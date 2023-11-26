#!/bin/bash

curr_dir="$PWD"
TALCO_HOME=../../
trash_file="$curr_dir/datasettrash"
dataset=$PWD/../../dataset
FILENAME=dataset.tar.gz
cd $TALCO_HOME
rm -rf $dataset

# Download dataset
echo "Downloading Dataset ..."
FILEID="190t0ajLgIJBGQvH5YiEL8pWbDmDMhXwG"
wget --load-cookies /tmp/cookies.txt "https://docs.google.com/uc?export=download&confirm=$(wget --quiet --save-cookies /tmp/cookies.txt --keep-session-cookies --no-check-certificate 'https://docs.google.com/uc?export=download&id=FILEID' -O- | sed -rn 's/.*confirm=([0-9A-Za-z_]+).*/\1\n/p')&id=$FILEID" -O $FILENAME && rm -rf /tmp/cookies.txt &>> $trash_file
tar -xzvf $FILENAME 
mv paper dataset
rm -f $FILENAME $trash_file

cd $curr_dir
