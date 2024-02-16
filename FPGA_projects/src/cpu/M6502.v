//==============================================================================
// Project SBC6502
//------------------------------------------------------------------------------
// MOS 6502 softcore implementation
//------------------------------------------------------------------------------
// 2024 (c) Davide Nardella
// Released under MIT License
//==============================================================================

//---------------------------------------------------------------
// Pin convention
// The underscore at the end of a pin means that it's active low
// e.g. ___
//      RES becomes RES_
//---------------------------------------------------------------
module M6502 #(
   parameter SYSCLK_MHZ      = 27,
	parameter EXACT_TIMING    = 0,
	parameter TRAP_ILLEGAL_OP = 1
)
(
	// Clock
	input wire 	CLK,        // Clock input 
	output wire PHI1,       // Clock output Phase 1 
	output wire PHI2,       // Clock output Phase 2 
	// Control
	input wire	BE,         // Bus Enable (when=0 Lines are HighZ)
	input wire	NMI_,       // No Maskable Interrupt
	input wire 	IRQ_,       // Interrupt Request
	input wire 	RDY,        // Ready
	input wire 	SO_,        // Set Overflow
	input wire 	RES_,       // Reset
	output wire RW_,        // RD/WR - 1:Read, 0:Write
	output wire SYNC,       // Sync  
	// Bus
	output wire[15:0] ABUS, // 16 Bit Address Bus
	inout wire[7:0]   DBUS,  // 8 Bit Data Bus
   // Trap on Error
   output wire TRAP
);
		
	localparam false    = 1'b0;
	localparam true     = 1'b1;
	
    // Vectors
   localparam RST_VECTOR = 16'hFFFC;
	localparam NMI_VECTOR = 16'hFFFA;
	localparam IRQ_VECTOR = 16'hFFFE;
	localparam BRK_VECTOR = 16'hFFFE;

	localparam A_INIT     = 8'hAA;
	localparam X_INIT     = 8'h00;
	localparam Y_INIT     = 8'h00;
	localparam SP_INIT    = 8'hFD;
	localparam ST_INIT    = 8'b0011_0110;
	
//---------------------------------------------------------------
// FSM Cycles (States)
//---------------------------------------------------------------
    localparam CY_RESET					= 6'h00;
	localparam CY_FETCH_DECODE			= 6'h01;
	localparam CY_EMPTY					= 6'h02;
	localparam CY_ILLEGAL_OPCODE		= 6'h03;
	localparam CY_VECTOR_SEQUENCE_0		= 6'h04;
	localparam CY_VECTOR_SEQUENCE_1		= 6'h05;
	localparam CY_VECTOR_SEQUENCE_2		= 6'h06;
	localparam CY_VECTOR_SEQUENCE_3		= 6'h07;
	localparam CY_VECTOR_SEQUENCE_4		= 6'h08;
	localparam CY_JSR_GET_AL			= 6'h09;
	localparam CY_JSR_GET_AH			= 6'h0A;
	localparam CY_JSR_PUSH_H			= 6'h0B;
	localparam CY_JSR_PUSH_L			= 6'h0C;
	
	localparam CY_IMPLIED_SHORT      	= 6'h10;
	localparam CY_IMMEDIATE				= 6'h11;
	localparam CY_STACK_PUSH			= 6'h12;
	localparam CY_STACK_PULL			= 6'h13;
	localparam CY_IND_GET_AL			= 6'h14;
	localparam CY_IND_GET_AH			= 6'h15;
	localparam CY_IND_GET_VL			= 6'h16;
	localparam CY_IND_GET_VH			= 6'h17;
	localparam CY_RELATIVE   			= 6'h18;
	localparam CY_RET_POP_ST			= 6'h19;
	localparam CY_RET_POP_AL			= 6'h1A;
	localparam CY_RET_POP_AH			= 6'h1B;
	localparam CY_RET_EXECUTE			= 6'h1C;

	localparam CY_ABS_GET_AL			= 6'h20;
	localparam CY_ABS_GET_AH			= 6'h21;
	localparam CY_IND_IDZ_GET_AL		= 6'h22;
	localparam CY_IND_IDZ_GET_VL		= 6'h23;
	localparam CY_IND_IDZ_GET_VH		= 6'h24;
	localparam CY_IND_IDZ_EX_RM			= 6'h25;
	localparam CY_EXECUTE_RM			= 6'h26;
	localparam CY_EXECUTE_MR			= 6'h27;
	localparam CY_EXECUTE_MM			= 6'h28;
	localparam CY_STORE_MM				= 6'h29;

    localparam CY_TRAP                  = 6'h3E;
	localparam CY_WAIT_RESET			= 6'h3F;  // Powerup state
	// Max cycle index = 6'h3F;
