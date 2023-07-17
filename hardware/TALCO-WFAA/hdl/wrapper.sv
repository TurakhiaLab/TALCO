// Reference and Query characters are 1 indexed, but stored 0 indexed in bram 



module wrapper #(
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
    parameter FIFO_WIDTH = 2*LOG_TILE_SIZE + TB_ADDR + 1 + 1 // {is_extend, k, offset, tbAddr}
) (
    input   logic   clk,
    input   logic   rst,
    dbram_wr_ifc.slave  rwr_ifc,
    dbram_wr_ifc.slave  qwr_ifc,
    input   logic   load,
    input   logic   start,
    input   logic   [DATA_WIDTH - 1: 0]  reference_length,
    input   logic   [DATA_WIDTH - 1: 0]  query_length,

    output  logic   done
);
    enum {WAIT, LOAD_DATA, DUMY, ALIGN, TB, DONE} state;
    
    // fifo compute-extend
    fifo_rd_wr_ifc #(.DEPTH(8), .DATA_WIDTH(NUM_EXTEND * FIFO_WIDTH)) fifo_ifc_c2e ();

    // fifo reduce_tbbram
    fifo_rd_wr_ifc #(.DEPTH(8), .DATA_WIDTH(NUM_EXTEND * FIFO_WIDTH)) fifo_ifc_e2t ();

    // extend-reduce interface
    ext2red_ifc #(
        .NUM_EXTEND(NUM_EXTEND),
        .FIFO_WIDTH(FIFO_WIDTH)
    ) ext2red_ifc_inst ();

    // global interface (kmin, kmax)
    global_ifc #(
        .TILE_SIZE(TILE_SIZE)
    ) global_ifc_inst ();
    logic new_score;

    //Extend
    logic	[NUM_EXTEND - 1: 0]	is_finish;

    // Reduce
    logic   wr2tb; // 1 when all wavefronts are extended and fifo_ifc_c2e is empty


    always_ff @(posedge clk) begin
        if (rst) begin
            global_ifc_inst.ref_end_cord <= reference_length;
            global_ifc_inst.query_end_cord <= query_length;
            global_ifc_inst.drop <= 50;
            global_ifc_inst.kmin <= 0;
            global_ifc_inst.kmax <= 0;
            new_score <= 0;
            wr2tb <= 0;
        end
        else begin
            case (state)
                WAIT: begin
                    
                end 
                LOAD_DATA: begin
                    
                end
                DUMY: begin
                    fifo_ifc_c2e.fifo_din <= {1'b1,10'b0,9'b0,10'b0, 1'b1,10'b1111111110,9'b1111,10'b0, 180'b0};
                    fifo_ifc_c2e.fifo_wen <= 1;
                    new_score <= 1;
                end
                ALIGN: begin
                    fifo_ifc_c2e.fifo_wen <= 0;
                    new_score <= 0;
                    fifo_ifc_c2e.fifo_ren <= (!fifo_ifc_c2e.fifo_empty) & (&is_finish);
                    wr2tb <= fifo_ifc_c2e.fifo_empty & is_finish;
                end
            endcase
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            state <= WAIT;
        end
        else begin
            case (state)
                WAIT: begin
                    if(load) begin
                        state <= LOAD_DATA;
                        
                    end
                end 
                LOAD_DATA: begin
                    if (start) begin
                        state <= DUMY;
                    end
                end
                DUMY: begin
                    state <= ALIGN;
                end
                ALIGN: begin
                    
                end
            endcase
        end
    end

    

    generate
        extend_array #(
            .NUM_EXTEND(NUM_EXTEND),
            .EXTEND_LEN(EXTEND_LEN),
            .TILE_SIZE(TILE_SIZE),
            .DATA_WIDTH(DATA_WIDTH),
            .BLOCK_WIDTH(BLOCK_WIDTH),
            .TB_ADDR(TB_ADDR),
            .FIFO_WIDTH(FIFO_WIDTH)
        ) extend_array_instance (
            .clk(clk),
            .rst(rst),
            .rwr_ifc(rwr_ifc),
            .qwr_ifc(qwr_ifc),
            .fifo_ifc(fifo_ifc_c2e),
            .is_finish(is_finish),
            .load(state==LOAD_DATA),
            .ext2red_ifc_inst(ext2red_ifc_inst)
        );
    endgenerate

    generate
        reduce #(
            .NUM_EXTEND(NUM_EXTEND),
            .EXTEND_LEN(EXTEND_LEN),
            .TILE_SIZE(TILE_SIZE),
            .DATA_WIDTH(DATA_WIDTH),
            .BLOCK_WIDTH(BLOCK_WIDTH),
            .TB_ADDR(TB_ADDR),
            .FIFO_WIDTH(FIFO_WIDTH)
        ) reduce_instance (
            .clk(clk),
            .rst(rst),
            .new_score(new_score),
            .wr2tb(wr2tb),
            .global_ifc_inst(global_ifc_inst),
            .ext2red_ifc_inst(ext2red_ifc_inst),
            .fifo_ifc_e2t(fifo_ifc_e2t),
            .fifo_dout(fifo_ifc_e2t.fifo_dout)
        );
    endgenerate

    generate
	fifo #(
		.DEPTH(8), 
		.DATA_WIDTH((DATA_WIDTH + 1)*NUM_EXTEND) // 8*{is_valid, k, offset, Tbaddr}
	) fifo_inst (
		.clk(clk),
		.rst(rst),
		.wen(fifo_ifc_e2t.fifo_wen),
		.ren(fifo_ifc_e2t.fifo_ren),
		.din(fifo_ifc_e2t.fifo_din),
		.dout(fifo_ifc_e2t.fifo_dout),
		.full(fifo_ifc_e2t.fifo_full),
		.empty(fifo_ifc_e2t.fifo_empty)			
	);
	endgenerate


endmodule