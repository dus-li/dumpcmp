# DUMPCMP

This is a simple helper utility that I hacked to debug one of my projects.

It reads a file with a description of a group of memory-mapped registers
(see: `examples/`) and then dumps it for two different implementations. After
that it compares the two results register-by-register and prints the
differences.

## Use scenario

Suppose you have two implementations of some embedded software. One works, the
other does not. You suspect the difference lies in some register state. You can
debug this by:

1. Connecting the board with first implementation.
2. Running `compare_regs.sh`
3. Flashing second implementation.
4. Pressing a key to get the script to continue.
5. Inspecting nicely formatted list of differences.

## Limitations

This script was written for use in STM32. It may be useful elsewhere, but may
require modification. In particular, it assumes, that the board has a hardware
debugger that is accessible as a GDB remote target.

## Requirements

- GDB
- xxd
- bash

## How it looks like

```
user@host$ ./compare_regs.sh STM32F302R8_GPIOA 
Please prepare the first implementation
Press any key to continue...
Please prepare the second implementation
Press any key to continue...
Value of OSPEEDR differs: 0x0c080000 vs 0x0c000000
Value of PUPDR differs:   0x64440000 vs 0x64040000
Value of IDR differs:     0x0000df0c vs 0x00009f0c
```
