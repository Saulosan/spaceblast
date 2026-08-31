# Space Blast v0.35 — texto paginado centralizado e com tempo ampliado

## Artefato final

- ROM no repositório: `space-blast-v035.nes`
- Cópia para teste: `/home/user/Space-Blast-v0.35-final.nes`
- Tamanho: `524304` bytes
- SHA-256: `79a51ada5c95cc004ea29939e2982d6a9acb2fb776684db47d320ea86694df94`
- Mapper: 30, 32 bancos PRG, CHR-RAM
- Fonte: `space-blast-v035.bas`
- Assembly: `space-blast-v035.asm`
- Build: `./build-v035.sh`
- Testes de entrada: `../nes-test/test_v035_input.py`

O build foi executado novamente e produziu o mesmo SHA-256 da ROM.

## Ajustes desta versão

1. As páginas foram recentralizadas verticalmente. A posição inicial da
   primeira linha é calculada conforme a quantidade de linhas de cada página,
   deixando o bloco de texto equilibrado entre as margens superior e inferior.
   Os acentos permanecem na linha acima da letra e dentro da área protegida.
   Nas capturas em escala 2x, os seis blocos tiveram margem horizontal mínima
   de 32 px e margem vertical mínima de 80 px, isto é, pelo menos 16 px e
   40 px respectivamente na resolução original de 256x240.
2. O tempo de leitura de cada página passou de 300 para 600 frames,
   aproximadamente 10 segundos. O hold é dividido em três blocos de 200 frames
   para respeitar os contadores de 8 bits do CVBasic.
3. O tempo de espera da tela de abertura antes da história passou de 300 para
   900 frames, aproximadamente 15 segundos — três vezes o tempo anterior.

O conteúdo, gameplay, controles, fases, inimigos, colisões, cartões, reset,
`THE END?` e cenários não foram alterados.

## Testes realizados no FCEUmm

- História capturada em três páginas, agora verticalmente centralizada.
- Créditos capturados em três páginas, também centralizados.
- Hold de 600 frames por página confirmado no fluxo completo.
- `#bo` da tela de abertura atingiu `900` antes da entrada da história,
  confirmando o novo atraso triplicado.
- Fade-in continuou funcionando com as etapas intermediárias de paleta.
- Teste específico de SELECT executado em duas voltas sem sujeira:

  `1 → 2 → 3 → 4 → 5 → 1 → 2 → 3 → 4 → 5 → 1`

  As vidas permaneceram em `3` após cada troca.
- Boss da fase 05, créditos, `THE END?`, reset e nova fase espacial após o
  reset foram verificados.
- Teste específico de START enviado na página 1 da história automática:
  página 1 alcançada no frame `1878`, reset detectado no frame seguinte,
  splash e título encontrados depois do reset.

## Fluxo completo

- Boss derrotado no frame `1320`.
- Páginas de créditos observadas nos frames `2063`, `2742` e `3421`.
- `THE END?` detectado no frame `4105`, legível por `302` frames.
- Reset completo no frame `4426`; splash no `4487`; título no `4716`.
- Nova fase espacial no frame `4999`, com `FASE=1`, `LI=3` e campo limpo.

A compilação terminou normalmente com `637` bytes de RAM usados de `1805`.
