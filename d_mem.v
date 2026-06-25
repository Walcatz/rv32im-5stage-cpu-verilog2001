module data_mem #(
    parameter ADDR_WIDTH = 14,          // 物理地址线宽，对应16KB寻址空间
    parameter MEM_DEPTH  = 4096          // 存储阵列深度（4096个32-bit字）
)(
    input  wire                  CLK,    // [CLK] 写时钟
    input  wire                  WE,     // [Write Enable] 总写使能信号（通常来自 Control Unit 的 MemWriteM）
    input  wire [31:0]           A,      // [Address] 来自CPU的32位访存物理地址
    input  wire [3:0]            BE,     // [Byte Enable] 4位字节使能，控制具体哪个Byte通道写入（由 store_unit 生成）
    input  wire [31:0]           WD,     // [Write Data] 准备写入的数据（已由 store_unit 处理好对齐）
    output wire [31:0]           RD      // [Read Data] 读出的32位原始数据字（后级由 load_unit 处理）
);

    // 拆分为4个独立的 8-bit 字节阵列
    reg [7:0] ram0 [0:MEM_DEPTH-1];
    reg [7:0] ram1 [0:MEM_DEPTH-1];
    reg [7:0] ram2 [0:MEM_DEPTH-1];
    reg [7:0] ram3 [0:MEM_DEPTH-1];

    // 将32位字节地址裁剪并转换为12位字阵列索引
    wire [ADDR_WIDTH-3:0] word_addr = A[ADDR_WIDTH-1:2];

    // 同步写：必须在全局写使能 WE 有效，且对应字节使能 BE[i] 有效时才写入数据
    always @(posedge CLK) begin
        if (WE && (word_addr < MEM_DEPTH)) begin
            if (BE[0]) ram0[word_addr] <= WD[7:0];
            if (BE[1]) ram1[word_addr] <= WD[15:8];
            if (BE[2]) ram2[word_addr] <= WD[23:16];
            if (BE[3]) ram3[word_addr] <= WD[31:24];
        end
    end

    // 异步读：直接拼接4个字节阵列，输出完整的32位字
    wire [31:0] ram_data = {ram3[word_addr], ram2[word_addr], ram1[word_addr], ram0[word_addr]};

    assign RD = (word_addr < MEM_DEPTH) ? 
                ram_data : 
                32'b0; // 越界访问返回0
                
endmodule