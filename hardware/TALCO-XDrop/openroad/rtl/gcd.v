module ascii2nt (
	ascii,
	complement,
	nt
);
	input [7:0] ascii;
	input complement;
	output reg [2:0] nt;
	localparam A = 1;
	localparam C = 2;
	localparam G = 3;
	localparam T = 4;
	localparam N = 0;
	always @(*)
		case ({ascii})
			8'h61: nt = (complement ? T : A);
			8'h41: nt = (complement ? T : A);
			8'h63: nt = (complement ? G : C);
			8'h43: nt = (complement ? G : C);
			8'h67: nt = (complement ? C : G);
			8'h47: nt = (complement ? C : G);
			8'h74: nt = (complement ? A : T);
			8'h54: nt = (complement ? A : T);
			8'h6e: nt = N;
			8'h4e: nt = N;
			default: nt = N;
		endcase
endmodule
module BRAM_kernel (
	clk,
	addr,
	write_en,
	data_in,
	data_out
);
	parameter ADDR_WIDTH = 8;
	parameter DATA_WIDTH = 16;
	input wire clk;
	input wire [ADDR_WIDTH - 1:0] addr;
	input wire write_en;
	input wire [DATA_WIDTH - 1:0] data_in;
	output reg [DATA_WIDTH - 1:0] data_out;
	(* ram_style = "ultra" *) reg [DATA_WIDTH - 1:0] mem [0:(2 ** ADDR_WIDTH) - 1];
	always @(posedge clk) begin
		if (write_en == 1)
			mem[addr] <= data_in;
		data_out <= mem[addr];
	end
