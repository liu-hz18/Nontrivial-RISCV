
import bitutils::*;

// 5-6 latency
module AES (
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
    input logic [1:0] s_axis_operation_tdata,
    // output channel
    output logic m_axis_result_tvalid,
    output word_t m_axis_result_tdata
);

byte_t [255:0] aes_sbox_inv_table = {
    8'h52, 8'h09, 8'h6a, 8'hd5, 8'h30, 8'h36, 8'ha5, 8'h38, 8'hbf, 8'h40, 8'ha3, 8'h9e, 8'h81,
    8'hf3, 8'hd7, 8'hfb, 8'h7c, 8'he3, 8'h39, 8'h82, 8'h9b, 8'h2f, 8'hff, 8'h87, 8'h34, 8'h8e,
    8'h43, 8'h44, 8'hc4, 8'hde, 8'he9, 8'hcb, 8'h54, 8'h7b, 8'h94, 8'h32, 8'ha6, 8'hc2, 8'h23,
    8'h3d, 8'hee, 8'h4c, 8'h95, 8'h0b, 8'h42, 8'hfa, 8'hc3, 8'h4e, 8'h08, 8'h2e, 8'ha1, 8'h66,
    8'h28, 8'hd9, 8'h24, 8'hb2, 8'h76, 8'h5b, 8'ha2, 8'h49, 8'h6d, 8'h8b, 8'hd1, 8'h25, 8'h72,
    8'hf8, 8'hf6, 8'h64, 8'h86, 8'h68, 8'h98, 8'h16, 8'hd4, 8'ha4, 8'h5c, 8'hcc, 8'h5d, 8'h65,
    8'hb6, 8'h92, 8'h6c, 8'h70, 8'h48, 8'h50, 8'hfd, 8'hed, 8'hb9, 8'hda, 8'h5e, 8'h15, 8'h46,
    8'h57, 8'ha7, 8'h8d, 8'h9d, 8'h84, 8'h90, 8'hd8, 8'hab, 8'h00, 8'h8c, 8'hbc, 8'hd3, 8'h0a,
    8'hf7, 8'he4, 8'h58, 8'h05, 8'hb8, 8'hb3, 8'h45, 8'h06, 8'hd0, 8'h2c, 8'h1e, 8'h8f, 8'hca,
    8'h3f, 8'h0f, 8'h02, 8'hc1, 8'haf, 8'hbd, 8'h03, 8'h01, 8'h13, 8'h8a, 8'h6b, 8'h3a, 8'h91,
    8'h11, 8'h41, 8'h4f, 8'h67, 8'hdc, 8'hea, 8'h97, 8'hf2, 8'hcf, 8'hce, 8'hf0, 8'hb4, 8'he6,
    8'h73, 8'h96, 8'hac, 8'h74, 8'h22, 8'he7, 8'had, 8'h35, 8'h85, 8'he2, 8'hf9, 8'h37, 8'he8,
    8'h1c, 8'h75, 8'hdf, 8'h6e, 8'h47, 8'hf1, 8'h1a, 8'h71, 8'h1d, 8'h29, 8'hc5, 8'h89, 8'h6f,
    8'hb7, 8'h62, 8'h0e, 8'haa, 8'h18, 8'hbe, 8'h1b, 8'hfc, 8'h56, 8'h3e, 8'h4b, 8'hc6, 8'hd2,
    8'h79, 8'h20, 8'h9a, 8'hdb, 8'hc0, 8'hfe, 8'h78, 8'hcd, 8'h5a, 8'hf4, 8'h1f, 8'hdd, 8'ha8,
    8'h33, 8'h88, 8'h07, 8'hc7, 8'h31, 8'hb1, 8'h12, 8'h10, 8'h59, 8'h27, 8'h80, 8'hec, 8'h5f,
    8'h60, 8'h51, 8'h7f, 8'ha9, 8'h19, 8'hb5, 8'h4a, 8'h0d, 8'h2d, 8'he5, 8'h7a, 8'h9f, 8'h93,
    8'hc9, 8'h9c, 8'hef, 8'ha0, 8'he0, 8'h3b, 8'h4d, 8'hae, 8'h2a, 8'hf5, 8'hb0, 8'hc8, 8'heb,
    8'hbb, 8'h3c, 8'h83, 8'h53, 8'h99, 8'h61, 8'h17, 8'h2b, 8'h04, 8'h7e, 8'hba, 8'h77, 8'hd6,
    8'h26, 8'he1, 8'h69, 8'h14, 8'h63, 8'h55, 8'h21, 8'h0c, 8'h7d
};

