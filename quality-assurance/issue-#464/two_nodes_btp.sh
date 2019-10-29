#!/bin/bash

current_dir=$(pwd)
log_dir=${current_dir}/two_nodes_btp_logs
interledger_rs_dir=/Users/dora_gt/Documents/git/interledger-rs
max_try=100

mkdir -p ${log_dir}
rm -f ${log_dir}/*
cd "${interledger_rs_dir}"

for test_num in $(seq 1 ${max_try}); do
	printf "Testing: %d/%d\n" $test_num $max_try 1>&2
	RUST_LOG=interledger=trace cargo test --package ilp-node --test btp two_nodes_btp -- --nocapture &>${log_dir}/${test_num}.log || exit 1
done
