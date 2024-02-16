//==============================================================================
// Project SBC6502
//------------------------------------------------------------------------------
// Module POR (PowerOn-Reset) implementation
//------------------------------------------------------------------------------
// 2024 (c) Davide Nardella
// Released under MIT License
//==============================================================================
module poweron_reset 
#(
    parameter SYSCLK_MHZ = 27,
    parameter DELAY      = 500   // 500 ms
)
(
    input   wire CLK,
    output  wire RESET_,  // Negative pulse
    output  wire RESET    // Positive pulse
);

    localparam MILLISECONDS = (SYSCLK_MHZ * 1000 * DELAY) - 1; 

    reg[31:0] res_cnt;
    reg       reg_res;

    always @(posedge CLK)
    begin
        if (res_cnt < MILLISECONDS) 
            res_cnt <= res_cnt + 32'd1;
        else
            reg_res <= 1'b1;            
    end

    assign RESET_ = reg_res;
    assign RESET  = ~reg_res;

    initial begin
        res_cnt = 32'd0;
        reg_res = 1'b0;
    end

endmodule