//---------------------------------------------------------------
// Registers
//---------------------------------------------------------------
    // Public
	reg[7:0]		reg_A;	// Accumulator
	reg[7:0]		reg_X;	// Index X
	reg[7:0]		reg_Y;	// Index Y
	reg[15:0]		reg_PC;	// Program Counter
	reg[7:0]		reg_SP; // Stack Pointer (8 bits, we will handle 9th bit separately)
	reg[7:0]		reg_ST; // Status registers (Flags)
	// Flags index
	localparam		C_flag	= 3'd0;    // Carry
	localparam		Z_flag	= 3'd1;    // Zero
	localparam		I_flag	= 3'd2;    // IRQB
	localparam		D_flag	= 3'd3;    // Decimal mode
	localparam		B_flag	= 3'd4;    // BRK
	localparam		U_flag	= 3'd5;    // Unused, always 1
	localparam		V_flag	= 3'd6;    // Overflow
	localparam		N_flag	= 3'd7;    // Negative
	// Latched
	reg[7:0]		reg_A_out;	// Accumulator
	reg[7:0]		reg_X_out;	// Index X
	reg[7:0]		reg_Y_out;	// Index Y
	reg[15:0]		reg_PC_out;	// Program Counter
	reg[7:0]		reg_SP_out; // Stack Pointer
	reg[7:0]		reg_ST_out; // Status registers (Flags)

    // Internals
	reg[7:0]		reg_DI;  // Data In buffer
	reg[7:0]		reg_DO;  // Data Out buffer
	reg[15:0]       reg_DP;  // Data Pointer 
	reg[15:0]		reg_MAR; // Memory address register
	// Latched
	reg[7:0]		reg_DI_out;  // Data In buffer
	reg[7:0]		reg_DO_out;  // Data Out buffer
	reg[15:0]       reg_DP_out;  // Data Pointer 
	reg[15:0]		reg_MAR_out; // Memory address register
	
//---------------------------------------------------------------
// FSM
//---------------------------------------------------------------
    reg[7:0]        cycle;
    reg[7:0]        next_cycle; // Latched
    
//---------------------------------------------------------------
// Clock
//---------------------------------------------------------------
    // 1st stage divider    
    reg[2:0]        sysck = 2'd0;
    wire            PH0;

    // 2nd stage divider    
    reg[2:0]		ck = 3'd0; // Clock counter
	wire			PHI3;   
	wire			T0;		
	wire			T1;

//---------------------------------------------------------------
// RES/NMI/INT
//---------------------------------------------------------------
	reg[2:0]		async_pending  	  = 3'b00;
	reg[2:0]		async_pending_out = 3'b00;
	localparam      no_pending  	  = 3'b000; // No pending	
	`define 		RST	2
	`define 		NMI	1
	`define 		IRQ	0
//---------------------------------------------------------------
// Internal flags
//---------------------------------------------------------------
	reg				write_enable     = 0;	// Write cycle
	reg				write_enable_out = 0;
	reg[2:0]		empty_count;
	reg[2:0]		empty_count_out;

//---------------------------------------------------------------
// Instructions 
//---------------------------------------------------------------
	reg[17:0]	itable[0:255];	          // instruction table
	reg[17:0]	instruction     = 18'd0;  // instruction record
	reg[17:0]	instruction_out = 18'd0;

	// Instruction fields
	`define 	instruction_name 	instruction[17:12]
	`define 	direction			instruction[11:9]
	`define 	index_mode  		instruction[8:6]
	`define		cycle_start			instruction_out[5:0]

	// Direction
	localparam dir_RR1B		= 3'b000;    // Register -> Register (1-byte)
	localparam dir_MR1B		= 3'b001;    // Memory -> Register (1-byte)
	localparam dir_MR2B		= 3'b010;    // Memory -> Register (2-byte)
	localparam dir_RM1B		= 3'b011;    // Register -> Memory (1-byte)
	localparam dir_RM2B		= 3'b100;    // Register -> Memory (2-byte)
	localparam dir_MM1B		= 3'b101;    // Memory -> Memory (1-byte)
	localparam dir_MM2B		= 3'b110;    // Memory -> Memory (2-byte)
	localparam dir_CTRL		= 3'b111;    // Control Instruction (No Direction or stack based)
	
	// Index mode
	localparam no_index     = 3'b000;    // Implied, Immediate, Relative, Accumulator, Indirect
	localparam index_Z      = 3'b001;    // Page Zero
	localparam index_X      = 3'b010;    // X-Indexed Absolute
	localparam index_Y      = 3'b011;    // Y-Indexed Absolute
	localparam index_XZ     = 3'b100;    // X-Indexed Zero Page
	localparam index_YZ     = 3'b101;    // Y-Indexed Zero Page
	localparam index_IXZ    = 3'b110;    // X-Indexed Zero Page Indirect
	localparam index_IYZ    = 3'b111;    // Zero Page Indirect Y-Indexed
	
//---------------------------------------------------------------
// Includes - to keep this file as small as possible avoiding
//            the overhead of modules
//---------------------------------------------------------------
`include "opcodes.v"  // opcodes List
`include "tasks.v"    // useful tasks
`include "execute.v"  // Instructions execute

