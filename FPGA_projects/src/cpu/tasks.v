	// Shift latched values
	task set_current();
	begin
		reg_A <= reg_A_out;
		reg_X <= reg_X_out;
		reg_Y <= reg_Y_out;
		reg_PC <= reg_PC_out;
		reg_SP <= reg_SP_out;
		reg_ST <= reg_ST_out;
		reg_DI <= reg_DI_out;
		reg_DP <= reg_DP_out;
		reg_DO <= reg_DO_out;
		reg_MAR<=reg_MAR_out;
		instruction <= instruction_out;
		empty_count <= empty_count_out;
		write_enable <= write_enable_out;
	end
	endtask
	
	// init out values to avoid latch infer
	task set_next();
	begin
        next_cycle = cycle;
		reg_A_out = reg_A;
		reg_X_out = reg_X;
		reg_Y_out = reg_Y;
		reg_PC_out = reg_PC;
		reg_SP_out = reg_SP;
		reg_ST_out = reg_ST;
		reg_DI_out = reg_DI;
		reg_DP_out = reg_DP;
		reg_DO_out = reg_DO;
		reg_MAR_out=reg_MAR;
		instruction_out = instruction;
		empty_count_out = empty_count;
		async_pending_out = async_pending;
		write_enable_out = write_enable;
	end
	endtask

	// Reset activities
	task init_on_reset();
	begin
		reg_DP_out   = 16'h0000;		
		reg_A_out    = A_INIT;
		reg_X_out    = X_INIT;
		reg_Y_out    = Y_INIT;
		reg_SP_out   = SP_INIT;
		reg_ST_out   = ST_INIT;
		reg_DO_out   = 8'h00;
	end
	endtask

	function [15:0] pagezero(input[15:0] address);
	begin
		pagezero = {8'b00000000, address[7:0]};
	end
	endfunction

	function [15:0] calc_pointer(input[15:0] address);
	begin		
		case (`index_mode)
			index_Z  : calc_pointer = {8'h00, address[7:0]};
			index_X  : calc_pointer = reg_X + address;
			index_Y  : calc_pointer = reg_Y + address;
			index_XZ : calc_pointer = (reg_X + address) & 16'h00FF;
			index_YZ : calc_pointer = (reg_Y + address) & 16'h00FF;
            index_IYZ: calc_pointer = reg_Y + address;
            // note: for index_IXZ the pointer is already adjusted
		default:
			calc_pointer = address;		
		endcase
	end
	endfunction

	// Checks for int/nmi pending
	task next_fetch;
	begin
        next_cycle = (async_pending == no_pending) ? CY_FETCH_DECODE : CY_VECTOR_SEQUENCE_0;
	end
	endtask

	task next_empty();
	begin	
		if (async_pending == no_pending)
			next_cycle = EXACT_TIMING == 1 ? CY_EMPTY : CY_FETCH_DECODE;
		else
			next_cycle = CY_VECTOR_SEQUENCE_0;
	end
	endtask

	task pc_to_mar();
	begin
		reg_MAR_out = reg_PC;
		reg_PC_out = reg_PC + 16'd1;
	end
	endtask

	task set_ZN_flags(input[7:0] value);
	begin
        reg_ST_out[Z_flag] = value == 8'd0;
        reg_ST_out[N_flag] = value[7]; 
	end
	endtask

	task push(input[7:0] value);
	begin
		reg_MAR_out = {8'h01, reg_SP}; 
		reg_SP_out = reg_SP - 8'd1;
		reg_DO_out = value;
		write_enable_out = true;
	end
	endtask

	task pull();
	begin
		reg_SP_out = reg_SP + 8'd1;
		reg_MAR_out = {8'h01, reg_SP_out};
	end
	endtask
