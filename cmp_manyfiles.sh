#!/bin/bash

set -eu -o pipefail

# path to benchmark script
path="${1:-}"

# first title/prefix
title1="${2:-}"
prefix1="${3:-}"
prefix1="${prefix1:+.$prefix1}"

# second title/prefix
title2="${4:-}"
prefix2="${5:-}"
prefix2="${prefix2:+.$prefix2}"

python << HERE
import csv
import collections as co
ys = ['bench_readed', 'bench_proged', 'bench_erased']
for prefix in ['$prefix1', '$prefix2']:
    for bench in ['create_raw', 'create_amor', 'read']:
        results = []
        print('prfxing %s' % ('$path%s.%s_.csv' % (prefix, bench)))
        with open('$path%s.%s_.csv' % (prefix, bench)) as f:
            reader = csv.DictReader(f)
            fieldnames = reader.fieldnames.copy()
            for r in reader:
                results.append(r)

        with open('$0%s.%s_.csv' % (prefix, bench), 'w') as f:
            writer = csv.DictWriter(f, fieldnames + ['PREFIX'],
                extrasaction='ignore')
            writer.writeheader()
            for r in results:
                writer.writerow(r | {'PREFIX': 'p'+prefix})
HERE

# plot results
./scripts/plotmpl.py \
    "$0$prefix1.create_raw_.csv" \
    "$0$prefix1.create_amor_.csv" \
    "$0$prefix1.read_.csv" \
    "$0$prefix2.create_raw_.csv" \
    "$0$prefix2.create_amor_.csv" \
    "$0$prefix2.read_.csv" \
    -o"$0.svg" \
    -W1600 -H700 \
    --ggplot \
    --title="littlefs - Many-file overhead" \
    -xN \
    -bPREFIX \
    -DSIZE=512 \
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
        $title1,,,,,, \
        $title2,,,,,, " \
    --colors="
        #4c72b0bf,#4c72b0bf,#4c72b0bf, \
        #4c72b03f,#4c72b03f,#4c72b03f, \
        #dd8452bf,#dd8452bf,#dd8452bf, \
        #dd84523f,#dd84523f,#dd84523f, "

# and generate a simple webpage for easy viewing
cat << HERE > "$0.html"
    <body style="background-color:#443333;">
    <img src="$(basename $0).svg">
    <p></p>
    <img src="$(basename $path)$prefix1.svg">
    <p></p>
    <img src="$(basename $path)$prefix2.svg">
HERE

