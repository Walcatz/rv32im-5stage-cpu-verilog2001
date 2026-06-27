`timescale 1ns/1ps

module riscv_top_tb;

    reg clk   = 1'b1;
    reg reset = 1'b1;

    always #10 clk = ~clk;

    integer file;
    integer i;

    initial begin
        $dumpfile("riscv_top_tb.vcd");
        $dumpvars(0, riscv_top_tb);

        repeat (10) @(posedge clk);
        reset <= 1'b0;

        repeat (20000) @(posedge clk);

        file = $fopen("d_mem_final.hex", "w");
        if (file == 0) begin
            $display("ERROR: could not open d_mem_final.hex for writing");
            $finish;
        end

        // 直接在循环内部进行字拼接与打印
        for (i = 0; i < 128; i = i + 1) begin
            $fdisplay(file, "%08X", {
                u_DUT.u_data_mem.ram3[i],
                u_DUT.u_data_mem.ram2[i],
                u_DUT.u_data_mem.ram1[i],
                u_DUT.u_data_mem.ram0[i]
            });
        end

        $fclose(file);
        $display("DMEM dump complete!");
        $finish;
    end

    riscv_top u_DUT (
        .clk   (clk),
        .reset (reset)
    );

endmodule