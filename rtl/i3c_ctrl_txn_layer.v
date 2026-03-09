`timescale 1ns/1ps

module i3c_ctrl_txn_layer #(
    parameter integer CLK_FREQ_HZ    = 100_000_000,
    parameter integer I3C_SDR_HZ     = 1_000_000,
    parameter integer PUSH_PULL_DATA = 1,
    parameter integer MAX_TX_BYTES   = 4,
    parameter integer MAX_RX_BYTES   = 4
) (
    input  wire                          clk,
    input  wire                          rst_n,

    input  wire                          txn_req_valid,
    output reg                           txn_req_ready,
    input  wire [6:0]                    txn_req_addr,
    input  wire                          txn_req_read,
    input  wire [7:0]                    txn_req_tx_len,
    input  wire [7:0]                    txn_req_rx_len,
    input  wire [8*MAX_TX_BYTES-1:0]     txn_req_wdata,

    output reg                           txn_rsp_valid,
    output reg                           txn_rsp_nack,
    output reg [7:0]                     txn_rsp_rx_count,
    output reg [8*MAX_RX_BYTES-1:0]      txn_rsp_rdata,
    output reg                           busy,

    output wire                          scl_o,
    output wire                          scl_oe,
    output wire                          sda_o,
    output wire                          sda_oe,
    input  wire                          sda_i
);

    reg                       engine_valid;
    wire                      engine_ready;
    reg  [6:0]                engine_addr;
    reg                       engine_read;
    reg  [7:0]                engine_tx_len;
    reg  [7:0]                engine_rx_len;
    reg  [8*MAX_TX_BYTES-1:0] engine_wdata;

    wire                      engine_done;
    wire                      engine_nack;
    wire [7:0]                engine_rx_count;
    wire [8*MAX_RX_BYTES-1:0] engine_rdata;
    wire                      engine_busy;

    localparam [1:0] CTRL_IDLE   = 2'd0;
    localparam [1:0] CTRL_ACTIVE = 2'd1;
    localparam [1:0] CTRL_RSP    = 2'd2;

    reg [1:0] ctrl_state;

    // Phase 1+ hooks:
    // - DAA orchestration will issue sequenced transactions through this layer.
    // - CCC support will expand the request format beyond simple read/write.
    // - IBI service will inject high-priority transactions alongside scheduler traffic.
    // - Recovery logic will own retry and reset escalation decisions around failed responses.
    i3c_bus_engine #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .I3C_SDR_HZ(I3C_SDR_HZ),
        .PUSH_PULL_DATA(PUSH_PULL_DATA),
        .MAX_TX_BYTES(MAX_TX_BYTES),
        .MAX_RX_BYTES(MAX_RX_BYTES)
    ) u_bus_engine (
        .clk         (clk),
        .rst_n       (rst_n),
        .txn_valid   (engine_valid),
        .txn_ready   (engine_ready),
        .txn_addr    (engine_addr),
        .txn_read    (engine_read),
        .txn_tx_len  (engine_tx_len),
        .txn_rx_len  (engine_rx_len),
        .txn_wdata   (engine_wdata),
        .txn_done    (engine_done),
        .txn_nack    (engine_nack),
        .txn_rx_count(engine_rx_count),
        .txn_rdata   (engine_rdata),
        .busy        (engine_busy),
        .scl_o       (scl_o),
        .scl_oe      (scl_oe),
        .sda_o       (sda_o),
        .sda_oe      (sda_oe),
        .sda_i       (sda_i)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ctrl_state       <= CTRL_IDLE;
            engine_valid     <= 1'b0;
            engine_addr      <= 7'h00;
            engine_read      <= 1'b0;
            engine_tx_len    <= 8'd0;
            engine_rx_len    <= 8'd0;
            engine_wdata     <= {8*MAX_TX_BYTES{1'b0}};
            txn_req_ready    <= 1'b1;
            txn_rsp_valid    <= 1'b0;
            txn_rsp_nack     <= 1'b0;
            txn_rsp_rx_count <= 8'd0;
            txn_rsp_rdata    <= {8*MAX_RX_BYTES{1'b0}};
            busy             <= 1'b0;
        end else begin
            txn_rsp_valid <= 1'b0;

            case (ctrl_state)
                CTRL_IDLE: begin
                    txn_req_ready <= 1'b1;
                    engine_valid  <= 1'b0;
                    busy          <= 1'b0;

                    if (txn_req_valid) begin
                        engine_addr   <= txn_req_addr;
                        engine_read   <= txn_req_read;
                        engine_tx_len <= txn_req_tx_len;
                        engine_rx_len <= txn_req_rx_len;
                        engine_wdata  <= txn_req_wdata;
                        engine_valid  <= 1'b1;
                        txn_req_ready <= 1'b0;
                        busy          <= 1'b1;
                        ctrl_state    <= CTRL_ACTIVE;
                    end
                end

                CTRL_ACTIVE: begin
                    busy <= 1'b1;

                    if (engine_valid && engine_ready) begin
                        engine_valid <= 1'b0;
                    end

                    if (engine_done) begin
                        txn_rsp_nack     <= engine_nack;
                        txn_rsp_rx_count <= engine_rx_count;
                        txn_rsp_rdata    <= engine_rdata;
                        ctrl_state       <= CTRL_RSP;
                    end
                end

                CTRL_RSP: begin
                    busy          <= 1'b0;
                    txn_rsp_valid <= 1'b1;
                    txn_req_ready <= 1'b1;
                    ctrl_state    <= CTRL_IDLE;
                end

                default: begin
                    ctrl_state <= CTRL_IDLE;
                end
            endcase
        end
    end
endmodule
