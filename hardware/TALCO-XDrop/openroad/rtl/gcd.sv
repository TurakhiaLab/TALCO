`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12.07.2022 12:51:50
// Design Name: 
// Module Name: ascii2nt
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


// Converting ASCII characters to Nucleotide bases
// Input one character among A,G,C,T,N (8 bits long) and convert it into "nt" with 4 bits. 
// Complement acts as a flag, if on, each nt is converted into its complement
// output: only 3 bits are required, different from GACTX
module ascii2nt (
    input [7:0] ascii,
    input complement,
    output logic [2:0] nt
    );

    localparam A=1, C=2, G=3, T=4, N=0;

    always_comb begin
        case ({ascii})
            8'h61 : nt = (complement) ? T : A; //8h'61 - ASCII for a 
            8'h41 : nt = (complement) ? T : A; //8h'41 - ASCII for A 
            8'h63 : nt = (complement) ? G : C; //8h'63 - ASCII for c 
            8'h43 : nt = (complement) ? G : C; //8h'43 - ASCII for C 
            8'h67 : nt = (complement) ? C : G; //8h'67 - ASCII for g 
            8'h47 : nt = (complement) ? C : G; //8h'47 - ASCII for G 
            8'h74 : nt = (complement) ? A : T; //8h'74 - ASCII for t 
            8'h54 : nt = (complement) ? A : T; //8h'54 - ASCII for T
            8'h6e : nt = N;
            8'h4e : nt = N;
            default : nt = N;
        endcase
    end
endmodule: ascii2nt
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 28.06.2022 10:33:15
// Design Name: 
// Module Name: BRAM
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


module BRAM_kernel #(
  parameter ADDR_WIDTH = 8,
  parameter DATA_WIDTH = 16
)
(
  input     logic                     clk,
  input     logic   [ADDR_WIDTH-1:0]  addr,
  input     logic                     write_en,
  input     logic   [DATA_WIDTH-1:0]  data_in,
  output    logic   [DATA_WIDTH-1:0]  data_out
  );

  (* ram_style = "ultra" *) logic [DATA_WIDTH - 1:0]    mem [0:2**ADDR_WIDTH-1];

  always_ff@(posedge clk) begin
      if (write_en == 1)
          mem[addr] <= data_in;
      data_out <= mem[addr];
  end
endmodule: BRAM_kernel
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01.09.2022 12:47:34
// Design Name: 
// Module Name: DPBram
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

//  Xilinx Simple Dual Port Single Clock RAM
//  This code implements a parameterizable SDP single clock memory.
//  If a reset or enable is not necessary, it may be tied off or removed from the code.

module DPBram #(
  parameter RAM_WIDTH = 64,                       // Specify RAM data width
  parameter RAM_DEPTH = 512,                      // Specify RAM depth (number of entries)
  parameter RAM_PERFORMANCE = 1 // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
//  parameter INIT_FILE = ""                        // Specify name/location of RAM initialization file if using one (leave blank if not)
) (
  input [$clog2(RAM_DEPTH-1)-1:0] addra, // Write address bus, width determined from RAM_DEPTH
  input [$clog2(RAM_DEPTH-1)-1:0] addrb, // Read address bus, width determined from RAM_DEPTH
  input [RAM_WIDTH-1:0] dina,          // RAM input data
  input clka,                          // Clock
  input wea,                           // Write enable
  input enb,                           // Read Enable, for additional power savings, disable when not in use
  input rstb,                          // Output reset (does not affect memory contents)
  input regceb,                        // Output register enable
  output [RAM_WIDTH-1:0] doutb         // RAM output data
);

  reg [RAM_WIDTH-1:0] BRAM [0:RAM_DEPTH-1];
  reg [RAM_WIDTH-1:0] ram_data = {RAM_WIDTH{1'b0}};

  // The following code either initializes the memory values to a specified file or to all zeros to match hardware
//  generate
//    if (INIT_FILE != "") begin: use_init_file
//      initial
//        $readmemh(INIT_FILE, BRAM, 0, RAM_DEPTH-1);
//    end else begin: init_bram_to_zero
//      integer ram_index;
//      initial
//        for (ram_index = 0; ram_index < RAM_DEPTH; ram_index = ram_index + 1)
//          BRAM[ram_index] = {RAM_WIDTH{1'b0}};
//    end
//  endgenerate

  always @(posedge clka) begin
    if (wea)
      BRAM[addra] <= dina;
    if (enb)
      ram_data <= BRAM[addrb];
  end

  //  The following code generates HIGH_PERFORMANCE (use output register) or LOW_LATENCY (no output register)
  generate
    if (RAM_PERFORMANCE == 0) begin: no_output_register

      // The following is a 1 clock cycle read latency at the cost of a longer clock-to-out timing
       assign doutb = ram_data;

    end else begin: output_register

      // The following is a 2 clock cycle read latency with improve clock-to-out timing

      reg [RAM_WIDTH-1:0] doutb_reg = {RAM_WIDTH{1'b0}};

      always @(posedge clka)
        if (rstb)
          doutb_reg <= {RAM_WIDTH{1'b0}};
        else if (regceb)
          doutb_reg <= ram_data;

      assign doutb = doutb_reg;

    end
  endgenerate

endmodule

module asym_ram_sdp_write_wider (clk, weA, enaA, enaB, addrA, addrB, diA, doB);

parameter WIDTHB = 8;

parameter WIDTHA = 32;

parameter SIZEA = 256;

localparam ADDRWIDTHA = $clog2(SIZEA);

localparam SIZEB = SIZEA*WIDTHA/WIDTHB;

localparam ADDRWIDTHB = $clog2(SIZEB);

input clk;


input weA;

input enaA, enaB;

input [ADDRWIDTHA-1:0] addrA;

input [ADDRWIDTHB-1:0] addrB;

input [WIDTHA-1:0] diA;

output [WIDTHB-1:0] doB;

`define max(a,b) {(a) > (b) ? (a) : (b)}

