`timescale 1ns / 10ps

module buffer(
    input  logic clk, n_rst,
    input  logic [63:0] data_in,
    input  logic [255:0] hash,
    input  logic clear, sample_hash, data_valid, data_rcv,
    output logic [511:0] data_out,
    output logic [255:0] prev_hash
);
    logic [255:0] init_hash_values = {
        32'h6a09e667, 32'hbb67ae85, 32'h3c6ef372, 32'ha54ff53a,
        32'h510e527f, 32'h9b05688c, 32'h1f83d9ab, 32'h5be0cd19
    };

    logic [255:0] hash_buffer, next_hash_buffer;
    /* verilator lint_off ASCRANGE */
    logic [0:2] ptr, next_ptr;
    logic [0:7][63:0] input_buffer, next_input_buffer;
    /* verilator lint_on ASCRANGE */

    always_ff @(posedge clk or negedge n_rst) begin
        if (!n_rst) begin
            hash_buffer <= init_hash_values;
            input_buffer <= '0;
            ptr <= '0;
        end else begin
            hash_buffer <= next_hash_buffer;
            input_buffer <= next_input_buffer;
            ptr <= next_ptr;
        end
    end

    always_comb begin

        next_input_buffer = input_buffer;

        // Set outputs
        data_out = {
                input_buffer[0], input_buffer[1], input_buffer[2],input_buffer[3], 
                input_buffer[4], input_buffer[5], input_buffer[6], input_buffer[7]
        };
        prev_hash = hash_buffer;

        // Next hash buffer logic
        // Samples on sample_hash (local_hash_done) signal, resets to initial hash values on clear signal
        if (clear) begin
            next_hash_buffer = init_hash_values;
        end else if (sample_hash) begin
            next_hash_buffer = hash;
        end else begin
            next_hash_buffer = hash_buffer;
        end

        // Next input buffer logic
        // Writes data_in to input_buffer at position ptr when data_valid and data_rcv are high
        // Resets input_buffer and ptr on clear signal
        if (data_valid && data_rcv) begin
            next_input_buffer[ptr] = data_in;
            next_ptr = (ptr == 3'd7) ? 3'b0 : ptr + 1'b1;
        end else begin
            next_input_buffer = (clear)? '0 : input_buffer;
            next_ptr = (clear)? 3'b0 : ptr;
        end
    end

endmodule
