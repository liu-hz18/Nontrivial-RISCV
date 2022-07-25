// Sync FIFO
// !NOTE: when `empty` is valid, `head_data` is invalid.
module SyncFIFO #(
    parameter NAME="FIFO",
    parameter DEPTH=4, // must be power of 2
    parameter LINE_WIDTH=32
) (
    input clk, rst,

    input flush,
    // write port
    input logic push,
    input logic [LINE_WIDTH-1:0] push_data,

    input logic pop,
    // read port
    output logic [LINE_WIDTH-1:0] head_data,

    output logic full,
    output logic empty
);

localparam int FIFO_INDEX_WIDTH = $clog2(DEPTH);
typedef logic [LINE_WIDTH-1:0] fifo_line_t;
fifo_line_t arr[DEPTH-1:0]; // ring buffer

// 读写指针均添加一个extra bit用来指示是否超过 arr 顶
// 写指针 指向 将要写位置(队列尾的下一个)
// 读指针 指向 队列头
logic [FIFO_INDEX_WIDTH-1+1:0] rp, wp;

assign full = (rp[FIFO_INDEX_WIDTH] ^ wp[FIFO_INDEX_WIDTH]) && (rp[FIFO_INDEX_WIDTH-1:0] == wp[FIFO_INDEX_WIDTH-1:0]);
assign empty = (rp == wp);


// read port
assign head_data = arr[rp[FIFO_INDEX_WIDTH-1:0]];

// write port
always_ff @(posedge clk) begin
    if (push & ~full) begin
        arr[wp[FIFO_INDEX_WIDTH-1:0]] <= push_data;
    end
end

always_ff @(posedge clk or posedge rst) begin
    if (rst | flush) begin
        wp <= '0;
    end else if (push & ~full) begin
        wp <= wp + 1;
    end
end

always_ff @(posedge clk or posedge rst) begin
    if (rst | flush) begin
        rp <= '0;
    end else if (pop & ~empty) begin
        rp <= rp + 1;
    end
end

endmodule
