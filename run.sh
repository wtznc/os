#!/bin/bash

# Shell options:
#   -x  Print each command before executing it (trace, useful for debugging).
#   -u  Treat unset variables as an error and exit immediately.
#   -e  Exit immediately if any command returns a non-zero status.
set -xue

# Path to the QEMU binary used to emulate a 32-bit RISC-V system.
# Installed via Homebrew's `qemu` package: `brew install qemu`.
QEMU=qemu-system-riscv32

# Path to the C compiler.
#
# We point at Homebrew's LLVM build of clang explicitly. Apple's bundled
# clang (the one in /usr/bin) does NOT include the riscv32 target, so it
# can't cross-compile our kernel. Homebrew's `llvm` package ships clang
# built with all targets enabled (see `clang -print-targets`).
#
# On Intel Macs this path would be /usr/local/opt/llvm/bin/clang.
CC=/opt/homebrew/opt/llvm/bin/clang

# Compiler + linker flags. Each one is here for a reason:
#
#   -std=c11
#       Use the C11 language standard. Gives us features like `_Static_assert`
#       and anonymous structs while staying portable.
#
#   -O2
#       Optimisation level 2. Good performance and small code, while still
#       producing debuggable output. -O0 would generate huge, slow binaries;
#       -O3 can rearrange code in ways that make stepping through it confusing.
#
#   -g3
#       Maximum debug info, including preprocessor macros. Lets gdb / lldb
#       show source lines and even expand macros while debugging.
#
#   -Wall -Wextra
#       Turn on the standard set of warnings, plus a useful extra set. Catches
#       a lot of mistakes (uninitialised vars, sign comparisons, unused params).
#
#   --target=riscv32-unknown-elf
#       Cross-compile for 32-bit RISC-V instead of the host (arm64/x86_64).
#       The "triple" is <arch>-<vendor>-<os>:
#         riscv32  — 32-bit RISC-V architecture.
#         unknown  — no specific vendor.
#         elf      — produce a bare-metal ELF binary (no OS, no syscalls).
#
#   -fuse-ld=lld
#       Use LLVM's linker (`ld.lld`) instead of the system linker. lld
#       understands GNU linker-script syntax and ships with the same LLVM
#       install as clang, so cross-linking just works.
#
#   -fno-stack-protector
#       Disable stack canaries. The protector would inject calls to
#       `__stack_chk_fail` on function entry/exit, but that symbol lives
#       in libc — which we don't link. Trying to use it would fail at link
#       time. Without an OS or libc, stack canaries can't be implemented.
#
#   -ffreestanding
#       Tell the compiler we're a "freestanding" program: no hosted
#       environment, no guarantees about libc, no `main()` semantics. This
#       disables compiler tricks like recognising printf-as-puts, prevents
#       it from inserting calls into libc helpers, etc.
#
#   -nostdlib
#       Don't link the standard library or the default startup files
#       (crt0/crt1/etc.). Our entry point is `boot()` as set by the linker
#       script — there is no _start from libc to pull in.
CFLAGS="-std=c11 -O2 -g3 -Wall -Wextra --target=riscv32-unknown-elf -fuse-ld=lld -fno-stack-protector -ffreestanding -nostdlib"

# Compile and link the kernel in one shot.
#
# clang acts as both the compiler driver AND the linker frontend here.
# Flags prefixed with `-Wl,` are passed straight through to the linker
# (ld.lld) instead of being interpreted by clang itself.
#
#   -Wl,-Tkernel.ld
#       Tell the linker: "use kernel.ld as the linker script". This is the
#       file that places `.text` at 0x80200000, reserves the stack, and
#       defines `__bss`, `__bss_end`, `__stack_top` (see notes/BOOT.md).
#       Without this flag the linker would use its default script and put
#       things wherever it pleased — almost certainly not where OpenSBI
#       expects to find us.
#
#   -Wl,-Map=kernel.map
#       Emit a "map file" describing exactly where every symbol and section
#       landed in the final ELF. Very handy for debugging layout problems
#       ("is my function really at the address I think it is?"). Open
#       kernel.map in any text editor after the build.
#
#   -o kernel.elf
#       Name of the output binary. ELF (Executable and Linkable Format) is
#       what QEMU's `-kernel` flag expects, and what gdb/objdump understand.
#
#   kernel.c
#       The single source file. As we add more files later they'll be
#       appended here (or moved into a Makefile).
$CC $CFLAGS -Wl,-Tkernel.ld -Wl,-Map=kernel.map -o kernel.elf kernel.c
# Start QEMU with the following flags:
#
#   -machine virt
#       Use the generic "virt" machine — a synthetic board QEMU exposes for
#       RISC-V. It does not exist in real hardware, but is simple and close
#       enough to real devices for OS development. See:
#       https://www.qemu.org/docs/master/system/riscv/virt.html
#
#   -bios default
#       Load QEMU's bundled default firmware (OpenSBI), which performs early
#       hardware init and then jumps to our kernel. Omitting this would leave
#       the machine without firmware; "default" is the recommended value.
#
#   -nographic
#       Disable the graphical display window. The emulator runs entirely in
#       the terminal — no VGA/SDL window pops up. Suitable for headless dev.
#
#   -serial mon:stdio
#       Connect the guest's serial port (UART) to the host terminal's stdio,
#       multiplexed with the QEMU monitor. This lets the kernel print to the
#       terminal and lets us drop into the monitor with `Ctrl-A` then `c`
#       (type `quit` there to exit QEMU).
#
#   --no-reboot
#       If the guest tries to reboot (e.g. after a panic or shutdown), exit
#       QEMU instead of restarting. Prevents reboot loops during development.
#
#   -kernel kernel.elf
#       Load our freshly-built ELF as the guest kernel. QEMU parses the ELF
#       headers, copies each loadable segment to the physical address the
#       linker script asked for (in our case `.text` at 0x80200000, and so
#       on), and arranges for OpenSBI to jump there in S-mode after firmware
#       initialisation finishes.
#
#       Without this flag, OpenSBI would boot, print its banner, and then
#       have nothing to hand control over to — you'd see the boot log and
#       then... silence. With `-kernel kernel.elf`, the chain becomes:
#       QEMU → OpenSBI → our `boot()` at 0x80200000 → `kernel_main()`.
$QEMU -machine virt -bios default -nographic -serial mon:stdio --no-reboot -kernel kernel.elf
