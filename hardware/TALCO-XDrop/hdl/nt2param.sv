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