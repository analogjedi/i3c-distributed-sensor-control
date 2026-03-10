`timescale 1ns/1ps

module tb_i3c_scheduler;

    reg clk;
    reg rst_n;

    reg        discover_valid;
    reg [47:0] discover_pid;
    reg [7:0]  discover_bcr;
    reg [7:0]  discover_dcr;

    reg        enable_update_valid;
    reg [6:0]  enable_update_addr;
    reg        enable_update_value;
    reg        status_update_valid;
    reg [6:0]  status_update_addr;
    reg [15:0] status_update_value;
    reg        status_update_ok;

    reg        schedule_tick;
    reg        req_accept;

    wire [3:0] endpoint_count;
    wire [2:0] scan_index;
    wire       scan_valid;
    wire [6:0] scan_addr;
    wire [1:0] scan_class;
    wire       scan_enabled;
    wire       scan_health_fault;
    wire       req_valid;
    wire [6:0] req_addr;
    wire [1:0] req_class;
    wire [2:0] req_index;
    wire       busy;
    wire       missed_slot;

    reg  [6:0] query_addr;
    wire       query_found;
    wire [1:0] query_class;
    wire       query_enabled;
    wire       query_health_fault;

    i3c_ctrl_inventory #(
        .MAX_ENDPOINTS(6),
        .DYN_ADDR_BASE(7'h10)
    ) inv (
        .clk                      (clk),
        .rst_n                    (rst_n),
        .clear_tables             (1'b0),
        .default_endpoint_enable  (1'b1),
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
        .reset_action_update_valid(1'b0),
        .reset_action_update_addr (7'h00),
        .reset_action_update_value(8'h00),
        .status_update_valid      (status_update_valid),
        .status_update_addr       (status_update_addr),
        .status_update_value      (status_update_value),
        .status_update_ok         (status_update_ok),
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
        .scan_index               (scan_index),
        .scan_valid               (scan_valid),
        .scan_addr                (scan_addr),
        .scan_class               (scan_class),
        .scan_enabled             (scan_enabled),
        .scan_health_fault        (scan_health_fault),
        .assign_valid             (),
        .assign_dynamic_addr      (),
        .daa_endpoint_count       (),
        .daa_table_full           (),
        .duplicate_pid            (),
        .last_pid                 (),
        .last_bcr                 (),
        .last_dcr                 (),
        .policy_endpoint_count    (endpoint_count),
        .policy_table_full        (),
        .policy_update_miss       (),
        .last_update_addr         (),
        .last_event_mask          ()
    );

    i3c_ctrl_scheduler #(
        .MAX_ENDPOINTS(6)
    ) sched (
        .clk              (clk),
        .rst_n            (rst_n),
        .enable           (1'b1),
        .schedule_tick    (schedule_tick),
        .req_accept       (req_accept),
        .endpoint_count   (endpoint_count),
        .scan_index       (scan_index),
        .scan_valid       (scan_valid),
        .scan_addr        (scan_addr),
        .scan_class       (scan_class),
        .scan_enabled     (scan_enabled),
        .scan_health_fault(scan_health_fault),
        .req_valid        (req_valid),
        .req_addr         (req_addr),
        .req_class        (req_class),
        .req_index        (req_index),
        .busy             (busy),
        .missed_slot      (missed_slot)
    );

    always #5 clk = ~clk;

    initial begin
        clk                 = 1'b0;
        rst_n               = 1'b0;
        discover_valid      = 1'b0;
        discover_pid        = 48'h0;
        discover_bcr        = 8'h00;
        discover_dcr        = 8'h00;
        enable_update_valid = 1'b0;
        enable_update_addr  = 7'h00;
        enable_update_value = 1'b0;
        status_update_valid = 1'b0;
        status_update_addr  = 7'h00;
        status_update_value = 16'h0000;
        status_update_ok    = 1'b0;
        schedule_tick       = 1'b0;
        req_accept          = 1'b0;
        query_addr          = 7'h00;

        $dumpfile("tb_i3c_scheduler.vcd");
        $dumpvars(0, tb_i3c_scheduler);

        #100;
        rst_n = 1'b1;

        discover_endpoint(48'h1000_0000_0001, 8'h11, 8'hA1);
        discover_endpoint(48'h1800_0000_0001, 8'h22, 8'hB2);
        discover_endpoint(48'h2200_0000_0001, 8'h08, 8'h10);
        discover_endpoint(48'h3200_0000_0001, 8'h31, 8'hC1);
        wait_endpoint_count(3'd4);

        if (endpoint_count != 3'd4) begin
            $display("FAIL: expected endpoint_count=4 got=%0d", endpoint_count);
            $finish(1);
        end

        set_enable(7'h11, 1'b0);
        set_status(7'h12, 16'h55AA, 1'b0);
        @(posedge clk);
        check_policy_state(7'h11, 2'd2, 1'b0, 1'b0);
        check_policy_state(7'h12, 2'd1, 1'b1, 1'b1);

        expect_schedule(7'h10, 2'd3);
        accept_schedule;
        expect_schedule(7'h13, 2'd2);
        accept_schedule;

        set_enable(7'h11, 1'b1);
        set_status(7'h12, 16'hAA55, 1'b1);
        @(posedge clk);
        check_policy_state(7'h11, 2'd2, 1'b1, 1'b0);
        check_policy_state(7'h12, 2'd1, 1'b1, 1'b0);

        expect_schedule(7'h10, 2'd3);
        accept_schedule;
        expect_schedule(7'h11, 2'd2);
        accept_schedule;
        expect_schedule(7'h12, 2'd1);
        accept_schedule;

        set_enable(7'h10, 1'b0);
        set_enable(7'h11, 1'b0);
        set_enable(7'h12, 1'b0);
        set_enable(7'h13, 1'b0);
        @(posedge clk);
        expect_missed_slot;

        $display("PASS");
        #50;
        $finish;
    end

    initial begin
        #5_000_000;
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

    task set_enable;
        input [6:0] addr;
        input       value;
        begin
            @(posedge clk);
            enable_update_addr  <= addr;
            enable_update_value <= value;
            enable_update_valid <= 1'b1;
            @(posedge clk);
            enable_update_valid <= 1'b0;
        end
    endtask

    task set_status;
        input [6:0]  addr;
        input [15:0] value;
        input        ok;
        begin
            @(posedge clk);
            status_update_addr  <= addr;
            status_update_value <= value;
            status_update_ok    <= ok;
            status_update_valid <= 1'b1;
            @(posedge clk);
            status_update_valid <= 1'b0;
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

    task expect_schedule;
        input [6:0] expected_addr;
        input [1:0] expected_class;
        begin
            pulse_schedule_tick;
            while (!req_valid) @(posedge clk);
            if ((req_addr != expected_addr) || (req_class != expected_class)) begin
                $display("FAIL: schedule mismatch addr=0x%02h class=%0d expected_addr=0x%02h expected_class=%0d",
                         req_addr, req_class, expected_addr, expected_class);
                $finish(1);
            end
        end
    endtask

    task accept_schedule;
        begin
            @(posedge clk);
            req_accept <= 1'b1;
            @(posedge clk);
            req_accept <= 1'b0;
        end
    endtask

    task check_policy_state;
        input [6:0] expected_addr;
        input [1:0] expected_class;
        input       expected_enabled;
        input       expected_fault;
        begin
            query_addr <= expected_addr;
            @(posedge clk);
            if (!query_found || (query_class != expected_class) ||
                (query_enabled != expected_enabled) ||
                (query_health_fault != expected_fault)) begin
                $display("FAIL: policy state mismatch addr=0x%02h class=%0d enabled=%0d fault=%0d",
                         expected_addr, query_class, query_enabled, query_health_fault);
                $finish(1);
            end
        end
    endtask

    task expect_missed_slot;
        integer wait_cycles;
        begin
            pulse_schedule_tick;
            wait_cycles = 0;
            while (!missed_slot && (wait_cycles < 16)) begin
                @(posedge clk);
                wait_cycles = wait_cycles + 1;
            end
            if (!missed_slot || req_valid) begin
                $display("FAIL: expected missed_slot when no endpoints are schedulable");
                $finish(1);
            end
        end
    endtask

    task wait_endpoint_count;
        input [2:0] expected_count;
        integer wait_cycles;
        begin
            wait_cycles = 0;
            while ((endpoint_count != expected_count) && (wait_cycles < 16)) begin
                @(posedge clk);
                wait_cycles = wait_cycles + 1;
            end
        end
    endtask

endmodule
