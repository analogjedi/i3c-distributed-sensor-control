`timescale 1ns/1ps

// 8N1 UART Receiver
module uart_rx #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer BAUD_RATE   = 115200
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       rx_pin,
    output reg  [7:0] rx_data,
    output reg        rx_valid
);

    localparam integer CLKS_PER_BIT = CLK_FREQ_HZ / BAUD_RATE;
    localparam integer CNT_W = $clog2(CLKS_PER_BIT + 1);

    localparam [1:0] ST_IDLE  = 2'd0;
    localparam [1:0] ST_START = 2'd1;
    localparam [1:0] ST_DATA  = 2'd2;
    localparam [1:0] ST_STOP  = 2'd3;

    reg [1:0]       state;
    reg [CNT_W-1:0] clk_cnt;
    reg [2:0]       bit_idx;
    reg [7:0]       shift_reg;
    // Double-flop synchronizer for rx_pin
    reg             rx_sync0;
    reg             rx_sync;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_sync0 <= 1'b1;
            rx_sync  <= 1'b1;
        end else begin
            rx_sync0 <= rx_pin;
            rx_sync  <= rx_sync0;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= ST_IDLE;
            clk_cnt   <= {CNT_W{1'b0}};
            bit_idx   <= 3'd0;
            shift_reg <= 8'd0;
            rx_data   <= 8'd0;
            rx_valid  <= 1'b0;
        end else begin
            rx_valid <= 1'b0;

            case (state)
                ST_IDLE: begin
                    if (!rx_sync) begin
                        // Falling edge detected — potential start bit
                        state   <= ST_START;
                        clk_cnt <= {CNT_W{1'b0}};
                    end
                end

                ST_START: begin
                    // Sample at mid-bit
                    if (clk_cnt == (CLKS_PER_BIT / 2) - 1) begin
                        if (!rx_sync) begin
                            // Valid start bit
                            clk_cnt <= {CNT_W{1'b0}};
                            bit_idx <= 3'd0;
                            state   <= ST_DATA;
                        end else begin
                            // Glitch — back to idle
                            state <= ST_IDLE;
                        end
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end

                ST_DATA: begin
                    if (clk_cnt == CLKS_PER_BIT - 1) begin
                        clk_cnt <= {CNT_W{1'b0}};
                        shift_reg[bit_idx] <= rx_sync;
                        if (bit_idx == 3'd7) begin
                            state <= ST_STOP;
                        end else begin
                            bit_idx <= bit_idx + 1'b1;
                        end
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end

                ST_STOP: begin
                    if (clk_cnt == CLKS_PER_BIT - 1) begin
                        rx_data  <= shift_reg;
                        rx_valid <= 1'b1;
                        state    <= ST_IDLE;
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end
            endcase
        end
    end

endmodule
