# Space Blast (NES) — Histórico completo do projeto

**Ponto de partida / backup** — gerado em 29/07/2026; atualização da
baseline em 28/08/2026.
Este documento resume o histórico técnico para que o projeto possa ser
retomado mesmo sem o histórico da conversa.

**ESTADO ATUAL = v0.28 baseline**. A fonte de gameplay permanece congelada;
esta etapa só consolidou a infraestrutura de build/teste e corrigiu os
três laços de duração longa das telas finais.

### v0.28 baseline — build reproduzível e validação externa

ROM entregue: `b22ac571b09857c03b04016c692f6502` (MD5),
`c464d8db98fb2ec4e3f6b8270ebb98458e86095bba92ee9252dc9972d2cfaee5`
(SHA-256), 524.304 bytes, iNES mapper 30, 512 KiB PRG e CHR-RAM.

- A suíte independente `nes-test/test_v028_baseline.py` passou: boot,
  ciclo SELECT `1 → 2 → 3 → 4 → 5 → 1`, bancos CHR `$00/$40`, cenários
  espacial/vermelho/azul, boss da fase 5 (HP 120, dano e morte), cerimônia,
  quatro telas do ending e retorno a uma partida nova na fase 1.
- A inspeção de código confirmou que não restou `FOR` numérico acima de
  254. CVBasic mantém contadores de laço em 8 bits; portanto os holds que
  estavam escritos como `0 TO 269` e `0 TO 449` foram substituídos por
  `2 × 135 = 270` e `2 × 225 = 450` frames. Isso corrige a duração sem
  mudar a lógica de gameplay.
- `build.sh`, `build-dbg.sh`, `gen_addrs.py`, `emu_lib.py` e os geradores
  principais passaram a resolver caminhos relativos ao próprio script; o
  build aceita `CVBASIC_BIN`, `GASM80_BIN` e a suíte aceita `FCEUMM_CORE`.
  Nenhum procedimento depende do GitHub Desktop.
- Resultado observado no emulador: os holds estáveis medidos foram
  `226/286/466/286` frames (fade + overhead explicam a diferença do alvo),
  e a fase 1 voltou em 1.585 frames após a morte do boss.
- **Não iniciar recursos de gameplay** antes do teste do usuário no Mesen
  e no hardware real. Próxima ação após o retorno: registrar o veredito e só
  então planejar inimigos próprios/detalhes visuais.

### v0.24 — Torus de 31 slots (scroll definitivo) — histórico anterior
Saulo testou a v0.23: "tudo é gerado certo fora da tela lá em cima,
mas muda um pouco abaixo do meio... ilhas da esquerda desaparecem
depois de 1 scroll". AUTÓPSIA da nossa própria correção:

- FOTO DO CRIME (zoom 6x no rodapé, fases 2..5): faixa LISA/escura de
  altura variável (~16px na fase 7, ~4px na fase 0) + ilhas mutiladas
  saindo. Dois erros da v0.23:
  1. FLIP 8 FRAMES CEDO: escrever o slot do FUNDO no frame da costura
     é 8px adiantado — aquele slot ainda exibe a linha velha saindo do
     rodapé (a tela mostra T+0..T+29+duplicado do topo: o slot do
     fundo serve a imagem por MAIS 8 frames!). Resultado: "linha do
     futuro" trocando no rodapé = ilhas picotadas sumindo.
  2. $2800 NÃO ERA MORTA: no coarse-Y 30 o PPU TOGGLE A NT VERTICAL
     (comportamento real de hardware, vide nesdev) — os últimos
     (fine) px da tela leem $2800 slot 0, que na v0.23 ficou congelado
     desde o setup (os espelhos tinham sido extintos). E é POR ISSO
     que a fase 1 sempre foi perfeita: as 3 páginas idênticas dela
     alimentam esse strip por construção!
- FIX (motor final, o mais simples até agora):
  - fase 7: flip do slot do TOPO (wr = sy/8 na 1a costura, decremento
    por costura, anel 60 wrap 0->59) — a linha nasce ATOMICAMENTE com
    o 1px que espia no alto (writes+scroll flush no MESMO NMI);
  - fase 6: $2800 slot 0 <- linha (topo+30) mod 60 = "31o slot";
  - 2 rajadas de 32 writes/ciclo, PPUBUF 48 tranquilo.
- PROVAS: NT $2000 + $2800 slot 0 byte-a-byte == modelo em 1400 frames
  (168 costuras, 100% no slot do topo); rodapé liso em todas as fases
  (nes-test/v024_rodape.png); vel fase 2 = 1340/1400; fase 1 299/300;
  suítes 4/4 verdes. ROM bf659ad1868f30d99598d78d74a01da8.
- APRENDIZADO IMORTAL: a tela no fine-scroll mostra 30 linhas + strip
  de até 7px lido da OUTRA NT vertical = o "torus" real do jogo tem
  31 slots (30 em $2000 + slot 0 de $2800).
- EM ABERTO (bug #2 do Saulo): estrelas erradas na fase 01 + tela de
  abertura apos uma tela de GAME OVER (print dele: reticulado
  uniforme de pontos). NAO reproduzido no fceumm em 4 rotas: morte na
  fase 1, morte na lava, morte DURANTE o boss (ppu_ctrl $B8 restaura
  certinho em $A8), spam de START no game over. NT e CHR-RAM saem
  byte-identicos ao boot fresco em todas. Pedido ao Saulo: qual
  emulador + onde foi o game over + o que apertou depois.

### v0.23 — Scroll da lava certinho (torus de 30 slots; superada pela v0.24)
Sintoma (Saulo): "as ilhas ainda somem... são construídas bem no meio da
tela, quando era pra ser fora dela, lá no alto." Ele estava certíssimo.

- AUTÓPSIA (v0.22 medida, 420 frames de fase 2):
  RESUMO: 6 writes no slot LIVRE | 64 em slot VISÍVEL (BUG)
  histograma pos (0=topo, 15=MEIO, 29=fundo):
  {1:6, 3:4, 5:4, 7:6, 9:6, 11:5, 13:3, 15:4, 17:4, 19:3, 21:3, 23:5, 25:5, 27:6}
  Trecho do log (frm sy slot pos srq #ld):
  32  182   7  15  37  $20E0   <- linha nova no MEIO da tela
  88  126  14  29  44  $21C0   <- a única no lugar certo (1/15)
  96  118  15   1  45  $21E0   <- na linha do TOPO (vira lixo aparente)
- CAUSA RAIZ (2 fatos + 1 inversão):
  1) scroll do jogo é BYTE (0-239, guard $FF->$EF no .bas); NMI grava
     PPUSCROLL com o byte e os NT bits do PPUCTRL vêm de scroll_y+1,
     SEMPRE 0 ⇒ renderiza-se só a $2000: TORUS de 30 slots, todos
     visíveis; $2400/$2800 nunca lidas (fceumm/Mesen/hw).
  2) o "design 480px escondido" da v0.19 era geometricamente
     impossível nesse torus.
  3) INVERSÃO DE MARCHA: #ld andava +32/linha e o topo visível anda
     -32/linha ⇒ cruzamento 1x/15 costuras ⇒ writes caíam em qualquer
     lugar da tela = ilhas sumindo/surgindo.
- FIX motor-vida-nova (lava_tick/lava_in reescritos):
  - 1 costura por 8px na fase (scroll_y AND 7)=7, 32 writes num só NMI;
  - alvo = slot do FUNDO (topo-1): nasce pronta ~8 frames antes de
    entrar pelo alto = "fora da tela, lá no alto" (a física do torus);
  - ordem das linhas DECREMENTANDO (anel 60: B 59..30, A 29..0, wrap
    0->59), fase travada na 1ª costura via scroll_y (imune a stall);
  - #ld = $2000 + w*32 via ASM low=w<<5 / high=w>>3|0x20 (carry ok);
  - espelhos $2400/$2800 extintos (CPU devolvida; setup ainda enche as
    3 páginas uma única vez, inerte).
- ARMADILHAS DO VERIFICADOR (p/ nunca mais):
  1) addrs mudam a cada build → parsear cvb_* do .asm, nunca hardcode
     ($0AA virou $0A7).
  2) NT flusha 1 frame após o enqueue: modelo deve tolerar 1 frame de
     latência, senão "linha errada" fantasma (o falso "lê A em vez de
     B": era o slot ANTES do flush; o read_pointer $88BB provou que o
     jogo lia B certinho).
