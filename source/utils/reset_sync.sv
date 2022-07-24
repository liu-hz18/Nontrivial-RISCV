
module reset_sync (
    input clk, rst,

    output sys_clk, sys_rst
);

// 异步复位同步释放 rst
reg rst_r1, rst_r2; // high active
always_ff @(posedge clk or posedge rst) begin
    if (rst) rst_r1 <= 1'b1;
    else rst_r1 <= 1'b0;
end

always_ff @(posedge clk or posedge rst) begin
    if (rst) rst_r2 <= 1'b1;
    else rst_r2 <= rst_r1;
end

// ! `locked` 信号可以作为后级电路reset信号，视为低有效
clk_wiz_0 clock_gen (
  // Clock in ports
  .clk_in1(clk),  // 外部时钟输入
  // Clock out ports
  .clk_out1(sys_clk), // 时钟输出1，频率在IP配置界面中设置
//   .clk_out2(), // 时钟输出2，频率在IP配置界面中设置
  // Status and control signals
  .reset(rst_r2), // PLL复位输入
  .locked(locked)    // PLL锁定指示输出，"1"表示时钟稳定，
                     // 后级电路复位信号应当由它生成（见下）
);

wire sys_rst_r0;
assign sys_rst_r0 = (~locked) | rst;
reg sys_rst_r1, sys_rst_r2;

always_ff @(posedge clk or posedge sys_rst_r0) begin
    if (sys_rst_r0) sys_rst_r1 <= 1'b1;
    else sys_rst_r1 <= 1'b0;
end

always_ff @(posedge clk or posedge sys_rst_r0) begin
    if (sys_rst_r0) sys_rst_r2 <= 1'b1;
    else sys_rst_r2 <= sys_rst_r1;
end

assign sys_rst = sys_rst_r2;

endmodule
