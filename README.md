# rv-vkeccak-dev

Development of RISC-V Vector Keccak extension (Zvknhk) specification,
based on the [riscv-isa-manual](https://github.com/riscv/riscv-isa-manual).

The upstream manual is included as a **pristine submodule** (pinned to a
specific upstream commit). Our only local change — the `zvknhk.adoc` chapter
and a one-line include in `unpriv.adoc` — lives in this repo and is layered on
top of the submodule at build time by `scripts/apply-patch.sh`. Nothing is
committed inside the submodule, so tracking upstream is just a matter of
bumping the pinned commit.

For information about Spike ISA emulation and basic tests for the Keccak
instruction, see [keccak-xrv](https://github.com/mjosaarinen/keccak-xrv).

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
`zvknhk.adoc` into the manual's `src/` and inserts the `include::zvknhk.adoc[]`
line into `src/unpriv.adoc`. The step is idempotent, so it is safe to re-run; you
can also apply the patch on its own with `make patch`.

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

## Editing the extension

`zvknhk.adoc` at the repo root is the source of truth for the chapter. Edit it
there, then rebuild — do **not** edit `riscv-isa-manual/src/zvknhk.adoc`, which
is an overwritten copy.

## Updating the upstream manual

The `riscv-isa-manual` submodule points at pristine upstream. To move to a newer
upstream revision:

```bash
cd riscv-isa-manual
git fetch origin
git checkout <new-commit-or-tag>
cd ..
git add riscv-isa-manual        # record the new pinned commit
```

If upstream reorders the `include::` lines in `src/unpriv.adoc`,
`scripts/apply-patch.sh` will report a missing anchor — update the `ANCHOR`
there to match.

## Project Structure

- `zvknhk.adoc` -- Zvknhk (Vector Keccak) extension chapter (**patch source of truth**)
- `scripts/apply-patch.sh` -- Layers `zvknhk.adoc` onto the upstream manual sources
- `riscv-isa-manual/` -- Pristine upstream RISC-V ISA manual (submodule; itself
  has a `docs-resources` submodule)
- `scripts/` -- Helper scripts for dependency installation and Docker builds
