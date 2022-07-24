// Floating Point Computational Unit
import bitutils::*;
import bundle::*;
import micro_ops::*;
import csr_def::*;
import exception::*;

module FPU (
    input clk, rst,

    input logic flush,
    input op_t op,
    input word_t fpr_rs1,
    input word_t fpr_rs2,
    input word_t fpr_rs3,

    input word_t gpr_rs1,

    output word_t float_result,
    output word_t fix_result,
    output logic[4:0] fflags, // [4:0] = NV, DZ, OF, UF, NX
    output logic busy
);

// instance of FPU Functional Units
logic maddsub_valid;
logic maddsub_result_tvalid;
logic [7:0] maddsub_operation_tdata;
word_t maddsub_result_tdata, nmaddsub_result_tdata;
assign nmaddsub_result_tdata = { ~maddsub_result_tdata[31], maddsub_result_tdata[30:0] };
logic [2:0] maddsub_result_tuser;
fpu_maddsub fpu_maddsub (
    .aclk(clk),                                   // input wire aclk
    .s_axis_a_tvalid(maddsub_valid),                  // input wire s_axis_a_tvalid
    .s_axis_a_tdata(fpr_rs1),                    // input wire [31 : 0] s_axis_a_tdata
    .s_axis_b_tvalid(maddsub_valid),                  // input wire s_axis_b_tvalid
    .s_axis_b_tdata(fpr_rs2),                    // input wire [31 : 0] s_axis_b_tdata
    .s_axis_c_tvalid(maddsub_valid),                  // input wire s_axis_c_tvalid
    .s_axis_c_tdata(fpr_rs3),                    // input wire [31 : 0] s_axis_c_tdata
    .s_axis_operation_tvalid(maddsub_valid),  // input wire s_axis_operation_tvalid
    .s_axis_operation_tdata(maddsub_operation_tdata),    // input wire [7 : 0] s_axis_operation_tdata
    .m_axis_result_tvalid(maddsub_result_tvalid),        // output wire m_axis_result_tvalid
    .m_axis_result_tdata(maddsub_result_tdata),          // output wire [31 : 0] m_axis_result_tdata
    .m_axis_result_tuser(maddsub_result_tuser)          // output wire [2 : 0] m_axis_result_tuser
);


logic mul_valid;
logic mul_ready;
logic mul_result_tvalid;
word_t mul_result_tdata;
logic [2:0] mul_result_tuser;
fpu_mul fpu_mul (
  .aclk(clk),                                  // input wire aclk
  .s_axis_a_tvalid(mul_valid),            // input wire s_axis_a_tvalid
  .s_axis_a_tdata(fpr_rs1),              // input wire [31 : 0] s_axis_a_tdata
  .s_axis_b_tvalid(mul_valid),            // input wire s_axis_b_tvalid
  .s_axis_b_tdata(fpr_rs2),              // input wire [31 : 0] s_axis_b_tdata
  .m_axis_result_tvalid(mul_result_tvalid),  // output wire m_axis_result_tvalid
  .m_axis_result_tdata(mul_result_tdata),    // output wire [31 : 0] m_axis_result_tdata
  .m_axis_result_tuser(mul_result_tuser)    // output wire [2 : 0] m_axis_result_tuser
);


logic sqrt_valid;
logic sqrt_result_tvalid;
word_t sqrt_result_tdata;
logic sqrt_result_tuser;
fpu_sqrt fpu_sqrt (
  .aclk(clk),                                  // input wire aclk
  .s_axis_a_tvalid(sqrt_valid),            // input wire s_axis_a_tvalid
  .s_axis_a_tdata(fpr_rs1),              // input wire [31 : 0] s_axis_a_tdata
  .m_axis_result_tvalid(sqrt_result_tvalid),  // output wire m_axis_result_tvalid
  .m_axis_result_tdata(sqrt_result_tdata),    // output wire [31 : 0] m_axis_result_tdata
  .m_axis_result_tuser(sqrt_result_tuser)    // output wire [0 : 0] m_axis_result_tuser
);


