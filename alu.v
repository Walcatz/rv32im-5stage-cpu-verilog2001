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

  wire [31:0] mul_result;
  wire [63:0] mul_product;
  wire [31:0] div_result;
  wire [31:0] div_quotient, div_remainder;
  reg  [1:0]  m_op_sel;
  reg  [1:0]  d_op_sel;
  reg         mul_en, div_en;
  wire        mul_v, div_v;

  // 握手信号：在使用多周期乘除法单元时，未完成前维持 Busy 状态
  // 乘法高/低 32 位选择已下沉到 rv32m_mul_unit；ALU 直接取 mul_result。
  assign BusyE = reset ? 1'b0 : (mul_en & !mul_v) | (div_en & !div_v);

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

  rv32m_mul_unit u_rv32m_mul(
    .clk(clk),
    .reset(reset),
    .enable(mul_en),
    .mul_op(m_op_sel),        // 00: MUL, 01: MULH, 10: MULHSU, 11: MULHU
    .opA(SrcA),
    .opB(SrcB),
    .done(mul_v),
    .result(mul_result),      // final 32-bit RV32M writeback result
    .product(mul_product)     // full 64-bit product, kept for debug/compatibility
  );

  rv32m_div_unit u_rv32m_div(
    .clk(clk),
    .reset(reset),
    .enable(div_en),
    .div_op(d_op_sel),        // 00: DIV, 01: DIVU, 10: REM, 11: REMU
    .opA(SrcA),
    .opB(SrcB),
    .done(div_v),
    .result(div_result),      // final 32-bit RV32M writeback result
    .quotient(div_quotient),  // kept for debug/compatibility
    .remainder(div_remainder) // kept for debug/compatibility
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
    mul_en = (ALUControl == ALU_MUL)    || (ALUControl == ALU_MULH) ||
             (ALUControl == ALU_MULHSU) || (ALUControl == ALU_MULHU);

    div_en = (ALUControl == ALU_DIV)    || (ALUControl == ALU_DIVU) ||
             (ALUControl == ALU_REM)    || (ALUControl == ALU_REMU);

    // 3. 乘除法 RV32M 操作类型选择
    m_op_sel = (ALUControl == ALU_MULH)   ? 2'b01 :   // MULH
               (ALUControl == ALU_MULHSU) ? 2'b10 :   // MULHSU
               (ALUControl == ALU_MULHU)  ? 2'b11 :   // MULHU
                                            2'b00 ;   // MUL

    d_op_sel = (ALUControl == ALU_DIVU) ? 2'b01 :   // DIVU
               (ALUControl == ALU_REM)  ? 2'b10 :   // REM
               (ALUControl == ALU_REMU) ? 2'b11 :   // REMU
                                          2'b00 ;   // DIV

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

      ALU_MUL,
      ALU_MULH,
      ALU_MULHSU,
      ALU_MULHU   : ALUResult = mul_result;

      ALU_DIV,
      ALU_DIVU,
      ALU_REM,
      ALU_REMU    : ALUResult = div_result;

      ALU_INVAL   : ALUResult = adder_out;
      default     : ALUResult = adder_out;
    endcase
  end

endmodule