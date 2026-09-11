ifndef BENCH_WEAR_I_MK
BENCH_WEAR_I_MK := 1

# include build rules + filesystems
include Makefiles/build.mk

# overrideable results dir
WEAR_I_RESULTSDIR ?= $(RESULTSDIR)/wear_i
# overrideable plots dir
WEAR_I_PLOTSDIR ?= $(PLOTSDIR)/wear_i
# overrideable tikz dir
WEAR_I_TIKZDIR ?= $(TIKZDIR)/wear_i


# block recycles to bench? these only make sense for littlefs
WEAR_I_BLOCK_RECYCLES ?= 0,1,10,100,1000

# range of sim sizes to bench
# 
# note the disk size is 8MiB by default
WEAR_I_SIM_SIZES ?= $\
	8388608,16777216,33554432,67108864,$\
	134217728,268435456,536870912,$\
	1073741824,2147483648,4294967296,8589934592,$\
	17179869184


# default bench filesystems to default bench filesystems
BENCH_FILESYSTEMS ?= $(DEFAULT_BENCH_FILESYSTEMS)

# default disk geometries to default disk geometries
BENCH_GEOMETRIES ?= $(DEFAULT_BENCH_GEOMETRIES)

# list of interesting bench cases
BENCH_CASES ?= logging # seq random logging many


# this is a bit of a hack, but we want to make sure the BUILDDIR
# directory structure is correct before we run any commands
ifneq ($(WEAR_I_RESULTSDIR),.)
$(if $(findstring n,$(MAKEFLAGS)),, \
		$(foreach d, \
				$(WEAR_I_RESULTSDIR) \
				$(WEAR_I_PLOTSDIR) \
				$(WEAR_I_TIKZDIR), \
            $(if $(wildcard $d),, $(shell mkdir -p $d))))
endif


#======================================================================#
# bench rules                                                          #
#======================================================================#

## Run benches
.PHONY: all bench bench-wear-i
all bench: bench-wear-i
bench-wear-i: \
		$(foreach c, $(BENCH_CASES), \
			$(foreach fs, $(BENCH_FILESYSTEMS), \
				$(foreach g, $(BENCH_GEOMETRIES), \
					$(WEAR_I_RESULTSDIR)/bench_wear_i.$(c).$(fs).$(g).csv)))

# core bench rule
#
# $1 - target
# $2 - bench case
# $3 - fs type/version
# $4 - disk geometry
# $5 - block recycles
# $6 - sim sizes
#
define BENCH_WEAR_I_RULE
$1: $($(U_$3)_BENCH_RUNNER)
	$$(strip ./scripts/bench.py -R$$< -B bench_wear_$2 \
		$(BENCHFLAGS) $($(U_$3)_BENCHFLAGS) \
		$(if $(SKIP_WARMUP),-DSKIP_WARMUP=$(SKIP_WARMUP)) \
		$(if $(SIM_TIME),-DSIM_TIME=$(SIM_TIME)) \
		$(if,    $(if $(SIM_SIZE),-DSIM_SIZE=$(SIM_SIZE))    ) \
		-DFS=$(N_$3) \
		-DDISK_GEOMETRY=$(N_$4) \
		-Swear=max -Swear=stddev -Swaf \
		$(if $(filter $3,$\
				$(DEFAULT_LFS3_FILESYSTEMS) $\
				$(DEFAULT_LFS2_FILESYSTEMS)),$\
			-DBLOCK_RECYCLES=$(or $5,$(WEAR_I_BLOCK_RECYCLES))) \
		-DSIM_SIZE=$(or $6,$(WEAR_I_SIM_SIZES)) \
		-o$$@)
endef

# bench rules
$(foreach c, $(BENCH_CASES),$\
	$(foreach fs, $(BENCH_FILESYSTEMS),$\
		$(foreach g, $(BENCH_GEOMETRIES),$\
			$(eval $(call BENCH_WEAR_I_RULE,$\
				$(WEAR_I_RESULTSDIR)/bench_wear_i.$(c).$(fs).$(g).csv,$\
				$(c),$\
				$(fs),$\
				$(g))))))


#======================================================================#
# plot rules                                                           #
#======================================================================#

