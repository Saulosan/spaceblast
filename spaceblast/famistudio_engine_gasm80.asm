; Generated mechanically from FamiStudio NESASM engine.
; Configuration: NTSC, native 2A03 channels 0-3, no DPCM/SFX.
; Temporary ZP aliases: $02-$09; engine RAM starts at $0502.
FAMISTUDIO_BANK: EQU 3
FAMISTUDIO_ACTIVE: EQU $0500
FAMISTUDIO_SAVED_BANK: EQU $0501
FAMISTUDIO_DPCM_OFF: EQU $C000
ORG $8000

;======================================================================================================================
; FAMISTUDIO SOUND ENGINE (4.5.0)
; Copyright (c) 2019-2026 Mathieu Gauthier
;
; Copying and distribution of this file, with or without
; modification, are permitted in any medium without royalty provided
; the copyright notice and this notice are preserved in all source
; code copies. This file is offered as-is, without any warranty.
;======================================================================================================================

;======================================================================================================================
; This is the FamiStudio sound engine. It is used by the NSF and ROM exporter of FamiStudio and can be used to make 
; games. It supports every feature from FamiStudio, some of them are toggeable to save CPU/memory.
;
; This is essentially a heavily modified version of FamiTone2 by Shiru. A lot of his code and comments are still
; present here, so massive thanks to him!! I am not trying to steal his work or anything, i renamed a lot of functions
; and variables because at some point it was becoming a mess of coding standards and getting hard to maintain.
;
; Moderately advanced users can probably figure out how to use the sound engine simply by reading these comments.
; For more in-depth documentation, please go to:
;
;    https://famistudio.org/doc/soundengine/
;======================================================================================================================

;======================================================================================================================
; INTERFACE
;
; The interface is pretty much the same as FamiTone2, with a slightly different naming convention. The subroutines you
; can call from your game are: 
;
;   - famistudio_init            : Initialize the engine with some music data.
;   - famistudio_music_play      : Start music playback with a specific song.
;   - famistudio_music_pause     : Pause/unpause music playback.
;   - famistudio_music_stop      : Stops music playback.
;   - famistudio_sfx_init        : Initialize SFX engine with SFX data.
;   - famistudio_sfx_play        : Play a SFX.
;   - famistudio_sfx_sample_play : Play a DPCM SFX.
;   - famistudio_update          : Updates the music/SFX engine, call once per frame, ideally from NMI.
;
; You can check the demo ROM to see how they are used or check out the online documentation for more info.
;======================================================================================================================

;======================================================================================================================
; CONFIGURATION
;
; There are 2 main ways of configuring the engine. 
;
;   1) The simplest way is right here, in the section below. Simply comment/uncomment these defines, and move on 
;      with your life.
;
;   2) The second way is "externally", using definitions coming from elsewhere in your app or the command line. If you
;      wish do so, simply define FAMISTUDIO_CFG_EXTERNAL=1 and this whole section will be ignored. You are then 
;      responsible for providing all configuration. This is useful if you have multiple projects that needs 
;      different configurations, while pointing to the same code file. This is how the provided demos and FamiStudio
;      uses it.
;
; Note that unless specified, the engine uses "if" and not "ifdef" for all boolean values so you need to define these
; to non-zero values. Undefined values will be assumed to be zero.
;
; There are 4 main things to configure, each of them will be detailed below.
;
;   1) Segments (ZP/RAM/PRG)
;   2) Audio expansion
;   3) Global engine parameters
;   4) Supported features
;======================================================================================================================


; Set this to configure the sound engine from outside (in your app, or from the command line)

; Memory location of the DPCM samples. Must be between $c000 and $ffc0, and a multiple of 64.

;======================================================================================================================
; END OF CONFIGURATION
;
; Ideally, you should not have to change anything below this line.
;======================================================================================================================

;======================================================================================================================
; INTERNAL DEFINES (Do not touch)
;======================================================================================================================













FAMISTUDIO_DUAL_SUPPORT: EQU 0
















    


    




FAMISTUDIO_EXP_NONE: EQU 1










FAMISTUDIO_DPCM_PTR: EQU (FAMISTUDIO_DPCM_OFF & $3fff) >> 6

FAMISTUDIO_NUM_ENVELOPES: EQU 3+3+2+3
FAMISTUDIO_NUM_PITCH_ENVELOPES: EQU 3
FAMISTUDIO_NUM_CHANNELS: EQU 5
FAMISTUDIO_NUM_DUTY_CYCLES: EQU 3

FAMISTUDIO_NUM_VOLUME_SLIDES: EQU 4

FAMISTUDIO_NUM_SLIDES: EQU FAMISTUDIO_NUM_PITCH_ENVELOPES

; Keep the noise slide at the end so the pitch envelopes/slides are in sync.
FAMISTUDIO_NOISE_SLIDE_INDEX: EQU FAMISTUDIO_NUM_SLIDES - 1


; TODO: Investigate reshuffling the envelopes to keep them contiguously 
; by type (all volumes envelopes, all arp envelopes, etc.) instead of 
; by channel. This *may* simplify a lot of places where we need a lookup
; table (famistudio_channel_to_volume_env, etc.)
FAMISTUDIO_CH0_ENVS: EQU 0
FAMISTUDIO_CH1_ENVS: EQU 3
FAMISTUDIO_CH2_ENVS: EQU 6
FAMISTUDIO_CH3_ENVS: EQU 8


FAMISTUDIO_ENV_VOLUME_OFF: EQU 0
FAMISTUDIO_ENV_NOTE_OFF: EQU 1
FAMISTUDIO_ENV_DUTY_OFF: EQU 2
FAMISTUDIO_ENV_N163_WAVE_IDX_OFF: EQU 2
FAMISTUDIO_ENV_FDS_WAVE_IDX_OFF: EQU 2
FAMISTUDIO_ENV_MIXER_IDX_OFF: EQU 2
FAMISTUDIO_ENV_NOISE_IDX_OFF: EQU 3


FAMISTUDIO_VRC6_CH0_IDX: EQU -1
FAMISTUDIO_VRC6_CH1_IDX: EQU -1
FAMISTUDIO_VRC6_CH2_IDX: EQU -1
FAMISTUDIO_MMC5_CH0_IDX: EQU -1
FAMISTUDIO_MMC5_CH1_IDX: EQU -1

FAMISTUDIO_VRC7_PITCH_SHIFT: EQU 3
FAMISTUDIO_EPSM_PITCH_SHIFT: EQU 3

FAMISTUDIO_N163_PITCH_SHIFT: EQU 2

FAMISTUDIO_PITCH_SHIFT: EQU 0



FAMISTUDIO_FIRST_EXP_INST_CHANNEL: EQU 5

FAMISTUDIO_FIRST_POSITIVE_SLIDE_CHANNEL: EQU 3

;======================================================================================================================
; RAM VARIABLES (You should not have to play with these)
;======================================================================================================================


famistudio_env_value: EQU $0502
famistudio_env_repeat: EQU $050D
famistudio_env_addr_lo: EQU $0518
famistudio_env_addr_hi: EQU $0523
famistudio_env_ptr: EQU $052E

famistudio_pitch_env_value_lo: EQU $0539
famistudio_pitch_env_value_hi: EQU $053C
famistudio_pitch_env_repeat: EQU $053F
famistudio_pitch_env_addr_lo: EQU $0542
famistudio_pitch_env_addr_hi: EQU $0545
famistudio_pitch_env_ptr: EQU $0548
famistudio_pitch_env_fine_value: EQU $054B

famistudio_slide_step: EQU $054E
famistudio_slide_pitch_lo: EQU $0551
famistudio_slide_pitch_hi: EQU $0554

famistudio_chn_ptr_lo: EQU $0557
famistudio_chn_ptr_hi: EQU $055C
famistudio_chn_note: EQU $0561
famistudio_chn_repeat: EQU $0566
famistudio_chn_return_lo: EQU $056B
famistudio_chn_return_hi: EQU $0570
famistudio_chn_ref_len: EQU $0575
famistudio_chn_volume_track: EQU $057A
famistudio_chn_env_override: EQU $057F

famistudio_tempo_env_ptr_lo: EQU $0584
famistudio_tempo_env_ptr_hi: EQU $0585
famistudio_tempo_env_counter: EQU $0586
famistudio_tempo_env_idx: EQU $0587
famistudio_tempo_frame_num: EQU $0588
famistudio_tempo_frame_cnt: EQU $0589

famistudio_pal_adjust: EQU $058A
famistudio_song_list_lo: EQU $058B
famistudio_song_list_hi: EQU $058C
famistudio_instrument_lo: EQU $058D
famistudio_instrument_hi: EQU $058E
famistudio_dpcm_list_lo: EQU $058F
famistudio_dpcm_list_hi: EQU $0590
famistudio_dpcm_effect: EQU $0591
famistudio_pulse1_prev: EQU $0592
famistudio_pulse2_prev: EQU $0593
famistudio_song_speed: EQU $0594




; FDS, N163 and VRC7 have very different instrument layout and are 16-bytes, so we keep them seperate.


