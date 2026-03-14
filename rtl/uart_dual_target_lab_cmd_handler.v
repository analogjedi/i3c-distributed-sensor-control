`timescale 1ns/1ps

module uart_dual_target_lab_cmd_handler #(
    parameter integer MAX_READ_BYTES = 16,
    parameter integer PAYLOAD_BYTES  = 10
) (
    input  wire                           clk,
    input  wire                           rst_n,
    input  wire [7:0]                     rx_data,
    input  wire                           rx_valid,
    output reg  [7:0]                     tx_data,
    output reg                            tx_valid,
    input  wire                           tx_ready,

    output reg                            soft_start,
    input  wire                           boot_done,
    input  wire                           boot_error,
    input  wire                           capture_error,
    input  wire                           recovery_active,
    input  wire [1:0]                     verified_bitmap,
    input  wire [1:0]                     sample_valid_bitmap,
    input  wire [1:0]                     target_led_state,
    input  wire [63:0]                    signature_flat,
    input  wire [2*PAYLOAD_BYTES*8-1:0]   sample_payloads_flat,

    output reg                            ctrl_cmd_valid,
    input  wire                           ctrl_cmd_ready,
    output reg                            ctrl_cmd_read,
    output reg                            ctrl_cmd_target,
    output reg  [7:0]                     ctrl_cmd_reg_addr,
    output reg  [7:0]                     ctrl_cmd_write_value,
    output reg  [7:0]                     ctrl_cmd_read_len,
    input  wire                           ctrl_rsp_valid,
    input  wire                           ctrl_rsp_error,
    input  wire [7:0]                     ctrl_rsp_len,
    input  wire [8*MAX_READ_BYTES-1:0]    ctrl_rsp_data
);

    localparam [7:0] REQ_SYNC        = 8'hA5;
    localparam [7:0] RSP_SYNC        = 8'h5A;
    localparam [7:0] CMD_START       = 8'h01;
    localparam [7:0] CMD_STATUS      = 8'h02;
    localparam [7:0] CMD_SUMMARY     = 8'h10;
    localparam [7:0] CMD_READ_REG    = 8'h11;
    localparam [7:0] CMD_WRITE_REG   = 8'h12;

    localparam [7:0] STS_OK          = 8'h00;
    localparam [7:0] STS_BAD_CMD     = 8'h01;
    localparam [7:0] STS_BUSY        = 8'h02;
    localparam [7:0] STS_BAD_TARGET  = 8'h03;
    localparam [7:0] STS_CTRL_ERROR  = 8'h04;

    localparam integer MAX_RESP_BYTES = 3 + 18;
    localparam integer RESP_IDX_W     = 5;

    localparam [2:0] RX_IDLE         = 3'd0;
    localparam [2:0] RX_FRAME        = 3'd1;
    localparam [2:0] WAIT_CTRL       = 3'd2;
    localparam [2:0] SEND_RESP       = 3'd3;
    localparam [2:0] WAIT_TX_ACCEPT  = 3'd4;

    reg [2:0] state;
    reg [1:0] rx_idx;
    reg [7:0] frame_cmd;
    reg [7:0] frame_target;
    reg [7:0] frame_arg0;
    reg [7:0] frame_arg1;
    reg [7:0] resp [0:MAX_RESP_BYTES-1];
    reg [RESP_IDX_W-1:0] resp_len;
    reg [RESP_IDX_W-1:0] resp_idx;
    integer i;

    task automatic prepare_response_header;
        input [7:0] status;
        input [7:0] payload_len;
        begin
            resp[0] <= RSP_SYNC;
            resp[1] <= status;
            resp[2] <= payload_len;
            resp_len <= payload_len + 3;
            resp_idx <= {RESP_IDX_W{1'b0}};
        end
    endtask

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state            <= RX_IDLE;
            rx_idx           <= 2'd0;
            frame_cmd        <= 8'h00;
            frame_target     <= 8'h00;
            frame_arg0       <= 8'h00;
            frame_arg1       <= 8'h00;
            tx_data          <= 8'h00;
            tx_valid         <= 1'b0;
            soft_start       <= 1'b0;
            ctrl_cmd_valid   <= 1'b0;
            ctrl_cmd_read    <= 1'b0;
            ctrl_cmd_target  <= 1'b0;
            ctrl_cmd_reg_addr <= 8'h00;
            ctrl_cmd_write_value <= 8'h00;
            ctrl_cmd_read_len <= 8'h00;
            resp_len         <= {RESP_IDX_W{1'b0}};
            resp_idx         <= {RESP_IDX_W{1'b0}};
            for (i = 0; i < MAX_RESP_BYTES; i = i + 1)
                resp[i] <= 8'h00;
        end else begin
            tx_valid       <= 1'b0;
            soft_start     <= 1'b0;
            ctrl_cmd_valid <= 1'b0;

            case (state)
                RX_IDLE: begin
                    if (rx_valid && (rx_data == REQ_SYNC)) begin
                        rx_idx <= 2'd0;
                        state  <= RX_FRAME;
                    end
                end

                RX_FRAME: begin
                    if (rx_valid) begin
                        case (rx_idx)
                            2'd0: frame_cmd    <= rx_data;
                            2'd1: frame_target <= rx_data;
                            2'd2: frame_arg0   <= rx_data;
                            2'd3: begin
                                frame_arg1 <= rx_data;

                                if ((frame_target != 8'h00) && (frame_target != 8'h01) &&
                                    (frame_cmd == CMD_SUMMARY || frame_cmd == CMD_READ_REG || frame_cmd == CMD_WRITE_REG)) begin
                                    prepare_response_header(STS_BAD_TARGET, 8'd0);
                                    state <= SEND_RESP;
                                end else begin
                                    case (frame_cmd)
                                        CMD_START: begin
                                            soft_start <= 1'b1;
                                            prepare_response_header(STS_OK, 8'd0);
                                            state <= SEND_RESP;
                                        end

                                        CMD_STATUS: begin
                                            prepare_response_header(STS_OK, 8'd4);
                                            resp[3] <= {4'b0, recovery_active, capture_error, boot_error, boot_done};
                                            resp[4] <= {6'b0, verified_bitmap};
                                            resp[5] <= {6'b0, sample_valid_bitmap};
                                            resp[6] <= {6'b0, target_led_state};
                                            state <= SEND_RESP;
                                        end

                                        CMD_SUMMARY: begin
                                            prepare_response_header(STS_OK, 8'd18);
                                            resp[3]  <= frame_target;
                                            resp[4]  <= 8'h10 + frame_target;
                                            resp[5]  <= verified_bitmap[frame_target[0]];
                                            resp[6]  <= target_led_state[frame_target[0]];
                                            if (frame_target[0]) begin
                                                resp[7]  <= signature_flat[39:32];
                                                resp[8]  <= signature_flat[47:40];
                                                resp[9]  <= signature_flat[55:48];
                                                resp[10] <= signature_flat[63:56];
                                                for (i = 0; i < PAYLOAD_BYTES; i = i + 1)
                                                    resp[11+i] <= sample_payloads_flat[PAYLOAD_BYTES*8 + i*8 +: 8];
                                            end else begin
                                                resp[7]  <= signature_flat[7:0];
                                                resp[8]  <= signature_flat[15:8];
                                                resp[9]  <= signature_flat[23:16];
                                                resp[10] <= signature_flat[31:24];
                                                for (i = 0; i < PAYLOAD_BYTES; i = i + 1)
                                                    resp[11+i] <= sample_payloads_flat[i*8 +: 8];
                                            end
                                            state <= SEND_RESP;
                                        end

                                        CMD_READ_REG: begin
                                            if (!boot_done || !ctrl_cmd_ready) begin
                                                prepare_response_header(STS_BUSY, 8'd0);
                                                state <= SEND_RESP;
                                            end else begin
                                                ctrl_cmd_valid       <= 1'b1;
                                                ctrl_cmd_read        <= 1'b1;
                                                ctrl_cmd_target      <= frame_target[0];
                                                ctrl_cmd_reg_addr    <= frame_arg0;
                                                ctrl_cmd_write_value <= 8'h00;
                                                ctrl_cmd_read_len    <= rx_data; // use rx_data directly; frame_arg1 not yet updated
                                                state                <= WAIT_CTRL;
                                            end
                                        end

                                        CMD_WRITE_REG: begin
                                            if (!boot_done || !ctrl_cmd_ready) begin
                                                prepare_response_header(STS_BUSY, 8'd0);
                                                state <= SEND_RESP;
                                            end else begin
                                                ctrl_cmd_valid       <= 1'b1;
                                                ctrl_cmd_read        <= 1'b0;
                                                ctrl_cmd_target      <= frame_target[0];
                                                ctrl_cmd_reg_addr    <= frame_arg0;
                                                ctrl_cmd_write_value <= rx_data; // use rx_data directly; frame_arg1 not yet updated
                                                ctrl_cmd_read_len    <= 8'd1;
                                                state                <= WAIT_CTRL;
                                            end
                                        end

                                        default: begin
                                            prepare_response_header(STS_BAD_CMD, 8'd0);
                                            state <= SEND_RESP;
                                        end
                                    endcase
                                end
                            end
                        endcase

                        if (rx_idx != 2'd3)
                            rx_idx <= rx_idx + 1'b1;
                    end
                end

                WAIT_CTRL: begin
                    if (ctrl_rsp_valid) begin
                        prepare_response_header(ctrl_rsp_error ? STS_CTRL_ERROR : STS_OK, ctrl_rsp_len);
                        for (i = 0; i < MAX_READ_BYTES; i = i + 1)
                            resp[3+i] <= ctrl_rsp_data[i*8 +: 8];
                        state <= SEND_RESP;
                    end
                end

                SEND_RESP: begin
                    if (tx_ready) begin
                        tx_data  <= resp[resp_idx];
                        tx_valid <= 1'b1;
                        state    <= WAIT_TX_ACCEPT;
                    end
                end

                WAIT_TX_ACCEPT: begin
                    if (!tx_ready) begin
                        if (resp_idx == resp_len - 1) begin
                            state <= RX_IDLE;
                        end else begin
                            resp_idx <= resp_idx + 1'b1;
                            state    <= SEND_RESP;
                        end
                    end
                end

                default: begin
                    state <= RX_IDLE;
                end
            endcase
        end
    end

endmodule
