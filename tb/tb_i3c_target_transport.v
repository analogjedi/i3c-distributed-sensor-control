`timescale 1ns/1ps

module tb_i3c_target_transport;

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

    wire target_sda_drive_en;

    reg  [7:0] target_read_data;
    wire [7:0] target_write_data;
    wire       target_write_valid;
    wire       target_read_valid;
    wire       target_selected;
    reg  [7:0] last_target_write_data;
    reg        target_write_seen;
    reg        target_read_seen;
    reg        target_selected_seen;

    pullup (scl_line);

    assign scl_line = scl_oe ? scl_o : 1'bz;
    assign sda_line = ~((sda_oe & ~sda_o) | target_sda_drive_en);
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

    i3c_target_transport tgt (
        .rst_n      (rst_n),
        .scl        (scl_line),
        .sda        (sda_line),
        .sda_drive_en(target_sda_drive_en),
        .suppress   (1'b0),
        .target_addr(7'h2A),
        .read_data  ({24'h000000, target_read_data}),
        .write_data (target_write_data),
        .write_valid(target_write_valid),
        .read_valid (target_read_valid),
        .selected   (target_selected)
    );

    always #5 clk = ~clk;

    initial begin
        clk              = 1'b0;
        rst_n            = 1'b0;
        cmd_valid        = 1'b0;
        cmd_addr         = 7'h2A;
        cmd_read         = 1'b0;
        cmd_wdata        = 8'hA5;
        target_read_data = 8'h3C;
        last_target_write_data = 8'h00;
        target_write_seen      = 1'b0;
        target_read_seen       = 1'b0;
        target_selected_seen   = 1'b0;

        $dumpfile("tb_i3c_target_transport.vcd");
        $dumpvars(0, tb_i3c_target_transport);

        #200;
        rst_n = 1'b1;

        do_cmd(1'b0, 8'hA5);
        if (!target_write_seen || (last_target_write_data != 8'hA5)) begin
            $display("FAIL: target transport write mismatch (seen=%0d data=0x%02h)", target_write_seen, last_target_write_data);
            $finish(1);
        end

        do_cmd(1'b1, 8'h00);
        if (!target_read_seen || !target_selected_seen) begin
            $display("FAIL: target transport did not observe read selection");
            $finish(1);
        end
        if (cmd_rdata != 8'h3C) begin
            $display("FAIL: target transport read mismatch (got=0x%02h)", cmd_rdata);
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

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            last_target_write_data <= 8'h00;
            target_write_seen      <= 1'b0;
            target_read_seen       <= 1'b0;
            target_selected_seen   <= 1'b0;
        end else begin
            if (target_write_valid) begin
                last_target_write_data <= target_write_data;
                target_write_seen      <= 1'b1;
            end
            if (target_read_valid) begin
                target_read_seen <= 1'b1;
            end
            if (target_selected) begin
                target_selected_seen <= 1'b1;
            end
        end
    end

    task do_cmd;
        input read_not_write;
        input [7:0] wdata;
        begin
            @(posedge clk);
            while (!cmd_ready) @(posedge clk);
            if (!read_not_write) begin
                target_write_seen <= 1'b0;
            end else begin
                target_read_seen     <= 1'b0;
                target_selected_seen <= 1'b0;
            end
            cmd_addr  <= 7'h2A;
            cmd_read  <= read_not_write;
            cmd_wdata <= wdata;
            cmd_valid <= 1'b1;
            @(posedge clk);
            cmd_valid <= 1'b0;

            while (!rsp_valid) @(posedge clk);
            if (rsp_nack) begin
                $display("FAIL: controller saw NACK");
                $finish(1);
            end
        end
    endtask

endmodule
