extern "C"{
#include "wavefront/wavefront.h"
#include "wavefront/wfa.h"
}
#include <csignal>
#include <cstddef>
#include <cstdio>
#include "nanosim_input.hpp"
#include <oneapi/tbb/parallel_pipeline.h>
#include <oneapi/tbb/global_control.h>
#include <string>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
// #include <tbb/parallel_pipeline.h>
#include <utility>
#include <unistd.h>
#include <sys/types.h>
#include "err_stats.hpp"

static void dump_file(std::string fname,std::string& out){
    auto fd=creat(fname.c_str(), S_IRWXU);
    if (fd<0) {
        perror(fname.c_str());
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
struct Seq_Info{
    std::string query;
    std::string ref;
    std::string seq_name;
};
struct wfa_aligner{
    wavefront_aligner_t* wf_aligner;
    wfa_aligner(){
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
  wf_aligner = wavefront_aligner_new(&attributes);
  wf_aligner->marking_score=256;

    }
};
thread_local wfa_aligner aligners;
int main(int argc, char** argv){
    //sequence file from nanosim, reference, faidx
    if(argc!=3){
        fprintf(stderr, "args: nanosim_output reference_fasta\n");
        exit(EXIT_FAILURE);
    }
    
    Nanosim_Input input(argv[2],argv[1]);
    int aligned=0;
    int failed=0;
    tbb::parallel_pipeline(64,
        tbb::make_filter<void,Seq_Info*>(tbb::filter_mode::serial_in_order,
            [&input](tbb::flow_control& fc)->Seq_Info*{
                auto res= new Seq_Info;
                if(!input(res->seq_name,res->ref,res->query)){
                    delete res;
                    fc.stop();
                    return nullptr;
                }
                return res;
            })&
        tbb::make_filter<Seq_Info*, void>(tbb::filter_mode::parallel, [](Seq_Info* in_seq){
            auto cur_tid=gettid();
            /*dump_file(std::to_string(cur_tid)+"query", in->query);
            dump_file(std::to_string(cur_tid)+"ref", in->ref);*/
            char* cigar;
        int cigar_len;
        Effi_Stats_t stats;
        wavefront_tile(aligners.wf_aligner,&cigar,&cigar_len,
        in_seq->query.data(),
        in_seq->query.size(),
        in_seq->ref.data(),
        in_seq->ref.size(),
        &stats);
        auto counts=calculate_error_rate(cigar,cigar_len);
        free(cigar);
        printf("%s\t%d\t%d\t%d\t%f\t%d\t%d\t%d\n",in_seq->seq_name.c_str(),
            counts.match_count,counts.mismatch_count,counts.indel_count,counts.error_rate,
            stats.longest_wavefront,stats.post_marking_cells,stats.pre_marking_cells);
            delete in_seq;
        })
    );

}