`timescale 1ns / 10ps

module flex_counter #(
    parameter SIZE = 4,
    parameter RESET_ROLLOVER = 0,
    parameter INCREMENT_SIZE = 1
    ) (
    input logic clk,
    input logic n_rst,
    input logic clear,
    input logic count_enable,
    input logic [SIZE-1 : 0] rollover_val,
    output logic [SIZE-1 : 0] count_out,
    output logic rollover_flag
);

logic [SIZE-1 : 0] next_count, reset_value;
logic next_rollover_flag, reset_rollover_flag;

assign reset_value = (RESET_ROLLOVER) ? rollover_val : 'b0;
assign reset_rollover_flag = (RESET_ROLLOVER) ? 1'b1 : 1'b0;

always_comb begin
    if (clear) begin
        next_count = 'b0;
        next_rollover_flag = 0;             
    end 
    else if (count_enable) begin
        if (count_out >= rollover_val) begin
            next_count = 'b1;
        end
        else begin
            next_count = count_out + INCREMENT_SIZE;           
        end
        if (count_out == rollover_val - 1) begin
            next_rollover_flag = 1;
        end else begin
            next_rollover_flag = 0;  
        end  
    end 
    else begin
        next_count = count_out;          
        next_rollover_flag = rollover_flag;               
    end
end

always_ff @(posedge clk or negedge n_rst) begin 
    if (!n_rst) begin
        rollover_flag <= reset_rollover_flag; 
        count_out <= reset_value;
    end               
    else begin
        count_out <= next_count;
        rollover_flag <= next_rollover_flag; 
    end       
end

endmodule
