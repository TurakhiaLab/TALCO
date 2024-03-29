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
 * DESCRIPTION: WaveFront alignment module for computing wavefronts (gap-affine)
 */

#include "utils/commons.h"
#include "system/mm_allocator.h"
#include "utils/string_padded.h"
#include "wavefront_compute.h"
#include "wavefront_backtrace_offload.h"

#ifdef WFA_PARALLEL
#include <omp.h>
#endif

/*
 * Compute Kernels
 */
void wavefront_compute_affine_idm(
    wavefront_aligner_t* const wf_aligner,
    const wavefront_set_t* const wavefront_set,
    const int lo,
    const int hi,
    bool compute_idx) {
  // Parameters
  const int pattern_length = wf_aligner->pattern_length;
  const int text_length = wf_aligner->text_length;
  // In Offsets
  const wf_offset_t* const m_misms = wavefront_set->in_mwavefront_misms->offsets;
  const wf_offset_t* const m_open1 = wavefront_set->in_mwavefront_open1->offsets;
  const wf_offset_t* const i1_ext = wavefront_set->in_i1wavefront_ext->offsets;
  const wf_offset_t* const d1_ext = wavefront_set->in_d1wavefront_ext->offsets;
  // In idx
  const wf_offset_t* const m_misms_idx = wavefront_set->in_mwavefront_misms->diag_idx;
  const wf_offset_t* const m_open1_idx = wavefront_set->in_mwavefront_open1->diag_idx;
  const wf_offset_t* const i1_ext_idx = wavefront_set->in_i1wavefront_ext->diag_idx;
  const wf_offset_t* const d1_ext_idx = wavefront_set->in_d1wavefront_ext->diag_idx;
  // Out Offsets
  wf_offset_t* const out_m = wavefront_set->out_mwavefront->offsets;
  wf_offset_t* const out_i1 = wavefront_set->out_i1wavefront->offsets;
  wf_offset_t* const out_d1 = wavefront_set->out_d1wavefront->offsets;
  //Out idx
  wf_offset_t* const out_m_idx = wavefront_set->out_mwavefront->diag_idx;
  wf_offset_t* const out_i1_idx = wavefront_set->out_i1wavefront->diag_idx;
  wf_offset_t* const out_d1_idx = wavefront_set->out_d1wavefront->diag_idx;
  // Compute-Next kernel loop
  int k;
  PRAGMA_LOOP_VECTORIZE
  for (k=lo;k<=hi;++k) {
    // Update I1
    const wf_offset_t ins1_o = m_open1[k-1];
    const wf_offset_t ins1_e = i1_ext[k-1];
    const wf_offset_t ins1 = MAX(ins1_o,ins1_e) + 1;
    if (compute_idx){
      out_i1_idx[k]=(ins1_e>=ins1_o)?i1_ext_idx[k-1]:m_open1_idx[k-1];
    }
    out_i1[k] = ins1;
    // Update D1
    const wf_offset_t del1_o = m_open1[k+1];
    const wf_offset_t del1_e = d1_ext[k+1];
    const wf_offset_t del1 = MAX(del1_o,del1_e);
    if (compute_idx){
      out_d1_idx[k]=(del1_e>=del1_o)?d1_ext_idx[k+1]:m_open1_idx[k+1];
    }
    out_d1[k] = del1;
    // Update M
    const wf_offset_t misms = m_misms[k] + 1;
    wf_offset_t max = MAX(del1,MAX(misms,ins1));
    if (compute_idx){
      if (max == ins1) {
        out_m_idx[k]=out_i1_idx[k];
      }
      if (max == del1) {
        out_m_idx[k]=out_d1_idx[k];
      }
      if (max == misms) {
        out_m_idx[k]=m_misms_idx[k];
      }
      if ((SCORE_FROM_IDX(out_i1_idx[k])>wf_aligner->wf_components.max_score_scope&&out_i1_idx[k]!=IDX_DONT_CARE)||out_i1_idx[k]==0){
        raise(SIGTRAP);
      }
      if ((SCORE_FROM_IDX(out_d1_idx[k])>wf_aligner->wf_components.max_score_scope&&out_d1_idx[k]!=IDX_DONT_CARE)||out_d1_idx[k]==0){
        raise(SIGTRAP);
      }
      if ((SCORE_FROM_IDX(out_m_idx[k])>wf_aligner->wf_components.max_score_scope&&out_m_idx[k]!=IDX_DONT_CARE)||out_m_idx[k]==0){
        raise(SIGTRAP);
      }
    }
    // Adjust offset out of boundaries !(h>tlen,v>plen) (here to allow vectorization)
    const wf_unsigned_offset_t h = WAVEFRONT_H(k,max); // Make unsigned to avoid checking negative
    const wf_unsigned_offset_t v = WAVEFRONT_V(k,max); // Make unsigned to avoid checking negative
    if (h > text_length) max = WAVEFRONT_OFFSET_NULL;
    if (v > pattern_length) max = WAVEFRONT_OFFSET_NULL;
    out_m[k] = max;
  }
}
/*
 * Compute Kernel (Piggyback)
 */
