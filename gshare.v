module gshare
(
  input  wire        clk,
  input  wire        reset,
  input  wire [31:0] PCF,
  input  wire [31:0] PCPlus4F,
  input  wire [6:0]  opF,          // 强转为标准的 7 位物理操作码
  input  wire [31:0] PCE,
  input  wire [31:0] PCPlus4E,
  input  wire [1:0]  PCSrcE,
  input  wire        JumpE,
  input  wire        JumprE,
  input  wire        BranchE,
  input  wire        br_actualE,
  input  wire [31:0] PCTargetE,
  input  wire [31:0] ALUResultE,
  input  wire        mispredictE,
  
  output reg         br_predictE,  // 顺延传递到 EX 级，交给 pc_src 去比对
  output wire [31:0] PCNextF,      // 反向控回最前端 PC 寄存器的源数据
  
  // 挂接来自 Hazard Unit 的冲刷互锁闸门
  input  wire        StallD,
  input  wire        FlushD,
  input  wire        StallE,
  input  wire        FlushE
);

  // 内部互联导线与打拍寄存器声明
  wire [9:0]  gbh_reg;
  wire [9:0]  pht_indexF;
  reg  [9:0]  pht_indexD;
  reg  [9:0]  pht_indexE;
  wire        br_predictF;
  reg         br_predictD;
  wire        pht_taken;
  wire        hit;
  wire [31:0] target_addr;
  reg  [31:0] PCNext_actualF;

  // =========================================================================
  // 1. 内部预测专线的流水线打拍同步（Decode 级与 Execute 级隔离大闸）
  // =========================================================================
  always @(posedge clk) begin
    // Decode (ID) 级状态同步
    if (FlushD) begin
      pht_indexD  <= 10'b0;
      br_predictD <= 1'b0;
    end 
    else if (!StallD) begin
      pht_indexD  <= pht_indexF;
      br_predictD <= br_predictF;
    end

    // Execute (EX) 级状态同步
    if (FlushE) begin
      pht_indexE  <= 10'b0;
      br_predictE <= 1'b0;
    end 
    else if (!StallE) begin
      pht_indexE  <= pht_indexD;
      br_predictE <= br_predictD;
    end
  end

  // =========================================================================
  // 2. 核心构件实例化（穿针引线）
  // =========================================================================
  
  // A. 级联全局历史寄存器
  gbh u_gbh(
    .clk(clk),
    .reset(reset),
    .BranchE(BranchE),
    .br_actualE(br_actualE),
    .gbh_reg(gbh_reg)
  );

  // B. 执行 Gshare 哈希算法：PC 的 10 位线与全局历史进行硬核 XOR
  assign pht_indexF = gbh_reg ^ PCF[11:2];

  // C. 级联模式历史表 (这里你顶层需要提供对齐的 pht 模块)
  pht u_pht(
    .clk(clk),
    .reset(reset),
    .BranchE(BranchE),
    .br_actualE(br_actualE),
    .pht_indexF(pht_indexF),
    .pht_indexE(pht_indexE),
    .pht_taken(pht_taken)
  );

  // D. 级联分支目标缓存
  btb u_btb(
    .clk(clk),
    .reset(reset),
    .PCF(PCF),
    .PCE(PCE),
    .JumpE(JumpE),
    .JumprE(JumprE),
    .BranchE(BranchE),
    .br_actualE(br_actualE),
    .PCTargetE(PCTargetE),
    .ALUResultE(ALUResultE),
    .btb_hit(hit),
    .target_addr(target_addr)
  );

  // =========================================================================
  // 3. 组合逻辑：生成超前预测结果
  //    I_TYPE_a (7'h67 对应 JALR) | J_TYPE (7'h6f 对应 JAL)
  // =========================================================================
  wire jump_taken = (opF == 7'h67) || (opF == 7'h6F);
  assign br_predictF = (pht_taken || jump_taken) && hit;

  // =========================================================================
  // 4. 多路选择器数据流合拢（内联展开映射，免去外部例化）
  // =========================================================================

  // MUX 1: 判定发生分支纠错（猜错）时，真理主干的正确恢复目标
  always @(*) begin
    case (PCSrcE)
      2'b00   : PCNext_actualF = PCPlus4E;
      2'b01   : PCNext_actualF = PCTargetE;
      2'b10   : PCNext_actualF = ALUResultE;
      default : PCNext_actualF = PCPlus4E;
    endcase
  end

  // MUX 2: 终极预测总控。结合 mispredictE 和 br_predictF
  wire [1:0] sel_predicted = {mispredictE, br_predictF};
  reg  [31:0] pc_next_mux_out;
  
  always @(*) begin
    case (sel_predicted)
      2'b00   : pc_next_mux_out = PCPlus4F;       // 没猜错，且不跳：常规递增
      2'b01   : pc_next_mux_out = target_addr;    // 没猜错，但猜跳：拉去BTB预测目标
      2'b10   : pc_next_mux_out = PCNext_actualF; // 翻车！触发纠错：强行塞回真理轨道
      2'b11   : pc_next_mux_out = PCNext_actualF; // 同上：纠错具有最高决定权
      default : pc_next_mux_out = PCPlus4F;
    endcase
  end

  assign PCNextF = pc_next_mux_out;

endmodule