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
#   make force-clean  — Remove build artifacts, incl. any left root-owned by a
#                       Docker build (deletes them via the container; needs Docker)
#
# Options:
#   SKIP_DOCKER=true   — Force a native build even if Docker is available
#   SKIP_DOCKER=false  — Force a Docker build (recommended; native is unreliable
#                        on current Debian — see README)

MANUAL_DIR := riscv-isa-manual
BUILD_DIR  := $(MANUAL_DIR)/build
DOCKER_BIN ?= docker
DOCKER_IMG := ghcr.io/riscv/riscv-docs-base-container-image:latest

# Pass through to the ISA manual Makefile. Prefer Docker (the reliable, pinned
# toolchain) whenever the docker binary is present; fall back to native builds
# otherwise. Override explicitly with SKIP_DOCKER=true|false.
SKIP_DOCKER ?= $(shell command -v docker >/dev/null 2>&1 && echo false || echo true)
MAKE_OPTS := SKIP_DOCKER=$(SKIP_DOCKER)

.PHONY: all pdf html patch clean force-clean docker-pull install-deps submodule-init

# The PDF and HTML builds share riscv-isa-manual/build (and build/images-out),
# so they must not run concurrently — force serial execution even under `make -j`.
.NOTPARALLEL:

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

# SKIP_DOCKER=true so the sub-make doesn't probe the Docker daemon (which prints
# a permission error when the user isn't in the docker group); cleaning never
# needs Docker anyway.
clean:
	cd $(MANUAL_DIR) && $(MAKE) SKIP_DOCKER=true clean
	rm -rf $(MANUAL_DIR)/dependencies/node_modules
	rm -f $(MANUAL_DIR)/dependencies/Gemfile.lock
	rm -f $(MANUAL_DIR)/dependencies/package-lock.json

# Recovery target: a Docker build that ran without --user (or a mis-mounted one)
# can leave build files owned by root that `clean` can't remove without sudo.
# Delete them from inside the container, which runs as root, then clean normally.
# The extra repo-root paths sweep stray dirs a mis-mounted build may have dropped.
force-clean:
	$(DOCKER_BIN) run --rm -v $(CURDIR):/work $(DOCKER_IMG) \
		rm -rf /work/$(BUILD_DIR) \
		       /work/build /work/src /work/docs-resources /work/normative_rule_defs
	$(MAKE) clean

docker-pull:
	$(DOCKER_BIN) pull $(DOCKER_IMG)

install-deps:
	./scripts/install-deps.sh
