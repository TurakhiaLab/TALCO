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

interface ext2red_ifc #(parameter
    FIFO_WIDTH = 30,
    NUM_EXTEND = 8
);
    logic   [FIFO_WIDTH* NUM_EXTEND - 1: 0] offset;
    logic   [NUM_EXTEND - 1: 0] valid; // if &valid == 1, excute reduce unit
    logic   read; //if read by reduce = 1, else 0;

    modport master (input offset, valid, read);
    modport slave (output offset, valid, read);
    
endinterface //ext2red

interface global_ifc #( parameter
    TILE_SIZE = 512,
    LOG_TILE_SIZE = $clog2(TILE_SIZE)
);

    logic   [LOG_TILE_SIZE: 0] kmin;
    logic   [LOG_TILE_SIZE: 0] kmax;
    logic   [15: 0] ref_end_cord;
    logic   [15: 0] query_end_cord;
    logic   [15:0] drop;
    logic   [15: 0] score;

    modport master (input kmin, kmax, ref_end_cord, query_end_cord, drop, score);
    modport slave (output kmin, kmax, ref_end_cord, query_end_cord, drop, score);
    
endinterface //global_ifc 