//---------------------------------------------------------------
// SEQUENTIAL
//---------------------------------------------------------------
	// Clock
    reg res_latch = 0; // We need a latch because PHI3 is always low during reset

	assign T0 = (ck == 1);
	assign T1 = (ck == 5);
	assign PHI3 = (ck == 1) || (ck == 5);

    // 1-st Stage divider
    always @(posedge CLK)
    begin
        sysck <= sysck + 3'd1;
    end

    localparam CLK_IDX = (SYSCLK_MHZ <= 12) ? 3'd0 : (SYSCLK_MHZ <= 27) ? 3'd1 : (SYSCLK_MHZ <= 50) ? 3'd2 : 3'd3; 
    assign PH0 = sysck[CLK_IDX];

    always @(posedge CLK)
    begin
		if (PH0) begin
            // Phases generation
            ck <= RES_ ? ck + 3'd1 : 3'd0;
            if (async_pending[`RST])  // RST
                res_latch <= 0; 
            else
                if (!RES_) 
                    res_latch <= true;	

            // Asynchronous events and state shift
            // 2-nd Stage divider
            if (PHI3) begin               
                // Check nested RST and Interrupts
                // RST has the max priority and clears all others
                // NMI is fired only if there isn't an RST in progress
                // IRQ is fired only if there aren't other event pending and I_flag is not set
                if (res_latch) begin
                    async_pending <= 3'b100; // set RST flag and clear all others
                    write_enable <= false;
                    cycle <= CY_RESET; // This is immediate
                end
                else begin
                    if (!NMI_ && (!async_pending_out[`RST])) begin // Not RES pending
                        async_pending[`NMI] <= 1'b1;  // set NMI flag
                    end	
                    else
                        if (!IRQ_ && !reg_ST_out[I_flag] && (async_pending_out == no_pending)) 
                            async_pending[`IRQ] <= 1'b1; // set IRQ flag
                        else
                            async_pending <= async_pending_out;
            
                    cycle <= next_cycle;					
                end
                set_current();
                if (T1 && ~SO_) // Seldom used, just for the "exactness"
                    reg_ST[V_flag] <= 1'b1;
            end
        end
    end

