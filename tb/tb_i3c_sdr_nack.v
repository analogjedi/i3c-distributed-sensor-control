`timescale 1ns/1ps

module tb_i3c_sdr_nack;

    reg clk;
    reg rst_n;

    reg        cmd_valid;
    wire       cmd_ready;
    reg [6:0]  cmd_addr;
    reg        cmd_read;
    reg [7:0]  cmd_wdata;
    wire       rsp_valid;
    wire       rsp_nack;
    wire [7:0] cmd_rdata;
    wire       busy;

    wire scl_o;
    wire scl_oe;
    wire sda_o;
    wire sda_oe;
    wire sda_i;

    wire scl_line;
    wire sda_line;

    wire [7:0] last_write_data;
    wire       write_seen;

    pullup (scl_line);
    pullup (sda_line);

    assign scl_line = scl_oe ? scl_o : 1'bz;
    assign sda_line = sda_oe ? sda_o : 1'bz;
    assign sda_i    = sda_line;

    i3c_sdr_controller #(
        .CLK_FREQ_HZ(100_000_000),
        .I3C_SDR_HZ(1_000_000),
        .PUSH_PULL_DATA(1)
    ) dut (
        .clk      (clk),
        .rst_n    (rst_n),
        .cmd_valid(cmd_valid),
        .cmd_ready(cmd_ready),
        .cmd_addr (cmd_addr),
        .cmd_read (cmd_read),
        .cmd_wdata(cmd_wdata),
        .rsp_valid(rsp_valid),
        .rsp_nack (rsp_nack),
        .cmd_rdata(cmd_rdata),
        .busy     (busy),
        .scl_o    (scl_o),
        .scl_oe   (scl_oe),
        .sda_o    (sda_o),
        .sda_oe   (sda_oe),
        .sda_i    (sda_i)
    );

    i3c_target_model #(
        .TARGET_ADDR(7'h2A),
        .READ_DATA(8'h3C)
    ) tgt (
        .scl(scl_line),
        .sda(sda_line),
        .last_write_data(last_write_data),
        .write_seen(write_seen)
    );

    always #5 clk = ~clk;

    initial begin
        clk       = 1'b0;
        rst_n     = 1'b0;
        cmd_valid = 1'b0;
        cmd_addr  = 7'h31;
        cmd_read  = 1'b0;
        cmd_wdata = 8'h5A;

        $dumpfile("tb_i3c_sdr_nack.vcd");
        $dumpvars(0, tb_i3c_sdr_nack);

        #200;
        rst_n = 1'b1;

        @(posedge clk);
        while (!cmd_ready) @(posedge clk);
        cmd_valid <= 1'b1;
        @(posedge clk);
        cmd_valid <= 1'b0;

        while (!rsp_valid) @(posedge clk);
        if (!rsp_nack) begin
            $display("FAIL: expected NACK response");
            $finish(1);
        end

        if (write_seen) begin
            $display("FAIL: target should not have accepted a mismatched address");
            $finish(1);
        end

        $display("PASS");
        #100;
        $finish;
    end

    initial begin
        #5_000_000;
        $display("FAIL: timeout");
        $finish(1);
    end

endmodule
