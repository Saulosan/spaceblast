#!/bin/sh
# build-v034.sh — compila a ROM final da apresentacao/textos v0.34.
# Mantem os patches de build reproduzivel de build.sh.
set -eu

# Resolve paths from this script, not from the caller's current directory.
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)

absolute_path() {
    case "$1" in
        /*) printf '%s\n' "$1" ;;
        *) printf '%s/%s\n' "$(CDPATH= cd -- "$(dirname -- "$1")" && pwd)" "$(basename -- "$1")" ;;
    esac
}

# The public repository contains these tools in sibling directories.  The
# environment overrides keep alternate local toolchains easy to use.
if [ -n "${CVBASIC_BIN:-}" ]; then
    CVBASIC_PATH=$(absolute_path "$CVBASIC_BIN")
elif [ -f "$SCRIPT_DIR/../cvbasic-repo/cvbasic" ]; then
    CVBASIC_PATH=$(absolute_path "$SCRIPT_DIR/../cvbasic-repo/cvbasic")
elif [ -f "$REPO_DIR/cvbasic-repo/cvbasic" ]; then
    CVBASIC_PATH=$(absolute_path "$REPO_DIR/cvbasic-repo/cvbasic")
else
    echo "cvbasic not found; set CVBASIC_BIN to its path" >&2
    exit 1
fi

if [ -n "${GASM80_BIN:-}" ]; then
    GASM80_PATH=$(absolute_path "$GASM80_BIN")
elif [ -f "$SCRIPT_DIR/../gasm80-repo/gasm80" ]; then
    GASM80_PATH=$(absolute_path "$SCRIPT_DIR/../gasm80-repo/gasm80")
elif [ -f "$REPO_DIR/gasm80-repo/gasm80" ]; then
    GASM80_PATH=$(absolute_path "$REPO_DIR/gasm80-repo/gasm80")
else
    echo "gasm80 not found; set GASM80_BIN to its path" >&2
    exit 1
fi

if [ ! -f "$CVBASIC_PATH" ] || [ ! -f "$GASM80_PATH" ]; then
    echo "configured build tools are not regular files" >&2
    exit 1
fi

# Some web checkouts preserve these binaries as regular (non-executable)
# files.  Run private copies so a build never changes tracked file modes.
BUILD_TMP=$(mktemp -d "${TMPDIR:-/tmp}/spaceblast-build.XXXXXX")
trap 'rm -rf "$BUILD_TMP"' 0 1 2 3 15
cp "$CVBASIC_PATH" "$BUILD_TMP/cvbasic"
cp "$GASM80_PATH" "$BUILD_TMP/gasm80"
chmod +x "$BUILD_TMP/cvbasic" "$BUILD_TMP/gasm80"

cd "$SCRIPT_DIR"

CVBASIC_DIR=$(dirname -- "$CVBASIC_PATH")
if [ -f "$CVBASIC_DIR/cvbasic_nes_prologue.asm" ]; then
    cp -f "$CVBASIC_DIR/cvbasic_nes_prologue.asm" .
fi
if [ -f "$CVBASIC_DIR/cvbasic_nes_epilogue.asm" ]; then
    cp -f "$CVBASIC_DIR/cvbasic_nes_epilogue.asm" .
fi

# Use stable command names in generated assembly; the actual binaries can be
# supplied from any supported path above.
PATH="$BUILD_TMP:$PATH" cvbasic --nes space-blast-v034.bas space-blast-v034.asm
# CVBasic leaves one space at the end of its command comment; normalize it
# so generated assembly passes whitespace checks and diffs stay reviewable.
sed -i 's/space-blast-v034\.asm $/space-blast-v034.asm/' space-blast-v034.asm
sed -i 's/^\t; Created: .*/\t; Created: reproducible build/' space-blast-v034.asm
# v0.16: prologue ligava o video ($2001=$1E) ANTES do main = flash cinza de
# ~17 frames no boot (medido no fceumm; existia desde a v0.14). Com a splash
# FALCON SOFT de fade preto isso ficava feio. Patch: mantem o video DESLIGADO
# no fim do prologue ($00); o primeiro SCREEN ENABLE do main liga de vez.
sed -i 's/LDA #\$1e\t; Color normal, Sprites visible, Background visible, No clipping, Color./LDA #$00\t; v0.16: boot sem flash cinza (video so liga no SCREEN ENABLE)/' space-blast-v034.asm
# v0.16 (complemento): a RAM de paleta do PPU acorda com lixo e o backdrop
# aparece ~15f durante a copia do CHR. $3F00=$0F ANTES da copia = boot preto.
sed -i '0,/\tJSR copy_chrram/s//\tLDA #$3F\n\tSTA PPUADDR\n\tLDA #$00\n\tSTA PPUADDR\n\tLDA #$0F\n\tSTA PPUDATA\n\tJSR copy_chrram/' space-blast-v034.asm
# v0.20: PPUBUF de 64B (21 writes/frame) estourava no burst do stream do
# lava e o WRTVRM dava JMP wait = frame de jogo perdido (fase 2 a 70-87%
# da velocidade real!). 144B = 48 writes/frame: cabe qualquer burst.
sed -i 's/^PPUSIZE:\tEQU \$40$/PPUSIZE:\tEQU $90\t; v0.20 burst stream/' space-blast-v034.asm
PATH="$BUILD_TMP:$PATH" gasm80 space-blast-v034.asm -o space-blast-v034.nes
