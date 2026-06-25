module ex_mem_reg
(
  input  wire        CLK,
  input  wire        FlushM,          // 高电平有效清空信号 (1: 冲刷当前级控制线，插入气泡)

  // Control Signals Input
  input  wire        RegWriteE,
  input  wire [1:0]  ResultSrcE,
  input  wire        MemWriteE,
  input  wire [1:0]  s_selE,
  input  wire [1:0]  l_selE,
  input  wire        u_loadE,
  input  wire [1:0]  ALUResultSrcE,

  // Control Signals Output
  output reg         RegWriteM,
  output reg  [1:0]  ResultSrcM,
  output reg         MemWriteM,
  output reg  [1:0]  s_selM,
  output reg  [1:0]  l_selM,
  output reg         u_loadM,
  output reg  [1:0]  ALUResultSrcM,

  // Data and Addresses Input
  input  wire [31:0] ALUResultE,
  input  wire [31:0] WriteDataE,
  input  wire [31:0] PCTargetE,
  input  wire [4:0]  RdE,
  input  wire [31:0] PCPlus4E,
  

  // Data and Addresses Output
  output reg  [31:0] ALUResultM,
  output reg  [31:0] WriteDataM,
  output reg  [31:0] PCTargetM,
  output reg  [4:0]  RdM,
  output reg  [31:0] PCPlus4M
);

  always @(posedge CLK) begin
    if (FlushM) begin
      // ======= 触发冲刷 =======
      RegWriteM     <= 1'b0;
      MemWriteM     <= 1'b0;
      
      // 以下分支控制线和数据线在使能关闭后均自动变为“无关项”
      // 保持全零复位，应在 Testbench 中观察到低电平波形
      ResultSrcM    <= 2'b00;
      s_selM        <= 2'b00;
      l_selM        <= 2'b00;
      u_loadM       <= 1'b0;
      ALUResultSrcM <= 2'b00;

      ALUResultM    <= 32'b0;
      WriteDataM    <= 32'b0;
      PCTargetM     <= 32'b0;
      RdM           <= 5'b0;
      PCPlus4M      <= 32'b0;
    end 
    else begin
      // ======= 正常状态：级联滚动 =======
      RegWriteM     <= RegWriteE;
      ResultSrcM    <= ResultSrcE;
      MemWriteM     <= MemWriteE;
      s_selM        <= s_selE;
      l_selM        <= l_selE;
      u_loadM       <= u_loadE;
      ALUResultSrcM <= ALUResultSrcE;

      ALUResultM    <= ALUResultE;
      WriteDataM    <= WriteDataE;
      PCTargetM     <= PCTargetE;
      RdM           <= RdE;
      PCPlus4M      <= PCPlus4E;
    end
  end

endmodule