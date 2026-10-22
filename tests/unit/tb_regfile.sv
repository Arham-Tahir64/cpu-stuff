`timescale 1ns/1ps

// Reference architectural state is separate from DUT storage. Check only the
// public ports, both before and after the write edge, and when read addresses
// change without a rising edge.
module tb_regfile;
    logic clk_i = 1'b0;
    logic rst_i = 1'b0;
    logic we_i = 1'b0;
    logic [4:0] waddr_i = 5'b0;
    logic [31:0] wdata_i = 32'b0;
    logic [4:0] raddr_a_i = 5'b0;
    logic [4:0] raddr_b_i = 5'b0;
    logic [31:0] rdata_a_o;
    logic [31:0] rdata_b_o;
    logic [31:0] expected [0:31] = '{default: 32'b0};
    logic [31:0] seed = 32'h5eed1234;
    logic [31:0] rng;
    logic [31:0] controls;
    logic [31:0] data_word;
    int unsigned random_cycles = 10000;
    int unsigned cycles_checked = 0;
    int unsigned read_checks = 0;
    bit sample_run;

    regfile dut (.*);
    always #5 clk_i <= ~clk_i;

    function automatic logic [31:0] next_random();
        // Explicit xorshift32 makes stimulus reproducible without $urandom's
        // simulator-dependent seed handling. Zero is rejected at startup.
        rng = rng ^ (rng << 13);
        rng = rng ^ (rng >> 17);
        rng = rng ^ (rng << 5);
        return rng;
    endfunction

    task automatic check_reads(input string phase);
        assert (rdata_a_o === expected[raddr_a_i])
            else $fatal(1, "seed=%h cycle=%0d %s port=A addr=%0d got=%h expected=%h",
                        seed, cycles_checked, phase, raddr_a_i,
                        rdata_a_o, expected[raddr_a_i]);
        assert (rdata_b_o === expected[raddr_b_i])
            else $fatal(1, "seed=%h cycle=%0d %s port=B addr=%0d got=%h expected=%h",
                        seed, cycles_checked, phase, raddr_b_i,
                        rdata_b_o, expected[raddr_b_i]);
        read_checks += 2;
    endtask

    task automatic step(
        input bit reset, input bit write_enable,
        input logic [4:0] write_addr, input logic [31:0] write_data,
        input logic [4:0] read_a, input logic [4:0] read_b
    );
        @(negedge clk_i);
        #1; // Drive away from either edge, avoiding DUT/testbench races.
        rst_i = reset;
        we_i = write_enable;
        waddr_i = write_addr;
        wdata_i = write_data;
        raddr_a_i = read_a;
        raddr_b_i = read_b;
        #1;
        check_reads("before rising edge");
        @(posedge clk_i);
        #1; // Sample after the DUT's nonblocking updates have settled.
        if (reset) begin
            foreach (expected[index]) expected[index] = 32'b0;
        end else begin
            if (write_enable) expected[write_addr] = write_data;
            // Architectural model includes x0 but forces it back to zero;
            // the DUT instead has no x0 storage and suppresses that write.
            expected[0] = 32'b0;
        end
        cycles_checked++;
        check_reads("after rising edge");
    endtask

    task automatic scan_registers();
        // After each directed write, read every register through both ports to
        // catch aliasing and unintended modification of neighboring registers.
        rst_i = 1'b0;
        we_i = 1'b0;
        for (int address = 0; address < 32; address++) begin
            @(negedge clk_i);
            #1;
            raddr_a_i = 5'(address);
            raddr_b_i = 5'(31 - address);
            #1;
            check_reads("register sweep");
        end
    endtask

    task automatic scan_read_pairs();
        rst_i = 1'b0;
        we_i = 1'b0;
        for (int a = 0; a < 32; a++) begin
            for (int b = 0; b < 32; b++) begin
                @(negedge clk_i);
                #1;
                raddr_a_i = 5'(a);
                raddr_b_i = 5'(b);
                #1;
                check_reads("all read-address pairs");
            end
        end
    endtask

    initial begin
        if ($value$plusargs("seed=%h", seed) && seed == 0)
            $fatal(1, "xorshift seed must be nonzero");
        if ($value$plusargs("random_cycles=%d", random_cycles) && random_cycles == 0)
            $fatal(1, "random_cycles must be positive when supplied");
        rng = seed;
        sample_run = $test$plusargs("sample");
        if ($test$plusargs("trace")) begin
            $dumpfile("build/regfile/regfile.vcd");
            $dumpvars(0, tb_regfile);
        end

        // Only x0 is assumed to be defined before the first reset edge.
        #1;
        check_reads("x0 before first reset");
        step(1, 1, 5'd5, 32'hffffffff, 5'd0, 5'd0);
        step(1, 1, 5'd5, 32'haaaaaaaa, 5'd5, 5'd0);

        for (int address = 0; address < 32; address++) begin
            step(0, 1, 5'(address), 32'hcafe0000 ^ (32'(address) * 32'h01010101),
                 5'(address), 5'(31 - address));
            if (!sample_run) scan_registers();
        end

        // WE=0 must retain state even when address/data change on every cycle.
        for (int address = 0; address < 32; address++)
            step(0, 0, 5'(address), 32'hffffffff, 5'(address), 5'(address));

        // A live nonzero register must survive reset assertion until posedge;
        // reset and WE together must then clear it rather than store wdata.
        step(0, 1, 5'd7, 32'hdeadbeef, 5'd7, 5'd0);
        step(1, 1, 5'd7, 32'h12345678, 5'd7, 5'd7);
        step(1, 1, 5'd31, 32'hffffffff, 5'd31, 5'd0);
        step(0, 0, 5'd7, 32'haaaaaaaa, 5'd7, 5'd31);
        step(0, 1, 5'd0, 32'hffffffff, 5'd0, 5'd0);

        if (sample_run) begin
            $display("PASS regfile waveform sample: %0d checked cycles / %0d reads (limited run)",
                     cycles_checked, read_checks);
            $finish;
        end

        // Walking ones/zeros test every bit in each of the 31 storage words.
        for (int address = 1; address < 32; address++) begin
            for (int bit_index = 0; bit_index < 32; bit_index++) begin
                step(0, 1, 5'(address), 32'h1 << bit_index, 5'(address), 5'(address));
                step(0, 1, 5'(address), ~(32'h1 << bit_index), 5'(address), 5'(address));
            end
        end
        // Make values distinct before the exhaustive two-port address sweep.
        for (int address = 1; address < 32; address++)
            step(0, 1, 5'(address), 32'h13579bdf ^ (32'(address) * 32'h01020408),
                 5'(address), 5'd0);
        scan_read_pairs();

        $display("Regfile random stimulus: seed=%h cycles=%0d", seed, random_cycles);
        repeat (random_cycles) begin
            controls = next_random();
            data_word = next_random();
            step((controls[23:16] ^ controls[31:24]) == 8'b0, controls[15], controls[4:0], data_word,
                 controls[9:5], controls[14:10]);
        end
        scan_read_pairs();
        // Final reset must clear every architectural register, not just reads
        // selected while reset was high.
        step(1, 1, 5'd31, 32'hffffffff, 5'd31, 5'd0);
        scan_registers();
        $display("PASS regfile: %0d checked cycles / %0d read checks; all 1024 read-address pairs",
                 cycles_checked, read_checks);
        $finish;
    end

    initial begin
        #10000000;
        $fatal(1, "regfile test timed out: seed=%h", seed);
    end
endmodule
