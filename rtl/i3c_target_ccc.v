`timescale 1ns/1ps

module i3c_target_ccc #(
    parameter [6:0] CCC_ADDR    = 7'h7E,
    parameter [7:0] CCC_RSTDAA  = 8'h07,
    parameter [7:0] CCC_SETAASA = 8'h2A
) (
    input  wire rst_n,
    input  wire scl,
    inout  wire sda,

    output reg  rstdaa_pulse,
    output reg  setaasa_pulse,
    output reg  ccc_seen,
    output reg  [7:0] last_ccc
);

    localparam [1:0] ST_IDLE = 2'd0;
    localparam [1:0] ST_ADDR = 2'd1;
    localparam [1:0] ST_ACK  = 2'd2;
    localparam [1:0] ST_DATA = 2'd3;

    reg [1:0] state;
    reg [3:0] bit_pos;
    reg [7:0] shift_reg;
    reg       addr_is_ccc;
    reg       rw_is_read;
    reg       ack_pending;
    reg       ack_from_data;
    reg       sda_drive_low;
    reg [7:0] data_count;

    assign sda = sda_drive_low ? 1'b0 : 1'bz;

    always @(negedge sda or negedge rst_n) begin
        if (!rst_n) begin
            state         <= ST_IDLE;
            bit_pos       <= 4'd0;
            shift_reg     <= 8'h00;
            addr_is_ccc   <= 1'b0;
            rw_is_read    <= 1'b0;
            ack_pending   <= 1'b0;
            ack_from_data <= 1'b0;
            sda_drive_low <= 1'b0;
            data_count    <= 8'd0;
            rstdaa_pulse  <= 1'b0;
            setaasa_pulse <= 1'b0;
            ccc_seen      <= 1'b0;
            last_ccc      <= 8'h00;
        end else if (scl === 1'b1) begin
            state         <= ST_ADDR;
            bit_pos       <= 4'd0;
            shift_reg     <= 8'h00;
            addr_is_ccc   <= 1'b0;
            rw_is_read    <= 1'b0;
            ack_pending   <= 1'b0;
            ack_from_data <= 1'b0;
            sda_drive_low <= 1'b0;
            data_count    <= 8'd0;
            rstdaa_pulse  <= 1'b0;
            setaasa_pulse <= 1'b0;
            ccc_seen      <= 1'b0;
        end
    end

    always @(posedge sda or negedge rst_n) begin
        if (!rst_n) begin
            state         <= ST_IDLE;
            bit_pos       <= 4'd0;
            ack_pending   <= 1'b0;
            ack_from_data <= 1'b0;
            sda_drive_low <= 1'b0;
            data_count    <= 8'd0;
            rstdaa_pulse  <= 1'b0;
            setaasa_pulse <= 1'b0;
            ccc_seen      <= 1'b0;
        end else if (scl === 1'b1) begin
            state         <= ST_IDLE;
            bit_pos       <= 4'd0;
            ack_pending   <= 1'b0;
            sda_drive_low <= 1'b0;
            data_count    <= 8'd0;
        end
    end

    always @(negedge scl or negedge rst_n) begin
        if (!rst_n) begin
            sda_drive_low <= 1'b0;
        end else if (ack_pending) begin
            sda_drive_low <= addr_is_ccc || ack_from_data;
        end else begin
            sda_drive_low <= 1'b0;
        end
    end

    always @(posedge scl or negedge rst_n) begin
        if (!rst_n) begin
            state         <= ST_IDLE;
            bit_pos       <= 4'd0;
            shift_reg     <= 8'h00;
            addr_is_ccc   <= 1'b0;
            rw_is_read    <= 1'b0;
            ack_pending   <= 1'b0;
            ack_from_data <= 1'b0;
            data_count    <= 8'd0;
            rstdaa_pulse  <= 1'b0;
            setaasa_pulse <= 1'b0;
            ccc_seen      <= 1'b0;
            last_ccc      <= 8'h00;
        end else begin
            rstdaa_pulse  <= 1'b0;
            setaasa_pulse <= 1'b0;
            ccc_seen      <= 1'b0;

            case (state)
                ST_ADDR: begin
                    shift_reg <= {shift_reg[6:0], sda};
                    if (bit_pos == 4'd7) begin
                        addr_is_ccc <= (({shift_reg[6:0], sda} & 8'hFE) == {CCC_ADDR, 1'b0});
                        rw_is_read  <= sda;
                        ack_pending <= 1'b1;
                        bit_pos     <= 4'd0;
                        state       <= ST_ACK;
                    end else begin
                        bit_pos <= bit_pos + 1'b1;
                    end
                end

                ST_ACK: begin
                    ack_pending <= 1'b0;
                    if (ack_from_data) begin
                        ack_from_data <= 1'b0;
                        state         <= ST_DATA;
                    end else if (addr_is_ccc && !rw_is_read) begin
                        state   <= ST_DATA;
                        bit_pos <= 4'd0;
                    end else begin
                        state <= ST_IDLE;
                    end
                end

                ST_DATA: begin
                    shift_reg <= {shift_reg[6:0], sda};
                    if (bit_pos == 4'd7) begin
                        if (data_count == 0) begin
                            last_ccc <= {shift_reg[6:0], sda};
                            ccc_seen <= 1'b1;
                            if ({shift_reg[6:0], sda} == CCC_RSTDAA) begin
                                rstdaa_pulse <= 1'b1;
                            end
                            if ({shift_reg[6:0], sda} == CCC_SETAASA) begin
                                setaasa_pulse <= 1'b1;
                            end
                        end
                        data_count    <= data_count + 1'b1;
                        bit_pos       <= 4'd0;
                        ack_pending   <= 1'b1;
                        ack_from_data <= 1'b1;
                        state         <= ST_ACK;
                    end else begin
                        bit_pos <= bit_pos + 1'b1;
                    end
                end

                default: begin
                end
            endcase
        end
    end
endmodule
