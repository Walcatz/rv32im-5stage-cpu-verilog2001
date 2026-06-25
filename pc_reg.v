// module pc_reg
// (
//   input  wire        CLK,         // 全局主时钟
//   input  wire        RESET,       // 全局复位
//   input  wire        StallF,      // 来自 Hazard Unit 的暂停信号（1: 冻结 PC, 0: 正常滚动）
//   input  wire [31:0] PCNextIF,    // 下一个周期的目标PC地址（来自前级 MUX）
//   output reg  [31:0] PCF          // 当前取指级的物理PC地址（连向 ROM 的 A 端口）
// );

//   always @(posedge CLK or posedge RESET) begin
//     if (RESET) begin
//       // RISC-V 默认复位地址通常为 32'h0000_0000 或者 32'h8000_0000（根据你的Testbench来定）
//       PCF <= 32'h0000_0000; 
//     end 
//     // 严格对照架构图：StallF 为 1 时，EN失效，PC保持原值不变
//     else if (!StallF) begin
//       PCF <= PCNextIF; // 正常更新地址
//     end
//     // else (StallF == 1) 隐式保持 PCF <= PCF;
//   end

// endmodule

// 在 riscv_core.v 顶层
// wire [31:0] PCPlus4F = PCF + 32'd4; // 纯组合逻辑，零延迟

module pc_reg
(
  input  wire        CLK,
  input  wire        RESET,// 全局复位信号，高有效1
  input  wire        StallF,// 模块主使能信号
  input  wire [31:0] PCNextF,
  output reg  [31:0] PCF,
  output wire [31:0] PCPlus4F  // 新增一个输出端口
);

  // 1. 时序逻辑：更新当前 PC
  always @(posedge CLK or posedge RESET) begin
    if (RESET)      PCF <= 32'h0000_0000; //首条指令地址
    else if (!StallF) PCF <= PCNextF;
  end

  // 2. 组合逻辑：并进来的加法器
  assign PCPlus4F = PCF + 32'd4;

endmodule