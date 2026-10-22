`timescale 1ns/1ps
module tb_tool_probe;
    logic clk = 1'b0;
    logic rst = 1'b1;
    logic [7:0] count;
    tool_probe dut (.clk(clk), .rst(rst), .count(count));
    always #5 clk <= ~clk;
    initial begin
        $dumpfile("build/smoke.vcd");
        $dumpvars(0, tb_tool_probe);
        repeat (2) @(negedge clk);
        assert (count == 0) else $fatal(1, "reset failed");
        rst = 1'b0;
        for (int unsigned i = 1; i <= 260; i++) begin
            @(negedge clk);
            assert (count == 8'(i)) else $fatal(1, "counter mismatch at %0d", i);
        end
        rst = 1'b1;
        @(negedge clk);
        assert (count == 0) else $fatal(1, "second reset failed");
        $display("PASS Verilator reset, 260 cycles, wraparound, assertions, VCD");
        $finish;
    end
    initial begin
        #10000;
        $fatal(1, "simulation timed out");
    end
endmodule
