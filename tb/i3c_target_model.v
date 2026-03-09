`timescale 1ns/1ps

module i3c_target_model #(
    parameter [6:0] TARGET_ADDR = 7'h2A,
    parameter [7:0] READ_DATA   = 8'h3C
) (
    input  wire scl,
    inout  wire sda,
    output reg [7:0] last_write_data,
    output reg       write_seen
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

    initial begin
        phase           = P_IDLE;
        bit_pos         = 4'd0;
        rx_shift        = 8'h00;
        sda_drive_low   = 1'b0;
        ack_pending     = 1'b0;
        addr_match      = 1'b0;
        rw_latched      = 1'b0;
        last_write_data = 8'h00;
        write_seen      = 1'b0;
    end

    // START: SDA falling while SCL high.
    always @(negedge sda) begin
        if (scl === 1'b1) begin
            phase         <= P_ADDR;
            bit_pos       <= 4'd0;
            rx_shift      <= 8'h00;
            sda_drive_low <= 1'b0;
            ack_pending   <= 1'b0;
            addr_match    <= 1'b0;
            rw_latched    <= 1'b0;
        end
    end

    // STOP: SDA rising while SCL high.
    always @(posedge sda) begin
        if (scl === 1'b1) begin
            phase         <= P_IDLE;
            bit_pos       <= 4'd0;
            sda_drive_low <= 1'b0;
            ack_pending   <= 1'b0;
        end
    end

    // Drive ACK/data on SCL falling edges so data is stable before next SCL high.
    always @(negedge scl) begin
        if (ack_pending && (phase == P_ADDR || phase == P_WRITE) && (bit_pos == 4'd8)) begin
            sda_drive_low <= addr_match;
        end else if (phase == P_READ && bit_pos < 4'd8) begin
            sda_drive_low <= ~READ_DATA[7 - bit_pos];
        end else begin
            sda_drive_low <= 1'b0;
        end
    end

    // Sample bus on SCL high.
    always @(posedge scl) begin
        case (phase)
            P_ADDR: begin
                if (bit_pos < 4'd8) begin
                    rx_shift <= {rx_shift[6:0], sda};
                    if (bit_pos == 4'd7) begin
                        addr_match  <= (({rx_shift[6:0], sda} & 8'hFE) == {TARGET_ADDR, 1'b0});
                        rw_latched  <= sda;
                        ack_pending <= 1'b1;
                        bit_pos     <= 4'd8;
                    end else begin
                        bit_pos <= bit_pos + 1'b1;
                    end
                end else begin
                    // ACK bit just completed.
                    ack_pending <= 1'b0;
                    bit_pos     <= 4'd0;
                    if (addr_match) begin
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
                        last_write_data <= {rx_shift[6:0], sda};
                        write_seen      <= 1'b1;
                        ack_pending     <= 1'b1;
                        bit_pos         <= 4'd8;
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
                    // Controller ACK/NACK phase; read once and stop serving this transfer.
                    bit_pos <= 4'd0;
                    phase   <= P_IGNORE;
                end
            end

            default: begin
                // Keep waiting for STOP.
            end
        endcase
    end

endmodule
