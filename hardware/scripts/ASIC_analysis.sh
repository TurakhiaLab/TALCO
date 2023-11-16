#!/bin/bash

CURR_DIR="$PWD"

which=$1

parser ()
{
    in=/dev/stdin
    file=$1
    target=$2

    if [[ $target == "Power" ]]; then
        l=$(grep "Total" $file)
        count=0
        for v in $l; do
            count=$(( $count + 1 ))
            if [[ $count == 10 ]]; then
                echo $v
            fi
        done
    fi

    if [[ $target == "Area" ]]; then
        l=$(grep "Design area" $file)
        count=0
        for v in $l; do
            count=$(( $count + 1 ))
            if [[ $count == 3 ]]; then
                echo $v
            fi
        done
    fi

    if [[ $target == "Delay" ]]; then
        l=$(grep -A 2 "finish critical path slack" $file)
        count=0
        for v in $l; do
            count=$(( $count + 1 ))
            if [[ $count == 6 ]]; then
                echo $v
            fi
        done
    fi
    
}

OPENROAD_DIR=/OpenROAD-flow-scripts
SV2V=/dependencies/sv2v/bin/sv2v

if [[ $which == "XDrop" ]]; then
    TALCO_XDROP_RTL="$CURR_DIR/../TALCO-XDrop/openroad/rtl"
    mkdir -p $TALCO_XDROP_RTL
    TALCO_XDROP_SV="$TALCO_XDROP_RTL/gcd.sv"
    TALCO_XDROP_V="$TALCO_XDROP_RTL/gcd.v"
    TALCO_XDROP_CONFIG="$CURR_DIR/../TALCO-XDrop/openroad/config/config.mk"
    TALCO_XDROP_CONST="$CURR_DIR/../TALCO-XDrop/openroad/config/constraint.sdc"
    TALCO_XDROP_MKFILE="$CURR_DIR/../TALCO-XDrop/openroad/Makefile"

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

    sed -i -e 's/PE_Array/gcd/g' $TALCO_XDROP_SV

    # # sv to v
    $SV2V $TALCO_XDROP_SV > $TALCO_XDROP_V 

    "yes" | cp -f $TALCO_XDROP_V $OPENROAD_DIR/flow/designs/src/gcd/
    "yes" | cp -f $TALCO_XDROP_CONFIG $OPENROAD_DIR/flow/designs/nangate45/gcd/
    "yes" | cp -f $TALCO_XDROP_CONST $OPENROAD_DIR/flow/designs/nangate45/gcd/
    # yes "" | cp -f $TALCO_XDROP_MKFILE $OPENROAD_DIR/flow/Makefile

    cd $OPENROAD_DIR/flow
    make &> temp_file

    log_file=logs/nangate45/gcd/base/6_report.log
    echo "Power: $(parser $log_file Power)"
    echo "Area:  $(parser $log_file Area)"
    echo "Delay: $(parser $log_file Delay)"


    # docker run --rm -it \
    #     -v $TALCO_XDROP_RTL:/OpenROAD-flow-scripts/flow/designs/src/gcd \
    #     -v $TALCO_XDROP_CONFIG:/OpenROAD-flow-scripts/flow/designs/nangate45/gcd \
    #     -v $TALCO_XDROP_MKFILE:/OpenRoad-flow-scripts/flow/Makefile \
    #     openroad/flow-centos7-builder:latest

elif [[ $which == "WFAA" ]]; then
    TALCO_WFAA_RTL="$CURR_DIR/../TALCO-WFAA/openroad/rtl"
    mkdir -p $TALCO_WFAA_RTL
    TALCO_WFAA_SV="$TALCO_WFAA_RTL/gcd.sv"
    TALCO_WFAA_V="$TALCO_WFAA_RTL/gcd.v"
    TALCO_WFAA_CONFIG="$CURR_DIR/../TALCO-WFAA/openroad/config/config.mk"
    TALCO_XDROP_CONST="$CURR_DIR/../TALCO-WFAA/openroad/config/constraint.sdc"
    TALCO_WFAA_MKFILE="$CURR_DIR/../TALCO-WFAA/openroad/Makefile"

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
    $SV2V $TALCO_WFAA_SV > $TALCO_WFAA_V 

    "yes" | cp -f $TALCO_WFAA_V $OPENROAD_DIR/flow/designs/src/gcd/
    "yes" | cp -f $TALCO_WFAA_CONFIG $OPENROAD_DIR/flow/designs/nangate45/gcd/
    "yes" | cp -f $TALCO_WFAA_CONST $OPENROAD_DIR/flow/designs/nangate45/gcd/
    # yes "" | cp -f $TALCO_WFAA_MKFILE $OPENROAD_DIR/flow/Makefile

    cd $OPENROAD_DIR/flow
    make

    # docker run --rm -it \
    #     -v $TALCO_WFAA_RTL:/OpenROAD-flow-scripts/flow/designs/src/gcd \
    #     -v $TALCO_WFAA_CONFIG:/OpenROAD-flow-scripts/flow/designs/nangate45/gcd \
    #     -v $TALCO_WFAA_MKFILE:/OpenRoad-flow-scripts/flow/Makefile \
    #     openroad/flow-centos7-builder:latest

else
    m=$(basename $BASH_SOURCE)
    echo "Usage: source $m [XDrop/WFAA]"
fi

cd $CURR_DIR



