# game over DURANTE o boss: morre na caixa de contato dele
import ctypes, sys
from PIL import Image
sys.path.insert(0, '/home/user/nes-test')
exec(open('v13_boss2.py').read().split("# ============ BOSS")[0])
ram[A['NSMA']] = 4; ram[A['NSHA']] = 4; ram[A['NE4']] = 4
for c in range(6): ram[A['SMA']+c] = 0
for c in range(4): ram[A['SHA']+c] = 0
for c in range(8): ram[A['E4A']+c] = 0
while not ram[A['BSA']]: run()
run(100)
shot('v13_go_antes')
ram[A['LI']] = 1
INV_MODE['on'] = False
ram[A['INV']] = 0
f = 0
while not ram[A['DED']] and f < 400:
    ram[A['PX']] = 112; ram[A['PY']] = 60   # se joga no corpo do boss
    ram[A['INV']] = 0
    run(); f += 1
print('morto no boss em %df (ded=%d)' % (f, ram[A['DED']]))
run(500)
shot('v13_go_tela')
print('li=%d' % ram[A['LI']])
