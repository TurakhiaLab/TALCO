v++ -O 3 -R 2 -l -t hw $TALCO_REPO/hardware/xo/high_perf_shell.xo --config build.cfg -o TALCO_XDROP.xclbin --platform xilinx_aws-vu9p-f1_shell-v04261818_201920_3/xilinx_aws-vu9p-f1_shell-v04261818_201920_3.xpfm -s

$VITIS_DIR/tools/create_vitis_afi.sh -xclbin=TALCO_XDROP.xclbin -o=TALCO_XDROP -s3_bucket=TALCO_XDROP_kernels -s3_dcp_key=dcp -s3_logs_key=log
