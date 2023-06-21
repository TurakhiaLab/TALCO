// Reference and Query characters are 1 indexed, but stored 0 indexed in bram 



module wrapper #(
    parameter NUM_EXTEND = 8,
	parameter LOG_NUM_EXTEND = $clog2(NUM_EXTEND),
    parameter EXTEND_LEN = 8,
    parameter LOG_EXTEND_LEN = $clog2(EXTEND_LEN),
	parameter TILE_SIZE = 512,
	parameter LOG_TILE_SIZE = $clog2(TILE_SIZE),
	parameter DATA_WIDTH = 16,
	parameter BLOCK_WIDTH = 8,
    parameter LOG_BLOCK_WIDTH = $clog2(BLOCK_WIDTH),
    parameter TB_ADDR = 10,
    parameter FIFO_WIDTH = 2*LOG_TILE_SIZE + TB_ADDR + 1 + 1 // {is_extend, k, offset, tbAddr}
) (
    input   logic   clk,
    input   logic   rst,
    dbram_wr_ifc.slave  rwr_ifc,
    dbram_wr_ifc.slave  qwr_ifc,
    input   logic   load,
    input   logic   start,

    output  logic   done
);
    enum {WAIT, LOAD_DATA, DUMY, ALIGN, TB, DONE} state;
    
    // fifo
    fifo_rd_wr_ifc #(.DEPTH(8), .DATA_WIDTH(NUM_EXTEND * FIFO_WIDTH)) fifo_ifc ();

    //Extend
    logic	[NUM_EXTEND - 1: 0]	is_finish;


    // // WFA registers
    // logic   [LOG_TILE_SIZE: 0] kmin;
    // logic   [LOG_TILE_SIZE: 0] kmax;
    // logic   extend_on;

    // assign ref_addr = STATE == LOAD_DATA ? rwaddr: 0;
    // assign query_addr = STATE == LOAD_DATA ? qwaddr: 0;


    always_ff @(posedge clk) begin
        if (rst) begin

        end
        else begin
            case (state)
                WAIT: begin
                    
                end 
                LOAD_DATA: begin
                    
                end
                DUMY: begin
                    fifo_ifc.fifo_din <= {1'b1,239'b0};
                    fifo_ifc.fifo_wen <= 1;
                end
                ALIGN: begin
                    fifo_ifc.fifo_wen <= 0;
                    fifo_ifc.fifo_ren <= (!fifo_ifc.fifo_empty) & (&is_finish);
                end
            endcase
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            state <= WAIT;
        end
        else begin
            case (state)
                WAIT: begin
                    if(load) begin
                        state <= LOAD_DATA;
                        
                    end
                end 
                LOAD_DATA: begin
                    if (start) begin
                        state <= DUMY;
                    end
                end
                DUMY: begin
                    state <= ALIGN;
                end
                ALIGN: begin
                    
                end
            endcase
        end
    end

    

    generate
        extend_array #(
            .NUM_EXTEND(NUM_EXTEND),
            .EXTEND_LEN(EXTEND_LEN),
            .TILE_SIZE(TILE_SIZE),
            .DATA_WIDTH(DATA_WIDTH),
            .BLOCK_WIDTH(BLOCK_WIDTH),
            .TB_ADDR(TB_ADDR),
            .FIFO_WIDTH(FIFO_WIDTH)
        ) extend_array_instance (
            .clk(clk),
            .rst(rst),
            .rwr_ifc(rwr_ifc),
            .qwr_ifc(qwr_ifc),
            .fifo_ifc(fifo_ifc),
            // .on(extend_on),
            // .kmin(kmin),
            // .kmax(kmax),
            // .rin(),
            // .qin(),
            // .done()
            .is_finish(is_finish),
            .load(state==LOAD_DATA)
        );
    endgenerate


endmodule