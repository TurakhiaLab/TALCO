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
						
						