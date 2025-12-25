`timescale 1ns / 10ps
/* verilator coverage_off */

module tb_flex_counter ();

    localparam CLK_PERIOD = 10ns;

    logic clk, n_rst;
    logic clear;
    logic count_enable;
    logic [3:0] rollover_val;
    logic [3:0] count_out;
    logic rollover_flag;


    flex_counter dut (
        .clk(clk),
        .n_rst(n_rst),
        .clear(clear),
        .count_enable(count_enable),
        .rollover_val(rollover_val),
        .count_out(count_out),
        .rollover_flag(rollover_flag)
    );


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

    task check_counting;
        input [3:0] expected_count;
    begin
        @(posedge clk);
        if (count_out != expected_count)
            $display("Test failed! Expected: %b, Got: %b", expected_count, count_out);
        else
            $display("Test passed: count_out = %b", count_out);
    end
    endtask

    initial begin

        count_enable = 0;
        clear = 0;
        rollover_val = 4'b1011; 
        n_rst = 1;

        reset_dut;

        check_counting(4'b0000); 
        count_enable = 1;
        #20; 
        check_counting(4'b0001); 
        #20;
        check_counting(4'b0010); 
        #20;
        check_counting(4'b0011);
        #20;
        check_counting(4'b0100);
        #20;
        #20;
        #40;

        rollover_val = 4'b0011; 
        #20;
        check_counting(4'b0101);
        #40; 
        check_counting(4'b0001);

        count_enable = 0; 
        #30;
        check_counting(4'b0001); 
        count_enable = 1; 
        #20;
        check_counting(4'b0010); 


        count_enable = 1;
        clear = 1; 
        #20;
        check_counting(4'b0000); 
        clear = 0; 
        #20;
        check_counting(4'b0001); 

        $finish;
    end

    initial begin
        void'($system("mkdir -p waves"));
        $dumpfile("waves/tb_flex_counter.vcd");
        $dumpvars(0, tb_flex_counter);
    end
    
endmodule

/* verilator coverage_on */
