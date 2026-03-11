`timescale 1ns/1ps

// Board-facing top for Digilent CMOD S7 (XC7S25-1CSGA225)
// 12 MHz board oscillator → MMCM → 100 MHz system clock

module spartan7_i3c_controller_demo_top #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer I3C_SDR_HZ  = 12_500_000
) (
    input  wire       clk_12mhz,
    input  wire       btn_reset,          // Active-high (CMOD S7 BTN0)
    output wire [3:0] led_sample_valid,   // Discrete LEDs 0-3
    output wire       led_sv4,            // RGB blue — sample_valid[4]
    output wire       led_boot_done,      // RGB green
    output wire       led_error,          // RGB red
    inout  wire       i3c_scl,
    inout  wire       i3c_sda
);

    // ----------------------------------------------------------------
    // MMCM: 12 MHz → 100 MHz
    //   VCO = 12 MHz × 62.5 = 750 MHz   (range 600–1200 MHz)
    //   CLKOUT0 = 750 / 7.5 = 100 MHz
    // ----------------------------------------------------------------
    wire clk_100m_unbuf;
    wire clk_100m;
    wire mmcm_locked;
    wire clk_fb;

    MMCME2_BASE #(
        .CLKIN1_PERIOD    (83.333),
        .DIVCLK_DIVIDE    (1),
        .CLKFBOUT_MULT_F  (62.500),
        .CLKOUT0_DIVIDE_F (7.500),
        .STARTUP_WAIT     ("FALSE")
    ) u_mmcm (
        .CLKIN1   (clk_12mhz),
        .RST      (1'b0),
        .PWRDWN   (1'b0),
        .CLKFBIN  (clk_fb),
        .CLKFBOUT (clk_fb),
        .CLKOUT0  (clk_100m_unbuf),
        .CLKOUT0B (),
        .CLKOUT1  (),
        .CLKOUT1B (),
        .CLKOUT2  (),
        .CLKOUT2B (),
        .CLKOUT3  (),
        .CLKOUT3B (),
        .CLKOUT4  (),
        .CLKOUT5  (),
        .CLKOUT6  (),
        .LOCKED   (mmcm_locked)
    );

    BUFG u_bufg_clk100 (
        .I (clk_100m_unbuf),
        .O (clk_100m)
    );

    // ----------------------------------------------------------------
    // System reset: active-low, held until MMCM locks and button released
    // ----------------------------------------------------------------
    wire sys_rst_n = mmcm_locked & ~btn_reset;

    // ----------------------------------------------------------------
    // I3C open-drain I/O buffers
    // ----------------------------------------------------------------
    wire scl_o;
    wire scl_oe;
    wire sda_o;
    wire sda_oe;
    wire sda_i;
    wire scl_i_unused;

    IOBUF iobuf_scl (
        .I  (scl_o),
        .O  (scl_i_unused),
        .IO (i3c_scl),
        .T  (~scl_oe)
    );

    IOBUF iobuf_sda (
        .I  (sda_o),
        .O  (sda_i),
        .IO (i3c_sda),
        .T  (~sda_oe)
    );

    // ----------------------------------------------------------------
    // Controller demo core
    // ----------------------------------------------------------------
    wire boot_done;
    wire boot_error;
    wire capture_error;
    wire [4:0] sample_valid_bitmap;

    assign led_sample_valid = sample_valid_bitmap[3:0];
    assign led_sv4          = sample_valid_bitmap[4];
    assign led_boot_done    = boot_done;
    assign led_error        = boot_error | capture_error;

    i3c_sensor_controller_demo #(
        .CLK_FREQ_HZ (CLK_FREQ_HZ),
        .I3C_SDR_HZ  (I3C_SDR_HZ)
    ) u_demo (
        .clk                       (clk_100m),
        .rst_n                     (sys_rst_n),
        .scl_o                     (scl_o),
        .scl_oe                    (scl_oe),
        .sda_o                     (sda_o),
        .sda_oe                    (sda_oe),
        .sda_i                     (sda_i),
        .boot_done                 (boot_done),
        .boot_error                (boot_error),
        .capture_error             (capture_error),
        .sample_valid_bitmap       (sample_valid_bitmap),
        .sample_payloads_flat      (),
        .sample_capture_count_flat (),
        .last_service_addr         (),
        .last_service_count        ()
    );

endmodule
