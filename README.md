# os

## Notes

Study notes that go with this repo live in [`notes/`](./notes):

- [`notes/RISC-V 101.md`](./notes/RISC-V%20101.md) — primer on the 32-bit RISC-V ISA: assembly basics, registers, memory access, branches, function calls, and the stack.
- [`notes/INSTRUCTIONS.md`](./notes/INSTRUCTIONS.md) — concise reference of the RISC-V instructions used throughout the project, grouped by purpose (arithmetic, memory, branches, function calls, stack).
- [`notes/BOOT.md`](./notes/BOOT.md) — what happens before the kernel runs: OpenSBI / SBI, example QEMU boot output, monitor shortcuts, and the linker script.

## Later:
1. `lld` deepdive
2. `qemu` deepdive
3.  try `riscv64` instead of `riscv32`
4. what are the all instructions in `riscv32`? (see `llvm-objdump -d` output)
5. what are all the registers in `riscv32`? (see `llvm-objdump -d` output)

## Tools:
- `clang` - C compiler, needs support for 32-bit RISC-V CPU
- `lld` - LLVM linker, bundles compiled object files into an executable
- `llvm-objcopy` - Object file editor, comes with the `llvm` package
- `llvm-objdump` - A disassembler, comes with the `llvm` package
- `llvm-readelf` - An ELF file reader, comes with the `llvm` package
- `qemu-system-riscv32` - 32-bit RISC-V CPU emulator, it's part of `qemu` package
- [Compiler Explorer](https://godbolt.org) - useful tool for learning assembly, as I type C code it shows the corresponding assembly code. By default it uses x86-64 CPU assembly. Specify `RISC-V rv32gc clang (trunk)` in the right pane to output 32-bit RISC-V assembly.
    - also we can specify options like `-O0` (optimization off) or `-O2` (optimization on) to see how the assembly code changes.

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
## QEMU `virt` machine

Even though it does not exist in the real world, it's simple and very similar to real devices. I can emulate on it for free, no need to buy a physical hardware. When I encounter debugging issues, I can read QEMU's source code, or attach a debugger to the QEMU process to investigate what's wrong.

[QEMU documentation](https://www.qemu.org/docs/master/system/riscv/virt.html)

QEMU console: 
`Ctrl-A` then `c`; type `quit` to exit.


