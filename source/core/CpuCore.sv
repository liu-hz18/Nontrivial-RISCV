// CPU Core
import bitutils::*;
import bundle::*;
import csr_def::*;

module CpuCore #(
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
    parameter ITLB_NUM_SETS = 64,
    // frontend-backend fifo
    parameter NUM_FIFO_DEPTH = 4
) (
    input clk, rst,
    // interruptions from MMIO
    input logic timer_interrupt,
    input logic external_interrupt,
    input logic software_interrupt,
    // inst bus
    output bus_query_req_t ibus_req,
    input bus_query_resp_t ibus_resp,
    // mem bus
    output bus_query_req_t dbus_req,
    input bus_query_resp_t dbus_resp
);


logic flush;
word_t redirect_pc;
logic exu_flush, csr_flush;
word_t exu_redirect_pc, csr_redirect_pc;
assign flush = exu_flush | csr_flush;
assign redirect_pc = csr_flush ? csr_redirect_pc : exu_redirect_pc;

logic fifo_full;
bpu_update_req_t bpu_update_req;

csr_t csr;
cpu_mode_t cpu_mode, lsu_cpu_mode_view;

logic gpr_we;
gpr_addr_t gpr_waddr;
word_t gpr_wdata;
gpr_addr_t gpr_raddr1, gpr_raddr2;
word_t gpr_rdata1, gpr_rdata2;

logic fpr_we;
fpr_addr_t fpr_waddr;
word_t fpr_wdata;
logic fpr_re1, fpr_re2, fpr_re3;
fpr_addr_t fpr_raddr1, fpr_raddr2, fpr_raddr3;
word_t fpr_rdata1, fpr_rdata2, fpr_rdata3;

frontend_packet_t frontend_packet;
logic frontend_busy;

bypass_t exu_bypass, lsu_bypass;

Frontend #(
    .BPU_NUM_BTB_ENTRIES(BPU_NUM_BTB_ENTRIES),
    .BPU_NUM_RAS(BPU_NUM_RAS),
    .ICACHE_NUM_WAYS(ICACHE_NUM_WAYS),
    .ICACHE_NUM_SETS(ICACHE_NUM_SETS),
    .ICACHE_DATA_WIDTH(ICACHE_DATA_WIDTH),
    .ICACHE_LINE_WIDTH(ICACHE_LINE_WIDTH),
    .ITLB_NUM_WAYS(ITLB_NUM_WAYS),
    .ITLB_NUM_SETS(ITLB_NUM_SETS)
) Frontend (
    .clk(clk),
    .rst(rst),

    .flush(flush),
    .backend_busy(fifo_full),
    .redirect_pc(redirect_pc),
    .bpu_update_req(bpu_update_req),

    .csr_satp(csr.satp),
    .csr_sstatus(csr.mstatus & SSTATUS_RMASK),
    .cpu_mode(cpu_mode),

    .frontend_packet(frontend_packet),
    .frontend_busy(frontend_busy),

    .gpr_raddr1(gpr_raddr1),
    .gpr_raddr2(gpr_raddr2),
    .gpr_rdata1(gpr_rdata1),
    .gpr_rdata2(gpr_rdata2),

    .fpr_re1(fpr_re1),
    .fpr_raddr1(fpr_raddr1),
    .fpr_re2(fpr_re2),
    .fpr_raddr2(fpr_raddr2),
    .fpr_re3(fpr_re3),
    .fpr_raddr3(fpr_raddr3),
    .fpr_rdata1(fpr_rdata1),
    .fpr_rdata2(fpr_rdata2),
    .fpr_rdata3(fpr_rdata3),

    .exu_bypass(exu_bypass),
    .lsu_bypass(lsu_bypass),

    .bus_req(ibus_req),
    .bus_resp(ibus_resp)
);


GPR GPR (
    .clk(clk),
    .rst(rst),

    .gpr_we(gpr_we),
    .gpr_waddr(gpr_waddr),
    .gpr_wdata(gpr_wdata),

    .gpr_raddr1(gpr_raddr1),
    .gpr_rdata1(gpr_rdata1),
    .gpr_raddr2(gpr_raddr2),
    .gpr_rdata2(gpr_rdata2)
);

