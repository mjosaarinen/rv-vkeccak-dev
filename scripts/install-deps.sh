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
grep -v '^#' "$APT_LIST" | grep -v '^$' | xargs apt-get install -y

echo "==> Installing Ruby gems..."
gem install bundler
BUNDLE_GEMFILE="$GEMFILE" bundle install

echo "==> Done. You can now build with: make pdf"
