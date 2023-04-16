#!/bin/bash

set -eu -o pipefail

count="$(echo "${1:-}" | cut -d, -f1)"
step="$(echo "${1:-}," | cut -d, -f2)"
samples="$(echo "${1:-},," | cut -d, -f3)"
count="${count:-1024}"
step="${step:-1}"
samples="${samples:-1}"
echo "benching $count,$step,$samples"

# run benchmarks
if [[ $count -ne 0 ]]
then
    # block_size = 4096
    ./scripts/bench.py ./runners/bench_runner -j -Gnor \
        bench_btree_lookup \
        bench_btree_commit \
        -DDISK_SIZE=1073741824 \
        -DN="range(1,$((count+1)),$step)" \
        -DAMORTIZED=0 \
        -DSEED="range(1,$((samples+1)))" \
        -obench_btree.sh.raw.csv
    ./scripts/bench.py ./runners/bench_runner -j -Gnor \
        bench_btree_commit \
        -DDISK_SIZE=1073741824 \
        -DN="range(1,$((count+1)),$step)" \
        -DAMORTIZED=1 \
        -DSEED="range(1,$((samples+1)))" \
        -obench_btree.sh.amortized.csv
fi

# actually amortize to amortized results
# find avg/min/max of results
python << HERE
import csv
import collections as co
results = co.OrderedDict()
ys = ['bench_readed', 'bench_proged', 'bench_erased']
with open('bench_btree.sh.raw.csv') as f:
    reader = csv.DictReader(f)
    fieldnames = reader.fieldnames.copy()
    fieldnames.remove('SEED')
    for r in reader:
        try:
            k = tuple(r[k] for k in fieldnames if k not in ys)
            r_ = results.get(k, {})
            for y in ys:
                r[y] = int(r[y])
                r[y+'_sum'] = r[y] + r_.get(y+'_sum', 0)
                r[y+'_min'] = min(r[y], r_.get(y+'_min', r[y]))
                r[y+'_max'] = max(r[y], r_.get(y+'_max', r[y]))
                r[y+'_count'] = 1 + r_.get(y+'_count', 0)
            results[k] = r
        except ValueError:
            pass

    for r in results.values():
        for y in ys:
            r[y+'_avg'] = r[y+'_sum'] / r[y+'_count']

with open('bench_btree.sh.raw_fixed.csv', 'w') as f:
    writer = csv.DictWriter(f, fieldnames + ['MODE'], extrasaction='ignore')
    writer.writeheader()
    for r in results.values():
        writer.writerow(r | {'MODE': 'avg'} | {y: r[y+'_avg'] for y in ys})
        writer.writerow(r | {'MODE': 'bnd'} | {y: r[y+'_min'] for y in ys})
        writer.writerow(r | {'MODE': 'bnd'} | {y: r[y+'_max'] for y in ys})
HERE
python << HERE
import csv
import collections as co
results = co.OrderedDict()
ys = ['bench_readed', 'bench_proged', 'bench_erased']
with open('bench_btree.sh.amortized.csv') as f:
    reader = csv.DictReader(f)
    fieldnames = reader.fieldnames.copy()
    # merge by seed
    fieldnames.remove('SEED')
    for r in reader:
        try:
            k = tuple(r[k] for k in fieldnames if k not in ys)
            r_ = results.get(k, {})
            for y in ys:
                # amortize
                r[y] = int(r[y]) / int(r['N'])
                # avg/min/max
                r[y+'_sum'] = r[y] + r_.get(y+'_sum', 0)
                r[y+'_min'] = min(r[y], r_.get(y+'_min', r[y]))
                r[y+'_max'] = max(r[y], r_.get(y+'_max', r[y]))
                r[y+'_count'] = 1 + r_.get(y+'_count', 0)
            results[k] = r
        except ValueError:
            pass

    for r in results.values():
        for y in ys:
            r[y+'_avg'] = r[y+'_sum'] / r[y+'_count']

