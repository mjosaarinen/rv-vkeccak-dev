# Makefile for rv-vkeccak — RISC-V Vector Keccak Extension
#
# Targets:
#   make pdf          — Build PDF (Docker if available, native otherwise)
#   make html         — Build HTML
#   make all          — Build PDF + HTML
#   make patch        — Patch zvknhk.adoc into the upstream manual sources
#   make docker-pull  — Pull the RISC-V docs Docker image
#   make install-deps — Install native build deps (Ubuntu/Debian, needs sudo)
#   make clean        — Remove build artifacts
#
# Options:
#   SKIP_DOCKER=true   — Force a native build even if Docker is available
#   SKIP_DOCKER=false  — Force a Docker build (recommended; native is unreliable
#                        on current Debian — see README)

MANUAL_DIR := riscv-isa-manual
BUILD_DIR  := $(MANUAL_DIR)/build

# Pass through to the ISA manual Makefile. Prefer Docker (the reliable, pinned
# toolchain) whenever the docker binary is present; fall back to native builds
# otherwise. Override explicitly with SKIP_DOCKER=true|false.
SKIP_DOCKER ?= $(shell command -v docker >/dev/null 2>&1 && echo false || echo true)
MAKE_OPTS := SKIP_DOCKER=$(SKIP_DOCKER)

.PHONY: all pdf html patch clean docker-pull install-deps submodule-init

all: pdf html

submodule-init:
	@if [ ! -f $(MANUAL_DIR)/docs-resources/global-config.adoc ]; then \
		echo "Initializing submodules..."; \
		cd $(MANUAL_DIR) && git submodule update --init --recursive; \
	fi

# Layer our Zvknhk chapter onto the pristine upstream manual sources.
patch: submodule-init
	./scripts/apply-patch.sh

# Build inside the submodule with `cd` (not `$(MAKE) -C`) so that ${PWD} — which
# the manual's Makefile uses to build its Docker bind-mount paths — resolves to
# the submodule directory, not the superproject root. `-C` updates make's CURDIR
# but leaves the inherited PWD env var pointing at the superproject.
pdf: patch
	cd $(MANUAL_DIR) && $(MAKE) $(MAKE_OPTS) build-pdf

html: patch
	cd $(MANUAL_DIR) && $(MAKE) $(MAKE_OPTS) build-html

clean:
	$(MAKE) -C $(MANUAL_DIR) clean
	rm -rf $(MANUAL_DIR)/dependencies/node_modules
	rm -f $(MANUAL_DIR)/dependencies/Gemfile.lock
	rm -f $(MANUAL_DIR)/dependencies/package-lock.json

docker-pull:
	docker pull ghcr.io/riscv/riscv-docs-base-container-image:latest

install-deps:
	./scripts/install-deps.sh
