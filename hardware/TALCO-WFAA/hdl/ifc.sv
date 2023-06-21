interface dbram_wr_ifc #(parameter
    DATA_WIDTH = 8,
    ADDR_WIDTH = 16
);

    logic   wen;
    logic   [DATA_WIDTH - 1: 0] din;
    logic   [ADDR_WIDTH - 1: 0] addr;

    modport master  (output wen, din, addr);
    modport slave   (input wen, din, addr);
    
endinterface //dbram_wr_ifc


interface fifo_rd_wr_ifc #(parameter
    DEPTH = 8,
    DATA_WIDTH = 16
);

    logic   fifo_wen;
    logic   fifo_ren;
    logic   fifo_full;
    logic   fifo_empty;
    logic   [DATA_WIDTH - 1: 0] fifo_din;
    logic   [DATA_WIDTH - 1: 0] fifo_dout;

    modport master   (input fifo_empty, fifo_full, output fifo_wen, fifo_ren, fifo_din);
    modport slave  (output fifo_empty, fifo_full, input fifo_wen, fifo_ren, fifo_din);
    
endinterface //dbram_wr_ifc
