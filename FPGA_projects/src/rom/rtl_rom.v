//==============================================================================
// Project SBC6502
//------------------------------------------------------------------------------
// Single-Port ROM implementation with static file preload
//------------------------------------------------------------------------------
// 2024 (c) Davide Nardella
// Released under MIT License
//==============================================================================
module rtl_rom
#(
    parameter ADDR_WIDTH = 14,
    parameter DATA_WIDTH = 8,
    parameter DEPTH = 1 << ADDR_WIDTH
)    
(
    input  wire CLK,
    // ROM Interface
	input  wire[ADDR_WIDTH-1:0] A,  // Address bus
    output wire[DATA_WIDTH-1:0] DO, // Data bus
    input  wire CS_N,               // Chip Select (negated)
    input  wire OE_N                // Output Enable (negated)
);
 
`ifdef VENDOR_GOWIN
    (* RAM_STYLE = "block" *)  
`endif 
`ifdef VENDOR_ALTERA
    (* ramstyle = "M9K" *)
`endif 
`ifdef VENDOR_XILINX
    (* RAM_STYLE = "block" *)  
`endif 
    reg[DATA_WIDTH-1:0]	mem[0:DEPTH-1];
    reg[DATA_WIDTH-1:0] data_out;

    always @(posedge CLK)
    begin
        if (!CS_N && !OE_N) 
            data_out <= mem[A];
    end

//------------------------------------------------------------------------------
// ROM Interface
//------------------------------------------------------------------------------

    assign DO = (!OE_N && !CS_N) ? data_out : {DATA_WIDTH{1'bz}};
    
	integer i;
    initial begin
		data_out = 8'h0;
		$readmemh("osi_bas.hex", mem);
    end

endmodule