# Booting the Kernel

When a computer is powered on, the CPU initializes itself and starts executing the OS. The OS then initializes the hardware and starts the applications. This process is called **booting**.

But what happens *before* the OS starts?

- On a PC, the **BIOS** (or **UEFI** on modern machines) initializes the hardware, shows the splash screen, and loads the OS from disk.
- On the QEMU `virt` machine, **OpenSBI** plays the same role.

---

## Supervisor Binary Interface (SBI)

The **Supervisor Binary Interface (SBI)** is an API between an OS kernel and the firmware running below it — it defines what services the firmware (e.g. OpenSBI) provides to the kernel.

A well-known SBI implementation is [**OpenSBI**](https://github.com/riscv-software-src/opensbi). QEMU launches OpenSBI by default; it performs hardware-specific initialization and then boots the kernel.

---

## Example boot output

Running the launch script:

```console
❯ ./run.sh
+ QEMU=qemu-system-riscv32
+ qemu-system-riscv32 -machine virt -bios default -nographic -serial mon:stdio --no-reboot

OpenSBI v1.7
   ____                    _____ ____ _____
  / __ \                  / ____|  _ \_   _|
 | |  | |_ __   ___ _ __ | (___ | |_) || |
 | |  | | '_ \ / _ \ '_ \ \___ \|  _ < | |
 | |__| | |_) |  __/ | | |____) | |_) || |_
  \____/| .__/ \___|_| |_|_____/|____/_____|
        | |
        |_|

Platform Name               : riscv-virtio,qemu
Platform Features           : medeleg
Platform HART Count         : 1
Platform IPI Device         : aclint-mswi
Platform Timer Device       : aclint-mtimer @ 10000000Hz
Platform Console Device     : uart8250
Platform HSM Device         : ---
Platform PMU Device         : ---
Platform Reboot Device      : syscon-reboot
Platform Shutdown Device    : syscon-poweroff
Platform Suspend Device     : ---
Platform CPPC Device        : ---
Firmware Base               : 0x80000000
Firmware Size               : 313 KB
Firmware RW Offset          : 0x40000
Firmware RW Size            : 57 KB
Firmware Heap Offset        : 0x45000
Firmware Heap Size          : 37 KB (total), 2 KB (reserved), 10 KB (used), 24 KB (free)
Firmware Scratch Size       : 4096 B (total), 1340 B (used), 2756 B (free)
Runtime SBI Version         : 3.0
Standard SBI Extensions     : time,rfnc,ipi,base,hsm,srst,pmu,dbcn,fwft,legacy,dbtr,sse
Experimental SBI Extensions : none

Domain0 Name                : root
Domain0 Boot HART           : 0
Domain0 HARTs               : 0*
Domain0 Region00            : 0x00100000-0x00100fff M: (I,R,W) S/U: (R,W)
Domain0 Region01            : 0x10000000-0x10000fff M: (I,R,W) S/U: (R,W)
Domain0 Region02            : 0x02000000-0x0200ffff M: (I,R,W) S/U: ()
Domain0 Region03            : 0x80040000-0x8004ffff M: (R,W) S/U: ()
Domain0 Region04            : 0x80000000-0x8003ffff M: (R,X) S/U: ()
Domain0 Region05            : 0x0c400000-0x0c5fffff M: (I,R,W) S/U: (R,W)
Domain0 Region06            : 0x0c000000-0x0c3fffff M: (I,R,W) S/U: (R,W)
Domain0 Region07            : 0x00000000-0xffffffff M: () S/U: (R,W,X)
Domain0 Next Address        : 0x00000000
Domain0 Next Arg1           : 0x87e00000
Domain0 Next Mode           : S-mode
Domain0 SysReset            : yes
Domain0 SysSuspend          : yes

Boot HART ID                : 0
Boot HART Domain            : root
Boot HART Priv Version      : v1.12
Boot HART Base ISA          : rv32imafdch
Boot HART ISA Extensions    : sstc,zicntr,zihpm,zicboz,zicbom,sdtrig,svadu
Boot HART PMP Count         : 16
Boot HART PMP Granularity   : 2 bits
Boot HART PMP Address Bits  : 32
Boot HART MHPM Info         : 16 (0x0007fff8)
Boot HART Debug Triggers    : 2 triggers
Boot HART MIDELEG           : 0x00001666
Boot HART MEDELEG           : 0x00f4b509
```

---

## QEMU monitor shortcuts

Press <kbd>Ctrl</kbd>+<kbd>A</kbd> followed by a second key to send a command to QEMU itself (rather than the guest):

| Key chord                                            | Action                                          |
| ---------------------------------------------------- | ----------------------------------------------- |
| <kbd>Ctrl</kbd>+<kbd>A</kbd>, <kbd>H</kbd>           | Print this help                                 |
| <kbd>Ctrl</kbd>+<kbd>A</kbd>, <kbd>X</kbd>           | Exit the emulator immediately                   |
| <kbd>Ctrl</kbd>+<kbd>A</kbd>, <kbd>S</kbd>           | Save disk data back to file (if `-snapshot`)    |
| <kbd>Ctrl</kbd>+<kbd>A</kbd>, <kbd>T</kbd>           | Toggle console timestamps                       |
| <kbd>Ctrl</kbd>+<kbd>A</kbd>, <kbd>B</kbd>           | Send break (magic SysRq)                        |
| <kbd>Ctrl</kbd>+<kbd>A</kbd>, <kbd>C</kbd>           | Switch between console and monitor              |
| <kbd>Ctrl</kbd>+<kbd>A</kbd>, <kbd>Ctrl</kbd>+<kbd>A</kbd> | Send a literal `Ctrl-A` to the guest      |

> Note: <kbd>Ctrl</kbd>+<kbd>A</kbd>, <kbd>X</kbd> exits QEMU instantly with no confirmation — easy to hit by accident.

---

## Linker script

After the compiler turns each `.c` into a `.o`, the **linker** glues them into one executable. A **linker script** (`*.ld`) tells it where each piece of the program should live in memory.

For a normal Linux program the toolchain has a default script — you never see it. For a kernel we write our own, because there is no OS to set things up: we have to put the code at the exact address the firmware jumps to, and we have to reserve our own stack.

> Comments inside `.ld` files use only `/* ... */`. No `//`, no `#`.

### The whole file

```ld
ENTRY(boot)

SECTIONS {
    . = 0x80200000;

    .text : {
        KEEP(*(.text.boot));
        *(.text .text.*);
    }

    .rodata : ALIGN(4) { *(.rodata .rodata.*); }
    .data   : ALIGN(4) { *(.data   .data.*); }

    .bss : ALIGN(4) {
        __bss = .;
        *(.bss .bss.* .sbss .sbss.*);
        __bss_end = .;
    }

    . = ALIGN(4);
    . += 128 * 1024;        /* 128 KB stack */
    __stack_top = .;
}
```

That's it — under 20 lines. Let's walk through it.

### `ENTRY(boot)`

Says: *the program starts at the symbol called `boot`*. The linker stores that address in the ELF header, and OpenSBI jumps to it. The name is arbitrary — pick anything, as long as your asm/C defines a matching label.

### `. = 0x80200000`

The dot `.` is the **location counter**: a cursor that tracks the address where the next byte will be placed. Setting it to `0x80200000` tells the linker: "start laying out the kernel at this address".

Why this address? On QEMU `virt`:

- DRAM begins at `0x80000000`.
- OpenSBI loads itself there and uses the next 2 MB.
- When OpenSBI finishes setting up, it jumps to `0x80200000` — and that's where we need to be waiting.

You can confirm this in the boot log: look for the line `Domain0 Next Address : 0x80200000`. If your firmware uses a different address, change this number to match.

### `.text` — the code

```ld
.text : {
    KEEP(*(.text.boot));
    *(.text .text.*);
}
```

Reading right-to-left inside the braces:

- `*(.text)` means *"from every input file (`*`), grab the input section called `.text`"*.
- `.text.*` picks up per-function sections like `.text.kernel_main` that the compiler emits with `-ffunction-sections`.
- `.text.boot` is a special section name we'll use in our boot code (`__attribute__((section(".text.boot")))`). Putting it first guarantees the boot code lives at exactly `0x80200000`.
- `KEEP(...)` tells the linker: don't throw this away even with `--gc-sections`. Nothing in C calls `boot()` — it's reached by a CPU jump — so without `KEEP` the linker would think it's dead code.

### `.rodata` and `.data`

```ld
.rodata : ALIGN(4) { *(.rodata .rodata.*); }
.data   : ALIGN(4) { *(.data   .data.*); }
```

Two flavours of globals:

- **`.rodata`** — read-only data. String literals, `const` arrays, jump tables.
- **`.data`** — read-write data with an initial value: `int counter = 42;`. The value `42` is stored in the ELF and copied into RAM at boot.

`ALIGN(4)` rounds the location counter up to a multiple of 4 before starting the section. RISC-V's `lw` instruction needs a 4-byte-aligned address; without this, an oddly-sized `.text` could leave us unaligned.

### `.bss` — uninitialised data

```ld
.bss : ALIGN(4) {
    __bss = .;
    *(.bss .bss.* .sbss .sbss.*);
    __bss_end = .;
}
```

Globals/statics that start as zero: `int counter;`, `static char buf[1024];`. The C standard promises they're 0 at startup.

A neat trick: `.bss` takes **zero bytes in the ELF file**. Storing a thousand zeros would be wasteful, so the linker only records the *size*. The kernel has to zero this region itself at startup.

To do that, we save two symbols:

- `__bss = .;` — current address becomes the start.
- `__bss_end = .;` — after collecting all the input `.bss` sections, the current address is the end.

The boot code does the equivalent of:

```c
for (char *p = __bss; p < __bss_end; p++) *p = 0;
```

`.sbss` is RISC-V's "small bss" — an optimisation for tiny variables. For now, just think of it as more `.bss`.

### The stack

```ld
. = ALIGN(4);
. += 128 * 1024;
__stack_top = .;
```

There's no OS to give us a stack, so we carve one out of memory ourselves:

1. Round up to a 4-byte boundary.
2. Move the cursor forward by 128 KB — without writing anything. This *reserves* the space.
3. Record the address at the top of that space as `__stack_top`.

The stack on RISC-V grows **downward**, so the boot code loads `__stack_top` into `sp` and lets function calls grow into the reserved region:

```asm
la sp, __stack_top
```

128 KB is plenty for an early kernel. Bump the constant later if you run out.

### Tweaking it

Common things you might want to change:

| Goal                                  | Change                                                          |
| ------------------------------------- | --------------------------------------------------------------- |
| Different kernel base address         | The number in `. = 0x80200000;`.                                |
| Bigger/smaller stack                  | The `128 * 1024` constant.                                      |
| Page-align sections (needed for MMU)  | Replace `ALIGN(4)` with `ALIGN(4096)`.                          |
| Add a new section (e.g. `.eh_frame`)  | A new `.name : { *(.name .name.*); }` block.                    |
| Drop noise (`.comment`, `.note.*`)    | Add `/DISCARD/ : { *(.comment) *(.note.*) }` at the end.        |
| Multiple memory regions (ROM + RAM)   | Define a `MEMORY { … }` block, then suffix sections with `> region`. |

### Inspecting the result

After linking, the easiest way to *see* what the script did:

```sh
llvm-readelf -S kernel.elf      # list sections, addresses, sizes
llvm-objdump -d kernel.elf      # disassemble; first instruction should be at 0x80200000
llvm-nm kernel.elf | grep _     # look up symbols like __bss, __bss_end, __stack_top
```

### Where to read more

- **GNU `ld` manual** — full reference for the script language: <https://sourceware.org/binutils/docs/ld/Scripts.html>. Start with [Simple Example](https://sourceware.org/binutils/docs/ld/Simple-Example.html), then [Output Section Description](https://sourceware.org/binutils/docs/ld/Output-Section-Description.html) and [`MEMORY`](https://sourceware.org/binutils/docs/ld/MEMORY.html).
- **LLVM `lld` docs** — what `ld.lld` (the linker used here) accepts: <https://lld.llvm.org/ELF/linker_script.html>. It's a compatible subset of GNU `ld`.
- **Other kernels** to compare against:
  - [xv6-riscv `kernel.ld`](https://github.com/mit-pdos/xv6-riscv/blob/riscv/kernel/kernel.ld) — short and very readable.
  - [Linux `vmlinux.lds.S`](https://github.com/torvalds/linux/blob/master/arch/riscv/kernel/vmlinux.lds.S) — production-grade, useful once the basics click.


## Minimal kernel

Now that the linker script has decided *where* things live in memory, we need a tiny bit of C code to put *something* at those addresses. The minimal kernel does just three things:

1. Run at the entry address OpenSBI jumps to.
2. Set up a stack pointer.
3. Hand off to a regular C function and loop forever.

That's it — no drivers, no printing, no syscalls yet. Just enough to prove the boot path works.

### The whole file

```c
typedef unsigned char uint8_t;
typedef unsigned int  uint32_t;
typedef uint32_t      size_t;

extern char __bss[], __bss_end[], __stack_top[];

void *memset(void *buf, char c, size_t n) {
    uint8_t *p = (uint8_t *)buf;
    while (n--) *p++ = c;
    return buf;
}

void kernel_main() {
    memset(__bss, 0, (size_t)__bss_end - (size_t)__bss);
    for (;;) ;
}

__attribute__((section(".text.boot")))
__attribute__((naked))
void boot(void) {
    __asm__ __volatile__(
        "mv sp, %[stack_top]\n"
        "j kernel_main\n"
        :
        : [stack_top] "r"(__stack_top)
    );
}
```

That's the whole kernel for now. Let's walk through each piece.

### Typedefs — no libc

```c
typedef unsigned char uint8_t;
typedef unsigned int  uint32_t;
typedef uint32_t      size_t;
```

In a normal C program we'd `#include <stdint.h>` and get `uint8_t` and friends for free. But we're bare-metal: there is no standard library to include from. We're writing it. So we define the few types we need by hand.

The sizes assume rv32: `int` is 32 bits, `char` is 8 bits, `size_t` is 32 bits (the natural pointer/index size on a 32-bit machine).

### Linker symbols — the bridge to `kernel.ld`

```c
extern char __bss[], __bss_end[], __stack_top[];
```

These three names don't refer to anything declared in C. They come from the **linker script**. Look back at `kernel.ld`:

```ld
.bss : ALIGN(4) {
    __bss = .;
    *(.bss .bss.* .sbss .sbss.*);
    __bss_end = .;
}
. = ALIGN(4);
. += 128 * 1024;
__stack_top = .;
```

Each `name = .;` defines a symbol whose *value is an address* — the current value of the location counter at that point in the layout. The linker patches those addresses into the final ELF, and the C code can refer to them through `extern` declarations.

Why declare them as `char[]`? Because we only care about the **address**, not any value supposedly stored there. An array name decays to a pointer (`__bss` → `char *` pointing at the first byte of `.bss`), which is exactly what `memset` and pointer arithmetic want. Declaring `extern char __bss;` would also work but would force us to write `&__bss` every time.

### `memset` — also no libc

```c
void *memset(void *buf, char c, size_t n) {
    uint8_t *p = (uint8_t *)buf;
    while (n--) *p++ = c;
    return buf;
}
```

A byte-by-byte fill. We need it to zero out `.bss`. The signature matches the standard libc one so we could later swap in a faster implementation without touching callers.

### `kernel_main` — the C-level entry point

```c
void kernel_main() {
    memset(__bss, 0, (size_t)__bss_end - (size_t)__bss);
    for (;;) ;
}
```

By the time we reach `kernel_main`, the `boot` function below has already set up a valid stack. From here on we can write normal C — locals, function calls, everything.

The first job is to **zero the `.bss` region**. Why? The C standard promises that uninitialised globals start at 0. On a hosted system (Linux, macOS) the program loader fills `.bss` with zeros before `main` runs. On bare-metal there is no loader — the kernel image is dropped into RAM with `.bss` full of garbage. We satisfy the C contract ourselves, using the bounds the linker script gave us.

Then we spin forever. Returning from `kernel_main` would have nowhere to go: nothing called us (the boot code *jumped* in without saving a return address), so returning would pop a garbage value from `ra` and jump to who-knows-where.

### `boot` — the very first instruction

```c
__attribute__((section(".text.boot")))
__attribute__((naked))
void boot(void) {
    __asm__ __volatile__(
        "mv sp, %[stack_top]\n"
        "j kernel_main\n"
        :
        : [stack_top] "r"(__stack_top)
    );
}
```

This is what OpenSBI jumps to. Two attributes do most of the work.

**`__attribute__((section(".text.boot")))`** puts this function into a separate input section called `.text.boot`. Remember the linker script:

```ld
.text : {
    KEEP(*(.text.boot));    /* <-- our boot() lands here, FIRST */
    *(.text .text.*);
}
```

Because `.text.boot` is listed first inside `.text`, and `.text` is the very first section at `0x80200000`, the function `boot` ends up at exactly `0x80200000` — the address OpenSBI hands control to. `KEEP(...)` is what stops the linker from garbage-collecting it: no other C code calls `boot()`, so without `KEEP` the linker would think it's dead code.

**`__attribute__((naked))`** tells the compiler: *don't generate a prologue or epilogue*. A normal C function starts with code like `addi sp, sp, -16; sw ra, 12(sp)` to save registers on the stack. But at this point **there is no stack yet** — `sp` contains whatever OpenSBI left in it. Any prologue would crash. With `naked`, the body is *only* our inline assembly — nothing before, nothing after.

The body is two instructions:

| Instruction              | What it does                                                |
| ------------------------ | ----------------------------------------------------------- |
| `mv sp, %[stack_top]`    | Set the stack pointer to `__stack_top` (top of the 128 KB stack the linker reserved). Now C function calls have somewhere to put their frames. |
| `j kernel_main`          | Unconditional jump to `kernel_main`. We use `j`, not `jal`, because we never plan to return — there's no caller to return to. |

The constraint `[stack_top] "r"(__stack_top)` is GCC inline-asm syntax for: *"take the address `__stack_top`, put it into some general-purpose register the compiler picks, and substitute the register name wherever I wrote `%[stack_top]`"*. We don't care which register — the compiler decides.

### The handoff, end to end

Putting it all together, here's what happens when you run `./run.sh`:

```
QEMU launches qemu-system-riscv32
   │
   ▼
OpenSBI loads at 0x80000000, initialises hardware
   │
   ▼  jump to Domain0 Next Address = 0x80200000
boot()  (in .text.boot at 0x80200000)
   │   mv sp, __stack_top      ← sp now points at the top of our 128 KB stack
   ▼   j kernel_main
kernel_main()
   │   memset(__bss, 0, __bss_end - __bss)   ← C globals are now valid
   ▼
for (;;) ;                                   ← park forever
```

Three files cooperate to make that picture work:

- **`run.sh`** picks the right machine and firmware (`-machine virt -bios default`).
- **`kernel.ld`** decides where each section lives and exposes `__bss`, `__bss_end`, `__stack_top` as symbols.
- **`kernel.c`** consumes those symbols, sets up the stack, and starts running C code.

### Inspecting it

After building, you can confirm everything landed where it should:

```sh
llvm-readelf -h kernel.elf | grep Entry        # Entry point should be 0x80200000
llvm-objdump -d kernel.elf | head -20          # First disassembled instructions are boot's `mv` and `j`
llvm-nm kernel.elf | grep -E '__bss|__stack'   # See __bss, __bss_end, __stack_top with concrete addresses
```

If those line up, the boot path is wired correctly — anything else you build on top (printing, traps, syscalls) just adds code; the foundation is already in place.

---

## Build & run pipeline

So far we've looked at *what* the linker script lays out and *what* the C code does. The missing piece is the toolchain that turns source files into a running kernel. That's what `run.sh` automates.

### The big picture

```
  kernel.c ──┐
             │  clang (compiler driver)
  kernel.ld ─┤      ├── cc1: kernel.c → object code
             │      └── ld.lld: link with kernel.ld → kernel.elf
             │
             ▼
        kernel.elf  ──── qemu-system-riscv32 -kernel kernel.elf
                         │
                         ▼
                    OpenSBI (firmware) → boot() → kernel_main()
```

Two stages: **build** (host-side, produces `kernel.elf`) and **run** (QEMU loads the ELF and starts emulating).

### Stage 1: Build

The single line that does everything:

```sh
clang $CFLAGS -Wl,-Tkernel.ld -Wl,-Map=kernel.map -o kernel.elf kernel.c
```

Clang acts as a *driver*: it compiles `kernel.c` to an object file in memory, then invokes the linker (`ld.lld`) to combine that object with our linker script into a final ELF. The `-Wl,` prefix tells clang "pass this flag straight to the linker".

Why each flag matters (full per-flag explanations live in [`run.sh`](../run.sh) — short version here):

| Flag                              | Job                                                                        |
| --------------------------------- | -------------------------------------------------------------------------- |
| `--target=riscv32-unknown-elf`    | Cross-compile for 32-bit RISC-V (bare-metal ELF), not the host machine.    |
| `-ffreestanding -nostdlib`        | We're not a hosted program; don't assume or link libc or crt startup files.|
| `-fno-stack-protector`            | Disable stack canaries — they call into libc, which we don't have.         |
| `-fuse-ld=lld`                    | Use LLVM's linker, which understands our linker script.                    |
| `-Wl,-Tkernel.ld`                 | Use `kernel.ld` as the linker script (overrides ld's default).             |
| `-Wl,-Map=kernel.map`             | Emit a map file listing where every symbol landed — useful for debugging.  |
| `-O2 -g3 -Wall -Wextra`           | Standard "reasonably optimised, fully debuggable, complain about mistakes".|

The output is `kernel.elf` — an ELF binary whose entry point is `0x80200000` (set by `ENTRY(boot)` + `. = 0x80200000;` in the linker script).

### Stage 2: Run

```sh
qemu-system-riscv32 \
    -machine virt -bios default -nographic \
    -serial mon:stdio --no-reboot \
    -kernel kernel.elf
```

What each flag does:

| Flag                  | Job                                                                                 |
| --------------------- | ----------------------------------------------------------------------------------- |
| `-machine virt`       | Emulate the generic RISC-V `virt` board (the synthetic one QEMU ships for OS dev).  |
| `-bios default`       | Use QEMU's bundled OpenSBI as firmware.                                             |
| `-nographic`          | No graphical window; run entirely in the terminal.                                  |
| `-serial mon:stdio`   | Pipe the guest UART (and the QEMU monitor) through the host stdio.                  |
| `--no-reboot`         | If the guest tries to reboot, exit instead of looping.                              |
| `-kernel kernel.elf`  | **Load our ELF as the guest kernel and have OpenSBI jump into it.** (Key link!)     |

The crucial one is `-kernel kernel.elf`. QEMU parses the ELF, copies each loadable segment to the physical address the linker script asked for (so `.text` lands at `0x80200000`, and so on), and then arranges for OpenSBI to jump there in S-mode after firmware initialisation finishes. Without it, OpenSBI would boot, print its banner, and then have nowhere to go.

### How the three files connect

Each file does one job, and they meet up at well-known addresses and symbols:

| File         | Produces                                | Consumed by                                                                             |
| ------------ | --------------------------------------- | --------------------------------------------------------------------------------------- |
| `kernel.c`   | code & data, the `boot` symbol          | The linker (via clang) — turned into bytes inside `kernel.elf`.                          |
| `kernel.ld`  | section layout, `__bss`, `__bss_end`, `__stack_top` | The linker — controls where bytes go. The C code reads its symbols via `extern`. |
| `run.sh`     | the build command + QEMU command line   | You — `./run.sh` is the only thing you ever run by hand.                                |

If you change any one of these you usually have to think about the other two:

- Move the kernel base address in `kernel.ld`? Make sure OpenSBI's `Domain0 Next Address` still matches.
- Add a new section to `kernel.ld`? The linker will complain unless something puts data into it.
- Change `boot` to a different name? Update `ENTRY(...)` in `kernel.ld` to match.

### End-to-end timeline

```
./run.sh
   │
   ├─► clang --target=riscv32-unknown-elf ... -Wl,-Tkernel.ld ... kernel.c
   │       └── produces kernel.elf  (entry = 0x80200000)
   │
   └─► qemu-system-riscv32 -machine virt -bios default ... -kernel kernel.elf
           │
           ├── OpenSBI loads at 0x80000000, prints banner
           ├── OpenSBI copies kernel.elf segments to their target addresses
           ├── OpenSBI jumps to 0x80200000 in S-mode
           │
           └── boot()         (.text.boot, at 0x80200000)
                 │   mv sp, __stack_top
                 │   j kernel_main
                 ▼
               kernel_main()
                 │   memset(__bss, 0, __bss_end - __bss)
                 ▼
               for (;;) ;
```

Once this whole chain runs cleanly, you have a working bare-metal RISC-V kernel that does nothing — but is ready to do anything.
