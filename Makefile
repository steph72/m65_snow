.DEFAULT_GOAL := generate
.PHONY: all hello generate

PRGNAME = m65snow.prg

SRCDIR = src
BINDIR = bin

CC = /home/stephan/kickc/bin/kickc.sh

all: hello generate test

hello:
	@echo "m65snow makefile"

generate: snow_65

clean:
	rm -rf ${BINDIR}/*

test:
	m65 ${BINDIR}/${PRGNAME}_wrapped -r -F -l /dev/ttyUSB1

emu:
	xemu-xmega65 -prg ${BINDIR}/${PRGNAME}_wrapped -besure

snow: src/m65snow.c
	${CC} src/m65snow.c -p mega65_c64 -a -o ../${BINDIR}/${PRGNAME}

snow_65: snow
	cat ./cbm/wrapper.prg ${BINDIR}/${PRGNAME} > ${BINDIR}/${PRGNAME}_wrapped