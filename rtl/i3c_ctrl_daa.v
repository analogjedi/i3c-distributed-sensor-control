`timescale 1ns/1ps

module i3c_ctrl_daa #(
    parameter integer MAX_ENDPOINTS = 8,
    parameter [6:0]  DYN_ADDR_BASE  = 7'h10
) (
    input  wire                           clk,
    input  wire                           rst_n,
    input  wire                           clear_table,
    input  wire                           discover_valid,
    input  wire [47:0]                    discover_pid,

    output reg                            assign_valid,
    output reg  [6:0]                     assign_dynamic_addr,
    output reg  [$clog2(MAX_ENDPOINTS):0] endpoint_count,
    output reg                            table_full,
    output reg                            duplicate_pid,
    output reg  [47:0]                    last_pid
);

    localparam integer COUNT_W = $clog2(MAX_ENDPOINTS) + 1;

    reg [47:0] pid_table [0:MAX_ENDPOINTS-1];
    reg [6:0]  addr_table[0:MAX_ENDPOINTS-1];
    wire [6:0] next_dynamic_addr;

    integer i;
    reg       discover_seen_match;
    reg [6:0] discover_matched_addr;

    assign next_dynamic_addr = DYN_ADDR_BASE + endpoint_count[COUNT_W-2:0];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            assign_valid       <= 1'b0;
            assign_dynamic_addr<= 7'h00;
            endpoint_count     <= {($clog2(MAX_ENDPOINTS)+1){1'b0}};
            table_full         <= 1'b0;
            duplicate_pid      <= 1'b0;
            last_pid           <= 48'h0;
            for (i = 0; i < MAX_ENDPOINTS; i = i + 1) begin
                pid_table[i]  <= 48'h0;
                addr_table[i] <= 7'h00;
            end
        end else begin
            assign_valid  <= 1'b0;
            duplicate_pid <= 1'b0;

            if (clear_table) begin
                endpoint_count <= {($clog2(MAX_ENDPOINTS)+1){1'b0}};
                table_full     <= 1'b0;
                last_pid       <= 48'h0;
            end else if (discover_valid) begin
                discover_seen_match   = 1'b0;
                discover_matched_addr = 7'h00;
                for (i = 0; i < MAX_ENDPOINTS; i = i + 1) begin
                    if ((i < endpoint_count) && (pid_table[i] == discover_pid)) begin
                        discover_seen_match   = 1'b1;
                        discover_matched_addr = addr_table[i];
                    end
                end

                last_pid <= discover_pid;

                if (discover_seen_match) begin
                    assign_valid        <= 1'b1;
                    assign_dynamic_addr <= discover_matched_addr;
                    duplicate_pid       <= 1'b1;
                end else if (endpoint_count < MAX_ENDPOINTS) begin
                    pid_table[endpoint_count]  <= discover_pid;
                    addr_table[endpoint_count] <= next_dynamic_addr;
                    assign_valid               <= 1'b1;
                    assign_dynamic_addr        <= next_dynamic_addr;
                    endpoint_count             <= endpoint_count + 1'b1;
                    table_full                 <= 1'b0;
                end else begin
                    table_full <= 1'b1;
                end
            end
        end
    end
endmodule