void wavefront_compute_affine_idm_piggyback(
    wavefront_aligner_t* const wf_aligner,
    const wavefront_set_t* const wavefront_set,
    const int lo,
    const int hi,
    bool compute_idx) {
  if (compute_idx)
  {
    raise(SIGTRAP);
  }
  
  // Parameters
  const int pattern_length = wf_aligner->pattern_length;
  const int text_length = wf_aligner->text_length;
  // In Offsets
  const wf_offset_t* const m_misms = wavefront_set->in_mwavefront_misms->offsets;
  const wf_offset_t* const m_open1 = wavefront_set->in_mwavefront_open1->offsets;
  const wf_offset_t* const i1_ext  = wavefront_set->in_i1wavefront_ext->offsets;
  const wf_offset_t* const d1_ext  = wavefront_set->in_d1wavefront_ext->offsets;
  // Out Offsets
  wf_offset_t* const out_m  = wavefront_set->out_mwavefront->offsets;
  wf_offset_t* const out_i1 = wavefront_set->out_i1wavefront->offsets;
  wf_offset_t* const out_d1 = wavefront_set->out_d1wavefront->offsets;
  // In BT-pcigar
  const pcigar_t* const m_misms_bt_pcigar = wavefront_set->in_mwavefront_misms->bt_pcigar;
  const pcigar_t* const m_open1_bt_pcigar = wavefront_set->in_mwavefront_open1->bt_pcigar;
  const pcigar_t* const i1_ext_bt_pcigar  = wavefront_set->in_i1wavefront_ext->bt_pcigar;
  const pcigar_t* const d1_ext_bt_pcigar  = wavefront_set->in_d1wavefront_ext->bt_pcigar;
  // In BT-prev
  const bt_block_idx_t* const m_misms_bt_prev = wavefront_set->in_mwavefront_misms->bt_prev;
  const bt_block_idx_t* const m_open1_bt_prev = wavefront_set->in_mwavefront_open1->bt_prev;
  const bt_block_idx_t* const i1_ext_bt_prev  = wavefront_set->in_i1wavefront_ext->bt_prev;
  const bt_block_idx_t* const d1_ext_bt_prev  = wavefront_set->in_d1wavefront_ext->bt_prev;
  // Out BT-pcigar
  pcigar_t* const out_m_bt_pcigar   = wavefront_set->out_mwavefront->bt_pcigar;
  pcigar_t* const out_i1_bt_pcigar  = wavefront_set->out_i1wavefront->bt_pcigar;
  pcigar_t* const out_d1_bt_pcigar  = wavefront_set->out_d1wavefront->bt_pcigar;
  // Out BT-prev
  bt_block_idx_t* const out_m_bt_prev  = wavefront_set->out_mwavefront->bt_prev;
  bt_block_idx_t* const out_i1_bt_prev = wavefront_set->out_i1wavefront->bt_prev;
  bt_block_idx_t* const out_d1_bt_prev = wavefront_set->out_d1wavefront->bt_prev;
  // Compute-Next kernel loop
  int k;
  PRAGMA_LOOP_VECTORIZE // Ifs predicated by the compiler
  for (k=lo;k<=hi;++k) {
    // Update I1
    const wf_offset_t ins1_o = m_open1[k-1];
    const wf_offset_t ins1_e = i1_ext[k-1];
    wf_offset_t ins1;
    pcigar_t ins1_pcigar;
    bt_block_idx_t ins1_block_idx;
    if (ins1_e >= ins1_o) {
      ins1 = ins1_e;
      ins1_pcigar = i1_ext_bt_pcigar[k-1];
      ins1_block_idx = i1_ext_bt_prev[k-1];
    } else {
      ins1 = ins1_o;
      ins1_pcigar = m_open1_bt_pcigar[k-1];
      ins1_block_idx = m_open1_bt_prev[k-1];
    }
    
    out_i1_bt_pcigar[k] = PCIGAR_PUSH_BACK_INS(ins1_pcigar);
    out_i1_bt_prev[k] = ins1_block_idx;
    out_i1[k] = ++ins1;
    // Update D1
    const wf_offset_t del1_o = m_open1[k+1];
    const wf_offset_t del1_e = d1_ext[k+1];
    wf_offset_t del1;
    pcigar_t del1_pcigar;
    bt_block_idx_t del1_block_idx;
    if (del1_e >= del1_o) {
      del1 = del1_e;
      del1_pcigar = d1_ext_bt_pcigar[k+1];
      del1_block_idx = d1_ext_bt_prev[k+1];
    } else {
      del1 = del1_o;
      del1_pcigar = m_open1_bt_pcigar[k+1];
      del1_block_idx = m_open1_bt_prev[k+1];
    }
    out_d1_bt_pcigar[k] = PCIGAR_PUSH_BACK_DEL(del1_pcigar);
    out_d1_bt_prev[k] = del1_block_idx;
    out_d1[k] = del1;
    // Update M
    const wf_offset_t misms = m_misms[k] + 1;
    wf_offset_t max = MAX(del1,MAX(misms,ins1));
    if (max == ins1) {
      out_m_bt_pcigar[k] = out_i1_bt_pcigar[k];
      out_m_bt_prev[k] = out_i1_bt_prev[k];
    }
    if (max == del1) {
      out_m_bt_pcigar[k] = out_d1_bt_pcigar[k];
      out_m_bt_prev[k] = out_d1_bt_prev[k];
    }
    if (max == misms) {
      out_m_bt_pcigar[k] = m_misms_bt_pcigar[k];
      out_m_bt_prev[k] = m_misms_bt_prev[k];
    }
    // Coming from I/D -> X is fake to represent gap-close
    // Coming from M -> X is real to represent mismatch
    out_m_bt_pcigar[k] = PCIGAR_PUSH_BACK_MISMS(out_m_bt_pcigar[k]);
    // Adjust offset out of boundaries !(h>tlen,v>plen) (here to allow vectorization)
    const wf_unsigned_offset_t h = WAVEFRONT_H(k,max); // Make unsigned to avoid checking negative
    const wf_unsigned_offset_t v = WAVEFRONT_V(k,max); // Make unsigned to avoid checking negative
    if (h > text_length) max = WAVEFRONT_OFFSET_NULL;
    if (v > pattern_length) max = WAVEFRONT_OFFSET_NULL;
    out_m[k] = max;
  }
}
/*
 * Compute Wavefronts (gap-affine)
 */
