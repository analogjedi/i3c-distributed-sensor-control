`timescale 1ns/1ps

module i3c_target_ccc #(
    parameter [6:0] CCC_ADDR     = 7'h7E,
    parameter [6:0] STATIC_ADDR  = 7'h2A,
    parameter [7:0] CCC_RSTDAA   = 8'h07,
    parameter [7:0] CCC_SETAASA  = 8'h2A,
    parameter [7:0] CCC_SETDASA  = 8'h87
) (
    input  wire       rst_n,
    input  wire       scl,
    inout  wire       sda,
    input  wire [6:0] active_addr,

    output reg        rstdaa_pulse,
    output reg        setaasa_pulse,
    output reg        setdasa_valid,
    output reg [6:0]  setdasa_addr,
    output reg        transport_holdoff,
    output reg        ccc_seen,
    output reg [7:0]  last_ccc
);

    localparam [1:0] ST_IDLE = 2'd0;
    localparam [1:0] ST_ADDR = 2'd1;
    localparam [1:0] ST_ACK  = 2'd2;
    localparam [1:0] ST_DATA = 2'd3;

    localparam [2:0] ACK_NONE        = 3'd0;
    localparam [2:0] ACK_CCC_ADDR    = 3'd1;
    localparam [2:0] ACK_CCC_CODE    = 3'd2;
    localparam [2:0] ACK_DIRECT_ADDR = 3'd3;
    localparam [2:0] ACK_DIRECT_DATA = 3'd4;

    reg [1:0] state;
    reg [2:0] ack_context;
    reg [3:0] bit_pos;
    reg [7:0] shift_reg;
    reg [7:0] current_ccc;
    reg       ack_pending;
    reg       ack_drive_low;
    reg       sda_drive_low;
    reg       current_rw;
    reg       current_addr_is_ccc;
    reg       collecting_ccc_code;
    reg       collecting_direct_data;
    reg       pending_direct_ccc;
    reg       direct_target_match;

    wire [7:0] assembled_byte = {shift_reg[6:0], sda};
    wire       direct_addr_match = ((assembled_byte[7:1] == STATIC_ADDR) ||
                                    (assembled_byte[7:1] == active_addr));
    wire       setdasa_data_valid = (assembled_byte[0] == 1'b0) &&
                                    (assembled_byte[7:1] != 7'h00) &&
                                    (assembled_byte[7:1] != 7'h7E);

    assign sda = sda_drive_low ? 1'b0 : 1'bz;

    always @(negedge sda or negedge rst_n) begin
        if (!rst_n) begin
            state                 <= ST_IDLE;
            ack_context           <= ACK_NONE;
            bit_pos               <= 4'd0;
            shift_reg             <= 8'h00;
            current_ccc           <= 8'h00;
            ack_pending           <= 1'b0;
            ack_drive_low         <= 1'b0;
            sda_drive_low         <= 1'b0;
            current_rw            <= 1'b0;
            current_addr_is_ccc   <= 1'b0;
            collecting_ccc_code   <= 1'b0;
            collecting_direct_data<= 1'b0;
            pending_direct_ccc    <= 1'b0;
            direct_target_match   <= 1'b0;
            transport_holdoff     <= 1'b0;
            rstdaa_pulse          <= 1'b0;
            setaasa_pulse         <= 1'b0;
            setdasa_valid         <= 1'b0;
            setdasa_addr          <= 7'h00;
            ccc_seen              <= 1'b0;
            last_ccc              <= 8'h00;
        end else if (scl === 1'b1) begin
            state                 <= ST_ADDR;
            ack_context           <= ACK_NONE;
            bit_pos               <= 4'd0;
            shift_reg             <= 8'h00;
            ack_pending           <= 1'b0;
            ack_drive_low         <= 1'b0;
            sda_drive_low         <= 1'b0;
            current_rw            <= 1'b0;
            current_addr_is_ccc   <= 1'b0;
            collecting_ccc_code   <= 1'b0;
            collecting_direct_data<= 1'b0;
            direct_target_match   <= 1'b0;
            rstdaa_pulse          <= 1'b0;
            setaasa_pulse         <= 1'b0;
            setdasa_valid         <= 1'b0;
            ccc_seen              <= 1'b0;
        end
    end

    always @(posedge sda or negedge rst_n) begin
        if (!rst_n) begin
            state                 <= ST_IDLE;
            ack_context           <= ACK_NONE;
            bit_pos               <= 4'd0;
            shift_reg             <= 8'h00;
            current_ccc           <= 8'h00;
            ack_pending           <= 1'b0;
            ack_drive_low         <= 1'b0;
            sda_drive_low         <= 1'b0;
            current_rw            <= 1'b0;
            current_addr_is_ccc   <= 1'b0;
            collecting_ccc_code   <= 1'b0;
            collecting_direct_data<= 1'b0;
            pending_direct_ccc    <= 1'b0;
            direct_target_match   <= 1'b0;
            transport_holdoff     <= 1'b0;
            rstdaa_pulse          <= 1'b0;
            setaasa_pulse         <= 1'b0;
            setdasa_valid         <= 1'b0;
            ccc_seen              <= 1'b0;
        end else if (scl === 1'b1) begin
            state                 <= pending_direct_ccc ? ST_ADDR : ST_IDLE;
            ack_context           <= ACK_NONE;
            bit_pos               <= 4'd0;
            shift_reg             <= 8'h00;
            ack_pending           <= 1'b0;
            ack_drive_low         <= 1'b0;
            sda_drive_low         <= 1'b0;
            current_rw            <= 1'b0;
            current_addr_is_ccc   <= 1'b0;
            collecting_ccc_code   <= 1'b0;
            collecting_direct_data<= 1'b0;
            direct_target_match   <= 1'b0;
            rstdaa_pulse          <= 1'b0;
            setaasa_pulse         <= 1'b0;
            setdasa_valid         <= 1'b0;
            ccc_seen              <= 1'b0;
            if (!pending_direct_ccc) begin
                transport_holdoff <= 1'b0;
            end
        end
    end

    always @(negedge scl or negedge rst_n) begin
        if (!rst_n) begin
            sda_drive_low <= 1'b0;
        end else if (ack_pending) begin
            sda_drive_low <= ack_drive_low;
        end else begin
            sda_drive_low <= 1'b0;
        end
    end

    always @(posedge scl or negedge rst_n) begin
        if (!rst_n) begin
            state                 <= ST_IDLE;
            ack_context           <= ACK_NONE;
            bit_pos               <= 4'd0;
            shift_reg             <= 8'h00;
            current_ccc           <= 8'h00;
            ack_pending           <= 1'b0;
            ack_drive_low         <= 1'b0;
            current_rw            <= 1'b0;
            current_addr_is_ccc   <= 1'b0;
            collecting_ccc_code   <= 1'b0;
            collecting_direct_data<= 1'b0;
            pending_direct_ccc    <= 1'b0;
            direct_target_match   <= 1'b0;
            transport_holdoff     <= 1'b0;
            rstdaa_pulse          <= 1'b0;
            setaasa_pulse         <= 1'b0;
            setdasa_valid         <= 1'b0;
            setdasa_addr          <= 7'h00;
            ccc_seen              <= 1'b0;
            last_ccc              <= 8'h00;
        end else begin
            rstdaa_pulse  <= 1'b0;
            setaasa_pulse <= 1'b0;
            setdasa_valid <= 1'b0;
            ccc_seen      <= 1'b0;

            case (state)
                ST_ADDR: begin
                    shift_reg <= assembled_byte;
                    if (bit_pos == 4'd7) begin
                        current_rw          <= sda;
                        current_addr_is_ccc <= (!pending_direct_ccc &&
                                                ((assembled_byte & 8'hFE) == {CCC_ADDR, 1'b0}));
                        direct_target_match <= pending_direct_ccc && direct_addr_match;
                        ack_pending         <= 1'b1;
                        bit_pos             <= 4'd0;
                        state               <= ST_ACK;

                        if (pending_direct_ccc) begin
                            ack_context   <= ACK_DIRECT_ADDR;
                            ack_drive_low <= (current_ccc == CCC_SETDASA) &&
                                             !sda && direct_addr_match;
                        end else begin
                            ack_context   <= ACK_CCC_ADDR;
                            ack_drive_low <= ((assembled_byte & 8'hFE) == {CCC_ADDR, 1'b0}) && !sda;
                        end
                    end else begin
                        bit_pos <= bit_pos + 1'b1;
                    end
                end

                ST_ACK: begin
                    ack_pending <= 1'b0;

                    case (ack_context)
                        ACK_CCC_ADDR: begin
                            if (current_addr_is_ccc && !current_rw) begin
                                state               <= ST_DATA;
                                collecting_ccc_code <= 1'b1;
                                bit_pos             <= 4'd0;
                                shift_reg           <= 8'h00;
                            end else begin
                                state <= ST_IDLE;
                            end
                        end

                        ACK_CCC_CODE: begin
                            if (pending_direct_ccc) begin
                                state     <= ST_ADDR;
                                bit_pos   <= 4'd0;
                                shift_reg <= 8'h00;
                            end else begin
                                state <= ST_IDLE;
                            end
                        end

                        ACK_DIRECT_ADDR: begin
                            if ((current_ccc == CCC_SETDASA) && direct_target_match && !current_rw) begin
                                state                  <= ST_DATA;
                                collecting_direct_data <= 1'b1;
                                bit_pos                <= 4'd0;
                                shift_reg              <= 8'h00;
                            end else begin
                                state <= ST_IDLE;
                            end
                        end

                        ACK_DIRECT_DATA: begin
                            state <= ST_IDLE;
                        end

                        default: begin
                            state <= ST_IDLE;
                        end
                    endcase
                end

                ST_DATA: begin
                    shift_reg <= assembled_byte;
                    if (bit_pos == 4'd7) begin
                        ack_pending <= 1'b1;
                        bit_pos     <= 4'd0;
                        state       <= ST_ACK;

                        if (collecting_ccc_code) begin
                            current_ccc           <= assembled_byte;
                            last_ccc              <= assembled_byte;
                            ccc_seen              <= 1'b1;
                            collecting_ccc_code   <= 1'b0;
                            ack_context           <= ACK_CCC_CODE;
                            ack_drive_low         <= 1'b1;
                            pending_direct_ccc    <= (assembled_byte == CCC_SETDASA);
                            transport_holdoff     <= (assembled_byte == CCC_SETDASA);

                            if (assembled_byte == CCC_RSTDAA) begin
                                rstdaa_pulse <= 1'b1;
                            end
                            if (assembled_byte == CCC_SETAASA) begin
                                setaasa_pulse <= 1'b1;
                            end
                        end else if (collecting_direct_data) begin
                            collecting_direct_data <= 1'b0;
                            ack_context            <= ACK_DIRECT_DATA;
                            ack_drive_low          <= direct_target_match && setdasa_data_valid;

                            if ((current_ccc == CCC_SETDASA) &&
                                direct_target_match &&
                                setdasa_data_valid) begin
                                setdasa_valid      <= 1'b1;
                                setdasa_addr       <= assembled_byte[7:1];
                                pending_direct_ccc <= 1'b0;
                                transport_holdoff  <= 1'b0;
                            end
                        end
                    end else begin
                        bit_pos <= bit_pos + 1'b1;
                    end
                end

                default: begin
                    state <= ST_IDLE;
                end
            endcase
        end
    end
endmodule
