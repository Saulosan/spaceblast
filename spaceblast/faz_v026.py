#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""faz_v026.py — v0.26: scroll da fase 2 = scroll da fase 1 (ordem do Saulo).

- lava_setup vira: paleta/CHR da lava + TRES nametables identicas cheias do
  mar de lava basico (96/97/98/99). Sem ilhas, canhoes, eventos, sem anel.
- Chamada do lava_tick comentada (motor aposentado; cadaver fica no banco 3).
- Cabecalho de versao atualizado."""

import pathlib
base = pathlib.Path(__file__).parent
src = (base / "space-blast.bas").read_text()

def troca(velho, novo):
    global src
    assert src.count(velho) == 1, f"ancora: {velho[:60]!r} count={src.count(velho)}"
    src = src.replace(velho, novo)

# 1) cabecalho v0.26 (o mais novo primeiro)
troca("\t'\n\t' v0.25 (pedido do Saulo): RESET POR SOFTWARE NO GAME OVER.",
"""	'
	' v0.26 (ordem do Saulo): SCROLL DA FASE 2 = SCROLL DA FASE 1. O motor
	'   de anel (v0.19-v0.24) sai de campo: o que sempre funcionou foi o
	'   esquema da fase 1 (3 nametables identicas + scroll byte). lava_setup
	'   agora so' troca paleta/CHR ($1C=$40) e preenche as 3 paginas com o
	'   mar de lava basico (tiles 96/97/98/99 = a textura 2x2 do proprio
	'   desenho do Saulo). ZERO ilhas, canhoes, eventos e lava_tick
	'   (chamada comentada). Cadaver do anel fica dormente no banco 3.
	'
	' v0.25 (pedido do Saulo): RESET POR SOFTWARE NO GAME OVER.""")

# 2) aposenta o motor
troca("\t\t\tGOSUB lava_tick",
      "\t\t\t' GOSUB lava_tick\t' v0.26: motor de anel aposentado (scroll = fase 1)")

# 3) lava_setup simplificado
velho_setup = """lava_setup: PROCEDURE
\tPALETTE LOAD lava_palette
\tPOKE $1C,$40\t\t' CHR-RAM pagina 2 (tiles + sprites da lava)
\t' v0.24: TORUS DE 31 SLOTS = $2000 (30) + $2800 slot 0 (o 31o!).
\t' AUTOPSIAS no emu: (a) scroll e' byte 0-239 e NT bits sempre 0 ->
\t' corpo da tela le' so' $2000; (b) MAS o PPU troca p/ a NT vertical
\t' no coarse-Y 30: os ultimos (fine) px da tela vem de $2800 slot 0
\t' = faixa congelada/alien se nao for alimentada (foi o "rodape
\t' morto" da v0.23); (c) o flip TEM que ser no frame da costura,
\t' no slot do TOPO: o conteudo nasce atomico junto com o 1px que
\t' espia la' no alto; a linha velha morre limpa saindo pelo fundo
\t' (v0.23 flipava 8 frames cedo demais = "linha do futuro" no
\t' rodape = ilhas mutiladas saindo). Ordem: linhas DECREMENTAM
\t' junto com o scroll (anel 60), fase travada na 1a costura.
\tRESTORE lava_map_a
\t#bk = $2000
\tGOSUB lava_wr
\tRESTORE lava_map_a
\t#bk = $2400
\tGOSUB lava_wr
\tRESTORE lava_map_a
\t#bk = $2800
\tGOSUB lava_wr
\t' $2800 slot 0 = "31o slot": recebe a linha ABAIXO da janela
\tw = scroll_y / 8 + 30
\tIF w >= 60 THEN w = w - 60
\tGOSUB lava_strip_w
\twrf = 0\t\t\t' fase do anel: trava (1a costura -> lava_in)
\tEND"""

novo_setup = """lava_setup: PROCEDURE\t' v0.26: scroll da lava = scroll da fase 1 (PONTO)
\tPALETTE LOAD lava_palette
\tPOKE $1C,$40\t\t' CHR-RAM pagina 2 (tiles + sprites da lava)
\t' Igual a fase 1 (que sempre funcionou): TRES nametables IDENTICAS,
\t' so' conteudo estatico, e o scroll byte cuida do loop. Conteudo =
\t' mar de lava BASICO (textura 2x2 dos tiles 96/97/98/99, do proprio
\t' desenho do Saulo) e mais NADA: sem ilhas, sem canhoes, sem
\t' eventos, sem anel, sem flip, sem strip.
\t#bk = $2000
\tGOSUB lava_sea_fill
\t#bk = $2400
\tGOSUB lava_sea_fill
\t#bk = $2800
\tGOSUB lava_sea_fill
\tEND

lava_sea_fill:\t' mar de lava 2x2 em cima de #bk (30 linhas x 32 = 960)
\t#tw = #bk
\tFOR r = 0 TO 29
\t\tFOR c = 0 TO 31
\t\t\tVPOKE #tw, 96 + (c AND 1) + 2 * (r AND 1)
\t\t\t#tw = #tw + 1
\t\tNEXT c
\t\tWAIT\t\t\t' 32 writes/frame: folga no buffer do NMI
\tNEXT r
\tRETURN"""

troca(velho_setup, novo_setup)

(base / "space-blast.bas").write_text(src)
print("v0.26 aplicada")
