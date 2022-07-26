import bitutils::*;
import bundle::*;
import micro_ops::*;
import csr_def::*;
import exception::*;

module CSR (
    input clk, rst,

    // CSR read port
    input csraddr_t raddr,
    output word_t rdata,

    // CSR write port
    input csraddr_t waddr,
    input logic we,
    input word_t wdata
);

csr_t csr_now, csr_nxt;
cpu_mode_t cpu_mode;

// TODO: exception and interrupt check.

// read port. implemented write data bypass
always_comb begin: csr_read
    rdata = '0;
    // TODO: each reg's unused bits should be set zero.
    unique case (raddr[11:8])
    4'h0: begin
        unique case (raddr[7:0])
        8'h01: rdata = csr_nxt.fcsr.fflags;
        8'h02: rdata = csr_nxt.fcsr.frm;
        8'h03: rdata = csr_nxt.fcsr;
        8'h15: rdata = csr_nxt.seed;
        endcase
    end
    4'hc: begin // read only shadows of machien mode csrs
        unique case (raddr[7:5])
        3'b000: rdata = csr_nxt.mhpmcounters[raddr[4:0]][31:0];
        3'b100: rdata = csr_nxt.mhpmcounters[raddr[4:0]][63:32];
        endcase
    end
    4'h1: begin
        unique case (raddr[7:0])
        8'h00: rdata = csr_nxt.mstatus;
        8'h04: rdata = csr_nxt.mie;
        8'h44: rdata = csr_nxt.mip;

        8'h05: rdata = csr_nxt.stvec;
        8'h06: rdata = csr_nxt.scounteren;
        8'h0a: rdata = csr_nxt.senvcfg;
        8'h40: rdata = csr_nxt.sscratch;
        8'h41: rdata = csr_nxt.sepc;
        8'h42: rdata = csr_nxt.scause;
        8'h43: rdata = csr_nxt.stval;
        8'h80: rdata = csr_nxt.satp;
        endcase
    end
    4'hf: begin // read-only
        unique case (raddr[7:0])
        8'h11: rdata = csr_nxt.mvendorid;
        8'h12: rdata = csr_nxt.marchid;
        8'h13: rdata = csr_nxt.mimpid;
        8'h14: rdata = csr_nxt.mhartid;
        8'h15: rdata = csr_nxt.mconfigptr;
        endcase
    end
    4'h3: begin
        unique case (raddr[7:5])
        3'b000: begin
            unique case (raddr[4:0])
            5'h00: rdata = csr_nxt.mstatus;
            5'h01: rdata = csr_nxt.misa;
            5'h02: rdata = csr_nxt.medeleg;
            5'h03: rdata = csr_nxt.mideleg;
            5'h04: rdata = csr_nxt.mie;
            5'h05: rdata = csr_nxt.mtvec;
            5'h06: rdata = csr_nxt.mcounteren;
            5'h10: rdata = csr_nxt.mstatush;
            5'h0a: rdata = csr_nxt.menvcfg[31:0];
            5'h1a: rdata = csr_nxt.menvcfg[63:32];
            endcase
        end
        3'b010: begin
            unique case (raddr[4:0])
            5'h00: rdata = csr_nxt.mscratch;
            5'h01: rdata = csr_nxt.mepc;
            5'h02: rdata = csr_nxt.mcause;
            5'h03: rdata = csr_nxt.mtval;
            5'h04: rdata = csr_nxt.mip;
            endcase
        end
        3'b101: begin
            if (raddr[4]) begin // pmpaddrs
                rdata = csr_nxt.pmpaddrs[raddr[3:0]];
            end else if (raddr[3:2] == 2'b00) begin // pmpcfgs
                rdata = csr_nxt.pmpcfgs[raddr[1:0]];
            end
        end
        3'b001: begin
            rdata = csr_nxt.mhpmevents[raddr[4:0]];
        end
        endcase
    end
    4'h7: begin
        unique case (raddr[7:0])
        8'h47: rdata = csr_nxt.mseccfg[31:0];
        8'h57: rdata = csr_nxt.mseccfg[63:32];
        endcase
    end
    4'hb: begin // read only shadows of machien mode csrs
        unique case (raddr[7:5])
        3'b000: rdata = csr_nxt.mhpmcounters[raddr[4:0]][31:0];
        3'b100: rdata = csr_nxt.mhpmcounters[raddr[4:0]][63:32];
        endcase
    end
    endcase
end

// write port
always_comb end: csr_write
    csr_nxt = csr_now;
    // exceptions

    // csr write insts
    // TODO: write only legal bits
    if (we) begin
    unique case (waddr[11:8])
        4'h0: begin
            unique case (waddr[7:0])
            8'h01: csr_nxt.fcsr.fflags = wdata;
            8'h02: csr_nxt.fcsr.frm = wdata;
            8'h03: csr_nxt.fcsr = wdata;
            endcase
        end
        4'h1: begin
            unique case (waddr[7:0])
            8'h00: csr_nxt.mstatus = wdata;
            8'h04: csr_nxt.mie = wdata;
            8'h44: csr_nxt.mip = wdata;

            8'h05: csr_nxt.stvec = wdata;
            8'h06: csr_nxt.scounteren = wdata;
            8'h0a: csr_nxt.senvcfg = wdata;
            8'h40: csr_nxt.sscratch = wdata;
            8'h41: csr_nxt.sepc = wdata;
            8'h42: csr_nxt.scause = wdata;
            8'h43: csr_nxt.stval = wdata;
            8'h80: csr_nxt.satp = wdata;
            endcase
        end
        4'h3: begin
            unique case (waddr[7:5])
            3'b000: begin
                unique case (waddr[4:0])
                5'h00: csr_nxt.mstatus = wdata;
                5'h01: csr_nxt.misa = wdata;
                5'h02: csr_nxt.medeleg = wdata;
                5'h03: csr_nxt.mideleg = wdata;
                5'h04: csr_nxt.mie = wdata;
                5'h05: csr_nxt.mtvec = wdata;
                5'h06: csr_nxt.mcounteren = wdata;
                5'h10: csr_nxt.mstatush = wdata;
                5'h0a: csr_nxt.menvcfg[31:0] = wdata;
                5'h1a: csr_nxt.menvcfg[63:32] = wdata;
                endcase
            end
            3'b010: begin
                unique case (waddr[4:0])
                5'h00: csr_nxt.mscratch = wdata;
                5'h01: csr_nxt.mepc = wdata;
                5'h02: csr_nxt.mcause = wdata;
                5'h03: csr_nxt.mtval = wdata;
                5'h04: csr_nxt.mip = wdata;
                endcase
            end
            3'b101: begin
                if (waddr[4]) begin // pmpaddrs
                    csr_nxt.pmpaddrs[waddr[3:0]] = wdata;
                end else if (waddr[3:2] == 2'b00) begin // pmpcfgs
                    csr_nxt.pmpcfgs[waddr[1:0]] = wdata;
                end
            end
            3'b001: begin
                csr_nxt.mhpmevents[waddr[4:0]] = wdata;
            end
            endcase
        end
        4'h7: begin
            unique case (waddr[7:0])
            8'h47: csr_nxt.mseccfg[31:0] = wdata;
            8'h57: csr_nxt.mseccfg[63:32] = wdata;
            endcase
        end
        4'hb: begin // read only shadows of machien mode csrs
            unique case (waddr[7:5])
            3'b000: csr_nxt.mhpmcounters[waddr[4:0]][31:0] = wdata;
            3'b100: csr_nxt.mhpmcounters[waddr[4:0]][63:32] = wdata;
            endcase
        end
        endcase
    end
end

always_ff @(posedge clk or posedge rst) begin: csr_reset_and_update
    if (rst) begin
        // TODO: csrs reset value
        csr_now.uepc <= '0;
    csr_now.fcsr <= '0;
    csr_now.seed <= '0;
    csr_now.mhpmcounters <= '0;
    csr_now.mhpmevents <= '0;
    csr_now.mtimecmp <= '0;
        csr_now.stvec <= '0;
        csr_now.scounteren <= '0;
    csr_now.senvcfg <= '0;
        csr_now.sscratch <= '0;
        csr_now.spec <= '0;
        csr_now.scause <= '0;
        csr_now.stval <= '0;
        csr_now.satp <= '0;
        // read-onlys id CSRs
        csr_now.mvendorid <= MVENDORID_INIT;
        csr_now.marchid <= MARCHID_INIT;
        csr_now.mimpid <= MIMPID_INIT;
        csr_now.mhartid <= MHARTID_INIT;
    csr_now.mconfigptr <= '0;
        // mstatus
    csr_now.mstatus <= '0;
    csr_now.mstatush <= '0;
    csr_now.mie <= '0;
    csr_now.mip <= '0;
        // misa: WARL R/W
        csr_now.misa <= MISA_INIT;
        csr_now.medeleg <= '0;
        csr_now.mideleg <= '0;
        csr_now.mtvec <= '0;
        csr_now.mcounteren <= '0;
        csr_now.mscratch <= '0;
        csr_now.mepc <= '0;
        csr_now.mcause <= '0;
        csr_now.mtval <= '0;
    csr_now.menvcfg <= '0;
    csr_now.mseccfg <= '0;
        csr_now.pmpcfgs <= '0;
        csr_now.pmpaddrs <= '0;
    end else begin
        csr_now <= csr_nxt;
    end
end

always_ff @(posedge clk or posedge rst) begin: mode_reset_and_update
    if (rst) cpu_mode <= MODE_M;
    // TODO: update cpu mode
    else cpu_mode <= MODE_M;
end

endmodule
