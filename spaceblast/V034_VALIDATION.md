# Space Blast v0.34 — texto fixo, paginado e sem scroll

## Artefato final

- ROM no repositório: `space-blast-v034.nes`
- Cópia para teste: `/home/user/Space-Blast-v0.34-final.nes`
- Tamanho: `524304` bytes
- SHA-256: `9e1eeabb3922dfed729cc2c4b18c96fb0af155b3f805f7fe2f2aab49cb15c826`
- Mapper: 30, 32 bancos PRG, CHR-RAM
- Fonte: `space-blast-v034.bas`
- Assembly: `space-blast-v034.asm`
- Build: `./build-v034.sh`

Uma segunda execução do build produziu exatamente o mesmo SHA-256 da ROM.

## Alteração desta versão

O sistema de scroll de história e créditos foi removido. O conteúdo foi
mantido, mas agora é dividido em seis páginas fixas:

- três páginas para a história;
- três páginas para os créditos;
- texto centralizado entre as colunas 2 e 29, garantindo pelo menos 16 pixels
  de margem esquerda e direita;
- glifos de acento continuam separados, nas linhas acima das letras corretas;
- todas as escritas de uma página ocorrem com `SCREEN DISABLE`;
- cada página aparece com fade-in, permanece acesa por 300 frames
  (aproximadamente 5 segundos) e então recebe fade-out antes da próxima;
- os laços de 300 frames foram divididos em dois blocos de 150 para respeitar
  o contador de 8 bits do CVBasic.

Não há mais `scroll_draw_history_tail`, `scroll_draw_credits_tail` ou escrita
de nametable durante a apresentação desses textos. O `SCROLL 0,0` usado na
preparação apenas garante que uma tela fixa não herde a posição do scroll do
gameplay.

## Verificações visuais

No FCEUmm, as três páginas da história foram capturadas completas e em ordem:

1. introdução e ameaça de Gorf;
2. cerco da Terra e início da missão;
3. rota até Gorf e encerramento da mensagem.

As três páginas de créditos também foram capturadas completas. A faixa de
texto ficou dentro da moldura de 16 pixels e não apresentou truncamento,
nametable parcial ou sujeira na transição entre páginas. A sequência de fade
foi confirmada pelas cores intermediárias da paleta antes do branco final.

## Regressão de fases e SELECT

O ciclo de teste foi executado duas vezes:

`1 → 2 → 3 → 4 → 5 → 1 → 2 → 3 → 4 → 5 → 1`

Todas as fases chegaram ao cenário correto, com os bancos de CHR-RAM esperados.
As fases espaciais, lava e água permaneceram funcionais, sem reaparecimento das
sujeiras após as trocas com SELECT.

Os cartões das fases 03 e 04 foram capturados novamente. O til/agudo continua
separado e sobre a letra correspondente, e o cartão 04 continua em duas linhas.

## Fluxo completo no FCEUmm

- Boss da fase 05 derrotado no frame `1320`.
- História fixa observada em três páginas; cada página recebeu hold de 300
  frames.
- Créditos fixos observados nas páginas `3`, `4` e `5`, respectivamente nos
  frames `2063`, `2442` e `2821` da execução completa.
- `THE END?` apareceu no frame `3205` e ficou legível por `302` frames.
- Reset completo detectado no frame `3526`; splash no `3587`; título no `3816`.
- Após o reset, nova fase espacial iniciada no frame `4099`, com `FASE=1`,
  `LI=3` e campo espacial sem corrupção (`field bright=0`).
- START durante a história interrompeu a apresentação e retornou ao splash.

A compilação terminou normalmente usando `637` bytes de RAM de `1805`
disponíveis. Permanecem apenas os warnings conhecidos de seleção de bancos
reservados para CHRROM e da variável `#LD` não utilizada.
