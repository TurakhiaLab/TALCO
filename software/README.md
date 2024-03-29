## Software Implementation and Baseline Evaluations

#### System Requirements
1. **gcc:** At least support for `C++ 17` and OpenMP, tested with `g++ 10.3`
2. **cmake:** `3.16.3`
3. **nvcc**
4. **Docker**
5. **python3-pip**

<!-- #### 1. Use Pre-built Docker image 
We provide a pre-built docker image with all necessary tools installed in it for baseline evaluation. 
```
docker run -it -v /sys/fs/cgroup:/sys/fs/cgroup:rw swalia14/talco:latest
# Inside Docker
cd /
git clone https://github.com/TurakhiaLab/TALCO.git
cd TALCO/software
``` -->
#### Note
Please **don't** use docker/VM to perform software analysis as Benchexec doesn't work with them.

#### Clone TALCO repository
```
git clone --recursive https://github.com/TurakhiaLab/TALCO.git
cd TALCO/software/scripts
```

#### Install Dependencies
```
sudo ./install_dependencies.sh
```

#### TALCO-XDrop and TALCO-WFAA
Visit [TALCO-XDrop](TALCO-XDrop/) and [TALCO-WFAA](TALCO-WFAA/) for implementation and usage. Use the following commands to build TALCO-XDrop and TALCO-WFAA.
```
source build_TALCO.sh make
```

#### Baseline Tools
We have used [Libgaba](https://github.com/ocxtal/libgaba), [WFA-Adapt](https://github.com/smarco/WFA2-lib), [Edlib](https://github.com/Martinsos/edlib), [BiWFA](https://github.com/smarco/BiWFA-paper), [Scrooge](https://github.com/CMU-SAFARI/Scrooge), and [Darwin-GPU](https://github.com/Tongdongq/darwin-gpu) as software baselines. Use the following commands to build the baseline tools. 
```
source build_baseline.sh make
```

#### Analysis
* Setup dataset
```
source setup_dataset.sh
```
* Compute memory footprint of TALCO-XDrop, TALCO-WFAA, and baseline tools executing on single-CPU thread
``` 
./analysis.sh mem
```

* Compute throughput of all software baseline tools executing on 32 CPU threads
``` 
./analysis.sh thp
```

* Compute throughput/watt of Libgaba and WFA-Adapt algorithms executing on 32 CPU threads
``` 
./analysis.sh thp/w
```
