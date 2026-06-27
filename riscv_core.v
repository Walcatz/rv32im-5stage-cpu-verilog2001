`include "riscv_defs.vh"

module riscv_core
(
    input  wire        clk,
    input  wire        reset,

    // Instruction Memory Interface
    output wire [31:0] imem_addr,
    input  wire [31:0] imem_rdata,

    // Data Memory Interface
    output wire        dmem_we,
    output wire [3:0]  dmem_byte_en,
    output wire [31:0] dmem_addr,
    output wire [31:0] dmem_wdata,
    input  wire [31:0] dmem_rdata
);

    // =========================================================================
    // 内部全局连线信号定义
    // =========================================================================
    wire rst_sync;

    // Hazard Unit 控制大闸
    wire StallF, StallD, FlushD, StallE, FlushE, FlushM;
    wire [1:0] ForwardAE, ForwardBE;

    // Fetch (IF) 级信号
    wire [31:0] PCNextF;
    wire [31:0] PCF;
    wire [31:0] PCPlus4F;
    wire [6:0]  opF = imem_rdata[6:0];

    // Decode (ID) 级信号
    wire [6:0]  Instr_6_0;
    wire [2:0]  Instr_14_12;
    wire        Instr_30;
    wire        Instr_25;
    wire [4:0]  Rs1D;
    wire [4:0]  Rs2D;
    wire [4:0]  RdD;
    wire [24:0] Instr_31_7;
    wire [31:0] PCD;
    wire [31:0] PCPlus4D;

    wire        RegWriteD;
    wire [1:0]  ResultSrcD;
    wire        MemWriteD;
    wire [1:0]  s_selD;
    wire [1:0]  l_selD;
    wire        u_loadD;
    wire        JumpD;
    wire        JumprD;
    wire        BranchD;
    wire [1:0]  ALUResultsSrcD;
    wire [4:0]  ALUControlID;
    wire        ALUSrcD;
    wire [2:0]  ImmSrcD;

    wire [31:0] RD1D;
    wire [31:0] RD2D;
    wire [31:0] ImmExtD;

    // Execute (EX) 级信号
    wire        RegWriteE;
    wire [1:0]  ResultSrcE;
    wire        MemWriteE;
    wire [1:0]  s_selE;
    wire [1:0]  l_selE;
    wire        u_loadE;
    wire        JumpE;
    wire        JumprE;
    wire        BranchE;
    wire [1:0]  ALUResultsSrcE;
    wire [4:0]  ALUControlE;
    wire        ALUSrcE;

    wire [31:0] PCE;
    wire [4:0]  Rs1E;
    wire [4:0]  Rs2E;
    wire [4:0]  RdE;
    wire [31:0] ImmExtE;
    wire [31:0] PCPlus4E;
    wire [31:0] RD1E;
    wire [31:0] RD2E;

    wire [31:0] SrcAE;
    wire [31:0] WriteDataE;
    wire [31:0] SrcBE;
    wire [31:0] ALUResultE;
    wire        BusyE;
    
    wire [31:0] PCTargetE = PCE + ImmExtE;
    wire        br_actualE = ALUResultE[0];
    wire        br_predictE;
    wire [1:0]  PCSrcE;
    wire        mispredictE;

    // Memory (MEM) 级信号
    wire        RegWriteM;
    wire [1:0]  ResultSrcM;
    wire        MemWriteM;
    wire [1:0]  s_selM;
    wire [1:0]  l_selM;
    wire        u_loadM;
    wire [1:0]  ALUResultSrcM;

    wire [31:0] ALUResultM;
    wire [31:0] WriteDataM;
    wire [31:0] PCTargetM;
    wire [4:0]  RdM;
    wire [31:0] PCPlus4M;
    wire [31:0] ProALUResultM;

    // Writeback (WB) 级信号
    wire        RegWriteW;
    wire [1:0]  ResultSrcW;
    wire [1:0]  l_selW;
    wire        u_loadW;

    wire [31:0] ProALUResultW;
    wire [31:0] ReadDataW;
    wire [31:0] PCTargetW;
    wire [4:0]  RdW;
    wire [31:0] PCPlus4W;
    
    wire [31:0] ProReadDataW;
    wire [31:0] ResultW;

    // =========================================================================
    // 全局基础部件：复位同步器
    // =========================================================================
    reset_sync u_reset_sync (
        .clk       (clk),
        .rst_async (reset),
        .rst_sync  (rst_sync)
    );

    // =========================================================================
    // FETCH (IF) 取指阶段
    // =========================================================================
    pc_reg u_pc_reg (
        .CLK      (clk),
        .RESET    (rst_sync),
        .StallF   (StallF),
        .PCNextF  (PCNextF),
        .PCF      (PCF),
        .PCPlus4F (PCPlus4F)
    );

    assign imem_addr = PCF;

    // 级联高超前 Gshare 分支预测器
    gshare u_gshare (
        .clk          (clk),
        .reset        (rst_sync),
        .PCF          (PCF),
        .PCPlus4F     (PCPlus4F),
        .opF          (opF),
        .PCE          (PCE),
        .PCPlus4E     (PCPlus4E),
        .PCSrcE       (PCSrcE),
        .JumpE        (JumpE),
        .JumprE       (JumprE),
        .BranchE      (BranchE),
        .br_actualE   (br_actualE),
        .PCTargetE    (PCTargetE),
        .ALUResultE   (ALUResultE),
        .mispredictE  (mispredictE),
        .br_predictE  (br_predictE),
        .PCNextF      (PCNextF),
        .StallD       (StallD),
        .FlushD       (FlushD),
        .StallE       (StallE),
        .FlushE       (FlushE)
    );

    // =========================================================================
    // IF/ID 段间寄存器
    // =========================================================================
    if_id_reg u_if_id_reg (
        .CLK         (clk),
        .StallD      (StallD),
        .FlushD      (FlushD),
        .RD          (imem_rdata),
        .PCF         (PCF),
        .PCPlus4F    (PCPlus4F),
        .Instr_6_0   (Instr_6_0),
        .Instr_14_12 (Instr_14_12),
        .Instr_30    (Instr_30),
        .Instr_25    (Instr_25),
        .Rs1D        (Rs1D),
        .Rs2D        (Rs2D),
        .RdD         (RdD),
        .Instr_31_7  (Instr_31_7),
        .PCD         (PCD),
        .PCPlus4D    (PCPlus4D)
    );

    // =========================================================================
    // DECODE (ID) 译码阶段
    // =========================================================================
    ctrl_unit u_ctrl_unit (
        .op             (Instr_6_0),
        .funct3         (Instr_14_12),
        .funct7_5       (Instr_30),
        .funct7_0       (Instr_25),
        .RegWriteD      (RegWriteD),
        .ResultSrcD     (ResultSrcD),
        .MemWriteD      (MemWriteD),
        .s_selD         (s_selD),
        .l_selD         (l_selD),
        .u_loadD        (u_loadD),
        .JumpD          (JumpD),
        .JumprD         (JumprD),
        .BranchD        (BranchD),
        .ALUResultsSrcD (ALUResultsSrcD),
        .ALUControlID   (ALUControlID),
        .ALUSrcD        (ALUSrcD),
        .ImmSrcD        (ImmSrcD)
    );

    reg_file u_reg_file (
        .CLK (clk),
        .WE3 (RegWriteW),
        .A1  (Rs1D),
        .A2  (Rs2D),
        .A3  (RdW),
        .WD3 (ResultW),
        .RD1 (RD1D),
        .RD2 (RD2D)
    );

    extend u_extend (
        .i_imm  (Instr_31_7),
        .ImmSrc (ImmSrcD),
        .ImmExt (ImmExtD)
    );

    // =========================================================================
    // ID/EX 段间寄存器
    // =========================================================================
    id_ex_reg u_id_ex_reg (
        .CLK            (clk),
        .StallE         (StallE),
        .FlushE         (FlushE),
        .RegWriteD      (RegWriteD),
        .ResultSrcD     (ResultSrcD),
        .MemWriteD      (MemWriteD),
        .s_selD         (s_selD),
        .l_selD         (l_selD),
        .u_loadD        (u_loadD),
        .JumpD          (JumpD),
        .JumprD         (JumprD),
        .BranchD        (BranchD),
        .ALUResultsSrcD (ALUResultsSrcD),
        .ALUControlD    (ALUControlID),
        .ALUSrcD        (ALUSrcD),
        .PCD            (PCD),
        .Rs1D           (Rs1D),
        .Rs2D           (Rs2D),
        .RdD            (RdD),
        .ImmExtD        (ImmExtD),
        .PCPlus4D       (PCPlus4D),
        .RD1D           (RD1D),
        .RD2D           (RD2D),
        .RegWriteE      (RegWriteE),
        .ResultSrcE     (ResultSrcE),
        .MemWriteE      (MemWriteE),
        .s_selE         (s_selE),
        .l_selE         (l_selE),
        .u_loadE        (u_loadE),
        .JumpE          (JumpE),
        .JumprE         (JumprE),
        .BranchE        (BranchE),
        .ALUResultsSrcE (ALUResultsSrcE),
        .ALUControlE    (ALUControlE),
        .ALUSrcE        (ALUSrcE),
        .PCE            (PCE),
        .Rs1E           (Rs1E),
        .Rs2E           (Rs2E),
        .RdE            (RdE),
        .ImmExtE        (ImmExtE),
        .PCPlus4E       (PCPlus4E),
        .RD1E           (RD1E),
        .RD2E           (RD2E)
    );

    // =========================================================================
    // EXECUTE (EX) 执行阶段
    // =========================================================================
    
    // 前推多路选择器
    mux3 u_SrcA (
        .d0 (RD1E),
        .d1 (ResultW),
        .d2 (ProALUResultM),
        .s  (ForwardAE),
        .y  (SrcAE)
    );

    mux3 u_SrcB0 (
        .d0 (RD2E),
        .d1 (ResultW),
        .d2 (ProALUResultM),
        .s  (ForwardBE),
        .y  (WriteDataE)
    );

    mux2 u_SrcB1 (
        .d0 (WriteDataE),
        .d1 (ImmExtE),
        .s  (ALUSrcE),
        .y  (SrcBE)
    );

    // 执行单元组件 ALU
    alu u_alu (
        .clk        (clk),
        .reset      (rst_sync),
        .SrcA       (SrcAE),
        .SrcB       (SrcBE),
        .ALUControl (ALUControlE),
        .BusyE      (BusyE),
        .ALResult   (ALUResultE)
    );

    // 预测失败判定及跳转源路由生成器
    pc_src u_pc_src (
        .Jump       (JumpE),
        .Jumpr      (JumprE),
        .Branch     (BranchE),
        .br_taken   (br_actualE),
        .br_predict (br_predictE),
        .PCSrc      (PCSrcE),
        .mispredict (mispredictE)
    );

    // =========================================================================
    // EX/MEM 段间寄存器
    // =========================================================================
    ex_mem_reg u_ex_mem_reg (
        .CLK           (clk),
        .FlushM        (FlushM),
        .RegWriteE     (RegWriteE),
        .ResultSrcE    (ResultSrcE),
        .MemWriteE     (MemWriteE),
        .s_selE        (s_selE),
        .l_selE        (l_selE),
        .u_loadE       (u_loadE),
        .ALUResultSrcE (ALUResultsSrcE),
        .ALUResultE    (ALUResultE),
        .WriteDataE    (WriteDataE),
        .PCTargetE     (PCTargetE),
        .RdE           (RdE),
        .PCPlus4E      (PCPlus4E),
        .RegWriteM     (RegWriteM),
        .ResultSrcM    (ResultSrcM),
        .MemWriteM     (MemWriteM),
        .s_selM        (s_selM),
        .l_selM        (l_selM),
        .u_loadM       (u_loadM),
        .ALUResultSrcM (ALUResultSrcM),
        .ALUResultM    (ALUResultM),
        .WriteDataM    (WriteDataM),
        .PCTargetM     (PCTargetM),
        .RdM           (RdM),
        .PCPlus4M      (PCPlus4M)
    );

    // =========================================================================
    // MEMORY (MEM) 访存阶段
    // =========================================================================
    
    // Store 格式化组件
    store_unit u_store_unit (
        .MemWrite  (MemWriteM),
        .s_sel     (s_selM),
        .b_sel     (ALUResultM[1:0]),
        .RawData   (WriteDataM),
        .byte_en   (dmem_byte_en),
        .WriteData (dmem_wdata)
    );

    assign dmem_we   = MemWriteM;
    assign dmem_addr = ALUResultM;

    // MEM 级直通选择器
    mux3 u_alu_result (
        .d0 (ALUResultM),
        .d1 (PCPlus4M),
        .d2 (PCTargetM),
        .s  (ALUResultSrcM),
        .y  (ProALUResultM)
    );

    // =========================================================================
    // MEM/WB 段间寄存器
    // =========================================================================
    mem_wb_reg u_mem_wb_reg (
        .CLK           (clk),
        .RegWriteM     (RegWriteM),
        .ResultSrcM    (ResultSrcM),
        .l_selM        (l_selM),
        .u_loadM       (u_loadM),
        .ProALUResultM (ProALUResultM),
        .ReadDataM     (dmem_rdata),
        .PCTargetM     (PCTargetM),
        .RdM           (RdM),
        .PCPlus4M      (PCPlus4M),
        .RegWriteW     (RegWriteW),
        .ResultSrcW    (ResultSrcW),
        .l_selW        (l_selW),
        .u_loadW       (u_loadW),
        .ProALUResultW (ProALUResultW),
        .ReadDataW     (ReadDataW),
        .PCTargetW     (PCTargetW),
        .RdW           (RdW),
        .PCPlus4W      (PCPlus4W)
    );

    // =========================================================================
    // WRITEBACK (WB) 写回阶段
    // =========================================================================
    
    // Load 格式化对齐组件
    load_unit u_load_unit (
        .l_sel    (l_selW),
        .bhw_sel  (ProALUResultW[1:0]),
        .u_load   (u_loadW),
        .RawData  (ReadDataW),
        .ReadData (ProReadDataW)
    );

    // 最终写回结果选择器 MUX
    mux4 u_result (
        .d0 (ProALUResultW),
        .d1 (ProReadDataW),
        .d2 (PCPlus4W),
        .d3 (PCTargetW),
        .s  (ResultSrcW),
        .y  (ResultW)
    );

    // =========================================================================
    // GLOBAL CONTROLLER: 冒险控制单元 (Hazard Unit)
    // =========================================================================
    hazard_unit u_hazard_unit (
        .Rs1D        (Rs1D),
        .Rs2D        (Rs2D),
        .Rs1E        (Rs1E),
        .Rs2E        (Rs2E),
        .RdE         (RdE),
        .mispredictE (mispredictE),
        .ResultSrcE  (ResultSrcE),
        .BusyE       (BusyE),
        .RdM         (RdM),
        .RegWriteM   (RegWriteM),
        .RdW         (RdW),
        .RegWriteW   (RegWriteW),
        .StallF      (StallF),
        .StallD      (StallD),
        .FlushD      (FlushD),
        .StallE      (StallE),
        .FlushE      (FlushE),
        .FlushM      (FlushM),
        .ForwardAE   (ForwardAE),
        .ForwardBE   (ForwardBE)
    );

endmodule