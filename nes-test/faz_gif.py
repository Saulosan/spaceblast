#!/usr/bin/env python3
# Captura gameplay em frames e monta um GIF animado (scroll + tiros + split).
exec(open('/home/user/nes-test/teste_v2.py').read().split("print('== A: titulo')")[0])

def frame_pil():
    w, h, p = last['w'], last['h'], last['p']
    a = np.frombuffer(last['buf'], dtype=np.uint8).reshape(h, p)[:, :w*4].reshape(h, w, 4)
    return Image.fromarray(a[:,:,:3][:,:,::-1])

step(150)
step(3, {B['START']})
step(30)

# mira contínua no primeiro meteoro visível (para o split acontecer em cena)
alvo = -1
frames = []
for t in range(210):
    if alvo < 0:
        for c in range(4):
            if 10 < ri16(MY + 2*c) < 140: alvo = c
    else:
        if ri16(MY + 2*alvo) < 220 and rd(SMA+0) == 0:
            wr(PX, max(16, min(224, rd(MX+alvo) - 2)))
    step(1, {B['B']})
    if t % 3 == 0:
        frames.append(frame_pil().resize((512, 480), Image.NEAREST))

frames[0].save('/home/user/cata-estrelas/docs/6_gameplay.gif',
               save_all=True, append_images=frames[1:], duration=50, loop=0)
print('GIF salvo com', len(frames), 'frames')
