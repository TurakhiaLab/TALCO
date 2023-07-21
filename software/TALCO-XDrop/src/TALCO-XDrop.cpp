#include "TALCO-XDrop.hpp"
#include <iostream>
#include <stdlib.h>
#include <string.h>
#include <fstream>
#include <vector>
#include <ctime>
#include <unordered_map>

#define DEBUG false

int Talco_xdrop::Score (
    Params params,
    const std::vector<int8_t> &aln,
    const std::string &reference,
    const std::string &query,
    const int ref_idx,
    const int query_idx
){  
    int score = 0;
    int ridx = ref_idx, qidx = query_idx;
    int m = 0,mm= 0,go=0,ge=0;
    // printf ("aln: %d\n",aln.size());
    for (int i = aln.size() - 1; i >= 0; i--){
        int8_t state = aln[i];	
        // printf ("state %d, ri %d, qi %d", state, ridx, qidx);
        if (state == 0) { // Current State M	
            if (reference[ridx] == query[qidx]){	
                score += params.match;
                m++;	
            } else {	
                score += params.mismatch;
                mm++;	
            }	
            ridx--;	
            qidx--;	
        } else if (state == 1) { // Current State I	
            if (i < aln.size() - 1 && aln[i+1] == 1) {	
                score += params.gapExtend;
                ge++;	
            } else {	
                score += params.gapOpen;
                go++;	
            }	
            qidx--;	

        } else { // Current State D	
            if (i < aln.size() - 1 && aln[i+1] == 2) {	
                score += params.gapExtend;	
                ge++;	
            } else {	
                score += params.gapOpen;	
                go++;	
            }	
            ridx--;	
        }	
        // printf(" Score: %d\n", score);
    }
    // printf("count %d %d %d %d, ridx %d, qidx %d\n", m, mm, go ,ge, ridx, qidx);

    return score;
    
}

void Talco_xdrop::Align (
    Params params,
    const std::vector<std::string>& reference,
    const std::vector<std::string>& query,
    size_t num_alignments
    ) {
        
        clock_t start, end;
        double time = 0;
        int count = 0;
        // n -> alignment number
        for (size_t n = 0; n < num_alignments; n++) {
        
            std::vector<int8_t> aln;
            int8_t state;
            int score;
            // std::cout << reference[n] << " " << query[n] << " " << std::endl;

            // initialising variables
            int32_t reference_idx, query_idx;
            reference_idx = 0; query_idx = 0;
            bool last_tile = false;
            
            int tile = 0;
            while (!last_tile) {
                std::vector<int8_t> tile_aln;
                Talco_xdrop::Tile(reference[n], query[n], params, reference_idx, query_idx, tile_aln, state, last_tile);
                for (int i= tile_aln.size()-1; i>=0; i--){
                    if (i == tile_aln.size()-1 && tile>0){
                        continue;
                    }
                    aln.push_back(tile_aln[i]);
                }
                tile_aln.clear();
                if (DEBUG) printf("Tile: %d, (r,q) = (%d,%d)\n",tile++, reference_idx, query_idx);
            }
            score = Score(params, aln, reference[n], query[n], reference_idx, query_idx);
            

            printf("Alignment (Length, Score): (%d, %d)\n ", aln.size(), score);

        }
        
        // printf("%f\n", time);
        // printf("%d\n", count);

    }

int32_t Talco_xdrop::Reduction_tree(const int32_t *C, const int32_t start, const int32_t length){
    int32_t conv = C[start];
    for (int32_t i = start + 1; i <= start + length; i++ ){
        if (conv != C[i]){
            conv = -1;
            break;
        } 
    }
    return conv;
}

