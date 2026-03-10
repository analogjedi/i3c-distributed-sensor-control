`timescale 1ns/1ps

module tb_i3c_recovery_sequence;

    reg clk;
    reg rst_n;

    reg        endpoint_add_valid;
    reg [6:0]  endpoint_dynamic_addr;
    reg [47:0] endpoint_pid;
    reg [7:0]  endpoint_bcr;
    reg [7:0]  endpoint_dcr;
    reg        reset_action_update_valid;
    reg [6:0]  reset_action_update_addr;
    reg [7:0]  reset_action_update_value;
    reg        status_update_valid;
    reg [6:0]  status_update_addr;
    reg [15:0] status_update_value;
    reg        status_update_ok;
    reg        service_result_valid;
    reg [6:0]  service_result_addr;
    reg        service_result_nack;
    reg        schedule_tick;

    reg  [6:0] query_addr;
    wire       query_found;
    wire [1:0] query_class;
    wire       query_enabled;
    wire       query_health_fault;
    wire [7:0] query_reset_action;
    wire [15:0] query_service_count;
    wire [15:0] query_success_count;
    wire [15:0] query_error_count;
    wire [7:0] query_consecutive_failures;
    wire [1:0] query_recovery_state;
    wire [7:0] query_recovery_countdown;
    wire [7:0] query_recovery_attempts;

    localparam [1:0] RECOVERY_IDLE       = 2'd0;
    localparam [1:0] RECOVERY_RETRY_WAIT = 2'd1;
    localparam [1:0] RECOVERY_RESET_WAIT = 2'd2;
    localparam [1:0] RECOVERY_ESCALATED  = 2'd3;

    i3c_ctrl_policy #(
        .MAX_ENDPOINTS(4),
        .AUTO_FAULT_THRESHOLD(2),
        .RECOVERY_RETRY_COOLDOWN(2),
        .RECOVERY_RESET_COOLDOWN(4),
        .RECOVERY_MAX_AUTO_ATTEMPTS(1)
    ) dut (
        .default_endpoint_enable (1'b1),
        .default_service_period  (8'd1),
        .clk                     (clk),
        .rst_n                   (rst_n),
        .clear_table             (1'b0),
        .schedule_tick           (schedule_tick),
        .endpoint_add_valid      (endpoint_add_valid),
        .endpoint_dynamic_addr   (endpoint_dynamic_addr),
        .endpoint_pid            (endpoint_pid),
        .endpoint_bcr            (endpoint_bcr),
        .endpoint_dcr            (endpoint_dcr),
        .broadcast_event_set_valid(1'b0),
        .broadcast_event_clear_valid(1'b0),
        .broadcast_event_mask    (8'h00),
        .direct_event_set_valid  (1'b0),
        .direct_event_clear_valid(1'b0),
        .direct_event_addr       (7'h00),
        .direct_event_mask       (8'h00),
        .enable_update_valid     (1'b0),
        .enable_update_addr      (7'h00),
        .enable_update_value     (1'b0),
        .reset_action_update_valid(reset_action_update_valid),
        .reset_action_update_addr(reset_action_update_addr),
        .reset_action_update_value(reset_action_update_value),
        .status_update_valid     (status_update_valid),
        .status_update_addr      (status_update_addr),
        .status_update_value     (status_update_value),
        .status_update_ok        (status_update_ok),
        .service_period_update_valid(1'b0),
        .service_period_update_addr(7'h00),
        .service_period_update_value(8'h00),
        .service_result_valid    (service_result_valid),
        .service_result_addr     (service_result_addr),
        .service_result_nack     (service_result_nack),
        .query_addr              (query_addr),
        .query_found             (query_found),
        .query_pid               (),
        .query_bcr               (),
        .query_dcr               (),
        .query_class             (query_class),
        .query_enabled           (query_enabled),
        .query_health_fault      (query_health_fault),
        .query_last_seen_ok      (),
        .query_event_mask        (),
        .query_reset_action      (query_reset_action),
        .query_status            (),
        .query_service_period    (),
        .query_service_count     (query_service_count),
        .query_success_count     (query_success_count),
        .query_error_count       (query_error_count),
        .query_consecutive_failures(query_consecutive_failures),
        .query_last_service_tag  (),
        .query_due_now           (),
        .query_recovery_state    (query_recovery_state),
        .query_recovery_countdown(query_recovery_countdown),
        .query_recovery_attempts (query_recovery_attempts),
        .scan_index              (2'd0),
        .scan_valid              (),
        .scan_addr               (),
        .scan_class              (),
        .scan_enabled            (),
        .scan_health_fault       (),
        .scan_due                (),
        .endpoint_count          (),
        .table_full              (),
        .policy_update_miss      (),
        .last_update_addr        (),
        .last_event_mask         ()
    );

    always #5 clk = ~clk;

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        endpoint_add_valid = 1'b0;
        endpoint_dynamic_addr = 7'h00;
        endpoint_pid = 48'h0;
        endpoint_bcr = 8'h00;
        endpoint_dcr = 8'h00;
        reset_action_update_valid = 1'b0;
        reset_action_update_addr = 7'h00;
        reset_action_update_value = 8'h00;
        status_update_valid = 1'b0;
        status_update_addr = 7'h00;
        status_update_value = 16'h0000;
        status_update_ok = 1'b0;
        service_result_valid = 1'b0;
        service_result_addr = 7'h00;
        service_result_nack = 1'b0;
        schedule_tick = 1'b0;
        query_addr = 7'h00;

        $dumpfile("tb_i3c_recovery_sequence.vcd");
        $dumpvars(0, tb_i3c_recovery_sequence);

        #100;
        rst_n = 1'b1;

        add_endpoint(7'h10, 48'h1000_0000_0001, 8'h11, 8'hA1);
        add_endpoint(7'h11, 48'h1100_0000_0001, 8'h21, 8'hB1);
        add_endpoint(7'h12, 48'h1200_0000_0001, 8'h31, 8'hC1);
        add_endpoint(7'h13, 48'h1300_0000_0001, 8'h01, 8'h10);

        set_reset_action(7'h10, 8'h01);
        induce_nack(7'h10);
        induce_nack(7'h10);
        check_recovery_state(7'h10, 1'b1, 1'b1, 8'h01, 16'd2, 16'd0, 16'd2, 8'd2, RECOVERY_RETRY_WAIT, 8'd2, 8'd1);
        pulse_tick;
        check_recovery_state(7'h10, 1'b1, 1'b1, 8'h01, 16'd2, 16'd0, 16'd2, 8'd2, RECOVERY_RETRY_WAIT, 8'd1, 8'd1);
        pulse_tick;
        check_recovery_state(7'h10, 1'b1, 1'b0, 8'h01, 16'd2, 16'd0, 16'd2, 8'd0, RECOVERY_IDLE, 8'd0, 8'd1);
        induce_success(7'h10);
        check_recovery_state(7'h10, 1'b1, 1'b0, 8'h01, 16'd3, 16'd1, 16'd2, 8'd0, RECOVERY_IDLE, 8'd0, 8'd0);

        set_reset_action(7'h11, 8'h02);
        induce_nack(7'h11);
        induce_nack(7'h11);
        check_recovery_state(7'h11, 1'b1, 1'b1, 8'h02, 16'd2, 16'd0, 16'd2, 8'd2, RECOVERY_RESET_WAIT, 8'd4, 8'd1);
        repeat (4) pulse_tick;
        check_recovery_state(7'h11, 1'b1, 1'b0, 8'h02, 16'd2, 16'd0, 16'd2, 8'd0, RECOVERY_IDLE, 8'd0, 8'd1);
        induce_nack(7'h11);
        induce_nack(7'h11);
        check_recovery_state(7'h11, 1'b0, 1'b1, 8'h02, 16'd4, 16'd0, 16'd4, 8'd2, RECOVERY_ESCALATED, 8'd0, 8'd1);
        set_status(7'h11, 16'h600D, 1'b1);
        check_recovery_state(7'h11, 1'b1, 1'b0, 8'h02, 16'd4, 16'd0, 16'd4, 8'd0, RECOVERY_IDLE, 8'd0, 8'd0);

        set_reset_action(7'h12, 8'h03);
        induce_nack(7'h12);
        induce_nack(7'h12);
        check_recovery_state(7'h12, 1'b0, 1'b1, 8'h03, 16'd2, 16'd0, 16'd2, 8'd2, RECOVERY_ESCALATED, 8'd0, 8'd0);
        set_status(7'h12, 16'h600D, 1'b1);
        check_recovery_state(7'h12, 1'b1, 1'b0, 8'h03, 16'd2, 16'd0, 16'd2, 8'd0, RECOVERY_IDLE, 8'd0, 8'd0);

        induce_nack(7'h13);
        induce_nack(7'h13);
        check_recovery_state(7'h13, 1'b1, 1'b1, 8'h00, 16'd2, 16'd0, 16'd2, 8'd2, RECOVERY_ESCALATED, 8'd0, 8'd0);
        set_status(7'h13, 16'h600D, 1'b1);
        check_recovery_state(7'h13, 1'b1, 1'b0, 8'h00, 16'd2, 16'd0, 16'd2, 8'd0, RECOVERY_IDLE, 8'd0, 8'd0);

        $display("PASS");
        #50;
        $finish;
    end

    initial begin
        #2_000_000;
        $display("FAIL: timeout");
        $finish(1);
    end

    task add_endpoint;
        input [6:0]  addr;
        input [47:0] pid;
        input [7:0]  bcr;
        input [7:0]  dcr;
        begin
            @(posedge clk);
            endpoint_dynamic_addr <= addr;
            endpoint_pid          <= pid;
            endpoint_bcr          <= bcr;
            endpoint_dcr          <= dcr;
            endpoint_add_valid    <= 1'b1;
            @(posedge clk);
            endpoint_add_valid    <= 1'b0;
            @(posedge clk);
        end
    endtask

    task set_reset_action;
        input [6:0] addr;
        input [7:0] value;
        begin
            @(posedge clk);
            reset_action_update_addr  <= addr;
            reset_action_update_value <= value;
            reset_action_update_valid <= 1'b1;
            @(posedge clk);
            reset_action_update_valid <= 1'b0;
            @(posedge clk);
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
            @(posedge clk);
        end
    endtask

    task induce_nack;
        input [6:0] addr;
        begin
            @(posedge clk);
            service_result_addr  <= addr;
            service_result_nack  <= 1'b1;
            service_result_valid <= 1'b1;
            @(posedge clk);
            service_result_valid <= 1'b0;
            service_result_nack  <= 1'b0;
            @(posedge clk);
        end
    endtask

    task induce_success;
        input [6:0] addr;
        begin
            @(posedge clk);
            service_result_addr  <= addr;
            service_result_nack  <= 1'b0;
            service_result_valid <= 1'b1;
            @(posedge clk);
            service_result_valid <= 1'b0;
            @(posedge clk);
        end
    endtask

    task pulse_tick;
        begin
            @(posedge clk);
            schedule_tick <= 1'b1;
            @(posedge clk);
            schedule_tick <= 1'b0;
            @(posedge clk);
        end
    endtask

    task check_recovery_state;
        input [6:0] expected_addr;
        input       expected_enabled;
        input       expected_fault;
        input [7:0] expected_reset_action;
        input [15:0] expected_service_count;
        input [15:0] expected_success_count;
        input [15:0] expected_error_count;
        input [7:0] expected_failures;
        input [1:0] expected_recovery_state;
        input [7:0] expected_recovery_countdown;
        input [7:0] expected_recovery_attempts;
        begin
            query_addr <= expected_addr;
            @(posedge clk);
            if (!query_found ||
                (query_enabled != expected_enabled) ||
                (query_health_fault != expected_fault) ||
                (query_reset_action != expected_reset_action) ||
                (query_service_count != expected_service_count) ||
                (query_success_count != expected_success_count) ||
                (query_error_count != expected_error_count) ||
                (query_consecutive_failures != expected_failures) ||
                (query_recovery_state != expected_recovery_state) ||
                (query_recovery_countdown != expected_recovery_countdown) ||
                (query_recovery_attempts != expected_recovery_attempts)) begin
                $display("FAIL: recovery state mismatch addr=0x%02h enabled=%0d fault=%0d rstact=0x%02h service=%0d success=%0d error=%0d failrun=%0d recovery_state=%0d countdown=%0d attempts=%0d",
                         expected_addr, query_enabled, query_health_fault, query_reset_action,
                         query_service_count, query_success_count, query_error_count, query_consecutive_failures,
                         query_recovery_state, query_recovery_countdown, query_recovery_attempts);
                $finish(1);
            end
        end
    endtask

endmodule