- PROVAS:
  - NT $2000 == modelo Python do torus BYTE-A-BYTE em 1200 frames
    (149 costuras; sync pela transição WRF 0->1 na RAM);
  - costuras 100% na posição 29 (fundo);
  - A/B visual: nes-test/ab_v022_pop_vs_v023_scroll.png +
    ab_v022_v023_telas.png (a ilha materializa no meio na v0.22; na
    v0.23 nasce no alto e desce);
  - velocidade: fase 2 = [100,99,94,98,100x7,98,99,100] = 1388/1400
    vs 1324/1400 da v0.22; fase 1 = 299/300;
  - suítes 4/4 verdes.
- CICATRIZ INERENTE: preview de ≤7px da linha nova no rodapé por ~8
  frames (torus). Alternativa real = scroll 480px (2 NTs): cirurgia no
  NMI compartilhado — candidato v0.24 SE o Saulo quiser pixel-perfeito
  absoluto no rodapé. ROM cf7db4d6bc48cc554434fc85bef5d7cb.

### v0.22 — Canhões extirpados + anel perfeito
- DESCOBERTA CENTRAL: o `lava_layout.bas.inc` era CARTA MORTA (ninguém
  incluía); o layout com os 5 canhões (subtiles 100-103) vivia INLINE no
  .bas desde a v0.19. Por isso o "quadrado" insistia! Patch nas 10
  posições do DATA inline -> provado: 0 tiles 100-103 na NT.
