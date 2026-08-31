#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
aplica_v019.py — v0.19 "Planeta de Lava": cirurgia no space-blast.bas.

1. DIM das variaveis novas (fase, scroll-480 da lava, canhoes, cerimonia).
2. Game over -> START volta a FALCON SOFT (restart_boot), nao ao begin_game.
3. Remove "ONDA: n" do game over (contador de ondas some de todo o jogo).
4. Trigger do boss GATED p/ fase 1 (fase 2 nao tem boss ainda).
5. begin_game: fase=1; novo rotulo begin_stage (pos-cartao) p/ entrada de fase.
6. Setup de fundo split: fase 1 = estrelas/page 0; fase 2 = lava_setup (bank 3).
7. Scroll: wrap 240px + toggle de nametable-base (bloco lava = 480px, 2 metades);
   pulso da lava ($3F01 $16/$17); chamada dos canhoes (bank 3) a cada frame.
8. Morte do boss: bsc=70 -> game_loop faz ESTROBO + explosoes repetidas no
   lugar do boss; ao fim, GOTO fase1_clear -> "FASE 01 COMPLETA" (fade) ->
   cartao "FASE 02 / PLANETA DE LAVA" (fade) -> begin_stage com fase=2.
9. Procs novas no BANK 1: fase_completa, fase2_card.
10. Novo BANK 3: lava_setup (detecta espelhamento, preenche A/B, canhoes),
    lava_cannons (mira+atira), lava_wr; dados lava_layout.bas.inc MERGED.
