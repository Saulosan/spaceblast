	; CVBasic compiler v0.9.2 Mar/12/2026
	; Command: cvbasic --nes space-blast-v035.bas space-blast-v035.asm
	; Created: reproducible build

COLECO:	equ 0
SG1000:	equ 0
MSX:	equ 0
FM_SUPPORT:	equ 0
SGM:	equ 0
SVI:	equ 0
SORD:	equ 0
MEMOTECH:	equ 0
EINSTEIN:	equ 0
CPM:	equ 0
PENCIL:	equ 0
PV2000:	equ 0
TI99:	equ 0
NABU:	equ 0
SMS:	equ 0
NES_PRG_BANKS:	equ 32	; Each one 16K.
NES_CHR_BANKS:	equ 3	; Each one 4K.
NES_NAMETABLE:	equ 0

CVBASIC_MUSIC_PLAYER:	equ 1
CVBASIC_COMPRESSION:	equ 0
CVBASIC_BANK_SWITCHING:	equ 1
CVBASIC_BANK_ROM_SIZE:	equ 512
COLECO_SPINNER:	equ 0

BASE_RAM:	equ $0050	; Base of RAM
RAM_SIZE:	equ $0800	; Base of RAM
STACK:	equ $01ff	; Base stack pointer
VDP:	equ $00	; VDP port (write)
VDPR:	equ $00	; VDP port (read)
PSG:	equ $00	; PSG port (write)

	forg $00000
	;
	; CVBasic prologue (BASIC compiler, 6502 target)
	;
	; by Oscar Toledo G.
	; https://nanochess.org/
	;
	; Creation date: May/13/2025.
	; Revision date: Jul/20/2025. Added code to load sprites and read controllers.
	; Revision date: Aug/23/2025. Support for writing VRAM and PRINT.
	; Revision date: Aug/24/2025. Support for scrolling, SCREEN, and DISABLE/ENABLE.
	;                             Added music player.
	; Revision date: Aug/25/2025. Added support for 256K and 512K ROM.
	; Revision date: Aug/26/2025. Added support for CHRRAM selection.
	; Revision date: Feb/16/2026. Relocated PPUBUF.
	; Revision date: Mar/25/2026. Faster _mul16 (using Y in loop) and _div16
	;                             (avoids update using registers)
	; Revision date: Mar/29/2026. Avoids unwinding stack for _mul16, _div16, _div16s,
	;                             _mod16, and _mod16s.
	;

	CPU 6502

	;
	; Platforms supported:
	; o NES/Famicom
	;

	;
	; CVBasic variables in zero page.
	;

ppu_source:	equ $00	; Used in NMI for source address for PPU copy
	; This is a block of 8 bytes that should stay together.
temp:		equ $02
temp2:		equ $04
result:		equ $06
pointer:	equ $08

read_pointer:	equ $0a
cursor:		equ $0c
mode:           equ $0e
ntsc:		equ $0f

vdp_status:	equ $10
flicker:	equ $11
frame:		equ $12
ppu_pointer:	equ $14
ppu_temp:	equ $15	; Used in NMI to save X
ppu_ctrl:	equ $16
ppu_mask:	equ $17
scroll_x:	equ $18
scroll_y:	equ $1a
CHRRAM_BANK:	equ $1c
cont_bits:	equ $1d
lfsr:		equ $1e

joy1_data:	equ $20
joy2_data:	equ $21
key1_data:	equ $22
key2_data:	equ $23
sprite_data:	equ $24

	IF CVBASIC_MUSIC_PLAYER
music_playing:		EQU $4f
music_bank:             EQU $30
music_timing:		EQU $31
music_start:		EQU $32
music_pointer:		EQU $34
music_note_counter:	EQU $36
music_instrument_1:	EQU $37
music_note_1:		EQU $38
music_counter_1:	EQU $39
music_instrument_2:	EQU $3a
music_note_2:		EQU $3b
music_counter_2:	EQU $3c
music_instrument_3:	EQU $3d
music_note_3:		EQU $3e
music_counter_3:	EQU $3f
music_drum:		EQU $40
music_counter_4:	EQU $41
audio_freq1:		EQU $42
audio_freq2:		EQU $44
audio_freq3:		EQU $46
audio_vol1:		EQU $48
audio_vol2:		EQU $49
audio_vol3:		EQU $4a
audio_vol4hw:		EQU $4b
audio_noise:		EQU $4c
music_tick:		EQU $4d
music_mode:		EQU $4e
	ENDIF

SPRITE_PAGE:	EQU $02
PPUBUF:		EQU $0140
PPUSIZE:	EQU $90	; v0.20 burst stream
BANKSEL:	EQU $C000

	FORG $0000
	; The ORG address doesn't matter here
	; iNES cartridge header
	DB "NES",$1A
	DB NES_PRG_BANKS
    if CVBASIC_BANK_SWITCHING
	DB 0	; It has CHRRAM
	DB $e2|NES_NAMETABLE	; Cartridge type LSB
	DB $10	; Cartridge type MSB
	DB $00	; Number of 8K RAM pages.
    else
	DB NES_CHR_BANKS
	DB $00|NES_NAMETABLE	; Cartridge type LSB
	DB $00	; Cartridge type MSB
	DB $00	; Number of 8K RAM pages.
    endif
	DB $00,$00,$00,$00,$00,$00,$00	; Reserved

    if CVBASIC_BANK_SWITCHING
        if CVBASIC_BANK_ROM_SIZE-512
		FORG $3c010
		ORG $c000
        else
		FORG $7c010
		ORG $c000
        endif
    else
	FORG $0010
	ORG $8000
    endif
	
PPUCTRL:	EQU $2000
PPUMASK:	EQU $2001
PPUSTATUS:	EQU $2002
OAMADDR:	EQU $2003
OAMDATA:	EQU $2004
PPUSCROLL:	EQU $2005
PPUADDR:	EQU $2006
PPUDATA:	EQU $2007
SPRRAM:		EQU $4014
CONT1:		EQU $4016
CONT2:		EQU $4017

	;
	; NES architecture prevents direct access to VRAM except
	; during the VBLANK.
	;
WRTVRM:
	PHA
	TXA
	LDX ppu_pointer
	STA PPUBUF+2,X
	PLA
	STA PPUBUF,X
	TYA
	ORA #$40
	STA PPUBUF+1,X
	INX
	INX
	INX
	STX ppu_pointer
	CPX #PPUSIZE
	BCS .1
	RTS
.1:
	JMP wait

LDIRVM4:
	JSR LDIRVM2
	JSR LDIRVM2
	JSR LDIRVM2
	JSR LDIRVM2
	RTS

LDIRVM2:
	JSR LDIRVM
	LDA pointer
	CLC
	ADC temp2
	STA pointer
	BCC .1
	INC pointer+1
.1:
	RTS

LDIRVM:
	LDX ppu_pointer
	LDA pointer
	STA PPUBUF,X
	LDA pointer+1
	STA PPUBUF+1,X
	LDA #0
	SEC
	SBC temp2
	STA PPUBUF+2,X
	LDA temp
	SEC
	SBC PPUBUF+2,X
	STA PPUBUF+3,X
	LDA temp+1
	SBC #0
	STA PPUBUF+4,X
	TXA
	CLC
	ADC #5
	STA ppu_pointer
	CMP #PPUSIZE
	BCS .1
	RTS
.1:
	JMP wait

ENASCR:
	LDA ppu_mask
	ORA #$18
	STA ppu_mask
	RTS

DISSCR:
	LDA ppu_mask
	AND #$E7
	STA ppu_mask
	RTS

CPYBLK:
.1:	
	LDA temp2
	PHA
	LDA temp2+1
	PHA
	TXA
	PHA
	TYA
	PHA
	LDA temp
	PHA
	LDA temp+1
	PHA
	LDA #0
	STA temp2+1
	JSR LDIRVM
	PLA
	STA temp+1
	PLA
	STA temp
	PLA
	STA temp2+1
	PLA
	STA temp2
	LDA temp
	CLC
	ADC temp2
	STA temp
	LDA temp+1
	ADC temp2+1
	STA temp+1
	LDX temp2
	LDY temp2+1
	PLA
	STA temp2+1
	PLA
	STA temp2
	LDA pointer
	CLC
	ADC #$20	; !!! Variation for scrolling
	STA pointer
	LDA pointer+1
	ADC #$00
	STA pointer+1
	DEC temp2+1
	BNE .1
	RTS

cls:
	LDA #$80
.1:
	PHA
	LDX ppu_pointer
	CMP #$8F
	BNE .2
	LDA #$00
	BEQ .3

.2:	LDA #$20
.3:	STA PPUBUF+3,X
	LDA #$40
	STA PPUBUF+2,X
	LDA #$00
	STA PPUBUF,X
	PLA
	STA PPUBUF+1,X
	PHA
	CLC
	ROR PPUBUF+1,X
	ROR PPUBUF,X
	SEC
	ROR PPUBUF+1,X
	ROR PPUBUF,X
	INX
	INX
	INX
	INX
	STX ppu_pointer
	JSR wait
	PLA
	CLC
	ADC #1
	CMP #$90
	BNE .1
	RTS

update_sprite:
	ASL A
	ASL A
	STA pointer
	LDA #SPRITE_PAGE
	STA pointer+1
	LDY #0
	LDA sprite_data+0
	STA (pointer),Y
	INY
	LDA sprite_data+1
	STA (pointer),Y
	INY
	LDA sprite_data+2
	STA (pointer),Y
	INY
	LDA sprite_data+3
	STA (pointer),Y
	RTS

_abs16:
	PHA
	TYA
	BPL _neg16.1
	PLA
_neg16:
	EOR #$FF
	CLC
	ADC #1
	PHA
	TYA
	EOR #$FF
	ADC #0
	TAY
.1:
	PLA
	RTS

_sgn16:
	STY temp
	ORA temp
	BEQ .1
	TYA
	BMI .2
	LDA #0
	TAY
	LDA #1
	RTS

.2:	LDA #$FF
.1:	TAY
	RTS

_read16:
	JSR _read8
	PHA
	JSR _read8
	TAY
	PLA
	RTS

_read8:
	LDY #0
	LDA (read_pointer),Y
	INC read_pointer
	BNE .1
	INC read_pointer+1
.1:
	RTS

_peek8:
	STA pointer
	STY pointer+1
	LDY #0
	LDA (pointer),Y
	RTS

_peek16:
	STA pointer
	STY pointer+1
	LDY #0
	LDA (pointer),Y
	PHA
	INY
	LDA (pointer),Y
	TAY
	PLA
	RTS

	; temp2 contains left side (dividend)
	; temp contains right side (divisor)

	; 16-bit multiplication.
_mul16:
	STA temp2
	STY temp2+1
	LDA #0
	STA result
	TAY
	; Shift low-byte of multiplier
	LDX #7
.1:
	LSR temp2
	BCC .2
	LDA result
	CLC
	ADC temp
	STA result
	TYA
	ADC temp+1
	TAY
.2:	ASL temp
	ROL temp+1
	DEX
	BPL .1
	; Shift high-byte of multiplier (temp is zero here)
	TYA
	LDX #7
.3:
	LSR temp2+1
	BCC .4
	CLC
	ADC temp+1
.4:	ASL temp+1
	DEX
	BPL .3
	TAY
	LDA result
	RTS

	; 16-bit signed modulo.
_mod16s:
	STA temp2
	STY temp2+1
	LDY temp2+1
	PHP
	BPL .1
	LDA temp2
	JSR _neg16
	STA temp2
	STY temp2+1
.1:
	LDY temp+1
	BPL .2
	LDA temp
	JSR _neg16
	STA temp
	STY temp+1
.2:
	JSR _mod16.1
	PLP
	BPL .3
	JMP _neg16
.3:
	RTS

	; 16-bit signed division.
_div16s:
	STA temp2
	STY temp2+1
	LDA temp+1
	EOR temp2+1
	PHP
	LDY temp2+1
	BPL .1
	LDA temp2
	JSR _neg16
	STA temp2
	STY temp2+1
.1:
	LDY temp+1
	BPL .2
	LDA temp
	JSR _neg16
	STA temp
	STY temp+1
.2:
	JSR _div16.1
	PLP
	BPL .3
	JMP _neg16
.3:
	RTS

_div16:
	STA temp2
	STY temp2+1
.1:
	LDA #0
	STA result
	STA result+1
	LDX #15
.2:
	ROL temp2
	ROL temp2+1
	ROL result
	ROL result+1
	LDA result
	SEC
	SBC temp
	TAY
	LDA result+1
	SBC temp+1
	BCC .3
	STY result
	STA result+1
.3:	DEX
	BPL .2
	ROL temp2
	ROL temp2+1
	LDA temp2
	LDY temp2+1
	RTS

_mod16:
	STA temp2
	STY temp2+1
.1:
	LDA #0
	STA result
	STA result+1
	LDX #15
.2:
	ROL temp2
	ROL temp2+1
	ROL result
	ROL result+1
	LDA result
	SEC
	SBC temp
	STA result
	LDA result+1
	SBC temp+1
	STA result+1
	BCS .3
	LDA result
	ADC temp
	STA result
	LDA result+1
	ADC temp+1
	STA result+1
	CLC
.3:
	DEX
	BPL .2
	LDA result
	LDY result+1
	RTS

	; Random number generator.
	; From my game Mecha Eight.
random:
	LDA lfsr
	ORA lfsr+1
	BNE .0
	LDA #$11
	STA lfsr
	LDA #$78
	STA lfsr+1
.0:	LDA lfsr+1
	ROR A	
	ROR A		
	ROR A		
	EOR lfsr+1	
	STA temp
	LDA lfsr+1
	ROR A
	ROR A
	EOR temp
	STA temp
	LDA lfsr
	ASL A
	ASL A
	EOR temp
	ROL A
	ROR lfsr+1
	ROR lfsr
	LDA lfsr
	LDY lfsr+1
	RTS

irq_handler:
	RTI

nmi_handler:
	PHA
	TXA
	PHA
	TYA
	PHA
	
  if CVBASIC_BANK_SWITCHING
	LDA $BFFF
	PHA
  endif
	; Load sprites
	LDA mode
	AND #4		; Flicker enabled?
	BNE .5		; No, jump.
	LDA flicker
	CLC
	ADC #32
	STA flicker
	JMP .6
.5:
	LDA #$00
.6:
	STA OAMADDR
	LDX #SPRITE_PAGE	
	STX SPRRAM	; Use DMA for sprite loading

	; Screen changes
	LDA ppu_pointer	; Any change?
	BEQ .1		; No, jump.
	LDX #$00
.0:	LDY PPUBUF,X
	INX
	LDA PPUBUF,X
	INX
	STA PPUADDR	; High-byte of VRAM address.
	ROL A
	STY PPUADDR	; Low-byte of VRAM address.
	BCS .2		; Fill routine.
	BMI .7		; Single byte routine.
			; Copy routine.
	LDA PPUBUF+1,X
	STA ppu_source
	LDA PPUBUF+2,X
	STA ppu_source+1
	LDY PPUBUF,X	; Negative counter.
	INX
	INX
	INX
.4:
	LDA (ppu_source),Y
	STA PPUDATA
	INY
	BNE .4
	CPX ppu_pointer
	BNE .0
	JMP .11

	; Single byte
.7:
	LDA PPUBUF,X
	INX
	STA PPUDATA
	CPX ppu_pointer
	BNE .0
	JMP .11

	; Filling data	
.2:
	LDY PPUBUF,X
	INX
	LDA PPUBUF,X
	INX
.3:
	STA PPUDATA
	DEY
	BNE .3	
	CPX ppu_pointer
	BNE .0

.11:
	LDA #0
	STA ppu_pointer
.1:

	; Final settings for PPU
	LDA #0
	STA PPUADDR
	STA PPUADDR
	LDA scroll_x
	STA PPUSCROLL	
	LDA scroll_y
	STA PPUSCROLL
	LDA ppu_ctrl
	LSR A
	LSR A
	STA ppu_temp
	LDA scroll_y+1
	ROR A
	ROL ppu_temp	
	LDA scroll_x+1
	ROR A
	ROL ppu_temp
	LDA ppu_temp
	STA PPUCTRL
	LDA ppu_mask
	STA PPUMASK

	LDA PPUSTATUS	; VDP interruption clear.
	STA vdp_status

	; Read controllers
	LDA #$01
	STA CONT1
	STA cont_bits
	LSR A
	STA CONT1

.15:	LDA CONT1
;	LSR A
	AND #3		; So it works with Famicom
	CMP #1
	ROL cont_bits
	BCC .15

	JSR convert_joystick
	STA joy1_data
	STX key1_data

	LDA #$01
	STA CONT1
	STA cont_bits
	LSR A
	STA CONT1

.16:	LDA CONT2
;	LSR A
	AND #3		; So it works with Famicom
	CMP #1
	ROL cont_bits
	BCC .16

	JSR convert_joystick
	STA joy2_data
	STX key2_data

    if CVBASIC_MUSIC_PLAYER
	LDA music_mode
	BEQ .10
	JSR music_hardware
.10:
    endif
	INC frame
	BNE .8
	INC frame+1
.8:
	INC lfsr	; Make LFSR more random
	INC lfsr
	INC lfsr
    if CVBASIC_MUSIC_PLAYER
	LDA ntsc
	BEQ .12
	LDX music_tick
	INX
	CPX #6
	BNE .14
	LDX #0
.14:	STX music_tick
	BEQ .9
.12:
	LDA music_mode
	BEQ .9
	JSR music_generate
.9:
    endif
	; This is like saving extra registers, because these
	; are used by the compiled code, and we don't want
	; any reentrancy.
	LDA temp+0
	PHA
	LDA temp+1
	PHA
	LDA temp+2
	PHA
	LDA temp+3
	PHA
	LDA temp+4
	PHA
	LDA temp+5
	PHA
	LDA temp+6
	PHA
	LDA temp+7
	PHA

	PLA
	STA temp+7
	PLA
	STA temp+6
	PLA
	STA temp+5
	PLA
	STA temp+4
	PLA
	STA temp+3
	PLA
	STA temp+2
	PLA
	STA temp+1
	PLA
	STA temp+0

  if CVBASIC_BANK_SWITCHING
	PLA
	ORA CHRRAM_BANK
	STA BANKSEL
  endif
	PLA
	TAY
	PLA
	TAX
	PLA
	RTI

convert_joystick:
	LDA #0
	LDX #15
	ROR cont_bits
	BCC $+4
	ORA #2
	ROR cont_bits
	BCC $+4
	ORA #8
	ROR cont_bits
	BCC $+4
	ORA #4
	ROR cont_bits
	BCC $+4
	ORA #1
	ROR cont_bits
	BCC $+4
	LDX #11
	ROR cont_bits
	BCC $+4
	LDX #10
	ROR cont_bits
	BCC $+4
	ORA #$40
	ROR cont_bits
	BCC $+4
	ORA #$80
	RTS

wait:
	LDA frame
.1:	CMP frame
	BEQ .1
	LDA FAMISTUDIO_ACTIVE
	BEQ .2
	SEI
	LDA $BFFF
	STA FAMISTUDIO_SAVED_BANK
	LDA #FAMISTUDIO_BANK
	ORA CHRRAM_BANK
	STA BANKSEL
	JSR FAMISTUDIO_UPDATE
	LDA FAMISTUDIO_SAVED_BANK
	ORA CHRRAM_BANK
	STA BANKSEL
	CLI
.2:
	RTS

print_string_cursor_constant:
	PLA
	STA temp
	PLA
	STA temp+1
	LDY #1
	LDA (temp),Y
	STA cursor
	INY
	LDA (temp),Y
	STA cursor+1
	INY
	LDA (temp),Y
	STA temp2
	TYA
	CLC
	ADC temp
	STA temp
	BCC $+4
	INC temp+1
	LDA temp2
	BNE print_string.2

print_string_cursor:
	STA cursor
	STY cursor+1
print_string:
	PLA
	STA temp
	PLA
	STA temp+1
	LDY #1
	LDA (temp),Y
	STA temp2
	INC temp
	BNE $+4
	INC temp+1
.2:	CLC
	ADC temp
	TAY
	LDA #0
	ADC temp+1
	PHA
	TYA
	PHA
	INC temp
	BNE $+4
	INC temp+1
	LDX ppu_pointer
	LDA cursor
	STA PPUBUF,X
	LDA cursor+1
	AND #$07
	ORA #$20
	STA PPUBUF+1,X
	LDA #0
	SEC
	SBC temp2
	STA PPUBUF+2,X
	LDA temp
	SEC
	SBC PPUBUF+2,X
	STA PPUBUF+3,X
	LDA temp+1
	SBC #0
	STA PPUBUF+4,X
	TXA
	CLC
	ADC #5
	STA ppu_pointer
	LDA temp2
	CLC
	ADC cursor
	STA cursor
	BCC .1
	INC cursor+1
.1:	
	CPX #PPUSIZE-5
	BCS .3
	RTS
.3:
	JMP wait

print_number:
	LDX #0
	STX temp
	SEI
print_number5:
	LDX #10000
	STX temp2
	LDX #10000/256
	STX temp2+1
	JSR print_digit
print_number4:
	LDX #1000
	STX temp2
	LDX #1000/256
	STX temp2+1
	JSR print_digit
print_number3:
	LDX #100
	STX temp2
	LDX #0
	STX temp2+1
	JSR print_digit
print_number2:
	LDX #10
	STX temp2
	LDX #0
	STX temp2+1
	JSR print_digit
print_number1:
	LDX #1
	STX temp2
	STX temp
	LDX #0
	STX temp2+1
	JSR print_digit
	CLI
	RTS

print_digit:
	LDX #$2F
.2:
	INX
	SEC
	SBC temp2
	PHA
	TYA
	SBC temp2+1
	TAY
	PLA
	BCS .2
	CLC
	ADC temp2
	PHA
	TYA
	ADC temp2+1
	TAY
	PLA
	CPX #$30
	BNE .3
	LDX temp
	BNE .4
	RTS

.4:	DEX
	BEQ .6
	LDX temp+1
	BNE print_char
.6:
	LDX #$30
.3:	PHA
	LDA #1
	STA temp
	PLA

print_char:
	PHA
	TYA
	PHA
	LDA cursor+1
	AND #$07
	ORA #$20
	TAY
	LDA cursor
	JSR WRTVRM
	INC cursor
	BNE .1
	INC cursor+1
.1:
	PLA
	TAY
	PLA
	RTS

mode_0:
	JSR cls
clear_sprites:
	LDA #$F0
	LDX #0
.1:
	STA $0200,X
	INX
	INX
	INX
	INX
	BNE .1
	RTS

music_init:
	LDA #$40
	STA $4017
	LDA #$10
	STA $4000	; Channel 1 silent
	STA $4004	; Channel 2 silent
	STA $400C	; Channel 4 silent
	LDA #$0b
	STA $4015	; Enable channel 1, 2 and 4.
	LDA #$00
	STA $4010
    if CVBASIC_MUSIC_PLAYER
    else	
	RTS
    endif

    if CVBASIC_MUSIC_PLAYER
	LDA #music_silence
	LDY #music_silence>>8
	;
	; Play music.
	; YA = Pointer to music.
	;
music_play:
	SEI
	STA music_pointer
	STY music_pointer+1
	LDA #0
	STA FAMISTUDIO_ACTIVE
	LDA #5
	STA music_mode
	LDY #0
	STY music_note_counter
	LDA (music_pointer),Y
	STA music_timing
	INY
	STY music_playing
	INC music_pointer
	BNE $+4
	INC music_pointer+1
	LDA music_pointer
	LDY music_pointer+1
	STA music_start
	STY music_start+1
    if CVBASIC_BANK_SWITCHING
	LDA $BFFF
	STA music_bank
    endif
	CLI
	RTS

	;
	; Generates music
	;
music_generate:
	LDA #$10
	STA audio_vol1
	STA audio_vol2
	STA audio_vol3
	STA audio_vol4hw
	LDA music_note_counter
	BEQ .1
	JMP .2
.1:
    if CVBASIC_BANK_SWITCHING
	LDA music_bank
	ORA CHRRAM_BANK
	STA BANKSEL
    endif
	LDY #0
	LDA (music_pointer),Y
	CMP #$fe	; End of music?
	BNE .3		; No, jump.
	LDA #0		; Keep at same place.
	STA music_playing
	RTS

.3:	CMP #$fd	; Repeat music?
	BNE .4
	LDA music_start
	LDY music_start+1
	STA music_pointer
	STY music_pointer+1
	JMP .1

.4:	LDA music_timing
	AND #$3f	; Restart note time.
	STA music_note_counter

	LDA (music_pointer),Y
	CMP #$3F	; Sustain?
	BEQ .5
	AND #$C0
	STA music_instrument_1
	LDA (music_pointer),Y
	AND #$3F
	ASL A
	STA music_note_1
	LDA #0
	STA music_counter_1
.5:
	INY
	LDA (music_pointer),Y
	CMP #$3F	; Sustain?
	BEQ .6
	AND #$C0
	STA music_instrument_2
	LDA (music_pointer),Y
	AND #$3F
	ASL A
	STA music_note_2
	LDA #0
	STA music_counter_2
.6:
	INY
	LDA (music_pointer),Y
	CMP #$3F	; Sustain?
	BEQ .7
	AND #$C0
	STA music_instrument_3
	LDA (music_pointer),Y
	AND #$3F
	ASL A
	STA music_note_3
	LDA #0
	STA music_counter_3
.7:
	INY
	LDA (music_pointer),Y
	STA music_drum
	LDA #0	
	STA music_counter_4
	LDA music_pointer
	CLC
	ADC #4
	STA music_pointer
	LDA music_pointer+1
	ADC #0
	STA music_pointer+1
.2:
	LDY music_note_1
	BEQ .8
	LDA music_instrument_1
	LDX music_counter_1
	JSR music_note2freq
	STA audio_freq1
	STY audio_freq1+1
	STX audio_vol1
.8:
	LDY music_note_2
	BEQ .9
	LDA music_instrument_2
	LDX music_counter_2
	JSR music_note2freq
	STA audio_freq2
	STY audio_freq2+1
	STX audio_vol2
.9:
	LDY music_note_3
	BEQ .10
	LDA music_instrument_3
	LDX music_counter_3
	JSR music_note2freq
	STA audio_freq3
	STY audio_freq3+1
	STX audio_vol3
.10:
	LDA music_drum
	BEQ .11
	CMP #1		; 1 - Long drum.
	BNE .12
	LDA music_counter_4
	CMP #3
	BCS .11
.15:
	LDA #$06
	STA audio_noise
	LDA #$9c
	STA audio_vol4hw
	JMP .11

.12:	CMP #2		; 2 - Short drum.
	BNE .14
	LDA music_counter_4
	CMP #0
	BNE .11
	LDA #$02
	STA audio_noise
	LDA #$9c
	STA audio_vol4hw
	JMP .11

.14:	;CMP #3		; 3 - Roll.
	;BNE
	LDA music_counter_4
	CMP #2
	BCC .15
	ASL A
	SEC
	SBC music_timing
	BCC .11
	CMP #4
	BCC .15
.11:
	LDX music_counter_1
	INX
	CPX #$18
	BNE $+4
	LDX #$10
	STX music_counter_1

	LDX music_counter_2
	INX
	CPX #$18
	BNE $+4
	LDX #$10
	STX music_counter_2

	LDX music_counter_3
	INX
	CPX #$18
	BNE $+4
	LDX #$10
	STX music_counter_3

	INC music_counter_4
	DEC music_note_counter
	RTS

music_flute:
	LDA music_notes_table,Y
	CLC
	ADC .2,X
	PHA
	LDA music_notes_table+1,Y
	ADC #0
	TAY
	LDA .1,X
	TAX
	PLA
	RTS

.1:
	db $9a,$9c,$9d,$9d,$9c,$9c,$9c,$9c
	db $9b,$9b,$9b,$9b,$9a,$9a,$9a,$9a
	db $9b,$9b,$9b,$9b,$9a,$9a,$9a,$9a

.2:
	db 0,0,0,0,0,1,1,1
	db 0,1,1,1,0,1,1,1
	db 0,1,1,1,0,1,1,1

	;
	; Converts note to frequency.
	; Input:
	;   A = Instrument.
	;   Y = Note (1-62)
	;   X = Instrument counter.
	; Output:
	;   YA = Frequency.
	;   X = Volume.
	;
music_note2freq:
	CMP #$40
	BCC music_piano
	BEQ music_clarinet
	CMP #$80
	BEQ music_flute
	;
	; Bass instrument
	; 
music_bass:
	LDA music_notes_table,Y
	ASL A
	PHA
	LDA music_notes_table+1,Y
	ROL A
	TAY
	LDA .1,X
	TAX
	PLA
	RTS

.1:
	db $9d,$9d,$9c,$9c,$9b,$9b,$9a,$9a
	db $99,$99,$98,$98,$97,$97,$96,$96
	db $95,$95,$94,$94,$93,$93,$92,$92

music_piano:
	LDA music_notes_table,Y
	PHA
	LDA music_notes_table+1,Y
	TAY
	LDA .1,X
	TAX
	PLA
	RTS

.1:	
	db $dc,$db,$db,$da,$da,$d9,$d9,$d8
	db $d8,$d7,$d7,$d6,$d6,$d5,$d5,$d4
	db $d4,$d4,$d5,$d5,$d4,$d4,$d3,$d3

music_clarinet:
	LDA music_notes_table,Y
	CLC
	ADC .2,X
	PHA
	LDA .2,X
	BMI .3
	LDA #$00
	DB $2C
.3:	LDA #$ff
	ADC music_notes_table+1,Y
	LSR A
	TAY
	LDA .1,X
	TAX
	PLA
	ROR A
	RTS

.1:
	db $1d,$1e,$1e,$1d,$1d,$1c,$1c,$1c
	db $1b,$1b,$1b,$1b,$1c,$1c,$1c,$1c
	db $1b,$1b,$1b,$1b,$1c,$1c,$1c,$1c

.2:
	db 0,0,0,0,-1,-1,-1,0
	db 1,1,1,0,-1,-1,-1,0
	db 1,1,1,0,-1,-1,-1,0

	;
	; Musical notes table.
	;
music_notes_table:
	; Silence - 0
	dw 0
	; Values for 1.79 mhz. / 16, offset 0
	; 2nd octave - Index 1
	dw 1710,1614,1524,1438,1357,1281,1209,1141,1077,1017,960,906
	; 3rd octave - Index 13
	dw 855,807,762,719,679,641,605,571,539,508,480,453
	; 4th octave - Index 25
	dw 428,404,381,360,339,320,302,285,269,254,240,226
	; 5th octave - Index 37
	dw 214,202,190,180,170,160,151,143,135,127,120,113
	; 6th octave - Index 49
	dw 107,101,95,90,85,80,76,71,67,64,60,57
	; 7th octave - Index 61
	dw 53,50,48

	;
	; When the frequency upper byte is rewritten, the
	; output phase is reset, and it creates glitches.
	; So it doesn't rewrite frequency unless the note
	; changes.
	;
music_hardware:
	LDA music_mode
	CMP #4		; PLAY SIMPLE?
	BCC .9		; Yes, jump.
	LDA audio_vol2
	AND #$0F
	BNE .9
	LDA audio_vol3
	AND #$0F
	BEQ .9
	LDA audio_vol3
	STA audio_vol2
	LDA #$10
	STA audio_vol3
	LDA audio_freq3
	LDY audio_freq3+1
	STA audio_freq2
	STY audio_freq2+1
.9:
	LDA audio_freq1
	STA $4002
	LDA music_counter_1
	CMP #1
	BNE .3
	LDA audio_freq1+1
	ORA #$08	; Keeps tone enabled
	STA $4003
.3:	LDA audio_vol1
	STA $4000
	LDA #0
	STA $4001

	LDA audio_freq2
	STA $4006
	LDA music_counter_2
	CMP #1
	BNE .4
	LDA audio_freq2+1
	ORA #$08	; Keeps tone enabled
	STA $4007
.4:	LDA audio_vol2
	STA $4004
	LDA #0
	STA $4005

	LDA music_mode
	CMP #4		; PLAY SIMPLE?
	BCC .6		; Yes, jump.

	LSR audio_freq3+1
	ROR audio_freq3
	LDA audio_freq3
	STA $400A
	LDA music_counter_3
	CMP #1
	BNE .5
	LDA audio_freq3+1
	ORA #$08	; Keeps tone enabled
	STA $400B
.5:
	LDA #$20
	STA $4008
	LDA audio_vol3
	AND #$0F
	BNE .1
	LDA #$0B
	JMP .2

.1:	LDA #$0F
.2:	STA $4015

.6:	LDA music_mode
	LSR A		; NO DRUMS?
	BCC .8
	LDA music_counter_4
	CMP #1
	BNE .7
	LDA audio_noise
	STA $400E
	ORA #$08	; Keeps tone enabled
	STA $400F
.7:	LDA audio_vol4hw
	STA $400C
.8:
	RTS

music_silence:
	db 8
	db 0,0,0,0
	db -2
    endif


    IF CVBASIC_BANK_SWITCHING
copy_chrram:
	LDA #$00
	STA PPUADDR
	STA PPUADDR
	STA temp
	STX temp+1
	LDX #32
.1:
	JSR copy_page
	DEX
	BNE .1
	RTS

copy_page:
	LDY #0
.1:
	LDA (temp),Y
	STA PPUDATA
	INY
	BNE .1
	INC temp+1
	RTS
    ENDIF

START:
	SEI
	CLD

	BIT PPUSTATUS

	LDA #$40
	STA $4017
	LDA #$10
	STA $4000	; Channel 1 silent
	STA $4004	; Channel 2 silent
	STA $400C	; Channel 4 silent
	LDA #$0b
	STA $4015	; Enable channel 1, 2 and 4.
	LDA #$00
	STA $4010

	LDA #0
	STA PPUCTRL
	STA PPUMASK
	
	TAX
.1:	STA $00,X
	STA $0100,X
	STA $0300,X
	STA $0400,X
	STA $0500,X
	STA $0600,X
	STA $0700,X
	INX
	BNE .1

	LDX #STACK
	TXS

	JSR clear_sprites

	;
	; The NES starts with the PPU registers write-protected.
	; Around 29000 cycles must happen before these can be written.
	;
	
	; lidnariq code for detecting NTSC/PAL/Dendy system
	; From: https://forums.nesdev.org/viewtopic.php?p=163258#p163258
	LDX #0
	LDY #0
	BIT PPUSTATUS
	BPL $-3	
.5:
	INX
	BNE .6
	INY
.6:
			; About 27384 cycles passed at this time.
	BIT PPUSTATUS
	BPL .5
	LDA #0
	STA PPUCTRL
	STA PPUMASK

	TYA
	CMP #16
	BCC .7
	LSR A
.7:	CLC
	ADC #$F7
	CMP #3
	BCC .8
	LDA #3		; Bad
	; 0=NTSC, 1=Pal, 2=Dendy, 3=Bad
.8:
	CMP #0		; Pass NTSC unchanged
	BEQ .9
	LDA #1		; All other PAL
.9:	EOR #1
	STA ntsc
			; About 57165 cycles passed at this time.

    IF CVBASIC_BANK_SWITCHING
	; Copy CHRROM to CHRRAM
	LDA #$00+CVBASIC_BANK_ROM_SIZE/16-3
	STA BANKSEL
	LDX #$80
	LDA #$3F
	STA PPUADDR
	LDA #$00
	STA PPUADDR
	LDA #$0F
	STA PPUDATA
	JSR copy_chrram

	LDA #$20+CVBASIC_BANK_ROM_SIZE/16-3
	STA BANKSEL
	LDX #$A0
	JSR copy_chrram

	LDA #$40+CVBASIC_BANK_ROM_SIZE/16-2
	STA BANKSEL
	LDX #$80
	JSR copy_chrram

	LDA #$60+CVBASIC_BANK_ROM_SIZE/16-2
	STA BANKSEL
	LDX #$A0
	JSR copy_chrram

	LDA #$00	; BANK SELECT 1
	STA BANKSEL
    ENDIF

	; Clear 2K of pattern memory
	LDA #$20
	STA PPUADDR
	LDA #$00
	STA PPUADDR
	LDX #$78
	LDA #$20
.2:
	STA PPUDATA
	STA PPUDATA
	STA PPUDATA
	STA PPUDATA
	STA PPUDATA
	STA PPUDATA
	STA PPUDATA
	STA PPUDATA
	DEX
	BNE .2

	LDX #$40
	LDA #$00
.3:	STA PPUDATA
	DEX
	BNE .3

	; Setup base palette
	LDA #$3F
	STA PPUADDR
	LDA #$00
	STA PPUADDR
	LDX #8
.4:
	LDA #$0F	; Black
	STA PPUDATA
	LDA #$35	; Red
	STA PPUDATA
	LDA #$3A	; Green
	STA PPUDATA
	LDA #$30	; White
	STA PPUDATA
	DEX
	BNE .4

	BIT PPUSTATUS
	BPL $-3	
	LDA #$00	; v0.16: boot sem flash cinza (video so liga no SCREEN ENABLE)
	STA PPUMASK
	STA ppu_mask
	LDA #$A8	; Enable NMI, 8x16 sprites, BG=$0000, SPR=$1000, NAME=$2000
	STA ppu_ctrl
	STA PPUCTRL

	JSR music_init

	JSR mode_0

	LDA #$00
	STA joy1_data
	STA joy2_data
	LDA #$0F
	STA key1_data
	STA key2_data

cvb_NSHA:	equ $0050
cvb_NSMA:	equ $0051
cvb_CAD:	equ $0052
cvb_C:	equ $0053
cvb_D:	equ $0054
cvb_WTIPO:	equ $0055
cvb_E:	equ $0056
cvb_I:	equ $0057
cvb_K:	equ $0058
cvb_N:	equ $0059
cvb_BOFF:	equ $005a
cvb_P:	equ $005b
cvb_Q:	equ $005c
cvb_R:	equ $005d
cvb_W:	equ $005e
cvb_BOL:	equ $005f
cvb_BPF:	equ $0060
cvb_MBXO:	equ $0061
cvb_#ADX:	equ $0062
cvb_#ADY:	equ $0064
cvb_BSA:	equ $0066
cvb_BSC:	equ $0067
cvb_BSN:	equ $0068
cvb_BST:	equ $0069
cvb_BSW:	equ $006a
cvb_MBA:	equ $006b
cvb_E4V:	equ $006c
cvb_MBS:	equ $006d
cvb_MBT:	equ $006e
cvb_MBW:	equ $006f
cvb_MBX:	equ $0070
cvb_#TBX:	equ $0071
cvb_#TBY:	equ $0073
cvb_DED:	equ $0075
cvb_WDIF:	equ $0076
cvb_DIR:	equ $0077
cvb_MLR:	equ $0078
cvb_MLX:	equ $0079
cvb_NE4:	equ $007a
cvb_EBS:	equ $007b
cvb_MPT:	equ $007c
cvb_MPX:	equ $007d
cvb_MPY:	equ $007e
cvb_COLB:	equ $007f
cvb_#BOY:	equ $0080
cvb_COLX:	equ $0082
cvb_SLOT:	equ $0083
cvb_COOL:	equ $0084
cvb_#J:	equ $0085
cvb_#MBY:	equ $0087
cvb_WRF:	equ $0089
cvb_WFLIP:	equ $008a
cvb_NSM:	equ $008b
cvb_WNUM:	equ $008c
cvb_FASE:	equ $008d
cvb_EBSPD:	equ $008e
cvb_GBC:	equ $008f
cvb_#MLY:	equ $0090
cvb_BSHP:	equ $0092
cvb_TBVX:	equ $0093
cvb_TBVY:	equ $0094
cvb_BSHW:	equ $0095
cvb_#AD:	equ $0096
cvb_#C1:	equ $0098
cvb_#C2:	equ $009a
cvb_#BK:	equ $009c
cvb_#BO:	equ $009e
cvb_WPAUSA:	equ $00a0
cvb_#FP:	equ $00a1
cvb_BSPH:	equ $00a3
cvb_#LD:	equ $00a4
cvb_AN:	equ $00a6
cvb_#T1:	equ $00a7
cvb_#T2:	equ $00a9
cvb_SCROLL_Y:	equ $00ab
cvb_BN:	equ $00ac
cvb_E2:	equ $00ad
cvb_BTRY:	equ $00ae
cvb_#TW:	equ $00af
cvb_FB:	equ $00b1
cvb_RET:	equ $00b2
cvb_#PEW:	equ $00b3
cvb_DIEK:	equ $00b5
cvb_LI:	equ $00b6
cvb_LY:	equ $00b7
cvb_Q1:	equ $00b8
cvb_Q2:	equ $00b9
cvb_Q3:	equ $00ba
cvb_Q4:	equ $00bb
cvb_WACT:	equ $00bc
cvb_PH:	equ $00bd
cvb_INV:	equ $00be
cvb_#POP:	equ $00bf
cvb_S0:	equ $00c1
cvb_S1:	equ $00c2
cvb_S2:	equ $00c3
cvb_S3:	equ $00c4
cvb_S4:	equ $00c5
cvb_PX:	equ $00c6
cvb_QN:	equ $00c7
cvb_PY:	equ $00c8
cvb_RR:	equ $00c9
cvb_SK:	equ $00ca
cvb_BDIR:	equ $00cb
cvb_SY:	equ $00cc
cvb_WA:	equ $00cd
cvb_XB:	equ $00ce
cvb_WR:	equ $00cf
cvb_YB:	equ $00d0
cvb_MBHP:	equ $00d1
cvb_YC:	equ $00d2
cvb_QDEL:	equ $00d3
cvb_MBDIR:	equ $00d4
cvb_SRQ:	equ $00d5
array_SHYC:	equ $00d6
array_STT:	equ $00da
array_#SHY:	equ $010a
array_E4A:	equ $0112
array_E4F:	equ $011a
array_BTX:	equ $0122
array_BTY:	equ $0127
array_E4P:	equ $012c
array_E4W:	equ $0134
array_E4X:	equ $0300
array_#SMY:	equ $0308
array_#STW:	equ $0314
array_EBA:	equ $0374
array_EBT:	equ $037c
array_NEP:	equ $0384
array_#E4Y:	equ $039b
array_EBXV:	equ $03ab
array_EBYV:	equ $03b3
array_R16:	equ $03bb
array_#EBX:	equ $03cb
array_#EBY:	equ $03db
array_SMYY:	equ $03eb
array_RING:	equ $03f1
array_SHA:	equ $0411
array_SHF:	equ $0415
array_SHX:	equ $0419
array_ST:	equ $041d
array_SMA:	equ $045d
array_SMC:	equ $0463
array_SMD:	equ $0469
array_SMF:	equ $046f
array_SMP:	equ $0475
array_SMX:	equ $047b
array_SMZ:	equ $0481
array_SNV:	equ $0487
array_SHVX:	equ $048d
ram_end:
	; BANK ROM 512	' v0.35: textos fixos paginados; gameplay da v0.29 intacto
	; 	' v0.29 candidate: limita lotes de VPOKE durante flashes/cenas de morte
	; 	' para caber no VBlank; nenhuma mecanica ou arte foi alterada.
	; 							' segue TODO no banco 0 (32K) como na v0.14; bancos
	; 							' 1-28 livres p/ fases 2-5 + CHRROM 0-3 p/ tiles
	; 
	; 	'
	; 	' v0.28 (ordem do Saulo): AS 5 FACES + FIM DE JOGO. Mesmo esquema
	; 	'   aprovado (scroll fase 1, mesmos inimigos, miniboss + boss iguais
	; 	'   em todas): 01 A CAMINHO DO PLANETA DE FOGO (espaco), 02 O
	; 	'   PLANETA DE FOGO (lava, nome corrigido!), 03 O CINTURAO DE
	; 	'   ASTEROIDES (espaco; acentos por tile na linha acima da letra,
	; 	'   til=tile 26 / agudo=tile 27 da spritefont), 04 O GERADOR DE
	; 	'   ESCUDOS DE ATLANTIS (tiles da lava + paleta agua $0C/$11/$02/
	; 	'   $01), 05 A BATALHA FINAL COM GORF (espaco). Cartao de fase e
	; 	'   "FASE 0X COMPLETA" genericos (PRINT <1>fase). Vencendo a 05:
	; 	'   telas de vitoria + creditos + "THE END?" e volta p/ a fase 01
	; 	'   (partida nova). SELECT cicla 1>2>3>4>5>1 (debug). POKE $1C,$00
	; 	'   antes dos textos pos-fase/game over (apos lava/agua a pagina
	; 	'   ativa e' a 2 = fonte sairia quebrada).
	; 	'
	; 	' v0.27 (pedido do Saulo): ILHAS PEQUENAS na lava p/ quebrar a
	; 	'   monotonia. So' ilhas 2x2 (4 tiles de 8x8: A=108/109/110/111,
	; 	'   B=119/153/154/155, C=149/150/151/152), 5 por pagina nas MESMAS
	; 	'   posicoes das 3 nametables -> o scroll estilo fase 1 continua
	; 	'   perfeito (o conteudo so' "gira" na tela). Sem canhoes, sem
	; 	'   eventos, sem anel. Teste: manter o scroll perfeito.
	; 	'
	; 	' v0.26 (ordem do Saulo): SCROLL DA FASE 2 = SCROLL DA FASE 1. O motor
	; 	'   de anel (v0.19-v0.24) sai de campo: o que sempre funcionou foi o
	; 	'   esquema da fase 1 (3 nametables identicas + scroll byte). lava_setup
	; 	'   agora so' troca paleta/CHR ($1C=$40) e preenche as 3 paginas com o
	; 	'   mar de lava basico (tiles 96/97/98/99 = a textura 2x2 do proprio
	; 	'   desenho do Saulo). ZERO ilhas, canhoes, eventos e lava_tick
	; 	'   (chamada comentada). Cadaver do anel fica dormente no banco 3.
	; 	'
	; 	' v0.25 (pedido do Saulo): RESET POR SOFTWARE NO GAME OVER. Pericia
	; 	'   do bug das estrelas (figura A/B/B no HISTORICO): a grade = tile
	; 	'   $00 (ceu do gameplay) e tile $20 (titulo) da CHR-RAM pagina 0
	; 	'   com os bytes 08@3 / 28@11 violados por escritor dinamico so-
	; 	'   no-Mesen (fceumm sai limpo); reset do console cura, porque o
	; 	'   boot regrava a CHR-RAM inteira. Entao ao sair do game over o
	; 	'   jogo aperta o proprio botao RESET: JMP ($FFFC) -> vetor ->
	; 	'   START -> prologue -> copy_chrram -> tiles virgem. Fluxo visual
	; 	'   identico (GO -> splash Falcon -> titulo), sintoma morto p/
	; 	'   sempre, zero logica de cura paliativa. Scroll da lava fica
	; 	'   CONGELADO na v0.24 por decisao do Saulo (retomamos depois).
	; 	'
	; 	' v0.24: TORUS DE 31 SLOTS (scroll da lava DEFINITIVO). A v0.23
	; 	'   errou duas vezes ao "matar" os espelhos: (a) flip 8 frames cedo
	; 	'   demais (slot do FUNDO ainda exibia a linha velha = ilhas
	; 	'   mutiladas saindo); (b) $2800 NAO e' morta: o PPU troca p/ a NT
	; 	'   vertical no coarse-Y 30 -> os ultimos (fine) px da tela leem
	; 	'   $2800 slot 0 (a fase 1 sempre foi perfeita justamente porque
	; 	'   suas 3 paginas identicas alimentam esse strip!). Motor final:
	; 	'   flip do slot do TOPO no frame da costura (AND 7 = 7; conteudo
	; 	'   nasce atomico com o 1px que espia no alto) + $2800 slot 0 =
	; 	'   linha (topo+30) na fase 6 = "31o slot" do torus. Prova: NT/$
	; 	'   2800 byte-a-byte == modelo em 1400 frames + strip visual liso.
	; 	' v0.23: SCROLL DA LAVA CERTINHO COMO O DA FASE 1. Autopsia com o
	; 	'   emulador: o scroll do jogo e' byte (0-239) e os NT bits do
	; 	'   PPUCTRL sao SEMPRE 0 -> a tela e' um TORUS de 30 slots do $2000
	; 	'   (as 30 linhas do anel estao todas visiveis; $2400/$2800 nunca
	; 	'   sao lidas). O design 480px da v0.19 era impossivel assim: o
	; 	'   #ld andava +32/linha enquanto o topo visivel anda -32/linha,
	; 	'   e 64/70 writes caiam em slots VISIVEIS (ate' o MEIO da tela) =
	; 	'   ilhas sumindo/surgindo (medido: tabela no HISTORICO.md). Fix:
	; 	'   motor-vida-nova = escrever o slot do FUNDO no frame exato da
	; 	'   costura (scroll_y AND 7 = 7), 32 writes num NMI so', linha-mundo
	; 	'   DECREMENTANDO junto com o scroll (anel 60, wrap 0->59), fase
	; 	'   travada na 1a costura a partir do scroll_y. Espelhos mortos.
	; 	' v0.22: canhoes extirpados do DATA INLINE (o lava_layout.bas.inc
	; 	'   era carta morta - NINGUEM o inclui!). Anel re-escrito: leitura
	; 	'   sequencial c/ shadow 16-bit (r*32 em 8-bit corrompia tudo antes),
	; 	'   linha replicada nas 3 paginas ($2000/$2400/$2800), 6 eventos de
	; 	'   16 writes. Prova: janela circular perfeita + 0 tiles de canhao.
	; 	' v0.20: fase 2 = fase 1 c/ cenario de lava. Canhoes removidos;
	; 	'   stream do anel em quartos (16 writes/evento); PPUBUF $40->$90 no
	; 	'   build.sh (burst estourava o buffer -> WRTVRM JMP wait -> frames
	; 	'   perdidos -> fase lerda! medido: scroll 210/300 -> 598/600).
	; 	' v0.19.2: SELECT alterna a fase (debug); fim do pulso de paleta do
	; 	'   lava; clear_nts na volta p/ fase 1 (lixo do anel nas nametables).
	; 	'   ATENCAO: FOR com TO > 254 nunca termina no CVBasic (8-bit wrap)!
	; 	' v0.19: FASE 02 - PLANETA DE LAVA. Cerimonia pos-boss -> FASE 01
	; 	'   COMPLETA -> cartao FASE 02 -> lava em anel de 60 meta-linhas com
	; 	'   streaming dual-write ($2000+$2800, immune a mirroring divergente).
	; 	'   Canhoes BG mirando o jogador; pulso $16/$17; inimigos reciclados.
	; 	'   Gate fase=1 p/ score/vidas; START do game over volta a Falcon.
	; 	'
	; 	' v0.18 (pedido do Saulo): GAME OVER retocado + CARTAO DE FASE.
	; 	'   "GAMEOVER" junto centralizado (tiles 214-221 em $214C-53); frases
	; 	'   com 1 linha de espaco (linhas 10/12/14/16); tela de game over entra
	; 	'   em FADE por palette cycling (rampa fade_tbl, mesma da Falcon). START
	; 	'   no game over agora cai em begin_game -> stage_card -> jogo (retry
	; 	'   direto, sem passar no titulo). stage_card: tela preta "FASE 01 / A
	; 	'   CAMINHO DO PLANETA DE FOGO" central, fade-in, sai com START (corte
	; 	'   seco) ou sozinha apos ~4s (com fade-out).
	; 	'
	; 	' v0.17 (pedido do Saulo): FONTE DO SAULO EM TUDO + HUD do placar no ar.
	; 	'   Spritefont dele (uploads/Sprite_font.png) vira a fonte unica do jogo
	; 	'   via CHRROM PATTERN 32 (sobrescreve a fonte default do CVBasic;
	; 	'   pixels valor 3 = paleta identica). "apresenta"->"APRESENTA" (maiusc.,
	; 	'   glifos 182-188 do CHRROM 1). "GAME OVER" usa os tiles estilizados
	; 	'   214-221 da folha dele. HUD: placar/vidas liam tiles 128-147 = ARTE DA
	; 	'   LOGO (sprites 8x16, byte OAM par -> tabela $0000! bug desde o v0.15,
	; 	'   provado com captura) -> digitos reais agora nos pares 192-211
	; 	'   (codigo: +128 virou +192). Gerador: gera_fonte.py.
	; 	'
	; 	' v0.16 (feedback do Saulo): SPLASH FALCON SOFT + acertos do titulo.
	; 	'   (a) Splash no boot: logo oficial da Falcon (128x80, veio "montada"
	; 	'   num PNG separado - a folha Falconsoft.png 128x48 estava desmontada
	; 	'   p/ aproveitar tiles; a montagem nossa bateu ~90% antes de chegar a
	; 	'   oficial). Vai numa CHRROM 1 PROPRIA = CHRRAM pagina 1 (POKE $1C,$20
	; 	'   = BANKSEL bits 5-6 do CHR-RAM; o NMI restaura ORA CHRRAM_BANK a
	; 	'   cada frame), 86 tiles unicos (96-181) + 7 glifos da fonte CVBasic
	; 	'   (182-188) p/ "apresenta" minusculo. Entrada/saida com FADE POR
	; 	'   PALETTE CYCLING nos entries $3F02/$3F03 (7 passos x 4 frames:
	; 	'   0F,0F->0F,00->00,00->00,10->10,10->10,20->10,30). Qualquer botao
	; 	'   corta DIRETO p/ o titulo; senao ~3.4s e transicao suave igual.
	; 	'   Game over volta p/ title_screen SEM splash (hook so no boot).
	; 	'   (b) Logo do titulo NOVA (title-space.png do Saulo, sem a barra de
	; 	'   katakana do Caravan Blast): SPACE branco/cinza (pal1), cometa teal
	; 	'   (pal3), BLAST vermelho/vermelho-escuro (pal2), estrelas soltas.
	; 	'   92 tiles unicos contiguos 96-187 (bullet 212 intacto), paletas
	; 	'   escolhidas por quad 16x16 com ZERO colisao de cores (medido), e os
	; 	'   atributos gerados por script (gera_title2.py).
	; 	'   (c) "APERTE START" todo branco: o RT (e o ER de APERTE) caiam em
	; 	'   quads do pal0 = idx3 $00 = cinza escuro (o PRINT usa sempre idx3).
	; 	'   Bytes de atributo corrigidos: BL/BR das colunas 10-21 -> pal2.
	; 	'   (d) Estrelas do fundo SUBSTITUIDAS pelas da folha nova (25 tiles,
	; 	'   dots de ate 6px com corrida <=3) - patterns 1-25, mesma convencao
	; 	'   de indices (teal->1 branco->2 cinza->3) = mesmo look azulado.
	; 	'   (e) Boot sem flash cinza: 2 patches no prologue via build.sh
	; 	'   (video so liga no SCREEN ENABLE + $3F00=$0F antes da copia do CHR;
	; 	'   medido no fceumm: 17 frames cinza -> 3 de deteccao NTSC).
	; 	'   Validacao: v12 17/17, v13 boss, v08 mini/HUD, v04 full = TUDO OK;
	; 	'   game over conferido; skip com botao generico (A) no frame 77.
	; 	'   Rodape do titulo agora sai branco (pal3 virou teal do cometa).
	; 
	; 	'
	; 	' SPACE BLAST - port NES (CVBasic) da demo HTML5 de Saulo San
	; 	' Baseado nos assets/logica originais (saulosan.com.br/caravanblast)
	; 	'
	; 	' v0.13 (feedback do Saulo): (a) o boss.png era um SPRITESHEET de 2
	; 	'   frames (96x64 cada), NAO 2 naves gemeas! Boss = UMA nave 96x64
	; 	'   NO ALTO, 100% Background: ceu todo preto + tiles na tabela $1000
	; 	'   com flip da ppu_ctrl ($B8) so durante a luta (sprites 8x16 leem a
	; 	'   tabela pelo bit0 do byte OAM: nada afetados). "Animacao" = PULSO
	; 	'   DE PALETA (ideia do autor: cor clara $38 cicla 38/28/18/28).
	; 	'   Balanco lateral classico de chefe-de-BG: SCROLL x fino +-16px
	; 	'   (ceu preto = wrap invisivel); tiros/laser/hitbox acompanham.
	; 	'   (b) BUG DOS TEXTOS da v0.12 explicado: PRINT escreve o codigo
	; 	'   ASCII DIRETO como tile - a FONTE mora nos tiles 32-95 da $0000,
	; 	'   exatamente onde a arte do boss tinha ido parar! (e caiu tambem o
	; 	'   tile 0 do $1000: ceu preto virou grade 2.0). Arte realocada p/
	; 	'   $1000 (257+, 272+, 436-511 = ex-asas); fonte 100% restaurada.
	; 	'   (c) duas armadilhas do codegen CVBasic mapeadas: byte var >=128
	; 	'   sign-extende ao ir p/ var 16-bit (#tbx 143 -> -113!), e somar o
	; 	'   byte-wrap 240 ("-16") em 16-bit vira +240. Resolvido com #bo.
	; 	' v0.12: fechamento da fase 01! (a) smalls: cota de MAX 3 tiros deles
	; 	'   na tela (tags ebt + contador nsm no eb_spawn/despawn). (b) mini-
	; 	'   boss agora para em y=72 e solta o LASER (arte do Saulo) que desce
	; 	'   rapido ao cruzar o meio exato (centro x=128: nasce e parqueia
	; 	'   em mbx=112). (c) BOSS 96x128 do
	; 	'   Saulo a cada 4 ondas-de-cada-tipo: hibrido BG (centro 48x128 +
	; 	'   strips, 102 tiles unicos $0000) + sprites (asas: 18 tiles $1000,
	; 	'   lado dir = flip H) - sprite puro era inviavel: 12 sprites por
	; 	'   scanline, limite do NES e 8! Fases: leques alternados das asas,
	; 	'   saraivada de posicoes/velocidades variadas, 3 lasers do meio;
	; 	'   tudo com trava no pool de 8 tiros. HP 120, +5000. Scroll congela
	; 	'   (boss e BG); pal BG1/pal2 ganham $03/$23/$38 e voltam na morte.
	; 	'   (d) tiro do player = nova arte do Saulo (fis 472/474, 217/219);
	; 	'   pal3 agora ciano ($1C/$3C/$30) p/ tiro+laser ficarem fi as artes.
	; 	' v0.12a (bug da grade): a arte BG do boss usava os tiles 32-95 do
	; 	'   banco $0000 - MAS o 32 ($20) e o byte que a CVBasic preenche a
	; 	'   nametable no boot (e o "espaco" do PRINT), e em branco na v0.11!
	; 	'   Todo o fundo "vazio" virou uma grade de pedacinhos do boss.
	; 	'   Forense: pixel-match do screenshot -> tile fis 32. Remapeada a
	; 	'   arte p/ 33-95 + 213-251 (gera_boss.py); o 32 voltou a ser vazio.
	; 	' v0.11: onda dos smalls (roxo) agora e 3+3: o 2o grupo entra logo
	; 	'   apos o 1o, no lado OPOSTO da tela (slots/OAM ampliados: smalls
	; 	'   0-5, sprites 4-15; por isso tiros->16-20, shards->21-24, tiros
	; 	'   inimigos->25-32, explosao->33/34, placar->35-39, vidas->40).
	; 	'   MINIBOSS NOVO (arte do Saulo, 32x32, 2 frames, tiles 396-427):
	; 	'   1 a cada 4 ondas; entra pelo topo, desce ate o meio e patrulha
	; 	'   esq/dir lancando aneis de 8 tiros (so dispara qdo o pool de
	; 	'   tiros inimigos esvazia = trava anti-slowdown); HP 48, +500 pts.
	; 	'   Usa os slots OAM 41-48 do enemy4 (nunca coexistem). Durante a
	; 	'   luta pal2 ganha as cores da arte ($03/$23/$38) e volta ao
	; 	'   normal ao morrer (chama da nave fica roxa nesse periodo).
	; 	' v0.10: estrelas de vez! Diagnostico definitivo (probe + medicao no
	; 	'   fceumm): o vizinho de scroll vertical da $2000 nesta ROM e a $2800
	; 	'   (a $2400 e ESPELHO da $2000 aqui). A v0.9 preencheu a $2400 (no-op)
	; 	'   e deixou a $2800 vazia = faixa sem estrelas cruzando a tela.
	; 	'   Solucao a prova de emulador: layout unico gravado nas TRES ($2000,
	; 	'   $2400 e $2800). Enemy4: atira ao cruzar a faixa topo-meio (y 64-
	; 	'   127) em vez de timer; onda com 8 naves a 0.5s (arrays/OAM 41-56);
	; 	'   colisao nave-inimigo DESTROI o inimigo (1 tiro de dano: small+100,
	; 	'   shard+120 c/ anel, enemy4+300).
	; 	' v0.9: fundo de estrelas com LOOP PERFEITO (a raiz do bug: a "NT2" era
	; 	'   escrita em $2800, que no espelhamento "vertical arrangement" da ROM
	; 	'   e ESPELHO da $2000; a vizinha real do wrap vertical e a $2400, que
	; 	'   nunca tinha sido preenchida!). Agora o layout e sorteado 1x no boot
	; 	'   e desenhado byte a byte igual nas 2 nametables ($2000/$2400).
	; 	'   Enemy4 (ex-"meteoro") mais rapido: e4v 10 -> 14 (+jitter por slot).
	; 	'   Pausa entre ondas 70 -> 30 frames (jogo mais desafiador).
	; 	' v0.8: ajustes no enemy4: sprite ESTATICO (economiza 12 tiles CHR),
	; 	'   agora ATIRA 1x (mirado, ~2.5s apos entrar), velocidade levemente
	; 	'   variada por slot, sprites movidos p/ 41-48 (33-39 eram o HUD de
	; 	'   sprites = placar/vidas, por isso "apagavam"!), e guarda ANTI-WRAP:
	; 	'   enemy4/shard/small escondidos enqto y<1 (nao nascem mais embaixo).
	; 	' v0.7: novo inimigo ENEMY4 (Enemy4.gif do autor): onda de 4 naves que
	; 	'   cruzam a tela do alto a base bem devagar (movimento de meteoro),
	; 	'   spawn 1.5s, cada uma numa das 4 colunas (32/88/144/200) embaralhadas
	; 	'   sem repeticao. Rodizio: small -> shard -> enemy4. 300 pts.
	; 	' v0.6: SPACE BLAST - novo nome + nova tela de titulo (logo 128x48 do
	; 	'   autor: SPACE branco, BLAST! ciano/teal, APERTE START branco piscando,
	; 	'   rodape ciano "2026 • FALCON SOFT"). Atributos da titulo reescritos a
	; 	'   cada entrada; begin_game zera a tabela de atributos (heranca visual).
	; 	' v0.5: TRILHAS SONORAS - arranjos NES das MP3 originais (titulo ~96bpm
	; 	'   G#m e fase 1 ~174bpm Gm) gerados por music/compose.py p/ o player do
	; 	'   CVBasic (PLAY FULL: pulso1=melodia, pulso2=arp, triangulo=baixo,
	; 	'   ruido=bateria). Titulo toca mus_title; jogo toca mus_stage1; game
	; 	'   over silencia. Performance medida: 99.7% do frame budget com musica.
	; 	'
	; 	' v0.2: corrige tiros inimigos (posicao nunca gravada p/ bug de codegen do
	; 	'   *16 em array 16-bit + mira com sinal quebrado), shard sumindo ao cruzar
	; 	'   x=128 (overflow 8-bit sinal na saida diagonal), 3 smalls/onda com frame
	; 	'   estatico, e divisoes /16 rapidas (posicoes com bias +256, sem _div16s).
	; 	' v0.1: inicio do game - ondas 01 (small formation) e 02 (shard formation)
	; 	' Direcional: move a nave. Botao B (segurar): rajada de 5 tiros.
	; 	' Start: inicia. Vidas: 3.
	; 	'
	; 	' Compilar:  cvbasic --nes space-blast.bas space-blast.asm
	; 	' Montar:    gasm80 space-blast.asm -o space-blast.nes
	; 	'
	; 
	; 	DIM st(64)		' tabela seno (zigzag dos smalls)
	; 	DIM boff,bdir,bpf	' BOSS: balanco lateral (+-16px), direcao, fase do pulso
	; 	DIM rr,q1,q2,q3,q4	' v0.14: rodizio OAM anti-flicker (Saulo) (k ja' existe: eb_spawn)
	; 	DIM diek			' v0.15: proc bancado pede morte da nave (GOTO externo proibido)
	; 	DIM r16(16)		' anel de slots fisicos (v0.14): smalls 0-11, shards 12-15
	; 	DIM shyc(4)		' v0.14: cache px do y dos shards (anel desenha todo frame)
	; 	DIM gbc			' contador do sky_clear (60 passos)
	; 	DIM #bk			' cursor de varredura do ceu preto (sky_clear)
	; 	DIM #bo			' boff com SINAL em 16 bits (p/ #tbx: byte >=128
	; 						' sign-extendia: asa dir. cuspia tiro em x=-113!)
	; 	DIM nep(23)		' tiles de estrela nao-vazios (sorteio harmonico)
	; 	DIM stt(48)		' layout de estrelas (gerado 1x no boot): tile por setor
	; 	DIM #stw(48)		' layout de estrelas: offset do setor na nametable (0-959)
	; 	DIM fase,bsc,ph,sy,srq,wr,wrf,ring(32)	' v0.23: fase atual, anel lava=linha-
	; 							'   mundo da costura + trava de fase, contador cerimonia
	; 	DIM r,q,e2		' scratch do fundo de estrelas / mapa da logo
	; 	DIM sk			' indice do layout de estrelas
	; 	DIM btx(5)		' tiros do player: x
	; 	DIM bty(5)		' tiros do player: y (0 = livre)
	; 	DIM sma(6)		' smalls: ativo? (v0.11: 6 slots p/ onda 3+3)
	; 	DIM smx(6)		' smalls: x
	; 	DIM #smy(6)		' smalls: (y+256)*16 (sempre positivo = /16 rapida!)
	; 	DIM smz(6)		' smalls: fase do zigzag (0-63)
	; 	DIM smp(6)		' smalls: x central do zigzag
	; 	DIM smc(6)		' smalls: amplitude do zigzag
	; 	DIM smd(6)		' smalls: timer do tiro
	; 	DIM smf(6)		' smalls: tiros dados
	; 	DIM snv(6)		' smalls: velocidade y (1/16 px/frame)
	; 	DIM smyy(6)		' v0.14: cache do y em pixel (anel desenha todo frame)
	; 	DIM sha(4)		' shards: ativo?
	; 	DIM shx(4)		' shards: x
	; 	DIM #shy(4)		' shards: (y+256)*16 (sempre positivo)
	; 	DIM shf(4)		' shards: fase (0 desce, 1 sai na diagonal)
	; 	DIM shvx(4)		' shards: vx da saida (+2/-2)
	; 	DIM e4a(8)		' enemy4: ativo?
	; 	DIM e4x(8)		' enemy4: x
	; 	DIM #e4y(8)		' enemy4: (y+256)*16
	; 	DIM e4p(8)		' enemy4: colunas embaralhadas (2 permutacoes de 4)
	; 	DIM e4v			' enemy4: velocidade base de descida (1/16 px/frame)
	; 	DIM e4w(8)		' enemy4: velocidade individual (base + jitter)
	; 	DIM e4f(8)		' enemy4: 1 = ainda nao atirou (atira ao cruzar y=64)
	; 	DIM eba(8)		' tiros inimigos: ativo?
	; 	DIM ebt(8)		' tiros inimigos: dono (1 = small) - cota v0.12
	; 	DIM #ebx(8)		' tiros inimigos: (x+256)*16
	; 	DIM #eby(8)		' tiros inimigos: (y+256)*16
	; 	DIM ebxv(8)		' tiros inimigos: vx (1/16)
	; 	DIM ebyv(8)		' tiros inimigos: vy (1/16)
	; 	DIM xb,yc		' scratch de pixel p/ sprites
	; 	DIM k			' indice do eb_spawn (nao pode usar c!)
	; 	DIM #c1,#c2		' scratch assinado p/ colisoes
	; 	DIM #t1,#t2		' pixel biased dos tiros inimigos (div reuse)
	; 	DIM s0,s1,s2,s3,s4	' placar em digitos (10000..1), sem divisoes!
	; 
	; 	SIGNED ebxv,ebyv,shvx,e,#tbx,#tby,#ad,#adx,#ady,#c1,#c2,#t1,#t2
	; 
	; 	RESTORE sintab
	LDA #cvb_SINTAB
	LDY #cvb_SINTAB>>8
	STA read_pointer
	STY read_pointer+1
	; 	FOR c = 0 TO 63
	LDA #0
	STA cvb_C
cv1:
	; 		READ BYTE st(c)	' READ puro le 16 bits (2 DATA por vez) e corrompe a tabela!
	LDA #array_ST
	CLC
	ADC cvb_C
	TAX
	LDA #array_ST>>8
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	JSR _read8
	LDY #0
	STA (temp),Y
	; 	NEXT c
	INC cvb_C
	LDA cvb_C
	CMP #64
	BCC.L cv1
	; 	RESTORE nep_tab
	LDA #cvb_NEP_TAB
	LDY #cvb_NEP_TAB>>8
	STA read_pointer
	STY read_pointer+1
	; 	FOR c = 0 TO 22
	LDA #0
	STA cvb_C
cv2:
	; 		READ BYTE nep(c)
	LDA #array_NEP
	CLC
	ADC cvb_C
	TAX
	LDA #array_NEP>>8
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	JSR _read8
	LDY #0
	STA (temp),Y
	; 	NEXT c
	INC cvb_C
	LDA cvb_C
	CMP #23
	BCC.L cv2
	; 	RESTORE oam_ring
	LDA #cvb_OAM_RING
	LDY #cvb_OAM_RING>>8
	STA read_pointer
	STY read_pointer+1
	; 	FOR c = 0 TO 15
	LDA #0
	STA cvb_C
cv3:
	; 		READ BYTE r16(c)
	LDA #array_R16
	CLC
	ADC cvb_C
	TAX
	LDA #array_R16>>8
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	JSR _read8
	LDY #0
	STA (temp),Y
	; 	NEXT c
	INC cvb_C
	LDA cvb_C
	CMP #16
	BCC.L cv3
	; 
	; 	GOSUB silence
	JSR cvb_SILENCE
	; 	PLAY FULL		' habilita o player de musica (MOD=5). music_tick roda no NMI.
	LDA #5
	STA music_mode
	; 
	; 	' Layout das estrelas gerado 1x aqui no boot: as 2 nametables do scroll
	; 	' recebem EXATAMENTE o mesmo desenho = loop perfeito. A vizinha visivel
	; 	' no wrap vertical e a $2400 (a $2800 e espelho da $2000 neste modo de
	; 	' espelhamento - era ai que morava o bug do "cenario trocando de lugar").
	; 	sk = 0
	LDA #0
	STA cvb_SK
	; 	FOR r = 0 TO 5
	STA cvb_R
cv4:
	; 		FOR q = 0 TO 7
	LDA #0
	STA cvb_Q
cv5:
	; 			stt(sk) = nep(RANDOM(23))
	JSR random
	LDX #23
	STX temp
	LDX #0
	STX temp+1
	JSR _mod16
	CLC
	ADC #array_NEP
	TAX
	TYA
	ADC #array_NEP>>8
	TAY
	TXA
	JSR _peek8
	PHA
	LDA #array_STT
	CLC
	ADC cvb_SK
	TAX
	LDA #array_STT>>8
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	PLA
	LDY #0
	STA (temp),Y
	; 			#tw = r * 5 + RANDOM(5)
	LDA cvb_R
	LDX #5
	STX temp
	LDX #0
	STX temp+1
	JSR _mul16
	PHA
	TYA
	PHA
	JSR random
	LDX #5
	STX temp
	LDX #0
	STX temp+1
	JSR _mod16
	STA temp
	STY temp+1
	PLA
	TAY
	PLA
	CLC
	ADC temp
	TAX
	TYA
	ADC temp+1
	TAY
	TXA
	STA cvb_#TW
	STY cvb_#TW+1
	; 			#tw = #tw * 32 + q * 4 + RANDOM(4)
	STY temp
	ASL A
	ROL temp
	ASL A
	ROL temp
	ASL A
	ROL temp
	ASL A
	ROL temp
	ASL A
	ROL temp
	LDY temp
	PHA
	TYA
	PHA
	LDA cvb_Q
	LDY #0
	STY temp
	ASL A
	ROL temp
	ASL A
	ROL temp
	LDY temp
	STA temp
	STY temp+1
	PLA
	TAY
	PLA
	CLC
	ADC temp
	TAX
	TYA
	ADC temp+1
	TAY
	TXA
	PHA
	TYA
	PHA
	JSR random
	AND #3
	LDY #0
	STA temp
	STY temp+1
	PLA
	TAY
	PLA
	CLC
	ADC temp
	TAX
	TYA
	ADC temp+1
	TAY
	TXA
	STA cvb_#TW
	STY cvb_#TW+1
	; 			#stw(sk) = #tw
	LDA cvb_SK
	ASL A
	LDY #0
	BCC $+3
	INY
	CLC
	ADC #array_#STW
	TAX
	TYA
	ADC #array_#STW>>8
	TAY
	TXA
	STA temp
	STY temp+1
	LDA cvb_#TW
	LDY cvb_#TW+1
	TAX
	TYA
	LDY #1
	STA (temp),Y
	TXA
	DEY
	STA (temp),Y
	; 			sk = sk + 1
	INC cvb_SK
	; 		NEXT q
	INC cvb_Q
	LDA cvb_Q
	CMP #8
	BCC.L cv5
	; 	NEXT r
	INC cvb_R
	LDA cvb_R
	CMP #6
	BCC.L cv4
	; 
	; 	'
	; 	' TELA DE TITULO
	; 	'
	; 	' v0.16: splash FALCON SOFT (so no boot; game over volta direto
	; 	' p/ title_screen sem passar aqui)
	; 	restart_boot:			' v0.19: START no game over volta ao INICIO do jogo
cvb_RESTART_BOOT:
	; 	BANK SELECT 1
	LDA #0
	ORA CHRRAM_BANK
	STA BANKSEL
	; 	GOSUB falcon_splash
	JSR cvb_FALCON_SPLASH
	; 	BANK SELECT 0
	LDA #31
	ORA CHRRAM_BANK
	STA BANKSEL
	; 
	; title_screen:
cvb_TITLE_SCREEN:
	; 	BANK SELECT 2		' v0.15: PLAY grava o banco (le $BFFF) p/ o player do NMI
	LDA #1
	ORA CHRRAM_BANK
	STA BANKSEL
	; 	PLAY mus_title		' trilha da apresentacao (loop)
	LDA #cvb_MUS_TITLE
	LDY #cvb_MUS_TITLE>>8
	JSR music_play
	; 	CLS
	JSR cls
	; 	PALETTE LOAD game_palette_title
	LDA #0
	STA pointer
	LDA #63
	STA pointer+1
	LDA #32
	STA temp2
	LDA #cvb_GAME_PALETTE_TITLE
	STA temp
	LDA #cvb_GAME_PALETTE_TITLE>>8
	STA temp+1
	JSR LDIRVM
	; 	SCREEN DISABLE
	JSR DISSCR
	; 	GOSUB stars_fill
	JSR cvb_STARS_FILL
	; 
	; 	' Logo SPACE BLAST (128x48): tiles linhas 6-11, colunas 8-23
	; 	' v0.16: art nova (sem katakana), paletas por quad, estrelas da folha nova
	; 	RESTORE logo_map
	LDA #cvb_LOGO_MAP
	LDY #cvb_LOGO_MAP>>8
	STA read_pointer
	STY read_pointer+1
	; 	FOR i = 0 TO 95
	LDA #0
	STA cvb_I
cv6:
	; 		READ BYTE e
	JSR _read8
	STA cvb_E
	; 		IF e <> 255 THEN
	TAX
	AND #128
	BPL cv8
	LDA #255
cv8:
	TAY
	TXA
	SEC
	SBC #255
	STA temp
	TYA
	SBC #0
	ORA temp
	BEQ.L cv7
	; 			#tw = i / 16 + 6
	LDA cvb_I
	LDY #0
	LDX #16
	STX temp
	LDX #0
	STX temp+1
	JSR _div16
	CLC
	ADC #6
	TAX
	TYA
	ADC #0
	TAY
	TXA
	STA cvb_#TW
	STY cvb_#TW+1
	; 			#tw = #tw * 32
	STY temp
	ASL A
	ROL temp
	ASL A
	ROL temp
	ASL A
	ROL temp
	ASL A
	ROL temp
	ASL A
	ROL temp
	LDY temp
	STA cvb_#TW
	STY cvb_#TW+1
	; 			e2 = i AND 15
	LDA cvb_I
	AND #15
	STA cvb_E2
	; 			#tw = #tw + e2 + 8
	LDA cvb_#TW
	CLC
	ADC cvb_E2
	TAX
	TYA
	ADC #0
	TAY
	TXA
	CLC
	ADC #8
	TAX
	TYA
	ADC #0
	TAY
	TXA
	STA cvb_#TW
	STY cvb_#TW+1
	; 			VPOKE $2000 + #tw, e
	LDA cvb_E
	PHA
	LDA cvb_#TW
	CLC
	TAX
	TYA
	ADC #32
	TAY
	TXA
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 		END IF
cv7:
	; 	NEXT i
	INC cvb_I
	LDA cvb_I
	CMP #96
	BCC.L cv6
	; 
	; 	' Atributos v0.16: pal1=SPACE, pal2=BLAST, pal3=cometa; pal0=estrelas.
	; 	VPOKE $23CA,$70		' logo rows 6-7
	LDA #112
	PHA
	LDA #202
	LDY #35
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $23CB,$50
	LDA #80
	PHA
	LDA #203
	LDY #35
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $23CC,$D0
	LDA #208
	PHA
	LDA #204
	LDY #35
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $23CD,$F0
	LDA #240
	PHA
	LDA #205
	LDY #35
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $23D2,$BB		' logo rows 8-11
	LDA #187
	PHA
	LDA #210
	LDY #35
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $23D3,$AA
	LDA #170
	PHA
	LDA #211
	LDY #35
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $23D4,$AA
	LDA #170
	PHA
	LDA #212
	LDY #35
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $23D5,$EE
	LDA #238
	PHA
	LDA #213
	LDY #35
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $23EA,$90		' "APERTE START" (py176-183) -> pal2 = BRANCO em tudo
	LDA #144
	PHA
	LDA #234
	LDY #35
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $23EB,$A8
	LDA #168
	PHA
	LDA #235
	LDY #35
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $23EC,$A8
	LDA #168
	PHA
	LDA #236
	LDY #35
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $23ED,$A8
	LDA #168
	PHA
	LDA #237
	LDY #35
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $23F1,$C0		' rodape (py216-223, quads inf.) -> pal3
	LDA #192
	PHA
	LDA #241
	LDY #35
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $23F2,$F0
	LDA #240
	PHA
	LDA #242
	LDY #35
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $23F3,$F0
	LDA #240
	PHA
	LDA #243
	LDY #35
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $23F4,$F0
	LDA #240
	PHA
	LDA #244
	LDY #35
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $23F5,$F0
	LDA #240
	PHA
	LDA #245
	LDY #35
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $23F6,$30
	LDA #48
	PHA
	LDA #246
	LDY #35
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	WAIT			' drena o buffer da PPU (escritas demais perdem!)
	JSR wait
	; 	SCREEN ENABLE
	JSR ENASCR
	; 
	; 	PRINT AT 714,"APERTE START"
	JSR print_string_cursor_constant
	DB $ca,$02,$0c
	DB $41,$50,$45,$52,$54,$45,$20,$53
	DB $54,$41,$52,$54
	; 	PRINT AT 871,"2026   FALCON SOFT"
	JSR print_string_cursor_constant
	DB $67,$03,$12
	DB $32,$30,$32,$36,$20,$20,$20,$46
	DB $41,$4c,$43,$4f,$4e,$20,$53,$4f
	DB $46,$54
	; 	VPOKE $236C,188		' "•" central do rodape (NT1: AT 871+5 = 876)
	LDA #188
	PHA
	LDA #108
	LDY #35
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 
	; title_wait:
cvb_TITLE_WAIT:
	; 	' v0.30: o loop de espera e a historia ficam no banco 1; o banco 0
	; 	' conserva somente a troca de banco; a historia termina em reset completo.
	; 	BANK SELECT 1
	LDA #0
	ORA CHRRAM_BANK
	STA BANKSEL
	; 	GOSUB title_idle_wait
	JSR cvb_TITLE_IDLE_WAIT
	; 	BANK SELECT 0
	LDA #31
	ORA CHRRAM_BANK
	STA BANKSEL
	; 	IF sk = 0 THEN GOTO begin_game
	LDA cvb_SK
	BNE.L cv9
	JMP cvb_BEGIN_GAME
cv9:
	; 	GOTO go_reset
	JMP cvb_GO_RESET
	; 
	; 	'
	; 	' INICIO DO JOGO
	; 	'
	; begin_game:
cvb_BEGIN_GAME:
	; 	fase = 1			' v0.19: partida nova = sempre fase 1
	LDA #1
	STA cvb_FASE
	; 	BANK SELECT 1		' v0.18: cartao "FASE 01" antes de comecar (banco 1)
	LDA #0
	ORA CHRRAM_BANK
	STA BANKSEL
	; 	GOSUB stage_card
	JSR cvb_STAGE_CARD
	; 	BANK SELECT 0
	LDA #31
	ORA CHRRAM_BANK
	STA BANKSEL
	; begin_stage:			' v0.19: entrada de fase sem cartao (a dela ja passou)
cvb_BEGIN_STAGE:
	; 	BANK SELECT 2		' v0.15: idem (trilha no banco 2)
	LDA #1
	ORA CHRRAM_BANK
	STA BANKSEL
	; 	PLAY mus_stage1		' trilha da fase 1 (loop)
	LDA #cvb_MUS_STAGE1
	LDY #cvb_MUS_STAGE1>>8
	JSR music_play
	; 	CLS
	JSR cls
	; 
	; 	' Fundo (v0.28): fases impares = espaco / 2 = LAVA / 4 = AGUA (banco 3)
	; 	SCREEN DISABLE
	JSR DISSCR
	; 	IF (fase AND 1) = 0 THEN	' fases pares: 2 = lava, 4 = agua
	LDA cvb_FASE
	AND #1
	BNE.L cv10
	; 		BANK SELECT 3		' tiles da lava/agua moram no banco 3
	LDA #2
	ORA CHRRAM_BANK
	STA BANKSEL
	; 		IF fase = 2 THEN GOSUB lava_setup
	LDA cvb_FASE
	CMP #2
	BNE.L cv11
	JSR cvb_LAVA_SETUP
cv11:
	; 		IF fase = 4 THEN GOSUB agua_setup
	LDA cvb_FASE
	CMP #4
	BNE.L cv12
	JSR cvb_AGUA_SETUP
cv12:
	; 		BANK SELECT 0
	LDA #31
	ORA CHRRAM_BANK
	STA BANKSEL
	; 	ELSE
	JMP cv13
cv10:
	; 		PALETTE LOAD game_palette_play
	LDA #0
	STA pointer
	LDA #63
	STA pointer+1
	LDA #32
	STA temp2
	LDA #cvb_GAME_PALETTE_PLAY
	STA temp
	LDA #cvb_GAME_PALETTE_PLAY>>8
	STA temp+1
	JSR LDIRVM
	; 		POKE $1C,$00		' espaco = pagina 0 do CHR-RAM
	LDA #0
	PHA
	LDA #28
	LDY #0
	STA temp
	STY temp+1
	PLA
	STA (temp),Y
	; 		' v0.19.2: lava deixa lixo no $2000/$2800 (stars_fill so toca
	; 		' slots com tile 0); zera as tres paginas (proc mora no banco 1)
	; 		BANK SELECT 1
	TYA
	ORA CHRRAM_BANK
	STA BANKSEL
	; 		GOSUB clear_nts
	JSR cvb_CLEAR_NTS
	; 		BANK SELECT 0
	LDA #31
	ORA CHRRAM_BANK
	STA BANKSEL
	; 	END IF
cv13:
	; 	FOR i = 0 TO 63		' zera atributos herdados da tela de titulo
	LDA #0
	STA cvb_I
cv14:
	; 		VPOKE $23C0 + i,0	' (das 3 nametables!)
	LDA #0
	PHA
	LDA cvb_I
	LDY #0
	CLC
	ADC #192
	TAX
	TYA
	ADC #35
	TAY
	TXA
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 		VPOKE $27C0 + i,0
	LDA #0
	PHA
	LDA cvb_I
	LDY #0
	CLC
	ADC #192
	TAX
	TYA
	ADC #39
	TAY
	TXA
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 		VPOKE $2BC0 + i,0
	LDA #0
	PHA
	LDA cvb_I
	LDY #0
	CLC
	ADC #192
	TAX
	TYA
	ADC #43
	TAY
	TXA
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	NEXT i
	INC cvb_I
	LDA cvb_I
	CMP #64
	BCC.L cv14
	; 	WAIT			' drena o buffer da PPU antes de mais escritas
	JSR wait
	; 	IF (fase AND 1) = 1 THEN GOSUB stars_fill	' v0.28: so no espaco
	LDA cvb_FASE
	AND #1
	CMP #1
	BNE.L cv15
	JSR cvb_STARS_FILL
cv15:
	; 	SCREEN ENABLE
	JSR ENASCR
	; 
	; 	IF fase = 1 THEN		' v0.19.1: placar/vidas sobrevivem a troca de fase
	LDA cvb_FASE
	CMP #1
	BNE.L cv16
	; 		s0 = 0
	LDA #0
	STA cvb_S0
	; 		s1 = 0
	STA cvb_S1
	; 		s2 = 0
	STA cvb_S2
	; 		s3 = 0
	STA cvb_S3
	; 		s4 = 0
	STA cvb_S4
	; 		GOSUB update_score
	JSR cvb_UPDATE_SCORE
	; 		li = 3
	LDA #3
	STA cvb_LI
	; 		GOSUB update_lives
	JSR cvb_UPDATE_LIVES
	; 	END IF
cv16:
	; 
	; 	px = 120		' posicao da nave
	LDA #120
	STA cvb_PX
	; 	py = 200
	LDA #200
	STA cvb_PY
	; 	dir = 0
	LDA #0
	STA cvb_DIR
	; 	ret = 0
	STA cvb_RET
	; 	an = 0
	STA cvb_AN
	; 	slot = 0
	STA cvb_SLOT
	; 	inv = 0			' invencibilidade (pisca)
	STA cvb_INV
	; 	ded = 0			' tempo da animacao de morte
	STA cvb_DED
	; 	FOR c = 0 TO 4
	STA cvb_C
cv17:
	; 		bty(c) = 0
	LDA #array_BTY
	CLC
	ADC cvb_C
	TAX
	LDA #array_BTY>>8
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	LDA #0
	TAY
	STA (temp),Y
	; 	NEXT c
	INC cvb_C
	LDA cvb_C
	CMP #5
	BCC.L cv17
	; 	FOR c = 0 TO 5
	TYA
	STA cvb_C
cv18:
	; 		sma(c) = 0
	LDA #array_SMA
	CLC
	ADC cvb_C
	TAX
	LDA #array_SMA>>8
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	LDA #0
	TAY
	STA (temp),Y
	; 	NEXT c
	INC cvb_C
	LDA cvb_C
	CMP #6
	BCC.L cv18
	; 	FOR c = 0 TO 3
	TYA
	STA cvb_C
cv19:
	; 		sha(c) = 0
	LDA #array_SHA
	CLC
	ADC cvb_C
	TAX
	LDA #array_SHA>>8
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	LDA #0
	TAY
	STA (temp),Y
	; 	NEXT c
	INC cvb_C
	LDA cvb_C
	CMP #4
	BCC.L cv19
	; 	mba = 0			' miniboss: inativo (v0.11)
	TYA
	STA cvb_MBA
	; 	mbw = 0			' onda atual NAO e a do miniboss
	STA cvb_MBW
	; 	mbt = 0			' cooldown do anel do miniboss
	STA cvb_MBT
	; 	nsm = 0			' tiros de small na tela (cota de 3 - v0.12)
	STA cvb_NSM
	; 	mlr = 0			' laser do miniboss desligado
	STA cvb_MLR
	; 	bsa = 0			' boss inativo
	STA cvb_BSA
	; 	bsw = 0			' onda atual NAO e a do boss
	STA cvb_BSW
	; 	bol = 0			' laser do boss desligado
	STA cvb_BOL
	; 	boff = 0		' balanco lateral do boss (signed em byte)
	STA cvb_BOFF
	; 	bdir = 0
	STA cvb_BDIR
	; 	bpf = 0
	STA cvb_BPF
	; 	bsc = 0			' v0.19.2: zera cerimonia (troca de fase via SELECT)
	STA cvb_BSC
	; 	nsma = 0		' ondas de cada tipo (p/ chamar o boss: 4 de cada)
	STA cvb_NSMA
	; 	nsha = 0
	STA cvb_NSHA
	; 	ne4 = 0
	STA cvb_NE4
	; 	FOR c = 0 TO 7
	STA cvb_C
cv20:
	; 		e4a(c) = 0
	LDA #array_E4A
	CLC
	ADC cvb_C
	TAX
	LDA #array_E4A>>8
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	LDA #0
	TAY
	STA (temp),Y
	; 		eba(c) = 0
	LDA #array_EBA
	CLC
	ADC cvb_C
	TAX
	LDA #array_EBA>>8
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	LDA #0
	TAY
	STA (temp),Y
	; 		ebt(c) = 0
	LDA #array_EBT
	CLC
	ADC cvb_C
	TAX
	LDA #array_EBT>>8
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	LDA #0
	TAY
	STA (temp),Y
	; 	NEXT c
	INC cvb_C
	LDA cvb_C
	CMP #8
	BCC.L cv20
	; 	mbxo = 112		' mbx do frame anterior (deteccao do cruzamento)
	LDA #112
	STA cvb_MBXO
	; 	FOR c = 0 TO 63		' esconde todos os sprites
	TYA
	STA cvb_C
cv21:
	; 		SPRITE c,$f0,0,0,0
	LDA cvb_C
	PHA
	LDA #240
	STA sprite_data
	LDA #0
	STA sprite_data+3
	STA sprite_data+1
	STA sprite_data+2
	PLA
	JSR update_sprite
	; 	NEXT c
	INC cvb_C
	LDA cvb_C
	CMP #64
	BCC.L cv21
	; 	GOSUB update_score
	JSR cvb_UPDATE_SCORE
	; 	GOSUB update_lives
	JSR cvb_UPDATE_LIVES
	; 	bn = 0			' rajada atual (tiro vermelho nv1)
	LDA #0
	STA cvb_BN
	; 	cad = 0			' cadencia dentro da rajada
	STA cvb_CAD
	; 	cool = 0		' descanso entre rajadas
	STA cvb_COOL
	; 	mpt = 0			' timer da mini-explosao
	STA cvb_MPT
	; 	#pew = 0
	TAY
	STA cvb_#PEW
	STY cvb_#PEW+1
	; 	#pop = 0
	STA cvb_#POP
	STY cvb_#POP+1
	; 
	; 	' Gerenciador de ondas
	; 	wnum = 0		' ondas completadas
	STA cvb_WNUM
	; 	wtipo = 0		' 0 = small, 1 = shard, 2 = enemy4
	STA cvb_WTIPO
	; 	wact = 0		' 1 = onda em andamento
	STA cvb_WACT
	; 	wpausa = 30		' pausa antes da proxima onda (v0.9: era 40)
	LDA #30
	STA cvb_WPAUSA
	; 	wdif = 0		' dificuldade (0-3)
	TYA
	STA cvb_WDIF
	; 	qn = 0			' inimigos restantes p/ nascer na onda
	STA cvb_QN
	; 	wflip = 0		' lado da formacao shard
	STA cvb_WFLIP
	; 
	; 	scroll_y = 0
	STA cvb_SCROLL_Y
	; 	SCROLL 0, 0
	STA scroll_x
	STY scroll_x+1
	STA scroll_y
	STY scroll_y+1
	; 
	; 	'
	; 	' LOOP PRINCIPAL
	; 	'
	; game_loop:
cvb_GAME_LOOP:
	; 	WAIT
	JSR wait
	; 
	; 	' v0.19.2: SELECT = troca de fase p/ testes (debug do Saulo)
	; 	' v0.28: cicla 1>2>3>4>5>1
	; 	IF CONT1.KEY = 10 THEN
	LDA key1_data
	CMP #10
	BNE.L cv22
	; 		fase = fase + 1
	INC cvb_FASE
	; 		IF fase > 5 THEN fase = 1
	LDA cvb_FASE
	CMP #6
	BCC.L cv23
	LDA #1
	STA cvb_FASE
cv23:
	; 		PLAY OFF
	LDA #music_silence
	LDY #music_silence>>8
	JSR music_play
	; 		GOTO begin_stage
	JMP cvb_BEGIN_STAGE
	; 	END IF
cv22:
	; 
	; 	' v0.19: cerimonia pos-boss (estrobo + explosoes repetidas no lugar
	; 	' dele); ao fim, sai do loop p/ a sequencia de transicao de fase
	; 	IF bsc > 0 THEN
	LDA cvb_BSC
	CMP #1
	BCC.L cv24
	; 		bsc = bsc - 1
	DEC cvb_BSC
	; 		IF (FRAME AND 4) = 0 THEN VPOKE $3F00,$30 ELSE VPOKE $3F00,$0F
	LDA frame
	LDY frame+1
	AND #4
	LDY #0
	STY temp
	ORA temp
	BNE.L cv25
	LDA #48
	PHA
	TYA
	LDY #63
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	JMP cv26
cv25:
	LDA #15
	PHA
	LDA #0
	LDY #63
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
cv26:
	; 		IF (bsc AND 15) = 0 THEN
	LDA cvb_BSC
	AND #15
	BNE.L cv27
	; 			mpt = 12
	LDA #12
	STA cvb_MPT
	; 			mpx = 96 + RANDOM(48)
	JSR random
	LDX #48
	STX temp
	LDX #0
	STX temp+1
	JSR _mod16
	CLC
	ADC #96
	STA cvb_MPX
	; 			mpy = 40 + RANDOM(40)
	JSR random
	LDX #40
	STX temp
	LDX #0
	STX temp+1
	JSR _mod16
	CLC
	ADC #40
	STA cvb_MPY
	; 			#pop = 12
	LDA #12
	LDY #0
	STA cvb_#POP
	STY cvb_#POP+1
	; 		END IF
cv27:
	; 		IF bsc = 0 THEN GOTO fase1_clear
	LDA cvb_BSC
	BNE.L cv28
	JMP cvb_FASE1_CLEAR
cv28:
	; 	END IF
cv24:
	; 
	; 	' v0.14: gira o rodizio OAM (flicker rotativo no lugar de
	; 	' sprites sumindo DEFINITIVO quando >8 por scanline)
	; 	rr = rr + 1
	INC cvb_RR
	; 	IF rr >= 16 THEN rr = 0
	LDA cvb_RR
	CMP #16
	BCC.L cv29
	LDA #0
	STA cvb_RR
cv29:
	; 
	; 	' Fundo rolando p/ baixo (congela durante o BOSS: ele e desenhado
	; 	' como Background eletrostatico - v0.12)
	; 	IF bsa = 0 THEN
	LDA cvb_BSA
	BNE.L cv30
	; 		scroll_y = scroll_y - 1
	DEC cvb_SCROLL_Y
	; 		IF scroll_y = $ff THEN scroll_y = $ef
	LDA cvb_SCROLL_Y
	CMP #255
	BNE.L cv31
	LDA #239
	STA cvb_SCROLL_Y
cv31:
	; 		SCROLL 0, scroll_y
	LDA #0
	TAY
	STA scroll_x
	STY scroll_x+1
	LDA cvb_SCROLL_Y
	STA scroll_y
	STY scroll_y+1
	; 		IF fase = 2 THEN	' v0.19.1: todo o ciclo da lava mora no banco 3
	LDA cvb_FASE
	CMP #2
	BNE.L cv32
	; 			BANK SELECT 3
	LDA #2
	ORA CHRRAM_BANK
	STA BANKSEL
	; 			' GOSUB lava_tick	' v0.26: motor de anel aposentado (scroll = fase 1)
	; 			BANK SELECT 0
	LDA #31
	ORA CHRRAM_BANK
	STA BANKSEL
	; 		END IF
cv32:
	; 	ELSE
	JMP cv33
cv30:
	; 		' v0.13: boss BALANCA p/ os lados (classico chefe-de-BG do NES;
	; 		' ceu todo preto = o wrap horizontal nunca aparece)
	; 		IF (FRAME AND 1) = 0 THEN
	LDA frame
	LDY frame+1
	AND #1
	LDY #0
	STY temp
	ORA temp
	BNE.L cv34
	; 			IF bdir = 0 THEN
	LDA cvb_BDIR
	BNE.L cv35
	; 				boff = boff + 1
	INC cvb_BOFF
	; 				IF boff = 16 THEN bdir = 1
	LDA cvb_BOFF
	CMP #16
	BNE.L cv36
	LDA #1
	STA cvb_BDIR
cv36:
	; 			ELSE
	JMP cv37
cv35:
	; 				boff = boff - 1
	DEC cvb_BOFF
	; 				IF boff = 240 THEN bdir = 0	' -16 em byte
	LDA cvb_BOFF
	CMP #240
	BNE.L cv38
	LDA #0
	STA cvb_BDIR
cv38:
	; 			END IF
cv37:
	; 		END IF
cv34:
	; 		' boff com sinal em 16 bits p/ os calculos de #tbx
	; 		IF boff >= 128 THEN
	LDA cvb_BOFF
	CMP #128
	BCC.L cv39
	; 			#bo = boff - 256
	LDY #0
	DEY
	STA cvb_#BO
	STY cvb_#BO+1
	; 		ELSE
	JMP cv40
cv39:
	; 			#bo = boff
	LDA cvb_BOFF
	LDY #0
	STA cvb_#BO
	STY cvb_#BO+1
	; 		END IF
cv40:
	; 		SCROLL boff,0
	LDA cvb_BOFF
	LDY #0
	STA scroll_x
	STY scroll_x+1
	TYA
	STA scroll_y
	STY scroll_y+1
	; 		' "animacao" do spritesheet por PULSO DE PALETA (ideia do Saulo):
	; 		' a cor clara $38 acende/apaga (38/28/18/28, ciclo de ~1s)
	; 		bpf = bpf + 1
	INC cvb_BPF
	; 		IF bpf = 14 THEN VPOKE $3F07,$28
	LDA cvb_BPF
	CMP #14
	BNE.L cv41
	LDA #40
	PHA
	LDA #7
	LDY #63
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
cv41:
	; 		IF bpf = 28 THEN VPOKE $3F07,$18
	LDA cvb_BPF
	CMP #28
	BNE.L cv42
	LDA #24
	PHA
	LDA #7
	LDY #63
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
cv42:
	; 		IF bpf = 42 THEN VPOKE $3F07,$38
	LDA cvb_BPF
	CMP #42
	BNE.L cv43
	LDA #56
	PHA
	LDA #7
	LDY #63
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
cv43:
	; 		IF bpf = 56 THEN VPOKE $3F07,$28
	LDA cvb_BPF
	CMP #56
	BNE.L cv44
	LDA #40
	PHA
	LDA #7
	LDY #63
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
cv44:
	; 		IF bpf >= 56 THEN bpf = 0
	LDA cvb_BPF
	CMP #56
	BCC.L cv45
	LDA #0
	STA cvb_BPF
cv45:
	; 	END IF
cv33:
	; 
	; 	' (sem animacao no fundo: so o SCROLL acima rola as estrelas)
	; 
	; 	' --- Movimento + animacao da nave (PANIM fiel ao original) ---
	; 	IF ded = 0 THEN
	LDA cvb_DED
	BNE.L cv46
	; 		IF CONT1.LEFT THEN IF px > 8 THEN px = px - 2
	LDA joy1_data
	AND #8
	BEQ.L cv47
	LDA cvb_PX
	CMP #9
	BCC.L cv48
	DEC cvb_PX
	DEC cvb_PX
cv48:
cv47:
	; 		IF CONT1.RIGHT THEN IF px < 232 THEN px = px + 2
	LDA joy1_data
	AND #2
	BEQ.L cv49
	LDA cvb_PX
	CMP #232
	BCS.L cv50
	INC cvb_PX
	INC cvb_PX
cv50:
cv49:
	; 		IF CONT1.UP THEN IF py > 24 THEN py = py - 2
	LDA joy1_data
	AND #1
	BEQ.L cv51
	LDA cvb_PY
	CMP #25
	BCC.L cv52
	DEC cvb_PY
	DEC cvb_PY
cv52:
cv51:
	; 		IF CONT1.DOWN THEN IF py < 208 THEN py = py + 2
	LDA joy1_data
	AND #4
	BEQ.L cv53
	LDA cvb_PY
	CMP #208
	BCS.L cv54
	INC cvb_PY
	INC cvb_PY
cv54:
cv53:
	; 
	; 		IF CONT1.LEFT THEN
	LDA joy1_data
	AND #8
	BEQ.L cv55
	; 			IF CONT1.RIGHT THEN
	LDA joy1_data
	AND #2
	BEQ.L cv56
	; 				BANK SELECT 1	' v0.28: anim_idle mora no banco 1
	LDA #0
	ORA CHRRAM_BANK
	STA BANKSEL
	; 				GOSUB anim_idle
	JSR cvb_ANIM_IDLE
	; 				BANK SELECT 0
	LDA #31
	ORA CHRRAM_BANK
	STA BANKSEL
	; 			ELSE
	JMP cv57
cv56:
	; 				IF dir <> 1 THEN
	LDA cvb_DIR
	CMP #1
	BEQ.L cv58
	; 					dir = 1
	LDA #1
	STA cvb_DIR
	; 					ret = 0
	LDA #0
	STA cvb_RET
	; 					an = 0
	STA cvb_AN
	; 				END IF
cv58:
	; 				IF an < 26 THEN an = an + 1
	LDA cvb_AN
	CMP #26
	BCS.L cv59
	INC cvb_AN
cv59:
	; 				IF an < 4 THEN
	LDA cvb_AN
	CMP #4
	BCS.L cv60
	; 					slot = 4
	LDA #4
	STA cvb_SLOT
	; 				ELSEIF an < 8 THEN
	JMP cv61
cv60:
	LDA cvb_AN
	CMP #8
	BCS.L cv62
	; 					slot = 5
	LDA #5
	STA cvb_SLOT
	; 				ELSEIF an < 12 THEN
	JMP cv61
cv62:
	LDA cvb_AN
	CMP #12
	BCS.L cv63
	; 					slot = 6
	LDA #6
	STA cvb_SLOT
	; 				ELSE
	JMP cv61
cv63:
	; 					slot = 7 + ((an - 12) / 5) % 4
	LDA cvb_AN
	LDY #0
	SEC
	SBC #12
	TAX
	TYA
	SBC #0
	TAY
	TXA
	LDX #5
	STX temp
	LDX #0
	STX temp+1
	JSR _div16
	AND #3
	CLC
	ADC #7
	STA cvb_SLOT
	; 				END IF
cv61:
	; 			END IF
cv57:
	; 		ELSEIF CONT1.RIGHT THEN
	JMP cv64
cv55:
	LDA joy1_data
	AND #2
	BEQ.L cv65
	; 			IF dir <> 2 THEN
	LDA cvb_DIR
	CMP #2
	BEQ.L cv66
	; 				dir = 2
	LDA #2
	STA cvb_DIR
	; 				ret = 0
	LDA #0
	STA cvb_RET
	; 				an = 0
	STA cvb_AN
	; 			END IF
cv66:
	; 			IF an < 26 THEN an = an + 1
	LDA cvb_AN
	CMP #26
	BCS.L cv67
	INC cvb_AN
cv67:
	; 			IF an < 4 THEN
	LDA cvb_AN
	CMP #4
	BCS.L cv68
	; 				slot = 4
	LDA #4
	STA cvb_SLOT
	; 			ELSEIF an < 8 THEN
	JMP cv69
cv68:
	LDA cvb_AN
	CMP #8
	BCS.L cv70
	; 				slot = 5
	LDA #5
	STA cvb_SLOT
	; 			ELSEIF an < 12 THEN
	JMP cv69
cv70:
	LDA cvb_AN
	CMP #12
	BCS.L cv71
	; 				slot = 6
	LDA #6
	STA cvb_SLOT
	; 			ELSE
	JMP cv69
cv71:
	; 				slot = 7 + ((an - 12) / 5) % 4
	LDA cvb_AN
	LDY #0
	SEC
	SBC #12
	TAX
	TYA
	SBC #0
	TAY
	TXA
	LDX #5
	STX temp
	LDX #0
	STX temp+1
	JSR _div16
	AND #3
	CLC
	ADC #7
	STA cvb_SLOT
	; 			END IF
cv69:
	; 		ELSE
	JMP cv64
cv65:
	; 			BANK SELECT 1	' v0.28: anim_idle mora no banco 1
	LDA #0
	ORA CHRRAM_BANK
	STA BANKSEL
	; 			GOSUB anim_idle
	JSR cvb_ANIM_IDLE
	; 			BANK SELECT 0
	LDA #31
	ORA CHRRAM_BANK
	STA BANKSEL
	; 		END IF
cv64:
	; 
	; 		' Desenha a nave (esquerda = H-FLIP da direita, como no original)
	; 		IF inv > 0 THEN inv = inv - 1
	LDA cvb_INV
	CMP #1
	BCC.L cv72
	DEC cvb_INV
cv72:
	; 		fb = 21 + slot * 8
	LDA cvb_SLOT
	ASL A
	ASL A
	ASL A
	CLC
	ADC #21
	STA cvb_FB
	; 		IF (inv AND 4) <> 0 THEN
	LDA cvb_INV
	AND #4
	BEQ.L cv73
	; 			SPRITE 0,$f0,0,0,0
	LDA #0
	PHA
	LDA #240
	STA sprite_data
	LDA #0
	STA sprite_data+3
	STA sprite_data+1
	STA sprite_data+2
	PLA
	JSR update_sprite
	; 			SPRITE 1,$f0,0,0,0
	LDA #1
	PHA
	LDA #240
	STA sprite_data
	LDA #0
	STA sprite_data+3
	STA sprite_data+1
	STA sprite_data+2
	PLA
	JSR update_sprite
	; 			SPRITE 2,$f0,0,0,0
	LDA #2
	PHA
	LDA #240
	STA sprite_data
	LDA #0
	STA sprite_data+3
	STA sprite_data+1
	STA sprite_data+2
	PLA
	JSR update_sprite
	; 			SPRITE 3,$f0,0,0,0
	LDA #3
	PHA
	LDA #240
	STA sprite_data
	LDA #0
	STA sprite_data+3
	STA sprite_data+1
	STA sprite_data+2
	PLA
	JSR update_sprite
	; 		ELSEIF dir = 1 THEN
	JMP cv74
cv73:
	LDA cvb_DIR
	CMP #1
	BNE.L cv75
	; 			SPRITE 0,py - 1,px + 4,fb + 4,$41
	LDA #0
	PHA
	LDA cvb_PY
	SEC
	SBC #1
	STA sprite_data
	LDA cvb_PX
	CLC
	ADC #4
	STA sprite_data+3
	LDA cvb_FB
	CLC
	ADC #4
	STA sprite_data+1
	LDA #65
	STA sprite_data+2
	PLA
	JSR update_sprite
	; 			SPRITE 1,py - 1,px + 4,fb + 6,$42
	LDA #1
	PHA
	LDA cvb_PY
	SEC
	SBC #1
	STA sprite_data
	LDA cvb_PX
	CLC
	ADC #4
	STA sprite_data+3
	LDA cvb_FB
	CLC
	ADC #6
	STA sprite_data+1
	LDA #66
	STA sprite_data+2
	PLA
	JSR update_sprite
	; 			SPRITE 2,py - 1,px,fb + 2,$40
	LDA #2
	PHA
	LDA cvb_PY
	SEC
	SBC #1
	STA sprite_data
	LDA cvb_PX
	STA sprite_data+3
	LDA cvb_FB
	CLC
	ADC #2
	STA sprite_data+1
	LDA #64
	STA sprite_data+2
	PLA
	JSR update_sprite
	; 			SPRITE 3,py - 1,px + 8,fb,$40
	LDA #3
	PHA
	LDA cvb_PY
	SEC
	SBC #1
	STA sprite_data
	LDA cvb_PX
	CLC
	ADC #8
	STA sprite_data+3
	LDA cvb_FB
	STA sprite_data+1
	LDA #64
	STA sprite_data+2
	PLA
	JSR update_sprite
	; 		ELSE
	JMP cv74
cv75:
	; 			SPRITE 0,py - 1,px + 4,fb + 4,1
	LDA #0
	PHA
	LDA cvb_PY
	SEC
	SBC #1
	STA sprite_data
	LDA cvb_PX
	CLC
	ADC #4
	STA sprite_data+3
	LDA cvb_FB
	CLC
	ADC #4
	STA sprite_data+1
	LDA #1
	STA sprite_data+2
	PLA
	JSR update_sprite
	; 			SPRITE 1,py - 1,px + 4,fb + 6,2
	LDA #1
	PHA
	LDA cvb_PY
	SEC
	SBC #1
	STA sprite_data
	LDA cvb_PX
	CLC
	ADC #4
	STA sprite_data+3
	LDA cvb_FB
	CLC
	ADC #6
	STA sprite_data+1
	LDA #2
	STA sprite_data+2
	PLA
	JSR update_sprite
	; 			SPRITE 2,py - 1,px,fb,0
	LDA #2
	PHA
	LDA cvb_PY
	SEC
	SBC #1
	STA sprite_data
	LDA cvb_PX
	STA sprite_data+3
	LDA cvb_FB
	STA sprite_data+1
	LDA #0
	STA sprite_data+2
	PLA
	JSR update_sprite
	; 			SPRITE 3,py - 1,px + 8,fb + 2,0
	LDA #3
	PHA
	LDA cvb_PY
	SEC
	SBC #1
	STA sprite_data
	LDA cvb_PX
	CLC
	ADC #8
	STA sprite_data+3
	LDA cvb_FB
	CLC
	ADC #2
	STA sprite_data+1
	LDA #0
	STA sprite_data+2
	PLA
	JSR update_sprite
	; 		END IF
cv74:
	; 
	; 		' --- Tiro vermelho nv1: rajada de 5 (3f entre tiros, 16f de gap) ---
	; 		IF CONT1.BUTTON THEN
	LDA joy1_data
	AND #64
	BEQ.L cv76
	; 			IF bn = 0 AND cool = 0 THEN bn = 5
	LDA cvb_COOL
	BEQ cv78
	LDA #0
	DB $2c
cv78:
	LDA #255
	STA temp
	LDA cvb_BN
	BEQ cv79
	LDA #0
	DB $2c
cv79:
	LDA #255
	AND temp
	BEQ.L cv77
	LDA #5
	STA cvb_BN
cv77:
	; 			IF bn > 0 AND cad = 0 THEN
	LDA cvb_CAD
	BEQ cv81
	LDA #0
	DB $2c
cv81:
	LDA #255
	STA temp
	LDA cvb_BN
	CMP #1
	LDA #255
	ADC #0
	EOR #255
	AND temp
	BEQ.L cv80
	; 				d = 0
	LDA #0
	STA cvb_D
	; 				WHILE d < 5
cv82:
	LDA cvb_D
	CMP #5
	BCS.L cv83
	; 					IF bty(d) = 0 THEN
	LDA #array_BTY
	CLC
	ADC cvb_D
	TAX
	LDA #array_BTY>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	CMP #0
	BNE.L cv84
	; 						btx(d) = px + 4
	LDA #array_BTX
	CLC
	ADC cvb_D
	TAX
	LDA #array_BTX>>8
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	LDA cvb_PX
	CLC
	ADC #4
	LDY #0
	STA (temp),Y
	; 						bty(d) = py - 6
	LDA #array_BTY
	CLC
	ADC cvb_D
	TAX
	LDA #array_BTY>>8
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	LDA cvb_PY
	SEC
	SBC #6
	LDY #0
	STA (temp),Y
	; 						#pew = 5
	LDA #5
	STA cvb_#PEW
	STY cvb_#PEW+1
	; 						bn = bn - 1
	DEC cvb_BN
	; 						cad = 3
	LDA #3
	STA cvb_CAD
	; 						IF bn = 0 THEN cool = 16
	LDA cvb_BN
	BNE.L cv85
	LDA #16
	STA cvb_COOL
cv85:
	; 						d = 5
	LDA #5
	STA cvb_D
	; 					ELSE
	JMP cv86
cv84:
	; 						d = d + 1
	INC cvb_D
	; 					END IF
cv86:
	; 				WEND
	JMP cv82
cv83:
	; 			END IF
cv80:
	; 		ELSE
	JMP cv87
cv76:
	; 			bn = 0
	LDA #0
	STA cvb_BN
	; 		END IF
cv87:
	; 	END IF
cv46:
	; 	IF cad > 0 THEN cad = cad - 1
	LDA cvb_CAD
	CMP #1
	BCC.L cv88
	DEC cvb_CAD
cv88:
	; 	IF cool > 0 THEN cool = cool - 1
	LDA cvb_COOL
	CMP #1
	BCC.L cv89
	DEC cvb_COOL
cv89:
	; 
	; 	' --- Tiros do player subindo ---
	; 	FOR c = 0 TO 4
	LDA #0
	STA cvb_C
cv90:
	; 		IF bty(c) <> 0 THEN
	LDA #array_BTY
	CLC
	ADC cvb_C
	TAX
	LDA #array_BTY>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	CMP #0
	BEQ.L cv91
	; 			bty(c) = bty(c) - 4
	LDA #array_BTY
	CLC
	ADC cvb_C
	STA temp
	LDA #array_BTY>>8
	ADC #0
	STA temp+1
	LDY #0
	LDA (temp),Y
	SEC
	SBC #4
	STA (temp),Y
	; 			IF bty(c) < 8 THEN
	LDA pointer
	LDY pointer+1
	JSR _peek8
	CMP #8
	BCS.L cv92
	; 				bty(c) = 0
	LDA pointer
	LDY pointer+1
	STA temp
	STY temp+1
	LDA #0
	TAY
	STA (temp),Y
	; 				SPRITE 16 + c,$f0,0,0,0
	LDA cvb_C
	CLC
	ADC #16
	PHA
	LDA #240
	STA sprite_data
	TYA
	STA sprite_data+3
	STA sprite_data+1
	STA sprite_data+2
	PLA
	JSR update_sprite
	; 			ELSE
	JMP cv93
cv92:
	; 				SPRITE 16 + c,bty(c) - 1,btx(c),217 + ((FRAME / 4) AND 1) * 2,3
	LDA cvb_C
	CLC
	ADC #16
	PHA
	LDA #array_BTY
	CLC
	ADC cvb_C
	TAX
	LDA #array_BTY>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	SEC
	SBC #1
	STA sprite_data
	LDA #array_BTX
	CLC
	ADC cvb_C
	TAX
	LDA #array_BTX>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	STA sprite_data+3
	LDA frame
	LDY frame+1
	STY temp
	LSR temp
	ROR A
	LSR temp
	ROR A
	LDY temp
	AND #1
	ASL A
	CLC
	ADC #217
	STA sprite_data+1
	LDA #3
	STA sprite_data+2
	PLA
	JSR update_sprite
	; 			END IF
cv93:
	; 		END IF
cv91:
	; 	NEXT c
	INC cvb_C
	LDA cvb_C
	CMP #5
	BCC.L cv90
	; 
	; 	' --- Gerenciador de ondas ---
	; 	IF wact = 0 THEN
	LDA cvb_WACT
	BNE.L cv94
	; 		IF wpausa > 0 THEN wpausa = wpausa - 1
	LDA cvb_WPAUSA
	CMP #1
	BCC.L cv95
	DEC cvb_WPAUSA
cv95:
	; 		IF wpausa = 0 THEN
	LDA cvb_WPAUSA
	BNE.L cv96
	; 			' BOSS: chamado quando TODAS as ondas ja passaram >= 4 vezes
	; 			btry = 0
	LDA #0
	STA cvb_BTRY
	; 			IF nsma >= 4 THEN	' v0.28: MESMO boss em TODAS as fases
	LDA cvb_NSMA
	CMP #4
	BCC.L cv97
	; 				IF nsha >= 4 THEN
	LDA cvb_NSHA
	CMP #4
	BCC.L cv98
	; 					IF ne4 >= 4 THEN btry = 1
	LDA cvb_NE4
	CMP #4
	BCC.L cv99
	LDA #1
	STA cvb_BTRY
cv99:
	; 				END IF
cv98:
	; 			END IF
cv97:
	; 			IF btry THEN
	LDA cvb_BTRY
	CMP #0
	BEQ.L cv100
	; 				' --- Onda do BOSS (v0.12) ---
	; 				BANK SELECT 1			' v0.15: boss_start mora no banco 1
	LDA #0
	ORA CHRRAM_BANK
	STA BANKSEL
	; 				GOSUB boss_start
	JSR cvb_BOSS_START
	; 				wact = 1
	LDA #1
	STA cvb_WACT
	; 			ELSE
	JMP cv101
cv100:
	; 			IF (wnum AND 3) = 3 THEN
	LDA cvb_WNUM
	AND #3
	CMP #3
	BNE.L cv102
	; 				' --- Onda do MINIBOSS: 1 a cada 4 ondas (interludio) ---
	; 				' (v0.11) entra pelo topo, desce ate o meio, patrulha
	; 				' esq/dir lancando aneis de 8 tiros; morre com 48 tiros
	; 				mbw = 1
	LDA #1
	STA cvb_MBW
	; 				mba = 1
	STA cvb_MBA
	; 				mbs = 1			' estado: descendo
	STA cvb_MBS
	; 				mbhp = 48		' HP (constante p/ ajuste fino)
	LDA #48
	STA cvb_MBHP
	; 				mbx = 112
	LDA #112
	STA cvb_MBX
	; 				#mby = 3584		' (-32 + 256) * 16
	LDA #0
	LDY #14
	STA cvb_#MBY
	STY cvb_#MBY+1
	; 				mbdir = RANDOM(2)
	JSR random
	AND #1
	STA cvb_MBDIR
	; 				mbt = 90		' 1.5s de graca antes do 1o anel
	LDA #90
	STA cvb_MBT
	; 				' pal2 vira a paleta da arte do miniboss (roxo/lilas/
	; 				' dourado = $03/$23/$38, cores exatas do PNG do Saulo;
	; 				' efeito colateral temporario: a chama da nave fica
	; 				' roxa durante a luta; restaurada no mb_kill)
	; 				VPOKE $3F19,$03
	LDA #3
	PHA
	LDA #25
	LDY #63
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 				VPOKE $3F1A,$23
	LDA #35
	PHA
	LDA #26
	LDY #63
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 				VPOKE $3F1B,$38
	LDA #56
	PHA
	LDA #27
	LDY #63
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 				wact = 1
	LDA #1
	STA cvb_WACT
	; 			ELSE
	JMP cv103
cv102:
	; 			mbw = 0
	LDA #0
	STA cvb_MBW
	; 			IF wtipo = 0 THEN
	LDA cvb_WTIPO
	BNE.L cv104
	; 				qn = 6
	LDA #6
	STA cvb_QN
	; 				qdel = 20	' onda small (v0.11): 6 naves em 2 grupos
	LDA #20
	STA cvb_QDEL
	; 				' de 3 (0.45s entre elas); o 2o grupo entra SEGUIDO
	; 				' do 1o, no lado OPOSTO da tela = tela mais cheia
	; 				c = RANDOM(2)
	JSR random
	AND #1
	STA cvb_C
	; 				colx = c * 170 + 43	' lado A: 43 (esq) ou 213 (dir)
	LDY #0
	LDX #170
	STX temp
	LDX #0
	STX temp+1
	JSR _mul16
	CLC
	ADC #43
	STA cvb_COLX
	; 				colb = 256 - colx	' lado B: o oposto
	LDA #0
	LDY #1
	SEC
	SBC cvb_COLX
	TAX
	TYA
	SBC #0
	TAY
	TXA
	STA cvb_COLB
	; 				nsma = nsma + 1	' conta p/ o gatilho do boss (v0.12)
	INC cvb_NSMA
	; 				wact = 1
	LDA #1
	STA cvb_WACT
	; 			ELSE
	JMP cv105
cv104:
	; 				IF wtipo = 1 THEN
	LDA cvb_WTIPO
	CMP #1
	BNE.L cv106
	; 				' formacao shard: 4 em coluna, lado alternado
	; 				FOR c = 0 TO 3
	LDA #0
	STA cvb_C
cv107:
	; 					sha(c) = 1
	LDA #array_SHA
	CLC
	ADC cvb_C
	TAX
	LDA #array_SHA>>8
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	LDA #1
	LDY #0
	STA (temp),Y
	; 					shf(c) = 0
	LDA #array_SHF
	CLC
	ADC cvb_C
	TAX
	LDA #array_SHF>>8
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	LDA #0
	TAY
	STA (temp),Y
	; 					#shy(c) = 3840 - c * 256	' (-16 + 256)*16, degraus de 16px
	LDY #15
	PHA
	TYA
	PHA
	LDA cvb_C
	TAY
	LDA #0
	STY temp
	STA temp
	STY temp+1
	PLA
	TAY
	PLA
	SEC
	SBC temp
	TAX
	TYA
	SBC temp+1
	TAY
	TXA
	PHA
	TYA
	PHA
	LDA cvb_C
	ASL A
	LDY #0
	BCC $+3
	INY
	CLC
	ADC #array_#SHY
	TAX
	TYA
	ADC #array_#SHY>>8
	TAY
	TXA
	STA temp
	STY temp+1
	PLA
	LDY #1
	STA (temp),Y
	PLA
	DEY
	STA (temp),Y
	; 					shyc(c) = 240		' v0.14: cache px (240+ = escondido na entrada)
	LDA #array_SHYC
	CLC
	ADC cvb_C
	TAX
	LDA #array_SHYC>>8
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	LDA #240
	LDY #0
	STA (temp),Y
	; 					IF wflip THEN
	LDA cvb_WFLIP
	CMP #0
	BEQ.L cv108
	; 						shx(c) = 205	' 0.8 * 256
	LDA #array_SHX
	CLC
	ADC cvb_C
	TAX
	LDA #array_SHX>>8
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	LDA #205
	LDY #0
	STA (temp),Y
	; 					ELSE
	JMP cv109
cv108:
	; 						shx(c) = 51	' 0.2 * 256
	LDA #array_SHX
	CLC
	ADC cvb_C
	TAX
	LDA #array_SHX>>8
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	LDA #51
	LDY #0
	STA (temp),Y
	; 					END IF
cv109:
	; 				NEXT c
	INC cvb_C
	LDA cvb_C
	CMP #4
	BCC.L cv107
	; 				wflip = 1 - wflip
	LDA #1
	LDY #0
	SEC
	SBC cvb_WFLIP
	TAX
	TYA
	SBC #0
	TAY
	TXA
	STA cvb_WFLIP
	; 				nsha = nsha + 1	' conta p/ o gatilho do boss (v0.12)
	INC cvb_NSHA
	; 				wact = 1
	LDA #1
	STA cvb_WACT
	; 				ELSE
	JMP cv110
cv106:
	; 				' formacao enemy4: 8 naves (0.5s entre elas), 4 colunas
	; 				' (32/88/144/200) em 2 permutacoes embaralhadas; coluna
	; 				' nunca repete em spawns seguidos = nunca coladas
	; 				qn = 8
	LDA #8
	STA cvb_QN
	; 				qdel = 30	' 1o enemy4 surge em 0.5s
	LDA #30
	STA cvb_QDEL
	; 				e4v = 14 + wdif	' descida (1/16 px/frame); v0.9: era 10
	LDA cvb_WDIF
	CLC
	ADC #14
	STA cvb_E4V
	; 				ne4 = ne4 + 1	' conta p/ o gatilho do boss (v0.12)
	INC cvb_NE4
	; 				FOR c = 0 TO 7
	LDA #0
	STA cvb_C
cv111:
	; 					e4p(c) = c AND 3
	LDA #array_E4P
	CLC
	ADC cvb_C
	TAX
	LDA #array_E4P>>8
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	LDA cvb_C
	AND #3
	LDY #0
	STA (temp),Y
	; 				NEXT c
	INC cvb_C
	LDA cvb_C
	CMP #8
	BCC.L cv111
	; 				FOR c = 0 TO 2
	TYA
	STA cvb_C
cv112:
	; 					d = c + RANDOM(4 - c)	' Fisher-Yates metade 1
	LDA cvb_C
	LDY #0
	PHA
	TYA
	PHA
	JSR random
	PHA
	TYA
	PHA
	LDA #4
	LDY #0
	SEC
	SBC cvb_C
	TAX
	TYA
	SBC #0
	TAY
	TXA
	STA temp
	STY temp+1
	PLA
	TAY
	PLA
	JSR _mod16
	STA temp
	STY temp+1
	PLA
	TAY
	PLA
	CLC
	ADC temp
	TAX
	TYA
	ADC temp+1
	TAY
	TXA
	STA cvb_D
	; 					e = e4p(c)
	LDA #array_E4P
	CLC
	ADC cvb_C
	TAX
	LDA #array_E4P>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	STA cvb_E
	; 					e4p(c) = e4p(d)
	LDA pointer
	LDY pointer+1
	STA temp
	STY temp+1
	LDA #array_E4P
	CLC
	ADC cvb_D
	TAX
	LDA #array_E4P>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	LDY #0
	STA (temp),Y
	; 					e4p(d) = e
	LDA pointer
	LDY pointer+1
	STA temp
	STY temp+1
	LDA cvb_E
	LDY #0
	STA (temp),Y
	; 				NEXT c
	INC cvb_C
	LDA cvb_C
	CMP #3
	BCC.L cv112
	; 				FOR c = 4 TO 6
	LDA #4
	STA cvb_C
cv113:
	; 					d = c + RANDOM(8 - c)	' Fisher-Yates metade 2
	LDA cvb_C
	LDY #0
	PHA
	TYA
	PHA
	JSR random
	PHA
	TYA
	PHA
	LDA #8
	LDY #0
	SEC
	SBC cvb_C
	TAX
	TYA
	SBC #0
	TAY
	TXA
	STA temp
	STY temp+1
	PLA
	TAY
	PLA
	JSR _mod16
	STA temp
	STY temp+1
	PLA
	TAY
	PLA
	CLC
	ADC temp
	TAX
	TYA
	ADC temp+1
	TAY
	TXA
	STA cvb_D
	; 					e = e4p(c)
	LDA #array_E4P
	CLC
	ADC cvb_C
	TAX
	LDA #array_E4P>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	STA cvb_E
	; 					e4p(c) = e4p(d)
	LDA pointer
	LDY pointer+1
	STA temp
	STY temp+1
	LDA #array_E4P
	CLC
	ADC cvb_D
	TAX
	LDA #array_E4P>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	LDY #0
	STA (temp),Y
	; 					e4p(d) = e
	LDA pointer
	LDY pointer+1
	STA temp
	STY temp+1
	LDA cvb_E
	LDY #0
	STA (temp),Y
	; 				NEXT c
	INC cvb_C
	LDA cvb_C
	CMP #7
	BCC.L cv113
	; 				IF e4p(4) = e4p(3) THEN	' fronteira nao repete coluna
	LDA array_E4P+3
	STA temp
	LDA array_E4P+4
	CMP temp
	BNE.L cv114
	; 					e = e4p(4)
	STA cvb_E
	; 					e4p(4) = e4p(5)
	LDA array_E4P+5
	STA array_E4P+4
	; 					e4p(5) = e
	LDA cvb_E
	STA array_E4P+5
	; 				END IF
cv114:
	; 				wact = 1
	LDA #1
	STA cvb_WACT
	; 				END IF
cv110:
	; 			END IF
cv105:
	; 			END IF
cv103:
	; 			END IF
cv101:
	; 		END IF
cv96:
	; 	ELSE
	JMP cv115
cv94:
	; 		IF qn > 0 THEN
	LDA cvb_QN
	CMP #1
	BCC.L cv116
	; 		IF mbw = 0 AND bsw = 0 THEN	' ondas de mini/boss nao spawnam
	LDA cvb_BSW
	BEQ cv118
	LDA #0
	DB $2c
cv118:
	LDA #255
	STA temp
	LDA cvb_MBW
	BEQ cv119
	LDA #0
	DB $2c
cv119:
	LDA #255
	AND temp
	BEQ.L cv117
	; 			qdel = qdel - 1
	DEC cvb_QDEL
	; 			IF qdel = 0 THEN
	LDA cvb_QDEL
	BNE.L cv120
	; 				IF wtipo = 2 THEN
	LDA cvb_WTIPO
	CMP #2
	BNE.L cv121
	; 					c = 8 - qn
	LDA #8
	LDY #0
	SEC
	SBC cvb_QN
	TAX
	TYA
	SBC #0
	TAY
	TXA
	STA cvb_C
	; 				ELSE
	JMP cv122
cv121:
	; 					c = 6 - qn
	LDA #6
	LDY #0
	SEC
	SBC cvb_QN
	TAX
	TYA
	SBC #0
	TAY
	TXA
	STA cvb_C
	; 				END IF
cv122:
	; 				IF wtipo = 2 THEN
	LDA cvb_WTIPO
	CMP #2
	BNE.L cv123
	; 					e4a(c) = 1
	LDA #array_E4A
	CLC
	ADC cvb_C
	TAX
	LDA #array_E4A>>8
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	LDA #1
	LDY #0
	STA (temp),Y
	; 					e = e4p(c) * 56		' colunas 32/88/144/200 (evita
	LDA #array_E4P
	CLC
	ADC cvb_C
	TAX
	LDA #array_E4P>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	LDY #0
	LDX #56
	STX temp
	LDX #0
	STX temp+1
	JSR _mul16
	STA cvb_E
	; 					e4x(c) = 32 + e		' mult. dentro do store do array)
	LDA #array_E4X
	CLC
	ADC cvb_C
	TAX
	LDA #array_E4X>>8
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	LDA cvb_E
	CLC
	ADC #32
	LDY #0
	STA (temp),Y
	; 					#e4y(c) = 3840		' (-16 + 256) * 16
	LDA cvb_C
	ASL A
	BCC $+3
	INY
	CLC
	ADC #array_#E4Y
	TAX
	TYA
	ADC #array_#E4Y>>8
	TAY
	TXA
	STA temp
	STY temp+1
	LDA #0
	LDY #15
	TAX
	TYA
	LDY #1
	STA (temp),Y
	TXA
	DEY
	STA (temp),Y
	; 					e4w(c) = e4v + RANDOM(5) - 2	' velocidade levemente variada
	LDA cvb_E4V
	LDY #0
	PHA
	TYA
	PHA
	JSR random
	LDX #5
	STX temp
	LDX #0
	STX temp+1
	JSR _mod16
	STA temp
	STY temp+1
	PLA
	TAY
	PLA
	CLC
	ADC temp
	TAX
	TYA
	ADC temp+1
	TAY
	TXA
	SEC
	SBC #2
	PHA
	LDA #array_E4W
	CLC
	ADC cvb_C
	TAX
	LDA #array_E4W>>8
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	PLA
	LDY #0
	STA (temp),Y
	; 					e4f(c) = 1		' ainda nao atirou (atira ao cruzar y=64)
	LDA #array_E4F
	CLC
	ADC cvb_C
	TAX
	LDA #array_E4F>>8
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	LDA #1
	LDY #0
	STA (temp),Y
	; 					qn = qn - 1
	DEC cvb_QN
	; 					IF qn > 0 THEN qdel = 30	' 0.5s entre enemy4
	LDA cvb_QN
	CMP #1
	BCC.L cv124
	LDA #30
	STA cvb_QDEL
cv124:
	; 				ELSE
	JMP cv125
cv123:
	; 					sma(c) = 1
	LDA #array_SMA
	CLC
	ADC cvb_C
	TAX
	LDA #array_SMA>>8
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	LDA #1
	LDY #0
	STA (temp),Y
	; 					IF c < 3 THEN		' grupo A (lado sorteado)
	LDA cvb_C
	CMP #3
	BCS.L cv126
	; 						d = colx
	LDA cvb_COLX
	STA cvb_D
	; 					ELSE				' grupo B (lado oposto)
	JMP cv127
cv126:
	; 						d = colb
	LDA cvb_COLB
	STA cvb_D
	; 					END IF
cv127:
	; 					smp(c) = d
	LDA #array_SMP
	CLC
	ADC cvb_C
	TAX
	LDA #array_SMP>>8
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	LDA cvb_D
	LDY #0
	STA (temp),Y
	; 					smc(c) = 16 + RANDOM(13)	' amplitude 16-28
	JSR random
	LDX #13
	STX temp
	LDX #0
	STX temp+1
	JSR _mod16
	CLC
	ADC #16
	PHA
	LDA #array_SMC
	CLC
	ADC cvb_C
	TAX
	LDA #array_SMC>>8
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	PLA
	LDY #0
	STA (temp),Y
	; 					smz(c) = 32			' comeca cruzando o centro
	LDA #array_SMZ
	CLC
	ADC cvb_C
	TAX
	LDA #array_SMZ>>8
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	LDA #32
	LDY #0
	STA (temp),Y
	; 					smx(c) = d
	LDA #array_SMX
	CLC
	ADC cvb_C
	TAX
	LDA #array_SMX>>8
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	LDA cvb_D
	LDY #0
	STA (temp),Y
	; 					#smy(c) = 3840		' (-16 + 256) * 16
	LDA cvb_C
	ASL A
	BCC $+3
	INY
	CLC
	ADC #array_#SMY
	TAX
	TYA
	ADC #array_#SMY>>8
	TAY
	TXA
	STA temp
	STY temp+1
	LDA #0
	LDY #15
	TAX
	TYA
	LDY #1
	STA (temp),Y
	TXA
	DEY
	STA (temp),Y
	; 					smyy(c) = 240		' v0.14: cache px (240+ = escondido na entrada)
	LDA #array_SMYY
	CLC
	ADC cvb_C
	TAX
	LDA #array_SMYY>>8
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	LDA #240
	LDY #0
	STA (temp),Y
	; 					smd(c) = 40 + RANDOM(26)
	JSR random
	LDX #26
	STX temp
	LDX #0
	STX temp+1
	JSR _mod16
	CLC
	ADC #40
	PHA
	LDA #array_SMD
	CLC
	ADC cvb_C
	TAX
	LDA #array_SMD>>8
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	PLA
	LDY #0
	STA (temp),Y
	; 					smf(c) = 0
	LDA #array_SMF
	CLC
	ADC cvb_C
	TAX
	LDA #array_SMF>>8
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	LDA #0
	TAY
	STA (temp),Y
	; 					snv(c) = 11 + wdif * 2
	LDA #array_SNV
	CLC
	ADC cvb_C
	TAX
	LDA #array_SNV>>8
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	LDA cvb_WDIF
	ASL A
	CLC
	ADC #11
	LDY #0
	STA (temp),Y
	; 					qn = qn - 1
	DEC cvb_QN
	; 					IF qn > 0 THEN qdel = 27
	LDA cvb_QN
	CMP #1
	BCC.L cv128
	LDA #27
	STA cvb_QDEL
cv128:
	; 				END IF
cv125:
	; 			END IF
cv120:
	; 		END IF
cv117:
	; 		END IF
cv116:
	; 	END IF
cv115:
	; 
	; 	' --- Smalls (zigzag descendente, frame estatico, atiram 2 mirados) ---
	; 	' --- Smalls (zigzag descendente, frame estatico, atiram 2 mirados) ---
	; 	' v0.14 (Saulo: slowdown nas ondas 3+3 = CPU, medido no emulador!):
	; 	' metade dos smalls ATUALIZA por frame (passo dobrado = mesma veloci-
	; 	' dade, mesma tecnica dos tiros inimigos) e a posicao de pixel fica em
	; 	' CACHE (smyy) p/ desenhar todo frame no slot do anel sem repetir a
	; 	' divisao /16. Timer do tiro anda TODO frame (mesmo ritmo do v0.13).
	; 	FOR c = 0 TO 5
	LDA #0
	STA cvb_C
cv129:
	; 		k = c + c + rr
	LDA cvb_C
	CLC
	ADC cvb_C
	CLC
	ADC cvb_RR
	STA cvb_K
	; 		IF k > 15 THEN k = k - 16
	CMP #16
	BCC.L cv130
	SEC
	SBC #16
	STA cvb_K
cv130:
	; 		q1 = r16(k)
	LDA #array_R16
	CLC
	ADC cvb_K
	TAX
	LDA #array_R16>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	STA cvb_Q1
	; 		k = k + 1
	INC cvb_K
	; 		IF k > 15 THEN k = 0
	LDA cvb_K
	CMP #16
	BCC.L cv131
	LDA #0
	STA cvb_K
cv131:
	; 		q2 = r16(k)
	LDA #array_R16
	CLC
	ADC cvb_K
	TAX
	LDA #array_R16>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	STA cvb_Q2
	; 		IF sma(c) <> 0 THEN
	LDA #array_SMA
	CLC
	ADC cvb_C
	TAX
	LDA #array_SMA>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	CMP #0
	BEQ.L cv132
	; 			' tique do timer do tiro: todo frame, na posicao cacheada
	; 			yb = smyy(c)
	LDA #array_SMYY
	CLC
	ADC cvb_C
	TAX
	LDA #array_SMYY>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	STA cvb_YB
	; 			IF smf(c) < 2 THEN
	LDA #array_SMF
	CLC
	ADC cvb_C
	TAX
	LDA #array_SMF>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	CMP #2
	BCS.L cv133
	; 				IF yb > 4 THEN
	LDA cvb_YB
	CMP #5
	BCC.L cv134
	; 					IF yb < 200 THEN
	CMP #200
	BCS.L cv135
	; 						smd(c) = smd(c) - 1
	LDA #array_SMD
	CLC
	ADC cvb_C
	STA temp
	LDA #array_SMD>>8
	ADC #0
	STA temp+1
	LDY #0
	LDA (temp),Y
	SEC
	SBC #1
	STA (temp),Y
	; 					END IF
cv135:
	; 				END IF
cv134:
	; 			END IF
cv133:
	; 			' atualizacao dividida: metade dos smalls por frame
	; 			IF (c AND 1) = (FRAME AND 1) THEN
	LDA cvb_C
	AND #1
	LDY #0
	PHA
	TYA
	PHA
	LDA frame
	LDY frame+1
	AND #1
	LDY #0
	STA temp
	STY temp+1
	PLA
	TAY
	PLA
	SEC
	SBC temp
	STA temp
	TYA
	SBC temp+1
	ORA temp
	BNE.L cv136
	; 				#smy(c) = #smy(c) + snv(c)
	LDA cvb_C
	ASL A
	LDY #0
	BCC $+3
	INY
	CLC
	ADC #array_#SMY
	TAX
	TYA
	ADC #array_#SMY>>8
	TAY
	TXA
	JSR _peek16
	PHA
	TYA
	PHA
	LDA #array_SNV
	CLC
	ADC cvb_C
	TAX
	LDA #array_SNV>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	LDY #0
	STA temp
	STY temp+1
	PLA
	TAY
	PLA
	CLC
	ADC temp
	TAX
	TYA
	ADC temp+1
	TAY
	TXA
	PHA
	TYA
	PHA
	LDA cvb_C
	ASL A
	LDY #0
	BCC $+3
	INY
	CLC
	ADC #array_#SMY
	TAX
	TYA
	ADC #array_#SMY>>8
	TAY
	TXA
	STA temp
	STY temp+1
	PLA
	LDY #1
	STA (temp),Y
	PLA
	DEY
	STA (temp),Y
	; 				#smy(c) = #smy(c) + snv(c)
	LDA cvb_C
	ASL A
	LDY #0
	BCC $+3
	INY
	CLC
	ADC #array_#SMY
	TAX
	TYA
	ADC #array_#SMY>>8
	TAY
	TXA
	JSR _peek16
	PHA
	TYA
	PHA
	LDA #array_SNV
	CLC
	ADC cvb_C
	TAX
	LDA #array_SNV>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	LDY #0
	STA temp
	STY temp+1
	PLA
	TAY
	PLA
	CLC
	ADC temp
	TAX
	TYA
	ADC temp+1
	TAY
	TXA
	PHA
	TYA
	PHA
	LDA cvb_C
	ASL A
	LDY #0
	BCC $+3
	INY
	CLC
	ADC #array_#SMY
	TAX
	TYA
	ADC #array_#SMY>>8
	TAY
	TXA
	STA temp
	STY temp+1
	PLA
	LDY #1
	STA (temp),Y
	PLA
	DEY
	STA (temp),Y
	; 				smz(c) = smz(c) + 2
	LDA #array_SMZ
	CLC
	ADC cvb_C
	STA temp
	LDA #array_SMZ>>8
	ADC #0
	STA temp+1
	LDY #0
	LDA (temp),Y
	CLC
	ADC #2
	STA (temp),Y
	; 				' Zigzag fluido: offset = ((seno * amp) / 128) - amp, somado ao centro.
	; 				' (/256 shift rapido + *2 = /128 com erro <1px, muito mais barato)
	; 				#tw = st(smz(c) AND 63)
	LDA #array_SMZ
	CLC
	ADC cvb_C
	TAX
	LDA #array_SMZ>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	AND #63
	LDY #0
	CLC
	ADC #array_ST
	TAX
	TYA
	ADC #array_ST>>8
	TAY
	TXA
	JSR _peek8
	LDY #0
	STA cvb_#TW
	STY cvb_#TW+1
	; 				#tw = (#tw * smc(c)) / 256
	PHA
	TYA
	PHA
	LDA #array_SMC
	CLC
	ADC cvb_C
	TAX
	LDA #array_SMC>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	LDY #0
	STA temp
	STY temp+1
	PLA
	TAY
	PLA
	JSR _mul16
	LDX #0
	STX temp
	LDX #1
	STX temp+1
	JSR _div16
	STA cvb_#TW
	STY cvb_#TW+1
	; 				#tw = #tw * 2
	STY temp
	ASL A
	ROL temp
	LDY temp
	STA cvb_#TW
	STY cvb_#TW+1
	; 				#tw = #tw + smp(c) - smc(c)
	PHA
	TYA
	PHA
	LDA #array_SMP
	CLC
	ADC cvb_C
	TAX
	LDA #array_SMP>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	LDY #0
	STA temp
	STY temp+1
	PLA
	TAY
	PLA
	CLC
	ADC temp
	TAX
	TYA
	ADC temp+1
	TAY
	TXA
	PHA
	TYA
	PHA
	LDA #array_SMC
	CLC
	ADC cvb_C
	TAX
	LDA #array_SMC>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	LDY #0
	STA temp
	STY temp+1
	PLA
	TAY
	PLA
	SEC
	SBC temp
	TAX
	TYA
	SBC temp+1
	TAY
	TXA
	STA cvb_#TW
	STY cvb_#TW+1
	; 				smx(c) = #tw
	LDA #array_SMX
	CLC
	ADC cvb_C
	TAX
	LDA #array_SMX>>8
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	LDA cvb_#TW
	LDY #0
	STA (temp),Y
	; 				yb = #smy(c) / 16 - 256		' y real (wrap p/ negativos)
	LDA cvb_C
	ASL A
	BCC $+3
	INY
	CLC
	ADC #array_#SMY
	TAX
	TYA
	ADC #array_#SMY>>8
	TAY
	TXA
	JSR _peek16
	LDX #16
	STX temp
	LDX #0
	STX temp+1
	JSR _div16
	SEC
	SBC #0
	STA cvb_YB
	; 				smyy(c) = yb	' cache p/ os frames sem atualizacao
	LDA #array_SMYY
	CLC
	ADC cvb_C
	TAX
	LDA #array_SMYY>>8
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	LDA cvb_YB
	LDY #0
	STA (temp),Y
	; 				IF #smy(c) >= 7904 THEN		' (238+256)*16: escapou por baixo
	LDA cvb_C
	ASL A
	BCC $+3
	INY
	CLC
	ADC #array_#SMY
	TAX
	TYA
	ADC #array_#SMY>>8
	TAY
	TXA
	JSR _peek16
	SEC
	SBC #224
	TYA
	SBC #30
	BCC.L cv137
	; 					sma(c) = 0
	LDA #array_SMA
	CLC
	ADC cvb_C
	TAX
	LDA #array_SMA>>8
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	LDA #0
	TAY
	STA (temp),Y
	; 				ELSE
	JMP cv138
cv137:
	; 					' Tiro mirado (ate 2)
	; 					IF smf(c) < 2 THEN
	LDA #array_SMF
	CLC
	ADC cvb_C
	TAX
	LDA #array_SMF>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	CMP #2
	BCS.L cv139
	; 						IF smd(c) = 0 THEN
	LDA #array_SMD
	CLC
	ADC cvb_C
	TAX
	LDA #array_SMD>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	CMP #0
	BNE.L cv140
	; 							' cota v0.12: no MAXIMO 3 tiros de small na tela;
	; 							' se cheia, espera e tenta de novo em 12 frames
	; 							IF nsm < 3 THEN
	LDA cvb_NSM
	CMP #3
	BCS.L cv141
	; 								smf(c) = smf(c) + 1
	LDA #array_SMF
	CLC
	ADC cvb_C
	STA temp
	LDA #array_SMF>>8
	ADC #0
	STA temp+1
	LDY #0
	LDA (temp),Y
	CLC
	ADC #1
	STA (temp),Y
	; 								smd(c) = 44 + RANDOM(28)
	JSR random
	LDX #28
	STX temp
	LDX #0
	STX temp+1
	JSR _mod16
	CLC
	ADC #44
	PHA
	LDA #array_SMD
	CLC
	ADC cvb_C
	TAX
	LDA #array_SMD>>8
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	PLA
	LDY #0
	STA (temp),Y
	; 								#tbx = smx(c) + 4
	LDA #array_SMX
	CLC
	ADC cvb_C
	TAX
	LDA #array_SMX>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	LDY #0
	CLC
	ADC #4
	TAX
	TYA
	ADC #0
	TAY
	TXA
	STA cvb_#TBX
	STY cvb_#TBX+1
	; 								#tby = yb + 8
	LDA cvb_YB
	LDY #0
	CLC
	ADC #8
	TAX
	TYA
	ADC #0
	TAY
	TXA
	STA cvb_#TBY
	STY cvb_#TBY+1
	; 								#adx = px + 8
	LDA cvb_PX
	LDY #0
	CLC
	ADC #8
	TAX
	TYA
	ADC #0
	TAY
	TXA
	STA cvb_#ADX
	STY cvb_#ADX+1
	; 								#adx = #adx - (smx(c) + 8)
	PHA
	TYA
	PHA
	LDA pointer
	LDY pointer+1
	JSR _peek8
	LDY #0
	CLC
	ADC #8
	TAX
	TYA
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	PLA
	TAY
	PLA
	SEC
	SBC temp
	TAX
	TYA
	SBC temp+1
	TAY
	TXA
	STA cvb_#ADX
	STY cvb_#ADX+1
	; 								#ady = py + 8
	LDA cvb_PY
	LDY #0
	CLC
	ADC #8
	TAX
	TYA
	ADC #0
	TAY
	TXA
	STA cvb_#ADY
	STY cvb_#ADY+1
	; 								#ady = #ady - (yb + 8)
	PHA
	TYA
	PHA
	LDA cvb_YB
	LDY #0
	CLC
	ADC #8
	TAX
	TYA
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	PLA
	TAY
	PLA
	SEC
	SBC temp
	TAX
	TYA
	SBC temp+1
	TAY
	TXA
	STA cvb_#ADY
	STY cvb_#ADY+1
	; 								GOSUB aim_8dir
	JSR cvb_AIM_8DIR
	; 								ebs = 1
	LDA #1
	STA cvb_EBS
	; 								GOSUB eb_spawn
	JSR cvb_EB_SPAWN
	; 							ELSE
	JMP cv142
cv141:
	; 								smd(c) = 12
	LDA #array_SMD
	CLC
	ADC cvb_C
	TAX
	LDA #array_SMD>>8
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	LDA #12
	LDY #0
	STA (temp),Y
	; 							END IF
cv142:
	; 						END IF
cv140:
	; 					END IF
cv139:
	; 					IF yb < 224 THEN		' so interage dentro da tela
	LDA cvb_YB
	CMP #224
	BCS.L cv143
	; 						' Encostou na nave?
	; 						IF ded = 0 AND inv = 0 THEN
	LDA cvb_INV
	BEQ cv145
	LDA #0
	DB $2c
cv145:
	LDA #255
	STA temp
	LDA cvb_DED
	BEQ cv146
	LDA #0
	DB $2c
cv146:
	LDA #255
	AND temp
	BEQ.L cv144
	; 							#c1 = px
	LDA cvb_PX
	LDY #0
	STA cvb_#C1
	STY cvb_#C1+1
	; 							#c1 = #c1 - smx(c)
	PHA
	TYA
	PHA
	LDA #array_SMX
	CLC
	ADC cvb_C
	TAX
	LDA #array_SMX>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	LDY #0
	STA temp
	STY temp+1
	PLA
	TAY
	PLA
	SEC
	SBC temp
	TAX
	TYA
	SBC temp+1
	TAY
	TXA
	STA cvb_#C1
	STY cvb_#C1+1
	; 							IF ABS(#c1) < 12 THEN
	JSR _abs16
	SEC
	SBC #12
	TYA
	SBC #0
	BCS.L cv147
	; 								#c2 = py
	LDA cvb_PY
	LDY #0
	STA cvb_#C2
	STY cvb_#C2+1
	; 								#c2 = #c2 - yb
	SEC
	SBC cvb_YB
	TAX
	TYA
	SBC #0
	TAY
	TXA
	STA cvb_#C2
	STY cvb_#C2+1
	; 								IF ABS(#c2) < 12 THEN
	JSR _abs16
	SEC
	SBC #12
	TYA
	SBC #0
	BCS.L cv148
	; 									' colisao = 1 tiro de dano no small tambem
	; 									sma(c) = 0
	LDA #array_SMA
	CLC
	ADC cvb_C
	TAX
	LDA #array_SMA>>8
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	LDA #0
	TAY
	STA (temp),Y
	; 									e = 1
	LDA #1
	STA cvb_E
	; 									d = 0
	TYA
	STA cvb_D
	; 									GOSUB score_add
	JSR cvb_SCORE_ADD
	; 									#pop = 8
	LDA #8
	LDY #0
	STA cvb_#POP
	STY cvb_#POP+1
	; 									mpt = 10
	LDA #10
	STA cvb_MPT
	; 									mpx = smx(c)
	LDA #array_SMX
	CLC
	ADC cvb_C
	TAX
	LDA #array_SMX>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	STA cvb_MPX
	; 									mpy = yb
	LDA cvb_YB
	STA cvb_MPY
	; 									GOTO player_dies
	JMP cvb_PLAYER_DIES
	; 								END IF
cv148:
	; 							END IF
cv147:
	; 						END IF
cv144:
	; 						' Levou tiro? (janelas byte, sem ABS = rapido)
	; 						FOR d = 0 TO 4
	LDA #0
	STA cvb_D
cv149:
	; 							IF bty(d) <> 0 THEN
	LDA #array_BTY
	CLC
	ADC cvb_D
	TAX
	LDA #array_BTY>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	CMP #0
	BEQ.L cv150
	; 								IF btx(d) + 6 > smx(c) AND btx(d) < smx(c) + 14 THEN
	LDA #array_SMX
	CLC
	ADC cvb_C
	TAX
	LDA #array_SMX>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	LDY #0
	PHA
	TYA
	PHA
	LDA #array_BTX
	CLC
	ADC cvb_D
	TAX
	LDA #array_BTX>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	LDY #0
	CLC
	ADC #6
	TAX
	TYA
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	PLA
	TAY
	PLA
	SEC
	SBC temp
	TYA
	SBC temp+1
	LDA #255
	ADC #0
	PHA
	LDA pointer
	LDY pointer+1
	JSR _peek8
	LDY #0
	PHA
	TYA
	PHA
	LDA #array_SMX
	CLC
	ADC cvb_C
	TAX
	LDA #array_SMX>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	LDY #0
	CLC
	ADC #14
	TAX
	TYA
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	PLA
	TAY
	PLA
	SEC
	SBC temp
	TYA
	SBC temp+1
	LDA #255
	ADC #0
	STA temp
	PLA
	AND temp
	BEQ.L cv151
	; 									IF bty(d) + 8 > yb AND bty(d) < yb + 16 THEN
	LDA cvb_YB
	LDY #0
	PHA
	TYA
	PHA
	LDA #array_BTY
	CLC
	ADC cvb_D
	TAX
	LDA #array_BTY>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	LDY #0
	CLC
	ADC #8
	TAX
	TYA
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	PLA
	TAY
	PLA
	SEC
	SBC temp
	TYA
	SBC temp+1
	LDA #255
	ADC #0
	PHA
	LDA pointer
	LDY pointer+1
	JSR _peek8
	LDY #0
	PHA
	TYA
	PHA
	LDA cvb_YB
	CLC
	ADC #16
	TAX
	TYA
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	PLA
	TAY
	PLA
	SEC
	SBC temp
	TYA
	SBC temp+1
	LDA #255
	ADC #0
	STA temp
	PLA
	AND temp
	BEQ.L cv152
	; 										bty(d) = 0
	LDA pointer
	LDY pointer+1
	STA temp
	STY temp+1
	LDA #0
	TAY
	STA (temp),Y
	; 										SPRITE 16 + d,$f0,0,0,0
	LDA cvb_D
	CLC
	ADC #16
	PHA
	LDA #240
	STA sprite_data
	TYA
	STA sprite_data+3
	STA sprite_data+1
	STA sprite_data+2
	PLA
	JSR update_sprite
	; 										sma(c) = 0
	LDA #array_SMA
	CLC
	ADC cvb_C
	TAX
	LDA #array_SMA>>8
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	LDA #0
	TAY
	STA (temp),Y
	; 										e = 1
	LDA #1
	STA cvb_E
	; 										d = 0
	TYA
	STA cvb_D
	; 										GOSUB score_add
	JSR cvb_SCORE_ADD
	; 										#pop = 8
	LDA #8
	LDY #0
	STA cvb_#POP
	STY cvb_#POP+1
	; 										mpt = 10
	LDA #10
	STA cvb_MPT
	; 										mpx = smx(c)
	LDA #array_SMX
	CLC
	ADC cvb_C
	TAX
	LDA #array_SMX>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	STA cvb_MPX
	; 										mpy = yb
	LDA cvb_YB
	STA cvb_MPY
	; 										d = 5
	LDA #5
	STA cvb_D
	; 									END IF
cv152:
	; 								END IF
cv151:
	; 							END IF
cv150:
	; 						NEXT d
	INC cvb_D
	LDA cvb_D
	CMP #5
	BCC.L cv149
	; 					END IF
cv143:
	; 				END IF
cv138:
	; 			END IF
cv136:
	; 		END IF
cv132:
	; 		' slot do anel escrito SEMPRE (vivo desenha do cache; morto, em
	; 		' entrada pelo alto ou saida por baixo = esconde). Byte do y
	; 		' cacheado enrola p/ 240+ na entrada pelo alto = esconde tambem.
	; 		IF sma(c) <> 0 THEN
	LDA #array_SMA
	CLC
	ADC cvb_C
	TAX
	LDA #array_SMA>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	CMP #0
	BEQ.L cv153
	; 			IF smyy(c) >= 240 THEN
	LDA #array_SMYY
	CLC
	ADC cvb_C
	TAX
	LDA #array_SMYY>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	CMP #240
	BCC.L cv154
	; 				SPRITE q1,$f0,0,0,0
	LDA cvb_Q1
	PHA
	LDA #240
	STA sprite_data
	LDA #0
	STA sprite_data+3
	STA sprite_data+1
	STA sprite_data+2
	PLA
	JSR update_sprite
	; 				SPRITE q2,$f0,0,0,0
	LDA cvb_Q2
	PHA
	LDA #240
	STA sprite_data
	LDA #0
	STA sprite_data+3
	STA sprite_data+1
	STA sprite_data+2
	PLA
	JSR update_sprite
	; 			ELSE
	JMP cv155
cv154:
	; 				SPRITE q1,smyy(c) - 1,smx(c),113,1
	LDA cvb_Q1
	PHA
	LDA #array_SMYY
	CLC
	ADC cvb_C
	TAX
	LDA #array_SMYY>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	SEC
	SBC #1
	STA sprite_data
	LDA #array_SMX
	CLC
	ADC cvb_C
	TAX
	LDA #array_SMX>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	STA sprite_data+3
	LDA #113
	STA sprite_data+1
	LDA #1
	STA sprite_data+2
	PLA
	JSR update_sprite
	; 				SPRITE q2,smyy(c) - 1,smx(c) + 8,115,1
	LDA cvb_Q2
	PHA
	LDA #array_SMYY
	CLC
	ADC cvb_C
	TAX
	LDA #array_SMYY>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	SEC
	SBC #1
	STA sprite_data
	LDA #array_SMX
	CLC
	ADC cvb_C
	TAX
	LDA #array_SMX>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	CLC
	ADC #8
	STA sprite_data+3
	LDA #115
	STA sprite_data+1
	LDA #1
	STA sprite_data+2
	PLA
	JSR update_sprite
	; 			END IF
cv155:
	; 		ELSE
	JMP cv156
cv153:
	; 			SPRITE q1,$f0,0,0,0
	LDA cvb_Q1
	PHA
	LDA #240
	STA sprite_data
	LDA #0
	STA sprite_data+3
	STA sprite_data+1
	STA sprite_data+2
	PLA
	JSR update_sprite
	; 			SPRITE q2,$f0,0,0,0
	LDA cvb_Q2
	PHA
	LDA #240
	STA sprite_data
	LDA #0
	STA sprite_data+3
	STA sprite_data+1
	STA sprite_data+2
	PLA
	JSR update_sprite
	; 		END IF
cv156:
	; 	NEXT c
	INC cvb_C
	LDA cvb_C
	CMP #6
	BCC.L cv129
	; 
	; 	' --- Shards (mergulho rapido; ao morrer soltam anel de 8 tiros) ---
	; 	' v0.14: metade por frame (passo dobrado = mesma velocidade) e y em
	; 	' pixel no cache shyc p/ desenhar todo frame no anel sem /16 extra
	; 	FOR c = 0 TO 3
	LDA #0
	STA cvb_C
cv157:
	; 		k = 12 + c + rr
	LDA cvb_C
	LDY #0
	CLC
	ADC #12
	TAX
	TYA
	ADC #0
	TAY
	TXA
	CLC
	ADC cvb_RR
	TAX
	TYA
	ADC #0
	TAY
	TXA
	STA cvb_K
	; 		IF k > 15 THEN k = k - 16
	CMP #16
	BCC.L cv158
	SEC
	SBC #16
	STA cvb_K
cv158:
	; 		q3 = r16(k)
	LDA #array_R16
	CLC
	ADC cvb_K
	TAX
	LDA #array_R16>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	STA cvb_Q3
	; 		IF sha(c) <> 0 THEN
	LDA #array_SHA
	CLC
	ADC cvb_C
	TAX
	LDA #array_SHA>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	CMP #0
	BEQ.L cv159
	; 			IF (c AND 1) = (FRAME AND 1) THEN
	LDA cvb_C
	AND #1
	LDY #0
	PHA
	TYA
	PHA
	LDA frame
	LDY frame+1
	AND #1
	LDY #0
	STA temp
	STY temp+1
	PLA
	TAY
	PLA
	SEC
	SBC temp
	STA temp
	TYA
	SBC temp+1
	ORA temp
	BNE.L cv160
	; 				IF shf(c) = 0 THEN
	LDA #array_SHF
	CLC
	ADC cvb_C
	TAX
	LDA #array_SHF>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	CMP #0
	BNE.L cv161
	; 					#shy(c) = #shy(c) + 64 + wdif * 8
	LDA cvb_C
	ASL A
	LDY #0
	BCC $+3
	INY
	CLC
	ADC #array_#SHY
	TAX
	TYA
	ADC #array_#SHY>>8
	TAY
	TXA
	JSR _peek16
	CLC
	ADC #64
	TAX
	TYA
	ADC #0
	TAY
	TXA
	PHA
	TYA
	PHA
	LDA cvb_WDIF
	LDY #0
	STY temp
	ASL A
	ROL temp
	ASL A
	ROL temp
	ASL A
	ROL temp
	LDY temp
	STA temp
	STY temp+1
	PLA
	TAY
	PLA
	CLC
	ADC temp
	TAX
	TYA
	ADC temp+1
	TAY
	TXA
	PHA
	TYA
	PHA
	LDA cvb_C
	ASL A
	LDY #0
	BCC $+3
	INY
	CLC
	ADC #array_#SHY
	TAX
	TYA
	ADC #array_#SHY>>8
	TAY
	TXA
	STA temp
	STY temp+1
	PLA
	LDY #1
	STA (temp),Y
	PLA
	DEY
	STA (temp),Y
	; 					IF #shy(c) >= 7712 THEN	' (226+256)*16: chegou embaixo
	LDA cvb_C
	ASL A
	LDY #0
	BCC $+3
	INY
	CLC
	ADC #array_#SHY
	TAX
	TYA
	ADC #array_#SHY>>8
	TAY
	TXA
	JSR _peek16
	SEC
	SBC #32
	TYA
	SBC #30
	BCC.L cv162
	; 						shf(c) = 1
	LDA #array_SHF
	CLC
	ADC cvb_C
	TAX
	LDA #array_SHF>>8
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	LDA #1
	LDY #0
	STA (temp),Y
	; 						IF shx(c) < 128 THEN
	LDA #array_SHX
	CLC
	ADC cvb_C
	TAX
	LDA #array_SHX>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	CMP #128
	BCS.L cv163
	; 							shvx(c) = 2	' sai p/ direita
	LDA #array_SHVX
	CLC
	ADC cvb_C
	TAX
	LDA #array_SHVX>>8
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	LDA #2
	LDY #0
	STA (temp),Y
	; 						ELSE
	JMP cv164
cv163:
	; 							shvx(c) = -2	' sai p/ esquerda
	LDA #array_SHVX
	CLC
	ADC cvb_C
	TAX
	LDA #array_SHVX>>8
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	LDA #254
	LDY #0
	STA (temp),Y
	; 						END IF
cv164:
	; 					END IF
cv162:
	; 				ELSE
	JMP cv165
cv161:
	; 					' 16-bit em 2 passos: shx+shvx em 8-bit estourava o sinal
	; 					' (x >= 128 virava negativo e o shard sumia no meio da tela!)
	; 					#ad = shx(c)
	LDA #array_SHX
	CLC
	ADC cvb_C
	TAX
	LDA #array_SHX>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	LDY #0
	STA cvb_#AD
	STY cvb_#AD+1
	; 					#ad = #ad + shvx(c)
	PHA
	TYA
	PHA
	LDA #array_SHVX
	CLC
	ADC cvb_C
	TAX
	LDA #array_SHVX>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	TAX
	AND #128
	BPL cv166
	LDA #255
cv166:
	TAY
	TXA
	STA temp
	STY temp+1
	PLA
	TAY
	PLA
	CLC
	ADC temp
	TAX
	TYA
	ADC temp+1
	TAY
	TXA
	STA cvb_#AD
	STY cvb_#AD+1
	; 					#ad = #ad + shvx(c)
	PHA
	TYA
	PHA
	LDA #array_SHVX
	CLC
	ADC cvb_C
	TAX
	LDA #array_SHVX>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	TAX
	AND #128
	BPL cv167
	LDA #255
cv167:
	TAY
	TXA
	STA temp
	STY temp+1
	PLA
	TAY
	PLA
	CLC
	ADC temp
	TAX
	TYA
	ADC temp+1
	TAY
	TXA
	STA cvb_#AD
	STY cvb_#AD+1
	; 					' NOTA: nunca repetir a mesma global 16-bit em 2+ comparacoes
	; 					' de um mesmo IF (bug de codegen: o TYA da 2a comparacao vem
	; 					' sujo e a condicao avalia errado). Por isso: um teste por IF.
	; 					wa = 0
	LDA #0
	STA cvb_WA
	; 					IF #ad < 1 THEN wa = 1	' esq: mata ANTES do wrap (byte nunca
	LDA cvb_#AD
	TAX
	TYA
	EOR #128
	TAY
	TXA
	SEC
	SBC #1
	TYA
	SBC #128
	BCS.L cv168
	LDA #1
	STA cvb_WA
cv168:
	; 					IF #ad > 255 THEN wa = 1	' recebe valor negativo e estoura p/ 255!)
	LDA cvb_#AD
	LDY cvb_#AD+1
	TAX
	TYA
	EOR #128
	TAY
	TXA
	SEC
	SBC #0
	TYA
	SBC #129
	BCC.L cv169
	LDA #1
	STA cvb_WA
cv169:
	; 					IF #shy(c) < 3840 THEN wa = 1	' saiu todo por cima
	LDA cvb_C
	ASL A
	LDY #0
	BCC $+3
	INY
	CLC
	ADC #array_#SHY
	TAX
	TYA
	ADC #array_#SHY>>8
	TAY
	TXA
	JSR _peek16
	SEC
	SBC #0
	TYA
	SBC #15
	BCS.L cv170
	LDA #1
	STA cvb_WA
cv170:
	; 					IF wa <> 0 THEN
	LDA cvb_WA
	BEQ.L cv171
	; 						sha(c) = 0
	LDA #array_SHA
	CLC
	ADC cvb_C
	TAX
	LDA #array_SHA>>8
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	LDA #0
	TAY
	STA (temp),Y
	; 					ELSE
	JMP cv172
cv171:
	; 						shx(c) = #ad
	LDA #array_SHX
	CLC
	ADC cvb_C
	TAX
	LDA #array_SHX>>8
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	LDA cvb_#AD
	LDY #0
	STA (temp),Y
	; 						#shy(c) = #shy(c) - 64
	LDA cvb_C
	ASL A
	BCC $+3
	INY
	CLC
	ADC #array_#SHY
	TAX
	TYA
	ADC #array_#SHY>>8
	TAY
	TXA
	STA temp
	STY temp+1
	LDA cvb_C
	ASL A
	LDY #0
	BCC $+3
	INY
	CLC
	ADC #array_#SHY
	TAX
	TYA
	ADC #array_#SHY>>8
	TAY
	TXA
	JSR _peek16
	SEC
	SBC #64
	TAX
	TYA
	SBC #0
	TAY
	TXA
	TAX
	TYA
	LDY #1
	STA (temp),Y
	TXA
	DEY
	STA (temp),Y
	; 					END IF
cv172:
	; 				END IF
cv165:
	; 				IF sha(c) <> 0 THEN
	LDA #array_SHA
	CLC
	ADC cvb_C
	TAX
	LDA #array_SHA>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	CMP #0
	BEQ.L cv173
	; 					yc = #shy(c) / 16 - 256	' y real
	LDA cvb_C
	ASL A
	LDY #0
	BCC $+3
	INY
	CLC
	ADC #array_#SHY
	TAX
	TYA
	ADC #array_#SHY>>8
	TAY
	TXA
	JSR _peek16
	LDX #16
	STX temp
	LDX #0
	STX temp+1
	JSR _div16
	SEC
	SBC #0
	STA cvb_YC
	; 					shyc(c) = yc	' cache p/ os frames sem atualizacao
	LDA #array_SHYC
	CLC
	ADC cvb_C
	TAX
	LDA #array_SHYC>>8
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	LDA cvb_YC
	LDY #0
	STA (temp),Y
	; 					IF #shy(c) >= 4096 THEN		' y real >= 0 (nao e wrap)
	LDA cvb_C
	ASL A
	BCC $+3
	INY
	CLC
	ADC #array_#SHY
	TAX
	TYA
	ADC #array_#SHY>>8
	TAY
	TXA
	JSR _peek16
	SEC
	SBC #0
	TYA
	SBC #16
	BCC.L cv174
	; 						' Encostou na nave?
	; 						IF ded = 0 AND inv = 0 THEN
	LDA cvb_INV
	BEQ cv176
	LDA #0
	DB $2c
cv176:
	LDA #255
	STA temp
	LDA cvb_DED
	BEQ cv177
	LDA #0
	DB $2c
cv177:
	LDA #255
	AND temp
	BEQ.L cv175
	; 							#c1 = px
	LDA cvb_PX
	LDY #0
	STA cvb_#C1
	STY cvb_#C1+1
	; 							#c1 = #c1 + 4 - shx(c)
	CLC
	ADC #4
	TAX
	TYA
	ADC #0
	TAY
	TXA
	PHA
	TYA
	PHA
	LDA #array_SHX
	CLC
	ADC cvb_C
	TAX
	LDA #array_SHX>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	LDY #0
	STA temp
	STY temp+1
	PLA
	TAY
	PLA
	SEC
	SBC temp
	TAX
	TYA
	SBC temp+1
	TAY
	TXA
	STA cvb_#C1
	STY cvb_#C1+1
	; 							IF ABS(#c1) < 10 THEN
	JSR _abs16
	SEC
	SBC #10
	TYA
	SBC #0
	BCS.L cv178
	; 								#c2 = py
	LDA cvb_PY
	LDY #0
	STA cvb_#C2
	STY cvb_#C2+1
	; 								#c2 = #c2 + 4 - yc
	CLC
	ADC #4
	TAX
	TYA
	ADC #0
	TAY
	TXA
	SEC
	SBC cvb_YC
	TAX
	TYA
	SBC #0
	TAY
	TXA
	STA cvb_#C2
	STY cvb_#C2+1
	; 								IF ABS(#c2) < 10 THEN
	JSR _abs16
	SEC
	SBC #10
	TYA
	SBC #0
	BCS.L cv179
	; 									' colisao = 1 tiro de dano no shard tambem
	; 									sha(c) = 0
	LDA #array_SHA
	CLC
	ADC cvb_C
	TAX
	LDA #array_SHA>>8
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	LDA #0
	TAY
	STA (temp),Y
	; 									e = 1
	LDA #1
	STA cvb_E
	; 									d = 2
	LDA #2
	STA cvb_D
	; 									GOSUB score_add
	JSR cvb_SCORE_ADD
	; 									#pop = 8
	LDA #8
	LDY #0
	STA cvb_#POP
	STY cvb_#POP+1
	; 									mpt = 10
	LDA #10
	STA cvb_MPT
	; 									mpx = shx(c) - 4
	LDA #array_SHX
	CLC
	ADC cvb_C
	TAX
	LDA #array_SHX>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	SEC
	SBC #4
	STA cvb_MPX
	; 									mpy = yc - 4
	LDA cvb_YC
	SEC
	SBC #4
	STA cvb_MPY
	; 									#tbx = shx(c) + 4
	LDA pointer
	LDY pointer+1
	JSR _peek8
	LDY #0
	CLC
	ADC #4
	TAX
	TYA
	ADC #0
	TAY
	TXA
	STA cvb_#TBX
	STY cvb_#TBX+1
	; 									#tby = yc + 4
	LDA cvb_YC
	LDY #0
	CLC
	ADC #4
	TAX
	TYA
	ADC #0
	TAY
	TXA
	STA cvb_#TBY
	STY cvb_#TBY+1
	; 									GOSUB spawn_ring
	JSR cvb_SPAWN_RING
	; 									GOTO player_dies
	JMP cvb_PLAYER_DIES
	; 								END IF
cv179:
	; 							END IF
cv178:
	; 						END IF
cv175:
	; 						' Levou tiro? -> ANEL DE 8 TIROS (igual ao original!)
	; 						' (janelas byte: shard longe das bordas p/ somas nao enrolarem)
	; 						IF yc < 224 AND shx(c) >= 8 AND shx(c) <= 240 THEN
	LDA #array_SHX
	CLC
	ADC cvb_C
	TAX
	LDA #array_SHX>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	CMP #8
	LDA #255
	ADC #0
	EOR #255
	STA temp
	LDA cvb_YC
	CMP #224
	LDA #255
	ADC #0
	AND temp
	PHA
	LDA pointer
	LDY pointer+1
	JSR _peek8
	CMP #241
	LDA #255
	ADC #0
	STA temp
	PLA
	AND temp
	BEQ.L cv180
	; 							FOR d = 0 TO 4
	LDA #0
	STA cvb_D
cv181:
	; 								IF bty(d) <> 0 THEN
	LDA #array_BTY
	CLC
	ADC cvb_D
	TAX
	LDA #array_BTY>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	CMP #0
	BEQ.L cv182
	; 									IF btx(d) + 8 > shx(c) AND btx(d) < shx(c) + 8 THEN
	LDA #array_SHX
	CLC
	ADC cvb_C
	TAX
	LDA #array_SHX>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	LDY #0
	PHA
	TYA
	PHA
	LDA #array_BTX
	CLC
	ADC cvb_D
	TAX
	LDA #array_BTX>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	LDY #0
	CLC
	ADC #8
	TAX
	TYA
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	PLA
	TAY
	PLA
	SEC
	SBC temp
	TYA
	SBC temp+1
	LDA #255
	ADC #0
	PHA
	LDA pointer
	LDY pointer+1
	JSR _peek8
	LDY #0
	PHA
	TYA
	PHA
	LDA #array_SHX
	CLC
	ADC cvb_C
	TAX
	LDA #array_SHX>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	LDY #0
	CLC
	ADC #8
	TAX
	TYA
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	PLA
	TAY
	PLA
	SEC
	SBC temp
	TYA
	SBC temp+1
	LDA #255
	ADC #0
	STA temp
	PLA
	AND temp
	BEQ.L cv183
	; 										IF bty(d) + 8 > yc AND bty(d) < yc + 8 THEN
	LDA cvb_YC
	LDY #0
	PHA
	TYA
	PHA
	LDA #array_BTY
	CLC
	ADC cvb_D
	TAX
	LDA #array_BTY>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	LDY #0
	CLC
	ADC #8
	TAX
	TYA
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	PLA
	TAY
	PLA
	SEC
	SBC temp
	TYA
	SBC temp+1
	LDA #255
	ADC #0
	PHA
	LDA pointer
	LDY pointer+1
	JSR _peek8
	LDY #0
	PHA
	TYA
	PHA
	LDA cvb_YC
	CLC
	ADC #8
	TAX
	TYA
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	PLA
	TAY
	PLA
	SEC
	SBC temp
	TYA
	SBC temp+1
	LDA #255
	ADC #0
	STA temp
	PLA
	AND temp
	BEQ.L cv184
	; 											bty(d) = 0
	LDA pointer
	LDY pointer+1
	STA temp
	STY temp+1
	LDA #0
	TAY
	STA (temp),Y
	; 											SPRITE 16 + d,$f0,0,0,0
	LDA cvb_D
	CLC
	ADC #16
	PHA
	LDA #240
	STA sprite_data
	TYA
	STA sprite_data+3
	STA sprite_data+1
	STA sprite_data+2
	PLA
	JSR update_sprite
	; 											sha(c) = 0
	LDA #array_SHA
	CLC
	ADC cvb_C
	TAX
	LDA #array_SHA>>8
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	LDA #0
	TAY
	STA (temp),Y
	; 											e = 1
	LDA #1
	STA cvb_E
	; 											d = 2
	LDA #2
	STA cvb_D
	; 											GOSUB score_add
	JSR cvb_SCORE_ADD
	; 											#pop = 8
	LDA #8
	LDY #0
	STA cvb_#POP
	STY cvb_#POP+1
	; 											mpt = 10
	LDA #10
	STA cvb_MPT
	; 											mpx = shx(c) - 4
	LDA #array_SHX
	CLC
	ADC cvb_C
	TAX
	LDA #array_SHX>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	SEC
	SBC #4
	STA cvb_MPX
	; 											mpy = yc - 4
	LDA cvb_YC
	SEC
	SBC #4
	STA cvb_MPY
	; 											#tbx = shx(c) + 4
	LDA pointer
	LDY pointer+1
	JSR _peek8
	LDY #0
	CLC
	ADC #4
	TAX
	TYA
	ADC #0
	TAY
	TXA
	STA cvb_#TBX
	STY cvb_#TBX+1
	; 											#tby = yc + 4
	LDA cvb_YC
	LDY #0
	CLC
	ADC #4
	TAX
	TYA
	ADC #0
	TAY
	TXA
	STA cvb_#TBY
	STY cvb_#TBY+1
	; 											GOSUB spawn_ring
	JSR cvb_SPAWN_RING
	; 											d = 5
	LDA #5
	STA cvb_D
	; 										END IF
cv184:
	; 									END IF
cv183:
	; 								END IF
cv182:
	; 							NEXT d
	INC cvb_D
	LDA cvb_D
	CMP #5
	BCC.L cv181
	; 						END IF
cv180:
	; 					END IF
cv174:
	; 				END IF
cv173:
	; 			END IF
cv160:
	; 		END IF
cv159:
	; 		' slot do anel escrito SEMPRE (cache; regras de esconde idem v0.13)
	; 		IF sha(c) <> 0 THEN
	LDA #array_SHA
	CLC
	ADC cvb_C
	TAX
	LDA #array_SHA>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	CMP #0
	BEQ.L cv185
	; 			IF #shy(c) < 4112 THEN	' (1+256)*16: entrada pelo alto enrola
	LDA cvb_C
	ASL A
	LDY #0
	BCC $+3
	INY
	CLC
	ADC #array_#SHY
	TAX
	TYA
	ADC #array_#SHY>>8
	TAY
	TXA
	JSR _peek16
	SEC
	SBC #16
	TYA
	SBC #16
	BCS.L cv186
	; 				SPRITE q3,$f0,0,0,0	' o byte do y p/ 192+ = NAO pode usar
	LDA cvb_Q3
	PHA
	LDA #240
	STA sprite_data
	LDA #0
	STA sprite_data+3
	STA sprite_data+1
	STA sprite_data+2
	PLA
	JSR update_sprite
	; 			ELSE				' shyc>=240 p/ esconder (cobre ate y=-64)!
	JMP cv187
cv186:
	; 				' esconde durante wrap de x (-8..-1) na saida p/ esquerda:
	; 				' senao o sprite pisca na borda direita por alguns frames
	; 				IF shvx(c) < 0 AND shx(c) > 240 AND shf(c) = 1 THEN
	LDA #array_SHX
	CLC
	ADC cvb_C
	TAX
	LDA #array_SHX>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	CMP #241
	LDA #255
	ADC #0
	EOR #255
	STA temp
	LDA #array_SHVX
	CLC
	ADC cvb_C
	TAX
	LDA #array_SHVX>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	TAX
	AND #128
	BPL cv189
	LDA #255
cv189:
	TAY
	TXA
	TAX
	TYA
	EOR #128
	TAY
	TXA
	SEC
	SBC #0
	TYA
	SBC #128
	LDA #255
	ADC #0
	AND temp
	PHA
	LDA #array_SHF
	CLC
	ADC cvb_C
	TAX
	LDA #array_SHF>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	CMP #1
	BEQ cv190
	LDA #0
	DB $2c
cv190:
	LDA #255
	STA temp
	PLA
	AND temp
	BEQ.L cv188
	; 					SPRITE q3,$f0,0,0,0
	LDA cvb_Q3
	PHA
	LDA #240
	STA sprite_data
	LDA #0
	STA sprite_data+3
	STA sprite_data+1
	STA sprite_data+2
	PLA
	JSR update_sprite
	; 				ELSE
	JMP cv191
cv188:
	; 					SPRITE q3,shyc(c) - 1,shx(c),125 + ((FRAME / 4) AND 3) * 2,2
	LDA cvb_Q3
	PHA
	LDA #array_SHYC
	CLC
	ADC cvb_C
	TAX
	LDA #array_SHYC>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	SEC
	SBC #1
	STA sprite_data
	LDA #array_SHX
	CLC
	ADC cvb_C
	TAX
	LDA #array_SHX>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	STA sprite_data+3
	LDA frame
	LDY frame+1
	STY temp
	LSR temp
	ROR A
	LSR temp
	ROR A
	LDY temp
	AND #3
	ASL A
	CLC
	ADC #125
	STA sprite_data+1
	LDA #2
	STA sprite_data+2
	PLA
	JSR update_sprite
	; 				END IF
cv191:
	; 			END IF
cv187:
	; 		ELSE
	JMP cv192
cv185:
	; 			SPRITE q3,$f0,0,0,0
	LDA cvb_Q3
	PHA
	LDA #240
	STA sprite_data
	LDA #0
	STA sprite_data+3
	STA sprite_data+1
	STA sprite_data+2
	PLA
	JSR update_sprite
	; 		END IF
cv192:
	; 	NEXT c
	INC cvb_C
	LDA cvb_C
	CMP #4
	BCC.L cv157
	; 
	; 	' --- Enemy4: cruza do alto a base (descida de meteoro); atira 1x mirado ---
	; 	' v0.14: metade por frame (passo dobrado = mesma velocidade; o loop com
	; 	' 8 Enemy4 era o MAIOR slowdown medido do v0.13: ~10% dos frames!),
	; 	' slots fixos 41-56 como sempre (fora do anel: prioridade classica)
	; 	FOR c = 0 TO 7
	LDA #0
	STA cvb_C
cv193:
	; 		IF e4a(c) <> 0 THEN
	LDA #array_E4A
	CLC
	ADC cvb_C
	TAX
	LDA #array_E4A>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	CMP #0
	BEQ.L cv194
	; 			IF (c AND 1) = (FRAME AND 1) THEN
	LDA cvb_C
	AND #1
	LDY #0
	PHA
	TYA
	PHA
	LDA frame
	LDY frame+1
	AND #1
	LDY #0
	STA temp
	STY temp+1
	PLA
	TAY
	PLA
	SEC
	SBC temp
	STA temp
	TYA
	SBC temp+1
	ORA temp
	BNE.L cv195
	; 				#e4y(c) = #e4y(c) + e4w(c)
	LDA cvb_C
	ASL A
	LDY #0
	BCC $+3
	INY
	CLC
	ADC #array_#E4Y
	TAX
	TYA
	ADC #array_#E4Y>>8
	TAY
	TXA
	JSR _peek16
	PHA
	TYA
	PHA
	LDA #array_E4W
	CLC
	ADC cvb_C
	TAX
	LDA #array_E4W>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	LDY #0
	STA temp
	STY temp+1
	PLA
	TAY
	PLA
	CLC
	ADC temp
	TAX
	TYA
	ADC temp+1
	TAY
	TXA
	PHA
	TYA
	PHA
	LDA cvb_C
	ASL A
	LDY #0
	BCC $+3
	INY
	CLC
	ADC #array_#E4Y
	TAX
	TYA
	ADC #array_#E4Y>>8
	TAY
	TXA
	STA temp
	STY temp+1
	PLA
	LDY #1
	STA (temp),Y
	PLA
	DEY
	STA (temp),Y
	; 				#e4y(c) = #e4y(c) + e4w(c)
	LDA cvb_C
	ASL A
	LDY #0
	BCC $+3
	INY
	CLC
	ADC #array_#E4Y
	TAX
	TYA
	ADC #array_#E4Y>>8
	TAY
	TXA
	JSR _peek16
	PHA
	TYA
	PHA
	LDA #array_E4W
	CLC
	ADC cvb_C
	TAX
	LDA #array_E4W>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	LDY #0
	STA temp
	STY temp+1
	PLA
	TAY
	PLA
	CLC
	ADC temp
	TAX
	TYA
	ADC temp+1
	TAY
	TXA
	PHA
	TYA
	PHA
	LDA cvb_C
	ASL A
	LDY #0
	BCC $+3
	INY
	CLC
	ADC #array_#E4Y
	TAX
	TYA
	ADC #array_#E4Y>>8
	TAY
	TXA
	STA temp
	STY temp+1
	PLA
	LDY #1
	STA (temp),Y
	PLA
	DEY
	STA (temp),Y
	; 				yc = #e4y(c) / 16 - 256		' y real
	LDA cvb_C
	ASL A
	LDY #0
	BCC $+3
	INY
	CLC
	ADC #array_#E4Y
	TAX
	TYA
	ADC #array_#E4Y>>8
	TAY
	TXA
	JSR _peek16
	LDX #16
	STX temp
	LDX #0
	STX temp+1
	JSR _div16
	SEC
	SBC #0
	STA cvb_YC
	; 				IF #e4y(c) >= 7904 THEN		' (238+256)*16: escapou por baixo
	LDA cvb_C
	ASL A
	LDY #0
	BCC $+3
	INY
	CLC
	ADC #array_#E4Y
	TAX
	TYA
	ADC #array_#E4Y>>8
	TAY
	TXA
	JSR _peek16
	SEC
	SBC #224
	TYA
	SBC #30
	BCC.L cv196
	; 					e4a(c) = 0
	LDA #array_E4A
	CLC
	ADC cvb_C
	TAX
	LDA #array_E4A>>8
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	LDA #0
	TAY
	STA (temp),Y
	; 					SPRITE 41 + c * 2,$f0,0,0,0
	LDA cvb_C
	ASL A
	CLC
	ADC #41
	PHA
	LDA #240
	STA sprite_data
	TYA
	STA sprite_data+3
	STA sprite_data+1
	STA sprite_data+2
	PLA
	JSR update_sprite
	; 					SPRITE 42 + c * 2,$f0,0,0,0
	LDA cvb_C
	ASL A
	CLC
	ADC #42
	PHA
	LDA #240
	STA sprite_data
	LDA #0
	STA sprite_data+3
	STA sprite_data+1
	STA sprite_data+2
	PLA
	JSR update_sprite
	; 				ELSE
	JMP cv197
cv196:
	; 					' Tiro unico mirado ao cruzar a faixa topo-meio (y 64-127):
	; 					' antes era timer de 2.5s e 90% morria sem atirar (v0.10)
	; 					IF e4f(c) <> 0 THEN
	LDA #array_E4F
	CLC
	ADC cvb_C
	TAX
	LDA #array_E4F>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	CMP #0
	BEQ.L cv198
	; 						IF yc >= 64 THEN
	LDA cvb_YC
	CMP #64
	BCC.L cv199
	; 							IF yc < 128 THEN
	CMP #128
	BCS.L cv200
	; 								e4f(c) = 0
	LDA pointer
	LDY pointer+1
	STA temp
	STY temp+1
	LDA #0
	TAY
	STA (temp),Y
	; 								#tbx = e4x(c) + 4
	LDA #array_E4X
	CLC
	ADC cvb_C
	TAX
	LDA #array_E4X>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	LDY #0
	CLC
	ADC #4
	TAX
	TYA
	ADC #0
	TAY
	TXA
	STA cvb_#TBX
	STY cvb_#TBX+1
	; 								#tby = yc + 8
	LDA cvb_YC
	LDY #0
	CLC
	ADC #8
	TAX
	TYA
	ADC #0
	TAY
	TXA
	STA cvb_#TBY
	STY cvb_#TBY+1
	; 								#adx = px + 8
	LDA cvb_PX
	LDY #0
	CLC
	ADC #8
	TAX
	TYA
	ADC #0
	TAY
	TXA
	STA cvb_#ADX
	STY cvb_#ADX+1
	; 								#adx = #adx - (e4x(c) + 8)
	PHA
	TYA
	PHA
	LDA pointer
	LDY pointer+1
	JSR _peek8
	LDY #0
	CLC
	ADC #8
	TAX
	TYA
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	PLA
	TAY
	PLA
	SEC
	SBC temp
	TAX
	TYA
	SBC temp+1
	TAY
	TXA
	STA cvb_#ADX
	STY cvb_#ADX+1
	; 								#ady = py + 8
	LDA cvb_PY
	LDY #0
	CLC
	ADC #8
	TAX
	TYA
	ADC #0
	TAY
	TXA
	STA cvb_#ADY
	STY cvb_#ADY+1
	; 								#ady = #ady - (yc + 8)
	PHA
	TYA
	PHA
	LDA cvb_YC
	LDY #0
	CLC
	ADC #8
	TAX
	TYA
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	PLA
	TAY
	PLA
	SEC
	SBC temp
	TAX
	TYA
	SBC temp+1
	TAY
	TXA
	STA cvb_#ADY
	STY cvb_#ADY+1
	; 								GOSUB aim_8dir
	JSR cvb_AIM_8DIR
	; 								ebs = 0
	LDA #0
	STA cvb_EBS
	; 								GOSUB eb_spawn
	JSR cvb_EB_SPAWN
	; 							END IF
cv200:
	; 						END IF
cv199:
	; 					END IF
cv198:
	; 					IF #e4y(c) < 4112 THEN	' entrando pelo alto: esconde
	LDA cvb_C
	ASL A
	LDY #0
	BCC $+3
	INY
	CLC
	ADC #array_#E4Y
	TAX
	TYA
	ADC #array_#E4Y>>8
	TAY
	TXA
	JSR _peek16
	SEC
	SBC #16
	TYA
	SBC #16
	BCS.L cv201
	; 						SPRITE 41 + c * 2,$f0,0,0,0	' p/ nao aparecer embaixo
	LDA cvb_C
	ASL A
	CLC
	ADC #41
	PHA
	LDA #240
	STA sprite_data
	LDA #0
	STA sprite_data+3
	STA sprite_data+1
	STA sprite_data+2
	PLA
	JSR update_sprite
	; 						SPRITE 42 + c * 2,$f0,0,0,0
	LDA cvb_C
	ASL A
	CLC
	ADC #42
	PHA
	LDA #240
	STA sprite_data
	LDA #0
	STA sprite_data+3
	STA sprite_data+1
	STA sprite_data+2
	PLA
	JSR update_sprite
	; 					ELSE
	JMP cv202
cv201:
	; 					' 2 sprites 8x16, 1 frame estatico (byte OAM IMPAR! bit0=1 ->
	; 					' tabela $1000; 137 = T68 -> tiles fis. 392/393; pal0 = meteorito)
	; 					SPRITE 41 + c * 2,yc - 1,e4x(c),137,0
	LDA cvb_C
	ASL A
	CLC
	ADC #41
	PHA
	LDA cvb_YC
	SEC
	SBC #1
	STA sprite_data
	LDA #array_E4X
	CLC
	ADC cvb_C
	TAX
	LDA #array_E4X>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	STA sprite_data+3
	LDA #137
	STA sprite_data+1
	LDA #0
	STA sprite_data+2
	PLA
	JSR update_sprite
	; 					SPRITE 42 + c * 2,yc - 1,e4x(c) + 8,139,0
	LDA cvb_C
	ASL A
	CLC
	ADC #42
	PHA
	LDA cvb_YC
	SEC
	SBC #1
	STA sprite_data
	LDA #array_E4X
	CLC
	ADC cvb_C
	TAX
	LDA #array_E4X>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	CLC
	ADC #8
	STA sprite_data+3
	LDA #139
	STA sprite_data+1
	LDA #0
	STA sprite_data+2
	PLA
	JSR update_sprite
	; 					END IF
cv202:
	; 					IF yc < 224 THEN		' so interage dentro da tela
	LDA cvb_YC
	CMP #224
	BCS.L cv203
	; 						IF ded = 0 AND inv = 0 THEN
	LDA cvb_INV
	BEQ cv205
	LDA #0
	DB $2c
cv205:
	LDA #255
	STA temp
	LDA cvb_DED
	BEQ cv206
	LDA #0
	DB $2c
cv206:
	LDA #255
	AND temp
	BEQ.L cv204
	; 							#c1 = px
	LDA cvb_PX
	LDY #0
	STA cvb_#C1
	STY cvb_#C1+1
	; 							#c1 = #c1 - e4x(c)
	PHA
	TYA
	PHA
	LDA #array_E4X
	CLC
	ADC cvb_C
	TAX
	LDA #array_E4X>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	LDY #0
	STA temp
	STY temp+1
	PLA
	TAY
	PLA
	SEC
	SBC temp
	TAX
	TYA
	SBC temp+1
	TAY
	TXA
	STA cvb_#C1
	STY cvb_#C1+1
	; 							IF ABS(#c1) < 12 THEN
	JSR _abs16
	SEC
	SBC #12
	TYA
	SBC #0
	BCS.L cv207
	; 								#c2 = py
	LDA cvb_PY
	LDY #0
	STA cvb_#C2
	STY cvb_#C2+1
	; 								#c2 = #c2 - yc
	SEC
	SBC cvb_YC
	TAX
	TYA
	SBC #0
	TAY
	TXA
	STA cvb_#C2
	STY cvb_#C2+1
	; 								IF ABS(#c2) < 12 THEN
	JSR _abs16
	SEC
	SBC #12
	TYA
	SBC #0
	BCS.L cv208
	; 									' colisao = 1 tiro de dano no enemy4 tambem
	; 									e4a(c) = 0
	LDA #array_E4A
	CLC
	ADC cvb_C
	TAX
	LDA #array_E4A>>8
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	LDA #0
	TAY
	STA (temp),Y
	; 									SPRITE 41 + c * 2,$f0,0,0,0
	LDA cvb_C
	ASL A
	CLC
	ADC #41
	PHA
	LDA #240
	STA sprite_data
	TYA
	STA sprite_data+3
	STA sprite_data+1
	STA sprite_data+2
	PLA
	JSR update_sprite
	; 									SPRITE 42 + c * 2,$f0,0,0,0
	LDA cvb_C
	ASL A
	CLC
	ADC #42
	PHA
	LDA #240
	STA sprite_data
	LDA #0
	STA sprite_data+3
	STA sprite_data+1
	STA sprite_data+2
	PLA
	JSR update_sprite
	; 									e = 3
	LDA #3
	STA cvb_E
	; 									d = 0
	LDA #0
	STA cvb_D
	; 									GOSUB score_add
	JSR cvb_SCORE_ADD
	; 									#pop = 8
	LDA #8
	LDY #0
	STA cvb_#POP
	STY cvb_#POP+1
	; 									mpt = 10
	LDA #10
	STA cvb_MPT
	; 									mpx = e4x(c)
	LDA #array_E4X
	CLC
	ADC cvb_C
	TAX
	LDA #array_E4X>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	STA cvb_MPX
	; 									mpy = yc
	LDA cvb_YC
	STA cvb_MPY
	; 									GOTO player_dies
	JMP cvb_PLAYER_DIES
	; 								END IF
cv208:
	; 							END IF
cv207:
	; 						END IF
cv204:
	; 						' Levou tiro? (janelas byte: colunas longe das bordas)
	; 						FOR d = 0 TO 4
	LDA #0
	STA cvb_D
cv209:
	; 							IF bty(d) <> 0 THEN
	LDA #array_BTY
	CLC
	ADC cvb_D
	TAX
	LDA #array_BTY>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	CMP #0
	BEQ.L cv210
	; 								IF btx(d) + 6 > e4x(c) AND btx(d) < e4x(c) + 14 THEN
	LDA #array_E4X
	CLC
	ADC cvb_C
	TAX
	LDA #array_E4X>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	LDY #0
	PHA
	TYA
	PHA
	LDA #array_BTX
	CLC
	ADC cvb_D
	TAX
	LDA #array_BTX>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	LDY #0
	CLC
	ADC #6
	TAX
	TYA
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	PLA
	TAY
	PLA
	SEC
	SBC temp
	TYA
	SBC temp+1
	LDA #255
	ADC #0
	PHA
	LDA pointer
	LDY pointer+1
	JSR _peek8
	LDY #0
	PHA
	TYA
	PHA
	LDA #array_E4X
	CLC
	ADC cvb_C
	TAX
	LDA #array_E4X>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	LDY #0
	CLC
	ADC #14
	TAX
	TYA
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	PLA
	TAY
	PLA
	SEC
	SBC temp
	TYA
	SBC temp+1
	LDA #255
	ADC #0
	STA temp
	PLA
	AND temp
	BEQ.L cv211
	; 									IF bty(d) + 8 > yc AND bty(d) < yc + 16 THEN
	LDA cvb_YC
	LDY #0
	PHA
	TYA
	PHA
	LDA #array_BTY
	CLC
	ADC cvb_D
	TAX
	LDA #array_BTY>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	LDY #0
	CLC
	ADC #8
	TAX
	TYA
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	PLA
	TAY
	PLA
	SEC
	SBC temp
	TYA
	SBC temp+1
	LDA #255
	ADC #0
	PHA
	LDA pointer
	LDY pointer+1
	JSR _peek8
	LDY #0
	PHA
	TYA
	PHA
	LDA cvb_YC
	CLC
	ADC #16
	TAX
	TYA
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	PLA
	TAY
	PLA
	SEC
	SBC temp
	TYA
	SBC temp+1
	LDA #255
	ADC #0
	STA temp
	PLA
	AND temp
	BEQ.L cv212
	; 										bty(d) = 0
	LDA pointer
	LDY pointer+1
	STA temp
	STY temp+1
	LDA #0
	TAY
	STA (temp),Y
	; 										SPRITE 16 + d,$f0,0,0,0
	LDA cvb_D
	CLC
	ADC #16
	PHA
	LDA #240
	STA sprite_data
	TYA
	STA sprite_data+3
	STA sprite_data+1
	STA sprite_data+2
	PLA
	JSR update_sprite
	; 										e4a(c) = 0
	LDA #array_E4A
	CLC
	ADC cvb_C
	TAX
	LDA #array_E4A>>8
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	LDA #0
	TAY
	STA (temp),Y
	; 										SPRITE 41 + c * 2,$f0,0,0,0
	LDA cvb_C
	ASL A
	CLC
	ADC #41
	PHA
	LDA #240
	STA sprite_data
	TYA
	STA sprite_data+3
	STA sprite_data+1
	STA sprite_data+2
	PLA
	JSR update_sprite
	; 										SPRITE 42 + c * 2,$f0,0,0,0
	LDA cvb_C
	ASL A
	CLC
	ADC #42
	PHA
	LDA #240
	STA sprite_data
	LDA #0
	STA sprite_data+3
	STA sprite_data+1
	STA sprite_data+2
	PLA
	JSR update_sprite
	; 										e = 3		' 300 pontos (igual ao medA do original)
	LDA #3
	STA cvb_E
	; 										d = 0
	LDA #0
	STA cvb_D
	; 										GOSUB score_add
	JSR cvb_SCORE_ADD
	; 										#pop = 8
	LDA #8
	LDY #0
	STA cvb_#POP
	STY cvb_#POP+1
	; 										mpt = 10
	LDA #10
	STA cvb_MPT
	; 										mpx = e4x(c)
	LDA #array_E4X
	CLC
	ADC cvb_C
	TAX
	LDA #array_E4X>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	STA cvb_MPX
	; 										mpy = yc
	LDA cvb_YC
	STA cvb_MPY
	; 										d = 5
	LDA #5
	STA cvb_D
	; 									END IF
cv212:
	; 								END IF
cv211:
	; 							END IF
cv210:
	; 						NEXT d
	INC cvb_D
	LDA cvb_D
	CMP #5
	BCC.L cv209
	; 					END IF
cv203:
	; 				END IF
cv197:
	; 			END IF
cv195:
	; 		END IF
cv194:
	; 	NEXT c
	INC cvb_C
	LDA cvb_C
	CMP #8
	BCC.L cv193
	; 
	; 	' --- Miniboss (v0.11: 32x32, entra pelo topo, desce ate o meio, ---
	; 	' patrulha esq/dir e lanca aneis de 8 tiros, tipo o shard ao morrer)
	; 	IF mba THEN
	LDA cvb_MBA
	CMP #0
	BEQ.L cv213
	; 		BANK SELECT 1
	LDA #0
	ORA CHRRAM_BANK
	STA BANKSEL
	; 		GOSUB mb_frame			' v0.15: bloco moveu p/ proc (banco 1 no mapper 30)
	JSR cvb_MB_FRAME
	; 		IF diek THEN			' proc pediu morte da nave
	LDA cvb_DIEK
	CMP #0
	BEQ.L cv214
	; 			diek = 0
	LDA #0
	STA cvb_DIEK
	; 			GOTO player_dies
	JMP cvb_PLAYER_DIES
	; 		END IF
cv214:
	; 	END IF
cv213:
	; 
	; 	' --- BOSS (v0.12): 96x128 = centro em BG + asas em sprite; ------
	; 	' fases: 1) leques de 3 alternando as asas; 2) saraivada p/ baixo
	; 	' de posicoes/velocidades variadas; 3) laser do meio 3x; repete ---
	; 	IF bsa THEN
	LDA cvb_BSA
	CMP #0
	BEQ.L cv215
	; 		BANK SELECT 1
	LDA #0
	ORA CHRRAM_BANK
	STA BANKSEL
	; 		GOSUB boss_frame		' v0.15: bloco moveu p/ proc (banco 1 no mapper 30)
	JSR cvb_BOSS_FRAME
	; 		IF diek THEN
	LDA cvb_DIEK
	CMP #0
	BEQ.L cv216
	; 			diek = 0
	LDA #0
	STA cvb_DIEK
	; 			GOTO player_dies
	JMP cvb_PLAYER_DIES
	; 		END IF
cv216:
	; 	END IF
cv215:
	; 
	; 	' --- Tiros inimigos: metade por frame (passo dobrado = mesma velocidade) ---
	; 	FOR c = 0 TO 7
	LDA #0
	STA cvb_C
cv217:
	; 		IF eba(c) <> 0 THEN
	LDA #array_EBA
	CLC
	ADC cvb_C
	TAX
	LDA #array_EBA>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	CMP #0
	BEQ.L cv218
	; 			IF (c AND 1) = (FRAME AND 1) THEN
	LDA cvb_C
	AND #1
	LDY #0
	PHA
	TYA
	PHA
	LDA frame
	LDY frame+1
	AND #1
	LDY #0
	STA temp
	STY temp+1
	PLA
	TAY
	PLA
	SEC
	SBC temp
	STA temp
	TYA
	SBC temp+1
	ORA temp
	BNE.L cv219
	; 				#ebx(c) = #ebx(c) + ebxv(c)
	LDA cvb_C
	ASL A
	LDY #0
	BCC $+3
	INY
	CLC
	ADC #array_#EBX
	TAX
	TYA
	ADC #array_#EBX>>8
	TAY
	TXA
	JSR _peek16
	PHA
	TYA
	PHA
	LDA #array_EBXV
	CLC
	ADC cvb_C
	TAX
	LDA #array_EBXV>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	TAX
	AND #128
	BPL cv220
	LDA #255
cv220:
	TAY
	TXA
	STA temp
	STY temp+1
	PLA
	TAY
	PLA
	CLC
	ADC temp
	TAX
	TYA
	ADC temp+1
	TAY
	TXA
	PHA
	TYA
	PHA
	LDA cvb_C
	ASL A
	LDY #0
	BCC $+3
	INY
	CLC
	ADC #array_#EBX
	TAX
	TYA
	ADC #array_#EBX>>8
	TAY
	TXA
	STA temp
	STY temp+1
	PLA
	LDY #1
	STA (temp),Y
	PLA
	DEY
	STA (temp),Y
	; 				#eby(c) = #eby(c) + ebyv(c)
	LDA cvb_C
	ASL A
	LDY #0
	BCC $+3
	INY
	CLC
	ADC #array_#EBY
	TAX
	TYA
	ADC #array_#EBY>>8
	TAY
	TXA
	JSR _peek16
	PHA
	TYA
	PHA
	LDA #array_EBYV
	CLC
	ADC cvb_C
	TAX
	LDA #array_EBYV>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	TAX
	AND #128
	BPL cv221
	LDA #255
cv221:
	TAY
	TXA
	STA temp
	STY temp+1
	PLA
	TAY
	PLA
	CLC
	ADC temp
	TAX
	TYA
	ADC temp+1
	TAY
	TXA
	PHA
	TYA
	PHA
	LDA cvb_C
	ASL A
	LDY #0
	BCC $+3
	INY
	CLC
	ADC #array_#EBY
	TAX
	TYA
	ADC #array_#EBY>>8
	TAY
	TXA
	STA temp
	STY temp+1
	PLA
	LDY #1
	STA (temp),Y
	PLA
	DEY
	STA (temp),Y
	; 				#ebx(c) = #ebx(c) + ebxv(c)
	LDA cvb_C
	ASL A
	LDY #0
	BCC $+3
	INY
	CLC
	ADC #array_#EBX
	TAX
	TYA
	ADC #array_#EBX>>8
	TAY
	TXA
	JSR _peek16
	PHA
	TYA
	PHA
	LDA #array_EBXV
	CLC
	ADC cvb_C
	TAX
	LDA #array_EBXV>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	TAX
	AND #128
	BPL cv222
	LDA #255
cv222:
	TAY
	TXA
	STA temp
	STY temp+1
	PLA
	TAY
	PLA
	CLC
	ADC temp
	TAX
	TYA
	ADC temp+1
	TAY
	TXA
	PHA
	TYA
	PHA
	LDA cvb_C
	ASL A
	LDY #0
	BCC $+3
	INY
	CLC
	ADC #array_#EBX
	TAX
	TYA
	ADC #array_#EBX>>8
	TAY
	TXA
	STA temp
	STY temp+1
	PLA
	LDY #1
	STA (temp),Y
	PLA
	DEY
	STA (temp),Y
	; 				#eby(c) = #eby(c) + ebyv(c)
	LDA cvb_C
	ASL A
	LDY #0
	BCC $+3
	INY
	CLC
	ADC #array_#EBY
	TAX
	TYA
	ADC #array_#EBY>>8
	TAY
	TXA
	JSR _peek16
	PHA
	TYA
	PHA
	LDA #array_EBYV
	CLC
	ADC cvb_C
	TAX
	LDA #array_EBYV>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	TAX
	AND #128
	BPL cv223
	LDA #255
cv223:
	TAY
	TXA
	STA temp
	STY temp+1
	PLA
	TAY
	PLA
	CLC
	ADC temp
	TAX
	TYA
	ADC temp+1
	TAY
	TXA
	PHA
	TYA
	PHA
	LDA cvb_C
	ASL A
	LDY #0
	BCC $+3
	INY
	CLC
	ADC #array_#EBY
	TAX
	TYA
	ADC #array_#EBY>>8
	TAY
	TXA
	STA temp
	STY temp+1
	PLA
	LDY #1
	STA (temp),Y
	PLA
	DEY
	STA (temp),Y
	; 				' fora da tela? (matar antes do wrap do byte: x em [-4,252], y em [-8,224])
	; 			IF #ebx(c) < 4032 OR #ebx(c) > 8128 OR #eby(c) > 7680 OR #eby(c) < 3968 THEN
	LDA cvb_C
	ASL A
	LDY #0
	BCC $+3
	INY
	CLC
	ADC #array_#EBX
	TAX
	TYA
	ADC #array_#EBX>>8
	TAY
	TXA
	JSR _peek16
	SEC
	SBC #193
	TYA
	SBC #31
	LDA #255
	ADC #0
	EOR #255
	STA temp
	LDA cvb_C
	ASL A
	LDY #0
	BCC $+3
	INY
	CLC
	ADC #array_#EBX
	TAX
	TYA
	ADC #array_#EBX>>8
	TAY
	TXA
	JSR _peek16
	SEC
	SBC #192
	TYA
	SBC #15
	LDA #255
	ADC #0
	ORA temp
	PHA
	LDA cvb_C
	ASL A
	LDY #0
	BCC $+3
	INY
	CLC
	ADC #array_#EBY
	TAX
	TYA
	ADC #array_#EBY>>8
	TAY
	TXA
	JSR _peek16
	SEC
	SBC #1
	TYA
	SBC #30
	LDA #255
	ADC #0
	EOR #255
	STA temp
	PLA
	ORA temp
	PHA
	LDA cvb_C
	ASL A
	LDY #0
	BCC $+3
	INY
	CLC
	ADC #array_#EBY
	TAX
	TYA
	ADC #array_#EBY>>8
	TAY
	TXA
	JSR _peek16
	SEC
	SBC #128
	TYA
	SBC #15
	LDA #255
	ADC #0
	STA temp
	PLA
	ORA temp
	BEQ.L cv224
	; 				IF ebt(c) = 1 THEN
	LDA #array_EBT
	CLC
	ADC cvb_C
	TAX
	LDA #array_EBT>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	CMP #1
	BNE.L cv225
	; 					nsm = nsm - 1		' saiu tiro de small: libera a cota
	DEC cvb_NSM
	; 					ebt(c) = 0
	LDA pointer
	LDY pointer+1
	STA temp
	STY temp+1
	LDA #0
	TAY
	STA (temp),Y
	; 				END IF
cv225:
	; 				eba(c) = 0
	LDA #array_EBA
	CLC
	ADC cvb_C
	TAX
	LDA #array_EBA>>8
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	LDA #0
	TAY
	STA (temp),Y
	; 				SPRITE 25 + c,$f0,0,0,0
	LDA cvb_C
	CLC
	ADC #25
	PHA
	LDA #240
	STA sprite_data
	TYA
	STA sprite_data+3
	STA sprite_data+1
	STA sprite_data+2
	PLA
	JSR update_sprite
	; 				ELSE
	JMP cv226
cv224:
	; 					' 2 divisoes por tiro (reuso p/ desenho E colisao)
	; 					#t1 = #ebx(c) / 16
	LDA cvb_C
	ASL A
	LDY #0
	BCC $+3
	INY
	CLC
	ADC #array_#EBX
	TAX
	TYA
	ADC #array_#EBX>>8
	TAY
	TXA
	JSR _peek16
	LDX #16
	STX temp
	LDX #0
	STX temp+1
	JSR _div16
	STA cvb_#T1
	STY cvb_#T1+1
	; 					#t2 = #eby(c) / 16
	LDA cvb_C
	ASL A
	LDY #0
	BCC $+3
	INY
	CLC
	ADC #array_#EBY
	TAX
	TYA
	ADC #array_#EBY>>8
	TAY
	TXA
	JSR _peek16
	LDX #16
	STX temp
	LDX #0
	STX temp+1
	JSR _div16
	STA cvb_#T2
	STY cvb_#T2+1
	; 					xb = #t1 - 256
	LDA cvb_#T1
	SEC
	SBC #0
	STA cvb_XB
	; 					yc = #t2 - 256
	LDA cvb_#T2
	SEC
	SBC #0
	STA cvb_YC
	; 					SPRITE 25 + c,yc - 1,xb,133 + ((FRAME / 4) AND 1) * 2,3
	LDA cvb_C
	CLC
	ADC #25
	PHA
	LDA cvb_YC
	SEC
	SBC #1
	STA sprite_data
	LDA cvb_XB
	STA sprite_data+3
	LDA frame
	LDY frame+1
	STY temp
	LSR temp
	ROR A
	LSR temp
	ROR A
	LDY temp
	AND #1
	ASL A
	CLC
	ADC #133
	STA sprite_data+1
	LDA #3
	STA sprite_data+2
	PLA
	JSR update_sprite
	; 					IF ded = 0 AND inv = 0 THEN
	LDA cvb_INV
	BEQ cv228
	LDA #0
	DB $2c
cv228:
	LDA #255
	STA temp
	LDA cvb_DED
	BEQ cv229
	LDA #0
	DB $2c
cv229:
	LDA #255
	AND temp
	BEQ.L cv227
	; 						' janela (px-4, px+12) em escala "real+256" = (px+252, px+268)
	; 						' (um teste por IF: ver nota do codegen no shard)
	; 						#c1 = px
	LDA cvb_PX
	LDY #0
	STA cvb_#C1
	STY cvb_#C1+1
	; 						#c1 = #c1 + 252
	CLC
	ADC #252
	TAX
	TYA
	ADC #0
	TAY
	TXA
	STA cvb_#C1
	STY cvb_#C1+1
	; 						IF #t1 >= #c1 THEN
	LDA cvb_#T1
	LDY cvb_#T1+1
	TAX
	TYA
	EOR #128
	TAY
	TXA
	PHA
	TYA
	PHA
	LDA cvb_#C1
	LDY cvb_#C1+1
	TAX
	TYA
	EOR #128
	TAY
	TXA
	STA temp
	STY temp+1
	PLA
	TAY
	PLA
	SEC
	SBC temp
	TYA
	SBC temp+1
	BCC.L cv230
	; 							#c1 = px
	LDA cvb_PX
	LDY #0
	STA cvb_#C1
	STY cvb_#C1+1
	; 							#c1 = #c1 + 268
	CLC
	ADC #12
	TAX
	TYA
	ADC #1
	TAY
	TXA
	STA cvb_#C1
	STY cvb_#C1+1
	; 							IF #t1 < #c1 THEN
	LDA cvb_#T1
	LDY cvb_#T1+1
	TAX
	TYA
	EOR #128
	TAY
	TXA
	PHA
	TYA
	PHA
	LDA cvb_#C1
	LDY cvb_#C1+1
	TAX
	TYA
	EOR #128
	TAY
	TXA
	STA temp
	STY temp+1
	PLA
	TAY
	PLA
	SEC
	SBC temp
	TYA
	SBC temp+1
	BCS.L cv231
	; 								#c2 = py
	LDA cvb_PY
	LDY #0
	STA cvb_#C2
	STY cvb_#C2+1
	; 								#c2 = #c2 + 252
	CLC
	ADC #252
	TAX
	TYA
	ADC #0
	TAY
	TXA
	STA cvb_#C2
	STY cvb_#C2+1
	; 								IF #t2 >= #c2 THEN
	LDA cvb_#T2
	LDY cvb_#T2+1
	TAX
	TYA
	EOR #128
	TAY
	TXA
	PHA
	TYA
	PHA
	LDA cvb_#C2
	LDY cvb_#C2+1
	TAX
	TYA
	EOR #128
	TAY
	TXA
	STA temp
	STY temp+1
	PLA
	TAY
	PLA
	SEC
	SBC temp
	TYA
	SBC temp+1
	BCC.L cv232
	; 									#c2 = py
	LDA cvb_PY
	LDY #0
	STA cvb_#C2
	STY cvb_#C2+1
	; 									#c2 = #c2 + 268
	CLC
	ADC #12
	TAX
	TYA
	ADC #1
	TAY
	TXA
	STA cvb_#C2
	STY cvb_#C2+1
	; 									IF #t2 < #c2 THEN
	LDA cvb_#T2
	LDY cvb_#T2+1
	TAX
	TYA
	EOR #128
	TAY
	TXA
	PHA
	TYA
	PHA
	LDA cvb_#C2
	LDY cvb_#C2+1
	TAX
	TYA
	EOR #128
	TAY
	TXA
	STA temp
	STY temp+1
	PLA
	TAY
	PLA
	SEC
	SBC temp
	TYA
	SBC temp+1
	BCS.L cv233
	; 										GOTO player_dies
	JMP cvb_PLAYER_DIES
	; 									END IF
cv233:
	; 								END IF
cv232:
	; 							END IF
cv231:
	; 						END IF
cv230:
	; 					END IF
cv227:
	; 				END IF
cv226:
	; 			END IF
cv219:
	; 		END IF
cv218:
	; 	NEXT c
	INC cvb_C
	LDA cvb_C
	CMP #8
	BCC.L cv217
	; 
	; 	' --- Mini-explosao de morte de inimigo ---
	; 	IF mpt > 0 THEN
	LDA cvb_MPT
	CMP #1
	BCC.L cv234
	; 		SPRITE 33,mpy - 1,mpx,13,3
	LDA #33
	PHA
	LDA cvb_MPY
	SEC
	SBC #1
	STA sprite_data
	LDA cvb_MPX
	STA sprite_data+3
	LDA #13
	STA sprite_data+1
	LDA #3
	STA sprite_data+2
	PLA
	JSR update_sprite
	; 		SPRITE 34,mpy - 1,mpx + 8,15,3
	LDA #34
	PHA
	LDA cvb_MPY
	SEC
	SBC #1
	STA sprite_data
	LDA cvb_MPX
	CLC
	ADC #8
	STA sprite_data+3
	LDA #15
	STA sprite_data+1
	LDA #3
	STA sprite_data+2
	PLA
	JSR update_sprite
	; 		mpt = mpt - 1
	DEC cvb_MPT
	; 		IF mpt = 0 THEN
	LDA cvb_MPT
	BNE.L cv235
	; 			SPRITE 33,$f0,0,0,0
	LDA #33
	PHA
	LDA #240
	STA sprite_data
	LDA #0
	STA sprite_data+3
	STA sprite_data+1
	STA sprite_data+2
	PLA
	JSR update_sprite
	; 			SPRITE 34,$f0,0,0,0
	LDA #34
	PHA
	LDA #240
	STA sprite_data
	LDA #0
	STA sprite_data+3
	STA sprite_data+1
	STA sprite_data+2
	PLA
	JSR update_sprite
	; 		END IF
cv235:
	; 	END IF
cv234:
	; 
	; 	' --- Fim da onda? ---
	; 	IF wact <> 0 AND qn = 0 THEN
	LDA cvb_QN
	BEQ cv237
	LDA #0
	DB $2c
cv237:
	LDA #255
	STA temp
	LDA cvb_WACT
	BNE cv238
	LDA #0
	DB $2c
cv238:
	LDA #255
	AND temp
	BEQ.L cv236
	; 		e = sma(0) + sma(1) + sma(2) + sma(3) + sma(4) + sma(5)
	LDA array_SMA+1
	STA temp
	LDA array_SMA
	CLC
	ADC temp
	PHA
	LDA array_SMA+2
	STA temp
	PLA
	CLC
	ADC temp
	PHA
	LDA array_SMA+3
	STA temp
	PLA
	CLC
	ADC temp
	PHA
	LDA array_SMA+4
	STA temp
	PLA
	CLC
	ADC temp
	PHA
	LDA array_SMA+5
	STA temp
	PLA
	CLC
	ADC temp
	STA cvb_E
	; 		e = e + sha(0) + sha(1) + sha(2) + sha(3)
	LDA array_SHA
	STA temp
	LDA cvb_E
	CLC
	ADC temp
	PHA
	LDA array_SHA+1
	STA temp
	PLA
	CLC
	ADC temp
	PHA
	LDA array_SHA+2
	STA temp
	PLA
	CLC
	ADC temp
	PHA
	LDA array_SHA+3
	STA temp
	PLA
	CLC
	ADC temp
	STA cvb_E
	; 		e = e + e4a(0) + e4a(1) + e4a(2) + e4a(3)
	LDA array_E4A
	STA temp
	LDA cvb_E
	CLC
	ADC temp
	PHA
	LDA array_E4A+1
	STA temp
	PLA
	CLC
	ADC temp
	PHA
	LDA array_E4A+2
	STA temp
	PLA
	CLC
	ADC temp
	PHA
	LDA array_E4A+3
	STA temp
	PLA
	CLC
	ADC temp
	STA cvb_E
	; 		e = e + e4a(4) + e4a(5) + e4a(6) + e4a(7)
	LDA array_E4A+4
	STA temp
	LDA cvb_E
	CLC
	ADC temp
	PHA
	LDA array_E4A+5
	STA temp
	PLA
	CLC
	ADC temp
	PHA
	LDA array_E4A+6
	STA temp
	PLA
	CLC
	ADC temp
	PHA
	LDA array_E4A+7
	STA temp
	PLA
	CLC
	ADC temp
	STA cvb_E
	; 		e = e + mba
	CLC
	ADC cvb_MBA
	STA cvb_E
	; 		e = e + bsa
	CLC
	ADC cvb_BSA
	STA cvb_E
	; 		IF e = 0 THEN
	TAX
	AND #128
	BPL cv240
	LDA #255
cv240:
	TAY
	TXA
	STY temp
	ORA temp
	BNE.L cv239
	; 			wact = 0
	LDA #0
	STA cvb_WACT
	; 			wpausa = 30			' v0.9: era 70 (jogo mais desafiador)
	LDA #30
	STA cvb_WPAUSA
	; 			wnum = wnum + 1
	INC cvb_WNUM
	; 			wtipo = wtipo + 1		' cicla 0 (small) -> 1 (shard) -> 2 (enemy4)
	INC cvb_WTIPO
	; 			IF wtipo >= 3 THEN wtipo = 0
	LDA cvb_WTIPO
	CMP #3
	BCC.L cv241
	LDA #0
	STA cvb_WTIPO
cv241:
	; 			wdif = wnum / 2
	LDA cvb_WNUM
	LSR A
	STA cvb_WDIF
	; 			IF wdif > 3 THEN wdif = 3
	CMP #4
	BCC.L cv242
	LDA #3
	STA cvb_WDIF
cv242:
	; 		END IF
cv239:
	; 	END IF
cv236:
	; 
	; 	' Som do tiro (subindo de tom) - no PULSO 2: divide canal so com o arpejo
	; 	' (antes era SOUND 10 = pulso 1 = mesmo canal da melodia => picotava ela)
	; 	IF #pew > 0 THEN
	LDA cvb_#PEW
	LDY cvb_#PEW+1
	SEC
	SBC #1
	TYA
	SBC #0
	BCC.L cv243
	; 		SOUND 11,$0800 + 200 + #pew * 40,$89
	LDA cvb_#PEW
	LDX #40
	STX temp
	LDX #0
	STX temp+1
	JSR _mul16
	CLC
	ADC #200
	TAX
	TYA
	ADC #8
	TAY
	TXA
	STA $4006
	STY $4007
	LDA #137
	STA $4004
	; 		#pew = #pew - 1
	LDA cvb_#PEW
	LDY cvb_#PEW+1
	SEC
	SBC #1
	TAX
	TYA
	SBC #0
	TAY
	TXA
	STA cvb_#PEW
	STY cvb_#PEW+1
	; 		IF #pew = 0 THEN SOUND 11,,$10
	STY temp
	ORA temp
	BNE.L cv244
	LDA #16
	STA $4004
cv244:
	; 	END IF
cv243:
	; 
	; 	' Som de destruicao (ruido decaindo)
	; 	IF #pop > 0 THEN
	LDA cvb_#POP
	LDY cvb_#POP+1
	SEC
	SBC #1
	TYA
	SBC #0
	BCC.L cv245
	; 		SOUND 14,$e6 + (#pop AND 1),$13 + #pop / 2
	LDA cvb_#POP
	AND #1
	LDY #0
	CLC
	ADC #230
	TAX
	TYA
	ADC #0
	TAY
	TXA
	STA $400e
	STY $400f
	LDA cvb_#POP
	LDY cvb_#POP+1
	STY temp
	LSR temp
	ROR A
	LDY temp
	CLC
	ADC #19
	STA $400c
	; 		#pop = #pop - 1
	LDA cvb_#POP
	LDY cvb_#POP+1
	SEC
	SBC #1
	TAX
	TYA
	SBC #0
	TAY
	TXA
	STA cvb_#POP
	STY cvb_#POP+1
	; 		IF #pop = 0 THEN SOUND 14,,$10
	STY temp
	ORA temp
	BNE.L cv246
	LDA #16
	STA $400c
cv246:
	; 	END IF
cv245:
	; 
	; 	GOTO game_loop
	JMP cvb_GAME_LOOP
	; 
	; 	'
	; 	' v0.19: FASE 01 COMPLETA -> fade -> cartao FASE 02 -> begin_stage
	; 	'
	; fase1_clear:
cvb_FASE1_CLEAR:
	; 	VPOKE $3F00,$0F		' fim do estrobo
	LDA #15
	PHA
	LDA #0
	LDY #63
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	POKE $1C,$00		' v0.28: cartoes/textos saem da pagina 0
	LDA #0
	PHA
	LDA #28
	LDY #0
	STA temp
	STY temp+1
	PLA
	STA (temp),Y
	; 	BANK SELECT 1
	TYA
	ORA CHRRAM_BANK
	STA BANKSEL
	; 	GOSUB fase_completa
	JSR cvb_FASE_COMPLETA
	; 	IF fase = 5 THEN	' v0.28: GORF vencido = FIM DE JOGO
	LDA cvb_FASE
	CMP #5
	BNE.L cv247
	; 		GOSUB end_vitoria
	JSR cvb_END_VITORIA
	; 		GOSUB end_creditos
	JSR cvb_END_CREDITOS
	; 		GOSUB end_theend
	JSR cvb_END_THEEND
	; 		BANK SELECT 0
	LDA #31
	ORA CHRRAM_BANK
	STA BANKSEL
	; 		GOTO go_reset		' depois do THE END? volta ao splash com reset completo
	JMP cvb_GO_RESET
	; 	END IF
cv247:
	; 	fase = fase + 1
	INC cvb_FASE
	; 	GOSUB stage_card	' v0.28: cartao generico (usa a var fase)
	JSR cvb_STAGE_CARD
	; 	BANK SELECT 0
	LDA #31
	ORA CHRRAM_BANK
	STA BANKSEL
	; 	GOTO begin_stage
	JMP cvb_BEGIN_STAGE
	; 
	; 	'
	; 	' A NAVE EXPLODIU
	; 	'
	; player_dies:
cvb_PLAYER_DIES:
	; 	ded = 40
	LDA #40
	STA cvb_DED
	; 	li = li - 1
	DEC cvb_LI
	; 	GOSUB update_lives
	JSR cvb_UPDATE_LIVES
	; 	SOUND 10,,$10
	LDA #16
	STA $4000
	; 	SOUND 11,,$10
	STA $4004
	; death_loop:
cvb_DEATH_LOOP:
	; 	WAIT
	JSR wait
	; 	e = py - 1 + RANDOM(5) - 2
	LDA cvb_PY
	LDY #0
	SEC
	SBC #1
	TAX
	TYA
	SBC #0
	TAY
	TXA
	PHA
	TYA
	PHA
	JSR random
	LDX #5
	STX temp
	LDX #0
	STX temp+1
	JSR _mod16
	STA temp
	STY temp+1
	PLA
	TAY
	PLA
	CLC
	ADC temp
	TAX
	TYA
	ADC temp+1
	TAY
	TXA
	SEC
	SBC #2
	STA cvb_E
	; 	d = px + RANDOM(5) - 2
	LDA cvb_PX
	LDY #0
	PHA
	TYA
	PHA
	JSR random
	LDX #5
	STX temp
	LDX #0
	STX temp+1
	JSR _mod16
	STA temp
	STY temp+1
	PLA
	TAY
	PLA
	CLC
	ADC temp
	TAX
	TYA
	ADC temp+1
	TAY
	TXA
	SEC
	SBC #2
	STA cvb_D
	; 	SPRITE 0,$f0,0,0,0	' esconde canopy/chama
	LDA #0
	PHA
	LDA #240
	STA sprite_data
	LDA #0
	STA sprite_data+3
	STA sprite_data+1
	STA sprite_data+2
	PLA
	JSR update_sprite
	; 	SPRITE 1,$f0,0,0,0
	LDA #1
	PHA
	LDA #240
	STA sprite_data
	LDA #0
	STA sprite_data+3
	STA sprite_data+1
	STA sprite_data+2
	PLA
	JSR update_sprite
	; 	SPRITE 2,e,d,13,3	' explosao no lugar do corpo
	LDA #2
	PHA
	LDA cvb_E
	STA sprite_data
	LDA cvb_D
	STA sprite_data+3
	LDA #13
	STA sprite_data+1
	LDA #3
	STA sprite_data+2
	PLA
	JSR update_sprite
	; 	SPRITE 3,e,d + 8,15,3
	LDA #3
	PHA
	LDA cvb_E
	STA sprite_data
	LDA cvb_D
	CLC
	ADC #8
	STA sprite_data+3
	LDA #15
	STA sprite_data+1
	LDA #3
	STA sprite_data+2
	PLA
	JSR update_sprite
	; 	SOUND 14,$e4 + (ded AND 3),$1d
	LDA cvb_DED
	AND #3
	LDY #0
	CLC
	ADC #228
	TAX
	TYA
	ADC #0
	TAY
	TXA
	STA $400e
	STY $400f
	LDA #29
	STA $400c
	; 	IF (ded AND 8) = 0 THEN
	LDA cvb_DED
	AND #8
	BNE.L cv248
	; 		PALETTE 0,$10
	LDA #0
	LDX ppu_pointer
	STA PPUBUF,X
	LDA #$7f
	STA PPUBUF+1,X
	LDA #16
	STA PPUBUF+2,X
	INX
	INX
	INX
	STX ppu_pointer
	; 	ELSE
	JMP cv249
cv248:
	; 		PALETTE 0,$0f
	LDA #0
	LDX ppu_pointer
	STA PPUBUF,X
	LDA #$7f
	STA PPUBUF+1,X
	LDA #15
	STA PPUBUF+2,X
	INX
	INX
	INX
	STX ppu_pointer
	; 	END IF
cv249:
	; 	ded = ded - 1
	DEC cvb_DED
	; 	IF ded <> 0 THEN GOTO death_loop
	LDA cvb_DED
	BEQ.L cv250
	JMP cvb_DEATH_LOOP
cv250:
	; 
	; 	GOSUB silence
	JSR cvb_SILENCE
	; 	PALETTE 0,$0f
	LDA #0
	LDX ppu_pointer
	STA PPUBUF,X
	LDA #$7f
	STA PPUBUF+1,X
	LDA #15
	STA PPUBUF+2,X
	INX
	INX
	INX
	STX ppu_pointer
	; 	SPRITE 2,$f0,0,0,0
	LDA #2
	PHA
	LDA #240
	STA sprite_data
	LDA #0
	STA sprite_data+3
	STA sprite_data+1
	STA sprite_data+2
	PLA
	JSR update_sprite
	; 	SPRITE 3,$f0,0,0,0
	LDA #3
	PHA
	LDA #240
	STA sprite_data
	LDA #0
	STA sprite_data+3
	STA sprite_data+1
	STA sprite_data+2
	PLA
	JSR update_sprite
	; 
	; 	IF li > 0 THEN
	LDA cvb_LI
	CMP #1
	BCC.L cv251
	; 		' Respawn embaixo no centro, invencivel por 1.5s
	; 		px = 120
	LDA #120
	STA cvb_PX
	; 		py = 200
	LDA #200
	STA cvb_PY
	; 		dir = 0
	LDA #0
	STA cvb_DIR
	; 		ret = 0
	STA cvb_RET
	; 		an = 0
	STA cvb_AN
	; 		slot = 0
	STA cvb_SLOT
	; 		inv = 90
	LDA #90
	STA cvb_INV
	; 		GOTO game_loop
	JMP cvb_GAME_LOOP
	; 	END IF
cv251:
	; 
	; 	FOR c = 0 TO 63		' esconde todos os sprites
	LDA #0
	STA cvb_C
cv252:
	; 		SPRITE c,$f0,0,0,0
	LDA cvb_C
	PHA
	LDA #240
	STA sprite_data
	LDA #0
	STA sprite_data+3
	STA sprite_data+1
	STA sprite_data+2
	PLA
	JSR update_sprite
	; 	NEXT c
	INC cvb_C
	LDA cvb_C
	CMP #64
	BCC.L cv252
	; 
	; 	' v0.13: morreu DURANTE o boss? devolve a tabela $0000 ANTES de
	; 	' imprimir os textos (senao a fonte sai da tabela errada!)
	; 	IF bsa THEN
	LDA cvb_BSA
	CMP #0
	BEQ.L cv253
	; 		ASM LDA #$A8
 LDA #$A8
	; 		ASM STA ppu_ctrl
 STA ppu_ctrl
	; 		bsa = 0
	LDA #0
	STA cvb_BSA
	; 		bsw = 0
	STA cvb_BSW
	; 		bol = 0
	STA cvb_BOL
	; 		boff = 0
	STA cvb_BOFF
	; 	END IF
cv253:
	; 
	; 	PLAY OFF		' para a musica no game over
	LDA #music_silence
	LDY #music_silence>>8
	JSR music_play
	; 	POKE $1C,$00		' v0.28: texto do GO sai da pagina 0 (apos lava/agua)
	LDA #0
	PHA
	LDA #28
	LDY #0
	STA temp
	STY temp+1
	PLA
	STA (temp),Y
	; 	CLS
	JSR cls
	; 	SCROLL 0,0
	LDA #0
	TAY
	STA scroll_x
	STY scroll_x+1
	STA scroll_y
	STY scroll_y+1
	; 	PALETTE LOAD game_palette_title
	STA pointer
	LDA #63
	STA pointer+1
	LDA #32
	STA temp2
	LDA #cvb_GAME_PALETTE_TITLE
	STA temp
	LDA #cvb_GAME_PALETTE_TITLE>>8
	STA temp+1
	JSR LDIRVM
	; 	WAIT			' separa a carga da paleta dos attrs (limite do NMI)
	JSR wait
	; 	FOR i = 0 TO 39		' zera attrs das linhas 0-4 (se morreu no boss)
	LDA #0
	STA cvb_I
cv254:
	; 		VPOKE $23C0 + i,0
	LDA #0
	PHA
	LDA cvb_I
	LDY #0
	CLC
	ADC #192
	TAX
	TYA
	ADC #35
	TAY
	TXA
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 		IF i = 31 THEN WAIT	' no maximo 32 escritas por VBlank
	LDA cvb_I
	CMP #31
	BNE.L cv255
	JSR wait
cv255:
	; 	NEXT i
	INC cvb_I
	LDA cvb_I
	CMP #40
	BCC.L cv254
	; 	WAIT
	JSR wait
	; 	VPOKE $23D2,$40		' "GAME OVER"  -> pal1 (branco)
	LDA #64
	PHA
	LDA #210
	LDY #35
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $23D3,$50
	LDA #80
	PHA
	LDA #211
	LDY #35
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $23D4,$50
	LDA #80
	PHA
	LDA #212
	LDY #35
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $23D9,$04		' "PONTOS/ONDA" -> pal1
	LDA #4
	PHA
	LDA #217
	LDY #35
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $23DA,$45		' + "APERTE START" (quads inf.)
	LDA #69
	PHA
	LDA #218
	LDY #35
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $23DB,$55
	LDA #85
	PHA
	LDA #219
	LDY #35
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $23DC,$55
	LDA #85
	PHA
	LDA #220
	LDY #35
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $23DD,$10
	LDA #16
	PHA
	LDA #221
	LDY #35
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	WAIT
	JSR wait
	; 
	; 	BANK SELECT 1		' v0.18: desenho+fade do game over mora no banco 1
	LDA #0
	ORA CHRRAM_BANK
	STA BANKSEL
	; 	GOSUB go_draw
	JSR cvb_GO_DRAW
	; 	BANK SELECT 0
	LDA #31
	ORA CHRRAM_BANK
	STA BANKSEL
	; go_wait:
cvb_GO_WAIT:
	; 	WAIT
	JSR wait
	; 	IF (FRAME AND 16) = 0 THEN
	LDA frame
	LDY frame+1
	AND #16
	LDY #0
	STY temp
	ORA temp
	BNE.L cv256
	; 		PRINT AT 458,"APERTE START"
	JSR print_string_cursor_constant
	DB $ca,$01,$0c
	DB $41,$50,$45,$52,$54,$45,$20,$53
	DB $54,$41,$52,$54
	; 	ELSE
	JMP cv257
cv256:
	; 		PRINT AT 458,"            "
	JSR print_string_cursor_constant
	DB $ca,$01,$0c
	DB $20,$20,$20,$20,$20,$20,$20,$20
	DB $20,$20,$20,$20
	; 	END IF
cv257:
	; 	IF CONT1.KEY = 11 THEN GOTO go_reset	' v0.25: reset de software!
	LDA key1_data
	CMP #11
	BNE.L cv258
	JMP cvb_GO_RESET
cv258:
	; 	IF CONT1.BUTTON THEN GOTO go_reset
	LDA joy1_data
	AND #64
	BEQ.L cv259
	JMP cvb_GO_RESET
cv259:
	; 	GOTO go_wait
	JMP cvb_GO_WAIT
	; 
	; go_reset:				' v0.25: game over = RESET COMPLETO (pedido do Saulo)
cvb_GO_RESET:
	; 	' Zera os 2KB de RAM, zera PPU/APU, reseta a pilha e salta p/ o vetor
	; 	' de reset ($FFFC) = volta ao inicio do programa, tudo zerado.
	; 	PLAY OFF
	LDA #music_silence
	LDY #music_silence>>8
	JSR music_play
	; 	ASM LDA #$00
 LDA #$00
	; 	ASM STA $2000
 STA $2000
	; 	ASM STA $2001
 STA $2001
	; 	ASM STA $4015
 STA $4015
	; 	ASM LDA #$40
 LDA #$40
	; 	ASM STA $4017
 STA $4017
	; 	ASM TAY
 TAY
	; 	ASM STA $00
 STA $00
	; 	ASM STA $01
 STA $01
	; 	ASM LDX #$08
 LDX #$08
	; 	ASM go_reset_zap:
go_reset_zap:
	; 	ASM STA ($00),Y
 STA ($00),Y
	; 	ASM INY
 INY
	; 	ASM BNE go_reset_zap
 BNE go_reset_zap
	; 	ASM INC $01
 INC $01
	; 	ASM DEX
 DEX
	; 	ASM BNE go_reset_zap
 BNE go_reset_zap
	; 	ASM LDX #$FF
 LDX #$FF
	; 	ASM TXS
 TXS
	; 	ASM JMP ($FFFC)
 JMP ($FFFC)
	; 
	; 	'
	; 	' Sub-rotinas
	; 	'
	; silence:	PROCEDURE
cvb_SILENCE:
	; 	SOUND 10,,$10
	LDA #16
	STA $4000
	; 	SOUND 11,,$10
	STA $4004
	; 	SOUND 14,,$10
	STA $400c
	; 	END
	RTS
	; 
	; 	' (v0.28: anim_idle mora no banco 1 - ver antes da FONTE SAULO.)
	; 
	; 	' v0.28: QUEM saiu do banco 0 p/ dar folga foi o anim_idle (banco 1,
	; 	' mesmo padrao do mb_frame/boss_frame). stars_fill FICA aqui: ele
	; 	' cai na metade FIXA ($C000+) do banco 0, que e' alcancavel de
	; 	' qualquer janela SEM wrapper (banco 0 estourou 97B com as 5 fases).
	; stars_fill:	PROCEDURE	' desenha o layout do boot nas TRES nametables
cvb_STARS_FILL:
	; 	' ($2000, $2400, $2800). Por que 3? A vizinha de scroll vertical da
	; 	' $2000 depende do espelhamento que o emulador aplica p/ o byte6=0:
	; 	' no fceumm/medido aqui e a $2800 (a $2400 e espelho da $2000!); no
	; 	' hardware/emuladores "de manual" seria a $2400. Escrevendo nas duas
	; 	' (uma das escritas sempre e no-op por ser a mesma RAM) o loop de 240px
	; 	' fica perfeito em QUALQUER caso. Layout: malha de 48 setores 4x5
	; 	' (1 estrela/setor: nunca aglomera, nunca deixa buraco).
	; 	' Lacos separados por WAIT: o buffer de escrita da PPU drena ~21 VPOKEs
	; 	' pendentes por NMI; escrever demais de uma vez PERDE escritas.
	; 	FOR sk = 0 TO 47
	LDA #0
	STA cvb_SK
cv260:
	; 		VPOKE $2000 + #stw(sk), stt(sk)
	LDA #array_STT
	CLC
	ADC cvb_SK
	TAX
	LDA #array_STT>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	PHA
	LDA cvb_SK
	ASL A
	LDY #0
	BCC $+3
	INY
	CLC
	ADC #array_#STW
	TAX
	TYA
	ADC #array_#STW>>8
	TAY
	TXA
	JSR _peek16
	CLC
	TAX
	TYA
	ADC #32
	TAY
	TXA
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 		IF sk = 31 THEN WAIT
	LDA cvb_SK
	CMP #31
	BNE.L cv261
	JSR wait
cv261:
	; 	NEXT sk
	INC cvb_SK
	LDA cvb_SK
	CMP #48
	BCC.L cv260
	; 	WAIT
	JSR wait
	; 	FOR sk = 0 TO 47
	LDA #0
	STA cvb_SK
cv262:
	; 		VPOKE $2400 + #stw(sk), stt(sk)
	LDA #array_STT
	CLC
	ADC cvb_SK
	TAX
	LDA #array_STT>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	PHA
	LDA cvb_SK
	ASL A
	LDY #0
	BCC $+3
	INY
	CLC
	ADC #array_#STW
	TAX
	TYA
	ADC #array_#STW>>8
	TAY
	TXA
	JSR _peek16
	CLC
	TAX
	TYA
	ADC #36
	TAY
	TXA
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 		IF sk = 31 THEN WAIT
	LDA cvb_SK
	CMP #31
	BNE.L cv263
	JSR wait
cv263:
	; 	NEXT sk
	INC cvb_SK
	LDA cvb_SK
	CMP #48
	BCC.L cv262
	; 	WAIT
	JSR wait
	; 	FOR sk = 0 TO 47
	LDA #0
	STA cvb_SK
cv264:
	; 		VPOKE $2800 + #stw(sk), stt(sk)
	LDA #array_STT
	CLC
	ADC cvb_SK
	TAX
	LDA #array_STT>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	PHA
	LDA cvb_SK
	ASL A
	LDY #0
	BCC $+3
	INY
	CLC
	ADC #array_#STW
	TAX
	TYA
	ADC #array_#STW>>8
	TAY
	TXA
	JSR _peek16
	CLC
	TAX
	TYA
	ADC #40
	TAY
	TXA
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 		IF sk = 31 THEN WAIT
	LDA cvb_SK
	CMP #31
	BNE.L cv265
	JSR wait
cv265:
	; 	NEXT sk
	INC cvb_SK
	LDA cvb_SK
	CMP #48
	BCC.L cv264
	; 	WAIT
	JSR wait
	; END
	RTS
	; 
	; update_score:	PROCEDURE	' placar em sprites (o fundo esta rolando!)
cvb_UPDATE_SCORE:
	; 	SPRITE 35,16,$c0,s0 * 2 + 192,0
	LDA #35
	PHA
	LDA #16
	STA sprite_data
	LDA #192
	STA sprite_data+3
	LDA cvb_S0
	ASL A
	CLC
	ADC #192
	STA sprite_data+1
	LDA #0
	STA sprite_data+2
	PLA
	JSR update_sprite
	; 	SPRITE 36,16,$c8,s1 * 2 + 192,0
	LDA #36
	PHA
	LDA #16
	STA sprite_data
	LDA #200
	STA sprite_data+3
	LDA cvb_S1
	ASL A
	CLC
	ADC #192
	STA sprite_data+1
	LDA #0
	STA sprite_data+2
	PLA
	JSR update_sprite
	; 	SPRITE 37,16,$d0,s2 * 2 + 192,0
	LDA #37
	PHA
	LDA #16
	STA sprite_data
	LDA #208
	STA sprite_data+3
	LDA cvb_S2
	ASL A
	CLC
	ADC #192
	STA sprite_data+1
	LDA #0
	STA sprite_data+2
	PLA
	JSR update_sprite
	; 	SPRITE 38,16,$d8,s3 * 2 + 192,0
	LDA #38
	PHA
	LDA #16
	STA sprite_data
	LDA #216
	STA sprite_data+3
	LDA cvb_S3
	ASL A
	CLC
	ADC #192
	STA sprite_data+1
	LDA #0
	STA sprite_data+2
	PLA
	JSR update_sprite
	; 	SPRITE 39,16,$e0,s4 * 2 + 192,0
	LDA #39
	PHA
	LDA #16
	STA sprite_data
	LDA #224
	STA sprite_data+3
	LDA cvb_S4
	ASL A
	CLC
	ADC #192
	STA sprite_data+1
	LDA #0
	STA sprite_data+2
	PLA
	JSR update_sprite
	; 	END
	RTS
	; 
	; score_add:	PROCEDURE	' e = centenas, d = dezenas a somar (chama update_score)
cvb_SCORE_ADD:
	; 	s2 = s2 + e
	LDA cvb_S2
	CLC
	ADC cvb_E
	STA cvb_S2
	; 	s3 = s3 + d
	LDA cvb_S3
	CLC
	ADC cvb_D
	STA cvb_S3
	; 	WHILE s3 > 9
cv266:
	LDA cvb_S3
	CMP #10
	BCC.L cv267
	; 		s3 = s3 - 10
	SEC
	SBC #10
	STA cvb_S3
	; 		s2 = s2 + 1
	INC cvb_S2
	; 	WEND
	JMP cv266
cv267:
	; 	WHILE s2 > 9
cv268:
	LDA cvb_S2
	CMP #10
	BCC.L cv269
	; 		s2 = s2 - 10
	SEC
	SBC #10
	STA cvb_S2
	; 		s1 = s1 + 1
	INC cvb_S1
	; 	WEND
	JMP cv268
cv269:
	; 	WHILE s1 > 9
cv270:
	LDA cvb_S1
	CMP #10
	BCC.L cv271
	; 		s1 = s1 - 10
	SEC
	SBC #10
	STA cvb_S1
	; 		s0 = s0 + 1
	INC cvb_S0
	; 	WEND
	JMP cv270
cv271:
	; 	IF s0 > 9 THEN s0 = 9
	LDA cvb_S0
	CMP #10
	BCC.L cv272
	LDA #9
	STA cvb_S0
cv272:
	; 	GOSUB update_score
	JSR cvb_UPDATE_SCORE
	; 	END
	RTS
	; 
	; update_lives:	PROCEDURE	' vidas como digito em sprite (canto sup. esquerdo)
cvb_UPDATE_LIVES:
	; 	IF li > 9 THEN li = 9
	LDA cvb_LI
	CMP #10
	BCC.L cv273
	LDA #9
	STA cvb_LI
cv273:
	; 	SPRITE 40,16,$30,li * 2 + 192,0
	LDA #40
	PHA
	LDA #16
	STA sprite_data
	LDA #48
	STA sprite_data+3
	LDA cvb_LI
	ASL A
	CLC
	ADC #192
	STA sprite_data+1
	LDA #0
	STA sprite_data+2
	PLA
	JSR update_sprite
	; 	END
	RTS
	; 
	; aim_8dir:	PROCEDURE	' mira do ponto (#tbx,#tby) na nave: 8 direcoes
cvb_AIM_8DIR:
	; 	' entrada: #adx,#ady (assinados) | saida: tbvx,tbvy
	; 	#t1 = ABS(#adx)
	LDA cvb_#ADX
	LDY cvb_#ADX+1
	JSR _abs16
	STA cvb_#T1
	STY cvb_#T1+1
	; 	#t2 = ABS(#ady)
	LDA cvb_#ADY
	LDY cvb_#ADY+1
	JSR _abs16
	STA cvb_#T2
	STY cvb_#T2+1
	; 	ebspd = 19 + wdif * 2
	LDA cvb_WDIF
	ASL A
	CLC
	ADC #19
	STA cvb_EBSPD
	; 	IF #t2 + #t2 < #t1 THEN		' horizontal dominante
	LDA cvb_#T2
	CLC
	ADC cvb_#T2
	TAX
	TYA
	ADC cvb_#T2+1
	TAY
	TXA
	TAX
	TYA
	EOR #128
	TAY
	TXA
	PHA
	TYA
	PHA
	LDA cvb_#T1
	LDY cvb_#T1+1
	TAX
	TYA
	EOR #128
	TAY
	TXA
	STA temp
	STY temp+1
	PLA
	TAY
	PLA
	SEC
	SBC temp
	TYA
	SBC temp+1
	BCS.L cv274
	; 		tbvy = 0
	LDA #0
	STA cvb_TBVY
	; 		IF #adx < 0 THEN
	LDA cvb_#ADX
	LDY cvb_#ADX+1
	TAX
	TYA
	EOR #128
	TAY
	TXA
	SEC
	SBC #0
	TYA
	SBC #128
	BCS.L cv275
	; 			tbvx = 0 - ebspd
	LDA #0
	TAY
	SEC
	SBC cvb_EBSPD
	TAX
	TYA
	SBC #0
	TAY
	TXA
	STA cvb_TBVX
	; 		ELSE
	JMP cv276
cv275:
	; 			tbvx = ebspd
	LDA cvb_EBSPD
	STA cvb_TBVX
	; 		END IF
cv276:
	; 	ELSEIF #t1 + #t1 < #t2 THEN	' vertical dominante
	JMP cv277
cv274:
	LDA cvb_#T1
	LDY cvb_#T1+1
	CLC
	ADC cvb_#T1
	TAX
	TYA
	ADC cvb_#T1+1
	TAY
	TXA
	TAX
	TYA
	EOR #128
	TAY
	TXA
	PHA
	TYA
	PHA
	LDA cvb_#T2
	LDY cvb_#T2+1
	TAX
	TYA
	EOR #128
	TAY
	TXA
	STA temp
	STY temp+1
	PLA
	TAY
	PLA
	SEC
	SBC temp
	TYA
	SBC temp+1
	BCS.L cv278
	; 		tbvx = 0
	LDA #0
	STA cvb_TBVX
	; 		IF #ady < 0 THEN
	LDA cvb_#ADY
	LDY cvb_#ADY+1
	TAX
	TYA
	EOR #128
	TAY
	TXA
	SEC
	SBC #0
	TYA
	SBC #128
	BCS.L cv279
	; 			tbvy = 0 - ebspd
	LDA #0
	TAY
	SEC
	SBC cvb_EBSPD
	TAX
	TYA
	SBC #0
	TAY
	TXA
	STA cvb_TBVY
	; 		ELSE
	JMP cv280
cv279:
	; 			tbvy = ebspd
	LDA cvb_EBSPD
	STA cvb_TBVY
	; 		END IF
cv280:
	; 	ELSE					' diagonal
	JMP cv277
cv278:
	; 		#tw = ebspd * 11 / 16
	LDA cvb_EBSPD
	LDY #0
	LDX #11
	STX temp
	LDX #0
	STX temp+1
	JSR _mul16
	LDX #16
	STX temp
	LDX #0
	STX temp+1
	JSR _div16
	STA cvb_#TW
	STY cvb_#TW+1
	; 		IF #adx < 0 THEN
	LDA cvb_#ADX
	LDY cvb_#ADX+1
	TAX
	TYA
	EOR #128
	TAY
	TXA
	SEC
	SBC #0
	TYA
	SBC #128
	BCS.L cv281
	; 			tbvx = 0 - #tw
	LDA #0
	TAY
	SEC
	SBC cvb_#TW
	TAX
	TYA
	SBC cvb_#TW+1
	TAY
	TXA
	STA cvb_TBVX
	; 		ELSE
	JMP cv282
cv281:
	; 			tbvx = #tw
	LDA cvb_#TW
	STA cvb_TBVX
	; 		END IF
cv282:
	; 		IF #ady < 0 THEN
	LDA cvb_#ADY
	LDY cvb_#ADY+1
	TAX
	TYA
	EOR #128
	TAY
	TXA
	SEC
	SBC #0
	TYA
	SBC #128
	BCS.L cv283
	; 			tbvy = 0 - #tw
	LDA #0
	TAY
	SEC
	SBC cvb_#TW
	TAX
	TYA
	SBC cvb_#TW+1
	TAY
	TXA
	STA cvb_TBVY
	; 		ELSE
	JMP cv284
cv283:
	; 			tbvy = #tw
	LDA cvb_#TW
	STA cvb_TBVY
	; 		END IF
cv284:
	; 	END IF
cv277:
	; 	END
	RTS
	; 
	; 	' === gerado por gera_boss.py (v0.13): ceu preto + boss BG $1000 ===
	; eb_spawn:	PROCEDURE	' nasce tiro inimigo em (#tbx,#tby) com vel (tbvx,tbvy)
cvb_EB_SPAWN:
	; 	' NOTA: nao usar "#arr(i) = #var * 16"! O shift do *16 reutiliza o temp
	; 	' que guarda o endereco do elemento e a escrita vai parar em $0000.
	; 	' Por isso o *16 vai antes para o global #tw e so depois p/ o array.
	; 	' (eb_spawn tambem nao pode usar c: destruiria o FOR das waves!)
	; 	' ebs = dono do tiro (1 = small; 0 = outros) p/ a cota de 3 do v0.12
	; 	k = 0
	LDA #0
	STA cvb_K
	; 	WHILE k < 8
cv285:
	LDA cvb_K
	CMP #8
	BCS.L cv286
	; 		IF eba(k) = 0 THEN
	LDA #array_EBA
	CLC
	ADC cvb_K
	TAX
	LDA #array_EBA>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	CMP #0
	BNE.L cv287
	; 			eba(k) = 1
	LDA pointer
	LDY pointer+1
	STA temp
	STY temp+1
	LDA #1
	LDY #0
	STA (temp),Y
	; 			ebt(k) = ebs
	LDA #array_EBT
	CLC
	ADC cvb_K
	TAX
	LDA #array_EBT>>8
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	LDA cvb_EBS
	LDY #0
	STA (temp),Y
	; 			IF ebs = 1 THEN nsm = nsm + 1
	LDA cvb_EBS
	CMP #1
	BNE.L cv288
	INC cvb_NSM
cv288:
	; 			#tw = (#tbx + 256) * 16
	LDA cvb_#TBX
	LDY cvb_#TBX+1
	INY
	STY temp
	ASL A
	ROL temp
	ASL A
	ROL temp
	ASL A
	ROL temp
	ASL A
	ROL temp
	LDY temp
	STA cvb_#TW
	STY cvb_#TW+1
	; 			#ebx(k) = #tw
	LDA cvb_K
	ASL A
	LDY #0
	BCC $+3
	INY
	CLC
	ADC #array_#EBX
	TAX
	TYA
	ADC #array_#EBX>>8
	TAY
	TXA
	STA temp
	STY temp+1
	LDA cvb_#TW
	LDY cvb_#TW+1
	TAX
	TYA
	LDY #1
	STA (temp),Y
	TXA
	DEY
	STA (temp),Y
	; 			#tw = (#tby + 256) * 16
	LDA cvb_#TBY
	LDY cvb_#TBY+1
	INY
	STY temp
	ASL A
	ROL temp
	ASL A
	ROL temp
	ASL A
	ROL temp
	ASL A
	ROL temp
	LDY temp
	STA cvb_#TW
	STY cvb_#TW+1
	; 			#eby(k) = #tw
	LDA cvb_K
	ASL A
	LDY #0
	BCC $+3
	INY
	CLC
	ADC #array_#EBY
	TAX
	TYA
	ADC #array_#EBY>>8
	TAY
	TXA
	STA temp
	STY temp+1
	LDA cvb_#TW
	LDY cvb_#TW+1
	TAX
	TYA
	LDY #1
	STA (temp),Y
	TXA
	DEY
	STA (temp),Y
	; 			ebxv(k) = tbvx
	LDA #array_EBXV
	CLC
	ADC cvb_K
	TAX
	LDA #array_EBXV>>8
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	LDA cvb_TBVX
	LDY #0
	STA (temp),Y
	; 			ebyv(k) = tbvy
	LDA #array_EBYV
	CLC
	ADC cvb_K
	TAX
	LDA #array_EBYV>>8
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	LDA cvb_TBVY
	LDY #0
	STA (temp),Y
	; 			k = 8
	LDA #8
	STA cvb_K
	; 		ELSE
	JMP cv289
cv287:
	; 			k = k + 1
	INC cvb_K
	; 		END IF
cv289:
	; 	WEND
	JMP cv285
cv286:
	; 	END
	RTS
	; 
	; spawn_ring:	PROCEDURE	' anel de 8 tiros do shard morto (145px/s ~ 24/16)
cvb_SPAWN_RING:
	; 	FOR i = 0 TO 7
	LDA #0
	STA cvb_I
cv290:
	; 		IF i = 0 THEN
	LDA cvb_I
	BNE.L cv291
	; 			tbvx = 24
	LDA #24
	STA cvb_TBVX
	; 			tbvy = 0
	LDA #0
	STA cvb_TBVY
	; 		ELSEIF i = 1 THEN
	JMP cv292
cv291:
	LDA cvb_I
	CMP #1
	BNE.L cv293
	; 			tbvx = 17
	LDA #17
	STA cvb_TBVX
	; 			tbvy = 17
	STA cvb_TBVY
	; 		ELSEIF i = 2 THEN
	JMP cv292
cv293:
	LDA cvb_I
	CMP #2
	BNE.L cv294
	; 			tbvx = 0
	LDA #0
	STA cvb_TBVX
	; 			tbvy = 24
	LDA #24
	STA cvb_TBVY
	; 		ELSEIF i = 3 THEN
	JMP cv292
cv294:
	LDA cvb_I
	CMP #3
	BNE.L cv295
	; 			tbvx = -17
	LDA #239
	STA cvb_TBVX
	; 			tbvy = 17
	LDA #17
	STA cvb_TBVY
	; 		ELSEIF i = 4 THEN
	JMP cv292
cv295:
	LDA cvb_I
	CMP #4
	BNE.L cv296
	; 			tbvx = -24
	LDA #232
	STA cvb_TBVX
	; 			tbvy = 0
	LDA #0
	STA cvb_TBVY
	; 		ELSEIF i = 5 THEN
	JMP cv292
cv296:
	LDA cvb_I
	CMP #5
	BNE.L cv297
	; 			tbvx = -17
	LDA #239
	STA cvb_TBVX
	; 			tbvy = -17
	STA cvb_TBVY
	; 		ELSEIF i = 6 THEN
	JMP cv292
cv297:
	LDA cvb_I
	CMP #6
	BNE.L cv298
	; 			tbvx = 0
	LDA #0
	STA cvb_TBVX
	; 			tbvy = -24
	LDA #232
	STA cvb_TBVY
	; 		ELSE
	JMP cv292
cv298:
	; 			tbvx = 17
	LDA #17
	STA cvb_TBVX
	; 			tbvy = -17
	LDA #239
	STA cvb_TBVY
	; 		END IF
cv292:
	; 		ebs = 0
	LDA #0
	STA cvb_EBS
	; 		GOSUB eb_spawn
	JSR cvb_EB_SPAWN
	; 	NEXT i
	INC cvb_I
	LDA cvb_I
	CMP #8
	BCC.L cv290
	; 	END
	RTS
	; 
	; 
	; 	'
	; 	' Paletas do Space Blast NES
	; 	'
	; ' Paleta do titulo/game over: pal0 = estrelas (cinza escuro, nao confunde
	; ' com tiros); pal1 = logo azul/ciano/branco + textos brancos;
	; ' pal2 = faixa vermelha da logo.
	; oam_ring:	' slots fisicos p/ o rodizio (v0.14, 16 slots)
cvb_OAM_RING:
	; 	DATA BYTE 4,5,6,7,8,9,10,11,12,13,14,15
	DB $04,$05,$06,$07,$08,$09,$0a,$0b
	DB $0c,$0d,$0e,$0f
	; 	DATA BYTE 21,22,23,24
	DB $15,$16,$17,$18
	; 
	; game_palette_title:
cvb_GAME_PALETTE_TITLE:
	; 	DATA BYTE $0F,$11,$21,$00	' fundo 0: preto, azuis + cinza escuro (estrelas)
	DB $0f,$11,$21,$00
	; 	DATA BYTE $0F,$00,$10,$30	' fundo 1: cinza/branco (SPACE)
	DB $0f,$00,$10,$30
	; 	DATA BYTE $0F,$06,$16,$30	' fundo 2: vermelhos (BLAST)
	DB $0f,$06,$16,$30
	; 	DATA BYTE $0F,$1C,$10,$30	' fundo 3: teal/cinza/branco (cometa)
	DB $0f,$1c,$10,$30
	; 	DATA BYTE $0F,$00,$10,$30	' sprites 0: cinzas (corpo da nave, placar)
	DB $0f,$00,$10,$30
	; 	DATA BYTE $0F,$16,$21,$12	' sprites 1: vermelho/azul/azul esc (canopy + small)
	DB $0f,$16,$21,$12
	; 	DATA BYTE $0F,$19,$2A,$30	' sprites 2: verdes (chama da nave + shard)
	DB $0f,$19,$2a,$30
	; 	DATA BYTE $0F,$1C,$3C,$30	' sprites 3: quentes (explosao, tiro, ebullet)
	DB $0f,$1c,$3c,$30
	; 
	; ' Paleta do gameplay: atributos todos 0 -> so o fundo 0 e usado.
	; game_palette_play:
cvb_GAME_PALETTE_PLAY:
	; 	DATA BYTE $0F,$11,$21,$00	' fundo 0: preto, azuis + cinza escuro
	DB $0f,$11,$21,$00
	; 	DATA BYTE $0F,$11,$21,$00	' fundo 1
	DB $0f,$11,$21,$00
	; 	DATA BYTE $0F,$11,$21,$00	' fundo 2
	DB $0f,$11,$21,$00
	; 	DATA BYTE $0F,$11,$21,$00	' fundo 3
	DB $0f,$11,$21,$00
	; 	DATA BYTE $0F,$00,$10,$30	' sprites 0: cinzas (corpo da nave, placar)
	DB $0f,$00,$10,$30
	; 	DATA BYTE $0F,$16,$21,$12	' sprites 1: vermelho/azul/azul esc (canopy + small)
	DB $0f,$16,$21,$12
	; 	DATA BYTE $0F,$19,$2A,$30	' sprites 2: verdes (chama da nave + shard)
	DB $0f,$19,$2a,$30
	; 	DATA BYTE $0F,$1C,$3C,$30	' sprites 3: quentes (explosao, tiro, ebullet)
	DB $0f,$1c,$3c,$30
	; 
	; 	' Tiles de estrela nao-vazios (p/ sorteio harmonico)
	; nep_tab:
cvb_NEP_TAB:
	; 	DATA BYTE 1,2,3,4,5,6,7,8
	DB $01,$02,$03,$04,$05,$06,$07,$08
	; 	DATA BYTE 9,10,11,12,13,14,15,16
	DB $09,$0a,$0b,$0c,$0d,$0e,$0f,$10
	; 	DATA BYTE 17,18,19,20,21,22,23
	DB $11,$12,$13,$14,$15,$16,$17
	; 
	; 	' Mapa de tiles da logo (255 = transparente, nao plota)
	; logo_map:
cvb_LOGO_MAP:
	; 	DATA BYTE 255,255,96,97,98,99,100,98
	DB $ff,$ff,$60,$61,$62,$63,$64,$62
	; 	DATA BYTE 101,102,103,104,105,106,107,108
	DB $65,$66,$67,$68,$69,$6a,$6b,$6c
	; 	DATA BYTE 255,255,109,110,111,112,113,114
	DB $ff,$ff,$6d,$6e,$6f,$70,$71,$72
	; 	DATA BYTE 115,116,117,118,119,120,121,122
	DB $73,$74,$75,$76,$77,$78,$79,$7a
	; 	DATA BYTE 255,255,255,123,124,125,126,127
	DB $ff,$ff,$ff,$7b,$7c,$7d,$7e,$7f
	; 	DATA BYTE 128,127,129,124,130,131,255,255
	DB $80,$7f,$81,$7c,$82,$83,$ff,$ff
	; 	DATA BYTE 255,255,255,132,133,134,135,136
	DB $ff,$ff,$ff,$84,$85,$86,$87,$88
	; 	DATA BYTE 137,138,139,140,141,142,255,255
	DB $89,$8a,$8b,$8c,$8d,$8e,$ff,$ff
	; 	DATA BYTE 255,255,255,143,144,145,146,147
	DB $ff,$ff,$ff,$8f,$90,$91,$92,$93
	; 	DATA BYTE 148,149,150,151,152,153,255,255
	DB $94,$95,$96,$97,$98,$99,$ff,$ff
	; 	DATA BYTE 255,255,255,154,155,156,157,158
	DB $ff,$ff,$ff,$9a,$9b,$9c,$9d,$9e
	; 	DATA BYTE 159,160,161,162,163,164,255,255
	DB $9f,$a0,$a1,$a2,$a3,$a4,$ff,$ff
	; 
	; falcon_map:
cvb_FALCON_MAP:
	; 	DATA BYTE 96,96,96,96,96,96,97,98,99,96,96,96,96,96,96,96
	DB $60,$60,$60,$60,$60,$60,$61,$62
	DB $63,$60,$60,$60,$60,$60,$60,$60
	; 	DATA BYTE 96,96,96,96,96,96,100,96,101,102,96,96,96,96,96,96
	DB $60,$60,$60,$60,$60,$60,$64,$60
	DB $65,$66,$60,$60,$60,$60,$60,$60
	; 	DATA BYTE 96,96,96,103,104,105,106,107,108,109,110,111,112,96,96,96
	DB $60,$60,$60,$67,$68,$69,$6a,$6b
	DB $6c,$6d,$6e,$6f,$70,$60,$60,$60
	; 	DATA BYTE 96,96,96,113,114,115,116,117,118,119,120,121,122,96,96,96
	DB $60,$60,$60,$71,$72,$73,$74,$75
	DB $76,$77,$78,$79,$7a,$60,$60,$60
	; 	DATA BYTE 96,96,123,124,125,126,127,128,129,130,131,132,133,134,96,96
	DB $60,$60,$7b,$7c,$7d,$7e,$7f,$80
	DB $81,$82,$83,$84,$85,$86,$60,$60
	; 	DATA BYTE 96,96,135,136,137,138,139,140,141,142,143,144,145,146,96,96
	DB $60,$60,$87,$88,$89,$8a,$8b,$8c
	DB $8d,$8e,$8f,$90,$91,$92,$60,$60
	; 	DATA BYTE 96,147,148,149,150,151,152,153,154,155,156,157,158,159,160,96
	DB $60,$93,$94,$95,$96,$97,$98,$99
	DB $9a,$9b,$9c,$9d,$9e,$9f,$a0,$60
	; 	DATA BYTE 96,161,162,163,164,165,166,167,168,169,170,171,172,173,174,96
	DB $60,$a1,$a2,$a3,$a4,$a5,$a6,$a7
	DB $a8,$a9,$aa,$ab,$ac,$ad,$ae,$60
	; 	DATA BYTE 96,96,96,96,96,96,175,176,177,178,96,96,96,96,96,96
	DB $60,$60,$60,$60,$60,$60,$af,$b0
	DB $b1,$b2,$60,$60,$60,$60,$60,$60
	; 	DATA BYTE 96,96,96,96,96,96,179,180,181,96,96,96,96,96,96,96
	DB $60,$60,$60,$60,$60,$60,$b3,$b4
	DB $b5,$60,$60,$60,$60,$60,$60,$60
	; 
	; falcon_txt:
cvb_FALCON_TXT:
	; 	DATA BYTE 182,185,186,183,187,183,184,188,182
	DB $b6,$b9,$ba,$b7,$bb,$b7,$b8,$bc
	DB $b6
	; 
	; ' Fade da splash por palette cycling (idx2=cinza, idx3=branco).
	; ' 7 passos x 4 frames ~0.47s por direcao.
	; fade_tbl:
cvb_FADE_TBL:
	; 	DATA BYTE $0F,$0F
	DB $0f,$0f
	; 	DATA BYTE $0F,$00
	DB $0f,$00
	; 	DATA BYTE $00,$00
	DB $00,$00
	; 	DATA BYTE $00,$10
	DB $00,$10
	; 	DATA BYTE $10,$10
	DB $10,$10
	; 	DATA BYTE $10,$20
	DB $10,$20
	; 	DATA BYTE $10,$30
	DB $10,$30
	; fade_tbl_out:
cvb_FADE_TBL_OUT:
	; 	DATA BYTE $10,$30
	DB $10,$30
	; 	DATA BYTE $10,$20
	DB $10,$20
	; 	DATA BYTE $10,$10
	DB $10,$10
	; 	DATA BYTE $00,$10
	DB $00,$10
	; 	DATA BYTE $00,$00
	DB $00,$00
	; 	DATA BYTE $0F,$00
	DB $0f,$00
	; 	DATA BYTE $0F,$0F
	DB $0f,$0f
	; 
	; 	'
	; 	' Tabela seno do zigzag: sin(i * 2pi / 64) * 127 + 128
	; 	'
	; sintab:
cvb_SINTAB:
	; 	DATA BYTE 128,140,153,165,177,189,200,211
	DB $80,$8c,$99,$a5,$b1,$bd,$c8,$d3
	; 	DATA BYTE 221,229,236,242,247,251,253,255
	DB $dd,$e5,$ec,$f2,$f7,$fb,$fd,$ff
	; 	DATA BYTE 255,253,251,247,242,236,229,221
	DB $ff,$fd,$fb,$f7,$f2,$ec,$e5,$dd
	; 	DATA BYTE 211,200,189,177,165,153,140,128
	DB $d3,$c8,$bd,$b1,$a5,$99,$8c,$80
	; 	DATA BYTE 128,116,103,91,79,67,56,45
	DB $80,$74,$67,$5b,$4f,$43,$38,$2d
	; 	DATA BYTE 35,27,20,14,9,5,3,1
	DB $23,$1b,$14,$0e,$09,$05,$03,$01
	; 	DATA BYTE 1,3,5,9,14,20,27,35
	DB $01,$03,$05,$09,$0e,$14,$1b,$23
	; 	DATA BYTE 45,56,67,79,91,103,116,128
	DB $2d,$38,$43,$4f,$5b,$67,$74,$80
	; 
	; 	'
	; 	' Blocos de video (CHR)
	; 	'
	; 
	; BANK 1	' v0.15: procs frios grandes (miniboss + boss) saem do banco 0
; Intruder Alert v0.36: fixed-bank continuation after music init/update.
cvb_FAMISTUDIO_RESTORE:
	LDA FAMISTUDIO_SAVED_BANK
	ORA CHRRAM_BANK
	STA BANKSEL
	CLI
	RTS

BANK_0_FREE:	EQU $fffa-$
	TIMES $fffa-$ DB $ff
	DB $1f
	FORG $00010
	ORG $8000
	; sky_clear:	PROCEDURE	' ceu 100% preto p/ luta (Saulo autorizou)
cvb_SKY_CLEAR:
	; 	' apaga as 960 celulas visiveis, 16 por frame (dreno do buffer)
	; 	#bk = $2000
	LDA #0
	LDY #32
	STA cvb_#BK
	STY cvb_#BK+1
	; 	gbc = 0
	STA cvb_GBC
	; sky_clear_loop:
cvb_SKY_CLEAR_LOOP:
	; 	FOR i = 0 TO 15
	LDA #0
	STA cvb_I
cv299:
	; 		VPOKE #bk, 0
	LDA #0
	PHA
	LDA cvb_#BK
	LDY cvb_#BK+1
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 		#bk = #bk + 1
	INC cvb_#BK
	BNE cv300
	INC cvb_#BK+1
cv300:
	; 	NEXT i
	INC cvb_I
	LDA cvb_I
	CMP #16
	BCC.L cv299
	; 	WAIT
	JSR wait
	; 	gbc = gbc + 1
	INC cvb_GBC
	; 	IF gbc < 60 THEN GOTO sky_clear_loop
	LDA cvb_GBC
	CMP #60
	BCS.L cv301
	JMP cvb_SKY_CLEAR_LOOP
cv301:
	; 	END
	RTS
	; 
	; boss_write:	PROCEDURE	' desenha o corpo 96x64 (linhas 3-10)
cvb_BOSS_WRITE:
	; 	VPOKE $2069,0
	LDA #0
	PHA
	LDA #105
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $206A,0
	LDA #0
	PHA
	LDA #106
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $206B,0
	LDA #0
	PHA
	LDA #107
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $206C,0
	LDA #0
	PHA
	LDA #108
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $206D,0
	LDA #0
	PHA
	LDA #109
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $206E,0
	LDA #0
	PHA
	LDA #110
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $206F,0
	LDA #0
	PHA
	LDA #111
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $2070,0
	LDA #0
	PHA
	LDA #112
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $2071,0
	LDA #0
	PHA
	LDA #113
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $2072,0
	LDA #0
	PHA
	LDA #114
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $2073,0
	LDA #0
	PHA
	LDA #115
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $2074,0
	LDA #0
	PHA
	LDA #116
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $2089,0
	LDA #0
	PHA
	LDA #137
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $208A,0
	LDA #0
	PHA
	LDA #138
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $208B,0
	LDA #0
	PHA
	LDA #139
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $208C,0
	LDA #0
	PHA
	LDA #140
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $208D,0
	LDA #0
	PHA
	LDA #141
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $208E,0
	LDA #0
	PHA
	LDA #142
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $208F,0
	LDA #0
	PHA
	LDA #143
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	WAIT	' (gera_boss: drena buffer da PPU)
	JSR wait
	; 	VPOKE $2090,0
	LDA #0
	PHA
	LDA #144
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $2091,0
	LDA #0
	PHA
	LDA #145
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $2092,0
	LDA #0
	PHA
	LDA #146
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $2093,0
	LDA #0
	PHA
	LDA #147
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $2094,0
	LDA #0
	PHA
	LDA #148
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $20A9,0
	LDA #0
	PHA
	LDA #169
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $20AA,0
	LDA #0
	PHA
	LDA #170
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $20AB,0
	LDA #0
	PHA
	LDA #171
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $20AC,0
	LDA #0
	PHA
	LDA #172
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $20AD,0
	LDA #0
	PHA
	LDA #173
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $20AE,0
	LDA #0
	PHA
	LDA #174
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $20AF,0
	LDA #0
	PHA
	LDA #175
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $20B0,0
	LDA #0
	PHA
	LDA #176
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $20B1,0
	LDA #0
	PHA
	LDA #177
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $20B2,0
	LDA #0
	PHA
	LDA #178
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $20B3,0
	LDA #0
	PHA
	LDA #179
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $20B4,0
	LDA #0
	PHA
	LDA #180
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $20C9,0
	LDA #0
	PHA
	LDA #201
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $20CA,0
	LDA #0
	PHA
	LDA #202
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	WAIT	' (gera_boss: drena buffer da PPU)
	JSR wait
	; 	VPOKE $20CB,0
	LDA #0
	PHA
	LDA #203
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $20CC,0
	LDA #0
	PHA
	LDA #204
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $20CD,0
	LDA #0
	PHA
	LDA #205
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $20CE,0
	LDA #0
	PHA
	LDA #206
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $20CF,0
	LDA #0
	PHA
	LDA #207
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $20D0,0
	LDA #0
	PHA
	LDA #208
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $20D1,0
	LDA #0
	PHA
	LDA #209
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $20D2,0
	LDA #0
	PHA
	LDA #210
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $20D3,0
	LDA #0
	PHA
	LDA #211
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $20D4,0
	LDA #0
	PHA
	LDA #212
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $20E9,0
	LDA #0
	PHA
	LDA #233
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $20EA,0
	LDA #0
	PHA
	LDA #234
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $20EB,0
	LDA #0
	PHA
	LDA #235
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $20EC,0
	LDA #0
	PHA
	LDA #236
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $20ED,0
	LDA #0
	PHA
	LDA #237
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $20EE,0
	LDA #0
	PHA
	LDA #238
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $20EF,0
	LDA #0
	PHA
	LDA #239
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $20F0,0
	LDA #0
	PHA
	LDA #240
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $20F1,0
	LDA #0
	PHA
	LDA #241
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	WAIT	' (gera_boss: drena buffer da PPU)
	JSR wait
	; 	VPOKE $20F2,0
	LDA #0
	PHA
	LDA #242
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $20F3,0
	LDA #0
	PHA
	LDA #243
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $20F4,0
	LDA #0
	PHA
	LDA #244
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $2109,0
	LDA #0
	PHA
	LDA #9
	LDY #33
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $210A,0
	LDA #0
	PHA
	LDA #10
	LDY #33
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $210B,0
	LDA #0
	PHA
	LDA #11
	LDY #33
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $210C,0
	LDA #0
	PHA
	LDA #12
	LDY #33
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $210D,0
	LDA #0
	PHA
	LDA #13
	LDY #33
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $210E,0
	LDA #0
	PHA
	LDA #14
	LDY #33
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $210F,0
	LDA #0
	PHA
	LDA #15
	LDY #33
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $2110,0
	LDA #0
	PHA
	LDA #16
	LDY #33
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $2111,0
	LDA #0
	PHA
	LDA #17
	LDY #33
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $2112,0
	LDA #0
	PHA
	LDA #18
	LDY #33
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $2113,0
	LDA #0
	PHA
	LDA #19
	LDY #33
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $2114,0
	LDA #0
	PHA
	LDA #20
	LDY #33
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $2129,0
	LDA #0
	PHA
	LDA #41
	LDY #33
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $212A,0
	LDA #0
	PHA
	LDA #42
	LDY #33
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $212B,0
	LDA #0
	PHA
	LDA #43
	LDY #33
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $212C,0
	LDA #0
	PHA
	LDA #44
	LDY #33
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	WAIT	' (gera_boss: drena buffer da PPU)
	JSR wait
	; 	VPOKE $212D,0
	LDA #0
	PHA
	LDA #45
	LDY #33
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $212E,0
	LDA #0
	PHA
	LDA #46
	LDY #33
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $212F,0
	LDA #0
	PHA
	LDA #47
	LDY #33
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $2130,0
	LDA #0
	PHA
	LDA #48
	LDY #33
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $2131,0
	LDA #0
	PHA
	LDA #49
	LDY #33
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $2132,0
	LDA #0
	PHA
	LDA #50
	LDY #33
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $2133,0
	LDA #0
	PHA
	LDA #51
	LDY #33
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $2134,0
	LDA #0
	PHA
	LDA #52
	LDY #33
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $2149,0
	LDA #0
	PHA
	LDA #73
	LDY #33
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $214A,0
	LDA #0
	PHA
	LDA #74
	LDY #33
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $214B,0
	LDA #0
	PHA
	LDA #75
	LDY #33
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $214C,0
	LDA #0
	PHA
	LDA #76
	LDY #33
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $214D,0
	LDA #0
	PHA
	LDA #77
	LDY #33
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $214E,0
	LDA #0
	PHA
	LDA #78
	LDY #33
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $214F,0
	LDA #0
	PHA
	LDA #79
	LDY #33
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $2150,0
	LDA #0
	PHA
	LDA #80
	LDY #33
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $2151,0
	LDA #0
	PHA
	LDA #81
	LDY #33
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $2152,0
	LDA #0
	PHA
	LDA #82
	LDY #33
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $2153,0
	LDA #0
	PHA
	LDA #83
	LDY #33
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	WAIT	' (gera_boss: drena buffer da PPU)
	JSR wait
	; 	VPOKE $2154,0
	LDA #0
	PHA
	LDA #84
	LDY #33
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $2069,1
	LDA #1
	PHA
	LDA #105
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $2089,11
	LDA #11
	PHA
	LDA #137
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $20A9,187
	LDA #187
	PHA
	LDA #169
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $20C9,199
	LDA #199
	PHA
	LDA #201
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $20E9,211
	LDA #211
	PHA
	LDA #233
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $2109,227
	LDA #227
	PHA
	LDA #9
	LDY #33
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $2129,239
	LDA #239
	PHA
	LDA #41
	LDY #33
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $2149,-256
	LDA #0
	PHA
	LDA #73
	LDY #33
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $206A,2
	LDA #2
	PHA
	LDA #106
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $208A,16
	LDA #16
	PHA
	LDA #138
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $20AA,188
	LDA #188
	PHA
	LDA #170
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $20CA,200
	LDA #200
	PHA
	LDA #202
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $20EA,212
	LDA #212
	PHA
	LDA #234
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $210A,228
	LDA #228
	PHA
	LDA #10
	LDY #33
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $212A,240
	LDA #240
	PHA
	LDA #42
	LDY #33
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $214A,251
	LDA #251
	PHA
	LDA #74
	LDY #33
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $206B,-256
	LDA #0
	PHA
	LDA #107
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $208B,17
	LDA #17
	PHA
	LDA #139
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	WAIT	' (gera_boss: drena buffer da PPU)
	JSR wait
	; 	VPOKE $20AB,189
	LDA #189
	PHA
	LDA #171
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $20CB,201
	LDA #201
	PHA
	LDA #203
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $20EB,213
	LDA #213
	PHA
	LDA #235
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $210B,229
	LDA #229
	PHA
	LDA #11
	LDY #33
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $212B,241
	LDA #241
	PHA
	LDA #43
	LDY #33
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $214B,252
	LDA #252
	PHA
	LDA #75
	LDY #33
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $206C,3
	LDA #3
	PHA
	LDA #108
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $208C,18
	LDA #18
	PHA
	LDA #140
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $20AC,190
	LDA #190
	PHA
	LDA #172
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $20CC,202
	LDA #202
	PHA
	LDA #204
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $20EC,214
	LDA #214
	PHA
	LDA #236
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $210C,230
	LDA #230
	PHA
	LDA #12
	LDY #33
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $212C,242
	LDA #242
	PHA
	LDA #44
	LDY #33
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $214C,-256
	LDA #0
	PHA
	LDA #76
	LDY #33
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $206D,4
	LDA #4
	PHA
	LDA #109
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $208D,19
	LDA #19
	PHA
	LDA #141
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $20AD,191
	LDA #191
	PHA
	LDA #173
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $20CD,203
	LDA #203
	PHA
	LDA #205
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $20ED,215
	LDA #215
	PHA
	LDA #237
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	WAIT	' (gera_boss: drena buffer da PPU)
	JSR wait
	; 	VPOKE $210D,231
	LDA #231
	PHA
	LDA #13
	LDY #33
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $212D,243
	LDA #243
	PHA
	LDA #45
	LDY #33
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $214D,-256
	LDA #0
	PHA
	LDA #77
	LDY #33
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $206E,5
	LDA #5
	PHA
	LDA #110
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $208E,180
	LDA #180
	PHA
	LDA #142
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $20AE,192
	LDA #192
	PHA
	LDA #174
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $20CE,204
	LDA #204
	PHA
	LDA #206
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $20EE,220
	LDA #220
	PHA
	LDA #238
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $210E,232
	LDA #232
	PHA
	LDA #14
	LDY #33
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $212E,244
	LDA #244
	PHA
	LDA #46
	LDY #33
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $214E,-256
	LDA #0
	PHA
	LDA #78
	LDY #33
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $206F,6
	LDA #6
	PHA
	LDA #111
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $208F,181
	LDA #181
	PHA
	LDA #143
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $20AF,193
	LDA #193
	PHA
	LDA #175
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $20CF,205
	LDA #205
	PHA
	LDA #207
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $20EF,221
	LDA #221
	PHA
	LDA #239
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $210F,233
	LDA #233
	PHA
	LDA #15
	LDY #33
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $212F,245
	LDA #245
	PHA
	LDA #47
	LDY #33
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $214F,-256
	LDA #0
	PHA
	LDA #79
	LDY #33
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	WAIT	' (gera_boss: drena buffer da PPU)
	JSR wait
	; 	VPOKE $2070,7
	LDA #7
	PHA
	LDA #112
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $2090,182
	LDA #182
	PHA
	LDA #144
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $20B0,194
	LDA #194
	PHA
	LDA #176
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $20D0,206
	LDA #206
	PHA
	LDA #208
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $20F0,222
	LDA #222
	PHA
	LDA #240
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $2110,234
	LDA #234
	PHA
	LDA #16
	LDY #33
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $2130,246
	LDA #246
	PHA
	LDA #48
	LDY #33
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $2150,-256
	LDA #0
	PHA
	LDA #80
	LDY #33
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $2071,8
	LDA #8
	PHA
	LDA #113
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $2091,183
	LDA #183
	PHA
	LDA #145
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $20B1,195
	LDA #195
	PHA
	LDA #177
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $20D1,207
	LDA #207
	PHA
	LDA #209
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $20F1,223
	LDA #223
	PHA
	LDA #241
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $2111,235
	LDA #235
	PHA
	LDA #17
	LDY #33
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $2131,247
	LDA #247
	PHA
	LDA #49
	LDY #33
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $2151,-256
	LDA #0
	PHA
	LDA #81
	LDY #33
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $2072,-256
	LDA #0
	PHA
	LDA #114
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $2092,184
	LDA #184
	PHA
	LDA #146
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $20B2,196
	LDA #196
	PHA
	LDA #178
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	WAIT	' (gera_boss: drena buffer da PPU)
	JSR wait
	; 	VPOKE $20D2,208
	LDA #208
	PHA
	LDA #210
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $20F2,224
	LDA #224
	PHA
	LDA #242
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $2112,236
	LDA #236
	PHA
	LDA #18
	LDY #33
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $2132,248
	LDA #248
	PHA
	LDA #50
	LDY #33
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $2152,253
	LDA #253
	PHA
	LDA #82
	LDY #33
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $2073,9
	LDA #9
	PHA
	LDA #115
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $2093,185
	LDA #185
	PHA
	LDA #147
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $20B3,197
	LDA #197
	PHA
	LDA #179
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $20D3,209
	LDA #209
	PHA
	LDA #211
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $20F3,225
	LDA #225
	PHA
	LDA #243
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $2113,237
	LDA #237
	PHA
	LDA #19
	LDY #33
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $2133,249
	LDA #249
	PHA
	LDA #51
	LDY #33
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $2153,254
	LDA #254
	PHA
	LDA #83
	LDY #33
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $2074,10
	LDA #10
	PHA
	LDA #116
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $2094,186
	LDA #186
	PHA
	LDA #148
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $20B4,198
	LDA #198
	PHA
	LDA #180
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $20D4,210
	LDA #210
	PHA
	LDA #212
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $20F4,226
	LDA #226
	PHA
	LDA #244
	LDY #32
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $2114,238
	LDA #238
	PHA
	LDA #20
	LDY #33
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	WAIT	' (gera_boss: drena buffer da PPU)
	JSR wait
	; 	VPOKE $2134,250
	LDA #250
	PHA
	LDA #52
	LDY #33
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $2154,-256
	LDA #0
	PHA
	LDA #84
	LDY #33
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $23C2,$55
	LDA #85
	PHA
	LDA #194
	LDY #35
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $23C3,$55
	LDA #85
	PHA
	LDA #195
	LDY #35
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $23C4,$55
	LDA #85
	PHA
	LDA #196
	LDY #35
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $23C5,$55
	LDA #85
	PHA
	LDA #197
	LDY #35
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $23CA,$55
	LDA #85
	PHA
	LDA #202
	LDY #35
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $23CB,$55
	LDA #85
	PHA
	LDA #203
	LDY #35
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $23CC,$55
	LDA #85
	PHA
	LDA #204
	LDY #35
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $23CD,$55
	LDA #85
	PHA
	LDA #205
	LDY #35
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $23D2,$55
	LDA #85
	PHA
	LDA #210
	LDY #35
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $23D3,$55
	LDA #85
	PHA
	LDA #211
	LDY #35
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $23D4,$55
	LDA #85
	PHA
	LDA #212
	LDY #35
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $23D5,$55
	LDA #85
	PHA
	LDA #213
	LDY #35
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	END
	RTS
	; 
	; boss_erase:	PROCEDURE	' remove o boss do BG (apos a morte)
cvb_BOSS_ERASE:
	; 	' retangulo cols 9-20, linhas 3-10 (1/2 linha por frame)
	; 	FOR #j = $2069 TO $206E
	LDA #105
	LDY #32
	STA cvb_#J
	STY cvb_#J+1
cv302:
	; 		VPOKE #j,0
	LDA #0
	PHA
	LDA cvb_#J
	LDY cvb_#J+1
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	NEXT #j
	INC cvb_#J
	BNE cv303
	INC cvb_#J+1
cv303:
	LDA cvb_#J
	LDY cvb_#J+1
	SEC
	SBC #111
	TYA
	SBC #32
	BCC.L cv302
	; 	FOR #j = $206F TO $2074
	LDA #111
	LDY #32
	STA cvb_#J
	STY cvb_#J+1
cv304:
	; 		VPOKE #j,0
	LDA #0
	PHA
	LDA cvb_#J
	LDY cvb_#J+1
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	NEXT #j
	INC cvb_#J
	BNE cv305
	INC cvb_#J+1
cv305:
	LDA cvb_#J
	LDY cvb_#J+1
	SEC
	SBC #117
	TYA
	SBC #32
	BCC.L cv304
	; 	WAIT
	JSR wait
	; 	FOR #j = $2089 TO $208E
	LDA #137
	LDY #32
	STA cvb_#J
	STY cvb_#J+1
cv306:
	; 		VPOKE #j,0
	LDA #0
	PHA
	LDA cvb_#J
	LDY cvb_#J+1
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	NEXT #j
	INC cvb_#J
	BNE cv307
	INC cvb_#J+1
cv307:
	LDA cvb_#J
	LDY cvb_#J+1
	SEC
	SBC #143
	TYA
	SBC #32
	BCC.L cv306
	; 	FOR #j = $208F TO $2094
	LDA #143
	LDY #32
	STA cvb_#J
	STY cvb_#J+1
cv308:
	; 		VPOKE #j,0
	LDA #0
	PHA
	LDA cvb_#J
	LDY cvb_#J+1
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	NEXT #j
	INC cvb_#J
	BNE cv309
	INC cvb_#J+1
cv309:
	LDA cvb_#J
	LDY cvb_#J+1
	SEC
	SBC #149
	TYA
	SBC #32
	BCC.L cv308
	; 	WAIT
	JSR wait
	; 	FOR #j = $20A9 TO $20AE
	LDA #169
	LDY #32
	STA cvb_#J
	STY cvb_#J+1
cv310:
	; 		VPOKE #j,0
	LDA #0
	PHA
	LDA cvb_#J
	LDY cvb_#J+1
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	NEXT #j
	INC cvb_#J
	BNE cv311
	INC cvb_#J+1
cv311:
	LDA cvb_#J
	LDY cvb_#J+1
	SEC
	SBC #175
	TYA
	SBC #32
	BCC.L cv310
	; 	FOR #j = $20AF TO $20B4
	LDA #175
	LDY #32
	STA cvb_#J
	STY cvb_#J+1
cv312:
	; 		VPOKE #j,0
	LDA #0
	PHA
	LDA cvb_#J
	LDY cvb_#J+1
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	NEXT #j
	INC cvb_#J
	BNE cv313
	INC cvb_#J+1
cv313:
	LDA cvb_#J
	LDY cvb_#J+1
	SEC
	SBC #181
	TYA
	SBC #32
	BCC.L cv312
	; 	WAIT
	JSR wait
	; 	FOR #j = $20C9 TO $20CE
	LDA #201
	LDY #32
	STA cvb_#J
	STY cvb_#J+1
cv314:
	; 		VPOKE #j,0
	LDA #0
	PHA
	LDA cvb_#J
	LDY cvb_#J+1
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	NEXT #j
	INC cvb_#J
	BNE cv315
	INC cvb_#J+1
cv315:
	LDA cvb_#J
	LDY cvb_#J+1
	SEC
	SBC #207
	TYA
	SBC #32
	BCC.L cv314
	; 	FOR #j = $20CF TO $20D4
	LDA #207
	LDY #32
	STA cvb_#J
	STY cvb_#J+1
cv316:
	; 		VPOKE #j,0
	LDA #0
	PHA
	LDA cvb_#J
	LDY cvb_#J+1
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	NEXT #j
	INC cvb_#J
	BNE cv317
	INC cvb_#J+1
cv317:
	LDA cvb_#J
	LDY cvb_#J+1
	SEC
	SBC #213
	TYA
	SBC #32
	BCC.L cv316
	; 	WAIT
	JSR wait
	; 	FOR #j = $20E9 TO $20EE
	LDA #233
	LDY #32
	STA cvb_#J
	STY cvb_#J+1
cv318:
	; 		VPOKE #j,0
	LDA #0
	PHA
	LDA cvb_#J
	LDY cvb_#J+1
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	NEXT #j
	INC cvb_#J
	BNE cv319
	INC cvb_#J+1
cv319:
	LDA cvb_#J
	LDY cvb_#J+1
	SEC
	SBC #239
	TYA
	SBC #32
	BCC.L cv318
	; 	FOR #j = $20EF TO $20F4
	LDA #239
	LDY #32
	STA cvb_#J
	STY cvb_#J+1
cv320:
	; 		VPOKE #j,0
	LDA #0
	PHA
	LDA cvb_#J
	LDY cvb_#J+1
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	NEXT #j
	INC cvb_#J
	BNE cv321
	INC cvb_#J+1
cv321:
	LDA cvb_#J
	LDY cvb_#J+1
	SEC
	SBC #245
	TYA
	SBC #32
	BCC.L cv320
	; 	WAIT
	JSR wait
	; 	FOR #j = $2109 TO $210E
	LDA #9
	LDY #33
	STA cvb_#J
	STY cvb_#J+1
cv322:
	; 		VPOKE #j,0
	LDA #0
	PHA
	LDA cvb_#J
	LDY cvb_#J+1
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	NEXT #j
	INC cvb_#J
	BNE cv323
	INC cvb_#J+1
cv323:
	LDA cvb_#J
	LDY cvb_#J+1
	SEC
	SBC #15
	TYA
	SBC #33
	BCC.L cv322
	; 	FOR #j = $210F TO $2114
	LDA #15
	LDY #33
	STA cvb_#J
	STY cvb_#J+1
cv324:
	; 		VPOKE #j,0
	LDA #0
	PHA
	LDA cvb_#J
	LDY cvb_#J+1
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	NEXT #j
	INC cvb_#J
	BNE cv325
	INC cvb_#J+1
cv325:
	LDA cvb_#J
	LDY cvb_#J+1
	SEC
	SBC #21
	TYA
	SBC #33
	BCC.L cv324
	; 	WAIT
	JSR wait
	; 	FOR #j = $2129 TO $212E
	LDA #41
	LDY #33
	STA cvb_#J
	STY cvb_#J+1
cv326:
	; 		VPOKE #j,0
	LDA #0
	PHA
	LDA cvb_#J
	LDY cvb_#J+1
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	NEXT #j
	INC cvb_#J
	BNE cv327
	INC cvb_#J+1
cv327:
	LDA cvb_#J
	LDY cvb_#J+1
	SEC
	SBC #47
	TYA
	SBC #33
	BCC.L cv326
	; 	FOR #j = $212F TO $2134
	LDA #47
	LDY #33
	STA cvb_#J
	STY cvb_#J+1
cv328:
	; 		VPOKE #j,0
	LDA #0
	PHA
	LDA cvb_#J
	LDY cvb_#J+1
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	NEXT #j
	INC cvb_#J
	BNE cv329
	INC cvb_#J+1
cv329:
	LDA cvb_#J
	LDY cvb_#J+1
	SEC
	SBC #53
	TYA
	SBC #33
	BCC.L cv328
	; 	WAIT
	JSR wait
	; 	FOR #j = $2149 TO $214E
	LDA #73
	LDY #33
	STA cvb_#J
	STY cvb_#J+1
cv330:
	; 		VPOKE #j,0
	LDA #0
	PHA
	LDA cvb_#J
	LDY cvb_#J+1
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	NEXT #j
	INC cvb_#J
	BNE cv331
	INC cvb_#J+1
cv331:
	LDA cvb_#J
	LDY cvb_#J+1
	SEC
	SBC #79
	TYA
	SBC #33
	BCC.L cv330
	; 	FOR #j = $214F TO $2154
	LDA #79
	LDY #33
	STA cvb_#J
	STY cvb_#J+1
cv332:
	; 		VPOKE #j,0
	LDA #0
	PHA
	LDA cvb_#J
	LDY cvb_#J+1
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	NEXT #j
	INC cvb_#J
	BNE cv333
	INC cvb_#J+1
cv333:
	LDA cvb_#J
	LDY cvb_#J+1
	SEC
	SBC #85
	TYA
	SBC #33
	BCC.L cv332
	; 	WAIT
	JSR wait
	; 	VPOKE $23C2,0
	LDA #0
	PHA
	LDA #194
	LDY #35
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $23C3,0
	LDA #0
	PHA
	LDA #195
	LDY #35
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $23C4,0
	LDA #0
	PHA
	LDA #196
	LDY #35
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $23C5,0
	LDA #0
	PHA
	LDA #197
	LDY #35
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $23CA,0
	LDA #0
	PHA
	LDA #202
	LDY #35
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $23CB,0
	LDA #0
	PHA
	LDA #203
	LDY #35
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $23CC,0
	LDA #0
	PHA
	LDA #204
	LDY #35
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $23CD,0
	LDA #0
	PHA
	LDA #205
	LDY #35
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $23D2,0
	LDA #0
	PHA
	LDA #210
	LDY #35
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $23D3,0
	LDA #0
	PHA
	LDA #211
	LDY #35
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $23D4,0
	LDA #0
	PHA
	LDA #212
	LDY #35
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $23D5,0
	LDA #0
	PHA
	LDA #213
	LDY #35
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	WAIT
	JSR wait
	; 	END
	RTS
	; 
	; boss_start:	PROCEDURE	' BOSS (v0.13): 1 nave 96x64 no alto, 100% BG
cvb_BOSS_START:
	; 	bsw = 1
	LDA #1
	STA cvb_BSW
	; 	bsa = 1
	STA cvb_BSA
	; 	bsph = 1			' fase 1: leques alternados das asas
	STA cvb_BSPH
	; 	bst = 60			' 1s de graca apos o warp-in
	LDA #60
	STA cvb_BST
	; 	bsn = 0
	LDA #0
	STA cvb_BSN
	; 	bshw = 0			' proximo leque: asa esquerda
	STA cvb_BSHW
	; 	bshp = 120			' HP do boss (constante p/ ajuste fino)
	LDA #120
	STA cvb_BSHP
	; 	bol = 0
	LDA #0
	STA cvb_BOL
	; 	boff = 0			' balanco comeca no centro
	STA cvb_BOFF
	; 	bdir = 0
	STA cvb_BDIR
	; 	bpf = 0
	STA cvb_BPF
	; 	scroll_y = 0
	STA cvb_SCROLL_Y
	; 	SCROLL 0,0			' boss e BG: congela o cenario no zero
	TAY
	STA scroll_x
	STY scroll_x+1
	STA scroll_y
	STY scroll_y+1
	; 	GOSUB sky_clear		' ceu 100% preto (~1s, top-down: dramatico)
	JSR cvb_SKY_CLEAR
	JSR cvb_FAMISTUDIO_START
	; 	VPOKE $3F05,$03		' BG pal1 = paleta do boss (roxo/lilas/dourado)
	LDA #3
	PHA
	LDA #5
	LDY #63
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $3F06,$23		' (cores exatas do boss.png do Saulo)
	LDA #35
	PHA
	LDA #6
	LDY #63
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $3F07,$38
	LDA #56
	PHA
	LDA #7
	LDY #63
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	' BG passa a ler a tabela $1000 (a arte do boss mora la); sprites
	; 	' 8x16 escolhem a tabela pelo bit0 do byte: nada muda p/ eles!
	; 	ASM LDA #$B8
 LDA #$B8
	; 	ASM STA ppu_ctrl
 STA ppu_ctrl
	; 	GOSUB boss_write		' desenha o corpo 96x64 (com WAITs)
	JSR cvb_BOSS_WRITE
	; 	END
	RTS
	; 
	; boss_kill:	PROCEDURE	' morte do boss: +5000, cerimonia, restaura cenario
cvb_BOSS_KILL:
	; 	bsa = 0
	LDA #0
	STA cvb_BSA
	; 	bsw = 0
	STA cvb_BSW
	; 	bol = 0
	STA cvb_BOL
	; 	SPRITE 61,$f0,0,0,0	' esconde o laser gêmeo
	LDA #61
	PHA
	LDA #240
	STA sprite_data
	LDA #0
	STA sprite_data+3
	STA sprite_data+1
	STA sprite_data+2
	PLA
	JSR update_sprite
	; 	SPRITE 62,$f0,0,0,0
	LDA #62
	PHA
	LDA #240
	STA sprite_data
	LDA #0
	STA sprite_data+3
	STA sprite_data+1
	STA sprite_data+2
	PLA
	JSR update_sprite
	; 	' BG volta p/ tabela $0000 (estrelas/fonte!)
	; 	ASM LDA #$A8
 LDA #$A8
	; 	ASM STA ppu_ctrl
 STA ppu_ctrl
	; 	VPOKE $3F05,$11		' restaura BG pal1 (estrelas)
	LDA #17
	PHA
	LDA #5
	LDY #63
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $3F06,$21
	LDA #33
	PHA
	LDA #6
	LDY #63
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $3F07,$00
	LDA #0
	PHA
	LDA #7
	LDY #63
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	mpt = 24			' explosao longa no centro do boss
	LDA #24
	STA cvb_MPT
	; 	mpx = 112 + boff
	LDA cvb_BOFF
	CLC
	ADC #112
	STA cvb_MPX
	; 	mpy = 56
	LDA #56
	STA cvb_MPY
	; 	#pop = 24
	LDA #24
	LDY #0
	STA cvb_#POP
	STY cvb_#POP+1
	; 	GOSUB boss_erase		' apaga o boss do BG (com WAITs)
	JSR cvb_BOSS_ERASE
	; 	' v0.28: SEM refill do mar aqui! banco1 -> banco3 (janela->janela,
	; 	' aninhado) trava a CPU. E nao precisa: o boss e' o FIM da fase; o
	; 	' fundo da fase seguinte e' refeito no begin_stage (banco 0->3, ok).
	; 	IF (fase AND 1) = 1 THEN	' (espaco: stars_fill e' fixo, sem wrap)
	LDA cvb_FASE
	AND #1
	CMP #1
	BNE.L cv334
	; 		GOSUB stars_fill	' devolve as estrelas ao cenario
	JSR cvb_STARS_FILL
	; 	END IF
cv334:
	; 	bsc = 70			' v0.19: cerimonia (estrobo+estouros) p/ transicao
	LDA #70
	STA cvb_BSC
	; 	e = 50				' +5000 pontos (chefe da fase 1!)
	LDA #50
	STA cvb_E
	; 	d = 0
	LDA #0
	STA cvb_D
	; 	GOSUB score_add
	JSR cvb_SCORE_ADD
	; 	nsma = 0			' boss volta a contar do zero (proximo ciclo)
	LDA #0
	STA cvb_NSMA
	; 	nsha = 0
	STA cvb_NSHA
	; 	ne4 = 0
	STA cvb_NE4
	; 	END
	RTS
	; 
	; mb_kill:	PROCEDURE	' morte do miniboss: +500, explosao grande central
cvb_MB_KILL:
	; 	mba = 0
	LDA #0
	STA cvb_MBA
	; 	mlr = 0
	STA cvb_MLR
	; 	FOR i = 41 TO 48
	LDA #41
	STA cvb_I
cv335:
	; 		SPRITE i,$f0,0,0,0
	LDA cvb_I
	PHA
	LDA #240
	STA sprite_data
	LDA #0
	STA sprite_data+3
	STA sprite_data+1
	STA sprite_data+2
	PLA
	JSR update_sprite
	; 	NEXT i
	INC cvb_I
	LDA cvb_I
	CMP #49
	BCC.L cv335
	; 	FOR i = 57 TO 60	' laser do miniboss (v0.12)
	LDA #57
	STA cvb_I
cv336:
	; 		SPRITE i,$f0,0,0,0
	LDA cvb_I
	PHA
	LDA #240
	STA sprite_data
	LDA #0
	STA sprite_data+3
	STA sprite_data+1
	STA sprite_data+2
	PLA
	JSR update_sprite
	; 	NEXT i
	INC cvb_I
	LDA cvb_I
	CMP #61
	BCC.L cv336
	; 	VPOKE $3F19,$19		' restaura pal2 (verde da chama/shards)
	LDA #25
	PHA
	LDY #63
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $3F1A,$2A
	LDA #42
	PHA
	LDA #26
	LDY #63
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $3F1B,$30
	LDA #48
	PHA
	LDA #27
	LDY #63
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	mpt = 16
	LDA #16
	STA cvb_MPT
	; 	mpx = mbx + 8
	LDA cvb_MBX
	CLC
	ADC #8
	STA cvb_MPX
	; 	mpy = yc + 8
	LDA cvb_YC
	CLC
	ADC #8
	STA cvb_MPY
	; 	e = 5				' 500 pontos (= medB/miniboss do jogo original)
	LDA #5
	STA cvb_E
	; 	d = 0
	LDA #0
	STA cvb_D
	; 	GOSUB score_add
	JSR cvb_SCORE_ADD
	; 	#pop = 16
	LDA #16
	LDY #0
	STA cvb_#POP
	STY cvb_#POP+1
	; 	END
	RTS
	; 
	; mb_frame:	PROCEDURE	' v0.15: frames do MINIBOSS (patrulha, laser, aneis, colisoes).
cvb_MB_FRAME:
	; 							' Sai com diek=1 quando a nave morre (GOTO p/ fora de proc e' ilegal).
	; 		yc = (#mby / 16) - 256
	LDA cvb_#MBY
	LDY cvb_#MBY+1
	LDX #16
	STX temp
	LDX #0
	STX temp+1
	JSR _div16
	SEC
	SBC #0
	STA cvb_YC
	; 		IF mbs = 1 THEN
	LDA cvb_MBS
	CMP #1
	BNE.L cv337
	; 			' descendo ate UM POUCO ACIMA do meio da tela (v0.12: era y=100)
	; 			#mby = #mby + 16
	LDA cvb_#MBY
	LDY cvb_#MBY+1
	CLC
	ADC #16
	TAX
	TYA
	ADC #0
	TAY
	TXA
	STA cvb_#MBY
	STY cvb_#MBY+1
	; 			IF #mby >= 5248 THEN mbs = 2	' 5248 = (72+256)*16
	SEC
	SBC #128
	TYA
	SBC #20
	BCC.L cv338
	LDA #2
	STA cvb_MBS
cv338:
	; 		ELSE
	JMP cv339
cv337:
	; 			' patrulha esquerda/direita (1 px/frame, inverte nas margens)
	; 			IF mbdir = 0 THEN
	LDA cvb_MBDIR
	BNE.L cv340
	; 				mbx = mbx + 1
	INC cvb_MBX
	; 				IF mbx >= 200 THEN mbdir = 1
	LDA cvb_MBX
	CMP #200
	BCC.L cv341
	LDA #1
	STA cvb_MBDIR
cv341:
	; 			ELSE
	JMP cv342
cv340:
	; 				mbx = mbx - 1
	DEC cvb_MBX
	; 				IF mbx <= 16 THEN mbdir = 0
	LDA cvb_MBX
	CMP #17
	BCS.L cv343
	LDA #0
	STA cvb_MBDIR
cv343:
	; 			END IF
cv342:
	; 			' v0.14: laser em 3 pontos do passeio (pedido do Saulo):
	; 			' centro exato (112) E os dois extremos (16/200)
	; 			e2 = 0
	LDA #0
	STA cvb_E2
	; 			IF mbx = 112 THEN e2 = 1
	LDA cvb_MBX
	CMP #112
	BNE.L cv344
	LDA #1
	STA cvb_E2
cv344:
	; 			IF mbx = 200 THEN e2 = 1
	LDA cvb_MBX
	CMP #200
	BNE.L cv345
	LDA #1
	STA cvb_E2
cv345:
	; 			IF mbx = 16 THEN e2 = 1
	LDA cvb_MBX
	CMP #16
	BNE.L cv346
	LDA #1
	STA cvb_E2
cv346:
	; 			IF mlr = 0 THEN
	LDA cvb_MLR
	BNE.L cv347
	; 				IF mbx <> mbxo THEN
	LDA cvb_MBX
	CMP cvb_MBXO
	BEQ.L cv348
	; 					IF e2 = 1 THEN
	LDA cvb_E2
	CMP #1
	BNE.L cv349
	; 						mlr = 1
	LDA #1
	STA cvb_MLR
	; 						mlx = mbx + 8
	LDA cvb_MBX
	CLC
	ADC #8
	STA cvb_MLX
	; 						#tw = yc + 276		' y do inicio do laser
	LDA cvb_YC
	LDY #0
	CLC
	ADC #20
	TAX
	TYA
	ADC #1
	TAY
	TXA
	STA cvb_#TW
	STY cvb_#TW+1
	; 						#mly = #tw * 16
	STY temp
	ASL A
	ROL temp
	ASL A
	ROL temp
	ASL A
	ROL temp
	ASL A
	ROL temp
	LDY temp
	STA cvb_#MLY
	STY cvb_#MLY+1
	; 					END IF
cv349:
	; 				END IF
cv348:
	; 			END IF
cv347:
	; 			mbxo = mbx
	LDA cvb_MBX
	STA cvb_MBXO
	; 			' Aneis de tempos em tempos; SO dispara quando o pool de tiros
	; 			' inimigos esvaziou (trava anti-slowdown pedida pelo Saulo)
	; 			IF mbt > 0 THEN mbt = mbt - 1
	LDA cvb_MBT
	CMP #1
	BCC.L cv350
	DEC cvb_MBT
cv350:
	; 			IF mbt = 0 THEN
	LDA cvb_MBT
	BNE.L cv351
	; 				e = eba(0) + eba(1) + eba(2) + eba(3) + eba(4) + eba(5) + eba(6) + eba(7)
	LDA array_EBA+1
	STA temp
	LDA array_EBA
	CLC
	ADC temp
	PHA
	LDA array_EBA+2
	STA temp
	PLA
	CLC
	ADC temp
	PHA
	LDA array_EBA+3
	STA temp
	PLA
	CLC
	ADC temp
	PHA
	LDA array_EBA+4
	STA temp
	PLA
	CLC
	ADC temp
	PHA
	LDA array_EBA+5
	STA temp
	PLA
	CLC
	ADC temp
	PHA
	LDA array_EBA+6
	STA temp
	PLA
	CLC
	ADC temp
	PHA
	LDA array_EBA+7
	STA temp
	PLA
	CLC
	ADC temp
	STA cvb_E
	; 				IF e = 0 THEN
	TAX
	AND #128
	BPL cv353
	LDA #255
cv353:
	TAY
	TXA
	STY temp
	ORA temp
	BNE.L cv352
	; 					#tbx = mbx + 16
	LDA cvb_MBX
	LDY #0
	CLC
	ADC #16
	TAX
	TYA
	ADC #0
	TAY
	TXA
	STA cvb_#TBX
	STY cvb_#TBX+1
	; 					#tby = yc + 16
	LDA cvb_YC
	LDY #0
	CLC
	ADC #16
	TAX
	TYA
	ADC #0
	TAY
	TXA
	STA cvb_#TBY
	STY cvb_#TBY+1
	; 					GOSUB spawn_ring
	JSR cvb_SPAWN_RING
	; 					mbt = 150		' 2.5s de descanso apos disparar
	LDA #150
	STA cvb_MBT
	; 				END IF
cv352:
	; 			END IF
cv351:
	; 		END IF
cv339:
	; 		IF #mby < 4112 THEN
	LDA cvb_#MBY
	LDY cvb_#MBY+1
	SEC
	SBC #16
	TYA
	SBC #16
	BCS.L cv354
	; 			FOR c = 41 TO 48	' ainda entrando: escondido
	LDA #41
	STA cvb_C
cv355:
	; 				SPRITE c,$f0,0,0,0
	LDA cvb_C
	PHA
	LDA #240
	STA sprite_data
	LDA #0
	STA sprite_data+3
	STA sprite_data+1
	STA sprite_data+2
	PLA
	JSR update_sprite
	; 			NEXT c
	INC cvb_C
	LDA cvb_C
	CMP #49
	BCC.L cv355
	; 		ELSE
	JMP cv356
cv354:
	; 			' desenha: 2 frames animados (bases 141/157); reuse dos slots
	; 			' 41-48 do enemy4 (eles NUNCA coexistem: ondas exclusivas)
	; 			d = (FRAME / 8) AND 1
	LDA frame
	LDY frame+1
	STY temp
	LSR temp
	ROR A
	LSR temp
	ROR A
	LSR temp
	ROR A
	LDY temp
	AND #1
	STA cvb_D
	; 			d = d * 16
	ASL A
	ASL A
	ASL A
	ASL A
	STA cvb_D
	; 			d = d + 141
	CLC
	ADC #141
	STA cvb_D
	; 			e = mbx
	LDA cvb_MBX
	STA cvb_E
	; 			FOR c = 41 TO 44
	LDA #41
	STA cvb_C
cv357:
	; 				SPRITE c,yc - 1,e,d,2
	LDA cvb_C
	PHA
	LDA cvb_YC
	SEC
	SBC #1
	STA sprite_data
	LDA cvb_E
	STA sprite_data+3
	LDA cvb_D
	STA sprite_data+1
	LDA #2
	STA sprite_data+2
	PLA
	JSR update_sprite
	; 				e = e + 8
	LDA cvb_E
	CLC
	ADC #8
	STA cvb_E
	; 				d = d + 2
	INC cvb_D
	INC cvb_D
	; 			NEXT c
	INC cvb_C
	LDA cvb_C
	CMP #45
	BCC.L cv357
	; 			e = mbx
	LDA cvb_MBX
	STA cvb_E
	; 			FOR c = 45 TO 48
	LDA #45
	STA cvb_C
cv358:
	; 				SPRITE c,yc + 15,e,d,2
	LDA cvb_C
	PHA
	LDA cvb_YC
	CLC
	ADC #15
	STA sprite_data
	LDA cvb_E
	STA sprite_data+3
	LDA cvb_D
	STA sprite_data+1
	LDA #2
	STA sprite_data+2
	PLA
	JSR update_sprite
	; 				e = e + 8
	LDA cvb_E
	CLC
	ADC #8
	STA cvb_E
	; 				d = d + 2
	INC cvb_D
	INC cvb_D
	; 			NEXT c
	INC cvb_C
	LDA cvb_C
	CMP #49
	BCC.L cv358
	; 		END IF
cv356:
	; 		' Encostou na nave? (colisao = 1 tiro de dano no miniboss tambem)
	; 		IF ded = 0 AND inv = 0 THEN
	LDA cvb_INV
	BEQ cv360
	LDA #0
	DB $2c
cv360:
	LDA #255
	STA temp
	LDA cvb_DED
	BEQ cv361
	LDA #0
	DB $2c
cv361:
	LDA #255
	AND temp
	BEQ.L cv359
	; 			IF #mby >= 4112 THEN
	LDA cvb_#MBY
	LDY cvb_#MBY+1
	SEC
	SBC #16
	TYA
	SBC #16
	BCC.L cv362
	; 				#c1 = px
	LDA cvb_PX
	LDY #0
	STA cvb_#C1
	STY cvb_#C1+1
	; 				#c1 = #c1 - mbx
	SEC
	SBC cvb_MBX
	TAX
	TYA
	SBC #0
	TAY
	TXA
	STA cvb_#C1
	STY cvb_#C1+1
	; 				#c1 = #c1 - 8
	SEC
	SBC #8
	TAX
	TYA
	SBC #0
	TAY
	TXA
	STA cvb_#C1
	STY cvb_#C1+1
	; 				IF ABS(#c1) < 20 THEN
	JSR _abs16
	SEC
	SBC #20
	TYA
	SBC #0
	BCS.L cv363
	; 					#c2 = py
	LDA cvb_PY
	LDY #0
	STA cvb_#C2
	STY cvb_#C2+1
	; 					#c2 = #c2 - yc
	SEC
	SBC cvb_YC
	TAX
	TYA
	SBC #0
	TAY
	TXA
	STA cvb_#C2
	STY cvb_#C2+1
	; 					#c2 = #c2 - 16
	SEC
	SBC #16
	TAX
	TYA
	SBC #0
	TAY
	TXA
	STA cvb_#C2
	STY cvb_#C2+1
	; 					IF ABS(#c2) < 20 THEN
	JSR _abs16
	SEC
	SBC #20
	TYA
	SBC #0
	BCS.L cv364
	; 						mbhp = mbhp - 1
	DEC cvb_MBHP
	; 						IF mbhp = 0 THEN GOSUB mb_kill
	LDA cvb_MBHP
	BNE.L cv365
	JSR cvb_MB_KILL
cv365:
	; 						diek = 1: RETURN		' v0.15: era GOTO player_dies (fora de proc nao pode!)
	LDA #1
	STA cvb_DIEK
	RTS
	; 					END IF
cv364:
	; 				END IF
cv363:
	; 			END IF
cv362:
	; 		END IF
cv359:
	; 		' Levou tiro?
	; 		FOR d = 0 TO 4
	LDA #0
	STA cvb_D
cv366:
	; 			IF bty(d) <> 0 THEN
	LDA #array_BTY
	CLC
	ADC cvb_D
	TAX
	LDA #array_BTY>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	CMP #0
	BEQ.L cv367
	; 				IF btx(d) + 6 > mbx AND btx(d) < mbx + 26 THEN
	LDA cvb_MBX
	LDY #0
	PHA
	TYA
	PHA
	LDA #array_BTX
	CLC
	ADC cvb_D
	TAX
	LDA #array_BTX>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	LDY #0
	CLC
	ADC #6
	TAX
	TYA
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	PLA
	TAY
	PLA
	SEC
	SBC temp
	TYA
	SBC temp+1
	LDA #255
	ADC #0
	PHA
	LDA pointer
	LDY pointer+1
	JSR _peek8
	LDY #0
	PHA
	TYA
	PHA
	LDA cvb_MBX
	CLC
	ADC #26
	TAX
	TYA
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	PLA
	TAY
	PLA
	SEC
	SBC temp
	TYA
	SBC temp+1
	LDA #255
	ADC #0
	STA temp
	PLA
	AND temp
	BEQ.L cv368
	; 					IF bty(d) + 8 > yc AND bty(d) < yc + 32 THEN
	LDA cvb_YC
	LDY #0
	PHA
	TYA
	PHA
	LDA #array_BTY
	CLC
	ADC cvb_D
	TAX
	LDA #array_BTY>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	LDY #0
	CLC
	ADC #8
	TAX
	TYA
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	PLA
	TAY
	PLA
	SEC
	SBC temp
	TYA
	SBC temp+1
	LDA #255
	ADC #0
	PHA
	LDA pointer
	LDY pointer+1
	JSR _peek8
	LDY #0
	PHA
	TYA
	PHA
	LDA cvb_YC
	CLC
	ADC #32
	TAX
	TYA
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	PLA
	TAY
	PLA
	SEC
	SBC temp
	TYA
	SBC temp+1
	LDA #255
	ADC #0
	STA temp
	PLA
	AND temp
	BEQ.L cv369
	; 						bty(d) = 0
	LDA pointer
	LDY pointer+1
	STA temp
	STY temp+1
	LDA #0
	TAY
	STA (temp),Y
	; 						SPRITE 16 + d,$f0,0,0,0
	LDA cvb_D
	CLC
	ADC #16
	PHA
	LDA #240
	STA sprite_data
	TYA
	STA sprite_data+3
	STA sprite_data+1
	STA sprite_data+2
	PLA
	JSR update_sprite
	; 						mpt = 6				' faisca no impacto
	LDA #6
	STA cvb_MPT
	; 						mpx = btx(d) - 3
	LDA #array_BTX
	CLC
	ADC cvb_D
	TAX
	LDA #array_BTX>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	SEC
	SBC #3
	STA cvb_MPX
	; 						mpy = bty(d)
	LDA #array_BTY
	CLC
	ADC cvb_D
	TAX
	LDA #array_BTY>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	STA cvb_MPY
	; 						mbhp = mbhp - 1
	DEC cvb_MBHP
	; 						#pop = 4
	LDA #4
	LDY #0
	STA cvb_#POP
	STY cvb_#POP+1
	; 					IF mbhp = 0 THEN GOSUB mb_kill
	LDA cvb_MBHP
	BNE.L cv370
	JSR cvb_MB_KILL
cv370:
	; 					d = 5
	LDA #5
	STA cvb_D
	; 				END IF
cv369:
	; 			END IF
cv368:
	; 		END IF
cv367:
	; 	NEXT d
	INC cvb_D
	LDA cvb_D
	CMP #5
	BCC.L cv366
	; 	' --- Laser do miniboss (v0.12: arte laser.png do Saulo, 16x32) ---
	; 	IF mlr THEN
	LDA cvb_MLR
	CMP #0
	BEQ.L cv371
	; 		#mly = #mly + 96	' desce rapido: 6 px/frame
	LDA cvb_#MLY
	LDY cvb_#MLY+1
	CLC
	ADC #96
	TAX
	TYA
	ADC #0
	TAY
	TXA
	STA cvb_#MLY
	STY cvb_#MLY+1
	; 		IF #mly >= 7808 THEN mlr = 0	' (232+256)*16: saiu da tela
	SEC
	SBC #128
	TYA
	SBC #30
	BCC.L cv372
	LDA #0
	STA cvb_MLR
cv372:
	; 		IF mlr THEN
	LDA cvb_MLR
	CMP #0
	BEQ.L cv373
	; 			ly = (#mly / 16) - 256
	LDA cvb_#MLY
	LDY cvb_#MLY+1
	LDX #16
	STX temp
	LDX #0
	STX temp+1
	JSR _div16
	SEC
	SBC #0
	STA cvb_LY
	; 			SPRITE 57,ly - 1,mlx,173,3
	LDA #57
	PHA
	LDA cvb_LY
	SEC
	SBC #1
	STA sprite_data
	LDA cvb_MLX
	STA sprite_data+3
	LDA #173
	STA sprite_data+1
	LDA #3
	STA sprite_data+2
	PLA
	JSR update_sprite
	; 			SPRITE 58,ly + 15,mlx,175,3
	LDA #58
	PHA
	LDA cvb_LY
	CLC
	ADC #15
	STA sprite_data
	LDA cvb_MLX
	STA sprite_data+3
	LDA #175
	STA sprite_data+1
	LDA #3
	STA sprite_data+2
	PLA
	JSR update_sprite
	; 			SPRITE 59,ly - 1,mlx + 8,177,3
	LDA #59
	PHA
	LDA cvb_LY
	SEC
	SBC #1
	STA sprite_data
	LDA cvb_MLX
	CLC
	ADC #8
	STA sprite_data+3
	LDA #177
	STA sprite_data+1
	LDA #3
	STA sprite_data+2
	PLA
	JSR update_sprite
	; 			SPRITE 60,ly + 15,mlx + 8,179,3
	LDA #60
	PHA
	LDA cvb_LY
	CLC
	ADC #15
	STA sprite_data
	LDA cvb_MLX
	CLC
	ADC #8
	STA sprite_data+3
	LDA #179
	STA sprite_data+1
	LDA #3
	STA sprite_data+2
	PLA
	JSR update_sprite
	; 			IF ded = 0 AND inv = 0 THEN
	LDA cvb_INV
	BEQ cv375
	LDA #0
	DB $2c
cv375:
	LDA #255
	STA temp
	LDA cvb_DED
	BEQ cv376
	LDA #0
	DB $2c
cv376:
	LDA #255
	AND temp
	BEQ.L cv374
	; 				#c1 = px
	LDA cvb_PX
	LDY #0
	STA cvb_#C1
	STY cvb_#C1+1
	; 				#c1 = #c1 - mlx
	SEC
	SBC cvb_MLX
	TAX
	TYA
	SBC #0
	TAY
	TXA
	STA cvb_#C1
	STY cvb_#C1+1
	; 				#c1 = #c1 - 4
	SEC
	SBC #4
	TAX
	TYA
	SBC #0
	TAY
	TXA
	STA cvb_#C1
	STY cvb_#C1+1
	; 				IF ABS(#c1) < 10 THEN
	JSR _abs16
	SEC
	SBC #10
	TYA
	SBC #0
	BCS.L cv377
	; 					#c2 = py
	LDA cvb_PY
	LDY #0
	STA cvb_#C2
	STY cvb_#C2+1
	; 					#c2 = #c2 - ly
	SEC
	SBC cvb_LY
	TAX
	TYA
	SBC #0
	TAY
	TXA
	STA cvb_#C2
	STY cvb_#C2+1
	; 					#c2 = #c2 - 12
	SEC
	SBC #12
	TAX
	TYA
	SBC #0
	TAY
	TXA
	STA cvb_#C2
	STY cvb_#C2+1
	; 					IF ABS(#c2) < 20 THEN
	JSR _abs16
	SEC
	SBC #20
	TYA
	SBC #0
	BCS.L cv378
	; 						diek = 1: RETURN		' v0.15: era GOTO player_dies (fora de proc nao pode!)
	LDA #1
	STA cvb_DIEK
	RTS
	; 					END IF
cv378:
	; 				END IF
cv377:
	; 			END IF
cv374:
	; 		END IF
cv373:
	; 	ELSE
	JMP cv379
cv371:
	; 		FOR c = 57 TO 60	' laser apagado: esconde (so nesta onda)
	LDA #57
	STA cvb_C
cv380:
	; 			SPRITE c,$f0,0,0,0
	LDA cvb_C
	PHA
	LDA #240
	STA sprite_data
	LDA #0
	STA sprite_data+3
	STA sprite_data+1
	STA sprite_data+2
	PLA
	JSR update_sprite
	; 		NEXT c
	INC cvb_C
	LDA cvb_C
	CMP #61
	BCC.L cv380
	; 	END IF
cv379:
	; 	END
	RTS
	; 
	; boss_frame:	PROCEDURE	' v0.15: frames do BOSS (3 fases, leques, saraivada, hits).
cvb_BOSS_FRAME:
	; 							' Idem diek.
	; 		IF bsph = 1 THEN
	LDA cvb_BSPH
	CMP #1
	BNE.L cv381
	; 			bst = bst - 1
	DEC cvb_BST
	; 			IF bst = 0 THEN
	LDA cvb_BST
	BNE.L cv382
	; 				e = eba(0) + eba(1) + eba(2) + eba(3) + eba(4) + eba(5) + eba(6) + eba(7)
	LDA array_EBA+1
	STA temp
	LDA array_EBA
	CLC
	ADC temp
	PHA
	LDA array_EBA+2
	STA temp
	PLA
	CLC
	ADC temp
	PHA
	LDA array_EBA+3
	STA temp
	PLA
	CLC
	ADC temp
	PHA
	LDA array_EBA+4
	STA temp
	PLA
	CLC
	ADC temp
	PHA
	LDA array_EBA+5
	STA temp
	PLA
	CLC
	ADC temp
	PHA
	LDA array_EBA+6
	STA temp
	PLA
	CLC
	ADC temp
	PHA
	LDA array_EBA+7
	STA temp
	PLA
	CLC
	ADC temp
	STA cvb_E
	; 				IF e < 5 THEN			' trava anti-slowdown (pool de 8)
	TAX
	AND #128
	BPL cv384
	LDA #255
cv384:
	TAY
	TXA
	TAX
	TYA
	EOR #128
	TAY
	TXA
	SEC
	SBC #5
	TYA
	SBC #128
	BCS.L cv383
	; 					#tbx = 84 + #bo		' asas acompanham o balanco
	LDA cvb_#BO
	LDY cvb_#BO+1
	CLC
	ADC #84
	TAX
	TYA
	ADC #0
	TAY
	TXA
	STA cvb_#TBX
	STY cvb_#TBX+1
	; 					IF bshw <> 0 THEN
	LDA cvb_BSHW
	BEQ.L cv385
	; 						#tbx = 156 + #bo	' (16-bit c/ sinal: asa dir >127!)
	LDA cvb_#BO
	LDY cvb_#BO+1
	CLC
	ADC #156
	TAX
	TYA
	ADC #0
	TAY
	TXA
	STA cvb_#TBX
	STY cvb_#TBX+1
	; 					END IF
cv385:
	; 					#tby = 80
	LDA #80
	LDY #0
	STA cvb_#TBY
	STY cvb_#TBY+1
	; 					tbvy = 35
	LDA #35
	STA cvb_TBVY
	; 					tbvx = 247			' -9 (em byte) = leque p/ esq
	LDA #247
	STA cvb_TBVX
	; 					ebs = 0
	TYA
	STA cvb_EBS
	; 					GOSUB eb_spawn
	JSR cvb_EB_SPAWN
	; 					tbvx = 0
	LDA #0
	STA cvb_TBVX
	; 					ebs = 0
	STA cvb_EBS
	; 					GOSUB eb_spawn
	JSR cvb_EB_SPAWN
	; 					tbvx = 9			' leque p/ dir
	LDA #9
	STA cvb_TBVX
	; 					ebs = 0
	LDA #0
	STA cvb_EBS
	; 					GOSUB eb_spawn
	JSR cvb_EB_SPAWN
	; 					bshw = 1 - bshw
	LDA #1
	LDY #0
	SEC
	SBC cvb_BSHW
	TAX
	TYA
	SBC #0
	TAY
	TXA
	STA cvb_BSHW
	; 					bsn = bsn + 1
	INC cvb_BSN
	; 					bst = 42
	LDA #42
	STA cvb_BST
	; 					IF bsn >= 8 THEN
	LDA cvb_BSN
	CMP #8
	BCC.L cv386
	; 						bsph = 2
	LDA #2
	STA cvb_BSPH
	; 						bsn = 0
	LDA #0
	STA cvb_BSN
	; 						bst = 20
	LDA #20
	STA cvb_BST
	; 					END IF
cv386:
	; 				ELSE
	JMP cv387
cv383:
	; 					bst = 10			' pool cheio: remarca
	LDA #10
	STA cvb_BST
	; 				END IF
cv387:
	; 			END IF
cv382:
	; 		ELSE
	JMP cv388
cv381:
	; 			IF bsph = 2 THEN
	LDA cvb_BSPH
	CMP #2
	BNE.L cv389
	; 				bst = bst - 1
	DEC cvb_BST
	; 				IF bst = 0 THEN
	LDA cvb_BST
	BNE.L cv390
	; 					e = eba(0) + eba(1) + eba(2) + eba(3) + eba(4) + eba(5) + eba(6) + eba(7)
	LDA array_EBA+1
	STA temp
	LDA array_EBA
	CLC
	ADC temp
	PHA
	LDA array_EBA+2
	STA temp
	PLA
	CLC
	ADC temp
	PHA
	LDA array_EBA+3
	STA temp
	PLA
	CLC
	ADC temp
	PHA
	LDA array_EBA+4
	STA temp
	PLA
	CLC
	ADC temp
	PHA
	LDA array_EBA+5
	STA temp
	PLA
	CLC
	ADC temp
	PHA
	LDA array_EBA+6
	STA temp
	PLA
	CLC
	ADC temp
	PHA
	LDA array_EBA+7
	STA temp
	PLA
	CLC
	ADC temp
	STA cvb_E
	; 					IF e < 8 THEN
	TAX
	AND #128
	BPL cv392
	LDA #255
cv392:
	TAY
	TXA
	TAX
	TYA
	EOR #128
	TAY
	TXA
	SEC
	SBC #8
	TYA
	SBC #128
	BCS.L cv391
	; 						#tbx = 88 + RANDOM(64)	' diferentes locais...
	JSR random
	AND #63
	LDY #0
	CLC
	ADC #88
	TAX
	TYA
	ADC #0
	TAY
	TXA
	STA cvb_#TBX
	STY cvb_#TBX+1
	; 						#tbx = #tbx + #bo		' ...acompanhando o balanco
	CLC
	ADC cvb_#BO
	TAX
	TYA
	ADC cvb_#BO+1
	TAY
	TXA
	STA cvb_#TBX
	STY cvb_#TBX+1
	; 						#tby = 82
	LDA #82
	LDY #0
	STA cvb_#TBY
	STY cvb_#TBY+1
	; 						tbvx = 0
	TYA
	STA cvb_TBVX
	; 						tbvy = 26 + RANDOM(23)	' ...e diferentes velocidades
	JSR random
	LDX #23
	STX temp
	LDX #0
	STX temp+1
	JSR _mod16
	CLC
	ADC #26
	STA cvb_TBVY
	; 						ebs = 0
	LDA #0
	STA cvb_EBS
	; 						GOSUB eb_spawn
	JSR cvb_EB_SPAWN
	; 						bsn = bsn + 1
	INC cvb_BSN
	; 						bst = 8
	LDA #8
	STA cvb_BST
	; 						IF bsn >= 20 THEN
	LDA cvb_BSN
	CMP #20
	BCC.L cv393
	; 							bsph = 3
	LDA #3
	STA cvb_BSPH
	; 							bsn = 0
	LDA #0
	STA cvb_BSN
	; 							bst = 30
	LDA #30
	STA cvb_BST
	; 						END IF
cv393:
	; 					ELSE
	JMP cv394
cv391:
	; 						bst = 6
	LDA #6
	STA cvb_BST
	; 					END IF
cv394:
	; 				END IF
cv390:
	; 			ELSE
	JMP cv395
cv389:
	; 				bst = bst - 1
	DEC cvb_BST
	; 				IF bst = 0 THEN
	LDA cvb_BST
	BNE.L cv396
	; 					IF bol = 0 THEN
	LDA cvb_BOL
	BNE.L cv397
	; 						bol = 1
	LDA #1
	STA cvb_BOL
	; 						#boy = 5504			' (88+256)*16
	LDA #128
	LDY #21
	STA cvb_#BOY
	STY cvb_#BOY+1
	; 						bsn = bsn + 1
	INC cvb_BSN
	; 						IF bsn >= 3 THEN
	LDA cvb_BSN
	CMP #3
	BCC.L cv398
	; 							bsph = 1			' repete o ciclo
	LDA #1
	STA cvb_BSPH
	; 							bsn = 0
	LDA #0
	STA cvb_BSN
	; 							bst = 90
	LDA #90
	STA cvb_BST
	; 						ELSE
	JMP cv399
cv398:
	; 							bst = 50
	LDA #50
	STA cvb_BST
	; 						END IF
cv399:
	; 					ELSE
	JMP cv400
cv397:
	; 						bst = 8			' espera o laser sair da tela
	LDA #8
	STA cvb_BST
	; 					END IF
cv400:
	; 				END IF
cv396:
	; 			END IF
cv395:
	; 		END IF
cv388:
	; 		' laser do boss (do meio dele; arte laser.png, metade 16x16)
	; 		IF bol THEN
	LDA cvb_BOL
	CMP #0
	BEQ.L cv401
	; 			#boy = #boy + 96	' desce rapido: 6 px/frame
	LDA cvb_#BOY
	LDY cvb_#BOY+1
	CLC
	ADC #96
	TAX
	TYA
	ADC #0
	TAY
	TXA
	STA cvb_#BOY
	STY cvb_#BOY+1
	; 			IF #boy >= 7808 THEN bol = 0
	SEC
	SBC #128
	TYA
	SBC #30
	BCC.L cv402
	LDA #0
	STA cvb_BOL
cv402:
	; 			IF bol THEN
	LDA cvb_BOL
	CMP #0
	BEQ.L cv403
	; 				ly = (#boy / 16) - 256
	LDA cvb_#BOY
	LDY cvb_#BOY+1
	LDX #16
	STX temp
	LDX #0
	STX temp+1
	JSR _div16
	SEC
	SBC #0
	STA cvb_LY
	; 				e = 112 + boff			' acompanha o balanco do corpo
	LDA cvb_BOFF
	CLC
	ADC #112
	STA cvb_E
	; 				SPRITE 61,ly - 1,e,173,3
	LDA #61
	PHA
	LDA cvb_LY
	SEC
	SBC #1
	STA sprite_data
	LDA cvb_E
	STA sprite_data+3
	LDA #173
	STA sprite_data+1
	LDA #3
	STA sprite_data+2
	PLA
	JSR update_sprite
	; 				e = 120 + boff
	LDA cvb_BOFF
	CLC
	ADC #120
	STA cvb_E
	; 				SPRITE 62,ly - 1,e,177,3
	LDA #62
	PHA
	LDA cvb_LY
	SEC
	SBC #1
	STA sprite_data
	LDA cvb_E
	STA sprite_data+3
	LDA #177
	STA sprite_data+1
	LDA #3
	STA sprite_data+2
	PLA
	JSR update_sprite
	; 				e = 116 + boff
	LDA cvb_BOFF
	CLC
	ADC #116
	STA cvb_E
	; 				IF ded = 0 AND inv = 0 THEN
	LDA cvb_INV
	BEQ cv405
	LDA #0
	DB $2c
cv405:
	LDA #255
	STA temp
	LDA cvb_DED
	BEQ cv406
	LDA #0
	DB $2c
cv406:
	LDA #255
	AND temp
	BEQ.L cv404
	; 					#c1 = px
	LDA cvb_PX
	LDY #0
	STA cvb_#C1
	STY cvb_#C1+1
	; 					#c1 = #c1 - e
	PHA
	TYA
	PHA
	LDA cvb_E
	TAX
	AND #128
	BPL cv407
	LDA #255
cv407:
	TAY
	TXA
	STA temp
	STY temp+1
	PLA
	TAY
	PLA
	SEC
	SBC temp
	TAX
	TYA
	SBC temp+1
	TAY
	TXA
	STA cvb_#C1
	STY cvb_#C1+1
	; 					IF ABS(#c1) < 10 THEN
	JSR _abs16
	SEC
	SBC #10
	TYA
	SBC #0
	BCS.L cv408
	; 						#c2 = py
	LDA cvb_PY
	LDY #0
	STA cvb_#C2
	STY cvb_#C2+1
	; 						#c2 = #c2 - ly
	SEC
	SBC cvb_LY
	TAX
	TYA
	SBC #0
	TAY
	TXA
	STA cvb_#C2
	STY cvb_#C2+1
	; 						#c2 = #c2 - 8
	SEC
	SBC #8
	TAX
	TYA
	SBC #0
	TAY
	TXA
	STA cvb_#C2
	STY cvb_#C2+1
	; 						IF ABS(#c2) < 14 THEN
	JSR _abs16
	SEC
	SBC #14
	TYA
	SBC #0
	BCS.L cv409
	; 							diek = 1: RETURN		' v0.15: era GOTO player_dies (fora de proc nao pode!)
	LDA #1
	STA cvb_DIEK
	RTS
	; 						END IF
cv409:
	; 					END IF
cv408:
	; 				END IF
cv404:
	; 			END IF
cv403:
	; 		ELSE
	JMP cv410
cv401:
	; 			SPRITE 61,$f0,0,0,0
	LDA #61
	PHA
	LDA #240
	STA sprite_data
	LDA #0
	STA sprite_data+3
	STA sprite_data+1
	STA sprite_data+2
	PLA
	JSR update_sprite
	; 			SPRITE 62,$f0,0,0,0
	LDA #62
	PHA
	LDA #240
	STA sprite_data
	LDA #0
	STA sprite_data+3
	STA sprite_data+1
	STA sprite_data+2
	PLA
	JSR update_sprite
	; 		END IF
cv410:
	; 		' Encostou na nave? (boss 96x64 no alto: caixa 72..167 x 24..88)
	; 		e = 120 + boff
	LDA cvb_BOFF
	CLC
	ADC #120
	STA cvb_E
	; 		IF ded = 0 AND inv = 0 THEN
	LDA cvb_INV
	BEQ cv412
	LDA #0
	DB $2c
cv412:
	LDA #255
	STA temp
	LDA cvb_DED
	BEQ cv413
	LDA #0
	DB $2c
cv413:
	LDA #255
	AND temp
	BEQ.L cv411
	; 			#c1 = px
	LDA cvb_PX
	LDY #0
	STA cvb_#C1
	STY cvb_#C1+1
	; 			#c1 = #c1 + 8
	CLC
	ADC #8
	TAX
	TYA
	ADC #0
	TAY
	TXA
	STA cvb_#C1
	STY cvb_#C1+1
	; 			#c1 = #c1 - e
	PHA
	TYA
	PHA
	LDA cvb_E
	TAX
	AND #128
	BPL cv414
	LDA #255
cv414:
	TAY
	TXA
	STA temp
	STY temp+1
	PLA
	TAY
	PLA
	SEC
	SBC temp
	TAX
	TYA
	SBC temp+1
	TAY
	TXA
	STA cvb_#C1
	STY cvb_#C1+1
	; 			IF ABS(#c1) < 52 THEN
	JSR _abs16
	SEC
	SBC #52
	TYA
	SBC #0
	BCS.L cv415
	; 				#c2 = py
	LDA cvb_PY
	LDY #0
	STA cvb_#C2
	STY cvb_#C2+1
	; 				#c2 = #c2 - 56
	SEC
	SBC #56
	TAX
	TYA
	SBC #0
	TAY
	TXA
	STA cvb_#C2
	STY cvb_#C2+1
	; 				IF ABS(#c2) < 36 THEN
	JSR _abs16
	SEC
	SBC #36
	TYA
	SBC #0
	BCS.L cv416
	; 					diek = 1: RETURN		' v0.15: era GOTO player_dies (fora de proc nao pode!)
	LDA #1
	STA cvb_DIEK
	RTS
	; 				END IF
cv416:
	; 			END IF
cv415:
	; 		END IF
cv411:
	; 		' Levou tiro?
	; 		FOR d = 0 TO 4
	LDA #0
	STA cvb_D
cv417:
	; 			IF bty(d) <> 0 THEN
	LDA #array_BTY
	CLC
	ADC cvb_D
	TAX
	LDA #array_BTY>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	CMP #0
	BEQ.L cv418
	; 				e = 72 + boff
	LDA cvb_BOFF
	CLC
	ADC #72
	STA cvb_E
	; 				e2 = 168 + boff
	LDA cvb_BOFF
	CLC
	ADC #168
	STA cvb_E2
	; 				IF btx(d) + 6 > e AND btx(d) < e2 THEN
	LDA cvb_E
	TAX
	AND #128
	BPL cv420
	LDA #255
cv420:
	TAY
	TXA
	TAX
	TYA
	EOR #128
	TAY
	TXA
	PHA
	TYA
	PHA
	LDA #array_BTX
	CLC
	ADC cvb_D
	TAX
	LDA #array_BTX>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	LDY #0
	CLC
	ADC #6
	TAX
	TYA
	ADC #0
	TAY
	TXA
	TAX
	TYA
	EOR #128
	TAY
	TXA
	STA temp
	STY temp+1
	PLA
	TAY
	PLA
	SEC
	SBC temp
	TYA
	SBC temp+1
	LDA #255
	ADC #0
	PHA
	LDA pointer
	LDY pointer+1
	JSR _peek8
	CMP cvb_E2
	LDA #255
	ADC #0
	STA temp
	PLA
	AND temp
	BEQ.L cv419
	; 					IF bty(d) + 8 > 24 AND bty(d) < 88 THEN
	LDA #array_BTY
	CLC
	ADC cvb_D
	TAX
	LDA #array_BTY>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	CMP #88
	LDA #255
	ADC #0
	STA temp
	LDA pointer
	LDY pointer+1
	JSR _peek8
	LDY #0
	CLC
	ADC #8
	TAX
	TYA
	ADC #0
	TAY
	TXA
	SEC
	SBC #25
	TYA
	SBC #0
	LDA #255
	ADC #0
	EOR #255
	AND temp
	BEQ.L cv421
	; 						bty(d) = 0
	LDA pointer
	LDY pointer+1
	STA temp
	STY temp+1
	LDA #0
	TAY
	STA (temp),Y
	; 						SPRITE 16 + d,$f0,0,0,0
	LDA cvb_D
	CLC
	ADC #16
	PHA
	LDA #240
	STA sprite_data
	TYA
	STA sprite_data+3
	STA sprite_data+1
	STA sprite_data+2
	PLA
	JSR update_sprite
	; 						mpt = 6				' faisca no impacto
	LDA #6
	STA cvb_MPT
	; 						mpx = btx(d) - 3
	LDA #array_BTX
	CLC
	ADC cvb_D
	TAX
	LDA #array_BTX>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	SEC
	SBC #3
	STA cvb_MPX
	; 						mpy = bty(d)
	LDA #array_BTY
	CLC
	ADC cvb_D
	TAX
	LDA #array_BTY>>8
	ADC #0
	TAY
	TXA
	JSR _peek8
	STA cvb_MPY
	; 						bshp = bshp - 1
	DEC cvb_BSHP
	; 						#pop = 4
	LDA #4
	LDY #0
	STA cvb_#POP
	STY cvb_#POP+1
	; 						IF bshp = 0 THEN GOSUB boss_kill
	LDA cvb_BSHP
	BNE.L cv422
	JSR cvb_BOSS_KILL
cv422:
	; 						d = 5
	LDA #5
	STA cvb_D
	; 					END IF
cv421:
	; 				END IF
cv419:
	; 			END IF
cv418:
	; 		NEXT d
	INC cvb_D
	LDA cvb_D
	CMP #5
	BCC.L cv417
	; 	END
	RTS
	; 
	; 
	; 
	; 	' v0.16: SPLASH FALCON SOFT. CHR-ROM pagina 1 via POKE $1C,$20 (BANKSEL
	; 	' bits 5-6 do CHR-RAM; o NMI restaura ORA CHRRAM_BANK a cada frame).
	; 	' Logo 128x80 (tiles 96-181) centralizada + "apresenta" (tiles 182-188,
	; 	' glifos da fonte CVBasic). Fade por PALETTE CYCLING em $3F02/$3F03
	; 	' (7 passos x 4 frames). Qualquer botao corta DIRETO p/ o titulo;
	; 	' senao, ~3.4s e sai com o mesmo fade suave.
	; falcon_splash: PROCEDURE
cvb_FALCON_SPLASH:
	; 	POKE $1C,$20
	LDA #32
	PHA
	LDA #28
	LDY #0
	STA temp
	STY temp+1
	PLA
	STA (temp),Y
	; 	SCREEN DISABLE
	JSR DISSCR
	; 	CLS
	JSR cls
	; 	RESTORE falcon_map
	LDA #cvb_FALCON_MAP
	LDY #cvb_FALCON_MAP>>8
	STA read_pointer
	STY read_pointer+1
	; 	FOR r = 0 TO 159
	LDA #0
	STA cvb_R
cv423:
	; 		READ BYTE e
	JSR _read8
	STA cvb_E
	; 		IF e THEN
	CMP #0
	BEQ.L cv424
	; 			#tw = r / 16 + 9
	LDA cvb_R
	LDY #0
	LDX #16
	STX temp
	LDX #0
	STX temp+1
	JSR _div16
	CLC
	ADC #9
	TAX
	TYA
	ADC #0
	TAY
	TXA
	STA cvb_#TW
	STY cvb_#TW+1
	; 			#tw = #tw * 32
	STY temp
	ASL A
	ROL temp
	ASL A
	ROL temp
	ASL A
	ROL temp
	ASL A
	ROL temp
	ASL A
	ROL temp
	LDY temp
	STA cvb_#TW
	STY cvb_#TW+1
	; 			e2 = r AND 15
	LDA cvb_R
	AND #15
	STA cvb_E2
	; 			#tw = #tw + e2 + 8
	LDA cvb_#TW
	CLC
	ADC cvb_E2
	TAX
	TYA
	ADC #0
	TAY
	TXA
	CLC
	ADC #8
	TAX
	TYA
	ADC #0
	TAY
	TXA
	STA cvb_#TW
	STY cvb_#TW+1
	; 			VPOKE $2000 + #tw, e
	LDA cvb_E
	PHA
	LDA cvb_#TW
	CLC
	TAX
	TYA
	ADC #32
	TAY
	TXA
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 		END IF
cv424:
	; 	NEXT r
	INC cvb_R
	LDA cvb_R
	CMP #160
	BCC.L cv423
	; 	RESTORE falcon_txt
	LDA #cvb_FALCON_TXT
	LDY #cvb_FALCON_TXT>>8
	STA read_pointer
	STY read_pointer+1
	; 	FOR r = 0 TO 8
	LDA #0
	STA cvb_R
cv425:
	; 		READ BYTE e
	JSR _read8
	STA cvb_E
	; 		VPOKE $2000 + 651 + r, e
	PHA
	LDA cvb_R
	LDY #0
	CLC
	ADC #139
	TAX
	TYA
	ADC #34
	TAY
	TXA
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	NEXT r
	INC cvb_R
	LDA cvb_R
	CMP #9
	BCC.L cv425
	; 	VPOKE $3F00,$0F
	LDA #15
	PHA
	LDA #0
	LDY #63
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $3F01,$0F
	LDA #15
	PHA
	LDA #1
	LDY #63
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $3F02,$0F
	LDA #15
	PHA
	LDA #2
	LDY #63
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $3F03,$0F
	LDA #15
	PHA
	LDA #3
	LDY #63
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	WAIT
	JSR wait
	; 	SCREEN ENABLE
	JSR ENASCR
	; 	RESTORE fade_tbl
	LDA #cvb_FADE_TBL
	LDY #cvb_FADE_TBL>>8
	STA read_pointer
	STY read_pointer+1
	; 	FOR sk = 0 TO 1
	LDA #0
	STA cvb_SK
cv426:
	; 		FOR r = 0 TO 6
	LDA #0
	STA cvb_R
cv427:
	; 			READ BYTE e
	JSR _read8
	STA cvb_E
	; 			READ BYTE e2
	JSR _read8
	STA cvb_E2
	; 			VPOKE $3F02,e
	LDA cvb_E
	PHA
	LDA #2
	LDY #63
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 			VPOKE $3F03,e2
	LDA cvb_E2
	PHA
	LDA #3
	LDY #63
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 			FOR q = 0 TO 3
	LDA #0
	STA cvb_Q
cv428:
	; 				WAIT
	JSR wait
	; 				IF CONT1.KEY = 11 THEN GOTO fs_fim
	LDA key1_data
	CMP #11
	BNE.L cv429
	JMP cvb_FS_FIM
cv429:
	; 				IF CONT1.BUTTON THEN GOTO fs_fim
	LDA joy1_data
	AND #64
	BEQ.L cv430
	JMP cvb_FS_FIM
cv430:
	; 			NEXT q
	INC cvb_Q
	LDA cvb_Q
	CMP #4
	BCC.L cv428
	; 		NEXT r
	INC cvb_R
	LDA cvb_R
	CMP #7
	BCC.L cv427
	; 		IF sk = 0 THEN
	LDA cvb_SK
	BNE.L cv431
	; 			' hold ~2.5s com a logo acesa
	; 			FOR q = 0 TO 149
	LDA #0
	STA cvb_Q
cv432:
	; 				WAIT
	JSR wait
	; 				IF CONT1.KEY = 11 THEN GOTO fs_fim
	LDA key1_data
	CMP #11
	BNE.L cv433
	JMP cvb_FS_FIM
cv433:
	; 				IF CONT1.BUTTON THEN GOTO fs_fim
	LDA joy1_data
	AND #64
	BEQ.L cv434
	JMP cvb_FS_FIM
cv434:
	; 			NEXT q
	INC cvb_Q
	LDA cvb_Q
	CMP #150
	BCC.L cv432
	; 			RESTORE fade_tbl_out
	LDA #cvb_FADE_TBL_OUT
	LDY #cvb_FADE_TBL_OUT>>8
	STA read_pointer
	STY read_pointer+1
	; 		END IF
cv431:
	; 	NEXT sk
	INC cvb_SK
	LDA cvb_SK
	CMP #2
	BCC.L cv426
	; fs_fim:
cvb_FS_FIM:
	; 	SCREEN DISABLE
	JSR DISSCR
	; 	POKE $1C,$00
	LDA #0
	PHA
	LDA #28
	LDY #0
	STA temp
	STY temp+1
	PLA
	STA (temp),Y
	; 	WAIT
	JSR wait
	; 	END
	RTS
	; 
	; 	'
	; 	' v0.18: CARTAO DE FASE — tela preta, texto central, entra em fade
	; 	' (palette cycling, mesma rampa da Falcon), sai com START ou sozinha
	; 	' (~4s). Texto usa pal0/cor3: attrs zerados pelo CLS, nada mais p/ setar.
	; 	'
	; title_idle_wait: PROCEDURE
cvb_TITLE_IDLE_WAIT:
	; 	#bo = 0
	LDA #0
	TAY
	STA cvb_#BO
	STY cvb_#BO+1
	; 	sk = 0
	STA cvb_SK
	; title_idle_loop:
cvb_TITLE_IDLE_LOOP:
	; 	WAIT
	JSR wait
	; 	IF (FRAME AND 16) = 0 THEN
	LDA frame
	LDY frame+1
	AND #16
	LDY #0
	STY temp
	ORA temp
	BNE.L cv435
	; 		PRINT AT 714,"APERTE START"
	JSR print_string_cursor_constant
	DB $ca,$02,$0c
	DB $41,$50,$45,$52,$54,$45,$20,$53
	DB $54,$41,$52,$54
	; 	ELSE
	JMP cv436
cv435:
	; 		PRINT AT 714,"            "
	JSR print_string_cursor_constant
	DB $ca,$02,$0c
	DB $20,$20,$20,$20,$20,$20,$20,$20
	DB $20,$20,$20,$20
	; 	END IF
cv436:
	; 	IF CONT1.KEY = 11 THEN GOTO title_idle_done
	LDA key1_data
	CMP #11
	BNE.L cv437
	JMP cvb_TITLE_IDLE_DONE
cv437:
	; 	IF CONT1.BUTTON THEN GOTO title_idle_done
	LDA joy1_data
	AND #64
	BEQ.L cv438
	JMP cvb_TITLE_IDLE_DONE
cv438:
	; 	#bo = #bo + 1
	INC cvb_#BO
	BNE cv439
	INC cvb_#BO+1
cv439:
	; 	IF #bo < 900 THEN GOTO title_idle_loop
	LDA cvb_#BO
	LDY cvb_#BO+1
	SEC
	SBC #132
	TYA
	SBC #3
	BCS.L cv440
	JMP cvb_TITLE_IDLE_LOOP
cv440:
	; 	' Quinze segundos sem START: historia; ao voltar, o banco 0 faz reset completo.
	; 	GOSUB history_screen
	JSR cvb_HISTORY_SCREEN
	; 	sk = 1
	LDA #1
	STA cvb_SK
	; title_idle_done:
cvb_TITLE_IDLE_DONE:
	; 	END
	RTS
	; 
	; stage_card: PROCEDURE
cvb_STAGE_CARD:
	; sc_release:				' espera soltar o START do game over/titulo
cvb_SC_RELEASE:
	; 	WAIT
	JSR wait
	; 	IF CONT1.KEY = 11 THEN GOTO sc_release
	LDA key1_data
	CMP #11
	BNE.L cv441
	JMP cvb_SC_RELEASE
cv441:
	; 	IF CONT1.BUTTON THEN GOTO sc_release
	LDA joy1_data
	AND #64
	BEQ.L cv442
	JMP cvb_SC_RELEASE
cv442:
	; 	SCREEN DISABLE
	JSR DISSCR
	; 	CLS
	JSR cls
	; 	SCROLL 0,0
	LDA #0
	TAY
	STA scroll_x
	STY scroll_x+1
	STA scroll_y
	STY scroll_y+1
	; 	PRINT AT 460,"FASE 0",<1>fase	' v0.28: cartao generico p/ as 5 fases
	JSR print_string_cursor_constant
	DB $cc,$01,$06
	DB $46,$41,$53,$45,$20,$30
	LDA cvb_FASE
	LDY #0
	SEI
	LDX #2
	STX temp
	LDX #48
	STX temp+1
	JSR print_number1
	; 	IF fase = 1 THEN PRINT AT 514,"A CAMINHO DO PLANETA DE FOGO"
	LDA cvb_FASE
	CMP #1
	BNE.L cv443
	JSR print_string_cursor_constant
	DB $02,$02,$1c
	DB $41,$20,$43,$41,$4d,$49,$4e,$48
	DB $4f,$20,$44,$4f,$20,$50,$4c,$41
	DB $4e,$45,$54,$41,$20,$44,$45,$20
	DB $46,$4f,$47,$4f
cv443:
	; 	IF fase = 2 THEN PRINT AT 519,"O PLANETA DE FOGO"
	LDA cvb_FASE
	CMP #2
	BNE.L cv444
	JSR print_string_cursor_constant
	DB $07,$02,$11
	DB $4f,$20,$50,$4c,$41,$4e,$45,$54
	DB $41,$20,$44,$45,$20,$46,$4f,$47
	DB $4f
cv444:
	; 	IF fase = 3 THEN
	LDA cvb_FASE
	CMP #3
	BNE.L cv445
	; 		PRINT AT 516,"O CINTURAO DE ASTEROIDES"
	JSR print_string_cursor_constant
	DB $04,$02,$18
	DB $4f,$20,$43,$49,$4e,$54,$55,$52
	DB $41,$4f,$20,$44,$45,$20,$41,$53
	DB $54,$45,$52,$4f,$49,$44,$45,$53
	; 		VPOKE $2000 + 492,26	' til sobre o A de CINTURAO
	LDA #26
	PHA
	LDA #236
	LDY #33
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 		VPOKE $2000 + 503,27	' agudo sobre o O de ASTEROIDES
	LDA #27
	PHA
	LDA #247
	LDY #33
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	END IF
cv445:
	; 	IF fase = 4 THEN
	LDA cvb_FASE
	CMP #4
	BNE.L cv446
	; 		PRINT AT 518,"O GERADOR DE ESCUDOS"
	JSR print_string_cursor_constant
	DB $06,$02,$14
	DB $4f,$20,$47,$45,$52,$41,$44,$4f
	DB $52,$20,$44,$45,$20,$45,$53,$43
	DB $55,$44,$4f,$53
	; 		PRINT AT 582,"DO PLANETA ATLANTIS"
	JSR print_string_cursor_constant
	DB $46,$02,$13
	DB $44,$4f,$20,$50,$4c,$41,$4e,$45
	DB $54,$41,$20,$41,$54,$4c,$41,$4e
	DB $54,$49,$53
	; 	END IF
cv446:
	; 	IF fase = 5 THEN PRINT AT 516,"A BATALHA FINAL COM GORF"
	LDA cvb_FASE
	CMP #5
	BNE.L cv447
	JSR print_string_cursor_constant
	DB $04,$02,$18
	DB $41,$20,$42,$41,$54,$41,$4c,$48
	DB $41,$20,$46,$49,$4e,$41,$4c,$20
	DB $43,$4f,$4d,$20,$47,$4f,$52,$46
cv447:
	; 	VPOKE $3F01,$0F		' texto invisivel: cores do pal0 em preto
	LDA #15
	PHA
	LDA #1
	LDY #63
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $3F02,$0F
	LDA #15
	PHA
	LDA #2
	LDY #63
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $3F03,$0F
	LDA #15
	PHA
	LDA #3
	LDY #63
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	WAIT
	JSR wait
	; 	SCREEN ENABLE
	JSR ENASCR
	; 	RESTORE fade_tbl
	LDA #cvb_FADE_TBL
	LDY #cvb_FADE_TBL>>8
	STA read_pointer
	STY read_pointer+1
	; 	FOR r = 0 TO 6			' fade-in
	LDA #0
	STA cvb_R
cv448:
	; 		READ BYTE e
	JSR _read8
	STA cvb_E
	; 		READ BYTE e		' (coluna "clara" da rampa)
	JSR _read8
	STA cvb_E
	; 		VPOKE $3F03,e
	PHA
	LDA #3
	LDY #63
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 		FOR q = 0 TO 3
	LDA #0
	STA cvb_Q
cv449:
	; 			WAIT
	JSR wait
	; 			IF CONT1.KEY = 11 THEN GOTO sc_fim
	LDA key1_data
	CMP #11
	BNE.L cv450
	JMP cvb_SC_FIM
cv450:
	; 			IF CONT1.BUTTON THEN GOTO sc_fim
	LDA joy1_data
	AND #64
	BEQ.L cv451
	JMP cvb_SC_FIM
cv451:
	; 		NEXT q
	INC cvb_Q
	LDA cvb_Q
	CMP #4
	BCC.L cv449
	; 	NEXT r
	INC cvb_R
	LDA cvb_R
	CMP #7
	BCC.L cv448
	; 	FOR q = 0 TO 239		' hold ~4s
	LDA #0
	STA cvb_Q
cv452:
	; 		WAIT
	JSR wait
	; 		IF CONT1.KEY = 11 THEN GOTO sc_fim
	LDA key1_data
	CMP #11
	BNE.L cv453
	JMP cvb_SC_FIM
cv453:
	; 		IF CONT1.BUTTON THEN GOTO sc_fim
	LDA joy1_data
	AND #64
	BEQ.L cv454
	JMP cvb_SC_FIM
cv454:
	; 	NEXT q
	INC cvb_Q
	LDA cvb_Q
	CMP #240
	BCC.L cv452
	; 	RESTORE fade_tbl_out		' fade-out so quando sai sozinha
	LDA #cvb_FADE_TBL_OUT
	LDY #cvb_FADE_TBL_OUT>>8
	STA read_pointer
	STY read_pointer+1
	; 	FOR r = 0 TO 6
	LDA #0
	STA cvb_R
cv455:
	; 		READ BYTE e
	JSR _read8
	STA cvb_E
	; 		READ BYTE e
	JSR _read8
	STA cvb_E
	; 		VPOKE $3F03,e
	PHA
	LDA #3
	LDY #63
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 		FOR q = 0 TO 3
	LDA #0
	STA cvb_Q
cv456:
	; 			WAIT
	JSR wait
	; 		NEXT q
	INC cvb_Q
	LDA cvb_Q
	CMP #4
	BCC.L cv456
	; 	NEXT r
	INC cvb_R
	LDA cvb_R
	CMP #7
	BCC.L cv455
	; sc_fim:
cvb_SC_FIM:
	; 	SCREEN DISABLE
	JSR DISSCR
	; 	WAIT
	JSR wait
	; 	END
	RTS
	; 
	; 	'
	; 	' v0.18: desenha a tela de GAME OVER apagada (cores em preto), escreve
	; 	' tudo invisivel e acende com FADE por palette cycling (rampa da Falcon)
	; 	'
	; clear_nts: PROCEDURE
cvb_CLEAR_NTS:
	; 	' v0.19.2: zera $2000/$2800 p/ a volta da fase 1 via SELECT
	; 	' CUIDADO: FOR de 8 bits com TO 255/1023 nunca termina (o contador
	; 	' embrulha em 255->0 e BCS sempre salta = loop infinito! autopsia:
	; 	' boot travado em tela preta COM musica - NMI viva, cpu presa).
	; 	FOR w = 0 TO 15
	LDA #0
	STA cvb_W
cv457:
	; 		FOR i = 0 TO 63
	LDA #0
	STA cvb_I
cv458:
	; 			VPOKE $2000+w*64+i,0
	LDA #0
	PHA
	LDA cvb_W
	LDY #0
	STY temp
	ASL A
	ROL temp
	ASL A
	ROL temp
	ASL A
	ROL temp
	ASL A
	ROL temp
	ASL A
	ROL temp
	ASL A
	ROL temp
	LDY temp
	CLC
	TAX
	TYA
	ADC #32
	TAY
	TXA
	CLC
	ADC cvb_I
	TAX
	TYA
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 			IF (i AND 15) = 15 THEN WAIT	' drena o PPUBUF (16 writes/frame)
	LDA cvb_I
	AND #15
	CMP #15
	BNE.L cv459
	JSR wait
cv459:
	; 		NEXT i
	INC cvb_I
	LDA cvb_I
	CMP #64
	BCC.L cv458
	; 	NEXT w
	INC cvb_W
	LDA cvb_W
	CMP #16
	BCC.L cv457
	; 	FOR w = 0 TO 15
	LDA #0
	STA cvb_W
cv460:
	; 		FOR i = 0 TO 63
	LDA #0
	STA cvb_I
cv461:
	; 			VPOKE $2800+w*64+i,0
	LDA #0
	PHA
	LDA cvb_W
	LDY #0
	STY temp
	ASL A
	ROL temp
	ASL A
	ROL temp
	ASL A
	ROL temp
	ASL A
	ROL temp
	ASL A
	ROL temp
	ASL A
	ROL temp
	LDY temp
	CLC
	TAX
	TYA
	ADC #40
	TAY
	TXA
	CLC
	ADC cvb_I
	TAX
	TYA
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 			IF (i AND 15) = 15 THEN WAIT
	LDA cvb_I
	AND #15
	CMP #15
	BNE.L cv462
	JSR wait
cv462:
	; 		NEXT i
	INC cvb_I
	LDA cvb_I
	CMP #64
	BCC.L cv461
	; 	NEXT w
	INC cvb_W
	LDA cvb_W
	CMP #16
	BCC.L cv460
	; 	FOR w = 0 TO 15		' $2400 tb: canhoes/streams pisam na 3a pagina
	LDA #0
	STA cvb_W
cv463:
	; 		FOR i = 0 TO 63
	LDA #0
	STA cvb_I
cv464:
	; 			VPOKE $2400+w*64+i,0
	LDA #0
	PHA
	LDA cvb_W
	LDY #0
	STY temp
	ASL A
	ROL temp
	ASL A
	ROL temp
	ASL A
	ROL temp
	ASL A
	ROL temp
	ASL A
	ROL temp
	ASL A
	ROL temp
	LDY temp
	CLC
	TAX
	TYA
	ADC #36
	TAY
	TXA
	CLC
	ADC cvb_I
	TAX
	TYA
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 			IF (i AND 15) = 15 THEN WAIT
	LDA cvb_I
	AND #15
	CMP #15
	BNE.L cv465
	JSR wait
cv465:
	; 		NEXT i
	INC cvb_I
	LDA cvb_I
	CMP #64
	BCC.L cv464
	; 	NEXT w
	INC cvb_W
	LDA cvb_W
	CMP #16
	BCC.L cv463
	; END
	RTS
	; 
	; go_draw: PROCEDURE
cvb_GO_DRAW:
	; 	VPOKE $3F01,$0F		' paletas do texto em preto (invisivel)
	LDA #15
	PHA
	LDA #1
	LDY #63
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $3F02,$0F
	LDA #15
	PHA
	LDA #2
	LDY #63
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $3F03,$0F
	LDA #15
	PHA
	LDA #3
	LDY #63
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $3F05,$0F
	LDA #15
	PHA
	LDA #5
	LDY #63
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $3F06,$0F
	LDA #15
	PHA
	LDA #6
	LDY #63
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $3F07,$0F
	LDA #15
	PHA
	LDA #7
	LDY #63
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $214B,32	' "GAMEOVER" junto, centralizado (col 12-19)
	LDA #32
	PHA
	LDA #75
	LDY #33
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $214C,214
	LDA #214
	PHA
	LDA #76
	LDY #33
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $214D,215
	LDA #215
	PHA
	LDA #77
	LDY #33
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $214E,216
	LDA #216
	PHA
	LDA #78
	LDY #33
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $214F,217
	LDA #217
	PHA
	LDA #79
	LDY #33
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $2150,218
	LDA #218
	PHA
	LDA #80
	LDY #33
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $2151,219
	LDA #219
	PHA
	LDA #81
	LDY #33
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $2152,220
	LDA #220
	PHA
	LDA #82
	LDY #33
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $2153,221
	LDA #221
	PHA
	LDA #83
	LDY #33
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $2154,32
	LDA #32
	PHA
	LDA #84
	LDY #33
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	PRINT AT 391,"PONTOS: ",<1>s0,<1>s1,<1>s2,<1>s3,<1>s4
	JSR print_string_cursor_constant
	DB $87,$01,$08
	DB $50,$4f,$4e,$54,$4f,$53,$3a,$20
	LDA cvb_S0
	LDY #0
	SEI
	LDX #2
	STX temp
	LDX #48
	STX temp+1
	JSR print_number1
	LDA cvb_S1
	LDY #0
	SEI
	LDX #2
	STX temp
	LDX #48
	STX temp+1
	JSR print_number1
	LDA cvb_S2
	LDY #0
	SEI
	LDX #2
	STX temp
	LDX #48
	STX temp+1
	JSR print_number1
	LDA cvb_S3
	LDY #0
	SEI
	LDX #2
	STX temp
	LDX #48
	STX temp+1
	JSR print_number1
	LDA cvb_S4
	LDY #0
	SEI
	LDX #2
	STX temp
	LDX #48
	STX temp+1
	JSR print_number1
	; 	' 1 linha de espaco entre frases: GO linha10, PONTOS 12, ONDA 14, START 16
	; 	WAIT
	JSR wait
	; 	RESTORE fade_tbl		' fade-in (texto -> cor 3 de pal0 E pal1)
	LDA #cvb_FADE_TBL
	LDY #cvb_FADE_TBL>>8
	STA read_pointer
	STY read_pointer+1
	; 	FOR r = 0 TO 6
	LDA #0
	STA cvb_R
cv466:
	; 		READ BYTE e
	JSR _read8
	STA cvb_E
	; 		READ BYTE e		' (coluna "clara" da rampa)
	JSR _read8
	STA cvb_E
	; 		VPOKE $3F03,e	' ONDA linha14 e APERTE linha16 caem em pal0!
	PHA
	LDA #3
	LDY #63
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 		VPOKE $3F07,e
	LDA cvb_E
	PHA
	LDA #7
	LDY #63
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 		FOR q = 0 TO 3
	LDA #0
	STA cvb_Q
cv467:
	; 			WAIT
	JSR wait
	; 		NEXT q
	INC cvb_Q
	LDA cvb_Q
	CMP #4
	BCC.L cv467
	; 	NEXT r
	INC cvb_R
	LDA cvb_R
	CMP #7
	BCC.L cv466
	; 	END
	RTS
	; 
	; 	'
	; 	' v0.19: telas de transicao de fase (mesmo estilo do stage_card)
	; 	'
	; fase_completa: PROCEDURE
cvb_FASE_COMPLETA:
	; fc_release:
cvb_FC_RELEASE:
	; 	WAIT
	JSR wait
	; 	IF CONT1.KEY = 11 THEN GOTO fc_release
	LDA key1_data
	CMP #11
	BNE.L cv468
	JMP cvb_FC_RELEASE
cv468:
	; 	IF CONT1.BUTTON THEN GOTO fc_release
	LDA joy1_data
	AND #64
	BEQ.L cv469
	JMP cvb_FC_RELEASE
cv469:
	; 	SCREEN DISABLE
	JSR DISSCR
	; 	FOR c = 0 TO 63		' tela limpa: esconde sprites (HUD + nave)
	LDA #0
	STA cvb_C
cv470:
	; 		SPRITE c,$f0,0,0,0
	LDA cvb_C
	PHA
	LDA #240
	STA sprite_data
	LDA #0
	STA sprite_data+3
	STA sprite_data+1
	STA sprite_data+2
	PLA
	JSR update_sprite
	; 	NEXT c
	INC cvb_C
	LDA cvb_C
	CMP #64
	BCC.L cv470
	; 	CLS
	JSR cls
	; 	SCROLL 0,0
	LDA #0
	TAY
	STA scroll_x
	STY scroll_x+1
	STA scroll_y
	STY scroll_y+1
	; 	PRINT AT 392,"FASE 0",<1>fase," COMPLETA"	' v0.28: generico
	JSR print_string_cursor_constant
	DB $88,$01,$06
	DB $46,$41,$53,$45,$20,$30
	LDA cvb_FASE
	LDY #0
	SEI
	LDX #2
	STX temp
	LDX #48
	STX temp+1
	JSR print_number1
	JSR print_string
	DB $09
	DB $20,$43,$4f,$4d,$50,$4c,$45,$54
	DB $41
	; 	PRINT AT 455,"PONTUACAO: ",<1>s0,<1>s1,<1>s2,<1>s3,<1>s4
	JSR print_string_cursor_constant
	DB $c7,$01,$0b
	DB $50,$4f,$4e,$54,$55,$41,$43,$41
	DB $4f,$3a,$20
	LDA cvb_S0
	LDY #0
	SEI
	LDX #2
	STX temp
	LDX #48
	STX temp+1
	JSR print_number1
	LDA cvb_S1
	LDY #0
	SEI
	LDX #2
	STX temp
	LDX #48
	STX temp+1
	JSR print_number1
	LDA cvb_S2
	LDY #0
	SEI
	LDX #2
	STX temp
	LDX #48
	STX temp+1
	JSR print_number1
	LDA cvb_S3
	LDY #0
	SEI
	LDX #2
	STX temp
	LDX #48
	STX temp+1
	JSR print_number1
	LDA cvb_S4
	LDY #0
	SEI
	LDX #2
	STX temp
	LDX #48
	STX temp+1
	JSR print_number1
	; 	PRINT AT 487,"VIDAS: ",<1>li
	JSR print_string_cursor_constant
	DB $e7,$01,$07
	DB $56,$49,$44,$41,$53,$3a,$20
	LDA cvb_LI
	LDY #0
	SEI
	LDX #2
	STX temp
	LDX #48
	STX temp+1
	JSR print_number1
	; 	VPOKE $3F01,$0F
	LDA #15
	PHA
	LDA #1
	LDY #63
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $3F02,$0F
	LDA #15
	PHA
	LDA #2
	LDY #63
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $3F03,$0F
	LDA #15
	PHA
	LDA #3
	LDY #63
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	WAIT
	JSR wait
	; 	SCREEN ENABLE
	JSR ENASCR
	; 	RESTORE fade_tbl
	LDA #cvb_FADE_TBL
	LDY #cvb_FADE_TBL>>8
	STA read_pointer
	STY read_pointer+1
	; 	FOR r = 0 TO 6
	LDA #0
	STA cvb_R
cv471:
	; 		READ BYTE e
	JSR _read8
	STA cvb_E
	; 		READ BYTE e
	JSR _read8
	STA cvb_E
	; 		VPOKE $3F03,e
	PHA
	LDA #3
	LDY #63
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 		FOR q = 0 TO 3
	LDA #0
	STA cvb_Q
cv472:
	; 			WAIT
	JSR wait
	; 			IF CONT1.KEY = 11 THEN GOTO fc_fim
	LDA key1_data
	CMP #11
	BNE.L cv473
	JMP cvb_FC_FIM
cv473:
	; 			IF CONT1.BUTTON THEN GOTO fc_fim
	LDA joy1_data
	AND #64
	BEQ.L cv474
	JMP cvb_FC_FIM
cv474:
	; 		NEXT q
	INC cvb_Q
	LDA cvb_Q
	CMP #4
	BCC.L cv472
	; 	NEXT r
	INC cvb_R
	LDA cvb_R
	CMP #7
	BCC.L cv471
	; 	FOR q = 0 TO 209
	LDA #0
	STA cvb_Q
cv475:
	; 		WAIT
	JSR wait
	; 		IF CONT1.KEY = 11 THEN GOTO fc_fim
	LDA key1_data
	CMP #11
	BNE.L cv476
	JMP cvb_FC_FIM
cv476:
	; 		IF CONT1.BUTTON THEN GOTO fc_fim
	LDA joy1_data
	AND #64
	BEQ.L cv477
	JMP cvb_FC_FIM
cv477:
	; 	NEXT q
	INC cvb_Q
	LDA cvb_Q
	CMP #210
	BCC.L cv475
	; 	RESTORE fade_tbl_out
	LDA #cvb_FADE_TBL_OUT
	LDY #cvb_FADE_TBL_OUT>>8
	STA read_pointer
	STY read_pointer+1
	; 	FOR r = 0 TO 6
	LDA #0
	STA cvb_R
cv478:
	; 		READ BYTE e
	JSR _read8
	STA cvb_E
	; 		READ BYTE e
	JSR _read8
	STA cvb_E
	; 		VPOKE $3F03,e
	PHA
	LDA #3
	LDY #63
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 		FOR q = 0 TO 3
	LDA #0
	STA cvb_Q
cv479:
	; 			WAIT
	JSR wait
	; 		NEXT q
	INC cvb_Q
	LDA cvb_Q
	CMP #4
	BCC.L cv479
	; 	NEXT r
	INC cvb_R
	LDA cvb_R
	CMP #7
	BCC.L cv478
	; fc_fim:
cvb_FC_FIM:
	; 	SCREEN DISABLE
	JSR DISSCR
	; 	WAIT
	JSR wait
	; 	END
	RTS
	; 
	; 	'
	; 	' v0.28: FIM DE JOGO - 3 telas (vitoria, creditos, THE END?)
	; 	' no mesmo estilo dos cartoes (fade por palette cycling, START pula)
	; 	'
	; end_vitoria: PROCEDURE
cvb_END_VITORIA:
	; ev_release:
cvb_EV_RELEASE:
	; 	WAIT
	JSR wait
	; 	IF CONT1.KEY = 11 THEN GOTO ev_release
	LDA key1_data
	CMP #11
	BNE.L cv480
	JMP cvb_EV_RELEASE
cv480:
	; 	IF CONT1.BUTTON THEN GOTO ev_release
	LDA joy1_data
	AND #64
	BEQ.L cv481
	JMP cvb_EV_RELEASE
cv481:
	; 	SCREEN DISABLE
	JSR DISSCR
	; 	FOR c = 0 TO 63		' tela limpa: esconde sprites (HUD + nave)
	LDA #0
	STA cvb_C
cv482:
	; 		SPRITE c,$f0,0,0,0
	LDA cvb_C
	PHA
	LDA #240
	STA sprite_data
	LDA #0
	STA sprite_data+3
	STA sprite_data+1
	STA sprite_data+2
	PLA
	JSR update_sprite
	; 	NEXT c
	INC cvb_C
	LDA cvb_C
	CMP #64
	BCC.L cv482
	; 	CLS
	JSR cls
	; 	SCROLL 0,0
	LDA #0
	TAY
	STA scroll_x
	STY scroll_x+1
	STA scroll_y
	STY scroll_y+1
	; 	PRINT AT 196,"VOCE CONSEGUIU DESTRUIR"
	JSR print_string_cursor_constant
	DB $c4,$00,$17
	DB $56,$4f,$43,$45,$20,$43,$4f,$4e
	DB $53,$45,$47,$55,$49,$55,$20,$44
	DB $45,$53,$54,$52,$55,$49,$52
	; 	PRINT AT 264,"O IMPERIO GORF E"
	JSR print_string_cursor_constant
	DB $08,$01,$10
	DB $4f,$20,$49,$4d,$50,$45,$52,$49
	DB $4f,$20,$47,$4f,$52,$46,$20,$45
	; 	PRINT AT 327,"SALVAR A GALAXIA!"
	JSR print_string_cursor_constant
	DB $47,$01,$11
	DB $53,$41,$4c,$56,$41,$52,$20,$41
	DB $20,$47,$41,$4c,$41,$58,$49,$41
	DB $21
	; 	PRINT AT 454,"PARABENS GUERREIRO!"
	JSR print_string_cursor_constant
	DB $c6,$01,$13
	DB $50,$41,$52,$41,$42,$45,$4e,$53
	DB $20,$47,$55,$45,$52,$52,$45,$49
	DB $52,$4f,$21
	; 	PRINT AT 517,"MAS A LUTA ESTA LONGE"
	JSR print_string_cursor_constant
	DB $05,$02,$15
	DB $4d,$41,$53,$20,$41,$20,$4c,$55
	DB $54,$41,$20,$45,$53,$54,$41,$20
	DB $4c,$4f,$4e,$47,$45
	; 	PRINT AT 586,"DE TERMINAR!"
	JSR print_string_cursor_constant
	DB $4a,$02,$0c
	DB $44,$45,$20,$54,$45,$52,$4d,$49
	DB $4e,$41,$52,$21
	; 	VPOKE $2000 + 307,27	' agudo na linha acima do A de GALAXIA
	LDA #27
	PHA
	LDA #51
	LDY #33
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $2000 + 427,27	' agudo na linha acima do E de PARABENS
	LDA #27
	PHA
	LDA #171
	LDY #33
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $2000 + 499,27	' agudo na linha acima do A de ESTA
	LDA #27
	PHA
	LDA #243
	LDY #33
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $3F01,$0F
	LDA #15
	PHA
	LDA #1
	LDY #63
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $3F02,$0F
	LDA #15
	PHA
	LDA #2
	LDY #63
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $3F03,$0F
	LDA #15
	PHA
	LDA #3
	LDY #63
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	WAIT
	JSR wait
	; 	SCREEN ENABLE
	JSR ENASCR
	; 	RESTORE fade_tbl
	LDA #cvb_FADE_TBL
	LDY #cvb_FADE_TBL>>8
	STA read_pointer
	STY read_pointer+1
	; 	FOR r = 0 TO 6
	LDA #0
	STA cvb_R
cv483:
	; 		READ BYTE e
	JSR _read8
	STA cvb_E
	; 		READ BYTE e
	JSR _read8
	STA cvb_E
	; 		VPOKE $3F03,e
	PHA
	LDA #3
	LDY #63
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 		FOR q = 0 TO 3
	LDA #0
	STA cvb_Q
cv484:
	; 			WAIT
	JSR wait
	; 			IF CONT1.KEY = 11 THEN GOTO ev_fim
	LDA key1_data
	CMP #11
	BNE.L cv485
	JMP cvb_EV_FIM
cv485:
	; 			IF CONT1.BUTTON THEN GOTO ev_fim
	LDA joy1_data
	AND #64
	BEQ.L cv486
	JMP cvb_EV_FIM
cv486:
	; 		NEXT q
	INC cvb_Q
	LDA cvb_Q
	CMP #4
	BCC.L cv484
	; 	NEXT r
	INC cvb_R
	LDA cvb_R
	CMP #7
	BCC.L cv483
	; 	' CVBasic counters are 8-bit: never use a FOR limit above 254.
	; 	' 2 x 135 frames = 270 frames (~4.5s), as intended.
	; 	FOR r = 0 TO 1
	LDA #0
	STA cvb_R
cv487:
	; 		FOR q = 0 TO 134
	LDA #0
	STA cvb_Q
cv488:
	; 			WAIT
	JSR wait
	; 			IF CONT1.KEY = 11 THEN GOTO ev_fim
	LDA key1_data
	CMP #11
	BNE.L cv489
	JMP cvb_EV_FIM
cv489:
	; 			IF CONT1.BUTTON THEN GOTO ev_fim
	LDA joy1_data
	AND #64
	BEQ.L cv490
	JMP cvb_EV_FIM
cv490:
	; 		NEXT q
	INC cvb_Q
	LDA cvb_Q
	CMP #135
	BCC.L cv488
	; 	NEXT r
	INC cvb_R
	LDA cvb_R
	CMP #2
	BCC.L cv487
	; 	RESTORE fade_tbl_out
	LDA #cvb_FADE_TBL_OUT
	LDY #cvb_FADE_TBL_OUT>>8
	STA read_pointer
	STY read_pointer+1
	; 	FOR r = 0 TO 6
	LDA #0
	STA cvb_R
cv491:
	; 		READ BYTE e
	JSR _read8
	STA cvb_E
	; 		READ BYTE e
	JSR _read8
	STA cvb_E
	; 		VPOKE $3F03,e
	PHA
	LDA #3
	LDY #63
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 		FOR q = 0 TO 3
	LDA #0
	STA cvb_Q
cv492:
	; 			WAIT
	JSR wait
	; 		NEXT q
	INC cvb_Q
	LDA cvb_Q
	CMP #4
	BCC.L cv492
	; 	NEXT r
	INC cvb_R
	LDA cvb_R
	CMP #7
	BCC.L cv491
	; ev_fim:
cvb_EV_FIM:
	; 	SCREEN DISABLE
	JSR DISSCR
	; 	WAIT
	JSR wait
	; 	END
	RTS
	; 
	; end_creditos: PROCEDURE
cvb_END_CREDITOS:
	; ec_release:
cvb_EC_RELEASE:
	; 	WAIT
	JSR wait
	; 	IF CONT1.KEY = 11 THEN GOTO ec_release
	LDA key1_data
	CMP #11
	BNE.L cv493
	JMP cvb_EC_RELEASE
cv493:
	; 	IF CONT1.BUTTON THEN GOTO ec_release
	LDA joy1_data
	AND #64
	BEQ.L cv494
	JMP cvb_EC_RELEASE
cv494:
	; 	' Cada pagina e fixa; nao existe mais scroll de nametable.
	; 	#fp = 3
	LDA #3
	LDY #0
	STA cvb_#FP
	STY cvb_#FP+1
	; 	GOSUB fixed_page_show
	JSR cvb_FIXED_PAGE_SHOW
	; 	IF sk <> 0 THEN GOTO ec_fim
	LDA cvb_SK
	BEQ.L cv495
	JMP cvb_EC_FIM
cv495:
	; 	#fp = 4
	LDA #4
	LDY #0
	STA cvb_#FP
	STY cvb_#FP+1
	; 	GOSUB fixed_page_show
	JSR cvb_FIXED_PAGE_SHOW
	; 	IF sk <> 0 THEN GOTO ec_fim
	LDA cvb_SK
	BEQ.L cv496
	JMP cvb_EC_FIM
cv496:
	; 	#fp = 5
	LDA #5
	LDY #0
	STA cvb_#FP
	STY cvb_#FP+1
	; 	GOSUB fixed_page_show
	JSR cvb_FIXED_PAGE_SHOW
	; ec_fim:
cvb_EC_FIM:
	; 	SCREEN DISABLE
	JSR DISSCR
	; 	POKE $1C,$00
	LDA #0
	PHA
	LDA #28
	LDY #0
	STA temp
	STY temp+1
	PLA
	STA (temp),Y
	; 	WAIT
	JSR wait
	; 	END
	RTS
	; 
	; end_theend: PROCEDURE
cvb_END_THEEND:
	; te_release:
cvb_TE_RELEASE:
	; 	WAIT
	JSR wait
	; 	IF CONT1.KEY = 11 THEN GOTO te_release
	LDA key1_data
	CMP #11
	BNE.L cv497
	JMP cvb_TE_RELEASE
cv497:
	; 	IF CONT1.BUTTON THEN GOTO te_release
	LDA joy1_data
	AND #64
	BEQ.L cv498
	JMP cvb_TE_RELEASE
cv498:
	; 	SCREEN DISABLE
	JSR DISSCR
	; 	FOR c = 0 TO 63
	LDA #0
	STA cvb_C
cv499:
	; 		SPRITE c,$f0,0,0,0
	LDA cvb_C
	PHA
	LDA #240
	STA sprite_data
	LDA #0
	STA sprite_data+3
	STA sprite_data+1
	STA sprite_data+2
	PLA
	JSR update_sprite
	; 	NEXT c
	INC cvb_C
	LDA cvb_C
	CMP #64
	BCC.L cv499
	; 	CLS
	JSR cls
	; 	SCROLL 0,0
	LDA #0
	TAY
	STA scroll_x
	STY scroll_x+1
	STA scroll_y
	STY scroll_y+1
	; 	PRINT AT 460,"THE END?"
	JSR print_string_cursor_constant
	DB $cc,$01,$08
	DB $54,$48,$45,$20,$45,$4e,$44,$3f
	; 	VPOKE $3F01,$0F
	LDA #15
	PHA
	LDA #1
	LDY #63
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $3F02,$0F
	LDA #15
	PHA
	LDA #2
	LDY #63
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $3F03,$0F
	LDA #15
	PHA
	LDA #3
	LDY #63
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	WAIT
	JSR wait
	; 	SCREEN ENABLE
	JSR ENASCR
	; 	RESTORE fade_tbl
	LDA #cvb_FADE_TBL
	LDY #cvb_FADE_TBL>>8
	STA read_pointer
	STY read_pointer+1
	; 	FOR r = 0 TO 6
	LDA #0
	STA cvb_R
cv500:
	; 		READ BYTE e
	JSR _read8
	STA cvb_E
	; 		READ BYTE e
	JSR _read8
	STA cvb_E
	; 		VPOKE $3F03,e
	PHA
	LDA #3
	LDY #63
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 		FOR q = 0 TO 3
	LDA #0
	STA cvb_Q
cv501:
	; 			WAIT
	JSR wait
	; 			IF CONT1.KEY = 11 THEN GOTO te_fim
	LDA key1_data
	CMP #11
	BNE.L cv502
	JMP cvb_TE_FIM
cv502:
	; 			IF CONT1.BUTTON THEN GOTO te_fim
	LDA joy1_data
	AND #64
	BEQ.L cv503
	JMP cvb_TE_FIM
cv503:
	; 		NEXT q
	INC cvb_Q
	LDA cvb_Q
	CMP #4
	BCC.L cv501
	; 	NEXT r
	INC cvb_R
	LDA cvb_R
	CMP #7
	BCC.L cv500
	; 	' CVBasic counters are 8-bit: never use a FOR limit above 254.
	; 	' 2 x 135 frames = 270 frames (~4.5s), as intended.
	; 	FOR r = 0 TO 1
	LDA #0
	STA cvb_R
cv504:
	; 		FOR q = 0 TO 134
	LDA #0
	STA cvb_Q
cv505:
	; 			WAIT
	JSR wait
	; 			IF CONT1.KEY = 11 THEN GOTO te_fim
	LDA key1_data
	CMP #11
	BNE.L cv506
	JMP cvb_TE_FIM
cv506:
	; 			IF CONT1.BUTTON THEN GOTO te_fim
	LDA joy1_data
	AND #64
	BEQ.L cv507
	JMP cvb_TE_FIM
cv507:
	; 		NEXT q
	INC cvb_Q
	LDA cvb_Q
	CMP #135
	BCC.L cv505
	; 	NEXT r
	INC cvb_R
	LDA cvb_R
	CMP #2
	BCC.L cv504
	; 	RESTORE fade_tbl_out
	LDA #cvb_FADE_TBL_OUT
	LDY #cvb_FADE_TBL_OUT>>8
	STA read_pointer
	STY read_pointer+1
	; 	FOR r = 0 TO 6
	LDA #0
	STA cvb_R
cv508:
	; 		READ BYTE e
	JSR _read8
	STA cvb_E
	; 		READ BYTE e
	JSR _read8
	STA cvb_E
	; 		VPOKE $3F03,e
	PHA
	LDA #3
	LDY #63
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 		FOR q = 0 TO 3
	LDA #0
	STA cvb_Q
cv509:
	; 			WAIT
	JSR wait
	; 		NEXT q
	INC cvb_Q
	LDA cvb_Q
	CMP #4
	BCC.L cv509
	; 	NEXT r
	INC cvb_R
	LDA cvb_R
	CMP #7
	BCC.L cv508
	; te_fim:
cvb_TE_FIM:
	; 	SCREEN DISABLE
	JSR DISSCR
	; 	WAIT
	JSR wait
	; 	END
	RTS
	; 
	; 	' v0.35: texto fixo, paginado e com fade-in; os tiles 26/27/28
	; 	' (til/agudo/circunflexo) ficam exatamente sobre a vogal. As paginas
	; 	' ficam centralizadas, usam margem de 16 pixels e nao dependem de scroll.
	; history_screen: PROCEDURE
cvb_HISTORY_SCREEN:
	; hs_release:
cvb_HS_RELEASE:
	; 	WAIT
	JSR wait
	; 	IF CONT1.KEY = 11 THEN GOTO hs_release
	LDA key1_data
	CMP #11
	BNE.L cv510
	JMP cvb_HS_RELEASE
cv510:
	; 	IF CONT1.BUTTON THEN GOTO hs_release
	LDA joy1_data
	AND #64
	BEQ.L cv511
	JMP cvb_HS_RELEASE
cv511:
	; 	' Historia fixa em tres paginas; cada uma fica acesa ~10 segundos.
	; 	#fp = 0
	LDA #0
	TAY
	STA cvb_#FP
	STY cvb_#FP+1
	; 	GOSUB fixed_page_show
	JSR cvb_FIXED_PAGE_SHOW
	; 	IF sk <> 0 THEN GOTO hs_fim
	LDA cvb_SK
	BEQ.L cv512
	JMP cvb_HS_FIM
cv512:
	; 	#fp = 1
	LDA #1
	LDY #0
	STA cvb_#FP
	STY cvb_#FP+1
	; 	GOSUB fixed_page_show
	JSR cvb_FIXED_PAGE_SHOW
	; 	IF sk <> 0 THEN GOTO hs_fim
	LDA cvb_SK
	BEQ.L cv513
	JMP cvb_HS_FIM
cv513:
	; 	#fp = 2
	LDA #2
	LDY #0
	STA cvb_#FP
	STY cvb_#FP+1
	; 	GOSUB fixed_page_show
	JSR cvb_FIXED_PAGE_SHOW
	; hs_fim:
cvb_HS_FIM:
	; 	SCREEN DISABLE
	JSR DISSCR
	; 	POKE $1C,$00
	LDA #0
	PHA
	LDA #28
	LDY #0
	STA temp
	STY temp+1
	PLA
	STA (temp),Y
	; 	WAIT
	JSR wait
	; 	END
	RTS
	; 
	; fixed_page_show: PROCEDURE
cvb_FIXED_PAGE_SHOW:
	; 	' Paginas 0-2 = historia; 3-5 = creditos.
	; 	' Margem: colunas 2..29 (16 px laterais); texto/acento entre linhas 5..24.
	; 	sk = 0
	LDA #0
	STA cvb_SK
	; 	SCREEN DISABLE
	JSR DISSCR
	; 	FOR c = 0 TO 63
	LDA #0
	STA cvb_C
cv514:
	; 		SPRITE c,$f0,0,0,0
	LDA cvb_C
	PHA
	LDA #240
	STA sprite_data
	LDA #0
	STA sprite_data+3
	STA sprite_data+1
	STA sprite_data+2
	PLA
	JSR update_sprite
	; 	NEXT c
	INC cvb_C
	LDA cvb_C
	CMP #64
	BCC.L cv514
	; 	POKE $1C,$00
	LDA #0
	PHA
	LDA #28
	LDY #0
	STA temp
	STY temp+1
	PLA
	STA (temp),Y
	; 	PALETTE LOAD game_palette_title
	TYA
	STA pointer
	LDA #63
	STA pointer+1
	LDA #32
	STA temp2
	LDA #cvb_GAME_PALETTE_TITLE
	STA temp
	LDA #cvb_GAME_PALETTE_TITLE>>8
	STA temp+1
	JSR LDIRVM
	; 	CLS
	JSR cls
	; 	SCROLL 0,0
	LDA #0
	TAY
	STA scroll_x
	STY scroll_x+1
	STA scroll_y
	STY scroll_y+1
	; 	GOSUB fixed_text_page
	JSR cvb_FIXED_TEXT_PAGE
	; 	VPOKE $3F01,$0F
	LDA #15
	PHA
	LDA #1
	LDY #63
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $3F02,$0F
	LDA #15
	PHA
	LDA #2
	LDY #63
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $3F03,$0F
	LDA #15
	PHA
	LDA #3
	LDY #63
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	WAIT
	JSR wait
	; 	SCREEN ENABLE
	JSR ENASCR
	; 	RESTORE fade_tbl
	LDA #cvb_FADE_TBL
	LDY #cvb_FADE_TBL>>8
	STA read_pointer
	STY read_pointer+1
	; 	FOR r = 0 TO 6
	LDA #0
	STA cvb_R
cv515:
	; 		READ BYTE e
	JSR _read8
	STA cvb_E
	; 		READ BYTE e
	JSR _read8
	STA cvb_E
	; 		VPOKE $3F03,e
	PHA
	LDA #3
	LDY #63
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 		FOR q = 0 TO 3
	LDA #0
	STA cvb_Q
cv516:
	; 			WAIT
	JSR wait
	; 			IF CONT1.KEY = 11 THEN GOTO fps_skip
	LDA key1_data
	CMP #11
	BNE.L cv517
	JMP cvb_FPS_SKIP
cv517:
	; 			IF CONT1.BUTTON THEN GOTO fps_skip
	LDA joy1_data
	AND #64
	BEQ.L cv518
	JMP cvb_FPS_SKIP
cv518:
	; 		NEXT q
	INC cvb_Q
	LDA cvb_Q
	CMP #4
	BCC.L cv516
	; 	NEXT r
	INC cvb_R
	LDA cvb_R
	CMP #7
	BCC.L cv515
	; 	' Hold de 600 frames = aproximadamente 10 segundos por pagina.
	; 	' Tres blocos de 200 respeitam o contador de 8 bits do CVBasic.
	; 	FOR r = 0 TO 2
	LDA #0
	STA cvb_R
cv519:
	; 		FOR q = 0 TO 199
	LDA #0
	STA cvb_Q
cv520:
	; 			WAIT
	JSR wait
	; 			IF CONT1.KEY = 11 THEN GOTO fps_skip
	LDA key1_data
	CMP #11
	BNE.L cv521
	JMP cvb_FPS_SKIP
cv521:
	; 			IF CONT1.BUTTON THEN GOTO fps_skip
	LDA joy1_data
	AND #64
	BEQ.L cv522
	JMP cvb_FPS_SKIP
cv522:
	; 		NEXT q
	INC cvb_Q
	LDA cvb_Q
	CMP #200
	BCC.L cv520
	; 	NEXT r
	INC cvb_R
	LDA cvb_R
	CMP #3
	BCC.L cv519
	; 	RESTORE fade_tbl_out
	LDA #cvb_FADE_TBL_OUT
	LDY #cvb_FADE_TBL_OUT>>8
	STA read_pointer
	STY read_pointer+1
	; 	FOR r = 0 TO 6
	LDA #0
	STA cvb_R
cv523:
	; 		READ BYTE e
	JSR _read8
	STA cvb_E
	; 		READ BYTE e
	JSR _read8
	STA cvb_E
	; 		VPOKE $3F03,e
	PHA
	LDA #3
	LDY #63
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 		FOR q = 0 TO 3
	LDA #0
	STA cvb_Q
cv524:
	; 			WAIT
	JSR wait
	; 		NEXT q
	INC cvb_Q
	LDA cvb_Q
	CMP #4
	BCC.L cv524
	; 	NEXT r
	INC cvb_R
	LDA cvb_R
	CMP #7
	BCC.L cv523
	; 	SCREEN DISABLE
	JSR DISSCR
	; 	GOTO fps_done
	JMP cvb_FPS_DONE
	; fps_skip:
cvb_FPS_SKIP:
	; 	SCREEN DISABLE
	JSR DISSCR
	; 	POKE $1C,$00
	LDA #0
	PHA
	LDA #28
	LDY #0
	STA temp
	STY temp+1
	PLA
	STA (temp),Y
	; 	sk = 1
	LDA #1
	STA cvb_SK
	; fps_done:
cvb_FPS_DONE:
	; 	WAIT
	JSR wait
	; 	END
	RTS
	; 
	; fixed_text_page: PROCEDURE
cvb_FIXED_TEXT_PAGE:
	; 	' Registros: pagina, linha-base, coluna, tamanho, bytes de tiles.
	; 	' Registros de acento ocupam a linha imediatamente acima da base.
	; 	RESTORE fixed_text_data
	LDA #cvb_FIXED_TEXT_DATA
	LDY #cvb_FIXED_TEXT_DATA>>8
	STA read_pointer
	STY read_pointer+1
	; 	READ BYTE n
	JSR _read8
	STA cvb_N
	; 	FOR i = 0 TO n - 1
	LDA #0
	STA cvb_I
cv525:
	; 		READ BYTE p
	JSR _read8
	STA cvb_P
	; 		READ BYTE r
	JSR _read8
	STA cvb_R
	; 		READ BYTE e2
	JSR _read8
	STA cvb_E2
	; 		READ BYTE d
	JSR _read8
	STA cvb_D
	; 		IF p = #fp THEN
	LDA cvb_P
	LDY #0
	SEC
	SBC cvb_#FP
	STA temp
	TYA
	SBC cvb_#FP+1
	ORA temp
	BNE.L cv526
	; 			#tw = $2000 + r * 32 + e2
	LDA cvb_R
	STY temp
	ASL A
	ROL temp
	ASL A
	ROL temp
	ASL A
	ROL temp
	ASL A
	ROL temp
	ASL A
	ROL temp
	LDY temp
	CLC
	TAX
	TYA
	ADC #32
	TAY
	TXA
	CLC
	ADC cvb_E2
	TAX
	TYA
	ADC #0
	TAY
	TXA
	STA cvb_#TW
	STY cvb_#TW+1
	; 			FOR q = 0 TO d - 1
	LDA #0
	STA cvb_Q
cv527:
	; 				READ BYTE e
	JSR _read8
	STA cvb_E
	; 				VPOKE #tw,e
	PHA
	LDA cvb_#TW
	LDY cvb_#TW+1
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 				#tw = #tw + 1
	INC cvb_#TW
	BNE cv528
	INC cvb_#TW+1
cv528:
	; 			NEXT q
	INC cvb_Q
	LDA cvb_D
	SEC
	SBC #1
	CMP cvb_Q
	BCS.L cv527
	; 		ELSE
	JMP cv529
cv526:
	; 			FOR q = 0 TO d - 1
	LDA #0
	STA cvb_Q
cv530:
	; 				READ BYTE e
	JSR _read8
	STA cvb_E
	; 			NEXT q
	INC cvb_Q
	LDA cvb_D
	SEC
	SBC #1
	CMP cvb_Q
	BCS.L cv530
	; 		END IF
cv529:
	; 	NEXT i
	INC cvb_I
	LDA cvb_N
	SEC
	SBC #1
	CMP cvb_I
	BCS.L cv525
	; 	END
	RTS
	; 
	; 	' Conteudo integral da historia e dos creditos, paginado e centralizado.
	; fixed_text_data:
cvb_FIXED_TEXT_DATA:
	; 	DATA BYTE 75
	DB $4b
	; 	DATA BYTE 0,7,4,23,79,32,73,77,80,69,82,73,79,32,71,79,82,70,32,65,77,69,65,29,65,32,65
	DB $00,$07,$04,$17,$4f,$20,$49,$4d
	DB $50,$45,$52,$49,$4f,$20,$47,$4f
	DB $52,$46,$20,$41,$4d,$45,$41,$1d
	DB $41,$20,$41
	; 	DATA BYTE 0,6,9,1,27
	DB $00,$06,$09,$01,$1b
	; 	DATA BYTE 0,9,5,21,71,65,76,65,88,73,65,33,32,65,32,72,85,77,65,78,73,68,65,68,69
	DB $00,$09,$05,$15,$47,$41,$4c,$41
	DB $58,$49,$41,$21,$20,$41,$20,$48
	DB $55,$4d,$41,$4e,$49,$44,$41,$44
	DB $45
	; 	DATA BYTE 0,8,8,1,27
	DB $00,$08,$08,$01,$1b
	; 	DATA BYTE 0,11,2,28,80,82,69,67,73,83,65,32,82,69,83,73,83,84,73,82,32,69,32,69,78,70,82,69,78,84,65,82
	DB $00,$0b,$02,$1c,$50,$52,$45,$43
	DB $49,$53,$41,$20,$52,$45,$53,$49
	DB $53,$54,$49,$52,$20,$45,$20,$45
	DB $4e,$46,$52,$45,$4e,$54,$41,$52
	; 	DATA BYTE 0,13,3,25,69,83,83,69,32,73,78,73,77,73,71,79,32,84,69,82,82,73,86,69,76,33,32,79,83
	DB $00,$0d,$03,$19,$45,$53,$53,$45
	DB $20,$49,$4e,$49,$4d,$49,$47,$4f
	DB $20,$54,$45,$52,$52,$49,$56,$45
	DB $4c,$21,$20,$4f,$53
	; 	DATA BYTE 0,12,20,1,27
	DB $00,$0c,$14,$01,$1b
	; 	DATA BYTE 0,15,2,27,76,65,67,65,73,79,83,32,68,69,32,71,79,82,70,32,69,78,67,79,78,84,82,65,82,65,77
	DB $00,$0f,$02,$1b,$4c,$41,$43,$41
	DB $49,$4f,$53,$20,$44,$45,$20,$47
	DB $4f,$52,$46,$20,$45,$4e,$43,$4f
	DB $4e,$54,$52,$41,$52,$41,$4d
	; 	DATA BYTE 0,17,4,23,65,32,84,69,82,82,65,32,69,32,73,78,73,67,73,65,82,65,77,32,85,77,65
	DB $00,$11,$04,$17,$41,$20,$54,$45
	DB $52,$52,$41,$20,$45,$20,$49,$4e
	DB $49,$43,$49,$41,$52,$41,$4d,$20
	DB $55,$4d,$41
	; 	DATA BYTE 0,19,5,22,71,85,69,82,82,65,46,32,69,77,32,83,69,77,65,78,65,83,44,32,65,83
	DB $00,$13,$05,$16,$47,$55,$45,$52
	DB $52,$41,$2e,$20,$45,$4d,$20,$53
	DB $45,$4d,$41,$4e,$41,$53,$2c,$20
	DB $41,$53
	; 	DATA BYTE 0,21,5,21,70,79,82,29,65,83,32,68,65,32,84,69,82,82,65,32,69,32,68,79,83
	DB $00,$15,$05,$15,$46,$4f,$52,$1d
	DB $41,$53,$20,$44,$41,$20,$54,$45
	DB $52,$52,$41,$20,$45,$20,$44,$4f
	DB $53
	; 	DATA BYTE 0,23,4,24,73,78,73,77,73,71,79,83,32,83,79,70,82,69,82,65,77,32,77,85,73,84,65,83
	DB $00,$17,$04,$18,$49,$4e,$49,$4d
	DB $49,$47,$4f,$53,$20,$53,$4f,$46
	DB $52,$45,$52,$41,$4d,$20,$4d,$55
	DB $49,$54,$41,$53
	; 	DATA BYTE 1,6,2,27,66,65,73,88,65,83,44,32,77,65,83,32,69,76,69,83,32,69,83,84,65,86,65,77,32,69,77
	DB $01,$06,$02,$1b,$42,$41,$49,$58
	DB $41,$53,$2c,$20,$4d,$41,$53,$20
	DB $45,$4c,$45,$53,$20,$45,$53,$54
	DB $41,$56,$41,$4d,$20,$45,$4d
	; 	DATA BYTE 1,8,3,26,77,65,73,79,82,32,78,85,77,69,82,79,32,69,32,67,79,78,83,69,71,85,73,82,65,77
	DB $01,$08,$03,$1a,$4d,$41,$49,$4f
	DB $52,$20,$4e,$55,$4d,$45,$52,$4f
	DB $20,$45,$20,$43,$4f,$4e,$53,$45
	DB $47,$55,$49,$52,$41,$4d
	; 	DATA BYTE 1,7,10,1,27
	DB $01,$07,$0a,$01,$1b
	; 	DATA BYTE 1,10,3,26,83,73,84,73,65,82,32,78,79,83,83,79,32,80,76,65,78,69,84,65,46,32,67,79,77,79
	DB $01,$0a,$03,$1a,$53,$49,$54,$49
	DB $41,$52,$20,$4e,$4f,$53,$53,$4f
	DB $20,$50,$4c,$41,$4e,$45,$54,$41
	DB $2e,$20,$43,$4f,$4d,$4f
	; 	DATA BYTE 1,12,4,23,85,76,84,73,77,79,32,82,69,67,85,82,83,79,44,32,79,83,32,84,82,69,83
	DB $01,$0c,$04,$17,$55,$4c,$54,$49
	DB $4d,$4f,$20,$52,$45,$43,$55,$52
	DB $53,$4f,$2c,$20,$4f,$53,$20,$54
	DB $52,$45,$53
	; 	DATA BYTE 1,11,4,1,27
	DB $01,$0b,$04,$01,$1b
	; 	DATA BYTE 1,11,25,1,28
	DB $01,$0b,$19,$01,$1c
	; 	DATA BYTE 1,14,3,25,77,69,76,72,79,82,69,83,32,80,73,76,79,84,79,83,32,68,65,32,84,69,82,82,65
	DB $01,$0e,$03,$19,$4d,$45,$4c,$48
	DB $4f,$52,$45,$53,$20,$50,$49,$4c
	DB $4f,$54,$4f,$53,$20,$44,$41,$20
	DB $54,$45,$52,$52,$41
	; 	DATA BYTE 1,16,3,26,70,79,82,65,77,32,69,78,86,73,65,68,79,83,32,78,85,77,65,32,77,73,83,83,65,79
	DB $01,$10,$03,$1a,$46,$4f,$52,$41
	DB $4d,$20,$45,$4e,$56,$49,$41,$44
	DB $4f,$53,$20,$4e,$55,$4d,$41,$20
	DB $4d,$49,$53,$53,$41,$4f
	; 	DATA BYTE 1,15,27,1,26
	DB $01,$0f,$1b,$01,$1a
	; 	DATA BYTE 1,18,5,22,83,85,73,67,73,68,65,32,80,65,82,65,32,79,32,83,73,83,84,69,77,65
	DB $01,$12,$05,$16,$53,$55,$49,$43
	DB $49,$44,$41,$20,$50,$41,$52,$41
	DB $20,$4f,$20,$53,$49,$53,$54,$45
	DB $4d,$41
	; 	DATA BYTE 1,17,9,1,27
	DB $01,$11,$09,$01,$1b
	; 	DATA BYTE 1,20,2,27,89,65,82,73,83,44,32,80,65,82,65,32,84,69,78,84,65,82,32,68,69,82,82,79,84,65,82
	DB $01,$14,$02,$1b,$59,$41,$52,$49
	DB $53,$2c,$20,$50,$41,$52,$41,$20
	DB $54,$45,$4e,$54,$41,$52,$20,$44
	DB $45,$52,$52,$4f,$54,$41,$52
	; 	DATA BYTE 1,22,2,27,71,79,82,70,32,69,77,32,83,85,65,32,80,82,79,80,82,73,65,32,67,65,83,65,46,32,65
	DB $01,$16,$02,$1b,$47,$4f,$52,$46
	DB $20,$45,$4d,$20,$53,$55,$41,$20
	DB $50,$52,$4f,$50,$52,$49,$41,$20
	DB $43,$41,$53,$41,$2e,$20,$41
	; 	DATA BYTE 1,21,16,1,27
	DB $01,$15,$10,$01,$1b
	; 	DATA BYTE 1,24,4,23,77,73,83,83,65,79,58,32,65,76,67,65,78,29,65,82,32,89,65,82,73,83,44
	DB $01,$18,$04,$17,$4d,$49,$53,$53
	DB $41,$4f,$3a,$20,$41,$4c,$43,$41
	DB $4e,$1d,$41,$52,$20,$59,$41,$52
	DB $49,$53,$2c
	; 	DATA BYTE 1,23,8,1,26
	DB $01,$17,$08,$01,$1a
	; 	DATA BYTE 2,8,6,20,80,65,83,83,65,82,32,80,79,82,32,86,85,76,67,65,78,44,32,79
	DB $02,$08,$06,$14,$50,$41,$53,$53
	DB $41,$52,$20,$50,$4f,$52,$20,$56
	DB $55,$4c,$43,$41,$4e,$2c,$20,$4f
	; 	DATA BYTE 2,10,4,23,67,73,78,84,85,82,65,79,32,68,69,32,65,83,84,69,82,79,73,68,69,83,44
	DB $02,$0a,$04,$17,$43,$49,$4e,$54
	DB $55,$52,$41,$4f,$20,$44,$45,$20
	DB $41,$53,$54,$45,$52,$4f,$49,$44
	DB $45,$53,$2c
	; 	DATA BYTE 2,9,10,1,26
	DB $02,$09,$0a,$01,$1a
	; 	DATA BYTE 2,9,21,1,27
	DB $02,$09,$15,$01,$1b
	; 	DATA BYTE 2,12,5,21,68,69,83,84,82,85,73,82,32,79,32,71,69,82,65,68,79,82,32,68,69
	DB $02,$0c,$05,$15,$44,$45,$53,$54
	DB $52,$55,$49,$52,$20,$4f,$20,$47
	DB $45,$52,$41,$44,$4f,$52,$20,$44
	DB $45
	; 	DATA BYTE 2,14,4,24,69,83,67,85,68,79,83,32,69,77,32,65,84,76,65,78,84,73,83,32,80,65,82,65
	DB $02,$0e,$04,$18,$45,$53,$43,$55
	DB $44,$4f,$53,$20,$45,$4d,$20,$41
	DB $54,$4c,$41,$4e,$54,$49,$53,$20
	DB $50,$41,$52,$41
	; 	DATA BYTE 2,16,2,28,67,72,69,71,65,82,32,65,32,71,79,82,70,70,73,79,78,32,69,32,68,69,83,84,82,85,73,82
	DB $02,$10,$02,$1c,$43,$48,$45,$47
	DB $41,$52,$20,$41,$20,$47,$4f,$52
	DB $46,$46,$49,$4f,$4e,$20,$45,$20
	DB $44,$45,$53,$54,$52,$55,$49,$52
	; 	DATA BYTE 2,18,2,28,71,79,82,70,32,69,77,32,83,85,65,32,66,65,83,69,33,32,66,79,65,32,83,79,82,84,69,44
	DB $02,$12,$02,$1c,$47,$4f,$52,$46
	DB $20,$45,$4d,$20,$53,$55,$41,$20
	DB $42,$41,$53,$45,$21,$20,$42,$4f
	DB $41,$20,$53,$4f,$52,$54,$45,$2c
	; 	DATA BYTE 2,20,2,28,86,79,67,69,83,32,83,65,79,32,65,32,85,76,84,73,77,65,32,69,83,80,69,82,65,78,29,65
	DB $02,$14,$02,$1c,$56,$4f,$43,$45
	DB $53,$20,$53,$41,$4f,$20,$41,$20
	DB $55,$4c,$54,$49,$4d,$41,$20,$45
	DB $53,$50,$45,$52,$41,$4e,$1d,$41
	; 	DATA BYTE 2,19,5,1,28
	DB $02,$13,$05,$01,$1c
	; 	DATA BYTE 2,19,9,1,26
	DB $02,$13,$09,$01,$1a
	; 	DATA BYTE 2,19,14,1,27
	DB $02,$13,$0e,$01,$1b
	; 	DATA BYTE 2,22,11,9,68,65,32,84,69,82,82,65,33
	DB $02,$16,$0b,$09,$44,$41,$20,$54
	DB $45,$52,$52,$41,$21
	; 	DATA BYTE 3,7,6,20,81,85,69,77,32,70,69,90,32,83,80,65,67,69,32,66,76,65,83,84
	DB $03,$07,$06,$14,$51,$55,$45,$4d
	DB $20,$46,$45,$5a,$20,$53,$50,$41
	DB $43,$45,$20,$42,$4c,$41,$53,$54
	; 	DATA BYTE 3,9,2,27,80,82,79,71,82,65,77,65,29,65,79,58,32,83,65,85,76,79,32,83,65,78,84,73,65,71,79
	DB $03,$09,$02,$1b,$50,$52,$4f,$47
	DB $52,$41,$4d,$41,$1d,$41,$4f,$3a
	DB $20,$53,$41,$55,$4c,$4f,$20,$53
	DB $41,$4e,$54,$49,$41,$47,$4f
	; 	DATA BYTE 3,8,11,1,26
	DB $03,$08,$0b,$01,$1a
	; 	DATA BYTE 3,11,4,24,71,82,65,70,73,67,79,83,58,32,83,65,85,76,79,32,83,65,78,84,73,65,71,79
	DB $03,$0b,$04,$18,$47,$52,$41,$46
	DB $49,$43,$4f,$53,$3a,$20,$53,$41
	DB $55,$4c,$4f,$20,$53,$41,$4e,$54
	DB $49,$41,$47,$4f
	; 	DATA BYTE 3,10,6,1,27
	DB $03,$0a,$06,$01,$1b
	; 	DATA BYTE 3,13,5,21,65,85,68,73,79,58,32,83,65,85,76,79,32,83,65,78,84,73,65,71,79
	DB $03,$0d,$05,$15,$41,$55,$44,$49
	DB $4f,$3a,$20,$53,$41,$55,$4c,$4f
	DB $20,$53,$41,$4e,$54,$49,$41,$47
	DB $4f
	; 	DATA BYTE 3,15,6,19,80,82,79,68,85,29,65,79,58,32,76,77,83,32,82,69,84,82,79
	DB $03,$0f,$06,$13,$50,$52,$4f,$44
	DB $55,$1d,$41,$4f,$3a,$20,$4c,$4d
	DB $53,$20,$52,$45,$54,$52,$4f
	; 	DATA BYTE 3,14,12,1,26
	DB $03,$0e,$0c,$01,$1a
	; 	DATA BYTE 3,17,4,23,80,85,66,76,73,67,65,29,65,79,58,32,70,65,76,67,79,78,32,83,79,70,84
	DB $03,$11,$04,$17,$50,$55,$42,$4c
	DB $49,$43,$41,$1d,$41,$4f,$3a,$20
	DB $46,$41,$4c,$43,$4f,$4e,$20,$53
	DB $4f,$46,$54
	; 	DATA BYTE 3,16,12,1,26
	DB $03,$10,$0c,$01,$1a
	; 	DATA BYTE 3,19,2,27,84,69,83,84,69,83,58,32,77,65,82,67,79,83,32,70,69,76,73,80,69,44,32,76,85,67,65
	DB $03,$13,$02,$1b,$54,$45,$53,$54
	DB $45,$53,$3a,$20,$4d,$41,$52,$43
	DB $4f,$53,$20,$46,$45,$4c,$49,$50
	DB $45,$2c,$20,$4c,$55,$43,$41
	; 	DATA BYTE 3,21,5,22,86,79,76,79,84,65,79,44,32,76,85,67,65,83,32,77,85,78,72,79,90,44
	DB $03,$15,$05,$16,$56,$4f,$4c,$4f
	DB $54,$41,$4f,$2c,$20,$4c,$55,$43
	DB $41,$53,$20,$4d,$55,$4e,$48,$4f
	DB $5a,$2c
	; 	DATA BYTE 3,20,10,1,26
	DB $03,$14,$0a,$01,$1a
	; 	DATA BYTE 3,23,8,16,70,73,76,73,80,69,32,71,82,65,67,73,79,76,76,73
	DB $03,$17,$08,$10,$46,$49,$4c,$49
	DB $50,$45,$20,$47,$52,$41,$43,$49
	DB $4f,$4c,$4c,$49
	; 	DATA BYTE 4,8,3,25,65,71,82,65,68,69,67,73,77,69,78,84,79,83,32,69,83,80,69,67,73,65,73,83,58
	DB $04,$08,$03,$19,$41,$47,$52,$41
	DB $44,$45,$43,$49,$4d,$45,$4e,$54
	DB $4f,$53,$20,$45,$53,$50,$45,$43
	DB $49,$41,$49,$53,$3a
	; 	DATA BYTE 4,10,5,21,87,65,82,80,90,79,78,69,44,32,67,65,78,65,76,51,44,32,82,73,79
	DB $04,$0a,$05,$15,$57,$41,$52,$50
	DB $5a,$4f,$4e,$45,$2c,$20,$43,$41
	DB $4e,$41,$4c,$33,$2c,$20,$52,$49
	DB $4f
	; 	DATA BYTE 4,12,2,28,82,69,84,82,79,71,65,77,69,83,44,32,83,72,77,85,80,83,66,82,44,32,77,65,82,67,79,83
	DB $04,$0c,$02,$1c,$52,$45,$54,$52
	DB $4f,$47,$41,$4d,$45,$53,$2c,$20
	DB $53,$48,$4d,$55,$50,$53,$42,$52
	DB $2c,$20,$4d,$41,$52,$43,$4f,$53
	; 	DATA BYTE 4,14,4,23,70,69,76,73,80,69,44,32,82,65,70,65,69,76,32,76,73,77,65,44,32,80,86
	DB $04,$0e,$04,$17,$46,$45,$4c,$49
	DB $50,$45,$2c,$20,$52,$41,$46,$41
	DB $45,$4c,$20,$4c,$49,$4d,$41,$2c
	DB $20,$50,$56
	; 	DATA BYTE 4,16,2,27,82,65,68,84,75,69,44,32,89,85,82,73,32,68,65,86,73,76,65,44,32,84,72,73,65,71,79
	DB $04,$10,$02,$1b,$52,$41,$44,$54
	DB $4b,$45,$2c,$20,$59,$55,$52,$49
	DB $20,$44,$41,$56,$49,$4c,$41,$2c
	DB $20,$54,$48,$49,$41,$47,$4f
	; 	DATA BYTE 4,15,16,1,27
	DB $04,$0f,$10,$01,$1b
	; 	DATA BYTE 4,18,5,22,77,73,78,69,73,82,79,44,32,76,85,67,65,83,32,77,85,78,72,79,90,44
	DB $04,$12,$05,$16,$4d,$49,$4e,$45
	DB $49,$52,$4f,$2c,$20,$4c,$55,$43
	DB $41,$53,$20,$4d,$55,$4e,$48,$4f
	DB $5a,$2c
	; 	DATA BYTE 4,20,3,26,71,85,83,84,65,86,79,32,86,65,76,68,73,86,73,69,83,83,79,44,32,77,65,82,73,79
	DB $04,$14,$03,$1a,$47,$55,$53,$54
	DB $41,$56,$4f,$20,$56,$41,$4c,$44
	DB $49,$56,$49,$45,$53,$53,$4f,$2c
	DB $20,$4d,$41,$52,$49,$4f
	; 	DATA BYTE 4,22,3,25,78,69,83,82,79,67,75,83,44,32,67,65,82,73,78,65,32,86,79,76,79,84,65,79,44
	DB $04,$16,$03,$19,$4e,$45,$53,$52
	DB $4f,$43,$4b,$53,$2c,$20,$43,$41
	DB $52,$49,$4e,$41,$20,$56,$4f,$4c
	DB $4f,$54,$41,$4f,$2c
	; 	DATA BYTE 4,21,25,1,26
	DB $04,$15,$19,$01,$1a
	; 	DATA BYTE 5,8,2,28,76,85,67,65,32,69,32,82,65,86,73,44,32,84,79,68,79,83,32,79,83,32,65,77,73,71,79,83
	DB $05,$08,$02,$1c,$4c,$55,$43,$41
	DB $20,$45,$20,$52,$41,$56,$49,$2c
	DB $20,$54,$4f,$44,$4f,$53,$20,$4f
	DB $53,$20,$41,$4d,$49,$47,$4f,$53
	; 	DATA BYTE 5,10,3,25,81,85,69,32,83,69,77,80,82,69,32,65,67,82,69,68,73,84,65,82,65,77,32,78,65
	DB $05,$0a,$03,$19,$51,$55,$45,$20
	DB $53,$45,$4d,$50,$52,$45,$20,$41
	DB $43,$52,$45,$44,$49,$54,$41,$52
	DB $41,$4d,$20,$4e,$41
	; 	DATA BYTE 5,12,4,23,70,65,76,67,79,78,32,83,79,70,84,32,69,32,86,79,67,69,44,32,81,85,69
	DB $05,$0c,$04,$17,$46,$41,$4c,$43
	DB $4f,$4e,$20,$53,$4f,$46,$54,$20
	DB $45,$20,$56,$4f,$43,$45,$2c,$20
	DB $51,$55,$45
	; 	DATA BYTE 5,11,21,1,28
	DB $05,$0b,$15,$01,$1c
	; 	DATA BYTE 5,14,3,25,80,82,69,83,84,73,71,73,79,85,32,78,79,83,83,79,32,84,82,65,66,65,76,72,79
	DB $05,$0e,$03,$19,$50,$52,$45,$53
	DB $54,$49,$47,$49,$4f,$55,$20,$4e
	DB $4f,$53,$53,$4f,$20,$54,$52,$41
	DB $42,$41,$4c,$48,$4f
	; 	DATA BYTE 5,16,3,26,86,73,83,73,84,69,32,65,32,70,65,76,67,79,78,83,79,70,84,46,67,79,77,46,66,82
	DB $05,$10,$03,$1a,$56,$49,$53,$49
	DB $54,$45,$20,$41,$20,$46,$41,$4c
	DB $43,$4f,$4e,$53,$4f,$46,$54,$2e
	DB $43,$4f,$4d,$2e,$42,$52
	; 	DATA BYTE 5,18,4,23,80,65,82,65,32,78,79,86,79,83,32,74,79,71,79,83,32,65,80,79,73,69,77
	DB $05,$12,$04,$17,$50,$41,$52,$41
	DB $20,$4e,$4f,$56,$4f,$53,$20,$4a
	DB $4f,$47,$4f,$53,$20,$41,$50,$4f
	DB $49,$45,$4d
	; 	DATA BYTE 5,20,5,21,83,69,77,80,82,69,32,79,83,32,73,78,68,73,69,32,71,65,77,69,83
	DB $05,$14,$05,$15,$53,$45,$4d,$50
	DB $52,$45,$20,$4f,$53,$20,$49,$4e
	DB $44,$49,$45,$20,$47,$41,$4d,$45
	DB $53
	; 	DATA BYTE 5,22,10,12,66,82,65,83,73,76,69,73,82,79,83,33
	DB $05,$16,$0a,$0c,$42,$52,$41,$53
	DB $49,$4c,$45,$49,$52,$4f,$53,$21
	; 	CHRROM 0
	; 	'
	; 	' Estrelas do fundo (sheet estrelas-cinzas.png do Saulo)
	; 	' idx 0 = vazio (cls preenche com 0). cores: 1=azul 2=branco 3=cinza
	; 	'
	; 	CHRROM PATTERN 0
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "......3."
	; 	BITMAP ".....323"
	; 	BITMAP "......3."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "....2..."
	; 	BITMAP "........"
	; 	BITMAP "..3....."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "...3...."
	; 	BITMAP "..323..."
	; 	BITMAP "...3...."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP ".3......"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "........"
	; 	BITMAP "....1..."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP ".....3.."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "..3....."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP ".....3.."
	; 	BITMAP "..1....."
	; 	BITMAP "........"
	; 	BITMAP "....1..."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "......3."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "....2..."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "......2."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "....1..."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP ".....3.."
	; 	BITMAP "....323."
	; 	BITMAP ".....3.."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP ".....1.."
	; 	BITMAP "........"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "..2.1..."
	; 	BITMAP "......33"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "..3....."
	; 	BITMAP "...1...."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "........"
	; 	BITMAP "..3....."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "....1..."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP ".1......"
	; 	BITMAP "....3..."
	; 	BITMAP "........"
	; 	BITMAP "..3....."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP ".....1.."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "...3...."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "..2....."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "..1....."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "....3..."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "..2....."
	; 	BITMAP "........"
	; 	BITMAP ".....1.."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "....3..."
	; 	BITMAP "...2...."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP ".2......"
	; 	BITMAP "........"
	; 	BITMAP ".....3.."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 
	; 
	; 	' ===== FONTE SAULO v0.17 — INICIO (gera_fonte.py) =====
	; 	' spritefont 16x6 do Saulo (uploads/Sprite_font.png). pixels '3' (2
	; 	' planos) = mesmo estilo da fonte CVBasic -> paleta identica.
	; 	' ASCII 32-95: digitos 0-9, A-Z e pontuacao mapeada.
	; 	CHRROM PATTERN 32
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "...333.."
	; 	BITMAP "...333.."
	; 	BITMAP "...333.."
	; 	BITMAP "...33..."
	; 	BITMAP "...33..."
	; 	BITMAP "........"
	; 	BITMAP "...33..."
	; 	BITMAP "...33..."
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "33333333"
	; 	BITMAP "33333333"
	; 	BITMAP "33333333"
	; 	BITMAP "33333333"
	; 	BITMAP "33333333"
	; 	BITMAP "33333333"
	; 	BITMAP "33333333"
	; 	BITMAP "33333333"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "....3..."
	; 	BITMAP "...3...."
	; 	BITMAP "........"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "..3..3.."
	; 	BITMAP "...33..."
	; 	BITMAP "...33..."
	; 	BITMAP "..3..3.."
	; 	BITMAP "........"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "...33..."
	; 	BITMAP "...33..."
	; 	BITMAP "....3..."
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "..333..."
	; 	BITMAP ".3..33.."
	; 	BITMAP "33...33."
	; 	BITMAP "33...33."
	; 	BITMAP "33...33."
	; 	BITMAP ".33..3.."
	; 	BITMAP "..333..."
	; 	BITMAP "........"
	; 
	; 	BITMAP "...33..."
	; 	BITMAP "...33..."
	; 	BITMAP "...33..."
	; 	BITMAP "...33..."
	; 	BITMAP "...33..."
	; 	BITMAP "...33..."
	; 	BITMAP ".333333."
	; 	BITMAP "........"
	; 
	; 	BITMAP ".33333.."
	; 	BITMAP "33...33."
	; 	BITMAP "....333."
	; 	BITMAP "..3333.."
	; 	BITMAP ".3333..."
	; 	BITMAP "333....."
	; 	BITMAP "3333333."
	; 	BITMAP "........"
	; 
	; 	BITMAP ".333333."
	; 	BITMAP "....33.."
	; 	BITMAP "...33..."
	; 	BITMAP "..3333.."
	; 	BITMAP ".....33."
	; 	BITMAP "33...33."
	; 	BITMAP ".33333.."
	; 	BITMAP "........"
	; 
	; 	BITMAP "...333.."
	; 	BITMAP "..3333.."
	; 	BITMAP ".33.33.."
	; 	BITMAP "33..33.."
	; 	BITMAP "3333333."
	; 	BITMAP "....33.."
	; 	BITMAP "....33.."
	; 	BITMAP "........"
	; 
	; 	BITMAP "333333.."
	; 	BITMAP "33......"
	; 	BITMAP "333333.."
	; 	BITMAP ".....33."
	; 	BITMAP ".....33."
	; 	BITMAP "33...33."
	; 	BITMAP ".33333.."
	; 	BITMAP "........"
	; 
	; 	BITMAP "..3333.."
	; 	BITMAP ".33....."
	; 	BITMAP "33......"
	; 	BITMAP "333333.."
	; 	BITMAP "33...33."
	; 	BITMAP "33...33."
	; 	BITMAP ".33333.."
	; 	BITMAP "........"
	; 
	; 	BITMAP "3333333."
	; 	BITMAP "33...33."
	; 	BITMAP "....33.."
	; 	BITMAP "...33..."
	; 	BITMAP "..33...."
	; 	BITMAP "..33...."
	; 	BITMAP "..33...."
	; 	BITMAP "........"
	; 
	; 	BITMAP ".33333.."
	; 	BITMAP "33...33."
	; 	BITMAP "33...33."
	; 	BITMAP ".33333.."
	; 	BITMAP "33...33."
	; 	BITMAP "33...33."
	; 	BITMAP ".33333.."
	; 	BITMAP "........"
	; 
	; 	BITMAP ".33333.."
	; 	BITMAP "33...33."
	; 	BITMAP "33...33."
	; 	BITMAP ".333333."
	; 	BITMAP ".....33."
	; 	BITMAP "....33.."
	; 	BITMAP ".3333..."
	; 	BITMAP "........"
	; 
	; 	BITMAP "...33..."
	; 	BITMAP "...33..."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "...33..."
	; 	BITMAP "...33..."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "...3...."
	; 	BITMAP "..33...."
	; 	BITMAP ".333...."
	; 	BITMAP "33333333"
	; 	BITMAP "33333333"
	; 	BITMAP ".333...."
	; 	BITMAP "..33...."
	; 	BITMAP "...3...."
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "..3333.."
	; 	BITMAP ".33..33."
	; 	BITMAP ".33..33."
	; 	BITMAP ".....33."
	; 	BITMAP "...33..."
	; 	BITMAP "........"
	; 	BITMAP "...33..."
	; 	BITMAP "...33..."
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "..333..."
	; 	BITMAP ".33.33.."
	; 	BITMAP "33...33."
	; 	BITMAP "33...33."
	; 	BITMAP "3333333."
	; 	BITMAP "33...33."
	; 	BITMAP "33...33."
	; 	BITMAP "........"
	; 
	; 	BITMAP "333333.."
	; 	BITMAP "33...33."
	; 	BITMAP "33...33."
	; 	BITMAP "333333.."
	; 	BITMAP "33...33."
	; 	BITMAP "33...33."
	; 	BITMAP "333333.."
	; 	BITMAP "........"
	; 
	; 	BITMAP "..3333.."
	; 	BITMAP ".33..33."
	; 	BITMAP "33......"
	; 	BITMAP "33......"
	; 	BITMAP "33......"
	; 	BITMAP ".33..33."
	; 	BITMAP "..3333.."
	; 	BITMAP "........"
	; 
	; 	BITMAP "33333..."
	; 	BITMAP "33..33.."
	; 	BITMAP "33...33."
	; 	BITMAP "33...33."
	; 	BITMAP "33...33."
	; 	BITMAP "33..33.."
	; 	BITMAP "33333..."
	; 	BITMAP "........"
	; 
	; 	BITMAP "3333333."
	; 	BITMAP "33......"
	; 	BITMAP "33......"
	; 	BITMAP "333333.."
	; 	BITMAP "33......"
	; 	BITMAP "33......"
	; 	BITMAP "3333333."
	; 	BITMAP "........"
	; 
	; 	BITMAP "3333333."
	; 	BITMAP "33......"
	; 	BITMAP "33......"
	; 	BITMAP "333333.."
	; 	BITMAP "33......"
	; 	BITMAP "33......"
	; 	BITMAP "33......"
	; 	BITMAP "........"
	; 
	; 	BITMAP "..33333."
	; 	BITMAP ".33....."
	; 	BITMAP "33......"
	; 	BITMAP "33..333."
	; 	BITMAP "33...33."
	; 	BITMAP ".33..33."
	; 	BITMAP "..33333."
	; 	BITMAP "........"
	; 
	; 	BITMAP "33...33."
	; 	BITMAP "33...33."
	; 	BITMAP "33...33."
	; 	BITMAP "3333333."
	; 	BITMAP "33...33."
	; 	BITMAP "33...33."
	; 	BITMAP "33...33."
	; 	BITMAP "........"
	; 
	; 	BITMAP ".333333."
	; 	BITMAP "...33..."
	; 	BITMAP "...33..."
	; 	BITMAP "...33..."
	; 	BITMAP "...33..."
	; 	BITMAP "...33..."
	; 	BITMAP ".333333."
	; 	BITMAP "........"
	; 
	; 	BITMAP "...3333."
	; 	BITMAP ".....33."
	; 	BITMAP ".....33."
	; 	BITMAP ".....33."
	; 	BITMAP "33...33."
	; 	BITMAP "33...33."
	; 	BITMAP ".33333.."
	; 	BITMAP "........"
	; 
	; 	BITMAP "33...33."
	; 	BITMAP "33..33.."
	; 	BITMAP "33.33..."
	; 	BITMAP "3333...."
	; 	BITMAP "33333..."
	; 	BITMAP "33.333.."
	; 	BITMAP "33..333."
	; 	BITMAP "........"
	; 
	; 	BITMAP ".33....."
	; 	BITMAP ".33....."
	; 	BITMAP ".33....."
	; 	BITMAP ".33....."
	; 	BITMAP ".33....."
	; 	BITMAP ".33....."
	; 	BITMAP ".333333."
	; 	BITMAP "........"
	; 
	; 	BITMAP "33...33."
	; 	BITMAP "333.333."
	; 	BITMAP "3333333."
	; 	BITMAP "3333333."
	; 	BITMAP "33.3.33."
	; 	BITMAP "33...33."
	; 	BITMAP "33...33."
	; 	BITMAP "........"
	; 
	; 	BITMAP "33...33."
	; 	BITMAP "333..33."
	; 	BITMAP "3333.33."
	; 	BITMAP "3333333."
	; 	BITMAP "33.3333."
	; 	BITMAP "33..333."
	; 	BITMAP "33...33."
	; 	BITMAP "........"
	; 
	; 	BITMAP ".33333.."
	; 	BITMAP "33...33."
	; 	BITMAP "33...33."
	; 	BITMAP "33...33."
	; 	BITMAP "33...33."
	; 	BITMAP "33...33."
	; 	BITMAP ".33333.."
	; 	BITMAP "........"
	; 
	; 	BITMAP "333333.."
	; 	BITMAP "33...33."
	; 	BITMAP "33...33."
	; 	BITMAP "33...33."
	; 	BITMAP "333333.."
	; 	BITMAP "33......"
	; 	BITMAP "33......"
	; 	BITMAP "........"
	; 
	; 	BITMAP ".33333.."
	; 	BITMAP "33...33."
	; 	BITMAP "33...33."
	; 	BITMAP "33...33."
	; 	BITMAP "33.3333."
	; 	BITMAP "33..33.."
	; 	BITMAP ".3333.3."
	; 	BITMAP "........"
	; 
	; 	BITMAP "333333.."
	; 	BITMAP "33...33."
	; 	BITMAP "33...33."
	; 	BITMAP "33..333."
	; 	BITMAP "33333..."
	; 	BITMAP "33.333.."
	; 	BITMAP "33..333."
	; 	BITMAP "........"
	; 
	; 	BITMAP ".3333..."
	; 	BITMAP "33..33.."
	; 	BITMAP "33......"
	; 	BITMAP ".33333.."
	; 	BITMAP ".....33."
	; 	BITMAP "33...33."
	; 	BITMAP ".33333.."
	; 	BITMAP "........"
	; 
	; 	BITMAP ".333333."
	; 	BITMAP "...33..."
	; 	BITMAP "...33..."
	; 	BITMAP "...33..."
	; 	BITMAP "...33..."
	; 	BITMAP "...33..."
	; 	BITMAP "...33..."
	; 	BITMAP "........"
	; 
	; 	BITMAP "33...33."
	; 	BITMAP "33...33."
	; 	BITMAP "33...33."
	; 	BITMAP "33...33."
	; 	BITMAP "33...33."
	; 	BITMAP "33...33."
	; 	BITMAP ".33333.."
	; 	BITMAP "........"
	; 
	; 	BITMAP "33...33."
	; 	BITMAP "33...33."
	; 	BITMAP "33...33."
	; 	BITMAP "333.333."
	; 	BITMAP ".33333.."
	; 	BITMAP "..333..."
	; 	BITMAP "...3...."
	; 	BITMAP "........"
	; 
	; 	BITMAP "33...33."
	; 	BITMAP "33...33."
	; 	BITMAP "33.3.33."
	; 	BITMAP "3333333."
	; 	BITMAP "3333333."
	; 	BITMAP "333.333."
	; 	BITMAP "33...33."
	; 	BITMAP "........"
	; 
	; 	BITMAP "33...33."
	; 	BITMAP "333.333."
	; 	BITMAP ".33333.."
	; 	BITMAP "..333..."
	; 	BITMAP ".33333.."
	; 	BITMAP "333.333."
	; 	BITMAP "33...33."
	; 	BITMAP "........"
	; 
	; 	BITMAP ".33..33."
	; 	BITMAP ".33..33."
	; 	BITMAP ".33..33."
	; 	BITMAP "..3333.."
	; 	BITMAP "...33..."
	; 	BITMAP "...33..."
	; 	BITMAP "...33..."
	; 	BITMAP "........"
	; 
	; 	BITMAP "3333333."
	; 	BITMAP "....333."
	; 	BITMAP "...333.."
	; 	BITMAP "..333..."
	; 	BITMAP ".333...."
	; 	BITMAP "333....."
	; 	BITMAP "3333333."
	; 	BITMAP "........"
	; 
	; 	BITMAP "........"
	; 	BITMAP ".333...."
	; 	BITMAP "...3...."
	; 	BITMAP "...3...."
	; 	BITMAP "...3...."
	; 	BITMAP "...3...."
	; 	BITMAP ".333...."
	; 	BITMAP "........"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "...33..."
	; 	BITMAP "..3333.."
	; 	BITMAP ".333333."
	; 	BITMAP "33333333"
	; 	BITMAP "...33..."
	; 	BITMAP "...33..."
	; 	BITMAP "...33..."
	; 	BITMAP "...33..."
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	' --- digitos do placar (sprites 8x16): par = glifo, impar = vazio;
	; 	'     T = 192 + 2*d (byte OAM par -> tabela $0000, pares T/T+1)
	; 	CHRROM PATTERN 192
	; 
	; 	BITMAP "..333..."
	; 	BITMAP ".3..33.."
	; 	BITMAP "33...33."
	; 	BITMAP "33...33."
	; 	BITMAP "33...33."
	; 	BITMAP ".33..3.."
	; 	BITMAP "..333..."
	; 	BITMAP "........"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "...33..."
	; 	BITMAP "...33..."
	; 	BITMAP "...33..."
	; 	BITMAP "...33..."
	; 	BITMAP "...33..."
	; 	BITMAP "...33..."
	; 	BITMAP ".333333."
	; 	BITMAP "........"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP ".33333.."
	; 	BITMAP "33...33."
	; 	BITMAP "....333."
	; 	BITMAP "..3333.."
	; 	BITMAP ".3333..."
	; 	BITMAP "333....."
	; 	BITMAP "3333333."
	; 	BITMAP "........"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP ".333333."
	; 	BITMAP "....33.."
	; 	BITMAP "...33..."
	; 	BITMAP "..3333.."
	; 	BITMAP ".....33."
	; 	BITMAP "33...33."
	; 	BITMAP ".33333.."
	; 	BITMAP "........"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "...333.."
	; 	BITMAP "..3333.."
	; 	BITMAP ".33.33.."
	; 	BITMAP "33..33.."
	; 	BITMAP "3333333."
	; 	BITMAP "....33.."
	; 	BITMAP "....33.."
	; 	BITMAP "........"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "333333.."
	; 	BITMAP "33......"
	; 	BITMAP "333333.."
	; 	BITMAP ".....33."
	; 	BITMAP ".....33."
	; 	BITMAP "33...33."
	; 	BITMAP ".33333.."
	; 	BITMAP "........"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "..3333.."
	; 	BITMAP ".33....."
	; 	BITMAP "33......"
	; 	BITMAP "333333.."
	; 	BITMAP "33...33."
	; 	BITMAP "33...33."
	; 	BITMAP ".33333.."
	; 	BITMAP "........"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "3333333."
	; 	BITMAP "33...33."
	; 	BITMAP "....33.."
	; 	BITMAP "...33..."
	; 	BITMAP "..33...."
	; 	BITMAP "..33...."
	; 	BITMAP "..33...."
	; 	BITMAP "........"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP ".33333.."
	; 	BITMAP "33...33."
	; 	BITMAP "33...33."
	; 	BITMAP ".33333.."
	; 	BITMAP "33...33."
	; 	BITMAP "33...33."
	; 	BITMAP ".33333.."
	; 	BITMAP "........"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP ".33333.."
	; 	BITMAP "33...33."
	; 	BITMAP "33...33."
	; 	BITMAP ".333333."
	; 	BITMAP ".....33."
	; 	BITMAP "....33.."
	; 	BITMAP ".3333..."
	; 	BITMAP "........"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	' --- GAME OVER estilizado (cells 80-87 da folha)
	; 	CHRROM PATTERN 214
	; 
	; 	BITMAP ".3333333"
	; 	BITMAP "33333333"
	; 	BITMAP "33.....3"
	; 	BITMAP "33..3333"
	; 	BITMAP "33..3..3"
	; 	BITMAP "33..33.3"
	; 	BITMAP "33.....3"
	; 	BITMAP ".3333333"
	; 
	; 	BITMAP "33333333"
	; 	BITMAP "33333333"
	; 	BITMAP "3......3"
	; 	BITMAP "3..333.3"
	; 	BITMAP "3......3"
	; 	BITMAP "3..333.3"
	; 	BITMAP "3..333.3"
	; 	BITMAP "33333333"
	; 
	; 	BITMAP "33333333"
	; 	BITMAP "33333333"
	; 	BITMAP "3..333.3"
	; 	BITMAP "3...3..3"
	; 	BITMAP "3..3.3.3"
	; 	BITMAP "3..333.3"
	; 	BITMAP "3..333.3"
	; 	BITMAP "33333333"
	; 
	; 	BITMAP "33333333"
	; 	BITMAP "33333333"
	; 	BITMAP "3.....33"
	; 	BITMAP "3..33333"
	; 	BITMAP "3.....33"
	; 	BITMAP "3..33333"
	; 	BITMAP "3.....33"
	; 	BITMAP "33333333"
	; 
	; 	BITMAP "33333333"
	; 	BITMAP "33333333"
	; 	BITMAP "3......3"
	; 	BITMAP "3..333.3"
	; 	BITMAP "3..333.3"
	; 	BITMAP "3..333.3"
	; 	BITMAP "3......3"
	; 	BITMAP "33333333"
	; 
	; 	BITMAP "33333333"
	; 	BITMAP "33333333"
	; 	BITMAP "3..333.3"
	; 	BITMAP "3..333.3"
	; 	BITMAP "3..33.33"
	; 	BITMAP "33..3.33"
	; 	BITMAP "33...333"
	; 	BITMAP "33333333"
	; 
	; 	BITMAP "33333333"
	; 	BITMAP "33333333"
	; 	BITMAP "3......3"
	; 	BITMAP "3..33333"
	; 	BITMAP "3......3"
	; 	BITMAP "3..33333"
	; 	BITMAP "3......3"
	; 	BITMAP "33333333"
	; 
	; 	BITMAP "3333333."
	; 	BITMAP "33333333"
	; 	BITMAP "3.....33"
	; 	BITMAP "3..333.3"
	; 	BITMAP "3.....33"
	; 	BITMAP "3..3.333"
	; 	BITMAP "3..33.33"
	; 	BITMAP "3333333."
	; 
	; 	' --- decor/mini-labels reservados: BONUS parts, 1UP, <|
	; 	CHRROM PATTERN 224
	; 
	; 	BITMAP "......3."
	; 	BITMAP ".33..3.3"
	; 	BITMAP ".3.3...."
	; 	BITMAP ".3.3..3."
	; 	BITMAP ".33..3.3"
	; 	BITMAP ".3.3.3.3"
	; 	BITMAP ".3.3.3.3"
	; 	BITMAP ".33...3."
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP ".3...3.3"
	; 	BITMAP ".33..3.3"
	; 	BITMAP ".3.3.3.3"
	; 	BITMAP ".3.3.3.3"
	; 	BITMAP ".3.3..3."
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP ".....33."
	; 	BITMAP ".333.33."
	; 	BITMAP ".3....3."
	; 	BITMAP "..33..3."
	; 	BITMAP "...3...."
	; 	BITMAP ".33...3."
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "...33..."
	; 	BITMAP "...33..."
	; 	BITMAP "....3..."
	; 	BITMAP "....3..."
	; 	BITMAP "....3..."
	; 	BITMAP "...333.."
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "3.3.33.."
	; 	BITMAP "3.3.3.3."
	; 	BITMAP "3.3.3.3."
	; 	BITMAP "3.3.33.."
	; 	BITMAP "3.3.3..."
	; 	BITMAP ".3..3..."
	; 
	; 	BITMAP "..33...."
	; 	BITMAP "..333..."
	; 	BITMAP "..3333.."
	; 	BITMAP "..33333."
	; 	BITMAP "..33333."
	; 	BITMAP "..3333.."
	; 	BITMAP "..333..."
	; 	BITMAP "..33...."
	; 
	; 	'
	; 	' v0.28: desvira + idle da nave. Saiu do banco 0 (estourou 97 bytes
	; 	' com as 5 fases + fim de jogo); mesmo padrao do mb_frame/boss_frame
	; 	' (proc quente chamado do game_loop com BANK SELECT 1/0).
	; 	'
	; anim_idle:	PROCEDURE	' soltou o direcional: desvira (6,5,4) e faz idle
cvb_ANIM_IDLE:
	; 	IF ret = 0 THEN
	LDA cvb_RET
	BNE.L cv531
	; 		IF dir <> 0 THEN
	LDA cvb_DIR
	BEQ.L cv532
	; 			ret = 1
	LDA #1
	STA cvb_RET
	; 			an = 0
	LDA #0
	STA cvb_AN
	; 		END IF
cv532:
	; 	END IF
cv531:
	; 	IF ret <> 0 THEN
	LDA cvb_RET
	BEQ.L cv533
	; 		an = an + 1
	INC cvb_AN
	; 		IF an >= 12 THEN
	LDA cvb_AN
	CMP #12
	BCC.L cv534
	; 			ret = 0
	LDA #0
	STA cvb_RET
	; 			dir = 0
	STA cvb_DIR
	; 			an = 0
	STA cvb_AN
	; 		ELSE
	JMP cv535
cv534:
	; 			slot = 6 - an / 4
	LDA #6
	LDY #0
	PHA
	TYA
	PHA
	LDA cvb_AN
	STY temp
	LSR temp
	ROR A
	LSR temp
	ROR A
	LDY temp
	STA temp
	STY temp+1
	PLA
	TAY
	PLA
	SEC
	SBC temp
	TAX
	TYA
	SBC temp+1
	TAY
	TXA
	STA cvb_SLOT
	; 		END IF
cv535:
	; 	ELSE
	JMP cv536
cv533:
	; 		an = an + 1
	INC cvb_AN
	; 		IF an > 19 THEN an = 0
	LDA cvb_AN
	CMP #20
	BCC.L cv537
	LDA #0
	STA cvb_AN
cv537:
	; 		slot = (an / 5) % 4
	LDA cvb_AN
	LDY #0
	LDX #5
	STX temp
	LDX #0
	STX temp+1
	JSR _div16
	AND #3
	STA cvb_SLOT
	; 	END IF
cv536:
	; 	END
	RTS
	; 
	; 	' ===== FONTE SAULO v0.17 — FIM =====
	; 
	; 	' v0.28: acentos da spritefont do Saulo (tecnica dele: glifo na
	; 	' "linha logo acima da letra acentuada") em 3 tiles livres da
	; 	' pagina 0. 26 = TIL (cell 13), 27 = AGUDO (cell 11),
	; 	' 28 = CIRCUNFLEXO e 29 = Ç. Uso: VPOKE no slot (linha-1, col); Ç tem glifo proprio.
	; 	' v0.30: padrao dedicado de Ç; tile 96 e a arte do logo, portanto nao e reutilizado.
	; 	CHRROM PATTERN 29
	; 	BITMAP "..3333.."
	; 	BITMAP ".33..33."
	; 	BITMAP "33......"
	; 	BITMAP "33......"
	; 	BITMAP ".33..33."
	; 	BITMAP "..3333.."
	; 	BITMAP "...33..."
	; 	BITMAP "....3..."
	; 
	; 	CHRROM PATTERN 26
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "...3.3.."
	; 	BITMAP "..3.3..."
	; 	BITMAP "........"
	; 	CHRROM PATTERN 27
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "...3...."
	; 	BITMAP "..3....."
	; 	BITMAP "........"
	; 	CHRROM PATTERN 28
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "...3...."
	; 	BITMAP "..3.3..."
	; 	BITMAP "........"
	; 
	; 	CHRROM PATTERN 96
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "...33333"
	; 	BITMAP "...33333"
	; 	BITMAP "..333333"
	; 	BITMAP "..333..."
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "33333.33"
	; 	BITMAP "33333.33"
	; 	BITMAP "33333.33"
	; 	BITMAP "......33"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "3333333."
	; 	BITMAP "3333333."
	; 	BITMAP "33333333"
	; 	BITMAP "3.....33"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "...33333"
	; 	BITMAP "...33333"
	; 	BITMAP "3.333333"
	; 	BITMAP "3.333..."
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "333....3"
	; 	BITMAP "333....3"
	; 	BITMAP "33333.33"
	; 	BITMAP "..333.33"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "..333333"
	; 	BITMAP "..333333"
	; 	BITMAP "3.333333"
	; 	BITMAP "3.333..."
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "33333..."
	; 	BITMAP "33333..."
	; 	BITMAP "33333..."
	; 	BITMAP "........"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "..3.1..."
	; 	BITMAP "......22"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP ".2......"
	; 	BITMAP "........"
	; 	BITMAP "....3..."
	; 	BITMAP "........"
	; 	BITMAP "11111222"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP ".2......"
	; 	BITMAP "....1..."
	; 	BITMAP "........"
	; 	BITMAP ".1112111"
	; 	BITMAP "22111311"
	; 
	; 	BITMAP "........"
	; 	BITMAP "....3.1."
	; 	BITMAP ".......1"
	; 	BITMAP "..2....."
	; 	BITMAP "....1.11"
	; 	BITMAP ".....111"
	; 	BITMAP "11111132"
	; 	BITMAP "22221112"
	; 
	; 	BITMAP "........"
	; 	BITMAP "..1....."
	; 	BITMAP "1...3..."
	; 	BITMAP "1111.1.."
	; 	BITMAP "111111.."
	; 	BITMAP "222211.."
	; 	BITMAP "2332211."
	; 	BITMAP "2222211."
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "..3....."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "..333333"
	; 	BITMAP "..333333"
	; 	BITMAP "...22222"
	; 	BITMAP "........"
	; 	BITMAP "..222222"
	; 	BITMAP "..222222"
	; 	BITMAP "..222222"
	; 	BITMAP "........"
	; 
	; 	BITMAP "333...33"
	; 	BITMAP "333...33"
	; 	BITMAP "22222.22"
	; 	BITMAP "..222.22"
	; 	BITMAP "22222.22"
	; 	BITMAP "22222.22"
	; 	BITMAP "222...22"
	; 	BITMAP "........"
	; 
	; 	BITMAP "3.....33"
	; 	BITMAP "3.....33"
	; 	BITMAP "22222222"
	; 	BITMAP "2222222."
	; 	BITMAP "2......."
	; 	BITMAP "2......."
	; 	BITMAP "2......."
	; 	BITMAP "........"
	; 
	; 	BITMAP "3.333..."
	; 	BITMAP "3.333..."
	; 	BITMAP "2.222222"
	; 	BITMAP "..222222"
	; 	BITMAP "..222..."
	; 	BITMAP "..222..."
	; 	BITMAP "..222..."
	; 	BITMAP "........"
	; 
	; 	BITMAP "..333.33"
	; 	BITMAP "..333.33"
	; 	BITMAP "22222.22"
	; 	BITMAP "22222.22"
	; 	BITMAP "..222.22"
	; 	BITMAP "..222.22"
	; 	BITMAP "..222..2"
	; 	BITMAP "........"
	; 
	; 	BITMAP "3......."
	; 	BITMAP "3......."
	; 	BITMAP "2......."
	; 	BITMAP "2.....22"
	; 	BITMAP "22222222"
	; 	BITMAP "22222222"
	; 	BITMAP "2222222."
	; 	BITMAP "........"
	; 
	; 	BITMAP "..333333"
	; 	BITMAP "..333333"
	; 	BITMAP "..222222"
	; 	BITMAP "2.222..."
	; 	BITMAP "2.222222"
	; 	BITMAP "2.222222"
	; 	BITMAP "..222222"
	; 	BITMAP "........"
	; 
	; 	BITMAP "333....."
	; 	BITMAP "333....."
	; 	BITMAP "222....."
	; 	BITMAP "........"
	; 	BITMAP "22222..."
	; 	BITMAP "22222..."
	; 	BITMAP "22222..."
	; 	BITMAP "........"
	; 
	; 	BITMAP "12222112"
	; 	BITMAP "..111111"
	; 	BITMAP "........"
	; 	BITMAP ".....2.."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "23222311"
	; 	BITMAP "11111111"
	; 	BITMAP "...111.."
	; 	BITMAP ".1......"
	; 	BITMAP ".....1.."
	; 	BITMAP "..3....."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "12322222"
	; 	BITMAP "11111111"
	; 	BITMAP "..1111.."
	; 	BITMAP "........"
	; 	BITMAP ".3....2."
	; 	BITMAP "...1...."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "21312322"
	; 	BITMAP "11111112"
	; 	BITMAP ".1...111"
	; 	BITMAP "....2.11"
	; 	BITMAP "..1....."
	; 	BITMAP "......21"
	; 	BITMAP "...3.1.."
	; 	BITMAP "........"
	; 
	; 	BITMAP "2223211."
	; 	BITMAP "2322211."
	; 	BITMAP "222211.."
	; 	BITMAP "111111.."
	; 	BITMAP "1111...."
	; 	BITMAP "..3.1..."
	; 	BITMAP ".1......"
	; 	BITMAP "........"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "..1....."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "....3333"
	; 	BITMAP "....3222"
	; 	BITMAP "....3222"
	; 	BITMAP "....3222"
	; 	BITMAP "....3222"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "33333333"
	; 	BITMAP "22222222"
	; 	BITMAP "22222222"
	; 	BITMAP "22222222"
	; 	BITMAP "22222222"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "3..33333"
	; 	BITMAP "23.32222"
	; 	BITMAP "23.32222"
	; 	BITMAP "23.32222"
	; 	BITMAP "23.32222"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "3......."
	; 	BITMAP "3......."
	; 	BITMAP "3......."
	; 	BITMAP "3......."
	; 	BITMAP "3......."
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP ".3333333"
	; 	BITMAP "32222222"
	; 	BITMAP "32222222"
	; 	BITMAP "32222222"
	; 	BITMAP "32222222"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "333333.."
	; 	BITMAP "2222223."
	; 	BITMAP "2222223."
	; 	BITMAP "2222223."
	; 	BITMAP "2222223."
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "33333.33"
	; 	BITMAP "22223.32"
	; 	BITMAP "22223.32"
	; 	BITMAP "22223.32"
	; 	BITMAP "22223.32"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "3333..33"
	; 	BITMAP "2223..32"
	; 	BITMAP "2223..32"
	; 	BITMAP "2223..32"
	; 	BITMAP "2223..32"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "3333...."
	; 	BITMAP "2223...."
	; 	BITMAP "2223...."
	; 	BITMAP "2223...."
	; 	BITMAP "2223...."
	; 
	; 	BITMAP "....3222"
	; 	BITMAP "....3222"
	; 	BITMAP "....3222"
	; 	BITMAP "....3222"
	; 	BITMAP "....3222"
	; 	BITMAP "....3222"
	; 	BITMAP "....3222"
	; 	BITMAP "....3222"
	; 
	; 	BITMAP "23332222"
	; 	BITMAP "3...3222"
	; 	BITMAP "3...3222"
	; 	BITMAP "3...3222"
	; 	BITMAP "3...3222"
	; 	BITMAP "3...3222"
	; 	BITMAP "23332222"
	; 	BITMAP "22222222"
	; 
	; 	BITMAP "23.32222"
	; 	BITMAP "23.32222"
	; 	BITMAP "23.32222"
	; 	BITMAP "23.32222"
	; 	BITMAP "23.32222"
	; 	BITMAP "23.32222"
	; 	BITMAP "23.32222"
	; 	BITMAP "3..32111"
	; 
	; 	BITMAP "3......."
	; 	BITMAP "3......."
	; 	BITMAP "3......."
	; 	BITMAP "3......."
	; 	BITMAP "3......."
	; 	BITMAP "3......."
	; 	BITMAP "3......."
	; 	BITMAP "3......."
	; 
	; 	BITMAP "32222222"
	; 	BITMAP "32222222"
	; 	BITMAP "32222233"
	; 	BITMAP "322223.."
	; 	BITMAP "322223.."
	; 	BITMAP "322223.."
	; 	BITMAP "322223.."
	; 	BITMAP "311113.."
	; 
	; 	BITMAP "2222223."
	; 	BITMAP "2222223."
	; 	BITMAP "3222223."
	; 	BITMAP ".322223."
	; 	BITMAP ".322223."
	; 	BITMAP ".322223."
	; 	BITMAP ".322223."
	; 	BITMAP ".311113."
	; 
	; 	BITMAP "32222222"
	; 	BITMAP "32222222"
	; 	BITMAP "32222233"
	; 	BITMAP "322223.."
	; 	BITMAP "322223.."
	; 	BITMAP "32222233"
	; 	BITMAP "32222222"
	; 	BITMAP "31111111"
	; 
	; 	BITMAP "22223.32"
	; 	BITMAP "22223.32"
	; 	BITMAP "33333.33"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "3333...."
	; 	BITMAP "22223..."
	; 	BITMAP "11123..."
	; 
	; 	BITMAP "22222222"
	; 	BITMAP "22222222"
	; 	BITMAP "33222222"
	; 	BITMAP "..322223"
	; 	BITMAP "..322223"
	; 	BITMAP "..322223"
	; 	BITMAP "..322223"
	; 	BITMAP "..322223"
	; 
	; 	BITMAP "2223..32"
	; 	BITMAP "2223..32"
	; 	BITMAP "3333..32"
	; 	BITMAP "......32"
	; 	BITMAP "......32"
	; 	BITMAP "......32"
	; 	BITMAP "......32"
	; 	BITMAP "......32"
	; 
	; 	BITMAP "2223...."
	; 	BITMAP "2223...."
	; 	BITMAP "2223...."
	; 	BITMAP "2223...."
	; 	BITMAP "2223...."
	; 	BITMAP "2223...."
	; 	BITMAP "2223...."
	; 	BITMAP "2223...."
	; 
	; 	BITMAP "....3222"
	; 	BITMAP "....3111"
	; 	BITMAP "....3111"
	; 	BITMAP "....3111"
	; 	BITMAP "....3111"
	; 	BITMAP "....3111"
	; 	BITMAP "....3111"
	; 	BITMAP "....3111"
	; 
	; 	BITMAP "22211111"
	; 	BITMAP "11111111"
	; 	BITMAP "13331111"
	; 	BITMAP "3...3111"
	; 	BITMAP "3...3111"
	; 	BITMAP "3...3111"
	; 	BITMAP "3...3111"
	; 	BITMAP "3...3111"
	; 
	; 	BITMAP "3..31111"
	; 	BITMAP "3..31111"
	; 	BITMAP "3..31111"
	; 	BITMAP "13.31111"
	; 	BITMAP "13.31111"
	; 	BITMAP "13.31111"
	; 	BITMAP "13.31111"
	; 	BITMAP "13.31111"
	; 
	; 	BITMAP "3......."
	; 	BITMAP "3......."
	; 	BITMAP "3......."
	; 	BITMAP "3......."
	; 	BITMAP "3......."
	; 	BITMAP "3......."
	; 	BITMAP "1333333."
	; 	BITMAP "1111113."
	; 
	; 	BITMAP "31111133"
	; 	BITMAP "31111111"
	; 	BITMAP "31111111"
	; 	BITMAP "31111111"
	; 	BITMAP "31111111"
	; 	BITMAP "31111111"
	; 	BITMAP "31111111"
	; 	BITMAP "31111133"
	; 
	; 	BITMAP "3111113."
	; 	BITMAP "1111113."
	; 	BITMAP "1111113."
	; 	BITMAP "1111113."
	; 	BITMAP "1111113."
	; 	BITMAP "1111113."
	; 	BITMAP "1111113."
	; 	BITMAP "3111113."
	; 
	; 	BITMAP "31111111"
	; 	BITMAP "31111111"
	; 	BITMAP "31111111"
	; 	BITMAP "31111111"
	; 	BITMAP ".3333331"
	; 	BITMAP ".......3"
	; 	BITMAP "33333331"
	; 	BITMAP "31111111"
	; 
	; 	BITMAP "11113..."
	; 	BITMAP "11113..."
	; 	BITMAP "11113..."
	; 	BITMAP "11113..."
	; 	BITMAP "11113..."
	; 	BITMAP "11113..."
	; 	BITMAP "11113..."
	; 	BITMAP "11113..."
	; 
	; 	BITMAP "..311113"
	; 	BITMAP "..311113"
	; 	BITMAP "..311113"
	; 	BITMAP "..311113"
	; 	BITMAP "..311113"
	; 	BITMAP "..311113"
	; 	BITMAP "..311113"
	; 	BITMAP "..311113"
	; 
	; 	BITMAP "......32"
	; 	BITMAP "......31"
	; 	BITMAP "......31"
	; 	BITMAP "......31"
	; 	BITMAP "......31"
	; 	BITMAP "......33"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "2223...."
	; 	BITMAP "1113...."
	; 	BITMAP "1113...."
	; 	BITMAP "1113...."
	; 	BITMAP "1113...."
	; 	BITMAP "3333...."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "....3111"
	; 	BITMAP "....3111"
	; 	BITMAP "....3111"
	; 	BITMAP "....3111"
	; 	BITMAP "....3111"
	; 	BITMAP "....3333"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "13331111"
	; 	BITMAP "11111111"
	; 	BITMAP "11111111"
	; 	BITMAP "11111111"
	; 	BITMAP "11111111"
	; 	BITMAP "33333333"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "13.31111"
	; 	BITMAP "13.31111"
	; 	BITMAP "13.31111"
	; 	BITMAP "13.31111"
	; 	BITMAP "13.31111"
	; 	BITMAP "3..33333"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "1111113."
	; 	BITMAP "1111113."
	; 	BITMAP "1111113."
	; 	BITMAP "1111113."
	; 	BITMAP "1111113."
	; 	BITMAP "3333333."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "311113.."
	; 	BITMAP "311113.."
	; 	BITMAP "311113.."
	; 	BITMAP "311113.."
	; 	BITMAP "311113.."
	; 	BITMAP "333333.."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP ".311113."
	; 	BITMAP ".311113."
	; 	BITMAP ".311113."
	; 	BITMAP ".311113."
	; 	BITMAP ".311113."
	; 	BITMAP ".333333."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "31111111"
	; 	BITMAP "31111111"
	; 	BITMAP "31111111"
	; 	BITMAP "31111111"
	; 	BITMAP "31111111"
	; 	BITMAP "33333333"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "11113..."
	; 	BITMAP "11113..."
	; 	BITMAP "11113..."
	; 	BITMAP "11113..."
	; 	BITMAP "11113..."
	; 	BITMAP "3333...."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "..311113"
	; 	BITMAP "..311113"
	; 	BITMAP "..311113"
	; 	BITMAP "..311113"
	; 	BITMAP "..311113"
	; 	BITMAP "..333333"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "......33"
	; 	BITMAP "......31"
	; 	BITMAP "......31"
	; 	BITMAP "......31"
	; 	BITMAP "......31"
	; 	BITMAP "......33"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "3333...."
	; 	BITMAP "1113...."
	; 	BITMAP "1113...."
	; 	BITMAP "1113...."
	; 	BITMAP "1113...."
	; 	BITMAP "3333...."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	' bullet "•" do rodape (bits 3, sai ciano na regiao pal3)
	; 	BITMAP "........"
	; 	BITMAP "...33..."
	; 	BITMAP "..3333.."
	; 	BITMAP "..3333.."
	; 	BITMAP "...33..."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	CHRROM PATTERN 268
	; 	' Explosao (padroes 268-271, frames 13 e 15)
	; 	BITMAP "................"
	; 	BITMAP "..1..........1.."
	; 	BITMAP ".3.1........1.3."
	; 	BITMAP "..3.1......1.3.."
	; 	BITMAP "...3.11..11.3..."
	; 	BITMAP "....33122133...."
	; 	BITMAP "...3122222213..."
	; 	BITMAP "..112222222211.."
	; 	BITMAP "..112222222211.."
	; 	BITMAP "...3122222213..."
	; 	BITMAP "....33122133...."
	; 	BITMAP "...3.11..11.3..."
	; 	BITMAP "..3.1......1.3.."
	; 	BITMAP ".3.1........1.3."
	; 	BITMAP "..1..........1.."
	; 	BITMAP "................"
	; 
	; 	'
	; 	' Nave do jogador (16x16, 4 sprites em camadas):
	; 	'   corpoE (pal 0) / corpoD (pal 0) / canopy (pal 1) / chama (pal 2)
	; 	'   11 slots de animacao, metade 8x16 cada: f = 21 + slot*8 + metade*2
	; 	'   slots 0-3 = idle, 4-6 = virando p/ direita, 7-10 = segurando p/ direita (orig 10-13)
	; 	'   (lado esquerdo = mesmo desenho com H-FLIP, atributo +$40)
	; 	'
	; 	CHRROM PATTERN 276
	; 	' slot 0 = frame original 0
	; 	' corpoE f=21
	; 	BITMAP "........"
	; 	BITMAP ".......1"
	; 	BITMAP "......12"
	; 	BITMAP ".....112"
	; 	BITMAP ".....232"
	; 	BITMAP ".....121"
	; 	BITMAP ".....111"
	; 	BITMAP "....1122"
	; 	BITMAP "...11221"
	; 	BITMAP "..122311"
	; 	BITMAP ".1121121"
	; 	BITMAP ".1111133"
	; 	BITMAP ".1112121"
	; 	BITMAP ".23..213"
	; 	BITMAP "11......"
	; 	BITMAP "........"
	; 	' corpoD f=23
	; 	BITMAP "........"
	; 	BITMAP "1......."
	; 	BITMAP "21......"
	; 	BITMAP "211....."
	; 	BITMAP "332....."
	; 	BITMAP "121....."
	; 	BITMAP "111....."
	; 	BITMAP "2211...."
	; 	BITMAP "12211..."
	; 	BITMAP "113221.."
	; 	BITMAP "1211211."
	; 	BITMAP "3311111."
	; 	BITMAP "1212111."
	; 	BITMAP "312..32."
	; 	BITMAP "......11"
	; 	BITMAP "........"
	; 	' canopy f=25
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "...22..."
	; 	BITMAP "...22..."
	; 	BITMAP "...23..."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP ".1....1."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "...11..."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	' chama  f=27
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "...22..."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	' slot 1 = frame original 1
	; 	' corpoE f=29
	; 	BITMAP "........"
	; 	BITMAP ".......1"
	; 	BITMAP "......12"
	; 	BITMAP ".....112"
	; 	BITMAP ".....232"
	; 	BITMAP ".....121"
	; 	BITMAP ".....111"
	; 	BITMAP "....1122"
	; 	BITMAP "...11221"
	; 	BITMAP "..122311"
	; 	BITMAP ".1121121"
	; 	BITMAP ".1111122"
	; 	BITMAP ".1112111"
	; 	BITMAP ".23..1.2"
	; 	BITMAP "11.....1"
	; 	BITMAP "........"
	; 	' corpoD f=31
	; 	BITMAP "........"
	; 	BITMAP "1......."
	; 	BITMAP "21......"
	; 	BITMAP "211....."
	; 	BITMAP "232....."
	; 	BITMAP "121....."
	; 	BITMAP "111....."
	; 	BITMAP "2211...."
	; 	BITMAP "12211..."
	; 	BITMAP "113221.."
	; 	BITMAP "1211211."
	; 	BITMAP "2211111."
	; 	BITMAP "1112111."
	; 	BITMAP "2.1..32."
	; 	BITMAP "1.....11"
	; 	BITMAP "........"
	; 	' canopy f=33
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "...22..."
	; 	BITMAP "...22..."
	; 	BITMAP "...22..."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP ".1....1."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "...11..."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	' chama  f=35
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "...22..."
	; 	BITMAP "........"
	; 	BITMAP "..2222.."
	; 	BITMAP ".121121."
	; 	BITMAP ".2.22.2."
	; 	BITMAP "...22..."
	; 	BITMAP "........"
	; 	' slot 2 = frame original 2
	; 	' corpoE f=37
	; 	BITMAP "........"
	; 	BITMAP ".......1"
	; 	BITMAP "......12"
	; 	BITMAP ".....112"
	; 	BITMAP ".....232"
	; 	BITMAP ".....121"
	; 	BITMAP ".....111"
	; 	BITMAP "....1122"
	; 	BITMAP "...11221"
	; 	BITMAP "..122311"
	; 	BITMAP ".1121121"
	; 	BITMAP ".1111133"
	; 	BITMAP ".1112121"
	; 	BITMAP ".23..2.3"
	; 	BITMAP "11....23"
	; 	BITMAP ".......2"
	; 	' corpoD f=39
	; 	BITMAP "........"
	; 	BITMAP "1......."
	; 	BITMAP "21......"
	; 	BITMAP "211....."
	; 	BITMAP "332....."
	; 	BITMAP "121....."
	; 	BITMAP "111....."
	; 	BITMAP "2211...."
	; 	BITMAP "12211..."
	; 	BITMAP "113221.."
	; 	BITMAP "1211211."
	; 	BITMAP "3311111."
	; 	BITMAP "1212111."
	; 	BITMAP "3.2..32."
	; 	BITMAP "32....11"
	; 	BITMAP "2......."
	; 	' canopy f=41
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "...22..."
	; 	BITMAP "...22..."
	; 	BITMAP "...23..."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP ".1....1."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "...11..."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	' chama  f=43
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "...22..."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "..2..2.."
	; 	BITMAP "...22..."
	; 	' slot 3 = frame original 3
	; 	' corpoE f=45
	; 	BITMAP "........"
	; 	BITMAP ".......1"
	; 	BITMAP "......12"
	; 	BITMAP ".....112"
	; 	BITMAP ".....232"
	; 	BITMAP ".....121"
	; 	BITMAP ".....111"
	; 	BITMAP "....1122"
	; 	BITMAP "...11221"
	; 	BITMAP "..122311"
	; 	BITMAP ".1121121"
	; 	BITMAP ".1111122"
	; 	BITMAP ".1112111"
	; 	BITMAP ".23..1.2"
	; 	BITMAP "11.....2"
	; 	BITMAP ".......2"
	; 	' corpoD f=47
	; 	BITMAP "........"
	; 	BITMAP "1......."
	; 	BITMAP "21......"
	; 	BITMAP "211....."
	; 	BITMAP "232....."
	; 	BITMAP "121....."
	; 	BITMAP "111....."
	; 	BITMAP "2211...."
	; 	BITMAP "12211..."
	; 	BITMAP "113221.."
	; 	BITMAP "1211211."
	; 	BITMAP "2211111."
	; 	BITMAP "1112111."
	; 	BITMAP "2.1..32."
	; 	BITMAP "2.....11"
	; 	BITMAP "2......."
	; 	' canopy f=49
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "...22..."
	; 	BITMAP "...22..."
	; 	BITMAP "...22..."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP ".1....1."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "...11..."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	' chama  f=51
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "...22..."
	; 	BITMAP "........"
	; 	BITMAP "..2222.."
	; 	BITMAP ".121121."
	; 	BITMAP ".2.22.2."
	; 	BITMAP "...22..."
	; 	BITMAP "...22..."
	; 	' slot 4 = frame original 4
	; 	' corpoE f=53
	; 	BITMAP "........"
	; 	BITMAP ".......1"
	; 	BITMAP "......12"
	; 	BITMAP ".....112"
	; 	BITMAP ".....232"
	; 	BITMAP ".....121"
	; 	BITMAP ".....111"
	; 	BITMAP "....1122"
	; 	BITMAP "...11221"
	; 	BITMAP "..122311"
	; 	BITMAP ".1121121"
	; 	BITMAP ".1111133"
	; 	BITMAP ".1112121"
	; 	BITMAP ".23..2.3"
	; 	BITMAP "11....23"
	; 	BITMAP ".......2"
	; 	' corpoD f=55
	; 	BITMAP "........"
	; 	BITMAP "1......."
	; 	BITMAP "21......"
	; 	BITMAP "211....."
	; 	BITMAP "332....."
	; 	BITMAP "121....."
	; 	BITMAP "111....."
	; 	BITMAP "2211...."
	; 	BITMAP "12211..."
	; 	BITMAP "113221.."
	; 	BITMAP "1211211."
	; 	BITMAP "3311111."
	; 	BITMAP "1212111."
	; 	BITMAP "3.2..32."
	; 	BITMAP "32....11"
	; 	BITMAP "2......."
	; 	' canopy f=57
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "...22..."
	; 	BITMAP "...22..."
	; 	BITMAP "...23..."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP ".1....1."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "...11..."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	' chama  f=59
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "...22..."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "..2..2.."
	; 	BITMAP "...22..."
	; 	' slot 5 = frame original 5
	; 	' corpoE f=61
	; 	BITMAP "........"
	; 	BITMAP ".......1"
	; 	BITMAP "......12"
	; 	BITMAP ".....112"
	; 	BITMAP ".....212"
	; 	BITMAP ".....121"
	; 	BITMAP ".....111"
	; 	BITMAP "...11221"
	; 	BITMAP "..122221"
	; 	BITMAP ".1122211"
	; 	BITMAP ".1112121"
	; 	BITMAP ".1111231"
	; 	BITMAP ".23.1111"
	; 	BITMAP "11...112"
	; 	BITMAP ".......1"
	; 	BITMAP "........"
	; 	' corpoD f=63
	; 	BITMAP "........"
	; 	BITMAP "1......."
	; 	BITMAP "2......."
	; 	BITMAP "21......"
	; 	BITMAP "321....."
	; 	BITMAP "111....."
	; 	BITMAP "111....."
	; 	BITMAP "211....."
	; 	BITMAP "1221...."
	; 	BITMAP "21121..."
	; 	BITMAP "1132111."
	; 	BITMAP "311131.."
	; 	BITMAP "111111.."
	; 	BITMAP "211.121."
	; 	BITMAP "1....12."
	; 	BITMAP "........"
	; 	' canopy f=65
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "...22..."
	; 	BITMAP "...22..."
	; 	BITMAP "..123..."
	; 	BITMAP "........"
	; 	BITMAP ".1......"
	; 	BITMAP ".....11."
	; 	BITMAP "........"
	; 	BITMAP "...1.1.."
	; 	BITMAP "....1..."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	' chama  f=67
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "....2..."
	; 	BITMAP "........"
	; 	BITMAP "...2.2.."
	; 	BITMAP ".121111."
	; 	BITMAP ".112221."
	; 	BITMAP "...22..."
	; 	BITMAP "........"
	; 	' slot 6 = frame original 6
	; 	' corpoE f=69
	; 	BITMAP "........"
	; 	BITMAP ".......1"
	; 	BITMAP ".......2"
	; 	BITMAP ".....111"
	; 	BITMAP ".....123"
	; 	BITMAP ".....112"
	; 	BITMAP "....1111"
	; 	BITMAP "..122212"
	; 	BITMAP ".1122312"
	; 	BITMAP ".1211111"
	; 	BITMAP ".1131111"
	; 	BITMAP ".2312121"
	; 	BITMAP "11...221"
	; 	BITMAP "......13"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	' corpoD f=71
	; 	BITMAP "........"
	; 	BITMAP "1......."
	; 	BITMAP "2......."
	; 	BITMAP "21......"
	; 	BITMAP "321....."
	; 	BITMAP "111....."
	; 	BITMAP "11......"
	; 	BITMAP "121....."
	; 	BITMAP "111....."
	; 	BITMAP "1111...."
	; 	BITMAP "11211..."
	; 	BITMAP "23212..."
	; 	BITMAP "11111..."
	; 	BITMAP "321211.."
	; 	BITMAP "....11.."
	; 	BITMAP "........"
	; 	' canopy f=73
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "...22..."
	; 	BITMAP "....2..."
	; 	BITMAP "....3..."
	; 	BITMAP "........"
	; 	BITMAP ".1......"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "....1.1."
	; 	BITMAP ".....1.."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	' chama  f=75
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP ".....2.."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	' slot 7 = frame original 10
	; 	' corpoE f=77
	; 	BITMAP "........"
	; 	BITMAP ".......1"
	; 	BITMAP ".......1"
	; 	BITMAP ".....111"
	; 	BITMAP ".....121"
	; 	BITMAP ".....112"
	; 	BITMAP "....1111"
	; 	BITMAP "..122212"
	; 	BITMAP ".1122312"
	; 	BITMAP ".1211111"
	; 	BITMAP ".1131111"
	; 	BITMAP ".2312121"
	; 	BITMAP "11...221"
	; 	BITMAP "......13"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	' corpoD f=79
	; 	BITMAP "........"
	; 	BITMAP "1......."
	; 	BITMAP "2......."
	; 	BITMAP "21......"
	; 	BITMAP "321....."
	; 	BITMAP "111....."
	; 	BITMAP "11......"
	; 	BITMAP "121....."
	; 	BITMAP "111....."
	; 	BITMAP "1111...."
	; 	BITMAP "11211..."
	; 	BITMAP "23212..."
	; 	BITMAP "11111..."
	; 	BITMAP "321211.."
	; 	BITMAP "....11.."
	; 	BITMAP "........"
	; 	' canopy f=81
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "...22..."
	; 	BITMAP "....2..."
	; 	BITMAP "....3..."
	; 	BITMAP "........"
	; 	BITMAP ".1......"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "....1.1."
	; 	BITMAP ".....1.."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	' chama  f=83
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP ".....2.."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	' slot 8 = frame original 11
	; 	' corpoE f=85
	; 	BITMAP "........"
	; 	BITMAP ".......1"
	; 	BITMAP ".......2"
	; 	BITMAP ".....111"
	; 	BITMAP ".....121"
	; 	BITMAP ".....112"
	; 	BITMAP "....1111"
	; 	BITMAP "..122212"
	; 	BITMAP ".1122312"
	; 	BITMAP ".1211111"
	; 	BITMAP ".1131111"
	; 	BITMAP ".2312111"
	; 	BITMAP "11...111"
	; 	BITMAP "......12"
	; 	BITMAP ".......1"
	; 	BITMAP "........"
	; 	' corpoD f=87
	; 	BITMAP "........"
	; 	BITMAP "1......."
	; 	BITMAP "2......."
	; 	BITMAP "21......"
	; 	BITMAP "321....."
	; 	BITMAP "111....."
	; 	BITMAP "11......"
	; 	BITMAP "121....."
	; 	BITMAP "111....."
	; 	BITMAP "1111...."
	; 	BITMAP "11211..."
	; 	BITMAP "12212..."
	; 	BITMAP "11111..."
	; 	BITMAP "211211.."
	; 	BITMAP "1...11.."
	; 	BITMAP "........"
	; 	' canopy f=89
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "...22..."
	; 	BITMAP "....2..."
	; 	BITMAP "....3..."
	; 	BITMAP "........"
	; 	BITMAP ".1......"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "....1.1."
	; 	BITMAP ".....1.."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	' chama  f=91
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP ".....2.."
	; 	BITMAP "........"
	; 	BITMAP "..2.22.."
	; 	BITMAP ".221111."
	; 	BITMAP "..1222.."
	; 	BITMAP "...22..."
	; 	BITMAP "........"
	; 	' slot 9 = frame original 12
	; 	' corpoE f=93
	; 	BITMAP "........"
	; 	BITMAP ".......1"
	; 	BITMAP ".......1"
	; 	BITMAP ".....111"
	; 	BITMAP ".....121"
	; 	BITMAP ".....112"
	; 	BITMAP "....1111"
	; 	BITMAP "..122212"
	; 	BITMAP ".1122312"
	; 	BITMAP ".1211111"
	; 	BITMAP ".1131111"
	; 	BITMAP ".2312121"
	; 	BITMAP "11...221"
	; 	BITMAP "......13"
	; 	BITMAP "......23"
	; 	BITMAP ".......2"
	; 	' corpoD f=95
	; 	BITMAP "........"
	; 	BITMAP "1......."
	; 	BITMAP "2......."
	; 	BITMAP "21......"
	; 	BITMAP "321....."
	; 	BITMAP "111....."
	; 	BITMAP "11......"
	; 	BITMAP "121....."
	; 	BITMAP "111....."
	; 	BITMAP "1111...."
	; 	BITMAP "11211..."
	; 	BITMAP "23212..."
	; 	BITMAP "11111..."
	; 	BITMAP "311211.."
	; 	BITMAP "32..11.."
	; 	BITMAP "2......."
	; 	' canopy f=97
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "...22..."
	; 	BITMAP "....2..."
	; 	BITMAP "....3..."
	; 	BITMAP "........"
	; 	BITMAP ".1......"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "....1.1."
	; 	BITMAP ".....1.."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	' chama  f=99
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP ".....2.."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP ".....2.."
	; 	BITMAP "..2..2.."
	; 	BITMAP "...22..."
	; 	' slot 10 = frame original 13
	; 	' corpoE f=101
	; 	BITMAP "........"
	; 	BITMAP ".......1"
	; 	BITMAP ".......2"
	; 	BITMAP ".....111"
	; 	BITMAP ".....121"
	; 	BITMAP ".....112"
	; 	BITMAP "....1111"
	; 	BITMAP "..122212"
	; 	BITMAP ".1122312"
	; 	BITMAP ".1211111"
	; 	BITMAP ".1131111"
	; 	BITMAP ".2312111"
	; 	BITMAP "11...111"
	; 	BITMAP ".......2"
	; 	BITMAP ".......2"
	; 	BITMAP ".......2"
	; 	' corpoD f=103
	; 	BITMAP "........"
	; 	BITMAP "1......."
	; 	BITMAP "2......."
	; 	BITMAP "21......"
	; 	BITMAP "321....."
	; 	BITMAP "111....."
	; 	BITMAP "11......"
	; 	BITMAP "121....."
	; 	BITMAP "111....."
	; 	BITMAP "1111...."
	; 	BITMAP "11211..."
	; 	BITMAP "12212..."
	; 	BITMAP "11111..."
	; 	BITMAP "2.1211.."
	; 	BITMAP "2...11.."
	; 	BITMAP "2......."
	; 	' canopy f=105
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "...22..."
	; 	BITMAP "....2..."
	; 	BITMAP "....3..."
	; 	BITMAP "........"
	; 	BITMAP ".1......"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "....1.1."
	; 	BITMAP ".....1.."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	' chama  f=107
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP ".....2.."
	; 	BITMAP "........"
	; 	BITMAP "..2.22.."
	; 	BITMAP ".221111."
	; 	BITMAP "...22..."
	; 	BITMAP "...22..."
	; 	BITMAP "...22..."
	; 	' ======= SPACE BLAST (ex-Caravan Blast): arte convertida do jogo HTML5 =======
	; 	' f: tiro03 113/115 | small 113+4+4i/115+4+4i (esq=HFLIP) | shard 125/127/129/131 | ebullet 133/135
	; 	' tiles: tiro03 364-367 | small 368-379 | shard 380-387 | ebullet 388-391
	; 	CHRROM PATTERN 364
	; 	' tiro03 fr0 f=113
	; 	BITMAP "........"
	; 	BITMAP "...11..."
	; 	BITMAP "...12..."
	; 	BITMAP ".2112.21"
	; 	BITMAP ".2112.21"
	; 	BITMAP ".2112.21"
	; 	BITMAP ".21.1.21"
	; 	BITMAP ".21...21"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	' tiro03 fr1 f=115
	; 	BITMAP "........"
	; 	BITMAP "....2..."
	; 	BITMAP ".2.23.2."
	; 	BITMAP ".3223.32"
	; 	BITMAP ".3223.32"
	; 	BITMAP ".3223.32"
	; 	BITMAP ".3223.32"
	; 	BITMAP ".2....2."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	' small fr13 metade0 f=117 (16x16 real)
	; 	BITMAP "........"
	; 	BITMAP ".......2"
	; 	BITMAP ".......3"
	; 	BITMAP "....33.1"
	; 	BITMAP "...333.1"
	; 	BITMAP "..3333.3"
	; 	BITMAP "..333223"
	; 	BITMAP "..1332.3"
	; 	BITMAP "..1332.3"
	; 	BITMAP "..1333.3"
	; 	BITMAP "..133313"
	; 	BITMAP "..3333.3"
	; 	BITMAP "..3333.3"
	; 	BITMAP "...333.."
	; 	BITMAP "....33.."
	; 	BITMAP ".....3.."
	; 	' small fr13 metade1 f=119 (16x16 real)
	; 	BITMAP "........"
	; 	BITMAP "22......"
	; 	BITMAP "33......"
	; 	BITMAP "33.3...."
	; 	BITMAP "33333..."
	; 	BITMAP "3.3333.."
	; 	BITMAP "113333.."
	; 	BITMAP "1.3333.."
	; 	BITMAP "333333.."
	; 	BITMAP "33.233.."
	; 	BITMAP "132233.."
	; 	BITMAP "13.233.."
	; 	BITMAP "...233.."
	; 	BITMAP "...233.."
	; 	BITMAP "..333..."
	; 	BITMAP "..33...."
	; 	' small fr15 metade0 f=121 (16x16 real)
	; 	BITMAP "........"
	; 	BITMAP ".......2"
	; 	BITMAP ".......3"
	; 	BITMAP ".....3.3"
	; 	BITMAP "....3333"
	; 	BITMAP "...3333."
	; 	BITMAP "...33331"
	; 	BITMAP "...1333."
	; 	BITMAP "...13333"
	; 	BITMAP "...132.3"
	; 	BITMAP "...13223"
	; 	BITMAP "...332.3"
	; 	BITMAP "...332.."
	; 	BITMAP "....32.."
	; 	BITMAP "....333."
	; 	BITMAP ".....33."
	; 	' small fr15 metade1 f=123 (16x16 real)
	; 	BITMAP "........"
	; 	BITMAP "22......"
	; 	BITMAP "33......"
	; 	BITMAP "3333...."
	; 	BITMAP "33333..."
	; 	BITMAP "3.333..."
	; 	BITMAP "11233..."
	; 	BITMAP "1.233..."
	; 	BITMAP "33233..."
	; 	BITMAP "33333..."
	; 	BITMAP "13333..."
	; 	BITMAP "13333..."
	; 	BITMAP "..333..."
	; 	BITMAP "..333..."
	; 	BITMAP "..33...."
	; 	BITMAP "..3....."
	; 	' small fr18 metade0 f=125 (16x16 real)
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP ".......3"
	; 	BITMAP ".......3"
	; 	BITMAP ".......3"
	; 	BITMAP "......33"
	; 	BITMAP "......31"
	; 	BITMAP "......31"
	; 	BITMAP "......31"
	; 	BITMAP "......31"
	; 	BITMAP "......31"
	; 	BITMAP "......33"
	; 	BITMAP ".......3"
	; 	BITMAP ".......3"
	; 	BITMAP "........"
	; 	' small fr18 metade1 f=127 (16x16 real)
	; 	BITMAP "2......."
	; 	BITMAP "2......."
	; 	BITMAP "333....."
	; 	BITMAP "133....."
	; 	BITMAP "333....."
	; 	BITMAP "333....."
	; 	BITMAP "313....."
	; 	BITMAP "313....."
	; 	BITMAP "333....."
	; 	BITMAP "333....."
	; 	BITMAP "213....."
	; 	BITMAP "233....."
	; 	BITMAP "2......."
	; 	BITMAP "2......."
	; 	BITMAP "3......."
	; 	BITMAP "3......."
	; 	' shard fr0 f=125
	; 	BITMAP "........"
	; 	BITMAP "...12..."
	; 	BITMAP "..1121.."
	; 	BITMAP ".112211."
	; 	BITMAP "....1222"
	; 	BITMAP "..21.111"
	; 	BITMAP "...2.11."
	; 	BITMAP ".....1.."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	' shard fr2 f=127
	; 	BITMAP "........"
	; 	BITMAP "...22..."
	; 	BITMAP "..2221.."
	; 	BITMAP ".112.21."
	; 	BITMAP "..1.2.22"
	; 	BITMAP "..12.211"
	; 	BITMAP "...1111."
	; 	BITMAP ".....1.."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	' shard fr5 f=129
	; 	BITMAP "....1..."
	; 	BITMAP "...12..."
	; 	BITMAP "..2..2.."
	; 	BITMAP ".1..2.2."
	; 	BITMAP "1..22..2"
	; 	BITMAP "..2...21"
	; 	BITMAP "...2.21."
	; 	BITMAP ".....1.."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	' shard fr7 f=131
	; 	BITMAP "........"
	; 	BITMAP "...12..."
	; 	BITMAP "..1222.."
	; 	BITMAP ".12..22."
	; 	BITMAP "...33.22"
	; 	BITMAP "..22.211"
	; 	BITMAP "...1.23."
	; 	BITMAP ".....1.."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	' ebullet fr0 f=133
	; 	BITMAP "..1111.."
	; 	BITMAP ".111111."
	; 	BITMAP "11133111"
	; 	BITMAP "11333311"
	; 	BITMAP "11333311"
	; 	BITMAP "11133111"
	; 	BITMAP ".111111."
	; 	BITMAP "..1111.."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	' ebullet fr2 f=135
	; 	BITMAP "..3333.."
	; 	BITMAP ".333333."
	; 	BITMAP "33333333"
	; 	BITMAP "33333333"
	; 	BITMAP "33333333"
	; 	BITMAP "33333333"
	; 	BITMAP ".333333."
	; 	BITMAP "..3333.."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	' Enemy4 (sprite do Saulo, frame estatico, 16x16; gera_enemy4.py)
	; 	CHRROM PATTERN 392
	; 	' enemy4 fr0 metade0 (byte OAM 137)
	; 	BITMAP "...22..."
	; 	BITMAP "..222.22"
	; 	BITMAP ".222.222"
	; 	BITMAP "31222212"
	; 	BITMAP "31222212"
	; 	BITMAP "31222112"
	; 	BITMAP "31222112"
	; 	BITMAP ".2222122"
	; 	BITMAP ".2222221"
	; 	BITMAP "..2..221"
	; 	BITMAP "..2..221"
	; 	BITMAP ".222..23"
	; 	BITMAP ".222...2"
	; 	BITMAP "..222..2"
	; 	BITMAP "..222..."
	; 	BITMAP "...2...."
	; 	CHRROM PATTERN 394
	; 	' enemy4 fr0 metade1 (byte OAM 139)
	; 	BITMAP "...22..."
	; 	BITMAP "22.222.."
	; 	BITMAP "222.222."
	; 	BITMAP "21222213"
	; 	BITMAP "21222213"
	; 	BITMAP "21122213"
	; 	BITMAP "21122213"
	; 	BITMAP "2212222."
	; 	BITMAP "1222222."
	; 	BITMAP "122..2.."
	; 	BITMAP "112..2.."
	; 	BITMAP "32..222."
	; 	BITMAP "2...222."
	; 	BITMAP "2..222.."
	; 	BITMAP "...222.."
	; 	BITMAP "....2..."
	; 
	; 	' MINIBOSS do Saulo (miniboss-1.png: 32x32, 2 frames, pal2;
	; 	' gera_miniboss.py). Onda a cada 4; o codigo troca pal2 p/
	; 	' $03/$23/$38 (cores exatas da arte) e restaura ao morrer.
	; 	' OAM: frame A = bytes 141-155, frame B = 157-171.
	; 	CHRROM PATTERN 396
	; 	' miniboss f0 top col0 (byte OAM 141)
	; 	BITMAP "........"
	; 	BITMAP "1......."
	; 	BITMAP "11......"
	; 	BITMAP "13122221"
	; 	BITMAP "11122221"
	; 	BITMAP "13122221"
	; 	BITMAP "13122221"
	; 	BITMAP "11111111"
	; 	BITMAP ".1.....1"
	; 	BITMAP "...111.."
	; 	BITMAP "..12221."
	; 	BITMAP ".1122211"
	; 	BITMAP ".1322231"
	; 	BITMAP ".1122211"
	; 	BITMAP "..12221."
	; 	BITMAP "...111.."
	; 	CHRROM PATTERN 398
	; 	' miniboss f0 top col1 (byte OAM 143)
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "1......."
	; 	BITMAP "1....1.."
	; 	BITMAP "3....112"
	; 	BITMAP "1....132"
	; 	BITMAP "1..1.112"
	; 	BITMAP "...1.131"
	; 	BITMAP "1.11.11."
	; 	BITMAP "1.111..."
	; 	BITMAP "1.113.11"
	; 	BITMAP ".1.11.1."
	; 	BITMAP ".1.13.31"
	; 	BITMAP ".1.11.11"
	; 	BITMAP "11.13.1."
	; 	BITMAP "...11.12"
	; 	CHRROM PATTERN 400
	; 	' miniboss f0 top col2 (byte OAM 145)
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP ".......1"
	; 	BITMAP "..1....1"
	; 	BITMAP "211....3"
	; 	BITMAP "231....1"
	; 	BITMAP "211.1..1"
	; 	BITMAP "131.1..."
	; 	BITMAP ".11.11.1"
	; 	BITMAP "...111.1"
	; 	BITMAP "11.311.1"
	; 	BITMAP ".1.11.1."
	; 	BITMAP "13.31.1."
	; 	BITMAP "11.11.1."
	; 	BITMAP ".1.31.11"
	; 	BITMAP "21.11..."
	; 	CHRROM PATTERN 402
	; 	' miniboss f0 top col3 (byte OAM 147)
	; 	BITMAP "........"
	; 	BITMAP ".......1"
	; 	BITMAP "......11"
	; 	BITMAP "12222131"
	; 	BITMAP "12222111"
	; 	BITMAP "12222131"
	; 	BITMAP "12222131"
	; 	BITMAP "11111111"
	; 	BITMAP "1.....1."
	; 	BITMAP "..111..."
	; 	BITMAP ".12221.."
	; 	BITMAP "1122211."
	; 	BITMAP "1322231."
	; 	BITMAP "1122211."
	; 	BITMAP ".12221.."
	; 	BITMAP "..111..."
	; 	CHRROM PATTERN 404
	; 	' miniboss f0 bot col0 (byte OAM 149)
	; 	BITMAP "..13331."
	; 	BITMAP "..13331."
	; 	BITMAP "...111.."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP ".......1"
	; 	BITMAP "......11"
	; 	BITMAP "......11"
	; 	BITMAP "......12"
	; 	BITMAP "......12"
	; 	BITMAP "......12"
	; 	BITMAP "......12"
	; 	BITMAP ".....113"
	; 	BITMAP ".....133"
	; 	BITMAP "......11"
	; 	CHRROM PATTERN 406
	; 	' miniboss f0 bot col1 (byte OAM 151)
	; 	BITMAP "11..1112"
	; 	BITMAP "311..111"
	; 	BITMAP "1311..21"
	; 	BITMAP "11311.12"
	; 	BITMAP ".1131.21"
	; 	BITMAP "11113.13"
	; 	BITMAP "11.11.32"
	; 	BITMAP "11....12"
	; 	BITMAP "211..113"
	; 	BITMAP "321.1132"
	; 	BITMAP "221.1.12"
	; 	BITMAP "321...23"
	; 	BITMAP "221...31"
	; 	BITMAP "3311..1."
	; 	BITMAP "3331...."
	; 	BITMAP "111....."
	; 	CHRROM PATTERN 408
	; 	' miniboss f0 bot col2 (byte OAM 153)
	; 	BITMAP "2111..11"
	; 	BITMAP "111..113"
	; 	BITMAP "12..1131"
	; 	BITMAP "21.11311"
	; 	BITMAP "12.1311."
	; 	BITMAP "31.31111"
	; 	BITMAP "23.11.11"
	; 	BITMAP "21....11"
	; 	BITMAP "311..112"
	; 	BITMAP "2311.123"
	; 	BITMAP "21.1.122"
	; 	BITMAP "32...123"
	; 	BITMAP "13...122"
	; 	BITMAP ".1..1133"
	; 	BITMAP "....1333"
	; 	BITMAP ".....111"
	; 	CHRROM PATTERN 410
	; 	' miniboss f0 bot col3 (byte OAM 155)
	; 	BITMAP ".13331.."
	; 	BITMAP ".13331.."
	; 	BITMAP "..111..."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "1......."
	; 	BITMAP "11......"
	; 	BITMAP "11......"
	; 	BITMAP "21......"
	; 	BITMAP "21......"
	; 	BITMAP "21......"
	; 	BITMAP "21......"
	; 	BITMAP "311....."
	; 	BITMAP "331....."
	; 	BITMAP "11......"
	; 	CHRROM PATTERN 412
	; 	' miniboss f1 top col0 (byte OAM 157)
	; 	BITMAP "........"
	; 	BITMAP "1...33.."
	; 	BITMAP "11.3333."
	; 	BITMAP "13122221"
	; 	BITMAP "11122221"
	; 	BITMAP "13122221"
	; 	BITMAP "13122221"
	; 	BITMAP "11111111"
	; 	BITMAP ".1.....1"
	; 	BITMAP "...111.."
	; 	BITMAP "..12221."
	; 	BITMAP ".1122211"
	; 	BITMAP ".1322231"
	; 	BITMAP ".1122211"
	; 	BITMAP "..12221."
	; 	BITMAP "...111.."
	; 	CHRROM PATTERN 414
	; 	' miniboss f1 top col1 (byte OAM 159)
	; 	BITMAP "......33"
	; 	BITMAP ".....333"
	; 	BITMAP "1...3333"
	; 	BITMAP "1...3133"
	; 	BITMAP "3....112"
	; 	BITMAP "1....132"
	; 	BITMAP "1..1.112"
	; 	BITMAP "...1.131"
	; 	BITMAP "1.11.11."
	; 	BITMAP "1.111..."
	; 	BITMAP "1.113.11"
	; 	BITMAP ".1.11.1."
	; 	BITMAP ".1.13.31"
	; 	BITMAP ".1.11.11"
	; 	BITMAP "11.13.1."
	; 	BITMAP "...11.12"
	; 	CHRROM PATTERN 416
	; 	' miniboss f1 top col2 (byte OAM 161)
	; 	BITMAP "33......"
	; 	BITMAP "333....."
	; 	BITMAP "3333...1"
	; 	BITMAP "3313...1"
	; 	BITMAP "211....3"
	; 	BITMAP "231....1"
	; 	BITMAP "211.1..1"
	; 	BITMAP "131.1..."
	; 	BITMAP ".11.11.1"
	; 	BITMAP "...111.1"
	; 	BITMAP "11.311.1"
	; 	BITMAP ".1.11.1."
	; 	BITMAP "13.31.1."
	; 	BITMAP "11.11.1."
	; 	BITMAP ".1.31.11"
	; 	BITMAP "21.11..."
	; 	CHRROM PATTERN 418
	; 	' miniboss f1 top col3 (byte OAM 163)
	; 	BITMAP "........"
	; 	BITMAP "..33...1"
	; 	BITMAP ".3333.11"
	; 	BITMAP "12222131"
	; 	BITMAP "12222111"
	; 	BITMAP "12222131"
	; 	BITMAP "12222131"
	; 	BITMAP "11111111"
	; 	BITMAP "1.....1."
	; 	BITMAP "..111..."
	; 	BITMAP ".12221.."
	; 	BITMAP "1122211."
	; 	BITMAP "1322231."
	; 	BITMAP "1122211."
	; 	BITMAP ".12221.."
	; 	BITMAP "..111..."
	; 	CHRROM PATTERN 420
	; 	' miniboss f1 bot col0 (byte OAM 165)
	; 	BITMAP "..13331."
	; 	BITMAP "..13331."
	; 	BITMAP "...111.."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP ".......1"
	; 	BITMAP "......11"
	; 	BITMAP "......11"
	; 	BITMAP "......12"
	; 	BITMAP "......12"
	; 	BITMAP "......12"
	; 	BITMAP "......12"
	; 	BITMAP ".....113"
	; 	BITMAP ".....133"
	; 	BITMAP "......11"
	; 	CHRROM PATTERN 422
	; 	' miniboss f1 bot col1 (byte OAM 167)
	; 	BITMAP "11..1112"
	; 	BITMAP "311..111"
	; 	BITMAP "1311..21"
	; 	BITMAP "11311.12"
	; 	BITMAP ".1131.21"
	; 	BITMAP "11113.13"
	; 	BITMAP "11.11.32"
	; 	BITMAP "11....12"
	; 	BITMAP "211..113"
	; 	BITMAP "321.1132"
	; 	BITMAP "221.1.12"
	; 	BITMAP "321...23"
	; 	BITMAP "221...31"
	; 	BITMAP "3311..1."
	; 	BITMAP "3331...."
	; 	BITMAP "111....."
	; 	CHRROM PATTERN 424
	; 	' miniboss f1 bot col2 (byte OAM 169)
	; 	BITMAP "2111..11"
	; 	BITMAP "111..113"
	; 	BITMAP "12..1131"
	; 	BITMAP "21.11311"
	; 	BITMAP "12.1311."
	; 	BITMAP "31.31111"
	; 	BITMAP "23.11.11"
	; 	BITMAP "21....11"
	; 	BITMAP "311..112"
	; 	BITMAP "2311.123"
	; 	BITMAP "21.1.122"
	; 	BITMAP "32...123"
	; 	BITMAP "13...122"
	; 	BITMAP ".1..1133"
	; 	BITMAP "....1333"
	; 	BITMAP ".....111"
	; 	CHRROM PATTERN 426
	; 	' miniboss f1 bot col3 (byte OAM 171)
	; 	BITMAP ".13331.."
	; 	BITMAP ".13331.."
	; 	BITMAP "..111..."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "1......."
	; 	BITMAP "11......"
	; 	BITMAP "11......"
	; 	BITMAP "21......"
	; 	BITMAP "21......"
	; 	BITMAP "21......"
	; 	BITMAP "21......"
	; 	BITMAP "311....."
	; 	BITMAP "331....."
	; 	BITMAP "11......"
	; 	' Laser do Saulo (16x32, pal3 ciano; gera_boss.py)
	; 	CHRROM PATTERN 428
	; 	' laser L cima (byte OAM 173)
	; 	BITMAP "..2232.."
	; 	BITMAP "...32..."
	; 	BITMAP "..2232.."
	; 	BITMAP "...32..."
	; 	BITMAP "..2232.."
	; 	BITMAP "...32..."
	; 	BITMAP "..2232.."
	; 	BITMAP "...32..."
	; 	BITMAP "..2232.."
	; 	BITMAP "...32..."
	; 	BITMAP "..2232.."
	; 	BITMAP "...32..."
	; 	BITMAP "..2232.."
	; 	BITMAP "...32..."
	; 	BITMAP "..2232.."
	; 	BITMAP "...32..."
	; 	CHRROM PATTERN 430
	; 	' laser L baixo (byte OAM 175)
	; 	BITMAP "..2232.."
	; 	BITMAP "...32..."
	; 	BITMAP "..2232.."
	; 	BITMAP "...32..."
	; 	BITMAP "..2232.."
	; 	BITMAP "...32..."
	; 	BITMAP "..2232.."
	; 	BITMAP "...32..."
	; 	BITMAP "..2232.."
	; 	BITMAP "...32..."
	; 	BITMAP "..2232.."
	; 	BITMAP "...32..."
	; 	BITMAP "..2232.."
	; 	BITMAP "...32..."
	; 	BITMAP "..2232.."
	; 	BITMAP "...32..."
	; 	CHRROM PATTERN 432
	; 	' laser R cima (byte OAM 177)
	; 	BITMAP "..2332.."
	; 	BITMAP "..2332.."
	; 	BITMAP "..2332.."
	; 	BITMAP "..2332.."
	; 	BITMAP "..2332.."
	; 	BITMAP "..2332.."
	; 	BITMAP "..2332.."
	; 	BITMAP "..2332.."
	; 	BITMAP "..2332.."
	; 	BITMAP "..2332.."
	; 	BITMAP "..2332.."
	; 	BITMAP "..2332.."
	; 	BITMAP "..2332.."
	; 	BITMAP "..2332.."
	; 	BITMAP "..2332.."
	; 	BITMAP "..2332.."
	; 	CHRROM PATTERN 434
	; 	' laser R baixo (byte OAM 179)
	; 	BITMAP "..2332.."
	; 	BITMAP "..2332.."
	; 	BITMAP "..2332.."
	; 	BITMAP "..2332.."
	; 	BITMAP "..2332.."
	; 	BITMAP "..2332.."
	; 	BITMAP "..2332.."
	; 	BITMAP "..2332.."
	; 	BITMAP "..2332.."
	; 	BITMAP "..2332.."
	; 	BITMAP "..2332.."
	; 	BITMAP "..2332.."
	; 	BITMAP "..2332.."
	; 	BITMAP "..2332.."
	; 	BITMAP "..2332.."
	; 	BITMAP "..2332.."
	; 	' Tiro novo do player (Saulo, 2 frames 8x8; pal3 ciano;
	; 	' bytes OAM 217/219; gera_boss.py)
	; 	CHRROM PATTERN 472
	; 	BITMAP "........"
	; 	BITMAP "...22..."
	; 	BITMAP "..2222.."
	; 	BITMAP "..2222.."
	; 	BITMAP "..2222.."
	; 	BITMAP "..2222.."
	; 	BITMAP "...22..."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	CHRROM PATTERN 474
	; 	BITMAP "........"
	; 	BITMAP "...33..."
	; 	BITMAP "..2332.."
	; 	BITMAP "..2332.."
	; 	BITMAP "..2332.."
	; 	BITMAP "..2332.."
	; 	BITMAP "...33..."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	' BOSS em BG $1000 (gera_boss.py): 1 nave 96x64, frame 0
	; 	CHRROM PATTERN 257
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "......21"
	; 	BITMAP ".....1.."
	; 	BITMAP ".....2.1"
	; 	BITMAP ".......1"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "212....."
	; 	BITMAP "3212121."
	; 	BITMAP "31212121"
	; 	BITMAP "3.....12"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "...3...."
	; 	BITMAP "..13...."
	; 	BITMAP "..13...."
	; 	BITMAP ".113...."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "1...33.."
	; 	BITMAP "11.3333."
	; 	BITMAP "13122221"
	; 	BITMAP "11122221"
	; 	BITMAP "13122221"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "......33"
	; 	BITMAP ".....333"
	; 	BITMAP "1...3333"
	; 	BITMAP "1...3133"
	; 	BITMAP "3....112"
	; 	BITMAP "1....132"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "33......"
	; 	BITMAP "333....."
	; 	BITMAP "3333...1"
	; 	BITMAP "3313...1"
	; 	BITMAP "211....3"
	; 	BITMAP "231....1"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "..33...1"
	; 	BITMAP ".3333.11"
	; 	BITMAP "12222131"
	; 	BITMAP "12222111"
	; 	BITMAP "12222131"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "....3..."
	; 	BITMAP "....31.."
	; 	BITMAP "....31.."
	; 	BITMAP "....311."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP ".....212"
	; 	BITMAP ".1212123"
	; 	BITMAP "12121213"
	; 	BITMAP "21.....3"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "12......"
	; 	BITMAP "..1....."
	; 	BITMAP "1.2....."
	; 	BITMAP "1......."
	; 	BITMAP "......21"
	; 	BITMAP "......11"
	; 	BITMAP "......22"
	; 	BITMAP ".....211"
	; 	BITMAP ".....212"
	; 	BITMAP "........"
	; 	BITMAP "....1222"
	; 	BITMAP "....3133"
	; 	CHRROM PATTERN 272
	; 	BITMAP "3......."
	; 	BITMAP "3....111"
	; 	BITMAP "23..1122"
	; 	BITMAP "13..1..."
	; 	BITMAP "13...122"
	; 	BITMAP "....1322"
	; 	BITMAP "221.1122"
	; 	BITMAP "313.1..."
	; 	BITMAP "........"
	; 	BITMAP "1......."
	; 	BITMAP "11......"
	; 	BITMAP ".1.121.1"
	; 	BITMAP "1......1"
	; 	BITMAP "31.21.11"
	; 	BITMAP "11....11"
	; 	BITMAP ".1.1.111"
	; 	BITMAP ".13....."
	; 	BITMAP "113....."
	; 	BITMAP "113....."
	; 	BITMAP "113.2121"
	; 	BITMAP "13......"
	; 	BITMAP "13.21212"
	; 	BITMAP "13......"
	; 	BITMAP "13.12121"
	; 	BITMAP "13122221"
	; 	BITMAP "11111111"
	; 	BITMAP ".1.....1"
	; 	BITMAP "...111.."
	; 	BITMAP "..12221."
	; 	BITMAP ".1122211"
	; 	BITMAP ".1322231"
	; 	BITMAP ".1122211"
	; 	CHRROM PATTERN 436
	; 	BITMAP "1..1.112"
	; 	BITMAP "...1.131"
	; 	BITMAP "1.11.11."
	; 	BITMAP "1.131..."
	; 	BITMAP "1.111.11"
	; 	BITMAP ".1.1.112"
	; 	BITMAP ".3..1123"
	; 	BITMAP ".1.11233"
	; 	BITMAP "211.1..1"
	; 	BITMAP "131.1..."
	; 	BITMAP ".11.11.1"
	; 	BITMAP "...131.1"
	; 	BITMAP "11.111.1"
	; 	BITMAP "211.1.1."
	; 	BITMAP "3211..3."
	; 	BITMAP "33211.1."
	; 	BITMAP "12222131"
	; 	BITMAP "11111111"
	; 	BITMAP "1.....1."
	; 	BITMAP "..111..."
	; 	BITMAP ".12221.."
	; 	BITMAP "1122211."
	; 	BITMAP "1322231."
	; 	BITMAP "1122211."
	; 	BITMAP ".....31."
	; 	BITMAP ".....311"
	; 	BITMAP ".....311"
	; 	BITMAP "1212.311"
	; 	BITMAP "......31"
	; 	BITMAP "21212.31"
	; 	BITMAP "......31"
	; 	BITMAP "12121.31"
	; 	BITMAP "........"
	; 	BITMAP ".......1"
	; 	BITMAP "......11"
	; 	BITMAP "1.121.1."
	; 	BITMAP "1......1"
	; 	BITMAP "11.12.13"
	; 	BITMAP "11....11"
	; 	BITMAP "111.1.1."
	; 	BITMAP ".......3"
	; 	BITMAP "111....3"
	; 	BITMAP "2211..32"
	; 	BITMAP "...1..31"
	; 	BITMAP "221...31"
	; 	BITMAP "2231...."
	; 	BITMAP "2211.122"
	; 	BITMAP "...1.313"
	; 	BITMAP "12......"
	; 	BITMAP "11......"
	; 	BITMAP "22......"
	; 	BITMAP "112....."
	; 	BITMAP "212....."
	; 	BITMAP "........"
	; 	BITMAP "2221...."
	; 	BITMAP "3313...."
	; 	BITMAP "........"
	; 	BITMAP "....1222"
	; 	BITMAP "....1111"
	; 	BITMAP "....1212"
	; 	BITMAP "...11111"
	; 	BITMAP "...11112"
	; 	BITMAP "...11121"
	; 	BITMAP "........"
	; 	BITMAP ".....122"
	; 	BITMAP "23..1322"
	; 	BITMAP "13..1122"
	; 	BITMAP "13..1322"
	; 	BITMAP "13..1122"
	; 	BITMAP "23...111"
	; 	BITMAP "13......"
	; 	BITMAP ".3......"
	; 	BITMAP "1....1.1"
	; 	BITMAP "31..1111"
	; 	BITMAP "11..1111"
	; 	BITMAP "31.11.11"
	; 	BITMAP "11.11113"
	; 	BITMAP "1...1113"
	; 	BITMAP "...2...."
	; 	BITMAP ".1112223"
	; 	BITMAP "3......."
	; 	BITMAP "31...33."
	; 	BITMAP "311.3333"
	; 	BITMAP "31312222"
	; 	BITMAP ".1112222"
	; 	BITMAP ".1312222"
	; 	BITMAP ".1312222"
	; 	BITMAP ".1111111"
	; 	BITMAP "..12221."
	; 	BITMAP "...111.."
	; 	BITMAP ".113331."
	; 	BITMAP "1113331."
	; 	BITMAP "13.111.."
	; 	BITMAP "11......"
	; 	BITMAP "11.1111."
	; 	BITMAP "1..121.."
	; 	BITMAP "13.11233"
	; 	BITMAP "...11123"
	; 	BITMAP "11..1112"
	; 	BITMAP "311..111"
	; 	BITMAP "1311..21"
	; 	BITMAP "11311.12"
	; 	BITMAP ".1131.21"
	; 	BITMAP "11113.13"
	; 	BITMAP "33211.31"
	; 	BITMAP "32111..."
	; 	BITMAP "2111..11"
	; 	BITMAP "111..113"
	; 	BITMAP "12..1131"
	; 	BITMAP "21.11311"
	; 	BITMAP "12.1311."
	; 	BITMAP "31.31111"
	; 	BITMAP ".12221.."
	; 	BITMAP "..111..."
	; 	BITMAP ".133311."
	; 	BITMAP ".1333111"
	; 	BITMAP "..111.31"
	; 	BITMAP "......11"
	; 	BITMAP ".1111.11"
	; 	BITMAP "..121..1"
	; 	BITMAP ".......3"
	; 	BITMAP ".33...13"
	; 	BITMAP "3333.113"
	; 	BITMAP "22221313"
	; 	BITMAP "2222111."
	; 	BITMAP "2222131."
	; 	BITMAP "2222131."
	; 	BITMAP "1111111."
	; 	BITMAP "1.1....1"
	; 	BITMAP "1111..13"
	; 	BITMAP "1111..11"
	; 	BITMAP "11.11.13"
	; 	BITMAP "31111.11"
	; 	BITMAP "3111...1"
	; 	BITMAP "....2..."
	; 	BITMAP "3222111."
	; 	BITMAP "221....."
	; 	BITMAP "2231..32"
	; 	BITMAP "2211..31"
	; 	BITMAP "2231..31"
	; 	BITMAP "2211..31"
	; 	BITMAP "111...32"
	; 	BITMAP "......31"
	; 	BITMAP "......3."
	; 	BITMAP "........"
	; 	BITMAP "2221...."
	; 	BITMAP "1111...."
	; 	BITMAP "2121...."
	; 	BITMAP "11111..."
	; 	BITMAP "21111..."
	; 	BITMAP "12111..."
	; 	BITMAP "........"
	; 	BITMAP "...11.12"
	; 	BITMAP "..113.11"
	; 	BITMAP "..213.11"
	; 	BITMAP "..113.11"
	; 	BITMAP "..213.11"
	; 	BITMAP "..111.11"
	; 	BITMAP ".111.111"
	; 	BITMAP ".11.1112"
	; 	BITMAP "13......"
	; 	BITMAP "113....."
	; 	BITMAP "113....."
	; 	BITMAP "213....2"
	; 	BITMAP "113....1"
	; 	BITMAP "113...11"
	; 	BITMAP "223...12"
	; 	BITMAP "113..211"
	; 	BITMAP ".1211113"
	; 	BITMAP "11212113"
	; 	BITMAP "11112111"
	; 	BITMAP ".1111111"
	; 	BITMAP "2.1111.1"
	; 	BITMAP "12.11111"
	; 	BITMAP "112....."
	; 	BITMAP "11122222"
	; 	BITMAP "..1....."
	; 	BITMAP "....111."
	; 	BITMAP "3..12221"
	; 	BITMAP "3.112221"
	; 	BITMAP "3.132223"
	; 	BITMAP "3.112221"
	; 	BITMAP "...12221"
	; 	BITMAP "3...111."
	; 	BITMAP "11.11..1"
	; 	BITMAP ".1.22.11"
	; 	BITMAP ".1.11.11"
	; 	BITMAP "1..22.12"
	; 	BITMAP "1.111.12"
	; 	BITMAP "1.121.12"
	; 	BITMAP "..11..12"
	; 	BITMAP ".111.113"
	; 	BITMAP "11.11.32"
	; 	BITMAP "11....12"
	; 	BITMAP "211..113"
	; 	BITMAP "321.1132"
	; 	BITMAP "221.1.12"
	; 	BITMAP "321...23"
	; 	BITMAP "221...31"
	; 	BITMAP "3311..12"
	; 	BITMAP "23.11.11"
	; 	BITMAP "21....11"
	; 	BITMAP "311..112"
	; 	BITMAP "2311.123"
	; 	BITMAP "21.1.122"
	; 	BITMAP "32...123"
	; 	BITMAP "13...122"
	; 	BITMAP "21..1133"
	; 	BITMAP "1..11.11"
	; 	BITMAP "11.22.1."
	; 	BITMAP "11.11.1."
	; 	BITMAP "21.22..1"
	; 	BITMAP "21.111.1"
	; 	BITMAP "21.121.1"
	; 	BITMAP "21..11.."
	; 	BITMAP "311.111."
	; 	BITMAP ".....1.."
	; 	BITMAP ".111...."
	; 	BITMAP "12221..3"
	; 	BITMAP "122211.3"
	; 	BITMAP "322231.3"
	; 	BITMAP "122211.3"
	; 	BITMAP "12221..."
	; 	BITMAP ".111...3"
	; 	BITMAP "3111121."
	; 	BITMAP "31121211"
	; 	BITMAP "11121111"
	; 	BITMAP "1111111."
	; 	BITMAP "1.1111.2"
	; 	BITMAP "11111.21"
	; 	BITMAP ".....211"
	; 	BITMAP "22222111"
	; 	BITMAP "......31"
	; 	BITMAP ".....311"
	; 	BITMAP ".....311"
	; 	BITMAP "2....312"
	; 	BITMAP "1....311"
	; 	BITMAP "11...311"
	; 	BITMAP "21...322"
	; 	BITMAP "112..311"
	; 	BITMAP "21.11..."
	; 	BITMAP "11.311.."
	; 	BITMAP "11.312.."
	; 	BITMAP "11.311.."
	; 	BITMAP "11.312.."
	; 	BITMAP "11.111.."
	; 	BITMAP "111.111."
	; 	BITMAP "2111.11."
	; 	BITMAP ".1.11211"
	; 	BITMAP "..112111"
	; 	BITMAP "..111121"
	; 	BITMAP "...11211"
	; 	BITMAP "........"
	; 	BITMAP "...11111"
	; 	BITMAP "..111112"
	; 	BITMAP ".1211123"
	; 	BITMAP "113..121"
	; 	BITMAP "213..112"
	; 	BITMAP "113..111"
	; 	BITMAP "21....11"
	; 	BITMAP ".......1"
	; 	BITMAP "113....."
	; 	BITMAP "1113...."
	; 	BITMAP "2113...."
	; 	BITMAP "12111211"
	; 	BITMAP "11111211"
	; 	BITMAP "21121211"
	; 	BITMAP "12111211"
	; 	BITMAP "11211211"
	; 	BITMAP "11121211"
	; 	BITMAP ".1112211"
	; 	BITMAP "..11.211"
	; 	BITMAP "3..13331"
	; 	BITMAP "3..13331"
	; 	BITMAP "13..111."
	; 	BITMAP "13......"
	; 	BITMAP "113....."
	; 	BITMAP "213....."
	; 	BITMAP "113....."
	; 	BITMAP "2113...."
	; 	BITMAP ".22..133"
	; 	BITMAP ".11...11"
	; 	BITMAP ".222...."
	; 	BITMAP ".1212..."
	; 	BITMAP "..3212.."
	; 	BITMAP "...1212."
	; 	BITMAP "....3212"
	; 	BITMAP ".....121"
	; 	CHRROM PATTERN 476
	; 	BITMAP "3331...3"
	; 	BITMAP "111...12"
	; 	BITMAP ".......1"
	; 	BITMAP "......12"
	; 	BITMAP ".......3"
	; 	BITMAP "......12"
	; 	BITMAP ".......1"
	; 	BITMAP "2.....12"
	; 	BITMAP "3...1333"
	; 	BITMAP "21...111"
	; 	BITMAP "1......."
	; 	BITMAP "21......"
	; 	BITMAP "3......."
	; 	BITMAP "21......"
	; 	BITMAP "1......."
	; 	BITMAP "21.....2"
	; 	BITMAP "331..22."
	; 	BITMAP "11...11."
	; 	BITMAP "....222."
	; 	BITMAP "...2121."
	; 	BITMAP "..2123.."
	; 	BITMAP ".2121..."
	; 	BITMAP "2123...."
	; 	BITMAP "121....."
	; 	BITMAP "13331..3"
	; 	BITMAP "13331..3"
	; 	BITMAP ".111..31"
	; 	BITMAP "......31"
	; 	BITMAP ".....311"
	; 	BITMAP ".....312"
	; 	BITMAP ".....311"
	; 	BITMAP "....3112"
	; 	BITMAP "11211121"
	; 	BITMAP "11211111"
	; 	BITMAP "11212112"
	; 	BITMAP "11211121"
	; 	BITMAP "11211211"
	; 	BITMAP "11212111"
	; 	BITMAP "1122111."
	; 	BITMAP "112.11.."
	; 	BITMAP "121..311"
	; 	BITMAP "211..312"
	; 	BITMAP "111..311"
	; 	BITMAP "11....12"
	; 	BITMAP "1......."
	; 	BITMAP ".....311"
	; 	BITMAP "....3111"
	; 	BITMAP "....3112"
	; 	BITMAP "11211.1."
	; 	BITMAP "111211.."
	; 	BITMAP "121111.."
	; 	BITMAP "11211..."
	; 	BITMAP "........"
	; 	BITMAP "11111..."
	; 	BITMAP "211111.."
	; 	BITMAP "3211121."
	; 	BITMAP ".1121123"
	; 	BITMAP ".1112112"
	; 	BITMAP ".1111211"
	; 	BITMAP "..111121"
	; 	BITMAP "...31112"
	; 	BITMAP "....3111"
	; 	BITMAP ".....111"
	; 	BITMAP "......11"
	; 	BITMAP "21113..."
	; 	BITMAP "11113..."
	; 	BITMAP "111113.."
	; 	BITMAP "112113.."
	; 	BITMAP "1111113."
	; 	BITMAP "2111113."
	; 	BITMAP "12112113"
	; 	BITMAP "12111113"
	; 	BITMAP "......21"
	; 	BITMAP ".....112"
	; 	BITMAP ".....111"
	; 	BITMAP "......11"
	; 	BITMAP ".......1"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "1113...."
	; 	BITMAP "11113..."
	; 	BITMAP "21113..."
	; 	BITMAP "12113..."
	; 	BITMAP "112113.."
	; 	BITMAP "111213.."
	; 	BITMAP ".11123.."
	; 	BITMAP "..11113."
	; 	BITMAP "......32"
	; 	BITMAP "......31"
	; 	BITMAP "......33"
	; 	BITMAP "......33"
	; 	BITMAP "......33"
	; 	BITMAP "......33"
	; 	BITMAP ".......3"
	; 	BITMAP ".......3"
	; 	BITMAP "1......3"
	; 	BITMAP "21......"
	; 	BITMAP "12......"
	; 	BITMAP "21......"
	; 	BITMAP "12......"
	; 	BITMAP "21......"
	; 	BITMAP "31......"
	; 	BITMAP "33......"
	; 	BITMAP "3......1"
	; 	BITMAP "......12"
	; 	BITMAP "......21"
	; 	BITMAP "......12"
	; 	BITMAP "......21"
	; 	BITMAP "......12"
	; 	BITMAP "......13"
	; 	BITMAP "......33"
	; 	BITMAP "23......"
	; 	BITMAP "13......"
	; 	BITMAP "33......"
	; 	BITMAP "33......"
	; 	BITMAP "33......"
	; 	BITMAP "33......"
	; 	BITMAP "3......."
	; 	BITMAP "3......."
	; 	BITMAP "....3111"
	; 	BITMAP "...31111"
	; 	BITMAP "...31112"
	; 	BITMAP "...31121"
	; 	BITMAP "..311211"
	; 	BITMAP "..312111"
	; 	BITMAP "..32111."
	; 	BITMAP ".31111.."
	; 	BITMAP "12......"
	; 	BITMAP "211....."
	; 	BITMAP "111....."
	; 	BITMAP "11......"
	; 	BITMAP "1......."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "...31112"
	; 	BITMAP "...31111"
	; 	BITMAP "..311111"
	; 	BITMAP "..311211"
	; 	BITMAP ".3111111"
	; 	BITMAP ".3111112"
	; 	BITMAP "31121121"
	; 	BITMAP "31111121"
	; 	BITMAP "3211211."
	; 	BITMAP "2112111."
	; 	BITMAP "1121111."
	; 	BITMAP "121111.."
	; 	BITMAP "21113..."
	; 	BITMAP "1113...."
	; 	BITMAP "111....."
	; 	BITMAP "11......"
	; 	BITMAP ".......3"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "11211111"
	; 	BITMAP "31121121"
	; 	BITMAP ".1112111"
	; 	BITMAP "..111211"
	; 	BITMAP "...31121"
	; 	BITMAP "....3112"
	; 	BITMAP ".....111"
	; 	BITMAP "......12"
	; 	BITMAP "3......."
	; 	BITMAP "3......."
	; 	BITMAP "13......"
	; 	BITMAP "13......"
	; 	BITMAP "113....."
	; 	BITMAP "123....."
	; 	BITMAP "2113...."
	; 	BITMAP "1113...."
	; 	BITMAP "...1113."
	; 	BITMAP "....1113"
	; 	BITMAP ".....113"
	; 	BITMAP "......11"
	; 	BITMAP ".......1"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "3......."
	; 	BITMAP "3......."
	; 	BITMAP "13......"
	; 	BITMAP ".3......"
	; 	BITMAP "........"
	; 	BITMAP "33......"
	; 	BITMAP ".3......"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "......33"
	; 	BITMAP "......3."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP ".......3"
	; 	BITMAP ".......3"
	; 	BITMAP "......31"
	; 	BITMAP "......3."
	; 	BITMAP "........"
	; 	BITMAP ".3111..."
	; 	BITMAP "3111...."
	; 	BITMAP "311....."
	; 	BITMAP "11......"
	; 	BITMAP "1......."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP ".......3"
	; 	BITMAP ".......3"
	; 	BITMAP "......31"
	; 	BITMAP "......31"
	; 	BITMAP ".....311"
	; 	BITMAP ".....321"
	; 	BITMAP "....3112"
	; 	BITMAP "....3111"
	; 	BITMAP "11111211"
	; 	BITMAP "12112113"
	; 	BITMAP "1112111."
	; 	BITMAP "112111.."
	; 	BITMAP "12113..."
	; 	BITMAP "2113...."
	; 	BITMAP "111....."
	; 	BITMAP "21......"
	; 	BITMAP "3......."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP ".......1"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "11113..."
	; 	BITMAP "31213..."
	; 	BITMAP ".31113.."
	; 	BITMAP "..1113.."
	; 	BITMAP "...1213."
	; 	BITMAP "....113."
	; 	BITMAP ".....113"
	; 	BITMAP "......13"
	; 	BITMAP "...31111"
	; 	BITMAP "...31213"
	; 	BITMAP "..31113."
	; 	BITMAP "..3111.."
	; 	BITMAP ".3121..."
	; 	BITMAP ".311...."
	; 	BITMAP "311....."
	; 	BITMAP "31......"
	; 	BITMAP "1......."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	' ---- LOGO FALCON SOFT (v0.16) ----
	; 	' splash inicial: CHRROM 1 = CHRRAM pagina 1 (POKE $1C,$20)
	; 	' cinza=idx2 branco=idx3; fade por palette cycling ($3F02/$3F03)
	; 	CHRROM 1
	; 	CHRROM PATTERN 96
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "...22222"
	; 	BITMAP "..22...."
	; 	BITMAP "....2..."
	; 	BITMAP "....2..."
	; 	BITMAP "....2..."
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "22222222"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "2......."
	; 	BITMAP "2222...."
	; 	BITMAP "....22.."
	; 	BITMAP "......2."
	; 	BITMAP ".22222.2"
	; 
	; 	BITMAP "....2..."
	; 	BITMAP "....2..."
	; 	BITMAP "....2..."
	; 	BITMAP "...2...."
	; 	BITMAP "...2...."
	; 	BITMAP "..2....."
	; 	BITMAP "..2....."
	; 	BITMAP ".2......"
	; 
	; 	BITMAP "...2..22"
	; 	BITMAP "...2.22."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "......22"
	; 	BITMAP ".....2.."
	; 	BITMAP "........"
	; 	BITMAP "....2222"
	; 
	; 	BITMAP "222222.."
	; 	BITMAP "......2."
	; 	BITMAP "......2."
	; 	BITMAP "......2."
	; 	BITMAP "222....2"
	; 	BITMAP "...222.2"
	; 	BITMAP ".22...22"
	; 	BITMAP "2......."
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP ".......2"
	; 	BITMAP "........"
	; 	BITMAP "......33"
	; 	BITMAP "......33"
	; 	BITMAP ".....333"
	; 	BITMAP ".....333"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "22222222"
	; 	BITMAP "........"
	; 	BITMAP "33333333"
	; 	BITMAP "33333333"
	; 	BITMAP "33333333"
	; 	BITMAP "33333333"
	; 
	; 	BITMAP ".......2"
	; 	BITMAP ".....22."
	; 	BITMAP "22222..."
	; 	BITMAP "........"
	; 	BITMAP "3333.333"
	; 	BITMAP "333..333"
	; 	BITMAP "333.3333"
	; 	BITMAP "333.3333"
	; 
	; 	BITMAP "2......."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "3333...."
	; 	BITMAP "3333...3"
	; 	BITMAP "3333...3"
	; 	BITMAP "3333...3"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "33....33"
	; 	BITMAP "33....33"
	; 	BITMAP "33....33"
	; 
	; 	BITMAP ".......2"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "3333...."
	; 	BITMAP "33333..3"
	; 	BITMAP "3.333.33"
	; 
	; 	BITMAP "........"
	; 	BITMAP "222....."
	; 	BITMAP "...22222"
	; 	BITMAP "........"
	; 	BITMAP "..3333.."
	; 	BITMAP "33333333"
	; 	BITMAP "33333333"
	; 	BITMAP "33333333"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "22222222"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "3...3333"
	; 	BITMAP "33..3333"
	; 	BITMAP "333.3333"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "22222222"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "33...333"
	; 	BITMAP "333...33"
	; 	BITMAP "3333..33"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "33......"
	; 	BITMAP "333....."
	; 	BITMAP "333....."
	; 
	; 	BITMAP "....3333"
	; 	BITMAP "....3333"
	; 	BITMAP "...33333"
	; 	BITMAP "...33333"
	; 	BITMAP "...33333"
	; 	BITMAP "..333333"
	; 	BITMAP "..333333"
	; 	BITMAP ".3333333"
	; 
	; 	BITMAP "33......"
	; 	BITMAP "33......"
	; 	BITMAP "33......"
	; 	BITMAP "3......."
	; 	BITMAP "3......."
	; 	BITMAP "3......."
	; 	BITMAP "........"
	; 	BITMAP "3333333."
	; 
	; 	BITMAP "....3333"
	; 	BITMAP "...33333"
	; 	BITMAP "...33333"
	; 	BITMAP "..333333"
	; 	BITMAP "..333333"
	; 	BITMAP "..333333"
	; 	BITMAP ".3333333"
	; 	BITMAP ".3333333"
	; 
	; 	BITMAP "3333...3"
	; 	BITMAP "3333...3"
	; 	BITMAP "3333..33"
	; 	BITMAP "3333..33"
	; 	BITMAP "3333..33"
	; 	BITMAP "3333..33"
	; 	BITMAP "3333..33"
	; 	BITMAP "3333..33"
	; 
	; 	BITMAP "33....33"
	; 	BITMAP "33....33"
	; 	BITMAP "33....33"
	; 	BITMAP "33....33"
	; 	BITMAP "33....33"
	; 	BITMAP "33....33"
	; 	BITMAP "33....33"
	; 	BITMAP "33....33"
	; 
	; 	BITMAP "3.333.33"
	; 	BITMAP "3.333.33"
	; 	BITMAP "3.333.33"
	; 	BITMAP "3.333..3"
	; 	BITMAP "3.333..3"
	; 	BITMAP "3.333..3"
	; 	BITMAP "3......3"
	; 	BITMAP "3......3"
	; 
	; 	BITMAP "3333..33"
	; 	BITMAP "3333..33"
	; 	BITMAP "3333..33"
	; 	BITMAP "3333..33"
	; 	BITMAP "33333..3"
	; 	BITMAP "33333..3"
	; 	BITMAP "33333..3"
	; 	BITMAP "33333..3"
	; 
	; 	BITMAP "333..333"
	; 	BITMAP "3333.333"
	; 	BITMAP "3333.333"
	; 	BITMAP "3333..33"
	; 	BITMAP "3333..33"
	; 	BITMAP "33333.33"
	; 	BITMAP "33333.33"
	; 	BITMAP "33333..3"
	; 
	; 	BITMAP "33333..3"
	; 	BITMAP "33333..3"
	; 	BITMAP "333333.3"
	; 	BITMAP "333333.."
	; 	BITMAP "3333333."
	; 	BITMAP "33333333"
	; 	BITMAP "33333333"
	; 	BITMAP "33333333"
	; 
	; 	BITMAP "333....."
	; 	BITMAP "3333...."
	; 	BITMAP "3333...."
	; 	BITMAP "33333..."
	; 	BITMAP "33333..."
	; 	BITMAP ".33333.."
	; 	BITMAP ".33333.."
	; 	BITMAP "3333333."
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP ".......3"
	; 	BITMAP ".......3"
	; 	BITMAP "......33"
	; 	BITMAP "......33"
	; 	BITMAP ".....333"
	; 
	; 	BITMAP ".3333333"
	; 	BITMAP "33333333"
	; 	BITMAP "33333333"
	; 	BITMAP "3333333."
	; 	BITMAP "333333.."
	; 	BITMAP "333333.."
	; 	BITMAP "33333..."
	; 	BITMAP "33333..."
	; 
	; 	BITMAP "333333.."
	; 	BITMAP "333333.."
	; 	BITMAP "333333.."
	; 	BITMAP ".......3"
	; 	BITMAP ".......3"
	; 	BITMAP "......33"
	; 	BITMAP "......22"
	; 	BITMAP "......22"
	; 
	; 	BITMAP "333333.3"
	; 	BITMAP "333333.3"
	; 	BITMAP "333333.3"
	; 	BITMAP "33333..3"
	; 	BITMAP "33332..2"
	; 	BITMAP "32222..2"
	; 	BITMAP "22222222"
	; 	BITMAP "22222222"
	; 
	; 	BITMAP "3333..33"
	; 	BITMAP "3333..33"
	; 	BITMAP "3333..22"
	; 	BITMAP "2222..22"
	; 	BITMAP "2222..22"
	; 	BITMAP "2222..22"
	; 	BITMAP "2222..22"
	; 	BITMAP "2222..22"
	; 
	; 	BITMAP "33....33"
	; 	BITMAP "33....33"
	; 	BITMAP "22....22"
	; 	BITMAP "22....22"
	; 	BITMAP "22....22"
	; 	BITMAP "22....22"
	; 	BITMAP "22....22"
	; 	BITMAP "22....22"
	; 
	; 	BITMAP "3......3"
	; 	BITMAP "3......3"
	; 	BITMAP "2.2222.2"
	; 	BITMAP "2.2222.2"
	; 	BITMAP "2.2222.2"
	; 	BITMAP "2.2222.."
	; 	BITMAP "2.2222.."
	; 	BITMAP "2.2222.."
	; 
	; 	BITMAP "33333..3"
	; 	BITMAP "33333..."
	; 	BITMAP "222233.."
	; 	BITMAP "222222.."
	; 	BITMAP "222222.."
	; 	BITMAP "222222.."
	; 	BITMAP "222222.."
	; 	BITMAP "2222222."
	; 
	; 	BITMAP "333333.3"
	; 	BITMAP "333333.3"
	; 	BITMAP "333333.."
	; 	BITMAP "223333.."
	; 	BITMAP "2222223."
	; 	BITMAP "2222222."
	; 	BITMAP ".222222."
	; 	BITMAP ".2222222"
	; 
	; 	BITMAP "33333333"
	; 	BITMAP "33333333"
	; 	BITMAP "33333.33"
	; 	BITMAP "33333..3"
	; 	BITMAP "333333.3"
	; 	BITMAP "333333.3"
	; 	BITMAP ".22233.."
	; 	BITMAP ".222222."
	; 
	; 	BITMAP "3333333."
	; 	BITMAP "33333333"
	; 	BITMAP "33333333"
	; 	BITMAP "33333333"
	; 	BITMAP "33333333"
	; 	BITMAP "33333333"
	; 	BITMAP "33333333"
	; 	BITMAP "33333333"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "3......."
	; 	BITMAP "3......."
	; 	BITMAP "33......"
	; 	BITMAP "33......"
	; 	BITMAP "33......"
	; 
	; 	BITMAP ".....333"
	; 	BITMAP ".....333"
	; 	BITMAP "....3333"
	; 	BITMAP "....3333"
	; 	BITMAP "...33332"
	; 	BITMAP "...33322"
	; 	BITMAP "..332222"
	; 	BITMAP "..222222"
	; 
	; 	BITMAP "3333...."
	; 	BITMAP "3333...."
	; 	BITMAP "3333...."
	; 	BITMAP "332....."
	; 	BITMAP "222....."
	; 	BITMAP "22......"
	; 	BITMAP "22......"
	; 	BITMAP "22......"
	; 
	; 	BITMAP ".....222"
	; 	BITMAP ".....222"
	; 	BITMAP "....2222"
	; 	BITMAP "....2222"
	; 	BITMAP "....2222"
	; 	BITMAP "...22222"
	; 	BITMAP "...22222"
	; 	BITMAP "..222222"
	; 
	; 	BITMAP "22222222"
	; 	BITMAP "22222222"
	; 	BITMAP "22222222"
	; 	BITMAP "222...22"
	; 	BITMAP "222...22"
	; 	BITMAP "22....22"
	; 	BITMAP "22....22"
	; 	BITMAP "22....22"
	; 
	; 	BITMAP "2222..22"
	; 	BITMAP "2222..22"
	; 	BITMAP "2222..22"
	; 	BITMAP "2222..22"
	; 	BITMAP "2222..22"
	; 	BITMAP "222....."
	; 	BITMAP "22......"
	; 	BITMAP "2..33333"
	; 
	; 	BITMAP "22....22"
	; 	BITMAP "22222.22"
	; 	BITMAP "22222.22"
	; 	BITMAP "22222.22"
	; 	BITMAP "22222..2"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "...3333."
	; 
	; 	BITMAP "2.2222.."
	; 	BITMAP "2.2222.."
	; 	BITMAP "222222.."
	; 	BITMAP "222222.."
	; 	BITMAP "2222...."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP ".33333.3"
	; 
	; 	BITMAP "2222222."
	; 	BITMAP "2222222."
	; 	BITMAP "2222222."
	; 	BITMAP "2222222."
	; 	BITMAP "2222222."
	; 	BITMAP "......22"
	; 	BITMAP "......22"
	; 	BITMAP "33333..2"
	; 
	; 	BITMAP ".2222222"
	; 	BITMAP ".2222222"
	; 	BITMAP ".2222222"
	; 	BITMAP "..222222"
	; 	BITMAP "..222222"
	; 	BITMAP "..222222"
	; 	BITMAP "..222222"
	; 	BITMAP "..222222"
	; 
	; 	BITMAP ".222222."
	; 	BITMAP ".222222."
	; 	BITMAP "..222222"
	; 	BITMAP "2.222222"
	; 	BITMAP "2.222222"
	; 	BITMAP "2..22222"
	; 	BITMAP "2..22222"
	; 	BITMAP "22.22222"
	; 
	; 	BITMAP ".3333333"
	; 	BITMAP ".2223333"
	; 	BITMAP "..222233"
	; 	BITMAP "...22222"
	; 	BITMAP "...22222"
	; 	BITMAP "2...2222"
	; 	BITMAP "2...2222"
	; 	BITMAP "2....222"
	; 
	; 	BITMAP "333....."
	; 	BITMAP "333....."
	; 	BITMAP "3333...."
	; 	BITMAP "3333...."
	; 	BITMAP "22333..."
	; 	BITMAP "22223..."
	; 	BITMAP "222223.."
	; 	BITMAP "222222.."
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP ".......2"
	; 	BITMAP ".......2"
	; 	BITMAP "......22"
	; 
	; 	BITMAP ".2222222"
	; 	BITMAP ".2222222"
	; 	BITMAP "22222222"
	; 	BITMAP "22222222"
	; 	BITMAP "2222222."
	; 	BITMAP "2222222."
	; 	BITMAP "2222222."
	; 	BITMAP "222222.."
	; 
	; 	BITMAP "2......."
	; 	BITMAP "2......."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "..222222"
	; 	BITMAP "..222222"
	; 	BITMAP ".2222222"
	; 	BITMAP ".2222222"
	; 	BITMAP "22222222"
	; 	BITMAP "22222222"
	; 	BITMAP ".....222"
	; 	BITMAP "........"
	; 
	; 	BITMAP "22....22"
	; 	BITMAP "2.....22"
	; 	BITMAP "2.....22"
	; 	BITMAP "2.....22"
	; 	BITMAP "......22"
	; 	BITMAP "......22"
	; 	BITMAP "......22"
	; 	BITMAP "........"
	; 
	; 	BITMAP "..333333"
	; 	BITMAP "..333333"
	; 	BITMAP "..333.33"
	; 	BITMAP ".333.333"
	; 	BITMAP ".333.333"
	; 	BITMAP ".3333.33"
	; 	BITMAP "..333..."
	; 	BITMAP "..3333.."
	; 
	; 	BITMAP "..333333"
	; 	BITMAP "..333333"
	; 	BITMAP ".333.333"
	; 	BITMAP ".333.333"
	; 	BITMAP ".333.333"
	; 	BITMAP ".333.333"
	; 	BITMAP ".333.333"
	; 	BITMAP ".333.333"
	; 
	; 	BITMAP ".33333.3"
	; 	BITMAP ".33333.3"
	; 	BITMAP ".333...."
	; 	BITMAP ".333...."
	; 	BITMAP ".333...."
	; 	BITMAP ".333...."
	; 	BITMAP ".333...."
	; 	BITMAP ".333...."
	; 
	; 	BITMAP "33333..2"
	; 	BITMAP "333....2"
	; 	BITMAP "3333...2"
	; 	BITMAP ".333.222"
	; 	BITMAP ".333.222"
	; 	BITMAP ".333..22"
	; 	BITMAP ".333..22"
	; 	BITMAP ".333...."
	; 
	; 	BITMAP "..222222"
	; 	BITMAP "22222222"
	; 	BITMAP "22222222"
	; 	BITMAP "22222222"
	; 	BITMAP "22222222"
	; 	BITMAP "22222222"
	; 	BITMAP "2222222."
	; 	BITMAP "22222..."
	; 
	; 	BITMAP "22.22222"
	; 	BITMAP "22..2222"
	; 	BITMAP "22..2222"
	; 	BITMAP "22..2222"
	; 	BITMAP "2....222"
	; 	BITMAP "2....222"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "22....22"
	; 	BITMAP "22....22"
	; 	BITMAP "22.....2"
	; 	BITMAP "222....2"
	; 	BITMAP "222....."
	; 	BITMAP "2222...."
	; 	BITMAP "..22...."
	; 	BITMAP "........"
	; 
	; 	BITMAP "2222222."
	; 	BITMAP "2222222."
	; 	BITMAP "22222222"
	; 	BITMAP "22222222"
	; 	BITMAP "22222222"
	; 	BITMAP "22222222"
	; 	BITMAP ".2222222"
	; 	BITMAP ".2222222"
	; 
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "2......."
	; 	BITMAP "2......."
	; 	BITMAP "22......"
	; 
	; 	BITMAP "......22"
	; 	BITMAP ".....222"
	; 	BITMAP ".....22."
	; 	BITMAP "....2..."
	; 	BITMAP "......22"
	; 	BITMAP "....22.."
	; 	BITMAP "...2...."
	; 	BITMAP "..2....."
	; 
	; 	BITMAP "22222..."
	; 	BITMAP "22....22"
	; 	BITMAP "...222.."
	; 	BITMAP "222....."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "...22222"
	; 	BITMAP "222....."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "22222222"
	; 	BITMAP ".......2"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "........"
	; 	BITMAP "22......"
	; 	BITMAP "..22...."
	; 	BITMAP "....2..."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "...333.."
	; 	BITMAP "...3333."
	; 	BITMAP "333.333."
	; 	BITMAP "333.3222"
	; 	BITMAP "333.2222"
	; 	BITMAP "332..222"
	; 	BITMAP "322.2222"
	; 	BITMAP "222.2222"
	; 
	; 	BITMAP ".333.222"
	; 	BITMAP ".222.222"
	; 	BITMAP ".222.222"
	; 	BITMAP ".222.222"
	; 	BITMAP ".222.222"
	; 	BITMAP ".222.222"
	; 	BITMAP ".222.222"
	; 	BITMAP ".222.222"
	; 
	; 	BITMAP ".222.33."
	; 	BITMAP ".222222."
	; 	BITMAP ".222222."
	; 	BITMAP ".2222..."
	; 	BITMAP ".222...."
	; 	BITMAP ".222...."
	; 	BITMAP ".222...."
	; 	BITMAP ".222...."
	; 
	; 	BITMAP ".333...."
	; 	BITMAP ".333...."
	; 	BITMAP ".333...."
	; 	BITMAP ".2233..."
	; 	BITMAP ".2223..."
	; 	BITMAP ".2222..."
	; 	BITMAP ".2222..."
	; 	BITMAP "..222..."
	; 
	; 	BITMAP "........"
	; 	BITMAP "......22"
	; 	BITMAP "....22.."
	; 	BITMAP "...2...."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "22222222"
	; 	BITMAP "2......."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "22222..."
	; 	BITMAP ".....222"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "....2222"
	; 	BITMAP "22.....2"
	; 	BITMAP "..222..."
	; 	BITMAP ".....222"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "22......"
	; 	BITMAP "222....."
	; 	BITMAP "..2....."
	; 	BITMAP "...2...."
	; 	BITMAP "22......"
	; 	BITMAP "..2....."
	; 	BITMAP "...22..."
	; 	BITMAP "........"
	; 
	; 	BITMAP "222.2222"
	; 	BITMAP ".2222222"
	; 	BITMAP "..222222"
	; 	BITMAP "...2222."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "22......"
	; 	BITMAP "..22...."
	; 
	; 	BITMAP ".222.222"
	; 	BITMAP ".222.222"
	; 	BITMAP ".222.222"
	; 	BITMAP ".222.222"
	; 	BITMAP ".222.222"
	; 	BITMAP ".2222222"
	; 	BITMAP "..222222"
	; 	BITMAP "..222222"
	; 
	; 	BITMAP ".222...."
	; 	BITMAP ".222...."
	; 	BITMAP ".222...."
	; 	BITMAP ".222...."
	; 	BITMAP ".222...."
	; 	BITMAP ".222...."
	; 	BITMAP ".222...."
	; 	BITMAP ".222...."
	; 
	; 	BITMAP "..222..."
	; 	BITMAP "..222..."
	; 	BITMAP "..22...."
	; 	BITMAP "..2....."
	; 	BITMAP "........"
	; 	BITMAP "....2..."
	; 	BITMAP "..22...."
	; 	BITMAP "22......"
	; 
	; 	BITMAP "....22.."
	; 	BITMAP "......2."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP "....2222"
	; 	BITMAP ".....22."
	; 	BITMAP ".2......"
	; 	BITMAP "..222222"
	; 	BITMAP "....2222"
	; 	BITMAP "......2."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	BITMAP ".22....2"
	; 	BITMAP "......2."
	; 	BITMAP "...2...."
	; 	BITMAP "222....."
	; 	BITMAP "2......."
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 	BITMAP "........"
	; 
	; 	' letra 'a' (fonte CVBasic) p/ "apresenta"
	; 	CHRROM PATTERN 182
	; 	BITMAP "..333..."
	; 	BITMAP ".33.33.."
	; 	BITMAP "33...33."
	; 	BITMAP "33...33."
	; 	BITMAP "3333333."
	; 	BITMAP "33...33."
	; 	BITMAP "33...33."
	; 	BITMAP "........"
	; 
	; 	' letra 'e' (fonte CVBasic) p/ "apresenta"
	; 	CHRROM PATTERN 183
	; 	BITMAP "3333333."
	; 	BITMAP "33......"
	; 	BITMAP "33......"
	; 	BITMAP "333333.."
	; 	BITMAP "33......"
	; 	BITMAP "33......"
	; 	BITMAP "3333333."
	; 	BITMAP "........"
	; 
	; 	' letra 'n' (fonte CVBasic) p/ "apresenta"
	; 	CHRROM PATTERN 184
	; 	BITMAP "33...33."
	; 	BITMAP "333..33."
	; 	BITMAP "3333.33."
	; 	BITMAP "3333333."
	; 	BITMAP "33.3333."
	; 	BITMAP "33..333."
	; 	BITMAP "33...33."
	; 	BITMAP "........"
	; 
	; 	' letra 'p' (fonte CVBasic) p/ "apresenta"
	; 	CHRROM PATTERN 185
	; 	BITMAP "333333.."
	; 	BITMAP "33...33."
	; 	BITMAP "33...33."
	; 	BITMAP "33...33."
	; 	BITMAP "333333.."
	; 	BITMAP "33......"
	; 	BITMAP "33......"
	; 	BITMAP "........"
	; 
	; 	' letra 'r' (fonte CVBasic) p/ "apresenta"
	; 	CHRROM PATTERN 186
	; 	BITMAP "333333.."
	; 	BITMAP "33...33."
	; 	BITMAP "33...33."
	; 	BITMAP "33..333."
	; 	BITMAP "33333..."
	; 	BITMAP "33.333.."
	; 	BITMAP "33..333."
	; 	BITMAP "........"
	; 
	; 	' letra 's' (fonte CVBasic) p/ "apresenta"
	; 	CHRROM PATTERN 187
	; 	BITMAP ".3333..."
	; 	BITMAP "33..33.."
	; 	BITMAP "33......"
	; 	BITMAP ".33333.."
	; 	BITMAP ".....33."
	; 	BITMAP "33...33."
	; 	BITMAP ".33333.."
	; 	BITMAP "........"
	; 
	; 	' letra 't' (fonte CVBasic) p/ "apresenta"
	; 	CHRROM PATTERN 188
	; 	BITMAP ".333333."
	; 	BITMAP "...33..."
	; 	BITMAP "...33..."
	; 	BITMAP "...33..."
	; 	BITMAP "...33..."
	; 	BITMAP "...33..."
	; 	BITMAP "...33..."
	; 	BITMAP "........"
	; 
	; BANK 3	' v0.19: FASE 2 - PLANETA DE LAVA (setup, terreno, canhoes)
; Intruder Alert v0.36: map the dedicated music bank.
cvb_FAMISTUDIO_START:
	SEI
	LDA $BFFF
	STA FAMISTUDIO_SAVED_BANK
	LDA #FAMISTUDIO_BANK
	ORA CHRRAM_BANK
	STA BANKSEL

BANK_1_FREE:	EQU $bfff-$
	TIMES $bfff-$ DB $ff
	DB $00
	FORG $08010
	ORG $8000
	; 
	; lava_wr: PROCEDURE		' escreve 960 tiles a partir do READ em #bk (base NT)
cvb_LAVA_WR:
	; 	FOR r = 0 TO 29
	LDA #0
	STA cvb_R
cv538:
	; 		FOR i = 0 TO 31
	LDA #0
	STA cvb_I
cv539:
	; 			READ BYTE e
	JSR _read8
	STA cvb_E
	; 			VPOKE #bk, e
	PHA
	LDA cvb_#BK
	LDY cvb_#BK+1
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 			#bk = #bk + 1
	INC cvb_#BK
	BNE cv540
	INC cvb_#BK+1
cv540:
	; 		NEXT i
	INC cvb_I
	LDA cvb_I
	CMP #32
	BCC.L cv539
	; 	NEXT r
	INC cvb_R
	LDA cvb_R
	CMP #30
	BCC.L cv538
	; 	END
	RTS
	; 
	; lava_setup: PROCEDURE	' v0.26: scroll da lava = scroll da fase 1 (PONTO)
cvb_LAVA_SETUP:
	; 	PALETTE LOAD lava_palette
	LDA #0
	STA pointer
	LDA #63
	STA pointer+1
	LDA #32
	STA temp2
	LDA #cvb_LAVA_PALETTE
	STA temp
	LDA #cvb_LAVA_PALETTE>>8
	STA temp+1
	JSR LDIRVM
	; 	POKE $1C,$40		' CHR-RAM pagina 2 (tiles + sprites da lava)
	LDA #64
	PHA
	LDA #28
	LDY #0
	STA temp
	STY temp+1
	PLA
	STA (temp),Y
	; 	' Igual a fase 1 (que sempre funcionou): TRES nametables IDENTICAS,
	; 	' so' conteudo estatico, e o scroll byte cuida do loop. Conteudo =
	; 	' mar de lava (textura 2x2 dos tiles 96/97/98/99, do proprio
	; 	' desenho do Saulo) + 5 ilhas PEQUENAS 2x2 (v0.27) nas mesmas
	; 	' posicoes das 3 paginas. Sem canhoes, sem eventos, sem anel,
	; 	' sem flip, sem strip.
	; 	#bk = $2000
	TYA
	LDY #32
	STA cvb_#BK
	STY cvb_#BK+1
	; 	GOSUB lava_sea_fill
	JSR cvb_LAVA_SEA_FILL
	; 	#bk = $2400
	LDA #0
	LDY #36
	STA cvb_#BK
	STY cvb_#BK+1
	; 	GOSUB lava_sea_fill
	JSR cvb_LAVA_SEA_FILL
	; 	#bk = $2800
	LDA #0
	LDY #40
	STA cvb_#BK
	STY cvb_#BK+1
	; 	GOSUB lava_sea_fill
	JSR cvb_LAVA_SEA_FILL
	; 	END
	RTS
	; 
	; lava_sea_fill:	' mar de lava 2x2 + ilhas 2x2 em cima de #bk (v0.27)
cvb_LAVA_SEA_FILL:
	; 	#tw = #bk
	LDA cvb_#BK
	LDY cvb_#BK+1
	STA cvb_#TW
	STY cvb_#TW+1
	; 	FOR r = 0 TO 29
	LDA #0
	STA cvb_R
cv541:
	; 		FOR c = 0 TO 31
	LDA #0
	STA cvb_C
cv542:
	; 			VPOKE #tw, 96 + (c AND 1) + 2 * (r AND 1)
	LDA cvb_C
	AND #1
	LDY #0
	CLC
	ADC #96
	TAX
	TYA
	ADC #0
	TAY
	TXA
	PHA
	TYA
	PHA
	LDA cvb_R
	AND #1
	ASL A
	LDY #0
	BCC $+3
	INY
	STA temp
	STY temp+1
	PLA
	TAY
	PLA
	CLC
	ADC temp
	TAX
	TYA
	ADC temp+1
	TAY
	TXA
	PHA
	LDA cvb_#TW
	LDY cvb_#TW+1
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 			#tw = #tw + 1
	INC cvb_#TW
	BNE cv543
	INC cvb_#TW+1
cv543:
	; 		NEXT c
	INC cvb_C
	LDA cvb_C
	CMP #32
	BCC.L cv542
	; 		WAIT			' 32 writes/frame: folga no buffer do NMI
	JSR wait
	; 	NEXT r
	INC cvb_R
	LDA cvb_R
	CMP #30
	BCC.L cv541
	; 	' v0.27: 5 ilhas PEQUENAS (2x2 = 4 tiles de 8x8) em linhas/cols
	; 	' pares, iguais nas 3 paginas -> conteudo estatico, scroll perfeito.
	; 	#tw = #bk + 134		' ilha A: linha 4, col 6
	LDA cvb_#BK
	LDY cvb_#BK+1
	CLC
	ADC #134
	TAX
	TYA
	ADC #0
	TAY
	TXA
	STA cvb_#TW
	STY cvb_#TW+1
	; 	GOSUB lava_isl_a
	JSR cvb_LAVA_ISL_A
	; 	#tw = #bk + 342		' ilha B: linha 10, col 22
	LDA cvb_#BK
	LDY cvb_#BK+1
	CLC
	ADC #86
	TAX
	TYA
	ADC #1
	TAY
	TXA
	STA cvb_#TW
	STY cvb_#TW+1
	; 	GOSUB lava_isl_b
	JSR cvb_LAVA_ISL_B
	; 	#tw = #bk + 524		' ilha C: linha 16, col 12
	LDA cvb_#BK
	LDY cvb_#BK+1
	CLC
	ADC #12
	TAX
	TYA
	ADC #2
	TAY
	TXA
	STA cvb_#TW
	STY cvb_#TW+1
	; 	GOSUB lava_isl_c
	JSR cvb_LAVA_ISL_C
	; 	WAIT
	JSR wait
	; 	#tw = #bk + 666		' ilha A: linha 20, col 26
	LDA cvb_#BK
	LDY cvb_#BK+1
	CLC
	ADC #154
	TAX
	TYA
	ADC #2
	TAY
	TXA
	STA cvb_#TW
	STY cvb_#TW+1
	; 	GOSUB lava_isl_a
	JSR cvb_LAVA_ISL_A
	; 	#tw = #bk + 834		' ilha B: linha 26, col 2
	LDA cvb_#BK
	LDY cvb_#BK+1
	CLC
	ADC #66
	TAX
	TYA
	ADC #3
	TAY
	TXA
	STA cvb_#TW
	STY cvb_#TW+1
	; 	GOSUB lava_isl_b
	JSR cvb_LAVA_ISL_B
	; 	WAIT
	JSR wait
	; 	RETURN
	RTS
	; 
	; lava_isl_a:	' ilha pequena A (2x2) com topo-esquerdo em #tw
cvb_LAVA_ISL_A:
	; 	VPOKE #tw, 108
	LDA #108
	PHA
	LDA cvb_#TW
	LDY cvb_#TW+1
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE #tw + 1, 109
	LDA #109
	PHA
	LDA cvb_#TW
	LDY cvb_#TW+1
	CLC
	ADC #1
	TAX
	TYA
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE #tw + 32, 110
	LDA #110
	PHA
	LDA cvb_#TW
	LDY cvb_#TW+1
	CLC
	ADC #32
	TAX
	TYA
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE #tw + 33, 111
	LDA #111
	PHA
	LDA cvb_#TW
	LDY cvb_#TW+1
	CLC
	ADC #33
	TAX
	TYA
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	RETURN
	RTS
	; 
	; lava_isl_b:	' ilha pequena B (2x2)
cvb_LAVA_ISL_B:
	; 	VPOKE #tw, 119
	LDA #119
	PHA
	LDA cvb_#TW
	LDY cvb_#TW+1
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE #tw + 1, 153
	LDA #153
	PHA
	LDA cvb_#TW
	LDY cvb_#TW+1
	CLC
	ADC #1
	TAX
	TYA
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE #tw + 32, 154
	LDA #154
	PHA
	LDA cvb_#TW
	LDY cvb_#TW+1
	CLC
	ADC #32
	TAX
	TYA
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE #tw + 33, 155
	LDA #155
	PHA
	LDA cvb_#TW
	LDY cvb_#TW+1
	CLC
	ADC #33
	TAX
	TYA
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	RETURN
	RTS
	; 
	; lava_isl_c:	' ilha pequena C (2x2)
cvb_LAVA_ISL_C:
	; 	VPOKE #tw, 149
	LDA #149
	PHA
	LDA cvb_#TW
	LDY cvb_#TW+1
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE #tw + 1, 150
	LDA #150
	PHA
	LDA cvb_#TW
	LDY cvb_#TW+1
	CLC
	ADC #1
	TAX
	TYA
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE #tw + 32, 151
	LDA #151
	PHA
	LDA cvb_#TW
	LDY cvb_#TW+1
	CLC
	ADC #32
	TAX
	TYA
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE #tw + 33, 152
	LDA #152
	PHA
	LDA cvb_#TW
	LDY cvb_#TW+1
	CLC
	ADC #33
	TAX
	TYA
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	RETURN
	RTS
	; 
	; 
	; lava_tick: PROCEDURE	' v0.24: flip no TOPO na fase 7; strip $2800 na 6
cvb_LAVA_TICK:
	; 	' (bug v0.22 provado no emu: 64/70 writes caiam em slots VISIVEIS
	; 	' inclusive o MEIO da tela porque #ld andava +32 e o topo anda -32;
	; 	' v0.23 acertou o slot mas flipava 8px cedo e abandonou o $2800).
	; 	IF (scroll_y AND 7) = 7 THEN
	LDA cvb_SCROLL_Y
	AND #7
	CMP #7
	BNE.L cv544
	; 		GOSUB lava_in
	JSR cvb_LAVA_IN
	; 	ELSEIF (scroll_y AND 7) = 6 THEN
	JMP cv545
cv544:
	LDA cvb_SCROLL_Y
	AND #7
	CMP #6
	BNE.L cv546
	; 		IF wrf = 1 THEN GOSUB lava_strip
	LDA cvb_WRF
	CMP #1
	BNE.L cv547
	JSR cvb_LAVA_STRIP
cv547:
	; 	END IF
cv545:
cv546:
	; 	END
	RTS
	; 
	; lava_in: PROCEDURE	' v0.24: flip do slot do TOPO no frame da costura
cvb_LAVA_IN:
	; 	IF wrf = 0 THEN		' 1a costura: trava a fase do anel com o scroll
	LDA cvb_WRF
	BNE.L cv548
	; 		wr = scroll_y / 8		' slot do topo agora (0-29)
	LDA cvb_SCROLL_Y
	LSR A
	LSR A
	LSR A
	STA cvb_WR
	; 		wrf = 1
	LDA #1
	STA cvb_WRF
	; 	ELSE
	JMP cv549
cv548:
	; 		wr = wr - 1		' linha-mundo seguinte (anel 60: wrap 0->59)
	DEC cvb_WR
	; 		IF wr = $ff THEN wr = 59
	LDA cvb_WR
	CMP #255
	BNE.L cv550
	LDA #59
	STA cvb_WR
cv550:
	; 	END IF
cv549:
	; 	w = wr			' w = linha dentro do mapa (0-29), RESTORE na metade
	LDA cvb_WR
	STA cvb_W
	; 	IF w >= 30 THEN
	CMP #30
	BCC.L cv551
	; 		w = w - 30
	SEC
	SBC #30
	STA cvb_W
	; 		RESTORE lava_map_b
	LDA #cvb_LAVA_MAP_B
	LDY #cvb_LAVA_MAP_B>>8
	STA read_pointer
	STY read_pointer+1
	; 	ELSE
	JMP cv552
cv551:
	; 		RESTORE lava_map_a
	LDA #cvb_LAVA_MAP_A
	LDY #cvb_LAVA_MAP_A>>8
	STA read_pointer
	STY read_pointer+1
	; 	END IF
cv552:
	; 	' #ld = $2000 + w*32; read_pointer += w*32 (low=w<<5, high=w>>3;
	; 	' 16 bits de verdade = adeus bug do ASL sem carry da v0.19)
	; 	ASM LDA cvb_W
 LDA cvb_W
	; 	ASM ASL A
 ASL A
	; 	ASM ASL A
 ASL A
	; 	ASM ASL A
 ASL A
	; 	ASM ASL A
 ASL A
	; 	ASM ASL A
 ASL A
	; 	ASM STA cvb_#LD
 STA cvb_#LD
	; 	ASM STA cvb_#T2
 STA cvb_#T2
	; 	ASM LDA cvb_W
 LDA cvb_W
	; 	ASM LSR A
 LSR A
	; 	ASM LSR A
 LSR A
	; 	ASM LSR A
 LSR A
	; 	ASM STA cvb_#T2+1
 STA cvb_#T2+1
	; 	ASM CLC
 CLC
	; 	ASM ADC #$20
 ADC #$20
	; 	ASM STA cvb_#LD+1
 STA cvb_#LD+1
	; 	ASM LDA read_pointer
 LDA read_pointer
	; 	ASM CLC
 CLC
	; 	ASM ADC cvb_#T2
 ADC cvb_#T2
	; 	ASM STA read_pointer
 STA read_pointer
	; 	ASM LDA read_pointer+1
 LDA read_pointer+1
	; 	ASM ADC cvb_#T2+1
 ADC cvb_#T2+1
	; 	ASM STA read_pointer+1
 STA read_pointer+1
	; 	FOR c = 0 TO 31		' 32 writes na mesma moldura (< PPUSIZE 48)
	LDA #0
	STA cvb_C
cv553:
	; 		READ BYTE e
	JSR _read8
	STA cvb_E
	; 		VPOKE #ld + c,e
	PHA
	LDA cvb_#LD
	LDY cvb_#LD+1
	CLC
	ADC cvb_C
	TAX
	TYA
	ADC #0
	TAY
	TXA
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	NEXT c
	INC cvb_C
	LDA cvb_C
	CMP #32
	BCC.L cv553
	; 	END
	RTS
	; 
	; lava_strip: PROCEDURE	' $2800 slot 0 = linha ABAIXO da janela (topo + 30)
cvb_LAVA_STRIP:
	; 	w = wr + 30
	LDA cvb_WR
	CLC
	ADC #30
	STA cvb_W
	; 	IF w >= 60 THEN w = w - 60
	CMP #60
	BCC.L cv554
	SEC
	SBC #60
	STA cvb_W
cv554:
	; lava_strip_w:		' entrada com w ja' calculado (lava_setup reusa)
cvb_LAVA_STRIP_W:
	; 	IF w >= 30 THEN
	LDA cvb_W
	CMP #30
	BCC.L cv555
	; 		w = w - 30
	SEC
	SBC #30
	STA cvb_W
	; 		RESTORE lava_map_b
	LDA #cvb_LAVA_MAP_B
	LDY #cvb_LAVA_MAP_B>>8
	STA read_pointer
	STY read_pointer+1
	; 	ELSE
	JMP cv556
cv555:
	; 		RESTORE lava_map_a
	LDA #cvb_LAVA_MAP_A
	LDY #cvb_LAVA_MAP_A>>8
	STA read_pointer
	STY read_pointer+1
	; 	END IF
cv556:
	; 	ASM LDA cvb_W
 LDA cvb_W
	; 	ASM ASL A
 ASL A
	; 	ASM ASL A
 ASL A
	; 	ASM ASL A
 ASL A
	; 	ASM ASL A
 ASL A
	; 	ASM ASL A
 ASL A
	; 	ASM STA cvb_#T2
 STA cvb_#T2
	; 	ASM LDA cvb_W
 LDA cvb_W
	; 	ASM LSR A
 LSR A
	; 	ASM LSR A
 LSR A
	; 	ASM LSR A
 LSR A
	; 	ASM STA cvb_#T2+1
 STA cvb_#T2+1
	; 	ASM LDA read_pointer
 LDA read_pointer
	; 	ASM CLC
 CLC
	; 	ASM ADC cvb_#T2
 ADC cvb_#T2
	; 	ASM STA read_pointer
 STA read_pointer
	; 	ASM LDA read_pointer+1
 LDA read_pointer+1
	; 	ASM ADC cvb_#T2+1
 ADC cvb_#T2+1
	; 	ASM STA read_pointer+1
 STA read_pointer+1
	; 	FOR c = 0 TO 31
	LDA #0
	STA cvb_C
cv557:
	; 		READ BYTE e
	JSR _read8
	STA cvb_E
	; 		VPOKE $2800 + c,e
	PHA
	LDA cvb_C
	LDY #0
	CLC
	TAX
	TYA
	ADC #40
	TAY
	TXA
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	NEXT c
	INC cvb_C
	LDA cvb_C
	CMP #32
	BCC.L cv557
	; 	END
	RTS
	; 
	; 	' ==== gerado por gera_lava.py (v0.19): layout da fase 2 ====
	; 	' mapas EXPANDIDOS: 30 tile-rows x 32 tiles por metade
	; 	' (metatile mx*2,my*2 -> tiles 2x2 via tabela de ids dedup)
	; lava_map_a:
cvb_LAVA_MAP_A:
	; 	DATA BYTE 96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,112,113,116,97,96,97,96,97
	DB $60,$61,$60,$61,$60,$61,$60,$61
	DB $60,$61,$60,$61,$60,$61,$60,$61
	DB $60,$61,$60,$61,$60,$61,$60,$61
	DB $70,$71,$74,$61,$60,$61,$60,$61
	; 	DATA BYTE 98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,114,115,117,118,98,99,98,99
	DB $62,$63,$62,$63,$62,$63,$62,$63
	DB $62,$63,$62,$63,$62,$63,$62,$63
	DB $62,$63,$62,$63,$62,$63,$62,$63
	DB $72,$73,$75,$76,$62,$63,$62,$63
	; 	DATA BYTE 96,97,96,97,96,97,96,97,96,97,96,97,96,97,119,153,96,97,96,97,96,97,96,127,130,131,134,135,96,97,96,97
	DB $60,$61,$60,$61,$60,$61,$60,$61
	DB $60,$61,$60,$61,$60,$61,$77,$99
	DB $60,$61,$60,$61,$60,$61,$60,$7f
	DB $82,$83,$86,$87,$60,$61,$60,$61
	; 	DATA BYTE 98,99,98,99,98,99,98,99,98,99,98,99,98,99,154,155,98,99,98,99,98,99,128,129,132,133,136,137,98,99,98,99
	DB $62,$63,$62,$63,$62,$63,$62,$63
	DB $62,$63,$62,$63,$62,$63,$9a,$9b
	DB $62,$63,$62,$63,$62,$63,$80,$81
	DB $84,$85,$88,$89,$62,$63,$62,$63
	; 	DATA BYTE 96,97,96,97,108,109,96,97,96,97,112,113,116,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97
	DB $60,$61,$60,$61,$6c,$6d,$60,$61
	DB $60,$61,$70,$71,$74,$61,$60,$61
	DB $60,$61,$60,$61,$60,$61,$60,$61
	DB $60,$61,$60,$61,$60,$61,$60,$61
	; 	DATA BYTE 98,99,98,99,110,111,98,99,98,99,114,115,117,118,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99
	DB $62,$63,$62,$63,$6e,$6f,$62,$63
	DB $62,$63,$72,$73,$75,$76,$62,$63
	DB $62,$63,$62,$63,$62,$63,$62,$63
	DB $62,$63,$62,$63,$62,$63,$62,$63
	; 	DATA BYTE 96,97,96,97,96,97,96,97,96,127,130,131,134,135,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97
	DB $60,$61,$60,$61,$60,$61,$60,$61
	DB $60,$7f,$82,$83,$86,$87,$60,$61
	DB $60,$61,$60,$61,$60,$61,$60,$61
	DB $60,$61,$60,$61,$60,$61,$60,$61
	; 	DATA BYTE 98,99,98,99,98,99,98,99,128,129,132,133,136,137,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99
	DB $62,$63,$62,$63,$62,$63,$62,$63
	DB $80,$81,$84,$85,$88,$89,$62,$63
	DB $62,$63,$62,$63,$62,$63,$62,$63
	DB $62,$63,$62,$63,$62,$63,$62,$63
	; 	DATA BYTE 96,97,96,97,96,97,96,97,96,97,96,97,108,109,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97
	DB $60,$61,$60,$61,$60,$61,$60,$61
	DB $60,$61,$60,$61,$6c,$6d,$60,$61
	DB $60,$61,$60,$61,$60,$61,$60,$61
	DB $60,$61,$60,$61,$60,$61,$60,$61
	; 	DATA BYTE 98,99,98,99,98,99,98,99,98,99,98,99,110,111,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99
	DB $62,$63,$62,$63,$62,$63,$62,$63
	DB $62,$63,$62,$63,$6e,$6f,$62,$63
	DB $62,$63,$62,$63,$62,$63,$62,$63
	DB $62,$63,$62,$63,$62,$63,$62,$63
	; 	DATA BYTE 96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97
	DB $60,$61,$60,$61,$60,$61,$60,$61
	DB $60,$61,$60,$61,$60,$61,$60,$61
	DB $60,$61,$60,$61,$60,$61,$60,$61
	DB $60,$61,$60,$61,$60,$61,$60,$61
	; 	DATA BYTE 98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99
	DB $62,$63,$62,$63,$62,$63,$62,$63
	DB $62,$63,$62,$63,$62,$63,$62,$63
	DB $62,$63,$62,$63,$62,$63,$62,$63
	DB $62,$63,$62,$63,$62,$63,$62,$63
	; 	DATA BYTE 96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,119,153,96,97,96,97,96,97,96,97,96,97
	DB $60,$61,$60,$61,$60,$61,$60,$61
	DB $60,$61,$60,$61,$60,$61,$60,$61
	DB $60,$61,$60,$61,$77,$99,$60,$61
	DB $60,$61,$60,$61,$60,$61,$60,$61
	; 	DATA BYTE 98,99,98,99,98,99,98,99,156,99,98,99,98,99,98,99,98,99,98,99,154,155,98,99,98,99,98,99,98,99,98,99
	DB $62,$63,$62,$63,$62,$63,$62,$63
	DB $9c,$63,$62,$63,$62,$63,$62,$63
	DB $62,$63,$62,$63,$9a,$9b,$62,$63
	DB $62,$63,$62,$63,$62,$63,$62,$63
	; 	DATA BYTE 96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97
	DB $60,$61,$60,$61,$60,$61,$60,$61
	DB $60,$61,$60,$61,$60,$61,$60,$61
	DB $60,$61,$60,$61,$60,$61,$60,$61
	DB $60,$61,$60,$61,$60,$61,$60,$61
	; 	DATA BYTE 98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99
	DB $62,$63,$62,$63,$62,$63,$62,$63
	DB $62,$63,$62,$63,$62,$63,$62,$63
	DB $62,$63,$62,$63,$62,$63,$62,$63
	DB $62,$63,$62,$63,$62,$63,$62,$63
	; 	DATA BYTE 96,97,96,97,96,97,119,153,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97
	DB $60,$61,$60,$61,$60,$61,$77,$99
	DB $60,$61,$60,$61,$60,$61,$60,$61
	DB $60,$61,$60,$61,$60,$61,$60,$61
	DB $60,$61,$60,$61,$60,$61,$60,$61
	; 	DATA BYTE 98,99,98,99,98,99,154,155,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99
	DB $62,$63,$62,$63,$62,$63,$9a,$9b
	DB $62,$63,$62,$63,$62,$63,$62,$63
	DB $62,$63,$62,$63,$62,$63,$62,$63
	DB $62,$63,$62,$63,$62,$63,$62,$63
	; 	DATA BYTE 96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97
	DB $60,$61,$60,$61,$60,$61,$60,$61
	DB $60,$61,$60,$61,$60,$61,$60,$61
	DB $60,$61,$60,$61,$60,$61,$60,$61
	DB $60,$61,$60,$61,$60,$61,$60,$61
	; 	DATA BYTE 98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99
	DB $62,$63,$62,$63,$62,$63,$62,$63
	DB $62,$63,$62,$63,$62,$63,$62,$63
	DB $62,$63,$62,$63,$62,$63,$62,$63
	DB $62,$63,$62,$63,$62,$63,$62,$63
	; 	DATA BYTE 96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,108,109,96,97,96,97,96,97,96,97,96,97,96,97
	DB $60,$61,$60,$61,$60,$61,$60,$61
	DB $60,$61,$60,$61,$60,$61,$60,$61
	DB $60,$61,$6c,$6d,$60,$61,$60,$61
	DB $60,$61,$60,$61,$60,$61,$60,$61
	; 	DATA BYTE 98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,110,111,98,99,98,99,98,99,98,99,98,99,98,99
	DB $62,$63,$62,$63,$62,$63,$62,$63
	DB $62,$63,$62,$63,$62,$63,$62,$63
	DB $62,$63,$6e,$6f,$62,$63,$62,$63
	DB $62,$63,$62,$63,$62,$63,$62,$63
	; 	DATA BYTE 96,97,96,97,96,97,96,97,96,97,119,153,149,150,96,97,149,150,108,109,96,97,96,97,96,97,119,153,96,97,96,97
	DB $60,$61,$60,$61,$60,$61,$60,$61
	DB $60,$61,$77,$99,$95,$96,$60,$61
	DB $95,$96,$6c,$6d,$60,$61,$60,$61
	DB $60,$61,$77,$99,$60,$61,$60,$61
	; 	DATA BYTE 98,99,98,99,98,99,98,99,98,99,154,155,151,152,98,99,151,152,110,111,98,99,98,99,98,99,154,155,98,99,98,99
	DB $62,$63,$62,$63,$62,$63,$62,$63
	DB $62,$63,$9a,$9b,$97,$98,$62,$63
	DB $97,$98,$6e,$6f,$62,$63,$62,$63
	DB $62,$63,$9a,$9b,$62,$63,$62,$63
	; 	DATA BYTE 96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97
	DB $60,$61,$60,$61,$60,$61,$60,$61
	DB $60,$61,$60,$61,$60,$61,$60,$61
	DB $60,$61,$60,$61,$60,$61,$60,$61
	DB $60,$61,$60,$61,$60,$61,$60,$61
	; 	DATA BYTE 98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99
	DB $62,$63,$62,$63,$62,$63,$62,$63
	DB $62,$63,$62,$63,$62,$63,$62,$63
	DB $62,$63,$62,$63,$62,$63,$62,$63
	DB $62,$63,$62,$63,$62,$63,$62,$63
	; 	DATA BYTE 96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97
	DB $60,$61,$60,$61,$60,$61,$60,$61
	DB $60,$61,$60,$61,$60,$61,$60,$61
	DB $60,$61,$60,$61,$60,$61,$60,$61
	DB $60,$61,$60,$61,$60,$61,$60,$61
	; 	DATA BYTE 98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99
	DB $62,$63,$62,$63,$62,$63,$62,$63
	DB $62,$63,$62,$63,$62,$63,$62,$63
	DB $62,$63,$62,$63,$62,$63,$62,$63
	DB $62,$63,$62,$63,$62,$63,$62,$63
	; 	DATA BYTE 96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,119,153,96,97,96,97,96,97
	DB $60,$61,$60,$61,$60,$61,$60,$61
	DB $60,$61,$60,$61,$60,$61,$60,$61
	DB $60,$61,$60,$61,$60,$61,$60,$61
	DB $77,$99,$60,$61,$60,$61,$60,$61
	; 	DATA BYTE 98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,154,155,98,99,98,99,98,99
	DB $62,$63,$62,$63,$62,$63,$62,$63
	DB $62,$63,$62,$63,$62,$63,$62,$63
	DB $62,$63,$62,$63,$62,$63,$62,$63
	DB $9a,$9b,$62,$63,$62,$63,$62,$63
	; lava_map_b:
cvb_LAVA_MAP_B:
	; 	DATA BYTE 96,97,96,97,96,97,96,97,96,97,96,97,108,109,96,97,96,97,96,97,96,97,96,97,96,97,149,150,96,97,96,97
	DB $60,$61,$60,$61,$60,$61,$60,$61
	DB $60,$61,$60,$61,$6c,$6d,$60,$61
	DB $60,$61,$60,$61,$60,$61,$60,$61
	DB $60,$61,$95,$96,$60,$61,$60,$61
	; 	DATA BYTE 98,99,98,99,98,99,98,99,98,99,98,99,110,111,98,99,98,99,98,99,98,99,98,99,156,99,151,152,98,99,98,99
	DB $62,$63,$62,$63,$62,$63,$62,$63
	DB $62,$63,$62,$63,$6e,$6f,$62,$63
	DB $62,$63,$62,$63,$62,$63,$62,$63
	DB $9c,$63,$97,$98,$62,$63,$62,$63
	; 	DATA BYTE 119,120,123,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,108,109,96,97,96,97
	DB $77,$78,$7b,$61,$60,$61,$60,$61
	DB $60,$61,$60,$61,$60,$61,$60,$61
	DB $60,$61,$60,$61,$60,$61,$60,$61
	DB $60,$61,$6c,$6d,$60,$61,$60,$61
	; 	DATA BYTE 121,122,124,125,126,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,156,99,98,99,98,99,110,111,98,99,98,99
	DB $79,$7a,$7c,$7d,$7e,$63,$62,$63
	DB $62,$63,$62,$63,$62,$63,$62,$63
	DB $62,$63,$62,$63,$9c,$63,$62,$63
	DB $62,$63,$6e,$6f,$62,$63,$62,$63
	; 	DATA BYTE 96,138,141,142,145,146,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,119,153,96,97,96,97
	DB $60,$8a,$8d,$8e,$91,$92,$60,$61
	DB $60,$61,$60,$61,$60,$61,$60,$61
	DB $60,$61,$60,$61,$60,$61,$60,$61
	DB $60,$61,$77,$99,$60,$61,$60,$61
	; 	DATA BYTE 139,140,143,144,147,148,156,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,154,155,98,99,98,99
	DB $8b,$8c,$8f,$90,$93,$94,$9c,$63
	DB $62,$63,$62,$63,$62,$63,$62,$63
	DB $62,$63,$62,$63,$62,$63,$62,$63
	DB $62,$63,$9a,$9b,$62,$63,$62,$63
	; 	DATA BYTE 96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97
	DB $60,$61,$60,$61,$60,$61,$60,$61
	DB $60,$61,$60,$61,$60,$61,$60,$61
	DB $60,$61,$60,$61,$60,$61,$60,$61
	DB $60,$61,$60,$61,$60,$61,$60,$61
	; 	DATA BYTE 98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99
	DB $62,$63,$62,$63,$62,$63,$62,$63
	DB $62,$63,$62,$63,$62,$63,$62,$63
	DB $62,$63,$62,$63,$62,$63,$62,$63
	DB $62,$63,$62,$63,$62,$63,$62,$63
	; 	DATA BYTE 96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97
	DB $60,$61,$60,$61,$60,$61,$60,$61
	DB $60,$61,$60,$61,$60,$61,$60,$61
	DB $60,$61,$60,$61,$60,$61,$60,$61
	DB $60,$61,$60,$61,$60,$61,$60,$61
	; 	DATA BYTE 98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99
	DB $62,$63,$62,$63,$62,$63,$62,$63
	DB $62,$63,$62,$63,$62,$63,$62,$63
	DB $62,$63,$62,$63,$62,$63,$62,$63
	DB $62,$63,$62,$63,$62,$63,$62,$63
	; 	DATA BYTE 96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,108,109,96,97,119,153,96,97
	DB $60,$61,$60,$61,$60,$61,$60,$61
	DB $60,$61,$60,$61,$60,$61,$60,$61
	DB $60,$61,$60,$61,$60,$61,$60,$61
	DB $6c,$6d,$60,$61,$77,$99,$60,$61
	; 	DATA BYTE 98,99,98,99,98,99,98,99,156,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,110,111,98,99,154,155,98,99
	DB $62,$63,$62,$63,$62,$63,$62,$63
	DB $9c,$63,$62,$63,$62,$63,$62,$63
	DB $62,$63,$62,$63,$62,$63,$62,$63
	DB $6e,$6f,$62,$63,$9a,$9b,$62,$63
	; 	DATA BYTE 96,97,96,97,96,97,119,153,96,97,108,109,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,108,109,96,97
	DB $60,$61,$60,$61,$60,$61,$77,$99
	DB $60,$61,$6c,$6d,$60,$61,$60,$61
	DB $60,$61,$60,$61,$60,$61,$60,$61
	DB $60,$61,$60,$61,$6c,$6d,$60,$61
	; 	DATA BYTE 98,99,98,99,98,99,154,155,98,99,110,111,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,110,111,98,99
	DB $62,$63,$62,$63,$62,$63,$9a,$9b
	DB $62,$63,$6e,$6f,$62,$63,$62,$63
	DB $62,$63,$62,$63,$62,$63,$62,$63
	DB $62,$63,$62,$63,$6e,$6f,$62,$63
	; 	DATA BYTE 96,97,119,120,123,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,119,153,96,97,96,97
	DB $60,$61,$77,$78,$7b,$61,$60,$61
	DB $60,$61,$60,$61,$60,$61,$60,$61
	DB $60,$61,$60,$61,$60,$61,$60,$61
	DB $60,$61,$77,$99,$60,$61,$60,$61
	; 	DATA BYTE 98,99,121,122,124,125,126,99,98,99,98,99,98,99,156,99,98,99,98,99,98,99,98,99,98,99,154,155,98,99,98,99
	DB $62,$63,$79,$7a,$7c,$7d,$7e,$63
	DB $62,$63,$62,$63,$62,$63,$9c,$63
	DB $62,$63,$62,$63,$62,$63,$62,$63
	DB $62,$63,$9a,$9b,$62,$63,$62,$63
	; 	DATA BYTE 96,97,96,138,141,142,145,146,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97
	DB $60,$61,$60,$8a,$8d,$8e,$91,$92
	DB $60,$61,$60,$61,$60,$61,$60,$61
	DB $60,$61,$60,$61,$60,$61,$60,$61
	DB $60,$61,$60,$61,$60,$61,$60,$61
	; 	DATA BYTE 98,99,139,140,143,144,147,148,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99
	DB $62,$63,$8b,$8c,$8f,$90,$93,$94
	DB $62,$63,$62,$63,$62,$63,$62,$63
	DB $62,$63,$62,$63,$62,$63,$62,$63
	DB $62,$63,$62,$63,$62,$63,$62,$63
	; 	DATA BYTE 96,97,96,97,96,97,149,150,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97
	DB $60,$61,$60,$61,$60,$61,$95,$96
	DB $60,$61,$60,$61,$60,$61,$60,$61
	DB $60,$61,$60,$61,$60,$61,$60,$61
	DB $60,$61,$60,$61,$60,$61,$60,$61
	; 	DATA BYTE 98,99,98,99,156,99,151,152,98,99,98,99,98,99,156,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99
	DB $62,$63,$62,$63,$9c,$63,$97,$98
	DB $62,$63,$62,$63,$62,$63,$9c,$63
	DB $62,$63,$62,$63,$62,$63,$62,$63
	DB $62,$63,$62,$63,$62,$63,$62,$63
	; 	DATA BYTE 96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,108,109,96,97,119,153,96,97,96,97,96,97,96,97
	DB $60,$61,$60,$61,$60,$61,$60,$61
	DB $60,$61,$60,$61,$60,$61,$60,$61
	DB $60,$61,$6c,$6d,$60,$61,$77,$99
	DB $60,$61,$60,$61,$60,$61,$60,$61
	; 	DATA BYTE 98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,110,111,98,99,154,155,98,99,98,99,98,99,98,99
	DB $62,$63,$62,$63,$62,$63,$62,$63
	DB $62,$63,$62,$63,$62,$63,$62,$63
	DB $62,$63,$6e,$6f,$62,$63,$9a,$9b
	DB $62,$63,$62,$63,$62,$63,$62,$63
	; 	DATA BYTE 96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97
	DB $60,$61,$60,$61,$60,$61,$60,$61
	DB $60,$61,$60,$61,$60,$61,$60,$61
	DB $60,$61,$60,$61,$60,$61,$60,$61
	DB $60,$61,$60,$61,$60,$61,$60,$61
	; 	DATA BYTE 98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,156,99,98,99
	DB $62,$63,$62,$63,$62,$63,$62,$63
	DB $62,$63,$62,$63,$62,$63,$62,$63
	DB $62,$63,$62,$63,$62,$63,$62,$63
	DB $62,$63,$62,$63,$9c,$63,$62,$63
	; 	DATA BYTE 96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,119,153,96,97,149,150
	DB $60,$61,$60,$61,$60,$61,$60,$61
	DB $60,$61,$60,$61,$60,$61,$60,$61
	DB $60,$61,$60,$61,$60,$61,$60,$61
	DB $60,$61,$77,$99,$60,$61,$95,$96
	; 	DATA BYTE 98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,154,155,98,99,151,152
	DB $62,$63,$62,$63,$62,$63,$62,$63
	DB $62,$63,$62,$63,$62,$63,$62,$63
	DB $62,$63,$62,$63,$62,$63,$62,$63
	DB $62,$63,$9a,$9b,$62,$63,$97,$98
	; 	DATA BYTE 96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,108,109,108,109,96,97,96,97,96,97,96,97,96,97,96,97
	DB $60,$61,$60,$61,$60,$61,$60,$61
	DB $60,$61,$60,$61,$60,$61,$60,$61
	DB $6c,$6d,$6c,$6d,$60,$61,$60,$61
	DB $60,$61,$60,$61,$60,$61,$60,$61
	; 	DATA BYTE 98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,110,111,110,111,98,99,98,99,98,99,98,99,98,99,98,99
	DB $62,$63,$62,$63,$62,$63,$62,$63
	DB $62,$63,$62,$63,$62,$63,$62,$63
	DB $6e,$6f,$6e,$6f,$62,$63,$62,$63
	DB $62,$63,$62,$63,$62,$63,$62,$63
	; 	DATA BYTE 96,97,96,97,96,97,119,153,96,97,96,97,149,150,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97
	DB $60,$61,$60,$61,$60,$61,$77,$99
	DB $60,$61,$60,$61,$95,$96,$60,$61
	DB $60,$61,$60,$61,$60,$61,$60,$61
	DB $60,$61,$60,$61,$60,$61,$60,$61
	; 	DATA BYTE 98,99,98,99,98,99,154,155,98,99,98,99,151,152,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99
	DB $62,$63,$62,$63,$62,$63,$9a,$9b
	DB $62,$63,$62,$63,$97,$98,$62,$63
	DB $62,$63,$62,$63,$62,$63,$62,$63
	DB $62,$63,$62,$63,$62,$63,$62,$63
	; 	' v0.28: FASE 4 - ATLANTIS. MESMOS tiles da lava (mar + ilhotas),
	; 	' so' muda a paleta p/ agua. Setup identico (3 paginas estaticas
	; 	' identicas) = scroll perfeito pelo mesmo esquema da fase 1.
	; agua_setup: PROCEDURE
cvb_AGUA_SETUP:
	; 	PALETTE LOAD agua_palette
	LDA #0
	STA pointer
	LDA #63
	STA pointer+1
	LDA #32
	STA temp2
	LDA #cvb_AGUA_PALETTE
	STA temp
	LDA #cvb_AGUA_PALETTE>>8
	STA temp+1
	JSR LDIRVM
	; 	POKE $1C,$40		' mesma pagina 2 de CHR-RAM da lava
	LDA #64
	PHA
	LDA #28
	LDY #0
	STA temp
	STY temp+1
	PLA
	STA (temp),Y
	; 	#bk = $2000
	TYA
	LDY #32
	STA cvb_#BK
	STY cvb_#BK+1
	; 	GOSUB lava_sea_fill
	JSR cvb_LAVA_SEA_FILL
	; 	#bk = $2400
	LDA #0
	LDY #36
	STA cvb_#BK
	STY cvb_#BK+1
	; 	GOSUB lava_sea_fill
	JSR cvb_LAVA_SEA_FILL
	; 	#bk = $2800
	LDA #0
	LDY #40
	STA cvb_#BK
	STY cvb_#BK+1
	; 	GOSUB lava_sea_fill
	JSR cvb_LAVA_SEA_FILL
	; 	END
	RTS
	; 
	; 	' (v0.28: stars_fill VOLTOU p/ o banco 0 - ver nota la'.)
	; 
	; lava_can:
cvb_LAVA_CAN:
	; 	DATA BYTE 5
	DB $05
	; 	DATA BYTE 12,9
	DB $0c,$09
	; 	DATA BYTE 1,8
	DB $01,$08
	; 	DATA BYTE 10,28
	DB $0a,$1c
	; 	DATA BYTE 13,21
	DB $0d,$15
	; 	DATA BYTE 5,29
	DB $05,$1d
	; lava_palette:
cvb_LAVA_PALETTE:
	; 	DATA BYTE $07,$16,$1C,$0C	' fundo 0: LAVA (fundo universal $07)
	DB $07,$16,$1c,$0c
	; 	DATA BYTE $07,$16,$1C,$0C	' fundo 1 (idem: reserva)
	DB $07,$16,$1c,$0c
	; 	DATA BYTE $07,$16,$1C,$0C	' fundo 2
	DB $07,$16,$1c,$0c
	; 	DATA BYTE $07,$16,$1C,$0C	' fundo 3
	DB $07,$16,$1c,$0c
	; 	DATA BYTE $0F,$00,$10,$30	' sprites 0: cinzas (nave, placar)
	DB $0f,$00,$10,$30
	; 	DATA BYTE $0F,$16,$21,$12	' sprites 1: vermelho/azuis
	DB $0f,$16,$21,$12
	; 	DATA BYTE $0F,$19,$2A,$30	' sprites 2: verdes (chama/shard)
	DB $0f,$19,$2a,$30
	; 	DATA BYTE $0F,$1C,$3C,$30	' sprites 3: quentes (explosao/tiros)
	DB $0f,$1c,$3c,$30
	; agua_palette:					' v0.28: ATLANTIS (fase 4) - mesma
cvb_AGUA_PALETTE:
	; 	DATA BYTE $0C,$11,$02,$01	'   estrutura da lava, so' azuis:
	DB $0c,$11,$02,$01
	; 	DATA BYTE $0C,$11,$02,$01	'   universal $0C (azul profundo),
	DB $0c,$11,$02,$01
	; 	DATA BYTE $0C,$11,$02,$01	'   veias $11, rocha $02/$01
	DB $0c,$11,$02,$01
	; 	DATA BYTE $0C,$11,$02,$01
	DB $0c,$11,$02,$01
	; 	DATA BYTE $0F,$00,$10,$30	' sprites iguais aos da lava
	DB $0f,$00,$10,$30
	; 	DATA BYTE $0F,$16,$21,$12
	DB $0f,$16,$21,$12
	; 	DATA BYTE $0F,$19,$2A,$30
	DB $0f,$19,$2a,$30
	; 	DATA BYTE $0F,$1C,$3C,$30
	DB $0f,$1c,$3c,$30
	; 
	; BANK 2	' v0.15: trilhas (~2.9KB): player do NMI rele music_bank a cada nota
BANK_3_FREE:	EQU $bfff-$
	TIMES $bfff-$ DB $ff
	DB $02
	FORG $04010
	ORG $8000
	; mus_stage1:
cvb_MUS_STAGE1:
	; 	DATA BYTE 1
	DB $01
	; 	MUSIC G4Y,G4X,G2W,M1
	db $a0,$60,$08,$01
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,A4#X,S,M2
	db $3f,$63,$3f,$02
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,D5X,S,M1
	db $3f,$67,$3f,$01
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,G5X,S,M2
	db $3f,$6c,$3f,$02
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,D5X,S,M1
	db $3f,$67,$3f,$01
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,A4#X,S,M2
	db $3f,$63,$3f,$02
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,M1
	db $3f,$3f,$3f,$01
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,G4X,F2W,M1
	db $3f,$60,$06,$01
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,A4#X,S,M2
	db $3f,$63,$3f,$02
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC G4Y,G4X,F2W,M1
	db $a0,$60,$06,$01
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,A4#X,S,M2
	db $3f,$63,$3f,$02
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,D5X,S,M1
	db $3f,$67,$3f,$01
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,G5X,S,M2
	db $3f,$6c,$3f,$02
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,D5X,S,M1
	db $3f,$67,$3f,$01
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,G5X,S,M2
	db $3f,$6c,$3f,$02
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,M1
	db $3f,$3f,$3f,$01
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,D5X,S,M1
	db $3f,$67,$3f,$01
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC D4#Y,A4#X,S,M2
	db $9c,$63,$3f,$02
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC D4#Y,F4X,F2W,M1
	db $9c,$5e,$06,$01
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,A4X,S,M2
	db $3f,$62,$3f,$02
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,C5X,S,M1
	db $3f,$65,$3f,$01
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,F5X,S,M2
	db $3f,$6a,$3f,$02
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,C5X,G2W,M1
	db $3f,$65,$08,$01
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,A4X,S,M2
	db $3f,$62,$3f,$02
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,M1
	db $3f,$3f,$3f,$01
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC C4Y,F4X,S,M1
	db $99,$5e,$3f,$01
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,A4X,S,M2
	db $3f,$62,$3f,$02
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC C4Y,F4X,G2W,M1
	db $99,$5e,$08,$01
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,A4X,S,M2
	db $3f,$62,$3f,$02
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,C5X,S,M1
	db $3f,$65,$3f,$01
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,A4X,S,M2
	db $3f,$62,$3f,$02
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,G4X,S,M1
	db $3f,$60,$3f,$01
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC D4Y,A4#X,S,M2
	db $9b,$63,$3f,$02
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,M1
	db $3f,$3f,$3f,$01
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,D5X,S,M1
	db $3f,$67,$3f,$01
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC D4Y,G5X,S,M1
	db $9b,$6c,$3f,$01
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC D4Y,G4X,G2W,M1
	db $9b,$60,$08,$01
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,A4#X,S,M2
	db $3f,$63,$3f,$02
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,D5X,S,M1
	db $3f,$67,$3f,$01
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,G5X,S,M2
	db $3f,$6c,$3f,$02
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,D5X,S,M1
	db $3f,$67,$3f,$01
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,A4#X,S,M2
	db $3f,$63,$3f,$02
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,M1
	db $3f,$3f,$3f,$01
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,G4X,F2W,M1
	db $3f,$60,$06,$01
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,A4#X,S,M2
	db $3f,$63,$3f,$02
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC D4Y,G4X,F2W,M1
	db $9b,$60,$06,$01
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,A4#X,S,M2
	db $3f,$63,$3f,$02
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,D5X,S,M1
	db $3f,$67,$3f,$01
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,G5X,S,M2
	db $3f,$6c,$3f,$02
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,D5X,S,M1
	db $3f,$67,$3f,$01
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,G5X,S,M2
	db $3f,$6c,$3f,$02
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,M1
	db $3f,$3f,$3f,$01
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,D5X,S,M1
	db $3f,$67,$3f,$01
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC D4#Y,A4#X,S,M2
	db $9c,$63,$3f,$02
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC D4#Y,F4X,F2W,M1
	db $9c,$5e,$06,$01
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,A4X,S,M2
	db $3f,$62,$3f,$02
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,C5X,S,M1
	db $3f,$65,$3f,$01
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,F5X,S,M2
	db $3f,$6a,$3f,$02
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,C5X,G2W,M1
	db $3f,$65,$08,$01
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,A4X,S,M2
	db $3f,$62,$3f,$02
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,M1
	db $3f,$3f,$3f,$01
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC C4Y,F4X,S,M1
	db $99,$5e,$3f,$01
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,A4X,S,M2
	db $3f,$62,$3f,$02
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC C4Y,F4X,G2W,M1
	db $99,$5e,$08,$01
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,A4X,S,M2
	db $3f,$62,$3f,$02
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,C5X,S,M1
	db $3f,$65,$3f,$01
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC D4Y,A4X,S,M2
	db $9b,$62,$3f,$02
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,G4X,S,M1
	db $3f,$60,$3f,$01
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,A4#X,S,M2
	db $3f,$63,$3f,$02
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,M1
	db $3f,$3f,$3f,$01
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC D4Y,D5X,S,M1
	db $9b,$67,$3f,$01
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,G5X,S,M1
	db $3f,$6c,$3f,$01
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC REPEAT
	db $fd,$00,$00,$00
	; 
	; mus_title:
cvb_MUS_TITLE:
	; 	DATA BYTE 2
	DB $02
	; 	MUSIC D4#Y,B4W,G2#W,M1
	db $9c,$24,$09,$01
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,G4#W,S,-
	db $3f,$21,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,B4W,S,M1
	db $3f,$24,$3f,$01
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,D5#W,S,-
	db $3f,$28,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC D4#Y,B4W,G2#W,M1
	db $9c,$24,$09,$01
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,G4#W,S,-
	db $3f,$21,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC D4#Y,D5#W,S,M1
	db $9c,$28,$3f,$01
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,B2W,-
	db $3f,$3f,$0c,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC G4#Y,B4W,S,-
	db $a1,$24,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,C3W,-
	db $3f,$3f,$0d,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC G4#Y,B4W,G2#W,M1
	db $a1,$24,$09,$01
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,G4#W,S,-
	db $3f,$21,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,B4W,S,M1
	db $3f,$24,$3f,$01
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC F4#Y,D5#W,S,M1
	db $9f,$28,$3f,$01
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC F4#Y,G4#W,G2#W,M1
	db $9f,$21,$09,$01
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,E4W,S,-
	db $3f,$1d,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,C4#W,C3#W,M1
	db $3f,$1a,$0e,$01
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,E4W,S,M1
	db $3f,$1d,$3f,$01
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC G4Y,G4W,G2W,M1
	db $a0,$20,$08,$01
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,M2
	db $3f,$3f,$3f,$02
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,B4W,S,M1
	db $3f,$24,$3f,$01
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,M2
	db $3f,$3f,$3f,$02
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,D5W,S,M1
	db $3f,$27,$3f,$01
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,M2
	db $3f,$3f,$3f,$02
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,G5W,S,M1
	db $3f,$2c,$3f,$01
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,M2
	db $3f,$3f,$3f,$02
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC G4Y,G4W,G2W,M1
	db $a0,$20,$08,$01
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,M2
	db $3f,$3f,$3f,$02
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,B4W,S,M1
	db $3f,$24,$3f,$01
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,M2
	db $3f,$3f,$3f,$02
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC D4Y,D5W,S,M1
	db $9b,$27,$3f,$01
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,M2
	db $3f,$3f,$3f,$02
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,B4W,S,M1
	db $3f,$24,$3f,$01
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,M2
	db $3f,$3f,$3f,$02
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC B3Y,G4W,G2W,M1
	db $98,$20,$08,$01
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,M2
	db $3f,$3f,$3f,$02
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC C4Y,B4W,S,M1
	db $99,$24,$3f,$01
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,M2
	db $3f,$3f,$3f,$02
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC D4#Y,D5W,S,M1
	db $9c,$27,$3f,$01
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,F2#W,M2
	db $3f,$3f,$07,$02
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,G5W,S,M1
	db $3f,$2c,$3f,$01
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,M2
	db $3f,$3f,$3f,$02
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC D4#Y,D5#W,G2W,M1
	db $9c,$28,$08,$01
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,M2
	db $3f,$3f,$3f,$02
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,C5#W,S,M1
	db $3f,$26,$3f,$01
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,M2
	db $3f,$3f,$3f,$02
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,B4W,G2#W,M1
	db $3f,$24,$09,$01
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC C4#Y,S,S,M2
	db $9a,$3f,$3f,$02
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,G4#W,S,M1
	db $3f,$21,$3f,$01
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,M2
	db $3f,$3f,$3f,$02
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC S,S,S,-
	db $3f,$3f,$3f,$00
	; 	MUSIC REPEAT
	db $fd,$00,$00,$00
	; 
	; 	' ==== gerado por gera_lava.py (v0.19): CHRROM 2 = fase 2 (lava) ====
	; 	CHRROM 2
	; 
	; 	' FONTE DO SAULO (32-95): copia byte-exata do ROM atual
	; 	CHRROM PATTERN 32
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00033300"
	; 	BITMAP "00033300"
	; 	BITMAP "00033300"
	; 	BITMAP "00033000"
	; 	BITMAP "00033000"
	; 	BITMAP "00000000"
	; 	BITMAP "00033000"
	; 	BITMAP "00033000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "33333333"
	; 	BITMAP "33333333"
	; 	BITMAP "33333333"
	; 	BITMAP "33333333"
	; 	BITMAP "33333333"
	; 	BITMAP "33333333"
	; 	BITMAP "33333333"
	; 	BITMAP "33333333"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00003000"
	; 	BITMAP "00030000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00300300"
	; 	BITMAP "00033000"
	; 	BITMAP "00033000"
	; 	BITMAP "00300300"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00033000"
	; 	BITMAP "00033000"
	; 	BITMAP "00003000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00333000"
	; 	BITMAP "03003300"
	; 	BITMAP "33000330"
	; 	BITMAP "33000330"
	; 	BITMAP "33000330"
	; 	BITMAP "03300300"
	; 	BITMAP "00333000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00033000"
	; 	BITMAP "00033000"
	; 	BITMAP "00033000"
	; 	BITMAP "00033000"
	; 	BITMAP "00033000"
	; 	BITMAP "00033000"
	; 	BITMAP "03333330"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "03333300"
	; 	BITMAP "33000330"
	; 	BITMAP "00003330"
	; 	BITMAP "00333300"
	; 	BITMAP "03333000"
	; 	BITMAP "33300000"
	; 	BITMAP "33333330"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "03333330"
	; 	BITMAP "00003300"
	; 	BITMAP "00033000"
	; 	BITMAP "00333300"
	; 	BITMAP "00000330"
	; 	BITMAP "33000330"
	; 	BITMAP "03333300"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00033300"
	; 	BITMAP "00333300"
	; 	BITMAP "03303300"
	; 	BITMAP "33003300"
	; 	BITMAP "33333330"
	; 	BITMAP "00003300"
	; 	BITMAP "00003300"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "33333300"
	; 	BITMAP "33000000"
	; 	BITMAP "33333300"
	; 	BITMAP "00000330"
	; 	BITMAP "00000330"
	; 	BITMAP "33000330"
	; 	BITMAP "03333300"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00333300"
	; 	BITMAP "03300000"
	; 	BITMAP "33000000"
	; 	BITMAP "33333300"
	; 	BITMAP "33000330"
	; 	BITMAP "33000330"
	; 	BITMAP "03333300"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "33333330"
	; 	BITMAP "33000330"
	; 	BITMAP "00003300"
	; 	BITMAP "00033000"
	; 	BITMAP "00330000"
	; 	BITMAP "00330000"
	; 	BITMAP "00330000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "03333300"
	; 	BITMAP "33000330"
	; 	BITMAP "33000330"
	; 	BITMAP "03333300"
	; 	BITMAP "33000330"
	; 	BITMAP "33000330"
	; 	BITMAP "03333300"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "03333300"
	; 	BITMAP "33000330"
	; 	BITMAP "33000330"
	; 	BITMAP "03333330"
	; 	BITMAP "00000330"
	; 	BITMAP "00003300"
	; 	BITMAP "03333000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00033000"
	; 	BITMAP "00033000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00033000"
	; 	BITMAP "00033000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00030000"
	; 	BITMAP "00330000"
	; 	BITMAP "03330000"
	; 	BITMAP "33333333"
	; 	BITMAP "33333333"
	; 	BITMAP "03330000"
	; 	BITMAP "00330000"
	; 	BITMAP "00030000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00333300"
	; 	BITMAP "03300330"
	; 	BITMAP "03300330"
	; 	BITMAP "00000330"
	; 	BITMAP "00033000"
	; 	BITMAP "00000000"
	; 	BITMAP "00033000"
	; 	BITMAP "00033000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00333000"
	; 	BITMAP "03303300"
	; 	BITMAP "33000330"
	; 	BITMAP "33000330"
	; 	BITMAP "33333330"
	; 	BITMAP "33000330"
	; 	BITMAP "33000330"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "33333300"
	; 	BITMAP "33000330"
	; 	BITMAP "33000330"
	; 	BITMAP "33333300"
	; 	BITMAP "33000330"
	; 	BITMAP "33000330"
	; 	BITMAP "33333300"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00333300"
	; 	BITMAP "03300330"
	; 	BITMAP "33000000"
	; 	BITMAP "33000000"
	; 	BITMAP "33000000"
	; 	BITMAP "03300330"
	; 	BITMAP "00333300"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "33333000"
	; 	BITMAP "33003300"
	; 	BITMAP "33000330"
	; 	BITMAP "33000330"
	; 	BITMAP "33000330"
	; 	BITMAP "33003300"
	; 	BITMAP "33333000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "33333330"
	; 	BITMAP "33000000"
	; 	BITMAP "33000000"
	; 	BITMAP "33333300"
	; 	BITMAP "33000000"
	; 	BITMAP "33000000"
	; 	BITMAP "33333330"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "33333330"
	; 	BITMAP "33000000"
	; 	BITMAP "33000000"
	; 	BITMAP "33333300"
	; 	BITMAP "33000000"
	; 	BITMAP "33000000"
	; 	BITMAP "33000000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00333330"
	; 	BITMAP "03300000"
	; 	BITMAP "33000000"
	; 	BITMAP "33003330"
	; 	BITMAP "33000330"
	; 	BITMAP "03300330"
	; 	BITMAP "00333330"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "33000330"
	; 	BITMAP "33000330"
	; 	BITMAP "33000330"
	; 	BITMAP "33333330"
	; 	BITMAP "33000330"
	; 	BITMAP "33000330"
	; 	BITMAP "33000330"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "03333330"
	; 	BITMAP "00033000"
	; 	BITMAP "00033000"
	; 	BITMAP "00033000"
	; 	BITMAP "00033000"
	; 	BITMAP "00033000"
	; 	BITMAP "03333330"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00033330"
	; 	BITMAP "00000330"
	; 	BITMAP "00000330"
	; 	BITMAP "00000330"
	; 	BITMAP "33000330"
	; 	BITMAP "33000330"
	; 	BITMAP "03333300"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "33000330"
	; 	BITMAP "33003300"
	; 	BITMAP "33033000"
	; 	BITMAP "33330000"
	; 	BITMAP "33333000"
	; 	BITMAP "33033300"
	; 	BITMAP "33003330"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "03300000"
	; 	BITMAP "03300000"
	; 	BITMAP "03300000"
	; 	BITMAP "03300000"
	; 	BITMAP "03300000"
	; 	BITMAP "03300000"
	; 	BITMAP "03333330"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "33000330"
	; 	BITMAP "33303330"
	; 	BITMAP "33333330"
	; 	BITMAP "33333330"
	; 	BITMAP "33030330"
	; 	BITMAP "33000330"
	; 	BITMAP "33000330"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "33000330"
	; 	BITMAP "33300330"
	; 	BITMAP "33330330"
	; 	BITMAP "33333330"
	; 	BITMAP "33033330"
	; 	BITMAP "33003330"
	; 	BITMAP "33000330"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "03333300"
	; 	BITMAP "33000330"
	; 	BITMAP "33000330"
	; 	BITMAP "33000330"
	; 	BITMAP "33000330"
	; 	BITMAP "33000330"
	; 	BITMAP "03333300"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "33333300"
	; 	BITMAP "33000330"
	; 	BITMAP "33000330"
	; 	BITMAP "33000330"
	; 	BITMAP "33333300"
	; 	BITMAP "33000000"
	; 	BITMAP "33000000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "03333300"
	; 	BITMAP "33000330"
	; 	BITMAP "33000330"
	; 	BITMAP "33000330"
	; 	BITMAP "33033330"
	; 	BITMAP "33003300"
	; 	BITMAP "03333030"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "33333300"
	; 	BITMAP "33000330"
	; 	BITMAP "33000330"
	; 	BITMAP "33003330"
	; 	BITMAP "33333000"
	; 	BITMAP "33033300"
	; 	BITMAP "33003330"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "03333000"
	; 	BITMAP "33003300"
	; 	BITMAP "33000000"
	; 	BITMAP "03333300"
	; 	BITMAP "00000330"
	; 	BITMAP "33000330"
	; 	BITMAP "03333300"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "03333330"
	; 	BITMAP "00033000"
	; 	BITMAP "00033000"
	; 	BITMAP "00033000"
	; 	BITMAP "00033000"
	; 	BITMAP "00033000"
	; 	BITMAP "00033000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "33000330"
	; 	BITMAP "33000330"
	; 	BITMAP "33000330"
	; 	BITMAP "33000330"
	; 	BITMAP "33000330"
	; 	BITMAP "33000330"
	; 	BITMAP "03333300"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "33000330"
	; 	BITMAP "33000330"
	; 	BITMAP "33000330"
	; 	BITMAP "33303330"
	; 	BITMAP "03333300"
	; 	BITMAP "00333000"
	; 	BITMAP "00030000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "33000330"
	; 	BITMAP "33000330"
	; 	BITMAP "33030330"
	; 	BITMAP "33333330"
	; 	BITMAP "33333330"
	; 	BITMAP "33303330"
	; 	BITMAP "33000330"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "33000330"
	; 	BITMAP "33303330"
	; 	BITMAP "03333300"
	; 	BITMAP "00333000"
	; 	BITMAP "03333300"
	; 	BITMAP "33303330"
	; 	BITMAP "33000330"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "03300330"
	; 	BITMAP "03300330"
	; 	BITMAP "03300330"
	; 	BITMAP "00333300"
	; 	BITMAP "00033000"
	; 	BITMAP "00033000"
	; 	BITMAP "00033000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "33333330"
	; 	BITMAP "00003330"
	; 	BITMAP "00033300"
	; 	BITMAP "00333000"
	; 	BITMAP "03330000"
	; 	BITMAP "33300000"
	; 	BITMAP "33333330"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "03330000"
	; 	BITMAP "00030000"
	; 	BITMAP "00030000"
	; 	BITMAP "00030000"
	; 	BITMAP "00030000"
	; 	BITMAP "03330000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00033000"
	; 	BITMAP "00333300"
	; 	BITMAP "03333330"
	; 	BITMAP "33333333"
	; 	BITMAP "00033000"
	; 	BITMAP "00033000"
	; 	BITMAP "00033000"
	; 	BITMAP "00033000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 
	; 
	; 	' tiles da lava (dedup): metatiles 16x16 -> 4 subtiles 8x8
	; 	CHRROM PATTERN 96
	; 
	; 	BITMAP "01000000"
	; 	BITMAP "10000011"
	; 	BITMAP "01000100"
	; 	BITMAP "00111000"
	; 	BITMAP "01000100"
	; 	BITMAP "10000011"
	; 	BITMAP "00000100"
	; 	BITMAP "00111000"
	; 
	; 	BITMAP "10010000"
	; 	BITMAP "10010111"
	; 	BITMAP "01011000"
	; 	BITMAP "00100100"
	; 	BITMAP "00100100"
	; 	BITMAP "11000011"
	; 	BITMAP "00100010"
	; 	BITMAP "00010010"
	; 
	; 	BITMAP "11001000"
	; 	BITMAP "00001111"
	; 	BITMAP "00001000"
	; 	BITMAP "00000100"
	; 	BITMAP "11001011"
	; 	BITMAP "00110001"
	; 	BITMAP "00100000"
	; 	BITMAP "01000000"
	; 
	; 	BITMAP "00010011"
	; 	BITMAP "00011100"
	; 	BITMAP "11010000"
	; 	BITMAP "00101000"
	; 	BITMAP "11000111"
	; 	BITMAP "00001000"
	; 	BITMAP "10010000"
	; 	BITMAP "10010000"
	; 
	; 	BITMAP "00111111"
	; 	BITMAP "01222222"
	; 	BITMAP "12333131"
	; 	BITMAP "12332222"
	; 	BITMAP "12323333"
	; 	BITMAP "12123322"
	; 	BITMAP "12023230"
	; 	BITMAP "12323201"
	; 
	; 	BITMAP "11111100"
	; 	BITMAP "22222210"
	; 	BITMAP "31313321"
	; 	BITMAP "22223321"
	; 	BITMAP "33332321"
	; 	BITMAP "22332121"
	; 	BITMAP "03232021"
	; 	BITMAP "10232321"
	; 
	; 	BITMAP "12323201"
	; 	BITMAP "12123230"
	; 	BITMAP "12023322"
	; 	BITMAP "12323333"
	; 	BITMAP "12332222"
	; 	BITMAP "12333131"
	; 	BITMAP "01222222"
	; 	BITMAP "00111111"
	; 
	; 	BITMAP "10232321"
	; 	BITMAP "03232121"
	; 	BITMAP "22332021"
	; 	BITMAP "33332321"
	; 	BITMAP "22223321"
	; 	BITMAP "31313321"
	; 	BITMAP "22222210"
	; 	BITMAP "11111100"
	; 
	; 	BITMAP "00111111"
	; 	BITMAP "01221012"
	; 	BITMAP "12333011"
	; 	BITMAP "12302120"
	; 	BITMAP "12301100"
	; 	BITMAP "12120012"
	; 	BITMAP "12001211"
	; 	BITMAP "12301101"
	; 
	; 	BITMAP "11111100"
	; 	BITMAP "22222210"
	; 	BITMAP "30313321"
	; 	BITMAP "10223321"
	; 	BITMAP "30032321"
	; 	BITMAP "11102121"
	; 	BITMAP "01210021"
	; 	BITMAP "11010321"
	; 
	; 	BITMAP "12320111"
	; 	BITMAP "12120010"
	; 	BITMAP "12020112"
	; 	BITMAP "12320111"
	; 	BITMAP "12311002"
	; 	BITMAP "12301031"
	; 	BITMAP "01222211"
	; 	BITMAP "00111111"
	; 
	; 	BITMAP "10211121"
	; 	BITMAP "11230111"
	; 	BITMAP "02310011"
	; 	BITMAP "13102321"
	; 	BITMAP "11023321"
	; 	BITMAP "10313321"
	; 	BITMAP "22222210"
	; 	BITMAP "11111100"
	; 
	; 	BITMAP "01000000"
	; 	BITMAP "10000011"
	; 	BITMAP "01000132"
	; 	BITMAP "00111222"
	; 	BITMAP "01002323"
	; 	BITMAP "10000011"
	; 	BITMAP "00000100"
	; 	BITMAP "00111000"
	; 
	; 	BITMAP "10010000"
	; 	BITMAP "10010111"
	; 	BITMAP "31011000"
	; 	BITMAP "33100100"
	; 	BITMAP "33300100"
	; 	BITMAP "11000011"
	; 	BITMAP "00100010"
	; 	BITMAP "00010010"
	; 
	; 	BITMAP "11001003"
	; 	BITMAP "00001223"
	; 	BITMAP "00003232"
	; 	BITMAP "00022233"
	; 	BITMAP "11232333"
	; 	BITMAP "00110001"
	; 	BITMAP "00100000"
	; 	BITMAP "01000000"
	; 
	; 	BITMAP "30010011"
	; 	BITMAP "33011100"
	; 	BITMAP "33310000"
	; 	BITMAP "32301000"
	; 	BITMAP "33330111"
	; 	BITMAP "00001000"
	; 	BITMAP "10010000"
	; 	BITMAP "10010000"
	; 
	; 	BITMAP "01000000"
	; 	BITMAP "10000011"
	; 	BITMAP "01000100"
	; 	BITMAP "00111000"
	; 	BITMAP "01000103"
	; 	BITMAP "10000033"
	; 	BITMAP "00000133"
	; 	BITMAP "00111032"
	; 
	; 	BITMAP "10010000"
	; 	BITMAP "10010111"
	; 	BITMAP "01011000"
	; 	BITMAP "00100100"
	; 	BITMAP "30100100"
	; 	BITMAP "23300011"
	; 	BITMAP "33330010"
	; 	BITMAP "33233010"
	; 
	; 	BITMAP "11001332"
	; 	BITMAP "00001311"
	; 	BITMAP "00003323"
	; 	BITMAP "00033122"
	; 	BITMAP "11031211"
	; 	BITMAP "00332221"
	; 	BITMAP "00322323"
	; 	BITMAP "03322233"
	; 
	; 	BITMAP "23313311"
	; 	BITMAP "23311133"
	; 	BITMAP "11313323"
	; 	BITMAP "32131332"
	; 	BITMAP "11332311"
	; 	BITMAP "33333222"
	; 	BITMAP "13232232"
	; 	BITMAP "13332222"
	; 
	; 	BITMAP "01000000"
	; 	BITMAP "10000011"
	; 	BITMAP "01000100"
	; 	BITMAP "00113300"
	; 	BITMAP "01033330"
	; 	BITMAP "10033233"
	; 	BITMAP "00323123"
	; 	BITMAP "03311333"
	; 
	; 	BITMAP "33221332"
	; 	BITMAP "32221113"
	; 	BITMAP "22231333"
	; 	BITMAP "23222123"
	; 	BITMAP "11221311"
	; 	BITMAP "23113331"
	; 	BITMAP "22133233"
	; 	BITMAP "21333333"
	; 
	; 	BITMAP "00010011"
	; 	BITMAP "30011100"
	; 	BITMAP "21010000"
	; 	BITMAP "30101000"
	; 	BITMAP "31000111"
	; 	BITMAP "30001000"
	; 	BITMAP "33010000"
	; 	BITMAP "13010000"
	; 
	; 	BITMAP "01000000"
	; 	BITMAP "10000011"
	; 	BITMAP "01000100"
	; 	BITMAP "00111000"
	; 	BITMAP "01000100"
	; 	BITMAP "10000011"
	; 	BITMAP "00000100"
	; 	BITMAP "00111002"
	; 
	; 	BITMAP "10010000"
	; 	BITMAP "10010111"
	; 	BITMAP "01011000"
	; 	BITMAP "00100100"
	; 	BITMAP "00100100"
	; 	BITMAP "11000011"
	; 	BITMAP "32220010"
	; 	BITMAP "23233010"
	; 
	; 	BITMAP "11001032"
	; 	BITMAP "00001221"
	; 	BITMAP "00002322"
	; 	BITMAP "00022132"
	; 	BITMAP "11021211"
	; 	BITMAP "00232223"
	; 	BITMAP "01111111"
	; 	BITMAP "01000000"
	; 
	; 	BITMAP "22212311"
	; 	BITMAP "22311330"
	; 	BITMAP "11313323"
	; 	BITMAP "23131333"
	; 	BITMAP "11233113"
	; 	BITMAP "23332332"
	; 	BITMAP "11111123"
	; 	BITMAP "10010322"
	; 
	; 	BITMAP "01000000"
	; 	BITMAP "10000011"
	; 	BITMAP "01000100"
	; 	BITMAP "00111000"
	; 	BITMAP "01000100"
	; 	BITMAP "10000011"
	; 	BITMAP "00000100"
	; 	BITMAP "00122230"
	; 
	; 	BITMAP "11221223"
	; 	BITMAP "00221113"
	; 	BITMAP "02321332"
	; 	BITMAP "22222133"
	; 	BITMAP "21221211"
	; 	BITMAP "22112331"
	; 	BITMAP "22123233"
	; 	BITMAP "21233332"
	; 
	; 	BITMAP "00010011"
	; 	BITMAP "30011100"
	; 	BITMAP "33010022"
	; 	BITMAP "32301223"
	; 	BITMAP "11332211"
	; 	BITMAP "33323222"
	; 	BITMAP "13222223"
	; 	BITMAP "13212233"
	; 
	; 	BITMAP "11001000"
	; 	BITMAP "00001111"
	; 	BITMAP "00001000"
	; 	BITMAP "23300100"
	; 	BITMAP "11331011"
	; 	BITMAP "33133001"
	; 	BITMAP "33133000"
	; 	BITMAP "31323000"
	; 
	; 	BITMAP "10010000"
	; 	BITMAP "10010113"
	; 	BITMAP "01011003"
	; 	BITMAP "00100133"
	; 	BITMAP "00100132"
	; 	BITMAP "11000331"
	; 	BITMAP "00103312"
	; 	BITMAP "00033212"
	; 
	; 	BITMAP "11001000"
	; 	BITMAP "00001133"
	; 	BITMAP "00001333"
	; 	BITMAP "00000100"
	; 	BITMAP "11001011"
	; 	BITMAP "00110001"
	; 	BITMAP "00100000"
	; 	BITMAP "01000000"
	; 
	; 	BITMAP "03312311"
	; 	BITMAP "33211122"
	; 	BITMAP "33333333"
	; 	BITMAP "00333323"
	; 	BITMAP "11003333"
	; 	BITMAP "00001000"
	; 	BITMAP "10010000"
	; 	BITMAP "10010000"
	; 
	; 	BITMAP "33232333"
	; 	BITMAP "32223311"
	; 	BITMAP "21233123"
	; 	BITMAP "22111333"
	; 	BITMAP "21233122"
	; 	BITMAP "12322211"
	; 	BITMAP "32222123"
	; 	BITMAP "22111232"
	; 
	; 	BITMAP "13332322"
	; 	BITMAP "33312111"
	; 	BITMAP "33211222"
	; 	BITMAP "32122132"
	; 	BITMAP "22122122"
	; 	BITMAP "11232211"
	; 	BITMAP "22122212"
	; 	BITMAP "22212313"
	; 
	; 	BITMAP "11221222"
	; 	BITMAP "22321111"
	; 	BITMAP "33333332"
	; 	BITMAP "33330103"
	; 	BITMAP "11001011"
	; 	BITMAP "00110001"
	; 	BITMAP "00100000"
	; 	BITMAP "01000000"
	; 
	; 	BITMAP "23212211"
	; 	BITMAP "22211133"
	; 	BITMAP "31213323"
	; 	BITMAP "33131333"
	; 	BITMAP "13333111"
	; 	BITMAP "00331333"
	; 	BITMAP "10033332"
	; 	BITMAP "10010033"
	; 
	; 	BITMAP "21333333"
	; 	BITMAP "13323311"
	; 	BITMAP "21333133"
	; 	BITMAP "22111332"
	; 	BITMAP "31333133"
	; 	BITMAP "13233311"
	; 	BITMAP "33332123"
	; 	BITMAP "33111333"
	; 
	; 	BITMAP "13310000"
	; 	BITMAP "12333111"
	; 	BITMAP "33333300"
	; 	BITMAP "32323300"
	; 	BITMAP "33333300"
	; 	BITMAP "13332331"
	; 	BITMAP "33233330"
	; 	BITMAP "33333330"
	; 
	; 	BITMAP "11321332"
	; 	BITMAP "33331111"
	; 	BITMAP "33231323"
	; 	BITMAP "23333133"
	; 	BITMAP "11331311"
	; 	BITMAP "33113331"
	; 	BITMAP "33132333"
	; 	BITMAP "33333300"
	; 
	; 	BITMAP "33230011"
	; 	BITMAP "33331100"
	; 	BITMAP "11330000"
	; 	BITMAP "33133000"
	; 	BITMAP "11332311"
	; 	BITMAP "33333300"
	; 	BITMAP "33010000"
	; 	BITMAP "10010000"
	; 
	; 	BITMAP "10012222"
	; 	BITMAP "10013111"
	; 	BITMAP "01022322"
	; 	BITMAP "00232222"
	; 	BITMAP "11111111"
	; 	BITMAP "11000011"
	; 	BITMAP "00100010"
	; 	BITMAP "00010010"
	; 
	; 	BITMAP "11001000"
	; 	BITMAP "00001111"
	; 	BITMAP "00001000"
	; 	BITMAP "00000102"
	; 	BITMAP "11001022"
	; 	BITMAP "00110223"
	; 	BITMAP "00101111"
	; 	BITMAP "01000000"
	; 
	; 	BITMAP "00010012"
	; 	BITMAP "00022222"
	; 	BITMAP "12223232"
	; 	BITMAP "32121222"
	; 	BITMAP "11232111"
	; 	BITMAP "22222222"
	; 	BITMAP "11111112"
	; 	BITMAP "10010011"
	; 
	; 	BITMAP "31232333"
	; 	BITMAP "12233312"
	; 	BITMAP "21223132"
	; 	BITMAP "32223332"
	; 	BITMAP "11111122"
	; 	BITMAP "10000232"
	; 	BITMAP "00222122"
	; 	BITMAP "02211222"
	; 
	; 	BITMAP "22213333"
	; 	BITMAP "32213111"
	; 	BITMAP "21211333"
	; 	BITMAP "32132133"
	; 	BITMAP "22133133"
	; 	BITMAP "11333311"
	; 	BITMAP "22123313"
	; 	BITMAP "23313313"
	; 
	; 	BITMAP "32221323"
	; 	BITMAP "22321111"
	; 	BITMAP "32221222"
	; 	BITMAP "23232133"
	; 	BITMAP "11221311"
	; 	BITMAP "32113333"
	; 	BITMAP "23333333"
	; 	BITMAP "11111111"
	; 
	; 	BITMAP "33313211"
	; 	BITMAP "32311133"
	; 	BITMAP "11313332"
	; 	BITMAP "33131333"
	; 	BITMAP "11333233"
	; 	BITMAP "33311111"
	; 	BITMAP "11110000"
	; 	BITMAP "10010000"
	; 
	; 	BITMAP "31333000"
	; 	BITMAP "13233311"
	; 	BITMAP "21333200"
	; 	BITMAP "33111300"
	; 	BITMAP "31323330"
	; 	BITMAP "13333333"
	; 	BITMAP "32333133"
	; 	BITMAP "33111332"
	; 
	; 	BITMAP "10010000"
	; 	BITMAP "10010111"
	; 	BITMAP "01011000"
	; 	BITMAP "00100100"
	; 	BITMAP "00100100"
	; 	BITMAP "11000011"
	; 	BITMAP "30100010"
	; 	BITMAP "33010010"
	; 
	; 	BITMAP "11331333"
	; 	BITMAP "33331111"
	; 	BITMAP "33231333"
	; 	BITMAP "33333133"
	; 	BITMAP "31331011"
	; 	BITMAP "33110333"
	; 	BITMAP "13333111"
	; 	BITMAP "11111000"
	; 
	; 	BITMAP "32010011"
	; 	BITMAP "33311100"
	; 	BITMAP "11330000"
	; 	BITMAP "33131000"
	; 	BITMAP "11331111"
	; 	BITMAP "33311000"
	; 	BITMAP "11110000"
	; 	BITMAP "10010000"
	; 
	; 	BITMAP "01000000"
	; 	BITMAP "10000011"
	; 	BITMAP "01000100"
	; 	BITMAP "00111000"
	; 	BITMAP "01000003"
	; 	BITMAP "10000322"
	; 	BITMAP "00001223"
	; 	BITMAP "00023122"
	; 
	; 	BITMAP "10010000"
	; 	BITMAP "00330011"
	; 	BITMAP "03323000"
	; 	BITMAP "33233000"
	; 	BITMAP "13333300"
	; 	BITMAP "21332310"
	; 	BITMAP "21333331"
	; 	BITMAP "23131110"
	; 
	; 	BITMAP "10322123"
	; 	BITMAP "00221322"
	; 	BITMAP "03231221"
	; 	BITMAP "33333333"
	; 	BITMAP "11111111"
	; 	BITMAP "00000000"
	; 	BITMAP "00100000"
	; 	BITMAP "01000000"
	; 
	; 	BITMAP "21331000"
	; 	BITMAP "12333100"
	; 	BITMAP "33233100"
	; 	BITMAP "33333310"
	; 	BITMAP "11111100"
	; 	BITMAP "00000000"
	; 	BITMAP "10010000"
	; 	BITMAP "10010000"
	; 
	; 	BITMAP "10010000"
	; 	BITMAP "10010111"
	; 	BITMAP "01011000"
	; 	BITMAP "00100100"
	; 	BITMAP "00100100"
	; 	BITMAP "12300011"
	; 	BITMAP "22330010"
	; 	BITMAP "23230010"
	; 
	; 	BITMAP "11001122"
	; 	BITMAP "00001111"
	; 	BITMAP "00001000"
	; 	BITMAP "00000100"
	; 	BITMAP "11001011"
	; 	BITMAP "00110001"
	; 	BITMAP "00100000"
	; 	BITMAP "01000000"
	; 
	; 	BITMAP "33333111"
	; 	BITMAP "11111100"
	; 	BITMAP "11010000"
	; 	BITMAP "00101000"
	; 	BITMAP "11000111"
	; 	BITMAP "00001000"
	; 	BITMAP "10010000"
	; 	BITMAP "10010000"
	; 
	; 	BITMAP "11001000"
	; 	BITMAP "00001111"
	; 	BITMAP "00023000"
	; 	BITMAP "00223300"
	; 	BITMAP "12233331"
	; 	BITMAP "01333111"
	; 	BITMAP "00111000"
	; 	BITMAP "01000000"
	; 
	; 
	; 	' pares 8x16 dos digitos do placar (copia)
	; 	CHRROM PATTERN 192
	; 
	; 	BITMAP "00333000"
	; 	BITMAP "03003300"
	; 	BITMAP "33000330"
	; 	BITMAP "33000330"
	; 	BITMAP "33000330"
	; 	BITMAP "03300300"
	; 	BITMAP "00333000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00033000"
	; 	BITMAP "00033000"
	; 	BITMAP "00033000"
	; 	BITMAP "00033000"
	; 	BITMAP "00033000"
	; 	BITMAP "00033000"
	; 	BITMAP "03333330"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "03333300"
	; 	BITMAP "33000330"
	; 	BITMAP "00003330"
	; 	BITMAP "00333300"
	; 	BITMAP "03333000"
	; 	BITMAP "33300000"
	; 	BITMAP "33333330"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "03333330"
	; 	BITMAP "00003300"
	; 	BITMAP "00033000"
	; 	BITMAP "00333300"
	; 	BITMAP "00000330"
	; 	BITMAP "33000330"
	; 	BITMAP "03333300"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00033300"
	; 	BITMAP "00333300"
	; 	BITMAP "03303300"
	; 	BITMAP "33003300"
	; 	BITMAP "33333330"
	; 	BITMAP "00003300"
	; 	BITMAP "00003300"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "33333300"
	; 	BITMAP "33000000"
	; 	BITMAP "33333300"
	; 	BITMAP "00000330"
	; 	BITMAP "00000330"
	; 	BITMAP "33000330"
	; 	BITMAP "03333300"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00333300"
	; 	BITMAP "03300000"
	; 	BITMAP "33000000"
	; 	BITMAP "33333300"
	; 	BITMAP "33000330"
	; 	BITMAP "33000330"
	; 	BITMAP "03333300"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "33333330"
	; 	BITMAP "33000330"
	; 	BITMAP "00003300"
	; 	BITMAP "00033000"
	; 	BITMAP "00330000"
	; 	BITMAP "00330000"
	; 	BITMAP "00330000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "03333300"
	; 	BITMAP "33000330"
	; 	BITMAP "33000330"
	; 	BITMAP "03333300"
	; 	BITMAP "33000330"
	; 	BITMAP "33000330"
	; 	BITMAP "03333300"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "03333300"
	; 	BITMAP "33000330"
	; 	BITMAP "33000330"
	; 	BITMAP "03333330"
	; 	BITMAP "00000330"
	; 	BITMAP "00003300"
	; 	BITMAP "03333000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 
	; 
	; 	' GAMEOVER estilizado (copia)
	; 	CHRROM PATTERN 214
	; 
	; 	BITMAP "03333333"
	; 	BITMAP "33333333"
	; 	BITMAP "33000003"
	; 	BITMAP "33003333"
	; 	BITMAP "33003003"
	; 	BITMAP "33003303"
	; 	BITMAP "33000003"
	; 	BITMAP "03333333"
	; 
	; 	BITMAP "33333333"
	; 	BITMAP "33333333"
	; 	BITMAP "30000003"
	; 	BITMAP "30033303"
	; 	BITMAP "30000003"
	; 	BITMAP "30033303"
	; 	BITMAP "30033303"
	; 	BITMAP "33333333"
	; 
	; 	BITMAP "33333333"
	; 	BITMAP "33333333"
	; 	BITMAP "30033303"
	; 	BITMAP "30003003"
	; 	BITMAP "30030303"
	; 	BITMAP "30033303"
	; 	BITMAP "30033303"
	; 	BITMAP "33333333"
	; 
	; 	BITMAP "33333333"
	; 	BITMAP "33333333"
	; 	BITMAP "30000033"
	; 	BITMAP "30033333"
	; 	BITMAP "30000033"
	; 	BITMAP "30033333"
	; 	BITMAP "30000033"
	; 	BITMAP "33333333"
	; 
	; 	BITMAP "33333333"
	; 	BITMAP "33333333"
	; 	BITMAP "30000003"
	; 	BITMAP "30033303"
	; 	BITMAP "30033303"
	; 	BITMAP "30033303"
	; 	BITMAP "30000003"
	; 	BITMAP "33333333"
	; 
	; 	BITMAP "33333333"
	; 	BITMAP "33333333"
	; 	BITMAP "30033303"
	; 	BITMAP "30033303"
	; 	BITMAP "30033033"
	; 	BITMAP "33003033"
	; 	BITMAP "33000333"
	; 	BITMAP "33333333"
	; 
	; 	BITMAP "33333333"
	; 	BITMAP "33333333"
	; 	BITMAP "30000003"
	; 	BITMAP "30033333"
	; 	BITMAP "30000003"
	; 	BITMAP "30033333"
	; 	BITMAP "30000003"
	; 	BITMAP "33333333"
	; 
	; 	BITMAP "33333330"
	; 	BITMAP "33333333"
	; 	BITMAP "30000033"
	; 	BITMAP "30033303"
	; 	BITMAP "30000033"
	; 	BITMAP "30030333"
	; 	BITMAP "30033033"
	; 	BITMAP "33333330"
	; 
	; 
	; 	' mini-labels BONUS/1UP (copia)
	; 	CHRROM PATTERN 224
	; 
	; 	BITMAP "00000030"
	; 	BITMAP "03300303"
	; 	BITMAP "03030000"
	; 	BITMAP "03030030"
	; 	BITMAP "03300303"
	; 	BITMAP "03030303"
	; 	BITMAP "03030303"
	; 	BITMAP "03300030"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "03000303"
	; 	BITMAP "03300303"
	; 	BITMAP "03030303"
	; 	BITMAP "03030303"
	; 	BITMAP "03030030"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000330"
	; 	BITMAP "03330330"
	; 	BITMAP "03000030"
	; 	BITMAP "00330030"
	; 	BITMAP "00030000"
	; 	BITMAP "03300030"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00033000"
	; 	BITMAP "00033000"
	; 	BITMAP "00003000"
	; 	BITMAP "00003000"
	; 	BITMAP "00003000"
	; 	BITMAP "00033300"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "30303300"
	; 	BITMAP "30303030"
	; 	BITMAP "30303030"
	; 	BITMAP "30303300"
	; 	BITMAP "30303000"
	; 	BITMAP "03003000"
	; 
	; 	BITMAP "00330000"
	; 	BITMAP "00333000"
	; 	BITMAP "00333300"
	; 	BITMAP "00333330"
	; 	BITMAP "00333330"
	; 	BITMAP "00333300"
	; 	BITMAP "00333000"
	; 	BITMAP "00330000"
	; 
	; 
	; 	' metade SPRITE: copia integral da pagina 0 (nave/inimigos/tiros/HUD)
	; 	CHRROM PATTERN 256
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000021"
	; 	BITMAP "00000100"
	; 	BITMAP "00000201"
	; 	BITMAP "00000001"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "21200000"
	; 	BITMAP "32121210"
	; 	BITMAP "31212121"
	; 	BITMAP "30000012"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00030000"
	; 	BITMAP "00130000"
	; 	BITMAP "00130000"
	; 	BITMAP "01130000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "10003300"
	; 	BITMAP "11033330"
	; 	BITMAP "13122221"
	; 	BITMAP "11122221"
	; 	BITMAP "13122221"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000033"
	; 	BITMAP "00000333"
	; 	BITMAP "10003333"
	; 	BITMAP "10003133"
	; 	BITMAP "30000112"
	; 	BITMAP "10000132"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "33000000"
	; 	BITMAP "33300000"
	; 	BITMAP "33330001"
	; 	BITMAP "33130001"
	; 	BITMAP "21100003"
	; 	BITMAP "23100001"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00330001"
	; 	BITMAP "03333011"
	; 	BITMAP "12222131"
	; 	BITMAP "12222111"
	; 	BITMAP "12222131"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00003000"
	; 	BITMAP "00003100"
	; 	BITMAP "00003100"
	; 	BITMAP "00003110"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000212"
	; 	BITMAP "01212123"
	; 	BITMAP "12121213"
	; 	BITMAP "21000003"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "12000000"
	; 	BITMAP "00100000"
	; 	BITMAP "10200000"
	; 	BITMAP "10000000"
	; 
	; 	BITMAP "00000021"
	; 	BITMAP "00000011"
	; 	BITMAP "00000022"
	; 	BITMAP "00000211"
	; 	BITMAP "00000212"
	; 	BITMAP "00000000"
	; 	BITMAP "00001222"
	; 	BITMAP "00003133"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00100000"
	; 	BITMAP "03010000"
	; 	BITMAP "00301000"
	; 	BITMAP "00030110"
	; 	BITMAP "00003312"
	; 	BITMAP "00031222"
	; 	BITMAP "00112222"
	; 
	; 	BITMAP "00112222"
	; 	BITMAP "00031222"
	; 	BITMAP "00003312"
	; 	BITMAP "00030110"
	; 	BITMAP "00301000"
	; 	BITMAP "03010000"
	; 	BITMAP "00100000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000100"
	; 	BITMAP "00001030"
	; 	BITMAP "00010300"
	; 	BITMAP "01103000"
	; 	BITMAP "21330000"
	; 	BITMAP "22213000"
	; 	BITMAP "22221100"
	; 
	; 	BITMAP "22221100"
	; 	BITMAP "22213000"
	; 	BITMAP "21330000"
	; 	BITMAP "01103000"
	; 	BITMAP "00010300"
	; 	BITMAP "00001030"
	; 	BITMAP "00000100"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "30000000"
	; 	BITMAP "30000111"
	; 	BITMAP "23001122"
	; 	BITMAP "13001000"
	; 	BITMAP "13000122"
	; 	BITMAP "00001322"
	; 	BITMAP "22101122"
	; 	BITMAP "31301000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "10000000"
	; 	BITMAP "11000000"
	; 	BITMAP "01012101"
	; 	BITMAP "10000001"
	; 	BITMAP "31021011"
	; 	BITMAP "11000011"
	; 	BITMAP "01010111"
	; 
	; 	BITMAP "01300000"
	; 	BITMAP "11300000"
	; 	BITMAP "11300000"
	; 	BITMAP "11302121"
	; 	BITMAP "13000000"
	; 	BITMAP "13021212"
	; 	BITMAP "13000000"
	; 	BITMAP "13012121"
	; 
	; 	BITMAP "13122221"
	; 	BITMAP "11111111"
	; 	BITMAP "01000001"
	; 	BITMAP "00011100"
	; 	BITMAP "00122210"
	; 	BITMAP "01122211"
	; 	BITMAP "01322231"
	; 	BITMAP "01122211"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000001"
	; 	BITMAP "00000012"
	; 	BITMAP "00000112"
	; 	BITMAP "00000232"
	; 	BITMAP "00000121"
	; 	BITMAP "00000111"
	; 	BITMAP "00001122"
	; 
	; 	BITMAP "00011221"
	; 	BITMAP "00122311"
	; 	BITMAP "01121121"
	; 	BITMAP "01111133"
	; 	BITMAP "01112121"
	; 	BITMAP "02300213"
	; 	BITMAP "11000000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "10000000"
	; 	BITMAP "21000000"
	; 	BITMAP "21100000"
	; 	BITMAP "33200000"
	; 	BITMAP "12100000"
	; 	BITMAP "11100000"
	; 	BITMAP "22110000"
	; 
	; 	BITMAP "12211000"
	; 	BITMAP "11322100"
	; 	BITMAP "12112110"
	; 	BITMAP "33111110"
	; 	BITMAP "12121110"
	; 	BITMAP "31200320"
	; 	BITMAP "00000011"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00022000"
	; 	BITMAP "00022000"
	; 	BITMAP "00023000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "01000010"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00011000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00022000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000001"
	; 	BITMAP "00000012"
	; 	BITMAP "00000112"
	; 	BITMAP "00000232"
	; 	BITMAP "00000121"
	; 	BITMAP "00000111"
	; 	BITMAP "00001122"
	; 
	; 	BITMAP "00011221"
	; 	BITMAP "00122311"
	; 	BITMAP "01121121"
	; 	BITMAP "01111122"
	; 	BITMAP "01112111"
	; 	BITMAP "02300102"
	; 	BITMAP "11000001"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "10000000"
	; 	BITMAP "21000000"
	; 	BITMAP "21100000"
	; 	BITMAP "23200000"
	; 	BITMAP "12100000"
	; 	BITMAP "11100000"
	; 	BITMAP "22110000"
	; 
	; 	BITMAP "12211000"
	; 	BITMAP "11322100"
	; 	BITMAP "12112110"
	; 	BITMAP "22111110"
	; 	BITMAP "11121110"
	; 	BITMAP "20100320"
	; 	BITMAP "10000011"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00022000"
	; 	BITMAP "00022000"
	; 	BITMAP "00022000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "01000010"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00011000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00022000"
	; 	BITMAP "00000000"
	; 	BITMAP "00222200"
	; 	BITMAP "01211210"
	; 	BITMAP "02022020"
	; 	BITMAP "00022000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000001"
	; 	BITMAP "00000012"
	; 	BITMAP "00000112"
	; 	BITMAP "00000232"
	; 	BITMAP "00000121"
	; 	BITMAP "00000111"
	; 	BITMAP "00001122"
	; 
	; 	BITMAP "00011221"
	; 	BITMAP "00122311"
	; 	BITMAP "01121121"
	; 	BITMAP "01111133"
	; 	BITMAP "01112121"
	; 	BITMAP "02300203"
	; 	BITMAP "11000023"
	; 	BITMAP "00000002"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "10000000"
	; 	BITMAP "21000000"
	; 	BITMAP "21100000"
	; 	BITMAP "33200000"
	; 	BITMAP "12100000"
	; 	BITMAP "11100000"
	; 	BITMAP "22110000"
	; 
	; 	BITMAP "12211000"
	; 	BITMAP "11322100"
	; 	BITMAP "12112110"
	; 	BITMAP "33111110"
	; 	BITMAP "12121110"
	; 	BITMAP "30200320"
	; 	BITMAP "32000011"
	; 	BITMAP "20000000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00022000"
	; 	BITMAP "00022000"
	; 	BITMAP "00023000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "01000010"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00011000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00022000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00200200"
	; 	BITMAP "00022000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000001"
	; 	BITMAP "00000012"
	; 	BITMAP "00000112"
	; 	BITMAP "00000232"
	; 	BITMAP "00000121"
	; 	BITMAP "00000111"
	; 	BITMAP "00001122"
	; 
	; 	BITMAP "00011221"
	; 	BITMAP "00122311"
	; 	BITMAP "01121121"
	; 	BITMAP "01111122"
	; 	BITMAP "01112111"
	; 	BITMAP "02300102"
	; 	BITMAP "11000002"
	; 	BITMAP "00000002"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "10000000"
	; 	BITMAP "21000000"
	; 	BITMAP "21100000"
	; 	BITMAP "23200000"
	; 	BITMAP "12100000"
	; 	BITMAP "11100000"
	; 	BITMAP "22110000"
	; 
	; 	BITMAP "12211000"
	; 	BITMAP "11322100"
	; 	BITMAP "12112110"
	; 	BITMAP "22111110"
	; 	BITMAP "11121110"
	; 	BITMAP "20100320"
	; 	BITMAP "20000011"
	; 	BITMAP "20000000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00022000"
	; 	BITMAP "00022000"
	; 	BITMAP "00022000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "01000010"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00011000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00022000"
	; 	BITMAP "00000000"
	; 	BITMAP "00222200"
	; 	BITMAP "01211210"
	; 	BITMAP "02022020"
	; 	BITMAP "00022000"
	; 	BITMAP "00022000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000001"
	; 	BITMAP "00000012"
	; 	BITMAP "00000112"
	; 	BITMAP "00000232"
	; 	BITMAP "00000121"
	; 	BITMAP "00000111"
	; 	BITMAP "00001122"
	; 
	; 	BITMAP "00011221"
	; 	BITMAP "00122311"
	; 	BITMAP "01121121"
	; 	BITMAP "01111133"
	; 	BITMAP "01112121"
	; 	BITMAP "02300203"
	; 	BITMAP "11000023"
	; 	BITMAP "00000002"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "10000000"
	; 	BITMAP "21000000"
	; 	BITMAP "21100000"
	; 	BITMAP "33200000"
	; 	BITMAP "12100000"
	; 	BITMAP "11100000"
	; 	BITMAP "22110000"
	; 
	; 	BITMAP "12211000"
	; 	BITMAP "11322100"
	; 	BITMAP "12112110"
	; 	BITMAP "33111110"
	; 	BITMAP "12121110"
	; 	BITMAP "30200320"
	; 	BITMAP "32000011"
	; 	BITMAP "20000000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00022000"
	; 	BITMAP "00022000"
	; 	BITMAP "00023000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "01000010"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00011000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00022000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00200200"
	; 	BITMAP "00022000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000001"
	; 	BITMAP "00000012"
	; 	BITMAP "00000112"
	; 	BITMAP "00000212"
	; 	BITMAP "00000121"
	; 	BITMAP "00000111"
	; 	BITMAP "00011221"
	; 
	; 	BITMAP "00122221"
	; 	BITMAP "01122211"
	; 	BITMAP "01112121"
	; 	BITMAP "01111231"
	; 	BITMAP "02301111"
	; 	BITMAP "11000112"
	; 	BITMAP "00000001"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "10000000"
	; 	BITMAP "20000000"
	; 	BITMAP "21000000"
	; 	BITMAP "32100000"
	; 	BITMAP "11100000"
	; 	BITMAP "11100000"
	; 	BITMAP "21100000"
	; 
	; 	BITMAP "12210000"
	; 	BITMAP "21121000"
	; 	BITMAP "11321110"
	; 	BITMAP "31113100"
	; 	BITMAP "11111100"
	; 	BITMAP "21101210"
	; 	BITMAP "10000120"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00022000"
	; 	BITMAP "00022000"
	; 	BITMAP "00123000"
	; 	BITMAP "00000000"
	; 	BITMAP "01000000"
	; 	BITMAP "00000110"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00010100"
	; 	BITMAP "00001000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00002000"
	; 	BITMAP "00000000"
	; 	BITMAP "00020200"
	; 	BITMAP "01211110"
	; 	BITMAP "01122210"
	; 	BITMAP "00022000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000001"
	; 	BITMAP "00000002"
	; 	BITMAP "00000111"
	; 	BITMAP "00000123"
	; 	BITMAP "00000112"
	; 	BITMAP "00001111"
	; 	BITMAP "00122212"
	; 
	; 	BITMAP "01122312"
	; 	BITMAP "01211111"
	; 	BITMAP "01131111"
	; 	BITMAP "02312121"
	; 	BITMAP "11000221"
	; 	BITMAP "00000013"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "10000000"
	; 	BITMAP "20000000"
	; 	BITMAP "21000000"
	; 	BITMAP "32100000"
	; 	BITMAP "11100000"
	; 	BITMAP "11000000"
	; 	BITMAP "12100000"
	; 
	; 	BITMAP "11100000"
	; 	BITMAP "11110000"
	; 	BITMAP "11211000"
	; 	BITMAP "23212000"
	; 	BITMAP "11111000"
	; 	BITMAP "32121100"
	; 	BITMAP "00001100"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00022000"
	; 	BITMAP "00002000"
	; 	BITMAP "00003000"
	; 	BITMAP "00000000"
	; 	BITMAP "01000000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00001010"
	; 	BITMAP "00000100"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000200"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000001"
	; 	BITMAP "00000001"
	; 	BITMAP "00000111"
	; 	BITMAP "00000121"
	; 	BITMAP "00000112"
	; 	BITMAP "00001111"
	; 	BITMAP "00122212"
	; 
	; 	BITMAP "01122312"
	; 	BITMAP "01211111"
	; 	BITMAP "01131111"
	; 	BITMAP "02312121"
	; 	BITMAP "11000221"
	; 	BITMAP "00000013"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "10000000"
	; 	BITMAP "20000000"
	; 	BITMAP "21000000"
	; 	BITMAP "32100000"
	; 	BITMAP "11100000"
	; 	BITMAP "11000000"
	; 	BITMAP "12100000"
	; 
	; 	BITMAP "11100000"
	; 	BITMAP "11110000"
	; 	BITMAP "11211000"
	; 	BITMAP "23212000"
	; 	BITMAP "11111000"
	; 	BITMAP "32121100"
	; 	BITMAP "00001100"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00022000"
	; 	BITMAP "00002000"
	; 	BITMAP "00003000"
	; 	BITMAP "00000000"
	; 	BITMAP "01000000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00001010"
	; 	BITMAP "00000100"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000200"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000001"
	; 	BITMAP "00000002"
	; 	BITMAP "00000111"
	; 	BITMAP "00000121"
	; 	BITMAP "00000112"
	; 	BITMAP "00001111"
	; 	BITMAP "00122212"
	; 
	; 	BITMAP "01122312"
	; 	BITMAP "01211111"
	; 	BITMAP "01131111"
	; 	BITMAP "02312111"
	; 	BITMAP "11000111"
	; 	BITMAP "00000012"
	; 	BITMAP "00000001"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "10000000"
	; 	BITMAP "20000000"
	; 	BITMAP "21000000"
	; 	BITMAP "32100000"
	; 	BITMAP "11100000"
	; 	BITMAP "11000000"
	; 	BITMAP "12100000"
	; 
	; 	BITMAP "11100000"
	; 	BITMAP "11110000"
	; 	BITMAP "11211000"
	; 	BITMAP "12212000"
	; 	BITMAP "11111000"
	; 	BITMAP "21121100"
	; 	BITMAP "10001100"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00022000"
	; 	BITMAP "00002000"
	; 	BITMAP "00003000"
	; 	BITMAP "00000000"
	; 	BITMAP "01000000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00001010"
	; 	BITMAP "00000100"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000200"
	; 	BITMAP "00000000"
	; 	BITMAP "00202200"
	; 	BITMAP "02211110"
	; 	BITMAP "00122200"
	; 	BITMAP "00022000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000001"
	; 	BITMAP "00000001"
	; 	BITMAP "00000111"
	; 	BITMAP "00000121"
	; 	BITMAP "00000112"
	; 	BITMAP "00001111"
	; 	BITMAP "00122212"
	; 
	; 	BITMAP "01122312"
	; 	BITMAP "01211111"
	; 	BITMAP "01131111"
	; 	BITMAP "02312121"
	; 	BITMAP "11000221"
	; 	BITMAP "00000013"
	; 	BITMAP "00000023"
	; 	BITMAP "00000002"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "10000000"
	; 	BITMAP "20000000"
	; 	BITMAP "21000000"
	; 	BITMAP "32100000"
	; 	BITMAP "11100000"
	; 	BITMAP "11000000"
	; 	BITMAP "12100000"
	; 
	; 	BITMAP "11100000"
	; 	BITMAP "11110000"
	; 	BITMAP "11211000"
	; 	BITMAP "23212000"
	; 	BITMAP "11111000"
	; 	BITMAP "31121100"
	; 	BITMAP "32001100"
	; 	BITMAP "20000000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00022000"
	; 	BITMAP "00002000"
	; 	BITMAP "00003000"
	; 	BITMAP "00000000"
	; 	BITMAP "01000000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00001010"
	; 	BITMAP "00000100"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000200"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000200"
	; 	BITMAP "00200200"
	; 	BITMAP "00022000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000001"
	; 	BITMAP "00000002"
	; 	BITMAP "00000111"
	; 	BITMAP "00000121"
	; 	BITMAP "00000112"
	; 	BITMAP "00001111"
	; 	BITMAP "00122212"
	; 
	; 	BITMAP "01122312"
	; 	BITMAP "01211111"
	; 	BITMAP "01131111"
	; 	BITMAP "02312111"
	; 	BITMAP "11000111"
	; 	BITMAP "00000002"
	; 	BITMAP "00000002"
	; 	BITMAP "00000002"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "10000000"
	; 	BITMAP "20000000"
	; 	BITMAP "21000000"
	; 	BITMAP "32100000"
	; 	BITMAP "11100000"
	; 	BITMAP "11000000"
	; 	BITMAP "12100000"
	; 
	; 	BITMAP "11100000"
	; 	BITMAP "11110000"
	; 	BITMAP "11211000"
	; 	BITMAP "12212000"
	; 	BITMAP "11111000"
	; 	BITMAP "20121100"
	; 	BITMAP "20001100"
	; 	BITMAP "20000000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00022000"
	; 	BITMAP "00002000"
	; 	BITMAP "00003000"
	; 	BITMAP "00000000"
	; 	BITMAP "01000000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00001010"
	; 	BITMAP "00000100"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000200"
	; 	BITMAP "00000000"
	; 	BITMAP "00202200"
	; 	BITMAP "02211110"
	; 	BITMAP "00022000"
	; 	BITMAP "00022000"
	; 	BITMAP "00022000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00011000"
	; 	BITMAP "00012000"
	; 	BITMAP "02112021"
	; 	BITMAP "02112021"
	; 	BITMAP "02112021"
	; 	BITMAP "02101021"
	; 	BITMAP "02100021"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00002000"
	; 	BITMAP "02023020"
	; 	BITMAP "03223032"
	; 	BITMAP "03223032"
	; 	BITMAP "03223032"
	; 	BITMAP "03223032"
	; 	BITMAP "02000020"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000002"
	; 	BITMAP "00000003"
	; 	BITMAP "00003301"
	; 	BITMAP "00033301"
	; 	BITMAP "00333303"
	; 	BITMAP "00333223"
	; 	BITMAP "00133203"
	; 
	; 	BITMAP "00133203"
	; 	BITMAP "00133303"
	; 	BITMAP "00133313"
	; 	BITMAP "00333303"
	; 	BITMAP "00333303"
	; 	BITMAP "00033300"
	; 	BITMAP "00003300"
	; 	BITMAP "00000300"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "22000000"
	; 	BITMAP "33000000"
	; 	BITMAP "33030000"
	; 	BITMAP "33333000"
	; 	BITMAP "30333300"
	; 	BITMAP "11333300"
	; 	BITMAP "10333300"
	; 
	; 	BITMAP "33333300"
	; 	BITMAP "33023300"
	; 	BITMAP "13223300"
	; 	BITMAP "13023300"
	; 	BITMAP "00023300"
	; 	BITMAP "00023300"
	; 	BITMAP "00333000"
	; 	BITMAP "00330000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000002"
	; 	BITMAP "00000003"
	; 	BITMAP "00000303"
	; 	BITMAP "00003333"
	; 	BITMAP "00033330"
	; 	BITMAP "00033331"
	; 	BITMAP "00013330"
	; 
	; 	BITMAP "00013333"
	; 	BITMAP "00013203"
	; 	BITMAP "00013223"
	; 	BITMAP "00033203"
	; 	BITMAP "00033200"
	; 	BITMAP "00003200"
	; 	BITMAP "00003330"
	; 	BITMAP "00000330"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "22000000"
	; 	BITMAP "33000000"
	; 	BITMAP "33330000"
	; 	BITMAP "33333000"
	; 	BITMAP "30333000"
	; 	BITMAP "11233000"
	; 	BITMAP "10233000"
	; 
	; 	BITMAP "33233000"
	; 	BITMAP "33333000"
	; 	BITMAP "13333000"
	; 	BITMAP "13333000"
	; 	BITMAP "00333000"
	; 	BITMAP "00333000"
	; 	BITMAP "00330000"
	; 	BITMAP "00300000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000003"
	; 	BITMAP "00000003"
	; 	BITMAP "00000003"
	; 	BITMAP "00000033"
	; 	BITMAP "00000031"
	; 
	; 	BITMAP "00000031"
	; 	BITMAP "00000031"
	; 	BITMAP "00000031"
	; 	BITMAP "00000031"
	; 	BITMAP "00000033"
	; 	BITMAP "00000003"
	; 	BITMAP "00000003"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "20000000"
	; 	BITMAP "20000000"
	; 	BITMAP "33300000"
	; 	BITMAP "13300000"
	; 	BITMAP "33300000"
	; 	BITMAP "33300000"
	; 	BITMAP "31300000"
	; 	BITMAP "31300000"
	; 
	; 	BITMAP "33300000"
	; 	BITMAP "33300000"
	; 	BITMAP "21300000"
	; 	BITMAP "23300000"
	; 	BITMAP "20000000"
	; 	BITMAP "20000000"
	; 	BITMAP "30000000"
	; 	BITMAP "30000000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00012000"
	; 	BITMAP "00112100"
	; 	BITMAP "01122110"
	; 	BITMAP "00001222"
	; 	BITMAP "00210111"
	; 	BITMAP "00020110"
	; 	BITMAP "00000100"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00022000"
	; 	BITMAP "00222100"
	; 	BITMAP "01120210"
	; 	BITMAP "00102022"
	; 	BITMAP "00120211"
	; 	BITMAP "00011110"
	; 	BITMAP "00000100"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00001000"
	; 	BITMAP "00012000"
	; 	BITMAP "00200200"
	; 	BITMAP "01002020"
	; 	BITMAP "10022002"
	; 	BITMAP "00200021"
	; 	BITMAP "00020210"
	; 	BITMAP "00000100"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00012000"
	; 	BITMAP "00122200"
	; 	BITMAP "01200220"
	; 	BITMAP "00033022"
	; 	BITMAP "00220211"
	; 	BITMAP "00010230"
	; 	BITMAP "00000100"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00111100"
	; 	BITMAP "01111110"
	; 	BITMAP "11133111"
	; 	BITMAP "11333311"
	; 	BITMAP "11333311"
	; 	BITMAP "11133111"
	; 	BITMAP "01111110"
	; 	BITMAP "00111100"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00333300"
	; 	BITMAP "03333330"
	; 	BITMAP "33333333"
	; 	BITMAP "33333333"
	; 	BITMAP "33333333"
	; 	BITMAP "33333333"
	; 	BITMAP "03333330"
	; 	BITMAP "00333300"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00022000"
	; 	BITMAP "00222022"
	; 	BITMAP "02220222"
	; 	BITMAP "31222212"
	; 	BITMAP "31222212"
	; 	BITMAP "31222112"
	; 	BITMAP "31222112"
	; 	BITMAP "02222122"
	; 
	; 	BITMAP "02222221"
	; 	BITMAP "00200221"
	; 	BITMAP "00200221"
	; 	BITMAP "02220023"
	; 	BITMAP "02220002"
	; 	BITMAP "00222002"
	; 	BITMAP "00222000"
	; 	BITMAP "00020000"
	; 
	; 	BITMAP "00022000"
	; 	BITMAP "22022200"
	; 	BITMAP "22202220"
	; 	BITMAP "21222213"
	; 	BITMAP "21222213"
	; 	BITMAP "21122213"
	; 	BITMAP "21122213"
	; 	BITMAP "22122220"
	; 
	; 	BITMAP "12222220"
	; 	BITMAP "12200200"
	; 	BITMAP "11200200"
	; 	BITMAP "32002220"
	; 	BITMAP "20002220"
	; 	BITMAP "20022200"
	; 	BITMAP "00022200"
	; 	BITMAP "00002000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "10000000"
	; 	BITMAP "11000000"
	; 	BITMAP "13122221"
	; 	BITMAP "11122221"
	; 	BITMAP "13122221"
	; 	BITMAP "13122221"
	; 	BITMAP "11111111"
	; 
	; 	BITMAP "01000001"
	; 	BITMAP "00011100"
	; 	BITMAP "00122210"
	; 	BITMAP "01122211"
	; 	BITMAP "01322231"
	; 	BITMAP "01122211"
	; 	BITMAP "00122210"
	; 	BITMAP "00011100"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "10000000"
	; 	BITMAP "10000100"
	; 	BITMAP "30000112"
	; 	BITMAP "10000132"
	; 	BITMAP "10010112"
	; 	BITMAP "00010131"
	; 
	; 	BITMAP "10110110"
	; 	BITMAP "10111000"
	; 	BITMAP "10113011"
	; 	BITMAP "01011010"
	; 	BITMAP "01013031"
	; 	BITMAP "01011011"
	; 	BITMAP "11013010"
	; 	BITMAP "00011012"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000001"
	; 	BITMAP "00100001"
	; 	BITMAP "21100003"
	; 	BITMAP "23100001"
	; 	BITMAP "21101001"
	; 	BITMAP "13101000"
	; 
	; 	BITMAP "01101101"
	; 	BITMAP "00011101"
	; 	BITMAP "11031101"
	; 	BITMAP "01011010"
	; 	BITMAP "13031010"
	; 	BITMAP "11011010"
	; 	BITMAP "01031011"
	; 	BITMAP "21011000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000001"
	; 	BITMAP "00000011"
	; 	BITMAP "12222131"
	; 	BITMAP "12222111"
	; 	BITMAP "12222131"
	; 	BITMAP "12222131"
	; 	BITMAP "11111111"
	; 
	; 	BITMAP "10000010"
	; 	BITMAP "00111000"
	; 	BITMAP "01222100"
	; 	BITMAP "11222110"
	; 	BITMAP "13222310"
	; 	BITMAP "11222110"
	; 	BITMAP "01222100"
	; 	BITMAP "00111000"
	; 
	; 	BITMAP "00133310"
	; 	BITMAP "00133310"
	; 	BITMAP "00011100"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000001"
	; 	BITMAP "00000011"
	; 
	; 	BITMAP "00000011"
	; 	BITMAP "00000012"
	; 	BITMAP "00000012"
	; 	BITMAP "00000012"
	; 	BITMAP "00000012"
	; 	BITMAP "00000113"
	; 	BITMAP "00000133"
	; 	BITMAP "00000011"
	; 
	; 	BITMAP "11001112"
	; 	BITMAP "31100111"
	; 	BITMAP "13110021"
	; 	BITMAP "11311012"
	; 	BITMAP "01131021"
	; 	BITMAP "11113013"
	; 	BITMAP "11011032"
	; 	BITMAP "11000012"
	; 
	; 	BITMAP "21100113"
	; 	BITMAP "32101132"
	; 	BITMAP "22101012"
	; 	BITMAP "32100023"
	; 	BITMAP "22100031"
	; 	BITMAP "33110010"
	; 	BITMAP "33310000"
	; 	BITMAP "11100000"
	; 
	; 	BITMAP "21110011"
	; 	BITMAP "11100113"
	; 	BITMAP "12001131"
	; 	BITMAP "21011311"
	; 	BITMAP "12013110"
	; 	BITMAP "31031111"
	; 	BITMAP "23011011"
	; 	BITMAP "21000011"
	; 
	; 	BITMAP "31100112"
	; 	BITMAP "23110123"
	; 	BITMAP "21010122"
	; 	BITMAP "32000123"
	; 	BITMAP "13000122"
	; 	BITMAP "01001133"
	; 	BITMAP "00001333"
	; 	BITMAP "00000111"
	; 
	; 	BITMAP "01333100"
	; 	BITMAP "01333100"
	; 	BITMAP "00111000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "10000000"
	; 	BITMAP "11000000"
	; 
	; 	BITMAP "11000000"
	; 	BITMAP "21000000"
	; 	BITMAP "21000000"
	; 	BITMAP "21000000"
	; 	BITMAP "21000000"
	; 	BITMAP "31100000"
	; 	BITMAP "33100000"
	; 	BITMAP "11000000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "10003300"
	; 	BITMAP "11033330"
	; 	BITMAP "13122221"
	; 	BITMAP "11122221"
	; 	BITMAP "13122221"
	; 	BITMAP "13122221"
	; 	BITMAP "11111111"
	; 
	; 	BITMAP "01000001"
	; 	BITMAP "00011100"
	; 	BITMAP "00122210"
	; 	BITMAP "01122211"
	; 	BITMAP "01322231"
	; 	BITMAP "01122211"
	; 	BITMAP "00122210"
	; 	BITMAP "00011100"
	; 
	; 	BITMAP "00000033"
	; 	BITMAP "00000333"
	; 	BITMAP "10003333"
	; 	BITMAP "10003133"
	; 	BITMAP "30000112"
	; 	BITMAP "10000132"
	; 	BITMAP "10010112"
	; 	BITMAP "00010131"
	; 
	; 	BITMAP "10110110"
	; 	BITMAP "10111000"
	; 	BITMAP "10113011"
	; 	BITMAP "01011010"
	; 	BITMAP "01013031"
	; 	BITMAP "01011011"
	; 	BITMAP "11013010"
	; 	BITMAP "00011012"
	; 
	; 	BITMAP "33000000"
	; 	BITMAP "33300000"
	; 	BITMAP "33330001"
	; 	BITMAP "33130001"
	; 	BITMAP "21100003"
	; 	BITMAP "23100001"
	; 	BITMAP "21101001"
	; 	BITMAP "13101000"
	; 
	; 	BITMAP "01101101"
	; 	BITMAP "00011101"
	; 	BITMAP "11031101"
	; 	BITMAP "01011010"
	; 	BITMAP "13031010"
	; 	BITMAP "11011010"
	; 	BITMAP "01031011"
	; 	BITMAP "21011000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00330001"
	; 	BITMAP "03333011"
	; 	BITMAP "12222131"
	; 	BITMAP "12222111"
	; 	BITMAP "12222131"
	; 	BITMAP "12222131"
	; 	BITMAP "11111111"
	; 
	; 	BITMAP "10000010"
	; 	BITMAP "00111000"
	; 	BITMAP "01222100"
	; 	BITMAP "11222110"
	; 	BITMAP "13222310"
	; 	BITMAP "11222110"
	; 	BITMAP "01222100"
	; 	BITMAP "00111000"
	; 
	; 	BITMAP "00133310"
	; 	BITMAP "00133310"
	; 	BITMAP "00011100"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000001"
	; 	BITMAP "00000011"
	; 
	; 	BITMAP "00000011"
	; 	BITMAP "00000012"
	; 	BITMAP "00000012"
	; 	BITMAP "00000012"
	; 	BITMAP "00000012"
	; 	BITMAP "00000113"
	; 	BITMAP "00000133"
	; 	BITMAP "00000011"
	; 
	; 	BITMAP "11001112"
	; 	BITMAP "31100111"
	; 	BITMAP "13110021"
	; 	BITMAP "11311012"
	; 	BITMAP "01131021"
	; 	BITMAP "11113013"
	; 	BITMAP "11011032"
	; 	BITMAP "11000012"
	; 
	; 	BITMAP "21100113"
	; 	BITMAP "32101132"
	; 	BITMAP "22101012"
	; 	BITMAP "32100023"
	; 	BITMAP "22100031"
	; 	BITMAP "33110010"
	; 	BITMAP "33310000"
	; 	BITMAP "11100000"
	; 
	; 	BITMAP "21110011"
	; 	BITMAP "11100113"
	; 	BITMAP "12001131"
	; 	BITMAP "21011311"
	; 	BITMAP "12013110"
	; 	BITMAP "31031111"
	; 	BITMAP "23011011"
	; 	BITMAP "21000011"
	; 
	; 	BITMAP "31100112"
	; 	BITMAP "23110123"
	; 	BITMAP "21010122"
	; 	BITMAP "32000123"
	; 	BITMAP "13000122"
	; 	BITMAP "01001133"
	; 	BITMAP "00001333"
	; 	BITMAP "00000111"
	; 
	; 	BITMAP "01333100"
	; 	BITMAP "01333100"
	; 	BITMAP "00111000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "10000000"
	; 	BITMAP "11000000"
	; 
	; 	BITMAP "11000000"
	; 	BITMAP "21000000"
	; 	BITMAP "21000000"
	; 	BITMAP "21000000"
	; 	BITMAP "21000000"
	; 	BITMAP "31100000"
	; 	BITMAP "33100000"
	; 	BITMAP "11000000"
	; 
	; 	BITMAP "00223200"
	; 	BITMAP "00032000"
	; 	BITMAP "00223200"
	; 	BITMAP "00032000"
	; 	BITMAP "00223200"
	; 	BITMAP "00032000"
	; 	BITMAP "00223200"
	; 	BITMAP "00032000"
	; 
	; 	BITMAP "00223200"
	; 	BITMAP "00032000"
	; 	BITMAP "00223200"
	; 	BITMAP "00032000"
	; 	BITMAP "00223200"
	; 	BITMAP "00032000"
	; 	BITMAP "00223200"
	; 	BITMAP "00032000"
	; 
	; 	BITMAP "00223200"
	; 	BITMAP "00032000"
	; 	BITMAP "00223200"
	; 	BITMAP "00032000"
	; 	BITMAP "00223200"
	; 	BITMAP "00032000"
	; 	BITMAP "00223200"
	; 	BITMAP "00032000"
	; 
	; 	BITMAP "00223200"
	; 	BITMAP "00032000"
	; 	BITMAP "00223200"
	; 	BITMAP "00032000"
	; 	BITMAP "00223200"
	; 	BITMAP "00032000"
	; 	BITMAP "00223200"
	; 	BITMAP "00032000"
	; 
	; 	BITMAP "00233200"
	; 	BITMAP "00233200"
	; 	BITMAP "00233200"
	; 	BITMAP "00233200"
	; 	BITMAP "00233200"
	; 	BITMAP "00233200"
	; 	BITMAP "00233200"
	; 	BITMAP "00233200"
	; 
	; 	BITMAP "00233200"
	; 	BITMAP "00233200"
	; 	BITMAP "00233200"
	; 	BITMAP "00233200"
	; 	BITMAP "00233200"
	; 	BITMAP "00233200"
	; 	BITMAP "00233200"
	; 	BITMAP "00233200"
	; 
	; 	BITMAP "00233200"
	; 	BITMAP "00233200"
	; 	BITMAP "00233200"
	; 	BITMAP "00233200"
	; 	BITMAP "00233200"
	; 	BITMAP "00233200"
	; 	BITMAP "00233200"
	; 	BITMAP "00233200"
	; 
	; 	BITMAP "00233200"
	; 	BITMAP "00233200"
	; 	BITMAP "00233200"
	; 	BITMAP "00233200"
	; 	BITMAP "00233200"
	; 	BITMAP "00233200"
	; 	BITMAP "00233200"
	; 	BITMAP "00233200"
	; 
	; 	BITMAP "10010112"
	; 	BITMAP "00010131"
	; 	BITMAP "10110110"
	; 	BITMAP "10131000"
	; 	BITMAP "10111011"
	; 	BITMAP "01010112"
	; 	BITMAP "03001123"
	; 	BITMAP "01011233"
	; 
	; 	BITMAP "21101001"
	; 	BITMAP "13101000"
	; 	BITMAP "01101101"
	; 	BITMAP "00013101"
	; 	BITMAP "11011101"
	; 	BITMAP "21101010"
	; 	BITMAP "32110030"
	; 	BITMAP "33211010"
	; 
	; 	BITMAP "12222131"
	; 	BITMAP "11111111"
	; 	BITMAP "10000010"
	; 	BITMAP "00111000"
	; 	BITMAP "01222100"
	; 	BITMAP "11222110"
	; 	BITMAP "13222310"
	; 	BITMAP "11222110"
	; 
	; 	BITMAP "00000310"
	; 	BITMAP "00000311"
	; 	BITMAP "00000311"
	; 	BITMAP "12120311"
	; 	BITMAP "00000031"
	; 	BITMAP "21212031"
	; 	BITMAP "00000031"
	; 	BITMAP "12121031"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000001"
	; 	BITMAP "00000011"
	; 	BITMAP "10121010"
	; 	BITMAP "10000001"
	; 	BITMAP "11012013"
	; 	BITMAP "11000011"
	; 	BITMAP "11101010"
	; 
	; 	BITMAP "00000003"
	; 	BITMAP "11100003"
	; 	BITMAP "22110032"
	; 	BITMAP "00010031"
	; 	BITMAP "22100031"
	; 	BITMAP "22310000"
	; 	BITMAP "22110122"
	; 	BITMAP "00010313"
	; 
	; 	BITMAP "12000000"
	; 	BITMAP "11000000"
	; 	BITMAP "22000000"
	; 	BITMAP "11200000"
	; 	BITMAP "21200000"
	; 	BITMAP "00000000"
	; 	BITMAP "22210000"
	; 	BITMAP "33130000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00001222"
	; 	BITMAP "00001111"
	; 	BITMAP "00001212"
	; 	BITMAP "00011111"
	; 	BITMAP "00011112"
	; 	BITMAP "00011121"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00000122"
	; 	BITMAP "23001322"
	; 	BITMAP "13001122"
	; 	BITMAP "13001322"
	; 	BITMAP "13001122"
	; 	BITMAP "23000111"
	; 	BITMAP "13000000"
	; 	BITMAP "03000000"
	; 
	; 	BITMAP "10000101"
	; 	BITMAP "31001111"
	; 	BITMAP "11001111"
	; 	BITMAP "31011011"
	; 	BITMAP "11011113"
	; 	BITMAP "10001113"
	; 	BITMAP "00020000"
	; 	BITMAP "01112223"
	; 
	; 	BITMAP "30000000"
	; 	BITMAP "31000330"
	; 	BITMAP "31103333"
	; 	BITMAP "31312222"
	; 	BITMAP "01112222"
	; 	BITMAP "01312222"
	; 	BITMAP "01312222"
	; 	BITMAP "01111111"
	; 
	; 	BITMAP "00122210"
	; 	BITMAP "00011100"
	; 	BITMAP "01133310"
	; 	BITMAP "11133310"
	; 	BITMAP "13011100"
	; 	BITMAP "11000000"
	; 	BITMAP "11011110"
	; 	BITMAP "10012100"
	; 
	; 	BITMAP "13011233"
	; 	BITMAP "00011123"
	; 	BITMAP "11001112"
	; 	BITMAP "31100111"
	; 	BITMAP "13110021"
	; 	BITMAP "11311012"
	; 	BITMAP "01131021"
	; 	BITMAP "11113013"
	; 
	; 	BITMAP "33211031"
	; 	BITMAP "32111000"
	; 	BITMAP "21110011"
	; 	BITMAP "11100113"
	; 	BITMAP "12001131"
	; 	BITMAP "21011311"
	; 	BITMAP "12013110"
	; 	BITMAP "31031111"
	; 
	; 	BITMAP "01222100"
	; 	BITMAP "00111000"
	; 	BITMAP "01333110"
	; 	BITMAP "01333111"
	; 	BITMAP "00111031"
	; 	BITMAP "00000011"
	; 	BITMAP "01111011"
	; 	BITMAP "00121001"
	; 
	; 	BITMAP "00000003"
	; 	BITMAP "03300013"
	; 	BITMAP "33330113"
	; 	BITMAP "22221313"
	; 	BITMAP "22221110"
	; 	BITMAP "22221310"
	; 	BITMAP "22221310"
	; 	BITMAP "11111110"
	; 
	; 	BITMAP "10100001"
	; 	BITMAP "11110013"
	; 	BITMAP "11110011"
	; 	BITMAP "11011013"
	; 	BITMAP "31111011"
	; 	BITMAP "31110001"
	; 	BITMAP "00002000"
	; 	BITMAP "32221110"
	; 
	; 	BITMAP "22100000"
	; 	BITMAP "22310032"
	; 	BITMAP "22110031"
	; 	BITMAP "22310031"
	; 	BITMAP "22110031"
	; 	BITMAP "11100032"
	; 	BITMAP "00000031"
	; 	BITMAP "00000030"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "22210000"
	; 	BITMAP "11110000"
	; 	BITMAP "21210000"
	; 	BITMAP "11111000"
	; 	BITMAP "21111000"
	; 	BITMAP "12111000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00011012"
	; 	BITMAP "00113011"
	; 	BITMAP "00213011"
	; 	BITMAP "00113011"
	; 	BITMAP "00213011"
	; 	BITMAP "00111011"
	; 	BITMAP "01110111"
	; 	BITMAP "01101112"
	; 
	; 	BITMAP "13000000"
	; 	BITMAP "11300000"
	; 	BITMAP "11300000"
	; 	BITMAP "21300002"
	; 	BITMAP "11300001"
	; 	BITMAP "11300011"
	; 	BITMAP "22300012"
	; 	BITMAP "11300211"
	; 
	; 	BITMAP "01211113"
	; 	BITMAP "11212113"
	; 	BITMAP "11112111"
	; 	BITMAP "01111111"
	; 	BITMAP "20111101"
	; 	BITMAP "12011111"
	; 	BITMAP "11200000"
	; 	BITMAP "11122222"
	; 
	; 	BITMAP "00100000"
	; 	BITMAP "00001110"
	; 	BITMAP "30012221"
	; 	BITMAP "30112221"
	; 	BITMAP "30132223"
	; 	BITMAP "30112221"
	; 	BITMAP "00012221"
	; 	BITMAP "30001110"
	; 
	; 	BITMAP "11011001"
	; 	BITMAP "01022011"
	; 	BITMAP "01011011"
	; 	BITMAP "10022012"
	; 	BITMAP "10111012"
	; 	BITMAP "10121012"
	; 	BITMAP "00110012"
	; 	BITMAP "01110113"
	; 
	; 	BITMAP "11011032"
	; 	BITMAP "11000012"
	; 	BITMAP "21100113"
	; 	BITMAP "32101132"
	; 	BITMAP "22101012"
	; 	BITMAP "32100023"
	; 	BITMAP "22100031"
	; 	BITMAP "33110012"
	; 
	; 	BITMAP "23011011"
	; 	BITMAP "21000011"
	; 	BITMAP "31100112"
	; 	BITMAP "23110123"
	; 	BITMAP "21010122"
	; 	BITMAP "32000123"
	; 	BITMAP "13000122"
	; 	BITMAP "21001133"
	; 
	; 	BITMAP "10011011"
	; 	BITMAP "11022010"
	; 	BITMAP "11011010"
	; 	BITMAP "21022001"
	; 	BITMAP "21011101"
	; 	BITMAP "21012101"
	; 	BITMAP "21001100"
	; 	BITMAP "31101110"
	; 
	; 	BITMAP "00000100"
	; 	BITMAP "01110000"
	; 	BITMAP "12221003"
	; 	BITMAP "12221103"
	; 	BITMAP "32223103"
	; 	BITMAP "12221103"
	; 	BITMAP "12221000"
	; 	BITMAP "01110003"
	; 
	; 	BITMAP "31111210"
	; 	BITMAP "31121211"
	; 	BITMAP "11121111"
	; 	BITMAP "11111110"
	; 	BITMAP "10111102"
	; 	BITMAP "11111021"
	; 	BITMAP "00000211"
	; 	BITMAP "22222111"
	; 
	; 	BITMAP "00000031"
	; 	BITMAP "00000311"
	; 	BITMAP "00000311"
	; 	BITMAP "20000312"
	; 	BITMAP "10000311"
	; 	BITMAP "11000311"
	; 	BITMAP "21000322"
	; 	BITMAP "11200311"
	; 
	; 	BITMAP "21011000"
	; 	BITMAP "11031100"
	; 	BITMAP "11031200"
	; 	BITMAP "11031100"
	; 	BITMAP "11031200"
	; 	BITMAP "11011100"
	; 	BITMAP "11101110"
	; 	BITMAP "21110110"
	; 
	; 	BITMAP "01011211"
	; 	BITMAP "00112111"
	; 	BITMAP "00111121"
	; 	BITMAP "00011211"
	; 	BITMAP "00000000"
	; 	BITMAP "00011111"
	; 	BITMAP "00111112"
	; 	BITMAP "01211123"
	; 
	; 	BITMAP "11300121"
	; 	BITMAP "21300112"
	; 	BITMAP "11300111"
	; 	BITMAP "21000011"
	; 	BITMAP "00000001"
	; 	BITMAP "11300000"
	; 	BITMAP "11130000"
	; 	BITMAP "21130000"
	; 
	; 	BITMAP "12111211"
	; 	BITMAP "11111211"
	; 	BITMAP "21121211"
	; 	BITMAP "12111211"
	; 	BITMAP "11211211"
	; 	BITMAP "11121211"
	; 	BITMAP "01112211"
	; 	BITMAP "00110211"
	; 
	; 	BITMAP "30013331"
	; 	BITMAP "30013331"
	; 	BITMAP "13001110"
	; 	BITMAP "13000000"
	; 	BITMAP "11300000"
	; 	BITMAP "21300000"
	; 	BITMAP "11300000"
	; 	BITMAP "21130000"
	; 
	; 	BITMAP "02200133"
	; 	BITMAP "01100011"
	; 	BITMAP "02220000"
	; 	BITMAP "01212000"
	; 	BITMAP "00321200"
	; 	BITMAP "00012120"
	; 	BITMAP "00003212"
	; 	BITMAP "00000121"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00022000"
	; 	BITMAP "00222200"
	; 	BITMAP "00222200"
	; 	BITMAP "00222200"
	; 	BITMAP "00222200"
	; 	BITMAP "00022000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00033000"
	; 	BITMAP "00233200"
	; 	BITMAP "00233200"
	; 	BITMAP "00233200"
	; 	BITMAP "00233200"
	; 	BITMAP "00033000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "33310003"
	; 	BITMAP "11100012"
	; 	BITMAP "00000001"
	; 	BITMAP "00000012"
	; 	BITMAP "00000003"
	; 	BITMAP "00000012"
	; 	BITMAP "00000001"
	; 	BITMAP "20000012"
	; 
	; 	BITMAP "30001333"
	; 	BITMAP "21000111"
	; 	BITMAP "10000000"
	; 	BITMAP "21000000"
	; 	BITMAP "30000000"
	; 	BITMAP "21000000"
	; 	BITMAP "10000000"
	; 	BITMAP "21000002"
	; 
	; 	BITMAP "33100220"
	; 	BITMAP "11000110"
	; 	BITMAP "00002220"
	; 	BITMAP "00021210"
	; 	BITMAP "00212300"
	; 	BITMAP "02121000"
	; 	BITMAP "21230000"
	; 	BITMAP "12100000"
	; 
	; 	BITMAP "13331003"
	; 	BITMAP "13331003"
	; 	BITMAP "01110031"
	; 	BITMAP "00000031"
	; 	BITMAP "00000311"
	; 	BITMAP "00000312"
	; 	BITMAP "00000311"
	; 	BITMAP "00003112"
	; 
	; 	BITMAP "11211121"
	; 	BITMAP "11211111"
	; 	BITMAP "11212112"
	; 	BITMAP "11211121"
	; 	BITMAP "11211211"
	; 	BITMAP "11212111"
	; 	BITMAP "11221110"
	; 	BITMAP "11201100"
	; 
	; 	BITMAP "12100311"
	; 	BITMAP "21100312"
	; 	BITMAP "11100311"
	; 	BITMAP "11000012"
	; 	BITMAP "10000000"
	; 	BITMAP "00000311"
	; 	BITMAP "00003111"
	; 	BITMAP "00003112"
	; 
	; 	BITMAP "11211010"
	; 	BITMAP "11121100"
	; 	BITMAP "12111100"
	; 	BITMAP "11211000"
	; 	BITMAP "00000000"
	; 	BITMAP "11111000"
	; 	BITMAP "21111100"
	; 	BITMAP "32111210"
	; 
	; 	BITMAP "01121123"
	; 	BITMAP "01112112"
	; 	BITMAP "01111211"
	; 	BITMAP "00111121"
	; 	BITMAP "00031112"
	; 	BITMAP "00003111"
	; 	BITMAP "00000111"
	; 	BITMAP "00000011"
	; 
	; 	BITMAP "21113000"
	; 	BITMAP "11113000"
	; 	BITMAP "11111300"
	; 	BITMAP "11211300"
	; 	BITMAP "11111130"
	; 	BITMAP "21111130"
	; 	BITMAP "12112113"
	; 	BITMAP "12111113"
	; 
	; 	BITMAP "00000021"
	; 	BITMAP "00000112"
	; 	BITMAP "00000111"
	; 	BITMAP "00000011"
	; 	BITMAP "00000001"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "11130000"
	; 	BITMAP "11113000"
	; 	BITMAP "21113000"
	; 	BITMAP "12113000"
	; 	BITMAP "11211300"
	; 	BITMAP "11121300"
	; 	BITMAP "01112300"
	; 	BITMAP "00111130"
	; 
	; 	BITMAP "00000032"
	; 	BITMAP "00000031"
	; 	BITMAP "00000033"
	; 	BITMAP "00000033"
	; 	BITMAP "00000033"
	; 	BITMAP "00000033"
	; 	BITMAP "00000003"
	; 	BITMAP "00000003"
	; 
	; 	BITMAP "10000003"
	; 	BITMAP "21000000"
	; 	BITMAP "12000000"
	; 	BITMAP "21000000"
	; 	BITMAP "12000000"
	; 	BITMAP "21000000"
	; 	BITMAP "31000000"
	; 	BITMAP "33000000"
	; 
	; 	BITMAP "30000001"
	; 	BITMAP "00000012"
	; 	BITMAP "00000021"
	; 	BITMAP "00000012"
	; 	BITMAP "00000021"
	; 	BITMAP "00000012"
	; 	BITMAP "00000013"
	; 	BITMAP "00000033"
	; 
	; 	BITMAP "23000000"
	; 	BITMAP "13000000"
	; 	BITMAP "33000000"
	; 	BITMAP "33000000"
	; 	BITMAP "33000000"
	; 	BITMAP "33000000"
	; 	BITMAP "30000000"
	; 	BITMAP "30000000"
	; 
	; 	BITMAP "00003111"
	; 	BITMAP "00031111"
	; 	BITMAP "00031112"
	; 	BITMAP "00031121"
	; 	BITMAP "00311211"
	; 	BITMAP "00312111"
	; 	BITMAP "00321110"
	; 	BITMAP "03111100"
	; 
	; 	BITMAP "12000000"
	; 	BITMAP "21100000"
	; 	BITMAP "11100000"
	; 	BITMAP "11000000"
	; 	BITMAP "10000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00031112"
	; 	BITMAP "00031111"
	; 	BITMAP "00311111"
	; 	BITMAP "00311211"
	; 	BITMAP "03111111"
	; 	BITMAP "03111112"
	; 	BITMAP "31121121"
	; 	BITMAP "31111121"
	; 
	; 	BITMAP "32112110"
	; 	BITMAP "21121110"
	; 	BITMAP "11211110"
	; 	BITMAP "12111100"
	; 	BITMAP "21113000"
	; 	BITMAP "11130000"
	; 	BITMAP "11100000"
	; 	BITMAP "11000000"
	; 
	; 	BITMAP "00000003"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "11211111"
	; 	BITMAP "31121121"
	; 	BITMAP "01112111"
	; 	BITMAP "00111211"
	; 	BITMAP "00031121"
	; 	BITMAP "00003112"
	; 	BITMAP "00000111"
	; 	BITMAP "00000012"
	; 
	; 	BITMAP "30000000"
	; 	BITMAP "30000000"
	; 	BITMAP "13000000"
	; 	BITMAP "13000000"
	; 	BITMAP "11300000"
	; 	BITMAP "12300000"
	; 	BITMAP "21130000"
	; 	BITMAP "11130000"
	; 
	; 	BITMAP "00011130"
	; 	BITMAP "00001113"
	; 	BITMAP "00000113"
	; 	BITMAP "00000011"
	; 	BITMAP "00000001"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "30000000"
	; 	BITMAP "30000000"
	; 	BITMAP "13000000"
	; 	BITMAP "03000000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "33000000"
	; 	BITMAP "03000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00000033"
	; 	BITMAP "00000030"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000003"
	; 	BITMAP "00000003"
	; 	BITMAP "00000031"
	; 	BITMAP "00000030"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "03111000"
	; 	BITMAP "31110000"
	; 	BITMAP "31100000"
	; 	BITMAP "11000000"
	; 	BITMAP "10000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00000003"
	; 	BITMAP "00000003"
	; 	BITMAP "00000031"
	; 	BITMAP "00000031"
	; 	BITMAP "00000311"
	; 	BITMAP "00000321"
	; 	BITMAP "00003112"
	; 	BITMAP "00003111"
	; 
	; 	BITMAP "11111211"
	; 	BITMAP "12112113"
	; 	BITMAP "11121110"
	; 	BITMAP "11211100"
	; 	BITMAP "12113000"
	; 	BITMAP "21130000"
	; 	BITMAP "11100000"
	; 	BITMAP "21000000"
	; 
	; 	BITMAP "30000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00000001"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "11113000"
	; 	BITMAP "31213000"
	; 	BITMAP "03111300"
	; 	BITMAP "00111300"
	; 	BITMAP "00012130"
	; 	BITMAP "00001130"
	; 	BITMAP "00000113"
	; 	BITMAP "00000013"
	; 
	; 	BITMAP "00031111"
	; 	BITMAP "00031213"
	; 	BITMAP "00311130"
	; 	BITMAP "00311100"
	; 	BITMAP "03121000"
	; 	BITMAP "03110000"
	; 	BITMAP "31100000"
	; 	BITMAP "31000000"
	; 
	; 	BITMAP "10000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 	BITMAP "00000000"
	; 
BANK_2_FREE:	EQU $bfff-$
	TIMES $bfff-$ DB $ff
	DB $01
; Intruder Alert v0.36 dedicated music bank (physical mapper bank 3).
FORG $0C010
ORG $8000
INCLUDE "famistudio_engine_gasm80.asm"
INCLUDE "intruder_alert_data_gasm80.asm"
; The map write in cvb_FAMISTUDIO_START is the last bank-0 opcode.  At
; logical $B3F4 the CPU now fetches this bank-3 continuation.
TIMES $B3F4-$ DB $FF
cvb_FAMISTUDIO_START_BANK3:
	LDA #0
	STA music_mode
	LDX #MUSIC_DATA_INTRUDER_ALERT
	LDY #MUSIC_DATA_INTRUDER_ALERT>>8
	JSR FAMISTUDIO_INIT
	LDA #0
	JSR FAMISTUDIO_MUSIC_PLAY
	LDA #1
	STA FAMISTUDIO_ACTIVE
	JMP cvb_FAMISTUDIO_RESTORE
TIMES $BFFF-$ DB $FF
DB $03

rom_end:
    if CVBASIC_BANK_SWITCHING
	forg CVBASIC_BANK_ROM_SIZE*1024+16-6	; Go to final of ROM minus vectors
   else
	times $fffa-$ db $ff
    endif

	dw nmi_handler
	dw START
	dw irq_handler	

FORG $74010

ORG $8000

; CHR data
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$02,$05,$02,$00,$00,$00
	db $00,$00,$02,$07,$02,$00,$00,$00
	db $00,$00,$00,$00,$00,$20,$00,$00
	db $00,$00,$00,$08,$00,$20,$00,$00
	db $00,$00,$10,$28,$10,$00,$00,$00
	db $00,$00,$10,$38,$10,$00,$00,$00
	db $00,$00,$40,$00,$00,$00,$00,$00
	db $00,$00,$40,$00,$00,$00,$00,$00
	db $00,$08,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$04,$00,$00,$00,$00
	db $00,$00,$00,$04,$00,$00,$00,$00
	db $00,$00,$20,$00,$00,$00,$00,$00
	db $00,$00,$20,$00,$00,$00,$00,$00
	db $00,$00,$04,$20,$00,$08,$00,$00
	db $00,$00,$04,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$02,$00,$00
	db $00,$00,$00,$00,$00,$02,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$08,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$02,$00,$00
	db $00,$00,$00,$00,$08,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$04,$0a,$04,$00,$00,$00
	db $00,$00,$04,$0e,$04,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$04,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$08,$03
	db $00,$00,$00,$00,$00,$00,$20,$03
	db $00,$00,$20,$10,$00,$00,$00,$00
	db $00,$00,$20,$00,$00,$00,$00,$00
	db $00,$20,$00,$00,$00,$08,$00,$00
	db $00,$20,$00,$00,$00,$00,$00,$00
	db $00,$00,$40,$08,$00,$20,$00,$00
	db $00,$00,$00,$08,$00,$20,$00,$00
	db $00,$00,$04,$00,$00,$10,$00,$00
	db $00,$00,$00,$00,$00,$10,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$20,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$20,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$08,$00,$00,$00
	db $00,$00,$00,$00,$08,$00,$00,$00
	db $00,$00,$00,$00,$00,$04,$00,$00
	db $00,$00,$00,$20,$00,$00,$00,$00
	db $00,$00,$08,$00,$00,$00,$00,$00
	db $00,$00,$08,$10,$00,$00,$00,$00
	db $00,$00,$00,$00,$04,$00,$00,$00
	db $00,$00,$40,$00,$04,$00,$00,$00
	db $00,$00,$00,$00,$00,$14,$28,$00
	db $00,$00,$00,$00,$00,$14,$28,$00
	db $00,$00,$00,$00,$00,$10,$20,$00
	db $00,$00,$00,$00,$00,$10,$20,$00
	db $00,$00,$00,$00,$00,$10,$28,$00
	db $00,$00,$00,$00,$00,$10,$28,$00
	db $3c,$66,$c0,$c0,$66,$3c,$18,$08
	db $3c,$66,$c0,$c0,$66,$3c,$18,$08
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $1c,$1c,$1c,$18,$18,$00,$18,$18
	db $1c,$1c,$1c,$18,$18,$00,$18,$18
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
	db $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$08,$10,$00
	db $00,$00,$00,$00,$00,$08,$10,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$24,$18,$18,$24,$00
	db $00,$00,$00,$24,$18,$18,$24,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$18,$18,$08
	db $00,$00,$00,$00,$00,$18,$18,$08
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $38,$4c,$c6,$c6,$c6,$64,$38,$00
	db $38,$4c,$c6,$c6,$c6,$64,$38,$00
	db $18,$18,$18,$18,$18,$18,$7e,$00
	db $18,$18,$18,$18,$18,$18,$7e,$00
	db $7c,$c6,$0e,$3c,$78,$e0,$fe,$00
	db $7c,$c6,$0e,$3c,$78,$e0,$fe,$00
	db $7e,$0c,$18,$3c,$06,$c6,$7c,$00
	db $7e,$0c,$18,$3c,$06,$c6,$7c,$00
	db $1c,$3c,$6c,$cc,$fe,$0c,$0c,$00
	db $1c,$3c,$6c,$cc,$fe,$0c,$0c,$00
	db $fc,$c0,$fc,$06,$06,$c6,$7c,$00
	db $fc,$c0,$fc,$06,$06,$c6,$7c,$00
	db $3c,$60,$c0,$fc,$c6,$c6,$7c,$00
	db $3c,$60,$c0,$fc,$c6,$c6,$7c,$00
	db $fe,$c6,$0c,$18,$30,$30,$30,$00
	db $fe,$c6,$0c,$18,$30,$30,$30,$00
	db $7c,$c6,$c6,$7c,$c6,$c6,$7c,$00
	db $7c,$c6,$c6,$7c,$c6,$c6,$7c,$00
	db $7c,$c6,$c6,$7e,$06,$0c,$78,$00
	db $7c,$c6,$c6,$7e,$06,$0c,$78,$00
	db $18,$18,$00,$00,$18,$18,$00,$00
	db $18,$18,$00,$00,$18,$18,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $10,$30,$70,$ff,$ff,$70,$30,$10
	db $10,$30,$70,$ff,$ff,$70,$30,$10
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $3c,$66,$66,$06,$18,$00,$18,$18
	db $3c,$66,$66,$06,$18,$00,$18,$18
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $38,$6c,$c6,$c6,$fe,$c6,$c6,$00
	db $38,$6c,$c6,$c6,$fe,$c6,$c6,$00
	db $fc,$c6,$c6,$fc,$c6,$c6,$fc,$00
	db $fc,$c6,$c6,$fc,$c6,$c6,$fc,$00
	db $3c,$66,$c0,$c0,$c0,$66,$3c,$00
	db $3c,$66,$c0,$c0,$c0,$66,$3c,$00
	db $f8,$cc,$c6,$c6,$c6,$cc,$f8,$00
	db $f8,$cc,$c6,$c6,$c6,$cc,$f8,$00
	db $fe,$c0,$c0,$fc,$c0,$c0,$fe,$00
	db $fe,$c0,$c0,$fc,$c0,$c0,$fe,$00
	db $fe,$c0,$c0,$fc,$c0,$c0,$c0,$00
	db $fe,$c0,$c0,$fc,$c0,$c0,$c0,$00
	db $3e,$60,$c0,$ce,$c6,$66,$3e,$00
	db $3e,$60,$c0,$ce,$c6,$66,$3e,$00
	db $c6,$c6,$c6,$fe,$c6,$c6,$c6,$00
	db $c6,$c6,$c6,$fe,$c6,$c6,$c6,$00
	db $7e,$18,$18,$18,$18,$18,$7e,$00
	db $7e,$18,$18,$18,$18,$18,$7e,$00
	db $1e,$06,$06,$06,$c6,$c6,$7c,$00
	db $1e,$06,$06,$06,$c6,$c6,$7c,$00
	db $c6,$cc,$d8,$f0,$f8,$dc,$ce,$00
	db $c6,$cc,$d8,$f0,$f8,$dc,$ce,$00
	db $60,$60,$60,$60,$60,$60,$7e,$00
	db $60,$60,$60,$60,$60,$60,$7e,$00
	db $c6,$ee,$fe,$fe,$d6,$c6,$c6,$00
	db $c6,$ee,$fe,$fe,$d6,$c6,$c6,$00
	db $c6,$e6,$f6,$fe,$de,$ce,$c6,$00
	db $c6,$e6,$f6,$fe,$de,$ce,$c6,$00
	db $7c,$c6,$c6,$c6,$c6,$c6,$7c,$00
	db $7c,$c6,$c6,$c6,$c6,$c6,$7c,$00
	db $fc,$c6,$c6,$c6,$fc,$c0,$c0,$00
	db $fc,$c6,$c6,$c6,$fc,$c0,$c0,$00
	db $7c,$c6,$c6,$c6,$de,$cc,$7a,$00
	db $7c,$c6,$c6,$c6,$de,$cc,$7a,$00
	db $fc,$c6,$c6,$ce,$f8,$dc,$ce,$00
	db $fc,$c6,$c6,$ce,$f8,$dc,$ce,$00
	db $78,$cc,$c0,$7c,$06,$c6,$7c,$00
	db $78,$cc,$c0,$7c,$06,$c6,$7c,$00
	db $7e,$18,$18,$18,$18,$18,$18,$00
	db $7e,$18,$18,$18,$18,$18,$18,$00
	db $c6,$c6,$c6,$c6,$c6,$c6,$7c,$00
	db $c6,$c6,$c6,$c6,$c6,$c6,$7c,$00
	db $c6,$c6,$c6,$ee,$7c,$38,$10,$00
	db $c6,$c6,$c6,$ee,$7c,$38,$10,$00
	db $c6,$c6,$d6,$fe,$fe,$ee,$c6,$00
	db $c6,$c6,$d6,$fe,$fe,$ee,$c6,$00
	db $c6,$ee,$7c,$38,$7c,$ee,$c6,$00
	db $c6,$ee,$7c,$38,$7c,$ee,$c6,$00
	db $66,$66,$66,$3c,$18,$18,$18,$00
	db $66,$66,$66,$3c,$18,$18,$18,$00
	db $fe,$0e,$1c,$38,$70,$e0,$fe,$00
	db $fe,$0e,$1c,$38,$70,$e0,$fe,$00
	db $00,$70,$10,$10,$10,$10,$70,$00
	db $00,$70,$10,$10,$10,$10,$70,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $18,$3c,$7e,$ff,$18,$18,$18,$18
	db $18,$3c,$7e,$ff,$18,$18,$18,$18
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$1f,$1f,$3f,$38
	db $00,$00,$00,$00,$1f,$1f,$3f,$38
	db $00,$00,$00,$00,$fb,$fb,$fb,$03
	db $00,$00,$00,$00,$fb,$fb,$fb,$03
	db $00,$00,$00,$00,$fe,$fe,$ff,$83
	db $00,$00,$00,$00,$fe,$fe,$ff,$83
	db $00,$00,$00,$00,$1f,$1f,$bf,$b8
	db $00,$00,$00,$00,$1f,$1f,$bf,$b8
	db $00,$00,$00,$00,$e1,$e1,$fb,$3b
	db $00,$00,$00,$00,$e1,$e1,$fb,$3b
	db $00,$00,$00,$00,$3f,$3f,$bf,$b8
	db $00,$00,$00,$00,$3f,$3f,$bf,$b8
	db $00,$00,$00,$00,$f8,$f8,$f8,$00
	db $00,$00,$00,$00,$f8,$f8,$f8,$00
	db $00,$00,$00,$00,$00,$00,$28,$00
	db $00,$00,$00,$00,$00,$00,$20,$03
	db $00,$00,$00,$00,$00,$08,$00,$f8
	db $00,$00,$00,$40,$00,$08,$00,$07
	db $00,$00,$00,$00,$08,$00,$77,$3f
	db $00,$00,$00,$40,$00,$00,$08,$c4
	db $00,$0a,$01,$00,$0b,$07,$fe,$0e
	db $00,$08,$00,$20,$00,$00,$03,$f1
	db $00,$20,$88,$f4,$fc,$0c,$66,$06
	db $00,$00,$08,$00,$00,$f0,$f8,$f8
	db $00,$00,$20,$00,$00,$00,$00,$00
	db $00,$00,$20,$00,$00,$00,$00,$00
	db $3f,$3f,$00,$00,$00,$00,$00,$00
	db $3f,$3f,$1f,$00,$3f,$3f,$3f,$00
	db $e3,$e3,$00,$00,$00,$00,$00,$00
	db $e3,$e3,$fb,$3b,$fb,$fb,$e3,$00
	db $83,$83,$00,$00,$00,$00,$00,$00
	db $83,$83,$ff,$fe,$80,$80,$80,$00
	db $b8,$b8,$00,$00,$00,$00,$00,$00
	db $b8,$b8,$bf,$3f,$38,$38,$38,$00
	db $3b,$3b,$00,$00,$00,$00,$00,$00
	db $3b,$3b,$fb,$fb,$3b,$3b,$39,$00
	db $80,$80,$00,$00,$00,$00,$00,$00
	db $80,$80,$80,$83,$ff,$ff,$fe,$00
	db $3f,$3f,$00,$00,$00,$00,$00,$00
	db $3f,$3f,$3f,$b8,$bf,$bf,$3f,$00
	db $e0,$e0,$00,$00,$00,$00,$00,$00
	db $e0,$e0,$e0,$00,$f8,$f8,$f8,$00
	db $86,$3f,$00,$00,$00,$00,$00,$00
	db $79,$00,$00,$04,$00,$00,$00,$00
	db $47,$ff,$1c,$40,$04,$20,$00,$00
	db $fc,$00,$00,$00,$00,$20,$00,$00
	db $a0,$ff,$3c,$00,$40,$10,$00,$00
	db $7f,$00,$00,$00,$42,$00,$00,$00
	db $74,$fe,$47,$03,$20,$01,$14,$00
	db $af,$01,$00,$08,$00,$02,$10,$00
	db $16,$46,$0c,$fc,$f0,$28,$40,$00
	db $f8,$f8,$f0,$00,$00,$20,$00,$00
	db $00,$00,$00,$00,$20,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$0f,$08,$08,$08,$08
	db $00,$00,$00,$0f,$0f,$0f,$0f,$0f
	db $00,$00,$00,$ff,$00,$00,$00,$00
	db $00,$00,$00,$ff,$ff,$ff,$ff,$ff
	db $00,$00,$00,$9f,$50,$50,$50,$50
	db $00,$00,$00,$9f,$df,$df,$df,$df
	db $00,$00,$00,$80,$80,$80,$80,$80
	db $00,$00,$00,$80,$80,$80,$80,$80
	db $00,$00,$00,$7f,$80,$80,$80,$80
	db $00,$00,$00,$7f,$ff,$ff,$ff,$ff
	db $00,$00,$00,$fc,$02,$02,$02,$02
	db $00,$00,$00,$fc,$fe,$fe,$fe,$fe
	db $00,$00,$00,$fb,$0a,$0a,$0a,$0a
	db $00,$00,$00,$fb,$fb,$fb,$fb,$fb
	db $00,$00,$00,$f3,$12,$12,$12,$12
	db $00,$00,$00,$f3,$f3,$f3,$f3,$f3
	db $00,$00,$00,$f0,$10,$10,$10,$10
	db $00,$00,$00,$f0,$f0,$f0,$f0,$f0
	db $08,$08,$08,$08,$08,$08,$08,$08
	db $0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f
	db $70,$88,$88,$88,$88,$88,$70,$00
	db $ff,$8f,$8f,$8f,$8f,$8f,$ff,$ff
	db $50,$50,$50,$50,$50,$50,$50,$97
	db $df,$df,$df,$df,$df,$df,$df,$98
	db $80,$80,$80,$80,$80,$80,$80,$80
	db $80,$80,$80,$80,$80,$80,$80,$80
	db $80,$80,$83,$84,$84,$84,$84,$fc
	db $ff,$ff,$ff,$fc,$fc,$fc,$fc,$84
	db $02,$02,$82,$42,$42,$42,$42,$7e
	db $fe,$fe,$fe,$7e,$7e,$7e,$7e,$42
	db $80,$80,$83,$84,$84,$83,$80,$ff
	db $ff,$ff,$ff,$fc,$fc,$ff,$ff,$80
	db $0a,$0a,$fb,$00,$00,$f0,$08,$e8
	db $fb,$fb,$fb,$00,$00,$f0,$f8,$18
	db $00,$00,$c0,$21,$21,$21,$21,$21
	db $ff,$ff,$ff,$3f,$3f,$3f,$3f,$3f
	db $12,$12,$f2,$02,$02,$02,$02,$02
	db $f3,$f3,$f3,$03,$03,$03,$03,$03
	db $10,$10,$10,$10,$10,$10,$10,$10
	db $f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0
	db $08,$0f,$0f,$0f,$0f,$0f,$0f,$0f
	db $0f,$08,$08,$08,$08,$08,$08,$08
	db $1f,$ff,$ff,$8f,$8f,$8f,$8f,$8f
	db $e0,$00,$70,$88,$88,$88,$88,$88
	db $9f,$9f,$9f,$df,$df,$df,$df,$df
	db $90,$90,$90,$50,$50,$50,$50,$50
	db $80,$80,$80,$80,$80,$80,$fe,$fe
	db $80,$80,$80,$80,$80,$80,$7e,$02
	db $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
	db $83,$80,$80,$80,$80,$80,$80,$83
	db $fe,$fe,$fe,$fe,$fe,$fe,$fe,$fe
	db $82,$02,$02,$02,$02,$02,$02,$82
	db $ff,$ff,$ff,$ff,$7f,$01,$ff,$ff
	db $80,$80,$80,$80,$7e,$01,$fe,$80
	db $f8,$f8,$f8,$f8,$f8,$f8,$f8,$f8
	db $08,$08,$08,$08,$08,$08,$08,$08
	db $3f,$3f,$3f,$3f,$3f,$3f,$3f,$3f
	db $21,$21,$21,$21,$21,$21,$21,$21
	db $02,$03,$03,$03,$03,$03,$00,$00
	db $03,$02,$02,$02,$02,$03,$00,$00
	db $10,$f0,$f0,$f0,$f0,$f0,$00,$00
	db $f0,$10,$10,$10,$10,$f0,$00,$00
	db $0f,$0f,$0f,$0f,$0f,$0f,$00,$00
	db $08,$08,$08,$08,$08,$0f,$00,$00
	db $ff,$ff,$ff,$ff,$ff,$ff,$00,$00
	db $70,$00,$00,$00,$00,$ff,$00,$00
	db $df,$df,$df,$df,$df,$9f,$00,$00
	db $50,$50,$50,$50,$50,$9f,$00,$00
	db $fe,$fe,$fe,$fe,$fe,$fe,$00,$00
	db $02,$02,$02,$02,$02,$fe,$00,$00
	db $fc,$fc,$fc,$fc,$fc,$fc,$00,$00
	db $84,$84,$84,$84,$84,$fc,$00,$00
	db $7e,$7e,$7e,$7e,$7e,$7e,$00,$00
	db $42,$42,$42,$42,$42,$7e,$00,$00
	db $ff,$ff,$ff,$ff,$ff,$ff,$00,$00
	db $80,$80,$80,$80,$80,$ff,$00,$00
	db $f8,$f8,$f8,$f8,$f8,$f0,$00,$00
	db $08,$08,$08,$08,$08,$f0,$00,$00
	db $3f,$3f,$3f,$3f,$3f,$3f,$00,$00
	db $21,$21,$21,$21,$21,$3f,$00,$00
	db $03,$03,$03,$03,$03,$03,$00,$00
	db $03,$02,$02,$02,$02,$03,$00,$00
	db $f0,$f0,$f0,$f0,$f0,$f0,$00,$00
	db $f0,$10,$10,$10,$10,$f0,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$18,$3c,$3c,$18,$00,$00,$00
	db $00,$18,$3c,$3c,$18,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $38,$4c,$c6,$c6,$c6,$64,$38,$00
	db $38,$4c,$c6,$c6,$c6,$64,$38,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $18,$18,$18,$18,$18,$18,$7e,$00
	db $18,$18,$18,$18,$18,$18,$7e,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $7c,$c6,$0e,$3c,$78,$e0,$fe,$00
	db $7c,$c6,$0e,$3c,$78,$e0,$fe,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $7e,$0c,$18,$3c,$06,$c6,$7c,$00
	db $7e,$0c,$18,$3c,$06,$c6,$7c,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $1c,$3c,$6c,$cc,$fe,$0c,$0c,$00
	db $1c,$3c,$6c,$cc,$fe,$0c,$0c,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $fc,$c0,$fc,$06,$06,$c6,$7c,$00
	db $fc,$c0,$fc,$06,$06,$c6,$7c,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $3c,$60,$c0,$fc,$c6,$c6,$7c,$00
	db $3c,$60,$c0,$fc,$c6,$c6,$7c,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $fe,$c6,$0c,$18,$30,$30,$30,$00
	db $fe,$c6,$0c,$18,$30,$30,$30,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $7c,$c6,$c6,$7c,$c6,$c6,$7c,$00
	db $7c,$c6,$c6,$7c,$c6,$c6,$7c,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $7c,$c6,$c6,$7e,$06,$0c,$78,$00
	db $7c,$c6,$c6,$7e,$06,$0c,$78,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $7f,$ff,$c1,$cf,$c9,$cd,$c1,$7f
	db $7f,$ff,$c1,$cf,$c9,$cd,$c1,$7f
	db $ff,$ff,$81,$9d,$81,$9d,$9d,$ff
	db $ff,$ff,$81,$9d,$81,$9d,$9d,$ff
	db $ff,$ff,$9d,$89,$95,$9d,$9d,$ff
	db $ff,$ff,$9d,$89,$95,$9d,$9d,$ff
	db $ff,$ff,$83,$9f,$83,$9f,$83,$ff
	db $ff,$ff,$83,$9f,$83,$9f,$83,$ff
	db $ff,$ff,$81,$9d,$9d,$9d,$81,$ff
	db $ff,$ff,$81,$9d,$9d,$9d,$81,$ff
	db $ff,$ff,$9d,$9d,$9b,$cb,$c7,$ff
	db $ff,$ff,$9d,$9d,$9b,$cb,$c7,$ff
	db $ff,$ff,$81,$9f,$81,$9f,$81,$ff
	db $ff,$ff,$81,$9f,$81,$9f,$81,$ff
	db $fe,$ff,$83,$9d,$83,$97,$9b,$fe
	db $fe,$ff,$83,$9d,$83,$97,$9b,$fe
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $02,$65,$50,$52,$65,$55,$55,$62
	db $02,$65,$50,$52,$65,$55,$55,$62
	db $00,$00,$00,$45,$65,$55,$55,$52
	db $00,$00,$00,$45,$65,$55,$55,$52
	db $00,$00,$06,$76,$42,$32,$10,$62
	db $00,$00,$06,$76,$42,$32,$10,$62
	db $00,$00,$18,$18,$08,$08,$08,$1c
	db $00,$00,$18,$18,$08,$08,$08,$1c
	db $00,$00,$ac,$aa,$aa,$ac,$a8,$48
	db $00,$00,$ac,$aa,$aa,$ac,$a8,$48
	db $30,$38,$3c,$3e,$3e,$3c,$38,$30
	db $30,$38,$3c,$3e,$3e,$3c,$38,$30
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$01,$04,$01,$01
	db $00,$00,$00,$00,$02,$00,$04,$00
	db $00,$00,$00,$00,$40,$aa,$d5,$82
	db $00,$00,$00,$00,$a0,$d4,$aa,$81
	db $00,$00,$00,$00,$10,$30,$30,$70
	db $00,$00,$00,$00,$10,$10,$10,$10
	db $00,$00,$00,$8c,$de,$e1,$e1,$e1
	db $00,$00,$00,$0c,$1e,$5e,$1e,$5e
	db $00,$00,$03,$07,$8f,$8f,$86,$86
	db $00,$00,$03,$07,$0f,$0b,$81,$03
	db $00,$00,$c0,$e0,$f1,$f1,$61,$61
	db $00,$00,$c0,$e0,$f0,$d0,$81,$c0
	db $00,$00,$00,$31,$7b,$87,$87,$87
	db $00,$00,$00,$30,$78,$7a,$78,$7a
	db $00,$00,$00,$00,$08,$0c,$0c,$0e
	db $00,$00,$00,$00,$08,$08,$08,$08
	db $00,$00,$00,$00,$02,$55,$ab,$41
	db $00,$00,$00,$00,$05,$2b,$55,$81
	db $00,$00,$00,$00,$80,$20,$80,$80
	db $00,$00,$00,$00,$40,$00,$20,$00
	db $01,$03,$00,$03,$02,$00,$08,$0f
	db $02,$00,$03,$04,$05,$00,$07,$0b
	db $00,$20,$50,$28,$16,$0e,$18,$30
	db $00,$00,$40,$20,$10,$0d,$17,$0f
	db $30,$18,$0e,$16,$28,$50,$20,$00
	db $0f,$17,$0d,$10,$20,$40,$00,$00
	db $00,$04,$0a,$14,$68,$70,$18,$0c
	db $00,$00,$02,$04,$08,$b0,$e8,$f0
	db $0c,$18,$70,$68,$14,$0a,$04,$00
	db $f0,$e8,$b0,$08,$04,$02,$00,$00
	db $80,$87,$4c,$c8,$c4,$0c,$2c,$e8
	db $80,$80,$c3,$40,$43,$07,$c3,$a0
	db $00,$80,$c0,$55,$81,$cb,$c3,$57
	db $00,$00,$00,$08,$00,$90,$00,$00
	db $60,$e0,$e0,$e5,$c0,$ca,$c0,$d5
	db $20,$20,$20,$2a,$40,$55,$40,$4a
	db $e1,$ff,$41,$1c,$22,$63,$63,$63
	db $5e,$00,$00,$00,$1c,$1c,$3e,$1c
	db $00,$01,$02,$06,$02,$05,$07,$0c
	db $00,$00,$01,$01,$07,$02,$00,$03
	db $19,$27,$6d,$7f,$75,$23,$c0,$00
	db $06,$1c,$12,$03,$0a,$65,$00,$00
	db $00,$80,$40,$60,$c0,$a0,$e0,$30
	db $00,$00,$80,$80,$e0,$40,$00,$c0
	db $98,$e4,$b6,$fe,$ae,$c4,$03,$00
	db $60,$38,$48,$c0,$50,$a6,$00,$00
	db $00,$00,$00,$00,$08,$00,$00,$42
	db $00,$00,$18,$18,$18,$00,$00,$00
	db $00,$00,$18,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$18,$00,$00,$00,$00,$00,$00
	db $00,$01,$02,$06,$02,$05,$07,$0c
	db $00,$00,$01,$01,$07,$02,$00,$03
	db $19,$27,$6d,$7c,$77,$24,$c1,$00
	db $06,$1c,$12,$03,$08,$61,$00,$00
	db $00,$80,$40,$60,$40,$a0,$e0,$30
	db $00,$00,$80,$80,$e0,$40,$00,$c0
	db $98,$e4,$b6,$3e,$ee,$24,$83,$00
	db $60,$38,$48,$c0,$10,$86,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$42
	db $00,$00,$18,$18,$18,$00,$00,$00
	db $00,$00,$18,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$5a,$00,$00,$00
	db $00,$18,$00,$3c,$24,$5a,$18,$00
	db $00,$01,$02,$06,$02,$05,$07,$0c
	db $00,$00,$01,$01,$07,$02,$00,$03
	db $19,$27,$6d,$7f,$75,$21,$c1,$00
	db $06,$1c,$12,$03,$0a,$65,$03,$01
	db $00,$80,$40,$60,$c0,$a0,$e0,$30
	db $00,$00,$80,$80,$e0,$40,$00,$c0
	db $98,$e4,$b6,$fe,$ae,$84,$83,$00
	db $60,$38,$48,$c0,$50,$a6,$c0,$80
	db $00,$00,$00,$00,$08,$00,$00,$42
	db $00,$00,$18,$18,$18,$00,$00,$00
	db $00,$00,$18,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$18,$00,$00,$00,$00,$24,$18
	db $00,$01,$02,$06,$02,$05,$07,$0c
	db $00,$00,$01,$01,$07,$02,$00,$03
	db $19,$27,$6d,$7c,$77,$24,$c0,$00
	db $06,$1c,$12,$03,$08,$61,$01,$01
	db $00,$80,$40,$60,$40,$a0,$e0,$30
	db $00,$00,$80,$80,$e0,$40,$00,$c0
	db $98,$e4,$b6,$3e,$ee,$24,$03,$00
	db $60,$38,$48,$c0,$10,$86,$80,$80
	db $00,$00,$00,$00,$00,$00,$00,$42
	db $00,$00,$18,$18,$18,$00,$00,$00
	db $00,$00,$18,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$5a,$00,$00,$00
	db $00,$18,$00,$3c,$24,$5a,$18,$18
	db $00,$01,$02,$06,$02,$05,$07,$0c
	db $00,$00,$01,$01,$07,$02,$00,$03
	db $19,$27,$6d,$7f,$75,$21,$c1,$00
	db $06,$1c,$12,$03,$0a,$65,$03,$01
	db $00,$80,$40,$60,$c0,$a0,$e0,$30
	db $00,$00,$80,$80,$e0,$40,$00,$c0
	db $98,$e4,$b6,$fe,$ae,$84,$83,$00
	db $60,$38,$48,$c0,$50,$a6,$c0,$80
	db $00,$00,$00,$00,$08,$00,$00,$42
	db $00,$00,$18,$18,$18,$00,$00,$00
	db $00,$00,$18,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$18,$00,$00,$00,$00,$24,$18
	db $00,$01,$02,$06,$02,$05,$07,$19
	db $00,$00,$01,$01,$05,$02,$00,$06
	db $21,$63,$75,$7b,$2f,$c6,$01,$00
	db $1e,$1c,$0a,$06,$60,$01,$00,$00
	db $00,$80,$00,$40,$a0,$e0,$e0,$60
	db $00,$00,$80,$80,$c0,$00,$00,$80
	db $90,$68,$ee,$fc,$fc,$6a,$84,$00
	db $60,$90,$30,$88,$00,$84,$02,$00
	db $00,$00,$00,$00,$28,$00,$40,$06
	db $00,$00,$18,$18,$18,$00,$00,$00
	db $00,$14,$08,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$5e,$62,$00,$00
	db $00,$08,$00,$14,$20,$1c,$18,$00
	db $00,$01,$00,$07,$05,$06,$0f,$22
	db $00,$00,$01,$00,$03,$01,$00,$1d
	db $66,$5f,$7f,$35,$c1,$03,$00,$00
	db $1d,$20,$10,$6a,$06,$01,$00,$00
	db $00,$80,$00,$40,$a0,$e0,$c0,$a0
	db $00,$00,$80,$80,$c0,$00,$00,$40
	db $e0,$f0,$d8,$50,$f8,$ac,$0c,$00
	db $00,$00,$20,$e8,$00,$d0,$00,$00
	db $00,$00,$00,$00,$08,$00,$40,$00
	db $00,$00,$18,$08,$08,$00,$00,$00
	db $00,$0a,$04,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$04,$00,$00,$00,$00,$00,$00
	db $00,$01,$01,$07,$05,$06,$0f,$22
	db $00,$00,$00,$00,$02,$01,$00,$1d
	db $66,$5f,$7f,$35,$c1,$03,$00,$00
	db $1d,$20,$10,$6a,$06,$01,$00,$00
	db $00,$80,$00,$40,$a0,$e0,$c0,$a0
	db $00,$00,$80,$80,$c0,$00,$00,$40
	db $e0,$f0,$d8,$50,$f8,$ac,$0c,$00
	db $00,$00,$20,$e8,$00,$d0,$00,$00
	db $00,$00,$00,$00,$08,$00,$40,$00
	db $00,$00,$18,$08,$08,$00,$00,$00
	db $00,$0a,$04,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$04,$00,$00,$00,$00,$00,$00
	db $00,$01,$00,$07,$05,$06,$0f,$22
	db $00,$00,$01,$00,$02,$01,$00,$1d
	db $66,$5f,$7f,$37,$c7,$02,$01,$00
	db $1d,$20,$10,$68,$00,$01,$00,$00
	db $00,$80,$00,$40,$a0,$e0,$c0,$a0
	db $00,$00,$80,$80,$c0,$00,$00,$40
	db $e0,$f0,$d8,$90,$f8,$6c,$8c,$00
	db $00,$00,$20,$68,$00,$90,$00,$00
	db $00,$00,$00,$00,$08,$00,$40,$00
	db $00,$00,$18,$08,$08,$00,$00,$00
	db $00,$0a,$04,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$1e,$20,$00,$00
	db $00,$04,$00,$2c,$60,$1c,$18,$00
	db $00,$01,$01,$07,$05,$06,$0f,$22
	db $00,$00,$00,$00,$02,$01,$00,$1d
	db $66,$5f,$7f,$35,$c1,$03,$01,$00
	db $1d,$20,$10,$6a,$06,$01,$03,$01
	db $00,$80,$00,$40,$a0,$e0,$c0,$a0
	db $00,$00,$80,$80,$c0,$00,$00,$40
	db $e0,$f0,$d8,$50,$f8,$ec,$8c,$00
	db $00,$00,$20,$e8,$00,$90,$c0,$80
	db $00,$00,$00,$00,$08,$00,$40,$00
	db $00,$00,$18,$08,$08,$00,$00,$00
	db $00,$0a,$04,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$04,$00,$00,$00,$04,$24,$18
	db $00,$01,$00,$07,$05,$06,$0f,$22
	db $00,$00,$01,$00,$02,$01,$00,$1d
	db $66,$5f,$7f,$37,$c7,$00,$00,$00
	db $1d,$20,$10,$68,$00,$01,$01,$01
	db $00,$80,$00,$40,$a0,$e0,$c0,$a0
	db $00,$00,$80,$80,$c0,$00,$00,$40
	db $e0,$f0,$d8,$90,$f8,$2c,$0c,$00
	db $00,$00,$20,$68,$00,$90,$80,$80
	db $00,$00,$00,$00,$08,$00,$40,$00
	db $00,$00,$18,$08,$08,$00,$00,$00
	db $00,$0a,$04,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$1e,$00,$00,$00
	db $00,$04,$00,$2c,$60,$18,$18,$18
	db $00,$18,$10,$31,$31,$31,$29,$21
	db $00,$00,$08,$4a,$4a,$4a,$42,$42
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$08,$4a,$4a,$4a,$4a,$00
	db $00,$08,$5a,$7b,$7b,$7b,$7b,$42
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$01,$0d,$1d,$3d,$39,$39
	db $00,$01,$01,$0c,$1c,$3d,$3f,$1d
	db $39,$3d,$3f,$3d,$3d,$1c,$0c,$04
	db $1d,$1d,$1d,$3d,$3d,$1c,$0c,$04
	db $00,$00,$c0,$d0,$f8,$bc,$fc,$bc
	db $00,$c0,$c0,$d0,$f8,$bc,$3c,$3c
	db $fc,$cc,$cc,$cc,$0c,$0c,$38,$30
	db $fc,$dc,$7c,$5c,$1c,$1c,$38,$30
	db $00,$00,$01,$05,$0f,$1e,$1f,$1e
	db $00,$01,$01,$05,$0f,$1e,$1e,$0e
	db $1f,$19,$19,$19,$18,$08,$0e,$06
	db $0f,$0d,$0f,$1d,$1c,$0c,$0e,$06
	db $00,$00,$c0,$f0,$f8,$b8,$d8,$98
	db $00,$c0,$c0,$f0,$f8,$b8,$38,$38
	db $d8,$f8,$f8,$f8,$38,$38,$30,$20
	db $f8,$f8,$78,$78,$38,$38,$30,$20
	db $00,$00,$00,$01,$01,$01,$03,$03
	db $00,$00,$00,$01,$01,$01,$03,$02
	db $03,$03,$03,$03,$03,$01,$01,$00
	db $02,$02,$02,$02,$03,$01,$01,$00
	db $00,$00,$e0,$e0,$e0,$e0,$e0,$e0
	db $80,$80,$e0,$60,$e0,$e0,$a0,$a0
	db $e0,$e0,$60,$60,$00,$00,$80,$80
	db $e0,$e0,$a0,$e0,$80,$80,$80,$80
	db $00,$10,$34,$66,$08,$17,$06,$04
	db $00,$08,$08,$18,$07,$20,$10,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$04,$62,$20,$23,$1e,$04
	db $00,$18,$38,$14,$0b,$14,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $08,$10,$00,$40,$80,$01,$02,$04
	db $00,$08,$24,$0a,$19,$22,$14,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$10,$20,$40,$18,$03,$12,$04
	db $00,$08,$1c,$26,$1b,$34,$06,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $3c,$7e,$ff,$ff,$ff,$ff,$7e,$3c
	db $00,$00,$18,$3c,$3c,$18,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $3c,$7e,$ff,$ff,$ff,$ff,$7e,$3c
	db $3c,$7e,$ff,$ff,$ff,$ff,$7e,$3c
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$c2,$c2,$c6,$c6,$04
	db $18,$3b,$77,$bd,$bd,$b9,$b9,$7b
	db $01,$01,$01,$01,$00,$00,$00,$00
	db $7e,$26,$26,$73,$71,$39,$38,$10
	db $00,$00,$00,$43,$43,$63,$63,$20
	db $18,$dc,$ee,$bd,$bd,$9d,$9d,$de
	db $80,$80,$c0,$80,$00,$00,$00,$00
	db $7e,$64,$24,$ce,$8e,$9c,$1c,$08
	db $00,$80,$c0,$e1,$e1,$e1,$e1,$ff
	db $00,$00,$00,$5e,$1e,$5e,$5e,$00
	db $41,$1c,$22,$63,$63,$63,$22,$1c
	db $00,$00,$1c,$1c,$3e,$1c,$1c,$00
	db $00,$00,$80,$84,$86,$86,$96,$17
	db $00,$00,$00,$00,$81,$03,$01,$02
	db $b6,$b8,$bb,$5a,$5b,$5b,$da,$1a
	db $00,$00,$08,$00,$0a,$00,$08,$01
	db $00,$00,$01,$21,$61,$61,$69,$e8
	db $00,$00,$00,$00,$81,$c0,$80,$40
	db $6d,$1d,$dd,$5a,$da,$da,$5b,$58
	db $00,$00,$10,$00,$50,$00,$10,$80
	db $00,$01,$03,$87,$87,$87,$87,$ff
	db $00,$00,$00,$7a,$78,$7a,$7a,$00
	db $82,$38,$44,$c6,$c6,$c6,$44,$38
	db $00,$00,$38,$38,$7c,$38,$38,$00
	db $3e,$3e,$1c,$00,$00,$00,$01,$03
	db $1c,$1c,$00,$00,$00,$00,$00,$00
	db $03,$02,$02,$02,$02,$07,$07,$03
	db $00,$01,$01,$01,$01,$01,$03,$00
	db $ce,$e7,$f1,$fa,$79,$fb,$da,$c2
	db $01,$80,$42,$21,$12,$09,$03,$01
	db $67,$ae,$2a,$a1,$23,$f2,$f0,$e0
	db $81,$c3,$c1,$c3,$c2,$c0,$e0,$00
	db $73,$e7,$8f,$5f,$9e,$df,$5b,$43
	db $80,$01,$42,$84,$48,$90,$c0,$80
	db $e6,$75,$54,$85,$c4,$4f,$0f,$07
	db $81,$c3,$83,$c3,$43,$03,$07,$00
	db $7c,$7c,$38,$00,$00,$00,$80,$c0
	db $38,$38,$00,$00,$00,$00,$00,$00
	db $c0,$40,$40,$40,$40,$e0,$e0,$c0
	db $00,$80,$80,$80,$80,$80,$c0,$00
	db $00,$8c,$de,$e1,$e1,$e1,$e1,$ff
	db $00,$0c,$1e,$5e,$1e,$5e,$5e,$00
	db $41,$1c,$22,$63,$63,$63,$22,$1c
	db $00,$00,$1c,$1c,$3e,$1c,$1c,$00
	db $03,$07,$8f,$8f,$86,$86,$96,$17
	db $03,$07,$0f,$0b,$81,$03,$01,$02
	db $b6,$b8,$bb,$5a,$5b,$5b,$da,$1a
	db $00,$00,$08,$00,$0a,$00,$08,$01
	db $c0,$e0,$f1,$f1,$61,$61,$69,$e8
	db $c0,$e0,$f0,$d0,$81,$c0,$80,$40
	db $6d,$1d,$dd,$5a,$da,$da,$5b,$58
	db $00,$00,$10,$00,$50,$00,$10,$80
	db $00,$31,$7b,$87,$87,$87,$87,$ff
	db $00,$30,$78,$7a,$78,$7a,$7a,$00
	db $82,$38,$44,$c6,$c6,$c6,$44,$38
	db $00,$00,$38,$38,$7c,$38,$38,$00
	db $3e,$3e,$1c,$00,$00,$00,$01,$03
	db $1c,$1c,$00,$00,$00,$00,$00,$00
	db $03,$02,$02,$02,$02,$07,$07,$03
	db $00,$01,$01,$01,$01,$01,$03,$00
	db $ce,$e7,$f1,$fa,$79,$fb,$da,$c2
	db $01,$80,$42,$21,$12,$09,$03,$01
	db $67,$ae,$2a,$a1,$23,$f2,$f0,$e0
	db $81,$c3,$c1,$c3,$c2,$c0,$e0,$00
	db $73,$e7,$8f,$5f,$9e,$df,$5b,$43
	db $80,$01,$42,$84,$48,$90,$c0,$80
	db $e6,$75,$54,$85,$c4,$4f,$0f,$07
	db $81,$c3,$83,$c3,$43,$03,$07,$00
	db $7c,$7c,$38,$00,$00,$00,$80,$c0
	db $38,$38,$00,$00,$00,$00,$00,$00
	db $c0,$40,$40,$40,$40,$e0,$e0,$c0
	db $00,$80,$80,$80,$80,$80,$c0,$00
	db $08,$10,$08,$10,$08,$10,$08,$10
	db $3c,$18,$3c,$18,$3c,$18,$3c,$18
	db $08,$10,$08,$10,$08,$10,$08,$10
	db $3c,$18,$3c,$18,$3c,$18,$3c,$18
	db $08,$10,$08,$10,$08,$10,$08,$10
	db $3c,$18,$3c,$18,$3c,$18,$3c,$18
	db $08,$10,$08,$10,$08,$10,$08,$10
	db $3c,$18,$3c,$18,$3c,$18,$3c,$18
	db $18,$18,$18,$18,$18,$18,$18,$18
	db $3c,$3c,$3c,$3c,$3c,$3c,$3c,$3c
	db $18,$18,$18,$18,$18,$18,$18,$18
	db $3c,$3c,$3c,$3c,$3c,$3c,$3c,$3c
	db $18,$18,$18,$18,$18,$18,$18,$18
	db $3c,$3c,$3c,$3c,$3c,$3c,$3c,$3c
	db $18,$18,$18,$18,$18,$18,$18,$18
	db $3c,$3c,$3c,$3c,$3c,$3c,$3c,$3c
	db $96,$17,$b6,$b8,$bb,$56,$4d,$5b
	db $01,$02,$00,$10,$00,$01,$43,$07
	db $69,$e8,$6d,$1d,$dd,$6a,$b2,$da
	db $80,$40,$00,$08,$00,$80,$c2,$e0
	db $87,$ff,$82,$38,$44,$c6,$c6,$c6
	db $7a,$00,$00,$00,$38,$38,$7c,$38
	db $06,$07,$07,$a7,$03,$53,$03,$ab
	db $04,$04,$04,$54,$02,$aa,$02,$52
	db $00,$01,$03,$aa,$81,$d3,$c3,$ea
	db $00,$00,$00,$10,$00,$09,$00,$00
	db $01,$e1,$32,$13,$23,$30,$34,$17
	db $01,$01,$c3,$02,$c2,$e0,$c3,$05
	db $80,$c0,$00,$c0,$40,$00,$10,$f0
	db $40,$00,$c0,$20,$a0,$00,$e0,$d0
	db $00,$08,$0f,$0a,$1f,$1e,$1d,$00
	db $00,$07,$00,$05,$00,$01,$02,$00
	db $04,$4c,$cc,$cc,$cc,$47,$c0,$40
	db $03,$c7,$43,$47,$43,$c0,$40,$40
	db $85,$cf,$cf,$db,$df,$8f,$00,$71
	db $00,$80,$00,$80,$01,$01,$10,$0f
	db $80,$c6,$ef,$f0,$70,$70,$70,$7f
	db $80,$86,$8f,$af,$0f,$2f,$2f,$00
	db $22,$1c,$7e,$fe,$dc,$c0,$de,$94
	db $1c,$00,$1c,$1c,$40,$00,$00,$08
	db $db,$1d,$ce,$e7,$f1,$fa,$79,$fb
	db $47,$03,$01,$80,$42,$21,$12,$09
	db $db,$b8,$73,$e7,$8f,$5f,$9e,$df
	db $e2,$c0,$80,$01,$42,$84,$48,$90
	db $44,$38,$7e,$7f,$3b,$03,$7b,$29
	db $38,$00,$38,$38,$02,$00,$00,$10
	db $01,$63,$f7,$0f,$0e,$0e,$0e,$fe
	db $01,$61,$f1,$f5,$f0,$f4,$f4,$00
	db $a1,$f3,$f3,$db,$fb,$f1,$00,$8e
	db $00,$01,$00,$01,$80,$80,$08,$f0
	db $20,$32,$33,$33,$33,$e2,$03,$02
	db $c0,$e3,$c2,$e2,$c2,$03,$02,$02
	db $00,$10,$f0,$50,$f8,$78,$b8,$00
	db $00,$e0,$00,$a0,$00,$80,$40,$00
	db $1a,$3b,$1b,$3b,$1b,$3b,$77,$6e
	db $01,$08,$28,$08,$28,$00,$00,$01
	db $c0,$e0,$e0,$60,$e1,$e3,$22,$e3
	db $40,$20,$20,$a1,$20,$20,$e1,$24
	db $5f,$d7,$f7,$7f,$3d,$9f,$c0,$e0
	db $21,$29,$08,$00,$80,$40,$20,$1f
	db $20,$0e,$91,$b1,$b1,$b1,$11,$8e
	db $00,$00,$8e,$8e,$9f,$8e,$0e,$80
	db $d9,$43,$5b,$82,$ba,$aa,$32,$77
	db $00,$18,$00,$19,$01,$11,$01,$01
	db $da,$c2,$67,$ae,$2a,$a1,$23,$f2
	db $03,$01,$81,$c3,$c1,$c3,$c2,$c1
	db $5b,$43,$e6,$75,$54,$85,$c4,$4f
	db $c0,$80,$81,$c3,$83,$c3,$43,$83
	db $9b,$c2,$da,$41,$5d,$55,$4c,$ee
	db $00,$18,$00,$98,$80,$88,$80,$80
	db $04,$70,$89,$8d,$8d,$8d,$88,$71
	db $00,$00,$71,$71,$f9,$71,$70,$01
	db $fa,$eb,$ef,$fe,$bc,$f9,$03,$07
	db $84,$94,$10,$00,$01,$02,$04,$f8
	db $03,$07,$07,$06,$87,$c7,$44,$c7
	db $02,$04,$04,$85,$04,$04,$87,$24
	db $58,$dc,$d8,$dc,$d8,$dc,$ee,$76
	db $80,$10,$14,$10,$14,$00,$00,$80
	db $5b,$37,$3d,$1b,$00,$1f,$3e,$5d
	db $04,$08,$02,$04,$00,$00,$01,$23
	db $e5,$66,$e7,$43,$01,$e0,$f0,$70
	db $22,$a1,$20,$80,$00,$20,$10,$90
	db $bb,$fb,$6b,$bb,$db,$eb,$73,$33
	db $44,$04,$94,$44,$24,$14,$0c,$04
	db $9f,$9f,$ce,$c0,$e0,$60,$e0,$70
	db $8e,$8e,$40,$40,$20,$a0,$20,$90
	db $07,$63,$00,$50,$28,$14,$0a,$05
	db $63,$00,$70,$28,$34,$0a,$0d,$02
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$18,$3c,$3c,$3c,$3c,$18,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$18,$18,$18,$18,$18,$18,$00
	db $00,$18,$3c,$3c,$3c,$3c,$18,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $f1,$e2,$01,$02,$01,$02,$01,$02
	db $e1,$01,$00,$01,$01,$01,$00,$81
	db $8f,$47,$80,$40,$80,$40,$80,$40
	db $87,$80,$00,$80,$80,$80,$00,$81
	db $e0,$c6,$00,$0a,$14,$28,$50,$a0
	db $c6,$00,$0e,$14,$2c,$50,$b0,$40
	db $f9,$f9,$73,$03,$07,$06,$07,$0e
	db $71,$71,$02,$02,$04,$05,$04,$09
	db $dd,$df,$d6,$dd,$db,$d7,$ce,$cc
	db $22,$20,$29,$22,$24,$28,$30,$20
	db $a7,$66,$e7,$c2,$80,$07,$0f,$0e
	db $44,$85,$04,$01,$00,$04,$08,$09
	db $da,$ec,$bc,$d8,$00,$f8,$7c,$ba
	db $20,$10,$40,$20,$00,$00,$80,$c4
	db $6d,$76,$7b,$3d,$1e,$0f,$07,$03
	db $13,$09,$04,$02,$11,$08,$00,$00
	db $78,$f8,$fc,$dc,$fe,$7e,$b7,$bf
	db $88,$08,$04,$24,$02,$82,$49,$41
	db $01,$06,$07,$03,$01,$00,$00,$00
	db $02,$01,$00,$00,$00,$00,$00,$00
	db $f0,$f8,$78,$b8,$dc,$ec,$74,$3e
	db $10,$08,$88,$48,$24,$14,$0c,$02
	db $02,$03,$03,$03,$03,$03,$01,$01
	db $03,$02,$03,$03,$03,$03,$01,$01
	db $81,$40,$80,$40,$80,$40,$c0,$c0
	db $01,$80,$40,$80,$40,$80,$80,$c0
	db $81,$02,$01,$02,$01,$02,$03,$03
	db $80,$01,$02,$01,$02,$01,$01,$03
	db $40,$c0,$c0,$c0,$c0,$c0,$80,$80
	db $c0,$40,$c0,$c0,$c0,$c0,$80,$80
	db $0f,$1f,$1e,$1d,$3b,$37,$2e,$7c
	db $08,$10,$11,$12,$24,$28,$30,$40
	db $80,$60,$e0,$c0,$80,$00,$00,$00
	db $40,$80,$00,$00,$00,$00,$00,$00
	db $1e,$1f,$3f,$3b,$7f,$7e,$ed,$fd
	db $11,$10,$20,$24,$40,$41,$92,$82
	db $b6,$6e,$de,$bc,$78,$f0,$e0,$c0
	db $c8,$90,$20,$40,$88,$10,$00,$00
	db $01,$00,$00,$00,$00,$00,$00,$00
	db $01,$00,$00,$00,$00,$00,$00,$00
	db $df,$ed,$77,$3b,$1d,$0e,$07,$02
	db $20,$92,$08,$04,$12,$09,$00,$01
	db $80,$80,$c0,$c0,$e0,$a0,$70,$f0
	db $80,$80,$40,$40,$20,$60,$90,$10
	db $1e,$0f,$07,$03,$01,$00,$00,$00
	db $02,$01,$01,$00,$00,$00,$00,$00
	db $00,$00,$00,$80,$80,$c0,$40,$00
	db $00,$00,$00,$80,$80,$40,$40,$00
	db $c0,$40,$00,$00,$00,$00,$00,$00
	db $c0,$40,$00,$00,$00,$00,$00,$00
	db $03,$02,$00,$00,$00,$00,$00,$00
	db $03,$02,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$01,$01,$03,$02,$00
	db $00,$00,$00,$01,$01,$02,$02,$00
	db $78,$f0,$e0,$c0,$80,$00,$00,$00
	db $40,$80,$80,$00,$00,$00,$00,$00
	db $01,$01,$03,$03,$07,$05,$0e,$0f
	db $01,$01,$02,$02,$04,$06,$09,$08
	db $fb,$b7,$ee,$dc,$b8,$70,$e0,$40
	db $04,$49,$10,$20,$48,$90,$00,$80
	db $80,$00,$00,$00,$00,$00,$00,$00
	db $80,$00,$00,$00,$00,$00,$00,$00
	db $01,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $f8,$d8,$7c,$3c,$16,$0e,$07,$03
	db $08,$a8,$44,$04,$0a,$02,$01,$01
	db $1f,$1b,$3e,$3c,$68,$70,$e0,$c0
	db $10,$15,$22,$20,$50,$40,$80,$80
	db $80,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $20,$20,$20,$20,$20,$00,$20,$00
	db $20,$20,$20,$20,$20,$00,$20,$00
	db $50,$50,$50,$00,$00,$00,$00,$00
	db $50,$50,$50,$00,$00,$00,$00,$00
	db $50,$50,$f8,$50,$f8,$50,$50,$00
	db $50,$50,$f8,$50,$f8,$50,$50,$00
	db $20,$78,$a0,$70,$28,$f0,$20,$00
	db $20,$78,$a0,$70,$28,$f0,$20,$00
	db $c0,$c8,$10,$20,$40,$98,$18,$00
	db $c0,$c8,$10,$20,$40,$98,$18,$00
	db $40,$a0,$40,$a0,$a8,$90,$68,$00
	db $40,$a0,$40,$a0,$a8,$90,$68,$00
	db $60,$20,$40,$00,$00,$00,$00,$00
	db $60,$20,$40,$00,$00,$00,$00,$00
	db $10,$20,$40,$40,$40,$20,$10,$00
	db $10,$20,$40,$40,$40,$20,$10,$00
	db $40,$20,$10,$10,$10,$20,$40,$00
	db $40,$20,$10,$10,$10,$20,$40,$00
	db $00,$a8,$70,$20,$70,$a8,$00,$00
	db $00,$a8,$70,$20,$70,$a8,$00,$00
	db $00,$20,$20,$f8,$20,$20,$00,$00
	db $00,$20,$20,$f8,$20,$20,$00,$00
	db $00,$00,$00,$00,$00,$60,$20,$40
	db $00,$00,$00,$00,$00,$60,$20,$40
	db $00,$00,$00,$fc,$00,$00,$00,$00
	db $00,$00,$00,$fc,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$60,$00
	db $00,$00,$00,$00,$00,$00,$60,$00
	db $00,$08,$10,$20,$40,$80,$00,$00
	db $00,$08,$10,$20,$40,$80,$00,$00
	db $70,$88,$98,$a8,$c8,$88,$70,$00
	db $70,$88,$98,$a8,$c8,$88,$70,$00
	db $20,$60,$20,$20,$20,$20,$f8,$00
	db $20,$60,$20,$20,$20,$20,$f8,$00
	db $70,$88,$08,$10,$60,$80,$f8,$00
	db $70,$88,$08,$10,$60,$80,$f8,$00
	db $70,$88,$08,$30,$08,$88,$70,$00
	db $70,$88,$08,$30,$08,$88,$70,$00
	db $30,$50,$90,$90,$f8,$10,$10,$00
	db $30,$50,$90,$90,$f8,$10,$10,$00
	db $f8,$80,$f0,$08,$08,$08,$f0,$00
	db $f8,$80,$f0,$08,$08,$08,$f0,$00
	db $30,$40,$80,$f0,$88,$88,$70,$00
	db $30,$40,$80,$f0,$88,$88,$70,$00
	db $f8,$08,$10,$20,$20,$20,$20,$00
	db $f8,$08,$10,$20,$20,$20,$20,$00
	db $70,$88,$88,$70,$88,$88,$70,$00
	db $70,$88,$88,$70,$88,$88,$70,$00
	db $70,$88,$88,$78,$08,$10,$60,$00
	db $70,$88,$88,$78,$08,$10,$60,$00
	db $00,$00,$00,$60,$00,$60,$00,$00
	db $00,$00,$00,$60,$00,$60,$00,$00
	db $00,$00,$00,$60,$00,$60,$20,$40
	db $00,$00,$00,$60,$00,$60,$20,$40
	db $10,$20,$40,$80,$40,$20,$10,$00
	db $10,$20,$40,$80,$40,$20,$10,$00
	db $00,$00,$f8,$00,$f8,$00,$00,$00
	db $00,$00,$f8,$00,$f8,$00,$00,$00
	db $08,$04,$02,$01,$02,$04,$08,$00
	db $08,$04,$02,$01,$02,$04,$08,$00
	db $70,$88,$08,$10,$20,$00,$20,$00
	db $70,$88,$08,$10,$20,$00,$20,$00
	db $70,$88,$98,$a8,$98,$80,$70,$00
	db $70,$88,$98,$a8,$98,$80,$70,$00
	db $20,$50,$88,$88,$f8,$88,$88,$00
	db $20,$50,$88,$88,$f8,$88,$88,$00
	db $f0,$88,$88,$f0,$88,$88,$f0,$00
	db $f0,$88,$88,$f0,$88,$88,$f0,$00
	db $70,$88,$80,$80,$80,$88,$70,$00
	db $70,$88,$80,$80,$80,$88,$70,$00
	db $f0,$88,$88,$88,$88,$88,$f0,$00
	db $f0,$88,$88,$88,$88,$88,$f0,$00
	db $f8,$80,$80,$f0,$80,$80,$f8,$00
	db $f8,$80,$80,$f0,$80,$80,$f8,$00
	db $f8,$80,$80,$f0,$80,$80,$80,$00
	db $f8,$80,$80,$f0,$80,$80,$80,$00
	db $70,$88,$80,$b8,$88,$88,$70,$00
	db $70,$88,$80,$b8,$88,$88,$70,$00
	db $88,$88,$88,$f8,$88,$88,$88,$00
	db $88,$88,$88,$f8,$88,$88,$88,$00
	db $70,$20,$20,$20,$20,$20,$70,$00
	db $70,$20,$20,$20,$20,$20,$70,$00
	db $08,$08,$08,$08,$88,$88,$70,$00
	db $08,$08,$08,$08,$88,$88,$70,$00
	db $88,$90,$a0,$c0,$a0,$90,$88,$00
	db $88,$90,$a0,$c0,$a0,$90,$88,$00
	db $80,$80,$80,$80,$80,$80,$f8,$00
	db $80,$80,$80,$80,$80,$80,$f8,$00
	db $88,$d8,$a8,$a8,$88,$88,$88,$00
	db $88,$d8,$a8,$a8,$88,$88,$88,$00
	db $88,$c8,$c8,$a8,$98,$98,$88,$00
	db $88,$c8,$c8,$a8,$98,$98,$88,$00
	db $70,$88,$88,$88,$88,$88,$70,$00
	db $70,$88,$88,$88,$88,$88,$70,$00
	db $f0,$88,$88,$f0,$80,$80,$80,$00
	db $f0,$88,$88,$f0,$80,$80,$80,$00
	db $70,$88,$88,$88,$88,$a8,$90,$68
	db $70,$88,$88,$88,$88,$a8,$90,$68
	db $f0,$88,$88,$f0,$a0,$90,$88,$00
	db $f0,$88,$88,$f0,$a0,$90,$88,$00
	db $70,$88,$80,$70,$08,$88,$70,$00
	db $70,$88,$80,$70,$08,$88,$70,$00
	db $f8,$20,$20,$20,$20,$20,$20,$00
	db $f8,$20,$20,$20,$20,$20,$20,$00
	db $88,$88,$88,$88,$88,$88,$70,$00
	db $88,$88,$88,$88,$88,$88,$70,$00
	db $88,$88,$88,$88,$50,$50,$20,$00
	db $88,$88,$88,$88,$50,$50,$20,$00
	db $88,$88,$88,$a8,$a8,$d8,$88,$00
	db $88,$88,$88,$a8,$a8,$d8,$88,$00
	db $88,$88,$50,$20,$50,$88,$88,$00
	db $88,$88,$50,$20,$50,$88,$88,$00
	db $88,$88,$88,$70,$20,$20,$20,$00
	db $88,$88,$88,$70,$20,$20,$20,$00
	db $f8,$08,$10,$20,$40,$80,$f8,$00
	db $f8,$08,$10,$20,$40,$80,$f8,$00
	db $78,$60,$60,$60,$60,$60,$78,$00
	db $78,$60,$60,$60,$60,$60,$78,$00
	db $00,$80,$40,$20,$10,$08,$00,$00
	db $00,$80,$40,$20,$10,$08,$00,$00
	db $f0,$30,$30,$30,$30,$30,$f0,$00
	db $f0,$30,$30,$30,$30,$30,$f0,$00
	db $20,$50,$88,$00,$00,$00,$00,$00
	db $20,$50,$88,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$f8,$00
	db $00,$00,$00,$00,$00,$00,$f8,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$1f,$30,$08,$08,$08
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$ff,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$80,$f0,$0c,$02,$7d
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $08,$08,$08,$10,$10,$20,$20,$40
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $13,$16,$00,$00,$03,$04,$00,$0f
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $fc,$02,$02,$02,$e1,$1d,$63,$80
	db $00,$00,$00,$00,$03,$03,$07,$07
	db $00,$00,$01,$00,$03,$03,$07,$07
	db $00,$00,$00,$00,$ff,$ff,$ff,$ff
	db $00,$00,$ff,$00,$ff,$ff,$ff,$ff
	db $00,$00,$00,$00,$f7,$e7,$ef,$ef
	db $01,$06,$f8,$00,$f7,$e7,$ef,$ef
	db $00,$00,$00,$00,$f0,$f1,$f1,$f1
	db $80,$00,$00,$00,$f0,$f1,$f1,$f1
	db $00,$00,$00,$00,$00,$c3,$c3,$c3
	db $00,$00,$00,$00,$00,$c3,$c3,$c3
	db $00,$00,$00,$00,$00,$f0,$f9,$bb
	db $01,$00,$00,$00,$00,$f0,$f9,$bb
	db $00,$00,$00,$00,$3c,$ff,$ff,$ff
	db $00,$e0,$1f,$00,$3c,$ff,$ff,$ff
	db $00,$00,$00,$00,$00,$8f,$cf,$ef
	db $00,$00,$ff,$00,$00,$8f,$cf,$ef
	db $00,$00,$00,$00,$00,$c7,$e3,$f3
	db $00,$00,$ff,$00,$00,$c7,$e3,$f3
	db $00,$00,$00,$00,$00,$c0,$e0,$e0
	db $00,$00,$00,$00,$00,$c0,$e0,$e0
	db $0f,$0f,$1f,$1f,$1f,$3f,$3f,$7f
	db $0f,$0f,$1f,$1f,$1f,$3f,$3f,$7f
	db $c0,$c0,$c0,$80,$80,$80,$00,$fe
	db $c0,$c0,$c0,$80,$80,$80,$00,$fe
	db $0f,$1f,$1f,$3f,$3f,$3f,$7f,$7f
	db $0f,$1f,$1f,$3f,$3f,$3f,$7f,$7f
	db $f1,$f1,$f3,$f3,$f3,$f3,$f3,$f3
	db $f1,$f1,$f3,$f3,$f3,$f3,$f3,$f3
	db $c3,$c3,$c3,$c3,$c3,$c3,$c3,$c3
	db $c3,$c3,$c3,$c3,$c3,$c3,$c3,$c3
	db $bb,$bb,$bb,$b9,$b9,$b9,$81,$81
	db $bb,$bb,$bb,$b9,$b9,$b9,$81,$81
	db $f3,$f3,$f3,$f3,$f9,$f9,$f9,$f9
	db $f3,$f3,$f3,$f3,$f9,$f9,$f9,$f9
	db $e7,$f7,$f7,$f3,$f3,$fb,$fb,$f9
	db $e7,$f7,$f7,$f3,$f3,$fb,$fb,$f9
	db $f9,$f9,$fd,$fc,$fe,$ff,$ff,$ff
	db $f9,$f9,$fd,$fc,$fe,$ff,$ff,$ff
	db $e0,$f0,$f0,$f8,$f8,$7c,$7c,$fe
	db $e0,$f0,$f0,$f8,$f8,$7c,$7c,$fe
	db $00,$00,$00,$01,$01,$03,$03,$07
	db $00,$00,$00,$01,$01,$03,$03,$07
	db $7f,$ff,$ff,$fe,$fc,$fc,$f8,$f8
	db $7f,$ff,$ff,$fe,$fc,$fc,$f8,$f8
	db $fc,$fc,$fc,$01,$01,$03,$00,$00
	db $fc,$fc,$fc,$01,$01,$03,$03,$03
	db $fd,$fd,$fd,$f9,$f0,$80,$00,$00
	db $fd,$fd,$fd,$f9,$f9,$f9,$ff,$ff
	db $f3,$f3,$f0,$00,$00,$00,$00,$00
	db $f3,$f3,$f3,$f3,$f3,$f3,$f3,$f3
	db $c3,$c3,$00,$00,$00,$00,$00,$00
	db $c3,$c3,$c3,$c3,$c3,$c3,$c3,$c3
	db $81,$81,$00,$00,$00,$00,$00,$00
	db $81,$81,$bd,$bd,$bd,$bc,$bc,$bc
	db $f9,$f8,$0c,$00,$00,$00,$00,$00
	db $f9,$f8,$fc,$fc,$fc,$fc,$fc,$fe
	db $fd,$fd,$fc,$3c,$02,$00,$00,$00
	db $fd,$fd,$fc,$fc,$fe,$fe,$7e,$7f
	db $ff,$ff,$fb,$f9,$fd,$fd,$0c,$00
	db $ff,$ff,$fb,$f9,$fd,$fd,$7c,$7e
	db $fe,$ff,$ff,$ff,$ff,$ff,$ff,$ff
	db $fe,$ff,$ff,$ff,$ff,$ff,$ff,$ff
	db $00,$00,$00,$80,$80,$c0,$c0,$c0
	db $00,$00,$00,$80,$80,$c0,$c0,$c0
	db $07,$07,$0f,$0f,$1e,$1c,$30,$00
	db $07,$07,$0f,$0f,$1f,$1f,$3f,$3f
	db $f0,$f0,$f0,$c0,$00,$00,$00,$00
	db $f0,$f0,$f0,$e0,$e0,$c0,$c0,$c0
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $07,$07,$0f,$0f,$0f,$1f,$1f,$3f
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $ff,$ff,$ff,$e3,$e3,$c3,$c3,$c3
	db $00,$00,$00,$00,$00,$00,$00,$1f
	db $f3,$f3,$f3,$f3,$f3,$e0,$c0,$9f
	db $00,$00,$00,$00,$00,$00,$00,$1e
	db $c3,$fb,$fb,$fb,$f9,$00,$00,$1e
	db $00,$00,$00,$00,$00,$00,$00,$7d
	db $bc,$bc,$fc,$fc,$f0,$00,$00,$7d
	db $00,$00,$00,$00,$00,$00,$00,$f8
	db $fe,$fe,$fe,$fe,$fe,$03,$03,$f9
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $7f,$7f,$7f,$3f,$3f,$3f,$3f,$3f
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $7e,$7e,$3f,$bf,$bf,$9f,$9f,$df
	db $7f,$0f,$03,$00,$00,$00,$00,$00
	db $7f,$7f,$3f,$1f,$1f,$8f,$8f,$87
	db $e0,$e0,$f0,$f0,$38,$08,$04,$00
	db $e0,$e0,$f0,$f0,$f8,$f8,$fc,$fc
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$01,$01,$03
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $7f,$7f,$ff,$ff,$fe,$fe,$fe,$fc
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $80,$80,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $3f,$3f,$7f,$7f,$ff,$ff,$07,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $c3,$83,$83,$83,$03,$03,$03,$00
	db $3f,$3f,$3b,$77,$77,$7b,$38,$3c
	db $3f,$3f,$3b,$77,$77,$7b,$38,$3c
	db $3f,$3f,$77,$77,$77,$77,$77,$77
	db $3f,$3f,$77,$77,$77,$77,$77,$77
	db $7d,$7d,$70,$70,$70,$70,$70,$70
	db $7d,$7d,$70,$70,$70,$70,$70,$70
	db $f8,$e0,$f0,$70,$70,$70,$70,$70
	db $f9,$e1,$f1,$77,$77,$73,$73,$70
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $3f,$ff,$ff,$ff,$ff,$ff,$fe,$f8
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $df,$cf,$cf,$cf,$87,$87,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $c3,$c3,$c1,$e1,$e0,$f0,$30,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $fe,$fe,$ff,$ff,$ff,$ff,$7f,$7f
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$80,$80,$c0
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $03,$07,$06,$08,$03,$0c,$10,$20
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $f8,$c3,$1c,$e0,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $1f,$e0,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $ff,$01,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$c0,$30,$08,$00,$00,$00,$00
	db $1c,$1e,$ee,$e8,$e0,$c0,$80,$00
	db $1c,$1e,$ee,$ef,$ef,$e7,$ef,$ef
	db $70,$00,$00,$00,$00,$00,$00,$00
	db $77,$77,$77,$77,$77,$77,$77,$77
	db $06,$00,$00,$00,$00,$00,$00,$00
	db $76,$7e,$7e,$78,$70,$70,$70,$70
	db $70,$70,$70,$18,$08,$00,$00,$00
	db $70,$70,$70,$78,$78,$78,$78,$38
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$03,$0c,$10,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $ff,$80,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $f8,$07,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $0f,$c1,$38,$07,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $c0,$e0,$20,$10,$c0,$20,$18,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $ef,$7f,$3f,$1e,$00,$00,$c0,$30
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $77,$77,$77,$77,$77,$7f,$3f,$3f
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $70,$70,$70,$70,$70,$70,$70,$70
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $38,$38,$30,$20,$00,$08,$30,$c0
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $0c,$02,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $0f,$06,$40,$3f,$0f,$02,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $61,$02,$10,$e0,$80,$00,$00,$00
	db $38,$6c,$c6,$c6,$fe,$c6,$c6,$00
	db $38,$6c,$c6,$c6,$fe,$c6,$c6,$00
	db $fe,$c0,$c0,$fc,$c0,$c0,$fe,$00
	db $fe,$c0,$c0,$fc,$c0,$c0,$fe,$00
	db $c6,$e6,$f6,$fe,$de,$ce,$c6,$00
	db $c6,$e6,$f6,$fe,$de,$ce,$c6,$00
	db $fc,$c6,$c6,$c6,$fc,$c0,$c0,$00
	db $fc,$c6,$c6,$c6,$fc,$c0,$c0,$00
	db $fc,$c6,$c6,$ce,$f8,$dc,$ce,$00
	db $fc,$c6,$c6,$ce,$f8,$dc,$ce,$00
	db $78,$cc,$c0,$7c,$06,$c6,$7c,$00
	db $78,$cc,$c0,$7c,$06,$c6,$7c,$00
	db $7e,$18,$18,$18,$18,$18,$18,$00
	db $7e,$18,$18,$18,$18,$18,$18,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $1c,$1c,$1c,$18,$18,$00,$18,$18
	db $1c,$1c,$1c,$18,$18,$00,$18,$18
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
	db $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$08,$10,$00
	db $00,$00,$00,$00,$00,$08,$10,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$24,$18,$18,$24,$00
	db $00,$00,$00,$24,$18,$18,$24,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$18,$18,$08
	db $00,$00,$00,$00,$00,$18,$18,$08
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $38,$4c,$c6,$c6,$c6,$64,$38,$00
	db $38,$4c,$c6,$c6,$c6,$64,$38,$00
	db $18,$18,$18,$18,$18,$18,$7e,$00
	db $18,$18,$18,$18,$18,$18,$7e,$00
	db $7c,$c6,$0e,$3c,$78,$e0,$fe,$00
	db $7c,$c6,$0e,$3c,$78,$e0,$fe,$00
	db $7e,$0c,$18,$3c,$06,$c6,$7c,$00
	db $7e,$0c,$18,$3c,$06,$c6,$7c,$00
	db $1c,$3c,$6c,$cc,$fe,$0c,$0c,$00
	db $1c,$3c,$6c,$cc,$fe,$0c,$0c,$00
	db $fc,$c0,$fc,$06,$06,$c6,$7c,$00
	db $fc,$c0,$fc,$06,$06,$c6,$7c,$00
	db $3c,$60,$c0,$fc,$c6,$c6,$7c,$00
	db $3c,$60,$c0,$fc,$c6,$c6,$7c,$00
	db $fe,$c6,$0c,$18,$30,$30,$30,$00
	db $fe,$c6,$0c,$18,$30,$30,$30,$00
	db $7c,$c6,$c6,$7c,$c6,$c6,$7c,$00
	db $7c,$c6,$c6,$7c,$c6,$c6,$7c,$00
	db $7c,$c6,$c6,$7e,$06,$0c,$78,$00
	db $7c,$c6,$c6,$7e,$06,$0c,$78,$00
	db $18,$18,$00,$00,$18,$18,$00,$00
	db $18,$18,$00,$00,$18,$18,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $10,$30,$70,$ff,$ff,$70,$30,$10
	db $10,$30,$70,$ff,$ff,$70,$30,$10
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $3c,$66,$66,$06,$18,$00,$18,$18
	db $3c,$66,$66,$06,$18,$00,$18,$18
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $38,$6c,$c6,$c6,$fe,$c6,$c6,$00
	db $38,$6c,$c6,$c6,$fe,$c6,$c6,$00
	db $fc,$c6,$c6,$fc,$c6,$c6,$fc,$00
	db $fc,$c6,$c6,$fc,$c6,$c6,$fc,$00
	db $3c,$66,$c0,$c0,$c0,$66,$3c,$00
	db $3c,$66,$c0,$c0,$c0,$66,$3c,$00
	db $f8,$cc,$c6,$c6,$c6,$cc,$f8,$00
	db $f8,$cc,$c6,$c6,$c6,$cc,$f8,$00
	db $fe,$c0,$c0,$fc,$c0,$c0,$fe,$00
	db $fe,$c0,$c0,$fc,$c0,$c0,$fe,$00
	db $fe,$c0,$c0,$fc,$c0,$c0,$c0,$00
	db $fe,$c0,$c0,$fc,$c0,$c0,$c0,$00
	db $3e,$60,$c0,$ce,$c6,$66,$3e,$00
	db $3e,$60,$c0,$ce,$c6,$66,$3e,$00
	db $c6,$c6,$c6,$fe,$c6,$c6,$c6,$00
	db $c6,$c6,$c6,$fe,$c6,$c6,$c6,$00
	db $7e,$18,$18,$18,$18,$18,$7e,$00
	db $7e,$18,$18,$18,$18,$18,$7e,$00
	db $1e,$06,$06,$06,$c6,$c6,$7c,$00
	db $1e,$06,$06,$06,$c6,$c6,$7c,$00
	db $c6,$cc,$d8,$f0,$f8,$dc,$ce,$00
	db $c6,$cc,$d8,$f0,$f8,$dc,$ce,$00
	db $60,$60,$60,$60,$60,$60,$7e,$00
	db $60,$60,$60,$60,$60,$60,$7e,$00
	db $c6,$ee,$fe,$fe,$d6,$c6,$c6,$00
	db $c6,$ee,$fe,$fe,$d6,$c6,$c6,$00
	db $c6,$e6,$f6,$fe,$de,$ce,$c6,$00
	db $c6,$e6,$f6,$fe,$de,$ce,$c6,$00
	db $7c,$c6,$c6,$c6,$c6,$c6,$7c,$00
	db $7c,$c6,$c6,$c6,$c6,$c6,$7c,$00
	db $fc,$c6,$c6,$c6,$fc,$c0,$c0,$00
	db $fc,$c6,$c6,$c6,$fc,$c0,$c0,$00
	db $7c,$c6,$c6,$c6,$de,$cc,$7a,$00
	db $7c,$c6,$c6,$c6,$de,$cc,$7a,$00
	db $fc,$c6,$c6,$ce,$f8,$dc,$ce,$00
	db $fc,$c6,$c6,$ce,$f8,$dc,$ce,$00
	db $78,$cc,$c0,$7c,$06,$c6,$7c,$00
	db $78,$cc,$c0,$7c,$06,$c6,$7c,$00
	db $7e,$18,$18,$18,$18,$18,$18,$00
	db $7e,$18,$18,$18,$18,$18,$18,$00
	db $c6,$c6,$c6,$c6,$c6,$c6,$7c,$00
	db $c6,$c6,$c6,$c6,$c6,$c6,$7c,$00
	db $c6,$c6,$c6,$ee,$7c,$38,$10,$00
	db $c6,$c6,$c6,$ee,$7c,$38,$10,$00
	db $c6,$c6,$d6,$fe,$fe,$ee,$c6,$00
	db $c6,$c6,$d6,$fe,$fe,$ee,$c6,$00
	db $c6,$ee,$7c,$38,$7c,$ee,$c6,$00
	db $c6,$ee,$7c,$38,$7c,$ee,$c6,$00
	db $66,$66,$66,$3c,$18,$18,$18,$00
	db $66,$66,$66,$3c,$18,$18,$18,$00
	db $fe,$0e,$1c,$38,$70,$e0,$fe,$00
	db $fe,$0e,$1c,$38,$70,$e0,$fe,$00
	db $00,$70,$10,$10,$10,$10,$70,$00
	db $00,$70,$10,$10,$10,$10,$70,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $18,$3c,$7e,$ff,$18,$18,$18,$18
	db $18,$3c,$7e,$ff,$18,$18,$18,$18
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $40,$83,$44,$38,$44,$83,$04,$38
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $90,$97,$58,$24,$24,$c3,$22,$12
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $c8,$0f,$08,$04,$cb,$31,$20,$40
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $13,$1c,$d0,$28,$c7,$08,$90,$90
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $3f,$40,$bf,$b0,$af,$ac,$8a,$a9
	db $00,$3f,$7a,$7f,$7f,$5f,$5e,$7c
	db $fc,$02,$fd,$0d,$f5,$35,$51,$95
	db $00,$fc,$ae,$fe,$fe,$fa,$7a,$3e
	db $a9,$aa,$8c,$af,$b0,$bf,$40,$3f
	db $7c,$5e,$5f,$7f,$7f,$7a,$3f,$00
	db $95,$55,$31,$f5,$0d,$fd,$02,$fc
	db $3e,$7a,$fa,$fe,$fe,$ae,$fc,$00
	db $3f,$4a,$bb,$a4,$ac,$a2,$8b,$ad
	db $00,$31,$78,$6a,$60,$51,$44,$60
	db $fc,$02,$bd,$8d,$95,$e5,$51,$d5
	db $00,$fc,$ae,$3e,$9e,$0a,$22,$06
	db $a7,$a2,$86,$a7,$b8,$ab,$43,$3f
	db $70,$50,$51,$70,$61,$62,$3c,$00
	db $9d,$d7,$33,$e5,$cd,$bd,$02,$fc
	db $22,$30,$60,$4e,$1e,$2e,$fc,$00
	db $40,$83,$46,$38,$45,$83,$04,$38
	db $00,$00,$03,$07,$0f,$00,$00,$00
	db $90,$97,$d8,$e4,$e4,$c3,$22,$12
	db $00,$00,$80,$c0,$e0,$00,$00,$00
	db $c9,$09,$0a,$03,$d7,$31,$20,$40
	db $01,$07,$0f,$1f,$3f,$00,$00,$00
	db $93,$dc,$f0,$a8,$f7,$08,$90,$90
	db $80,$c0,$e0,$e0,$f0,$00,$00,$00
	db $40,$83,$44,$38,$45,$83,$07,$3a
	db $00,$00,$00,$00,$01,$03,$03,$03
	db $90,$97,$58,$24,$a4,$63,$f2,$da
	db $00,$00,$00,$00,$80,$e0,$f0,$f8
	db $ce,$0f,$0d,$1c,$db,$31,$25,$63
	db $07,$04,$0f,$1b,$14,$3e,$3f,$7f
	db $7f,$7f,$fd,$be,$f7,$f8,$d2,$f0
	db $ec,$e3,$2f,$d7,$3c,$ff,$7f,$7f
	db $40,$83,$44,$3c,$5e,$9b,$2d,$7f
	db $00,$00,$00,$0c,$1e,$1f,$3b,$67
	db $ce,$8f,$1f,$45,$cf,$7f,$3b,$7f
	db $f7,$f1,$f7,$fb,$34,$ce,$df,$bf
	db $13,$9c,$50,$a8,$c7,$88,$d0,$d0
	db $00,$80,$80,$80,$80,$80,$c0,$40
	db $40,$83,$44,$38,$44,$83,$04,$38
	db $00,$00,$00,$00,$00,$00,$00,$01
	db $90,$97,$58,$24,$24,$c3,$82,$5a
	db $00,$00,$00,$00,$00,$00,$f0,$f8
	db $ca,$09,$04,$06,$cb,$11,$7f,$40
	db $03,$06,$0f,$1b,$14,$3f,$00,$00
	db $17,$3e,$fd,$7f,$df,$76,$fd,$94
	db $ec,$e6,$2f,$d7,$39,$ff,$03,$07
	db $40,$83,$44,$38,$44,$83,$04,$22
	db $00,$00,$00,$00,$00,$00,$00,$1e
	db $c9,$0f,$2e,$07,$4b,$37,$2b,$5e
	db $37,$31,$77,$fb,$b4,$ce,$df,$bf
	db $13,$9c,$d0,$a9,$f3,$e8,$c1,$d3
	db $00,$80,$c3,$e7,$3c,$ff,$7f,$6f
	db $c8,$0f,$08,$64,$fb,$f9,$f8,$e8
	db $00,$00,$00,$e0,$30,$d8,$d8,$b8
	db $90,$97,$59,$27,$26,$c7,$2e,$1a
	db $00,$01,$01,$03,$03,$06,$0d,$1d
	db $c8,$0f,$0f,$04,$cb,$31,$20,$40
	db $00,$03,$07,$00,$00,$00,$00,$00
	db $77,$dc,$ff,$3d,$cf,$08,$90,$90
	db $6c,$e3,$ff,$3f,$0f,$00,$00,$00
	db $d7,$8f,$5d,$3f,$5c,$a3,$85,$3a
	db $ff,$fc,$bb,$c7,$bb,$7c,$fb,$c7
	db $f4,$f7,$d8,$a6,$24,$d3,$22,$17
	db $7f,$e8,$e7,$db,$db,$3c,$dd,$ed
	db $c8,$2f,$fe,$f5,$cb,$31,$20,$40
	db $37,$f0,$ff,$f1,$00,$00,$00,$00
	db $53,$1f,$dd,$ff,$ff,$3f,$9e,$93
	db $ec,$e3,$af,$d7,$78,$37,$1f,$03
	db $7f,$ef,$7f,$3e,$ff,$df,$f5,$ff
	db $bf,$7c,$bb,$c7,$bb,$7c,$fb,$c7
	db $f0,$bf,$fc,$ac,$fc,$f7,$de,$fe
	db $60,$78,$fc,$fc,$fc,$7e,$fe,$fe
	db $ee,$ff,$dd,$7f,$ff,$ff,$f7,$fc
	db $37,$f0,$f7,$fb,$34,$ce,$df,$fc
	db $d3,$fc,$f0,$f8,$f7,$fc,$d0,$90
	db $f0,$f0,$30,$d8,$3c,$fc,$c0,$00
	db $90,$9f,$44,$10,$ff,$c3,$22,$12
	db $0f,$08,$1f,$3f,$00,$00,$00,$00
	db $c8,$0f,$08,$04,$c8,$31,$2f,$40
	db $00,$00,$00,$01,$03,$07,$00,$00
	db $12,$00,$8a,$a8,$d7,$00,$fe,$93
	db $01,$1f,$7f,$d7,$38,$ff,$01,$00
	db $d7,$9e,$4e,$8e,$fc,$82,$04,$18
	db $bf,$7d,$bb,$ff,$03,$07,$3b,$67
	db $1f,$9f,$5f,$b7,$3f,$ff,$2f,$7f
	db $ef,$e8,$a7,$db,$db,$3c,$dd,$ed
	db $8d,$2f,$88,$57,$cf,$bf,$7f,$ff
	db $f7,$f0,$f7,$fb,$34,$cf,$ff,$00
	db $fb,$bf,$fe,$ff,$fb,$ff,$f0,$90
	db $ec,$e3,$2f,$d7,$3f,$e0,$00,$00
	db $f8,$df,$78,$fc,$ee,$ff,$bf,$fe
	db $b8,$7c,$bc,$c4,$be,$7f,$fb,$c7
	db $90,$97,$58,$24,$24,$c3,$a2,$d2
	db $00,$00,$00,$00,$00,$00,$80,$c0
	db $ff,$ff,$df,$ff,$fb,$f7,$ff,$f8
	db $37,$f0,$f7,$fb,$b0,$c7,$78,$00
	db $93,$fc,$f0,$f8,$ff,$f8,$f0,$90
	db $c0,$e0,$30,$d0,$30,$e0,$00,$00
	db $40,$83,$44,$38,$41,$84,$09,$0c
	db $00,$00,$00,$00,$01,$07,$07,$1b
	db $90,$33,$68,$d8,$fc,$76,$7f,$7e
	db $00,$30,$78,$f8,$7c,$bc,$be,$d0
	db $a5,$0c,$59,$ff,$ff,$00,$20,$40
	db $3b,$37,$76,$ff,$00,$00,$00,$00
	db $78,$bc,$dc,$fe,$fc,$00,$90,$90
	db $b0,$78,$f8,$fc,$00,$00,$00,$00
	db $90,$97,$58,$24,$24,$a3,$32,$52
	db $00,$00,$00,$00,$00,$60,$f0,$f0
	db $cc,$0f,$08,$04,$cb,$31,$20,$40
	db $03,$00,$00,$00,$00,$00,$00,$00
	db $ff,$fc,$d0,$28,$c7,$08,$90,$90
	db $f8,$00,$00,$00,$00,$00,$00,$00
	db $c8,$0f,$08,$0c,$9f,$7f,$38,$40
	db $00,$00,$18,$3c,$7e,$38,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $38,$4c,$c6,$c6,$c6,$64,$38,$00
	db $38,$4c,$c6,$c6,$c6,$64,$38,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $18,$18,$18,$18,$18,$18,$7e,$00
	db $18,$18,$18,$18,$18,$18,$7e,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $7c,$c6,$0e,$3c,$78,$e0,$fe,$00
	db $7c,$c6,$0e,$3c,$78,$e0,$fe,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $7e,$0c,$18,$3c,$06,$c6,$7c,$00
	db $7e,$0c,$18,$3c,$06,$c6,$7c,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $1c,$3c,$6c,$cc,$fe,$0c,$0c,$00
	db $1c,$3c,$6c,$cc,$fe,$0c,$0c,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $fc,$c0,$fc,$06,$06,$c6,$7c,$00
	db $fc,$c0,$fc,$06,$06,$c6,$7c,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $3c,$60,$c0,$fc,$c6,$c6,$7c,$00
	db $3c,$60,$c0,$fc,$c6,$c6,$7c,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $fe,$c6,$0c,$18,$30,$30,$30,$00
	db $fe,$c6,$0c,$18,$30,$30,$30,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $7c,$c6,$c6,$7c,$c6,$c6,$7c,$00
	db $7c,$c6,$c6,$7c,$c6,$c6,$7c,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $7c,$c6,$c6,$7e,$06,$0c,$78,$00
	db $7c,$c6,$c6,$7e,$06,$0c,$78,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $7f,$ff,$c1,$cf,$c9,$cd,$c1,$7f
	db $7f,$ff,$c1,$cf,$c9,$cd,$c1,$7f
	db $ff,$ff,$81,$9d,$81,$9d,$9d,$ff
	db $ff,$ff,$81,$9d,$81,$9d,$9d,$ff
	db $ff,$ff,$9d,$89,$95,$9d,$9d,$ff
	db $ff,$ff,$9d,$89,$95,$9d,$9d,$ff
	db $ff,$ff,$83,$9f,$83,$9f,$83,$ff
	db $ff,$ff,$83,$9f,$83,$9f,$83,$ff
	db $ff,$ff,$81,$9d,$9d,$9d,$81,$ff
	db $ff,$ff,$81,$9d,$9d,$9d,$81,$ff
	db $ff,$ff,$9d,$9d,$9b,$cb,$c7,$ff
	db $ff,$ff,$9d,$9d,$9b,$cb,$c7,$ff
	db $ff,$ff,$81,$9f,$81,$9f,$81,$ff
	db $ff,$ff,$81,$9f,$81,$9f,$81,$ff
	db $fe,$ff,$83,$9d,$83,$97,$9b,$fe
	db $fe,$ff,$83,$9d,$83,$97,$9b,$fe
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $02,$65,$50,$52,$65,$55,$55,$62
	db $02,$65,$50,$52,$65,$55,$55,$62
	db $00,$00,$00,$45,$65,$55,$55,$52
	db $00,$00,$00,$45,$65,$55,$55,$52
	db $00,$00,$06,$76,$42,$32,$10,$62
	db $00,$00,$06,$76,$42,$32,$10,$62
	db $00,$00,$18,$18,$08,$08,$08,$1c
	db $00,$00,$18,$18,$08,$08,$08,$1c
	db $00,$00,$ac,$aa,$aa,$ac,$a8,$48
	db $00,$00,$ac,$aa,$aa,$ac,$a8,$48
	db $30,$38,$3c,$3e,$3e,$3c,$38,$30
	db $30,$38,$3c,$3e,$3e,$3c,$38,$30
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$01,$04,$01,$01
	db $00,$00,$00,$00,$02,$00,$04,$00
	db $00,$00,$00,$00,$40,$aa,$d5,$82
	db $00,$00,$00,$00,$a0,$d4,$aa,$81
	db $00,$00,$00,$00,$10,$30,$30,$70
	db $00,$00,$00,$00,$10,$10,$10,$10
	db $00,$00,$00,$8c,$de,$e1,$e1,$e1
	db $00,$00,$00,$0c,$1e,$5e,$1e,$5e
	db $00,$00,$03,$07,$8f,$8f,$86,$86
	db $00,$00,$03,$07,$0f,$0b,$81,$03
	db $00,$00,$c0,$e0,$f1,$f1,$61,$61
	db $00,$00,$c0,$e0,$f0,$d0,$81,$c0
	db $00,$00,$00,$31,$7b,$87,$87,$87
	db $00,$00,$00,$30,$78,$7a,$78,$7a
	db $00,$00,$00,$00,$08,$0c,$0c,$0e
	db $00,$00,$00,$00,$08,$08,$08,$08
	db $00,$00,$00,$00,$02,$55,$ab,$41
	db $00,$00,$00,$00,$05,$2b,$55,$81
	db $00,$00,$00,$00,$80,$20,$80,$80
	db $00,$00,$00,$00,$40,$00,$20,$00
	db $01,$03,$00,$03,$02,$00,$08,$0f
	db $02,$00,$03,$04,$05,$00,$07,$0b
	db $00,$20,$50,$28,$16,$0e,$18,$30
	db $00,$00,$40,$20,$10,$0d,$17,$0f
	db $30,$18,$0e,$16,$28,$50,$20,$00
	db $0f,$17,$0d,$10,$20,$40,$00,$00
	db $00,$04,$0a,$14,$68,$70,$18,$0c
	db $00,$00,$02,$04,$08,$b0,$e8,$f0
	db $0c,$18,$70,$68,$14,$0a,$04,$00
	db $f0,$e8,$b0,$08,$04,$02,$00,$00
	db $80,$87,$4c,$c8,$c4,$0c,$2c,$e8
	db $80,$80,$c3,$40,$43,$07,$c3,$a0
	db $00,$80,$c0,$55,$81,$cb,$c3,$57
	db $00,$00,$00,$08,$00,$90,$00,$00
	db $60,$e0,$e0,$e5,$c0,$ca,$c0,$d5
	db $20,$20,$20,$2a,$40,$55,$40,$4a
	db $e1,$ff,$41,$1c,$22,$63,$63,$63
	db $5e,$00,$00,$00,$1c,$1c,$3e,$1c
	db $00,$01,$02,$06,$02,$05,$07,$0c
	db $00,$00,$01,$01,$07,$02,$00,$03
	db $19,$27,$6d,$7f,$75,$23,$c0,$00
	db $06,$1c,$12,$03,$0a,$65,$00,$00
	db $00,$80,$40,$60,$c0,$a0,$e0,$30
	db $00,$00,$80,$80,$e0,$40,$00,$c0
	db $98,$e4,$b6,$fe,$ae,$c4,$03,$00
	db $60,$38,$48,$c0,$50,$a6,$00,$00
	db $00,$00,$00,$00,$08,$00,$00,$42
	db $00,$00,$18,$18,$18,$00,$00,$00
	db $00,$00,$18,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$18,$00,$00,$00,$00,$00,$00
	db $00,$01,$02,$06,$02,$05,$07,$0c
	db $00,$00,$01,$01,$07,$02,$00,$03
	db $19,$27,$6d,$7c,$77,$24,$c1,$00
	db $06,$1c,$12,$03,$08,$61,$00,$00
	db $00,$80,$40,$60,$40,$a0,$e0,$30
	db $00,$00,$80,$80,$e0,$40,$00,$c0
	db $98,$e4,$b6,$3e,$ee,$24,$83,$00
	db $60,$38,$48,$c0,$10,$86,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$42
	db $00,$00,$18,$18,$18,$00,$00,$00
	db $00,$00,$18,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$5a,$00,$00,$00
	db $00,$18,$00,$3c,$24,$5a,$18,$00
	db $00,$01,$02,$06,$02,$05,$07,$0c
	db $00,$00,$01,$01,$07,$02,$00,$03
	db $19,$27,$6d,$7f,$75,$21,$c1,$00
	db $06,$1c,$12,$03,$0a,$65,$03,$01
	db $00,$80,$40,$60,$c0,$a0,$e0,$30
	db $00,$00,$80,$80,$e0,$40,$00,$c0
	db $98,$e4,$b6,$fe,$ae,$84,$83,$00
	db $60,$38,$48,$c0,$50,$a6,$c0,$80
	db $00,$00,$00,$00,$08,$00,$00,$42
	db $00,$00,$18,$18,$18,$00,$00,$00
	db $00,$00,$18,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$18,$00,$00,$00,$00,$24,$18
	db $00,$01,$02,$06,$02,$05,$07,$0c
	db $00,$00,$01,$01,$07,$02,$00,$03
	db $19,$27,$6d,$7c,$77,$24,$c0,$00
	db $06,$1c,$12,$03,$08,$61,$01,$01
	db $00,$80,$40,$60,$40,$a0,$e0,$30
	db $00,$00,$80,$80,$e0,$40,$00,$c0
	db $98,$e4,$b6,$3e,$ee,$24,$03,$00
	db $60,$38,$48,$c0,$10,$86,$80,$80
	db $00,$00,$00,$00,$00,$00,$00,$42
	db $00,$00,$18,$18,$18,$00,$00,$00
	db $00,$00,$18,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$5a,$00,$00,$00
	db $00,$18,$00,$3c,$24,$5a,$18,$18
	db $00,$01,$02,$06,$02,$05,$07,$0c
	db $00,$00,$01,$01,$07,$02,$00,$03
	db $19,$27,$6d,$7f,$75,$21,$c1,$00
	db $06,$1c,$12,$03,$0a,$65,$03,$01
	db $00,$80,$40,$60,$c0,$a0,$e0,$30
	db $00,$00,$80,$80,$e0,$40,$00,$c0
	db $98,$e4,$b6,$fe,$ae,$84,$83,$00
	db $60,$38,$48,$c0,$50,$a6,$c0,$80
	db $00,$00,$00,$00,$08,$00,$00,$42
	db $00,$00,$18,$18,$18,$00,$00,$00
	db $00,$00,$18,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$18,$00,$00,$00,$00,$24,$18
	db $00,$01,$02,$06,$02,$05,$07,$19
	db $00,$00,$01,$01,$05,$02,$00,$06
	db $21,$63,$75,$7b,$2f,$c6,$01,$00
	db $1e,$1c,$0a,$06,$60,$01,$00,$00
	db $00,$80,$00,$40,$a0,$e0,$e0,$60
	db $00,$00,$80,$80,$c0,$00,$00,$80
	db $90,$68,$ee,$fc,$fc,$6a,$84,$00
	db $60,$90,$30,$88,$00,$84,$02,$00
	db $00,$00,$00,$00,$28,$00,$40,$06
	db $00,$00,$18,$18,$18,$00,$00,$00
	db $00,$14,$08,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$5e,$62,$00,$00
	db $00,$08,$00,$14,$20,$1c,$18,$00
	db $00,$01,$00,$07,$05,$06,$0f,$22
	db $00,$00,$01,$00,$03,$01,$00,$1d
	db $66,$5f,$7f,$35,$c1,$03,$00,$00
	db $1d,$20,$10,$6a,$06,$01,$00,$00
	db $00,$80,$00,$40,$a0,$e0,$c0,$a0
	db $00,$00,$80,$80,$c0,$00,$00,$40
	db $e0,$f0,$d8,$50,$f8,$ac,$0c,$00
	db $00,$00,$20,$e8,$00,$d0,$00,$00
	db $00,$00,$00,$00,$08,$00,$40,$00
	db $00,$00,$18,$08,$08,$00,$00,$00
	db $00,$0a,$04,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$04,$00,$00,$00,$00,$00,$00
	db $00,$01,$01,$07,$05,$06,$0f,$22
	db $00,$00,$00,$00,$02,$01,$00,$1d
	db $66,$5f,$7f,$35,$c1,$03,$00,$00
	db $1d,$20,$10,$6a,$06,$01,$00,$00
	db $00,$80,$00,$40,$a0,$e0,$c0,$a0
	db $00,$00,$80,$80,$c0,$00,$00,$40
	db $e0,$f0,$d8,$50,$f8,$ac,$0c,$00
	db $00,$00,$20,$e8,$00,$d0,$00,$00
	db $00,$00,$00,$00,$08,$00,$40,$00
	db $00,$00,$18,$08,$08,$00,$00,$00
	db $00,$0a,$04,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$04,$00,$00,$00,$00,$00,$00
	db $00,$01,$00,$07,$05,$06,$0f,$22
	db $00,$00,$01,$00,$02,$01,$00,$1d
	db $66,$5f,$7f,$37,$c7,$02,$01,$00
	db $1d,$20,$10,$68,$00,$01,$00,$00
	db $00,$80,$00,$40,$a0,$e0,$c0,$a0
	db $00,$00,$80,$80,$c0,$00,$00,$40
	db $e0,$f0,$d8,$90,$f8,$6c,$8c,$00
	db $00,$00,$20,$68,$00,$90,$00,$00
	db $00,$00,$00,$00,$08,$00,$40,$00
	db $00,$00,$18,$08,$08,$00,$00,$00
	db $00,$0a,$04,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$1e,$20,$00,$00
	db $00,$04,$00,$2c,$60,$1c,$18,$00
	db $00,$01,$01,$07,$05,$06,$0f,$22
	db $00,$00,$00,$00,$02,$01,$00,$1d
	db $66,$5f,$7f,$35,$c1,$03,$01,$00
	db $1d,$20,$10,$6a,$06,$01,$03,$01
	db $00,$80,$00,$40,$a0,$e0,$c0,$a0
	db $00,$00,$80,$80,$c0,$00,$00,$40
	db $e0,$f0,$d8,$50,$f8,$ec,$8c,$00
	db $00,$00,$20,$e8,$00,$90,$c0,$80
	db $00,$00,$00,$00,$08,$00,$40,$00
	db $00,$00,$18,$08,$08,$00,$00,$00
	db $00,$0a,$04,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$04,$00,$00,$00,$04,$24,$18
	db $00,$01,$00,$07,$05,$06,$0f,$22
	db $00,$00,$01,$00,$02,$01,$00,$1d
	db $66,$5f,$7f,$37,$c7,$00,$00,$00
	db $1d,$20,$10,$68,$00,$01,$01,$01
	db $00,$80,$00,$40,$a0,$e0,$c0,$a0
	db $00,$00,$80,$80,$c0,$00,$00,$40
	db $e0,$f0,$d8,$90,$f8,$2c,$0c,$00
	db $00,$00,$20,$68,$00,$90,$80,$80
	db $00,$00,$00,$00,$08,$00,$40,$00
	db $00,$00,$18,$08,$08,$00,$00,$00
	db $00,$0a,$04,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$1e,$00,$00,$00
	db $00,$04,$00,$2c,$60,$18,$18,$18
	db $00,$18,$10,$31,$31,$31,$29,$21
	db $00,$00,$08,$4a,$4a,$4a,$42,$42
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$08,$4a,$4a,$4a,$4a,$00
	db $00,$08,$5a,$7b,$7b,$7b,$7b,$42
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$01,$0d,$1d,$3d,$39,$39
	db $00,$01,$01,$0c,$1c,$3d,$3f,$1d
	db $39,$3d,$3f,$3d,$3d,$1c,$0c,$04
	db $1d,$1d,$1d,$3d,$3d,$1c,$0c,$04
	db $00,$00,$c0,$d0,$f8,$bc,$fc,$bc
	db $00,$c0,$c0,$d0,$f8,$bc,$3c,$3c
	db $fc,$cc,$cc,$cc,$0c,$0c,$38,$30
	db $fc,$dc,$7c,$5c,$1c,$1c,$38,$30
	db $00,$00,$01,$05,$0f,$1e,$1f,$1e
	db $00,$01,$01,$05,$0f,$1e,$1e,$0e
	db $1f,$19,$19,$19,$18,$08,$0e,$06
	db $0f,$0d,$0f,$1d,$1c,$0c,$0e,$06
	db $00,$00,$c0,$f0,$f8,$b8,$d8,$98
	db $00,$c0,$c0,$f0,$f8,$b8,$38,$38
	db $d8,$f8,$f8,$f8,$38,$38,$30,$20
	db $f8,$f8,$78,$78,$38,$38,$30,$20
	db $00,$00,$00,$01,$01,$01,$03,$03
	db $00,$00,$00,$01,$01,$01,$03,$02
	db $03,$03,$03,$03,$03,$01,$01,$00
	db $02,$02,$02,$02,$03,$01,$01,$00
	db $00,$00,$e0,$e0,$e0,$e0,$e0,$e0
	db $80,$80,$e0,$60,$e0,$e0,$a0,$a0
	db $e0,$e0,$60,$60,$00,$00,$80,$80
	db $e0,$e0,$a0,$e0,$80,$80,$80,$80
	db $00,$10,$34,$66,$08,$17,$06,$04
	db $00,$08,$08,$18,$07,$20,$10,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$04,$62,$20,$23,$1e,$04
	db $00,$18,$38,$14,$0b,$14,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $08,$10,$00,$40,$80,$01,$02,$04
	db $00,$08,$24,$0a,$19,$22,$14,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$10,$20,$40,$18,$03,$12,$04
	db $00,$08,$1c,$26,$1b,$34,$06,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $3c,$7e,$ff,$ff,$ff,$ff,$7e,$3c
	db $00,$00,$18,$3c,$3c,$18,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $3c,$7e,$ff,$ff,$ff,$ff,$7e,$3c
	db $3c,$7e,$ff,$ff,$ff,$ff,$7e,$3c
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$c2,$c2,$c6,$c6,$04
	db $18,$3b,$77,$bd,$bd,$b9,$b9,$7b
	db $01,$01,$01,$01,$00,$00,$00,$00
	db $7e,$26,$26,$73,$71,$39,$38,$10
	db $00,$00,$00,$43,$43,$63,$63,$20
	db $18,$dc,$ee,$bd,$bd,$9d,$9d,$de
	db $80,$80,$c0,$80,$00,$00,$00,$00
	db $7e,$64,$24,$ce,$8e,$9c,$1c,$08
	db $00,$80,$c0,$e1,$e1,$e1,$e1,$ff
	db $00,$00,$00,$5e,$1e,$5e,$5e,$00
	db $41,$1c,$22,$63,$63,$63,$22,$1c
	db $00,$00,$1c,$1c,$3e,$1c,$1c,$00
	db $00,$00,$80,$84,$86,$86,$96,$17
	db $00,$00,$00,$00,$81,$03,$01,$02
	db $b6,$b8,$bb,$5a,$5b,$5b,$da,$1a
	db $00,$00,$08,$00,$0a,$00,$08,$01
	db $00,$00,$01,$21,$61,$61,$69,$e8
	db $00,$00,$00,$00,$81,$c0,$80,$40
	db $6d,$1d,$dd,$5a,$da,$da,$5b,$58
	db $00,$00,$10,$00,$50,$00,$10,$80
	db $00,$01,$03,$87,$87,$87,$87,$ff
	db $00,$00,$00,$7a,$78,$7a,$7a,$00
	db $82,$38,$44,$c6,$c6,$c6,$44,$38
	db $00,$00,$38,$38,$7c,$38,$38,$00
	db $3e,$3e,$1c,$00,$00,$00,$01,$03
	db $1c,$1c,$00,$00,$00,$00,$00,$00
	db $03,$02,$02,$02,$02,$07,$07,$03
	db $00,$01,$01,$01,$01,$01,$03,$00
	db $ce,$e7,$f1,$fa,$79,$fb,$da,$c2
	db $01,$80,$42,$21,$12,$09,$03,$01
	db $67,$ae,$2a,$a1,$23,$f2,$f0,$e0
	db $81,$c3,$c1,$c3,$c2,$c0,$e0,$00
	db $73,$e7,$8f,$5f,$9e,$df,$5b,$43
	db $80,$01,$42,$84,$48,$90,$c0,$80
	db $e6,$75,$54,$85,$c4,$4f,$0f,$07
	db $81,$c3,$83,$c3,$43,$03,$07,$00
	db $7c,$7c,$38,$00,$00,$00,$80,$c0
	db $38,$38,$00,$00,$00,$00,$00,$00
	db $c0,$40,$40,$40,$40,$e0,$e0,$c0
	db $00,$80,$80,$80,$80,$80,$c0,$00
	db $00,$8c,$de,$e1,$e1,$e1,$e1,$ff
	db $00,$0c,$1e,$5e,$1e,$5e,$5e,$00
	db $41,$1c,$22,$63,$63,$63,$22,$1c
	db $00,$00,$1c,$1c,$3e,$1c,$1c,$00
	db $03,$07,$8f,$8f,$86,$86,$96,$17
	db $03,$07,$0f,$0b,$81,$03,$01,$02
	db $b6,$b8,$bb,$5a,$5b,$5b,$da,$1a
	db $00,$00,$08,$00,$0a,$00,$08,$01
	db $c0,$e0,$f1,$f1,$61,$61,$69,$e8
	db $c0,$e0,$f0,$d0,$81,$c0,$80,$40
	db $6d,$1d,$dd,$5a,$da,$da,$5b,$58
	db $00,$00,$10,$00,$50,$00,$10,$80
	db $00,$31,$7b,$87,$87,$87,$87,$ff
	db $00,$30,$78,$7a,$78,$7a,$7a,$00
	db $82,$38,$44,$c6,$c6,$c6,$44,$38
	db $00,$00,$38,$38,$7c,$38,$38,$00
	db $3e,$3e,$1c,$00,$00,$00,$01,$03
	db $1c,$1c,$00,$00,$00,$00,$00,$00
	db $03,$02,$02,$02,$02,$07,$07,$03
	db $00,$01,$01,$01,$01,$01,$03,$00
	db $ce,$e7,$f1,$fa,$79,$fb,$da,$c2
	db $01,$80,$42,$21,$12,$09,$03,$01
	db $67,$ae,$2a,$a1,$23,$f2,$f0,$e0
	db $81,$c3,$c1,$c3,$c2,$c0,$e0,$00
	db $73,$e7,$8f,$5f,$9e,$df,$5b,$43
	db $80,$01,$42,$84,$48,$90,$c0,$80
	db $e6,$75,$54,$85,$c4,$4f,$0f,$07
	db $81,$c3,$83,$c3,$43,$03,$07,$00
	db $7c,$7c,$38,$00,$00,$00,$80,$c0
	db $38,$38,$00,$00,$00,$00,$00,$00
	db $c0,$40,$40,$40,$40,$e0,$e0,$c0
	db $00,$80,$80,$80,$80,$80,$c0,$00
	db $08,$10,$08,$10,$08,$10,$08,$10
	db $3c,$18,$3c,$18,$3c,$18,$3c,$18
	db $08,$10,$08,$10,$08,$10,$08,$10
	db $3c,$18,$3c,$18,$3c,$18,$3c,$18
	db $08,$10,$08,$10,$08,$10,$08,$10
	db $3c,$18,$3c,$18,$3c,$18,$3c,$18
	db $08,$10,$08,$10,$08,$10,$08,$10
	db $3c,$18,$3c,$18,$3c,$18,$3c,$18
	db $18,$18,$18,$18,$18,$18,$18,$18
	db $3c,$3c,$3c,$3c,$3c,$3c,$3c,$3c
	db $18,$18,$18,$18,$18,$18,$18,$18
	db $3c,$3c,$3c,$3c,$3c,$3c,$3c,$3c
	db $18,$18,$18,$18,$18,$18,$18,$18
	db $3c,$3c,$3c,$3c,$3c,$3c,$3c,$3c
	db $18,$18,$18,$18,$18,$18,$18,$18
	db $3c,$3c,$3c,$3c,$3c,$3c,$3c,$3c
	db $96,$17,$b6,$b8,$bb,$56,$4d,$5b
	db $01,$02,$00,$10,$00,$01,$43,$07
	db $69,$e8,$6d,$1d,$dd,$6a,$b2,$da
	db $80,$40,$00,$08,$00,$80,$c2,$e0
	db $87,$ff,$82,$38,$44,$c6,$c6,$c6
	db $7a,$00,$00,$00,$38,$38,$7c,$38
	db $06,$07,$07,$a7,$03,$53,$03,$ab
	db $04,$04,$04,$54,$02,$aa,$02,$52
	db $00,$01,$03,$aa,$81,$d3,$c3,$ea
	db $00,$00,$00,$10,$00,$09,$00,$00
	db $01,$e1,$32,$13,$23,$30,$34,$17
	db $01,$01,$c3,$02,$c2,$e0,$c3,$05
	db $80,$c0,$00,$c0,$40,$00,$10,$f0
	db $40,$00,$c0,$20,$a0,$00,$e0,$d0
	db $00,$08,$0f,$0a,$1f,$1e,$1d,$00
	db $00,$07,$00,$05,$00,$01,$02,$00
	db $04,$4c,$cc,$cc,$cc,$47,$c0,$40
	db $03,$c7,$43,$47,$43,$c0,$40,$40
	db $85,$cf,$cf,$db,$df,$8f,$00,$71
	db $00,$80,$00,$80,$01,$01,$10,$0f
	db $80,$c6,$ef,$f0,$70,$70,$70,$7f
	db $80,$86,$8f,$af,$0f,$2f,$2f,$00
	db $22,$1c,$7e,$fe,$dc,$c0,$de,$94
	db $1c,$00,$1c,$1c,$40,$00,$00,$08
	db $db,$1d,$ce,$e7,$f1,$fa,$79,$fb
	db $47,$03,$01,$80,$42,$21,$12,$09
	db $db,$b8,$73,$e7,$8f,$5f,$9e,$df
	db $e2,$c0,$80,$01,$42,$84,$48,$90
	db $44,$38,$7e,$7f,$3b,$03,$7b,$29
	db $38,$00,$38,$38,$02,$00,$00,$10
	db $01,$63,$f7,$0f,$0e,$0e,$0e,$fe
	db $01,$61,$f1,$f5,$f0,$f4,$f4,$00
	db $a1,$f3,$f3,$db,$fb,$f1,$00,$8e
	db $00,$01,$00,$01,$80,$80,$08,$f0
	db $20,$32,$33,$33,$33,$e2,$03,$02
	db $c0,$e3,$c2,$e2,$c2,$03,$02,$02
	db $00,$10,$f0,$50,$f8,$78,$b8,$00
	db $00,$e0,$00,$a0,$00,$80,$40,$00
	db $1a,$3b,$1b,$3b,$1b,$3b,$77,$6e
	db $01,$08,$28,$08,$28,$00,$00,$01
	db $c0,$e0,$e0,$60,$e1,$e3,$22,$e3
	db $40,$20,$20,$a1,$20,$20,$e1,$24
	db $5f,$d7,$f7,$7f,$3d,$9f,$c0,$e0
	db $21,$29,$08,$00,$80,$40,$20,$1f
	db $20,$0e,$91,$b1,$b1,$b1,$11,$8e
	db $00,$00,$8e,$8e,$9f,$8e,$0e,$80
	db $d9,$43,$5b,$82,$ba,$aa,$32,$77
	db $00,$18,$00,$19,$01,$11,$01,$01
	db $da,$c2,$67,$ae,$2a,$a1,$23,$f2
	db $03,$01,$81,$c3,$c1,$c3,$c2,$c1
	db $5b,$43,$e6,$75,$54,$85,$c4,$4f
	db $c0,$80,$81,$c3,$83,$c3,$43,$83
	db $9b,$c2,$da,$41,$5d,$55,$4c,$ee
	db $00,$18,$00,$98,$80,$88,$80,$80
	db $04,$70,$89,$8d,$8d,$8d,$88,$71
	db $00,$00,$71,$71,$f9,$71,$70,$01
	db $fa,$eb,$ef,$fe,$bc,$f9,$03,$07
	db $84,$94,$10,$00,$01,$02,$04,$f8
	db $03,$07,$07,$06,$87,$c7,$44,$c7
	db $02,$04,$04,$85,$04,$04,$87,$24
	db $58,$dc,$d8,$dc,$d8,$dc,$ee,$76
	db $80,$10,$14,$10,$14,$00,$00,$80
	db $5b,$37,$3d,$1b,$00,$1f,$3e,$5d
	db $04,$08,$02,$04,$00,$00,$01,$23
	db $e5,$66,$e7,$43,$01,$e0,$f0,$70
	db $22,$a1,$20,$80,$00,$20,$10,$90
	db $bb,$fb,$6b,$bb,$db,$eb,$73,$33
	db $44,$04,$94,$44,$24,$14,$0c,$04
	db $9f,$9f,$ce,$c0,$e0,$60,$e0,$70
	db $8e,$8e,$40,$40,$20,$a0,$20,$90
	db $07,$63,$00,$50,$28,$14,$0a,$05
	db $63,$00,$70,$28,$34,$0a,$0d,$02
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$18,$3c,$3c,$3c,$3c,$18,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$18,$18,$18,$18,$18,$18,$00
	db $00,$18,$3c,$3c,$3c,$3c,$18,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $f1,$e2,$01,$02,$01,$02,$01,$02
	db $e1,$01,$00,$01,$01,$01,$00,$81
	db $8f,$47,$80,$40,$80,$40,$80,$40
	db $87,$80,$00,$80,$80,$80,$00,$81
	db $e0,$c6,$00,$0a,$14,$28,$50,$a0
	db $c6,$00,$0e,$14,$2c,$50,$b0,$40
	db $f9,$f9,$73,$03,$07,$06,$07,$0e
	db $71,$71,$02,$02,$04,$05,$04,$09
	db $dd,$df,$d6,$dd,$db,$d7,$ce,$cc
	db $22,$20,$29,$22,$24,$28,$30,$20
	db $a7,$66,$e7,$c2,$80,$07,$0f,$0e
	db $44,$85,$04,$01,$00,$04,$08,$09
	db $da,$ec,$bc,$d8,$00,$f8,$7c,$ba
	db $20,$10,$40,$20,$00,$00,$80,$c4
	db $6d,$76,$7b,$3d,$1e,$0f,$07,$03
	db $13,$09,$04,$02,$11,$08,$00,$00
	db $78,$f8,$fc,$dc,$fe,$7e,$b7,$bf
	db $88,$08,$04,$24,$02,$82,$49,$41
	db $01,$06,$07,$03,$01,$00,$00,$00
	db $02,$01,$00,$00,$00,$00,$00,$00
	db $f0,$f8,$78,$b8,$dc,$ec,$74,$3e
	db $10,$08,$88,$48,$24,$14,$0c,$02
	db $02,$03,$03,$03,$03,$03,$01,$01
	db $03,$02,$03,$03,$03,$03,$01,$01
	db $81,$40,$80,$40,$80,$40,$c0,$c0
	db $01,$80,$40,$80,$40,$80,$80,$c0
	db $81,$02,$01,$02,$01,$02,$03,$03
	db $80,$01,$02,$01,$02,$01,$01,$03
	db $40,$c0,$c0,$c0,$c0,$c0,$80,$80
	db $c0,$40,$c0,$c0,$c0,$c0,$80,$80
	db $0f,$1f,$1e,$1d,$3b,$37,$2e,$7c
	db $08,$10,$11,$12,$24,$28,$30,$40
	db $80,$60,$e0,$c0,$80,$00,$00,$00
	db $40,$80,$00,$00,$00,$00,$00,$00
	db $1e,$1f,$3f,$3b,$7f,$7e,$ed,$fd
	db $11,$10,$20,$24,$40,$41,$92,$82
	db $b6,$6e,$de,$bc,$78,$f0,$e0,$c0
	db $c8,$90,$20,$40,$88,$10,$00,$00
	db $01,$00,$00,$00,$00,$00,$00,$00
	db $01,$00,$00,$00,$00,$00,$00,$00
	db $df,$ed,$77,$3b,$1d,$0e,$07,$02
	db $20,$92,$08,$04,$12,$09,$00,$01
	db $80,$80,$c0,$c0,$e0,$a0,$70,$f0
	db $80,$80,$40,$40,$20,$60,$90,$10
	db $1e,$0f,$07,$03,$01,$00,$00,$00
	db $02,$01,$01,$00,$00,$00,$00,$00
	db $00,$00,$00,$80,$80,$c0,$40,$00
	db $00,$00,$00,$80,$80,$40,$40,$00
	db $c0,$40,$00,$00,$00,$00,$00,$00
	db $c0,$40,$00,$00,$00,$00,$00,$00
	db $03,$02,$00,$00,$00,$00,$00,$00
	db $03,$02,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$01,$01,$03,$02,$00
	db $00,$00,$00,$01,$01,$02,$02,$00
	db $78,$f0,$e0,$c0,$80,$00,$00,$00
	db $40,$80,$80,$00,$00,$00,$00,$00
	db $01,$01,$03,$03,$07,$05,$0e,$0f
	db $01,$01,$02,$02,$04,$06,$09,$08
	db $fb,$b7,$ee,$dc,$b8,$70,$e0,$40
	db $04,$49,$10,$20,$48,$90,$00,$80
	db $80,$00,$00,$00,$00,$00,$00,$00
	db $80,$00,$00,$00,$00,$00,$00,$00
	db $01,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $f8,$d8,$7c,$3c,$16,$0e,$07,$03
	db $08,$a8,$44,$04,$0a,$02,$01,$01
	db $1f,$1b,$3e,$3c,$68,$70,$e0,$c0
	db $10,$15,$22,$20,$50,$40,$80,$80
	db $80,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
