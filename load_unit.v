module load_unit
(
  input  wire [1:0]  l_sel,      // Load 类型选择 (00: Byte, 01: Half-word, 10: Word)
  input  wire [1:0]  bhw_sel,    // 字节/半字对齐选择 (通常来自 ALUResultW[1:0])
  input  wire        u_load,     // 无符号加载使能 (1: 零扩展, 0: 符号扩展)
  input  wire [31:0] RawData,    // 来自 Data Memory 吐出的原始32位数据
  output reg  [31:0] ReadData    // 格式化后、真正送往寄存器堆写回端的数据
  //output reg  [31:0] ProReadData    // Processed Read Data (最终送回寄存器堆的值，经过 Load Unit 处理)

);

  // 局部临时声明，用于暂存提取出来的目标碎片
  reg [7:0]  target_byte;
  reg [15:0] target_half;

  always @(*) begin
    // 默认兜底赋值，防止 Latch 产生
    ReadData    = RawData;
    target_byte = RawData[7:0];
    target_half = RawData[15:0];

    case (l_sel)
      // =====================================================================
      // 1. Load Byte (LB / LBU)
      // =====================================================================
      2'b00: begin
        // 首先：精准抓取当前地址对应的那个物理字节
        case (bhw_sel)
          2'b00   : target_byte = RawData[7:0];   // Byte 0
          2'b01   : target_byte = RawData[15:8];  // Byte 1
          2'b10   : target_byte = RawData[23:16]; // Byte 2
          2'b11   : target_byte = RawData[31:24]; // Byte 3
          default : target_byte = RawData[7:0];
        endcase

        // 其次：整合成32位，并根据 u_load 动态判定是补 0 还是补各自真正的符号位 (target_byte[7])
        ReadData = u_load ? {24'b0, target_byte} : {{24{target_byte[7]}}, target_byte};
      end

      // =====================================================================
      // 2. Load Half-word (LH / LHU)
      // =====================================================================
      2'b01: begin
        // 首先：精准抓取当前地址对应的那个物理半字
        case (bhw_sel[1])
          1'b0    : target_half = RawData[15:0];  // Half-word 0
          1'b1    : target_half = RawData[31:16]; // Half-word 1
          default : target_half = RawData[15:0];
        endcase

        // 其次：整合成32位，动态判定是补 0 还是补各自真正的符号位 (target_half[15])
        ReadData = u_load ? {16'b0, target_half} : {{16{target_half[15]}}, target_half};
      end

      // =====================================================================
      // 3. Load Word (LW)
      // =====================================================================
      2'b10: begin
        ReadData = RawData; // 满32位直接透传
      end

      default: begin
        ReadData = RawData;
      end
    endcase
  end

endmodule