#!/usr/bin/env python3
"""Make the FamiStudio NESASM engine/data consumable by the project's Gasm80.

The project intentionally uses the very small Gasm80 assembler.  FamiStudio's
NESASM source uses ca65/NESASM conditional syntax, .rs declarations, indirect
square brackets and macros, so this file performs only the mechanical
translation needed for this integration.  It does not alter the musical data
semantics.
"""
from __future__ import annotations

import re
from pathlib import Path
from typing import Dict, Iterable, List, Tuple

ENGINE = Path('/tmp/FamiStudio-src/SoundEngine/famistudio_nesasm.asm')
MUSIC = Path('/tmp/intruder_famistudio.asm')
OUT_ENGINE = Path('/home/user/music-integration/famistudio_engine_gasm80.asm')
OUT_DATA = Path('/home/user/music-integration/intruder_alert_data_gasm80.asm')

# The game has the five native NES APU voices, but the existing game audio
# budget has four musical voices.  The DPCM voice is therefore deliberately
# not enabled; the integration replaces that channel with a one-byte inactive
# stream in the generated data file.
CONFIG: Dict[str, int] = {
    'FAMISTUDIO_CFG_EXTERNAL': 1,
    'FAMISTUDIO_CFG_PAL_SUPPORT': 0,
    'FAMISTUDIO_CFG_NTSC_SUPPORT': 1,
    'FAMISTUDIO_CFG_SFX_SUPPORT': 0,
    'FAMISTUDIO_CFG_SFX_STREAMS': 0,
    'FAMISTUDIO_CFG_SMOOTH_VIBRATO': 0,
    'FAMISTUDIO_CFG_DPCM_SUPPORT': 0,
    'FAMISTUDIO_CFG_EQUALIZER': 0,
    'FAMISTUDIO_CFG_THREAD': 0,
    'FAMISTUDIO_USE_FAMITRACKER_TEMPO': 0,
    'FAMISTUDIO_USE_FAMITRACKER_DELAYED_NOTES_OR_CUTS': 0,
    'FAMISTUDIO_USE_VOLUME_TRACK': 1,
    'FAMISTUDIO_USE_VOLUME_SLIDES': 0,
    'FAMISTUDIO_USE_PITCH_TRACK': 1,
    'FAMISTUDIO_USE_SLIDE_NOTES': 1,
    'FAMISTUDIO_USE_NOISE_SLIDE_NOTES': 0,
    'FAMISTUDIO_USE_VIBRATO': 1,
    'FAMISTUDIO_USE_ARPEGGIO': 1,
    'FAMISTUDIO_USE_DUTYCYCLE_EFFECT': 0,
    'FAMISTUDIO_USE_DELTA_COUNTER': 0,
    'FAMISTUDIO_USE_PHASE_RESET': 0,
    'FAMISTUDIO_USE_FDS_AUTOMOD': 0,
    'FAMISTUDIO_USE_RELEASE_NOTES': 1,
    'FAMISTUDIO_USE_DPCM_EXTENDED_RANGE': 0,
    'FAMISTUDIO_USE_INSTRUMENT_EXTENDED_RANGE': 0,
    'FAMISTUDIO_USE_DPCM_BANKSWITCHING': 0,
    'FAMISTUDIO_EXP_RAINBOW': 0,
    'FAMISTUDIO_EXP_VRC6': 0,
    'FAMISTUDIO_EXP_VRC7': 0,
    'FAMISTUDIO_EXP_EPSM': 0,
    # These derived EPSM counts are referenced by a few unconditional
    # conditional blocks later in the upstream engine.
    'FAMISTUDIO_EXP_EPSM_ENV_CNT': 0,
    'FAMISTUDIO_EXP_EPSM_RHYTHM_CNT': 0,
    'FAMISTUDIO_EXP_EPSM_TRIG_CHN': 0,
    'FAMISTUDIO_EXP_MMC5': 0,
    'FAMISTUDIO_EXP_S5B': 0,
    'FAMISTUDIO_EXP_FDS': 0,
    'FAMISTUDIO_EXP_N163': 0,
    'FAMISTUDIO_EXP_N163_CHN_CNT': 1,
    'FAMISTUDIO_EXP_EPSM_SSG_CHN_CNT': 3,
    'FAMISTUDIO_EXP_EPSM_FM_CHN_CNT': 6,
    'FAMISTUDIO_EXP_EPSM_RHYTHM_CHN1_ENABLE': 1,
    'FAMISTUDIO_EXP_EPSM_RHYTHM_CHN2_ENABLE': 1,
    'FAMISTUDIO_EXP_EPSM_RHYTHM_CHN3_ENABLE': 1,
    'FAMISTUDIO_EXP_EPSM_RHYTHM_CHN4_ENABLE': 1,
    'FAMISTUDIO_EXP_EPSM_RHYTHM_CHN5_ENABLE': 1,
    'FAMISTUDIO_EXP_EPSM_RHYTHM_CHN6_ENABLE': 1,
    'FAMISTUDIO_DPCM_OFF': 0xC000,
}

