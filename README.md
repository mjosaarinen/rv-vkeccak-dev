# rv-vkeccak-dev

Development of the **`Zvknhk`** RISC-V Vector Keccak extension.

**This repository exists to develop [`zvknhk.adoc`](zvknhk.adoc)** — the
`Zvknhk` (Vector Keccak) extension chapter, and the single source of truth for the
specification. It defines the `Zvknhk` extension and its instruction `vkeccak.vi`,
a vector-immediate multi-round Keccak-_p_[1600] permutation. 

**Edit it in the repo root.**

Everything else here is scaffolding to render that one chapter, in context, as part
of the official RISC-V ISA manual so it can be reviewed as a normative document.

Do **not** edit the generated copy at `riscv-isa-manual/src/unpriv/zvknhk.adoc`.

Alongside the specification there are two reference implementations of the
instruction — for Spike, the RISC-V ISA simulator, in
[`spike/vkeccak_vi.h`](spike/vkeccak_vi.h), and for QEMU in
[`qemu/`](qemu/README.md) — and a test suite in [`test/`](test/) that checks
them against SHA-3 and SHAKE known-answer vectors. All three upstreams — the
ISA manual, Spike and QEMU — are pristine submodules that get patched at build
time; the editable sources live here in the repo root.


## Getting the sources

```bash
git clone --recurse-submodules <repo-url>
cd rv-vkeccak-dev
```

