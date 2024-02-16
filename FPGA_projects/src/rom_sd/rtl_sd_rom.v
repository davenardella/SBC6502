//==============================================================================
// Project SBC6502
//------------------------------------------------------------------------------
// Single-Port ROM implementation with dynamic file preload via SD-Card
//------------------------------------------------------------------------------
// 2024 (c) Davide Nardella
// Released under MIT License
//==============================================================================
// sd_file_reader and its ancillary files are (c) of WuangXuan95
//==============================================================================

module rtl_sd_rom
#(
    parameter FILE_NAME_LEN = 11, // length of FILE_NAME (in bytes). Since the length of "example.txt" is 11, so here is 11.
    parameter [52*8-1:0] FILE_NAME = "example.txt", // file name to read, ignore upper and lower case
    parameter SYSCLK_MHZ = 100,
    parameter ADDR_WIDTH = 14,
    parameter DEPTH = 1 << ADDR_WIDTH,
	parameter BLANK = 8'h2E
)    
(
    // ROM Interface
	input wire[ADDR_WIDTH-1:0] A,  // Address bus
    output wire[7:0]           DO, // Data bus
    input wire CS_N,     // Chip Select (negated)
    input wire OE_N,     // Output Enable (negated)
    // SD Adapter Interface  pin
    output wire sdclk,   //   5  
    inout  wire sdcmd,   //   3  
    input  wire sddat0,  //   7  
    output wire sddat1,  //   8  
    output wire sddat2,  //   1  
    output wire sddat3,  //   2  
    // Control Interface
	input  wire clk,
	input  wire reload,
	output wire ldr_err,
    output wire ldr_busy,
	output wire ldr_end,
    output wire[31:0] file_size
);
	localparam false      = 1'b0;
	localparam true       = 1'b1;

    localparam IDLE       = 2'd0;
    localparam GET_FILE   = 2'd1;
    localparam FILL_BLANK = 2'd2;
    localparam WAIT_END   = 2'd3;

    localparam CLK_DIV = (SYSCLK_MHZ <= 50) ? 3'd2 : (SYSCLK_MHZ <= 100) ? 3'd3 : (SYSCLK_MHZ <= 200) ? 3'd4 : 3'd5; 
    
//    (* RAM_STYLE = "block" *)  
    (* ramstyle = "M9K" *)
    reg[7:0]			mem[0:DEPTH-1];

    reg[7:0]            data_out;
    reg[31:0]           file_cnt    = 0;
    reg[1:0]    		ldr_state   = IDLE;
    reg         		loader_busy = 0;
    reg         		loader_end  = 0;

	wire 		file_read;
	wire 		busy;
	wire 		scan;
	wire [3:0] 	card_stat;         // show the sdcard initialize status
	wire [1:0] 	card_type;         // 0=UNKNOWN    , 1=SDv1    , 2=SDv2  , 3=SDHCv2
	wire [1:0] 	filesystem_type;   // 0=UNASSIGNED , 1=UNKNOWN , 2=FAT16 , 3=FAT32 
	wire		file_found;        // 0=file not found, 1=file found
	wire       	outen;             // when outen=1, a byte of file content is read out from outbyte
	wire [7:0] 	outbyte;           // a byte of file content
    
    assign file_size = file_cnt;
//------------------------------------------------------------------------------
// SD Card reader
//------------------------------------------------------------------------------
    assign {sddat1, sddat2, sddat3} = 3'b111;    // Must set sddat1~3 to 1 to avoid SD card from entering SPI mode

    sd_file_reader #(
        .FILE_NAME_LEN    ( FILE_NAME_LEN  ),  // the length of "example.txt" (in bytes)
        .FILE_NAME        ( FILE_NAME      ),  // file name to read
        .CLK_DIV          ( CLK_DIV        )   // because clk=50MHz, CLK_DIV must ≥2
    ) u_sd_file_reader (
        .rstn             ( reload         ),
        .clk              ( clk            ),
        .sdclk            ( sdclk          ),
        .sdcmd            ( sdcmd          ),
        .sddat0           ( sddat0         ),
        .card_stat        ( card_stat      ),  // show the sdcard initialize status
        .card_type        ( card_type      ),  // 0=UNKNOWN    , 1=SDv1    , 2=SDv2  , 3=SDHCv2
        .filesystem_type  ( filesystem_type),  // 0=UNASSIGNED , 1=UNKNOWN , 2=FAT16 , 3=FAT32 
        .file_found       ( file_found     ),  // 0=file not found, 1=file found
        .scan             ( scan           ),
        .busy             ( busy           ),
        .file_read        ( file_read      ),
        .err              ( ldr_err        ),
        .outen            ( outen          ),
        .outbyte          ( outbyte        )
    );

//------------------------------------------------------------------------------
// FSM
//------------------------------------------------------------------------------
    always @(posedge clk)
    begin
       data_out <= mem[A];

        if (loader_end)
            loader_end <= false;
        case (ldr_state)
            IDLE: begin																				
                if (busy || !reload) begin																			
                    file_cnt <= 0;
                    loader_busy <= true;																		
                    ldr_state <= GET_FILE;																		
                end																			
            end																				
            // Get the file until the end or error or memory full																				
            GET_FILE: begin																				
                if (file_read) begin																			
                    ldr_state <= FILL_BLANK;	
                end																			
                else begin																			
                    if (!ldr_err) begin																		
                        if (outen) begin																	
                            if (file_cnt < DEPTH) begin																
                                mem[file_cnt] <= outbyte;															
                                file_cnt <= file_cnt + 1;
                            end																
                            else																
                                ldr_state <= WAIT_END;
                        end																	
                    end																		
                    else																		
                        ldr_state <= WAIT_END;
                end																			
            end																				
            // Fill with a blank char the memory unused																				
            FILL_BLANK: begin																				
                if (file_cnt < DEPTH) begin																			
                    mem[file_cnt] <= BLANK;																		
                    file_cnt <= file_cnt + 1;
                end																			
                else begin																			
                    loader_busy <= false;																		
                    loader_end <= true;
                    ldr_state <= IDLE;
                end
            end
            // Error or Size reached before file_read : wait until sd_reader finishes																				
            WAIT_END: begin																				
                if (!busy) begin																			
                    loader_busy <= false;
                    loader_end <= true;
                    ldr_state <= IDLE;																		
                end																			
            end																				
        endcase
    end

//------------------------------------------------------------------------------
// ROM Interface
//------------------------------------------------------------------------------

    assign DO = (!OE_N && !CS_N && !loader_busy) ? data_out : 8'bz;
	assign ldr_busy = ~loader_busy;
	assign ldr_end = loader_end;
    
	integer i;
    initial begin
		ldr_state   = IDLE;
		loader_busy = 0;
		loader_end  = 0;
    end

endmodule