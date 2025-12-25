`timescale 1ns/10ps
/* verilator coverage_off */

`include "./Testbench/sha256_golden_model.sv"

module tb_sha256_top ();

    localparam CLK_PERIOD = 10ns;

    logic clk, n_rst;
    logic [63:0] data_in;
    logic data_valid, ready_send, last_block;
    logic [6:0] last_block_invalid_bits;
    logic ready_rcv, hash_valid;
    logic [255:0] dut_hash, golden_hash;

    sha256_top dut (
        .clk(clk),
        .n_rst(n_rst),
        .data_in(data_in),
        .data_valid(data_valid),
        .ready_send(ready_send),
        .last_block(last_block),
        .last_block_invalid_bits(last_block_invalid_bits),
        .ready_rcv(ready_rcv),
        .hash_valid(hash_valid),
        .hash_value(dut_hash)
    );

    always begin
        clk = 0;
        #(CLK_PERIOD/ 2.0);
        clk = 1;
        #(CLK_PERIOD/ 2.0);
    end

    task reset_dut;
    begin
        n_rst = 0;
        data_valid = 0;
        last_block = 0;
        ready_send = 0;
        @(posedge clk);
        @(posedge clk);
        n_rst = 1;
        @(negedge clk);
    end
    endtask

    task initialize_data;
    begin
        data_in = '0;
        data_valid = 0;
        ready_send = 0;
        last_block = 0;
        last_block_invalid_bits = '0;
    end
    endtask

    task compare_hash;
        input string test_name;
    begin
        if (dut_hash == golden_hash) begin
            $display("✅ %s PASSED. Hash: %h", test_name, dut_hash);
        end else begin
            $display("❌ %s FAILED!", test_name);
            $display("Expected (Golden): %h", golden_hash);
            $display("Got (DUT): %h", dut_hash);
        end
    end
    endtask

    task pass_input(input string str);
        byte   message[];
        int    total_bytes;
        int    num_chunks;
        int    base_idx;
        int    valid_bits_last_chunk;
        logic [6:0] invalid_bits_calc;

        // --- Convert string to bytes ---
        total_bytes = str.len();

        // empty string case
        if (str.len() == 0) begin
            // For empty message, send a single "last-block" with 64 invalid bits.
            @(negedge clk);
            data_valid = 1;
            last_block = 1;
            last_block_invalid_bits = 7'd64;
            data_in = 64'h0;

            @(negedge clk);
            @(negedge clk);

            data_valid = 0;
            last_block = 0;
            last_block_invalid_bits = 0;

            // Wait for hashing to complete
            while (!hash_valid) @(posedge clk);
            return;
        end

        message = new[total_bytes];
        for (int i = 0; i < total_bytes; i++)
            message[i] = str[i];

        num_chunks = (total_bytes + 7) / 8;

        valid_bits_last_chunk = (total_bytes * 8) % 64;
        if (valid_bits_last_chunk == 0 && total_bytes > 0)
            invalid_bits_calc = 0;
        else
            invalid_bits_calc = 7'(64 - valid_bits_last_chunk);

        // --- Start transaction ---
        data_valid = 1'b1;          // assert data_valid immediately to kick CU out of IDLE

        for (int i = 0; i < num_chunks; i++) begin

            // Wait until CU is ready to receive this chunk
            while (!ready_rcv) @(posedge clk);

            // Drive control signals BEFORE the posedge
            last_block = (i == num_chunks - 1);
            if (last_block)
                last_block_invalid_bits = invalid_bits_calc;

            // Build data word
            data_in = 64'h0;
            base_idx = i * 8;
            for (int j = 0; j < 8; j++) begin
                if (base_idx + j < total_bytes)
                    data_in[(7-j)*8 +: 8] = message[base_idx + j];
            end

            // Hold stable for **one rising edge** so DUT can sample
            @(posedge clk);
        end

        // Deassert data_valid after CU leaves receive state
        data_valid = 0;
        while (ready_rcv) @(posedge clk);

        // Clear last-block signals
        last_block = 0;
        last_block_invalid_bits = 7'h0;

        // Wait for hash
        while (!hash_valid) @(posedge clk);
    endtask




    task pass_input_with_pause;
        input string str;
    begin
        byte   message[];
        int    total_bytes;
        int    num_chunks;
        int    pause_at_chunk;
        int    valid_bits;
        int    base_idx;
        
        total_bytes = str.len();
        message = new[total_bytes];
        for (int i = 0; i < total_bytes; i++) message[i] = str[i];
        num_chunks = (total_bytes + 7) / 8;
        
        pause_at_chunk = 3;

        @(negedge clk);
        data_valid = 1'b1;

        for (int i = 0; i < num_chunks; i++) begin
            if (i == pause_at_chunk) begin
                $display("... Pausing data stream ...");
                data_valid = 1'b0;
                repeat(10) @(negedge clk);
                $display("... Resuming data stream ...");
                data_valid = 1'b1;
            end
            
            while (!ready_rcv) begin
                @(negedge clk);
            end

            last_block = (i == num_chunks - 1);
            if (last_block) begin
                 valid_bits = (total_bytes * 8) % 64;
                 if (valid_bits == 0) valid_bits = 64;
                 last_block_invalid_bits = 7'(64 - valid_bits);
            end

            data_in = 64'h0;
            base_idx = i * 8;
            for (int j = 0; j < 8; j++) begin
                if (base_idx + j < total_bytes) begin
                    data_in[ (7-j)*8 +: 8 ] = message[base_idx + j];
                end
            end

            @(negedge clk);
        end

        data_valid = 1'b0;
        last_block = 1'b0;
        
        while (!hash_valid) @(negedge clk);
        @(posedge clk);
    end
    endtask
    

    initial begin
        string test_string;

        reset_dut;
        initialize_data;

        // // Test 1 : String is 11 bytes (<= 448 bits)
        test_string = "hello world";
        compute_hash(test_string, golden_hash);
        pass_input(test_string);
        compare_hash("Test 1: 'hello world'");
        ready_send = 1'b1;
        @(posedge clk);
        ready_send = 1'b0;
        repeat(3) @(posedge clk);

        // // Test 2 : String is 58 bytes ( 448 < str < 512)
        test_string = "This string is exactly 58 bytes long to test edge case 1 .";
        compute_hash(test_string, golden_hash);
        pass_input(test_string);
        compare_hash("Test 2: 58 bytes");
        ready_send = 1'b1;
        @(posedge clk);
        ready_send = 1'b0;
        repeat(3) @(posedge clk);

        // // Test 3: String is exactly 64 bytes/ 512 bits 
        test_string = "This string is exactly 64 bytes long to test the 2nd edge case .";
        compute_hash(test_string, golden_hash);
        pass_input(test_string);
        compare_hash("Test 3: 64 bytes");
        ready_send = 1'b1;
        @(posedge clk);
        ready_send = 1'b0;
        repeat(3) @(posedge clk);

        // Test 4: String is 96 bytes (str > 512 bits)
        test_string = "This testcase will test how the hashing device performs when the input is larger than one block.";
        compute_hash(test_string, golden_hash);
        pass_input(test_string);
        compare_hash("Test 4: 96 bytes");
        ready_send = 1'b1;
        @(posedge clk);
        ready_send = 1'b0;
        repeat(3) @(posedge clk);

        // // Test 5: Testing pausing (de-asserting data_valid)
        test_string = "This string will test the sender's pauses";
        compute_hash(test_string, golden_hash);
        pass_input_with_pause(test_string);
        compare_hash("Test 5: Pause test");
        ready_send = 1'b1;
        @(posedge clk);
        ready_send = 1'b0;
        repeat(3) @(posedge clk);

        $display("\n--- Custom tests complete ---");
        $display("\n--- Beginning NIST test vectors ---\n");

        // NIST TEST 0: Empty string ("")
        test_string = "";
        compute_hash(test_string, golden_hash);
        pass_input(test_string);
        compare_hash("NIST Test 0: Empty String");
        ready_send = 1'b1; @(posedge clk); ready_send = 1'b0; repeat(3) @(posedge clk);

        // NIST TEST 1: "abc"
        test_string = "abc";
        compute_hash(test_string, golden_hash);
        pass_input(test_string);
        compare_hash("NIST Test 1: 'abc'");
        ready_send = 1'b1; @(posedge clk); ready_send = 1'b0; repeat(3) @(posedge clk);

        // NIST TEST 2: Multi-block known vector
        // "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"
        test_string =
            "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq";
        compute_hash(test_string, golden_hash);
        pass_input(test_string);
        compare_hash("NIST Test 2: Multi-block known vector");
        ready_send = 1'b1; @(posedge clk); ready_send = 1'b0; repeat(3) @(posedge clk);

        // NIST TEST 3: 55 bytes
        // Edge case: padding fits in same block (440 bits)---
        test_string = 
            "1234567890123456789012345678901234567890123456789012345"; // 55 bytes
        compute_hash(test_string, golden_hash);
        pass_input(test_string);
        compare_hash("NIST Test 3: 55-byte edge case");
        ready_send = 1'b1; @(posedge clk); ready_send = 1'b0; repeat(3) @(posedge clk);

        // NIST TEST 4: 56 bytes
        // Edge case: padding spills into next block (exact 448 bits)
        test_string =
            "12345678901234567890123456789012345678901234567890123456"; // 56 bytes
        compute_hash(test_string, golden_hash);
        pass_input(test_string);
        compare_hash("NIST Test 4: 56-byte edge case");
        ready_send = 1'b1; @(posedge clk); ready_send = 1'b0; repeat(3) @(posedge clk);

        // NIST TEST 5: 1 million 'a' characters
        // Stress test — checks buffer/FSM endurance
        test_string = {1000000{"a"}}; // 1,000,000 'a'
        compute_hash(test_string, golden_hash);
        pass_input(test_string);
        compare_hash("NIST Test 5: One million 'a'");
        ready_send = 1'b1; @(posedge clk); ready_send = 1'b0; repeat(3) @(posedge clk);

        // NIST TEST 6: Bit-level tests (1 bit message)
        // Single byte with only MSB = 1 (0x80), 1 bit long
        test_string = "\x80"; // golden model uses bit length = 1 (not 8)
        compute_hash(test_string, golden_hash); // if golden accepts bit-length param
        pass_input(test_string);
        compare_hash("NIST Test 6: Single-bit test (0x80, 1 bit)");
        ready_send = 1'b1; @(posedge clk); ready_send = 1'b0; repeat(3) @(posedge clk);

        $display("\n--- All tests complete ---");
        $finish;
    end

    initial begin
        void'($system("mkdir -p waves"));
        $dumpfile("waves/tb_sha256_top.vcd");
        $dumpvars(0, tb_sha256_top);
    end

endmodule
/* verilator coverage_on */