;======================================================================================================================
; ZEROPAGE VARIABLES
;
; These are only used as temporary variable during the famistudio_xxx calls.
; Feel free to alias those with other ZP values in your programs to save a few bytes.
;======================================================================================================================


famistudio_r0: EQU $0002
famistudio_r1: EQU $0003
famistudio_r2: EQU $0004
famistudio_r3: EQU $0005

famistudio_ptr0: EQU $0006
famistudio_ptr1: EQU $0008

famistudio_ptr0_lo: EQU famistudio_ptr0+0
famistudio_ptr0_hi: EQU famistudio_ptr0+1
famistudio_ptr1_lo: EQU famistudio_ptr1+0
famistudio_ptr1_hi: EQU famistudio_ptr1+1

;======================================================================================================================
; CODE
;======================================================================================================================


FAMISTUDIO_APU_PL1_VOL: EQU $4000
FAMISTUDIO_APU_PL1_SWEEP: EQU $4001
FAMISTUDIO_APU_PL1_LO: EQU $4002
FAMISTUDIO_APU_PL1_HI: EQU $4003
FAMISTUDIO_APU_PL2_VOL: EQU $4004
FAMISTUDIO_APU_PL2_SWEEP: EQU $4005
FAMISTUDIO_APU_PL2_LO: EQU $4006
FAMISTUDIO_APU_PL2_HI: EQU $4007
FAMISTUDIO_APU_TRI_LINEAR: EQU $4008
FAMISTUDIO_APU_TRI_LO: EQU $400a
FAMISTUDIO_APU_TRI_HI: EQU $400b
FAMISTUDIO_APU_NOISE_VOL: EQU $400c
FAMISTUDIO_APU_NOISE_LO: EQU $400e
FAMISTUDIO_APU_NOISE_HI: EQU $400f
FAMISTUDIO_APU_DMC_FREQ: EQU $4010
FAMISTUDIO_APU_DMC_RAW: EQU $4011
FAMISTUDIO_APU_DMC_START: EQU $4012
FAMISTUDIO_APU_DMC_LEN: EQU $4013
FAMISTUDIO_APU_SND_CHN: EQU $4015
FAMISTUDIO_APU_FRAME_CNT: EQU $4017

FAMISTUDIO_VRC6_PL1_VOL: EQU $9000
FAMISTUDIO_VRC6_PL1_LO: EQU $9001
FAMISTUDIO_VRC6_PL1_HI: EQU $9002
FAMISTUDIO_VRC6_FREQ_CTRL: EQU $9003
FAMISTUDIO_VRC6_PL2_VOL: EQU $a000
FAMISTUDIO_VRC6_PL2_LO: EQU $a001
FAMISTUDIO_VRC6_PL2_HI: EQU $a002
FAMISTUDIO_VRC6_SAW_VOL: EQU $b000
FAMISTUDIO_VRC6_SAW_LO: EQU $b001
FAMISTUDIO_VRC6_SAW_HI: EQU $b002

FAMISTUDIO_VRC7_SILENCE: EQU $e000
FAMISTUDIO_VRC7_REG_SEL: EQU $9010
FAMISTUDIO_VRC7_REG_WRITE: EQU $9030
FAMISTUDIO_VRC7_REG_LO_1: EQU $10
FAMISTUDIO_VRC7_REG_LO_2: EQU $11
FAMISTUDIO_VRC7_REG_LO_3: EQU $12
FAMISTUDIO_VRC7_REG_LO_4: EQU $13
FAMISTUDIO_VRC7_REG_LO_5: EQU $14
FAMISTUDIO_VRC7_REG_LO_6: EQU $15
FAMISTUDIO_VRC7_REG_HI_1: EQU $20
FAMISTUDIO_VRC7_REG_HI_2: EQU $21
FAMISTUDIO_VRC7_REG_HI_3: EQU $22
FAMISTUDIO_VRC7_REG_HI_4: EQU $23
FAMISTUDIO_VRC7_REG_HI_5: EQU $24
FAMISTUDIO_VRC7_REG_HI_6: EQU $25
FAMISTUDIO_VRC7_REG_VOL_1: EQU $30
FAMISTUDIO_VRC7_REG_VOL_2: EQU $31
FAMISTUDIO_VRC7_REG_VOL_3: EQU $32
FAMISTUDIO_VRC7_REG_VOL_4: EQU $33
FAMISTUDIO_VRC7_REG_VOL_5: EQU $34
FAMISTUDIO_VRC7_REG_VOL_6: EQU $35

FAMISTUDIO_EPSM_REG_SEL0: EQU $401c
FAMISTUDIO_EPSM_REG_WRITE0: EQU $401d
FAMISTUDIO_EPSM_REG_SEL1: EQU $401e
FAMISTUDIO_EPSM_REG_WRITE1: EQU $401f
FAMISTUDIO_EPSM_REG_KEY: EQU $28
FAMISTUDIO_EPSM_REG_DT_MUL: EQU $30
FAMISTUDIO_EPSM_REG_TL: EQU $40
FAMISTUDIO_EPSM_REG_KS_AR: EQU $50
FAMISTUDIO_EPSM_REG_AMO_DR: EQU $60
FAMISTUDIO_EPSM_REG_SR: EQU $70
FAMISTUDIO_EPSM_REG_SL_RR: EQU $80
FAMISTUDIO_EPSM_REG_SSG: EQU $90
FAMISTUDIO_EPSM_REG_FN_LO: EQU $A0
FAMISTUDIO_EPSM_REG_FN_LO2: EQU $A1
FAMISTUDIO_EPSM_REG_FN_LO3: EQU $A2
FAMISTUDIO_EPSM_REG_FN_HI: EQU $A4
FAMISTUDIO_EPSM_REG_FN_HI2: EQU $A5
FAMISTUDIO_EPSM_REG_FN_HI3: EQU $A6
FAMISTUDIO_EPSM_REG_FB: EQU $B0
FAMISTUDIO_EPSM_REG_AM_PM: EQU $B4
FAMISTUDIO_EPSM_REG_LFO: EQU $22
FAMISTUDIO_EPSM_REG_RHY_KY: EQU $10
FAMISTUDIO_EPSM_REG_RHY_BD: EQU $18
FAMISTUDIO_EPSM_REG_RHY_SD: EQU $19
FAMISTUDIO_EPSM_REG_RHY_TC: EQU $1a
FAMISTUDIO_EPSM_REG_RHY_HH: EQU $1b
FAMISTUDIO_EPSM_REG_RHY_TOM: EQU $1c
FAMISTUDIO_EPSM_REG_RHY_RIM: EQU $1d
FAMISTUDIO_EPSM_REG_LO_1: EQU $10
FAMISTUDIO_EPSM_REG_LO_2: EQU $11
FAMISTUDIO_EPSM_REG_LO_3: EQU $12
FAMISTUDIO_EPSM_REG_LO_4: EQU $13
FAMISTUDIO_EPSM_REG_LO_5: EQU $14
FAMISTUDIO_EPSM_REG_LO_6: EQU $15
FAMISTUDIO_EPSM_REG_HI_1: EQU $20
FAMISTUDIO_EPSM_REG_HI_2: EQU $21
FAMISTUDIO_EPSM_REG_HI_3: EQU $22
FAMISTUDIO_EPSM_REG_HI_4: EQU $23
FAMISTUDIO_EPSM_REG_HI_5: EQU $24
FAMISTUDIO_EPSM_REG_HI_6: EQU $25
FAMISTUDIO_EPSM_REG_VOL_1: EQU $30
FAMISTUDIO_EPSM_REG_VOL_2: EQU $31
FAMISTUDIO_EPSM_REG_VOL_3: EQU $32
FAMISTUDIO_EPSM_REG_VOL_4: EQU $33
FAMISTUDIO_EPSM_REG_VOL_5: EQU $34
FAMISTUDIO_EPSM_REG_VOL_6: EQU $35
FAMISTUDIO_EPSM_ADDR: EQU $401c
FAMISTUDIO_EPSM_DATA: EQU $401d
FAMISTUDIO_EPSM_REG_LO_A: EQU $00
FAMISTUDIO_EPSM_REG_HI_A: EQU $01
FAMISTUDIO_EPSM_REG_LO_B: EQU $02
FAMISTUDIO_EPSM_REG_HI_B: EQU $03
FAMISTUDIO_EPSM_REG_LO_C: EQU $04
FAMISTUDIO_EPSM_REG_HI_C: EQU $05
FAMISTUDIO_EPSM_REG_NOISE: EQU $06
FAMISTUDIO_EPSM_REG_TONE: EQU $07
FAMISTUDIO_EPSM_REG_VOL_A: EQU $08
FAMISTUDIO_EPSM_REG_VOL_B: EQU $09
FAMISTUDIO_EPSM_REG_VOL_C: EQU $0a
FAMISTUDIO_EPSM_REG_ENV_LO: EQU $0b
FAMISTUDIO_EPSM_REG_ENV_HI: EQU $0c
FAMISTUDIO_EPSM_REG_SHAPE: EQU $0d
FAMISTUDIO_EPSM_REG_IO_A: EQU $0e
FAMISTUDIO_EPSM_REG_IO_B: EQU $0f

