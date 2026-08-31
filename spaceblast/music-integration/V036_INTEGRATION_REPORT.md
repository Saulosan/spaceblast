# Space Blast v0.36 — Intruder Alert integration

- Base: `space-blast-v035.nes` (read-only)
- Base SHA-256: `79a51ada5c95cc004ea29939e2982d6a9acb2fb776684db47d320ea86694df94`
- New ROM: `space-blast-intruder-alert-v036.nes`
- New ROM SHA-256: `15de5bc18d8bb56d17255ef9971889b16009cc95f09419b0dc625945bb4d9acf`
- New ROM size: `524304` bytes
- Source route: `uploads/intruder_alert.nsf` imported by FamiStudio 4.4.4.
- FTM note: the original `intruder_alert.ftm` is preserved; FamiStudio 4.4.4 rejected its older FTM version.
- Audio mapping: FamiStudio native 2A03 pulse 1, pulse 2, triangle and noise are retained; the DPCM channel is replaced by an inactive sentinel because the fixed `$C000-$FFFF` bank is full and the existing game has a four-voice music budget.
- Playback: custom engine is initialized after `boss_start` clears the battle scenery and advances from `WAIT`, while the approved CVBasic player is disabled. Calling the existing `PLAY` path disables the custom player and restores standard stage/title audio.
- Mapper: dedicated physical bank 3, with marker `$03` at `$BFFF`.
- Gameplay source: no BASIC/gameplay source was changed; the generated v0.35 assembly was copied and patched only for the audio hook, wrapper, and unused ROM bank.

## Build

- Assembler: Gasm80 6502.
- Assembly log: `build_v036_assembler.log`.
- Listing: `spaceblast/space-blast-intruder-alert-v036.lst`.
- Self-contained source sidecars: `spaceblast/famistudio_engine_gasm80.asm` and `spaceblast/intruder_alert_data_gasm80.asm`.

## Automated structural checks

- The v0.35 ROM hash was checked before and after assembly.
- The new ROM has the expected 512 KiB PRG/CHR file size (`524304` bytes including iNES header).
- Libretro FCEUMM smoke test: `test_v035_input.py` passed repeated SELECT phase changes and START-during-history reset (`V035 INPUT TESTS OK`).
- Libretro FCEUMM boss test: `test_v036_boss_audio.py` reached the real boss gate, enabled FamiStudio 61 frames after the forced gate, observed 31 moving channel-pointer values, and captured non-silent APU output (RMS 2820.36).
- Full v0.35 regression route on v0.36: boss defeated at frame 1320; credits pages, `THE END?` (302 readable frames), reset, splash/title and a clean phase-1 restart all passed; fixed-text hardware scroll stayed zero.
- The source assembler still contains the original game loop, boss procedure, bank markers and reset vectors; final listening on the user setup remains the last acceptance step.
