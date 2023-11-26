#!/bin/bash

CURR_DIR="$PWD"
DEPEND_DIR="$PWD/../dependencies"

mkdir -p $DEPEND_DIR
cd $DEPEND_DIR

apt install build-essential

apt-get install libboost-all-dev
apt-get install pkg-config

wget https://github.com/sosy-lab/cpu-energy-meter/releases/download/1.2/cpu-energy-meter_1.2-1_amd64.deb
apt install ./cpu-energy-meter_1.2-1_amd64.deb
yes "" | add-apt-repository ppa:sosy-lab/benchmarking
apt install benchexec

wget https://github.com/seccomp/libseccomp/releases/download/v2.5.4/libseccomp-2.5.4.tar.gz
tar -xvf libseccomp-2.5.4.tar.gz
rm -rf libseccomp-2.5.4.tar.gz
cd libseccomp-2.5.4
apt-get install -y gperf
./configure
make
make install
cd ../

cd $CURR_DIR

