module mux3 #(parameter WIDTH = 32)
(
  input  wire [WIDTH-1:0] d0, 
  input  wire [WIDTH-1:0] d1, 
  input  wire [WIDTH-1:0] d2, // 数据输入
  input  wire [1:0]       s,  // 2位选择总线
  output reg  [WIDTH-1:0] y   // 数据输出 (用 reg 承载组合逻辑)
);

  // 采用全覆盖 case 块，规避多维三目运算符的优先级歧义
  always @(*) begin
    case (s)
      2'b00   : y = d0;
      2'b01   : y = d1;
      2'b10   : y = d2;
      default : y = d0; // 兜底处理 2'b11 或未知态，防止触发 Latch
    endcase
  end

endmodule