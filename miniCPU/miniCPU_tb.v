`timescale 10ns/10ps
`include "miniCPU.v" 
module miniCPU_tb;

	reg clk;
	reg rst_;

	always 
		#1 clk = ~clk; // Clock generation

    // mini-CPU instance
    miniCPU CPU(
        .CLK(clk),
        .RST_(rst_)
    );

	initial begin
        $dumpfile("signals.vcd"); // Name of the signal dump file
        $dumpvars(0, miniCPU_tb); // Signals to dump
		clk     = 1'b0; // *Everything* must be inited in a testbench
		rst_    = 1'b0;
		#2 rst_ = 1'b1; // Reset remains LOW for two time units
        #85; // Wait 85 time units (meanwhile the clock is running)
        $finish(); 
	end

endmodule