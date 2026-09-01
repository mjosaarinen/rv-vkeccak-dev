#!/bin/bash
set -euo pipefail

# Patch the Zvknhk (Vector Keccak) extension into the upstream Spike
# (riscv-isa-sim) sources. Spike is a pristine upstream submodule; this script
# is the single point where our local change is layered on top:
#
#   1. Copy spike/vkeccak_vi.h into the simulator's riscv/insns/ directory.
#   2. Insert the small amount of glue that registers the instruction: the
#      EXT_ZVKK extension id, its ISA-string name ("zvkk"), the encoding,
#      the build-system entry, and the required element-group macros.
#
# Every edit is a pure insertion anchored on a nearby upstream line, and every
# site is guarded by a token that only this patch introduces — so the script is
# idempotent and safe to run on every build.
#
# WHY ANCHORS AND NOT A DIFF: the original change lives in the dev-keccak
# branch of a Spike fork, taken from upstream at 55b4658d (2026-06-25). Two of
# its nine hunks (disasm/isa_parser.cc, riscv/riscv.mk.in) already fail to
# apply against upstream a couple of months later, because they insert lines
# into long, frequently-edited lists. Anchoring on a single stable neighbour
# line survives that churn; unified-diff context does not.
#
# NOTE ON UPSTREAM LAYOUT: if a future Spike bump moves or renames any anchor,
# the corresponding check below fails loudly — update the anchor here.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
SIM_DIR="$REPO_ROOT/riscv-isa-sim"
CHAPTER_SRC="$REPO_ROOT/spike/vkeccak_vi.h"
INSN_DST="$SIM_DIR/riscv/insns/vkeccak_vi.h"

if [ ! -f "$CHAPTER_SRC" ]; then
    echo "error: spike/vkeccak_vi.h not found at repo root ($REPO_ROOT)" >&2
    exit 1
fi

if [ ! -f "$SIM_DIR/riscv/riscv.mk.in" ]; then
    echo "error: expected Spike source $SIM_DIR/riscv/riscv.mk.in not found." >&2
    echo "       Either the submodule is not initialized (run" >&2
    echo "       'git submodule update --init --recursive'), or the upstream" >&2
    echo "       source layout changed — update the paths in $0." >&2
    exit 1
fi

BLOCKS="$(mktemp -d)"
trap 'rm -rf "$BLOCKS"' EXIT

# ---------------------------------------------------------------- helpers ---

# patch_file <file> <mode> <anchor> <terminator|-> <guard-token> <block-file>
#
#   mode = after       : insert the block after the line matching <anchor>
#          before      : insert the block before the line matching <anchor>
#          after_term  : find <anchor>, then insert after the next line
#                        matching <terminator> (used to land after the close
#                        of the block the anchor sits in)
#
# <guard-token> is a string that only this patch introduces; if it is already
# present the site is left alone, which is what makes the script idempotent.
patch_file() {
    local rel="$1" mode="$2" anchor="$3" term="$4" guard="$5" block="$6"
    local file="$SIM_DIR/$rel"

    if [ ! -f "$file" ]; then
        echo "error: $rel not found — upstream layout changed; update $0" >&2
        exit 1
    fi

    if grep -qF -- "$guard" "$file"; then
        echo "    $rel: already patched"
        return 0
    fi

    if ! grep -qF -- "$anchor" "$file"; then
        echo "error: anchor not found in $rel:" >&2
        echo "         $anchor" >&2
        echo "       upstream layout changed — update the anchor in $0" >&2
        exit 1
    fi

    MODE="$mode" ANCHOR="$anchor" TERM="$term" BLOCK="$block" awk '
        BEGIN {
            while ((getline l < ENVIRON["BLOCK"]) > 0) blk = blk l "\n"
            mode = ENVIRON["MODE"]
        }
        mode == "before" && !done && index($0, ENVIRON["ANCHOR"]) {
            printf "%s", blk; done = 1
        }
        { print }
        mode == "after" && !done && index($0, ENVIRON["ANCHOR"]) {
            printf "%s", blk; done = 1
        }
        mode == "after_term" && !armed && !done && index($0, ENVIRON["ANCHOR"]) {
            armed = 1; next
        }
        mode == "after_term" && armed && !done && index($0, ENVIRON["TERM"]) {
            printf "%s", blk; armed = 0; done = 1
        }
    ' "$file" > "$file.tmp"

    mv "$file.tmp" "$file"

    if ! grep -qF -- "$guard" "$file"; then
        echo "error: insertion into $rel did not take effect; update $0" >&2
        exit 1
    fi
    echo "    $rel: patched"
}

