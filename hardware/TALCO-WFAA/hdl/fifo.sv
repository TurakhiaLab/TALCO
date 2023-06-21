module fifo #(
    parameter DATA_WIDTH = 8,
    parameter DEPTH = 32,
    parameter LOG_DEPTH = $clog2(DEPTH)
)(
    input   logic   clk,
    input   logic   rst,
    input   logic   wen,
    input   logic   ren,
    input   logic   [DATA_WIDTH - 1: 0] din,
    output  logic   [DATA_WIDTH - 1: 0] dout,
    output  logic   full,
    output  logic   empty
);

    logic   [LOG_DEPTH: 0]  raddr;
    logic   [LOG_DEPTH: 0]  waddr;

    logic   [DATA_WIDTH - 1: 0] fifo    [DEPTH];

    always_ff @(posedge clk) begin: addrs
        if (rst) begin
            raddr <= 0;
            waddr <= 0;
        end
    end

    always_ff @(posedge clk) begin: write 
        if (wen && !full) begin
            fifo[waddr] <= din;
            waddr <= waddr + 1;
        end
    end

    always_ff @(posedge clk) begin: read
        if (ren && !empty) begin
            dout <= fifo[raddr];
            raddr <= raddr + 1;
        end
    end

    assign empty = (waddr == raddr);
    assign full  = (waddr[LOG_DEPTH - 1: 0] == raddr[LOG_DEPTH - 1: 0]) && (waddr[LOG_DEPTH] != raddr[LOG_DEPTH]);
    
endmodule : fifo