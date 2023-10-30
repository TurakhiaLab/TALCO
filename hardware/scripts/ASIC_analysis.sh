#!/bin/bash

CURR_DIR="$PWD"

which=$1

if [[ $which == "XDrop" ]]; then
    TALCO_XDROP_RTL="$CURR_DIR/../TALCO-XDrop/openroad/rtl"
    TALCO_XDROP_SV="$TALCO_XDROP_RTL/gcd.sv"
    TALCO_XDROP_V="$TALCO_XDROP_RTL/gcd.v"
    TALCO_XDROP_CONFIG="$CURR_DIR/../TALCO-XDrop/openroad/config"
    TALCO_XDROP_MKFILE="$CURR_DIR/../TALCO-XDrop/openroad/Makefile"
    OPENROAD_DIR=$CURR_DIR/../OpenROAD-flow-scripts

    rm -f $TALCO_XDROP_SV $TALCO_XDROP_V

    TALCO_XDROP_DIR="$CURR_DIR/../TALCO-XDrop/hdl"
    touch $TALCO_XDROP_SV
    for file in $TALCO_XDROP_DIR/*; do 
        if [[ $file != $TALCO_XDROP_DIR/tb.sv ]]; 
        then
            cat $file >> $TALCO_XDROP_SV
            echo "" >> $TALCO_XDROP_SV
        fi
    done

    sed -i -e 's/TALCO_XDrop/gcd/g' $TALCO_XDROP_SV

    # sv to v
    SV2V=$CURR_DIR/../dependencies/sv2v/bin/sv2v
    $SV2V $TALCO_XDROP_SV > $TALCO_XDROP_V 

    docker run --rm -it \
        -v $TALCO_XDROP_RTL:/OpenROAD-flow-scripts/flow/designs/src/gcd \
        -v $TALCO_XDROP_CONFIG:/OpenROAD-flow-scripts/flow/designs/nangate45/gcd \
        -v $TALCO_XDROP_MKFILE:/OpenRoad-flow-scripts/flow/Makefile \
        openroad/flow-centos7-builder:latest

elif [[ $which == "WFAA" ]]; then
    TALCO_WFAA_RTL="$CURR_DIR/../TALCO-WFAA/openroad/rtl"
    TALCO_WFAA_SV="$TALCO_WFAA_RTL/gcd.sv"
    TALCO_WFAA_V="$TALCO_WFAA_RTL/gcd.v"
    TALCO_WFAA_CONFIG="$CURR_DIR/../TALCO-WFAA/openroad/config"
    TALCO_WFAA_MKFILE="$CURR_DIR/../TALCO-WFAA/openroad/Makefile"
    OPENROAD_DIR=$CURR_DIR/../OpenROAD-flow-scripts

    rm -f $TALCO_WFAA_SV $TALCO_WFAA_V

    TALCO_WFAA_DIR="$CURR_DIR/../TALCO-WFAA/hdl"
    touch $TALCO_WFAA_SV
    for file in $TALCO_WFAA_DIR/*; do 
        if [[ $file != $TALCO_WFAA_DIR/tb.sv ]]; 
        then
            cat $file >> $TALCO_WFAA_SV
            echo "" >> $TALCO_WFAA_SV
        fi
    done

    sed -i -e 's/TALCO_WFAA/gcd/g' $TALCO_WFAA_SV

    # sv to v
    SV2V=$CURR_DIR/../dependencies/sv2v/bin/sv2v
    $SV2V $TALCO_WFAA_SV > $TALCO_WFAA_V 

    docker run --rm -it \
        -v $TALCO_WFAA_RTL:/OpenROAD-flow-scripts/flow/designs/src/gcd \
        -v $TALCO_WFAA_CONFIG:/OpenROAD-flow-scripts/flow/designs/nangate45/gcd \
        -v $TALCO_WFAA_MKFILE:/OpenRoad-flow-scripts/flow/Makefile \
        openroad/flow-centos7-builder:latest

else
    m=$(basename $BASH_SOURCE)
    echo "Usage: source $m [XDrop/WFAA]"
fi




