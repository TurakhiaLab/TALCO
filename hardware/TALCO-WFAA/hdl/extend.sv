module extend_array #(
	parameter NUM_EXTEND = 8,
	parameter LOG_NUM_EXTEND = $clog2(NUM_EXTEND),
    parameter EXTEND_LEN = 8,
    parameter LOG_EXTEND_LEN = $clog2(EXTEND_LEN),
	parameter TILE_SIZE = 512,
	parameter LOG_TILE_SIZE = $clog2(TILE_SIZE),
	parameter DATA_WIDTH = 16,
	parameter BLOCK_WIDTH = 8,
    parameter LOG_BLOCK_WIDTH = $clog2(BLOCK_WIDTH),
    parameter TB_ADDR = 10,
	parameter FIFO_WIDTH = 2*LOG_TILE_SIZE + TB_ADDR + 1 + 1 // {is_valid, k, offset, tbAddr}
)(
	input	logic	clk,
	input	logic	rst,
	dbram_wr_ifc.slave	rwr_ifc,
	dbram_wr_ifc.slave	qwr_ifc,
	fifo_rd_wr_ifc.slave fifo_ifc,
	// input 	logic	on,
	// input	logic	[4*EXTEND_LEN - 1: 0]	rin,	// 8 ref char
	// input	logic	[4*EXTEND_LEN - 1: 0]	qin,	// 8 query char
	output	logic	[NUM_EXTEND - 1: 0]	is_finish,
	input	logic	load
);
	
	// broadcast input ref and query data to NUM_EXTEND BRAMs
	dbram_wr_ifc #(.DATA_WIDTH(4*BLOCK_WIDTH), .ADDR_WIDTH(LOG_TILE_SIZE - LOG_BLOCK_WIDTH)) rwr_bcast[NUM_EXTEND] (), qwr_bcast[NUM_EXTEND]();
	broadcast #(.NUM_EXTEND(NUM_EXTEND)) bcast_ref_inst (
		.in(rwr_ifc),
		.out(rwr_bcast)
	);

	broadcast #(.NUM_EXTEND(NUM_EXTEND)) bcast_query_inst (
		.in(qwr_ifc),
		.out(qwr_bcast)
	);

	//fifo
	logic	[NUM_EXTEND*FIFO_WIDTH - 1: 0]	fifo_dout; // {is_valid, k, offset, Tbaddr}
	logic 	ren_delay;
	always_ff @(posedge clk) begin
		if (rst)
			ren_delay <= 0;

		else
			ren_delay <= fifo_ifc.fifo_ren;
			
	end

	// extend
	logic	ready;	// extend modules free and new data ready to be extended.

	assign ready = fifo_ifc.fifo_ren;


	genvar i;
	generate
		for (i = 0; i < NUM_EXTEND; i+=1) 
		begin: extend_inst
			enum {W,V,R,C}state; //WAIT, VALID, RUN, COMPLETE
			logic	[LOG_TILE_SIZE: 0]	k;
			logic	[TB_ADDR - 1: 0]	tbaddr;

			logic	[LOG_TILE_SIZE - 1: 0]	o_offset;
			logic	[LOG_TILE_SIZE - 1: 0]	new_offset;

			logic 	is_valid;
			logic	is_extend;
			logic	is_complete;

			always_ff @(posedge clk) begin
				if (rst) begin
					{is_valid, k, o_offset, tbaddr} <= 0;
					is_extend <= 1;
					is_finish[i] <= 1;
				end
				else begin
					case (state)
						W: begin
							if (ren_delay) begin
								{is_valid, k, o_offset, tbaddr} <= fifo_dout[(i+1)*FIFO_WIDTH - 1: i*FIFO_WIDTH];
							end
						end
						V: begin
							is_extend <= 1;
							is_finish[i] <= 0;
						end
						R: begin
							o_offset <= new_offset;
						end
						C:	begin
							is_extend <= 0;
							is_finish[i] <= 1;
						end
					endcase
				end
			end

			always_ff @(posedge clk) begin
				if (rst) begin
					state <= W;
				end
				case (state)
					W: begin
						if (is_valid) begin
							state <= V;
						end
					end
					V: begin
						// Set Address
						state <= R;
					end
					R: begin
						// Further extension required
						if (is_complete) begin
							state <= C;
						end
						else begin
							state <= V;
						end;
					end
				endcase
			end


			extend #(
				.NUM_EXTEND(NUM_EXTEND),
				.EXTEND_LEN(EXTEND_LEN),
				.TILE_SIZE(TILE_SIZE),
				.DATA_WIDTH(DATA_WIDTH),
				.BLOCK_WIDTH(BLOCK_WIDTH),
				.TB_ADDR(TB_ADDR),
				.FIFO_WIDTH(FIFO_WIDTH)
			) extend_inst (
				.clk(clk),
				.rst(rst),
				.rwr_ifc(rwr_bcast[i]),
				.qwr_ifc(qwr_bcast[i]),
				.k(k),
				.roffset(o_offset),
				.offset(new_offset),
				.is_valid(is_valid),
				.is_complete(is_complete),
				.load(load)
			);
		end
	endgenerate
	
	generate
	fifo #(
		.DEPTH(8), 
		.DATA_WIDTH(NUM_EXTEND*FIFO_WIDTH) // 8*{is_valid, k, offset, Tbaddr}
	) fifo_inst (
		.clk(clk),
		.rst(rst),
		.wen(fifo_ifc.fifo_wen),
		.ren(fifo_ifc.fifo_ren),
		.din(fifo_ifc.fifo_din),
		.dout(fifo_dout),
		.full(fifo_ifc.fifo_full),
		.empty(fifo_ifc.fifo_empty)			
	);
	endgenerate

	

