module adder
(
  input  wire [31:0] opA,      // Operand A
  input  wire [31:0] opB,      // Operand B
  input  wire        sub_en,   // Subtraction Enable (1: Subtract, 0: Add)

  output reg  [31:0] sum,      // Result
  output reg         overflow, // Overflow Flag
  output reg         carry,    // Carry Flag
  output wire        negative, // Negative Flag (可通过组合逻辑逻辑 assign)
  output wire        zero      // Zero Flag (可通过组合逻辑逻辑 assign)
);

  // 内部逻辑声明 (logic 转换为 reg)
  reg [31:0] newB;

  // 组合逻辑计算块
  always @(*) begin
    // 减法使能时，B码按位取反，后续通过 + sub_en 补齐补码的 +1
    newB = sub_en ? ~opB : opB;

    // 拼接执行 32位加/减运算，并捕获第33位进位
    {carry, sum} = opA + newB + sub_en;

    // 溢出标志判断：
    // 当两数符号相同，但运算结果符号与操作数相反时，发生算术溢出
    overflow = ~(opA[31] ^ opB[31] ^ sub_en) & (opA[31] ^ sum[31]);
  end

  // 符号位与零标志位直接通过纯硬件连线（assign）引出，更加高效
  assign negative = sum[31];
  assign zero     = ~|sum;  // 缩减Nor操作，当且仅当 sum 全为0时输出1

endmodule