If already cloned without submodules (run from the repo root; `--recursive`
also pulls the manual's own `docs-resources` submodule):

```bash
git submodule update --init --recursive
```

There are four submodules, all tracking pristine upstream:

| Submodule | Upstream | Pinned at | Patched by |
|---|---|---|---|
| `riscv-isa-manual` | `github.com/riscv/riscv-isa-manual` | `e5c0c60f` | `scripts/apply-patch.sh` |
| `riscv-isa-sim` | `github.com/riscv-software-src/riscv-isa-sim` | `549da3fa` | `scripts/apply-spike-patch.sh` |
| `qemu-src` | `gitlab.com/qemu-project/qemu` | `d2e570cc` | `scripts/apply-qemu-patch.sh` |
| `demo/openssl` | `github.com/openssl/openssl` | `f089acdf` (`openssl-4.0.2`) | `scripts/apply-openssl-patch.sh` |

The pinned revisions are whatever `git submodule status` reports; the table
records the ones this documentation was written against.

If a submodule checkout ever fails to find the pinned commit, that submodule's
local remote has drifted off upstream — check it:

```bash
git -C riscv-isa-manual remote -v      # must be riscv/riscv-isa-manual
git -C riscv-isa-sim    remote -v      # must be riscv-software-src/riscv-isa-sim
git -C qemu-src         remote -v      # must be qemu-project/qemu
git -C demo/openssl     remote -v      # must be openssl/openssl
```

Either way, `make pdf`/`make html` run `make patch` first, which copies
`zvknhk.adoc` into the manual's `src/unpriv/` and adds an `include::` for it to
`src/unpriv/crypto.adoc` (right after the Vector Cryptography section). The step
is idempotent, so it is safe to re-run; you can also apply the patch on its own
with `make patch`.

## Build — Docker (recommended)

The RISC-V manual builds reproducibly inside the official docs container, which
pins a known-good toolchain and is what upstream CI uses. A native build also
works (see below), but the container is the one that cannot drift.

One-time setup:

```bash
sudo apt-get install -y docker.io
sudo systemctl enable --now docker
sudo usermod -aG docker $USER    # then log out/in, or prefix docker with sudo
make docker-pull                 # pull the docs image (~3.5 GB, needs network)
```

Build (when the `docker` binary is present, `make pdf` uses Docker automatically;
`SKIP_DOCKER=false` forces it):

```bash
make pdf  SKIP_DOCKER=false      # PDF  -> riscv-isa-manual/build/riscv-spec.pdf
make html SKIP_DOCKER=false      # HTML -> riscv-isa-manual/build/riscv-spec.html
make clean
```

The container runs as your UID (`--user $(id -u)`), so the output PDF is owned by
you, not root.

## Build — native (fallback)

A native build needs no root and no 3.5 GB image. Three things bite on current
Debian. The first two are about *which* Asciidoctor you end up running; the
third is about a gem that will not install without root unless you pin it:

- **Gems stranded by a Ruby upgrade.** Debian 13 moved to `ruby3.3`, leaving
  gems installed under Debian 12 behind in `/var/lib/gems/3.1.0`. The
  `/usr/local/bin/asciidoctor-pdf` wrapper left over from then still starts with
  `#!/usr/bin/ruby3.1`, so it dies immediately:

  ```
  env: 'ruby3.1': No such file or directory
  ```

  Reinstalling the gems for the current Ruby fixes it.

- **`PATH` order.** That stale wrapper sits in `/usr/local/bin`, which normally
  precedes the per-user gem bindir — so a fresh `--user-install` is shadowed by
  the broken one until you put the gem bindir first.

- **`rouge` 5.x needs a compiler and Ruby headers.** The manual sets
  `:source-highlighter: rouge`, and rouge 5 requires `strscan ~> 3.1`, which is
  a native gem. Ruby 3.3 bundles only `strscan` 3.0.9, so RubyGems tries to
  build 3.1.x and fails without the Ruby development headers:

  ```
  mkmf.rb can't find header files for ruby at /usr/lib/ruby/include/ruby.h
  ```

  The gem still installs, but the build then dies on `Unable to activate
  rouge-5.1.0, because strscan-3.0.9 conflicts with strscan (~> 3.1)` — and,
  confusingly, on `cannot load such file -- asciidoctor-sail`, which loads
  rouge internally. Pinning rouge below 5 avoids the native build entirely;
  installing `ruby-dev` (needs root) is the other way out.

Install the gems for the current Ruby, no `sudo` needed:

```bash
gem install --user-install --no-document \
    asciidoctor asciidoctor-bibtex asciidoctor-diagram asciidoctor-lists \
    asciidoctor-pdf asciidoctor-sail asciidoctor-diagram-ditaamini \
    citeproc-ruby coderay csl-styles rghost
gem install --user-install --no-document rouge -v 4.5.2   # see the note above
npm install -g wavedrom-cli bytefield-svg                 # diagram CLIs
```

`npm install -g` needs a user-writable prefix; if it wants root, point it at
one with `npm config set prefix ~/.npm-global` and put `~/.npm-global/bin` on
`PATH`. `json` is not in the list: it is a default gem, and asking for it
explicitly triggers the same native build that rouge 5 does.

Put the gem bindir ahead of `/usr/local/bin`, then build:

```bash
export PATH="$(ruby -e 'print Gem.user_dir')/bin:$PATH"
make pdf SKIP_DOCKER=true
```

If it still fails, check which one you got — the shebang must name your current
Ruby:

```bash
head -1 "$(command -v asciidoctor-pdf)"    # => #!/usr/bin/ruby3.3
```

The system packages in `riscv-isa-manual/dependencies/apt_packages.txt` (cairo,
pango, gdk-pixbuf, graphviz, a JRE for wavedrom and ditaa, …) are needed too,
but on a desktop Debian/Ubuntu they are usually already present. Only if a gem
fails to build a native extension do you need:

```bash
sudo make install-deps
```

`make install-deps` installs those system packages, the Ruby gems from
`riscv-isa-manual/dependencies/Gemfile`, and the two extra gems
(`asciidoctor-sail`, `asciidoctor-diagram-ditaamini`) the PDF build needs but
which are not in that Gemfile. It requires root and installs the gems
system-wide, which is what created the stale-wrapper problem above — the
`--user-install` route avoids it.

Notes for recent Debian/Ubuntu:

- `apt_packages.txt` lists `libgdk-pixbuf2.0-dev`; it was renamed to
  `libgdk-pixbuf-2.0-dev` (usually already installed). The old `-xlib-` variant no
  longer exists and is not needed.
- Upstream dropped `asciidoctor-mathematical` from the build, so the
  `mathematical` gem — the one whose bundled CMake config predates CMake 4 and
  needed `CMAKE_POLICY_VERSION_MINIMUM=3.5` — is no longer required.
  `scripts/install-deps.sh` still exports that variable; it is now vestigial but
  harmless.

## Build — the Spike simulator

`riscv-isa-sim` is a pristine upstream Spike checkout; `scripts/apply-spike-patch.sh`
layers the Zvknhk instruction onto it, exactly as `apply-patch.sh` does for the
manual. `make spike` runs the patch, configures once, and builds:

```bash
make spike           # -> riscv-isa-sim/build/spike
make patch-spike     # apply the patch only
make spike-clean     # remove riscv-isa-sim/build
```

The build needs a C++20 compiler, Boost (`libboost-dev`, regex + system),
`device-tree-compiler` and `libriscv`-style autotools — the same dependencies
as upstream Spike; see its README. `make spike` builds with `-j$(nproc)`;
override with `NPROC=`.

The patch adds one extension, `zvknhk`, which gates the instruction. Enable it in
the ISA string:

```bash
riscv-isa-sim/build/spike --isa=rv64gcv_zvl256b_zvknhk_zicntr_zihpm pk <binary>
```

Per `zvknhk.adoc`, `Zvknhk` depends on `Zve64x` and needs `VLEN >= 128`, so
the registration declares both as implied and `--isa=rv64i_zvknhk` pulls them
in rather than being accepted as a vector-less string. An explicitly requested
`zvl` still wins, since the implied `zvl128b` only raises `VLEN`. Note this
makes `zvknhk` stricter than upstream's other `zvk*` extensions, which declare
no implications.

### What the patch does

`spike/vkeccak_vi.h` is the instruction semantics and the thing to edit. The
rest is glue that the script inserts into five upstream files: the `EXT_ZVKNHK`
extension id, the `"zvknhk"` ISA-string name, the `MATCH`/`MASK` encoding and
its `DECLARE_INSN`, a `riscv_insn_ext_zvknhk` build-system entry, and the
disassembler entry.

Because `zvknhk.adoc` defines the state as a single fixed element group that is
not strip-mined, the implementation needs neither the Zvk element-group loop
macros nor a new element-group type. `riscv/vector_unit.h`,
`riscv/zvk_ext_macros.h` and `riscv/zvkned_ext_macros.h` are therefore left
untouched, which keeps the footprint on upstream small.

If you change *what* the script inserts, reset the simulator sources first —
each site is guarded by a token that only the patch introduces, so an
already-patched file is skipped and would keep the old insertion:

```bash
make unpatch-spike && make spike
```

### Conformance to the specification

The implementation follows `zvknhk.adoc` rather than the original fork, which
predates the current spec text and differs from it in several ways: it treated
`imm5` as a literal round count, strip-mined the permutation across `vl`, and
placed the fixed encoding field at `0b10001` instead of `0b10010`. What the
patched simulator now implements:

- the state is one fixed element group designated by `vd`, with
  `EMUL=NREG=ceil(EGW/VLEN)`, independent of `vl` and `LMUL`;
- `imm5` is a selector — `0` gives 24 rounds, `1` gives 12 rounds using
  `RC[12..23]`, and every other value is reserved;
- `SEW != 64`, `vm=0`, a nonzero `vstart`, a reserved `imm5` and a misaligned
  `vd` all raise an illegal-instruction exception;
- elements 25..31 and all bits outside the fixed group are preserved.

Each insertion is anchored on a nearby upstream line and guarded by a token
that only this patch introduces, so the script is idempotent and re-runs
cleanly. It deliberately does **not** use a unified diff: the change originated
on the `dev-keccak` branch of a Spike fork, forked from upstream at `55b4658d`
(2026-06-25), and two of its nine hunks already fail to apply against upstream
two months later because they insert lines into long, churning lists. If an
anchor ever disappears, the script fails loudly naming the file — update the
anchor rather than force the patch.

## Build — QEMU

`qemu-src` is a pristine upstream QEMU checkout, and
`scripts/apply-qemu-patch.sh` layers the Zvknhk instruction onto it in exactly
the same anchor-based way as the Spike patch. `make qemu` runs the patch,
configures once, and builds:

```bash
make qemu            # -> qemu-src/build/qemu-riscv64
                     #    qemu-src/build/qemu-system-riscv64
make patch-qemu      # apply the patch only
make unpatch-qemu    # restore qemu-src to pristine upstream
make qemu-clean      # remove qemu-src/build
```

Two targets are built: `riscv64-linux-user`, which runs RISC-V Linux binaries
directly — static and dynamically linked alike, no proxy kernel — and
`riscv64-softmmu` for full-system emulation. Override `QEMU_TARGETS` to build
just one. The build needs QEMU's own dependencies (a C compiler, Python, Ninja,
glib); it bootstraps Meson itself into a private venv.

