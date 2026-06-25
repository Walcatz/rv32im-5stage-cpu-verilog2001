module if_id_reg
(
  // =========================================================================
  // 1. 控制总线
  // =========================================================================
  input  wire        CLK,          // 全局主时钟
  input  wire        StallD,       // 译码级暂停信号 (1: 冻结, 0: 滚动)
  input  wire        FlushD,       // 译码级清空信号 (1: 冲刷为 NOP)
  
  // =========================================================================
  // 2. 取指级 (IF) 输入源
  // =========================================================================
  input  wire [31:0] RD,           // 来自 Instruction Memory 的原始指令码 (InstrF)
  input  wire [31:0] PCF,          // 当前取指级的 PC 值
  input  wire [31:0] PCPlus4F,     // 当前取指级的 PC+4 值

  // =========================================================================
  // 3. 译码级 (ID) 拆分输出端 (严谨规范命名)
  // =========================================================================
  output wire [6:0]  Instr_6_0,    // 对应 op[6:0] -> 连到 ctrl_unit
  output wire [2:0]  Instr_14_12,  // 对应 funct3[14:12] -> 连到 ctrl_unit
  output wire        Instr_30,     // 对应 funct7_5 -> 连到 ctrl_unit (ADD/SUB)
  output wire        Instr_25,     // 对应 funct7_0 -> 连到 ctrl_unit (M扩展)
  
  output wire [4:0]  Rs1D,         // [Rs1D] 源寄存器1地址 -> 连到 reg_file A1 (以及 Hazard Unit) Instr19:15
  output wire [4:0]  Rs2D,         // [Rs2D] 源寄存器2地址 -> 连到 reg_file A2 (以及 Hazard Unit) Instr24:20
  output wire [4:0]  RdD,          // [RdD] 目的寄存器地址 -> 顺延传递给下一级 id_ex_reg Instr11:7
  output wire [24:0] Instr_31_7,   // 对应喂给 extend 模块的立即数相对总线 i_imm
  
  output reg  [31:0] PCD,          // 顺延传递的当前级 PC 值
  output reg  [31:0] PCPlus4D      // 顺延传递的当前级 PC+4 值
);

  // 内部核心锁存寄存器
  reg [31:0] instr_reg;

  // =========================================================================
  // 1. 时序逻辑：段间数据锁存与冲刷
  // =========================================================================
  always @(posedge CLK) begin
    if (FlushD) begin
      instr_reg <= 32'h00000013; // 冲刷转换为规范的 NOP (addi x0, x0, 0)
      PCD       <= 32'b0;
      PCPlus4D  <= 32'b0;
    end 
    else if (!StallD) begin
      instr_reg <= RD;
      PCD       <= PCF;
      PCPlus4D  <= PCPlus4F;
    end
    // 隐式锁存保持原值不变
  end

  // =========================================================================
  // 2. 组合逻辑：信号切片
  // =========================================================================
  assign Instr_6_0   = instr_reg[6:0];
  assign Instr_14_12 = instr_reg[14:12];
  assign Instr_30    = instr_reg[30];
  assign Instr_25    = instr_reg[25];
  
  assign Rs1D        = instr_reg[19:15];
  assign Rs2D        = instr_reg[24:20];
  assign RdD         = instr_reg[11:7];
  assign Instr_31_7  = instr_reg[31:7];

endmodule