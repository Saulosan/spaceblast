#!/bin/sh
# build-dbg.sh — compila a ROM de DIAGNOSTICO (ou selftest) do bug das estrelas.
# Uso: sh build-dbg.sh [selftest]
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
MODE=${1:-}
TAG=dbg
[ "$MODE" = selftest ] && TAG=dbg-selftest

absolute_path() {
    case "$1" in
        /*) printf '%s\n' "$1" ;;
        *) printf '%s/%s\n' "$(CDPATH= cd -- "$(dirname -- "$1")" && pwd)" "$(basename -- "$1")" ;;
    esac
}

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

BUILD_TMP=$(mktemp -d "${TMPDIR:-/tmp}/spaceblast-dbg.XXXXXX")
trap 'rm -rf "$BUILD_TMP"' 0 1 2 3 15
cp "$CVBASIC_PATH" "$BUILD_TMP/cvbasic"
cp "$GASM80_PATH" "$BUILD_TMP/gasm80"
chmod +x "$BUILD_TMP/cvbasic" "$BUILD_TMP/gasm80"

cd "$SCRIPT_DIR"
if [ "$MODE" = selftest ]; then
    python3 faz_dbg.py selftest
else
    python3 faz_dbg.py
fi
CVBASIC_DIR=$(dirname -- "$CVBASIC_PATH")
if [ ! -f cvbasic_nes_prologue.asm ] && [ -f "$CVBASIC_DIR/cvbasic_nes_prologue.asm" ]; then
    cp -f "$CVBASIC_DIR/cvbasic_nes_prologue.asm" .
fi
if [ ! -f cvbasic_nes_epilogue.asm ] && [ -f "$CVBASIC_DIR/cvbasic_nes_epilogue.asm" ]; then
    cp -f "$CVBASIC_DIR/cvbasic_nes_epilogue.asm" .
fi
PATH="$BUILD_TMP:$PATH" cvbasic --nes space-blast-dbg.bas space-blast-dbg.asm
sed -i 's/space-blast-dbg\.asm $/space-blast-dbg.asm/' space-blast-dbg.asm
sed -i 's/^\t; Created: .*/\t; Created: reproducible build/' space-blast-dbg.asm
# mesmos 3 patches do build.sh oficial (video desligado no boot, $3F00 preto, PPUSIZE $90)
sed -i 's/LDA #\$1e\t; Color normal, Sprites visible, Background visible, No clipping, Color./LDA #$00\t; v0.16: boot sem flash cinza (video so liga no SCREEN ENABLE)/' space-blast-dbg.asm
sed -i '0,/\tJSR copy_chrram/s//\tLDA #$3F\n\tSTA PPUADDR\n\tLDA #$00\n\tSTA PPUADDR\n\tLDA #$0F\n\tSTA PPUDATA\n\tJSR copy_chrram/' space-blast-dbg.asm
sed -i 's/^PPUSIZE:\tEQU \$40$/PPUSIZE:\tEQU $90\t; v0.20 burst stream/' space-blast-dbg.asm
PATH="$BUILD_TMP:$PATH" gasm80 space-blast-dbg.asm -o space-blast-$TAG.nes
echo "OK: space-blast-$TAG.nes"
