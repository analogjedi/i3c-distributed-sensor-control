`timescale 1ns/1ps

module tb_i3c_direct_ccc_write;

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
    wire [31:0] rsp_rdata;
    wire       busy;

    wire scl_o;
    wire scl_oe;
    wire sda_o;
    wire sda_oe;
    wire sda_i;

    wire scl_line;
    wire sda_line;

    integer start_count;
    reg saw_ccc_code_phase;
    reg saw_target_addr_phase;
    reg saw_target_write_phase;
    reg saw_rstart_state;

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
        .MAX_RX_BYTES(4)
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

    i3c_direct_ccc_responder #(
        .READ_MODE(0)
    ) responder (
        .scl(scl_line),
        .sda(sda_line)
    );

    always #5 clk = ~clk;

    always @(negedge sda_line) begin
        if (scl_line === 1'b1) begin
            start_count = start_count + 1;
        end
    end

    always @(posedge clk) begin
        if (busy) begin
            if (dut.phase == 3'd1) saw_ccc_code_phase   <= 1'b1;
            if (dut.phase == 3'd2) saw_target_addr_phase<= 1'b1;
            if (dut.phase == 3'd3) saw_target_write_phase <= 1'b1;
            if (dut.state == 5'd8) saw_rstart_state    <= 1'b1;
        end
    end

    initial begin
        clk                  = 1'b0;
        rst_n                = 1'b0;
        cmd_valid            = 1'b0;
        ccc_code             = 8'h88;
        target_addr          = 7'h2A;
        target_read          = 1'b0;
        tx_len               = 8'd1;
        rx_len               = 8'd0;
        tx_data              = 32'h0000_0033;
        start_count          = 0;
        saw_ccc_code_phase   = 1'b0;
        saw_target_addr_phase= 1'b0;
        saw_target_write_phase = 1'b0;
        saw_rstart_state     = 1'b0;

        $dumpfile("tb_i3c_direct_ccc_write.vcd");
        $dumpvars(0, tb_i3c_direct_ccc_write);

        #200;
        rst_n = 1'b1;

        do_cmd;

        if (rsp_nack || !saw_ccc_code_phase || !saw_target_addr_phase ||
            !saw_target_write_phase || !saw_rstart_state) begin
            $display("FAIL: direct write framing mismatch nack=%0d starts=%0d ccc_phase=%0d tgt_addr=%0d tgt_wr=%0d rstart=%0d",
                     rsp_nack, start_count, saw_ccc_code_phase, saw_target_addr_phase,
                     saw_target_write_phase, saw_rstart_state);
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

    task do_cmd;
        begin
            @(posedge clk);
            while (!cmd_ready) @(posedge clk);
            cmd_valid <= 1'b1;
            @(posedge clk);
            cmd_valid <= 1'b0;
            while (!rsp_valid) @(posedge clk);
        end
    endtask

endmodule
