module pht
(
  input  wire        clk,        // Clock
  input  wire        reset,      // Reset
  input  wire        BranchE,    // Branch Detect from EX stage
  input  wire        br_actualE, // Actual branch outcome from EX stage ALUResult[0]
  input  wire [9:0]  pht_indexF, // Address to predict next branch outcome
  input  wire [9:0]  pht_indexE, // Address to update counters
  output wire        pht_taken   // Predicted branch outcome
);
  //PHT, Pattern History Table

  // Verilog-2001中二维数组定义
  // 组相联（Set-Associative）架构？？
  reg [1:0] PHT_Array [0:1023];
  reg [1:0] count;

  // 1. 组合逻辑块：使用传统 always @(*)
  always @(*) begin
    case (PHT_Array[pht_indexE])
                                 // Taken : Not Taken
      2'b00: count = br_actualE ? 2'b01 : 2'b00; // Strong Not Taken
      2'b01: count = br_actualE ? 2'b10 : 2'b00; // Weak Not Taken
      2'b10: count = br_actualE ? 2'b11 : 2'b01; // Weak Taken
      2'b11: count = br_actualE ? 2'b11 : 2'b10; // Strong Taken
      default: count = 2'b01;                    // 增加default防止意外产生Latch
    endcase
  end

  // 2. 同步写时序块：使用传统 always @(posedge clk)
  integer i; // Verilog-2001要求循环变量定义在块外面
  always @(posedge clk) begin
    if (reset) begin
        // 初始化计数器 (Weak Not Taken 2'b01)
        for (i = 0; i < 1024; i = i + 1) begin
            PHT_Array[i] <= 2'b01; 
        end
    end else if (BranchE) begin
      PHT_Array[pht_indexE] <= count;
    end
  end

  // 3. 异步读逻辑
  assign pht_taken = PHT_Array[pht_indexF][1];// 预测结果：高位为1表示预测跳转，高位为0表示预测不跳转

endmodule