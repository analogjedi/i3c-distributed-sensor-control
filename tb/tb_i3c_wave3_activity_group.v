`timescale 1ns/1ps

module tb_i3c_wave3_activity_group;

    localparam [7:0] CCC_ENTAS1_BCAST  = 8'h03;
    localparam [7:0] CCC_RSTGRPA_BCAST = 8'h2C;
    localparam [7:0] CCC_ENTAS2_DIRECT = 8'h84;
    localparam [7:0] CCC_SETGRPA_DIRECT= 8'h9B;
    localparam [7:0] CCC_RSTGRPA_DIRECT= 8'h9C;

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

    reg        assign_dynamic_addr_valid_0;
    reg [6:0]  assign_dynamic_addr_0;
    reg        assign_dynamic_addr_valid_1;
    reg [6:0]  assign_dynamic_addr_1;

    reg [31:0] read_data_0;
    reg [31:0] read_data_1;

    wire scl_line;
    wire sda_line;
    wire sda_i;
    wire target0_sda_oe;
    wire target1_sda_oe;
    wire [7:0] write_data_0;
    wire [7:0] write_data_1;
    wire       write_valid_0;
    wire       write_valid_1;
    wire [7:0] register_selector_0;
    wire [7:0] register_selector_1;
    wire [1:0] activity_state_0;
    wire [1:0] activity_state_1;
    wire       group_addr_valid_0;
    wire       group_addr_valid_1;
    wire [6:0] group_addr_0;
    wire [6:0] group_addr_1;
    wire [7:0] last_ccc_0;
    wire [7:0] last_ccc_1;

    wire bus_dccc_active = dccc_busy || dccc_cmd_valid;
    wire bus_txn_active  = !bus_dccc_active && (txn_busy || txn_req_valid || ccc_txn_req_valid);

    pullup (scl_line);

    assign scl_line = bus_dccc_active ? (dccc_scl_oe ? dccc_scl_o : 1'bz) :
                      bus_txn_active  ? (txn_scl_oe  ? txn_scl_o  : 1'bz) :
                                        1'bz;
    assign sda_line = ~(((bus_dccc_active ? (dccc_sda_oe & ~dccc_sda_o) : 1'b0) |
                         (bus_txn_active  ? (txn_sda_oe  & ~txn_sda_o)  : 1'b0)) |
                        target0_sda_oe | target1_sda_oe);
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
        .STATIC_ADDR   (7'h2A),
        .PROVISIONAL_ID(48'h1000_0000_0001)
    ) target0 (
        .clk                     (clk),
        .rst_n                   (rst_n),
        .scl                     (scl_line),
        .sda                     (sda_line),
        .sda_oe                  (target0_sda_oe),
        .clear_dynamic_addr      (1'b0),
        .assign_dynamic_addr_valid(assign_dynamic_addr_valid_0),
        .assign_dynamic_addr     (assign_dynamic_addr_0),
        .read_data               (read_data_0),
        .write_data              (write_data_0),
        .write_valid             (write_valid_0),
        .register_selector       (register_selector_0),
        .read_valid              (),
        .selected                (),
        .active_addr             (),
        .dynamic_addr_valid      (),
        .provisional_id          (),
        .event_enable_mask       (),
        .rstact_action           (),
        .status_word             (),
        .activity_state          (activity_state_0),
        .group_addr_valid        (group_addr_valid_0),
        .group_addr              (group_addr_0),
        .max_write_len           (),
        .max_read_len            (),
        .ibi_data_len            (),
        .last_ccc                (last_ccc_0)
    );

    i3c_target_top #(
        .STATIC_ADDR   (7'h2B),
        .PROVISIONAL_ID(48'h1000_0000_0002)
    ) target1 (
        .clk                     (clk),
        .rst_n                   (rst_n),
        .scl                     (scl_line),
        .sda                     (sda_line),
        .sda_oe                  (target1_sda_oe),
        .clear_dynamic_addr      (1'b0),
        .assign_dynamic_addr_valid(assign_dynamic_addr_valid_1),
        .assign_dynamic_addr     (assign_dynamic_addr_1),
        .read_data               (read_data_1),
        .write_data              (write_data_1),
        .write_valid             (write_valid_1),
        .register_selector       (register_selector_1),
        .read_valid              (),
        .selected                (),
        .active_addr             (),
        .dynamic_addr_valid      (),
        .provisional_id          (),
        .event_enable_mask       (),
        .rstact_action           (),
        .status_word             (),
        .activity_state          (activity_state_1),
        .group_addr_valid        (group_addr_valid_1),
        .group_addr              (group_addr_1),
        .max_write_len           (),
        .max_read_len            (),
        .ibi_data_len            (),
        .last_ccc                (last_ccc_1)
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
        assign_dynamic_addr_valid_0 = 1'b0;
        assign_dynamic_addr_0 = 7'h00;
        assign_dynamic_addr_valid_1 = 1'b0;
        assign_dynamic_addr_1 = 7'h00;
        read_data_0 = 32'h0;
        read_data_1 = 32'h0;

        $dumpfile("tb_i3c_wave3_activity_group.vcd");
        $dumpvars(0, tb_i3c_wave3_activity_group);

        #200;
        rst_n = 1'b1;

        pulse_assign_dynamic_addr_0(7'h30);
        pulse_assign_dynamic_addr_1(7'h31);

        do_direct_no_data(CCC_ENTAS2_DIRECT, 7'h30);
        if (dccc_rsp_nack || (last_ccc_0 != CCC_ENTAS2_DIRECT) || (activity_state_0 != 2'd2) || (activity_state_1 != 2'd0)) begin
            $display("FAIL: direct ENTAS2 mismatch nack=%0d last0=0x%02h act0=%0d act1=%0d",
                     dccc_rsp_nack, last_ccc_0, activity_state_0, activity_state_1);
            $finish(1);
        end

        do_broadcast(CCC_ENTAS1_BCAST);
        if (ccc_nack || (last_ccc_0 != CCC_ENTAS1_BCAST) || (last_ccc_1 != CCC_ENTAS1_BCAST) ||
            (activity_state_0 != 2'd1) || (activity_state_1 != 2'd1)) begin
            $display("FAIL: broadcast ENTAS1 mismatch nack=%0d last0=0x%02h last1=0x%02h act0=%0d act1=%0d",
                     ccc_nack, last_ccc_0, last_ccc_1, activity_state_0, activity_state_1);
            $finish(1);
        end

        do_direct_group_set(7'h30, 7'h70);
        do_direct_group_set(7'h31, 7'h70);
        if (!group_addr_valid_0 || !group_addr_valid_1 || (group_addr_0 != 7'h70) || (group_addr_1 != 7'h70)) begin
            $display("FAIL: SETGRPA mismatch valid0=%0d addr0=0x%02h valid1=%0d addr1=0x%02h",
                     group_addr_valid_0, group_addr_0, group_addr_valid_1, group_addr_1);
            $finish(1);
        end

        do_private_write(7'h70, 8'hA5);
        if (txn_rsp_nack || (register_selector_0 != 8'hA5) || (register_selector_1 != 8'hA5)) begin
            $display("FAIL: group write mismatch nack=%0d sel0=0x%02h sel1=0x%02h",
                     txn_rsp_nack, register_selector_0, register_selector_1);
            $finish(1);
        end

        do_direct_no_data(CCC_RSTGRPA_DIRECT, 7'h30);
        if (dccc_rsp_nack || group_addr_valid_0 || !group_addr_valid_1) begin
            $display("FAIL: direct RSTGRPA mismatch nack=%0d valid0=%0d valid1=%0d",
                     dccc_rsp_nack, group_addr_valid_0, group_addr_valid_1);
            $finish(1);
        end

        do_private_write(7'h70, 8'h5A);
        if (txn_rsp_nack || (register_selector_0 != 8'hA5) || (register_selector_1 != 8'h5A)) begin
            $display("FAIL: post-direct-reset group write mismatch nack=%0d sel0=0x%02h sel1=0x%02h",
                     txn_rsp_nack, register_selector_0, register_selector_1);
            $finish(1);
        end

        do_broadcast(CCC_RSTGRPA_BCAST);
        if (ccc_nack || group_addr_valid_0 || group_addr_valid_1) begin
            $display("FAIL: broadcast RSTGRPA mismatch nack=%0d valid0=%0d valid1=%0d",
                     ccc_nack, group_addr_valid_0, group_addr_valid_1);
            $finish(1);
        end

        do_private_write(7'h70, 8'h3C);
        if (!txn_rsp_nack) begin
            $display("FAIL: group write should NACK after broadcast RSTGRPA");
            $finish(1);
        end

        $display("PASS");
        #100;
        $finish;
    end

    initial begin
        #20_000_000;
        $display("FAIL: timeout");
        $finish(1);
    end

    task pulse_assign_dynamic_addr_0;
        input [6:0] addr;
        begin
            @(posedge clk);
            assign_dynamic_addr_0      <= addr;
            assign_dynamic_addr_valid_0<= 1'b1;
            @(posedge clk);
            assign_dynamic_addr_valid_0<= 1'b0;
        end
    endtask

    task pulse_assign_dynamic_addr_1;
        input [6:0] addr;
        begin
            @(posedge clk);
            assign_dynamic_addr_1      <= addr;
            assign_dynamic_addr_valid_1<= 1'b1;
            @(posedge clk);
            assign_dynamic_addr_valid_1<= 1'b0;
        end
    endtask

    task do_broadcast;
        input [7:0] code;
        begin
            @(posedge clk);
            while (!ccc_ready || dccc_busy || txn_req_valid) @(posedge clk);
            ccc_code     <= code;
            ccc_data_len <= 8'd0;
            ccc_data     <= 56'h0;
            ccc_valid    <= 1'b1;
            @(posedge clk);
            ccc_valid    <= 1'b0;
            while (!ccc_done) @(posedge clk);
        end
    endtask

    task do_direct_no_data;
        input [7:0] code;
        input [6:0] addr;
        begin
            @(posedge clk);
            while (!dccc_cmd_ready || txn_busy || ccc_txn_req_valid || txn_req_valid) @(posedge clk);
            dccc_ccc_code    <= code;
            dccc_target_addr <= addr;
            dccc_target_read <= 1'b0;
            dccc_tx_len      <= 8'd0;
            dccc_rx_len      <= 8'd0;
            dccc_tx_data     <= 32'h0;
            dccc_cmd_valid   <= 1'b1;
            @(posedge clk);
            dccc_cmd_valid   <= 1'b0;
            while (!dccc_rsp_valid) @(posedge clk);
        end
    endtask

    task do_direct_group_set;
        input [6:0] addr;
        input [6:0] group_addr_value;
        begin
            @(posedge clk);
            while (!dccc_cmd_ready || txn_busy || ccc_txn_req_valid || txn_req_valid) @(posedge clk);
            dccc_ccc_code    <= CCC_SETGRPA_DIRECT;
            dccc_target_addr <= addr;
            dccc_target_read <= 1'b0;
            dccc_tx_len      <= 8'd1;
            dccc_rx_len      <= 8'd0;
            dccc_tx_data     <= {24'h0, group_addr_value, 1'b0};
            dccc_cmd_valid   <= 1'b1;
            @(posedge clk);
            dccc_cmd_valid   <= 1'b0;
            while (!dccc_rsp_valid) @(posedge clk);
            if (dccc_rsp_nack) begin
                $display("FAIL: SETGRPA direct NACK addr=0x%02h", addr);
                $finish(1);
            end
        end
    endtask

    task do_private_write;
        input [6:0] addr;
        input [7:0] data;
        begin
            @(posedge clk);
            while (!txn_req_ready || ccc_txn_req_valid || dccc_busy) @(posedge clk);
            txn_req_addr   <= addr;
            txn_req_read   <= 1'b0;
            txn_req_tx_len <= 8'd1;
            txn_req_rx_len <= 8'd0;
            txn_req_wdata  <= {56'h0, data};
            txn_req_valid  <= 1'b1;
            @(posedge clk);
            txn_req_valid  <= 1'b0;
            while (!txn_rsp_valid) @(posedge clk);
        end
    endtask

endmodule
