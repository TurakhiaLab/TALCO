`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 25.05.2023 11:41:57
// Design Name: 
// Module Name: tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module tb();
    parameter FILE= "../../../dataset/sequences.fa"
    parameter PE_WIDTH = 16;
    parameter DATA_WIDTH = 8;
    parameter NUM_BLOCK  = 1;
    parameter NUM_PE = 16;
    parameter MAX_TILE_SIZE = 512;
    parameter REF_LEN_WIDTH = 16;
    parameter QUERY_LEN_WIDTH = 16;
    parameter PARAM_ADDR_WIDTH = 8;

    parameter BLOCK_WIDTH = DATA_WIDTH/NUM_BLOCK;
    parameter LOG_NUM_PE = $clog2(NUM_PE);
    parameter LOG_MAX_TILE_SIZE = $clog2(MAX_TILE_SIZE);
    parameter CONV_SCORE_WIDTH = 1 +1 + 2*(REF_LEN_WIDTH + 2) + 3*PE_WIDTH;
    parameter TB_DATA_WIDTH = 4*NUM_PE; // I(1). D(1). M(2)
    parameter TB_ADDR_WIDTH = $clog2(2*(MAX_TILE_SIZE/NUM_PE)*MAX_TILE_SIZE);

    logic   clk;
    logic   rst;
    logic   start;

    logic   [14*PE_WIDTH - 1: 0] in_param;
    logic   [REF_LEN_WIDTH - 1:0] total_ref_length;
    logic   [QUERY_LEN_WIDTH - 1:0] total_query_length;
    
    logic   ref_wr_en;
    logic   complement_ref_in;
    logic   [31:0] ref_bram_data_in;
    logic   [(LOG_MAX_TILE_SIZE/NUM_BLOCK) - 3: 0] ref_addr_in;

    logic   query_wr_en;
    logic   complement_query_in;
    logic   [31:0] query_bram_data_in;
    logic   [(LOG_MAX_TILE_SIZE/NUM_BLOCK) - 3: 0] query_addr_in;

    logic   last_tile;
    logic   [1:0] init_state;
    logic   [PE_WIDTH - 1: 0] INF;
    logic   [LOG_MAX_TILE_SIZE: 0] marker;
    logic   [1:0] query_start_offset;
    logic   [1:0] ref_start_offset;
    
    logic   [QUERY_LEN_WIDTH-1:0] query_next_tile_addr;
    logic   [QUERY_LEN_WIDTH-1:0] query_rd_ptr;
    logic   [REF_LEN_WIDTH-1:0] ref_next_tile_addr;
    logic   [REF_LEN_WIDTH-1:0] ref_rd_ptr;
    logic   [1:0] next_tile_init_state;
    logic   [1: 0] tb_pointer;
    logic   tb_valid;
    logic   commit;
    logic   traceback;
    logic   stop;

    int i;
    int fd;
    string r, q;
    string r0, q0;
    logic read;
    logic [31: 0] ref_, query_;
    // Todo make it bigger than 10k
    logic   [15: 0] curr_ref_addr, curr_query_addr;
    logic   [15: 0] start_ref_addr, start_query_addr;

    TALCO_XDrop #(
        .PE_WIDTH(PE_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .NUM_BLOCK(NUM_BLOCK),
        .BLOCK_WIDTH(BLOCK_WIDTH),
        .NUM_PE(NUM_PE),
        .LOG_NUM_PE(LOG_NUM_PE),
        .MAX_TILE_SIZE(MAX_TILE_SIZE),
        .LOG_MAX_TILE_SIZE(LOG_MAX_TILE_SIZE),
        .REF_LEN_WIDTH(REF_LEN_WIDTH),
        .QUERY_LEN_WIDTH(QUERY_LEN_WIDTH),
        .PARAM_ADDR_WIDTH(PARAM_ADDR_WIDTH),
        .CONV_SCORE_WIDTH(CONV_SCORE_WIDTH),
        .TB_DATA_WIDTH(TB_DATA_WIDTH),
        .TB_ADDR_WIDTH(TB_ADDR_WIDTH)
    ) talco_xdrop_instance (
        .clk(clk),          
        .rst(rst),          
        .start(start),

        .in_param(in_param),         
        .total_ref_length(total_ref_length),     
        .total_query_length(total_query_length),
        
        .ref_wr_en(ref_wr_en),
        .ref_addr_in(ref_addr_in),
        .ref_bram_data_in(ref_bram_data_in),
        .complement_ref_in(complement_ref_in),

        .query_wr_en(query_wr_en),
        .query_addr_in(query_addr_in),
        .query_bram_data_in(query_bram_data_in),
        .complement_query_in(complement_query_in),
        
        
        .last_tile(last_tile),
        .init_state(init_state),
        .INF(INF),
        .marker(marker),
        .query_start_offset(query_start_offset),
        .ref_start_offset(ref_start_offset),

        .query_next_tile_addr(query_next_tile_addr),
        .query_rd_ptr(query_rd_ptr),
        .ref_next_tile_addr(ref_next_tile_addr),
        .ref_rd_ptr(ref_rd_ptr),
        .next_tile_init_state(next_tile_init_state),
        .tb_pointer(tb_pointer),
        .tb_valid(tb_valid),
        .commit(commit),
        .traceback(traceback),
        .stop(stop)    
    );

    always begin
        #5ns clk = !clk;
    end


    initial begin
        
        clk = 0;
        rst = 1;
        start = 0;
        
        in_param = 0;
        total_ref_length = 0;     
        total_query_length = 0;
        
        ref_wr_en = 0;
        ref_addr_in = 0;
        ref_bram_data_in = 0;
        complement_ref_in = 0;
        
        query_wr_en = 0;
        query_addr_in = 0;
        query_bram_data_in = 0;
        complement_query_in = 0;

        init_state = 0;
        INF = 0;
        marker = 0;        
        query_start_offset = 0;
        ref_start_offset = 0;

        ref_=0; query_=0; read = 0; curr_ref_addr = 0; curr_query_addr = 0;
        start_ref_addr = 0; start_query_addr = 0;
        
        fd = $fopen(FILE, "r");
        if (!fd) begin
            $display("Could not read the sequences\n");
            $finish;
        end

        while (!$feof(fd)) begin
            $fgets(r0, fd); r0 = r0.substr(0, r0.len() - 2);
            $fgets(r, fd); r = r.substr(0, r.len() - 2);
            $fgets(q0, fd); q0 = q0.substr(0, q0.len() - 2);
            $fgets(q, fd); q = q.substr(0, q.len() - 2);
            #10ns;
            rst = 0;
            start = 0;
            total_ref_length = r.len();
            total_query_length = q.len();
            in_param = 'h00640002FFFEFFFEFFFE0002FFFEFFFE0002FFFE0002FFFDFFFFFFFF;
            INF = 1000;
            marker = 506;
            init_state = 3;
            ref_start_offset = 0;
            query_start_offset = 0;

            while(1) begin
                i = 0;
                while (1) begin
                    #10ns;
                    ref_wr_en = 1;
                    query_wr_en = 1;
                    if (curr_ref_addr != start_ref_addr) begin
                        ref_addr_in += 1;
                    end
                    if (curr_query_addr != start_query_addr) begin
                        query_addr_in += 1;
                    end
                    if (curr_ref_addr < start_ref_addr + marker/4) begin 
                        ref_bram_data_in = (((r[i + 3]<<24) | (r[i + 2]<<16)) | (r[i + 1]<<8)) | r[i + 0];
                        curr_ref_addr += 1;
                    end
                    if (curr_query_addr < start_query_addr + marker/4) begin
                        query_bram_data_in = (((q[i + 3]<<24) | (q[i + 2]<<16)) | (q[i + 1]<<8)) | q[i + 0];
                        curr_query_addr += 1;
                    end
                    if ((curr_ref_addr >= start_ref_addr + marker/4) && (curr_query_addr >= start_query_addr + marker/4)) begin
                        break;
                    end
                    i+=4;
                end

                #10; 
                start = 1; ref_wr_en = 0; query_wr_en = 0;
                wait(stop);
                #10;
                start = 0; 
                rst = 1;
                #10;
                rst = 0;
                ref_addr_in = 0;
                query_addr_in = 0;
                curr_ref_addr += ref_next_tile_addr;
                curr_query_addr += query_next_tile_addr;
                start_ref_addr += ref_next_tile_addr;
                start_query_addr += query_next_tile_addr;
                init_state = next_tile_init_state;
                
            end
            break;
            

        end
        $finish;


    end


endmodule


