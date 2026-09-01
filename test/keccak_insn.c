//  keccak_insn.c
//  Markku-Juhani O. Saarinen <mjos@iki.fi>. Credit: Nicolas Brunie.
//  === Single-instruction Keccak-f1600

//  The assembler does not know `vkeccak.vi` yet, so the instruction is emitted
//  with `.insn`. Only two of the five R-type fields are real operands; see
//  the Encoding section of zvknhk.adoc:
//
//      rd  = vd    -- the vector register holding the 1600-bit state
//      rs1 = x18   -- NOT an operand: 0b10010 is a fixed part of the opcode
//      rs2 = imm5  -- the round-count selector: 0 -> 24 rounds, 1 -> 12 rounds
//
//  The state is one fixed element group of EGW=2048 bits designated by vd,
//  independent of vl and LMUL, so vl only has to be large enough for the
//  surrounding vle64/vse64 of the 25 active state words.

//  The two permutations differ only in imm5, which must be an encoded
//  register number in the rs2 field, hence the macro rather than a parameter.

#define KECCAK_INSN(name, imm5)                                     \
void name(void *state)                                              \
{                                                                   \
    __asm volatile (                                                \
        "vsetivli x0, 25, e64, m8, tu, mu\n"                        \
        "vle64.v v8, 0(%[state])\n"                                 \
        /*  vkeccak.vi v8, imm5                                  */  \
        /*  .insn r opc, func3, func7, rd, rs1, rs2              */  \
        ".insn r 0x77, 0x2, 0x53, x8, x18, " imm5 "\n"              \
        "vse64.v v8, 0(%[state])\n"                                 \
        :                                                           \
        : [state]"r"(state)                                         \
        : "memory"                                                  \
    );                                                              \
}

//  Keccak-p[1600,24] = Keccak-f[1600]; used by SHA-3 and SHAKE.
KECCAK_INSN(keccak_f1600, "x0")

//  Keccak-p[1600,12]; used by TurboSHAKE and KangarooTwelve. Uses round
//  constants RC[12..23], which the instruction selects on its own.
KECCAK_INSN(keccak_p1600_12, "x1")
