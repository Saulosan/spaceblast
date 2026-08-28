import ctypes, sys
sys.path.insert(0, '/home/user/nes-test')
from addrs_cb import ADDR as A
exec(open('/tmp/probe2.py').read().split("giff = []")[0].replace("def bot(rec, n):", "def _nao_usa(rec, n):"))
run(150); held.add(BT['START']); run(6); held.discard(BT['START']); run(30)
while not ram[A['MBA']]: run()
while ram[A['MBS']] == 1: run()
run(300)  # deixa patrulhar um pouco
print('yc=%d mbx=%d mlr=%d' % ((u16(A['#MBY'])//16)-256, ram[A['MBX']], ram[A['MLR']]))
# alinha px com o centro do miniboss e injeta bala natural no slot 0
ram[A['PX']] = ram[A['MBX']] + 8     # centro do corpo (32px) menos metade da nave
slot = 0
while ram[A['BTY']+slot]: slot += 1
ram[A['BTX']+slot] = ram[A['MBX']] + 12
ram[A['BTY']+slot] = 150
hp0 = ram[A['MBHP']]
for f in range(30):
    run()
    print('f=%d bty=%d btx=%d mbx=%d yc=%d MBHP=%d MLR=%d' % (
        f, ram[A['BTY']+slot], ram[A['BTX']+slot], ram[A['MBX']],
        (u16(A['#MBY'])//16)-256, ram[A['MBHP']], ram[A['MLR']]))
