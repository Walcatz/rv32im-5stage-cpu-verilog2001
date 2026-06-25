module btb
(
  input  wire        clk,
  input  wire        reset,
  input  wire [31:0] PCF,         // 取指级当前 PC (用于查表读 Tag)
  input  wire [31:0] PCE,         // 执行级当前 PC (用于同步更新写 Tag)
  input  wire        JumpE,       // 来自 EX 级的 JAL 标志
  input  wire        JumprE,      // 来自 EX 级的 JALR 标志
  input  wire        BranchE,     // 来自 EX 级的 B-Type 标志
  input  wire        br_actualE,  // EX 级分支比对物理结果
  input  wire [31:0] PCTargetE,   // B-Type/JAL 计算出来的物理目标地址
  input  wire [31:0] ALUResultE,  // JALR 计算出来的物理目标地址
  
  output wire        btb_hit,     // 预测命中指示线
  output wire [31:0] target_addr  // 吐给前级的预测跳转目标地址
);
  //BTB, Branch Target Buffer

  // 1. 核心控制分支：判定 EX 级有符号条件分支是否真的发生了跳转
  wire br_takenE;
  assign br_takenE = BranchE && br_actualE;

  // 2. 存储阵列物理拆分（降级至标准 V2001 二维数组行为模型）
  reg        valid_array [0:1023]; // 仅对 1024 位的 Valid 阵列进行硬件复位
  reg [31:0] tag_array   [0:1023]; // Tag 存放历史上在这里挨打的 PC
  reg [31:0] target_array[0:1023]; // 存放历史上成功跳过去的目标物理地址

  // 3. 组合逻辑：Fetch (IF) 阶段的高速异步查表
  wire [9:0] read_index;
  assign read_index  = PCF[11:2]; // 取 PC 的中间 10 位作为查找哈希索引
  
  // 命中条件：当前条目必须有效，且登记的 Tag 必须和当前的 PCF 丝滑对齐
  assign btb_hit     = valid_array[read_index] && (tag_array[read_index] == PCF);
  assign target_addr = target_array[read_index];

  // 4. 时序逻辑：在时钟上升沿响应 EX 级的真理写入与安全清零
  integer k;
  always @(posedge clk) begin
    if (reset) begin
      // 完美的 Verilog-2001 批量 Valid 复位网络（仅 1024 个晶体管面积开销）
      for (k = 0; k < 1024; k = k + 1) begin
        valid_array[k] <= 1'b0;
      end
    end 
    else if (JumpE || JumprE || br_takenE) begin
      // 当发生任意形式的跳转动作时，霸占对应的存储槽位并宣告激活
      valid_array[PCE[11:2]] <= 1'b1;
      tag_array[PCE[11:2]]   <= PCE;
      target_array[PCE[11:2]]<= JumprE ? ALUResultE : PCTargetE;
    end
  end

endmodule