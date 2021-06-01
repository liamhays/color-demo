;=====================================================================
; This is a simple demo that utilizes line interrupts to display lots
; of colors on screen at once---of course, with some CRAM dots. It
; displays a total of 256 unique colors; any more causes glitches and
; issues, from what I've found.
;=====================================================================

;=========================================
; Start preliminary stuff
;=========================================
.memorymap
defaultslot 0
slotsize $8000
slot 0 $0000
.endme

.rombankmap
bankstotal 1
banksize $8000
banks 1
.endro


; this also gives the ROM a header
.sdsctag 0, "Many color demo", "A demo to show many, many colors on screen at once", "Liam Hays"
;=========================================
; End preliminary stuff
;=========================================

;=========================================
; start defines
;=========================================
.define VDPControlPort $bf
.define VDPDataPort $be
.define VCounter $7E

;=========================================
; Start code section
;=========================================
.bank 0 slot 0
.org $0000

; boot
	di
	im 1
	jp main

;=========================================
; Line handler (really the interrupt handler in general)
;=========================================

; -4 is a good offset to prevent tearing
.define TearOffset 4

.define GGStartLine 24
.org $0038
InterruptHandler:

	
	in a, (VCounter)

	cp 0
	call z, ChangePalette1

	; I think the max line on the GG screen is line 195.
	cp GGStartLine + 16 - TearOffset
	call z, ChangePalette2

	; we don't get tearing at 121
	; tearing appears to be dependent on where we change
	; if we change on a sprite line, we don't get tearing
	cp GGStartLine + 16 + 16 - TearOffset
	call z, ChangePalette3

	cp GGStartLine + 32 + 16 - TearOffset
	call z, ChangePalette4

	cp GGStartLine + 48 + 16 - TearOffset
	call z, ChangePalette5

	cp GGStartLine + 64 + 16 - TearOffset
	call z, ChangePalette6

	cp GGStartLine + 80 + 16 - TearOffset
	call z, ChangePalette7

	; this is the most palette changes we can do	
	ei
	reti

;;;;;; Subroutine: takes palette address in hl and writes it to CRAM
MasterChangePalette:
	ld a, $00
	out (VDPControlPort), a
	ld a, %11000000
	out (VDPControlPort), a

	ld b, 64
	ld c, VDPDataPort
	otir
	ret

CPe:
	call MasterChangePalette
	ret
	
ChangePalette1:
	ld hl, Palette1
	jp CPe
	
ChangePalette2:
	ld hl, Palette2
	jp CPe

ChangePalette3:
	ld hl, Palette3
	jp CPe

ChangePalette4:
	ld hl, Palette4
	jp CPe
	
ChangePalette5:
	ld hl, Palette5
	jp CPe

ChangePalette6:
	ld hl, Palette6
	jp CPe

ChangePalette7:
	ld hl, Palette7
	jp CPe
	
; no pause button handler needed here, it's a GG program

