`timescale 1ns/1ps

module tb_i3c_entdaa_stress;

    reg clk;
    reg rst_n;

    reg         entdaa_cmd_valid;
    wire        entdaa_cmd_ready;
    wire        discover_valid;
    wire [47:0] discover_pid;
    wire [7:0]  discover_bcr;
    wire [7:0]  discover_dcr;
    wire        daa_assign_valid;
    wire [6:0]  daa_assign_addr;
    wire [3:0]  endpoint_count;
    wire        table_full;
    wire [7:0]  daa_last_bcr;
    wire [7:0]  daa_last_dcr;
    reg  [6:0]  inv_query_addr;
    wire        inv_query_found;
    wire [47:0] inv_query_pid;
    wire [7:0]  inv_query_bcr;
    wire [7:0]  inv_query_dcr;
    wire [1:0]  inv_query_class;
    wire        inv_query_enabled;
    wire        inv_query_health_fault;
    wire        inv_query_last_seen_ok;
    wire [7:0]  inv_query_event_mask;
    wire [7:0]  inv_query_reset_action;
    wire [15:0] inv_query_status;
    wire        entdaa_done;
    wire        entdaa_nack;
    wire [6:0]  entdaa_assigned_addr;
    wire        entdaa_busy;

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

    wire target0_sda_oe;
    wire target1_sda_oe;
    wire target2_sda_oe;
    wire target3_sda_oe;
    wire target4_sda_oe;
    wire target5_sda_oe;

    reg  [7:0] read_data_0;
    reg  [7:0] read_data_1;
    reg  [7:0] read_data_2;
    reg  [7:0] read_data_3;
    reg  [7:0] read_data_4;
    reg  [7:0] read_data_5;

    wire [7:0] write_data_0;
    wire [7:0] write_data_1;
    wire [7:0] write_data_2;
    wire [7:0] write_data_3;
    wire [7:0] write_data_4;
    wire [7:0] write_data_5;
    wire       write_valid_0;
    wire       write_valid_1;
    wire       write_valid_2;
    wire       write_valid_3;
    wire       write_valid_4;
    wire       write_valid_5;
    wire       read_valid_0;
    wire       read_valid_1;
    wire       read_valid_2;
    wire       read_valid_3;
    wire       read_valid_4;
    wire       read_valid_5;
    wire       selected_0;
    wire       selected_1;
    wire       selected_2;
    wire       selected_3;
    wire       selected_4;
    wire       selected_5;
    wire [6:0] active_addr_0;
    wire [6:0] active_addr_1;
    wire [6:0] active_addr_2;
    wire [6:0] active_addr_3;
    wire [6:0] active_addr_4;
    wire [6:0] active_addr_5;
    wire       dynamic_addr_valid_0;
    wire       dynamic_addr_valid_1;
    wire       dynamic_addr_valid_2;
    wire       dynamic_addr_valid_3;
    wire       dynamic_addr_valid_4;
    wire       dynamic_addr_valid_5;
    wire [47:0] provisional_id_0;
    wire [47:0] provisional_id_1;
    wire [47:0] provisional_id_2;
    wire [47:0] provisional_id_3;
    wire [47:0] provisional_id_4;
    wire [47:0] provisional_id_5;
    wire [7:0]  last_ccc_0;
    wire [7:0]  last_ccc_1;
    wire [7:0]  last_ccc_2;
    wire [7:0]  last_ccc_3;
    wire [7:0]  last_ccc_4;
    wire [7:0]  last_ccc_5;

    pullup (scl_line);

    assign scl_line = entdaa_scl_oe ? entdaa_scl_o : 1'bz;
    assign scl_line = rw_scl_oe     ? rw_scl_o     : 1'bz;
    assign sda_line = ~((entdaa_sda_oe & ~entdaa_sda_o) | (rw_sda_oe & ~rw_sda_o) | target0_sda_oe | target1_sda_oe | target2_sda_oe | target3_sda_oe | target4_sda_oe | target5_sda_oe);

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

    i3c_ctrl_inventory #(
        .MAX_ENDPOINTS(6),
        .DYN_ADDR_BASE(7'h10)
    ) inv (
        .clk                      (clk),
        .rst_n                    (rst_n),
        .clear_tables             (1'b0),
        .default_endpoint_enable  (1'b1),
        .default_service_period   (8'd1),
        .schedule_tick            (1'b0),
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
        .service_period_update_valid(1'b0),
        .service_period_update_addr(7'h00),
        .service_period_update_value(8'h00),
        .service_len_update_valid (1'b0),
        .service_len_update_addr  (7'h00),
        .service_len_update_value (8'h00),
        .service_selector_update_valid(1'b0),
        .service_selector_update_addr(7'h00),
        .service_selector_update_value(8'h00),
        .service_result_valid     (1'b0),
        .service_result_addr      (7'h00),
        .service_result_nack      (1'b0),
        .query_addr               (inv_query_addr),
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
        .query_service_period     (),
        .query_service_rx_len     (),
        .query_service_selector   (),
        .query_service_count      (),
        .query_success_count      (),
        .query_error_count        (),
        .query_consecutive_failures(),
        .query_last_service_tag   (),
        .query_due_now            (),
        .scan_index               (3'd0),
        .scan_valid               (),
        .scan_addr                (),
        .scan_class               (),
        .scan_enabled             (),
        .scan_health_fault        (),
        .scan_due                 (),
        .scan_service_rx_len      (),
        .scan_service_selector    (),
        .assign_valid             (daa_assign_valid),
        .assign_dynamic_addr      (daa_assign_addr),
        .daa_endpoint_count       (endpoint_count),
        .daa_table_full           (table_full),
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
        .STATIC_ADDR   (7'h30),
        .PROVISIONAL_ID(48'h3200_0000_0001),
        .TARGET_BCR    (8'h31),
        .TARGET_DCR    (8'hC1)
    ) target0 (
        .clk                     (clk),
        .rst_n                   (rst_n),
        .scl                     (scl_line),
        .sda                     (sda_line),
        .sda_oe                  (target0_sda_oe),
        .clear_dynamic_addr      (1'b0),
        .assign_dynamic_addr_valid(1'b0),
        .assign_dynamic_addr     (7'h00),
        .read_data               ({24'h000000, read_data_0}),
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
        .STATIC_ADDR   (7'h31),
        .PROVISIONAL_ID(48'h1000_0000_0001),
        .TARGET_BCR    (8'h11),
        .TARGET_DCR    (8'hA1)
    ) target1 (
        .clk                     (clk),
        .rst_n                   (rst_n),
        .scl                     (scl_line),
        .sda                     (sda_line),
        .sda_oe                  (target1_sda_oe),
        .clear_dynamic_addr      (1'b0),
        .assign_dynamic_addr_valid(1'b0),
        .assign_dynamic_addr     (7'h00),
        .read_data               ({24'h000000, read_data_1}),
        .write_data              (write_data_1),
        .write_valid             (write_valid_1),
        .read_valid              (read_valid_1),
        .selected                (selected_1),
        .active_addr             (active_addr_1),
        .dynamic_addr_valid      (dynamic_addr_valid_1),
        .provisional_id          (provisional_id_1),
        .last_ccc                (last_ccc_1)
    );

    i3c_target_top #(
        .STATIC_ADDR   (7'h32),
        .PROVISIONAL_ID(48'h2200_0000_0001),
        .TARGET_BCR    (8'h21),
        .TARGET_DCR    (8'hB1)
    ) target2 (
        .clk                     (clk),
        .rst_n                   (rst_n),
        .scl                     (scl_line),
        .sda                     (sda_line),
        .sda_oe                  (target2_sda_oe),
        .clear_dynamic_addr      (1'b0),
        .assign_dynamic_addr_valid(1'b0),
        .assign_dynamic_addr     (7'h00),
        .read_data               ({24'h000000, read_data_2}),
        .write_data              (write_data_2),
        .write_valid             (write_valid_2),
        .read_valid              (read_valid_2),
        .selected                (selected_2),
        .active_addr             (active_addr_2),
        .dynamic_addr_valid      (dynamic_addr_valid_2),
        .provisional_id          (provisional_id_2),
        .last_ccc                (last_ccc_2)
    );

    i3c_target_top #(
        .STATIC_ADDR   (7'h33),
        .PROVISIONAL_ID(48'h1800_0000_0001),
        .TARGET_BCR    (8'h19),
        .TARGET_DCR    (8'hA9)
    ) target3 (
        .clk                     (clk),
        .rst_n                   (rst_n),
        .scl                     (scl_line),
        .sda                     (sda_line),
        .sda_oe                  (target3_sda_oe),
        .clear_dynamic_addr      (1'b0),
        .assign_dynamic_addr_valid(1'b0),
        .assign_dynamic_addr     (7'h00),
        .read_data               ({24'h000000, read_data_3}),
        .write_data              (write_data_3),
        .write_valid             (write_valid_3),
        .read_valid              (read_valid_3),
        .selected                (selected_3),
        .active_addr             (active_addr_3),
        .dynamic_addr_valid      (dynamic_addr_valid_3),
        .provisional_id          (provisional_id_3),
        .last_ccc                (last_ccc_3)
    );

    i3c_target_top #(
        .STATIC_ADDR   (7'h34),
        .PROVISIONAL_ID(48'h0500_0000_0001),
        .TARGET_BCR    (8'h08),
        .TARGET_DCR    (8'h10)
    ) target4 (
        .clk                     (clk),
        .rst_n                   (rst_n),
        .scl                     (scl_line),
        .sda                     (sda_line),
        .sda_oe                  (target4_sda_oe),
        .clear_dynamic_addr      (1'b0),
        .assign_dynamic_addr_valid(1'b0),
        .assign_dynamic_addr     (7'h00),
        .read_data               ({24'h000000, read_data_4}),
        .write_data              (write_data_4),
        .write_valid             (write_valid_4),
        .read_valid              (read_valid_4),
        .selected                (selected_4),
        .active_addr             (active_addr_4),
        .dynamic_addr_valid      (dynamic_addr_valid_4),
        .provisional_id          (provisional_id_4),
        .last_ccc                (last_ccc_4)
    );

    i3c_target_top #(
        .STATIC_ADDR   (7'h35),
        .PROVISIONAL_ID(48'h2800_0000_0001),
        .TARGET_BCR    (8'h04),
        .TARGET_DCR    (8'h01)
    ) target5 (
        .clk                     (clk),
        .rst_n                   (rst_n),
        .scl                     (scl_line),
        .sda                     (sda_line),
        .sda_oe                  (target5_sda_oe),
        .clear_dynamic_addr      (1'b0),
        .assign_dynamic_addr_valid(1'b0),
        .assign_dynamic_addr     (7'h00),
        .read_data               ({24'h000000, read_data_5}),
        .write_data              (write_data_5),
        .write_valid             (write_valid_5),
        .read_valid              (read_valid_5),
        .selected                (selected_5),
        .active_addr             (active_addr_5),
        .dynamic_addr_valid      (dynamic_addr_valid_5),
        .provisional_id          (provisional_id_5),
        .last_ccc                (last_ccc_5)
    );

    always #5 clk = ~clk;

    initial begin
        clk              = 1'b0;
        rst_n            = 1'b0;
        entdaa_cmd_valid = 1'b0;
        inv_query_addr   = 7'h00;
        rw_cmd_valid     = 1'b0;
        rw_cmd_addr      = 7'h00;
        rw_cmd_read      = 1'b0;
        rw_cmd_wdata     = 8'h00;
        read_data_0      = 8'hD0;
        read_data_1      = 8'hD1;
        read_data_2      = 8'hD2;
        read_data_3      = 8'hD3;
        read_data_4      = 8'hD4;
        read_data_5      = 8'hD5;

        $dumpfile("tb_i3c_entdaa_stress.vcd");
        $dumpvars(0, tb_i3c_entdaa_stress);

        #200;
        rst_n = 1'b1;

        do_entdaa_expect_success(48'h0500_0000_0001, 8'h08, 8'h10, 7'h10, 2'd1);
        do_entdaa_expect_success(48'h1000_0000_0001, 8'h11, 8'hA1, 7'h11, 2'd3);
        do_entdaa_expect_success(48'h1800_0000_0001, 8'h19, 8'hA9, 7'h12, 2'd3);
        do_entdaa_expect_success(48'h2200_0000_0001, 8'h21, 8'hB1, 7'h13, 2'd2);
        do_entdaa_expect_success(48'h2800_0000_0001, 8'h04, 8'h01, 7'h14, 2'd0);
        do_entdaa_expect_success(48'h3200_0000_0001, 8'h31, 8'hC1, 7'h15, 2'd2);

        if (endpoint_count != 3'd6) begin
            $display("FAIL: expected endpoint_count=6 got=%0d", endpoint_count);
            $finish(1);
        end
        if (table_full) begin
            $display("FAIL: table_full asserted during exact-fit stress run");
            $finish(1);
        end

        if (!dynamic_addr_valid_0 || !dynamic_addr_valid_1 ||
            !dynamic_addr_valid_2 || !dynamic_addr_valid_3 ||
            !dynamic_addr_valid_4 || !dynamic_addr_valid_5 ||
            (active_addr_0 != 7'h15) || (active_addr_1 != 7'h11) ||
            (active_addr_2 != 7'h13) || (active_addr_3 != 7'h12) ||
            (active_addr_4 != 7'h10) || (active_addr_5 != 7'h14)) begin
            $display("FAIL: stress address assignment mismatch a0=0x%02h a1=0x%02h a2=0x%02h a3=0x%02h a4=0x%02h a5=0x%02h",
                     active_addr_0, active_addr_1, active_addr_2, active_addr_3,
                     active_addr_4, active_addr_5);
            $finish(1);
        end

        do_read_expect_data(7'h10, 8'hD4);
        do_read_expect_data(7'h11, 8'hD1);
        do_read_expect_data(7'h12, 8'hD3);
        do_read_expect_data(7'h13, 8'hD2);
        do_read_expect_data(7'h14, 8'hD5);
        do_read_expect_data(7'h15, 8'hD0);

        do_read_expect_nack(7'h30);
        do_read_expect_nack(7'h31);
        do_read_expect_nack(7'h32);
        do_read_expect_nack(7'h33);
        do_read_expect_nack(7'h34);
        do_read_expect_nack(7'h35);

        do_entdaa_expect_nack;

        $display("PASS");
        #100;
        $finish;
    end

    initial begin
        #30_000_000;
        $display("FAIL: timeout");
        $finish(1);
    end

    task do_entdaa_expect_success;
        input [47:0] expected_pid;
        input [7:0]  expected_bcr;
        input [7:0]  expected_dcr;
        input [6:0]  expected_addr;
        input [1:0]  expected_class;
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
            if ((discover_bcr != expected_bcr) || (discover_dcr != expected_dcr)) begin
                $display("FAIL: discover BCR/DCR mismatch bcr=0x%02h dcr=0x%02h expected_bcr=0x%02h expected_dcr=0x%02h",
                         discover_bcr, discover_dcr, expected_bcr, expected_dcr);
                $finish(1);
            end
            if ((daa_last_bcr != expected_bcr) || (daa_last_dcr != expected_dcr)) begin
                $display("FAIL: controller inventory BCR/DCR mismatch bcr=0x%02h dcr=0x%02h expected_bcr=0x%02h expected_dcr=0x%02h",
                         daa_last_bcr, daa_last_dcr, expected_bcr, expected_dcr);
                $finish(1);
            end
            if (entdaa_assigned_addr != expected_addr) begin
                $display("FAIL: assigned addr mismatch got=0x%02h expected=0x%02h",
                         entdaa_assigned_addr, expected_addr);
                $finish(1);
            end
            inv_query_addr <= expected_addr;
            @(posedge clk);
            if (!inv_query_found || (inv_query_pid != expected_pid) ||
                (inv_query_bcr != expected_bcr) || (inv_query_dcr != expected_dcr) ||
                (inv_query_class != expected_class) || !inv_query_enabled ||
                inv_query_health_fault || inv_query_last_seen_ok ||
                (inv_query_event_mask != 8'h00) || (inv_query_reset_action != 8'h00) ||
                (inv_query_status != 16'h0000)) begin
                $display("FAIL: automatic policy population mismatch addr=0x%02h", expected_addr);
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
