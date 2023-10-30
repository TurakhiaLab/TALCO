
CURR_DIR="$PWD"
BASELINE_DIR="$CURR_DIR/../baselines"

edlib=edlib/build/bin/runTests
wadapt=WFA2-lib/bin/wfa_adapt
biwfa=BiWFA-paper/bin/biwfa
scrooge=Scrooge/scrooge_cpu

tools=""
tools+="edlib "
tools+="wadapt "
tools+="biwfa "
tools+="scrooge "

DATASET_DIR="$CURR_DIR/../dataset"
TEMP_FILE="$CURR_DIR/temp"
touch $TEMP_FILE

error=""
error+="1 "
error+="5 "
error+="15 "
error+="30 "

length=""
length+="10k "
length+="20k "
length+="50k "
length+="100k "

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

for err in $error; 
do
    for len in $length;
    do
        echo "Analysing tools on Genomes of $len length with $err% error rate"
        printf 'Tool\tMemory\tEnergy\tTime\n'
        for tool in $tools
        do 
            # $ANALYSER -- $tool  $file_path/${type}_ref.fa $file_path/${type}_query.fa > $TEMP_FILE
            printf '%s\t%s\t%s\t%s\n' "$tool $(cat $TEMP_FILE | parser "memory" "B") $(cat $TEMP_FILE | parser "cpuenergy" "J") $(cat $TEMP_FILE | parser "cputime"   "s")"        
        done
    done
done

rm $TEMP_FILE
cd $CURR_DIR