main:
	ld sp, $dff0
	; initialize VDP registers
	ld hl, VDPInitData ; starting location in memory
	ld b, VDPInitDataEnd-VDPInitData ; decrement counter and data count
	ld c, VDPControlPort ; port to write to (data at hl is sent here)
	otir ; send (hl) to (c), dec b, inc hl until b == 0


	; just address bits: (first byte written)
	; we want to write to the 0th position in VRAM
	ld a, $00
	out (VDPControlPort), a
	ld a, %01000000 ; code value 1, writes to data go to VRAM
	out (VDPControlPort), a

	; now the VDP is ready to receive data
	; we want to output nothing but zeroes, and 16KB of them
	ld bc, $4000
	; we can't use a hardware repeat instruction because we're not
	; streaming data (and we don't want to store 16KB of zeroes
	; as data)
	-:
		ld a, $00
		out (VDPDataPort), a
		dec bc
		; this is tricky! it will only be zero if
		; the lower and upper half of bc are both zero,
		; and that only happens when bc itself is zero.
		ld a, b
		or c
		jp nz, -


	; write tiles to VRAM
	ld a, $00
	out (VDPControlPort), a
	ld a, %01000000 ; code value 1, writes to data go to VRAM
	out (VDPControlPort), a

	ld hl, Tiles
	ld bc, TilesEnd-Tiles
	-:
		ld a, (hl)
		out (VDPDataPort), a
		inc hl
		dec bc
		ld a, b
		or c
		jp nz, -


	; write palette
	ld a, $00
	out (VDPControlPort), a
	ld a, %11000000 ; enable CRAM write mode
	out (VDPControlPort), a

	ld hl, Palette1
	ld b, Palette1End-Palette1
	ld c, VDPDataPort
	otir

	; finally, we can write out the tilemap
	; apparently we need to write it to $3800 in VRAM
	
	; however, our tilemap is designed to start at the beginning
	; of the GG screen, not the beginning of the VDP's display.
	; we have to write 32*3 + 6 = 102 empty tiles, like this:
	
	ld a, $00
	out (VDPControlPort), a
	ld a, $38|$40 ; OR it with $40 to enable VRAM write
	out (VDPControlPort), a

	ld a, $00
	ld bc, 204 ; 102*2 because each tile is 2 bytes
	-:
		ld a, $00
		out (VDPDataPort), a
		dec bc
		ld a, b
		or c
		jp nz, -
		
	ld hl, Tilemap
	ld bc, TilemapEnd-Tilemap
	-:
		ld a, (hl)
		inc hl
		out (VDPDataPort), a
		dec bc
		ld a, b
		or c
		jp nz, -



	

	; turn the screen on
	; we do that with VDP register 01, and setting bit 6 to 1.
	ld a, %01000000 ; bit 6 set
	out (VDPControlPort), a
	; highest bit for register write, write to register 2
	ld a, %10000001
	out (VDPControlPort), a

	; now we need to deal with the line interrupts
	; enable them now so that they don't trigger while we're
	; adjusting data
	ld a, %00010100
	out (VDPControlPort), a
	ld a, %10000000
	out (VDPControlPort), a
	ei
	; do literally nothing
	@loop:
		jp @loop



VDPInitData:
; register 0
.db %00000100 %10000000
.db %00100000 %10000001
.db $ff $82
.db $ff $85
.db $ff $86
.db $ff $87
.db $00 $88
.db $00 $89
.db $ff $8a
VDPInitDataEnd:

Tiles:
.include "tiles.inc"
TilesEnd:

Tilemap:
.include "tilemap.inc"
TilemapEnd:

; contains both bg and sprite palettes
Palette1:
.dw $0FB $001 $002 $003 $004 $005 $006 $007 $008 $009 $00A $00B $00C $00D $00E $00F
.dw $0F1 $010 $020 $030 $040 $050 $060 $070 $080 $090 $0A0 $0B0 $0C0 $0D0 $0E0 $0F0
Palette1End:

Palette2:
.dw $01D $011 $022 $033 $044 $055 $066 $077 $088 $099 $0AA $0BB $0CC $0DD $0EE $0FF
.dw $FFE $100 $200 $300 $400 $500 $600 $700 $800 $900 $A00 $B00 $C00 $D00 $E00 $F00


Palette3:
.dw $FEF $10F $20F $30F $40F $50F $60F $70F $80F $90F $A0F $B0F $C0F $D0F $E0F $F0F
.dw $09D $101 $202 $303 $404 $505 $606 $707 $808 $909 $A0A $B0B $C0C $D0D $E0E $F0D


Palette4:
.dw $EF0 $110 $220 $330 $440 $550 $660 $770 $880 $990 $AA0 $BB0 $CC0 $DD0 $EE0 $FF0
.dw $FF1 $111 $222 $333 $444 $555 $666 $777 $888 $999 $AAA $BBB $CCC $DDD $EEE $FFF


Palette5:
.dw $FEA $F01 $F02 $F03 $F04 $F05 $F06 $F07 $F08 $F09 $F0A $F0B $F0C $F0D $F0E $F0F
.dw $005 $105 $205 $305 $405 $505 $605 $705 $805 $905 $A05 $B05 $C05 $D05 $E05 $F05


Palette6:
.dw $A6B $016 $026 $036 $046 $056 $066 $076 $086 $096 $0A6 $0B6 $0C6 $0D6 $0E6 $0F6 ; not $0FF because that's already on screen
.dw $9EF $019 $029 $039 $049 $059 $069 $079 $089 $099 $0A9 $0B9 $0C9 $0D9 $0E9 $0F9


Palette7:
.dw $58B $013 $023 $033 $043 $053 $063 $073 $083 $093 $0A3 $0B3 $0C3 $0D3 $0E3 $0F3
.dw $09B $01E $02E $03E $04E $05E $06E $07E $08E $09E $0AE $0BE $0CE $0DE $0EE $0FE
