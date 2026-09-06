ifndef BENCH_WT_DS_MK
BENCH_WT_DS_MK := 1

# prevent parallel benching because of how big disk is
DISK_BIG = 1

# include build rules + filesystems
include Makefiles/build.mk

# overrideable results dir
WT_DS_RESULTSDIR ?= $(RESULTSDIR)/wt_ds
# overrideable plots dir
WT_DS_PLOTSDIR ?= $(PLOTSDIR)/wt_ds
# overrideable tikz dir
WT_DS_TIKZDIR ?= $(TIKZDIR)/wt_ds


# range of disk sizes to test
#
# note this needs to be >>2n, probably ~4n to be safe
WT_DS_DISK_SIZES ?= $\
		4194304,$\
		8388608,16777216,33554432,67108864,134217728,268435456,$\
		536870912,1073741824,2147483648,4294967296,8589934592


# default bench filesystems to default bench filesystems
BENCH_FILESYSTEMS ?= $(DEFAULT_BENCH_FILESYSTEMS)

# default disk geometries to default disk geometries
BENCH_GEOMETRIES ?= $(DEFAULT_BENCH_GEOMETRIES)

# list of interesting bench cases
BENCH_CASES ?= seq random logging many


# this is a bit of a hack, but we want to make sure the BUILDDIR
# directory structure is correct before we run any commands
ifneq ($(WT_DS_RESULTSDIR),.)
$(if $(findstring n,$(MAKEFLAGS)),, \
		$(foreach d, \
				$(WT_DS_RESULTSDIR) \
				$(WT_DS_PLOTSDIR) \
				$(WT_DS_TIKZDIR), \
            $(if $(wildcard $d),, $(shell mkdir -p $d))))
endif


#======================================================================#
# bench rules                                                          #
#======================================================================#

## Run benches
.PHONY: all bench bench-wt-ds
all bench: bench-wt-ds
bench-wt-ds: \
		$(foreach c, $(BENCH_CASES), \
			$(foreach fs, $(BENCH_FILESYSTEMS), \
				$(foreach g, $(BENCH_GEOMETRIES), \
					$(WT_DS_RESULTSDIR)/bench_wt_ds.$(c).$(fs).$(g).csv)))

# core bench rule
#
# $1 - target
# $2 - bench case
# $3 - fs type/version
# $4 - disk geometry
# $5 - disk sizes
#
define BENCH_WT_DS_RULE
$1: $($(U_$3)_BENCH_RUNNER)
	$$(strip ./scripts/bench.py -R$$< -B bench_wt_$2 \
		$(BENCHFLAGS) $($(U_$3)_BENCHFLAGS) \
		$(if $(SKIP_WARMUP),-DSKIP_WARMUP=$(SKIP_WARMUP)) \
		$(if $(SIM_TIME),-DSIM_TIME=$(SIM_TIME)) \
		$(if $(SIM_SIZE),-DSIM_SIZE=$(SIM_SIZE)) \
		-DFS=$(N_$3) \
		-DDISK_GEOMETRY=$(N_$4) \
		-DDISK_SIZE=$(or $5,$(WT_DS_DISK_SIZES)) \
		-o$$@)
endef

# bench rules
$(foreach c, $(BENCH_CASES),$\
	$(foreach fs, $(BENCH_FILESYSTEMS),$\
		$(foreach g, $(BENCH_GEOMETRIES),$\
			$(eval $(call BENCH_WT_DS_RULE,$\
				$(WT_DS_RESULTSDIR)/bench_wt_ds.$(c).$(fs).$(g).csv,$\
				$(c),$\
				$(fs),$\
				$(g))))))


#======================================================================#
# plot rules                                                           #
#======================================================================#

## Plot benchmarks
.PHONY: all plot plot-wt-ds
all plot: plot-wt-ds
plot-wt-ds: \
		$(WT_DS_PLOTSDIR)/plots.html \
		$(foreach g, $(BENCH_GEOMETRIES), \
			$(WT_DS_PLOTSDIR)/plot_wt_ds.$(g).svg)

