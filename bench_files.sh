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
        --cmp-ins)
            cmp=.ins
        ;;
        --cmp-frs)
            cmp=.frs
        ;;
        --cmp-crs)
            cmp=.crs
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
        -B bench_files \
        -DSEED="range($samples)" \
        $([[ "$cmp" == ".bs" ]] && echo "\
            -DBLOCK_SIZE=2048,4096,8192,16384") \
        $([[ "$cmp" == ".ins" ]] && echo "\
            -DINLINE_SIZE=0,8,64,512") \
        $([[ "$cmp" == ".frs" ]] && echo "\
            -DFRAGMENT_SIZE=8,16,32,64,128") \
        $([[ "$cmp" == ".crs" ]] && echo "\
            -DCRYSTAL_SIZE=0,8,64,512,4096") \
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
if [[ -z "$cmp" ]]
then 
    echo "plotting $0.sparseish.svg"
    ./scripts/plotmpl.py "$0.avg.csv" -o"$0.sparseish.svg" \
        -W1750 -H750 \
        --ggplot $([[ "$dark" ]] && echo "--dark") \
        -xbench_iter \
        -bORDER \
        -bBLOCK_SIZE \
        -bbench_agg \
        -Dcase=bench_files \
        -DREWRITE=0 \
        -Linorder=0,4096,avg,bench_readed \
        -L==0,4096,avg,bench_proged \
        -L==0,4096,avg,bench_erased \
        -L==0,4096,bnd,bench_readed \
        -L==0,4096,bnd,bench_proged \
        -L==0,4096,bnd,bench_erased \
        -Lreversed=1,4096,avg,bench_readed \
        -L==1,4096,avg,bench_proged \
        -L==1,4096,avg,bench_erased \
        -L==1,4096,bnd,bench_readed \
        -L==1,4096,bnd,bench_proged \
        -L==1,4096,bnd,bench_erased \
        -L'random aligned'=2,4096,avg,bench_readed \
        -L==2,4096,avg,bench_proged \
        -L==2,4096,avg,bench_erased \
        -L==2,4096,bnd,bench_readed \
        -L==2,4096,bnd,bench_proged \
        -L==2,4096,bnd,bench_erased \
        -L'random unaligned'=3,4096,avg,bench_readed \
        -L==3,4096,avg,bench_proged \
        -L==3,4096,avg,bench_erased \
        -L==3,4096,bnd,bench_readed \
        -L==3,4096,bnd,bench_proged \
        -L==3,4096,bnd,bench_erased \
        --y2 --yunits=B \
        --title="file operations - sparseish" \
        --subplot=" \
                -Dbench_meas=write \
                -ybench_readed \
                --ylabel=bench_readed \
                --title='write' \
                --xticklabels=" \
            --subplot-below=" \
                -Dbench_meas=write \
                -ybench_proged \
                --ylabel=bench_proged \
                --xticklabels= \
                -H0.5 " \
            --subplot-below=" \
                -Dbench_meas=write \
                -ybench_erased \
                --ylabel=bench_erased \
                -H0.33" \
        --subplot-right=" \
                -Dbench_meas=write+amor \
                -ybench_readed \
                --title='write (amortized)' \
                --xticklabels= \
                -W0.5 \
            --subplot-below=\" \
                -Dbench_meas=write+amor \
                -ybench_proged \
                --xticklabels= \
                -H0.5 \" \
            --subplot-below=\" \
                -Dbench_meas=write+amor \
                -ybench_erased \
                -H0.33\"" \
        --subplot-right=" \
                -Dbench_meas=read \
                -ybench_readed \
                --title='read' \
                --xticklabels= \
                -W0.33 \
            --subplot-below=\" \
                -Dbench_meas=read \
                -ybench_proged \
                --xticklabels= \
                -Y0,1 \
                -H0.5 \" \
            --subplot-below=\" \
                -Dbench_meas=read \
                -ybench_erased \
                -Y0,1 \
                -H0.33\"" \
        --subplot-right=" \
                -Dbench_meas=usage+per \
                -ybench_readed \
                --ylabel=bench_usage \
                --title='usage (per-byte)' \
                --xticklabels= \
                -Y0,16 \
                -W0.25 \
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

    echo "plotting $0.rewriting.svg"
    ./scripts/plotmpl.py "$0.avg.csv" -o"$0.rewriting.svg" \
        -W1750 -H750 \
        --ggplot $([[ "$dark" ]] && echo "--dark") \
        -xbench_iter \
        -bORDER \
        -bBLOCK_SIZE \
        -bbench_agg \
        -Dcase=bench_files \
        -DREWRITE=1 \
        -Linorder=0,4096,avg,bench_readed \
        -L==0,4096,avg,bench_proged \
        -L==0,4096,avg,bench_erased \
        -L==0,4096,bnd,bench_readed \
        -L==0,4096,bnd,bench_proged \
        -L==0,4096,bnd,bench_erased \
        -Lreversed=1,4096,avg,bench_readed \
        -L==1,4096,avg,bench_proged \
        -L==1,4096,avg,bench_erased \
        -L==1,4096,bnd,bench_readed \
        -L==1,4096,bnd,bench_proged \
        -L==1,4096,bnd,bench_erased \
        -L'random aligned'=2,4096,avg,bench_readed \
        -L==2,4096,avg,bench_proged \
        -L==2,4096,avg,bench_erased \
        -L==2,4096,bnd,bench_readed \
        -L==2,4096,bnd,bench_proged \
        -L==2,4096,bnd,bench_erased \
        -L'random unaligned'=3,4096,avg,bench_readed \
        -L==3,4096,avg,bench_proged \
        -L==3,4096,avg,bench_erased \
        -L==3,4096,bnd,bench_readed \
        -L==3,4096,bnd,bench_proged \
        -L==3,4096,bnd,bench_erased \
        --y2 --yunits=B \
        --title="file operations - rewriting" \
        --subplot=" \
                -Dbench_meas=write \
                -ybench_readed \
                --ylabel=bench_readed \
                --title='write' \
                --xticklabels=" \
            --subplot-below=" \
                -Dbench_meas=write \
                -ybench_proged \
                --ylabel=bench_proged \
                --xticklabels= \
                -H0.5 " \
            --subplot-below=" \
                -Dbench_meas=write \
                -ybench_erased \
                --ylabel=bench_erased \
                -H0.33" \
        --subplot-right=" \
                -Dbench_meas=write+amor \
                -ybench_readed \
                --title='write (amortized)' \
                --xticklabels= \
                -W0.5 \
            --subplot-below=\" \
                -Dbench_meas=write+amor \
                -ybench_proged \
                --xticklabels= \
                -H0.5 \" \
            --subplot-below=\" \
                -Dbench_meas=write+amor \
                -ybench_erased \
                -H0.33\"" \
        --subplot-right=" \
                -Dbench_meas=read \
                -ybench_readed \
                --title='read' \
                --xticklabels= \
                -W0.33 \
            --subplot-below=\" \
                -Dbench_meas=read \
                -ybench_proged \
                --xticklabels= \
                -Y0,1 \
                -H0.5 \" \
            --subplot-below=\" \
                -Dbench_meas=read \
                -ybench_erased \
                -Y0,1 \
                -H0.33\"" \
        --subplot-right=" \
                -Dbench_meas=usage+per \
                -ybench_readed \
                --ylabel=bench_usage \
                --title='usage (per-byte)' \
                --xticklabels= \
                -W0.25 \
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
fi

