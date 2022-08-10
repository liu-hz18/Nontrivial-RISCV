// inst fetch
import bitutils::*;
import bundle::*;
import csr_def::*;
import exception::*;

module IFU #(
    // bpu parameters
    parameter BPU_NUM_BTB_ENTRIES = 512, // must be power of 2
    parameter BPU_NUM_RAS = 16, // must be power of 2
    // icache parameters
    parameter ICACHE_NUM_WAYS = 4, // must be power of 2
    parameter ICACHE_NUM_SETS = 128, // must be power of 2
    parameter ICACHE_DATA_WIDTH = 32, // must be power of 2
    parameter ICACHE_LINE_WIDTH = 256, // must be power of 2
    // itlb parameters
    parameter ITLB_NUM_WAYS = 2, // must be power of 2
    parameter ITLB_NUM_SETS = 64 // must be power of 2
) (
    input clk, rst,
    
    input logic flush,
    input logic cpu_busy,
    input word_t redirect_pc,
    input bpu_update_req_t bpu_update_req,

    input satp_t csr_satp,
    input sstatus_t csr_sstatus,
    input cpu_mode_t cpu_mode,
    
    // send to idu stage
    output word_t ifu_pc,
    output word_t ifu_inst,
    output except_t ifu_exception,
    output word_t ifu_except_val, // for mtval and stval.
    output word_t bpu_predict_target,
    output logic bpu_predict_valid,

    // control signals
    output logic ifu_busy,

    // bus signals
    output bus_query_req_t bus_req,
    input bus_query_resp_t bus_resp
);

word_t predict_target;
logic predict_valid;

// pc-stage (IF-1 stage)
word_t pc, npc;
always_comb begin: gen_npc
    if (flush) begin
        npc = redirect_pc;
    end else if (predict_valid) begin
        npc = predict_target;
    end else begin
        npc = { pc[31:2] + 30'd1, 2'b0 };
    end
end
always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
        pc <= 32'h8000_0000;
    end else if (~ifu_busy && ~cpu_busy) begin
        pc <= npc;
    end
end

// BPU
// BPU prediction result is given in next cycle (IF-2 stage)
bpu_query_req_t bpu_query_req;
assign bpu_query_req.pc = npc;
assign bpu_query_req.valid = 1'b1;

BPU #(
    .NUM_BTB_ENTRIES(BPU_NUM_BTB_ENTRIES),
    .NUM_RAS(BPU_NUM_RAS)
) BPU (
    .clk(clk),
    .rst(rst),
    
    .query_req(bpu_query_req),
    .predict_target(predict_target),
    .predict_valid(predict_valid),
    
    .flush(flush),

    .update_req(bpu_update_req)
);




// I-CACHE
// basic parameters definition
localparam int ICACHE_SIZE = ICACHE_LINE_WIDTH * ICACHE_NUM_SETS * ICACHE_NUM_WAYS; // bits
localparam int ICACHE_DATA_PER_LINE = ICACHE_LINE_WIDTH / ICACHE_DATA_WIDTH;
localparam int ICACHE_INDEX_WIDTH = $clog2(ICACHE_NUM_SETS);
localparam int ICACHE_BYTE_OFFSET = $clog2(ICACHE_DATA_WIDTH / 8); // 1 byte = 8 bit
localparam int ICACHE_BLOCK_INDEX_WIDTH = $clog2(ICACHE_DATA_PER_LINE);
localparam int ICACHE_BLOCK_OFFSET = ICACHE_BLOCK_INDEX_WIDTH + ICACHE_BYTE_OFFSET;
localparam int ICACHE_TAG_WIDTH = ICACHE_DATA_WIDTH - ICACHE_INDEX_WIDTH - ICACHE_BLOCK_OFFSET;
localparam int ICACHE_META_WIDTH = ICACHE_TAG_WIDTH+1; // tag | valid
localparam int ICACHE_WAY_INDEX_WIDTH = $clog2(ICACHE_NUM_WAYS);

