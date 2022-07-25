// blocking execute unit 
import bitutils::*;
import bundle::*;
import micro_ops::*;
import csr_def::*;
import exception::*;
// Cryptography Extensions
import sha2utils::*;
import sm3utils::*;

module EXU (
    input clk, rst,
    input flush,
    input op_t op,
    input word_t inst,
    input word_t pc,

    // GPR values
    input word_t gpr_rs1,
    input word_t gpr_rs2,
    input word_t imm,
    input logic [4:0] shamt,

    // FPR values
    input word_t fpr_rs1,
    input word_t fpr_rs2,
    input word_t fpr_rs3,

    // BPU prediction results
    input word_t bpu_predict_target,
    input logic bpu_predict_valid,
    // inst type
    input inst_type_t inst_type,

    // exception from frontend
    input except_t exception_in,

    // output control signal
    output logic exu_busy,

    // ALU output
    output word_t gpr_wdata,
    output word_t fpr_wdata,

    // MEM control signals
    output mem_req_t mem_req,

    // BPU update req
    output bpu_update_req_t bpu_update_req,

    // PC update req
    output word_t redirect_pc,
    output logic redirect_valid,

    // exceptions updated by EXU
    output except_t exu_exception
);

logic [5:0] xlen_sub_shamt, xlen_sub_rs2;
assign xlen_sub_shamt = 6'b10_0000 - { 1'b0, shamt };
assign xlen_sub_rs2 = 6'b10_0000 - { 1'b0, gpr_rs2[4:0] };

word_t btype_target;
assign btype_target = pc + imm;