# ----------------------------------------------------------------- blocks ---

cat > "$BLOCKS/disasm.cc" <<'EOF'

  // Zvknhk (vkeccak.vi) -- applied by scripts/apply-spike-patch.sh
  if (ext_enabled(EXT_ZVKK)) {
    DEFINE_VECTOR_VIU(vkeccak_vi);
  }
EOF

cat > "$BLOCKS/isa_parser.cc" <<'EOF'
  // Zvknhk (vkeccak.vi) -- applied by scripts/apply-spike-patch.sh
  {"zvkk", {EXT_ZVKK}},
EOF

cat > "$BLOCKS/encoding_match.h" <<'EOF'
/* Zvknhk (vkeccak.vi) -- applied by scripts/apply-spike-patch.sh */
#define MATCH_VKECCAK_VI 0xa608a077
#define MASK_VKECCAK_VI 0xfe0ff07f
EOF

cat > "$BLOCKS/encoding_declare.h" <<'EOF'
DECLARE_INSN(vkeccak_vi, MATCH_VKECCAK_VI, MASK_VKECCAK_VI)
EOF

cat > "$BLOCKS/isa_parser.h" <<'EOF'
  EXT_ZVKK,  /* Zvknhk (vkeccak.vi) */
EOF

# NOTE: tabs are significant in the two riscv.mk.in blocks below.
printf '%s\n' \
    '# Zvknhk (vkeccak.vi) -- applied by scripts/apply-spike-patch.sh' \
    'riscv_insn_ext_zvkk = \' \
    "$(printf '\tvkeccak_vi \\')" \
    '' > "$BLOCKS/riscv.mk.in.list"

printf '%s\n' "$(printf '\t$(riscv_insn_ext_zvkk) \\')" > "$BLOCKS/riscv.mk.in.use"

cat > "$BLOCKS/vector_unit.h" <<'EOF'

// Element Group of 32 64 bits elements (2048b total).
// Zvknhk (vkeccak.vi) -- applied by scripts/apply-spike-patch.sh
using EGU64x32_t = std::array<uint64_t, 32>;
EOF

cat > "$BLOCKS/zvk_ext_macros.h" <<'EOF'
// Zvknhk (vkeccak.vi) -- applied by scripts/apply-spike-patch.sh

#define require_zvkk \
  do { \
    require_vector(true); \
    require_extension(EXT_ZVKK); \
  } while (0)

// Checks that the vector unit state (vtype and vl) can be interpreted
// as element groups with EEW=64, EGS=32 (thirty-two 64-bits elements per
// group), for an effective element group width of EGW=2048 bits.
#define require_element_groups_64x32 \
  do { \
    /* 'vstart' must be a multiple of EGS */ \
    const reg_t vstart = P.VU.vstart->read(); \
    require(vstart % 32 == 0); \
    /* 'vl' must be a multiple of EGS */ \
    const reg_t vl = P.VU.vl->read(); \
    require(vl % 32 == 0); \
  } while (0)

