module hazard_unit
(
  input  wire [4:0] Rs1D,
  input  wire [4:0] Rs2D,

  input  wire [4:0] Rs1E,
  input  wire [4:0] Rs2E,
  input  wire [4:0] RdE,
  input  wire       mispredictE,
  input  wire [1:0] ResultSrcE, // 2'b01 代表当前EX级是 Load 指令
  input  wire       BusyE,       // 来自多周期乘除法 ALU 的忙信号

  input  wire [4:0] RdM,
  input  wire       RegWriteM,

  input  wire [4:0] RdW,
  input  wire       RegWriteW,

  // 流水线控制输出大闸
  output reg         StallF,
  output reg         StallD,
  output reg         FlushD,
  output reg         StallE,
  output reg         FlushE,
  output reg         FlushM,

  // 前推选通 MUX 控制线
  output reg  [1:0]  ForwardAE,
  output reg  [1:0]  ForwardBE
);

  // 内部临时逻辑变量声明 (在组合逻辑块内部赋值，综合映射为 wire)
  reg lStall;   // Load Stall
  reg aluStall; // ALU Stall
  reg jbFlush;  // Jump/Branch Flush

  // =========================================================================
  // 1. 数据冒险：前推与 Load-use 挂起判定
  // =========================================================================
  always @(*) begin
    // -----------------------------------------------------------------------
    // ForwardAE 路由选择：核心端 A 前推判定 (严格保证 MEM 级具有最高前推优先级)
    // -----------------------------------------------------------------------
    if ((Rs1E == RdM) && RegWriteM && (Rs1E != 5'b0)) begin
      ForwardAE = 2'b10; // 优先拦截：数据来自 MEM 级的 ALUResultM
    end
    else if ((Rs1E == RdW) && RegWriteW && (Rs1E != 5'b0)) begin
      ForwardAE = 2'b01; // 次要拦截：数据来自 WB 级的 ResultW
    end
    else begin
      ForwardAE = 2'b00; // 无冲突：保持通用寄存器堆出来的原始值 RD1E
    end

    // -----------------------------------------------------------------------
    // ForwardBE 路由选择：核心端 B 前推判定
    // -----------------------------------------------------------------------
    if ((Rs2E == RdM) && RegWriteM && (Rs2E != 5'b0)) begin
      ForwardBE = 2'b10; // 优先拦截：数据来自 MEM 级的 ALUResultM
    end
    else if ((Rs2E == RdW) && RegWriteW && (Rs2E != 5'b0)) begin
      ForwardBE = 2'b01; // 次要拦截：数据来自 WB 级的 ResultW
    end
    else begin
      ForwardBE = 2'b00; // 无冲突：保持通用寄存器堆出来的原始值 RD2E
    end

    // -----------------------------------------------------------------------
    // Load-use 冒险判定：
    // 当前级是 Load (ResultSrcE == 2'b01) 且后级正在译码的源寄存器依赖它还没捞出来的 RdE
    // -----------------------------------------------------------------------
    lStall = (ResultSrcE == 2'b01) && ((Rs1D == RdE) || (Rs2D == RdE));
  end

  // =========================================================================
  // 1. 数据冒险：前推与 Load-use 挂起判定 (纯 assign 扁平化重构)
  // =========================================================================

  // ForwardAE 路由选择：严格保证 MEM 级具有最高前推优先级
  assign ForwardAE = ((Rs1E == RdM) && RegWriteM && (Rs1E != 5'b0)) ? 2'b10 : // 优先拦截：来自 MEM 级
                     ((Rs1E == RdW) && RegWriteW && (Rs1E != 5'b0)) ? 2'b01 : // 次要拦截：来自 WB 级
                                                                      2'b00 ; // 无冲突：保持原始值

  // ForwardBE 路由选择：严格保证 MEM 级具有最高前推优先级
  assign ForwardBE = ((Rs2E == RdM) && RegWriteM && (Rs2E != 5'b0)) ? 2'b10 : // 优先拦截：来自 MEM 级
                     ((Rs2E == RdW) && RegWriteW && (Rs2E != 5'b0)) ? 2'b01 : // 次要拦截：来自 WB 级
                                                                      2'b00 ; // 无冲突：保持原始值


  // =========================================================================
  // 2. 控制冒险与结构冒险提取
  // =========================================================================
  always @(*) begin
    jbFlush  = mispredictE; // 分支预测失败，立刻启动大冲刷
    aluStall = BusyE;       // 乘除法器未收敛，启动多周期挂起机制
  end

  // =========================================================================
  // 3. 终极控制网关：Stall / Flush 信号的并联解算
  // =========================================================================
  always @(*) begin
    // Fetch (IF) 级：发生 Load-use 或 乘除法忙，立刻冻结 PC 递增
    StallF = lStall || aluStall;

    // Decode (ID) 级：拉住上一级大闸，同时如果分支预测失败，冲刷掉译码中的假指令
    StallD = lStall || aluStall;
    FlushD = jbFlush;

    // Execute (EX) 级：乘除法忙时锁住当前状态；若发生 Load-use 或预测失败，向后级塞入 NOP 气泡
    StallE = aluStall;
    FlushE = lStall || jbFlush;

    // Memory (MEM) 级：多周期乘除法在执行时，由于 EX 级被锁死，必须冲刷 MEM 级防止写入动作重复触发
    FlushM = aluStall;
  end

endmodule