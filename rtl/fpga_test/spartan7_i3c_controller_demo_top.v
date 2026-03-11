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
    inout  wire       i3c_sda,
    output wire       uart_txd,           // FPGA → PC (FT2232H)
    input  wire       uart_rxd            // PC → FPGA (FT2232H)
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
    // UART command interface
    // ----------------------------------------------------------------
    wire [7:0] uart_rx_data;
    wire       uart_rx_valid;
    wire [7:0] uart_tx_data;
    wire       uart_tx_valid;
    wire       uart_tx_ready;
    wire       soft_start;

    uart_rx #(
        .CLK_FREQ_HZ (CLK_FREQ_HZ),
        .BAUD_RATE    (115200)
    ) u_uart_rx (
        .clk     (clk_100m),
        .rst_n   (sys_rst_n),
        .rx_pin  (uart_rxd),
        .rx_data (uart_rx_data),
        .rx_valid(uart_rx_valid)
    );

    uart_tx #(
        .CLK_FREQ_HZ (CLK_FREQ_HZ),
        .BAUD_RATE    (115200)
    ) u_uart_tx (
        .clk     (clk_100m),
        .rst_n   (sys_rst_n),
        .tx_data (uart_tx_data),
        .tx_valid(uart_tx_valid),
        .tx_ready(uart_tx_ready),
        .tx_pin  (uart_txd)
    );

    // ----------------------------------------------------------------
    // Soft-start gating: hold demo in reset until 'S' command received
    // ----------------------------------------------------------------
    reg demo_started;
    always @(posedge clk_100m or negedge sys_rst_n) begin
        if (!sys_rst_n)
            demo_started <= 1'b0;
        else if (soft_start)
            demo_started <= 1'b1;
    end

    wire demo_rst_n = sys_rst_n & demo_started;

    // ----------------------------------------------------------------
    // Controller demo core
    // ----------------------------------------------------------------
    wire boot_done;
    wire boot_error;
    wire capture_error;
    wire [4:0] sample_valid_bitmap;
    wire [5*10*8-1:0] sample_payloads_flat;

    assign led_sample_valid = sample_valid_bitmap[3:0];
    assign led_sv4          = sample_valid_bitmap[4];
    assign led_boot_done    = boot_done;
    assign led_error        = boot_error | capture_error;

    i3c_sensor_controller_demo #(
        .CLK_FREQ_HZ (CLK_FREQ_HZ),
        .I3C_SDR_HZ  (I3C_SDR_HZ)
    ) u_demo (
        .clk                       (clk_100m),
        .rst_n                     (demo_rst_n),
        .scl_o                     (scl_o),
        .scl_oe                    (scl_oe),
        .sda_o                     (sda_o),
        .sda_oe                    (sda_oe),
        .sda_i                     (sda_i),
        .boot_done                 (boot_done),
        .boot_error                (boot_error),
        .capture_error             (capture_error),
        .sample_valid_bitmap       (sample_valid_bitmap),
        .sample_payloads_flat      (sample_payloads_flat),
        .sample_capture_count_flat (),
        .last_service_addr         (),
        .last_service_count        ()
    );

    // ----------------------------------------------------------------
    // Command handler
    // ----------------------------------------------------------------
    uart_cmd_handler u_cmd_handler (
        .clk                  (clk_100m),
        .rst_n                (sys_rst_n),
        .rx_data              (uart_rx_data),
        .rx_valid             (uart_rx_valid),
        .tx_data              (uart_tx_data),
        .tx_valid             (uart_tx_valid),
        .tx_ready             (uart_tx_ready),
        .soft_start           (soft_start),
        .boot_done            (boot_done),
        .boot_error           (boot_error),
        .capture_error        (capture_error),
        .sample_payloads_flat (sample_payloads_flat),
        .sample_valid_bitmap  (sample_valid_bitmap)
    );

endmodule
