`timescale 1ns / 10ps

module compression_core (
    input logic clk,
    input logic n_rst,
    input logic clear_hash, load,
    input logic [31:0] message_word,
    input logic [6:0] count,
    input logic [255:0] prev_hash,
    output logic [255:0] hash_out
);
    /* verilator lint_off ASCRANGE */
    logic [0:7][31:0] init_hash_values, hash_reg, next_hash_reg;
    logic [0:63][31:0] round_constants;
    /* verilator lint_on ASCRANGE */
    logic [31:0] s0, s1, ch, maj, temp1, temp2;

    // Initial hash values (H[0..7])
    assign init_hash_values = {
            32'h6a09e667, 32'hbb67ae85, 32'h3c6ef372, 32'ha54ff53a,
            32'h510e527f, 32'h9b05688c, 32'h1f83d9ab, 32'h5be0cd19
    };

    // Round Constants (K[0..63])
    assign round_constants = {
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

    assign hash_out = {hash_reg[0] , hash_reg[1], hash_reg[2], hash_reg[3], hash_reg[4], hash_reg[5], hash_reg[6], hash_reg[7]};

    always_ff @(posedge clk or negedge n_rst) begin
        if (!n_rst) begin
            hash_reg <= init_hash_values;
        end else begin
            hash_reg <= next_hash_reg;
        end
    end

    always_comb begin
        next_hash_reg = hash_reg;

        // Start of the compression loop
        // Calculate the necessary values for the SHA-256 compression function
        s1 = {hash_reg[4][5:0], hash_reg[4][31:6]} ^ {hash_reg[4][10:0], hash_reg[4][31:11]} ^ {hash_reg[4][24:0], hash_reg[4][31:25]};
        ch = (hash_reg[4] & hash_reg[5]) ^ (~hash_reg[4]& hash_reg[6]);
        temp1 = hash_reg[7] + s1 + ch + round_constants[count] + message_word;
        s0 = {hash_reg[0][1:0], hash_reg[0][31:2]} ^ {hash_reg[0][12:0], hash_reg[0][31:13]} ^ {hash_reg[0][21:0], hash_reg[0][31:22]};
        maj = (hash_reg[0] & hash_reg[1]) ^ (hash_reg[0] & hash_reg[2]) ^ (hash_reg[1] & hash_reg[2]);
        temp2 = s0 + maj;

        // Update hash registers or reset based on control signals and current hash cycle count
        // At the end of 64 rounds, add the compressed values to the previous hash values
        if (clear_hash) begin
            next_hash_reg = init_hash_values;
        end
        else if (count <= 63 && ~load) begin
            next_hash_reg[7] = hash_reg[6];
            next_hash_reg[6] = hash_reg[5];
            next_hash_reg[5] = hash_reg[4];
            next_hash_reg[4] = hash_reg[3] + temp1;
            next_hash_reg[3] = hash_reg[2];
            next_hash_reg[2] = hash_reg[1];
            next_hash_reg[1] = hash_reg[0];
            next_hash_reg[0] = temp1 + temp2;

            if (count == 63) begin
                next_hash_reg[0] = prev_hash[255:224] + next_hash_reg[0];
                next_hash_reg[1] = prev_hash[223:192] + next_hash_reg[1];
                next_hash_reg[2] = prev_hash[191:160] + next_hash_reg[2];
                next_hash_reg[3] = prev_hash[159:128] + next_hash_reg[3];
                next_hash_reg[4] = prev_hash[127:96] + next_hash_reg[4];
                next_hash_reg[5] = prev_hash[95:64] + next_hash_reg[5];
                next_hash_reg[6] = prev_hash[63:32] + next_hash_reg[6];
                next_hash_reg[7] = prev_hash[31:0] + next_hash_reg[7];
                
            end
        end
    end
    
endmodule
