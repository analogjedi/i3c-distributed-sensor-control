`timescale 1ns/1ps

module tb_i3c_known_target_hub;

    localparam integer TARGET_COUNT = 5;
    localparam integer PAYLOAD_BYTES = 10;
    localparam integer MAX_SERVICE_BYTES = 16;
    localparam [6:0] STATIC_ADDR_BASE = 7'h30;
    localparam [6:0] DYN_ADDR_BASE    = 7'h10;
    localparam [47:0] PROVISIONAL_ID_BASE = 48'h4100_0000_0001;
    localparam [7:0] TARGET_BCR = 8'h21;
    localparam [7:0] TARGET_DCR = 8'h90;

    reg clk;
    reg rst_n;

    wire scl_o;
    wire scl_oe;
    wire sda_o;
    wire sda_oe;
    wire scl_line;
    wire sda_line;

    reg  [TARGET_COUNT-1:0] clear_dynamic_addr;
    reg  [TARGET_COUNT-1:0] fault_diag_ibi_req;
    wire [TARGET_COUNT-1:0] target_sda_oe;
    wire [TARGET_COUNT-1:0] dynamic_addr_valid;
    wire [6:0] active_addr [0:TARGET_COUNT-1];
    wire [7:0] event_enable_mask [0:TARGET_COUNT-1];

    wire boot_done;
    wire boot_error;
    wire capture_error;
    wire recovery_active;
    wire fault_diag_irq;
    wire [TARGET_COUNT-1:0] verified_bitmap;
    wire [TARGET_COUNT-1:0] recovered_bitmap;
    wire [TARGET_COUNT-1:0] fault_diag_seen_bitmap;
    wire [TARGET_COUNT-1:0] fault_diag_enable_bitmap;
    wire [TARGET_COUNT-1:0] sample_valid_bitmap;
    wire [TARGET_COUNT*PAYLOAD_BYTES*8-1:0] sample_payloads_flat;
    wire [TARGET_COUNT*16-1:0] sample_capture_count_flat;
    wire [6:0] last_service_addr;
    wire [7:0] last_service_count;
    wire [6:0] last_recovery_addr;
    wire [6:0] last_diag_addr;
    wire [15:0] last_status_word;

    genvar gi;
    integer i;
    reg [15:0] count_before_recovery;
    reg [79:0] expected_payload [0:TARGET_COUNT-1];

    pullup (scl_line);
    assign scl_line = scl_oe ? scl_o : 1'bz;
    assign sda_line = ~((sda_oe & ~sda_o) |
                        target_sda_oe[0] |
                        target_sda_oe[1] |
                        target_sda_oe[2] |
                        target_sda_oe[3] |
                        target_sda_oe[4]);

    i3c_known_target_hub #(
        .ENDPOINT_COUNT    (TARGET_COUNT),
        .MAX_SERVICE_BYTES (MAX_SERVICE_BYTES),
        .PAYLOAD_BYTES     (PAYLOAD_BYTES),
        .CLK_FREQ_HZ       (100_000_000),
        .I3C_SDR_HZ        (12_500_000),
        .SAMPLE_RATE_HZ    (2_000),
        .DYN_ADDR_BASE     (DYN_ADDR_BASE),
        .STATIC_ADDR_BASE  (STATIC_ADDR_BASE),
        .PROVISIONAL_ID_BASE(PROVISIONAL_ID_BASE),
        .TARGET_BCR        (TARGET_BCR),
        .TARGET_DCR        (TARGET_DCR)
    ) dut (
        .clk                     (clk),
        .rst_n                   (rst_n),
        .scl_o                   (scl_o),
        .scl_oe                  (scl_oe),
        .sda_o                   (sda_o),
        .sda_oe                  (sda_oe),
        .sda_i                   (sda_line),
        .fault_diag_ibi_req      (fault_diag_ibi_req),
        .boot_done               (boot_done),
        .boot_error              (boot_error),
        .capture_error           (capture_error),
        .recovery_active         (recovery_active),
        .fault_diag_irq          (fault_diag_irq),
        .verified_bitmap         (verified_bitmap),
        .recovered_bitmap        (recovered_bitmap),
        .fault_diag_seen_bitmap  (fault_diag_seen_bitmap),
        .fault_diag_enable_bitmap(fault_diag_enable_bitmap),
        .sample_valid_bitmap     (sample_valid_bitmap),
        .sample_payloads_flat    (sample_payloads_flat),
        .sample_capture_count_flat(sample_capture_count_flat),
        .last_service_addr       (last_service_addr),
        .last_service_count      (last_service_count),
        .last_recovery_addr      (last_recovery_addr),
        .last_diag_addr          (last_diag_addr),
        .last_status_word        (last_status_word)
    );

    generate
        for (gi = 0; gi < TARGET_COUNT; gi = gi + 1) begin : g_targets
            i3c_target_top #(
                .MAX_READ_BYTES (PAYLOAD_BYTES),
                .STATIC_ADDR    (STATIC_ADDR_BASE + gi[6:0]),
                .PROVISIONAL_ID (PROVISIONAL_ID_BASE + gi),
                .TARGET_BCR     (TARGET_BCR),
                .TARGET_DCR     (TARGET_DCR)
            ) target (
                .clk                     (clk),
                .rst_n                   (rst_n),
                .scl                     (scl_line),
                .sda                     (sda_line),
                .sda_oe                  (target_sda_oe[gi]),
                .clear_dynamic_addr      (clear_dynamic_addr[gi]),
                .assign_dynamic_addr_valid(1'b0),
                .assign_dynamic_addr     (7'h00),
                .read_data               (expected_payload[gi]),
                .write_data              (),
                .write_valid             (),
                .register_selector       (),
                .read_valid              (),
                .selected                (),
                .active_addr             (active_addr[gi]),
                .dynamic_addr_valid      (dynamic_addr_valid[gi]),
                .provisional_id          (),
                .event_enable_mask       (event_enable_mask[gi]),
                .rstact_action           (),
                .status_word             (),
                .activity_state          (),
                .group_addr_valid        (),
                .group_addr              (),
                .max_write_len           (),
                .max_read_len            (),
                .ibi_data_len            (),
                .last_ccc                ()
            );
        end
    endgenerate

    always #5 clk = ~clk;

    function [15:0] capture_count_for;
        input integer idx;
        begin
            capture_count_for = sample_capture_count_flat[idx*16 +: 16];
        end
    endfunction

    task wait_for_all_samples;
        begin
            while (sample_valid_bitmap != {TARGET_COUNT{1'b1}}) @(posedge clk);
        end
    endtask

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        clear_dynamic_addr = {TARGET_COUNT{1'b0}};
        fault_diag_ibi_req = {TARGET_COUNT{1'b0}};
        count_before_recovery = 16'h0000;

        expected_payload[0] = 80'hA9_A8_A7_A6_A5_A4_A3_A2_A1_A0;
        expected_payload[1] = 80'hB9_B8_B7_B6_B5_B4_B3_B2_B1_B0;
        expected_payload[2] = 80'hC9_C8_C7_C6_C5_C4_C3_C2_C1_C0;
        expected_payload[3] = 80'hD9_D8_D7_D6_D5_D4_D3_D2_D1_D0;
        expected_payload[4] = 80'hE9_E8_E7_E6_E5_E4_E3_E2_E1_E0;

        $dumpfile("tb_i3c_known_target_hub.vcd");
        $dumpvars(0, tb_i3c_known_target_hub);

        #200;
        rst_n = 1'b1;

        while (!boot_done && !boot_error) @(posedge clk);
        if (boot_error) begin
            $display("FAIL: boot_error asserted");
            $finish(1);
        end

        if (verified_bitmap != {TARGET_COUNT{1'b1}}) begin
            $display("FAIL: not all targets verified bitmap=0x%0h", verified_bitmap);
            $finish(1);
        end

        if (fault_diag_enable_bitmap != {TARGET_COUNT{1'b1}}) begin
            $display("FAIL: fault diagnostic IBI mask not enabled bitmap=0x%0h", fault_diag_enable_bitmap);
            $finish(1);
        end

        for (i = 0; i < TARGET_COUNT; i = i + 1) begin
            if (!dynamic_addr_valid[i] || (active_addr[i] != (DYN_ADDR_BASE + i[6:0])) || (event_enable_mask[i] != 8'h01)) begin
                $display("FAIL: target %0d boot state mismatch dyn_valid=%0d addr=0x%02h event_mask=0x%02h",
                         i, dynamic_addr_valid[i], active_addr[i], event_enable_mask[i]);
                $finish(1);
            end
        end

        wait_for_all_samples();
        if (last_service_count != PAYLOAD_BYTES[7:0]) begin
            $display("FAIL: expected 10-byte scheduled service count got %0d", last_service_count);
            $finish(1);
        end

        if (sample_payloads_flat[2*PAYLOAD_BYTES*8 +: PAYLOAD_BYTES*8] != expected_payload[2]) begin
            $display("FAIL: target 2 payload mismatch got=0x%020h expected=0x%020h",
                     sample_payloads_flat[2*PAYLOAD_BYTES*8 +: PAYLOAD_BYTES*8], expected_payload[2]);
            $finish(1);
        end

        count_before_recovery = capture_count_for(2);
        @(posedge clk);
        clear_dynamic_addr[2] <= 1'b1;
        @(posedge clk);
        clear_dynamic_addr[2] <= 1'b0;

        while (!recovered_bitmap[2] && !boot_error && !capture_error) @(posedge clk);
        if (boot_error || capture_error) begin
            $display("FAIL: targeted recovery did not complete cleanly boot_error=%0d capture_error=%0d", boot_error, capture_error);
            $finish(1);
        end

        if (last_recovery_addr != (DYN_ADDR_BASE + 2)) begin
            $display("FAIL: wrong recovery address 0x%02h", last_recovery_addr);
            $finish(1);
        end

        repeat (120_000) @(posedge clk);
        if (capture_count_for(2) <= count_before_recovery) begin
            $display("FAIL: target 2 did not resume service after recovery before=%0d after=%0d",
                     count_before_recovery, capture_count_for(2));
            $finish(1);
        end

        fault_diag_ibi_req[4] <= 1'b1;
        while (!fault_diag_seen_bitmap[4] && !boot_error && !capture_error) @(posedge clk);
        fault_diag_ibi_req[4] <= 1'b0;

        if (boot_error || capture_error) begin
            $display("FAIL: fault diagnostic path caused controller error boot_error=%0d capture_error=%0d", boot_error, capture_error);
            $finish(1);
        end

        if (last_diag_addr != (DYN_ADDR_BASE + 4)) begin
            $display("FAIL: wrong diag address 0x%02h", last_diag_addr);
            $finish(1);
        end

        if (!last_status_word[0]) begin
            $display("FAIL: diag status did not indicate valid dynamic address status=0x%04h", last_status_word);
            $finish(1);
        end

        $display("PASS: known-target hub boot, recovery, and fault-diagnostic IBI policy baseline");
        #100;
        $finish;
    end

    initial begin
        #40_000_000;
        $display("FAIL: timeout");
        $finish(1);
    end

endmodule
