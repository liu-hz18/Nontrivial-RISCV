// Control Stata Registers
// WPRI: Reserved Writes Preserve Values, Reads Ignore Value
// WLRL: Write/Read Only Legal Value
// WARL: Write Any Values, Reads Legal Value

package csr_def;

import bitutils::*;

typedef enum logic[1:0] {
    MODE_U = 0,
    MODE_S = 1,
    MODE_H = 2, // Hypervisor
    MODE_M = 3
} cpu_mode_t;

cpu_mode_t cpu_mode;

// Machine Mode CSRs
typedef struct packed {
    logic [1:0] mxl; // mxl(Machine XLEN) = 1 when xlen = 32.
    logic [3:0] _wlrl0;
    logic [25:0] extensions; // WARL. [25:0] = {Z, Y, ..., B, A}
} misa_t;

typedef struct packed {
    logic [24:0] bank;
    logic [6:0] offset;
} mvendorid_t;

typedef logic [31:0] marchid_t;
typedef logic [31:0] mimpid_t;
typedef logic [31:0] mhartid_t;

typedef struct packed {
    logic sd;
    logic [7:0] _wpri0;
    logic tsr;
    logic tw;
    logic tvm;
    logic mxr;
    logic sum;
    logic mprv; // reset to 0
    logic [1:0] xs;
    logic [1:0] fs;
    logic [1:0] mpp;
    logic [1:0] _wpri1;
    logic spp;
    logic mpie;
    logic ube;
    logic spie;
    logic _wpri2;
    logic mie; // reset to 0
    logic _wpri3;
    logic sie;
    logic _wpri4;
} mstatus_t;

typedef struct packed {
    logic [25:0] _wpri0;
    logic mbe;
    logic sbe;
    logic [3:0] _wpri1;
} mstatush_t;

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

typedef struct packed {
    logic interrupt;
    logic [30:0] exception_code;
} mcause_t;

typedef struct packed {
    logic [29:0] base;
    logic [1:0] mode;
} mtvec_t;

typedef logic [31:0] mcounteren_t; // hpm31...hpm3 | ir | tm | cy
typedef logic [31:0] mcountinhibit_t;
typedef logic [31:0] medeleg_t;
typedef logic [31:0] mideleg_t;
typedef logic [31:0] mepc_t;
typedef logic [31:0] mtval_t;
typedef logic [31:0] mscratch_t;
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
    logic [21:0] _wpri0;
    logic sseed;
    logic useed;
    logic [4:0] _wpri1;
    logic rlb;
    logic mmwp;
    logic mml;
} mseccfg_t;


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
    logic [24:0] _zero;
    logic [2:0] frm;
    // fflags
    logic _NV; // INVALID OPERATION
    logic _DZ; // DIVIDE by ZERO
    logic _OF; // Overflow
    logic _UF; // Underflow
    logic _NX; // Inexact
} fcsr_t;

typedef struct packed {
    logic [1:0] opst; // BIST(00), WAIT(01), ES16(10), DEAD(11)
    logic [5:0] _zero;
    logic [7:0] custom; // Designated for custom and experimental use.
    logic [15:0] entropy; // 16 bits of randomness, only when OPST=ES16.
} seed_t;

endpackage
