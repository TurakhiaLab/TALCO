#include "err_stats.hpp"
#include <signal.h>
err_stats calculate_error_rate(const char* cigar, int cigar_len){
    err_stats out{0,0,0,0};
    for(int idx=0;idx<cigar_len;idx++){
        switch (cigar[idx])
        {
        case 'M':
            out.match_count++;
            break;
        case 'X':
            out.mismatch_count++;
            break;
        case 'I':
        case 'D':
            out.indel_count++;
            break;
        default:
            raise(SIGTRAP);
        }
    }
    out.error_rate=((float)(out.indel_count+out.mismatch_count))/((float)(out.match_count+out.indel_count+out.mismatch_count+1));
    return out;
}