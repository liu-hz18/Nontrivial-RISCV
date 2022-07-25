// multi-cycle multiply/divide unit
import bitutils::*;
import bundle::*;
import micro_ops::*;
import csr_def::*;
import exception::*;

module MDU (
    input clk, rst,

    input logic flush,
    input op_t op,
    input inst_type_t inst_type,
    input word_t gpr_rs1,
    input word_t gpr_rs2,

    output dword_t mul_ss, // signed x signed
    output dword_t mul_su, // signed x unsigned
    output dword_t mul_uu, // unsigned x unsigned
    output word_t div_s,
    output word_t div_u,
    output word_t rem_s,
    output word_t rem_u,
    output dword_t clmul,
    output logic busy
);

localparam int DIV_SIGNED_CYCLES = 36;
localparam int DIV_UNSIGNED_CYCLES = 34;
localparam int MUL_CYCLES = 6;
localparam int CLMUL_CYCLES = 1;

byte_t cycles_count;
byte_t max_cycles;

mult_ss mult_ss (
  .CLK(clk),  // input wire CLK
  .A(gpr_rs1),      // input wire [31 : 0] A
  .B(gpr_rs2),      // input wire [31 : 0] B
  .P(mul_ss)      // output wire [63 : 0] P
);

mult_su mult_su (
  .CLK(clk),  // input wire CLK
  .A(gpr_rs1),      // input wire [31 : 0] A
  .B(gpr_rs2),      // input wire [31 : 0] B
  .P(mul_su)      // output wire [63 : 0] P
);

mult_uu mult_uu (
  .CLK(clk),  // input wire CLK
  .A(gpr_rs1),      // input wire [31 : 0] A
  .B(gpr_rs2),      // input wire [31 : 0] B
  .P(mul_uu)      // output wire [63 : 0] P
);

clmul32 clmul32 (
    .CLK(clk),  // input wire CLK
    .A(gpr_rs1), // input wire [31 : 0] A
    .B(gpr_rs2),      // input wire [31 : 0] B
    .P(clmul)   // output wire [63 : 0] P
);


logic divisor_zero;
assign divisor_zero = (gpr_rs2 == '0);
logic signed_overflow;
assign signed_overflow = (gpr_rs1 == 32'h8000_0000) & (gpr_rs2 == 32'hffff_ffff);
// signed(gpr_rs1) / signed(gpr_rs2)
dword_t div_signed_dout_tdata;
always_comb begin
    if (divisor_zero) div_s = 32'hffff_ffff;
    else if (signed_overflow) div_s = 32'h8000_0000;
    else div_s = div_signed_dout_tdata[63:32];
end
always_comb begin
    if (divisor_zero) rem_s = gpr_rs1;
    else if (signed_overflow) rem_s = '0;
    else rem_s = div_signed_dout_tdata[31:0];
end
divider_signed divider_signed (
  .aclk(clk),                                      // input wire aclk
  .s_axis_divisor_tvalid(1'b1),    // input wire s_axis_divisor_tvalid
  .s_axis_divisor_tdata(gpr_rs1),      // input wire [31 : 0] s_axis_divisor_tdata
  .s_axis_dividend_tvalid(1'b1),  // input wire s_axis_dividend_tvalid
  .s_axis_dividend_tdata(gpr_rs2),    // input wire [31 : 0] s_axis_dividend_tdata
  .m_axis_dout_tvalid(),          // output wire m_axis_dout_tvalid
  .m_axis_dout_tuser(),            // output wire [0 : 0] m_axis_dout_tuser
  .m_axis_dout_tdata(div_signed_dout_tdata)            // output wire [63 : 0] m_axis_dout_tdata
);

// unsigned(gpr_rs1) / unsigned(gpr_rs2)
dword_t div_unsigned_dout_tdata;
assign div_u = divisor_zero ? 32'hffff_ffff : div_unsigned_dout_tdata[63:32];
assign rem_u = divisor_zero ? gpr_rs1 : div_unsigned_dout_tdata[31:0];
divider_unsigned divider_unsigned (
  .aclk(clk),                                      // input wire aclk
  .s_axis_divisor_tvalid(1'b1),    // input wire s_axis_divisor_tvalid
  .s_axis_divisor_tdata(gpr_rs1),      // input wire [31 : 0] s_axis_divisor_tdata
  .s_axis_dividend_tvalid(1'b1),  // input wire s_axis_dividend_tvalid
  .s_axis_dividend_tdata(gpr_rs2),    // input wire [31 : 0] s_axis_dividend_tdata
  .m_axis_dout_tvalid(),          // output wire m_axis_dout_tvalid
  .m_axis_dout_tuser(),            // output wire [0 : 0] m_axis_dout_tuser
  .m_axis_dout_tdata(div_unsigned_dout_tdata)            // output wire [63 : 0] m_axis_dout_tdata
);

// TODO: cache last time DIV/MUL result for faster REM request.
// OP_MUL, OP_MULH, OP_MULHSU, OP_MULHU
// OP_DIV, OP_DIVU, OP_REM, OP_REMU
// OP_CLMUL, OP_CLMULH, OP_CLMULR
typedef enum {
    IDLE,
    WAIT
} mdu_fsm_t;

mdu_fsm_t mdu_state_now, mdu_state_nxt; 

always_comb begin
    mdu_state_nxt = mdu_state_now;
    unique case (mdu_state_now)
    IDLE: begin
        if (inst_type.is_mdu_multi_cycle & ~flush) mdu_state_nxt = WAIT;
    end
    WAIT: begin
        if (flush) mdu_state_nxt = IDLE;
        else if (cycles_count >= max_cycles) mdu_state_nxt = IDLE;
    end
    endcase
end

always_ff @(posedge clk or posedge rst) begin
    if (rst) mdu_state_now <= IDLE;
    else mdu_state_now <= mdu_state_nxt;
end

// max cycles control
always_ff @(posedge clk) begin
    unique case (op)
    OP_MUL, OP_MULH, OP_MULHSU, OP_MULHU: max_cycles <= MUL_CYCLES;
    OP_DIV, OP_REM: max_cycles <= DIV_SIGNED_CYCLES;
    OP_DIVU, OP_REMU: max_cycles <= DIV_UNSIGNED_CYCLES;
    OP_CLMUL, OP_CLMULH, OP_CLMULR: max_cycles <= CLMUL_CYCLES;
    endcase

    if ((mdu_state_now == IDLE) | flush) cycles_count <= '0;
    else cycles_count <= cycles_count + 1;
end

assign busy = (mdu_state_nxt != IDLE);

endmodule
