ifndef BENCH_MOUNT_DS_MK
BENCH_MOUNT_DS_MK := 1

# prevent parallel benching because of how big disk is
DISK_BIG = 1

# include build rules + filesystems
include Makefiles/build.mk

# overrideable results dir
MOUNT_DS_RESULTSDIR ?= $(RESULTSDIR)/mount_ds
# overrideable plots dir
MOUNT_DS_PLOTSDIR ?= $(PLOTSDIR)/mount_ds
# overrideable tikz dir
MOUNT_DS_TIKZDIR ?= $(TIKZDIR)/mount_ds


# what percentile are we interested in?
MOUNT_DS_P ?= avg,p90,p99,max

# run with powerloss
MOUNT_DS_POWERLOSS ?= 0,1,2

# range of disk sizes to test
#
# note this needs to be >>2n, probably ~4n to be safe
MOUNT_DS_DISK_SIZES ?= $\
		4194304,$\
		8388608,16777216,33554432,67108864,134217728,268435456,$\
		536870912,1073741824,2147483648,4294967296,8589934592


# default bench filesystems to default bench filesystems
BENCH_FILESYSTEMS ?= $(DEFAULT_BENCH_FILESYSTEMS)

# default disk geometries to default disk geometries
BENCH_GEOMETRIES ?= $(DEFAULT_BENCH_GEOMETRIES)

# list of interesting bench cases
BENCH_CASES ?= logging # seq random logging many


# this is a bit of a hack, but we want to make sure the BUILDDIR
# directory structure is correct before we run any commands
ifneq ($(MOUNT_DS_RESULTSDIR),.)
$(if $(findstring n,$(MAKEFLAGS)),, \
		$(foreach d, \
				$(MOUNT_DS_RESULTSDIR) \
				$(MOUNT_DS_PLOTSDIR) \
				$(MOUNT_DS_TIKZDIR), \
            $(if $(wildcard $d),, $(shell mkdir -p $d))))
endif


#======================================================================#
# bench rules                                                          #
#======================================================================#

## Run benches
.PHONY: all bench bench-mount-ds
all bench: bench-mount-ds
bench-mount-ds: \
		$(foreach c, $(BENCH_CASES), \
			$(foreach fs, $(BENCH_FILESYSTEMS), \
				$(foreach g, $(BENCH_GEOMETRIES), \
					$(MOUNT_DS_RESULTSDIR)/bench_mount_ds.$(c).$(fs).$(g).csv)))

# core bench rule
#
# $1 - target
# $2 - bench case
# $3 - fs type/version
# $4 - disk geometry
# $5 - percentiles
# $6 - powerloss
# $7 - disk sizes
#
# the --isolate is because we're leaking memory every pl
#
define BENCH_MOUNT_DS_RULE
$1: $($(U_$3)_BENCH_RUNNER)
	$$(strip ./scripts/bench.py -R$$< -B bench_mount_$2 \
		$(BENCHFLAGS) $($(U_$3)_BENCHFLAGS) \
		--isolate \
		$(if $(SKIP_WARMUP),-DSKIP_WARMUP=$(SKIP_WARMUP)) \
		$(if $(SIM_MOUNTS),-DSIM_MOUNTS=$(SIM_MOUNTS)) \
		$(if $(SIM_ROTATES),-DSIM_ROTATES=$(SIM_ROTATES)) \
		$(if $(SIM_TIME),-DSIM_TIME=$(SIM_TIME)) \
		$(if $(SIM_SIZE),-DSIM_SIZE=$(SIM_SIZE)) \
		-DFS=$(N_$3) \
		-DDISK_GEOMETRY=$(N_$4) \
		$(foreach p, $(subst $(comma),$(space),$(or $5,$(MOUNT_DS_P))),$\
			-Sromount=$(p)) \
		$(foreach p, $(subst $(comma),$(space),$(or $5,$(MOUNT_DS_P))),$\
			-Smount=$(p)) \
		$(foreach p, $(subst $(comma),$(space),$(or $5,$(MOUNT_DS_P))),$\
			-Smountwrite=$(p)) \
		$(foreach p, $(subst $(comma),$(space),$(or $5,$(MOUNT_DS_P))),$\
			$(foreach w, mount mkconsistent open alloc_ write_ sync_,$\
				$(if $(filter avg,$(p)),$\
					$(if $(filter mount,$(w)),,-S$(w)=$(p)),$\
					-S$(w)='$(p)(mountwrite)'))) \
		-Srotates -Sgrms \
		-Sclose -Sunmount \
		-DPOWERLOSS=$(or $6,$(MOUNT_DS_POWERLOSS)) \
		-DDISK_SIZE=$(or $7,$(MOUNT_DS_DISK_SIZES)) \
		-o$$@)
