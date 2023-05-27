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
        -DBLOCK_SIZE=512,1024,2048,4096,8192,16384,32768 \
        -DORDER=2 \
        -DDISK_SIZE=1073741824 \
        -DN="range(1,$((count+1)),$step)" \
        -DAMORTIZED=0 \
        -DSEED="range(1,$((samples+1)))" \
        -obench_btree_block_size.sh.raw.csv
    ./scripts/bench.py ./runners/bench_runner -j -Gnor \
        bench_btree_commit \
        -DBLOCK_SIZE=512,1024,2048,4096,8192,16384,32768 \
        -DORDER=2 \
        -DDISK_SIZE=1073741824 \
        -DN="range(1,$((count+1)),$step)" \
        -DAMORTIZED=1 \
        -DSEED="range(1,$((samples+1)))" \
        -obench_btree_block_size.sh.amortized.csv
fi

# actually amortize to amortized results
# find avg/min/max of results
python << HERE
import csv
import collections as co
results = co.OrderedDict()
ys = ['bench_readed', 'bench_proged', 'bench_erased']
with open('bench_btree_block_size.sh.raw.csv') as f:
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

with open('bench_btree_block_size.sh.raw_fixed.csv', 'w') as f:
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
with open('bench_btree_block_size.sh.amortized.csv') as f:
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

with open('bench_btree_block_size.sh.amortized_fixed.csv', 'w') as f:
    writer = csv.DictWriter(f, fieldnames + ['MODE'], extrasaction='ignore')
    writer.writeheader()
    for r in results.values():
        writer.writerow(r | {'MODE': 'avg'} | {y: r[y+'_avg'] for y in ys})
        writer.writerow(r | {'MODE': 'bnd'} | {y: r[y+'_min'] for y in ys})
        writer.writerow(r | {'MODE': 'bnd'} | {y: r[y+'_max'] for y in ys})
HERE

# prefix block_size with zeros for lexicographic ordering
python << HERE
import csv
import collections as co
for path in [
        'bench_btree_block_size.sh.raw_fixed.csv',
        'bench_btree_block_size.sh.amortized_fixed.csv']:
    results = []
    with open(path) as f:
        reader = csv.DictReader(f)
        for r in reader:
            r['BLOCK_SIZE'] = '%010d' % int(r['BLOCK_SIZE'], 0)
            results.append(r)
    with open(path, 'w') as f:
        writer = csv.DictWriter(f, reader.fieldnames)
        writer.writeheader()
        for r in results:
            writer.writerow(r)
HERE


# plot results
./scripts/plotmpl.py \
    bench_btree_block_size.sh.raw_fixed.csv \
    bench_btree_block_size.sh.amortized_fixed.csv \
    -obench_btree_block_size.sh.svg \
    --legend \
    -xN \
    -DMODE=avg \
    -bBLOCK_SIZE \
    -W1600 -H600 \
    --ggplot --dark \
    --y2 --yunits=B \
    --xlabel="count" \
    --title="btree operations" \
    --subplot="-Dcase=bench_btree_lookup -ybench_readed --ylabel=bench_readed --title=btree_lookup --xticklabels=" \
        --subplot-below="-Dcase=bench_btree_lookup -ybench_proged --ylabel=bench_proged -Y0,1 --xticklabels=" \
        --subplot-below="-Dcase=bench_btree_lookup -ybench_erased --ylabel=bench_erased -Y0,1 -H0.33" \
    --subplot-right="-Dcase=bench_btree_commit -DAMORTIZED=0 -ybench_readed --title=btree_commit -W0.5 --xticklabels= \
        --subplot-below=\"-Dcase=bench_btree_commit -DAMORTIZED=0 -ybench_proged --xticklabels=\" \
        --subplot-below=\"-Dcase=bench_btree_commit -DAMORTIZED=0 -ybench_erased -H0.33\"" \
    --subplot-right="-Dcase=bench_btree_commit -DAMORTIZED=1 -ybench_readed --title='btree_commit (amortized)' -W0.33 --xticklabels= \
        --subplot-below=\"-Dcase=bench_btree_commit -DAMORTIZED=1 -ybench_proged --xticklabels=\" \
        --subplot-below=\"-Dcase=bench_btree_commit -DAMORTIZED=1 -ybench_erased -H0.33\"" \
    --colors=" \
        #a1c9f4bf,#a1c9f4bf,#a1c9f4bf, \
        #ffb482bf,#ffb482bf,#ffb482bf, \
        #8de5a1bf,#8de5a1bf,#8de5a1bf, \
        #ff9f9bbf,#ff9f9bbf,#ff9f9bbf, \
        #d0bbffbf,#d0bbffbf,#d0bbffbf, \
        #debb9bbf,#debb9bbf,#debb9bbf, \
        #fab0e4bf,#fab0e4bf,#fab0e4bf, \
        #cfcfcfbf,#cfcfcfbf,#cfcfcfbf, \
        #fffea3bf,#fffea3bf,#fffea3bf, \
        #b9f2f0bf,#b9f2f0bf,#b9f2f0bf" \
    --labels=" \
        bs=512,,, \
        bs=1024,,, \
        bs=2048,,, \
        bs=4096,,, \
        bs=8192,,, \
        bs=16384,,, \
        bs=32768,,,"


# a simple webpage for easy viewing
cat << HERE > bench_btree_block_size.sh.html
    <body style="background-color:#443333;">
    <img src="bench_btree_block_size.sh.svg">
HERE
