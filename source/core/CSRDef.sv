// Control Stata Registers
// WPRI: Reserved Writes Preserve Values, Reads Ignore Value (read-only zero)
// WLRL: Write/Read Only Legal Value
// WARL: Write Any Values, Reads Legal Value

package csr_def;

import bitutils::*;

typedef enum logic[1:0] {
    MODE_U = 0, // 00
    MODE_S = 1, // 01
    MODE_H = 2, // Hypervisor
    MODE_M = 3  // 11
} cpu_mode_t;

// Machine Mode CSRs
typedef struct packed {
    logic [1:0] mxl; // mxl(Machine XLEN) = 1 when xlen = 32.
    logic [3:0] _wlrl0;
    logic [25:0] extensions; // WARL. [25:0] = {Z, Y, ..., B, A}
} misa_t;
parameter misa_t MISA_INIT = { 
    2'b01, // mxl
    4'b0,  // WLRL
    1'b0,  // A
    1'b1,  // Bitmanip
    1'b0,  // C Extension
    1'b0,  // D
    1'b0,  // E
    1'b1,  // F
    1'b0,  // G, Reserved
    1'b0,  // Hypervisor
    1'b1,  // I
    1'b0,  // Dynamically Translated Languages Extension
    1'b0,  // K, Reserved
    1'b0,  // L, Reserved
    1'b1,  // M
    1'b0,  // User-level Interrupts Extension
    1'b0,  // O, Reserved
    1'b0,  // P, Packed-SIMD
    1'b0,  // Q
    1'b0,  // R, Reserved
    1'b1,  // Supervisor mode implemented
    1'b0,  // T
    1'b1,  // User mode implemented
    1'b0,  // V
    1'b0,  // W
    1'b0,  // Non-Standard extension
    1'b0,  // Y, Reserved
    1'b0   // Z, Reserved
};
parameter misa_t MISA_WMASK = {
    2'b00,
    4'b0,
    1'b0,  // A
    1'b1,  // Bitmanip
    1'b0,  // C Extension
    1'b0,  // D
    1'b0,  // E
    1'b1,  // F
    1'b0,  // G, Reserved
    1'b0,  // Hypervisor
    1'b0,  // I
    1'b0,  // Dynamically Translated Languages Extension
    1'b0,  // K, Reserved
    1'b0,  // L, Reserved
    1'b1,  // M
    1'b0,  // User-level Interrupts Extension
    1'b0,  // O, Reserved
    1'b0,  // P, Packed-SIMD
    1'b0,  // Q
    1'b0,  // R, Reserved
    1'b1,  // Supervisor mode implemented
    1'b0,  // T
    1'b1,  // User mode implemented
    1'b0,  // V
    1'b0,  // W
    1'b0,  // Non-Standard extension
    1'b0,  // Y, Reserved
    1'b0   // Z, Reserved
};

typedef struct packed {
    logic [24:0] bank;
    logic [6:0] offset;
} mvendorid_t; // read-only
parameter mvendorid_t MVENDORID_INIT = '0; // non-commercial implementation
typedef logic [31:0] marchid_t;
parameter marchid_t MARCHID_INIT = '0; // return 0 to indicate the field is not implemented
typedef logic [31:0] mimpid_t;
parameter mimpid_t MIMPID_INIT = '0; // provides a unique encoding of the version of the processor implementation
typedef logic [31:0] mhartid_t;
parameter mhartid_t MHARTID_INIT = '0; // the hardware thread running the code

