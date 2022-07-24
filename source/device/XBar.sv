import bitutils::*;
import bundle::*;

module XBar (
    input clk, rst,

    input bus_query_req_t cpu_ibus_req,
    output bus_query_resp_t cpu_ibus_resp,

    input bus_query_req_t cpu_dbus_req,
    output bus_query_resp_t cpu_dbus_resp,

    // CPLD Control
    output logic uart_rdn,
    output logic uart_wrn,
    input  logic uart_dataready,
    input  logic uart_tbre,
    input  logic uart_tsre,

    // BaseRAM
    inout logic[31:0] base_ram_data,
    output logic[19:0] base_ram_addr,
    output logic[3:0] base_ram_be_n,
    output logic base_ram_ce_n,
    output logic base_ram_oe_n,
    output logic base_ram_we_n,

    // ExtRAM
    inout logic[31:0] ext_ram_data,
    output logic[19:0] ext_ram_addr,
    output logic[3:0] ext_ram_be_n,
    output logic ext_ram_ce_n,
    output logic ext_ram_oe_n,
    output logic ext_ram_we_n,

    // Flash
    output logic[22:0] flash_a,
    inout  logic[15:0] flash_d,
    output logic flash_rp_n,
    output logic flash_vpen,
    output logic flash_ce_n,
    output logic flash_oe_n,
    output logic flash_we_n,
    output logic flash_byte_n,

    // VGA
    output wire[2:0] vga_red,
    output wire[2:0] vga_green,
    output wire[1:0] vga_blue,
    output logic vga_hsync,
    output logic vga_vsync,
    output logic vga_clk,
    output logic vga_de
);

// 3-state gate to connect `inout` bus
// bus write priority: UART > BASERAM
word_t baseram_data_in, baseram_data_out;
word_t extram_data_in, extram_data_out;
logic baseram_we, extram_we;
assign base_ram_data = baseram_we ? baseram_data_out : 32'bz;
assign baseram_data_in = base_ram_data;
assign ext_ram_data = extram_we ? extram_data_out : 32'bz;
assign extram_data_in = ext_ram_data;

localparam int READ_UART_HOLD_CYCLES = 3;
localparam int WRITE_UART_HOLD_CYCLES = 5;
localparam int READ_SRAM_HOLD_CYCLES = 2;
localparam int WRITE_SRAM_HOLD_CYCLES = 3;

// possible conficts:
// 1. IF and MEM bus send requests at the same time;
// 2. when handling IF requests, MEM bus send a new request;
// !NOTE: when handling MEM requests, IF won't raise a new request because of signal `stall` inside Core.

// MMIOs: UART, Flash, VGA, mtimecmp, mtime
typedef enum {
    WAIT_FOR_REQUEST,
    WAITING_FOR_IO_IDLE,
    // read uart data
    READING_UART_DATA,
    CACHE_UART_DATA,
    // write uart data
    WRITING_UART_DATA,
    // read uart state reg
    READING_UART_STATE,
    // read baseram
    READING_BASERAM_DATA,
    CACHE_BASERAM_DATA,
    // write baseram
    WRITING_BASERAM_DATA,
    // read extram
    READING_EXTRAM_DATA,
    CACHE_EXTRAM_DATA,
    // write extram
    WRITING_EXTRAM_DATA,
    // read mtime
    READING_MTIME_LOW,
    READING_MTIME_HIGH,
    // read mtimecmp
    READING_MTIMECMP_LOW,
    READING_MTIMECMP_HIGH,
    // write mtimecmp
    WRITING_MTIMECMP_LOW,
    WRITING_MTIMECMP_HIGH,
    // give `valid` signal
    FINISH_WRITING,
    FINISH_READING
} xbar_state_t;

typedef struct packed {
    logic 
    uart_data,
    uart_state,
    baseram,
    extram,
    mtimelow,
    mtimehigh,
    mtimecmplow,
    mtimecmphigh;
} mmio_flag_t;

function mmio_flag_t addr_arbitrary (input paddr_t paddr);
    mmio_flag_t mmio_flag;
    mmio_flag = {
        // MMIO: [left, right)
        // UART
        ((32'h1000_0000 <= paddr[31:0]) && (paddr[31:0] < 32'h1000_0004)), // uart_data
        ((32'h1000_0004 <= paddr[31:0]) && (paddr[31:0] < 32'h1000_0008)), // uart_state
        // RAM
        ((32'h8000_0000 <= paddr[31:0]) && (paddr[31:0] < 32'h8040_0000)), // baseram
        ((32'h8040_0000 <= paddr[31:0]) && (paddr[31:0] < 32'h8080_0000)), // extram
        // ! MTIME, read-only
        ((32'h0200_bff8 <= paddr[31:0]) && (paddr[31:0] < 32'h0200_bffc)), // mtimelow
        ((32'h0200_bffc <= paddr[31:0]) && (paddr[31:0] < 32'h0200_c000)), // mtimehigh
        // MTIMECMP
        ((32'h0200_4000 <= paddr[31:0]) && (paddr[31:0] < 32'h0200_4004)), // mtimecmplow
        ((32'h0200_4004 <= paddr[31:0]) && (paddr[31:0] < 32'h0200_4008))  // mtimecmphigh
    };
    return mmio_flag;
