`include "SBC6502_options.v"

module top(
		// Clock
		input wire sysclk_50,
		// 7-Segment Display
		output wire [7:0]	HEX0,
		output wire [7:0]	HEX1,
		output wire [7:0]	HEX2,
		output wire [7:0]	HEX3,
		output wire [7:0]	HEX4,
		output wire [7:0]	HEX5,
		// Keys
		input  wire [1:0]	KEY,
		// Leds
		output wire [9:0] LEDR,
		// Switches
		input wire  [9:0] SW,
		// UART
		input  wire			RXD, // GPIO_31 Y4
		output wire			TXD  // GPIO_33 Y3
);


		localparam SYSCLK_MHZ      = 50;     // System clock in MHz
		localparam BAUD_RATE       = 115200; // RS232 Baudrate
		localparam EXACT_TIMING    = 1;      // 1 : Exact 6502 timing (including empty cycles), 0 :  Skips empty cycles
		localparam TRAP_ILLEGAL_OP = 1;
		
		localparam false = 1'b0;
		localparam true  = 1'b1;

		wire			warm_reset = KEY[0];

		wire[7:0]   QB; 
		wire[7:0]   IB;
		wire[15:0]  ADDR_BUS;        
		wire[7:0]   DATA_BUS; 

//===============================================================================================
//  LED & KEYS
//===============================================================================================

		// Input/Output
		assign LEDR[7:0] = QB;
		assign IB = SW[7:0];
		
		assign LEDR[8] = false;
		assign LEDR[9] = false;
		
		assign HEX0 = 8'b1011_1111; // - 
		assign HEX1 = 8'b1010_0100; // 2
		assign HEX2 = 8'b1100_0000; // 0
		assign HEX3 = 8'b1001_0010; // 5
		assign HEX4 = 8'b1000_0010; // 6
		assign HEX5 = 8'b1011_1111; // - 
		
//===============================================================================================
// SBC6502 BOARD
//===============================================================================================

		SBC6502 #(
		  .SYSCLK_MHZ(SYSCLK_MHZ),
		  .BAUD_RATE(BAUD_RATE),
		  .EXACT_TIMING(EXACT_TIMING),
		  .TRAP_ILLEGAL_OP(TRAP_ILLEGAL_OP)
		)
		CPUBOARD(
		  // Control
		  .CLK(sysclk_50),
		  .COLD_RESET_(true),          // needed only for SD option
		  .WARM_RESET_(warm_reset),
		  // Debug
		  .ADDR_BUS(ADDR_BUS),
		  .DATA_BUS(DATA_BUS), 
		  // I/O
		  .IB(IB),
		  .QB(QB),
		  // UART Interface 
		  .RXD(RXD),
		  .TXD(TXD)
		);


endmodule