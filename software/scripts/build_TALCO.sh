#!/bin/bash

in=$1
curr_dir="$PWD"
TALCO_XDROP_DIR="$curr_dir/../TALCO-XDrop"
TALCO_WFAA_DIR="$curr_dir/../TALCO-WFAA"
trash_file="$curr_dir/makedata"


if [[ $in == "make" ]]
then 
    # TALCO-XDrop
    echo "Building TALCO-XDrop...."
    cd $TALCO_XDROP_DIR
    mkdir -p build
    cd build
    cmake .. &>> $trash_file
    make TALCO-XDrop &>> $trash_file

    # TALCO-WFAA
    echo "Building TALCO-WFAA...."
    cd $TALCO_WFAA_DIR
    mkdir -p build
    cd build
    cmake .. &>> $trash_file 
    make &>> $trash_file

    rm -f $trash_file


elif [[ $in == "clean" ]] 
then
    # TALCO-XDrop
    echo "Cleaning TALCO-XDrop...."
    cd $TALCO_XDROP_DIR/build
    make clean &>> $trash_file

    # TALCO-WFAA
    echo "Cleaning TALCO-WFAA...."
    cd $TALCO_WFAA_DIR/build
    make clean &>> $trash_file

    rm -f $trash_file


else
    echo "make or clean? Usage: source $0 [make or clean]"
fi

cd $curr_dir
