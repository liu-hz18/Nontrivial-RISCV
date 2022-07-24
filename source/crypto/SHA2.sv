package sha2utils;

import bitutils::*;

function word_t sha256sig0(input word_t x);
    return { x[6:0], x[31:7] } ^ { x[17:0], x[31:18] } ^ { 3'b000, x[31:3] };
endfunction;
function word_t sha256sig1(input word_t x);
    return { x[16:0], x[31:17] } ^ { x[18:0], x[31:19] } ^ { 10'b0, x[31:10] };
endfunction;
function word_t sha256sum0(input word_t x);
    return { x[1:0], x[31:2] } ^ { x[12:0], x[31:13] } ^ { x[21:0], x[31:22] };
endfunction;
function word_t sha256sum1(input word_t x);
    return { x[5:0], x[31:6] } ^ { x[10:0], x[31:11] } ^ { x[24:0], x[31:25] };
endfunction;
function word_t sha512sig0h(input word_t rs1, input word_t rs2);
    return { 1'b0, rs1[31:1] } ^ { 7'b0, rs1[31:7] } ^ { 8'b0, rs1[31:8] } ^ { rs2[0], 31'b0 } ^ { rs2[7:0], 24'b0 };
endfunction;
function word_t sha512sig0l(input word_t rs1, input word_t rs2);
    return { 1'b0, rs1[31:1] } ^ { 7'b0, rs1[31:7] } ^ { 8'b0, rs1[31:8] } ^ { rs2[0], 31'b0 } ^ { rs2[6:0], 25'b0 } ^ { rs2[7:0], 24'b0 };
endfunction;
function word_t sha512sig1h(input word_t rs1, input word_t rs2);
    return { rs1[28:0], 3'b0 } ^ { 6'b0, rs1[31:6] } ^ { 19'b0, rs1[31:19] } ^ { 29'b0, rs2[31:29] } ^ { rs2[18:0], 13'b0 };
endfunction;
function word_t sha512sig1l(input word_t rs1, input word_t rs2);
    return { rs1[28:0], 3'b0 } ^ { 6'b0, rs1[31:6] } ^ { 19'b0, rs1[31:19] } ^ { 29'b0, rs2[31:29] } ^ { rs2[5:0], 26'b0 } ^ { rs2[18:0], 13'b0 };
endfunction;
function word_t sha512sum0r(input word_t rs1, input word_t rs2);
    return { rs1[6:0], 25'b0 } ^ { rs1[1:0], 30'b0 } ^ { 28'b0, rs1[31:28] } ^ { 7'b0, rs2[31:7] } ^ { 2'b0, rs2[31:2] } ^ { rs2[27:0], 4'b0 };
endfunction;
function word_t sha512sum1r(input word_t rs1, input word_t rs2);
    return { rs1[8:0], 23'b0 } ^ { 14'b0, rs1[31:14] } ^ { 18'b0, rs1[31:18] } ^ { 9'b0, rs2[31:9] } ^ { rs2[13:0], 18'b0 } ^ { rs2[17:0], 14'b0 };
endfunction;

endpackage