FAMISTUDIO_MMC5_PL1_VOL: EQU $5000
FAMISTUDIO_MMC5_PL1_SWEEP: EQU $5001
FAMISTUDIO_MMC5_PL1_LO: EQU $5002
FAMISTUDIO_MMC5_PL1_HI: EQU $5003
FAMISTUDIO_MMC5_PL2_VOL: EQU $5004
FAMISTUDIO_MMC5_PL2_SWEEP: EQU $5005
FAMISTUDIO_MMC5_PL2_LO: EQU $5006
FAMISTUDIO_MMC5_PL2_HI: EQU $5007
FAMISTUDIO_MMC5_PCM_MODE: EQU $5010
FAMISTUDIO_MMC5_SND_CHN: EQU $5015
FAMISTUDIO_MMC5_EXRAM_MODE: EQU $5104

FAMISTUDIO_N163_SILENCE: EQU $e000
FAMISTUDIO_N163_ADDR: EQU $f800
FAMISTUDIO_N163_DATA: EQU $4800
FAMISTUDIO_N163_REG_FREQ_LO: EQU $78
FAMISTUDIO_N163_REG_PHASE_LO: EQU $79
FAMISTUDIO_N163_REG_FREQ_MID: EQU $7a
FAMISTUDIO_N163_REG_PHASE_MID: EQU $7b
FAMISTUDIO_N163_REG_FREQ_HI: EQU $7c
FAMISTUDIO_N163_REG_PHASE_HI: EQU $7d
FAMISTUDIO_N163_REG_WAVE: EQU $7e
FAMISTUDIO_N163_REG_VOLUME: EQU $7f

FAMISTUDIO_S5B_ADDR: EQU $c000
FAMISTUDIO_S5B_DATA: EQU $e000
FAMISTUDIO_S5B_REG_LO_A: EQU $00
FAMISTUDIO_S5B_REG_HI_A: EQU $01
FAMISTUDIO_S5B_REG_LO_B: EQU $02
FAMISTUDIO_S5B_REG_HI_B: EQU $03
FAMISTUDIO_S5B_REG_LO_C: EQU $04
FAMISTUDIO_S5B_REG_HI_C: EQU $05
FAMISTUDIO_S5B_REG_NOISE: EQU $06
FAMISTUDIO_S5B_REG_TONE: EQU $07
FAMISTUDIO_S5B_REG_VOL_A: EQU $08
FAMISTUDIO_S5B_REG_VOL_B: EQU $09
FAMISTUDIO_S5B_REG_VOL_C: EQU $0a
FAMISTUDIO_S5B_REG_ENV_LO: EQU $0b
FAMISTUDIO_S5B_REG_ENV_HI: EQU $0c
FAMISTUDIO_S5B_REG_SHAPE: EQU $0d
FAMISTUDIO_S5B_REG_IO_A: EQU $0e
FAMISTUDIO_S5B_REG_IO_B: EQU $0f

FAMISTUDIO_FDS_WAV_START: EQU $4040
FAMISTUDIO_FDS_VOL_ENV: EQU $4080
FAMISTUDIO_FDS_FREQ_LO: EQU $4082
FAMISTUDIO_FDS_FREQ_HI: EQU $4083
FAMISTUDIO_FDS_SWEEP_ENV: EQU $4084
FAMISTUDIO_FDS_SWEEP_BIAS: EQU $4085
FAMISTUDIO_FDS_MOD_LO: EQU $4086
FAMISTUDIO_FDS_MOD_HI: EQU $4087
FAMISTUDIO_FDS_MOD_TABLE: EQU $4088
FAMISTUDIO_FDS_VOL: EQU $4089
FAMISTUDIO_FDS_ENV_SPEED: EQU $408A

; Output directly to APU
FAMISTUDIO_ALIAS_PL1_VOL: EQU FAMISTUDIO_APU_PL1_VOL
FAMISTUDIO_ALIAS_PL1_LO: EQU FAMISTUDIO_APU_PL1_LO
FAMISTUDIO_ALIAS_PL1_HI: EQU FAMISTUDIO_APU_PL1_HI
FAMISTUDIO_ALIAS_PL2_VOL: EQU FAMISTUDIO_APU_PL2_VOL
FAMISTUDIO_ALIAS_PL2_LO: EQU FAMISTUDIO_APU_PL2_LO
FAMISTUDIO_ALIAS_PL2_HI: EQU FAMISTUDIO_APU_PL2_HI
FAMISTUDIO_ALIAS_TRI_LINEAR: EQU FAMISTUDIO_APU_TRI_LINEAR
FAMISTUDIO_ALIAS_TRI_LO: EQU FAMISTUDIO_APU_TRI_LO
FAMISTUDIO_ALIAS_TRI_HI: EQU FAMISTUDIO_APU_TRI_HI
FAMISTUDIO_ALIAS_NOISE_VOL: EQU FAMISTUDIO_APU_NOISE_VOL
FAMISTUDIO_ALIAS_NOISE_LO: EQU FAMISTUDIO_APU_NOISE_LO

;======================================================================================================================
; FAMISTUDIO_INIT (public)
;
; Reset APU, initialize the sound engine with some music data.
; 
; [in] a : Playback platform, zero for PAL, non-zero for NTSC.
; [in] x : Pointer to music data (lo)
; [in] y : Pointer to music data (hi)
;======================================================================================================================

famistudio_init:
    
.music_data_ptr: EQU famistudio_ptr0

    stx famistudio_song_list_lo
    sty famistudio_song_list_hi
    stx .music_data_ptr+0
    sty .music_data_ptr+1

        lda #97
    sta famistudio_pal_adjust

    jsr famistudio_music_stop

    ; Instrument address
    ldy #1
    lda (.music_data_ptr),y
    sta famistudio_instrument_lo
    iny
    lda (.music_data_ptr),y
    sta famistudio_instrument_hi
    iny

    ; Expansions instrument address

    ; Sample list address
    lda (.music_data_ptr),y
    sta famistudio_dpcm_list_lo
    iny
    lda (.music_data_ptr),y
    sta famistudio_dpcm_list_hi

    lda #$80 ; Previous pulse period MSB, to not write it when not changed
    sta famistudio_pulse1_prev
    sta famistudio_pulse2_prev

    lda #$0f ; Enable channels, stop DMC
    sta FAMISTUDIO_APU_SND_CHN
    lda #$80 ; Disable triangle length counter
    sta FAMISTUDIO_APU_TRI_LINEAR
    lda #$00 ; Load noise length
    sta FAMISTUDIO_APU_NOISE_HI

    lda #$30 ; Volumes to 0
    sta FAMISTUDIO_APU_PL1_VOL
    sta FAMISTUDIO_APU_PL2_VOL
    sta FAMISTUDIO_APU_NOISE_VOL
    lda #$08 ; No sweep
    sta FAMISTUDIO_APU_PL1_SWEEP
    sta FAMISTUDIO_APU_PL2_SWEEP



.init_epsm:


    jmp famistudio_music_stop

;======================================================================================================================
; FAMISTUDIO_MUSIC_STOP (public)
;
; Stops any music currently playing, if any. Note that this will not update the APU, so sound might linger. Calling
; famistudio_update after this will update the APU.
; 
; [in] no input params.
;======================================================================================================================

famistudio_music_stop:

    lda #0
    sta famistudio_song_speed
    sta famistudio_dpcm_effect

    ldx #0

.set_channels:

    sta famistudio_chn_repeat,x
    sta famistudio_chn_note,x
    sta famistudio_chn_ref_len,x
        sta famistudio_chn_volume_track,x
        sta famistudio_chn_env_override,x
    inx
    cpx #FAMISTUDIO_NUM_CHANNELS
    bne .set_channels


    ldx #0
.set_slides:

    sta famistudio_slide_step, x
    inx
    cpx #FAMISTUDIO_NUM_SLIDES
    bne .set_slides


    ldx #0

.set_envelopes:

    lda #(famistudio_dummy_envelope & $FF)
    sta famistudio_env_addr_lo,x
    lda #(famistudio_dummy_envelope >> 8)
    sta famistudio_env_addr_hi,x
    lda #0
    sta famistudio_env_repeat,x
    sta famistudio_env_value,x
    sta famistudio_env_ptr,x
    inx
    cpx #FAMISTUDIO_NUM_ENVELOPES
    bne .set_envelopes

    ldx #0
.set_pitch_envelopes:

    lda #(famistudio_dummy_pitch_envelope & $FF)
    sta famistudio_pitch_env_addr_lo,x
    lda #(famistudio_dummy_pitch_envelope >> 8)
    sta famistudio_pitch_env_addr_hi,x
    lda #0
    sta famistudio_pitch_env_repeat,x
    sta famistudio_pitch_env_value_lo,x
    sta famistudio_pitch_env_value_hi,x
        sta famistudio_pitch_env_fine_value,x
    lda #1
    sta famistudio_pitch_env_ptr,x
    inx
    cpx #FAMISTUDIO_NUM_PITCH_ENVELOPES
    bne .set_pitch_envelopes

    jmp famistudio_sample_stop

