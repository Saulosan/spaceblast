# Space Blast v0.33 — relatório histórico (superseded)

## Artefato

- ROM: `space-blast-v033.nes`
- Tamanho: `524304` bytes
- SHA-256: `461cbf4a9cb16b8e925b201f461419ad20182645393ab87ae7ba6b69c3894688`
- Build: `./build-v033.sh`

## Abordagem testada

A v0.33 trocou a escrita progressiva dos helpers da v0.32 por uma
pré-renderização de duas nametables, ocultando uma parte pela paleta durante o
scroll. O contador voltou a terminar em `#bk=460` e a varredura usada no
ambiente de teste não encontrou a escrita parcial da v0.32.

## Resultado do teste do usuário

O teste real invalidou essa abordagem: o scroll ficou truncado e fora do lugar,
o primeiro movimento voltou a apresentar bug e a sujeira reaparecia depois de
algumas trocas de fase com SELECT. Portanto, a v0.33 **não é uma solução final**
e não deve ser usada.

A implementação atual está na v0.34, que remove completamente o scroll de
história/créditos e usa texto fixo, paginado, com margem mínima de 16 pixels,
fade-in e hold de leitura.
