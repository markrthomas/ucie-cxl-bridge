# Build PDF from design-spec.md (run from this directory: make)
#
# Requires: pandoc
# PDF engine (need one):
#   - pdflatex: sudo apt install texlive-latex-recommended
#   - xelatex:  sudo apt install texlive-xetex (better Unicode)
#
# Override engine: make PDF_ENGINE=xelatex

BUILD_DIR   := build
SOURCE_MD   := design-spec.md
OUTPUT_PDF  := $(BUILD_DIR)/design-spec.pdf

PDF_ENGINE  ?= pdflatex

.PHONY: all pdf clean

all: pdf

pdf: $(OUTPUT_PDF)

$(OUTPUT_PDF): $(SOURCE_MD) | $(BUILD_DIR)
	pandoc $(SOURCE_MD) -o $(OUTPUT_PDF) \
		--pdf-engine=$(PDF_ENGINE) \
		--toc \
		-V geometry:margin=1in \
		-V colorlinks=true

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

clean:
	rm -rf $(BUILD_DIR)
