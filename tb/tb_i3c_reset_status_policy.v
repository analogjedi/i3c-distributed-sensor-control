`timescale 1ns/1ps

module tb_i3c_reset_status_policy;

    localparam [7:0] CCC_RSTDAA        = 8'h06;
    localparam [7:0] CCC_SETAASA       = 8'h2A;
    localparam [7:0] CCC_GETSTATUS     = 8'h90;
    localparam [7:0] CCC_RSTACT_DIRECT = 8'h9A;

    reg clk;
    reg rst_n;

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
    wire [15:0] dccc_rsp_rdata;
    wire       dccc_busy;

    wire dccc_scl_o;
    wire dccc_scl_oe;
    wire dccc_sda_o;
    wire dccc_sda_oe;

    reg        ccc_valid;
    wire       ccc_ready;
    reg [7:0]  ccc_code;
    reg [7:0]  ccc_data_len;
    reg [55:0] ccc_data;
    wire       ccc_done;
    wire       ccc_nack;
    wire       ccc_txn_req_valid;
    wire       ccc_txn_req_ready;
    wire [6:0] ccc_txn_req_addr;
    wire       ccc_txn_req_read;
    wire [7:0] ccc_txn_req_tx_len;
    wire [7:0] ccc_txn_req_rx_len;
    wire [63:0] ccc_txn_req_wdata;
    wire       txn_rsp_valid;
    wire       txn_rsp_nack;
    wire [7:0] txn_rsp_rx_count;
    wire [31:0] txn_rsp_rdata;
    wire       txn_busy;
    wire       txn_scl_o;
    wire       txn_scl_oe;
    wire       txn_sda_o;
    wire       txn_sda_oe;
    wire sda_i;

    wire scl_line;
    wire sda_line;

    wire target_sda_oe;

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
    wire [7:0]  event_enable_mask;
    wire [7:0]  rstact_action;
    wire [15:0] status_word;
    wire [7:0]  last_ccc;

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
    reg [6:0]  query_addr;
    wire       query_found;
    wire [47:0] query_pid;
    wire [7:0] query_bcr;
    wire [7:0] query_dcr;
    wire [7:0] query_event_mask;
    wire [7:0] query_reset_action;
    wire [15:0] query_status;
    wire [2:0] endpoint_count;
    wire       table_full;
    wire       policy_update_miss;
    wire [6:0] last_update_addr;
    wire [7:0] last_event_mask;

    pullup (scl_line);

    assign scl_line = dccc_busy ? (dccc_scl_oe ? dccc_scl_o : 1'bz) :
                                  (txn_scl_oe ? txn_scl_o : 1'bz);
    assign sda_line = ~((dccc_busy ? (dccc_sda_oe & ~dccc_sda_o) : (txn_sda_oe & ~txn_sda_o)) | target_sda_oe);
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
        .txn_req_valid  (ccc_txn_req_valid),
        .txn_req_ready  (ccc_txn_req_ready),
        .txn_req_addr   (ccc_txn_req_addr),
        .txn_req_read   (ccc_txn_req_read),
        .txn_req_tx_len (ccc_txn_req_tx_len),
        .txn_req_rx_len (ccc_txn_req_rx_len),
        .txn_req_wdata  (ccc_txn_req_wdata),
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
        .MAX_RX_BYTES(2)
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
        .sda_oe                  (target_sda_oe),
        .clear_dynamic_addr      (1'b0),
        .assign_dynamic_addr_valid(assign_dynamic_addr_valid),
        .assign_dynamic_addr     (assign_dynamic_addr),
        .read_data               ({24'h000000, read_data}),
        .write_data              (write_data),
        .write_valid             (write_valid),
        .read_valid              (read_valid),
        .selected                (selected),
        .active_addr             (active_addr),
        .dynamic_addr_valid      (dynamic_addr_valid),
        .provisional_id          (provisional_id),
        .event_enable_mask       (event_enable_mask),
        .rstact_action           (rstact_action),
        .status_word             (status_word),
        .last_ccc                (last_ccc)
    );

    i3c_ctrl_policy #(
        .MAX_ENDPOINTS(4)
    ) policy (
        .default_endpoint_enable (1'b1),
        .default_service_period  (8'd1),
        .clk                     (clk),
        .rst_n                   (rst_n),
        .clear_table             (1'b0),
        .schedule_tick           (1'b0),
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
        .status_update_ok        (1'b0),
        .service_period_update_valid(1'b0),
        .service_period_update_addr(7'h00),
        .service_period_update_value(8'h00),
        .service_len_update_valid (1'b0),
        .service_len_update_addr  (7'h00),
        .service_len_update_value (8'h00),
        .service_selector_update_valid(1'b0),
        .service_selector_update_addr(7'h00),
        .service_selector_update_value(8'h00),
        .service_result_valid    (1'b0),
        .service_result_addr     (7'h00),
        .service_result_nack     (1'b0),
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
        .query_reset_action      (query_reset_action),
        .query_status            (query_status),
        .query_service_period    (),
        .query_service_rx_len    (),
        .query_service_selector  (),
        .query_service_count     (),
        .query_success_count     (),
        .query_error_count       (),
        .query_consecutive_failures(),
        .query_last_service_tag  (),
        .query_due_now           (),
        .scan_index              (2'd0),
        .scan_valid              (),
        .scan_addr               (),
        .scan_class              (),
        .scan_enabled            (),
        .scan_health_fault       (),
        .scan_due                (),
        .scan_service_rx_len     (),
        .scan_service_selector   (),
        .endpoint_count          (endpoint_count),
        .table_full              (table_full),
        .policy_update_miss      (policy_update_miss),
        .last_update_addr        (last_update_addr),
        .last_event_mask         (last_event_mask)
    );

    always #5 clk = ~clk;

    initial begin
        clk                     = 1'b0;
        rst_n                   = 1'b0;
        dccc_cmd_valid          = 1'b0;
        dccc_ccc_code           = 8'h00;
        dccc_target_addr        = 7'h00;
        dccc_target_read        = 1'b0;
        dccc_tx_len             = 8'd0;
        dccc_rx_len             = 8'd0;
        dccc_tx_data            = 32'h0;
        ccc_valid               = 1'b0;
        ccc_code                = 8'h00;
        ccc_data_len            = 8'd0;
        ccc_data                = 56'h0;
        assign_dynamic_addr_valid = 1'b0;
        assign_dynamic_addr     = 7'h00;
        read_data               = 8'h5C;
        endpoint_add_valid      = 1'b0;
        endpoint_dynamic_addr   = 7'h00;
        endpoint_pid            = 48'h0;
        endpoint_bcr            = 8'h00;
        endpoint_dcr            = 8'h00;
        reset_action_update_valid = 1'b0;
        reset_action_update_addr = 7'h00;
        reset_action_update_value = 8'h00;
        status_update_valid     = 1'b0;
        status_update_addr      = 7'h00;
        status_update_value     = 16'h0000;
        query_addr              = 7'h33;

        $dumpfile("tb_i3c_reset_status_policy.vcd");
        $dumpvars(0, tb_i3c_reset_status_policy);

        #200;
        rst_n = 1'b1;

        preload_dynamic_addr(7'h33);
        seed_policy_entry(7'h33, 48'h1122_3344_5566, 8'h21, 8'hC4);

        issue_direct_write(CCC_RSTACT_DIRECT, 7'h33, 8'h05);
        if (dccc_rsp_nack || (last_ccc != CCC_RSTACT_DIRECT) || (rstact_action != 8'h05)) begin
            $display("FAIL: RSTACT mismatch nack=%0d last_ccc=0x%02h rstact=0x%02h",
                     dccc_rsp_nack, last_ccc, rstact_action);
            $finish(1);
        end
        if (status_word != 16'h00A1) begin
            $display("FAIL: unexpected status after RSTACT status=0x%04h", status_word);
            $finish(1);
        end

        mirror_reset_action(7'h33, 8'h05);
        if (policy_update_miss || !query_found || (query_reset_action != 8'h05) ||
            (last_update_addr != 7'h33)) begin
            $display("FAIL: controller reset-action policy mismatch");
            $finish(1);
        end

        issue_direct_read_status(7'h33);
        if (dccc_rsp_nack || (last_ccc != CCC_GETSTATUS) ||
            (dccc_rsp_rx_count != 8'd2) || (dccc_rsp_rdata != 16'hA100)) begin
            $display("FAIL: GETSTATUS mismatch nack=%0d last_ccc=0x%02h rx_count=%0d data=0x%04h",
                     dccc_rsp_nack, last_ccc, dccc_rsp_rx_count, dccc_rsp_rdata);
            $finish(1);
        end

        mirror_status(7'h33, {dccc_rsp_rdata[7:0], dccc_rsp_rdata[15:8]});
        if (policy_update_miss || (query_status != 16'h00A1) ||
            (query_pid != 48'h1122_3344_5566) || (query_bcr != 8'h21) ||
            (query_dcr != 8'hC4) || (query_event_mask != 8'h00)) begin
            $display("FAIL: controller status policy mismatch");
            $finish(1);
        end

        issue_broadcast_ccc(CCC_RSTDAA);
        repeat (4) @(posedge clk);
        if (ccc_nack || (last_ccc != CCC_RSTDAA) ||
            dynamic_addr_valid || (active_addr != 7'h2A) ||
            (status_word != 16'h00A0)) begin
            $display("FAIL: RSTDAA recovery mismatch nack=%0d last_ccc=0x%02h dyn=%0d active=0x%02h status=0x%04h",
                     ccc_nack, last_ccc, dynamic_addr_valid, active_addr, status_word);
            $finish(1);
        end

        mirror_status(7'h33, status_word);
        if (policy_update_miss || (query_status != 16'h00A0) ||
            (query_reset_action != 8'h05)) begin
            $display("FAIL: controller recovery status mirror mismatch after RSTDAA");
            $finish(1);
        end

        issue_broadcast_ccc(CCC_SETAASA);
        repeat (4) @(posedge clk);
        if (ccc_nack || (last_ccc != CCC_SETAASA) ||
            !dynamic_addr_valid || (active_addr != 7'h2A) ||
            (status_word != 16'h00A1)) begin
            $display("FAIL: SETAASA recovery mismatch nack=%0d last_ccc=0x%02h dyn=%0d active=0x%02h status=0x%04h",
                     ccc_nack, last_ccc, dynamic_addr_valid, active_addr, status_word);
            $finish(1);
        end

        issue_direct_read_status(7'h2A);
        if (dccc_rsp_nack || (last_ccc != CCC_GETSTATUS) ||
            (dccc_rsp_rx_count != 8'd2) || (dccc_rsp_rdata != 16'hA100)) begin
            $display("FAIL: GETSTATUS after SETAASA mismatch nack=%0d last_ccc=0x%02h rx_count=%0d data=0x%04h",
                     dccc_rsp_nack, last_ccc, dccc_rsp_rx_count, dccc_rsp_rdata);
            $finish(1);
        end

        mirror_status(7'h33, {dccc_rsp_rdata[7:0], dccc_rsp_rdata[15:8]});
        if (policy_update_miss || (query_status != 16'h00A1) ||
            (query_reset_action != 8'h05)) begin
            $display("FAIL: controller recovery status mirror mismatch after SETAASA");
            $finish(1);
        end

        $display("PASS");
        #100;
        $finish;
    end

    initial begin
        #12_000_000;
        $display("FAIL: timeout");
        $finish(1);
    end

    task preload_dynamic_addr;
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

    task mirror_reset_action;
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

    task mirror_status;
        input [6:0]  addr;
        input [15:0] value;
        begin
            @(posedge clk);
            status_update_addr  <= addr;
            status_update_value <= value;
            status_update_valid <= 1'b1;
            @(posedge clk);
            status_update_valid <= 1'b0;
            @(posedge clk);
        end
    endtask

    task issue_direct_write;
        input [7:0] code;
        input [6:0] addr;
        input [7:0] data0;
        begin
            @(posedge clk);
            while (!dccc_cmd_ready) @(posedge clk);
            dccc_ccc_code    <= code;
            dccc_target_addr <= addr;
            dccc_target_read <= 1'b0;
            dccc_tx_len      <= 8'd1;
            dccc_rx_len      <= 8'd0;
            dccc_tx_data     <= {24'h0, data0};
            dccc_cmd_valid   <= 1'b1;
            @(posedge clk);
            dccc_cmd_valid   <= 1'b0;
            while (!dccc_rsp_valid) @(posedge clk);
        end
    endtask

    task issue_direct_read_status;
        input [6:0] addr;
        begin
            @(posedge clk);
            while (!dccc_cmd_ready) @(posedge clk);
            dccc_ccc_code    <= CCC_GETSTATUS;
            dccc_target_addr <= addr;
            dccc_target_read <= 1'b1;
            dccc_tx_len      <= 8'd0;
            dccc_rx_len      <= 8'd2;
            dccc_tx_data     <= 32'h0;
            dccc_cmd_valid   <= 1'b1;
            @(posedge clk);
            dccc_cmd_valid   <= 1'b0;
            while (!dccc_rsp_valid) @(posedge clk);
        end
    endtask

    task issue_direct_read_status_expect_nack;
        input [6:0] addr;
        begin
            issue_direct_read_status(addr);
            if (!dccc_rsp_nack) begin
                $display("FAIL: expected GETSTATUS NACK for addr=0x%02h", addr);
                $finish(1);
            end
        end
    endtask

    task issue_broadcast_ccc;
        input [7:0] code;
        begin
            @(posedge clk);
            while (!ccc_ready || dccc_busy) @(posedge clk);
            ccc_code     <= code;
            ccc_data_len <= 8'd0;
            ccc_data     <= 56'h0;
            ccc_valid    <= 1'b1;
            @(posedge clk);
            ccc_valid    <= 1'b0;
            while (!ccc_done) @(posedge clk);
        end
    endtask

endmodule
