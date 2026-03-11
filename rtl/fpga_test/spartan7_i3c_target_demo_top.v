`timescale 1ns/1ps

module spartan7_i3c_target_demo_top #(
    parameter integer TARGET_INDEX   = 0,
    parameter integer CLK_FREQ_HZ    = 100_000_000,
    parameter integer SAMPLE_RATE_HZ = 2_000,
    parameter [6:0]  STATIC_ADDR     = 7'h30,
    parameter [47:0] PROVISIONAL_ID  = 48'h4100_0000_0001
) (
    input  wire clk_100mhz,
    input  wire btn_rst_n,
    output wire led_frame_active,
    inout  wire i3c_scl,
    inout  wire i3c_sda
);

    wire [79:0] sample_payload;
    wire [15:0] frame_counter;
    wire [7:0]  register_selector;
    wire [6:0]  active_addr;
    wire        dynamic_addr_valid;
    wire        read_valid;

    assign led_frame_active = frame_counter[8] ^ dynamic_addr_valid ^ read_valid ^ register_selector[0] ^ active_addr[0] ^ sample_payload[0];

    i3c_sensor_target_demo #(
        .TARGET_INDEX (TARGET_INDEX),
        .CLK_FREQ_HZ  (CLK_FREQ_HZ),
        .SAMPLE_RATE_HZ(SAMPLE_RATE_HZ),
        .STATIC_ADDR  (STATIC_ADDR),
        .PROVISIONAL_ID(PROVISIONAL_ID + TARGET_INDEX)
    ) u_demo (
        .clk            (clk_100mhz),
        .rst_n          (btn_rst_n),
        .scl            (i3c_scl),
        .sda            (i3c_sda),
        .sample_payload (sample_payload),
        .frame_counter  (frame_counter),
        .register_selector(register_selector),
        .active_addr    (active_addr),
        .dynamic_addr_valid(dynamic_addr_valid),
        .read_valid     (read_valid)
    );

endmodule