- Anel re-escrito com aritmética 100% 16-bit (shadow #lp/#ld): o r*32
  em 8-bit da geração anterior corrompia tudo. Linha nova na $2000 +
  cópia na $2400/$2800 (3 páginas = qualquer mirroring). Prova com
  âncoras de ilha: janela circular 100% perfeita.
- Stream em 6 eventos de 16 writes (triggers AND7=7/5,4/2,1/0).
- Aprendizados imortais no .bas: FOR-254 infinito, `' comment` em ASM,
  var fantasma, layout inline duplicado.
- Suítes 4/4 verdes.

### v0.20 — Fase 2 = Fase 1 c/ lava, MESMA velocidade
- Canhões de cenário fora de vez (mapa+init+proc+tick+DIMs); fase 2 =
  fase 1 só com cenário de lava (ondas/inimigos/música iguais).
- LENTIDÃO AUTOPSIADA: scroll avançava 210/300 frames (vs 299/300) —
  burst de 64 writes no PPUBUF (21 writes/frame) estourava e o WRTVRM
  `JMP wait` comia ~1 frame por linha streamada. Fix: stream em quartos
  (4×16 writes) + PPUBUF $40→$90. Depois: [598,598,598,596] nos dois.
- Suítes 4/4 verdes.

### v0.19.2 — SELECT troca de fase + fim do palette cycling
- **SELECT alterna a fase na hora** (debug do Saulo): `fase = 3 - fase` →
  begin_stage; fase 2 preserva placar/vidas, volta p/ 1 = partida nova.
  A volta roda `clear_nts` (zera $2000/$2400/$2800 — o anel do lava deixa
  lixo que o stars_fill não recobre).
- **ARMADILHA CVBasic documentada**: `FOR` com limite > 254 é laço infinito
  (contador 8-bit + BCS) — travou o boot 2x até acharmos (tela preta com
  música = NMI viva e CPU presa). Faxina em blocos `0..63` + WAIT c/ dreno.
- **Removido o pulso de paleta do lava** (rachaduras fixas $16).
- Suítes 4/4 verdes; v13 com espera de gameplay p/ boot mais longo.

### v0.19 — FASE 02: PLANETA DE LAVA
- Fluxo pós-boss do spec: cerimônia (estrobo+explosões) → `FASE 01
  COMPLETA` (PONTUACAO/VIDAS persistem, gate `IF fase=1` no reset) →
  cartão `FASE 02 / PLANETA DE LAVA` → lava. Game over → START → splash
  Falcon (não mais meio da fase 1). Contador de ONDAS removido.
- Lava = anel de 60 meta-linhas (480 px, `lava_map_a/b`, banco 3) com
  streaming por linha do `$2000` + **dual-write** da linha evictida no
  `$2800` (immune a H/V-mirror e ao four-screen do fceumm novo). ASM de
  re-RESTORE+skip p/ as waves do banco 0 não sequestrarem o ponteiro.
- Canhões BG (tile B1) em 5 pontos do anel, tiro em 8 direções mirando o
  jogador, bala nascendo na boca; pulso de paleta $16↔$17 2x/s; inimigos
  da fase 1 reciclados p/ teste; C1 reservado p/ canhão destruído.
- AUTÓPSIA: o nightly do fceumm trocou p/ XRGB8888 (bpp novo) E nosso
  decoder tinha B↔R trocado → "rachaduras azuis" era vermelho (208,32,32)
  espelhado; bit-exact c/ paleta asqrealc; o "fundo cinza" = flash de
  morte $10 no frame capturado. Zero bugs de cor no jogo.
- Suítes: v04/v08/v12 verdes; v13 adaptada (30 checks) verde.

### v0.18 — Game Over retocado + cartão "FASE 01"
- **Pedidos do Saulo**: (1) "GAMEOVER" junto (sem o espaço), centralizado;
  (2) frases do game over com 1 linha de espaçamento; (3) tela de game over
  entra em **fade por palette cycling** como a Falcon; (4) após START, tela
  preta com "FASE 01 / A CAMINHO DO PLANETA DE FOGO" no centro, também em
  fade, **cortável com START ou saindo sozinha** em alguns segundos.
- **Implementado**: GAMEOVER = tiles 214–221 contíguos `$214C–53` (l.10,
  col 12); linhas 10/12/14/16; `go_draw` e `stage_card` no **banco 1**
  (banco 0 estourou 91 B no 1º build — `TIMES -91`; migrados com a dança
  BANK SELECT dos procs de boss). Cartão: anti-corte acidental (espera o
  START ser solto), fade-in, hold ~4 s, fade-out só quando sai sozinha;
  START no game over agora faz **retry direto** (game over → cartão → jogo,
  sem passar no título; marcado como mudança de fluxo pro Saulo).
- **Bug capturado por pixel**: v1 do fade escondia "OND" de "ONDA:" — linha
  14 cai nos quads BL (pal0), mas só `$3F07` (pal1) era rampada; fix =
  rampar `$3F03` junto. Verificado: 97 px "OND" faltantes → linha toda ok,
  APERTE (linha 16, attr row 4 = pal0) idem.
- **Verificação**: cartão (meio-fade aceso, cheio 682 px, auto-exit ~5,3 s
  rumo ao gameplay), game over com layout novo + pisca ok (292 px), retry
  direto; suítes **v08 29/29, v12 17/17, v13 OK, v04 OK** (patch p/ cortar o
  cartão no boot). ROM md5 `0e93d7d68ff2d1d729ee88ac168a8f4e`. GIFs v18 em docs/.

### v0.17 — "Fonte Saulo": spritefont em todo o jogo + HUD consertado
- **Relato do Saulo**: textos do HUD in-game quebrados ("por conta dessas
  mudanças") + ordem nova: criou uma **spritefont** (`uploads/Sprite_font.png`,
  16×6 células de 8×8, só preto/branco) e quer **todo** texto do jogo nela —
  "Tudo que formos escrever nas telas, a gente puxa desses sprites",
  incluindo "apresenta" e "APERTE START".
- **Autópsia do HUD** (medida→hipótese→prova, sem chute):
  1. Captura fceumm v0.16b: placar = 5 blocos brancos sólidos; vidas = glifo
     estranho no canto esquerdo.
  2. Diff de tiles v0.15↔v0.16b: fonte (32–95) e dígitos **idênticos** →
     "foi a reforma do título" NÃO se sustenta.
  3. Captura do gameplay **v0.15**: placar já eram 5 caixinhas vazadas +
     vidas "Ǝ" — **bug anterior ao v0.16**.
  4. Causa raiz: placar usa sprites 8×16 com tile OAM `s*2+128` (**par** →
     tabela $0000, lado BG), caindo nos tiles **128–147 = arte da logo** em
     todas as versões recentes. Os glifos de dígito nunca existiram lá.
- **Solução (gera_fonte.py, idempotente)**:
  - `CHRROM PATTERN 32` com as 64 posições ASCII 32–95 puxadas da folha
    (0-9←cells 16-25, A-Z←26-51, pontuação mapeada, `*`/ǹ`&`=✦, setas em
    `<^>~`, Ç no `` ` ``). Pixels valor 3 = paleta idêntica à fonte antiga.
  - Placar/vidas: pares 8×16 novos em **192–211**; código `+128`→`+192`
    (6 pontos). Score volta a mostrar números de verdade (na fonte dele!).
  - GAME OVER estilizado (cells 80–87 → patterns 214–221, 9 VPOKEs);
    "PONTOS:/ONDA:/APERTE START" na fonte nova automagicamente.
  - Splash: "apresenta"→"APRESENTA" (maiúsculas; folha não tem minúsculas),
    glifos 182–188 do CHRROM 1. Achado forense: `DATA BYTE
    182,185,186,183,187,183,184,188,182` ⇒ s=187, n=184 (1ª tentativa saiu
    "APRENESTA"; captura flagrou; corrigido).
  - Reservados: 224–229 (mini-labels BONUS/1UP + seta).
- **Faxina do workspace (30/07)**: estouramos 136 MB/128 MB. Saulo baixou
  TODOS os zips p/ a máquina dele e autorizou a limpeza. Onda 1: 5 zips
  antigos (29/07, 30/07 geral, v015, v016b, nrom-v014), pasta
  `backup_nrom_v014_2026-07-30/`, `nrom_v014_backup/`, o **fonte HTML5
  (`spaceblast/js/`)** e o `caravan-blast.nes` (ROM do nome antigo).
  Onda 2: o zip slim (cópia local com o Saulo), `exemplos-build/`,
  os 4 GIFs da era "Caravan" (`docs/caravan_*.gif`), a referência
  `assets/sprites/Caravan-title.gif` e PNGs de diagnóstico do nes-test.
  Resultado: **137 MB → ~56 MB**. **Política final de backup (Saulo,
  30/07)**: manter SEMPRE 1 zip no workspace —
  `space_blast_backup_2026-07-30.zip`, regenerado a cada versão (completo:
  fontes+ROM+docs+testes+toolchain; MD5 interno conferido); versões antigas
  = cópias locais do Saulo.
- **Verificação**: 7/7 checks de byte; 4 telas capturadas ok; suítes
  **v12 17/17, v13, v08, v04 full — todas OK**. ROM md5
  `12a61c06b9bb188eed397981fdde88e6`. GIFs em docs/ (v17).

### v0.16b — Título com paletas por quad 16×16 (mapa do Saulo)
- **Pedido do Saulo**: cores do título erradas (SPACE azulada, BLAST bicolor,
  estrelas coladas na logo). Ele mesclou e mandou o **mapa de paletas por
  bloco 16×16 sobre a arte** (overlays coloridos: rosa=pal3 cometa/laterais,
  azul=pal1 SPACE, verde=pal2 BLAST) com a lição: no NES a paleta de BG não
  é por tile 8×8 e sim por **quad 16×16** (2×2 tiles).
- **Causa raiz (autópsia, docs/title_attr_diag.png)**: `gera_title2.py`
  empacotava os sub-quads do byte de atributo na ordem errada (TL,**BL,TR**,BR);
  o NES espera TL,TR,BL,BR. Todo quadrante direito de cada byte saía certo, o
  esquerdo zerado/estrelas — daí o padrão xadrez de cores.
- **Correções** (`gera_title3.py`): (1) logo regenerada **sem os 32 componentes
  de brilho/estrela** (censo: 65 componentes → 27 arte + 38 brilho; os brilhos
  voltaram a ser só tiles do cenário, espalhados pela malha stars_fill — como
  ele pediu); (2) atributos regravados no mapa dele: pal1=SPACE, pal2=BLAST,
  pal3=cometa+faixas laterais, empacotamento correto; (3) **bug achado no meio
  do caminho**: o bullet `•` do rodapé vivia no pattern 188 mas o VPOKE
  apontava 212 (vazio) → invisível desde a v0.16; agora `VPOKE $236C,188` e
  o `•` reaparece; (4) "APERTE START" segue todo branco ($23ED=$A8: o byte
  antigo $88 deixava os quads inferiores BL/BR em pal0 = RT cinzento).
- **Verificação emulador**: paleta por quad simulada = idêntica à referência;
  amostras de pixel: SPACE=W/g, BLAST=R/W, cometa=T, "APERTE START" 255
  lum (RT incluído), bullet visível (lum máx 255). Suites: **v12 17/17 OK,
  v13 boss OK, v08 OK, v04 SUITE OK**. ROM md5 a registrar no README.

### v0.16 — Splash FALCON SOFT + acertos do título
- **Pedido do Saulo**: (a) splash da Falcon Soft antes do título, aparecendo
  gradual via palette cycling, logo no centro + "apresenta", qualquer botão
  corta direto pro título, senão ~alguns segundos com transição suave;
  (b) título novo (title-space.png) sem a barra de katakana do Caravan
  Blast, "APERTE START" todo branco; (c) bônus: estrelas da folha nova no
  fundo das fases de espaço. ROM `c97bb6f6164cd3087a2ffabe8a458b6c`.
- **Detalhes técnicos** no README (seção v0.16). Pontos-chave: CHRRAM de
  32KB paginada (POKE $1C = CHRRAM_BANK bits 5-6 do BANKSEL; NMI restaura
  `ORA CHRRAM_BANK`; boot copia 4 chunks 29/30 → páginas 0-3); CHRROM 1 =
  página 1 da splash; fades por $3F02/$3F03 em 7 passos × 4f; splash PROC
  em BANK 1; hook só no boot (game over volta direto ao título).
- **Quebra-cabeça da logo resolvido**: folha 128×48 veio "desmontada" —
  análise forense (matching NCC + leitura de tiles) achou águia/asas/FALCON
  quase montados no lugar, SOFT em cascata nas pontas, escudo picado nos
  cantos; montagem própria bateu ~90% com a oficial que chegou depois
  (`Falconsoft-montado.png`, usada como fonte autoritativa).
- **Título**: paleta por quad 16×16 sem colisões (gerador `gera_title2.py`);
  bug do RT cinza = quads pal0 com idx3 `$00` (PRINT sempre usa idx3).
- **Boot sem flash**: 2 patches no .asm via build.sh (medido: 17f cinza →
  3f do detect NTSC). RAM: 591/1805 (zero novo).
- **Suítes**: fluxo de 2 STARTs documentado nelas; v12 17/17 ✓, v13 ✓,
  v08 ✓, v04 ✓ na ROM final. GIFs v16 em docs/.

### v0.15 — SPACE BLAST pra valer: rename + UNROM 512 (mapper 30)
- **Pedido do Saulo (madrugada, autônomo)**: (1) backup da versão "UNROM"
  (a NROM) p/ rollback, (2) converter TUDO p/ mapper 30 mantendo o jogo
  do jeito que está, (3) renomear o projeto de Caravan Blast p/ Space Blast.
- **Backup**: `/home/user/backup_nrom_v014_2026-07-30/` + zip homônimo
  (`CHECKSUMS.md5`: bas `6c967961…`, ROM NROM entregue `7b7a9c29…`).
  O zip geral `space_blast_backup_2026-07-29.zip` foi regenerado p/ v0.15.
- **Rename**: pasta `spaceblast/`, `space-blast.bas/.nes`, build.sh,
  gen_addrs.py e suítes atualizados. Prova de inocuidade: **mesmo md5 da
  ROM antes/depois do rename** (`81b9a3c6…`).
- **Migração mapper 30** (CVBasic `BANK ROM 512` nativo; doc: manual
  BANK/CHRROM; spike bank_nes.bas validado no fceumm antes de apostar):
  - banco 0 (fixo $C000, 15.900/16.378 B): boot, título, game loop
    completo, procs quentes (`score_add`, `aim_8dir`, `eb_spawn`,
    `spawn_ring`, `update_score`, `silence`, `stars_fill`…), TODAS as
    tabelas (`oam_ring`, paletas, `nep_tab`, `logo_map`, `sintab`).
  - banco 1 (7.710/16.383 B): `mb_frame`, `boss_frame`, `sky_clear`,
    `boss_write`, `boss_erase`, `boss_start`, `boss_kill`, `mb_kill`.
  - banco 2 (4.362/16.383 B): `mus_stage1`, `mus_title`.
  - bancos 3–28 LIVRES p/ fases 2–5; 29–31 = CHRROM (CHR-RAM no boot).
  - **Semântica de chamadas**: código no banco 0 é visível de qualquer
    banco (fixo). Procs no banco 1 NUNCA fazem `BANK SELECT`. Call sites
    no banco 0: `BANK SELECT 1` antes de `GOSUB` (idempotente).
  - **`GOTO player_dies` não pode sair de PROCEDURE** (retorno pendurado
    na pilha): solução = flag `diek` (RAM +1 byte); o jogador morre no
    frame seguinte ao retorno, no mesmo ponto — comportamento igual.
  - **Música bancada funciona nativo**: `PLAY` com banco 2 selecionado
    grava `LDA $BFFF → music_bank` (=1 medido); o NMI chaveia sozinho
    (prologue linha ~1085-1105: `LDA music_bank / ORA CHRRAM_BANK /
    STA BANKSEL` antes de ler o stream e restaura o banco no fim).
- **BUG CAÇADO (a novela)**: 1º build mapper-30 = lógica OK mas tela
  preta total. Espelhos PPU ok ($A8/$1E → render ligado). Causa real:
  os blocos DE DADOS ficaram fisicamente depois do `BANK 1` no source
  (o arquivo foi reorganizado 2×) → paletas/tabelas foram montadas no
  banco 1. Com banco 2 (música) ativo no title/gameplay, a PALETTE LOAD
  lia lixo = tudo preto. Fix: mover dados p/ antes do `BANK 1`. Moral:
  em CVBasic bancado, **conteúdo é do banco do marcador mais próximo
  ACIMA no arquivo fonte** — dado global tem que vir antes de qq `BANK n`.
- **Provas de equivalência**: 0 drops/1200 f em gameplay (ambas);
  `lfsr` e arrays de onda idênticos alinhando por game-frame (a fase
  −15f em probes de wall-frame = cópia CHR→CHRRAM no boot do v0.15);
  suites v12 17/17, v13 OK, v08 OK, v04 full OK. Único retoque em teste:
  margem do probe de pixels do HUD 30→80 (sensor de fase, comentado lá).
- **RAM**: 591/1805 B. **Boot**: ~15 wall-frames mais longo (CHR copy).

### v0.14 — laser nos 3 pontos + fim dos slowdowns
- **Pedido 1**: miniboss atira o laser também nos **extremos do passeio**
  (mbx 16 e 200), além do centro (112). Condição: `mbx <> mbxo` (borda
  de subida) com `mlr = 0`; `mlx = mbx + 8`. Prova em RAM: pontos
  disparados ⊆ {16,112,200}, os 3 vistos em 1 passeio (371f).
- **Pedido 2 (a autópsia do "slowdown")**: eram DOIS problemas somados:
  1. **Dropout na scanline (8 sprites/linha)** — 6 roxinhos = 12 metades
     na linha; a PPU descarta as excedentes e elas sumiam PARA SEMPRE.
     fceumm emula o limite (provado em screenshot). Fix: **anel OAM** de
     16 slots físicos (4-15 para as 12 metades dos smalls; 21-24 para os
     shards) com rodízio 1/frame (rr mod 16): flicker justo. REGRA
     **always-write**: cada membro escreve seu slot mapeado TODO frame
     (vivo desenha do cache / morto esconde) — sem isso sobram fantasmas
     ou duplicatas por 1 frame. Fora do anel (slots fixos, como sempre):
     player 0-3, tiros do player 16-20, tiros inimigos 25-32, explosões
     33/34, HUD 35-40, miniboss 41-48, Enemy4 41-56, laser 57-62.
  2. **CPU esgotada de verdade** — MÉTRICA NOVA: o var `frame` do
     CVBasic anda por NMI (sempre +1/frame: NÃO mede estouro!). Usar um
     contador por iteração do loop (`rr`) como loops/frame. v0.13 media
     **0,979** em 60 s de gameplay (2,1% de drops; pico 10,6% nas ondas
     de Enemy4). Custos reais: `/16` vira `JSR _div16`; cada acesso a
     array 16-bit vira `_peek16` (intercalado lo/hi); multiplicação
     16×16 do zigzag. Fix: **split de paridade (30 Hz) com passo
     dobrado** e **cache do y em pixel** (sem divisão por frame):
     smalls 3/frame (`smyy`), Enemy4 4/frame, shards 2/frame (`shyc`);
     tiros inimigos = loop v0.13 (já dividido; revertida tentativa de
     desenhar todo frame — custava 16 divisões a mais). Colisões de
     tiros inimigos ficaram byte a byte IGUAIS à v0.13 (mesmos frames).
     **v0.14 mede 0,995 médio / 0,47% drops (Enemy4: 63 → 1)**.
- **Timer de tiro dos smalls** continua por frame (mesmo ritmo do
  v0.13), usando o y cacheado; janelas de contato/tiro a 30 Hz não
  deixam passar nada (a bala cruza a janela em 7+ frames).
- **Armadilhas novas documentadas**:
  - OAM shadow NES: `+0=Y, +1=TILE, +2=ATTR, +3=X` (uma suíte lia +2
    como tile = ATTR 1 e "não achava" sprite nenhum!).
  - Sentinel "byte ≥ 240 = escondido na entrada" só funciona para spawns
    em -16 px. Shards entram em degraus até **-64** → y enrola para 192
    (faixa visível): manter o teste 16-bit `#shy < 4112` no desenho.
  - `k` já era o índice do `eb_spawn`; DIM duplicado = "Redefined label
    CVB_K". Rodízio usa o `k` compartilhado (comentado no DIM).
  - Testes que injetam bala e esperam 1 frame precisam de ~3 agora
    (janelas a 30 Hz).
- **Suite nova/expandida** (`v12_fechamento.py`): anel carregado no boot
  (r16), 12 metades sempre escritas, slot físico do small-0 percorre os
  16 slots do anel, mortos escondem o próprio slot, e os 3 pontos do
  laser. `v08_ajustes.py` e `v12` atualizados p/ paridade+anel.
  Benchmarks reproduzíveis em `/tmp/bench_seg.py` (regenerável).
- Backup ZIP regenerado ( MD5 verificado ) após esta versão.

### v0.13 — boss correto (1 nave no alto, 100% BG $1000)
- **Spritesheet, não gêmeas**: boss.png = 2 frames 96×64 empilhados.
  Boss reescrito: **uma nave 96×64 no alto** (NT linhas 3–10, cols 9–20),
  100% Background em **$1000** (86 tiles únicos nos slots livres:
  257–267, 272–275, 436–471, 476–511 — inclui a faixa das asas mortas,
  que saíram de cena). `ppu_ctrl=$B8` na luta / `$A8` fora (ASM inline).
  Sprites 8×16 = bit0 do byte OAM → imunes ao flip.
- **Céu preto autorizado**: `sky_clear` apaga as 960 células em 60
  passos (~1s top-down, dramático). **Balanço ±16px via SCROLL x fino**
  (wrap invisível no preto); leques/saraivada/lasers/hitboxes seguem o
  balanço. **Animação = pulso da cor `$38`** (38/28/18/28, ideia dele).
- **Bug dos textos (causa-raiz)**: `PRINT` = ASCII direto p/ tile;
  fonte vive em 32–95 de `$0000` → arte do boss v0.12 atropelou TODAS
  as letras. Bônus: tile 0 de `$1000` ocupado = "grade" do céu preto.
  Regra permanente: **tile 0 em branco nos DOIS bancos; 32–95 = fonte,
  intocável.** `gera_boss.py` documenta as faixas livres reais.
- **Novas armadilhas codegen CVBasic 6502**: (1) var byte **≥128 é
  sign-extendida** ao ser atribuída a var 16-bit (e=143 → #tbx=-113:
  asa direita cuspia tiros em x negativo); (2) representar "-16" como
  byte 240 e somar em contexto 16-bit vira +240. Solução: `#bo` =
  boff com sinal 16-bit, atualizado 1× por frame junto ao balanço.
- Game-over **durante o boss** restaura `ppu_ctrl` antes dos PRINTs.
- Suites: `nes-test/v13_boss2.py` (22/22), `v12_fechamento.py` (11/11:
  cota + miniboss), v08/v04 OK. GIF `docs/space_blast_v13_boss.gif`.

### v0.12 — fechamento da fase 01
- **Cota de 3 tiros do small (roxo)**: tags `ebt` + contador `nsm`;
  small com cota cheia remarca o tiro (retry) — só 3 tiros deles na tela.
- **Miniboss**: estaciona em **y=72**; ao cruzar o **meio exato** (x=128,
  `mbx=112`) dispara o **laser do Saulo** (6 px/f, sprites 57–60, tiles
  428–435) que mata a nave. Cruza 1x = 1 laser; patrulha segue atirando.
- **BOSS 96×128** a cada 4-de-cada-onda (`nsma/nsha/ne4 ≥ 4`): híbrido
  **BG + 36 sprites** (H-simetria exata medida por pixels; V não era
  simétrica; sprite puro impossível pelo limite de 8 sprites/scanline).
  Fases: 8 leques alternados das asas → 20 tiros dispersos (x/vel
  aleatórios) → 3 lasers gêmeos do centro → repete. Trava no pool de
  tiros inimigos em todas as fases. **HP 120, +5000 pontos**; scroll
  congela (`bsa`), paletas BG1/pal2 viram $03/$23/$38 e voltam na morte;
  `boss_erase` + `stars_fill` restauram o cenário; contadores zeram.
- **Tiro novo do player** em tiles 472–475 (bytes 217/219); pal3 ciano
  $1C/$3C/$30 — **efeito colateral**: explosões agora ciano/branco.
- **Bug da grade (v0.12a)**: arte BG do boss ocupou o tile 32 = byte $20
  do preenchimento de nametable da CVBasic → fundo virou "grade" de
  pedacinhos do boss. Diagnóstico por pixel-match screenshot→CHR;
  remapeado p/ 33–95+213–251 (tile 32 volta a ser vazio). Regenerar
  sempre com `gera_boss.py` (alocação `LIVRES` documentada).
- **Armadilhas do bot de demo aprendidas**: clampear `MBHP` **todo frame**
  zera o HP de volta (o dano real nunca vence o poke) → clampear 1× só;
  mira precisa de **antecipação** (~28 px = 32f de voo da bala × 1px/f).
- Suites: `nes-test/v12_fechamento.py` (27/27), regressões v08/v04 OK.
  GIF demo: `docs/space_blast_v12_boss.gif`. RAM 551/1805, PRG ~12.5 KB livres.

### v0.11 — smalls 3+3 + MINIBOSS (arte do autor)

- **Onda do small (roxo) 3+3**: 6 naves em 2 grupos de 3; grupo B entra
  logo após o A no **lado oposto** (43↔213). Arrays small → 6 slots
  (`sma(6)` etc.); **mapa OAM reorganizado**: smalls 4–15, tiros player
  16–20, shards 21–24, tiros inimigos 25–32, explosão 33/34, placar
  35–39, vidas 40 (enemy4 = 41–56 inalterado).
- **MINIBOSS** (pedido: entra pelo topo, desce ao meio, patrulha esq/dir,
  anéis de 8 tiros com trava anti-slowdown, HP alto):
  - Arte **do autor** (`uploads/miniboss-1.png`, 64×32 = 2 frames 32×32;
    preto = transparente; cores Lospec NES $03/$23/$38 → bits 1/2/3,
    `gera_miniboss.py` → tiles CHR fís. 396–427; OAM bytes 141–155 (A) e
    157–171 (B)).
  - **1 a cada 4 ondas** (`(wnum AND 3) = 3` → bloco próprio no wave
    manager; flag `mbw`; `wnum` continua ciclando os 3 tipos normais).
  - Estados `mbs`: 1 = descendo (16/16 px/f até `#mby=5696` ⇒ y=100),
    2 = patrulha (±1 px/f, inverte em mbx 16/200). Animação 2 f (FRAME/8).
  - **Anel** (`spawn_ring`): só quando `eba(0..7)` TODOS 0 + `mbt=150`
    (2.5s). Verificado: gap exato 150f, 8 tiros.
  - **HP 48** (`mbhp`), 1 tiro=1 dano (faísca mpt=6,#pop=4); morte =
    `mb_kill`: +500 pts (e=5,=medB do JS), mpt=16,#pop=16, esconde 41–48.
  - Colisão nave↔miniboss: 1 dano nele + nave morre (regra v0.10).
  - **OAM reusa slots 41–48 do enemy4** (ondas exclusivas, nunca
    coexistem) — necessário p/ caber nos 64 sprites do NES.
  - **Palette swap**: no spawn, `VPOKE $3F19..1B = $03/$23/$38` (pal2
    vira a arte; chama da nave fica roxa — efeito aceito); `mb_kill`
    restaura $19/$2A/$30. Game over/novo jogo restauram via PALETTE LOAD.
- Vars: mba(0x5d) mbs(0x5f) mbhp(0x9e) mbx(0x62) #mby(0x71) mbdir(0xa1)
  mbt(0x60) mbw(0x61) colb(0x6d) colx(0x6e) — ver nes-test/addrs_cb.py.
- Testes: suíte v08_ajustes estendida **TUDO OK**; v04_full **SUITE OK**.
  GIF `docs/space_blast_v11_miniboss.gif` (bot mata o miniboss!).
- RAM 519/1805.

---

## 1. O projeto

Port do jogo HTML5 **Space Blast** (antes "Caravan Blast") de **Saulo San**
(http://saulosan.com.br/caravanblast — jogo e assets do próprio autor, uso
autorizado) para **NES/Famicom**, escrito em **CVBasic v0.9.2** (alvo 6502),
montado com **gasm80**. O cartucho gerado é **NROM (mapper 0)**, 40.976 bytes
(32KB PRG + 8KB CHR + header iNES).

- ROM final: `caravanblast/caravan-blast.nes` (os arquivos do projeto seguem
  com o nome antigo `caravan-blast.*`; renomear é opcional/pendente).
- Telas/fluxo: **título → gameplay → game over → título**, tudo verificado
  em emulador (fceumm via libretro).

---

## 2. Estado atual (v0.7)

**Congelado a pedido do autor** (NÃO mexer sem pedido explícito):
1. **Mecânicas existentes** — o autor já pediu ADIÇÕES específicas (como
   o meteoro da v0.7); a regra é não *alterar* o que existe sem pedido.
2. **Músicas/arranjos** — "A música ainda precisa melhorar muito, mas não
   vamos mexer nisso agora".

Funcionando e verificado:
- Tela de título **Space Blast** idêntica ao mockup do autor (ver §5).
- Gameplay com nave, rajada de tiros (B), 2 ondas de inimigos (small
  zigzag + shard), tiros inimigos mirados, shard em anel, placar 5 dígitos,
  3 vidas, invencibilidade pós-respawn, game over com pontos/onda.
- Fundo de estrelas harmônico (48 setores, sem parallax), rolagem suave.
- Trilhas NES transcritas das MP3s originais (título ~94 BPM G#m,
  fase ~167 BPM Gm) + SFX (laser, explosão) — performance 99,7% do frame.

---

## 3. Como compilar (toolchain)

```
cd caravanblast
chmod +x build.sh ../cvbasic-repo/cvbasic ../gasm80-repo/gasm80   # ver §7.8!
./build.sh          # gera caravan-blast.asm e caravan-blast.nes
```

`build.sh` roda:
1. `/home/user/cvbasic-repo/cvbasic --nes caravan-blast.bas caravan-blast.asm`
2. `/home/user/gasm80-repo/gasm80 caravan-blast.asm -o caravan-blast.nes`

Sempre **confira se o tamanho do `.asm` mudou** após editar o `.bas`
(build silenciosamente velho já aconteceu — ver §7.8).

---

## 4. Mapa de arquivos

```
caravanblast/
├── caravan-blast.bas        ← FONTE PRINCIPAL (v0.6)
├── caravan-blast.asm/.nes   ← saída do build
├── build.sh
├── README.md                ← notas técnicas por versão (complementa este MD)
├── gera_logo_spaceblast.py  ← converte o title.png (128×48) → tiles/patch do .bas
├── cvbasic_nes_prologue.asm ← runtime do CVBasic (player de música: linhas
│                              ~1047-1530; zeropage $23-$4f: linhas 60-100)
├── assets/sprites/          ← PNGs originais (nave, inimigos, estrelas...)
├── docs/                    ← screenshots, GIFs, WAVs preview, logo reconstruído
├── music/                   ← compose.py/arranger.py (regenera os blocos PLAY),
│                              cb_title.mp3 / cb_stage1.mp3 (fontes das trilhas)
└── js/                      ← referências do jogo HTML5
cvbasic-repo/                ← compilador CVBasic v0.9.2 (binário + fontes)
gasm80-repo/                 ← montador gasm80 (binário + fontes)
nes-test/                    ← harness de testes emulados (ver §7.7)
uploads/                     ← artes enviadas pelo autor (title.png,
                               "exemplo de titulo.png", estrelas-cinzas.png)
```

---

## 5. Histórico de versões

### v0.1–v0.3 — gameplay base
- Onda 01 (smalls em formação com zigzag senoidal) e onda 02 (shards que
  descem e saem na diagonal), tiro mirado do inimigo, shard-bônus em anel.
- **Bugs de codegen CVBasic contornados** (ver §7.1): posições passaram a
  usar bias +256 e divisões por 16 via shift manual.
- Fundo de estrelas harmônico (48 setores de 4×5 células por nametable,
  1 estrela/setor; nametable 2 preenchida uma vez no boot).

### v0.4 — performance + primeiros ajustes visuais
- Tiros inimigos a 30Hz (meio step), cadência menor, anti-slowdown
  (99,7% do budget do frame).
- Logo antiga no título; controles aprovados pelo autor: "Agora eu
  realmente gostei."

### v0.5 / v0.5.1 — música
- Trilhas título/fase transcritas das MP3s via `music/compose.py`.
- **Bug**: "sons estranhos quando a nave atira no meio da música" → laser
  movido do canal SOUND 10 (pulso 1, a melodia) para **SOUND 11 (pulso 2)**.
- Player: `PLAY FULL` no boot, `PLAY mus_title`/`mus_stage1`,
  `PLAY OFF` no game over.

### v0.10 — estrelas de vez + Enemy4 turbinado
- **Regressão da v0.9 ("estrelas sumindo em bloco")**: o vizinho REAL do
  scroll vertical nesta ROM/fceumm é a **`$2800`** ($2400 = espelho da
  $2000 aqui; prova: `nes-test/probe_nt.bas` varrendo $2000/$2400/$2800).
  A v0.9 preencheu a NT errada. **Fix à prova de emulador**: mesma
  estrela nas TRÊS ($2000/$2400/$2800) + WAITs drenando o buffer da PPU
  (~21 VPOKEs/flush). Medido: pixels de estrela constantes (71–73) em
  TODO o ciclo de 240px (antes decaía 72→3).
- **Enemy4**: tiro era timer de 2,5s (morria antes 90% das vezes) →
  agora dispara ao cruzar **y 64–127** (faixa topo-meio); verificado:
  8/8 disparam em y=64. Onda com **8 naves a 0,5s** (arrays/OAM 41–56;
  colunas = 2 permutações embaralhadas, nunca repete seguida).
- **Colisão mata o inimigo** (dano = 1 tiro): small +100, shard +120
  (com anel de 8!), enemy4 +300 — mesmos efeitos do kill por bala.
- Suíte v08 (atualizada) TUDO OK; regressão SUITE OK. GIF
  `docs/space_blast_v10.gif`.

### v0.9 — loop perfeito das estrelas + Enemy4 mais rápido
- **Bug "o cenário muda as estrelas de lugar"**: cada `stars_fill` re-
  sorteava o layout (boot/título/begin_game), então as estrelas se
  rearranjavam a cada transição. (Diagnóstico emulado descartou wrap
  quebrado/nametable errada: o scroll em si sempre foi perfeito.)
- **Fix**: layout gerado 1× no boot (`stt(48)` + `#stw(48)`, +144B RAM),
  desenhado idêntico em `$2000` **e** `$2400` — funciona em qualquer
  modo de espelhamento. Verificado: 0 pixels de diferença após
  morrer→game over→título→novo jogo.
- Enemy4 (não chamar mais de "meteoro"!): `e4v` 10→**14**+wdif (~0,94–
  1,19 px/frame) — atravessa a tela ~40% mais rápido.
- Pausa entre ondas: `wpausa` 70→**30** frames (medido: gaps exatos de
  30f entre ondas).
- Testes: `nes-test/v09_estrelas*.py`, suite v08 TUDO OK, regressão
  SUITE OK. GIF: `docs/space_blast_v09_loop_estrelas.gif`.

### v0.8 — ajustes do meteoro + fim dos wraps de tela
- **HUD apagando**: placar/vidas são SPRITES nos slots OAM 34–39 e a v0.7
  pôs os meteoros nos 33–40 — colisão direta. Meteoros agora nos slots
  41–48. (Lição: placar/vidas NÃO são fundo; são sprites! ver
  `update_score`/`update_lives`.)
- Meteoro: sprite estático (CHR 392–395 só; -12 tiles), **atira 1×
  mirado** ~2,5s após entrar, velocidade por slot `base+RANDOM(5)-2`.
- **Anti-wrap alto/baixo/lados**: entrada pelo alto esconde o sprite
  enquanto `#pos < 4112`. Bug sutil: yc/yb (byte) nunca é <1 porque o
  negativo enrola — comparar SEMPRE o 16-bit (`#smy/#shy/#e4y < 4112`).
- Teste `nes-test/v08_ajustes.py` TUDO OK; regressão SUITE OK.

### v0.7 — novo inimigo: METEORO (Enemy4)
- Nova onda (3ª do rodízio small→shard→meteoro): 4 meteoros do
  `Enemy4.gif`, cruzam do alto à base devagar (~0,7px/frame), sem atirar,
  spawn a cada 1,5s, colunas 32/88/144/200 embaralhadas sem repetição.
  300 pts/kill. Tiles físicos 392–407, sprites OAM 33–40, pal0 (cinzas).
- **Bug corrigido**: em sprite 8×16 o byte de tile do OAM precisa ser
  ÍMPAR (bit0 = tabela de padrões; par = tabela do fundo → os meteoros
  apareceram como dígitos da fonte). Fórmula: `byte = 2×((fis-256)/2)+1`.
- Regressão completa OK; teste próprio `nes-test/v07_meteoro.py` TUDO OK.

### v0.6 — SPACE BLAST (tela de título nova)
Nome mudou para **Space Blast**; nova logo 128×48 (`uploads/title.png`)
e mockup de referência do autor (`uploads/exemplo de titulo.png`).

**Tela de título final (bate com o mockup, verificado pixel a pixel):**
- Logo nas linhas 6–11 (colunas 8–23 da nametable): "SPACE" branco,
  "BLAST!" ciano `$3C`=(160,232,255) com sombra teal `$1C`=(0,116,156)
  (tiles PATTERN 96–127 e 148–211; gerados por `gera_logo_spaceblast.py`).
- "APERTE START" branco puro piscando na linha 22 (`AT 714`), paleta pal2.
- Rodapé ciano "2026 • FALCON SOFT" na linha 27 (`AT 871`); a bala "•" é o
  tile custom 212 escrito com `VPOKE $236C` (**nametable 1!**).
- Paletas do título: pal0 = estrelas (azuis), pal1 = `$0F,$1C,$3C,$30`,
  pal2 = `$0F,$30,$30,$30`, pal3 = `$0F,$1C,$3C,$3C`.

**Bugs encontrados e corrigidos nesta versão:**
1. Bloco de atributos da logo ANTIGA sobrescrevia os novos (logo saía
   azul/cinza) — bloco velho removido; atributos novos reescritos a cada
   entrada na tela de título.
2. Bala "•" ia para a nametable 2 por engano (`$2876` → `$236C`).
3. O "apaga" do pisca-pisca usava a posição antiga (`AT 394` → `AT 714`).
4. Atributos do título vazavam para o gameplay (com as cores novas,
   apareceria uma faixa teal/ciano nas estrelas) — `begin_game` agora zera
   `$23C0–$23FF`.

---

## 6. Detalhes do hardware NES usados no jogo

### Layout do CHR (verificado despejando o .nes)
| Tiles | Conteúdo |
|---|---|
| 0–31 | sheet de estrelas (bits 1,2,3; tile 0 = vazio, usado pelo CLS) |
| 32–95 | fonte ASCII (PRINT escreve tile = código ASCII; glifos usam bits 2 e 3) |
| 96–121 | logo, linhas 0–1 (sobrepõe glifos minúsculos, nunca impressos) |
| 128–146 pares | dígitos do placar 0–9 (bit 3) |
| 148–211 | logo, linhas 2–5 |
| **212–275** | **livres** (212 = bala "•") |
| 276+ | nave do jogador |
| 364+ | inimigos |

### Atributos de cor (nametable)
- Byte de atributo = `$23C0 + linha*8 + coluna`, onde linha = py/32 e
  coluna = px/32; cada byte = 4 quads 16×16px (2×2 tiles):
  bits 0-1 = TL, 2-3 = TR, 4-5 = BL, 6-7 = BR (cada quad escolhe pal0–3).
- Texto usa os bits 2/3 do glifo → para cor uniforme faça idx2 = idx3
  na paleta da região.

### Paletas REais medidas no fceumm (a tabela "oficial" comum está ERRADA)
`$30`=(255,255,255)branco · `$12`=(56,56,255)azul · `$11`=(32,92,220) ·
`$21`=(76,160,255) · `$1C`=(0,116,156)teal · `$16`=(208,32,32)vermelho ·
`$25`=(255,100,184)rosa · `$3C`=(160,232,255)ciano claro (o mais próximo
do (0,228,255) do mockup) · `$00`=(108,108,108)cinza · `$1B/$0C`=(0,116,104).

### PPUBUF
~64 bytes ≈ **21 VPOKEs por frame**; para muitas escritas use `WAIT`
periódico ou `SCREEN DISABLE` (escrita direta) para não rasgar/perder
conteúdo.

---

## 7. Armadilhas conhecidas (leia antes de programar!)

### 7.1 Bugs de codegen do CVBasic-6502 (contornados no código)
1. Store em array 16-bit com multiplicação por constante clobbera o valor
   — por isso `#smy/#shy/#ebx/#eby` guardam `(coord+256)*16` e divisão /16
   vira shift (evita `_div16s`).
2. A MESMA var global 16-bit em 2+ comparações de um único IF gera código
   errado — quebre em IFs separados.
3. `READ var` com var 16-bit consome 2 bytes por DATA — sempre
   `READ BYTE x` + `DATA BYTE`.
4. Expressões computadas dentro de argumentos de VPOKE/tile podem colapsar
   em constante — em ROMs de teste, use literais.

### 7.2 CHRROM
`CHRROM 0` é OBRIGATÓRIO antes de qualquer `CHRROM PATTERN n`, senão:
"BITMAP used without choosing CHRROM table".

### 7.3 Player de música (regras duras)
- Tick = 50,0832 Hz; notas `A4#Y` (letra, oitava, sustenido, instrumento).
- Triângulo soa ~1 oitava abaixo; piso prático do baixo ≈ A2/110 Hz
  (hi-pass do fceumm corta abaixo disso).
- Nunca dê rest no pulso 2 enquanto o triângulo toca (rouba o clone);
  sem nota "Z" no triângulo; canal 1 evita bytes $FD/$FE.
- SFX de laser = **SOUND 11** (pulso 2) para não cortar a melodia (pulso 1).
- Blocos regeneráveis: `cd music && python3 compose.py`.

### 7.4 Nametables
O `CLS` do CVBasic só limpa a nametable 1 (`$2000`); a nametable 2
(`$2800`) persiste — por isso o fundo dela é preenchido uma vez no boot.
Cuidado: VPOKE `$2400+` é nametable 2!

### 7.5 Atributos persistem
A tabela de atributos **não** é limpa por CLS nem por troca de tela —
a tela de título regrava os seus e o `begin_game` zera tudo.

### 7.6 Compilação
- `cvbasic --nes` + `gasm80`. ROM final: 40.976 bytes (NROM).
- RAM usada: 288 de 1805 bytes; PRG ~16,2KB de 32KB (+5,3KB de música).

### 7.7 Testes (nes-test/)
- Core: `/tmp/fceumm_libretro.so` (**/tmp é apagado a cada sessão!**
  re-baixar: `curl -sL -o f.zip "https://buildbot.libretro.com/nightly/linux/x86_64/latest/fceumm_libretro.so.zip" && unzip f.zip`).
- Harness ctypes: env cmd 10 → pixel format 1 (XRGB8888), cmds 11/16/17 →
  True; frame 256×240; inputs {B:0, SEL:2, START:3, UP:4, DOWN:5, LEFT:6,
  RIGHT:7, A:8}; RAM via `retro_get_memory_data(2)` com `restype=c_void_p`
  e `from_address(2048)`.
- **Segfault comum #1**: declare `retro_load_game.argtypes/restype`
  (senão o ponteiro trunca). **#2**: guarde referência dos callbacks
  ctypes (senão o GC mata o trampoline e o core chama memória morta).
  ** #3**: em `ram_watch.py`, callbacks devem ser varáveis NOMEADAS.
- `addrs_cb.py` = mapa nome→endereço RAM gerado do `.asm`
  (`^(cvb_\w+|array_\w+):\s*equ \$(\w+)`) — **regere após cada build**!
- `teste_v04_full.py` = suíte de regressão completa (RGB + RAM + GIF).

### 7.8 Sprites 8×16 — byte de tile do OAM TEM que ser ÍMPAR
PPU roda com `$A8` (sprites 8×16, tabela sprite $1000). Em 8×16 o bit0 do
byte de tile no OAM escolhe a tabela (0 = `$0000`/fonte!, 1 = `$1000`) e
os 7 bits altos T usam o par (2T, 2T+1) da tabela. Mapeamento: tile físico
`f` (na metade alta 256–511 do CHR) → byte = `(f-256)+1` se par... use
sempre: `T = (f-256)/2` e **byte = 2T+1**, metade seguinte = byte+2.
Byte par = o sprite vira glifo da fonte na tela (bug vivido na v0.7).

### 7.9 Sessões/workspace (IMPORTANTE)
- O workspace (`/home/user/...`) persiste entre conversas, MAS:
  - **`chmod +x` some** dos binários (`build.sh`, `cvbasic`, `gasm80`) —
    primeiro comando de qualquer sessão: `chmod +x` nos 3. Um build com
    permissão negada pode falhar SILENCIOSAMENTE e gerar ROM velha:
    sempre cheque se o tamanho do `.asm` mudou.
  - `/tmp` é apagado (fceumm, caches pip e probes somem — reinstale/re-baixe).
  - `mock_nave.py` tem tabela de cores NES ERRADA — use a tabela medida
    em §6.

---

## 8. Próximos passos sugeridos (não iniciados)

1. Renomear arquivos do projeto `caravan-blast.*` → `space-blast.*`
   (autor foi consultado; opcional).
2. Melhorar músicas/arranjos (autor adiou: "ainda precisa melhorar muito").
3. Novas fases/ondas e o que mais o autor pedir, respeitando o congelamento
   atual das mecânicas.

---

## 9. Conteúdo deste backup (zip)

```
space_blast_backup_2026-07-29.zip
├── caravanblast/    ← projeto completo (fonte, assets, docs, music)
├── cvbasic-repo/    ← compilador CVBasic v0.9.2
├── gasm80-repo/     ← montador gasm80
├── nes-test/        ← harness de testes emulados
├── uploads/         ← artes enviadas pelo autor
└── HISTORICO.md     ← este arquivo (cópia)
```

## 31/jul (fora de versao): AUTOPSIA DO BUG DAS ESTRELAS — mecanismo identificado

O print do Saulo foi periciado pixel a pixel (scripts em /tmp, figura A/B/B em
nes-test/ab_limpo_vs_saulo_vs_selftest.png):

1. A grade anomala e' tile-locked 8x8 (captura 4:3: 20x16px/celula, razao 1.25 exata);
   cada celula = 1 glifo de 2 pontos (azul col 2, cinza col 4, linha 3) + as 48
   estrelas reais por cima. Fontes/HUD intactos (placar/vidas sao SPRITES).
2. Ceu do gameplay = NT cheia de tile $00 (BG base $0000); ceu do titulo/CLS =
   tile $20. A sombra do banco CHR ($1C) foi ELIMINADA como causa (falcon_splash
   e begin_stage sempre restauram $1C=0).
3. Causa: BYTES VIOLADOS na CHR-RAM pagina 0: 08@$0003 + 28@$000B (tile $00)
   e 08@$0203 + 28@$020B (tile $20). Nenhuma tabela estatica da ROM tem esses
   bytes -> escrita dinamica fora do lugar (na maquina do Saulo; fceumm limpo).
4. PROVA: injetar esses bytes (build selftest) reproduz o print 1:1 (908 vs 802
   celulas c/ traco; grade identica; gameplay/titulo ambos gradeados).
5. FERRAMENTA: space-blast-dbg.nes (builds por build-dbg.sh/faz_dbg.py) le
   $0000/$0200 (16B), $2000 (4B) e a sombra $1C, e imprime em hex no titulo
   (linhas 1-5) e no GAME OVER (linhas 24-28). A foto do Saulo vai dizer EM
   QUE TRECHO o escritor age (GO ja' quebrado = durante o gameplay; GO limpo +
   titulo quebrado = trecho go_draw/splash/logo).
6. CURA JA' DESENHADA (vai na v0.25 apos a confirmacao): regravar os 16 bytes
   zerados dos tiles $00/$0200 a cada stars_fill (32 VPOKEs; seguro ate' no
   boss_kill: arte do boss mora nos tiles 180-255 da pagina $1000).


---

## v0.25 (31/jul, pedido do Saulo): bug das estrelas MORTO — game over chama RESET

ROM `f25c88c6bf9861cde3007398041fa0f7` · ROM v0.25 em `space-blast.nes`

Saulo testou: o bug das estrelas (grade de pontinhos na fase 01 e no
título) só acontece no **Mesen**, só **depois de passar pelo game over**,
e qualquer reset do console cura. Recomendação dele: o game over chamar
um reset — "simples assim". Aceito e implementado:

- **Autópsia completa** (detalhes no bloco "31/jul (fora de versão)"
  acima): tile `$00`/`$20` da CHR-RAM página 0 com bytes violados
  (`08`@+3, `28`@+11) por escritor dinâmico pós-game-over; mecanismo
  reproduzido 1:1 no emu injetando esses bytes (selftest == print).
- **Cura:** `go_reset:` + `PLAY OFF` + `JMP ($FFFC)` = apertar o botão
  RESET por software. O boot regrava a CHR-RAM (`copy_chrram`) e refaz
  a RAM → os tiles voltam virgens. Fluxo visual idêntico ao de antes
  (GO → splash → título); nunca retorna ao código velho.
- Troca no `go_wait`: `GOTO restart_boot` ×2 virou `GOTO go_reset` ×2
  (o rótulo `restart_boot` do boot a frio continua igual).
- **Prova de ponta a ponta (fceumm):** injetar a corrupção exata do
  print → morte real (roxinho em cima da nave) → GO → START → reset →
  `LI:3 FASE:1`, `CHRR[0x0003]=00 CHRR[0x000B]=00`, `CHRR[0x0203]=00
  CHRR[0x020B]=00`. GIF `space-blast-v025.gif` (5 quadros legendados).
- Suites teste_v04_full / v08_ajustes / v12_fechamento / v13_boss2_v019:
  **4/4 verdes** na v0.25.
- Scroll da lava: **congelado na v0.24** a pedido do Saulo
  ("vamos deixar ele pra lá por enquanto"); o motor v0.24 segue no ar.
- Ferramenta de apoio mantida: `space-blast-dbg.nes` + `build-dbg.sh` +
  `faz_dbg.py` (dump hex dos tiles do céu no título e no game over) —
  guardada para eventual caça ao escritor fantasma, fora do caminho.


### v0.25b (mesmo dia): reset COMPLETO, exatamente como pedido

A pedido do Saulo, o go_reset virou reset integral de maquina antes do
salto: NMI off + video off ($2000/$2001), APU calada ($4015=0, $4017=$40
inibindo IRQ), loop STA ($00),Y zerando os 2KB de RAM (o ponteiro mora
em $00/$01 e se auto-zera sem dano: lo/hi ja estao nos valores certos),
pilha resetada (LDX #$FF TXS) e so entao JMP ($FFFC). Prova no emu com
bug injetado: morte -> GO -> START -> LI=3, FASE=1, tiles $00/$20
zerados. ROM f25c88c6bf9861cde3007398041fa0f7. Suites 4/4 verdes.


---

## v0.28 (01/ago, ordem do Saulo): AS 5 FASES + FIM DE JOGO

ROM de referência da implementação original: `8ac873400a4d8c15b4ad4dd2c5fea1d3`.
Base v0.27 aprovada. A ROM recompilada/consolidada está registrada no
bloco `v0.28 baseline` no início deste arquivo.

- Pedido: gerar todas as fases "no mesmo esquema" (scroll simples fase
  1, mesmos inimigos da fase 1, mesmo boss em todas); depois vêm os
  inimigos próprios. Fases: 01 A CAMINHO DO PLANETA DE FOGO (espaco),
  02 O PLANETA DE FOGO (nome corrigido!), 03 O CINTURAO DE ASTEROIDES
  (espaco; til/agudo da spritefont na linha acima da letra),
  04 O GERADOR DE ESCUDOS DE ATLANTIS (tiles da lava + paleta agua
  $0C/$11/$02/$01, contraste cuidado), 05 A BATALHA FINAL COM GORF
  (espaco). Pos-05: vitoria + creditos + "THE END?" -> fase 01.
- Implementado: stage_card e fase_completa genericos (PRINT <1>fase,
  subtitulo por fase); end_vitoria/end_creditos/end_theend (banco 1,
  mesmo estilo de fade das telas frias, START pula); fase1_clear
  generico (fase+1; fase 5 -> ending -> begin_game); SELECT cicla 1-5;
  agua_setup/agua_palette (banco 3, setup identico ao da lava = mesmo
  scroll perfeito); acentos em tiles 26/27/28 (CHRROM 0); POKE $1C,$00
  antes de textos pos-fase/game over (apos lava/agua a pagina ativa e'
  a 2); gate "IF fase = 1" do boss REMOVIDO (boss em todas as fases -
  CHR 256-511 da pagina 2 e' copia byte-identica da 0, provado no
  state dump: boss e sprites funcionam nas duas); boss na lava testado
  de verdade (nasce, morre, fase avanca).
- SAGA DO BANCO 0 (autopsia completa no asm): o novo codigo estourou o
  banco 0 em 97 bytes (TIMES negativo no gasm80). Descobertas sobre o
  UNROM-512 do CVBasic: "BANK SELECT n" grava 2n-2 no BANKSEL (1->0,
  3->2; BANK SELECT 0 grava 31); o banco 0 ocupa 32K com metade FIXA
  em $C000-$FFFA (fisico 31) = alcancavel de qualquer janela SEM
  wrapper (e' por isso que banco1->banco0 sempre funcionou sem
  SELECT!). Tentativa 1 (stars_fill p/ banco 3 + wrappers): titulo e
  begin_stage OK, mas boss_kill(banco1) -> stars_fill(banco3) TRAVAVA
  a CPU (boss morria e RENASCIA sem bsc=70 = kill nao completava).
  Regra empirica: chamada ANINHADA janela->janela quebra. Solucao
  final: anim_idle p/ o banco 1 (padrao mb_frame/boss_frame, quente e
  validado), stars_fill intacto no banco 0, refill do mar removido do
  boss_kill (boss = fim de fase; o begin_stage da proxima refaz tudo).
- Teste de tiro fabricado (bty/btx escritos na RAM em cima da caixa
  do boss: mata em 1 hit sem depender de mira) - virou ferramenta
  padrao p/ testar kills.
- Suite 13/13 verde (emu): titulo c/ estrelas, SELECT 2/3/4/5/1 com
  CHRRAM_BANK certo ($40 pares, $00 impares), scroll da agua, boss1 ->
  fase 2, boss2(lava) -> card FASE 03 (acentos OK) -> fase 3, ending 3
  telas -> volta fase 1 LI=3. Shot da fase 4: azul-agua, contraste ok.
- GIF space-blast-v028.gif: ciclo animado das 5 fases.
- A validação interna foi consolidada na suíte independente
  `nes-test/test_v028_baseline.py`; o veredito externo no Mesen/Everdrive
  continua pendente. Depois dele, e somente com aprovação, vêm inimigos
  próprios de cada fase e detalhes finais.

ROM `65a15b2b3e51bd04a2cad0a03abbb395`. Base v0.26 aprovada ("duas fases
certinhas, scrolls perfeitos — ponto de partida").

- Pedido: ilhas pequenas (4 tiles de 8x8) em algumas linhas p/ a fase
  ficar menos monótona, testando se o scroll continua perfeito.
- Implementado: 5 ilhotas por página (linhas 4/10/16/20/26, colunas
  pares), usando as 3 ilhas 2x2 do mapa original: A=108/109/110/111,
  B=119/153/154/155, C=149/150/151/152. MESMAS posições nas 3
  nametables (estilo fase 1: conteúdo estático, scroll só "gira").
  Novos labels lava_isl_a/b/c chamados ao fim de lava_sea_fill.
- Provas (fceumm): NT0 com exatamente 20 tiles != mar nas posições
  certas, estável após 300 frames (nada escreve no BG em runtime); as
  3 páginas iguais byte-a-byte nas ilhas; scroll 599/600 frames
  (medição com inimigos congelados p/ a nave não morrer — a morte
  pausa o scroll e contaminava a métrica: 560/600 era isso, não bug).
- Render dos tiles na paleta lava: ilhotas = pedras/cristais
  verde-azulados, discretas como no desenho original. GIF
  space-blast-v027.gif (1 ciclo vertical completo, tela limpa).
- Pendente: veredito do Saulo (densidade/visibilidade das ilhotas).

ROM `5dab7d5a2a47c512cb3dfc92a48fb22f`.

- Diretriz: esquecer investigação; fazer o que sempre deu certo. O scroll
  da lava vira EXATAMENTE o da fase 1: 3 nametables idênticas (mar de
  lava básico 96/97/98/99, textura 2x2 do próprio desenho) + paleta/CHR
  da lava. Sem ilhas/extras nesta rodada — detalhes vêm depois.
- Mudanças: lava_setup reescrito (3 x GOSUB lava_sea_fill: 960 VPOKEs
  por página, WAIT por linha); chamada de lava_tick comentada; motor de
  anel (lava_tick/lava_in/lava_strip(_w)/lava_wr/mapas) fica dormente
  no banco 3. Cabeçalho de versão atualizado.
- Medido: FASE=2 com $1C=$40; scroll 597/600 frames (velocidade plena,
  como a fase 1); GIF space-blast-v026.gif. Suites 4/4 verdes.
- v0.25 intacta: reset completo no game over segue resolvendo o bug
  das estrelas (Saulo confirmou no Mesen: "RESOLVEU completamente").
