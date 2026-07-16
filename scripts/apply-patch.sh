#!/bin/bash
set -euo pipefail

# Patch the Zvknhk (Vector Keccak) extension into the upstream RISC-V ISA
# manual sources. The manual itself is a pristine upstream submodule; this
# script is the single point where our local change is layered on top:
#
#   1. Copy zvknhk.adoc into the manual's cryptography source directory.
#   2. Add an include for it to crypto.adoc, right after the Vector
#      Cryptography section (zvk.adoc), so the chapter renders as part of the
#      "Cryptography Extensions". leveloffset=+1 shifts its top-level (==)
#      headings down to (===) so it sits as a section peer of zvk, matching
#      how upstream nests the other crypto extensions.
#
# The script is idempotent: running it repeatedly leaves the tree in the same
# state, so it is safe to invoke on every build.
#
# NOTE ON UPSTREAM LAYOUT: these paths track the current upstream source tree
# (post the src/unpriv/ + modules/ reorganization). If a future upstream bump
# moves things again, the checks below fail loudly — update the variables here.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
MANUAL_SRC="$REPO_ROOT/riscv-isa-manual/src"

CHAPTER="zvknhk.adoc"                 # source of truth, at the repo root
DEST_DIR="$MANUAL_SRC/unpriv"         # where the crypto sources live
ANCHOR_FILE="$DEST_DIR/crypto.adoc"   # file we add the include to
ANCHOR="include::zvk.adoc[]"          # insert right after this line
INCLUDE="include::${CHAPTER}[leveloffset=+1]"

if [ ! -f "$REPO_ROOT/$CHAPTER" ]; then
    echo "error: $CHAPTER not found at repo root ($REPO_ROOT)" >&2
    exit 1
fi

if [ ! -f "$ANCHOR_FILE" ]; then
    echo "error: expected manual source $ANCHOR_FILE not found." >&2
    echo "       Either the submodule is not initialized (run" >&2
    echo "       'git submodule update --init --recursive'), or the upstream" >&2
    echo "       source layout changed — update the paths in $0." >&2
    exit 1
fi

# Copy the chapter in. The manual's Makefile keys rebuilds off tracked src
# files (git ls-files), and this copy is untracked there — so when it changes,
# bump the anchor file's mtime (which IS tracked) to force a rebuild.
if cmp -s "$REPO_ROOT/$CHAPTER" "$DEST_DIR/$CHAPTER"; then
    echo "==> $CHAPTER unchanged"
else
    echo "==> Copying $CHAPTER into $DEST_DIR"
    cp "$REPO_ROOT/$CHAPTER" "$DEST_DIR/$CHAPTER"
    touch "$ANCHOR_FILE"
fi

if grep -qF "$INCLUDE" "$ANCHOR_FILE"; then
    echo "==> $(basename "$ANCHOR_FILE") already includes $CHAPTER (nothing to do)"
else
    if ! grep -qF "$ANCHOR" "$ANCHOR_FILE"; then
        echo "error: anchor '$ANCHOR' not found in $ANCHOR_FILE;" >&2
        echo "       upstream layout changed — update scripts/apply-patch.sh" >&2
        exit 1
    fi
    echo "==> Adding '$INCLUDE' to $(basename "$ANCHOR_FILE")"
    awk -v anchor="$ANCHOR" -v line="$INCLUDE" '
        { print }
        index($0, anchor) { print line }
    ' "$ANCHOR_FILE" > "$ANCHOR_FILE.tmp"
    mv "$ANCHOR_FILE.tmp" "$ANCHOR_FILE"
fi

echo "==> Patch applied."
