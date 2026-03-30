# Makefile for rv-vkeccak — RISC-V Vector Keccak Extension
#
# Targets:
#   make pdf          — Build PDF (Docker if available, native otherwise)
#   make html         — Build HTML
#   make all          — Build PDF + HTML
#   make docker-pull  — Pull the RISC-V docs Docker image
#   make install-deps — Install native build deps (Ubuntu/Debian, needs sudo)
#   make clean        — Remove build artifacts
#
# Options:
#   SKIP_DOCKER=true  — Force native build even if Docker is available

MANUAL_DIR := riscv-isa-manual
BUILD_DIR  := $(MANUAL_DIR)/build

# Pass through to the ISA manual Makefile
MAKE_OPTS :=
ifdef SKIP_DOCKER
  MAKE_OPTS += SKIP_DOCKER=$(SKIP_DOCKER)
endif

.PHONY: all pdf html clean docker-pull install-deps submodule-init

all: pdf html

submodule-init:
	@if [ ! -f $(MANUAL_DIR)/docs-resources/global-config.adoc ]; then \
		echo "Initializing submodules..."; \
		cd $(MANUAL_DIR) && git submodule update --init --recursive; \
	fi

pdf: submodule-init
	$(MAKE) -C $(MANUAL_DIR) $(MAKE_OPTS) build-pdf

html: submodule-init
	$(MAKE) -C $(MANUAL_DIR) $(MAKE_OPTS) build-html

clean:
	$(MAKE) -C $(MANUAL_DIR) clean
	rm -rf $(MANUAL_DIR)/dependencies/node_modules
	rm -f $(MANUAL_DIR)/dependencies/Gemfile.lock
	rm -f $(MANUAL_DIR)/dependencies/package-lock.json

docker-pull:
	docker pull ghcr.io/riscv/riscv-docs-base-container-image:latest

install-deps:
	./scripts/install-deps.sh
