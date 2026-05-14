# os

## Later:
1. `lld` deepdive
2. `qemu` deepdive
3. `riscv64` instead of `riscv32`

## Tools:
- `clang` - C compiler, needs support for 32-bit RISC-V CPU
- `lld` - LLVM linker, bundles compiled object files into an executable
- `llvm-objcopy` - Object file editor, comes with the `llvm` package
- `llvm-objdump` - A disassembler, comes with the `llvm` package
- `llvm-readelf` - An ELF file reader, comes with the `llvm` package
- `qemu-system-riscv32` - 32-bit RISC-V CPU emulator, it's part of `qemu` package

## Setup (macOS)

Apple's bundled `clang` does not include the `riscv32` target,
```
$ clang --print-targets
  Registered Targets:
    aarch64    - AArch64 (little endian)
    aarch64_32 - AArch64 (little endian ILP32)
    aarch64_be - AArch64 (big endian)
    arm        - ARM
    arm64      - ARM64 (little endian)
    arm64_32   - ARM64 (little endian ILP32)
    armeb      - ARM (big endian)
    thumb      - Thumb
    thumbeb    - Thumb (big endian)
    x86        - 32-bit X86: Pentium-Pro and above
    x86-64     - 64-bit X86: EM64T and AMD64
```

 so install Homebrew's LLVM (which is built with all targets) plus `lld` and `qemu`:

```sh
brew install llvm lld qemu
```

Verify the RISC-V target is available:

```sh
$(brew --prefix llvm)/bin/clang -print-targets | grep riscv
    riscv32     - 32-bit RISC-V
    riscv32be   - 32-bit big endian RISC-V
    riscv64     - 64-bit RISC-V
    riscv64be   - 64-bit big endian RISC-V
```

Use the Homebrew toolchain by full path in `run.sh` (don't shadow Apple's clang globally):

```sh
/opt/homebrew/opt/llvm/bin/clang        # Apple Silicon
/usr/local/opt/llvm/bin/clang           # Intel Mac
```

If a shell session needs `llvm-objcopy` etc. on PATH:

```sh
export PATH="$(brew --prefix llvm)/bin:$PATH"
```

## Running

```sh
./run.sh
```

QEMU console: `Ctrl-A` then `c`; type `quit` to exit.
