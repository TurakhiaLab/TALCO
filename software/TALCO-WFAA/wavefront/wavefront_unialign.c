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
 */

#include "utils/commons.h"
#include "system/mm_allocator.h"
#include "wavefront_unialign.h"
#include "wavefront.h"
#include "wavefront_attributes.h"
#include "wavefront_offset.h"
#include "wavefront_penalties.h"
#include "wavefront_plot.h"
#include "wavefront_slab.h"

#include "wavefront_components.h"
#include "wavefront_compute.h"
#include "wavefront_compute_affine.h"
#include "wavefront_compute_affine2p.h"
#include "wavefront_compute_edit.h"
#include "wavefront_compute_linear.h"
#include "wavefront_extend.h"
#include "wavefront_backtrace.h"
#include "wavefront_backtrace_buffer.h"

/*
 * Configuration
 */
#define SEQUENCES_PADDING     10

/*
 * Setup
 */
void wavefront_unialign_status_clear(
    wavefront_align_status_t* const align_status) {
  align_status->status = WF_STATUS_SUCCESSFUL;
  align_status->score = 0;
}
void wavefront_unialigner_system_clear(
    wavefront_aligner_t* const wf_aligner) {
  // Reset effective limits
  wf_aligner->system.max_memory_compact = BUFFER_SIZE_256M;
  wf_aligner->system.max_memory_resident = BUFFER_SIZE_256M + BUFFER_SIZE_256M;
  switch (wf_aligner->memory_mode) {
    case wavefront_memory_med:
      wf_aligner->system.max_partial_compacts = 4;
      break;
    case wavefront_memory_low:
      wf_aligner->system.max_partial_compacts = 1;
      break;
    default:
      break;
  }
  // Profile
  timer_reset(&wf_aligner->system.timer);
}
/*
 * Resize
 */
void wavefront_unialign_resize(
    wavefront_aligner_t* const wf_aligner,
    const char* const pattern,
    const int pattern_length,
    const char* const text,
    const int text_length,
    const bool reverse_sequences) {
  // Configure sequences and status
  wf_aligner->pattern_length = pattern_length;
  wf_aligner->text_length = text_length;
  if (wf_aligner->match_funct == NULL) {
    if (wf_aligner->sequences != NULL) strings_padded_delete(wf_aligner->sequences);
    wf_aligner->sequences = strings_padded_new_rhomb(
            pattern,pattern_length,text,text_length,
            SEQUENCES_PADDING,reverse_sequences,
            wf_aligner->mm_allocator);
    wf_aligner->pattern = wf_aligner->sequences->pattern_padded;
    wf_aligner->text = wf_aligner->sequences->text_padded;
  } else {
    wf_aligner->sequences = NULL;
    wf_aligner->pattern = NULL;
    wf_aligner->text = NULL;
  }
  wavefront_unialign_status_clear(&wf_aligner->align_status);
  // Heuristics clear
  wavefront_heuristic_clear(&wf_aligner->heuristic);
  // Wavefront components
  wavefront_components_resize(&wf_aligner->wf_components,
      pattern_length,text_length,&wf_aligner->penalties);
  wavefront_components_resize(&wf_aligner->wf_components_pass_marking,
      pattern_length,text_length,&wf_aligner->penalties);
  // CIGAR
  if (wf_aligner->alignment_scope == compute_alignment) {
    cigar_resize(wf_aligner->cigar,2*(pattern_length+text_length));
  }
  // Slab
  wavefront_slab_clear(wf_aligner->wavefront_slab);
  // System
  wavefront_unialigner_system_clear(wf_aligner);
}
/*
 * Initialize alignment
 */
