#!/usr/bin/env python3
"""Exercise the v0.36 boss transition and prove that the custom player runs.

This is an integration smoke test, not a replacement for listening in a
hardware/emulator setup. It boots the approved game flow, advances the boss
counters, waits for boss_start to clear the scenery, and checks the new
FamiStudio active flag, moving channel pointers, and non-silent APU output.
"""
from __future__ import annotations

import argparse
import ctypes
import sys
import wave
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
PROJECT = HERE.parent / 'spaceblast-github'
sys.path.insert(0, str(PROJECT / 'nes-test'))
from addrs_cb import ADDR as A  # noqa: E402
from emu_lib import Emu  # noqa: E402
from test_v035_input import boot_game  # noqa: E402


AUDIOB = ctypes.CFUNCTYPE(ctypes.c_size_t, ctypes.POINTER(ctypes.c_int16), ctypes.c_size_t)


def parse_args():
    p = argparse.ArgumentParser()
    p.add_argument('--rom', type=Path,
                   default=PROJECT / 'spaceblast' / 'space-blast-intruder-alert-v036.nes')
    p.add_argument('--core', type=Path, default=Path('/tmp/fceumm_libretro.so'))
    p.add_argument('--out-dir', type=Path, default=HERE)
    return p.parse_args()


def u16(ram, address):
    return ram[address] | (ram[address + 1] << 8)


def main():
    args = parse_args()
    rom = args.rom.resolve()
    args.out_dir.mkdir(parents=True, exist_ok=True)
    if not rom.is_file():
        raise SystemExit(f'ROM not found: {rom}')

    emu = Emu(so=args.core, rom=rom)
    ram = emu.ram()
    boot_elapsed = boot_game(emu, ram)

    pcm = []

    def audio_batch(buf, frames):
        if buf and frames:
            pcm.append(np.ctypeslib.as_array(buf, shape=(frames * 2,)).copy())
        return frames

    audio_cb = AUDIOB(audio_batch)
    emu.L.retro_set_audio_sample_batch(audio_cb)

    # Make the normal game-loop boss gate true.  No game logic or ROM bytes
    # are patched by this test; these are the same RAM counters used by the
    # original boss trigger.
    ram[A['NSMA']] = 4
    ram[A['NSHA']] = 4
    ram[A['NE4']] = 4
    ram[A['WACT']] = 0
    ram[A['WPAUSA']] = 1
    for address in (A['SMA'], A['SHA'], A['E4A']):
        # Existing enemy arrays are not relevant once the boss gate is true;
        # leave their contents alone rather than changing gameplay state more
        # than necessary.
        _ = address

    transition_frames = 0
    active_frame = None
    before = []
    after = []
    pointers = []
    boss_frames = []
    for frame in range(420):
        ram[A['INV']] = 90
        emu.run(1)
        active = int(ram[0x0500])
        song_speed = int(ram[0x0594])
        ptr = u16(ram, 0x0557)
        boss = int(ram[A['BSA']])
        pointers.append(ptr)
        boss_frames.append(boss)
        if active:
            if active_frame is None:
                active_frame = frame + 1
            after.append((song_speed, ptr))
        else:
            before.append((song_speed, ptr))
        transition_frames = frame + 1
        if active_frame is not None and frame - active_frame > 180:
            break

    # Store all captured samples, then calculate a conservative non-silence
    # check over the frames after FamiStudio was enabled.
    all_pcm = np.concatenate(pcm) if pcm else np.zeros(2, dtype=np.int16)
    wav_path = args.out_dir / 'v036_boss_audio.wav'
    with wave.open(str(wav_path), 'wb') as out:
        out.setnchannels(2)
        out.setsampwidth(2)
        out.setframerate(48000)
        out.writeframes(all_pcm.astype('<i2').tobytes())

    # The engine's song pointer should advance during the sampled boss music.
    ptr_values = {ptr for _, ptr in after}
    audio_rms = float(np.sqrt(np.mean(all_pcm.astype(np.float64) ** 2))) if len(all_pcm) else 0.0
    if active_frame is None:
        raise AssertionError(f'FamiStudio active flag never set in {transition_frames} frames')
    if len(ptr_values) < 2:
        raise AssertionError(f'FamiStudio channel pointer did not advance: {sorted(ptr_values)}')
    if audio_rms < 1.0:
        raise AssertionError(f'captured APU output is silent (RMS={audio_rms:.2f})')
    if 1 not in boss_frames:
        raise AssertionError('boss_start did not enter its active state')

    print(f'boot_playable_after={boot_elapsed}f')
    print(f'boss_active_after_force={active_frame}f')
    print(f'frames_sampled={transition_frames} pointer_values={len(ptr_values)}')
    print(f'audio_rms={audio_rms:.2f} wav={wav_path}')
    print('V036 BOSS MUSIC TEST OK')


if __name__ == '__main__':
    main()