;======================================================================================================================
; FAMISTUDIO_MUSIC_PLAY (public)
;
; Plays a song from the loaded music data (from a previous call to famistudio_init).
; 
; [in] a : Song index.
;======================================================================================================================

famistudio_music_play:

.tmp: EQU famistudio_r0
.song_list_ptr: EQU famistudio_ptr0
.temp_env_ptr: EQU famistudio_ptr1

    ldx famistudio_song_list_lo
    stx .song_list_ptr+0
    ldx famistudio_song_list_hi
    stx .song_list_ptr+1

    ldy #0
    cmp (.song_list_ptr),y
    bcc .valid_song
    rts ; Invalid song index.

.valid_song:
    ; Here we basically assume we have 17 songs or less (17 songs * 14 bytes per song + 5 bytes header < 256).
    asl a
    sta .tmp
    asl a
    tax
    asl a
    adc .tmp
    stx .tmp
    adc .tmp
    adc #5 ; Song count + instrument ptr + sample ptr
    tay

    jsr famistudio_music_stop

    ldx #0

.set_channels:

    ; Channel data address
    lda (.song_list_ptr),y
    sta famistudio_chn_ptr_lo,x
    iny
    lda (.song_list_ptr),y
    sta famistudio_chn_ptr_hi,x
    iny

    lda #0
    sta famistudio_chn_repeat,x
    sta famistudio_chn_note,x
    sta famistudio_chn_ref_len,x
        lda #$f0
        sta famistudio_chn_volume_track,x

.nextchannel:
    inx
    cpx #FAMISTUDIO_NUM_CHANNELS
    bne .set_channels

    lda (.song_list_ptr),y
    sta famistudio_tempo_env_ptr_lo
    sta .temp_env_ptr+0
    iny
    lda (.song_list_ptr),y
    sta famistudio_tempo_env_ptr_hi
    sta .temp_env_ptr+1
    iny
    lda (.song_list_ptr),y
    tax
    lda famistudio_tempo_frame_lookup, x ; Lookup contains the number of frames to run (0,1,2) to maintain tempo
    sta famistudio_tempo_frame_num
    ldy #0
    sty famistudio_tempo_env_idx
    lda (.temp_env_ptr),y
    clc 
    adc #1
    sta famistudio_tempo_env_counter
    lda #6
    sta famistudio_song_speed ; Non-zero simply so the song isnt considered paused.









.skip:
    rts

;======================================================================================================================
; FAMISTUDIO_MUSIC_PAUSE (public)
;
; Pause/unpause the currently playing song. Note that this will not update the APU, so sound might linger. Calling
; famistudio_update after this will update the APU.
; 
; [in] a : zero to play, non-zero to pause.
;======================================================================================================================

famistudio_music_pause:

    tax
    beq .unpause
    
.pause:

    jsr famistudio_sample_stop
    
    lda #0
    sta famistudio_env_value+FAMISTUDIO_CH0_ENVS+FAMISTUDIO_ENV_VOLUME_OFF
    sta famistudio_env_value+FAMISTUDIO_CH1_ENVS+FAMISTUDIO_ENV_VOLUME_OFF
    sta famistudio_env_value+FAMISTUDIO_CH2_ENVS+FAMISTUDIO_ENV_VOLUME_OFF
    sta famistudio_env_value+FAMISTUDIO_CH3_ENVS+FAMISTUDIO_ENV_VOLUME_OFF
    lda famistudio_song_speed ; <= 0 pauses the music
    ora #$80
    bne .done
.unpause:
    lda famistudio_song_speed ; > 0 unpause music
    and #$7f
.done:
    sta famistudio_song_speed

    rts

;======================================================================================================================
; FAMISTUDIO_GET_NOTE_PITCH_MACRO (internal)
;
; Uber-macro used to compute the final pitch of a note, taking into account the current note, arpeggios, instrument
; pitch envelopes, slide notes and fine pitch tracks.
; 
; [in] x : note index.
; [in] y : slide/pitch envelope index.
; [out] famistudio_ptr1 : Final note pitch.
;======================================================================================================================


famistudio_get_note_pitch:

;note_table_lsb_M0001 = famistudio_note_table_lsb ; Getting "Internal error" when trying to do this.
;note_table_msb_M0001 = famistudio_note_table_msb ; Getting "Internal error" when trying to do this.



    ; Pitch envelope + fine pitch (sign extended)
    clc
    lda famistudio_pitch_env_fine_value+0, y 
    adc famistudio_pitch_env_value_lo+0, y 
    sta famistudio_ptr1+0
    lda famistudio_pitch_env_fine_value+0, y 
    and #$80
    beq .pos
    lda #$ff
.pos:
    adc famistudio_pitch_env_value_hi+0, y 
    sta famistudio_ptr1+1


    ; Check if there is an active slide.
    lda famistudio_slide_step+0, y 
    beq .no_slide

    ; Add slide
    ; Most channels have 1 bit of fraction for slides.
    lda famistudio_slide_pitch_hi+0, y 
    cmp #$80 ; Sign extend upcoming right shift.
    ror a ; We have 1 bit of fraction for slides, shift right hi byte.
    sta famistudio_r0
    lda famistudio_slide_pitch_lo+0, y 
    ror a ; Shift right low byte.
    clc
    adc famistudio_ptr1+0
    sta famistudio_ptr1+0
    lda famistudio_r0
    adc famistudio_ptr1+1 
    sta famistudio_ptr1+1 

.no_slide:    


    ; Finally, add note pitch.
    clc
    lda famistudio_note_table_lsb,x ; famistudio_note_table_lsb = note_table_lsb
    adc famistudio_ptr1+0
    sta famistudio_ptr1+0
    lda famistudio_note_table_msb,x ; famistudio_note_table_msb = note_table_msb
    adc famistudio_ptr1+1
    sta famistudio_ptr1+1   

    rts


;======================================================================================================================
; FAMISTUDIO_SMOOTH_VIBRATO (internal)
;
; Implementation of Blaarg's smooth vibrato to eliminate pops on square channels. Called either from regular channel
; updates or from SFX code.
;
; [in] a : new hi period.
;======================================================================================================================


;======================================================================================================================
; FAMISTUDIO_UPDATE_CHANNEL_SOUND (internal)
;
; Uber-macro used to update the APU registers for a given 2A03/VRC6/MMC5 channel. This macro is an absolute mess, but
; it is still more maintainable than having many different functions.
;
; [in] no input params.
;======================================================================================================================










;======================================================================================================================
; FAMISTUDIO_UPDATE (public)
;
; Main update function, should be called once per frame, ideally at the end of NMI. Will update the tempo, advance
; the song if needed, update instrument and apply any change to the APU registers.
;
; [in] no input params.
;======================================================================================================================

famistudio_update:

.pitch_env_type: EQU famistudio_r0
.temp_pitch: EQU famistudio_r1
.tempo_env_ptr: EQU famistudio_ptr0
.env_ptr: EQU famistudio_ptr0
.pitch_env_ptr: EQU famistudio_ptr0


    lda famistudio_song_speed ; Speed 0 means that no music is playing currently
    bmi .pause ; Bit 7 set is the pause flag
    bne .update
.pause:
    lda #1
    sta famistudio_tempo_frame_cnt
    jmp .update_sound

;----------------------------------------------------------------------------------------------------------------------
.update:


    ; Decrement envelope counter, see if we need to advance.
    dec famistudio_tempo_env_counter
    beq .advance_tempo_envelope
    lda #1
    jmp .store_frame_count

.advance_tempo_envelope:
    ; Advance the envelope by one step.
    lda famistudio_tempo_env_ptr_lo
    sta .tempo_env_ptr+0
    lda famistudio_tempo_env_ptr_hi
    sta .tempo_env_ptr+1

    inc famistudio_tempo_env_idx
    ldy famistudio_tempo_env_idx
    lda (.tempo_env_ptr),y
    bpl .store_counter ; Negative value means we loop back to to index 1.

.tempo_envelope_end:
    ldy #1
    sty famistudio_tempo_env_idx
    lda (.tempo_env_ptr),y

.store_counter:
    ; Reset the counter
    sta famistudio_tempo_env_counter
    lda famistudio_tempo_frame_num
    bne .store_frame_count
    jmp .skip_frame

.store_frame_count:
    sta famistudio_tempo_frame_cnt


;----------------------------------------------------------------------------------------------------------------------
.advance_song:
    ldx #0
    .channel_loop:
            cpx #4
            beq .channel_loop_end
            jsr famistudio_advance_channel
        .channel_loop_end:
        inx
        cpx #FAMISTUDIO_NUM_CHANNELS
        bne .channel_loop

;----------------------------------------------------------------------------------------------------------------------
.update_envelopes:
    ldx #0

.env_process:
    lda famistudio_env_repeat,x
    beq .env_read  
    dec famistudio_env_repeat,x
    bne .env_next