void wavefront_unialign_initialize_wavefront_m(
    wavefront_aligner_t* const wf_aligner,
    const int pattern_length,
    const int text_length) {
  // Parameters
  wavefront_slab_t* const wavefront_slab = wf_aligner->wavefront_slab;
  wavefront_components_t* const wf_components = &wf_aligner->wf_components;
  const distance_metric_t distance_metric = wf_aligner->penalties.distance_metric;
  wavefront_penalties_t* const penalties = &wf_aligner->penalties;
  alignment_form_t* const form = &wf_aligner->alignment_form;
  // Consider ends-free
  const int hi = (penalties->match==0) ? form->text_begin_free : 0;
  const int lo = (penalties->match==0) ? -form->pattern_begin_free : 0;
  // Compute dimensions
  int effective_lo, effective_hi;
  wavefront_compute_limits_output(wf_aligner,lo,hi,&effective_lo,&effective_hi);
  // Initialize end2end (wavefront zero)
  wf_components->mwavefronts[0] = wavefront_slab_allocate(wavefront_slab,effective_lo,effective_hi,false);
  wf_components->mwavefronts[0]->offsets[0] = 0;
  wf_components->mwavefronts[0]->lo = lo;
  wf_components->mwavefronts[0]->hi = hi;
  // Store initial BT-piggypack element
  if (wf_components->bt_piggyback) {
    const bt_block_idx_t block_idx = wf_backtrace_buffer_init_block(wf_components->bt_buffer,0,0);
    wf_components->mwavefronts[0]->bt_pcigar[0] = 0;
    wf_components->mwavefronts[0]->bt_prev[0] = block_idx;
  }
  // Initialize ends-free
  if (form->span == alignment_endsfree && penalties->match == 0) {
    // Text begin-free
    const int text_begin_free = form->text_begin_free;
    int h;
    for (h=1;h<=text_begin_free;++h) {
      const int k = DPMATRIX_DIAGONAL(h,0);
      wf_components->mwavefronts[0]->offsets[k] = DPMATRIX_OFFSET(h,0);
      if (wf_components->bt_piggyback) {
        const bt_block_idx_t block_idx = wf_backtrace_buffer_init_block(wf_components->bt_buffer,0,h);
        wf_components->mwavefronts[0]->bt_pcigar[k] = 0;
        wf_components->mwavefronts[0]->bt_prev[k] = block_idx;
      }
    }
    // Pattern begin-free
    const int pattern_begin_free = form->pattern_begin_free;
    int v;
    for (v=1;v<=pattern_begin_free;++v) {
      const int k = DPMATRIX_DIAGONAL(0,v);
      wf_components->mwavefronts[0]->offsets[k] = DPMATRIX_OFFSET(0,v);
      if (wf_components->bt_piggyback) {
        const bt_block_idx_t block_idx = wf_backtrace_buffer_init_block(wf_components->bt_buffer,v,0);
        wf_components->mwavefronts[0]->bt_pcigar[k] = 0;
        wf_components->mwavefronts[0]->bt_prev[k] = block_idx;
      }
    }
  }
  // Nullify unused WFs
  if (distance_metric <= gap_linear) return;
  wf_components->d1wavefronts[0] = NULL;
  wf_components->i1wavefronts[0] = NULL;
  if (distance_metric==gap_affine) return;
  wf_components->d2wavefronts[0] = NULL;
  wf_components->i2wavefronts[0] = NULL;
}
void wavefront_unialign_initialize_wavefronts(
    wavefront_aligner_t* const wf_aligner,
    const int pattern_length,
    const int text_length) {
  // Parameters
  wavefront_slab_t* const wavefront_slab = wf_aligner->wavefront_slab;
  wavefront_components_t* const wf_components = &wf_aligner->wf_components;
  const distance_metric_t distance_metric = wf_aligner->penalties.distance_metric;
  // Init wavefronts
  if (wf_aligner->component_begin == affine2p_matrix_M) {
    // Initialize
    wavefront_unialign_initialize_wavefront_m(wf_aligner,pattern_length,text_length);
    // Nullify unused WFs
    if (distance_metric <= gap_linear) return;
    wf_components->i1wavefronts[0] = NULL;
    wf_components->d1wavefronts[0] = NULL;
    if (distance_metric==gap_affine) return;
    wf_components->i2wavefronts[0] = NULL;
    wf_components->d2wavefronts[0] = NULL;
  } else {
    // Compute dimensions
    int effective_lo, effective_hi; // Effective lo/hi
    wavefront_compute_limits_output(wf_aligner,0,0,&effective_lo,&effective_hi);
    wavefront_t* const wavefront = wavefront_slab_allocate(wavefront_slab,effective_lo,effective_hi,false);
    // Store initial BT-piggypack element
    if (wf_components->bt_piggyback) {
      const bt_block_idx_t block_idx = wf_backtrace_buffer_init_block(wf_components->bt_buffer,0,0);
      wavefront->bt_pcigar[0] = 0;
      wavefront->bt_prev[0] = block_idx;
    }
    // Initialize
    switch (wf_aligner->component_begin) {
      case affine2p_matrix_I1:
        wf_components->mwavefronts[0] = NULL;
        wf_components->i1wavefronts[0] = wavefront;
        wf_components->i1wavefronts[0]->offsets[0] = 0;
        wf_components->i1wavefronts[0]->lo = 0;
        wf_components->i1wavefronts[0]->hi = 0;
        wf_components->d1wavefronts[0] = NULL;
        // Nullify unused WFs
        if (distance_metric==gap_affine) return;
        wf_components->i2wavefronts[0] = NULL;
        wf_components->d2wavefronts[0] = NULL;
        break;
      case affine2p_matrix_I2:
        wf_components->mwavefronts[0] = NULL;
        wf_components->i1wavefronts[0] = NULL;
        wf_components->d1wavefronts[0] = NULL;
        wf_components->i2wavefronts[0] = wavefront;
        wf_components->i2wavefronts[0]->offsets[0] = 0;
        wf_components->i2wavefronts[0]->lo = 0;
        wf_components->i2wavefronts[0]->hi = 0;
        wf_components->d2wavefronts[0] = NULL;
        break;
      case affine2p_matrix_D1:
        wf_components->mwavefronts[0] = NULL;
        wf_components->i1wavefronts[0] = NULL;
        wf_components->d1wavefronts[0] = wavefront;
        wf_components->d1wavefronts[0]->offsets[0] = 0;
        wf_components->d1wavefronts[0]->lo = 0;
        wf_components->d1wavefronts[0]->hi = 0;
        // Nullify unused WFs
        if (distance_metric==gap_affine) return;
        wf_components->i2wavefronts[0] = NULL;
        wf_components->d2wavefronts[0] = NULL;
        break;
      case affine2p_matrix_D2:
        wf_components->mwavefronts[0] = NULL;
        wf_components->i1wavefronts[0] = NULL;
        wf_components->d1wavefronts[0] = NULL;
        wf_components->i2wavefronts[0] = NULL;
        wf_components->d2wavefronts[0] = wavefront;
        wf_components->d2wavefronts[0]->offsets[0] = 0;
        wf_components->d2wavefronts[0]->lo = 0;
        wf_components->d2wavefronts[0]->hi = 0;
        break;
      default:
        break;
    }
  }
}
void wavefront_unialign_init(
    wavefront_aligner_t* const wf_aligner,
    const char* const pattern,
    const int pattern_length,
    const char* const text,
    const int text_length,
    const affine2p_matrix_type component_begin,
    const affine2p_matrix_type component_end) {
  // Parameters
  wavefront_align_status_t* const align_status = &wf_aligner->align_status;
  // Resize wavefront aligner
  wavefront_unialign_resize(wf_aligner,pattern,pattern_length,text,text_length,false);
  // Configure WF-compute function
  switch (wf_aligner->penalties.distance_metric) {
    case indel:
    case edit:
      align_status->wf_align_compute = &wavefront_compute_edit;
      break;
    case gap_linear:
      align_status->wf_align_compute = &wavefront_compute_linear;
      break;
    case gap_affine:
      align_status->wf_align_compute = &wavefront_compute_affine;
      break;
    case gap_affine_2p:
      align_status->wf_align_compute = &wavefront_compute_affine2p;
      break;
    default:
      fprintf(stderr,"[WFA] Distance function not implemented\n");
      exit(1);
      break;
  }
  // Configure WF-extend function
  const bool end2end = (wf_aligner->alignment_form.span == alignment_end2end);
  if (wf_aligner->match_funct != NULL) {
    align_status->wf_align_extend = &wavefront_extend_custom;
  } else if (end2end) {
    align_status->wf_align_extend = &wavefront_extend_end2end;
  } else {
    align_status->wf_align_extend = &wavefront_extend_endsfree;
  }
  // Initialize wavefront
  wf_aligner->alignment_end_pos.score = -1; // Not aligned
  wf_aligner->alignment_end_pos.k = DPMATRIX_DIAGONAL_NULL;
  wf_aligner->component_begin = component_begin;
  wf_aligner->component_end = component_end;
  wavefront_unialign_initialize_wavefronts(wf_aligner,pattern_length,text_length);
  // Plot (WF_0)
  if (wf_aligner->plot != NULL) wavefront_plot(wf_aligner,0,0);
}
/*
 * Limits
 */
