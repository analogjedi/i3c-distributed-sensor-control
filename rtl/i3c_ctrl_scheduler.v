`timescale 1ns/1ps

module i3c_ctrl_scheduler #(
    parameter integer MAX_ENDPOINTS = 8
) (
    input  wire                           clk,
    input  wire                           rst_n,
    input  wire                           enable,
    input  wire                           schedule_tick,
    input  wire                           req_accept,

    input  wire [$clog2(MAX_ENDPOINTS):0] endpoint_count,
    output reg  [$clog2(MAX_ENDPOINTS)-1:0] scan_index,
    input  wire                           scan_valid,
    input  wire [6:0]                     scan_addr,
    input  wire [1:0]                     scan_class,
    input  wire                           scan_enabled,
    input  wire                           scan_health_fault,

    output reg                            req_valid,
    output reg  [6:0]                     req_addr,
    output reg  [1:0]                     req_class,
    output reg  [$clog2(MAX_ENDPOINTS)-1:0] req_index,
    output reg                            busy,
    output reg                            missed_slot
);

    localparam integer INDEX_W = (MAX_ENDPOINTS <= 1) ? 1 : $clog2(MAX_ENDPOINTS);

    localparam [1:0] ST_IDLE = 2'd0;
    localparam [1:0] ST_SCAN = 2'd1;
    localparam [1:0] ST_WAIT = 2'd2;

    reg [1:0] state;
    reg [INDEX_W-1:0] rr_cursor;
    reg [INDEX_W-1:0] scan_count;

    function [INDEX_W-1:0] next_index;
        input [INDEX_W-1:0] current;
        begin
            if (endpoint_count <= 1) begin
                next_index = {INDEX_W{1'b0}};
            end else if (current + 1'b1 >= endpoint_count[INDEX_W-1:0]) begin
                next_index = {INDEX_W{1'b0}};
            end else begin
                next_index = current + 1'b1;
            end
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= ST_IDLE;
            rr_cursor   <= {INDEX_W{1'b0}};
            scan_index  <= {INDEX_W{1'b0}};
            scan_count  <= {INDEX_W{1'b0}};
            req_valid   <= 1'b0;
            req_addr    <= 7'h00;
            req_class   <= 2'd0;
            req_index   <= {INDEX_W{1'b0}};
            busy        <= 1'b0;
            missed_slot <= 1'b0;
        end else begin
            missed_slot <= 1'b0;

            case (state)
                ST_IDLE: begin
                    busy <= 1'b0;
                    if (req_valid) begin
                        if (req_accept) begin
                            rr_cursor <= next_index(req_index);
                            req_valid <= 1'b0;
                        end
                    end else if (enable && schedule_tick && (endpoint_count != 0)) begin
                        busy       <= 1'b1;
                        scan_index <= rr_cursor;
                        scan_count <= {INDEX_W{1'b0}};
                        state      <= ST_SCAN;
                    end
                end

                ST_SCAN: begin
                    busy <= 1'b1;
                    if (scan_valid && scan_enabled && !scan_health_fault) begin
                        req_valid <= 1'b1;
                        req_addr  <= scan_addr;
                        req_class <= scan_class;
                        req_index <= scan_index;
                        state     <= ST_WAIT;
                    end else if (scan_count + 1'b1 < endpoint_count[INDEX_W-1:0]) begin
                        scan_index <= next_index(scan_index);
                        scan_count <= scan_count + 1'b1;
                    end else begin
                        busy        <= 1'b0;
                        missed_slot <= 1'b1;
                        state       <= ST_IDLE;
                    end
                end

                ST_WAIT: begin
                    busy <= 1'b1;
                    if (req_accept) begin
                        rr_cursor <= next_index(req_index);
                        req_valid <= 1'b0;
                        busy      <= 1'b0;
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
