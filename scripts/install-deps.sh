#!/bin/bash
set -euo pipefail

# Install native build dependencies for the RISC-V ISA manual on
# Ubuntu / Debian. Run as root (or with sudo).

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
MANUAL_DIR="$REPO_ROOT/riscv-isa-manual"
APT_LIST="$MANUAL_DIR/dependencies/apt_packages.txt"
GEMFILE="$MANUAL_DIR/dependencies/Gemfile"

if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root. Try: sudo $0" >&2
    exit 1
fi

echo "==> Installing system packages..."
apt-get update -qq
# NOTE: upstream's apt_packages.txt lists libgdk-pixbuf2.0-dev, which was
# renamed to libgdk-pixbuf-2.0-dev on newer Debian/Ubuntu. If apt reports that
# package as unavailable, it is almost certainly already present under the new
# name (installed by default) — the mathematical gem builds fine without action.
grep -v '^#' "$APT_LIST" | grep -v '^$' | xargs apt-get install -y

# The `mathematical` gem (pulled in by asciidoctor-mathematical) compiles a
# bundled native library whose CMakeLists requests a minimum older than CMake
# 4.x allows. This env var tells CMake to accept the old policy version.
export CMAKE_POLICY_VERSION_MINIMUM=3.5

echo "==> Installing Ruby gems (Gemfile)..."
gem install bundler
BUNDLE_GEMFILE="$GEMFILE" bundle install

# The manual's PDF build requires these gems too, but they are not in the
# upstream Gemfile (asciidoctor-sail is passed via --require in the Makefile;
# ditaamini renders the ditaa diagrams).
echo "==> Installing extra Ruby gems (not in Gemfile)..."
gem install asciidoctor-sail asciidoctor-diagram-ditaamini

echo "==> Done. You can now build with: make pdf"
