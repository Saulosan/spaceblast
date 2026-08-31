# Space Blast v0.29 candidate — validação

Data da validação: 2026-08-28.

## Causa identificada

O `PPUSIZE=$90` permitia que um único NMI tentasse drenar 48 escritas
`VPOKE` individuais. Esse lote excede o tempo de VBlank disponível quando o
jogo está desenhando a cena. No caminho de morte do boss, `stars_fill` enfileira
48 escritas em cada uma das três nametables; no Mesen, as primeiras escritas
anômalas apareceram no frame 531, depois de 38 escritas válidas. O PPU passou a
receber bytes do comando como endereços de CHR-RAM (`$0002`, `$1FE8`, `$000A`).

O mesmo limite aparecia no game over do player: `PALETTE LOAD` e as 40 escritas
de atributos eram enfileirados juntos. O lote era drenado parcialmente e o
restante ocorria com o PPU fora da janela segura, produzindo oito escritas de
CHR-RAM no teste de três mortes.

## Correção mínima aplicada

A ROM global continua usando `PPUSIZE=$90`, preservando o throughput da v0.28
nas rotinas normais de gameplay, lava e água. Foram alterados somente os lotes
relacionados às cenas de morte:

- `stars_fill`: `WAIT` após `sk=31` em cada loop; cada nametable é drenada em
  lotes de 32 + 16 escritas.
- Game over: `WAIT` entre a carga da paleta e os atributos, e `WAIT` após
  `i=31`; os 40 atributos ficam em lotes de 32 + 8.

Não foram alterados inimigos, arte, controles, balanceamento, fluxo de fases,
sons ou a ROM oficial v0.28.

## Testes executados

- Build independente com CVBasic + GASM80: ROM iNES de 524.304 bytes,
  mapper 30, 32 bancos PRG e CHR-RAM.
- `nes-test/test_v028_baseline.py` contra a candidata: **V0.28 BASELINE OK**.
  Passou boot/título, gameplay, fases 1–5, cenários espacial/lava/água,
  boss, ending e retorno a uma partida nova. As quatro telas do ending
  permaneceram estáveis em `226, 286, 466, 286` frames.
- Probe Mesen do boss: tiro final no frame 521, morte no frame 522;
  hash CHR-RAM de referência `616a346f`, após a cerimônia `616a346f`,
  diferenças `0`.
- Probe Mesen da morte natural do player: flash entre os frames 866 e 906,
  `CHR_WRITES=0`.
- Probe Mesen de três mortes até game over: chegou a `LI=00` no frame 2450;
  1.141 escritas PPU da entrada do game over foram verificadas, com
  `bad_chr_writes=0`.

## Arquivos

- `space-blast-v029.nes` — ROM candidata para teste.
- `space-blast-v029.bas` — fonte candidata, com somente os lotes limitados.
- `space-blast-v029.asm` — assembly correspondente ao build.

Checksums:

| Arquivo | MD5 | SHA-256 |
|---|---|---|
| ROM oficial `space-blast.nes` (v0.28) | `b22ac571b09857c03b04016c692f6502` | `c464d8db98fb2ec4e3f6b8270ebb98458e86095bba92ee9252dc9972d2cfaee5` |
| ROM candidata `space-blast-v029.nes` | `d56601e0eac8dd51f78f08daa921d141` | `d8ea1c446cb153faaf44e905fa9197f68ef33dd7c17e2d97b8c626466369f1ce` |
