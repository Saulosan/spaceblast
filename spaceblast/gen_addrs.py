#!/usr/bin/env python3
"""Regenerate the RAM-address map used by the emulator harnesses.

Paths default to this repository's generated assembly and nes-test output,
but both can be overridden for a diagnostic build::

    python3 gen_addrs.py [asm] [output]
"""
from pathlib import Path
import re
import sys

HERE = Path(__file__).resolve().parent
ASM = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else HERE / 'space-blast.asm'
OUT = (Path(sys.argv[2]).resolve() if len(sys.argv) > 2
       else HERE.parent / 'nes-test' / 'addrs_cb.py')

addr = {}
for match in re.finditer(
        r'^(cvb_[\w#]+|array_[\w#]+):\s*equ \$(\w+)',
        ASM.read_text(), re.MULTILINE | re.IGNORECASE):
    label, value = match.group(1), int(match.group(2), 16)
    upper = label.upper()
    if upper.startswith('CVB_'):
        name = upper[4:]
    elif upper.startswith('ARRAY_'):
        # 16-bit names already carry the '#' in the assembly label.
        name = upper[6:]
    else:
        name = upper
    addr[name] = value
addr['FRAME'] = 0x12

OUT.parent.mkdir(parents=True, exist_ok=True)
with OUT.open('w') as file:
    file.write('# gerado automaticamente (regenerar apos cada build)\n')
    file.write('ADDR = {\n')
    for name in sorted(addr):
        file.write(f'    "{name}": 0x{addr[name]:04X},\n')
    file.write('}\nA = ADDR\n')
print(f'{len(addr)} simbolos -> {OUT}')