bool wavefront_unialign_reached_limits(
    wavefront_aligner_t* const wf_aligner,
    const int score) {
  // Check alignment-score limit
  if (score >= wf_aligner->system.max_alignment_score) {
    wf_aligner->cigar->score = wf_aligner->system.max_alignment_score;
    wf_aligner->align_status.status = WF_STATUS_MAX_SCORE_REACHED;
    wf_aligner->align_status.score = score;
    return true; // Stop
  }
  // Global probing interval
  alignment_system_t* const system = &wf_aligner->system;
  if (score % system->probe_interval_global != 0) return false; // Continue
  if (system->verbose >= 3) {
    wavefront_unialign_print_status(stderr,wf_aligner,score); // DEBUG
  }
  // BT-Buffer
  wavefront_components_t* const wf_components = &wf_aligner->wf_components;
  if (wf_components->bt_buffer!=NULL && (score%system->probe_interval_compact)==0) {
    uint64_t bt_memory = wf_backtrace_buffer_get_size_used(wf_components->bt_buffer);
    // Check BT-buffer memory
    if (bt_memory > system->max_memory_compact) {
      // Compact BT-buffer
      wavefront_components_compact_bt_buffer(wf_components,score,wf_aligner->system.verbose);
      // Set new buffer limit
      bt_memory = wf_backtrace_buffer_get_size_used(wf_components->bt_buffer);
      uint64_t proposed_mem = (double)bt_memory * TELESCOPIC_FACTOR;
      if (system->max_memory_compact < proposed_mem && proposed_mem < system->max_memory_abort) {
        proposed_mem = system->max_memory_compact;
      }
      // Reset (if maximum compacts has been performed)
      if (wf_components->bt_buffer->num_compactions >= system->max_partial_compacts) {
        wf_backtrace_buffer_reset_compaction(wf_components->bt_buffer);
      }
    }
  }
  // Check overall memory used
  const uint64_t wf_memory_used = wavefront_aligner_get_size(wf_aligner);
  if (wf_memory_used > system->max_memory_abort) {
    wf_aligner->align_status.status = WF_STATUS_OOM;
    wf_aligner->align_status.score = score;
    return true; // Stop
  }
  // Otherwise continue
  return false;
}
/*
 * Terminate alignment (backtrace)
 */
