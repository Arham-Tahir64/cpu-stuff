`timescale 1ns/1ps

// Stimulus and expected values come from a separate Python integer oracle.
module tb_alu;
    logic [31:0] a_i = 32'b0;
    logic [31:0] b_i = 32'b0;
    logic [3:0] op_i = 4'b0;
    logic [31:0] result_o;
    logic invalid_o;
    logic [31:0] expected_result;
    logic expected_invalid;
    logic [31:0] vector_a;
    logic [31:0] vector_b;
    logic [3:0] vector_op;
    int file_handle;
    int fields;
    int unsigned checked = 0;
    int unsigned limit = 0;
    int unsigned per_control [16] = '{default: 0};
    string vector_path;

    alu dut (.*);

    initial begin
        if (!$value$plusargs("vectors=%s", vector_path))
            $fatal(1, "provide +vectors=path (run make unit-alu)");
        if ($value$plusargs("limit=%d", limit) && limit == 0)
            $fatal(1, "+limit must be positive when supplied");
        if ($test$plusargs("trace")) begin
            $dumpfile("build/alu/alu.vcd");
            $dumpvars(0, tb_alu);
        end

        file_handle = $fopen(vector_path, "r");
        if (file_handle == 0) $fatal(1, "cannot open %s", vector_path);
        forever begin
            fields = $fscanf(file_handle, "%h %h %h %h %h\n",
                             vector_op, vector_a, vector_b, expected_result, expected_invalid);
            if (fields <= 0 && $feof(file_handle)) break;
            if (fields != 5) $fatal(1, "bad vector after row %0d", checked);
            // Explicit stimulus assignments ensure the combinational DUT is
            // rescheduled; scanning directly into ports fails on Verilator 5.020.
            op_i = vector_op;
            a_i = vector_a;
            b_i = vector_b;
            // This is a settling interval in the testbench, not ALU latency.
            #1;
            assert (result_o === expected_result && invalid_o === expected_invalid)
                else $fatal(1, "row=%0d op=%h a=%h b=%h got=%h/%b expected=%h/%b file=%s",
                            checked + 1, op_i, a_i, b_i, result_o, invalid_o,
                            expected_result, expected_invalid, vector_path);
            per_control[op_i]++;
            checked++;
            if (limit != 0 && checked == limit) break;
        end
        $fclose(file_handle);
        if (checked == 0) $fatal(1, "empty vector file");
        if (limit == 0) begin
            foreach (per_control[op]) begin
                assert (per_control[op] > 0)
                    else $fatal(1, "control %h was never exercised", 4'(op));
            end
            $display("PASS ALU: %0d vectors; all 10 operations and 6 invalid controls exercised", checked);
        end else begin
            $display("PASS ALU waveform sample: %0d vectors (limited run, not the full regression)", checked);
        end
        $finish;
    end

    initial begin
        #10000000;
        $fatal(1, "ALU test timed out");
    end
endmodule