Because `zvknhk` implies `zve64x`, it is enough on its own in the CPU string:

```bash
qemu-src/build/qemu-riscv64 -cpu rv64,zvknhk=true,vlen=256 test/xtest
```

**[`qemu/README.md`](qemu/README.md) is the writeup of how the instruction is
wired in** — the two `.c.inc` files that hold it, the nine insertion sites, why
none of QEMU's strip-mining scaffolding applies to a fixed element group, and
where each reserved encoding is enforced.

Note that QEMU caps VLEN at `RV_VLEN_MAX`, currently 1024, so the `VLEN >= 2048`
row of the specification's table cannot be exercised there; Spike has no such
cap.

## Build — OpenSSL

The third target is not a simulator but a consumer. `demo/openssl` is a
pristine upstream OpenSSL checkout, and `scripts/apply-openssl-patch.sh` layers
a `vkeccak.vi` Keccak backend onto it in the same anchor-based way as the other
two patches. `make openssl` runs the patch, configures once, and cross-builds:

```bash
make openssl            # -> demo/openssl/build/apps/openssl
make patch-openssl      # apply the patch only
make unpatch-openssl    # restore demo/openssl to pristine upstream
make openssl-clean      # remove demo/openssl/build
```

It is a two-line patch: a `ZVKNHK` capability bit in the RISC-V capability
table, and one `#include` in `crypto/sha/keccak1600.c` that redirects
`KeccakF1600()`. Hooking the permutation rather than the digest provider is
what makes it two lines instead of a rewrite — and it is what puts the
instruction under SHA-3, SHAKE, KMAC, ML-KEM, ML-DSA and SLH-DSA at once, in
both the default and the FIPS provider.

