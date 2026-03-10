`timescale 1ns/1ps

module i3c_ctrl_policy #(
    parameter integer MAX_ENDPOINTS = 8
) (
    input  wire                           clk,
    input  wire                           rst_n,
    input  wire                           clear_table,

    input  wire                           endpoint_add_valid,
    input  wire [6:0]                     endpoint_dynamic_addr,
    input  wire [47:0]                    endpoint_pid,
    input  wire [7:0]                     endpoint_bcr,
    input  wire [7:0]                     endpoint_dcr,

    input  wire                           broadcast_event_set_valid,
    input  wire                           broadcast_event_clear_valid,
    input  wire [7:0]                     broadcast_event_mask,

    input  wire                           direct_event_set_valid,
    input  wire                           direct_event_clear_valid,
    input  wire [6:0]                     direct_event_addr,
    input  wire [7:0]                     direct_event_mask,

    input  wire [6:0]                     query_addr,
    output reg                            query_found,
    output reg  [47:0]                    query_pid,
    output reg  [7:0]                     query_bcr,
    output reg  [7:0]                     query_dcr,
    output reg  [7:0]                     query_event_mask,

    output reg  [$clog2(MAX_ENDPOINTS):0] endpoint_count,
    output reg                            table_full,
    output reg                            policy_update_miss,
    output reg  [6:0]                     last_update_addr,
    output reg  [7:0]                     last_event_mask
);

    integer i;
    reg       add_seen_match;
    reg       direct_seen_match;
    reg [7:0] updated_mask;

    reg [6:0]  addr_table      [0:MAX_ENDPOINTS-1];
    reg [47:0] pid_table       [0:MAX_ENDPOINTS-1];
    reg [7:0]  bcr_table       [0:MAX_ENDPOINTS-1];
    reg [7:0]  dcr_table       [0:MAX_ENDPOINTS-1];
    reg [7:0]  event_mask_table[0:MAX_ENDPOINTS-1];

    always @(*) begin
        query_found      = 1'b0;
        query_pid        = 48'h0;
        query_bcr        = 8'h00;
        query_dcr        = 8'h00;
        query_event_mask = 8'h00;

        for (i = 0; i < MAX_ENDPOINTS; i = i + 1) begin
            if ((i < endpoint_count) && (addr_table[i] == query_addr)) begin
                query_found      = 1'b1;
                query_pid        = pid_table[i];
                query_bcr        = bcr_table[i];
                query_dcr        = dcr_table[i];
                query_event_mask = event_mask_table[i];
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            endpoint_count     <= {($clog2(MAX_ENDPOINTS)+1){1'b0}};
            table_full         <= 1'b0;
            policy_update_miss <= 1'b0;
            last_update_addr   <= 7'h00;
            last_event_mask    <= 8'h00;
            for (i = 0; i < MAX_ENDPOINTS; i = i + 1) begin
                addr_table[i]       <= 7'h00;
                pid_table[i]        <= 48'h0;
                bcr_table[i]        <= 8'h00;
                dcr_table[i]        <= 8'h00;
                event_mask_table[i] <= 8'h00;
            end
        end else begin
            policy_update_miss <= 1'b0;

            if (clear_table) begin
                endpoint_count     <= {($clog2(MAX_ENDPOINTS)+1){1'b0}};
                table_full         <= 1'b0;
                policy_update_miss <= 1'b0;
                last_update_addr   <= 7'h00;
                last_event_mask    <= 8'h00;
                for (i = 0; i < MAX_ENDPOINTS; i = i + 1) begin
                    addr_table[i]       <= 7'h00;
                    pid_table[i]        <= 48'h0;
                    bcr_table[i]        <= 8'h00;
                    dcr_table[i]        <= 8'h00;
                    event_mask_table[i] <= 8'h00;
                end
            end else if (endpoint_add_valid) begin
                add_seen_match = 1'b0;
                for (i = 0; i < MAX_ENDPOINTS; i = i + 1) begin
                    if ((i < endpoint_count) && (addr_table[i] == endpoint_dynamic_addr)) begin
                        addr_table[i] <= endpoint_dynamic_addr;
                        pid_table[i]  <= endpoint_pid;
                        bcr_table[i]  <= endpoint_bcr;
                        dcr_table[i]  <= endpoint_dcr;
                        add_seen_match = 1'b1;
                    end
                end

                last_update_addr <= endpoint_dynamic_addr;
                if (!add_seen_match) begin
                    if (endpoint_count < MAX_ENDPOINTS) begin
                        addr_table[endpoint_count]       <= endpoint_dynamic_addr;
                        pid_table[endpoint_count]        <= endpoint_pid;
                        bcr_table[endpoint_count]        <= endpoint_bcr;
                        dcr_table[endpoint_count]        <= endpoint_dcr;
                        event_mask_table[endpoint_count] <= 8'h00;
                        endpoint_count                   <= endpoint_count + 1'b1;
                        table_full                       <= 1'b0;
                        last_event_mask                  <= 8'h00;
                    end else begin
                        table_full <= 1'b1;
                    end
                end
            end else if (broadcast_event_set_valid || broadcast_event_clear_valid) begin
                last_update_addr <= 7'h7E;
                for (i = 0; i < MAX_ENDPOINTS; i = i + 1) begin
                    if (i < endpoint_count) begin
                        if (broadcast_event_set_valid) begin
                            event_mask_table[i] <= event_mask_table[i] | broadcast_event_mask;
                            last_event_mask     <= event_mask_table[i] | broadcast_event_mask;
                        end else begin
                            event_mask_table[i] <= event_mask_table[i] & ~broadcast_event_mask;
                            last_event_mask     <= event_mask_table[i] & ~broadcast_event_mask;
                        end
                    end
                end
            end else if (direct_event_set_valid || direct_event_clear_valid) begin
                direct_seen_match = 1'b0;
                updated_mask      = 8'h00;
                last_update_addr  <= direct_event_addr;

                for (i = 0; i < MAX_ENDPOINTS; i = i + 1) begin
                    if ((i < endpoint_count) && (addr_table[i] == direct_event_addr)) begin
                        if (direct_event_set_valid) begin
                            updated_mask        = event_mask_table[i] | direct_event_mask;
                            event_mask_table[i] <= event_mask_table[i] | direct_event_mask;
                        end else begin
                            updated_mask        = event_mask_table[i] & ~direct_event_mask;
                            event_mask_table[i] <= event_mask_table[i] & ~direct_event_mask;
                        end
                        direct_seen_match = 1'b1;
                    end
                end

                if (direct_seen_match) begin
                    last_event_mask <= updated_mask;
                end else begin
                    policy_update_miss <= 1'b1;
                end
            end
        end
    end
endmodule
