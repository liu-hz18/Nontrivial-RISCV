import bitutils::*;

module LFSR64 #(
    parameter NAME = "LFSR64",
    parameter RANDOM_SEED = 64'h1234_5678_8765_4321
) (
    input rst, clk,
    input logic update,
    output dword_t lfsr
);

logic _xor;
assign _xor = lfsr[0] ^ lfsr[1] ^ lfsr[3] ^ lfsr[4];

always_ff @(posedge clk) begin
    if (rst) begin
        lfsr <= RANDOM_SEED;
    end else if (update) begin
        if (lfsr == '0) begin
            lfsr <= 64'h1;
        end else begin
            lfsr <= { _xor, lfsr[63:1] };
        end
    end
end

endmodule
