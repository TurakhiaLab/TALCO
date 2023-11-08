#include <string>
#include <vector>
#include <iostream>
#include <fstream>
#include <omp.h>
#include "genasm_cpu.hpp"
#include "util.hpp"

using namespace std;

int cigar_read(std::string cigar, int affine){
    int score = 0;
    int match = 2;
    int mismatch = 1;
    int gape = affine;
    int gapo = 1;

    std::string num;
    for (int i = 0; i < cigar.size(); i++){
        char current_char = cigar[i];
        if (current_char == '=') {
            score += stoi(num) * match;
            num.clear();
        }
        else if (current_char == 'X') {
            score -= stoi(num) * mismatch;
            num.clear();
        }
        else if (current_char == 'I') {
            score -= gapo;
            if (stoi(num) > 1) {
                score -= (stoi(num) - 1)*(gapo + gape);
            }

            num.clear();
        } 
        else if (current_char == 'D') {
            score -= gapo;
            if (stoi(num) > 1) {
                score -= (stoi(num) - 1)*(gapo + gape);
            }

            num.clear();
        }
        else {
            num.push_back(cigar[i]);
        }
    }

    return score;

}

void cpu_pairwise(std::vector<std::string> texts, std::vector<std::string> queries){

    int threads = 1;
    vector<Alignment_t> alignments = genasm_cpu::align_all(texts, queries, threads);
    int affine = 1;
    for(Alignment_t &aln : alignments){
     	cout  << aln.edit_distance << endl << " " << endl;
        // cout << "cigar:" << aln.cigar << endl;
        cout << "score: affine - " << affine << ": " << cigar_read(aln.cigar, affine) << std::endl;
    }
}

int main(int argc, char *argv[]){
    genasm_cpu::enabled_algorithm_log = true;
    
    std::ifstream rf (argv[1]);
    std::ifstream qf (argv[2]);

    std::vector<std::string> ref, query;
    std::string r,q;

    while(true){
        std::getline(rf, r);
        std::getline(qf, q);
        if (rf.eof()||qf.eof()) break;

        std::getline(rf, r);
        std::getline(qf, q);
        ref.push_back(r);
        query.push_back(q);
    }
    // cout << "edit_distance" << endl;
    cpu_pairwise(ref, query);
    //cpu_string_pairs_example();
    //cpu_mapping_example();
    //gpu_mapping_example();
    // gpu_string_pairs_example();
}
