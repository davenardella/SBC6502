//==============================================================================
// Project SBC6502
//------------------------------------------------------------------------------
// Mainboard implementation (version without SD-Option)
//------------------------------------------------------------------------------
// 2024 (c) Davide Nardella
// Released under MIT License
//==============================================================================
module SBC6502 #(
    parameter SYSCLK_MHZ      = 27,
    parameter BAUD_RATE       = 115200,
    parameter EXACT_TIMING    = 0,
    parameter TRAP_ILLEGAL_OP = 1
)
(
	input       wire CLK,
	input       wire COLD_RESET_,
	input       wire WARM_RESET_,
   output      reg[15:0] ADDR_BUS,
   output      reg[7:0] DATA_BUS,
   // IO
   output      wire[7:0] QB,
   input       wire[7:0] IB,
   // UART Interface
   input       wire RXD,
   output      wire TXD
);
   localparam VSS = 1'b0;
   localparam VCC = 1'b1;

   localparam RES_DELAY = 500;    // 500 ms reset on power-on
    
   localparam ROMWIDTH  = 14;     // A0..A13 -> 16K ROM
   localparam RAMWIDTH  = 15;     // A0..A14 -> 32k RAM
   localparam WORDSIZE  = 8;      // 8 bit Word

	wire rom_sel;    // ROM CS active low
	wire ram_sel;    // RAM CS active low
	wire ram_wr;     // RAM OE acrive low
	wire mem_rd;     // RAM/ROM OE active low
	wire latch_wr;   // Output Latch write enable
	wire latch_rd;   // Input Latch read enable
	wire inout_ena;  // I/O LAtch enable
	wire uart_ena;   // UART enable
    wire auto_reset; // Power-On reset

	// CPU connections
	wire[15:0] ABUS;	 // Address Bus
	wire[7:0] DBUS;		 // Data Bus
	wire[7:0] PREV_CYCLE;
	wire RW_;			 // R/W* Line
	wire PHI1;			 // PHI2 Line
	wire PHI2;			 // PHI2 Line
	wire RES_;
	wire ROM_BSY_;
		 
//==============================================================================
// CPU
//==============================================================================
    assign RES_ = WARM_RESET_ && COLD_RESET_ && auto_reset;
        
    wire TRAP;
    wire RDY;
    wire SYNC;

	M6502 #(
        .SYSCLK_MHZ(SYSCLK_MHZ),
        .EXACT_TIMING(EXACT_TIMING),
        .TRAP_ILLEGAL_OP(TRAP_ILLEGAL_OP)
    )
    M65RTL02(
		.CLK(CLK),     // <-- System Clock (27 MHz)
		.PHI1(PHI1),   // --> Phase 1 out
		.PHI2(PHI2),   // --> Phase 2 out
		.RES_(RES_),   // <-- Reset (active low)'
      .BE(VCC),      // <-- Bus Enable (Active High)
      .NMI_(VCC),    // <-- No Maskable Interrupt (Active Low)
      .IRQ_(VCC),    // <-- Interrupt Request (Active Low)
      .RDY(RDY),     // <-- Ready (Active High)
      .SO_(VCC),     // <-- Set Overflow Flag (Active Low)
      .RW_(RW_),     // --> Read/Write (Read : 1, Write : 0)
      .SYNC(SYNC),   // --> Sync - Fetch in progress - (Active High)
      .ABUS(ABUS),   // ==> 16-bit Address Bus
      .DBUS(DBUS),   // <=> 8bit Data Bus (Bidirectional)
      .TRAP(TRAP)    // --> Trap on error (illegal opcode)
	);


    // Open this "short-circuit" and insert a step by step or wait_state circuit, if you want.
    assign RDY = SYNC;

    always @(posedge CLK)
    begin
        if ((SYNC && PHI2) || TRAP) // Get Info
        begin
            ADDR_BUS <= ABUS;
            DATA_BUS <= DBUS;
        end
    end

//==============================================================================
// ADDRESS DECODER
//==============================================================================
	assign rom_sel   = ~(ABUS[14] & ABUS[15]); // ROM Map : 0xC000 -> 0xFFFF
	assign ram_sel   = ABUS[15];               // RAM Map : 0x0000 -> 0x7FFF 
	assign ram_wr    = RW_;
	assign mem_rd    = ~RW_;
   assign inout_ena = ABUS[12] | ABUS[13] | ABUS[14] | ~ABUS[15]; // Address = 0x8XXX
   assign latch_rd  = !(!inout_ena && RW_);
   assign latch_wr  = !inout_ena && !RW_ && PHI1; 
   assign uart_ena  = ABUS[12] | ~ABUS[13] | ABUS[14] | ~ABUS[15]; // Address = 0xAXXX
//==============================================================================
// ROM 
//==============================================================================
    rtl_rom #(
        .ADDR_WIDTH(ROMWIDTH),
        .DATA_WIDTH(WORDSIZE)  
    )
    M27RTL128SD(
        .CLK(CLK),        
         // ROM Interface
        .A(ABUS[ROMWIDTH-1:0]),
        .DO(DBUS),
        .CS_N(rom_sel),
        .OE_N(mem_rd)
    );
    assign ROM_BSY_ = VCC;
	
//==============================================================================
// RAM - 62256 32K x 8 SRAM
//==============================================================================
    // Instance
    rtl_ram #(
        .ADDR_WIDTH(RAMWIDTH),
        .DATA_WIDTH(WORDSIZE)  
    )
    M62RTL256(
        .CLK(CLK),
        .A(ABUS[RAMWIDTH-1:0]),
        .DIO(DBUS),
        .CS_N(ram_sel),
        .OE_N(mem_rd),
		.WR_N(ram_wr)
    );

//==============================================================================
// UART - ACIA 6850
//==============================================================================

    // Instance
    rtl_acia #(
        .SYSCLK_MHZ(SYSCLK_MHZ),
        .BAUD_RATE(BAUD_RATE)
    )
    M68RTL50(
        .CLK(CLK),
        .RXD(RXD),
        .TXD(TXD),
        .RTS(),
        .CTS(VSS),        // unused here
        .E(VCC),
        .CS0(VCC),
        .CS1(VCC),
        .CS2_N(uart_ena),
        .RS(ABUS[0]),
        .RW_N(RW_),
        .IRQ_N(),
        .DIO(DBUS)
    );

//==============================================================================
// I/O
//==============================================================================

    rtl_octal_3state_buffer
    M74RTL244(
        .D(IB),
        .Q(DBUS),
        .OE_N(latch_rd)
    );

    rtl_octal_ff
    M74RTL374(
        .CLK(CLK),
        .D(DBUS),
        .Q(QB),
        .OE_N(VSS),
        .WR(latch_wr)
    );

//==============================================================================
// Autoreset
//==============================================================================

    poweron_reset #(
        .SYSCLK_MHZ(SYSCLK_MHZ),
        .DELAY(RES_DELAY)
    )
    POR(
        .CLK(CLK),
        .RESET_(auto_reset),
        .RESET()
    );

endmodule