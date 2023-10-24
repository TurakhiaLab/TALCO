#!/bin/bash

curr_dir="$PWD"
trash_file="$curr_dir/datasettrash"

cd $PWD/../
# Download dataset
rm -rf dataset*
echo "Downloading Dataset ..."
wget --no-check-certificate https://drive.google.com/uc?id=1IKyFpIoqSnaEpYnZ8Pu0e6dyKEt2Rn4n -O dataset.zip &>> trash_file
unzip dataset.zip 
rm -f dataset.zip $trash_file

cd $curr_dir