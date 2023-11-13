
## ASIC Analysis using OpenROAD

#### 1. Use Pre-built Docker image (Recommended)
We have provided a pre-built docker image with all necessary tools installed in it for ASIC analysis. 
```
docker run -it swalia14/talco:latest
# Inside Docker
cd /
git clone https://github.com/TurakhiaLab/TALCO.git
cd TALCO/hardware
```

#### 2. System Verilog to Verilog Conversion (Not required if using Docker Image)

OpenROAD only supports Verilog; therefore, we use [sv2v](https://github.com/zachjs/sv2v.git) to convert our codebase in System-verilog to Verilog. Use the following command to install [sv2v](https://github.com/zachjs/sv2v.git):
```
cd scripts
source install_dependecies.sh
```

#### 3. ASIC Analysis
1. Use the following commands to generate Area, Power, and Critical path delay of the designs using [OpenROAD-flow-scripts](https://github.com/The-OpenROAD-Project/OpenROAD-flow-scripts/tree/master):
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

4. Alignment throughput of ASIC designs

> Total execution time (TET) $=$ Logic cycle count (LCC) $\times$ Critical path delay (PD) $+$ DRAM cycle count (DCC) $\times$ ($\frac{1}{DRAM frequency}$)  
> Throughput $=$ Number of PE's $\times$ $\frac{1}{TET}$

Note: $LCC$ of our designs can be calculated by simulating the designs using the testbench provided in the [repository](./hardware/TALCO-XDrop/hdl/) 

5. ASIC baseline 
> Step 1-4 is performed for alignment throughput of [GACT-X](https://github.com/gsneha26/Darwin-WGA/tree/master/src/hdl/GACTX) (used as ASIC baseline) 

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