`timescale 1ns/1ps

module spartan7_i3c_controller_demo_top #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer I3C_SDR_HZ  = 12_500_000
) (
    input  wire       clk_100mhz,
    input  wire       btn_rst_n,
    output wire [4:0] led_sample_valid,
    output wire       led_boot_done,
    output wire       led_error,
    inout  wire       i3c_scl,
    inout  wire       i3c_sda
);

    wire scl_o;
    wire scl_oe;
    wire sda_o;
    wire sda_oe;
    wire sda_i;
    wire scl_i_unused;
    wire boot_done;
    wire boot_error;
    wire capture_error;
    wire [4:0] sample_valid_bitmap;

    assign led_sample_valid = sample_valid_bitmap;
    assign led_boot_done    = boot_done;
    assign led_error        = boot_error | capture_error;

    IOBUF iobuf_scl (
        .I (scl_o),
        .O (scl_i_unused),
        .IO(i3c_scl),
        .T (~scl_oe)
    );

    IOBUF iobuf_sda (
        .I (sda_o),
        .O (sda_i),
        .IO(i3c_sda),
        .T (~sda_oe)
    );

    i3c_sensor_controller_demo #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .I3C_SDR_HZ (I3C_SDR_HZ)
    ) u_demo (
        .clk                   (clk_100mhz),
        .rst_n                 (btn_rst_n),
        .scl_o                 (scl_o),
        .scl_oe                (scl_oe),
        .sda_o                 (sda_o),
        .sda_oe                (sda_oe),
        .sda_i                 (sda_i),
        .boot_done             (boot_done),
        .boot_error            (boot_error),
        .capture_error         (capture_error),
        .sample_valid_bitmap   (sample_valid_bitmap),
        .sample_payloads_flat  (),
        .sample_capture_count_flat(),
        .last_service_addr     (),
        .last_service_count    ()
    );

endmodule