.env_read:
    lda famistudio_env_addr_lo,x
    sta .env_ptr+0
    lda famistudio_env_addr_hi,x
    sta .env_ptr+1
    ldy famistudio_env_ptr,x

.env_read_value:
    lda (.env_ptr),y
    bpl .env_special ; Values below 128 used as a special code, loop or repeat
    clc              ; Values above 128 are output value+192 (output values are signed -63..64)
    adc #256-192
    sta famistudio_env_value,x
    iny
    bne .env_next_store_ptr

.env_special:
    bne .env_set_repeat  ; Zero is the loop point, non-zero values used for the repeat counter
    iny
    lda (.env_ptr),y     ; Read loop position
    tay
    jmp .env_read_value

.env_set_repeat:
    iny
    sta famistudio_env_repeat,x ; Store the repeat counter value

.env_next_store_ptr:
    tya
    sta famistudio_env_ptr,x

.env_next:
    inx

    cpx #FAMISTUDIO_NUM_ENVELOPES
    bne .env_process

;----------------------------------------------------------------------------------------------------------------------
.update_pitch_envelopes:
    ldx #0
    jmp .pitch_env_process

.pitch_env_process:
    lda famistudio_pitch_env_repeat,x
    beq .pitch_env_read
    dec famistudio_pitch_env_repeat,x
    bne .pitch_env_next

.pitch_env_read:
    lda famistudio_pitch_env_addr_lo,x 
    sta .pitch_env_ptr+0
    lda famistudio_pitch_env_addr_hi,x
    sta .pitch_env_ptr+1
    ldy #0
    lda (.pitch_env_ptr),y
    sta .pitch_env_type ; First value is 0 for absolute envelope, 0x80 for relative.
    ldy famistudio_pitch_env_ptr,x

.pitch_env_read_value:
    lda (.pitch_env_ptr),y
    bpl .pitch_env_special 
    clc  
    adc #256-192
    bit .pitch_env_type
    bmi .pitch_relative

.pitch_absolute:
    sta famistudio_pitch_env_value_lo,x
    ora #0
    bmi .pitch_absolute_neg  
    lda #0
    jmp .pitch_absolute_set_value_hi
.pitch_absolute_neg:
    lda #$ff
.pitch_absolute_set_value_hi:
    sta famistudio_pitch_env_value_hi,x
    iny 
    jmp .pitch_env_next_store_ptr

.pitch_relative:
    sta .temp_pitch
    clc
    adc famistudio_pitch_env_value_lo,x
    sta famistudio_pitch_env_value_lo,x
    lda .temp_pitch
    and #$80
    bpl .pitch_relative_pos  
    lda #$ff
.pitch_relative_pos:
    adc famistudio_pitch_env_value_hi,x
    sta famistudio_pitch_env_value_hi,x
    iny 
    jmp .pitch_env_next_store_ptr

.pitch_env_special:
    bne .pitch_env_set_repeat
    iny 
    lda (.pitch_env_ptr),y 
    tay
    jmp .pitch_env_read_value 

.pitch_env_set_repeat:
    iny
    ora .pitch_env_type ; This is going to set the relative flag in the hi-bit.
    sta famistudio_pitch_env_repeat,x

.pitch_env_next_store_ptr:
    tya 
    sta famistudio_pitch_env_ptr,x

.pitch_env_next:
    inx 

    cpx #FAMISTUDIO_NUM_PITCH_ENVELOPES
    bne .pitch_env_process

;----------------------------------------------------------------------------------------------------------------------
.update_slides:
    ldx #0

.slide_process:
    lda famistudio_slide_step,x ; Zero repeat means no active slide.
    beq .slide_next
    clc ; Add step to slide pitch (16bit + 8bit signed).
    lda famistudio_slide_step,x
    adc famistudio_slide_pitch_lo,x
    sta famistudio_slide_pitch_lo,x
    lda famistudio_slide_step,x
    and #$80
    beq .positive_slide

.negative_slide:
    lda #$ff
    adc famistudio_slide_pitch_hi,x
    sta famistudio_slide_pitch_hi,x
    bpl .slide_next
    jmp .clear_slide

.positive_slide:
    adc famistudio_slide_pitch_hi,x
    sta famistudio_slide_pitch_hi,x
    bmi .slide_next

.clear_slide:
    lda #0
    sta famistudio_slide_step,x

.slide_next:
    inx 
    cpx #FAMISTUDIO_NUM_SLIDES
    bne .slide_process



;----------------------------------------------------------------------------------------------------------------------
.update_sound:




    lda famistudio_chn_note+0
    bne .nocut_M0002
    jmp .set_volume_M0002

.nocut_M0002:
    clc
    adc famistudio_env_value+FAMISTUDIO_CH0_ENVS+FAMISTUDIO_ENV_NOTE_OFF


    tax

    ; This basically does same as "famistudio_channel_to_pitch_env"
        ldy #0

        jsr famistudio_get_note_pitch

    lda famistudio_ptr1+0
    sta FAMISTUDIO_ALIAS_PL1_LO
    lda famistudio_ptr1+1

                cmp famistudio_pulse1_prev
                beq .compute_volume_M0002
                sta famistudio_pulse1_prev


    sta FAMISTUDIO_ALIAS_PL1_HI

.compute_volume_M0002:

        lda famistudio_chn_volume_track+0
        ora famistudio_env_value+FAMISTUDIO_CH0_ENVS+FAMISTUDIO_ENV_VOLUME_OFF
        tax
        lda famistudio_volume_table, x 


.set_volume_M0002:

    ldx famistudio_env_value+FAMISTUDIO_CH0_ENVS+FAMISTUDIO_ENV_DUTY_OFF
    ora famistudio_duty_lookup, x

    ; HACK : We are out of macro param for NESASM.

    sta FAMISTUDIO_ALIAS_PL1_VOL




    lda famistudio_chn_note+1
    bne .nocut_M0004
    jmp .set_volume_M0004

.nocut_M0004:
    clc
    adc famistudio_env_value+FAMISTUDIO_CH1_ENVS+FAMISTUDIO_ENV_NOTE_OFF


    tax

    ; This basically does same as "famistudio_channel_to_pitch_env"
        ldy #1

        jsr famistudio_get_note_pitch

    lda famistudio_ptr1+0
    sta FAMISTUDIO_ALIAS_PL2_LO
    lda famistudio_ptr1+1

                cmp famistudio_pulse2_prev
                beq .compute_volume_M0004
                sta famistudio_pulse2_prev


    sta FAMISTUDIO_ALIAS_PL2_HI

.compute_volume_M0004:

        lda famistudio_chn_volume_track+1
        ora famistudio_env_value+FAMISTUDIO_CH1_ENVS+FAMISTUDIO_ENV_VOLUME_OFF
        tax
        lda famistudio_volume_table, x 


.set_volume_M0004:

    ldx famistudio_env_value+FAMISTUDIO_CH1_ENVS+FAMISTUDIO_ENV_DUTY_OFF
    ora famistudio_duty_lookup, x

    ; HACK : We are out of macro param for NESASM.

    sta FAMISTUDIO_ALIAS_PL2_VOL




    lda famistudio_chn_note+2
    bne .nocut_M0006
    jmp .set_volume_M0006

.nocut_M0006:
    clc
    adc famistudio_env_value+FAMISTUDIO_CH2_ENVS+FAMISTUDIO_ENV_NOTE_OFF


    tax

    ; This basically does same as "famistudio_channel_to_pitch_env"
        ldy #2

        jsr famistudio_get_note_pitch

    lda famistudio_ptr1+0
    sta FAMISTUDIO_ALIAS_TRI_LO
    lda famistudio_ptr1+1



    sta FAMISTUDIO_ALIAS_TRI_HI

.compute_volume_M0006:

        lda famistudio_chn_volume_track+2
        ora famistudio_env_value+FAMISTUDIO_CH2_ENVS+FAMISTUDIO_ENV_VOLUME_OFF
        tax
        lda famistudio_volume_table, x 


.set_volume_M0006:


    ; HACK : We are out of macro param for NESASM.
    ora #$80

    sta FAMISTUDIO_ALIAS_TRI_LINEAR




    lda famistudio_chn_note+3
    bne .nocut_M0008
    jmp .set_volume_M0008

.nocut_M0008:
    clc
    adc famistudio_env_value+FAMISTUDIO_CH3_ENVS+FAMISTUDIO_ENV_NOTE_OFF



.no_noise_slide_M0008:
    and #$0f
    eor #$0f
    sta famistudio_r0
    ldx famistudio_env_value+FAMISTUDIO_CH3_ENVS+FAMISTUDIO_ENV_DUTY_OFF
    lda famistudio_duty_lookup, x
    asl a
    and #$80
    ora famistudio_r0


    sta FAMISTUDIO_ALIAS_NOISE_LO

.compute_volume_M0008:

        lda famistudio_chn_volume_track+3
        ora famistudio_env_value+FAMISTUDIO_CH3_ENVS+FAMISTUDIO_ENV_VOLUME_OFF
        tax
        lda famistudio_volume_table, x 


