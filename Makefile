
#─────────────────────────────── GLOBAL SETTINGS ──────────────────────────────
SHELL        := bash
.SHELLFLAGS  := -e -o pipefail -c   # exit on error, fail on pipe

LOCALES      := ru en
# Use latest Git tag if present, otherwise fallback to package.json
VERSION      := $(shell git describe --tags --abbrev=0 2>/dev/null \
	                || node -p "require('./package.json').version")
BUILD_SCOPE ?= local
BUILD_REF   ?= HEAD

# Build directories
SITE_DIR     := build/site
ASM_DIR      := build/asm
PDF_DIR      := build/pdf
DOCX_DIR     := build/docx

# Pandoc reference DOCX and Lua filters
PANDOC_REF   := $(CURDIR)/docx/reference.docx
LUA_COVER    := $(CURDIR)/docx/coverpage.lua

# rsvg-convert check (for SVG→PNG in DOCX)
ifneq ($(shell command -v rsvg-convert),)
SVG_FILTER   := --lua-filter=$(CURDIR)/docx/svg2png.lua
else
$(warning rsvg-convert not found — SVGs will be embedded as SVG)
SVG_FILTER   :=
endif

# Common options for asciidoctor-pdf
ASCIIDOCTOR_PDF_OPTS := \
	-a pdf-theme=config/default-theme.yml \
	-a pdf-fontsdir=/usr/share/fonts/truetype/dejavu \
	-a toc -a allow-uri-read -a title-page=true \
	-a revnumber=$(VERSION) -a version-label=

# Release archive name
RELEASE_FILE := adaptadocx-docs-$(VERSION).zip

.DEFAULT_GOAL := build-site

#────────────────────────────────── BUILD ─────────────────────────────────────
.PHONY: build build-site build-html build-pdf build-docx build-all \
        clean test release

build-html:
	@echo "[html] start"; \
	for l in $(LOCALES); do \
		echo "  • $${l}"; \
		pb="antora-playbook-$${l}.yml"; \
		if [ "$(BUILD_SCOPE)" = "tags" ]; then \
			npx antora "$$pb"; \
		else \
			bak="$$pb.bak"; \
			cp "$$pb" "$$bak"; \
			tr -d '\r' < "$$pb" > "$$pb.unix" && mv "$$pb.unix" "$$pb"; \
			sed -i "s/tags: '\*'/tags: ~/" "$$pb"; \
			sed -i "s/branches: ~$$/branches: $(BUILD_REF)/" "$$pb"; \
			npx antora "$$pb"; \
			mv "$$bak" "$$pb"; \
		fi; \
	done
	@echo "[html] done"

