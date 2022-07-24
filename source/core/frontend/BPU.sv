// branch prediction unit
import bitutils::*;
import bundle::*;

module BPU #(
    parameter NUM_BTB_ENTRIES = 512,
    parameter NUM_RAS = 16
) (
    input clk, rst,
    // from&to pc
    input bpu_query_req_t query_req,
    output word_t predict_target,
    output logic predict_valid,
    // from control flow
    input logic flush,
    // from backend branch update request
    input bpu_update_req_t update_req
);

// basic parameters of BPU
localparam int NUM_BTB_WAYS = 1;
localparam int NUM_BTB_SETS = NUM_BTB_ENTRIES / NUM_BTB_WAYS;
localparam int BTB_INDEX_WIDTH = $clog2(NUM_BTB_SETS);
localparam int BTB_TAG_WIDTH = 32 - BTB_INDEX_WIDTH - 2;
typedef logic[BTB_INDEX_WIDTH-1:0] btb_index_t;
typedef logic[BTB_TAG_WIDTH  -1:0] btb_tag_t;
typedef struct packed {
    btb_tag_t tag;
    word_t    target;
    btb_type_t _type;
    logic     valid;
} btb_entry_t;

function btb_index_t get_pc_index (input word_t vaddr);
    return vaddr[BTB_INDEX_WIDTH+2-1:2];
endfunction;
function btb_tag_t get_pc_tag (input word_t vaddr);
    return vaddr[31:BTB_INDEX_WIDTH+2];
endfunction;


// meta query informations from the input query request
typedef struct packed {
    logic valid;
    btb_tag_t tag;
    btb_index_t index;
    word_t pc;
} bpu_query_meta_t;

bpu_query_meta_t bpu_query_meta;
assign bpu_query_meta.valid = query_req.valid;
assign bpu_query_meta.tag = get_pc_tag(query_req.pc);
assign bpu_query_meta.index = get_pc_index(query_req.pc);
assign bpu_query_meta.pc = query_req.pc;

// BTB-read responses
btb_entry_t btb_read_response;


