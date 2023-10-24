struct err_stats{
    int match_count;
    int mismatch_count;
    int indel_count;
    float error_rate;
};
err_stats calculate_error_rate(const char* cigar, int cigar_len);