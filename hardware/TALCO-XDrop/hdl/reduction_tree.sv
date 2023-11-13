module reduction_tree_max #(
        parameter PE_WIDTH = 16,
        parameter SEL_WIDTH = 16,
        parameter NUM_PE = 4,
        parameter LOG_NUM_PE = 2
    )(
        input   logic [SEL_WIDTH - 1: 0] to_sel [0: NUM_PE - 1],
        input   logic signed [PE_WIDTH - 1: 0] array [0: NUM_PE - 1],
        output  logic signed [PE_WIDTH - 1: 0] reduction_value,
        output  logic [LOG_NUM_PE - 1: 0] idx,
        output logic [SEL_WIDTH - 1: 0] selected
    );
    
    logic local_stop;
    
    genvar i,j;
    generate
        for ( j = 0; j < LOG_NUM_PE; j = j + 1 ) begin: rt_level
            for ( i = 0; i < 2**(LOG_NUM_PE - j - 1); i = i + 1 ) begin: rt_iter
                logic signed [PE_WIDTH - 1: 0] value1;
                logic signed [PE_WIDTH - 1: 0] value2;
                logic signed [SEL_WIDTH - 1: 0] sel_value1;
                logic signed [SEL_WIDTH - 1: 0] sel_value2;
                logic signed [SEL_WIDTH - 1: 0] selected_val;
                logic signed [PE_WIDTH - 1: 0] out;
                logic [LOG_NUM_PE - 1: 0] idx1;
                logic [LOG_NUM_PE - 1: 0] idx2;
                logic [LOG_NUM_PE - 1: 0] max_idx;

                if(j == 0) begin
                    assign value1 = array[ i * 2 ];
                    assign value2 = array[ i * 2 + 1 ];
                    assign sel_value1=to_sel[ i*2 ];
                    assign sel_value2=to_sel[ i*2 +1 ];
                    assign idx1 = i * 2;
                    assign idx2 = i * 2 + 1;
                end
                else begin
                    assign value1 = rt_level[ j - 1 ].rt_iter[ i * 2 ].out;
                    assign value2 = rt_level[ j - 1 ].rt_iter[ i * 2 + 1 ].out;
                    assign sel_value1 = rt_level[ j - 1 ].rt_iter[ i * 2 ].selected_val;
                    assign sel_value2 = rt_level[ j - 1 ].rt_iter[ i * 2 + 1 ].selected_val;
                    assign idx1 = rt_level[ j - 1 ].rt_iter[ i * 2 ].max_idx;
                    assign idx2 = rt_level[ j - 1 ].rt_iter[ i * 2 + 1 ].max_idx;
                end
                assign selected_val=($signed(value1) > $signed(value2)) ? sel_value1:sel_value2;
                assign out = ($signed(value1) > $signed(value2)) ? value1 :value2;
                assign max_idx = ($signed(value1) > $signed(value2)) ? idx1 :idx2;
            end
        end
        assign reduction_value = rt_level[LOG_NUM_PE - 1].rt_iter[0].out;
        assign idx = rt_level[LOG_NUM_PE - 1].rt_iter[0].max_idx;
        assign selected= rt_level[LOG_NUM_PE - 1].rt_iter[0].selected_val;
    endgenerate
endmodule
           
module reduction_tree_value #(
        parameter PE_WIDTH = 16,
        parameter NUM_PE = 4,
        parameter LOG_NUM_PE = 2
    )(
        input   logic [PE_WIDTH - 1: 0] array [0: NUM_PE - 1],
        output  logic [PE_WIDTH - 1: 0] reduction_value,
        output logic reduction_bool
    );
    
    logic local_stop;
    parameter CONV_DONT_CARE=0;
    
    genvar i,j;
    generate
        for ( j = 0; j < LOG_NUM_PE; j = j + 1 ) begin: rt_level
            for ( i = 0; i < 2**(LOG_NUM_PE - j - 1); i = i + 1 ) begin: rt_iter
                logic [PE_WIDTH - 1: 0] value0;
                logic [PE_WIDTH - 1: 0] value1;
                logic [PE_WIDTH - 1: 0] value2;
                logic bool0;
                logic bool1;
                logic bool2;

                if(j == 0) begin
                    assign value1 = array[ i * 2 ];
                    assign value2 = array[ i * 2 + 1 ];
                    assign bool1 = 1'b1;
                    assign bool2 = 1'b1;
                end
                else begin
                    assign value1 = rt_level[ j - 1 ].rt_iter[ i * 2 ].value0;
                    assign value2 = rt_level[ j - 1 ].rt_iter[ i * 2 + 1 ].value0;
                    assign bool1  = rt_level[ j - 1 ].rt_iter[ i * 2 ].bool0;
                    assign bool2  = rt_level[ j - 1 ].rt_iter[ i * 2 + 1 ].bool0;
                end

                wire dontcare1=value1==CONV_DONT_CARE;
                wire dontcare2=value2==CONV_DONT_CARE;
                assign value0 = dontcare1?value2:value1; // choose either value1 or value2
                assign bool0=(dontcare1||dontcare2||value1==value2)&&bool1&&bool2;
            end
        end
        assign reduction_bool  = rt_level[LOG_NUM_PE - 1].rt_iter[0].bool0;
        assign reduction_value = rt_level[LOG_NUM_PE - 1].rt_iter[0].value0;
    endgenerate
endmodule


//            for ( j = LOG_NUM_PE - 1; j <= 0; j = j - 1 ) begin: rt_level_up
//                logic [LOG_NUM_PE - 1: 0] local_i;
//                if (j == LOG_NUM_PE - 1) begin
//                    assign local_i = 2*0 + 1;
//                end
//                else begin  
//                    logic value1;
//                    logic value2;
                    
//                    assign value1 = rt_level[j].rt_iter[rt_level_up[j-1].local_i - 0].out;
//                    assign value2 = rt_level[j].rt_iter[rt_level_up[j-1].local_i - 1].out;
                    
//                    if (value1) assign local_i = 2*(rt_level_up[j-1].local_i) + 1;
//                    else assign local_i = 2*(rt_level_up[j-1].local_i - 1) + 1;
                    
//                end
//            end
            
//            if (stop == 1) 
//                assign reduction_value = rt_level_up[0].local_i;
            
//            else
//                assign reduction_value = 0;