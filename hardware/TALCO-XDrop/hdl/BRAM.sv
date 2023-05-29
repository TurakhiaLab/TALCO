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