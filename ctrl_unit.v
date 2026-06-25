`include "riscv_defs.vh"

module ctrl_unit
(
  input  wire [6:0]  op,
  input  wire [2:0]  funct3,
  input  wire        funct7_5,
  input  wire        funct7_0,

  output wire        RegWriteD,       // 改为 assign 驱动
  output reg  [1:0]  ResultSrcD,
  output wire        MemWriteD,       // 改为 assign 驱动
  output reg  [1:0]  s_selD,
  output reg  [1:0]  l_selD,
  output reg         u_loadD,
  output wire        JumpD,           // 改为 assign 驱动
  output wire        JumprD,          // 改为 assign 驱动
  output wire        BranchD,         // 改为 assign 驱动
  output reg  [1:0]  ALUResultsSrcD,
  output reg  [4:0]  ALUControlID,
  output wire        ALUSrcD,         // 改为 assign 驱动
  output reg  [2:0]  ImmSrcD
);

  // =========================================================================
  // 1. 采用原作者风格的纯组合逻辑连线 (assign)
  // =========================================================================
  assign RegWriteD = (op == OP_R_TYPE)   || (op == OP_I_TYPE_A) || 
                    (op == OP_I_TYPE_B) || (op == OP_I_TYPE_C) || 
                    (op == OP_U_TYPE_A) || (op == OP_U_TYPE_B) || 
                    (op == OP_J_TYPE);

  assign MemWriteD = (op == OP_S_TYPE);

  assign JumpD   = (op == OP_J_TYPE);
  assign JumprD  = (op == OP_I_TYPE_A);
  assign BranchD = (op == OP_B_TYPE);

  assign ALUSrcD = (op == OP_I_TYPE_A) || (op == OP_I_TYPE_B) || 
                   (op == OP_I_TYPE_C) || (op == OP_S_TYPE)   || 
                   (op == OP_U_TYPE_A);

  // =========================================================================
  // 2. ResultSrcD 译码
  // =========================================================================
  always @(*) begin
    case (op)
      OP_I_TYPE_A,
      OP_J_TYPE   : ResultSrcD = 2'b10; // PC + 4
      OP_I_TYPE_B : ResultSrcD = 2'b01; // Data Memory
      OP_U_TYPE_B : ResultSrcD = 2'b11; // PC + ImmExt (补上 AUIPC)
      default     : ResultSrcD = 2'b00; // ALUResult
    endcase
  end

  // =========================================================================
  // 3. Store 对齐控制译码 (s_selD)
  // =========================================================================
  always @(*) begin
    s_selD = 2'b10; // 严格对齐原作者默认 Word 初始化
    if (op == OP_S_TYPE) begin
      case (funct3[1:0])
        2'b00   : s_selD = 2'b00; // Store Byte
        2'b01   : s_selD = 2'b01; // Store Half
        2'b10   : s_selD = 2'b10; // Store Word
        default : s_selD = 2'b10;
      endcase
    end
  end

  // =========================================================================
  // 4. Load 对齐控制与符号位译码 (l_selD / u_loadD)
  // =========================================================================
  always @(*) begin
    l_selD  = 2'b10; // 默认 Word
    u_loadD = 1'b1;  // 严格对应原作者的无符号默认值

    if (op == OP_I_TYPE_B) begin
      case (funct3)
        3'b000,
        3'b100  : l_selD = 2'b00; // Load Byte
        3'b001,
        3'b101  : l_selD = 2'b01; // Load Half
        3'b010  : l_selD = 2'b10; // Load Word
        default : l_selD = 2'b10;
      endcase
      u_loadD = funct3[2]; // 捕捉符号选通位
    end
  end

  // =========================================================================
  // 5. ALU 结果多路选择总线 (ALUResultsSrcD)
  // =========================================================================
  always @(*) begin
    case (op)
      OP_I_TYPE_A,
      OP_J_TYPE   : ALUResultsSrcD = 2'b01; // PC + 4
      OP_U_TYPE_B : ALUResultsSrcD = 2'b10; // PC + ImmExt
      default     : ALUResultsSrcD = 2'b00; // 常规 ALUResult
    endcase
  end

  // =========================================================================
  // 6. 立即数模式选择译码 (ImmSrcD)
  // =========================================================================
  always @(*) begin
    case (op)
      OP_I_TYPE_A,
      OP_I_TYPE_B,
      OP_I_TYPE_C : ImmSrcD = IMM_I;
      OP_S_TYPE   : ImmSrcD = IMM_S;
      OP_B_TYPE   : ImmSrcD = IMM_B;
      OP_U_TYPE_A,
      OP_U_TYPE_B : ImmSrcD = IMM_U; // AUIPC 和 LUI 共享 U 型立即数扩展
      OP_J_TYPE   : ImmSrcD = IMM_J;
      default     : ImmSrcD = IMM_I;
    endcase
  end

  // =========================================================================
  // 7. 核心 ALU 算术指令译码 (ALUControlID)
  // =========================================================================
  always @(*) begin
    case (op)
      OP_I_TYPE_A,
      OP_I_TYPE_B,
      OP_S_TYPE   : ALUControlID = ALU_ADD;

      OP_U_TYPE_A : ALUControlID = ALU_LUI;

      OP_R_TYPE,
      OP_I_TYPE_C : begin
        if ((op == OP_R_TYPE) && funct7_0) begin
          // M 扩展多周期乘除法
          case (funct3)
            3'b000  : ALUControlID = ALU_MUL;
            3'b001  : ALUControlID = ALU_MULH;
            3'b010  : ALUControlID = ALU_MULHSU;
            3'b011  : ALUControlID = ALU_MULHU;
            3'b100  : ALUControlID = ALU_DIV;
            3'b101  : ALUControlID = ALU_DIVU;
            3'b110  : ALUControlID = ALU_REM;
            3'b111  : ALUControlID = ALU_REMU;
            default : ALUControlID = ALU_INVAL;
          endcase
        end 
        else begin
          // 基础 I 扩展整数运算
          case (funct3)
            3'b000  : ALUControlID = ((op == OP_R_TYPE) && funct7_5) ? ALU_SUB : ALU_ADD;
            3'b001  : ALUControlID = ALU_SLL;
            3'b010  : ALUControlID = ALU_LESS;
            3'b011  : ALUControlID = ALU_LESSU;
            3'b100  : ALUControlID = ALU_XOR;
            3'b101  : ALUControlID = funct7_5 ? ALU_SRA : ALU_SRL;
            3'b110  : ALUControlID = ALU_OR;
            3'b111  : ALUControlID = ALU_AND;
            default : ALUControlID = ALU_INVAL;
          endcase
        end
      end

      OP_B_TYPE : begin
        case (funct3)
          3'b000  : ALUControlID = ALU_EQ;
          3'b001  : ALUControlID = ALU_NEQ;
          3'b100  : ALUControlID = ALU_LESS;
          3'b101  : ALUControlID = ALU_GEQ;
          3'b110  : ALUControlID = ALU_LESSU;
          3'b111  : ALUControlID = ALU_GEQU;
          default : ALUControlID = ALU_INVAL;
        endcase
      end

      default : ALUControlID = ALU_INVAL;
    endcase
  end

endmodule