endfunction;

// mmio busy flag
// TODO: assign these 2 busy signals
logic baseram_or_uart_busy, extram_busy;

// I-XBar is read only
xbar_state_t ixbar_state_now, ixbar_state_nxt;
mmio_flag_t ixbar_mmio_flag;
paddr_t ixbar_addr;
logic [3:0] ixbar_burst_length, ixbar_burst_now, ixbar_burst_nxt;

// D-XBar can read & write
xbar_state_t dxbar_state_now, dxbar_state_nxt;
mmio_flag_t dxbar_mmio_flag;
paddr_t dxbar_addr;
logic dxbar_is_store;
logic [3:0] dxbar_burst_length;
logic [3:0] dxbar_wstrb;

// MMIO signals for ibus & dbus
logic ixbar_uart_load, dxbar_uart_load, dxbar_uart_store;
logic ixbar_baseram_load, dxbar_baseram_load, dxbar_baseram_store;
logic ixbar_extram_load, dxbar_extram_load, dxbar_extram_store;

// send request to MMIO
assign uart_rdn = ~(ixbar_uart_load | dxbar_uart_load);
assign uart_wrn = ~dxbar_uart_store;
assign base_ram_addr = (dxbar_baseram_load | dxbar_baseram_store) ? dxbar_addr[21:2] : ixbar_addr[21:2];
assign base_ram_be_n = (dxbar_baseram_load | dxbar_baseram_store) ? dxbar_wstrb : 4'b0000;
assign base_ram_ce_n = ~(dxbar_baseram_load | dxbar_baseram_store | ixbar_baseram_load);
assign base_ram_oe_n = ~(dxbar_baseram_load | ixbar_baseram_load);
assign base_ram_we_n = 1'b1;
assign baseram_we = '0;
assign baseram_data_out = '0;
assign ext_ram_addr = (dxbar_extram_load | dxbar_extram_store) ? dxbar_addr[21:2] : ixbar_addr[21:2];
assign ext_ram_be_n = (dxbar_extram_load | dxbar_extram_store) ? dxbar_wstrb : 4'b0000;
assign ext_ram_ce_n = ~(dxbar_extram_load | dxbar_extram_store | ixbar_extram_load);
assign ext_ram_oe_n = ~(dxbar_extram_load | ixbar_extram_load);
assign ext_ram_we_n = 1'b1;
assign extram_we = '0;
assign extram_data_out = '0;


// IBUS FSM logic
// ibus cache cpu requests
always_ff @(posedge clk) begin: cache_ibus_request
    if (cpu_ibus_req.arvalid && ixbar_state_now == WAIT_FOR_REQUEST) begin
        ixbar_addr <= cpu_ibus_req.araddr;
        ixbar_burst_length <= cpu_ibus_req.rlen;
    end
end
assign ixbar_mmio_flag = addr_arbitrary(ixbar_addr);

// ibus FSM counter
word_t ixbar_hold_cycles_counter_now, ixbar_hold_cycles_counter_nxt;
always_ff @(posedge clk or posedge rst) begin: init_counter
    if (rst) begin
        ixbar_burst_now <= '0;
        ixbar_hold_cycles_counter_now <= '0;
    end else begin
        ixbar_burst_now <= ixbar_burst_nxt;
        ixbar_hold_cycles_counter_now <= ixbar_hold_cycles_counter_nxt;
    end
end

// temporily cache recieved data from system bus
logic ixbar_cache_baseram_flag, ixbar_cache_extram_flag;
word_t ixbar_rdata;
always_ff @(posedge clk) begin
    if (ixbar_cache_baseram_flag) ixbar_rdata <= baseram_data_in;
    else if (ixbar_cache_extram_flag) ixbar_rdata <= extram_data_in;
end