//---------------------------------------------------------------
// LOGIC FSM
//---------------------------------------------------------------

    always @(*) 
    begin
		set_next();
        case (cycle)
			//=============================================================================
            // WAIT RESET cycle
			//=============================================================================
			CY_WAIT_RESET: begin
				// After the powerup a reset is needed to initialize the CPU
				// We wait here until the sequential FSM fires the reset cycle
			end
			//=============================================================================
            // RESET cycle
			//=============================================================================
			CY_RESET: begin
				// Active in T1, waits for the reset line to be deactivated
                if (RES_ && T1) begin
					next_cycle = CY_VECTOR_SEQUENCE_3; // Skip pushing return address and SP
                end			
            end
			//=============================================================================
			// FETCH and DECODE Cycle 
			//=============================================================================
			CY_FETCH_DECODE: begin
				if (T0) begin
					// We cannot increment PC here since we need to check the RDY signal
					reg_MAR_out = reg_PC;
				end
				else begin
					if (RDY) begin
						// Decode (get Instruction Info)
						instruction_out = itable[DBUS];
						reg_PC_out = reg_PC + 16'd1;
						// Execute (Jumps to the first Instruction sequence step)
                        next_cycle = `cycle_start;
					end 
				end
			end
			//=============================================================================
			// Implied Short (2 cycles)
			//=============================================================================
			CY_IMPLIED_SHORT: begin
				if (T1) begin
					execute_Register_Register();
					// Here PC = Next OP, we don't have to inc PC for this cycle 
					next_fetch();
				end
			end
			//=============================================================================
			// Immediate (2 cycles)
			//=============================================================================
			CY_IMMEDIATE: begin
				if (T0) begin
					pc_to_mar();
				end
				else begin
					execute_Memory_Register();
					next_fetch(); 
				end
			end
			//=============================================================================
			// STACK Push (PHA/PHP)
			//=============================================================================
			CY_STACK_PUSH: begin
				if (T0) begin
					if (`instruction_name == PHA)
						push(reg_A);						
					else 
						push(reg_ST); 
				end 
				else begin
					write_enable_out = false;
					empty_count_out = 3'd1;
					next_empty();
				end
			end
			//=============================================================================
			// STACK Pull (PLA/PLP)
			//=============================================================================
			CY_STACK_PULL: begin			
				if (T0) begin
					pull();
				end
				else begin
					if (`instruction_name == PLA) begin
						reg_A_out = DBUS;
		                set_ZN_flags(DBUS);
					end	
					else
						reg_ST_out = DBUS; 
					empty_count_out = 3'd2;
					next_empty();
				end
			end
			//=============================================================================
			// Absolute 
			//=============================================================================
			// Get Lo part of operand address
			CY_ABS_GET_AL: begin
				if (T0) begin
					pc_to_mar();
				end
				else begin
					reg_DP_out = {8'h00, DBUS}; // Get LO-Part
					case (`direction)
						// 1-byte Address
						dir_MR1B : next_cycle = CY_EXECUTE_MR;
						dir_RM1B : next_cycle = CY_EXECUTE_RM;
						dir_MM1B : next_cycle = CY_EXECUTE_MM;
						// all other : 2-byte Address
						default : 
							next_cycle = CY_ABS_GET_AH;
					endcase	
				end
			end
			//---------------------------------------------------------------
			// Get Hi part of operan address
			//---------------------------------------------------------------
			CY_ABS_GET_AH: begin
				if (T0) begin
					pc_to_mar();
				end
				else begin
					if (`instruction_name == JMP) begin
						reg_PC_out = {DBUS, reg_DP[7:0]};
						next_fetch();				
					end
					else begin
						reg_DP_out[15:8] = DBUS; // Get HI-Part
						case (`direction)
							// 2-byte Address
							dir_MR2B : next_cycle = CY_EXECUTE_MR; 
							dir_RM2B : next_cycle = CY_EXECUTE_RM;      
							dir_MM2B : next_cycle = CY_EXECUTE_MM;
						default: 	
							next_cycle = CY_TRAP;
						endcase	
					end
				end
			end
			//=============================================================================
			// Relative 
			//=============================================================================
			// Get Lo part as offset for the program counter
			CY_RELATIVE: begin
				// Get the offset
				if (T0) begin
					pc_to_mar();
				end
				else begin
                    // The offset is signed, so we need to adjust it
					execute_branch(DBUS[7] ? {8'hFF, DBUS} : {8'h00, DBUS});
					if (empty_count_out == 0)
						next_fetch();
					else	
						next_empty();
				end
			end
			//=============================================================================
			// Absolute Indirect 
			//=============================================================================
			// Get Lo part of Lookup Address 
			CY_IND_GET_AL: begin
				// Get the first byte
				if (T0) begin
					pc_to_mar();
				end
				else begin
					reg_DP_out = {8'h00, DBUS};
					next_cycle = CY_IND_GET_AH;
				end
			end
			//---------------------------------------------------------------
			// Get Hi part of Lookup Address 
			//---------------------------------------------------------------
			CY_IND_GET_AH: begin
				// Get the second byte
				if (T0) begin
					pc_to_mar();
				end
				else begin
					reg_DP_out[15:8] = DBUS;
					next_cycle = CY_IND_GET_VL;
				end
			end
			//---------------------------------------------------------------
			// Get Final low value
			//---------------------------------------------------------------
			CY_IND_GET_VL: begin
				if (T0) begin
					reg_MAR_out = reg_DP;
				end
				else begin
					reg_DI_out = DBUS;
					reg_DP_out = reg_DP + 16'd1;
					next_cycle = CY_IND_GET_VH;
				end
			end
			//---------------------------------------------------------------
			// Get Final high value and setup PC for the Jump
			//---------------------------------------------------------------
			CY_IND_GET_VH: begin
				if (T0) begin
					reg_MAR_out = reg_DP;
				end
				else begin
					reg_PC_out = {DBUS, reg_DI};
					next_fetch();
				end
			end
			//=============================================================================
			// Indirect Zero page Indexed 
			//=============================================================================
			// Get Lookup byte Address
			CY_IND_IDZ_GET_AL: begin
				// Get the first byte
				if (T0) begin
					pc_to_mar();
				end
				else begin
					reg_DP_out = {8'h00, DBUS};
					next_cycle = CY_IND_IDZ_GET_VL;
				end
			end
			//---------------------------------------------------------------
			// Get the Lo Address part
			//---------------------------------------------------------------
			CY_IND_IDZ_GET_VL: begin
				if (T0) begin
					reg_MAR_out = (`index_mode == index_IXZ) ? (reg_DP + reg_X) & 16'h00FF : reg_DP;
				end
				else begin
					reg_DI_out = DBUS;
					reg_DP_out = (reg_DP + 16'd1) & 16'h00FF;  // ?? do we need of & 16'h00FF ??
					next_cycle = CY_IND_IDZ_GET_VH;
				end
			end
			//---------------------------------------------------------------
			// Get the Hi Address part
			//---------------------------------------------------------------
			CY_IND_IDZ_GET_VH: begin
				if (T0) begin
					reg_MAR_out = reg_DP;
				end
				else begin
                    reg_DP_out = {DBUS, reg_DI};

					// Here the operand address is complete
					case (`direction)
						dir_MR1B : next_cycle = CY_EXECUTE_MR;
						dir_RM1B : next_cycle = CY_EXECUTE_RM;      
						dir_MM1B : next_cycle = CY_EXECUTE_MM;
					default:
                        next_cycle = CY_TRAP;
					endcase
				end
			end
			//=============================================================================
			// Execute Register -> Memory
			//=============================================================================
			CY_EXECUTE_RM: begin
				if (T0) begin
					execute_Register_Memory();
					// <-- Here the result is ready to be written
					reg_MAR_out = calc_pointer(reg_DP); // Get effective address (using X,Y,Z-page if needed)
					// check page crossing
					empty_count_out = (`index_mode == index_X || `index_mode == index_Y) && (reg_MAR_out[15:8] != reg_DP[15:8]) ? 3'd1 : 3'd0;
					write_enable_out = true;
				end
				// <-- During this time (from T0 to T1) write line is LOW and the result is physically written to the memory
				else begin
					write_enable_out = false;
					if (empty_count != 0) 
						next_empty();
					else
						next_fetch();
				end
			end
			//=============================================================================
			// Execute Memory -> Register 
			//=============================================================================
			CY_EXECUTE_MR: begin
				if (T0) begin
					reg_MAR_out = calc_pointer(reg_DP); // Get effective address (using X,Y,Z-page if needed)
					// check page crossing to calc the empty cycle
					empty_count_out = (`index_mode == index_X || `index_mode == index_Y) && (reg_MAR_out[15:8] != reg_DP[15:8]) ? 3'd1 : 3'd0;
					// <-- Here we emit the address from which we want to read
				end
				// <-- During this time (from T0 to T1) write line is HIGH and the data is physically read from the memory
				else begin
					// <-- Here DBUS contains the operand ...
					execute_Memory_Register();	// ..and we can use it
					if (empty_count != 0) 
						next_empty();
					else
						next_fetch();
				end
			end		
			//=============================================================================
			// Execute Memory -> Memory 
			//=============================================================================
			CY_EXECUTE_MM: begin
				if (T0) begin
					reg_MAR_out = calc_pointer(reg_DP);
					// check page crossing
					empty_count_out = (`index_mode == index_X || `index_mode == index_Y) && (reg_MAR_out[15:8] != reg_DP[15:8]) ? 3'd1 : 3'd0;
				end
				else begin
					// Here DBUS contains the Memory value
					execute_Memory_Memory();
					next_cycle = CY_STORE_MM;
				end
			end
			//=============================================================================
			// Store Memory -> Memory
			//=============================================================================
			CY_STORE_MM: begin
				if (T0) begin
					// Here reg_DO_out contains the Memory value of the former cycle
					// and reg_MAR_out contains the Memory address already adjusted
					write_enable_out = true;
				end
				else begin
					write_enable_out = false;
					if (empty_count != 0) 
						next_empty();
					else
						next_fetch();
				end
			end
			//=============================================================================
			// Jump to Subroutine 
			//=============================================================================
			// Get Lo part of the address
			CY_JSR_GET_AL: begin
				if (T0) begin
					pc_to_mar();
				end
				else begin
					reg_DP_out = {8'h00, DBUS};
					next_cycle = CY_JSR_GET_AH;
				end
			end
			//-------------------------------------------------
			// Get Hi part of the address
			//-------------------------------------------------
			CY_JSR_GET_AH: begin
				if (T0) begin
					reg_MAR_out = reg_PC;  
				end
				else begin
					reg_DP_out[15:8] = DBUS;
					next_cycle = CY_JSR_PUSH_H;
				end
			end
			//-------------------------------------------------
			// Push Hi part of PC
			//-------------------------------------------------
			CY_JSR_PUSH_H: begin
				// Push PC_H
				if (T0) begin
					push(reg_PC[15:8]);						
				end 
				else begin
					write_enable_out = false;
					next_cycle = CY_JSR_PUSH_L; 
				end
			end
			//-------------------------------------------------
			// Jump to Subroutine - Push Lo part of PC 
			//-------------------------------------------------
			CY_JSR_PUSH_L: begin
				// Push PC_H
				if (T0) begin
					push(reg_PC[7:0]);						
				end 
				else begin
					write_enable_out = false;
					reg_PC_out = reg_DP; // <- And Jumps
					next_fetch();
				end
			end
			//=============================================================================
			// Return from Interrupt/Subroutine (RTI/RTS)
			//=============================================================================
			// Retrieve ST 
			CY_RET_POP_ST: begin // <-- RTI Jump point
				if (T0) begin
					pull();
				end
				else begin
					reg_ST_out = DBUS;
					next_cycle = CY_RET_POP_AL;
				end	
			end
			//-------------------------------------------------
			// Pull Lo part of the return address
			//-------------------------------------------------
			CY_RET_POP_AL: begin // <-- RTS Jump point
				if (T0) begin
					pull();
				end
				else begin
					reg_DP_out= {8'h00, DBUS};
					next_cycle = CY_RET_POP_AH;
				end	
			end
			//-------------------------------------------------
			// Pull Hi part of the return address
			//-------------------------------------------------
			CY_RET_POP_AH: begin
				if (T0) begin
					pull();
				end
				else begin
					reg_DP_out[15:8] = DBUS;
					next_cycle = CY_RET_EXECUTE;
				end	
			end
			//-------------------------------------------------
			// Jumps to the retrieved address
			//-------------------------------------------------
			CY_RET_EXECUTE: begin
				if (T1) begin
					if (`instruction_name == RTS) begin
                        reg_PC_out = reg_DP + 16'd1;    // We pushed Return address - 1 
                        empty_count_out = 3'd2;
                    end
                    else begin
                        reg_PC_out = reg_DP;            // We pushed Return address
                        empty_count_out = 3'd1;
                    end
					next_empty();
				end
			end
			//=============================================================================
			// Jump to Vector sequence (RES/NMI/IRQ/BRK)
			//=============================================================================
			CY_VECTOR_SEQUENCE_0: begin
				// Push PC_H
				if (T0) begin
					// If we are here due to a BRK instruction the async_pending will be 0
					// and we need to store PC + 1 instead of PC because BRK has a padding
					// byte after the opcode.
					// 6502 literature reports PC + 2, but here the PC is Fetch + 1, so we
					// need only to add 1.
					if (async_pending == no_pending)
						reg_DP_out = reg_PC + 16'd1;
					else
						reg_DP_out = reg_PC;

					push(reg_DP_out[15:8]);						
				end 
				else begin
					write_enable_out = false;
					next_cycle = CY_VECTOR_SEQUENCE_1;
				end
			end
			CY_VECTOR_SEQUENCE_1: begin
				// Push PC_L
				if (T0) begin
					push(reg_DP[7:0]);						
				end 
				else begin
					write_enable_out = false;
					next_cycle = CY_VECTOR_SEQUENCE_2;
				end
			end
			CY_VECTOR_SEQUENCE_2: begin
				// Push reg_ST
				if (T0) begin
					if (async_pending == no_pending)
						push(reg_ST | 8'b0001_0000);  // Set B-Flag on a BRK instruction
					else	
						push(reg_ST & 8'b1110_1111);  // Reset B-Flag in all the other
				end 
				else begin
					write_enable_out = false;
					next_cycle = CY_VECTOR_SEQUENCE_3;
				end
			end
			CY_VECTOR_SEQUENCE_3: begin
				// Get Vector L
				if (T0) begin
					case (async_pending)
						3'b000 : reg_DP_out = BRK_VECTOR;
						3'b001 : reg_DP_out = IRQ_VECTOR;
						3'b010 : reg_DP_out = NMI_VECTOR;
						3'b011 : reg_DP_out = IRQ_VECTOR; // Both NMI and IRQ, -> this was the IRQ handler
						default:
							reg_DP_out = RST_VECTOR;
					endcase
					reg_MAR_out = reg_DP_out;
				end
				else begin
					reg_DI_out = DBUS;
					next_cycle = CY_VECTOR_SEQUENCE_4;
				end
			end
			CY_VECTOR_SEQUENCE_4: begin
				// Get Vector H
				if (T0) begin
					reg_MAR_out = reg_DP + 16'd1;
				end
				else begin
					reg_PC_out = {DBUS, reg_DI};
					if (async_pending[`RST])
						init_on_reset();						
					else	
						reg_ST_out[I_flag] = true;
					
					empty_count_out = async_pending == no_pending ? 3'd1 : 3'd4;
					case (async_pending)
						3'b000 : begin // BRK instruction
							next_cycle = EXACT_TIMING ? CY_EMPTY : CY_FETCH_DECODE;
						end
						3'b011 : begin // Both NMI and IRQ, -> this was the IRQ handler : clear only IRQ and perform NMI
							async_pending_out[`IRQ] = 1'b0;
							next_cycle = EXACT_TIMING ? CY_EMPTY : CY_VECTOR_SEQUENCE_0;  					
						end
						default: begin // RST or NMI (without IRQ) or IRQ (without NMI)
							async_pending_out = no_pending;
							next_cycle = EXACT_TIMING ? CY_EMPTY : CY_FETCH_DECODE;  
						end
					endcase
				end
			end
			//*****************************************************************************
			// Empty Cycle : in order to be "exact cycle"
			//*****************************************************************************
			CY_EMPTY: begin
				if (T1) begin
					if (empty_count < 2) 
						next_fetch();
					else
						empty_count_out = empty_count - 3'd1;	
				end
			end
            CY_ILLEGAL_OPCODE : next_cycle = TRAP_ILLEGAL_OP == 1 ? CY_TRAP : CY_FETCH_DECODE;
            CY_TRAP: next_cycle = CY_TRAP;
			default:
				next_cycle = CY_RESET;
        endcase
    end

//---------------------------------------------------------------
// Physical lines
//---------------------------------------------------------------
	assign PHI1 = ~ck[2];
	assign PHI2 = ck[2];

	wire canwrite = write_enable && (ck > 1);
	assign RW_ = BE? !canwrite : 1'bz; 

    assign DBUS = (BE && canwrite) ? reg_DO : {8{1'bz}};

	assign ABUS = BE ? reg_MAR_out : {16{1'bz}};
	assign SYNC = (cycle == CY_FETCH_DECODE);
   
    assign TRAP = (cycle == CY_TRAP);

`include "initial_inc.v"  
`include "instr_table.v"  


endmodule
