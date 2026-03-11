`timescale 1ns/1ps

module tb_i3c_five_target_sampling_system;

    localparam integer TARGET_COUNT = 5;
    localparam integer MAX_SERVICE_BYTES = 16;
    localparam [7:0] SAMPLE_PAYLOAD_BYTES = 8'd10;
    localparam [7:0] SAMPLE_SELECTOR = 8'h40;
    localparam [7:0] SAMPLE_PERIOD_TICKS = 8'd1;
    localparam integer ADC_EFFECTIVE_SPS = 2000;

    reg clk;
    reg rst_n;

    reg        discover_valid;
    reg [47:0] discover_pid;
    reg [7:0]  discover_bcr;
    reg [7:0]  discover_dcr;
    reg        service_period_update_valid;
    reg [6:0]  service_period_update_addr;
    reg [7:0]  service_period_update_value;
    reg        service_len_update_valid;
    reg [6:0]  service_len_update_addr;
    reg [7:0]  service_len_update_value;
    reg        service_selector_update_valid;
    reg [6:0]  service_selector_update_addr;
    reg [7:0]  service_selector_update_value;
    reg        schedule_tick;
    reg [6:0]  query_addr;

    wire       query_found;
    wire [7:0] query_service_period;
    wire [7:0] query_service_rx_len;
    wire [7:0] query_service_selector;
    wire [15:0] query_service_count;
    wire [15:0] query_success_count;
    wire [3:0] endpoint_count;

    wire       service_rsp_valid;
    wire       service_rsp_nack;
    wire [6:0] service_rsp_addr;
    wire [2:0] service_rsp_index;
    wire [7:0] service_rsp_rx_count;
    wire [8*MAX_SERVICE_BYTES-1:0] service_rsp_rdata;

    wire scl_o;
    wire scl_oe;
    wire sda_o;
    wire sda_oe;
    wire scl_line;
    wire sda_line;

    reg  [TARGET_COUNT-1:0] assign_dynamic_addr_valid;
    reg  [6:0] assign_dynamic_addr [0:TARGET_COUNT-1];
    reg  [8*MAX_SERVICE_BYTES-1:0] read_data [0:TARGET_COUNT-1];
    wire [7:0] register_selector [0:TARGET_COUNT-1];
    wire       write_valid [0:TARGET_COUNT-1];
    integer selector_write_count [0:TARGET_COUNT-1];
    integer i;
    integer service_round;

    pullup (scl_line);
    pullup (sda_line);

    assign scl_line = scl_oe ? scl_o : 1'bz;
    assign sda_line = sda_oe ? sda_o : 1'bz;

    i3c_ctrl_top #(
        .MAX_ENDPOINTS(5),
        .MAX_SERVICE_BYTES(MAX_SERVICE_BYTES),
        .DYN_ADDR_BASE(7'h10),
        .CLK_FREQ_HZ(100_000_000),
        .I3C_SDR_HZ(1_000_000),
        .PUSH_PULL_DATA(1)
    ) dut (
        .clk                      (clk),
        .rst_n                    (rst_n),
        .clear_tables             (1'b0),
        .default_endpoint_enable  (1'b1),
        .default_service_period   (SAMPLE_PERIOD_TICKS),
        .discover_valid           (discover_valid),
        .discover_pid             (discover_pid),
        .discover_bcr             (discover_bcr),
        .discover_dcr             (discover_dcr),
        .broadcast_event_set_valid(1'b0),
        .broadcast_event_clear_valid(1'b0),
        .broadcast_event_mask     (8'h00),
        .direct_event_set_valid   (1'b0),
        .direct_event_clear_valid (1'b0),
        .direct_event_addr        (7'h00),
        .direct_event_mask        (8'h00),
        .enable_update_valid      (1'b0),
        .enable_update_addr       (7'h00),
        .enable_update_value      (1'b0),
        .reset_action_update_valid(1'b0),
        .reset_action_update_addr (7'h00),
        .reset_action_update_value(8'h00),
        .status_update_valid      (1'b0),
        .status_update_addr       (7'h00),
        .status_update_value      (16'h0000),
        .status_update_ok         (1'b0),
        .service_period_update_valid(service_period_update_valid),
        .service_period_update_addr(service_period_update_addr),
        .service_period_update_value(service_period_update_value),
        .service_len_update_valid (service_len_update_valid),
        .service_len_update_addr  (service_len_update_addr),
        .service_len_update_value (service_len_update_value),
        .service_selector_update_valid(service_selector_update_valid),
        .service_selector_update_addr(service_selector_update_addr),
        .service_selector_update_value(service_selector_update_value),
        .schedule_enable          (1'b1),
        .schedule_tick            (schedule_tick),
        .query_addr               (query_addr),
        .query_found              (query_found),
        .query_pid                (),
        .query_bcr                (),
        .query_dcr                (),
        .query_class              (),
        .query_enabled            (),
        .query_health_fault       (),
        .query_last_seen_ok       (),
        .query_event_mask         (),
        .query_reset_action       (),
        .query_status             (),
        .query_service_period     (query_service_period),
        .query_service_rx_len     (query_service_rx_len),
        .query_service_selector   (query_service_selector),
        .query_service_count      (query_service_count),
        .query_success_count      (query_success_count),
        .query_error_count        (),
        .query_consecutive_failures(),
        .query_last_service_tag   (),
        .query_due_now            (),
        .endpoint_count           (endpoint_count),
        .policy_table_full        (),
        .policy_update_miss       (),
        .scheduler_busy           (),
        .scheduler_missed_slot    (),
        .service_rsp_valid        (service_rsp_valid),
        .service_rsp_nack         (service_rsp_nack),
        .service_rsp_addr         (service_rsp_addr),
        .service_rsp_class        (),
        .service_rsp_index        (service_rsp_index),
        .service_rsp_rx_count     (service_rsp_rx_count),
        .service_rsp_rdata        (service_rsp_rdata),
        .service_busy             (),
        .scl_o                    (scl_o),
        .scl_oe                   (scl_oe),
        .sda_o                    (sda_o),
        .sda_oe                   (sda_oe),
        .sda_i                    (sda_line)
    );

    genvar gi;
    generate
        for (gi = 0; gi < TARGET_COUNT; gi = gi + 1) begin : gen_targets
            i3c_target_top #(
                .MAX_READ_BYTES(MAX_SERVICE_BYTES),
                .STATIC_ADDR(7'h30 + gi[6:0]),
                .PROVISIONAL_ID(48'h4100_0000_0001 + gi),
                .TARGET_BCR(8'h21),
                .TARGET_DCR(8'h90)
            ) target (
                .clk                     (clk),
                .rst_n                   (rst_n),
                .scl                     (scl_line),
                .sda                     (sda_line),
                .clear_dynamic_addr      (1'b0),
                .assign_dynamic_addr_valid(assign_dynamic_addr_valid[gi]),
                .assign_dynamic_addr     (assign_dynamic_addr[gi]),
                .read_data               (read_data[gi]),
                .write_data              (),
                .write_valid             (write_valid[gi]),
                .register_selector       (register_selector[gi]),
                .read_valid              (),
                .selected                (),
                .active_addr             (),
                .dynamic_addr_valid      (),
                .provisional_id          (),
                .event_enable_mask       (),
                .rstact_action           (),
                .status_word             (),
                .last_ccc                ()
            );
        end
    endgenerate

    generate
        for (gi = 0; gi < TARGET_COUNT; gi = gi + 1) begin : gen_counts
            always @(posedge write_valid[gi] or negedge rst_n) begin
                if (!rst_n) begin
                    selector_write_count[gi] <= 0;
                end else begin
                    selector_write_count[gi] <= selector_write_count[gi] + 1;
                end
            end
        end
    endgenerate

    always #5 clk = ~clk;

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        discover_valid = 1'b0;
        discover_pid = 48'h0;
        discover_bcr = 8'h00;
        discover_dcr = 8'h00;
        service_period_update_valid = 1'b0;
        service_period_update_addr = 7'h00;
        service_period_update_value = 8'h00;
        service_len_update_valid = 1'b0;
        service_len_update_addr = 7'h00;
        service_len_update_value = 8'h00;
        service_selector_update_valid = 1'b0;
        service_selector_update_addr = 7'h00;
        service_selector_update_value = 8'h00;
        schedule_tick = 1'b0;
        query_addr = 7'h00;
        assign_dynamic_addr_valid = {TARGET_COUNT{1'b0}};

        read_data[0] = {48'h0, 8'hA0, 8'h90, 8'h44, 8'h33, 8'h22, 8'h11, 8'h04, 8'h03, 8'h02, 8'h01};
        read_data[1] = {48'h0, 8'hA1, 8'h91, 8'h48, 8'h37, 8'h26, 8'h15, 8'h08, 8'h07, 8'h06, 8'h05};
        read_data[2] = {48'h0, 8'hA2, 8'h92, 8'h4C, 8'h3B, 8'h2A, 8'h19, 8'h0C, 8'h0B, 8'h0A, 8'h09};
        read_data[3] = {48'h0, 8'hA3, 8'h93, 8'h50, 8'h3F, 8'h2E, 8'h1D, 8'h10, 8'h0F, 8'h0E, 8'h0D};
        read_data[4] = {48'h0, 8'hA4, 8'h94, 8'h54, 8'h43, 8'h32, 8'h21, 8'h14, 8'h13, 8'h12, 8'h11};

        for (i = 0; i < TARGET_COUNT; i = i + 1) begin
            assign_dynamic_addr[i] = 7'h00;
            selector_write_count[i] = 0;
        end

        $dumpfile("tb_i3c_five_target_sampling_system.vcd");
        $dumpvars(0, tb_i3c_five_target_sampling_system);

        #200;
        rst_n = 1'b1;

        for (i = 0; i < TARGET_COUNT; i = i + 1) begin
            discover_endpoint(48'h4100_0000_0001 + i, 8'h21, 8'h90);
            assign_target_addr(i, 7'h10 + i[6:0]);
        end
        wait_endpoint_count(TARGET_COUNT);

        for (i = 0; i < TARGET_COUNT; i = i + 1) begin
            set_service_period(7'h10 + i[6:0], SAMPLE_PERIOD_TICKS);
            set_service_len(7'h10 + i[6:0], SAMPLE_PAYLOAD_BYTES);
            set_service_selector(7'h10 + i[6:0], SAMPLE_SELECTOR);
            check_endpoint_config(7'h10 + i[6:0], SAMPLE_PERIOD_TICKS, SAMPLE_PAYLOAD_BYTES, SAMPLE_SELECTOR);
        end

        for (service_round = 0; service_round < 2; service_round = service_round + 1) begin
            for (i = 0; i < TARGET_COUNT; i = i + 1) begin
                expect_service(7'h10 + i[6:0], i[2:0], SAMPLE_PAYLOAD_BYTES, read_data[i]);
                if (register_selector[i] != SAMPLE_SELECTOR) begin
                    $display("FAIL: target%0d selector 0x%02h expected 0x%02h", i, register_selector[i], SAMPLE_SELECTOR);
                    $finish(1);
                end
                if (selector_write_count[i] != (service_round + 1)) begin
                    $display("FAIL: target%0d selector writes %0d expected %0d", i, selector_write_count[i], service_round + 1);
                    $finish(1);
                end
            end
        end

        for (i = 0; i < TARGET_COUNT; i = i + 1) begin
            query_addr <= 7'h10 + i[6:0];
            @(posedge clk);
            if (!query_found || (query_service_count != 16'd2) || (query_success_count != 16'd2)) begin
                $display("FAIL: endpoint 0x%02h count=%0d success=%0d", 7'h10 + i[6:0], query_service_count, query_success_count);
                $finish(1);
            end
        end

        $display("PASS: 5-target sampling system baseline, %0d-byte payload, %0d SPS endpoint config", SAMPLE_PAYLOAD_BYTES, ADC_EFFECTIVE_SPS);
        #100;
        $finish;
    end

    initial begin
        #20_000_000;
        $display("FAIL: timeout");
        $finish(1);
    end

    task discover_endpoint;
        input [47:0] pid;
        input [7:0] bcr;
        input [7:0] dcr;
        begin
            @(posedge clk);
            discover_pid   <= pid;
            discover_bcr   <= bcr;
            discover_dcr   <= dcr;
            discover_valid <= 1'b1;
            @(posedge clk);
            discover_valid <= 1'b0;
        end
    endtask

    task assign_target_addr;
        input integer target_id;
        input [6:0] addr;
        begin
            @(posedge clk);
            assign_dynamic_addr[target_id] <= addr;
            assign_dynamic_addr_valid[target_id] <= 1'b1;
            @(posedge clk);
            assign_dynamic_addr_valid[target_id] <= 1'b0;
            @(posedge clk);
        end
    endtask

    task set_service_period;
        input [6:0] addr;
        input [7:0] value;
        begin
            @(posedge clk);
            service_period_update_addr  <= addr;
            service_period_update_value <= value;
            service_period_update_valid <= 1'b1;
            @(posedge clk);
            service_period_update_valid <= 1'b0;
            @(posedge clk);
        end
    endtask

    task set_service_len;
        input [6:0] addr;
        input [7:0] value;
        begin
            @(posedge clk);
            service_len_update_addr  <= addr;
            service_len_update_value <= value;
            service_len_update_valid <= 1'b1;
            @(posedge clk);
            service_len_update_valid <= 1'b0;
            @(posedge clk);
        end
    endtask

    task set_service_selector;
        input [6:0] addr;
        input [7:0] value;
        begin
            @(posedge clk);
            service_selector_update_addr  <= addr;
            service_selector_update_value <= value;
            service_selector_update_valid <= 1'b1;
            @(posedge clk);
            service_selector_update_valid <= 1'b0;
            @(posedge clk);
        end
    endtask

    task pulse_schedule_tick;
        begin
            @(posedge clk);
            schedule_tick <= 1'b1;
            @(posedge clk);
            schedule_tick <= 1'b0;
        end
    endtask

    task wait_endpoint_count;
        input integer expected_count;
        integer wait_cycles;
        begin
            wait_cycles = 0;
            while ((endpoint_count != expected_count) && (wait_cycles < 64)) begin
                @(posedge clk);
                wait_cycles = wait_cycles + 1;
            end
            if (endpoint_count != expected_count) begin
                $display("FAIL: endpoint_count=%0d expected=%0d", endpoint_count, expected_count);
                $finish(1);
            end
        end
    endtask

    task check_endpoint_config;
        input [6:0] addr;
        input [7:0] expected_period;
        input [7:0] expected_len;
        input [7:0] expected_selector;
        begin
            query_addr <= addr;
            @(posedge clk);
            if (!query_found ||
                (query_service_period != expected_period) ||
                (query_service_rx_len != expected_len) ||
                (query_service_selector != expected_selector)) begin
                $display("FAIL: config mismatch addr=0x%02h period=%0d len=%0d selector=0x%02h", addr, query_service_period, query_service_rx_len, query_service_selector);
                $finish(1);
            end
        end
    endtask

    task expect_service;
        input [6:0] expected_addr;
        input [2:0] expected_index;
        input [7:0] expected_count;
        input [8*MAX_SERVICE_BYTES-1:0] expected_data;
        integer wait_cycles;
        begin
            pulse_schedule_tick;
            wait_cycles = 0;
            while (!service_rsp_valid && (wait_cycles < 20000)) begin
                @(posedge clk);
                wait_cycles = wait_cycles + 1;
            end
            if (!service_rsp_valid || service_rsp_nack ||
                (service_rsp_addr != expected_addr) ||
                (service_rsp_index != expected_index) ||
                (service_rsp_rx_count != expected_count) ||
                (service_rsp_rdata[79:0] != expected_data[79:0])) begin
                $display("FAIL: service mismatch addr=0x%02h idx=%0d count=%0d data=0x%020h expected=0x%020h valid=%0d nack=%0d",
                         service_rsp_addr, service_rsp_index, service_rsp_rx_count,
                         service_rsp_rdata[79:0], expected_data[79:0], service_rsp_valid, service_rsp_nack);
                $finish(1);
            end
        end
    endtask

endmodule