Zvknhk is not an upstream extension, so the kernel has no hwprobe bit for it.
OpenSSL's `OPENSSL_riscvcap` override is therefore how it is switched on, which
suits an emulator exactly:

```bash
OPENSSL_riscvcap=rv64gc_v_zvknhk \
    qemu-src/build/qemu-riscv64 -L $RISCV/sysroot \
    -cpu rv64,v=true,vlen=256,elen=64,zvknhk=true \
    demo/openssl/build/apps/openssl dgst -sha3-256 /dev/null
```

`_v_` needs its own underscore — OpenSSL's parser looks for a literal `_V`, and
without it `VLEN` reads back as 0 and the backend silently declines to the C
path.

**[`openssl/README.md`](openssl/README.md) is the writeup of how the instruction
is wired in** — the two insertion sites, why `KeccakF1600()` and not
`PROV_SHA3_METHOD`, how one `#include` redirects both call sites, and why the
vector clobbers are not optional.

The cross build needs the same `riscv64-unknown-linux-gnu` toolchain as `test/`.
It is configured `no-shared`, so `apps/openssl` carries OpenSSL statically;
libc is still dynamic, hence the `-L $RISCV/sysroot` above.

## Tests

`test/` holds the instruction test suite. It builds a static RISC-V binary and
runs it under the Spike built above. Both round counts the instruction defines
are covered:

| Suite | `imm5` | Rounds | Vectors from |
|---|---|---|---|
| SHA-3, SHAKE128/256 | `0` | 24 | FIPS 202 |
| TurboSHAKE128/256 | `1` | 12 | RFC 9861 §5 (`misc/rfc9861.txt`) |

Each suite also checks the bare permutation on its own, so a failure in the
instruction is distinguishable from one in the sponge padding. 39 vectors in
total.

