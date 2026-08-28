# forca 6 smalls na MESMA linha + tiros: conta sprites/scanline e ve quem some
import ctypes, sys
sys.path.insert(0, '/home/user/nes-test')
exec(open('v13_boss2.py').read().split("# ============ BOSS")[0])
held.add(3); run(6); held.discard(3); run(30)
# forja 6 smalls vivos, todos na linha y=96, x variados
for c in range(6):
    ram[A['SMA']+c] = 1
    ram[A['#SMY'] + c*2] = ((96+256)*16) & 255
    ram[A['#SMY'] + c*2 + 1] = ((96+256)*16) >> 8
    ram[A['SMP']+c] = 60 + c*24
    ram[A['SMC']+c] = 24
    ram[A['SNV']+c] = 0       # parados na linha (so teste)
    ram[A['SMD']+c] = 30
    ram[A['SMF']+c] = 0
run(3)
shot('flicker_smalls')
# conta sprites nao-vazios por linha olhando a shadow OAM ($0200)
faixas = {}
for s in range(64):
    y = ram[0x200 + s*4]
    if y != 0xF0 and 96 <= y - 1 < 112:
        faixas.setdefault('linha96', []).append(s)
print('sprites OAM na faixa y96-112 (%d):' % sum(len(v) for v in faixas.values()), faixas)
