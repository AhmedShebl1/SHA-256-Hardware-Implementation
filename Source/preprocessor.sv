`timescale 1ns/10ps

module preprocessor (
    input logic [511:0] data, 
    input logic [63:0] data_len,
    input logic second_block_flag, length512,
    output logic [511:0] preprocessed_block
);

    /* verilator lint_off UNUSEDSIGNAL */
    logic [511:0] masked_data;
    /* verilator lint_on UNUSEDSIGNAL */
    logic [8:0] valid_bits;
    logic [511:0] data_mask;
    logic [511:0] one_bit_mask;

    always_comb begin
        /* verilator lint_off WIDTHTRUNC */
        valid_bits = data_len % 512 ;
        data_mask = 'b0;
        one_bit_mask = 'b0;
        /* verilator lint_off WIDTHTRUNC */
        if (valid_bits == 0 && data_len != 0) begin
            // Last block to be processed is 512 bits. First preprocessed block is the entire data. 
            masked_data = data;
        end else begin
            data_mask = {512{1'b1}} << (512 - valid_bits);
            one_bit_mask = 512'b1 << (511 - valid_bits);
            masked_data = (data & data_mask) | one_bit_mask;
        end
        // Check if this is the first or second processed block.
        if (second_block_flag) begin
            // Processed block is 1024 bits, first preprocessed block has already been hashed. Need to send next 512 block.
            // if the length of the block to be processed is 448, then the 1 has been already placed in the first preprocessed block
            // if the length of the block to be processed is 512, then place the one as the first bit
            preprocessed_block = (length512)? {1'b1, 447'b0, data_len} : {448'b0, data_len} ;
        end else if (valid_bits >= 448 || valid_bits == 0) begin
            // First block of edge case (1024 preprocessed block size)
            preprocessed_block = masked_data;
        end else begin
            // preprocessed block is a single 512 bit block
            preprocessed_block = {masked_data[511:64] , data_len};
        end
    end

endmodule
