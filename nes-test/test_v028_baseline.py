#!/usr/bin/env python3
"""Independent v0.28 baseline smoke/regression suite.

The suite exercises the boot path, all five stage backgrounds and the real
post-boss ending flow.  It uses only the RAM map generated from the current
assembly and accepts ROM/core paths through arguments or environment variables.
"""
from collections import Counter
from hashlib import md5, sha256
from pathlib import Path
import argparse
import re
import sys

HERE = Path(__file__).resolve().parent
PROJECT = HERE.parent
sys.path.insert(0, str(HERE))

from addrs_cb import ADDR as A  # noqa: E402
from emu_lib import BT, Emu  # noqa: E402

CHR_BANK = 0x001C
PPU_CTRL = 0x0016


def parse_args():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        '--rom', type=Path,
        default=PROJECT / 'spaceblast' / 'space-blast.nes',
        help='ROM to test (default: ../spaceblast/space-blast.nes)',
    )
    parser.add_argument(
        '--core', type=Path, default=None,
        help='FCEUmm libretro core (or set FCEUMM_CORE)',
    )
    return parser.parse_args()


def check(condition, message, failures):
    print(('OK  ' if condition else 'FAIL') + ' ' + message)
    if not condition:
        failures.append(message)
    return condition


def rom_checks(rom_path, source_path, failures):
    data = rom_path.read_bytes()
    mapper = (data[6] >> 4) | (data[7] & 0xF0) if len(data) >= 8 else -1
    check(len(data) == 524304, f'ROM 524304 bytes ({len(data)})', failures)
    check(data[:4] == b'NES\x1a', 'header iNES presente', failures)
    check(mapper == 30, f'mapper 30 ({mapper})', failures)
    check(data[4] == 32 and data[5] == 0,
          f'32 bancos PRG / CHR-RAM ({data[4]}/{data[5]})', failures)
    print('MD5   ', md5(data).hexdigest())
    print('SHA256', sha256(data).hexdigest())

    # This is the code-generation rule that the original v0.28 ending broke:
    # FOR counters are bytes, so a numeric limit above 254 is unsafe.
    bad_for = []
    pattern = re.compile(r'^\s*FOR\s+[^\n]*?\s+TO\s+(\d+)\b', re.I)
    for line_no, line in enumerate(source_path.read_text().splitlines(), 1):
        match = pattern.search(line)
        if match and int(match.group(1)) > 254:
            bad_for.append(f'{line_no}:{match.group(1)}')
    check(not bad_for, 'nenhum FOR numerico acima de 254', failures)


def frame_colors(emu):
    if not emu.frames:
        return Counter()
    return Counter(map(tuple, emu.frames[-1].reshape(-1, 3)))


def wait_until(step, predicate, limit, description, failures):
    for elapsed in range(limit + 1):
        if predicate():
            return elapsed
        step()
    check(False, f'{description} (timeout {limit}f)', failures)
    return None


