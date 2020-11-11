// Functions for performing input and output.
.cpu _45gs02
  // MEGA65 platform PRG executable starting in MEGA65 mode.
.file [name="m65snow.prg", type="prg", segments="Program"]
.segmentdef Program [segments="Basic, Code, Data"]
.segmentdef Basic [start=$2001]
.segmentdef Code [start=$2017]
.segmentdef Data [startAfter="Code"]
.segment Basic
.byte $0a, $20, $0a, $00, $fe, $02, $20, $30, $00       // 10 BANK 0
.byte $15, $20, $14, $00, $9e, $20                      // 20 SYS 
.text toIntString(__start)                                   //         NNNN
.byte $00, $00, $00                                     // 
  // DMA command copy
  .const DMA_COMMAND_COPY = 0
  // Map 2nd KB of colour RAM $DC00-$DFFF (hiding CIA's)
  .const CRAM2K = 1
  .const LIGHT_BLUE = $e
  // keyboard scanner
  .const width = $50
  .const height = $19
  .const size = width*height
  .const OFFSET_STRUCT_F018_DMAGIC_EN018B = 3
  .const OFFSET_STRUCT_DMA_LIST_F018B_COUNT = 1
  .const OFFSET_STRUCT_DMA_LIST_F018B_SRC = 3
  .const OFFSET_STRUCT_DMA_LIST_F018B_DEST = 6
  .const OFFSET_STRUCT_F018_DMAGIC_ADDRMB = 4
  .const OFFSET_STRUCT_F018_DMAGIC_ADDRBANK = 2
  .const OFFSET_STRUCT_F018_DMAGIC_ADDRMSB = 1
  .const OFFSET_STRUCT_MEGA65_VICIV_KEY = $2f
  .const OFFSET_STRUCT_MOS4569_VICIII_RASTER = $12
  // I/O Personality selection
  .label IO_KEY = $d02f
  // C65 Banking Register
  .label IO_BANK = $d030
  // Processor port data direction register
  .label PROCPORT_DDR = 0
  // The VIC III MOS 4567/4569
  .label VICIII = $d000
  // The VIC IV
  .label VICIV = $d000
  // DMAgic F018 Controller
  .label DMA = $d700
  // Color Ram
  .label COLORRAM = $d800
  // Default address of screen character matrix
  .label DEFAULT_SCREEN = $800
  // Top of the heap used by malloc()
  .label HEAP_TOP = $a000
  .label flakes = malloc.return
  // The random state variable
  .label rand_state = $c
  // The random state variable
  .label rand_state_1 = 4
