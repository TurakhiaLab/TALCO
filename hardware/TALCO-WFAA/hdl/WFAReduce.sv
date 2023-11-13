module WFAReduce #(
    parameter MAX_WAVEFRONT_LEN = 128,
    parameter LOG_MAX_TILE_SIZE = 10,
    parameter DATA_WIDTH = 8,
    parameter REF_LEN_WIDTH = 14,
    parameter QUERY_LEN_WIDTH = 14
)(
    input logic clk,
    input logic rst,
    input logic start,
    input logic [LOG_MAX_TILE_SIZE - 1: 0] OffsetReg [MAX_WAVEFRONT_LEN - 1: 0],
    input logic signed [DATA_WIDTH - 1: 0]  Kmin,
    input logic signed [DATA_WIDTH - 1: 0]  Kmax,
    input logic [QUERY_LEN_WIDTH - 1: 0] queryLen,
    input logic [REF_LEN_WIDTH - 1: 0] refLen,
	input logic [REF_LEN_WIDTH - 1: 0] threshold,
	input logic valid_M_s_minus_1_temp [MAX_WAVEFRONT_LEN - 1: 0],
    
    output logic signed [DATA_WIDTH - 1: 0]  KminNew,
    output logic signed [DATA_WIDTH - 1: 0]  KmaxNew,
    output logic done
);
	
	logic [$clog2(MAX_WAVEFRONT_LEN):0] [MAX_WAVEFRONT_LEN-1:0] [LOG_MAX_TILE_SIZE - 1:0] stage_data;
	logic [$clog2(MAX_WAVEFRONT_LEN):0] [MAX_WAVEFRONT_LEN-1:0] stage_valid;
	logic [1:0] reduce;
	logic signed [DATA_WIDTH - 1: 0] Kmin_New, Kmax_New;
	logic [LOG_MAX_TILE_SIZE - 1: 0] reductionData [(MAX_WAVEFRONT_LEN) - 1: 0];
	logic reductionDataValid [(MAX_WAVEFRONT_LEN) - 1: 0];
	logic [DATA_WIDTH - 1: 0] numDiag;
	
	assign numDiag = Kmax - Kmin + 1;

	localparam IDLE = 1, PRE_MIN= 2, REDUCE_MIN = 3, REDUCE_MAX = 4, DONE = 5;
    logic [2:0] STATE;
	
	reg [LOG_MAX_TILE_SIZE -1: 0] stage;

	
	always_ff @(posedge clk) begin
        if(rst) begin
            STATE <= IDLE;
			reduce <= 0;
			for(int i = 0; i < MAX_WAVEFRONT_LEN; i++) begin
				stage_data[0][i] <=  0;
				stage_valid[0][i] <= 0;
				reductionData[i] <= 0;
				reductionDataValid[i] <= 0;
			end
			KminNew <= Kmin;
			KmaxNew <= Kmax;
        end
        else begin
			case(STATE)
			    IDLE: begin
					done <= 0;
					for(int j=0; j<MAX_WAVEFRONT_LEN; j++) begin
						if(j <= numDiag+1 && valid_M_s_minus_1_temp[j]) begin
							reductionData[j] <= OffsetReg[j];
							reductionDataValid[j] <= 1;
						end
						else begin
							reductionData[j] <= OffsetReg[j];
							reductionDataValid[j] <= 0;
						end
					end
			        if(start) begin
						STATE <= PRE_MIN;
					end
			    end
				PRE_MIN: begin
					for(int i = 0; i < MAX_WAVEFRONT_LEN; i++) begin
						stage_data[0][i] <= (reductionDataValid[i] == 1'b1) ? i: 0;
						stage_valid[0][i] <= (reductionDataValid[i] == 1'b1) ? ((queryLen - reductionData[i] >= refLen - $signed($signed(reductionData[i]) - $signed($signed(Kmin) + $signed(i)))) ? (queryLen - reductionData[i] <= threshold) : (refLen - $signed($signed(reductionData[i]) - $signed($signed(Kmin) + $signed(i))) <= threshold)) : 0;
					end
					reduce <= 2'b10;
					stage <= 'd0;
					STATE <= REDUCE_MIN;
				end
				REDUCE_MIN: begin
					//KminNew <= Kmin_New;
					if(stage < $clog2(MAX_WAVEFRONT_LEN)) begin
						stage <= stage + 'd1;
						for(int i = 0; i < (MAX_WAVEFRONT_LEN); i+=2) begin
						  //if(i < MAX_WAVEFRONT_LEN-2) begin
							if(stage_valid[stage][i+reduce[0]] == 1) begin
								stage_data[stage+1][i/2] <= stage_data[stage][i+reduce[0]];
								stage_valid[stage+1][i/2] <= stage_valid[stage][i+reduce[0]];
							end
							else begin
								stage_data[stage+1][i/2] <= stage_data[stage][i+reduce[1]];
								stage_valid[stage+1][i/2] <= stage_valid[stage][i+reduce[1]];
							end
						  end
						//end
						STATE <= REDUCE_MIN;
					end
					else begin
						KminNew <= stage_valid[$clog2(MAX_WAVEFRONT_LEN)][0] ? stage_data[$clog2(MAX_WAVEFRONT_LEN)][0] + Kmin : Kmin;
						reduce <= 2'b01;
						stage <= 'd0;
						STATE <= REDUCE_MAX;
					end
				end
				REDUCE_MAX: begin
					//KmaxNew <= Kmax_New;
					if(stage < $clog2(MAX_WAVEFRONT_LEN)) begin
						stage <= stage + 'd1;
						for(int i = 0; i < (MAX_WAVEFRONT_LEN); i+=2) begin
						  //if(i < MAX_WAVEFRONT_LEN-2) begin
							if(stage_valid[stage][i+reduce[0]] == 1) begin
								stage_data[stage+1][i/2] <= stage_data[stage][i+reduce[0]];
								stage_valid[stage+1][i/2] <= stage_valid[stage][i+reduce[0]];
							end
							else begin
								stage_data[stage+1][i/2] <= stage_data[stage][i+reduce[1]];
								stage_valid[stage+1][i/2] <= stage_valid[stage][i+reduce[1]];
							end
						  //end
						end
						STATE <= REDUCE_MAX;
					end
					else begin
						KmaxNew <= stage_valid[$clog2(MAX_WAVEFRONT_LEN)][0] ? stage_data[$clog2(MAX_WAVEFRONT_LEN)][0] + Kmin: Kmax;
						STATE <= DONE;
					end
				end
				DONE: begin
					done <= 1;
                    STATE <= IDLE;
				end
			endcase
        end
    end


endmodule: WFAReduce
