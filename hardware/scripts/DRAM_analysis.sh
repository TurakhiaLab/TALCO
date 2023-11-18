#!/bin/bash

#scl enable devtoolset-11 -- bash

CURR_DIR=$PWD
RAMULATOR=/ramulator/ramulator
DRAMPower=/DRAMPower/build/bin/drampower_cli

traces=""
traces+="10k "
#traces+="20k "
#traces+="50k "
#traces+="100k "

TRACES_DIR=/ramulator

OUT_FILE=/DRAMPower/temp

parser()
{
    in=$1
    text=$2
    out=$(grep "$text" $in | awk -F':' "{print $2}")
    echo "$out"
}


for trace in $traces;
do
    $RAMULATOR $TRACES_DIR/configs/DDR4-config.cfg --mode=dram  --stats $TRACES_DIR/out_${trace} $TRACES_DIR/memory_${trace}.trace
    $DRAMPower $CURR_DIR/cmd-trace-chan-0-rank-0.cmdtrace /DRAMPower/tests/tests_drampower/resources/ddr4.json > $OUT_FILE
    out=$(grep "TOTAL ENERGY" $OUT_FILE | awk -F':' "{print $2}")
    echo "$out nJ"
    out=$(grep "ramulator.ramulator_active_cycles" $TRACES_DIR/out_${trace} | awk -F' ' "{print $2}")
    echo $out   
done

