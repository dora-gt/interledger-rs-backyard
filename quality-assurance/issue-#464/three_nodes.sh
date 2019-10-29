#!/bin/bash

current_dir=$(pwd)
log_dir=${current_dir}/three_nodes_logs
interledger_rs_dir=/Users/dora_gt/Documents/git/interledger-rs
max_try=100

mkdir -p ${log_dir}
rm -f ${log_dir}/*
cd "${interledger_rs_dir}"

for test_num in $(seq 1 ${max_try}); do
	printf "Testing: %d/%d\n" $test_num $max_try 1>&2
	nice 19 RUST_LOG=interledger=trace cargo test --package ilp-node --test three_nodes three_nodes -- --nocapture &>${log_dir}/${test_num}.log || exit 1
done
