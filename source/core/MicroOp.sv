package micro_ops;

typedef enum {
    OP_NOP,

    // RV32I
    // I-logic ops
    OP_ANDI, OP_ORI, OP_XORI, OP_SLLI, OP_SRLI, OP_SRAI,
    // I-arth ops
    OP_ADDI, OP_SLTI, OP_SLTIU,
    // R-logic ops
    OP_AND, OP_OR, OP_XOR, OP_SLL, OP_SRL, OP_SRA,
    // R-arth ops
    OP_ADD, OP_SUB, OP_SLT, OP_SLTU,
    // u-type ops
    OP_LUI, OP_AUIPC,
    // j-type ops
    OP_JAL, OP_JALR,
    // b-type ops
    OP_BEQ, OP_BNE, OP_BLT, OP_BLTU, OP_BGE, OP_BGEU,
    // load/store
    OP_LB, OP_LH, OP_LW, OP_LBU, OP_LHU, OP_SB, OP_SH, OP_SW,
    // PRIV ops
    OP_ECALL, OP_EBREAK,
    OP_MRET, OP_SRET, OP_URET, OP_WFI,
    OP_FENCE, OP_FENCEI,
    
    // RV32 Zifencei Extension. fence ops
    OP_SFENCE,
    // RV32 Zicsr Extension csr R/W ops
    OP_CSRRW, OP_CSRRS, OP_CSRRC, OP_CSRRWI, OP_CSRRSI, OP_CSRRCI,
    
    // TODO: RV32M Extension
    OP_MUL, OP_MULH, OP_MULHSU, OP_MULHU,
    OP_DIV, OP_DIVU, OP_REM, OP_REMU,
    
    // TODO: RV32A Extension
    OP_LR, OP_SC,
    OP_AMOSWAP, OP_AMOADD, OP_AMOXOR, OP_AMOAND, OP_AMOOR,
    OP_AMOMIN, OP_AMOMAX, OP_AMOMINU, OP_AMOMAXU,

    // RV32 Bitmanip Extensions, see: https://github.com/riscv/riscv-bitmanip/releases
    // RV32 Zba Extension
    OP_SH1ADD, OP_SH2ADD, OP_SH3ADD, 
    // RV32 Zbb Extension
    OP_ANDN, OP_ORN, OP_XNOR,
    OP_CLZ, OP_CTZ, OP_CPOP,
    OP_MAX, OP_MAXU, OP_MIN, OP_MINU,
    OP_SEXTB, OP_SEXTH, OP_ZEXTH,
    OP_ROL, OP_ROR, OP_RORI,
    OP_ORCB, OP_REV8,
    // TODO: RV32 Zbc Extension (ALSO IN RV32 Zbkc Extension)
    OP_CLMUL, OP_CLMULH, OP_CLMULR,
    // RV32 Zbs Extension
    OP_BCLR, OP_BCLRI, OP_BEXT, OP_BEXTI, 
    OP_BINV, OP_BINVI, OP_BSET, OP_BSETI,

    // TODO: RV32F Extension (Single Presicion)
    OP_FLWS, OP_FSWS,
    OP_FMADDS, OP_FMSUBS, OP_FNMSUBS, OP_FNMADDS,
    OP_FADDS, OP_FSUBS, OP_FMULS, OP_FDIVS, OP_FSQRTS,
    OP_FMINS, OP_FMAXS,
    OP_FEQS, OP_FLTS, OP_FLES,
    OP_FSGNJS, OP_FSGNJNS, OP_FSGNJXS,
    OP_FCVTWS, OP_FCVTWUS, OP_FMVXW,
    OP_FCVTSW, OP_FCVTSWU, OP_FMVWX,
    OP_FCLASSS,

    // RV32 Cryptography spec.
    // RV32 Zbkb Extension
    OP_PACK, OP_PACKH, OP_BREV8, OP_ZIP, OP_UNZIP,
    // RV32 Zbkx Extension (Crossbar permutation instructions)
    OP_XPERM8, OP_XPERM4,
    // RV32 Zknd Extension (AES Decryption)
    OP_AES32_DSI, OP_AES32_DSMI,
    // RV32 Zkne Extension (AES Encryption)
    OP_AES32_ESI, OP_AES32_ESMI,
    // RV32 Zknh Extension (Hash Function instructions)
    OP_SHA256_SIG0, OP_SHA256_SIG1, OP_SHA256_SUM0, OP_SHA256_SUM1,
    OP_SHA512_SIG0H, OP_SHA512_SIG0L, OP_SHA512_SIG1H, OP_SHA512_SIG1L,
    OP_SHA512_SUM0R, OP_SHA512_SUM1R,
    // RV32 Zksed Extension (SM4 Block Cipher)
    OP_SM4_ED, OP_SM4_KS,
    // RV32 Zksh Extension (SM3 Hash Function instructions)
    OP_SM3_P0, OP_SM3_P1,

    // INVALID
    OP_INVALID
} op_t;

endpackage
 