logic div_valid;
logic div_result_tvalid;
word_t div_result_tdata;
logic [3:0] div_result_tuser;
fpu_div fpu_div (
  .aclk(clk),                                  // input wire aclk
  .s_axis_a_tvalid(div_valid),            // input wire s_axis_a_tvalid
  .s_axis_a_tdata(fpr_rs1),              // input wire [31 : 0] s_axis_a_tdata
  .s_axis_b_tvalid(div_valid),            // input wire s_axis_b_tvalid
  .s_axis_b_tdata(fpr_rs2),              // input wire [31 : 0] s_axis_b_tdata
  .m_axis_result_tvalid(div_result_tvalid),  // output wire m_axis_result_tvalid
  .m_axis_result_tdata(div_result_tdata),    // output wire [31 : 0] m_axis_result_tdata
  .m_axis_result_tuser(div_result_tuser)    // output wire [3 : 0] m_axis_result_tuser
);


logic cmp_valid;
logic [7:0] cmp_operation_tdata;
logic cmp_result_tvalid;
logic [7:0] cmp_result_tdata;
logic cmp_result_tuser;
fpu_cmp fpu_cmp (
  .aclk(clk),                                        // input wire aclk
  .s_axis_a_tvalid(cmp_valid),                  // input wire s_axis_a_tvalid
  .s_axis_a_tdata(fpr_rs1),                    // input wire [31 : 0] s_axis_a_tdata
  .s_axis_b_tvalid(cmp_valid),                  // input wire s_axis_b_tvalid
  .s_axis_b_tdata(fpr_rs2),                    // input wire [31 : 0] s_axis_b_tdata
  .s_axis_operation_tvalid(cmp_valid),  // input wire s_axis_operation_tvalid
  .s_axis_operation_tdata(cmp_operation_tdata),    // input wire [7 : 0] s_axis_operation_tdata
  .m_axis_result_tvalid(cmp_result_tvalid),        // output wire m_axis_result_tvalid
  .m_axis_result_tdata(cmp_result_tdata),          // output wire [7 : 0] m_axis_result_tdata
  .m_axis_result_tuser(cmp_result_tuser)          // output wire [0 : 0] m_axis_result_tuser
);


logic addsub_valid;
logic [7:0] addsub_operation_tdata;
logic addsub_result_tvalid;
word_t addsub_result_tdata;
logic [2:0] addsub_result_tuser;
fpu_addsub fpu_addsub (
  .aclk(clk),                                        // input wire aclk
  .s_axis_a_tvalid(addsub_valid),                  // input wire s_axis_a_tvalid
  .s_axis_a_tdata(fpr_rs1),                    // input wire [31 : 0] s_axis_a_tdata
  .s_axis_b_tvalid(addsub_valid),                  // input wire s_axis_b_tvalid
  .s_axis_b_tdata(fpr_rs2),                    // input wire [31 : 0] s_axis_b_tdata
  .s_axis_operation_tvalid(addsub_valid),  // input wire s_axis_operation_tvalid
  .s_axis_operation_tdata(addsub_operation_tdata),    // input wire [7 : 0] s_axis_operation_tdata
  .m_axis_result_tvalid(addsub_result_tvalid),        // output wire m_axis_result_tvalid
  .m_axis_result_tdata(addsub_result_tdata),          // output wire [31 : 0] m_axis_result_tdata
  .m_axis_result_tuser(addsub_result_tuser)          // output wire [2 : 0] m_axis_result_tuser
);


logic fix2float_signed_valid;
logic fix2float_signed_result_tvalid;
word_t fix2float_signed_result_tdata;
fpu_fix2float_signed fpu_fix2float_signed (
  .aclk(clk),                                  // input wire aclk
  .s_axis_a_tvalid(fix2float_signed_valid),            // input wire s_axis_a_tvalid
  .s_axis_a_tdata(gpr_rs1),              // input wire [31 : 0] s_axis_a_tdata
  .m_axis_result_tvalid(fix2float_signed_result_tvalid),  // output wire m_axis_result_tvalid
  .m_axis_result_tdata(fix2float_signed_result_tdata)    // output wire [31 : 0] m_axis_result_tdata
);


