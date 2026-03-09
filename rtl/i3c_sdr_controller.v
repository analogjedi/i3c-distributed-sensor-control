`timescale 1ns/1ps

module i3c_sdr_controller #(
    parameter integer CLK_FREQ_HZ    = 100_000_000,
    parameter integer I3C_SDR_HZ     = 1_000_000,
    parameter integer PUSH_PULL_DATA = 1
) (
    input  wire       clk,
    input  wire       rst_n,

    input  wire       cmd_valid,
    output reg        cmd_ready,
    input  wire [6:0] cmd_addr,
    input  wire       cmd_read,
    input  wire [7:0] cmd_wdata,

    output reg        rsp_valid,
    output reg        rsp_nack,
    output reg [7:0]  cmd_rdata,
    output reg        busy,

    output reg        scl_o,
    output reg        scl_oe,
    output reg        sda_o,
    output reg        sda_oe,
    input  wire       sda_i
);

    localparam integer HALF_PERIOD_CLKS = CLK_FREQ_HZ / (2 * I3C_SDR_HZ);
    localparam integer DIVIDER          = (HALF_PERIOD_CLKS < 2) ? 2 : HALF_PERIOD_CLKS;

    localparam [3:0] ST_IDLE          = 4'd0;
    localparam [3:0] ST_START_A       = 4'd1;
    localparam [3:0] ST_START_B       = 4'd2;
    localparam [3:0] ST_TX_BIT_L      = 4'd3;
    localparam [3:0] ST_TX_BIT_H      = 4'd4;
    localparam [3:0] ST_ACK_L         = 4'd5;
    localparam [3:0] ST_ACK_H         = 4'd6;
    localparam [3:0] ST_RX_BIT_L      = 4'd7;
    localparam [3:0] ST_RX_BIT_H      = 4'd8;
    localparam [3:0] ST_MASTER_ACK_L  = 4'd9;
    localparam [3:0] ST_MASTER_ACK_H  = 4'd10;
    localparam [3:0] ST_STOP_A        = 4'd11;
    localparam [3:0] ST_STOP_B        = 4'd12;
    localparam [3:0] ST_STOP_C        = 4'd13;
    localparam [3:0] ST_DONE          = 4'd14;

    localparam [1:0] PH_ADDR          = 2'd0;
    localparam [1:0] PH_WRITE_DATA    = 2'd1;
    localparam [1:0] PH_READ_DATA     = 2'd2;

    reg [3:0] state;
    reg [1:0] phase;
    reg [31:0] div_cnt;
    reg [3:0] bit_idx;
    reg [7:0] shreg;

    reg [6:0] cmd_addr_lat;
    reg       cmd_read_lat;
    reg [7:0] cmd_wdata_lat;
    reg       nack_seen;

    wire tick = (div_cnt == 0);

    task set_sda;
        input bit_value;
        input open_drain;
        begin
            if (open_drain) begin
                sda_o  <= 1'b0;
                sda_oe <= ~bit_value;
            end else begin
                sda_o  <= bit_value;
                sda_oe <= 1'b1;
            end
        end
    endtask

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state        <= ST_IDLE;
            phase        <= PH_ADDR;
            div_cnt      <= DIVIDER - 1;
            bit_idx      <= 4'd0;
            shreg        <= 8'h00;
            cmd_addr_lat <= 7'h00;
            cmd_read_lat <= 1'b0;
            cmd_wdata_lat<= 8'h00;
            nack_seen    <= 1'b0;
            cmd_ready    <= 1'b1;
            rsp_valid    <= 1'b0;
            rsp_nack     <= 1'b0;
            cmd_rdata    <= 8'h00;
            busy         <= 1'b0;
            scl_o        <= 1'b1;
            scl_oe       <= 1'b1;
            sda_o        <= 1'b0;
            sda_oe       <= 1'b0;
        end else begin
            rsp_valid <= 1'b0;

            if (state == ST_IDLE) begin
                div_cnt <= DIVIDER - 1;
            end else if (tick) begin
                div_cnt <= DIVIDER - 1;
            end else begin
                div_cnt <= div_cnt - 1;
            end

            case (state)
                ST_IDLE: begin
                    cmd_ready <= 1'b1;
                    busy      <= 1'b0;
                    rsp_nack  <= nack_seen;
                    scl_o     <= 1'b1;
                    scl_oe    <= 1'b1;
                    set_sda(1'b1, 1'b1);

                    if (cmd_valid) begin
                        cmd_addr_lat  <= cmd_addr;
                        cmd_read_lat  <= cmd_read;
                        cmd_wdata_lat <= cmd_wdata;
                        phase         <= PH_ADDR;
                        shreg         <= {cmd_addr, cmd_read};
                        bit_idx       <= 4'd7;
                        nack_seen     <= 1'b0;
                        cmd_ready     <= 1'b0;
                        busy          <= 1'b1;
                        state         <= ST_START_A;
                    end
                end

                ST_START_A: begin
                    scl_o  <= 1'b1;
                    scl_oe <= 1'b1;
                    set_sda(1'b0, 1'b1);
                    if (tick) begin
                        state <= ST_START_B;
                    end
                end

                ST_START_B: begin
                    scl_o  <= 1'b0;
                    scl_oe <= 1'b1;
                    set_sda(1'b0, 1'b1);
                    if (tick) begin
                        state <= ST_TX_BIT_L;
                    end
                end

                ST_TX_BIT_L: begin
                    scl_o  <= 1'b0;
                    scl_oe <= 1'b1;
                    if (phase == PH_ADDR) begin
                        set_sda(shreg[bit_idx], 1'b1);
                    end else begin
                        set_sda(shreg[bit_idx], (PUSH_PULL_DATA == 0));
                    end
                    if (tick) begin
                        state <= ST_TX_BIT_H;
                    end
                end

                ST_TX_BIT_H: begin
                    scl_o  <= 1'b1;
                    scl_oe <= 1'b1;
                    if (phase == PH_ADDR) begin
                        set_sda(shreg[bit_idx], 1'b1);
                    end else begin
                        set_sda(shreg[bit_idx], (PUSH_PULL_DATA == 0));
                    end
                    if (tick) begin
                        if (bit_idx == 0) begin
                            state <= ST_ACK_L;
                        end else begin
                            bit_idx <= bit_idx - 1'b1;
                            state   <= ST_TX_BIT_L;
                        end
                    end
                end

                ST_ACK_L: begin
                    scl_o  <= 1'b0;
                    scl_oe <= 1'b1;
                    set_sda(1'b1, 1'b1);
                    if (tick) begin
                        state <= ST_ACK_H;
                    end
                end

                ST_ACK_H: begin
                    scl_o  <= 1'b1;
                    scl_oe <= 1'b1;
                    set_sda(1'b1, 1'b1);
                    if (tick) begin
                        if (sda_i) begin
                            nack_seen <= 1'b1;
                            state     <= ST_STOP_A;
                        end else if (phase == PH_ADDR) begin
                            if (cmd_read_lat) begin
                                phase   <= PH_READ_DATA;
                                bit_idx <= 4'd7;
                                shreg   <= 8'h00;
                                state   <= ST_RX_BIT_L;
                            end else begin
                                phase   <= PH_WRITE_DATA;
                                shreg   <= cmd_wdata_lat;
                                bit_idx <= 4'd7;
                                state   <= ST_TX_BIT_L;
                            end
                        end else begin
                            state <= ST_STOP_A;
                        end
                    end
                end

                ST_RX_BIT_L: begin
                    scl_o  <= 1'b0;
                    scl_oe <= 1'b1;
                    set_sda(1'b1, 1'b1);
                    if (tick) begin
                        state <= ST_RX_BIT_H;
                    end
                end

                ST_RX_BIT_H: begin
                    scl_o  <= 1'b1;
                    scl_oe <= 1'b1;
                    set_sda(1'b1, 1'b1);
                    if (tick) begin
                        shreg[bit_idx] <= sda_i;
                        if (bit_idx == 0) begin
                            cmd_rdata <= {shreg[7:1], sda_i};
                            state     <= ST_MASTER_ACK_L;
                        end else begin
                            bit_idx <= bit_idx - 1'b1;
                            state   <= ST_RX_BIT_L;
                        end
                    end
                end

                ST_MASTER_ACK_L: begin
                    scl_o  <= 1'b0;
                    scl_oe <= 1'b1;
                    if (PUSH_PULL_DATA) begin
                        set_sda(1'b1, 1'b0);
                    end else begin
                        set_sda(1'b1, 1'b1);
                    end
                    if (tick) begin
                        state <= ST_MASTER_ACK_H;
                    end
                end

                ST_MASTER_ACK_H: begin
                    scl_o  <= 1'b1;
                    scl_oe <= 1'b1;
                    if (PUSH_PULL_DATA) begin
                        set_sda(1'b1, 1'b0);
                    end else begin
                        set_sda(1'b1, 1'b1);
                    end
                    if (tick) begin
                        state <= ST_STOP_A;
                    end
                end

                ST_STOP_A: begin
                    scl_o  <= 1'b0;
                    scl_oe <= 1'b1;
                    set_sda(1'b0, 1'b1);
                    if (tick) begin
                        state <= ST_STOP_B;
                    end
                end

                ST_STOP_B: begin
                    scl_o  <= 1'b1;
                    scl_oe <= 1'b1;
                    set_sda(1'b0, 1'b1);
                    if (tick) begin
                        state <= ST_STOP_C;
                    end
                end

                ST_STOP_C: begin
                    scl_o  <= 1'b1;
                    scl_oe <= 1'b1;
                    set_sda(1'b1, 1'b1);
                    if (tick) begin
                        state <= ST_DONE;
                    end
                end

                ST_DONE: begin
                    cmd_ready <= 1'b1;
                    busy      <= 1'b0;
                    rsp_valid <= 1'b1;
                    rsp_nack  <= nack_seen;
                    scl_o     <= 1'b1;
                    scl_oe    <= 1'b1;
                    set_sda(1'b1, 1'b1);
                    state <= ST_IDLE;
                end

                default: begin
                    state <= ST_IDLE;
                end
            endcase
        end
    end
endmodule
