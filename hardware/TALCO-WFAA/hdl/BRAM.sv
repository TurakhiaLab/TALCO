module BRAM #(
  parameter ADDR_WIDTH = 8,
  parameter DATA_WIDTH = 16
)
(
  input     logic                       clk,
  input     logic   [ADDR_WIDTH - 1:0]  addr,
  input     logic                       wen,
  input     logic   [DATA_WIDTH - 1:0]  din,
  
  output    logic   [DATA_WIDTH - 1:0]  dout
  );

  logic [DATA_WIDTH - 1:0]    mem [0:2**ADDR_WIDTH-1];

  always_ff@(posedge clk) begin
      if (wen == 1)
          mem[addr] <= din;
      dout <= mem[addr];
  end
endmodule: BRAM