// physical stroage structs
btb_entry_t btb_write_data;
btb_index_t btb_write_addr;
logic btb_write_en;
// BTB
// only implemented 1-way BTB
BRAM #(
    .NAME("BPU_BTB"),
    .LINE_WIDTH($bits(btb_entry_t)),
    .DATA_WIDTH($bits(btb_entry_t)),
    .DEPTH(NUM_BTB_SETS)
) btb (
    .clk(clk),
    .rst(rst),
    
    .wen(btb_write_en),
    .wmask(1'b1),
    .waddr(btb_write_addr),
    .wline(btb_write_data),
    
    // send read request to BTB in this cycle
    .ren(bpu_query_meta.valid), 
    .raddr(bpu_query_meta.index),
    // read-response is received in next cycle
    .rline(btb_read_response)
);

// PHT: Pattern History Table (2bit)
//  11: taken. if truly taken, 11 -> 11, else 11 -> 10
//  10: taken. if truly taken, 10 -> 11, else 10 -> 00
//  01: not taken (pc+4). if truly taken, 01 -> 11, else 01 -> 00
//  00: not taken (pc+4). if truly taken, 00 -> 01, else 00 -> 00
typedef enum logic[1:0] {
    STRONG_TAKEN = 3,
    WAKE_TAKEN = 2,
    WAKE_NOT_TAKEN = 1,
    STRONG_NOT_TAKEN = 0
} pht_type_t;
pht_type_t [NUM_BTB_ENTRIES-1:0] pht;

// RAS: Return Address Stack (Recurrent Stack)
localparam int RAS_INDEX_WIDTH = $clog2(NUM_RAS);
logic [NUM_RAS-1:0][31:0] ras;
logic [RAS_INDEX_WIDTH-1:0] sp, nsp; // Recurrent RAS stack pointer. hold when overflow.
logic ras_empty;
assign ras_empty = (sp == 0);

// read PHT & RAS, result is latched in next cycle
pht_type_t pht_state;
word_t ras_target;
always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
        pht_state <= STRONG_NOT_TAKEN;
        ras_target <= '0;
    end else if (bpu_query_meta.valid) begin
        pht_state <= pht[bpu_query_meta.index];
        ras_target <= ras[sp];
    end
end

// BTB hit check (next cycle)
bpu_query_meta_t bpu_query_meta_latch;
always_ff @(posedge clk) begin
    if (bpu_query_meta.valid) begin
        bpu_query_meta_latch <= bpu_query_meta;
    end
end
logic btb_hit;
assign btb_hit = btb_read_response.valid && (btb_read_response.tag == bpu_query_meta_latch.tag);
logic pht_taken;
assign pht_taken = pht_state[1];

// predict nnpc from current npc (next cycle)
always_comb begin: npc_predict_logic
    if (btb_read_response._type == RETURN) begin
        predict_target = ras_target;
    end else begin
        predict_target = btb_read_response.target;
    end
end
assign predict_valid = btb_hit && ((btb_read_response._type == BRANCH) ? pht_taken : (1'b1 && ~ras_empty));



// BPU sync update, we only update BPU at a miss prediction
// and if a miss prediction is found, the pipeline will be flushed, 
// so BTB read request is useless, we only need to write BTBs.

// update BTB

assign btb_write_data.tag = get_pc_tag(update_req.pc);
assign btb_write_data.target = update_req.actual_target;
assign btb_write_data._type = update_req.btb_type;
assign btb_write_data.valid = 1'b1;

assign btb_write_addr = get_pc_index(update_req.pc);

assign btb_write_en = update_req.valid && update_req.is_miss_predict;
always_ff @(posedge clk) begin
    if (btb_write_en) begin
        $display("BTB(depth=%d) updated. pc = 0x%h, idx = %d, tag = %d, actual target = 0x%h, btb type = %b", NUM_BTB_ENTRIES, update_req.pc, get_pc_index(update_req.pc), get_pc_tag(update_req.pc), update_req.actual_target, update_req.btb_type);
    end
end

// update PHT
// whether or not a miss prediction occurred, we always need to update or retain the PHT state.
// ! we need to read PHT to get `pht_type_t`, we temporily pipe the result for timing issue.
pht_type_t pht_old_state, pht_new_state;
bpu_update_req_t update_req_latch;
always_ff @(posedge clk) begin
    pht_old_state <= pht[get_pc_index(update_req.pc)];
    update_req_latch <= update_req;
end
always_comb begin: gen_new_pht_state
    if (update_req_latch.actual_taken) begin
        unique case(pht_old_state)
        STRONG_NOT_TAKEN: pht_new_state = WAKE_NOT_TAKEN;
        default: pht_new_state = STRONG_TAKEN; // STRONG_TAKEN, WAKE_TALEN, WAKE_NOT_TAKEN
        endcase
    end else begin
        unique case(pht_old_state)
        STRONG_TAKEN: pht_new_state = WAKE_TAKEN;
        default: pht_new_state = STRONG_NOT_TAKEN; // WAKE_TAKEN, WAKE_NOT_TAKEN, STRONG_NOT_TAKEN
        endcase
    end
end
// update pht in next cycle
always_ff @(posedge clk) begin
    if (update_req_latch.valid && update_req_latch.is_branch_inst) begin
        pht[get_pc_index(update_req.pc)] <= pht_new_state;
        $display("PHT(depth=%d) updated. pc = 0x%h, idx = %d, old state(%b) -> new state(%b)", NUM_BTB_ENTRIES, update_req.pc, get_pc_index(update_req.pc), pht_old_state, pht_new_state);
    end
end

// update RAS
// we need to update RAS and RAS.sp when a `call` or `ret` inst is issued.
// 1. if `call` and not `ret`, we push pc+4 into RAS.
// 2. if `ret` and not `call`, we pop RAS.
// 3. if both `call` and `ret`, if `rs1 == rd`, we push pc+4 into RAS, else we pop then push pc+4 into RAS.
always_ff @(posedge clk) begin
    // !NOTE: `update_req.pc` is `exu.pc+4`, there's no need to add 4 anymore.
    if (update_req.valid && update_req.is_call_inst) begin
        ras[nsp] <= update_req.pc; // push
    end
end

// update sp
// !NOTE: sp==0 means RAS is empty, we should always maintian this contraint.
always_comb begin: nsp_gen
    nsp = sp;
    if (update_req.valid) begin
        if (update_req.is_call_inst && update_req.is_ret_inst) begin
            if (update_req.same_link_regs) begin
                nsp = (&sp) ? sp : sp + 1;
                $display("[INFO][BPU] RAS(depth=%d) pushed. prev sp = %d, new sp = %d, pushed pc = 0x%h", NUM_RAS, sp, nsp, update_req.pc);
            end else begin 
                nsp = (sp == '0) ? sp + 1 : sp;
                $display("[INFO][BPU] RAS(depth=%d) poped then pushed. prev sp = %d, new sp = %d, pushed pc = 0x%h", NUM_RAS, sp, nsp, update_req.pc);
            end
        end else if (update_req.is_call_inst) begin
            nsp = (&sp) ? sp : sp + 1;
            $display("[INFO][BPU] RAS(depth=%d) pushed. prev sp = %d, new sp = %d, pushed pc = 0x%h", NUM_RAS, sp, nsp, update_req.pc);
        end else if (update_req.is_ret_inst) begin
            nsp = (sp == '0) ? '0 : (sp-1);
            $display("[INFO][BPU] RAS(depth=%d) poped. prev sp = %d, new sp = %d, poped pc = 0x%h", NUM_RAS, sp, nsp, ras[sp]);
        end
    end
end
always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
        sp <= '0;
    end else begin
        sp <= nsp;
    end
end

endmodule // BPU
