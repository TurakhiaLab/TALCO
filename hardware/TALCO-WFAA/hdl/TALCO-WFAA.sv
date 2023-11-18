module TALCO_WFAA #(
    parameter NUM_EXTEND = 4,
    parameter MAX_WAVEFRONT_LEN = 32,
	parameter LOG_MAX_WAVEFRONT_LEN = 5,
    parameter DATA_WIDTH = 8,
    parameter BLOCK_WIDTH = 8,
    parameter MAX_TILE_SIZE = 64,
    parameter LOG_MAX_TILE_SIZE = 6,
    parameter REF_LEN_WIDTH = 8,
    parameter QUERY_LEN_WIDTH =8,
	parameter ADDR_WIDTH = 8,
	parameter NUM_COMPUTE = 4,
	parameter TB_POINTER_WIDTH = 4,
	parameter SEQ = 16
    )(
    input clk,
    input rst,
    input [DATA_WIDTH - 1: 0] globalKmin,
    input [DATA_WIDTH - 1: 0] globalKmax,
    input loadData,
    input [DATA_WIDTH - 1: 0] queryData,
    input [DATA_WIDTH - 1: 0] refData,
	input [LOG_MAX_TILE_SIZE - 1: 0] queryAdr,
	input [LOG_MAX_TILE_SIZE - 1: 0] refAdr,
	input start,
	input logic [REF_LEN_WIDTH - 1: 0] refLen,
    input logic [QUERY_LEN_WIDTH - 1: 0] queryLen,
	input logic [LOG_MAX_WAVEFRONT_LEN - 1: 0] marker,
	output logic [1:0] compact_cigar [MAX_WAVEFRONT_LEN-1:0],
	output logic stop
);

	logic signed [DATA_WIDTH - 1: 0] globalKminReg, globalKmaxReg, a, b, shift, globalKminReg_new, globalKmaxReg_new;
	logic signed [DATA_WIDTH - 1: 0] k_conv [NUM_COMPUTE - 1: 0];
	logic [LOG_MAX_TILE_SIZE - 1: 0] globalOffsetReg [MAX_WAVEFRONT_LEN - 1: 0];
	logic [LOG_MAX_TILE_SIZE - 1: 0] globalOffsetReg_temp [MAX_WAVEFRONT_LEN - 1: 0];
	logic [LOG_MAX_WAVEFRONT_LEN - 1: 0] score;
	logic [DATA_WIDTH - 1: 0] queryData_read [NUM_EXTEND - 1: 0];
	logic [DATA_WIDTH - 1: 0] refData_read [NUM_EXTEND - 1: 0];
	logic [DATA_WIDTH - 1: 0] queryData_extend [NUM_EXTEND - 1: 0][BLOCK_WIDTH - 1: 0];
	logic [DATA_WIDTH - 1: 0] refData_extend [NUM_EXTEND - 1: 0][BLOCK_WIDTH - 1: 0];
	logic [LOG_MAX_TILE_SIZE - 1: 0] previous_offset [NUM_EXTEND - 1: 0];
	logic [LOG_MAX_TILE_SIZE - 1: 0] extend_offset [NUM_EXTEND - 1: 0];
	logic done_diag [NUM_EXTEND - 1: 0];

	logic [NUM_EXTEND-1:0] valid;
	logic [MAX_WAVEFRONT_LEN - 1: 0] globalValid, globalValidCheck;
	logic [LOG_MAX_TILE_SIZE - 1: 0] queryAdr_reg [NUM_EXTEND - 1: 0];
	logic [LOG_MAX_TILE_SIZE - 1: 0] refAdr_reg [NUM_EXTEND - 1: 0];
	logic [DATA_WIDTH - 1: 0] numDiag, numStages;
	logic [3:0] count [NUM_EXTEND - 1: 0];
	logic signed [LOG_MAX_TILE_SIZE - 1: 0] diag [NUM_EXTEND - 1: 0];
	logic startExtend, stopExt;
	logic next;
	logic startReduce, done, startThresh, doneThresh;
	logic stopReduce;
	logic signed [DATA_WIDTH - 1: 0]  KminNew, KmaxNew, KminNew_w, KmaxNew_w, lower, upper, k;
	logic [LOG_MAX_TILE_SIZE - 1: 0] tempIndex2;
	logic [DATA_WIDTH - 1: 0]  tempIndex1;
	logic [REF_LEN_WIDTH - 1: 0] threshold;
	logic [LOG_MAX_TILE_SIZE-1:0] M_s_minus_2 [MAX_WAVEFRONT_LEN - 1: 0];
	logic [LOG_MAX_TILE_SIZE-1:0] M_s_minus_1 [MAX_WAVEFRONT_LEN - 1: 0];
	logic [LOG_MAX_TILE_SIZE-1:0] I_s_minus_1 [MAX_WAVEFRONT_LEN - 1: 0];
	logic [LOG_MAX_TILE_SIZE-1:0] D_s_minus_1 [MAX_WAVEFRONT_LEN - 1: 0];
	logic [2+LOG_MAX_WAVEFRONT_LEN:0] M_s_minus_2_ID [MAX_WAVEFRONT_LEN - 1: 0];
	logic [2+LOG_MAX_WAVEFRONT_LEN:0] M_s_minus_1_ID [MAX_WAVEFRONT_LEN - 1: 0];
	logic [2+LOG_MAX_WAVEFRONT_LEN:0] I_s_minus_1_ID [MAX_WAVEFRONT_LEN - 1: 0];
	logic [2+LOG_MAX_WAVEFRONT_LEN:0] D_s_minus_1_ID [MAX_WAVEFRONT_LEN - 1: 0];
	logic valid_M_s_minus_2 [MAX_WAVEFRONT_LEN - 1: 0];
	logic valid_M_s_minus_1 [MAX_WAVEFRONT_LEN - 1: 0];
	logic valid_I_s_minus_1 [MAX_WAVEFRONT_LEN - 1: 0];
	logic valid_D_s_minus_1 [MAX_WAVEFRONT_LEN - 1: 0];
	logic [LOG_MAX_TILE_SIZE-1:0] M_s_minus_2_temp [MAX_WAVEFRONT_LEN - 1: 0];
	logic [LOG_MAX_TILE_SIZE-1:0] M_s_minus_1_temp [MAX_WAVEFRONT_LEN - 1: 0];
	logic [LOG_MAX_TILE_SIZE-1:0] I_s_minus_1_temp [MAX_WAVEFRONT_LEN - 1: 0];
	logic [LOG_MAX_TILE_SIZE-1:0] D_s_minus_1_temp [MAX_WAVEFRONT_LEN - 1: 0];
	logic [2+LOG_MAX_WAVEFRONT_LEN:0] M_s_minus_2_temp_ID [MAX_WAVEFRONT_LEN - 1: 0];
	logic [2+LOG_MAX_WAVEFRONT_LEN:0] M_s_minus_1_temp_ID [MAX_WAVEFRONT_LEN - 1: 0];
	logic [2+LOG_MAX_WAVEFRONT_LEN:0] I_s_minus_1_temp_ID [MAX_WAVEFRONT_LEN - 1: 0];
	logic [2+LOG_MAX_WAVEFRONT_LEN:0] D_s_minus_1_temp_ID [MAX_WAVEFRONT_LEN - 1: 0];
	logic valid_M_s_minus_2_temp [MAX_WAVEFRONT_LEN - 1: 0];
	logic valid_M_s_minus_1_temp [MAX_WAVEFRONT_LEN - 1: 0];
	logic valid_I_s_minus_1_temp [MAX_WAVEFRONT_LEN - 1: 0];
	logic valid_D_s_minus_1_temp [MAX_WAVEFRONT_LEN - 1: 0];
	logic [LOG_MAX_TILE_SIZE-1:0] M_s [MAX_WAVEFRONT_LEN - 1: 0];
    logic [LOG_MAX_TILE_SIZE-1:0] I_s [MAX_WAVEFRONT_LEN - 1: 0];
    logic [LOG_MAX_TILE_SIZE-1:0] D_s [MAX_WAVEFRONT_LEN - 1: 0]; 
	logic [2+LOG_MAX_WAVEFRONT_LEN:0] M_s_ID [MAX_WAVEFRONT_LEN - 1: 0];
    logic [2+LOG_MAX_WAVEFRONT_LEN:0] I_s_ID [MAX_WAVEFRONT_LEN - 1: 0];
    logic [2+LOG_MAX_WAVEFRONT_LEN:0] D_s_ID [MAX_WAVEFRONT_LEN - 1: 0]; 
	logic [LOG_MAX_TILE_SIZE - 1: 0] diag_compute [NUM_COMPUTE-1:0];
	logic startCompute, wrEn_compute;
	logic [$clog2(MAX_WAVEFRONT_LEN) - 1: 0] count_compute;
	logic [LOG_MAX_TILE_SIZE-1:0] M_s_minus_2_k_minus_1 [NUM_COMPUTE-1:0]; 
	logic [LOG_MAX_TILE_SIZE-1:0] M_s_minus_2_k_plus_1 [NUM_COMPUTE-1:0];
	logic [LOG_MAX_TILE_SIZE-1:0] M_s_minus_1_k [NUM_COMPUTE-1:0];
	logic [LOG_MAX_TILE_SIZE-1:0] I_s_minus_1_k_minus_1 [NUM_COMPUTE-1:0];	
	logic [LOG_MAX_TILE_SIZE-1:0] D_s_minus_1_k_plus_1 [NUM_COMPUTE-1:0];
	logic [2+LOG_MAX_WAVEFRONT_LEN:0] M_s_minus_2_k_minus_1_ID [NUM_COMPUTE-1:0]; 
	logic [2+LOG_MAX_WAVEFRONT_LEN:0] M_s_minus_2_k_plus_1_ID [NUM_COMPUTE-1:0];
	logic [2+LOG_MAX_WAVEFRONT_LEN:0] M_s_minus_1_k_ID [NUM_COMPUTE-1:0];
	logic [2+LOG_MAX_WAVEFRONT_LEN:0] I_s_minus_1_k_minus_1_ID [NUM_COMPUTE-1:0];	
	logic [2+LOG_MAX_WAVEFRONT_LEN:0] D_s_minus_1_k_plus_1_ID [NUM_COMPUTE-1:0];
	logic [LOG_MAX_TILE_SIZE-1:0] M_s_k [NUM_COMPUTE-1:0];
    logic [LOG_MAX_TILE_SIZE-1:0] I_s_k [NUM_COMPUTE-1:0];
    logic [LOG_MAX_TILE_SIZE-1:0] D_s_k [NUM_COMPUTE-1:0];
	logic [2+LOG_MAX_WAVEFRONT_LEN:0] M_s_k_ID [NUM_COMPUTE-1:0];
    logic [2+LOG_MAX_WAVEFRONT_LEN:0] I_s_k_ID [NUM_COMPUTE-1:0];
    logic [2+LOG_MAX_WAVEFRONT_LEN:0] D_s_k_ID [NUM_COMPUTE-1:0];
	logic [TB_POINTER_WIDTH-1:0] TB [MAX_WAVEFRONT_LEN - 1: 0];
	logic [TB_POINTER_WIDTH-1:0] TB_temp [MAX_WAVEFRONT_LEN - 1: 0];
	logic [TB_POINTER_WIDTH-1:0] TB_k [NUM_COMPUTE-1:0];
	logic valid_M_s [MAX_WAVEFRONT_LEN - 1: 0];
	logic valid_I_s [MAX_WAVEFRONT_LEN - 1: 0]; 
	logic valid_D_s [MAX_WAVEFRONT_LEN - 1: 0];
	logic valid_M_s_minus_2_k_minus_1 [NUM_COMPUTE-1:0];
	logic valid_M_s_minus_2_k_plus_1 [NUM_COMPUTE-1:0];
	logic valid_M_s_minus_1_k [NUM_COMPUTE-1:0];
	logic valid_I_s_minus_1_k_minus_1 [NUM_COMPUTE-1:0];
	logic valid_D_s_minus_1_k_plus_1 [NUM_COMPUTE-1:0];
	logic valid_M_s_k [NUM_COMPUTE-1:0];
	logic valid_I_s_k [NUM_COMPUTE-1:0]; 
	logic valid_D_s_k [NUM_COMPUTE-1:0];
	logic [NUM_COMPUTE-1:0] doneCompute, doneComputeFinal;
	logic [DATA_WIDTH-1:0] countCyc, waitCount;
	logic [ADDR_WIDTH - 1: 0] computeWidthAddr, computeKminAddr, computeAddr_out;
	logic [DATA_WIDTH - 1: 0] computeAddr, computeAddr_data;
	logic stopCompute;
	logic [12:0] temp3;
	logic [5:0] countAssign1, countAssign2, countAssign3, countAssign4, countAssign5, countAssign7;
	logic [LOG_MAX_WAVEFRONT_LEN-1:0] countAssign6;
	logic [MAX_WAVEFRONT_LEN - 1: 0] equal_M_s_ID, equal_M_s_minus_1_ID, equal_I_s_ID, equal_D_s_ID;
	logic converge, flag_M_s_ID, flag_M_s_minus_1_ID, flag_I_s_ID, flag_D_s_ID;
	logic [2+LOG_MAX_WAVEFRONT_LEN:0] prev_M_s_ID, prev_M_s_minus_1_ID, prev_I_s_ID, prev_D_s_ID;
	logic [1:0] tb_state;
	logic [2*LOG_MAX_WAVEFRONT_LEN + 1:0] convergenceID;
	logic signed [LOG_MAX_WAVEFRONT_LEN-1: 0] start_diag, start_score;
	logic start_traceback;
	logic [DATA_WIDTH-1:0] width_data, widthIn;
	logic [DATA_WIDTH-1:0] Kmin_data;
	logic [TB_POINTER_WIDTH-1:0] traceback_ptr_data;
	logic [ADDR_WIDTH-1:0] traceback_ptr_addr;
	logic [ADDR_WIDTH-1:0] Kmin_addr;
	logic [ADDR_WIDTH-1:0] width_addr;
	logic stop_traceback;
	
	logic [LOG_MAX_WAVEFRONT_LEN -1:0] num_compact;
	logic [3:0] countExtend;
	
	typedef enum logic [5:0] {IDLE, PRE_EXTEND, EXTEND1_1, EXTEND1, EXTEND2_1, EXTEND2, EXTEND2_2, EXTEND3, CHECK_EXTEND_1, CHECK_EXTEND, DONE_EXTEND, THRESHOLD, REDUCE, DONE_REDUCE, PRE_COMPUTE0_0, PRE_COMPUTE0, PRE_COMPUTE_1, PRE_COMPUTE, COMPUTE1, COMPUTE1_1, COMPUTE1_2, COMPUTE1_3, COMPUTE2_1, WAIT_COMPUTE_0, WAIT_COMPUTE, WAIT_COMPUTE_1, COMPUTE2, WRITE_COMPUTE0, INT1, INT2, WRITE_COMPUTE1, WRITE_COMPUTE2, CHECK_CONVERGENCE, CHECK_CONVERGENCE_1, CHECK_CONVERGENCE_2, DONE_COMPUTE, PRE_TRACEBACK0, PRE_TRACEBACK1, PRE_TRACEBACK2, PRE_TRACEBACK3, PRE_TRACEBACK, TRACEBACK, DONE_TRACEBACK} state;
    state current_state, next_state;
	
	always_comb begin
        if(rst) begin
            current_state = IDLE;
        end
        else begin
            current_state = next_state;
        end
    end
	
	always_ff @(posedge clk) begin
		case(current_state)
			IDLE: begin
				if(start && next) begin
					globalValid <= '0;
					
					for(int j=NUM_EXTEND-1; j>=0; j--) begin
						valid[j] <= '0;
						done_diag[j] <= '0;
						count[j] <= '0;
						extend_offset[j] <= 0;
					end
					
					startReduce <= 0;
					startCompute <= 0;
					stopExt <= 0;
					stopReduce <= 0;
					stopCompute <= 0;
					
					for(int i=0; i< MAX_WAVEFRONT_LEN/SEQ; i++) begin
					  if(countAssign7*MAX_WAVEFRONT_LEN/SEQ+i < (MAX_WAVEFRONT_LEN-shift)) begin
						globalOffsetReg[countAssign7*MAX_WAVEFRONT_LEN/SEQ+i+shift] <= M_s[countAssign7*MAX_WAVEFRONT_LEN/SEQ+i];
						globalOffsetReg_temp[countAssign7*MAX_WAVEFRONT_LEN/SEQ+i] <= '0;
						
						M_s_minus_2_temp[countAssign7*MAX_WAVEFRONT_LEN/SEQ+i+shift] <= M_s_minus_2[countAssign7*MAX_WAVEFRONT_LEN/SEQ+i];
						valid_M_s_minus_2_temp[countAssign7*MAX_WAVEFRONT_LEN/SEQ+i+shift] <= valid_M_s_minus_2[countAssign7*MAX_WAVEFRONT_LEN/SEQ+i];
						M_s_minus_1_temp[countAssign7*MAX_WAVEFRONT_LEN/SEQ+i+shift] <= M_s_minus_1[countAssign7*MAX_WAVEFRONT_LEN/SEQ+i];
						valid_M_s_minus_1_temp[countAssign7*MAX_WAVEFRONT_LEN/SEQ+i+shift] <= valid_M_s_minus_1[countAssign7*MAX_WAVEFRONT_LEN/SEQ+i];
						I_s_minus_1_temp[countAssign7*MAX_WAVEFRONT_LEN/SEQ+i+shift] <= I_s_minus_1[countAssign7*MAX_WAVEFRONT_LEN/SEQ+i];
						valid_I_s_minus_1_temp[countAssign7*MAX_WAVEFRONT_LEN/SEQ+i+shift] <= valid_I_s_minus_1[countAssign7*MAX_WAVEFRONT_LEN/SEQ+i];
						D_s_minus_1_temp[countAssign7*MAX_WAVEFRONT_LEN/SEQ+i+shift] <= D_s_minus_1[countAssign7*MAX_WAVEFRONT_LEN/SEQ+i];
						valid_D_s_minus_1_temp[countAssign7*MAX_WAVEFRONT_LEN/SEQ+i+shift] <= valid_D_s_minus_1[countAssign7*MAX_WAVEFRONT_LEN/SEQ+i];
						
						M_s_minus_2_temp_ID[countAssign7*MAX_WAVEFRONT_LEN/SEQ+i+shift] <= M_s_minus_2_ID[countAssign7*MAX_WAVEFRONT_LEN/SEQ+i];
						M_s_minus_1_temp_ID[countAssign7*MAX_WAVEFRONT_LEN/SEQ+i+shift] <= M_s_minus_1_ID[countAssign7*MAX_WAVEFRONT_LEN/SEQ+i];
						I_s_minus_1_temp_ID[countAssign7*MAX_WAVEFRONT_LEN/SEQ+i+shift] <= I_s_minus_1_ID[countAssign7*MAX_WAVEFRONT_LEN/SEQ+i];
						D_s_minus_1_temp_ID[countAssign7*MAX_WAVEFRONT_LEN/SEQ+i+shift] <= D_s_minus_1_ID[countAssign7*MAX_WAVEFRONT_LEN/SEQ+i];
					  end
					end
					
					globalKmaxReg <= globalKmaxReg_new;
					globalKminReg <= globalKminReg_new;
					
					if(countAssign7 != SEQ-1) begin
                        countAssign7 <= countAssign7 + 'd1;				
				        next_state <= IDLE;
				    end
				    else
					    next_state <= PRE_EXTEND;
				end
				else if(start) begin
					globalValid <= '0;
					
					globalOffsetReg[1] <= 0;
					
					valid_M_s_minus_1[1] <= 1;
					valid_M_s_minus_1_temp[1] <= 1;
					
					widthIn <= 0;
					
					next_state <= PRE_EXTEND;
				end
				else begin
					next_state <= IDLE;
					for(int j=NUM_EXTEND-1; j>=0; j--) begin
						queryAdr_reg[j] <= queryAdr;
						refAdr_reg[j] <= refAdr;
						valid[j] <= 0;
						done_diag[j] <= 0;
						count[j] <= '0;
						extend_offset[j] <= 0;
					end
					for(int i=0; i< MAX_WAVEFRONT_LEN; i++) begin
						globalOffsetReg[i] <= '0;
						M_s_minus_2[i] <= '0;
						M_s_minus_1[i] <= '0;
						I_s_minus_1[i] <= '0;
						D_s_minus_1[i] <= '0;
						valid_M_s_minus_2[i] <= 0;
						valid_M_s_minus_1[i] <= 0;
						valid_I_s_minus_1[i] <= 0;
						valid_D_s_minus_1[i] <= 0;
						M_s_minus_2_ID[i] <= '1;
						M_s_minus_1_ID[i] <= '1;
						I_s_minus_1_ID[i] <= '1;
						D_s_minus_1_ID[i] <= '1;
						
						globalOffsetReg_temp[i] <= '0;
						M_s_minus_2_temp[i] <= '0;
						M_s_minus_1_temp[i] <= '0;
						I_s_minus_1_temp[i] <= '0;
						D_s_minus_1_temp[i] <= '0;
						valid_M_s_minus_2_temp[i] <= 0;
						valid_M_s_minus_1_temp[i] <= 0;
						valid_I_s_minus_1_temp[i] <= 0;
						valid_D_s_minus_1_temp[i] <= 0;
						M_s_minus_2_temp_ID[i] <= '1;
						M_s_minus_1_temp_ID[i] <= '1;
						I_s_minus_1_temp_ID[i] <= '1;
						D_s_minus_1_temp_ID[i] <= '1;
					end
					
					computeAddr <= '0;
					computeWidthAddr <= '0;
					computeKminAddr <= '0;
					
					score <= 0;
					
					globalKminReg <= globalKmin;
					globalKmaxReg <= globalKmax;
					
					startExtend <= 0;
					startReduce <= 0;
					startCompute <= 0;
					stopExt <= 0;
					startThresh <= 0;
					stopReduce <= 0;
					stopCompute <= 0;
					stop <= 0;
					next <= 0;
				end
			end
			PRE_EXTEND: begin
				//Set the no. of diagonals based on Kmin, Kmax
				//Set the no. of stages based on the NUM of PEs used in extend
				numDiag <= globalKmaxReg - globalKminReg + 1;
				numStages <= (globalKmaxReg - globalKminReg + 1)/NUM_EXTEND;
				next_state <= EXTEND1;
				for(int j=NUM_EXTEND-1; j>=0; j--) begin	
					count[j] <= '0;
				end
				for(int i=0; i<MAX_WAVEFRONT_LEN; i++) begin
					globalValidCheck[i] <= 1;
				end
			end
			EXTEND1: begin
			  //Set the diagonal number sent to each PE
			  if(next_state != EXTEND1_1) begin
				for(int j=NUM_EXTEND-1; j>=0; j--) begin
				  if(!globalValid[numStages*NUM_EXTEND+j] && valid_M_s_minus_1_temp[numStages*NUM_EXTEND+j]) begin
					previous_offset[j] <= globalOffsetReg[numStages*NUM_EXTEND+j];
					if(numStages*NUM_EXTEND+j <= numDiag+1) begin
						diag[j] <= $signed($signed(numStages*NUM_EXTEND)+$signed(j)+globalKminReg);
						
					end
				  end
				end
				next_state <= EXTEND1_1;
				countExtend <= '0;
			  end
			end
			EXTEND1_1: begin
			  //Set the query and ref SRAM addresses to fetch the correct bases according to the diagonal number
			  if(next_state != EXTEND2_1) begin
				for(int j=NUM_EXTEND-1; j>=0; j--) begin
				  if(!globalValid[numStages*NUM_EXTEND+j] && valid_M_s_minus_1_temp[numStages*NUM_EXTEND+j]) begin
					if(numStages*NUM_EXTEND+j <= numDiag+1) begin
						queryAdr_reg[j] <= previous_offset[j] + count[j];
						refAdr_reg[j] <= $signed(previous_offset[j]) - $signed(diag[j] - 1) + count[j];
					end
				  end
				end
				next_state <= EXTEND2_1;
			  end
			end
			EXTEND2_1: begin
			  //Wait state
			  if(next_state != EXTEND2) begin
				next_state <= EXTEND2;
			  end
			end
			EXTEND2: begin
			  //Check if bases equal in ref and query, extend accordingly
			  //Update the new extended offset
			  if(next_state != EXTEND3) begin
				for(int j=NUM_EXTEND-1; j>=0; j--) begin
					if (refData_read[j] == queryData_read[j]) begin
						count[j] <= count[j]  + 1;
						if(count[j] == BLOCK_WIDTH-1)
						    extend_offset[j] <= previous_offset[j] + count[j]+1;
					end
					else if (!done_diag[j]) begin
						valid[j] <= 1;
						done_diag[j] <= 1;
						extend_offset[j] <= previous_offset[j] + count[j];
					end
				end
				countExtend <= countExtend + 1;
				if (countExtend == BLOCK_WIDTH-1) begin
					next_state <= EXTEND3;
				end
				else begin
				    next_state <= EXTEND1_1;
				end
			  end
			end
			EXTEND3: begin
			  //Update the global offset reg with extended offsets
			  //Check if more num of stages remaining, then continue their extension on the available PEs
			  if(next_state != EXTEND1) begin
					countExtend <= 'd0;
					for(int j=NUM_EXTEND-1; j>=0; j--) begin
					  if(!globalValid[numStages*NUM_EXTEND+j] && numStages*NUM_EXTEND+j <= numDiag+1 && valid_M_s_minus_1_temp[numStages*NUM_EXTEND+j]) begin
						globalOffsetReg_temp[numStages*NUM_EXTEND+j] <= extend_offset[j];
						globalValid[numStages*NUM_EXTEND+j] <= valid[j];
					  end
					  count[j] <= '0;
					end
					if(numStages) begin
						numStages <= numStages - 1;
						next_state <= EXTEND1;
					end
					else
						next_state <= CHECK_EXTEND;
			  end
			end
			CHECK_EXTEND: begin
				//Check is extension has ended, if not, keep extending
				for(int i=0; i<MAX_WAVEFRONT_LEN; i++) begin
					if(valid_M_s_minus_1_temp[i])
						globalValidCheck[i] <= globalValid[i];
				end
				
				next_state <= CHECK_EXTEND_1;
			end
			CHECK_EXTEND_1: begin
				//Continue checking extension
				if(&globalValidCheck) begin
					next_state <= DONE_EXTEND;
					globalOffsetReg <= globalOffsetReg_temp;
				end
				else begin
					next_state <= PRE_EXTEND;
					globalOffsetReg <= globalOffsetReg_temp;
				end
			end
			DONE_EXTEND: begin
				//Move to next step
				stopExt <= 1;
				next_state <= THRESHOLD;
				startThresh <= 1;
			end
			THRESHOLD: begin
				//Just calculate the threshold for the particular set of diagonals based on their distances from the endpoint
				if(doneThresh) begin
					next_state <= REDUCE;
					startThresh <= 0;
				end
			end
			REDUCE: begin
				//Drop logic based on calculated threshold
				startReduce <= 1;
				countAssign1 <= 'd0;
				countAssign2 <= 'd0;
				countAssign3 <= 'd0;
				countAssign4 <= 'd0;
				countAssign5 <= 'd0;
				countAssign6 <= 'd0;
				countAssign7 <= 'd0;
				if(done)
					next_state <= DONE_REDUCE;
			end
			DONE_REDUCE: begin
				//Move to Compute stage
				//Keep the new Kmin, Kmax ready
				startReduce <= 0;
				stopReduce <= 1;
				startCompute <= 1;
				numStages <= 0;
				
				M_s_minus_2 <= M_s_minus_2_temp;
				valid_M_s_minus_2 <= valid_M_s_minus_2_temp;
				M_s_minus_1 <= M_s_minus_1_temp;
				valid_M_s_minus_1 <= valid_M_s_minus_1_temp;
				I_s_minus_1 <= I_s_minus_1_temp;
				valid_I_s_minus_1 <= valid_I_s_minus_1_temp;
				D_s_minus_1 <= D_s_minus_1_temp;
				valid_D_s_minus_1 <= valid_D_s_minus_1_temp;
				
				M_s_minus_2_ID <= M_s_minus_2_temp_ID;
				M_s_minus_1_ID <= M_s_minus_1_temp_ID;
				I_s_minus_1_ID <= I_s_minus_1_temp_ID;
				D_s_minus_1_ID <= D_s_minus_1_temp_ID;
				
				for(int i=0; i< MAX_WAVEFRONT_LEN; i++) begin
					globalOffsetReg_temp[i] <= '0;
					M_s_minus_2_temp[i] <= '0;
					valid_M_s_minus_2_temp[i] <= '0;
					M_s_minus_1_temp[i] <= '0;
					valid_M_s_minus_1_temp[i] <= '0;
					I_s_minus_1_temp[i] <= '0;
					valid_I_s_minus_1_temp[i] <= '0;
					D_s_minus_1_temp[i] <= '0;
					valid_D_s_minus_1_temp[i] <= '0;
					
					M_s_minus_2_temp_ID[i] <= '1;
					M_s_minus_1_temp_ID[i] <= '1;
					I_s_minus_1_temp_ID[i] <= '1;
					D_s_minus_1_temp_ID[i] <= '1;
					
				end
				
				KmaxNew <= KmaxNew_w-1;
				KminNew <= KminNew_w-1;
				
				next_state <= PRE_COMPUTE0_0;
			end
			PRE_COMPUTE0_0: begin
			  //Set lower and upper bounds based on new Kmin and Kmax
			  if(next_state != PRE_COMPUTE0) begin
				
				M_s_minus_2_temp <= M_s_minus_2;
			    valid_M_s_minus_2_temp <= valid_M_s_minus_2;
			    M_s_minus_2_temp_ID <= M_s_minus_2_ID;
			    
			    lower <= $signed(KminNew)+$signed(1)-$signed(globalKminReg);
			    upper <= $signed(KmaxNew)+$signed(1)-$signed(globalKminReg);
				next_state <= PRE_COMPUTE0;
			  end
			end
			PRE_COMPUTE0: begin
			  //Set the no. of diagonals, stages as before
			  //Based on the lower and upper bounds, start storing in M, I, D registers from prev wavefront
			  if(next_state != PRE_COMPUTE_1) begin
				numDiag <= globalKmaxReg - globalKminReg + 1;
				numStages <= (globalKmaxReg - globalKminReg + 1)/NUM_EXTEND;
				
				for(int i=0; i<MAX_WAVEFRONT_LEN/SEQ; i++) begin
					if(countAssign1*MAX_WAVEFRONT_LEN/SEQ + i >= lower && countAssign1*MAX_WAVEFRONT_LEN/SEQ + i <= upper) begin
						globalOffsetReg_temp[countAssign1*MAX_WAVEFRONT_LEN/SEQ + i] <= globalOffsetReg[countAssign1*MAX_WAVEFRONT_LEN/SEQ + i];
						
						M_s_minus_1_temp[countAssign1*MAX_WAVEFRONT_LEN/SEQ + i] <= M_s_minus_1[countAssign1*MAX_WAVEFRONT_LEN/SEQ + i];
						valid_M_s_minus_1_temp[countAssign1*MAX_WAVEFRONT_LEN/SEQ + i] <= valid_M_s_minus_1[countAssign1*MAX_WAVEFRONT_LEN/SEQ + i];
						I_s_minus_1_temp[countAssign1*MAX_WAVEFRONT_LEN/SEQ + i] <= I_s_minus_1[countAssign1*MAX_WAVEFRONT_LEN/SEQ + i];
						valid_I_s_minus_1_temp[countAssign1*MAX_WAVEFRONT_LEN/SEQ + i] <= valid_I_s_minus_1[countAssign1*MAX_WAVEFRONT_LEN/SEQ + i];
						D_s_minus_1_temp[countAssign1*MAX_WAVEFRONT_LEN/SEQ + i] <= D_s_minus_1[countAssign1*MAX_WAVEFRONT_LEN/SEQ + i];
						valid_D_s_minus_1_temp[countAssign1*MAX_WAVEFRONT_LEN/SEQ + i] <= valid_D_s_minus_1[countAssign1*MAX_WAVEFRONT_LEN/SEQ + i];
						
						M_s_minus_1_temp_ID[countAssign1*MAX_WAVEFRONT_LEN/SEQ + i] <= M_s_minus_1_ID[countAssign1*MAX_WAVEFRONT_LEN/SEQ + i];
						I_s_minus_1_temp_ID[countAssign1*MAX_WAVEFRONT_LEN/SEQ + i] <= I_s_minus_1_ID[countAssign1*MAX_WAVEFRONT_LEN/SEQ + i];
						D_s_minus_1_temp_ID[countAssign1*MAX_WAVEFRONT_LEN/SEQ + i] <= D_s_minus_1_ID[countAssign1*MAX_WAVEFRONT_LEN/SEQ + i];
					end  
				end
				
				if(countAssign1 != SEQ-1) begin
                    countAssign1 <= countAssign1 + 'd1;				
				    next_state <= PRE_COMPUTE0;
				end
				else begin
					for(int i=0; i< MAX_WAVEFRONT_LEN; i++) begin
						globalOffsetReg[i] <= '0;
						M_s_minus_2[i] <= '0;
						valid_M_s_minus_2[i] <= '0;
						M_s_minus_1[i] <= '0;
						valid_M_s_minus_1[i] <= '0;
						I_s_minus_1[i] <= '0;
						valid_I_s_minus_1[i] <= '0;
						D_s_minus_1[i] <= '0;
						valid_D_s_minus_1[i] <= '0;
						
						M_s_minus_2_ID[i] <= '1;
						M_s_minus_1_ID[i] <= '1;
						I_s_minus_1_ID[i] <= '1;
						D_s_minus_1_ID[i] <= '1;
					end
				    next_state <= COMPUTE1_1;
				end
			  end
			end
			COMPUTE1_1: begin
			  //Update M(S-1) register with the extended values
			  if(next_state != COMPUTE1_2) begin
				for(int i=0; i<MAX_WAVEFRONT_LEN/SEQ; i++) begin
					M_s_minus_1_temp[countAssign4*MAX_WAVEFRONT_LEN/SEQ+i] <= globalOffsetReg_temp[countAssign4*MAX_WAVEFRONT_LEN/SEQ+i];
				end
				
				temp3 <= numStages*NUM_COMPUTE;
				
				if(countAssign4 != SEQ-1) begin
                    countAssign4 <= countAssign4 + 'd1;				
				    next_state <= COMPUTE1_1;
				end
				else begin
				    next_state <= COMPUTE1_2;
				end
			  end
			end
			COMPUTE1_2: begin
			//Set the diagonal number to be assigned to each Compute PE
			startCompute <= 1;
			  if(next_state != COMPUTE1_3) begin
				M_s_minus_1_temp[0] <= '0;
				I_s_minus_1_temp[0] <= '0;
				D_s_minus_1_temp[0] <= '0;
				M_s_minus_1_temp[numDiag+1] <= '0;
				I_s_minus_1_temp[numDiag+1] <= '0;
				D_s_minus_1_temp[numDiag+1] <= '0;
				
				M_s_minus_1_temp_ID[0] <= '1;
				I_s_minus_1_temp_ID[0] <= '1;
				D_s_minus_1_temp_ID[0] <= '1;
				M_s_minus_1_temp_ID[numDiag+1] <= '1;
				I_s_minus_1_temp_ID[numDiag+1] <= '1;
				D_s_minus_1_temp_ID[numDiag+1] <= '1;
				
				temp3 <= numStages*NUM_COMPUTE; 
				
				for(int j=NUM_COMPUTE-1; j>=0; j--) begin
					if(numStages*NUM_COMPUTE+j <= numDiag+1) begin
						diag_compute[j] <= (numStages*NUM_COMPUTE+j);
					end
				end
				
				next_state <= COMPUTE1_3;
			  end
			end
			COMPUTE1_3: begin
			  //Send M, I, D values from global registers to each PE
			  if(next_state != WAIT_COMPUTE_0) begin
				for(int j=NUM_COMPUTE-1; j>=0; j--) begin
					if(temp3+j <= numDiag+1) begin
						M_s_minus_2_k_minus_1[j] <= M_s_minus_2_temp[diag_compute[j]-1];
						M_s_minus_2_k_plus_1[j] <= M_s_minus_2_temp[diag_compute[j]+1];
						M_s_minus_1_k[j] <= M_s_minus_1_temp[diag_compute[j]];
						I_s_minus_1_k_minus_1[j] <= I_s_minus_1_temp[diag_compute[j]-1];
						D_s_minus_1_k_plus_1[j] <= D_s_minus_1_temp[diag_compute[j]+1];
						valid_M_s_minus_2_k_minus_1[j] <= valid_M_s_minus_2_temp[diag_compute[j]-1];
						valid_M_s_minus_2_k_plus_1[j] <= valid_M_s_minus_2_temp[diag_compute[j]+1];
						valid_M_s_minus_1_k[j] <= valid_M_s_minus_1_temp[diag_compute[j]];
						valid_I_s_minus_1_k_minus_1[j] <= valid_I_s_minus_1_temp[diag_compute[j]-1];
						valid_D_s_minus_1_k_plus_1[j] <= valid_D_s_minus_1_temp[diag_compute[j]+1];
						
						M_s_minus_2_k_minus_1_ID[j] <= M_s_minus_2_temp_ID[diag_compute[j]-1];
						M_s_minus_2_k_plus_1_ID[j] <= M_s_minus_2_temp_ID[diag_compute[j]+1];
						M_s_minus_1_k_ID[j] <= M_s_minus_1_temp_ID[diag_compute[j]];
						I_s_minus_1_k_minus_1_ID[j] <= I_s_minus_1_temp_ID[diag_compute[j]-1];
						D_s_minus_1_k_plus_1_ID[j] <= D_s_minus_1_temp_ID[diag_compute[j]+1];
						k_conv[j] <= $signed(diag_compute[j]) + $signed(globalKminReg - 1);
					end
				end
				next_state <= WAIT_COMPUTE_0;
				waitCount <= 0;
			  end
			end
			WAIT_COMPUTE_0: begin
				//Wait for compute to finish
				waitCount <= waitCount + 1;

				if(waitCount == 2)
					next_state <= WAIT_COMPUTE;
				else
					next_state <= WAIT_COMPUTE_0;
			end
			WAIT_COMPUTE: begin
				//Wait state
				startCompute <= 0;
				if(next_state != WAIT_COMPUTE_1) begin
			
				next_state <= WAIT_COMPUTE_1;	
			  end
			end
			WAIT_COMPUTE_1: begin
			  //wait state
			  if(next_state != COMPUTE2_1) begin
				next_state <= COMPUTE2_1;
			  end
			end
			COMPUTE2_1: begin
			  //Decide the locations on the global registers where you want to store the per PE compute results
			  if(next_state != COMPUTE2) begin
				for(int j = 0; j < NUM_COMPUTE; j += 1) begin
					if(temp3+j <= numDiag+1) begin
						diag_compute[j] <= (temp3+j);
					end
				end
			  
			  next_state <= COMPUTE2;
			  end
			end
			COMPUTE2: begin
			  //Store per PE compute results back into global registers, which will be used for future wavefronts
			  if(next_state != COMPUTE1 && next_state != WRITE_COMPUTE1) begin
				for(int j = 0; j < NUM_COMPUTE; j += 1) begin
					if(temp3+j <= numDiag+1) begin
						M_s[diag_compute[j]] <= M_s_k[j];
						I_s[diag_compute[j]] <= I_s_k[j];
						D_s[diag_compute[j]] <= D_s_k[j];
						valid_M_s[diag_compute[j]] <= valid_M_s_k[j];
						valid_I_s[diag_compute[j]] <= valid_I_s_k[j];
						valid_D_s[diag_compute[j]] <= valid_D_s_k[j];
						TB[diag_compute[j]] <= TB_k[j];
						
						M_s_ID[diag_compute[j]] <= M_s_k_ID[j];
						I_s_ID[diag_compute[j]] <= I_s_k_ID[j];
						D_s_ID[diag_compute[j]] <= D_s_k_ID[j];
					end
				end
				
				if(numStages) begin
					numStages <= numStages - 1;
					next_state <= COMPUTE1_2;
					doneComputeFinal <= '0;
				end
				else begin
					next_state <= WRITE_COMPUTE0;
				end
				count_compute <= 0;
			  end
			end
			WRITE_COMPUTE0: begin
				//Update the Kmin, Kmax values in case we enter some valid values in new diagonals
			        if(!valid_M_s_minus_1[0] && valid_M_s[0]) begin
				        globalKminReg_new <= globalKminReg - 1;
				    end
				    else
				            globalKminReg_new <= globalKminReg;
				    if(!valid_M_s_minus_1[numDiag+1] && valid_M_s[numDiag+1]) begin
				        globalKmaxReg_new <= globalKmaxReg + 1;
				    end
				    else
				        globalKmaxReg_new <= globalKmaxReg;
				    next_state <= INT1;
			end
			INT1: begin
			    //Set the current no. of diagonals
			    numDiag <= globalKmaxReg_new - globalKminReg_new + 1;
			    widthIn <= widthIn + globalKmaxReg_new - globalKminReg_new + 1;
		        shift <= globalKminReg-globalKminReg_new;
			    next_state <= INT2;
			    TB_temp <= TB;
			end
			INT2: begin
				//Prepare global TB pointer register
				for(int i=0; i< MAX_WAVEFRONT_LEN/SEQ; i++) begin
					if(countAssign5*MAX_WAVEFRONT_LEN/SEQ+i < (MAX_WAVEFRONT_LEN-shift)) begin
						TB[countAssign5*MAX_WAVEFRONT_LEN/SEQ+i+shift] <= TB_temp[countAssign5*MAX_WAVEFRONT_LEN/SEQ+i];
					end
				end
			
				if(countAssign5 != SEQ-1) begin
					countAssign5 <= countAssign5 + 'd1;				
					next_state <= INT2;
				end
				else begin
					next_state <= WRITE_COMPUTE1;
				end
			end
			WRITE_COMPUTE1: begin
			  //Begin storing TB pointers by calculating the correct address for TB BRAM
			  //In case marker wavefront has crossed, move to convergence
			  if(next_state != WRITE_COMPUTE2 || next_state != CHECK_CONVERGENCE) begin
			  
				if(count_compute == 0) begin
					M_s_minus_2 <= M_s_minus_1_temp;
				    M_s_minus_1 <= M_s;
				    I_s_minus_1 <= I_s;
				    D_s_minus_1 <= D_s;
					valid_M_s_minus_2 <= valid_M_s_minus_1_temp;
				    valid_M_s_minus_1 <= valid_M_s;
				    valid_I_s_minus_1 <= valid_I_s;
				    valid_D_s_minus_1 <= valid_D_s;
				    
				    M_s_minus_2_ID <= M_s_minus_1_temp_ID;
				    M_s_minus_1_ID <= M_s_ID;
				    I_s_minus_1_ID <= I_s_ID;
				    D_s_minus_1_ID <= D_s_ID;
				    
				end
			  
				if(score <= marker) begin
					count_compute <= count_compute + 1;
				
					wrEn_compute <= 1;
				
					computeAddr_out <= computeAddr + count_compute;
					next_state <= WRITE_COMPUTE2;
				end
				else begin
				    next_state <= CHECK_CONVERGENCE;
				end
			  end
			end
			WRITE_COMPUTE2: begin
				//Write values into TB BRAM
				if(count_compute <= numDiag-1)
					next_state <= WRITE_COMPUTE1;
				else begin
					converge <= 0;
					next_state <= DONE_COMPUTE;
				end
			end
			CHECK_CONVERGENCE: begin
				//Begin convergence
				next_state <= CHECK_CONVERGENCE_1;
				flag_M_s_minus_1_ID <= 0;
				flag_M_s_ID <= 0;
				flag_I_s_ID <= 0;
				flag_D_s_ID <= 0;
			end
			CHECK_CONVERGENCE_1: begin
			  //Check the equality of the ID registers for the current and previous wavefront (after crossing marker)
			  if(next_state != CHECK_CONVERGENCE_2) begin
			
				if(countAssign6 == 0) begin
				    equal_M_s_ID[countAssign6] <= 1;
				    equal_M_s_minus_1_ID[countAssign6] <= 1;
					equal_I_s_ID[countAssign6] <= 1;
					equal_D_s_ID[countAssign6] <= 1;
				    if(valid_M_s[countAssign6] && !flag_M_s_ID) begin
				        prev_M_s_ID <= M_s_ID[countAssign6];
				        flag_M_s_ID <= 1;
				    end
				    if(valid_M_s_minus_1_temp[countAssign6] && !flag_M_s_minus_1_ID) begin
				        prev_M_s_minus_1_ID <= M_s_minus_1_temp_ID[countAssign6];
				        flag_M_s_minus_1_ID <= 1;
				    end
					if(valid_I_s[countAssign6] && !flag_I_s_ID) begin
				        prev_I_s_ID <= I_s_ID[countAssign6];
				        flag_I_s_ID <= 1;
				    end
					if(valid_D_s[countAssign6] && !flag_D_s_ID) begin
				        prev_D_s_ID <= D_s_ID[countAssign6];
				        flag_D_s_ID <= 1;
				    end
				    countAssign6 <= countAssign6 + 1'd1;
				    next_state <= CHECK_CONVERGENCE_1;
				end
				else if(countAssign6 > 0 && countAssign6 <= MAX_WAVEFRONT_LEN-1) begin
				    if(valid_M_s[countAssign6] && !flag_M_s_ID) begin
				       prev_M_s_ID <= M_s_ID[countAssign6];
				       flag_M_s_ID <= 1;
				       equal_M_s_ID[countAssign6] <= 1;
				    end
				    else if(valid_M_s[countAssign6] && flag_M_s_ID) begin
				       if(M_s_ID[countAssign6] == prev_M_s_ID) begin
				           equal_M_s_ID[countAssign6] <= 1;
				       end
				       else begin
				           equal_M_s_ID[countAssign6] <= 0;
				       end
				    end
				    else begin
				       equal_M_s_ID[countAssign6] <= 1;
				    end
				    
				    if(valid_M_s_minus_1_temp[countAssign6] && !flag_M_s_minus_1_ID) begin
				       prev_M_s_minus_1_ID <= M_s_minus_1_temp_ID[countAssign6];
				       flag_M_s_minus_1_ID <= 1;
				       equal_M_s_minus_1_ID[countAssign6] <= 1;
				    end
				    else if(valid_M_s_minus_1_temp[countAssign6] && flag_M_s_minus_1_ID) begin
				       if(M_s_minus_1_temp_ID[countAssign6] == prev_M_s_minus_1_ID) begin
				           equal_M_s_minus_1_ID[countAssign6] <= 1;
				       end
				       else begin
				           equal_M_s_minus_1_ID[countAssign6] <= 0;
				       end
				    end
				    else begin
				       equal_M_s_minus_1_ID[countAssign6] <= 1;
				    end
					
					if(valid_I_s[countAssign6] && !flag_I_s_ID) begin
				       prev_I_s_ID <= I_s_ID[countAssign6];
				       flag_I_s_ID <= 1;
				       equal_I_s_ID[countAssign6] <= 1;
				    end
				    else if(valid_I_s[countAssign6] && flag_I_s_ID) begin
				       if(I_s_ID[countAssign6] == prev_I_s_ID) begin
				           equal_I_s_ID[countAssign6] <= 1;
				       end
				       else begin
				           equal_I_s_ID[countAssign6] <= 0;
				       end
				    end
				    else begin
				       equal_I_s_ID[countAssign6] <= 1;
				    end
					
					if(valid_D_s[countAssign6] && !flag_D_s_ID) begin
				       prev_D_s_ID <= D_s_ID[countAssign6];
				       flag_D_s_ID <= 1;
				       equal_D_s_ID[countAssign6] <= 1;
				    end
				    else if(valid_D_s[countAssign6] && flag_D_s_ID) begin
				       if(D_s_ID[countAssign6] == prev_D_s_ID) begin
				           equal_D_s_ID[countAssign6] <= 1;
				       end
				       else begin
				           equal_D_s_ID[countAssign6] <= 0;
				       end
				    end
				    else begin
				       equal_D_s_ID[countAssign6] <= 1;
				    end
				    
				    countAssign6 <= countAssign6 + 1'd1;
				    next_state <= CHECK_CONVERGENCE_1;
				end
				else begin
				    next_state <= CHECK_CONVERGENCE_2;
				end
			  end					
			end
			CHECK_CONVERGENCE_2: begin
				//Check if converged
				if(&equal_M_s_ID && &equal_M_s_minus_1_ID && &equal_I_s_ID && &equal_D_s_ID && prev_M_s_ID == prev_M_s_minus_1_ID && prev_M_s_ID == prev_I_s_ID && prev_M_s_ID == prev_D_s_ID)
					converge <= 1;
				else
					converge <= 0;
				
				next_state <= DONE_COMPUTE;
			end
			DONE_COMPUTE: begin
				//Move to traceback if converged, else move to next wavefront for another extend-reduce-compute cycle
				count_compute <= 0;
				wrEn_compute <= 0;
				if(converge) begin
				    next_state <= PRE_TRACEBACK0;
				    start_score <= prev_M_s_ID[LOG_MAX_WAVEFRONT_LEN+2] ? marker : marker-1;
				    start_diag <= prev_M_s_ID[LOG_MAX_WAVEFRONT_LEN+1:2];
				end
				else begin
					score <= score+1;
					computeAddr <= computeAddr_out+1;
					computeWidthAddr <= computeWidthAddr+1;
					computeKminAddr <= computeKminAddr+1;
					next_state <= IDLE;
					next <= 1;
				end
			end
			PRE_TRACEBACK0: begin
			    //Compute Kmin BRAM address for traceback logic
			    computeKminAddr <= start_score;
			    next_state <= PRE_TRACEBACK1;
			end
			PRE_TRACEBACK1: begin
			    //Wait state for address to propagate to BRAM
			    next_state <= PRE_TRACEBACK2;
			end
			PRE_TRACEBACK2: begin
			    //Compute TB BRAM address for traceback logic
			    computeAddr_out <= $signed(computeAddr_data) + $signed(start_diag) - $signed(Kmin_data);
			    next_state <= PRE_TRACEBACK3;
			end
			PRE_TRACEBACK3: begin
		   	    //Wait state for address to propagate to BRAM
			    next_state <= PRE_TRACEBACK;
			end
			PRE_TRACEBACK: begin
				//Begin traceback
				tb_state <= traceback_ptr_data[1:0];
				start_traceback <= 1;
				computeWidthAddr <= width_addr-1;
				computeKminAddr <= width_addr;
				computeAddr_out <= traceback_ptr_addr;
				next_state <= TRACEBACK;
			end
			TRACEBACK: begin
				//Continue traceback until Origin reached for the particular tile
				if(stop_traceback)
					next_state <= DONE_TRACEBACK;
				else begin
					computeWidthAddr <= width_addr-1;
					computeKminAddr <= width_addr;
					computeAddr_out <= traceback_ptr_addr;
				end
			end
			DONE_TRACEBACK: begin
				//Stop simulation
				stop <= 1;
			end
		endcase
	end
	
	


    genvar i;
