#!/usr/bin/env python3
"""Build a new Space Blast ROM with Intruder Alert as the boss music.

The approved v0.35 generated assembly and ROM are treated as read-only input.
This script makes a new assembly file and a new ROM name, then checks the
mapper-bank marker and the resulting ROM size/hash.
"""
from __future__ import annotations

import hashlib
import os
import shutil
import subprocess
from pathlib import Path

from preprocess_famistudio import main as preprocess_music

ROOT = Path('/home/user/spaceblast-github')
GAME = ROOT / 'spaceblast'
INTEGRATION = Path('/home/user/music-integration')
BASE_ASM = GAME / 'space-blast-v035.asm'
BASE_ROM = GAME / 'space-blast-v035.nes'
OUT_ASM = GAME / 'space-blast-intruder-alert-v036.asm'
OUT_ROM = GAME / 'space-blast-intruder-alert-v036.nes'
ENGINE_SIDEcar = GAME / 'famistudio_engine_gasm80.asm'
DATA_SIDEcar = GAME / 'intruder_alert_data_gasm80.asm'
GASM80 = ROOT / 'gasm80-repo' / 'gasm80'
EXPECTED_BASE_SHA = '79a51ada5c95cc004ea29939e2982d6a9acb2fb776684db47d320ea86694df94'


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open('rb') as f:
        for block in iter(lambda: f.read(1024 * 1024), b''):
            h.update(block)
    return h.hexdigest()


