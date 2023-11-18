module thresholdCalc #(
    parameter MAX_WAVEFRONT_LEN = 32,
    parameter LOG_MAX_TILE_SIZE = 6,
    parameter DATA_WIDTH = 8,
    parameter REF_LEN_WIDTH = 8,
    parameter QUERY_LEN_WIDTH = 8
)(
    input logic clk,
    input logic rst,
    input logic start,
    input logic [DATA_WIDTH - 1: 0] numDiag,
    input logic [LOG_MAX_TILE_SIZE - 1: 0] OffsetReg [MAX_WAVEFRONT_LEN - 1: 0],
    input logic [DATA_WIDTH - 1: 0]  Kmin,
    input logic [DATA_WIDTH - 1: 0]  Kmax,
    input logic [QUERY_LEN_WIDTH - 1: 0] queryLen,
    input logic [REF_LEN_WIDTH - 1: 0] refLen,
	input logic valid_M_s_minus_1_temp [MAX_WAVEFRONT_LEN - 1: 0],
	
	output logic [REF_LEN_WIDTH - 1: 0] threshold,
    output logic done
);
	localparam IDLE = 0, PRE= 1, CALC = 2, DONE = 3;
    logic [2:0] STATE;
	
	logic signed [$clog2(MAX_WAVEFRONT_LEN):0] [MAX_WAVEFRONT_LEN-1:0] [LOG_MAX_TILE_SIZE:0] stage_data;
	reg [LOG_MAX_TILE_SIZE -1: 0] stage;
	
	always_ff @(posedge clk) begin
        if(rst) begin
            STATE <= IDLE;
        end
        else begin
			case(STATE)
			    IDLE: begin
			        done <= 0;
			        if(start) begin
						STATE <= PRE;
					end
			    end
				PRE: begin
					for(int j=0; j<MAX_WAVEFRONT_LEN; j++) begin
						if(j <= numDiag+1 && valid_M_s_minus_1_temp[j]) begin
							stage_data[0][j] <= OffsetReg[j];
						end
						else begin
							stage_data[0][j] <= '1;
						end
				end
					STATE <= CALC;
					stage <= 'd0;
				end
				CALC: begin
					if(stage < $clog2(MAX_WAVEFRONT_LEN)) begin
						stage <= stage + 'd1;
						for(int i = 0; i < (MAX_WAVEFRONT_LEN); i+=2) begin
						  //if(i < MAX_WAVEFRONT_LEN-2) begin
							stage_data[stage+1][i/2] <= ($signed(stage_data[stage][i]) >= $signed(stage_data[stage][i+1])) ? stage_data[stage][i] : stage_data[stage][i+1];	
						  //end
						end
						STATE <= CALC;
					end
					else begin
						STATE <= DONE;
					end
				end
				DONE: begin
					threshold <= (queryLen - stage_data[$clog2(MAX_WAVEFRONT_LEN)][0] + 10); //Final threshold calc
					done <= 1;
					STATE <= IDLE;
				end
			endcase
            
        end
    end
	
endmodule: thresholdCalc
