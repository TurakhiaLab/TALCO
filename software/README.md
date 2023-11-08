## Software Implementation and Baseline Evaluations

#### System Requirements
1. **gcc:** At least support for `C++ 17` and OpenMP, tested with `g++ 10.3`
2. **cmake:** `3.16.3`

#### Install Dependencies
```
sudo ./install_dependencies.sh
```

#### TALCO-XDrop and TALCO-WFAA
Visit [TALCO-XDrop](TALCO-XDrop/) and [TALCO-WFAA](TALCO-WFAA/) for implementation and usage. Use the following commands to build TALCO-XDrop and TALCO-WFAA.
```
cd scripts
source build_TALCO.sh make
cd ..
```

#### Baseline Tools
We have used [Libgaba](https://github.com/ocxtal/libgaba), [WFA-Adapt](https://github.com/smarco/WFA2-lib), [Edlib](https://github.com/Martinsos/edlib), [BiWFA](https://github.com/smarco/BiWFA-paper), and [Scrooge](https://github.com/CMU-SAFARI/Scrooge) as software baselines. Use the following commands to build the baseline tools. 
```
cd scripts
source build_baseline.sh make
cd ..
```

#### Memory Usage and Energy Consumption Analysis
* Setup dataset
```
cd scripts
source setup_dataset.sh
```
* Run TALCO-XDrop, TALCO-WFAA, and baseline tools
``` 
sudo ./analysis.sh
```