#!/bin/bash

set -eu -o pipefail

# first arg = samples
samples="${1:-1}"
shift || true

# --cmp-bs => compare block sizes
# allow --dark for dark mode
# rest gets passed to bench.py
args+=()
cmp=
dark=
while [[ "$#" -gt 0 ]]
do
    case "$1" in 
        --cmp-bs)
            cmp=.bs
        ;;
        --dark)
            dark=1
        ;;
        *)
            args+=("$1")
        ;;
    esac
    shift
done

# run benchmarks
echo "benching $samples samples $0$cmp.csv"
if [[ "$samples" -gt 0 ]]
then
    ./scripts/bench.py -j -Gnor -o"$0$cmp.csv" \
        -B bench_mtree \
        -DSEED="range($samples)" \
        $([[ "$cmp" == ".bs" ]] && echo "\
            -DORDER=2 \
            -DBLOCK_SIZE=2048,4096,8192,16384") \
        ${args[@]}
fi

# compute amors/avgs
echo "amortizing $0.amor.csv"
./scripts/amor.py "$0$cmp.csv" -o "$0.amor.csv" \
    --amor --per \
    -mbench_meas \
    -ibench_iter \
    -nbench_size \
    -fbench_readed -fbench_proged -fbench_erased
echo "averaging $0.avg.csv"
./scripts/avg.py "$0$cmp.csv" "$0.amor.csv" -o "$0.avg.csv" \
    --avg --bnd \
    -mbench_agg \
    -sSEED \
    -fbench_readed -fbench_proged -fbench_erased

