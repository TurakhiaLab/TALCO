
// FIFO -> extend -> dist_finder -> min_scan -> FIFO -> reduction ->

module reduce #(
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
) (
    input clk, 
    input rst,
    input next_cycle,
    global_ifc.master   global_ifc_inst,
    ext2red_ifc.master  ext2red_ifc_inst
);
    
    logic   [LOG_TILE_SIZE: 0] new_kmin;
    logic   [LOG_TILE_SIZE: 0] new_kmax;
    logic   [LOG_TILE_SIZE: 0] base_k;



    always_ff @(posedge clk) begin
        if (rst) begin
            new_kmin <= 0;
            new_kmax <= 0;
            base_k <= 0;
        end
        else 
    end



endmodule


module dist_finder # (parameter 
    NUM_EXTEND = 8,
    TB_ADDR = 10,
    FIFO_WIDTH = 30
)(
    global_ifc.master   global_ifc_inst,
    ext2red_ifc.master  ext2red_ifc_inst,
    output  [(LOG_TILE_SIZE + 1) * NUM_EXTEND - 1: 0] distace; // {valid (1), distance (LOG_TILE_SIZE - 1)}
);
    genvar i;
    generate
        for (i = 0; i < NUM_EXTEND; i++) begin
            logic   valid;
            logic	[LOG_TILE_SIZE: 0]	k;
			logic	[LOG_TILE_SIZE - 1: 0]	offset;
			logic	[TB_ADDR - 1: 0]	tbaddr;
            
			logic	[LOG_TILE_SIZE - 1: 0]	rtemp;
			logic	[LOG_TILE_SIZE - 1: 0]	qtemp;
			logic	[LOG_TILE_SIZE: 0]	dtemp;


            assign {valid,k,offset,tbaddr} = ext2red_ifc.offset[(i+1)*FIFO_WIDTH - 1: i*FIFO_WIDTH];
            assign rtemp = global_ifc_inst.ref_end_cord - offset; // (x-x0)
            assign qtemp = global_ifc_inst.query_end_cord - (offset - k); // (y - y0)
            assign dtemp = rtemp + qtemp - (rtemp <= qtemp ? rtemp - qtemp);
            always@(posedge clk) begin
                if (rst) begin
                    distace <= 0;
                end
                else begin
                    // (x-x0) + (y-y0) - min((x-x0, y-y0))
                    distace[(i+1)*LOG_TILE_SIZE - 1: i*LOG_TILE_SIZE] <= {valid, dtemp[LOG_TILE_SIZE - 1: 0]};
                end
            end
        end
    endgenerate
    
endmodule

module min_scan #(parameter
    NUM_EXTEND = 8,
    LEVEL = $clog2(NUM_EXTEND),
    TILE_SIZE = 512,
    VALUE = $clog2(TILE_SIZE) + 1
)(
    input   logic [NUM_EXTEND*VALUE - 1: 0] distace,
    output  logic [VALUE - 1: 0] min // {valid, min}
);

    genvar i,j;
    generate
        for (i = 0; i < LEVEL ; i+=1 ) begin: level
            for (j = 0; j < 2**(LEVEL - i - 1); j+=1 ) begin : item
                logic [LOG_TILE_SIZE - 1: 0] rval, lval, oval;
                logic rvalid, lvalid, ovalid;

                if (i == 0) begin
                    assign lvalid = distace[(2*j + 1)*VALUE - 1];                     
                    assign rvalid = distace[(2*j + 2)*VALUE - 1];                     
                    assign lval = lvalid ? distace[(2*j + 1)*VALUE - 2: (2*j)*VALUE]: -1;
                    assign rval = rvalid ? distace[(2*j + 2)*VALUE - 2: (2*j + 1)*VALUE]: -1;
                end

                else begin
                    assign lval = level[i-1].item[2*j].oval;
                    assign rval = level[i-1].item[2*j + 1].oval;
                    assign lvalid = level[i-1].item[2*j].ovalid;
                    assign rvalid = level[i-1].item[2*j + 1].ovalid;
                end

                assign ovalid = rvalid | lvalid;
                assign oval = (lval <= rval) ? lval : rval;

            end
        end

        assign min = {level[LEVEL - 1].item[LEVEL - 1].ovalid, level[LEVEL - 1].item[LEVEL - 1].ovalid};

    endgenerate
endmodule


module compute_limit #(
    
)(
    
);
    
endmodule
