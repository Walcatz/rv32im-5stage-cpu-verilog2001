module store_unit
(
  input  wire        MemWrite,  // 来自流水线后级的内存写总使能
  input  wire [1:0]  s_sel,     // Store 类型选择 (00: Byte, 01: Half-word, 10: Word)
  input  wire [1:0]  b_sel,     // 字节对齐选择偏置 (通常来自 ALUResultM[1:0])
  input  wire [31:0] RawData,   // 经前推筛选后，准备写内存的原始32位数据 (RD2M)
  
  output reg  [3:0]  byte_en,   // 4位数据存储器字节写使能掩码 (Byte Enable / WE_mask)
  output reg  [31:0] WriteData  // 格式化复制后、真正送往 Data Memory 物理数据总线的数据
);

  // =========================================================================
  // 组合逻辑核心控制块：数据复制与掩码生成一体化
  // =========================================================================
  always @(*) begin
    // 1. 默认兜底赋值：如果不满足写使能，字节掩码全清0，关闭内存写入闸门
    byte_en   = 4'b0000;
    WriteData = RawData;

    // 2. 硬件级别的数据盲拷复制：利用导线物理分叉，不消耗逻辑门面积
    case (s_sel)
      2'b00   : WriteData = {4{RawData[7:0]}};  // SB (Store Byte): 复制4份
      2'b01   : WriteData = {2{RawData[15:0]}}; // SH (Store Half): 复制2份
      2'b10   : WriteData = RawData;            // SW (Store Word): 全32位透传
      default : WriteData = RawData;
    endcase

    // 3. 当且仅当写总主闸 MemWrite 拉高时，才去根据偏置打开特定的字节通道
    if (MemWrite) begin
      case (s_sel)
        // -------------------------------------------------------------------
        // SB 指令：激活 4 个字节通道中的某一个
        // -------------------------------------------------------------------
        2'b00: begin 
          case (b_sel)
            2'b00   : byte_en = 4'b0001; // 写在第 0 字节 (低8位)
            2'b01   : byte_en = 4'b0010; // 写在第 1 字节
            2'b10   : byte_en = 4'b0100; // 写在第 2 字节
            2'b11   : byte_en = 4'b1000; // 写在第 3 字节 (高8位)
            default : byte_en = 4'b0001;
          endcase
        end

        // -------------------------------------------------------------------
        // SH 指令：激活 2 个半字通道中的某一个 (由最高位 b_sel[1] 决定)
        // -------------------------------------------------------------------
        2'b01: begin 
          case (b_sel[1])
            1'b0    : byte_en = 4'b0011; // 写在低16位通道
            1'b1    : byte_en = 4'b1100; // 写在高16位通道
            default : byte_en = 4'b0011;
          endcase
        end

        // -------------------------------------------------------------------
        // SW 指令：全部 4 个字节通道火力全开同时写入
        // -------------------------------------------------------------------
        2'b10: begin 
          byte_en = 4'b1111;
        end

        default: begin
          byte_en = 4'b1111;
        end
      endcase
    end
  end

endmodule