#!/bin/bash

set -eu -o pipefail

size="${1:-256}"
count="${2:-16}"
block_size="${3:-128,256,512,1024,2048,4096,8192,16384}"



python << HERE
import math as m
import csv

def rbyd_bound(block_size=None, *,
        size=0xffffffff,
        weight=0xffffffff):
    # space for revision count and crc32c
    off = 4 + 8+4
    count = 0

    while True:
        # strict bound of rbyd is 2*log2(n)+1, assume this
        # many alt pointers
        if count == 0:
            alts = 0
        else:
            alts = 2*m.ceil(m.log2(count)) + 1

        # assume worst case alt encoding, 16-bit tag + 2 leb128s
        off += alts*(
            2
            + m.ceil(m.log(max(weight, 1), 128))
            + m.ceil(m.log(max(block_size/2, 1), 128)))

        # assume worst case tag encoding, 16-bit tag + 2 leb128s
        off += (
            2
            + m.ceil(m.log(max(weight, 1), 128))
            + m.ceil(m.log(max(size, 1), 128)))

        # and don't forget the actual data
        off += size

        # do we still fit?
        # 
        # note we want to be able to compact, so look at the
        # 1/2 block_size threshold
        if off > block_size // 2:
            return count

        # try to fit another tag
        count += 1

with open('bench_rbyd_phase.sh.csv', 'w') as f:
    writer = csv.DictWriter(f, ['block_size', 'size', 'count'])
    writer.writeheader()
    # for each block_size
    for block_size in [$block_size]:
        # find upper bound for each size
        for size in range($size):
            count = rbyd_bound(block_size=block_size, size=size)
            writer.writerow({
                # prefix with zeros for lexicographic ordering
                'block_size': '%010d' % block_size,
                'size': size,
                'count': count})
HERE


# plot results
./scripts/plotmpl.py \
    bench_rbyd_phase.sh.csv \
    -obench_rbyd_phase.sh.svg \
    -bblock_size \
    --legend \
    -xsize \
    --xlabel=size \
    -ycount \
    --ylabel=count \
    -Y"$count" \
    --title="rbyd tag bounds" \
    --ggplot \
    --dark \
    --labels="$(echo $block_size | sed 's/\</bs=/g')"

# a simple webpage for easy viewing
cat << HERE > bench_rbyd_phase.sh.html
    <body style="background-color:#443333;">
    <img src="bench_rbyd_phase.sh.svg">
HERE
