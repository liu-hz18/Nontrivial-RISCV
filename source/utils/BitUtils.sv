package bitutils;

// basic data types
typedef logic       bit_t;
typedef logic[7 :0] byte_t;
typedef logic[15:0] hword_t;
typedef logic[31:0] word_t;
typedef logic[63:0] dword_t;

parameter        ZERO_BIT = 1'b0;
parameter [7 :0] ZERO_BYTE = 8'h0;
parameter [15:0] ZERO_HWORD = 16'h0;
parameter [31:0] ZERO_WORD = 32'h0;
parameter [63:0] ZERO_DWORD = 64'h0;

parameter int NUM_GPRS = 32;
parameter GPR_INDEX_WIDTH = $clog2(NUM_GPRS);
typedef logic [GPR_INDEX_WIDTH-1:0] gpr_addr_t;

parameter int NUM_FPRS = 32;
parameter FPR_INDEX_WIDTH = $clog2(NUM_FPRS);
typedef logic [FPR_INDEX_WIDTH-1:0] fpr_addr_t;


function word_t rol32_byte(input word_t x, input logic[1:0] bs);
    word_t result;
    unique case(bs)
    2'b00: result = x;
    2'b01: result = { x[23:0], x[31:24] };
    2'b10: result = { x[15:0], x[31:16] };
    2'b11: result = { x[7:0],  x[31:8] };
    endcase
    return result;
endfunction;
function logic[7:0] bit_reverse_in_byte(input logic[7:0] in);
    return { in[0], in[1], in[2], in[3], in[4], in[5], in[6], in[7] };
endfunction;
function word_t zip_word(input word_t in);
    word_t out;
    for (int i = 0; i < 16; ++i) begin
        out[2*i] = in[i];
        out[2*i+1] = in[i+16];
    end
    return out;
endfunction;
function word_t unzip_word(input word_t in);
    word_t out;
    for (int i = 0; i < 16; ++i) begin
        out[i] = in[2*i];
        out[i+16] = in[2*i+1];
    end
    return out;
endfunction;
function byte_t xperm_byte(input byte_t idx, input word_t lut);
    // unique case (idx)
    // 8'b0000_0000: lut[7:0];
    // 8'b0000_0001: lut[15:8];
    // 8'b0000_0010: lut[23:16];
    // 8'b0000_0011: lut[31:24];
    // default: '0;
    // endcase
    word_t result;
    result = (lut >> { idx, 3'b000 });
    return result[7:0];
endfunction;
function logic[3:0] xperm_nibble(input logic[3:0] idx, input word_t lut);
    // unique case (idx)
    // 4'b0000: lut[3:0];
    // 4'b0001: lut[7:4];
    // 4'b0010: lut[11:8];
    // 4'b0011: lut[15:12];
    // 4'b0100: lut[19:16];
    // 4'b0101: lut[23:20];
    // 4'b0110: lut[27:24];
    // 4'b0111: lut[31:28];
    // default: '0;
    // endcase
    word_t result;
    result = (lut >> { idx, 2'b00 });
    return result[3:0];
endfunction;

endpackage
