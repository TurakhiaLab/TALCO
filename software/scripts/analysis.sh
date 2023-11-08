#!/bin/bash

CURR_DIR="$PWD"
BASELINE_DIR="$CURR_DIR/.."

edlib=baselines/edlib/build/bin/edlib-aligner
wadapt=baselines/common/wadapt
biwfa=baselines/BiWFA-paper/bin/biwfa
scrooge=baselines/common/scrooge_cpu

talco_xdrop=TALCO-XDrop/build/TALCO-XDrop
talco_wfaa=TALCO-WFAA/build/TALCO-WFAA


tools=""
tools+="$edlib "
tools+="$wadapt "
# tools+="biwfa "
tools+="$scrooge "
tools+="$talco_xdrop "
tools+="$talco_wfaa "

DATASET_DIR="$CURR_DIR/../dataset"
TEMP_FILE="$CURR_DIR/temp"
touch $TEMP_FILE

acc=""
acc+="0.99 "
# acc+="0.95 "
# acc+="0.85 "
# acc+="0.70 "

length=""
length+="10k "
# length+="20k "
# length+="50k "
# length+="100k "

type=""
type+="ont "
# type+="query "

ANALYSER="runexec --read-only-dir / --overlay-dir ."

tab="\t"

parser()
{
    in=/dev/stdin
    text=$1
    unit=$2
    out=$(grep "$text" $in | awk -F'=' '{print $2}')
    max=0
    count=0
    check="cputime"
    

    for v in $out; 
    do
        if [[ $text == $check ]];
        then
            if (( $count == 0 ));
            then
                count=$(( $count + 1 ))
                continue
            fi
        fi
        val=$(echo $v | awk -F"$unit" '{print $1}')
        if (( $(echo "$val > $max" |bc -l) ));
        then
            max=$val
        fi
        count=$(( $count + 1 ))
    done
    echo $max
}

for err in $acc; 
do
    for len in $length;
    do
        for t in $type;
        do
            echo "Analysing tools on $t reads of $len length with $err% acc rate"
            printf 'Tool\tMemory\tEnergy\tTime\n'
            for tool in $tools
            do 
                file_path=$DATASET_DIR/dataset_$len/$t/$err
                
                if [[ $tool == $talco_xdrop ]];
                then
                    $ANALYSER -- $BASELINE_DIR/$tool -r $file_path/${t}_ref.fa -q $file_path/${t}_query.fa &> $TEMP_FILE

                elif [[ $tool == $biwfa ]];
                then
                    echo "BIWFA"
                else
                    $ANALYSER -- $BASELINE_DIR/$tool  $file_path/${t}_ref.fa $file_path/${t}_query.fa &> $TEMP_FILE

                fi            
                
                printf '%s\t%s\t%s\t%s\n' "$(basename $tool) $(cat $TEMP_FILE | parser "memory=" "B") $(cat $TEMP_FILE | parser "cpuenergy" "J") $(cat $TEMP_FILE | parser "cputime"   "s")"        
            done
        done
    done
done

# rm -f $TEMP_FILE
cd $CURR_DIR
