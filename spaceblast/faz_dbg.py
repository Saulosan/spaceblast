#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""faz_dbg.py — gera space-blast-dbg.bas (ROM de DIAGNOSTICO do bug das estrelas).

CONTEXTO (pericia em cima do print do Saulo, 31/jul/2026):
- ceu do gameplay = NT cheia de tile $00 lido pela BG em $0000 (ppu_ctrl bit4=0);
- ceu do titulo/CLS = NT cheia de tile $20 lido de $0200;
- a anomalia (grade de pontinhos 1:1 com o print) foi REPRODUZIDA no emu
  escrevendo 08 em $0003 e 28 em $000B (tile $00) -> o bug e' ESCRITA de
  bytes fora do lugar na CHR-RAM pagina 0 (shadow $1C sempre e' curada).

O que a ROM faz:
1. Titulo (apos drenar, antes do SCREEN ENABLE) e GAME OVER (apos go_draw):
   le 16 bytes do tile $00 ($0000), 16 do tile $20 ($0200), 4 da NT $2000
   e a sombra $1C; mostra tudo em hex na tela (titulo linhas 1-5, GO 24-28).
2. Leitura da VRAM: NMI desligado, $2006/$2007 direto, dummy-read antes.
3. SELFT=1 injeta o par criminoso nos dois tiles ($0003/$000B/$0203/$020B)
   p/ validar exibicao + reproduzir o ceu gradeado 1:1 (comparacao A/B)."""

import sys, pathlib

SELFT = len(sys.argv) > 1 and sys.argv[1] == "selftest"
base = pathlib.Path(__file__).parent
src = (base / "space-blast.bas").read_text()

def troca(trecho_velho, trecho_novo):
    global src
    assert src.count(trecho_velho) == 1, f"ancora nao-unica/ausente: {trecho_velho[:60]!r}"
    src = src.replace(trecho_velho, trecho_novo)

# --- 1. DIM ---
troca("\tDIM fase,bsc,ph,sy,srq,wr,wrf,ring(32)",
      "\tDIM fase,bsc,ph,sy,srq,wr,wrf,ring(32)\n\tDIM diag(40),bkc,h,#db\t\t' v0.24-dbg: pericia do tile $00/$20 (bug das estrelas)")

# --- 2. callsite titulo ---
troca("\tWAIT\t\t\t' drena o buffer da PPU (escritas demais perdem!)\n\tSCREEN ENABLE",
      "\tWAIT\t\t\t' drena o buffer da PPU (escritas demais perdem!)\n"
      "\tBANK SELECT 1\t\t' v0.24-dbg: pericia dos tiles do ceu\n"
      "\tGOSUB diag_dump\n"
      "\tBANK SELECT 2\t\t' volta p/ o banco da trilha do titulo\n"
      "\tSCREEN ENABLE")

# --- 3. callsite game over ---
troca("\tGOSUB go_draw\n\tBANK SELECT 0",
      "\tGOSUB go_draw\n\tBANK SELECT 0\n"
      "\tBANK SELECT 1\t\t' v0.24-dbg: pericia dos tiles do ceu (game over)\n"
      "\tGOSUB diag_dump_go\n"
      "\tBANK SELECT 0")

# --- 4. blocos ASM de leitura ---
def le_vram(hi, lo, base_array):
    out = ["\tASM LDA #" + hi, "\tASM STA $2006",
           "\tASM LDA #" + lo, "\tASM STA $2006",
           "\tASM LDA $2007"]  # dummy
    for k in range(16):
        out.append("\tASM LDA $2007")
        out.append("\tASM STA array_DIAG+%d" % (base_array + k))
    return "\n".join(out)

leitura = []
leitura.append("\tASM LDA #$00")   # NMI off p/ ler VRAM sem fila intercalando
leitura.append("\tASM STA $2000")
leitura.append(le_vram("$00", "$00", 0))    # tile $00 (ceu do gameplay)
leitura.append(le_vram("$02", "$00", 16))   # tile $20 (ceu do titulo/CLS)
# 4 primeiros bytes da NT $2000
leitura.append("\tASM LDA #$20")
leitura.append("\tASM STA $2006")
leitura.append("\tASM LDA #$00")
leitura.append("\tASM STA $2006")
leitura.append("\tASM LDA $2007")           # dummy
for k in range(4):
    leitura.append("\tASM LDA $2007")
    leitura.append("\tASM STA array_DIAG+%d" % (32 + k))
leitura.append("\tASM LDA #$A8")            # re-arma NMI
leitura.append("\tASM STA $2000")
LEITURA = "\n".join(leitura)

def hex8(diagbase):
    return "\n".join(["\tFOR i = 0 TO 7",
           f"\t\th = diag({diagbase} + i)",
           "\t\te = h / 16",
           "\t\tIF e > 9 THEN e = e + 7",
           "\t\tVPOKE #tw + i * 3, 48 + e",
           "\t\te = h AND 15",
           "\t\tIF e > 9 THEN e = e + 7",
           "\t\tVPOKE #tw + i * 3 + 1, 48 + e",
           "\tNEXT i"])

selftest = ""
if SELFT:
    selftest = ("\t' --- SELFTEST (NAO VAI P/ PRODUCAO): injeta o par 08/28 ---\n"
                "\tFOR i = 0 TO 15\n"
                "\t\tVPOKE $0000 + i, 0\n"
                "\t\tVPOKE $0200 + i, 0\n"
                "\tNEXT i\n"
                "\tVPOKE $0003,8\n"
                "\tVPOKE $000B,$28\n"
                "\tVPOKE $0203,8\n"
                "\tVPOKE $020B,$28\n"
                "\tWAIT\n")

procs = f"""
' =====================================================================
' v0.24-dbg: PERICIA DO BUG DAS ESTRELAS (somente build de diagnostico)
diag_dump:\tPROCEDURE\t\t' titulo, linhas 1-5 (ceu livre acima da logo)
\t#db = $2022
\tGOSUB diag_core
\tEND

diag_dump_go:\tPROCEDURE\t' game over, linhas 24-28
\t#db = $2301
\tGOSUB diag_core
\tEND

diag_core:
{selftest}\tbkc = PEEK(28)\t\t' sombra CHR-RAM (NMI faz ORA CHRRAM_BANK/BANKSEL)
\tWAIT\t\t\t\t' drena a fila antes de ler a VRAM
{LEITURA}
\tVPOKE #db, 84\t\t' "T00:" (tile do ceu do gameplay)
\tVPOKE #db + 1, 48
\tVPOKE #db + 2, 48
\tVPOKE #db + 3, 58
\t#tw = #db + 5
{hex8(0)}
\t#tw = #db + 32 + 5
{hex8(8)}
\tWAIT
\tVPOKE #db + 64, 84\t' "T20:" (tile do ceu do titulo/CLS)
\tVPOKE #db + 65, 50
\tVPOKE #db + 66, 48
\tVPOKE #db + 67, 58
\t#tw = #db + 64 + 5
{hex8(16)}
\t#tw = #db + 96 + 5
{hex8(24)}
\tWAIT
\tVPOKE #db + 128, 66\t' "BK:"
\tVPOKE #db + 129, 75
\tVPOKE #db + 130, 58
\th = bkc
\te = h / 16
\tIF e > 9 THEN e = e + 7
\tVPOKE #db + 131, 48 + e
\te = h AND 15
\tIF e > 9 THEN e = e + 7
\tVPOKE #db + 132, 48 + e
\tVPOKE #db + 134, 78\t' "NT:"
\tVPOKE #db + 135, 84
\tVPOKE #db + 136, 58
\t#tw = #db + 137
\tFOR i = 0 TO 3
\t\th = diag(32 + i)
\t\te = h / 16
\t\tIF e > 9 THEN e = e + 7
\t\tVPOKE #tw + i * 3, 48 + e
\t\te = h AND 15
\t\tIF e > 9 THEN e = e + 7
\t\tVPOKE #tw + i * 3 + 1, 48 + e
\tNEXT i
\tWAIT
\tRETURN

"""

ancora = "\nBANK 3"
assert ancora in src
src = src.replace(ancora, procs + "\nBANK 3", 1)

out = base / "space-blast-dbg.bas"
out.write_text(src)
print("OK ->", out, "SELFT=", SELFT)