11. CHRROM 2 (lava_chr2.bas.inc) anexado no fim do .bas.
"""
from pathlib import Path

HERE = Path(__file__).resolve().parent
BAS = HERE / 'space-blast.bas'
src = BAS.read_text(encoding='utf-8')

def rep(old, new, cnt=1):
    global src
    assert src.count(old) == cnt, ('anchor x%d?!' % src.count(old), old[:70])
    src = src.replace(old, new, cnt)

# ---------- 1. DIM ----------
rep("\tDIM #stw(48)\t\t' layout de estrelas: offset do setor na nametable (0-959)",
    "\tDIM #stw(48)\t\t' layout de estrelas: offset do setor na nametable (0-959)\n"
    "\tDIM fase,ntb,mirb,bsc,ph,sy\t' v0.19: fase atual, base NT lava 480px, espelho,\n"
    "\t\t\t\t\t\t\t\t'   contador da cerimonia p/ transicao, fase janela, tmp\n"
    "\tDIM cnc(5),cnx(5),cny(5)\t' v0.19: canhoes da lava: cooldown, x meta, linha meta")

# ---------- 2. game over -> Falcon ----------
rep("\tBANK SELECT 1\n\tGOSUB falcon_splash\n\tBANK SELECT 0\n\ntitle_screen:",
    "\trestart_boot:\t\t\t' v0.19: START no game over volta ao INICIO do jogo\n"
    "\tBANK SELECT 1\n\tGOSUB falcon_splash\n\tBANK SELECT 0\n\ntitle_screen:")
rep("\tIF CONT1.KEY = 11 THEN GOTO begin_game\n\tIF CONT1.BUTTON THEN GOTO begin_game\n\tGOTO go_wait",
    "\tIF CONT1.KEY = 11 THEN GOTO restart_boot\t' v0.19: inicio do jogo!\n"
    "\tIF CONT1.BUTTON THEN GOTO restart_boot\n\tGOTO go_wait")

# ---------- 3. sem ONDA no game over + APERTE volta a linha 14 ----------
rep('\tPRINT AT 455,"ONDA: ",<2>wnum + 1\n', '')
rep('go_wait:\n\tWAIT\n\tIF (FRAME AND 16) = 0 THEN\n\t\tPRINT AT 522,"APERTE START"\n\tELSE\n\t\tPRINT AT 522,"            "\n\tEND IF',
    'go_wait:\n\tWAIT\n\tIF (FRAME AND 16) = 0 THEN\n\t\tPRINT AT 458,"APERTE START"\n\tELSE\n\t\tPRINT AT 458,"            "\n\tEND IF')

# ---------- 4. boss so na fase 1 ----------
rep("\t\t\tIF nsma >= 4 THEN\n\t\t\t\tIF nsha >= 4 THEN\n\t\t\t\t\tIF ne4 >= 4 THEN btry = 1\n\t\t\t\tEND IF\n\t\t\tEND IF",
    "\t\t\tIF nsma >= 4 THEN\n\t\t\t\tIF nsha >= 4 THEN\n\t\t\t\t\tIF fase = 1 THEN\t' v0.19: fase 2 ainda nao tem boss\n\t\t\t\t\t\tIF ne4 >= 4 THEN btry = 1\n\t\t\t\t\tEND IF\n\t\t\t\tEND IF\n\t\t\tEND IF")

# ---------- 5. begin_game / begin_stage ----------
rep("begin_game:\n\tBANK SELECT 1\t\t' v0.18: cartao \"FASE 01\" antes de comecar (banco 1)\n\tGOSUB stage_card\n\tBANK SELECT 0\n\tBANK SELECT 2\t\t' v0.15: idem (trilha no banco 2)",
    "begin_game:\n\tfase = 1\t\t\t' v0.19: partida nova = sempre fase 1\n\tBANK SELECT 1\t\t' v0.18: cartao \"FASE 01\" antes de comecar (banco 1)\n\tGOSUB stage_card\n\tBANK SELECT 0\n"
    "begin_stage:\t\t\t' v0.19: entrada de fase sem cartao (a dela ja passou)\n\tBANK SELECT 2\t\t' v0.15: idem (trilha no banco 2)")

# ---------- 6. setup do fundo por fase ----------
rep("\t' Fundo de estrelas: mesmo layout nas 2 nametables ($2000/$2400)\n\tSCREEN DISABLE\n\tPALETTE LOAD game_palette_play\n\tFOR i = 0 TO 63\t\t' zera atributos herdados da tela de titulo\n\t\tVPOKE $23C0 + i,0\t' (das 3 nametables!)\n\t\tVPOKE $27C0 + i,0\n\t\tVPOKE $2BC0 + i,0\n\tNEXT i\n\tWAIT\t\t\t' drena o buffer da PPU antes de mais escritas\n\tGOSUB stars_fill\n\tSCREEN ENABLE",
    "\t' Fundo: fase 1 = estrelas / fase 2 = LAVA (banco 3)\n\tSCREEN DISABLE\n\tIF fase = 2 THEN\n\t\tBANK SELECT 3\t\t' tiles/terreno/canhao da lava moram no banco 3\n\t\tGOSUB lava_setup\n\t\tBANK SELECT 0\n\tELSE\n\t\tPALETTE LOAD game_palette_play\n\t\tPOKE $1C,$00\t\t' fase 1 = pagina 0 do CHR-RAM\n\tEND IF\n\tFOR i = 0 TO 63\t\t' zera atributos herdados da tela de titulo\n\t\tVPOKE $23C0 + i,0\t' (das 3 nametables!)\n\t\tVPOKE $27C0 + i,0\n\t\tVPOKE $2BC0 + i,0\n\tNEXT i\n\tWAIT\t\t\t' drena o buffer da PPU antes de mais escritas\n\tIF fase = 1 THEN GOSUB stars_fill\n\tntb = 0\t\t\t' v0.19: janela da lava comeca pela metade A\n\tSCREEN ENABLE")

# ---------- 7. scroll 480 + pulso + canhoes ----------
rep("\t\tscroll_y = scroll_y - 1\n\t\tIF scroll_y = $ff THEN scroll_y = $ef\n\t\tSCROLL 0, scroll_y",
    "\t\tscroll_y = scroll_y - 1\n\t\tIF scroll_y = $ff THEN\n\t\t\tscroll_y = $ef\n\t\t\tIF fase = 2 THEN\t' v0.19: bloco lava = 480px (2 metades)\n\t\t\t\tIF ntb = 0 THEN ntb = mirb ELSE ntb = 0\n\t\t\t\te = $E8\t\t' ctrl: NMI on, spr 8x16, BG $0000, pagina 2\n\t\t\t\te = e + ntb\t' + bit(s) de nametable-base do wrap\n\t\t\t\tASM LDA e\n\t\t\t\tASM STA ppu_ctrl\n\t\t\tEND IF\n\t\tEND IF\n\t\tSCROLL 0, scroll_y\n\t\tIF fase = 2 THEN\t' v0.19: pulso da lava ($16/$17, 2x por segundo)\n\t\t\tIF (FRAME AND 32) = 0 THEN VPOKE $3F01,$16 ELSE VPOKE $3F01,$17\n\t\tEND IF\n\t\tIF fase = 2 THEN\n\t\t\tBANK SELECT 3\t' canhoes da lava atiram no jogador (banco 3)\n\t\t\tGOSUB lava_cannons\n\t\t\tBANK SELECT 0\n\t\tEND IF")

# ---------- 8. cerimonia no loop + transicao ----------
rep("game_loop:\n\tWAIT\n",
    "game_loop:\n\tWAIT\n\n\t' v0.19: cerimonia pos-boss (estrobo + explosoes repetidas no lugar\n\t' dele); ao fim, sai do loop p/ a sequencia de transicao de fase\n\tIF bsc > 0 THEN\n\t\tbsc = bsc - 1\n\t\tIF (FRAME AND 4) = 0 THEN VPOKE $3F00,$30 ELSE VPOKE $3F00,$0F\n\t\tIF (bsc AND 15) = 0 THEN\n\t\t\tmpt = 12\n\t\t\tmpx = 96 + RANDOM(48)\n\t\t\tmpy = 40 + RANDOM(40)\n\t\t\t#pop = 12\n\t\tEND IF\n\t\tIF bsc = 0 THEN GOTO fase1_clear\n\tEND IF\n", 1)
rep("\tGOTO game_loop\n\n\t'\n\t' A NAVE EXPLODIU\n\t'\nplayer_dies:",
    "\tGOTO game_loop\n\n\t'\n\t' v0.19: FASE 01 COMPLETA -> fade -> cartao FASE 02 -> begin_stage\n\t'\nfase1_clear:\n\tVPOKE $3F00,$0F\t\t' fim do estrobo\n\tBANK SELECT 1\n\tGOSUB fase_completa\n\tGOSUB fase2_card\n\tBANK SELECT 0\n\tfase = 2\n\tGOTO begin_stage\n\n\t'\n\t' A NAVE EXPLODIU\n\t'\nplayer_dies:")

# ---------- boss_kill: arma a cerimonia ----------
rep("\tGOSUB stars_fill\t\t' devolve as estrelas ao cenario\n\te = 50\t\t\t\t' +5000 pontos (chefe da fase 1!)",
    "\tGOSUB stars_fill\t\t' devolve as estrelas ao cenario\n\tbsc = 70\t\t\t' v0.19: cerimonia (estrobo+estouros) p/ transicao\n\te = 50\t\t\t\t' +5000 pontos (chefe da fase 1!)")

open(BAS, 'w', encoding='utf-8').write(src)
print('aplica_v019 parte 1 (banco 0) OK')

# ---------- 9. procs no BANK 1 (apos go_draw END) ----------
src = open(BAS, encoding='utf-8').read()
anchor = "\t\tVPOKE $3F07,e\n\t\tFOR q = 0 TO 3\n\t\t\tWAIT\n\t\tNEXT q\n\tNEXT r\n\tEND\n"
assert src.count(anchor) == 1
procs_b1 = anchor + """
\t'
\t' v0.19: telas de transicao de fase (mesmo estilo do stage_card)
\t'
fase_completa: PROCEDURE
fc_release:
\tWAIT
\tIF CONT1.KEY = 11 THEN GOTO fc_release
\tIF CONT1.BUTTON THEN GOTO fc_release
\tSCREEN DISABLE
\tCLS
\tSCROLL 0,0
\tPRINT AT 392,"FASE 01 COMPLETA"
\tPRINT AT 455,"PONTUACAO: ",<1>s0,<1>s1,<1>s2,<1>s3,<1>s4
\tPRINT AT 487,"VIDAS: ",<1>li
\tVPOKE $3F01,$0F
\tVPOKE $3F02,$0F
\tVPOKE $3F03,$0F
\tWAIT
\tSCREEN ENABLE
\tRESTORE fade_tbl
\tFOR r = 0 TO 6
\t\tREAD BYTE e
\t\tREAD BYTE e
\t\tVPOKE $3F03,e
\t\tFOR q = 0 TO 3
\t\t\tWAIT
\t\t\tIF CONT1.KEY = 11 THEN GOTO fc_fim
\t\t\tIF CONT1.BUTTON THEN GOTO fc_fim
\t\tNEXT q
\tNEXT r
\tFOR q = 0 TO 209
\t\tWAIT
\t\tIF CONT1.KEY = 11 THEN GOTO fc_fim
\t\tIF CONT1.BUTTON THEN GOTO fc_fim
\tNEXT q
\tRESTORE fade_tbl_out
\tFOR r = 0 TO 6
\t\tREAD BYTE e
\t\tREAD BYTE e
\t\tVPOKE $3F03,e
\t\tFOR q = 0 TO 3
\t\t\tWAIT
\t\tNEXT q
\tNEXT r
fc_fim:
\tSCREEN DISABLE
\tWAIT
\tEND

