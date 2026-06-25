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
    // 信号声明 (按照流水级划分)
    // =========================================================================

    // ------------------ 1. Fetch Stage (IF) ------------------
    wire [31:0] PCNextF;
    wire [31:0] PCF;
    wire [31:0] PCPlus4F;
    wire [31:0] InstrF;

    // ------------------ 2. Decode Stage (ID) ------------------
    wire [6:0]  Instr_6_0;
    wire [2:0]  Instr_14_12;
    wire        Instr_30;
    wire        Instr_25;
    wire [4:0]  Rs1D, Rs2D, RdD;
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
    wire [4:0]  ALUControlD;
    wire        ALUSrcD;
    wire [2:0]  ImmSrcD;

    wire [31:0] RD1D, RD2D;
    wire [31:0] ImmExtD;

    // ------------------ 3. Execute Stage (EX) ------------------
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
    wire [4:0]  Rs1E, Rs2E, RdE;
    wire [31:0] ImmExtE;
    wire [31:0] PCPlus4E;
    wire [31:0] RD1E, RD2E;

    wire [31:0] Forwarded_A_E;
    wire [31:0] WriteDataE; // 前推后的预备写入内存的数据/SrcB的输入源之一
    wire [31:0] SrcAE;
    wire [31:0] SrcBE;
    wire [31:0] ALUResultE;
    wire [31:0] PCTargetE;
    wire        BusyE;

    wire        br_predictE;
    wire [1:0]  PCSrcE;
    wire        mispredictE;

    // ------------------ 4. Memory Stage (MEM) ------------------
    wire        RegWriteM;
    wire [1:0]  ResultSrcM;
    wire        MemWriteM;
    wire [1:0]  s_selM;
    wire [1:0]  l_selM;
    wire        u_loadM;
    wire [1:0]  ALUResultSrcM;

    wire [31:0] ALUResultM;
    wire [31:0] WriteDataM;
    wire [4:0]  RdM;
    wire [31:0] PCTargetM;
    wire [31:0] PCPlus4M;

    wire [3:0]  byte_enM;
    wire [31:0] FormattedWriteDataM;

    // ------------------ 5. Writeback Stage (WB) ------------------
    wire        RegWriteW;
    wire [1:0]  ResultSrcW;
    wire [1:0]  l_selW;
    wire        u_loadW;

    wire [31:0] ProALUResultW;
    wire [31:0] ReadDataRawW;
    wire [31:0] PCTargetW;
    wire [31:0] PCPlus4W;
    wire [4:0]  RdW;

    wire [31:0] ReadDataW;  // 经过 Load Unit 格式化后的数据
    wire [31:0] ResultW;    // 最终写回寄存器堆的数据

    // ------------------ 6. Hazard Unit Control ------------------
    wire        StallF, StallD, FlushD, StallE, FlushE, FlushM;
    wire [1:0]  ForwardAE, ForwardBE;


    // =========================================================================
    // 1. 取指阶段 (FETCH STAGE)
    // =========================================================================
    
    assign imem_addr = PCF;
    assign InstrF    = imem_rdata;

    pc_reg u_pc_reg (
        .CLK      (clk),
        .RESET    (reset),
        .StallF   (StallF),
        .PCNextF (PCNextF),
        .PCF      (PCF),
        .PCPlus4F (PCPlus4F)
    );

    gshare u_gshare (
        .clk         (clk),
        .reset       (reset),
        .PCF         (PCF),
        .PCPlus4F    (PCPlus4F),
        .opF         (InstrF[6:0]),
        .PCE         (PCE),
        .PCPlus4E    (PCPlus4E),
        .PCSrcE      (PCSrcE),
        .JumpE       (JumpE),
        .JumprE      (JumprE),
        .BranchE     (BranchE),
        .br_actualE  (ALUResultE[0]), // 约定用 ALUResultE[0] 表示分支实际跳转结果
        .PCTargetE   (PCTargetE),
        .ALUResultE  (ALUResultE),
        .mispredictE (mispredictE),
        .br_predictE (br_predictE),
        .PCNextF     (PCNextF),
        .StallD      (StallD),
        .FlushD      (FlushD),
        .StallE      (StallE),
        .FlushE      (FlushE)
    );

    if_id_reg u_if_id_reg (
        .CLK          (clk),
        .StallD       (StallD),
        .FlushD       (FlushD),
        .RD           (InstrF),
        .PCF          (PCF),
        .PCPlus4F     (PCPlus4F),
        .Instr_6_0    (Instr_6_0),
        .Instr_14_12  (Instr_14_12),
        .Instr_30     (Instr_30),
        .Instr_25     (Instr_25),
        .Rs1D         (Rs1D),
        .Rs2D         (Rs2D),
        .RdD          (RdD),
        .Instr_31_7   (Instr_31_7),
        .PCD          (PCD),
        .PCPlus4D     (PCPlus4D)
    );

    // =========================================================================
    // 2. 译码阶段 (DECODE STAGE)
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
        .ALUControlD   (ALUControlD),
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
        .ALUControlD   (ALUControlD),
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
    // 3. 执行阶段 (EXECUTE STAGE)
    // =========================================================================

    // A 端前推选择 MUX
    mux3 #(.WIDTH(32)) u_forwardA_mux (
        .d0 (RD1E),
        .d1 (ResultW),
        .d2 (ALUResultM),
        .s  (ForwardAE),
        .y  (Forwarded_A_E)
    );

    // B 端前推选择 MUX (先选出写入内存的原始数据)
    mux3 #(.WIDTH(32)) u_forwardB_mux (
        .d0 (RD2E),
        .d1 (ResultW),
        .d2 (ALUResultM),
        .s  (ForwardBE),
        .y  (WriteDataE)
    );

    // 区别是寄存器值还是立即数
    mux2 #(.WIDTH(32)) u_srcB_mux (
        .d0 (WriteDataE),
        .d1 (ImmExtE),
        .s  (ALUSrcE),
        .y  (SrcBE)
    );

    // 处理极少数特殊的微架构需求，这里将 Forwarded_A_E 直接赋给 SrcAE
    assign SrcAE = Forwarded_A_E;

    alu u_alu (
        .clk        (clk),
        .reset      (reset),
        .SrcA       (SrcAE),
        .SrcB       (SrcBE),
        .ALUControl (ALUControlE),
        .BusyE      (BusyE),
        .ALUResult  (ALUResultE)
    );

    // 计算标准 B/J 类型的目标跳转地址 (PCE + ImmExtE)
    assign PCTargetE = PCE + ImmExtE;

    pc_src u_pc_src (
        .Jump       (JumpE),
        .Jumpr      (JumprE),
        .Branch     (BranchE),
        .br_taken   (ALUResultE[0]),
        .br_predict (br_predictE),
        .PCSrc      (PCSrcE),
        .mispredict (mispredictE)
    );

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
        .RegWriteM     (RegWriteM),
        .ResultSrcM    (ResultSrcM),
        .MemWriteM     (MemWriteM),
        .s_selM        (s_selM),
        .l_selM        (l_selM),
        .u_loadM       (u_loadM),
        .ALUResultSrcM (ALUResultSrcM),
        .ALUResultE    (ALUResultE),
        .WriteDataE    (WriteDataE),
        .RdE           (RdE),
        .PCTargetE     (PCTargetE),
        .PCPlus4E      (PCPlus4E),
        .ALUResultM    (ALUResultM),
        .WriteDataM    (WriteDataM),
        .RdM           (RdM),
        .PCTargetM     (PCTargetM),
        .PCPlus4M      (PCPlus4M)
    );

    // =========================================================================
    // 4. 访存阶段 (MEMORY STAGE)
    // =========================================================================

    store_unit u_store_unit (
        .MemWrite  (MemWriteM),
        .s_sel     (s_selM),
        .b_sel     (ALUResultM[1:0]),
        .RawData   (WriteDataM),
        .byte_en   (byte_enM),
        .WriteData (FormattedWriteDataM)
    );

    // 挂接外部 Data Memory 物理总线
    assign dmem_we      = MemWriteM;
    assign dmem_byte_en = byte_enM;
    assign dmem_addr    = ALUResultM;
    assign dmem_wdata   = FormattedWriteDataM;

    mem_wb_reg u_mem_wb_reg (
        .CLK           (clk),
        .RegWriteM     (RegWriteM),
        .ResultSrcM    (ResultSrcM),
        .l_selM        (l_selM),
        .u_loadM       (u_loadM),
        .RegWriteW     (RegWriteW),
        .ResultSrcW    (ResultSrcW),
        .l_selW        (l_selW),
        .u_loadW       (u_loadW),
        .ProALUResultM (ALUResultM), // 原名映射：传递访存级生成的有效计算地址
        .ReadDataM     (dmem_rdata), // 直接由外部内存吐出的原始数据
        .PCTargetM     (PCTargetM),
        .PCPlus4M      (PCPlus4M),
        .RdM           (RdM),
        .ProALUResultW (ProALUResultW),
        .ReadDataW     (ReadDataRawW),
        .PCTargetW     (PCTargetW),
        .PCPlus4W      (PCPlus4W),
        .RdW           (RdW)
    );

    // =========================================================================
    // 5. 写回阶段 (WRITEBACK STAGE)
    // =========================================================================

    load_unit u_load_unit (
        .l_sel    (l_selW),
        .bhw_sel  (ProALUResultW[1:0]),
        .u_load   (u_loadW),
        .RawData  (ReadDataRawW),
        .ReadData (ReadDataW)
    );

    // 最终写回寄存器源数据 4路选择 MUX (根据 ResultSrcW 切换)
    mux4 #(.WIDTH(32)) u_wb_result_mux (
        .d0 (ProALUResultW),
        .d1 (ReadDataW),
        .d2 (PCPlus4W),
        .d3 (PCTargetW),
        .s  (ResultSrcW),
        .y  (ResultW)
    );

    // =========================================================================
    // 6. 流水线冲突控制单元 (HAZARD UNIT)
    // =========================================================================

    hazard_unit u_hazard_unit (
        .Rs1D         (Rs1D),
        .Rs2D         (Rs2D),
        .Rs1E         (Rs1E),
        .Rs2E         (Rs2E),
        .RdE          (RdE),
        .mispredictE  (mispredictE),
        .ResultSrcE   (ResultSrcE),
        .BusyE        (BusyE),
        .RdM          (RdM),
        .RegWriteM    (RegWriteM),
        .RdW          (RdW),
        .RegWriteW    (RegWriteW),
        .StallF       (StallF),
        .StallD       (StallD),
        .FlushD       (FlushD),
        .StallE       (StallE),
        .FlushE       (FlushE),
        .FlushM       (FlushM),
        .ForwardAE    (ForwardAE),
        .ForwardBE    (ForwardBE)
    );

endmodule