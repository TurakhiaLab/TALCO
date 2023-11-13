module topTb ();
    parameter FILE= "../../../dataset/sequences.fa"
    parameter NUM_EXTEND = 8;
    parameter MAX_WAVEFRONT_LEN = 128;
	parameter LOG_MAX_WAVEFRONT_LEN = 8;
    parameter DATA_WIDTH = 8;
    parameter BLOCK_WIDTH = 8;
    parameter MAX_TILE_SIZE = 1024;
    parameter LOG_MAX_TILE_SIZE = 10;
    parameter REF_LEN_WIDTH = 14;
    parameter QUERY_LEN_WIDTH = 14;   
	parameter REF_LEN = 1024;
    parameter QUERY_LEN = 1024;
    parameter NUM_BLOCK = DATA_WIDTH/BLOCK_WIDTH;
	parameter ADDR_WIDTH = 10;
	parameter NUM_COMPUTE = 10;

    logic clk;
    logic rst;
    logic [DATA_WIDTH - 1: 0] globalKmin;
    logic [DATA_WIDTH - 1: 0] globalKmax;
    logic loadData;
    logic [DATA_WIDTH - 1: 0] queryData;
    logic [DATA_WIDTH - 1: 0] refData;
	logic  [LOG_MAX_TILE_SIZE - 1: 0] queryAdr;
    logic  [LOG_MAX_TILE_SIZE - 1: 0] refAdr;
    logic start;
	logic [REF_LEN_WIDTH - 1: 0] refLen;
    logic [QUERY_LEN_WIDTH - 1: 0] queryLen;
	logic valid_M_s_minus_2_in [MAX_WAVEFRONT_LEN - 1: 0];
	logic valid_M_s_minus_1_in [MAX_WAVEFRONT_LEN - 1: 0];
	logic valid_I_s_minus_1_in [MAX_WAVEFRONT_LEN - 1: 0];
	logic valid_D_s_minus_1_in [MAX_WAVEFRONT_LEN - 1: 0];
	logic [LOG_MAX_WAVEFRONT_LEN - 1:0] marker;
    logic [1:0] compact_cigar [MAX_WAVEFRONT_LEN-1:0];
	logic stop;

    logic  [DATA_WIDTH - 1: 0] queryMem [0: (QUERY_LEN/NUM_BLOCK) - 1];
    logic  [DATA_WIDTH - 1: 0] refMem [0: (REF_LEN/NUM_BLOCK) - 1];
    
    int i;
    int fd;
    string r, q;
    string r0, q0;
    logic read;
    logic [31: 0] ref_, query_;
    // Todo make it bigger than 10k
    logic   [15: 0] curr_ref_addr, curr_query_addr;
    logic   [15: 0] start_ref_addr, start_query_addr;

    TALCO_WFAA #(
        .NUM_EXTEND(NUM_EXTEND),
        .MAX_WAVEFRONT_LEN(MAX_WAVEFRONT_LEN),
        .DATA_WIDTH(DATA_WIDTH),
        .BLOCK_WIDTH(BLOCK_WIDTH),
        .MAX_TILE_SIZE(MAX_TILE_SIZE),
        .LOG_MAX_TILE_SIZE(LOG_MAX_TILE_SIZE),
        .REF_LEN_WIDTH(REF_LEN_WIDTH),
        .QUERY_LEN_WIDTH(QUERY_LEN_WIDTH),
		.ADDR_WIDTH(ADDR_WIDTH),
		.NUM_COMPUTE(NUM_COMPUTE)
    ) TALCO_WFAA (
        .*
    );

    
    integer i;

    always #5 clk = ~clk;


    initial 
    begin
        clk = 0;
        rst = 1;
        start = 0;
        loadData = 0;
		
        fd = $fopen(FILE, "r");
        if (!fd) begin
            $display("Could not read the sequences\n");
            $finish;
        end

        while (!$feof(fd)) begin
            $fgets(r0, fd); r0 = r0.substr(0, r0.len() - 2);
            $fgets(r, fd); r = r.substr(0, r.len() - 2);
            $fgets(q0, fd); q0 = q0.substr(0, q0.len() - 2);
            $fgets(q, fd); q = q.substr(0, q.len() - 2);
            
            #10ns;
            refLen = r.len();
            queryLen = q.len();
            globalKmin = 0;
            globalKmax = 0;
            queryAdr = 0;
            refAdr = 0;
            
            marker = 10;

            for (i=0; i < (REF_LEN/NUM_BLOCK); i = i + 1) begin
                refMem[i] = r[i];
            end

            for (i=0; i < (QUERY_LEN/NUM_BLOCK); i = i + 1) begin
                queryMem[i] = q[i];
            end

            #10;
            rst = 0;
            loadData = 1;

            wait(stop);

        end
    end

    always @(posedge clk) 
    begin

        if (loadData)
        begin
            if (queryAdr < QUERY_LEN/NUM_BLOCK)
            begin
                queryData = queryMem[queryAdr];
                queryAdr += 1;
            end

            if (refAdr < REF_LEN/NUM_BLOCK)
            begin
                refData = refMem[refAdr];
                refAdr += 1;
            end

            if ((refAdr + 1 == REF_LEN/NUM_BLOCK) && (queryAdr + 1 == QUERY_LEN/NUM_BLOCK))
            begin
                loadData = 0;
                start = 1;
            end
        end
    end

endmodule