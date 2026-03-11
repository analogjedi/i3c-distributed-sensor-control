`timescale 1ns/1ps

module tb_i3c_fpga_test_system;

    reg clk;
    reg rst_n;

    wire scl_o;
    wire scl_oe;
    wire sda_o;
    wire sda_oe;
    tri1 scl_line;
    tri1 sda_line;

    wire       boot_done;
    wire       boot_error;
    wire       capture_error;
    wire [4:0] sample_valid_bitmap;
    wire [399:0] sample_payloads_flat;
    wire [79:0] sample_capture_count_flat;
    wire [6:0] last_service_addr;
    wire [7:0] last_service_count;

    wire [79:0] sample_payload_0;
    wire [79:0] sample_payload_1;
    wire [79:0] sample_payload_2;
    wire [79:0] sample_payload_3;
    wire [79:0] sample_payload_4;
    wire [15:0] frame_counter_0;
    wire [15:0] frame_counter_1;
    wire [15:0] frame_counter_2;
    wire [15:0] frame_counter_3;
    wire [15:0] frame_counter_4;
    wire [7:0]  selector_0;
    wire [7:0]  selector_1;
    wire [7:0]  selector_2;
    wire [7:0]  selector_3;
    wire [7:0]  selector_4;

    assign scl_line = scl_oe ? scl_o : 1'bz;
    assign sda_line = sda_oe ? sda_o : 1'bz;

    i3c_sensor_controller_demo u_ctrl_demo (
        .clk                   (clk),
        .rst_n                 (rst_n),
        .scl_o                 (scl_o),
        .scl_oe                (scl_oe),
        .sda_o                 (sda_o),
        .sda_oe                (sda_oe),
        .sda_i                 (sda_line),
        .boot_done             (boot_done),
        .boot_error            (boot_error),
        .capture_error         (capture_error),
        .sample_valid_bitmap   (sample_valid_bitmap),
        .sample_payloads_flat  (sample_payloads_flat),
        .sample_capture_count_flat(sample_capture_count_flat),
        .last_service_addr     (last_service_addr),
        .last_service_count    (last_service_count)
    );

    i3c_sensor_target_demo #(
        .TARGET_INDEX (0),
        .STATIC_ADDR  (7'h30),
        .PROVISIONAL_ID(48'h4100_0000_0001)
    ) target0 (
        .clk            (clk),
        .rst_n          (rst_n),
        .scl            (scl_line),
        .sda            (sda_line),
        .sample_payload (sample_payload_0),
        .frame_counter  (frame_counter_0),
        .register_selector(selector_0),
        .active_addr    (),
        .dynamic_addr_valid(),
        .read_valid     ()
    );

    i3c_sensor_target_demo #(
        .TARGET_INDEX (1),
        .STATIC_ADDR  (7'h31),
        .PROVISIONAL_ID(48'h4100_0000_0002)
    ) target1 (
        .clk            (clk),
        .rst_n          (rst_n),
        .scl            (scl_line),
        .sda            (sda_line),
        .sample_payload (sample_payload_1),
        .frame_counter  (frame_counter_1),
        .register_selector(selector_1),
        .active_addr    (),
        .dynamic_addr_valid(),
        .read_valid     ()
    );

    i3c_sensor_target_demo #(
        .TARGET_INDEX (2),
        .STATIC_ADDR  (7'h32),
        .PROVISIONAL_ID(48'h4100_0000_0003)
    ) target2 (
        .clk            (clk),
        .rst_n          (rst_n),
        .scl            (scl_line),
        .sda            (sda_line),
        .sample_payload (sample_payload_2),
        .frame_counter  (frame_counter_2),
        .register_selector(selector_2),
        .active_addr    (),
        .dynamic_addr_valid(),
        .read_valid     ()
    );

    i3c_sensor_target_demo #(
        .TARGET_INDEX (3),
        .STATIC_ADDR  (7'h33),
        .PROVISIONAL_ID(48'h4100_0000_0004)
    ) target3 (
        .clk            (clk),
        .rst_n          (rst_n),
        .scl            (scl_line),
        .sda            (sda_line),
        .sample_payload (sample_payload_3),
        .frame_counter  (frame_counter_3),
        .register_selector(selector_3),
        .active_addr    (),
        .dynamic_addr_valid(),
        .read_valid     ()
    );

    i3c_sensor_target_demo #(
        .TARGET_INDEX (4),
        .STATIC_ADDR  (7'h34),
        .PROVISIONAL_ID(48'h4100_0000_0005)
    ) target4 (
        .clk            (clk),
        .rst_n          (rst_n),
        .scl            (scl_line),
        .sda            (sda_line),
        .sample_payload (sample_payload_4),
        .frame_counter  (frame_counter_4),
        .register_selector(selector_4),
        .active_addr    (),
        .dynamic_addr_valid(),
        .read_valid     ()
    );

    always #5 clk = ~clk;

    initial begin
        clk   = 1'b0;
        rst_n = 1'b0;

        $dumpfile("tb_i3c_fpga_test_system.vcd");
        $dumpvars(0, tb_i3c_fpga_test_system);

        #200;
        rst_n = 1'b1;

        wait_for_boot;
        wait_for_capture_counts;

        if (boot_error || capture_error) begin
            $display("FAIL: demo controller flagged boot_error=%0d capture_error=%0d", boot_error, capture_error);
            $finish(1);
        end

        if (sample_valid_bitmap != 5'b1_1111) begin
            $display("FAIL: expected all five sample-valid bits, got %b", sample_valid_bitmap);
            $finish(1);
        end

        if ((selector_0 != 8'h40) || (selector_1 != 8'h40) || (selector_2 != 8'h40) ||
            (selector_3 != 8'h40) || (selector_4 != 8'h40)) begin
            $display("FAIL: selector mismatch 0=%02h 1=%02h 2=%02h 3=%02h 4=%02h",
                     selector_0, selector_1, selector_2, selector_3, selector_4);
            $finish(1);
        end

        compare_payload(0, sample_payload_0);
        compare_payload(1, sample_payload_1);
        compare_payload(2, sample_payload_2);
        compare_payload(3, sample_payload_3);
        compare_payload(4, sample_payload_4);

        if ((frame_counter_0 == 16'h0000) || (frame_counter_1 == 16'h0000) ||
            (frame_counter_2 == 16'h0000) || (frame_counter_3 == 16'h0000) ||
            (frame_counter_4 == 16'h0000)) begin
            $display("FAIL: expected all target frame counters to advance");
            $finish(1);
        end

        if (last_service_count != 8'd10) begin
            $display("FAIL: expected last service byte count 10, got %0d", last_service_count);
            $finish(1);
        end

        $display("PASS");
        #100;
        $finish;
    end

    initial begin
        #20_000_000;
        $display("FAIL: timeout");
        $finish(1);
    end

    task wait_for_boot;
        integer cycles;
        begin
            cycles = 0;
            while (!boot_done && !boot_error && (cycles < 2_000_000)) begin
                @(posedge clk);
                cycles = cycles + 1;
            end
            if (!boot_done) begin
                $display("FAIL: boot did not complete boot_done=%0d boot_error=%0d state=%0d idx=%0d dccc_nack=%0d target=0x%02h",
                         boot_done, boot_error, u_ctrl_demo.boot_state, u_ctrl_demo.boot_index,
                         u_ctrl_demo.dccc_rsp_nack, u_ctrl_demo.dccc_target_addr);
                $finish(1);
            end
        end
    endtask

    task wait_for_capture_counts;
        integer cycles;
        begin
            cycles = 0;
            while ((((sample_capture_count_flat[15:0]   < 16'd2) ||
                     (sample_capture_count_flat[31:16]  < 16'd2) ||
                     (sample_capture_count_flat[47:32]  < 16'd2) ||
                     (sample_capture_count_flat[63:48]  < 16'd2) ||
                     (sample_capture_count_flat[79:64]  < 16'd2)) ||
                    (sample_valid_bitmap != 5'b1_1111)) &&
                   (cycles < 5_000_000)) begin
                @(posedge clk);
                cycles = cycles + 1;
            end
            if ((sample_capture_count_flat[15:0]   < 16'd2) ||
                (sample_capture_count_flat[31:16]  < 16'd2) ||
                (sample_capture_count_flat[47:32]  < 16'd2) ||
                (sample_capture_count_flat[63:48]  < 16'd2) ||
                (sample_capture_count_flat[79:64]  < 16'd2)) begin
                $display("FAIL: capture counts did not advance evenly c0=%0d c1=%0d c2=%0d c3=%0d c4=%0d",
                         sample_capture_count_flat[15:0], sample_capture_count_flat[31:16],
                         sample_capture_count_flat[47:32], sample_capture_count_flat[63:48],
                         sample_capture_count_flat[79:64]);
                $finish(1);
            end
        end
    endtask

    task compare_payload;
        input integer endpoint_index;
        input [79:0] current_target_payload;
        reg [79:0] captured_payload;
        reg [7:0]  frame_lsb;
        reg [15:0] ch0;
        reg [15:0] ch1;
        reg [15:0] ch2;
        reg [15:0] ch3;
        reg [7:0]  temperature;
        reg [7:0]  misc_status;
        reg [79:0] expected_payload;
        reg [15:0] expected_ch0;
        reg [15:0] expected_ch1;
        reg [15:0] expected_ch2;
        reg [15:0] expected_ch3;
        reg [7:0]  current_frame_lsb;
        begin
            captured_payload = sample_payloads_flat[endpoint_index*80 +: 80];
            ch0         = {captured_payload[15:8], captured_payload[7:0]};
            ch1         = {captured_payload[31:24], captured_payload[23:16]};
            ch2         = {captured_payload[47:40], captured_payload[39:32]};
            ch3         = {captured_payload[63:56], captured_payload[55:48]};
            temperature = captured_payload[71:64];
            misc_status = captured_payload[79:72];
            frame_lsb   = ch0[7:0];
            current_frame_lsb = current_target_payload[7:0];

            expected_ch0 = 16'h1000 + (endpoint_index << 8) + frame_lsb;
            expected_ch1 = 16'h2000 + (endpoint_index << 8) + ((frame_lsb << 1) + frame_lsb);
            expected_ch2 = 16'h3000 + (endpoint_index << 8) + ((frame_lsb << 2) + frame_lsb);
            expected_ch3 = 16'h4000 + (endpoint_index << 8) + ((frame_lsb << 3) - frame_lsb);

            expected_payload = {
                {endpoint_index[2:0], frame_lsb[4:0]},
                (8'h50 + endpoint_index[7:0] + frame_lsb[3:0]),
                expected_ch3[15:8], expected_ch3[7:0],
                expected_ch2[15:8], expected_ch2[7:0],
                expected_ch1[15:8], expected_ch1[7:0],
                expected_ch0[15:8], expected_ch0[7:0]
            };

            if (captured_payload != expected_payload) begin
                $display("FAIL: endpoint%0d payload signature mismatch captured=0x%020h expected=0x%020h",
                         endpoint_index, captured_payload, expected_payload);
                $finish(1);
            end

            if ((captured_payload != current_target_payload) &&
                (frame_lsb != current_frame_lsb) &&
                (frame_lsb + 1'b1 != current_frame_lsb)) begin
                $display("FAIL: endpoint%0d captured frame is not aligned to recent target state captured=0x%020h current=0x%020h",
                         endpoint_index, captured_payload, current_target_payload);
                $finish(1);
            end
        end
    endtask

endmodule