byte_t [255:0] aes_sbox_fwd_table = {
    8'h63, 8'h7c, 8'h77, 8'h7b, 8'hf2, 8'h6b, 8'h6f, 8'hc5, 8'h30, 8'h01, 8'h67, 8'h2b, 8'hfe,
    8'hd7, 8'hab, 8'h76, 8'hca, 8'h82, 8'hc9, 8'h7d, 8'hfa, 8'h59, 8'h47, 8'hf0, 8'had, 8'hd4,
    8'ha2, 8'haf, 8'h9c, 8'ha4, 8'h72, 8'hc0, 8'hb7, 8'hfd, 8'h93, 8'h26, 8'h36, 8'h3f, 8'hf7,
    8'hcc, 8'h34, 8'ha5, 8'he5, 8'hf1, 8'h71, 8'hd8, 8'h31, 8'h15, 8'h04, 8'hc7, 8'h23, 8'hc3,
    8'h18, 8'h96, 8'h05, 8'h9a, 8'h07, 8'h12, 8'h80, 8'he2, 8'heb, 8'h27, 8'hb2, 8'h75, 8'h09,
    8'h83, 8'h2c, 8'h1a, 8'h1b, 8'h6e, 8'h5a, 8'ha0, 8'h52, 8'h3b, 8'hd6, 8'hb3, 8'h29, 8'he3,
    8'h2f, 8'h84, 8'h53, 8'hd1, 8'h00, 8'hed, 8'h20, 8'hfc, 8'hb1, 8'h5b, 8'h6a, 8'hcb, 8'hbe,
    8'h39, 8'h4a, 8'h4c, 8'h58, 8'hcf, 8'hd0, 8'hef, 8'haa, 8'hfb, 8'h43, 8'h4d, 8'h33, 8'h85,
    8'h45, 8'hf9, 8'h02, 8'h7f, 8'h50, 8'h3c, 8'h9f, 8'ha8, 8'h51, 8'ha3, 8'h40, 8'h8f, 8'h92,
    8'h9d, 8'h38, 8'hf5, 8'hbc, 8'hb6, 8'hda, 8'h21, 8'h10, 8'hff, 8'hf3, 8'hd2, 8'hcd, 8'h0c,
    8'h13, 8'hec, 8'h5f, 8'h97, 8'h44, 8'h17, 8'hc4, 8'ha7, 8'h7e, 8'h3d, 8'h64, 8'h5d, 8'h19,
    8'h73, 8'h60, 8'h81, 8'h4f, 8'hdc, 8'h22, 8'h2a, 8'h90, 8'h88, 8'h46, 8'hee, 8'hb8, 8'h14,
    8'hde, 8'h5e, 8'h0b, 8'hdb, 8'he0, 8'h32, 8'h3a, 8'h0a, 8'h49, 8'h06, 8'h24, 8'h5c, 8'hc2,
    8'hd3, 8'hac, 8'h62, 8'h91, 8'h95, 8'he4, 8'h79, 8'he7, 8'hc8, 8'h37, 8'h6d, 8'h8d, 8'hd5,
    8'h4e, 8'ha9, 8'h6c, 8'h56, 8'hf4, 8'hea, 8'h65, 8'h7a, 8'hae, 8'h08, 8'hba, 8'h78, 8'h25,
    8'h2e, 8'h1c, 8'ha6, 8'hb4, 8'hc6, 8'he8, 8'hdd, 8'h74, 8'h1f, 8'h4b, 8'hbd, 8'h8b, 8'h8a,
    8'h70, 8'h3e, 8'hb5, 8'h66, 8'h48, 8'h03, 8'hf6, 8'h0e, 8'h61, 8'h35, 8'h57, 8'hb9, 8'h86,
    8'hc1, 8'h1d, 8'h9e, 8'he1, 8'hf8, 8'h98, 8'h11, 8'h69, 8'hd9, 8'h8e, 8'h94, 8'h9b, 8'h1e,
    8'h87, 8'he9, 8'hce, 8'h55, 8'h28, 8'hdf, 8'h8c, 8'ha1, 8'h89, 8'h0d, 8'hbf, 8'he6, 8'h42,
    8'h68, 8'h41, 8'h99, 8'h2d, 8'h0f, 8'hb0, 8'h54, 8'hbb, 8'h16
};