```bash
make test            # builds spike if needed, then builds and runs the tests
make test-all        # the same, at every VLEN the spec tabulates (128..2048)
```

The same suite runs under QEMU instead of Spike, plus a full-system smoke test
that boots with no proxy kernel and no firmware:

```bash
make test-qemu       # the suite under user-mode QEMU
make test-qemu-all   # at every VLEN QEMU supports (128..1024)
make boot-qemu       # system-mode: boot test/system/ on qemu-system-riscv64
make boot-qemu-all   # the same, at every VLEN QEMU supports
make -C test run-qemu-dyn   # a dynamically linked build of the same suite
```

`demo/` checks the same instruction from the other end — through OpenSSL,
where nothing knows it exists:

```bash
make test-openssl      # sixteen checks at VLEN=256
make test-openssl-all  # at every VLEN QEMU supports (128..1024)
make -C demo count      # instructions removed per operation (emulator)
make -C demo cycles     # rdcycle/rdinstret, best of N runs -- run on the target
make -C demo cycles-qemu # the same code path under QEMU (host ticks, not cycles)
```

Those are SHA-3 and SHAKE known answers with the capability on and off — the
SHAKE vectors run to 200 bytes, past the rate, because shorter output never
reaches the permutation in `SHA3_squeeze()` — an ML-KEM-768 and an ML-DSA-65
round trip, a fingerprint comparison that cross-checks both backends over the
whole PQC path, and a negative test that runs the same binary with the same
`OPENSSL_riscvcap` against a QEMU CPU *without* `zvknhk` and requires exit
status 132 (SIGILL). Without that last one a passing suite would prove nothing:
falling back to the C code produces identical digests.

The fixed element group spans `NREG = ceil(2048/VLEN)` registers, so both its
extent and the set of legal `vd` change with `VLEN`. The tests are built for
the smallest supported `VLEN` and run unmodified at 128, 256, 512, 1024 and
2048; see [`test/README.md`](test/README.md) for how.

It needs a `riscv64-unknown-linux-gnu` toolchain and `$RISCV` pointing at its
install prefix (the proxy kernel `pk` is taken from
`$RISCV/riscv64-unknown-linux-gnu/bin/pk`). Both the simulator and the proxy
kernel can be overridden:

```bash
make -C test run SPIKE=/path/to/spike PK=/path/to/pk
```

Expected output ends with every vector passing:

```
[PASS]	SHA3-256 64537B87892835FF0963EF9AD5145AB4CFCE5D303A0CB0415B3B03F9D16E7D6B
...
[PASS]	TurboSHAKE128 1E415F1C5983AFF2169217277D17BB538CD945A397DDEC541F1CE41AF2C1B74C
...
[INFO] fail= 0
```

`test/Makefile` defaults `SPIKE` and `PK` to this repo's build rather than
whatever is on `PATH`, and selects the runtime `VLEN`.

## Build times

The manual's PDF render is single-threaded Ruby, so there is no way to
parallelise a single document — measured on a 20-core machine:

| Build | Time |
|---|---|
| PDF only | 307 s |
| PDF only, warm diagram cache | 270 s |
| PDF + HTML, serial | 414 s |
| PDF + HTML, `make -j2` | 315 s |

Two things actually help. Building the PDF and HTML concurrently is a real win,
since they are separate processes; the top-level Makefile currently serialises
them with `.NOTPARALLEL:`. And `UNRELIABLE_BUT_FASTER_INCREMENTAL_BUILDS=1`
keeps the per-target work directory (and with it the asciidoctor-diagram cache)
instead of deleting it after each build, which is worth about 12% on a rebuild:

```bash
UNRELIABLE_BUT_FASTER_INCREMENTAL_BUILDS=1 make pdf SKIP_DOCKER=true
```

Spike, by contrast, parallelises well: a from-scratch build is ~80 s at
`-j20`.

## Cleaning

```bash
make clean         # remove build artifacts (riscv-isa-manual/build)
make force-clean   # same, but also removes artifacts left owned by root
```

