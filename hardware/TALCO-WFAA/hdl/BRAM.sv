module BRAM #(
  parameter ADDR_WIDTH = 8,
  parameter DATA_WIDTH = 16
)
(
  input     logic                       clk,
  input     logic   [ADDR_WIDTH - 1:0]  addr,
  input     logic                       writeEn,
  input     logic   [DATA_WIDTH - 1:0]  dataIn,
  
  output    logic   [DATA_WIDTH - 1:0]  dataOut
  );

  logic [DATA_WIDTH - 1:0]    mem [0:2**ADDR_WIDTH-1];

  always_ff@(posedge clk) begin
      if (writeEn == 1)
          mem[addr] <= dataIn; //WR
      dataOut <= mem[addr]; //RD
  end
endmodule: BRAM