endef

# bench rules
$(foreach c, $(BENCH_CASES),$\
	$(foreach fs, $(BENCH_FILESYSTEMS),$\
		$(foreach g, $(BENCH_GEOMETRIES),$\
			$(eval $(call BENCH_MOUNT_DS_RULE,$\
				$(MOUNT_DS_RESULTSDIR)/bench_mount_ds.$(c).$(fs).$(g).csv,$\
				$(c),$\
				$(fs),$\
				$(g))))))


#======================================================================#
# plot rules                                                           #
#======================================================================#

## Plot benchmarks
.PHONY: all plot plot-mount-ds
all plot: plot-mount-ds
plot-mount-ds: \
		$(MOUNT_DS_PLOTSDIR)/plots.html \
		$(foreach g, $(BENCH_GEOMETRIES), \
			$(MOUNT_DS_PLOTSDIR)/plot_mount_ds_romount.$(g).svg \
			$(MOUNT_DS_PLOTSDIR)/plot_mount_ds_mount.$(g).svg \
			$(MOUNT_DS_PLOTSDIR)/plot_mount_ds_mountwrite.$(g).svg)

## Create a quick html page for easy viewing
$(MOUNT_DS_PLOTSDIR)/plots.html:
	echo -e "$(subst $(nl),\n,$(HTML_HEADER))" >> $@
	$(foreach g, $(BENCH_GEOMETRIES), \
		echo -e "<p><img src="plot_mount_ds_romount.$(g).svg"></p>" $\
			>> $@ $(nl)$\
		echo -e "<p><img src="plot_mount_ds_mount.$(g).svg"></p>" $\
			>> $@ $(nl)$\
		echo -e "<p><img src="plot_mount_ds_mountwrite.$(g).svg"></p>" $\
			>> $@ $(nl))
	echo -e "$(subst $(nl),\n,$(HTML_FOOTER))" >> $@

# core plot rule
#
# $1 - target
# $2 - sources
# $3 - title
# $4 - x-axis
# $5 - x-ticks
# $6 - x-skip
# $7 - extra plotmpl.py flags
# $8 - probe name
#
define PLOT_MOUNT_DS_RULE
$1: $2
	$$(strip ./scripts/plotmpl.py \
		<(./scripts/csv.py $$^ \
			-bcase -bFS -bPOWERLOSS -b$4 -Dprobe=$8 \
			-flatency='float(bench_t)/1.0e9' \
			-o-) \
		-W1500 -H350 \
		--title=$3 \
		-bFS \
		-x$4 \
		-ylatency \
		--subplot=" \
				--title='seq' \
				--ylabel='mount latency (no pl)' \
				-Dcase=bench_mount_seq \
				-DPOWERLOSS=0 \
			--subplot-below=\" \
				--ylabel='mount latency (yes pl)' \
				-Dcase=bench_mount_seq \
				-DPOWERLOSS=1\" \
			--subplot-below=\" \
				--ylabel='mount latency (prog pl)' \
				-Dcase=bench_mount_seq \
				-DPOWERLOSS=2\"" \
		--subplot-right=" \
				--title='random' \
				-Dcase=bench_mount_random \
				-DPOWERLOSS=0 \
			--subplot-below=\" \
				-Dcase=bench_mount_random \
				-DPOWERLOSS=1\" \
			--subplot-below=\" \
				-Dcase=bench_mount_random \
				-DPOWERLOSS=2\"" \
		--subplot-right=" \
				--title='logging' \
				-Dcase=bench_mount_logging \
				-DPOWERLOSS=0 \
			--subplot-below=\" \
				-Dcase=bench_mount_logging \
				-DPOWERLOSS=1\" \
			--subplot-below=\" \
				-Dcase=bench_mount_logging \
				-DPOWERLOSS=2\"" \
		--subplot-right=" \
				--title='many' \
				-Dcase=bench_mount_many \
				-DPOWERLOSS=0 \
			--subplot-below=\" \
				-Dcase=bench_mount_many \
				-DPOWERLOSS=1\" \
			--subplot-below=\" \
				-Dcase=bench_mount_many \
				-DPOWERLOSS=2\"" \
		--legend \
		$(foreach fs, $(BENCH_FILESYSTEMS),$\
			-L'$(N_$(fs))=$(fs)') \
		$(foreach fs, $(BENCH_FILESYSTEMS),$\
			-C'$(N_$(fs))=$(C_$(fs))') \
		$(foreach fs, $(BENCH_FILESYSTEMS),$\
			-F'$(N_$(fs))=$(addsuffix -,$(F_$(fs)))') \
		--xlog --x2 --xunits=B \
		--yunits=s \
		-X"$$(shell python -c 'a=min([$5]); print(a-a/4)'),$\
			$$(shell python -c 'b=max([$5]); print(b+b/4)')" \
		$$(shell python -c '$\
			for n in [$5][::$6]: $\
				print("--add-xticklabel=%d=\"%%(x)IB\"" % n)') \
		$7 \
		$$(PLOTFLAGS) \
		-o$$@)
