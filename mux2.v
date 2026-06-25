module mux2 #(parameter WIDTH = 32)
(
  input  wire [WIDTH-1:0] d0, 
  input  wire [WIDTH-1:0] d1, // 数据输入
  input  wire             s,  // 选择信号
  output wire [WIDTH-1:0] y   // 数据输出
);

  // 时序最干净的连续赋值三目运算
  assign y = s ? d1 : d0;

endmodule