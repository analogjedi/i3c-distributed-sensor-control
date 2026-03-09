`timescale 1ns/1ps

module i3c_target_top #(
    parameter [6:0]  STATIC_ADDR    = 7'h2A,
    parameter [47:0] PROVISIONAL_ID = 48'h1234_5678_9ABC
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       scl,
    inout  wire       sda,

    input  wire       clear_dynamic_addr,
    input  wire       assign_dynamic_addr_valid,
    input  wire [6:0] assign_dynamic_addr,

    input  wire [7:0] read_data,
    output wire [7:0] write_data,
    output wire       write_valid,
    output wire       read_valid,
    output wire       selected,
    output wire [6:0] active_addr,
    output wire       dynamic_addr_valid,
    output wire [47:0] provisional_id,
    output wire [7:0]  last_ccc
);

    wire ccc_rstdaa_pulse;
    wire ccc_setaasa_pulse;
    wire ccc_seen;

    i3c_target_daa #(
        .STATIC_ADDR(STATIC_ADDR),
        .PROVISIONAL_ID(PROVISIONAL_ID)
    ) u_target_daa (
        .clk                     (clk),
        .rst_n                   (rst_n),
        .clear_dynamic_addr      (clear_dynamic_addr | ccc_rstdaa_pulse),
        .set_static_dynamic_addr (ccc_setaasa_pulse),
        .assign_dynamic_addr_valid(assign_dynamic_addr_valid),
        .assign_dynamic_addr     (assign_dynamic_addr),
        .active_addr             (active_addr),
        .dynamic_addr_valid      (dynamic_addr_valid),
        .provisional_id          (provisional_id)
    );

    i3c_target_transport u_target_transport (
        .rst_n      (rst_n),
        .scl        (scl),
        .sda        (sda),
        .read_data  (read_data),
        .write_data (write_data),
        .write_valid(write_valid),
        .read_valid (read_valid),
        .selected   (selected),
        .target_addr(active_addr)
    );

    i3c_target_ccc u_target_ccc (
        .rst_n        (rst_n),
        .scl          (scl),
        .sda          (sda),
        .rstdaa_pulse (ccc_rstdaa_pulse),
        .setaasa_pulse(ccc_setaasa_pulse),
        .ccc_seen     (ccc_seen),
        .last_ccc     (last_ccc)
    );
endmodule
