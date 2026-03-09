`timescale 1ns/1ps

module i3c_target_daa #(
    parameter [6:0]  STATIC_ADDR = 7'h2A,
    parameter [47:0] PROVISIONAL_ID = 48'h1234_5678_9ABC
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       clear_dynamic_addr,
    input  wire       assign_dynamic_addr_valid,
    input  wire [6:0] assign_dynamic_addr,

    output reg  [6:0] active_addr,
    output reg        dynamic_addr_valid,
    output wire [47:0] provisional_id
);

    assign provisional_id = PROVISIONAL_ID;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            active_addr        <= STATIC_ADDR;
            dynamic_addr_valid <= 1'b0;
        end else if (clear_dynamic_addr) begin
            active_addr        <= STATIC_ADDR;
            dynamic_addr_valid <= 1'b0;
        end else if (assign_dynamic_addr_valid) begin
            active_addr        <= assign_dynamic_addr;
            dynamic_addr_valid <= 1'b1;
        end
    end
endmodule
