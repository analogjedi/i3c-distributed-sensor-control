`timescale 1ns/1ps

module i3c_target_transport (
    input  wire       rst_n,
    input  wire       scl,
    inout  wire       sda,

    input  wire [6:0] target_addr,
    input  wire [7:0] read_data,
    output reg  [7:0] write_data,
    output reg        write_valid,
    output reg        read_valid,
    output reg        selected
);

    localparam [2:0] P_IDLE   = 3'd0;
    localparam [2:0] P_ADDR   = 3'd1;
    localparam [2:0] P_WRITE  = 3'd2;
    localparam [2:0] P_READ   = 3'd3;
    localparam [2:0] P_IGNORE = 3'd4;

    reg [2:0] phase;
    reg [3:0] bit_pos;
    reg [7:0] rx_shift;
    reg       sda_drive_low;
    reg       ack_pending;
    reg       addr_match;
    reg       rw_latched;

    assign sda = sda_drive_low ? 1'b0 : 1'bz;

    // Phase 1+ hooks:
    // - DAA logic will own dynamic address state rather than this fixed TARGET_ADDR.
    // - CCC decode will extend the write path beyond simple payload capture.
    // - IBI logic will arbitrate when this target may request bus ownership.
    // - Recovery logic will reset or gate transport behavior after local/system faults.
    always @(negedge sda or negedge rst_n) begin
        if (!rst_n) begin
            phase         <= P_IDLE;
            bit_pos       <= 4'd0;
            rx_shift      <= 8'h00;
            sda_drive_low <= 1'b0;
            ack_pending   <= 1'b0;
            addr_match    <= 1'b0;
            rw_latched    <= 1'b0;
            selected      <= 1'b0;
            write_data    <= 8'h00;
            write_valid   <= 1'b0;
            read_valid    <= 1'b0;
        end else if (scl === 1'b1) begin
            phase         <= P_ADDR;
            bit_pos       <= 4'd0;
            rx_shift      <= 8'h00;
            sda_drive_low <= 1'b0;
            ack_pending   <= 1'b0;
            addr_match    <= 1'b0;
            rw_latched    <= 1'b0;
            selected      <= 1'b0;
            write_valid   <= 1'b0;
            read_valid    <= 1'b0;
        end
    end

    always @(posedge sda or negedge rst_n) begin
        if (!rst_n) begin
            phase         <= P_IDLE;
            bit_pos       <= 4'd0;
            sda_drive_low <= 1'b0;
            ack_pending   <= 1'b0;
            selected      <= 1'b0;
            write_valid   <= 1'b0;
            read_valid    <= 1'b0;
        end else if (scl === 1'b1) begin
            phase         <= P_IDLE;
            bit_pos       <= 4'd0;
            sda_drive_low <= 1'b0;
            ack_pending   <= 1'b0;
            selected      <= 1'b0;
        end
    end

    always @(negedge scl or negedge rst_n) begin
        if (!rst_n) begin
            sda_drive_low <= 1'b0;
        end else if (ack_pending && (phase == P_ADDR || phase == P_WRITE) && (bit_pos == 4'd8)) begin
            sda_drive_low <= addr_match;
        end else if (phase == P_READ && bit_pos < 4'd8) begin
            sda_drive_low <= ~read_data[7 - bit_pos];
        end else begin
            sda_drive_low <= 1'b0;
        end
    end

    always @(posedge scl or negedge rst_n) begin
        if (!rst_n) begin
            phase       <= P_IDLE;
            bit_pos     <= 4'd0;
            rx_shift    <= 8'h00;
            ack_pending <= 1'b0;
            addr_match  <= 1'b0;
            rw_latched  <= 1'b0;
            selected    <= 1'b0;
            write_data  <= 8'h00;
            write_valid <= 1'b0;
            read_valid  <= 1'b0;
        end else begin
            write_valid <= 1'b0;
            read_valid  <= 1'b0;

            case (phase)
                P_ADDR: begin
                    if (bit_pos < 4'd8) begin
                        rx_shift <= {rx_shift[6:0], sda};
                        if (bit_pos == 4'd7) begin
                            addr_match  <= (({rx_shift[6:0], sda} & 8'hFE) == {target_addr, 1'b0});
                            rw_latched  <= sda;
                            ack_pending <= 1'b1;
                            bit_pos     <= 4'd8;
                        end else begin
                            bit_pos <= bit_pos + 1'b1;
                        end
                    end else begin
                        ack_pending <= 1'b0;
                        bit_pos     <= 4'd0;
                        selected    <= addr_match;
                        if (addr_match) begin
                            if (rw_latched) begin
                                read_valid <= 1'b1;
                            end
                            phase <= rw_latched ? P_READ : P_WRITE;
                        end else begin
                            phase <= P_IGNORE;
                        end
                    end
                end

                P_WRITE: begin
                    if (bit_pos < 4'd8) begin
                        rx_shift <= {rx_shift[6:0], sda};
                        if (bit_pos == 4'd7) begin
                            write_data  <= {rx_shift[6:0], sda};
                            write_valid <= 1'b1;
                            ack_pending <= 1'b1;
                            bit_pos     <= 4'd8;
                        end else begin
                            bit_pos <= bit_pos + 1'b1;
                        end
                    end else begin
                        ack_pending <= 1'b0;
                        bit_pos     <= 4'd0;
                        phase       <= P_IGNORE;
                    end
                end

                P_READ: begin
                    if (bit_pos < 4'd8) begin
                        bit_pos <= bit_pos + 1'b1;
                    end else begin
                        bit_pos <= 4'd0;
                        phase   <= P_IGNORE;
                    end
                end

                default: begin
                end
            endcase
        end
    end
endmodule
