`timescale 1ns / 10ps

module hash_engine (
    input logic clk,
    input logic n_rst,
    input logic load, clear_hash,
    input logic [511:0] message_block,
    input logic [255:0] prev_hash,
    output logic [255:0] hash_out,
    output logic local_hash_done
);

    logic [15:0][31:0] init_message_words;
    logic count_enable, rollover_flag;
    logic [6:0] message_count;
    logic [31:0] message_word;

    assign local_hash_done = rollover_flag ;
    assign count_enable = ~rollover_flag ;

    assign init_message_words = {
        message_block[511:480], message_block[479:448], message_block[447:416], message_block[415:384],
        message_block[383:352], message_block[351:320], message_block[319:288], message_block[287:256],
        message_block[255:224], message_block[223:192], message_block[191:160], message_block[159:128],
        message_block[127:96] , message_block[95:64]  , message_block[63:32]  , message_block[31:0]
    };

    // count is set from 0 to 64
    // 0 to 63 for processing message words, 64 to stop the compression cycle.
    // To start a new compression cycle, load signal should be asserted to clear the counter.
    flex_counter #(.SIZE(7), .RESET_ROLLOVER(1)) message_counter (
        .clk(clk),
        .n_rst(n_rst),
        .clear(load),
        .count_enable(count_enable),
        .rollover_val(7'd64),
        .count_out(message_count),
        .rollover_flag(rollover_flag)
    );

    // Circular Buffer that incrementaly calculates and generates message words from initial 16 words
    // output one message word at a time on each clock cycle
    message_scheduler message_sched (
        .clk(clk),
        .n_rst(n_rst),
        .load(load),
        .data_in(init_message_words),
        .data_out(message_word)
    );

    // Core compression module that performs SHA-256 compression function
    // updates hash registers based on current message word, previous hash values, and count
    compression_core compress_core (
        .clk(clk),
        .n_rst(n_rst),
        .message_word(message_word),
        .clear_hash(clear_hash),
        .count(message_count),
        .hash_out(hash_out),
        .prev_hash(prev_hash),
        .load(load)
    );

endmodule
