`timescale 1ns/1ps

module i3c_sdr_controller #(
    parameter integer CLK_FREQ_HZ    = 100_000_000,
    parameter integer I3C_SDR_HZ     = 1_000_000,
    parameter integer PUSH_PULL_DATA = 1,
    parameter integer MAX_TX_BYTES   = 4,
    parameter integer MAX_RX_BYTES   = 4
) (
    input  wire       clk,
    input  wire       rst_n,

    input  wire       cmd_valid,
    output reg        cmd_ready,
    input  wire [6:0] cmd_addr,
    input  wire       cmd_read,
    input  wire [7:0] cmd_wdata,

    output reg        rsp_valid,
    output reg        rsp_nack,
    output reg [7:0]  cmd_rdata,
    output reg        busy,

    output reg        scl_o,
    output reg        scl_oe,
    output reg        sda_o,
    output reg        sda_oe,
    input  wire       sda_i
);

    wire                          txn_req_ready;
    wire                          txn_rsp_valid;
    wire                          txn_rsp_nack;
    wire [7:0]                    txn_rsp_rx_count;
    wire [8*MAX_RX_BYTES-1:0]     txn_rsp_rdata;
    wire                          core_busy;

    wire [8*MAX_TX_BYTES-1:0] txn_req_wdata;
    assign txn_req_wdata[7:0] = cmd_wdata;
    generate
        if (MAX_TX_BYTES > 1) begin : g_unused_wbytes
            assign txn_req_wdata[8*MAX_TX_BYTES-1:8] = {(8*MAX_TX_BYTES-8){1'b0}};
        end
    endgenerate

    // Compatibility wrapper around the refactored transaction layer.
    // Phase 1+ controller modules for DAA/CCC/IBI/recovery will sit above this
    // interface and consume the multi-byte transaction path directly.
    i3c_ctrl_txn_layer #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .I3C_SDR_HZ(I3C_SDR_HZ),
        .PUSH_PULL_DATA(PUSH_PULL_DATA),
        .MAX_TX_BYTES(MAX_TX_BYTES),
        .MAX_RX_BYTES(MAX_RX_BYTES)
    ) u_txn_layer (
        .clk            (clk),
        .rst_n          (rst_n),
        .txn_req_valid  (cmd_valid),
        .txn_req_ready  (txn_req_ready),
        .txn_req_addr   (cmd_addr),
        .txn_req_read   (cmd_read),
        .txn_req_tx_len (cmd_read ? 8'd0 : 8'd1),
        .txn_req_rx_len (cmd_read ? 8'd1 : 8'd0),
        .txn_req_wdata  (txn_req_wdata),
        .txn_rsp_valid  (txn_rsp_valid),
        .txn_rsp_nack   (txn_rsp_nack),
        .txn_rsp_rx_count(txn_rsp_rx_count),
        .txn_rsp_rdata  (txn_rsp_rdata),
        .busy           (core_busy),
        .scl_o          (scl_o),
        .scl_oe         (scl_oe),
        .sda_o          (sda_o),
        .sda_oe         (sda_oe),
        .sda_i          (sda_i)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cmd_ready    <= 1'b1;
            rsp_valid    <= 1'b0;
            rsp_nack     <= 1'b0;
            cmd_rdata    <= 8'h00;
            busy         <= 1'b0;
        end else begin
            cmd_ready <= txn_req_ready;
            rsp_valid <= txn_rsp_valid;
            rsp_nack  <= txn_rsp_nack;
            cmd_rdata <= txn_rsp_rdata[7:0];
            busy      <= core_busy;
        end
    end
endmodule
