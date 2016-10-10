LATEXSOURCES = \
	perfbook.tex \
	legal.tex \
	glossary.tex \
	qqz.sty origpub.sty \
	book.cls \
	*/*.tex \
	*/*/*.tex

LATEXGENERATED = qqz.tex contrib.tex origpub.tex

PDFTARGETS := perfbook.pdf perfbook-1c.pdf perfbook-hb.pdf

EPSSOURCES_FROM_TEX := \
	SMPdesign/DiningPhilosopher5.eps \
	SMPdesign/DiningPhilosopher5TB.eps \
	SMPdesign/DiningPhilosopher4part-b.eps \
	SMPdesign/DiningPhilosopher5PEM.eps

DOTSOURCES := $(wildcard */*.dot)

EPSSOURCES_FROM_DOT := $(DOTSOURCES:%.dot=%.eps)

FIGSOURCES := $(wildcard */*.fig) $(wildcard */*/*.fig)

EPSSOURCES_FROM_FIG := $(FIGSOURCES:%.fig=%.eps)

EPSSOURCES_DUP := \
	$(wildcard */*.eps) \
	$(wildcard */*/*.eps) \
	$(EPSSOURCES_FROM_TEX) \
	$(EPSSOURCES_FROM_DOT) \
	$(EPSSOURCES_FROM_FIG)

EPSSOURCES := $(sort $(EPSSOURCES_DUP))

PDFTARGETS_OF_EPS := $(EPSSOURCES:%.eps=%.pdf)

BIBSOURCES = bib/*.bib

SVGSOURCES := $(wildcard */*.svg)

PDFTARGETS_OF_SVG := $(SVGSOURCES:%.svg=%.pdf)

DOT := $(shell which dot 2>/dev/null)

FIG2EPS := $(shell which fig2eps 2>/dev/null)

A2PING := $(shell which a2ping 2>/dev/null)

INKSCAPE := $(shell which inkscape 2>/dev/null)

default = $(PERFBOOK_DEFAULT)

ifeq ($(default),)
	targ = perfbook.pdf
else
	targ = $(default)
endif

.PHONY: all touchsvg clean distclean neatfreak 1c 2c hb ls-unused
all: $(targ)

1c: perfbook-1c.pdf

2c: perfbook.pdf

hb: perfbook-hb.pdf

$(PDFTARGETS): %.pdf: %.tex %.bbl
	sh utilities/runlatex.sh $(basename $@)

$(PDFTARGETS:.pdf=.bbl): %.bbl: $(BIBSOURCES) %.aux
	bibtex $(basename $@)

$(PDFTARGETS:.pdf=.aux): $(LATEXSOURCES) $(LATEXGENERATED)
	sh utilities/runfirstlatex.sh $(basename $@)

perfbook_flat.tex: perfbook.tex $(LATEXSOURCES) $(PDFTARGETS_OF_EPS) $(PDFTARGETS_OF_SVG)
	echo > qqz.tex
	echo > contrib.tex
	echo > origpub.tex
	texexpand perfbook.tex > perfbook_flat.tex

qqz.tex: perfbook_flat.tex
	sh utilities/extractqqz.sh < perfbook_flat.tex > qqz.tex

contrib.tex: perfbook_flat.tex qqz.tex
	cat perfbook_flat.tex qqz.tex | sh utilities/extractcontrib.sh > contrib.tex

origpub.tex: perfbook_flat.tex
	sh utilities/extractorigpub.sh < perfbook_flat.tex > origpub.tex

perfbook-1c.tex: perfbook.tex
	sed -e 's/,twocolumn//' -e 's/setboolean{twocolumn}{true}/setboolean{twocolumn}{false}/' < perfbook.tex > perfbook-1c.tex

perfbook-hb.tex: perfbook.tex
	sed -e 's/,twocolumn/&,letterpaperhb/' -e 's/setboolean{hardcover}{false}/setboolean{hardcover}{true}/' < perfbook.tex > perfbook-hb.tex

# Rules related to perfbook_html are removed as of May, 2016

$(EPSSOURCES_FROM_TEX): %.eps: %.tex
	@echo "$< --> $@"
	@latex -output-directory=$(shell dirname $<) $< > /dev/null 2>&1
	@dvips -Pdownload35 -E $(patsubst %.tex,%.dvi,$<) -o $@ > /dev/null 2>&1
	@sh utilities/fixanepsfonts.sh $@

$(EPSSOURCES_FROM_DOT): %.eps: %.dot
	@echo "$< --> $@"
ifndef DOT
	$(error "$< --> $@: dot not found. Please install graphviz")
endif
	@dot -Tps -o $@ $<
	@sh utilities/fixanepsfonts.sh $@

$(EPSSOURCES_FROM_FIG): %.eps: %.fig
	@echo "$< --> $@"
ifndef FIG2EPS
	$(error "$< --> $@: fig2eps not found. Please install fig2ps")
endif
	@fig2eps --nogv $< > /dev/null 2>&1
	@sh utilities/fixanepsfonts.sh $@

$(PDFTARGETS_OF_EPS): %.pdf: %.eps
	@echo "$< --> $@"
ifndef A2PING
	$(error "$< --> $@: a2ping not found. Please install it.")
endif
	@a2ping --below --hires --bboxfrom=compute-gs $< $@ > /dev/null 2>&1

$(PDFTARGETS_OF_SVG): %.pdf: %.svg
	@echo "$< --> $@"
ifndef INKSCAPE
	$(error "$< --> $@: inkscape not found. Please install it.")
endif
	@inkscape --export-pdf=$@ $<

clean:
	find . -name '*.aux' -o -name '*.blg' \
		-o -name '*.dvi' -o -name '*.log' \
		-o -name '*.qqz' -o -name '*.toc' -o -name '*.bbl' | xargs rm -f
	rm -f perfbook_flat.tex perfbook.out perfbook-1c.out
	rm -f $(LATEXGENERATED)
	rm -f perfbook-hb.out perfbook-1c.tex perfbook-hb.tex
	rm -f extraction

distclean: clean
	sh utilities/cleanpdf.sh
	rm -f $(EPSSOURCES_FROM_DOT) $(EPSSOURCES_FROM_TEX) $(EPSSOURCES_FROM_FIG)

touchsvg:
	find . -name '*.svg' | xargs touch

ls-unused:
	find . -name .unused | xargs ls

neatfreak: distclean
	# Don't forget to regenerate the .pdf from each .svg file
	find . -name '*.pdf' | xargs rm -f
