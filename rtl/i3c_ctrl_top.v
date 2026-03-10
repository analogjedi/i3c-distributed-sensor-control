`timescale 1ns/1ps

module i3c_ctrl_top #(
    parameter integer MAX_ENDPOINTS = 8,
    parameter [6:0]  DYN_ADDR_BASE  = 7'h10,
    parameter integer CLK_FREQ_HZ   = 100_000_000,
    parameter integer I3C_SDR_HZ    = 1_000_000,
    parameter integer PUSH_PULL_DATA = 1
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

    input  wire                           schedule_enable,
    input  wire                           schedule_tick,

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

    output wire [$clog2(MAX_ENDPOINTS):0] endpoint_count,
    output wire                           policy_table_full,
    output wire                           policy_update_miss,
    output wire                           scheduler_busy,
    output wire                           scheduler_missed_slot,

    output reg                            service_rsp_valid,
    output reg                            service_rsp_nack,
    output reg  [6:0]                     service_rsp_addr,
    output reg  [1:0]                     service_rsp_class,
    output reg  [$clog2(MAX_ENDPOINTS)-1:0] service_rsp_index,
    output reg  [7:0]                     service_rsp_rdata,
    output reg                            service_busy,

    output wire                           scl_o,
    output wire                           scl_oe,
    output wire                           sda_o,
    output wire                           sda_oe,
    input  wire                           sda_i
);

    localparam integer INDEX_W = (MAX_ENDPOINTS <= 1) ? 1 : $clog2(MAX_ENDPOINTS);

    localparam [1:0] SVC_IDLE      = 2'd0;
    localparam [1:0] SVC_WAIT_REQ  = 2'd1;
    localparam [1:0] SVC_WAIT_RSP  = 2'd2;

    reg  [1:0] svc_state;
    reg        sched_req_accept;
    wire       sched_req_valid;
    wire [6:0] sched_req_addr;
    wire [1:0] sched_req_class;
    wire [INDEX_W-1:0] sched_req_index;
    wire [INDEX_W-1:0] scan_index;
    wire       scan_valid;
    wire [6:0] scan_addr;
    wire [1:0] scan_class;
    wire       scan_enabled;
    wire       scan_health_fault;

    reg        txn_req_valid;
    wire       txn_req_ready;
    wire       txn_rsp_valid;
    wire       txn_rsp_nack;
    wire [7:0] txn_rsp_rx_count;
    wire [31:0] txn_rsp_rdata;
    wire       txn_busy;

    reg [6:0]             pending_addr;
    reg [1:0]             pending_class;
    reg [INDEX_W-1:0]     pending_index;

    i3c_ctrl_inventory #(
        .MAX_ENDPOINTS(MAX_ENDPOINTS),
        .DYN_ADDR_BASE(DYN_ADDR_BASE)
    ) u_inventory (
        .clk                      (clk),
        .rst_n                    (rst_n),
        .clear_tables             (clear_tables),
        .default_endpoint_enable  (default_endpoint_enable),
        .discover_valid           (discover_valid),
        .discover_pid             (discover_pid),
        .discover_bcr             (discover_bcr),
        .discover_dcr             (discover_dcr),
        .broadcast_event_set_valid(broadcast_event_set_valid),
        .broadcast_event_clear_valid(broadcast_event_clear_valid),
        .broadcast_event_mask     (broadcast_event_mask),
        .direct_event_set_valid   (direct_event_set_valid),
        .direct_event_clear_valid (direct_event_clear_valid),
        .direct_event_addr        (direct_event_addr),
        .direct_event_mask        (direct_event_mask),
        .enable_update_valid      (enable_update_valid),
        .enable_update_addr       (enable_update_addr),
        .enable_update_value      (enable_update_value),
        .reset_action_update_valid(reset_action_update_valid),
        .reset_action_update_addr (reset_action_update_addr),
        .reset_action_update_value(reset_action_update_value),
        .status_update_valid      (status_update_valid),
        .status_update_addr       (status_update_addr),
        .status_update_value      (status_update_value),
        .status_update_ok         (status_update_ok),
        .query_addr               (query_addr),
        .query_found              (query_found),
        .query_pid                (query_pid),
        .query_bcr                (query_bcr),
        .query_dcr                (query_dcr),
        .query_class              (query_class),
        .query_enabled            (query_enabled),
        .query_health_fault       (query_health_fault),
        .query_last_seen_ok       (query_last_seen_ok),
        .query_event_mask         (query_event_mask),
        .query_reset_action       (query_reset_action),
        .query_status             (query_status),
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
        .policy_table_full        (policy_table_full),
        .policy_update_miss       (policy_update_miss),
        .last_update_addr         (),
        .last_event_mask          ()
    );

    i3c_ctrl_scheduler #(
        .MAX_ENDPOINTS(MAX_ENDPOINTS)
    ) u_scheduler (
        .clk              (clk),
        .rst_n            (rst_n),
        .enable           (schedule_enable),
        .schedule_tick    (schedule_tick),
        .req_accept       (sched_req_accept),
        .endpoint_count   (endpoint_count),
        .scan_index       (scan_index),
        .scan_valid       (scan_valid),
        .scan_addr        (scan_addr),
        .scan_class       (scan_class),
        .scan_enabled     (scan_enabled),
        .scan_health_fault(scan_health_fault),
        .req_valid        (sched_req_valid),
        .req_addr         (sched_req_addr),
        .req_class        (sched_req_class),
        .req_index        (sched_req_index),
        .busy             (scheduler_busy),
        .missed_slot      (scheduler_missed_slot)
    );

    i3c_ctrl_txn_layer #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .I3C_SDR_HZ(I3C_SDR_HZ),
        .PUSH_PULL_DATA(PUSH_PULL_DATA),
        .MAX_TX_BYTES(4),
        .MAX_RX_BYTES(4)
    ) u_txn (
        .clk             (clk),
        .rst_n           (rst_n),
        .txn_req_valid   (txn_req_valid),
        .txn_req_ready   (txn_req_ready),
        .txn_req_addr    (pending_addr),
        .txn_req_read    (1'b1),
        .txn_req_tx_len  (8'd0),
        .txn_req_rx_len  (8'd1),
        .txn_req_wdata   (32'h0000_0000),
        .txn_rsp_valid   (txn_rsp_valid),
        .txn_rsp_nack    (txn_rsp_nack),
        .txn_rsp_rx_count(txn_rsp_rx_count),
        .txn_rsp_rdata   (txn_rsp_rdata),
        .busy            (txn_busy),
        .scl_o           (scl_o),
        .scl_oe          (scl_oe),
        .sda_o           (sda_o),
        .sda_oe          (sda_oe),
        .sda_i           (sda_i)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            svc_state         <= SVC_IDLE;
            sched_req_accept  <= 1'b0;
            txn_req_valid     <= 1'b0;
            pending_addr      <= 7'h00;
            pending_class     <= 2'd0;
            pending_index     <= {INDEX_W{1'b0}};
            service_rsp_valid <= 1'b0;
            service_rsp_nack  <= 1'b0;
            service_rsp_addr  <= 7'h00;
            service_rsp_class <= 2'd0;
            service_rsp_index <= {INDEX_W{1'b0}};
            service_rsp_rdata <= 8'h00;
            service_busy      <= 1'b0;
        end else begin
            sched_req_accept  <= 1'b0;
            service_rsp_valid <= 1'b0;
            service_busy      <= (svc_state != SVC_IDLE) || scheduler_busy || txn_busy;

            case (svc_state)
                SVC_IDLE: begin
                    txn_req_valid <= 1'b0;
                    if (sched_req_valid) begin
                        pending_addr  <= sched_req_addr;
                        pending_class <= sched_req_class;
                        pending_index <= sched_req_index;
                        txn_req_valid <= 1'b1;
                        svc_state     <= SVC_WAIT_REQ;
                    end
                end

                SVC_WAIT_REQ: begin
                    if (txn_req_valid && txn_req_ready) begin
                        txn_req_valid    <= 1'b0;
                        sched_req_accept <= 1'b1;
                        svc_state        <= SVC_WAIT_RSP;
                    end
                end

                SVC_WAIT_RSP: begin
                    if (txn_rsp_valid) begin
                        service_rsp_valid <= 1'b1;
                        service_rsp_nack  <= txn_rsp_nack;
                        service_rsp_addr  <= pending_addr;
                        service_rsp_class <= pending_class;
                        service_rsp_index <= pending_index;
                        service_rsp_rdata <= txn_rsp_rdata[7:0];
                        svc_state         <= SVC_IDLE;
                    end
                end

                default: begin
                    svc_state <= SVC_IDLE;
                end
            endcase
        end
    end
endmodule
