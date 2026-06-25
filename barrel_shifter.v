module barrel_shifter
(
  input  wire [31:0] data_in,        // Input Data
  input  wire  [4:0] shift_amount,   // Shift Amount (5-bit for 32-bit data)
  input  wire        shift_mode,     // Shift Mode; 0: Left Shift, 1: Right Shift
  input  wire        arithmetic_en,  // Sign Preservation Enable; 0: Logical, 1: Arithmetic

  output reg  [31:0] data_out        // Shift Result
);

  // 组合逻辑计算块 (always_comb 转换为 always @(*))
  always @(*) begin

    case ({shift_mode, arithmetic_en})
      // 2'b00, 2'b01: 逻辑左移 (SLL/SLLI)
      // 无论是逻辑还是算术，左移都是低位补 0，因此无需区分 arithmetic_en
      2'b00,
      2'b01   : data_out = data_in << shift_amount;
      
      // 2'b10: 逻辑右移 (SRL/SRLI)
      // 高位纯粹补 0
      2'b10   : data_out = data_in >> shift_amount;
      
      // 2'b11: 算术右移 (SRA/SRAI)
      // 利用 Verilog-2001 的 $signed() 关键字强制转为有符号数，>>> 会自动根据最高位补符号位
      2'b11   : data_out = $signed(data_in) >>> shift_amount;
      
      // 默认情况：逻辑左移，防止生成意外的 Latch
      default : data_out = data_in << shift_amount;
    endcase

  end

endmodule