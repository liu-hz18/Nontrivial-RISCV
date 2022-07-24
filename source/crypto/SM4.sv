import bitutils::*;

// 6 cycle latency
module SM4 (
    input clk, rst,

    // input a channel
    input logic s_axis_a_tvalid,
    output logic s_axis_a_tready,
    input word_t s_axis_a_tdata,
    // input b channel
    input logic s_axis_b_tvalid,
    output logic s_axis_b_tready,
    input word_t s_axis_b_tdata,
    // input bs channel
    input logic s_axis_bs_tvalid,
    output logic s_axis_bs_tready,
    input logic[1:0] s_axis_bs_tdata,
    // input op channel
    input logic s_axis_operation_tvalid,
    output logic s_axis_operation_tready,
    input logic s_axis_operation_tdata, // ED(0), KS(1)
    // output channel
    output logic m_axis_result_tvalid,
    output word_t m_axis_result_tdata
);

byte_t [255:0] sm4_sbox_table = {
    8'hD6, 8'h90, 8'hE9, 8'hFE, 8'hCC, 8'hE1, 8'h3D, 8'hB7, 8'h16, 8'hB6, 8'h14, 8'hC2, 8'h28,
    8'hFB, 8'h2C, 8'h05, 8'h2B, 8'h67, 8'h9A, 8'h76, 8'h2A, 8'hBE, 8'h04, 8'hC3, 8'hAA, 8'h44,
    8'h13, 8'h26, 8'h49, 8'h86, 8'h06, 8'h99, 8'h9C, 8'h42, 8'h50, 8'hF4, 8'h91, 8'hEF, 8'h98,
    8'h7A, 8'h33, 8'h54, 8'h0B, 8'h43, 8'hED, 8'hCF, 8'hAC, 8'h62, 8'hE4, 8'hB3, 8'h1C, 8'hA9,
    8'hC9, 8'h08, 8'hE8, 8'h95, 8'h80, 8'hDF, 8'h94, 8'hFA, 8'h75, 8'h8F, 8'h3F, 8'hA6, 8'h47,
    8'h07, 8'hA7, 8'hFC, 8'hF3, 8'h73, 8'h17, 8'hBA, 8'h83, 8'h59, 8'h3C, 8'h19, 8'hE6, 8'h85,
    8'h4F, 8'hA8, 8'h68, 8'h6B, 8'h81, 8'hB2, 8'h71, 8'h64, 8'hDA, 8'h8B, 8'hF8, 8'hEB, 8'h0F,
    8'h4B, 8'h70, 8'h56, 8'h9D, 8'h35, 8'h1E, 8'h24, 8'h0E, 8'h5E, 8'h63, 8'h58, 8'hD1, 8'hA2,
    8'h25, 8'h22, 8'h7C, 8'h3B, 8'h01, 8'h21, 8'h78, 8'h87, 8'hD4, 8'h00, 8'h46, 8'h57, 8'h9F,
    8'hD3, 8'h27, 8'h52, 8'h4C, 8'h36, 8'h02, 8'hE7, 8'hA0, 8'hC4, 8'hC8, 8'h9E, 8'hEA, 8'hBF,
    8'h8A, 8'hD2, 8'h40, 8'hC7, 8'h38, 8'hB5, 8'hA3, 8'hF7, 8'hF2, 8'hCE, 8'hF9, 8'h61, 8'h15,
    8'hA1, 8'hE0, 8'hAE, 8'h5D, 8'hA4, 8'h9B, 8'h34, 8'h1A, 8'h55, 8'hAD, 8'h93, 8'h32, 8'h30,
    8'hF5, 8'h8C, 8'hB1, 8'hE3, 8'h1D, 8'hF6, 8'hE2, 8'h2E, 8'h82, 8'h66, 8'hCA, 8'h60, 8'hC0,
    8'h29, 8'h23, 8'hAB, 8'h0D, 8'h53, 8'h4E, 8'h6F, 8'hD5, 8'hDB, 8'h37, 8'h45, 8'hDE, 8'hFD,
    8'h8E, 8'h2F, 8'h03, 8'hFF, 8'h6A, 8'h72, 8'h6D, 8'h6C, 8'h5B, 8'h51, 8'h8D, 8'h1B, 8'hAF,
    8'h92, 8'hBB, 8'hDD, 8'hBC, 8'h7F, 8'h11, 8'hD9, 8'h5C, 8'h41, 8'h1F, 8'h10, 8'h5A, 8'hD8,
    8'h0A, 8'hC1, 8'h31, 8'h88, 8'hA5, 8'hCD, 8'h7B, 8'hBD, 8'h2D, 8'h74, 8'hD0, 8'h12, 8'hB8,
    8'hE5, 8'hB4, 8'hB0, 8'h89, 8'h69, 8'h97, 8'h4A, 8'h0C, 8'h96, 8'h77, 8'h7E, 8'h65, 8'hB9,
    8'hF1, 8'h09, 8'hC5, 8'h6E, 8'hC6, 8'h84, 8'h18, 8'hF0, 8'h7D, 8'hEC, 8'h3A, 8'hDC, 8'h4D,
    8'h20, 8'h79, 8'hEE, 8'h5F, 8'h3E, 8'hD7, 8'hCB, 8'h39, 8'h48
};