FPRF FPRF (
    .clk(clk),
    .rst(rst),

    .fpr_we(fpr_we),
    .fpr_waddr(fpr_waddr),
    .fpr_wdata(fpr_wdata),
    
    .fpr_re1(fpr_re1),
    .fpr_rdata1(fpr_rdata1),
    .fpr_raddr1(fpr_raddr1),
    
    .fpr_re2(fpr_re2),
    .fpr_rdata2(fpr_rdata2),
    .fpr_raddr2(fpr_raddr2),
    
    .fpr_re3(fpr_re3),
    .fpr_rdata3(fpr_rdata3),
    .fpr_raddr3(fpr_raddr3)
);

logic backend_busy;
logic fifo_pop;
logic fifo_empty;
frontend_packet_t fifo_head_tmp, fifo_head;
assign fifo_pop = ~backend_busy;
// !FIXIT: fifo read logic is wrong
always_comb begin
    if (fifo_empty) begin
        fifo_head = '0;
        fifo_head.inst = { 25'b0, 7'b0010011 }; // NOP
        fifo_head.op = OP_NOP;
    end else begin
        fifo_head = fifo_head_tmp;
    end
end

SyncFIFO #(
    .NAME("FRONT-BACK-FIFO"),
    .DEPTH(NUM_FIFO_DEPTH),
    .LINE_WIDTH($bits(frontend_packet_t))
) front_back_fifo (
    .clk(clk),
    .rst(rst),
    
    .flush(flush),
    
    .push(frontend_packet.valid),
    .push_data(frontend_packet),

    .pop(fifo_pop),
    .head_data(fifo_head_tmp),
    
    .full(fifo_full),
    .empty(fifo_empty)
);


csraddr_t csr_raddr, csr_waddr;
word_t csr_rdata, csr_wdata;
logic csr_we;
except_t exception;
word_t mem_inst, mem_pc;
mem_req_t mem_req;
inst_type_t mem_inst_type;
Backend Backend (
    .clk(clk),
    .rst(rst),
    // from frontend
    .packet(fifo_head),
    // to frontend
    .backend_busy(backend_busy),
    .backend_flush(exu_flush),
    .redirect_pc(exu_redirect_pc),
    .bpu_update_req(bpu_update_req),
    .exu_bypass(exu_bypass),
    .lsu_bypass(lsu_bypass),
    // to GPR
    .gpr_waddr(gpr_waddr),
    .gpr_wdata(gpr_wdata),
    .gpr_we(gpr_we),
    // to FPR
    .fpr_waddr(fpr_waddr),
    .fpr_wdata(fpr_wdata),
    .fpr_we(fpr_we),
    // to & from CSR module
    .csr_raddr(csr_raddr),
    .csr_rdata(csr_rdata),
    .csr_waddr(csr_waddr),
    .csr_we(csr_we),
    .csr_wdata(csr_wdata),
    // to CSR
    .exception(exception),
    .mem_inst(mem_inst),
    .mem_pc(mem_pc),
    .mem_req(mem_req),
    .mem_inst_type(mem_inst_type),
    // to bus
    .bus_req(dbus_req),
    .bus_resp(dbus_resp)
);

// CSRs
CSR CSR (
    .clk(clk),
    .rst(rst),
    // from EX stage 
    .raddr(csr_raddr),
    .rdata(csr_rdata),
    // from MEM stage
    .waddr(csr_waddr),
    .we(csr_we),
    .wdata(csr_wdata),

    .exception(exception),
    .inst(mem_inst),
    .pc(mem_pc),
    .mem_req(mem_req),
    .inst_type(mem_inst_type),

    .timer_interrupt(timer_interrupt),
    .external_interrupt(external_interrupt),

    .csr(csr),
    .cpu_mode(cpu_mode),
    .lsu_cpu_mode_view(lsu_cpu_mode_view),

    .flush(csr_flush),
    .redirect_pc(csr_redirect_pc)
);

endmodule