function byte_t xt2(input byte_t x);
    return (x << 1) ^ (x[7] ? 8'h1b : 8'h00);
endfunction;

function byte_t gfmul(input byte_t x, input logic[3:0] y);
    byte_t r0, r1, r2, r3;
    r0 = y[0] ? x : 8'h0;
    r1 = y[1] ? xt2(x) : 8'h0;
    r2 = y[2] ? xt2(xt2(x)) : 8'h0;
    r3 = y[3] ? xt2(xt2(xt2(x))) : 8'h0;
endfunction;

function word_t aes_mixcol_byte_fwd(input byte_t so);
    return { gfmul(so, 4'h3), so, so, gfmul(so, 4'h2) };
endfunction;

function word_t aes_mixcol_byte_inv(input byte_t so);
    return { gfmul(so, 4'hb), gfmul(so, 4'hd), gfmul(so, 4'h9), gfmul(so, 4'he) };
endfunction;

// function word_t aes_decode_rcon(input logic[3:0] r);
//     word_t result;
//     unique case(r)
//     4'h0: 32'h0000_0001;
//     4'h1: 32'h0000_0002;
//     4'h2: 32'h0000_0004;
//     4'h3: 32'h0000_0008;
//     4'h4: 32'h0000_0010;
//     4'h5: 32'h0000_0020;
//     4'h6: 32'h0000_0040;
//     4'h7: 32'h0000_0080;
//     4'h8: 32'h0000_001b;
//     4'h9: 32'h0000_0036;
//     default: 32'h0;
//     endcase
//     return result;
// endfunction;

// function byte_t xt3(input byte_t x);
//     return x ^ xt2(x);
// endfunction;

// function word_t aes_mixcol_fwd(input word_t x);
//     byte_t b0, b1, b2, b3;
//     b0 = xt2(x[7:0]) ^ xt3(x[15:8]) ^ x[23:16] ^ x[31:24];
//     b1 = x[7:0] ^ xt2(x[15:8]) ^ xt3(x[23:16]) ^ x[31:24];
//     b2 = x[7:0] ^ x[15:8] ^ xt2(x[23:16]) ^ xt3(x[31:24]);
//     b3 = xt3(x[7:0]) ^ x[15:8] ^ x[23:16] ^ xt2(x[31:24]);
//     return { b3, b2, b1, b0 };
// endfunction;

// function word_t aes_mixcol_inv(input word_t x);
//     byte_t b0, b1, b2, b3;
//     b0 = gfmul(x[7:0], 4'he) ^ gfmul(x[15:8], 4'hb) ^ gfmul(x[23:16], 4'hd) ^ gfmul(x[31:24], 4'h9);
//     b1 = gfmul(x[7:0], 4'h9) ^ gfmul(x[15:8], 4'he) ^ gfmul(x[23:16], 4'hb) ^ gfmul(x[31:24], 4'hd);
//     b2 = gfmul(x[7:0], 4'hd) ^ gfmul(x[15:8], 4'h9) ^ gfmul(x[23:16], 4'he) ^ gfmul(x[31:24], 4'hb);
//     b3 = gfmul(x[7:0], 4'hb) ^ gfmul(x[15:8], 4'hd) ^ gfmul(x[23:16], 4'h9) ^ gfmul(x[31:24], 4'he);
//     return { b3, b2, b1, b0 };
// endfunction;

