
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
    input new_score, // 1 when new score calculation starts for 2-3 cycles
    input wr2tb,
    global_ifc.master   global_ifc_inst,
    ext2red_ifc.master  ext2red_ifc_inst,
    fifo_rd_wr_ifc.slave  fifo_ifc_e2t,
    input   [(DATA_WIDTH + 1)*NUM_EXTEND  -1: 0]  fifo_dout
);
    
    logic   [LOG_TILE_SIZE: 0] new_kmin;
    logic   [LOG_TILE_SIZE: 0] new_kmax;
    logic   [LOG_TILE_SIZE: 0] base_k;

    //reduce
    logic   [FIFO_WIDTH* NUM_EXTEND - 1: 0] offsets;
    logic   [(DATA_WIDTH + 1) * NUM_EXTEND - 1: 0] distance;
    logic   [(DATA_WIDTH + 1) * NUM_EXTEND - 1: 0] distance_reg;
    logic   [DATA_WIDTH: 0] min_valid_dist; //{valid, min distance}
    logic   [DATA_WIDTH - 1: 0] min_dist;
    logic   is_reduce_finish;
    logic   [LOG_NUM_EXTEND: 0] lo;
    logic   [LOG_NUM_EXTEND: 0] hi;
    logic   [LOG_TILE_SIZE: 0] kmin;
    logic   [LOG_TILE_SIZE: 0] kmax;
    logic   [LOG_TILE_SIZE: 0] curr;
    logic   is_valid;
    

    logic [2:0] state;
    localparam WAIT = 0, DIST_FIND = 1, MIN_DIST = 2, REDUCE_SLACK = 3, REDUCE = 4, DONE = 5;
    
    always_ff @(posedge clk) begin
        if (new_score) begin
            min_dist <= 10000;
            is_reduce_finish <= 0;
        end
        else begin
            case (state) 
            WAIT: begin
                kmin <= 0; // can't loose k = 0 (global alignment)
                kmax <= 0; // can't loose k = 0 (global alignment)
                curr <= global_ifc_inst.kmin;
                if (&ext2red_ifc_inst.valid & !ext2red_ifc_inst.read) begin
                    ext2red_ifc_inst.read <= 1;
                    offsets <= ext2red_ifc_inst.offset;
                end
            end 
            DIST_FIND: begin
                distance_reg <= distance;
                fifo_ifc_e2t.fifo_wen <= distance[(DATA_WIDTH + 1) * NUM_EXTEND - 1];
                fifo_ifc_e2t.fifo_din <= distance;
            end
            MIN_DIST: begin
                fifo_ifc_e2t.fifo_wen <= 0;
                if (min_valid_dist[DATA_WIDTH] && (min_dist>min_valid_dist[DATA_WIDTH - 1: 0])) begin
                    min_dist <= min_valid_dist[DATA_WIDTH - 1: 0];
                end
            end
            REDUCE_SLACK: begin
                is_reduce_finish <= 1;
                fifo_ifc_e2t.fifo_ren <= 1;
            end
            REDUCE: begin
                if ((curr + lo < kmin) && (lo < 8) && is_valid) begin
                    kmin <= curr + lo;
                end
                if (((curr + (NUM_EXTEND - hi)) > kmax) && (NUM_EXTEND - hi < 8) && is_valid) begin
                    kmax <= curr + hi;
                end
                if (is_valid) begin
                    curr <= curr + NUM_EXTEND;
                end

            end

            DONE: begin
                
            end
            endcase
        end
        
    end

    
    always_ff @(posedge clk) begin
        if (new_score) begin
            state <= WAIT;
        end
        else begin
            case (state) 
            WAIT: begin
                if (&ext2red_ifc_inst.valid & !ext2red_ifc_inst.read) begin
                    state <= DIST_FIND;
                end
            end 
            DIST_FIND: begin
                state <= MIN_DIST;
            end
            MIN_DIST: begin
                if (fifo_ifc_e2t.fifo_empty) begin
                    state <= REDUCE_SLACK;
                end
                else begin
                    state <= WAIT;
                end
            end
            REDUCE_SLACK: begin
                state <= REDUCE;
            end
            REDUCE: begin
                if (fifo_ifc_e2t.fifo_empty) begin
                    state <= DONE;
                end
            end
            DONE: begin
                
            end
            endcase
        end
        
    end


    generate
        dist_finder #(
            .NUM_EXTEND(NUM_EXTEND),
            .TILE_SIZE(TILE_SIZE),
            .TB_ADDR(TB_ADDR),
            .FIFO_WIDTH(FIFO_WIDTH),
            .DATA_WIDTH(DATA_WIDTH)
        ) dist_finder_inst (
            .clk(clk),
            .rst(rst),
            .global_ifc_inst(global_ifc_inst),
            .offsets(offsets),
            .distance(distance)
        );
    endgenerate

    generate
        min_scan #(
            .NUM_EXTEND(NUM_EXTEND),
            .DATA_WIDTH(DATA_WIDTH)
        ) min_scan_inst (
            .distance(distance_reg),
            .min(min_valid_dist)
        );
    endgenerate

    generate
        compute_limit #(
            .NUM_EXTEND(NUM_EXTEND),
            .TILE_SIZE(TILE_SIZE),
            .FIFO_WIDTH(FIFO_WIDTH),
            .DATA_WIDTH(DATA_WIDTH)
        ) compute_limit_inst (
            .global_ifc_inst(global_ifc_inst),
            .distances(fifo_dout),
            .min_dist(min_dist),
            .kmin(lo),
            .kmax(hi),
            .is_valid(is_valid)
        );
    endgenerate


