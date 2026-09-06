ifndef BENCH_WT_DS_LGBT_MK
BENCH_WT_DS_LGBT_MK := 1

# prevent parallel benching because of how big disk is
DISK_BIG = 1

# include build rules + filesystems
include Makefiles/build.mk

# overrideable results dir
WT_DS_LGBT_RESULTSDIR ?= $(RESULTSDIR)/wt_ds_lgbt
# overrideable plots dir
WT_DS_LGBT_PLOTSDIR ?= $(PLOTSDIR)/wt_ds_lgbt
# overrideable tikz dir
WT_DS_LGBT_TIKZDIR ?= $(TIKZDIR)/wt_ds_lgbt


# range of disk sizes to test
#
# note this needs to be >>2n, probably ~4n to be safe
WT_DS_LGBT_DISK_SIZES ?= $\
		4194304,$\
		8388608,16777216,33554432,67108864,134217728,268435456,$\
		536870912,1073741824,2147483648,4294967296,8589934592

# range of lookgbmap threshes, these only make sense for littlefs
WT_DS_LGBT_LOOKGBMAP_THRESHES ?= -1,0,1,2,4,8,16,32,64,128,256,512,1024



# we don't need to bench all the filesystems
BENCH_FILESYSTEMS ?= lfs3 lfs3gbp # $(DEFAULT_BENCH_FILESYSTEMS)

# and we're interested in some of the more atypical disk geometries
BENCH_GEOMETRIES ?= nor nand nandftl # $(DEFAULT_BENCH_GEOMETRIES)

# list of interesting bench cases
BENCH_CASES ?= logging # seq random logging many


# this is a bit of a hack, but we want to make sure the BUILDDIR
# directory structure is correct before we run any commands
ifneq ($(WT_DS_LGBT_RESULTSDIR),.)
$(if $(findstring n,$(MAKEFLAGS)),, \
		$(foreach d, \
				$(WT_DS_LGBT_RESULTSDIR) \
				$(WT_DS_LGBT_PLOTSDIR) \
				$(WT_DS_LGBT_TIKZDIR), \
            $(if $(wildcard $d),, $(shell mkdir -p $d))))
endif


#======================================================================#
# bench rules                                                          #
#======================================================================#

## Run benches
.PHONY: all bench bench-wt-ds-lgbt
all bench: bench-wt-ds-lgbt
bench-wt-ds-lgbt: \
		$(foreach c, $(BENCH_CASES), \
			$(foreach fs, $(BENCH_FILESYSTEMS), \
				$(foreach g, $(BENCH_GEOMETRIES), \
					$(WT_DS_LGBT_RESULTSDIR)/$\
						bench_wt_ds_lgbt.$(c).$(fs).$(g).csv)))

# core bench rule
#
# $1 - target
# $2 - bench case
# $3 - fs type/version
# $4 - disk geometry
# $5 - disk sizes
# $6 - lookgbmap threshes (per-1024)
#
define BENCH_WT_DS_LGBT_RULE
$1: $($(U_$3)_BENCH_RUNNER)
	$$(strip ./scripts/bench.py -R$$< -B bench_wt_$2 \
		$(BENCHFLAGS) $($(U_$3)_BENCHFLAGS) \
		$(if $(SKIP_WARMUP),-DSKIP_WARMUP=$(SKIP_WARMUP)) \
		$(if $(SIM_TIME),-DSIM_TIME=$(SIM_TIME)) \
		$(if $(SIM_SIZE),-DSIM_SIZE=$(SIM_SIZE)) \
		-DFS=$(N_$3) \
		-DDISK_GEOMETRY=$(N_$4) \
		-DDISK_SIZE=$(or $5,$(WT_DS_LGBT_DISK_SIZES)) \
		$(if $(filter $3,$\
				$(DEFAULT_LFS3GB_FILESYSTEMS)),$\
			-DLOOKGBMAP_THRESH=$(or $6,$(WT_DS_LGBT_LOOKGBMAP_THRESHES))) \
		-o$$@)
endef

