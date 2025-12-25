`timescale 1ns/10ps
/* verilator coverage_off */
module tb_preprocessor ();

    localparam DELAY = 10ns;

    logic [63:0] data_len;
    logic second_block_flag, length512;
    logic [511:0] data, preprocessed_block;

    logic [1023:0] golden_output;
    string test_string;
    byte test_bytes[64];

    preprocessor dut (
        .data_len(data_len),
        .second_block_flag(second_block_flag),
        .length512(length512),
        .preprocessed_block(preprocessed_block),
        .data(data)
    );

    task preprocess_data;
        input string str;
    begin
        longint str_len;
        byte str_bytes[128];

        str_len = str.len() * 8;
        golden_output = '0;

        foreach (str[i]) begin
            str_bytes[i] = str[i];
        end

        golden_output = {>>{str_bytes}};

        /* verilator lint_off WIDTHTRUNC */
        golden_output[1023 - str_len] = 1'b1;
        /* verilator lint_on WIDTHTRUNC */

        if(str_len < 448) begin
            golden_output[575:512] = str_len;
        end else begin     
            golden_output[63:0] = str_len;
        end
    end
    endtask

    task initialize_inputs;
    begin
        data_len = '0;
        second_block_flag = 0;
        length512 = 0;
        data = '0;
    end
    endtask

    task set_data;
        input string s;
    begin

        test_bytes = '{default: 8'h00};

        foreach (s[i]) begin
            test_bytes[i] = s[i];
        end

        data = {>>{test_bytes}};
    end
    endtask

    task check_data;
    begin

        /* verilator lint_off UNUSEDSIGNAL */
        logic check_pulse, check_mismatch;
        /* verilator lint_off UNUSEDSIGNAL */
        logic [511:0] block;

        check_pulse = 1'b1;
        check_mismatch = 1'b0;

        block = (second_block_flag)? golden_output[511:0] : golden_output [1023:512];

        if (block == preprocessed_block)
            $display("Test passed. data = %h", block);
        else begin
            $display("Test failed. Expected: %h, Got: %h", block, preprocessed_block);
            check_mismatch = 1'b1;
        end

        #1ns; 
        check_pulse = 1'b0;
    end
    endtask

    initial begin

        initialize_inputs;
        #DELAY;

        // Test 1: Data batch is less than 448 bits 
        // In this case the preprocessed block is 512 bits
        test_string = "hello world";
        set_data(test_string); preprocess_data(test_string);
        data_len = test_string.len() * 8;
        #DELAY;
        check_data;

        // Test 2: Data is exactly 448 bits
        // In this case the preprocessed block is 1024 with the 1 placed in the first 512 block
        test_string = "This string is 448 bits long to test the 448-bit case!  ";
        set_data(test_string); preprocess_data(test_string);
        data_len = test_string.len() * 8;
        #DELAY;
        check_data;
        second_block_flag = 1'b1;
        #DELAY;
        check_data;
        second_block_flag = 1'b0;

        // Test 3: Data is between 448 and 512 bits
        // Similar to the previous case , the preprocessed block is 1024 with the 1 placed in the first 512 block
        test_string = "This string is exactly 62 bytes long to test padding case 2.";
        set_data(test_string); preprocess_data(test_string);
        data_len = test_string.len() * 8;
        #DELAY;
        check_data;
        second_block_flag = 1'b1;
        #DELAY;
        check_data;
        second_block_flag = 1'b0;

        // Test 4: Data is exactly 512 bits
        // In this case the preprocessed block is 1024 with the 1 placed in the second 512 block
        test_string = "This string is 64 bytes a full block forcing a new padding block";
        set_data(test_string); preprocess_data(test_string);
        data_len = test_string.len() * 8;
        length512 = 1'b1;
        #DELAY;
        check_data;
        second_block_flag = 1'b1;
        #DELAY;
        check_data;
        second_block_flag = 1'b0;

        $finish;
    end

    
    initial begin
        void'($system("mkdir -p waves"));
        $dumpfile("waves/tb_preprocessor.vcd");
        $dumpvars(0, tb_preprocessor);
    end

endmodule
/* verilator coverage_on */
