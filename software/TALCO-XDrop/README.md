## Software implementation of TALCO-XDrop

#### System Requirements
1. **gcc:** At least support for `C++ 17` and OpenMP, tested with `g++ 10.3`
2. **cmake:** `3.16.3`

#### Build Instructions
```
git clone https://github.com/TurakhiaLab/TALCO.git
cd TALCO/software/TALCO-XDrop
mkdir -p build && cd build
cmake ..
make TALCO-XDrop
```

#### Run Instructions
```
cd build
data="../../dataset"
./TALCO-XDrop -r $data/ref.fa -q $data/query.fa
```

