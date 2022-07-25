import bitutils::*;

module clmul32 (
    input CLK,
    input word_t A,
    input word_t B,
    output dword_t P
);

dword_t [31:0] mul0;
dword_t [15:0] mul1;
dword_t [7:0] mul2;

generate
    for (genvar i = 0; i < 32; ++i) begin
        assign mul0[i] = A[i] ? ((i==0) ? {{32{1'b0}}, B} : {{(32-i){1'b0}}, B, {i{1'b0}}}) : '0;
    end
endgenerate

generate
    for (genvar i = 0; i < 16; ++i) begin
        // mul1[0] = mul0[0] ^ mul0[1]
        // mul1[1] = mul0[2] ^ mul0[3]
        // ...
        // mul1[15] = mul0[30] ^ mul0[31]
        assign mul1[i] = mul0[i*2] ^ mul0[i*2+1];
    end
endgenerate

generate
    for (genvar i = 0; i < 8; ++i) begin
        // mul2[0] = mul1[0] ^ mul1[1]
        // mul2[1] = mul1[2] ^ mul1[3]
        // ...
        // mul2[7] = mul1[14] ^ mul1[15]
        assign mul2[i] = mul1[i*2] ^ mul1[i*2+1];
    end
endgenerate

dword_t [3:0] mul3_reg;

generate
    for (genvar i = 0; i < 4; ++i) begin
        // mul3_reg[0] <= mul2[0] ^ mul2[1]
        // mul3_reg[1] <= mul2[2] ^ mul2[3]
        // ...
        // mul3_reg[3] <= mul2[6] ^ mul2[7]
        always_ff @(posedge CLK) begin
            mul3_reg[i] <= mul2[i*2] ^ mul2[i*2+1];
        end
    end
endgenerate

assign P = mul3_reg[0] ^ mul3_reg[1] ^ mul3_reg[2] ^ mul3_reg[3];


endmodule
