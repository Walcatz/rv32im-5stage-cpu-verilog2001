module reset_sync (
    input  wire clk,
    input  wire rst_async, // 外部输入的、不稳定的异步复位信号
    output wire rst_sync   // 同步释放后的安全复位信号，传给你的 PC 和其他模块
);

    reg rst_r1;
    reg rst_r2;

    // 异步复位，同步释放核心逻辑
    always @(posedge clk or posedge rst_async) begin
        if (rst_async) begin
            rst_r1 <= 1'b1; // 异步复位：立刻进入复位状态（高电平）
            rst_r2 <= 1'b1;
        end else begin
            rst_r1 <= 1'b0; // 同步释放：时钟沿到来时，依次清零
            rst_r2 <= rst_r1;
        end
    end

    // 使用第二级寄存器的输出作为最终的复位信号
    assign rst_sync = rst_r2;

endmodule

// // 在顶层模块中连接：
// wire sys_rst_high; // 内部高有效复位信号

// // 1. 调用同步器，并在输出时反相
// reset_bridge_top u_rst_sync (
//     .clk          (CLK),
//     .sys_rst_n    (PIN_RESET_N), // 绑定到开发板的低电平复位按键引脚
//     .rst_internal (sys_rst_high) // 输出高电平有效复位
// );

// // 2. 你的 PC 模块，天然契合高电平复位
// pc_reg u_pc_reg (
//     .CLK      (CLK),
//     .RESET    (sys_rst_high),    // 完美的异步复位、同步释放（高电平）
//     .StallF   (StallF),
//     .PCNextIF (PCNextIF),
//     .PCF      (PCF),
//     .PCPlus4F (PCPlus4F)
// );