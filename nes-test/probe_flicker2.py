import ctypes, sys
sys.path.insert(0, '/home/user/nes-test')
exec(open('v13_boss2.py').read().split("# ============ BOSS")[0])
held.add(3); run(6); held.discard(3); run(30)
# espera a onda small 3+3 encher os 6 slots
f = 0
while sum(ram[A['SMA']+c] for c in range(6)) < 6 and f < 3000:
    run(); f += 1
print('6 slots ativos em %df (wnum=%d)' % (f, ram[A['WNUM']]))
# aperta os 6 na mesma linha y=96, colados
for c in range(6):
    v = ((96+256)*16)
    ram[A['#SMY'] + c*2] = v & 255
    ram[A['#SMY'] + c*2 + 1] = (v >> 8) & 255
    ram[A['SMP']+c] = 40 + c*30
    ram[A['SMC']+c] = 0       # sem zig: grudados na linha
    ram[A['SNV']+c] = 0
run(3)
shot('flicker6')
# OAM na faixa 88-104 (y byte ~95)
slots = [s for s in range(64) if ram[0x200+s*4] != 0xF0 and 88 <= ram[0x200+s*4] <= 104]
print('OAM sprites na faixa (~linha 96): %d -> slots %s' % (len(slots), slots))
# nave + tiros tambem na linha? coloca a nave na linha deles
ram[A['PY']] = 96
held.add(BT['B']); run(2); held.discard(BT['B'])
run(1)
slots = [s for s in range(64) if ram[0x200+s*4] != 0xF0 and 88 <= ram[0x200+s*4] <= 104]
print('com nave+tiros: %d slots' % len(slots))
shot('flicker6_nave')
