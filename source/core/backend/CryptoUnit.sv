import bitutils::*;

module CryptoUnit (
    input clk, rst,

    input logic flush,
    input op_t op,

    input word_t rs1,
    input word_t rs2,
    input logic[1:0] bs,

    output word_t aes_result,
    output word_t sm4_result,
    output logic busy
);

op_t cached_op;
word_t cached_rs1, cached_rs2;
logic [1:0] cached_bs;

logic aes_req_valid;
logic aes_all_ready;
logic aes_axis_a_tready, aes_axis_b_tready, aes_axis_bs_tready, aes_axis_operation_tready;
logic [1:0] aes_operation;
logic aes_axis_result_tvalid;
assign aes_all_ready = aes_axis_a_tready&aes_axis_b_tready&aes_axis_bs_tready&aes_axis_operation_tready;

logic sm4_req_valid;
logic sm4_all_ready;
logic sm4_axis_a_tready, sm4_axis_b_tready, sm4_axis_bs_tready, sm4_axis_operation_tready;
logic sm4_operation;
logic sm4_axis_result_tvalid;
assign sm4_all_ready = sm4_axis_a_tready&sm4_axis_b_tready&sm4_axis_bs_tready&sm4_axis_operation_tready;

AES AES (
    .clk(clk),
    .rst(rst),
    // input rs1 channel
    .s_axis_a_tvalid(aes_req_valid),
    .s_axis_a_tready(aes_axis_a_tready),
    .s_axis_a_tdata(cached_rs1),
    // input rs2 channel
    .s_axis_b_tvalid(aes_req_valid),
    .s_axis_b_tready(aes_axis_b_tready),
    .s_axis_b_tdata(cached_rs2),
    // input bs channel
    .s_axis_bs_tvalid(aes_req_valid),
    .s_axis_bs_tready(aes_axis_bs_tready),
    .s_axis_bs_tdata(cached_bs),
    // input op channel
    .s_axis_operation_tvalid(aes_req_valid),
    .s_axis_operation_tready(aes_axis_operation_tready),
    .s_axis_operation_tdata(aes_operation),
    // output channel
    .m_axis_result_tvalid(aes_axis_result_tvalid),
    .m_axis_result_tdata(aes_result)
);

SM4 SM4 (
    .clk(clk),
    .rst(rst),
    // input rs1 channel
    .s_axis_a_tvalid(sm4_req_valid),
    .s_axis_a_tready(sm4_axis_a_tready),
    .s_axis_a_tdata(cached_rs1),
    // input rs2 channel
    .s_axis_b_tvalid(sm4_req_valid),
    .s_axis_b_tready(sm4_axis_b_tready),
    .s_axis_b_tdata(cached_rs2),
    // input bs channel
    .s_axis_bs_tvalid(sm4_req_valid),
    .s_axis_bs_tready(sm4_axis_bs_tready),
    .s_axis_bs_tdata(cached_bs),
    // input op channel
    .s_axis_operation_tvalid(sm4_req_valid),
    .s_axis_operation_tready(sm4_axis_operation_tready),
    .s_axis_operation_tdata(sm4_operation),
    // output channel
    .m_axis_result_tvalid(sm4_axis_result_tvalid),
    .m_axis_result_tdata(sm4_result)
);

typedef enum { 
    IDLE,
    WAITING_READY,
    WAITING_VALID
} crypto_fsm_t;
crypto_fsm_t crypto_state_now, crypto_state_nxt;

always_ff @(posedge clk) begin
    if (crypto_state_now == IDLE) begin
        cached_op <= op;
        cached_rs1 <= rs1;
        cached_rs2 <= rs2;
        cached_bs <= bs;
    end
end

// TODO: refine this judgement to IDU stage
logic is_aes_sm4;
assign is_aes_sm4 = (op == OP_AES32_DSI) || (op == OP_AES32_DSMI) || (op == OP_AES32_ESI) || (op == OP_AES32_ESMI) || (op == OP_SM4_ED) || (op == OP_SM4_KS);

always_comb begin
    crypto_state_nxt = crypto_state_now;
    aes_operation = '0;
    sm4_operation = '0;
    aes_req_valid = '0;
    sm4_req_valid = '0;
    unique case(crypto_state_now)
    IDLE: begin
        if (flush) crypto_state_nxt = IDLE;
        else if (is_aes_sm4) crypto_state_nxt = WAITING_READY;
    end
    WAITING_READY: begin
        if (flush) crypto_state_nxt = IDLE;
        else begin
            unique case(cached_op)
            OP_AES32_DSI: begin
                aes_req_valid = 1'b1;
                aes_operation = 2'b00;
                if (aes_all_ready) crypto_state_nxt = WAITING_VALID;
            end
            OP_AES32_DSMI: begin
                aes_req_valid = 1'b1;
                aes_operation = 2'b01;
                if (aes_all_ready) crypto_state_nxt = WAITING_VALID;
            end
            OP_AES32_ESI: begin
                aes_req_valid = 1'b1;
                aes_operation = 2'b10;
                if (aes_all_ready) crypto_state_nxt = WAITING_VALID;
            end
            OP_AES32_ESMI: begin
                aes_req_valid = 1'b1;
                aes_operation = 2'b11;
                if (aes_all_ready) crypto_state_nxt = WAITING_VALID;
            end
            OP_SM4_ED: begin
                sm4_req_valid = 1'b1;
                sm4_operation = 1'b0;
                if (sm4_all_ready) crypto_state_nxt = WAITING_VALID;
            end
            OP_SM4_KS: begin
                sm4_req_valid = 1'b1;
                sm4_operation = 1'b1;
                if (sm4_all_ready) crypto_state_nxt = WAITING_VALID;
            end
            default: crypto_state_nxt = IDLE;
            endcase
        end
    end
    WAITING_VALID: begin
        if (flush) crypto_state_nxt = IDLE;
        else if (sm4_axis_result_tvalid | aes_axis_result_tvalid) crypto_state_nxt = IDLE;
    end
    endcase
end

assign busy = (crypto_state_nxt != IDLE);

always_ff @(posedge clk or posedge rst) begin
    if (rst) crypto_state_now <= IDLE;
    else crypto_state_now <= crypto_state_nxt;
end

endmodule
