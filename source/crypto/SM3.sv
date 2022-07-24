package sm3utils;

import bitutils::*;

function word_t sm3p0(input word_t x);
    return x ^ { x[22:0], x[31:23] } ^ { x[14:0], x[31:15] };
endfunction;

function word_t sm3p1(input word_t x);
    return x ^ { x[16:0], x[31:17] } ^ { x[8:0], x[31:9] };
endfunction;

endpackage