endef

# plot rules
$(foreach g, $(BENCH_GEOMETRIES), \
	$(eval $(call PLOT_MOUNT_DS_RULE,$\
		$(MOUNT_DS_PLOTSDIR)/plot_mount_ds_%.$(g).svg,$\
		$(foreach c, $(BENCH_CASES),$\
			$(foreach fs, $(BENCH_FILESYSTEMS),$\
				$(MOUNT_DS_RESULTSDIR)/bench_mount_ds.$(c).$(fs).$(g).csv)),$\
		"disk sizes - $(g) - simulated $$* time",$\
		DISK_SIZE,$\
		$(MOUNT_DS_DISK_SIZES),$\
		2,$\
		--xlabel="disk size",$\
		'$$*+$(lastword $(subst $(comma),$(space),$(MOUNT_DS_P)))')))


#======================================================================#
# tikz rules                                                           #
#======================================================================#

## Generate tikz results
.PHONY: all tikz tikz-mount-ds
all tikz tikz-mount-ds: \
        $(foreach c, $(BENCH_CASES), \
            $(foreach fs, $(BENCH_FILESYSTEMS), \
                $(foreach g, $(BENCH_GEOMETRIES), \
                    $(MOUNT_DS_TIKZDIR)/tikz_mount_ds.$(c).$(fs).$(g).csv))) \
        $(foreach c, $(BENCH_CASES), \
            $(foreach fs, $(BENCH_FILESYSTEMS), \
                $(foreach g, $(BENCH_GEOMETRIES), \
                    $(MOUNT_DS_TIKZDIR)/tikz_mount_ds_ops.$(c).$(fs).$(g).csv))) \
        $(foreach c, $(BENCH_CASES), \
            $(foreach fs, $(BENCH_FILESYSTEMS), \
                $(foreach g, $(BENCH_GEOMETRIES), \
                    $(MOUNT_DS_TIKZDIR)/tikz_mount_ds_work.$(c).$(fs).$(g).csv)))

# core tikz rule
#
# $1 - target
# $2 - source
# $3 - x-axis
#
define TIKZ_MOUNT_DS_RULE
$1: $2
	$$(strip ./scripts/csv.py \
		$(foreach op, romount mount mountwrite, \
			$(foreach pl, $(subst $(comma),$(space),$(MOUNT_DS_POWERLOSS)), \
				$(foreach p, $(subst $(comma),$(space),$(MOUNT_DS_P)), \
					<(./scripts/csv.py $$^ \
						-b$3 -DPOWERLOSS=$(pl) \
						-Dprobe=$(op)+$(p) \
						-f$(op)_pl$(pl)_$(subst .,$(nil),$(p))=$\
							'float(bench_t)/1.0e9' \
						-o-)))) \
		-b$3 -F$3 \
		-o$$@)
endef

# tikz rules
$(foreach c, $(BENCH_CASES), \
	$(foreach fs, $(BENCH_FILESYSTEMS), \
		$(foreach g, $(BENCH_GEOMETRIES), \
			$(eval $(call TIKZ_MOUNT_DS_RULE,$\
				$(MOUNT_DS_TIKZDIR)/tikz_mount_ds.$(c).$(fs).$(g).csv,$\
				$(MOUNT_DS_RESULTSDIR)/bench_mount_ds.$(c).$(fs).$(g).csv,$\
				DISK_SIZE)))))