typedef enum {
    IDLE,
    CACHE_REQUEST,
    SBOX_LOOKUP,
    MIX_COLUMN,
    ROL32,
    FINISH
} aes_fsm_t;

aes_fsm_t aes_state_now, aes_state_nxt;

assign s_axis_a_tready = (aes_state_now == IDLE);
assign s_axis_b_tready = (aes_state_now == IDLE);
assign s_axis_bs_tready = (aes_state_now == IDLE);
assign s_axis_operation_tready = (aes_state_now == IDLE);

assign m_axis_result_tvalid = (aes_state_now == FINISH);

word_t cached_rs1, cached_rs2;
logic [1:0] cached_bs;
logic [1:0] cached_op; // valid at CACHE_REQUEST stage
always_ff @(posedge clk) begin
    if (aes_state_now == IDLE) cached_rs1 <= s_axis_a_tdata;
    if (aes_state_now == IDLE) cached_rs2 <= s_axis_b_tdata;
    if (aes_state_now == IDLE) cached_bs <= s_axis_bs_tdata;
    if (aes_state_now == IDLE) cached_op <= s_axis_operation_tdata;
end

// cached_op: OP_AES32_DSI(00), OP_AES32_DSMI(01), OP_AES32_ESI(10), OP_AES32_ESMI(11)

byte_t sbox_input; // valid at SBOX_LOOKUP stage
always_ff @(posedge clk) begin
    unique case(cached_bs)
    2'b00: sbox_input <= cached_rs2[7:0];
    2'b01: sbox_input <= cached_rs2[15:8];
    2'b10: sbox_input <= cached_rs2[23:16];
    2'b11: sbox_input <= cached_rs2[31:24];
    endcase
end

byte_t sbox_output; // valid at MIX_COLUMN or ROL32 stage
always_ff @(posedge clk) begin
    if (aes_state_now == SBOX_LOOKUP) begin
        if (cached_op[1]) sbox_output <= aes_sbox_fwd_table[sbox_input];
        else sbox_output <= aes_sbox_inv_table[sbox_input];
    end
end

word_t mixed; // valid at ROL32 stage
always_ff @(posedge clk) begin
    if (aes_state_now == MIX_COLUMN) begin
        if (cached_op[1]) mixed <= aes_mixcol_byte_fwd(sbox_output);
        else mixed <= aes_mixcol_byte_inv(sbox_output);
    end
end

word_t result; // valid at FINISH stage
always_ff @(posedge clk) begin
    if (aes_state_now == ROL32) begin
        if (cached_op[0]) result <= cached_rs1 ^ rol32_byte(mixed, cached_bs);
        else result <= cached_rs1 ^ rol32_byte({ 24'h00_0000, sbox_output }, cached_bs);
    end
end

assign m_axis_result_tdata = result;

always_comb begin: aes_fsm
    aes_state_nxt = aes_state_now;
    unique case(aes_state_now)
    IDLE: begin
        if (s_axis_a_tvalid && s_axis_b_tvalid && s_axis_bs_tvalid && s_axis_operation_tvalid) begin
            aes_state_nxt = CACHE_REQUEST;
        end
    end
    CACHE_REQUEST: begin
        aes_state_nxt = SBOX_LOOKUP;
    end
    SBOX_LOOKUP: begin
        if (cached_op[0]) aes_state_nxt = MIX_COLUMN;
        else aes_state_nxt = ROL32;
    end
    MIX_COLUMN: begin
        aes_state_nxt = ROL32;
    end
    ROL32: begin
        aes_state_nxt = FINISH;
    end
    FINISH: begin
        aes_state_nxt = IDLE;
    end
    endcase
end

always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
        aes_state_now <= IDLE;
    end else begin
        aes_state_now <= aes_state_nxt;
    end
end

endmodule
