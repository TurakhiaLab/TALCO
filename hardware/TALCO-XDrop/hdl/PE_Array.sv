module compute_tb_start #(parameter PE_WIDTH=8,LOG_MAX_TILE_SIZE=10,REF_LEN_WIDTH=10)
    (
        input clk,
        input [LOG_MAX_TILE_SIZE:0] marker,
        input [REF_LEN_WIDTH+1:0] conv_value,
        output logic [REF_LEN_WIDTH-1:0] conv_query_idx,
        output logic [REF_LEN_WIDTH-1:0] conv_ref_idx,
        output logic [1:0] conv_state
    );
    wire [REF_LEN_WIDTH-1:0] conv_ref_idx_next;
    wire [1:0] conv_marker;
    assign {conv_ref_idx_next,conv_marker}=conv_value;
    
    always @(posedge clk ) begin
            conv_ref_idx<=conv_ref_idx_next;
            conv_query_idx<=marker-conv_ref_idx_next-(conv_marker==3);
            case (conv_marker)
                0: conv_state<=0;
                2: conv_state<=1;
                1: conv_state<=2;
                3: conv_state<=0;
            endcase
    end
endmodule
module PE_Array #(
    parameter PE_WIDTH = 7,
    parameter DATA_WIDTH = 8,
    parameter NUM_BLOCK  = 4,
    parameter NUM_PE = 32,
    parameter LOG_NUM_PE = $clog2(NUM_PE),
    parameter MAX_TILE_SIZE = 64,
    parameter LOG_MAX_TILE_SIZE = $clog2(MAX_TILE_SIZE),
    parameter REF_LEN_WIDTH = 8,
    parameter QUERY_LEN_WIDTH = 8,
    parameter PARAM_ADDR_WIDTH = 8,
    parameter CONV_SCORE_WIDTH = 1 + 2*(REF_LEN_WIDTH + 2) + 3*PE_WIDTH+1,
    parameter TB_DATA_WIDTH = 4*NUM_PE,
    parameter TB_ADDR_WIDTH = $clog2(2*(MAX_TILE_SIZE/NUM_PE)*MAX_TILE_SIZE)
    )(
        input  logic clk,
        input  logic rst,
        input  logic start,

        input  logic [13*PE_WIDTH - 1: 0] in_param,
        input  logic [REF_LEN_WIDTH - 1:0] total_ref_length,
        input  logic [QUERY_LEN_WIDTH - 1:0] total_query_length,
        //input  logic [LOG_MAX_TILE_SIZE - 1:0] tile_ref_length,
        //input  logic [LOG_MAX_TILE_SIZE - 1:0] tile_query_length,

        input  logic complement_ref_in,
        output logic [(LOG_MAX_TILE_SIZE/NUM_BLOCK): 0] ref_bram_addr,
        input  logic [DATA_WIDTH - 1:0]                     ref_bram_data_out,

        input  logic complement_query_in,
        output logic [(LOG_MAX_TILE_SIZE/NUM_BLOCK): 0] query_bram_addr,
        input  logic [DATA_WIDTH - 1:0]                     query_bram_data_out,

        output logic                               rstb,
        output logic                               regceb,
        output logic                               score_bram_wr_en_ext,
        output logic                               score_bram_rd_en,
        // conv_check + CH_score + CI_score + H_score + I_score
        output logic [CONV_SCORE_WIDTH - 1:0]      score_bram_data_in, 
        input  logic [CONV_SCORE_WIDTH - 1:0]      score_bram_data_out, 
        output logic [LOG_MAX_TILE_SIZE - 1: 0]    score_bram_addr_wr,
        output logic [LOG_MAX_TILE_SIZE - 1: 0]    score_bram_addr_rd,

        output logic                               tb_bram_wr_en,
        output logic [TB_DATA_WIDTH - 1: 0]        tb_bram_data_in,
        input  logic [TB_DATA_WIDTH - 1: 0]        tb_bram_data_out,
        output logic [TB_ADDR_WIDTH-1: 0]    tb_bram_addr_reg,

        output  logic last_tile,
        input  logic [PE_WIDTH - 1: 0] INF,        
        input  logic [LOG_MAX_TILE_SIZE : 0] marker,
        input  logic signed [PE_WIDTH - 1: 0] xdrop_value,
        input [1:0] init_state,
        
        //output logic [REF_LEN_WIDTH - 1: 0] lb,
        //output logic [REF_LEN_WIDTH - 1: 0] ub,
        output logic [1: 0] tb_pointer,
        output logic tb_valid,
        //output logic host_en,
        output logic [QUERY_LEN_WIDTH-1:0] query_next_tile_addr,
        output logic [REF_LEN_WIDTH-1:0] ref_next_tile_addr,
        output logic [1:0] next_tile_init_state,
        output commit,
        output traceback,
        output logic stop

    );

