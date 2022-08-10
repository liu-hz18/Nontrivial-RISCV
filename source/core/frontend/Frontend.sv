// CPU frontend
import bitutils::*;
import bundle::*;
import micro_ops::*;
import csr_def::*;
import exception::*;

module Frontend #(
    // bpu parameters
    parameter BPU_NUM_BTB_ENTRIES = 512,
    parameter BPU_NUM_RAS = 16,
    // icache parameters
    parameter ICACHE_NUM_WAYS = 4,
    parameter ICACHE_NUM_SETS = 128,
    parameter ICACHE_DATA_WIDTH = 32,
    parameter ICACHE_LINE_WIDTH = 256,
    // itlb parameters
    parameter ITLB_NUM_WAYS = 2,
    parameter ITLB_NUM_SETS = 64
) (
    input clk, rst,

    input logic flush,
    input logic backend_busy,
    input word_t redirect_pc,
    input bpu_update_req_t bpu_update_req,

    // from backend CSR module
    input satp_t csr_satp,
    input sstatus_t csr_sstatus,
    input cpu_mode_t cpu_mode,
    
    output frontend_packet_t frontend_packet,
    output logic frontend_busy,

    // GPR R signals
    output gpr_addr_t gpr_raddr1,
    output gpr_addr_t gpr_raddr2,
    input word_t gpr_rdata1,
    input word_t gpr_rdata2,

    // FPR R siganls
    output logic fpr_re1,
    output fpr_addr_t fpr_raddr1,
    output logic fpr_re2,
    output fpr_addr_t fpr_raddr2,
    output logic fpr_re3,
    output fpr_addr_t fpr_raddr3,
    input word_t fpr_rdata1,
    input word_t fpr_rdata2,
    input word_t fpr_rdata3,

    // backend bypass signals
    input bypass_t exu_bypass,
    input bypass_t lsu_bypass,

    // bus signals
    output bus_query_req_t bus_req,
    input bus_query_resp_t bus_resp
);

logic isu_busy;

word_t ifu_pc;
word_t ifu_inst;
except_t ifu_exception;
word_t ifu_except_val;
word_t bpu_predict_target;
logic bpu_predict_valid;
logic ifu_busy;

assign frontend_busy = isu_busy | ifu_busy;

IFU #(
    .BPU_NUM_BTB_ENTRIES(BPU_NUM_BTB_ENTRIES),
    .BPU_NUM_RAS(BPU_NUM_RAS),
    .ICACHE_NUM_WAYS(ICACHE_NUM_WAYS),
    .ICACHE_NUM_SETS(ICACHE_NUM_SETS),
    .ICACHE_DATA_WIDTH(ICACHE_DATA_WIDTH),
    .ICACHE_LINE_WIDTH(ICACHE_LINE_WIDTH),
    .ITLB_NUM_WAYS(ITLB_NUM_WAYS),
    .ITLB_NUM_SETS(ITLB_NUM_SETS)
) IFU (
    .clk(clk),
    .rst(rst),

    .flush(flush),
    .cpu_busy(backend_busy | isu_busy),
    .redirect_pc(redirect_pc),
    .bpu_update_req(bpu_update_req),

    .csr_satp(csr_satp),
    .csr_sstatus(csr_sstatus),
    .cpu_mode(cpu_mode),

    .ifu_pc(ifu_pc),
    .ifu_inst(ifu_inst),
    .ifu_exception(ifu_exception),
    .ifu_except_val(ifu_except_val),
    .bpu_predict_target(bpu_predict_target),
    .bpu_predict_valid(bpu_predict_valid),

    .ifu_busy(ifu_busy),

    .bus_req(bus_req),
    .bus_resp(bus_resp)
);

word_t idu_pc;
word_t idu_inst;
except_t idu_exception_tmp;
word_t idu_except_val;
word_t idu_bpu_predict_target;
logic idu_bpu_predict_valid;
always_ff @(posedge clk or posedge rst) begin: ifu_idu_pipeline
    if (rst | flush | (ifu_busy && ~(isu_busy | backend_busy))) begin
        idu_pc <= '0;
        idu_inst <= '0;
        idu_exception_tmp <= '0;
        idu_except_val <= '0;
        idu_bpu_predict_target <= '0;
        idu_bpu_predict_valid <= '0;
    end else if (~ifu_busy && ~isu_busy && ~backend_busy) begin
        idu_pc <= ifu_pc;
        idu_inst <= ifu_inst;
        idu_exception_tmp <= ifu_exception;
        idu_except_val <= ifu_except_val;
        idu_bpu_predict_target <= bpu_predict_target;
        idu_bpu_predict_valid <= bpu_predict_valid;
    end
end

op_t idu_op;
word_t idu_imm;
logic[4:0] idu_shamt;
logic idu_gpr_we;
gpr_addr_t idu_gpr_waddr;
gpr_addr_t idu_gpr_raddr1, idu_gpr_raddr2;
except_t idu_exception;
inst_type_t idu_inst_type;
// fpr
fpr_addr_t idu_fpr_rd, idu_fpr_rs1, idu_fpr_rs2, idu_fpr_rs3;
logic idu_fpr_we, idu_fpr_re1, idu_fpr_re2, idu_fpr_re3;
logic [2:0] idu_fp_rounding_mode;
always_comb begin
    idu_exception = idu_exception_tmp;
    idu_exception.illegal_inst = (idu_op == OP_INVALID);
    idu_exception.ecall = (idu_op == OP_ECALL);
    idu_exception.breakpoint = (idu_op == OP_EBREAK);
    idu_exception.mret = (idu_op == OP_MRET);
    idu_exception.sret = (idu_op == OP_SRET);
    idu_exception.uret = (idu_op == OP_URET);
