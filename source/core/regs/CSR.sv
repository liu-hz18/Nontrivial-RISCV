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
cpu_mode_t lsu_cpu_mode_view; // LSU 真正可见的 mode

assign lsu_cpu_mode_view = csr_now.mstatus.mprv ? csr_now.mstatus.mpp : cpu_mode;

// TODO: check `illegal_csr_write`, which will raise an illegal instruction exception.
logic illegal_csr_write;


// TODO: exception and interrupt check.

// read port. 
// !we DONOT implement write data bypass: if a CSRW inst is executed, we flush the pipeline and redirect `pc` to "pc+4".
// !and since we also flush pipeline when an exception occurs, the CSR values that other unit access are safe in most cases.
always_comb begin: csr_read
    rdata = '0;
    unique case (raddr[11:8])
    4'h0: begin
        unique case (raddr[7:0])
        8'h01: rdata = { 27'b0, csr_now.fcsr.fflags };
        8'h02: rdata = { 29'b0, csr_now.fcsr.frm };
        8'h03: rdata = csr_now.fcsr;
        8'h15: rdata = csr_now.seed;
        endcase
    end
    4'hc: begin // read only shadows of machien mode csrs
        unique case (raddr[7:5])
        3'b000: rdata = csr_now.mhpmcounters[raddr[4:0]][31:0];
        3'b100: rdata = csr_now.mhpmcounters[raddr[4:0]][63:32];
        endcase
    end
    4'h1: begin
        unique case (raddr[7:0])
        8'h00: rdata = csr_now.mstatus & SSTATUS_RMASK; // status actually.
        8'h04: rdata = csr_now.mie & SIE_RWMASK & csr_now.mideleg; // sie actually.
        8'h44: rdata = csr_now.mip & SIP_RWMASK & csr_now.mideleg; // sip actually.

        8'h05: rdata = csr_now.stvec;
        8'h06: rdata = csr_now.scounteren;
        8'h0a: rdata = csr_now.senvcfg;
        8'h40: rdata = csr_now.sscratch;
        8'h41: rdata = csr_now.sepc;
        8'h42: rdata = csr_now.scause;
        8'h43: rdata = csr_now.stval;
        8'h80: rdata = csr_now.satp;
        endcase
    end
    4'hf: begin // read-only
        unique case (raddr[7:0])
        8'h11: rdata = csr_now.mvendorid;
        8'h12: rdata = csr_now.marchid;
        8'h13: rdata = csr_now.mimpid;
        8'h14: rdata = csr_now.mhartid;
        8'h15: rdata = csr_now.mconfigptr;
        endcase
    end
    4'h3: begin
        unique case (raddr[7:5])
        3'b000: begin
            unique case (raddr[4:0])
            5'h00: rdata = { (csr_now.mstatus.fs == 2'b11), csr_now.mstatus[30:0] };
            5'h01: rdata = csr_now.misa;
            5'h02: rdata = csr_now.medeleg;
            5'h03: rdata = csr_now.mideleg;
            5'h04: rdata = csr_now.mie;
            5'h05: rdata = csr_now.mtvec;
            5'h06: rdata = csr_now.mcounteren;
            5'h10: rdata = csr_now.mstatush;
            5'h0a: rdata = csr_now.menvcfg[31:0];
            5'h1a: rdata = csr_now.menvcfg[63:32];
            endcase
        end
        3'b010: begin
            unique case (raddr[4:0])
            5'h00: rdata = csr_now.mscratch;
            5'h01: rdata = csr_now.mepc;
            5'h02: rdata = csr_now.mcause;
            5'h03: rdata = csr_now.mtval;
            5'h04: rdata = csr_now.mip;
            endcase
        end
        3'b101: begin
            if (raddr[4]) begin // pmpaddrs
                rdata = csr_now.pmpaddrs[raddr[3:0]];
            end else if (raddr[3:2] == 2'b00) begin // pmpcfgs
                rdata = csr_now.pmpcfgs[raddr[1:0]];
            end
        end
        3'b001: begin
            if (waddr[4:0] == 0) rdata = csr_now.mcountinhibit;
            else rdata = csr_now.mhpmevents[raddr[4:0]];
        end
        endcase
    end
    4'h7: begin
        unique case (raddr[7:0])
        8'h47: rdata = csr_now.mseccfg[31:0];
        8'h57: rdata = csr_now.mseccfg[63:32];
        endcase
    end
    4'hb: begin // read only shadows of machien mode csrs
        unique case (raddr[7:5])
        3'b000: rdata = csr_now.mhpmcounters[raddr[4:0]][31:0];
        3'b100: rdata = csr_now.mhpmcounters[raddr[4:0]][63:32];
        endcase
    end
    endcase
end

// write port
always_comb end: csr_write
    csr_nxt = csr_now;
    // exceptions check

    // csr write insts, write only legal bits
    // TODO: check `we` is not enough.
    if (we) begin
    unique case (waddr[11:8])
        4'h0: begin
            unique case (waddr[7:0])
            8'h01: csr_nxt.fcsr.fflags = wdata[4:0];
            8'h02: csr_nxt.fcsr.frm = wdata[2:0];
            8'h03: csr_nxt.fcsr = wdata & FCSR_WMASK;
            8'h15: csr_nxt.seed = wdata & SEED_WMASK;
            endcase
        end
        4'h1: begin
            unique case (waddr[7:0])
            8'h00: csr_nxt.mstatus = wdata & SSTATUS_WMASK; // sstatus actually.
            8'h04: csr_nxt.mie = wdata & SIE_RWMASK & csr_now.mideleg; // sie actually.
            8'h44: csr_nxt.mip = wdata & SIP_RWMASK & csr_now.mideleg; // sip actually.

            8'h05: csr_nxt.stvec = wdata;
            8'h06: csr_nxt.scounteren = wdata;
            8'h0a: csr_nxt.senvcfg = wdata & SENVCFG_WMASK;
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
                5'h00: csr_nxt.mstatus = wdata & MSTATUS_WMASK;
                5'h01: csr_nxt.misa = wdata & MISA_WMASK;
                5'h02: csr_nxt.medeleg = wdata & MEDELEG_WMASK;
                5'h03: csr_nxt.mideleg = wdata & MIDELEG_WMASK;
                5'h04: csr_nxt.mie = wdata & MIE_WMASK;
                5'h05: csr_nxt.mtvec = wdata;
                5'h06: csr_nxt.mcounteren = wdata;
                5'h10: csr_nxt.mstatush = wdata & MSTATUSH_WMASK;
                5'h0a: csr_nxt.menvcfg[31:0] = wdata & MENVCFG_WMASK[31:0];
                5'h1a: csr_nxt.menvcfg[63:32] = wdata & MENVCFG_WMASK[63:32];
                endcase
            end
            3'b010: begin
                unique case (waddr[4:0])
                5'h00: csr_nxt.mscratch = wdata;
                5'h01: csr_nxt.mepc = wdata & MEPC_WMASK;
                5'h02: csr_nxt.mcause = wdata;
                5'h03: csr_nxt.mtval = wdata;
                5'h04: csr_nxt.mip = wdata & MIP_WMASK;
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
                if (waddr[4:0] == 0) csr_nxt.mcountinhibit = wdata;
                else csr_nxt.mhpmevents[waddr[4:0]] = wdata;
            end
            endcase
        end
        4'h7: begin
            unique case (waddr[7:0])
            8'h47: csr_nxt.mseccfg[31:0] = wdata & MSECCFG_WMASK[31:0];
            8'h57: csr_nxt.mseccfg[63:32] = wdata & MSECCFG_WMASK[63:32];
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
        // csrs reset value
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
        csr_now.mstatus <= MSTATUS_INIT;
        csr_now.mstatush <= MSTATUSH_INIT;
        csr_now.mie <= '0;
        csr_now.mip <= '0;
        // misa: WARL R/W
        csr_now.misa <= MISA_INIT;
        csr_now.medeleg <= '0;
        csr_now.mideleg <= '0;
        csr_now.mtvec <= '0;
        csr_now.mcounteren <= '0;
        csr_now.mcountinhibit <= '0;
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
