#!/usr/bin/env python3
# Captura a animação de explosão
exec(open('/home/user/nes-test/fceumm_test.py').read().split('# --- roteiro do teste ---')[0])

run(150)
press({BTN['START']}, 3)
run(120)
# força colisão assim que algum meteoro estiver perto da nave (y ~ 160)
best = -1
for t in range(600):
    for c in range(4):
        my = rd(0x60 + 2*c) | (rd(0x61 + 2*c) << 8)
        if my > 32767: my -= 65536
        if 100 < my < 220:
            best = c
    if best >= 0:
        break
    run(1)
if best >= 0:
    wr(0x5d, rd(0x8c + best))   # px = mx(c)
    wr(0x5e, 160)               # py = 160 (perto da rotação do meteoro)
run(20)
shot('gt_8_explosao_a')
run(12)
shot('gt_9_explosao_b')
print('FIM')