function word_t sm4_linear_shift_ed(input word_t x);
    return x ^ { x[23:0], 8'b0 } ^ { x[29:0], 2'b0 } ^ { x[13:0], 18'b0 } ^ { x[5:0], 26'b0 } ^ { 14'b0, x[7:6], 6'b0, 10'b0 };
endfunction;
function word_t sm4_linear_shift_ks(input word_t x);
    return x ^ { x[2:0], 29'b0 } ^ { 17'b0, x[7:1], 1'b0, 7'b0} ^ {8'b0, x[0], 23'b0} ^ { 11'b0, x[7:3], 3'b0, 13'b0 };
endfunction;

typedef enum {
    IDLE,
    CACHE_REQUEST,
    SBOX_LOOKUP,
    LINEAR_SHIFT,
    ROL_XOR,
    FINISH
} sm4_fsm_t;
sm4_fsm_t sm4_state_now, sm4_state_nxt;

assign s_axis_a_tready = (sm4_state_now == IDLE);
assign s_axis_b_tready = (sm4_state_now == IDLE);
assign s_axis_bs_tready = (sm4_state_now == IDLE);
assign s_axis_operation_tready = (sm4_state_now == IDLE);

assign m_axis_result_tvalid = (sm4_state_now == FINISH);

word_t cached_rs1, cached_rs2;
logic [1:0] cached_bs;
logic cached_op; // valid at CACHE_REQUEST stage
always_ff @(posedge clk) begin
    if (sm4_state_now == IDLE) cached_rs1 <= s_axis_a_tdata;
    if (sm4_state_now == IDLE) cached_rs2 <= s_axis_b_tdata;
    if (sm4_state_now == IDLE) cached_bs <= s_axis_bs_tdata;
    if (sm4_state_now == IDLE) cached_op <= s_axis_operation_tdata;
end

byte_t sbox_input; // valid at SBOX_LOOKUP stage
always_ff @(posedge clk) begin
    unique case(cached_bs)
    2'b00: sbox_input <= cached_rs2[7:0];
    2'b01: sbox_input <= cached_rs2[15:8];
    2'b10: sbox_input <= cached_rs2[23:16];
    2'b11: sbox_input <= cached_rs2[31:24];
    endcase
end

byte_t sbox_output; // valid at LINEAR_SHIFT stage
always_ff @(posedge clk) begin
    if (sm4_state_now == SBOX_LOOKUP) begin
        sbox_output <= sm4_sbox_table[sbox_input];
    end
end

word_t shift_result; // valid at ROL_XOR stage
always_ff @(posedge clk) begin
    if (sm4_state_now == LINEAR_SHIFT) begin
        if (cached_op) shift_result <= sm4_linear_shift_ks({ 24'b0, sbox_output });
        else shift_result <= sm4_linear_shift_ed({ 24'b0, sbox_output });
    end
end

word_t result; // valid at FINISH stage
always_ff @(posedge clk) begin
    if (sm4_state_now == ROL_XOR) begin
        result <= cached_rs1 ^ rol32_byte(shift_result, cached_bs);
    end
end

assign m_axis_result_tdata = result;

always_comb begin: sm4_fsm
    sm4_state_nxt = sm4_state_now;
    unique case(sm4_state_now)
    IDLE: begin
        if (s_axis_a_tvalid && s_axis_b_tvalid && s_axis_bs_tvalid && s_axis_operation_tvalid) begin
            sm4_state_nxt = CACHE_REQUEST;
        end
    end
    CACHE_REQUEST: begin
        sm4_state_nxt = SBOX_LOOKUP;
    end
    SBOX_LOOKUP: begin
        sm4_state_nxt = LINEAR_SHIFT;
    end
    LINEAR_SHIFT: begin
        sm4_state_nxt = ROL_XOR;
    end
    ROL_XOR: begin
        sm4_state_nxt = FINISH;
    end
    FINISH: begin
        sm4_state_nxt = IDLE;
    end
    endcase
end

always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
        sm4_state_now <= IDLE;
    end else begin
        sm4_state_now <= sm4_state_nxt;
    end
end

endmodule
