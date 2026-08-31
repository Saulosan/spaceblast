#!/usr/bin/env python3
"""v0.35 input smoke tests: repeated SELECT and START during history."""
from pathlib import Path
import argparse
import sys

HERE = Path(__file__).resolve().parent
PROJECT = HERE.parent
sys.path.insert(0, str(HERE))

from addrs_cb import ADDR as A  # noqa: E402
from emu_lib import Emu  # noqa: E402


def parse_args():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--rom', type=Path,
                   default=PROJECT / 'spaceblast' / 'space-blast-v035.nes')
    p.add_argument('--core', type=Path, default=None)
    return p.parse_args()


def value(ram, name):
    address = A[name]
    return ram[address] | (ram[address + 1] << 8)


def tap(emu, key):
    emu.run(1, {key})


def boot_game(emu, ram):
    """Skip splash, title and stage card, then wait for playable phase 1."""
    for _ in range(120):
        emu.run(1)
        ram[A['INV']] = 90
    tap(emu, 'START')
    for _ in range(40):
        emu.run(1)
        ram[A['INV']] = 90
    tap(emu, 'START')
    for _ in range(40):
        emu.run(1)
        ram[A['INV']] = 90
    tap(emu, 'START')
    for elapsed in range(1200):
        emu.run(1)
        ram[A['INV']] = 90
        if ram[A['FASE']] == 1 and ram[A['LI']] == 3:
            # Leave the setup path before the first SELECT tap.
            for _ in range(80):
                emu.run(1)
                ram[A['INV']] = 90
            return elapsed
    raise AssertionError('phase 1 gameplay did not start')


def select_test(rom, core):
    emu = Emu(so=core, rom=rom)
    ram = emu.ram()
    boot_game(emu, ram)
    expected_sequence = (2, 3, 4, 5, 1, 2, 3, 4, 5, 1)
    observed = [ram[A['FASE']]]
    for expected in expected_sequence:
        tap(emu, 'SELECT')
        for elapsed in range(1000):
            emu.run(1)
            ram[A['INV']] = 90
            if ram[A['FASE']] == expected:
                break
        else:
            raise AssertionError(f'SELECT timeout waiting for FASE={expected}')
        # SELECT changes the phase immediately, then begin_stage performs its
        # scenery setup without reading another SELECT. Stabilize before tap.
        setup = 240 if expected in (1, 3, 5) else 130
        for _ in range(setup):
            emu.run(1)
            ram[A['INV']] = 90
        if ram[A['FASE']] != expected:
            raise AssertionError(f'phase changed after settling: {expected}')
        if ram[A['LI']] != 3:
            raise AssertionError(f'lives changed during SELECT: {ram[A["LI"]]}')
        observed.append(ram[A['FASE']])
    if tuple(observed) != (1,) + expected_sequence:
        raise AssertionError(f'unexpected SELECT sequence: {observed}')
    print('SELECT OK:', ' -> '.join(map(str, observed)))


def start_history_test(rom, core):
    emu = Emu(so=core, rom=rom)
    ram = emu.ram()
    reached_page = None
    for frame in range(3600):
        emu.run(1)
        ram[A['INV']] = 90
        # #BO=900 proves this is the automatic history path, not a manual
        # START from the title. #FP=1 proves the input is sent in history.
        if value(ram, '#BO') >= 900 and value(ram, '#FP') == 1:
            reached_page = frame + 1
            break
    if reached_page is None:
        raise AssertionError('automatic history page 1 did not appear')
    for _ in range(100):
        emu.run(1)
        ram[A['INV']] = 90
    tap(emu, 'START')

    reset_frame = None
    for elapsed in range(1200):
        emu.run(1)
        ram[A['INV']] = 90
        if ram[A['FASE']] == 0 and ram[0x1C] == 0:
            reset_frame = elapsed + 1
            break
    if reset_frame is None:
        raise AssertionError('START did not reset from history')

    splash = False
    title = False
    for _ in range(1200):
        emu.run(1)
        ram[A['INV']] = 90
        bank = ram[0x1C]
        if not splash and bank == 0x20:
            splash = True
        if splash and bank == 0 and value(ram, '#BO') < 50:
            title = True
            break
    if not splash or not title:
        raise AssertionError(f'reset visuals missing: splash={splash} title={title}')
    print('START during history OK:',
          f'page1_at={reached_page}f reset={reset_frame}f splash={splash} title={title}')


def main():
    args = parse_args()
    rom = args.rom.expanduser().resolve()
    if not rom.is_file():
        raise SystemExit(f'ROM not found: {rom}')
    select_test(rom, args.core)
    start_history_test(rom, args.core)
    print('V035 INPUT TESTS OK')


if __name__ == '__main__':
    main()
