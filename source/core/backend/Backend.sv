// backend module
import bitutils::*;
import bundle::*;
import micro_ops::*;
import csr_def::*;
import exception::*;

module Backend (
    input clk, rst,

    input frontend_packet_t packet,

    // to frontend
    output logic backend_busy,
    output logic backend_flush,
    output word_t redirect_pc,
    output bpu_update_req_t bpu_update_req,
    output bypass_t exu_bypass,
    output bypass_t lsu_bypass,

    // to GPR
    output gpr_addr_t gpr_waddr,
    output word_t gpr_wdata,
    output logic gpr_we,

    // to FPR
    output fpr_addr_t fpr_waddr,
    output word_t fpr_wdata,
    output logic fpr_we,

    // to & from CSR
    output csraddr_t csr_raddr,
    input word_t csr_rdata,
    output csraddr_t csr_waddr,
    output logic csr_we,
    output word_t csr_wdata,
    // to CSR
    output except_t exception,
    output word_t mem_inst,
    output word_t mem_pc,
    output mem_req_t mem_req,
    output inst_type_t mem_inst_type,

    // to bus
    output bus_query_req_t bus_req,
    input bus_query_resp_t bus_resp
);

logic exu_busy;
word_t exu_gpr_wdata;
word_t exu_fpr_wdata;
mem_req_t exu_mem_req;

logic exu_redirect_valid;
word_t exu_redirect_pc;
except_t exu_exception;

csraddr_t exu_csr_raddr, exu_csr_waddr;
word_t exu_csr_wdata;
logic exu_csr_we;

csraddr_t lsu_csr_waddr;
word_t lsu_csr_wdata;
logic lsu_csr_we;
assign csr_raddr = exu_csr_raddr;
assign csr_waddr = lsu_csr_waddr;
assign csr_we = lsu_csr_we;
assign csr_wdata = lsu_csr_wdata;

logic lsu_flush;
word_t lsu_redirect_pc;

logic lsu_busy;

assign backend_busy = exu_busy | lsu_busy;

// pc redirect unit
assign backend_flush = exu_redirect_valid | lsu_flush;
always_comb begin
    if (lsu_flush) redirect_pc = lsu_redirect_pc;
    else if (exu_redirect_valid) redirect_pc = exu_redirect_pc;
    else redirect_pc = '0;
end

// exu bypass
assign exu_bypass.gpr_we = packet.gpr_we & (~(|exu_exception));
assign exu_bypass.gpr_waddr = packet.gpr_rd;
assign exu_bypass.gpr_wdata = exu_gpr_wdata;
assign exu_bypass.fpr_we = packet.fpr_we & (~(|exu_exception));
assign exu_bypass.fpr_waddr = packet.fpr_rd;
assign exu_bypass.fpr_wdata = exu_fpr_wdata;
assign exu_bypass.need_load = exu_mem_req.load;

EXU EXU (
    .clk(clk),
    .rst(rst),

    .flush(lsu_flush),
    .op(packet.op),
    .inst(packet.inst),
    .pc(packet.pc),
    // GPR VALUES
    .gpr_rs1(packet.gpr_rs1),
    .gpr_rs2(packet.gpr_rs2),
    .imm(packet.imm),
    .shamt(packet.shamt),
    // FPR values
    .fpr_rs1(packet.fpr_rs1),
    .fpr_rs2(packet.fpr_rs2),
    .fpr_rs3(packet.fpr_rs3),
    // BPU prediction results
    .bpu_predict_target(packet.bpu_predict_target),
    .bpu_predict_valid(packet.valid),
    // inst type
    .inst_type(packet.inst_type),
    // exception from frontend
    .exception_in(packet.exception),
    
    // output 
    .exu_busy(exu_busy),
    .gpr_wdata(exu_gpr_wdata),
    .fpr_wdata(exu_fpr_wdata),
    // MEM control signals
    .mem_req(exu_mem_req),
    // CSR R/W signals
    .csr_raddr(exu_csr_raddr),
    .csr_rdata(csr_rdata),
    .csr_waddr(exu_csr_waddr),
    .csr_we(exu_csr_we),
    .csr_wdata(exu_csr_wdata),
    // BPU update req
    .bpu_update_req(bpu_update_req),
    // PC update req
    .redirect_pc(exu_redirect_pc),
    .redirect_valid(exu_redirect_valid),
    // exceptions updated by EXU
    .exu_exception(exu_exception)
);

assign lsu_flush = 1'b0;
assign lsu_busy = 1'b0;
assign bus_req = '0;

