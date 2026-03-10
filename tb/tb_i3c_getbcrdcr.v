`timescale 1ns/1ps

module tb_i3c_getbcrdcr;

    localparam [7:0] CCC_GETBCR = 8'h8E;
    localparam [7:0] CCC_GETDCR = 8'h8F;

    reg clk;
    reg rst_n;

    reg        cmd_valid;
    wire       cmd_ready;
    reg [7:0]  ccc_code;
    reg [6:0]  target_addr;
    reg        target_read;
    reg [7:0]  tx_len;
    reg [7:0]  rx_len;
    reg [31:0] tx_data;
    wire       rsp_valid;
    wire       rsp_nack;
    wire [7:0] rsp_rx_count;
    wire [7:0] rsp_rdata;
    wire       busy;

    wire scl_o;
    wire scl_oe;
    wire sda_o;
    wire sda_oe;
    wire sda_i;

    wire scl_line;
    wire sda_line;

    reg  [7:0] read_data;
    wire [7:0] write_data;
    wire       write_valid;
    wire       read_valid;
    wire       selected;
    wire [6:0] active_addr;
    wire       dynamic_addr_valid;
    wire [47:0] provisional_id;
    wire [7:0] event_enable_mask;
    wire [7:0] last_ccc;

    pullup (scl_line);
    pullup (sda_line);

    assign scl_line = scl_oe ? scl_o : 1'bz;
    assign sda_line = sda_oe ? sda_o : 1'bz;
    assign sda_i    = sda_line;

    i3c_ctrl_direct_ccc #(
        .CLK_FREQ_HZ(100_000_000),
        .I3C_SDR_HZ(1_000_000),
        .PUSH_PULL_DATA(1),
        .MAX_TX_BYTES(4),
        .MAX_RX_BYTES(1)
    ) dut (
        .clk        (clk),
        .rst_n      (rst_n),
        .cmd_valid  (cmd_valid),
        .cmd_ready  (cmd_ready),
        .ccc_code   (ccc_code),
        .target_addr(target_addr),
        .target_read(target_read),
        .tx_len     (tx_len),
        .rx_len     (rx_len),
        .tx_data    (tx_data),
        .rsp_valid  (rsp_valid),
        .rsp_nack   (rsp_nack),
        .rsp_rx_count(rsp_rx_count),
        .rsp_rdata  (rsp_rdata),
        .busy       (busy),
        .scl_o      (scl_o),
        .scl_oe     (scl_oe),
        .sda_o      (sda_o),
        .sda_oe     (sda_oe),
        .sda_i      (sda_i)
    );

    i3c_target_top #(
        .STATIC_ADDR(7'h2A),
        .PROVISIONAL_ID(48'h0BAD_F00D_CAFE),
        .TARGET_BCR(8'h24),
        .TARGET_DCR(8'hA7)
    ) target (
        .clk                     (clk),
        .rst_n                   (rst_n),
        .scl                     (scl_line),
        .sda                     (sda_line),
        .clear_dynamic_addr      (1'b0),
        .assign_dynamic_addr_valid(1'b0),
        .assign_dynamic_addr     (7'h00),
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

    always #5 clk = ~clk;

    initial begin
        clk       = 1'b0;
        rst_n     = 1'b0;
        cmd_valid = 1'b0;
        ccc_code  = CCC_GETBCR;
        target_addr= 7'h2A;
        target_read= 1'b1;
        tx_len    = 8'd0;
        rx_len    = 8'd1;
        tx_data   = 32'h0;
        read_data = 8'h55;

        $dumpfile("tb_i3c_getbcrdcr.vcd");
        $dumpvars(0, tb_i3c_getbcrdcr);

        #200;
        rst_n = 1'b1;

        do_cmd(CCC_GETBCR);
        if (rsp_nack || (last_ccc != CCC_GETBCR) || (rsp_rx_count != 8'd1) || (rsp_rdata != 8'h24)) begin
            $display("FAIL: GETBCR response mismatch nack=%0d last_ccc=0x%02h rx_count=%0d data=0x%02h",
                     rsp_nack, last_ccc, rsp_rx_count, rsp_rdata);
            $finish(1);
        end

        do_cmd(CCC_GETDCR);
        if (rsp_nack || (last_ccc != CCC_GETDCR) || (rsp_rx_count != 8'd1) || (rsp_rdata != 8'hA7)) begin
            $display("FAIL: GETDCR response mismatch nack=%0d last_ccc=0x%02h rx_count=%0d data=0x%02h",
                     rsp_nack, last_ccc, rsp_rx_count, rsp_rdata);
            $finish(1);
        end

        if (event_enable_mask != 8'h00) begin
            $display("FAIL: GETBCR/GETDCR should not perturb event policy state");
            $finish(1);
        end

        $display("PASS");
        #100;
        $finish;
    end

    initial begin
        #10_000_000;
        $display("FAIL: timeout");
        $finish(1);
    end

    task do_cmd;
        input [7:0] code;
        begin
            @(posedge clk);
            while (!cmd_ready) @(posedge clk);
            ccc_code  <= code;
            cmd_valid <= 1'b1;
            @(posedge clk);
            cmd_valid <= 1'b0;
            while (!rsp_valid) @(posedge clk);
        end
    endtask

endmodule
