#!/bin/bash
set -euo pipefail

# Build the RISC-V ISA manual using the official Docker image.
# Usage: ./scripts/docker-build.sh [pdf|html|all]

TARGET="${1:-pdf}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

DOCKER_IMG="ghcr.io/riscv/riscv-docs-base-container-image:latest"

# Pull image if not present
if ! docker image inspect "$DOCKER_IMG" >/dev/null 2>&1; then
    echo "==> Pulling Docker image..."
    docker pull "$DOCKER_IMG"
fi

cd "$REPO_ROOT/riscv-isa-manual"

# Ensure submodules are initialized
if [ ! -f docs-resources/global-config.adoc ]; then
    git submodule update --init --recursive
fi

case "$TARGET" in
    pdf)  make build-pdf  ;;
    html) make build-html ;;
    all)  make build-pdf build-html ;;
    *)
        echo "Usage: $0 [pdf|html|all]" >&2
        exit 1
        ;;
esac

echo "==> Output in riscv-isa-manual/build/"
