`timescale 1ns / 10ps

/* verilator coverage_off */

module tb_buffer();

    localparam CLK_PERIOD = 10ns;

    logic clk, n_rst;
    logic [63:0] data_in;
    logic [255:0] hash, prev_hash;
    logic reset_hash, sample_hash, data_valid, data_rcv, clear;
    logic [511:0] data_out;

    /* verilator lint_off ASCRANGE */
    logic [0:15][63:0] test_data;
    /* verilator lint_on ASCRANGE */

    logic [255:0] init_hash_values;

    buffer dut (
        .clk(clk),
        .n_rst(n_rst),
        .hash(hash),
        .prev_hash(prev_hash),
        .reset_hash(reset_hash),
        .sample_hash(sample_hash),
        .data_out(data_out),
        .data_in(data_in),
        .data_valid(data_valid),
        .data_rcv(data_rcv),
        .clear(clear)
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

    task initialize_data;
    begin
        hash = '0;
        data_in = '0;
        reset_hash = 0;
        sample_hash = 0;
        data_valid = 0;
        data_rcv = 0;
        clear = 0;
    end
    endtask

    task check_buffer;
        input integer test_no;
    begin
        logic [511:0] data;
        case (test_no)
            1: data = {
                test_data[0],test_data[1],test_data[2],test_data[3],
                test_data[4],test_data[5],test_data[6],test_data[7]
            };
            2: data = {
                test_data[8],test_data[9],test_data[10],test_data[11],
                test_data[12],test_data[13],test_data[14],test_data[15]
            };
            default: data = '0;
        endcase

        if (data == data_out)
            $display("Test %d passed. data = %h", test_no, data);
        else begin
            $display("Test %d failed. Expected: %h, Got: %h", test_no, data, data_out);
        end

    end
    endtask

    initial begin

        reset_dut;

        initialize_data;

        test_data = {
            64'hABCDEF01ABCDEF01, 64'h0000000000000000, 64'h1010101010101010, 64'h0A1B2C3D4E5F0A1B,
            64'h1111111111111111, 64'hF00D1000F00D1000, 64'h0123456789ABCDEF, 64'hADDBAD00BADBABDA,
            64'h7346AA937BBAD700, 64'hFEDCBA9876543210, 64'hEEEEEEEEEEEEEEEE, 64'h0950374B03FCC93E,
            64'hAA118888EE111118, 64'h9F0567887CCC1000, 64'h0123456789ABCDEF, 64'hADDBAD00BADBABDA
        };

        // Data input tests

        // Test 1: data input without pause, test the latching functionality
        @(negedge clk);
        data_valid = 1;
        data_rcv = 1;
        for (int i = 0; i < 8; i++) begin
            data_in = test_data[i];
            @(negedge clk);
        end
        data_valid = 0;
        data_rcv = 0;
        @(negedge clk);

        check_buffer(1);

        repeat(5) @(posedge clk);
        check_buffer(1);

        // Test 2: data input is paused briefly after the second batch of 64 bits
        @(negedge clk);
        data_valid = 1;
        data_rcv = 1;
        for (int i = 8; i < 10; i++) begin
            data_in = test_data[i];
            @(negedge clk);
        end
        data_valid = 0; 
        data_rcv = 0;
        repeat(4) @(posedge clk); // simulate pause
        @(negedge clk);
        data_valid = 1; 
        data_rcv = 1;
        for (int i = 10; i < 16; i++) begin
            data_in = test_data[i];
            @(negedge clk);
        end
        data_valid = 0; 
        data_rcv = 0;
        @(negedge clk);

        check_buffer(2);

        // Hash input tests

        // Test 1: Latch the incoming hash value
        @(negedge clk);
        hash = {
            32'hAAAAAAAA, 32'hBBBBBBBB, 32'hCCCCCCCC, 32'hDDDDDDDD,
            32'hEEEEEEEE, 32'hFFFFFFFF, 32'h00000000, 32'h11111111
        };

        sample_hash = 1'b1;

        @(negedge clk);

        sample_hash = 1'b0;

        @(negedge clk);

        if (prev_hash == hash)
            $display("Hash test 1 passed");
        else
            $display("Hash test 1 failed, got %h", prev_hash);

        // Test 2: Reset the hash values back to the hash constants

        init_hash_values = {
            32'h6a09e667, 32'hbb67ae85, 32'h3c6ef372, 32'ha54ff53a,
            32'h510e527f, 32'h9b05688c, 32'h1f83d9ab, 32'h5be0cd19
        };

        reset_hash = 1'b1;

        @(negedge clk);

        reset_hash = 1'b0;
        
        @(negedge clk);

        if (prev_hash == init_hash_values)
            $display("Hash test 2 passed");
        else
            $display("Hash test 2 failed, got %h", prev_hash);

        $finish;
    end

    initial begin
        void'($system("mkdir -p waves"));
        $dumpfile("waves/tb_buffer.vcd");
        $dumpvars(0, tb_buffer);
    end

endmodule

/* verilator coverage_on */
