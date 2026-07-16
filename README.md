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

Either way, `make pdf`/`make html` run `make patch` first, which copies
`zvknhk.adoc` into the manual's `src/unpriv/` and adds an `include::` for it to
`src/unpriv/crypto.adoc` (right after the Vector Cryptography section). The step
is idempotent, so it is safe to re-run; you can also apply the patch on its own
with `make patch`.

## Build — Docker (recommended)

The RISC-V manual builds reproducibly inside the official docs container, which
pins a known-good toolchain. This is the recommended path — the native toolchain
on current Debian is broken (see below).

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

Native builds avoid Docker but are **not reliable on current Debian**: the distro
ships `asciidoctor-pdf` 2.3.x with `prawn` 2.5.0, an incompatible pair that
crashes while rendering the running headers
(`valign must be one of :left, :right or :center`). Prefer Docker unless you can
pin a matching `asciidoctor-pdf`/`prawn` set yourself.

Install dependencies (requires `sudo`):

```bash
sudo make install-deps
sudo npm install -g wavedrom-cli bytefield-svg   # diagram CLIs
```

`make install-deps` installs the system packages from
`riscv-isa-manual/dependencies/apt_packages.txt`, the Ruby gems from
`riscv-isa-manual/dependencies/Gemfile`, and the two extra gems
(`asciidoctor-sail`, `asciidoctor-diagram-ditaamini`) the PDF build needs but
which are not in that Gemfile.

To install the gems without `sudo` instead:

```bash
CMAKE_POLICY_VERSION_MINIMUM=3.5 gem install --user-install \
    asciidoctor-bibtex asciidoctor-diagram asciidoctor-lists \
    mathematical asciidoctor-mathematical asciidoctor-sail \
    asciidoctor-diagram-ditaamini
```

Then force a native build (Docker is auto-preferred whenever the `docker` binary
is present, so pass `SKIP_DOCKER=true` to opt out):

```bash
make pdf SKIP_DOCKER=true
```

Notes for recent Debian/Ubuntu:

- `apt_packages.txt` lists `libgdk-pixbuf2.0-dev`; it was renamed to
  `libgdk-pixbuf-2.0-dev` (usually already installed). The old `-xlib-` variant no
  longer exists and is not needed.
- The `mathematical` gem builds a bundled native library whose CMake config
  predates CMake 4; `CMAKE_POLICY_VERSION_MINIMUM=3.5` lets it configure. Both
  `make install-deps` and the command above set this.

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
git checkout -- src/unpriv/crypto.adoc       # revert the include line
rm -f src/unpriv/zvknhk.adoc                 # drop the copied-in chapter
git fetch origin
git checkout <new-commit-or-tag>             # e.g. origin/main for the latest
git submodule update --init --recursive      # sync docs-resources
cd ..
git add riscv-isa-manual                     # record the new pinned commit
make pdf SKIP_DOCKER=false                   # re-applies the patch and builds
```

`scripts/apply-patch.sh` hardcodes the source paths and the anchor line it
inserts after (`src/unpriv/crypto.adoc`, after `include::zvk.adoc[]`).

Note: Upstream was migrated into `src/unpriv/` + `modules/` around mid-2026.

## Project Structure

- **`zvknhk.adoc`** -- the Zvknhk (Vector Keccak) extension chapter: the reason this
  repo exists and the single source of truth for the spec
- `scripts/apply-patch.sh` -- Layers `zvknhk.adoc` onto the upstream manual sources
- `riscv-isa-manual/` -- Pristine upstream RISC-V ISA manual (submodule; itself
  has a `docs-resources` submodule)
- `scripts/` -- Helper scripts for dependency installation and Docker builds