// icache_line_t 在 logic [a:0][b:0] 形式的声明下, 其实是一维数组 packed array
typedef logic [ICACHE_DATA_PER_LINE-1:0][ICACHE_DATA_WIDTH-1:0] icache_line_t;
typedef logic [ICACHE_INDEX_WIDTH-1:0] icache_index_t;
typedef logic [ICACHE_BLOCK_INDEX_WIDTH-1:0] icache_offset_t;
typedef logic [ICACHE_TAG_WIDTH-1:0] icache_tag_t;
typedef logic [ICACHE_META_WIDTH-1:0] icache_meta_t;
generate
    if (ICACHE_NUM_WAYS <= 1) begin: icache_no_way_association
        // define nothing
    end else begin: icache_multi_way_enable
        `define ICACHE_MULTI_WAY
    end
endgenerate

function icache_index_t icache_get_addr_index(input word_t addr);
    return addr[ICACHE_BLOCK_OFFSET+ICACHE_INDEX_WIDTH-1:ICACHE_BLOCK_OFFSET];
endfunction;

function icache_tag_t icache_get_addr_tag(input word_t addr);
    return addr[ICACHE_DATA_WIDTH-1:ICACHE_BLOCK_OFFSET+ICACHE_INDEX_WIDTH];
endfunction;

function icache_offset_t icache_get_addr_offset(input word_t addr);
    return addr[ICACHE_BLOCK_OFFSET-1:ICACHE_BYTE_OFFSET];
endfunction;

function icache_tag_t icache_get_meta_tag(input icache_meta_t meta);
    return meta[ICACHE_META_WIDTH-1:1];
endfunction;

// multi-way set associate icache
// meta cache R/W signals
// W
logic [ICACHE_NUM_WAYS-1:0] icache_meta_wens;
icache_index_t icache_meta_waddr;
icache_meta_t icache_meta_wline;
// R
logic icache_meta_ren;
icache_index_t icache_meta_raddr;
icache_meta_t [ICACHE_NUM_WAYS-1:0] icache_meta_rlines_unsafe, icache_meta_rlines;
// icache meta bram
// tag | valid
for (genvar i = ICACHE_NUM_WAYS-1; i >= 0; --i) begin: gen_meta_icache
    BRAM #(
        .NAME("ICACHE_META"),
        .LINE_WIDTH(ICACHE_META_WIDTH), // tag | valid
        .DEPTH(ICACHE_NUM_SETS)
    ) icache_meta (
        .clk(clk),
        .rst(rst),
        // write port
        .wen(icache_meta_wens[i]),
        .waddr(icache_meta_waddr),
        .wline(icache_meta_wline),
        // read port 
        .ren(icache_meta_ren),
        .raddr(icache_meta_raddr),
        .rline(icache_meta_rlines_unsafe[i]) // output
    );
end

// data cache R/W signals
// W
logic [ICACHE_NUM_WAYS-1:0] icache_data_wens;
icache_index_t icache_data_waddr;
icache_line_t icache_data_wline;
// R
logic icache_data_ren;
icache_index_t icache_data_raddr;
icache_line_t [ICACHE_NUM_WAYS-1:0] icache_data_rlines_unsafe, icache_data_rlines;
// icache data bram
// word | ... | word
for (genvar i = ICACHE_NUM_WAYS-1; i >= 0; --i) begin: gen_data_icache
    BRAM #(
        .NAME("ICACHE_DATA"),
        .LINE_WIDTH(ICACHE_LINE_WIDTH), // a cache block
        .DEPTH(ICACHE_NUM_SETS)
    ) icache_data (
        .clk(clk),
        .rst(rst),
        // write port
        .wen(icache_data_wens[i]),
        .waddr(icache_data_waddr),
        .wline(icache_data_wline),
        // read port 
        .ren(icache_data_ren),
        .raddr(icache_data_raddr),
        .rline(icache_data_rlines_unsafe[i])
    );
end

// random replacement policy, LFSR
`ifdef ICACHE_MULTI_WAY
logic update_icache_random_generator;
dword_t icache_random_dword;
logic [ICACHE_WAY_INDEX_WIDTH-1:0] icache_random_way_index;
assign icache_random_way_index = icache_random_dword[ICACHE_WAY_INDEX_WIDTH-1:0];
LFSR64 #(
    .NAME("ICACHE_RANDOM_GENERATOR"),
    .RANDOM_SEED(64'h1234_5678_8765_4321)
) icache_random_generator (
    .rst(rst),
    .clk(clk),
    .update(update_icache_random_generator),
    .lfsr(icache_random_dword)
);
`endif


// ITLB
// SV32 page table entry: (2^10 entries) 4KiB page, 2-level
//  PPN[1] | PPN[2] | RSW | D | A | G | U | X | W | R | V
//    12       10      2    1...
// SV32 Vaddr:
//  VPN[1] | VPN[0] | page offset
//    10       10         12
// SV32 Paddr:
//  PPN[1] | PPN[2] | page offset
//    12       10         12
// satp register, ASID is used for TLB
//  MODE  |  ASID  |  PPN
//    1        9       22
// TLB entry: (we designed)
//  ASID | D | A | G | U | X | W | R | V | tag | ppn
//    9    1...                                   22
// SV32 Vaddr:
//  tag | index | page offset
//     20             12
localparam int ITLB_NUM_ENTRIES = ITLB_NUM_WAYS * ITLB_NUM_SETS;
localparam int ITLB_WAY_INDEX_WIDTH = $clog2(ITLB_NUM_WAYS);
localparam int ITLB_INDEX_WIDTH = $clog2(ITLB_NUM_SETS);
localparam int ITLB_PAGE_OFFSET_WIDTH = 12;
localparam int ITLB_TAG_WIDTH = 32 - ITLB_PAGE_OFFSET_WIDTH - ITLB_INDEX_WIDTH;
typedef struct packed {
    logic valid;
    logic _super; // is superpage.
    logic [8:0] asid;
    logic [1:0] _rsw;
    logic _D, _A, _G, _U, _X, _W, _R, _V;
    logic [ITLB_TAG_WIDTH-1:0] tag;
    logic [21:0] ppn;
} itlb_entry_t;
typedef struct packed {
    logic [11:0] ppn1;
    logic [9:0] ppn0;
    logic [1:0] _rsw;
    logic _D, _A, _G, _U, _X, _W, _R, _V;
} pte_t;
typedef logic [ITLB_TAG_WIDTH-1:0] itlb_tag_t;
typedef logic [ITLB_INDEX_WIDTH-1:0] itlb_index_t;
typedef logic [ITLB_PAGE_OFFSET_WIDTH-1:0] itlb_page_offset_t;
typedef logic [21:0] ppn_t;
generate
    if (ITLB_NUM_WAYS <= 1) begin: itlb_no_way_association
        // define nothing
    end else begin: itlb_multi_way_enable
        `define ITLB_MULTI_WAY
    end
endgenerate

function itlb_tag_t itlb_get_tag(input word_t vaddr);
    return vaddr[31:ITLB_INDEX_WIDTH+ITLB_PAGE_OFFSET_WIDTH];