.set_volume_M0008:

    ldx famistudio_env_value+FAMISTUDIO_CH3_ENVS+FAMISTUDIO_ENV_DUTY_OFF
    ora famistudio_duty_lookup, x

    ; HACK : We are out of macro param for NESASM.
    ora #$f0

    sta FAMISTUDIO_ALIAS_NOISE_VOL










.update_sound_done:
    ; See if we need to run a double frame (playing NTSC song on PAL)
    dec famistudio_tempo_frame_cnt
    beq .skip_frame
    jmp .advance_song

.skip_frame:

;----------------------------------------------------------------------------------------------------------------------


    rts

;======================================================================================================================
; FAMISTUDIO_DO_NOTE_ATTACK + EXP VARIANTS (internal)
;
; Internal function to reset all the envelopes of a channnel (note attack).
;
; [in] x/r0 : channel index
;======================================================================================================================






famistudio_do_note_attack:

.chan_idx: EQU famistudio_r0
.tmp_x: EQU famistudio_r2

    lda famistudio_channel_env,x
    tax

    ; Volume envelope.
    lda #1
    sta famistudio_env_ptr,x ; Reset volume envelope pointer to 1 (volume have releases point in index 0)
    lda #0
    sta famistudio_env_repeat,x

    ; Arpeggio envelope
    sta famistudio_env_repeat+FAMISTUDIO_ENV_NOTE_OFF,x
    sta famistudio_env_ptr+FAMISTUDIO_ENV_NOTE_OFF,x

    ; Duty envelope (optional)
    lda .chan_idx
    cmp #2 ; Triangle has no duty.
    beq .no_duty
.duty:
    lda #0
    sta famistudio_env_repeat+FAMISTUDIO_ENV_DUTY_OFF,x
    sta famistudio_env_ptr+FAMISTUDIO_ENV_DUTY_OFF,x
    sta famistudio_env_value+FAMISTUDIO_ENV_DUTY_OFF,x

.no_duty:
    ; Pitch envelope
    ldx .chan_idx
    lda famistudio_channel_to_pitch_env, x
    bmi .no_pitch
    tax

.reset_pitch_env:
    lda #0
    sta famistudio_pitch_env_value_lo,x
    sta famistudio_pitch_env_value_hi,x
    sta famistudio_pitch_env_repeat,x
    lda #1
    sta famistudio_pitch_env_ptr,x     ; Reset pitch envelope pointer to 1 (pitch envelope have relative/absolute flag in the first byte) 

.no_pitch:


.done:
    ldx .chan_idx
    rts
    
;======================================================================================================================
; FAMISTUDIO_LOAD_BASIC_ENVELOPES (internal)
;
; Internal function to load the most common envelopes (volume, arp, duty (optional) and pitch) for an instrument.
;
; [in] x:      first envelope index.
; [in] r0:     instrument index.
; [in] ptr1/y: point to instrument data to load.
;======================================================================================================================

famistudio_load_basic_envelopes:

.instrument_ptr: EQU famistudio_ptr1
.chan_idx: EQU famistudio_r0
.tmp_x: EQU famistudio_r3

    ; Volume envelope
    lda (.instrument_ptr),y
    sta famistudio_env_addr_lo,x
    iny
    lda (.instrument_ptr),y
    iny
    sta famistudio_env_addr_hi,x
    inx

    ; Arpeggio envelope
    stx .tmp_x
    ldx .chan_idx
    lda famistudio_chn_env_override,x ; Check if its overriden by arpeggio.
    lsr a
    ldx .tmp_x
    bcc .arpeggio_envelope 
    iny ; Instrument arpeggio is overriden by arpeggio, dont touch!
    jmp .duty_envelope

.arpeggio_envelope:    
    lda (.instrument_ptr),y
    sta famistudio_env_addr_lo,x
    iny
    lda (.instrument_ptr),y
    sta famistudio_env_addr_hi,x

.duty_envelope:
    ; Duty cycle envelope
    lda .chan_idx
    cmp #2 ; Triangle has no duty.
    beq .no_duty
    .duty:
        inx
        iny
        lda (.instrument_ptr),y
        sta famistudio_env_addr_lo,x
        iny
        lda (.instrument_ptr),y
        sta famistudio_env_addr_hi,x
        jmp .pitch_envelope        
    .no_duty:
        iny
        iny

.pitch_envelope:
    ; Pitch envelopes.
    ldx .chan_idx
    lda famistudio_chn_env_override,x 
    asl a ; Bit-7 tells us if the pitch env is overriden, temporarely store in carry.
    lda famistudio_channel_to_pitch_env, x
    bmi .done
    tax
    ror a ; Bring back our bit-7 from above.
    bpl .no_vibrato ; In bit 7 is set, instrument pitch is overriden by vibrato, dont touch pitch envelope!
    iny
    iny
    bne .done
    .no_vibrato:
    iny
    lda (.instrument_ptr),y
    sta famistudio_pitch_env_addr_lo,x
    iny
    lda (.instrument_ptr),y
    sta famistudio_pitch_env_addr_hi,x
.done:
    rts
    
;======================================================================================================================
; FAMISTUDIO_SET_INSTRUMENT (internal)
;
; Internal function to set an instrument for a given channel. Will initialize all instrument envelopes.
;
; [in] x/r0: channel index
; [in] a:    instrument index.
;======================================================================================================================

famistudio_set_instrument:

.instrument_ptr: EQU famistudio_ptr1
.chan_idx: EQU famistudio_r0

    ; Pre-multiply by 4 if not using extended range, faster pointer arithmetic.
    asl a
    asl a

    ldy .chan_idx
    ldx famistudio_channel_env,y


.base_instrument:

        asl a ; Instrument number is pre multiplied by 4
        tay
        lda famistudio_instrument_hi
        adc #0 ; Use carry to extend range for 64 instruments
        sta .instrument_ptr+1
        lda famistudio_instrument_lo
        sta .instrument_ptr+0

    jmp famistudio_load_basic_envelopes ; Will 'rts'








;======================================================================================================================
; FAMISTUDIO_UPDATE_CHANNEL (internal)
;
; Advances the song by one frame for a given channel. If a new note or effect(s) are found, they will be processed.
;
; [in]  x: channel index
; [out] z: non-zero if we triggered a new note.
;======================================================================================================================

famistudio_advance_channel:

.chan_idx: EQU famistudio_r0
.update_flags: EQU famistudio_r1
.temp_ptr_y: EQU famistudio_r2
.tmp_slide_from: EQU famistudio_r2
.tmp_slide_idx: EQU famistudio_r2
.tmp_duty_cycle: EQU famistudio_r2
.tmp_ptr_lo: EQU famistudio_r2
.tmp_y1: EQU famistudio_r2
.slide_delta_lo: EQU famistudio_ptr1_hi
.tmp_y2: EQU famistudio_ptr1_lo
.channel_data_ptr: EQU famistudio_ptr0
.opcode_jmp_ptr: EQU famistudio_ptr1
.tempo_env_ptr: EQU famistudio_ptr1
.env_ptr: EQU famistudio_ptr1

    lda famistudio_chn_repeat,x
    beq .no_repeat
    dec famistudio_chn_repeat,x
    lda #0
    rts

.no_repeat:
    lda famistudio_chn_ptr_lo,x
    sta .channel_data_ptr+0
    lda famistudio_chn_ptr_hi,x
    sta .channel_data_ptr+1
    ldy #0
    sty .update_flags
    stx .chan_idx    

.read_byte:
    lda (.channel_data_ptr),y
    iny

; $80 to $ff = sequence of empty notes (up to 64) or instrument changes (up to 64)
.check_negative: 
    ora #0
    bmi .empty_notes_or_instrument_change

; $00 to $3f = notes from C1 to D6 (most common notes, same as FT2 range)
; $40 to $6f = opcodes for various things.
.check_regular_note:
    cmp #$40
    bcc .common_note

; $70 to $7f = volume change 
.check_volume_track:
    cmp #$70
    bcc .jmp_to_opcode

.volume_track:    
    and #$0f
    asl a
    asl a
    asl a
    asl a
    sta famistudio_chn_volume_track,x
    ; Clear any volume slide.
    bcc .read_byte

.jmp_to_opcode:
    and #$3f
    tax
    lda .famistudio_opcode_jmp_lo,x
    sta .opcode_jmp_ptr+0
    lda .famistudio_opcode_jmp_hi,x
    sta .opcode_jmp_ptr+1
    ldx .chan_idx
    jmp (.opcode_jmp_ptr)

.empty_notes_or_instrument_change:
    and #$7f
    lsr a
    bcs .set_repeat

.instrument_change:
    ; Set the instrument. `famistudio_set_instrument` (or proc it calls) are not
    ; allowed to clobber r0/r1/r2 or ptr0.
    sty .temp_ptr_y
    jsr famistudio_set_instrument ; Will clobber x/y, need to save/restore them.
    ldy .temp_ptr_y
    ldx .chan_idx
    jmp .read_byte 