// !when a trap is taken from mode Y to mode X, XPIE is set to XIE, and XIE is set to 0, and XPP is set to Y, `cpu_mode` is set to X
// !when a XRET(mret, sret) is executed, if XPP is Y originally: XIE is set to XPIE, `cpu_mode` is set to Y, XPIE is set to 1, XPP is set to U. (if Y is M, XRET also set MPRV to 0)
typedef struct packed {
    logic sd;
    logic [7:0] _wpri0;
    logic tsr; // if tsr=1, attempts to execute a `sret` in S-mode raise a illegal inst exception. if tsr=0, this operation is permitted.
    logic tw;  // if tw=0, `wfi` inst can execute in lower priviledge modes. if tw=1, `wfi` cannot execute in U and S modes. 
    logic tvm; // if tvm=1, attempts to read or write `satp` or execute a `sfence.vma` inst in S-mode will raise an illegal instruction exception. if tvm=0, these operations are permitted.
    logic mxr; // if mxr=0, only loads from pages marked R will succ. if mxr=1, loads from pages marked R or X will succ.
    logic sum; // if sum=0, S-mode memory access to pages marked U will fault. when sum=1, these accessed are permitted. (sum also takes effect when MPRV=1 and MPP=S)
    logic mprv; // reset to 0, if mprv=0, loads and stores behave as normal. if mprv=1, loads and stores behave as cpu_mode=MPP
    logic [1:0] xs;
    logic [1:0] fs;
    logic [1:0] mpp; // previous privilege mode (can hold mode M, S, U)
    logic [1:0] _wpri1;
    logic spp; // previous privilege mode (can hold mode S, U)
    logic mpie; // the value of mie prior to a trap
    logic ube; // L/S accesses from U-mode is little-endian(ube=0) or big-endian(ube=1), (sbe also takes effect when MPRV=1 and MPP=U)
    logic spie; // the value of sie prior to a trap
    logic _wpri2;
    logic mie; // reset to 0, machine mode interrput global enable
    logic _wpri3;
    logic sie; // supervisor mode interrput global enable
    logic _wpri4;
} mstatus_t;
// TODO: read spec and confirm these values
parameter mstatus_t MSTATUS_INIT = {
    1'b0, // sd
    8'b0, // WPRI
    1'b0, // tsr
    1'b0, // tw
    1'b0, // tvm
    1'b0, // mxr 
    1'b0, // sum
    1'b0, // mprv
    2'b00, // xs
    2'b00, // fs
    
    2'b11, // mpp
    
    2'b00, // WPRI
    1'b0, // spp
    
    1'b0, // mpie
    1'b0, // ube
    1'b0, // spie
    1'b0, // WPRI
    
    1'b0, // mie
    1'b0, // WPRI
    1'b0, // sie
    1'b0 // WPRI
};
parameter mstatus_t MSTATUS_WMASK = {
    1'b0, // sd
    8'b0, // WPRI
    1'b0, // tsr
    1'b0, // tw
    1'b0, // tvm
    1'b0, // mxr 
    1'b0, // sum
    1'b0, // mprv
    2'b00, // xs
    2'b00, // fs
    2'b00, // mpp
    2'b00, // WPRI
    1'b0, // spp
    1'b0, // mpie
    1'b0, // ube
    1'b0, // spie
    1'b0, // WPRI
    1'b0, // mie
    1'b0, // WPRI
    1'b0, // sie
    1'b0 // WPRI
};

// ! `sbe` and `ube` can just be a copy of `mbe`
typedef struct packed {
    logic [25:0] _wpri0;
    logic mbe; // L/S accesses from M-mode is little-endian(ube=0) or big-endian(ube=1)
    logic sbe; // L/S accesses from S-mode is little-endian(ube=0) or big-endian(ube=1), (sbe also takes effect when MPRV=1 and MPP=S)
    logic [3:0] _wpri1;
} mstatush_t;
parameter mstatush_t MSTATUSH_INIT = {
    26'b0, // WPRI
    1'b0, // mbe
    1'b0, // sbe
    4'b0 // WPRI
};
parameter mstatush_t MSTATUSH_WMASK = {
    26'b0, // WPRI
    1'b0, // mbe
    1'b0, // sbe
    4'b0 // WPRI
};

typedef struct packed {
    logic [19:0] _zero0;
    logic meip;
    logic _zero1;
    logic seip;
    logic _zero2;
    logic mtip;
    logic _zero3;
    logic stip;
    logic _zero4;
    logic msip;
    logic _zero5;
    logic ssip;
    logic _zero6;
} mip_t;
parameter mip_t MIP_INIT = {

};
parameter mip_t MIP_WMASK = {

};

