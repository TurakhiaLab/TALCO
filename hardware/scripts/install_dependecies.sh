#!/bin/bash

CURR_DIR="$PWD"
DEPEND_DIR="$PWD/../dependencies"

mkdir -p $DEPEND_DIR
cd $DEPEND_DIR

# Install sv2v
git clone https://github.com/zachjs/sv2v.git
cd sv2v
make

cd $CURR_DIR

