`timescale 1ns/1ps

// UART command handler for I3C sensor demo
// Commands (single ASCII byte):
//   'S' (0x53) — Assert soft_start pulse, respond "OK\r\n"
//   'R' (0x52) — Dump 50 payload bytes (5 targets x 10), then "\r\n"
//   'C' (0x43) — Status byte (bit0=boot_done, bit1=boot_error, bit2=capture_error), then "\r\n"
//   Other      — Respond "ERR\r\n"

module uart_cmd_handler (
    input  wire         clk,
    input  wire         rst_n,
    // UART RX interface
    input  wire [7:0]   rx_data,
    input  wire         rx_valid,
    // UART TX interface
    output reg  [7:0]   tx_data,
    output reg          tx_valid,
    input  wire         tx_ready,
    // Demo control/status
    output reg          soft_start,
    input  wire         boot_done,
    input  wire         boot_error,
    input  wire         capture_error,
    input  wire [399:0] sample_payloads_flat,
    input  wire [4:0]   sample_valid_bitmap
);

    // Response buffer — max 52 bytes ('R' dumps 50 data + \r + \n)
    localparam integer BUF_LEN = 52;
    localparam integer IDX_W   = 6; // ceil(log2(52))

    localparam [1:0] ST_IDLE    = 2'd0;
    localparam [1:0] ST_SEND    = 2'd1;
    localparam [1:0] ST_WAIT    = 2'd2;

    reg [1:0]       state;
    reg [7:0]       resp [0:BUF_LEN-1];
    reg [IDX_W-1:0] buf_len;
    reg [IDX_W-1:0] buf_idx;

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= ST_IDLE;
            tx_data    <= 8'd0;
            tx_valid   <= 1'b0;
            soft_start <= 1'b0;
            buf_len    <= {IDX_W{1'b0}};
            buf_idx    <= {IDX_W{1'b0}};
            for (i = 0; i < BUF_LEN; i = i + 1)
                resp[i] <= 8'd0;
        end else begin
            soft_start <= 1'b0;
            tx_valid   <= 1'b0;

            case (state)
                ST_IDLE: begin
                    if (rx_valid) begin
                        case (rx_data)
                            8'h53: begin // 'S' — soft start
                                soft_start <= 1'b1;
                                resp[0] <= 8'h4F; // 'O'
                                resp[1] <= 8'h4B; // 'K'
                                resp[2] <= 8'h0D; // '\r'
                                resp[3] <= 8'h0A; // '\n'
                                buf_len <= 6'd4;
                                buf_idx <= 6'd0;
                                state   <= ST_SEND;
                            end

                            8'h52: begin // 'R' — read payloads
                                // Pack 50 bytes from sample_payloads_flat
                                // Target 0 first, byte 0 is LSB of each target's slice
                                for (i = 0; i < 50; i = i + 1)
                                    resp[i] <= sample_payloads_flat[i*8 +: 8];
                                resp[50] <= 8'h0D; // '\r'
                                resp[51] <= 8'h0A; // '\n'
                                buf_len <= 6'd52;
                                buf_idx <= 6'd0;
                                state   <= ST_SEND;
                            end

                            8'h43: begin // 'C' — status
                                resp[0] <= {5'b0, capture_error, boot_error, boot_done};
                                resp[1] <= 8'h0D; // '\r'
                                resp[2] <= 8'h0A; // '\n'
                                buf_len <= 6'd3;
                                buf_idx <= 6'd0;
                                state   <= ST_SEND;
                            end

                            default: begin // Unknown command
                                resp[0] <= 8'h45; // 'E'
                                resp[1] <= 8'h52; // 'R'
                                resp[2] <= 8'h52; // 'R'
                                resp[3] <= 8'h0D; // '\r'
                                resp[4] <= 8'h0A; // '\n'
                                buf_len <= 6'd5;
                                buf_idx <= 6'd0;
                                state   <= ST_SEND;
                            end
                        endcase
                    end
                end

                ST_SEND: begin
                    if (tx_ready) begin
                        tx_data  <= resp[buf_idx];
                        tx_valid <= 1'b1;
                        state    <= ST_WAIT;
                    end
                end

                ST_WAIT: begin
                    // Wait for tx_ready to drop (byte accepted), then advance
                    if (!tx_ready) begin
                        if (buf_idx == buf_len - 1) begin
                            state <= ST_IDLE;
                        end else begin
                            buf_idx <= buf_idx + 1'b1;
                            state   <= ST_SEND;
                        end
                    end
                end
            endcase
        end
    end

endmodule
