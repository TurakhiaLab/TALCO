module PE #(
    parameter PE_WIDTH          = 16,
    parameter DATA_WIDTH        = 16,
    parameter NUM_BLOCK         = 4,
    parameter NUM_PE            = 4,
    parameter LOG_NUM_PE        = $clog2(NUM_PE),
    parameter REF_LEN_WIDTH     = 10,
    parameter QUERY_LEN_WIDTH   = 10,
    parameter PE_IDX            = 0,
    parameter LOG_MAX_TILE_SIZE =10
) (
    input   logic   clk,
    input   logic   rst,
    input   logic   init_in,
    input   logic   set_param,

    input param_valid_in,
    input   logic [2: 0]            ref_in,
    input   logic [PE_WIDTH - 1: 0] sub_A_in,
    input   logic [PE_WIDTH - 1: 0] sub_C_in,
    input   logic [PE_WIDTH - 1: 0] sub_G_in,
    input   logic [PE_WIDTH - 1: 0] sub_T_in,
    input   logic [PE_WIDTH - 1: 0] sub_N_in,
    input   logic [PE_WIDTH - 1: 0] gap_open_in,
    input   logic [PE_WIDTH - 1: 0] gap_extend_in,
    //input   logic signed [PE_WIDTH - 1: 0] xdrop_value,
    input   logic signed [PE_WIDTH - 1: 0] INF,

    input   logic block,
    input [1:0] init_state,
    input   logic signed [PE_WIDTH - 1: 0]         diag_score,
    input   logic [REF_LEN_WIDTH - 1: 0]    start_idx,
    input   logic [LOG_MAX_TILE_SIZE : 0]    marker,     
    input   logic [REF_LEN_WIDTH - 1: 0]    ref_idx_in,
    input   logic [QUERY_LEN_WIDTH - 1: 0]  query_idx_in,
    //input   logic signed [PE_WIDTH - 1: 0]         global_max_score,

    input   logic [PE_WIDTH - 1: 0]         D_init_in,
    input   logic [PE_WIDTH - 1: 0]         H_init_in,

    input   logic signed [PE_WIDTH - 1: 0]         H_PE_prev,
    input   logic signed [PE_WIDTH - 1: 0]         I_PE_prev,
    input   logic [REF_LEN_WIDTH  + 1: 0]   CH_PE_prev,
    input   logic [REF_LEN_WIDTH  + 1: 0]   CI_PE_prev,diag_CH_score,

    output  logic           init_out,
    //output  logic           xdrop_flag,
    output  logic [3: 0]    dir_out,
    output  logic [2: 0]    ref_out,
    
    output  logic [REF_LEN_WIDTH - 1: 0]    ref_idx_out,
    output  logic [QUERY_LEN_WIDTH - 1: 0]  query_idx_out,

    output   logic signed [PE_WIDTH - 1: 0]         H_PE,
    output   logic signed [PE_WIDTH - 1: 0]         I_PE,
    output   logic signed [PE_WIDTH - 1: 0]         D_PE,
    output   logic [REF_LEN_WIDTH  + 1: 0]   CH_PE,
    output   logic [REF_LEN_WIDTH  + 1: 0]   CI_PE,
    output   logic [REF_LEN_WIDTH  + 1: 0]   CD_PE
);

    // localparam VERI=0, VERH=1, HORD=2, HORH=3, DIAG=4;
    localparam VER = 2, HOR = 1, DIAG = 0;
    localparam CONV_DONT_CARE=0;
    localparam NU_DONT_CARE=5;
    // dir          tb
    // ??00        Diagonal   H
    // ?001        Horizontal H
    // ?101        Horizontal D
    // 0?10        Vertical   H
    // 1?10        Vertical   I

    logic signed [PE_WIDTH - 1: 0]  sub_A;
    logic signed [PE_WIDTH - 1: 0]  sub_C;
    logic signed [PE_WIDTH - 1: 0]  sub_G;
    logic signed [PE_WIDTH - 1: 0]  sub_T;
    logic signed [PE_WIDTH - 1: 0]  sub_N;
    logic signed [PE_WIDTH - 1: 0]  gap_open;
    logic signed [PE_WIDTH - 1: 0]  gap_extend;
    logic signed [PE_WIDTH - 1: 0]  match_reward;
    logic param_valid;
    //logic xdrop_flag_reg;
    logic [REF_LEN_WIDTH - 1: 0]    ref_idx;
    logic [QUERY_LEN_WIDTH - 1: 0]  query_idx;

    always_comb begin : match_reward_calculation
        case ({ref_in}) 
            3'b111  : match_reward = sub_N;
            3'b001  : match_reward = sub_A;
            3'b010  : match_reward = sub_C;
            3'b011  : match_reward = sub_G;
            3'b100  : match_reward = sub_T;
            default : match_reward = 0;
        endcase
    end

    

    logic signed [PE_WIDTH - 1: 0] HV_score;
    logic signed [PE_WIDTH - 1: 0] IV_score;
    logic signed [PE_WIDTH - 1: 0] I_score;

    logic signed [PE_WIDTH - 1: 0] HH_score;
    logic signed [PE_WIDTH - 1: 0] DH_score;
    logic signed [PE_WIDTH - 1: 0] D_prev;
    logic signed [PE_WIDTH - 1: 0] H_prev;
    logic signed [PE_WIDTH - 1: 0] D_score;

    logic signed [PE_WIDTH - 1: 0] HD_score;
    logic signed [PE_WIDTH - 1: 0] H_score;

    logic signed [PE_WIDTH - 1: 0] H_PE_prev_reg;
    logic signed [PE_WIDTH - 1: 0] H_PE_prev2_reg;
    logic signed [PE_WIDTH - 1: 0] H_prev_reg;
    logic signed [PE_WIDTH - 1: 0] I_PE_prev_reg;
    logic signed [PE_WIDTH - 1: 0] D_prev_reg;
    logic signed [PE_WIDTH - 1: 0] H_PE_prev2;

    logic [REF_LEN_WIDTH  + 1: 0] CH_score;
    logic [REF_LEN_WIDTH  + 1: 0] CI_score;
    logic [REF_LEN_WIDTH  + 1: 0] CD_score;
    logic [REF_LEN_WIDTH  + 1: 0] CH_score_reg;
    logic [REF_LEN_WIDTH  + 1: 0] CH_score_reg2;
    logic [REF_LEN_WIDTH  + 1: 0] CD_score_reg;
    
    //logic [PE_WIDTH - 1: 0] D_init;
    

    logic [3: 0]    dir;
    logic [1:0] H_flag;
    logic D_flag;
    logic I_flag;



    always_comb begin: boundary_conditions
        if (!query_idx && !ref_idx)
            H_PE_prev2_reg = 0;
        else
            H_PE_prev2_reg = H_PE_prev2;

        H_PE_prev_reg  = H_PE_prev;
        I_PE_prev_reg  = I_PE_prev;

        if (!init_out&&init_in) begin
            H_prev_reg = H_init_in;
            D_prev_reg = D_init_in;
        end
        else begin
            H_prev_reg = H_prev;
            D_prev_reg = D_prev;
        end
    end

    always_comb begin : score_calculation
        // I (i,j) calculation
        HV_score = H_PE_prev_reg + gap_open;
        IV_score = I_PE_prev_reg + gap_extend;
        if ($signed(HV_score) >= $signed(IV_score)) begin
            I_score = HV_score;
            I_flag = 0;
        end
        else begin
            I_score = IV_score;
            I_flag = 1; 
        end

        // D (i,j) calculation
        HH_score = H_prev_reg + gap_open;
        DH_score = D_prev_reg + gap_extend;
        if ($signed(HH_score) >= $signed(DH_score)) begin
            D_score = HH_score;
            D_flag = 0;
        end
        else begin
            D_score = DH_score;
            D_flag = 1; 
        end
        // H (i,j) calculation
        HD_score = H_PE_prev2_reg + match_reward;
        H_score = HD_score;
        dir[1:0] = DIAG;
        if(D_score>H_score) begin
            H_score = D_score;
            dir[1:0] = HOR;
        end
        if(I_score>H_score) begin
            H_score = I_score;
            dir[1:0] = VER;
        end

        if (I_flag) begin
            dir[3] = 1;
        end
        else begin
            dir[3] = 0;
        end

        if (D_flag) begin
            dir[2] = 1;
        end
        else begin
            dir[2] = 0;
        end
        if(PE_IDX==0&&!block&&init_state!=3&&!init_out) begin
            H_score=init_state==0?0:-INF;
            I_score=init_state==2?0:-INF;
            D_score=init_state==1?0:-INF;
        end
        if(ref_in==NU_DONT_CARE) begin
            H_score=-INF;
        end
    end

    /*always_comb begin : xdrop
        if ($signed(H_score) + $signed(xdrop_value) < $signed(global_max_score)) 
            xdrop_flag_reg = 1;
        else
            xdrop_flag_reg = 0;
    end*/

    always_comb begin : convergence_logic
        if (ref_idx + query_idx == marker - 1) begin
            CH_score = {ref_idx, 2'b11};
            CI_score = {ref_idx, 2'b11}; // not required
            CD_score = {ref_idx, 2'b11}; // not required
        end

        else if (ref_idx + query_idx == marker) begin
            CH_score = {ref_idx, 2'b00};
            CI_score = {ref_idx, 2'b01};
            CD_score = {ref_idx, 2'b10}; 
        end

        else begin
            if (I_flag) begin
                CI_score = CI_PE_prev;
            end
            else begin
                CI_score = CH_PE_prev;
            end

            if (D_flag) begin
                CD_score = CD_score_reg;
            end
            else begin
                CD_score = CH_score_reg;
            end
            
            casex (dir)
                4'b??00 : CH_score = CH_score_reg2;
                4'b?001 : CH_score = CH_score_reg;
                4'b?101 : CH_score = CD_score_reg;
                4'b0?10 : CH_score = CH_PE_prev;
                4'b1?10 : CH_score = CI_PE_prev;
                default: CH_score = CH_score_reg2;
            endcase
        end
        
        if(ref_in==NU_DONT_CARE) begin
            CH_score=CONV_DONT_CARE;
            CD_score=CONV_DONT_CARE;
            CI_score=CONV_DONT_CARE;
        end
    end
    
    assign query_idx = query_idx_in;

    always_ff @ (posedge clk) begin
        if(rst)
            ref_out <= 0;
        else
            ref_out <= ref_in;
    end
    always_ff @ (posedge clk) begin
        if (rst) begin
            sub_A <= 0;
            sub_C <= 0;
            sub_G <= 0;
            sub_T <= 0;
            sub_N <= 0;
            gap_open <= 0;
            gap_extend <= 0; 

            H_prev <= 0;
            D_prev <= 0;
            H_PE_prev2 <= 0;
            CH_score_reg <= 0;
            CD_score_reg <= 0;
            CH_score_reg2 <= 0;

            //D_init <= 0;

            ref_idx <= 0;
            // query_idx <= 0;


            // outputs
            init_out <= 0;
            ref_idx_out <= 0;
            query_idx_out <= 0;
            I_PE <= -INF;
            H_PE <= -INF;  
            D_PE <= -INF;  
            CH_PE <= 0;
            CI_PE <= 0;
            CD_PE <= 0;
            //xdrop_flag <= 0;  
            dir_out <= 0;
        end
        
        else if (set_param) begin
            sub_A <= sub_A_in;
            sub_C <= sub_C_in;
            sub_G <= sub_G_in;
            sub_T <= sub_T_in;
            sub_N <= sub_N_in;
            gap_open <= gap_open_in;
            gap_extend <= gap_extend_in;
            H_PE<=-INF;
            param_valid<=param_valid_in;
        end

        else if(param_valid) begin
            //D_init <= D_init_in;
            init_out <= init_in;
            dir_out <= dir;
            

            ref_idx <= ref_idx_in;
            ref_idx_out <= ref_idx_in;
            if (init_in) begin

                H_prev <= H_score;
                D_prev <= D_score;
                H_PE_prev2 <= H_PE_prev;

                CH_score_reg <= CH_score;
                CD_score_reg <= CD_score;
                CH_score_reg2 <= CH_PE_prev;

                query_idx_out <= query_idx_in + 1;
                I_PE <= I_score;
                H_PE <= H_score;  
                D_PE <= D_score;
                CH_PE <= CH_score;
                CI_PE <= CI_score;
                CD_PE <= CD_score;
                //xdrop_flag <= xdrop_flag_reg;

            end

            else begin
                //xdrop_flag <= 0;
                //H_PE_prev2 <= (start_idx == 0) ? (block ? -query_idx_in + (gap_open - gap_extend): H_init_in): diag_score;
                H_PE_prev2 <= block ?  (PE_IDX?-INF:diag_score): H_init_in;
                CH_score_reg2 <= block ?  (PE_IDX?CONV_DONT_CARE:diag_CH_score): CONV_DONT_CARE;
                H_prev <= -INF;
                D_prev <= -INF;
                CH_score_reg<=CONV_DONT_CARE;
                CD_score_reg<=CONV_DONT_CARE;
                CH_PE <= CONV_DONT_CARE;
                CI_PE <= CONV_DONT_CARE;
                CD_PE <= CONV_DONT_CARE;
            end
        end

    end

    
endmodule