endmodule


module dist_finder # (parameter 
    NUM_EXTEND = 8,
    TILE_SIZE = 512,
    LOG_TILE_SIZE = $clog2(TILE_SIZE),
    TB_ADDR = 10,
    FIFO_WIDTH = 30,
    DATA_WIDTH = 16
)(
    input clk,
    input rst,
    global_ifc.master   global_ifc_inst,
    input   logic   [FIFO_WIDTH* NUM_EXTEND - 1: 0] offsets,
    output  logic   [(DATA_WIDTH + 1) * NUM_EXTEND - 1: 0] distance // {valid (1), distance (LOG_TILE_SIZE - 1)}
);
    genvar i;
    generate
        for (i = 0; i < NUM_EXTEND; i++) begin
            logic   valid;
            logic	[LOG_TILE_SIZE: 0]	k;
			logic	[LOG_TILE_SIZE - 1: 0]	offset;
			logic	[TB_ADDR - 1: 0]	tbaddr;
            
			logic	[DATA_WIDTH - 1: 0]	rtemp;
			logic	[DATA_WIDTH - 1: 0]	qtemp;
			logic	[DATA_WIDTH: 0]	dtemp;


            assign {valid,k,offset,tbaddr} = offsets[(i+1)*FIFO_WIDTH - 1: i*FIFO_WIDTH];
            assign rtemp = global_ifc_inst.ref_end_cord - offset; // (x-x0)
            assign qtemp = global_ifc_inst.query_end_cord - (offset - k); // (y - y0)
            assign dtemp = rtemp + qtemp - (rtemp <= qtemp ? rtemp : qtemp);
            assign distance[(i+1)*(DATA_WIDTH + 1) - 1: i*(DATA_WIDTH + 1)] = {valid, dtemp[DATA_WIDTH - 1: 0]};
        end
    endgenerate
    
endmodule

