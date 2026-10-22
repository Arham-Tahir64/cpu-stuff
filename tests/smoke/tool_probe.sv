// Environment check only. No CPU instructions are implemented here.
`timescale 1ns/1ps
module tool_probe (
    input  logic       clk,
    input  logic       rst,
    output logic [7:0] count
);
    always_ff @(posedge clk) begin
        if (rst) count <= 8'd0;
        else     count <= count + 8'd1;
    end
endmodule