def main():
    args = parse_args()
    rom_path = args.rom.expanduser().resolve()
    source_path = PROJECT / 'spaceblast' / 'space-blast.bas'
    failures = []

    if not rom_path.is_file():
        print(f'FAIL ROM ausente: {rom_path}')
        return 2
    if not source_path.is_file():
        print(f'FAIL fonte ausente: {source_path}')
        return 2
    rom_checks(rom_path, source_path, failures)

    try:
        emu = Emu(so=args.core, rom=rom_path)
    except (OSError, RuntimeError) as error:
        print(f'FAIL nao foi possivel abrir o FCEUmm/ROM: {error}')
        return 2
    ram = emu.ram()

    # Keep the pilot safe while the harness deliberately advances through
    # several scenes.  This is test-only RAM injection, never game logic.
    def step(n=1, keys=()):
        for _ in range(n):
            emu.run(1, keys)
            ram[A['INV']] = 90

    def press(key):
        step(1, {key})

    def transition(expected, stabilize=True):
        press('SELECT')
        arrived = wait_until(
            step, lambda: ram[A['FASE']] == expected, 900,
            f'chegada na fase {expected}', failures,
        )
        if arrived is None:
            return False
        # Odd pages clear the three nametables; even pages fill the scenery.
        # Give each path enough frames to leave setup before sampling it.
        if stabilize:
            step(240 if expected in (1, 3, 5) else 130)
        check(ram[A['FASE']] == expected,
              f'FASE={expected} apos a preparacao ({arrived}f)', failures)
        bank = ram[CHR_BANK]
        check(bank == (0x40 if expected in (2, 4) else 0x00),
              f'fase {expected}: CHRRAM bank ${bank:02X}', failures)
        before = ram[A['SCROLL_Y']]
        step(60)
        after = ram[A['SCROLL_Y']]
        check(before != after, f'fase {expected}: scroll ativo', failures)
        colors = frame_colors(emu)
        if expected == 2:
            check(colors[(208, 32, 32)] > 10000,
                  f'fase 2: cenario vermelho ({colors[(208, 32, 32)]} px)',
                  failures)
        elif expected == 4:
            check(colors[(32, 92, 220)] > 10000,
                  f'fase 4: cenario azul ({colors[(32, 92, 220)]} px)',
                  failures)
        else:
            check(colors[(16, 16, 16)] > 30000,
                  f'fase {expected}: cenario espacial ({colors[(16, 16, 16)]} px)',
                  failures)
        return True

    # ===== boot: splash -> title -> stage card -> first gameplay =====
    step(120)
    check(bool(emu.frames), 'boot produziu frames de video', failures)
    press('START')  # skip Falcon splash
    step(40)
    title_colors = frame_colors(emu)
    check(len(title_colors) >= 8, 'titulo tem imagem nao-uniforme', failures)
    press('START')  # start title
    step(40)
    press('START')  # cut the first stage card
    first_game = wait_until(
        step, lambda: ram[A['LI']] == 3, 900,
        'primeiro gameplay com 3 vidas', failures,
    )
    check(ram[A['FASE']] == 1, 'boot termina na FASE=1', failures)
    check(ram[CHR_BANK] == 0, 'boot termina no CHRRAM bank $00', failures)
    if first_game is not None:
        print(f'  (gameplay inicial em {first_game}f de espera)')

    # ===== all five pages and the debug SELECT cycle =====
    for expected in (2, 3, 4, 5, 1):
        if not transition(expected):
            break
    check(ram[A['FASE']] == 1, 'ciclo SELECT 1 -> 2 -> 3 -> 4 -> 5 -> 1', failures)

    # ===== boss in the actual phase-5 path, then ending =====
    # The cycle ends in phase 1.  Walk back to phase 5 so the boss is tested
    # after the same stage setup that a player sees.
    for expected in (2, 3, 4, 5):
        if not transition(expected):
            break

    # Make the boss gate deterministic without changing its code path.
    for base, count in ((A['SMA'], 6), (A['SHA'], 4),
                        (A['E4A'], 8), (A['EBA'], 8)):
        for index in range(count):
            ram[base + index] = 0
    ram[A['NSMA']] = 4
    ram[A['NSHA']] = 4
    ram[A['NE4']] = 4
    ram[A['WACT']] = 0
    ram[A['WPAUSA']] = 1

    boss_wait = wait_until(
        step, lambda: ram[A['BSA']] == 1, 400,
        'boss inicia na fase 5', failures,
    )
    check(boss_wait is not None and ram[A['BSHP']] == 120,
          f'boss inicia com HP 120 ({boss_wait}f)', failures)
    step(80)  # sky_clear + boss_write must finish before the probe shot
    check(ram[PPU_CTRL] == 0xB8, 'boss usa BG na tabela $1000 (PPUCTRL $B8)', failures)
    boss_colors = frame_colors(emu)
    check(len(boss_colors) > 8, 'boss produziu cena visivel', failures)

    def inject_bullet(x=116, y=92):
        for index in range(5):
            if ram[A['BTY'] + index] == 0:
                ram[A['BTX'] + index] = x
                ram[A['BTY'] + index] = y
                return True
        return False

    hp_before = ram[A['BSHP']]
    check(inject_bullet(), 'slot de tiro disponivel para o boss', failures)
    step(15)
    check(ram[A['BSHP']] == hp_before - 1,
          f'primeiro tiro reduz HP ({hp_before}->{ram[A["BSHP"]]})', failures)
    ram[A['BSHP']] = 1
    check(inject_bullet(), 'slot de tiro disponivel para o golpe final', failures)
    killed_after = wait_until(
        step, lambda: ram[A['BSA']] == 0, 30,
        'boss morre com o golpe final', failures,
    )

    # Record exact static-frame runs.  The ending screens intentionally hold
    # for 210, 270, 450 and 270 frames; this catches byte-counter truncation
    # while also proving that each screen was actually rendered.
    stable_runs = []
    previous = None
    run_length = 0
    frames_to_phase1 = None
    for elapsed in range(2500):
        step()
        digest = md5(emu.frames[-1].tobytes()).digest()
        if digest == previous:
            run_length += 1
        else:
            # Fade steps repeat for a few frames; only long runs are
            # useful evidence of the four static ending screens.
            if run_length >= 100:
                stable_runs.append(run_length)
            previous = digest
            run_length = 1
        if elapsed > 500 and ram[A['FASE']] == 1:
            frames_to_phase1 = elapsed + 1
            break
    if run_length >= 100:
        stable_runs.append(run_length)

    check(killed_after is not None, 'fluxo sai do boss para a cerimonia', failures)
    check(frames_to_phase1 is not None,
          'ending retorna ao estado FASE=1', failures)
    check(frames_to_phase1 is not None and frames_to_phase1 >= 1000,
          f'ending nao encurta telas ({frames_to_phase1}f ate FASE=1)', failures)
    check(len(stable_runs) >= 4,
          f'quatro telas do ending renderizadas (runs={stable_runs})', failures)
    if len(stable_runs) >= 4:
        expected_min = (150, 200, 350, 200)
        for index, minimum in enumerate(expected_min):
            check(stable_runs[index] >= minimum,
                  f'ending tela {index + 1} permanece estavel '
                  f'({stable_runs[index]}f >= {minimum}f)', failures)

    returned_game = wait_until(
        step, lambda: ram[A['FASE']] == 1 and ram[A['LI']] == 3, 900,
        'partida nova apos THE END', failures,
    )
    check(returned_game is not None and ram[CHR_BANK] == 0,
          'partida nova volta ao cenario espacial', failures)

    print()
    if failures:
        print(f'RESULTADO: {len(failures)} FALHA(S)')
        for failure in failures:
            print(' -', failure)
        return 1
    print('RESULTADO: V0.28 BASELINE OK')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
