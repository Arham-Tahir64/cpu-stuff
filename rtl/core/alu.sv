`timescale 1ns/1ps

// Purely combinational RV32I arithmetic/logic. The future decoder selects op_i
// and supplies either rs2 or an already extended immediate as b_i.
module alu (
    input  logic [31:0] a_i,
    input  logic [31:0] b_i,
    input  logic [3:0]  op_i,
    output logic [31:0] result_o,
    output logic        invalid_o
);
    always_comb begin
        // Full defaults prevent stale results/latches for unsupported controls.
        result_o = 32'b0;
        invalid_o = 1'b0;
        case (op_i)
            rv32_pkg::ALU_ADD:  result_o = a_i + b_i;
            rv32_pkg::ALU_SUB:  result_o = a_i - b_i;
            rv32_pkg::ALU_AND:  result_o = a_i & b_i;
            rv32_pkg::ALU_OR:   result_o = a_i | b_i;
            rv32_pkg::ALU_XOR:  result_o = a_i ^ b_i;
            rv32_pkg::ALU_SLL:  result_o = a_i << b_i[4:0];
            rv32_pkg::ALU_SRL:  result_o = a_i >> b_i[4:0];
            rv32_pkg::ALU_SRA:  result_o = $signed(a_i) >>> b_i[4:0];
            rv32_pkg::ALU_SLT:  result_o = {31'b0, ($signed(a_i) < $signed(b_i))};
            rv32_pkg::ALU_SLTU: result_o = {31'b0, (a_i < b_i)};
            default:           invalid_o = 1'b1;
        endcase
    end
endmodule
