module fpga_wrapper (
    input  wire        clk,
    input  wire        n_rst,
    input  wire [63:0] data_in,
    input  wire        data_valid,
    input  wire        ready_send,
    input  wire        last_block,
    input  wire [5:0]  last_block_invalid_bits,
    output wire        ready_rcv,
    output reg  [7:0]  hash_out_byte,
    output reg         hash_byte_valid
);

    // Instantiate your SHA256 core
    wire [255:0] hash_value;
    wire         hash_valid;

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
        .hash_value(hash_value)
    );

    // Byte counter for serialization
    reg [4:0] byte_index; // 0..31 for 32 bytes (256 bits)

    always @(posedge clk or negedge n_rst) begin
        if (!n_rst) begin
            byte_index      <= 5'd0;
            hash_out_byte   <= 8'd0;
            hash_byte_valid <= 1'b0;
        end else begin
            if (hash_valid) begin
                // Output one byte per clock
                hash_out_byte   <= hash_value[byte_index*8 +: 8];
                hash_byte_valid <= 1'b1;
                byte_index      <= byte_index + 1'b1;
            end else begin
                hash_byte_valid <= 1'b0;
            end

            // Reset counter after sending all 32 bytes
            if (byte_index == 5'd31 && hash_valid)
                byte_index <= 5'd0;
        end
    end

endmodule