# Existing CVBasic scratch bytes.  FamiStudio documents r0-r3 and ptr0/ptr1
# as call-temporary values, so aliasing them here avoids consuming the last
# free zero-page bytes.  The integration calls the engine with interrupts
# disabled while these temporaries are live.
ZP_ALIAS = {
    'famistudio_r0': 0x02,
    'famistudio_r1': 0x03,
    'famistudio_r2': 0x04,
    'famistudio_r3': 0x05,
    'famistudio_ptr0': 0x06,
    'famistudio_ptr1': 0x08,
}
RAM_BASE = 0x0502

IDENT = re.compile(r'[A-Za-z_][A-Za-z0-9_]*')
ASSIGN = re.compile(r'^\s*([A-Za-z_.][A-Za-z0-9_.]*)\s*=\s*(.*?)\s*$')
RS = re.compile(r'^\s*([A-Za-z_.][A-Za-z0-9_.]*)(?::)?\s*\.rs\s+(.+?)\s*$', re.I)
COND = re.compile(r'^\s*\.?(ifn?def|if|else|endif)\b(.*)$', re.I)


def strip_comment(s: str) -> str:
    # Assembly comments do not contain quoted strings in the directives we
    # evaluate, but retain a small quote-aware implementation for safety.
    quote = None
    for i, c in enumerate(s):
        if c in "'\"":
            if quote is None:
                quote = c
            elif quote == c and (i == 0 or s[i - 1] != '\\'):
                quote = None
        elif c == ';' and quote is None:
            return s[:i]
    return s


def eval_expr(expr: str, env: Dict[str, int], *, where: str = '', allow_unknown: bool = False) -> int:
    """Evaluate the constant expressions used by the engine configuration."""
    expr = strip_comment(expr).strip()
    # The source uses $abcd hexadecimal literals.
    expr = re.sub(r'\$([0-9A-Fa-f]+)', r'0x\1', expr)
    # The source uses C/assembler comparison spelling.
    expr = expr.replace('&&', ' and ').replace('||', ' or ')
    expr = re.sub(r'!\s*(?!=)', ' not ', expr)
    expr = re.sub(r'(?<![<>=!])=(?!=)', '==', expr)
    # Replace known symbols.  Unknown symbols are an error instead of being
    # silently treated as zero; this catches a bad conditional early.
    def repl(m: re.Match[str]) -> str:
        name = m.group(0)
        if name in env:
            return str(env[name])
        # Python keywords introduced above are not symbols.
        if name in {'and', 'or', 'not'}:
            return name
        if allow_unknown:
            # During macro branch selection the remaining unknown names are
            # ordinary RAM/APU labels.  Their exact value is irrelevant for
            # feature flags; treating them as a non-zero address lets the
            # positional argument (0 versus a real label) decide the branch.
            return '1'
        raise ValueError(f'unknown symbol {name!r} in {where}: {expr!r}')
    expr = IDENT.sub(repl, expr)
    try:
        value = eval(expr, {'__builtins__': {}}, {})
    except Exception as exc:
        raise ValueError(f'cannot evaluate {where}: {expr!r}: {exc}') from exc
    if not isinstance(value, int):
        raise ValueError(f'non-integer expression {where}: {expr!r}')
    return value


