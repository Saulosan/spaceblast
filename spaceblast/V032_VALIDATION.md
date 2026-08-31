# Space Blast v0.32 — relatório histórico (superseded)

## Artefato

- ROM: `space-blast-v032.nes`
- Tamanho: `524304` bytes
- SHA-256: `590fbf2a660d5c7af1922d009dbdf1be8e6b65110fffa70aad6998ef23db4537`
- Mapper: 30, 32 bancos PRG, CHR-RAM
- Build: `./build-v032.sh`

## O que a v0.32 corrigiu

A v0.31 chamava `scroll_draw_history_tail` e
`scroll_draw_credits_tail` de dentro dos loops `FOR r` / `FOR q` do scroll.
Como essas rotinas reutilizavam os contadores ativos, o scroll ultrapassava o
limite e chegava a `#bk=536`. A v0.32 separou os contadores (`i`, `d`, `k`) e
passou a terminar em `#bk=460`.

## Problema transitório descoberto depois

A validação inicial da v0.32 amostrava estados estáveis e, por isso, registrou
incorretamente que não havia flicker. Uma varredura frame a frame no FCEUmm,
feita depois do teste visual, encontrou a segunda causa em `#bk=224`: as
rotinas `*_tail` ainda escreviam progressivamente na nametable enquanto a tela
estava visível. A luminosidade medida foi:

`9213 → 1997 → 3108 → 4289 → 5402 → 9213`

As capturas intermediárias continham linhas parcialmente escritas. Portanto,
a v0.32 corrige o contador, mas **não deve ser usada como solução final**.

A correção está em `V033_VALIDATION.md` e na ROM `space-blast-v033.nes`.
