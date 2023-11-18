#!/bin/bash

curr_dir="$PWD"
# -v /sys/fs/cgroup:/sys/fs/cgroup:rw
# 

scl enable devtoolset-11 -- bash

pip3 install benchexec coloredlogs
cd ../../
git submodule update --init --recursive
cd $curr_dir


trash_file="$curr_dir/datasettrash"
dataset=$PWD/../dataset
FILENAME=dataset.tar.gz
cd ../
rm -rf $dataset

# Download dataset
echo "Downloading Dataset ..."
FILEID="190t0ajLgIJBGQvH5YiEL8pWbDmDMhXwG"
wget --load-cookies /tmp/cookies.txt "https://docs.google.com/uc?export=download&confirm=$(wget --quiet --save-cookies /tmp/cookies.txt --keep-session-cookies --no-check-certificate 'https://docs.google.com/uc?export=download&id=FILEID' -O- | sed -rn 's/.*confirm=([0-9A-Za-z_]+).*/\1\n/p')&id=$FILEID" -O $FILENAME && rm -rf /tmp/cookies.txt &>> $trash_file
tar -xzvf $FILENAME 
mv paper dataset
rm -f $FILENAME $trash_file

cd $curr_dir