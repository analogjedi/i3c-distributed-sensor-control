`timescale 1ns/1ps

module i3c_demo_rate_tick #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer TICK_HZ     = 1_000
) (
    input  wire clk,
    input  wire rst_n,
    output reg  tick
);

    localparam integer DIVISOR = (TICK_HZ <= 0) ? 1 : (CLK_FREQ_HZ / TICK_HZ);
    localparam integer COUNT_W = (DIVISOR <= 1) ? 1 : $clog2(DIVISOR);

    reg [COUNT_W-1:0] counter;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter <= {COUNT_W{1'b0}};
            tick    <= 1'b0;
        end else begin
            tick <= 1'b0;
            if (DIVISOR <= 1) begin
                tick <= 1'b1;
            end else if (counter == DIVISOR - 1) begin
                counter <= {COUNT_W{1'b0}};
                tick    <= 1'b1;
            end else begin
                counter <= counter + 1'b1;
            end
        end
    end

endmodule
