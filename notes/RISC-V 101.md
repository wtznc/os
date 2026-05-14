# RISC-V 101 — Notes

Operating systems hide the differences between CPUs. An OS is a program which controls the CPU to provide an abstraction layer for applications.

**RISC-V** is our target CPU:

- Specification: <https://riscv.org/specifications/ratified/>
- A trending Instruction Set Architecture (ISA), along with x86 and ARM.

We're writing an OS for **32-bit RISC-V**. The RISC-V ISA *defines the instructions that the CPU can execute* — similar to how a language specification defines a programming language. When I write a C program, the compiler translates it into RISC-V assembly.

---

## Assembly language basics

Assembly language is a (mostly) direct representation of machine code. Typically, each line of assembly corresponds to one machine instruction.

```asm
addi a0, a1, 123
```

- The first column (`addi`) is the instruction name, also known as the **opcode**.
- The following columns (`a0`, `a1`, `123`) are the instruction's **operands**.

This instruction adds the value in register `a1` to the immediate value `123` and stores the result in register `a0`. It is encoded as a 32-bit binary number that the CPU can execute directly.

---

## Registers

Registers are like temporary variables inside the CPU — they are *much* faster than memory. The CPU reads data from memory into registers, performs arithmetic on registers, and writes the results back to memory or registers.

| Register  | Alias    | Description                                                          |
| --------- | -------- | -------------------------------------------------------------------- |
| `pc`      | `pc`     | Program Counter — holds the address of the next instruction          |
| `x0`      | `zero`   | Always zero; writes to it are ignored                                |
| `x1`      | `ra`     | Return Address — holds the return address for function calls        |
| `x2`      | `sp`     | Stack Pointer — points to the top of the stack                       |
| `x3`      | `gp`     | Global Pointer — points to the middle of the 64KB global area        |
| `x4`      | `tp`     | Thread Pointer — points to thread-local storage                      |
| `x5`–`x7` | `t0`–`t2`| Temporary registers, used for intermediate values                    |
| `x8`      | `fp`     | Frame Pointer — points to the base of the current stack frame        |
| `x9`      | `s1`     | Saved register, callee-saved                                         |
| `x10`–`x11` | `a0`–`a1` | Function arguments and return values                              |
| `x12`–`x17` | `a2`–`a7` | Function arguments                                                |
| `x18`–`x27` | `s0`–`s11`| Saved registers, preserved across function calls                  |
| `x28`–`x31` | `t3`–`t6` | Temporary registers, used for intermediate values                 |

