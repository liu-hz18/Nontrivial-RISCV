// Floating Point Registers
import bitutils::*;

module FPRF (
    input clk, rst,

    // write port
    input logic fpr_we,
    input fpr_addr_t fpr_waddr,
    input word_t fpr_wdata,

    // read port 1
    input fpr_addr_t fpr_raddr1,
    input logic fpr_re1,
    output word_t fpr_rdata1,
    // read port 2
    input fpr_addr_t fpr_raddr2,
    input logic fpr_re2,
    output word_t fpr_rdata2,
    // read port 3
    input fpr_addr_t fpr_raddr3,
    input logic fpr_re3,
    output word_t fpr_rdata3
);

word_t fprs[NUM_FPRS-1:0];

// write
genvar i;
generate
for (i = 0; i < NUM_FPRS; ++i) begin
    always_ff @(posedge clk) begin
        if (fpr_we && fpr_waddr == i) begin
            fprs[i] <= fpr_wdata;
        end
    end
end
endgenerate

// read 1
always_comb begin: read_port1
    if (fpr_we && fpr_re1 && fpr_raddr1 == fpr_waddr) begin
        fpr_rdata1 = fpr_wdata;
    end else begin
        fpr_rdata1 = fprs[fpr_raddr1];
    end
end

// read 2
always_comb begin: read_port2
    if (fpr_we && fpr_re2 && fpr_raddr2 == fpr_waddr) begin
        fpr_rdata2 = fpr_wdata;
    end else begin
        fpr_rdata2 = fprs[fpr_raddr2];
    end
end

// read 3
always_comb begin: read_port3
    if (fpr_we && fpr_re3 && fpr_raddr3 == fpr_waddr) begin
        fpr_rdata3 = fpr_wdata;
    end else begin
        fpr_rdata3 = fprs[fpr_raddr3];
    end
end

endmodule
