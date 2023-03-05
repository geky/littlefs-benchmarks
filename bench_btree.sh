#!/bin/bash

set -eu -o pipefail

count="$(echo "${1:-1024}," | cut -d, -f1)"
step="$(echo "${1:-1024}," | cut -d, -f2)"
step=${step:-1}
echo "benching $count,$step"

# run benchmarks
if [[ $count -ne 0 ]]
then
    ./scripts/bench.py ./runners/bench_runner -j -Gnor \
        bench_btree_lookup \
        bench_btree_append \
        -DDISK_SIZE=10485760 \
        -DBLOCK_SIZE=512,4096,16384 \
        -DN="range(1,$((count+1)),$step)" \
        -obench_btree.sh.csv
fi

# plot results
./scripts/plotmpl.py bench_btree.sh.csv -obench_btree.sh.svg \
    -l -xN -bBLOCK_SIZE --dark \
    -W1200 -H600 --ggplot --y2 --yunits=B \
    --xlabel="count" --title="btree operations" \
    --colors=" \
        #4c72b0bf,#4c72b0bf,#4c72b0bf, \
        #dd8452bf,#dd8452bf,#dd8452bf, \
        #55a868bf,#55a868bf,#55a868bf, \
        #c44e52bf,#c44e52bf,#c44e52bf, \
        #8172b3bf,#8172b3bf,#8172b3bf, \
        #937860bf,#937860bf,#937860bf" \
    --subplot="-Dcase=bench_btree_lookup -ybench_readed --ylabel=bench_readed --title=btree_lookup --xticklabels=" \
        --subplot-below="-Dcase=bench_btree_lookup -ybench_proged --ylabel=bench_proged -Y0,1 --xticklabels=" \
        --subplot-below="-Dcase=bench_btree_lookup -ybench_erased --ylabel=bench_erased -Y0,1 -H0.33" \
    --subplot-right="-Dcase=bench_btree_append -ybench_readed --title=btree_append -W0.5 --xticklabels= \
        --subplot-below=\"-Dcase=bench_btree_append -ybench_proged --xticklabels=\" \
        --subplot-below=\"-Dcase=bench_btree_append -ybench_erased -H0.33\""

# a simple webpage for easy viewing
cat << HERE > bench_btree.sh.html
    <body style="background-color:#443333;">
    <img src="bench_btree.sh.svg">
HERE
