`timescale 1ns/1ps

// 8N1 UART Transmitter
module uart_tx #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer BAUD_RATE   = 115200
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [7:0] tx_data,
    input  wire       tx_valid,
    output reg        tx_ready,
    output reg        tx_pin
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

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= ST_IDLE;
            clk_cnt   <= {CNT_W{1'b0}};
            bit_idx   <= 3'd0;
            shift_reg <= 8'd0;
            tx_ready  <= 1'b1;
            tx_pin    <= 1'b1;
        end else begin
            case (state)
                ST_IDLE: begin
                    tx_pin   <= 1'b1;
                    tx_ready <= 1'b1;
                    if (tx_valid) begin
                        shift_reg <= tx_data;
                        tx_ready  <= 1'b0;
                        state     <= ST_START;
                        clk_cnt   <= {CNT_W{1'b0}};
                    end
                end

                ST_START: begin
                    tx_pin <= 1'b0;
                    if (clk_cnt == CLKS_PER_BIT - 1) begin
                        clk_cnt <= {CNT_W{1'b0}};
                        bit_idx <= 3'd0;
                        state   <= ST_DATA;
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end

                ST_DATA: begin
                    tx_pin <= shift_reg[bit_idx];
                    if (clk_cnt == CLKS_PER_BIT - 1) begin
                        clk_cnt <= {CNT_W{1'b0}};
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
                    tx_pin <= 1'b1;
                    if (clk_cnt == CLKS_PER_BIT - 1) begin
                        state <= ST_IDLE;
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end
            endcase
        end
    end

endmodule
