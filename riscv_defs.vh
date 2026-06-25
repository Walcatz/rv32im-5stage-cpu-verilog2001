// =========================================================================
// 参数化风格的头文件：riscv_defs.vh
// =========================================================================
// `include "riscv_defs.vh"

// Opcodes
parameter [6:0] OP_R_TYPE     = 7'b0110011;
parameter [6:0] OP_I_TYPE_A   = 7'b1100111;
parameter [6:0] OP_I_TYPE_B   = 7'b0000011;
parameter [6:0] OP_I_TYPE_C   = 7'b0010011;
parameter [6:0] OP_S_TYPE     = 7'b0100011;
parameter [6:0] OP_B_TYPE     = 7'b1100011;
parameter [6:0] OP_U_TYPE_A   = 7'b0110111;
parameter [6:0] OP_U_TYPE_B   = 7'b0010111;
parameter [6:0] OP_J_TYPE     = 7'b1101111;

// ALU Operations
parameter [4:0] ALU_ADD       = 5'h00;
parameter [4:0] ALU_SUB       = 5'h01;
parameter [4:0] ALU_EQ        = 5'h02;
parameter [4:0] ALU_NEQ       = 5'h03;
parameter [4:0] ALU_LESS      = 5'h04;
parameter [4:0] ALU_LESSU     = 5'h05;
parameter [4:0] ALU_GEQ       = 5'h06;
parameter [4:0] ALU_GEQU      = 5'h07;
parameter [4:0] ALU_AND       = 5'h08;
parameter [4:0] ALU_OR        = 5'h09;
parameter [4:0] ALU_XOR       = 5'h0A;
parameter [4:0] ALU_SLL       = 5'h0B;
parameter [4:0] ALU_SRL       = 5'h0C;
parameter [4:0] ALU_SRA       = 5'h0D;
parameter [4:0] ALU_LUI       = 5'h0E;
parameter [4:0] ALU_MUL       = 5'h0F;
parameter [4:0] ALU_MULH      = 5'h10;
parameter [4:0] ALU_MULHSU    = 5'h11;
parameter [4:0] ALU_MULHU     = 5'h12;
parameter [4:0] ALU_DIV       = 5'h13;
parameter [4:0] ALU_DIVU      = 5'h14;
parameter [4:0] ALU_REM       = 5'h15;
parameter [4:0] ALU_REMU      = 5'h16;
parameter [4:0] ALU_INVAL     = 5'h17;

// Immediate Type Selection
parameter [2:0] IMM_I         = 3'h0;
parameter [2:0] IMM_S         = 3'h1;
parameter [2:0] IMM_B         = 3'h2;
parameter [2:0] IMM_U         = 3'h3;
parameter [2:0] IMM_J         = 3'h4;