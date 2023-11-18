`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/02/2023 08:00:54 PM
// Design Name: 
// Module Name: traceback_new
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module traceback #(
    parameter MAX_WAVEFRONT_LEN = 32,
	parameter LOG_MAX_WAVEFRONT_LEN = 5,
    parameter MAX_TILE_SIZE = 64,
    parameter LOG_MAX_TILE_SIZE = 6,
	parameter ADDR_WIDTH = 8,
	parameter DATA_WIDTH = 8
)(
input clk,
input rst,
input logic [LOG_MAX_WAVEFRONT_LEN-1: 0] start_diag, // decide length
input logic [LOG_MAX_WAVEFRONT_LEN - 1: 0] start_score,
input start_traceback,
input logic [DATA_WIDTH-1:0] width_data,
input logic [DATA_WIDTH-1:0] Kmin_data,
input logic [3:0] traceback_ptr_data,
input [1:0] tb_state,
output logic [ADDR_WIDTH-1:0] traceback_ptr_addr,
output logic [ADDR_WIDTH-1:0] Kmin_addr,
output logic [ADDR_WIDTH-1:0] width_addr,
output logic stop_traceback,
output logic [1:0] compact_cigar [MAX_WAVEFRONT_LEN-1:0],
output logic [LOG_MAX_WAVEFRONT_LEN -1:0] num_compact );

logic [ADDR_WIDTH-1:0] traceback_ptr_addr_temp;
//logic [ADDR_WIDTH-1:0] curr_bram_addr;

//localparam WAIT = 0, STALL = 1, TB1= 1, TB2 = 2, DONE = 3;
localparam WAIT = 0, TB1= 1, TB2 = 2, DONE = 3, WAIT1 = 4, WAIT2 = 5, WAIT3 = 6, WAIT4 = 7;
logic [3:0] STATE;
logic C1;


// logic [ADDR_WIDTH-1:0] curr_traceback_ptr_addr;
logic [1:0] curr_tb_state;
logic [LOG_MAX_WAVEFRONT_LEN - 1: 0] curr_score;
logic [LOG_MAX_WAVEFRONT_LEN-1: 0] curr_diag;


// logic [ADDR_WIDTH-1:0] next_traceback_ptr_addr;
logic [1:0] next_tb_state;
logic [LOG_MAX_WAVEFRONT_LEN - 1: 0] next_score;
logic [LOG_MAX_WAVEFRONT_LEN-1: 0] next_diag;
logic control;
logic [1:0] control2;
logic done;
logic [1:0] compact_cigar_val;
always_comb begin
    C1 = ($signed(next_score) <= 0) ? 1:0;
end
// assign traceback_ptr_addr = (control2!=2'b10)?{2'b00,{start_diag - Kmin_data + width_data}}:{2'b00,{next_diag - Kmin_data + width_data}};
assign Kmin_addr = (start_traceback)?((control == 0)?start_score:next_score):0;
assign width_addr = (start_traceback)?((control == 0)?start_score:next_score):0;;


always_comb begin
    if(rst || !start_traceback) begin
        traceback_ptr_addr <= 0;
    end
    else if(control2 == 2'b01) begin
        if(STATE == 2) begin
            traceback_ptr_addr <= traceback_ptr_addr_temp;
        end
        else begin
            traceback_ptr_addr <= {2'b00,{next_diag - Kmin_data + width_data}};
        end
    end 
    else if(control2 == 2'b00 || control2 == 2'b01) begin
        traceback_ptr_addr <= {2'b00,{start_diag - Kmin_data + width_data}};
    end
    else 
        traceback_ptr_addr <= traceback_ptr_addr_temp;
end


generate 
    addr_calculator #(
        .MAX_WAVEFRONT_LEN(MAX_WAVEFRONT_LEN),
        .MAX_TILE_SIZE(MAX_TILE_SIZE),
        .LOG_MAX_TILE_SIZE(LOG_MAX_TILE_SIZE),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) addr_calculate (
        .curr_tb_state(curr_tb_state),
        .score(curr_score),
        .diag(curr_diag),
        .traceback_ptr_data(traceback_ptr_data),
        .next_tb_state(next_tb_state),
        .next_score(next_score),
        .next_diag(next_diag),
        .done(done),
        .compact_cigar_val(compact_cigar_val),
        .STATE(STATE)

    );
endgenerate

always_ff@(posedge clk) begin
    if(rst) begin
        curr_tb_state <= 0;
        curr_score <= 0;
        curr_diag <= 0;
        num_compact <= 0;
        traceback_ptr_addr_temp <= 0;
        stop_traceback <= 0;
    end
    else begin
        case(STATE)
            WAIT: begin
                curr_tb_state <= tb_state;
                curr_score <= start_score;
                curr_diag <= start_diag;
                traceback_ptr_addr_temp <= 0;
                num_compact <= 0;
            end

            TB1: begin
                curr_tb_state <= curr_tb_state;
                curr_score <= curr_score;
                curr_diag <= curr_diag;
                
                if(control2 ==11)
                    traceback_ptr_addr_temp <= traceback_ptr_addr;
                traceback_ptr_addr_temp <= traceback_ptr_addr;
                
            end

            TB2: begin
                curr_tb_state <= next_tb_state;
                curr_score <= next_score;
                curr_diag <= next_diag;
                num_compact <= num_compact + 8'b00000001;
                compact_cigar[num_compact] <= compact_cigar_val; 
            end

            DONE: begin
                stop_traceback <= 1;
            end
        endcase
    end
end

always_ff@(posedge clk) begin
    $display("control 2 = %b", control2);
    if (rst) begin
       STATE <= WAIT; 
       control <= 0;
       control2 <= 0;
    end
    else begin
        case (STATE)
            WAIT: begin
                if (start_traceback) begin
                    STATE <= WAIT1;
                end
            end 
			
			WAIT1: begin
                    STATE <= WAIT2;
            end
			
			WAIT2: begin
                    STATE <= WAIT3;
            end
            
            WAIT3: begin
                    STATE <= WAIT4;
            end
			
			WAIT4: begin
                    STATE <= TB1;
            end

            TB1: begin
                STATE <= TB2;
                if(control2== 2'b11 || control2 == 2'b10) 
                    control2 <= 2'b10;
                else 
                    control2 <= 2'b01;
                control <= 1;
            end

            TB2: begin

                if (C1 || done) begin
                    STATE <= DONE;
                end
                else begin
                    STATE <= WAIT1;
                end
            end

            DONE: begin
                
            end
        endcase 
    end
end

endmodule

module addr_calculator #(
    parameter MAX_WAVEFRONT_LEN = 256,
	parameter LOG_MAX_WAVEFRONT_LEN = 8,
    parameter MAX_TILE_SIZE = 1024,
    parameter LOG_MAX_TILE_SIZE = 10,
	parameter ADDR_WIDTH = 10,
	parameter DATA_WIDTH = 8
)(
    input logic [1:0] curr_tb_state,
    input logic [LOG_MAX_WAVEFRONT_LEN - 1: 0] score,
    input logic [LOG_MAX_WAVEFRONT_LEN - 1: 0] diag,
    input logic [3:0] traceback_ptr_data,
    input logic [3:0] STATE,

    output logic [1:0] next_tb_state,
    output logic [LOG_MAX_WAVEFRONT_LEN - 1: 0] next_diag,
    output logic [LOG_MAX_WAVEFRONT_LEN - 1: 0] next_score,
    output logic done,
    output logic [1:0] compact_cigar_val
);

    logic [3:0] curr_tb_value;
    always_comb begin
        curr_tb_value = traceback_ptr_data[3:0];
        done = 0;
        
        if((STATE == 0 || STATE == 1)) begin
            next_diag = diag;
            next_score = score;
            next_tb_state =  curr_tb_state[1:0];
            compact_cigar_val = 2'b11;
        end
        else if((STATE == 2 || STATE == 3)) begin
            case(curr_tb_state)
                2'b00: begin
                    if(curr_tb_value[1:0] == 2'b00) begin
                        next_diag = diag;
                        next_score = score-1;
                        next_tb_state = 2'b00;
                        compact_cigar_val = 2'b00;
                    end
                    else if(curr_tb_value[1:0] == 2'b01) begin
                        compact_cigar_val = 2'b01;
                        if(curr_tb_value[2]==1) begin
                            next_tb_state = 2'b01;
                            next_diag = diag-1;
                            next_score = score-2;
                        end
                        else begin
                            next_tb_state = 2'b00;
                            next_diag = diag-1;
                            next_score = score-1;
                        end
                    end
                    else if(curr_tb_value[1:0] == 2'b10) begin
                        compact_cigar_val = 2'b10;
                        if(curr_tb_value[3]==1) begin
                            next_tb_state = 2'b10;
                            next_diag = diag+1;
                            next_score = score-2;
                        end
                        else begin
                            next_tb_state = 2'b00;
                            next_diag = diag+1;
                            next_score = score-1;
                        end
                    end
                    else begin
                        compact_cigar_val = 2'b11;
                        next_diag = diag;
                        next_score = score-1;
                        next_tb_state = curr_tb_state[1:0];
                        done = 1;
                    end
                    
                end
                2'b01: begin
                    compact_cigar_val = 2'b01;
                    if(curr_tb_value[2]==1) begin
                        
                        next_tb_state = 2'b01;
                        next_diag = diag-1;
                        next_score = score-2;
                    end
                    else begin
                        next_tb_state = 2'b00;
                        next_diag = diag-1;
                        next_score = score-1;
                    end
                end
                2'b10: begin
                    compact_cigar_val = 2'b10;
                    
                    if(curr_tb_value[3]==1) begin
                        
                        next_tb_state = 2'b10;
                        next_diag = diag+1;
                        next_score = score-2;
                        //$display("score = %d, next_score = %d",score, next_score);
                    end
                    else begin
                        next_tb_state = 2'b00;
                        next_diag = diag+1;
                        next_score = score-1;
                    end
                end
                default: begin
                    compact_cigar_val = 2'b11;
                    next_diag = diag;
                    next_score = score-1;
                    next_tb_state = curr_tb_state[1:0];
                    done  = 1;

                end

            endcase
        end
        else begin
            next_diag = diag;
            next_score = score;
            next_tb_state =  curr_tb_state[1:0];
            compact_cigar_val = 2'b11;
        end
		/*else begin
			compact_cigar_val = 2'b11;
			next_diag = diag;
			next_score = score-1;
			next_tb_state = curr_tb_state[1:0];
			done  = 1;
		end*/
        

    end

endmodule
