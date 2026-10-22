`timescale 1ns/1ps

// Internal control encodings, not RISC-V instruction opcodes. Keep this package
// before its consumers in rtl/files.f. Enums name the shared control encodings;
// module ports remain plain bit vectors so unsupported values can be tested.
package rv32_pkg;
    typedef enum logic [3:0] {
        ALU_ADD  = 4'h0,
        ALU_SUB  = 4'h1,
        ALU_AND  = 4'h2,
        ALU_OR   = 4'h3,
        ALU_XOR  = 4'h4,
        ALU_SLL  = 4'h5,
        ALU_SRL  = 4'h6,
        ALU_SRA  = 4'h7,
        ALU_SLT  = 4'h8,
        ALU_SLTU = 4'h9
    } alu_op_t;

    // Immediate-format selectors are internal controls, not instruction bits.
    typedef enum logic [2:0] {
        IMM_NONE = 3'd0,
        IMM_I    = 3'd1,
        IMM_S    = 3'd2,
        IMM_B    = 3'd3,
        IMM_U    = 3'd4,
        IMM_J    = 3'd5
    } imm_format_t;

    typedef enum logic [1:0] { ALU_A_RS1 = 2'd0, ALU_A_PC = 2'd1, ALU_A_ZERO = 2'd2 } alu_a_sel_t;
    typedef enum logic [1:0] { WB_ALU = 2'd0, WB_LOAD = 2'd1, WB_PC4 = 2'd2 } wb_sel_t;
    typedef enum logic [1:0] { MEM_BYTE = 2'd0, MEM_HALF = 2'd1, MEM_WORD = 2'd2 } mem_size_t;
    typedef enum logic [2:0] {
        BR_NONE = 3'd0, BR_EQ = 3'd1, BR_NE = 3'd2, BR_LT = 3'd3,
        BR_GE = 3'd4, BR_LTU = 3'd5, BR_GEU = 3'd6
    } branch_t;
    typedef enum logic [1:0] { JUMP_NONE = 2'd0, JUMP_JAL = 2'd1, JUMP_JALR = 2'd2 } jump_t;
    typedef enum logic [1:0] { SYS_NONE = 2'd0, SYS_ECALL = 2'd1, SYS_EBREAK = 2'd2 } system_t;
endpackage
