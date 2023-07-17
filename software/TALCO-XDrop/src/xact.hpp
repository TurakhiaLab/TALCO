#include <stdint.h>
#include "timer.hpp"
#include <vector>
#include <string>

namespace Xact {
    struct Params 
    {
        int16_t match;
        int16_t mismatch;
        int16_t gapOpen;
        int16_t gapExtend;

        int16_t xdrop;
        int16_t marker;

        Params(int16_t t_match, int16_t t_mismatch, int16_t t_gapOpen, int16_t t_gapExtend, int16_t t_xdrop, int16_t marker) : 
            match(t_match), mismatch(t_mismatch), gapOpen(t_gapOpen), gapExtend(t_gapExtend), xdrop(t_xdrop), marker(marker) {}
    };

    // void printGpuProperties();

    // struct DeviceArrays
    // {
    //     // device pointer to store the array for traceback pointers
    //     int8_t* d_tracebackArray;
    //     size_t tracebackArrayLength;

    //     // TODO: add required device arrays here

    //     // TODO: define this constructor to allocate the memory required for device arrays
    //     DeviceArrays (size_t t_tracebackArrayLength);

    //     // TODO: deallocate the memory allocated for device arrays
    //     void clearDeviceArrays();
    // };

    // char* transferSequenceToDevice (char* h_sequence, size_t sequenceLength);
    // void clearSequenceOnDevice (char* d_sequence);

    // Starts and Ends specify alignment bounds.
    // Anchors specify starting positions.
    void Align (
        Params params,

        const std::vector<std::string>& reference,
        const std::vector<std::string>& query,

        size_t num_alignments
    );

    void Tile (
        const std::string &reference,
        const std::string &query,
        Params params,
        int32_t &reference_idx,
        int32_t &query_idx,
        std::vector<int8_t> &aln,
        int8_t &state,
        bool &last_tile
    );

    int32_t Reduction_tree (
        const int32_t *C,
        const int32_t L,
        const int32_t U
    );
    void Traceback(
        const std::vector<int32_t> &ftr_length, 
        const std::vector<int32_t> &ftr_lower_limit, 
        const int32_t tb_start_addr, 
        const int16_t tb_start_ftr,
        const int8_t tb_state,
        const int16_t tb_start_idx,
        const std::vector<int8_t> &tb,
        std::vector<int8_t> &aln
    );

    int Score (
        Params params,
        const std::vector<int8_t> &aln,
        const std::string &reference,
        const std::string &query
    );

    
}

