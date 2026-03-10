`timescale 1ns/1ps

module tb_i3c_ctrl_top_service;

    reg clk;
    reg rst_n;

    reg        discover_valid;
    reg [47:0] discover_pid;
    reg [7:0]  discover_bcr;
    reg [7:0]  discover_dcr;

    reg        enable_update_valid;
    reg [6:0]  enable_update_addr;
    reg        enable_update_value;
    reg        service_period_update_valid;
    reg [6:0]  service_period_update_addr;
    reg [7:0]  service_period_update_value;
    reg        status_update_valid;
    reg [6:0]  status_update_addr;
    reg [15:0] status_update_value;
    reg        status_update_ok;

    reg        schedule_tick;
    reg  [6:0] query_addr;

    wire       query_found;
    wire [1:0] query_class;
    wire       query_enabled;
    wire       query_health_fault;
    wire [7:0] query_service_period;
    wire [15:0] query_service_count;
    wire [15:0] query_success_count;
    wire [15:0] query_error_count;
    wire [7:0] query_consecutive_failures;
    wire       query_due_now;
    wire [3:0] endpoint_count;
    wire       scheduler_busy;
    wire       scheduler_missed_slot;

    wire       service_rsp_valid;
    wire       service_rsp_nack;
    wire [6:0] service_rsp_addr;
    wire [1:0] service_rsp_class;
    wire [2:0] service_rsp_index;
    wire [7:0] service_rsp_rx_count;
    wire [31:0] service_rsp_rdata;
    wire       service_busy;

    wire scl_o;
    wire scl_oe;
    wire sda_o;
    wire sda_oe;
    wire scl_line;
    wire sda_line;

    reg        assign_dynamic_addr_valid_0;
    reg  [6:0] assign_dynamic_addr_0;
    reg        assign_dynamic_addr_valid_1;
    reg  [6:0] assign_dynamic_addr_1;
    reg        assign_dynamic_addr_valid_2;
    reg  [6:0] assign_dynamic_addr_2;
    reg        assign_dynamic_addr_valid_3;
    reg  [6:0] assign_dynamic_addr_3;

    reg  [31:0] read_data_0;
    reg  [31:0] read_data_1;
    reg  [31:0] read_data_2;
    reg  [31:0] read_data_3;

    wire [7:0] write_data_0;
    wire [7:0] write_data_1;
    wire [7:0] write_data_2;
    wire [7:0] write_data_3;
    wire       write_valid_0;
    wire       write_valid_1;
    wire       write_valid_2;
    wire       write_valid_3;
    wire [7:0] register_selector_0;
    wire [7:0] register_selector_1;
    wire [7:0] register_selector_2;
    wire [7:0] register_selector_3;
    wire       read_valid_0;
    wire       read_valid_1;
    wire       read_valid_2;
    wire       read_valid_3;
    wire [6:0] active_addr_0;
    wire [6:0] active_addr_1;
    wire [6:0] active_addr_2;
    wire [6:0] active_addr_3;
    reg        saw_read_0;
    reg        saw_read_1;
    reg        saw_read_2;
    reg        saw_read_3;
    reg [7:0]  write_count_0;
    reg [7:0]  write_count_1;
    reg [7:0]  write_count_2;
    reg [7:0]  write_count_3;

    pullup (scl_line);
    pullup (sda_line);

    assign scl_line = scl_oe ? scl_o : 1'bz;
    assign sda_line = sda_oe ? sda_o : 1'bz;

    i3c_ctrl_top #(
        .MAX_ENDPOINTS(6),
        .DYN_ADDR_BASE(7'h10),
        .CLK_FREQ_HZ(100_000_000),
        .I3C_SDR_HZ(1_000_000),
        .PUSH_PULL_DATA(1)
    ) dut (
        .clk                      (clk),
        .rst_n                    (rst_n),
        .clear_tables             (1'b0),
        .default_endpoint_enable  (1'b1),
        .default_service_period   (8'd1),
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
        .enable_update_valid      (enable_update_valid),
        .enable_update_addr       (enable_update_addr),
        .enable_update_value      (enable_update_value),
        .service_period_update_valid(service_period_update_valid),
        .service_period_update_addr(service_period_update_addr),
        .service_period_update_value(service_period_update_value),
        .reset_action_update_valid(1'b0),
        .reset_action_update_addr (7'h00),
        .reset_action_update_value(8'h00),
        .status_update_valid      (status_update_valid),
        .status_update_addr       (status_update_addr),
        .status_update_value      (status_update_value),
        .status_update_ok         (status_update_ok),
        .schedule_enable          (1'b1),
        .schedule_tick            (schedule_tick),
        .query_addr               (query_addr),
        .query_found              (query_found),
        .query_pid                (),
        .query_bcr                (),
        .query_dcr                (),
        .query_class              (query_class),
        .query_enabled            (query_enabled),
        .query_health_fault       (query_health_fault),
        .query_last_seen_ok       (),
        .query_event_mask         (),
        .query_reset_action       (),
        .query_status             (),
        .query_service_period     (query_service_period),
        .query_service_count      (query_service_count),
        .query_success_count      (query_success_count),
        .query_error_count        (query_error_count),
        .query_consecutive_failures(query_consecutive_failures),
        .query_last_service_tag   (),
        .query_due_now            (query_due_now),
        .endpoint_count           (endpoint_count),
        .policy_table_full        (),
        .policy_update_miss       (),
        .scheduler_busy           (scheduler_busy),
        .scheduler_missed_slot    (scheduler_missed_slot),
        .service_rsp_valid        (service_rsp_valid),
        .service_rsp_nack         (service_rsp_nack),
        .service_rsp_addr         (service_rsp_addr),
        .service_rsp_class        (service_rsp_class),
        .service_rsp_index        (service_rsp_index),
        .service_rsp_rx_count     (service_rsp_rx_count),
        .service_rsp_rdata        (service_rsp_rdata),
        .service_busy             (service_busy),
        .scl_o                    (scl_o),
        .scl_oe                   (scl_oe),
        .sda_o                    (sda_o),
        .sda_oe                   (sda_oe),
        .sda_i                    (sda_line)
    );

    i3c_target_top #(
        .STATIC_ADDR(7'h30),
        .PROVISIONAL_ID(48'h1000_0000_0001),
        .TARGET_BCR(8'h11),
        .TARGET_DCR(8'hA1)
    ) target0 (
        .clk                     (clk),
        .rst_n                   (rst_n),
        .scl                     (scl_line),
        .sda                     (sda_line),
        .clear_dynamic_addr      (1'b0),
        .assign_dynamic_addr_valid(assign_dynamic_addr_valid_0),
        .assign_dynamic_addr     (assign_dynamic_addr_0),
        .read_data               (read_data_0),
        .write_data              (write_data_0),
        .write_valid             (write_valid_0),
        .register_selector       (register_selector_0),
        .read_valid              (read_valid_0),
        .selected                (),
        .active_addr             (active_addr_0),
        .dynamic_addr_valid      (),
        .provisional_id          (),
        .event_enable_mask       (),
        .rstact_action           (),
        .status_word             (),
        .last_ccc                ()
    );

    i3c_target_top #(
        .STATIC_ADDR(7'h31),
        .PROVISIONAL_ID(48'h1800_0000_0001),
        .TARGET_BCR(8'h22),
        .TARGET_DCR(8'hB2)
    ) target1 (
        .clk                     (clk),
        .rst_n                   (rst_n),
        .scl                     (scl_line),
        .sda                     (sda_line),
        .clear_dynamic_addr      (1'b0),
        .assign_dynamic_addr_valid(assign_dynamic_addr_valid_1),
        .assign_dynamic_addr     (assign_dynamic_addr_1),
        .read_data               (read_data_1),
        .write_data              (write_data_1),
        .write_valid             (write_valid_1),
        .register_selector       (register_selector_1),
        .read_valid              (read_valid_1),
        .selected                (),
        .active_addr             (active_addr_1),
        .dynamic_addr_valid      (),
        .provisional_id          (),
        .event_enable_mask       (),
        .rstact_action           (),
        .status_word             (),
        .last_ccc                ()
    );

    i3c_target_top #(
        .STATIC_ADDR(7'h32),
        .PROVISIONAL_ID(48'h2200_0000_0001),
        .TARGET_BCR(8'h08),
        .TARGET_DCR(8'h10)
    ) target2 (
        .clk                     (clk),
        .rst_n                   (rst_n),
        .scl                     (scl_line),
        .sda                     (sda_line),
        .clear_dynamic_addr      (1'b0),
        .assign_dynamic_addr_valid(assign_dynamic_addr_valid_2),
        .assign_dynamic_addr     (assign_dynamic_addr_2),
        .read_data               (read_data_2),
        .write_data              (write_data_2),
        .write_valid             (write_valid_2),
        .register_selector       (register_selector_2),
        .read_valid              (read_valid_2),
        .selected                (),
        .active_addr             (active_addr_2),
        .dynamic_addr_valid      (),
        .provisional_id          (),
        .event_enable_mask       (),
        .rstact_action           (),
        .status_word             (),
        .last_ccc                ()
    );

    i3c_target_top #(
        .STATIC_ADDR(7'h33),
        .PROVISIONAL_ID(48'h3200_0000_0001),
        .TARGET_BCR(8'h31),
        .TARGET_DCR(8'hC1)
    ) target3 (
        .clk                     (clk),
        .rst_n                   (rst_n),
        .scl                     (scl_line),
        .sda                     (sda_line),
        .clear_dynamic_addr      (1'b0),
        .assign_dynamic_addr_valid(assign_dynamic_addr_valid_3),
        .assign_dynamic_addr     (assign_dynamic_addr_3),
        .read_data               (read_data_3),
        .write_data              (write_data_3),
        .write_valid             (write_valid_3),
        .register_selector       (register_selector_3),
        .read_valid              (read_valid_3),
        .selected                (),
        .active_addr             (active_addr_3),
        .dynamic_addr_valid      (),
        .provisional_id          (),
        .event_enable_mask       (),
        .rstact_action           (),
        .status_word             (),
        .last_ccc                ()
    );

    always #5 clk = ~clk;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            saw_read_0 <= 1'b0;
            saw_read_1 <= 1'b0;
            saw_read_2 <= 1'b0;
            saw_read_3 <= 1'b0;
        end else begin
            if (read_valid_0) saw_read_0 <= 1'b1;
            if (read_valid_1) saw_read_1 <= 1'b1;
            if (read_valid_2) saw_read_2 <= 1'b1;
            if (read_valid_3) saw_read_3 <= 1'b1;
        end
    end

    always @(posedge write_valid_0 or negedge rst_n) begin
        if (!rst_n) begin
            write_count_0 <= 8'd0;
        end else begin
            write_count_0 <= write_count_0 + 1'b1;
        end
    end

    always @(posedge write_valid_1 or negedge rst_n) begin
        if (!rst_n) begin
            write_count_1 <= 8'd0;
        end else begin
            write_count_1 <= write_count_1 + 1'b1;
        end
    end

    always @(posedge write_valid_2 or negedge rst_n) begin
        if (!rst_n) begin
            write_count_2 <= 8'd0;
        end else begin
            write_count_2 <= write_count_2 + 1'b1;
        end
    end

    always @(posedge write_valid_3 or negedge rst_n) begin
        if (!rst_n) begin
            write_count_3 <= 8'd0;
        end else begin
            write_count_3 <= write_count_3 + 1'b1;
        end
    end

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        discover_valid = 1'b0;
        discover_pid = 48'h0;
        discover_bcr = 8'h00;
        discover_dcr = 8'h00;
        enable_update_valid = 1'b0;
        enable_update_addr = 7'h00;
        enable_update_value = 1'b0;
        service_period_update_valid = 1'b0;
        service_period_update_addr = 7'h00;
        service_period_update_value = 8'h00;
        status_update_valid = 1'b0;
        status_update_addr = 7'h00;
        status_update_value = 16'h0000;
        status_update_ok = 1'b0;
        schedule_tick = 1'b0;
        query_addr = 7'h00;
        assign_dynamic_addr_valid_0 = 1'b0;
        assign_dynamic_addr_0 = 7'h00;
        assign_dynamic_addr_valid_1 = 1'b0;
        assign_dynamic_addr_1 = 7'h00;
        assign_dynamic_addr_valid_2 = 1'b0;
        assign_dynamic_addr_2 = 7'h00;
        assign_dynamic_addr_valid_3 = 1'b0;
        assign_dynamic_addr_3 = 7'h00;
        read_data_0 = 32'hA3A2A1A0;
        read_data_1 = 32'h00B3B2B1;
        read_data_2 = 32'h0000C2C1;
        read_data_3 = 32'h00D3D2D1;
        saw_read_0 = 1'b0;
        saw_read_1 = 1'b0;
        saw_read_2 = 1'b0;
        saw_read_3 = 1'b0;
        write_count_0 = 8'd0;
        write_count_1 = 8'd0;
        write_count_2 = 8'd0;
        write_count_3 = 8'd0;

        $dumpfile("tb_i3c_ctrl_top_service.vcd");
        $dumpvars(0, tb_i3c_ctrl_top_service);

        #200;
        rst_n = 1'b1;

        discover_endpoint(48'h1000_0000_0001, 8'h11, 8'hA1);
        assign_target_addr(0, 7'h10);
        discover_endpoint(48'h1800_0000_0001, 8'h22, 8'hB2);
        assign_target_addr(1, 7'h11);
        discover_endpoint(48'h2200_0000_0001, 8'h08, 8'h10);
        assign_target_addr(2, 7'h12);
        discover_endpoint(48'h3200_0000_0001, 8'h31, 8'hC1);
        assign_target_addr(3, 7'h13);
        wait_endpoint_count(4'd4);

        set_service_period(7'h10, 8'd2);
        set_service_period(7'h13, 8'd3);

        set_enable(7'h11, 1'b0);
        set_fault(7'h12, 1'b1);
        check_policy_state(7'h11, 2'd2, 1'b0, 1'b0, 8'd1, 16'd0, 16'd0, 16'd0, 8'd0, 1'b1);
        check_policy_state(7'h12, 2'd1, 1'b1, 1'b1, 8'd1, 16'd0, 16'd0, 16'd0, 8'd0, 1'b1);

        expect_service(7'h10, 2'd3, 8'd4, 32'hA3A2A1A0);
        check_selector_state(0, 8'd1, 8'h30);
        expect_service(7'h13, 2'd2, 8'd3, 32'h00D3D2D1);
        check_selector_state(3, 8'd1, 8'h20);
        check_policy_state(7'h10, 2'd3, 1'b1, 1'b0, 8'd2, 16'd1, 16'd1, 16'd0, 8'd0, 1'b0);
        check_policy_state(7'h13, 2'd2, 1'b1, 1'b0, 8'd3, 16'd1, 16'd1, 16'd0, 8'd0, 1'b0);

        set_enable(7'h11, 1'b1);
        set_fault(7'h12, 1'b0);
        check_policy_state(7'h11, 2'd2, 1'b1, 1'b0, 8'd1, 16'd0, 16'd0, 16'd0, 8'd0, 1'b1);
        check_policy_state(7'h12, 2'd1, 1'b1, 1'b0, 8'd1, 16'd0, 16'd0, 16'd0, 8'd0, 1'b1);

        expect_service(7'h10, 2'd3, 8'd4, 32'hA3A2A1A0);
        check_selector_state(0, 8'd2, 8'h30);
        expect_service(7'h11, 2'd2, 8'd3, 32'h00B3B2B1);
        check_selector_state(1, 8'd1, 8'h20);
        expect_service(7'h12, 2'd1, 8'd2, 32'h0000C2C1);
        check_selector_state(2, 8'd1, 8'h10);
        expect_service(7'h13, 2'd2, 8'd3, 32'h00D3D2D1);
        check_selector_state(3, 8'd2, 8'h20);
        check_policy_state(7'h10, 2'd3, 1'b1, 1'b0, 8'd2, 16'd2, 16'd2, 16'd0, 8'd0, 1'b1);
        check_policy_state(7'h11, 2'd2, 1'b1, 1'b0, 8'd1, 16'd1, 16'd1, 16'd0, 8'd0, 1'b1);
        check_policy_state(7'h12, 2'd1, 1'b1, 1'b0, 8'd1, 16'd1, 16'd1, 16'd0, 8'd0, 1'b1);
        check_policy_state(7'h13, 2'd2, 1'b1, 1'b0, 8'd3, 16'd2, 16'd2, 16'd0, 8'd0, 1'b0);

        assign_target_addr(3, 7'h23);
        set_service_period(7'h13, 8'd1);
        set_enable(7'h10, 1'b0);
        set_enable(7'h11, 1'b0);
        set_enable(7'h12, 1'b0);
        expect_service_nack(7'h13, 2'd2);
        check_selector_state(3, 8'd2, 8'h20);
        check_policy_state(7'h13, 2'd2, 1'b1, 1'b0, 8'd1, 16'd3, 16'd2, 16'd1, 8'd1, 1'b0);
        expect_service_nack(7'h13, 2'd2);
        check_selector_state(3, 8'd2, 8'h20);
        check_policy_state(7'h13, 2'd2, 1'b1, 1'b1, 8'd1, 16'd4, 16'd2, 16'd2, 8'd2, 1'b0);
        expect_missed_slot;

        assign_target_addr(3, 7'h13);
        set_fault(7'h13, 1'b0);
        check_policy_state(7'h13, 2'd2, 1'b1, 1'b0, 8'd1, 16'd4, 16'd2, 16'd2, 8'd0, 1'b1);
        expect_service(7'h13, 2'd2, 8'd3, 32'h00D3D2D1);
        check_selector_state(3, 8'd3, 8'h20);
        check_policy_state(7'h13, 2'd2, 1'b1, 1'b0, 8'd1, 16'd5, 16'd3, 16'd2, 8'd0, 1'b0);

        if (!saw_read_0 || !saw_read_1 || !saw_read_2 || !saw_read_3) begin
            $display("FAIL: expected each target to observe scheduled read service");
            $finish(1);
        end

        set_enable(7'h13, 1'b0);
        expect_missed_slot;

        $display("PASS");
        #100;
        $finish;
    end

    initial begin
        #10_000_000;
        $display("FAIL: timeout");
        $finish(1);
    end

    task discover_endpoint;
        input [47:0] pid;
        input [7:0]  bcr;
        input [7:0]  dcr;
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
            case (target_id)
                0: begin
                    assign_dynamic_addr_0 <= addr;
                    assign_dynamic_addr_valid_0 <= 1'b1;
                end
                1: begin
                    assign_dynamic_addr_1 <= addr;
                    assign_dynamic_addr_valid_1 <= 1'b1;
                end
                2: begin
                    assign_dynamic_addr_2 <= addr;
                    assign_dynamic_addr_valid_2 <= 1'b1;
                end
                3: begin
                    assign_dynamic_addr_3 <= addr;
                    assign_dynamic_addr_valid_3 <= 1'b1;
                end
            endcase
            @(posedge clk);
            assign_dynamic_addr_valid_0 <= 1'b0;
            assign_dynamic_addr_valid_1 <= 1'b0;
            assign_dynamic_addr_valid_2 <= 1'b0;
            assign_dynamic_addr_valid_3 <= 1'b0;
        end
    endtask

    task set_enable;
        input [6:0] addr;
        input value;
        begin
            @(posedge clk);
            enable_update_addr  <= addr;
            enable_update_value <= value;
            enable_update_valid <= 1'b1;
            @(posedge clk);
            enable_update_valid <= 1'b0;
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

    task set_fault;
        input [6:0] addr;
        input faulted;
        begin
            @(posedge clk);
            status_update_addr  <= addr;
            status_update_value <= faulted ? 16'hDEAD : 16'h600D;
            status_update_ok    <= !faulted;
            status_update_valid <= 1'b1;
            @(posedge clk);
            status_update_valid <= 1'b0;
            @(posedge clk);
        end
    endtask

    task wait_endpoint_count;
        input [3:0] expected_count;
        integer wait_cycles;
        begin
            wait_cycles = 0;
            while ((endpoint_count != expected_count) && (wait_cycles < 16)) begin
                @(posedge clk);
                wait_cycles = wait_cycles + 1;
            end
            if (endpoint_count != expected_count) begin
                $display("FAIL: expected endpoint_count=%0d got=%0d", expected_count, endpoint_count);
                $finish(1);
            end
        end
    endtask

    task check_policy_state;
        input [6:0] expected_addr;
        input [1:0] expected_class;
        input expected_enabled;
        input expected_fault;
        input [7:0] expected_period;
        input [15:0] expected_service_count;
        input [15:0] expected_success_count;
        input [15:0] expected_error_count;
        input [7:0] expected_consecutive_failures;
        input expected_due_now;
        begin
            query_addr <= expected_addr;
            @(posedge clk);
            if (!query_found || (query_class != expected_class) ||
                (query_enabled != expected_enabled) ||
                (query_health_fault != expected_fault) ||
                (query_service_period != expected_period) ||
                (query_service_count != expected_service_count) ||
                (query_success_count != expected_success_count) ||
                (query_error_count != expected_error_count) ||
                (query_consecutive_failures != expected_consecutive_failures) ||
                (query_due_now != expected_due_now)) begin
                $display("FAIL: policy mismatch addr=0x%02h class=%0d enabled=%0d fault=%0d period=%0d service=%0d success=%0d error=%0d failrun=%0d due=%0d",
                         expected_addr, query_class, query_enabled, query_health_fault,
                         query_service_period, query_service_count, query_success_count,
                         query_error_count, query_consecutive_failures, query_due_now);
                $finish(1);
            end
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

    task expect_service;
        input [6:0] expected_addr;
        input [1:0] expected_class;
        input [7:0] expected_count;
        input [31:0] expected_data;
        integer wait_cycles;
        begin
            pulse_schedule_tick;
            wait_cycles = 0;
            while (!service_rsp_valid && (wait_cycles < 12000)) begin
                @(posedge clk);
                wait_cycles = wait_cycles + 1;
            end
            if (!service_rsp_valid || service_rsp_nack ||
                (service_rsp_addr != expected_addr) ||
                (service_rsp_class != expected_class) ||
                (service_rsp_rx_count != expected_count) ||
                (service_rsp_rdata != expected_data)) begin
                $display("FAIL: service mismatch valid=%0d nack=%0d addr=0x%02h class=%0d count=%0d data=0x%08h expected_addr=0x%02h expected_class=%0d expected_count=%0d expected_data=0x%08h",
                         service_rsp_valid, service_rsp_nack, service_rsp_addr, service_rsp_class,
                         service_rsp_rx_count, service_rsp_rdata, expected_addr, expected_class,
                         expected_count, expected_data);
                $finish(1);
            end
        end
    endtask

    task expect_service_nack;
        input [6:0] expected_addr;
        input [1:0] expected_class;
        integer wait_cycles;
        begin
            pulse_schedule_tick;
            wait_cycles = 0;
            while (!service_rsp_valid && (wait_cycles < 12000)) begin
                @(posedge clk);
                wait_cycles = wait_cycles + 1;
            end
            if (!service_rsp_valid || !service_rsp_nack ||
                (service_rsp_addr != expected_addr) ||
                (service_rsp_class != expected_class)) begin
                $display("FAIL: expected NACK service addr=0x%02h class=%0d valid=%0d nack=%0d got_addr=0x%02h got_class=%0d",
                         expected_addr, expected_class, service_rsp_valid, service_rsp_nack,
                         service_rsp_addr, service_rsp_class);
                $finish(1);
            end
        end
    endtask

    task expect_missed_slot;
        integer wait_cycles;
        begin
            pulse_schedule_tick;
            wait_cycles = 0;
            while (!scheduler_missed_slot && (wait_cycles < 64)) begin
                @(posedge clk);
                wait_cycles = wait_cycles + 1;
            end
            if (!scheduler_missed_slot) begin
                $display("FAIL: expected scheduler_missed_slot when all endpoints disabled");
                $finish(1);
            end
        end
    endtask

    task check_selector_state;
        input integer target_id;
        input [7:0] expected_count;
        input [7:0] expected_selector;
        begin
            case (target_id)
                0: begin
                    if ((write_count_0 != expected_count) || (register_selector_0 != expected_selector)) begin
                        $display("FAIL: selector mismatch target0 count=%0d selector=0x%02h expected_count=%0d expected_selector=0x%02h",
                                 write_count_0, register_selector_0, expected_count, expected_selector);
                        $finish(1);
                    end
                end
                1: begin
                    if ((write_count_1 != expected_count) || (register_selector_1 != expected_selector)) begin
                        $display("FAIL: selector mismatch target1 count=%0d selector=0x%02h expected_count=%0d expected_selector=0x%02h",
                                 write_count_1, register_selector_1, expected_count, expected_selector);
                        $finish(1);
                    end
                end
                2: begin
                    if ((write_count_2 != expected_count) || (register_selector_2 != expected_selector)) begin
                        $display("FAIL: selector mismatch target2 count=%0d selector=0x%02h expected_count=%0d expected_selector=0x%02h",
                                 write_count_2, register_selector_2, expected_count, expected_selector);
                        $finish(1);
                    end
                end
                3: begin
                    if ((write_count_3 != expected_count) || (register_selector_3 != expected_selector)) begin
                        $display("FAIL: selector mismatch target3 count=%0d selector=0x%02h expected_count=%0d expected_selector=0x%02h",
                                 write_count_3, register_selector_3, expected_count, expected_selector);
                        $finish(1);
                    end
                end
            endcase
        end
    endtask

endmodule