void Talco_xdrop::Traceback(
    const std::vector<int32_t> &ftr_length, 
    const std::vector<int32_t> &ftr_lower_limit, 
    const int32_t tb_start_addr, 
    const int16_t tb_start_ftr,
    const int8_t tb_state,
    const int16_t tb_start_idx,
    const std::vector<int8_t> &tb,
    std::vector<int8_t> &aln
){
    int32_t addr = tb_start_addr; 
    int16_t ftr = tb_start_ftr;
    int16_t idx = tb_start_idx;
    int8_t  state = tb_state;
    int8_t  tb_value = 0;

    while (ftr >= 0) {
        if (addr < 0) {
            fprintf(stderr, "ERROR: tb addr < 0!\n");
            exit(1);
        }
        
        
        tb_value = tb[addr];
        if (DEBUG) {
            std::cout << "Start Addr:" << addr << " state: " << (state & 0xFFFF) << " ,ftr: " << ftr << " ,idx: " << idx << " ,ll[ftr-1]: " <<  ftr_lower_limit[ftr];
            std::cout << " fL[ftr - 1]: " << ftr_length[ftr - 1] << " ,ll[ftr-2]: " <<  ftr_lower_limit[ftr-2];
            std::cout << " fL[ftr - 2]: " << ftr_length[ftr - 2];
            std::cout << " Tb: " << ( tb_value&0xFFFF);
        }
        
        if (state == 0) { // Current State M
            state = tb_value & 0x03;
        } else if (state == 1) { // Current State I
            if (tb_value & 0x04) {
                state = 1;
            } else {
                state = 0;
            }
        } else { // Current State D
            if (tb_value & 0x08) {
                state = 2;
            } else {
                state = 0;
            }
        }

        addr = addr - (idx  - ftr_lower_limit[ftr] + 1) - (ftr_length[ftr - 1]);
        if (state == 0){
            addr = addr - (ftr_length[ftr - 2]) + (idx - ftr_lower_limit[ftr  - 2]);
            ftr -= 2;
            idx -= 1;
        }else if (state == 1){
            addr = addr + (idx - ftr_lower_limit[ftr  - 1]);
            ftr -= 1;
            idx -=1;
        }else{
            addr = addr + (idx - ftr_lower_limit[ftr  - 1] + 1);
            ftr -= 1;
        }

        aln.push_back(state);
        if (DEBUG) std::cout << " Final State: " << (state&0xFF) << " End Addr: " << addr << std::endl;
    }
}

