#include <string>
#include <vector>
#include <iostream>
#include <fstream>

#include "genasm_cpu.hpp"
#include "genasm_gpu.hpp"
#include "util.hpp"

using namespace std;


void gpu_pairwise(std::vector<std::string> texts, std::vector<std::string> queries){
    vector<Alignment_t> alignments = genasm_gpu::align_all(texts, queries);

    // for(Alignment_t &aln : alignments){
    //     cout << "edit_distance:" << aln.edit_distance << " ";
    //     cout << "cigar:" << aln.cigar << endl;
    // }
}

int main(int argc, char *argv[]){
    genasm_cpu::enabled_algorithm_log = false;
    genasm_gpu::enabled_algorithm_log = true;
    
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
    gpu_pairwise(ref, query);
    //cpu_string_pairs_example();
    //cpu_mapping_example();
    //gpu_mapping_example();
    // gpu_string_pairs_example();
}
