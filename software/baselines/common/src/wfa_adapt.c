/*
 *                             The MIT License
 *
 * Wavefront Alignment Algorithms
 * Copyright (c) 2017 by Santiago Marco-Sola  <santiagomsola@gmail.com>
 *
 * This file is part of Wavefront Alignment Algorithms.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 *
 * PROJECT: Wavefront Alignment Algorithms
 * AUTHOR(S): Santiago Marco-Sola <santiagomsola@gmail.com>
 * DESCRIPTION: WFA Sample-Code
 */

#include "wavefront/wavefront_align.h"
#include <time.h>

int main(int argc,char* argv[]) {
  // Patter & Text
  FILE* ref_data;
  FILE* query_data;

  ref_data = fopen(argv[1], "r");
  query_data = fopen(argv[2], "r");
  char* ref = NULL;
  char* query = NULL;
  size_t len = 0;
  size_t len1 = 0;
  ssize_t readq;
  ssize_t readr;
  clock_t start;
  clock_t end;
  double time = 0;
  int count_seq = 0;
    wavefront_aligner_attr_t attributes = wavefront_aligner_attr_default;
    attributes.distance_metric = gap_affine;
    attributes.affine_penalties.match = 0;
    attributes.affine_penalties.mismatch = 4;
    attributes.affine_penalties.gap_opening = 6;
    attributes.affine_penalties.gap_extension = 2;
    // Set heuristic wf-adaptive
    attributes.heuristic.strategy = wf_heuristic_wfadaptive;
    attributes.heuristic.min_wavefront_length = 10;
    attributes.heuristic.max_distance_threshold = 50;
    attributes.heuristic.steps_between_cutoffs = 1;
    // Initialize Wavefront Aligner
    // attributes.memory_mode = wavefront_memory_high;
    wavefront_aligner_t* const wf_aligner = wavefront_aligner_new(&attributes);

  while (true){
    
    if ((readr = getline(&ref, &len, ref_data)) == -1) {
      break;
    }
    if ((readq = getline(&query, &len1, query_data)) == -1) {
      break;
    }
    count_seq += 1;
    readr = getline(&ref, &len, ref_data);
    readq = getline(&query, &len1, query_data);

    char* pattern = query;
    char* text    = ref;

    start = clock();  
    // Configure alignment attributes
       // Align
    wavefront_align(wf_aligner,pattern,strlen(pattern),text,strlen(text));
    end = clock();  
    time += (double)(end-start)/(CLOCKS_PER_SEC*count_seq);
    fprintf(stderr,"WFA-Alignment returns score %d in %f sec\n",wf_aligner->cigar->score, (double)(end-start)/CLOCKS_PER_SEC);
    // Count mismatches, deletions, and insertions
    int i, misms=0, ins=0, del=0;
    cigar_t* const cigar = wf_aligner->cigar;
    for (i=cigar->begin_offset;i<cigar->end_offset;++i) {
      switch (cigar->operations[i]) {
        case 'M': break;
        case 'X': ++misms; break;
        case 'D': ++del; break;
        case 'I': ++ins; break;
      }
    }
    // fprintf(stderr,"Alignment contains %d mismatches, "
        // "%d insertions, and %d deletions\n",misms,ins,del);
    // Free
  }
  
    wavefront_aligner_delete(wf_aligner);
  fprintf (stderr, "\n%f secs\n", time);
  fprintf (stderr, "\n%d counts\n", count_seq);
  fclose(ref_data);
  fclose(query_data);
  if(ref) free(ref);
  if(query) free(query);
}
