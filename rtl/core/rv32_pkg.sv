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
endpackage
