// multi-cycle multiply/divide unit
import bitutils::*;
import bundle::*;
import micro_ops::*;
import csr_def::*;
import exception::*;

module MDU (
    input clk, rst,

    input logic flush,
    input op_t op,
    input word_t gpr_rs1,
    input word_t gpr_rs2,

    output dword_t mul_ss, // signed x signed
    output dword_t mul_su, // signed x unsigned
    output dword_t mul_uu, // unsigned x unsigned
    output word_t div_s,
    output word_t div_u,
    output word_t rem_s,
    output word_t rem_u,
    output dword_t clmul,
    output dword_t clmulr,
    output logic busy
);

// TODO: cache last time DIV/MUL result for faster REM request.
// OP_MUL, OP_MULH, OP_MULHSU, OP_MULHU
// OP_DIV, OP_DIVU, OP_REM, OP_REMU
// OP_CLMUL, OP_CLMULH, OP_CLMULR

assign mul_ss = '0;
assign mul_su = '0;
assign mul_uu = '0;
assign div_s = '0;
assign div_u = '0;
assign rem_s = '0;
assign rem_u = '0;
assign clmul = '0;
assign clmulr = '0;
assign busy = '0;

endmodule