op_t lsu_op;
word_t lsu_inst;
word_t lsu_pc;
inst_type_t lsu_inst_type;
gpr_addr_t lsu_gpr_waddr;
word_t lsu_gpr_wdata;
logic lsu_gpr_we;
fpr_addr_t lsu_fpr_waddr;
word_t lsu_fpr_wdata;
logic lsu_fpr_we;
except_t lsu_exception_tmp, lsu_exception;
mem_req_t lsu_mem_req;
// TODO: LSU and exception check unit. CSR RW logic

// LSU bypass
assign lsu_bypass.gpr_we = lsu_gpr_we & (~(|lsu_exception));
assign lsu_bypass.gpr_waddr = lsu_gpr_waddr;
assign lsu_bypass.gpr_wdata = lsu_gpr_wdata;
assign lsu_bypass.fpr_we = lsu_fpr_we & (~(|lsu_exception));
assign lsu_bypass.fpr_waddr = lsu_fpr_waddr;
assign lsu_bypass.fpr_wdata = lsu_fpr_wdata;
assign lsu_bypass.need_load = lsu_mem_req.load;

// EXU LSU pipeline
always_ff @(posedge clk or posedge rst) begin: exu_lsu_pipeline
    if (rst | lsu_flush | (exu_busy && ~lsu_busy)) begin
        lsu_op <= OP_NOP;
        lsu_inst <= { 25'b0, 7'b0010011 };
        lsu_pc <= '0;
        lsu_gpr_waddr <= '0;
        lsu_gpr_wdata <= '0;
        lsu_gpr_we <= '0;
        lsu_fpr_waddr <= '0;
        lsu_fpr_wdata <= '0;
        lsu_fpr_we <= '0;
        lsu_exception_tmp <= '0;
        lsu_mem_req <= '0;
        lsu_csr_we <= '0;
        lsu_csr_waddr <= '0;
        lsu_csr_wdata <= '0;
    end else if (~exu_busy && ~lsu_busy) begin
        lsu_op <= packet.op;
        lsu_inst <= packet.inst;
        lsu_pc <= packet.pc;
        lsu_inst_type <= packet.inst_type;
        lsu_gpr_waddr <= packet.gpr_rd;
        lsu_gpr_wdata <= exu_gpr_wdata;
        lsu_gpr_we <= packet.gpr_we & (~(|exu_exception));
        lsu_fpr_waddr <= packet.fpr_rd;
        lsu_fpr_wdata <= exu_fpr_wdata;
        lsu_fpr_we <= packet.fpr_we & (~(|exu_exception));
        lsu_exception_tmp <= exu_exception;
        lsu_mem_req <= exu_mem_req;
        lsu_csr_we <= exu_csr_we;
        lsu_csr_waddr <= exu_csr_waddr;
        lsu_csr_wdata <= exu_csr_wdata;
    end
end

// TODO: give correct `lsu_exception`
assign lsu_exception = lsu_exception_tmp;


assign exception = lsu_exception;
assign mem_inst = lsu_inst;
assign mem_pc = lsu_pc;
assign mem_req = lsu_mem_req;
assign mem_inst_type = lsu_inst_type;

op_t wbu_op;
word_t wbu_inst;
word_t wbu_pc;
gpr_addr_t wbu_gpr_waddr;
word_t wbu_gpr_wdata;
logic wbu_gpr_we;
fpr_addr_t wbu_fpr_waddr;
word_t wbu_fpr_wdata;
logic wbu_fpr_we;
// LSU WBU pipeline
always_ff @(posedge clk or posedge rst) begin: lsu_wbu_pipeline
    if (rst | lsu_busy) begin
        wbu_op <= OP_NOP;
        wbu_inst <= { 25'b0, 7'b0010011 };
        wbu_pc <= '0;
        wbu_gpr_waddr <= '0;
        wbu_gpr_wdata <= '0;
        wbu_gpr_we <= '0;
        wbu_fpr_waddr <= '0;
        wbu_fpr_wdata <= '0;
        wbu_fpr_we <= '0;
    end else if (~lsu_busy) begin
        wbu_op <= lsu_op;
        wbu_inst <= lsu_inst;
        wbu_pc <= lsu_pc;
        wbu_gpr_waddr <= lsu_gpr_waddr;
        wbu_gpr_wdata <= lsu_gpr_wdata;
        wbu_gpr_we <= lsu_gpr_we & (~(|lsu_exception));
        wbu_fpr_waddr <= lsu_fpr_waddr;
        wbu_fpr_wdata <= lsu_fpr_wdata;
        wbu_fpr_we <= lsu_fpr_we & (~(|lsu_exception));
    end
end

assign gpr_waddr = wbu_gpr_waddr;
assign gpr_wdata = wbu_gpr_wdata;
assign gpr_we = wbu_gpr_we;
assign fpr_waddr = wbu_fpr_waddr;
assign fpr_wdata = wbu_fpr_wdata;
assign fpr_we = wbu_fpr_we;

endmodule
