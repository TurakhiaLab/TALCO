## Software implementation of TALCO-WFAA

> Please note that TALCO-WFAA is implemented on top of [WFA2-lib](https://github.com/smarco/WFA2-lib). We modified the unidirectional align function of the WFA library (adopted in WFA-Adapt) to use the TALCO tiling strategy. We did this by modifying the compute function to forward the convergence pointers and check for convergence, while the reduce and extend function invocations remained the same. 

#### System Requirements
1. **gcc:** At least support for `C++ 17` and OpenMP, tested with `g++ 10.3`
2. **cmake:** `3.16.3`

#### Build Instructions
```
git clone https://github.com/TurakhiaLab/TALCO.git
cd TALCO/software/TALCO-WFAA
mkdir -p build && cd build
cmake ..
make TALCO-WFAA
```

#### Run Instructions
```
cd build
data="../../dataset"
./TALCO-WFAA $data/ref.fa $data/query.fa
```
