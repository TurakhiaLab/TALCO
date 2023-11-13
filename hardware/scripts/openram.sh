#!/bin/bash

source setvars.sh

config_file=$1

word_size=32
KB=8192

default=256
previous=$default
words=""
words+="1024 "
words+="256 "
words+="8192 "
words+="512 "


for word in $words; 
do
    echo sed -i "s/$previous/$word/" $1
    file=$(( $word*$word_size/$KB  ))
    echo sed -i "s/sram_2KB/sram_${file}KB/" $1
    previous=$word
    echo python3 $OPENRAM_HOME/../sram_compiler.py $1
    echo sed -i "s/sram_${file}KB/sram_2KB/" $1
done

echo sed -i "s/$previous/$default/" $1