module min_scan #(parameter
    NUM_EXTEND = 8,
    LEVEL = $clog2(NUM_EXTEND),
    DATA_WIDTH = 16,
    VALUE = DATA_WIDTH + 1
)(
    input   logic [NUM_EXTEND*VALUE - 1: 0] distance,
    output  logic [VALUE - 1: 0] min // {valid, min}
);

    genvar i,j;
    generate
        for (i = 0; i < LEVEL ; i+=1 ) begin: level
            for (j = 0; j < 2**(LEVEL - i - 1); j+=1 ) begin: item
                logic [DATA_WIDTH - 1: 0] rval, lval, oval;
                logic rvalid, lvalid, ovalid;

                if (i == 0) begin
                    assign lvalid = distance[(2*j + 1)*VALUE - 1];                     
                    assign rvalid = distance[(2*j + 2)*VALUE - 1];                     
                    assign lval = lvalid ? distance[(2*j + 1)*VALUE - 2: (2*j)*VALUE]: -1;
                    assign rval = rvalid ? distance[(2*j + 2)*VALUE - 2: (2*j + 1)*VALUE]: -1;
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
    endgenerate
    assign min = {level[LEVEL - 1].item[0].ovalid, level[LEVEL - 1].item[0].oval};
endmodule


module compute_limit #(
    NUM_EXTEND = 8,
    LOG_NUM_EXTEND = $clog2(NUM_EXTEND),
    TILE_SIZE = 512,
    LOG_TILE_SIZE = $clog2(TILE_SIZE),
    FIFO_WIDTH = 30,
    DATA_WIDTH = 16
)(
    global_ifc.master   global_ifc_inst,
    input   logic   [(DATA_WIDTH + 1)* NUM_EXTEND - 1: 0] distances,
    input   logic   [DATA_WIDTH - 1: 0] min_dist,
    output  logic   [LOG_NUM_EXTEND: 0]  kmin,
    output  logic   [LOG_NUM_EXTEND: 0]  kmax,
    output  logic   is_valid
);
    
    logic [NUM_EXTEND - 1: 0] reduce_flag;
    logic [NUM_EXTEND - 1: 0] valid_flag;
    genvar i;
    generate
        for (i = 0; i < NUM_EXTEND; i+=1) begin
            logic [DATA_WIDTH - 1: 0] value;
            logic valid;
            assign {valid,value} = distances[(i+1)*(DATA_WIDTH + 1) - 1: i*(DATA_WIDTH + 1)];
            always_comb begin
                valid_flag[i] = valid;
                if (!valid || (value - min_dist > global_ifc_inst.drop)) begin
                    reduce_flag[i] = 1;
                end
                else begin
                    reduce_flag[i] = 0;
                end
            end
        end
        assign is_valid = |valid_flag;
    endgenerate
    
    //foward_pass
    always_comb begin
        if (!reduce_flag[7]) begin
            kmin = 0;
        end
        else if (!reduce_flag[6]) begin
           kmin = 1; 
        end
        else if (!reduce_flag[5]) begin
           kmin = 2; 
        end
        else if (!reduce_flag[4]) begin
           kmin = 3; 
        end
        else if (!reduce_flag[3]) begin
           kmin = 4; 
        end
        else if (!reduce_flag[2]) begin
           kmin = 5; 
        end
        else if (!reduce_flag[1]) begin
           kmin = 6; 
        end
        else if (!reduce_flag[0]) begin
           kmin = 7; 
        end
        else begin
            kmin = 8;
        end
    end

    //backward_pass
    always_comb begin
        if (!reduce_flag[0]) begin
            kmax = 1;
        end
        else if (!reduce_flag[1]) begin
            kmax = 2; 
        end
        else if (!reduce_flag[2]) begin
            kmax = 3; 
        end
        else if (!reduce_flag[3]) begin
            kmax = 4; 
        end
        else if (!reduce_flag[4]) begin
            kmax = 5; 
        end
        else if (!reduce_flag[5]) begin
            kmax = 6; 
        end
        else if (!reduce_flag[6]) begin
            kmax = 7; 
        end
        else if (!reduce_flag[7]) begin
            kmax = 8; 
        end
        else begin
            kmax = 0;
        end
    end


endmodule
