`timescale 1ns / 10ps
/* verilator lint_off ASCRANGE */
module message_scheduler (
    input  logic clk,
    input  logic n_rst,
    input  logic load,
    input  logic [0:15][31:0] data_in,
    output logic [31:0] data_out
);

logic [0:15][31:0] buffer, next_buffer;
logic [3:0] ptr, next_ptr;
logic [31:0] s0, s1, next_data_out;

always_ff @(posedge clk or negedge n_rst) begin
    if (!n_rst) begin
        buffer <= 0;
        ptr <= 4'b0;
        data_out <= 32'b0;
    end else begin
        buffer <= next_buffer;
        ptr <= next_ptr;
        data_out <= next_data_out;
    end
end

always_comb begin
    next_buffer = buffer;
    next_ptr = ptr;
    next_data_out = data_out;

    // Calculate s0 and s1 based on previous saved message words
    s0 = {buffer[(ptr + 1)  % 16][6:0] , buffer[(ptr + 1)  % 16][31:7] } ^
         {buffer[(ptr + 1)  % 16][17:0], buffer[(ptr + 1)  % 16][31:18]} ^
         (buffer[(ptr + 1)  % 16] >> 3);

    s1 = {buffer[(ptr + 14) % 16][16:0], buffer[(ptr + 14) % 16][31:17]} ^
         {buffer[(ptr + 14) % 16][18:0], buffer[(ptr + 14) % 16][31:19]} ^
         (buffer[(ptr + 14) % 16] >> 10);


    // Reset buffer and ptr on load, otherwise update buffer and ptr to calculate next message word
    if (load) begin
        next_buffer = data_in;
        next_ptr = 4'b0;
        next_data_out = data_in[0];
    end else begin
        next_buffer[ptr] = buffer[ptr] + s0 + buffer[(ptr + 9) % 16] + s1;
        next_data_out = buffer[(ptr+1) % 16];
        next_ptr = (ptr == 4'd15)? 4'b0 : ptr + 1'b1;
    end
end
/* verilator lint_on ASCRANGE */
endmodule