`define min(a,b) {(a) < (b) ? (a) : (b)}

localparam maxSIZE = `max(SIZEA, SIZEB);

localparam maxWIDTH = `max(WIDTHA, WIDTHB);

localparam minWIDTH = `min(WIDTHA, WIDTHB);

localparam RATIO = maxWIDTH / minWIDTH;

localparam log2RATIO = $clog2(RATIO);

reg [minWIDTH-1:0] RAM [0:maxSIZE-1];

reg [WIDTHB-1:0] readB;

always @(posedge clk) begin

if (enaB) begin

readB <= RAM[addrB];

end

end

assign doB = readB;

always @(posedge clk)

begin : ramwrite

integer i;

reg [log2RATIO-1:0] lsbaddr;

for (i=0; i< RATIO; i= i+ 1) begin : write1

lsbaddr = i;

if (enaA) begin

if (weA)

RAM[{addrA, lsbaddr}] <= diA[(i+1)*minWIDTH-1 -: minWIDTH];

end

end

end

endmodule 
// The following is an instantiation template for xilinx_simple_dual_port_1_clock_ram
/*
//  Xilinx Simple Dual Port Single Clock RAM
  xilinx_simple_dual_port_1_clock_ram #(
    .RAM_WIDTH(18),                       // Specify RAM data width
    .RAM_DEPTH(1024),                     // Specify RAM depth (number of entries)
    .RAM_PERFORMANCE("HIGH_PERFORMANCE"), // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
    .INIT_FILE("")                        // Specify name/location of RAM initialization file if using one (leave blank if not)
  ) your_instance_name (
    .addra(addra),   // Write address bus, width determined from RAM_DEPTH
    .addrb(addrb),   // Read address bus, width determined from RAM_DEPTH
    .dina(dina),     // RAM input data, width determined from RAM_WIDTH
    .clka(clka),     // Clock
    .wea(wea),       // Write enable
    .enb(enb),	     // Read Enable, for additional power savings, disable when not in use
    .rstb(rstb),     // Output reset (does not affect memory contents)
    .regceb(regceb), // Output register enable
    .doutb(doutb)    // RAM output data, width determined from RAM_WIDTH
  );
*/
						
						
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12.07.2022 12:56:40
// Design Name: 
// Module Name: nt2param
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

