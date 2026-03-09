`timescale 1ns/1ps

module spartan7_i3c_top #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer I3C_SDR_HZ  = 1_000_000,
    parameter [6:0]  TARGET_ADDR  = 7'h2A
) (
    input  wire clk_100mhz,
    input  wire btn_rst_n,
    output wire led_done,
    output wire led_error,
    inout  wire i3c_scl,
    inout  wire i3c_sda
);

    wire scl_o;
    wire scl_oe;
    wire sda_o;
    wire sda_oe;
    wire sda_i;
    wire scl_i_unused;

    reg        cmd_valid;
    wire       cmd_ready;
    reg        cmd_read;
    reg [6:0]  cmd_addr;
    reg [7:0]  cmd_wdata;
    wire       rsp_valid;
    wire       rsp_nack;
    wire [7:0] cmd_rdata;
    wire       busy;

    reg [26:0] interval_cnt;
    reg        do_read_next;
    reg        led_done_r;
    reg        led_error_r;

    assign led_done  = led_done_r;
    assign led_error = led_error_r;

    // Drive pads through IOBUF so SDA can switch between drive and receive.
    IOBUF iobuf_scl (
        .I (scl_o),
        .O (scl_i_unused),
        .IO(i3c_scl),
        .T (~scl_oe)
    );

    IOBUF iobuf_sda (
        .I (sda_o),
        .O (sda_i),
        .IO(i3c_sda),
        .T (~sda_oe)
    );

    i3c_sdr_controller #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .I3C_SDR_HZ(I3C_SDR_HZ),
        .PUSH_PULL_DATA(1)
    ) u_ctrl (
        .clk      (clk_100mhz),
        .rst_n    (btn_rst_n),
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

    // Demo sequencer:
    // - Periodically alternates write/read commands.
    // - Successful transfers toggle DONE LED.
    // - NACK latches ERROR LED high.
    always @(posedge clk_100mhz) begin
        if (!btn_rst_n) begin
            cmd_valid     <= 1'b0;
            cmd_read      <= 1'b0;
            cmd_addr      <= TARGET_ADDR;
            cmd_wdata     <= 8'hA5;
            interval_cnt  <= 27'd0;
            do_read_next  <= 1'b0;
            led_done_r    <= 1'b0;
            led_error_r   <= 1'b0;
        end else begin
            cmd_valid <= 1'b0;

            if (interval_cnt == CLK_FREQ_HZ - 1) begin
                interval_cnt <= 27'd0;
                if (cmd_ready) begin
                    cmd_valid    <= 1'b1;
                    cmd_read     <= do_read_next;
                    cmd_addr     <= TARGET_ADDR;
                    cmd_wdata    <= 8'hA5;
                    do_read_next <= ~do_read_next;
                end
            end else begin
                interval_cnt <= interval_cnt + 1'b1;
            end

            if (rsp_valid) begin
                if (rsp_nack) begin
                    led_error_r <= 1'b1;
                end else begin
                    led_done_r <= ~led_done_r;
                end
            end
        end
    end

endmodule

