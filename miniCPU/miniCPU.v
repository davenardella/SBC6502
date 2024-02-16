module miniCPU(
    input  wire CLK,
    input  wire RST_
);

    // Cycles
    localparam CY_RESET             = 6'h00; // CPU Reset
    localparam CY_FETCH_DECODE      = 6'h01; // Fetch and Decode
    localparam CY_GET_IMMEDIATE     = 6'h02; // Get an immediate operand (Constant)
    localparam CY_GET_OPERAND       = 6'h03; // Pick the address of the operand
    localparam CY_EXECUTE           = 6'h04; // Execute the instruction
    localparam CY_ILLEGAL_OPCODE    = 6'h3F; // Illegal (unknown) opcode fetched

    // Ocpodes
    localparam LDA_I                = 8'hA9;
    localparam LDA_M                = 8'hA5;
    localparam STA_M                = 8'h85;
    localparam ADC_I                = 8'h69;
    localparam ADC_M                = 8'h65;
    localparam NOP                  = 8'hEA;
    localparam JMP                  = 8'h4C;
    localparam JSR                  = 8'h20;
    localparam RTS                  = 8'h60;
    localparam PHA                  = 8'h48;
    localparam PLA                  = 8'h68;

	// Direction
	localparam dir_RM               = 2'b00;    // Register -> Memory
	localparam dir_MR               = 2'b01;    // Memory -> Register 
	localparam dir_CTRL             = 2'b10;    // Control Instruction (No Direction or stack based)

    // Registers (current state)
    reg[7:0]    A           = 8'd0;
    reg[7:0]    PC          = 8'd0;
    reg[7:0]    DP          = 8'd0;
    reg[7:0]    SP          = 8'd0;
    reg[7:0]    IR          = 8'd0;
    reg[7:0]    cycle       = CY_RESET;
    reg[7:0]    opcode      = 8'h00;

    // Registers (next state)
    reg[7:0]    A_out       = 8'd0;
    reg[7:0]    PC_out      = 8'd0;
    reg[7:0]    DP_out      = 8'd0;
    reg[7:0]    SP_out      = 8'd0;
    reg[7:0]    IR_out      = 8'd0;
    reg[7:0]    next_cycle  = CY_RESET;
    reg[7:0]    opcode_out  = 8'h00;

    // Instruction Table
    reg[7:0]    itable[0:255];
	reg[7:0]	instruction     = 8'd0;  // instruction record
	reg[7:0]	instruction_out = 8'd0;

	// Instruction fields
	`define 	direction			instruction[7:6]
	`define		cycle_start			instruction_out[5:0]

    // Memory
    reg[7:0]    mem[0:255];

    task execute_control();
    begin
        case(opcode)
            NOP: begin
                // Nothing to do 
            end
            // Return from subroutine
            RTS: begin
        		SP_out = SP + 8'd1;
                PC_out = mem[SP_out];
            end
            // Push Accumulator
            PHA: begin
                mem[SP] = A;
        		SP_out = SP - 8'd1;
            end
            // Pull Accumulator
            PLA: begin
        		SP_out = SP + 8'd1;
                A_out = mem[SP_out];
            end
        endcase
    end
    endtask

    task execute_memory_register();
    begin
        case(opcode)
            // Loads an immediate value to the accumulator
            LDA_I: begin
                A_out = IR;
            end
            // Loads a memory value to the accumulator
            LDA_M: begin
                A_out = mem[DP];
            end
            // Jumps to a new location
            JMP: begin
                PC_out = IR;
            end
            // Adds a constant to the accumulator
            ADC_I: begin
                A_out = A + IR;
            end
            // Adds a memory value to the accumulator
            ADC_M: begin
                A_out = A + mem[DP];
            end
            // Jump to subroutine
            JSR: begin
                mem[SP] = PC + 8'd1; // Push return address (PC + 1)
        		SP_out = SP - 8'd1;  // Decrements the Stack Pointer
                PC_out = IR;         // Loads the new address
            end
        endcase
    end
    endtask

    task execute_register_memory();
    begin
        case(opcode)
            // Store the accumulator in the memory
            STA_M: begin
                mem[DP] = A;
            end
        endcase
    end
    endtask

    always @(posedge CLK) 
    begin
        if (!RST_)
            cycle <= CY_RESET;
        else
            cycle <= next_cycle;
        // Next
        A <= A_out;
        PC <= PC_out;
        DP <= DP_out;
        SP <= SP_out;
        IR <= IR_out;
        opcode <= opcode_out;
        instruction <= instruction_out;
    end

    always @(*) 
    begin
        // Current
        next_cycle = cycle;
        A_out = A;
        PC_out = PC;
        DP_out = DP;
        SP_out = SP;
        IR_out = IR;
        opcode_out = opcode;
        instruction_out = instruction;
        // Cycle shift
        case (cycle)
            CY_RESET: begin
                if (RST_) begin // Waits until RST_ is high again
                    // Registers initialization
                    SP_out = 8'hFF;
                    A_out  = 8'h00;
                    PC_out = 8'h00;
                    DP_out = 8'h00;
                    // Jump to the first Fetch
                    next_cycle = CY_FETCH_DECODE;    
                end
            end
            CY_FETCH_DECODE: begin
                // Fetch
                opcode_out = mem[PC];
                // Decode (get Instruction Info)
                instruction_out = itable[opcode_out];
                // Increment PC for pointing to the next byte
                PC_out = PC + 8'd1;
                // Jumps to the first Instruction sequence step
                next_cycle = `cycle_start;
            end
            CY_GET_OPERAND: begin
                DP_out = mem[PC];     // Get the address of the operand
                next_cycle = CY_EXECUTE;
            end
            CY_GET_IMMEDIATE: begin
                IR_out = mem[PC];
                next_cycle = CY_EXECUTE;
            end
            CY_EXECUTE: begin
                case(`direction)
                    dir_CTRL: execute_control();
                    dir_MR: begin
                        PC_out = PC + 8'd1;
                        execute_memory_register();
                    end
                    dir_RM: begin
                        PC_out = PC + 8'd1;
                        execute_register_memory();
                    end
                endcase
                next_cycle = CY_FETCH_DECODE; // On the road again...
            end
            CY_ILLEGAL_OPCODE: begin
                next_cycle = CY_ILLEGAL_OPCODE; // stay here forever
            end
            default: // just to avoid compiler warnings
                next_cycle = CY_ILLEGAL_OPCODE; 
        endcase
    end
    
    integer i;
    initial begin
        // Clears the instruction Table and the memory
        for (i = 0; i < 256; i = i + 1) begin
                itable[i] = {2'b00, CY_ILLEGAL_OPCODE};           
                mem[i] = 8'h00;
        end   
        // Init the instruction Table
        itable[LDA_I] = {dir_MR,   CY_GET_IMMEDIATE};
        itable[LDA_M] = {dir_MR,   CY_GET_OPERAND};
        itable[STA_M] = {dir_RM,   CY_GET_OPERAND};
        itable[ADC_I] = {dir_MR,   CY_GET_IMMEDIATE};
        itable[ADC_M] = {dir_MR,   CY_GET_OPERAND};
        itable[NOP  ] = {dir_CTRL, CY_EXECUTE};
        itable[JMP  ] = {dir_MR,   CY_GET_IMMEDIATE};
        itable[JSR  ] = {dir_MR,   CY_GET_IMMEDIATE};
        itable[RTS  ] = {dir_CTRL, CY_EXECUTE};
        itable[PHA  ] = {dir_CTRL, CY_EXECUTE};
        itable[PLA  ] = {dir_CTRL, CY_EXECUTE};
        //-----------------------------------------------------
        // A small program to test all the instructions
        //-----------------------------------------------------
        //                          checkpoint
        // Load 4F in A             
        mem[8'h00] = LDA_I;        
        mem[8'h01] = 8'h4F;         // A = 4F 
        // Store A in $21
        mem[8'h02] = STA_M;         
        mem[8'h03] = 8'h21;       
        // Clear A
        mem[8'h04] = LDA_I;
        mem[8'h05] = 8'h00;         // A = 00
        // Load $21 in A to verify the previous store
        mem[8'h06] = LDA_M;
        mem[8'h07] = 8'h21;         // A = 4F
        // ADC $21 to A 
        mem[8'h08] = ADC_M;
        mem[8'h09] = 8'h21;         // A = 9E
        // ADC #$01 to A 
        mem[8'h0A] = ADC_I;
        mem[8'h0B] = 8'h01;         // A = 9F
                                    
        // JSR $80 
        mem[8'h0C] = JSR;
        mem[8'h0D] = 8'h80;         // PC = 80
        // Push A
        mem[8'h0E] = PHA;
        // Clear A
        mem[8'h0F] = LDA_I;
        mem[8'h10] = 8'h00;         // A = 00
        // JMP $85
        mem[8'h11] = JMP;
        mem[8'h12] = 8'h85;         // A = 00

        mem[8'h80] = LDA_I;
        mem[8'h81] = 8'hFF;
        mem[8'h82] = RTS;
                                    // PC = 0E

        mem[8'h85] = PLA;           // A = FF
        mem[8'h86] = NOP;           // <- The execution stops here due to 
                                    //    illegal opcode (00) in $87

    end
endmodule