/*
    generate
        for (i = 0; i < NUM_EXTEND; i += 1) 
        begin: eachBRAM_query
            BRAM #(
                .ADDR_WIDTH(ADDR_WIDTH),
                .DATA_WIDTH(DATA_WIDTH)
            ) bram_query (
                .clk(clk),
                .addr(queryAdr_reg[i]),
                .writeEn(loadData),
                .dataIn(queryData),
                .dataOut(queryData_read[i])
            );
        end
    endgenerate
	
	generate
        for (i = 0; i < NUM_EXTEND; i += 1) 
        begin: eachBRAM_ref
            BRAM #(
                .ADDR_WIDTH(ADDR_WIDTH),
                .DATA_WIDTH(DATA_WIDTH)
            ) bram_ref (
                .clk(clk),
                .addr(refAdr_reg[i]),
                .writeEn(loadData),
                .dataIn(refData),
                .dataOut(refData_read[i])
            );
        end
    endgenerate

	
	thresholdCalc #(
		.MAX_WAVEFRONT_LEN(MAX_WAVEFRONT_LEN),
		.LOG_MAX_TILE_SIZE(LOG_MAX_TILE_SIZE),
		.DATA_WIDTH(DATA_WIDTH),
		.REF_LEN_WIDTH(REF_LEN_WIDTH),
		.QUERY_LEN_WIDTH(QUERY_LEN_WIDTH)
	) tc (
		.clk(clk),
		.rst(rst),
		.start(startThresh),
		.numDiag(numDiag),
		.OffsetReg(globalOffsetReg),
		.Kmin(globalKminReg),
		.Kmax(globalKmaxReg),
		.queryLen(queryLen),
		.refLen(refLen),
		.valid_M_s_minus_1_temp(valid_M_s_minus_1_temp),
		.threshold(threshold),
		.done(doneThresh)
	);
	
	WFAReduce #(
		.MAX_WAVEFRONT_LEN(MAX_WAVEFRONT_LEN),
		.LOG_MAX_TILE_SIZE(LOG_MAX_TILE_SIZE),
		.DATA_WIDTH(DATA_WIDTH),
		.REF_LEN_WIDTH(REF_LEN_WIDTH),
		.QUERY_LEN_WIDTH(QUERY_LEN_WIDTH)
	) wfReduce (
		.clk(clk),
		.rst(rst),
		.start(startReduce),
		.OffsetReg(globalOffsetReg),
		.Kmin(globalKminReg),
		.Kmax(globalKmaxReg),
		.queryLen(queryLen),
		.refLen(refLen),
		.threshold(threshold),
		.KminNew(KminNew_w),
		.KmaxNew(KmaxNew_w),
		.valid_M_s_minus_1_temp(valid_M_s_minus_1_temp),
		.done(done)
	);

generate
        for (i = 0; i < NUM_COMPUTE; i += 1) 
        begin: eachComputeMod
            compute_conv #(
                .MAX_WAVEFRONT_LEN(MAX_WAVEFRONT_LEN),
                .LOG_MAX_WAVEFRONT_LEN(LOG_MAX_WAVEFRONT_LEN),
                .MAX_TILE_SIZE(MAX_TILE_SIZE),
                .LOG_MAX_TILE_SIZE(LOG_MAX_TILE_SIZE),
				.TB_POINTER_WIDTH(TB_POINTER_WIDTH),
				.DATA_WIDTH(DATA_WIDTH)
            ) comp (
                .clk(clk),
                .rst(rst),
                .startCompute(startCompute),
				.M_s_minus_2_k_minus_1(M_s_minus_2_k_minus_1[i]),
                .M_s_minus_2_k_plus_1(M_s_minus_2_k_plus_1[i]),
                .M_s_minus_1_k(M_s_minus_1_k[i]),
                .I_s_minus_1_k_minus_1(I_s_minus_1_k_minus_1[i]),	
                .D_s_minus_1_k_plus_1(D_s_minus_1_k_plus_1[i]),
				.M_s_minus_2_k_minus_1_ID(M_s_minus_2_k_minus_1_ID[i]),
                .M_s_minus_2_k_plus_1_ID(M_s_minus_2_k_plus_1_ID[i]),
                .M_s_minus_1_k_ID(M_s_minus_1_k_ID[i]),
                .I_s_minus_1_k_minus_1_ID(I_s_minus_1_k_minus_1_ID[i]),	
                .D_s_minus_1_k_plus_1_ID(D_s_minus_1_k_plus_1_ID[i]),
				.valid_M_s_minus_2_k_minus_1(valid_M_s_minus_2_k_minus_1[i]),
                .valid_M_s_minus_2_k_plus_1(valid_M_s_minus_2_k_plus_1[i]),
                .valid_M_s_minus_1_k(valid_M_s_minus_1_k[i]),
                .valid_I_s_minus_1_k_minus_1(valid_I_s_minus_1_k_minus_1[i]),	
                .valid_D_s_minus_1_k_plus_1(valid_D_s_minus_1_k_plus_1[i]),
				.marker(marker),
				.score(score),
				.k(k_conv[i]),
                .M_s_k(M_s_k[i]),
                .I_s_k(I_s_k[i]),
                .D_s_k(D_s_k[i]),
				.valid_M_s_k(valid_M_s_k[i]),
                .valid_I_s_k(valid_I_s_k[i]),
                .valid_D_s_k(valid_D_s_k[i]), 
				.TB_k(TB_k[i]),
				.M_s_k_ID(M_s_k_ID[i]),
                .I_s_k_ID(I_s_k_ID[i]),
                .D_s_k_ID(D_s_k_ID[i]),
				.doneCompute(doneCompute[i])
            );
        end
    endgenerate
    
	BRAM #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) bram_Kmin (
        .clk(clk),
        .addr(computeKminAddr),
        .writeEn(wrEn_compute),
        .dataIn(globalKminReg_new),
        .dataOut(Kmin_data)
    );
		
	BRAM #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) bram_computeAddr (
        .clk(clk),
        .addr(computeKminAddr),
        .writeEn(wrEn_compute),
        .dataIn(computeAddr),
        .dataOut(computeAddr_data)
    );
		
	BRAM #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) bram_width (
        .clk(clk),
        .addr(computeWidthAddr),
        .writeEn(wrEn_compute),
        .dataIn(widthIn),
        .dataOut(width_data)
    );

    BRAM #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(TB_POINTER_WIDTH)
    ) bram_M (
        .clk(clk),
        .addr(computeAddr_out),
        .writeEn(wrEn_compute),
        .dataIn(TB[count_compute]),
        .dataOut(traceback_ptr_data)
    );
        
   BRAM #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(TB_POINTER_WIDTH)
    ) bram_I (
        .clk(clk),
        .addr(computeAddr_out),
        .writeEn(wrEn_compute),
        .dataIn(TB[count_compute]),
        .dataOut()
    );
        
   BRAM #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(TB_POINTER_WIDTH)
    ) bram_D (
        .clk(clk),
        .addr(computeAddr_out),
        .writeEn(wrEn_compute),
        .dataIn(TB[count_compute]),
        .dataOut()
    );
		
	traceback #(
		.MAX_WAVEFRONT_LEN(MAX_WAVEFRONT_LEN),
		.LOG_MAX_WAVEFRONT_LEN(LOG_MAX_WAVEFRONT_LEN),
		.MAX_TILE_SIZE(MAX_TILE_SIZE),
		.LOG_MAX_TILE_SIZE(LOG_MAX_TILE_SIZE),
		.ADDR_WIDTH(ADDR_WIDTH),
		.DATA_WIDTH(DATA_WIDTH)
	) tb (
		.clk(clk),
		.rst(rst),
		.start_diag(start_diag),
		.start_score(start_score),
		.start_traceback(start_traceback),
		.width_data(width_data),
		.Kmin_data(Kmin_data),
		.traceback_ptr_data(traceback_ptr_data),
		.tb_state(tb_state),
		.traceback_ptr_addr(traceback_ptr_addr),
		.Kmin_addr(Kmin_addr),
		.width_addr(width_addr),
		.stop_traceback(stop_traceback),
		.compact_cigar(compact_cigar),
		.num_compact(num_compact)
	);
*/
endmodule : PEArray
