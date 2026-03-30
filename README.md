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

### 2. Install system packages

```bash
sudo apt-get update
sudo apt-get install -y \
    bison build-essential cmake curl flex fonts-lyx git graphviz \
    default-jre libcairo2-dev libffi-dev libgdk-pixbuf2.0-dev \
    libglib2.0-dev libpango1.0-dev libwebp-dev libxml2-dev \
    libzstd-dev make pkg-config ruby ruby-dev nodejs npm
```

### 3. Install Ruby gems

```bash
gem install bundler
cd riscv-isa-manual/dependencies && bundle install && cd ../..
gem install asciidoctor-sail asciidoctor-diagram-ditaamini
```

### 4. Install Node.js packages

```bash
sudo npm install -g wavedrom-cli bytefield-svg
```

### 5. Build

```bash
make pdf    # PDF output in riscv-isa-manual/build/riscv-spec.pdf
make html   # HTML output in riscv-isa-manual/build/riscv-spec.html
make clean  # remove build artifacts
```

## Build with Docker (alternative)

If you prefer Docker over installing dependencies natively:

```bash
make docker-pull
make pdf
```

## Project Structure

- `riscv-isa-manual/` -- Fork of the RISC-V ISA manual (submodule: `docs-resources`)
- `riscv-isa-manual/src/zvknhk.adoc` -- Zvknhk (Vector Keccak) extension chapter
- `riscv-isa-manual/src/unpriv.adoc` -- Unprivileged volume (includes `zvknhk.adoc`)
- `scripts/` -- Helper scripts for dependency installation and Docker builds
