//------------------------------------------------------------------------------
// Instruction Table
// A table indexed by the opcode. Every item (the instruction) contains:
// instruction_name - 6 bit -> Instruction[17:12]
// direction        - 3 bit -> Instruction[11:9]
// index_mode       - 3 bit -> Instruction[8:6]
// cycle_start      - 6 bit -> Instruction[5:0]
//------------------------------------------------------------------------------

integer i;
initial begin

    for (i = 0; i < 256; i = i + 1) begin
		itable[i] = CY_ILLEGAL_OPCODE;           
    end   

    // Implied short / Accumulator (2 bytes - 2 cycles)
    itable[CLC_IS]  = {CLC, dir_RR1B, no_index, CY_IMPLIED_SHORT}; // 18
    itable[CLD_IS]  = {CLD, dir_RR1B, no_index, CY_IMPLIED_SHORT}; // D8
    itable[CLI_IS]  = {CLI, dir_RR1B, no_index, CY_IMPLIED_SHORT}; // 58
    itable[CLV_IS]  = {CLV, dir_RR1B, no_index, CY_IMPLIED_SHORT}; // B8
    itable[DEX_IS]  = {DEX, dir_RR1B, no_index, CY_IMPLIED_SHORT}; // CA
    itable[DEY_IS]  = {DEY, dir_RR1B, no_index, CY_IMPLIED_SHORT}; // 88
    itable[INX_IS]  = {INX, dir_RR1B, no_index, CY_IMPLIED_SHORT}; // E8
    itable[INY_IS]  = {INY, dir_RR1B, no_index, CY_IMPLIED_SHORT}; // C8
    itable[NOP_IS]  = {NOP, dir_RR1B, no_index, CY_IMPLIED_SHORT}; // EA
    itable[SEC_IS]  = {SEC, dir_RR1B, no_index, CY_IMPLIED_SHORT}; // 38
    itable[SED_IS]  = {SED, dir_RR1B, no_index, CY_IMPLIED_SHORT}; // F8
    itable[SEI_IS]  = {SEI, dir_RR1B, no_index, CY_IMPLIED_SHORT}; // 78
    itable[TAX_IS]  = {TAX, dir_RR1B, no_index, CY_IMPLIED_SHORT}; // AA
    itable[TAY_IS]  = {TAY, dir_RR1B, no_index, CY_IMPLIED_SHORT}; // A8
    itable[TSX_IS]  = {TSX, dir_RR1B, no_index, CY_IMPLIED_SHORT}; // BA
    itable[TXA_IS]  = {TXA, dir_RR1B, no_index, CY_IMPLIED_SHORT}; // 8A
    itable[TXS_IS]  = {TXS, dir_RR1B, no_index, CY_IMPLIED_SHORT}; // 9A
    itable[TYA_IS]  = {TYA, dir_RR1B, no_index, CY_IMPLIED_SHORT}; // 98
    // Accumulator
    itable[ASL_ACC] = {ASL_A, dir_RR1B, no_index, CY_IMPLIED_SHORT}; // 0A
    itable[LSR_ACC] = {LSR_A, dir_RR1B, no_index, CY_IMPLIED_SHORT}; // 4A
    itable[ROL_ACC] = {ROL_A, dir_RR1B, no_index, CY_IMPLIED_SHORT}; // 2A
    itable[ROR_ACC] = {ROR_A, dir_RR1B, no_index, CY_IMPLIED_SHORT}; // 6A
    // Implied
    itable[PHA_IMP] = {PHA, dir_CTRL, no_index, CY_STACK_PUSH}; // 48
    itable[PHP_IMP] = {PHP, dir_CTRL, no_index, CY_STACK_PUSH}; // 08
    itable[PLA_IMP] = {PLA, dir_CTRL, no_index, CY_STACK_PULL}; // 68
    itable[PLP_IMP] = {PLP, dir_CTRL, no_index, CY_STACK_PULL}; // 28
    itable[BRK_IMP] = {BRK, dir_CTRL, no_index, CY_VECTOR_SEQUENCE_0}; // 00
    itable[RTI_IMP] = {RTI, dir_CTRL, no_index, CY_RET_POP_ST}; // 40
    itable[RTS_IMP] = {RTS, dir_CTRL, no_index, CY_RET_POP_AL}; // 60
    // Immediate
    itable[ADC_IMM] = {ADC, dir_MR1B, no_index, CY_IMMEDIATE}; // 69
    itable[AND_IMM] = {AND, dir_MR1B, no_index, CY_IMMEDIATE}; // 29
    itable[CMP_IMM] = {CMP, dir_MR1B, no_index, CY_IMMEDIATE}; // C9
    itable[CPX_IMM] = {CPX, dir_MR1B, no_index, CY_IMMEDIATE}; // E0
    itable[CPY_IMM] = {CPY, dir_MR1B, no_index, CY_IMMEDIATE}; // C0
    itable[EOR_IMM] = {EOR, dir_MR1B, no_index, CY_IMMEDIATE}; // 49 
    itable[LDA_IMM] = {LDA, dir_MR1B, no_index, CY_IMMEDIATE}; // A9
    itable[LDX_IMM] = {LDX, dir_MR1B, no_index, CY_IMMEDIATE}; // A2
    itable[LDY_IMM] = {LDY, dir_MR1B, no_index, CY_IMMEDIATE}; // A0
    itable[ORA_IMM] = {ORA, dir_MR1B, no_index, CY_IMMEDIATE}; // 09
    itable[SBC_IMM] = {SBC, dir_MR1B, no_index, CY_IMMEDIATE}; // E9
    // Absolute
    itable[ADC_ABS] = {ADC, dir_MR2B, no_index, CY_ABS_GET_AL}; // 6D
    itable[AND_ABS] = {AND, dir_MR2B, no_index, CY_ABS_GET_AL}; // 2D
    itable[ASL_ABS] = {ASL, dir_MM2B, no_index, CY_ABS_GET_AL}; // 0E
    itable[BIT_ABS] = {BIT, dir_MR2B, no_index, CY_ABS_GET_AL}; // 2C
    itable[CMP_ABS] = {CMP, dir_MR2B, no_index, CY_ABS_GET_AL}; // CD
    itable[CPX_ABS] = {CPX, dir_MR2B, no_index, CY_ABS_GET_AL}; // EC
    itable[CPY_ABS] = {CPY, dir_MR2B, no_index, CY_ABS_GET_AL}; // CC
    itable[DEC_ABS] = {DEC, dir_MM2B, no_index, CY_ABS_GET_AL}; // CE
    itable[EOR_ABS] = {EOR, dir_MR2B, no_index, CY_ABS_GET_AL}; // 4D
    itable[INC_ABS] = {INC, dir_MM2B, no_index, CY_ABS_GET_AL}; // EE
    itable[JMP_ABS] = {JMP, dir_MR2B, no_index, CY_ABS_GET_AL}; // 4C
    itable[LDA_ABS] = {LDA, dir_MR2B, no_index, CY_ABS_GET_AL}; // AD
    itable[LDX_ABS] = {LDX, dir_MR2B, no_index, CY_ABS_GET_AL}; // AE
    itable[LDY_ABS] = {LDY, dir_MR2B, no_index, CY_ABS_GET_AL}; // AC
    itable[LSR_ABS] = {LSR, dir_MM2B, no_index, CY_ABS_GET_AL}; // 4E
    itable[ORA_ABS] = {ORA, dir_MR2B, no_index, CY_ABS_GET_AL}; // 0D
    itable[ROL_ABS] = {ROL, dir_MM2B, no_index, CY_ABS_GET_AL}; // 2E
    itable[ROR_ABS] = {ROR, dir_MM2B, no_index, CY_ABS_GET_AL}; // 6E
    itable[SBC_ABS] = {SBC, dir_MR2B, no_index, CY_ABS_GET_AL}; // ED
    itable[STA_ABS] = {STA, dir_RM2B, no_index, CY_ABS_GET_AL}; // 8D
    itable[STX_ABS] = {STX, dir_RM2B, no_index, CY_ABS_GET_AL}; // 8E
    itable[STY_ABS] = {STY, dir_RM2B, no_index, CY_ABS_GET_AL}; // 8C
    // X-Indexed Absolute
    itable[ADC_XA]  = {ADC, dir_MR2B, index_X, CY_ABS_GET_AL}; // 7D
    itable[AND_XA]  = {AND, dir_MR2B, index_X, CY_ABS_GET_AL}; // 3D
    itable[ASL_XA]  = {ASL, dir_MM2B, index_X, CY_ABS_GET_AL}; // 1E
    itable[CMP_XA]  = {CMP, dir_MR2B, index_X, CY_ABS_GET_AL}; // DD
    itable[DEC_XA]  = {DEC, dir_MM2B, index_X, CY_ABS_GET_AL}; // DE
    itable[EOR_XA]  = {EOR, dir_MR2B, index_X, CY_ABS_GET_AL}; // 5D
    itable[INC_XA]  = {INC, dir_MM2B, index_X, CY_ABS_GET_AL}; // FE
    itable[LDA_XA]  = {LDA, dir_MR2B, index_X, CY_ABS_GET_AL}; // BD
    itable[LDY_XA]  = {LDY, dir_MR2B, index_X, CY_ABS_GET_AL}; // BC
    itable[LSR_XA]  = {LSR, dir_MM2B, index_X, CY_ABS_GET_AL}; // 5E
    itable[ORA_XA]  = {ORA, dir_MR2B, index_X, CY_ABS_GET_AL}; // 1D
    itable[ROL_XA]  = {ROL, dir_MM2B, index_X, CY_ABS_GET_AL}; // 3E
    itable[ROR_XA]  = {ROR, dir_MM2B, index_X, CY_ABS_GET_AL}; // 7E
    itable[SBC_XA]  = {SBC, dir_MR2B, index_X, CY_ABS_GET_AL}; // FD
    itable[STA_XA]  = {STA, dir_RM2B, index_X, CY_ABS_GET_AL}; // 9D
    // Y-Indexed Absolute
    itable[ADC_YA]  = {ADC, dir_MR2B, index_Y, CY_ABS_GET_AL}; // 79
    itable[AND_YA]  = {AND, dir_MR2B, index_Y, CY_ABS_GET_AL}; // 39
    itable[CMP_YA]  = {CMP, dir_MR2B, index_Y, CY_ABS_GET_AL}; // D9
    itable[EOR_YA]  = {EOR, dir_MR2B, index_Y, CY_ABS_GET_AL}; // 59
    itable[LDA_YA]  = {LDA, dir_MR2B, index_Y, CY_ABS_GET_AL}; // B9
    itable[LDX_YA]  = {LDX, dir_MR2B, index_Y, CY_ABS_GET_AL}; // BE
    itable[ORA_YA]  = {ORA, dir_MR2B, index_Y, CY_ABS_GET_AL}; // 19
    itable[SBC_YA]  = {SBC, dir_MR2B, index_Y, CY_ABS_GET_AL}; // F9
    itable[STA_YA]  = {STA, dir_RM2B, index_Y, CY_ABS_GET_AL}; // 99
    // Zero Page
    itable[ADC_Z]   = {ADC, dir_MR1B, index_Z, CY_ABS_GET_AL}; // 65
    itable[AND_Z]   = {AND, dir_MR1B, index_Z, CY_ABS_GET_AL}; // 25
    itable[ASL_Z]   = {ASL, dir_MM1B, index_Z, CY_ABS_GET_AL}; // 06
    itable[BIT_Z]   = {BIT, dir_MR1B, index_Z, CY_ABS_GET_AL}; // 24
    itable[CMP_Z]   = {CMP, dir_MR1B, index_Z, CY_ABS_GET_AL}; // C5
    itable[CPX_Z]   = {CPX, dir_MR1B, index_Z, CY_ABS_GET_AL}; // E4
    itable[CPY_Z]   = {CPY, dir_MR1B, index_Z, CY_ABS_GET_AL}; // C4
    itable[DEC_Z]   = {DEC, dir_MM1B, index_Z, CY_ABS_GET_AL}; // C6
    itable[EOR_Z]   = {EOR, dir_MR1B, index_Z, CY_ABS_GET_AL}; // 45
    itable[INC_Z]   = {INC, dir_MM1B, index_Z, CY_ABS_GET_AL}; // E6
    itable[LDA_Z]   = {LDA, dir_MR1B, index_Z, CY_ABS_GET_AL}; // A5
    itable[LDX_Z]   = {LDX, dir_MR1B, index_Z, CY_ABS_GET_AL}; // A6
    itable[LDY_Z]   = {LDY, dir_MR1B, index_Z, CY_ABS_GET_AL}; // A4
    itable[LSR_Z]   = {LSR, dir_MM1B, index_Z, CY_ABS_GET_AL}; // 46
    itable[ORA_Z]   = {ORA, dir_MR1B, index_Z, CY_ABS_GET_AL}; // 05
    itable[ROL_Z]   = {ROL, dir_MM1B, index_Z, CY_ABS_GET_AL}; // 26
    itable[ROR_Z]   = {ROR, dir_MM1B, index_Z, CY_ABS_GET_AL}; // 66
    itable[SBC_Z]   = {SBC, dir_MR1B, index_Z, CY_ABS_GET_AL}; // E5
    itable[STA_Z]   = {STA, dir_RM1B, index_Z, CY_ABS_GET_AL}; // 85
    itable[STX_Z]   = {STX, dir_RM1B, index_Z, CY_ABS_GET_AL}; // 86
    itable[STY_Z]   = {STY, dir_RM1B, index_Z, CY_ABS_GET_AL}; // 84
    // X-Indexed Zero Page
    itable[ADC_XZ]  = {ADC, dir_MR1B, index_XZ, CY_ABS_GET_AL}; // 75
    itable[AND_XZ]  = {AND, dir_MR1B, index_XZ, CY_ABS_GET_AL}; // 35
    itable[ASL_XZ]  = {ASL, dir_MM1B, index_XZ, CY_ABS_GET_AL}; // 16
    itable[CMP_XZ]  = {CMP, dir_MR1B, index_XZ, CY_ABS_GET_AL}; // D5
    itable[DEC_XZ]  = {DEC, dir_MM1B, index_XZ, CY_ABS_GET_AL}; // D6
    itable[EOR_XZ]  = {EOR, dir_MR1B, index_XZ, CY_ABS_GET_AL}; // 55
    itable[INC_XZ]  = {INC, dir_MM1B, index_XZ, CY_ABS_GET_AL}; // F6
    itable[LDA_XZ]  = {LDA, dir_MR1B, index_XZ, CY_ABS_GET_AL}; // B5
    itable[LDY_XZ]  = {LDY, dir_MR1B, index_XZ, CY_ABS_GET_AL}; // B4
    itable[LSR_XZ]  = {LSR, dir_MM1B, index_XZ, CY_ABS_GET_AL}; // 56
    itable[ROL_XZ]  = {ROL, dir_MM1B, index_XZ, CY_ABS_GET_AL}; // 36
    itable[ROR_XZ]  = {ROR, dir_MM1B, index_XZ, CY_ABS_GET_AL}; // 76
    itable[ORA_XZ]  = {ORA, dir_MR1B, index_XZ, CY_ABS_GET_AL}; // 15
    itable[SBC_XZ]  = {SBC, dir_MR1B, index_XZ, CY_ABS_GET_AL}; // F5
    itable[STA_XZ]  = {STA, dir_RM1B, index_XZ, CY_ABS_GET_AL}; // 95
    itable[STY_XZ]  = {STY, dir_RM1B, index_XZ, CY_ABS_GET_AL}; // 94
    // Y-Indexed Zero Page
    itable[LDX_YZ]  = {LDX, dir_MR1B, index_YZ, CY_ABS_GET_AL}; // B6
    itable[STX_YZ]  = {STX, dir_RM1B, index_YZ, CY_ABS_GET_AL}; // 96
    // Indirect
    itable[JMP_AI]  = {JMP, dir_CTRL, no_index, CY_IND_GET_AL}; // 6C
    // X-Indexed Zero Page Indirect
    itable[ADC_XIZ] = {ADC, dir_MR1B, index_IXZ, CY_IND_IDZ_GET_AL}; // 61
    itable[AND_XIZ] = {AND, dir_MR1B, index_IXZ, CY_IND_IDZ_GET_AL}; // 21
    itable[CMP_XIZ] = {CMP, dir_MR1B, index_IXZ, CY_IND_IDZ_GET_AL}; // C1
    itable[EOR_XIZ] = {EOR, dir_MR1B, index_IXZ, CY_IND_IDZ_GET_AL}; // 41
    itable[LDA_XIZ] = {LDA, dir_MR1B, index_IXZ, CY_IND_IDZ_GET_AL}; // A1
    itable[ORA_XIZ] = {ORA, dir_MR1B, index_IXZ, CY_IND_IDZ_GET_AL}; // 01  
    itable[SBC_XIZ] = {SBC, dir_MR1B, index_IXZ, CY_IND_IDZ_GET_AL}; // E1
    itable[STA_XIZ] = {STA, dir_RM1B, index_IXZ, CY_IND_IDZ_GET_AL}; // 81
    // Zero Page Indirect Y-Indexed
    itable[ADC_ZIY] = {ADC, dir_MR1B, index_IYZ, CY_IND_IDZ_GET_AL}; // 71
    itable[AND_ZIY] = {AND, dir_MR1B, index_IYZ, CY_IND_IDZ_GET_AL}; // 31
    itable[CMP_ZIY] = {CMP, dir_MR1B, index_IYZ, CY_IND_IDZ_GET_AL}; // D1
    itable[EOR_ZIY] = {EOR, dir_MR1B, index_IYZ, CY_IND_IDZ_GET_AL}; // 51
    itable[LDA_ZIY] = {LDA, dir_MR1B, index_IYZ, CY_IND_IDZ_GET_AL}; // B1
    itable[ORA_ZIY] = {ORA, dir_MR1B, index_IYZ, CY_IND_IDZ_GET_AL}; // 11  
    itable[SBC_ZIY] = {SBC, dir_MR1B, index_IYZ, CY_IND_IDZ_GET_AL}; // F1
    itable[STA_ZIY] = {STA, dir_RM1B, index_IYZ, CY_IND_IDZ_GET_AL}; // 91
    // Relative
    itable[BCC_R]   = {BCC, dir_CTRL, no_index, CY_RELATIVE}; // 90
    itable[BCS_R]   = {BCS, dir_CTRL, no_index, CY_RELATIVE}; // B0
    itable[BEQ_R]   = {BEQ, dir_CTRL, no_index, CY_RELATIVE}; // F0
    itable[BMI_R]   = {BMI, dir_CTRL, no_index, CY_RELATIVE}; // 30
    itable[BNE_R]   = {BNE, dir_CTRL, no_index, CY_RELATIVE}; // D0
    itable[BPL_R]   = {BPL, dir_CTRL, no_index, CY_RELATIVE}; // 10
    itable[BVC_R]   = {BVC, dir_CTRL, no_index, CY_RELATIVE}; // 50
    itable[BVS_R]   = {BVS, dir_CTRL, no_index, CY_RELATIVE}; // 70
    // JSR
    itable[JSR_ABS] = {JSR, dir_CTRL, no_index, CY_JSR_GET_AL}; // 20
end