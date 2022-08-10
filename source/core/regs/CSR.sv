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
    input word_t wdata,

    // exception
    input except_t exception,
    input word_t inst,
    input word_t pc,
    input mem_req_t mem_req,
    input inst_type_t inst_type,
    
    // interrupt
    input logic timer_interrupt,
    input logic external_interrupt,

    // CSR reg
    output csr_t csr,
    output cpu_mode_t cpu_mode,
    output cpu_mode_t lsu_cpu_mode_view, // LSU 真正可见的 mode

    // flush signal
    output logic flush,
    output word_t redirect_pc
);

csr_t csr_now, csr_nxt;
assign csr = csr_now;

cpu_mode_t cpu_mode_nxt;

assign lsu_cpu_mode_view = csr_now.mstatus.mprv ? csr_now.mstatus.mpp : cpu_mode;

// check `illegal_csr_write`, which will raise an illegal instruction exception.
logic write_read_only_csr;
logic access_at_illegal_mode;
logic access_satp_illegal;
logic access_hpms_illegal;
logic access_seed_illegal;
logic sret_forbidden;
logic illegal_inst;
assign write_read_only_csr = we && (waddr[11:10] == 2'b11);
assign access_at_illegal_mode = (cpu_mode < waddr[9:8]) | (cpu_mode < raddr[9:8]);
assign access_satp_illegal = (csr_now.mstatus.tvm && cpu_mode == MODE_S && (waddr == 12'h180 | raddr == 12'h180));
assign access_hpms_illegal = (cpu_mode[1] == 1'b0) && (~csr_now.mcounteren[raddr[4:0]] && raddr[11:8] == 4'hc);
assign access_seed_illegal = (~we && raddr == 12'h015) | (we && waddr == 12'h015 && ((~csr_now.mseccfg.sseed && cpu_mode == MODE_S) | (~csr_now.mseccfg.useed && cpu_mode == MODE_U)));
assign sret_forbidden = (exception.sret & csr_now.mstatus.tsr) | (exception.sret && cpu_mode < MODE_S);
assign illegal_inst = exception.illegal_inst | write_read_only_csr | access_at_illegal_mode | access_satp_illegal | access_hpms_illegal | access_seed_illegal | sret_forbidden;

except_t final_exception;
always_comb begin
    final_exception = exception;
    final_exception.illegal_inst = illegal_inst;
    final_exception.mret = '0;
    final_exception.sret = '0;
    final_exception.uret = '0;
end

logic is_uret, is_sret, is_mret;
assign is_uret = exception.uret;
assign is_sret = exception.sret;
assign is_mret = exception.mret;

mip_t mip_wire;
assign mip_wire = { 20'b0, external_interrupt, 1'b0, external_interrupt, 1'b0, timer_interrupt, 1'b0, timer_interrupt, 1'b0, 4'b0 };

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
        8'h44: rdata = (csr_now.mip | mip_wire) & SIP_RWMASK & csr_now.mideleg; // sip actually.

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

mip_t mip_raise_interrupt;
assign mip_raise_interrupt = csr_now.mip | mip_wire;

logic interrupt_trap_mmode;
assign interrupt_trap_mmode = ((cpu_mode == MODE_M && csr_now.mstatus.mie) || (cpu_mode != MODE_M));

logic interrupt_trap_ssmode;
assign interrupt_trap_ssmode = ((cpu_mode == MODE_S && csr_now.mstatus.sie) || (cpu_mode < MODE_S));

typedef struct packed {
    logic mei, msi, mti;
    logic sei, ssi, sti;
} interrupt_t;
interrupt_t interrupt_vec_enable; // mei, msi, mti, sei, ssi, sti
assign interrupt_vec_enable = {
    interrupt_trap_mmode & csr_now.mie.meie,
    interrupt_trap_mmode & csr_now.mie.msie,
    interrupt_trap_mmode & csr_now.mie.mtie,
    csr_now.mideleg[9] ? (interrupt_trap_ssmode & csr_now.mie.seie) : (interrupt_trap_mmode & csr_now.mie.meie),
    csr_now.mideleg[1] ? (interrupt_trap_ssmode & csr_now.mie.ssie) : (interrupt_trap_mmode & csr_now.mie.msie),
    csr_now.mideleg[5] ? (interrupt_trap_ssmode & csr_now.mie.stie) : (interrupt_trap_mmode & csr_now.mie.mtie)
};
interrupt_t interrupt_should_trap;
assign interrupt_should_trap = {
    mip_raise_interrupt[11], // mei
    mip_raise_interrupt[3],  // msi
    mip_raise_interrupt[7],  // mti
    mip_raise_interrupt[9],  // sei
    mip_raise_interrupt[1],  // ssi
    mip_raise_interrupt[5]   // sti
} & interrupt_vec_enable;

logic raise_exception, raise_interrupt;
assign raise_exception = (|final_exception);
assign raise_interrupt = (|interrupt_should_trap);

word_t exception_num, interrupt_num;
word_t cause_num;
assign cause_num = raise_interrupt ? interrupt_num : exception_num;

word_t exception_val;

logic deleg_to_smode;
assign deleg_to_smode = (cpu_mode < MODE_M) && (raise_interrupt ? csr_now.mideleg[cause_num[3:0]] : csr_now.medeleg[cause_num[3:0]]);
always_comb begin: exception_num_mux
    if (final_exception.breakpoint) begin
        exception_num = `MCAUSE_BREAKPOINT;
        exception_val = pc;
    end else if (final_exception.fetch_pagefault) begin
        exception_num = `MCAUSE_INST_PAGE_FAULT;
        exception_val = pc;
    end else if (final_exception.fetch_access_fault) begin
        exception_num = `MCAUSE_INST_ACCESS_FAULT;
        exception_val = pc;
    end else if (final_exception.illegal_inst) begin
        exception_num = `MCAUSE_ILLEGAL_INST;
        exception_val = inst;
    end else if (final_exception.fetch_misalign) begin
        exception_num = `MCAUSE_INST_ADDR_MISALIGNED;
        exception_val = pc;
    end else if (final_exception.ecall) begin
        if (cpu_mode == MODE_U) exception_num = `MCAUSE_ECALL_U;
        else if (cpu_mode == MODE_S) exception_num = `MCAUSE_ECALL_S;
        else exception_num = `MCAUSE_ECALL_M;
        exception_val = '0;
    end else if (final_exception.store_misalign) begin
        exception_num = `MCAUSE_STORE_ADDR_MISALIGNED;
        exception_val = mem_req.addr;
    end else if (final_exception.load_misalign) begin
        exception_num = `MCAUSE_LOAD_ADDR_MISALIGNED;
        exception_val = mem_req.addr;
    end else if (final_exception.store_pagefault) begin
        exception_num = `MCAUSE_STORE_PAGE_FAULT;
        exception_val = mem_req.addr;
    end else if (final_exception.load_pagefault) begin
        exception_num = `MCAUSE_LOAD_PAGE_FAULT;
        exception_val = mem_req.addr;
    end else if (final_exception.store_access_fault) begin
        exception_num = `MCAUSE_STORE_ACCESS_FAULT;
        exception_val = mem_req.addr;
    end else if (final_exception.load_access_fault) begin
        exception_num = `MCAUSE_LOAD_ACCESS_FAULT;
        exception_val = mem_req.addr;
    end else begin
        exception_num = '0;
        exception_val = '0;
    end
end
always_comb begin: interrupt_num_mux
    if (interrupt_should_trap.mei) begin
        interrupt_num = `MCAUSE_MMODE_EXT_INT;
    end else if (interrupt_should_trap.msi) begin
        interrupt_num = `MCAUSE_MMODE_SOFT_INT;
    end else if (interrupt_should_trap.mti) begin
        interrupt_num = `MCAUSE_MMODE_TIMER_INT;
    end else if (interrupt_should_trap.sei) begin
        interrupt_num = `MCAUSE_SMODE_EXT_INT;
    end else if (interrupt_should_trap.ssi) begin
        interrupt_num = `MCAUSE_SMODE_SOFT_INT;
    end else if (interrupt_should_trap.sti) begin
        interrupt_num = `MCAUSE_SMODE_TIMER_INT;
    end else begin
        interrupt_num = '0;
    end
end

assign flush = raise_interrupt | raise_exception | is_mret | is_sret | is_uret | we;

word_t mtvec, stvec;
assign mtvec = (csr_now.mtvec.mode == 2'b01 && raise_interrupt) ? { csr_now.mtvec.base+{ 28'b0, interrupt_num[3:0] }, 2'b00 } : { csr_now.mtvec.base, 2'b00 };
assign stvec = (csr_now.stvec.mode == 2'b01 && raise_interrupt) ? { csr_now.stvec.base+{ 28'b0, interrupt_num[3:0] }, 2'b00 } : { csr_now.stvec.base, 2'b00 };

