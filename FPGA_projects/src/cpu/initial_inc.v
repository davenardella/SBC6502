initial begin

reg_A       = 0; // Accumulator
reg_X       = 0; // Index X
reg_Y       = 0; // Index Y
reg_PC      = 0; // Program Counter
reg_SP      = 0; // Stack Pointer
reg_ST      = 0; // Status registers (Flags)
reg_A_out   = 0; // Accumulator
reg_X_out   = 0; // Index X
reg_Y_out   = 0; // Index Y
reg_PC_out  = 0; // Program Counter
reg_SP_out  = 0; // Stack Pointer
reg_ST_out  = 0; // Status registers (Flags)
reg_DI      = 0; // Data In buffer
reg_DO      = 0; // Data Out buffer
reg_DP      = 0; // Data Pointer 
reg_MAR     = 0; // Memory address register
reg_MAR_out = 0; // Memory address register
reg_DI_out  = 0; // Data In buffer
reg_DP_out  = 0; // Data Pointer 


empty_count = 0;
empty_count_out = 0;
cycle           = CY_WAIT_RESET;
next_cycle      = CY_WAIT_RESET; 

async_pending     = 3'b00;
async_pending_out = 3'b00;

write_enable = 0;	// Write cycle

instruction = 18'd0;
instruction_out = 18'd0;

ck = 3'd0;

end