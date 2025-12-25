`timescale 1ns / 10ps
/* verilator coverage_off */
/* verilator lint_off ASCRANGE */
module tb_message_scheduler ();

    localparam CLK_PERIOD = 10ns;

    /* verilator lint_off UNUSEDSIGNAL */
    logic clk, n_rst, load;
    logic [0:15][31:0] data_in;
    logic [0:63][31:0] expected_data_out;
    logic [31:0] data_out;
    logic [31:0] expected_word_out;
    logic tb_check_pulse;
    /* verilator lint_on UNUSEDSIGNAL */

    message_scheduler dut (
        .clk(clk),
        .n_rst(n_rst),
        .load(load),
        .data_in(data_in),
        .data_out(data_out)
    );

    // always @(posedge clk)
    // $display("T=%0t | load=%b | data_out=%h", $time, load, data_out);

    always begin
        clk = 0;
        #(CLK_PERIOD / 2.0);
        clk = 1;
        #(CLK_PERIOD / 2.0);
    end

    task reset_dut;
    begin
        n_rst = 0;
        @(posedge clk);
        @(posedge clk); 
        n_rst = 1;
        @(negedge clk);
    end
    endtask

    task compute_message_words;
        input  [0:15][31:0] msg_block;
        output [0:63][31:0] w;
    begin
        logic [31:0] s0, s1;
        integer i;

        for (i = 0; i < 16; i = i + 1) begin
            w[i] = msg_block[i];
        end

        for (i = 16; i < 64; i = i + 1) begin
            s0 = {w[i-15][6:0], w[i-15][31:7]} ^ {w[i-15][17:0], w[i-15][31:18]} ^ (w[i-15] >> 3);
            s1 = {w[i-2][16:0], w[i-2][31:17]} ^ {w[i-2][18:0], w[i-2][31:19]} ^ (w[i-2] >> 10);
            w[i] = w[i-16] + s0 + w[i-7] + s1;
        end

    end
    endtask

    task check_word;
        input [31:0] expected_word;
        input [31:0] actual_word;
        input integer index;
    begin
        /* verilator lint_off UNUSEDSIGNAL */
        logic mismatch;
        /* verilator lint_on UNUSEDSIGNAL */
        
        mismatch = (expected_word !== actual_word);
        if (mismatch) begin
            $display("Index : %d . Word mismatch. Expected: %h, Got: %h", index, expected_word, actual_word);
        end else begin
            $display("Index : %d . Word match: %h", index, actual_word);
        end
    end
    endtask


    initial begin
        reset_dut; // Resets DUT, ends at a negedge
        expected_word_out = 32'b0;

        // Test 1 abc
        data_in = '{
            32'h61626380, 32'h00000000, 32'h00000000, 32'h00000000,
            32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000,
            32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000,
            32'h00000000, 32'h00000000, 32'h00000000, 32'h00000018
        };
        
        compute_message_words(data_in, expected_data_out);
        
        // At negedge, set up inputs for the *next* posedge
        load = 1;
        @(negedge clk);

        // At this negedge, de-assert load for the *next* cycle
        load = 0;
        
        // Loop 64 times
        for (int i = 0; i < 64; i++) begin
            @(posedge clk); 
            tb_check_pulse = 1'b1;
            expected_word_out = expected_data_out[i];
            check_word(expected_word_out, data_out, i);
            @(negedge clk);
            tb_check_pulse = 1'b0; 
        end

        $finish;
    end



    initial begin
        void'($system("mkdir -p waves"));
        $dumpfile("waves/tb_message_scheduler.vcd");
        $dumpvars(0, tb_message_scheduler);
    end
    
endmodule
/* verilator lint_on ASCRANGE */
/* verilator coverage_on */