logic fix2float_unsigned_valid;
logic fix2float_unsigned_result_tvalid;
word_t fix2float_unsigned_result_tdata;
fpu_fix2float_unsigned fpu_fix2float_unsigned (
  .aclk(clk),                                  // input wire aclk
  .s_axis_a_tvalid(fix2float_unsigned_valid),            // input wire s_axis_a_tvalid
  .s_axis_a_tdata(gpr_rs1),              // input wire [31 : 0] s_axis_a_tdata
  .m_axis_result_tvalid(fix2float_unsigned_result_tvalid),  // output wire m_axis_result_tvalid
  .m_axis_result_tdata(fix2float_unsigned_result_tdata)    // output wire [31 : 0] m_axis_result_tdata
);


logic float2fix_signed_valid;
logic float2fix_signed_result_tvalid;
word_t float2fix_signed_result_tdata;
logic [1:0] float2fix_signed_result_tuser;
fpu_float2fix_signed fpu_float2fix_signed (
  .aclk(clk),                                  // input wire aclk
  .s_axis_a_tvalid(float2fix_signed_valid),            // input wire s_axis_a_tvalid
  .s_axis_a_tdata(fpr_rs1),              // input wire [31 : 0] s_axis_a_tdata
  .m_axis_result_tvalid(float2fix_signed_result_tvalid),  // output wire m_axis_result_tvalid
  .m_axis_result_tdata(float2fix_signed_result_tdata),    // output wire [31 : 0] m_axis_result_tdata
  .m_axis_result_tuser(float2fix_signed_result_tuser)    // output wire [1 : 0] m_axis_result_tuser
);


logic float2fix_unsigned_valid;
logic float2fix_unsigned_result_tvalid;
logic [39:0] float2fix_unsigned_result_tdata_tmp;
word_t float2fix_unsigned_result_tdata;
assign float2fix_unsigned_result_tdata = float2fix_unsigned_result_tdata_tmp[32] ? 32'b0 : float2fix_unsigned_result_tdata_tmp[31:0];
logic [1:0] float2fix_unsigned_result_tuser;
fpu_float2fix_unsigned fpu_float2fix_unsigned (
  .aclk(clk),                                  // input wire aclk
  .s_axis_a_tvalid(float2fix_unsigned_valid),            // input wire s_axis_a_tvalid
  .s_axis_a_tdata(fpr_rs1),              // input wire [31 : 0] s_axis_a_tdata
  .m_axis_result_tvalid(float2fix_unsigned_result_tvalid),  // output wire m_axis_result_tvalid
  .m_axis_result_tdata(float2fix_unsigned_result_tdata_tmp),    // output wire [39 : 0] m_axis_result_tdata
  .m_axis_result_tuser(float2fix_unsigned_result_tuser)    // output wire [1 : 0] m_axis_result_tuser
);


typedef enum {
    IDLE,
    WAITING_READY,
    WAITING_VALID
} fpu_state_t;
fpu_state_t fpu_state_now, fpu_state_nxt;
assign busy = (fpu_state_nxt != IDLE);

// TODO: refine this judgement to IDU stage
logic should_multi_cycle;
assign should_multi_cycle = (op == OP_FMADDS) || (op == OP_FMSUBS) || (op == OP_FNMSUBS) || (op == OP_FNMADDS) || (op == OP_FADDS) || (op == OP_FSUBS) || (op == OP_FMULS) || (op == OP_FDIVS) || (op == OP_FSQRTS) || (op == OP_FMINS) || (op == OP_FMAXS) || (op == OP_FEQS) || (op == OP_FLTS) || (op == OP_FLES) || (op == OP_FCVTWS) || (op == OP_FCVTWUS) || (op == OP_FCVTSW) || (op == OP_FCVTSWU);

