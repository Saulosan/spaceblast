#!/bin/sh
set -e
cp -n ../cvbasic-repo/cvbasic_nes_prologue.asm ../cvbasic-repo/cvbasic_nes_epilogue.asm . 2>/dev/null || true
../cvbasic-repo/cvbasic --nes space-blast.bas space-blast.asm
# v0.16: prologue ligava o video ($2001=$1E) ANTES do main = flash cinza de
# ~17 frames no boot (medido no fceumm; existia desde a v0.14). Com a splash
# FALCON SOFT de fade preto isso ficava feio. Patch: mantem o video DESLIGADO
# no fim do prologue ($00); o primeiro SCREEN ENABLE do main liga de vez.
sed -i 's/LDA #\$1e\t; Color normal, Sprites visible, Background visible, No clipping, Color./LDA #$00\t; v0.16: boot sem flash cinza (video so liga no SCREEN ENABLE)/' space-blast.asm
# v0.16 (complemento): a RAM de paleta do PPU acorda com lixo e o backdrop
# aparece ~15f durante a copia do CHR. $3F00=$0F ANTES da copia = boot preto.
sed -i '0,/\tJSR copy_chrram/s//\tLDA #$3F\n\tSTA PPUADDR\n\tLDA #$00\n\tSTA PPUADDR\n\tLDA #$0F\n\tSTA PPUDATA\n\tJSR copy_chrram/' space-blast.asm
# v0.20: PPUBUF de 64B (21 writes/frame) estourava no burst do stream do
# lava e o WRTVRM dava JMP wait = frame de jogo perdido (fase 2 a 70-87%
# da velocidade real!). 144B = 48 writes/frame: cabe qualquer burst.
sed -i 's/^PPUSIZE:\tEQU \$40$/PPUSIZE:\tEQU $90\t; v0.20 burst stream/' space-blast.asm
../gasm80-repo/gasm80 space-blast.asm -o space-blast.nes
