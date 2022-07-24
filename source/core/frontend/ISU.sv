// issue
import bitutils::*;
import bundle::*;
import csr_def::*;

module ISU (
    input gpr_addr_t gpr_raddr1,
    input gpr_addr_t gpr_raddr2,

    // FPRs
    input logic fpr_re1,
    input fpr_addr_t fpr_raddr1,
    input logic fpr_re2,
    input fpr_addr_t fpr_raddr2,
    input logic fpr_re3,
    input fpr_addr_t fpr_raddr3,

    // bypass from backend EX stage
    input bypass_t exu_bypass,
    // bypass from backend MEM stage
    input bypass_t lsu_bypass,

    // GPR read results
    input word_t gpr_rdata1,
    input word_t gpr_rdata2,

    // FPR read results
    input word_t fpr_rdata1,
    input word_t fpr_rdata2,
    input word_t fpr_rdata3,

    // output true GPR values
    output word_t real_gpr_rdata1,
    output word_t real_gpr_rdata2,

    // output FPR values
    output word_t real_fpr_rdata1,
    output word_t real_fpr_rdata2,
    output word_t real_fpr_rdata3,

    // ISU busy waiting signal
    output logic isu_busy
);


// GPR forward unit
always_comb begin: reg1_forward
    if (gpr_raddr1 == 5'b0) begin
        real_gpr_rdata1 = 32'b0;
    end else if (exu_bypass.gpr_we && exu_bypass.gpr_waddr == gpr_raddr1) begin
        real_gpr_rdata1 = exu_bypass.gpr_wdata;
    end else if (lsu_bypass.gpr_we && lsu_bypass.gpr_waddr == gpr_raddr1) begin
        real_gpr_rdata1 = lsu_bypass.gpr_wdata;
    end else begin
        real_gpr_rdata1 = gpr_rdata1;
    end
end

always_comb begin: reg2_forward
    if (gpr_raddr2 == 5'b0) begin
        real_gpr_rdata2 = 32'b0;
    end else if (exu_bypass.gpr_we && exu_bypass.gpr_waddr == gpr_raddr2) begin
        real_gpr_rdata2 = exu_bypass.gpr_wdata;
    end else if (lsu_bypass.gpr_we && lsu_bypass.gpr_waddr == gpr_raddr2) begin
        real_gpr_rdata2 = lsu_bypass.gpr_wdata;
    end else begin
        real_gpr_rdata2 = gpr_rdata2;
    end
end

// FPR forward unit
always_comb begin: fpr1_forward
    if (~fpr_re1) begin
        real_fpr_rdata1 = 32'b0;
    end else if (exu_bypass.fpr_we && exu_bypass.fpr_waddr == fpr_raddr1) begin
        real_fpr_rdata1 = exu_bypass.fpr_wdata;
    end else if (lsu_bypass.fpr_we && lsu_bypass.fpr_waddr == fpr_raddr1) begin
        real_fpr_rdata1 = lsu_bypass.fpr_wdata;
    end else begin
        real_fpr_rdata1 = fpr_rdata1;
    end
end

always_comb begin: fpr2_forward
    if (~fpr_re2) begin
        real_fpr_rdata2 = 32'b0;
    end else if (exu_bypass.fpr_we && exu_bypass.fpr_waddr == fpr_raddr2) begin
        real_fpr_rdata2 = exu_bypass.fpr_wdata;
    end else if (lsu_bypass.fpr_we && lsu_bypass.fpr_waddr == fpr_raddr2) begin
        real_fpr_rdata2 = lsu_bypass.fpr_wdata;
    end else begin
        real_fpr_rdata2 = fpr_rdata2;
    end
end

always_comb begin: fpr3_forward
    if (~fpr_re3) begin
        real_fpr_rdata3 = 32'b0;
    end else if (exu_bypass.fpr_we && exu_bypass.fpr_waddr == fpr_raddr3) begin
        real_fpr_rdata3 = exu_bypass.fpr_wdata;
    end else if (lsu_bypass.fpr_we && lsu_bypass.fpr_waddr == fpr_raddr3) begin
        real_fpr_rdata3 = lsu_bypass.fpr_wdata;
    end else begin
        real_fpr_rdata3 = fpr_rdata3;
    end
end

logic exu_load_gpr_relation, lsu_load_gpr_relation;
assign exu_load_gpr_relation = ( exu_bypass.need_load &&
    ((exu_bypass.gpr_waddr == gpr_raddr1) && (gpr_raddr1 != '0)) ||
    ((exu_bypass.gpr_waddr == gpr_raddr2) && (gpr_raddr2 != '0))
);
assign lsu_load_gpr_relation = ( lsu_bypass.need_load &&
    ((lsu_bypass.gpr_waddr == gpr_raddr1) && (gpr_raddr1 != '0)) ||
    ((lsu_bypass.gpr_waddr == gpr_raddr2) && (gpr_raddr2 != '0))
);
logic exu_load_fpr_relation, lsu_load_fpr_relation;
assign exu_load_fpr_relation = ( exu_bypass.need_load &&
    ((exu_bypass.fpr_waddr == fpr_raddr1) && fpr_re1) ||
    ((exu_bypass.fpr_waddr == fpr_raddr2) && fpr_re2) ||
    ((exu_bypass.fpr_waddr == fpr_raddr3) && fpr_re3)
);
assign lsu_load_fpr_relation = ( lsu_bypass.need_load &&
    ((lsu_bypass.fpr_waddr == fpr_raddr1) && fpr_re1) ||
    ((lsu_bypass.fpr_waddr == fpr_raddr2) && fpr_re2) ||
    ((lsu_bypass.fpr_waddr == fpr_raddr3) && fpr_re3)
);

assign isu_busy = exu_load_gpr_relation | lsu_load_gpr_relation |
                  exu_load_fpr_relation | lsu_load_fpr_relation;

endmodule