// write port
always_comb begin: csr_write
    csr_nxt = csr_now;
    cpu_mode_nxt = cpu_mode;
    redirect_pc = pc;
    // exceptions check
    if (raise_interrupt | raise_exception) begin
        if (deleg_to_smode) begin
            csr_nxt.scause = cause_num;
            csr_nxt.sepc = pc;
            csr_nxt.mstatus.spie = csr_now.mstatus.sie;
            csr_nxt.mstatus.sie = 1'b0;
            csr_nxt.mstatus.spp = cpu_mode[0];
            csr_nxt.stval = exception_val;
            cpu_mode_nxt = MODE_S;
            redirect_pc = stvec;
        end else begin
            csr_nxt.mcause = cause_num;
            csr_nxt.mepc = pc;
            csr_nxt.mstatus.mpie = csr_now.mstatus.mie;
            csr_nxt.mstatus.mie = 1'b0;
            csr_nxt.mstatus.mpp = cpu_mode;
            csr_nxt.mtval = exception_val;
            cpu_mode_nxt = MODE_M;
            redirect_pc = mtvec;
        end
    end else if (is_mret) begin
        csr_nxt.mstatus.mie = csr_now.mstatus.mpie;
        cpu_mode_nxt = csr_now.mstatus.mpp;
        csr_nxt.mstatus.mpie = 1'b1;
        csr_nxt.mstatus.mpp = MODE_U;
        csr_nxt.mstatus.mprv = csr_now.mstatus.mpp == MODE_M ? 1'b0 : csr_now.mstatus.mprv;
        redirect_pc = csr_now.mepc;
    end else if (is_sret) begin
        csr_nxt.mstatus.sie = csr_now.mstatus.spie;
        cpu_mode_nxt = { 1'b0, csr_now.mstatus.spp };
        csr_nxt.mstatus.spie = 1'b1;
        csr_nxt.mstatus.spp = 1'b0;
        redirect_pc = csr_now.sepc;
    end else if (is_uret) begin
        csr_nxt.mstatus.uie = csr_now.mstatus.upie;
        cpu_mode_nxt = MODE_U;
        csr_nxt.mstatus.upie = 1'b1;
        redirect_pc = csr_now.uepc;
    end else if (we) begin // csr write insts, write only legal bits
        redirect_pc = { pc[31:2] + 30'b1, 2'b00 };
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
            4'hb: begin
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
        csr_now.sepc <= '0;
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
    else cpu_mode <= cpu_mode_nxt;
end

endmodule
