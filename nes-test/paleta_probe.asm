	; CVBasic compiler v0.9.2 Mar/12/2026
	; Command: ../cvbasic-repo/cvbasic --nes paleta_probe.bas paleta_probe.asm 
	; Created: Wed Jul 29 00:24:12 2026

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
NES_PRG_BANKS:	equ 2	; Each one 16K.
NES_CHR_BANKS:	equ 1	; Each one 4K.
NES_NAMETABLE:	equ 0

CVBASIC_MUSIC_PLAYER:	equ 0
CVBASIC_COMPRESSION:	equ 0
CVBASIC_BANK_SWITCHING:	equ 0
CVBASIC_BANK_ROM_SIZE:	equ 0
COLECO_SPINNER:	equ 0

BASE_RAM:	equ $0050	; Base of RAM
RAM_SIZE:	equ $0800	; Base of RAM
STACK:	equ $01ff	; Base stack pointer
VDP:	equ $00	; VDP port (write)
VDPR:	equ $00	; VDP port (read)
PSG:	equ $00	; PSG port (write)

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
PPUSIZE:	EQU $40
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
	LDA #$1e	; Color normal, Sprites visible, Background visible, No clipping, Color.
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

ram_end:
	; 	CLS
	JSR cls
	; 	PALETTE LOAD probe_pal
	LDA #0
	STA pointer
	LDA #63
	STA pointer+1
	LDA #32
	STA temp2
	LDA #cvb_PROBE_PAL
	STA temp
	LDA #cvb_PROBE_PAL>>8
	STA temp+1
	JSR LDIRVM
	; 	VPOKE $8192, 200
	LDA #200
	PHA
	LDA #146
	LDY #129
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8193, 200
	LDA #200
	PHA
	LDA #147
	LDY #129
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8194, 200
	LDA #200
	PHA
	LDA #148
	LDY #129
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8195, 200
	LDA #200
	PHA
	LDA #149
	LDY #129
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8196, 200
	LDA #200
	PHA
	LDA #150
	LDY #129
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8197, 200
	LDA #200
	PHA
	LDA #151
	LDY #129
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8198, 200
	LDA #200
	PHA
	LDA #152
	LDY #129
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8199, 200
	LDA #200
	PHA
	LDA #153
	LDY #129
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	WAIT
	JSR wait
	; 	VPOKE $8224, 200
	LDA #200
	PHA
	LDA #36
	LDY #130
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8225, 200
	LDA #200
	PHA
	LDA #37
	LDY #130
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8226, 200
	LDA #200
	PHA
	LDA #38
	LDY #130
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8227, 200
	LDA #200
	PHA
	LDA #39
	LDY #130
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8228, 200
	LDA #200
	PHA
	LDA #40
	LDY #130
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8229, 200
	LDA #200
	PHA
	LDA #41
	LDY #130
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8230, 200
	LDA #200
	PHA
	LDA #48
	LDY #130
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8231, 200
	LDA #200
	PHA
	LDA #49
	LDY #130
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	WAIT
	JSR wait
	; 	VPOKE $8256, 200
	LDA #200
	PHA
	LDA #86
	LDY #130
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8257, 200
	LDA #200
	PHA
	LDA #87
	LDY #130
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8258, 200
	LDA #200
	PHA
	LDA #88
	LDY #130
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8259, 200
	LDA #200
	PHA
	LDA #89
	LDY #130
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8260, 200
	LDA #200
	PHA
	LDA #96
	LDY #130
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8261, 200
	LDA #200
	PHA
	LDA #97
	LDY #130
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8262, 200
	LDA #200
	PHA
	LDA #98
	LDY #130
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8263, 200
	LDA #200
	PHA
	LDA #99
	LDY #130
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	WAIT
	JSR wait
	; 	VPOKE $8288, 200
	LDA #200
	PHA
	LDA #136
	LDY #130
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8289, 200
	LDA #200
	PHA
	LDA #137
	LDY #130
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8290, 200
	LDA #200
	PHA
	LDA #144
	LDY #130
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8291, 200
	LDA #200
	PHA
	LDA #145
	LDY #130
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8292, 200
	LDA #200
	PHA
	LDA #146
	LDY #130
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8293, 200
	LDA #200
	PHA
	LDA #147
	LDY #130
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8294, 200
	LDA #200
	PHA
	LDA #148
	LDY #130
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8295, 200
	LDA #200
	PHA
	LDA #149
	LDY #130
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	WAIT
	JSR wait
	; 	VPOKE $8200, 201
	LDA #201
	PHA
	LDA #0
	LDY #130
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8201, 201
	LDA #201
	PHA
	LDA #1
	LDY #130
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8202, 201
	LDA #201
	PHA
	LDA #2
	LDY #130
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8203, 201
	LDA #201
	PHA
	LDA #3
	LDY #130
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8204, 201
	LDA #201
	PHA
	LDA #4
	LDY #130
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8205, 201
	LDA #201
	PHA
	LDA #5
	LDY #130
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8206, 201
	LDA #201
	PHA
	LDA #6
	LDY #130
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8207, 201
	LDA #201
	PHA
	LDA #7
	LDY #130
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	WAIT
	JSR wait
	; 	VPOKE $8232, 201
	LDA #201
	PHA
	LDA #50
	LDY #130
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8233, 201
	LDA #201
	PHA
	LDA #51
	LDY #130
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8234, 201
	LDA #201
	PHA
	LDA #52
	LDY #130
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8235, 201
	LDA #201
	PHA
	LDA #53
	LDY #130
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8236, 201
	LDA #201
	PHA
	LDA #54
	LDY #130
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8237, 201
	LDA #201
	PHA
	LDA #55
	LDY #130
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8238, 201
	LDA #201
	PHA
	LDA #56
	LDY #130
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8239, 201
	LDA #201
	PHA
	LDA #57
	LDY #130
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	WAIT
	JSR wait
	; 	VPOKE $8264, 201
	LDA #201
	PHA
	LDA #100
	LDY #130
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8265, 201
	LDA #201
	PHA
	LDA #101
	LDY #130
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8266, 201
	LDA #201
	PHA
	LDA #102
	LDY #130
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8267, 201
	LDA #201
	PHA
	LDA #103
	LDY #130
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8268, 201
	LDA #201
	PHA
	LDA #104
	LDY #130
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8269, 201
	LDA #201
	PHA
	LDA #105
	LDY #130
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8270, 201
	LDA #201
	PHA
	LDA #112
	LDY #130
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8271, 201
	LDA #201
	PHA
	LDA #113
	LDY #130
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	WAIT
	JSR wait
	; 	VPOKE $8296, 201
	LDA #201
	PHA
	LDA #150
	LDY #130
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8297, 201
	LDA #201
	PHA
	LDA #151
	LDY #130
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8298, 201
	LDA #201
	PHA
	LDA #152
	LDY #130
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8299, 201
	LDA #201
	PHA
	LDA #153
	LDY #130
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8300, 201
	LDA #201
	PHA
	LDA #0
	LDY #131
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8301, 201
	LDA #201
	PHA
	LDA #1
	LDY #131
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8302, 201
	LDA #201
	PHA
	LDA #2
	LDY #131
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8303, 201
	LDA #201
	PHA
	LDA #3
	LDY #131
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	WAIT
	JSR wait
	; 	VPOKE $8208, 202
	LDA #202
	PHA
	LDA #8
	LDY #130
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8209, 202
	LDA #202
	PHA
	LDA #9
	LDY #130
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8210, 202
	LDA #202
	PHA
	LDA #16
	LDY #130
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8211, 202
	LDA #202
	PHA
	LDA #17
	LDY #130
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8212, 202
	LDA #202
	PHA
	LDA #18
	LDY #130
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8213, 202
	LDA #202
	PHA
	LDA #19
	LDY #130
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8214, 202
	LDA #202
	PHA
	LDA #20
	LDY #130
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8215, 202
	LDA #202
	PHA
	LDA #21
	LDY #130
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	WAIT
	JSR wait
	; 	VPOKE $8240, 202
	LDA #202
	PHA
	LDA #64
	LDY #130
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8241, 202
	LDA #202
	PHA
	LDA #65
	LDY #130
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8242, 202
	LDA #202
	PHA
	LDA #66
	LDY #130
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8243, 202
	LDA #202
	PHA
	LDA #67
	LDY #130
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8244, 202
	LDA #202
	PHA
	LDA #68
	LDY #130
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8245, 202
	LDA #202
	PHA
	LDA #69
	LDY #130
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8246, 202
	LDA #202
	PHA
	LDA #70
	LDY #130
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8247, 202
	LDA #202
	PHA
	LDA #71
	LDY #130
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	WAIT
	JSR wait
	; 	VPOKE $8272, 202
	LDA #202
	PHA
	LDA #114
	LDY #130
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8273, 202
	LDA #202
	PHA
	LDA #115
	LDY #130
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8274, 202
	LDA #202
	PHA
	LDA #116
	LDY #130
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8275, 202
	LDA #202
	PHA
	LDA #117
	LDY #130
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8276, 202
	LDA #202
	PHA
	LDA #118
	LDY #130
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8277, 202
	LDA #202
	PHA
	LDA #119
	LDY #130
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8278, 202
	LDA #202
	PHA
	LDA #120
	LDY #130
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8279, 202
	LDA #202
	PHA
	LDA #121
	LDY #130
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	WAIT
	JSR wait
	; 	VPOKE $8304, 202
	LDA #202
	PHA
	LDA #4
	LDY #131
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8305, 202
	LDA #202
	PHA
	LDA #5
	LDY #131
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8306, 202
	LDA #202
	PHA
	LDA #6
	LDY #131
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8307, 202
	LDA #202
	PHA
	LDA #7
	LDY #131
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8308, 202
	LDA #202
	PHA
	LDA #8
	LDY #131
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8309, 202
	LDA #202
	PHA
	LDA #9
	LDY #131
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8310, 202
	LDA #202
	PHA
	LDA #16
	LDY #131
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8311, 202
	LDA #202
	PHA
	LDA #17
	LDY #131
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	WAIT
	JSR wait
	; 	VPOKE $8320, 200
	LDA #200
	PHA
	LDA #32
	LDY #131
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8321, 200
	LDA #200
	PHA
	LDA #33
	LDY #131
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8322, 200
	LDA #200
	PHA
	LDA #34
	LDY #131
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8323, 200
	LDA #200
	PHA
	LDA #35
	LDY #131
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8324, 200
	LDA #200
	PHA
	LDA #36
	LDY #131
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8325, 200
	LDA #200
	PHA
	LDA #37
	LDY #131
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8326, 200
	LDA #200
	PHA
	LDA #38
	LDY #131
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8327, 200
	LDA #200
	PHA
	LDA #39
	LDY #131
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	WAIT
	JSR wait
	; 	VPOKE $8352, 200
	LDA #200
	PHA
	LDA #82
	LDY #131
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8353, 200
	LDA #200
	PHA
	LDA #83
	LDY #131
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8354, 200
	LDA #200
	PHA
	LDA #84
	LDY #131
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8355, 200
	LDA #200
	PHA
	LDA #85
	LDY #131
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8356, 200
	LDA #200
	PHA
	LDA #86
	LDY #131
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8357, 200
	LDA #200
	PHA
	LDA #87
	LDY #131
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8358, 200
	LDA #200
	PHA
	LDA #88
	LDY #131
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8359, 200
	LDA #200
	PHA
	LDA #89
	LDY #131
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	WAIT
	JSR wait
	; 	VPOKE $8384, 200
	LDA #200
	PHA
	LDA #132
	LDY #131
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8385, 200
	LDA #200
	PHA
	LDA #133
	LDY #131
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8386, 200
	LDA #200
	PHA
	LDA #134
	LDY #131
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8387, 200
	LDA #200
	PHA
	LDA #135
	LDY #131
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8388, 200
	LDA #200
	PHA
	LDA #136
	LDY #131
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8389, 200
	LDA #200
	PHA
	LDA #137
	LDY #131
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8390, 200
	LDA #200
	PHA
	LDA #144
	LDY #131
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8391, 200
	LDA #200
	PHA
	LDA #145
	LDY #131
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	WAIT
	JSR wait
	; 	VPOKE $8416, 200
	LDA #200
	PHA
	LDA #22
	LDY #132
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8417, 200
	LDA #200
	PHA
	LDA #23
	LDY #132
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8418, 200
	LDA #200
	PHA
	LDA #24
	LDY #132
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8419, 200
	LDA #200
	PHA
	LDA #25
	LDY #132
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8420, 200
	LDA #200
	PHA
	LDA #32
	LDY #132
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8421, 200
	LDA #200
	PHA
	LDA #33
	LDY #132
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8422, 200
	LDA #200
	PHA
	LDA #34
	LDY #132
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8423, 200
	LDA #200
	PHA
	LDA #35
	LDY #132
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	WAIT
	JSR wait
	; 	VPOKE $8328, 201
	LDA #201
	PHA
	LDA #40
	LDY #131
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8329, 201
	LDA #201
	PHA
	LDA #41
	LDY #131
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8330, 201
	LDA #201
	PHA
	LDA #48
	LDY #131
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8331, 201
	LDA #201
	PHA
	LDA #49
	LDY #131
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8332, 201
	LDA #201
	PHA
	LDA #50
	LDY #131
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8333, 201
	LDA #201
	PHA
	LDA #51
	LDY #131
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8334, 201
	LDA #201
	PHA
	LDA #52
	LDY #131
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8335, 201
	LDA #201
	PHA
	LDA #53
	LDY #131
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	WAIT
	JSR wait
	; 	VPOKE $8360, 201
	LDA #201
	PHA
	LDA #96
	LDY #131
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8361, 201
	LDA #201
	PHA
	LDA #97
	LDY #131
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8362, 201
	LDA #201
	PHA
	LDA #98
	LDY #131
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8363, 201
	LDA #201
	PHA
	LDA #99
	LDY #131
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8364, 201
	LDA #201
	PHA
	LDA #100
	LDY #131
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8365, 201
	LDA #201
	PHA
	LDA #101
	LDY #131
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8366, 201
	LDA #201
	PHA
	LDA #102
	LDY #131
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8367, 201
	LDA #201
	PHA
	LDA #103
	LDY #131
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	WAIT
	JSR wait
	; 	VPOKE $8392, 201
	LDA #201
	PHA
	LDA #146
	LDY #131
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8393, 201
	LDA #201
	PHA
	LDA #147
	LDY #131
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8394, 201
	LDA #201
	PHA
	LDA #148
	LDY #131
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8395, 201
	LDA #201
	PHA
	LDA #149
	LDY #131
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8396, 201
	LDA #201
	PHA
	LDA #150
	LDY #131
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8397, 201
	LDA #201
	PHA
	LDA #151
	LDY #131
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8398, 201
	LDA #201
	PHA
	LDA #152
	LDY #131
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8399, 201
	LDA #201
	PHA
	LDA #153
	LDY #131
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	WAIT
	JSR wait
	; 	VPOKE $8424, 201
	LDA #201
	PHA
	LDA #36
	LDY #132
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8425, 201
	LDA #201
	PHA
	LDA #37
	LDY #132
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8426, 201
	LDA #201
	PHA
	LDA #38
	LDY #132
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8427, 201
	LDA #201
	PHA
	LDA #39
	LDY #132
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8428, 201
	LDA #201
	PHA
	LDA #40
	LDY #132
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8429, 201
	LDA #201
	PHA
	LDA #41
	LDY #132
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8430, 201
	LDA #201
	PHA
	LDA #48
	LDY #132
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8431, 201
	LDA #201
	PHA
	LDA #49
	LDY #132
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	WAIT
	JSR wait
	; 	VPOKE $8336, 202
	LDA #202
	PHA
	LDA #54
	LDY #131
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8337, 202
	LDA #202
	PHA
	LDA #55
	LDY #131
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8338, 202
	LDA #202
	PHA
	LDA #56
	LDY #131
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8339, 202
	LDA #202
	PHA
	LDA #57
	LDY #131
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8340, 202
	LDA #202
	PHA
	LDA #64
	LDY #131
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8341, 202
	LDA #202
	PHA
	LDA #65
	LDY #131
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8342, 202
	LDA #202
	PHA
	LDA #66
	LDY #131
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8343, 202
	LDA #202
	PHA
	LDA #67
	LDY #131
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	WAIT
	JSR wait
	; 	VPOKE $8368, 202
	LDA #202
	PHA
	LDA #104
	LDY #131
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8369, 202
	LDA #202
	PHA
	LDA #105
	LDY #131
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8370, 202
	LDA #202
	PHA
	LDA #112
	LDY #131
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8371, 202
	LDA #202
	PHA
	LDA #113
	LDY #131
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8372, 202
	LDA #202
	PHA
	LDA #114
	LDY #131
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8373, 202
	LDA #202
	PHA
	LDA #115
	LDY #131
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8374, 202
	LDA #202
	PHA
	LDA #116
	LDY #131
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8375, 202
	LDA #202
	PHA
	LDA #117
	LDY #131
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	WAIT
	JSR wait
	; 	VPOKE $8400, 202
	LDA #202
	PHA
	LDA #0
	LDY #132
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8401, 202
	LDA #202
	PHA
	LDA #1
	LDY #132
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8402, 202
	LDA #202
	PHA
	LDA #2
	LDY #132
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8403, 202
	LDA #202
	PHA
	LDA #3
	LDY #132
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8404, 202
	LDA #202
	PHA
	LDA #4
	LDY #132
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8405, 202
	LDA #202
	PHA
	LDA #5
	LDY #132
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8406, 202
	LDA #202
	PHA
	LDA #6
	LDY #132
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8407, 202
	LDA #202
	PHA
	LDA #7
	LDY #132
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	WAIT
	JSR wait
	; 	VPOKE $8432, 202
	LDA #202
	PHA
	LDA #50
	LDY #132
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8433, 202
	LDA #202
	PHA
	LDA #51
	LDY #132
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8434, 202
	LDA #202
	PHA
	LDA #52
	LDY #132
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8435, 202
	LDA #202
	PHA
	LDA #53
	LDY #132
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8436, 202
	LDA #202
	PHA
	LDA #54
	LDY #132
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8437, 202
	LDA #202
	PHA
	LDA #55
	LDY #132
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8438, 202
	LDA #202
	PHA
	LDA #56
	LDY #132
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8439, 202
	LDA #202
	PHA
	LDA #57
	LDY #132
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	WAIT
	JSR wait
	; 	VPOKE $8448, 200
	LDA #200
	PHA
	LDA #72
	LDY #132
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8449, 200
	LDA #200
	PHA
	LDA #73
	LDY #132
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8450, 200
	LDA #200
	PHA
	LDA #80
	LDY #132
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8451, 200
	LDA #200
	PHA
	LDA #81
	LDY #132
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8452, 200
	LDA #200
	PHA
	LDA #82
	LDY #132
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8453, 200
	LDA #200
	PHA
	LDA #83
	LDY #132
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8454, 200
	LDA #200
	PHA
	LDA #84
	LDY #132
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8455, 200
	LDA #200
	PHA
	LDA #85
	LDY #132
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	WAIT
	JSR wait
	; 	VPOKE $8480, 200
	LDA #200
	PHA
	LDA #128
	LDY #132
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8481, 200
	LDA #200
	PHA
	LDA #129
	LDY #132
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8482, 200
	LDA #200
	PHA
	LDA #130
	LDY #132
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8483, 200
	LDA #200
	PHA
	LDA #131
	LDY #132
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8484, 200
	LDA #200
	PHA
	LDA #132
	TAY
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8485, 200
	LDA #200
	PHA
	LDA #133
	LDY #132
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8486, 200
	LDA #200
	PHA
	LDA #134
	LDY #132
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8487, 200
	LDA #200
	PHA
	LDA #135
	LDY #132
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	WAIT
	JSR wait
	; 	VPOKE $8512, 200
	LDA #200
	PHA
	LDA #18
	LDY #133
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8513, 200
	LDA #200
	PHA
	LDA #19
	LDY #133
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8514, 200
	LDA #200
	PHA
	LDA #20
	LDY #133
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8515, 200
	LDA #200
	PHA
	LDA #21
	LDY #133
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8516, 200
	LDA #200
	PHA
	LDA #22
	LDY #133
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8517, 200
	LDA #200
	PHA
	LDA #23
	LDY #133
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8518, 200
	LDA #200
	PHA
	LDA #24
	LDY #133
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8519, 200
	LDA #200
	PHA
	LDA #25
	LDY #133
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	WAIT
	JSR wait
	; 	VPOKE $8544, 200
	LDA #200
	PHA
	LDA #68
	LDY #133
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8545, 200
	LDA #200
	PHA
	LDA #69
	LDY #133
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8546, 200
	LDA #200
	PHA
	LDA #70
	LDY #133
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8547, 200
	LDA #200
	PHA
	LDA #71
	LDY #133
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8548, 200
	LDA #200
	PHA
	LDA #72
	LDY #133
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8549, 200
	LDA #200
	PHA
	LDA #73
	LDY #133
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8550, 200
	LDA #200
	PHA
	LDA #80
	LDY #133
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8551, 200
	LDA #200
	PHA
	LDA #81
	LDY #133
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	WAIT
	JSR wait
	; 	VPOKE $8456, 201
	LDA #201
	PHA
	LDA #86
	LDY #132
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8457, 201
	LDA #201
	PHA
	LDA #87
	LDY #132
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8458, 201
	LDA #201
	PHA
	LDA #88
	LDY #132
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8459, 201
	LDA #201
	PHA
	LDA #89
	LDY #132
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8460, 201
	LDA #201
	PHA
	LDA #96
	LDY #132
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8461, 201
	LDA #201
	PHA
	LDA #97
	LDY #132
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8462, 201
	LDA #201
	PHA
	LDA #98
	LDY #132
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8463, 201
	LDA #201
	PHA
	LDA #99
	LDY #132
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	WAIT
	JSR wait
	; 	VPOKE $8488, 201
	LDA #201
	PHA
	LDA #136
	LDY #132
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8489, 201
	LDA #201
	PHA
	LDA #137
	LDY #132
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8490, 201
	LDA #201
	PHA
	LDA #144
	LDY #132
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8491, 201
	LDA #201
	PHA
	LDA #145
	LDY #132
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8492, 201
	LDA #201
	PHA
	LDA #146
	LDY #132
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8493, 201
	LDA #201
	PHA
	LDA #147
	LDY #132
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8494, 201
	LDA #201
	PHA
	LDA #148
	LDY #132
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8495, 201
	LDA #201
	PHA
	LDA #149
	LDY #132
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	WAIT
	JSR wait
	; 	VPOKE $8520, 201
	LDA #201
	PHA
	LDA #32
	LDY #133
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8521, 201
	LDA #201
	PHA
	LDA #33
	LDY #133
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8522, 201
	LDA #201
	PHA
	LDA #34
	LDY #133
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8523, 201
	LDA #201
	PHA
	LDA #35
	LDY #133
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8524, 201
	LDA #201
	PHA
	LDA #36
	LDY #133
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8525, 201
	LDA #201
	PHA
	LDA #37
	LDY #133
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8526, 201
	LDA #201
	PHA
	LDA #38
	LDY #133
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8527, 201
	LDA #201
	PHA
	LDA #39
	LDY #133
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	WAIT
	JSR wait
	; 	VPOKE $8552, 201
	LDA #201
	PHA
	LDA #82
	LDY #133
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8553, 201
	LDA #201
	PHA
	LDA #83
	LDY #133
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8554, 201
	LDA #201
	PHA
	LDA #84
	LDY #133
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8555, 201
	LDA #201
	PHA
	LDA #85
	LDY #133
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8556, 201
	LDA #201
	PHA
	LDA #86
	LDY #133
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8557, 201
	LDA #201
	PHA
	LDA #87
	LDY #133
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8558, 201
	LDA #201
	PHA
	LDA #88
	LDY #133
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8559, 201
	LDA #201
	PHA
	LDA #89
	LDY #133
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	WAIT
	JSR wait
	; 	VPOKE $8464, 202
	LDA #202
	PHA
	LDA #100
	LDY #132
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8465, 202
	LDA #202
	PHA
	LDA #101
	LDY #132
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8466, 202
	LDA #202
	PHA
	LDA #102
	LDY #132
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8467, 202
	LDA #202
	PHA
	LDA #103
	LDY #132
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8468, 202
	LDA #202
	PHA
	LDA #104
	LDY #132
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8469, 202
	LDA #202
	PHA
	LDA #105
	LDY #132
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8470, 202
	LDA #202
	PHA
	LDA #112
	LDY #132
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8471, 202
	LDA #202
	PHA
	LDA #113
	LDY #132
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	WAIT
	JSR wait
	; 	VPOKE $8496, 202
	LDA #202
	PHA
	LDA #150
	LDY #132
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8497, 202
	LDA #202
	PHA
	LDA #151
	LDY #132
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8498, 202
	LDA #202
	PHA
	LDA #152
	LDY #132
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8499, 202
	LDA #202
	PHA
	LDA #153
	LDY #132
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8500, 202
	LDA #202
	PHA
	LDA #0
	LDY #133
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8501, 202
	LDA #202
	PHA
	LDA #1
	LDY #133
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8502, 202
	LDA #202
	PHA
	LDA #2
	LDY #133
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8503, 202
	LDA #202
	PHA
	LDA #3
	LDY #133
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	WAIT
	JSR wait
	; 	VPOKE $8528, 202
	LDA #202
	PHA
	LDA #40
	LDY #133
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8529, 202
	LDA #202
	PHA
	LDA #41
	LDY #133
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8530, 202
	LDA #202
	PHA
	LDA #48
	LDY #133
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8531, 202
	LDA #202
	PHA
	LDA #49
	LDY #133
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8532, 202
	LDA #202
	PHA
	LDA #50
	LDY #133
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8533, 202
	LDA #202
	PHA
	LDA #51
	LDY #133
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8534, 202
	LDA #202
	PHA
	LDA #52
	LDY #133
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8535, 202
	LDA #202
	PHA
	LDA #53
	LDY #133
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	WAIT
	JSR wait
	; 	VPOKE $8560, 202
	LDA #202
	PHA
	LDA #96
	LDY #133
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8561, 202
	LDA #202
	PHA
	LDA #97
	LDY #133
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8562, 202
	LDA #202
	PHA
	LDA #98
	LDY #133
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8563, 202
	LDA #202
	PHA
	LDA #99
	LDY #133
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8564, 202
	LDA #202
	PHA
	LDA #100
	LDY #133
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8565, 202
	LDA #202
	PHA
	LDA #101
	LDY #133
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8566, 202
	LDA #202
	PHA
	LDA #102
	LDY #133
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8567, 202
	LDA #202
	PHA
	LDA #103
	LDY #133
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	WAIT
	JSR wait
	; 	VPOKE $8576, 200
	LDA #200
	PHA
	LDA #118
	LDY #133
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8577, 200
	LDA #200
	PHA
	LDA #119
	LDY #133
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8578, 200
	LDA #200
	PHA
	LDA #120
	LDY #133
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8579, 200
	LDA #200
	PHA
	LDA #121
	LDY #133
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8580, 200
	LDA #200
	PHA
	LDA #128
	LDY #133
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8581, 200
	LDA #200
	PHA
	LDA #129
	LDY #133
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8582, 200
	LDA #200
	PHA
	LDA #130
	LDY #133
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8583, 200
	LDA #200
	PHA
	LDA #131
	LDY #133
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	WAIT
	JSR wait
	; 	VPOKE $8608, 200
	LDA #200
	PHA
	LDA #8
	LDY #134
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8609, 200
	LDA #200
	PHA
	LDA #9
	LDY #134
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8610, 200
	LDA #200
	PHA
	LDA #16
	LDY #134
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8611, 200
	LDA #200
	PHA
	LDA #17
	LDY #134
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8612, 200
	LDA #200
	PHA
	LDA #18
	LDY #134
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8613, 200
	LDA #200
	PHA
	LDA #19
	LDY #134
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8614, 200
	LDA #200
	PHA
	LDA #20
	LDY #134
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8615, 200
	LDA #200
	PHA
	LDA #21
	LDY #134
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	WAIT
	JSR wait
	; 	VPOKE $8640, 200
	LDA #200
	PHA
	LDA #64
	LDY #134
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8641, 200
	LDA #200
	PHA
	LDA #65
	LDY #134
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8642, 200
	LDA #200
	PHA
	LDA #66
	LDY #134
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8643, 200
	LDA #200
	PHA
	LDA #67
	LDY #134
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8644, 200
	LDA #200
	PHA
	LDA #68
	LDY #134
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8645, 200
	LDA #200
	PHA
	LDA #69
	LDY #134
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8646, 200
	LDA #200
	PHA
	LDA #70
	LDY #134
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8647, 200
	LDA #200
	PHA
	LDA #71
	LDY #134
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	WAIT
	JSR wait
	; 	VPOKE $8672, 200
	LDA #200
	PHA
	LDA #114
	LDY #134
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8673, 200
	LDA #200
	PHA
	LDA #115
	LDY #134
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8674, 200
	LDA #200
	PHA
	LDA #116
	LDY #134
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8675, 200
	LDA #200
	PHA
	LDA #117
	LDY #134
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8676, 200
	LDA #200
	PHA
	LDA #118
	LDY #134
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8677, 200
	LDA #200
	PHA
	LDA #119
	LDY #134
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8678, 200
	LDA #200
	PHA
	LDA #120
	LDY #134
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8679, 200
	LDA #200
	PHA
	LDA #121
	LDY #134
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	WAIT
	JSR wait
	; 	VPOKE $8584, 201
	LDA #201
	PHA
	LDA #132
	LDY #133
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8585, 201
	LDA #201
	PHA
	LDA #133
	TAY
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8586, 201
	LDA #201
	PHA
	LDA #134
	LDY #133
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8587, 201
	LDA #201
	PHA
	LDA #135
	LDY #133
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8588, 201
	LDA #201
	PHA
	LDA #136
	LDY #133
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8589, 201
	LDA #201
	PHA
	LDA #137
	LDY #133
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8590, 201
	LDA #201
	PHA
	LDA #144
	LDY #133
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8591, 201
	LDA #201
	PHA
	LDA #145
	LDY #133
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	WAIT
	JSR wait
	; 	VPOKE $8616, 201
	LDA #201
	PHA
	LDA #22
	LDY #134
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8617, 201
	LDA #201
	PHA
	LDA #23
	LDY #134
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8618, 201
	LDA #201
	PHA
	LDA #24
	LDY #134
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8619, 201
	LDA #201
	PHA
	LDA #25
	LDY #134
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8620, 201
	LDA #201
	PHA
	LDA #32
	LDY #134
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8621, 201
	LDA #201
	PHA
	LDA #33
	LDY #134
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8622, 201
	LDA #201
	PHA
	LDA #34
	LDY #134
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8623, 201
	LDA #201
	PHA
	LDA #35
	LDY #134
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	WAIT
	JSR wait
	; 	VPOKE $8648, 201
	LDA #201
	PHA
	LDA #72
	LDY #134
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8649, 201
	LDA #201
	PHA
	LDA #73
	LDY #134
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8650, 201
	LDA #201
	PHA
	LDA #80
	LDY #134
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8651, 201
	LDA #201
	PHA
	LDA #81
	LDY #134
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8652, 201
	LDA #201
	PHA
	LDA #82
	LDY #134
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8653, 201
	LDA #201
	PHA
	LDA #83
	LDY #134
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8654, 201
	LDA #201
	PHA
	LDA #84
	LDY #134
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8655, 201
	LDA #201
	PHA
	LDA #85
	LDY #134
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	WAIT
	JSR wait
	; 	VPOKE $8680, 201
	LDA #201
	PHA
	LDA #128
	LDY #134
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8681, 201
	LDA #201
	PHA
	LDA #129
	LDY #134
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8682, 201
	LDA #201
	PHA
	LDA #130
	LDY #134
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8683, 201
	LDA #201
	PHA
	LDA #131
	LDY #134
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8684, 201
	LDA #201
	PHA
	LDA #132
	LDY #134
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8685, 201
	LDA #201
	PHA
	LDA #133
	LDY #134
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8686, 201
	LDA #201
	PHA
	LDA #134
	TAY
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8687, 201
	LDA #201
	PHA
	LDA #135
	LDY #134
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	WAIT
	JSR wait
	; 	VPOKE $8592, 202
	LDA #202
	PHA
	LDA #146
	LDY #133
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8593, 202
	LDA #202
	PHA
	LDA #147
	LDY #133
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8594, 202
	LDA #202
	PHA
	LDA #148
	LDY #133
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8595, 202
	LDA #202
	PHA
	LDA #149
	LDY #133
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8596, 202
	LDA #202
	PHA
	LDA #150
	LDY #133
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8597, 202
	LDA #202
	PHA
	LDA #151
	LDY #133
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8598, 202
	LDA #202
	PHA
	LDA #152
	LDY #133
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8599, 202
	LDA #202
	PHA
	LDA #153
	LDY #133
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	WAIT
	JSR wait
	; 	VPOKE $8624, 202
	LDA #202
	PHA
	LDA #36
	LDY #134
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8625, 202
	LDA #202
	PHA
	LDA #37
	LDY #134
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8626, 202
	LDA #202
	PHA
	LDA #38
	LDY #134
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8627, 202
	LDA #202
	PHA
	LDA #39
	LDY #134
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8628, 202
	LDA #202
	PHA
	LDA #40
	LDY #134
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8629, 202
	LDA #202
	PHA
	LDA #41
	LDY #134
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8630, 202
	LDA #202
	PHA
	LDA #48
	LDY #134
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8631, 202
	LDA #202
	PHA
	LDA #49
	LDY #134
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	WAIT
	JSR wait
	; 	VPOKE $8656, 202
	LDA #202
	PHA
	LDA #86
	LDY #134
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8657, 202
	LDA #202
	PHA
	LDA #87
	LDY #134
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8658, 202
	LDA #202
	PHA
	LDA #88
	LDY #134
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8659, 202
	LDA #202
	PHA
	LDA #89
	LDY #134
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8660, 202
	LDA #202
	PHA
	LDA #96
	LDY #134
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8661, 202
	LDA #202
	PHA
	LDA #97
	LDY #134
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8662, 202
	LDA #202
	PHA
	LDA #98
	LDY #134
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8663, 202
	LDA #202
	PHA
	LDA #99
	LDY #134
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	WAIT
	JSR wait
	; 	VPOKE $8688, 202
	LDA #202
	PHA
	LDA #136
	LDY #134
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8689, 202
	LDA #202
	PHA
	LDA #137
	LDY #134
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8690, 202
	LDA #202
	PHA
	LDA #144
	LDY #134
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8691, 202
	LDA #202
	PHA
	LDA #145
	LDY #134
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8692, 202
	LDA #202
	PHA
	LDA #146
	LDY #134
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8693, 202
	LDA #202
	PHA
	LDA #147
	LDY #134
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8694, 202
	LDA #202
	PHA
	LDA #148
	LDY #134
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $8695, 202
	LDA #202
	PHA
	LDA #149
	LDY #134
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	WAIT
	JSR wait
	; 	VPOKE $9152, $00
	LDA #0
	PHA
	LDA #82
	LDY #145
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $9160, $55
	LDA #85
	PHA
	LDA #96
	LDY #145
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $9153, $00
	LDA #0
	PHA
	LDA #83
	LDY #145
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $9161, $55
	LDA #85
	PHA
	LDA #97
	LDY #145
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $9154, $00
	LDA #0
	PHA
	LDA #84
	LDY #145
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $9162, $55
	LDA #85
	PHA
	LDA #98
	LDY #145
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $9155, $00
	LDA #0
	PHA
	LDA #85
	LDY #145
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $9163, $55
	LDA #85
	PHA
	LDA #99
	LDY #145
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $9156, $00
	LDA #0
	PHA
	LDA #86
	LDY #145
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $9164, $55
	LDA #85
	PHA
	LDA #100
	LDY #145
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $9157, $00
	LDA #0
	PHA
	LDA #87
	LDY #145
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $9165, $55
	LDA #85
	PHA
	LDA #101
	LDY #145
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $9158, $00
	LDA #0
	PHA
	LDA #88
	LDY #145
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $9166, $55
	LDA #85
	PHA
	LDA #102
	LDY #145
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $9159, $00
	LDA #0
	PHA
	LDA #89
	LDY #145
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $9167, $55
	LDA #85
	PHA
	LDA #103
	LDY #145
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	WAIT
	JSR wait
	; 	VPOKE $9168, $AA
	LDA #170
	PHA
	LDA #104
	LDY #145
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $9176, $FF
	LDA #255
	PHA
	LDA #118
	LDY #145
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $9169, $AA
	LDA #170
	PHA
	LDA #105
	LDY #145
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $9177, $FF
	LDA #255
	PHA
	LDA #119
	LDY #145
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $9170, $AA
	LDA #170
	PHA
	LDA #112
	LDY #145
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $9178, $FF
	LDA #255
	PHA
	LDA #120
	LDY #145
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $9171, $AA
	LDA #170
	PHA
	LDA #113
	LDY #145
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $9179, $FF
	LDA #255
	PHA
	LDA #121
	LDY #145
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $9172, $AA
	LDA #170
	PHA
	LDA #114
	LDY #145
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $9180, $FF
	LDA #255
	PHA
	LDA #128
	LDY #145
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $9173, $AA
	LDA #170
	PHA
	LDA #115
	LDY #145
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $9181, $FF
	LDA #255
	PHA
	LDA #129
	LDY #145
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $9174, $AA
	LDA #170
	PHA
	LDA #116
	LDY #145
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $9182, $FF
	LDA #255
	PHA
	LDA #130
	LDY #145
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $9175, $AA
	LDA #170
	PHA
	LDA #117
	LDY #145
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	VPOKE $9183, $FF
	LDA #255
	PHA
	LDA #131
	LDY #145
	STA temp
	STY temp+1
	PLA
	TAX
	LDA temp
	JSR WRTVRM
	; 	WAIT
	JSR wait
	; loop:
