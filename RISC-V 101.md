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

**Caller side:**

```asm
li  a0, 123          // Load immediate value 123 into a0 (1st argument)
jal ra, <label>      // Call function at <label>; save return address in ra
// After the function returns, execution continues here.
```

**Callee side — equivalent C:**

```c
int func(int a) {
    a += 1;     // increment the argument
    return a;   // return value goes back via a0
}
```

**Callee side — assembly:**

```asm
<label>:
    addi a0, a0, 1   // Increment a0 (1st argument) by 1
    ret              // Return to the caller; a0 holds the return value
```

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