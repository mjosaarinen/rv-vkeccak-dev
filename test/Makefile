#	Makefile -- Zvknhk (vkeccak.vi) instruction tests
#
#	Vendored from https://github.com/mjosaarinen/keccak-xrv (70ef711, 2026-06-11);
#	the unmodified original is kept alongside as Makefile.upstream. The only
#	changes here are to run against the Spike built from this repo's submodule
#	rather than whatever `spike` happens to be on PATH.

XBIN	=	xtest
CC		=	riscv64-unknown-linux-gnu-gcc
#RVKISA	=	rv64gcv_zbb_zvbb_zvbc_zvkg_zvkned_zvknhb_zvksed_zvksh_zvl256b
RVKISA	=	rv64gcv_zvl256b

#	Spike built by `make spike` in the repo root; override to use another build.
SPIKE	?=	../riscv-isa-sim/build/spike
#	The proxy kernel that the test binary runs under.
PK		?=	$(RISCV)/riscv64-unknown-linux-gnu/bin/pk

SPIKEFL	=	--isa=$(RVKISA)_zvkk_zicntr_zihpm
CFLAGS	=	-march=$(RVKISA) -mabi=lp64d -Wall
LDFLAGS	=	-static --sysroot=$(RISCV)/sysroot/usr
CSRC	= 	$(wildcard *.c)
SSRC	= 	$(wildcard *.s *.S)
OBJS	=	$(CSRC:.c=.o) $(SSRC:.s=.o)
LDLIBS	=

run:	$(XBIN)
	$(SPIKE) $(SPIKEFL) $(PK) $(XBIN)

$(XBIN): $(OBJS) Makefile
	$(CC) $(LDFLAGS) $(CFLAGS) -o $(XBIN) $(OBJS) $(LDLIBS)

%.o:	%.c
	$(CC) $(CFLAGS) -c $< -o $@

#	Cleanup
clean:
	$(RM) -f $(XBIN) $(OBJS)
