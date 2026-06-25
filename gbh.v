module gbh
(
  input  wire        clk,
  input  wire        reset,
  input  wire        BranchE,    // 更新使能：EX级检测到是 B-Type 指令
  input  wire        br_actualE, // EX级分支比较器的真实物理结果
  output reg  [9:0]  gbh_reg     // 当前的全局历史战绩吐给前级
);
 //GBH, Global Branch History
  always @(posedge clk) begin
    if (reset) begin
      gbh_reg <= 10'b0;
    end 
    else if (BranchE) begin
      // 向左移位，最低位更新
      gbh_reg <= {gbh_reg[8:0], br_actualE};
    end
  end

endmodule