endfunction;
function itlb_index_t itlb_get_index(input word_t vaddr);
    return vaddr[ITLB_INDEX_WIDTH+ITLB_PAGE_OFFSET_WIDTH-1:ITLB_PAGE_OFFSET_WIDTH];
endfunction;
function itlb_page_offset_t itlb_get_page_offset(input word_t vaddr);
    return vaddr[ITLB_PAGE_OFFSET_WIDTH-1:0];
endfunction;

// multi-way set ITLB
// ITLB R/W signals
// W
logic [ITLB_NUM_WAYS-1:0] itlb_wens;
itlb_index_t itlb_waddr;
itlb_entry_t itlb_wline;
// R
logic itlb_ren;
itlb_index_t itlb_raddr;
itlb_entry_t [ITLB_NUM_WAYS-1:0] itlb_rlines_unsafe, itlb_rlines;
// ITLB BRAM
for (genvar i = ITLB_NUM_WAYS-1; i >= 0; --i) begin: gen_itlb
    BRAM #(
        .NAME("ITLB"),
        .LINE_WIDTH($bits(itlb_entry_t)),
        .DEPTH(ITLB_NUM_SETS)
    ) itlb (
        .clk(clk),
        .rst(rst),
        // write port
        .wen(itlb_wens[i]),
        .waddr(itlb_waddr),
        .wline(itlb_wline),
        // read port
        .ren(itlb_ren),
        .raddr(itlb_raddr),
        .rline(itlb_rlines_unsafe[i])
    );
end
`ifdef ITLB_MULTI_WAY
logic update_itlb_random_generator;
dword_t itlb_random_dword;
logic [ITLB_WAY_INDEX_WIDTH-1:0] itlb_random_way_index;
assign itlb_random_way_index = itlb_random_dword[ITLB_WAY_INDEX_WIDTH-1:0];
LFSR64 #(
    .NAME("ITLB_RANDOM_GENERATOR"),
    .RANDOM_SEED(64'h1234_5678_dead_face)
) itlb_random_generator (
    .rst(rst),
    .clk(clk),
    .update(update_itlb_random_generator),
    .lfsr(itlb_random_dword)
);
`endif




// send read request (pc) to ICACHE & ITLB in IF-1 stage(pc stage)
// meta cache
assign icache_meta_raddr = icache_get_addr_index(pc);
assign icache_meta_ren = 1'b1;
// data cache
assign icache_data_raddr = icache_get_addr_index(pc);
assign icache_data_ren = 1'b1;
// itlb
assign itlb_raddr = itlb_get_index(pc);
assign itlb_ren = 1'b1;



// IF-2 stage: icache and tlb bypass from IF-3 stage
word_t pc_if2;
word_t pc_if3;
generate
for (genvar i = ICACHE_NUM_WAYS-1; i >= 0; --i) begin: icache_bypass
    always_comb begin
        if (icache_meta_wens[i] && icache_get_addr_index(pc_if2) == icache_get_addr_index(pc_if3)) begin
            icache_meta_rlines[i] = icache_meta_wline;
        end else begin
            icache_meta_rlines[i] = icache_meta_rlines_unsafe[i];
        end
        if (icache_data_wens[i] && icache_get_addr_index(pc_if2) == icache_get_addr_index(pc_if3)) begin
            icache_data_rlines[i] = icache_data_wline;
        end else begin
            icache_data_rlines[i] = icache_data_rlines_unsafe[i];
        end
    end
end
endgenerate

generate
for (genvar i = ITLB_NUM_WAYS-1; i >= 0; --i) begin: itlb_bypass
    always_comb begin
        if (itlb_wens[i] && itlb_get_index(pc_if2) == itlb_get_index(pc_if3)) begin
            itlb_rlines[i] = itlb_wline;
        end else begin
            itlb_rlines[i] = itlb_rlines_unsafe[i];
        end
    end
end
endgenerate

// receive read responses (already latched in reg inside BRAM) in IF-2 stage
logic pc_valid_if2;
word_t predict_target_if2;
logic predict_valid_if2;
// pipe pc to IF-2 stage
always_ff @(posedge clk or posedge rst) begin
    if (rst | flush) begin
        pc_if2 <= '0;
        pc_valid_if2 <= '0;
        predict_target_if2 <= '0;
        predict_valid_if2 <= '0;
    end else if (~ifu_busy && ~cpu_busy) begin
        pc_if2 <= pc;
        pc_valid_if2 <= 1'b1;
        predict_target_if2 <= predict_target;
        predict_valid_if2 <= predict_valid;
    end
end
// icache hit check logic
logic icache_hit;
logic [ICACHE_NUM_WAYS-1:0] icache_hit_in_ways;
for (genvar i = ICACHE_NUM_WAYS-1; i >= 0; --i) begin: icache_hit_check_in_each_way
    // valid && cache.tag == pc.tag
    assign icache_hit_in_ways[i] = icache_meta_rlines[i][0] && (icache_get_meta_tag(icache_meta_rlines[i]) == icache_get_addr_tag(pc_if2));
end
assign icache_hit = (|icache_hit_in_ways);

// icache hit data choose logic
word_t icache_hit_data;
always_comb begin: gen_icache_hit_data
    icache_hit_data = '0;
    // TODO: refine this loop logic code into onehot-parallel-mux
    for (int i = ICACHE_NUM_WAYS-1; i >= 0; --i) begin
        if (icache_hit_in_ways[i]) begin
            icache_hit_data = icache_data_rlines[i][icache_get_addr_offset(pc_if2)];
        end
    end