typedef struct packed {
    logic [19:0] _zero0;
    logic meie;
    logic _zero1;
    logic seie;
    logic _zero2;
    logic mtie;
    logic _zero3;
    logic stie;
    logic _zero4;
    logic msie;
    logic _zero5;
    logic ssie;
    logic _zero6;
} mie_t;
parameter mie_t MIE_INIT = {};
parameter mie_t MIE_WMASK = {};

typedef struct packed {
    logic interrupt;
    logic [30:0] exception_code;
} mcause_t;
parameter mcause_t MCAUSE_INIT = {};
parameter mcause_t MCAUSE_WMASK = {};

typedef struct packed {
    logic [29:0] base;
    logic [1:0] mode;
} mtvec_t;
parameter mtvec_t MTVEC_INIT = {};
parameter mtvec_t MTVEC_WMASK = {};

typedef logic [31:0] mcounteren_t; // hpm31...hpm3 | ir | tm | cy
parameter mcounteren_t MCOUNTEREN_WMASK = '1;
typedef logic [31:0] medeleg_t;
parameter medeleg_t MEDELEG_WMASK = '1;
typedef logic [31:0] mideleg_t;
parameter mideleg_t MIDELEG_WMASK = '1;
typedef logic [31:0] mepc_t;
parameter mepc_t MEPC_WMASK = '1;
typedef logic [31:0] mtval_t;
parameter mepc_t MTVAL_WMASK = '1;
typedef logic [31:0] mscratch_t;
parameter mscratch_t MSCRACH_WMASK = '1;
typedef logic [31:0] mconfigptr_t;
typedef struct packed { // 64bit but can only be accessed by 2 csr access insts.
    logic mtce;
    logic pbmte;
    logic [53:0] _wpri0;
    logic cbze;
    logic cbcfe;
    logic [1:0] cbie;
    logic [2:0] _wpri1;
    logic fiom;
} menvcfg_t; // !NOTE: {menvcfgh, menvcfg}(RV32) = menvcfg (RV64);
typedef struct packed {
    logic [53:0] _wpri0;
    logic sseed;
    logic useed;
    logic [4:0] _wpri1;
    logic rlb;
    logic mmwp;
    logic mml;
} mseccfg_t;
typedef logic [63:0] mcycle_t;
typedef logic [63:0] minstret_t;
typedef logic [63:0] mhpmcounter_t;
typedef logic [31:0] mhpmevent_t;
typedef logic [63:0] mtime_t;
typedef logic [63:0] mtimecmp_t;

// PMP CSRs
// implementations may implement 0, 16 or 64 PMP entries (a.k.a 0, 4 or 16 PMP CSRs)
// PMP Configuration Registers
// pmpcfg 32bits = pmp3cfg | pmp2cfg | pmp1cfg | pmp0cfg
// pmpxcfg 8bits = L | 00 | A | X | W | R
//                 1        2   1   1   1
typedef logic [31:0] pmpcfg_t; 

// PMP Address Registers, they hold physical address[33:2] bits.
// !pmpaddr regs are WARL
typedef logic [31:0] pmpaddr_t;

