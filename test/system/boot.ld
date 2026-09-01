/*  Minimal layout for the QEMU 'virt' machine: DRAM starts at 0x80000000,
 *  which is where -bios none -kernel puts us, in M-mode.  */
OUTPUT_ARCH(riscv)
ENTRY(_start)
SECTIONS {
  . = 0x80000000;
  .text   : { *(.text.init) *(.text*) }
  .rodata : { *(.rodata*) }
  .data   : { *(.data*) }
  .bss ALIGN(64) : { *(.bss*) *(COMMON) }
  . = ALIGN(64); . += 0x10000; _stack_top = .;
}