## Create a quick html page for easy viewing
$(WT_DS_PLOTSDIR)/plots.html:
	echo -e "$(subst $(nl),\n,$(HTML_HEADER))" >> $@
	$(foreach g, $(BENCH_GEOMETRIES), \
		echo -e "<p><img src="plot_wt_ds.$(g).svg"></p>" >> $@ $(nl))
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
#
define PLOT_WT_DS_RULE
$1: $2
	$$(strip ./scripts/plotmpl.py \
		<(./scripts/csv.py $$^ \
			-bcase -bFS -b$4 -Dprobe=write \
			-fthroughput='float(bench_n)/max(float(bench_t)/1.0e9,1.0e-9)' \
			-o-) \
		<(./scripts/csv.py $$^ \
			-bcase -bFS -b$4 -Dprobe=heap,stack \
			-fram=bench_t \
			-o-) \
		-W1500 -H350 \
		--title=$3 \
		-bFS \
		-x$4 \
		--subplot=" \
				--title='seq' \
				--ylabel='throughput' \
				-Dcase=bench_wt_seq \
				-ythroughput --y2 --yunits=B/s \
			--subplot-below=\" \
				--ylabel='ram' \
				-Dcase=bench_wt_seq \
				-yram --y2 --yunits=B\"" \
		--subplot-right=" \
				--title='random' \
				-Dcase=bench_wt_random \
				-ythroughput --y2 --yunits=B/s \
			--subplot-below=\" \
				-Dcase=bench_wt_random \
				-yram --y2 --yunits=B\"" \
		--subplot-right=" \
				--title='logging' \
				-Dcase=bench_wt_logging \
				-ythroughput --y2 --yunits=B/s \
			--subplot-below=\" \
				-Dcase=bench_wt_logging \
				-yram --y2 --yunits=B\"" \
		--subplot-right=" \
				--title='many' \
				-Dcase=bench_wt_many \
				-ythroughput --y2 --yunits=B/s \
			--subplot-below=\" \
				-Dcase=bench_wt_many \
				-yram --y2 --yunits=B\"" \
		--legend \
		$(foreach fs, $(BENCH_FILESYSTEMS),$\
			-L'$(N_$(fs))=$(fs)') \
		$(foreach fs, $(BENCH_FILESYSTEMS),$\
			-C'$(N_$(fs))=$(C_$(fs))') \
		$(foreach fs, $(BENCH_FILESYSTEMS),$\
			-F'$(N_$(fs))=$(addsuffix -,$(F_$(fs)))') \
		--xlog \
		-X"$$(shell python -c 'a=min([$5]); print(a-a/4)'),$\
			$$(shell python -c 'b=max([$5]); print(b+b/4)')" \
		--x2 --xunits=B \
		$$(shell python -c '$\
			for n in [$5][::$6]: $\
				print("--add-xticklabel=%d=\"%%(x)IB\"" % n)') \
		$7 \
		$$(PLOTFLAGS) \
		-o$$@)
endef

# plot rules
$(foreach g, $(BENCH_GEOMETRIES), \
	$(eval $(call PLOT_WT_DS_RULE,$\
		$(WT_DS_PLOTSDIR)/plot_wt_ds.$(g).svg,$\
		$(foreach c, $(BENCH_CASES),$\
			$(foreach fs, $(BENCH_FILESYSTEMS),$\
				$(WT_DS_RESULTSDIR)/bench_wt_ds.$(c).$(fs).$(g).csv)),$\
		"disk sizes - $(g) - simulated throughput",$\
		DISK_SIZE,$\
		$(WT_DS_DISK_SIZES),$\
		2,$\
		--xlabel="disk size")))


#======================================================================#
# tikz rules                                                           #
#======================================================================#

