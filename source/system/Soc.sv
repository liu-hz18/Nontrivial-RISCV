// Soc
import bitutils::*;
import bundle::*;


module Soc (
    input clk, rst,

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

bus_query_req_t ibus_req, dbus_req;
bus_query_resp_t ibus_resp, dbus_resp;

logic timer_interrupt, external_interrupt, software_interrupt;
assign { timer_interrupt, external_interrupt, software_interrupt } = 3'b111;

// CPU Core
CpuCore #(
    .BPU_NUM_BTB_ENTRIES(512),
    .BPU_NUM_RAS(16),
    .ICACHE_NUM_WAYS(2),
    .ICACHE_NUM_SETS(256),
    .ICACHE_DATA_WIDTH(32),
    .ICACHE_LINE_WIDTH(256),
    .ITLB_NUM_WAYS(2),
    .ITLB_NUM_SETS(64),
    .NUM_FIFO_DEPTH(4)
) CpuCore (
    .clk(clk),
    .rst(rst),

    .timer_interrupt(timer_interrupt),
    .external_interrupt(external_interrupt),
    .software_interrupt(software_interrupt),
    
    .ibus_req(ibus_req),
    .ibus_resp(ibus_resp),
    
    .dbus_req(dbus_req),
    .dbus_resp(dbus_resp)
);

XBar XBar (
    .clk(clk),
    .rst(rst),
    
    .cpu_ibus_req(ibus_req),
    .cpu_ibus_resp(ibus_resp),
    .cpu_dbus_req(dbus_req),
    .cpu_dbus_resp(dbus_resp),

    .uart_rdn(uart_rdn),
    .uart_wrn(uart_wrn),
    .uart_dataready(uart_dataready),
    .uart_tbre(uart_tbre),
    .uart_tsre(uart_tsre),

    .base_ram_data(base_ram_data),
    .base_ram_addr(base_ram_addr),
    .base_ram_be_n(base_ram_be_n),
    .base_ram_ce_n(base_ram_ce_n),
    .base_ram_oe_n(base_ram_oe_n),
    .base_ram_we_n(base_ram_we_n),

    .ext_ram_data(ext_ram_data),
    .ext_ram_addr(ext_ram_addr),
    .ext_ram_be_n(ext_ram_be_n),
    .ext_ram_ce_n(ext_ram_ce_n),
    .ext_ram_oe_n(ext_ram_oe_n),
    .ext_ram_we_n(ext_ram_we_n),

    .flash_a(flash_a),
    .flash_d(flash_d),
    .flash_rp_n(flash_rp_n),
    .flash_vpen(flash_vpen),
    .flash_ce_n(flash_ce_n),
    .flash_oe_n(flash_oe_n),
    .flash_we_n(flash_we_n),
    .flash_byte_n(flash_byte_n),

    .vga_red(vga_red),
    .vga_green(vga_green),
    .vga_blue(vga_blue),
    .vga_hsync(vga_hsync),
    .vga_vsync(vga_vsync),
    .vga_clk(vga_clk),
    .vga_de(vga_de)
);

endmodule

