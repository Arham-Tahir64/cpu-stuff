`timescale 1ns/1ps

module tb_immediate;
    logic [31:0] instr_i = 32'b0;
    logic [2:0] format_i = 3'b0;
    logic [31:0] imm_o;
    logic invalid_o;
    logic [31:0] vector_instruction;
    logic [2:0] vector_format;
    logic [31:0] expected_immediate;
    logic expected_invalid;
    int file_handle;
    int fields;
    int unsigned checked = 0;
    int unsigned limit = 0;
    int unsigned per_format [8] = '{default: 0};
    string vector_path;

    immediate dut (.*);

    initial begin
        if (!$value$plusargs("vectors=%s", vector_path))
            $fatal(1, "provide +vectors=path (run make unit-immediate)");
        if ($value$plusargs("limit=%d", limit) && limit == 0)
            $fatal(1, "+limit must be positive when supplied");
        if ($test$plusargs("trace")) begin
            $dumpfile("build/immediate/immediate.vcd");
            $dumpvars(0, tb_immediate);
        end
        file_handle = $fopen(vector_path, "r");
        if (file_handle == 0) $fatal(1, "cannot open %s", vector_path);
        forever begin
            fields = $fscanf(file_handle, "%h %h %h %h\n", vector_format,
                             vector_instruction, expected_immediate, expected_invalid);
            if (fields <= 0 && $feof(file_handle)) break;
            if (fields != 4) $fatal(1, "bad vector after row %0d", checked);
            // Explicit driving is required for reliable rescheduling in 5.020.
            format_i = vector_format;
            instr_i = vector_instruction;
            #1;
            assert (imm_o === expected_immediate && invalid_o === expected_invalid)
                else $fatal(1, "row=%0d format=%h instruction=%h got=%h/%b expected=%h/%b file=%s",
                            checked + 1, format_i, instr_i, imm_o, invalid_o,
                            expected_immediate, expected_invalid, vector_path);
            checked++;
            per_format[format_i]++;
            if (limit != 0 && checked == limit) break;
        end
        $fclose(file_handle);
        if (checked == 0) $fatal(1, "empty vector file");
        if (limit == 0) begin
            foreach (per_format[format_code]) begin
                assert (per_format[format_code] > 0)
                    else $fatal(1, "format selector %0d was never exercised", format_code);
            end
            $display("PASS immediate: %0d vectors; I/S/B/U/J, NONE and both invalid selectors", checked);
        end else begin
            $display("PASS immediate waveform sample: %0d vectors (limited run)", checked);
        end
        $finish;
    end

    initial begin
        #10000000;
        $fatal(1, "immediate test timed out");
    end
endmodule
