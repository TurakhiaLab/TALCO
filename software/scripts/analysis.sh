#!/bin/bash

CURR_DIR="$PWD"
BASELINE_DIR="$CURR_DIR/.."

edlib=baselines/edlib/build/bin/edlib-aligner
wadapt=baselines/common/wadapt
biwfa=baselines/BiWFA-paper/bin/align_benchmark
scrooge=baselines/common/scrooge_cpu
libgaba=baselines/common/libgaba

edlib_p=baselines/edlib/build/bin/edlib_p
wadapt_p=baselines/common/wadapt_p
biwfa_p=baselines/common/BiWFA_p
scrooge_p=baselines/common/scrooge_cpu_p
libgaba_p=baselines/common/libgaba_p

scrooge_gpu=baselines/common/scrooge_gpu
darwin_dir=$BASELINE_DIR/baselines/darwin-gpu
darwin_gpu=./darwin

talco_xdrop=TALCO-XDrop/build/TALCO-XDrop
talco_wfaa=TALCO-WFAA/build/TALCO-WFAA


tools=""
if [[ $1 == "mem" ]]; then
    tools+="$edlib "
    tools+="$libgaba "
    tools+="$wadapt "
    tools+="$biwfa "
    tools+="$talco_xdrop "
    tools+="$talco_wfaa "
elif [[ $1 == "thp" ]]; then
    tools+="$edlib_p "
    tools+="$libgaba_p "
    tools+="$wadapt_p "
    tools+="$biwfa_p "
    tools+="$scrooge_p "
    tools+="$scrooge_gpu "
    tools+="$darwin_gpu "
elif [[ $1 == "thp/w" ]]; then
    tools+="$libgaba_p "
    tools+="$wadapt "
else
    tool+=""
fi

DATASET_DIR="$CURR_DIR/../dataset"
TEMP_FILE="$CURR_DIR/temp"
touch $TEMP_FILE

acc=""
acc+="0.85 "
# acc+="0.95 "
# acc+="0.99 "
# acc+="0.70 "

length=""
length+="10k "
length+="20k "
length+="50k "
length+="100k "

type=""
type+="ont "
type+="pacbio "

# ANALYSER="runexec --read-only-dir / --overlay-dir . --no-container"
ANALYSER="runexec --read-only-dir / --overlay-dir . --no-container"
GPU_ANALYS="ncu -o profile "

tab="\t"
total_alg=1001
parser()
{
    in=/dev/stdin
    
    text=$2
    unit=$3
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
    if [[ $1 == "mem" ]]; then
        if [[ $(( $max/1048576 )) == 0 ]];then
            echo "$(( $max/1024 ))KB"
        else
            echo "$(( $max/1048576 ))MB"
        fi
    elif [[ $1 == "thp" ]]; then
        echo "$(bc -l <<< "scale=2; $total_alg/$max") Alignments/sec"
    elif [[ $1 == "thp/w" ]]; then
        echo "$(bc -l <<< "scale=2; $max") Throughput/Watt"
    fi
}

for err in $acc; 
do
    for len in $length;
    do
        for t in $type;
        do
            echo "Analysing tools on $t reads of $len length with $err% acc rate"
            # printf 'Tool\tMemory\tEnergy\tTime\n'
            if [[ $1 == "mem" ]]; 
            then
                printf 'Tool\tMemory\t\n'
            elif [[ $1 == "thp" ]]; then
                printf 'Tool\tThroughput\t\n'
            fi
            for tool in $tools
            do 
                file_path=$DATASET_DIR/dataset_$len/$t/$err
                
                if [[ $tool == $talco_xdrop ]];
                then
                    $ANALYSER -- $BASELINE_DIR/$tool -r $file_path/${t}_ref.fa -q $file_path/${t}_query.fa &> $TEMP_FILE

                elif [ $tool == $biwfa ] || [ $tool == $biwfa_p ];
                then
                    $ANALYSER -- $BASELINE_DIR/$tool -i $file_path/${t}_biwfa.fa --affine-penalties 0,3,6,1 --wfa-score-only &> $TEMP_FILE
                elif [[ $tool == $darwin_gpu ]]; then
                    cd $darwin_dir
                    $ANALYSER -- $tool  $file_path/${t}_darwingpu_ref.fa $file_path/${t}_darwingpu_query.fa 8 32 64 &> $TEMP_FILE
                    cd $curr_dir
                else
                    $ANALYSER -- $BASELINE_DIR/$tool  $file_path/${t}_ref.fa $file_path/${t}_query.fa &> $TEMP_FILE
                fi            
                if [[ $1 == "mem" ]]; then
                    if [[ $tool == $biwfa ]];
                    then 
                        printf '%s\t%s\t\n' "BiWFA $(cat $TEMP_FILE | parser $1 "memory=" "B")"        
                    else
                        printf '%s\t%s\t\n' "$(basename $tool) $(cat $TEMP_FILE | parser $1 "memory=" "B")"        
                    fi
                elif [[ $1 == "thp" ]]; then
                    printf '%s\t%s\t\n' "$(basename $tool) $(cat $TEMP_FILE | parser  $1 "cputime" "s")"      
                elif [[ $1 == "thp/w" ]]; then
                    printf '%s\t%s\t\n' "$(basename $tool) $(cat $TEMP_FILE | parser  $1 "cpuenergy" "s")"      
                fi
                # printf '%s\t%s\t%s\t%s\n' "$(basename $tool) $(cat $TEMP_FILE | parser "memory=" "B") $(cat $TEMP_FILE | parser "cpuenergy" "J") $(cat $TEMP_FILE | parser "cputime"   "s")"        
            done
        done
    done
done

# rm -f $TEMP_FILE
cd $CURR_DIR

