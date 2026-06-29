


module extend
(
  input  wire [31:7] i_imm,   // Immediate Raw (机器码中的原始立即数片段InstrD[31:7])
  input  wire [2:0]  ImmSrc,  // Immediate Select (来自 riscv_defs.vh)
  output reg  [31:0] ImmExt   // Immediate Extended (符号扩展后的 32 位立即数)
);
  `include "riscv_defs.vh"
  // 组合逻辑计算块

  always @(*) begin

    case (ImmSrc)
      // I-Type (整数立即数/Load/JALR): 对应原指令 [31:20]
      IMM_I   : ImmExt = {{20{i_imm[31]}}, i_imm[31:20]};
      
      // S-Type (Store指令): 原 [31:25] 和 [11:7]
      IMM_S   : ImmExt = {{20{i_imm[31]}}, i_imm[31:25], i_imm[11:7]};
      
      // B-Type (条件分支跳转): 原 [31], [7], [30:25], [11:8]
      IMM_B   : ImmExt = {{20{i_imm[31]}}, i_imm[7], i_imm[30:25], i_imm[11:8], 1'b0};
      
      // U-Type (LUI/AUIPC): 原高20位 [31:12]
      IMM_U   : ImmExt = {i_imm[31:12], 12'b0};
      
      // J-Type (JAL绝对跳转): 原 [31], [19:12], [20], [30:21] -> 平移后为 [24], [12:5], [13], [23:14]
      IMM_J   : ImmExt = {{12{i_imm[31]}}, i_imm[19:12], i_imm[20], i_imm[30:21], 1'b0};

      IMM_Z   : ImmExt = {27'b0, i_imm[19:15]};
      
      // 默认情况：导向安全默认值，防止由于未全覆盖产生锁存器(Latch)
      default : ImmExt = {{20{i_imm[31]}}, i_imm[31:20]};
    endcase

  end

endmodule