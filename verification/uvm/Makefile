# Build PDF from README.md
# Requires: pandoc and a PDF engine (e.g., pdflatex or xelatex)

BUILD_DIR   := build
SOURCE_MD   := README.md
OUTPUT_PDF  := $(BUILD_DIR)/README.pdf

# Adjust paths in README if needed, but Makefile itself just needs to point to correct src if it had any.
# UVM README has relative paths like ../../src, which should now be ../../../src

PDF_ENGINE  ?= pdflatex

.PHONY: all pdf clean

all: pdf

pdf: $(OUTPUT_PDF)

$(OUTPUT_PDF): $(SOURCE_MD) | $(BUILD_DIR)
	pandoc $(SOURCE_MD) -o $(OUTPUT_PDF) \
		--pdf-engine=$(PDF_ENGINE) \
		-V geometry:margin=1in \
		-V colorlinks=true

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

clean:
	rm -rf $(BUILD_DIR)