echo "plotting $0$cmp.linear.svg"
./scripts/plotmpl.py "$0.avg.csv" -o"$0$cmp.linear.svg" \
    -W1750 -H750 \
    --ggplot $([[ "$dark" ]] && echo "--dark") \
    -xbench_iter \
    $([[ "$cmp" == ".bs" ]] && echo "-bBLOCK_SIZE") \
    $([[ "$cmp" == ".ins" ]] && echo "-bINLINE_SIZE") \
    $([[ "$cmp" == ".frs" ]] && echo "-bFRAGMENT_SIZE") \
    $([[ "$cmp" == ".crs" ]] && echo "-bCRYSTAL_SIZE") \
    -bbench_agg \
    -Dcase=bench_files \
    -DORDER=0 \
    -DREWRITE=0 \
    $([[ -z "$cmp" ]] && echo '
        -Lrandom=avg,bench_readed
        -L==avg,bench_proged
        -L==avg,bench_erased
        -L==bnd,bench_readed
        -L==bnd,bench_proged
        -L==bnd,bench_erased') \
    $([[ "$cmp" == ".bs" ]] && awk -F, '
        NR==1 {for (i=1;i<=NF;i++) {if ($i == "BLOCK_SIZE") break}}
        NR>1 {bs[$i]=1}
        END {for (k in bs) {print k}}' \
        "$0$cmp.csv" \
        | sort -n \
        | awk '{
            printf("-Lbs\\=%s=%s,avg,bench_readed\n", $0, $0);
            printf("-L==%s,avg,bench_proged\n", $0);
            printf("-L==%s,avg,bench_erased\n", $0);
            printf("-L==%s,bnd,bench_readed\n", $0);
            printf("-L==%s,bnd,bench_proged\n", $0);
            printf("-L==%s,bnd,bench_erased\n", $0)}') \
    $([[ "$cmp" == ".ins" ]] && awk -F, '
        NR==1 {for (i=1;i<=NF;i++) {if ($i == "INLINE_SIZE") break}}
        NR>1 {ins[$i]=1}
        END {for (k in ins) {print k}}' \
        "$0$cmp.csv" \
        | sort -n \
        | awk '{
            printf("-Lins\\=%s=%s,avg,bench_readed\n", $0, $0);
            printf("-L==%s,avg,bench_proged\n", $0);
            printf("-L==%s,avg,bench_erased\n", $0);
            printf("-L==%s,bnd,bench_readed\n", $0);
            printf("-L==%s,bnd,bench_proged\n", $0);
            printf("-L==%s,bnd,bench_erased\n", $0)}') \
    $([[ "$cmp" == ".frs" ]] && awk -F, '
        NR==1 {for (i=1;i<=NF;i++) {if ($i == "FRAGMENT_SIZE") break}}
        NR>1 {frs[$i]=1}
        END {for (k in frs) {print k}}' \
        "$0$cmp.csv" \
        | sort -n \
        | awk '{
            printf("-Lfrs\\=%s=%s,avg,bench_readed\n", $0, $0);
            printf("-L==%s,avg,bench_proged\n", $0);
            printf("-L==%s,avg,bench_erased\n", $0);
            printf("-L==%s,bnd,bench_readed\n", $0);
            printf("-L==%s,bnd,bench_proged\n", $0);
            printf("-L==%s,bnd,bench_erased\n", $0)}') \
    $([[ "$cmp" == ".crs" ]] && awk -F, '
        NR==1 {for (i=1;i<=NF;i++) {if ($i == "CRYSTAL_SIZE") break}}
        NR>1 {crs[$i]=1}
        END {for (k in crs) {print k}}' \
        "$0$cmp.csv" \
        | sort -n \
        | awk '{
            printf("-Lcrs\\=%s=%s,avg,bench_readed\n", $0, $0);
            printf("-L==%s,avg,bench_proged\n", $0);
            printf("-L==%s,avg,bench_erased\n", $0);
            printf("-L==%s,bnd,bench_readed\n", $0);
            printf("-L==%s,bnd,bench_proged\n", $0);
            printf("-L==%s,bnd,bench_erased\n", $0)}') \
    --y2 --yunits=B \
    --title="file operations - linear writes" \
    --subplot=" \
            -Dbench_meas=write \
            -ybench_readed \
            --ylabel=bench_readed \
            --title='write' \
            --xticklabels=" \
        --subplot-below=" \
            -Dbench_meas=write \
            -ybench_proged \
            --ylabel=bench_proged \
            --xticklabels= \
            -H0.5 " \
        --subplot-below=" \
            -Dbench_meas=write \
            -ybench_erased \
            --ylabel=bench_erased \
            -H0.33" \
    --subplot-right=" \
            -Dbench_meas=write+amor \
            -ybench_readed \
            --title='write (amortized)' \
            --xticklabels= \
            -W0.5 \
        --subplot-below=\" \
            -Dbench_meas=write+amor \
            -ybench_proged \
            --xticklabels= \
            -H0.5 \" \
        --subplot-below=\" \
            -Dbench_meas=write+amor \
            -ybench_erased \
            -H0.33\"" \
    --subplot-right=" \
            -Dbench_meas=read \
            -ybench_readed \
            --title='read' \
            --xticklabels= \
            -W0.33 \
        --subplot-below=\" \
            -Dbench_meas=read \
            -ybench_proged \
            --xticklabels= \
            -Y0,1 \
            -H0.5 \" \
        --subplot-below=\" \
            -Dbench_meas=read \
            -ybench_erased \
            -Y0,1 \
            -H0.33\"" \
    --subplot-right=" \
            -Dbench_meas=usage+per \
            -ybench_readed \
            --ylabel=bench_usage \
            --title='usage (per-byte)' \
            --xticklabels= \
            -Y0,16 \
            -W0.25 \
        --subplot-below=\" \
            -Dbench_meas=usage \
            -ybench_readed \
            --ylabel=bench_usage \
            --title='usage (total)' \
            -H0.665\"" \
    $([[ "$cmp" ]] && echo "--legend") \
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

echo "plotting $0$cmp.random.svg"
./scripts/plotmpl.py "$0.avg.csv" -o"$0$cmp.random.svg" \
    -W1750 -H750 \
    --ggplot $([[ "$dark" ]] && echo "--dark") \
    -xbench_iter \
    $([[ "$cmp" == ".bs" ]] && echo "-bBLOCK_SIZE") \
    $([[ "$cmp" == ".ins" ]] && echo "-bINLINE_SIZE") \
    $([[ "$cmp" == ".frs" ]] && echo "-bFRAGMENT_SIZE") \
    $([[ "$cmp" == ".crs" ]] && echo "-bCRYSTAL_SIZE") \
    -bbench_agg \
    -Dcase=bench_files \
    -DORDER=3 \
    -DREWRITE=1 \
    $([[ -z "$cmp" ]] && echo '
        -Lrandom=avg,bench_readed
        -L==avg,bench_proged
        -L==avg,bench_erased
        -L==bnd,bench_readed
        -L==bnd,bench_proged
        -L==bnd,bench_erased') \
    $([[ "$cmp" == ".bs" ]] && awk -F, '
        NR==1 {for (i=1;i<=NF;i++) {if ($i == "BLOCK_SIZE") break}}
        NR>1 {bs[$i]=1}
        END {for (k in bs) {print k}}' \
        "$0$cmp.csv" \
        | sort -n \
        | awk '{
            printf("-Lbs\\=%s=%s,avg,bench_readed\n", $0, $0);
            printf("-L==%s,avg,bench_proged\n", $0);
            printf("-L==%s,avg,bench_erased\n", $0);
            printf("-L==%s,bnd,bench_readed\n", $0);
            printf("-L==%s,bnd,bench_proged\n", $0);
            printf("-L==%s,bnd,bench_erased\n", $0)}') \
    $([[ "$cmp" == ".ins" ]] && awk -F, '
        NR==1 {for (i=1;i<=NF;i++) {if ($i == "INLINE_SIZE") break}}
        NR>1 {ins[$i]=1}
        END {for (k in ins) {print k}}' \
        "$0$cmp.csv" \
        | sort -n \
        | awk '{
            printf("-Lins\\=%s=%s,avg,bench_readed\n", $0, $0);
            printf("-L==%s,avg,bench_proged\n", $0);
            printf("-L==%s,avg,bench_erased\n", $0);
            printf("-L==%s,bnd,bench_readed\n", $0);
            printf("-L==%s,bnd,bench_proged\n", $0);
            printf("-L==%s,bnd,bench_erased\n", $0)}') \
    $([[ "$cmp" == ".frs" ]] && awk -F, '
        NR==1 {for (i=1;i<=NF;i++) {if ($i == "FRAGMENT_SIZE") break}}
        NR>1 {frs[$i]=1}
        END {for (k in frs) {print k}}' \
        "$0$cmp.csv" \
        | sort -n \
        | awk '{
            printf("-Lfrs\\=%s=%s,avg,bench_readed\n", $0, $0);
            printf("-L==%s,avg,bench_proged\n", $0);
            printf("-L==%s,avg,bench_erased\n", $0);
            printf("-L==%s,bnd,bench_readed\n", $0);
            printf("-L==%s,bnd,bench_proged\n", $0);
            printf("-L==%s,bnd,bench_erased\n", $0)}') \
    $([[ "$cmp" == ".crs" ]] && awk -F, '
        NR==1 {for (i=1;i<=NF;i++) {if ($i == "CRYSTAL_SIZE") break}}
        NR>1 {crs[$i]=1}
        END {for (k in crs) {print k}}' \
        "$0$cmp.csv" \
        | sort -n \
        | awk '{
            printf("-Lcrs\\=%s=%s,avg,bench_readed\n", $0, $0);
            printf("-L==%s,avg,bench_proged\n", $0);
            printf("-L==%s,avg,bench_erased\n", $0);
            printf("-L==%s,bnd,bench_readed\n", $0);
            printf("-L==%s,bnd,bench_proged\n", $0);
            printf("-L==%s,bnd,bench_erased\n", $0)}') \
    --y2 --yunits=B \
    --title="file operations - random writes" \
    --subplot=" \
            -Dbench_meas=write \
            -ybench_readed \
            --ylabel=bench_readed \
            --title='write' \
            --xticklabels=" \
        --subplot-below=" \
            -Dbench_meas=write \
            -ybench_proged \
            --ylabel=bench_proged \
            --xticklabels= \
            -H0.5 " \
        --subplot-below=" \
            -Dbench_meas=write \
            -ybench_erased \
            --ylabel=bench_erased \
            -H0.33" \
    --subplot-right=" \
            -Dbench_meas=write+amor \
            -ybench_readed \
            --title='write (amortized)' \
            --xticklabels= \
            -W0.5 \
        --subplot-below=\" \
            -Dbench_meas=write+amor \
            -ybench_proged \
            --xticklabels= \
            -H0.5 \" \
        --subplot-below=\" \
            -Dbench_meas=write+amor \
            -ybench_erased \
            -H0.33\"" \
    --subplot-right=" \
            -Dbench_meas=read \
            -ybench_readed \
            --title='read' \
            --xticklabels= \
            -W0.33 \
        --subplot-below=\" \
            -Dbench_meas=read \
            -ybench_proged \
            --xticklabels= \
            -Y0,1 \
            -H0.5 \" \
        --subplot-below=\" \
            -Dbench_meas=read \
            -ybench_erased \
            -Y0,1 \
            -H0.33\"" \
    --subplot-right=" \
            -Dbench_meas=usage+per \
            -ybench_readed \
            --ylabel=bench_usage \
            --title='usage (per-byte)' \
            --xticklabels= \
            -W0.25 \
        --subplot-below=\" \
            -Dbench_meas=usage \
            -ybench_readed \
            --ylabel=bench_usage \
            --title='usage (total)' \
            -H0.665\"" \
    $([[ "$cmp" ]] && echo "--legend") \
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
    $([[ -z "$cmp" ]] \
        && echo "
            <img src=\"$(basename $0).sparseish.svg\">
            <p></p>
            <img src=\"$(basename $0).rewriting.svg\">
            <p></p>")
    <img src="$(basename $0)$cmp.linear.svg">
    <p></p>
    <img src="$(basename $0)$cmp.random.svg">
HERE

