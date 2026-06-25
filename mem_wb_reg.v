module mem_wb_reg
(
  input  wire        CLK,

  // Control Signals Input (MEM 级)
  input  wire        RegWriteM,
  input  wire [1:0]  ResultSrcM,
  input  wire [1:0]  l_selM,
  input  wire        u_loadM,

  // Control Signals Output (WB 级)
  output reg         RegWriteW,
  output reg  [1:0]  ResultSrcW,
  output reg  [1:0]  l_selW,
  output reg         u_loadW,

  // Data and Addresses Input (来自 MEM 级的结果和地址)
  input  wire [31:0] ProALUResultM,
  input  wire [31:0] ReadDataM,
  input  wire [31:0] PCTargetM,
  input  wire [4:0]  RdM,
  input  wire [31:0] PCPlus4M,

  // Data and Addresses Output (向写回级倾泻数据)
  output reg  [31:0] ProALUResultW,
  output reg  [31:0] ReadDataW,
  output reg  [31:0] PCTargetW,
  output reg  [4:0]  RdW,
  output reg  [31:0] PCPlus4W
);

  always @(posedge CLK) begin
    // 控制信号向前滚动更新
    RegWriteW     <= RegWriteM;
    ResultSrcW    <= ResultSrcM;
    l_selW        <= l_selM;
    u_loadW       <= u_loadM;

    // 数据与地址向前滚动更新
    ProALUResultW <= ProALUResultM;
    ReadDataW     <= ReadDataM;
    PCTargetW     <= PCTargetM;
    RdW           <= RdM;
    PCPlus4W      <= PCPlus4M;
  end

endmodule