# bench rules
$(foreach c, $(BENCH_CASES),$\
	$(foreach fs, $(BENCH_FILESYSTEMS),$\
		$(foreach g, $(BENCH_GEOMETRIES),$\
			$(eval $(call BENCH_WT_DS_LGBT_RULE,$\
				$(WT_DS_LGBT_RESULTSDIR)/bench_wt_ds_lgbt.$(c).$(fs).$(g).csv,$\
				$(c),$\
				$(fs),$\
				$(g))))))


#======================================================================#
# plot rules                                                           #
#======================================================================#

## Plot benchmarks
.PHONY: all plot plot-wt-ds-lgbt
all plot: plot-wt-ds-lgbt
plot-wt-ds-lgbt: \
		$(WT_DS_LGBT_PLOTSDIR)/plots.html \
		$(foreach g, $(BENCH_GEOMETRIES), \
			$(WT_DS_LGBT_PLOTSDIR)/plot_wt_ds_lgbt.$(g).svg)

## Create a quick html page for easy viewing
$(WT_DS_LGBT_PLOTSDIR)/plots.html:
	echo -e "$(subst $(nl),\n,$(HTML_HEADER))" >> $@
	$(foreach g, $(BENCH_GEOMETRIES), \
		echo -e "<p><img src="plot_wt_ds_lgbt.$(g).svg"></p>" >> $@ $(nl))
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
define PLOT_WT_DS_LGBT_RULE
$1: $2
	$$(strip ./scripts/plotmpl.py \
		<(./scripts/csv.py $$^ \
			-bcase -bFS -bLOOKGBMAP_THRESH -b$4 -Dprobe=write \
			-fthroughput='float(bench_n)/max(float(bench_t)/1.0e9,1.0e-9)' \
			-o-) \
		<(./scripts/csv.py $$^ \
			-bcase -bFS -bLOOKGBMAP_THRESH -b$4 -Dprobe=heap,stack \
			-fram=bench_t \
			-o-) \
		-W1500 -H350 \
		--title=$3 \
		-bFS \
		-bLOOKGBMAP_THRESH \
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
			-L'$(N_$(fs))=$(fs),%(LOOKGBMAP_THRESH)s') \
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
	$(eval $(call PLOT_WT_DS_LGBT_RULE,$\
		$(WT_DS_LGBT_PLOTSDIR)/plot_wt_ds_lgbt.$(g).svg,$\
		$(foreach c, $(BENCH_CASES),$\
			$(foreach fs, $(BENCH_FILESYSTEMS),$\
				$(WT_DS_LGBT_RESULTSDIR)/bench_wt_ds_lgbt.$(c).$(fs).$(g).csv)),$\
		"disk sizes - $(g) - simulated throughput",$\
		DISK_SIZE,$\
		$(WT_DS_LGBT_DISK_SIZES),$\
		2,$\
		--xlabel="disk size")))


#======================================================================#
# tikz rules                                                           #
#======================================================================#

## Generate tikz results
.PHONY: all tikz tikz-wt-ds-lgbt
all tikz tikz-wt-ds-lgbt: \
		$(foreach c, $(BENCH_CASES), \
			$(foreach fs, $(BENCH_FILESYSTEMS), \
				$(foreach g, $(BENCH_GEOMETRIES), \
					$(WT_DS_LGBT_TIKZDIR)/tikz_wt_ds_lgbt.$(c).$(fs).$(g).csv)))

# core tikz rule
#
# $1 - target
# $2 - source
# $3 - x-axis
# $4 - lookgbmap threshes (per-1024)
#
define TIKZ_WT_DS_LGBT_RULE
$1: $2
	$$(strip ./scripts/csv.py \
		$(foreach l, $(subst $(comma),$(space),$4), \
			<(./scripts/csv.py $$^ \
				-b$3 -DLOOKGBMAP_THRESH='$(l),' \
				-Dprobe=write \
				-fthroughput_l$(subst -1,no,$(l))=$\
					'float(bench_n)/max(float(bench_t)/1.0e9,1.0e-9)' \
				-o-) \
			<(./scripts/csv.py $$^ \
				-b$3 -DLOOKGBMAP_THRESH='$(l),' \
				-Dprobe=heap,stack \
				-fram_l$(subst -1,no,$(l))=bench_t \
				-o-)) \
		-b$3 -F$3 \
		-o$$@)