# ops tikz rule
#
# $1 - target
# $2 - source
# $3 - fs type/version
# $4 - disk geometry
# $5 - x-axis
#
define TIKZ_MOUNT_DS_OPS_RULE
$1: $2
	$$(strip ./scripts/csv.py \
		$(foreach op, romount mount mountwrite, \
			$(foreach pl, $(subst $(comma),$(space),$(MOUNT_DS_POWERLOSS)), \
				$(foreach p, $(subst $(comma),$(space),$(MOUNT_DS_P)), \
					<(./scripts/csv.py $$^ \
						-b$5 -DPOWERLOSS=$(pl) \
						-Dprobe='$(op)+$(p)' \
						-f$(op)_pl$(pl)_$(subst .,$(nil),$(p))_reads=$\
							bench_reads \
						-f$(op)_pl$(pl)_$(subst .,$(nil),$(p))_wreads=$\
							bench_wreads \
						-f$(op)_pl$(pl)_$(subst .,$(nil),$(p))_readed=$\
							bench_readed \
						-f$(op)_pl$(pl)_$(subst .,$(nil),$(p))_progs=$\
							bench_progs \
						-f$(op)_pl$(pl)_$(subst .,$(nil),$(p))_wprogs=$\
							bench_wprogs \
						-f$(op)_pl$(pl)_$(subst .,$(nil),$(p))_progged=$\
							bench_progged \
						-f$(op)_pl$(pl)_$(subst .,$(nil),$(p))_erases=$\
							bench_erases \
						-f$(op)_pl$(pl)_$(subst .,$(nil),$(p))_werases=$\
							bench_werases \
						-f$(op)_pl$(pl)_$(subst .,$(nil),$(p))_erased=$\
							bench_erased \
						-f$(op)_pl$(pl)_$(subst .,$(nil),$(p))_readtime="$\
							float($$$$($($(U_$3)_BENCH_RUNNER) \
									-DDISK_GEOMETRY=$(N_$4) \
									-QREAD_TIMING)*bench_reads \
								+ $$$$($($(U_$3)_BENCH_RUNNER) \
									-DDISK_GEOMETRY=$(N_$4) \
									-QREAD_WTIMING)*bench_wreads \
								+ $$$$($($(U_$3)_BENCH_RUNNER) \
									-DDISK_GEOMETRY=$(N_$4) \
									-QREAD_UTIMING)*bench_readed) \
								/ 1.0e9" \
						-f$(op)_pl$(pl)_$(subst .,$(nil),$(p))_progtime="$\
							float($$$$($($(U_$3)_BENCH_RUNNER) \
									-DDISK_GEOMETRY=$(N_$4) \
									-QPROG_TIMING)*bench_progs \
								+ $$$$($($(U_$3)_BENCH_RUNNER) \
									-DDISK_GEOMETRY=$(N_$4) \
									-QPROG_WTIMING)*bench_wprogs \
								+ $$$$($($(U_$3)_BENCH_RUNNER) \
									-DDISK_GEOMETRY=$(N_$4) \
									-QPROG_UTIMING)*bench_progged) \
								/ 1.0e9" \
						-f$(op)_pl$(pl)_$(subst .,$(nil),$(p))_erasetime="$\
							float($$$$($($(U_$3)_BENCH_RUNNER) \
									-DDISK_GEOMETRY=$(N_$4) \
									-QERASE_TIMING)*bench_erases \
								+ $$$$($($(U_$3)_BENCH_RUNNER) \
									-DDISK_GEOMETRY=$(N_$4) \
									-QERASE_WTIMING)*bench_werases \
								+ $$$$($($(U_$3)_BENCH_RUNNER) \
									-DDISK_GEOMETRY=$(N_$4) \
									-QERASE_UTIMING)*bench_erased) \
								/ 1.0e9" \
						-o-)))) \
		-b$5 -F$5 \
		-o$$@)
endef

# ops tikz rules
$(foreach c, $(BENCH_CASES), \
	$(foreach fs, $(BENCH_FILESYSTEMS), \
		$(foreach g, $(BENCH_GEOMETRIES), \
			$(eval $(call TIKZ_MOUNT_DS_OPS_RULE,$\
				$(MOUNT_DS_TIKZDIR)/tikz_mount_ds_ops.$(c).$(fs).$(g).csv,$\
				$(MOUNT_DS_RESULTSDIR)/bench_mount_ds.$(c).$(fs).$(g).csv,$\
				$(fs),$\
				$(g),$\
				DISK_SIZE)))))

