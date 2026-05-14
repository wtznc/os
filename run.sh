#!/bin/bash

# Shell options:
#   -x  Print each command before executing it (trace, useful for debugging).
#   -u  Treat unset variables as an error and exit immediately.
#   -e  Exit immediately if any command returns a non-zero status.
set -xue

# Path to the QEMU binary used to emulate a 32-bit RISC-V system.
# Installed via Homebrew's `qemu` package: `brew install qemu`.
QEMU=qemu-system-riscv32

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
$QEMU -machine virt -bios default -nographic -serial mon:stdio --no-reboot