// exception code in mcause
// !exception handle priority from high to low
// i-breakpoint > i-page fault > i-access fault >
// illegal inst > inst_addr_misaligned > 
// ecall > ebreak > 
// store-addr misaligned > load-addr misaligned >
// store-page fault > load page fault >
// store-access fault > load-access fault
// !NOTE: misaligned exception are raised by control-flow instructions (EXU), not by IFU
`define MCAUSE_SMODE_SOFT_INT        {1'b1, 31'd1}
`define MCAUSE_MMODE_SOFT_INT        {1'b1, 31'd3}
`define MCAUSE_SMODE_TIMER_INT       {1'b1, 31'd5}
`define MCAUSE_MMODE_TIMER_INT       {1'b1, 31'd7}
`define MCAUSE_SMODE_EXT_INT         {1'b1, 31'd9}
`define MCAUSE_MMODE_EXT_INT         {1'b1, 31'd11}
`define MCAUSE_INST_ADDR_MISALIGNED  32'd0
`define MCAUSE_INST_ACCESS_FAULT     32'd1 // for PMP only
`define MCAUSE_ILLEGAL_INST          32'd2
`define MCAUSE_BREAKPOINT            32'd3
`define MCAUSE_LOAD_ADDR_MISALIGNED  32'd4
`define MCAUSE_LOAD_ACCESS_FAULT     32'd5 // for PMP only
`define MCAUSE_STORE_ADDR_MISALIGNED 32'd6
`define MCAUSE_STORE_ACCESS_FAULT    32'd7 // for PMP only
`define MCAUSE_ECALL_U               32'd8
`define MCAUSE_ECALL_S               32'd9
`define MCAUSE_ECALL_M               32'd11
`define MCAUSE_INST_PAGE_FAULT       32'd12
`define MCAUSE_LOAD_PAGE_FAULT       32'd13
`define MCAUSE_STORE_PAGE_FAULT      32'd15


// Supervisor Mode CSRs
typedef struct packed {
    logic sd;
    logic [10:0] _wpri0;
    logic mxr;
    logic sum;
    logic _wpri1;
    logic [1:0] xs;
    logic [1:0] fs;
    logic [3:0] _wpri2;
    logic spp;
    logic _wpri3;
    logic ube;
    logic spie;
    logic [2:0] _wpri4;
    logic sie;
    logic _wpri5;
} sstatus_t;

typedef struct packed {
    logic [29:0] base;
    logic [1:0] mode;
} stvec_t;

typedef struct packed {
    logic [21:0] _zero0;
    logic seip;
    logic [2:0] _zero1;
    logic stip;
    logic [2:0] _zero2;
    logic ssip;
    logic _zero3;
} sip_t;

typedef struct packed {
    logic [21:0] _zero0;
    logic seie;
    logic [2:0] _zero1;
    logic stie;
    logic [2:0] _zero2;
    logic ssie;
    logic _zero3;
} sie_t;

typedef struct packed {
    logic interrupt;
    logic [30:0] exception_code;
} scause_t;

typedef struct packed {
    logic mode; // 0 means bare(no translation), 1 means SV32 virtual addressing.
    logic [8:0] asid;
    logic [21:0] ppn;
} satp_t;

typedef struct packed {
    logic [23:0] _wpri0;
    logic cbze;
    logic cbcfe;
    logic [1:0] cbie;
    logic [2:0] _wpri1;
    logic fiom;
} senvcfg_t;

typedef logic [31:0] scounteren_t;
typedef logic [31:0] sscratch_t;
typedef logic [31:0] sepc_t;
typedef logic [31:0] stval_t;

// exception code in scause
// !exception handle priority from high to low
// i-breakpoint > i-page fault > i-access fault >
// illegal inst > inst_addr_misaligned > 
// ecall > ebreak > 
// store-addr misaligned > load-addr misaligned >
// store-page fault > load page fault >
// store-access fault > load-access fault
// !NOTE: misaligned exception are raised by control-flow instructions (EXU), not by IFU
`define SCAUSE_SMODE_SOFT_INT        {1'b1, 31'd1}
`define SCAUSE_SMODE_TIMER_INT       {1'b1, 31'd5}
`define SCAUSE_SMODE_EXT_INT         {1'b1, 31'd9}
`define SCAUSE_INST_ADDR_MISALIGNED  32'd0
`define SCAUSE_INST_ACCESS_FAULT     32'd1
`define SCAUSE_ILLEGAL_INST          32'd2
`define SCAUSE_BREAKPOINT            32'd3
`define SCAUSE_LOAD_ADDR_MISALIGNED  32'd4
`define SCAUSE_LOAD_ACCESS_FAULT     32'd5
`define SCAUSE_STORE_ADDR_MISALIGNED 32'd6
`define SCAUSE_STORE_ACCESS_FAULT    32'd7
`define SCAUSE_ECALL_U               32'd8
`define SCAUSE_ECALL_S               32'd9
`define SCAUSE_INST_PAGE_FAULT       32'd12
`define SCAUSE_LOAD_PAGE_FAULT       32'd13
`define SCAUSE_STORE_PAGE_FAULT      32'd15