fase2_card: PROCEDURE
f2_release:
\tWAIT
\tIF CONT1.KEY = 11 THEN GOTO f2_release
\tIF CONT1.BUTTON THEN GOTO f2_release
\tSCREEN DISABLE
\tCLS
\tSCROLL 0,0
\tPRINT AT 460,"FASE 02"
\tPRINT AT 520,"PLANETA DE LAVA"
\tVPOKE $3F01,$0F
\tVPOKE $3F02,$0F
\tVPOKE $3F03,$0F
\tWAIT
\tSCREEN ENABLE
\tRESTORE fade_tbl
\tFOR r = 0 TO 6
\t\tREAD BYTE e
\t\tREAD BYTE e
\t\tVPOKE $3F03,e
\t\tFOR q = 0 TO 3
\t\t\tWAIT
\t\t\tIF CONT1.KEY = 11 THEN GOTO f2_fim
\t\t\tIF CONT1.BUTTON THEN GOTO f2_fim
\t\tNEXT q
\tNEXT r
\tFOR q = 0 TO 239
\t\tWAIT
\t\tIF CONT1.KEY = 11 THEN GOTO f2_fim
\t\tIF CONT1.BUTTON THEN GOTO f2_fim
\tNEXT q
\tRESTORE fade_tbl_out
\tFOR r = 0 TO 6
\t\tREAD BYTE e
\t\tREAD BYTE e
\t\tVPOKE $3F03,e
\t\tFOR q = 0 TO 3
\t\t\tWAIT
\t\tNEXT q
\tNEXT r
f2_fim:
\tSCREEN DISABLE
\tWAIT
\tEND
"""
src = src.replace(anchor, procs_b1, 1)

# ---------- 10. BANK 3 ----------
layout = (HERE / 'lava_layout.bas.inc').read_text(encoding='utf-8')
bank2_anchor = "BANK 2\t' v0.15: trilhas (~2.9KB): player do NMI rele music_bank a cada nota"
assert src.count(bank2_anchor) == 1
bank3 = """BANK 3\t' v0.19: FASE 2 - PLANETA DE LAVA (setup, terreno, canhoes)

