`timescale 1ns/1ps

module tb_i3c_entdaa_multi;

    reg clk;
    reg rst_n;

    reg        entdaa_cmd_valid;
    wire       entdaa_cmd_ready;
    wire       discover_valid;
    wire [47:0] discover_pid;
    wire [7:0] discover_bcr;
    wire [7:0] discover_dcr;
    wire       daa_assign_valid;
    wire [6:0] daa_assign_addr;
    wire [2:0] endpoint_count;
    wire       entdaa_done;
    wire       entdaa_nack;
    wire [6:0] entdaa_assigned_addr;
    wire       entdaa_busy;

    reg        rw_cmd_valid;
    wire       rw_cmd_ready;
    reg [6:0]  rw_cmd_addr;
    reg        rw_cmd_read;
    reg [7:0]  rw_cmd_wdata;
    wire       rw_rsp_valid;
    wire       rw_rsp_nack;
    wire [7:0] rw_cmd_rdata;
    wire       rw_busy;

    wire entdaa_scl_o;
    wire entdaa_scl_oe;
    wire entdaa_sda_o;
    wire entdaa_sda_oe;

    wire rw_scl_o;
    wire rw_scl_oe;
    wire rw_sda_o;
    wire rw_sda_oe;

    wire scl_line;
    wire sda_line;

    reg  [7:0] read_data_0;
    wire [7:0] write_data_0;
    wire       write_valid_0;
    wire       read_valid_0;
    wire       selected_0;
    wire [6:0] active_addr_0;
    wire       dynamic_addr_valid_0;
    wire [47:0] provisional_id_0;

    reg  [7:0] read_data_1;
    wire [7:0] write_data_1;
    wire       write_valid_1;
    wire       read_valid_1;
    wire       selected_1;
    wire [6:0] active_addr_1;
    wire       dynamic_addr_valid_1;
    wire [47:0] provisional_id_1;

    wire [7:0] last_ccc_0;
    wire [7:0] last_ccc_1;

    pullup (scl_line);
    pullup (sda_line);

    assign scl_line = entdaa_scl_oe ? entdaa_scl_o : 1'bz;
    assign scl_line = rw_scl_oe     ? rw_scl_o     : 1'bz;
    assign sda_line = entdaa_sda_oe ? entdaa_sda_o : 1'bz;
    assign sda_line = rw_sda_oe     ? rw_sda_o     : 1'bz;

    i3c_ctrl_entdaa #(
        .CLK_FREQ_HZ(100_000_000),
        .I3C_SDR_HZ(1_000_000),
        .PUSH_PULL_DATA(1)
    ) entdaa (
        .clk                (clk),
        .rst_n              (rst_n),
        .cmd_valid          (entdaa_cmd_valid),
        .cmd_ready          (entdaa_cmd_ready),
        .discover_valid     (discover_valid),
        .discover_pid       (discover_pid),
        .discover_bcr       (discover_bcr),
        .discover_dcr       (discover_dcr),
        .assign_valid       (daa_assign_valid),
        .assign_dynamic_addr(daa_assign_addr),
        .done               (entdaa_done),
        .nack               (entdaa_nack),
        .assigned_addr      (entdaa_assigned_addr),
        .busy               (entdaa_busy),
        .scl_o              (entdaa_scl_o),
        .scl_oe             (entdaa_scl_oe),
        .sda_o              (entdaa_sda_o),
        .sda_oe             (entdaa_sda_oe),
        .sda_i              (sda_line)
    );

    i3c_ctrl_daa #(
        .MAX_ENDPOINTS(4),
        .DYN_ADDR_BASE(7'h10)
    ) daa (
        .clk                (clk),
        .rst_n              (rst_n),
        .clear_table        (1'b0),
        .discover_valid     (discover_valid),
        .discover_pid       (discover_pid),
        .assign_valid       (daa_assign_valid),
        .assign_dynamic_addr(daa_assign_addr),
        .endpoint_count     (endpoint_count),
        .table_full         (),
        .duplicate_pid      (),
        .last_pid           ()
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
        .PROVISIONAL_ID(48'h0A00_0000_0001)
    ) target0 (
        .clk                     (clk),
        .rst_n                   (rst_n),
        .scl                     (scl_line),
        .sda                     (sda_line),
        .clear_dynamic_addr      (1'b0),
        .assign_dynamic_addr_valid(1'b0),
        .assign_dynamic_addr     (7'h00),
        .read_data               (read_data_0),
        .write_data              (write_data_0),
        .write_valid             (write_valid_0),
        .read_valid              (read_valid_0),
        .selected                (selected_0),
        .active_addr             (active_addr_0),
        .dynamic_addr_valid      (dynamic_addr_valid_0),
        .provisional_id          (provisional_id_0),
        .last_ccc                (last_ccc_0)
    );

    i3c_target_top #(
        .STATIC_ADDR(7'h2B),
        .PROVISIONAL_ID(48'h0B00_0000_0001)
    ) target1 (
        .clk                     (clk),
        .rst_n                   (rst_n),
        .scl                     (scl_line),
        .sda                     (sda_line),
        .clear_dynamic_addr      (1'b0),
        .assign_dynamic_addr_valid(1'b0),
        .assign_dynamic_addr     (7'h00),
        .read_data               (read_data_1),
        .write_data              (write_data_1),
        .write_valid             (write_valid_1),
        .read_valid              (read_valid_1),
        .selected                (selected_1),
        .active_addr             (active_addr_1),
        .dynamic_addr_valid      (dynamic_addr_valid_1),
        .provisional_id          (provisional_id_1),
        .last_ccc                (last_ccc_1)
    );

    always #5 clk = ~clk;

    initial begin
        clk              = 1'b0;
        rst_n            = 1'b0;
        entdaa_cmd_valid = 1'b0;
        rw_cmd_valid     = 1'b0;
        rw_cmd_addr      = 7'h00;
        rw_cmd_read      = 1'b0;
        rw_cmd_wdata     = 8'h00;
        read_data_0      = 8'hA1;
        read_data_1      = 8'hB2;

        $dumpfile("tb_i3c_entdaa_multi.vcd");
        $dumpvars(0, tb_i3c_entdaa_multi);

        #200;
        rst_n = 1'b1;

        do_entdaa_expect_success(48'h0A00_0000_0001, 7'h10);
        do_entdaa_expect_success(48'h0B00_0000_0001, 7'h11);

        if (endpoint_count != 3'd2) begin
            $display("FAIL: expected endpoint_count=2 got=%0d", endpoint_count);
            $finish(1);
        end

        if (!dynamic_addr_valid_0 || !dynamic_addr_valid_1 ||
            (active_addr_0 != 7'h10) || (active_addr_1 != 7'h11)) begin
            $display("FAIL: multi-target address assignment mismatch a0_valid=%0d a0=0x%02h a1_valid=%0d a1=0x%02h",
                     dynamic_addr_valid_0, active_addr_0, dynamic_addr_valid_1, active_addr_1);
            $finish(1);
        end

        do_read_expect_data(7'h10, 8'hA1);
        do_read_expect_data(7'h11, 8'hB2);
        do_read_expect_nack(7'h2A);
        do_read_expect_nack(7'h2B);
        do_entdaa_expect_nack;

        $display("PASS");
        #100;
        $finish;
    end

    initial begin
        #20_000_000;
        $display("FAIL: timeout");
        $finish(1);
    end

    task do_entdaa_expect_success;
        input [47:0] expected_pid;
        input [6:0]  expected_addr;
        begin
            @(posedge clk);
            while (!entdaa_cmd_ready) @(posedge clk);
            entdaa_cmd_valid <= 1'b1;
            @(posedge clk);
            entdaa_cmd_valid <= 1'b0;
            while (!entdaa_done) @(posedge clk);

            if (entdaa_nack) begin
                $display("FAIL: unexpected ENTDAA NACK expected_pid=0x%012h", expected_pid);
                $finish(1);
            end
            if (discover_pid != expected_pid) begin
                $display("FAIL: discover_pid mismatch got=0x%012h expected=0x%012h",
                         discover_pid, expected_pid);
                $finish(1);
            end
            if ((discover_bcr != 8'h01) || (discover_dcr != 8'h5A)) begin
                $display("FAIL: BCR/DCR mismatch bcr=0x%02h dcr=0x%02h", discover_bcr, discover_dcr);
                $finish(1);
            end
            if (entdaa_assigned_addr != expected_addr) begin
                $display("FAIL: assigned addr mismatch got=0x%02h expected=0x%02h",
                         entdaa_assigned_addr, expected_addr);
                $finish(1);
            end
        end
    endtask

    task do_entdaa_expect_nack;
        begin
            @(posedge clk);
            while (!entdaa_cmd_ready) @(posedge clk);
            entdaa_cmd_valid <= 1'b1;
            @(posedge clk);
            entdaa_cmd_valid <= 1'b0;
            while (!entdaa_done) @(posedge clk);

            if (!entdaa_nack) begin
                $display("FAIL: expected ENTDAA NACK when no unassigned targets remain");
                $finish(1);
            end
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
