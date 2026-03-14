`timescale 1ns/1ps

module tb_i3c_dual_target_lab_controller;

    localparam integer CLK_FREQ_HZ = 100_000_000;
    localparam integer I3C_SDR_HZ  = 12_500_000;

    reg clk = 1'b0;
    reg rst_n = 1'b0;

    always #5 clk = ~clk;

    wire scl_bus;
    wire sda_bus;
    wire ctrl_scl_o;
    wire ctrl_scl_oe;
    wire ctrl_sda_o;
    wire ctrl_sda_oe;
    wire tgt0_sda_oe;
    wire tgt1_sda_oe;

    reg  host_cmd_valid;
    wire host_cmd_ready;
    reg  host_cmd_read;
    reg  host_cmd_target;
    reg  [7:0] host_cmd_reg_addr;
    reg  [7:0] host_cmd_write_value;
    reg  [7:0] host_cmd_read_len;
    wire host_rsp_valid;
    wire host_rsp_error;
    wire [7:0] host_rsp_len;
    wire [127:0] host_rsp_data;

    wire boot_done;
    wire boot_error;
    wire capture_error;
    wire [1:0] verified_bitmap;
    wire [1:0] sample_valid_bitmap;
    wire [1:0] target_led_state;
    wire [63:0] signature_flat;
    wire [159:0] sample_payloads_flat;
    wire [31:0] sample_capture_count_flat;
    wire [31:0] status_word_flat;
    wire [6:0] last_service_addr;
    wire [6:0] last_recovery_addr;
    wire tgt0_indicator;
    wire tgt1_indicator;

    assign scl_bus = ~(ctrl_scl_oe & ~ctrl_scl_o);
    assign sda_bus = ~((ctrl_sda_oe & ~ctrl_sda_o) | tgt0_sda_oe | tgt1_sda_oe);

    i3c_dual_target_lab_controller #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .I3C_SDR_HZ (I3C_SDR_HZ)
    ) dut (
        .clk                   (clk),
        .rst_n                 (rst_n),
        .scl_o                 (ctrl_scl_o),
        .scl_oe                (ctrl_scl_oe),
        .sda_o                 (ctrl_sda_o),
        .sda_oe                (ctrl_sda_oe),
        .sda_i                 (sda_bus),
        .host_cmd_valid        (host_cmd_valid),
        .host_cmd_ready        (host_cmd_ready),
        .host_cmd_read         (host_cmd_read),
        .host_cmd_target       (host_cmd_target),
        .host_cmd_reg_addr     (host_cmd_reg_addr),
        .host_cmd_write_value  (host_cmd_write_value),
        .host_cmd_read_len     (host_cmd_read_len),
        .host_rsp_valid        (host_rsp_valid),
        .host_rsp_error        (host_rsp_error),
        .host_rsp_len          (host_rsp_len),
        .host_rsp_data         (host_rsp_data),
        .boot_done             (boot_done),
        .boot_error            (boot_error),
        .capture_error         (capture_error),
        .recovery_active       (),
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
        .SAMPLE_RATE_HZ  (2_000),
        .STATIC_ADDR     (7'h30),
        .TARGET_INDEX    (0),
        .PROVISIONAL_ID  (48'h4100_0000_0011),
        .TARGET_SIGNATURE(32'h534E_0100)
    ) u_tgt0 (
        .clk              (clk),
        .rst_n            (rst_n),
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
        .SAMPLE_RATE_HZ  (2_000),
        .STATIC_ADDR     (7'h31),
        .TARGET_INDEX    (1),
        .PROVISIONAL_ID  (48'h4100_0000_0012),
        .TARGET_SIGNATURE(32'h534E_0101)
    ) u_tgt1 (
        .clk              (clk),
        .rst_n            (rst_n),
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

    task automatic issue_read;
        input        target;
        input [7:0]  reg_addr;
        input [7:0]  read_len;
        output [127:0] data;
        begin
            @(posedge clk);
            while (!host_cmd_ready) @(posedge clk);
            host_cmd_valid       <= 1'b1;
            host_cmd_read        <= 1'b1;
            host_cmd_target      <= target;
            host_cmd_reg_addr    <= reg_addr;
            host_cmd_write_value <= 8'h00;
            host_cmd_read_len    <= read_len;
            @(posedge clk);
            host_cmd_valid <= 1'b0;
            while (!host_rsp_valid) @(posedge clk);
            if (host_rsp_error) begin
                $display("FAIL: host read returned error target=%0d reg=0x%02x", target, reg_addr);
                $finish;
            end
            if (host_rsp_len != read_len) begin
                $display("FAIL: host read length mismatch got=%0d exp=%0d", host_rsp_len, read_len);
                $finish;
            end
            data = host_rsp_data;
        end
    endtask

    task automatic issue_write;
        input        target;
        input [7:0]  reg_addr;
        input [7:0]  value;
        begin
            @(posedge clk);
            while (!host_cmd_ready) @(posedge clk);
            host_cmd_valid       <= 1'b1;
            host_cmd_read        <= 1'b0;
            host_cmd_target      <= target;
            host_cmd_reg_addr    <= reg_addr;
            host_cmd_write_value <= value;
            host_cmd_read_len    <= 8'd1;
            @(posedge clk);
            host_cmd_valid <= 1'b0;
            while (!host_rsp_valid) @(posedge clk);
            if (host_rsp_error) begin
                $display("FAIL: host write returned error target=%0d reg=0x%02x", target, reg_addr);
                $finish;
            end
        end
    endtask

    reg [127:0] readback;

    initial begin
        $dumpfile("tb_i3c_dual_target_lab_controller.vcd");
        $dumpvars(0, tb_i3c_dual_target_lab_controller);

        host_cmd_valid       = 1'b0;
        host_cmd_read        = 1'b0;
        host_cmd_target      = 1'b0;
        host_cmd_reg_addr    = 8'h00;
        host_cmd_write_value = 8'h00;
        host_cmd_read_len    = 8'h00;

        repeat (20) @(posedge clk);
        rst_n = 1'b1;

        wait (boot_done);
        if (boot_error) begin
            $display("FAIL: boot_error asserted");
            $finish;
        end
        if (verified_bitmap != 2'b11) begin
            $display("FAIL: verified_bitmap=%b", verified_bitmap);
            $finish;
        end

        wait (sample_valid_bitmap == 2'b11);

        issue_read(1'b0, 8'h00, 8'd4, readback);
        if (readback[31:0] != 32'h534E_0100) begin
            $display("FAIL: target0 signature mismatch 0x%08x", readback[31:0]);
            $finish;
        end

        issue_read(1'b1, 8'h00, 8'd4, readback);
        if (readback[31:0] != 32'h534E_0101) begin
            $display("FAIL: target1 signature mismatch 0x%08x", readback[31:0]);
            $finish;
        end

        issue_write(1'b0, 8'h04, 8'h01);
        issue_write(1'b1, 8'h04, 8'h01);
        repeat (20) @(posedge clk);

        if (!tgt0_indicator || !tgt1_indicator) begin
            $display("FAIL: target indicators not asserted tgt0=%0d tgt1=%0d", tgt0_indicator, tgt1_indicator);
            $finish;
        end

        issue_read(1'b0, 8'h04, 8'd1, readback);
        if (readback[7:0] != 8'h01) begin
            $display("FAIL: target0 control readback mismatch 0x%02x", readback[7:0]);
            $finish;
        end

        issue_read(1'b1, 8'h10, 8'd10, readback);
        if (readback[79:0] == 80'h0) begin
            $display("FAIL: target1 sample payload readback is zero");
            $finish;
        end

        issue_write(1'b1, 8'h04, 8'h00);
        repeat (20) @(posedge clk);
        if (tgt1_indicator) begin
            $display("FAIL: target1 indicator failed to clear");
            $finish;
        end

        $display("PASS: dual-target lab controller boot, polling, register read/write, and LED control");
        $finish;
    end

    initial begin
        #20_000_000;
        $display("FAIL: timeout state=%0d boot_done=%0d boot_error=%0d capture_error=%0d verified=%b sample_valid=%b",
                 dut.state, boot_done, boot_error, capture_error, verified_bitmap, sample_valid_bitmap);
        $finish;
    end

endmodule
