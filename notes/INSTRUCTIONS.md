# RISC-V Instruction Reference

A concise reference of the RISC-V instructions used throughout these notes, grouped by purpose.

---

## Arithmetic & immediates

### `addi` — add immediate

Adds a register and an immediate value, stores the result in a register.

```asm
addi a0, a1, 123   // a0 = a1 + 123
```

### `li` — load immediate

Loads an immediate constant directly into a register. (Pseudo-instruction.)

```asm
li a0, 123         // a0 = 123
```

---

## Memory access

### `lw` — load word

Reads a 32-bit word from memory into a register.

```asm
lw a0, (a1)        // a0 = *(uint32_t *)a1
```

### `sw` — store word

Writes a 32-bit word from a register into memory.

```asm
sw a0, (a1)        // *(uint32_t *)a1 = a0
```

---

## Branches

Branches change control flow based on a register comparison. Execution either jumps to `<label>` or falls through to the next instruction.

| Instruction | Taken when…           |
| ----------- | --------------------- |
| `beq`       | `rs1 == rs2`          |
| `bne`       | `rs1 != rs2`          |
| `blt`       | `rs1 <  rs2` (signed) |
| `bge`       | `rs1 >= rs2` (signed) |
| `bnez`      | `rs1 != 0`            |

```asm
beq  a0, a1, <label>   // branch if equal
bne  a0, a1, <label>   // branch if not equal
blt  a0, a1, <label>   // branch if less than
bge  a0, a1, <label>   // branch if greater than or equal
bnez a0,     <label>   // branch if not zero
```

A **label** marks a position in the code that a branch or jump can target:

```asm
<label>:
    // Execution continues here when the branch is taken.
```

---

## Function calls

### `jal` — jump and link

Jumps to `<label>` and stores the return address (the address of the next instruction) in `ra`.

```asm
jal ra, <label>    // ra = pc + 4; pc = <label>
```

### `ret` — return

Jumps back to the address stored in `ra`. Equivalent to `jalr x0, 0(ra)`.

```asm
ret                // pc = ra
```

### End-to-end example

Translating `int result = func(123);` where `func(a)` returns `a + 1`:

```asm
// caller
li  a0, 123          // a0 = 123          ← argument
jal ra, func         // call func; ra = return address
// a0 now holds the return value (124)

// callee
func:
    addi a0, a0, 1   // a0 += 1
    ret              // return; result already in a0
```

Convention: arguments go in `a0`–`a7`, return value comes back in `a0`, return address lives in `ra`.

---

## Stack operations

The stack grows downwards; `sp` points to its top. Push/pop are built from `addi` + `sw`/`lw`.

**Push:**

```asm
addi sp, sp, -4    // allocate 4 bytes
sw   a0, (sp)      // store a0 on the stack
```

**Pop:**

```asm
lw   a0, (sp)      // load top of stack into a0
addi sp, sp, 4     // deallocate 4 bytes
```
