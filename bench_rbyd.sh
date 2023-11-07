#!/bin/bash

set -eu -o pipefail

# first arg = samples
samples="${1:-1}"
shift || true

# allow --github for github formatting
# rest gets passed to bench.py
args+=()
style="--ggplot --dark"
while [[ "$#" -gt 0 ]]
do
    case "$1" in 
        --light)
            style="--ggplot"
        ;;
        *)
            args+=("$1")
        ;;
    esac
    shift
done

# run benchmarks
echo "benching $samples samples $0.csv"
if [[ "$samples" -gt 0 ]]
then
    ./scripts/bench.py -j -Gnor -o"$0.csv" \
        -B bench_rbyd \
        -DSEED="range($samples)" \
        ${args[@]}
fi

# compute amors/avgs
echo "amortizing $0.amor.csv"
./scripts/amor.py "$0.csv" -o "$0.amor.csv" \
    --amor --per \
    -mbench_meas \
    -ibench_iter \
    -nbench_size \
    -fbench_readed -fbench_proged -fbench_erased
echo "averaging $0.avg.csv"
./scripts/avg.py "$0.csv" "$0.amor.csv" -o "$0.avg.csv" \
    --avg --bnd \
    -mbench_agg \
    -sSEED \
    -fbench_readed -fbench_proged -fbench_erased

# plot results
echo "plotting $0.svg"
./scripts/plotmpl.py "$0.avg.csv" -o"$0.attr.svg" \
    -W1750 -H500 \
    $style \
    -xbench_iter \
    -bORDER \
    -bbench_agg \
    -Linorder=0,avg,bench_readed \
    -L==0,avg,bench_proged \
    -L==0,bnd,bench_readed \
    -L==0,bnd,bench_proged \
    -Lreversed=1,avg,bench_readed \
    -L==1,avg,bench_proged \
    -L==1,bnd,bench_readed \
    -L==1,bnd,bench_proged \
    -Lrandom=2,avg,bench_readed \
    -L==2,avg,bench_proged \
    -L==2,bnd,bench_readed \
    -L==2,bnd,bench_proged \
    --y2 --yunits=B \
    --title="rbyd attr operations" \
    --subplot=" \
            -Dcase=bench_rbyd_attr_append \
            -Dbench_meas=append \
            -ybench_readed \
            --ylabel=bench_readed \
            --title=append \
            --xticklabels=" \
        --subplot-below=" \
            -Dbench_meas=append \
            -ybench_proged \
            --ylabel=bench_proged" \
    --subplot-right=" \
            -Dcase=bench_rbyd_attr_remove \
            -Dbench_meas=remove \
            -ybench_readed \
            --title='remove' \
            --xticklabels= \
            -W0.5 \
        --subplot-below=\" \
            -Dbench_meas=remove \
            -ybench_proged\"" \
    --subplot-right=" \
            -Dcase=bench_rbyd_attr_fetch \
            -Dbench_meas=fetch+per \
            -ybench_readed \
            --title='fetch (per-attr)' \
            --xticklabels= \
            -W0.33 \
        --subplot-below=\" \
            -Dbench_meas=fetch+per \
            -ybench_proged \
            -Y0,1\"" \
    --subplot-right=" \
            -Dcase=bench_rbyd_attr_lookup \
            -Dbench_meas=lookup \
            -ybench_readed \
            --title=lookup \
            --xticklabels= \
            -W0.25 \
        --subplot-below=\" \
            -Dbench_meas=lookup \
            -ybench_proged \
            -Y0,1\"" \
    --subplot-right=" \
            -Dcase=bench_rbyd_attr_usage \
            -Dbench_meas=usage+per \
            -ybench_readed \
            --ylabel=bench_usage \
            --title='usage (per-attr)' \
            --xticklabels= \
            -W0.20 \
        --subplot-below=\" \
            -Dbench_meas=usage \
            -ybench_readed \
            --ylabel=bench_usage \
            --title='usage (total)'\"" \
    --legend \
    --colors=" \
        #4c72b0bf,#4c72b0bf, \
        #4c72b03f,#4c72b03f, \
        #dd8452bf,#dd8452bf, \
        #dd84523f,#dd84523f, \
        #55a868bf,#55a868bf, \
        #55a8683f,#55a8683f"

echo "plotting $0.svg"
./scripts/plotmpl.py "$0.avg.csv" -o"$0.id.svg" \
    -W1750 -H500 \
    $style \
    -xbench_iter \
    -bORDER \
    -bbench_agg \
    -Linorder=0,avg,bench_readed \
    -L==0,avg,bench_proged \
    -L==0,bnd,bench_readed \
    -L==0,bnd,bench_proged \
    -Lreversed=1,avg,bench_readed \
    -L==1,avg,bench_proged \
    -L==1,bnd,bench_readed \
    -L==1,bnd,bench_proged \
    -Lrandom=2,avg,bench_readed \
    -L==2,avg,bench_proged \
    -L==2,bnd,bench_readed \
    -L==2,bnd,bench_proged \
    --y2 --yunits=B \
    --title="rbyd id operations" \
    --subplot=" \
            -Dcase=bench_rbyd_id_create \
            -Dbench_meas=create \
            -ybench_readed \
            --ylabel=bench_readed \
            --title=create \
            --xticklabels=" \
        --subplot-below=" \
            -Dbench_meas=create \
            -ybench_proged \
            --ylabel=bench_proged" \
    --subplot-right=" \
            -Dcase=bench_rbyd_id_delete \
            -Dbench_meas=delete \
            -ybench_readed \
            --title='delete' \
            --xticklabels= \
            -W0.5 \
        --subplot-below=\" \
            -Dbench_meas=delete \
            -ybench_proged\"" \
    --subplot-right=" \
            -Dcase=bench_rbyd_id_fetch \
            -Dbench_meas=fetch+per \
            -ybench_readed \
            --title='fetch (per-attr)' \
            --xticklabels= \
            -W0.33 \
        --subplot-below=\" \
            -Dbench_meas=fetch+per \
            -ybench_proged \
            -Y0,1\"" \
    --subplot-right=" \
            -Dcase=bench_rbyd_id_lookup \
            -Dbench_meas=lookup \
            -ybench_readed \
            --title=lookup \
            --xticklabels= \
            -W0.25 \
        --subplot-below=\" \
            -Dbench_meas=lookup \
            -ybench_proged \
            -Y0,1\"" \
    --subplot-right=" \
            -Dcase=bench_rbyd_id_usage \
            -Dbench_meas=usage+per \
            -ybench_readed \
            --ylabel=bench_usage \
            --title='usage (per-attr)' \
            --xticklabels= \
            -W0.20 \
        --subplot-below=\" \
            -Dbench_meas=usage \
            -ybench_readed \
            --ylabel=bench_usage \
            --title='usage (total)'\"" \
    --legend \
    --colors=" \
        #4c72b0bf,#4c72b0bf, \
        #4c72b03f,#4c72b03f, \
        #dd8452bf,#dd8452bf, \
        #dd84523f,#dd84523f, \
        #55a868bf,#55a868bf, \
        #55a8683f,#55a8683f"

# and a simple webpage for easy viewing
echo "generating $0.html"
cat << HERE > "$0.html"
    <body style="background-color:#443333;">
    <img src="$(basename $0).attr.svg">
    <p></p>
    <img src="$(basename $0).id.svg">
HERE
