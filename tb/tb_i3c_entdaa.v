`timescale 1ns/1ps

module tb_i3c_entdaa;

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
    wire [7:0] daa_last_bcr;
    wire [7:0] daa_last_dcr;
    wire       inv_query_found;
    wire [47:0] inv_query_pid;
    wire [7:0] inv_query_bcr;
    wire [7:0] inv_query_dcr;
    wire [1:0] inv_query_class;
    wire       inv_query_enabled;
    wire       inv_query_health_fault;
    wire       inv_query_last_seen_ok;
    wire [7:0] inv_query_event_mask;
    wire [7:0] inv_query_reset_action;
    wire [15:0] inv_query_status;
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

    reg  [7:0] read_data;
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

    assign scl_line = entdaa_scl_oe ? entdaa_scl_o : 1'bz;
    assign scl_line = rw_scl_oe     ? rw_scl_o     : 1'bz;
    assign sda_line = entdaa_sda_oe ? entdaa_sda_o : 1'bz;
    assign sda_line = rw_sda_oe     ? rw_sda_o     : 1'bz;

    i3c_ctrl_entdaa #(
        .CLK_FREQ_HZ(100_000_000),
        .I3C_SDR_HZ(1_000_000),
        .PUSH_PULL_DATA(1)
    ) entdaa (
        .clk              (clk),
        .rst_n            (rst_n),
        .cmd_valid        (entdaa_cmd_valid),
        .cmd_ready        (entdaa_cmd_ready),
        .discover_valid   (discover_valid),
        .discover_pid     (discover_pid),
        .discover_bcr     (discover_bcr),
        .discover_dcr     (discover_dcr),
        .assign_valid     (daa_assign_valid),
        .assign_dynamic_addr(daa_assign_addr),
        .done             (entdaa_done),
        .nack             (entdaa_nack),
        .assigned_addr    (entdaa_assigned_addr),
        .busy             (entdaa_busy),
        .scl_o            (entdaa_scl_o),
        .scl_oe           (entdaa_scl_oe),
        .sda_o            (entdaa_sda_o),
        .sda_oe           (entdaa_sda_oe),
        .sda_i            (sda_line)
    );

    i3c_ctrl_inventory #(
        .MAX_ENDPOINTS(4),
        .DYN_ADDR_BASE(7'h10)
    ) inv (
        .clk                      (clk),
        .rst_n                    (rst_n),
        .clear_tables             (1'b0),
        .default_endpoint_enable  (1'b1),
        .discover_valid           (discover_valid),
        .discover_pid             (discover_pid),
        .discover_bcr             (discover_bcr),
        .discover_dcr             (discover_dcr),
        .broadcast_event_set_valid(1'b0),
        .broadcast_event_clear_valid(1'b0),
        .broadcast_event_mask     (8'h00),
        .direct_event_set_valid   (1'b0),
        .direct_event_clear_valid (1'b0),
        .direct_event_addr        (7'h00),
        .direct_event_mask        (8'h00),
        .enable_update_valid      (1'b0),
        .enable_update_addr       (7'h00),
        .enable_update_value      (1'b0),
        .reset_action_update_valid(1'b0),
        .reset_action_update_addr (7'h00),
        .reset_action_update_value(8'h00),
        .status_update_valid      (1'b0),
        .status_update_addr       (7'h00),
        .status_update_value      (16'h0000),
        .status_update_ok         (1'b0),
        .query_addr               (7'h10),
        .query_found              (inv_query_found),
        .query_pid                (inv_query_pid),
        .query_bcr                (inv_query_bcr),
        .query_dcr                (inv_query_dcr),
        .query_class              (inv_query_class),
        .query_enabled            (inv_query_enabled),
        .query_health_fault       (inv_query_health_fault),
        .query_last_seen_ok       (inv_query_last_seen_ok),
        .query_event_mask         (inv_query_event_mask),
        .query_reset_action       (inv_query_reset_action),
        .query_status             (inv_query_status),
        .scan_index               (2'd0),
        .scan_valid               (),
        .scan_addr                (),
        .scan_class               (),
        .scan_enabled             (),
        .scan_health_fault        (),
        .assign_valid             (daa_assign_valid),
        .assign_dynamic_addr      (daa_assign_addr),
        .daa_endpoint_count       (),
        .daa_table_full           (),
        .duplicate_pid            (),
        .last_pid                 (),
        .last_bcr                 (daa_last_bcr),
        .last_dcr                 (daa_last_dcr),
        .policy_endpoint_count    (),
        .policy_table_full        (),
        .policy_update_miss       (),
        .last_update_addr         (),
        .last_event_mask          ()
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
        .last_ccc                (last_ccc)
    );

    always #5 clk = ~clk;

    initial begin
        clk             = 1'b0;
        rst_n           = 1'b0;
        entdaa_cmd_valid= 1'b0;
        rw_cmd_valid    = 1'b0;
        rw_cmd_addr     = 7'h00;
        rw_cmd_read     = 1'b0;
        rw_cmd_wdata    = 8'h00;
        read_data       = 8'h3C;

        $dumpfile("tb_i3c_entdaa.vcd");
        $dumpvars(0, tb_i3c_entdaa);

        #200;
        rst_n = 1'b1;

        do_entdaa;

        if (entdaa_nack) begin
            $display("FAIL: ENTDAA returned NACK");
            $finish(1);
        end

        if (discover_pid != 48'h0BAD_F00D_CAFE) begin
            $display("FAIL: discovered PID mismatch got=0x%012h", discover_pid);
            $finish(1);
        end

        if ((discover_bcr != 8'h01) || (discover_dcr != 8'h5A)) begin
            $display("FAIL: BCR/DCR mismatch bcr=0x%02h dcr=0x%02h", discover_bcr, discover_dcr);
            $finish(1);
        end
        if ((daa_last_bcr != 8'h01) || (daa_last_dcr != 8'h5A)) begin
            $display("FAIL: controller inventory BCR/DCR mismatch bcr=0x%02h dcr=0x%02h",
                     daa_last_bcr, daa_last_dcr);
            $finish(1);
        end
        if (!inv_query_found || (inv_query_pid != 48'h0BAD_F00D_CAFE) ||
            (inv_query_bcr != 8'h01) || (inv_query_dcr != 8'h5A) ||
            (inv_query_class != 2'd1) || !inv_query_enabled ||
            inv_query_health_fault || inv_query_last_seen_ok ||
            (inv_query_event_mask != 8'h00) || (inv_query_reset_action != 8'h00) ||
            (inv_query_status != 16'h0000)) begin
            $display("FAIL: automatic policy population mismatch");
            $finish(1);
        end

        if (!dynamic_addr_valid || (active_addr != 7'h10) || (entdaa_assigned_addr != 7'h10)) begin
            $display("FAIL: ENTDAA assignment mismatch valid=%0d active=0x%02h assigned=0x%02h",
                     dynamic_addr_valid, active_addr, entdaa_assigned_addr);
            $finish(1);
        end

        do_read_expect_data(7'h10, 8'h3C);
        do_read_expect_nack(7'h2A);

        $display("PASS");
        #100;
        $finish;
    end

    initial begin
        #12_000_000;
        $display("FAIL: timeout");
        $finish(1);
    end

    task do_entdaa;
        begin
            @(posedge clk);
            while (!entdaa_cmd_ready) @(posedge clk);
            entdaa_cmd_valid <= 1'b1;
            @(posedge clk);
            entdaa_cmd_valid <= 1'b0;
            while (!entdaa_done) @(posedge clk);
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