end

`ifdef ICACHE_MULTI_WAY
// icache victim choose
logic [ICACHE_WAY_INDEX_WIDTH-1:0] icache_victim_way_index;
always_comb begin: icache_victim_choose
    icache_victim_way_index = icache_random_way_index;
    // if there's a way is empty, we just choose it.
    for (int i = ICACHE_NUM_WAYS-1; i >= 0; --i) begin
        if (~icache_meta_rlines[i][0]) icache_victim_way_index = i;
    end
end
`endif

// itlb hit check logic
logic itlb_hit;
logic [ITLB_NUM_WAYS-1:0] itlb_hit_in_ways;
for (genvar i = ITLB_NUM_WAYS-1; i >= 0; --i) begin: itlb_hit_check_in_each_way
    assign itlb_hit_in_ways[i] = itlb_rlines[i].valid && (
        itlb_rlines[i]._G 
        ? (itlb_rlines[i].tag == itlb_get_tag(pc_if2)) 
        : ((itlb_rlines[i].asid == csr_satp.asid) && (itlb_rlines[i].tag == itlb_get_tag(pc_if2)))
    );
end
assign itlb_hit = (|itlb_hit_in_ways);

// itlb hit data choose logic
itlb_entry_t itlb_hit_entry;
always_comb begin: gen_itlb_hit_ppn
    itlb_hit_entry = '0;
    // TODO: refine this loop logic code into onehot-parallel-mux
    for (int i = ITLB_NUM_WAYS-1; i >= 0; --i) begin
        if (itlb_hit_in_ways[i]) begin
            itlb_hit_entry = itlb_rlines[i];
        end
    end
end

// itlb victim choose
`ifdef ITLB_MULTI_WAY
logic [ITLB_WAY_INDEX_WIDTH-1:0] itlb_victim_way_index;
always_comb begin: itlb_victim_choose
    itlb_victim_way_index = itlb_random_way_index;
    for (int i = ITLB_NUM_WAYS-1; i >= 0; --i) begin
        if (~itlb_rlines[i].valid) itlb_victim_way_index = i;
    end
end
`endif

// IF-3 stage
// if miss, we go to XBar (blocked). else we send it out to IDU
logic pc_valid_if3;
word_t predict_target_if3;
logic predict_valid_if3;
word_t icache_hit_data_if3;
logic icache_hit_if3;
`ifdef ICACHE_MULTI_WAY
logic [ICACHE_WAY_INDEX_WIDTH-1:0] icache_victim_way_index_if3;
`endif
itlb_entry_t itlb_hit_entry_if3;
logic itlb_hit_if3;
`ifdef ITLB_MULTI_WAY
logic [ITLB_WAY_INDEX_WIDTH-1:0] itlb_victim_way_index_if3;
`endif
// simple translation of pc
vaddr_t ifu_vaddr;
assign ifu_vaddr = pc_if3;
always_ff @(posedge clk or posedge rst) begin
    if (rst | flush) begin
        pc_if3 <= '0;
        pc_valid_if3 <= '0;
        predict_target_if3 <= '0;
        predict_valid_if3 <= '0;
        // icache signals
        icache_hit_data_if3 <= '0;
        icache_hit_if3 <= '0;
`ifdef ICACHE_MULTI_WAY
        icache_victim_way_index_if3 <= '0;
`endif
        // itlb signals
        itlb_hit_entry_if3 <= '0;
        itlb_hit_if3 <= '0;
`ifdef ITLB_MULTI_WAY
        itlb_victim_way_index_if3 <= '0;
`endif
    end else if (~ifu_busy && ~cpu_busy) begin
        pc_if3 <= pc_if2;
        pc_valid_if3 <= pc_valid_if2;
        predict_target_if3 <= predict_target_if2;
        predict_valid_if3 <= predict_valid_if2;
        // icache signals
        icache_hit_data_if3 <= icache_hit_data;
        icache_hit_if3 <= icache_hit;
`ifdef ICACHE_MULTI_WAY
        icache_victim_way_index_if3 <= icache_victim_way_index;
`endif
        // itlb signals
        itlb_hit_entry_if3 <= itlb_hit_entry;
        itlb_hit_if3 <= itlb_hit;
`ifdef ITLB_MULTI_WAY
        itlb_victim_way_index_if3 <= itlb_victim_way_index;
`endif
    end
end

// IFU FSM
typedef enum {
    IDLE,
    // flush | clear (fence.i ?)
    CLEARING_ICACHE,
    CLEARING_ITLB,
    // cache miss, send bus read request
    // `flush` may occur in any state, so we need to add FLUSH_* states.
    FLUSH_WAITING_READY,
    FLUSH_RECEVING,
    // CACHE MISS
    P_WAITING_READY,
    P_RECEVING,
    REFILL_ICACHE,
    // ITLB MISS
    V1_WAITING_READY,
    V1_RECEVING,
    V1_CHECK,
    V2_WAITING_READY,
    V2_RECEVING,
    V2_CHECK,
    V3_WAITING_READY,
    V3_RECEVING,
    REFILL_ITIB
} ifu_fsm_state_t;
// ! CPU only give ready when all pipelines are not stalled.
// ! if EX stage is stalled, CPU is not ready.

