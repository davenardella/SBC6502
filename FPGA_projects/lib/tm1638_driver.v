//***********************************************************************************************
// TM1638 LED&KEY driver
//-----------------------------------------------------------------------------------------------
// 2023 (c) Davide Nardella
// Released under MIT License
//***********************************************************************************************
module tm1638_driver(
	input wire sysclock,         // System clock
	input wire sysreset,         // System reset
	// phisical 
	output wire device_clk,
	output reg device_stb,
    inout wire device_dio,
	// Digits
    input wire[6:0] D0,
    input wire[6:0] D1,
    input wire[6:0] D2,
    input wire[6:0] D3,
    input wire[6:0] D4,
    input wire[6:0] D5,
    input wire[6:0] D6,
    input wire[6:0] D7,
    // leds and buttons
	input wire[7:0] leds,
	input wire[7:0] dots,
    input wire[31:0] hexnumber,
    input wire numenable,
	output wire[7:0] buttons
);
	parameter SYSCLK_MHZ = 27;   // How many MHz is System clock

    localparam SETUP      = 8'b1000_1111; // 0x8F Display ON and High duty cycle
    localparam INCADD     = 8'b0100_0000; // 0x40 : incremental address
    localparam MODEREAD   = 8'b0100_0010; // 0x42 : mode readkey
    localparam FIRSTADD   = 8'b1100_0000; // 0xC0 : first address = 0
	
// States    
    localparam RESET_ST   = 5'd0;   // Reset Start
    localparam RESET_WB   = 5'd1;   // Reset Wait Busy
    localparam RESET_WE   = 5'd2;   // Reset Wait End   
    localparam RESET_WA   = 5'd3;   // Reset Wait 

    localparam MODEA_ST   = 5'd4;   // Mode address Start
    localparam MODEA_WB   = 5'd5;   // Mode address wait busy
    localparam MODEA_WE   = 5'd6;   // Wait end 
    localparam MODEA_WA   = 5'd7;   // WAIT

    localparam WRITE_ST   = 5'd8;   // ST = Start
    localparam WRITE_WB   = 5'd9;   // WB = Wait Busy
    localparam WRITE_WE   = 5'd10;  // WE = Wait End
    localparam WRITE_WA   = 5'd11;  // WE = Wait End

    localparam MODER_ST   = 5'd12;   // Mode read key Start
    localparam MODER_WB   = 5'd13;   // Mode read key wait busy
    localparam MODER_WE   = 5'd14;   // Wait end 
    localparam MODER_WA   = 5'd15;   // WAIT

    localparam READ_ST    = 5'd16;  // ST = Start
    localparam READ_WB    = 5'd17;  // WB = Wait Busy
    localparam READ_WE    = 5'd18;  // WE = Wait End
    localparam READ_WA    = 5'd19;  // Wait before READ
       
       
// readbyte interface	
	reg rd_clock;
	wire rd_busy;
	reg rd_start = 0;
	reg[7:0] rd_data;
	
// writebyte interface	
	reg wr_clock;
	wire wr_busy;
	reg wr_start = 0;
	reg[7:0] wr_data = 8'd0;
		
// internals	
	reg selfreset = 1'b1;
    reg[7:0] clkcnt = 8'd0;
	reg driver_clock = 1'b0;     
    wire[7:0] wr_frame[0:16];
    reg[7:0] rd_frame[0:3];     

    reg[7:0] pwstb = 8'd0;       // wait time counter
    reg[4:0] cnt_frame = 5'd0;   // Frame Counter
    reg[4:0] state = RESET_ST;

	reg device_dout;
	wire device_din;
    wire device_write;

    assign wr_frame[0]  = FIRSTADD;

    assign wr_frame[1]  = numenable ? {dots[0:0], sseg(hexnumber[31:28])} : {dots[0:0], D0[6:0]}; 
    assign wr_frame[2]  = leds[0:0];
    assign wr_frame[3]  = numenable ? {dots[1:1], sseg(hexnumber[27:24])} : {dots[1:1], D1[6:0]};
    assign wr_frame[4]  = leds[1:1];
    assign wr_frame[5]  = numenable ? {dots[2:2], sseg(hexnumber[23:20])} : {dots[2:2], D2[6:0]};
    assign wr_frame[6]  = leds[2:2];
    assign wr_frame[7]  = numenable ? {dots[3:3], sseg(hexnumber[19:16])} : {dots[3:3], D3[6:0]};
    assign wr_frame[8]  = leds[3:3];

    assign wr_frame[9]  = numenable ? {dots[4:4], sseg(hexnumber[15:12])} : {dots[4:4], D4[6:0]};
    assign wr_frame[10] = leds[4:4];
    assign wr_frame[11] = numenable ? {dots[5:5], sseg(hexnumber[11:8])} : {dots[5:5], D5[6:0]};
    assign wr_frame[12] = leds[5:5];

    assign wr_frame[13] = numenable ? {dots[6:6], sseg(hexnumber[7:4])} : {dots[6:6], D6[6:0]};
    assign wr_frame[14] = leds[6:6];
    assign wr_frame[15] = numenable ? {dots[7:7], sseg(hexnumber[3:0])} : {dots[7:7], D7[6:0]};
    assign wr_frame[16] = leds[7:7];

