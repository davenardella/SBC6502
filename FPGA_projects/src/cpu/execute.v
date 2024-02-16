//--------------------------------------------------------------------------
// REGISTER-REGISTER 
//--------------------------------------------------------------------------
// Implied instruction which don't have an explicit operand.
// I called them register-register because them don't access the memory.
// Note:
//   There areother implied (control) instructions such as push and pull;
//   they are executed directly into the FSM.
//--------------------------------------------------------------------------
task execute_Register_Register();
begin
    case(`instruction_name)
        //------------------------------------------------------------------
        // Implied short 
        //------------------------------------------------------------------
        // Clear Carry
        CLC: begin
            reg_ST_out[C_flag] = false;
        end
        // Clear D Flag
        CLD: begin
            reg_ST_out[D_flag] = false;
        end
        // Clear I Flag
        CLI: begin
            reg_ST_out[I_flag] = false;
        end
        // Clear V Flag
        CLV: begin
            reg_ST_out[V_flag] = false;
        end
        // X = X - 1
        DEX: begin
            reg_X_out = reg_X - 8'd1;
            set_ZN_flags(reg_X_out);
        end
        // Y = Y - 1
        DEY: begin
            reg_Y_out = reg_Y - 8'd1;
            set_ZN_flags(reg_Y_out);
        end
        // X = X + 1
        INX: begin
            reg_X_out = reg_X + 8'd1;
            set_ZN_flags(reg_X_out);
        end
        // Y = Y + 1
        INY: begin
            reg_Y_out = reg_Y + 8'd1;
            set_ZN_flags(reg_Y_out);
        end
        // Nothing to do
        NOP: begin
        end
        // Set Carry flag
        SEC: begin
            reg_ST_out[C_flag] = true;
        end
        // Set D flag
        SED: begin
            reg_ST_out[D_flag] = true;
        end
        // Set IRQB flag
        SEI: begin
            reg_ST_out[I_flag] = true;
        end
        // A -> X
        TAX: begin
            reg_X_out = reg_A;
            set_ZN_flags(reg_A);
        end
        // A -> Y
        TAY: begin
            reg_Y_out = reg_A;
            set_ZN_flags(reg_A);
        end
        // SP -> X
        TSX: begin
            reg_X_out = reg_SP; 
            set_ZN_flags(reg_SP);
        end
        // X -> A
        TXA: begin
            reg_A_out = reg_X;
            set_ZN_flags(reg_X);
        end
        // X -> SP
        TXS: begin
            reg_SP_out = reg_X; 
            // No flags affected here
        end
        // Y -> A
        TYA: begin
            reg_A_out = reg_Y;
            set_ZN_flags(reg_Y);
        end
        //------------------------------------------------------------------
        // Accumulator 
        //------------------------------------------------------------------
        // Shift Left A, Carry = Bit 7
        ASL_A:  begin
            {reg_ST_out[C_flag], reg_A_out} = {reg_A, 1'b0};
            set_ZN_flags(reg_A_out);
        end
        // Shift Right A, Carry = Bit 0
        LSR_A:  begin
            {reg_A_out, reg_ST_out[C_flag]} = {1'b0, reg_A};
            set_ZN_flags(reg_A_out);
        end
        // Rotate Left A
        ROL_A:  begin
            {reg_ST_out[C_flag], reg_A_out} = {reg_A, reg_ST[C_flag]};
            set_ZN_flags(reg_A_out);
        end
        ROR_A:  begin
            {reg_A_out, reg_ST_out[C_flag]} = {reg_ST[C_flag], reg_A};
            set_ZN_flags(reg_A_out);
        end
        default: begin
		end
    endcase
end
endtask
//--------------------------------------------------------------------------
// MEMORY-REGISTER 
//--------------------------------------------------------------------------
// Instructions that load a value from a memory cell, then modify it and  
// finally store it into a register (or flag) 
//--------------------------------------------------------------------------
task execute_Memory_Register(); 
begin: exec_mr
    reg[15:0] tmp;
    reg digital_carry;
    reg[4:0] D0;
    reg[4:0] D1;   

    D0 = 0;
    D1 = 0;
    digital_carry = 0;
    tmp   = 16'h00;

    case(`instruction_name)
        // A + M + C → A, C
        ADC: begin 
            if (reg_ST[D_flag]) begin // BCD Mode
                D0 = reg_A[3:0] + DBUS[3:0] + reg_ST[C_flag];
                if (D0 > 9) begin
                    D0 = D0 + 5'd6;
                    digital_carry = 1'b1;
                end
                else
                    digital_carry = 1'b0;
                D1 = reg_A[7:4] + DBUS[7:4] + digital_carry;
                if (D1 > 9) begin
                    D1 = D1 + 5'd6;                  
                    reg_ST_out[C_flag] = 1'b1;    
                end
                else
                    reg_ST_out[C_flag] = 1'b0;    
                reg_A_out = {D1[3:0], D0[3:0]};
                
            end
            else // Binary mode
                {reg_ST_out[C_flag], reg_A_out} = reg_A + DBUS + reg_ST[C_flag];
            
            reg_ST_out[V_flag] = (reg_A[7] == DBUS[7]) && (reg_A[7] != reg_A_out[7]);
            set_ZN_flags(reg_A_out);             
        end
        // A = A & DBUS
        AND: begin 
            reg_A_out = reg_A & DBUS;
            set_ZN_flags(reg_A_out);
        end
        // Bit Test
        BIT: begin
            reg_ST_out[N_flag] = DBUS[7];
            reg_ST_out[V_flag] = DBUS[6];
            reg_ST_out[Z_flag] = (reg_A & DBUS) == 8'd0; 
        end    
        // A - M
        CMP: begin 
            reg_ST_out[Z_flag] = reg_A == DBUS;
            reg_ST_out[C_flag] = reg_A >= DBUS;
            tmp[7:0] = reg_A - DBUS;           
            reg_ST_out[N_flag] = tmp[7];          
        end
        // X - M
        CPX: begin 
            reg_ST_out[Z_flag] = reg_X == DBUS;
            reg_ST_out[C_flag] = reg_X >= DBUS;
            tmp[7:0] = reg_X - DBUS;           
            reg_ST_out[N_flag] = tmp[7];          
        end
        // Y - M
        CPY: begin
            reg_ST_out[Z_flag] = reg_Y == DBUS;
            reg_ST_out[C_flag] = reg_Y >= DBUS;
            tmp[7:0] = reg_Y - DBUS;           
            reg_ST_out[N_flag] = tmp[7];          
        end
        // A ^ M
        EOR: begin 
            reg_A_out = reg_A ^ DBUS;
            set_ZN_flags(reg_A_out);
        end
        // M -> A
        LDA: begin
            reg_A_out = DBUS;
            set_ZN_flags(DBUS);
        end
        // M -> X
        LDX: begin 
            reg_X_out = DBUS;
            set_ZN_flags(DBUS);
        end
        // M -> Y
        LDY: begin 
            reg_Y_out = DBUS;
            set_ZN_flags(DBUS);
        end
        // A = A | DBUS
        ORA: begin 
            reg_A_out = reg_A | DBUS;
            set_ZN_flags(reg_A_out);
        end
        SBC: begin
            tmp = reg_A + (~DBUS) + reg_ST[C_flag];
            set_ZN_flags(tmp[7:0]);
            reg_ST_out[V_flag] = (reg_A[7] != tmp[7]) && (reg_A[7] != DBUS[7]);

            if (reg_ST[D_flag]) begin // BCD Mode
                if ((reg_A - (reg_ST[C_flag] ? 0 : 1) & 8'h0F) < (DBUS & 8'h0F))
                    tmp = tmp - 16'd6;

                if (tmp > 16'h0099)
                    tmp = tmp - 16'h0060;    
            end
            
            reg_ST_out[C_flag] = tmp < 16'h100; //(tmp[7:0] == 0) || !tmp[7];
            reg_A_out = tmp[7:0];
        end
		default: begin
		end
    endcase
end
endtask
//--------------------------------------------------------------------------
// REGISTER-MEMORY
//--------------------------------------------------------------------------
// Instructions that store a register into a memory cell addressed via one
// of the many available schemes
//--------------------------------------------------------------------------
task execute_Register_Memory(); 
begin
    case(`instruction_name)
        STA: begin
            reg_DO_out = reg_A;
        end    
        STX: begin
            reg_DO_out = reg_X;
        end    
        STY: begin
            reg_DO_out = reg_Y;
        end   
        default: begin
		end
    endcase
end
endtask

//--------------------------------------------------------------------------
// BRANCH 
//--------------------------------------------------------------------------
// Branch instructions, i.e. a conditional Jump.
//--------------------------------------------------------------------------
task execute_branch(input[15:0] offset);
begin: ex_br
    reg condition;
    
    // false condition : 2 cycles (+0)
    // true condition  : 3 cycles (+1)
    // true condition and page cross : 4 cycles (+2)

    case(`instruction_name)
        BCC: condition = !reg_ST[C_flag];
        BCS: condition = reg_ST[C_flag];
        BNE: condition = !reg_ST[Z_flag];
        BEQ: condition = reg_ST[Z_flag];
        BPL: condition = !reg_ST[N_flag];
        BMI: condition = reg_ST[N_flag];
        BVC: condition = !reg_ST[V_flag];
        BVS: condition = reg_ST[V_flag];
        default: 
            condition = false;
    endcase

    if (condition) begin
        reg_PC_out = reg_PC + offset;
        // check page-crossing to set the correct empty cycle count
        empty_count_out = (reg_PC[15:8] != reg_PC_out[15:8]) ? 3'd2 : 3'd1;
    end
    else 
        empty_count_out = 0; // Condition false
end
endtask

//--------------------------------------------------------------------------
// MEMORY-MEMORY
//--------------------------------------------------------------------------
// Instructions that modify a memory cell.
// The value is loaded using one of the addressing scheme, then is modified 
// here and finally is stored into the same address
//--------------------------------------------------------------------------
task execute_Memory_Memory();
begin
    case(`instruction_name)
        //------------------------------------------------------------------
        // Instructions with an operand
        //------------------------------------------------------------------
        INC: begin
            reg_DO_out = DBUS + 8'd1;
            set_ZN_flags(reg_DO_out);
        end    
        DEC: begin
            reg_DO_out = DBUS - 8'd1;
            set_ZN_flags(reg_DO_out);
        end
        ASL: begin
            {reg_ST_out[C_flag], reg_DO_out} = {DBUS, 1'b0};
            set_ZN_flags(reg_DO_out);
        end    
        LSR: begin
            {reg_DO_out, reg_ST_out[C_flag]} = {1'b0, DBUS};
            set_ZN_flags(reg_DO_out);
        end    
        ROL: begin
            {reg_ST_out[C_flag], reg_DO_out} = {DBUS, reg_ST[C_flag]};
            set_ZN_flags(reg_DO_out);
        end    
        ROR: begin
            {reg_DO_out, reg_ST_out[C_flag]} = {reg_ST[C_flag], DBUS};
            set_ZN_flags(reg_DO_out);
        end    
        default: begin
		end
    endcase

end
/* These (control/stack) instructions are Handled directly into FSM
    JMP
    JSR
    PHA
    PHP
    PLA
    PLP
    BRK
    RTI
    RTS
*/
endtask