def split_args(s: str) -> List[str]:
    args: List[str] = []
    start = 0
    depth = 0
    quote = None
    for i, c in enumerate(s):
        if c in "'\"":
            if quote is None:
                quote = c
            elif quote == c and (i == 0 or s[i - 1] != '\\'):
                quote = None
        elif quote is None:
            if c in '([':
                depth += 1
            elif c in ')]':
                depth -= 1
            elif c == ',' and depth == 0:
                args.append(s[start:i].strip())
                start = i + 1
    tail = s[start:].strip()
    if tail or args:
        args.append(tail)
    return args


def collect_macros(lines: List[str]) -> Tuple[List[str], Dict[str, Tuple[List[str], List[str]]]]:
    """Remove .macro blocks and return name -> (parameter names, body)."""
    out: List[str] = []
    macros: Dict[str, Tuple[List[str], List[str]]] = {}
    i = 0
    while i < len(lines):
        line = lines[i]
        m = re.match(r'^\s*([A-Za-z_][A-Za-z0-9_]*)\s+\.macro\b(.*)$', line, re.I)
        if not m:
            out.append(line)
            i += 1
            continue
        name = m.group(1)
        tail = strip_comment(m.group(2)).strip()
        # NESASM's comments document the positional arguments.  The actual
        # body uses \1, \2, ...; deriving the count from the body is robust.
        max_arg = 0
        for b in []:
            pass
        body: List[str] = []
        i += 1
        while i < len(lines) and not re.match(r'^\s*\.endm\b', lines[i], re.I):
            body.append(lines[i])
            i += 1
        if i == len(lines):
            raise ValueError(f'unterminated macro {name}')
        max_arg = 0
        for b in body:
            for a in re.findall(r'\\([1-9][0-9]*)', b):
                max_arg = max(max_arg, int(a))
        params = [f'\\{n}' for n in range(1, max_arg + 1)]
        macros[name.lower()] = (params, body)
        i += 1  # .endm
    return out, macros


def expand_macros(lines: List[str], macros: Dict[str, Tuple[List[str], List[str]]]) -> List[str]:
    counter = 0

    def expand(seq: Iterable[str], depth: int = 0) -> List[str]:
        nonlocal counter
        if depth > 20:
            raise ValueError('macro expansion appears recursive')
        result: List[str] = []
        for line in seq:
            code = strip_comment(line)
            m = re.match(r'^\s*([A-Za-z_][A-Za-z0-9_]*)\s*(.*?)\s*$', code)
            if not m or m.group(1).lower() not in macros:
                result.append(line)
                continue
            name = m.group(1).lower()
            args = split_args(m.group(2))
            _, body = macros[name]
            counter += 1
            suffix = f'_M{counter:04d}'
            expanded_body: List[str] = []
            for b in body:
                x = b.replace('\\@', suffix)
                for n, arg in enumerate(args, 1):
                    x = x.replace(f'\\{n}', arg)
                expanded_body.append(x)

            # NESASM macro assignments are compile-time aliases.  Gasm80
            # treats a colon-defined alias as a new global-label scope, which
            # would make later local labels such as .skip_frame resolve to the
            # wrong scope.  Resolve and remove those aliases before handing
            # the body back to the recursive expander.
            aliases: Dict[str, str] = {}
            kept: List[str] = []
            for b in expanded_body:
                am = ASSIGN.match(strip_comment(b))
                if am:
                    aname, aval = am.group(1), am.group(2)
                    for old in sorted(aliases, key=len, reverse=True):
                        aval = re.sub(r'(?<![A-Za-z0-9_.])' + re.escape(old) + r'(?![A-Za-z0-9_.])', aliases[old], aval)
                    aliases[aname] = aval.strip()
                else:
                    kept.append(b)
            if aliases:
                for pos, b in enumerate(kept):
                    for old in sorted(aliases, key=len, reverse=True):
                        b = re.sub(r'(?<![A-Za-z0-9_.])' + re.escape(old) + r'(?![A-Za-z0-9_.])', aliases[old], b)
                    kept[pos] = b
            result.extend(expand(kept, depth + 1))
        return result

    return expand(lines)


