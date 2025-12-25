`timescale 1ns / 10ps
/* verilator coverage_off */

module tb_hash_engine ();

    localparam CLK_PERIOD = 10ns;

    logic clk, n_rst, load, clear_hash, local_hash_done;
    logic [511:0] message_block;
    logic [255:0] hash_out, expected_hash, prev_hash;

    /* verilator lint_off ASCRANGE */
    logic [0:7][31:0] init_hash_values;
    logic [0:63][31:0] round_constants;
    /* verilator lint_on ASCRANGE */

    // Initialize constants
    initial begin
        // Initial SHA-256 hash values (H0–H7)
        init_hash_values = '{
            32'h6a09e667, 32'hbb67ae85, 32'h3c6ef372, 32'ha54ff53a,
            32'h510e527f, 32'h9b05688c, 32'h1f83d9ab, 32'h5be0cd19
        };

        // SHA-256 round constants (K0–K63)
        round_constants = '{
            32'h428a2f98, 32'h71374491, 32'hb5c0fbcf, 32'he9b5dba5,
            32'h3956c25b, 32'h59f111f1, 32'h923f82a4, 32'hab1c5ed5,
            32'hd807aa98, 32'h12835b01, 32'h243185be, 32'h550c7dc3,
            32'h72be5d74, 32'h80deb1fe, 32'h9bdc06a7, 32'hc19bf174,
            32'he49b69c1, 32'hefbe4786, 32'h0fc19dc6, 32'h240ca1cc,
            32'h2de92c6f, 32'h4a7484aa, 32'h5cb0a9dc, 32'h76f988da,
            32'h983e5152, 32'ha831c66d, 32'hb00327c8, 32'hbf597fc7,
            32'hc6e00bf3, 32'hd5a79147, 32'h06ca6351, 32'h14292967,
            32'h27b70a85, 32'h2e1b2138, 32'h4d2c6dfc, 32'h53380d13,
            32'h650a7354, 32'h766a0abb, 32'h81c2c92e, 32'h92722c85,
            32'ha2bfe8a1, 32'ha81a664b, 32'hc24b8b70, 32'hc76c51a3,
            32'hd192e819, 32'hd6990624, 32'hf40e3585, 32'h106aa070,
            32'h19a4c116, 32'h1e376c08, 32'h2748774c, 32'h34b0bcb5,
            32'h391c0cb3, 32'h4ed8aa4a, 32'h5b9cca4f, 32'h682e6ff3,
            32'h748f82ee, 32'h78a5636f, 32'h84c87814, 32'h8cc70208,
            32'h90befffa, 32'ha4506ceb, 32'hbef9a3f7, 32'hc67178f2
        };
    end

    // DUT instance
    hash_engine dut (
        .clk(clk),
        .n_rst(n_rst),
        .load(load),
        .message_block(message_block),
        .hash_out(hash_out),
        .clear_hash(clear_hash),
        .prev_hash(prev_hash),
        .local_hash_done(local_hash_done)
    );

    // Clock generation
    always begin
        clk = 0; #(CLK_PERIOD / 2);
        clk = 1; #(CLK_PERIOD / 2);
    end

    // Reset the DUT 
    task reset_dut;
    begin
        n_rst = 0;
        @(posedge clk);
        @(posedge clk);
        n_rst = 1;
        @(negedge clk);
    end
    endtask


    // Compute golden hash for a single block
    task compute_hash(
        input  [511:0] msg_block,
        /* verilator lint_off ASCRANGE */
        inout  [0:7][31:0] h_state,
        /* verilator lint_on ASCRANGE */
        output [255:0] hash_expectation
    );
        /* verilator lint_off ASCRANGE */
        logic [0:63][31:0] w;
        logic [0:7][31:0] h, h_in_copy;
        /* verilator lint_on ASCRANGE */
        logic [31:0] s0, s1, ss0, ss1, ch, maj, temp1, temp2;
        integer i;

        // Message schedule initialization
        for (i = 0; i < 16; i++)
            w[i] = msg_block[511 - i*32 -: 32];

        // Initialize working variables
        h = h_state;
        h_in_copy = h_state;

        // Extend the first 16 words into 64 words
        for (i = 16; i < 64; i++) begin
            s0 = {w[i-15][6:0], w[i-15][31:7]} ^
                 {w[i-15][17:0], w[i-15][31:18]} ^
                 (w[i-15] >> 3);
            s1 = {w[i-2][16:0], w[i-2][31:17]} ^
                 {w[i-2][18:0], w[i-2][31:19]} ^
                 (w[i-2] >> 10);
            w[i] = w[i-16] + s0 + w[i-7] + s1;
        end

        // Compression function main loop
        for (i = 0; i < 64; i++) begin
            ss1 = {h[4][5:0], h[4][31:6]} ^
                  {h[4][10:0], h[4][31:11]} ^
                  {h[4][24:0], h[4][31:25]};
            ch = (h[4] & h[5]) ^ (~h[4] & h[6]);
            temp1 = h[7] + ss1 + ch + round_constants[i] + w[i];

            ss0 = {h[0][1:0], h[0][31:2]} ^
                  {h[0][12:0], h[0][31:13]} ^
                  {h[0][21:0], h[0][31:22]};
            maj = (h[0] & h[1]) ^ (h[0] & h[2]) ^ (h[1] & h[2]);
            temp2 = ss0 + maj;

            h[7] = h[6];
            h[6] = h[5];
            h[5] = h[4];
            h[4] = h[3] + temp1;
            h[3] = h[2];
            h[2] = h[1];
            h[1] = h[0];
            h[0] = temp1 + temp2;
        end

        // Compute updated hash values
        for (i = 0; i < 8; i++)
            h_state[i] = h_in_copy[i] + h[i];

        // Pack 256-bit final hash
        hash_expectation = {
            h_state[0], h_state[1], h_state[2], h_state[3],
            h_state[4], h_state[5], h_state[6], h_state[7]
        };
    endtask


    // --- Compare expected vs. DUT output ---
    task check_hash(input [255:0] expected, input [255:0] result);
    begin
        if (result !== expected)
            $display("Test failed. Expected: %h, Got: %h", expected, result);
        else
            $display("Test passed. hash_out = %h", result);
    end
    endtask

    // Main Test Sequence
    initial begin
        /* verilator lint_off UNUSEDSIGNAL */
        /* verilator lint_off ASCRANGE */
        logic [0:7][31:0] golden_h_state;
        /* verilator lint_on ASCRANGE */
        /* verilator lint_on UNUSEDSIGNAL */

        prev_hash = {
            init_hash_values[0], init_hash_values[1], init_hash_values[2], init_hash_values[3],
            init_hash_values[4], init_hash_values[5], init_hash_values[6], init_hash_values[7]
        };

        reset_dut;

        @(posedge clk);
        clear_hash = 1;
        @(posedge clk);
        clear_hash = 0;

        // Test 1: "abc"
        message_block = {
            32'h61626380, 32'h00000000, 32'h00000000, 32'h00000000,
            32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000,
            32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000,
            32'h00000000, 32'h00000000, 32'h00000000, 32'h00000018
        };
        golden_h_state = init_hash_values;
        compute_hash(message_block, golden_h_state, expected_hash);
        #10; load = 1; @(posedge clk); load = 0;
        repeat (64) @(posedge clk);
        check_hash(expected_hash, hash_out);
        @(posedge clk); clear_hash = 1; @(posedge clk); clear_hash = 0;

        // Test 2: Empty string ""
        message_block = {
            32'h80000000, 32'h00000000, 32'h00000000, 32'h00000000,
            32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000,
            32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000,
            32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000
        };
        golden_h_state = init_hash_values;
        compute_hash(message_block, golden_h_state, expected_hash);
        #10; load = 1; @(posedge clk); load = 0;
        repeat (64) @(posedge clk);
        check_hash(expected_hash, hash_out);
        @(posedge clk); clear_hash = 1; @(posedge clk); clear_hash = 0;

        // Test 3: "The quick brown fox jumps over the lazy dog"
        // + asserting load for more than one clock cycle (probably wont be the case in design)
        message_block = {
            32'h54686520, 32'h71756963, 32'h6b206272, 32'h6f776e20,
            32'h666f7820, 32'h6a756d70, 32'h73206f76, 32'h65722074,
            32'h6865206c, 32'h617a7920, 32'h646f6780, 32'h00000000,
            32'h00000000, 32'h00000000, 32'h00000000, 32'h00000158
        };
        golden_h_state = init_hash_values;
        compute_hash(message_block, golden_h_state, expected_hash);
        #10; load = 1; @(posedge clk); @(posedge clk); load = 0;
        repeat (64) @(posedge clk);
        check_hash(expected_hash, hash_out);
        @(posedge clk); clear_hash = 1; @(posedge clk); clear_hash = 0;

        // Test 4: All Ones
        // + checking that hash value is retained until we clear hash 
        // (added 4 extra cycles after hash was complete then checked the hash)
        message_block = {
            32'hFFFFFFFF, 32'hFFFFFFFF, 32'hFFFFFFFF, 32'hFFFFFFFF,
            32'hFFFFFFFF, 32'hFFFFFFFF, 32'hFFFFFFFF, 32'hFFFFFFFF,
            32'hFFFFFFFF, 32'hFFFFFFFF, 32'hFFFFFFFF, 32'hFFFFFFFF,
            32'hFFFFFFFF, 32'hFFFFFFFF, 32'hFFFFFFFF, 32'hFFFFFFF8
        };
        golden_h_state = init_hash_values;
        compute_hash(message_block, golden_h_state, expected_hash);
        #10; load = 1; @(posedge clk); load = 0;
        repeat (68) @(posedge clk);
        check_hash(expected_hash, hash_out);
        @(posedge clk); clear_hash = 1; @(posedge clk); clear_hash = 0;

        // Test 5: Two-block message
        // "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz1234aaa333444787878JKJKjk"
        golden_h_state = init_hash_values;

        // Block 1
        message_block = {
            32'h41424344, 32'h45464748, 32'h494A4B4C, 32'h4D4E4F50,
            32'h51525354, 32'h55565758, 32'h595A6162, 32'h63646566,
            32'h6768696A, 32'h6B6C6D6E, 32'h6F707172, 32'h73747576,
            32'h7778797A, 32'h31323334, 32'h61616133, 32'h33333434
        };
        compute_hash(message_block, golden_h_state, expected_hash);

        // Block 2
        message_block = {
            32'h34373837, 32'h3837384A, 32'h4B4A4B6A, 32'h6B800000,
            32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000,
            32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000,
            32'h00000000, 32'h00000000, 32'h00000000, 32'h00000268
        };
        compute_hash(message_block, golden_h_state, expected_hash);

        // --- DUT Execution ---
        // Block 1
        message_block = {
            32'h41424344, 32'h45464748, 32'h494A4B4C, 32'h4D4E4F50,
            32'h51525354, 32'h55565758, 32'h595A6162, 32'h63646566,
            32'h6768696A, 32'h6B6C6D6E, 32'h6F707172, 32'h73747576,
            32'h7778797A, 32'h31323334, 32'h61616133, 32'h33333434
        };
        #10; load = 1; @(posedge clk); load = 0;
        repeat (64) @(posedge clk);
        prev_hash = hash_out;

        // Block 2
        message_block = {
            32'h34373837, 32'h3837384A, 32'h4B4A4B6A, 32'h6B800000,
            32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000,
            32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000,
            32'h00000000, 32'h00000000, 32'h00000000, 32'h00000268
        };
        #10; load = 1; @(posedge clk); load = 0;
        repeat (64) @(posedge clk);

        // Verify
        check_hash(expected_hash, hash_out);

        $finish;
    end

    initial begin
        void'($system("mkdir -p waves"));
        $dumpfile("waves/tb_hash_engine.vcd");
        $dumpvars(0, tb_hash_engine);
    end

endmodule

/* verilator coverage_on */