void Talco_xdrop::Tile (
    const std::string &reference,
    const std::string &query,
    Params params,
    int32_t &reference_idx,
    int32_t &query_idx,
    std::vector<int8_t> &aln,
    int8_t &state,
    bool &last_tile 
    ) {
        
        // Initialising variables
        int32_t inf = params.xdrop + 1;
        int32_t fLen = (1 << 10); // frontier length (assuming anti-diagonal length cannot exceed 1024)
        bool converged = false; bool conv_logic = false;
        int32_t reference_length = reference.size() - reference_idx; 
        int32_t query_length = query.size() - query_idx;
        int32_t score = 0; int32_t max_score = 0; int32_t max_score_prime = -inf; int32_t max_score_ref_idx = 0; int32_t max_score_query_idx = 0;
        int32_t conv_score = 0; int32_t conv_value = 0; int32_t conv_ref_idx = 0; int32_t conv_query_idx = 0; 
        int32_t tb_start_addr = 0; int32_t tb_start_ftr = 0; int32_t max_score_start_addr = 0; int32_t max_score_start_ftr = 0;
        int8_t tb_state = 0;
        int8_t ptr = 0;  // Main pointer
        bool Iptr = false;
        bool Dptr = false; // I and D states; xx00 -> M, x001 -> I (M) open, x101 -> I (I) extend, 0x10 -> D (M) open, 1x10 -> D (D) extend

        int32_t L[3], U[3];
        int16_t *S[3], *I[2], *D[2];
        int32_t *CS[3], *CI[2], *CD[2];
        std::vector<int8_t> tb;
        std::vector<int32_t> ftr_length;
        std::vector<int32_t> ftr_lower_limit;
        int32_t ftr_addr = 0;

        int32_t prev_conv_s = -1;
        
        
        for (size_t sIndx=0; sIndx<3; sIndx++) { // Allocate memory for S, I, D, and CS array
            S[sIndx] = (int16_t*) std::malloc(fLen*sizeof(int16_t));
            CS[sIndx] = (int32_t*) std::malloc(fLen*sizeof(int32_t));
            if (sIndx < 2) {
                I[sIndx] = (int16_t*) std::malloc(fLen*sizeof(int16_t));
                D[sIndx] = (int16_t*) std::malloc(fLen*sizeof(int16_t));
                CI[sIndx] = (int32_t*) std::malloc(fLen*sizeof(int32_t));
                CD[sIndx] = (int32_t*) std::malloc(fLen*sizeof(int32_t));
            }
            L[sIndx] = sIndx;
            U[sIndx] = -sIndx;
        }

        
        for (int16_t sIndx=0; sIndx<3; sIndx++){ // Initialise memory for S, I, D array
            for (int16_t sLenIndex=0; sLenIndex<fLen; sLenIndex++){
                S[sIndx][sLenIndex] = -1;
                CS[sIndx][sLenIndex] = -1;
                if (sIndx < 2) {
                    I[sIndx][sLenIndex] = -1;
                    D[sIndx][sLenIndex] = -1;
                    CI[sIndx][sLenIndex] = -1;
                    CD[sIndx][sLenIndex] = -1;
                }
            }
        }

        if ((reference_length < 0) || (query_length < 0)) {
            std::cout << reference_length << " " << query_length << std::endl;
            fprintf(stderr, "ERROR: Reference/Query index exceeded limit!\n");
            exit(1); 
        }

        // printf("r,q length: %d,%d", reference_length, query_length);
        for (int32_t k = 0; k < reference_length + query_length - 1; k++){
                    // printf("k: %d\n", k);
            if (L[k%3] >= U[k%3]+1) { // No more cells to compute based on x-drop critieria
                std::cout << "No more cells to compute based on x-drop critieria" << std::endl;
                break;
            }
            
            if (U[k%3]-L[k%3]+1 > fLen) { // Limit the size of the anti-diagonal
                fprintf(stderr, "ERROR: anti-diagonal larger than the max limit!\n");
                exit(1);
            }

            if (k <= params.marker) {
                ftr_length.push_back(U[k%3] - L[k%3] + 1);
                ftr_lower_limit.push_back(L[k%3]);
                ftr_addr += U[k%3] - L[k%3] + 1;
                // std::cout << "ftr length: " << U[k%3] - L[k%3] + 1 << " ftr_addr: " << ftr_addr << " ftr lower limit: " << L[k%3] << " tb len: " << tb.size() << std::endl;
            }
            
            for (int16_t i = L[k%3]; i < U[k%3]+1; i++) { // i-> query_idx, j -> reference_idx
                int16_t Lprime = std::max(0, static_cast<int16_t>(k)-static_cast<int16_t>(reference_length) + 1); 
                int16_t j = std::min(static_cast<int16_t>(k), static_cast<int16_t>(reference_length - 1)) - (i-Lprime); 
                
                if (j < 0) {
                    fprintf(stderr, "ERROR: j less than 0.\n");
                    exit(1);
                }

                int32_t match = -inf, insOp = -inf, delOp = -inf, insExt = -inf, delExt = -inf;
                int32_t offset = i-L[k%3];
                int32_t offsetDiag = L[k%3]-L[(k+1)%3]+offset-1;
                int32_t offsetUp = L[k%3]-L[(k+2)%3]+offset;
                int32_t offsetLeft = L[k%3]-L[(k+2)%3]+offset-1;

                

                if ((k==0) || ((offsetDiag >= 0) && (offsetDiag <= U[(k+1)%3]-L[(k+1)%3]))) {
                    if (reference[reference_idx+j] == query[query_idx+i]) {
                        match = S[(k+1)%3][offsetDiag] + params.match;
                    }
                    else {
                        match = S[(k+1)%3][offsetDiag] + params.mismatch;
                    }
                }

                if ((offsetUp >= 0) && (offsetUp <= U[(k+2)%3]-L[(k+2)%3])) {
                    delOp = S[(k+2)%3][offsetUp] + params.gapOpen;
                    delExt = D[(k+1)%2][offsetUp] + params.gapExtend;
                }
                
                if ((offsetLeft >= 0) && (offsetLeft <= U[(k+2)%3]-L[(k+2)%3])) {
                    insOp = S[(k+2)%3][offsetLeft] + params.gapOpen;
                    insExt = I[(k+1)%2][offsetLeft] + params.gapExtend;
                }

                I[k%2][offset] = insOp;
                D[k%2][offset] = delOp;
                Iptr = false;
                Dptr = false;


                if (insExt > insOp) {
                    I[k%2][offset] = insExt;
                    Iptr = true;
                }
                if (delExt > delOp) {
                    D[k%2][offset] = delExt;
                    Dptr = true;
                }

                if (match >= I[k%2][offset]) {
                    if (match >= D[k%2][offset]) {
                        S[k%3][offset] = match;
                        ptr = 0;
                    }
                    else {
                        S[k%3][offset] = D[k%2][offset];
                        ptr = 2;
                    }
                }
                else if (I[k%2][offset] >= D[k%2][offset]) {
                    S[k%3][offset] = I[k%2][offset];
                    ptr = 1;
                }
                else {
                    S[k%3][offset] = D[k%2][offset];
                    ptr = 2;
                }
                

                if (S[k%3][offset] < max_score-params.xdrop) {
                    S[k%3][offset] = -inf;
                }

                score = S[k%3][offset];

                if (max_score_prime < score) {
                    max_score_prime = score;
                    if (k <= params.marker) {
                        max_score_ref_idx = j;
                        max_score_query_idx = i;
                        max_score_start_addr = ftr_addr - (U[k%3] - L[k%3] + 1)  + (i - L[k%3]);
                        max_score_start_ftr = k;
                    }
                }

                if (k == params.marker - 1) { // Convergence algorithm
                    CS[k%3][offset] = (3 << 16) + (i & 0xFFFF); 
                    if(DEBUG) std::cout << "Convergence Unique Id's: " <<  CS[k%3][offset] << "\n";
                } else if (k == params.marker) {
                    CS[k%3][offset] = (0 << 16) | (i & 0xFFFF);  // to extract value use (CS[k%3][offset] & 0xFFFF)
                    CI[k%2][offset] = (1 << 16) | (i & 0xFFFF);
                    CD[k%2][offset] = (2 << 16) | (i & 0xFFFF);
                    if(DEBUG) std::cout << "Convergence Unique Id's: " <<  CS[k%3][offset] <<  " " << CI[k%2][offset] <<  " " << CD[k%2][offset] << "\n";
                } 
                else if (k >= params.marker + 1){
                    if (Iptr) {
                        CI[k%2][offset] = CI[(k+1)%2][offsetLeft]; 
                    } else {
                        CI[k%2][offset] = CS[(k+2)%3][offsetLeft]; 
                    }

                    if (Dptr) {
                        CD[k%2][offset] = CD[(k+1)%2][offsetUp];
                    } else {
                        CD[k%2][offset] = CS[(k+2)%3][offsetUp];
                    }

                    if (ptr == 0) {
                        CS[k%3][offset] = CS[(k+1)%3][offsetDiag];
                    } else if (ptr == 1) {
                        CS[k%3][offset] = CI[k%2][offset];
                    } else {
                        CS[k%3][offset] = CD[k%2][offset];
                    } 
                }
                if (Iptr) {
                    // std::cout << (ptr & 0xFF) << " ";
                    ptr |= 0x04; 
                    // std::cout << (ptr & 0xFF) << "\n";
                }
                if (Dptr) {
                    // std::cout << (ptr & 0xFF) << " ";
                    ptr |= 0x08;
                    // std::cout << (ptr & 0xFF) << "\n";
                }
                if (k <= params.marker){
                    tb.push_back(ptr);
                    // std::cout << (ptr & 0xFFFF) << " ";
                }
                // std:: cout << CS[k%3][offset] << " ";
            }
            // std::cout << "\n";

            int32_t newL = L[k%3];
            int32_t newU = U[k%3];

            while (newL <= U[k%3]) {
                int32_t offset = newL - L[k%3];
                if (S[k%3][offset] <= -inf) {
                    newL++;
                }
                else {
                    break;
                }
            }

            while (newU >= L[k%3]) {
                int32_t offset = newU - L[k%3];
                if (S[k%3][offset] <= -inf) {
                    newU--;
                }
                else {
                    break;
                }
            }

            if ((!converged) && (k < reference_length + query_length - 2)) {
                int32_t conv_I = Reduction_tree(CI[k%2], newL - L[k%3], newU - newL);
                int32_t conv_D = Reduction_tree(CD[k%2], newL - L[k%3], newU - newL);
                int32_t conv_S = Reduction_tree(CS[k%3], newL - L[k%3], newU - newL);
                
                if ((conv_I == conv_D) && (conv_I == conv_S) && (prev_conv_s == conv_S) && (conv_I != -1)){
                    converged = true; 
                    conv_value = prev_conv_s;
                    conv_score = max_score_prime;
                    if (DEBUG)  std::cout << "Converged at: " << conv_value << "\n";
                }
                prev_conv_s = conv_S;
            }


            int32_t v1 = static_cast<int32_t>(query_length)-1;
            int32_t v2 = static_cast<int32_t>(k)+2-static_cast<int32_t>(reference_length);
            int32_t v3 = newU+1;

            int32_t Lprime = std::max(static_cast<int32_t>(0), v2);
            
            L[(k+1)%3] = std::max(newL, Lprime);
            U[(k+1)%3] = std::min(v1, v3); 
            
            // Update max_score
            max_score = max_score_prime;

            if ((converged) && (max_score > conv_score)){
                conv_logic = true;
                if (DEBUG) std::cout << "Convergence logic found: ";
                break;
            }
        }
        // Deallocate memory for scores
        for (size_t sIndx=0; sIndx<3; sIndx++) {
            std::free(S[sIndx]);
            std::free(CS[sIndx]);
            if (sIndx < 2) {
                std::free(I[sIndx]);
                std::free(D[sIndx]);
                std::free(CI[sIndx]);
                std::free(CD[sIndx]);
            }
        }
        if (DEBUG) std::cout <<  "Frontier addr: " << ftr_addr << " \ntb_start_ftr: " << ftr_length.size() << "\nmarker: " << params.marker << std::endl;
        if (conv_logic) {
            conv_query_idx = conv_value & 0xFFFF;
            tb_state = (conv_value >> 16) & 0xFFFF;
            conv_ref_idx = params.marker - conv_query_idx; 
            conv_ref_idx -= (tb_state == 3) ? 1: 0;
            tb_start_addr = ftr_addr - ftr_length[ftr_length.size() - 1];
            tb_start_addr = (tb_state == 3) ? tb_start_addr - ftr_length[ftr_length.size() - 2] + (conv_query_idx - ftr_lower_limit[ftr_lower_limit.size() - 2]) : tb_start_addr +  (conv_query_idx - ftr_lower_limit[ftr_lower_limit.size() - 1]);
            tb_start_ftr = (tb_state == 3) ? ftr_length.size() - 2: ftr_length.size() - 1;
            if (DEBUG) std::cout <<  " conv query idx: " << conv_query_idx << " " << (tb_state&0xFFFF) << " " << conv_ref_idx << " " << conv_value << std::endl;
        } else {
            conv_query_idx = max_score_query_idx;
            conv_ref_idx = max_score_ref_idx;
            tb_start_addr = max_score_start_addr;
            tb_start_ftr = max_score_start_ftr;
            tb_state = 0;
            last_tile = true;
        }

        reference_idx += conv_ref_idx;
        query_idx += conv_query_idx;
        // std::cout <<  "Ref idx: " << reference_idx << " \nQuery idx: " << query_idx << std::endl;
        if (DEBUG) std::cout <<  "tb_start_addr: " << tb_start_addr << " \ntb_start_ftr: " << tb_start_ftr << std::endl;

        Traceback(ftr_length, ftr_lower_limit, tb_start_addr, tb_start_ftr, (tb_state%3), conv_query_idx, tb, aln);
        state = tb_state%3;
        if (DEBUG) {
            std::cout << "tb_state: " <<  (tb_state & 0xFFFF) << std::endl;
            int count = 0;
            for (auto &a: aln){
                std::cout << count << ": " << (a & 0xFFFF) << "\n";
                count += 1;
            }
        }

        

    }