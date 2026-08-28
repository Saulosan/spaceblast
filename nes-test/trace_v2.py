#!/usr/bin/env python3
# Trace do split: estado controlado, log frame a frame.
exec(open('/home/user/nes-test/teste_v2.py').read().split("print('== A: titulo')")[0])

step(150)
step(3, {B['START']})
step(30)

# Estado controlado: meteoro 0 alinhado com a nave, descendo
wr(MX + 0, 120)          # mx(0) = 120
wr(0x86, 100); wr(0x87, 0)   # #my(0) = 100
wr(MS + 0, 2)            # velocidade 2
wr(PX, 118)              # nave alinhada (btx = 124 ≈ centro 124-128)
wr(PY, 172)

print('f | my0 | bty0..3 | sma_ativos | score')
for f in range(80):
    step(1, {B['B']})
    if f % 4 == 0:
        print(f'{f:3} | {ri16(MY):4} | {[rd(BTY+i) for i in range(4)]!s:20} | {sum(rd(SMA+i) for i in range(8))} | {ri16(SCORE)}')
    if sum(rd(SMA+i) for i in range(8)) >= 2:
        print(f'*** SPLIT no frame {f}! bty={[rd(BTY+i) for i in range(4)]} my0={ri16(MY)} score={ri16(SCORE)}')
        for i in range(8):
            if rd(SMA+i): print(f'    small{i}: x={rd(SMX+i)} y={ri16(SMY+2*i)}')
        break
