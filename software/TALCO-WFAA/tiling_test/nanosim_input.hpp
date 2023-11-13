#include <fstream>
#include <regex>
#include <string>
#include <unordered_map>
struct ref_info {
  size_t length;
  size_t start;
};
class Nanosim_Input {
  char *ref_file;
  std::unordered_map<std::string, ref_info> seq_idx;
  std::regex seq_name_parser;
  std::fstream nanosim_file;
  public:
  Nanosim_Input(char *ref_name, char *nanosim_out);
  bool operator()(std::string &seq_name, std::string &query,
                  std::string &reference);
};