#!/bin/bash

set -eu -o pipefail

# range of N to run
count="$(echo "${1:-}" | cut -d, -f1)"
step="$(echo "${1:-}," | cut -d, -f2)"
samples="$(echo "${1:-},," | cut -d, -f3)"
count="${count:-1024}"
step="${step:-1}"
samples="${samples:-1}"
echo "benching $count,$step,$samples"

# run the benches
if [[ $count -ne 0 ]]
then
    # benchmark raw create time
    ./scripts/bench.py -j -Gnor \
        bench_manyfiles_create \
        -DDISK_SIZE=1073741824 \
        -DN="range(1,$((count+1)),$step)" \
        -DAMORTIZED=0 \
        -DSEED="range(1,$((samples+1)))" \
        -o"$0".create_raw.csv
    # benchmark amortized create time
    ./scripts/bench.py -j -Gnor \
        bench_manyfiles_create \
        -DDISK_SIZE=1073741824 \
        -DN="range(1,$((count+1)),$step)" \
        -DAMORTIZED=1 \
        -DSEED="range(1,$((samples+1)))" \
        -o"$0".create_amor.csv
    # benchmark read time
    ./scripts/bench.py -j -Gnor \
        bench_manyfiles_read \
        -DDISK_SIZE=1073741824 \
        -DN="range(1,$((count+1)),$step)" \
        -DSEED="range(1,$((samples+1)))" \
        -o"$0".read.csv
fi


# find avg/min/max of results
python << HERE
import csv
import collections as co
ys = ['bench_readed', 'bench_proged', 'bench_erased']
for bench in ['create_raw', 'read']:
    print('avging %s' % ('$0.%s.csv' % bench))
    results = co.OrderedDict()
    with open('$0.%s.csv' % bench) as f:
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

    with open('$0.%s_.csv' % bench, 'w') as f:
        writer = csv.DictWriter(f, fieldnames + ['MODE'], extrasaction='ignore')
        writer.writeheader()
        for r in results.values():
            writer.writerow(r | {'MODE': 'avg'} | {y: r[y+'_avg'] for y in ys})
            writer.writerow(r | {'MODE': 'bnd'} | {y: r[y+'_min'] for y in ys})
            writer.writerow(r | {'MODE': 'bnd'} | {y: r[y+'_max'] for y in ys})
HERE

# actually amortize to amortized results
python << HERE
import csv
import collections as co
ys = ['bench_readed', 'bench_proged', 'bench_erased']
print('avging %s' % '$0.create_amor.csv')
results = co.OrderedDict()
with open('$0.create_amor.csv') as f:
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

with open('$0.create_amor_.csv', 'w') as f:
    writer = csv.DictWriter(f, fieldnames + ['MODE'], extrasaction='ignore')
    writer.writeheader()
    for r in results.values():
        writer.writerow(r | {'MODE': 'avg'} | {y: r[y+'_avg'] for y in ys})
        writer.writerow(r | {'MODE': 'bnd'} | {y: r[y+'_min'] for y in ys})
        writer.writerow(r | {'MODE': 'bnd'} | {y: r[y+'_max'] for y in ys})
HERE

# plot results
./scripts/plotmpl.py \
    "$0".create_raw_.csv \
    "$0".create_amor_.csv \
    "$0".read_.csv \
    -o"$0".svg \
    -W1600 -H700 \
    --ggplot \
    --title="File create overhead" \
    -xN \
    -bSIZE \
    -bMODE \
    --xlabel="number of files" \
    --y2 --yunits=B \
    --subplot="-Dcase=bench_manyfiles_create \
            -DAMORTIZED=0 \
            -ybench_readed \
            --ylabel=bench_readed \
            --title=create \
            --xticklabels=" \
        --subplot-below="-Dcase=bench_manyfiles_create \
            -DAMORTIZED=0 \
            -ybench_proged \
            --ylabel=bench_proged \
            --xticklabels=" \
        --subplot-below="-Dcase=bench_manyfiles_create \
            -DAMORTIZED=0 \
            -ybench_erased \
            --ylabel=bench_erased \
            -H0.33" \
    --subplot-right="-Dcase=bench_manyfiles_create \
            -DAMORTIZED=1 \
            -ybench_readed \
            --title='create (amortized)' \
            --xticklabels= \
        --subplot-below=\"-Dcase=bench_manyfiles_create \
            -DAMORTIZED=1 \
            -ybench_proged \
            --xticklabels=\" \
        --subplot-below=\"-Dcase=bench_manyfiles_create \
            -DAMORTIZED=1 \
            -ybench_erased \
            -H0.33\"" \
    --subplot-right="-Dcase=bench_manyfiles_read \
            -ybench_readed \
            --title=read \
            --xticklabels= \
            -W0.33 \
        --subplot-below=\"-Dcase=bench_manyfiles_read \
            -ybench_proged \
            --xticklabels= \
            -Y0,1 \" \
        --subplot-below=\"-Dcase=bench_manyfiles_read \
            -ybench_erased \
            -Y0,1 \
            -H0.33\"" \
    --legend \
    --labels=" \
        inlined=0B,,,,,, \
        inlined=16B,,,,,, \
        inlined=512B,,,,,, " \
    --colors="
        #4c72b0bf,#4c72b0bf,#4c72b0bf, \
        #4c72b03f,#4c72b03f,#4c72b03f, \
        #dd8452bf,#dd8452bf,#dd8452bf, \
        #dd84523f,#dd84523f,#dd84523f, \
        #55a868bf,#55a868bf,#55a868bf, \
        #55a8683f,#55a8683f,#55a8683f, "

# and generate a simple webpage for easy viewing
cat << HERE > "$0".html
    <body style="background-color:#443333;">
    <img src="$(basename $0).svg">
HERE