.set_repeat:
    sta famistudio_chn_repeat,x ; Set up repeat counter
    bcs .done 

.common_note:
    cmp #0
    beq .play_note
        adc #11 ; Carry is set here.

.play_note:    
    sta famistudio_chn_note,x ; Store note code

.clear_previous_slide:
    lda famistudio_channel_to_slide,x ; Clear any previous slide on new note.
    bmi .cancel_delayed_cut
    tax
    lda #0
    sta famistudio_slide_step,x
    ldx .chan_idx

.cancel_delayed_cut:

.check_dpcm_channel:

.check_attack:
    lda famistudio_chn_note,x
    beq .done
    bit .update_flags
    bmi .done

    ; Note attack. `famistudio_do_note_attack` (or any proc it calls) are not
    ; allowed to clobber r0 or ptr0. They can clobber r1 if they are done using it.
    jsr famistudio_do_note_attack ; Note attack.

.done:
    lda famistudio_chn_ref_len,x ; Check reference row counter
    beq .flush_y                  ; If it is zero, there is no reference
    dec famistudio_chn_ref_len,x ; Decrease row counter
    bne .flush_y

    lda famistudio_chn_return_lo,x ; End of a reference, return to previous pointer
    sta famistudio_chn_ptr_lo,x
    lda famistudio_chn_return_hi,x
    sta famistudio_chn_ptr_hi,x
    rts

.flush_y:

    clc
    tya
    adc .channel_data_ptr+0
    sta famistudio_chn_ptr_lo,x
    lda #0
    adc .channel_data_ptr+1
    sta famistudio_chn_ptr_hi,x
    rts

.opcode_extended_note:
    lda (.channel_data_ptr),y
    iny
    jmp .play_note

.opcode_set_reference:
    clc ; Remember return address+3
    tya
    adc #3
    adc .channel_data_ptr+0
    sta famistudio_chn_return_lo,x
    lda .channel_data_ptr+1
    adc #0
    sta famistudio_chn_return_hi,x
    lda (.channel_data_ptr),y ; Read length of the reference (how many rows)
    sta famistudio_chn_ref_len,x
    iny
    lda (.channel_data_ptr),y ; Read 16-bit absolute address of the reference
    sta .tmp_ptr_lo
    iny
    lda (.channel_data_ptr),y
    sta .channel_data_ptr+1
    lda .tmp_ptr_lo
    sta .channel_data_ptr+0
    ldy #0
    jmp .read_byte

.opcode_loop:
    lda (.channel_data_ptr),y
    sta .tmp_ptr_lo
    iny
    lda (.channel_data_ptr),y
    sta .channel_data_ptr+1
    lda .tmp_ptr_lo
    sta .channel_data_ptr+0
    ldy #0
    jmp .read_byte

.opcode_disable_attack:
    lda #$80
    ora .update_flags
    sta .update_flags
    jmp .read_byte 

.opcode_end_song:
    lda #$80 ; TODO : Should we stop, or just call famistudio_music_stop here?
    sta famistudio_song_speed
    jmp .read_byte

.jump_to_release_envelope:
    lda famistudio_env_addr_lo,x ; Load envelope data address into temp
    sta .env_ptr+0
    lda famistudio_env_addr_hi,x
    sta .env_ptr+1
    
    sty .tmp_y1
    ldy #0
    lda (.env_ptr),y ; Read first byte of the envelope data, this contains the release index.
    beq .env_has_no_release

    sta famistudio_env_ptr,x
    lda #0
    sta famistudio_env_repeat,x ; Need to reset envelope repeat to force update.

.env_has_no_release:
    ldx .chan_idx
    ldy .tmp_y1
    rts





.opcode_release_note:
    lda famistudio_channel_to_volume_env,x ; DPCM(5) will never have releases.
    tax
    jsr .jump_to_release_envelope
    clc
    jmp .done










.opcode_fine_pitch:
    lda famistudio_channel_to_pitch_env,x
    tax
    lda (.channel_data_ptr),y
    iny
    sta famistudio_pitch_env_fine_value,x
    ldx .chan_idx
    jmp .read_byte 

.opcode_clear_pitch_override_flag:
    lda #$7f
    and famistudio_chn_env_override,x
    sta famistudio_chn_env_override,x
    jmp .read_byte 

.opcode_override_pitch_envelope:
    lda #$80
    ora famistudio_chn_env_override,x
    sta famistudio_chn_env_override,x
    lda famistudio_channel_to_pitch_env,x
    tax
    lda (.channel_data_ptr),y
    iny
    sta famistudio_pitch_env_addr_lo,x
    lda (.channel_data_ptr),y
    iny
    sta famistudio_pitch_env_addr_hi,x
    lda #0
    sta famistudio_pitch_env_repeat,x
    lda #1
    sta famistudio_pitch_env_ptr,x
    ldx .chan_idx
    jmp .read_byte 

.opcode_clear_arpeggio_override_flag:
    lda #$fe
    and famistudio_chn_env_override,x
    sta famistudio_chn_env_override,x
    jmp .read_byte

.opcode_override_arpeggio_envelope:
    lda #$01
    ora famistudio_chn_env_override,x
    sta famistudio_chn_env_override,x
    lda famistudio_channel_to_arpeggio_env,x
    tax    
    lda (.channel_data_ptr),y
    iny
    sta famistudio_env_addr_lo,x
    lda (.channel_data_ptr),y
    iny
    sta famistudio_env_addr_hi,x
    lda #0
    sta famistudio_env_repeat,x ; Reset the envelope since this might be a no-attack note.
    sta famistudio_env_value,x
    sta famistudio_env_ptr,x
    ldx .chan_idx
    jmp .read_byte

.opcode_reset_arpeggio:
    lda famistudio_channel_to_arpeggio_env,x
    tax
    lda #0
    sta famistudio_env_repeat,x
    sta famistudio_env_value,x
    sta famistudio_env_ptr,x
    ldx .chan_idx
    jmp .read_byte



.opcode_set_tempo_envelope:
    ; Load and reset the new tempo envelope.
    lda (.channel_data_ptr),y
    iny
    sta famistudio_tempo_env_ptr_lo
    sta .tempo_env_ptr+0
    lda (.channel_data_ptr),y
    iny
    sta famistudio_tempo_env_ptr_hi
    sta .tempo_env_ptr+1
    jmp .reset_tempo_env
.opcode_reset_tempo_envelope:
    lda famistudio_tempo_env_ptr_lo
    sta .tempo_env_ptr+0 
    lda famistudio_tempo_env_ptr_hi
    sta .tempo_env_ptr+1
.reset_tempo_env:    
    sty .tmp_y1
    ldy #0
    sty famistudio_tempo_env_idx
    lda (.tempo_env_ptr),y
    sta famistudio_tempo_env_counter
    ldy .tmp_y1
    jmp .read_byte



.opcode_slide:
    lda famistudio_channel_to_slide,x
    tax
    lda (.channel_data_ptr),y ; Read slide step size
    iny
    sta famistudio_slide_step,x
    lda (.channel_data_ptr),y ; Read slide note from
    iny 
    sty .tmp_y2
    sta .tmp_slide_from
    lda (.channel_data_ptr),y ; Read slide note to
    ldy .tmp_slide_from       ; reload note from
    stx .tmp_slide_idx ; X contained the slide index.    
    tax
    sec ; Subtract the pitch of both notes.
    lda famistudio_note_table_lsb,y
    sbc famistudio_note_table_lsb,x
    sta .slide_delta_lo
    lda famistudio_note_table_msb,y
    sbc famistudio_note_table_msb,x
    ldx .tmp_slide_idx ; slide index.
    sta famistudio_slide_pitch_hi,x
    .negative_shift:
        lda .slide_delta_lo
        asl a ; Shift-left, we have 1 bit of fractional slide.
        sta famistudio_slide_pitch_lo,x
        rol famistudio_slide_pitch_hi,x ; Shift-left, we have 1 bit of fractional slide.
    ldx .chan_idx
    ldy .tmp_y2

.slide_done_pos:
    lda (.channel_data_ptr),y ; Re-read the target note (ugly...)
    sta famistudio_chn_note,x ; Store note code
    iny
    jmp .cancel_delayed_cut

.opcode_invalid:

    ; If you hit this, this mean you either:
    ; - exported a song that uses FamiStudio tempo but have defined "FAMISTUDIO_USE_FAMITRACKER_TEMPO"
    ; - use delayed notes/cuts, but didnt enable "FAMISTUDIO_USE_FAMITRACKER_DELAYED_NOTES_OR_CUTS"
    ; - use vibrato effect, but didnt enable "FAMISTUDIO_USE_VIBRATO"
    ; - use arpeggiated chords, but didnt enable "FAMISTUDIO_USE_ARPEGGIO"
    ; - use fine pitches, but didnt enable "FAMISTUDIO_USE_PITCH_TRACK"
    ; - use a duty cycle effect, but didnt enable "FAMISTUDIO_USE_DUTYCYCLE_EFFECT"
    ; - use slide notes, but didnt enable "FAMISTUDIO_USE_SLIDE_NOTES"
    ; - use volume slides, but didnt enable "FAMISTUDIO_USE_VOLUME_SLIDES"
    ; - use DMC counter effect, but didnt enable "FAMISTUDIO_USE_DELTA_COUNTER"
    ; - use a Phase Reset efect, but didnt enable the "FAMISTUDIO_USE_PHASE_RESET"
    ; - use an instrument > 63, but didnt enable "FAMISTUDIO_USE_INSTRUMENT_EXTENDED_RANGE"