endmodule
module DPBram (
	addra,
	addrb,
	dina,
	clka,
	wea,
	enb,
	rstb,
	regceb,
	doutb
);
	parameter RAM_WIDTH = 64;
	parameter RAM_DEPTH = 512;
	parameter RAM_PERFORMANCE = 1;
	input [$clog2(RAM_DEPTH - 1) - 1:0] addra;
	input [$clog2(RAM_DEPTH - 1) - 1:0] addrb;
	input [RAM_WIDTH - 1:0] dina;
	input clka;
	input wea;
	input enb;
	input rstb;
	input regceb;
	output wire [RAM_WIDTH - 1:0] doutb;
	reg [RAM_WIDTH - 1:0] BRAM [0:RAM_DEPTH - 1];
	reg [RAM_WIDTH - 1:0] ram_data = {RAM_WIDTH {1'b0}};
	always @(posedge clka) begin
		if (wea)
			BRAM[addra] <= dina;
		if (enb)
			ram_data <= BRAM[addrb];
	end
	generate
		if (RAM_PERFORMANCE == 0) begin : no_output_register
			assign doutb = ram_data;
		end
		else begin : output_register
			reg [RAM_WIDTH - 1:0] doutb_reg = {RAM_WIDTH {1'b0}};
			always @(posedge clka)
				if (rstb)
					doutb_reg <= {RAM_WIDTH {1'b0}};
				else if (regceb)
					doutb_reg <= ram_data;
			assign doutb = doutb_reg;
		end
	endgenerate
endmodule
module asym_ram_sdp_write_wider (
	clk,
	weA,
	enaA,
	enaB,
	addrA,
	addrB,
	diA,
	doB
);
	parameter WIDTHB = 8;
	parameter WIDTHA = 32;
	parameter SIZEA = 256;
	localparam ADDRWIDTHA = $clog2(SIZEA);
	localparam SIZEB = (SIZEA * WIDTHA) / WIDTHB;
	localparam ADDRWIDTHB = $clog2(SIZEB);
	input clk;
	input weA;
	input enaA;
	input enaB;
	input [ADDRWIDTHA - 1:0] addrA;
	input [ADDRWIDTHB - 1:0] addrB;
	input [WIDTHA - 1:0] diA;
	output wire [WIDTHB - 1:0] doB;
	localparam maxSIZE = {(SIZEA > SIZEB ? SIZEA : SIZEB)};
	localparam maxWIDTH = {(WIDTHA > WIDTHB ? WIDTHA : WIDTHB)};
	localparam minWIDTH = {(WIDTHA < WIDTHB ? WIDTHA : WIDTHB)};
	localparam RATIO = maxWIDTH / minWIDTH;
	localparam log2RATIO = $clog2(RATIO);
	reg [minWIDTH - 1:0] RAM [0:maxSIZE - 1];
	reg [WIDTHB - 1:0] readB;
	always @(posedge clk)
		if (enaB)
			readB <= RAM[addrB];
	assign doB = readB;
	always @(posedge clk) begin : ramwrite
		integer i;
		reg [log2RATIO - 1:0] lsbaddr;
		for (i = 0; i < RATIO; i = i + 1)
			begin : write1
				lsbaddr = i;
				if (enaA) begin
					if (weA)
						RAM[{addrA, lsbaddr}] <= diA[((i + 1) * minWIDTH) - 1-:minWIDTH];
				end
			end
	end
endmodule
module nt2param (
	nt,
	in_param,
	out_param
);
	parameter PE_WIDTH = 16;
	input [2:0] nt;
	input [(13 * PE_WIDTH) - 1:0] in_param;
	output reg [(4 * PE_WIDTH) - 1:0] out_param;
	localparam A = 1;
	localparam C = 2;
	localparam G = 3;
	localparam T = 4;
	localparam N = 0;
	always @(*)
		case ({nt})
			A: out_param = {in_param[(13 * PE_WIDTH) - 1:9 * PE_WIDTH]};
			C: out_param = {in_param[(12 * PE_WIDTH) - 1:11 * PE_WIDTH], in_param[(9 * PE_WIDTH) - 1:6 * PE_WIDTH]};
			G: out_param = {in_param[(11 * PE_WIDTH) - 1:10 * PE_WIDTH], in_param[(8 * PE_WIDTH) - 1:7 * PE_WIDTH], in_param[(6 * PE_WIDTH) - 1:4 * PE_WIDTH]};
			T: out_param = {in_param[(10 * PE_WIDTH) - 1:9 * PE_WIDTH], in_param[(7 * PE_WIDTH) - 1:6 * PE_WIDTH], in_param[(5 * PE_WIDTH) - 1:3 * PE_WIDTH]};
			N: out_param = {in_param[(3 * PE_WIDTH) - 1:2 * PE_WIDTH], in_param[(3 * PE_WIDTH) - 1:2 * PE_WIDTH], in_param[(3 * PE_WIDTH) - 1:2 * PE_WIDTH], in_param[(3 * PE_WIDTH) - 1:2 * PE_WIDTH]};
			default: out_param = {4 * PE_WIDTH {1'b0}};
		endcase
endmodule
module compute_tb_start (
	clk,
	marker,
	conv_value,
	conv_query_idx,
	conv_ref_idx,
	conv_state
);
	parameter PE_WIDTH = 8;
	parameter LOG_MAX_TILE_SIZE = 10;
	parameter REF_LEN_WIDTH = 10;
	input clk;
	input [LOG_MAX_TILE_SIZE:0] marker;
	input [REF_LEN_WIDTH + 1:0] conv_value;
	output reg [REF_LEN_WIDTH - 1:0] conv_query_idx;
	output reg [REF_LEN_WIDTH - 1:0] conv_ref_idx;
	output reg [1:0] conv_state;
	wire [REF_LEN_WIDTH - 1:0] conv_ref_idx_next;
	wire [1:0] conv_marker;
	assign {conv_ref_idx_next, conv_marker} = conv_value;
	always @(posedge clk) begin
		conv_ref_idx <= conv_ref_idx_next;
		conv_query_idx <= (marker - conv_ref_idx_next) - (conv_marker == 3);
		case (conv_marker)
			0: conv_state <= 0;
			2: conv_state <= 1;
			1: conv_state <= 2;
			3: conv_state <= 0;
		endcase
	end
endmodule
module PE_Array (
	clk,
	rst,
	start,
	in_param,
	total_ref_length,
	total_query_length,
	complement_ref_in,
	ref_bram_addr,
	ref_bram_data_out,
	complement_query_in,
	query_bram_addr,
	query_bram_data_out,
	rstb,
	regceb,
	score_bram_wr_en_ext,
	score_bram_rd_en,
	score_bram_data_in,
	score_bram_data_out,
	score_bram_addr_wr,
	score_bram_addr_rd,
	tb_bram_wr_en,
	tb_bram_data_in,
	tb_bram_data_out,
	tb_bram_addr_reg,
	last_tile,
	INF,
	marker,
	xdrop_value,
	init_state,
	tb_pointer,
	tb_valid,
	query_next_tile_addr,
	ref_next_tile_addr,
	next_tile_init_state,
	commit,
	traceback,
	stop
);
	parameter PE_WIDTH = 8;
	parameter DATA_WIDTH = 16;
	parameter NUM_BLOCK = 4;
	parameter NUM_PE = 2;
	parameter LOG_NUM_PE = $clog2(NUM_PE);
	parameter MAX_TILE_SIZE = 16;
	parameter LOG_MAX_TILE_SIZE = $clog2(MAX_TILE_SIZE);
	parameter REF_LEN_WIDTH = 8;
	parameter QUERY_LEN_WIDTH = 8;
	parameter PARAM_ADDR_WIDTH = 8;
	parameter CONV_SCORE_WIDTH = ((1 + (2 * (REF_LEN_WIDTH + 2))) + (3 * PE_WIDTH)) + 1;
	parameter TB_DATA_WIDTH = 4 * NUM_PE;
	parameter TB_ADDR_WIDTH = $clog2((2 * (MAX_TILE_SIZE / NUM_PE)) * MAX_TILE_SIZE);
	input wire clk;
	input wire rst;
	input wire start;
	input wire [(13 * PE_WIDTH) - 1:0] in_param;
	input wire [REF_LEN_WIDTH - 1:0] total_ref_length;
	input wire [QUERY_LEN_WIDTH - 1:0] total_query_length;
	input wire complement_ref_in;
	output reg [LOG_MAX_TILE_SIZE / NUM_BLOCK:0] ref_bram_addr;
	input wire [DATA_WIDTH - 1:0] ref_bram_data_out;
	input wire complement_query_in;
	output reg [LOG_MAX_TILE_SIZE / NUM_BLOCK:0] query_bram_addr;
	input wire [DATA_WIDTH - 1:0] query_bram_data_out;
	output reg rstb;
	output reg regceb;
	output wire score_bram_wr_en_ext;
	output reg score_bram_rd_en;
	output wire [CONV_SCORE_WIDTH - 1:0] score_bram_data_in;
	input wire [CONV_SCORE_WIDTH - 1:0] score_bram_data_out;
	output reg [LOG_MAX_TILE_SIZE - 1:0] score_bram_addr_wr;
	output reg [LOG_MAX_TILE_SIZE - 1:0] score_bram_addr_rd;
	output reg tb_bram_wr_en;
	output reg [TB_DATA_WIDTH - 1:0] tb_bram_data_in;
	input wire [TB_DATA_WIDTH - 1:0] tb_bram_data_out;
	output reg [TB_ADDR_WIDTH - 1:0] tb_bram_addr_reg;
	output reg last_tile;
	input wire [PE_WIDTH - 1:0] INF;
	input wire [LOG_MAX_TILE_SIZE:0] marker;
	input wire signed [PE_WIDTH - 1:0] xdrop_value;
	input [1:0] init_state;
	output wire [1:0] tb_pointer;
	output wire tb_valid;
	output wire [QUERY_LEN_WIDTH - 1:0] query_next_tile_addr;
	output wire [REF_LEN_WIDTH - 1:0] ref_next_tile_addr;
	output wire [1:0] next_tile_init_state;
	output wire commit;
	output wire traceback;
	output wire stop;
	localparam PARAM_WIDTH = 4 * PE_WIDTH;
	reg score_bram_wr_en;
	wire score_bram_wr_en_delayed;
	reg [31:0] STATE;
	wire [2:0] ref_nt;
	wire [2:0] query_nt;
	reg block;
	wire [PARAM_WIDTH - 1:0] param;
	wire [PARAM_WIDTH - 1:0] out_param;
	reg [REF_LEN_WIDTH - 1:0] curr_ref_length;
	reg [QUERY_LEN_WIDTH - 1:0] curr_query_length;
	reg init_n;
	wire init_in [0:NUM_PE - 1];
	reg [NUM_PE - 1:0] set_param;
	wire [2:0] ref_in [0:NUM_PE - 1];
	wire signed [PE_WIDTH - 1:0] sub_A_in;
	wire signed [PE_WIDTH - 1:0] sub_C_in;
	wire signed [PE_WIDTH - 1:0] sub_G_in;
	wire signed [PE_WIDTH - 1:0] sub_T_in;
	reg signed [PE_WIDTH - 1:0] sub_N_in;
	reg signed [PE_WIDTH - 1:0] gap_open_in;
	reg signed [PE_WIDTH - 1:0] gap_extend_in;
	reg [REF_LEN_WIDTH - 1:0] curr_ref_idx;
	reg [REF_LEN_WIDTH - 1:0] ref_idx_in [0:NUM_PE - 1];
	reg [QUERY_LEN_WIDTH - 1:0] query_idx_in [0:NUM_PE - 1];
	wire signed [PE_WIDTH - 1:0] conv_score;
	wire [REF_LEN_WIDTH - 1:0] conv_query_idx;
	wire [REF_LEN_WIDTH - 1:0] conv_ref_idx;
	wire [1:0] conv_tb_state;
	wire [LOG_MAX_TILE_SIZE - 1:0] block_rd_idx;
	reg signed [PE_WIDTH - 1:0] global_max_score;
	reg signed [PE_WIDTH - 1:0] ad_max_score;
	wire signed [PE_WIDTH - 1:0] ad_max_score_next;
	wire signed [PE_WIDTH - 1:0] ad_max_score_prev_block;
	wire signed [PE_WIDTH - 1:0] ad_max_score_prev_block_raw;
	reg signed [PE_WIDTH - 1:0] cur_ad_max_score;
	reg [REF_LEN_WIDTH - 1:0] global_max_ref_idx;
	reg [REF_LEN_WIDTH:0] global_max_ad_idx;
	reg [REF_LEN_WIDTH:0] convergence_detected_ad_idx;
	reg [QUERY_LEN_WIDTH - 1:0] global_max_query_idx;
	reg signed [PE_WIDTH - 1:0] H_init;
	wire signed [PE_WIDTH - 1:0] D_init_in;
	wire signed [PE_WIDTH - 1:0] H_prev_block;
	wire signed [PE_WIDTH - 1:0] H_prev_block_raw;
	wire signed [PE_WIDTH - 1:0] I_prev_block;
	wire signed [PE_WIDTH - 1:0] I_prev_block_raw;
	reg signed [PE_WIDTH - 1:0] H_PE_prev [0:NUM_PE - 1];
	reg signed [PE_WIDTH - 1:0] I_PE_prev [0:NUM_PE - 1];
	reg [REF_LEN_WIDTH + 1:0] CH_PE_prev [0:NUM_PE - 1];
	wire [REF_LEN_WIDTH + 1:0] CH_PE_prev_block;
	wire [REF_LEN_WIDTH + 1:0] CH_PE_prev_block_pipe;
	wire [REF_LEN_WIDTH + 1:0] CI_PE_prev_block;
	wire [REF_LEN_WIDTH + 1:0] CH_PE_prev_block_raw;
	wire [REF_LEN_WIDTH + 1:0] CI_PE_prev_block_raw;
	reg [REF_LEN_WIDTH + 1:0] CI_PE_prev [0:NUM_PE - 1];
	wire signed [PE_WIDTH - 1:0] rd_array [0:NUM_PE - 1];
	wire init_out [0:NUM_PE - 1];
	wire [2:0] ref_out [0:NUM_PE - 1];
	wire [TB_DATA_WIDTH - 1:0] dir_out;
	wire [REF_LEN_WIDTH - 1:0] ref_idx_out [0:NUM_PE - 1];
	wire [QUERY_LEN_WIDTH - 1:0] query_idx_out [0:NUM_PE - 1];
	wire [REF_LEN_WIDTH + 1:0] H_rd_value;
	wire [REF_LEN_WIDTH + 1:0] I_rd_value;
	wire [REF_LEN_WIDTH + 1:0] D_rd_value;
	wire signed [PE_WIDTH - 1:0] rd_value;
	wire signed [(NUM_PE * PE_WIDTH) - 1:0] H_PE;
	wire signed [PE_WIDTH - 1:0] I_PE [0:NUM_PE - 1];
	wire signed [PE_WIDTH - 1:0] D_PE [0:NUM_PE - 1];
	wire [((REF_LEN_WIDTH + 1) >= 0 ? (NUM_PE * (REF_LEN_WIDTH + 2)) - 1 : (NUM_PE * (1 - (REF_LEN_WIDTH + 1))) + (REF_LEN_WIDTH + 0)):((REF_LEN_WIDTH + 1) >= 0 ? 0 : REF_LEN_WIDTH + 1)] CH_PE;
	wire [((REF_LEN_WIDTH + 1) >= 0 ? (NUM_PE * (REF_LEN_WIDTH + 2)) - 1 : (NUM_PE * (1 - (REF_LEN_WIDTH + 1))) + (REF_LEN_WIDTH + 0)):((REF_LEN_WIDTH + 1) >= 0 ? 0 : REF_LEN_WIDTH + 1)] CI_PE;
	wire [((REF_LEN_WIDTH + 1) >= 0 ? (NUM_PE * (REF_LEN_WIDTH + 2)) - 1 : (NUM_PE * (1 - (REF_LEN_WIDTH + 1))) + (REF_LEN_WIDTH + 0)):((REF_LEN_WIDTH + 1) >= 0 ? 0 : REF_LEN_WIDTH + 1)] CD_PE;
	reg lower_bound_check;
	reg [$clog2(MAX_TILE_SIZE / NUM_PE):0] block_count;
	reg [REF_LEN_WIDTH - 1:0] start_idx;
	reg [REF_LEN_WIDTH - 1:0] lower_bound_value;
	reg [TB_ADDR_WIDTH - 1:0] tb_bram_start_sub_ref_start [(MAX_TILE_SIZE / NUM_PE) - 1:0];
	reg conv;
	reg C1;
	reg C2;
	reg C3;
	reg C4;
	reg C5;
	reg query_oflow;
	reg ref_oflow;
	always @(posedge clk)
		if (rst)
			ref_oflow <= 0;
		else
			ref_oflow <= curr_ref_length >= total_ref_length;
	always @(posedge clk)
		if (rst)
			query_oflow <= 0;
		else
			query_oflow <= curr_query_length >= total_query_length;
	reg [REF_LEN_WIDTH + 1:0] global_max_conv_idx;
	reg tb_start;
	wire [1:0] tb_state;
	wire [TB_ADDR_WIDTH - 1:0] tb_bram_addr_out;
	reg [TB_ADDR_WIDTH - 1:0] tb_bram_addr;
	wire tb_done;
	wire last_PE_not_droped;
	wire [REF_LEN_WIDTH:0] curr_ad_idx;
	assign curr_ad_idx = curr_ref_length + (curr_query_length - NUM_PE);
	reg past_marking;
	always @(posedge clk) past_marking <= curr_ad_idx > (marker + 1);
	wire [CONV_SCORE_WIDTH - 1:0] prev_block_to_write;
	wire H_converged_this_block;
	wire H_converged;
	wire I_converged;
	wire D_converged;
	wire this_ad_converged;
	assign prev_block_to_write = {this_ad_converged, H_converged, CH_PE[((REF_LEN_WIDTH + 1) >= 0 ? 0 : REF_LEN_WIDTH + 1) + (((NUM_PE - 1) - (NUM_PE - 1)) * ((REF_LEN_WIDTH + 1) >= 0 ? REF_LEN_WIDTH + 2 : 1 - (REF_LEN_WIDTH + 1)))+:((REF_LEN_WIDTH + 1) >= 0 ? REF_LEN_WIDTH + 2 : 1 - (REF_LEN_WIDTH + 1))], CI_PE[((REF_LEN_WIDTH + 1) >= 0 ? 0 : REF_LEN_WIDTH + 1) + (((NUM_PE - 1) - (NUM_PE - 1)) * ((REF_LEN_WIDTH + 1) >= 0 ? REF_LEN_WIDTH + 2 : 1 - (REF_LEN_WIDTH + 1)))+:((REF_LEN_WIDTH + 1) >= 0 ? REF_LEN_WIDTH + 2 : 1 - (REF_LEN_WIDTH + 1))], H_PE[((NUM_PE - 1) - (NUM_PE - 1)) * PE_WIDTH+:PE_WIDTH], I_PE[NUM_PE - 1], ad_max_score_next};
	wire CID_prev_block;
	wire CID_prev_block_raw;
	wire H_converged_prev_block;
	wire H_converged_prev_block_raw;
	assign {CID_prev_block_raw, H_converged_prev_block_raw, CH_PE_prev_block_raw, CI_PE_prev_block_raw, H_prev_block_raw, I_prev_block_raw, ad_max_score_prev_block_raw} = score_bram_data_out;
	wire CID_writing_debug;
	wire signed [PE_WIDTH - 1:0] H_WR_debug;
	wire signed [PE_WIDTH - 1:0] I_WR_debug;
	wire signed [PE_WIDTH - 1:0] ad_WR_debug;
	wire [REF_LEN_WIDTH + 1:0] CH_WR_debug;
	wire [REF_LEN_WIDTH + 1:0] CI_WR_debug;
	assign {CID_writing_debug, CH_WR_debug, CI_WR_debug, H_WR_debug, I_WR_debug, ad_WR_debug} = score_bram_data_in;
	sft_reg #(
		.BW(CONV_SCORE_WIDTH),
		.DEPTH(3)
	) score_wr_delay(
		.clk(clk),
		.en(1),
		.in(prev_block_to_write),
		.out(score_bram_data_in)
	);
	sft_w_rst #(.DEPTH(3)) en_pipe(
		.clk(clk),
		.rst(rst),
		.en(1),
		.in(score_bram_wr_en),
		.out(score_bram_wr_en_delayed)
	);
	wire score_valid_delayed;
	sft_w_rst #(.DEPTH(3)) score_valid_pipe(
		.clk(clk),
		.rst(rst),
		.en(1),
		.in(init_out[NUM_PE - 1]),
		.out(score_valid_delayed)
	);
	assign score_bram_wr_en_ext = (score_bram_wr_en_delayed | score_bram_wr_en) & score_valid_delayed;
	always @(posedge clk)
		if (score_bram_wr_en_ext)
			score_bram_addr_wr <= score_bram_addr_wr + 1;
		else
			score_bram_addr_wr <= 0;
	wire past_score_bram_wr_en_ext;
	parameter CONV_DONT_CARE = 0;
	parameter NU_DONT_CARE = 5;
	sft_w_rst #(.DEPTH(1)) score_bram_wr_pipe(
		.clk(clk),
		.rst(rst),
		.en(1),
		.in(score_bram_wr_en_ext),
		.out(past_score_bram_wr_en_ext)
	);
	reg [LOG_MAX_TILE_SIZE - 1:0] score_bram_valid_up_to;
	always @(posedge clk)
		if (!score_bram_wr_en_ext && past_score_bram_wr_en_ext)
			score_bram_valid_up_to <= score_bram_addr_wr - 1;
	always @(posedge clk)
		if (rst)
			score_bram_rd_en <= 0;
		else if (((block && set_param[NUM_PE - 4]) && start_idx) || (block && set_param[NUM_PE - 3]))
			score_bram_rd_en <= 1;
		else if ((score_bram_addr_rd == score_bram_valid_up_to) || set_param[0])
			score_bram_rd_en <= 0;
	wire past_score_bram_rd_en;
	sft_w_rst #(.DEPTH(1)) score_bram_rd_pipe(
		.clk(clk),
		.rst(rst),
		.en(1),
		.in(score_bram_rd_en),
		.out(past_score_bram_rd_en)
	);
	wire not_last_droped_in_prev_block = past_score_bram_rd_en && score_bram_rd_en;
	wire CID_prev_block_temp;
	sft_reg #(
		.DEPTH(1),
		.BW(1)
	) CID_pipe(
		.clk(clk),
		.en(1),
		.in(CID_prev_block_raw),
		.out(CID_prev_block_temp)
	);
	assign CID_prev_block = !not_last_droped_in_prev_block || CID_prev_block_temp;
	wire H_converged_prev_block_temp;
	sft_reg #(
		.DEPTH(1),
		.BW(1)
	) H_converged_pipe(
		.clk(clk),
		.en(1),
		.in(H_converged_prev_block_raw),
		.out(H_converged_prev_block_temp)
	);
	assign H_converged_prev_block = !not_last_droped_in_prev_block || H_converged_prev_block_temp;
	wire prev_blk_valid;
	sft_reg #(
		.DEPTH(1),
		.BW(1)
	) prev_block_valid_pipe(
		.clk(clk),
		.en(1),
		.in(past_score_bram_rd_en),
		.out(prev_blk_valid)
	);
	assign CH_PE_prev_block = (past_score_bram_rd_en ? CH_PE_prev_block_raw : CONV_DONT_CARE);
	sft_reg #(
		.DEPTH(1),
		.BW(REF_LEN_WIDTH + 2)
	) CH_IDX_pipe(
		.clk(clk),
		.en(1),
		.in(CH_PE_prev_block),
		.out(CH_PE_prev_block_pipe)
	);
	sft_reg #(
		.DEPTH(1),
		.BW(PE_WIDTH)
	) ad_max_pipe(
		.clk(clk),
		.en(1),
		.in(ad_max_score_prev_block_raw),
		.out(ad_max_score_prev_block)
	);
	assign CI_PE_prev_block = (past_score_bram_rd_en ? CI_PE_prev_block_raw : CONV_DONT_CARE);
	assign H_prev_block = (past_score_bram_rd_en ? H_prev_block_raw : -INF);
	assign I_prev_block = (past_score_bram_rd_en ? I_prev_block_raw : -INF);
	assign last_PE_not_droped = (H_PE[((NUM_PE - 1) - (NUM_PE - 1)) * PE_WIDTH+:PE_WIDTH] + xdrop_value) >= ad_max_score;
	assign H_converged = ((H_converged_this_block && H_converged_prev_block) && past_marking) && (!not_last_droped_in_prev_block || (H_rd_value == CH_PE_prev_block_pipe));
	assign this_ad_converged = ((((H_converged && CID_prev_block) && I_converged) && D_converged) && (((I_rd_value == H_rd_value) || (I_rd_value == CONV_DONT_CARE)) || (H_rd_value == CONV_DONT_CARE))) && (((D_rd_value == H_rd_value) || (D_rd_value == CONV_DONT_CARE)) || (H_rd_value == CONV_DONT_CARE));
	reg [REF_LEN_WIDTH + 1:0] H_rd_value_prev_ad;
	reg H_converged_prev_ad;
	always @(posedge clk) begin
		H_rd_value_prev_ad <= H_rd_value;
		H_converged_prev_ad <= H_converged;
	end
	reg signed [PE_WIDTH - 1:0] diag_delayed;
	reg [REF_LEN_WIDTH + 1:0] diag_CH_delayed;
	reg score_bram_loaded_first;
	always @(posedge clk)
		if (rst)
			score_bram_loaded_first <= 0;
		else
			score_bram_loaded_first <= score_bram_rd_en && (score_bram_addr_rd == 0);
	always @(posedge clk)
		if (score_bram_loaded_first)
			diag_delayed <= H_prev_block;
		else if ((set_param[NUM_PE - 2] && block) && !start_idx)
			diag_delayed <= -INF;
	always @(posedge clk)
		if (score_bram_loaded_first)
			diag_CH_delayed <= CH_PE_prev_block;
	reg init_0_delayed;
	always @(posedge clk)
		if (STATE == 32'd2)
			init_0_delayed <= 0;
		else if (init_out[0])
			init_0_delayed <= 1;
	always @(*) begin
		curr_ref_idx = ($signed(ref_idx_in[NUM_PE - 1] - 3) > 0 ? ref_idx_in[NUM_PE - 1] - 3 : 0);
		tb_bram_addr_reg = (STATE == 32'd9 ? tb_bram_addr_out : tb_bram_addr);
		C1 = (curr_ref_idx >= (total_ref_length - 1) ? 1 : 0);
		C2 = (curr_query_length >= (total_query_length - 1) ? 1 : 0);
		C3 = (!not_last_droped_in_prev_block && init_0_delayed) && ((rd_value + xdrop_value) < ad_max_score);
		C4 = global_max_ad_idx >= convergence_detected_ad_idx;
		C5 = ((this_ad_converged && (H_rd_value == H_rd_value_prev_ad)) && past_marking) && H_converged_prev_ad;
	end
	wire start_tb_from_xdrop;
	assign start_tb_from_xdrop = global_max_ad_idx <= (marker + 2);
	always @(posedge clk)
		if (rst)
			last_tile <= 0;
		else if ((STATE == 32'd9) && start_tb_from_xdrop)
			last_tile <= 1;
	wire convergence_detected;
	assign convergence_detected = (((C5 && (STATE == 32'd4)) && init_out[0]) && (!init_n || !last_PE_not_droped)) && !lower_bound_check;
	always @(posedge clk)
		if (rst)
			conv <= 0;
		else if (convergence_detected)
			conv <= 1;
	compute_tb_start #(
		.PE_WIDTH(PE_WIDTH),
		.LOG_MAX_TILE_SIZE(LOG_MAX_TILE_SIZE),
		.REF_LEN_WIDTH(REF_LEN_WIDTH)
	) tb_init_inst(
		.clk(clk),
		.marker(marker),
		.conv_value(global_max_conv_idx),
		.conv_query_idx(conv_query_idx),
		.conv_ref_idx(conv_ref_idx),
		.conv_state(conv_tb_state)
	);
	always @(posedge clk)
		if (rst)
			convergence_detected_ad_idx <= INF;
		else if (convergence_detected && !conv)
			convergence_detected_ad_idx <= curr_ad_idx;
	always @(posedge clk)
		if (set_param[0])
			tb_bram_start_sub_ref_start[block_count - 2] <= (tb_bram_addr - lower_bound_value) + NUM_PE;
	ascii2nt ref_ascii2nt(
		.ascii(ref_bram_data_out),
		.complement(complement_ref_in),
		.nt(ref_nt)
	);
	ascii2nt query_ascii2nt(
		.ascii(query_bram_data_out),
		.complement(complement_query_in),
		.nt(query_nt)
	);
	nt2param #(.PE_WIDTH(PE_WIDTH)) query_nt2param(
		.nt(query_nt),
		.in_param(in_param),
		.out_param(out_param)
	);
	assign param = out_param;
	assign {sub_A_in, sub_C_in, sub_G_in, sub_T_in} = (query_oflow ? {{4 * PE_WIDTH} {1'b0}} : param);
	wire [(NUM_PE * (((REF_LEN_WIDTH + 2) + REF_LEN_WIDTH) + QUERY_LEN_WIDTH)) - 1:0] max_val_to_sel;
	wire [(((REF_LEN_WIDTH + 2) + REF_LEN_WIDTH) + QUERY_LEN_WIDTH) - 1:0] selected_idx;
	genvar _gv_i_1;
	generate
		for (_gv_i_1 = 0; _gv_i_1 < NUM_PE; _gv_i_1 = _gv_i_1 + 1) begin : pe_gen
			localparam i = _gv_i_1;
			PE #(
				.PE_WIDTH(PE_WIDTH),
				.DATA_WIDTH(DATA_WIDTH),
				.NUM_BLOCK(NUM_BLOCK),
				.NUM_PE(NUM_PE),
				.LOG_NUM_PE(LOG_NUM_PE),
				.REF_LEN_WIDTH(REF_LEN_WIDTH),
				.QUERY_LEN_WIDTH(QUERY_LEN_WIDTH),
				.PE_IDX(i),
				.LOG_MAX_TILE_SIZE(LOG_MAX_TILE_SIZE)
			) pe_affine(
				.clk(clk),
				.rst(rst),
				.init_in(init_in[i]),
				.set_param(set_param[i]),
				.ref_in(ref_in[i]),
				.param_valid_in(!query_oflow),
				.sub_A_in(sub_A_in),
				.sub_C_in(sub_C_in),
				.sub_G_in(sub_G_in),
				.sub_T_in(sub_T_in),
				.sub_N_in(sub_N_in),
				.gap_open_in(gap_open_in),
				.gap_extend_in(gap_extend_in),
				.INF(INF),
				.block(block),
				.diag_score(diag_delayed),
				.diag_CH_score(diag_CH_delayed),
				.start_idx(start_idx),
				.marker(marker),
				.ref_idx_in(ref_idx_in[i]),
				.query_idx_in(query_idx_in[i]),
				.D_init_in(D_init_in),
				.H_init_in(H_init),
				.H_PE_prev(H_PE_prev[i]),
				.I_PE_prev(I_PE_prev[i]),
				.CH_PE_prev(CH_PE_prev[i]),
				.CI_PE_prev(CI_PE_prev[i]),
				.init_out(init_out[i]),
				.dir_out(dir_out[(4 * i) + 3:4 * i]),
				.ref_out(ref_out[i]),
				.ref_idx_out(ref_idx_out[i]),
				.query_idx_out(query_idx_out[i]),
				.init_state(init_state),
				.H_PE(H_PE[((NUM_PE - 1) - i) * PE_WIDTH+:PE_WIDTH]),
				.I_PE(I_PE[i]),
				.D_PE(D_PE[i]),
				.CH_PE(CH_PE[((REF_LEN_WIDTH + 1) >= 0 ? 0 : REF_LEN_WIDTH + 1) + (((NUM_PE - 1) - i) * ((REF_LEN_WIDTH + 1) >= 0 ? REF_LEN_WIDTH + 2 : 1 - (REF_LEN_WIDTH + 1)))+:((REF_LEN_WIDTH + 1) >= 0 ? REF_LEN_WIDTH + 2 : 1 - (REF_LEN_WIDTH + 1))]),
				.CI_PE(CI_PE[((REF_LEN_WIDTH + 1) >= 0 ? 0 : REF_LEN_WIDTH + 1) + (((NUM_PE - 1) - i) * ((REF_LEN_WIDTH + 1) >= 0 ? REF_LEN_WIDTH + 2 : 1 - (REF_LEN_WIDTH + 1)))+:((REF_LEN_WIDTH + 1) >= 0 ? REF_LEN_WIDTH + 2 : 1 - (REF_LEN_WIDTH + 1))]),
				.CD_PE(CD_PE[((REF_LEN_WIDTH + 1) >= 0 ? 0 : REF_LEN_WIDTH + 1) + (((NUM_PE - 1) - i) * ((REF_LEN_WIDTH + 1) >= 0 ? REF_LEN_WIDTH + 2 : 1 - (REF_LEN_WIDTH + 1)))+:((REF_LEN_WIDTH + 1) >= 0 ? REF_LEN_WIDTH + 2 : 1 - (REF_LEN_WIDTH + 1))])
			);
			assign max_val_to_sel[((NUM_PE - 1) - i) * (((REF_LEN_WIDTH + 2) + REF_LEN_WIDTH) + QUERY_LEN_WIDTH)+:((REF_LEN_WIDTH + 2) + REF_LEN_WIDTH) + QUERY_LEN_WIDTH] = {CH_PE[((REF_LEN_WIDTH + 1) >= 0 ? 0 : REF_LEN_WIDTH + 1) + (((NUM_PE - 1) - i) * ((REF_LEN_WIDTH + 1) >= 0 ? REF_LEN_WIDTH + 2 : 1 - (REF_LEN_WIDTH + 1)))+:((REF_LEN_WIDTH + 1) >= 0 ? REF_LEN_WIDTH + 2 : 1 - (REF_LEN_WIDTH + 1))], ref_idx_out[i], query_idx_out[i]};
		end
	endgenerate
	wire [REF_LEN_WIDTH + 1:0] max_CH_val;
	wire [REF_LEN_WIDTH - 1:0] cur_max_query_idx;
	wire [QUERY_LEN_WIDTH - 1:0] cur_max_ref_idx;
	reduction_tree_max #(
		.PE_WIDTH(PE_WIDTH),
		.SEL_WIDTH(((REF_LEN_WIDTH + 2) + REF_LEN_WIDTH) + QUERY_LEN_WIDTH),
		.NUM_PE(NUM_PE),
		.LOG_NUM_PE(LOG_NUM_PE)
	) rd_tree_max(
		.to_sel(max_val_to_sel),
		.array(H_PE),
		.reduction_value(rd_value),
		.selected(selected_idx)
	);
	assign {max_CH_val, cur_max_ref_idx, cur_max_query_idx} = selected_idx;
	reduction_tree_value #(
		.PE_WIDTH(REF_LEN_WIDTH + 2),
		.NUM_PE(NUM_PE),
		.LOG_NUM_PE(LOG_NUM_PE)
	) rd_tree_M(
		.array(CH_PE),
		.reduction_value(H_rd_value),
		.reduction_bool(H_converged_this_block)
	);
	reduction_tree_value #(
		.PE_WIDTH(REF_LEN_WIDTH + 2),
		.NUM_PE(NUM_PE),
		.LOG_NUM_PE(LOG_NUM_PE)
	) rd_tree_I(
		.array(CI_PE),
		.reduction_value(I_rd_value),
		.reduction_bool(I_converged)
	);
	reduction_tree_value #(
		.PE_WIDTH(REF_LEN_WIDTH + 2),
		.NUM_PE(NUM_PE),
		.LOG_NUM_PE(LOG_NUM_PE)
	) rd_tree_D(
		.array(CD_PE),
		.reduction_value(D_rd_value),
		.reduction_bool(D_converged)
	);
	assign query_next_tile_addr = (start_tb_from_xdrop ? global_max_query_idx : conv_query_idx);
	assign ref_next_tile_addr = (start_tb_from_xdrop ? global_max_ref_idx : conv_ref_idx);
	assign next_tile_init_state = (start_tb_from_xdrop ? 0 : conv_tb_state);
	traceback #(
		.PE_WIDTH(PE_WIDTH),
		.DATA_WIDTH(DATA_WIDTH),
		.NUM_BLOCK(NUM_BLOCK),
		.NUM_PE(NUM_PE),
		.LOG_NUM_PE(LOG_NUM_PE),
		.MAX_TILE_SIZE(MAX_TILE_SIZE),
		.LOG_MAX_TILE_SIZE(LOG_MAX_TILE_SIZE),
		.REF_LEN_WIDTH(REF_LEN_WIDTH),
		.QUERY_LEN_WIDTH(QUERY_LEN_WIDTH),
		.PARAM_ADDR_WIDTH(PARAM_ADDR_WIDTH),
		.CONV_SCORE_WIDTH(CONV_SCORE_WIDTH),
		.TB_DATA_WIDTH(TB_DATA_WIDTH)
	) tb(
		.clk(clk),
		.rst(rst),
		.tb_start(tb_start),
		.start_query_idx(query_next_tile_addr),
		.start_ref_idx(ref_next_tile_addr),
		.start_tb_state(next_tile_init_state),
		.tb_bram_addr_out(tb_bram_addr_out),
		.tb_bram_data_out(tb_bram_data_out),
		.addr_offset_rd_addr(block_rd_idx),
		.addr_offset_rd_result(tb_bram_start_sub_ref_start[block_rd_idx]),
		.tb_pointer(tb_pointer),
		.tb_valid(tb_valid),
		.first_tile(init_state == 3),
		.tb_done(tb_done)
	);
	wire tb_bram_wr_en_next;
	reg was_stream_ref;
	always @(posedge clk)
		if (rst)
			was_stream_ref <= 0;
		else
			was_stream_ref <= STATE == 32'd4;
	assign tb_bram_wr_en_next = (init_out[0] && (was_stream_ref || (STATE == 32'd4))) && !past_marking;
	always @(posedge clk)
		if (rst)
			tb_bram_wr_en <= 0;
		else
			tb_bram_wr_en <= tb_bram_wr_en_next;
	wire [TB_ADDR_WIDTH - 1:0] tb_bram_wr_addr_next;
	assign tb_bram_wr_addr_next = (tb_bram_wr_en_next ? tb_bram_addr + 1 : tb_bram_addr);
	always @(posedge clk)
		if (rst)
			tb_bram_addr <= -1;
		else
			tb_bram_addr <= tb_bram_wr_addr_next;
	generate
		for (_gv_i_1 = 1; _gv_i_1 < NUM_PE; _gv_i_1 = _gv_i_1 + 1) begin : systolic_array_connections
			localparam i = _gv_i_1;
			assign init_in[i] = (STATE == 32'd5 ? 0 : init_out[i - 1]);
			assign ref_in[i] = ref_out[i - 1];
			wire [REF_LEN_WIDTH:1] sv2v_tmp_95B5E;
			assign sv2v_tmp_95B5E = ref_idx_out[i - 1];
			always @(*) ref_idx_in[i] = sv2v_tmp_95B5E;
			wire [QUERY_LEN_WIDTH:1] sv2v_tmp_B8C82;
			assign sv2v_tmp_B8C82 = query_idx_out[i - 1];
			always @(*) query_idx_in[i] = sv2v_tmp_B8C82;
			wire [PE_WIDTH:1] sv2v_tmp_2872C;
			assign sv2v_tmp_2872C = H_PE[((NUM_PE - 1) - (i - 1)) * PE_WIDTH+:PE_WIDTH];
			always @(*) H_PE_prev[i] = sv2v_tmp_2872C;
			wire [PE_WIDTH:1] sv2v_tmp_D245F;
			assign sv2v_tmp_D245F = I_PE[i - 1];
			always @(*) I_PE_prev[i] = sv2v_tmp_D245F;
			wire [((REF_LEN_WIDTH + 1) >= 0 ? REF_LEN_WIDTH + 2 : 1 - (REF_LEN_WIDTH + 1)):1] sv2v_tmp_9D855;
			assign sv2v_tmp_9D855 = CH_PE[((REF_LEN_WIDTH + 1) >= 0 ? 0 : REF_LEN_WIDTH + 1) + (((NUM_PE - 1) - (i - 1)) * ((REF_LEN_WIDTH + 1) >= 0 ? REF_LEN_WIDTH + 2 : 1 - (REF_LEN_WIDTH + 1)))+:((REF_LEN_WIDTH + 1) >= 0 ? REF_LEN_WIDTH + 2 : 1 - (REF_LEN_WIDTH + 1))];
			always @(*) CH_PE_prev[i] = sv2v_tmp_9D855;
			wire [((REF_LEN_WIDTH + 1) >= 0 ? REF_LEN_WIDTH + 2 : 1 - (REF_LEN_WIDTH + 1)):1] sv2v_tmp_81C89;
			assign sv2v_tmp_81C89 = CI_PE[((REF_LEN_WIDTH + 1) >= 0 ? 0 : REF_LEN_WIDTH + 1) + (((NUM_PE - 1) - (i - 1)) * ((REF_LEN_WIDTH + 1) >= 0 ? REF_LEN_WIDTH + 2 : 1 - (REF_LEN_WIDTH + 1)))+:((REF_LEN_WIDTH + 1) >= 0 ? REF_LEN_WIDTH + 2 : 1 - (REF_LEN_WIDTH + 1))];
			always @(*) CI_PE_prev[i] = sv2v_tmp_81C89;
		end
	endgenerate
	always @(posedge clk) I_PE_prev[0] <= (block ? I_prev_block : -INF);
	assign D_init_in = -INF;
	assign init_in[0] = STATE == 32'd4;
	wire [PE_WIDTH - 1:0] boundary_init_H_score_next;
	assign boundary_init_H_score_next = H_init + gap_extend_in;
	always @(posedge clk)
		if (STATE == 32'd3)
			H_init <= (block || (init_state != 3) ? -INF : gap_open_in);
		else if (STATE == 32'd4)
			H_init <= (block || (init_state != 3) ? -INF : boundary_init_H_score_next);
	always @(posedge clk)
		if (STATE == 32'd3)
			H_PE_prev[0] <= (block ? H_prev_block : (init_state != 3 ? -INF : gap_open_in));
		else if (STATE == 32'd4)
			H_PE_prev[0] <= (block ? H_prev_block : (init_state != 3 ? -INF : boundary_init_H_score_next));
	always @(posedge clk)
		if ((STATE == 32'd4) || (STATE == 32'd3))
			CH_PE_prev[0] <= (block ? CH_PE_prev_block : CONV_DONT_CARE);
	always @(posedge clk)
		if ((STATE == 32'd4) || (STATE == 32'd3))
			CI_PE_prev[0] <= (block ? CI_PE_prev_block : CONV_DONT_CARE);
	always @(*) begin
		cur_ad_max_score = rd_value;
		if (block && not_last_droped_in_prev_block) begin
			if (ad_max_score_prev_block > cur_ad_max_score)
				cur_ad_max_score = ad_max_score_prev_block;
		end
	end
	assign ad_max_score_next = (cur_ad_max_score > ad_max_score ? cur_ad_max_score : ad_max_score);
	always @(posedge clk)
		if (rst || (STATE == 32'd5))
			ad_max_score <= 0;
		else if (init_out[0])
			ad_max_score <= ad_max_score_next;
	always @(posedge clk)
		if (score_bram_rd_en)
			score_bram_addr_rd <= score_bram_addr_rd + 1;
		else
			score_bram_addr_rd <= 0;
	assign ref_in[0] = (ref_oflow ? NU_DONT_CARE : ref_nt);
	always @(posedge clk) begin : state_description
		if (rst) begin
			block <= 0;
			init_n <= 0;
			set_param <= 0;
			curr_query_length <= 0;
			curr_ref_length <= 0;
			start_idx <= 0;
			lower_bound_check <= 0;
			lower_bound_value <= 0;
			block_count <= 0;
			ref_bram_addr <= 0;
			query_bram_addr <= 0;
			rstb <= 0;
			regceb <= 0;
			score_bram_wr_en <= 0;
			tb_bram_data_in <= 0;
			global_max_score <= 0;
			global_max_ad_idx <= 0;
			query_idx_in[0] <= 0;
			ref_idx_in[0] <= 0;
			tb_start <= 0;
		end
		else begin
			regceb <= 1;
			init_n <= init_out[NUM_PE - 2] & init_out[0];
			tb_bram_data_in <= dir_out;
			case (STATE)
				32'd0:
					;
				32'd1: begin
					sub_N_in <= in_param[(3 * PE_WIDTH) - 1-:PE_WIDTH];
					gap_open_in <= in_param[(2 * PE_WIDTH) - 1-:PE_WIDTH];
					gap_extend_in <= in_param[PE_WIDTH - 1:0];
					ref_bram_addr <= 0;
					query_bram_addr <= 0;
					block_count <= block_count + 1;
				end
				32'd2: begin
					if (!set_param)
						set_param <= 1;
					else
						set_param <= set_param << 1;
					query_bram_addr <= query_bram_addr + 1;
					curr_query_length <= curr_query_length + 1;
				end
				32'd3: begin
					set_param <= 0;
					lower_bound_check <= 0;
					curr_ref_length <= curr_ref_length + 1;
					ref_bram_addr <= ref_bram_addr + 1;
					ref_idx_in[0] <= ref_idx_in[0] + 1;
				end
				32'd4: begin
					curr_ref_length <= curr_ref_length + 1;
					ref_bram_addr <= ref_bram_addr + 1;
					ref_idx_in[0] <= ref_idx_in[0] + 1;
					if ((!lower_bound_check && init_n) && last_PE_not_droped) begin
						lower_bound_check <= 1;
						lower_bound_value <= curr_ref_idx;
					end
					if (init_n)
						;
					if ($signed(global_max_score) <= $signed(rd_value)) begin
						global_max_score <= rd_value;
						global_max_ref_idx <= cur_max_ref_idx - 1;
						global_max_query_idx <= cur_max_query_idx - 1;
						global_max_ad_idx <= curr_ad_idx;
						global_max_conv_idx <= max_CH_val;
					end
					if (init_n) begin
						if ((!score_bram_wr_en && !lower_bound_check) && last_PE_not_droped)
							score_bram_wr_en <= 1;
					end
				end
				32'd5: begin
					block <= 1;
					start_idx <= lower_bound_value;
					ref_bram_addr <= lower_bound_value;
					ref_idx_in[0] <= lower_bound_value;
					curr_ref_length <= lower_bound_value;
					query_idx_in[0] <= curr_query_length;
					block_count <= block_count + 1;
					score_bram_wr_en <= 0;
				end
				32'd7:
					;
				32'd6:
					;
				32'd8:
					;
				32'd9: tb_start <= 1;
				32'd10:
					;
			endcase
		end
	end
	wire load_new_seq;
	assign load_new_seq = (STATE == 32'd3) && block_count;
	assign stop = tb_done;
	always @(posedge clk) begin : state_machine
		if (rst)
			STATE <= 32'd0;
		else
			case (STATE)
				32'd0:
					if (start)
						STATE <= 32'd1;
				32'd1: STATE <= 32'd2;
				32'd2:
					if (set_param[NUM_PE - 2])
						STATE <= 32'd3;
				32'd3: STATE <= 32'd4;
				32'd4:
					if (C4)
						STATE <= 32'd8;
					else if ((ref_oflow && (ref_in[NUM_PE - 1] == NU_DONT_CARE)) || C3)
						STATE <= (lower_bound_check && !query_oflow ? 32'd5 : 32'd8);
					else
						STATE <= 32'd4;
				32'd5: STATE <= 32'd2;
				32'd7: STATE <= 32'd10;
				32'd6:
					;
				32'd8: STATE <= 32'd11;
				32'd11: STATE <= 32'd9;
				32'd9:
					if (tb_done == 1)
						STATE <= 32'd10;
				32'd10:
					;
			endcase
	end
	assign commit = STATE == 32'd2;
	assign traceback = ((STATE == 32'd9) || (STATE == 32'd0)) || (STATE == 32'd10);
endmodule
module sft_reg (
	clk,
	en,
	in,
	out
);
	parameter BW = 10;
	parameter DEPTH = 10;
	input clk;
	input en;
	input [BW - 1:0] in;
	output wire [BW - 1:0] out;
	reg [BW - 1:0] content [DEPTH - 1:0];
	reg signed [31:0] idx;
	always @(posedge clk)
		if (en) begin
			content[0] <= in;
			for (idx = 1; idx < DEPTH; idx = idx + 1)
				content[idx] <= content[idx - 1];
		end
	assign out = content[DEPTH - 1];
endmodule
module sft_w_rst (
	clk,
	en,
	rst,
	in,
	out
);
	parameter DEPTH = 10;
	input clk;
	input en;
	input rst;
	input in;
	output wire out;
	reg [DEPTH - 1:0] data;
	always @(posedge clk)
		if (rst)
			data <= 0;
		else if (en) begin
			if (DEPTH > 1)
				data <= {data[DEPTH - 2:0], in};
			else
				data <= in;
		end
	assign out = data[DEPTH - 1];
endmodule
module PE (
	clk,
	rst,
	init_in,
	set_param,
	param_valid_in,
	ref_in,
	sub_A_in,
	sub_C_in,
	sub_G_in,
	sub_T_in,
	sub_N_in,
	gap_open_in,
	gap_extend_in,
	INF,
	block,
	init_state,
	diag_score,
	start_idx,
	marker,
	ref_idx_in,
	query_idx_in,
	D_init_in,
	H_init_in,
	H_PE_prev,
	I_PE_prev,
	CH_PE_prev,
	CI_PE_prev,
	diag_CH_score,
	init_out,
	dir_out,
	ref_out,
	ref_idx_out,
	query_idx_out,
	H_PE,
	I_PE,
	D_PE,
	CH_PE,
	CI_PE,
	CD_PE
);
	parameter PE_WIDTH = 16;
	parameter DATA_WIDTH = 16;
	parameter NUM_BLOCK = 4;
	parameter NUM_PE = 4;
	parameter LOG_NUM_PE = $clog2(NUM_PE);
	parameter REF_LEN_WIDTH = 10;
	parameter QUERY_LEN_WIDTH = 10;
	parameter PE_IDX = 0;
	parameter LOG_MAX_TILE_SIZE = 10;
	input wire clk;
	input wire rst;
	input wire init_in;
	input wire set_param;
	input param_valid_in;
	input wire [2:0] ref_in;
	input wire [PE_WIDTH - 1:0] sub_A_in;
	input wire [PE_WIDTH - 1:0] sub_C_in;
	input wire [PE_WIDTH - 1:0] sub_G_in;
	input wire [PE_WIDTH - 1:0] sub_T_in;
	input wire [PE_WIDTH - 1:0] sub_N_in;
	input wire [PE_WIDTH - 1:0] gap_open_in;
	input wire [PE_WIDTH - 1:0] gap_extend_in;
	input wire signed [PE_WIDTH - 1:0] INF;
	input wire block;
	input [1:0] init_state;
	input wire signed [PE_WIDTH - 1:0] diag_score;
	input wire [REF_LEN_WIDTH - 1:0] start_idx;
	input wire [LOG_MAX_TILE_SIZE:0] marker;
	input wire [REF_LEN_WIDTH - 1:0] ref_idx_in;
	input wire [QUERY_LEN_WIDTH - 1:0] query_idx_in;
	input wire [PE_WIDTH - 1:0] D_init_in;
	input wire [PE_WIDTH - 1:0] H_init_in;
	input wire signed [PE_WIDTH - 1:0] H_PE_prev;
	input wire signed [PE_WIDTH - 1:0] I_PE_prev;
	input wire [REF_LEN_WIDTH + 1:0] CH_PE_prev;
	input wire [REF_LEN_WIDTH + 1:0] CI_PE_prev;
	input wire [REF_LEN_WIDTH + 1:0] diag_CH_score;
	output reg init_out;
	output reg [3:0] dir_out;
	output reg [2:0] ref_out;
	output reg [REF_LEN_WIDTH - 1:0] ref_idx_out;
	output reg [QUERY_LEN_WIDTH - 1:0] query_idx_out;
	output reg signed [PE_WIDTH - 1:0] H_PE;
	output reg signed [PE_WIDTH - 1:0] I_PE;
	output reg signed [PE_WIDTH - 1:0] D_PE;
	output reg [REF_LEN_WIDTH + 1:0] CH_PE;
	output reg [REF_LEN_WIDTH + 1:0] CI_PE;
	output reg [REF_LEN_WIDTH + 1:0] CD_PE;
	localparam VER = 2;
	localparam HOR = 1;
	localparam DIAG = 0;
	localparam CONV_DONT_CARE = 0;
	localparam NU_DONT_CARE = 5;
	reg signed [PE_WIDTH - 1:0] sub_A;
	reg signed [PE_WIDTH - 1:0] sub_C;
	reg signed [PE_WIDTH - 1:0] sub_G;
	reg signed [PE_WIDTH - 1:0] sub_T;
	reg signed [PE_WIDTH - 1:0] sub_N;
	reg signed [PE_WIDTH - 1:0] gap_open;
	reg signed [PE_WIDTH - 1:0] gap_extend;
	reg signed [PE_WIDTH - 1:0] match_reward;
	reg param_valid;
	reg [REF_LEN_WIDTH - 1:0] ref_idx;
	wire [QUERY_LEN_WIDTH - 1:0] query_idx;
	always @(*) begin : match_reward_calculation
		case ({ref_in})
			3'b111: match_reward = sub_N;
			3'b001: match_reward = sub_A;
			3'b010: match_reward = sub_C;
			3'b011: match_reward = sub_G;
			3'b100: match_reward = sub_T;
			default: match_reward = 0;
		endcase
	end
	reg signed [PE_WIDTH - 1:0] HV_score;
	reg signed [PE_WIDTH - 1:0] IV_score;
	reg signed [PE_WIDTH - 1:0] I_score;
	reg signed [PE_WIDTH - 1:0] HH_score;
	reg signed [PE_WIDTH - 1:0] DH_score;
	reg signed [PE_WIDTH - 1:0] D_prev;
	reg signed [PE_WIDTH - 1:0] H_prev;
	reg signed [PE_WIDTH - 1:0] D_score;
	reg signed [PE_WIDTH - 1:0] HD_score;
	reg signed [PE_WIDTH - 1:0] H_score;
	reg signed [PE_WIDTH - 1:0] H_PE_prev_reg;
	reg signed [PE_WIDTH - 1:0] H_PE_prev2_reg;
	reg signed [PE_WIDTH - 1:0] H_prev_reg;
	reg signed [PE_WIDTH - 1:0] I_PE_prev_reg;
	reg signed [PE_WIDTH - 1:0] D_prev_reg;
	reg signed [PE_WIDTH - 1:0] H_PE_prev2;
	reg [REF_LEN_WIDTH + 1:0] CH_score;
	reg [REF_LEN_WIDTH + 1:0] CI_score;
	reg [REF_LEN_WIDTH + 1:0] CD_score;
	reg [REF_LEN_WIDTH + 1:0] CH_score_reg;
	reg [REF_LEN_WIDTH + 1:0] CH_score_reg2;
	reg [REF_LEN_WIDTH + 1:0] CD_score_reg;
	reg [3:0] dir;
	wire [1:0] H_flag;
	reg D_flag;
	reg I_flag;
	always @(*) begin : boundary_conditions
		if (!query_idx && !ref_idx)
			H_PE_prev2_reg = 0;
		else
			H_PE_prev2_reg = H_PE_prev2;
		H_PE_prev_reg = H_PE_prev;
		I_PE_prev_reg = I_PE_prev;
		if (!init_out && init_in) begin
			H_prev_reg = H_init_in;
			D_prev_reg = D_init_in;
		end
		else begin
			H_prev_reg = H_prev;
			D_prev_reg = D_prev;
		end
	end
	always @(*) begin : score_calculation
		HV_score = H_PE_prev_reg + gap_open;
		IV_score = I_PE_prev_reg + gap_extend;
		if ($signed(HV_score) >= $signed(IV_score)) begin
			I_score = HV_score;
			I_flag = 0;
		end
		else begin
			I_score = IV_score;
			I_flag = 1;
		end
		HH_score = H_prev_reg + gap_open;
		DH_score = D_prev_reg + gap_extend;
		if ($signed(HH_score) >= $signed(DH_score)) begin
			D_score = HH_score;
			D_flag = 0;
		end
		else begin
			D_score = DH_score;
			D_flag = 1;
		end
		HD_score = H_PE_prev2_reg + match_reward;
		H_score = HD_score;
		dir[1:0] = DIAG;
		if (D_score > H_score) begin
			H_score = D_score;
			dir[1:0] = HOR;
		end
		if (I_score > H_score) begin
			H_score = I_score;
			dir[1:0] = VER;
		end
		if (I_flag)
			dir[3] = 1;
		else
			dir[3] = 0;
		if (D_flag)
			dir[2] = 1;
		else
			dir[2] = 0;
		if ((((PE_IDX == 0) && !block) && (init_state != 3)) && !init_out) begin
			H_score = (init_state == 0 ? 0 : -INF);
			I_score = (init_state == 2 ? 0 : -INF);
			D_score = (init_state == 1 ? 0 : -INF);
		end
		if (ref_in == NU_DONT_CARE)
			H_score = -INF;
	end
	always @(*) begin : convergence_logic
		if ((ref_idx + query_idx) == (marker - 1)) begin
			CH_score = {ref_idx, 2'b11};
			CI_score = {ref_idx, 2'b11};
			CD_score = {ref_idx, 2'b11};
		end
		else if ((ref_idx + query_idx) == marker) begin
			CH_score = {ref_idx, 2'b00};
			CI_score = {ref_idx, 2'b01};
			CD_score = {ref_idx, 2'b10};
		end
		else begin
			if (I_flag)
				CI_score = CI_PE_prev;
			else
				CI_score = CH_PE_prev;
			if (D_flag)
				CD_score = CD_score_reg;
			else
				CD_score = CH_score_reg;
			casex (dir)
				4'bzz00: CH_score = CH_score_reg2;
				4'bz001: CH_score = CH_score_reg;
				4'bz101: CH_score = CD_score_reg;
				4'b0z10: CH_score = CH_PE_prev;
				4'b1z10: CH_score = CI_PE_prev;
				default: CH_score = CH_score_reg2;
			endcase
		end
		if (ref_in == NU_DONT_CARE) begin
			CH_score = CONV_DONT_CARE;
			CD_score = CONV_DONT_CARE;
			CI_score = CONV_DONT_CARE;
		end
	end
	assign query_idx = query_idx_in;
	always @(posedge clk)
		if (rst)
			ref_out <= 0;
		else
			ref_out <= ref_in;
	always @(posedge clk)
		if (rst) begin
			sub_A <= 0;
			sub_C <= 0;
			sub_G <= 0;
			sub_T <= 0;
			sub_N <= 0;
			gap_open <= 0;
			gap_extend <= 0;
			H_prev <= 0;
			D_prev <= 0;
			H_PE_prev2 <= 0;
			CH_score_reg <= 0;
			CD_score_reg <= 0;
			CH_score_reg2 <= 0;
			ref_idx <= 0;
			init_out <= 0;
			ref_idx_out <= 0;
			query_idx_out <= 0;
			I_PE <= -INF;
			H_PE <= -INF;
			D_PE <= -INF;
			CH_PE <= 0;
			CI_PE <= 0;
			CD_PE <= 0;
			dir_out <= 0;
		end
		else if (set_param) begin
			sub_A <= sub_A_in;
			sub_C <= sub_C_in;
			sub_G <= sub_G_in;
			sub_T <= sub_T_in;
			sub_N <= sub_N_in;
			gap_open <= gap_open_in;
			gap_extend <= gap_extend_in;
			H_PE <= -INF;
			param_valid <= param_valid_in;
		end
		else if (param_valid) begin
			init_out <= init_in;
			dir_out <= dir;
			ref_idx <= ref_idx_in;
			ref_idx_out <= ref_idx_in;
			if (init_in) begin
				H_prev <= H_score;
				D_prev <= D_score;
				H_PE_prev2 <= H_PE_prev;
				CH_score_reg <= CH_score;
				CD_score_reg <= CD_score;
				CH_score_reg2 <= CH_PE_prev;
				query_idx_out <= query_idx_in + 1;
				I_PE <= I_score;
				H_PE <= H_score;
				D_PE <= D_score;
				CH_PE <= CH_score;
				CI_PE <= CI_score;
				CD_PE <= CD_score;
			end
			else begin
				H_PE_prev2 <= (block ? (PE_IDX ? -INF : diag_score) : H_init_in);
				CH_score_reg2 <= (block ? (PE_IDX ? CONV_DONT_CARE : diag_CH_score) : CONV_DONT_CARE);
				H_prev <= -INF;
				D_prev <= -INF;
				CH_score_reg <= CONV_DONT_CARE;
				CD_score_reg <= CONV_DONT_CARE;
				CH_PE <= CONV_DONT_CARE;
				CI_PE <= CONV_DONT_CARE;
				CD_PE <= CONV_DONT_CARE;
			end
		end
endmodule
module reduction_tree_max (
	to_sel,
	array,
	reduction_value,
	idx,
	selected
);
	parameter PE_WIDTH = 16;
	parameter SEL_WIDTH = 16;
	parameter NUM_PE = 4;
	parameter LOG_NUM_PE = 2;
	input wire [(NUM_PE * SEL_WIDTH) - 1:0] to_sel;
	input wire signed [(NUM_PE * PE_WIDTH) - 1:0] array;
	output wire signed [PE_WIDTH - 1:0] reduction_value;
	output wire [LOG_NUM_PE - 1:0] idx;
	output wire [SEL_WIDTH - 1:0] selected;
	wire local_stop;
	genvar _gv_i_2;
	genvar _gv_j_1;
	generate
		for (_gv_j_1 = 0; _gv_j_1 < LOG_NUM_PE; _gv_j_1 = _gv_j_1 + 1) begin : rt_level
			localparam j = _gv_j_1;
			for (_gv_i_2 = 0; _gv_i_2 < (2 ** ((LOG_NUM_PE - j) - 1)); _gv_i_2 = _gv_i_2 + 1) begin : rt_iter
				localparam i = _gv_i_2;
				wire signed [PE_WIDTH - 1:0] value1;
				wire signed [PE_WIDTH - 1:0] value2;
				wire signed [SEL_WIDTH - 1:0] sel_value1;
				wire signed [SEL_WIDTH - 1:0] sel_value2;
				wire signed [SEL_WIDTH - 1:0] selected_val;
				wire signed [PE_WIDTH - 1:0] out;
				wire [LOG_NUM_PE - 1:0] idx1;
				wire [LOG_NUM_PE - 1:0] idx2;
				wire [LOG_NUM_PE - 1:0] max_idx;
				if (j == 0) begin : genblk1
					assign value1 = array[((NUM_PE - 1) - (i * 2)) * PE_WIDTH+:PE_WIDTH];
					assign value2 = array[((NUM_PE - 1) - ((i * 2) + 1)) * PE_WIDTH+:PE_WIDTH];
					assign sel_value1 = to_sel[((NUM_PE - 1) - (i * 2)) * SEL_WIDTH+:SEL_WIDTH];
					assign sel_value2 = to_sel[((NUM_PE - 1) - ((i * 2) + 1)) * SEL_WIDTH+:SEL_WIDTH];
					assign idx1 = i * 2;
					assign idx2 = (i * 2) + 1;
				end
				else begin : genblk1
					assign value1 = rt_level[j - 1].rt_iter[i * 2].out;
					assign value2 = rt_level[j - 1].rt_iter[(i * 2) + 1].out;
					assign sel_value1 = rt_level[j - 1].rt_iter[i * 2].selected_val;
					assign sel_value2 = rt_level[j - 1].rt_iter[(i * 2) + 1].selected_val;
					assign idx1 = rt_level[j - 1].rt_iter[i * 2].max_idx;
					assign idx2 = rt_level[j - 1].rt_iter[(i * 2) + 1].max_idx;
				end
				assign selected_val = ($signed(value1) > $signed(value2) ? sel_value1 : sel_value2);
				assign out = ($signed(value1) > $signed(value2) ? value1 : value2);
				assign max_idx = ($signed(value1) > $signed(value2) ? idx1 : idx2);
			end
		end
	endgenerate
	assign reduction_value = rt_level[LOG_NUM_PE - 1].rt_iter[0].out;
	assign idx = rt_level[LOG_NUM_PE - 1].rt_iter[0].max_idx;
	assign selected = rt_level[LOG_NUM_PE - 1].rt_iter[0].selected_val;
endmodule
module reduction_tree_value (
	array,
	reduction_value,
	reduction_bool
);
	parameter PE_WIDTH = 16;
	parameter NUM_PE = 4;
	parameter LOG_NUM_PE = 2;
	input wire [(NUM_PE * PE_WIDTH) - 1:0] array;
	output wire [PE_WIDTH - 1:0] reduction_value;
	output wire reduction_bool;
	wire local_stop;
	parameter CONV_DONT_CARE = 0;
	genvar _gv_i_3;
	genvar _gv_j_2;
	generate
		for (_gv_j_2 = 0; _gv_j_2 < LOG_NUM_PE; _gv_j_2 = _gv_j_2 + 1) begin : rt_level
			localparam j = _gv_j_2;
			for (_gv_i_3 = 0; _gv_i_3 < (2 ** ((LOG_NUM_PE - j) - 1)); _gv_i_3 = _gv_i_3 + 1) begin : rt_iter
				localparam i = _gv_i_3;
				wire [PE_WIDTH - 1:0] value0;
				wire [PE_WIDTH - 1:0] value1;
				wire [PE_WIDTH - 1:0] value2;
				wire bool0;
				wire bool1;
				wire bool2;
				if (j == 0) begin : genblk1
					assign value1 = array[((NUM_PE - 1) - (i * 2)) * PE_WIDTH+:PE_WIDTH];
					assign value2 = array[((NUM_PE - 1) - ((i * 2) + 1)) * PE_WIDTH+:PE_WIDTH];
					assign bool1 = 1'b1;
					assign bool2 = 1'b1;
				end
				else begin : genblk1
					assign value1 = rt_level[j - 1].rt_iter[i * 2].value0;
					assign value2 = rt_level[j - 1].rt_iter[(i * 2) + 1].value0;
					assign bool1 = rt_level[j - 1].rt_iter[i * 2].bool0;
					assign bool2 = rt_level[j - 1].rt_iter[(i * 2) + 1].bool0;
				end
				wire dontcare1 = value1 == CONV_DONT_CARE;
				wire dontcare2 = value2 == CONV_DONT_CARE;
				assign value0 = (dontcare1 ? value2 : value1);
				assign bool0 = (((dontcare1 || dontcare2) || (value1 == value2)) && bool1) && bool2;
			end
		end
	endgenerate
	assign reduction_bool = rt_level[LOG_NUM_PE - 1].rt_iter[0].bool0;
	assign reduction_value = rt_level[LOG_NUM_PE - 1].rt_iter[0].value0;
endmodule
module gcd (
	clk,
	rst,
	start,
	in_param,
	total_ref_length,
	total_query_length,
	ref_wr_en,
	complement_ref_in,
	ref_bram_data_in,
	ref_addr_in,
	query_wr_en,
	complement_query_in,
	query_bram_data_in,
	query_addr_in,
	last_tile,
	init_state,
	INF,
	marker,
	query_start_offset,
	ref_start_offset,
	query_next_tile_addr,
	query_rd_ptr,
	ref_next_tile_addr,
	ref_rd_ptr,
	next_tile_init_state,
	tb_pointer,
	tb_valid,
	commit,
	traceback,
	stop
);
	parameter PE_WIDTH = 16;
	parameter DATA_WIDTH = 8;
	parameter NUM_BLOCK = 1;
	parameter BLOCK_WIDTH = DATA_WIDTH / NUM_BLOCK;
	parameter NUM_PE = 16;
	parameter LOG_NUM_PE = $clog2(NUM_PE);
	parameter MAX_TILE_SIZE = 512;
	parameter LOG_MAX_TILE_SIZE = $clog2(MAX_TILE_SIZE);
	parameter REF_LEN_WIDTH = 16;
	parameter QUERY_LEN_WIDTH = 16;
	parameter PARAM_ADDR_WIDTH = 8;
	parameter CONV_SCORE_WIDTH = (2 + (2 * (REF_LEN_WIDTH + 2))) + (3 * PE_WIDTH);
	parameter TB_DATA_WIDTH = 4 * NUM_PE;
	parameter TB_ADDR_WIDTH = $clog2((2 * (MAX_TILE_SIZE / NUM_PE)) * MAX_TILE_SIZE);
	input clk;
	input rst;
	input start;
	input [(14 * PE_WIDTH) - 1:0] in_param;
	input [REF_LEN_WIDTH - 1:0] total_ref_length;
	input [QUERY_LEN_WIDTH - 1:0] total_query_length;
	input ref_wr_en;
	input complement_ref_in;
	input [31:0] ref_bram_data_in;
	input [(LOG_MAX_TILE_SIZE / NUM_BLOCK) - 3:0] ref_addr_in;
	input query_wr_en;
	input complement_query_in;
	input [31:0] query_bram_data_in;
	input [(LOG_MAX_TILE_SIZE / NUM_BLOCK) - 3:0] query_addr_in;
	output wire last_tile;
	input [1:0] init_state;
	input [PE_WIDTH - 1:0] INF;
	input [LOG_MAX_TILE_SIZE:0] marker;
	input [1:0] query_start_offset;
	input [1:0] ref_start_offset;
	output wire [QUERY_LEN_WIDTH - 1:0] query_next_tile_addr;
	output wire [QUERY_LEN_WIDTH - 1:0] query_rd_ptr;
	output wire [REF_LEN_WIDTH - 1:0] ref_next_tile_addr;
	output wire [REF_LEN_WIDTH - 1:0] ref_rd_ptr;
	output wire [1:0] next_tile_init_state;
	output wire [1:0] tb_pointer;
	output wire tb_valid;
	output wire commit;
	output wire traceback;
	output wire stop;
	wire [DATA_WIDTH - 1:0] ref_bram_data_out;
	wire [LOG_MAX_TILE_SIZE / NUM_BLOCK:0] ref_bram_addr;
	wire [LOG_MAX_TILE_SIZE / NUM_BLOCK:0] ref_actual_rd_addr;
	assign ref_actual_rd_addr = ref_bram_addr + ref_start_offset;
	assign ref_rd_ptr = ref_actual_rd_addr[LOG_MAX_TILE_SIZE:2];
	asym_ram_sdp_write_wider #(
		.SIZEA(1 << ((LOG_MAX_TILE_SIZE / NUM_BLOCK) - 2)),
		.WIDTHA(4 * DATA_WIDTH),
		.WIDTHB(DATA_WIDTH)
	) ref_bram(
		.addrA(ref_addr_in),
		.addrB(ref_actual_rd_addr),
		.diA(ref_bram_data_in),
		.clk(clk),
		.weA(ref_wr_en),
		.enaA(1),
		.enaB(1),
		.doB(ref_bram_data_out)
	);
	wire [DATA_WIDTH - 1:0] query_bram_data_out;
	wire [LOG_MAX_TILE_SIZE / NUM_BLOCK:0] query_bram_addr;
	wire [LOG_MAX_TILE_SIZE / NUM_BLOCK:0] query_actual_rd_addr;
	assign query_actual_rd_addr = query_bram_addr + query_start_offset;
	assign query_rd_ptr = query_actual_rd_addr[LOG_MAX_TILE_SIZE:2];
	asym_ram_sdp_write_wider #(
		.SIZEA(1 << ((LOG_MAX_TILE_SIZE / NUM_BLOCK) - 2)),
		.WIDTHA(4 * DATA_WIDTH),
		.WIDTHB(DATA_WIDTH)
	) query_bram(
		.addrA(query_addr_in),
		.addrB(query_actual_rd_addr),
		.diA(query_bram_data_in),
		.clk(clk),
		.weA(query_wr_en),
		.enaA(1),
		.enaB(1),
		.doB(query_bram_data_out)
	);
	wire rstb;
	wire regceb;
	wire score_bram_wr_en;
	wire score_bram_rd_en;
	wire [LOG_MAX_TILE_SIZE - 1:0] score_bram_addr_wr;
	wire [LOG_MAX_TILE_SIZE - 1:0] score_bram_addr_rd;
	wire [CONV_SCORE_WIDTH - 1:0] score_bram_data_in;
	wire [CONV_SCORE_WIDTH - 1:0] score_bram_data_out;
	DPBram #(
		.RAM_WIDTH(CONV_SCORE_WIDTH),
		.RAM_DEPTH(MAX_TILE_SIZE),
		.RAM_PERFORMANCE(0)
	) DPRam_instance(
		.clka(clk),
		.rstb(rstb),
		.regceb(regceb),
		.wea(score_bram_wr_en),
		.addra(score_bram_addr_wr),
		.dina(score_bram_data_in),
		.enb(score_bram_rd_en),
		.addrb(score_bram_addr_rd),
		.doutb(score_bram_data_out)
	);
	wire tb_bram_wr_en;
	wire [TB_DATA_WIDTH - 1:0] tb_bram_data_in;
	wire [TB_DATA_WIDTH - 1:0] tb_bram_data_out;
	wire [TB_ADDR_WIDTH - 1:0] tb_bram_addr;
	BRAM_kernel #(
		.ADDR_WIDTH(TB_ADDR_WIDTH),
		.DATA_WIDTH(TB_DATA_WIDTH)
	) tb_bram(
		.clk(clk),
		.addr(tb_bram_addr),
		.write_en(tb_bram_wr_en),
		.data_in(tb_bram_data_in),
		.data_out(tb_bram_data_out)
	);
	PE_Array #(
		.PE_WIDTH(PE_WIDTH),
		.DATA_WIDTH(DATA_WIDTH),
		.NUM_BLOCK(NUM_BLOCK),
		.NUM_PE(NUM_PE),
		.LOG_NUM_PE(LOG_NUM_PE),
		.MAX_TILE_SIZE(MAX_TILE_SIZE),
		.LOG_MAX_TILE_SIZE(LOG_MAX_TILE_SIZE),
		.REF_LEN_WIDTH(REF_LEN_WIDTH),
		.QUERY_LEN_WIDTH(QUERY_LEN_WIDTH),
		.PARAM_ADDR_WIDTH(PARAM_ADDR_WIDTH)
	) pe_array(
		.clk(clk),
		.rst(rst),
		.start(start),
		.in_param(in_param),
		.total_ref_length(total_ref_length),
		.total_query_length(total_query_length),
		.ref_bram_addr(ref_bram_addr),
		.ref_bram_data_out(ref_bram_data_out),
		.complement_ref_in(complement_ref_in),
		.query_bram_addr(query_bram_addr),
		.query_bram_data_out(query_bram_data_out),
		.complement_query_in(complement_query_in),
		.rstb(rstb),
		.regceb(regceb),
		.score_bram_wr_en_ext(score_bram_wr_en),
		.score_bram_rd_en(score_bram_rd_en),
		.score_bram_data_in(score_bram_data_in),
		.score_bram_data_out(score_bram_data_out),
		.score_bram_addr_wr(score_bram_addr_wr),
		.score_bram_addr_rd(score_bram_addr_rd),
		.tb_bram_wr_en(tb_bram_wr_en),
		.tb_bram_data_in(tb_bram_data_in),
		.tb_bram_data_out(tb_bram_data_out),
		.tb_bram_addr_reg(tb_bram_addr),
		.init_state(init_state),
		.query_next_tile_addr(query_next_tile_addr),
		.ref_next_tile_addr(ref_next_tile_addr),
		.INF({2'b00, {PE_WIDTH - 2 {1'b1}}}),
		.last_tile(last_tile),
		.marker(marker),
		.xdrop_value(in_param[13 * PE_WIDTH+:PE_WIDTH]),
		.next_tile_init_state(next_tile_init_state),
		.tb_pointer(tb_pointer),
		.tb_valid(tb_valid),
		.commit(commit),
		.traceback(traceback),
		.stop(stop)
	);
endmodule
module traceback (
	clk,
	rst,
	tb_start,
	start_query_idx,
	start_ref_idx,
	start_tb_state,
	tb_bram_data_out,
	addr_offset_rd_addr,
	addr_offset_rd_result,
	first_tile,
	tb_bram_addr_out,
	tb_pointer,
	tb_valid,
	tb_done
);
	parameter PE_WIDTH = 8;
	parameter DATA_WIDTH = 16;
	parameter NUM_BLOCK = 4;
	parameter NUM_PE = 2;
	parameter LOG_NUM_PE = $clog2(NUM_PE);
	parameter MAX_TILE_SIZE = 16;
	parameter LOG_MAX_TILE_SIZE = $clog2(MAX_TILE_SIZE);
	parameter REF_LEN_WIDTH = 8;
	parameter QUERY_LEN_WIDTH = 8;
	parameter PARAM_ADDR_WIDTH = 8;
	parameter CONV_SCORE_WIDTH = (1 + (2 * (REF_LEN_WIDTH + 2))) + (2 * PE_WIDTH);
	parameter TB_DATA_WIDTH = 4 * NUM_PE;
	parameter TB_ADDR_WIDTH = $clog2((2 * (MAX_TILE_SIZE / NUM_PE)) * MAX_TILE_SIZE);
	input wire clk;
	input wire rst;
	input wire tb_start;
	input wire [REF_LEN_WIDTH - 1:0] start_query_idx;
	input wire [REF_LEN_WIDTH - 1:0] start_ref_idx;
	input wire [1:0] start_tb_state;
	input wire [TB_DATA_WIDTH - 1:0] tb_bram_data_out;
	output wire [LOG_MAX_TILE_SIZE - 1:0] addr_offset_rd_addr;
	input wire [TB_ADDR_WIDTH - 1:0] addr_offset_rd_result;
	input first_tile;
	output reg [TB_ADDR_WIDTH - 1:0] tb_bram_addr_out;
	output wire [1:0] tb_pointer;
	output wire tb_valid;
	output wire tb_done;
	reg [31:0] state;
	reg [LOG_NUM_PE - 1:0] query_pe_idx;
	wire [LOG_NUM_PE - 1:0] query_pe_idx_sub1;
	wire [LOG_NUM_PE - 1:0] query_pe_idx_next;
	wire query_pe_idx_underflow;
	assign {query_pe_idx_underflow, query_pe_idx_sub1} = {1'b0, query_pe_idx} - 1;
	reg [TB_ADDR_WIDTH - 1:0] cur_blk_idx;
	wire [TB_ADDR_WIDTH - 1:0] next_blk_idx;
	assign next_blk_idx = cur_blk_idx - 1;
	reg [REF_LEN_WIDTH - 1:0] next_addr_offset;
	always @(posedge clk) next_addr_offset <= ((state == 32'd0 ? start_query_idx[REF_LEN_WIDTH - 1:LOG_NUM_PE] != 0 : next_blk_idx != 0) ? addr_offset_rd_result : NUM_PE - 1);
	reg [REF_LEN_WIDTH - 1:0] curr_ref_idx;
	wire [REF_LEN_WIDTH - 1:0] next_ref_idx;
	wire [TB_ADDR_WIDTH - 1:0] next_tb_bram_addr_diag;
	wire [TB_ADDR_WIDTH - 1:0] next_tb_bram_addr_horz;
	wire [TB_ADDR_WIDTH - 1:0] next_tb_bram_addr_vert;
	reg [TB_ADDR_WIDTH - 1:0] prev_tb_bram_addr;
	assign next_tb_bram_addr_diag = (query_pe_idx_underflow ? (curr_ref_idx + next_addr_offset) - 1 : prev_tb_bram_addr - 2);
	assign next_tb_bram_addr_vert = (query_pe_idx_underflow ? curr_ref_idx + next_addr_offset : prev_tb_bram_addr - 1);
	assign next_tb_bram_addr_horz = prev_tb_bram_addr - 1;
	reg [1:0] cur_tb_state;
	wire [1:0] this_move;
	always @(*)
		if (state == 32'd1)
			tb_bram_addr_out = ((curr_ref_idx + next_addr_offset) - (NUM_PE - 1)) + query_pe_idx;
		else
			case (this_move)
				0: tb_bram_addr_out = next_tb_bram_addr_diag;
				1: tb_bram_addr_out = next_tb_bram_addr_horz;
				2: tb_bram_addr_out = next_tb_bram_addr_vert;
				3: tb_bram_addr_out = 'hx;
			endcase
	wire delete_extend;
	wire insert_extend;
	wire [1:0] h_move;
	wire [3:0] tb_ptr_read;
	assign tb_ptr_read = tb_bram_data_out[query_pe_idx * 4+:4];
	assign {insert_extend, delete_extend, h_move} = tb_ptr_read;
	assign this_move = (cur_tb_state == 0 ? h_move : cur_tb_state);
	assign tb_pointer = this_move;
	assign tb_valid = state == 32'd2;
	wire tb_start_pulse;
	assign tb_start_pulse = tb_start && (state == 32'd0);
	always @(posedge clk)
		if (rst)
			state <= 32'd0;
		else
			case (state)
				32'd0:
					if (tb_start_pulse)
						state <= 32'd1;
				32'd1: state <= 32'd2;
				32'd2:
					if (tb_done)
						state <= 32'd3;
			endcase
	assign tb_done = (state == 32'd2) && (first_tile ? (curr_ref_idx == 0) || (query_pe_idx_underflow && (cur_blk_idx == 0)) : (next_ref_idx == 0) && ({cur_blk_idx, query_pe_idx_next} == 0));
	assign query_pe_idx_next = ((this_move == 0) || (this_move == 2) ? query_pe_idx_sub1 : query_pe_idx);
	always @(posedge clk)
		if (tb_start_pulse)
			query_pe_idx <= start_query_idx[LOG_NUM_PE - 1:0];
		else if (state == 32'd2)
			query_pe_idx <= query_pe_idx_next;
	wire is_init;
	assign is_init = state == 32'd1;
	always @(posedge clk)
		if (tb_start_pulse)
			cur_blk_idx <= start_query_idx[REF_LEN_WIDTH - 1:LOG_NUM_PE];
		else if (((state == 32'd2) && ((this_move == 0) || (this_move == 2))) && query_pe_idx_underflow)
			cur_blk_idx <= next_blk_idx;
	assign addr_offset_rd_addr = (tb_start_pulse ? start_query_idx[REF_LEN_WIDTH - 1:LOG_NUM_PE] : next_blk_idx) - 1;
	assign next_ref_idx = ((this_move == 0) || (this_move == 1) ? curr_ref_idx - 1 : curr_ref_idx);
	always @(posedge clk)
		if (tb_start_pulse)
			curr_ref_idx <= start_ref_idx;
		else if (state == 32'd2)
			curr_ref_idx <= next_ref_idx;
	always @(posedge clk) prev_tb_bram_addr <= tb_bram_addr_out;
	always @(posedge clk)
		if (tb_start_pulse)
			cur_tb_state <= start_tb_state;
		else if (state == 32'd2)
			case (this_move)
				0: cur_tb_state <= 0;
				1: cur_tb_state <= delete_extend;
				2: cur_tb_state <= (insert_extend ? 2 : 0);
				default: cur_tb_state <= 2'hx;
			endcase
endmodule
