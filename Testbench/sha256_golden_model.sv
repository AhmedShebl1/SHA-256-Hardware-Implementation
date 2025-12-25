// This golden model was written using AI (gemini 2.5) to speed up the process of debugging

/*
 * SHA-256 Golden Model Implementation (FIPS 180-4)
 * Fixed for Verilator: All declarations moved to top of scopes.
 */

/* verilator lint_off VARHIDDEN */


// SHA-256 Initial Hash Values (H)
const logic [31:0] H[8] = '{
    32'h6a09e667, 32'hbb67ae85, 32'h3c6ef372, 32'ha54ff53a,
    32'h510e527f, 32'h9b05688c, 32'h1f83d9ab, 32'h5be0cd19
};

// SHA-256 Round Constants (K)
const logic [31:0] K[64] = '{
    32'h428a2f98, 32'h71374491, 32'hb5c0fbcf, 32'he9b5dba5, 32'h3956c25b, 32'h59f111f1, 32'h923f82a4, 32'hab1c5ed5,
    32'hd807aa98, 32'h12835b01, 32'h243185be, 32'h550c7dc3, 32'h72be5d74, 32'h80deb1fe, 32'h9bdc06a7, 32'hc19bf174,
    32'he49b69c1, 32'hefbe4786, 32'h0fc19dc6, 32'h240ca1cc, 32'h2de92c6f, 32'h4a7484aa, 32'h5cb0a9dc, 32'h76f988da,
    32'h983e5152, 32'ha831c66d, 32'hb00327c8, 32'hbf597fc7, 32'hc6e00bf3, 32'hd5a79147, 32'h06ca6351, 32'h14292967,
    32'h27b70a85, 32'h2e1b2138, 32'h4d2c6dfc, 32'h53380d13, 32'h650a7354, 32'h766a0abb, 32'h81c2c92e, 32'h92722c85,
    32'ha2bfe8a1, 32'ha81a664b, 32'hc24b8b70, 32'hc76c51a3, 32'hd192e819, 32'hd6990624, 32'hf40e3585, 32'h106aa070,
    32'h19a4c116, 32'h1e376c08, 32'h2748774c, 32'h34b0bcb5, 32'h391c0cb3, 32'h4ed8aa4a, 32'h5b9cca4f, 32'h682e6ff3,
    32'h748f82ee, 32'h78a5636f, 32'h84c87814, 32'h8cc70208, 32'h90befffa, 32'ha4506ceb, 32'hbef9a3f7, 32'hc67178f2
};

// Helper function for 32-bit Rotate Right
function automatic logic [31:0] rotr(input logic [31:0] x, input integer y);
    return (x >> y) | (x << (32 - y));
endfunction

function automatic logic [31:0] S0(input logic [31:0] x);
    return rotr(x, 2) ^ rotr(x, 13) ^ rotr(x, 22);
endfunction

function automatic logic [31:0] S1(input logic [31:0] x);
    return rotr(x, 6) ^ rotr(x, 11) ^ rotr(x, 25);
endfunction

function automatic logic [31:0] s0(input logic [31:0] x);
    return rotr(x, 7) ^ rotr(x, 18) ^ (x >> 3);
endfunction

function automatic logic [31:0] s1(input logic [31:0] x);
    return rotr(x, 17) ^ rotr(x, 19) ^ (x >> 10);
endfunction

// --- FIX: typed inputs for Ch and Maj (all 32-bit) ---
function automatic logic [31:0] Ch(
    input logic [31:0] x,
    input logic [31:0] y,
    input logic [31:0] z
);
    return (x & y) ^ (~x & z);
endfunction

function automatic logic [31:0] Maj(
    input logic [31:0] x,
    input logic [31:0] y,
    input logic [31:0] z
);
    return (x & y) ^ (x & z) ^ (y & z);
endfunction

// --- compute_hash task (fixed length endianness + cleaner block calc) ---
task compute_hash;
    input  string str;
    output logic [255:0] hash;

    // Declarations
    longint str_len_bits;
    int     str_len_bytes;
    byte    message[];               // dynamic byte array
    int     num_blocks;

    // Hashing variables
    logic [31:0] hash_regs[8];
    logic [31:0] W[64];
    logic [31:0] a, b, c, d, e, f, g, h;
    logic [31:0] temp1, temp2;
    int b_idx;

    // --- Padding Logic ---
    str_len_bytes = str.len();
    str_len_bits  = str_len_bytes * 8;

    // Clear and clear formula: total = original bytes + 1 (0x80) + 8 (length)
    // num_blocks = ceil( (str_len_bytes + 1 + 8) / 64 )
    num_blocks = ((str_len_bytes + 1 + 8) + 63) / 64;

    message = new[num_blocks * 64];

    // zero initialize explicitly
    for (int i = 0; i < (num_blocks * 64); i++) message[i] = 8'h00;

    // copy message bytes
    for (int i = 0; i < str_len_bytes; i++) begin
        message[i] = str[i];
    end

    // append 0x80
    message[str_len_bytes] = 8'h80;

    // append length as 64-bit big-endian:
    // Most significant byte first: str_len_bits[63:56], ... , str_len_bits[7:0]
    // Put it into the final 8 bytes (index = num_blocks*64 - 8 + i)
    for (int i = 0; i < 8; i++) begin
        // pick byte i from MSB to LSB
        message[(num_blocks * 64) - 8 + i] = byte'((str_len_bits >> ((7 - i) * 8)) & 64'hFF);;
    end

    // --- Hash Computation ---
    // initialize
    for (int i = 0; i < 8; i++) hash_regs[i] = H[i];

    for (int block = 0; block < num_blocks; block++) begin
        // copy first 16 words (big-endian bytes -> big-endian words)
        for (int i = 0; i < 16; i++) begin
            b_idx = block * 64 + i * 4;
            W[i] = { message[b_idx], message[b_idx+1], message[b_idx+2], message[b_idx+3] };
        end

        // extend
        for (int i = 16; i < 64; i++) begin
            // note: keep operations as 32-bit (assignment will truncate)
            W[i] = s1(W[i-2]) + W[i-7] + s0(W[i-15]) + W[i-16];
        end

        // compress
        a = hash_regs[0];
        b = hash_regs[1];
        c = hash_regs[2];
        d = hash_regs[3];
        e = hash_regs[4];
        f = hash_regs[5];
        g = hash_regs[6];
        h = hash_regs[7];

        for (int i = 0; i < 64; i++) begin
            temp1 = h + S1(e) + Ch(e, f, g) + K[i] + W[i];
            temp2 = S0(a) + Maj(a, b, c);
            h = g;
            g = f;
            f = e;
            e = d + temp1;
            d = c;
            c = b;
            b = a;
            a = temp1 + temp2;
        end

        // add back
        hash_regs[0] = hash_regs[0] + a;
        hash_regs[1] = hash_regs[1] + b;
        hash_regs[2] = hash_regs[2] + c;
        hash_regs[3] = hash_regs[3] + d;
        hash_regs[4] = hash_regs[4] + e;
        hash_regs[5] = hash_regs[5] + f;
        hash_regs[6] = hash_regs[6] + g;
        hash_regs[7] = hash_regs[7] + h;
    end

    // output
    hash = {hash_regs[0], hash_regs[1], hash_regs[2], hash_regs[3],
            hash_regs[4], hash_regs[5], hash_regs[6], hash_regs[7]};
endtask

/* verilator lint_on VARHIDDEN */
