`timescale 1ns/1ps

module i3c_sensor_controller_demo #(
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
    parameter [7:0]  CCC_SETDASA         = 8'h87
) (
    input  wire                                  clk,
    input  wire                                  rst_n,
    output wire                                  scl_o,
    output wire                                  scl_oe,
    output wire                                  sda_o,
    output wire                                  sda_oe,
    input  wire                                  sda_i,
    output reg                                   boot_done,
    output reg                                   boot_error,
    output reg                                   capture_error,
    output reg  [ENDPOINT_COUNT-1:0]             sample_valid_bitmap,
    output reg  [ENDPOINT_COUNT*PAYLOAD_BYTES*8-1:0] sample_payloads_flat,
    output reg  [ENDPOINT_COUNT*16-1:0]          sample_capture_count_flat,
    output reg  [6:0]                            last_service_addr,
    output reg  [7:0]                            last_service_count
);

    localparam integer INDEX_W = (ENDPOINT_COUNT <= 1) ? 1 : $clog2(ENDPOINT_COUNT);
    localparam integer SCHEDULE_TICK_HZ = ENDPOINT_COUNT * SAMPLE_RATE_HZ;
    localparam [7:0]  PAYLOAD_BYTES_U8  = PAYLOAD_BYTES;

    localparam [3:0] BOOT_SETDASA_REQ = 4'd0;
    localparam [3:0] BOOT_SETDASA_WAIT= 4'd1;
    localparam [3:0] BOOT_DISCOVER    = 4'd2;
    localparam [3:0] BOOT_CFG_PERIOD  = 4'd3;
    localparam [3:0] BOOT_CFG_LEN     = 4'd4;
    localparam [3:0] BOOT_CFG_SEL     = 4'd5;
    localparam [3:0] BOOT_NEXT        = 4'd6;
    localparam [3:0] BOOT_RUN         = 4'd7;
    localparam [3:0] BOOT_ERROR       = 4'd8;

    reg  [3:0] boot_state;
    reg  [INDEX_W-1:0] boot_index;

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

    wire schedule_tick;
    wire service_rsp_valid;
    wire service_rsp_nack;
    wire [6:0] service_rsp_addr;
    wire [1:0] service_rsp_class;
    wire [INDEX_W-1:0] service_rsp_index;
    wire [7:0] service_rsp_rx_count;
    wire [8*MAX_SERVICE_BYTES-1:0] service_rsp_rdata;
    wire ctrl_scl_o;
    wire ctrl_scl_oe;
    wire ctrl_sda_o;
    wire ctrl_sda_oe;

    reg        dccc_cmd_valid;
    wire       dccc_cmd_ready;
    reg [7:0]  dccc_ccc_code;
    reg [6:0]  dccc_target_addr;
    reg        dccc_target_read;
    reg [7:0]  dccc_tx_len;
    reg [7:0]  dccc_rx_len;
    reg [7:0]  dccc_tx_data;
    wire       dccc_rsp_valid;
    wire       dccc_rsp_nack;
    wire [7:0] dccc_rsp_rx_count;
    wire [7:0] dccc_rsp_rdata;
    wire       dccc_busy;
    wire       dccc_scl_o;
    wire       dccc_scl_oe;
    wire       dccc_sda_o;
    wire       dccc_sda_oe;

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

    assign scl_o  = boot_done ? ctrl_scl_o  : dccc_scl_o;
    assign scl_oe = boot_done ? ctrl_scl_oe : dccc_scl_oe;
    assign sda_o  = boot_done ? ctrl_sda_o  : dccc_sda_o;
    assign sda_oe = boot_done ? ctrl_sda_oe : dccc_sda_oe;

    i3c_demo_rate_tick #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .TICK_HZ    (SCHEDULE_TICK_HZ)
    ) u_schedule_tick (
        .clk  (clk),
        .rst_n(rst_n),
        .tick (schedule_tick)
    );

    i3c_ctrl_direct_ccc #(
        .CLK_FREQ_HZ   (CLK_FREQ_HZ),
        .I3C_SDR_HZ    (I3C_SDR_HZ),
        .PUSH_PULL_DATA(1),
        .MAX_TX_BYTES  (1),
        .MAX_RX_BYTES  (1)
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
        .MAX_ENDPOINTS   (ENDPOINT_COUNT),
        .MAX_SERVICE_BYTES(MAX_SERVICE_BYTES),
        .DYN_ADDR_BASE   (DYN_ADDR_BASE),
        .CLK_FREQ_HZ     (CLK_FREQ_HZ),
        .I3C_SDR_HZ      (I3C_SDR_HZ),
        .PUSH_PULL_DATA  (1)
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
        .schedule_enable          (boot_done),
        .schedule_tick            (schedule_tick),
        .query_addr               (7'h00),
        .query_found              (),
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
        .query_service_period     (),
        .query_service_rx_len     (),
        .query_service_selector   (),
        .query_service_count      (),
        .query_success_count      (),
        .query_error_count        (),
        .query_consecutive_failures(),
        .query_last_service_tag   (),
        .query_due_now            (),
        .endpoint_count           (),
        .policy_table_full        (),
        .policy_update_miss       (),
        .scheduler_busy           (),
        .scheduler_missed_slot    (),
        .service_rsp_valid        (service_rsp_valid),
        .service_rsp_nack         (service_rsp_nack),
        .service_rsp_addr         (service_rsp_addr),
        .service_rsp_class        (service_rsp_class),
        .service_rsp_index        (service_rsp_index),
        .service_rsp_rx_count     (service_rsp_rx_count),
        .service_rsp_rdata        (service_rsp_rdata),
        .service_busy             (),
        .scl_o                    (ctrl_scl_o),
        .scl_oe                   (ctrl_scl_oe),
        .sda_o                    (ctrl_sda_o),
        .sda_oe                   (ctrl_sda_oe),
        .sda_i                    (sda_i)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            boot_state                   <= BOOT_SETDASA_REQ;
            boot_index                   <= {INDEX_W{1'b0}};
            boot_done                    <= 1'b0;
            boot_error                   <= 1'b0;
            capture_error                <= 1'b0;
            sample_valid_bitmap          <= {ENDPOINT_COUNT{1'b0}};
            sample_payloads_flat         <= {ENDPOINT_COUNT*PAYLOAD_BYTES*8{1'b0}};
            sample_capture_count_flat    <= {ENDPOINT_COUNT*16{1'b0}};
            last_service_addr            <= 7'h00;
            last_service_count           <= 8'h00;
            discover_valid               <= 1'b0;
            discover_pid                 <= 48'h0;
            discover_bcr                 <= 8'h00;
            discover_dcr                 <= 8'h00;
            service_period_update_valid  <= 1'b0;
            service_period_update_addr   <= 7'h00;
            service_period_update_value  <= 8'h00;
            service_len_update_valid     <= 1'b0;
            service_len_update_addr      <= 7'h00;
            service_len_update_value     <= 8'h00;
            service_selector_update_valid<= 1'b0;
            service_selector_update_addr <= 7'h00;
            service_selector_update_value<= 8'h00;
            dccc_cmd_valid               <= 1'b0;
            dccc_ccc_code                <= CCC_SETDASA;
            dccc_target_addr             <= 7'h00;
            dccc_target_read             <= 1'b0;
            dccc_tx_len                  <= 8'd1;
            dccc_rx_len                  <= 8'd0;
            dccc_tx_data                 <= 8'h00;
        end else begin
            discover_valid                <= 1'b0;
            service_period_update_valid   <= 1'b0;
            service_len_update_valid      <= 1'b0;
            service_selector_update_valid <= 1'b0;
            dccc_cmd_valid                <= 1'b0;

            if (service_rsp_valid) begin
                last_service_addr  <= service_rsp_addr;
                last_service_count <= service_rsp_rx_count;
                if (service_rsp_nack || (service_rsp_rx_count != PAYLOAD_BYTES_U8)) begin
                    capture_error <= 1'b1;
                end else begin
                    sample_valid_bitmap[service_rsp_index] <= 1'b1;
                    sample_payloads_flat[service_rsp_index*PAYLOAD_BYTES*8 +: PAYLOAD_BYTES*8] <= service_rsp_rdata[PAYLOAD_BYTES*8-1:0];
                    sample_capture_count_flat[service_rsp_index*16 +: 16] <= sample_capture_count_flat[service_rsp_index*16 +: 16] + 1'b1;
                end
            end

            case (boot_state)
                BOOT_SETDASA_REQ: begin
                    if (dccc_cmd_ready) begin
                        dccc_cmd_valid   <= 1'b1;
                        dccc_ccc_code    <= CCC_SETDASA;
                        dccc_target_addr <= endpoint_static_addr(boot_index);
                        dccc_target_read <= 1'b0;
                        dccc_tx_len      <= 8'd1;
                        dccc_rx_len      <= 8'd0;
                        dccc_tx_data     <= {endpoint_dynamic_addr(boot_index), 1'b0};
                        boot_state       <= BOOT_SETDASA_WAIT;
                    end
                end

                BOOT_SETDASA_WAIT: begin
                    if (dccc_rsp_valid) begin
                        if (dccc_rsp_nack) begin
                            boot_error <= 1'b1;
                            boot_state <= BOOT_ERROR;
                        end else begin
                            boot_state <= BOOT_DISCOVER;
                        end
                    end
                end

                BOOT_DISCOVER: begin
                    discover_valid <= 1'b1;
                    discover_pid   <= endpoint_pid(boot_index);
                    discover_bcr   <= TARGET_BCR;
                    discover_dcr   <= TARGET_DCR;
                    boot_state     <= BOOT_CFG_PERIOD;
                end

                BOOT_CFG_PERIOD: begin
                    service_period_update_valid <= 1'b1;
                    service_period_update_addr  <= endpoint_dynamic_addr(boot_index);
                    service_period_update_value <= 8'd1;
                    boot_state                  <= BOOT_CFG_LEN;
                end

                BOOT_CFG_LEN: begin
                    service_len_update_valid <= 1'b1;
                    service_len_update_addr  <= endpoint_dynamic_addr(boot_index);
                    service_len_update_value <= PAYLOAD_BYTES_U8;
                    boot_state               <= BOOT_CFG_SEL;
                end

                BOOT_CFG_SEL: begin
                    service_selector_update_valid <= 1'b1;
                    service_selector_update_addr  <= endpoint_dynamic_addr(boot_index);
                    service_selector_update_value <= SAMPLE_SELECTOR;
                    boot_state                    <= BOOT_NEXT;
                end

                BOOT_NEXT: begin
                    if (boot_index == ENDPOINT_COUNT - 1) begin
                        boot_done  <= 1'b1;
                        boot_state <= BOOT_RUN;
                    end else begin
                        boot_index <= boot_index + 1'b1;
                        boot_state <= BOOT_SETDASA_REQ;
                    end
                end

                BOOT_RUN: begin
                end

                default: begin
                    boot_state <= BOOT_ERROR;
                end
            endcase
        end
    end

endmodule
