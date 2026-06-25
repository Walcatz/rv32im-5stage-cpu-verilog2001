module mux4 #(parameter WIDTH = 32)
(
  input  wire [WIDTH-1:0] d0, 
  input  wire [WIDTH-1:0] d1, 
  input  wire [WIDTH-1:0] d2, 
  input  wire [WIDTH-1:0] d3, // 数据输入
  input  wire [1:0]       s,  // 2位选择总线
  output reg  [WIDTH-1:0] y   // 数据输出
);

  // 四选一/写回 MUX，映射成硬件上最纯粹的传输门并联网络
  always @(*) begin
    case (s)
      2'b00   : y = d0;
      2'b01   : y = d1;
      2'b10   : y = d2;
      2'b11   : y = d3;
      default : y = d0;
    endcase
  end

endmodule