## Plot benchmarks
.PHONY: all plot plot-wear-i
all plot: plot-wear-i
plot-wear-i: \
		$(WEAR_I_PLOTSDIR)/plots.html \
		$(foreach g, $(BENCH_GEOMETRIES), \
			$(WEAR_I_PLOTSDIR)/plot_wear_i.$(g).svg)

## Create a quick html page for easy viewing
$(WEAR_I_PLOTSDIR)/plots.html:
	echo -e "$(subst $(nl),\n,$(HTML_HEADER))" >> $@
	$(foreach g, $(BENCH_GEOMETRIES), \
		echo -e "<p><img src="plot_wear_i.$(g).svg"></p>" >> $@ $(nl))
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
define PLOT_WEAR_I_RULE
$1: $2
	$$(strip ./scripts/plotmpl.py \
		<(./scripts/csv.py $$^ \
			-bcase -bFS -bBLOCK_RECYCLES -b$4 \
			-Dprobe=wear+max -fwmax=bench_t \
			-o-) \
		<(./scripts/csv.py $$^ \
			-bcase -bFS -bBLOCK_RECYCLES -b$4 \
			-Dprobe=wear+stddev -fwstddev=bench_t \
			-o-) \
		<(./scripts/csv.py $$^ \
			-bcase -bFS -bBLOCK_RECYCLES -b$4 \
			-Dprobe=waf -fwaf=bench_t \
			-o-) \
		-W1500 -H350 \
		--title=$3 \
		-bFS \
		-bBLOCK_RECYCLES \
		-x$4 \
		--subplot=" \
				--title='seq' \
				--ylabel='max' \
				-Dcase=bench_wear_seq \
				-ywmax \
			--subplot-below=\" \
				--ylabel='stddev' \
				-Dcase=bench_wear_seq \
				-ywstddev\" \
			--subplot-below=\" \
				--ylabel='waf' \
				-Dcase=bench_wear_seq \
				-ywaf\"" \
		--subplot-right=" \
				--title='random' \
				-Dcase=bench_wear_random \
				-ywmax \
			--subplot-below=\" \
				-Dcase=bench_wear_random \
				-ywstddev\" \
			--subplot-below=\" \
				-Dcase=bench_wear_random \
				-ywaf\"" \
		--subplot-right=" \
				--title='logging' \
				-Dcase=bench_wear_logging \
				-ywmax \
			--subplot-below=\" \
				-Dcase=bench_wear_logging \
				-ywstddev\" \
			--subplot-below=\" \
				-Dcase=bench_wear_logging \
				-ywaf\"" \
		--subplot-right=" \
				--title='many' \
				-Dcase=bench_wear_many \
				-ywmax \
			--subplot-below=\" \
				-Dcase=bench_wear_many \
				-ywstddev\" \
			--subplot-below=\" \
				-Dcase=bench_wear_many \
				-ywaf\"" \
		--legend \
		$(foreach fs, $(BENCH_FILESYSTEMS),$\
			-L'$(N_$(fs))=$(fs),%(BLOCK_RECYCLES)s') \
		$(foreach fs, $(BENCH_FILESYSTEMS),$\
			-C'$(N_$(fs))=$(C_$(fs))') \
		$(foreach fs, $(BENCH_FILESYSTEMS),$\
			-F'$(N_$(fs))=$(addsuffix -,$(F_$(fs)))') \
		--xlog --x2 --xunits=B \
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
	$(eval $(call PLOT_WEAR_I_RULE,$\
		$(WEAR_I_PLOTSDIR)/plot_wear_i.$(g).svg,$\
		$(foreach c, $(BENCH_CASES),$\
			$(foreach fs, $(BENCH_FILESYSTEMS),$\
				$(WEAR_I_RESULTSDIR)/bench_wear_i.$(c).$(fs).$(g).csv)),$\
		"sim sizes - $(g) - simulated wear",$\
		SIM_SIZE,$\
		$(WEAR_I_SIM_SIZES),$\
		2,$\
		--xlabel="sim size")))


#======================================================================#
# tikz rules                                                           #
#======================================================================#

## Generate tikz results
.PHONY: all tikz tikz-wear-i
all tikz tikz-wear-i: \
        $(foreach c, $(BENCH_CASES), \
            $(foreach fs, $(BENCH_FILESYSTEMS), \
                $(foreach g, $(BENCH_GEOMETRIES), \
                    $(WEAR_I_TIKZDIR)/tikz_wear_i.$(c).$(fs).$(g).csv)))

