`timescale 1ns/1ps

module spartan7_i3c_dual_target_lab_top #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer I3C_SDR_HZ  = 12_500_000
) (
    input  wire       clk_12mhz,
    input  wire       btn_reset,
    output wire [3:0] led_sample_valid,
    output wire       led_sv4,
    output wire       led_boot_done,
    output wire       led_error,
    output wire       uart_txd,
    input  wire       uart_rxd
);

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

    wire sys_rst_n = mmcm_locked & ~btn_reset;

    wire [7:0] uart_rx_data;
    wire       uart_rx_valid;
    wire [7:0] uart_tx_data;
    wire       uart_tx_valid;
    wire       uart_tx_ready;
    wire       soft_start;

    uart_rx #(
        .CLK_FREQ_HZ (CLK_FREQ_HZ),
        .BAUD_RATE   (115200)
    ) u_uart_rx (
        .clk     (clk_100m),
        .rst_n   (sys_rst_n),
        .rx_pin  (uart_rxd),
        .rx_data (uart_rx_data),
        .rx_valid(uart_rx_valid)
    );

    uart_tx #(
        .CLK_FREQ_HZ (CLK_FREQ_HZ),
        .BAUD_RATE   (115200)
    ) u_uart_tx (
        .clk     (clk_100m),
        .rst_n   (sys_rst_n),
        .tx_data (uart_tx_data),
        .tx_valid(uart_tx_valid),
        .tx_ready(uart_tx_ready),
        .tx_pin  (uart_txd)
    );

    reg demo_started;
    always @(posedge clk_100m or negedge sys_rst_n) begin
        if (!sys_rst_n)
            demo_started <= 1'b0;
        else if (soft_start)
            demo_started <= 1'b1;
    end

    wire demo_rst_n = sys_rst_n & demo_started;

    wire scl_bus;
    wire sda_bus;
    wire ctrl_scl_o;
    wire ctrl_scl_oe;
    wire ctrl_sda_o;
    wire ctrl_sda_oe;
    wire tgt0_sda_oe;
    wire tgt1_sda_oe;

    assign scl_bus = ~(ctrl_scl_oe & ~ctrl_scl_o);
    assign sda_bus = ~((ctrl_sda_oe & ~ctrl_sda_o) | tgt0_sda_oe | tgt1_sda_oe);

    wire       boot_done;
    wire       boot_error;
    wire       capture_error;
    wire       recovery_active;
    wire [1:0] verified_bitmap;
    wire [1:0] sample_valid_bitmap;
    wire [1:0] target_led_state;
    wire [63:0] signature_flat;
    wire [159:0] sample_payloads_flat;
    wire [31:0] sample_capture_count_flat;
    wire [31:0] status_word_flat;
    wire [6:0] last_service_addr;
    wire [6:0] last_recovery_addr;

    wire       ctrl_cmd_valid;
    wire       ctrl_cmd_ready;
    wire       ctrl_cmd_read;
    wire       ctrl_cmd_target;
    wire [7:0] ctrl_cmd_reg_addr;
    wire [7:0] ctrl_cmd_write_value;
    wire [7:0] ctrl_cmd_read_len;
    wire       ctrl_rsp_valid;
    wire       ctrl_rsp_error;
    wire [7:0] ctrl_rsp_len;
    wire [127:0] ctrl_rsp_data;
    wire       ctrl_ccc_valid;
    wire       ctrl_ccc_ready;
    wire       ctrl_ccc_direct;
    wire       ctrl_ccc_target;
    wire [7:0] ctrl_ccc_code;
    wire [7:0] ctrl_ccc_arg;
    wire       ctrl_ccc_rsp_valid;
    wire       ctrl_ccc_rsp_error;
    wire [7:0] ctrl_ccc_rsp_len;
    wire [47:0] ctrl_ccc_rsp_data;

    wire tgt0_indicator;
    wire tgt1_indicator;

    assign led_sample_valid[0] = tgt0_indicator;
    assign led_sample_valid[1] = tgt1_indicator;
    assign led_sample_valid[2] = sample_valid_bitmap[0];
    assign led_sample_valid[3] = sample_valid_bitmap[1];
    assign led_sv4             = recovery_active;
    assign led_boot_done       = boot_done;
    assign led_error           = boot_error | capture_error;

    uart_dual_target_lab_cmd_handler #(
        .MAX_READ_BYTES(16),
        .PAYLOAD_BYTES (10)
    ) u_cmd_handler (
        .clk              (clk_100m),
        .rst_n            (sys_rst_n),
        .rx_data          (uart_rx_data),
        .rx_valid         (uart_rx_valid),
        .tx_data          (uart_tx_data),
        .tx_valid         (uart_tx_valid),
        .tx_ready         (uart_tx_ready),
        .soft_start       (soft_start),
        .boot_done        (boot_done),
        .boot_error       (boot_error),
        .capture_error    (capture_error),
        .recovery_active  (recovery_active),
        .verified_bitmap  (verified_bitmap),
        .sample_valid_bitmap(sample_valid_bitmap),
        .target_led_state (target_led_state),
        .signature_flat   (signature_flat),
        .sample_payloads_flat(sample_payloads_flat),
        .ctrl_cmd_valid   (ctrl_cmd_valid),
        .ctrl_cmd_ready   (ctrl_cmd_ready),
        .ctrl_cmd_read    (ctrl_cmd_read),
        .ctrl_cmd_target  (ctrl_cmd_target),
        .ctrl_cmd_reg_addr(ctrl_cmd_reg_addr),
        .ctrl_cmd_write_value(ctrl_cmd_write_value),
        .ctrl_cmd_read_len(ctrl_cmd_read_len),
        .ctrl_rsp_valid   (ctrl_rsp_valid),
        .ctrl_rsp_error   (ctrl_rsp_error),
        .ctrl_rsp_len     (ctrl_rsp_len),
        .ctrl_rsp_data    (ctrl_rsp_data),
        .ccc_cmd_valid    (ctrl_ccc_valid),
        .ccc_cmd_ready    (ctrl_ccc_ready),
        .ccc_cmd_direct   (ctrl_ccc_direct),
        .ccc_cmd_target   (ctrl_ccc_target),
        .ccc_cmd_code     (ctrl_ccc_code),
        .ccc_cmd_arg      (ctrl_ccc_arg),
        .ccc_rsp_valid    (ctrl_ccc_rsp_valid),
        .ccc_rsp_error    (ctrl_ccc_rsp_error),
        .ccc_rsp_len      (ctrl_ccc_rsp_len),
        .ccc_rsp_data     (ctrl_ccc_rsp_data)
    );

    i3c_dual_target_lab_controller #(
        .CLK_FREQ_HZ (CLK_FREQ_HZ),
        .I3C_SDR_HZ  (I3C_SDR_HZ)
    ) u_controller (
        .clk                   (clk_100m),
        .rst_n                 (demo_rst_n),
        .scl_o                 (ctrl_scl_o),
        .scl_oe                (ctrl_scl_oe),
        .sda_o                 (ctrl_sda_o),
        .sda_oe                (ctrl_sda_oe),
        .sda_i                 (sda_bus),
        .host_cmd_valid        (ctrl_cmd_valid),
        .host_cmd_ready        (ctrl_cmd_ready),
        .host_cmd_read         (ctrl_cmd_read),
        .host_cmd_target       (ctrl_cmd_target),
        .host_cmd_reg_addr     (ctrl_cmd_reg_addr),
        .host_cmd_write_value  (ctrl_cmd_write_value),
        .host_cmd_read_len     (ctrl_cmd_read_len),
        .host_rsp_valid        (ctrl_rsp_valid),
        .host_rsp_error        (ctrl_rsp_error),
        .host_rsp_len          (ctrl_rsp_len),
        .host_rsp_data         (ctrl_rsp_data),
        .host_ccc_valid        (ctrl_ccc_valid),
        .host_ccc_ready        (ctrl_ccc_ready),
        .host_ccc_direct       (ctrl_ccc_direct),
        .host_ccc_target       (ctrl_ccc_target),
        .host_ccc_code         (ctrl_ccc_code),
        .host_ccc_arg          (ctrl_ccc_arg),
        .host_ccc_rsp_valid    (ctrl_ccc_rsp_valid),
        .host_ccc_rsp_error    (ctrl_ccc_rsp_error),
        .host_ccc_rsp_len      (ctrl_ccc_rsp_len),
        .host_ccc_rsp_data     (ctrl_ccc_rsp_data),
        .boot_done             (boot_done),
        .boot_error            (boot_error),
        .capture_error         (capture_error),
        .recovery_active       (recovery_active),
        .verified_bitmap       (verified_bitmap),
        .sample_valid_bitmap   (sample_valid_bitmap),
        .target_led_state      (target_led_state),
        .signature_flat        (signature_flat),
        .sample_payloads_flat  (sample_payloads_flat),
        .sample_capture_count_flat(sample_capture_count_flat),
        .status_word_flat      (status_word_flat),
        .last_service_addr     (last_service_addr),
        .last_recovery_addr    (last_recovery_addr)
    );

    i3c_sensor_gpio_target_demo #(
        .CLK_FREQ_HZ     (CLK_FREQ_HZ),
        .STATIC_ADDR     (7'h30),
        .TARGET_INDEX    (0),
        .PROVISIONAL_ID  (48'h4100_0000_0011),
        .TARGET_SIGNATURE(32'h534E_0100)
    ) u_tgt0 (
        .clk              (clk_100m),
        .rst_n            (demo_rst_n),
        .scl              (scl_bus),
        .sda              (sda_bus),
        .sda_oe           (tgt0_sda_oe),
        .indicator_out    (tgt0_indicator),
        .sample_payload   (),
        .signature_word   (),
        .control_reg      (),
        .register_pointer (),
        .frame_counter    (),
        .active_addr      (),
        .dynamic_addr_valid(),
        .read_valid       ()
    );

    i3c_sensor_gpio_target_demo #(
        .CLK_FREQ_HZ     (CLK_FREQ_HZ),
        .STATIC_ADDR     (7'h31),
        .TARGET_INDEX    (1),
        .PROVISIONAL_ID  (48'h4100_0000_0012),
        .TARGET_SIGNATURE(32'h534E_0101)
    ) u_tgt1 (
        .clk              (clk_100m),
        .rst_n            (demo_rst_n),
        .scl              (scl_bus),
        .sda              (sda_bus),
        .sda_oe           (tgt1_sda_oe),
        .indicator_out    (tgt1_indicator),
        .sample_payload   (),
        .signature_word   (),
        .control_reg      (),
        .register_pointer (),
        .frame_counter    (),
        .active_addr      (),
        .dynamic_addr_valid(),
        .read_valid       ()
    );

endmodule
