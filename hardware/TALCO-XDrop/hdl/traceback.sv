module  traceback # (
    parameter PE_WIDTH = 8,
    parameter DATA_WIDTH = 16,
    parameter NUM_BLOCK  = 4,
    parameter NUM_PE = 2,
    parameter LOG_NUM_PE = $clog2(NUM_PE),
    parameter MAX_TILE_SIZE = 16,
    parameter LOG_MAX_TILE_SIZE = $clog2(MAX_TILE_SIZE),
    parameter REF_LEN_WIDTH = 8,
    parameter QUERY_LEN_WIDTH = 8,
    parameter PARAM_ADDR_WIDTH = 8,
    parameter CONV_SCORE_WIDTH = 1 + 2*(REF_LEN_WIDTH + 2) + 2*PE_WIDTH,
    parameter TB_DATA_WIDTH = 4*NUM_PE,
    parameter TB_ADDR_WIDTH = $clog2(2*(MAX_TILE_SIZE/NUM_PE)*MAX_TILE_SIZE)
)(
    input   logic   clk,
    input   logic   rst,
    input   logic   tb_start,
    input   logic   [REF_LEN_WIDTH - 1: 0]      start_query_idx,
    input   logic   [REF_LEN_WIDTH - 1: 0]      start_ref_idx,
    input   logic   [1:0] start_tb_state,
    input   logic   [TB_DATA_WIDTH - 1: 0]      tb_bram_data_out,
    output   logic   [LOG_MAX_TILE_SIZE - 1: 0]  addr_offset_rd_addr,
    input   logic   [TB_ADDR_WIDTH-1: 0]      addr_offset_rd_result,
    input first_tile,

    output  logic   [TB_ADDR_WIDTH -1: 0]  tb_bram_addr_out,
    output  logic   [1:0] tb_pointer,
    output  logic   tb_valid,
    output  logic   tb_done
);

    enum {WAIT,INIT,TB,DONE} state;
    logic [LOG_NUM_PE-1:0] query_pe_idx;
    wire [LOG_NUM_PE-1:0] query_pe_idx_sub1;
    wire [LOG_NUM_PE-1:0] query_pe_idx_next;
    wire query_pe_idx_underflow;
    assign {query_pe_idx_underflow,query_pe_idx_sub1}={1'b0,query_pe_idx}-1;
    
    logic [TB_ADDR_WIDTH-1:0] cur_blk_idx;
    logic [TB_ADDR_WIDTH-1:0] next_blk_idx;
    assign next_blk_idx=cur_blk_idx-1;

    logic [REF_LEN_WIDTH-1:0] next_addr_offset;
    always @(posedge clk ) begin
        next_addr_offset<=(state==WAIT?start_query_idx[REF_LEN_WIDTH-1:LOG_NUM_PE]!=0:next_blk_idx!=0)?addr_offset_rd_result:(NUM_PE-1);
    end

    logic [REF_LEN_WIDTH-1:0] curr_ref_idx;
    wire [REF_LEN_WIDTH-1:0] next_ref_idx;
    wire [TB_ADDR_WIDTH-1:0] next_tb_bram_addr_diag,next_tb_bram_addr_horz,next_tb_bram_addr_vert;
    logic   [TB_ADDR_WIDTH-1: 0]  prev_tb_bram_addr;
    assign next_tb_bram_addr_diag=query_pe_idx_underflow?(curr_ref_idx+next_addr_offset-1):prev_tb_bram_addr-2;
    assign next_tb_bram_addr_vert=query_pe_idx_underflow?(curr_ref_idx+next_addr_offset):prev_tb_bram_addr-1;
    assign next_tb_bram_addr_horz=prev_tb_bram_addr-1;
    logic [1:0] cur_tb_state;
    wire [1:0] this_move;

    always_comb begin
        if(state==INIT)
            tb_bram_addr_out=curr_ref_idx+next_addr_offset-(NUM_PE-1)+query_pe_idx;
        else begin
            case(this_move)
                0: tb_bram_addr_out=next_tb_bram_addr_diag;
                1: tb_bram_addr_out=next_tb_bram_addr_horz;
                2: tb_bram_addr_out=next_tb_bram_addr_vert;
                3: tb_bram_addr_out='hx;
            endcase
        end
    end
    wire delete_extend,insert_extend;
    wire [1:0] h_move;
    wire [3:0] tb_ptr_read;
    assign tb_ptr_read=tb_bram_data_out[query_pe_idx*4+:4];
    assign {insert_extend,delete_extend,h_move}=tb_ptr_read;

    assign this_move=cur_tb_state==0?h_move:cur_tb_state;
    assign tb_pointer=this_move;
    assign tb_valid=state==TB;
    assign tb_start_pulse=tb_start&&state==WAIT;
    always @(posedge clk ) begin
        if(rst)
            state<=WAIT;
        else begin
            case(state)
                WAIT: if(tb_start_pulse) state<=INIT;
                INIT: state<=TB;
                TB: if(tb_done) state<=DONE;
            endcase 
        end 
    end
    assign tb_done=(state==TB)&&
        (first_tile?
            (curr_ref_idx==0||(query_pe_idx_underflow&&cur_blk_idx==0))
            :(next_ref_idx==0&&{cur_blk_idx,query_pe_idx_next}==0)
        );

    assign query_pe_idx_next=(this_move==0||this_move==2)?query_pe_idx_sub1:query_pe_idx;
    always @(posedge clk ) begin
        if(tb_start_pulse)
            query_pe_idx<=start_query_idx[LOG_NUM_PE-1:0];
        else if(state==TB) 
            query_pe_idx<=query_pe_idx_next;
    end
    wire is_init;
    assign is_init=state==INIT;
    always @(posedge clk ) begin
        if( tb_start_pulse)
            cur_blk_idx<=start_query_idx[REF_LEN_WIDTH-1:LOG_NUM_PE];
        else if(state==TB&&(this_move==0||this_move==2)&&query_pe_idx_underflow) 
            cur_blk_idx<=next_blk_idx;
    end
    assign addr_offset_rd_addr= ((tb_start_pulse)?start_query_idx[REF_LEN_WIDTH-1:LOG_NUM_PE]:next_blk_idx)-1;
    assign next_ref_idx=(this_move==0||this_move==1)?curr_ref_idx-1:curr_ref_idx;
    always @(posedge clk ) begin
        if( tb_start_pulse)
            curr_ref_idx<=start_ref_idx;
        else if(state==TB) 
            curr_ref_idx<=next_ref_idx;
    end

    always @(posedge clk ) begin
        prev_tb_bram_addr<=tb_bram_addr_out;
    end

    always @(posedge clk ) begin
        if(tb_start_pulse)
            cur_tb_state<=start_tb_state;
        else if(state==TB)
            case (this_move)
                0:cur_tb_state<=0;
                1:cur_tb_state<=delete_extend;
                2:cur_tb_state<=insert_extend?2:0;
                default: cur_tb_state<=2'hx;
            endcase
    end

endmodule