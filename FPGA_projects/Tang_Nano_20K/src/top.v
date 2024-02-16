//===============================================================================================
// This project (for Tang Nano 20K) uses the SD based dynamic loading of the Basic.
// This because Tang Nano 20K has the SD-Card adapter (with all pins connected) onboard, so you
// don't need to buy an external adapter ;)
// Only a small micro-SD/SHDC FAT32 is required. Copy on it osi_bas.bin (folder /SBC6502_OSIBasic).
// If you still prefer a static load, then refer to Tang Nano 9k project wich is almost the same.
//===============================================================================================

`include "SBC6502_options.v"

module top(
    // Onboard
    input wire      sysclk,
    input wire      push_btn_A,
    input wire      push_btn_B,
    output[5:0]     sys_leds,
    // key & leds
    output wire     tm1638_stb,
    output wire     tm1638_clk,
    inout  wire     tm1638_dio,
    // SD Adapter          pin   FPGA  Nano-20k pin  
    output wire     sdclk,  //  5     83       -
    inout  wire     sdcmd,  //  3     82       -
    input  wire     sddat0, //  7     84       -
    output wire     sddat1, //  8     85    J6 pin 4
    output wire     sddat2, //  1     80    J5 pin 4
    output wire     sddat3, //  2     81       -
    // RS232
    input  wire     RXD, 
    output wire     TXD
);
    localparam SYSCLK_MHZ      = 27;       // System clock in MHz
    localparam BAUD_RATE       = 115200;   // RS232 Baudrate
    localparam EXACT_TIMING    = 1;        // Exact 6502 simulation (including empty cycles)
    localparam TRAP_ILLEGAL_OP = 1;        // Trap on illegal Opcode

    wire    cold_reset;
    wire    warm_reset;

    localparam false = 1'b0;
    localparam true  = 1'b1;

    wire[7:0]   QB; 
    wire[7:0]   IB;

//===============================================================================================
//  LED&KEY Driver Instance
//===============================================================================================

    wire numenable = 0;
    wire[31:0] number = 0;

    wire[7:0] ext_leds;
    wire[6:0] digits[0:7];
    wire[7:0] buttons;
    wire[7:0] dots = 8'b0000_0000;
      
    tm1638_driver #(.SYSCLK_MHZ(SYSCLK_MHZ)) // System clock in MHz 
    tm1638 (
        .sysclock(sysclk),        // System clock (route to the main clock line)
        .sysreset(!warm_reset),   // Reset (active high)
        .device_clk(tm1638_clk),  // route to clk physical line of tm1638 board
        .device_stb(tm1638_stb),  // route to stb physical line of tm1638 board
        .device_dio(tm1638_dio),  // route to dio physical line of tm1638 board 
        .D0(digits[0]),           // bitmap of Display 1 (leftmost) if numenable = 0
        .D1(digits[1]),           // bitmap of Display 2 if numenable = 0  
        .D2(digits[2]),           // bitmap of Display 3 if numenable = 0  
        .D3(digits[3]),           // bitmap of Display 4 if numenable = 0  
        .D4(digits[4]),           // bitmap of Display 5 if numenable = 0  
        .D5(digits[5]),           // bitmap of Display 6 if numenable = 0  
        .D6(digits[6]),           // bitmap of Display 7 if numenable = 0  
        .D7(digits[7]),           // bitmap of Display 8 (rightmost) if numenable = 0  
        .leds(ext_leds),          // leds bitmap (bit 0 = leftmost, bit 7 = rightmost)
        .dots(dots),              // dots bitmap (bit 0 = leftmost, bit 7 = rightmost)
        .hexnumber(number),       // 32 bit hex number to display if numenable = 1
        .numenable(numenable),    // = 1 shows hexnumber, = 0 shows D0(leftmost)..D7(rightmost)
        .buttons(buttons)         // buttons bitmap (bit 0 = leftmost, bit 7 = rightmost)
    );

    function [6:0] sseg(input[3:0] hex);
    begin
        case(hex)
            4'h0: sseg[6:0] = 7'b0111111;
            4'h1: sseg[6:0] = 7'b0000110;
            4'h2: sseg[6:0] = 7'b1011011;
            4'h3: sseg[6:0] = 7'b1001111;
            4'h4: sseg[6:0] = 7'b1100110;
            4'h5: sseg[6:0] = 7'b1101101;
            4'h6: sseg[6:0] = 7'b1111101;
            4'h7: sseg[6:0] = 7'b0000111;
            4'h8: sseg[6:0] = 7'b1111111;
            4'h9: sseg[6:0] = 7'b1101111;
            4'hA: sseg[6:0] = 7'b1110111;
            4'hB: sseg[6:0] = 7'b1111100;
            4'hC: sseg[6:0] = 7'b0111001;
            4'hD: sseg[6:0] = 7'b1011110;
            4'hE: sseg[6:0] = 7'b1111001;
            default: 
                  sseg[6:0] = 7'b1110001; // 4'hF
        endcase
    end
    endfunction

//===============================================================================================
// RESET
//===============================================================================================

    assign cold_reset = !push_btn_A;
    assign warm_reset = !push_btn_B;

//===============================================================================================
// SBC6502 BOARD
//===============================================================================================

    wire[15:0]  ADDR_BUS;        
    wire[7:0]   DATA_BUS; 

    SBC6502_SD #(
        .SYSCLK_MHZ(SYSCLK_MHZ),
        .BAUD_RATE(BAUD_RATE),
        .EXACT_TIMING(EXACT_TIMING),
        .TRAP_ILLEGAL_OP(TRAP_ILLEGAL_OP),
        .ROM_FILE_NAME("osi_bas.bin"), // File to load @ startup
        .ROM_FILE_NAME_LEN(11)         // It's length, including the dot (.)  
    )
    CPUBOARD(
        // Control
        .CLK(sysclk),
        .COLD_RESET_(cold_reset),
        .WARM_RESET_(warm_reset),
        // Debug
        .ADDR_BUS(ADDR_BUS),
        .DATA_BUS(DATA_BUS), 
        // SD-Card
        .sdclk (sdclk),
        .sdcmd (sdcmd),
        .sddat0(sddat0),   
        .sddat1(sddat1),
        .sddat2(sddat2),
        .sddat3(sddat3),
        // I/O
        .IB(IB),
        .QB(QB),
        // UART Interface 
        .RXD(RXD),
        .TXD(TXD)
    );
    
    assign ext_leds = QB;
    assign IB = buttons;

    assign digits[0] = 7'b111_1101; // 6 
    assign digits[1] = 7'b110_1101; // 5
    assign digits[2] = 7'b011_1111; // 0
    assign digits[3] = 7'b101_1011; // 2
    assign digits[4] = 7'h0;
    assign digits[5] = 7'b101_0000; // r
    assign digits[6] = 7'b001_1100; // u
    assign digits[7] = 7'b101_0100; // n
	    
    assign sys_leds[0] = true; 
    assign sys_leds[1] = true; 
    assign sys_leds[2] = true; 
    assign sys_leds[3] = true;  
    assign sys_leds[4] = true;
    assign sys_leds[5] = true;

endmodule                                       