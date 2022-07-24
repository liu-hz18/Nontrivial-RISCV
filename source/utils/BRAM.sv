// simple wrapper of RAMs

// Simple dual port BRAM
// A端口只写，B端口只读，已经内置前�?
// 使用 SDP_RAM 默认其读延迟�?1
// LINE_WIDTH: width of a line which contains multi-data
// DATA_WIDTH: width of a data
// DEPTH: num of lines
module BRAM #(
    parameter NAME = "BRAM",
    parameter LINE_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter DEPTH = 128
) (
    input logic clk,
    input logic rst,

    // write port
    input logic wen, // high enable
    input logic [LINE_WIDTH/DATA_WIDTH-1:0] wmask, // high enable
    input logic [$clog2(DEPTH)-1:0] waddr,
    input logic [LINE_WIDTH-1:0] wline,

    // read port
    input logic ren, // high enable
    input logic [$clog2(DEPTH)-1:0] raddr,
    output logic [LINE_WIDTH-1:0] rline
);

logic wen_latch;
logic [LINE_WIDTH/DATA_WIDTH-1:0] wmask_latch;
logic [$clog2(DEPTH)-1:0] waddr_latch, raddr_latch;
logic [LINE_WIDTH-1:0] wline_latch;
logic [LINE_WIDTH-1:0] rline_unsafe;
always_ff @(posedge clk) begin
    wen_latch <= wen;
    wmask_latch <= wmask;
    waddr_latch <= waddr;
    wline_latch <= wline;
    raddr_latch <= raddr;
end

generate
genvar i;
for (i = LINE_WIDTH/DATA_WIDTH-1; i >= 0; --i) begin
    always_comb begin
        if (wen_latch && wmask_latch[i] && raddr_latch == waddr_latch) rline[(i+1)*DATA_WIDTH-1:i*DATA_WIDTH] = wline_latch[(i+1)*DATA_WIDTH-1:i*DATA_WIDTH];
        else rline[(i+1)*DATA_WIDTH-1:i*DATA_WIDTH] = rline_unsafe[(i+1)*DATA_WIDTH-1:i*DATA_WIDTH];
    end
end
endgenerate

// xpm_memory_sdpram: Simple Dual Port RAM
// Xilinx Parameterized Macro, version 2019.2
xpm_memory_sdpram #(
    // common module parameters
    .CLOCKING_MODE("common_clock"), // String
    .MEMORY_PRIMITIVE("block"),     // String
    .ECC_MODE("no_ecc"),            // String
    .MEMORY_INIT_FILE("none"),      // String
    .MEMORY_INIT_PARAM("0"),        // String
    .MEMORY_OPTIMIZATION("true"),   // String
    .AUTO_SLEEP_TIME(0),            // DECIMAL
    .CASCADE_HEIGHT(0),             // DECIMAL
    .MESSAGE_CONTROL(0),            // DECIMAL
    .MEMORY_SIZE(LINE_WIDTH * DEPTH),// DECIMAL
    .SIM_ASSERT_CHK(0),             // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
    .USE_EMBEDDED_CONSTRAINT(0),    // DECIMAL
    .USE_MEM_INIT(0),               // DECIMAL
    .WAKEUP_TIME("disable_sleep"),  // String
    // Port A (write) params
    .ADDR_WIDTH_A($clog2(DEPTH)),      // DECIMAL
    .BYTE_WRITE_WIDTH_A(DATA_WIDTH),  // DECIMAL
    .RST_MODE_A("SYNC"),              // String
    .WRITE_DATA_WIDTH_A(LINE_WIDTH),  // DECIMAL
    // Port B (read) params
    .ADDR_WIDTH_B($clog2(DEPTH)),      // DECIMAL
    .READ_DATA_WIDTH_B(LINE_WIDTH),   // DECIMAL
    .READ_LATENCY_B(1),               // DECIMAL
    .READ_RESET_VALUE_B("0"),         // String
    .RST_MODE_B("SYNC"),              // String
    .WRITE_MODE_B("read_first")       // String
) xpm_memory_sdpram_inst (
    .dbiterrb(),                    // 1-bit output: Status signal to indicate double bit error occurrence
                                    // on the data output of port B.

    .doutb(rline_unsafe),           // READ_DATA_WIDTH_B-bit output: Data output for port B read operations.
    .sbiterrb(),                    // 1-bit output: Status signal to indicate single bit error occurrence
                                    // on the data output of port B.

    .addra(waddr),                  // ADDR_WIDTH_A-bit input: Address for port A write operations.
    .addrb(raddr),                  // ADDR_WIDTH_B-bit input: Address for port B read operations.
    .clka(clk),                     // 1-bit input: Clock signal for port A. Also clocks port B when
                                    // parameter CLOCKING_MODE is "common_clock".

    .clkb(clk),                     // 1-bit input: Clock signal for port B when parameter CLOCKING_MODE is
                                    // "independent_clock". Unused when parameter CLOCKING_MODE is
                                    // "common_clock".

    .dina(wline),                   // WRITE_DATA_WIDTH_A-bit input: Data input for port A write operations.
    .ena(wen),                      // 1-bit input: Memory enable signal for port A. Must be high on clock
                                    // cycles when write operations are initiated. Pipelined internally.

    .enb(ren),                      // 1-bit input: Memory enable signal for port B. Must be high on clock
                                    // cycles when read operations are initiated. Pipelined internally.

    .injectdbiterra(1'b0),          // 1-bit input: Controls double bit error injection on input data when
                                    // ECC enabled (Error injection capability is not available in
                                    // "decode_only" mode).

    .injectsbiterra(1'b0),          // 1-bit input: Controls single bit error injection on input data when
                                    // ECC enabled (Error injection capability is not available in
                                    // "decode_only" mode).

    .regceb(1'b1),                  // 1-bit input: Clock Enable for the last register stage on the output
                                    // data path.

    .rstb(rst),                     // 1-bit input: Reset signal for the final port B output register stage.
                                    // Synchronously resets output port doutb to the value specified by
                                    // parameter READ_RESET_VALUE_B.

    .sleep(1'b0),                   // 1-bit input: sleep signal to enable the dynamic power saving feature.
    .wea(wmask)                     // WRITE_DATA_WIDTH_A/BYTE_WRITE_WIDTH_A-bit input: Write enable vector
                                    // for port A input data port dina. 1 bit wide when word-wide writes are
                                    // used. In byte-wide write configurations, each bit controls the
                                    // writing one byte of dina to address addra. For example, to
                                    // synchronously write only bits [15-8] of dina when WRITE_DATA_WIDTH_A
                                    // is 32, wea would be 4'b0010.
);

endmodule
