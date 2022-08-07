// inst decode
import bitutils::*;
import bundle::*;
import micro_ops::*;

`define INST(_op, _raddr1, _raddr2, _we, _waddr) \
begin \
    op = _op; \
    gpr_raddr1 = _raddr1; \
    gpr_raddr2 = _raddr2; \
    gpr_we = _we; \
    gpr_waddr = _waddr; \
\
    fpr_we = '0; \
    fpr_waddr = '0; \
\
    fpu_rs1_re = '0; \
    fpr_raddr1 = '0; \
    fpu_rs2_re = '0; \
    fpr_raddr2 = '0; \
    fpu_rs3_re = '0; \
    fpr_raddr3 = '0; \
    fp_rounding_mode = '0; \
end

`define INST_W(_op, _raddr1, _raddr2, _waddr) `INST(_op, _raddr1, _raddr2, 1'b1, _waddr)
`define INST_R(_op, _raddr1, _raddr2) `INST(_op, _raddr1, _raddr2, 1'b0, 5'b0)

`define FINST(_op, _raddr1, _raddr2, _rs2_ren, _raddr3, _rs3_ren, _we, _waddr, _rm) \
begin \
    op = _op; \
\
    fpr_raddr1 = _raddr1; \
    fpu_rs1_re = 1'b1; \
    fpr_raddr2 = _raddr2; \
    fpu_rs2_re = _rs2_ren; \
    fpr_raddr3 = _raddr3; \
    fpu_rs3_re = _rs3_ren; \
\
    fpr_we = _we; \
    fpr_waddr = _waddr; \
    fp_rounding_mode = _rm; \
\
    gpr_raddr1 = '0; \
    gpr_raddr2 = '0; \
    gpr_we = '0; \
    gpr_waddr = '0; \
end
`define FINST_READ1(_op, _raddr1, _we, _waddr, _rm) `FINST(_op, _raddr1, 5'b0, 1'b0, 5'b0, 1'b0, _we, _waddr, _rm)
`define FINST_READ2(_op, _raddr1, _raddr2, _we, _waddr, _rm) `FINST(_op, _raddr1, _raddr2, 1'b1, 5'b0, 1'b0, _we, _waddr, _rm)
`define FINST_READ3(_op, _raddr1, _raddr2, _raddr3, _we, _waddr, _rm) `FINST(_op, _raddr1, _raddr2, 1'b1, _raddr3, 1'b1, _we, _waddr, _rm)
`define FINST_LOAD(_op, _raddr1, _waddr) \
begin \
    op = _op; \
    fpr_raddr1 = '0; \
    fpu_rs1_re = 1'b0; \
    fpr_raddr2 = '0; \
    fpu_rs2_re = 1'b0; \
    fpr_raddr3 = '0; \
    fpu_rs3_re = 1'b0; \
    fpr_we = 1'b1; \
    fpr_waddr = _waddr; \
    fp_rounding_mode = 3'b000; \
    gpr_raddr1 = _raddr1; \
    gpr_raddr2 = '0; \
    gpr_we = '0; \
    gpr_waddr = '0; \
end
`define FINST_STORE(_op, _raddr1, _raddr2) \
begin \
    op = _op; \
    fpr_raddr1 = '0; \
    fpu_rs1_re = 1'b0; \
    fpr_raddr2 = _raddr2; \
    fpu_rs2_re = 1'b1; \
    fpr_raddr3 = '0; \
    fpu_rs3_re = 1'b0; \
    fpr_we = 1'b0; \
    fpr_waddr = '0; \
    fp_rounding_mode = 3'b000; \
    gpr_raddr1 = _raddr1; \
    gpr_raddr2 = '0; \
    gpr_we = '0; \
    gpr_waddr = '0; \
end
`define FINST_FIX2FLOAT(_op, _raddr1, _waddr, _rm) \
begin \
    op = _op; \
    fpr_raddr1 = '0; \
    fpu_rs1_re = 1'b0; \
    fpr_raddr2 = '0; \
    fpu_rs2_re = 1'b0; \
    fpr_raddr3 = '0; \
    fpu_rs3_re = 1'b0; \
    fpr_we = 1'b1; \
    fpr_waddr = _waddr; \
    fp_rounding_mode = _rm; \
    gpr_raddr1 = _raddr1; \
    gpr_raddr2 = '0; \
    gpr_we = '0; \
    gpr_waddr = '0; \
end
`define FINST_FLOAT2FIX(_op, _raddr1, _waddr, _rm) \
begin \
    op = _op; \
    fpr_raddr1 = _raddr1; \
    fpu_rs1_re = 1'b1; \
    fpr_raddr2 = '0; \
    fpu_rs2_re = 1'b0; \
    fpr_raddr3 = '0; \
    fpu_rs3_re = 1'b0; \
    fpr_we = 1'b0; \
    fpr_waddr = '0; \
    fp_rounding_mode = _rm; \
    gpr_raddr1 = '0; \
    gpr_raddr2 = '0; \
    gpr_we = 1'b1; \
    gpr_waddr = _waddr; \
end
`define FINST_CMP(_op, _raddr1, _raddr2, _waddr) \
begin \
    op = _op; \
    fpr_raddr1 = _raddr1; \
    fpu_rs1_re = 1'b1; \
    fpr_raddr2 = _raddr2; \
    fpu_rs2_re = 1'b1; \
    fpr_raddr3 = '0; \
    fpu_rs3_re = 1'b0; \
    fpr_we = 1'b0; \
    fpr_waddr = '0; \
    fp_rounding_mode = 3'b000; \
    gpr_raddr1 = '0; \
    gpr_raddr2 = '0; \
    gpr_we = 1'b1; \
    gpr_waddr = _waddr; \
end

// opcode
parameter [6:0] OPCODE_LUI    = 7'b0110111;
parameter [6:0] OPCODE_AUIPC  = 7'b0010111;
parameter [6:0] OPCODE_JAL    = 7'b1101111;
parameter [6:0] OPCODE_JALR   = 7'b1100111;
parameter [6:0] OPCODE_BRANCH = 7'b1100011; // beq, bne, blt, bge, bltu, bgeu
parameter [6:0] OPCODE_LOAD   = 7'b0000011; // lb, lh, lw, lbu, lhu
parameter [6:0] OPCODE_STORE  = 7'b0100011; // sb, sh, sw
parameter [6:0] OPCODE_IMM    = 7'b0010011; // addi, slti, sltiu, xori, ori, andi, slli, srli, srai
parameter [6:0] OPCODE_REG    = 7'b0110011; // add, sub, sll, slt, sltu, xor, srl, sra, or, and
parameter [6:0] OPCODE_FENCE  = 7'b0001111; // fence
parameter [6:0] OPCODE_SYSTEM = 7'b1110011; // ecall, ebreak, mret, CSRS
// RV32A Extension
parameter [6:0] OPCODE_AMO    = 7'b0101111; // lr, sc, amo*
// RV32F Extension
parameter [6:0] OPCODE_FLOAD  = 7'b0000111; // flw
parameter [6:0] OPCODE_FSTORE = 7'b0100111; // fsw
parameter [6:0] OPCODE_FMADD  = 7'b1000011;
parameter [6:0] OPCODE_FMSUB  = 7'b1000111;
parameter [6:0] OPCODE_FNMSUB = 7'b1001011;
parameter [6:0] OPCODE_FNMADD = 7'b1001111;
parameter [6:0] OPCODE_FLOAT  = 7'b1010011;

module IDU #(
    parameter NAME = "IDU"
) (
    input word_t inst,

    input csr_t csr,
    input cpu_mode_t cpu_mode,

    output op_t op,
    output word_t imm,
    output logic[4:0] shamt,
    // BPU call/ret
    output inst_type_t inst_type,
    // regfile R/W signals
    output logic gpr_we,
    output gpr_addr_t gpr_waddr,
    output gpr_addr_t gpr_raddr1,
    output gpr_addr_t gpr_raddr2,
    // Floating Point Registers R/W
    output logic fpr_we,
    output fpr_addr_t fpr_waddr,
    output fpr_addr_t fpr_raddr1,
    output logic fpu_rs1_re,
    output fpr_addr_t fpr_raddr2,
    output logic fpu_rs2_re,
    output fpr_addr_t fpr_raddr3,
    output logic fpu_rs3_re,
    output logic [2:0] fp_rounding_mode
);

word_t utype_imm, jtype_imm, itype_imm, stype_imm, btype_imm, csrtype_imm;
assign utype_imm   = { inst[31:12], 12'b0 };
assign jtype_imm   = { {13{inst[31]}}, inst[19:12], inst[20], inst[30:21], 1'b0 }; // jal
assign itype_imm   = { {21{inst[31]}}, inst[30:20] }; // NOTE: jalr is i-type
assign stype_imm   = { {21{inst[31]}}, inst[30:25], inst[11:7] };
assign btype_imm   = { {20{inst[31]}}, inst[7], inst[30:25], inst[11:8], 1'b0 };
assign csrtype_imm = { 27'b0, inst[19:15] };

logic[6:0] opcode;
logic[2:0] funct3;
logic[6:0] funct7;
logic[4:0] funct5;
assign opcode = inst[6:0];
assign funct3 = inst[14:12];
assign funct7 = inst[31:25];
assign funct5 = inst[31:27];
assign shamt = inst[24:20];

gpr_addr_t rs1, rs2, rs3, rd;
assign rs1 = inst[19:15];
assign rs2 = inst[24:20];
assign rs3 = inst[31:27];
assign rd  = inst[11:7];
logic [2:0] rm;
assign rm = inst[14:12];

logic aq, rl;
assign aq = inst[26];
assign rl = inst[25];

function logic is_link(input logic[4:0] rfaddr);
    return (rfaddr == 5'd1 || rfaddr == 5'd5);
endfunction;

assign inst_type.is_branch_jump = (opcode == OPCODE_BRANCH) || (opcode == OPCODE_JALR) || (opcode == OPCODE_JAL);
assign inst_type.is_branch = (opcode == OPCODE_BRANCH);
// call should push return address to RAS
assign inst_type.is_call = ((opcode == OPCODE_JAL) && is_link(rd)) || ((opcode == OPCODE_JALR) && is_link(rd));
// ret should pop RAS
assign inst_type.is_ret = (opcode == OPCODE_JALR) && is_link(rs1);
assign inst_type.same_link_regs = is_link(rs1) && (rs1 == rd);
assign inst_type.is_aes_sm4 = (opcode == OPCODE_REG) && (funct3 == 3'b0) && (funct7[4]);
assign inst_type.is_fpu_multi_cycle = (opcode == OPCODE_FMADD) || (opcode == OPCODE_FMSUB) || (opcode == OPCODE_FNMSUB) || (opcode == OPCODE_FNMADD) || 
                                     ((opcode == OPCODE_FLOAT) && ((funct7 == 7'b0000000) || (funct7 == 7'b0000100) || (funct7 == 7'b0001000) || (funct7 == 7'b0001100) || (funct7 == 7'b0101100) || (funct7 == 7'b0010100) || (funct7 == 7'b1100000) || (funct7 == 7'b1010000) || (funct7 == 7'b1101000)));
assign inst_type.is_mdu_multi_cycle = (opcode == OPCODE_REG) && ((funct7 == 7'b0000001) || (funct7 == 7'b0000101));
assign inst_type.is_load = (opcode == OPCODE_LOAD) || (opcode == OPCODE_FLOAD);
assign inst_type.is_store = (opcode == OPCODE_STORE) || (opcode == OPCODE_FSTORE);
// !NOTE: `is_amo` not include `is_lr` and `ls_sc`
assign inst_type.is_amo = (opcode == OPCODE_AMO) && (~funct7[3]);
assign inst_type.is_lr = (opcode == OPCODE_AMO) && (funct7[6:2] == 5'b00010);
assign inst_type.is_sc = (opcode == OPCODE_AMO) && (funct7[6:2] == 5'b00011);
assign inst_type.is_fpu_inst = (opcode == OPCODE_FLOAD) | (opcode == OPCODE_FSTORE) | (opcode == OPCODE_FMADD) | (opcode == OPCODE_FMSUB) | (opcode == OPCODE_FNMSUB) | (opcode == OPCODE_FNMADD) | (opcode == OPCODE_FLOAT);
assign inst_type.read_csr = ((opcode == OPCODE_SYSTEM) && (funct3[1:0] == 2'b01) && (rd != 5'b0));
assign inst_type.write_csr = ((opcode == OPCODE_SYSTEM) && ((funct3[2:1] == 2'b01) && (rs1 != 5'b0)) | ((funct3[2:1] == 2'b11) && (csrtype_imm != '0)));

// decoder
always_comb begin
    imm = '0;
    unique case(opcode)
    OPCODE_LUI: begin
        imm = utype_imm;
        `INST_W(OP_LUI, 5'b0, 5'b0, rd)
    end
    OPCODE_AUIPC: begin
        imm = utype_imm;
        `INST_W(OP_AUIPC, 5'b0, 5'b0, rd)
    end
    OPCODE_JAL: begin
        imm = jtype_imm;
        `INST_W(OP_JAL, 5'b0, 5'b0, rd)
    end
    OPCODE_JALR: begin
        imm = itype_imm;
        `INST_W(OP_JALR, rs1, 5'b0, rd)
    end
    OPCODE_BRANCH: begin
        imm = btype_imm;
        unique case(funct3)
        3'b000: `INST_R(OP_BEQ, rs1, rs2)
        3'b001: `INST_R(OP_BNE, rs1, rs2)
        3'b100: `INST_R(OP_BLT, rs1, rs2)
        3'b101: `INST_R(OP_BGE, rs1, rs2)
        3'b110: `INST_R(OP_BLTU, rs1, rs2)
        3'b111: `INST_R(OP_BGEU, rs1, rs2)
        default: `INST_R(OP_INVALID, 5'b0, 5'b0)
        endcase
    end
    OPCODE_LOAD: begin
        imm = itype_imm;
        unique case(funct3)
        3'b000: `INST_W(OP_LB, rs1, 5'b0, rd)
        3'b001: `INST_W(OP_LH, rs1, 5'b0, rd)
        3'b010: `INST_W(OP_LW, rs1, 5'b0, rd)
        3'b100: `INST_W(OP_LBU, rs1, 5'b0, rd)
        3'b101: `INST_W(OP_LHU, rs1, 5'b0, rd)
        default: `INST_R(OP_INVALID, 5'b0, 5'b0)
        endcase
    end
    OPCODE_STORE: begin
        imm = stype_imm;
        unique case(funct3)
        3'b000: `INST_R(OP_SB, rs1, rs2)
        3'b001: `INST_R(OP_SH, rs1, rs2)
        3'b010: `INST_R(OP_SW, rs1, rs2)
        default: `INST_R(OP_INVALID, 5'b0, 5'b0)
        endcase
    end
    OPCODE_IMM: begin
        imm = itype_imm;
        unique case(funct3)
        3'b000: `INST_W(OP_ADDI, rs1, 5'b0, rd)
        3'b001: begin
            unique case(funct7)
            7'b0000000: `INST_W(OP_SLLI, rs1, 5'b0, rd)
            7'b0100100: `INST_W(OP_BCLRI, rs1, 5'b0, rd) // bclri
            7'b0110100: `INST_W(OP_BINVI, rs1, 5'b0, rd) // binvi
            7'b0010100: `INST_W(OP_BSETI, rs1, 5'b0, rd) // bseti
            7'b0110000: begin
                unique case(rs2)
                5'b00000: `INST_W(OP_CLZ, rs1, 5'b0, rd) // clz
                5'b00001: `INST_W(OP_CTZ, rs1, 5'b0, rd) // ctz
                5'b00010: `INST_W(OP_CPOP, rs1, 5'b0, rd) // cpop
                5'b00100: `INST_W(OP_SEXTB, rs1, 5'b0, rd) // sext.b
                5'b00101: `INST_W(OP_SEXTH, rs1, 5'b0, rd) // sext.h
                default: `INST_R(OP_INVALID, 5'b0, 5'b0)
                endcase
            end
            7'b0000100: `INST_W(OP_ZIP, rs1, 5'b0, rd) // zip
            7'b0001000: begin
                unique case(rs2)
                5'b00010: `INST_W(OP_SHA256_SIG0, rs1, 5'b0, rd) // sha256sig0
                5'b00011: `INST_W(OP_SHA256_SIG1, rs1, 5'b0, rd) // sha256sig1
                5'b00000: `INST_W(OP_SHA256_SUM0, rs1, 5'b0, rd) // sha256sum0
                5'b00001: `INST_W(OP_SHA256_SUM1, rs1, 5'b0, rd) // sha256sum1
                5'b01000: `INST_W(OP_SM3_P0, rs1, 5'b0, rd) // sm3p0
                5'b01001: `INST_W(OP_SM3_P1, rs1, 5'b0, rd) // sm3p1
                default:  `INST_R(OP_INVALID, 5'b0, 5'b0)
                endcase
            end
            default:    `INST_R(OP_INVALID, 5'b0, 5'b0)
            endcase
        end
        3'b010: `INST_W(OP_SLTI, rs1, 5'b0, rd)
        3'b011: `INST_W(OP_SLTIU, rs1, 5'b0, rd)
        3'b100: `INST_W(OP_XORI, rs1, 5'b0, rd)
        3'b101: begin
            unique case(funct7)
            7'b0000000: `INST_W(OP_SRLI, rs1, 5'b0, rd)
            7'b0100000: `INST_W(OP_SRAI, rs1, 5'b0, rd)
            7'b0100100: `INST_W(OP_BEXTI, rs1, 5'b0, rd) // bexti
            7'b0110100: begin
                unique case (rs2)
                5'b00111: `INST_W(OP_BREV8, rs1, 5'b0, rd) // brev8
                5'b11000: `INST_W(OP_REV8, rs1, 5'b0, rd) // rev8
                default: `INST_R(OP_INVALID, 5'b0, 5'b0)
                endcase
            end
            7'b0010100: `INST_W(OP_ORCB, rs1, 5'b0, rd) // orc.b
            7'b0110000: `INST_W(OP_RORI, rs1, 5'b0, rd) // rori
            7'b0000100: `INST_W(OP_UNZIP, rs1, 5'b0, rd) // unzip
            default: `INST_R(OP_INVALID, 5'b0, 5'b0)
            endcase
        end
        3'b110: `INST_W(OP_ORI, rs1, 5'b0, rd)
        3'b111: `INST_W(OP_ANDI, rs1, 5'b0, rd)
        endcase
    end
    OPCODE_REG: begin
        unique case(funct3)
        3'b000: begin
            unique case(funct7[4:0])
            5'b00000: begin
                unique case (funct7[6:5])
                2'b00: `INST_W(OP_ADD, rs1, rs2, rd)
                2'b01: `INST_W(OP_SUB, rs1, rs2, rd)
                default: `INST_R(OP_INVALID, 5'b0, 5'b0)
                endcase
            end
            5'b00001: `INST_W(OP_MUL, rs1, rs2, rd) // mul
            5'b01110: `INST_W(OP_SHA512_SIG0H, rs1, rs2, rd) // sha512sig0h
            5'b01010: `INST_W(OP_SHA512_SIG0L, rs1, rs2, rd) // sha512sig0l
            5'b01111: `INST_W(OP_SHA512_SIG1H, rs1, rs2, rd) // sha512sig1h
            5'b01011: `INST_W(OP_SHA512_SIG1L, rs1, rs2, rd) // sha512sig1l
            5'b01000: `INST_W(OP_SHA512_SUM0R, rs1, rs2, rd) // sha512sum0r
            5'b01001: `INST_W(OP_SHA512_SUM1R, rs1, rs2, rd) // sha512sum1r
            5'b10101: `INST_W(OP_AES32_DSI, rs1, rs2, rd) // aes32dsi
            5'b10111: `INST_W(OP_AES32_DSMI, rs1, rs2, rd) // aes32dsmi
            5'b10001: `INST_W(OP_AES32_ESI, rs1, rs2, rd) // aes32esi
            5'b10011: `INST_W(OP_AES32_ESMI, rs1, rs2, rd) // aes32esmi
            5'b11000: `INST_W(OP_SM4_ED, rs1, rs2, rd) // sm4ed
            5'b11010: `INST_W(OP_SM4_KS, rs1, rs2, rd) // sm4ks
            default: `INST_R(OP_INVALID, 5'b0, 5'b0)
            endcase
        end
        3'b001: begin
            unique case(funct7)
            7'b0000000: `INST_W(OP_SLL, rs1, rs2, rd)
            7'b0000001: `INST_W(OP_MULH, rs1, rs2, rd) // mulh
            7'b0100100: `INST_W(OP_BCLR, rs1, rs2, rd) // bclr
            7'b0010100: `INST_W(OP_BSET, rs1, rs2, rd) // bset
            7'b0110100: `INST_W(OP_BINV, rs1, rs2, rd) // binv
            7'b0000101: `INST_W(OP_CLMUL, rs1, rs2, rd) // clmul
            7'b0110000: `INST_W(OP_ROL, rs1, rs2, rd) // rol
            default:    `INST_R(OP_INVALID, 5'b0, 5'b0)
            endcase 
        end
        3'b010: begin
            unique case(funct7)
            7'b0000000: `INST_W(OP_SLT, rs1, rs2, rd)
            7'b0000001: `INST_W(OP_MULHSU, rs1, rs2, rd) // mulhsu
            7'b0000101: `INST_W(OP_CLMULR, rs1, rs2, rd) // clmulr
            7'b0010000: `INST_W(OP_SH1ADD, rs1, rs2, rd) // sh1add
            7'b0010100: `INST_W(OP_XPERM4, rs1, rs2, rd) // xperm4
            default:    `INST_R(OP_INVALID, 5'b0, 5'b0)
            endcase
        end
        3'b011: begin
            unique case(funct7)
            7'b0000000: `INST_W(OP_SLTU, rs1, rs2, rd)
            7'b0000001: `INST_W(OP_MULHU, rs1, rs2, rd) // mulhu
            7'b0000101: `INST_W(OP_CLMULH, rs1, rs2, rd) // clmulh
            default:    `INST_R(OP_INVALID, 5'b0, 5'b0)
            endcase
        end
        3'b100: begin
            unique case(funct7)
            7'b0000000: `INST_W(OP_XOR, rs1, rs2, rd)
            7'b0000001: `INST_W(OP_DIV, rs1, rs2, rd) // div
            7'b0000101: `INST_W(OP_MIN, rs1, rs2, rd) // min
            7'b0100000: `INST_W(OP_XNOR, rs1, rs2, rd) // xnor
            7'b0010000: `INST_W(OP_SH2ADD, rs1, rs2, rd) // sh2add
            7'b0000100: `INST_W(OP_PACK, rs1, rs2, rd) // pack
            // 7'b0000100: `INST_W(OP_ZEXTH, rs1, 5'b0, rd) // !NOTE: (`zext.h`) == (`pack` when rs2 == 0)
            7'b0010100: `INST_W(OP_XPERM8, rs1, rs2, rd) // xperm8
            default:    `INST_R(OP_INVALID, 5'b0, 5'b0)
            endcase
        end
        3'b101: begin
            unique case(funct7)
            7'b0000000: `INST_W(OP_SRL, rs1, rs2, rd)
            7'b0000001: `INST_W(OP_DIVU, rs1, rs2, rd) // divu
            7'b0000101: `INST_W(OP_MINU, rs1, rs2, rd) // minu
            7'b0100000: `INST_W(OP_SRA, rs1, rs2, rd)
            7'b0100100: `INST_W(OP_BEXT, rs1, rs2, rd) // bext
            7'b0110000: `INST_W(OP_ROR, rs1, rs2, rd) // ror
            default:    `INST_R(OP_INVALID, 5'b0, 5'b0)
            endcase
        end
        3'b110: begin
            unique case(funct7)
            7'b0000000: `INST_W(OP_OR,  rs1, rs2, rd)
            7'b0000001: `INST_W(OP_REM, rs1, rs2, rd) // rem
            7'b0000101: `INST_W(OP_MAX, rs1, rs2, rd) // max
            7'b0100000: `INST_W(OP_ORN, rs1, rs2, rd) // orn
            7'b0010000: `INST_W(OP_SH3ADD, rs1, rs2, rd) // sh3add
            default:    `INST_R(OP_INVALID, 5'b0, 5'b0)
            endcase
        end
        3'b111: begin
            unique case(funct7)
            7'b0000000: `INST_W(OP_AND,  rs1, rs2, rd)
            7'b0000001: `INST_W(OP_REMU, rs1, rs2, rd) // remu
            7'b0000101: `INST_W(OP_MAXU, rs1, rs2, rd) // maxu
            7'b0100000: `INST_W(OP_ANDN, rs1, rs2, rd) // andn
            7'b0000100: `INST_W(OP_PACKH, rs1, rs2, rd) // packh
            default:    `INST_R(OP_INVALID, 5'b0, 5'b0)
            endcase
        end
        endcase
    end
    OPCODE_FENCE: begin // fence.I, for simplicity, need to flush all ICACHE
        imm = itype_imm;
        unique case (funct3)
        3'b000:  `INST_R(OP_FENCE, 5'b0, 5'b0)
        3'b001:  `INST_R(OP_FENCEI, 5'b0, 5'b0)
        default: `INST_R(OP_INVALID, 5'b0, 5'b0)
        endcase
    end
    OPCODE_SYSTEM: begin
        imm = csrtype_imm;
        unique case(funct3)
        3'b000: begin
            unique case(funct7)
            7'b0000000: begin
                unique case(rs2)
                5'b00000: `INST_R(OP_ECALL, 5'b0, 5'b0) // ecall
                5'b00001: `INST_R(OP_EBREAK, 5'b0, 5'b0) // ebreak
                // 5'b00010: `INST_R(OP_URET, 5'b0, 5'b0) // uret, not supported yet.
                default: `INST_R(OP_INVALID, 5'b0, 5'b0)
                endcase
            end
            7'b0001000: begin // sret, wfi
                unique case(rs2)
                5'b00010: begin
                    if (csr.mstatus.tsr && (cpu_mode == MODE_S)) `INST_R(OP_INVALID, 5'b0, 5'b0)
                    else `INST_R(OP_SRET, 5'b0, 5'b0) // sret
                end
                5'b00101: `INST_R(OP_WFI, 5'b0, 5'b0) // wfi
                default: `INST_R(OP_INVALID, 5'b0, 5'b0)
                endcase
            end
            7'b0011000: `INST_R(OP_MRET, 5'b0, 5'b0) // mret, pc <- mepc
            7'b0001001: begin
                if (csr.mstatus.tvm && (cpu_mode == MODE_S)) `INST_R(OP_INVALID, 5'b0, 5'b0)
                else `INST_R(OP_SFENCE, 5'b0, 5'b0) // sfence.vma
            end
            default: `INST_R(OP_INVALID, 5'b0, 5'b0)
            endcase
        end
        3'b001: `INST_W(OP_CSRRW, rs1, 5'b0, rd) // csrrw
        3'b010: `INST_W(OP_CSRRS, rs1, 5'b0, rd) // csrrs
        3'b011: `INST_W(OP_CSRRC, rs1, 5'b0, rd) // csrrc
        3'b100: `INST_R(OP_INVALID, 5'b0, 5'b0)  // hypervisor related insts, not implemented
        3'b101: `INST_W(OP_CSRRWI, 5'b0, 5'b0, rd) // csrrwi
        3'b110: `INST_W(OP_CSRRSI, 5'b0, 5'b0, rd) // csrrsi
        3'b111: `INST_W(OP_CSRRCI, 5'b0, 5'b0, rd) // csrrci
        endcase
    end
    // RV32A Extension
    OPCODE_AMO: begin
        unique case(funct7[6:2])
        5'b00000: `INST_W(OP_AMOADD,  rs1, rs2, rd)
        5'b00001: `INST_W(OP_AMOSWAP,  rs1, rs2, rd)
        5'b00010: `INST_W(OP_LR,  rs1, 5'b0, rd)
        5'b00011: `INST_W(OP_SC,  rs1, rs2, rd)
        5'b00100: `INST_W(OP_AMOXOR,  rs1, rs2, rd)
        5'b01100: `INST_W(OP_AMOAND,  rs1, rs2, rd)
        5'b01000: `INST_W(OP_AMOOR,  rs1, rs2, rd)
        5'b10000: `INST_W(OP_AMOMIN,  rs1, rs2, rd)
        5'b10100: `INST_W(OP_AMOMAX,  rs1, rs2, rd)
        5'b11000: `INST_W(OP_AMOMINU,  rs1, rs2, rd)
        5'b11100: `INST_W(OP_AMOMAXU,  rs1, rs2, rd)
        default:  `INST_R(OP_INVALID, 5'b0, 5'b0)
        endcase
    end
    // RV32F Extension
    OPCODE_FLOAD: begin
        imm = itype_imm;
        if (csr.mstatus.fs == 2'b00) `INST_R(OP_INVALID, 5'b0, 5'b0)
        else `FINST_LOAD(OP_FLWS, rs1, rd)
    end
    OPCODE_FSTORE: begin
        imm = stype_imm;
        if (csr.mstatus.fs == 2'b00) `INST_R(OP_INVALID, 5'b0, 5'b0)
        else `FINST_STORE(OP_FSWS, rs1, rs2)
    end
    OPCODE_FMADD: begin
        if (csr.mstatus.fs == 2'b00) `INST_R(OP_INVALID, 5'b0, 5'b0)
        else `FINST_READ3(OP_FMADDS, rs1, rs2, rs3, 1'b1, rd, rm)
    end
    OPCODE_FMSUB: begin
        if (csr.mstatus.fs == 2'b00) `INST_R(OP_INVALID, 5'b0, 5'b0)
        else `FINST_READ3(OP_FMSUBS, rs1, rs2, rs3, 1'b1, rd, rm)
    end
    OPCODE_FNMSUB: begin
        if (csr.mstatus.fs == 2'b00) `INST_R(OP_INVALID, 5'b0, 5'b0)
        else `FINST_READ3(OP_FNMSUBS, rs1, rs2, rs3, 1'b1, rd, rm)
    end
    OPCODE_FNMADD: begin
        if (csr.mstatus.fs == 2'b00) `INST_R(OP_INVALID, 5'b0, 5'b0)
        else `FINST_READ3(OP_FNMADDS, rs1, rs2, rs3, 1'b1, rd, rm)
    end
    OPCODE_FLOAT: begin
        if (csr.mstatus.fs == 2'b00) `INST_R(OP_INVALID, 5'b0, 5'b0)
        else begin
            unique case(funct7)
            7'b0000000: `FINST_READ2(OP_FADDS, rs1, rs2, 1'b1, rd, rm)
            7'b0000100: `FINST_READ2(OP_FSUBS, rs1, rs2, 1'b1, rd, rm)
            7'b0001000: `FINST_READ2(OP_FMULS, rs1, rs2, 1'b1, rd, rm)
            7'b0001100: `FINST_READ2(OP_FDIVS, rs1, rs2, 1'b1, rd, rm)
            7'b0101100: `FINST_READ1(OP_FSQRTS, rs1, 1'b1, rd, rm)
            7'b0010000: begin
                unique case(funct3)
                3'b000: `FINST_READ2(OP_FSGNJS, rs1, rs2, 1'b1, rd, 3'b000)
                3'b001: `FINST_READ2(OP_FSGNJNS, rs1, rs2, 1'b1, rd, 3'b000)
                3'b010: `FINST_READ2(OP_FSGNJXS, rs1, rs2, 1'b1, rd, 3'b000)
                default: `INST_R(OP_INVALID, 5'b0, 5'b0)
                endcase
            end
            7'b0010100: begin
                unique case(funct3)
                3'b000: `FINST_READ2(OP_FMINS, rs1, rs2, 1'b1, rd, 3'b000)
                3'b001: `FINST_READ2(OP_FMAXS, rs1, rs2, 1'b1, rd, 3'b000)
                default: `INST_R(OP_INVALID, 5'b0, 5'b0)
                endcase
            end
            7'b1100000: begin
                unique case(rs2)
                5'b00000: `FINST_FLOAT2FIX(OP_FCVTWS, rs1, rd, rm)
                5'b00001: `FINST_FLOAT2FIX(OP_FCVTWUS, rs1, rd, rm)
                default: `INST_R(OP_INVALID, 5'b0, 5'b0)
                endcase
            end
            7'b1110000: begin
                unique case(funct3)
                3'b000: `FINST_FLOAT2FIX(OP_FMVXW, rs1, rd, 3'b000)
                3'b001: `FINST_FLOAT2FIX(OP_FCLASSS, rs1, rd, 3'b000)
                default: `INST_R(OP_INVALID, 5'b0, 5'b0)
                endcase
            end
            7'b1010000: begin
                unique case(funct3)
                3'b010: `FINST_CMP(OP_FEQS, rs1, rs2, rd)
                3'b001: `FINST_CMP(OP_FLTS, rs1, rs2, rd)
                3'b000: `FINST_CMP(OP_FLES, rs1, rs2, rd)
                default: `INST_R(OP_INVALID, 5'b0, 5'b0)
                endcase
            end
            7'b1101000: begin
                unique case(rs2)
                5'b00000: `FINST_FIX2FLOAT(OP_FCVTSW, rs1, rd, rm)
                5'b00001: `FINST_FIX2FLOAT(OP_FCVTSWU, rs1, rd, rm)
                default: `INST_R(OP_INVALID, 5'b0, 5'b0)
                endcase
            end
            7'b1111000: begin
                `FINST_FIX2FLOAT(OP_FMVWX, rs1, rd, 3'b000)
            end
            default: `INST_R(OP_INVALID, 5'b0, 5'b0)
            endcase
        end
    end
    default: `INST_R(OP_INVALID, 5'b0, 5'b0)
    endcase
end
endmodule
