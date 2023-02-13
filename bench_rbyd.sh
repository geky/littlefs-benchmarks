#!/bin/bash

set -eu -o pipefail

id_count="$(echo "${1:-4096}," | cut -d, -f1)"
id_step="$(echo "${1:-4096}," | cut -d, -f2)"
id_step=${id_step:-8}
attr_count="$(echo "${2:-256}," | cut -d, -f1)"
attr_step="$(echo "${2:-256}," | cut -d, -f2)"
attr_step=${attr_step:-1}
echo "benching ids $id_count,$id_step attrs $attr_count,$attr_step"

# run benchmarks
./scripts/bench.py ./runners/bench_runner -j -Gnor \
    bench_rbyd_id_commit \
    bench_rbyd_id_fetch \
    bench_rbyd_id_lookup \
    bench_rbyd_id_create \
    bench_rbyd_id_delete \
    -DN="range(1,$((id_count+1)),$id_step)" -obench_rbyd.sh.id.csv
./scripts/bench.py ./runners/bench_runner -j -Gnor \
    bench_rbyd_attr_commit \
    bench_rbyd_attr_fetch \
    bench_rbyd_attr_lookup \
    bench_rbyd_attr_append \
    bench_rbyd_attr_remove \
    -DN="range(1,$((attr_count+1)),$attr_step)" -obench_rbyd.sh.attr.csv

# plot results
./scripts/plotmpl.py bench_rbyd.sh.id.csv -obench_rbyd.sh.id.svg \
    -l -xN -bORDER -bCOMMIT --dark \
    -W1600 -H400 --ggplot --y2 --yunits=B \
    --xlabel="id count" --title="rbyd id operations" \
    --labels="
        inorder\,1\,readed,
        inorder\,1\,proged,
        inorder\,n\,readed,
        inorder\,n\,proged,
        reversed\,1\,readed,
        reversed\,1\,proged,
        reversed\,n\,readed,
        reversed\,n\,proged,
        random\,1\,readed,
        random\,1\,proged,
        random\,n\,readed,
        random\,n\,proged" \
    --subplot="-Dcase=bench_rbyd_id_commit -ybench_readed --ylabel=bench_readed --title=rbyd_commit --xticklabels=" \
        --subplot-below="-Dcase=bench_rbyd_id_commit -ybench_proged --ylabel=bench_proged" \
    --subplot-right="-Dcase=bench_rbyd_id_fetch -ybench_readed --title=rbyd_fetch -W0.5 --xticklabels= \
        --subplot-below=\"-Dcase=bench_rbyd_id_fetch -ybench_proged -Y0,1\"" \
    --subplot-right="-Dcase=bench_rbyd_id_lookup -ybench_readed --title=rbyd_lookup -W0.33 --xticklabels= \
        --subplot-below=\"-Dcase=bench_rbyd_id_lookup -ybench_proged -Y0,1\"" \
    --subplot-right="-Dcase=bench_rbyd_id_create -ybench_readed --title=rbyd_create -W0.25 --xticklabels= \
        --subplot-below=\"-Dcase=bench_rbyd_id_create -ybench_proged\"" \
    --subplot-right="-Dcase=bench_rbyd_id_delete -ybench_readed --title=rbyd_delete -W0.2 --xticklabels= \
        --subplot-below=\"-Dcase=bench_rbyd_id_delete -ybench_proged\""

./scripts/plotmpl.py bench_rbyd.sh.attr.csv -obench_rbyd.sh.attr.svg \
    -l -xN -bORDER -bCOMMIT --dark \
    -W1600 -H400 --ggplot --y2 --yunits=B \
    --xlabel="attr count" --title="rbyd attr operations" \
    --labels="
        inorder\,1\,readed,
        inorder\,1\,proged,
        inorder\,n\,readed,
        inorder\,n\,proged,
        reversed\,1\,readed,
        reversed\,1\,proged,
        reversed\,n\,readed,
        reversed\,n\,proged,
        random\,1\,readed,
        random\,1\,proged,
        random\,n\,readed,
        random\,n\,proged" \
    --subplot="-Dcase=bench_rbyd_attr_commit -ybench_readed --ylabel=bench_readed --title=rbyd_commit --xticklabels=" \
        --subplot-below="-Dcase=bench_rbyd_attr_commit -ybench_proged --ylabel=bench_proged" \
    --subplot-right="-Dcase=bench_rbyd_attr_fetch -ybench_readed --title=rbyd_fetch -W0.5 --xticklabels= \
        --subplot-below=\"-Dcase=bench_rbyd_attr_fetch -ybench_proged -Y0,1\"" \
    --subplot-right="-Dcase=bench_rbyd_attr_lookup -ybench_readed --title=rbyd_lookup -W0.33 --xticklabels= \
        --subplot-below=\"-Dcase=bench_rbyd_attr_lookup -ybench_proged -Y0,1\"" \
    --subplot-right="-Dcase=bench_rbyd_attr_append -ybench_readed --title=rbyd_append -W0.25 --xticklabels= \
        --subplot-below=\"-Dcase=bench_rbyd_attr_append -ybench_proged\"" \
    --subplot-right="-Dcase=bench_rbyd_attr_remove -ybench_readed --title=rbyd_remove -W0.2 --xticklabels= \
        --subplot-below=\"-Dcase=bench_rbyd_attr_remove -ybench_proged\""

# a simple webpage for easy viewing
cat << HERE > bench_rbyd.sh.html
    <body style="background-color:#443333;">
    <img src="bench_rbyd.sh.id.svg">
    <p></p>
    <img src="bench_rbyd.sh.attr.svg">
HERE
