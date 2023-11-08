CURR_DIR=$PWD
OPENRAM=/OpenRAM/OpenRAM
SCRIPT=$OPENRAM/sram_compiler.py
FILE=$OPENRAM/config.py

cd $OpenRAM

WORD=32
prev_row="num_words=32"
ROW=""
ROW+="256 " #1KB
ROW+="512 " #2KB
ROW+="1024 " #4KB 
ROW+="8192 " #32KB

for row in $ROW; 
do
    curr_row="num_words=$row"
    sed -i "s/$prev_row/$curr_row/" $FILE
    python3 $SCRIPT $FILE
    prev_row=$curr_row 
done

cd $CURR_DIR
