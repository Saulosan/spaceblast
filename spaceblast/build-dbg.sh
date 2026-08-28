#!/bin/sh
# build-dbg.sh — compila a ROM de DIAGNOSTICO (ou selftest) do bug das estrelas.
# Uso: ./build-dbg.sh [selftest]
set -e
TAG="dbg"
if [ "$1" = "selftest" ]; then TAG="dbg-selftest"; fi
python3 faz_dbg.py $1
cp -n ../cvbasic-repo/cvbasic_nes_prologue.asm ../cvbasic-repo/cvbasic_nes_epilogue.asm . 2>/dev/null || true
../cvbasic-repo/cvbasic --nes space-blast-dbg.bas space-blast-dbg.asm
# mesmos 3 patches do build.sh oficial (video desligado no boot, $3F00 preto, PPUSIZE $90)
sed -i 's/LDA #\$1e\t; Color normal, Sprites visible, Background visible, No clipping, Color./LDA #$00\t; v0.16: boot sem flash cinza (video so liga no SCREEN ENABLE)/' space-blast-dbg.asm
sed -i '0,/\tJSR copy_chrram/s//\tLDA #$3F\n\tSTA PPUADDR\n\tLDA #$00\n\tSTA PPUADDR\n\tLDA #$0F\n\tSTA PPUDATA\n\tJSR copy_chrram/' space-blast-dbg.asm
sed -i 's/^PPUSIZE:\tEQU \$40$/PPUSIZE:\tEQU $90\t; v0.20 burst stream/' space-blast-dbg.asm
../gasm80-repo/gasm80 space-blast-dbg.asm -o space-blast-$TAG.nes
echo "OK: space-blast-$TAG.nes"
