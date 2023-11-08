#!/bin/bash

CURR_DIR="$PWD"
DEPEND_DIR="$PWD/../dependencies"

mkdir -p $DEPEND_DIR
cd $DEPEND_DIR

yes "" | add-apt-repository ppa:sosy-lab/benchmarking
apt install benchexec
apt install cpu-energy-meter

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