Docker builds run as your UID (`--user $(id -u)`), so artifacts are normally
yours and `make clean` just works. If a build ever leaves root-owned files under
`build/` (e.g. one run without `--user`, or a mis-mounted run that drops stray
`build/ src/ docs-resources/ normative_rule_defs/` dirs at the repo root),
`make force-clean` deletes them from inside the container (which runs as root) —
no `sudo` needed.

## Updating the upstream manual

The `riscv-isa-manual` submodule points at pristine upstream. To move to a newer
upstream revision, first drop the patched-in files so the checkout isn't blocked
by the dirty work tree, then switch and re-pin:

```bash
cd riscv-isa-manual
git remote -v                                # confirm: riscv/riscv-isa-manual
git checkout -- src/unpriv/crypto.adoc       # revert the include line
rm -f src/unpriv/zvknhk.adoc                 # drop the copied-in chapter
git fetch origin
git checkout <new-commit-or-tag>             # e.g. origin/main for the latest
git submodule update --init --recursive      # sync docs-resources
cd ..
git add riscv-isa-manual                     # record the new pinned commit
make pdf SKIP_DOCKER=false                   # re-applies the patch and builds
```

Keep the submodule on `riscv/riscv-isa-manual`. If it is repointed at a fork and
pinned to a fork-only commit, `git clone --recurse-submodules` breaks for
everyone else: the URL in `.gitmodules` still resolves to upstream, where that
commit does not exist.

`scripts/apply-patch.sh` hardcodes the source paths and the anchor line it
inserts after (`src/unpriv/crypto.adoc`, after `include::zvk.adoc[]`). If a
future upstream reorganization moves either, the script fails loudly — update the
variables at the top of it.

## Project Structure

- **`zvknhk.adoc`** -- the Zvknhk (Vector Keccak) extension chapter: the reason this
  repo exists and the single source of truth for the spec
- **`spike/vkeccak_vi.h`** -- the instruction's reference semantics for Spike;
  the source of truth for the simulator, edit it here
- `test/` -- instruction tests: SHA-3 / SHAKE (24 rounds) and TurboSHAKE
  (12 rounds) known-answer vectors
- `riscv-spec.pdf` -- a checked-in render of the manual with the chapter
  included, so it can be read without building it. Copied by hand from
  `riscv-isa-manual/build/`, so it lags the sources until someone refreshes it
- `misc/rfc9861.txt` -- RFC 9861, the source of the TurboSHAKE test vectors
- `scripts/apply-patch.sh` -- Layers `zvknhk.adoc` onto the upstream manual sources
- `scripts/apply-spike-patch.sh` -- Layers the Zvknhk instruction onto the
  upstream Spike sources
- **`qemu/`** -- the instruction's reference semantics for QEMU, and
  [`qemu/README.md`](qemu/README.md), the writeup of how it is wired in
- `test/system/` -- a full-system smoke test booted on qemu-system-riscv64
- `scripts/apply-qemu-patch.sh` -- Layers the Zvknhk instruction onto the
  upstream QEMU sources
- **`openssl/`** -- the Keccak backend for OpenSSL, and
  [`openssl/README.md`](openssl/README.md), the writeup of how it is wired in
- `demo/` -- checks that OpenSSL's SHA-3, ML-KEM and ML-DSA really run on the
  instruction, including a negative test that proves the fallback isn't hiding.
  `pqcbench.c` drives one operation at a time for measurement, and `count.sh`
  counts instructions under QEMU with the per-permutation figures calibrated on
  each run rather than hardcoded
- `scripts/apply-openssl-patch.sh` -- Layers the Zvknhk Keccak backend onto the
  upstream OpenSSL sources
- `riscv-isa-manual/` -- Pristine upstream RISC-V ISA manual (submodule; itself
  has a `docs-resources` submodule)
- `riscv-isa-sim/` -- Pristine upstream Spike / RISC-V ISA simulator (submodule)
- `qemu-src/` -- Pristine upstream QEMU (submodule)
- `demo/openssl/` -- Pristine upstream OpenSSL (submodule)
- `scripts/` -- Helper scripts for dependency installation and Docker builds
