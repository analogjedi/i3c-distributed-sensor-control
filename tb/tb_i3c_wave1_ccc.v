`timescale 1ns/1ps

module tb_i3c_wave1_ccc;

    localparam [7:0] CCC_SETMWL_BCAST  = 8'h09;
    localparam [7:0] CCC_SETMRL_BCAST  = 8'h0A;
    localparam [7:0] CCC_SETNEWDA      = 8'h88;
    localparam [7:0] CCC_SETMWL_DIRECT = 8'h89;
    localparam [7:0] CCC_SETMRL_DIRECT = 8'h8A;
    localparam [7:0] CCC_GETMWL        = 8'h8B;
    localparam [7:0] CCC_GETMRL        = 8'h8C;
    localparam [7:0] CCC_GETMXDS       = 8'h94;
    localparam [7:0] CCC_GETCAPS       = 8'h95;

    reg clk;
    reg rst_n;

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
    wire       txn_scl_o;
    wire       txn_scl_oe;
    wire       txn_sda_o;
    wire       txn_sda_oe;

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
    wire [31:0] dccc_rsp_rdata;
    wire       dccc_busy;
    wire       dccc_scl_o;
    wire       dccc_scl_oe;
    wire       dccc_sda_o;
    wire       dccc_sda_oe;

    wire scl_line;
    wire sda_line;
    wire sda_i;
    wire target_sda_oe;
    wire [6:0] active_addr;
    wire       dynamic_addr_valid;
    wire [15:0] max_write_len;
    wire [15:0] max_read_len;
    wire [7:0]  ibi_data_len;
    wire [7:0]  last_ccc;

    reg assign_dynamic_addr_valid;
    reg [6:0] assign_dynamic_addr;

    wire bus_dccc_active = dccc_busy || dccc_cmd_valid;
    wire bus_txn_active  = !bus_dccc_active && (txn_busy || txn_req_valid || ccc_txn_req_valid);

    pullup (scl_line);

    assign scl_line = bus_dccc_active ? (dccc_scl_oe ? dccc_scl_o : 1'bz) :
                      bus_txn_active  ? (txn_scl_oe  ? txn_scl_o  : 1'bz) :
                                        1'bz;
    assign sda_line = ~(((bus_dccc_active ? (dccc_sda_oe & ~dccc_sda_o) : 1'b0) |
                         (bus_txn_active  ? (txn_sda_oe  & ~txn_sda_o)  : 1'b0)) |
                        target_sda_oe);
    assign sda_i = sda_line;

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
        .txn_req_ready(txn_req_ready),
        .txn_req_addr (ccc_txn_req_addr),
        .txn_req_read (ccc_txn_req_read),
        .txn_req_tx_len(ccc_txn_req_tx_len),
        .txn_req_rx_len(ccc_txn_req_rx_len),
        .txn_req_wdata(ccc_txn_req_wdata),
        .txn_rsp_valid(txn_rsp_valid),
        .txn_rsp_nack (txn_rsp_nack)
    );

    i3c_ctrl_txn_layer #(
        .CLK_FREQ_HZ(100_000_000),
        .I3C_SDR_HZ(1_000_000),
        .PUSH_PULL_DATA(1),
        .MAX_TX_BYTES(8),
        .MAX_RX_BYTES(4)
    ) txn (
        .clk            (clk),
        .rst_n          (rst_n),
        .txn_req_valid  (ccc_txn_req_valid | txn_req_valid),
        .txn_req_ready  (txn_req_ready),
        .txn_req_addr   (ccc_txn_req_valid ? ccc_txn_req_addr  : txn_req_addr),
        .txn_req_read   (ccc_txn_req_valid ? ccc_txn_req_read  : txn_req_read),
        .txn_req_tx_len (ccc_txn_req_valid ? ccc_txn_req_tx_len: txn_req_tx_len),
        .txn_req_rx_len (ccc_txn_req_valid ? ccc_txn_req_rx_len: txn_req_rx_len),
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

    i3c_ctrl_direct_ccc #(
        .CLK_FREQ_HZ(100_000_000),
        .I3C_SDR_HZ(1_000_000),
        .PUSH_PULL_DATA(1),
        .MAX_TX_BYTES(4),
        .MAX_RX_BYTES(4)
    ) dccc (
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

    i3c_target_top #(
        .STATIC_ADDR          (7'h2A),
        .PROVISIONAL_ID       (48'h0123_4567_89AB),
        .TARGET_BCR           (8'h21),
        .TARGET_DCR           (8'h90),
        .TARGET_MAX_WRITE_LEN (16'h1234),
        .TARGET_MAX_READ_LEN  (16'h5678),
        .TARGET_IBI_DATA_LEN  (8'h9A),
        .TARGET_MXDS          (16'hBCDE),
        .TARGET_CAPS          (32'h1122_3344)
    ) target (
        .clk                     (clk),
        .rst_n                   (rst_n),
        .scl                     (scl_line),
        .sda                     (sda_line),
        .sda_oe                  (target_sda_oe),
        .clear_dynamic_addr      (1'b0),
        .assign_dynamic_addr_valid(assign_dynamic_addr_valid),
        .assign_dynamic_addr     (assign_dynamic_addr),
        .read_data               (32'h0),
        .write_data              (),
        .write_valid             (),
        .register_selector       (),
        .read_valid              (),
        .selected                (),
        .active_addr             (active_addr),
        .dynamic_addr_valid      (dynamic_addr_valid),
        .provisional_id          (),
        .event_enable_mask       (),
        .rstact_action           (),
        .status_word             (),
        .activity_state          (),
        .group_addr_valid        (),
        .group_addr              (),
        .max_write_len           (max_write_len),
        .max_read_len            (max_read_len),
        .ibi_data_len            (ibi_data_len),
        .last_ccc                (last_ccc)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        ccc_valid = 1'b0;
        ccc_code = 8'h00;
        ccc_data_len = 8'd0;
        ccc_data = 56'h0;
        txn_req_valid = 1'b0;
        txn_req_addr = 7'h00;
        txn_req_read = 1'b0;
        txn_req_tx_len = 8'd0;
        txn_req_rx_len = 8'd0;
        txn_req_wdata = 64'h0;
        dccc_cmd_valid = 1'b0;
        dccc_ccc_code = 8'h00;
        dccc_target_addr = 7'h00;
        dccc_target_read = 1'b0;
        dccc_tx_len = 8'd0;
        dccc_rx_len = 8'd0;
        dccc_tx_data = 32'h0;
        assign_dynamic_addr_valid = 1'b0;
        assign_dynamic_addr = 7'h00;

        $dumpfile("tb_i3c_wave1_ccc.vcd");
        $dumpvars(0, tb_i3c_wave1_ccc);

        #200;
        rst_n = 1'b1;

        pulse_assign_dynamic_addr(7'h33);

        do_direct_read(CCC_GETMWL, 7'h33, 8'd2);
        expect_direct_read("GETMWL default", CCC_GETMWL, 16'h1234, 8'd2);

        do_direct_read(CCC_GETMRL, 7'h33, 8'd3);
        if (dccc_rsp_nack || (last_ccc != CCC_GETMRL) || (dccc_rsp_rx_count != 8'd3) ||
            (dccc_rsp_rdata[23:0] != 24'h9A_78_56)) begin
            $display("FAIL: GETMRL default mismatch nack=%0d last=0x%02h rx_count=%0d data=0x%06h",
                     dccc_rsp_nack, last_ccc, dccc_rsp_rx_count, dccc_rsp_rdata[23:0]);
            $finish(1);
        end

        do_broadcast(CCC_SETMWL_BCAST, 8'd2, {40'h0, 8'h20, 8'h00});
        if (ccc_nack || (last_ccc != CCC_SETMWL_BCAST) || (max_write_len != 16'h0020)) begin
            $display("FAIL: broadcast SETMWL mismatch nack=%0d last=0x%02h mwl=0x%04h",
                     ccc_nack, last_ccc, max_write_len);
            $finish(1);
        end

        do_direct_read(CCC_GETMWL, 7'h33, 8'd2);
        expect_direct_read("GETMWL broadcast update", CCC_GETMWL, 16'h0020, 8'd2);

        do_direct_write(CCC_SETMWL_DIRECT, 7'h33, 8'd2, 32'h0000_5634);
        if (dccc_rsp_nack || (last_ccc != CCC_SETMWL_DIRECT) || (max_write_len != 16'h3456)) begin
            $display("FAIL: direct SETMWL mismatch nack=%0d last=0x%02h mwl=0x%04h",
                     dccc_rsp_nack, last_ccc, max_write_len);
            $finish(1);
        end

        do_direct_read(CCC_GETMWL, 7'h33, 8'd2);
        expect_direct_read("GETMWL direct update", CCC_GETMWL, 16'h3456, 8'd2);

        do_broadcast(CCC_SETMRL_BCAST, 8'd3, {32'h0, 8'h13, 8'h12, 8'h11});
        if (ccc_nack || (last_ccc != CCC_SETMRL_BCAST) ||
            (max_read_len != 16'h1112) || (ibi_data_len != 8'h13)) begin
            $display("FAIL: broadcast SETMRL mismatch nack=%0d last=0x%02h mrl=0x%04h ibi=0x%02h",
                     ccc_nack, last_ccc, max_read_len, ibi_data_len);
            $finish(1);
        end

        do_direct_read(CCC_GETMRL, 7'h33, 8'd3);
        if (dccc_rsp_nack || (last_ccc != CCC_GETMRL) || (dccc_rsp_rx_count != 8'd3) ||
            (dccc_rsp_rdata[23:0] != 24'h13_12_11)) begin
            $display("FAIL: GETMRL broadcast update mismatch nack=%0d last=0x%02h rx_count=%0d data=0x%06h",
                     dccc_rsp_nack, last_ccc, dccc_rsp_rx_count, dccc_rsp_rdata[23:0]);
            $finish(1);
        end

        do_direct_write(CCC_SETMRL_DIRECT, 7'h33, 8'd3, 32'h0024_2322);
        if (dccc_rsp_nack || (last_ccc != CCC_SETMRL_DIRECT) ||
            (max_read_len != 16'h2223) || (ibi_data_len != 8'h24)) begin
            $display("FAIL: direct SETMRL mismatch nack=%0d last=0x%02h mrl=0x%04h ibi=0x%02h",
                     dccc_rsp_nack, last_ccc, max_read_len, ibi_data_len);
            $finish(1);
        end

        do_direct_read(CCC_GETMRL, 7'h33, 8'd3);
        if (dccc_rsp_nack || (last_ccc != CCC_GETMRL) || (dccc_rsp_rx_count != 8'd3) ||
            (dccc_rsp_rdata[23:0] != 24'h24_23_22)) begin
            $display("FAIL: GETMRL direct update mismatch nack=%0d last=0x%02h rx_count=%0d data=0x%06h",
                     dccc_rsp_nack, last_ccc, dccc_rsp_rx_count, dccc_rsp_rdata[23:0]);
            $finish(1);
        end

        do_direct_read(CCC_GETMXDS, 7'h33, 8'd2);
        expect_direct_read("GETMXDS", CCC_GETMXDS, 16'hBCDE, 8'd2);

        do_direct_read(CCC_GETCAPS, 7'h33, 8'd4);
        if (dccc_rsp_nack || (last_ccc != CCC_GETCAPS) || (dccc_rsp_rx_count != 8'd4) ||
            (dccc_rsp_rdata != 32'h4433_2211)) begin
            $display("FAIL: GETCAPS mismatch nack=%0d last=0x%02h rx_count=%0d data=0x%08h",
                     dccc_rsp_nack, last_ccc, dccc_rsp_rx_count, dccc_rsp_rdata);
            $finish(1);
        end

        do_direct_write(CCC_SETNEWDA, 7'h33, 8'd1, 32'h0000_006C);
        if (dccc_rsp_nack || (last_ccc != CCC_SETNEWDA) ||
            !dynamic_addr_valid || (active_addr != 7'h36)) begin
            $display("FAIL: SETNEWDA mismatch nack=%0d last=0x%02h dyn_valid=%0d addr=0x%02h",
                     dccc_rsp_nack, last_ccc, dynamic_addr_valid, active_addr);
            $finish(1);
        end

        do_direct_read(CCC_GETMWL, 7'h33, 8'd2);
        if (!dccc_rsp_nack) begin
            $display("FAIL: old dynamic address should NACK after SETNEWDA");
            $finish(1);
        end

        do_direct_read(CCC_GETMWL, 7'h36, 8'd2);
        expect_direct_read("GETMWL after SETNEWDA", CCC_GETMWL, 16'h3456, 8'd2);

        $display("PASS");
        #100;
        $finish;
    end

    initial begin
        #20_000_000;
        $display("FAIL: timeout");
        $finish(1);
    end

    task pulse_assign_dynamic_addr;
        input [6:0] addr;
        begin
            @(posedge clk);
            assign_dynamic_addr      <= addr;
            assign_dynamic_addr_valid<= 1'b1;
            @(posedge clk);
            assign_dynamic_addr_valid<= 1'b0;
        end
    endtask

    task do_broadcast;
        input [7:0] code;
        input [7:0] len;
        input [55:0] data;
        begin
            @(posedge clk);
            while (!ccc_ready || dccc_busy || txn_req_valid) @(posedge clk);
            ccc_code     <= code;
            ccc_data_len <= len;
            ccc_data     <= data;
            ccc_valid    <= 1'b1;
            @(posedge clk);
            ccc_valid    <= 1'b0;
            while (!ccc_done) @(posedge clk);
        end
    endtask

    task do_direct_write;
        input [7:0] code;
        input [6:0] addr;
        input [7:0] len;
        input [31:0] data;
        begin
            @(posedge clk);
            while (!dccc_cmd_ready || txn_busy || ccc_txn_req_valid || txn_req_valid) @(posedge clk);
            dccc_ccc_code    <= code;
            dccc_target_addr <= addr;
            dccc_target_read <= 1'b0;
            dccc_tx_len      <= len;
            dccc_rx_len      <= 8'd0;
            dccc_tx_data     <= data;
            dccc_cmd_valid   <= 1'b1;
            @(posedge clk);
            dccc_cmd_valid   <= 1'b0;
            while (!dccc_rsp_valid) @(posedge clk);
        end
    endtask

    task do_direct_read;
        input [7:0] code;
        input [6:0] addr;
        input [7:0] len;
        begin
            @(posedge clk);
            while (!dccc_cmd_ready || txn_busy || ccc_txn_req_valid || txn_req_valid) @(posedge clk);
            dccc_ccc_code    <= code;
            dccc_target_addr <= addr;
            dccc_target_read <= 1'b1;
            dccc_tx_len      <= 8'd0;
            dccc_rx_len      <= len;
            dccc_tx_data     <= 32'h0;
            dccc_cmd_valid   <= 1'b1;
            @(posedge clk);
            dccc_cmd_valid   <= 1'b0;
            while (!dccc_rsp_valid) @(posedge clk);
        end
    endtask

    task expect_direct_read;
        input [8*20-1:0] label;
        input [7:0] expected_ccc;
        input [15:0] expected_data;
        input [7:0] expected_len;
        begin
            if (dccc_rsp_nack || (last_ccc != expected_ccc) ||
                (dccc_rsp_rx_count != expected_len) ||
                (dccc_rsp_rdata[15:0] != {expected_data[7:0], expected_data[15:8]})) begin
                $display("FAIL: %0s mismatch nack=%0d last=0x%02h rx_count=%0d data=0x%08h",
                         label, dccc_rsp_nack, last_ccc, dccc_rsp_rx_count, dccc_rsp_rdata);
                $finish(1);
            end
        end
    endtask

endmodule
