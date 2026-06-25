module id_ex_reg
(
  // =========================================================================
  // 1. 全局控制总线 (严格对照图纸底部引脚与极性)
  // =========================================================================
  input  wire        CLK,             // 全局主时钟
  input  wire        StallE,          // 连在 EN 端的低电平有效使能 (1: 冻结, 0: 正常滚动)
  input  wire        FlushE,          // 连在 CLR 端的高电平有效清空信号 (1: 冲刷清零)

  // =========================================================================
  // 2. 译码级 (ID) 输入端 (来自控制单元、分线大闸以及寄存器堆)
  // =========================================================================
  input  wire        RegWriteD,
  input  wire [1:0]  ResultSrcD,
  input  wire        MemWriteD,
  input  wire [1:0]  s_selD,
  input  wire [1:0]  l_selD,
  input  wire        u_loadD,
  input  wire        JumpD,
  input  wire        JumprD,
  input  wire        BranchD,
  input  wire [1:0]  ALUResultsSrcD,
  input  wire [4:0]  ALUControlD,
  input  wire        ALUSrcD,
  
  input  wire [31:0] PCD,
  input  wire [4:0]  Rs1D,
  input  wire [4:0]  Rs2D,
  input  wire [4:0]  RdD,
  input  wire [31:0] ImmExtD,
  input  wire [31:0] PCPlus4D,
  
  input  wire [31:0] RD1D,
  input  wire [31:0] RD2D,
  
  // =========================================================================
  // 3. 执行级 (EX) 输出端 (严格对照图纸右侧全组命名)
  // =========================================================================
  output reg         RegWriteE,
  output reg  [1:0]  ResultSrcE,
  output reg         MemWriteE,
  output reg  [1:0]  s_selE,
  output reg  [1:0]  l_selE,
  output reg         u_loadE,
  output reg         JumpE,
  output reg         JumprE,
  output reg         BranchE,
  output reg  [1:0]  ALUResultsSrcE,
  output reg  [4:0]  ALUControlE,
  output reg         ALUSrcE,
  
  output reg  [31:0] PCE,
  output reg  [4:0]  Rs1E,
  output reg  [4:0]  Rs2E,
  output reg  [4:0]  RdE,
  output reg  [31:0] ImmExtE,
  output reg  [31:0] PCPlus4E,
  
  output reg  [31:0] RD1E,
  output reg  [31:0] RD2E
);

  // =========================================================================
  // 同步时序打拍逻辑 (带 StallE 冻结与 FlushE 冲刷)
  // =========================================================================
  always @(posedge CLK) begin
    if (FlushE) begin
      // 当 FlushE 有效时，CLR 触发，将所有控制线与数据线清零（安全插入气泡）
      RegWriteE      <= 1'b0;
      ResultSrcE     <= 2'b00;
      MemWriteE      <= 1'b0;
      s_selE         <= 2'b10; // 遵循 Jeffrey 默认 Word 的安全设置
      l_selE         <= 2'b10; // 遵循 Jeffrey 默认 Word 的安全设置
      u_loadE        <= 1'b1;  // 遵循 Jeffrey 默认 Unsigned 的安全设置
      JumpE          <= 1'b0;
      JumprE         <= 1'b0;
      BranchE        <= 1'b0;
      ALUResultsSrcE <= 2'b00;
      ALUControlE    <= 5'b00000;
      ALUSrcE        <= 1'b0;
      
      PCE            <= 32'b0;
      Rs1E           <= 5'b0;
      Rs2E           <= 5'b0;
      RdE            <= 5'b0;
      ImmExtE        <= 32'b0;
      PCPlus4E       <= 32'b0;
      
      RD1E           <= 32'b0;
      RD2E           <= 32'b0;
    end 
    else if (!StallE) begin
      // 当没有被 StallE 锁死时，流水线欢快地向 EX 级输送数据
      RegWriteE      <= RegWriteD;
      ResultSrcE     <= ResultSrcD;
      MemWriteE      <= MemWriteD;
      s_selE         <= s_selD;
      l_selE         <= l_selD;
      u_loadE        <= u_loadD;
      JumpE          <= JumpD;
      JumprE         <= JumprD;
      BranchE        <= BranchD;
      ALUResultsSrcE <= ALUResultsSrcD;
      ALUControlE    <= ALUControlD;
      ALUSrcE        <= ALUSrcD;
      
      PCE            <= PCD;
      Rs1E           <= Rs1D;
      Rs2E           <= Rs2D;
      RdE            <= RdD;
      ImmExtE        <= ImmExtD;
      PCPlus4E       <= PCPlus4D;
      
      RD1E           <= RD1D;
      RD2E           <= RD2D;
    end
    // else if (StallE) 隐式锁存保持原值不变
  end

endmodule