always_comb begin: ixbar_fsm
    ixbar_state_nxt = ixbar_state_now;
    ixbar_burst_nxt = ixbar_burst_now;
    ixbar_hold_cycles_counter_nxt = ixbar_hold_cycles_counter_now;
    
    cpu_ibus_resp = '0;

    ixbar_uart_load = '0;
    ixbar_baseram_load = '0;
    ixbar_extram_load = '0;

    ixbar_cache_baseram_flag = 1'b0;
    ixbar_cache_extram_flag = 1'b0;
    unique case (ixbar_state_now)
    WAIT_FOR_REQUEST: begin
        cpu_ibus_resp.rready = 1'b1;
        if (cpu_ibus_req.arvalid) ixbar_state_nxt = WAITING_FOR_IO_IDLE;
    end
    WAITING_FOR_IO_IDLE: begin
        ixbar_burst_nxt = '0;
        ixbar_hold_cycles_counter_nxt = '0;
        if (ixbar_mmio_flag.baseram) begin
            if (~baseram_or_uart_busy) ixbar_state_nxt = READING_BASERAM_DATA;
        end else if (ixbar_mmio_flag.extram) begin
            if (~extram_busy) ixbar_state_nxt = READING_EXTRAM_DATA;
        end else begin
            cpu_ibus_resp.rvalid = 1'b1;
            cpu_ibus_resp.rlast = 1'b1;
            $display("[ERROR][XBar-IBUS FSM] send request addr = 0x%x out of range.", ixbar_addr);
            ixbar_state_nxt = WAIT_FOR_REQUEST; // TODO: report unsupported inst fetch request
        end
    end
    // READING_UART_DATA: begin
    //     ixbar_uart_load = 1'b1;
    //     ixbar_hold_cycles_counter_nxt = ixbar_hold_cycles_counter_now + 1;
    //     if (ixbar_hold_cycles_counter_now == READ_UART_HOLD_CYCLES) begin 
    //         ixbar_cache_baseram_flag = 1'b1;
    //         ixbar_state_nxt = CACHE_UART_DATA;
    //     end
    // end
    // CACHE_UART_DATA: begin
    //     cpu_ibus_resp.rvalid = 1'b1;
    //     cpu_ibus_resp.rdata = { 24'b0, ixbar_rdata };
    //     if (ixbar_burst_now == ixbar_burst_length) begin
    //         ixbar_burst_nxt = '0;
    //         ixbar_state_nxt = WAIT_FOR_REQUEST;
    //         cpu_ibus_resp.rlast = 1'b1;
    //     end else begin
    //         ixbar_state_nxt = READING_UART_DATA;
    //         ixbar_burst_nxt = ixbar_burst_now + 1;
    //     end
    // end
    READING_BASERAM_DATA: begin
        ixbar_baseram_load = 1'b1;
        ixbar_hold_cycles_counter_nxt = ixbar_hold_cycles_counter_now + 1;
        if (ixbar_hold_cycles_counter_now == READ_SRAM_HOLD_CYCLES) begin
            ixbar_cache_baseram_flag = 1'b1;
            ixbar_state_nxt = CACHE_BASERAM_DATA;
        end
    end
    CACHE_BASERAM_DATA: begin
        cpu_ibus_resp.rvalid = 1'b1;
        cpu_ibus_resp.rdata = ixbar_rdata;
        if (ixbar_burst_now == ixbar_burst_length) begin
            ixbar_burst_nxt = '0;
            ixbar_state_nxt = WAIT_FOR_REQUEST;
            cpu_ibus_resp.rlast = 1'b1;
        end else begin
            ixbar_state_nxt = READING_BASERAM_DATA;
            ixbar_burst_nxt = ixbar_burst_now + 1;
        end
    end
    READING_EXTRAM_DATA: begin
        ixbar_extram_load = 1'b1;
        ixbar_hold_cycles_counter_nxt = ixbar_hold_cycles_counter_now + 1;
        if (ixbar_hold_cycles_counter_now == READ_SRAM_HOLD_CYCLES) begin
            ixbar_cache_extram_flag = 1'b1;
            ixbar_state_nxt = CACHE_EXTRAM_DATA;
        end
    end
    CACHE_EXTRAM_DATA: begin
        cpu_ibus_resp.rvalid = 1'b1;
        cpu_ibus_resp.rdata = ixbar_rdata;
        if (ixbar_burst_now == ixbar_burst_length) begin
            ixbar_burst_nxt = '0;
            ixbar_state_nxt = WAIT_FOR_REQUEST;
            cpu_ibus_resp.rlast = 1'b1;
        end else begin
            ixbar_state_nxt = READING_EXTRAM_DATA;
            ixbar_burst_nxt = ixbar_burst_now + 1;
        end
    end
    default: ixbar_state_nxt = WAIT_FOR_REQUEST;
    endcase
end

always_ff @(posedge clk) begin: ixbar_fsm_update
    if (rst) begin
        ixbar_state_now <= WAIT_FOR_REQUEST;
    end else begin
        ixbar_state_now <= ixbar_state_nxt;
    end
end


// flash
assign flash_a = 0;
assign flash_rp_n = 1'b1;
assign flash_vpen = 1'b1;
assign flash_ce_n = 1'b1;
assign flash_oe_n = 1'b1;
assign flash_we_n = 1'b1;
assign flash_byte_n = 1'b0;
// vga
assign vga_red = 0;
assign vga_green = 0;
assign vga_blue = 0;
assign vga_hsync = 0;
assign vga_vsync = 0;
assign vga_clk = 0;
assign vga_de = 0;

endmodule