void wavefront_unialign_terminate(
    wavefront_aligner_t* const wf_aligner,
    const int score) {
  // Parameters
  const int pattern_length = wf_aligner->pattern_length;
  const int text_length = wf_aligner->text_length;
  // Retrieve alignment
  if (wf_aligner->alignment_scope == compute_score) {
    cigar_clear(wf_aligner->cigar);
    wf_aligner->cigar->score =
        wavefront_compute_classic_score(wf_aligner,pattern_length,text_length,score);
  } else {
    // Parameters
    wavefront_components_t* const wf_components = &wf_aligner->wf_components;
    const int alignment_end_k = wf_aligner->alignment_end_pos.k;
    const wf_offset_t alignment_end_offset = wf_aligner->alignment_end_pos.offset;
    if (wf_components->bt_piggyback) {
      // Fetch wavefront
      const bool memory_modular = wf_aligner->wf_components.memory_modular;
      const int max_score_scope = wf_aligner->wf_components.max_score_scope;
      const int score_mod = (memory_modular) ? score % max_score_scope : score;
      wavefront_t* const mwavefront = wf_components->mwavefronts[score_mod];
      // Backtrace alignment from buffer (unpacking pcigar)
      wavefront_backtrace_pcigar(
          wf_aligner,alignment_end_k,alignment_end_offset,
          mwavefront->bt_pcigar[alignment_end_k],
          mwavefront->bt_prev[alignment_end_k],true);
    } else {
      // Backtrace alignment
      if (wf_aligner->penalties.distance_metric <= gap_linear) {
        wavefront_backtrace_linear(wf_aligner,
            score,alignment_end_k,alignment_end_offset);
      } else {
        wavefront_backtrace_affine(wf_aligner,
            wf_aligner->component_begin,wf_aligner->component_end,
            score,alignment_end_k,alignment_end_offset);
      }
    }
    // Set score & finish
    wf_aligner->cigar->score =
        wavefront_compute_classic_score(wf_aligner,pattern_length,text_length,score);
  }
  // Set successful
  wf_aligner->align_status.status = WF_STATUS_SUCCESSFUL;
}
/*
 * Classic WF-Alignment (Unidirectional)
 */
