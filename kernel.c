/*
 * Basic integer typedefs.
 *
 * In a "normal" program we'd write `#include <stdint.h>` to get `uint8_t`,
 * `uint32_t`, etc. But we're bare-metal — there is no standard library to
 * include from. So we define the types ourselves.
 *
 * These sizes assume rv32 (32-bit RISC-V): `int` is 32 bits, `char` is 8.
 * `size_t` is whatever can hold an array index / object size — on rv32
 * that's 32 bits.
 */
typedef unsigned char uint8_t;
typedef unsigned int  uint32_t;
typedef uint32_t      size_t;

/*
 * Symbols defined by the linker script (kernel.ld), not by any C code:
 *
 *   __bss       — first byte of the .bss section (zero-initialized data).
 *   __bss_end   — first byte AFTER .bss.
 *   __stack_top — top (highest address) of the 128 KB stack region.
 *
 * In kernel.ld these appear inside SECTIONS, e.g.
 *
 *     .bss : ALIGN(4) {
 *         __bss = .;
 *         *(.bss .bss.* .sbss .sbss.*);
 *         __bss_end = .;
 *     }
 *     ...
 *     __stack_top = .;
 *
 * Why declare them as `char[]`? Because we only care about their ADDRESSES,
 * not any value stored "in" them. Declaring an array makes `__bss` decay
 * into a `char *` pointing to that address — perfect for `memset()` and
 * pointer arithmetic. Declaring them as `extern char __bss;` would also
 * work, but then we'd have to write `&__bss` every time.
 */
extern char __bss[], __bss_end[], __stack_top[];

/*
 * memset — set the first `n` bytes of `buf` to byte `c`.
 *
 * Standard libc function, but again we have no libc, so we write our own.
 * The loop walks one byte at a time; not the fastest possible version, but
 * the simplest and easiest to trust. We'll use it to zero out .bss below.
 */
void *memset(void *buf, char c, size_t n)
{
    uint8_t *p = (uint8_t *)buf;
    while (n--)
    {
        *p++ = c;
    }
    return buf;
}

/*
 * kernel_main — the "C-level" entry point.
 *
 * By the time we get here, the boot code below has already set up a valid
 * stack pointer, so it's safe to call C functions, use local variables,
 * etc. From here on we can pretend we're writing a normal C program.
 *
 * First job: zero out the .bss region. The C standard says uninitialised
 * globals must start at 0, but in bare-metal nobody else does this for us
 * (on Linux the program loader would). The linker script gave us `__bss`
 * and `__bss_end` exactly so we can compute the size and clear it.
 *
 * After that we have nothing to do yet, so we spin forever. Returning
 * from kernel_main would have nowhere to go — there's no caller — and
 * would likely jump into garbage.
 */
void kernel_main()
{
    // Zero the .bss section: from __bss up to (but not including) __bss_end.
    memset(__bss, 0, (size_t)__bss_end - (size_t)__bss);

    // Park here. Real kernels do real work; ours just doesn't exit.
    for (;;)
        ;
}

/*
 * boot — the very first instruction the CPU executes in our kernel.
 *
 * Two compiler attributes do most of the heavy lifting:
 *
 *   __attribute__((section(".text.boot")))
 *       Place this function into a separate input section named
 *       `.text.boot`. The linker script does:
 *
 *           .text : {
 *               KEEP(*(.text.boot));   <-- this function lands here
 *               *(.text .text.*);
 *           }
 *
 *       Because `.text.boot` is listed FIRST inside `.text`, this function
 *       sits at the very beginning of the kernel image — i.e. at the load
 *       address 0x80200000 (the value we set with `. = 0x80200000;`).
 *       That's exactly where OpenSBI jumps to, so the CPU starts here.
 *
 *       `KEEP(...)` in the linker script prevents this function from being
 *       garbage-collected by `--gc-sections`. Nothing in our C code calls
 *       `boot()` — the firmware reaches it through a CPU jump — so without
 *       KEEP the linker would think it's unused and drop it.
 *
 *   __attribute__((naked))
 *       Don't generate a prologue/epilogue. A normal C function starts
 *       with code that saves registers and sets up a stack frame — but
 *       at this point there is NO stack yet (we haven't set `sp`). Any
 *       prologue would crash. With `naked`, the function body is ONLY
 *       the inline assembly we write — nothing else.
 *
 * The body itself is two instructions:
 *
 *   mv sp, %[stack_top]
 *       Copy the address `__stack_top` (provided by the linker script)
 *       into the stack pointer register `sp`. From this moment on the
 *       CPU has a stack, and we can safely call regular C functions.
 *
 *   j kernel_main
 *       Unconditional jump to kernel_main. We don't use `jal` because we
 *       don't intend to come back here — kernel_main never returns.
 *
 * The constraint `[stack_top] "r"(__stack_top)` tells the compiler:
 * "put the address of __stack_top into some general-purpose register,
 *  then substitute that register name wherever I wrote %[stack_top]".
 * We don't care which register — the compiler picks one.
 */
__attribute__((section(".text.boot")))
__attribute__((naked)) void
boot(void)
{
    __asm__ __volatile__(
        "mv sp, %[stack_top]\n" // sp = __stack_top (top of the 128 KB stack)
        "j kernel_main\n"       // jump into the C entry point
        :
        : [stack_top] "r"(__stack_top) // input: address of the stack top
    );
}
