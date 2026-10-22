`timescale 1ns/1ps

// RV32I architectural registers: x0 is a constant, x1-x31 hold state.
// Reads are combinational. Writes and active-high reset happen only at posedge.
module regfile (
    input  logic        clk_i,
    input  logic        rst_i,
    input  logic        we_i,
    input  logic [4:0]  waddr_i,
    input  logic [31:0] wdata_i,
    input  logic [4:0]  raddr_a_i,
    input  logic [4:0]  raddr_b_i,
    output logic [31:0] rdata_a_o,
    output logic [31:0] rdata_b_o
);
    // No writable storage is allocated for x0.
    logic [31:0] regs [1:31];

    always_ff @(posedge clk_i) begin
        for (int index = 1; index < 32; index++) begin
            if (rst_i)
                regs[index] <= 32'b0;
            else if (we_i && waddr_i == 5'(index))
                regs[index] <= wdata_i;
        end
    end

    // No pre-edge write-through: a read sees stored state, then the new value
    // once a rising-edge write has settled. The future pipeline handles bypass.
    assign rdata_a_o = (raddr_a_i == 5'd0) ? 32'b0 : regs[raddr_a_i];
    assign rdata_b_o = (raddr_b_i == 5'd0) ? 32'b0 : regs[raddr_b_i];
endmodule
