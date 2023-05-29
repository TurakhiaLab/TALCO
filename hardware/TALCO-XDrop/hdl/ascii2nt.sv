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