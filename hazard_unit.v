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
  output wire         StallF,
  output wire         StallD,
  output wire         FlushD,
  output wire         StallE,
  output wire         FlushE,
  output wire         FlushM,

  // 前推选通 MUX 控制线
  output wire  [1:0]  ForwardAE,
  output wire  [1:0]  ForwardBE
);

  // 内部临时逻辑变量声明 (在组合逻辑块内部赋值，综合映射为 wire)
  wire lStall;   // Load Stall
  wire aluStall; // ALU Stall
  wire jbFlush;  // Jump/Branch Flush


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
  assign lStall = (ResultSrcE == 2'b01) && (RdE != 5'b0) && ((Rs1D == RdE) || (Rs2D == RdE));

  // =========================================================================
  // 2. 控制冒险与结构冒险提取
  // =========================================================================

    assign jbFlush  = mispredictE; // 分支预测失败，立刻启动大冲刷
    assign aluStall = BusyE;       // 乘除法器未收敛，启动多周期挂起机制


  // =========================================================================
  // 3. 终极控制网关：Stall / Flush 信号的并联解算
  // =========================================================================

    assign StallF = lStall || aluStall;

    // Decode (ID) 级：拉住大闸挂起；遇到分支预测失败直接冲刷
    assign StallD = lStall || aluStall;
    assign FlushD = jbFlush;

    // Execute (EX) 级：乘除忙时锁死当前级状态；遇到常规 Load-use 或分支失败则向后级注入 NOP
    assign StallE = aluStall;
    assign FlushE = lStall || jbFlush;

    // Memory (MEM) 级：主动 Flush 不让MUL/DIV结果污染后续Mem级
    assign FlushM = aluStall;



endmodule