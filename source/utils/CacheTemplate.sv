// n-way m-set sync cache template, read/write delay = 1 cycle

module CacheTemplate #(
    parameter NAME = "cache",
    parameter NUM_WAYS = 1,
    parameter NUM_SETS = 16,
    parameter DATA_WIDTH = 32, // bits
    parameter LINE_WIDTH = 256 // bits
) (
    input rst, clk,

    input logic flush,
    // from&to CPU
    input cache_query_req_t query_req,
    output cache_query_resp_t query_resp,

    // from&to BUS
    input bus_query_req_t bus_req,
    output bus_query_resp_t bus_resp
);

localparam int CACHE_SIZE = LINE_WIDTH * NUM_SETS * NUM_WAYS; // bits
localparam int DATA_PER_LINE = LINE_WIDTH / DATA_WIDTH;
localparam int INDEX_WIDTH = $clog2(NUM_SETS);
localparam int DATA_BYTE_OFFSET = $clog2(DATA_WIDTH / 8); // 1 byte = 8 bit
localparam int LINE_INDEX_WIDTH = $clog2(LINE_WIDTH / DATA_WIDTH);
localparam int LINE_BYTE_OFFSET = LINE_INDEX_WIDTH + DATA_BYTE_OFFSET;
localparam int TAG_WIDTH = DATA_WIDTH - INDEX_WIDTH - LINE_BYTE_OFFSET;

typedef logic[DATA_PER_LINE-1:0][DATA_WIDTH-1:0] line_t;
typedef logic[INDEX_WIDTH-1:0] index_t;
typedef logic[LINE_INDEX_WIDTH-1:0] offset_t;
typedef logic[TAG_WIDTH-1:0] tag_t;

function index_t get_addr_index(input word_t addr);
    return addr[LINE_BYTE_OFFSET+INDEX_WIDTH-1:LINE_BYTE_OFFSET];
endfunction;

function tag_t get_addr_tag(input word_t addr);
    return addr[DATA_WIDTH-1:LINE_BYTE_OFFSET+INDEX_WIDTH];
endfunction;

function offset_t get_addr_offset(input word_t addr);
    return addr[LINE_BYTE_OFFSET-1:DATA_BYTE_OFFSET];
endfunction;

// meta cache
for (genvar i = 0; i < NUM_WAYS; ++i) begin: gen_meta_cache
    BRAM #(
        .LINE_WIDTH(LINE_WIDTH),
        .DATA_WIDTH(),
        .DEPTH()
    ) meta_cache (
        .clk(clk),
        .rst(rst),
        // write port
        .wen(),
        .waddr(),
        .wline(),
        // read port 
        .ren(),
        .raddr(),
        .rline()
    );
end

// data cache
for (genvar i = 0; i < NUM_WAYS; ++i) begin: gen_data_cache
    BRAM #(
        .LINE_WIDTH(LINE_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(NUM_SETS)
    ) data_cache (
        .clk(clk),
        .rst(rst),
        // write port
        .wen(),
        .waddr(),
        .wline(),
        // read port 
        .ren(),
        .raddr(),
        .rline()
    );
end




endmodule