/*    localparam WAIT = 0, READ_PARAM = 1, SET_PARAM = 2;
    localparam STREAM_REF_START = 3, STREAM_REF = 4;
    localparam STREAM_REF_CONTINUE = 5, STREAM_REF_DONE = 6;
    localparam STREAM_REF_STOP = 7, DONE = 8, TB = 9, EXIT = 10,DONE2=11;*/

    localparam PARAM_WIDTH = 4 * PE_WIDTH;

    logic score_bram_wr_en,score_bram_wr_en_delayed;
    enum {WAIT,READ_PARAM,SET_PARAM,STREAM_REF_START,STREAM_REF,STREAM_REF_CONTINUE,STREAM_REF_DONE,STREAM_REF_STOP,DONE,TB,EXIT,DONE2} STATE;

    logic [2:0] ref_nt;
    logic [2:0] query_nt;

    logic block; // 0 for first block otherwise 1

    logic [PARAM_WIDTH - 1:0] param; 
    logic [PARAM_WIDTH - 1:0] out_param;

    logic [REF_LEN_WIDTH-1:0]     curr_ref_length;
    logic [QUERY_LEN_WIDTH-1:0]   curr_query_length;

    //logic   init_0;
    logic   init_n;
    logic   init_in   [0: NUM_PE - 1];
    logic   [NUM_PE - 1: 0] set_param;

    logic [2: 0] ref_in [0: NUM_PE - 1];
    logic signed [PE_WIDTH - 1: 0] sub_A_in;
    logic signed [PE_WIDTH - 1: 0] sub_C_in;
    logic signed [PE_WIDTH - 1: 0] sub_G_in;
    logic signed [PE_WIDTH - 1: 0] sub_T_in;
    logic signed [PE_WIDTH - 1: 0] sub_N_in;
    logic signed [PE_WIDTH - 1: 0] gap_open_in;
    logic signed [PE_WIDTH - 1: 0] gap_extend_in;

    logic [REF_LEN_WIDTH - 1: 0]    curr_ref_idx;
    logic [REF_LEN_WIDTH - 1: 0]    ref_idx_in   [0: NUM_PE - 1];
    logic [QUERY_LEN_WIDTH - 1: 0]  query_idx_in [0: NUM_PE - 1];

    logic signed [PE_WIDTH - 1: 0]          conv_score;
    logic [REF_LEN_WIDTH-1:0]   conv_query_idx,conv_ref_idx;
    logic [1:0] conv_tb_state;
    wire [LOG_MAX_TILE_SIZE-1:0] block_rd_idx;
    logic signed [PE_WIDTH - 1: 0]   global_max_score;
    logic signed [PE_WIDTH - 1: 0]   ad_max_score,ad_max_score_next,ad_max_score_prev_block,ad_max_score_prev_block_raw,cur_ad_max_score;
    logic [REF_LEN_WIDTH - 1: 0]     global_max_ref_idx;
    logic [REF_LEN_WIDTH : 0]     global_max_ad_idx, convergence_detected_ad_idx;
    logic [QUERY_LEN_WIDTH - 1: 0]        global_max_query_idx;

    logic signed [PE_WIDTH - 1: 0]         H_init;
    //logic signed [PE_WIDTH - 1: 0]         D_init;
    //logic signed [PE_WIDTH - 1: 0]         H_init_in; 
    logic signed [PE_WIDTH - 1: 0]         D_init_in; 

    //logic [3 * PE_WIDTH - 1: 0]     diag_score; // Score (H,I,D) for previous block's last row's (lower bound - 1)th idx 
    logic signed [PE_WIDTH - 1: 0]         H_prev_block,H_prev_block_raw;
    logic signed [PE_WIDTH - 1: 0]         I_prev_block,I_prev_block_raw;

    //logic signed [PE_WIDTH - 1: 0]         H_PE_prev_n;
    //logic signed [PE_WIDTH - 1: 0]         I_PE_prev_n;
    //logic signed [PE_WIDTH - 1: 0]         D_PE_prev_n;
    logic signed [PE_WIDTH - 1: 0]         H_PE_prev [0: NUM_PE - 1];
    logic signed [PE_WIDTH - 1: 0]         I_PE_prev [0: NUM_PE - 1];
    logic [REF_LEN_WIDTH  + 1: 0]   CH_PE_prev [0: NUM_PE - 1];
    wire [REF_LEN_WIDTH  + 1: 0]   CH_PE_prev_block,CH_PE_prev_block_pipe,CI_PE_prev_block,CH_PE_prev_block_raw,CI_PE_prev_block_raw;
    logic [REF_LEN_WIDTH  + 1: 0]   CI_PE_prev [0: NUM_PE - 1];
    logic signed [PE_WIDTH - 1: 0]         rd_array   [0: NUM_PE - 1];

    logic                   init_out [0: NUM_PE - 1];
    logic [2: 0]            ref_out  [0: NUM_PE - 1];
    //logic [NUM_PE - 1: 0]   xdrop_flag;
    logic [TB_DATA_WIDTH - 1: 0] dir_out;
    
    logic [REF_LEN_WIDTH - 1: 0]    ref_idx_out [0: NUM_PE - 1];
    logic [QUERY_LEN_WIDTH - 1: 0]  query_idx_out [0: NUM_PE - 1];

    logic [REF_LEN_WIDTH + 1: 0]         H_rd_value;
    logic [REF_LEN_WIDTH + 1: 0]         I_rd_value;
    logic [REF_LEN_WIDTH + 1: 0]         D_rd_value;

    logic signed [PE_WIDTH - 1: 0]         rd_value;
    //logic [REF_LEN_WIDTH + 1: 0]    CH_reg; // stores (curr_dia -1)th convergence M value  
    //logic [REF_LEN_WIDTH + 1: 0]    CH_reg2; // stores (curr_dia)th convergence M value  from previous block
    //logic                           CID_reg; // stores (curr_dia)th convergence I,D flag from previous block

    logic signed [PE_WIDTH - 1: 0]         H_PE [0: NUM_PE - 1];
    logic signed [PE_WIDTH - 1: 0]         I_PE [0: NUM_PE - 1];
    logic signed [PE_WIDTH - 1: 0]         D_PE [0: NUM_PE - 1];
    logic [REF_LEN_WIDTH  + 1: 0]   CH_PE [0: NUM_PE - 1];
    logic [REF_LEN_WIDTH  + 1: 0]   CI_PE [0: NUM_PE - 1];
    logic [REF_LEN_WIDTH  + 1: 0]   CD_PE [0: NUM_PE - 1];

    // Block's bounds
    logic lower_bound_check;
    // ToDo: Change 2048 such that it can handle longer query
    logic [$clog2(MAX_TILE_SIZE/NUM_PE): 0] block_count;
    logic [REF_LEN_WIDTH - 1: 0] start_idx;
    logic [REF_LEN_WIDTH - 1: 0] lower_bound_value;
    //logic [REF_LEN_WIDTH - 1: 0] upper_bound_value;
    
    //TB bram addr=addr of first ad in the block + query_offset + (ref_idx-start_ref)
    logic [TB_ADDR_WIDTH-1: 0] tb_bram_start_sub_ref_start [MAX_TILE_SIZE/NUM_PE - 1: 0];
    //logic [REF_LEN_WIDTH - 1: 0] upper_bound [MAX_TILE_SIZE/NUM_PE - 1: 0];

    // convergence
    logic conv;
    logic C1,C2,C3,C4,C5;
    logic query_oflow;
    logic ref_oflow;
    always @(posedge clk ) begin
        if(rst)
            ref_oflow<=0;
        else
            ref_oflow<=curr_ref_length>=total_ref_length;
    end

    always @(posedge clk ) begin
        if(rst)
            query_oflow<=0;
        else
            query_oflow<=curr_query_length>=total_query_length;
    end
    logic [REF_LEN_WIDTH+1:0] global_max_conv_idx;
    // Traceback
    logic tb_start;
    logic [1:0] tb_state;
    logic [TB_ADDR_WIDTH-1: 0] tb_bram_addr_out;
    logic [TB_ADDR_WIDTH-1: 0]    tb_bram_addr;
    logic tb_done;
    wire last_PE_not_droped;
    wire [REF_LEN_WIDTH:0] curr_ad_idx;
    assign curr_ad_idx= (curr_ref_length) + (curr_query_length - NUM_PE);
    logic past_marking;
    always @(posedge clk ) begin
        past_marking<=curr_ad_idx>marker+1;
    end
    wire [CONV_SCORE_WIDTH - 1:0] prev_block_to_write;
    wire H_converged_this_block,H_converged,I_converged,D_converged, this_ad_converged;
    assign prev_block_to_write={this_ad_converged,H_converged,CH_PE[NUM_PE - 1], CI_PE[NUM_PE - 1], H_PE[NUM_PE - 1], I_PE[NUM_PE - 1],ad_max_score_next};
    wire CID_prev_block,CID_prev_block_raw,H_converged_prev_block,H_converged_prev_block_raw;
    assign {
        CID_prev_block_raw,
        H_converged_prev_block_raw,
        CH_PE_prev_block_raw,
        CI_PE_prev_block_raw,
        H_prev_block_raw,
        I_prev_block_raw,
        ad_max_score_prev_block_raw
    }=score_bram_data_out;
    wire CID_writing_debug;
    wire signed [PE_WIDTH-1:0] H_WR_debug,I_WR_debug,ad_WR_debug;
    wire [REF_LEN_WIDTH+1:0] CH_WR_debug,CI_WR_debug;
    assign {CID_writing_debug,CH_WR_debug,CI_WR_debug,H_WR_debug,I_WR_debug,ad_WR_debug}=score_bram_data_in;
    sft_reg #(.BW(CONV_SCORE_WIDTH),.DEPTH(3)) score_wr_delay(
        .clk(clk),
        .en(1),
        .in(prev_block_to_write),
        .out(score_bram_data_in));
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
        .in(init_out[NUM_PE-1]),
        .out(score_valid_delayed)
    );
    assign score_bram_wr_en_ext=(score_bram_wr_en_delayed|score_bram_wr_en)&score_valid_delayed;
    always_ff @(posedge clk) begin
        if(score_bram_wr_en_ext)
            score_bram_addr_wr<=score_bram_addr_wr+1;
        else
            score_bram_addr_wr<=0; 
    end
    logic past_score_bram_wr_en_ext;
    parameter CONV_DONT_CARE=0;
    parameter NU_DONT_CARE=5;
    sft_w_rst #(.DEPTH(1)) score_bram_wr_pipe(
        .clk(clk),
        .rst(rst),
        .en(1),
        .in(score_bram_wr_en_ext),
        .out(past_score_bram_wr_en_ext)
    );
    logic [ LOG_MAX_TILE_SIZE-1:0 ] score_bram_valid_up_to;
    always @(posedge clk ) begin
        if(!score_bram_wr_en_ext&&past_score_bram_wr_en_ext)
            score_bram_valid_up_to<=score_bram_addr_wr-1;
    end

    always @(posedge clk ) begin
        if(rst)
            score_bram_rd_en <= 0;
        else if (
            (block && set_param[NUM_PE - 4]&&start_idx)||
            (block && set_param[NUM_PE - 3])
        ) begin
            score_bram_rd_en <= 1;
        end else if(score_bram_addr_rd==score_bram_valid_up_to||set_param[0])
            score_bram_rd_en <= 0;
    end

    logic past_score_bram_rd_en;
    sft_w_rst #(.DEPTH(1)) score_bram_rd_pipe(
        .clk(clk),
        .rst(rst),
        .en(1),
        .in(score_bram_rd_en),
        .out(past_score_bram_rd_en)
    );
    wire not_last_droped_in_prev_block=past_score_bram_rd_en&&score_bram_rd_en;
    wire CID_prev_block_temp;
    sft_reg #(.DEPTH(1),.BW(1)) CID_pipe(.clk(clk),.en(1),.in(CID_prev_block_raw),.out(CID_prev_block_temp));
    assign CID_prev_block=!not_last_droped_in_prev_block||CID_prev_block_temp;
    wire H_converged_prev_block_temp;
    sft_reg #(.DEPTH(1),.BW(1)) H_converged_pipe(.clk(clk),.en(1),.in(H_converged_prev_block_raw),.out(H_converged_prev_block_temp));
    assign H_converged_prev_block=!not_last_droped_in_prev_block||H_converged_prev_block_temp;
    logic prev_blk_valid;
    sft_reg #(.DEPTH(1),.BW(1)) prev_block_valid_pipe(.clk(clk),.en(1),.in(past_score_bram_rd_en),.out(prev_blk_valid));
    assign CH_PE_prev_block=past_score_bram_rd_en?CH_PE_prev_block_raw:CONV_DONT_CARE;
    sft_reg #(.DEPTH(1),.BW(REF_LEN_WIDTH+2)) CH_IDX_pipe(.clk(clk),.en(1),.in(CH_PE_prev_block),.out(CH_PE_prev_block_pipe));
    sft_reg #(.DEPTH(1),.BW(PE_WIDTH)) ad_max_pipe(.clk(clk),.en(1),.in(ad_max_score_prev_block_raw),.out(ad_max_score_prev_block));
    assign CI_PE_prev_block=past_score_bram_rd_en?CI_PE_prev_block_raw:CONV_DONT_CARE;
    assign H_prev_block=past_score_bram_rd_en?H_prev_block_raw:-INF;
    assign I_prev_block=past_score_bram_rd_en?I_prev_block_raw:-INF;
    assign last_PE_not_droped=(H_PE[NUM_PE-1]+xdrop_value)>=ad_max_score;
    //assign ad_max_score_prev_block=past_score_bram_rd_en?ad_max_score_prev_block_raw:0;
    assign H_converged=H_converged_this_block&&
        H_converged_prev_block&&
        past_marking&&
        (!not_last_droped_in_prev_block||H_rd_value==CH_PE_prev_block_pipe);
    assign this_ad_converged=
        H_converged&&
        CID_prev_block&&
        I_converged&&
        D_converged&&
        (I_rd_value==H_rd_value||I_rd_value==CONV_DONT_CARE||H_rd_value==CONV_DONT_CARE)&&
        (D_rd_value==H_rd_value||D_rd_value==CONV_DONT_CARE||H_rd_value==CONV_DONT_CARE);
    logic [REF_LEN_WIDTH+1:0]H_rd_value_prev_ad;
    logic H_converged_prev_ad;

    always @(posedge clk ) begin
        H_rd_value_prev_ad<=H_rd_value;
        H_converged_prev_ad<=H_converged;
    end

    logic signed [PE_WIDTH-1:0] diag_delayed;
    logic [REF_LEN_WIDTH+1:0] diag_CH_delayed;
    logic score_bram_loaded_first;
    always @(posedge clk ) begin
        if(rst)
            score_bram_loaded_first<=0;
        else
            score_bram_loaded_first<=score_bram_rd_en&&score_bram_addr_rd==0;
    end
    always_ff @( posedge clk ) begin
        if(score_bram_loaded_first)
            diag_delayed<=H_prev_block;
        else if(set_param[NUM_PE-2]&&block&&(!start_idx))
            diag_delayed<=-INF;
    end
    always_ff @( posedge clk ) begin
        if(score_bram_loaded_first)
            diag_CH_delayed<=CH_PE_prev_block;
    end
    /*always_comb begin
        CH_reg = (curr_ref_length < upper_bound_value) ? CH_PE_prev_block : 0;
        //CID_reg = (curr_ref_length < upper_bound_value)?CI_PE_prev_block: 0;
    end*/

    //logic [REF_LEN_WIDTH-1:0] converged_idx;
    logic init_0_delayed;
    always @(posedge clk ) begin
        if(STATE==SET_PARAM)
            init_0_delayed<=0;
        else if(init_out[0])
            init_0_delayed<=1;
    end
    always_comb begin
        curr_ref_idx = $signed(ref_idx_in[NUM_PE - 1] - 3) > 0 ? (ref_idx_in[NUM_PE - 1] - 3) : 0; //last column idx
        //lb = lower_bound_value;
        //ub = upper_bound_value;
        tb_bram_addr_reg = (STATE==TB) ?  tb_bram_addr_out : tb_bram_addr;

        C1 = (curr_ref_idx >= total_ref_length - 1) ? 1: 0; // Hit Right boundary
        C2 = (curr_query_length >= total_query_length - 1) ? 1 :0; // Hit Botthom boundary
        C3 = (!not_last_droped_in_prev_block) &&init_0_delayed &&(rd_value+xdrop_value<ad_max_score); // Xdropped
        C4 = global_max_ad_idx>=convergence_detected_ad_idx; 
        C5 = this_ad_converged && (H_rd_value==H_rd_value_prev_ad) && past_marking&&H_converged_prev_ad ;
        // C1 = curr_ref_length >= tile_ref_length;
        // C2 = curr_query_length >= tile_query_length;
        // C3 = (($signed(curr_ref_length - NUM_PE) < 0) ? 0 : curr_ref_length - NUM_PE) >= total_ref_length;
        // C4 = curr_query_length >= total_query_length;
        
    end
    wire start_tb_from_xdrop;
    assign start_tb_from_xdrop=global_max_ad_idx<=(marker+2);
    always @(posedge clk ) begin
        if(rst)
            last_tile<=0;
        else if(STATE==TB&&start_tb_from_xdrop)
            last_tile<=1; 
    end
    wire convergence_detected;
    assign convergence_detected=C5&&(STATE==STREAM_REF)&&init_out[0]&&(!init_n || (!last_PE_not_droped))&&(!lower_bound_check);
    always @(posedge clk ) begin
        if(rst)
            conv<=0;
        else if(convergence_detected)
            conv<=1;
    end

    /*always @(posedge clk ) begin
        if(convergence_detected&&!conv)
            converged_idx<=H_rd_value;
    end*/
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
    always @(posedge clk ) begin
        if(rst)
            convergence_detected_ad_idx<=INF;
        else if (convergence_detected&&!conv)
            convergence_detected_ad_idx<=curr_ad_idx; 
    end
    always @(posedge clk ) begin
        if(set_param[0])
            tb_bram_start_sub_ref_start[block_count-2]<=tb_bram_addr-lower_bound_value+(NUM_PE);
    end

    // reference character ascii to nucleotide conversion
    ascii2nt ref_ascii2nt (         
        .ascii(ref_bram_data_out),
        .complement(complement_ref_in),
        .nt(ref_nt)
    );
    
    // query character ascii to nucleotide conversion
    ascii2nt query_ascii2nt (       
        .ascii(query_bram_data_out),
        .complement(complement_query_in),
        .nt(query_nt)
    );    
    
    nt2param #(
        .PE_WIDTH(PE_WIDTH)
    ) query_nt2param (
        .nt(query_nt),
        .in_param(in_param),
        .out_param(out_param)
    );

    assign param = out_param;
    assign {sub_A_in, sub_C_in, sub_G_in, sub_T_in} = query_oflow?{{4*PE_WIDTH}{1'b0}}:param;

    logic [REF_LEN_WIDTH+2+REF_LEN_WIDTH+QUERY_LEN_WIDTH-1:0]  max_val_to_sel[0:NUM_PE-1], selected_idx;
    genvar i;
    generate
        for (i = 0; i < NUM_PE; i = i + 1) 
        begin: pe_gen
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
            ) pe_affine (
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
                //.xdrop_value(xdrop_value),
                .INF(INF),

                .block(block),
                .diag_score(diag_delayed),
                .diag_CH_score(diag_CH_delayed),
                .start_idx(start_idx),
                .marker(marker),     
                .ref_idx_in(ref_idx_in[i]),
                .query_idx_in(query_idx_in[i]),
                //.global_max_score(ad_max_score),

                .D_init_in(D_init_in),
                .H_init_in(H_init),

                .H_PE_prev(H_PE_prev[i]),
                .I_PE_prev(I_PE_prev[i]),
                .CH_PE_prev(CH_PE_prev[i]),
                .CI_PE_prev(CI_PE_prev[i]),

                .init_out(init_out[i]),
                //.xdrop_flag(xdrop_flag[i]),
                .dir_out(dir_out[4*i + 3: 4*i]),
                .ref_out(ref_out[i]),
                
                .ref_idx_out(ref_idx_out[i]),
                .query_idx_out(query_idx_out[i]),

                .init_state(init_state),
                .H_PE(H_PE[i]),
                .I_PE(I_PE[i]),
                .D_PE(D_PE[i]),
                .CH_PE(CH_PE[i]),
                .CI_PE(CI_PE[i]),
                .CD_PE(CD_PE[i])

            );
            assign max_val_to_sel[i]={CH_PE[i],ref_idx_out[i],query_idx_out[i]};
        end
    endgenerate
    wire [REF_LEN_WIDTH+1:0] max_CH_val;
    wire [REF_LEN_WIDTH-1:0] cur_max_query_idx;
    wire [QUERY_LEN_WIDTH-1:0] cur_max_ref_idx;
    reduction_tree_max # (
        .PE_WIDTH(PE_WIDTH),
        .SEL_WIDTH(REF_LEN_WIDTH+2+REF_LEN_WIDTH+QUERY_LEN_WIDTH),
        .NUM_PE(NUM_PE),
        .LOG_NUM_PE(LOG_NUM_PE)
        ) rd_tree_max (
            .to_sel(max_val_to_sel),
            .array(H_PE),
            .reduction_value(rd_value),
            .selected(selected_idx)
    );
    assign {max_CH_val,cur_max_ref_idx,cur_max_query_idx}=selected_idx;
    reduction_tree_value # (
        .PE_WIDTH(REF_LEN_WIDTH + 2),
        .NUM_PE(NUM_PE),
        .LOG_NUM_PE(LOG_NUM_PE)
        ) rd_tree_M (
            .array(CH_PE),
            .reduction_value(H_rd_value),
            .reduction_bool(H_converged_this_block)
    );

    reduction_tree_value # (
        .PE_WIDTH(REF_LEN_WIDTH + 2),
        .NUM_PE(NUM_PE),
        .LOG_NUM_PE(LOG_NUM_PE)
        ) rd_tree_I (
            .array(CI_PE),
            .reduction_value(I_rd_value),
            .reduction_bool(I_converged)
    );

    reduction_tree_value # (
        .PE_WIDTH(REF_LEN_WIDTH + 2),
        .NUM_PE(NUM_PE),
        .LOG_NUM_PE(LOG_NUM_PE)
        ) rd_tree_D (
            .array(CD_PE),
            .reduction_value(D_rd_value),
            .reduction_bool(D_converged)
    );

    
    assign query_next_tile_addr=start_tb_from_xdrop?global_max_query_idx:conv_query_idx;
    assign ref_next_tile_addr=start_tb_from_xdrop?global_max_ref_idx:conv_ref_idx;
    assign next_tile_init_state=start_tb_from_xdrop?0:conv_tb_state;
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
        ) tb (
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
            .first_tile(init_state==3),
            .tb_done(tb_done)
        );

    
    wire tb_bram_wr_en_next;
    logic was_stream_ref;
    always @(posedge clk ) begin
        if(rst)
            was_stream_ref<=0;
        else
            was_stream_ref<= (STATE==STREAM_REF);
    end
    assign tb_bram_wr_en_next=init_out[0]&&(was_stream_ref||(STATE==STREAM_REF))&&(!past_marking);
    
    always @(posedge clk ) begin
        if(rst)
            tb_bram_wr_en<=0;
        else 
            tb_bram_wr_en<=tb_bram_wr_en_next;
    end

    wire [TB_ADDR_WIDTH-1:0] tb_bram_wr_addr_next;
    assign tb_bram_wr_addr_next=tb_bram_wr_en_next?tb_bram_addr+1:tb_bram_addr;
    always @(posedge clk ) begin
        if(rst)
            tb_bram_addr<=-1;
        else
            tb_bram_addr<=tb_bram_wr_addr_next; 
    end

    generate
        for (i = 1; i < NUM_PE; i = i + 1)
        begin: systolic_array_connections
            assign init_in[i] = (STATE==STREAM_REF_CONTINUE)?0:init_out[i-1];
            assign ref_in[i]  = ref_out[i-1];
            assign ref_idx_in[i] = ref_idx_out[i-1];
            assign query_idx_in[i] = query_idx_out[i-1];
            assign H_PE_prev[i] = H_PE[i-1];
            assign I_PE_prev[i] = I_PE[i-1];
            assign CH_PE_prev[i] = CH_PE[i-1];
            assign CI_PE_prev[i] = CI_PE[i-1];
        end
    endgenerate

    always_ff @( posedge clk ) begin
        I_PE_prev[0]<=block? I_prev_block : -INF;
    end
    assign D_init_in = -INF;
    //assign H_init_in = H_init;
    assign init_in[0]=(STATE==STREAM_REF);
    
    wire [PE_WIDTH-1:0 ] boundary_init_H_score_next;
    assign boundary_init_H_score_next=H_init+gap_extend_in;
    always_ff @( posedge clk ) begin 
        if(STATE==STREAM_REF_START)
            H_init<=(block||init_state!=3)?-INF:gap_open_in;
        else if(STATE==STREAM_REF)
            H_init<=(block||init_state!=3)?-INF:boundary_init_H_score_next;
    end

    always_ff @( posedge clk ) begin
        if(STATE==STREAM_REF_START)
            H_PE_prev[0] <=  block ? H_prev_block : (init_state!=3?-INF:gap_open_in);
        else if(STATE==STREAM_REF)
            H_PE_prev[0] <=  block ? H_prev_block : (init_state!=3?-INF:boundary_init_H_score_next);
    end

    always_ff @( posedge clk) begin
        if(STATE==STREAM_REF||STATE==STREAM_REF_START)
            CH_PE_prev[0]<= block? CH_PE_prev_block:CONV_DONT_CARE;
    end

    always_ff @( posedge clk) begin
        if(STATE==STREAM_REF||STATE==STREAM_REF_START)
            CI_PE_prev[0]<= block? CI_PE_prev_block:CONV_DONT_CARE;
    end
    
    always_comb begin
        cur_ad_max_score=rd_value;
        if(block&&not_last_droped_in_prev_block) begin
            if(ad_max_score_prev_block>cur_ad_max_score)
                cur_ad_max_score=ad_max_score_prev_block;
        end
    end
    assign ad_max_score_next=(cur_ad_max_score>ad_max_score)?cur_ad_max_score:ad_max_score;
    always_ff @( posedge clk ) begin
        if(rst||STATE==STREAM_REF_CONTINUE)
            ad_max_score<=0;
        else if(init_out[0])
            ad_max_score<=ad_max_score_next;
    end

    always_ff @(posedge clk) begin
        if (score_bram_rd_en) begin
            score_bram_addr_rd <= score_bram_addr_rd + 1;
        end else
            score_bram_addr_rd <=0;
    end

    assign ref_in[0] =ref_oflow?NU_DONT_CARE:ref_nt;
    always_ff @(posedge clk) begin : state_description
        if (rst) begin

            block <= 0;
            //init_0 <= 0;
            init_n <= 0;
            //init_in[0] <= 0;
            set_param <= 0;
            curr_query_length <= 0;
            curr_ref_length <= 0;

            // PE inital values

            //H_PE_prev_n <= 0;
            //I_PE_prev_n <= 0;
            //D_PE_prev_n <= 0;
            //CH_PE_prev[0] <= 0; 
            //CI_PE_prev[0] <= 0; 
            //CH_reg2 <= 0;
            //diag_score <= 0;

            start_idx <= 0;
            lower_bound_check <= 0;
            lower_bound_value <= 0;
            //upper_bound_value <= INF;
            block_count <= 0;

            // ref and query bram
            ref_bram_addr <= 0;
            query_bram_addr <= 0;

            // last column bram
            rstb <= 0;
            regceb <= 0;
            //score_bram_rd_en <= 0;
            //score_bram_addr_rd <= 0;
            score_bram_wr_en <= 0;
            //score_bram_addr_wr <= 0;

            // tb bram
            tb_bram_data_in <= 0;

            global_max_score <= 0;
            global_max_ad_idx<=0;

            query_idx_in[0] <= 0;
            ref_idx_in[0] <= 0;

            tb_start <= 0;

        end
        
        else begin
            regceb <= 1;
            init_n <= init_out[NUM_PE - 2] & init_out[0];
            //CH_reg2 <= CH_reg;
            tb_bram_data_in <= dir_out;
            //H_PE_prev_n <= H_PE[NUM_PE - 1];
            //I_PE_prev_n <= I_PE[NUM_PE - 1];
            //D_PE_prev_n <= D_PE[NUM_PE - 1];
            
            case (STATE)
                WAIT: begin
                end

                READ_PARAM: begin
                    sub_N_in        <= in_param[3*PE_WIDTH-1-:PE_WIDTH];
                    gap_open_in     <= in_param[2*PE_WIDTH-1-:PE_WIDTH];
                    gap_extend_in   <= in_param[PE_WIDTH-1:0];

                    ref_bram_addr <= 0;
                    query_bram_addr <= 0;

                    //lower_bound[block_count] <= 0;
                    //upper_bound[block_count] <= 0;
                    block_count <= block_count + 1;
                    
                end 
                

                SET_PARAM: begin

                    if (!set_param) begin
                        set_param <= 1;
                     // Incr query idx passed to PE[0] 
                    end
                    else begin
                        set_param <= set_param << 1;
                    end
                    // Increment Query idx
                        query_bram_addr <= query_bram_addr + 1; 
                        curr_query_length <= curr_query_length + 1;

                    // handling last column score matrix Read (1 cycle here and 1 cycle in next state)
                    /*if (block && set_param[NUM_PE - 4]) begin
                        score_bram_rd_en <= 1;
                    end*/
                end

                STREAM_REF_START: begin
                    // Set initial values for PE
                    set_param <= 0;
                    //init_0 <= 1;
                    
                    lower_bound_check <= 0;
                    
                    /*if (score_bram_rd_en == 1) begin
                        score_bram_addr_rd <= score_bram_addr_rd + 1;
                    end*/
                    curr_ref_length <= curr_ref_length + 1; //Incr curr ref length
                    ref_bram_addr <= ref_bram_addr + 1; //Incr curr ref bram addr
                    ref_idx_in[0] <= ref_idx_in[0] + 1; // Incr ref idx passed to PE[0]
                end

                STREAM_REF: begin
                    
                    curr_ref_length <= curr_ref_length + 1; //Incr curr ref length
                    ref_bram_addr <= ref_bram_addr + 1; //Incr curr ref bram addr
                    ref_idx_in[0] <= ref_idx_in[0] + 1; // Incr ref idx passed to PE[0] 
                    

                    // if ref boundary is hit (total_ref_length + NUM_PE) move to STREAM_REF_CONTINUE


                    // update lower bound for next block if not updated yet
                    if (!lower_bound_check && init_n && last_PE_not_droped) begin
                        lower_bound_check <= 1; 
                        lower_bound_value <= curr_ref_idx; 
                        //lower_bound[block_count] <= curr_ref_idx;
                    end                             


                    // update upper bound for next block when xdrop_flag == -1
                    if (init_n) begin
                        //if ($signed(xdrop_flag) == -1) begin
                            //upper_bound_value <= curr_ref_idx; 
                            //upper_bound[block_count] <= curr_ref_idx;
                        //end
                    end
                    
                    //CH_PE_prev[0] <= block ? ((curr_ref_length < upper_bound_value) ? (CH_PE_prev_block): -INF) : -INF;
                    //CI_PE_prev[0] <= block ? ((curr_ref_length < upper_bound_value) ? (CI_PE_prev_block): -INF) : -INF;

                    // Handling maximum score
                    if ($signed(global_max_score) <= $signed(rd_value)) begin
                        global_max_score <= rd_value;
                        global_max_ref_idx <= cur_max_ref_idx-1;
                        global_max_query_idx <= cur_max_query_idx-1;
                        global_max_ad_idx<=curr_ad_idx;
                        global_max_conv_idx<=max_CH_val;
                    end


                    /*if (score_bram_rd_en == 1) begin
                        score_bram_addr_rd <= score_bram_addr_rd + 1;
                    end*/
                    
                    // handling last column score matrix: Write
                    if (init_n) begin
                        if (!score_bram_wr_en && !lower_bound_check && last_PE_not_droped) begin
                            score_bram_wr_en <= 1;
                            //diag_score <= {H_PE[NUM_PE - 1], I_PE[NUM_PE - 1], D_PE[NUM_PE - 1]};
                        end
                        /*if (score_bram_wr_en) begin
                            score_bram_addr_wr <= score_bram_addr_wr + 1;
                        end*/
                    end

                end

                STREAM_REF_CONTINUE: begin
                    //init_0 <= 0;
                    block <= 1; 
                    start_idx <= lower_bound_value;
                    ref_bram_addr<=lower_bound_value;
                    ref_idx_in[0] <= lower_bound_value;
                    curr_ref_length <= lower_bound_value;
                    query_idx_in[0] <= curr_query_length;
                    block_count <= block_count + 1;
                    score_bram_wr_en <= 0;
                    //score_bram_rd_en <= 0;
                    //score_bram_addr_wr <= 0;
                    //score_bram_addr_rd <= 0;  
                end

                STREAM_REF_STOP: begin
                    // Check for starting point of traceback
                end

                STREAM_REF_DONE: begin
                    // Load more data
                end

                DONE: begin
                    
                end

                TB: begin
                    tb_start <= 1;
                end

                EXIT: begin
                end

            endcase
            
        end
    end
    wire load_new_seq;
    assign load_new_seq=(STATE==STREAM_REF_START)&&block_count;
    assign stop=tb_done;
    always_ff @(posedge clk) begin : state_machine
        if (rst) 
            STATE <= WAIT;
        
        else begin
            case (STATE)
                WAIT: begin
                    if (start) begin
			    STATE <= READ_PARAM;
                    end
                end

                READ_PARAM: begin
                    STATE <= SET_PARAM;
                end 

                SET_PARAM: begin
                    // Increment Query idx
                    if (set_param[NUM_PE - 2])
                        STATE <= STREAM_REF_START;
                end

                STREAM_REF_START: begin
                    // Set initial values for PE
                    STATE <= STREAM_REF;
                end

                STREAM_REF: begin
                    if(C4)
                        STATE<=DONE;
                    else if ( (ref_oflow&& ref_in[NUM_PE-1]==NU_DONT_CARE) ||C3) begin
                        STATE <= (lower_bound_check&&!query_oflow)?STREAM_REF_CONTINUE:DONE; // If hit total reference boundary or Xdrop flag == -1
                    end
                                        
                    else begin
                        STATE <= STREAM_REF;
                    end

                end

                STREAM_REF_CONTINUE: begin
		    STATE <= SET_PARAM;
                end

                STREAM_REF_STOP: begin
                    STATE <= EXIT;
                end

                STREAM_REF_DONE: begin
                    
                end


                DONE: begin
                    // Ready to check convergence and start traceback
                    STATE <= DONE2;
                end

		DONE2:STATE<=TB;

                TB: begin
                    if (tb_done == 1) begin
                        STATE <= EXIT;
                    end
                    
                end

                EXIT: begin
                end

            endcase
        end        

    end    
    assign commit=STATE==SET_PARAM;
    assign traceback=STATE==TB||STATE==WAIT||STATE==EXIT;
endmodule

module sft_reg#(parameter BW = 10, DEPTH=10) (input clk, en, input [BW-1:0] in, output [BW-1:0] out);
    logic [BW-1:0] content[DEPTH-1:0];
    int idx;
    always_ff @( posedge clk ) begin
        if(en) begin
            content[0]<=in;
            for (idx = 1; idx<DEPTH; idx++) begin
                content[idx]<=content[idx-1];
            end
        end
    end
    assign out=content[DEPTH-1];
endmodule

module sft_w_rst#(DEPTH=10) (input clk, input en, input rst, input in, output out);
    logic [DEPTH-1:0] data;
    always @(posedge clk ) begin
        if(rst)
            data<=0;
        else if(en)
            if(DEPTH>1)
                data<={data[DEPTH-2:0],in};
            else
                data<=in; 
    end
    assign out=data[DEPTH-1];
endmodule
