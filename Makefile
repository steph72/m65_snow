.DEFAULT_GOAL := generate
.PHONY: all hello generate

PRGNAME = m65snow.prg

SRCDIR = src
BINDIR = bin

CC = /home/stephan/kickc/bin/kickc.sh

all: hello generate

hello:
	@echo "m65snow makefile"

generate: snow

clean:
	rm -rf ${BINDIR}/*

test:
	m65 ${BINDIR}/${PRGNAME} -r -F -l /dev/ttyUSB1

emu:
	xemu-xmega65 -prg ${BINDIR}/${PRGNAME} -besure

snow: src/m65snow.c
	${CC} src/m65snow.c -p mega65 -a -o ../${BINDIR}/${PRGNAME}

