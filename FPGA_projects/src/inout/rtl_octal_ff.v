//==============================================================================
// Project SBC6502
//------------------------------------------------------------------------------
// 8-bit D-Latch implementation
//------------------------------------------------------------------------------
// 2024 (c) Davide Nardella
// Released under MIT License
//==============================================================================
module rtl_octal_ff
(
	input wire CLK,
	input wire[7:0]  D,
	output wire[7:0] Q,
    input wire OE_N,     // Output Enable (negated)
    input wire WR       // Output Enable (negated)
);

	reg[7:0] latch;
	
    always @(posedge CLK) 
    begin
        if (WR)
            latch <= D;
    end


    assign Q = !OE_N ? latch : {8{1'bz}};

    initial latch = 8'h00;

endmodule