lava_wr: PROCEDURE\t\t' escreve 960 tiles a partir do READ em #bk (base NT)
\tFOR r = 0 TO 29
\t\tFOR i = 0 TO 31
\t\t\tREAD BYTE e
\t\t\tVPOKE #bk, e
\t\t\t#bk = #bk + 1
\t\tNEXT i
\tNEXT r
\tEND

lava_setup: PROCEDURE
\tPALETTE LOAD lava_palette
\tPOKE $1C,$40\t\t' CHR-RAM pagina 2 (tiles + sprites da lava)
\t' Detecta o espelhamento da ROM em tempo de execucao: escreve um
\t' sentinela na $2400 e le a $2000 — se vier o mesmo valor, $2400 e'
\t' ESPELHO da $2000 (fceumm / hardware H-mirror) e a vizinha vertical
\t' real e' a $2800 (mirb=2); senao, a vizinha e' a $2400 (mirb=1).
\tmirb = 2
\tVPOKE $2400,$AA
\t#tw = VPEEK($2000)\t' 1a leitura = lixo do buffer (dummy)
\t#tw = VPEEK($2000)\t' 2a = dado de verdade
\tIF #tw = $AA THEN
\t\tmirb = 2
\tELSE
\t\tmirb = 1
\tEND IF
\t' Anti-espelho (mesma filosofia das estrelas na v0.10): em mirb=2 a
\t' escrita na $2400 e' destruida pela da $2000 — por isso ela vem
\t' PRIMEIRO; a $2000 (metade A) sobrescreve o espelho. B vai p/ $2800.
\t' Em mirb=1: A->$2000 e B->$2400 (a $2800 NAO e' escrita — e' espelho).
\tIF mirb = 2 THEN
\t\tRESTORE lava_map_b
\t\t#bk = $2400
\t\tGOSUB lava_wr
\t\tRESTORE lava_map_a
\t\t#bk = $2000
\t\tGOSUB lava_wr
\t\tRESTORE lava_map_b
\t\t#bk = $2800
\t\tGOSUB lava_wr
\tELSE
\t\tRESTORE lava_map_a
\t\t#bk = $2000
\t\tGOSUB lava_wr
\t\tRESTORE lava_map_b
\t\t#bk = $2400
\t\tGOSUB lava_wr
\tEND IF
\t' Canhoes: le (col, meta-linha) -> cooldown inicial escalonado
\tRESTORE lava_can
\tREAD BYTE e
\tFOR i = 0 TO 4
\t\tREAD BYTE e
\t\tcnx(i) = e * 16 + 8
\t\tREAD BYTE e
\t\tcny(i) = e
\t\tcnc(i) = 40 + i * 26
\tNEXT i
\tEND

