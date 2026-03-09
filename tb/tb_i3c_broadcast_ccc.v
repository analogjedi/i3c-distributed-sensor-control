`timescale 1ns/1ps

module tb_i3c_broadcast_ccc;

    localparam [7:0] CCC_RSTDAA  = 8'h06;
    localparam [7:0] CCC_SETAASA = 8'h2A;

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
    wire       busy;

    reg        ccc_valid;
    wire       ccc_ready;
    reg [7:0]  ccc_code;
    reg [7:0]  ccc_data_len;
    reg [55:0] ccc_data;
    wire       ccc_done;
    wire       ccc_nack;

    wire ccc_txn_req_valid;
    wire ccc_txn_req_ready;
    wire [6:0] ccc_txn_req_addr;
    wire       ccc_txn_req_read;
    wire [7:0] ccc_txn_req_tx_len;
    wire [7:0] ccc_txn_req_rx_len;
    wire [63:0] ccc_txn_req_wdata;

    wire scl_o;
    wire scl_oe;
    wire sda_o;
    wire sda_oe;
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
    wire [7:0] last_ccc;

    pullup (scl_line);
    pullup (sda_line);

    assign scl_line = scl_oe ? scl_o : 1'bz;
    assign sda_line = sda_oe ? sda_o : 1'bz;
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
        .busy           (busy),
        .scl_o          (scl_o),
        .scl_oe         (scl_oe),
        .sda_o          (sda_o),
        .sda_oe         (sda_oe),
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

    i3c_target_top #(
        .STATIC_ADDR(7'h2A),
        .PROVISIONAL_ID(48'h0BAD_F00D_CAFE)
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
        .last_ccc                (last_ccc)
    );

    always #5 clk = ~clk;

    initial begin
        clk                     = 1'b0;
        rst_n                   = 1'b0;
        txn_req_valid           = 1'b0;
        txn_req_addr            = 7'h00;
        txn_req_read            = 1'b0;
        txn_req_tx_len          = 8'd0;
        txn_req_rx_len          = 8'd0;
        txn_req_wdata           = 64'h0;
        ccc_valid               = 1'b0;
        ccc_code                = 8'h00;
        ccc_data_len            = 8'd0;
        ccc_data                = 56'h0;
        clear_dynamic_addr      = 1'b0;
        assign_dynamic_addr_valid = 1'b0;
        assign_dynamic_addr     = 7'h00;
        read_data               = 8'h5C;

        $dumpfile("tb_i3c_broadcast_ccc.vcd");
        $dumpvars(0, tb_i3c_broadcast_ccc);

        #200;
        rst_n = 1'b1;

        assign_target_addr(7'h33);
        if (!dynamic_addr_valid || (active_addr != 7'h33)) begin
            $display("FAIL: expected preloaded dynamic address");
            $finish(1);
        end

        do_read(7'h33, 8'h5C);

        issue_broadcast_ccc(CCC_RSTDAA);
        if (ccc_nack || (last_ccc != CCC_RSTDAA)) begin
            $display("FAIL: RSTDAA CCC did not complete cleanly");
            $finish(1);
        end
        if (dynamic_addr_valid || (active_addr != 7'h2A)) begin
            $display("FAIL: RSTDAA did not reset target state");
            $finish(1);
        end

        do_read_expect_nack(7'h33);
        do_read(7'h2A, 8'h5C);

        issue_broadcast_ccc(CCC_SETAASA);
        if (ccc_nack || (last_ccc != CCC_SETAASA)) begin
            $display("FAIL: SETAASA CCC did not complete cleanly");
            $finish(1);
        end
        if (!dynamic_addr_valid || (active_addr != 7'h2A)) begin
            $display("FAIL: SETAASA did not assert static dynamic address state");
            $finish(1);
        end

        $display("PASS");
        #100;
        $finish;
    end

    initial begin
        #8_000_000;
        $display("FAIL: timeout");
        $finish(1);
    end

    task assign_target_addr;
        input [6:0] addr;
        begin
            @(posedge clk);
            assign_dynamic_addr      <= addr;
            assign_dynamic_addr_valid<= 1'b1;
            @(posedge clk);
            assign_dynamic_addr_valid<= 1'b0;
            @(posedge clk);
        end
    endtask

    task issue_broadcast_ccc;
        input [7:0] code;
        begin
            @(posedge clk);
            while (!ccc_ready) @(posedge clk);
            ccc_code     <= code;
            ccc_data_len <= 8'd0;
            ccc_data     <= 56'h0;
            ccc_valid    <= 1'b1;
            @(posedge clk);
            ccc_valid    <= 1'b0;
            while (!ccc_done) @(posedge clk);
        end
    endtask

    task do_read;
        input [6:0] addr;
        input [7:0] expected;
        begin
            @(posedge clk);
            while (!txn_req_ready || ccc_txn_req_valid) @(posedge clk);
            txn_req_addr   <= addr;
            txn_req_read   <= 1'b1;
            txn_req_tx_len <= 8'd0;
            txn_req_rx_len <= 8'd1;
            txn_req_wdata  <= 64'h0;
            txn_req_valid  <= 1'b1;
            @(posedge clk);
            txn_req_valid  <= 1'b0;
            while (!txn_rsp_valid) @(posedge clk);
            if (txn_rsp_nack || (txn_rsp_rdata[7:0] != expected)) begin
                $display("FAIL: read mismatch addr=0x%02h nack=%0d data=0x%02h", addr, txn_rsp_nack, txn_rsp_rdata[7:0]);
                $finish(1);
            end
        end
    endtask

    task do_read_expect_nack;
        input [6:0] addr;
        begin
            @(posedge clk);
            while (!txn_req_ready || ccc_txn_req_valid) @(posedge clk);
            txn_req_addr   <= addr;
            txn_req_read   <= 1'b1;
            txn_req_tx_len <= 8'd0;
            txn_req_rx_len <= 8'd1;
            txn_req_wdata  <= 64'h0;
            txn_req_valid  <= 1'b1;
            @(posedge clk);
            txn_req_valid  <= 1'b0;
            while (!txn_rsp_valid) @(posedge clk);
            if (!txn_rsp_nack) begin
                $display("FAIL: expected NACK for addr=0x%02h", addr);
                $finish(1);
            end
        end
    endtask

endmodule