typedef enum [2:0] {
    RNE = 3'b000, // round to nearest, ties to even
    RTZ = 3'b001, // round towards zero
    RDN = 3'b010, // round down towards -inf
    RUP = 3'b011, // round up towards +inf
    RMM = 3'b100, // round to nearest, ties to max magnitude
    INVALID0 = 3'b101, // invalid
    INVALID1 = 3'b110, // invalid
    DYN = 3'b111 // invalid in fcsr, dynamic in instrucitons
} rounding_mode_t;

// Floating Point CSR
typedef struct packed {
    logic _NV; // INVALID OPERATION
    logic _DZ; // DIVIDE by ZERO
    logic _OF; // Overflow
    logic _UF; // Underflow
    logic _NX; // Inexact
} fflags_t;

typedef struct packed {
    logic [24:0] _zero;
    logic [2:0] frm;
    fflags_t fflags;
} fcsr_t;

// !seed must be accessed with a read-write instruction
// A  read-only  instruction  such  as  CSRRS/CSRRC with rs1=x0 or CSRRSI/CSRRCI with uimm=0 will raise an illegal instruction exception.
// The  seed  CSR  is  by  default  only  available  in  M  mode,  but  can  be  made  available  to  other  modes  via  the mseccfg.sseed and mseccfg.useed access control bits.
typedef struct packed {
    logic [1:0] opst; // BIST(00), WAIT(01), ES16(10), DEAD(11)
    logic [5:0] _zero;
    logic [7:0] custom; // Designated for custom and experimental use.
    logic [15:0] entropy; // 16 bits of randomness, only when OPST=ES16.
} seed_t;

// User Level CSRs (not implemented)
typedef logic [31:0] uepc_t;

typedef struct packed {
    // Unprivileged CSRs
    seed_t seed;
    fcsr_t fcsr;
    // mcycle_t mcycle; // 64 bit
    // mtime_t mtime; // 64 bits
    // minstret_t minstret; // 64 bit
    mhpmcounter_t [31:0] mhpmcounters; // 64 bit per reg. [0] is mcycle, [1] is mtime, [2] is minstret.
    mhpmevent_t [31:0] mhpmevents; // MXLEN bit
    mtimecmp_t mtimecmp; // 64 bits
    
    // supervisor-level CSRs
    // !sstatus is a R/W shadow of mstatus
    // sstatus_t sstatus;
    // !sie is a R/W shadow of mie
    // sie_t sie;
    // !sip is a R/W shadow of mip
    // sip_t sip;
    stvec_t stvec;
    scounteren_t scounteren;
    senvcfg_t senvcfg;
    sscratch_t sscratch;
    sepc_t spec;
    scause_t scause;
    stval_t stval;
    satp_t satp;

    // machine-level CSRs
    // machine information regs
    mvendorid_t mvendorid;
    marchid_t marchid;
    mimpid_t mimpid;
    mhartid_t mhartid;
    mconfigptr_t mconfigptr;
    // machine trap setup
    mstatus_t mstatus;
    misa_t misa;
    medeleg_t medeleg;
    mideleg_t mideleg;
    mie_t mie;
    mtvec_t mtvec;
    mcounteren_t mcounteren;
    mstatush_t mstatush;
    // machine trap handling
    mscratch_t mscratch;
    mepc_t mepc;
    mcause_t mcause;
    mtval_t mtval;
    mip_t mip;
    // machine configuration
    menvcfg_t menvcfg; // 64bit
    mseccfg_t mseccfg; // 64bit
    // machine memory protection
    pmpcfg_t [3:0] pmpcfgs; // index is 2 bit width
    pmpaddr_t [15:0] pmpaddrs; // index is 4 bit width
} csr_t;

endpackage
