# Space Blast — Port NES (CVBasic)

Port para **NES/Famicom** do jogo HTML5 **Space Blast** (antes "Caravan
Blast"; Saulo San — http://saulosan.com.br/caravanblast), escrito em
**CVBasic** v0.9.2 rodando em **UNROM 512 (mapper 30, 512 KB)**.

**ESTADO ATUAL: v0.28** (seção da v0.28 logo abaixo; histórico completo em HISTORICO.md)

## v0.28 — As 5 fases + fim de jogo (ordem do Saulo)

ROM `8ac873400a4d8c15b4ad4dd2c5fea1d3`. Todas as fases no mesmo esquema
aprovado (scroll estilo fase 1, mesmos inimigos da fase 1, miniboss +
mesmo boss em todas):

1. **A CAMINHO DO PLANETA DE FOGO** (espaço/estrelas)
2. **O PLANETA DE FOGO** (lava; nome corrigido de "planeta de lava")
3. **O CINTURÃO DE ASTERÓIDES** (espaço; acentos por glifo na linha
   acima da letra: til = tile 26, agudo = tile 27 da spritefont)
4. **O GERADOR DE ESCUDOS DE ATLANTIS** (tiles da lava + paleta água
   `$0C,$11,$02,$01` — azul profundo, contraste preservado)
5. **A BATALHA FINAL COM GORF** (espaço)

Vencendo a 05: telas de vitória (com agudos em GALÁXIA/PARABÉNS/ESTÁ) →
créditos completos (com til em VOLOTÃO) → "THE END?" → volta à fase 01
em partida nova. Cartão e "FASE 0X COMPLETA" genéricos (`<1>fase`).
SELECT cicla 1-5 (debug). Gate `fase = 1` do boss removido — o boss
eletrostático funciona em qualquer página (CHR 256-511 da página 2 é
cópia byte-idêntica da 0). `POKE $1C,$00` antes de cartões/game over
(após lava/água, senão o texto sairia da página 2).

**Saga do banco 0 (autópsia no asm):** as novidades estouraram os 97
bytes restantes do banco 0. Descoberta da arquitetura: banco 0 = 32 KB
(físico 30 na janela + 31 FIXO em `$C000+`, acessível de qualquer
janela sem wrapper); `BANK SELECT n` grava `2n−2` (1→0, 3→2). Chamada
aninhada **janela→janela** (`boss_kill`@b1 → `stars_fill/lava_setup`@b3)
trava a CPU (boss: morria e renascia sem `bsc`). Solução: `anim_idle`
foi para o banco 1 (mesmo padrão validado do `mb_frame/boss_frame`),
`stars_fill` ficou no banco 0, e o refill do mar no `boss_kill` foi
removido (desnecessário: o boss é o fim da fase).

Suite emu 13/13: título, ciclo SELECT 1-5 com `$1C` certo, scroll água,
boss fase 1 → fase 2, boss fase 2 (lava) → card 03 com acentos → fase 3,
ending (3 telas) → volta à fase 1 com 3 vidas.

## v0.27 — Ilhas pequenas na lava, scroll continua perfeito

ROM `65a15b2b3e51bd04a2cad0a03abbb395`. Pedido do Saulo: quebrar a
monotonia da fase 2 com **ilhas pequenas 2×2 (4 tiles de 8×8)** e
conferir se o scroll aguenta. Adicionadas 5 ilhotas nas linhas
4/10/16/20/26, usando só as 3 ilhas 2×2 do mapa original (v0.19):
**A** = tiles 108/109/110/111, **B** = 119/153/154/155 e
**C** = 149/150/151/152 — nas **mesmas posições das 3 nametables**, em
linhas/colunas pares (alinhadas à textura 2×2 do mar).

Provas no emu: (1) state dump do NT0: **exatamente 20 tiles ≠ mar**
(5 ilhas × 4), nas posições certas, **idênticos após 300 frames** (zero
escrita dinâmica); (2) as 3 páginas byte-a-byte iguais nas 5 ilhas;
(3) scroll a **599/600 frames** em movimento — pleno, igual à fase 1.
Render dos tiles confirmou: as ilhotas são pedras/cristais verde-azulados
(discretas como no PNG original do Saulo). Cadaver do anel continua
dormente; sem canhões/eventos. Aguardando veredito do Saulo
(Mesen/Everdrive) — se quiser mais densidade ou ilhotas mais vistosas,
iteramos na v0.28.

## v0.26 — Scroll da fase 2 = scroll da fase 1 (ordem do Saulo)

ROM `5dab7d5a2a47c512cb3dfc92a48fb22f`. O motor de anel/torus (v0.19–v0.24)
saiu de campo: o que sempre funcionou foi o esquema da fase 1 — **3
nametables idênticas com conteúdo estático + scroll byte**. `lava_setup`
agora só troca paleta/CHR (`$1C=$40`) e preenche as 3 páginas com o mar de
lava básico (tiles 96/97/98/99, a textura 2×2 do próprio desenho do Saulo).
Sem ilhas, sem canhões, sem eventos, sem `lava_tick` (chamada comentada;
cadáver do anel dormente no banco 3 para limpeza futura).

Medido no emu: fase 2 entra com `$1C=$40`, scroll anda **597/600 frames**
(mesma velocidade plena da fase 1), textura uniforme, inimigos/sprites
intactos. Suites 4/4 verdes. Próximos passos (com a base lisa): detalhes
do cenário e depois as 5 fases.


## v0.25 — Bug das estrelas MORTO: game over aperta o botão RESET (pedido do Saulo)

ROM `f25c88c6bf9861cde3007398041fa0f7`. O scroll da lava fica congelado
na v0.24 (retomamos depois — decisão do Saulo). Foco total no bug que só
acontecia **no Mesen, depois de passar pela tela de game over**: céu da
fase 01 e do título virando uma grade perfeita de pontinhos.

**A autópsia (no print do Saulo):** a grade é travada em células 8×8 (sua
captura era 4:3: 20×16px/célula, razão 1.25 exata); cada célula ganhou 1
glifo de 2 pontinhos (azul col. 2, cinza col. 4, linha 3), com as 48
estrelas reais intactas por cima. Fontes/HUD nunca quebravam porque são
sprites. O céu do gameplay é a nametable cheia de **tile `$00`** (e o do
título, de tile `$20`); a sombra do banco CHR (`$1C`) foi eliminada
(`falcon_splash` e `begin_stage` sempre restauram). Logo: os **bytes do
tile `$00`/`$20` da CHR-RAM página 0 foram violados** (`08` em `$xx03`,
`28` em `$xx0B`) por um escritor dinâmico em algum trecho depois do game
over — caminho esse que sai limpo no fceumm (por isso nunca reproduziu
aqui). **Prova de mecanismo:** injetar exatamente esses bytes no emulador
reproduz o print 1:1 (figura `nes-test/ab_limpo_vs_saulo_vs_selftest.png`).

**A cura (como o Saulo imaginou, literalmente):** como o reset do console
sempre resolve, o jogo passou a **apertar o próprio botão RESET** ao sair
do game over — `JMP ($FFFC)` → vetor → `START`.
Antes do salto ele faz o reset completo: zera PPU ($2000/$2001), APU
($4015,$4017), os 2KB de RAM num loop e a pilha — exatamente como um
botão de RESET de verdade. O prologue então regrava a CHR-RAM toda. O fluxo visual
continua idêntico (GAME OVER → splash Falcon → título), mas o tile
violado volta a zeros **para sempre** — sem lógica paliativa, sem caça ao
fantasma. Prova de ponta a ponta no fceumm: corrompi a CHR-RAM com os
bytes do bug (céu gradeado igual ao print) → morte → game over → START →
reset → **`LI:3`, `FASE:1`, tiles `$00` e `$20` zerados de fábrica**
(GIF `space-blast-v025.gif`). Suites 4/4 verdes.

Fica para a ciência (opcional): a ROM `space-blast-dbg.nes` já entregue
mostra em hex os bytes dos tiles `$00`/`$20` no título e no game over —
se um dia quisermos prender o escritor em flagrante, a foto dela diz em
que trecho do game over ele escreve.


## v0.24 — Torus de 31 slots: o scroll definitivo da lava

ROM `bf659ad1868f30d99598d78d74a01da8`. Saulo testou a v0.23 e viu que
as ilhas ainda trocavam "um pouco abaixo do meio" — certíssimo de novo:
a v0.23 tinha **dois erros novos** introduzidos ao matar os espelhos:

1. **Flip 8 frames cedo demais**: escrevíamos o slot do FUNDO enquanto
   ele ainda precisava exibir a linha velha saindo → uma "linha do
   futuro" de 8px no rodapé; ilhas eram mutiladas ao sair em vez de
   morrer limpas (fotografado: `nes-test/v024_rodape.png` vs o zoom da
   v0.23 com a faixa lisa/alien na base).
2. **`$2800` NÃO era morta coisa nenhuma!** O PPU troca para a
   nametable vertical quando o coarse-Y passa de 29 durante o
   fine-scroll — os últimos `fine` px da tela leem **`$2800` slot 0**.
   (Aliás: é exatamente POR ISSO que a fase 1 sempre foi perfeita: as
   3 páginas idênticas dela alimentam esse strip automaticamente.) Na
   v0.23 o strip ficou congelado desde o setup = faixa de lava morta
   pendurada no rodapé.

**Motor final (ainda mais simples)**:
- fase 7 da costura: flip do slot do **TOPO** com a linha-mundo
  seguinte (anel 60 decrementando junto do scroll, fase travada na 1ª
  costura). O conteúdo nasce **atomicamente** com o 1px que espia lá
  no alto — zero frames meio construídos; a linha velha morre limpa
  saindo pelo fundo;
- fase 6: `$2800` slot 0 recebe a linha `(topo+30) mod 60` = o "31º
  slot" do torus, completando o rodapé;
- 2 eventos de 32 writes/ciclo (folga no PPUBUF 48) — CPU devolvida
  ao jogo: sem os 64 writes mortos da v0.22.

**Provas**: NT `$2000` + `$2800` slot 0 **byte-a-byte** iguais ao
modelo Python do torus em **1400 frames** (168 costuras, todas no slot
do topo); strip do rodapé rolando contínuo em todas as fases de fine
scroll (zoom em `nes-test/v024_rodape.png`); velocidade fase 2 =
1340/1400 frames ≈ v0.22 (1324); fase 1 intacta (299/300); suítes
**4/4 verdes**.

## v0.23 — Scroll da lava CERTINHO como o da fase 1 (autópsia do anel)

ROM `cf7db4d6bc48cc554434fc85bef5d7cb`. O bug das \"ilhas que somem e
surgem do nada\" foi autopsiado do zero — com a pista de ouro do Saulo:
*"as ilhas são construídas bem no meio da tela, quando era pra ser fora
dela, lá no alto"*. Estava espetacularmente certo:

1. **A medição (v0.22 no emulador, 420 frames)**: de 70 linhas
   escritas, apenas 6 caíam no slot livre da costura; **64 caíram em
   slots VISÍVEIS** — posições 1 a 27, incluindo a 15 (exato MEIO da
   tela). Histograma no HISTORICO.md.
2. **A causa raiz — geometria invertida do anel**: o scroll do jogo é
   **byte** (0→239, guard `$FF→$EF`), e os NT bits do PPUCTRL saem
   SEMPRE de `scroll_y+1`=0 ⇒ a tela é um **TORUS** de 30 slots na
   $2000: todas as 30 linhas do anel estão visíveis o tempo todo, e
   `$2400/$2800` **nunca são lidas** por nenhum emu/hardware. O design
   480px da v0.19 (escrever numa "metade escondida") era impossível
   assim. Pior: `#ld` andava **+32** por linha enquanto o topo visível
   `T=scroll_y/8` anda **−32** — os dois se cruzavam 1 vez a cada 15
   costuras; no resto, a linha nova caía em tela, com sorteio de
   posição. Linha com ilha = ilha "surgindo"; linha de lava vazia sobre
   ilha = ilha "sumindo".
3. **O fix (motor-vida-nova)**: no torus só existe UM instante bom pra
   regravar um slot — quando ele é o do **FUNDO**, no frame da costura
   (`scroll_y AND 7 = 7`, restam 7px dele). O motor agora:
   - escreve o slot do fundo em **32 writes num único NMI** (cabe no
     PPUBUF 48 + HUD), ~8 frames antes da linha entrar pelo topo;
   - a linha-mundo **decrementa** junto com o scroll (anel 60: mapa B
     59→30, depois A 29→0, wrap 0→59) — antes incrementava;
   - a fase do anel trava na 1ª costura lendo o `scroll_y` atual
     (deriva zero, imune a stalls);
   - `#ld = $2000 + w*32` com carry de verdade em ASM (low=w<<5,
     high=w>>3|$20) — adeus bug-irmão do ASL 8-bit;
   - **lava_out1/lava_out2 extintos**: escrever $2400/$2800 era CPU
     jogada fora (ninguém renderiza aquilo com NT bits 0).
4. **Provas**:
   - NT $2000 **byte-a-byte** idêntico ao modelo Python do torus em
     **1200 frames** (149 costuras), com 1 frame de latência do flush
     contabilizado;
   - 100% das costuras caem na posição 29 (fundo/livre);
   - A/B visual: `nes-test/ab_v022_pop_vs_v023_scroll.png` (ilha
     inteira materializando no meio na v0.22 vs. nascendo no alto e
     descendo 1px/frame na v0.23);
   - velocidade fase 2 = **1388/1400** vs 1324/1400 da v0.22
     (mais rápida que antes: menos 64 writes mortos por linha);
     fase 1 intacta (299/300);
   - suítes **4/4 verdes** (v04_full, v08, v12, v13_boss2_v019).
5. **Cicatriz conhecida (inerente ao torus, não é bug)**: a linha
   escrita no fundo fica como "preview" de ≤7px no rodapé por ~8
   frames antes de sair e entrar pelo topo. É a física do torus de 30
   linhas — a alternativa seria scroll 480px real (segundo NT), que
   exigiria cirurgia no NMI compartilhado com a fase 1. Se incomodar,
   conversamos sobre uma v0.24 nesse caminho.

## v0.22 — Fim dos canhões DE VERDADE + anel perfeito

ROM `d31f2f0554007e6c44da29c006bf9a4f`. O "quadrado" foi extirpado
definitivamente e o scroll ficou liso-com-vidro:

1. **O canhão sobrevivia no DATA INLINE!** A grande pegadinha: o
   `lava_layout.bas.inc` (regenerado 3x com 0 canhões) **não era incluído
   por ninguém** — o layout original (com 5 canhões B1 = subtiles 100-103)
   vivia embutido no `space-blast.bas` desde a injeção da v0.19! Por isso
   o quadrado continuava no cenário. Autópsia: pattern RGB do B1 casado
   byte a byte com as posições do DATA inline; substituídos pelo A1 base.
   Prova: **zero tiles 100-103 em qualquer nametable** (antes: 5
   molduras quadradas por tela).
2. **"Ilhas somem/surgem do nada" = anel dessincronizado**: o streaming
   v0.19-0.20 calculava `r*32` **em 8 bits** (r>7 transborda, carry ao
   lixo) e o skip do read_pointer idem — só os slots 0-7 atualizavam; as
   linhas lidas vinham de endereços aleatórios. v0.22: leitura
   **sequencial com shadow 16-bit** (`#lp`), destino idem (`#ld/#ldw`),
   e a mesma linha replicada nas **3 páginas** ($2000/$2400/$2800 =
   universal p/ H/V/four-screen). Prova: 15 âncoras únicas de ilha na
   nametable avançando **+32B exatos** = janela circular perfeita.
3. Streaming em **6 eventos de 16 writes** por 8 px (triggers
   `AND 7` = 7/5, 4/2, 1/0): fase 2 ~ igual à fase 1 nas janelas
   ([398,400] × [326*,394,400,383,398,397]; *janela de warm-up pós-setup).
4. Armadilhas documentadas no código: `FOR TO >254` infinito; comment
   `'` em linha `ASM` quebra o gasm80; `#var` sem assigned vira lixo;
   e o layout inline duplicado (a "carta morta" do .inc).

Suítes: 4/4 verdes.

## v0.20 — Fase 2 = Fase 1 com cenário de lava (mesma velocidade!)

ROM `a8cbcb953ff46026f3604376eee90712`. Pedidos do Saulo, keep it simple:

- **Canhões de cenário removidos COMPLETAMENTE**: fora do mapa
  (regenerado), do init, da proc, do tick, dos DIMs. O tile B1 fica no
  CHR sem uso; C1 continua reservado.
- **Fase 2 agora é a fase 1 trocando só o cenário** (mesmas ondas,
  inimigos, velocidade, música). Ilhas e enfeites continuam espalhados
  pelo anel pra deixar bonito.
- **A CAUSA-RAIZ da lentidão, com prova**: não era o palette cycling (ele
  nem existia mais). Medição frame a frame: a fase 1 avança o scroll em
  299/300 frames; a fase 2 só em **210/300 (70%)**. Autópsia: o streaming
  do anel escrevia **64 writes de uma vez** no PPUBUF de 64 bytes
  (21 writes/frame) → `WRTVRM` estourava e caía no `JMP wait` → cada
  estouro = 1 frame de jogo perdido (a música, da NMI, seguia normal —
  por isso parecia "se arrastar"). Correções em duas camadas:
  1. **stream em quartos de linha**: 4 eventos de 16 writes espalhados
     no ciclo de 8 px (triggers `AND 7` = 7/5/3/1);
  2. **PPUBUF $40→$90** (144 B = 48 writes/frame; 3º patch do build.sh).
- **Prova de mesa: velocidade IDÊNTICA** — janelas de 600 frames:
  fase 1 = [598,598,598,596], fase 2 = [597,598,598,596] ✅
- Suítes: 4/4 verdes.

## v0.19.2 — SELECT troca de fase (debug) + fim do palette cycling

ROM `62922c249ae08fa711a491f1351b3b83`. Pedidos do Saulo:

1. **SELECT (controle 1) alterna de fase na hora** (`fase = 3 - fase` →
   `begin_stage`): ir pra fase 2 preserva score/vidas; voltar pra 1 vem
   como partida nova (mesmo gate `IF fase = 1` do fluxo real).
   A volta limpa as 3 nametables (`clear_nts` banco 1, 3072 tiles c/ dreno
   do PPUBUF a cada 16 writes) — o anel do lava deixava lixo em
   `$2000/$2400/$2800` que o `stars_fill` não cobre (só toca slots tile 0).
   Achado forense da autópsia: **`FOR i = 0 TO 1023` no CVBasic é laço
   infinito** — o contador é 8-bit, o limite trunca p/ 255, o `INC`
   embrulha 255→0 e o `BCS` sempre salta (boot travado em tela preta COM
   música, NMI viva!). Por isso a faxina vai em blocos seguros de `0..63`.
2. **Removido TODO o palette cycling da fase 2** (pulso `$16↔$17`): as
   rachaduras ficam fixas em `$16`. (Nota técnica: o pulso era 1 VPOKE
   a cada 32 frames ~ gratuito de CPU; se a lentidão no emulador dele
   continuar, a causa é outra — próxima investigação mede frame-time do
   `lava_tick`/streams.)

Suítes: 4/4 verdes (v13 ajustada pro boot mais longo do clear_nts).

## v0.19 — FASE 02: PLANETA DE LAVA

ROM `9a5e922854bb20548d442753158f4755`. A fase 2 inteira do spec do Saulo +
a autópsia de harness mais divertida do projeto.

**Fluxo de fim de fase (spec do Saulo, ponto a ponto):**
- Morte do boss → cerimônia: tela pisca várias vezes + chuva de explosões
  onde ele ficava (`bsc=70`).
- Fade p/ tela preta com `FASE 01 COMPLETA` / `PONTUACAO:` / `VIDAS:`
  (score e vidas **persistem** — bug real caçado: o reset de score/vidas
  agora é gated `IF fase = 1`, antes zerava na transição!).
- Outro fade → cartão `FASE 02` / `PLANETA DE LAVA` → a fase começa.
- Game over → START agora volta pra **splash da Falcon** (era jogado no
  meio da fase 1); contador de **ONDAS removido** do jogo todo.

**Arquitetura do lava (a parte gostosa):**
- Cenário = **anel de 60 meta-linhas (480 px)** nos mapas `lava_map_a/b`
  (960 bytes cada, banco 3), tileset de 61 padrões únicos (CHR banco 2),
  paleta única `$07,$16,$1C,$0C` (rachadura $16 pulsa p/ $17 2x/s).
- **Streaming por linha**: a cada 8 px de scroll, `lava_stream` escreve a
  linha nova do anel no slot do $2000 **e a linha recém-evictida da outra
  metade no $2800** (dual-write). Motivo forense: o fceumm atual emula
  mapper 30 com 4 páginas CIRAM reais (four-screen) apesar do header
  H-mirror — scroll vertical de 2 páginas diverge entre emuladores; o
  dual-write é idêntico em H/V/four-screen (no V-mirror o $2800 escreve
  primeiro e perde pro $2000 — harmless).
- **Sequestro do read_pointer**: as waves (banco 0) roubam o RESTORE no
  meio do anel; o loader do lava re-RESTOREia e pula `#bk` bytes com ASM.
- **Canhões** (tiles B1, quinteto espalhado pelo anel): background mesmo
  (0 sprites!), atiram em 8 direções mirando o jogador quando entram na
  janela [24,190) de tela; bala nasce na boca (verificado pixel a pixel).
- Inimigos da fase 1 reciclados p/ teste (decisão do Saulo); tile C1
  reservado p/ "canhão destruído" (destrutibilidade em aberto).

**A AUTÓPSIA DO HARNESS (3 "bugs de cor", nenhum no jogo):**
1. fceumm nightly (jul/26) passou a emitir **XRGB8888**; nosso decoder lia
   2 bpp → tudo azul-distorcido (telas cinza passavam ilesas!).
2. Corrigido o bpp, faltou o **B↔R swap** (`[:,:,:3]` em buffer
   B,G,R,X) → o vermelho-tijolo (208,32,32) aparecia azul (32,32,208).
   Prova bit-exact contra a paleta **asqrealc** compilada no core:
   $16=0xd02020, $1C=0x00749c, $0C=0x004060 — tudo batendo.
3. O "campo cinza-claro" restante = **flash de morte** (`PALETTE 0,$10` do
   death_loop): o piloto do harness não desvia e morreu no lava bem no
   frame capturado. Confirmação com build instrumentada do core
   (`PALRAM[0]` alternando 0F↔10, `PPU[1]=$18`, XDBuf=0).

**Suítes (4/4 verdes com o decoder corrigido):** v04_full, v08_ajustes,
v12_fechamento e v13_boss2 adaptada p/ v0.19 (30 checks: fases do boss,
cerimônia, COMPLETA, card, banco CHR 2, scroll rolando, score
persistido, roxinhos reciclados spawnando no lava).


## v0.18 — Game Over retocado + cartão de fase "FASE 01"

ROM `0e93d7d68ff2d1d729ee88ac168a8f4e`. Pedidos do Saulo, ponto a ponto:

- **"GAMEOVER" junto e centralizado**: os 8 tiles estilizados (214–221) agora
  contíguos em `$214C–$2153` (col 12–19 da linha 10).
- **Espaçamento 1 linha entre frases**: GAMEOVER l.10, PONTOS l.12,
  ONDA l.14 (era 13), APERTE START l.16 (era 14).
- **Fade-in por palette cycling** (mesma técnica/rampa da Falcon, 7 passos ×
  4 frames): `go_draw` no banco 1 escreve tudo com as cores em preto e acende
  `$3F03`+`$3F07` pela `fade_tbl`. Autópsia divertida: a 1ª versão escondia
  "OND" de "ONDA:" — a linha 14 cai nos quads BL → pal0, e só a pal1 era
  rampada; captura pixel-a-pixel flagrou (97 px faltando, depois 185 OK).
- **START no game over → retry direto**: não volta mais ao título; cai em
  `begin_game` → cartão → jogo (fluxo arcade).
- **Cartão de fase** (`stage_card`, banco 1): tela preta, "FASE 01" /
  "A CAMINHO DO PLANETA DE FOGO" centralizadas (col 12/linha 14 e col 2/
  linha 16), fade-in pela mesma rampa, espera de entrada p/ o START ser
  solto (anti-corte acidental), **sai com START (corte seco) ou sozinha
  após ~4 s (com fade-out)**. Aparece antes de TODA partida da fase 1
  (título → START → cartão; game over → START → cartão).
- **Erro de build que virou arquitetura**: o banco 0 estourou em 91 bytes
  (`TIMES -91`) — fade+cartão migraram p/ o banco 1 com a dança
  `BANK SELECT 1/GOSUB/BANK SELECT 0` (mesmo padrão dos procs de boss; o
  player do NMI relê o banco da música a cada nota, então a trilha do
  título segue tocando sob o cartão).
- **Suítes**: 4/4 verdes com patch p/ cortar o cartão (v08 29/29, v12 17/17,
  v13 OK, v04 OK). GIFs: `docs/space_blast_v18_cartao_fase.gif` +
  `docs/space_blast_v18_gameover_fade.gif`.

## v0.17 — "Fonte Saulo": spritefont em TODO texto + HUD do placar consertado

ROM `12a61c06b9bb188eed397981fdde88e6`. Gerador: `gera_fonte.py`
(fonte: `uploads/Sprite_font.png`, 128×48 = 96 células 8×8, 2 cores).

### A autópsia do HUD quebrado (medida → hipótese → prova)
1. **Medida**: captura fceumm do gameplay v0.16b → placar = 5 blocos
   brancos sólidos no canto superior direito; vidas = 1 glifo estranho.
2. **Hipótese derrubada**: "foi a reforma do título (v0.16)". Diff dos tiles
   v0.15↔v0.16b: fonte 32–95 e região dos dígitos **byte-idênticas**.
3. **Prova definitiva** (captura `/tmp` do gameplay **v0.15**): o placar já
   aparecia como 5 "caixinhas" vazadas e as vidas como uma "Ǝ" — **o bug é
   mais velho que o v0.16**; a reforma só mudou o formato do lixo exibido.
4. **Causa raiz**: o placar são sprites 8×16 com byte OAM `s*2+128`
   (128,130,...). No modo 8×16, byte **par** → padrões da tabela **$0000
   (lado BG!)**, tiles 128–147 = **território da logo do título** em todas
   as versões recentes. Os "dígitos" nunca existiram ali: o jogo lixiviava
   fragmentos da logo como se fossem números.

### A solução (uma só fonte para tudo — pedido do Saulo)
- **Fonte BG (patterns 32–95)**: spritefont instalada via `CHRROM PATTERN 32`
  (last-write-wins sobre a fonte default do CVBasic). Mapa: `0-9`←células
  16–25, `A-Z`←26–51, `.,;:!?,"-()[]*` etc. mapeados; `*` e `&` = faísca ✦,
  `< ^ > ~` = setas, `` ` `` = **Ç** (pensando no "ESPAÇO" da fase 2!).
  Pixels valor 3 (dois planos), idêntico à fonte de fábrica → **paletas
  intocadas**. Maiúsculas apenas (a folha não tem minúsculas).
- **Placar/vidas (HUD em sprites)**: novos pares 8×16 em **192–211**
  (tile par = dígito da folha, ímpar = vazio); código alterado de
  `+128` para `+192` (6 pontos: 5 dígitos + vidas). Bug morto na raiz.
- **"GAME OVER" estilizado**: os 8 tiles desenhados pelo Saulo (células
  80–87, blocos brancos vazados) instalados em 214–221 e escritos por
  VPOKE na tela final. "PONTOS: / ONDA: / APERTE START" na fonte nova.
- **Splash**: "apresenta" → **"APRESENTA"** (a folha só tem maiúsculas) —
  glifos 182–188 do CHRROM 1 trocados pelas versões da spritefont
  (descoberta forense: a linha `DATA BYTE 182,185,186,183,187,183,184,188,182`
  soletra a-p-r-e-s-e-n-t-a ⇒ s=187, n=184 — a 1ª tentativa saiu
  "APRENESTA" e a captura flagrou).
- **Reservados p/ futuro**: 224–229 = mini-labels (BONUS/1UP) + seta-sólida.

### Verificação
Bytes: 7/7 (espaço vazio, 'A' nos 2 planos, dígitos 192–211, GAMEOVER
214–221, splash maiúsculo, logo 69 tiles intacta, bullet 188 intacto).
Telas (fceumm): splash, título (pisca ok: 292 px aceso / 0 apagado),
gameplay com `00000`+vidas na fonte, game over completo.
Regressão: **v12 17/17, v13 (boss), v08 (miniboss/HUD), v04 full — todas OK.**
GIFs: `docs/space_blast_v17_fonte_saulo.gif` + `docs/space_blast_v17_gameover.gif`.

## v0.16b — Título: paletas corretas por quad 16×16 + logo sem estrelas

Correção em cima da v0.16. ROM `62f963db85cd889ec02af5137a32577b` (524.304 B).

- **Hardware**: paleta de BG no NES **não é por tile 8×8** — é por **bloco de
  16×16 px** (2×2 tiles), 2 bits cada dentro de bytes de atributo que cobrem
  32×32 px na ordem `TL,TR,BL,BR` (bits 0-1, 2-3, 4-5, 6-7).
- **Bug raiz**: o gerador v0.16 (`gera_title2.py`) empacotava os sub-quads na
  ordem errada (trocava TR↔BL). Evidência: `docs/title_attr_diag.png`.
- **Mapa de paletas do Saulo** (overlay sobre a arte, tudo 16×16-alinhado):
  `pal1` = SPACE (cinzas), `pal2` = BLAST (vermelhos), `pal3` = cometa +
  colunas laterais (zona de brilhos), `pal0` = estrelas do fundo.
  Censo por quad conferiu **zero colisões** (após remover os brilhos).
- **Logo sem estrelas**: `gera_title3.py` separa 65 componentes da folha em
  27 de arte (letras, cometa, poeira da cauda) e 38 de brilho (estrelas ficam
  SÓ como tiles do cenário, espalhadas pela malha `stars_fill` em toda a tela).
  Logo caiu de 92 para **69 tiles únicos** (patterns 96–164; 165–187 vazios).
- **Bug achado de brinde**: o bullet `•` do rodapé era gravado no pattern 188
  mas o código escrevia o tile **212** (vazio) — invisível desde a v0.16.
  Corrigido para `VPOKE $236C,188`.
- **"APERTE START"**: refixado `$23ED=$A8` medindo emulador: texto 100% branco,
  "RT" lum 255, zero px cinza.
- **Suítes**: v12 17/17 OK, v13 boss OK, v08 miniboss/HUD OK, v04 SUITE OK.
- GIF: `docs/space_blast_v16b_titulo_corrigido.gif`.

## v0.16 — Splash FALCON SOFT + acertos do título

Entregue em cima da v0.15 (mapper 30 intacto). ROM
`c97bb6f6164cd3087a2ffabe8a458b6c` (524.304 B). Resumo:

### 1. Splash FALCON SOFT no boot

- **Arte oficial montada** (`Falconsoft-montado.png`, 128×78; a folha
  `Falconsoft.png`, 128×48, vinha "desmontada" pra aproveitar tiles — a
  águia/asas/FALCON já estavam quase no lugar, SOFT estacionado em
  cascata nas laterais, escudo picado nos cantos; nossa montagem
  reversa bateu ~90% antes de chegar o PNG oficial).
- **CHRROM 1 própria** = CHRRAM página 1 (`POKE $1C,$20` → BANKSEL
  bits 5-6 do CHR-RAM; o NMI restaura `ORA CHRRAM_BANK` a cada frame):
  86 tiles únicos (patterns 96–181) + 7 glifos da fonte CVBasic
  (182–188) escrevendo "apresenta" em minúsculas.
- **Fade por palette cycling** nos entries `$3F02/$3F03`: 7 passos × 4
  frames (`0F,0F → 0F,00 → 00,00 → 00,10 → 10,10 → 10,20 → 10,30`).
  Skip com **qualquer botão** corte direto pro título; senão ~3,4 s e
  fade-out idêntico. Game over volta ao título **sem** splash.
- Zero bytes de RAM novos (591/1805 mantidos).

### 2. Título novo sem katakana + "APERTE START" todo branco

- Logo `title-space.png` regenerada por script (`gera_title2.py`):
  SPACE branco/cinza (pal1 `$10/$30`), cometa teal (pal3 `$1C/$10/$30`),
  BLAST vermelhos (pal2 `$06/$16/$30`). Paleta escolhida **por quad
  16×16 com zero colisões medidas**; 92 tiles únicos contíguos 96–187
  (bullet • do rodapé em 212 intacto).
- Bug antigo: letras caíam em quads do pal0 (idx3 = `$00` cinza escuro
  — o PRINT sempre usa idx3): `RT` e vizinhos cinzas. Atributos da
  faixa de texto corrigidos → tudo pal2 = branco.
- **Estrelas do fundo substituídas** pelas da folha nova (25 tiles de
  dots esparsos), mesma convenção de índices (teal→1 / branco→2 /
  cinza→3) = mesmo azulado; `nep_tab` regenerada (23 entradas).
- Rodapé passa a sair **branco** (pal3 virou teal do cometa).

### 3. Boot sem flash cinza

- Sintoma medido no fceumm: **17 frames** de tela cinza sólida no boot
  (existia desde a v0.14 = não regressão). Causas decompostas: prologue
  ligava o vídeo `$2001=$1E` antes do main + RAM de paleta do PPU
  acordando com lixo durante a cópia CHR (~15f).
- Dois patches textuais no `build.sh` sobre o `.asm` gerado: vídeo só
  liga no primeiro `SCREEN ENABLE` e `$3F00=$0F` antes do `copy_chrram`.
  Resultado medido: boot preto, sobrando só ~3f da detecção NTSC.

### 4. Validação

- Suítes `nes-test/` adaptadas (o fluxo agora é START p/ pular splash +
  START no título) e rodadas na ROM final: **v12 17/17, v13 boss,
  v08 miniboss/HUD, v04 full = TUDO OK**. Game over conferido na tela.
- Skip com botão genérico (A): título no frame 77. Skip durante o hold:
  título ~23 frames depois.
- GIFs em `docs/`: `space_blast_v16_splash_falcon.gif` (sequência
  completa) e `space_blast_v16_gameplay.gif` (estrelas novas).

## v0.15 — SPACE BLAST pra valer: rename do projeto + MAPPER 30

Duas entregues, zero mudança de comportamento (prova: build pós-rename
bit a bit igual ao build pré-rename; gameplay lógico idêntico ao v0.14).

### 1. Rename: projeto Caravan Blast → Space Blast

- Pasta `/home/user/spaceblast/`, fonte `space-blast.bas`, saída
  `space-blast.nes`; `build.sh`, `gen_addrs.py` e todas as suítes do
  `nes-test/` apontando pros caminhos novos.
- No código e nas docs só ficaram as referências factuais ao original
  (URL do Saulo + crédito "ex-Caravan Blast" na seção de arte).
- **Backup (política atual, pedido do Saulo 30/07)**: manter SEMPRE **1** zip
  no workspace — `/home/user/space_blast_backup_2026-07-30.zip`, regenerado
  a cada versão entregue (estado completo: código, ROM, docs, testes,
  toolchain, artes). Zips de versões antigas ficam nas cópias locais do
  Saulo (v0.14, v0.15, v0.16b…). Checksums históricos: bas `6c967961…`,
  ROM NROM `7b7a9c29…`.

### 2. Migração NROM → UNROM 512 (mapper 30) com `BANK ROM 512` nativo

Motivo: as fases 2–5 precisavam de teto. Mapper 30 = **512 KB de PRG em
32 bancos de 16 KB** (banco 0 = fixo e visível sempre; 13–15/29–31
reservados p/ CHRROM). O jogo NROM inteiro tinha ~28 KB — hoje:

| Banco | Conteúdo | Usado | Livre |
|---|---|---|---|
| 0 (fixo $C000) | runtime + boot + título + loop quente (ondas, inimigos, tiros, HUD, player) + procs quentes | 15.900 B | 478 B |
| 1 | `mb_frame`, `boss_frame`, `sky_clear`, `boss_write/erase/start/kill`, `mb_kill` | 7.710 B | 8.673 B |
| 2 | trilhas `mus_stage1` + `mus_title` | 4.362 B | 12.021 B |
| 3–28 | **vazios, esperando as fases 2–5** | 0 | ~416 KB |
| 29–31 | CHRROM (tiles; cópia automática p/ CHRRAM no boot, +15f) | — | — |

Regras respeitadas do CVBasic: `BANK ROM 512` na 1ª linha; `BANK n` sem
repetição e nunca 0; `BANK SELECT` **só no banco 0**; música com o banco
certo selecionado (o player grava o banco lendo `$BFFF` no PLAY;
`music_bank` = `$01` medido no emulador); `GOTO` pra fora de PROCEDURE é
proibido → flag `diek` (proc pede morte, o dono do loop executa o GOTO).

### 3. A novela da tela preta (a parte forense que o Saulo gosta)

Primeiro build mapper-30: lógica 100% OK (suítes de RAM verdes), mas a
tela saía **toda preta** — perfeita p/ artefato de "render desligado".
Medição dos espelhos de PPU na RAM: `ppu_ctrl=$A8`, `ppu_mask=$1E`
idênticos ao v0.14 → renderização LIGADA. Mínimo reproduzível também
preto; spike de ontem, normal. Diferença achada: o bloco de dados ficou
**fisicamente depois do marcador `BANK 1`** no source → paletas,
`oam_ring`, `nep_tab`, `logo_map`, `sintab` foram parar no banco 1,
invisíveis quando o banco ativo era outro → paleta lida como lixo
(preto), logo vazio. Fix: mover as tabelas p/ antes do `BANK 1`.
Revalidado: título com 3.316 px claros (antes: 0).

### 4. Provas de equivalência v0.14 ⟷ v0.15

- **Drops de frame em gameplay real: 0 em 1.200 f nos dois** (v0.13
  tinha 2,1%; v0.14: 0,47%).
- **RNG/lógica idênticos**: alinhando por game-frame, o `lfsr` (e todos
  os arrays de onda) é o mesmo nas duas builds; o deslocamento de fase
  detectado em probes de wall-frame (−15f) vem da cópia CHR→CHRRAM no
  boot (15 frames) — conteúdo igual, relógio diferente.
- **Suítes:** v12 (cota+laser+anel) 17/17, v13 (boss + `ppu_ctrl` após
  morte) OK, v08 (e4/shards/miniboss) OK, v04 full OK (placar 660, anel
  de tiros, morte/respawn, volta ao título). Único ajuste: tolerância do
  probe de pixels do HUD em v08 (30→80), inerentemente sensível a fase.
- **Áudio:** energia de música medida igual (~960k/10s nas duas);
  `CHRRAM_BANK` preservado nas trocas de banco do NMI.
- RAM: 591/1805 bytes (+1 do `diek`).

### 5. O que isso libera agora

26 bancos de 16 KB vazios (3–28) + CHRROM por fase sob demanda
(CHR-RAM 8 KB recarregável; `CHRRAM 0-3` disponível). Fase 2 (planeta de
lava, 1 tile + palette cycling) tem espaço sobrando; miniboss reutilizado
em todas as fases sem custo extra de sprite.

## v0.14 — laser nos 3 pontos do passeio + fim dos slowdowns

Dois pedidos do Saulo, os dois entregues:

1. **Miniboss atira o laser em 3 pontos do passeio** (antes só no centro):
   agora dispara também nos extremos esquerdo/direito do movimento
   (`mbx` = 16, 112 ou 200; detectado na borda de subida `mbx <> mbxo`
   com o laser livre `mlr = 0`). Suíte prova: os 3 pontos `{16,112,200}`
   disparam dentro de 1 passeio completo (371f), mais nenhum outro.

2. **"Slowdowns" investigados a fundo — tinham DUAS causas distintas**:

   a. **Dropout de sprites (limite de 8 por scanline)** — nas ondas 3+3,
      seis roxinhos alinhados somam 12 metades na mesma linha (+ tiros e
      a nave): a PPU descarta as excedentes e elas SUMIAM em definitivo.
      Solução clássica de shmup de NES: **rodízio de prioridade (anel
      OAM = "sprite flickering justo")**. Os 16 slots mais disputados
      (12 metades dos smalls + 4 shards) são distribuídos por um mapa
      `r16` que gira 1 posição por frame: todo mundo pisca um pouco,
      ninguém desaparece. Regra de ouro: **always-write** — todo membro
      escreve seu slot todo frame (vivo desenha, morto esconde), senão
      sobra fantasma. Medido: cada small visível em 23-28 de 32 frames;
      antes, 2 de 6 ficavam invisíveis para sempre.

   b. **CPU real esgotada** — medida nova (contador por loop `rr`, já
      que o `frame` do CVBasic anda por NMI e mascara estouros): a v0.13
      rodava a **0,979 loops/frame (~2,1% de frames perdidos)**, com
      picos de **10,6% nas ondas de Enemy4** (o loop de 8 inimigos com
      divisões `/16`=`JSR _div16` e `peek16` por acesso a array era o
      maior vilão medido). Solução, também clássica: **atualização em
      paridade (30 Hz) com passo dobrado** — mesma velocidade final:
      smalls 3/frame (y em cache `smyy`), Enemy4 4/frame, shards 2/frame
      (y em cache `shyc`); tiros inimigos mantêm o loop da v0.13 (já era
      dividido). Desenho continua por frame via cache, para o anel.
      Resultado medido em 60 s de gameplay real: **0,995 loops/frame,
      0,47% de drops** (Enemy4: 63→1). Janelas de contato/tiro a 30 Hz
      são seguras: a bala cruza a janela em 7+ frames (sem tunneling).

   RAM: 590/1805 bytes. Suítes: v12 (cota+laser+anel) 17/17, v13 (boss)
   OK, v08 (e4/shard/miniboss) OK, v04 (full) OK.

3. Armadilhas cobradas nesta versão (ver HISTORICO.md p/ detalhes):
   - OAM shadow: `+0=Y, +1=TILE, +2=ATTR, +3=X` (teste lia ATTR!).
   - Sentinel de wrap do byte só cobre entrada de -16px; shards entram a
     -64 e o y enrola para 192 (faixa visível!): esconder com o teste de
     16 bits `#shy < 4112`, como a v0.13 fazia.
   - `k` já era variável do `eb_spawn` (DIM duplo = label redefinido).

## v0.6 — SPACE BLAST: novo nome + nova tela de título

Tela de título refeita conforme mockup do autor (`exemplo de titulo.png`):

1. **Nova logo `title.png` (128×48)** convertida por
   `gera_logo_spaceblast.py`: "SPACE" em branco, "BLAST!" em ciano
   elétrico com sombra teal e brilhos. Paleta do NES: pal1 =
   `$0F,$1C,$3C,$30` (teal/ciano `$3C`=(160,232,255)/branco) — `$3C` é o
   mais próximo do ciano (0,228,255) do PNG na paleta real do fceumm.
2. **Layout**: logo nas linhas 6–11 (colunas 8–23, tiles PATTERN 96–127 e
   148–211); "APERTE START" branco puro (pal2 = `$0F,$30,$30,$30`)
   piscando na linha 22 (AT 714); rodapé **2026 • FALCON SOFT** em ciano
   uniforme (pal3 = `$0F,$1C,$3C,$3C`) na linha 27 (AT 871), com a bala
   "•" = tile 212 custom via `VPOKE $236C` (nametable 1!).
3. **Atributos (quads 16×16)** reescritos a cada entrada na título:
   `$23CA–CD=$50` e `$23D2–D5=$55` (logo→pal1), `$23EA–ED=$80,$A0,$A0,$40`
   (APERTE→pal2), `$23F1–F6` (rodapé→pal3). O `begin_game` agora **zera
   `$23C0–$23FF`** para as cores da título não vazarem para as estrelas
   do gameplay (a pal0 antiga tinha os mesmos azuis da pal1, então antes
   era invisível; com teal/ciano novos ficaria uma faixa colorida).
4. Game over mantém seu próprio bloco de atributos e volta à título com
   START — verificado em emulador (logo + cores corretas já no 1º frame).

## v0.7 — novo inimigo: METEORO (Enemy4)

Onda nova usando o `Enemy4.gif` do autor (32×32, 4 frames — nave roxa/ouro
com luz verde), conforme spec: cruza a tela **do alto até a base, lento,
sem atirar**; sempre **4 por onda**, spawn a cada **1,5s** (primeiro em
0,5s), cada um numa das **4 colunas fixas (x = 32/88/144/200)
embaralhadas sem repetição** (nunca colados). Morre com 1 tiro, vale
**300 pontos** (= medA do jogo original) e toca o som de explosão.
Rodízio de ondas agora é cíclico: **small → shard → meteoro**.

Técnica:
- **Tiles**: `gera_enemy4.py` corta o bbox (28×27), reduz para 16×16 e
  quantiza em 3 tons (corpo→1, asas→2, brilhos→3). Ocupam os padrões
  **físicos 392–407** (livres no CHR). Cada inimigo = 2 sprites 8×16
  (slots OAM 33–40). Paleta **pal0 (cinzas)** — cara de meteoro e zero
  conflito com tiros/explosões (troca trivial: attr do SPRITE).
- **ARMADILHA DO OAM (documentada)**: em modo sprite 8×16, o byte de tile
  do OAM precisa ser **ÍMPAR** — o bit0 escolhe a tabela de padrões
  (0 = `$0000` fundo, 1 = `$1000` sprites) e os 7 bits altos T usam o par
  de tiles (2T, 2T+1) da tabela. Ou seja: byte = `((fis-256)/2)*2+1`.
  Primeira versão usou bytes pares (136/138) e os meteoros renderizaram
  como dígitos da fonte! Por isso o codebook usa **137 + 4×frame** (e
  +2 na metade direita). Todos os sprites antigos (13, 113, 125, 133)
  já eram ímpares por sorte/construção.
- Velocidade: `10 + wdif` décimos-sexto de px/frame (~0,7 px/frame ≈
  7s de travessia — mais lento que shards/smalls).
- Testes (`nes-test/v07_meteoro.py`, **TUDO OK**): chegada do rodízio a
  wtipo=2, 4 spawns em colunas embaralhadas [32,88,144,200], intervalos
  exatos de 90 frames, descida lenta e uniforme, kill +300 pts + explosão,
  fim de onda e continuação do ciclo. Suíte de regressão completa: OK.

## v0.8 — ajustes do meteoro + fim dos wraps de tela

Pedidos do autor após testar a v0.7:

1. **HUD apagava quando o meteoro surgia — CAUSA RAIZ**: o placar e as
   vidas são **SPRITES nos slots OAM 34–39** (`update_score`/
   `update_lives`), e o meteoro da v0.7 usava os slots 33–40 — conflito
   direto! Meteoros movidos para **OAM 41–48** e o HUD nunca mais pisca.
2. **Sprite estático**: removida a animação de 4 frames (economia de
   **12 tiles CHR**, 192B); fica só o frame 0 (tiles fís. 392–395).
3. **Meteoro atira**: 1 tiro por inimigo, ~2,5s após o spawn, **mirado
   no jogador** (reusa `aim_8dir` + `eb_spawn` — tiros escalonados por
   conta do spawn de 1,5s). Continua morrendo com 1 tiro = 300 pts.
4. **Velocidade levemente variada** por slot: `base + RANDOM(5) - 2`
   (1/16 px/frame) — nunca voam todos iguaizinhos.
5. **Anti-wrap todos os lados**: ao entrar pelo alto (y < 1) shard,
   meteoro e small ficam **escondidos** — o byte de Y do OAM enrolava
   (y=-12 → 243) e o inimigo "nascia embaixo" (o "metade em cima,
   metade embaixo" do shard era exatamente isso: 2 shards da coluna
   escalonada apareciam ao mesmo tempo, um em cada ponta).
   **ARMADILHA**: yc/yb são 8-bit sem sinal — negativo enrola p/ 244 e o
   IF `yc<1` nunca dispara. A guarda correta compara o valor 16-bit:
   `#shy(c) < 4112` ((1+256)*16). Tiros inimigos já eram mortos antes do
   wrap de borda (código antigo).

Testes (`nes-test/v08_ajustes.py`, **TUDO OK**): shard escondido na
entrada (OAM y=$f0 enquanto y<1), 4 colunas, intervalos 90f, velocidades
distintas, HUD estável, tile 137 constante, exatamente 4 tiros mirados
(nenhum atira p/ longe), kill +300. Regressão completa: SUITE OK.

## v0.9 — estrelas com loop perfeito + ritmo mais desafiador

Pedidos do autor após testar a v0.8:

1. **Cenário "mudava as estrelas de lugar" — CAUSA RAIZ**: a
   `stars_fill` sorteava um layout NOVO a cada chamada (boot, título,
   begin_game). Comprovado em emulador: o wrap do scroll em si sempre
   foi perfeito (a vizinha vertical da `$2000` é espelho da mesma RAM
   neste espelhamento da ROM — diagnóstico descartou as hipóteses de
   nametable errada); quem rearranjava as estrelas era o **re-sorteio a
   cada título/partida**. Correção: o layout das 48 estrelas (malha
   harmônica) é gerado **uma única vez no boot** nos arrays `stt(48)`/
   `#stw(48)` (+144B RAM) e desenhado **byte a byte igual** nas
   nametables `$2000` **e** `$2400` (a escrita explícita nas 2 deixa o
   loop perfeito independente do modo de espelhamento; na prática a
   2ª escrita é no-op por ser a mesma RAM). Resultado medido: **0 pixels
   diferentes** após ciclo completo morrer 3× → game over → título →
   nova partida (`nes-test/v09_estrelas*.py`).
2. **Enemy4 mais rápido** (parou de chamar "meteoro" — a MOVIMENTAÇÃO é
   que era como a dos meteoros!): `e4v = 10+wdif` → **`14+wdif`**
   (1/16 px/frame; ≈0,94–1,19 px/frame com o jitter por slot). Na
   prática: atravessam a tela ~40% mais rápido. Comentários do código
   atualizados (chega de "meteoro").
3. **Intervalo entre ondas menor**: `wpausa = 70` → **30 frames**
   (também na primeira onda). ONDAS medidas em emulador: gaps de
   exatamente 30f entre uma onda limpa e a próxima.

Testes: `nes-test/v09_estrelas*.py` (loop/temporalidade/persistência do
layout — tudo 0 diffs), suíte `v08_ajustes.py` **TUDO OK** (velocidades
agora 13–17/16) e regressão `teste_v04_full.py` **SUITE OK**. GIF:
`docs/space_blast_v09_loop_estrelas.gif`.

## v0.10 — estrelas encerradas de vez + Enemy4 turbinado

Bug encontrado pelo autor na v0.9: "as estrelas estão sumindo, como se o
scroll tivesse um bloco com elas e um bloco sem elas". **Diagnóstico
definitivo** (probe ROM `nes-test/probe_nt.bas` + medição de pixels por
frame no fceumm): nesta ROM (byte6=0) **a nametable vizinha do scroll
vertical é a `$2800`** — a `$2400` é espelho da `$2000` aqui. A v0.9
preencheu a `$2400` (no-op) e deixou a `$2800` vazia: a faixa vazia
varria a tela (contagem de pixels de estrela caía de 72 p/ 3 por ciclo!).
**Correção à prova de emulador**: o layout único do boot agora é gravado
nas **três** nametables (`$2000`, `$2400`, `$2800`) — uma das escritas é
sempre no-op (mesma RAM), então o loop fica perfeito em qualquer
espelhamento. Recontagem: **71–73 pixels constantes no ciclo inteiro**.

Mudanças pedidas pelo autor:

1. **Tiro do Enemy4 reposicionado**: antes era um timer de ~2,5s pós-
   spawn (ele morria antes de atirar 90% das vezes). Agora dispara ao
   **cruzar a faixa topo-meio da tela (y 64–127)** — verificado: os 8
   disparam exatamente em y = 64.
2. **Onda com 8 Enemy4** (eram 4), entrada a cada **0,5s** (era 1,5s).
   Colunas das 4 posições em **2 permutações embaralhadas**; coluna nunca
   se repete em spawns seguidos (nunca colados). Arrays/OAM ampliados
   (sprites 41–56) e a checagem de fim de onda soma os 8.
3. **Colisão nave×inimigo DESTRÓI o inimigo** (dano = 1 tiro): small
   vira sucata +100 pts, shard +120 pts **soltando o anel de 8 tiros**
   como sempre, enemy4 +300 pts — todos com som/mini-explosão iguais ao
   kill por bala, e a nave explode (3 cenários testados no emulador).

Testes: suíte `nes-test/v08_ajustes.py` (atualizada p/ v0.10) **TUDO OK**,
regressão `teste_v04_full.py` **SUITE OK**. GIF:
`docs/space_blast_v10.gif`.

## v0.13 — o boss certo (spritesheet, não gêmeas!) + bug dos textos corrigido

Feedback do autor sobre a v0.12:

1. **"Não são 2 boss gêmeos — é um spritesheet de 2 frames!"** Reescrito:
   o boss agora é **UMA nave 96×64, NO ALTO da tela, 100% Background**.
   Como o cenário pôde ficar preto (autorizado), toda a arte foi para a
   tabela **$1000** com **flip da `ppu_ctrl`** (`$B8`) só durante a luta —
   sprites 8×16 escolhem a tabela pelo bit0 do byte OAM, então nada muda
   para nave/tiros/placar.
2. **Animação por pulso de paleta** (sugestão dele): a cor clara `$38`
   cicla `38/28/18/28` a cada 14 frames — as luzes da nave "respiram" como
   no frame 2 do spritesheet, custo = 1 VPOKE por passo.
3. **Balanço lateral clássico de chefe-de-BG**: `SCROLL` x fino ±16 px
   (±1 px a cada 2 frames); com o céu preto o wrap horizontal é invisível.
   Leques, saraivada, lasers e as caixas de colisão **acompanham o
   balanço** (com `#bo`: boff com sinal 16-bit).
4. **Bug dos textos explicado e corrigido**: CVBasic `PRINT` grava o
   código ASCII **diretamente como tile** — a fonte mora nos tiles 32–95
   do banco `$0000`, exatamente onde a arte do boss tinha sido colocada na
   v0.12 (e o tile 0 do `$1000` também virou arte: céu preto virou
   "grade 2.0"). Arte realocada; nametable em `$0000` **idêntica à v0.11**
   (título pixel-a-pixel igual; "GAME OVER" no meio da luta legível).
5. Duas novas **armadilhas do codegen** registradas no HISTÓRICO: byte
   var ≥128 sign-extende ao entrar em var 16-bit; e o wrap `-16` (240)
   somado em 16-bit vira `+240`.

Suites: `v13_boss2.py` (**22/22**), `v12_fechamento.py` (11/11),
regressões v08/v04 OK. GIF: `docs/space_blast_v13_boss.gif`.

## v0.12 — FECHAMENTO DA FASE 01: cota de tiros, laser do miniboss, BOSS!

Pedido do autor (últimas mudanças do dia, deixando a fase 01 quase completa):

1. **Cota de tiros do inimigo roxo**: máx. **3 tiros de small na tela**.
   Cada tiro nasce marcado (`ebt`) e um contador global (`nsm`) sobe/desce
   no spawn/despawn; o small que quiser atirar com a cota cheia espera e
   tenta de novo — "sempre que um tiro sumir, outro deles atira".
2. **Miniboss mais acima + LASER**: ele estaciona em **y=72** (era 100) e,
   toda vez que cruza o **meio EXATO** da tela (corpo centrado em x=128),
   solta o laser (arte `uploads/laser.png` do autor, 16×32) que desce a
   **6 px/frame**. O laser **mata** a nave. 4 sprites (57–60), tiles
   428–435 (pal3 ciano).
3. **BOSS** (`uploads/boss.png`, 96×128, mesma paleta do miniboss) após
   todas as ondas passarem **4× cada**: nave gêmea simétrica. Verificamos
   pixel a pixel: **simétrico na horizontal EXATO** (metade direita =
   sprites com flip H $40) e **NÃO simétrico na vertical** (3.190 pixels
   diferentes → metade de baixo precisa de tiles próprios). Sprite puro
   era inviável (12 colunas > 8 sprites/scanline do NES), então ele é
   **híbrido**: centro + pontas das asas em **Background** (102 tiles
   únicos no banco $0000) + asas superiores em **36 sprites** (18 tiles
   únicos, direita espelhada). Scroll **congela** na luta. 3 fases em
   ciclo: **leques alternados** saindo de cada asa (8 rajadas), **sara-
   ivada** de 20 tiros de posições/velocidades aleatórias, e **3 lasers
   gêmeos** do centro. **HP 120 → +5000 pts**, cenário restaurado e os
   contadores de onda zeram (ciclo recomeça).
4. **Tiro do player novo**: arte `uploads/tiro player.png` (2 frames,
   tiles 472–475, bytes OAM 217/219). pal3 virou ciano `$1C/$3C/$30`
   (mesma família da arte). Efeito colateral conhecido: as explosões
   dos inimigos agora saem em ciano/branco (antes vermelho/laranja).

**Bug da grade (v0.12a)**: nos testes de emulador o fundo virou uma
*grade* de pedacinhos do boss. Forense com pixel-match do screenshot
contra o CHR: a "grade" era o tile fís 32 — que a CVBasic usa como
preenchimento da nametable no boot (e como espaço do PRINT) e que era
vazio até a v0.11. A arte BG do boss foi remapeada para 33–95 + 213–251
(`gera_boss.py`), devolvendo o 32 à condição de vazio eterno.

Suites: `nes-test/v12_fechamento.py` (**27/27 OK**), regressões
`v08_ajustes.py` e `teste_v04_full.py` OK. GIF: `docs/space_blast_v12_boss.gif`.

## v0.11 — onda 3+3 do roxo + MINIBOSS (arte do autor)!

Pedido do autor: \"A tela tem poucos inimigos. Isso ajudaria a ter bem mais.\"

1. **Onda do small (roxo) em 3+3**: os 3 primeiros entram por um lado
   (43 ou 213) e, logo em seguida, mais 3 entram pelo lado **oposto**
   — 6 smalls na tela se sobrepondo. Slots ampliados p/ 6 e mapa OAM
   reorganizado: smalls 4–15, tiros player 16–20, shards 21–24, tiros
   inimigos 25–32, explosão 33/34, placar 35–39, vidas 40 (enemy4 segue
   41–56).
2. **MINIBOSS NOVO** (32×32, 2 frames, arte `uploads/miniboss-1.png`
   do autor, cores Lospec NES **$03/$23/$38** respeitadas): interlúdio
   a **cada 4 ondas** (wnum 3, 7, 11...). Entra pelo topo, desce até o
   meio (y=100) e passa a patrulhar esq/dir (margens 16/200), lançando
   **anéis de 8 tiros** (mesmo `spawn_ring` do shard). **Trava
   anti-slowdown** pedida pelo autor: só dispara um novo anel quando o
   pool de 8 tiros inimigos esvazia + descanso de 2.5s. **HP 48** (1
   tiro = 1 de dano, com faísca no impacto), **+500 pts** (= medB do
   original, `js/enemies.js`). Colisão da nave também dá 1 de dano nele.
   Reutiliza os slots OAM 41–48 do enemy4 (ondas são exclusivas, nunca
   coexistem) — assim coube nos 64 sprites do NES (4+12+5+4+8+2+5+1+16).
   Tiles CHR físicos 396–427 (`gera_miniboss.py`).
3. **Palette swap cinematográfico**: durante a luta, a pal2 vira as
   cores exatas da arte (VPOKE $3F19–1B) — efeito colateral assumido: a
   chama da nave fica roxa só nesse período; restaurada na morte dele
   (e por PALETTE LOAD em game over/novo jogo). O shard nunca divide a
   pal2 com o miniboss porque as ondas são exclusivas.

Testes: suíte `nes-test/v08_ajustes.py` (small 3+3 + miniboss: chegada
na 4ª onda, descida até y=100, patrulha, anéis de 8 com trava de 150f,
1 HP por tiro, morte +500, próxima onda) **TUDO OK**; regressão
`teste_v04_full.py` **SUITE OK**. RAM: 519/1805. GIF:
`docs/space_blast_v11_miniboss.gif` (o bot mata o miniboss no final!).

## v0.4 — fundo harmônico, logo no título e fim dos slowdowns

**Fundo de estrelas (novo spritesheet do Saulo)**
1. **Parallax removido** (não funcionava bem — estrelas sumiam). O fundo é
   um scroll único como antes, sem nenhuma animação/cintilação: zero VPOKEs
   por frame no loop.
2. **Sheet 64×32 `estrelas-cinzas.png`** virou os 32 tiles em PATTERN 0–31
   (índice 0 = tile vazio, usado pelo CLS). Cores do sheet mapeadas:
   azul→`$11`, branco→`$21`, cinza→`$00` (discreto, não confunde com tiros).
3. **Distribuição harmônica**: 48 setores de 4×5 células por nametable,
   1 estrela sortida por setor em posição aleatória — nunca aglomera nem
   deixa buracos. A nametable 2 (`$2800`) é preenchida **uma única vez no
   boot** (o CLS só limpa a nametable 1 — verificado em
   `cvbasic_nes_prologue.asm:cls`), então cada transição re-plota só 48
   VPOKEs (rápido).

**Tela de título**
4. **Logo oficial (title.png) no centro**, quantizada para o NES:
   "CARAVAN BLAST!" em azul/ciano/branco (pal1) + faixa vermelha com
   katakana em vermelho/rosa/branco (pal2). 96 tiles de fundo (PATTERN
   96–127 e 148–211). Atributos 16×16 dirigem cada bloco para a paleta
   certa; o corte azul→vermelho cai exatamente na fronteira de quad (py 48).
   O filete vermelho do CARAVAN virou branco (limite de 3 cores/bloco).
5. **APERTE START** piscando abaixo da logo; rodapé **2026 - FALCON SOFT**.
   Textos usam a pal1 (branco) via atributos; estrelas continuam discre-
   tas na pal0. Game over também carrega a paleta do título + atributos
   para o texto ficar branco.

**Anti-slowdown** (medido em fceumm: iterações do game loop por frame —
antes 77–84% sob fogo ⇒ agora **92–100%**):
6. **Inimigos atiram menos**: cadência do tiro mirado ~40% mais lenta
   (`smd` 33+RND22→40+RND26 na entrada, 30+RND24→44+RND28 entre tiros).
7. **Tiros inimigos a 30 Hz** com passo dobrado (metade dos 8 slots por
   frame, mesma velocidade final); faixa de saída reforçada para nunca
   enrolar o byte de x na borda.
8. **Placar em BCD incremental** (`s0..s4`): `update_score` tinha 4
   divisões genéricas de 16 bits por kill (~1500 ciclos!); agora é só
   propagação de carry + 5 sprites. Game over imprime os dígitos.
9. **Colisão shard×tiro em janelas byte** (era 16 bits com ABS ×20 pares
   por frame), guardada para somas não enrolarem nas bordas.
10. **Zigzag sem divisão genérica**: `/128` virou `/256 * 2` (shift rápido,
    erro <1px). Divisões dos tiros inimigos computadas **uma** vez e
    reusadas no desenho e na colisão.

## v0.3 — fundo discreto com parallax

1. **Cintilação removida**: acabaram os 2 VPOKEs/frame do efeito de piscar
   (menos trabalho por frame → alívio de slowdown). O scroll (quase grátis,
   só 2 escritas em registrador) continua.
2. **Só estrelas azuis em destaque**: tiles 16 (ponto) e 17 (cruz) como
   estavam. O diamante branco grande (tile 18) saiu.
3. **Estrelas cinza novas**: pontos de 1px em cinza escuro (`$00`), para não
   se confundir com tiros. A paleta do gameplay (`game_palette_play`) tem a
   cor 3 do fundo em cinza escuro; título/game over mantêm a paleta com
   branco para o texto ficar legível.
4. **Parallax 2 velocidades**: as cinza andam a **0,5 px/frame** (metade das
   azuis, que seguem no scroll a 1 px/frame). Técnica: 8 tiles (PATTERN
   24–31) com o pixel em cada linha 0..7 — a estrela "desliza" dentro do
   tile e só troca de célula na nametable a cada 8 fases. Cada estrela tem
   coluna exclusiva (1,5,9...29), que as azuis evitam, então apagar/replotar
   nunca destrói uma azul. 4 estrelas atualizadas por frame → ~4–5 VPOKEs
   por frame, bem dentro do buffer de 21.
   Validado em fceumm: 32 px em 64 frames por estrela (fases ciclam 7→0 e a
   linha cai 1 a cada 16 frames — exato).

## v0.2 — correções de playtest

1. **Shard não some mais no meio da tela**: a saída diagonal agora vai até
   os limites (x=255 à direita / x=1 à esquerda), cruzando a tela inteira.
   Raiz: `shx+shvx` em 8 bits estourava o sinal em x≥128; na correção em 16
   bits, descobrimos um **bug real do gerador de código 6502 do CVBasic** —
   usar a mesma global de 16 bits em duas comparações do mesmo `IF a AND/OR b`
   avalia a 2ª com o byte alto sujo (o `TYA` vem errado). Regra adotada no
   código: **uma comparação de global 16-bit por IF** (arrays via `_peek16`
   recarregam A/Y e são seguras). Também matamos o shard *antes* de o byte
   de x dar wrap (`#ad < 1` na saída à esquerda) para o sprite nunca piscar
   na borda oposta.
2. **Tiros inimigos funcionando**: as balas inimigas nunca eram escritas no
   array (verdadeira posição ia parar em $0000!) — outro caso de codegen:
   `#arr(i) = #var * 16` reutiliza o `temp` do endereço do elemento. Solução:
   multiplicar antes num global (`#tw`) e só depois copiar pro array. Mira
   8-dir também corrigida (sinal de `#adx/#ady` era extendido sem-sinal).
   `eb_spawn` não usa mais `c` (destruía o FOR das ondas).
3. **Smalls**: **3 por onda** (era 4 — slowdown), **frame estático** (fr13,
   sem inclinação jitter) e **zigzag fluido** (máx 3 px/frame). A causa da
   movimentação "estranha": `READ st(c)` lia **16 bits** por entrada
   (CVBasic: parear `READ BYTE` com `DATA BYTE`!) — só metade da tabela seno
   existia e o resto era lixo.
- Bônus anti-slowdown: posições 16-bit agora usam **bias +256** (sempre
  positivas) → todas as `/16` viram divisões unsigned rápidas em vez de
  `_div16s` (muito lenta). Colisões por janelas byte sem ABS onde possível.

## v0.1 — o começo do game

- Nave do jogador 16×16, com a animação **exata** do original (`PANIM` do
  `player.js`): idle 0-3 · virar 4-6 · segurar 10-13 (direita) · esquerda =
  H-FLIP · ao soltar, retorno 6-5-4. Quatro sprites em camadas: corpo em
  cinzas, canopy azul-vermelho (pal 1), chama verde (pal 2).
- **Onda 1 — smallFormation** (Enemy1.png): 4 naves em coluna A/B/C (43, 128,
  213 — mapa das 3 colunas 480→256), descida em **zigzag senoidal**
  (tabela de 64 entradas, amplitude 16-28 aleatória), inclinação lateral
  pela derivada do movimento (frames 13/15/18, esquerda = H-FLIP — os lados
  do sheet são espelhos exatos), **2 tiros mirados** em 8 direções
  (~160 px/s escalado). +100 pts cada.
- **Onda 2 — shardFormation** (Enemy5.gif): 4 diamantes verdes em coluna,
  mergulho rápido (~336 px/s escalado), lado L/R alternado (âncoras 51/205),
  saída em diagonal ao chegar embaixo. Ao morrer: **anel de 8 tiros**
  (~145 px/s), igual ao original. +120 pts cada.
- Ondas **alternam** com dificuldade crescente (velocidades sobem a cada 2
  ondas, teto 3).
- Tiro do jogador = **tiro vermelho nv.1** do original (`WEAPONS.red`):
  rajada de 5 tiros (1 a cada ~3 frames, gap de ~16), velocidade ~4 px/frame.
- **3 vidas** (HUD em dígito, canto superior esquerdo), respawn com 1.5 s de
  invencibilidade piscando, game over → volta ao título.
- Placar em sprites (o fundo rola!), fundo de estrelas com scroll + cintilação
  (adaptação do fundo escuro de `bg-fase-01*.png`).
- SFX de tiro/explosão nos canais de pulso/ruído.

Sprites inimigos convertidos de 32×32 → 16×16 (small) e 8×8 (shard, tiros),
quantizados na paleta 2C02 respeitando 3 cores+transparência por sprite e as
4 paletas globais — veja `../nes-test/mock_nave*.py` e `gera_bitmaps_cb.py`.

## Escala de conversão (480×640 TATE → 256×240 NES)

Horizontal ≈ ×0.53, vertical ≈ ×0.375; velocidades convertidas px/s →
1/16 px/frame. Frames de animação preservados 1:1 por hardware H-FLIP.

## Compilar e rodar

```sh
./build.sh        # precisa de ../cvbasic-repo e ../gasm80-repo (ver cata-estrelas)
```

Gera `caravan-blast.nes` (iNES, mapper 0/NROM). Abra em Mesen 2/FCEUX/Nestopia.

- **Direcional**: move · **B (segurar)**: rajada · **Start**: inicia/reinicia

Testes automatizados no fceumm (libretro): `../nes-test/teste_cb.py`.

## Fora de escopo nesta versão (próximos passos)

- medA (Enemy4, sine), medB (miniboss Enemy2), medC (Enemy3, lemniscate)
- Combo, medalhas, cápsulas/power-ups (verde/roxo), laser, mísseis
- Boss (Boss1.gif) e o cronômetro da caravana (5:00)
- Título com logo real (title.png) + Saturno, intro, parallax do fundo
- Música (BGM stage1) — os canais estão quase livres

## v0.5 (jul/2026) - Trilhas sonoras

Arranjos NES das duas MP3 originais (`assets/bgm/title.mp3` ~96bpm, la# menor;
`assets/bgm/stage1.mp3` ~174bpm, sol menor), gerados por `music/compose.py`:

- **Transcrição**: `music/transcribe.py` (STFT + saliência harmônica 1-5 +
  Viterbi, grade de colcheias) e `music/drums.py` (onsets percussivos em
  bandas K/S/H). Tempo medido por autocorrelação: 173.7bpm (fase), 96bpm (título).
- **Player CVBasic NES** (`CVBASIC_MUSIC_PLAYER`): tick real de 50.0832Hz
  (roda 5 a cada 6 NMIs). `PLAY` label inicia música; modo: PLAY FULL=5
  (2 pulsos + triângulo + bateria no ruído), SIMPLE=3 (2 pulsos + bateria).
  Nota CVBasic = LETRA OITAVA [#] [instrumento]: `A4#Y`. Instrumentos:
  W=piano 75%dec, X=clarineta 12%vibr, Y=flauta 50% sust, Z=baixo (período×2).
  `S` = sustain, `-` = pausa, `MUSIC REPEAT` loop, `STOP` fim.
- **Limites medidos (fceumm)**: piso audível ~A2/110Hz (filtro passa-altas do
  emulador mata 65-98Hz); triângulo soa 1 oitava ACIMA do codificado (LSR no
  player) com piso em D3; clone ch3->ch2 quando pulso2 em pausa -> REGRA:
  pulso2 sempre ativo enquanto o triângulo toca; Z vedado no triângulo;
  notas 61-62 com Z no ch1 colidem com $FD/$FE (repeat/stop).
- **Tempo real vs alvo**: colcheia = 9 linhas no tick 1 -> 166.9bpm
  (alvo 174, -3.8%, uniforme); título: tick 2, 8 linhas -> 93.9bpm (alvo 96).
- **Bateria**: M1 = ruido médio 3 ticks ($400E=$06, bumbo/caixa), M2 = tick
  curto agudo ($02, chimbal), M3 = rolo. Um hit por linha.
- **SFX x música**: `SOUND 10-14` escreve DIRETO nos registradores; o player
  regrava os canais a cada NMI a partir de `audio_*` -> efeito e música se
  intercalam por frame (efeito "ducking" clássico, ~1 tick de duração).
- Integração: `PLAY FULL` no boot; `PLAY mus_title` na tela de título;
  `PLAY mus_stage1` no begin_game; `PLAY OFF` no game over.
- Blocos gerados: `music/music_blocks.bas` (NÃO editar à mão; regerar com
  `python3 music/compose.py`). +5.3KB de PRG (16.2KB usados, 16.5KB livres).
- Prévias: `docs/preview_stage1_nes.wav` (2 loops), `docs/preview_title_nes.wav`.
- Performance medida no emulador: 99.7% do frame budget com a música ligada.

## v0.5.1 - Fix: laser do player migrado pro pulso 2

Sintoma: "sons estranhos" ao atirar durante a música da fase. Causa: o laser
(SOUND 10) disputava o PULSO 1 com a melodia — o player regrava o canal a cada
NMI e o SFX a cada frame do main, picotando a melodia (interleave ~50/50 por
frame durante a rajada). Correção: laser agora usa SOUND 11 (pulso 2), que só
divide canal com o arpejo (fundo) — melodia segue limpa. Verificado no emulador:
com rajada contínua, o pitch da melodia fica estável; performance inalterada
(99.7%). O som do laser em si não mudou.