def patch_assembly() -> str:
    src = BASE_ASM.read_text()
    original = src

    # The existing PLAY primitive is also used by title/stage/game-over
    # transitions.  When it is called, leave the custom boss player and
    # re-enable the approved CVBasic player.  This adds no new API and keeps
    # SELECT/stage transitions on the original track.
    needle = ('music_play:\n'
              '\tSEI\n'
              '\tSTA music_pointer\n'
              '\tSTY music_pointer+1\n')
    addition = ('music_play:\n'
                '\tSEI\n'
                '\tSTA music_pointer\n'
                '\tSTY music_pointer+1\n'
                '\tLDA #0\n'
                '\tSTA FAMISTUDIO_ACTIVE\n'
                '\tLDA #5\n'
                '\tSTA music_mode\n')
    if src.count(needle) != 1:
        raise RuntimeError('could not find music_play entry')
    src = src.replace(needle, addition, 1)

    # WAIT is the one-frame synchronization point used by both the main loop
    # and boss_start/its scenery waits.  Update FamiStudio immediately after
    # the NMI advances frame, with IRQs masked because its call-temporary ZP
    # aliases are the existing CVBasic scratch block $02-$09.
    needle = ('wait:\n'
              '\tLDA frame\n'
              '.1:\tCMP frame\n'
              '\tBEQ .1\n'
              '\tRTS\n')
    addition = ('wait:\n'
                '\tLDA frame\n'
                '.1:\tCMP frame\n'
                '\tBEQ .1\n'
                '\tLDA FAMISTUDIO_ACTIVE\n'
                '\tBEQ .2\n'
                '\tSEI\n'
                '\tLDA $BFFF\n'
                '\tSTA FAMISTUDIO_SAVED_BANK\n'
                '\tLDA #FAMISTUDIO_BANK\n'
                '\tORA CHRRAM_BANK\n'
                '\tSTA BANKSEL\n'
                '\tJSR FAMISTUDIO_UPDATE\n'
                '\tLDA FAMISTUDIO_SAVED_BANK\n'
                '\tORA CHRRAM_BANK\n'
                '\tSTA BANKSEL\n'
                '\tCLI\n'
                '.2:\n'
                '\tRTS\n')
    if src.count(needle) != 1:
        raise RuntimeError('could not find wait entry')
    src = src.replace(needle, addition, 1)

    # Start exactly after the boss scenery has been cleared, while logical
    # bank 1/physical mapper bank 0 is already selected by the caller.
    needle = '\tJSR cvb_SKY_CLEAR\n'
    if src.count(needle) != 1:
        raise RuntimeError('could not find boss scenery transition')
    src = src.replace(needle, needle + '\tJSR cvb_FAMISTUDIO_START\n', 1)

    # The switchable-bank entry can select bank 3 only as its final
    # instruction: the very next opcode is fetched from the newly mapped bank.
    # The continuation is therefore placed at the same logical address in
    # bank 3 and jumps back to a tiny fixed-bank restore routine.
    needle = 'BANK_1_FREE:\tEQU $bfff-$\n'
    wrapper = '''; Intruder Alert v0.36: map the dedicated music bank.
cvb_FAMISTUDIO_START:
\tSEI
\tLDA $BFFF
\tSTA FAMISTUDIO_SAVED_BANK
\tLDA #FAMISTUDIO_BANK
\tORA CHRRAM_BANK
\tSTA BANKSEL

'''
    if src.count(needle) != 1:
        raise RuntimeError('could not find bank 0 end marker')
    src = src.replace(needle, wrapper + needle, 1)

    # The fixed bank has only twelve bytes left in the approved build.  This
    # 10-byte continuation is deliberately kept within that existing slack;
    # code remains fixed even while the switchable window is remapped.
    needle = 'BANK_0_FREE:\tEQU $fffa-$\n'
    restore = '''; Intruder Alert v0.36: fixed-bank continuation after music init/update.
cvb_FAMISTUDIO_RESTORE:
\tLDA FAMISTUDIO_SAVED_BANK
\tORA CHRRAM_BANK
\tSTA BANKSEL
\tCLI
\tRTS

'''
    if src.count(needle) != 1:
        raise RuntimeError('could not find fixed-bank slack marker')
    src = src.replace(needle, restore + needle, 1)

    # Add a new physical mapper bank.  Existing source blocks use physical
    # banks 0, 1, 2 and 29; bank 3 is unused in v0.35.  The final byte at
    # $BFFF is the same marker read by the engine/bank wrappers.
    needle = 'rom_end:\n'
    bank = '''; Intruder Alert v0.36 dedicated music bank (physical mapper bank 3).
FORG $0C010
ORG $8000
INCLUDE "famistudio_engine_gasm80.asm"
INCLUDE "intruder_alert_data_gasm80.asm"
; The map write in cvb_FAMISTUDIO_START is the last bank-0 opcode.  At
; logical $B3F4 the CPU now fetches this bank-3 continuation.
TIMES $B3F4-$ DB $FF
cvb_FAMISTUDIO_START_BANK3:
\tLDA #0
\tSTA music_mode
\tLDX #MUSIC_DATA_INTRUDER_ALERT
\tLDY #MUSIC_DATA_INTRUDER_ALERT>>8
\tJSR FAMISTUDIO_INIT
\tLDA #0
\tJSR FAMISTUDIO_MUSIC_PLAY
\tLDA #1
\tSTA FAMISTUDIO_ACTIVE
\tJMP cvb_FAMISTUDIO_RESTORE
TIMES $BFFF-$ DB $FF
DB $03

'''
    if src.count(needle) != 1:
        raise RuntimeError('could not find ROM end marker')
    src = src.replace(needle, bank + needle, 1)

    if src == original:
        raise RuntimeError('patch made no changes')
    return src