# plot results
echo "plotting $0$cmp.svg"
./scripts/plotmpl.py "$0.avg.csv" -o"$0$cmp.svg" \
    -W1750 -H750 \
    --ggplot $([[ "$dark" ]] && echo "--dark") \
    -xbench_iter \
    -bORDER \
    -bBLOCK_SIZE \
    -bbench_agg \
    -Dcase=bench_mtree \
    $([[ "$cmp" == ".bs" ]] \
        && awk -F, '
            NR==1 {for (i=1;i<=NF;i++) {if ($i == "BLOCK_SIZE") break}}
            NR>1 {bs[$i]=1}
            END {for (k in bs) {print k}}' \
            "$0$cmp.csv" \
            | sort -n \
            | awk '{
                printf("-Lbs\\=%s=2,%s,avg,bench_readed\n", $0, $0);
                printf("-L==2,%s,avg,bench_proged\n", $0);
                printf("-L==2,%s,avg,bench_erased\n", $0);
                printf("-L==2,%s,bnd,bench_readed\n", $0);
                printf("-L==2,%s,bnd,bench_proged\n", $0);
                printf("-L==2,%s,bnd,bench_erased\n", $0)}' \
        || echo '
            -Linorder=0,4096,avg,bench_readed
            -L==0,4096,avg,bench_proged
            -L==0,4096,avg,bench_erased
            -L==0,4096,bnd,bench_readed
            -L==0,4096,bnd,bench_proged
            -L==0,4096,bnd,bench_erased
            -Lreversed=1,4096,avg,bench_readed
            -L==1,4096,avg,bench_proged
            -L==1,4096,avg,bench_erased
            -L==1,4096,bnd,bench_readed
            -L==1,4096,bnd,bench_proged
            -L==1,4096,bnd,bench_erased
            -Lrandom=2,4096,avg,bench_readed
            -L==2,4096,avg,bench_proged
            -L==2,4096,avg,bench_erased
            -L==2,4096,bnd,bench_readed
            -L==2,4096,bnd,bench_proged
            -L==2,4096,bnd,bench_erased') \
    --y2 --yunits=B \
    --title="mtree operations" \
    --subplot=" \
            -Dbench_meas=commit \
            -ybench_readed \
            --ylabel=bench_readed \
            --title=commit \
            --xticklabels=" \
        --subplot-below=" \
            -Dbench_meas=commit \
            -ybench_proged \
            --ylabel=bench_proged
            -H0.5 " \
        --subplot-below=" \
            -Dbench_meas=commit \
            -ybench_erased \
            --ylabel=bench_erased \
            -H0.33" \
    --subplot-right=" \
            -Dbench_meas=commit+amor \
            -ybench_readed \
            --title='commit (amortized)' \
            --xticklabels= \
            -W0.5 \
        --subplot-below=\" \
            -Dbench_meas=commit+amor \
            -ybench_proged \
            -H0.5 \" \
        --subplot-below=\" \
            -Dbench_meas=commit+amor \
            -ybench_erased \
            -Y0,1024 \
            -H0.33\"" \
    --subplot-right=" \
            -Dbench_meas=namelookup \
            -ybench_readed \
            --title='namelookup' \
            --xticklabels= \
            -W0.33 \
        --subplot-below=\" \
            -Dbench_meas=namelookup \
            -ybench_proged \
            -Y0,1 \
            -H0.5 \" \
        --subplot-below=\" \
            -Dbench_meas=namelookup \
            -ybench_erased \
            -Y0,1 \
            -H0.33\"" \
    --subplot-right=" \
            -Dbench_meas=lookup \
            -ybench_readed \
            --title='lookup' \
            --xticklabels= \
            -W0.25 \
        --subplot-below=\" \
            -Dbench_meas=lookup \
            -ybench_proged \
            -Y0,1 \
            -H0.5 \" \
        --subplot-below=\" \
            -Dbench_meas=lookup \
            -ybench_erased \
            -Y0,1 \
            -H0.33\"" \
    --subplot-right=" \
            -Dbench_meas=traversal+per \
            -ybench_readed \
            --title='traversal (per-entry)' \
            --xticklabels= \
            -Y0,1024 \
            -W0.20 \
        --subplot-below=\" \
            -Dbench_meas=traversal+per \
            -ybench_proged \
            -Y0,1 \
            -H0.5 \" \
        --subplot-below=\" \
            -Dbench_meas=traversal+per \
            -ybench_erased \
            -Y0,1 \
            -H0.33\"" \
    --subplot-right=" \
            -Dbench_meas=usage+per \
            -ybench_readed \
            --ylabel=bench_usage \
            --title='usage (per-entry)' \
            --xticklabels= \
            -Y0,1024 \
            -W0.16 \
        --subplot-below=\" \
            -Dbench_meas=usage \
            -ybench_readed \
            --ylabel=bench_usage \
            --title='usage (total)' \
            -H0.665\"" \
    --legend \
    --colors=" \
        #4c72b0bf,#4c72b0bf,#4c72b0bf, \
        #4c72b03f,#4c72b03f,#4c72b03f, \
        #dd8452bf,#dd8452bf,#dd8452bf, \
        #dd84523f,#dd84523f,#dd84523f, \
        #55a868bf,#55a868bf,#55a868bf, \
        #55a8683f,#55a8683f,#55a8683f, \
        #c44e52bf,#c44e52bf,#c44e52bf, \
        #c44e523f,#c44e523f,#c44e523f, \
        #8172b3bf,#8172b3bf,#8172b3bf, \
        #8172b33f,#8172b33f,#8172b33f, \
        #937860bf,#937860bf,#937860bf, \
        #9378603f,#9378603f,#9378603f, \
        #da8bc3bf,#da8bc3bf,#da8bc3bf, \
        #da8bc33f,#da8bc33f,#da8bc33f, \
        #8c8c8cbf,#8c8c8cbf,#8c8c8cbf, \
        #8c8c8c3f,#8c8c8c3f,#8c8c8c3f, \
        #ccb974bf,#ccb974bf,#ccb974bf, \
        #ccb9743f,#ccb9743f,#ccb9743f, \
        #64b5cdbf,#64b5cdbf,#64b5cdbf, \
        #64b5cd3f,#64b5cd3f,#64b5cd3f"


# a simple webpage for easy viewing
echo "generating $0.html"
cat << HERE > "$0.html"
    $([[ "$dark" ]] \
        && echo '<body style="background-color:#443333;">' \
        || echo '<body style="background-color:#ccbbbb;">')
    <img src="$(basename $0)$cmp.svg">
HERE