DB $00 ; BRK (unreachable invalid-opcode trap)

.famistudio_opcode_jmp_lo:
DB (.opcode_extended_note & $FF)                ; $40
DB (.opcode_set_reference & $FF)                ; $41
DB (.opcode_loop & $FF)                         ; $42
DB (.opcode_disable_attack & $FF)               ; $43
DB (.opcode_end_song & $FF)                     ; $44
DB (.opcode_release_note & $FF)                 ; $45
DB (.opcode_invalid & $FF)                      ; $46
DB (.opcode_set_tempo_envelope & $FF)           ; $47
DB (.opcode_reset_tempo_envelope & $FF)         ; $48
DB (.opcode_override_pitch_envelope & $FF)      ; $49
DB (.opcode_clear_pitch_override_flag & $FF)    ; $4a
DB (.opcode_override_arpeggio_envelope & $FF)   ; $4b
DB (.opcode_clear_arpeggio_override_flag & $FF) ; $4c
DB (.opcode_reset_arpeggio & $FF)               ; $4d
DB (.opcode_fine_pitch & $FF)                   ; $4e
DB (.opcode_invalid & $FF)                      ; $4f
DB (.opcode_slide & $FF)                        ; $50
DB (.opcode_invalid & $FF)                      ; $51
DB (.opcode_invalid & $FF)                      ; $52
DB (.opcode_invalid & $FF)                      ; $53
DB (.opcode_invalid & $FF)                      ; $54

.famistudio_opcode_jmp_hi:
DB (.opcode_extended_note >> 8)                ; $40
DB (.opcode_set_reference >> 8)                ; $41
DB (.opcode_loop >> 8)                         ; $42
DB (.opcode_disable_attack >> 8)               ; $43
DB (.opcode_end_song >> 8)                     ; $44
DB (.opcode_release_note >> 8)                 ; $45
DB (.opcode_invalid >> 8)                      ; $46
DB (.opcode_set_tempo_envelope >> 8)           ; $47
DB (.opcode_reset_tempo_envelope >> 8)         ; $48
DB (.opcode_override_pitch_envelope >> 8)      ; $49
DB (.opcode_clear_pitch_override_flag >> 8)    ; $4a
DB (.opcode_override_arpeggio_envelope >> 8)   ; $4b
DB (.opcode_clear_arpeggio_override_flag >> 8) ; $4c
DB (.opcode_reset_arpeggio >> 8)               ; $4d
DB (.opcode_fine_pitch >> 8)                   ; $4e
DB (.opcode_invalid >> 8)                      ; $4f
DB (.opcode_slide >> 8)                        ; $50
DB (.opcode_invalid >> 8)                      ; $51
DB (.opcode_invalid >> 8)                      ; $52
DB (.opcode_invalid >> 8)                      ; $53
DB (.opcode_invalid >> 8)                      ; $54

;======================================================================================================================
; FAMISTUDIO_SAMPLE_STOP (internal)
;
; Stop DPCM sample if it plays
;
; [in] no input params.
;======================================================================================================================

famistudio_sample_stop:

    lda #0b00001111
    sta FAMISTUDIO_APU_SND_CHN
    rts

        


; Dummy envelope used to initialize all channels with silence
famistudio_dummy_envelope:
DB $c0,$7f,$00,$00

famistudio_dummy_pitch_envelope:
DB $00,$c0,$7f,$00,$01

; Note tables
famistudio_note_table_lsb:
; embedded NoteTables/famistudio_note_table_lsb.bin (97 bytes)
DB $00,$5B,$9C,$E6,$3B,$9A,$01,$72,$EA,$6A,$F1,$7F,$13,$AD,$4D,$F3
DB $9D,$4C,$00,$B8,$74,$34,$F8,$BF,$89,$56,$26,$F9,$CE,$A6,$80,$5C
DB $3A,$1A,$FB,$DF,$C4,$AB,$93,$7C,$67,$52,$3F,$2D,$1C,$0C,$FD,$EF
DB $E1,$D5,$C9,$BD,$B3,$A9,$9F,$96,$8E,$86,$7E,$77,$70,$6A,$64,$5E
DB $59,$54,$4F,$4B,$46,$42,$3F,$3B,$38,$34,$31,$2F,$2C,$29,$27,$25
DB $23,$21,$1F,$1D,$1B,$1A,$18,$17,$15,$14,$13,$12,$11,$10,$0F,$0E
DB $0D

famistudio_note_table_msb:
; embedded NoteTables/famistudio_note_table_msb.bin (97 bytes)
DB $00,$0D,$0C,$0B,$0B,$0A,$0A,$09,$08,$08,$07,$07,$07,$06,$06,$05
DB $05,$05,$05,$04,$04,$04,$03,$03,$03,$03,$03,$02,$02,$02,$02,$02
DB $02,$02,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$00,$00
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB $00






; For a given channel, returns the index of the volume envelope.
famistudio_channel_env:
famistudio_channel_to_volume_env:
DB FAMISTUDIO_CH0_ENVS+FAMISTUDIO_ENV_VOLUME_OFF
DB FAMISTUDIO_CH1_ENVS+FAMISTUDIO_ENV_VOLUME_OFF
DB FAMISTUDIO_CH2_ENVS+FAMISTUDIO_ENV_VOLUME_OFF
DB FAMISTUDIO_CH3_ENVS+FAMISTUDIO_ENV_VOLUME_OFF
DB $ff

; For a given channel, returns the index of the arpeggio envelope.
famistudio_channel_to_arpeggio_env:
DB FAMISTUDIO_CH0_ENVS+FAMISTUDIO_ENV_NOTE_OFF
DB FAMISTUDIO_CH1_ENVS+FAMISTUDIO_ENV_NOTE_OFF
DB FAMISTUDIO_CH2_ENVS+FAMISTUDIO_ENV_NOTE_OFF
DB FAMISTUDIO_CH3_ENVS+FAMISTUDIO_ENV_NOTE_OFF
DB $ff

famistudio_channel_to_slide:
; This table will only be defined if we use noise slides, otherwise identical to "famistudio_channel_to_pitch_env".


; For a given channel, returns the index of the pitch envelope.
famistudio_channel_to_pitch_env:
DB $00
DB $01
DB $02
DB $ff ; no pitch envelopes for noise
DB $ff ; no pitch envelopes slide for DPCM


; Duty lookup table.
famistudio_duty_lookup:
DB $30
DB $70
DB $b0
DB $f0



famistudio_tempo_frame_lookup:
DB $01, $02 ; NTSC -> NTSC, NTSC -> PAL
DB $00, $01 ; PAL  -> NTSC, PAL  -> PAL



; Precomputed volume multiplication table (rounded but never to zero unless one of the value is zero).
; Load the 2 volumes in the lo/hi nibble and fetch.

famistudio_volume_table:
DB $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
DB $00, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01
DB $00, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $02, $02, $02, $02
DB $00, $01, $01, $01, $01, $01, $01, $01, $02, $02, $02, $02, $02, $03, $03, $03
DB $00, $01, $01, $01, $01, $01, $02, $02, $02, $02, $03, $03, $03, $03, $04, $04
DB $00, $01, $01, $01, $01, $02, $02, $02, $03, $03, $03, $04, $04, $04, $05, $05
DB $00, $01, $01, $01, $02, $02, $02, $03, $03, $04, $04, $04, $05, $05, $06, $06
DB $00, $01, $01, $01, $02, $02, $03, $03, $04, $04, $05, $05, $06, $06, $07, $07
DB $00, $01, $01, $02, $02, $03, $03, $04, $04, $05, $05, $06, $06, $07, $07, $08
DB $00, $01, $01, $02, $02, $03, $04, $04, $05, $05, $06, $07, $07, $08, $08, $09
DB $00, $01, $01, $02, $03, $03, $04, $05, $05, $06, $07, $07, $08, $09, $09, $0a
DB $00, $01, $01, $02, $03, $04, $04, $05, $06, $07, $07, $08, $09, $0a, $0a, $0b
DB $00, $01, $02, $02, $03, $04, $05, $06, $06, $07, $08, $09, $0a, $0a, $0b, $0c
DB $00, $01, $02, $03, $03, $04, $05, $06, $07, $08, $09, $0a, $0a, $0b, $0c, $0d
DB $00, $01, $02, $03, $04, $05, $06, $07, $07, $08, $09, $0a, $0b, $0c, $0d, $0e
DB $00, $01, $02, $03, $04, $05, $06, $07, $08, $09, $0a, $0b, $0c, $0d, $0e, $0f

    
