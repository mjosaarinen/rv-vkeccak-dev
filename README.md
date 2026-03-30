# rv-vkeccak-dev

Development of RISC-V Vector Keccak extension (Zvknhk) specification,
based on the [riscv-isa-manual](https://github.com/riscv/riscv-isa-manual).

For information about Spike ISA emulation and basic tests for the Keccak
instruction, see [keccak-xrv](https://github.com/mjosaarinen/keccak-xrv).

## Build Setup (Ubuntu 24.04)

### 1. Clone with submodules

```bash
git clone --recurse-submodules <repo-url>
cd rv-vkeccak-dev
```

If already cloned without submodules:

```bash
cd riscv-isa-manual && git submodule update --init --recursive && cd ..
```

### 2. Install dependencies

The quickest path (requires `sudo`):

```bash
sudo make install-deps
```

This reads system packages from `riscv-isa-manual/dependencies/apt_packages.txt`
and Ruby gems from `riscv-isa-manual/dependencies/Gemfile`. You also need
`libgdk-pixbuf-xlib-2.0-dev` and a few extras not covered by the upstream Gemfile:

```bash
sudo apt-get install -y libgdk-pixbuf-xlib-2.0-dev nodejs npm
gem install asciidoctor-sail asciidoctor-diagram-ditaamini
sudo npm install -g wavedrom-cli bytefield-svg
```

### 3. Build

```bash
make pdf    # PDF  -> riscv-isa-manual/build/riscv-spec.pdf
make html   # HTML -> riscv-isa-manual/build/riscv-spec.html
make clean
```

To build with Docker instead of native dependencies:

```bash
make docker-pull
make pdf SKIP_DOCKER=false
```

## Project Structure

- `riscv-isa-manual/` -- Fork of the RISC-V ISA manual (submodule: `docs-resources`)
- `riscv-isa-manual/src/zvknhk.adoc` -- Zvknhk (Vector Keccak) extension chapter
- `riscv-isa-manual/src/unpriv.adoc` -- Unprivileged volume (includes `zvknhk.adoc`)
- `scripts/` -- Helper scripts for dependency installation and Docker builds