# work tikz rule
#
# $1 - target
# $2 - source
# $3 - fs type/version
# $4 - disk geometry
# $5 - x-axis
#
define TIKZ_MOUNT_DS_WORK_RULE
$1: $2
	$$(strip ./scripts/csv.py \
		$(foreach w, mount mkconsistent open alloc_ write_ sync_, \
			$(foreach pl, $(subst $(comma),$(space),$(MOUNT_DS_POWERLOSS)), \
				$(foreach p, $(subst $(comma),$(space),$(MOUNT_DS_P)), \
					<(./scripts/csv.py $$^ \
						-b$5 -DPOWERLOSS=$(pl) \
						-Dprobe='$(w)+$(if $(filter avg,$(p)),$\
							avg,$\
							$(p)(mountwrite))' \
						-fmountwrite$\
								_pl$(pl)$\
								_$(subst .,$(nil),$(p))$\
								_$(subst _,$(nil),$(w))time=$\
							'float(bench_t)/1.0e9' \
						-o-)))) \
		-b$5 -F$5 \
		-o$$@)
endef

# work tikz rules
$(foreach c, $(BENCH_CASES), \
	$(foreach fs, $(BENCH_FILESYSTEMS), \
		$(foreach g, $(BENCH_GEOMETRIES), \
			$(eval $(call TIKZ_MOUNT_DS_WORK_RULE,$\
				$(MOUNT_DS_TIKZDIR)/tikz_mount_ds_work.$(c).$(fs).$(g).csv,$\
				$(MOUNT_DS_RESULTSDIR)/bench_mount_ds.$(c).$(fs).$(g).csv,$\
				$(fs),$\
				$(g),$\
				DISK_SIZE)))))


#======================================================================#
# save rules, for quickly saving things                                #
#======================================================================#

## Save bench results
.PHONY: save save-results save-results-mount-ds
save save-results: save-results-mount-ds
save-results-mount-ds:
	mkdir -p $(SAVEDIR)/$(RESULTSDIR)/
	cp -ru $(MOUNT_DS_RESULTSDIR) $(SAVEDIR)/$(RESULTSDIR)/

## Save bench plots
.PHONY: save save-plots save-plots-mount-ds
save save-plots: save-plots-mount-ds
save-plots-mount-ds:
	mkdir -p $(SAVEDIR)/$(PLOTSDIR)/
	cp -ru $(MOUNT_DS_PLOTSDIR) $(SAVEDIR)/$(PLOTSDIR)/

## Save tikz
.PHONY: save save-tikz save-tikz-mount-ds
save save-tikz: save-tikz-mount-ds
save-tikz-mount-ds:
	mkdir -p $(SAVEDIR)/$(TIKZDIR)/
	cp -ru $(MOUNT_DS_TIKZDIR) $(SAVEDIR)/$(TIKZDIR)/


#======================================================================#
# touch rules, to try to force rebenches without cleaning everything   #
#======================================================================#

## Mark current results as up-to-date to prevent reruns
.PHONY: reuse-results touch-results reuse-results-mount-ds touch-results-mount-ds
reuse-results touch-results: reuse-results-mount-ds touch-results-mount-ds
reuse-results-mount-ds touch-results-mount-ds:
	find $(MOUNT_DS_RESULTSDIR) -name '*.csv' -execdir touch '{}' ';'
	@echo "# note: Make sure you build before plotting!"


#======================================================================#
# cleaning rules, we put everything in build dirs, so this is easy     #
#======================================================================#

## Clean bench results
.PHONY: clean clean-results clean-results-mount-ds
clean clean-results: clean-results-mount-ds
clean-results-mount-ds:
	rm -rf $(MOUNT_DS_RESULTSDIR)
	@echo "# note: Not cleaning saved output"

## Clean bench plots
.PHONY: clean clean-plots clean-plots-mount-ds
clean clean-plots: clean-plots-mount-ds
clean-plots-mount-ds:
	rm -rf $(MOUNT_DS_PLOTSDIR)
	@echo "# note: Not cleaning saved output"

## Clean tikz
.PHONY: clean clean-tikz clean-tikz-mount-ds
clean clean-tikz: clean-tikz-mount-ds
clean-tikz-mount-ds:
	rm -rf $(MOUNT_DS_TIKZDIR)
	@echo "# note: Not cleaning saved output"


endif