cvb_LOOP:
	; 	WAIT
	JSR wait
	; 	GOTO loop
	JMP cvb_LOOP
	; 
	; probe_pal:
cvb_PROBE_PAL:
	; 	DATA BYTE $0F,$0B,$0C,$1B
	DB $0f,$0b,$0c,$1b
	; 	DATA BYTE $0F,$2B,$2C,$3C
	DB $0f,$2b,$2c,$3c
	; 	DATA BYTE $0F,$11,$12,$1C
	DB $0f,$11,$12,$1c
	; 	DATA BYTE $0F,$16,$25,$30
	DB $0f,$16,$25,$30
	; 
	; 	CHRROM 0
	; 	CHRROM PATTERN 200
	; 
	; 	BITMAP "11111111"
	; 	BITMAP "11111111"
	; 	BITMAP "11111111"
	; 	BITMAP "11111111"
	; 	BITMAP "11111111"
	; 	BITMAP "11111111"
	; 	BITMAP "11111111"
	; 	BITMAP "11111111"
	; 
	; 	BITMAP "22222222"
	; 	BITMAP "22222222"
	; 	BITMAP "22222222"
	; 	BITMAP "22222222"
	; 	BITMAP "22222222"
	; 	BITMAP "22222222"
	; 	BITMAP "22222222"
	; 	BITMAP "22222222"
	; 
	; 	BITMAP "33333333"
	; 	BITMAP "33333333"
	; 	BITMAP "33333333"
	; 	BITMAP "33333333"
	; 	BITMAP "33333333"
	; 	BITMAP "33333333"
	; 	BITMAP "33333333"
	; 	BITMAP "33333333"
