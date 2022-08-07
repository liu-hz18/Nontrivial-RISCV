// bundles between stages
package bundle;

import bitutils::*;
import exception::*;
import micro_ops::*;

typedef enum logic[1:0] {
    BRANCH,
    JUMP,
    INDIRECT,
    RETURN
} btb_type_t;

typedef struct {
    logic valid;
    word_t pc;
    logic is_miss_predict;
    word_t actual_target;
    logic actual_taken;
    btb_type_t btb_type;
    logic is_branch_inst;
    logic is_call_inst;
    logic is_ret_inst;
    logic same_link_regs;
} bpu_update_req_t;

typedef struct {
    word_t pc;
    logic valid;
} bpu_query_req_t;

typedef struct packed {
    logic [9:0] vpn1;
    logic [9:0] vpn0;
    logic [11:0] page_offset;
} vaddr_t;
typedef  struct packed {
    logic [11:0] ppn1;
    logic [9:0] ppn0;
    logic [11:0] page_offset;
} paddr_t;

// self-defined Bus Signals.
// do handshake using `valid` and `ready` signal.
// �? word �?1个传输单位，支持突发读写，最多突�? 16 word 突发读写
typedef struct {
    // write passage
    // W addr passage
    logic awvalid;
    paddr_t waddr;
    logic [3:0] wlen; // burst transmission. >=1 is valid. 0 means no write request.
    logic wlast; // last burst word
    // W data passage
    logic wvalid;
    word_t wdata;
    logic [3:0] wstrb; // byte enable signal
    // W response passage
    logic bready;

    // read passage
    // R addr passage
    logic arvalid;
    paddr_t araddr;
    logic [3:0] rlen; // burst transmission. >=1 is valid. 0 means no read request.
    // R response passage
    logic rready;
} bus_query_req_t;

typedef struct {
    // write passage
    // W addr passage
    logic awready;
    // W response passage
    logic wready; // write one data successfully.
    logic bvalid;

    // read passage
    // R addr passage
    logic rready;
    // R data(response) passage
    logic rvalid;
    logic rlast; // last burst word
    word_t rdata;
} bus_query_resp_t;

typedef struct {
    logic is_branch_jump;
    logic is_branch;
    logic is_call;
    logic is_ret;
    logic same_link_regs;
    logic is_aes_sm4;
    logic is_fpu_multi_cycle;
    logic is_mdu_multi_cycle;
    logic is_load;
    logic is_store;
    logic is_amo;
    logic is_lr;
    logic is_sc;
    // for illegal inst check
    logic is_fpu_inst;
    logic is_sret;
    logic read_csr;
    logic write_csr;
} inst_type_t;

typedef struct {
    logic valid;
    word_t pc;
    word_t inst;
    op_t op;
    except_t exception;
    word_t except_val;
    word_t bpu_predict_target;
    logic bpu_predict_valid;
    
    word_t imm;
    logic [4:0] shamt;

    // bpu control
    inst_type_t inst_type;
    
    gpr_addr_t gpr_rd;
    logic gpr_we;
    word_t gpr_rs1;
    word_t gpr_rs2;

    logic fpr_we;
    fpr_addr_t fpr_rd;
    word_t fpr_rs1;
    word_t fpr_rs2;
    word_t fpr_rs3;
    logic [2:0] fp_rounding_mode;
} frontend_packet_t;

typedef struct {
    logic gpr_we;
    gpr_addr_t gpr_waddr;
    word_t gpr_wdata;
    // fpu support
    logic fpr_we;
    fpr_addr_t fpr_waddr;
    word_t fpr_wdata;
    logic need_load;
} bypass_t;

typedef struct {
    logic load, store;
    logic [3:0] mask;
    word_t addr;
    word_t wdata;
} mem_req_t;

endpackage
