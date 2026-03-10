`timescale 1ns/1ps

module i3c_ctrl_policy #(
    parameter integer MAX_ENDPOINTS = 8,
    parameter integer AUTO_FAULT_THRESHOLD = 2
) (
    input  wire                           default_endpoint_enable,
    input  wire [7:0]                     default_service_period,
    input  wire                           clk,
    input  wire                           rst_n,
    input  wire                           clear_table,
    input  wire                           schedule_tick,

    input  wire                           endpoint_add_valid,
    input  wire [6:0]                     endpoint_dynamic_addr,
    input  wire [47:0]                    endpoint_pid,
    input  wire [7:0]                     endpoint_bcr,
    input  wire [7:0]                     endpoint_dcr,

    input  wire                           broadcast_event_set_valid,
    input  wire                           broadcast_event_clear_valid,
    input  wire [7:0]                     broadcast_event_mask,

    input  wire                           direct_event_set_valid,
    input  wire                           direct_event_clear_valid,
    input  wire [6:0]                     direct_event_addr,
    input  wire [7:0]                     direct_event_mask,

    input  wire                           enable_update_valid,
    input  wire [6:0]                     enable_update_addr,
    input  wire                           enable_update_value,

    input  wire                           reset_action_update_valid,
    input  wire [6:0]                     reset_action_update_addr,
    input  wire [7:0]                     reset_action_update_value,

    input  wire                           status_update_valid,
    input  wire [6:0]                     status_update_addr,
    input  wire [15:0]                    status_update_value,
    input  wire                           status_update_ok,

    input  wire                           service_period_update_valid,
    input  wire [6:0]                     service_period_update_addr,
    input  wire [7:0]                     service_period_update_value,

    input  wire                           service_result_valid,
    input  wire [6:0]                     service_result_addr,
    input  wire                           service_result_nack,

    input  wire [6:0]                     query_addr,
    output reg                            query_found,
    output reg  [47:0]                    query_pid,
    output reg  [7:0]                     query_bcr,
    output reg  [7:0]                     query_dcr,
    output reg  [1:0]                     query_class,
    output reg                            query_enabled,
    output reg                            query_health_fault,
    output reg                            query_last_seen_ok,
    output reg  [7:0]                     query_event_mask,
    output reg  [7:0]                     query_reset_action,
    output reg  [15:0]                    query_status,
    output reg  [7:0]                     query_service_period,
    output reg  [15:0]                    query_service_count,
    output reg  [15:0]                    query_success_count,
    output reg  [15:0]                    query_error_count,
    output reg  [7:0]                     query_consecutive_failures,
    output reg  [15:0]                    query_last_service_tag,
    output reg                            query_due_now,

    input  wire [$clog2(MAX_ENDPOINTS)-1:0] scan_index,
    output reg                            scan_valid,
    output reg  [6:0]                     scan_addr,
    output reg  [1:0]                     scan_class,
    output reg                            scan_enabled,
    output reg                            scan_health_fault,
    output reg                            scan_due,

    output reg  [$clog2(MAX_ENDPOINTS):0] endpoint_count,
    output reg                            table_full,
    output reg                            policy_update_miss,
    output reg  [6:0]                     last_update_addr,
    output reg  [7:0]                     last_event_mask
);

    integer i;
    localparam [7:0] AUTO_FAULT_THRESHOLD_U8 = AUTO_FAULT_THRESHOLD;
    reg       add_seen_match;
    reg       direct_seen_match;
    reg [7:0] updated_mask;

    reg [6:0]  addr_table      [0:MAX_ENDPOINTS-1];
    reg [47:0] pid_table       [0:MAX_ENDPOINTS-1];
    reg [7:0]  bcr_table       [0:MAX_ENDPOINTS-1];
    reg [7:0]  dcr_table       [0:MAX_ENDPOINTS-1];
    reg [1:0]  class_table     [0:MAX_ENDPOINTS-1];
    reg        enabled_table   [0:MAX_ENDPOINTS-1];
    reg        health_fault_table[0:MAX_ENDPOINTS-1];
    reg        last_seen_ok_table[0:MAX_ENDPOINTS-1];
    reg [7:0]  event_mask_table[0:MAX_ENDPOINTS-1];
    reg [7:0]  reset_action_table[0:MAX_ENDPOINTS-1];
    reg [15:0] status_table    [0:MAX_ENDPOINTS-1];
    reg [7:0]  service_period_table[0:MAX_ENDPOINTS-1];
    reg [15:0] service_count_table[0:MAX_ENDPOINTS-1];
    reg [15:0] success_count_table[0:MAX_ENDPOINTS-1];
    reg [15:0] error_count_table[0:MAX_ENDPOINTS-1];
    reg [7:0]  consecutive_failures_table[0:MAX_ENDPOINTS-1];
    reg [15:0] last_service_tag_table[0:MAX_ENDPOINTS-1];
    reg [15:0] schedule_tag;

    function [1:0] derive_class;
        input [7:0] bcr;
        input [7:0] dcr;
        begin
            if (bcr[5]) begin
                derive_class = 2'd2;
            end else if (dcr[7]) begin
                derive_class = 2'd3;
            end else if (dcr[4]) begin
                derive_class = 2'd1;
            end else begin
                derive_class = 2'd0;
            end
        end
    endfunction

    always @(*) begin
        query_found      = 1'b0;
        query_pid        = 48'h0;
        query_bcr        = 8'h00;
        query_dcr        = 8'h00;
        query_class      = 2'd0;
        query_enabled    = 1'b0;
        query_health_fault = 1'b0;
        query_last_seen_ok = 1'b0;
        query_event_mask = 8'h00;
        query_reset_action = 8'h00;
        query_status     = 16'h0000;
        query_service_period = 8'd1;
        query_service_count = 16'h0000;
        query_success_count = 16'h0000;
        query_error_count = 16'h0000;
        query_consecutive_failures = 8'h00;
        query_last_service_tag = 16'h0000;
        query_due_now = 1'b0;
        scan_valid       = 1'b0;
        scan_addr        = 7'h00;
        scan_class       = 2'd0;
        scan_enabled     = 1'b0;
        scan_health_fault = 1'b0;
        scan_due         = 1'b0;

        for (i = 0; i < MAX_ENDPOINTS; i = i + 1) begin
            if ((i < endpoint_count) && (addr_table[i] == query_addr)) begin
                query_found      = 1'b1;
                query_pid        = pid_table[i];
                query_bcr        = bcr_table[i];
                query_dcr        = dcr_table[i];
                query_class      = class_table[i];
                query_enabled    = enabled_table[i];
                query_health_fault = health_fault_table[i];
                query_last_seen_ok = last_seen_ok_table[i];
                query_event_mask = event_mask_table[i];
                query_reset_action = reset_action_table[i];
                query_status     = status_table[i];
                query_service_period = service_period_table[i];
                query_service_count = service_count_table[i];
                query_success_count = success_count_table[i];
                query_error_count = error_count_table[i];
                query_consecutive_failures = consecutive_failures_table[i];
                query_last_service_tag = last_service_tag_table[i];
                query_due_now = (service_count_table[i] == 16'h0000) ||
                                ((schedule_tag - last_service_tag_table[i]) >= service_period_table[i]);
            end
        end

        if (scan_index < endpoint_count) begin
            scan_valid        = 1'b1;
            scan_addr         = addr_table[scan_index];
            scan_class        = class_table[scan_index];
            scan_enabled      = enabled_table[scan_index];
            scan_health_fault = health_fault_table[scan_index];
            scan_due          = (service_count_table[scan_index] == 16'h0000) ||
                                ((schedule_tag - last_service_tag_table[scan_index]) >= service_period_table[scan_index]);
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            schedule_tag       <= 16'h0000;
            endpoint_count     <= {($clog2(MAX_ENDPOINTS)+1){1'b0}};
            table_full         <= 1'b0;
            policy_update_miss <= 1'b0;
            last_update_addr   <= 7'h00;
            last_event_mask    <= 8'h00;
            for (i = 0; i < MAX_ENDPOINTS; i = i + 1) begin
                addr_table[i]       <= 7'h00;
                pid_table[i]        <= 48'h0;
                bcr_table[i]        <= 8'h00;
                dcr_table[i]        <= 8'h00;
                class_table[i]      <= 2'd0;
                enabled_table[i]    <= 1'b0;
                health_fault_table[i] <= 1'b0;
                last_seen_ok_table[i] <= 1'b0;
                event_mask_table[i] <= 8'h00;
                reset_action_table[i] <= 8'h00;
                status_table[i]     <= 16'h0000;
                service_period_table[i] <= 8'd1;
                service_count_table[i] <= 16'h0000;
                success_count_table[i] <= 16'h0000;
                error_count_table[i] <= 16'h0000;
                consecutive_failures_table[i] <= 8'h00;
                last_service_tag_table[i] <= 16'h0000;
            end
        end else begin
            policy_update_miss <= 1'b0;
            if (schedule_tick) begin
                schedule_tag <= schedule_tag + 1'b1;
            end

            if (clear_table) begin
                schedule_tag       <= 16'h0000;
                endpoint_count     <= {($clog2(MAX_ENDPOINTS)+1){1'b0}};
                table_full         <= 1'b0;
                policy_update_miss <= 1'b0;
                last_update_addr   <= 7'h00;
                last_event_mask    <= 8'h00;
                for (i = 0; i < MAX_ENDPOINTS; i = i + 1) begin
                    addr_table[i]       <= 7'h00;
                    pid_table[i]        <= 48'h0;
                    bcr_table[i]        <= 8'h00;
                    dcr_table[i]        <= 8'h00;
                    class_table[i]      <= 2'd0;
                    enabled_table[i]    <= 1'b0;
                    health_fault_table[i] <= 1'b0;
                    last_seen_ok_table[i] <= 1'b0;
                    event_mask_table[i] <= 8'h00;
                    reset_action_table[i] <= 8'h00;
                    status_table[i]     <= 16'h0000;
                    service_period_table[i] <= 8'd1;
                    service_count_table[i] <= 16'h0000;
                    success_count_table[i] <= 16'h0000;
                    error_count_table[i] <= 16'h0000;
                    consecutive_failures_table[i] <= 8'h00;
                    last_service_tag_table[i] <= 16'h0000;
                end
            end else if (endpoint_add_valid) begin
                add_seen_match = 1'b0;
                for (i = 0; i < MAX_ENDPOINTS; i = i + 1) begin
                    if ((i < endpoint_count) && (addr_table[i] == endpoint_dynamic_addr)) begin
                        addr_table[i] <= endpoint_dynamic_addr;
                        pid_table[i]  <= endpoint_pid;
                        bcr_table[i]  <= endpoint_bcr;
                        dcr_table[i]  <= endpoint_dcr;
                        class_table[i] <= derive_class(endpoint_bcr, endpoint_dcr);
                        if (service_period_table[i] == 8'h00) begin
                            service_period_table[i] <= 8'd1;
                        end
                        add_seen_match = 1'b1;
                    end
                end

                last_update_addr <= endpoint_dynamic_addr;
                if (!add_seen_match) begin
                    if (endpoint_count < MAX_ENDPOINTS) begin
                        addr_table[endpoint_count]       <= endpoint_dynamic_addr;
                        pid_table[endpoint_count]        <= endpoint_pid;
                        bcr_table[endpoint_count]        <= endpoint_bcr;
                        dcr_table[endpoint_count]        <= endpoint_dcr;
                        class_table[endpoint_count]      <= derive_class(endpoint_bcr, endpoint_dcr);
                        enabled_table[endpoint_count]    <= default_endpoint_enable;
                        health_fault_table[endpoint_count] <= 1'b0;
                        last_seen_ok_table[endpoint_count] <= 1'b0;
                        event_mask_table[endpoint_count] <= 8'h00;
                        reset_action_table[endpoint_count] <= 8'h00;
                        status_table[endpoint_count]     <= 16'h0000;
                        service_period_table[endpoint_count] <= (default_service_period == 8'h00) ? 8'd1 : default_service_period;
                        service_count_table[endpoint_count] <= 16'h0000;
                        success_count_table[endpoint_count] <= 16'h0000;
                        error_count_table[endpoint_count] <= 16'h0000;
                        consecutive_failures_table[endpoint_count] <= 8'h00;
                        last_service_tag_table[endpoint_count] <= 16'h0000;
                        endpoint_count                   <= endpoint_count + 1'b1;
                        table_full                       <= 1'b0;
                        last_event_mask                  <= 8'h00;
                    end else begin
                        table_full <= 1'b1;
                    end
                end
            end else if (broadcast_event_set_valid || broadcast_event_clear_valid) begin
                last_update_addr <= 7'h7E;
                for (i = 0; i < MAX_ENDPOINTS; i = i + 1) begin
                    if (i < endpoint_count) begin
                        if (broadcast_event_set_valid) begin
                            event_mask_table[i] <= event_mask_table[i] | broadcast_event_mask;
                            last_event_mask     <= event_mask_table[i] | broadcast_event_mask;
                        end else begin
                            event_mask_table[i] <= event_mask_table[i] & ~broadcast_event_mask;
                            last_event_mask     <= event_mask_table[i] & ~broadcast_event_mask;
                        end
                    end
                end
            end else if (direct_event_set_valid || direct_event_clear_valid) begin
                direct_seen_match = 1'b0;
                updated_mask      = 8'h00;
                last_update_addr  <= direct_event_addr;

                for (i = 0; i < MAX_ENDPOINTS; i = i + 1) begin
                    if ((i < endpoint_count) && (addr_table[i] == direct_event_addr)) begin
                        if (direct_event_set_valid) begin
                            updated_mask        = event_mask_table[i] | direct_event_mask;
                            event_mask_table[i] <= event_mask_table[i] | direct_event_mask;
                        end else begin
                            updated_mask        = event_mask_table[i] & ~direct_event_mask;
                            event_mask_table[i] <= event_mask_table[i] & ~direct_event_mask;
                        end
                        direct_seen_match = 1'b1;
                    end
                end

                if (direct_seen_match) begin
                    last_event_mask <= updated_mask;
                end else begin
                    policy_update_miss <= 1'b1;
                end
            end else if (enable_update_valid) begin
                direct_seen_match = 1'b0;
                last_update_addr  <= enable_update_addr;
                for (i = 0; i < MAX_ENDPOINTS; i = i + 1) begin
                    if ((i < endpoint_count) && (addr_table[i] == enable_update_addr)) begin
                        enabled_table[i] <= enable_update_value;
                        direct_seen_match = 1'b1;
                    end
                end
                if (!direct_seen_match) begin
                    policy_update_miss <= 1'b1;
                end
            end else if (service_period_update_valid) begin
                direct_seen_match = 1'b0;
                last_update_addr  <= service_period_update_addr;
                for (i = 0; i < MAX_ENDPOINTS; i = i + 1) begin
                    if ((i < endpoint_count) && (addr_table[i] == service_period_update_addr)) begin
                        service_period_table[i] <= (service_period_update_value == 8'h00) ? 8'd1 : service_period_update_value;
                        direct_seen_match = 1'b1;
                    end
                end
                if (!direct_seen_match) begin
                    policy_update_miss <= 1'b1;
                end
            end else if (reset_action_update_valid) begin
                direct_seen_match = 1'b0;
                last_update_addr  <= reset_action_update_addr;
                for (i = 0; i < MAX_ENDPOINTS; i = i + 1) begin
                    if ((i < endpoint_count) && (addr_table[i] == reset_action_update_addr)) begin
                        reset_action_table[i] <= reset_action_update_value;
                        direct_seen_match      = 1'b1;
                    end
                end
                if (!direct_seen_match) begin
                    policy_update_miss <= 1'b1;
                end
            end else if (status_update_valid) begin
                direct_seen_match = 1'b0;
                last_update_addr  <= status_update_addr;
                for (i = 0; i < MAX_ENDPOINTS; i = i + 1) begin
                    if ((i < endpoint_count) && (addr_table[i] == status_update_addr)) begin
                        status_table[i] <= status_update_value;
                        last_seen_ok_table[i] <= status_update_ok;
                        health_fault_table[i] <= !status_update_ok;
                        if (status_update_ok) begin
                            consecutive_failures_table[i] <= 8'h00;
                        end
                        direct_seen_match = 1'b1;
                    end
                end
                if (!direct_seen_match) begin
                    policy_update_miss <= 1'b1;
                end
            end else if (service_result_valid) begin
                direct_seen_match = 1'b0;
                last_update_addr  <= service_result_addr;
                for (i = 0; i < MAX_ENDPOINTS; i = i + 1) begin
                    if ((i < endpoint_count) && (addr_table[i] == service_result_addr)) begin
                        service_count_table[i] <= service_count_table[i] + 1'b1;
                        last_service_tag_table[i] <= schedule_tag;
                        if (service_result_nack) begin
                            error_count_table[i] <= error_count_table[i] + 1'b1;
                            consecutive_failures_table[i] <= consecutive_failures_table[i] + 1'b1;
                            last_seen_ok_table[i] <= 1'b0;
                            if ((consecutive_failures_table[i] + 1'b1) >= AUTO_FAULT_THRESHOLD_U8) begin
                                health_fault_table[i] <= 1'b1;
                            end
                        end else begin
                            success_count_table[i] <= success_count_table[i] + 1'b1;
                            consecutive_failures_table[i] <= 8'h00;
                            last_seen_ok_table[i] <= 1'b1;
                        end
                        direct_seen_match = 1'b1;
                    end
                end
                if (!direct_seen_match) begin
                    policy_update_miss <= 1'b1;
                end
            end
        end
    end
endmodule
