`timescale 1ns/1ps

module tb_i3c_daa_state;

    reg clk;
    reg rst_n;

    reg        clear_table;
    reg        discover_valid;
    reg [47:0] discover_pid;
    wire       assign_valid;
    wire [6:0] assign_dynamic_addr;
    wire [3:0] endpoint_count;
    wire       table_full;
    wire       duplicate_pid;
    wire [47:0] last_pid;
    reg        assign_seen;
    reg [6:0]  assigned_addr_seen;
    reg        duplicate_seen;

    reg        clear_dynamic_addr;
    reg        assign_dynamic_addr_valid;
    reg [6:0]  assign_dynamic_addr_in;
    wire [6:0] active_addr;
    wire       dynamic_addr_valid;
    wire [47:0] provisional_id;

    i3c_ctrl_daa #(
        .MAX_ENDPOINTS(8),
        .DYN_ADDR_BASE(7'h20)
    ) ctrl_daa (
        .clk                (clk),
        .rst_n              (rst_n),
        .clear_table        (clear_table),
        .discover_valid     (discover_valid),
        .discover_pid       (discover_pid),
        .assign_valid       (assign_valid),
        .assign_dynamic_addr(assign_dynamic_addr),
        .endpoint_count     (endpoint_count),
        .table_full         (table_full),
        .duplicate_pid      (duplicate_pid),
        .last_pid           (last_pid)
    );

    i3c_target_daa #(
        .STATIC_ADDR(7'h2A),
        .PROVISIONAL_ID(48'h0BAD_F00D_CAFE)
    ) target_daa (
        .clk                     (clk),
        .rst_n                   (rst_n),
        .clear_dynamic_addr      (clear_dynamic_addr),
        .assign_dynamic_addr_valid(assign_dynamic_addr_valid),
        .assign_dynamic_addr     (assign_dynamic_addr_in),
        .active_addr             (active_addr),
        .dynamic_addr_valid      (dynamic_addr_valid),
        .provisional_id          (provisional_id)
    );

    always #5 clk = ~clk;

    initial begin
        clk                     = 1'b0;
        rst_n                   = 1'b0;
        clear_table             = 1'b0;
        discover_valid          = 1'b0;
        discover_pid            = 48'h0;
        assign_seen             = 1'b0;
        assigned_addr_seen      = 7'h00;
        duplicate_seen          = 1'b0;
        clear_dynamic_addr      = 1'b0;
        assign_dynamic_addr_valid = 1'b0;
        assign_dynamic_addr_in  = 7'h00;

        #100;
        rst_n = 1'b1;

        discover_once(48'hAA00_0000_0001);
        if (!assign_seen || (assigned_addr_seen != 7'h20) || (endpoint_count != 1)) begin
            $display("FAIL: first DAA assignment mismatch");
            $finish(1);
        end

        discover_once(48'hAA00_0000_0002);
        if (!assign_seen || (assigned_addr_seen != 7'h21) || (endpoint_count != 2)) begin
            $display("FAIL: second DAA assignment mismatch");
            $finish(1);
        end

        discover_once(48'hAA00_0000_0001);
        if (!assign_seen || !duplicate_seen || (assigned_addr_seen != 7'h20)) begin
            $display("FAIL: duplicate PID handling mismatch");
            $finish(1);
        end

        assign_target_addr(7'h33);
        if (!dynamic_addr_valid || (active_addr != 7'h33)) begin
            $display("FAIL: target DAA assignment mismatch");
            $finish(1);
        end

        clear_dynamic_addr <= 1'b1;
        @(posedge clk);
        clear_dynamic_addr <= 1'b0;
        @(posedge clk);
        if (dynamic_addr_valid || (active_addr != 7'h2A)) begin
            $display("FAIL: target DAA clear mismatch");
            $finish(1);
        end

        if (provisional_id != 48'h0BAD_F00D_CAFE) begin
            $display("FAIL: provisional ID mismatch");
            $finish(1);
        end

        $display("PASS");
        #50;
        $finish;
    end

    task discover_once;
        input [47:0] pid;
        begin
            @(posedge clk);
            assign_seen     <= 1'b0;
            duplicate_seen  <= 1'b0;
            discover_pid    <= pid;
            discover_valid  <= 1'b1;
            @(posedge clk);
            @(posedge clk);
            discover_valid  <= 1'b0;
            @(posedge clk);
        end
    endtask

    task assign_target_addr;
        input [6:0] addr;
        begin
            @(posedge clk);
            assign_dynamic_addr_in    <= addr;
            assign_dynamic_addr_valid <= 1'b1;
            @(posedge clk);
            assign_dynamic_addr_valid <= 1'b0;
            @(posedge clk);
        end
    endtask

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            assign_seen        <= 1'b0;
            assigned_addr_seen <= 7'h00;
            duplicate_seen     <= 1'b0;
        end else begin
            if (assign_valid) begin
                assign_seen        <= 1'b1;
                assigned_addr_seen <= assign_dynamic_addr;
            end
            if (duplicate_pid) begin
                duplicate_seen <= 1'b1;
            end
        end
    end

endmodule
