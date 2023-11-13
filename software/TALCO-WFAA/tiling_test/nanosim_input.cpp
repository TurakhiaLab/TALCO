#include "tiling_test/nanosim_input.hpp"
#include <csignal>
#include <cstdio>
#include <fcntl.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

char *open_ref(char *ref_name) {
  auto ref_fd = open(ref_name, O_RDONLY);
  if (ref_fd == -1) {
    perror("error opening ref file");
    exit(EXIT_FAILURE);
  }
  struct stat stat_buf;
  fstat(ref_fd, &stat_buf);
  auto ref_ptr = mmap(NULL, stat_buf.st_size, PROT_READ, MAP_SHARED, ref_fd, 0);
  close(ref_fd);
  return (char *)ref_ptr;
}
std::unordered_map<std::string, ref_info> scan_idx(std::string idx_name) {
  std::fstream idx_file(idx_name);
  std::regex idx_regex("(\\w+)\t(\\d+)\t(\\d+)\t.*");
  if (!idx_file) {
    perror("error opening idx file");
    exit(EXIT_FAILURE);
  }
  std::string temp;
  std::smatch match_results;
  std::unordered_map<std::string, ref_info> idx;
  while (idx_file) {
    std::getline(idx_file, temp);
    if (temp == "") {
      continue;
    }
    if (!std::regex_match(temp, match_results, idx_regex)) {
      fprintf(stderr, "failed to parse idx file line %s\n", temp.c_str());
      exit(EXIT_FAILURE);
    }
    if (match_results.size() != 4) {
      fprintf(stderr, "%zu mathced\n", match_results.size());
      raise(SIGTRAP);
    }
    idx.emplace(match_results[1].str(),
                ref_info{std::stoul(match_results[2].str()),
                         std::stoul(match_results[3].str())});
  }
  return idx;
}
static char convert(char in) {
  switch (in) {
  case 'a':
  case 'A':
    return 0;
  case 't':
  case 'T':
    return 1;
  case 'g':
  case 'G':
    return 2;
  case 'c':
  case 'C':
    return 3;
  default:
    return 4;
  }
}
static char convert_complement(char in) {
  switch (in) {
  case 'a':
  case 'A':
    return 1;
  case 't':
  case 'T':
    return 0;
  case 'g':
  case 'G':
    return 3;
  case 'c':
  case 'C':
    return 2;
  default:
    return 4;
  }
}
Nanosim_Input::Nanosim_Input(char *ref_name, char *nanosim_out)
    : ref_file(open_ref(ref_name)),
      seq_idx(scan_idx(std::string(ref_name) + ".fai")),
      seq_name_parser(
          ">([a-zA-Z0-9-]+)_(\\d+)_aligned_\\d+_([RF])_(\\d+)_(\\d+)_(\\d+)"),
      nanosim_file(nanosim_out) {}

bool Nanosim_Input::operator()(std::string &seq_name, std::string &query,
                               std::string &reference) {
  while(true){
  if (!nanosim_file) {
    return false;
  }
  std::string sequence_temp;
  std::smatch match_results;
  std::getline(nanosim_file, seq_name);
  std::getline(nanosim_file, sequence_temp);
  while (seq_name=="") {
    if (!nanosim_file) {
      return false;
    }
    std::getline(nanosim_file, seq_name);
    std::getline(nanosim_file, sequence_temp);
  }
  if (!std::regex_match(seq_name, match_results, seq_name_parser) ||
      match_results.size() != 7) {
    fprintf(stderr, "failed to parse sequence name %s\n", seq_name.c_str());
    raise(SIGTRAP);
  }
  std::string contig_name = match_results[1].str();
  for (auto &c : contig_name) {
    if (c == '-') {
      c = '_';
    }
  }
  auto iter = seq_idx.find(contig_name);
  if (iter == seq_idx.end()) {
    fprintf(stderr, "cannot find contig %s\n", contig_name.c_str());
    raise(SIGTRAP);
  }
  size_t start_pos = std::stoul(match_results[2]);
  bool forward = match_results[3] == "F";
  size_t init_skip = std::stoul(match_results[4]);
  size_t ref_len = std::stoul(match_results[5]);
  size_t end_skip = std::stoul(match_results[6]);

  auto start_addr = ref_file + iter->second.start + start_pos;
  std::string ref_string(start_addr, start_addr + ref_len);
  int query_idx = forward ? init_skip : end_skip;
  auto query_end=forward ?end_skip:init_skip ;
  reference.resize(ref_len);
  if (forward) {
    for (int idx = 0; idx < ref_string.size(); idx++) {
      reference[idx] = convert(ref_string[idx]);
    }
  } else {
    for (int idx = 0; idx < ref_string.size(); idx++) {
      reference[ref_string.size() - 1 - idx] =
          convert_complement(ref_string[idx]);
    }
  }
  int ambi_count=0;
  for (auto c : reference) {
    if (c==4) {
      ambi_count++;
    }
  }
  if (reference.size()/10<ambi_count) {
    fprintf(stderr, "%s of length %zu have %d N, discarded\n",seq_name.c_str(),reference.size(),ambi_count);
    continue;
  }
  query.resize(sequence_temp.size() - query_idx-query_end);
  for (size_t idx = query_idx; idx < sequence_temp.size()-query_end; idx++) {
    query[idx - query_idx] = convert(sequence_temp[idx]);
  }
  return true;
  }
}