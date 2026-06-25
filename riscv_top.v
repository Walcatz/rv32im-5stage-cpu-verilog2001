module riscv_top
(
    input wire clk,
    input wire reset
);

    // =========================================================================
    // 内部连线信号声明
    // =========================================================================
    
    // 指令存储器接口线 (Instruction Memory Interface)
    wire [31:0] imem_addr;
    wire [31:0] imem_rdata;

    // 数据存储器接口线 (Data Memory Interface)
    wire        dmem_we;
    wire [3:0]  dmem_byte_en;
    wire [31:0] dmem_addr;
    wire [31:0] dmem_wdata;
    wire [31:0] dmem_rdata;

    // =========================================================================
    // 1. RISC-V 处理器核实例化
    // =========================================================================
    riscv_core u_riscv_core (
        .clk          (clk),
        .reset        (reset),

        // Instruction Memory Interface
        .imem_addr    (imem_addr),
        .imem_rdata   (imem_rdata),

        // Data Memory Interface
        .dmem_we      (dmem_we),
        .dmem_byte_en (dmem_byte_en),
        .dmem_addr    (dmem_addr),
        .dmem_wdata   (dmem_wdata),
        .dmem_rdata   (dmem_rdata)
    );

    // =========================================================================
    // 2. 指令存储器实例化 (Instruction ROM / RAM)
    // =========================================================================
    // 默认保持你声明的 14 位物理地址和 4096 深度参数
    instruction_mem #(
        .ADDR_WIDTH (14),
        .MEM_DEPTH  (4096)
    ) u_instruction_mem (
        .A  (imem_addr),
        .RD (imem_rdata)
    );

    // =========================================================================
    // 3. 数据存储器实例化 (Data RAM)
    // =========================================================================
    data_mem #(
        .ADDR_WIDTH (14),
        .MEM_DEPTH  (4096)
    ) u_data_mem (
        .CLK (clk),
        .WE  (dmem_we),
        .A   (dmem_addr),
        .BE  (dmem_byte_en),
        .WD  (dmem_wdata),
        .RD  (dmem_rdata)
    );

endmodule