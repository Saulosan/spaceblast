#!/usr/bin/env python3
# Aplica a tela splash FALCON SOFT (v0.16) no space-blast.bas.
BAS = '/home/user/spaceblast/space-blast.bas'
src = open(BAS).read()
inc = open('/home/user/spaceblast/falcon_chr.bas.inc').read()

# divide inc: parte CHR (ate antes de "falcon_map:") e parte DATA
i = inc.index('falcon_map:')
chr_part = inc[:i].rstrip() + '\n'
data_part = inc[i:].rstrip() + '\n'

fade = """
' Fade da splash por palette cycling (idx2=cinza, idx3=branco).
' 7 passos x 4 frames ~0.47s por direcao.
fade_tbl:
\tDATA BYTE $0F,$0F
\tDATA BYTE $0F,$00
\tDATA BYTE $00,$00
\tDATA BYTE $00,$10
\tDATA BYTE $10,$10
\tDATA BYTE $10,$20
\tDATA BYTE $10,$30
fade_tbl_out:
\tDATA BYTE $10,$30
\tDATA BYTE $10,$20
\tDATA BYTE $10,$10
\tDATA BYTE $00,$10
\tDATA BYTE $00,$00
\tDATA BYTE $0F,$00
\tDATA BYTE $0F,$0F
"""

proc = """
\t' v0.16: SPLASH FALCON SOFT. CHR-ROM pagina 1 via POKE $1C,$20 (BANKSEL
\t' bits 5-6 do CHR-RAM; o NMI restaura ORA CHRRAM_BANK a cada frame).
\t' Logo 128x80 (tiles 96-181) centralizada + "apresenta" (tiles 182-188,
\t' glifos da fonte CVBasic). Fade por PALETTE CYCLING em $3F02/$3F03
\t' (7 passos x 4 frames). Qualquer botao corta DIRETO p/ o titulo;
\t' senao, ~3.4s e sai com o mesmo fade suave.
falcon_splash: PROCEDURE
\tPOKE $1C,$20
\tSCREEN DISABLE
\tCLS
\tRESTORE falcon_map
\tFOR r = 0 TO 159
\t\tREAD BYTE e
\t\tIF e THEN
\t\t\t#tw = r / 16 + 9
\t\t\t#tw = #tw * 32
\t\t\te2 = r AND 15
\t\t\t#tw = #tw + e2 + 8
\t\t\tVPOKE $2000 + #tw, e
\t\tEND IF
\tNEXT r
\tRESTORE falcon_txt
\tFOR r = 0 TO 8
\t\tREAD BYTE e
\t\tVPOKE $2000 + 651 + r, e
\tNEXT r
\tVPOKE $3F00,$0F
\tVPOKE $3F01,$0F
\tVPOKE $3F02,$0F
\tVPOKE $3F03,$0F
\tWAIT
\tSCREEN ENABLE
\tRESTORE fade_tbl
\tFOR sk = 0 TO 1
\t\tFOR r = 0 TO 6
\t\t\tREAD BYTE e
\t\t\tREAD BYTE e2
\t\t\tVPOKE $3F02,e
\t\t\tVPOKE $3F03,e2
\t\t\tFOR q = 0 TO 3
\t\t\t\tWAIT
\t\t\t\tIF CONT1.KEY = 11 THEN GOTO fs_fim
\t\t\t\tIF CONT1.BUTTON THEN GOTO fs_fim
\t\t\tNEXT q
\t\tNEXT r
\t\tIF sk = 0 THEN
\t\t\t' hold ~2.5s com a logo acesa
\t\t\tFOR q = 0 TO 149
\t\t\t\tWAIT
\t\t\t\tIF CONT1.KEY = 11 THEN GOTO fs_fim
\t\t\t\tIF CONT1.BUTTON THEN GOTO fs_fim
\t\t\tNEXT q
\t\t\tRESTORE fade_tbl_out
\t\tEND IF
\tNEXT sk
fs_fim:
\tSCREEN DISABLE
\tPOKE $1C,$00
\tWAIT
\tEND
"""

# 1) PROC: dentro da regiao do BANK 1, antes do primeiro CHRROM 0
anchor = "\n\tCHRROM 0\n"
assert src.count(anchor) == 1
src = src.replace(anchor, "\n" + proc + anchor, 1)

# 2) DATA (falcon_map, falcon_txt) + fades: no bank 0, logo apos logo_map
import re
m = re.search(r"(logo_map:\n(?:\tDATA BYTE .*\n)+)", src)
assert m, "logo_map nao achado"
src = src[:m.end()] + "\n" + data_part + fade + src[m.end():]

# 3) CHRROM 1 (tiles da Falcon): antes do marcador BANK 2
anchor = "\nBANK 2"
assert anchor in src
src = src.replace(anchor, "\n" + chr_part + anchor, 1)

# 4) hook no boot: splash antes da primeira ida ao titulo
anchor = "\ntitle_screen:"
assert src.count(anchor) == 1
src = src.replace(anchor,
    "\n\t' v0.16: splash FALCON SOFT (so no boot; game over volta direto\n\t' p/ title_screen sem passar aqui)\n\tBANK SELECT 1\n\tGOSUB falcon_splash\n\tBANK SELECT 0\n\ntitle_screen:", 1)

open(BAS, 'w').write(src)
print("splash aplicada.")
