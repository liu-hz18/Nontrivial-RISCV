// General Purpose Registers
import bitutils::*;

module GPR(
    input clk, rst,

    // write port
    input logic gpr_we,
    input gpr_addr_t gpr_waddr,
    input word_t gpr_wdata,
    // read port 1
    input gpr_addr_t gpr_raddr1,
    output word_t gpr_rdata1,
    // read port 2
    input gpr_addr_t gpr_raddr2,
    output word_t gpr_rdata2
);

word_t gprs[NUM_GPRS-1:0];

always_ff @(posedge clk) begin
    gprs[0] <= '0;
end

// write
genvar i;
generate
for (i = 1; i < NUM_GPRS; ++i) begin
    always_ff @(posedge clk) begin
        if (gpr_we && gpr_waddr == i) begin
            gprs[i] <= gpr_wdata;
        end
    end
end
endgenerate

// read port 1
always_comb begin : read_port1
    if (gpr_we && gpr_raddr1 == gpr_waddr) begin
        gpr_rdata1 = gpr_wdata;
    end else begin
        gpr_rdata1 = gprs[gpr_raddr1];
    end
end

// read port 2
always_comb begin : read_port2
    if (gpr_we && gpr_raddr2 == gpr_waddr) begin
        gpr_rdata2 = gpr_wdata;
    end else begin
        gpr_rdata2 = gprs[gpr_raddr2];
    end
end


endmodule
