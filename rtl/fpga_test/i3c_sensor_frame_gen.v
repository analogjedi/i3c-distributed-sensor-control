`timescale 1ns/1ps

module i3c_sensor_frame_gen #(
    parameter integer TARGET_INDEX = 0
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        sample_tick,
    output reg  [15:0] frame_counter,
    output wire [79:0] sample_payload
);

    localparam [15:0] TARGET_OFFSET = TARGET_INDEX << 8;

    wire [15:0] ch0 = 16'h1000 + TARGET_OFFSET + frame_counter[7:0];
    wire [15:0] ch1 = 16'h2000 + TARGET_OFFSET + ((frame_counter[7:0] << 1) + frame_counter[7:0]);
    wire [15:0] ch2 = 16'h3000 + TARGET_OFFSET + ((frame_counter[7:0] << 2) + frame_counter[7:0]);
    wire [15:0] ch3 = 16'h4000 + TARGET_OFFSET + ((frame_counter[7:0] << 3) - frame_counter[7:0]);
    wire [7:0] temperature = 8'h50 + TARGET_INDEX[7:0] + frame_counter[3:0];
    wire [7:0] misc_status  = {TARGET_INDEX[2:0], frame_counter[4:0]};

    assign sample_payload = {
        misc_status,
        temperature,
        ch3[15:8], ch3[7:0],
        ch2[15:8], ch2[7:0],
        ch1[15:8], ch1[7:0],
        ch0[15:8], ch0[7:0]
    };

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            frame_counter <= 16'h0000;
        end else if (sample_tick) begin
            frame_counter <= frame_counter + 1'b1;
        end
    end

endmodule
