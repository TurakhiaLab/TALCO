#!/bin/bash

in=$1
curr_dir="$PWD"
baseline_dir="$PWD/../baselines"
trash_file="$curr_dir/makedata"

if [[ $in == "make" ]]
then 
    # Libgaba
    echo "Building Libgaba...."
    cd "$baseline_dir/libgaba"
    make &>> $trash_file

    # WFA-Adapt
    echo "Building WFA-Adapt...."
    cd "$baseline_dir/WFA2-lib"
    make &>> $trash_file

    # Edlib
    echo "Building WFA-Edlib...."
    cd "$baseline_dir/edlib"
    yes | cp ../common/CMakeLists.txt .
    mkdir -p build && cd build 
    cmake -D CMAKE_BUILD_TYPE=Release .. &>> $trash_file
    make &>> $trash_file

    # BiWFA
    echo "Building WFA-BiWFA...."
    cd "$baseline_dir/BiWFA-paper"
    make &>> $trash_file

    # Scrooge
    echo "Building Scrooge...."
    cd "$baseline_dir/Scrooge"
    make &>> $trash_file

    cd $baseline_dir/common
    make &>> $trash_file

    # Darwin-GPU
    echo "Building Darwin-GPU...."
    cd "$baseline_dir/darwin-gpu"
    cp ../common/darwin-gpu/Makefile .
    ./z_compile.sh GPU &>> $trash_file


    rm -f $trash_file

elif [[ $in == "clean" ]] 
then
    # Libgaba
    echo "Cleaning Libgaba...."
    cd "$baseline_dir/libgaba"
    make clean &>> $trash_file

    # WFA-Adapt
    echo "Cleaning WFA-Adpat...."
    cd "$baseline_dir/WFA2-lib"
    make clean &>> $trash_file

    # Edlib
    echo "Cleaning Edlib...."
    cd "$baseline_dir/edlib/build"
    make clean &>> $trash_file
    cd ../
    rm -rf build

    # BiWFA
    echo "Cleaning BiWFA...."
    cd "$baseline_dir/BiWFA-paper"
    make clean &>> $trash_file

    # Scrooge
    echo "Cleaning Scrooge...."
    cd "$baseline_dir/Scrooge"
    make clean &>> $trash_file

    # Darwin-GPU
    echo "Cleaning Darwin-GPU...."
    cd "$baseline_dir/darwin-gpu"
    make clean &>> $trash_file

    cd $baseline_dir/common
    make clean &>> $trash_file

    rm -f $trash_file

else
    echo "make or clean? Usage: source $0 [make or clean]"
fi

cd $curr_dir