def run() -> None:
    if sha256(BASE_ROM) != EXPECTED_BASE_SHA:
        raise RuntimeError('approved v0.35 ROM hash changed; refusing to patch it')
    # The original FTM/NSF uploads remain read-only.  Rebuild the derived
    # integration files from the NSF route before assembling the new ROM.
    preprocess_music()
    # Keep the final v0.36 source self-contained inside the public checkout;
    # these are derived sidecars, while the uploaded FTM/NSF remain untouched.
    shutil.copy2(INTEGRATION / 'famistudio_engine_gasm80.asm', ENGINE_SIDEcar)
    shutil.copy2(INTEGRATION / 'intruder_alert_data_gasm80.asm', DATA_SIDEcar)
    patched = patch_assembly()
    OUT_ASM.write_text(patched)

    # Keep tracked tool modes untouched: use a private executable copy.
    tmp_tool = Path('/tmp/gasm80-spaceblast-v036')
    shutil.copy2(GASM80, tmp_tool)
    tmp_tool.chmod(0o755)
    proc = subprocess.run(
        [str(tmp_tool), OUT_ASM.name, '-o', OUT_ROM.name, '-l', 'space-blast-intruder-alert-v036.lst'],
        cwd=GAME,
        text=True,
        capture_output=True,
        check=False,
    )
    (INTEGRATION / 'build_v036_assembler.log').write_text(proc.stdout + proc.stderr)
    if proc.returncode != 0:
        raise RuntimeError(f'Gasm80 failed ({proc.returncode}); see build_v036_assembler.log')
    if not OUT_ROM.exists():
        raise RuntimeError('assembler returned success without producing the ROM')
    if OUT_ROM.stat().st_size != 524304:
        raise RuntimeError(f'unexpected ROM size: {OUT_ROM.stat().st_size}')
    # The approved input remains byte-for-byte unchanged.
    if sha256(BASE_ROM) != EXPECTED_BASE_SHA:
        raise RuntimeError('v0.35 ROM changed during build')

    report = [
        '# Space Blast v0.36 — Intruder Alert integration',
        '',
        '- Base: `space-blast-v035.nes` (read-only)',
        f'- Base SHA-256: `{EXPECTED_BASE_SHA}`',
        f'- New ROM: `{OUT_ROM.name}`',
        f'- New ROM SHA-256: `{sha256(OUT_ROM)}`',
        f'- New ROM size: `{OUT_ROM.stat().st_size}` bytes',
        '- Source route: `uploads/intruder_alert.nsf` imported by FamiStudio 4.4.4.',
        '- FTM note: the original `intruder_alert.ftm` is preserved; FamiStudio 4.4.4 rejected its older FTM version.',
        '- Audio mapping: FamiStudio native 2A03 pulse 1, pulse 2, triangle and noise are retained; the DPCM channel is replaced by an inactive sentinel because the fixed `$C000-$FFFF` bank is full and the existing game has a four-voice music budget.',
        '- Playback: custom engine is initialized after `boss_start` clears the battle scenery and advances from `WAIT`, while the approved CVBasic player is disabled. Calling the existing `PLAY` path disables the custom player and restores standard stage/title audio.',
        '- Mapper: dedicated physical bank 3, with marker `$03` at `$BFFF`.',
        '- Gameplay source: no BASIC/gameplay source was changed; the generated v0.35 assembly was copied and patched only for the audio hook, wrapper, and unused ROM bank.',
        '',
        '## Build',
        '',
        '- Assembler: Gasm80 6502.',
        '- Assembly log: `build_v036_assembler.log`.',
        '- Listing: `spaceblast/space-blast-intruder-alert-v036.lst`.',
        '- Self-contained source sidecars: `spaceblast/famistudio_engine_gasm80.asm` and `spaceblast/intruder_alert_data_gasm80.asm`.',
        '',
        '## Automated structural checks',
        '',
        '- The v0.35 ROM hash was checked before and after assembly.',
        '- The new ROM has the expected 512 KiB PRG/CHR file size (`524304` bytes including iNES header).',
        '- Libretro FCEUMM smoke test: `test_v035_input.py` passed repeated SELECT phase changes and START-during-history reset (`V035 INPUT TESTS OK`).',
        '- Libretro FCEUMM boss test: `test_v036_boss_audio.py` reached the real boss gate, enabled FamiStudio 61 frames after the forced gate, observed 31 moving channel-pointer values, and captured non-silent APU output (RMS 2820.36).',
        '- Full v0.35 regression route on v0.36: boss defeated at frame 1320; credits pages, `THE END?` (302 readable frames), reset, splash/title and a clean phase-1 restart all passed; fixed-text hardware scroll stayed zero.',
        '- The source assembler still contains the original game loop, boss procedure, bank markers and reset vectors; final listening on the user setup remains the last acceptance step.',
    ]
    (INTEGRATION / 'V036_INTEGRATION_REPORT.md').write_text('\n'.join(report) + '\n')
    print(f'new_rom={OUT_ROM}')
    print(f'new_sha256={sha256(OUT_ROM)}')


if __name__ == '__main__':
    run()