.segment Code
__start: {
    jsr conio_mega65_init
    jsr main
    rts
}
// Enable 2K Color ROM
conio_mega65_init: {
    // Disable BASIC/KERNAL interrupts
    sei
    // Map memory to BANK 0 : 0x00XXXX - giving access to I/O
    lda #0
    tax
    tay
    taz
    map
    eom
    // Enable the VIC 4
    lda #$47
    sta IO_KEY
    lda #$53
    sta IO_KEY
    // Enable 2K Color RAM
    lda #CRAM2K
    ora IO_BANK
    sta IO_BANK
    rts
}
main: {
    .label __7 = 6
    jsr mega65_io_enable
    jsr initFlakes
    jsr bordercolor
    jsr bgcolor
    jsr clrscr
    jsr screenToCanvas
  __b1:
    jsr doFlakes
    jsr rand
    lda #$7f
    and.z __7
    cmp #$64+1
    bcc __b3
    jsr addFlake
  __b3:
    ldz #0
  __b2:
    cpz #$14
    bcc __b4
    jsr canvasToScreen
    jmp __b1
  __b4:
    lda #0
    cmp VICIII+OFFSET_STRUCT_MOS4569_VICIII_RASTER
    bne __b4
    inz
    jmp __b2
}
mega65_io_enable: {
    lda #$47
    sta VICIV+OFFSET_STRUCT_MEGA65_VICIV_KEY
    lda #$53
    sta VICIV+OFFSET_STRUCT_MEGA65_VICIV_KEY
    lda #$40
    sta PROCPORT_DDR
    rts
}
initFlakes: {
    .label __5 = 6
    .label __21 = 8
    .label __22 = $a
    .label __23 = $15
    .label __24 = $13
    .label i = 2
    jsr malloc
    lda #<1
    sta.z rand_state_1
    lda #>1
    sta.z rand_state_1+1
    sta.z i
  __b1:
    lda.z i
    cmp #$32
    bcc __b2
    rts
  __b2:
    lda.z i
    asl
    asl
    clc
    adc.z i
    tax
    lda #$ff
    sta flakes,x
    txa
    clc
    adc #<flakes
    sta.z __21
    lda #>flakes
    adc #0
    sta.z __21+1
    lda #$ff
    ldy #1
    sta (__21),y
    txa
    clc
    adc #<flakes
    sta.z __22
    lda #>flakes
    adc #0
    sta.z __22+1
    lda #3
    taz
    tya
    sta.z (__22),z
    jsr rand
    lda #$f
    and.z __5
    cmp #8+1
    bcs __b3
    lda.z i
    asl
    asl
    clc
    adc.z i
    clc
    adc #<flakes
    sta.z __24
    lda #>flakes
    adc #0
    sta.z __24+1
    lda #2
    taz
    lda #-1
    sta.z (__24),z
  __b4:
    inc.z i
    jmp __b1
  __b3:
    lda.z i
    asl
    asl
    clc
    adc.z i
    clc
    adc #<flakes
    sta.z __23
    lda #>flakes
    adc #0
    sta.z __23+1
    lda #2
    taz
    lda #1
    sta.z (__23),z
    jmp __b4
}
// Set the color for the border. The old color setting is returned.
bordercolor: {
    .const color = 0
    // The border color register address
    .label CONIO_BORDERCOLOR = $d020
    lda #color
    sta CONIO_BORDERCOLOR
    rts
}
// Set the color for the background. The old color setting is returned.
bgcolor: {
    .const color = 0
    // The background color register address
    .label CONIO_BGCOLOR = $d021
    lda #color
    sta CONIO_BGCOLOR
    rts
}
// clears the screen and moves the cursor to the upper left-hand corner of the screen.
clrscr: {
    .label line_text = 6
    .label line_cols = 8
    lda #<COLORRAM
    sta.z line_cols
    lda #>COLORRAM
    sta.z line_cols+1
    lda #<DEFAULT_SCREEN
    sta.z line_text
    lda #>DEFAULT_SCREEN
    sta.z line_text+1
    ldx #0
  __b1:
    cpx #$19
    bcc __b4
    rts
  __b4:
    ldz #0
  __b2:
    cpz #$50
    bcc __b3
    lda #$50
    clc
    adc.z line_text
    sta.z line_text
    bcc !+
    inc.z line_text+1
  !:
    lda #$50
    clc
    adc.z line_cols
    sta.z line_cols
    bcc !+
    inc.z line_cols+1
  !:
    inx
    jmp __b1
  __b3:
    lda #' '
    sta.z (line_text),z
    lda #LIGHT_BLUE
    sta.z (line_cols),z
    inz
    jmp __b2
}
screenToCanvas: {
    lda #<canvas
    sta.z memcpy_dma.dest
    lda #>canvas
    sta.z memcpy_dma.dest+1
    lda #<DEFAULT_SCREEN
    sta.z memcpy_dma.src
    lda #>DEFAULT_SCREEN
    sta.z memcpy_dma.src+1
    jsr memcpy_dma
    rts
}
doFlakes: {
    .label current = 8
    .label i = 3
    lda #0
    sta.z i
  __b1:
    lda.z i
    cmp #$32
    bcc __b2
    rts
  __b2:
    lda.z i
    asl
    asl
    clc
    adc.z i
    clc
    adc #<flakes
    sta.z current
    lda #>flakes
    adc #0
    sta.z current+1
    ldy #3
    lda (current),y
    tax
    cpx #0
    bne __b3
    ldx.z i
    dec currentCount,x
    ldy.z i
    lda currentCount,y
    cmp #0
    bne __b3
    lda delay,y
    sta currentCount,y
    ldy #0
    lda (current),y
    tax
    ldy #1
    lda (current),y
    taz
    ldy #$20
    jsr setCanvas
    lda.z current
    sta.z doFlake.aFlake
    lda.z current+1
    sta.z doFlake.aFlake+1
    jsr doFlake
    cmp #0
    bne __b6
    jmp __b3
  __b6:
    ldy #0
    lda (current),y
    tax
    ldy #1
    lda (current),y
    taz
    ldy #4
    lda (current),y
    tay
    jsr setCanvas
  __b3:
    inc.z i
    jmp __b1
}
// Returns a pseudo-random number in the range of 0 to RAND_MAX (65535)
// Uses an xorshift pseudorandom number generator that hits all different values
// Information https://en.wikipedia.org/wiki/Xorshift
// Source http://www.retroprogramming.com/2017/07/xorshift-pseudorandom-numbers-in-z80.html
rand: {
    .label __0 = $17
    .label __1 = $10
    .label __2 = $15
    .label return = 6
    lda.z rand_state_1+1
    lsr
    lda.z rand_state_1
    ror
    sta.z __0+1
    lda #0
    ror
    sta.z __0
    lda.z rand_state_1
    eor.z __0
    sta.z rand_state
    lda.z rand_state_1+1
    eor.z __0+1
    sta.z rand_state+1
    lsr
    sta.z __1
    lda #0
    sta.z __1+1
    lda.z rand_state
    eor.z __1
    sta.z rand_state
    lda.z rand_state+1
    eor.z __1+1
    sta.z rand_state+1
    lda.z rand_state
    sta.z __2+1
    lda #0
    sta.z __2
    lda.z rand_state
    eor.z __2
    sta.z rand_state_1
    lda.z rand_state+1
    eor.z __2+1
    sta.z rand_state_1+1
    lda.z rand_state_1
    sta.z return
    lda.z rand_state_1+1
    sta.z return+1
    rts
}
addFlake: {
    .label __3 = 6
    .label __5 = 6
    .label __6 = $f
    .label __7 = 6
    .label __10 = 6
    .label current = $13
    .label charIdx = $e
    ldx #0
  __b1:
    cpx #$32
    bcc __b2
    rts
  __b2:
    txa
    asl
    asl
    stx.z $ff
    clc
    adc.z $ff
    clc
    adc #<flakes
    sta.z current
    lda #>flakes
    adc #0
    sta.z current+1
    ldy #3
    lda (current),y
    cmp #0
    bne __b4
    inx
    jmp __b1
  __b4:
    jsr rand
    lda #3
    and.z __3
    sta.z charIdx
    jsr rand
    lda #$3f
    and.z __5
    sta.z __6
    jsr rand
    lda #$f
    and.z __7
    clc
    adc.z __6
    ldy #0
    sta (current),y
    tya
    ldy #1
    sta (current),y
    ldy.z charIdx
    lda flakeSymbols,y
    ldy #4
    sta (current),y
    lda #3
    taz
    lda #0
    sta.z (current),z
    jsr rand
    lda #3
    and.z __10
    clc
    adc #2
    sta delay,x
    lda delay,x
    sta currentCount,x
    rts
}
canvasToScreen: {
    lda #<DEFAULT_SCREEN
    sta.z memcpy_dma.dest
    lda #>DEFAULT_SCREEN
    sta.z memcpy_dma.dest+1
    lda #<canvas
    sta.z memcpy_dma.src
    lda #>canvas
    sta.z memcpy_dma.src+1
    jsr memcpy_dma
    rts
}
// Allocates a block of size chars of memory, returning a pointer to the beginning of the block.
// The content of the newly allocated block of memory is not initialized, remaining with indeterminate values.
malloc: {
    .const size = $32*5
    .label mem = HEAP_TOP-size
    .label return = mem
    rts
}
// Copy a memory block within the first 64K memory space using MEGA65 DMagic DMA
// Copies the values of num bytes from the location pointed to by source directly to the memory block pointed to by destination.
// - dest The destination address (within the MB and bank)
// - src The source address (within the MB and bank)
// - num The number of bytes to copy
// memcpy_dma(void* zp(8) dest, void* zp(6) src)
memcpy_dma: {
    .label src = 6
    .label dest = 8
    // Remember current F018 A/B mode
    ldx DMA+OFFSET_STRUCT_F018_DMAGIC_EN018B
    // Set up command
    lda #<size
    sta memcpy_dma_command+OFFSET_STRUCT_DMA_LIST_F018B_COUNT
    lda #>size
    sta memcpy_dma_command+OFFSET_STRUCT_DMA_LIST_F018B_COUNT+1
    lda.z src
    sta memcpy_dma_command+OFFSET_STRUCT_DMA_LIST_F018B_SRC
    lda.z src+1
    sta memcpy_dma_command+OFFSET_STRUCT_DMA_LIST_F018B_SRC+1
    lda.z dest
    sta memcpy_dma_command+OFFSET_STRUCT_DMA_LIST_F018B_DEST
    lda.z dest+1
    sta memcpy_dma_command+OFFSET_STRUCT_DMA_LIST_F018B_DEST+1
    // Set F018B mode
    lda #1
    sta DMA+OFFSET_STRUCT_F018_DMAGIC_EN018B
    // Set address of DMA list
    lda #0
    sta DMA+OFFSET_STRUCT_F018_DMAGIC_ADDRMB
    sta DMA+OFFSET_STRUCT_F018_DMAGIC_ADDRBANK
    lda #>memcpy_dma_command
    sta DMA+OFFSET_STRUCT_F018_DMAGIC_ADDRMSB
    // Trigger the DMA (without option lists)
    lda #<memcpy_dma_command
    sta DMA
    // Re-enable F018A mode
    stx DMA+OFFSET_STRUCT_F018_DMAGIC_EN018B
    rts
}
// setCanvas(byte register(X) x, byte register(Z) y, byte register(Y) s)
setCanvas: {
    .label __1 = $15
    .label __2 = $10
    .label adr = $15
    .label __3 = $15
    .label __4 = $17
    .label __5 = $15
    tza
    sta.z __1
    lda #0
    sta.z __1+1
    lda.z __1
    asl
    sta.z __4
    lda.z __1+1
    rol
    sta.z __4+1
    asl.z __4
    rol.z __4+1
    lda.z __5
    clc
    adc.z __4
    sta.z __5
    lda.z __5+1
    adc.z __4+1
    sta.z __5+1
    asw adr
    asw adr
    asw adr
    asw adr
    txa
    sta.z __2
    lda #0
    sta.z __2+1
    lda.z adr
    clc
    adc.z __2
    sta.z adr
    lda.z adr+1
    adc.z __2+1
    sta.z adr+1
    clc
    lda.z __3
    adc #<canvas
    sta.z __3
    lda.z __3+1
    adc #>canvas
    sta.z __3+1
    tya
    ldy #0
    sta (__3),y
    rts
}
// doFlake(struct $0* zp($a) aFlake)
doFlake: {
    .label __3 = 6
    .label __16 = 6
    .label __22 = 6
    .label newY = $12
    .label aFlake = $a
    ldy #1
    lda (aFlake),y
    cmp #height-1
    bcc __b1
    lda #3
    taz
    tya
    sta.z (aFlake),z
    lda #0
    rts
  __b1:
    ldy #0
    lda (aFlake),y
    taz
    ldy #1
    lda (aFlake),y
    inc
    sta.z newY
    jsr rand
    lda #$f
    and.z __3
    cmp #8
    bcc __b2
    jsr rand
    lda #$1f
    and.z __16
    cmp #$1c
    bcc __b11
    lda.z aFlake
    sta.z changeHorizontalDirection.aFlake
    lda.z aFlake+1
    sta.z changeHorizontalDirection.aFlake+1
    jsr changeHorizontalDirection
  __b11:
    ldy #0
    lda (aFlake),y
    ldy #2
    tax
    lda (aFlake),y
    stx.z $ff
    clc
    adc.z $ff
    taz
  __b2:
    cpz #width
    bcc __b3
    // flake exited on left or right side of screen
    lda #3
    taz
    lda #1
    sta.z (aFlake),z
    lda #0
    rts
  __b3:
    tza
    tax
    lda.z newY
    jsr canvasAt
    cmp #$a0
    bne __b4
    ldy #0
    lda (aFlake),y
    taz
  __b4:
    tza
    tax
    lda.z newY
    jsr canvasAt
    cmp #$a0
    bne __b5
    jsr rand
    lda #$f
    and.z __22
    cmp #8+1
    lda #3
    taz
    lda #1
    sta.z (aFlake),z
    lda #0
    rts
  __b5:
    tza
    ldy #0
    sta (aFlake),y
    lda.z newY
    ldy #1
    sta (aFlake),y
    tya
    rts
}
// changeHorizontalDirection(struct $0* zp($15) aFlake)
changeHorizontalDirection: {
    .label aFlake = $15
    ldy #2
    lda (aFlake),y
    cmp #-1
    beq __b1
    tya
    taz
    lda #-1
    sta.z (aFlake),z
    rts
  __b1:
    lda #2
    taz
    lda #1
    sta.z (aFlake),z
    rts
}
// canvasAt(byte register(X) x, byte register(A) y)
canvasAt: {
    .label __1 = $13
    .label __2 = $17
    .label adr = $13
    .label __3 = $13
    .label __4 = $15
    .label __5 = $13
    sta.z __1
    lda #0
    sta.z __1+1
    lda.z __1
    asl
    sta.z __4
    lda.z __1+1
    rol
    sta.z __4+1
    asl.z __4
    rol.z __4+1
    lda.z __5
    clc
    adc.z __4
    sta.z __5
    lda.z __5+1
    adc.z __4+1
    sta.z __5+1
    asw adr
    asw adr
    asw adr
    asw adr
    txa
    sta.z __2
    lda #0
    sta.z __2+1
    lda.z adr
    clc
    adc.z __2
    sta.z adr
    lda.z adr+1
    adc.z __2+1
    sta.z adr+1
    clc
    lda.z __3
    adc #<canvas
    sta.z __3
    lda.z __3+1
    adc #>canvas
    sta.z __3+1
    ldy #0
    lda (__3),y
    rts
}
.segment Data
  delay: .fill $32, 0
  currentCount: .fill $32, 0
  canvas: .fill size, 0
  flakeSymbols: .text "*,.+"
  .byte 0
  // DMA list entry for copying data
  memcpy_dma_command: .byte DMA_COMMAND_COPY
  .word 0, 0
  .byte 0
  .word 0
  .byte 0, 0
  .word 0
