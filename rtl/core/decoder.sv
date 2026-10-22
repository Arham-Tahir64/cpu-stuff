`timescale 1ns/1ps

// RV32I legality and control intents only. No clock, execution or side effects.
// Raw register fields are always exposed; *_used_o qualify operand consumption.
module decoder (
    input  logic [31:0] instr_i,
    output logic [4:0]  rs1_addr_o,
    output logic [4:0]  rs2_addr_o,
    output logic [4:0]  rd_addr_o,
    output logic        illegal_o,
    output logic        reg_write_o,
    output logic        rs1_used_o,
    output logic        rs2_used_o,
    output logic [3:0]  alu_op_o,
    output logic [1:0]  alu_a_sel_o,
    output logic        alu_b_imm_o,
    output logic [2:0]  imm_format_o,
    output logic [1:0]  wb_sel_o,
    output logic        mem_read_o,
    output logic        mem_write_o,
    output logic [1:0]  mem_size_o,
    output logic        load_unsigned_o,
    output logic [2:0]  branch_o,
    output logic [1:0]  jump_o,
    output logic        fence_o,
    output logic [1:0]  system_o
);
    assign rs1_addr_o = instr_i[19:15];
    assign rs2_addr_o = instr_i[24:20];
    assign rd_addr_o = instr_i[11:7];

    always_comb begin
        // All invalid paths preserve this complete, deterministic safe control.
        illegal_o = 1'b1;
        reg_write_o = 1'b0;
        rs1_used_o = 1'b0;
        rs2_used_o = 1'b0;
        alu_op_o = rv32_pkg::ALU_ADD;
        alu_a_sel_o = rv32_pkg::ALU_A_RS1;
        alu_b_imm_o = 1'b0;
        imm_format_o = rv32_pkg::IMM_NONE;
        wb_sel_o = rv32_pkg::WB_ALU;
        mem_read_o = 1'b0;
        mem_write_o = 1'b0;
        mem_size_o = rv32_pkg::MEM_BYTE;
        load_unsigned_o = 1'b0;
        branch_o = rv32_pkg::BR_NONE;
        jump_o = rv32_pkg::JUMP_NONE;
        fence_o = 1'b0;
        system_o = rv32_pkg::SYS_NONE;

        // Check all seven opcode bits, including the 32-bit instruction suffix.
        case (instr_i[6:0])
            7'h37: begin // LUI: zero + U immediate
                illegal_o = 1'b0;
                reg_write_o = 1'b1;
                alu_a_sel_o = rv32_pkg::ALU_A_ZERO;
                alu_b_imm_o = 1'b1;
                imm_format_o = rv32_pkg::IMM_U;
            end
            7'h17: begin // AUIPC: instruction PC + U immediate
                illegal_o = 1'b0;
                reg_write_o = 1'b1;
                alu_a_sel_o = rv32_pkg::ALU_A_PC;
                alu_b_imm_o = 1'b1;
                imm_format_o = rv32_pkg::IMM_U;
            end
            7'h6f: begin // JAL: ALU calculates target, separate PC+4 writeback
                illegal_o = 1'b0;
                reg_write_o = 1'b1;
                alu_a_sel_o = rv32_pkg::ALU_A_PC;
                alu_b_imm_o = 1'b1;
                imm_format_o = rv32_pkg::IMM_J;
                wb_sel_o = rv32_pkg::WB_PC4;
                jump_o = rv32_pkg::JUMP_JAL;
            end
            7'h67: begin // JALR; core clears target bit0 after addition
                if (instr_i[14:12] == 3'b000) begin
                    illegal_o = 1'b0;
                    reg_write_o = 1'b1;
                    rs1_used_o = 1'b1;
                    alu_b_imm_o = 1'b1;
                    imm_format_o = rv32_pkg::IMM_I;
                    wb_sel_o = rv32_pkg::WB_PC4;
                    jump_o = rv32_pkg::JUMP_JALR;
                end
            end
            7'h63: begin
                case (instr_i[14:12])
                    3'b000: begin illegal_o = 1'b0; branch_o = rv32_pkg::BR_EQ; end
                    3'b001: begin illegal_o = 1'b0; branch_o = rv32_pkg::BR_NE; end
                    3'b100: begin illegal_o = 1'b0; branch_o = rv32_pkg::BR_LT; end
                    3'b101: begin illegal_o = 1'b0; branch_o = rv32_pkg::BR_GE; end
                    3'b110: begin illegal_o = 1'b0; branch_o = rv32_pkg::BR_LTU; end
                    3'b111: begin illegal_o = 1'b0; branch_o = rv32_pkg::BR_GEU; end
                    default: begin end
                endcase
                if (!illegal_o) begin
                    rs1_used_o = 1'b1;
                    rs2_used_o = 1'b1;
                    alu_a_sel_o = rv32_pkg::ALU_A_PC;
                    alu_b_imm_o = 1'b1;
                    imm_format_o = rv32_pkg::IMM_B;
                end
            end
            7'h03: begin
                case (instr_i[14:12])
                    3'b000: begin illegal_o = 1'b0; mem_size_o = rv32_pkg::MEM_BYTE; end
                    3'b001: begin illegal_o = 1'b0; mem_size_o = rv32_pkg::MEM_HALF; end
                    3'b010: begin illegal_o = 1'b0; mem_size_o = rv32_pkg::MEM_WORD; end
                    3'b100: begin
                        illegal_o = 1'b0; mem_size_o = rv32_pkg::MEM_BYTE; load_unsigned_o = 1'b1;
                    end
                    3'b101: begin
                        illegal_o = 1'b0; mem_size_o = rv32_pkg::MEM_HALF; load_unsigned_o = 1'b1;
                    end
                    default: begin end
                endcase
                if (!illegal_o) begin
                    // Do not suppress memory reads when rd=x0.
                    reg_write_o = 1'b1;
                    rs1_used_o = 1'b1;
                    alu_b_imm_o = 1'b1;
                    imm_format_o = rv32_pkg::IMM_I;
                    wb_sel_o = rv32_pkg::WB_LOAD;
                    mem_read_o = 1'b1;
                end
            end
            7'h23: begin
                case (instr_i[14:12])
                    3'b000: begin illegal_o = 1'b0; mem_size_o = rv32_pkg::MEM_BYTE; end
                    3'b001: begin illegal_o = 1'b0; mem_size_o = rv32_pkg::MEM_HALF; end
                    3'b010: begin illegal_o = 1'b0; mem_size_o = rv32_pkg::MEM_WORD; end
                    default: begin end
                endcase
                if (!illegal_o) begin
                    rs1_used_o = 1'b1;
                    rs2_used_o = 1'b1;
                    alu_b_imm_o = 1'b1;
                    imm_format_o = rv32_pkg::IMM_S;
                    mem_write_o = 1'b1;
                end
            end
            7'h13: begin
                case (instr_i[14:12])
                    3'b000: begin illegal_o = 1'b0; alu_op_o = rv32_pkg::ALU_ADD; end
                    3'b010: begin illegal_o = 1'b0; alu_op_o = rv32_pkg::ALU_SLT; end
                    3'b011: begin illegal_o = 1'b0; alu_op_o = rv32_pkg::ALU_SLTU; end
                    3'b100: begin illegal_o = 1'b0; alu_op_o = rv32_pkg::ALU_XOR; end
                    3'b110: begin illegal_o = 1'b0; alu_op_o = rv32_pkg::ALU_OR; end
                    3'b111: begin illegal_o = 1'b0; alu_op_o = rv32_pkg::ALU_AND; end
                    3'b001: begin
                        if (instr_i[31:25] == 7'h00) begin
                            illegal_o = 1'b0; alu_op_o = rv32_pkg::ALU_SLL;
                        end
                    end
                    3'b101: begin
                        case (instr_i[31:25])
                            7'h00: begin illegal_o = 1'b0; alu_op_o = rv32_pkg::ALU_SRL; end
                            7'h20: begin illegal_o = 1'b0; alu_op_o = rv32_pkg::ALU_SRA; end
                            default: begin end
                        endcase
                    end
                    default: begin end
                endcase
                if (!illegal_o) begin
                    reg_write_o = 1'b1;
                    rs1_used_o = 1'b1;
                    alu_b_imm_o = 1'b1;
                    imm_format_o = rv32_pkg::IMM_I;
                end
            end
            7'h33: begin
                case ({instr_i[31:25], instr_i[14:12]})
                    10'h000: begin illegal_o = 1'b0; alu_op_o = rv32_pkg::ALU_ADD; end
                    10'h100: begin illegal_o = 1'b0; alu_op_o = rv32_pkg::ALU_SUB; end
                    10'h001: begin illegal_o = 1'b0; alu_op_o = rv32_pkg::ALU_SLL; end
                    10'h002: begin illegal_o = 1'b0; alu_op_o = rv32_pkg::ALU_SLT; end
                    10'h003: begin illegal_o = 1'b0; alu_op_o = rv32_pkg::ALU_SLTU; end
                    10'h004: begin illegal_o = 1'b0; alu_op_o = rv32_pkg::ALU_XOR; end
                    10'h005: begin illegal_o = 1'b0; alu_op_o = rv32_pkg::ALU_SRL; end
                    10'h105: begin illegal_o = 1'b0; alu_op_o = rv32_pkg::ALU_SRA; end
                    10'h006: begin illegal_o = 1'b0; alu_op_o = rv32_pkg::ALU_OR; end
                    10'h007: begin illegal_o = 1'b0; alu_op_o = rv32_pkg::ALU_AND; end
                    default: begin end
                endcase
                if (!illegal_o) begin
                    reg_write_o = 1'b1;
                    rs1_used_o = 1'b1;
                    rs2_used_o = 1'b1;
                end
            end
            7'h0f: begin
                // Base RV32I ignores rd/rs1 and reserved fm/pred/succ settings.
                // The serialized core implements all these as full FENCE.
                if (instr_i[14:12] == 3'b000) begin
                    illegal_o = 1'b0;
                    fence_o = 1'b1;
                end
            end
            7'h73: begin
                case (instr_i)
                    32'h00000073: begin illegal_o = 1'b0; system_o = rv32_pkg::SYS_ECALL; end
                    32'h00100073: begin illegal_o = 1'b0; system_o = rv32_pkg::SYS_EBREAK; end
                    default: begin end
                endcase
            end
            default: begin end
        endcase
    end
endmodule