logic result_valid;
assign result_valid = maddsub_result_tvalid|mul_result_tvalid|sqrt_result_tvalid|div_result_tvalid|cmp_result_tvalid|addsub_result_tvalid|fix2float_signed_result_tvalid|fix2float_unsigned_result_tvalid|float2fix_signed_result_tvalid|float2fix_unsigned_result_tvalid;


// IEEE 754 Single Precision Float
// sign | exp |frac
//   1     8     23
//           1.frac

// classify fpr_rs1
// any value with all bits of the exponent set and at least one bit of the fraction set represents a NaN
// It is implementation-defined which values of the fraction represent quiet or signaling NaNs, and whether the sign bit is meaningful.
logic [7:0] exponent;
logic [22:0] fraction;
assign exponent = fpr_rs1[30:23];
assign fraction = fpr_rs1[22:0];
logic exp_all_zero, exp_all_one;
assign exp_all_zero = ~(|exponent);
assign exp_all_one = &exponent;
logic frac_all_zero, frac_all_one;
assign frac_all_zero = ~(|fraction);
assign frac_all_one = &fraction;

logic quietNaN, signalNaN, positive_inf, positive_normal, positive_subnormal, positive_zero, negative_zero, negative_subnormal, negative_normal, negative_inf;
assign quietNaN = exp_all_one & (~frac_all_zero) & fraction[22]; // quiet bit: MSB of fraction is set
assign signalNaN = exp_all_one & (~frac_all_zero) & (~fraction[22]);
assign positive_inf = (~fpr_rs1[31]) & exp_all_one & frac_all_zero;
assign negative_inf = (fpr_rs1[31]) & exp_all_one & frac_all_zero;
assign positive_normal = (~fpr_rs1[31]) & (~exp_all_zero) & (~exp_all_one);
assign negative_normal = (fpr_rs1[31]) & (~exp_all_zero) & (~exp_all_one);
assign positive_subnormal = (~fpr_rs1[31]) & exp_all_zero & (~frac_all_zero);
assign negative_subnormal = (fpr_rs1[31]) & exp_all_zero & (~frac_all_zero);
assign positive_zero = (~fpr_rs1[31]) & exp_all_zero & frac_all_zero;
assign negative_zero = (fpr_rs1[31]) & exp_all_zero & frac_all_zero;