endef

# tikz rules
$(foreach c, $(BENCH_CASES), \
	$(foreach fs, $(BENCH_FILESYSTEMS), \
		$(foreach g, $(BENCH_GEOMETRIES), \
			$(eval $(call TIKZ_WT_DS_LGBT_RULE,$\
				$(WT_DS_LGBT_TIKZDIR)/tikz_wt_ds_lgbt.$(c).$(fs).$(g).csv,$\
				$(WT_DS_LGBT_RESULTSDIR)/bench_wt_ds_lgbt.$(c).$(fs).$(g).csv,$\
				DISK_SIZE,$\
				$(WT_DS_LGBT_LOOKGBMAP_THRESHES))))))


#======================================================================#
# save rules, for quickly saving things                                #
#======================================================================#

## Save bench results
.PHONY: save save-results save-results-wt-ds-lgbt
save save-results: save-results-wt-ds-lgbt
save-results-wt-ds-lgbt:
	mkdir -p $(SAVEDIR)/$(RESULTSDIR)/
	cp -ru $(WT_DS_LGBT_RESULTSDIR) $(SAVEDIR)/$(RESULTSDIR)/

## Save bench plots
.PHONY: save save-plots save-plots-wt-ds-lgbt
save save-plots: save-plots-wt-ds-lgbt
save-plots-wt-ds-lgbt:
	mkdir -p $(SAVEDIR)/$(PLOTSDIR)/
	cp -ru $(WT_DS_LGBT_PLOTSDIR) $(SAVEDIR)/$(PLOTSDIR)/

## Save tikz
.PHONY: save save-tikz save-tikz-wt-ds-lgbt
save save-tikz: save-tikz-wt-ds-lgbt
save-tikz-wt-ds-lgbt:
	mkdir -p $(SAVEDIR)/$(TIKZDIR)/
	cp -ru $(WT_DS_LGBT_TIKZDIR) $(SAVEDIR)/$(TIKZDIR)/


#======================================================================#
# touch rules, to try to force rebenches without cleaning everything   #
#======================================================================#

## Mark current results as up-to-date to prevent reruns
.PHONY: reuse-results touch-results reuse-results-wt-ds-lgbt touch-results-wt-ds-lgbt
reuse-results touch-results: reuse-results-wt-ds-lgbt touch-results-wt-ds-lgbt
reuse-results-wt-ds-lgbt touch-results-wt-ds-lgbt:
	find $(WT_DS_LGBT_RESULTSDIR) -name '*.csv' -execdir touch '{}' ';'
	@echo "# note: Make sure you build before plotting!"


#======================================================================#
# cleaning rules, we put everything in build dirs, so this is easy     #
#======================================================================#

## Clean bench results
.PHONY: clean clean-results clean-results-wt-ds-lgbt
clean clean-results: clean-results-wt-ds-lgbt
clean-results-wt-ds-lgbt:
	rm -rf $(WT_DS_LGBT_RESULTSDIR)
	@echo "# note: Not cleaning saved output"

## Clean bench plots
.PHONY: clean clean-plots clean-plots-wt-ds-lgbt
clean clean-plots: clean-plots-wt-ds-lgbt
clean-plots-wt-ds-lgbt:
	rm -rf $(WT_DS_LGBT_PLOTSDIR)
	@echo "# note: Not cleaning saved output"

## Clean tikz
.PHONY: clean clean-tikz clean-tikz-wt-ds-lgbt
clean clean-tikz: clean-tikz-wt-ds-lgbt
clean-tikz-wt-ds-lgbt:
	rm -rf $(WT_DS_LGBT_TIKZDIR)
	@echo "# note: Not cleaning saved output"


endif
