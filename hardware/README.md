
## ASIC Analysis using OpenROAD

#### 1. Use Pre-built Docker image 
We have provided a pre-built docker image with all necessary tools installed in it for ASIC analysis. 
```
docker run -it swalia14/talco:latest
# Inside Docker
cd /
git clone https://github.com/TurakhiaLab/TALCO.git
cd TALCO/hardware
```

#### 2. System Verilog to Verilog Conversion

OpenROAD only supports Verilog; therefore, we use [sv2v](https://github.com/zachjs/sv2v.git) to convert our codebase in system verilog to verilog. Use the following command to install [sv2v](https://github.com/zachjs/sv2v.git):
```
cd scripts
source install_dependecies.sh
```

#### 3. ASIC Analysis
1. Use the following commands to generate Area, Power, and Max-delay of the designs using [OpenROAD-flow-scripts](https://github.com/The-OpenROAD-Project/OpenROAD-flow-scripts/tree/master):
```
cd scripts
source ASIC_analysis.sh [XDrop/WFAA]
```

2. SRAM Power analysis using [OpenRAM](https://github.com/VLSIDA/OpenRAM/tree/stable)
```
cd scripts
source SRAM_analysis.sh
```

3. DRAM Power and Cycle count analysis using [DRAMPower](https://github.com/tukl-msd/DRAMPower)
```
cd scripts
source DRAM_analysis.sh
```

## Building on AWS EC2 F1 instace
Follow the below instructions to execute TALCO-XDrop and TALCO-WFAA on AWS EC2 F1 instance, [f1.2xlarge]().

* Clone aws-fpga repository
```
git clone https://github.com/aws/aws-fpga
cd aws-fpga
source vitis_runtime_setup.sh
```

* Clone TALCO repository
```
git clone https://github.com/TurakhiaLab/TALCO.git
export TALCO_DIR=$PWD/TALCO
cd TALCO/hardware/TALCO-XDrop
```

* Steps for running on the EC2 F1 instance, f1.2xlarge (MODE-hw)
```
source $TALCO_DIR/hardware/scripts/run.sh
$TALCO_DIR/dataset/sequence.fa TALCO_XDrop.awsxclbin
``````