//***************************************************************************** 
// Write Byte
//***************************************************************************** 
    // States
    localparam WR_IDLE = 1'd0;
    localparam WR_SEND = 1'd1;

    reg wr_state = WR_IDLE;
    reg[3:0] wr_cnt = 4'd0;
    
    assign wr_busy = (wr_state == WR_SEND);

// OneShot
    reg wr_os_up;
    reg FF_wr;

    always @(posedge sysclock)
    begin
        if (sysreset) begin    
            FF_wr <= 0;
            wr_os_up <= 0;
        end
        else begin
            FF_wr <= driver_clock;
            wr_os_up <= driver_clock & ~FF_wr;
        end
    end
    
    always @(posedge sysclock)
    begin
        if (sysreset) begin
            wr_state <= WR_IDLE;
            wr_cnt <= 0;
            wr_clock <= 1;
            device_dout <= 1;
        end
        else begin
            if (wr_os_up) begin
                if (wr_state == WR_IDLE) begin
                    if (wr_start) begin
                        wr_cnt <= 0;
                        wr_clock <= 0;
                        device_dout <= wr_data[4'd0];
                        wr_state <= WR_SEND;
                    end
                end
                else begin // state == WR_SEND
                    if (!wr_clock) begin
                        wr_clock <= 1;
                        wr_cnt <= wr_cnt + 4'd1;
                    end
                    else begin
                        if (wr_cnt < 4'd8) begin
                            device_dout <= wr_data[wr_cnt];
                            wr_clock <= 0;
                        end
                        else begin
                            wr_state <= WR_IDLE;
                            device_dout <= 1;
                        end    
                    end                                                          
                end
            end
        end
    end

//***************************************************************************** 
// Read Byte
//***************************************************************************** 
    // States
    localparam RD_IDLE = 1'd0;
    localparam RD_RECV = 1'd1;

    reg rd_state = RD_IDLE;
    reg[3:0] rd_cnt = 4'd0;
    
    assign rd_busy = (rd_state == RD_RECV);

// OneShot
    reg rd_os_up;
    reg FF_rd;

    always @(posedge sysclock)
    begin
        if (sysreset) begin    
            FF_rd <= 0;
            rd_os_up <= 0;
        end
        else begin
            FF_rd <= driver_clock;
            rd_os_up <= driver_clock & ~FF_rd;
        end
    end

    always @(posedge sysclock)
    begin
        if (sysreset) begin
            rd_state <= RD_IDLE;
            rd_cnt <= 0;
            rd_clock <= 1;           
            rd_data <= 8'd0;
        end
        else begin
            if (rd_os_up) begin
                if (rd_state == RD_IDLE) begin
                    if (rd_start) begin
                        rd_cnt <= 0;
                        rd_clock <= 0;
                        rd_state <= RD_RECV;
                    end
                end
                else begin // rd_state == RD_RECV
                    if (!rd_clock) begin
                        rd_data[rd_cnt] <= device_din;
                        rd_clock <= 1;
                        rd_cnt <= rd_cnt + 4'd1;
                    end
                    else begin
                        if (rd_cnt < 4'd8) begin
                            rd_clock <= 0;
                        end
                        else 
                            rd_state <= RD_IDLE;
                    end                                                          
                end          
            end
        end
    end
  
//***************************************************************************** 
    assign buttons[0:0] = rd_frame[0][0];
    assign buttons[1:1] = rd_frame[1][0];
    assign buttons[2:2] = rd_frame[2][0];
    assign buttons[3:3] = rd_frame[3][0];
    assign buttons[4:4] = rd_frame[0][4];
    assign buttons[5:5] = rd_frame[1][4];
    assign buttons[6:6] = rd_frame[2][4];
    assign buttons[7:7] = rd_frame[3][4];

    assign device_write = (state >= RESET_ST) && (state <= MODER_WA);

    assign device_clk = device_write ? wr_clock : rd_clock;
    assign device_dio = (device_write & ~device_dout) ? 1'b0 : 1'bz;
    assign device_din = device_dio;

	always @(posedge sysclock)
	begin   
        if (sysreset | selfreset)
        begin
			clkcnt <= 8'd0;
            driver_clock <= 1'b0;
            wr_start <= 1'b0;   // Drop wr start

            rd_start <= 1'b0;   // Drop rd start
            wr_data <= 8'd0;
            rd_frame[0] <= 8'd0;
            rd_frame[1] <= 8'd0;
            rd_frame[2] <= 8'd0;
            rd_frame[3] <= 8'd0;
          
            
            device_stb <= 1'b1; // Strobe off (high) 
            pwstb <=8'd0;
            cnt_frame <= 5'd0;
            selfreset <= 1'b0;
            state <= RESET_ST;
        end
        else begin
            // Driver Clock 
			if(clkcnt>=SYSCLK_MHZ) begin
				clkcnt <= 0;
				driver_clock <= ~driver_clock;  // 500 KHz clock
			end
            else
                clkcnt <= clkcnt + 8'd1;
            // States management
            case (state)
                // --------------------------------------------- Reset Cycle
                RESET_ST: begin
                    wr_data <= SETUP;
                    device_stb <= 1'b0;      // Strobe active (low)
                    wr_start <= 1'b1;        // Raise Start
                    state <= RESET_WB;
                end    
                RESET_WB: begin             // Wait Busy ON
                    if (wr_busy) begin
                        wr_start <= 1'b0;   // Drop start
                        state <=RESET_WE;
                    end
                end
                RESET_WE: begin             // Wait Busy OFF
                    if (!wr_busy) begin
                        device_stb <= 1'b1;// Strobe off (high)                       
                        pwstb <= 8'd0;
                        state <= RESET_WA;
                    end                   
                end
                RESET_WA: begin
                    if(pwstb>=SYSCLK_MHZ) 
                        state <= MODEA_ST;
                    else
                        pwstb <= pwstb + 8'd1;                                
                end           
                // --------------------------------------------- Mode Address Cycle
                MODEA_ST: begin
                    wr_data <= INCADD;
                    device_stb <= 1'b0; // Strobe active (low)
                    wr_start <= 1'b1;        // Raise Start
                    state <= MODEA_WB;                  
                end
                MODEA_WB: begin
                    if (wr_busy) begin
                        wr_start <= 1'b0;   // Drop start
                        state <=MODEA_WE;
                    end                    
                end
                MODEA_WE: begin
                    if (!wr_busy) begin
                        device_stb <= 1'b1;// Strobe off (high)                       
                        pwstb <= 8'd0;
                        state <= MODEA_WA;                      
                    end
                end
                MODEA_WA: begin
                    if(pwstb>=SYSCLK_MHZ) begin
                        state <= WRITE_ST;
                        device_stb <= 1'b0; // Strobe active (low)
                        cnt_frame<=0;
                    end
                    else
                        pwstb <= pwstb + 8'd1;                                
                end         
                // --------------------------------------------- Write Cycle
                WRITE_ST: begin
                    wr_data <= wr_frame[cnt_frame];
                    wr_start <= 1'b1;        // Raise Start
                    state <= WRITE_WB;               
                end
                WRITE_WB: begin
                    if (wr_busy) begin
                        wr_start <= 1'b0;   // Drop start
                        state <=WRITE_WE;
                    end                    
                end
                WRITE_WE: begin             // Wait Busy OFF
                    if (!wr_busy) begin
                        if (cnt_frame==16) begin
                            device_stb <= 1'b1;// Strobe off (high)                       
                            pwstb <= 0;
                            state <= WRITE_WA;                           
                        end
                        else begin
                            cnt_frame <= cnt_frame + 5'd1;
                            state <= WRITE_ST;
                        end
                    end
                end
                WRITE_WA: begin
                    if(pwstb>=SYSCLK_MHZ) 
                        state <= MODER_ST;
                    else
                        pwstb <= pwstb + 8'd1;                                
                end
                // --------------------------------------------- Command Readkey
                MODER_ST: begin
                    wr_data <= MODEREAD;
                    device_stb <= 1'b0;   // Strobe active (low)
                    wr_start <= 1'b1;     // Raise Start
                    state <= MODER_WB;
                end
                MODER_WB: begin
                    if (wr_busy) begin
                        wr_start <= 1'b0;   // Drop start
                        state <=MODER_WE;
                    end                    
                end
                MODER_WE: begin
                    if (!wr_busy) begin
                        pwstb <= 8'd0;
                        state <= MODER_WA;                      
                    end
                end
                MODER_WA: begin
                    if(pwstb>=SYSCLK_MHZ) begin
                        cnt_frame<= 5'd0;
                        state <= READ_ST;
                    end
                    else
                        pwstb <= pwstb + 8'd1;                                
                end         
                // --------------------------------------------- Read Cycle
                READ_ST: begin
                    rd_start <= 1'b1;        // Raise Start
                    state <= READ_WB;               
                end
                READ_WB: begin
                    if (rd_busy) begin
                        rd_start <= 1'b0;   // Drop start
                        state <=READ_WE;
                    end                    
                end
                READ_WE: begin             // Wait Busy OFF
                    if (!rd_busy) begin
                        rd_frame[cnt_frame] <= rd_data;
                        if (cnt_frame==3) begin
                            device_stb <= 1'b1;// Strobe off (high)                       
                            pwstb <= 0;
                            state <= READ_WA;                           
                        end
                        else begin
                            cnt_frame <= cnt_frame + 5'd1;
                            state <= READ_ST;
                        end
                    end
                end
                READ_WA: begin
                    if(pwstb>=SYSCLK_MHZ) 
                        state <= MODEA_ST;
                    else
                        pwstb <= pwstb + 8'd1;                                
                end

                default:
                    state <= RESET_ST;

            endcase
           
        end
	end

    initial begin
        selfreset = 1'b0;
    end

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

endmodule