rom_end:
    if CVBASIC_BANK_SWITCHING
	forg CVBASIC_BANK_ROM_SIZE*1024+16-6	; Go to final of ROM minus vectors
   else
	times $fffa-$ db $ff
    endif

	dw nmi_handler
	dw START
	dw irq_handler	

; CHR data
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
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
	db $40,$20,$10,$00,$00,$00,$00,$00
	db $40,$20,$10,$00,$00,$00,$00,$00
	db $00,$00,$68,$98,$88,$98,$68,$00
	db $00,$00,$68,$98,$88,$98,$68,$00
	db $80,$80,$f0,$88,$88,$88,$f0,$00
	db $80,$80,$f0,$88,$88,$88,$f0,$00
	db $00,$00,$78,$80,$80,$80,$78,$00
	db $00,$00,$78,$80,$80,$80,$78,$00
	db $08,$08,$68,$98,$88,$98,$68,$00
	db $08,$08,$68,$98,$88,$98,$68,$00
	db $00,$00,$70,$88,$f8,$80,$70,$00
	db $00,$00,$70,$88,$f8,$80,$70,$00
	db $30,$48,$40,$e0,$40,$40,$40,$00
	db $30,$48,$40,$e0,$40,$40,$40,$00
	db $00,$00,$78,$88,$88,$78,$08,$70
	db $00,$00,$78,$88,$88,$78,$08,$70
	db $80,$80,$f0,$88,$88,$88,$88,$00
	db $80,$80,$f0,$88,$88,$88,$88,$00
	db $20,$00,$60,$20,$20,$20,$70,$00
	db $20,$00,$60,$20,$20,$20,$70,$00
	db $08,$00,$18,$08,$88,$88,$70,$00
	db $08,$00,$18,$08,$88,$88,$70,$00
	db $80,$80,$88,$90,$e0,$90,$88,$00
	db $80,$80,$88,$90,$e0,$90,$88,$00
	db $60,$20,$20,$20,$20,$20,$70,$00
	db $60,$20,$20,$20,$20,$20,$70,$00
	db $00,$00,$d0,$a8,$a8,$a8,$a8,$00
	db $00,$00,$d0,$a8,$a8,$a8,$a8,$00
	db $00,$00,$b0,$c8,$88,$88,$88,$00
	db $00,$00,$b0,$c8,$88,$88,$88,$00
	db $00,$00,$70,$88,$88,$88,$70,$00
	db $00,$00,$70,$88,$88,$88,$70,$00
	db $00,$00,$f0,$88,$88,$88,$f0,$80
	db $00,$00,$f0,$88,$88,$88,$f0,$80
	db $00,$00,$78,$88,$88,$88,$78,$08
	db $00,$00,$78,$88,$88,$88,$78,$08
	db $00,$00,$b8,$c0,$80,$80,$80,$00
	db $00,$00,$b8,$c0,$80,$80,$80,$00
	db $00,$00,$78,$80,$70,$08,$f0,$00
	db $00,$00,$78,$80,$70,$08,$f0,$00
	db $20,$20,$f8,$20,$20,$20,$20,$00
	db $20,$20,$f8,$20,$20,$20,$20,$00
	db $00,$00,$88,$88,$88,$98,$68,$00
	db $00,$00,$88,$88,$88,$98,$68,$00
	db $00,$00,$88,$88,$88,$50,$20,$00
	db $00,$00,$88,$88,$88,$50,$20,$00
	db $00,$00,$88,$a8,$a8,$a8,$50,$00
	db $00,$00,$88,$a8,$a8,$a8,$50,$00
	db $00,$00,$88,$50,$20,$50,$88,$00
	db $00,$00,$88,$50,$20,$50,$88,$00
	db $00,$00,$88,$88,$98,$68,$08,$70
	db $00,$00,$88,$88,$98,$68,$08,$70
	db $00,$00,$f8,$10,$20,$40,$f8,$00
	db $00,$00,$f8,$10,$20,$40,$f8,$00
	db $18,$20,$20,$40,$20,$20,$18,$00
	db $18,$20,$20,$40,$20,$20,$18,$00
	db $20,$20,$20,$20,$20,$20,$20,$00
	db $20,$20,$20,$20,$20,$20,$20,$00
	db $c0,$20,$20,$10,$20,$20,$c0,$00
	db $c0,$20,$20,$10,$20,$20,$c0,$00
	db $00,$00,$40,$a8,$10,$00,$00,$00
	db $00,$00,$40,$a8,$10,$00,$00,$00
	db $70,$70,$20,$f8,$20,$70,$50,$00
	db $70,$70,$20,$f8,$20,$70,$50,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
	db $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
	db $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
