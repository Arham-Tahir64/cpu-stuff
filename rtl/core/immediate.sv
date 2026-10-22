`timescale 1ns/1ps

// Pure field extraction. The future decoder validates instructions and selects
// format_i. B/J outputs already include the low zero bit: they are byte offsets.
module immediate (
    input  logic [31:0] instr_i,
    input  logic [2:0]  format_i,
    output logic [31:0] imm_o,
    output logic        invalid_o
);
    // Opcode bits do not participate in any immediate. Explicitly mark that
    // intentional non-use while keeping lint checks on every other input bit.
    logic unused_opcode;
    assign unused_opcode = ^instr_i[6:0];

    always_comb begin
        imm_o = 32'b0;
        invalid_o = 1'b0;
        case (format_i)
            rv32_pkg::IMM_NONE: imm_o = 32'b0;
            rv32_pkg::IMM_I:    imm_o = {{20{instr_i[31]}}, instr_i[31:20]};
            rv32_pkg::IMM_S:    imm_o = {{20{instr_i[31]}}, instr_i[31:25], instr_i[11:7]};
            rv32_pkg::IMM_B:    imm_o = {{19{instr_i[31]}}, instr_i[31], instr_i[7],
                                        instr_i[30:25], instr_i[11:8], 1'b0};
            rv32_pkg::IMM_U:    imm_o = {instr_i[31:12], 12'b0};
            rv32_pkg::IMM_J:    imm_o = {{11{instr_i[31]}}, instr_i[31], instr_i[19:12],
                                        instr_i[20], instr_i[30:21], 1'b0};
            default:           invalid_o = 1'b1;
        endcase
    end
endmodule
