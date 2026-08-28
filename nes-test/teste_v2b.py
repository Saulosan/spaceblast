#!/usr/bin/env python3
# Validação v2b: cadencia, split com mira contínua, kill de pequeno, morte por pequeno.
exec(open('/home/user/nes-test/teste_v2.py').read().split("print('== A: titulo')")[0])
# DT vem do addrs (#dt: só != 0 durante a explosao do jogador)

step(150); shot('w_1_titulo')
step(3, {B['START']})
step(90, {B['B']})
print('fase tiros: bty:', [rd(BTY+i) for i in range(4)], ' score:', ri16(SCORE))
shot('w_2_tiros_separados')

print('fase split:')
alvo = -1
for t in range(1500):
    for c in range(4):
        y = ri16(MY + 2*c)
        if 30 < y < 150: alvo = c
    if alvo >= 0: break
    step(1, {})
print('  alvo:', alvo)
ok_split = False
s0 = ri16(SCORE)
def mira(): wr(PX, max(16, min(224, rd(MX+alvo) - 2)))
for f in range(240):
    step(1, {B['B']}, mira)
    if rd(DT) != 0:
        print('  JOGADOR MORREU no frame', f, '(pequeno o atingiu?)'); break
    n = sum(rd(SMA+i) for i in range(8))
    if n >= 2:
        ok_split = True; fs = f; break
if ok_split:
    print(f'  SPLIT ok no frame {fs}! score {s0} -> {ri16(SCORE)}')
    for i in range(8):
        if rd(SMA+i): print(f'    small{i}: x={rd(SMX+i)} y={ri16(SMY+2*i)}')
    shot('w_3_split')
else:
    shot('w_3_split_falhou')

print('fase kill de pequeno:')
z = next((i for i in range(8) if rd(SMA+i) and ri16(SMY+2*i) > 40 and ri16(SMY+2*i) < 130), -1)
print('  alvo pequeno:', z)
ok_kill = False
if z >= 0:
    s0 = ri16(SCORE)
    def mira2():
        if rd(SMA+z) and ri16(SMY+2*z) < 150: wr(PX, max(16, min(224, rd(SMX+z) - 4)))
    for f in range(240):
        step(1, {B['B']}, mira2)
        if rd(DT) != 0: print('  MORREU no frame', f); break
        if rd(SMA+z) == 0:
            ok_kill = True; fk = f; break
if ok_kill:
    print(f'  KILL ok no frame {fk}! score {s0} -> {ri16(SCORE)} | #pop={ri16(POP)} #bng={ri16(BNG)}')
    shot('w_4_kill_minexplosao')

print('fase morte por pequeno:')
z2 = next((i for i in range(8) if rd(SMA+i) and ri16(SMY+2*i) < 120), -1)
print('  assassino:', z2)
if z2 >= 0:
    wr(SMY + 2*z2, rd(PY)); wr(SMY + 2*z2 + 1, 0)
    wr(SMX + z2, (rd(PX) + 2) & 0xff)
    step(2, {})
    print('  #dt apos colisao:', rd(DT))
    step(25); shot('w_5_explosao')
    step(120); shot('w_6_gameover')
else:
    print('  sem pequeno disponivel; pegando meteoro grande mesmo:')
    # força: teleporta meteoro grande vivo sobre a nave
    c = next((i for i in range(4) if 0 < ri16(MY+2*i) < 120), -1)
    if c >= 0:
        wr(MY + 2*c, rd(PY)); wr(MY + 2*c + 1, 0); wr(MX + c, rd(PX))
        step(2, {})
        print('  #dt:', rd(DT))
        step(25); shot('w_5_explosao')
        step(120); shot('w_6_gameover')
print('  score final:', ri16(SCORE))
step(3, {B['START']})
step(60); shot('w_7_volta_titulo')
print('FIM')
