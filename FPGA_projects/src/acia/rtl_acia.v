//==============================================================================
// Project SBC6502
//------------------------------------------------------------------------------
// ACIA (simil M6850) implementation
//------------------------------------------------------------------------------
// 2024 (c) Davide Nardella
// Released under MIT License
//==============================================================================
// sync_rs232_uart is (c) of Brian Guralnick
//==============================================================================
module rtl_acia #(
    parameter SYSCLK_MHZ = 27,
    parameter BAUD_RATE = 115200
)
(
    input   wire CLK,
    // Physical lines
    input   wire RXD,
    output  wire TXD,
    output  wire RTS,
    input   wire CTS,
    // Interface
    input   wire E,
    input   wire CS0,       // Chip select 0
    input   wire CS1,       // Chip select 1
    input   wire CS2_N,     // Chip select 2
    input   wire RS,        // Register select
    input   wire RW_N,      // Read/Write*    
    output  wire IRQ_N,     // IRQ* out
    inout   wire[7:0] DIO   // Data Bus
);
    localparam  false       = 1'b0;
    localparam  true        = 1'b1;

    assign RTS = false;

//===============================================================================
// RX/TX
//===============================================================================
	wire		rx_rdy;
	wire[7:0]	rx_data;
	reg [7:0] 	tx_data = 8'd0;
	reg			ena_tx = 1'b0;
	wire		tx_busy;
	
	sync_rs232_uart #(
		.SYSCLK_MHZ(SYSCLK_MHZ),
		.BAUD_RATE(BAUD_RATE)
	)
	RS232(
		.clk(CLK),
		.rxd(RXD),
		.rx_rdy(rx_rdy),
		.rx_data(rx_data),
		//------------------
		.ena_tx(ena_tx),
		.tx_data(tx_data),
		.txd(TXD),
		.tx_busy(tx_busy),
        .rx_sample_pulse()

	);

//===============================================================================
// UART
//===============================================================================

    reg[7:0]    status_reg  = 8'b0000_0010;
    reg[7:0]    ctrl_reg    = 0;
    reg[7:0]    data_rx     = 0;
    reg         irq         = 0;
    wire        ena;

    localparam  st_rx_buffer = 0;
    localparam  st_tx_buffer = 1;
    localparam  st_tx_irq    = 7;

    localparam  ct_irq_enable = 7;

    localparam  rx_data_available = true;
    localparam  rx_no_data        = false;
    localparam  rx_no_irq         = false;
    localparam  tx_buffer_empty   = true;
    localparam  tx_buffer_full    = false;
   
    localparam  TX_IDLE     = 0;
    localparam  START_TX    = 1;
    localparam  WAIT_TX     = 2;
    reg[1:0]    tx_state    = TX_IDLE;

    assign ena = E && CS0 && CS1 && !CS2_N;

    always @(posedge CLK)
    begin
        //--------------------------------------------
        // RX
        //--------------------------------------------
        if (rx_rdy) begin
            data_rx <= rx_data;                              // byte received
            status_reg[st_rx_buffer] <= rx_data_available;   // data available
            irq <= ctrl_reg[ct_irq_enable];                  // IRQ Line (if enabled)
            status_reg[st_tx_irq] <= ctrl_reg[ct_irq_enable];// IRQ bit (if enabled)
        end
        else
            if (ena && RS && RW_N) begin                     // Reading data_rx reg
                status_reg[st_rx_buffer] <= rx_no_data;      // no more data available
                irq <= rx_no_irq;                            // Reset IRQ line
                status_reg[st_tx_irq] <= rx_no_irq;          // Reset IRQ bit
            end
        //--------------------------------------------
        // TX
        //--------------------------------------------
        if (ena && !RS && !RW_N) begin
            ctrl_reg <= DIO;
            if (DIO[0] & DIO[1]) begin // Master reset
                status_reg <= 8'h00;
                irq <= rx_no_irq;   
            end
        end

        case (tx_state)
            TX_IDLE: begin
                if (ena && RS && !RW_N) begin               // Writing data
                    tx_data <= DIO;
                    ena_tx <= true;
                    tx_state <= START_TX;    
                    status_reg[st_tx_buffer]<=tx_buffer_full; // Lock further writing
                end           
            end
            START_TX: begin
                if (tx_busy) begin
                    ena_tx <= false;
                    tx_state <= WAIT_TX;                  
                end
            end
            WAIT_TX: begin
                if (!tx_busy) begin
                    tx_state <= TX_IDLE;
                    status_reg[st_tx_buffer] <= tx_buffer_empty;
                end
            end
            default:
                tx_state <= TX_IDLE;
        endcase
    end

    assign DIO = (ena && RW_N) ? RS ? data_rx : status_reg : {8{1'bz}};
    
    assign IRQ_N = !irq;

    initial begin
        tx_state    = TX_IDLE;
        status_reg  = 8'b1000_0010; // TX buffer empty
        ctrl_reg    = 8'd0;
        data_rx     = 8'd0;
        irq         = 1'b0;
    end

endmodule