def active_lines(lines: List[str], env: Dict[str, int], *, allow_unknown: bool = False) -> List[str]:
    """Resolve all conditional assembly blocks using the constant env."""
    out: List[str] = []
    stack: List[Tuple[bool, bool]] = []  # (parent active, condition true)
    active = True
    for lineno, line in enumerate(lines, 1):
        m = COND.match(line)
        if m:
            kind = m.group(1).lower()
            tail = m.group(2).strip()
            if kind in {'if', 'ifdef', 'ifndef'}:
                parent = active
                if not parent:
                    cond = False
                elif kind == 'ifdef':
                    sym = strip_comment(tail).strip()
                    cond = sym in env
                elif kind == 'ifndef':
                    sym = strip_comment(tail).strip()
                    cond = sym not in env
                else:
                    cond = eval_expr(tail, env, where=f'conditional line {lineno}', allow_unknown=allow_unknown) != 0
                stack.append((parent, cond))
                active = parent and cond
            elif kind == 'else':
                if not stack:
                    raise ValueError(f'ELSE without IF at line {lineno}')
                parent, cond = stack[-1]
                active = parent and not cond
                stack[-1] = (parent, not cond)
            else:
                if not stack:
                    raise ValueError(f'ENDIF without IF at line {lineno}')
                stack.pop()
                active = True if not stack else (stack[-1][0] and stack[-1][1])
            continue
        if active:
            out.append(line)
            # Keep the evaluator's symbol table in step with local macro
            # constants, e.g. idx_M0001 = 3, before their IF lines.
            a = ASSIGN.match(strip_comment(line))
            if a:
                name, expr = a.group(1), a.group(2)
                try:
                    env[name] = eval_expr(expr, env, where=f'assignment line {lineno}', allow_unknown=allow_unknown)
                except ValueError:
                    # Labels such as .ptr are real assembly symbols but are
                    # not needed for the remaining conditional expressions.
                    pass
    if stack:
        raise ValueError('unterminated conditional block')
    return out


def translate_engine(lines: List[str]) -> Tuple[List[str], int, Dict[str, int]]:
    env = dict(CONFIG)
    # Remove macro definitions before resolving conditionals: macro bodies
    # contain parameterized IF expressions such as "pitch_shift\\@ >= 1"
    # which are intentionally evaluated only after a call is expanded.
    no_macros, macros = collect_macros(lines)
    # Resolve config/feature branches, expand the surviving calls, then
    # resolve the parameterized branches inside those expansions.
    first = active_lines(no_macros, env)
    expanded = expand_macros(first, macros)
    env2 = dict(env)
    selected = active_lines(expanded, env2, allow_unknown=True)

    out: List[str] = []
    ram = RAM_BASE
    defined_config = set(CONFIG)
    for lineno, raw in enumerate(selected, 1):
        code = strip_comment(raw)
        if not code.strip():
            out.append(raw)
            continue
        # Configuration aliases already provided above must not be emitted a
        # second time.  Derived symbols are retained as normal EQU labels.
        a = ASSIGN.match(code)
        if a:
            name, expr = a.group(1), a.group(2)
            if name in defined_config:
                continue
            out.append(f'{name}: EQU {expr}')
            try:
                env2[name] = eval_expr(expr, env2, where=f'assembly assignment {name}')
            except ValueError:
                pass
            continue
        r = RS.match(code)
        if r:
            name, expr = r.group(1), r.group(2)
            if name in ZP_ALIAS:
                out.append(f'{name}: EQU ${ZP_ALIAS[name]:04X}')
            else:
                size = eval_expr(expr, env2, where=f'RAM declaration {name}')
                if size < 0:
                    raise ValueError(f'negative RAM declaration {name}: {size}')
                out.append(f'{name}: EQU ${ram:04X}')
                env2[name] = ram
                ram += size
            continue
        # Remove directives that have no Gasm80 equivalent.  They are not
        # emitted by the active external configuration in normal operation,
        # but filtering them here makes the translator safe for updates.
        if re.match(r'^\s*\.(?:zp|bss|code|bank|org|rsset)\b', code, re.I):
            continue
        inc = re.match(r'^\s*\.incbin\s+"([^"]+)"', code, re.I)
        if inc:
            inc_path = ENGINE.parent / inc.group(1)
            payload = inc_path.read_bytes()
            out.append(f'; embedded {inc.group(1)} ({len(payload)} bytes)')
            for pos in range(0, len(payload), 16):
                chunk = payload[pos:pos + 16]
                out.append('DB ' + ','.join(f'${b:02X}' for b in chunk))
            continue
        x = raw
        if re.match(r'^\s*brk\s*$', code, re.I):
            out.append('DB $00 ; BRK (unreachable invalid-opcode trap)')
            continue
        x = re.sub(r'^\s*\.(?:db|byte)\b', lambda m: m.group(0)[:len(m.group(0))-2] + 'DB' if False else 'DB', x, flags=re.I)
        x = re.sub(r'^\s*\.(?:dw|word)\b', 'DW', x, flags=re.I)
        # NESASM's [ptr],Y is the same 6502 addressing mode as Gasm80's
        # (ptr),Y.  Unary < is only a zero-page assertion in the source; the
        # assembler selects zero-page automatically from the EQU address.
        before_comment, sep, comment = x.partition(';')
        before_comment = before_comment.replace('[', '(').replace(']', ')')
        before_comment = re.sub(r'\bLOW\(([^()]+)\)', r'(\1 & $FF)', before_comment, flags=re.I)
        before_comment = re.sub(r'\bHIGH\(([^()]+)\)', r'(\1 >> 8)', before_comment, flags=re.I)
        before_comment = re.sub(r'%([01]+)', r'0b\1', before_comment)
        before_comment = re.sub(r'(?<!<)<(?=[A-Za-z_.#])', '', before_comment)
        x = before_comment + (sep + comment if sep else '')
        out.append(x)
    return out, ram, env2


