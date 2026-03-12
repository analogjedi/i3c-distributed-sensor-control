`timescale 1ns/1ps

module i3c_sensor_target_demo #(
    parameter integer MAX_READ_BYTES = 16,
    parameter integer TARGET_INDEX   = 0,
    parameter integer CLK_FREQ_HZ    = 100_000_000,
    parameter integer SAMPLE_RATE_HZ = 2_000,
    parameter [7:0]  SAMPLE_SELECTOR = 8'h40,
    parameter [6:0]  STATIC_ADDR     = 7'h30,
    parameter [47:0] PROVISIONAL_ID  = 48'h4100_0000_0001,
    parameter [7:0]  TARGET_BCR      = 8'h21,
    parameter [7:0]  TARGET_DCR      = 8'h90
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       scl,
    input  wire       sda,
    output wire       sda_oe,
    output wire [79:0] sample_payload,
    output wire [15:0] frame_counter,
    output wire [7:0]  register_selector,
    output wire [6:0]  active_addr,
    output wire        dynamic_addr_valid,
    output wire        read_valid
);

    wire sample_tick;
    wire [8*MAX_READ_BYTES-1:0] read_data_bus;

    i3c_demo_rate_tick #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .TICK_HZ    (SAMPLE_RATE_HZ)
    ) u_sample_tick (
        .clk  (clk),
        .rst_n(rst_n),
        .tick (sample_tick)
    );

    i3c_sensor_frame_gen #(
        .TARGET_INDEX(TARGET_INDEX)
    ) u_frame_gen (
        .clk          (clk),
        .rst_n        (rst_n),
        .sample_tick  (sample_tick),
        .frame_counter(frame_counter),
        .sample_payload(sample_payload)
    );

    assign read_data_bus = (register_selector == SAMPLE_SELECTOR) ?
                           {{(8*MAX_READ_BYTES-80){1'b0}}, sample_payload} :
                           {8*MAX_READ_BYTES{1'b0}};

    i3c_target_top #(
        .MAX_READ_BYTES(MAX_READ_BYTES),
        .STATIC_ADDR   (STATIC_ADDR),
        .PROVISIONAL_ID(PROVISIONAL_ID),
        .TARGET_BCR    (TARGET_BCR),
        .TARGET_DCR    (TARGET_DCR)
    ) u_target_top (
        .clk                     (clk),
        .rst_n                   (rst_n),
        .scl                     (scl),
        .sda                     (sda),
        .sda_oe                  (sda_oe),
        .clear_dynamic_addr      (1'b0),
        .assign_dynamic_addr_valid(1'b0),
        .assign_dynamic_addr     (7'h00),
        .read_data               (read_data_bus),
        .write_data              (),
        .write_valid             (),
        .register_selector       (register_selector),
        .read_valid              (read_valid),
        .selected                (),
        .active_addr             (active_addr),
        .dynamic_addr_valid      (dynamic_addr_valid),
        .provisional_id          (),
        .event_enable_mask       (),
        .rstact_action           (),
        .status_word             (),
        .last_ccc                ()
    );

endmodule
