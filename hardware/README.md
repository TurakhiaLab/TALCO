
## ASIC Analysis using OpenROAD

#### Build OpenROAD Using Docker
Various methods can be adopted to build [OpenROAD](https://github.com/The-OpenROAD-Project/OpenROAD-flow-scripts/tree/master). Building with Docker using the following commands is recommended as we have performed ASCI analysis with Docker: 
```
git clone --recursive https://github.com/The-OpenROAD-Project/OpenROAD-flow-scripts
cd OpenROAD-flow-scripts
./build_openroad.sh --threads N
```
Number of CPU threads can be restricted using `--threads N` argument.

To verify OpenROAD installation, use the following command:
```
docker run --rm -it -u $(id -u ${USER}):$(id -g ${USER}) -v $(pwd)/flow:/OpenROAD-flow-scripts/flow openroad/flow-centos7-builder
```

Inside docker, set the environment, and check whether `yosys` and `openroad` are installed correctly using the following commands:
```
source ./env.sh
yosys -help
openroad -help
cd flow
make
exit
```

#### System Verilog to Verilog Conversion

OpenROAD only supports Verilog; therefore, we use [sv2v](https://github.com/zachjs/sv2v.git) to convert our codebase in system verilog to verilog. Use the following command to install [sv2v](https://github.com/zachjs/sv2v.git):
```
cd scripts
source install_dependecies.sh
```

#### ASIC Analysis
Following commands will mount necessary files to the OpenROAD docker instance and generate area, power, and worst-case-delay of the designs.
```
cd scripts
source ASIC_analysis.sh [XDrop/WFAA]
cd flow
make
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