lava_cannons: PROCEDURE\t' canhoes BG: miram e atiram no jogador
\tFOR i = 0 TO 4
\t\tIF cnc(i) > 0 THEN cnc(i) = cnc(i) - 1
\t\tph = 0
\t\tIF ntb <> 0 THEN ph = 240
\t\t#tw = cny(i)\t\t' meta-linha -> pixel (0..464)
\t\t#tw = #tw * 16
\t\t#tw = #tw + 480
\t\t#tw = #tw - ph\t' janela: metade atual (0/240) + scroll fino
\t\t#tw = #tw - scroll_y
\t\tWHILE #tw >= 480
\t\t\t#tw = #tw - 480
\t\tWEND
\t\tIF #tw < 240 THEN\t\t' visivel na tela (0-239)
\t\t\tIF #tw >= 24 THEN\t' e dentro da zona de engajamento
\t\t\t\tIF #tw < 190 THEN
\t\t\t\t\tIF cnc(i) = 0 THEN
\t\t\t\t\t\tcnc(i) = 110 + RANDOM(50)
\t\t\t\t\t\tsy = #tw
\t\t\t\t\t\t#tbx = cnx(i)
\t\t\t\t\t\t#tby = sy + 8
\t\t\t\t\t\t#adx = px + 8
\t\t\t\t\t\t#adx = #adx - #tbx
\t\t\t\t\t\t#ady = py + 8
\t\t\t\t\t\t#ady = #ady - #tby
\t\t\t\t\t\tGOSUB aim_8dir\t' 8 direcoes, velocidade por wdif
\t\t\t\t\t\tebs = 0\t\t' dono "outros" (nao entra na cota small)
\t\t\t\t\t\tGOSUB eb_spawn
\t\t\t\t\tEND IF
\t\t\t\tEND IF
\t\t\tEND IF
\t\tEND IF
\tNEXT i
\tEND

""" + layout + "\n" + bank2_anchor
src = src.replace(bank2_anchor, bank3, 1)

# ---------- 11. CHRROM 2 no fim ----------
chrr = (HERE / 'lava_chr2.bas.inc').read_text(encoding='utf-8')
src = src.rstrip('\n') + '\n\n' + chrr + '\n'

open(BAS, 'w', encoding='utf-8').write(src)
print('aplica_v019 partes 2-4 (bank1/bank3/chrrom2) OK')