// VECTOR KECCAK SPECIFIC MACRO
#define VI_ZVK_VD_VS2_NOOPERANDS_PRELOOP_EGU64x32_NOVM_LOOP(PRELUDE, \
                                                        PRELOOP, \
                                                        EG_BODY) \
  do { \
    require_element_groups_64x32; \
    require_no_vmask; \
    const reg_t vd_num = insn.rd(); \
    const reg_t zimm5 = insn.rs2(); \
    const reg_t vstart_eg = P.VU.vstart->read() / 32; \
    const reg_t vl_eg = P.VU.vl->read() / 32; \
    do { PRELUDE } while (0); \
    if (vstart_eg < vl_eg) { \
      PRELOOP \
      for (reg_t idx_eg = vstart_eg; idx_eg < vl_eg; ++idx_eg) { \
        EG_BODY \
      } \
    } \
    P.VU.vstart->write(0); \
  } while (0)

// Copies a EGU64x32_t value from 'SRC' into 'DST'.
#define EGU64x32_COPY(DST, SRC) \
  for (std::size_t bidx = 0; bidx < 32; ++bidx) { \
    (DST)[bidx] = (SRC)[bidx]; \
  }

EOF

cat > "$BLOCKS/zvkned_ext_macros.h" <<'EOF'

// vkeccak.vi instruction constraints (Zvknhk).
// Applied by scripts/apply-spike-patch.sh
#define require_vkeccak_vi_constraints \
  do { \
    require_zvkk; \
    require(P.VU.vsew == 64); \
    require_egw_fits(2048); \
  } while (false)
EOF

# ------------------------------------------------------------------ apply ---

if cmp -s "$CHAPTER_SRC" "$INSN_DST"; then
    echo "==> vkeccak_vi.h unchanged"
else
    echo "==> Copying vkeccak_vi.h into riscv/insns"
    cp "$CHAPTER_SRC" "$INSN_DST"
fi

echo "==> Registering the instruction in the Spike sources"

patch_file riscv/isa_parser.h after \
    '  EXT_ZICFISS,' - \
    'EXT_ZVKK' "$BLOCKS/isa_parser.h"

patch_file disasm/isa_parser.cc after \
    '  {"zvkt"},' - \
    '{"zvkk"' "$BLOCKS/isa_parser.cc"

patch_file riscv/encoding.h after \
    '#define MASK_VIOTA_M 0xfc0ff07f' - \
    'MATCH_VKECCAK_VI' "$BLOCKS/encoding_match.h"

patch_file riscv/encoding.h after \
    'DECLARE_INSN(viota_m, MATCH_VIOTA_M, MASK_VIOTA_M)' - \
    'DECLARE_INSN(vkeccak_vi' "$BLOCKS/encoding_declare.h"

patch_file riscv/riscv.mk.in before \
    'riscv_insn_ext_p = \' - \
    'riscv_insn_ext_zvkk = ' "$BLOCKS/riscv.mk.in.list"

patch_file riscv/riscv.mk.in after \
    '$(riscv_insn_ext_zicfiss) \' - \
    '$(riscv_insn_ext_zvkk)' "$BLOCKS/riscv.mk.in.use"

patch_file riscv/vector_unit.h after \
    'using EGU8x16_t = std::array<uint8_t, 16>;' - \
    'EGU64x32_t' "$BLOCKS/vector_unit.h"

patch_file riscv/zvk_ext_macros.h before \
    '#endif  // RISCV_ZVK_EXT_MACROS_H_' - \
    'require_zvkk' "$BLOCKS/zvk_ext_macros.h"

patch_file riscv/zvkned_ext_macros.h after_term \
    '    require_noover_eglmul(insn.rd(), insn.rs2()); \' '} while (false)' \
    'require_vkeccak_vi_constraints' "$BLOCKS/zvkned_ext_macros.h"

# The disassembler entry goes next to the other Zvk* blocks. The upstream fork
# nested it inside `if (ext_enabled(EXT_ZICFISS))`, which meant vkeccak.vi only
# disassembled when Zicfiss happened to be enabled too — not the case for the
# documented test ISA string. Anchor on the Zvksh block instead.
patch_file disasm/disasm.cc after_term \
    '    DEFINE_VECTOR_VV(vsm3me_vv);' '  }' \
    'DEFINE_VECTOR_VIU(vkeccak_vi)' "$BLOCKS/disasm.cc"

echo "==> Patch applied."
