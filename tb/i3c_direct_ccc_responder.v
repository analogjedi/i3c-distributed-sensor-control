`timescale 1ns/1ps

module i3c_direct_ccc_responder #(
    parameter integer READ_MODE = 0,
    parameter [7:0]  READ_DATA  = 8'hC3,
    parameter [7:0]  ACK_BYTES_BEFORE_READ = 8'd3
) (
    input  wire scl,
    inout  wire sda
);

    reg [3:0] bit_pos;
    reg [7:0] byte_count;
    reg [3:0] read_bit_pos;
    reg       ack_pending;
    reg       reading;
    reg       sda_drive_low;

    assign sda = sda_drive_low ? 1'b0 : 1'bz;

    always @(negedge sda) begin
        if (scl === 1'b1) begin
            bit_pos <= 4'd0;
        end
    end

    always @(negedge scl) begin
        if (ack_pending) begin
            sda_drive_low <= 1'b1;
        end else if (reading && (read_bit_pos < 8)) begin
            sda_drive_low <= ~READ_DATA[7 - read_bit_pos];
        end else begin
            sda_drive_low <= 1'b0;
        end
    end

    always @(posedge scl) begin
        if (ack_pending) begin
            ack_pending <= 1'b0;
            if (READ_MODE && (byte_count == ACK_BYTES_BEFORE_READ)) begin
                reading      <= 1'b1;
                read_bit_pos <= 4'd0;
            end
        end else if (reading) begin
            if (read_bit_pos < 8) begin
                read_bit_pos <= read_bit_pos + 1'b1;
            end else begin
                reading <= 1'b0;
            end
        end else begin
            if (bit_pos == 4'd7) begin
                byte_count   <= byte_count + 1'b1;
                ack_pending  <= 1'b1;
                bit_pos      <= 4'd0;
            end else begin
                bit_pos <= bit_pos + 1'b1;
            end
        end
    end

    initial begin
        bit_pos       = 4'd0;
        byte_count    = 8'd0;
        read_bit_pos  = 4'd0;
        ack_pending   = 1'b0;
        reading       = 1'b0;
        sda_drive_low = 1'b0;
    end
endmodule
