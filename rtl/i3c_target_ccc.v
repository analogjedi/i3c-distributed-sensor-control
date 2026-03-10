`timescale 1ns/1ps

module i3c_target_ccc #(
    parameter [6:0]  CCC_ADDR     = 7'h7E,
    parameter [6:0]  STATIC_ADDR  = 7'h2A,
    parameter [7:0]  CCC_ENEC_BCAST = 8'h00,
    parameter [7:0]  CCC_DISEC_BCAST= 8'h01,
    parameter [7:0]  CCC_RSTDAA   = 8'h06,
    parameter [7:0]  CCC_ENTDAA   = 8'h07,
    parameter [7:0]  CCC_SETAASA  = 8'h2A,
    parameter [7:0]  CCC_ENEC_DIRECT = 8'h80,
    parameter [7:0]  CCC_DISEC_DIRECT= 8'h81,
    parameter [7:0]  CCC_GETPID   = 8'h8D,
    parameter [7:0]  CCC_GETBCR   = 8'h8E,
    parameter [7:0]  CCC_GETDCR   = 8'h8F,
    parameter [7:0]  CCC_SETDASA  = 8'h87,
    parameter [7:0]  TARGET_BCR   = 8'h01,
    parameter [7:0]  TARGET_DCR   = 8'h5A
) (
    input  wire       rst_n,
    input  wire       scl,
    inout  wire       sda,
    input  wire [6:0] active_addr,
    input  wire       dynamic_addr_valid,
    input  wire [47:0] provisional_id,

    output reg        rstdaa_pulse,
    output reg        setaasa_pulse,
    output reg        setdasa_valid,
    output reg [6:0]  setdasa_addr,
    output reg        entdaa_assign_valid,
    output reg [6:0]  entdaa_assign_addr,
    output reg        transport_holdoff,
    output reg [7:0]  event_enable_mask,
    output reg        ccc_seen,
    output reg [7:0]  last_ccc
);

    localparam [2:0] ST_IDLE     = 3'd0;
    localparam [2:0] ST_ADDR     = 3'd1;
    localparam [2:0] ST_ACK      = 3'd2;
    localparam [2:0] ST_DATA     = 3'd3;
    localparam [2:0] ST_READ     = 3'd4;
    localparam [2:0] ST_WAIT_STOP= 3'd5;

    localparam [2:0] ACK_NONE          = 3'd0;
    localparam [2:0] ACK_CCC_ADDR      = 3'd1;
    localparam [2:0] ACK_CCC_CODE      = 3'd2;
    localparam [2:0] ACK_DIRECT_ADDR   = 3'd3;
    localparam [2:0] ACK_DIRECT_DATA   = 3'd4;
    localparam [2:0] ACK_ENTDAA_ADDR   = 3'd5;
    localparam [2:0] ACK_ENTDAA_ASSIGN = 3'd6;
    localparam [2:0] ACK_BCAST_DATA    = 3'd7;

    localparam [2:0] READ_NONE   = 3'd0;
    localparam [2:0] READ_GETPID = 3'd1;
    localparam [2:0] READ_ENTDAA = 3'd2;
    localparam [2:0] READ_GETBCR = 3'd3;
    localparam [2:0] READ_GETDCR = 3'd4;

    reg [2:0] state;
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
    reg       collecting_broadcast_data;
    reg       collecting_entdaa_assign;
    reg       pending_direct_ccc;
    reg       pending_broadcast_data;
    reg       pending_entdaa;
    reg       entdaa_lost;
    reg       direct_target_match;
    reg [2:0] read_kind;
    reg [3:0] read_bit_pos;
    reg [3:0] read_byte_idx;
    reg [3:0] read_len;
    reg [7:0] read_shift;

    wire [7:0] assembled_byte = {shift_reg[6:0], sda};
    wire       direct_addr_match = ((assembled_byte[7:1] == STATIC_ADDR) ||
                                    (assembled_byte[7:1] == active_addr));
    wire       setdasa_data_valid = (assembled_byte[0] == 1'b0) &&
                                    (assembled_byte[7:1] != 7'h00) &&
                                    (assembled_byte[7:1] != 7'h7E);
    wire       entdaa_addr_valid = (assembled_byte[0] == 1'b0) &&
                                   (assembled_byte[7:1] != 7'h00) &&
                                   (assembled_byte[7:1] != 7'h7E);

    function [7:0] pid_byte;
        input [47:0] pid;
        input [2:0]  idx;
        begin
            case (idx)
                3'd0: pid_byte = pid[47:40];
                3'd1: pid_byte = pid[39:32];
                3'd2: pid_byte = pid[31:24];
                3'd3: pid_byte = pid[23:16];
                3'd4: pid_byte = pid[15:8];
                default: pid_byte = pid[7:0];
            endcase
        end
    endfunction

    function [7:0] read_byte_value;
        input [2:0]  kind;
        input [3:0]  idx;
        input [47:0] pid;
        begin
            case (kind)
                READ_GETPID: begin
                    read_byte_value = pid_byte(pid, idx[2:0]);
                end
                READ_GETBCR: begin
                    read_byte_value = TARGET_BCR;
                end
                READ_GETDCR: begin
                    read_byte_value = TARGET_DCR;
                end
                READ_ENTDAA: begin
                    case (idx)
                        4'd0: read_byte_value = pid_byte(pid, 3'd0);
                        4'd1: read_byte_value = pid_byte(pid, 3'd1);
                        4'd2: read_byte_value = pid_byte(pid, 3'd2);
                        4'd3: read_byte_value = pid_byte(pid, 3'd3);
                        4'd4: read_byte_value = pid_byte(pid, 3'd4);
                        4'd5: read_byte_value = pid_byte(pid, 3'd5);
                        4'd6: read_byte_value = TARGET_BCR;
                        default: read_byte_value = TARGET_DCR;
                    endcase
                end
                default: begin
                    read_byte_value = 8'h00;
                end
            endcase
        end
    endfunction

    assign sda = sda_drive_low ? 1'b0 : 1'bz;

    always @(negedge sda or negedge rst_n) begin
        if (!rst_n) begin
            state                   <= ST_IDLE;
            ack_context             <= ACK_NONE;
            bit_pos                 <= 4'd0;
            shift_reg               <= 8'h00;
            current_ccc             <= 8'h00;
            ack_pending             <= 1'b0;
            ack_drive_low           <= 1'b0;
            sda_drive_low           <= 1'b0;
            current_rw              <= 1'b0;
            current_addr_is_ccc     <= 1'b0;
            collecting_ccc_code     <= 1'b0;
            collecting_direct_data  <= 1'b0;
            collecting_broadcast_data <= 1'b0;
            collecting_entdaa_assign<= 1'b0;
            pending_direct_ccc      <= 1'b0;
            pending_broadcast_data  <= 1'b0;
            pending_entdaa          <= 1'b0;
            entdaa_lost            <= 1'b0;
            direct_target_match     <= 1'b0;
            read_kind               <= READ_NONE;
            read_bit_pos            <= 4'd0;
            read_byte_idx           <= 4'd0;
            read_len                <= 4'd0;
            read_shift              <= 8'h00;
            transport_holdoff       <= 1'b0;
            event_enable_mask       <= 8'h00;
            rstdaa_pulse            <= 1'b0;
            setaasa_pulse           <= 1'b0;
            setdasa_valid           <= 1'b0;
            setdasa_addr            <= 7'h00;
            entdaa_assign_valid     <= 1'b0;
            entdaa_assign_addr      <= 7'h00;
            ccc_seen                <= 1'b0;
            last_ccc                <= 8'h00;
        end else if (scl === 1'b1) begin
            if (entdaa_lost) begin
                pending_entdaa    <= 1'b0;
                transport_holdoff <= 1'b0;
            end
            state                   <= ST_ADDR;
            ack_context             <= ACK_NONE;
            bit_pos                 <= 4'd0;
            shift_reg               <= 8'h00;
            ack_pending             <= 1'b0;
            ack_drive_low           <= 1'b0;
            sda_drive_low           <= 1'b0;
            current_rw              <= 1'b0;
            current_addr_is_ccc     <= 1'b0;
            collecting_ccc_code     <= 1'b0;
            collecting_direct_data  <= 1'b0;
            collecting_broadcast_data <= 1'b0;
            collecting_entdaa_assign<= 1'b0;
            direct_target_match     <= 1'b0;
            entdaa_lost            <= 1'b0;
            rstdaa_pulse            <= 1'b0;
            setaasa_pulse           <= 1'b0;
            setdasa_valid           <= 1'b0;
            entdaa_assign_valid     <= 1'b0;
            ccc_seen                <= 1'b0;
        end
    end

    // This model preserves pending direct/ENTDAA state across the SDA-high
    // transition that precedes repeated-start on the simplified simulation bus.
    always @(posedge sda or negedge rst_n) begin
        if (!rst_n) begin
            state                   <= ST_IDLE;
            ack_context             <= ACK_NONE;
            bit_pos                 <= 4'd0;
            shift_reg               <= 8'h00;
            ack_pending             <= 1'b0;
            ack_drive_low           <= 1'b0;
            sda_drive_low           <= 1'b0;
            current_rw              <= 1'b0;
            current_addr_is_ccc     <= 1'b0;
            collecting_ccc_code     <= 1'b0;
            collecting_direct_data  <= 1'b0;
            collecting_broadcast_data <= 1'b0;
            collecting_entdaa_assign<= 1'b0;
            direct_target_match     <= 1'b0;
            read_kind               <= READ_NONE;
            read_bit_pos            <= 4'd0;
            read_byte_idx           <= 4'd0;
            read_len                <= 4'd0;
            rstdaa_pulse            <= 1'b0;
            setaasa_pulse           <= 1'b0;
            setdasa_valid           <= 1'b0;
            entdaa_assign_valid     <= 1'b0;
            ccc_seen                <= 1'b0;
            transport_holdoff       <= 1'b0;
            pending_direct_ccc      <= 1'b0;
            pending_broadcast_data  <= 1'b0;
            pending_entdaa          <= 1'b0;
            entdaa_lost            <= 1'b0;
        end else if (scl === 1'b1) begin
            state                   <= (pending_direct_ccc || pending_entdaa) ? ST_ADDR : ST_IDLE;
            ack_context             <= ACK_NONE;
            bit_pos                 <= 4'd0;
            shift_reg               <= 8'h00;
            ack_pending             <= 1'b0;
            ack_drive_low           <= 1'b0;
            sda_drive_low           <= 1'b0;
            current_rw              <= 1'b0;
            current_addr_is_ccc     <= 1'b0;
            collecting_ccc_code     <= 1'b0;
            collecting_direct_data  <= 1'b0;
            collecting_entdaa_assign<= 1'b0;
            direct_target_match     <= 1'b0;
            entdaa_lost            <= 1'b0;
            read_kind               <= READ_NONE;
            read_bit_pos            <= 4'd0;
            read_byte_idx           <= 4'd0;
            read_len                <= 4'd0;
            rstdaa_pulse            <= 1'b0;
            setaasa_pulse           <= 1'b0;
            setdasa_valid           <= 1'b0;
            entdaa_assign_valid     <= 1'b0;
            ccc_seen                <= 1'b0;
            if (!(pending_direct_ccc || pending_entdaa)) begin
                transport_holdoff   <= 1'b0;
            end
        end
    end

    always @(negedge scl or negedge rst_n) begin
        if (!rst_n) begin
            sda_drive_low <= 1'b0;
        end else if (ack_pending) begin
            sda_drive_low <= ack_drive_low;
        end else if ((state == ST_READ) && (read_bit_pos < 4'd8)) begin
            sda_drive_low <= ~read_shift[7 - read_bit_pos[2:0]];
        end else begin
            sda_drive_low <= 1'b0;
        end
    end

    always @(posedge scl or negedge rst_n) begin
        if (!rst_n) begin
            state                   <= ST_IDLE;
            ack_context             <= ACK_NONE;
            bit_pos                 <= 4'd0;
            shift_reg               <= 8'h00;
            current_ccc             <= 8'h00;
            ack_pending             <= 1'b0;
            ack_drive_low           <= 1'b0;
            current_rw              <= 1'b0;
            current_addr_is_ccc     <= 1'b0;
            collecting_ccc_code     <= 1'b0;
            collecting_direct_data  <= 1'b0;
            collecting_broadcast_data <= 1'b0;
            collecting_entdaa_assign<= 1'b0;
            pending_direct_ccc      <= 1'b0;
            pending_broadcast_data  <= 1'b0;
            pending_entdaa          <= 1'b0;
            entdaa_lost            <= 1'b0;
            direct_target_match     <= 1'b0;
            read_kind               <= READ_NONE;
            read_bit_pos            <= 4'd0;
            read_byte_idx           <= 4'd0;
            read_len                <= 4'd0;
            read_shift              <= 8'h00;
            transport_holdoff       <= 1'b0;
            event_enable_mask       <= 8'h00;
            rstdaa_pulse            <= 1'b0;
            setaasa_pulse           <= 1'b0;
            setdasa_valid           <= 1'b0;
            setdasa_addr            <= 7'h00;
            entdaa_assign_valid     <= 1'b0;
            entdaa_assign_addr      <= 7'h00;
            ccc_seen                <= 1'b0;
            last_ccc                <= 8'h00;
        end else begin
            rstdaa_pulse        <= 1'b0;
            setaasa_pulse       <= 1'b0;
            setdasa_valid       <= 1'b0;
            entdaa_assign_valid <= 1'b0;
            ccc_seen            <= 1'b0;

            case (state)
                ST_ADDR: begin
                    shift_reg <= assembled_byte;
                    if (bit_pos == 4'd7) begin
                        current_rw          <= sda;
                        current_addr_is_ccc <= (!pending_direct_ccc && !pending_entdaa &&
                                                ((assembled_byte & 8'hFE) == {CCC_ADDR, 1'b0}));
                        direct_target_match <= pending_direct_ccc && direct_addr_match;
                        ack_pending         <= 1'b1;
                        bit_pos             <= 4'd0;
                        state               <= ST_ACK;

                        if (pending_entdaa && (assembled_byte == {CCC_ADDR, 1'b1})) begin
                            ack_context   <= ACK_ENTDAA_ADDR;
                            ack_drive_low <= !dynamic_addr_valid;
                        end else if (pending_entdaa &&
                                     ((assembled_byte & 8'hFE) == {CCC_ADDR, 1'b0})) begin
                            pending_entdaa    <= 1'b0;
                            transport_holdoff <= 1'b0;
                            current_addr_is_ccc <= 1'b1;
                            ack_context       <= ACK_CCC_ADDR;
                            ack_drive_low     <= !sda;
                        end else if (pending_direct_ccc) begin
                            ack_context   <= ACK_DIRECT_ADDR;
                            ack_drive_low <= direct_addr_match &&
                                             (((current_ccc == CCC_SETDASA) && !sda) ||
                                              ((current_ccc == CCC_ENEC_DIRECT) && !sda) ||
                                              ((current_ccc == CCC_DISEC_DIRECT) && !sda) ||
                                              ((current_ccc == CCC_GETPID) && sda) ||
                                              ((current_ccc == CCC_GETBCR) && sda) ||
                                              ((current_ccc == CCC_GETDCR) && sda));
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
                            if (pending_direct_ccc || pending_entdaa) begin
                                state     <= ST_ADDR;
                                bit_pos   <= 4'd0;
                                shift_reg <= 8'h00;
                            end else if (pending_broadcast_data) begin
                                state                   <= ST_DATA;
                                collecting_broadcast_data <= 1'b1;
                                bit_pos                 <= 4'd0;
                                shift_reg               <= 8'h00;
                            end else begin
                                state <= ST_IDLE;
                            end
                        end

                        ACK_DIRECT_ADDR: begin
                            if (((current_ccc == CCC_SETDASA) ||
                                 (current_ccc == CCC_ENEC_DIRECT) ||
                                 (current_ccc == CCC_DISEC_DIRECT)) &&
                                direct_target_match && !current_rw) begin
                                state                  <= ST_DATA;
                                collecting_direct_data <= 1'b1;
                                bit_pos                <= 4'd0;
                                shift_reg              <= 8'h00;
                            end else if ((current_ccc == CCC_GETPID) && direct_target_match && current_rw) begin
                                state        <= ST_READ;
                                read_kind    <= READ_GETPID;
                                read_byte_idx<= 4'd0;
                                read_bit_pos <= 4'd0;
                                read_len     <= 4'd6;
                                read_shift   <= pid_byte(provisional_id, 3'd0);
                            end else if ((current_ccc == CCC_GETBCR) && direct_target_match && current_rw) begin
                                state        <= ST_READ;
                                read_kind    <= READ_GETBCR;
                                read_byte_idx<= 4'd0;
                                read_bit_pos <= 4'd0;
                                read_len     <= 4'd1;
                                read_shift   <= TARGET_BCR;
                            end else if ((current_ccc == CCC_GETDCR) && direct_target_match && current_rw) begin
                                state        <= ST_READ;
                                read_kind    <= READ_GETDCR;
                                read_byte_idx<= 4'd0;
                                read_bit_pos <= 4'd0;
                                read_len     <= 4'd1;
                                read_shift   <= TARGET_DCR;
                            end else begin
                                state <= ST_IDLE;
                            end
                        end

                        ACK_DIRECT_DATA: begin
                            state <= ST_IDLE;
                        end

                        ACK_BCAST_DATA: begin
                            state <= ST_IDLE;
                        end

                        ACK_ENTDAA_ADDR: begin
                            if (!dynamic_addr_valid && !entdaa_lost) begin
                                state        <= ST_READ;
                                read_kind    <= READ_ENTDAA;
                                read_byte_idx<= 4'd0;
                                read_bit_pos <= 4'd0;
                                read_len     <= 4'd8;
                                read_shift   <= pid_byte(provisional_id, 3'd0);
                            end else begin
                                state <= ST_IDLE;
                            end
                        end

                        ACK_ENTDAA_ASSIGN: begin
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

                            if (assembled_byte == CCC_RSTDAA) begin
                                rstdaa_pulse      <= 1'b1;
                            end
                            if (assembled_byte == CCC_SETAASA) begin
                                setaasa_pulse     <= 1'b1;
                            end
                            if ((assembled_byte == CCC_SETDASA) ||
                                (assembled_byte == CCC_ENEC_DIRECT) ||
                                (assembled_byte == CCC_DISEC_DIRECT) ||
                                (assembled_byte == CCC_GETPID) ||
                                (assembled_byte == CCC_GETBCR) ||
                                (assembled_byte == CCC_GETDCR)) begin
                                pending_direct_ccc<= 1'b1;
                                transport_holdoff <= 1'b1;
                            end
                            if ((assembled_byte == CCC_ENEC_BCAST) ||
                                (assembled_byte == CCC_DISEC_BCAST)) begin
                                pending_broadcast_data <= 1'b1;
                                transport_holdoff      <= 1'b1;
                            end
                            if ((assembled_byte == CCC_ENTDAA) && !dynamic_addr_valid) begin
                                pending_entdaa    <= 1'b1;
                                transport_holdoff <= 1'b1;
                            end
                        end else if (collecting_direct_data) begin
                            collecting_direct_data <= 1'b0;
                            ack_context            <= ACK_DIRECT_DATA;
                            ack_drive_low          <= direct_target_match &&
                                                      (((current_ccc == CCC_SETDASA) && setdasa_data_valid) ||
                                                       (current_ccc == CCC_ENEC_DIRECT) ||
                                                       (current_ccc == CCC_DISEC_DIRECT));

                            if (direct_target_match) begin
                                if ((current_ccc == CCC_SETDASA) && setdasa_data_valid) begin
                                    setdasa_valid      <= 1'b1;
                                    setdasa_addr       <= assembled_byte[7:1];
                                    pending_direct_ccc <= 1'b0;
                                    transport_holdoff  <= 1'b0;
                                end else if (current_ccc == CCC_ENEC_DIRECT) begin
                                    event_enable_mask  <= event_enable_mask | assembled_byte;
                                    pending_direct_ccc <= 1'b0;
                                    transport_holdoff  <= 1'b0;
                                end else if (current_ccc == CCC_DISEC_DIRECT) begin
                                    event_enable_mask  <= event_enable_mask & ~assembled_byte;
                                    pending_direct_ccc <= 1'b0;
                                    transport_holdoff  <= 1'b0;
                                end
                            end
                        end else if (collecting_broadcast_data) begin
                            collecting_broadcast_data <= 1'b0;
                            pending_broadcast_data    <= 1'b0;
                            ack_context               <= ACK_BCAST_DATA;
                            ack_drive_low             <= 1'b1;
                            transport_holdoff         <= 1'b0;

                            if (current_ccc == CCC_ENEC_BCAST) begin
                                event_enable_mask <= event_enable_mask | assembled_byte;
                            end else if (current_ccc == CCC_DISEC_BCAST) begin
                                event_enable_mask <= event_enable_mask & ~assembled_byte;
                            end
                        end else if (collecting_entdaa_assign) begin
                            collecting_entdaa_assign <= 1'b0;
                            ack_context              <= ACK_ENTDAA_ASSIGN;
                            ack_drive_low            <= entdaa_addr_valid;

                            if (entdaa_addr_valid) begin
                                entdaa_assign_valid <= 1'b1;
                                entdaa_assign_addr  <= assembled_byte[7:1];
                                pending_entdaa      <= 1'b0;
                                transport_holdoff   <= 1'b0;
                            end
                        end
                    end else begin
                        bit_pos <= bit_pos + 1'b1;
                    end
                end

                ST_READ: begin
                    if (read_bit_pos < 4'd8) begin
                        if ((read_kind == READ_ENTDAA) &&
                            read_shift[7 - read_bit_pos[2:0]] &&
                            (sda == 1'b0)) begin
                            state       <= ST_WAIT_STOP;
                            entdaa_lost <= 1'b1;
                            read_kind   <= READ_NONE;
                            read_len    <= 4'd0;
                            read_bit_pos<= 4'd0;
                        end else if (read_bit_pos < 4'd7) begin
                            read_bit_pos <= read_bit_pos + 1'b1;
                        end else begin
                            read_bit_pos <= 4'd8;
                        end
                    end else begin
                        if ((read_byte_idx + 1'b1) < read_len) begin
                            read_byte_idx <= read_byte_idx + 1'b1;
                            read_shift    <= read_byte_value(read_kind, read_byte_idx + 1'b1, provisional_id);
                            read_bit_pos  <= 4'd0;
                        end else begin
                            read_bit_pos <= 4'd0;
                            if (read_kind == READ_ENTDAA) begin
                                state                   <= ST_DATA;
                                collecting_entdaa_assign<= 1'b1;
                                bit_pos                 <= 4'd0;
                                shift_reg               <= 8'h00;
                            end else begin
                                state              <= ST_IDLE;
                                pending_direct_ccc <= 1'b0;
                                transport_holdoff  <= 1'b0;
                            end
                            read_kind <= READ_NONE;
                            read_len  <= 4'd0;
                        end
                    end
                end

                ST_WAIT_STOP: begin
                    // Another target won ENTDAA arbitration for this cycle.
                    // Stay quiet until the controller issues a new START.
                end

                default: begin
                    state <= ST_IDLE;
                end
            endcase
        end
    end
endmodule
