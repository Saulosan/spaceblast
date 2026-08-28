# Mede slowdown real: delta do contador frame (<frame> do CVBasic) por emu-frame.
# delta=1 ok; delta>=2 = frame perdido (loop nao coube em 1 vblank).
import ctypes, sys
sys.path.insert(0, '/home/user/nes-test')
exec(open('v13_boss2.py').read().split("# ============ BOSS")[0])
held.add(3); run(6); held.discard(3); run(30)

def mede(n, tag):
    f0 = ram[0x12] | (ram[0x12+1] << 8)
    perd = 0
    fa = ram[0x12]
    for i in range(n):
        run()
        fb = ram[0x12]
        d = (fb - fa) & 0xff
        if d > 1: perd += d - 1
        fa = fb
    print('%s: %d frames perdidos em %d (%.1f%%)' % (tag, perd, n, 100.0*perd/n))

# varre as ondas: small (roxo), shard, enemy4... loga quando ativa
ram[A['NSMA']] = 0; ram[A['NSHA']] = 0; ram[A['NE4']] = 0
for fase in range(6):
    # espera uma onda ativa
    f = 0
    while ram[A['WACT']] == 0 and f < 1200: run(); f += 1
    w = ram[A['WNUM']] & 3
    run(120)  # deixa encher a tela
    ns = sum(ram[A['SMA']+c] for c in range(6))
    ne = sum(ram[A['E4A']+c] for c in range(8))
    nh = sum(ram[A['SHA']+c] for c in range(4))
    # tiro pra gerar mais trabalho
    held.add(BT['B'])
    mede(300, 'onda wnum=%d smalls=%d e4=%d shards=%d' % (ram[A['WNUM']], ns, ne, nh))
    held.discard(BT['B'])
    # esgota a onda
    f = 0
    while ram[A['WACT']] == 1 and f < 3000: run(); f += 1