# core tikz rule
#
# $1 - target
# $2 - source
# $3 - block recycles
# $4 - x-axis
#
define TIKZ_WEAR_I_RULE
$1: $2
	$$(strip ./scripts/csv.py \
		$(foreach r, $(subst $(comma),$(space),$3), \
			<(./scripts/csv.py $$^ \
				-b$4 -DBLOCK_RECYCLES='$(r),' \
				-Dprobe=wear+max -fwmax_r$(r)=bench_t \
				-o-) \
			<(./scripts/csv.py $$^ \
				-b$4 -DBLOCK_RECYCLES='$(r),' \
				-Dprobe=wear+stddev -fwstddev_r$(r)=bench_t \
				-o-) \
			<(./scripts/csv.py $$^ \
				-b$4 -DBLOCK_RECYCLES='$(r),' \
				-Dprobe=waf -fwaf_r$(r)=bench_t \
				-o-)) \
		-b$4 -F$4 \
		-o$$@)
endef

# tikz rules
$(foreach c, $(BENCH_CASES), \
	$(foreach fs, $(BENCH_FILESYSTEMS), \
		$(foreach g, $(BENCH_GEOMETRIES), \
			$(eval $(call TIKZ_WEAR_I_RULE,$\
				$(WEAR_I_TIKZDIR)/tikz_wear_i.$(c).$(fs).$(g).csv,$\
				$(WEAR_I_RESULTSDIR)/bench_wear_i.$(c).$(fs).$(g).csv,$\
				$(WEAR_I_BLOCK_RECYCLES),$\
				SIM_SIZE)))))


#======================================================================#
# save rules, for quickly saving things                                #
#======================================================================#

## Save bench results
.PHONY: save save-results save-results-wear-i
save save-results: save-results-wear-i
save-results-wear-i:
	mkdir -p $(SAVEDIR)/$(RESULTSDIR)/
	cp -ru $(WEAR_I_RESULTSDIR) $(SAVEDIR)/$(RESULTSDIR)/

## Save bench plots
.PHONY: save save-plots save-plots-wear-i
save save-plots: save-plots-wear-i
save-plots-wear-i:
	mkdir -p $(SAVEDIR)/$(PLOTSDIR)/
	cp -ru $(WEAR_I_PLOTSDIR) $(SAVEDIR)/$(PLOTSDIR)/

## Save tikz
.PHONY: save save-tikz save-tikz-wear-i
save save-tikz: save-tikz-wear-i
save-tikz-wear-i:
	mkdir -p $(SAVEDIR)/$(TIKZDIR)/
	cp -ru $(WEAR_I_TIKZDIR) $(SAVEDIR)/$(TIKZDIR)/


#======================================================================#
# touch rules, to try to force rebenches without cleaning everything   #
#======================================================================#

## Mark current results as up-to-date to prevent reruns
.PHONY: reuse-results touch-results reuse-results-wear-i touch-results-wear-i
reuse-results touch-results: reuse-results-wear-i touch-results-wear-i
reuse-results-wear-i touch-results-wear-i:
	find $(WEAR_I_RESULTSDIR) -name '*.csv' -execdir touch '{}' ';'
	@echo "# note: Make sure you build before plotting!"


#======================================================================#
# cleaning rules, we put everything in build dirs, so this is easy     #
#======================================================================#

## Clean bench results
.PHONY: clean clean-results clean-results-wear-i
clean clean-results: clean-results-wear-i
clean-results-wear-i:
	rm -rf $(WEAR_I_RESULTSDIR)
	@echo "# note: Not cleaning saved output"

## Clean bench plots
.PHONY: clean clean-plots clean-plots-wear-i
clean clean-plots: clean-plots-wear-i
clean-plots-wear-i:
	rm -rf $(WEAR_I_PLOTSDIR)
	@echo "# note: Not cleaning saved output"

## Clean tikz
.PHONY: clean clean-tikz clean-tikz-wear-i
clean clean-tikz: clean-tikz-wear-i
clean-tikz-wear-i:
	rm -rf $(WEAR_I_TIKZDIR)
	@echo "# note: Not cleaning saved output"


endif
