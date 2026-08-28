#!/usr/bin/env python3
# Regenera /home/user/nes-test/addrs_cb.py a partir de space-blast.asm
# (rodar DEPOIS de cada build). Mapa: CVB_X -> X, CVB_ARRAY_ARR -> #ARR.
import re, sys

ASM = '/home/user/spaceblast/space-blast.asm'
OUT = '/home/user/nes-test/addrs_cb.py'

addr = {}
for m in re.finditer(r'^(cvb_[\w#]+|array_[\w#]+):\s*equ \$(\w+)', open(ASM).read(), re.M | re.I):
    lbl, val = m.group(1), int(m.group(2), 16)
    u = lbl.upper()
    if u.startswith('CVB_'):
        name = u[4:]
    elif u.startswith('ARRAY_'):
        name = u[6:]   # 16-bit ja' vem com '#' no rotulo (array_#SHY)
    else:
        name = u
    addr[name] = val
addr['FRAME'] = 0x12
with open(OUT, 'w') as f:
    f.write('# gerado automaticamente (regenerar apos cada build)\nADDR = {\n')
    for k in sorted(addr):
        f.write(f'    "{k}": 0x{addr[k]:04X},\n')
    f.write('}\nA = ADDR\n')
print(f'{len(addr)} simbolos -> {OUT}')
