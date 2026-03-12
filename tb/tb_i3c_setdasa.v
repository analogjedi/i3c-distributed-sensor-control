`timescale 1ns/1ps

module tb_i3c_setdasa;

    localparam [7:0] CCC_SETDASA = 8'h87;

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
    wire [31:0] dccc_rsp_rdata;
    wire       dccc_busy;

    reg        rw_cmd_valid;
    wire       rw_cmd_ready;
    reg [6:0]  rw_cmd_addr;
    reg        rw_cmd_read;
    reg [7:0]  rw_cmd_wdata;
    wire       rw_rsp_valid;
    wire       rw_rsp_nack;
    wire [7:0] rw_cmd_rdata;
    wire       rw_busy;

    wire dccc_scl_o;
    wire dccc_scl_oe;
    wire dccc_sda_o;
    wire dccc_sda_oe;

    wire rw_scl_o;
    wire rw_scl_oe;
    wire rw_sda_o;
    wire rw_sda_oe;

    wire scl_line;
    wire sda_line;

    wire target_sda_oe;

    reg  [7:0] read_data;
    wire [7:0] write_data;
    wire       write_valid;
    wire       read_valid;
    wire       selected;
    wire [6:0] active_addr;
    wire       dynamic_addr_valid;
    wire [47:0] provisional_id;
    wire [7:0] last_ccc;

    reg write_seen_during_setdasa;

    pullup (scl_line);

    assign scl_line = dccc_scl_oe ? dccc_scl_o : 1'bz;
    assign scl_line = rw_scl_oe   ? rw_scl_o   : 1'bz;
    assign sda_line = ~((dccc_sda_oe & ~dccc_sda_o) | (rw_sda_oe & ~rw_sda_o) | target_sda_oe);

    i3c_ctrl_direct_ccc #(
        .CLK_FREQ_HZ(100_000_000),
        .I3C_SDR_HZ(1_000_000),
        .PUSH_PULL_DATA(1),
        .MAX_TX_BYTES(4),
        .MAX_RX_BYTES(4)
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
        .sda_i      (sda_line)
    );

    i3c_sdr_controller #(
        .CLK_FREQ_HZ(100_000_000),
        .I3C_SDR_HZ(1_000_000),
        .PUSH_PULL_DATA(1)
    ) rw_ctrl (
        .clk      (clk),
        .rst_n    (rst_n),
        .cmd_valid(rw_cmd_valid),
        .cmd_ready(rw_cmd_ready),
        .cmd_addr (rw_cmd_addr),
        .cmd_read (rw_cmd_read),
        .cmd_wdata(rw_cmd_wdata),
        .rsp_valid(rw_rsp_valid),
        .rsp_nack (rw_rsp_nack),
        .cmd_rdata(rw_cmd_rdata),
        .busy     (rw_busy),
        .scl_o    (rw_scl_o),
        .scl_oe   (rw_scl_oe),
        .sda_o    (rw_sda_o),
        .sda_oe   (rw_sda_oe),
        .sda_i    (sda_line)
    );

    i3c_target_top #(
        .STATIC_ADDR(7'h2A),
        .PROVISIONAL_ID(48'h0BAD_F00D_CAFE)
    ) target (
        .clk                     (clk),
        .rst_n                   (rst_n),
        .scl                     (scl_line),
        .sda                     (sda_line),
        .sda_oe                  (target_sda_oe),
        .clear_dynamic_addr      (1'b0),
        .assign_dynamic_addr_valid(1'b0),
        .assign_dynamic_addr     (7'h00),
        .read_data               ({24'h000000, read_data}),
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

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            write_seen_during_setdasa <= 1'b0;
        end else if (dccc_busy && write_valid) begin
            write_seen_during_setdasa <= 1'b1;
        end
    end

    initial begin
        clk                     = 1'b0;
        rst_n                   = 1'b0;
        dccc_cmd_valid          = 1'b0;
        dccc_ccc_code           = CCC_SETDASA;
        dccc_target_addr        = 7'h2A;
        dccc_target_read        = 1'b0;
        dccc_tx_len             = 8'd1;
        dccc_rx_len             = 8'd0;
        dccc_tx_data            = 32'h0000_0066;
        rw_cmd_valid            = 1'b0;
        rw_cmd_addr             = 7'h00;
        rw_cmd_read             = 1'b0;
        rw_cmd_wdata            = 8'h00;
        read_data               = 8'hA6;
        write_seen_during_setdasa = 1'b0;

        $dumpfile("tb_i3c_setdasa.vcd");
        $dumpvars(0, tb_i3c_setdasa);

        #200;
        rst_n = 1'b1;

        if (dynamic_addr_valid || (active_addr != 7'h2A)) begin
            $display("FAIL: unexpected initial address state valid=%0d addr=0x%02h",
                     dynamic_addr_valid, active_addr);
            $finish(1);
        end

        do_setdasa(7'h2A, 7'h33);

        if (dccc_rsp_nack || (last_ccc != CCC_SETDASA)) begin
            $display("FAIL: SETDASA response mismatch nack=%0d last_ccc=0x%02h",
                     dccc_rsp_nack, last_ccc);
            $finish(1);
        end

        if (!dynamic_addr_valid || (active_addr != 7'h33)) begin
            $display("FAIL: SETDASA did not update dynamic address valid=%0d addr=0x%02h",
                     dynamic_addr_valid, active_addr);
            $finish(1);
        end

        if (write_seen_during_setdasa) begin
            $display("FAIL: transport payload path was not suppressed during SETDASA");
            $finish(1);
        end

        do_read_expect_data(7'h33, 8'hA6);
        do_read_expect_nack(7'h2A);

        $display("PASS");
        #100;
        $finish;
    end

    initial begin
        #10_000_000;
        $display("FAIL: timeout");
        $finish(1);
    end

    task do_setdasa;
        input [6:0] static_addr;
        input [6:0] dynamic_addr;
        begin
            @(posedge clk);
            while (!dccc_cmd_ready) @(posedge clk);
            dccc_ccc_code    <= CCC_SETDASA;
            dccc_target_addr <= static_addr;
            dccc_target_read <= 1'b0;
            dccc_tx_len      <= 8'd1;
            dccc_rx_len      <= 8'd0;
            dccc_tx_data     <= {24'h0, dynamic_addr, 1'b0};
            dccc_cmd_valid   <= 1'b1;
            @(posedge clk);
            dccc_cmd_valid   <= 1'b0;
            while (!dccc_rsp_valid) @(posedge clk);
        end
    endtask

    task do_read_expect_data;
        input [6:0] addr;
        input [7:0] expected;
        begin
            @(posedge clk);
            while (!rw_cmd_ready) @(posedge clk);
            rw_cmd_addr  <= addr;
            rw_cmd_read  <= 1'b1;
            rw_cmd_wdata <= 8'h00;
            rw_cmd_valid <= 1'b1;
            @(posedge clk);
            rw_cmd_valid <= 1'b0;
            while (!rw_rsp_valid) @(posedge clk);
            if (rw_rsp_nack || (rw_cmd_rdata != expected)) begin
                $display("FAIL: read mismatch addr=0x%02h nack=%0d data=0x%02h",
                         addr, rw_rsp_nack, rw_cmd_rdata);
                $finish(1);
            end
        end
    endtask

    task do_read_expect_nack;
        input [6:0] addr;
        begin
            @(posedge clk);
            while (!rw_cmd_ready) @(posedge clk);
            rw_cmd_addr  <= addr;
            rw_cmd_read  <= 1'b1;
            rw_cmd_wdata <= 8'h00;
            rw_cmd_valid <= 1'b1;
            @(posedge clk);
            rw_cmd_valid <= 1'b0;
            while (!rw_rsp_valid) @(posedge clk);
            if (!rw_rsp_nack) begin
                $display("FAIL: expected NACK for addr=0x%02h", addr);
                $finish(1);
            end
        end
    endtask

endmodule
