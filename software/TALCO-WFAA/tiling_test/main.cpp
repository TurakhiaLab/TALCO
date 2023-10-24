extern "C"{
#include "wavefront/wavefront.h"
#include "wavefront/wfa.h"
}
#include "tiling_test/nanosim_input.hpp"
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include "utils/commons.h"
#include <unistd.h>
#include "err_stats.hpp"
#include <signal.h>
#include <bits/stdc++.h>
#include <string>
static void dump_file(char* fname,std::string& out){
    auto fd=creat(fname, S_IRWXU);
    if (fd<0) {
        perror(fname);
        raise(SIGTRAP);
    }
    auto len=out.size();
    auto ptr=out.data();
    while (len) {
        auto write_len=write(fd, ptr, len);
        if (write_len==-1) {
            perror("write");
            raise(SIGTRAP);
        }
        len-=write_len;
        ptr+=write_len;
    }
    close(fd);
}

std::string adv_tokenizer(std::string s, char del)
{
    std::stringstream ss(s);
    std::string word;
    while (!ss.eof()) {
        std::getline(ss, word, del);
    }
    return word;
}


int main(int argc, char* argv[]){
      wavefront_aligner_attr_t attributes = wavefront_aligner_attr_default;
  attributes.distance_metric = gap_affine;
  attributes.affine_penalties.match = 0;
  attributes.affine_penalties.mismatch = 2;
  attributes.affine_penalties.gap_opening = 3;
  attributes.affine_penalties.gap_extension = 1;
  attributes.use_tile=true;
    // Set heuristic wf-adaptive
  attributes.heuristic.strategy = wf_heuristic_wfadaptive;
  attributes.heuristic.min_wavefront_length = 10;
  attributes.heuristic.max_distance_threshold = 50;
  attributes.heuristic.steps_between_cutoffs = 1;
  //Semi-global
      attributes.alignment_form.span = alignment_endsfree;
      attributes.alignment_form.pattern_begin_free = 0;
    attributes.alignment_form.pattern_end_free = 1;
    attributes.alignment_form.text_begin_free = 0;
    attributes.alignment_form.text_end_free = 1;
  attributes.memory_mode = wavefront_memory_med;

  // Initialize Wavefront Aligner
  wavefront_aligner_t* const wf_aligner = wavefront_aligner_new(&attributes);
  wf_aligner->marking_score=32;
  
    //sequence file from nanosim, reference, faidx
    if(argc!=3){
        fprintf(stderr, "args: nanosim_output reference_fasta\n");
        exit(EXIT_FAILURE);
    }

    char* query_path = argv[2];
    char* ref_path = argv[1];


    std::ifstream query_data;
    std::ifstream ref_data;
    ref_data.open(ref_path);
    query_data.open(query_path);
    
    // Nanosim_Input input(argv[2],argv[1]);
    int aligned=0;
    int failed=0;
    while (true) {
        // std::string seq_name;
        std::string ref;
        std::string query;

        std::getline(ref_data, ref);
        std::getline(query_data, query);
        if (ref_data.eof())
            break;
        if (query_data.eof())
            break;

        if (ref[0] == '>')
            continue;

        // query = adv_tokenizer(query_str,'>');
        // ref = adv_tokenizer(ref_str,'>');

        // std::cout << query << std::endl;
        // std::cout << ref << std::endl;

        dump_file("query", query);
        dump_file("ref", ref);
        char* cigar;
        int cigar_len;
        Effi_Stats_t stats;
        wavefront_tile(wf_aligner,&cigar,&cigar_len,
        query.data(),
        query.size(),
        ref.data(),
        ref.size(),
        &stats);
        auto counts=calculate_error_rate(cigar,cigar_len);
        free(cigar);
        printf("%d\t%d\t%d\t%f\t%d\t%d\t%d\n", counts.match_count,counts.mismatch_count,counts.indel_count,counts.error_rate,
            stats.longest_wavefront,stats.post_marking_cells,stats.pre_marking_cells);
    }

}