// IF satp.MODE is 1:
// 1. if ITLB hit & ICACHE hit, we pipe this to next stage, we do not need to Fetch ftom BUS.
//  IDLE -> IDLE
// 2. if ITLB hit & ICACHE miss, we can use PADDR to access BUS. we access memory for only ONCE.
//  IDLE -> V3_WAITING_READY -> V3_RECEVING -> REFILL_ICACHE -> IDLE
// 3. if ITLB miss & ICACHE hit, we need to do PTW(Page Table Walker) to cache entry into ITLB, we access memory for TWICE.
//  IDLE -> V1_WAITING_READY -> V1_RECEVING -> V2_WAITING_READY -> V2_RECEVING -> REFILL_ITIB -> IDLE
// 4. if ITLB miss & ICACHE miss, we need to do PTW as well as Physical Memory Access. we need to access memory THREE TIMES.
//  IDLE -> V1_WAITING_READY -> V1_RECEVING -> V2_WAITING_READY -> V2_RECEVING -> REFILL_ITLB -> V3_WAITING_READY -> V3_RECEVING -> REFILL_ICACHE -> IDLE
// IF satp.MODE is 0:
// 1. if ICACHE hit, pipe this to next stage
//  IDLE -> IDLE
// 2. if ICACHE miss, we access memory for ONCE.
//  IDLE -> P_WAITING_READY -> P_RECEVING -> REFILL_ICACHE -> IDLE
// !NOTE: can we access ITLB entries from ICACHE ?
// !      NO! ICACHE is indexed using virtual address. and PTW is worked under physical memory. 
ifu_fsm_state_t ifu_state_now, ifu_state_nxt;
// ! beacuse we use Virtual ICACHE, we need to flush ICACHE whenever after we flush ITLB.

// temporily store whether to access 3 times
logic icache_hit_if3_latch, itlb_hit_if3_latch;
always_ff @(posedge clk) begin
    if (ifu_state_now == IDLE && ifu_state_nxt != IDLE) begin
        icache_hit_if3_latch <= icache_hit_if3;
        itlb_hit_if3_latch <= itlb_hit_if3;
    end
end

// invalidating ICACHE and ITLB signals
icache_index_t flushing_icache_index, flushing_icache_index_nxt;
itlb_index_t flushing_itlb_index, flushing_itlb_index_nxt;

// burst transmission counter
icache_offset_t icache_burst_cnt, icache_burst_cnt_nxt;
icache_line_t icache_line_receved;


pte_t pte1_latch, pte2_latch; // is valid at Vx_CHECK states.
always_ff @(posedge clk or posedge rst) begin: latch_pte
    if (rst | flush) begin
        pte1_latch <= '0;
        pte2_latch <= '0;
    end else if (ifu_state_now == V1_RECEVING && bus_resp.rvalid && bus_resp.rlast) begin
        pte1_latch <= bus_resp.rdata;
    end else if (ifu_state_now == V2_RECEVING && bus_resp.rvalid && bus_resp.rlast) begin
        pte2_latch <= bus_resp.rdata;
    end
end

