#include <iostream>
#include <vector>
#include <string>
#include <boost/program_options.hpp> 
#include "TALCO-XDrop.hpp"
#include "kseq.h"
#include "zlib.h"

namespace po = boost::program_options;

KSEQ_INIT2(, gzFile, gzread)

int main(int argc, char** argv) {
    Timer timer;

    std::string referenceFilename;
    std::string queryFilename;
    
    int marker = 1024;
    int xdrop = 100;

    // Command line options
    po::options_description desc{"Options"};
    desc.add_options()
        ("reference,r", po::value<std::string>(&referenceFilename)->required(), "Reference filename (required)")
        ("query,q", po::value<std::string>(&queryFilename)->required(), "Query filename (required)")
        ("xdrop,x", po::value<int>(&xdrop), "X-Drop value")
        ("marker,M", po::value<int>(&marker), "Marker")
        ("help,h", "Print help messages");

    po::options_description allOptions;
    allOptions.add(desc);

    po::variables_map vm;
    try{
        po::store(po::command_line_parser(argc, argv).options(allOptions).run(), vm);
        po::notify(vm);
    }
    catch(std::exception &e){
        std::cerr << desc << std::endl;
        // Return with error code 1 unless the user specifies help
        if(vm.count("help"))
            return 0;
        else
            return 1;
    }

    gzFile f_rd;
    kseq_t *kseq_rd;

    std::vector<std::string> reference, query;

    // Read reference sequences
    timer.Start();

    // fprintf(stderr, "Reading reference file: %s\n", referenceFilename.c_str());
    f_rd = gzopen(referenceFilename.c_str(), "r");
    if (!f_rd) {
        fprintf(stderr, "ERROR: cant open file: %s\n", referenceFilename.c_str());
        exit(1);
    }

    kseq_rd = kseq_init(f_rd);
    while (kseq_read(kseq_rd) >= 0) {
        size_t seqLen = kseq_rd->seq.l;
        std::string seqString = std::string(kseq_rd->seq.s, seqLen);
        reference.push_back(seqString);
    }

    // fprintf(stderr, "Completed in %ld msec \n\n", timer.Stop());

    // Read query sequences
    timer.Start();

    // fprintf(stderr, "Reading query file: %s\n", queryFilename.c_str());
    f_rd = gzopen(queryFilename.c_str(), "r");
    if (!f_rd) {
        fprintf(stderr, "ERROR: cant open file: %s\n", queryFilename.c_str());
        exit(1);
    }

    kseq_rd = kseq_init(f_rd);

    while (kseq_read(kseq_rd) >= 0) {
        size_t seqLen = kseq_rd->seq.l;
        std::string seqString = std::string(kseq_rd->seq.s, seqLen);
        query.push_back(seqString);
    }

    // fprintf(stderr, "Completed in %ld msec \n\n", timer.Stop());

    assert (reference.size() == query.size());

    size_t num_alignments = reference.size();

    timer.Start();
    // fprintf(stderr, "Initializing params and device arrays.\n");
    Talco_xdrop::Params params (2, -1, -2, -1, xdrop, marker);
    // fprintf(stderr, "Completed in %ld msec \n\n", timer.Stop());

    timer.Start();
    // fprintf(stderr, "Performing alignment.\n");
    Align (params, reference, query, num_alignments);
    // fprintf(stderr, "Completed in %ld msec \n\n", timer.Stop());

    return 0;
}