endmodule: extend_array


module extend #(
	parameter NUM_EXTEND = 8,
	parameter LOG_NUM_EXTEND = $clog2(NUM_EXTEND),
    parameter EXTEND_LEN = 8,
    parameter LOG_EXTEND_LEN = $clog2(EXTEND_LEN),
	parameter TILE_SIZE = 512,
	parameter LOG_TILE_SIZE = $clog2(TILE_SIZE),
	parameter DATA_WIDTH = 16,
	parameter BLOCK_WIDTH = 8,
	parameter LOG_BLOCK_WIDTH = $clog2(BLOCK_WIDTH),
    parameter TB_ADDR = 10,
	parameter FIFO_WIDTH = 2*LOG_TILE_SIZE + TB_ADDR + 1 + 1
)(
	input	clk,
	input	rst,
	dbram_wr_ifc.slave	rwr_ifc,
	dbram_wr_ifc.slave	qwr_ifc,
	// input	start,
	// input	[4*EXTEND_LEN - 1: 0]	rin,
	// input	[4*EXTEND_LEN - 1: 0]	qin,
	// output	[LOG_EXTEND_LEN - 1: 0]	offset,
	// input	logic	[FIFO_WIDTH - 1: 0]	fifo_dout,
	input 	logic	[LOG_TILE_SIZE: 0]	k,
	input 	logic 	[LOG_TILE_SIZE - 1: 0]	roffset,
	output 	logic 	[LOG_TILE_SIZE - 1: 0]	offset,
	input 	logic 	is_valid,	// if a diagonal needs to be extended
	output  logic 	is_complete,
	input	logic	load
);

	

	// BRAM signals
	logic	qwen;
	logic   [LOG_TILE_SIZE - LOG_BLOCK_WIDTH - 1: 0]  rbram_addr;
    logic   [LOG_TILE_SIZE - LOG_BLOCK_WIDTH - 1: 0]  qbram_addr;
	logic   [4*BLOCK_WIDTH - 1: 0]	rbram_dout;
	logic   [4*BLOCK_WIDTH - 1: 0]	qbram_dout;

	// Extend signals
	logic 	[LOG_BLOCK_WIDTH - 1: 0] idxr; 	// ref bram index of a row
	logic 	[LOG_BLOCK_WIDTH - 1: 0] idxq;	// query bram idx of a row


	// Stage1: Getting offsets and address
	logic 	[LOG_TILE_SIZE - 1: 0]	qoffset;
	logic	[LOG_BLOCK_WIDTH: 0]	max_extend;
	logic	[LOG_BLOCK_WIDTH: 0]	extended;
	
	
	assign rbram_addr = load ? rwr_ifc.addr: roffset[LOG_TILE_SIZE - LOG_BLOCK_WIDTH - 1: LOG_BLOCK_WIDTH];
	assign qbram_addr = load ? qwr_ifc.addr: qoffset[LOG_TILE_SIZE - LOG_BLOCK_WIDTH - 1: LOG_BLOCK_WIDTH];
	assign qoffset = roffset - k;
	assign idxr = roffset%BLOCK_WIDTH;
	assign idxq = qoffset%BLOCK_WIDTH;
	assign max_extend = BLOCK_WIDTH - ($signed(idxr - idxq) >= 0? idxr: idxq);
	assign offset[LOG_TILE_SIZE - 1: LOG_BLOCK_WIDTH] = roffset[LOG_TILE_SIZE - 1: LOG_BLOCK_WIDTH] + extended[LOG_BLOCK_WIDTH];
	assign offset[LOG_BLOCK_WIDTH - 1: 0] = extended[LOG_BLOCK_WIDTH - 1: 0];
		
	compare # (
		.NUM_EXTEND(NUM_EXTEND),
		.LOG_NUM_EXTEND(LOG_NUM_EXTEND),
		.EXTEND_LEN(EXTEND_LEN),
		.LOG_EXTEND_LEN(LOG_EXTEND_LEN),
		.TILE_SIZE(TILE_SIZE),
		.LOG_TILE_SIZE(LOG_TILE_SIZE),
		.DATA_WIDTH(DATA_WIDTH),
		.BLOCK_WIDTH(BLOCK_WIDTH),
		.LOG_BLOCK_WIDTH(LOG_BLOCK_WIDTH),
		.TB_ADDR(TB_ADDR),
		.FIFO_WIDTH(FIFO_WIDTH)
	) conpare_inst(	 
		.rin(rbram_dout), 
		.qin(qbram_dout), 
		.idxr(idxr),
		.idxq(idxq),
		.max_extend(max_extend),
		.out(extended),
		.is_complete(is_complete)
	);

	// always_ff @(posedge clk) begin 
	// 	if (rst || !is_valid) begin
	// 		finish <= 1;
	// 	end
	// 	else if (valid) begin
	// 		finish <= is_complete; // if valid and extend is complete.
	// 	end
	// end


	BRAM #(
		.ADDR_WIDTH(LOG_TILE_SIZE - LOG_BLOCK_WIDTH),
		.DATA_WIDTH(4*BLOCK_WIDTH)
	) ref_bram (
		.clk(clk),
		.addr(rbram_addr),
		.wen(rwr_ifc.wen),
		.din(rwr_ifc.din),
		.dout(rbram_dout)
	);
	BRAM #(
		.ADDR_WIDTH(LOG_TILE_SIZE - LOG_BLOCK_WIDTH),
		.DATA_WIDTH(4*BLOCK_WIDTH)
	) query_bram (
		.clk(clk),
		.addr(qbram_addr),
		.wen(qwr_ifc.wen),
		.din(qwr_ifc.din),
		.dout(qbram_dout)
	);

