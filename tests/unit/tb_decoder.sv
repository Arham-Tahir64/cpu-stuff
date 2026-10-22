`timescale 1ns/1ps

module tb_decoder;
    logic [31:0] instr_i = 32'b0;
    logic [4:0] rs1_addr_o, rs2_addr_o, rd_addr_o;
    logic illegal_o, reg_write_o, rs1_used_o, rs2_used_o;
    logic [3:0] alu_op_o;
    logic [1:0] alu_a_sel_o;
    logic alu_b_imm_o;
    logic [2:0] imm_format_o;
    logic [1:0] wb_sel_o;
    logic mem_read_o, mem_write_o;
    logic [1:0] mem_size_o;
    logic load_unsigned_o;
    logic [2:0] branch_o;
    logic [1:0] jump_o;
    logic fence_o;
    logic [1:0] system_o;
    wire [28:0] control_word = {illegal_o, reg_write_o, rs1_used_o, rs2_used_o,
        alu_op_o, alu_a_sel_o, alu_b_imm_o, imm_format_o, wb_sel_o,
        mem_read_o, mem_write_o, mem_size_o, load_unsigned_o, branch_o,
        jump_o, fence_o, system_o};
    wire [14:0] register_word = {rs1_addr_o, rs2_addr_o, rd_addr_o};
    logic [31:0] vector_instruction;
    logic [28:0] expected_control;
    logic [14:0] expected_registers;
    logic [5:0] expected_kind;
    int fields, file_handle;
    int unsigned checked = 0;
    int unsigned limit = 0;
    int unsigned per_kind [41] = '{default: 0};
    string vector_path;

    decoder dut (.*);

    initial begin
        if (!$value$plusargs("vectors=%s", vector_path))
            $fatal(1, "provide +vectors=path (run make unit-decoder)");
        if ($value$plusargs("limit=%d", limit) && limit == 0)
            $fatal(1, "+limit must be positive when supplied");
        if ($test$plusargs("trace")) begin
            $dumpfile("build/decoder/decoder.vcd");
            $dumpvars(0, tb_decoder);
        end
        file_handle = $fopen(vector_path, "r");
        if (file_handle == 0) $fatal(1, "cannot open %s", vector_path);
        forever begin
            fields = $fscanf(file_handle, "%h %h %h %h\n", vector_instruction,
                             expected_control, expected_registers, expected_kind);
            if (fields <= 0 && $feof(file_handle)) break;
            if (fields != 4) $fatal(1, "bad vector after row %0d", checked);
            if (expected_kind > 40) $fatal(1, "bad coverage ID after row %0d", checked);
            instr_i = vector_instruction;
            #1;
            assert (control_word === expected_control && register_word === expected_registers)
                else $fatal(1, "row=%0d insn=%h controls=%h expected=%h regs=%h expected_regs=%h file=%s",
                            checked + 1, instr_i, control_word, expected_control,
                            register_word, expected_registers, vector_path);
            // Architectural safety checks, independent of vector expectations.
            if (illegal_o)
                assert (control_word == 29'h10000000)
                    else $fatal(1, "illegal instruction leaked active controls");
            assert (!(mem_read_o && mem_write_o)) else $fatal(1, "conflicting memory intents");
            if (mem_write_o)
                assert (!reg_write_o && rs1_used_o && rs2_used_o)
                    else $fatal(1, "unsafe store controls");
            per_kind[expected_kind]++;
            checked++;
            if (limit != 0 && checked == limit) break;
        end
        $fclose(file_handle);
        if (checked == 0) $fatal(1, "empty vector file");
        if (limit == 0) begin
            foreach (per_kind[kind]) begin
                assert (per_kind[kind] > 0)
                    else $fatal(1, "instruction kind %0d was never exercised", kind);
            end
            $display("PASS decoder: %0d vectors; all 40 RV32I instructions and illegal cases", checked);
        end else begin
            $display("PASS decoder waveform sample: %0d vectors (limited run)", checked);
        end
        $finish;
    end

    initial begin
        #10000000;
        $fatal(1, "decoder test timed out");
    end
endmodule