// MMU exception check
// itlb page fault exception check logic
// ITLB caches the final-level of page table, so XWR bits must be non-zero
// X W R
// 0 0 0: point to next level
// 0 0 1: read only
// 0 1 0: (reserved)
// 0 1 1: read and write
// 1 0 0: execution only
// 1 0 1: read and execution
// 1 1 0: (reserved)
// 1 1 1: R & W & E
// A(accessed): the virtual page has been read, written, or fetched from since the last time the A bit was clear.
// D(dirty): the virtual page has been written since the last time the D bit was cleared.
// G(global): Global mappings are those that exist in all address spaces.
// !NOTE: G mappings need not be stored redundantly in TLB for multiple ASIDs. they need not be flushed from TLB when `sfence.vma` is executed with `rs2 != x0`
// Any level of PTE may be a leaf PTE, so SV32 supports 4MiB megapages.
// !NOTE: any level of a PTE may be a leaf PTE: when XWR == 000, it points to next level, otherwise it is a leaf PTE.
function logic pte_is_legal(pte_t pte, logic must_be_final, cpu_mode_t cpu_mode);
    // !NOTE: you should put variable declarations in the front of a function.
    logic is_leaf;
    logic match_depth;
    logic match_cpu_mode;
    logic match_XWRAD_bits;
    logic is_super_page;
    logic addr_aligned;

    is_leaf = pte._X | pte._W | pte._R;

    match_depth = must_be_final ? is_leaf : 1'b1;
    
    if (cpu_mode == MODE_U) match_cpu_mode = pte._U;
    else if (cpu_mode == MODE_S) match_cpu_mode = pte._U ? csr_sstatus.sum : 1'b1;
    else match_cpu_mode = 1'b1;

    // 1st-level page check: assert(XWR == 000).
    // !for LEAF PTEs:
    // when a virtual page is accessed and the A bit is clear, a page fault exception is raised.
    // when a virtual page is writen   and the D bit is clear, a page fault exception is raised.
    // assert(XWR != 010) and assert(XWR != 110);    
    match_XWRAD_bits = is_leaf ? (pte._X & ({pte._W, pte._R} != 2'b10) & pte._A) : 1'b1;

    is_super_page = (~must_be_final) & is_leaf;

    // check if level-1 is misaligned.    
    addr_aligned = is_super_page ? (~(|pte.ppn0)) : 1'b1;

    $display("[INFO][IFU-EXCEPTION] leaf=%b, cpu mode=%b, match_cpu_mode=%b, match_XWRAD_bits=%b, is_super_page=%b, addr_aligned=%b", is_leaf, cpu_mode, match_cpu_mode, match_XWRAD_bits, is_super_page, addr_aligned);

    return pte._V & match_XWRAD_bits & match_cpu_mode & match_depth & addr_aligned;
endfunction;

// IMMU exception check when performing PTW.
always_comb begin: immu_exception_check
    ifu_exception = '0;
    ifu_except_val = '0;
    
    // !NOTE: we do not need to check ITLB hit entries, because we only cache correct entries in ITLB. 
    // if `ifu_exception.fetch_pagefault` is 1, ifu_state_nxt will be IDLE, so `ifu_busy` is 0.
    // then `ifu_exception` will be piped to next stage
    if (ifu_state_now == V1_CHECK) begin
        ifu_exception.fetch_pagefault = ~(pte_is_legal(pte1_latch, 1'b0, cpu_mode));
        ifu_except_val = pc_if3;
    end else if (ifu_state_now == V2_CHECK) begin
        ifu_exception.fetch_pagefault = ~(pte_is_legal(pte2_latch, 1'b1, cpu_mode));
        ifu_except_val = pc_if3;
    end

    if (flush) begin
        ifu_exception = '0;
        ifu_except_val = '0;
    end
end

logic is_super_page;
always_ff @(posedge clk or posedge rst) begin: latch_super_page
    if (rst) begin
        is_super_page <= '0;
    end else if (ifu_state_now == V1_CHECK) begin
        is_super_page <= pte1_latch._X | pte1_latch._W | pte1_latch._R;
    end
end

assign ifu_busy = (ifu_state_nxt != IDLE);

always_comb begin: ifu_fsm
    ifu_state_nxt = ifu_state_now;
    unique case (ifu_state_now)
    IDLE: begin
        if (flush | ~pc_valid_if3) begin
            ifu_state_nxt = IDLE;
        end else if (csr_satp.mode && cpu_mode != MODE_M) begin // SV32: satp is active(S/U mode) and satp.MODE == 1
            if (icache_hit_if3 && itlb_hit_if3) ifu_state_nxt = IDLE;
            else if (~icache_hit_if3 && itlb_hit_if3) ifu_state_nxt = V3_WAITING_READY;
            else if (icache_hit_if3 && ~itlb_hit_if3) ifu_state_nxt = V1_WAITING_READY;
            else ifu_state_nxt = V1_WAITING_READY;
        end else begin // bare mode: M mode
            if (icache_hit_if3) ifu_state_nxt = IDLE;
            else ifu_state_nxt = P_WAITING_READY;
        end
    end
    // SV32 mode. Hardwire Page Table Walker.
    V1_WAITING_READY: begin
        if (flush) begin
            if (bus_resp.rready) ifu_state_nxt = FLUSH_WAITING_READY;
            else ifu_state_nxt = IDLE;
        end else if (bus_resp.rready) ifu_state_nxt = V1_RECEVING;
    end
    V1_RECEVING: begin
        if (flush) begin
            if (bus_resp.rvalid && bus_resp.rlast) ifu_state_nxt = IDLE;
            else ifu_state_nxt = FLUSH_RECEVING;
        end else if (bus_resp.rvalid && bus_resp.rlast) ifu_state_nxt = V1_CHECK;
    end
    V1_CHECK: begin
        $display("[INFO][IFU-PTW] 1st stage PTW get PTE: (ppn=0x%x, RSW=%b, flags: D=%b, A=%b, G=%b, U=%b, X=%b, W=%b, R=%b, V=%b)",
            { pte1_latch.ppn1, pte1_latch.ppn0 },
            pte1_latch._rsw,
            pte1_latch._D, pte1_latch._A, pte1_latch._G, pte1_latch._U,
            pte1_latch._X, pte1_latch._W, pte1_latch._R, pte1_latch._V
        );
        if (flush) ifu_state_nxt = IDLE;
        else if (ifu_exception.fetch_pagefault) ifu_state_nxt = IDLE;
        // handle super page
        else if (pte1_latch._X | pte1_latch._W | pte1_latch._R) ifu_state_nxt = REFILL_ITIB;
        else ifu_state_nxt = V2_WAITING_READY;
    end
    V2_WAITING_READY: begin
        if (flush) begin
            if (bus_resp.rready) ifu_state_nxt = FLUSH_WAITING_READY;
            else ifu_state_nxt = IDLE;
        end else if (bus_resp.rready) ifu_state_nxt = V2_RECEVING;
    end
    V2_RECEVING: begin
        if (flush) begin
            if (bus_resp.rvalid && bus_resp.rlast) ifu_state_nxt = IDLE;
            else ifu_state_nxt = FLUSH_RECEVING;
        end else if (bus_resp.rvalid && bus_resp.rlast) ifu_state_nxt = V2_CHECK;
    end
    V2_CHECK: begin
        $display("[INFO][IFU-PTW] 2nd stage PTW get PTE: (ppn=0x%x, RSW=%b, flags: D=%b, A=%b, G=%b, U=%b, X=%b, W=%b, R=%b, V=%b)",
            { pte2_latch.ppn1, pte2_latch.ppn0 },
            pte2_latch._rsw,
            pte2_latch._D, pte2_latch._A, pte2_latch._G, pte2_latch._U,
            pte2_latch._X, pte2_latch._W, pte2_latch._R, pte2_latch._V
        );
        if (flush) ifu_state_nxt = IDLE;
        else if (ifu_exception.fetch_pagefault) ifu_state_nxt = IDLE;
        else ifu_state_nxt = REFILL_ITIB;
    end
    REFILL_ITIB: begin
        if (flush | icache_hit_if3) ifu_state_nxt = IDLE;
        else ifu_state_nxt = V3_WAITING_READY;
    end
    V3_WAITING_READY: begin
        if (flush) begin
            if (bus_resp.rready) ifu_state_nxt = FLUSH_WAITING_READY;
            else ifu_state_nxt = IDLE;
        end else if (bus_resp.rready) ifu_state_nxt = V3_RECEVING;
    end
    V3_RECEVING: begin
        if (flush) begin
            if (bus_resp.rvalid && bus_resp.rlast) ifu_state_nxt = IDLE;
            else ifu_state_nxt = FLUSH_RECEVING;
        end else if (bus_resp.rvalid && bus_resp.rlast) ifu_state_nxt = REFILL_ICACHE;
    end
    // bare mode
    P_WAITING_READY: begin
        if (flush) begin
            if (bus_resp.rready) ifu_state_nxt = FLUSH_WAITING_READY;
            else ifu_state_nxt = IDLE;
        end else if (bus_resp.rready) ifu_state_nxt = P_RECEVING;
    end
    P_RECEVING: begin
        if (flush) begin
            if (bus_resp.rvalid && bus_resp.rlast) ifu_state_nxt = IDLE;
            else ifu_state_nxt = FLUSH_RECEVING;
        end else if (bus_resp.rvalid && bus_resp.rlast) ifu_state_nxt = REFILL_ICACHE;
    end
    REFILL_ICACHE: begin
        ifu_state_nxt = IDLE;
    end
    // flush when backend meet a miss prediction or an exception
    FLUSH_WAITING_READY: begin
        if (bus_resp.rready) ifu_state_nxt = FLUSH_RECEVING;
    end
    FLUSH_RECEVING: begin
        if (bus_resp.rvalid && bus_resp.rlast) ifu_state_nxt = IDLE;
    end
    // flush when rebooting or `sfence.vma`
    // TODO: flushing ITLB and ICACHE should be done in MEM stage, so we should give a signal to MEM stage to stall all pipelines in front of MEM stage
    CLEARING_ITLB: begin
        if (&flushing_itlb_index) ifu_state_nxt = CLEARING_ICACHE;
    end
    CLEARING_ICACHE: begin
        if (&flushing_icache_index) ifu_state_nxt = IDLE;
    end
    default: begin
        ifu_state_nxt = IDLE;
    end
    endcase
end

// give signals to local variables and IO requests
always_comb begin: ifu_control_signals_logic
    // random engine update
    update_itlb_random_generator = '0;
    update_icache_random_generator = '0;
    // flush signals
    flushing_icache_index_nxt = '0;
    flushing_itlb_index_nxt = '0;
    // busrt transmission
    icache_burst_cnt_nxt = '0;
    // write itlb signals
    itlb_wens = '0;
    itlb_waddr = '0;
    itlb_wline = '0;
    // write icache signals
    // meta cache
    icache_meta_wens = '0;
    icache_meta_waddr = '0;
    icache_meta_wline = '0;
    // data cache
    icache_data_wens = '0;
    icache_data_waddr = '0;
    icache_data_wline = '0;
    // bus requests
    bus_req = '0;
    unique case (ifu_state_now)
    // SV32 PTW
    V1_WAITING_READY: begin
        bus_req.arvalid = 1'b1;
        bus_req.rlen = 4'b0001;
        bus_req.araddr = { csr_satp.ppn, ifu_vaddr.vpn1, 2'b00 }; // 22 | 10 | 2
    end
    V1_RECEVING: begin
        // we only receive one word
        if (bus_resp.rvalid & bus_resp.rlast) begin
            bus_req.rready = 1'b1;
        end
    end
    V2_WAITING_READY: begin
        bus_req.arvalid = 1'b1;
        bus_req.rlen = 4'b0001;
        bus_req.araddr = { pte1_latch.ppn1, pte1_latch.ppn0, ifu_vaddr.vpn0, 2'b00 }; // 12 | 10 | 10 | 2
    end
    V2_RECEVING: begin
        if (bus_resp.rvalid & bus_resp.rlast) begin
            bus_req.rready = 1'b1;
        end
    end
    REFILL_ITIB: begin
        update_itlb_random_generator = 1'b1;
`ifdef ITLB_MULTI_WAY
        itlb_wens[itlb_victim_way_index_if3] = ~flush;
`else
        itlb_wens[0] = ~flush;
`endif
        itlb_waddr = itlb_get_index(pc_if3);
        if (is_super_page) begin
            itlb_wline = {
                1'b1, 1'b1, csr_satp.asid,
                pte1_latch._D, pte1_latch._A, pte1_latch._G, pte1_latch._U, pte1_latch._X, pte1_latch._W, pte1_latch._R, pte1_latch._V, 
                itlb_get_tag(pc_if3),
                pte1_latch.ppn1, 10'b0 // !super pages' ppn0 is all zero.
            };
        end else begin
            itlb_wline = {
                1'b1, 1'b0, csr_satp.asid,
                pte2_latch._D, pte2_latch._A, pte2_latch._G, pte2_latch._U, pte2_latch._X, pte2_latch._W, pte2_latch._R, pte2_latch._V, 
                itlb_get_tag(pc_if3),
                pte2_latch.ppn1, pte2_latch.ppn0
            };
        end
    end
    V3_WAITING_READY: begin
        bus_req.arvalid = 1'b1;
        bus_req.rlen = ICACHE_DATA_PER_LINE; 
        if (itlb_hit_if3) begin
            if (itlb_hit_entry_if3._super) begin 
                // ! PTE.PPN1 | VADDR.VPN0 | VADDR.PAGE_OFFSET
                // ! load 4 words, addr is 4x4=16 byte aligned, so offset [3:0] is zero
                bus_req.araddr = { itlb_hit_entry_if3.ppn[21:10], ifu_vaddr.vpn0, ifu_vaddr.page_offset[11:4], 4'b0000 }; // 12 | 10 | 8+4
            end else begin
                bus_req.araddr = { itlb_hit_entry_if3.ppn, ifu_vaddr.page_offset[11:4], 4'b0000 }; // 22 | 8+4
            end
        end else begin
            if (is_super_page) begin 
                // ! PTE.PPN1 | VADDR.VPN0 | VADDR.PAGE_OFFSET
                bus_req.araddr = { pte1_latch.ppn1, ifu_vaddr.vpn0, ifu_vaddr.page_offset[11:4], 4'b0000 }; // 12 | 10 | 12
            end else begin
                bus_req.araddr = { pte2_latch.ppn1, pte2_latch.ppn0, ifu_vaddr.page_offset[11:4], 4'b0000 }; // 12 | 10 | 12
            end
        end
        icache_burst_cnt_nxt = 1'b0;
    end
    V3_RECEVING: begin
        if (bus_resp.rvalid) begin
            bus_req.rready = 1'b1;
            icache_burst_cnt_nxt = icache_burst_cnt + 1;
        end else begin
            bus_req.rready = 1'b0;
            icache_burst_cnt_nxt = icache_burst_cnt;
        end
    end
    // bare mode
    P_WAITING_READY: begin
        bus_req.arvalid = 1'b1;
        bus_req.rlen = ICACHE_DATA_PER_LINE;
        // ! load 4 words, addr is 4x4=16 byte aligned, so offset [3:0] is zero
        bus_req.araddr = { 2'b00, pc_if3[31:4], 4'b0000 }; // 2 | 28 | 4
        icache_burst_cnt_nxt = 1'b0;
    end
    P_RECEVING: begin
        if (bus_resp.rvalid) begin
            bus_req.rready = 1'b1;
            icache_burst_cnt_nxt = icache_burst_cnt + 1;
        end else begin
            bus_req.rready = 1'b0;
            icache_burst_cnt_nxt = icache_burst_cnt;
        end
    end
    REFILL_ICACHE: begin
        update_icache_random_generator = 1'b1;
`ifdef ICACHE_MULTI_WAY
        icache_meta_wens[icache_victim_way_index_if3] = ~flush;
        icache_data_wens[icache_victim_way_index_if3] = ~flush;
`else
        icache_meta_wens[0] = ~flush;
        icache_data_wens[0] = ~flush;
`endif
        // addrs
        icache_meta_waddr = icache_get_addr_index(pc_if3);
        icache_data_waddr = icache_get_addr_index(pc_if3);
        // lines
        icache_meta_wline = { icache_get_addr_tag(pc_if3), 1'b1 };
        icache_data_wline = icache_line_receved;
    end
    FLUSH_WAITING_READY: begin
        bus_req.arvalid = 1'b1;
        bus_req.rlen = '0;
    end
    FLUSH_RECEVING: begin
        bus_req.rready = 1'b1; // ignore all datas
    end
    CLEARING_ITLB: begin
        flushing_itlb_index_nxt = flushing_itlb_index + 1;
        itlb_wens = '1;
        itlb_waddr = flushing_itlb_index;
    end
    CLEARING_ICACHE: begin
        flushing_icache_index_nxt = flushing_icache_index + 1;
        icache_data_wens = '1;
        icache_meta_wens = '1;
        icache_meta_waddr = flushing_icache_index;
        icache_data_waddr = flushing_icache_index;
    end
    endcase
end

// write cacheline
always_ff @(posedge clk or posedge rst) begin: write_temp_cacheline
    if (rst) begin
        icache_line_receved <= '0;
    end else if ((ifu_state_now == V3_RECEVING || ifu_state_now == P_RECEVING) && bus_resp.rvalid) begin
        icache_line_receved[icache_burst_cnt] <= bus_resp.rdata;
    end
end

// update received-cacheline index and FSM state
always_ff @(posedge clk or posedge rst) begin: ifu_fsm_update
    if (rst) begin
        ifu_state_now <= CLEARING_ITLB;
        icache_burst_cnt <= '0;
        flushing_icache_index <= '0;
        flushing_itlb_index <= '0;
    end else begin
        ifu_state_now <= ifu_state_nxt;
        icache_burst_cnt <= icache_burst_cnt_nxt;
        flushing_icache_index <= flushing_icache_index_nxt;
        flushing_itlb_index <= flushing_itlb_index_nxt;
    end
end

localparam word_t NOP = { 25'b0, 7'b0010011 };

// TODO: SRAM and UART bus, and bus XBar
// TODO: simplify flushing ICACHE/ITLB logic, as `sfence.vma` and `fence.i` DO NOT need to flush all entries.

// output pc and inst
assign ifu_pc = pc_if3;
assign ifu_inst = (flush | ~pc_valid_if3) ? NOP : (icache_hit_if3 ? icache_hit_data_if3 : icache_line_receved[icache_get_addr_offset(pc_if3)]);
assign bpu_predict_target = predict_target_if3;
assign bpu_predict_valid = flush ? 1'b0 : predict_valid_if3;


endmodule // IFU
