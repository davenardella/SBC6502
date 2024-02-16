//==============================================================================
// Project SBC6502
//------------------------------------------------------------------------------
// 8-bit 3-State Buffer implementation
//------------------------------------------------------------------------------
// 2024 (c) Davide Nardella
// Released under MIT License
//==============================================================================
module rtl_octal_3state_buffer
(
	input wire[7:0]  D,
	output wire[7:0] Q,
    input wire OE_N     // Output Enable (negated)
);

    assign Q = !OE_N ? D : {8{1'bz}};

endmodule