int wavefront_unialign(
    wavefront_aligner_t* const wf_aligner) {
  // Parameters
  wavefront_align_status_t* const align_status = &wf_aligner->align_status;
  void (*wf_align_compute)(wavefront_aligner_t* const,const int) = align_status->wf_align_compute;
  int (*wf_align_extend)(wavefront_aligner_t* const,const int) = align_status->wf_align_extend;
  // Compute wavefronts of increasing score
  align_status->num_null_steps = 0;
  int score = align_status->score;
  while (true) {
    // Exact extend s-wavefront
    const int finished = (*wf_align_extend)(wf_aligner,score);
    if (finished) {
      // DEBUG
      // wavefront_aligner_print(stderr,wf_aligner,0,score,7,0);
      if (align_status->status == WF_STATUS_END_REACHED) {
        wavefront_unialign_terminate(wf_aligner,score);
      }
      return align_status->status;
    }
    // Compute (s+1)-wavefront
    ++score;
    (*wf_align_compute)(wf_aligner,score);
    // Probe limits
    if (wavefront_unialign_reached_limits(wf_aligner,score)) return align_status->status;
    // Plot
    if (wf_aligner->plot != NULL) wavefront_plot(wf_aligner,score,0);
    // DEBUG
    //wavefront_aligner_print(stderr,wf_aligner,score,score,7,0);
  }
  // Return OK
  align_status->score = score;
  align_status->status = WF_STATUS_SUCCESSFUL;
  return WF_STATUS_SUCCESSFUL;
}
static void concat_cigar(wavefront_aligner_t* const wf_aligner,char** out_cigar,int * cigar_valid_len){
  int this_cigar_len=wf_aligner->cigar->end_offset-wf_aligner->cigar->begin_offset;
  memcpy(*out_cigar+*cigar_valid_len,wf_aligner->cigar->operations+wf_aligner->cigar->begin_offset,this_cigar_len);
  *cigar_valid_len+=this_cigar_len;
}
static wf_offset_t accumulate_converge_idx(wf_offset_t a,wf_offset_t b){
  if (a==IDX_DONT_CARE){
    return b;
  }
  if(b==IDX_DONT_CARE){
    return a;
  }
  if(a==IDX_MISMATCH||b==IDX_MISMATCH||a!=b){
    return IDX_MISMATCH;
  }
  return a;
}
static wf_offset_t test_converged_wf(wavefront_t* wf){
  wf_offset_t cur_idx=IDX_DONT_CARE;
  if (!wf){
    return IDX_DONT_CARE;
  }
  
  for (int idx = wf->lo; idx <= wf->hi; idx++){
    cur_idx=accumulate_converge_idx(cur_idx,wf->diag_idx[idx]);
    if (cur_idx==IDX_MISMATCH){
      /*for (int idx = wf->lo; idx < wf->hi; idx++){
        printf("%08x\t",wf->diag_idx[idx]);
      }
      puts("\n");*/
      break;
    }
  }
  return cur_idx;
}
static int wf_length(wavefront_aligner_t* const wf_aligner, int score){
  const bool memory_modular = wf_aligner->wf_components.memory_modular;
  const int max_score_scope = wf_aligner->wf_components.max_score_scope;
  wavefront_components_t* wf_components= 
    (score>=wf_aligner->marking_score+max_score_scope)
    ?&wf_aligner->wf_components_pass_marking
    :&wf_aligner->wf_components;
  const int score_mod = (memory_modular) ? score % max_score_scope : score;
  wavefront_t* mwavefronts=wf_components->mwavefronts[score_mod];
  if (!mwavefronts)
  {
    return 0;
  }
  
  return mwavefronts->hi-mwavefronts->lo;
}
static wf_offset_t test_converged_score(wavefront_aligner_t* const wf_aligner, int score){
  const bool memory_modular = wf_aligner->wf_components.memory_modular;
  const int max_score_scope = wf_aligner->wf_components.max_score_scope;
  wavefront_components_t* wf_components= 
    (score>=wf_aligner->marking_score+max_score_scope)
    ?&wf_aligner->wf_components_pass_marking
    :&wf_aligner->wf_components;
  const int score_mod = (memory_modular) ? score % max_score_scope : score;
  wf_offset_t cur_idx=test_converged_wf(wf_components->mwavefronts[score_mod]);
  cur_idx=accumulate_converge_idx(cur_idx,test_converged_wf(wf_components->i1wavefronts[score_mod]));
  cur_idx=accumulate_converge_idx(cur_idx,test_converged_wf(wf_components->d1wavefronts[score_mod]));
  return cur_idx;
}
static void check_cigar(const char* operations,int cigar_len, const char* pattern,const char* text,int pattern_length,int text_length){
    int pattern_pos=0, text_pos=0, i;
  bool alignment_correct=true;
  for (i=0;i<cigar_len;++i) {
    switch (operations[i]) {
      case 'M': {
        // Check match
        const bool is_match =pattern[pattern_pos] == text[text_pos];
        if (!is_match) {
          fprintf(stderr,"[WFA::Check] Alignment not matching (pattern[%d]=%c != text[%d]=%c)\n",
              pattern_pos,pattern[pattern_pos],text_pos,text[text_pos]);
          alignment_correct = false;
          break;
        }
        ++pattern_pos;
        ++text_pos;
        break;
      }
      case 'X': {
        // Check mismatch
        const bool is_match =pattern[pattern_pos] == text[text_pos];
        if (is_match) {
          fprintf(stderr,"[WFA::Check] Alignment not mismatching (pattern[%d]=%c == text[%d]=%c)\n",
              pattern_pos,pattern[pattern_pos],text_pos,text[text_pos]);
          alignment_correct = false;
          break;
        }
        ++pattern_pos;
        ++text_pos;
        break;
      }
      case 'I':
        ++text_pos;
        break;
      case 'D':
        ++pattern_pos;
        break;
      default:
        fprintf(stderr,"[WFA::Check] Unknown edit operation '%c'\n",operations[i]);
        raise(SIGTRAP);
        break;
    }
  }
  if (pattern_pos != pattern_length) {
    fprintf(stderr,
        "[WFA::Check] Alignment incorrect length (pattern-aligned=%d,pattern-length=%d)\n",
        pattern_pos,pattern_length);
    alignment_correct = false;
  }
  if (text_pos != text_length) {
    fprintf(stderr,
        "[WFA::Check] Alignment incorrect length (text-aligned=%d,text-length=%d)\n",
        text_pos,text_length);
    alignment_correct = false;
  }
  if(!alignment_correct){
    raise(SIGTRAP);
  }
}
int wavefront_tile(
    wavefront_aligner_t* const wf_aligner,char** out_cigar,int * cigar_valid_len,
    const char*  pattern,
    int pattern_length,
    const char*  text,
    int text_length,
    Effi_Stats_t* stats) {
  stats->longest_wavefront=0;
  stats->post_marking_cells=0;
  stats->pre_marking_cells=0;
  wavefront_unialign_init(
      wf_aligner,
      pattern,pattern_length,
      text,text_length,
      affine2p_matrix_M,affine2p_matrix_M);
  // Parameters
  wavefront_align_status_t* const align_status = &wf_aligner->align_status;
  void (*wf_align_compute)(wavefront_aligner_t* const,const int) = align_status->wf_align_compute;
  int (*wf_align_extend)(wavefront_aligner_t* const,const int) = align_status->wf_align_extend;
  // Compute wavefronts of increasing score
  align_status->num_null_steps = 0;
  int score = align_status->score;
  *out_cigar=malloc(wf_aligner->pattern_length+wf_aligner->text_length);
  *cigar_valid_len=0;
  int pattern_so_far=0;
  int text_so_far=0;
  const char* ori_pattern=pattern;
  const char* ori_text=text;
  vector_t pattern_consumed_vec;
  vector_t text_consumed_vec;
  vector_t end_state_consumed_vec;
  int tile_cnt=0;
  const int max_score_scope = wf_aligner->wf_components.max_score_scope;
  while(true){
    int converged_scores=0;
    wf_offset_t converged_idx=IDX_MISMATCH;
    while (true) {
      // Exact extend s-wavefront
      const int finished = (*wf_align_extend)(wf_aligner,score);
      if (finished) {
        // DEBUG
        // wavefront_aligner_print(stderr,wf_aligner,0,score,7,0);
        if (align_status->status == WF_STATUS_END_REACHED) {
          if (score>=wf_aligner->marking_score+max_score_scope){
            const bool memory_modular = wf_aligner->wf_components.memory_modular;
            const int score_mod = (memory_modular) ? score % max_score_scope : score;
            wavefront_t* const mwavefront = wf_aligner->wf_components_pass_marking.mwavefronts[score_mod];
            const int alignment_end_k = wf_aligner->alignment_end_pos.k;
            converged_idx=mwavefront->diag_idx[alignment_end_k];
            break;
          }else{
            wavefront_unialign_terminate(wf_aligner,score);
          }
        }
        concat_cigar(wf_aligner,out_cigar,cigar_valid_len);
        return align_status->status;
      }else{
        int wavefront_length=wf_length(wf_aligner,score);
        stats->longest_wavefront=MAX(stats->longest_wavefront,wavefront_length);
        if (score<(wf_aligner->marking_score+max_score_scope)){
            stats->pre_marking_cells+=wavefront_length;
            converged_idx=IDX_MISMATCH;
            converged_scores=0;
        }else{
          wf_offset_t this_converged_idx=test_converged_score(wf_aligner,score);
          stats->post_marking_cells+=wf_length(wf_aligner,score);
          if (converged_idx==IDX_MISMATCH){
            converged_idx=this_converged_idx;
            converged_scores=0;
          }else{
            converged_idx=accumulate_converge_idx(converged_idx,this_converged_idx);
            converged_scores=converged_idx==IDX_MISMATCH?0:(converged_scores+1);
          }
          if (converged_scores==max_score_scope){
            break;
          }
        }
      }
      // Compute (s+1)-wavefront
      ++score;
      (*wf_align_compute)(wf_aligner,score);
      // Probe limits
      if (wavefront_unialign_reached_limits(wf_aligner,score)) return align_status->status;
      // Plot
      // DEBUG
      //wavefront_aligner_print(stderr,wf_aligner,score,score,7,0);
    }
    // Parameters
    const int alignment_conv_k = K_FROM_IDX(converged_idx);
    wavefront_t* bt_start_wf=fetch_wavefront_from_conv_idx(wf_aligner,converged_idx);
    const wf_offset_t alignment_end_offset=bt_start_wf->offsets[alignment_conv_k];
    
    if (wf_aligner->wf_components.bt_piggyback) {
      // Backtrace alignment from buffer (unpacking pcigar)
      wavefront_backtrace_pcigar(
          wf_aligner,alignment_conv_k,alignment_end_offset,
          bt_start_wf->bt_pcigar[alignment_conv_k],
          bt_start_wf->bt_prev[alignment_conv_k],false);
    } else {
      // Backtrace alignment
      if (wf_aligner->penalties.distance_metric <= gap_linear) {
        wavefront_backtrace_linear(wf_aligner,
            score,alignment_conv_k,alignment_end_offset);
      } else {
        wavefront_backtrace_affine(wf_aligner,
            wf_aligner->component_begin,wf_aligner->component_end,
            score,alignment_conv_k,alignment_end_offset);
      }
    }
    concat_cigar(wf_aligner,out_cigar,cigar_valid_len);
    if ((*out_cigar)[*cigar_valid_len -1]=='X')
    {
      //raise(SIGTRAP);
    }
    if (tile_cnt==59)
    {
      //raise(SIGTRAP);
    }
    
    wavefront_align_unidirectional_cleanup(wf_aligner);
    int pattern_consumed=WAVEFRONT_V(alignment_conv_k,alignment_end_offset);
    int text_consumed=WAVEFRONT_H(alignment_conv_k,alignment_end_offset);
    check_cigar(wf_aligner->cigar->operations+wf_aligner->cigar->begin_offset,(wf_aligner->cigar->end_offset-wf_aligner->cigar->begin_offset)
      ,pattern,text,pattern_consumed,text_consumed);
    pattern+=pattern_consumed;
    pattern_so_far+=pattern_consumed;
    text_so_far+=text_consumed;
    text+=text_consumed;
    pattern_length-=pattern_consumed;
    text_length-=text_consumed;
    check_cigar(*out_cigar,*cigar_valid_len,ori_pattern,ori_text,pattern_so_far,text_so_far);
    affine2p_matrix_type start_type=affine2p_matrix_M;
    switch (TYPE_FROM_IDX(converged_idx))
    {
    case IDX_TYPE_INS:
      start_type=affine2p_matrix_I1;
      break;
    case IDX_TYPE_DEL:
      start_type=affine2p_matrix_D1;
      break;
    case IDX_TYPE_MIS:
      start_type=affine2p_matrix_M;
      break;
    default:
      raise(SIGTRAP);
    }
    /*vector_insert(&pattern_consumed_vec,pattern_consumed,int);
    vector_insert(&text_consumed_vec,text_consumed,int);
    vector_insert(&end_state_consumed_vec,start_type,affine2p_matrix_type);*/
    tile_cnt++;

    wavefront_unialign_init(
      wf_aligner,
      pattern,pattern_length,
      text,text_length,
      start_type,affine2p_matrix_M);
    score=0;
  }
  // Return OK
  align_status->score = score;
  align_status->status = WF_STATUS_SUCCESSFUL;
  return WF_STATUS_SUCCESSFUL;
}

