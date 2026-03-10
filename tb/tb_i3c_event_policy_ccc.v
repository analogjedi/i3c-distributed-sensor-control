`timescale 1ns/1ps

module tb_i3c_event_policy_ccc;

    localparam [7:0] CCC_ENEC_BCAST  = 8'h00;
    localparam [7:0] CCC_DISEC_DIRECT= 8'h81;
    localparam [7:0] CCC_ENEC_DIRECT = 8'h80;

    reg clk;
    reg rst_n;

    reg        txn_req_valid;
    wire       txn_req_ready;
    reg [6:0]  txn_req_addr;
    reg        txn_req_read;
    reg [7:0]  txn_req_tx_len;
    reg [7:0]  txn_req_rx_len;
    reg [63:0] txn_req_wdata;
    wire       txn_rsp_valid;
    wire       txn_rsp_nack;
    wire [7:0] txn_rsp_rx_count;
    wire [31:0] txn_rsp_rdata;
    wire       txn_busy;

    reg        ccc_valid;
    wire       ccc_ready;
    reg [7:0]  ccc_code;
    reg [7:0]  ccc_data_len;
    reg [55:0] ccc_data;
    wire       ccc_done;
    wire       ccc_nack;

    reg        dccc_cmd_valid;
    wire       dccc_cmd_ready;
    reg [7:0]  dccc_ccc_code;
    reg [6:0]  dccc_target_addr;
    reg        dccc_target_read;
    reg [7:0]  dccc_tx_len;
    reg [7:0]  dccc_rx_len;
    reg [31:0] dccc_tx_data;
    wire       dccc_rsp_valid;
    wire       dccc_rsp_nack;
    wire [7:0] dccc_rsp_rx_count;
    wire [7:0] dccc_rsp_rdata;
    wire       dccc_busy;

    wire ccc_txn_req_valid;
    wire ccc_txn_req_ready;
    wire [6:0] ccc_txn_req_addr;
    wire       ccc_txn_req_read;
    wire [7:0] ccc_txn_req_tx_len;
    wire [7:0] ccc_txn_req_rx_len;
    wire [63:0] ccc_txn_req_wdata;

    wire txn_scl_o;
    wire txn_scl_oe;
    wire txn_sda_o;
    wire txn_sda_oe;
    wire dccc_scl_o;
    wire dccc_scl_oe;
    wire dccc_sda_o;
    wire dccc_sda_oe;
    wire sda_i;

    wire scl_line;
    wire sda_line;

    reg        clear_dynamic_addr;
    reg        assign_dynamic_addr_valid;
    reg [6:0]  assign_dynamic_addr;
    reg [7:0]  read_data;
    wire [7:0] write_data;
    wire       write_valid;
    wire       read_valid;
    wire       selected;
    wire [6:0] active_addr;
    wire       dynamic_addr_valid;
    wire [47:0] provisional_id;
    wire [7:0] event_enable_mask;
    wire [7:0] last_ccc;

    reg        endpoint_add_valid;
    reg [6:0]  endpoint_dynamic_addr;
    reg [47:0] endpoint_pid;
    reg [7:0]  endpoint_bcr;
    reg [7:0]  endpoint_dcr;
    reg        broadcast_event_set_valid;
    reg        broadcast_event_clear_valid;
    reg [7:0]  broadcast_event_mask;
    reg        direct_event_set_valid;
    reg        direct_event_clear_valid;
    reg [6:0]  direct_event_addr;
    reg [7:0]  direct_event_mask;
    reg [6:0]  query_addr;
    wire       query_found;
    wire [47:0] query_pid;
    wire [7:0] query_bcr;
    wire [7:0] query_dcr;
    wire [7:0] query_event_mask;
    wire [2:0] endpoint_count;
    wire       table_full;
    wire       policy_update_miss;
    wire [6:0] last_update_addr;
    wire [7:0] last_event_mask;

    pullup (scl_line);
    pullup (sda_line);

    assign scl_line = txn_scl_oe  ? txn_scl_o  : 1'bz;
    assign scl_line = dccc_scl_oe ? dccc_scl_o : 1'bz;
    assign sda_line = txn_sda_oe  ? txn_sda_o  : 1'bz;
    assign sda_line = dccc_sda_oe ? dccc_sda_o : 1'bz;
    assign sda_i    = sda_line;

    i3c_ctrl_txn_layer #(
        .CLK_FREQ_HZ(100_000_000),
        .I3C_SDR_HZ(1_000_000),
        .PUSH_PULL_DATA(1),
        .MAX_TX_BYTES(8),
        .MAX_RX_BYTES(4)
    ) txn (
        .clk            (clk),
        .rst_n          (rst_n),
        .txn_req_valid  (txn_req_valid | ccc_txn_req_valid),
        .txn_req_ready  (txn_req_ready),
        .txn_req_addr   (ccc_txn_req_valid ? ccc_txn_req_addr : txn_req_addr),
        .txn_req_read   (ccc_txn_req_valid ? ccc_txn_req_read : txn_req_read),
        .txn_req_tx_len (ccc_txn_req_valid ? ccc_txn_req_tx_len : txn_req_tx_len),
        .txn_req_rx_len (ccc_txn_req_valid ? ccc_txn_req_rx_len : txn_req_rx_len),
        .txn_req_wdata  (ccc_txn_req_valid ? ccc_txn_req_wdata : txn_req_wdata),
        .txn_rsp_valid  (txn_rsp_valid),
        .txn_rsp_nack   (txn_rsp_nack),
        .txn_rsp_rx_count(txn_rsp_rx_count),
        .txn_rsp_rdata  (txn_rsp_rdata),
        .busy           (txn_busy),
        .scl_o          (txn_scl_o),
        .scl_oe         (txn_scl_oe),
        .sda_o          (txn_sda_o),
        .sda_oe         (txn_sda_oe),
        .sda_i          (sda_i)
    );

    assign ccc_txn_req_ready = txn_req_ready;

    i3c_ctrl_ccc #(
        .MAX_TX_BYTES(8)
    ) ccc (
        .clk          (clk),
        .rst_n        (rst_n),
        .ccc_valid    (ccc_valid),
        .ccc_ready    (ccc_ready),
        .ccc_code     (ccc_code),
        .ccc_data_len (ccc_data_len),
        .ccc_data     (ccc_data),
        .ccc_done     (ccc_done),
        .ccc_nack     (ccc_nack),
        .txn_req_valid(ccc_txn_req_valid),
        .txn_req_ready(ccc_txn_req_ready),
        .txn_req_addr (ccc_txn_req_addr),
        .txn_req_read (ccc_txn_req_read),
        .txn_req_tx_len(ccc_txn_req_tx_len),
        .txn_req_rx_len(ccc_txn_req_rx_len),
        .txn_req_wdata(ccc_txn_req_wdata),
        .txn_rsp_valid(txn_rsp_valid),
        .txn_rsp_nack (txn_rsp_nack)
    );

    i3c_ctrl_direct_ccc #(
        .CLK_FREQ_HZ(100_000_000),
        .I3C_SDR_HZ(1_000_000),
        .PUSH_PULL_DATA(1),
        .MAX_TX_BYTES(4),
        .MAX_RX_BYTES(1)
    ) dccc (
        .clk        (clk),
        .rst_n      (rst_n),
        .cmd_valid  (dccc_cmd_valid),
        .cmd_ready  (dccc_cmd_ready),
        .ccc_code   (dccc_ccc_code),
        .target_addr(dccc_target_addr),
        .target_read(dccc_target_read),
        .tx_len     (dccc_tx_len),
        .rx_len     (dccc_rx_len),
        .tx_data    (dccc_tx_data),
        .rsp_valid  (dccc_rsp_valid),
        .rsp_nack   (dccc_rsp_nack),
        .rsp_rx_count(dccc_rsp_rx_count),
        .rsp_rdata  (dccc_rsp_rdata),
        .busy       (dccc_busy),
        .scl_o      (dccc_scl_o),
        .scl_oe     (dccc_scl_oe),
        .sda_o      (dccc_sda_o),
        .sda_oe     (dccc_sda_oe),
        .sda_i      (sda_i)
    );

    i3c_target_top #(
        .STATIC_ADDR(7'h2A),
        .PROVISIONAL_ID(48'h1122_3344_5566),
        .TARGET_BCR(8'h21),
        .TARGET_DCR(8'hC4)
    ) target (
        .clk                     (clk),
        .rst_n                   (rst_n),
        .scl                     (scl_line),
        .sda                     (sda_line),
        .clear_dynamic_addr      (clear_dynamic_addr),
        .assign_dynamic_addr_valid(assign_dynamic_addr_valid),
        .assign_dynamic_addr     (assign_dynamic_addr),
        .read_data               (read_data),
        .write_data              (write_data),
        .write_valid             (write_valid),
        .read_valid              (read_valid),
        .selected                (selected),
        .active_addr             (active_addr),
        .dynamic_addr_valid      (dynamic_addr_valid),
        .provisional_id          (provisional_id),
        .event_enable_mask       (event_enable_mask),
        .last_ccc                (last_ccc)
    );

    i3c_ctrl_policy #(
        .MAX_ENDPOINTS(4)
    ) policy (
        .default_endpoint_enable (1'b1),
        .clk                     (clk),
        .rst_n                   (rst_n),
        .clear_table             (1'b0),
        .endpoint_add_valid      (endpoint_add_valid),
        .endpoint_dynamic_addr   (endpoint_dynamic_addr),
        .endpoint_pid            (endpoint_pid),
        .endpoint_bcr            (endpoint_bcr),
        .endpoint_dcr            (endpoint_dcr),
        .broadcast_event_set_valid(broadcast_event_set_valid),
        .broadcast_event_clear_valid(broadcast_event_clear_valid),
        .broadcast_event_mask    (broadcast_event_mask),
        .direct_event_set_valid  (direct_event_set_valid),
        .direct_event_clear_valid(direct_event_clear_valid),
        .direct_event_addr       (direct_event_addr),
        .direct_event_mask       (direct_event_mask),
        .enable_update_valid     (1'b0),
        .enable_update_addr      (7'h00),
        .enable_update_value     (1'b0),
        .reset_action_update_valid(1'b0),
        .reset_action_update_addr(7'h00),
        .reset_action_update_value(8'h00),
        .status_update_valid     (1'b0),
        .status_update_addr      (7'h00),
        .status_update_value     (16'h0000),
        .status_update_ok        (1'b0),
        .query_addr              (query_addr),
        .query_found             (query_found),
        .query_pid               (query_pid),
        .query_bcr               (query_bcr),
        .query_dcr               (query_dcr),
        .query_class             (),
        .query_enabled           (),
        .query_health_fault      (),
        .query_last_seen_ok      (),
        .query_event_mask        (query_event_mask),
        .query_reset_action      (),
        .query_status            (),
        .scan_index              (2'd0),
        .scan_valid              (),
        .scan_addr               (),
        .scan_class              (),
        .scan_enabled            (),
        .scan_health_fault       (),
        .endpoint_count          (endpoint_count),
        .table_full              (table_full),
        .policy_update_miss      (policy_update_miss),
        .last_update_addr        (last_update_addr),
        .last_event_mask         (last_event_mask)
    );

    always #5 clk = ~clk;

    initial begin
        clk                       = 1'b0;
        rst_n                     = 1'b0;
        txn_req_valid             = 1'b0;
        txn_req_addr              = 7'h00;
        txn_req_read              = 1'b0;
        txn_req_tx_len            = 8'd0;
        txn_req_rx_len            = 8'd0;
        txn_req_wdata             = 64'h0;
        ccc_valid                 = 1'b0;
        ccc_code                  = 8'h00;
        ccc_data_len              = 8'd0;
        ccc_data                  = 56'h0;
        dccc_cmd_valid            = 1'b0;
        dccc_ccc_code             = 8'h00;
        dccc_target_addr          = 7'h00;
        dccc_target_read          = 1'b0;
        dccc_tx_len               = 8'd0;
        dccc_rx_len               = 8'd0;
        dccc_tx_data              = 32'h0;
        clear_dynamic_addr        = 1'b0;
        assign_dynamic_addr_valid = 1'b0;
        assign_dynamic_addr       = 7'h00;
        read_data                 = 8'h5C;
        endpoint_add_valid        = 1'b0;
        endpoint_dynamic_addr     = 7'h00;
        endpoint_pid              = 48'h0;
        endpoint_bcr              = 8'h00;
        endpoint_dcr              = 8'h00;
        broadcast_event_set_valid = 1'b0;
        broadcast_event_clear_valid = 1'b0;
        broadcast_event_mask      = 8'h00;
        direct_event_set_valid    = 1'b0;
        direct_event_clear_valid  = 1'b0;
        direct_event_addr         = 7'h00;
        direct_event_mask         = 8'h00;
        query_addr                = 7'h33;

        $dumpfile("tb_i3c_event_policy_ccc.vcd");
        $dumpvars(0, tb_i3c_event_policy_ccc);

        #200;
        rst_n = 1'b1;

        assign_target_addr(7'h33);
        if (!dynamic_addr_valid || (active_addr != 7'h33)) begin
            $display("FAIL: expected preloaded dynamic address");
            $finish(1);
        end

        seed_policy_entry(7'h33, 48'h1122_3344_5566, 8'h21, 8'hC4);
        if (!query_found || (endpoint_count != 3'd1) || (query_event_mask != 8'h00)) begin
            $display("FAIL: expected seeded controller policy entry");
            $finish(1);
        end

        issue_broadcast_ccc(CCC_ENEC_BCAST, 8'h03);
        apply_broadcast_policy_set(8'h03);
        if (ccc_nack || (last_ccc != CCC_ENEC_BCAST) || (event_enable_mask != 8'h03)) begin
            $display("FAIL: broadcast ENEC mismatch nack=%0d last_ccc=0x%02h mask=0x%02h",
                     ccc_nack, last_ccc, event_enable_mask);
            $finish(1);
        end
        if (!query_found || (query_pid != 48'h1122_3344_5566) ||
            (query_bcr != 8'h21) || (query_dcr != 8'hC4) ||
            (query_event_mask != 8'h03) || (last_update_addr != 7'h7E) ||
            (last_event_mask != 8'h03)) begin
            $display("FAIL: controller policy broadcast update mismatch");
            $finish(1);
        end

        issue_direct_ccc_write(CCC_DISEC_DIRECT, 7'h33, 8'h01);
        apply_direct_policy_clear(7'h33, 8'h01);
        if (dccc_rsp_nack || (last_ccc != CCC_DISEC_DIRECT) || (event_enable_mask != 8'h02)) begin
            $display("FAIL: direct DISEC mismatch nack=%0d last_ccc=0x%02h mask=0x%02h",
                     dccc_rsp_nack, last_ccc, event_enable_mask);
            $finish(1);
        end
        if (policy_update_miss || (query_event_mask != 8'h02) ||
            (last_update_addr != 7'h33) || (last_event_mask != 8'h02)) begin
            $display("FAIL: controller policy direct clear mismatch");
            $finish(1);
        end

        issue_direct_ccc_write(CCC_ENEC_DIRECT, 7'h33, 8'h04);
        apply_direct_policy_set(7'h33, 8'h04);
        if (dccc_rsp_nack || (last_ccc != CCC_ENEC_DIRECT) || (event_enable_mask != 8'h06)) begin
            $display("FAIL: direct ENEC mismatch nack=%0d last_ccc=0x%02h mask=0x%02h",
                     dccc_rsp_nack, last_ccc, event_enable_mask);
            $finish(1);
        end
        if (policy_update_miss || (query_event_mask != 8'h06) ||
            (last_update_addr != 7'h33) || (last_event_mask != 8'h06)) begin
            $display("FAIL: controller policy direct set mismatch");
            $finish(1);
        end

        $display("PASS");
        #100;
        $finish;
    end

    initial begin
        #16_000_000;
        $display("FAIL: timeout");
        $finish(1);
    end

    task assign_target_addr;
        input [6:0] addr;
        begin
            @(posedge clk);
            assign_dynamic_addr       <= addr;
            assign_dynamic_addr_valid <= 1'b1;
            @(posedge clk);
            assign_dynamic_addr_valid <= 1'b0;
            @(posedge clk);
        end
    endtask

    task seed_policy_entry;
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

    task apply_broadcast_policy_set;
        input [7:0] mask;
        begin
            @(posedge clk);
            broadcast_event_mask      <= mask;
            broadcast_event_set_valid <= 1'b1;
            @(posedge clk);
            broadcast_event_set_valid <= 1'b0;
            @(posedge clk);
        end
    endtask

    task apply_direct_policy_clear;
        input [6:0] addr;
        input [7:0] mask;
        begin
            @(posedge clk);
            direct_event_addr        <= addr;
            direct_event_mask        <= mask;
            direct_event_clear_valid <= 1'b1;
            @(posedge clk);
            direct_event_clear_valid <= 1'b0;
            @(posedge clk);
        end
    endtask

    task apply_direct_policy_set;
        input [6:0] addr;
        input [7:0] mask;
        begin
            @(posedge clk);
            direct_event_addr      <= addr;
            direct_event_mask      <= mask;
            direct_event_set_valid <= 1'b1;
            @(posedge clk);
            direct_event_set_valid <= 1'b0;
            @(posedge clk);
        end
    endtask

    task issue_broadcast_ccc;
        input [7:0] code;
        input [7:0] data0;
        begin
            @(posedge clk);
            while (!ccc_ready || dccc_busy) @(posedge clk);
            ccc_code     <= code;
            ccc_data_len <= 8'd1;
            ccc_data     <= {48'h0, data0};
            ccc_valid    <= 1'b1;
            @(posedge clk);
            ccc_valid    <= 1'b0;
            while (!ccc_done) @(posedge clk);
        end
    endtask

    task issue_direct_ccc_write;
        input [7:0] code;
        input [6:0] addr;
        input [7:0] data0;
        begin
            @(posedge clk);
            while (!dccc_cmd_ready || txn_busy || ccc_txn_req_valid) @(posedge clk);
            dccc_ccc_code   <= code;
            dccc_target_addr<= addr;
            dccc_target_read<= 1'b0;
            dccc_tx_len     <= 8'd1;
            dccc_rx_len     <= 8'd0;
            dccc_tx_data    <= {24'h0, data0};
            dccc_cmd_valid  <= 1'b1;
            @(posedge clk);
            dccc_cmd_valid  <= 1'b0;
            while (!dccc_rsp_valid) @(posedge clk);
        end
    endtask

endmodule