end

IDU #(
    .NAME("IDU")
) IDU (
    .inst(idu_inst),
    .op(idu_op),
    .imm(idu_imm),
    .shamt(idu_shamt),
    // inst type
    .inst_type(idu_inst_type),
    // gpr
    .gpr_we(idu_gpr_we),
    .gpr_waddr(idu_gpr_waddr),
    .gpr_raddr1(idu_gpr_raddr1),
    .gpr_raddr2(idu_gpr_raddr2),
    // fpr
    .fpr_we(idu_fpr_we),
    .fpr_waddr(idu_fpr_rd),
    .fpr_raddr1(idu_fpr_rs1),
    .fpu_rs1_re(idu_fpr_re1),
    .fpr_raddr2(idu_fpr_rs2),
    .fpu_rs2_re(idu_fpr_re2),
    .fpr_raddr3(idu_fpr_rs3),
    .fpu_rs3_re(idu_fpr_re3),
    .fp_rounding_mode(idu_fp_rounding_mode)
);

frontend_packet_t idu_packet, isu_packet_tmp, isu_packet;
assign idu_packet = {
    1'b1,
    idu_pc,
    idu_inst,
    idu_op,
    idu_exception,
    idu_except_val,
    idu_bpu_predict_target,
    idu_bpu_predict_valid,
    idu_imm,
    idu_shamt,

    idu_inst_type,

    idu_gpr_waddr,
    idu_gpr_we,
    32'b0,
    32'b0,

    idu_fpr_we,
    idu_fpr_rd,
    32'b0,
    32'b0,
    32'b0,
    idu_fp_rounding_mode
};

gpr_addr_t isu_gpr_raddr1, isu_gpr_raddr2;
fpr_addr_t isu_fpr_rs1, isu_fpr_rs2, isu_fpr_rs3;
logic isu_fpr_re1, isu_fpr_re2, isu_fpr_re3;

always_ff @(posedge clk or posedge rst) begin: idu_isu_pipeline
    if (rst | flush) begin
        isu_packet_tmp <= '0;
        isu_gpr_raddr1 <= '0;
        isu_gpr_raddr2 <= '0;
        isu_fpr_rs1 <= '0;
        isu_fpr_rs2 <= '0;
        isu_fpr_rs3 <= '0;
        isu_fpr_re1 <= '0;
        isu_fpr_re2 <= '0;
        isu_fpr_re3 <= '0;
    end else if (~isu_busy && ~backend_busy) begin
        isu_packet_tmp <= idu_packet;
        isu_gpr_raddr1 <= idu_gpr_raddr1;
        isu_gpr_raddr2 <= idu_gpr_raddr2;
        isu_fpr_rs1 <= idu_fpr_rs1;
        isu_fpr_rs2 <= idu_fpr_rs2;
        isu_fpr_rs3 <= idu_fpr_rs3;
        isu_fpr_re1 <= idu_fpr_re1;
        isu_fpr_re2 <= idu_fpr_re2;
        isu_fpr_re3 <= idu_fpr_re3;
    end
end

assign gpr_raddr1 = isu_gpr_raddr1;
assign gpr_raddr2 = isu_gpr_raddr2;
assign { fpr_re1, fpr_re2, fpr_re3 } = { isu_fpr_re1, isu_fpr_re2, isu_fpr_re3 };
assign { fpr_raddr1, fpr_raddr2, fpr_raddr3 } = { isu_fpr_rs1, isu_fpr_rs2, isu_fpr_rs3 };
word_t real_gpr_rdata1, real_gpr_rdata2;
word_t real_fpr_rs1, real_fpr_rs2, real_fpr_rs3;

ISU ISU (
    .gpr_raddr1(isu_gpr_raddr1),
    .gpr_raddr2(isu_gpr_raddr2),

    .fpr_re1(isu_fpr_re1),
    .fpr_raddr1(isu_fpr_rs1),
    .fpr_re2(isu_fpr_re2),
    .fpr_raddr2(isu_fpr_rs2),
    .fpr_re3(isu_fpr_re3),
    .fpr_raddr3(isu_fpr_rs3),

    .exu_bypass(exu_bypass),
    .lsu_bypass(lsu_bypass),

    .gpr_rdata1(gpr_rdata1),
    .gpr_rdata2(gpr_rdata2),

    .fpr_rdata1(fpr_rdata1),
    .fpr_rdata2(fpr_rdata2),
    .fpr_rdata3(fpr_rdata3),

    .real_gpr_rdata1(real_gpr_rdata1),
    .real_gpr_rdata2(real_gpr_rdata2),

    .real_fpr_rdata1(real_fpr_rs1),
    .real_fpr_rdata2(real_fpr_rs2),
    .real_fpr_rdata3(real_fpr_rs3),

    .isu_busy(isu_busy)
);

always_comb begin
    isu_packet = isu_packet_tmp;
    isu_packet.gpr_rs1 = real_gpr_rdata1;
    isu_packet.gpr_rs2 = real_gpr_rdata2;
    isu_packet.fpr_rs1 = real_fpr_rs1;
    isu_packet.fpr_rs2 = real_fpr_rs2;
    isu_packet.fpr_rs3 = real_fpr_rs3;
end

assign frontend_packet = isu_packet;

// !NOTE: since we introduced Front-Backend FIFO into our design, we DONOT need this ISU-EXU pipeline anymore.
// always_ff @(posedge clk or posedge rst) begin: fronend_backend_pipeline
//     if (rst | flush) begin
//         frontend_packet <= '0;
//     end else if (~backend_busy) begin
//         frontend_packet <= isu_packet;
//     end
// end

endmodule