// !FIXIT
// TODO: we don't confirm `ready` when begin a request,
//       so when a `flush` signal is given, we leave the FPUs behind, 
//       when the next FPU inst come a few cycles then, 
//       our implementation will take the last requests `valid` signal as result,
//       THIS IS NOT PERMITTED!
// !one possible solution: count cycles when requests begin, until the counter meets its requirement.
always_comb begin
    fpu_state_nxt = fpu_state_now;
    maddsub_valid = '0;
    maddsub_operation_tdata = '0;
    mul_valid = '0;
    sqrt_valid = '0;
    div_valid = '0;
    cmp_valid = '0;
    cmp_operation_tdata = '0;
    addsub_valid = '0;
    addsub_operation_tdata = '0;
    fix2float_signed_valid = '0;
    fix2float_unsigned_valid = '0;
    float2fix_signed_valid = '0;
    float2fix_unsigned_valid = '0;
    unique case (fpu_state_now)
    IDLE: begin
        if (flush) fpu_state_nxt = IDLE;
        else if (should_multi_cycle) fpu_state_nxt = WAITING_READY;
    end
    WAITING_READY: begin    
        if (flush) fpu_state_nxt = IDLE;
        else begin
            fpu_state_nxt = WAITING_VALID;
            unique case (op)
            OP_FMADDS, OP_FNMADDS: begin
                maddsub_valid = 1'b1;
                maddsub_operation_tdata = 7'b0_000000;
            end
            OP_FMSUBS, OP_FNMSUBS: begin
                maddsub_valid = 1'b1;
                maddsub_operation_tdata = 7'b0_000001;
            end
            OP_FADDS: begin
                addsub_valid = 1'b1;
                addsub_operation_tdata = 7'b0_000000;
            end
            OP_FSUBS: begin
                addsub_valid = 1'b1;
                addsub_operation_tdata = 7'b0_000001;
            end
            OP_FMULS: begin
                mul_valid = 1'b1;
            end
            OP_FDIVS: begin
                div_valid = 1'b1;
            end
            OP_FSQRTS: begin
                sqrt_valid = 1'b1;
            end
            OP_FMINS: begin
                cmp_valid = 1'b1;
                cmp_operation_tdata = 7'b0_001100;
            end
            OP_FMAXS: begin
                cmp_valid = 1'b1;
                cmp_operation_tdata = 7'b0_100100;
            end
            OP_FEQS: begin
                cmp_valid = 1'b1;
                cmp_operation_tdata = 7'b0_010100;
            end
            OP_FLTS: begin
                cmp_valid = 1'b1;
                cmp_operation_tdata = 7'b0_001100;
            end
            OP_FLES: begin
                cmp_valid = 1'b1;
                cmp_operation_tdata = 7'b0_011100;
            end
            OP_FCVTWS: begin
                float2fix_signed_valid = 1'b1;
            end
            OP_FCVTWUS: begin
                float2fix_unsigned_valid = 1'b1;
            end
            OP_FCVTSW: begin
                fix2float_signed_valid = 1'b1;
            end
            OP_FCVTSWU: begin
                fix2float_unsigned_valid = 1'b1;
            end
            endcase
        end
    end
    WAITING_VALID: begin
        if (flush) fpu_state_nxt = IDLE;
        else if (result_valid) fpu_state_nxt = IDLE;
    end
    endcase
end

always_ff @(posedge clk or posedge rst) begin
    if (rst) fpu_state_now <= IDLE;
    else fpu_state_now <= fpu_state_nxt;
end

