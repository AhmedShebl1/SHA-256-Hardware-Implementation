`timescale 1ns/10ps

module sha256_top(
    input logic clk, n_rst,
    input logic [63:0] data_in,
    input logic data_valid, ready_send, last_block,
    input logic [6:0] last_block_invalid_bits,
    output logic ready_rcv, hash_valid,
    output logic [255:0] hash_value
);

    logic [63:0] data_len;
    logic local_hash_done, second_block_flag, length512;
    logic insrc, load, clear, data_rcv_cu;
    logic [511:0] message_block, preprocessed_block, data_out;
    logic [255:0] hash, prev_hash;

    assign ready_rcv = data_rcv_cu;
    assign hash_value = hash;
    assign message_block = (insrc) ? preprocessed_block : data_out; 

    control_unit cu (
        .clk(clk),
        .n_rst(n_rst),
        .data_valid(data_valid),
        .ready_send(ready_send),
        .last_block(last_block),
        .last_block_invalid_bits(last_block_invalid_bits),
        .local_hash_done(local_hash_done),
        .ready_rcv(data_rcv_cu),
        .data_len(data_len),
        .second_block_flag(second_block_flag),
        .length512(length512),
        .insrc(insrc),
        .load(load),
        .clear(clear),
        .hash_valid(hash_valid)
    );

    buffer buff (
        .clk(clk),
        .n_rst(n_rst),
        .data_in(data_in),
        .hash(hash),
        .sample_hash(local_hash_done),
        .data_valid(data_valid),
        .data_rcv(data_rcv_cu),
        .clear(clear),
        .data_out(data_out),
        .prev_hash(prev_hash)
    );

    preprocessor preproc (
        .data(data_out),
        .data_len(data_len),
        .second_block_flag(second_block_flag),
        .length512(length512),
        .preprocessed_block(preprocessed_block)
    );

    hash_engine he (
        .clk(clk),
        .n_rst(n_rst),
        .load(load),
        .clear_hash(clear),
        .message_block(message_block),
        .prev_hash(prev_hash),
        .hash_out(hash),
        .local_hash_done(local_hash_done)
    );


endmodule
