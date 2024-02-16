//==============================================================================
// Project SBC6502
//------------------------------------------------------------------------------
// Single-Port RAM implementation
//------------------------------------------------------------------------------
// 2024 (c) Davide Nardella
// Released under MIT License
//==============================================================================
module rtl_ram
#(
    parameter ADDR_WIDTH = 15,
    parameter DATA_WIDTH = 8,
    parameter DEPTH = 1 << ADDR_WIDTH
)    
(
    input wire CLK,
    input wire[ADDR_WIDTH-1:0] A,   // Address bus
    inout wire[DATA_WIDTH-1:0] DIO, // Data bus
    input wire CS_N,                // Chip Select (negated)
    input wire OE_N,                // Output Enable (negated)
    input wire WR_N                 // Write Enable (negated)
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
    reg[DATA_WIDTH-1:0] mem[0:DEPTH-1];
    reg[DATA_WIDTH-1:0] data_out;

    always @(posedge CLK)
    begin
		if (!CS_N && !OE_N) 
			data_out <= mem[A];
	 end
	
    always @(posedge CLK)
    begin
        if (!CS_N && !WR_N) 
            mem[A] <= DIO;
	end
    assign DIO = (!OE_N && !CS_N && WR_N) ? data_out : {DATA_WIDTH{1'bz}};
    
    initial begin
        data_out = 0;
    end

endmodule