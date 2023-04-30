#!/bin/bash

set -eu -o pipefail

# actually amortize to amortized results
# find avg/min/max of results
for f in "$@"
do
python << HERE
import csv
import collections as co
results = co.OrderedDict()
ys = ['bench_readed', 'bench_proged', 'bench_erased']
with open('$(echo "$f" | cut -d= -f2 | cut -d, -f1)') as f:
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

with open('$(echo "$f" | cut -d= -f2 | cut -d, -f1 | sed 's/.csv$/_fixed&/')', 'w') as f:
    writer = csv.DictWriter(f, fieldnames + ['MODE', 'CMP'], extrasaction='ignore')
    writer.writeheader()
    for r in results.values():
        writer.writerow(r | {'CMP': '$(echo "$f" | cut -d= -f1)', 'MODE': 'avg'} | {y: r[y+'_avg'] for y in ys})
        writer.writerow(r | {'CMP': '$(echo "$f" | cut -d= -f1)', 'MODE': 'bnd'} | {y: r[y+'_min'] for y in ys})
        writer.writerow(r | {'CMP': '$(echo "$f" | cut -d= -f1)', 'MODE': 'bnd'} | {y: r[y+'_max'] for y in ys})
HERE
done
for f in "$@"
do
python << HERE
import csv
import collections as co
results = co.OrderedDict()
ys = ['bench_readed', 'bench_proged', 'bench_erased']
with open('$(echo "$f" | cut -d= -f2 | cut -d, -f2)') as f:
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

with open('$(echo "$f" | cut -d= -f2 | cut -d, -f2 | sed 's/.csv$/_fixed&/')', 'w') as f:
    writer = csv.DictWriter(f, fieldnames + ['MODE', 'CMP'], extrasaction='ignore')
    writer.writeheader()
    for r in results.values():
        writer.writerow(r | {'CMP': '$(echo "$f" | cut -d= -f1)', 'MODE': 'avg'} | {y: r[y+'_avg'] for y in ys})
        writer.writerow(r | {'CMP': '$(echo "$f" | cut -d= -f1)', 'MODE': 'bnd'} | {y: r[y+'_min'] for y in ys})
        writer.writerow(r | {'CMP': '$(echo "$f" | cut -d= -f1)', 'MODE': 'bnd'} | {y: r[y+'_max'] for y in ys})
HERE
done

# plot results
./scripts/plotmpl.py \
    $(for f in "$@" ; do echo "$f" | cut -d= -f2 | cut -d, -f1 | sed 's/.csv$/_fixed&/' ; done) \
    $(for f in "$@" ; do echo "$f" | cut -d= -f2 | cut -d, -f2 | sed 's/.csv$/_fixed&/' ; done) \
    -obench_btree_cmp.sh.svg \
    --legend \
    -xN \
    -DORDER=2 \
    -bMODE \
    -bCMP \
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
    --colors=" \
        #a1c9f4bf,#a1c9f4bf,#a1c9f4bf, \
        #ffb482bf,#ffb482bf,#ffb482bf, \
        #a1c9f43f,#a1c9f43f,#a1c9f43f, \
        #ffb4823f,#ffb4823f,#ffb4823f, " \
    --labels=" \
        $(for f in "$@" ; do echo "$f" | cut -d= -f1 ; echo ,,, ; done) \
        ,,, \
        ,,, "



# a simple webpage for easy viewing
cat << HERE > bench_btree_cmp.sh.html
    <body style="background-color:#443333;">
    <img src="bench_btree_cmp.sh.svg">
HERE