def translate_data() -> List[str]:
    lines = MUSIC.read_text().splitlines()
    out: List[str] = []
    in_ch4 = False
    for raw in lines:
        # The DPCM channel is intentionally removed: it cannot coexist with
        # this ROM's nearly full fixed $C000-$FFFF bank.  The engine is built
        # with DPCM disabled and ignores channel index 4.  Keep a valid pointer
        # target so the five-entry FamiStudio song list remains well-formed.
        if re.match(r'^\.song0ch4\s*:', raw, re.I):
            in_ch4 = True
            out.append('.song0ch4:\n\tDB $FF')
            continue
        if in_ch4:
            continue
        x = raw
        x = re.sub(r'^\s*\.(?:db|byte)\b', 'DB', x, flags=re.I)
        x = re.sub(r'^\s*\.(?:dw|word)\b', 'DW', x, flags=re.I)
        # FamiStudio emits these functions in the data header.  Gasm80 has
        # ordinary expressions but no LOW/HIGH functions.
        x = re.sub(r'\bLOW\(([^()]+)\)', r'(\1 & $FF)', x, flags=re.I)
        x = re.sub(r'\bHIGH\(([^()]+)\)', r'(\1 >> 8)', x, flags=re.I)
        out.append(x)
    return out


def main() -> None:
    engine_lines, ram_end, env = translate_engine(ENGINE.read_text().splitlines())
    data_lines = translate_data()
    OUT_ENGINE.parent.mkdir(parents=True, exist_ok=True)
    header = [
        '; Generated mechanically from FamiStudio NESASM engine.',
        '; Configuration: NTSC, native 2A03 channels 0-3, no DPCM/SFX.',
        '; Temporary ZP aliases: $02-$09; engine RAM starts at $0502.',
        'FAMISTUDIO_BANK: EQU 3',
        'FAMISTUDIO_ACTIVE: EQU $0500',
        'FAMISTUDIO_SAVED_BANK: EQU $0501',
        'FAMISTUDIO_DPCM_OFF: EQU $C000',
        'ORG $8000',
        '',
    ]
    OUT_ENGINE.write_text('\n'.join(header + engine_lines) + '\n')
    data_header = [
        '; Intruder Alert data generated by FamiStudio from intruder_alert.nsf.',
        '; Channel 4 (DPCM) replaced with a valid inactive sentinel for this NES ROM.',
        '',
    ]
    OUT_DATA.write_text('\n'.join(data_header + data_lines) + '\n')
    print(f'engine={OUT_ENGINE} lines={len(engine_lines)} ram_end=${ram_end:04X}')
    print(f'data={OUT_DATA} lines={len(data_lines)}')


if __name__ == '__main__':
    main()
