module instruction_mem #(
    parameter ADDR_WIDTH = 14,          // 物理地址线宽，对应16KB寻址空间
    parameter MEM_DEPTH  = 4096          // 存储阵列深度（4096个32-bit字）
)(
    input  wire [31:0]           A,      // [Address] 来自CPU的32位程序计数器(PC)地址
    output wire [31:0]           RD      // [Read Data] 输出给CPU的32位目标机器指令(Instr)
);

    // 32位宽的存储器阵列，深度为 MEM_DEPTH
    reg [31:0] rom [0:MEM_DEPTH-1];

    // 将32位字节地址裁剪并转换为12位字阵列索引 (抛弃低2位对齐位)
    wire [ADDR_WIDTH-3:0] word_addr = A[ADDR_WIDTH-1:2];

    // 异步读：地址 A 改变，指令 RD 立刻输出
    // 若地址越界，默认输出 NOP 指令 (addi x0, x0, 0 -> 32'h00000013) 防止跑飞
    assign RD = (word_addr < MEM_DEPTH) ? rom[word_addr] : 32'h00000013;

    // 仿真初始化：从外部文本文件加载16进制机器码
    initial begin
        $readmemh("inst_rom.txt", rom);
    end

endmodule