## PDF
build-pdf: build-html
	@mkdir -p "$(PDF_DIR)"
	@for l in $(LOCALES); do \
		echo "[pdf] $${l}"; \
		for version_dir in $(SITE_DIR)/$${l}/*/; do \
			if [ -d "$$version_dir" ]; then \
				version=$$(basename "$$version_dir"); \
				if [ "$(BUILD_SCOPE)" != "tags" ] && [ "$$version" != "$(BUILD_REF)" ] && [ "$$version" != "current" ] && [ "$$version" != "main" ]; then continue; fi; \
				export_file=""; \
				for candidate in "$(ASM_DIR)/$${l}/$$version/_exports/index.adoc" "$(ASM_DIR)/$${l}/_exports/index.adoc" "$(ASM_DIR)/_exports/$${l}/$$version/index.adoc" "$(ASM_DIR)/_exports/$${l}/index.adoc"; do \
					if [ -f "$$candidate" ]; then export_file="$$candidate"; base=$$(dirname "$$(dirname "$$candidate")"); break; fi; \
				done; \
				[ -z "$$export_file" ] && continue; \
				img_src="$$base/_images"; \
				img_dst="$$(dirname "$$export_file")/$${l}/$$version/_images"; \
				[ -d "$$img_src" ] && mkdir -p "$$img_dst" && cp -r "$$img_src"/* "$$img_dst"/ || true; \
				outdir="$(PDF_DIR)/$${l}/$$version"; \
				outfile="$$outdir/adaptadocx-$${l}.pdf"; \
				mkdir -p "$$outdir"; \
				toc=$$( [ "$$l" = ru ] && echo '-a toc-title=Содержание' || echo '-a toc-title=Contents' ); \
				asciidoctor-pdf $(ASCIIDOCTOR_PDF_OPTS) $$toc -a revnumber=$$version -o "$$outfile" "$$export_file"; \
				mkdir -p "$(SITE_DIR)/$${l}/$$version/_downloads"; \
				cp "$$outfile" "$(SITE_DIR)/$${l}/$$version/_downloads/adaptadocx-$${l}.pdf"; \
			fi; \
		done; \
	done
	@echo "[pdf] done"

## DOCX
build-docx: build-html
	@mkdir -p "$(DOCX_DIR)"
	@for l in $(LOCALES); do \
		echo "[docx] $${l}"; \
		for version_dir in $(SITE_DIR)/$${l}/*/; do \
			if [ -d "$$version_dir" ]; then \
				version=$$(basename "$$version_dir"); \
				if [ "$(BUILD_SCOPE)" != "tags" ] && [ "$$version" != "$(BUILD_REF)" ] && [ "$$version" != "current" ] && [ "$$version" != "main" ]; then continue; fi; \
				base="$(ASM_DIR)/$${l}/$$version"; \
				img_src="$$base/_images"; \
				img_dst="$$base/_exports/$${l}/$$version/_images"; \
				[ -d "$$img_src" ] && mkdir -p "$$img_dst" && cp -r "$$img_src"/* "$$img_dst"/ || true; \
				outdir="$(DOCX_DIR)/$${l}/$$version"; \
				outfile="$$outdir/adaptadocx-$${l}.docx"; \
				outfile_abs="$(CURDIR)/$$outfile"; \
				mkdir -p "$$outdir"; \
				tmp_meta="$(CURDIR)/$(DOCX_DIR)/meta-$${l}-$$version.yml"; \
				sed "s/{page-version}/$$version/g" $(CURDIR)/config/meta-$${l}.yml > "$$tmp_meta"; \
				( cd "$$base/_exports" && asciidoctor -b docbook5 -r $(CURDIR)/extensions/collapsible_tree_processor.rb -a allow-uri-read -a revdate! -a revnumber! -a docdate! -a docdatetime! -o - index.adoc | pandoc --from=docbook --to=docx --reference-doc=$(PANDOC_REF) --metadata-file="$$tmp_meta" $(SVG_FILTER) --lua-filter=$(LUA_COVER) -o "$$outfile_abs" ); \
				rm -f "$$tmp_meta"; \
				mkdir -p "$(SITE_DIR)/$${l}/$$version/_downloads"; \
				cp "$$outfile" "$(SITE_DIR)/$${l}/$$version/_downloads/adaptadocx-$${l}.docx"; \
			fi; \
		done; \
	done
	@echo "[docx] done"

## Composite 
build-site: build-html build-pdf build-docx
	@echo "[site] full build done"

build:      build-site
build-all:  build-site

#──────────────────────────── OTHER TARGETS ───────────────────────────────────
clean:
	-rm -rf build
	@echo '[clean] build/ removed'

test:
	@if [ -d "$(SITE_DIR)" ]; then \
		echo "[test] Running htmltest on existing site"; \
		htmltest -c .htmltest.yml "$(SITE_DIR)"; \
	else \
		echo "[test] Skipping htmltest - no site built"; \
	fi
	@vale --config=.vale.ini docs/
	@find scripts -name '*.sh' -print0 | xargs -0 -I{} bash -c 'tr -d "\r" < "{}" | shellcheck -'
	@echo '[test] OK'

release: build-site test
	@cd build && zip -rq ../"$(RELEASE_FILE)" .
	@echo "[release] $(RELEASE_FILE) created"