endmodule

module compare #(
	parameter NUM_EXTEND = 8,
	parameter LOG_NUM_EXTEND = $clog2(NUM_EXTEND),
    parameter EXTEND_LEN = 8,
    parameter LOG_EXTEND_LEN = $clog2(EXTEND_LEN),
	parameter TILE_SIZE = 512,
	parameter LOG_TILE_SIZE = $clog2(TILE_SIZE),
	parameter DATA_WIDTH = 16,
	parameter BLOCK_WIDTH = 8,
	parameter LOG_BLOCK_WIDTH = $clog2(BLOCK_WIDTH),
    parameter TB_ADDR = 10,
	parameter FIFO_WIDTH = 2*LOG_TILE_SIZE + TB_ADDR + 1
)(
	input [4*BLOCK_WIDTH - 1: 0] rin, 
	input [4*BLOCK_WIDTH - 1: 0] qin, 
	input [LOG_BLOCK_WIDTH - 1: 0] idxr,
	input [LOG_BLOCK_WIDTH - 1: 0] idxq,
	input [LOG_BLOCK_WIDTH: 0] max_extend,
	output [LOG_BLOCK_WIDTH : 0] out,
	output	is_complete
);
	logic [4*BLOCK_WIDTH - 1: 0] xor_op;
	logic match [BLOCK_WIDTH - 1: 0];
	logic [LOG_BLOCK_WIDTH: 0] out_reg;

	assign out = idxr + (out_reg>max_extend? max_extend: out_reg);
	assign is_complete = (out_reg < max_extend) ? 1 : 0;

	//00...110101 (idx=1) -> 00...110000 assigning 4*idx bits 0
	assign xor_op = (rin>>(4*idxr)) ^ (qin>>(4*idxq));
	
	genvar i;
	generate
		for (i = 0; i< BLOCK_WIDTH; i += 1)
		begin
			assign match[i] = xor_op[4*(i+1) - 1: 4*i] == 0 ? 0 : 1;
		end
	endgenerate

	always_comb begin
		if (match[0]) begin
			out_reg = 0;
		end
		else if(match[1]) begin
			out_reg = 1;
		end
		else if(match[2]) begin
			out_reg = 2;
		end
		else if(match[3]) begin
			out_reg = 3;
		end
		else if(match[4]) begin
			out_reg = 4;
		end
		else if(match[5]) begin
			out_reg = 5;
		end
		else if(match[6]) begin
			out_reg = 6;
		end
		else if (match[7])begin
			out_reg = 7;
		end
		else begin
			out_reg = 8;
		end
	end
endmodule


module broadcast #(parameter NUM_EXTEND = 8)(
	dbram_wr_ifc.slave	in,
	dbram_wr_ifc.master	out	[NUM_EXTEND - 1: 0]
);

	genvar i;
	generate
		for (i = 0; i < NUM_EXTEND; i += 1)
		begin
			assign out[i].wen = in.wen;
			assign out[i].din = in.din;
			assign out[i].addr = in.addr;
		end
	endgenerate

endmodule

// function [FIFO_WIDTH - 1: 0] extract(input [FIFO_WIDTH - 1: 0] fifo_dout);
// 	logic	[LOG_TILE_SIZE: 0]	k;
// 	logic 	[LOG_TILE_SIZE - 1: 0]	roffset;
// 	logic	[TB_ADDR - 1: 0]	tbaddr;
// 	assign 	k = fifo_dout[FIFO_WIDTH - 1: FIFO_WIDTH - LOG_TILE_SIZE - 1]; //LOG_TILE_SIZE + 1
// 	assign 	roffset = fifo_dout[FIFO_WIDTH - LOG_TILE_SIZE - 2: TB_ADDR]; //LOG_TILE_SIZE
// 	assign 	tbaddr = fifo_dout[TB_ADDR - 1: 0]; //TB_ADDR
// 	return {k, offset, tbaddr};
// endfunction