with open('bench_btree.sh.amortized_fixed.csv', 'w') as f:
    writer = csv.DictWriter(f, fieldnames + ['MODE'], extrasaction='ignore')
    writer.writeheader()
    for r in results.values():
        writer.writerow(r | {'MODE': 'avg'} | {y: r[y+'_avg'] for y in ys})
        writer.writerow(r | {'MODE': 'bnd'} | {y: r[y+'_min'] for y in ys})
        writer.writerow(r | {'MODE': 'bnd'} | {y: r[y+'_max'] for y in ys})
HERE

# plot results
./scripts/plotmpl.py \
    bench_btree.sh.raw_fixed.csv \
    bench_btree.sh.amortized_fixed.csv \
    -obench_btree.sh.svg \
    $([ "${2:-}" == order ] && echo --legend) \
    -xN \
    $([ "${2:-}" == order ] && echo -bORDER || echo -DORDER=2) \
    $([ "${2:-}" == order ] && echo -DMODE=avg || echo -bMODE) \
    -W1600 -H600 \
    --ggplot --dark \
    --y2 --yunits=B \
    --xlabel="count" \
    --title="btree operations" \
    --subplot="-Dcase=bench_btree_lookup -DVALIDATE=0 -ybench_readed --ylabel=bench_readed --title=btree_lookup --xticklabels=" \
        --subplot-below="-Dcase=bench_btree_lookup -DVALIDATE=0 -ybench_proged --ylabel=bench_proged -Y0,1 --xticklabels=" \
        --subplot-below="-Dcase=bench_btree_lookup -DVALIDATE=0 -ybench_erased --ylabel=bench_erased -Y0,1 -H0.33" \
    --subplot-right="-Dcase=bench_btree_lookup -DVALIDATE=1 -ybench_readed --title='btree_lookup (validated)' -W0.5 --xticklabels= \
        --subplot-below=\"-Dcase=bench_btree_lookup -DVALIDATE=0 -ybench_proged -Y0,1 --xticklabels=\" \
        --subplot-below=\"-Dcase=bench_btree_lookup -DVALIDATE=0 -ybench_erased -Y0,1 -H0.33\"" \
    --subplot-right="-Dcase=bench_btree_commit -DAMORTIZED=0 -ybench_readed --title=btree_commit -W0.33 --xticklabels= \
        --subplot-below=\"-Dcase=bench_btree_commit -DAMORTIZED=0 -ybench_proged --xticklabels=\" \
        --subplot-below=\"-Dcase=bench_btree_commit -DAMORTIZED=0 -ybench_erased -H0.33\"" \
    --subplot-right="-Dcase=bench_btree_commit -DAMORTIZED=1 -ybench_readed --title='btree_commit (amortized)' -W0.25 --xticklabels= \
        --subplot-below=\"-Dcase=bench_btree_commit -DAMORTIZED=1 -ybench_proged --xticklabels=\" \
        --subplot-below=\"-Dcase=bench_btree_commit -DAMORTIZED=1 -ybench_erased -H0.33\"" \
    "$([ "${2:-}" == order ] \
        && echo "--colors= \
            #a1c9f4bf,#a1c9f4bf,#a1c9f4bf, \
            #ffb482bf,#ffb482bf,#ffb482bf, \
            #8de5a1bf,#8de5a1bf,#8de5a1bf, " \
        || echo "--colors= \
            #a1c9f4bf,#a1c9f4bf,#a1c9f4bf, \
            #a1c9f43f,#a1c9f43f,#a1c9f43f, ")" \
    "$([ "${2:-}" == order ] \
        && echo "--labels= \
            inorder,,, \
            reversed,,, \
            random,,, ")"


# a simple webpage for easy viewing
cat << HERE > bench_btree.sh.html
    <body style="background-color:#443333;">
    <img src="bench_btree.sh.svg">
HERE
