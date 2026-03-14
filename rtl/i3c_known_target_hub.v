`timescale 1ns/1ps

module i3c_known_target_hub #(
    parameter integer ENDPOINT_COUNT     = 5,
    parameter integer MAX_SERVICE_BYTES  = 16,
    parameter integer PAYLOAD_BYTES      = 10,
    parameter integer CLK_FREQ_HZ        = 100_000_000,
    parameter integer I3C_SDR_HZ         = 12_500_000,
    parameter integer SAMPLE_RATE_HZ     = 2_000,
    parameter [6:0]  DYN_ADDR_BASE       = 7'h10,
    parameter [6:0]  STATIC_ADDR_BASE    = 7'h30,
    parameter [47:0] PROVISIONAL_ID_BASE = 48'h4100_0000_0001,
    parameter [7:0]  TARGET_BCR          = 8'h21,
    parameter [7:0]  TARGET_DCR          = 8'h90,
    parameter [7:0]  SAMPLE_SELECTOR     = 8'h40,
    parameter [7:0]  FAULT_DIAG_EVENT_MASK = 8'h01,
    parameter [7:0]  RECOVERY_RSTACT_ACTION = 8'h02
) (
    input  wire                                   clk,
    input  wire                                   rst_n,
    output wire                                   scl_o,
    output wire                                   scl_oe,
    output wire                                   sda_o,
    output wire                                   sda_oe,
    input  wire                                   sda_i,

    input  wire [ENDPOINT_COUNT-1:0]              fault_diag_ibi_req,

    output reg                                    boot_done,
    output reg                                    boot_error,
    output reg                                    capture_error,
    output reg                                    recovery_active,
    output reg                                    fault_diag_irq,
    output reg  [ENDPOINT_COUNT-1:0]              verified_bitmap,
    output reg  [ENDPOINT_COUNT-1:0]              recovered_bitmap,
    output reg  [ENDPOINT_COUNT-1:0]              fault_diag_seen_bitmap,
    output reg  [ENDPOINT_COUNT-1:0]              fault_diag_enable_bitmap,
    output reg  [ENDPOINT_COUNT-1:0]              sample_valid_bitmap,
    output reg  [ENDPOINT_COUNT*PAYLOAD_BYTES*8-1:0] sample_payloads_flat,
    output reg  [ENDPOINT_COUNT*16-1:0]           sample_capture_count_flat,
    output reg  [6:0]                             last_service_addr,
    output reg  [7:0]                             last_service_count,
    output reg  [6:0]                             last_recovery_addr,
    output reg  [6:0]                             last_diag_addr,
    output reg  [15:0]                            last_status_word
);

    localparam integer INDEX_W = (ENDPOINT_COUNT <= 1) ? 1 : $clog2(ENDPOINT_COUNT);
    localparam integer PID_BYTES = 6;
    localparam integer STATUS_BYTES = 2;
    localparam integer SCHEDULE_TICK_HZ = ENDPOINT_COUNT * SAMPLE_RATE_HZ;
    localparam [7:0] PAYLOAD_BYTES_U8 = PAYLOAD_BYTES;
    localparam [7:0] PID_BYTES_U8 = PID_BYTES;
    localparam [7:0] STATUS_BYTES_U8 = STATUS_BYTES;

    localparam [7:0] CCC_ENEC       = 8'h80;
    localparam [7:0] CCC_GETPID     = 8'h8D;
    localparam [7:0] CCC_GETBCR     = 8'h8E;
    localparam [7:0] CCC_GETDCR     = 8'h8F;
    localparam [7:0] CCC_GETSTATUS  = 8'h90;
    localparam [7:0] CCC_SETDASA    = 8'h87;
    localparam [7:0] CCC_RSTACT     = 8'h9A;

    localparam [5:0] ST_BOOT_SETDASA_REQ  = 6'd0;
    localparam [5:0] ST_BOOT_SETDASA_WAIT = 6'd1;
    localparam [5:0] ST_BOOT_GETPID_REQ   = 6'd2;
    localparam [5:0] ST_BOOT_GETPID_WAIT  = 6'd3;
    localparam [5:0] ST_BOOT_GETBCR_REQ   = 6'd4;
    localparam [5:0] ST_BOOT_GETBCR_WAIT  = 6'd5;
    localparam [5:0] ST_BOOT_GETDCR_REQ   = 6'd6;
    localparam [5:0] ST_BOOT_GETDCR_WAIT  = 6'd7;
    localparam [5:0] ST_BOOT_GETSTATUS_REQ = 6'd8;
    localparam [5:0] ST_BOOT_GETSTATUS_WAIT = 6'd9;
    localparam [5:0] ST_BOOT_RSTACT_REQ   = 6'd10;
    localparam [5:0] ST_BOOT_RSTACT_WAIT  = 6'd11;
    localparam [5:0] ST_BOOT_ENEC_REQ     = 6'd12;
    localparam [5:0] ST_BOOT_ENEC_WAIT    = 6'd13;
    localparam [5:0] ST_BOOT_DISCOVER     = 6'd14;
    localparam [5:0] ST_BOOT_CFG_PERIOD   = 6'd15;
    localparam [5:0] ST_BOOT_CFG_LEN      = 6'd16;
    localparam [5:0] ST_BOOT_CFG_SEL      = 6'd17;
    localparam [5:0] ST_BOOT_NEXT         = 6'd18;
    localparam [5:0] ST_RUN               = 6'd19;
    localparam [5:0] ST_DIAG_GETSTATUS_REQ = 6'd20;
    localparam [5:0] ST_DIAG_GETSTATUS_WAIT = 6'd21;
    localparam [5:0] ST_RECOVER_SETDASA_REQ = 6'd22;
    localparam [5:0] ST_RECOVER_SETDASA_WAIT = 6'd23;
    localparam [5:0] ST_RECOVER_GETSTATUS_REQ = 6'd24;
    localparam [5:0] ST_RECOVER_GETSTATUS_WAIT = 6'd25;
    localparam [5:0] ST_RECOVER_REENABLE  = 6'd26;
    localparam [5:0] ST_ERROR             = 6'd27;

    reg [5:0] hub_state;
    reg [INDEX_W-1:0] boot_index;
    reg [INDEX_W-1:0] active_index;
    reg               active_diag_request;

    reg        discover_valid;
    reg [47:0] discover_pid;
    reg [7:0]  discover_bcr;
    reg [7:0]  discover_dcr;
    reg        direct_event_set_valid;
    reg [6:0]  direct_event_addr;
    reg [7:0]  direct_event_mask;
    reg        enable_update_valid;
    reg [6:0]  enable_update_addr;
    reg        enable_update_value;
    reg        reset_action_update_valid;
    reg [6:0]  reset_action_update_addr;
    reg [7:0]  reset_action_update_value;
    reg        status_update_valid;
    reg [6:0]  status_update_addr;
    reg [15:0] status_update_value;
    reg        status_update_ok;
    reg        service_period_update_valid;
    reg [6:0]  service_period_update_addr;
    reg [7:0]  service_period_update_value;
    reg        service_len_update_valid;
    reg [6:0]  service_len_update_addr;
    reg [7:0]  service_len_update_value;
    reg        service_selector_update_valid;
    reg [6:0]  service_selector_update_addr;
    reg [7:0]  service_selector_update_value;

    wire       schedule_tick;
    localparam integer SCHEDULE_DIV_CLKS = (SCHEDULE_TICK_HZ <= 0) ? 1 : (CLK_FREQ_HZ / SCHEDULE_TICK_HZ);
    localparam integer SCHEDULE_DIV_W = (SCHEDULE_DIV_CLKS <= 1) ? 1 : $clog2(SCHEDULE_DIV_CLKS);
    reg [SCHEDULE_DIV_W-1:0] schedule_div_cnt;
    wire       query_found;
    wire [47:0] query_pid;
    wire [7:0] query_bcr;
    wire [7:0] query_dcr;
    wire [1:0] query_class;
    wire       query_enabled;
    wire       query_health_fault;
    wire       query_last_seen_ok;
    wire [7:0] query_event_mask;
    wire [7:0] query_reset_action;
    wire [15:0] query_status;
    wire [7:0] query_service_period;
    wire [7:0] query_service_rx_len;
    wire [7:0] query_service_selector;
    wire [15:0] query_service_count;
    wire [15:0] query_success_count;
    wire [15:0] query_error_count;
    wire [7:0] query_consecutive_failures;
    wire [15:0] query_last_service_tag;
    wire       query_due_now;
    wire [$clog2(ENDPOINT_COUNT):0] endpoint_count;
    wire       policy_table_full;
    wire       policy_update_miss;
    wire       scheduler_busy;
    wire       scheduler_missed_slot;
    wire       service_rsp_valid;
    wire       service_rsp_nack;
    wire [6:0] service_rsp_addr;
    wire [1:0] service_rsp_class;
    wire [INDEX_W-1:0] service_rsp_index;
    wire [7:0] service_rsp_rx_count;
    wire [8*MAX_SERVICE_BYTES-1:0] service_rsp_rdata;
    wire       ctrl_service_busy;

    reg        dccc_cmd_valid;
    wire       dccc_cmd_ready;
    reg [7:0]  dccc_ccc_code;
    reg [6:0]  dccc_target_addr;
    reg        dccc_target_read;
    reg [7:0]  dccc_tx_len;
    reg [7:0]  dccc_rx_len;
    reg [47:0] dccc_tx_data;
    wire       dccc_rsp_valid;
    wire       dccc_rsp_nack;
    wire [7:0] dccc_rsp_rx_count;
    wire [47:0] dccc_rsp_rdata;
    wire       dccc_busy;
    wire       dccc_scl_o;
    wire       dccc_scl_oe;
    wire       dccc_sda_o;
    wire       dccc_sda_oe;

    wire       ctrl_scl_o;
    wire       ctrl_scl_oe;
    wire       ctrl_sda_o;
    wire       ctrl_sda_oe;
    wire       dccc_bus_owner = (hub_state != ST_RUN);
    wire [ENDPOINT_COUNT-1:0] fault_diag_req_masked = fault_diag_ibi_req & fault_diag_enable_bitmap;
    wire [INDEX_W-1:0] fault_diag_req_index = first_request_index(fault_diag_req_masked);
    wire fault_diag_req_valid = |fault_diag_req_masked;
    wire [15:0] dccc_status_word = decode_status_word(dccc_rsp_rdata[15:0]);

    integer i;

    function [6:0] endpoint_static_addr;
        input integer idx;
        begin
            endpoint_static_addr = STATIC_ADDR_BASE + idx[6:0];
        end
    endfunction

    function [6:0] endpoint_dynamic_addr;
        input integer idx;
        begin
            endpoint_dynamic_addr = DYN_ADDR_BASE + idx[6:0];
        end
    endfunction

    function [47:0] endpoint_pid;
        input integer idx;
        begin
            endpoint_pid = PROVISIONAL_ID_BASE + idx;
        end
    endfunction

    function [47:0] direct_pid_value;
        input [47:0] pid;
        begin
            direct_pid_value = {pid[7:0], pid[15:8], pid[23:16], pid[31:24], pid[39:32], pid[47:40]};
        end
    endfunction

    function [15:0] direct_status_value;
        input [15:0] status_word;
        begin
            direct_status_value = {status_word[7:0], status_word[15:8]};
        end
    endfunction

    function [INDEX_W-1:0] first_request_index;
        input [ENDPOINT_COUNT-1:0] reqs;
        integer j;
        begin
            first_request_index = {INDEX_W{1'b0}};
            for (j = 0; j < ENDPOINT_COUNT; j = j + 1) begin
                if (reqs[j]) begin
                    first_request_index = j[INDEX_W-1:0];
                end
            end
        end
    endfunction

    function [15:0] decode_status_word;
        input [15:0] direct_value;
        begin
            decode_status_word = {direct_value[7:0], direct_value[15:8]};
        end
    endfunction

    assign scl_o  = dccc_bus_owner ? dccc_scl_o  : ctrl_scl_o;
    assign scl_oe = dccc_bus_owner ? dccc_scl_oe : ctrl_scl_oe;
    assign sda_o  = dccc_bus_owner ? dccc_sda_o  : ctrl_sda_o;
    assign sda_oe = dccc_bus_owner ? dccc_sda_oe : ctrl_sda_oe;

    assign schedule_tick = (schedule_div_cnt == SCHEDULE_DIV_CLKS - 1);

    i3c_ctrl_direct_ccc #(
        .CLK_FREQ_HZ   (CLK_FREQ_HZ),
        .I3C_SDR_HZ    (I3C_SDR_HZ),
        .PUSH_PULL_DATA(1),
        .MAX_TX_BYTES  (PID_BYTES),
        .MAX_RX_BYTES  (PID_BYTES)
    ) u_direct_ccc (
        .clk         (clk),
        .rst_n       (rst_n),
        .cmd_valid   (dccc_cmd_valid),
        .cmd_ready   (dccc_cmd_ready),
        .ccc_code    (dccc_ccc_code),
        .target_addr (dccc_target_addr),
        .target_read (dccc_target_read),
        .tx_len      (dccc_tx_len),
        .rx_len      (dccc_rx_len),
        .tx_data     (dccc_tx_data),
        .rsp_valid   (dccc_rsp_valid),
        .rsp_nack    (dccc_rsp_nack),
        .rsp_rx_count(dccc_rsp_rx_count),
        .rsp_rdata   (dccc_rsp_rdata),
        .busy        (dccc_busy),
        .scl_o       (dccc_scl_o),
        .scl_oe      (dccc_scl_oe),
        .sda_o       (dccc_sda_o),
        .sda_oe      (dccc_sda_oe),
        .sda_i       (sda_i)
    );

    i3c_ctrl_top #(
        .MAX_ENDPOINTS     (ENDPOINT_COUNT),
        .MAX_SERVICE_BYTES (MAX_SERVICE_BYTES),
        .DYN_ADDR_BASE     (DYN_ADDR_BASE),
        .CLK_FREQ_HZ       (CLK_FREQ_HZ),
        .I3C_SDR_HZ        (I3C_SDR_HZ),
        .PUSH_PULL_DATA    (1)
    ) u_ctrl_top (
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
        .direct_event_set_valid   (direct_event_set_valid),
        .direct_event_clear_valid (1'b0),
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
        .service_period_update_valid(service_period_update_valid),
        .service_period_update_addr(service_period_update_addr),
        .service_period_update_value(service_period_update_value),
        .service_len_update_valid (service_len_update_valid),
        .service_len_update_addr  (service_len_update_addr),
        .service_len_update_value (service_len_update_value),
        .service_selector_update_valid(service_selector_update_valid),
        .service_selector_update_addr(service_selector_update_addr),
        .service_selector_update_value(service_selector_update_value),
        .schedule_enable          (hub_state == ST_RUN),
        .schedule_tick            (schedule_tick),
        .query_addr               (endpoint_dynamic_addr(active_index)),
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
        .query_service_period     (query_service_period),
        .query_service_rx_len     (query_service_rx_len),
        .query_service_selector   (query_service_selector),
        .query_service_count      (query_service_count),
        .query_success_count      (query_success_count),
        .query_error_count        (query_error_count),
        .query_consecutive_failures(query_consecutive_failures),
        .query_last_service_tag   (query_last_service_tag),
        .query_due_now            (query_due_now),
        .endpoint_count           (endpoint_count),
        .policy_table_full        (policy_table_full),
        .policy_update_miss       (policy_update_miss),
        .scheduler_busy           (scheduler_busy),
        .scheduler_missed_slot    (scheduler_missed_slot),
        .service_rsp_valid        (service_rsp_valid),
        .service_rsp_nack         (service_rsp_nack),
        .service_rsp_addr         (service_rsp_addr),
        .service_rsp_class        (service_rsp_class),
        .service_rsp_index        (service_rsp_index),
        .service_rsp_rx_count     (service_rsp_rx_count),
        .service_rsp_rdata        (service_rsp_rdata),
        .service_busy             (ctrl_service_busy),
        .scl_o                    (ctrl_scl_o),
        .scl_oe                   (ctrl_scl_oe),
        .sda_o                    (ctrl_sda_o),
        .sda_oe                   (ctrl_sda_oe),
        .sda_i                    (sda_i)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            hub_state                    <= ST_BOOT_SETDASA_REQ;
            boot_index                   <= {INDEX_W{1'b0}};
            active_index                 <= {INDEX_W{1'b0}};
            active_diag_request          <= 1'b0;
            boot_done                    <= 1'b0;
            boot_error                   <= 1'b0;
            capture_error                <= 1'b0;
            recovery_active              <= 1'b0;
            fault_diag_irq               <= 1'b0;
            verified_bitmap              <= {ENDPOINT_COUNT{1'b0}};
            recovered_bitmap             <= {ENDPOINT_COUNT{1'b0}};
            fault_diag_seen_bitmap       <= {ENDPOINT_COUNT{1'b0}};
            fault_diag_enable_bitmap     <= {ENDPOINT_COUNT{1'b0}};
            sample_valid_bitmap          <= {ENDPOINT_COUNT{1'b0}};
            sample_payloads_flat         <= {ENDPOINT_COUNT*PAYLOAD_BYTES*8{1'b0}};
            sample_capture_count_flat    <= {ENDPOINT_COUNT*16{1'b0}};
            last_service_addr            <= 7'h00;
            last_service_count           <= 8'h00;
            last_recovery_addr           <= 7'h00;
            last_diag_addr               <= 7'h00;
            last_status_word             <= 16'h0000;
            discover_valid               <= 1'b0;
            discover_pid                 <= 48'h0;
            discover_bcr                 <= 8'h00;
            discover_dcr                 <= 8'h00;
            direct_event_set_valid       <= 1'b0;
            direct_event_addr            <= 7'h00;
            direct_event_mask            <= 8'h00;
            enable_update_valid          <= 1'b0;
            enable_update_addr           <= 7'h00;
            enable_update_value          <= 1'b0;
            reset_action_update_valid    <= 1'b0;
            reset_action_update_addr     <= 7'h00;
            reset_action_update_value    <= 8'h00;
            status_update_valid          <= 1'b0;
            status_update_addr           <= 7'h00;
            status_update_value          <= 16'h0000;
            status_update_ok             <= 1'b0;
            service_period_update_valid  <= 1'b0;
            service_period_update_addr   <= 7'h00;
            service_period_update_value  <= 8'h00;
            service_len_update_valid     <= 1'b0;
            service_len_update_addr      <= 7'h00;
            service_len_update_value     <= 8'h00;
            service_selector_update_valid <= 1'b0;
            service_selector_update_addr  <= 7'h00;
            service_selector_update_value <= 8'h00;
            dccc_cmd_valid               <= 1'b0;
            dccc_ccc_code                <= 8'h00;
            dccc_target_addr             <= 7'h00;
            dccc_target_read             <= 1'b0;
            dccc_tx_len                  <= 8'd0;
            dccc_rx_len                  <= 8'd0;
            dccc_tx_data                 <= 48'h0;
            schedule_div_cnt             <= {SCHEDULE_DIV_W{1'b0}};
        end else begin
            discover_valid                <= 1'b0;
            direct_event_set_valid        <= 1'b0;
            enable_update_valid           <= 1'b0;
            reset_action_update_valid     <= 1'b0;
            status_update_valid           <= 1'b0;
            service_period_update_valid   <= 1'b0;
            service_len_update_valid      <= 1'b0;
            service_selector_update_valid <= 1'b0;
            dccc_cmd_valid                <= 1'b0;
            fault_diag_irq                <= 1'b0;

            if (schedule_tick) begin
                schedule_div_cnt <= {SCHEDULE_DIV_W{1'b0}};
            end else begin
                schedule_div_cnt <= schedule_div_cnt + 1'b1;
            end

            if (service_rsp_valid) begin
                last_service_addr  <= service_rsp_addr;
                last_service_count <= service_rsp_rx_count;
                if (!service_rsp_nack && (service_rsp_rx_count == PAYLOAD_BYTES_U8)) begin
                    sample_valid_bitmap[service_rsp_index] <= 1'b1;
                    sample_payloads_flat[service_rsp_index*PAYLOAD_BYTES*8 +: PAYLOAD_BYTES*8] <=
                        service_rsp_rdata[PAYLOAD_BYTES*8-1:0];
                    sample_capture_count_flat[service_rsp_index*16 +: 16] <=
                        sample_capture_count_flat[service_rsp_index*16 +: 16] + 1'b1;
                end
            end

            case (hub_state)
                ST_BOOT_SETDASA_REQ: begin
                    if (dccc_cmd_ready) begin
                        dccc_cmd_valid   <= 1'b1;
                        dccc_ccc_code    <= CCC_SETDASA;
                        dccc_target_addr <= endpoint_static_addr(boot_index);
                        dccc_target_read <= 1'b0;
                        dccc_tx_len      <= 8'd1;
                        dccc_rx_len      <= 8'd0;
                        dccc_tx_data     <= {40'h0, endpoint_dynamic_addr(boot_index), 1'b0};
                        hub_state        <= ST_BOOT_SETDASA_WAIT;
                    end
                end

                ST_BOOT_SETDASA_WAIT: begin
                    if (dccc_rsp_valid) begin
                        if (dccc_rsp_nack) begin
                            boot_error <= 1'b1;
                            hub_state  <= ST_ERROR;
                        end else begin
                            hub_state <= ST_BOOT_GETPID_REQ;
                        end
                    end
                end

                ST_BOOT_GETPID_REQ: begin
                    if (dccc_cmd_ready) begin
                        dccc_cmd_valid   <= 1'b1;
                        dccc_ccc_code    <= CCC_GETPID;
                        dccc_target_addr <= endpoint_dynamic_addr(boot_index);
                        dccc_target_read <= 1'b1;
                        dccc_tx_len      <= 8'd0;
                        dccc_rx_len      <= PID_BYTES;
                        dccc_tx_data     <= 48'h0;
                        hub_state        <= ST_BOOT_GETPID_WAIT;
                    end
                end

                ST_BOOT_GETPID_WAIT: begin
                    if (dccc_rsp_valid) begin
                        if (dccc_rsp_nack ||
                            (dccc_rsp_rx_count != PID_BYTES_U8) ||
                            (dccc_rsp_rdata != direct_pid_value(endpoint_pid(boot_index)))) begin
                            boot_error <= 1'b1;
                            hub_state  <= ST_ERROR;
                        end else begin
                            hub_state <= ST_BOOT_GETBCR_REQ;
                        end
                    end
                end

                ST_BOOT_GETBCR_REQ: begin
                    if (dccc_cmd_ready) begin
                        dccc_cmd_valid   <= 1'b1;
                        dccc_ccc_code    <= CCC_GETBCR;
                        dccc_target_addr <= endpoint_dynamic_addr(boot_index);
                        dccc_target_read <= 1'b1;
                        dccc_tx_len      <= 8'd0;
                        dccc_rx_len      <= 8'd1;
                        dccc_tx_data     <= 48'h0;
                        hub_state        <= ST_BOOT_GETBCR_WAIT;
                    end
                end

                ST_BOOT_GETBCR_WAIT: begin
                    if (dccc_rsp_valid) begin
                        if (dccc_rsp_nack || (dccc_rsp_rx_count != 8'd1) || (dccc_rsp_rdata[7:0] != TARGET_BCR)) begin
                            boot_error <= 1'b1;
                            hub_state  <= ST_ERROR;
                        end else begin
                            hub_state <= ST_BOOT_GETDCR_REQ;
                        end
                    end
                end

                ST_BOOT_GETDCR_REQ: begin
                    if (dccc_cmd_ready) begin
                        dccc_cmd_valid   <= 1'b1;
                        dccc_ccc_code    <= CCC_GETDCR;
                        dccc_target_addr <= endpoint_dynamic_addr(boot_index);
                        dccc_target_read <= 1'b1;
                        dccc_tx_len      <= 8'd0;
                        dccc_rx_len      <= 8'd1;
                        dccc_tx_data     <= 48'h0;
                        hub_state        <= ST_BOOT_GETDCR_WAIT;
                    end
                end

                ST_BOOT_GETDCR_WAIT: begin
                    if (dccc_rsp_valid) begin
                        if (dccc_rsp_nack || (dccc_rsp_rx_count != 8'd1) || (dccc_rsp_rdata[7:0] != TARGET_DCR)) begin
                            boot_error <= 1'b1;
                            hub_state  <= ST_ERROR;
                        end else begin
                            hub_state <= ST_BOOT_GETSTATUS_REQ;
                        end
                    end
                end

                ST_BOOT_GETSTATUS_REQ: begin
                    if (dccc_cmd_ready) begin
                        dccc_cmd_valid   <= 1'b1;
                        dccc_ccc_code    <= CCC_GETSTATUS;
                        dccc_target_addr <= endpoint_dynamic_addr(boot_index);
                        dccc_target_read <= 1'b1;
                        dccc_tx_len      <= 8'd0;
                        dccc_rx_len      <= STATUS_BYTES;
                        dccc_tx_data     <= 48'h0;
                        hub_state        <= ST_BOOT_GETSTATUS_WAIT;
                    end
                end

                ST_BOOT_GETSTATUS_WAIT: begin
                    if (dccc_rsp_valid) begin
                        last_status_word <= decode_status_word(dccc_rsp_rdata[15:0]);
                        if (dccc_rsp_nack || (dccc_rsp_rx_count != STATUS_BYTES_U8) ||
                            !dccc_status_word[0]) begin
                            boot_error <= 1'b1;
                            hub_state  <= ST_ERROR;
                        end else begin
                            status_update_valid <= 1'b1;
                            status_update_addr  <= endpoint_dynamic_addr(boot_index);
                            status_update_value <= dccc_status_word;
                            status_update_ok    <= 1'b1;
                            hub_state           <= ST_BOOT_RSTACT_REQ;
                        end
                    end
                end

                ST_BOOT_RSTACT_REQ: begin
                    if (dccc_cmd_ready) begin
                        dccc_cmd_valid   <= 1'b1;
                        dccc_ccc_code    <= CCC_RSTACT;
                        dccc_target_addr <= endpoint_dynamic_addr(boot_index);
                        dccc_target_read <= 1'b0;
                        dccc_tx_len      <= 8'd1;
                        dccc_rx_len      <= 8'd0;
                        dccc_tx_data     <= {40'h0, RECOVERY_RSTACT_ACTION};
                        hub_state        <= ST_BOOT_RSTACT_WAIT;
                    end
                end

                ST_BOOT_RSTACT_WAIT: begin
                    if (dccc_rsp_valid) begin
                        if (dccc_rsp_nack) begin
                            boot_error <= 1'b1;
                            hub_state  <= ST_ERROR;
                        end else begin
                            reset_action_update_valid <= 1'b1;
                            reset_action_update_addr  <= endpoint_dynamic_addr(boot_index);
                            reset_action_update_value <= RECOVERY_RSTACT_ACTION;
                            hub_state                 <= ST_BOOT_ENEC_REQ;
                        end
                    end
                end

                ST_BOOT_ENEC_REQ: begin
                    if (dccc_cmd_ready) begin
                        dccc_cmd_valid   <= 1'b1;
                        dccc_ccc_code    <= CCC_ENEC;
                        dccc_target_addr <= endpoint_dynamic_addr(boot_index);
                        dccc_target_read <= 1'b0;
                        dccc_tx_len      <= 8'd1;
                        dccc_rx_len      <= 8'd0;
                        dccc_tx_data     <= {40'h0, FAULT_DIAG_EVENT_MASK};
                        hub_state        <= ST_BOOT_ENEC_WAIT;
                    end
                end

                ST_BOOT_ENEC_WAIT: begin
                    if (dccc_rsp_valid) begin
                        if (dccc_rsp_nack) begin
                            boot_error <= 1'b1;
                            hub_state  <= ST_ERROR;
                        end else begin
                            direct_event_set_valid <= 1'b1;
                            direct_event_addr      <= endpoint_dynamic_addr(boot_index);
                            direct_event_mask      <= FAULT_DIAG_EVENT_MASK;
                            fault_diag_enable_bitmap[boot_index] <= 1'b1;
                            hub_state              <= ST_BOOT_DISCOVER;
                        end
                    end
                end

                ST_BOOT_DISCOVER: begin
                    discover_valid               <= 1'b1;
                    discover_pid                 <= endpoint_pid(boot_index);
                    discover_bcr                 <= TARGET_BCR;
                    discover_dcr                 <= TARGET_DCR;
                    verified_bitmap[boot_index]  <= 1'b1;
                    hub_state                    <= ST_BOOT_CFG_PERIOD;
                end

                ST_BOOT_CFG_PERIOD: begin
                    service_period_update_valid <= 1'b1;
                    service_period_update_addr  <= endpoint_dynamic_addr(boot_index);
                    service_period_update_value <= 8'd1;
                    hub_state                   <= ST_BOOT_CFG_LEN;
                end

                ST_BOOT_CFG_LEN: begin
                    service_len_update_valid <= 1'b1;
                    service_len_update_addr  <= endpoint_dynamic_addr(boot_index);
                    service_len_update_value <= PAYLOAD_BYTES_U8;
                    hub_state                <= ST_BOOT_CFG_SEL;
                end

                ST_BOOT_CFG_SEL: begin
                    service_selector_update_valid <= 1'b1;
                    service_selector_update_addr  <= endpoint_dynamic_addr(boot_index);
                    service_selector_update_value <= SAMPLE_SELECTOR;
                    hub_state                     <= ST_BOOT_NEXT;
                end

                ST_BOOT_NEXT: begin
                    if (boot_index == ENDPOINT_COUNT - 1) begin
                        boot_done <= 1'b1;
                        hub_state <= ST_RUN;
                    end else begin
                        boot_index <= boot_index + 1'b1;
                        hub_state  <= ST_BOOT_SETDASA_REQ;
                    end
                end

                ST_RUN: begin
                    recovery_active <= 1'b0;
                    if (service_rsp_valid && service_rsp_nack) begin
                        active_index        <= service_rsp_index;
                        active_diag_request <= 1'b0;
                        recovery_active     <= 1'b1;
                        last_recovery_addr  <= service_rsp_addr;
                        enable_update_valid <= 1'b1;
                        enable_update_addr  <= service_rsp_addr;
                        enable_update_value <= 1'b0;
                        hub_state           <= ST_DIAG_GETSTATUS_REQ;
                    end else if (fault_diag_req_valid) begin
                        active_index        <= fault_diag_req_index;
                        active_diag_request <= 1'b1;
                        recovery_active     <= 1'b1;
                        fault_diag_irq      <= 1'b1;
                        fault_diag_seen_bitmap[fault_diag_req_index] <= 1'b1;
                        last_diag_addr      <= endpoint_dynamic_addr(fault_diag_req_index);
                        hub_state           <= ST_DIAG_GETSTATUS_REQ;
                    end
                end

                ST_DIAG_GETSTATUS_REQ: begin
                    recovery_active <= 1'b1;
                    if (dccc_cmd_ready) begin
                        dccc_cmd_valid   <= 1'b1;
                        dccc_ccc_code    <= CCC_GETSTATUS;
                        dccc_target_addr <= endpoint_dynamic_addr(active_index);
                        dccc_target_read <= 1'b1;
                        dccc_tx_len      <= 8'd0;
                        dccc_rx_len      <= STATUS_BYTES;
                        dccc_tx_data     <= 48'h0;
                        hub_state        <= ST_DIAG_GETSTATUS_WAIT;
                    end
                end

                ST_DIAG_GETSTATUS_WAIT: begin
                    recovery_active <= 1'b1;
                    if (dccc_rsp_valid) begin
                        last_status_word <= decode_status_word(dccc_rsp_rdata[15:0]);
                        if (!dccc_rsp_nack && (dccc_rsp_rx_count == STATUS_BYTES_U8)) begin
                            status_update_valid <= 1'b1;
                            status_update_addr  <= endpoint_dynamic_addr(active_index);
                            status_update_value <= dccc_status_word;
                            status_update_ok    <= dccc_status_word[0];
                        end

                        if (dccc_rsp_nack || (dccc_rsp_rx_count != STATUS_BYTES_U8) ||
                            !dccc_status_word[0]) begin
                            last_recovery_addr <= endpoint_dynamic_addr(active_index);
                            hub_state          <= ST_RECOVER_SETDASA_REQ;
                        end else if (active_diag_request) begin
                            hub_state <= ST_RUN;
                        end else begin
                            hub_state <= ST_RECOVER_REENABLE;
                        end
                    end
                end

                ST_RECOVER_SETDASA_REQ: begin
                    recovery_active <= 1'b1;
                    if (dccc_cmd_ready) begin
                        dccc_cmd_valid   <= 1'b1;
                        dccc_ccc_code    <= CCC_SETDASA;
                        dccc_target_addr <= endpoint_static_addr(active_index);
                        dccc_target_read <= 1'b0;
                        dccc_tx_len      <= 8'd1;
                        dccc_rx_len      <= 8'd0;
                        dccc_tx_data     <= {40'h0, endpoint_dynamic_addr(active_index), 1'b0};
                        hub_state        <= ST_RECOVER_SETDASA_WAIT;
                    end
                end

                ST_RECOVER_SETDASA_WAIT: begin
                    recovery_active <= 1'b1;
                    if (dccc_rsp_valid) begin
                        if (dccc_rsp_nack) begin
                            capture_error <= 1'b1;
                            hub_state     <= ST_ERROR;
                        end else begin
                            hub_state <= ST_RECOVER_GETSTATUS_REQ;
                        end
                    end
                end

                ST_RECOVER_GETSTATUS_REQ: begin
                    recovery_active <= 1'b1;
                    if (dccc_cmd_ready) begin
                        dccc_cmd_valid   <= 1'b1;
                        dccc_ccc_code    <= CCC_GETSTATUS;
                        dccc_target_addr <= endpoint_dynamic_addr(active_index);
                        dccc_target_read <= 1'b1;
                        dccc_tx_len      <= 8'd0;
                        dccc_rx_len      <= STATUS_BYTES;
                        dccc_tx_data     <= 48'h0;
                        hub_state        <= ST_RECOVER_GETSTATUS_WAIT;
                    end
                end

                ST_RECOVER_GETSTATUS_WAIT: begin
                    recovery_active <= 1'b1;
                    if (dccc_rsp_valid) begin
                        last_status_word <= decode_status_word(dccc_rsp_rdata[15:0]);
                        if (dccc_rsp_nack || (dccc_rsp_rx_count != STATUS_BYTES_U8) ||
                            !dccc_status_word[0]) begin
                            capture_error <= 1'b1;
                            hub_state     <= ST_ERROR;
                        end else begin
                            status_update_valid <= 1'b1;
                            status_update_addr  <= endpoint_dynamic_addr(active_index);
                            status_update_value <= dccc_status_word;
                            status_update_ok    <= 1'b1;
                            recovered_bitmap[active_index] <= 1'b1;
                            hub_state           <= ST_RECOVER_REENABLE;
                        end
                    end
                end

                ST_RECOVER_REENABLE: begin
                    recovery_active     <= 1'b1;
                    enable_update_valid <= 1'b1;
                    enable_update_addr  <= endpoint_dynamic_addr(active_index);
                    enable_update_value <= 1'b1;
                    hub_state           <= ST_RUN;
                end

                default: begin
                    recovery_active <= 1'b0;
                    boot_error      <= 1'b1;
                    hub_state       <= ST_ERROR;
                end
            endcase
        end
    end

endmodule