## Generate tikz results
.PHONY: all tikz tikz-wt-ds
all tikz tikz-wt-ds: \
		$(foreach c, $(BENCH_CASES), \
			$(foreach fs, $(BENCH_FILESYSTEMS), \
				$(foreach g, $(BENCH_GEOMETRIES), \
					$(WT_DS_TIKZDIR)/tikz_wt_ds.$(c).$(fs).$(g).csv)))

# core tikz rule
#
# $1 - target
# $2 - source
# $3 - x-axis
#
define TIKZ_WT_DS_RULE
$1: $2
	$$(strip ./scripts/csv.py \
		<(./scripts/csv.py $$^ \
			-b$3 -Dprobe=write \
			-fthroughput='float(bench_n)/max(float(bench_t)/1.0e9,1.0e-9)' \
			-o-) \
		<(./scripts/csv.py $$^ \
			-b$3 -Dprobe=heap,stack \
			-fram=bench_t \
			-o-) \
		-Si=$3 -b$3 \
		-fthroughput -fram \
		-o$$@)
endef

# tikz rules
$(foreach c, $(BENCH_CASES), \
	$(foreach fs, $(BENCH_FILESYSTEMS), \
		$(foreach g, $(BENCH_GEOMETRIES), \
			$(eval $(call TIKZ_WT_DS_RULE,$\
				$(WT_DS_TIKZDIR)/tikz_wt_ds.$(c).$(fs).$(g).csv,$\
				$(WT_DS_RESULTSDIR)/bench_wt_ds.$(c).$(fs).$(g).csv,$\
				DISK_SIZE)))))


#======================================================================#
# save rules, for quickly saving things                                #
#======================================================================#

## Save bench results
.PHONY: save save-results save-results-wt-ds
save save-results: save-results-wt-ds
save-results-wt-ds:
	mkdir -p $(SAVEDIR)/$(RESULTSDIR)/
	cp -ru $(WT_DS_RESULTSDIR) $(SAVEDIR)/$(RESULTSDIR)/

## Save bench plots
.PHONY: save save-plots save-plots-wt-ds
save save-plots: save-plots-wt-ds
save-plots-wt-ds:
	mkdir -p $(SAVEDIR)/$(PLOTSDIR)/
	cp -ru $(WT_DS_PLOTSDIR) $(SAVEDIR)/$(PLOTSDIR)/

## Save tikz
.PHONY: save save-tikz save-tikz-wt-ds
save save-tikz: save-tikz-wt-ds
save-tikz-wt-ds:
	mkdir -p $(SAVEDIR)/$(TIKZDIR)/
	cp -ru $(WT_DS_TIKZDIR) $(SAVEDIR)/$(TIKZDIR)/


#======================================================================#
# touch rules, to try to force rebenches without cleaning everything   #
#======================================================================#

## Mark current results as up-to-date to prevent reruns
.PHONY: reuse-results touch-results reuse-results-wt-ds touch-results-wt-ds
reuse-results touch-results: reuse-results-wt-ds touch-results-wt-ds
reuse-results-wt-ds touch-results-wt-ds:
	find $(WT_DS_RESULTSDIR) -name '*.csv' -execdir touch '{}' ';'
	@echo "# note: Make sure you build before plotting!"


#======================================================================#
# cleaning rules, we put everything in build dirs, so this is easy     #
#======================================================================#

## Clean bench results
.PHONY: clean clean-results clean-results-wt-ds
clean clean-results: clean-results-wt-ds
clean-results-wt-ds:
	rm -rf $(WT_DS_RESULTSDIR)
	@echo "# note: Not cleaning saved output"

## Clean bench plots
.PHONY: clean clean-plots clean-plots-wt-ds
clean clean-plots: clean-plots-wt-ds
clean-plots-wt-ds:
	rm -rf $(WT_DS_PLOTSDIR)
	@echo "# note: Not cleaning saved output"

## Clean tikz
.PHONY: clean clean-tikz clean-tikz-wt-ds
clean clean-tikz: clean-tikz-wt-ds
clean-tikz-wt-ds:
	rm -rf $(WT_DS_TIKZDIR)
	@echo "# note: Not cleaning saved output"


endif
