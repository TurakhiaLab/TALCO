#!/bin/bash

CURR_DIR=$PWD
OPENRAM=/OpenRAM/OpenRAM
SCRIPT=$OPENRAM/sram_compiler.py
FILE=$OPENRAM/config.py

cd "$OPENRAM"

WORD=32
main_row="num_words=32"
prev_row="num_words=32"
ROW=""
ROW+="256 " #1KB
ROW+="512 " #2KB
ROW+="1024 " #4KB 
ROW+="8192 " #32KB
old_file_name="size_2KB"

TEMP_FILE=temp_file
touch $TEMP_FILE
parser ()
{
    in=/dev/stdin
    file=$1
    text=$2

    table_content=$(grep -Po "(?s)<table .*?</table>" "$file")
    cleaned_table=$(echo "$table_content" | sed 's/<[^>]*>/ /g')
    count=0
    for a in $cleaned_table; do
        count=$(( $count + 1 ))
        if [[ $count == 19 ]] && [[ $text == "Area" ]]; then
            echo "$text: $a um2"
        elif [[ $count == 179 ]] && [[ $text == "Power" ]]; then
            echo "$text $a mW"
        fi
    done

}


for row in $ROW;
do
    curr_row="num_words=$row"
    sed -i "s/$prev_row/$curr_row/" $FILE
    size=$(( $WORD*$row/8192  ))
    file_name="size_${size}KB"
    sed -i "s/$old_file_name/$file_name/" $FILE
    python3 $SCRIPT $FILE &> $TEMP_FILE
    prev_row=$curr_row
    echo "$size KB"
    parser "$OPENRAM/temp/size_${size}KB.html" Area
    parser "$OPENRAM/temp/size_${size}KB.html" Power
    sed -i "s/size_${size}KB/size_2KB/" $FILE

done

yes "" | rm -f $TEMP_FILE

sed -i "s/$prev_row/$main_row/" $FILE
cd $CURR_DIR




