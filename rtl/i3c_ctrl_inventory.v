`timescale 1ns/1ps

module i3c_ctrl_inventory #(
    parameter integer MAX_ENDPOINTS = 8,
    parameter [6:0]  DYN_ADDR_BASE  = 7'h10
) (
    input  wire                           clk,
    input  wire                           rst_n,
    input  wire                           clear_tables,
    input  wire                           default_endpoint_enable,

    input  wire                           discover_valid,
    input  wire [47:0]                    discover_pid,
    input  wire [7:0]                     discover_bcr,
    input  wire [7:0]                     discover_dcr,

    input  wire                           broadcast_event_set_valid,
    input  wire                           broadcast_event_clear_valid,
    input  wire [7:0]                     broadcast_event_mask,

    input  wire                           direct_event_set_valid,
    input  wire                           direct_event_clear_valid,
    input  wire [6:0]                     direct_event_addr,
    input  wire [7:0]                     direct_event_mask,

    input  wire                           reset_action_update_valid,
    input  wire [6:0]                     reset_action_update_addr,
    input  wire [7:0]                     reset_action_update_value,

    input  wire                           status_update_valid,
    input  wire [6:0]                     status_update_addr,
    input  wire [15:0]                    status_update_value,
    input  wire                           status_update_ok,

    input  wire [6:0]                     query_addr,
    output wire                           query_found,
    output wire [47:0]                    query_pid,
    output wire [7:0]                     query_bcr,
    output wire [7:0]                     query_dcr,
    output wire [1:0]                     query_class,
    output wire                           query_enabled,
    output wire                           query_health_fault,
    output wire                           query_last_seen_ok,
    output wire [7:0]                     query_event_mask,
    output wire [7:0]                     query_reset_action,
    output wire [15:0]                    query_status,

    output wire                           assign_valid,
    output wire [6:0]                     assign_dynamic_addr,
    output wire [$clog2(MAX_ENDPOINTS):0] daa_endpoint_count,
    output wire                           daa_table_full,
    output wire                           duplicate_pid,
    output wire [47:0]                    last_pid,
    output wire [7:0]                     last_bcr,
    output wire [7:0]                     last_dcr,

    output wire [$clog2(MAX_ENDPOINTS):0] policy_endpoint_count,
    output wire                           policy_table_full,
    output wire                           policy_update_miss,
    output wire [6:0]                     last_update_addr,
    output wire [7:0]                     last_event_mask
);

    i3c_ctrl_daa #(
        .MAX_ENDPOINTS(MAX_ENDPOINTS),
        .DYN_ADDR_BASE(DYN_ADDR_BASE)
    ) u_daa (
        .clk                (clk),
        .rst_n              (rst_n),
        .clear_table        (clear_tables),
        .discover_valid     (discover_valid),
        .discover_pid       (discover_pid),
        .discover_bcr       (discover_bcr),
        .discover_dcr       (discover_dcr),
        .assign_valid       (assign_valid),
        .assign_dynamic_addr(assign_dynamic_addr),
        .endpoint_count     (daa_endpoint_count),
        .table_full         (daa_table_full),
        .duplicate_pid      (duplicate_pid),
        .last_pid           (last_pid),
        .last_bcr           (last_bcr),
        .last_dcr           (last_dcr)
    );

    i3c_ctrl_policy #(
        .MAX_ENDPOINTS(MAX_ENDPOINTS)
    ) u_policy (
        .default_endpoint_enable(default_endpoint_enable),
        .clk                     (clk),
        .rst_n                   (rst_n),
        .clear_table             (clear_tables),
        .endpoint_add_valid      (assign_valid),
        .endpoint_dynamic_addr   (assign_dynamic_addr),
        .endpoint_pid            (last_pid),
        .endpoint_bcr            (last_bcr),
        .endpoint_dcr            (last_dcr),
        .broadcast_event_set_valid(broadcast_event_set_valid),
        .broadcast_event_clear_valid(broadcast_event_clear_valid),
        .broadcast_event_mask    (broadcast_event_mask),
        .direct_event_set_valid  (direct_event_set_valid),
        .direct_event_clear_valid(direct_event_clear_valid),
        .direct_event_addr       (direct_event_addr),
        .direct_event_mask       (direct_event_mask),
        .reset_action_update_valid(reset_action_update_valid),
        .reset_action_update_addr(reset_action_update_addr),
        .reset_action_update_value(reset_action_update_value),
        .status_update_valid     (status_update_valid),
        .status_update_addr      (status_update_addr),
        .status_update_value     (status_update_value),
        .status_update_ok        (status_update_ok),
        .query_addr              (query_addr),
        .query_found             (query_found),
        .query_pid               (query_pid),
        .query_bcr               (query_bcr),
        .query_dcr               (query_dcr),
        .query_class             (query_class),
        .query_enabled           (query_enabled),
        .query_health_fault      (query_health_fault),
        .query_last_seen_ok      (query_last_seen_ok),
        .query_event_mask        (query_event_mask),
        .query_reset_action      (query_reset_action),
        .query_status            (query_status),
        .endpoint_count          (policy_endpoint_count),
        .table_full              (policy_table_full),
        .policy_update_miss      (policy_update_miss),
        .last_update_addr        (last_update_addr),
        .last_event_mask         (last_event_mask)
    );
endmodule