// However, the Xilinx Floating-Point Operator core treats all NaNs as Quiet NaNs. 
// When any NaN is supplied as one of the operands to the core, 
// the result is a Quiet NaN, and an invalid operation exception is not raised.
// !Rounding Mode: Xilinx IP only support `Round to Nearest Even` mode
// !Except when otherwise stated, if the result of a floating-point operation is NaN, it is the canonical NaN.
//  The canonical NaN has a positive sign and all significand bits clear except the MSB, a.k.a. the quiet bit. (32'h7fc0_0000)
localparam logic[31:0] CANONICAL_NAN = 32'h7fc0_0000;
always_comb begin: fpu_mux
    fix_result = '0;
    float_result = '0;
    unique case(op)
    // rs1*rs2 + rs3
    OP_FMADDS: float_result = maddsub_result_tdata;
    // rs1*rs2 - rs3
    OP_FMSUBS: float_result = maddsub_result_tdata;
    // -(rs1*rs2 + rs3)
    OP_FNMSUBS: float_result = nmaddsub_result_tdata;
    // -(rs1*rs2 - rs3)
    OP_FNMADDS: float_result = nmaddsub_result_tdata;

    OP_FADDS: float_result = addsub_result_tdata;
    OP_FSUBS: float_result = addsub_result_tdata;
    OP_FMULS: float_result = mul_result_tdata;
    OP_FDIVS: float_result = div_result_tuser;
    OP_FSQRTS: float_result = sqrt_result_tdata;
    
    OP_FMINS: float_result = cmp_result_tdata[0] ? fpr_rs1 : fpr_rs2;
    OP_FMAXS: float_result = cmp_result_tdata[0] ? fpr_rs1 : fpr_rs2;

    OP_FEQS: fix_result = { 30'b0, cmp_result_tdata[0] };
    OP_FLTS: fix_result = { 30'b0, cmp_result_tdata[0] };
    OP_FLES: fix_result = { 30'b0, cmp_result_tdata[0] };
    // F2F sign-injection instructions (can used for value movement)
    // FPR[rs2]'s sign bit with FPR[rs1]'s abs value.
    OP_FSGNJS: float_result = { fpr_rs2[31], fpr_rs1[30:0] };
    // opposite of FPR[rs2]'s sign bit with FPR[rs1]'s abs value.
    OP_FSGNJNS: float_result = { ~fpr_rs2[31], fpr_rs1[30:0] };
    // (FPR[rs2]'s sign bit ^ FPR[rs1]'s sign bit) with FPR[rs1]'s abs value.
    OP_FSGNJXS: float_result = { fpr_rs2[31]^fpr_rs1[31], fpr_rs1[30:0] };
    // Conversions round accroding to the [rm] field.
    // Xilinx: NaN and infinity raise an invalid operation exception. If the operand is out of range, or an infinity, then an overflow exception is raised
    // signed(FPR[rs]) -> GPR[rd] 
    // !NOTE: out-of-range negative input (including -inf) will be transformed to -2^31
    //        out-of-range positive input (including +inf) will be transformed to 2^31-1
    OP_FCVTWS: fix_result = float2fix_signed_result_tdata;
    // unsigned(FPR[rs]) -> GPR[rd]
    // !NOTE: out-of-range negative input (including -inf) will be transformed to 0
    //        out-of-range positive input (including +inf) will be transformed to 2^32-1
    OP_FCVTWUS: fix_result = float2fix_unsigned_result_tdata;
    // signed(GPR[rs1]) -> FPR[rd]
    OP_FCVTSW: float_result = fix2float_signed_result_tdata;
    // unsigned(GPR[rs1]) -> FPR[rd]
    OP_FCVTSWU: float_result = fix2float_unsigned_result_tdata;
    // simple copy bits(FPR[rs1]) -> GPR[rd]
    OP_FMVXW: fix_result = fpr_rs1;
    // simple copy bits(GPR[rs1]) -> FPR[rd]
    OP_FMVWX: float_result = gpr_rs1;
    // TODO: classcification(FPR[rs1]) -> GPR[rd] (only lower 10 bit valid)
    // quiet NaN, signaling NaN, +inf, positive normal number, positive subnormal number, +0, -0, negative subnormal number, negative normal number, -inf
    //     9            8          7              6                          5             4   3                2                          1           0
    // !NOTE: exactly one bit in rd will be set.
    OP_FCLASSS: fix_result = { 22'b0, 
        quietNaN, signalNaN, positive_inf, positive_normal, positive_subnormal,
        positive_zero, negative_zero, negative_subnormal, negative_normal, negative_inf 
    };
    endcase
end

// TODO: FPU Exception fflags set
// !The fused multiply-add instructions must set the invalid operation exception flag when the multiplicands are between "+-inf" and "+-zero", even when the addend is a quiet NaN.
always_comb begin
    fflags = '0;
    unique case(op)
    OP_FMADDS, OP_FMSUBS: fflags = '0;
    OP_FNMADDS, OP_FNMSUBS: fflags = '0;
    OP_FADDS, OP_FSUBS: fflags = '0;
    OP_FMULS: fflags = '0;
    OP_FDIVS: fflags = '0;
    OP_FSQRTS: fflags = '0;
    OP_FMINS, OP_FMAXS, OP_FEQS, OP_FLTS, OP_FLES: fflags = '0;
    OP_FSGNJS, OP_FSGNJNS, OP_FSGNJXS: fflags = '0;
    OP_FCVTWS: fflags = '0;
    OP_FCVTWUS: fflags = '0;
    OP_FCVTSW: fflags = '0;
    OP_FCVTSWU: fflags = '0;
    OP_FMVXW: fflags = '0;
    OP_FMVWX: fflags = '0;
    OP_FCLASSS: fflags = '0;
    endcase
end

endmodule
