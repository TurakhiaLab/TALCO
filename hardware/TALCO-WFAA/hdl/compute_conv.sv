module compute_conv #(
    parameter MAX_WAVEFRONT_LEN = 128,
    parameter LOG_MAX_WAVEFRONT_LEN = 8,
    parameter LOG_MAX_TILE_SIZE = 10,
    parameter MAX_TILE_SIZE = 1024,
	parameter TB_POINTER_WIDTH = 4,
	parameter DATA_WIDTH = 8
)(
	input logic clk, rst,
	input startCompute,
	
	input logic [LOG_MAX_TILE_SIZE-1:0] M_s_minus_2_k_minus_1, 
	input logic [LOG_MAX_TILE_SIZE-1:0] M_s_minus_2_k_plus_1,
	input logic [LOG_MAX_TILE_SIZE-1:0] M_s_minus_1_k,
	input logic [LOG_MAX_TILE_SIZE-1:0] I_s_minus_1_k_minus_1,	
	input logic [LOG_MAX_TILE_SIZE-1:0] D_s_minus_1_k_plus_1,
	
	input logic [2+LOG_MAX_WAVEFRONT_LEN:0] M_s_minus_2_k_minus_1_ID, 
	input logic [2+LOG_MAX_WAVEFRONT_LEN:0] M_s_minus_2_k_plus_1_ID,
	input logic [2+LOG_MAX_WAVEFRONT_LEN:0] M_s_minus_1_k_ID,
	input logic [2+LOG_MAX_WAVEFRONT_LEN:0] I_s_minus_1_k_minus_1_ID,	
	input logic [2+LOG_MAX_WAVEFRONT_LEN:0] D_s_minus_1_k_plus_1_ID,
	
	input logic valid_M_s_minus_2_k_minus_1,
	input logic valid_M_s_minus_2_k_plus_1,
	input logic valid_M_s_minus_1_k,
	input logic valid_I_s_minus_1_k_minus_1,	
	input logic valid_D_s_minus_1_k_plus_1,
	
	input logic [LOG_MAX_WAVEFRONT_LEN - 1: 0] marker, score,
	input logic signed [DATA_WIDTH - 1: 0]  k,
	
	output logic [LOG_MAX_TILE_SIZE-1:0] M_s_k,
    output logic [LOG_MAX_TILE_SIZE-1:0] I_s_k,
    output logic [LOG_MAX_TILE_SIZE-1:0] D_s_k,
	output logic [TB_POINTER_WIDTH-1:0] TB_k,
	
	output logic [2+LOG_MAX_WAVEFRONT_LEN:0] M_s_k_ID,
    output logic [2+LOG_MAX_WAVEFRONT_LEN:0] I_s_k_ID,
    output logic [2+LOG_MAX_WAVEFRONT_LEN:0] D_s_k_ID,
	
	output logic valid_M_s_k,
    output logic valid_I_s_k,
    output logic valid_D_s_k,
	
	output logic doneCompute
);
	
	logic [LOG_MAX_TILE_SIZE-1:0] temp;
    localparam IDLE = 0, ID =1 , M =2,TB = 3, DONE =4;
	logic [2:0] STATE;
	logic [1:0] TB_k_temp;

	assign valid_I_s_k = valid_M_s_minus_2_k_minus_1 | valid_I_s_minus_1_k_minus_1;
	assign valid_D_s_k = valid_M_s_minus_2_k_plus_1 | valid_D_s_minus_1_k_plus_1;
	assign valid_M_s_k = valid_M_s_minus_1_k | valid_I_s_k | valid_D_s_k;
	
	always_ff @(posedge clk) begin
        if(rst) begin
            STATE <= IDLE;
        end
        else begin
        $display("STATE = %d",STATE);
			case(STATE)
			
			    IDLE:begin
			         if(startCompute)
			             STATE<= ID;
			          else 
			             STATE <= IDLE;
			    end
				ID: begin
                    STATE <= M;
				end
				M: begin
					STATE <= TB;
				end
				TB: begin
					STATE <= DONE;
				end
				DONE: begin
					STATE <= IDLE;
				end
			endcase
        end
    end
	
	always_ff@(posedge clk) begin
		if(rst) begin
			I_s_k <= 0;
			M_s_k <= 0;
			D_s_k <= 0;
			TB_k <= 0;
			doneCompute <= 0;
		end
		else begin
			case(STATE)
                IDLE: begin
                end
				ID: begin
					if((valid_M_s_minus_2_k_minus_1) & (valid_I_s_minus_1_k_minus_1)) begin
						if(M_s_minus_2_k_minus_1 >= I_s_minus_1_k_minus_1) begin
							I_s_k <= M_s_minus_2_k_minus_1+1; //Offset calc
							if(score <= marker) begin //ID Calc
								I_s_k_ID <= '1;
							end
							else if(score == marker + 1) begin
								I_s_k_ID <= {1'b0,(k-1),2'b01};
							end
							else if(score == marker + 2) begin
								I_s_k_ID <= {1'b1,(k-1),2'b01};
							end
							else if(score > marker + 2) begin
								I_s_k_ID <= M_s_minus_2_k_minus_1_ID;
							end
						end
						else begin
							I_s_k <= I_s_minus_1_k_minus_1+1; //Offset calc
							if(score <= marker) begin //ID calc
								I_s_k_ID <= '1;
							end
							else if(score == marker + 1) begin
								I_s_k_ID <= {1'b1,(k-1),2'b01};
							end
							else if(score == marker + 2) begin
								I_s_k_ID <= I_s_minus_1_k_minus_1_ID;
							end
							else if(score > marker + 2) begin
								I_s_k_ID <= I_s_minus_1_k_minus_1_ID;
							end
						end
					end
					else if(valid_M_s_minus_2_k_minus_1 & !valid_I_s_minus_1_k_minus_1) begin
						I_s_k <= M_s_minus_2_k_minus_1+1; //Offset calc
						if(score <= marker) begin //ID calc
							I_s_k_ID <= '1;
						end
						else if(score == marker + 1) begin
							I_s_k_ID <= {1'b0,(k-1),2'b01};
						end
						else if(score == marker + 2) begin
							I_s_k_ID <= {1'b1,(k-1),2'b01};
						end
						else if(score > marker + 2) begin
							I_s_k_ID <= M_s_minus_2_k_minus_1_ID;
						end
					end

					else if(!valid_M_s_minus_2_k_minus_1 & valid_I_s_minus_1_k_minus_1) begin
						I_s_k <= I_s_minus_1_k_minus_1+1; //Offset calc
						if(score <= marker) begin //ID calc
							I_s_k_ID <= '1;
						end
						else if(score == marker + 1) begin
							I_s_k_ID <= {1'b1,(k-1),2'b01};
						end
						else if(score == marker + 2) begin
							I_s_k_ID <= I_s_minus_1_k_minus_1_ID;
						end
						else if(score > marker + 2) begin
							I_s_k_ID <= I_s_minus_1_k_minus_1_ID;
						end
					end
					else begin
						I_s_k <= '0; //Offset calc
						I_s_k_ID <= '1; //ID calc
					end
					


					if(valid_M_s_minus_2_k_plus_1 & valid_D_s_minus_1_k_plus_1) begin
						if(M_s_minus_2_k_plus_1 >= D_s_minus_1_k_plus_1) begin
							D_s_k <= M_s_minus_2_k_plus_1; //Offset calc
							if(score <= marker) begin //ID calc
								D_s_k_ID <= '1;
							end
							else if(score == marker + 1) begin
								D_s_k_ID <= {1'b0,(k+1),2'b10};
							end
							else if(score == marker + 2) begin
								D_s_k_ID <= {1'b1,(k+1),2'b10};
							end
							else if(score > marker + 2) begin
								D_s_k_ID <= M_s_minus_2_k_plus_1_ID;
							end
						end
						else begin
							D_s_k <= D_s_minus_1_k_plus_1; //Offset calc
							if(score <= marker) begin //ID calc
								D_s_k_ID <= '1;
							end
							else if(score == marker + 1) begin
								D_s_k_ID <= {1'b1,(k+1),2'b10};
							end
							else if(score == marker + 2) begin
								D_s_k_ID <= D_s_minus_1_k_plus_1_ID;
							end
							else if(score > marker + 2) begin
								D_s_k_ID <= D_s_minus_1_k_plus_1_ID;
							end
						end
					end
					else if(valid_M_s_minus_2_k_plus_1 & !valid_D_s_minus_1_k_plus_1) begin
						D_s_k <= M_s_minus_2_k_plus_1; //Offset calc
						if(score <= marker) begin //ID calc
							D_s_k_ID <= '1;
						end
						else if(score == marker + 1) begin
							D_s_k_ID <= {1'b0,(k+1),2'b10};
						end
						else if(score == marker + 2) begin
							D_s_k_ID <= {1'b1,(k+1),2'b10};
						end
						else if(score > marker + 2) begin
							D_s_k_ID <= M_s_minus_2_k_plus_1_ID;
						end
					end
					else if(!valid_M_s_minus_2_k_plus_1 & valid_D_s_minus_1_k_plus_1) begin
						D_s_k <= D_s_minus_1_k_plus_1; //Offset calc
						if(score <= marker) begin //ID calc
							D_s_k_ID <= '1;
						end
						else if(score == marker + 1) begin
							D_s_k_ID <= {1'b1,(k+1),2'b10};
						end
						else if(score == marker + 2) begin
							D_s_k_ID <= D_s_minus_1_k_plus_1_ID;
						end
						else if(score > marker + 2) begin
							D_s_k_ID <= D_s_minus_1_k_plus_1_ID;
						end
					end
					else begin
						D_s_k <= '0; //Offset calc
						D_s_k_ID <= '1; //ID calc
					end
					
				end

				M: begin
					if(valid_M_s_k) begin
						if((M_s_minus_1_k+1 >= I_s_k) && (M_s_minus_1_k+1 >= D_s_k) && valid_M_s_minus_1_k) begin
							M_s_k <= M_s_minus_1_k+1; //Offset calc
							if(score <= marker) begin //ID calc
								M_s_k_ID <= '1;
							end
							else if(score == marker + 1) begin
								M_s_k_ID <= {1'b1,k,2'b00};
							end
							else if(score == marker + 2) begin
								M_s_k_ID <= M_s_minus_1_k_ID;
							end
							else if(score > marker + 2) begin
								M_s_k_ID <= M_s_minus_1_k_ID;
							end
						end
						else if(I_s_k >= D_s_k) begin
							M_s_k <= I_s_k; //Offset calc
							M_s_k_ID <= I_s_k_ID; //ID calc
						end
						else if(D_s_k > I_s_k) begin
							M_s_k <= D_s_k; //Offset calc
							M_s_k_ID <= D_s_k_ID; //ID calc
						end
					end
					else begin
					   M_s_k <= 0; //Offset calc
					   M_s_k_ID <= '1; //ID calc
					end

					

				end
				TB: begin
					//TB calc
					if(M_s_k == (M_s_minus_1_k+1) && valid_M_s_minus_1_k)
						TB_k <= 4'b0000;
					else if(M_s_k == I_s_k && (valid_M_s_minus_2_k_minus_1 || valid_I_s_minus_1_k_minus_1)) begin
						if(I_s_k == (M_s_minus_2_k_minus_1+1) && valid_M_s_minus_2_k_minus_1)
							TB_k <= 4'b0101;
						else if(valid_I_s_minus_1_k_minus_1)
							TB_k <= 4'b0001;
					end
					else if(M_s_k == D_s_k && (valid_M_s_minus_2_k_plus_1 || valid_D_s_minus_1_k_plus_1)) begin
						if(D_s_k == M_s_minus_2_k_plus_1 && valid_M_s_minus_2_k_plus_1)
							TB_k <= 4'b1010;
						else if(valid_D_s_minus_1_k_plus_1)
							TB_k <= 4'b0010;
					end
					else
						TB_k <= 4'b1111;
				
				end
			  
			

				DONE: begin
					doneCompute <= 1;
				end
			endcase
		end
	end



	
endmodule: compute_conv