/*
 * Display
 */
void wavefront_unialign_print_status(
    FILE* const stream,
    wavefront_aligner_t* const wf_aligner,
    const int score) {
  // Parameters
  wavefront_components_t* const wf_components = &wf_aligner->wf_components;
  // Approximate progress
  const int dist_total = MAX(wf_aligner->text_length,wf_aligner->pattern_length);
  int s = (wf_components->memory_modular) ? score%wf_components->max_score_scope : score;
  wavefront_t* wavefront = wf_components->mwavefronts[s];
  if (wavefront==NULL && s>0) {
    s = (wf_components->memory_modular) ? (score-1)%wf_components->max_score_scope : (score-1);
    wavefront = wf_components->mwavefronts[s];
  }
  int dist_max = -1, wf_len = -1, k;
  if (wavefront!=NULL) {
    wf_offset_t* const offsets = wavefront->offsets;
    for (k=wavefront->lo;k<=wavefront->hi;++k) {
      const int dist = MAX(WAVEFRONT_V(k,offsets[k]),WAVEFRONT_H(k,offsets[k]));
      dist_max = MAX(dist_max,dist);
    }
    wf_len = wavefront->hi-wavefront->lo+1;
  }
  // Memory used
  const uint64_t slab_size = wavefront_slab_get_size(wf_aligner->wavefront_slab);
  const uint64_t bt_buffer_used = (wf_components->bt_buffer) ?
      wf_backtrace_buffer_get_size_used(wf_components->bt_buffer) : 0;
  // Progress
  const float aligned_progress = (dist_max>=0) ? (100.0f*(float)dist_max/(float)dist_total) : -1.0f;
  const float million_offsets = (wf_len>=0) ? (float)wf_len/1000000.0f : -1.0f;
  // Print one-line status
  fprintf(stream,"[");
  wavefront_aligner_print_type(stream,wf_aligner);
  fprintf(stream,
      "] SequenceLength=(%d,%d) Score %d (~ %2.3f%% aligned). "
      "MemoryUsed(WF-Slab,BT-buffer)=(%lu MB,%lu MB). "
      "Wavefronts ~ %2.3f Moffsets\n",
      wf_aligner->pattern_length,wf_aligner->text_length,score,aligned_progress,
      CONVERT_B_TO_MB(slab_size),CONVERT_B_TO_MB(bt_buffer_used),million_offsets);
}
