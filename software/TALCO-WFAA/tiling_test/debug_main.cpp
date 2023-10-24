extern "C"{
#include "wavefront/wavefront.h"
#include "wavefront/wfa.h"
}
#include <csignal>
#include <cstddef>
#include <cstdio>
#include <string>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
static void load_from_file(char* fname,std::string& out){
    auto fd=open(fname, O_RDONLY);
    if (fd<0) {
        perror(fname);
        raise(SIGTRAP);
    }
    struct stat stat_buf;
    fstat(fd, &stat_buf);
    auto len=stat_buf.st_size;
    out.resize(len);
    auto ptr=const_cast<char*>(out.data());
    while (len) {
        auto write_len=read(fd, ptr, len);
        if (write_len==-1) {
            perror("write");
            raise(SIGTRAP);
        }
        len-=write_len;
        ptr+=write_len;
    }
    close(fd);
}
int main(int argc, char** argv){
    //sequence file from nanosim, reference, faidx
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
  std::string seq_name,query,ref;
        load_from_file("query", query);
        load_from_file("ref", ref);
        char* cigar;
        int cigar_len;
        Effi_Stats_t stats;
        wavefront_tile(wf_aligner,&cigar,&cigar_len,
        query.data(),
        query.size(),
        ref.data(),
        ref.size(),
        &stats);
        fprintf(stderr, "out \n");
        
}