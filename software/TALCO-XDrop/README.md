## Software implementation of TALCO-XDrop

#### Build Instructions
```
git clone https://github.com/TurakhiaLab/TALCO.git
cd TALCO/software/TALCO-XDrop
mkdir build && cd build
cmake ..
make TALCO-XDrop
```

#### Run Instructions
```
cd build
data="../../dataset"
./TALCO-XDrop -r $data/ref.fa -q $data/query.fa
```
