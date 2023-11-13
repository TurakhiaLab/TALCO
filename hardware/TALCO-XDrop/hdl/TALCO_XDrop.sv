module TALCO_XDrop #(
    parameter PE_WIDTH = 16,
    parameter DATA_WIDTH = 8,
    parameter NUM_BLOCK  = 1,
    parameter BLOCK_WIDTH = DATA_WIDTH/NUM_BLOCK,
    parameter NUM_PE = 8,
    parameter LOG_NUM_PE = $clog2(NUM_PE),
    parameter MAX_TILE_SIZE = 512,
    parameter LOG_MAX_TILE_SIZE = $clog2(MAX_TILE_SIZE),
    parameter REF_LEN_WIDTH = 16,
    parameter QUERY_LEN_WIDTH = 16,
    parameter PARAM_ADDR_WIDTH = 8,
    parameter CONV_SCORE_WIDTH = 1 +1 + 2*(REF_LEN_WIDTH + 2) + 3*PE_WIDTH,
    parameter TB_DATA_WIDTH = 4*NUM_PE, // I(1). D(1). M(2)
    parameter TB_ADDR_WIDTH = $clog2(2*(MAX_TILE_SIZE/NUM_PE)*MAX_TILE_SIZE)

)(
    input  clk,
    input  rst,
    input  start,

    input  [14*PE_WIDTH - 1: 0] in_param,
    input  [REF_LEN_WIDTH - 1:0] total_ref_length,
    input  [QUERY_LEN_WIDTH - 1:0] total_query_length,
    
    input  ref_wr_en,
    input  complement_ref_in,
    input  [31:0] ref_bram_data_in,
    input  [(LOG_MAX_TILE_SIZE/NUM_BLOCK) - 3: 0] ref_addr_in,

    input  query_wr_en,
    input  complement_query_in,
    input  [31:0] query_bram_data_in,
    input  [(LOG_MAX_TILE_SIZE/NUM_BLOCK) - 3: 0] query_addr_in,

    output  last_tile,
    input [1:0] init_state,
    input  [PE_WIDTH - 1: 0] INF,
    input  [LOG_MAX_TILE_SIZE: 0] marker,
    input [1:0] query_start_offset,
    input [1:0] ref_start_offset,
    
    output logic [QUERY_LEN_WIDTH-1:0] query_next_tile_addr,
    output logic [QUERY_LEN_WIDTH-1:0] query_rd_ptr,
    output logic [REF_LEN_WIDTH-1:0] ref_next_tile_addr,
    output logic [REF_LEN_WIDTH-1:0] ref_rd_ptr,
    output logic [1:0] next_tile_init_state,
    output [1: 0] tb_pointer,
    output tb_valid,
    output commit,traceback,
    output stop
);

    logic [DATA_WIDTH - 1:0]                      ref_bram_data_out; 
    logic [(LOG_MAX_TILE_SIZE/NUM_BLOCK): 0]  ref_bram_addr, ref_actual_rd_addr;
    assign ref_actual_rd_addr=ref_bram_addr+ref_start_offset;
    assign ref_rd_ptr=ref_actual_rd_addr[LOG_MAX_TILE_SIZE:2];
    //wire [31:0] ref_temp,query_temp;
    asym_ram_sdp_write_wider #(
        .SIZEA(1<<((LOG_MAX_TILE_SIZE/NUM_BLOCK)-2)),
        .WIDTHA(4*DATA_WIDTH),
        .WIDTHB(DATA_WIDTH)
    ) ref_bram (
       .addrA(ref_addr_in),
       .addrB(ref_actual_rd_addr),
       .diA(ref_bram_data_in),
       .clk(clk),
       .weA(ref_wr_en),
       .enaA(1),
       .enaB(1),
       .doB(ref_bram_data_out)
    );
    //assign ref_bram_data_out=ref_temp[8*ref_actual_rd_addr[1:0]+:8];
    logic [DATA_WIDTH - 1:0]                      query_bram_data_out; 
    logic [(LOG_MAX_TILE_SIZE/NUM_BLOCK): 0]  query_bram_addr,query_actual_rd_addr;
    assign query_actual_rd_addr=query_bram_addr+query_start_offset;
    assign query_rd_ptr=query_actual_rd_addr[LOG_MAX_TILE_SIZE:2];
    asym_ram_sdp_write_wider #(
        .SIZEA(1<<((LOG_MAX_TILE_SIZE/NUM_BLOCK)-2)),
        .WIDTHA(4*DATA_WIDTH),
        .WIDTHB(DATA_WIDTH)
    ) query_bram (
       .addrA(query_addr_in),
       .addrB(query_actual_rd_addr),
       .diA(query_bram_data_in),
       .clk(clk),
       .weA(query_wr_en),
       .enaA(1),
       .enaB(1),
       .doB(query_bram_data_out)
    );
    //assign query_bram_data_out=query_temp[8*query_actual_rd_addr[1:0]+:8];
    logic                               rstb;
    logic                               regceb;
    logic                               score_bram_wr_en;
    logic                               score_bram_rd_en;
    logic [LOG_MAX_TILE_SIZE - 1: 0]    score_bram_addr_wr;
    logic [LOG_MAX_TILE_SIZE - 1: 0]    score_bram_addr_rd;
    logic [CONV_SCORE_WIDTH - 1:0]      score_bram_data_in; 
    logic [CONV_SCORE_WIDTH - 1:0]      score_bram_data_out; 

    generate
    DPBram #(
      .RAM_WIDTH(CONV_SCORE_WIDTH), // M I D
      .RAM_DEPTH(MAX_TILE_SIZE),
      .RAM_PERFORMANCE(0)
    ) DPRam_instance (
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
    endgenerate
    
    logic                                    tb_bram_wr_en;
    logic [TB_DATA_WIDTH - 1: 0]             tb_bram_data_in;
    logic [TB_DATA_WIDTH - 1: 0]             tb_bram_data_out;
    logic [TB_ADDR_WIDTH-1: 0]         tb_bram_addr;


    BRAM_kernel #(
        .ADDR_WIDTH(TB_ADDR_WIDTH),
        .DATA_WIDTH(TB_DATA_WIDTH)
    ) tb_bram (
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
    ) pe_array (
        .clk(clk),
        .rst(rst),
        .start(start),

        .in_param(in_param),
        .total_ref_length(total_ref_length),
        .total_query_length(total_query_length),
        //.tile_ref_length(tile_ref_length),
        //.tile_query_length(tile_query_length),

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

        .INF({2'b00, {PE_WIDTH-2{1'b1}}}),
        .last_tile(last_tile),
        .marker(marker),
        .xdrop_value(in_param[13*PE_WIDTH+:PE_WIDTH]),
        .next_tile_init_state(next_tile_init_state),
        .tb_pointer(tb_pointer),
        .tb_valid(tb_valid),
        .commit(commit),
        .traceback(traceback),
        .stop(stop)

    );

    
endmodule