`timescale 1ns/10ps

module control_unit(
    input logic clk, n_rst,
    input logic data_valid, ready_send, last_block,
    input logic [6:0] last_block_invalid_bits,
    input logic local_hash_done,
    output logic ready_rcv,
    output logic [63:0] data_len,
    output logic second_block_flag, length512,
    output logic insrc, load, clear,
    output logic hash_valid
);

    typedef enum { 
        IDLE,
        RCV_DATA, 
        LOAD_RAW, 
        LOAD_EDGE, 
        LOAD_PREPROCESSED,
        HASH,
        FINAL_HASH,
        HASH_RESET
    } state_t;

    logic [1:0] flags, next_flags; // flags[0] = second_block_flag , flags[1] = length512
    logic [63:0] data_size, next_data_size;
    state_t state, next_state;

    always_ff @( posedge clk or negedge n_rst ) begin
        if(!n_rst) begin
            state <= IDLE;
            flags <= 2'b0;
            data_size <= 64'b0;
        end else begin
            state <= next_state;
            flags <= next_flags;
            data_size <= next_data_size;
        end
    end

    /* 
        IDLE transitions to RCV_DATA when data_valid goes high
        RCV_DATA stays in RCV_DATA until a full block is received or last_block is high
        LOAD_RAW transitions to HASH
        LOAD_EDGE transitions to HASH
        LOAD_PREPROCESSED transitions to FINAL_HASH
        HASH stays in HASH until local_hash_done is high
        FINAL_HASH transitions to HASH_RESET when local_hash_done and ready_send are high
        HASH_RESET transitions to IDLE
    */
    always_comb begin : NEXT_STATE_BLOCK
        next_state = state;
        
        case (state)
            IDLE: next_state = (data_valid)? RCV_DATA : IDLE ;
            RCV_DATA: begin
                if ((next_data_size) % 512 == 0 && !last_block) begin
                    next_state = LOAD_RAW;
                end else if (( ((next_data_size) % 512 >= 448) || ((next_data_size) % 512 == 0) )  && last_block && next_data_size != 0) begin
                    next_state = LOAD_EDGE;
                end else if (((next_data_size) % 512 < 448 && last_block) || flags[0]) begin
                    next_state = LOAD_PREPROCESSED;
                end else begin
                    next_state = RCV_DATA;
                end
            end
            LOAD_RAW: next_state = HASH;
            LOAD_EDGE: next_state = HASH;
            LOAD_PREPROCESSED: next_state = FINAL_HASH;
            HASH: next_state = (!local_hash_done)? HASH : (flags[0]) ? LOAD_PREPROCESSED : RCV_DATA;
            FINAL_HASH: next_state = (local_hash_done && ready_send)? HASH_RESET : FINAL_HASH; 
            HASH_RESET : next_state = IDLE;
        endcase
    end

    /*
        IDLE, HASH: all outputs low 
        RCV_DATA: ready_rcv = 1, data_len updated based on received data
        LOAD_RAW: load = 1
        LOAD_EDGE: load = 1, insrc = 1, second_block_flag and length512 set accordingly
        LOAD_PREPROCESSED: load = 1, insrc = 1
        FINAL_HASH: hash_valid = local_hash_done
        HASH_RESET: clear = 1, flags and data_size reset
    */
    always_comb begin : OUTPUT_BLOCK
        ready_rcv = 0;
        data_len = data_size;
        next_data_size = data_size;
        second_block_flag = flags[0];
        length512 = flags[1];
        next_flags = flags;
        insrc = 0; 
        load = 0;
        clear = 0;
        hash_valid = 0;

        case (state)
            RCV_DATA: begin
                ready_rcv = 1'b1;
                if (data_valid)
                    next_data_size = (last_block)? data_size + 64'd64 - 64'(last_block_invalid_bits) : data_size + 64'd64;
                else
                    next_data_size = data_size;
            end
            LOAD_RAW: load = 1'b1;
            LOAD_EDGE: begin
                load = 1'b1;
                insrc = 1'b1;
                next_flags[0] = 1'b1;
                next_flags[1] = (data_size % 512 == 0) ? 1'b1 : 1'b0;
            end
            LOAD_PREPROCESSED: begin
                load = 1'b1;
                insrc = 1'b1;
            end
            FINAL_HASH: hash_valid = local_hash_done;
            HASH_RESET: begin
                clear = 1'b1;
                next_flags = 2'b0;
                next_data_size = 64'b0;
            end
        endcase
    end

endmodule