//Convert nt bases to the parameters from the W matrix
//
//for each nucleotide x that belongs to [A,C,G,T], we store x->y substutin cost from W matrix where y belongs to [A,C,G,T].
// plus substition cost to N, gap_open, and gap extend penalties.  

//    | A  | C  | G  | T
// A  | 13 | 12 | 11 | 10
// C  | 12 | 9  | 8  | 7
// G  | 11 | 8  | 6  | 5
// T  | 10 | 7  | 5  | 4
// sub_N - 3
// Gap_open - 2
// Gap_extend - 1
// (numbers) represent the element index of in-param 

// Input in_param: in_params = {  sub_AA[PE_WIDTH-1:0],
//                                sub_AC[PE_WIDTH-1:0],
//                                sub_AG[PE_WIDTH-1:0],
//                                sub_AT[PE_WIDTH-1:0],
//                                sub_CC[PE_WIDTH-1:0],
//                                sub_CG[PE_WIDTH-1:0],
//                                sub_CT[PE_WIDTH-1:0],
//                                sub_GG[PE_WIDTH-1:0],
//                                sub_GT[PE_WIDTH-1:0],
//                                sub_TT[PE_WIDTH-1:0],
//                                sub_N[PE_WIDTH-1:0],
//                                gap_open[PE_WIDTH-1:0],
//                                gap_extend[PE_WIDTH-1:0] /// From BSW_kernel_control

// PE_width = no of bits assigned to store values (each W cell value could be floating point number)
// input nt: only 3 bits are required, different from GACTX

