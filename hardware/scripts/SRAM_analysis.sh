CURR_DIR=$PWD
OPENRAM=/OpenRAM/OpenRAM
SCRIPT=$OPENRAM/sram_compiler.py
FILE=$OPENRAM/config.py

#cd $OpenRAM

WORD=32
main_row="num_words=32"
prev_row="num_words=32"
ROW=""
ROW+="256 " #1KB
#ROW+="512 " #2KB
#ROW+="1024 " #4KB 
#ROW+="8192 " #32KB
old_file_name="sram_2KB"
for row in $ROW;
do
    curr_row="num_words=$row"
    sed -i "s/$prev_row/$curr_row/" $FILE
    size=$(( $WORD*$row/8192  ))
    file_name="sram_${size}KB"
    sed -i "s/$old_file_name/$file_name/" $FILE
    #python3 $SCRIPT $FILE
    prev_row=$curr_row
    sed -i "s/sram_${size}KB/size_2KB/" $FILE
done

sed -i "s/$prev_row/$main_row/" $FILE
cd $CURR_DIR

