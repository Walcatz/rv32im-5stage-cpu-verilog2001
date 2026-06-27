module alu
(
  input  wire        clk,        // Clock
  input  wire        reset,      // Reset
  input  wire [31:0] SrcA,       // Source A (严格对齐微架构图 SrcAE)
  input  wire [31:0] SrcB,       // Source B (严格对齐微架构图 SrcBE)
  input  wire [4:0]  ALUControl, // ALU Control (5-bit 参数控制码)
  output wire        BusyE,      // ALU Busy (送往 Hazard Unit)
  output reg  [31:0] ALUResult   // ALU Result
);
  `include "riscv_defs.vh"
  // 内部线网声明 (组合逻辑输出用 reg，子模块连线用 wire)
  wire [31:0] adder_out, shift_out, and_out, or_out, xor_out;
  reg         sub_en;
  wire        v, c, n, z;
  reg         s_mode, a_en;

  wire [63:0] multiplier_out;
  wire [31:0] quotient_out, remainder_out;
  reg  [1:0]  m_sign_sel;
  reg         d_sign_sel;
  reg         mul_op, div_op;
  wire        mul_v, div_v;

  // 握手信号：在使用多周期乘除法单元时，未完成前维持 Busy 状态
  assign BusyE = reset ? 1'b0 : (mul_op & !mul_v) | (div_op & !div_v);

  // =========================================================================
  // 子模块例化 (与原模块完美对齐)
  // =========================================================================
  adder u_add(
    .opA(SrcA),
    .opB(SrcB),
    .sub_en(sub_en),
    .sum(adder_out),
    .overflow(v),
    .carry(c),
    .negative(n),
    .zero(z)
  );

  barrel_shifter u_shift(
    .data_in(SrcA),
    .shift_amount(SrcB[4:0]),
    .shift_mode(s_mode),      // 0: Left, 1: Right
    .arithmetic_en(a_en),     // 0: No Sign, 1: Preserve Sign
    .data_out(shift_out)
  );

  multiplier_16c u_mul_16c(
    .clk(clk),
    .reset(reset),
    .enable(mul_op),
    .opA(SrcA),
    .opB(SrcB),
    .sign_sel(m_sign_sel),    // 00: S/S, 01: S/U, 10: U/U
    .product(multiplier_out),
    .done(mul_v)
  );

  divider_32c u_div_32c(
    .clk(clk),
    .reset(reset),
    .enable(div_op),
    .sign_sel(d_sign_sel),    // 0: S/S, 1: U/U
    .numA(SrcA),
    .denB(SrcB),
    .done(div_v),
    .quotient(quotient_out),
    .remainder(remainder_out)
  );

  // =========================================================================
  // 组合逻辑控制通路
  // =========================================================================
  assign and_out = SrcA & SrcB;
  assign or_out  = SrcA | SrcB;
  assign xor_out = SrcA ^ SrcB;

  always @(*) begin
    // 1. 生成基础部件控制信号
    sub_en = (ALUControl == ALU_SUB)  ||
             (ALUControl == ALU_EQ)   || (ALUControl == ALU_NEQ)  ||
             (ALUControl == ALU_LESS) || (ALUControl == ALU_LESSU) ||
             (ALUControl == ALU_GEQ)  || (ALUControl == ALU_GEQU);

    s_mode = (ALUControl == ALU_SRL)  || (ALUControl == ALU_SRA);

    a_en   = (ALUControl == ALU_SRA);

    // 2. 生成乘除法触发信号
    mul_op = (ALUControl == ALU_MUL)    || (ALUControl == ALU_MULH) ||
             (ALUControl == ALU_MULHSU) || (ALUControl == ALU_MULHU);

    div_op = (ALUControl == ALU_DIV)    || (ALUControl == ALU_DIVU) ||
             (ALUControl == ALU_REM)    || (ALUControl == ALU_REMU);

    // 3. 乘除法有符号/无符号模式选择
    m_sign_sel = (ALUControl == ALU_MULHSU) ? 2'b01 :   // 有符号/无符号
                 (ALUControl == ALU_MULHU)  ? 2'b10 :   // 无符号/无符号
                                              2'b00 ;   // 默认 有符号/有符号

    d_sign_sel = (ALUControl == ALU_DIVU) || (ALUControl == ALU_REMU);

    // 4. 最终大 MUX 结果输出选择
    case (ALUControl)
      ALU_ADD,
      ALU_SUB     : ALUResult = adder_out;

      ALU_EQ      : ALUResult = {31'b0, z};
      ALU_NEQ     : ALUResult = {31'b0, !z};
      
      ALU_LESS    : ALUResult = {31'b0, n ^ v};
      ALU_LESSU   : ALUResult = {31'b0, !c};
      
      ALU_GEQ     : ALUResult = {31'b0, !(n ^ v)};
      ALU_GEQU    : ALUResult = {31'b0, c};

      ALU_AND     : ALUResult = and_out;
      ALU_OR      : ALUResult = or_out;
      ALU_XOR     : ALUResult = xor_out;

      ALU_SLL,
      ALU_SRL,
      ALU_SRA     : ALUResult = shift_out;

      ALU_LUI     : ALUResult = SrcB;

      ALU_MUL     : ALUResult = multiplier_out[31:0];
      
      ALU_MULH,
      ALU_MULHSU,
      ALU_MULHU   : ALUResult = multiplier_out[63:32];

      ALU_DIV,
      ALU_DIVU    : ALUResult = quotient_out;

      ALU_REM,
      ALU_REMU    : ALUResult = remainder_out;

      ALU_INVAL   : ALUResult = adder_out;
      default     : ALUResult = adder_out;
    endcase
  end

endmodule