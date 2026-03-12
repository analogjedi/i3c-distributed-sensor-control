`timescale 1ns/1ps

// Unified single-board demo for Digilent CMOD S7 (XC7S25-1CSGA225)
// Controller + 5 targets on one FPGA — no external I3C pins needed.
// 12 MHz board oscillator → MMCM → 100 MHz system clock
//
// Internal open-drain bus: explicit wired-AND of all drivers.
// SCL driven by controller only; SDA driven by controller + 5 targets.

module spartan7_i3c_unified_demo_top #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer I3C_SDR_HZ  = 12_500_000
) (
    input  wire       clk_12mhz,
    input  wire       btn_reset,          // Active-high (CMOD S7 BTN0)
    output wire [3:0] led_sample_valid,   // Discrete LEDs 0-3
    output wire       led_sv4,            // RGB blue — sample_valid[4]
    output wire       led_boot_done,      // RGB green
    output wire       led_error,          // RGB red
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
    // Internal open-drain I3C bus (wired-AND)
    //
    // SCL and SDA are open-drain.  All driver-enable signals are
    // combined explicitly into a wired-AND:
    //   bus = ~(driver_0_pulling_low | driver_1_pulling_low | …)
    // Bus idles high (1) when nobody drives.
    // ----------------------------------------------------------------
    wire scl_bus;
    wire sda_bus;

    wire ctrl_scl_o, ctrl_scl_oe;
    wire ctrl_sda_o, ctrl_sda_oe;
    wire tgt0_sda_oe, tgt1_sda_oe, tgt2_sda_oe, tgt3_sda_oe, tgt4_sda_oe;

    assign scl_bus = ~(ctrl_scl_oe & ~ctrl_scl_o);
    assign sda_bus = ~( (ctrl_sda_oe & ~ctrl_sda_o) |
                        tgt0_sda_oe |
                        tgt1_sda_oe |
                        tgt2_sda_oe |
                        tgt3_sda_oe |
                        tgt4_sda_oe );

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
    ) u_ctrl (
        .clk                       (clk_100m),
        .rst_n                     (demo_rst_n),
        .scl_o                     (ctrl_scl_o),
        .scl_oe                    (ctrl_scl_oe),
        .sda_o                     (ctrl_sda_o),
        .sda_oe                    (ctrl_sda_oe),
        .sda_i                     (sda_bus),
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
    // 5× Target instances (STATIC_ADDR 0x30–0x34)
    //
    // Each target exposes sda_oe (open-drain pull-low enable).
    // The wired-AND above combines all drivers.
    // ----------------------------------------------------------------
    i3c_sensor_target_demo #(
        .CLK_FREQ_HZ    (CLK_FREQ_HZ),
        .STATIC_ADDR     (7'h30),
        .TARGET_INDEX    (0),
        .PROVISIONAL_ID  (48'h4100_0000_0001)
    ) u_tgt0 (
        .clk               (clk_100m),
        .rst_n              (demo_rst_n),
        .scl                (scl_bus),
        .sda                (sda_bus),
        .sda_oe             (tgt0_sda_oe),
        .sample_payload     (),
        .frame_counter      (),
        .register_selector  (),
        .active_addr        (),
        .dynamic_addr_valid (),
        .read_valid         ()
    );

    i3c_sensor_target_demo #(
        .CLK_FREQ_HZ    (CLK_FREQ_HZ),
        .STATIC_ADDR     (7'h31),
        .TARGET_INDEX    (1),
        .PROVISIONAL_ID  (48'h4100_0000_0002)
    ) u_tgt1 (
        .clk               (clk_100m),
        .rst_n              (demo_rst_n),
        .scl                (scl_bus),
        .sda                (sda_bus),
        .sda_oe             (tgt1_sda_oe),
        .sample_payload     (),
        .frame_counter      (),
        .register_selector  (),
        .active_addr        (),
        .dynamic_addr_valid (),
        .read_valid         ()
    );

    i3c_sensor_target_demo #(
        .CLK_FREQ_HZ    (CLK_FREQ_HZ),
        .STATIC_ADDR     (7'h32),
        .TARGET_INDEX    (2),
        .PROVISIONAL_ID  (48'h4100_0000_0003)
    ) u_tgt2 (
        .clk               (clk_100m),
        .rst_n              (demo_rst_n),
        .scl                (scl_bus),
        .sda                (sda_bus),
        .sda_oe             (tgt2_sda_oe),
        .sample_payload     (),
        .frame_counter      (),
        .register_selector  (),
        .active_addr        (),
        .dynamic_addr_valid (),
        .read_valid         ()
    );

    i3c_sensor_target_demo #(
        .CLK_FREQ_HZ    (CLK_FREQ_HZ),
        .STATIC_ADDR     (7'h33),
        .TARGET_INDEX    (3),
        .PROVISIONAL_ID  (48'h4100_0000_0004)
    ) u_tgt3 (
        .clk               (clk_100m),
        .rst_n              (demo_rst_n),
        .scl                (scl_bus),
        .sda                (sda_bus),
        .sda_oe             (tgt3_sda_oe),
        .sample_payload     (),
        .frame_counter      (),
        .register_selector  (),
        .active_addr        (),
        .dynamic_addr_valid (),
        .read_valid         ()
    );

    i3c_sensor_target_demo #(
        .CLK_FREQ_HZ    (CLK_FREQ_HZ),
        .STATIC_ADDR     (7'h34),
        .TARGET_INDEX    (4),
        .PROVISIONAL_ID  (48'h4100_0000_0005)
    ) u_tgt4 (
        .clk               (clk_100m),
        .rst_n              (demo_rst_n),
        .scl                (scl_bus),
        .sda                (sda_bus),
        .sda_oe             (tgt4_sda_oe),
        .sample_payload     (),
        .frame_counter      (),
        .register_selector  (),
        .active_addr        (),
        .dynamic_addr_valid (),
        .read_valid         ()
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