void wavefront_compute_affine_dispatcher(
    wavefront_aligner_t* const wf_aligner,
    wavefront_set_t* const wavefront_set,
    const int lo,
    const int hi,
    bool compute_idx,bool pass_marking) {
  // Parameters
  const bool bt_piggyback = wf_aligner->wf_components.bt_piggyback;
  const int num_threads = wavefront_compute_num_threads(wf_aligner,lo,hi);  
  // Multithreading dispatcher
  if (num_threads == 1) {
    // Compute next wavefront
    if (bt_piggyback&&(!pass_marking)) {
      wavefront_compute_affine_idm_piggyback(wf_aligner,wavefront_set,lo,hi,compute_idx);
    } else {
      wavefront_compute_affine_idm(wf_aligner,wavefront_set,lo,hi,compute_idx);
    }
  } else {
#ifdef WFA_PARALLEL
    // Compute next wavefront in parallel
    #pragma omp parallel num_threads(num_threads)
    {
      int t_lo, t_hi;
      const int thread_id = omp_get_thread_num();
      const int thread_num = omp_get_num_threads();
      wavefront_compute_thread_limits(thread_id,thread_num,lo,hi,&t_lo,&t_hi);
      if (bt_piggyback) {
        wavefront_compute_affine_idm_piggyback(wf_aligner,wavefront_set,t_lo,t_hi,compute_idx);
      } else {
        wavefront_compute_affine_idm(wf_aligner,wavefront_set,t_lo,t_hi,compute_idx);
      }
    }
#endif
  }
}
static void fill_wave_front_idx(int type,int score,int lo,int hi,wavefront_t* wf_idx){
  for (int i = lo; i <= hi; i++){
    wf_idx->diag_idx[i]=COMPOSE_IDX(type,i,score);    
  }
}
static void fill_wf_set_idx(int score,int lo,int hi,const wavefront_set_t* set){
  fill_wave_front_idx(IDX_TYPE_INS,score,lo,hi,set->out_i1wavefront);
  fill_wave_front_idx(IDX_TYPE_DEL,score,lo,hi,set->out_d1wavefront);
  fill_wave_front_idx(IDX_TYPE_MIS,score,lo,hi,set->out_mwavefront);
}
void wavefront_compute_affine(
    wavefront_aligner_t* const wf_aligner,
    const int score) {
      if (score==262)
      {
        //raise(SIGTRAP);
      }
  // Select wavefronts
  wavefront_set_t wavefront_set;
  wavefront_compute_fetch_input(wf_aligner,&wavefront_set,score);
  // Check null wavefronts
  if (wavefront_set.in_mwavefront_misms->null &&
      wavefront_set.in_mwavefront_open1->null &&
      wavefront_set.in_i1wavefront_ext->null &&
      wavefront_set.in_d1wavefront_ext->null) {
    wf_aligner->align_status.num_null_steps++; // Increment null-steps
    wavefront_compute_allocate_output_null(wf_aligner,score); // Null s-wavefront
    return;
  }
  int cur_marking_score_idx=score-wf_aligner->marking_score;
  bool allocate_idx=cur_marking_score_idx>=0;
  bool compute_idx=allocate_idx&&cur_marking_score_idx>=(wf_aligner->wf_components.max_score_scope);

  wf_aligner->align_status.num_null_steps = 0;
  // Set limits
  bool pass_marking=score>=wf_aligner->marking_score+wf_aligner->wf_components.max_score_scope;
  int hi, lo;
  wavefront_compute_limits_input(wf_aligner,&wavefront_set,&lo,&hi);
  // Allocate wavefronts
  wavefront_compute_allocate_output(wf_aligner,&wavefront_set,score,lo,hi,allocate_idx);
  // Init wavefront ends
  wavefront_compute_init_ends(wf_aligner,&wavefront_set,lo,hi);
  // Compute wavefronts
  if (score==35&&wf_aligner->pattern_length==4059&&wf_aligner->text_length==3938)
  {
    //raise(SIGTRAP);
  }
  
  wavefront_compute_affine_dispatcher(wf_aligner,&wavefront_set,lo,hi,compute_idx,pass_marking);
  // Offload backtrace (if necessary)
  if (allocate_idx&&!compute_idx){
    fill_wf_set_idx(cur_marking_score_idx,lo,hi,&wavefront_set);
  }
  if (wf_aligner->wf_components.bt_piggyback&&(!pass_marking)) {
    wavefront_backtrace_offload_affine(wf_aligner,&wavefront_set,lo,hi);
  }
  // Process wavefront ends
  wavefront_compute_process_ends(wf_aligner,&wavefront_set,score);
}