module nt2param #(
    parameter PE_WIDTH=16
    )(   
        input [2:0] nt,
        input [13*PE_WIDTH-1:0] in_param,
        output logic [4*PE_WIDTH-1:0] out_param
    );

    localparam A=1, C=2, G=3, T=4, N=0;

    always_comb begin
        case ({nt})
            A : out_param = {in_param[13*PE_WIDTH-1:9*PE_WIDTH]};
            C : out_param = {in_param[12*PE_WIDTH-1:11*PE_WIDTH], in_param[9*PE_WIDTH-1:6*PE_WIDTH]};
            G : out_param = {in_param[11*PE_WIDTH-1:10*PE_WIDTH], in_param[8*PE_WIDTH-1:7*PE_WIDTH], in_param[6*PE_WIDTH-1:4*PE_WIDTH]};
            T : out_param = {in_param[10*PE_WIDTH-1:9*PE_WIDTH], in_param[7*PE_WIDTH-1:6*PE_WIDTH], in_param[5*PE_WIDTH-1:3*PE_WIDTH]};
            N : out_param = {in_param[3*PE_WIDTH-1:2*PE_WIDTH], in_param[3*PE_WIDTH-1:2*PE_WIDTH], in_param[3*PE_WIDTH-1:2*PE_WIDTH], in_param[3*PE_WIDTH-1:2*PE_WIDTH]};
            default : out_param = {{(4*PE_WIDTH){1'b0}}};
        endcase
    end

endmodule: nt2param
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
module PE #(
    parameter PE_WIDTH          = 16,
    parameter DATA_WIDTH        = 16,
    parameter NUM_BLOCK         = 4,
    parameter NUM_PE            = 4,
    parameter LOG_NUM_PE        = $clog2(NUM_PE),
    parameter REF_LEN_WIDTH     = 10,
    parameter QUERY_LEN_WIDTH   = 10,
    parameter PE_IDX            = 0,
    parameter LOG_MAX_TILE_SIZE =10
) (
    input   logic   clk,
    input   logic   rst,
    input   logic   init_in,
    input   logic   set_param,

    input param_valid_in,
    input   logic [2: 0]            ref_in,
    input   logic [PE_WIDTH - 1: 0] sub_A_in,
    input   logic [PE_WIDTH - 1: 0] sub_C_in,
    input   logic [PE_WIDTH - 1: 0] sub_G_in,
    input   logic [PE_WIDTH - 1: 0] sub_T_in,
    input   logic [PE_WIDTH - 1: 0] sub_N_in,
    input   logic [PE_WIDTH - 1: 0] gap_open_in,
    input   logic [PE_WIDTH - 1: 0] gap_extend_in,
    //input   logic signed [PE_WIDTH - 1: 0] xdrop_value,
    input   logic signed [PE_WIDTH - 1: 0] INF,

    input   logic block,
    input [1:0] init_state,
    input   logic signed [PE_WIDTH - 1: 0]         diag_score,
    input   logic [REF_LEN_WIDTH - 1: 0]    start_idx,
    input   logic [LOG_MAX_TILE_SIZE : 0]    marker,     
    input   logic [REF_LEN_WIDTH - 1: 0]    ref_idx_in,
    input   logic [QUERY_LEN_WIDTH - 1: 0]  query_idx_in,
    //input   logic signed [PE_WIDTH - 1: 0]         global_max_score,

    input   logic [PE_WIDTH - 1: 0]         D_init_in,
    input   logic [PE_WIDTH - 1: 0]         H_init_in,

    input   logic signed [PE_WIDTH - 1: 0]         H_PE_prev,
    input   logic signed [PE_WIDTH - 1: 0]         I_PE_prev,
    input   logic [REF_LEN_WIDTH  + 1: 0]   CH_PE_prev,
    input   logic [REF_LEN_WIDTH  + 1: 0]   CI_PE_prev,diag_CH_score,

    output  logic           init_out,
    //output  logic           xdrop_flag,
    output  logic [3: 0]    dir_out,
    output  logic [2: 0]    ref_out,
    
    output  logic [REF_LEN_WIDTH - 1: 0]    ref_idx_out,
    output  logic [QUERY_LEN_WIDTH - 1: 0]  query_idx_out,

    output   logic signed [PE_WIDTH - 1: 0]         H_PE,
    output   logic signed [PE_WIDTH - 1: 0]         I_PE,
    output   logic signed [PE_WIDTH - 1: 0]         D_PE,
    output   logic [REF_LEN_WIDTH  + 1: 0]   CH_PE,
    output   logic [REF_LEN_WIDTH  + 1: 0]   CI_PE,
    output   logic [REF_LEN_WIDTH  + 1: 0]   CD_PE
);

    // localparam VERI=0, VERH=1, HORD=2, HORH=3, DIAG=4;
    localparam VER = 2, HOR = 1, DIAG = 0;
    localparam CONV_DONT_CARE=0;
    localparam NU_DONT_CARE=5;
    // dir          tb
    // ??00        Diagonal   H
    // ?001        Horizontal H
    // ?101        Horizontal D
    // 0?10        Vertical   H
    // 1?10        Vertical   I

    logic signed [PE_WIDTH - 1: 0]  sub_A;
    logic signed [PE_WIDTH - 1: 0]  sub_C;
    logic signed [PE_WIDTH - 1: 0]  sub_G;
    logic signed [PE_WIDTH - 1: 0]  sub_T;
    logic signed [PE_WIDTH - 1: 0]  sub_N;
    logic signed [PE_WIDTH - 1: 0]  gap_open;
    logic signed [PE_WIDTH - 1: 0]  gap_extend;
    logic signed [PE_WIDTH - 1: 0]  match_reward;
    logic param_valid;
    //logic xdrop_flag_reg;
    logic [REF_LEN_WIDTH - 1: 0]    ref_idx;
    logic [QUERY_LEN_WIDTH - 1: 0]  query_idx;

    always_comb begin : match_reward_calculation
        case ({ref_in}) 
            3'b111  : match_reward = sub_N;
            3'b001  : match_reward = sub_A;
            3'b010  : match_reward = sub_C;
            3'b011  : match_reward = sub_G;
            3'b100  : match_reward = sub_T;
            default : match_reward = 0;
        endcase
    end

    

    logic signed [PE_WIDTH - 1: 0] HV_score;
    logic signed [PE_WIDTH - 1: 0] IV_score;
    logic signed [PE_WIDTH - 1: 0] I_score;

    logic signed [PE_WIDTH - 1: 0] HH_score;
    logic signed [PE_WIDTH - 1: 0] DH_score;
    logic signed [PE_WIDTH - 1: 0] D_prev;
    logic signed [PE_WIDTH - 1: 0] H_prev;
    logic signed [PE_WIDTH - 1: 0] D_score;

    logic signed [PE_WIDTH - 1: 0] HD_score;
    logic signed [PE_WIDTH - 1: 0] H_score;

    logic signed [PE_WIDTH - 1: 0] H_PE_prev_reg;
    logic signed [PE_WIDTH - 1: 0] H_PE_prev2_reg;
    logic signed [PE_WIDTH - 1: 0] H_prev_reg;
    logic signed [PE_WIDTH - 1: 0] I_PE_prev_reg;
    logic signed [PE_WIDTH - 1: 0] D_prev_reg;
    logic signed [PE_WIDTH - 1: 0] H_PE_prev2;

    logic [REF_LEN_WIDTH  + 1: 0] CH_score;
    logic [REF_LEN_WIDTH  + 1: 0] CI_score;
    logic [REF_LEN_WIDTH  + 1: 0] CD_score;
    logic [REF_LEN_WIDTH  + 1: 0] CH_score_reg;
    logic [REF_LEN_WIDTH  + 1: 0] CH_score_reg2;
    logic [REF_LEN_WIDTH  + 1: 0] CD_score_reg;
    
    //logic [PE_WIDTH - 1: 0] D_init;
    

    logic [3: 0]    dir;
    logic [1:0] H_flag;
    logic D_flag;
    logic I_flag;



    always_comb begin: boundary_conditions
        if (!query_idx && !ref_idx)
            H_PE_prev2_reg = 0;
        else
            H_PE_prev2_reg = H_PE_prev2;

        H_PE_prev_reg  = H_PE_prev;
        I_PE_prev_reg  = I_PE_prev;

        if (!init_out&&init_in) begin
            H_prev_reg = H_init_in;
            D_prev_reg = D_init_in;
        end
        else begin
            H_prev_reg = H_prev;
            D_prev_reg = D_prev;
        end
    end

    always_comb begin : score_calculation
        // I (i,j) calculation
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

        // D (i,j) calculation
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
        // H (i,j) calculation
        HD_score = H_PE_prev2_reg + match_reward;
        H_score = HD_score;
        dir[1:0] = DIAG;
        if(D_score>H_score) begin
            H_score = D_score;
            dir[1:0] = HOR;
        end
        if(I_score>H_score) begin
            H_score = I_score;
            dir[1:0] = VER;
        end

        if (I_flag) begin
            dir[3] = 1;
        end
        else begin
            dir[3] = 0;
        end

        if (D_flag) begin
            dir[2] = 1;
        end
        else begin
            dir[2] = 0;
        end
        if(PE_IDX==0&&!block&&init_state!=3&&!init_out) begin
            H_score=init_state==0?0:-INF;
            I_score=init_state==2?0:-INF;
            D_score=init_state==1?0:-INF;
        end
        if(ref_in==NU_DONT_CARE) begin
            H_score=-INF;
        end
    end

    /*always_comb begin : xdrop
        if ($signed(H_score) + $signed(xdrop_value) < $signed(global_max_score)) 
            xdrop_flag_reg = 1;
        else
            xdrop_flag_reg = 0;
    end*/

    always_comb begin : convergence_logic
        if (ref_idx + query_idx == marker - 1) begin
            CH_score = {ref_idx, 2'b11};
            CI_score = {ref_idx, 2'b11}; // not required
            CD_score = {ref_idx, 2'b11}; // not required
        end

        else if (ref_idx + query_idx == marker) begin
            CH_score = {ref_idx, 2'b00};
            CI_score = {ref_idx, 2'b01};
            CD_score = {ref_idx, 2'b10}; 
        end

        else begin
            if (I_flag) begin
                CI_score = CI_PE_prev;
            end
            else begin
                CI_score = CH_PE_prev;
            end

            if (D_flag) begin
                CD_score = CD_score_reg;
            end
            else begin
                CD_score = CH_score_reg;
            end
            
            casex (dir)
                4'b??00 : CH_score = CH_score_reg2;
                4'b?001 : CH_score = CH_score_reg;
                4'b?101 : CH_score = CD_score_reg;
                4'b0?10 : CH_score = CH_PE_prev;
                4'b1?10 : CH_score = CI_PE_prev;
                default: CH_score = CH_score_reg2;
            endcase
        end
        
        if(ref_in==NU_DONT_CARE) begin
            CH_score=CONV_DONT_CARE;
            CD_score=CONV_DONT_CARE;
            CI_score=CONV_DONT_CARE;
        end
    end
    
    assign query_idx = query_idx_in;

    always_ff @ (posedge clk) begin
        if(rst)
            ref_out <= 0;
        else
            ref_out <= ref_in;
    end
    always_ff @ (posedge clk) begin
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

            //D_init <= 0;

            ref_idx <= 0;
            // query_idx <= 0;


            // outputs
            init_out <= 0;
            ref_idx_out <= 0;
            query_idx_out <= 0;
            I_PE <= -INF;
            H_PE <= -INF;  
            D_PE <= -INF;  
            CH_PE <= 0;
            CI_PE <= 0;
            CD_PE <= 0;
            //xdrop_flag <= 0;  
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
            H_PE<=-INF;
            param_valid<=param_valid_in;
        end

        else if(param_valid) begin
            //D_init <= D_init_in;
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
                //xdrop_flag <= xdrop_flag_reg;

            end

            else begin
                //xdrop_flag <= 0;
                //H_PE_prev2 <= (start_idx == 0) ? (block ? -query_idx_in + (gap_open - gap_extend): H_init_in): diag_score;
                H_PE_prev2 <= block ?  (PE_IDX?-INF:diag_score): H_init_in;
                CH_score_reg2 <= block ?  (PE_IDX?CONV_DONT_CARE:diag_CH_score): CONV_DONT_CARE;
                H_prev <= -INF;
                D_prev <= -INF;
                CH_score_reg<=CONV_DONT_CARE;
                CD_score_reg<=CONV_DONT_CARE;
                CH_PE <= CONV_DONT_CARE;
                CI_PE <= CONV_DONT_CARE;
                CD_PE <= CONV_DONT_CARE;
            end
        end

    end

    
endmodule
module reduction_tree_max #(
        parameter PE_WIDTH = 16,
        parameter SEL_WIDTH = 16,
        parameter NUM_PE = 4,
        parameter LOG_NUM_PE = 2
    )(
        input   logic [SEL_WIDTH - 1: 0] to_sel [0: NUM_PE - 1],
        input   logic signed [PE_WIDTH - 1: 0] array [0: NUM_PE - 1],
        output  logic signed [PE_WIDTH - 1: 0] reduction_value,
        output  logic [LOG_NUM_PE - 1: 0] idx,
        output logic [SEL_WIDTH - 1: 0] selected
    );
    
    logic local_stop;
    
    genvar i,j;
    generate
        for ( j = 0; j < LOG_NUM_PE; j = j + 1 ) begin: rt_level
            for ( i = 0; i < 2**(LOG_NUM_PE - j - 1); i = i + 1 ) begin: rt_iter
                logic signed [PE_WIDTH - 1: 0] value1;
                logic signed [PE_WIDTH - 1: 0] value2;
                logic signed [SEL_WIDTH - 1: 0] sel_value1;
                logic signed [SEL_WIDTH - 1: 0] sel_value2;
                logic signed [SEL_WIDTH - 1: 0] selected_val;
                logic signed [PE_WIDTH - 1: 0] out;
                logic [LOG_NUM_PE - 1: 0] idx1;
                logic [LOG_NUM_PE - 1: 0] idx2;
                logic [LOG_NUM_PE - 1: 0] max_idx;

                if(j == 0) begin
                    assign value1 = array[ i * 2 ];
                    assign value2 = array[ i * 2 + 1 ];
                    assign sel_value1=to_sel[ i*2 ];
                    assign sel_value2=to_sel[ i*2 +1 ];
                    assign idx1 = i * 2;
                    assign idx2 = i * 2 + 1;
                end
                else begin
                    assign value1 = rt_level[ j - 1 ].rt_iter[ i * 2 ].out;
                    assign value2 = rt_level[ j - 1 ].rt_iter[ i * 2 + 1 ].out;
                    assign sel_value1 = rt_level[ j - 1 ].rt_iter[ i * 2 ].selected_val;
                    assign sel_value2 = rt_level[ j - 1 ].rt_iter[ i * 2 + 1 ].selected_val;
                    assign idx1 = rt_level[ j - 1 ].rt_iter[ i * 2 ].max_idx;
                    assign idx2 = rt_level[ j - 1 ].rt_iter[ i * 2 + 1 ].max_idx;
                end
                assign selected_val=($signed(value1) > $signed(value2)) ? sel_value1:sel_value2;
                assign out = ($signed(value1) > $signed(value2)) ? value1 :value2;
                assign max_idx = ($signed(value1) > $signed(value2)) ? idx1 :idx2;
            end
        end
        assign reduction_value = rt_level[LOG_NUM_PE - 1].rt_iter[0].out;
        assign idx = rt_level[LOG_NUM_PE - 1].rt_iter[0].max_idx;
        assign selected= rt_level[LOG_NUM_PE - 1].rt_iter[0].selected_val;
    endgenerate
endmodule
           
module reduction_tree_value #(
        parameter PE_WIDTH = 16,
        parameter NUM_PE = 4,
        parameter LOG_NUM_PE = 2
    )(
        input   logic [PE_WIDTH - 1: 0] array [0: NUM_PE - 1],
        output  logic [PE_WIDTH - 1: 0] reduction_value,
        output logic reduction_bool
    );
    
    logic local_stop;
    parameter CONV_DONT_CARE=0;
    
    genvar i,j;
    generate
        for ( j = 0; j < LOG_NUM_PE; j = j + 1 ) begin: rt_level
            for ( i = 0; i < 2**(LOG_NUM_PE - j - 1); i = i + 1 ) begin: rt_iter
                logic [PE_WIDTH - 1: 0] value0;
                logic [PE_WIDTH - 1: 0] value1;
                logic [PE_WIDTH - 1: 0] value2;
                logic bool0;
                logic bool1;
                logic bool2;

                if(j == 0) begin
                    assign value1 = array[ i * 2 ];
                    assign value2 = array[ i * 2 + 1 ];
                    assign bool1 = 1'b1;
                    assign bool2 = 1'b1;
                end
                else begin
                    assign value1 = rt_level[ j - 1 ].rt_iter[ i * 2 ].value0;
                    assign value2 = rt_level[ j - 1 ].rt_iter[ i * 2 + 1 ].value0;
                    assign bool1  = rt_level[ j - 1 ].rt_iter[ i * 2 ].bool0;
                    assign bool2  = rt_level[ j - 1 ].rt_iter[ i * 2 + 1 ].bool0;
                end

                wire dontcare1=value1==CONV_DONT_CARE;
                wire dontcare2=value2==CONV_DONT_CARE;
                assign value0 = dontcare1?value2:value1; // choose either value1 or value2
                assign bool0=(dontcare1||dontcare2||value1==value2)&&bool1&&bool2;
            end
        end
        assign reduction_bool  = rt_level[LOG_NUM_PE - 1].rt_iter[0].bool0;
        assign reduction_value = rt_level[LOG_NUM_PE - 1].rt_iter[0].value0;
    endgenerate
endmodule


//            for ( j = LOG_NUM_PE - 1; j <= 0; j = j - 1 ) begin: rt_level_up
//                logic [LOG_NUM_PE - 1: 0] local_i;
//                if (j == LOG_NUM_PE - 1) begin
//                    assign local_i = 2*0 + 1;
//                end
//                else begin  
//                    logic value1;
//                    logic value2;
                    
//                    assign value1 = rt_level[j].rt_iter[rt_level_up[j-1].local_i - 0].out;
//                    assign value2 = rt_level[j].rt_iter[rt_level_up[j-1].local_i - 1].out;
                    
//                    if (value1) assign local_i = 2*(rt_level_up[j-1].local_i) + 1;
//                    else assign local_i = 2*(rt_level_up[j-1].local_i - 1) + 1;
                    
//                end
//            end
            
//            if (stop == 1) 
//                assign reduction_value = rt_level_up[0].local_i;
            
//            else
//                assign reduction_value = 0;
module gcd #(
    parameter PE_WIDTH = 16,
    parameter DATA_WIDTH = 8,
    parameter NUM_BLOCK  = 1,
    parameter BLOCK_WIDTH = DATA_WIDTH/NUM_BLOCK,
    parameter NUM_PE = 16,
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
