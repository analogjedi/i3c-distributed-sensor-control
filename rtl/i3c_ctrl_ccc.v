`timescale 1ns/1ps

module i3c_ctrl_ccc #(
    parameter integer MAX_TX_BYTES = 8,
    parameter [6:0]  CCC_ADDR      = 7'h7E
) (
    input  wire                      clk,
    input  wire                      rst_n,

    input  wire                      ccc_valid,
    output reg                       ccc_ready,
    input  wire [7:0]                ccc_code,
    input  wire [7:0]                ccc_data_len,
    input  wire [8*(MAX_TX_BYTES-1)-1:0] ccc_data,

    output reg                       ccc_done,
    output reg                       ccc_nack,

    output reg                       txn_req_valid,
    input  wire                      txn_req_ready,
    output reg  [6:0]                txn_req_addr,
    output reg                       txn_req_read,
    output reg  [7:0]                txn_req_tx_len,
    output reg  [7:0]                txn_req_rx_len,
    output reg  [8*MAX_TX_BYTES-1:0] txn_req_wdata,

    input  wire                      txn_rsp_valid,
    input  wire                      txn_rsp_nack
);

    localparam [1:0] ST_IDLE   = 2'd0;
    localparam [1:0] ST_ISSUE  = 2'd1;
    localparam [1:0] ST_WAIT   = 2'd2;

    reg [1:0] state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state         <= ST_IDLE;
            ccc_ready     <= 1'b1;
            ccc_done      <= 1'b0;
            ccc_nack      <= 1'b0;
            txn_req_valid <= 1'b0;
            txn_req_addr  <= CCC_ADDR;
            txn_req_read  <= 1'b0;
            txn_req_tx_len<= 8'd0;
            txn_req_rx_len<= 8'd0;
            txn_req_wdata <= {8*MAX_TX_BYTES{1'b0}};
        end else begin
            ccc_done <= 1'b0;

            case (state)
                ST_IDLE: begin
                    ccc_ready     <= 1'b1;
                    txn_req_valid <= 1'b0;

                    if (ccc_valid) begin
                        ccc_ready              <= 1'b0;
                        txn_req_addr           <= CCC_ADDR;
                        txn_req_read           <= 1'b0;
                        txn_req_tx_len         <= ccc_data_len + 1'b1;
                        txn_req_rx_len         <= 8'd0;
                        txn_req_wdata[7:0]     <= ccc_code;
                        txn_req_wdata[8*MAX_TX_BYTES-1:8] <= {{(8*(MAX_TX_BYTES-1)){1'b0}}};
                        if (MAX_TX_BYTES > 1) begin
                            txn_req_wdata[8*MAX_TX_BYTES-1:8] <= ccc_data;
                        end
                        txn_req_valid          <= 1'b1;
                        ccc_nack               <= 1'b0;
                        state                  <= ST_ISSUE;
                    end
                end

                ST_ISSUE: begin
                    if (txn_req_valid && txn_req_ready) begin
                        txn_req_valid <= 1'b0;
                        state         <= ST_WAIT;
                    end
                end

                ST_WAIT: begin
                    if (txn_rsp_valid) begin
                        ccc_done  <= 1'b1;
                        ccc_nack  <= txn_rsp_nack;
                        ccc_ready <= 1'b1;
                        state     <= ST_IDLE;
                    end
                end

                default: begin
                    state <= ST_IDLE;
                end
            endcase
        end
    end
endmodule