> In principle, I can use CPU registers however I like. For interoperability with other software, however, register usage is well defined — this is the [**calling convention**](https://riscv.org/wp-content/uploads/2024/12/riscv-calling.pdf). See the spec for details.

---

## Memory access

Registers are fast but limited in number. Most data lives in memory, and programs read/write it using `lw` (load word) and `sw` (store word).

**Load word — memory → register:**

```asm
lw a0, (a1)   // Read a 32-bit word from the address in `a1`
              // and store it in register `a0`.
```

**Store word — register → memory:**

```asm
sw a0, (a1)   // Write the 32-bit value in register `a0` to
              // the address pointed to by `a1`.
```

Think of `(...)` as a pointer dereference in C. Here, `a1` is a pointer to a 32-bit value.

---

## Branch instructions

Branch instructions change the control flow of the program. They are used to implement `if`, `for`, and `while` statements in C.

```asm
bnez a0, <label>   // Go to <label> if a0 is not zero.
                   // Otherwise, fall through to the next instruction.

<label>:
    // Execution lands here when a0 != 0.
```

`bnez` stands for **"branch if not equal to zero"**. Other common branch instructions:

| Instruction | Meaning                          |
| ----------- | -------------------------------- |
| `beq`       | branch if equal                  |
| `bne`       | branch if not equal              |
| `blt`       | branch if less than              |
| `bge`       | branch if greater than or equal  |

They are similar to `goto` in C, but with conditions.

---

## Function calls

The `jal` (jump and link) and `ret` (return) instructions implement function calls and returns:

- `jal` — saves the return address in the `ra` register and jumps to the function's address.
- `ret` — jumps back to the address stored in `ra`.

### Walk-through

To see how this hangs together, let's translate a small C program into RISC-V.

**1. The C program** — a function that adds 1 to its argument, called with `123`:

```c
int func(int a) {
    a += 1;
    return a;
}

// somewhere in main:
int result = func(123);
```

**2. The call site (caller)** — places `123` in `a0`, calls `func`, then continues:

```asm
li  a0, 123          // a0 = 123     ← function argument
jal ra, func         // ra = pc+4; jump to `func`
// ── after `ret`, execution resumes here, with a0 = return value ──
```

**3. The function body (callee)** — receives its argument in `a0`, returns its result in the same register:

```asm
func:
    addi a0, a0, 1   // a0 += 1       ← body of the function
    ret              // jump back to ra  ← return value already in a0
```

### How the pieces connect

| C                   | Assembly                                      | Role                                       |
| ------------------- | --------------------------------------------- | ------------------------------------------ |
| `func(123)`         | `li a0, 123` + `jal ra, func`                 | Pass argument, then call.                  |
| `int a` (parameter) | `a0` on entry to `func`                       | 1st argument lives in `a0`.                |
| `a += 1`            | `addi a0, a0, 1`                              | Mutates the argument in place.             |
| `return a`          | `ret` (with `a0` already holding the result)  | Return value travels back in `a0`.         |
| `int result = …`    | `a0` immediately after `jal`                  | Caller reads the return value from `a0`.   |

---

## Stack

The **stack** is a Last-In-First-Out (LIFO) data structure (and region of memory) used for function calls and local variables. It grows *downwards* — towards lower addresses — and the stack pointer (`sp`) always points to the top of the stack.

**Push — save a value onto the stack:**

Decrement the stack pointer, then store the value.

```asm
addi sp, sp, -4   // Move sp down by 4 bytes — stack allocation
sw   a0, (sp)     // Push the value in a0 onto the stack
```

**Pop — load a value from the stack:**

Load the value, then increment the stack pointer.

```asm
lw   a0, (sp)     // Pop the top of the stack into a0
addi sp, sp, 4    // Move sp up by 4 bytes — deallocation
```

> In C, stack operations are emitted by the compiler, so I don't have to write them by hand. Even so, understanding how the stack works matters when writing assembly or debugging.

## CPU modes
CPU has multiple modes of operation, each with different privileges and capabilities. In RISC-V, the main modes are:
-- insert table with Mode and Overview columns
| Mode   | Overview                                                                 |
| ------ | ------------------------------------------------------------------------ |
| U-Mode (User)   | Least privileged mode, where applications run. Cannot execute privileged instructions or access certain memory regions. |
| S-Mode (Supervisor) | Intermediate privilege level, typically used for OS kernels. Can execute privileged instructions and manage memory, but still has some restrictions compared to Machine mode. |
| M-Mode (Machine) | Most privileged mode, used for low-level hardware control and bootstrapping. Can execute all instructions and access all memory. |

## Privileged instructions
Among CPU instructions, there are types called privileged instructions that applications (user mode) cannot execute. These instructions are reserved for the OS kernel (supervisor mode) or hardware control (machine mode). Examples include:
-- insert table with Opcode and operands, Overview and Pseudocode columns
| Opcode | Operands | Overview | Pseudocode |
| ------ | -------- | -------- | ---------- |
| `csrr` | `rd, csr` | Read from a control and status register (CSR) into a general-purpose register. | `rd = csr` |
| `csrw` | `csr, rs` | Write a value from a general-purpose register into a control and status register (CSR). | `csr = rs` | 
| `csrrw` | `rd, csr, rs` | Atomically read a CSR into a register and write a new value from another register. | `temp = csr; csr = rs; rd = temp;` |
| `sret` |  | Return from supervisor mode to user mode. | `if (current_mode == S-Mode) { current_mode = U-Mode; }` |
| `sfence.vma` | `rs1, rs2` | Flush the virtual memory area (VMA) for a specific address range. | `flush_vma(rs1, rs2)` |

>CSR (Control and Status Register) is a special register that stores CPU settings. The list of CSRs can be found in [RISC-V Privileged Specification](https://riscv.org/specifications/privileged-isa/)

> Some instructions like `sret` do somewhat complex operations. To understand what actually happens, reading RISC-V emulator source code might be helpful. Particularly, [rvemu](https://github.com/d0iasm/rvemu) is written in a intuitive and easy-to-understand way (e.g. [sret implementation](https://github.com/d0iasm/rvemu/blob/f55eb5b376f22a73c0cf2630848c03f8d5c93922/src/cpu.rs#L3357-L3400))

## Inline assembly

In this project, there will be some cases where I need to write assembly code directly in C files. This is called **inline assembly** and looks like this:

```c
uint32_t value;
__asm__ __volatile__("csrr %0, sepc" : "=r"(value));
```
Using inline assembly is generally preferred because:
- you can use C variables within the assembly. Also you can assign the results of assembly to C variables
- You can leave register allocation to the C compiler. You don't have to manually write the preservation and restoration of registers to be modified in the assembly. 

## How to write inline assembly

Inline assembly is written in the following format:

```c
__asm__ __volatile__(
    "assembly": output operands : input operands : clobbered registers
);
```
--insert table with Part and Description columns
| Part | Description |
| ---- | ----------- |
| `__asm__` | Indicates that this is an assembly block. |
| `__volatile__` | Tells the compiler not to optimize or reorder this assembly block. This is important for instructions that have side effects or depend on specific timing. |
| `assembly` | The actual assembly code as a string. It can contain placeholders for operands. |
| output operands | A list of C variables that will receive values from the assembly code. Each operand is specified as `"constraint"(variable)`. |
| input operands | A list of C variables that will be used as inputs to the assembly code |. Each operand is specified as `"constraint"(variable)`. |
| clobbered registers | A list of registers that the assembly code modifies, so the compiler knows they are not preserved. |

Output and input operands and comma-separated, and each operand is written in the format `constraint (C expression)`. Constraints are used to specify the type of operand, and usually `=r` (register) for output operands, and `r` for input operands.

Output and input operands can be accessed in the assembly using `%0`, `%1`, `%2`, etc. in order starting from the output operands.

## Examples
```c
// Example 1: Read the value of the `sepc` CSR into a C variable
uint32_t value;
__asm__ __volatile__("csrr %0, sepc" : "=r"(value));
```
In this example, the `csrr` instruction reads the value of the `sepc` CSR and stores it in the C variable `value`. The `=r` constraint indicates that `value` should be stored in a register. The `%0` in the assembly code corresponds to the first output operand, which is `value`.


```c
// Example 2: Write a value from a C variable into the `sscratch` CSR
uint32_t value = 123;
__asm__ __volatile__("csrw sscratch, %0" : /* output operands are empty */ : "r"(value));
```
This writes the value `123` from the C variable `value` into the `sscratch` CSR, using the `csrw` instruction. `%0` corresponds to the register containing `value`, which is specified as an input operand with the `r` constraint.

```asm
li a0, 123          // Load immediate value 123 into a0 (1st argument)
csrw sscratch, a0  // Write the value in a0 into the sscratch CSR
``` 

Although only the `csrw` instruction is written in the inline assembly, the `li` instruction is automatically inserted by the compiler to satisfy the `"r"` constraint (value in register).