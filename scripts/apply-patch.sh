#!/bin/bash
set -euo pipefail

# Patch the Zvknhk (Vector Keccak) extension into the upstream RISC-V ISA
# manual sources. The manual itself is a pristine upstream submodule; this
# script is the single point where our local changes are layered on top:
#
#   1. Copy zvknhk.adoc into the manual's src/ directory.
#   2. Add an `include::zvknhk.adoc[]` line to src/unpriv.adoc so the chapter
#      is pulled into the Unprivileged volume.
#
# The script is idempotent: running it repeatedly leaves the tree in the same
# state, so it is safe to invoke on every build.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
MANUAL_SRC="$REPO_ROOT/riscv-isa-manual/src"

CHAPTER="zvknhk.adoc"                 # source of truth, at the repo root
ANCHOR="include::vector-crypto.adoc[]"  # insert the include right after this
INCLUDE="include::${CHAPTER}[]"

if [ ! -f "$REPO_ROOT/$CHAPTER" ]; then
    echo "error: $CHAPTER not found at repo root ($REPO_ROOT)" >&2
    exit 1
fi

if [ ! -f "$MANUAL_SRC/unpriv.adoc" ]; then
    echo "error: manual sources not found at $MANUAL_SRC" >&2
    echo "       run 'git submodule update --init --recursive' first" >&2
    exit 1
fi

# Copy the chapter in. The manual's Makefile keys rebuilds off tracked src
# files (git ls-files), and this copy is untracked there — so when it changes,
# bump unpriv.adoc's mtime (which IS tracked) to force a rebuild.
if cmp -s "$REPO_ROOT/$CHAPTER" "$MANUAL_SRC/$CHAPTER"; then
    echo "==> $CHAPTER unchanged"
else
    echo "==> Copying $CHAPTER into manual sources"
    cp "$REPO_ROOT/$CHAPTER" "$MANUAL_SRC/$CHAPTER"
    touch "$MANUAL_SRC/unpriv.adoc"
fi

if grep -qF "$INCLUDE" "$MANUAL_SRC/unpriv.adoc"; then
    echo "==> unpriv.adoc already includes $CHAPTER (nothing to do)"
else
    if ! grep -qF "$ANCHOR" "$MANUAL_SRC/unpriv.adoc"; then
        echo "error: anchor '$ANCHOR' not found in unpriv.adoc;" >&2
        echo "       upstream layout changed — update scripts/apply-patch.sh" >&2
        exit 1
    fi
    echo "==> Adding '$INCLUDE' to unpriv.adoc"
    awk -v anchor="$ANCHOR" -v line="$INCLUDE" '
        { print }
        index($0, anchor) { print line }
    ' "$MANUAL_SRC/unpriv.adoc" > "$MANUAL_SRC/unpriv.adoc.tmp"
    mv "$MANUAL_SRC/unpriv.adoc.tmp" "$MANUAL_SRC/unpriv.adoc"
fi

echo "==> Patch applied."