word_t onehot_rs2, onehot_imm;
assign onehot_rs2 = (32'b1 << gpr_rs2[4:0]);
assign onehot_imm = (32'b1 << shamt);

word_t clz_result, ctz_result, cntone_result;
BitManip BitManip(
    .value(gpr_rs1),
    .clz_result(clz_result),
    .ctz_result(ctz_result),
    .cntone_result(cntone_result)
);

// compare unit
// reg-reg insts
bit_t reg_eq;
assign reg_eq = (gpr_rs1 == gpr_rs2);
word_t add_u, sub_u;
bit_t signed_lt, unsigned_lt;
assign add_u = gpr_rs1 + gpr_rs2;
assign sub_u = gpr_rs1 - gpr_rs2;
assign signed_lt = (gpr_rs1[31] != gpr_rs2[31]) ? gpr_rs1[31] : sub_u[31];
assign unsigned_lt = (gpr_rs1 < gpr_rs2);

// reg-imm insts
word_t addi_u, subi_u;
bit_t signed_lti, unsigned_lti;
assign addi_u = gpr_rs1 + imm;
assign subi_u = gpr_rs1 - imm;
assign signed_lti = (gpr_rs1[31] != imm[31]) ? gpr_rs1[31] : subi_u[31];
assign unsigned_lti = (gpr_rs1 < imm);

word_t pc_plus4;
assign pc_plus4 = { pc[31:2] + 30'd1, 2'b0 };

// Branch instructions
logic branch_should_take;
word_t actual_branch_target;
always_comb begin: branch_amend
    unique case(op)
    OP_BEQ: begin 
        branch_should_take = reg_eq; actual_branch_target = btype_target;
        bpu_update_req.btb_type = BRANCH;
    end
    OP_BNE: begin 
        branch_should_take = ~reg_eq; actual_branch_target = btype_target;
        bpu_update_req.btb_type = BRANCH;
    end
    OP_BLT: begin 
        branch_should_take = signed_lt; actual_branch_target = btype_target; 
        bpu_update_req.btb_type = BRANCH;
    end
    OP_BGE: begin 
        branch_should_take = ~signed_lt; actual_branch_target = btype_target;
        bpu_update_req.btb_type = BRANCH;
    end
    OP_BLTU: begin 
        branch_should_take = unsigned_lt; actual_branch_target = btype_target; 
        bpu_update_req.btb_type = BRANCH;
    end
    OP_BGEU: begin 
        branch_should_take = ~unsigned_lt; actual_branch_target = btype_target;
        bpu_update_req.btb_type = BRANCH;
    end
    OP_JAL: begin 
        branch_should_take = 1'b1; actual_branch_target = btype_target;
        bpu_update_req.btb_type = JUMP;
    end
    OP_JALR: begin 
        branch_should_take = 1'b1; actual_branch_target = addi_u; 
        bpu_update_req.btb_type = inst_type.is_ret ? RETURN : INDIRECT;
    end
    default: begin 
        branch_should_take = 1'b0; actual_branch_target = '0;
        bpu_update_req.btb_type = BRANCH; 
    end
    endcase
end
// fix BPU prediction
assign bpu_update_req.valid = ~flush & inst_type.is_branch_jump;
assign bpu_update_req.pc = pc_plus4;
assign bpu_update_req.is_miss_predict = ~(bpu_predict_valid && (actual_branch_target == bpu_predict_target));
assign bpu_update_req.actual_target = actual_branch_target;
assign bpu_update_req.actual_taken = branch_should_take;
assign bpu_update_req.is_branch_inst = inst_type.is_branch;
assign bpu_update_req.is_call_inst = inst_type.is_call;
assign bpu_update_req.is_ret_inst = inst_type.is_ret;
assign bpu_update_req.same_link_regs = inst_type.same_link_regs;
// PC redirect
assign redirect_valid = (branch_should_take ^ bpu_predict_valid) || (bpu_predict_valid && branch_should_take && (actual_branch_target != bpu_predict_target));
assign redirect_pc = branch_should_take ? actual_branch_target : pc_plus4;

// ALU
logic mdu_busy;
dword_t mul_ss, mul_su, mul_uu, clmul, clmulr;
word_t div_s, div_u, rem_s, rem_u;
logic fpu_busy;
word_t fpu_result, fix_result;
logic [4:0] fpu_fflags;

word_t aes_result, sm4_result;
logic crypto_busy;

assign exu_busy = mdu_busy | fpu_busy | crypto_busy;

always_comb begin: gpr_alu
    unique case(op)
    // RV32I
    OP_ANDI: gpr_wdata = gpr_rs1 & imm;
    OP_ORI:  gpr_wdata = gpr_rs1 | imm;
    OP_XORI: gpr_wdata = gpr_rs1 ^ imm;
    OP_SLLI: gpr_wdata = gpr_rs1 << shamt;
    OP_SRLI: gpr_wdata = gpr_rs1 >> shamt;
    OP_SRAI: gpr_wdata = $signed(gpr_rs1) >>> shamt;
    OP_ADDI: gpr_wdata = addi_u;
    OP_SLTI: gpr_wdata = { 31'b0, signed_lti };
    OP_SLTIU:gpr_wdata = { 31'b0, unsigned_lti };
    OP_AND:  gpr_wdata = gpr_rs1 & gpr_rs2;
    OP_OR:   gpr_wdata = gpr_rs1 | gpr_rs2;
    OP_XOR:  gpr_wdata = gpr_rs1 ^ gpr_rs2;
    OP_SLL:  gpr_wdata = gpr_rs1 << gpr_rs2[4:0];
    OP_SRL:  gpr_wdata = gpr_rs1 >> gpr_rs2[4:0];
    OP_SRA:  gpr_wdata = $signed(gpr_rs1) >>> gpr_rs2[4:0];
    OP_ADD:  gpr_wdata = add_u;
    OP_SUB:  gpr_wdata = sub_u;
    OP_SLT:  gpr_wdata = { 31'b0, signed_lt };
    OP_SLTU: gpr_wdata = { 31'b0, unsigned_lt };
    OP_LUI:  gpr_wdata = imm;
    OP_AUIPC:gpr_wdata = btype_target;
    OP_JAL:  gpr_wdata = pc_plus4;
    OP_JALR: gpr_wdata = pc_plus4;
    // TODO: RV Zicsr Extension
    OP_CSRRW, OP_CSRRS, OP_CSRRC,
    OP_CSRRWI, OP_CSRRSI, OP_CSRRCI:  gpr_wdata = '0;
    // RV32M Extension
    OP_MUL:  gpr_wdata = mul_ss[31:0];
    OP_MULH: gpr_wdata = mul_ss[63:32];
    OP_MULHSU:gpr_wdata = mul_su[63:32];
    OP_MULHU: gpr_wdata = mul_uu[63:32];
    OP_DIV:   gpr_wdata = div_s;
    OP_DIVU:  gpr_wdata = div_u;
    OP_REM:   gpr_wdata = rem_s;
    OP_REMU:  gpr_wdata = rem_u;
    // RV32 Bitmanip Extensions
    // RV32 Zba Extension
    OP_SH1ADD:gpr_wdata = { gpr_rs1[30:0], 1'b0 } + gpr_rs2;
    OP_SH2ADD:gpr_wdata = { gpr_rs1[29:0], 2'b00 } + gpr_rs2;
    OP_SH3ADD:gpr_wdata = { gpr_rs1[28:0], 3'b000 } + gpr_rs2;
    // RV32 Zbb Extension
    OP_ANDN: gpr_wdata = gpr_rs1 & (~gpr_rs2);
    OP_ORN:  gpr_wdata = gpr_rs1 | (~gpr_rs2);
    OP_XNOR: gpr_wdata = gpr_rs1 ^ (~gpr_rs2);
    OP_CLZ:  gpr_wdata = clz_result;
    OP_CTZ:  gpr_wdata = ctz_result;
    OP_CPOP: gpr_wdata = cntone_result;
    OP_MAX:  gpr_wdata = signed_lt ? gpr_rs2 : gpr_rs1;
    OP_MAXU: gpr_wdata = unsigned_lt ? gpr_rs2 : gpr_rs1;
    OP_MIN:  gpr_wdata = signed_lt ? gpr_rs1 : gpr_rs2;
    OP_MINU: gpr_wdata = unsigned_lt ? gpr_rs1 : gpr_rs2;
    OP_SEXTB:gpr_wdata = { {24{gpr_rs1[7]}}, gpr_rs1[7:0] };
    OP_SEXTH:gpr_wdata = { {16{gpr_rs1[15]}}, gpr_rs1[15:0] };
    // OP_ZEXTH:gpr_wdata = { 16'b0, gpr_rs1[15:0] }; // !replaced by `OP_PACK`
    OP_PACK: gpr_wdata = { gpr_rs2[15:0], gpr_rs1[15:0] };
    OP_PACKH:gpr_wdata = { 16'b0, gpr_rs2[7:0], gpr_rs1[7:0] };
    OP_ROL:  gpr_wdata = (gpr_rs1 << gpr_rs2[4:0]) | (gpr_rs1 >> xlen_sub_rs2);
    OP_ROR:  gpr_wdata = (gpr_rs1 >> gpr_rs2[4:0]) | (gpr_rs1 << xlen_sub_rs2);
    OP_RORI: gpr_wdata = (gpr_rs1 >> shamt) | (gpr_rs1 << xlen_sub_shamt);
    OP_ORCB: gpr_wdata = { {8{(|gpr_rs1[31:24])}}, {8{(|gpr_rs1[23:16])}}, {8{(|gpr_rs1[15:8])}}, {8{(|gpr_rs1[7:0])}} };
    OP_REV8: gpr_wdata = { gpr_rs1[7:0], gpr_rs1[15:8], gpr_rs1[23:16], gpr_rs1[31:24] };
    OP_BREV8:gpr_wdata = { bit_reverse_in_byte(gpr_rs1[31:24]), bit_reverse_in_byte(gpr_rs1[23:16]), bit_reverse_in_byte(gpr_rs1[15:8]), bit_reverse_in_byte(gpr_rs1[7:0]) };
    OP_ZIP:  gpr_wdata = zip_word(gpr_rs1);
    OP_UNZIP:gpr_wdata = unzip_word(gpr_rs1);
    OP_XPERM4: gpr_wdata = {
        xperm_nibble(gpr_rs2[31:28], gpr_rs1), xperm_nibble(gpr_rs2[27:24], gpr_rs1), xperm_nibble(gpr_rs2[23:20], gpr_rs1), xperm_nibble(gpr_rs2[19:16], gpr_rs1), 
        xperm_nibble(gpr_rs2[15:12], gpr_rs1), xperm_nibble(gpr_rs2[11:8], gpr_rs1),  xperm_nibble(gpr_rs2[7:4],   gpr_rs1), xperm_nibble(gpr_rs2[3:0],   gpr_rs1)
    };
    OP_XPERM8: gpr_wdata = { xperm_byte(gpr_rs2[31:24], gpr_rs1), xperm_byte(gpr_rs2[23:16], gpr_rs1), xperm_byte(gpr_rs2[15:8], gpr_rs1), xperm_byte(gpr_rs2[7:0], gpr_rs1) };
    // RV32 Zbc Extension
    OP_CLMUL: gpr_wdata = clmul[31:0];
    OP_CLMULH:gpr_wdata = clmul[63:32];
    OP_CLMULR:gpr_wdata = clmul[62:31];
    // RV32 Zbs Extensions
    OP_BCLR: gpr_wdata = gpr_rs1 & (~onehot_rs2);
    OP_BCLRI:gpr_wdata = gpr_rs1 & (~onehot_imm);
    OP_BEXT: gpr_wdata = 32'b1 & (gpr_rs1 >> gpr_rs2[4:0]);
    OP_BEXTI:gpr_wdata = 32'b1 & (gpr_rs1 >> shamt);
    OP_BINV: gpr_wdata = gpr_rs1 ^ onehot_rs2;
    OP_BINVI:gpr_wdata = gpr_rs1 ^ onehot_imm;
    OP_BSET: gpr_wdata = gpr_rs1 | onehot_rs2;
    OP_BSETI:gpr_wdata = gpr_rs1 | onehot_imm;
    // TODO: RV32A Extension

    // RV32F Extension
    OP_FEQS, OP_FLTS, OP_FLES,
    OP_FCVTWS, OP_FCVTWUS, OP_FMVXW, OP_FCLASSS: gpr_wdata = fix_result;
    // RV32 Cryptography Extension
    OP_AES32_DSI, OP_AES32_DSMI, 
    OP_AES32_ESI, OP_AES32_ESMI: gpr_wdata = aes_result;
    OP_SHA256_SIG0: gpr_wdata = sha256sig0(gpr_rs1);
    OP_SHA256_SIG1: gpr_wdata = sha256sig1(gpr_rs1);
    OP_SHA256_SUM0: gpr_wdata = sha256sum0(gpr_rs1);
    OP_SHA256_SUM1: gpr_wdata = sha256sum1(gpr_rs1);
    OP_SHA512_SIG0H: gpr_wdata = sha512sig0h(gpr_rs1, gpr_rs2);
    OP_SHA512_SIG0L: gpr_wdata = sha512sig0l(gpr_rs1, gpr_rs2);
    OP_SHA512_SIG1H: gpr_wdata = sha512sig1h(gpr_rs1, gpr_rs2);
    OP_SHA512_SIG1L: gpr_wdata = sha512sig1l(gpr_rs1, gpr_rs2);
    OP_SHA512_SUM0R: gpr_wdata = sha512sum0r(gpr_rs1, gpr_rs2);
    OP_SHA512_SUM1R: gpr_wdata = sha512sum1r(gpr_rs1, gpr_rs2);
    OP_SM4_ED, OP_SM4_KS: gpr_wdata = sm4_result;
    OP_SM3_P0: gpr_wdata = sm3p0(gpr_rs1);
    OP_SM3_P1: gpr_wdata = sm3p1(gpr_rs1);
    default:   gpr_wdata = '0;
    endcase
end

MDU MDU (
    .clk(clk),
    .rst(rst),
    .flush(flush),
    .op(op),
    .inst_type(inst_type),
    .gpr_rs1(gpr_rs1),
    .gpr_rs2(gpr_rs2),
    .mul_ss(mul_ss),
    .mul_su(mul_su),
    .mul_uu(mul_uu),
    .div_s(div_s),
    .div_u(div_u),
    .rem_s(rem_s),
    .rem_u(rem_u),
    .clmul(clmul),
    .busy(mdu_busy)
);

assign fpr_wdata = fpu_result;
FPU FPU (
    .clk(clk),
    .rst(rst),
    .flush(flush),
    .op(op),
    .inst_type(inst_type),
    .fpr_rs1(fpr_rs1),
    .fpr_rs2(fpr_rs2),
    .fpr_rs3(fpr_rs3),
    .gpr_rs1(gpr_rs1),
    .float_result(fpu_result),
    .fix_result(fix_result),
    .fflags(fpu_fflags),
    .busy(fpu_busy)
);

CryptoUnit CryptoUnit (
    .clk(clk),
    .rst(rst),
    .flush(flush),
    .op(op),
    .inst_type(inst_type),
    .rs1(gpr_rs1),
    .rs2(gpr_rs2),
    .bs(inst[31:30]),
    .aes_result(aes_result),
    .sm4_result(sm4_result),
    .busy(crypto_busy)
);

// MEM Control signals
always_comb begin: mem_ctrl
    mem_req = '0;
    mem_req.addr = addi_u;

    unique case(op)
    OP_LB, OP_LH, OP_LW, OP_LBU, OP_LHU, OP_FLWS: mem_req.load = ~(|exu_exception);
    OP_SB, OP_SH, OP_SW, OP_FSWS: mem_req.store = ~(|exu_exception);
    endcase

    unique case(op)
    OP_LB, OP_SB, OP_LBU: mem_req.mask = 4'b0001 << addi_u[1:0];
    OP_LH, OP_SH, OP_LHU: mem_req.mask = addi_u[1] ? 4'b1100 : 4'b0011;
    OP_LW, OP_SW, OP_FLWS, OP_FSWS: mem_req.mask = 4'b1111;
    default: mem_req.mask = 4'b0000;
    endcase

    unique case(op)
    OP_SB: begin
        unique case(addi_u[1:0])
        2'b00: mem_req.wdata = { 24'b0, gpr_rs2[7:0] };
        2'b01: mem_req.wdata = { 16'b0, gpr_rs2[7:0], 8'b0 };
        2'b10: mem_req.wdata = { 8'b0, gpr_rs2[7:0], 16'b0 };
        2'b11: mem_req.wdata = { gpr_rs2[7:0], 24'b0 };
        endcase
    end
    OP_SH: mem_req.wdata = addi_u[1] ? { gpr_rs2[15:0], 16'b0 } : { 16'b0, gpr_rs2[15:0] };
    OP_SW: mem_req.wdata = gpr_rs2;
    OP_FSWS: mem_req.wdata = fpr_rs2;
    endcase
end

// TODO: CSR read signals


// exception check
logic load_half_misaligned, load_word_misaligned;
logic store_half_misaligned, store_word_misaligned;
assign load_half_misaligned = ((op == OP_LH) || (op == OP_LHU)) ? addi_u[0] : 1'b0;
assign load_word_misaligned = ((op == OP_LW) || (op == OP_FLWS)) ? (|addi_u[1:0]) : 1'b0;
assign store_half_misaligned = (op == OP_SH) ? addi_u[0] : 1'b0;
assign store_word_misaligned = ((op == OP_SW) || (op == OP_FSWS)) ? (|addi_u[1:0]) : 1'b0;
always_comb begin: exu_exception_check
    exu_exception = exception_in;
    // misaligned
    exu_exception.fetch_misalign = inst_type.is_branch_jump ? (|actual_branch_target[1:0]) : 1'b0;
    exu_exception.load_misalign = load_half_misaligned | load_word_misaligned;
    exu_exception.store_misalign = store_half_misaligned | store_word_misaligned;
end

endmodule
