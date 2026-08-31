BANK ROM 512	' v0.33: scroll de textos seguro; gameplay da v0.29 intacto
	' v0.29 candidate: limita lotes de VPOKE durante flashes/cenas de morte
	' para caber no VBlank; nenhuma mecanica ou arte foi alterada.
							' segue TODO no banco 0 (32K) como na v0.14; bancos
							' 1-28 livres p/ fases 2-5 + CHRROM 0-3 p/ tiles

	'
	' v0.28 (ordem do Saulo): AS 5 FACES + FIM DE JOGO. Mesmo esquema
	'   aprovado (scroll fase 1, mesmos inimigos, miniboss + boss iguais
	'   em todas): 01 A CAMINHO DO PLANETA DE FOGO (espaco), 02 O
	'   PLANETA DE FOGO (lava, nome corrigido!), 03 O CINTURAO DE
	'   ASTEROIDES (espaco; acentos por tile na linha acima da letra,
	'   til=tile 26 / agudo=tile 27 da spritefont), 04 O GERADOR DE
	'   ESCUDOS DE ATLANTIS (tiles da lava + paleta agua $0C/$11/$02/
	'   $01), 05 A BATALHA FINAL COM GORF (espaco). Cartao de fase e
	'   "FASE 0X COMPLETA" genericos (PRINT <1>fase). Vencendo a 05:
	'   telas de vitoria + creditos + "THE END?" e volta p/ a fase 01
	'   (partida nova). SELECT cicla 1>2>3>4>5>1 (debug). POKE $1C,$00
	'   antes dos textos pos-fase/game over (apos lava/agua a pagina
	'   ativa e' a 2 = fonte sairia quebrada).
	'
	' v0.27 (pedido do Saulo): ILHAS PEQUENAS na lava p/ quebrar a
	'   monotonia. So' ilhas 2x2 (4 tiles de 8x8: A=108/109/110/111,
	'   B=119/153/154/155, C=149/150/151/152), 5 por pagina nas MESMAS
	'   posicoes das 3 nametables -> o scroll estilo fase 1 continua
	'   perfeito (o conteudo so' "gira" na tela). Sem canhoes, sem
	'   eventos, sem anel. Teste: manter o scroll perfeito.
	'
	' v0.26 (ordem do Saulo): SCROLL DA FASE 2 = SCROLL DA FASE 1. O motor
	'   de anel (v0.19-v0.24) sai de campo: o que sempre funcionou foi o
	'   esquema da fase 1 (3 nametables identicas + scroll byte). lava_setup
	'   agora so' troca paleta/CHR ($1C=$40) e preenche as 3 paginas com o
	'   mar de lava basico (tiles 96/97/98/99 = a textura 2x2 do proprio
	'   desenho do Saulo). ZERO ilhas, canhoes, eventos e lava_tick
	'   (chamada comentada). Cadaver do anel fica dormente no banco 3.
	'
	' v0.25 (pedido do Saulo): RESET POR SOFTWARE NO GAME OVER. Pericia
	'   do bug das estrelas (figura A/B/B no HISTORICO): a grade = tile
	'   $00 (ceu do gameplay) e tile $20 (titulo) da CHR-RAM pagina 0
	'   com os bytes 08@3 / 28@11 violados por escritor dinamico so-
	'   no-Mesen (fceumm sai limpo); reset do console cura, porque o
	'   boot regrava a CHR-RAM inteira. Entao ao sair do game over o
	'   jogo aperta o proprio botao RESET: JMP ($FFFC) -> vetor ->
	'   START -> prologue -> copy_chrram -> tiles virgem. Fluxo visual
	'   identico (GO -> splash Falcon -> titulo), sintoma morto p/
	'   sempre, zero logica de cura paliativa. Scroll da lava fica
	'   CONGELADO na v0.24 por decisao do Saulo (retomamos depois).
	'
	' v0.24: TORUS DE 31 SLOTS (scroll da lava DEFINITIVO). A v0.23
	'   errou duas vezes ao "matar" os espelhos: (a) flip 8 frames cedo
	'   demais (slot do FUNDO ainda exibia a linha velha = ilhas
	'   mutiladas saindo); (b) $2800 NAO e' morta: o PPU troca p/ a NT
	'   vertical no coarse-Y 30 -> os ultimos (fine) px da tela leem
	'   $2800 slot 0 (a fase 1 sempre foi perfeita justamente porque
	'   suas 3 paginas identicas alimentam esse strip!). Motor final:
	'   flip do slot do TOPO no frame da costura (AND 7 = 7; conteudo
	'   nasce atomico com o 1px que espia no alto) + $2800 slot 0 =
	'   linha (topo+30) na fase 6 = "31o slot" do torus. Prova: NT/$
	'   2800 byte-a-byte == modelo em 1400 frames + strip visual liso.
	' v0.23: SCROLL DA LAVA CERTINHO COMO O DA FASE 1. Autopsia com o
	'   emulador: o scroll do jogo e' byte (0-239) e os NT bits do
	'   PPUCTRL sao SEMPRE 0 -> a tela e' um TORUS de 30 slots do $2000
	'   (as 30 linhas do anel estao todas visiveis; $2400/$2800 nunca
	'   sao lidas). O design 480px da v0.19 era impossivel assim: o
	'   #ld andava +32/linha enquanto o topo visivel anda -32/linha,
	'   e 64/70 writes caiam em slots VISIVEIS (ate' o MEIO da tela) =
	'   ilhas sumindo/surgindo (medido: tabela no HISTORICO.md). Fix:
	'   motor-vida-nova = escrever o slot do FUNDO no frame exato da
	'   costura (scroll_y AND 7 = 7), 32 writes num NMI so', linha-mundo
	'   DECREMENTANDO junto com o scroll (anel 60, wrap 0->59), fase
	'   travada na 1a costura a partir do scroll_y. Espelhos mortos.
	' v0.22: canhoes extirpados do DATA INLINE (o lava_layout.bas.inc
	'   era carta morta - NINGUEM o inclui!). Anel re-escrito: leitura
	'   sequencial c/ shadow 16-bit (r*32 em 8-bit corrompia tudo antes),
	'   linha replicada nas 3 paginas ($2000/$2400/$2800), 6 eventos de
	'   16 writes. Prova: janela circular perfeita + 0 tiles de canhao.
	' v0.20: fase 2 = fase 1 c/ cenario de lava. Canhoes removidos;
	'   stream do anel em quartos (16 writes/evento); PPUBUF $40->$90 no
	'   build.sh (burst estourava o buffer -> WRTVRM JMP wait -> frames
	'   perdidos -> fase lerda! medido: scroll 210/300 -> 598/600).
	' v0.19.2: SELECT alterna a fase (debug); fim do pulso de paleta do
	'   lava; clear_nts na volta p/ fase 1 (lixo do anel nas nametables).
	'   ATENCAO: FOR com TO > 254 nunca termina no CVBasic (8-bit wrap)!
	' v0.19: FASE 02 - PLANETA DE LAVA. Cerimonia pos-boss -> FASE 01
	'   COMPLETA -> cartao FASE 02 -> lava em anel de 60 meta-linhas com
	'   streaming dual-write ($2000+$2800, immune a mirroring divergente).
	'   Canhoes BG mirando o jogador; pulso $16/$17; inimigos reciclados.
	'   Gate fase=1 p/ score/vidas; START do game over volta a Falcon.
	'
	' v0.18 (pedido do Saulo): GAME OVER retocado + CARTAO DE FASE.
	'   "GAMEOVER" junto centralizado (tiles 214-221 em $214C-53); frases
	'   com 1 linha de espaco (linhas 10/12/14/16); tela de game over entra
	'   em FADE por palette cycling (rampa fade_tbl, mesma da Falcon). START
	'   no game over agora cai em begin_game -> stage_card -> jogo (retry
	'   direto, sem passar no titulo). stage_card: tela preta "FASE 01 / A
	'   CAMINHO DO PLANETA DE FOGO" central, fade-in, sai com START (corte
	'   seco) ou sozinha apos ~4s (com fade-out).
	'
	' v0.17 (pedido do Saulo): FONTE DO SAULO EM TUDO + HUD do placar no ar.
	'   Spritefont dele (uploads/Sprite_font.png) vira a fonte unica do jogo
	'   via CHRROM PATTERN 32 (sobrescreve a fonte default do CVBasic;
	'   pixels valor 3 = paleta identica). "apresenta"->"APRESENTA" (maiusc.,
	'   glifos 182-188 do CHRROM 1). "GAME OVER" usa os tiles estilizados
	'   214-221 da folha dele. HUD: placar/vidas liam tiles 128-147 = ARTE DA
	'   LOGO (sprites 8x16, byte OAM par -> tabela $0000! bug desde o v0.15,
	'   provado com captura) -> digitos reais agora nos pares 192-211
	'   (codigo: +128 virou +192). Gerador: gera_fonte.py.
	'
	' v0.16 (feedback do Saulo): SPLASH FALCON SOFT + acertos do titulo.
	'   (a) Splash no boot: logo oficial da Falcon (128x80, veio "montada"
	'   num PNG separado - a folha Falconsoft.png 128x48 estava desmontada
	'   p/ aproveitar tiles; a montagem nossa bateu ~90% antes de chegar a
	'   oficial). Vai numa CHRROM 1 PROPRIA = CHRRAM pagina 1 (POKE $1C,$20
	'   = BANKSEL bits 5-6 do CHR-RAM; o NMI restaura ORA CHRRAM_BANK a
	'   cada frame), 86 tiles unicos (96-181) + 7 glifos da fonte CVBasic
	'   (182-188) p/ "apresenta" minusculo. Entrada/saida com FADE POR
	'   PALETTE CYCLING nos entries $3F02/$3F03 (7 passos x 4 frames:
	'   0F,0F->0F,00->00,00->00,10->10,10->10,20->10,30). Qualquer botao
	'   corta DIRETO p/ o titulo; senao ~3.4s e transicao suave igual.
	'   Game over volta p/ title_screen SEM splash (hook so no boot).
	'   (b) Logo do titulo NOVA (title-space.png do Saulo, sem a barra de
	'   katakana do Caravan Blast): SPACE branco/cinza (pal1), cometa teal
	'   (pal3), BLAST vermelho/vermelho-escuro (pal2), estrelas soltas.
	'   92 tiles unicos contiguos 96-187 (bullet 212 intacto), paletas
	'   escolhidas por quad 16x16 com ZERO colisao de cores (medido), e os
	'   atributos gerados por script (gera_title2.py).
	'   (c) "APERTE START" todo branco: o RT (e o ER de APERTE) caiam em
	'   quads do pal0 = idx3 $00 = cinza escuro (o PRINT usa sempre idx3).
	'   Bytes de atributo corrigidos: BL/BR das colunas 10-21 -> pal2.
	'   (d) Estrelas do fundo SUBSTITUIDAS pelas da folha nova (25 tiles,
	'   dots de ate 6px com corrida <=3) - patterns 1-25, mesma convencao
	'   de indices (teal->1 branco->2 cinza->3) = mesmo look azulado.
	'   (e) Boot sem flash cinza: 2 patches no prologue via build.sh
	'   (video so liga no SCREEN ENABLE + $3F00=$0F antes da copia do CHR;
	'   medido no fceumm: 17 frames cinza -> 3 de deteccao NTSC).
	'   Validacao: v12 17/17, v13 boss, v08 mini/HUD, v04 full = TUDO OK;
	'   game over conferido; skip com botao generico (A) no frame 77.
	'   Rodape do titulo agora sai branco (pal3 virou teal do cometa).

	'
	' SPACE BLAST - port NES (CVBasic) da demo HTML5 de Saulo San
	' Baseado nos assets/logica originais (saulosan.com.br/caravanblast)
	'
	' v0.13 (feedback do Saulo): (a) o boss.png era um SPRITESHEET de 2
	'   frames (96x64 cada), NAO 2 naves gemeas! Boss = UMA nave 96x64
	'   NO ALTO, 100% Background: ceu todo preto + tiles na tabela $1000
	'   com flip da ppu_ctrl ($B8) so durante a luta (sprites 8x16 leem a
	'   tabela pelo bit0 do byte OAM: nada afetados). "Animacao" = PULSO
	'   DE PALETA (ideia do autor: cor clara $38 cicla 38/28/18/28).
	'   Balanco lateral classico de chefe-de-BG: SCROLL x fino +-16px
	'   (ceu preto = wrap invisivel); tiros/laser/hitbox acompanham.
	'   (b) BUG DOS TEXTOS da v0.12 explicado: PRINT escreve o codigo
	'   ASCII DIRETO como tile - a FONTE mora nos tiles 32-95 da $0000,
	'   exatamente onde a arte do boss tinha ido parar! (e caiu tambem o
	'   tile 0 do $1000: ceu preto virou grade 2.0). Arte realocada p/
	'   $1000 (257+, 272+, 436-511 = ex-asas); fonte 100% restaurada.
	'   (c) duas armadilhas do codegen CVBasic mapeadas: byte var >=128
	'   sign-extende ao ir p/ var 16-bit (#tbx 143 -> -113!), e somar o
	'   byte-wrap 240 ("-16") em 16-bit vira +240. Resolvido com #bo.
	' v0.12: fechamento da fase 01! (a) smalls: cota de MAX 3 tiros deles
	'   na tela (tags ebt + contador nsm no eb_spawn/despawn). (b) mini-
	'   boss agora para em y=72 e solta o LASER (arte do Saulo) que desce
	'   rapido ao cruzar o meio exato (centro x=128: nasce e parqueia
	'   em mbx=112). (c) BOSS 96x128 do
	'   Saulo a cada 4 ondas-de-cada-tipo: hibrido BG (centro 48x128 +
	'   strips, 102 tiles unicos $0000) + sprites (asas: 18 tiles $1000,
	'   lado dir = flip H) - sprite puro era inviavel: 12 sprites por
	'   scanline, limite do NES e 8! Fases: leques alternados das asas,
	'   saraivada de posicoes/velocidades variadas, 3 lasers do meio;
	'   tudo com trava no pool de 8 tiros. HP 120, +5000. Scroll congela
	'   (boss e BG); pal BG1/pal2 ganham $03/$23/$38 e voltam na morte.
	'   (d) tiro do player = nova arte do Saulo (fis 472/474, 217/219);
	'   pal3 agora ciano ($1C/$3C/$30) p/ tiro+laser ficarem fi as artes.
	' v0.12a (bug da grade): a arte BG do boss usava os tiles 32-95 do
	'   banco $0000 - MAS o 32 ($20) e o byte que a CVBasic preenche a
	'   nametable no boot (e o "espaco" do PRINT), e em branco na v0.11!
	'   Todo o fundo "vazio" virou uma grade de pedacinhos do boss.
	'   Forense: pixel-match do screenshot -> tile fis 32. Remapeada a
	'   arte p/ 33-95 + 213-251 (gera_boss.py); o 32 voltou a ser vazio.
	' v0.11: onda dos smalls (roxo) agora e 3+3: o 2o grupo entra logo
	'   apos o 1o, no lado OPOSTO da tela (slots/OAM ampliados: smalls
	'   0-5, sprites 4-15; por isso tiros->16-20, shards->21-24, tiros
	'   inimigos->25-32, explosao->33/34, placar->35-39, vidas->40).
	'   MINIBOSS NOVO (arte do Saulo, 32x32, 2 frames, tiles 396-427):
	'   1 a cada 4 ondas; entra pelo topo, desce ate o meio e patrulha
	'   esq/dir lancando aneis de 8 tiros (so dispara qdo o pool de
	'   tiros inimigos esvazia = trava anti-slowdown); HP 48, +500 pts.
	'   Usa os slots OAM 41-48 do enemy4 (nunca coexistem). Durante a
	'   luta pal2 ganha as cores da arte ($03/$23/$38) e volta ao
	'   normal ao morrer (chama da nave fica roxa nesse periodo).
	' v0.10: estrelas de vez! Diagnostico definitivo (probe + medicao no
	'   fceumm): o vizinho de scroll vertical da $2000 nesta ROM e a $2800
	'   (a $2400 e ESPELHO da $2000 aqui). A v0.9 preencheu a $2400 (no-op)
	'   e deixou a $2800 vazia = faixa sem estrelas cruzando a tela.
	'   Solucao a prova de emulador: layout unico gravado nas TRES ($2000,
	'   $2400 e $2800). Enemy4: atira ao cruzar a faixa topo-meio (y 64-
	'   127) em vez de timer; onda com 8 naves a 0.5s (arrays/OAM 41-56);
	'   colisao nave-inimigo DESTROI o inimigo (1 tiro de dano: small+100,
	'   shard+120 c/ anel, enemy4+300).
	' v0.9: fundo de estrelas com LOOP PERFEITO (a raiz do bug: a "NT2" era
	'   escrita em $2800, que no espelhamento "vertical arrangement" da ROM
	'   e ESPELHO da $2000; a vizinha real do wrap vertical e a $2400, que
	'   nunca tinha sido preenchida!). Agora o layout e sorteado 1x no boot
	'   e desenhado byte a byte igual nas 2 nametables ($2000/$2400).
	'   Enemy4 (ex-"meteoro") mais rapido: e4v 10 -> 14 (+jitter por slot).
	'   Pausa entre ondas 70 -> 30 frames (jogo mais desafiador).
	' v0.8: ajustes no enemy4: sprite ESTATICO (economiza 12 tiles CHR),
	'   agora ATIRA 1x (mirado, ~2.5s apos entrar), velocidade levemente
	'   variada por slot, sprites movidos p/ 41-48 (33-39 eram o HUD de
	'   sprites = placar/vidas, por isso "apagavam"!), e guarda ANTI-WRAP:
	'   enemy4/shard/small escondidos enqto y<1 (nao nascem mais embaixo).
	' v0.7: novo inimigo ENEMY4 (Enemy4.gif do autor): onda de 4 naves que
	'   cruzam a tela do alto a base bem devagar (movimento de meteoro),
	'   spawn 1.5s, cada uma numa das 4 colunas (32/88/144/200) embaralhadas
	'   sem repeticao. Rodizio: small -> shard -> enemy4. 300 pts.
	' v0.6: SPACE BLAST - novo nome + nova tela de titulo (logo 128x48 do
	'   autor: SPACE branco, BLAST! ciano/teal, APERTE START branco piscando,
	'   rodape ciano "2026 • FALCON SOFT"). Atributos da titulo reescritos a
	'   cada entrada; begin_game zera a tabela de atributos (heranca visual).
	' v0.5: TRILHAS SONORAS - arranjos NES das MP3 originais (titulo ~96bpm
	'   G#m e fase 1 ~174bpm Gm) gerados por music/compose.py p/ o player do
	'   CVBasic (PLAY FULL: pulso1=melodia, pulso2=arp, triangulo=baixo,
	'   ruido=bateria). Titulo toca mus_title; jogo toca mus_stage1; game
	'   over silencia. Performance medida: 99.7% do frame budget com musica.
	'
	' v0.2: corrige tiros inimigos (posicao nunca gravada p/ bug de codegen do
	'   *16 em array 16-bit + mira com sinal quebrado), shard sumindo ao cruzar
	'   x=128 (overflow 8-bit sinal na saida diagonal), 3 smalls/onda com frame
	'   estatico, e divisoes /16 rapidas (posicoes com bias +256, sem _div16s).
	' v0.1: inicio do game - ondas 01 (small formation) e 02 (shard formation)
	' Direcional: move a nave. Botao B (segurar): rajada de 5 tiros.
	' Start: inicia. Vidas: 3.
	'
	' Compilar:  cvbasic --nes space-blast.bas space-blast.asm
	' Montar:    gasm80 space-blast.asm -o space-blast.nes
	'

	DIM st(64)		' tabela seno (zigzag dos smalls)
	DIM boff,bdir,bpf	' BOSS: balanco lateral (+-16px), direcao, fase do pulso
	DIM rr,q1,q2,q3,q4	' v0.14: rodizio OAM anti-flicker (Saulo) (k ja' existe: eb_spawn)
	DIM diek			' v0.15: proc bancado pede morte da nave (GOTO externo proibido)
	DIM r16(16)		' anel de slots fisicos (v0.14): smalls 0-11, shards 12-15
	DIM shyc(4)		' v0.14: cache px do y dos shards (anel desenha todo frame)
	DIM gbc			' contador do sky_clear (60 passos)
	DIM #bk			' cursor de varredura do ceu preto (sky_clear)
	DIM #bo			' boff com SINAL em 16 bits (p/ #tbx: byte >=128
						' sign-extendia: asa dir. cuspia tiro em x=-113!)
	DIM nep(23)		' tiles de estrela nao-vazios (sorteio harmonico)
	DIM stt(48)		' layout de estrelas (gerado 1x no boot): tile por setor
	DIM #stw(48)		' layout de estrelas: offset do setor na nametable (0-959)
	DIM fase,bsc,ph,sy,srq,wr,wrf,ring(32)	' v0.23: fase atual, anel lava=linha-
							'   mundo da costura + trava de fase, contador cerimonia
	DIM r,q,e2		' scratch do fundo de estrelas / mapa da logo
	DIM sk			' indice do layout de estrelas
	DIM btx(5)		' tiros do player: x
	DIM bty(5)		' tiros do player: y (0 = livre)
	DIM sma(6)		' smalls: ativo? (v0.11: 6 slots p/ onda 3+3)
	DIM smx(6)		' smalls: x
	DIM #smy(6)		' smalls: (y+256)*16 (sempre positivo = /16 rapida!)
	DIM smz(6)		' smalls: fase do zigzag (0-63)
	DIM smp(6)		' smalls: x central do zigzag
	DIM smc(6)		' smalls: amplitude do zigzag
	DIM smd(6)		' smalls: timer do tiro
	DIM smf(6)		' smalls: tiros dados
	DIM snv(6)		' smalls: velocidade y (1/16 px/frame)
	DIM smyy(6)		' v0.14: cache do y em pixel (anel desenha todo frame)
	DIM sha(4)		' shards: ativo?
	DIM shx(4)		' shards: x
	DIM #shy(4)		' shards: (y+256)*16 (sempre positivo)
	DIM shf(4)		' shards: fase (0 desce, 1 sai na diagonal)
	DIM shvx(4)		' shards: vx da saida (+2/-2)
	DIM e4a(8)		' enemy4: ativo?
	DIM e4x(8)		' enemy4: x
	DIM #e4y(8)		' enemy4: (y+256)*16
	DIM e4p(8)		' enemy4: colunas embaralhadas (2 permutacoes de 4)
	DIM e4v			' enemy4: velocidade base de descida (1/16 px/frame)
	DIM e4w(8)		' enemy4: velocidade individual (base + jitter)
	DIM e4f(8)		' enemy4: 1 = ainda nao atirou (atira ao cruzar y=64)
	DIM eba(8)		' tiros inimigos: ativo?
	DIM ebt(8)		' tiros inimigos: dono (1 = small) - cota v0.12
	DIM #ebx(8)		' tiros inimigos: (x+256)*16
	DIM #eby(8)		' tiros inimigos: (y+256)*16
	DIM ebxv(8)		' tiros inimigos: vx (1/16)
	DIM ebyv(8)		' tiros inimigos: vy (1/16)
	DIM xb,yc		' scratch de pixel p/ sprites
	DIM k			' indice do eb_spawn (nao pode usar c!)
	DIM #c1,#c2		' scratch assinado p/ colisoes
	DIM #t1,#t2		' pixel biased dos tiros inimigos (div reuse)
	DIM s0,s1,s2,s3,s4	' placar em digitos (10000..1), sem divisoes!

	SIGNED ebxv,ebyv,shvx,e,#tbx,#tby,#ad,#adx,#ady,#c1,#c2,#t1,#t2

	RESTORE sintab
	FOR c = 0 TO 63
		READ BYTE st(c)	' READ puro le 16 bits (2 DATA por vez) e corrompe a tabela!
	NEXT c
	RESTORE nep_tab
	FOR c = 0 TO 22
		READ BYTE nep(c)
	NEXT c
	RESTORE oam_ring
	FOR c = 0 TO 15
		READ BYTE r16(c)
	NEXT c

	GOSUB silence
	PLAY FULL		' habilita o player de musica (MOD=5). music_tick roda no NMI.

	' Layout das estrelas gerado 1x aqui no boot: as 2 nametables do scroll
	' recebem EXATAMENTE o mesmo desenho = loop perfeito. A vizinha visivel
	' no wrap vertical e a $2400 (a $2800 e espelho da $2000 neste modo de
	' espelhamento - era ai que morava o bug do "cenario trocando de lugar").
	sk = 0
	FOR r = 0 TO 5
		FOR q = 0 TO 7
			stt(sk) = nep(RANDOM(23))
			#tw = r * 5 + RANDOM(5)
			#tw = #tw * 32 + q * 4 + RANDOM(4)
			#stw(sk) = #tw
			sk = sk + 1
		NEXT q
	NEXT r

	'
	' TELA DE TITULO
	'
	' v0.16: splash FALCON SOFT (so no boot; game over volta direto
	' p/ title_screen sem passar aqui)
	restart_boot:			' v0.19: START no game over volta ao INICIO do jogo
	BANK SELECT 1
	GOSUB falcon_splash
	BANK SELECT 0

title_screen:
	BANK SELECT 2		' v0.15: PLAY grava o banco (le $BFFF) p/ o player do NMI
	PLAY mus_title		' trilha da apresentacao (loop)
	CLS
	PALETTE LOAD game_palette_title
	SCREEN DISABLE
	GOSUB stars_fill

	' Logo SPACE BLAST (128x48): tiles linhas 6-11, colunas 8-23
	' v0.16: art nova (sem katakana), paletas por quad, estrelas da folha nova
	RESTORE logo_map
	FOR i = 0 TO 95
		READ BYTE e
		IF e <> 255 THEN
			#tw = i / 16 + 6
			#tw = #tw * 32
			e2 = i AND 15
			#tw = #tw + e2 + 8
			VPOKE $2000 + #tw, e
		END IF
	NEXT i

	' Atributos v0.16: pal1=SPACE, pal2=BLAST, pal3=cometa; pal0=estrelas.
	VPOKE $23CA,$70		' logo rows 6-7
	VPOKE $23CB,$50
	VPOKE $23CC,$D0
	VPOKE $23CD,$F0
	VPOKE $23D2,$BB		' logo rows 8-11
	VPOKE $23D3,$AA
	VPOKE $23D4,$AA
	VPOKE $23D5,$EE
	VPOKE $23EA,$90		' "APERTE START" (py176-183) -> pal2 = BRANCO em tudo
	VPOKE $23EB,$A8
	VPOKE $23EC,$A8
	VPOKE $23ED,$A8
	VPOKE $23F1,$C0		' rodape (py216-223, quads inf.) -> pal3
	VPOKE $23F2,$F0
	VPOKE $23F3,$F0
	VPOKE $23F4,$F0
	VPOKE $23F5,$F0
	VPOKE $23F6,$30
	WAIT			' drena o buffer da PPU (escritas demais perdem!)
	SCREEN ENABLE

	PRINT AT 714,"APERTE START"
	PRINT AT 871,"2026   FALCON SOFT"
	VPOKE $236C,188		' "•" central do rodape (NT1: AT 871+5 = 876)

title_wait:
	' v0.30: o loop de espera e a historia ficam no banco 1; o banco 0
	' conserva somente a troca de banco; a historia termina em reset completo.
	BANK SELECT 1
	GOSUB title_idle_wait
	BANK SELECT 0
	IF sk = 0 THEN GOTO begin_game
	GOTO go_reset

	'
	' INICIO DO JOGO
	'
begin_game:
	fase = 1			' v0.19: partida nova = sempre fase 1
	BANK SELECT 1		' v0.18: cartao "FASE 01" antes de comecar (banco 1)
	GOSUB stage_card
	BANK SELECT 0
begin_stage:			' v0.19: entrada de fase sem cartao (a dela ja passou)
	BANK SELECT 2		' v0.15: idem (trilha no banco 2)
	PLAY mus_stage1		' trilha da fase 1 (loop)
	CLS

	' Fundo (v0.28): fases impares = espaco / 2 = LAVA / 4 = AGUA (banco 3)
	SCREEN DISABLE
	IF (fase AND 1) = 0 THEN	' fases pares: 2 = lava, 4 = agua
		BANK SELECT 3		' tiles da lava/agua moram no banco 3
		IF fase = 2 THEN GOSUB lava_setup
		IF fase = 4 THEN GOSUB agua_setup
		BANK SELECT 0
	ELSE
		PALETTE LOAD game_palette_play
		POKE $1C,$00		' espaco = pagina 0 do CHR-RAM
		' v0.19.2: lava deixa lixo no $2000/$2800 (stars_fill so toca
		' slots com tile 0); zera as tres paginas (proc mora no banco 1)
		BANK SELECT 1
		GOSUB clear_nts
		BANK SELECT 0
	END IF
	FOR i = 0 TO 63		' zera atributos herdados da tela de titulo
		VPOKE $23C0 + i,0	' (das 3 nametables!)
		VPOKE $27C0 + i,0
		VPOKE $2BC0 + i,0
	NEXT i
	WAIT			' drena o buffer da PPU antes de mais escritas
	IF (fase AND 1) = 1 THEN GOSUB stars_fill	' v0.28: so no espaco
	SCREEN ENABLE

	IF fase = 1 THEN		' v0.19.1: placar/vidas sobrevivem a troca de fase
		s0 = 0
		s1 = 0
		s2 = 0
		s3 = 0
		s4 = 0
		GOSUB update_score
		li = 3
		GOSUB update_lives
	END IF

	px = 120		' posicao da nave
	py = 200
	dir = 0
	ret = 0
	an = 0
	slot = 0
	inv = 0			' invencibilidade (pisca)
	ded = 0			' tempo da animacao de morte
	FOR c = 0 TO 4
		bty(c) = 0
	NEXT c
	FOR c = 0 TO 5
		sma(c) = 0
	NEXT c
	FOR c = 0 TO 3
		sha(c) = 0
	NEXT c
	mba = 0			' miniboss: inativo (v0.11)
	mbw = 0			' onda atual NAO e a do miniboss
	mbt = 0			' cooldown do anel do miniboss
	nsm = 0			' tiros de small na tela (cota de 3 - v0.12)
	mlr = 0			' laser do miniboss desligado
	bsa = 0			' boss inativo
	bsw = 0			' onda atual NAO e a do boss
	bol = 0			' laser do boss desligado
	boff = 0		' balanco lateral do boss (signed em byte)
	bdir = 0
	bpf = 0
	bsc = 0			' v0.19.2: zera cerimonia (troca de fase via SELECT)
	nsma = 0		' ondas de cada tipo (p/ chamar o boss: 4 de cada)
	nsha = 0
	ne4 = 0
	FOR c = 0 TO 7
		e4a(c) = 0
		eba(c) = 0
		ebt(c) = 0
	NEXT c
	mbxo = 112		' mbx do frame anterior (deteccao do cruzamento)
	FOR c = 0 TO 63		' esconde todos os sprites
		SPRITE c,$f0,0,0,0
	NEXT c
	GOSUB update_score
	GOSUB update_lives
	bn = 0			' rajada atual (tiro vermelho nv1)
	cad = 0			' cadencia dentro da rajada
	cool = 0		' descanso entre rajadas
	mpt = 0			' timer da mini-explosao
	#pew = 0
	#pop = 0

	' Gerenciador de ondas
	wnum = 0		' ondas completadas
	wtipo = 0		' 0 = small, 1 = shard, 2 = enemy4
	wact = 0		' 1 = onda em andamento
	wpausa = 30		' pausa antes da proxima onda (v0.9: era 40)
	wdif = 0		' dificuldade (0-3)
	qn = 0			' inimigos restantes p/ nascer na onda
	wflip = 0		' lado da formacao shard

	scroll_y = 0
	SCROLL 0, 0

	'
	' LOOP PRINCIPAL
	'
game_loop:
	WAIT

	' v0.19.2: SELECT = troca de fase p/ testes (debug do Saulo)
	' v0.28: cicla 1>2>3>4>5>1
	IF CONT1.KEY = 10 THEN
		fase = fase + 1
		IF fase > 5 THEN fase = 1
		PLAY OFF
		GOTO begin_stage
	END IF

	' v0.19: cerimonia pos-boss (estrobo + explosoes repetidas no lugar
	' dele); ao fim, sai do loop p/ a sequencia de transicao de fase
	IF bsc > 0 THEN
		bsc = bsc - 1
		IF (FRAME AND 4) = 0 THEN VPOKE $3F00,$30 ELSE VPOKE $3F00,$0F
		IF (bsc AND 15) = 0 THEN
			mpt = 12
			mpx = 96 + RANDOM(48)
			mpy = 40 + RANDOM(40)
			#pop = 12
		END IF
		IF bsc = 0 THEN GOTO fase1_clear
	END IF

	' v0.14: gira o rodizio OAM (flicker rotativo no lugar de
	' sprites sumindo DEFINITIVO quando >8 por scanline)
	rr = rr + 1
	IF rr >= 16 THEN rr = 0

	' Fundo rolando p/ baixo (congela durante o BOSS: ele e desenhado
	' como Background eletrostatico - v0.12)
	IF bsa = 0 THEN
		scroll_y = scroll_y - 1
		IF scroll_y = $ff THEN scroll_y = $ef
		SCROLL 0, scroll_y
		IF fase = 2 THEN	' v0.19.1: todo o ciclo da lava mora no banco 3
			BANK SELECT 3
			' GOSUB lava_tick	' v0.26: motor de anel aposentado (scroll = fase 1)
			BANK SELECT 0
		END IF
	ELSE
		' v0.13: boss BALANCA p/ os lados (classico chefe-de-BG do NES;
		' ceu todo preto = o wrap horizontal nunca aparece)
		IF (FRAME AND 1) = 0 THEN
			IF bdir = 0 THEN
				boff = boff + 1
				IF boff = 16 THEN bdir = 1
			ELSE
				boff = boff - 1
				IF boff = 240 THEN bdir = 0	' -16 em byte
			END IF
		END IF
		' boff com sinal em 16 bits p/ os calculos de #tbx
		IF boff >= 128 THEN
			#bo = boff - 256
		ELSE
			#bo = boff
		END IF
		SCROLL boff,0
		' "animacao" do spritesheet por PULSO DE PALETA (ideia do Saulo):
		' a cor clara $38 acende/apaga (38/28/18/28, ciclo de ~1s)
		bpf = bpf + 1
		IF bpf = 14 THEN VPOKE $3F07,$28
		IF bpf = 28 THEN VPOKE $3F07,$18
		IF bpf = 42 THEN VPOKE $3F07,$38
		IF bpf = 56 THEN VPOKE $3F07,$28
		IF bpf >= 56 THEN bpf = 0
	END IF

	' (sem animacao no fundo: so o SCROLL acima rola as estrelas)

	' --- Movimento + animacao da nave (PANIM fiel ao original) ---
	IF ded = 0 THEN
		IF CONT1.LEFT THEN IF px > 8 THEN px = px - 2
		IF CONT1.RIGHT THEN IF px < 232 THEN px = px + 2
		IF CONT1.UP THEN IF py > 24 THEN py = py - 2
		IF CONT1.DOWN THEN IF py < 208 THEN py = py + 2

		IF CONT1.LEFT THEN
			IF CONT1.RIGHT THEN
				BANK SELECT 1	' v0.28: anim_idle mora no banco 1
				GOSUB anim_idle
				BANK SELECT 0
			ELSE
				IF dir <> 1 THEN
					dir = 1
					ret = 0
					an = 0
				END IF
				IF an < 26 THEN an = an + 1
				IF an < 4 THEN
					slot = 4
				ELSEIF an < 8 THEN
					slot = 5
				ELSEIF an < 12 THEN
					slot = 6
				ELSE
					slot = 7 + ((an - 12) / 5) % 4
				END IF
			END IF
		ELSEIF CONT1.RIGHT THEN
			IF dir <> 2 THEN
				dir = 2
				ret = 0
				an = 0
			END IF
			IF an < 26 THEN an = an + 1
			IF an < 4 THEN
				slot = 4
			ELSEIF an < 8 THEN
				slot = 5
			ELSEIF an < 12 THEN
				slot = 6
			ELSE
				slot = 7 + ((an - 12) / 5) % 4
			END IF
		ELSE
			BANK SELECT 1	' v0.28: anim_idle mora no banco 1
			GOSUB anim_idle
			BANK SELECT 0
		END IF

		' Desenha a nave (esquerda = H-FLIP da direita, como no original)
		IF inv > 0 THEN inv = inv - 1
		fb = 21 + slot * 8
		IF (inv AND 4) <> 0 THEN
			SPRITE 0,$f0,0,0,0
			SPRITE 1,$f0,0,0,0
			SPRITE 2,$f0,0,0,0
			SPRITE 3,$f0,0,0,0
		ELSEIF dir = 1 THEN
			SPRITE 0,py - 1,px + 4,fb + 4,$41
			SPRITE 1,py - 1,px + 4,fb + 6,$42
			SPRITE 2,py - 1,px,fb + 2,$40
			SPRITE 3,py - 1,px + 8,fb,$40
		ELSE
			SPRITE 0,py - 1,px + 4,fb + 4,1
			SPRITE 1,py - 1,px + 4,fb + 6,2
			SPRITE 2,py - 1,px,fb,0
			SPRITE 3,py - 1,px + 8,fb + 2,0
		END IF

		' --- Tiro vermelho nv1: rajada de 5 (3f entre tiros, 16f de gap) ---
		IF CONT1.BUTTON THEN
			IF bn = 0 AND cool = 0 THEN bn = 5
			IF bn > 0 AND cad = 0 THEN
				d = 0
				WHILE d < 5
					IF bty(d) = 0 THEN
						btx(d) = px + 4
						bty(d) = py - 6
						#pew = 5
						bn = bn - 1
						cad = 3
						IF bn = 0 THEN cool = 16
						d = 5
					ELSE
						d = d + 1
					END IF
				WEND
			END IF
		ELSE
			bn = 0
		END IF
	END IF
	IF cad > 0 THEN cad = cad - 1
	IF cool > 0 THEN cool = cool - 1

	' --- Tiros do player subindo ---
	FOR c = 0 TO 4
		IF bty(c) <> 0 THEN
			bty(c) = bty(c) - 4
			IF bty(c) < 8 THEN
				bty(c) = 0
				SPRITE 16 + c,$f0,0,0,0
			ELSE
				SPRITE 16 + c,bty(c) - 1,btx(c),217 + ((FRAME / 4) AND 1) * 2,3
			END IF
		END IF
	NEXT c

	' --- Gerenciador de ondas ---
	IF wact = 0 THEN
		IF wpausa > 0 THEN wpausa = wpausa - 1
		IF wpausa = 0 THEN
			' BOSS: chamado quando TODAS as ondas ja passaram >= 4 vezes
			btry = 0
			IF nsma >= 4 THEN	' v0.28: MESMO boss em TODAS as fases
				IF nsha >= 4 THEN
					IF ne4 >= 4 THEN btry = 1
				END IF
			END IF
			IF btry THEN
				' --- Onda do BOSS (v0.12) ---
				BANK SELECT 1			' v0.15: boss_start mora no banco 1
				GOSUB boss_start
				wact = 1
			ELSE
			IF (wnum AND 3) = 3 THEN
				' --- Onda do MINIBOSS: 1 a cada 4 ondas (interludio) ---
				' (v0.11) entra pelo topo, desce ate o meio, patrulha
				' esq/dir lancando aneis de 8 tiros; morre com 48 tiros
				mbw = 1
				mba = 1
				mbs = 1			' estado: descendo
				mbhp = 48		' HP (constante p/ ajuste fino)
				mbx = 112
				#mby = 3584		' (-32 + 256) * 16
				mbdir = RANDOM(2)
				mbt = 90		' 1.5s de graca antes do 1o anel
				' pal2 vira a paleta da arte do miniboss (roxo/lilas/
				' dourado = $03/$23/$38, cores exatas do PNG do Saulo;
				' efeito colateral temporario: a chama da nave fica
				' roxa durante a luta; restaurada no mb_kill)
				VPOKE $3F19,$03
				VPOKE $3F1A,$23
				VPOKE $3F1B,$38
				wact = 1
			ELSE
			mbw = 0
			IF wtipo = 0 THEN
				qn = 6
				qdel = 20	' onda small (v0.11): 6 naves em 2 grupos
				' de 3 (0.45s entre elas); o 2o grupo entra SEGUIDO
				' do 1o, no lado OPOSTO da tela = tela mais cheia
				c = RANDOM(2)
				colx = c * 170 + 43	' lado A: 43 (esq) ou 213 (dir)
				colb = 256 - colx	' lado B: o oposto
				nsma = nsma + 1	' conta p/ o gatilho do boss (v0.12)
				wact = 1
			ELSE
				IF wtipo = 1 THEN
				' formacao shard: 4 em coluna, lado alternado
				FOR c = 0 TO 3
					sha(c) = 1
					shf(c) = 0
					#shy(c) = 3840 - c * 256	' (-16 + 256)*16, degraus de 16px
					shyc(c) = 240		' v0.14: cache px (240+ = escondido na entrada)
					IF wflip THEN
						shx(c) = 205	' 0.8 * 256
					ELSE
						shx(c) = 51	' 0.2 * 256
					END IF
				NEXT c
				wflip = 1 - wflip
				nsha = nsha + 1	' conta p/ o gatilho do boss (v0.12)
				wact = 1
				ELSE
				' formacao enemy4: 8 naves (0.5s entre elas), 4 colunas
				' (32/88/144/200) em 2 permutacoes embaralhadas; coluna
				' nunca repete em spawns seguidos = nunca coladas
				qn = 8
				qdel = 30	' 1o enemy4 surge em 0.5s
				e4v = 14 + wdif	' descida (1/16 px/frame); v0.9: era 10
				ne4 = ne4 + 1	' conta p/ o gatilho do boss (v0.12)
				FOR c = 0 TO 7
					e4p(c) = c AND 3
				NEXT c
				FOR c = 0 TO 2
					d = c + RANDOM(4 - c)	' Fisher-Yates metade 1
					e = e4p(c)
					e4p(c) = e4p(d)
					e4p(d) = e
				NEXT c
				FOR c = 4 TO 6
					d = c + RANDOM(8 - c)	' Fisher-Yates metade 2
					e = e4p(c)
					e4p(c) = e4p(d)
					e4p(d) = e
				NEXT c
				IF e4p(4) = e4p(3) THEN	' fronteira nao repete coluna
					e = e4p(4)
					e4p(4) = e4p(5)
					e4p(5) = e
				END IF
				wact = 1
				END IF
			END IF
			END IF
			END IF
		END IF
	ELSE
		IF qn > 0 THEN
		IF mbw = 0 AND bsw = 0 THEN	' ondas de mini/boss nao spawnam
			qdel = qdel - 1
			IF qdel = 0 THEN
				IF wtipo = 2 THEN
					c = 8 - qn
				ELSE
					c = 6 - qn
				END IF
				IF wtipo = 2 THEN
					e4a(c) = 1
					e = e4p(c) * 56		' colunas 32/88/144/200 (evita
					e4x(c) = 32 + e		' mult. dentro do store do array)
					#e4y(c) = 3840		' (-16 + 256) * 16
					e4w(c) = e4v + RANDOM(5) - 2	' velocidade levemente variada
					e4f(c) = 1		' ainda nao atirou (atira ao cruzar y=64)
					qn = qn - 1
					IF qn > 0 THEN qdel = 30	' 0.5s entre enemy4
				ELSE
					sma(c) = 1
					IF c < 3 THEN		' grupo A (lado sorteado)
						d = colx
					ELSE				' grupo B (lado oposto)
						d = colb
					END IF
					smp(c) = d
					smc(c) = 16 + RANDOM(13)	' amplitude 16-28
					smz(c) = 32			' comeca cruzando o centro
					smx(c) = d
					#smy(c) = 3840		' (-16 + 256) * 16
					smyy(c) = 240		' v0.14: cache px (240+ = escondido na entrada)
					smd(c) = 40 + RANDOM(26)
					smf(c) = 0
					snv(c) = 11 + wdif * 2
					qn = qn - 1
					IF qn > 0 THEN qdel = 27
				END IF
			END IF
		END IF
		END IF
	END IF

	' --- Smalls (zigzag descendente, frame estatico, atiram 2 mirados) ---
	' --- Smalls (zigzag descendente, frame estatico, atiram 2 mirados) ---
	' v0.14 (Saulo: slowdown nas ondas 3+3 = CPU, medido no emulador!):
	' metade dos smalls ATUALIZA por frame (passo dobrado = mesma veloci-
	' dade, mesma tecnica dos tiros inimigos) e a posicao de pixel fica em
	' CACHE (smyy) p/ desenhar todo frame no slot do anel sem repetir a
	' divisao /16. Timer do tiro anda TODO frame (mesmo ritmo do v0.13).
	FOR c = 0 TO 5
		k = c + c + rr
		IF k > 15 THEN k = k - 16
		q1 = r16(k)
		k = k + 1
		IF k > 15 THEN k = 0
		q2 = r16(k)
		IF sma(c) <> 0 THEN
			' tique do timer do tiro: todo frame, na posicao cacheada
			yb = smyy(c)
			IF smf(c) < 2 THEN
				IF yb > 4 THEN
					IF yb < 200 THEN
						smd(c) = smd(c) - 1
					END IF
				END IF
			END IF
			' atualizacao dividida: metade dos smalls por frame
			IF (c AND 1) = (FRAME AND 1) THEN
				#smy(c) = #smy(c) + snv(c)
				#smy(c) = #smy(c) + snv(c)
				smz(c) = smz(c) + 2
				' Zigzag fluido: offset = ((seno * amp) / 128) - amp, somado ao centro.
				' (/256 shift rapido + *2 = /128 com erro <1px, muito mais barato)
				#tw = st(smz(c) AND 63)
				#tw = (#tw * smc(c)) / 256
				#tw = #tw * 2
				#tw = #tw + smp(c) - smc(c)
				smx(c) = #tw
				yb = #smy(c) / 16 - 256		' y real (wrap p/ negativos)
				smyy(c) = yb	' cache p/ os frames sem atualizacao
				IF #smy(c) >= 7904 THEN		' (238+256)*16: escapou por baixo
					sma(c) = 0
				ELSE
					' Tiro mirado (ate 2)
					IF smf(c) < 2 THEN
						IF smd(c) = 0 THEN
							' cota v0.12: no MAXIMO 3 tiros de small na tela;
							' se cheia, espera e tenta de novo em 12 frames
							IF nsm < 3 THEN
								smf(c) = smf(c) + 1
								smd(c) = 44 + RANDOM(28)
								#tbx = smx(c) + 4
								#tby = yb + 8
								#adx = px + 8
								#adx = #adx - (smx(c) + 8)
								#ady = py + 8
								#ady = #ady - (yb + 8)
								GOSUB aim_8dir
								ebs = 1
								GOSUB eb_spawn
							ELSE
								smd(c) = 12
							END IF
						END IF
					END IF
					IF yb < 224 THEN		' so interage dentro da tela
						' Encostou na nave?
						IF ded = 0 AND inv = 0 THEN
							#c1 = px
							#c1 = #c1 - smx(c)
							IF ABS(#c1) < 12 THEN
								#c2 = py
								#c2 = #c2 - yb
								IF ABS(#c2) < 12 THEN
									' colisao = 1 tiro de dano no small tambem
									sma(c) = 0
									e = 1
									d = 0
									GOSUB score_add
									#pop = 8
									mpt = 10
									mpx = smx(c)
									mpy = yb
									GOTO player_dies
								END IF
							END IF
						END IF
						' Levou tiro? (janelas byte, sem ABS = rapido)
						FOR d = 0 TO 4
							IF bty(d) <> 0 THEN
								IF btx(d) + 6 > smx(c) AND btx(d) < smx(c) + 14 THEN
									IF bty(d) + 8 > yb AND bty(d) < yb + 16 THEN
										bty(d) = 0
										SPRITE 16 + d,$f0,0,0,0
										sma(c) = 0
										e = 1
										d = 0
										GOSUB score_add
										#pop = 8
										mpt = 10
										mpx = smx(c)
										mpy = yb
										d = 5
									END IF
								END IF
							END IF
						NEXT d
					END IF
				END IF
			END IF
		END IF
		' slot do anel escrito SEMPRE (vivo desenha do cache; morto, em
		' entrada pelo alto ou saida por baixo = esconde). Byte do y
		' cacheado enrola p/ 240+ na entrada pelo alto = esconde tambem.
		IF sma(c) <> 0 THEN
			IF smyy(c) >= 240 THEN
				SPRITE q1,$f0,0,0,0
				SPRITE q2,$f0,0,0,0
			ELSE
				SPRITE q1,smyy(c) - 1,smx(c),113,1
				SPRITE q2,smyy(c) - 1,smx(c) + 8,115,1
			END IF
		ELSE
			SPRITE q1,$f0,0,0,0
			SPRITE q2,$f0,0,0,0
		END IF
	NEXT c

	' --- Shards (mergulho rapido; ao morrer soltam anel de 8 tiros) ---
	' v0.14: metade por frame (passo dobrado = mesma velocidade) e y em
	' pixel no cache shyc p/ desenhar todo frame no anel sem /16 extra
	FOR c = 0 TO 3
		k = 12 + c + rr
		IF k > 15 THEN k = k - 16
		q3 = r16(k)
		IF sha(c) <> 0 THEN
			IF (c AND 1) = (FRAME AND 1) THEN
				IF shf(c) = 0 THEN
					#shy(c) = #shy(c) + 64 + wdif * 8
					IF #shy(c) >= 7712 THEN	' (226+256)*16: chegou embaixo
						shf(c) = 1
						IF shx(c) < 128 THEN
							shvx(c) = 2	' sai p/ direita
						ELSE
							shvx(c) = -2	' sai p/ esquerda
						END IF
					END IF
				ELSE
					' 16-bit em 2 passos: shx+shvx em 8-bit estourava o sinal
					' (x >= 128 virava negativo e o shard sumia no meio da tela!)
					#ad = shx(c)
					#ad = #ad + shvx(c)
					#ad = #ad + shvx(c)
					' NOTA: nunca repetir a mesma global 16-bit em 2+ comparacoes
					' de um mesmo IF (bug de codegen: o TYA da 2a comparacao vem
					' sujo e a condicao avalia errado). Por isso: um teste por IF.
					wa = 0
					IF #ad < 1 THEN wa = 1	' esq: mata ANTES do wrap (byte nunca
					IF #ad > 255 THEN wa = 1	' recebe valor negativo e estoura p/ 255!)
					IF #shy(c) < 3840 THEN wa = 1	' saiu todo por cima
					IF wa <> 0 THEN
						sha(c) = 0
					ELSE
						shx(c) = #ad
						#shy(c) = #shy(c) - 64
					END IF
				END IF
				IF sha(c) <> 0 THEN
					yc = #shy(c) / 16 - 256	' y real
					shyc(c) = yc	' cache p/ os frames sem atualizacao
					IF #shy(c) >= 4096 THEN		' y real >= 0 (nao e wrap)
						' Encostou na nave?
						IF ded = 0 AND inv = 0 THEN
							#c1 = px
							#c1 = #c1 + 4 - shx(c)
							IF ABS(#c1) < 10 THEN
								#c2 = py
								#c2 = #c2 + 4 - yc
								IF ABS(#c2) < 10 THEN
									' colisao = 1 tiro de dano no shard tambem
									sha(c) = 0
									e = 1
									d = 2
									GOSUB score_add
									#pop = 8
									mpt = 10
									mpx = shx(c) - 4
									mpy = yc - 4
									#tbx = shx(c) + 4
									#tby = yc + 4
									GOSUB spawn_ring
									GOTO player_dies
								END IF
							END IF
						END IF
						' Levou tiro? -> ANEL DE 8 TIROS (igual ao original!)
						' (janelas byte: shard longe das bordas p/ somas nao enrolarem)
						IF yc < 224 AND shx(c) >= 8 AND shx(c) <= 240 THEN
							FOR d = 0 TO 4
								IF bty(d) <> 0 THEN
									IF btx(d) + 8 > shx(c) AND btx(d) < shx(c) + 8 THEN
										IF bty(d) + 8 > yc AND bty(d) < yc + 8 THEN
											bty(d) = 0
											SPRITE 16 + d,$f0,0,0,0
											sha(c) = 0
											e = 1
											d = 2
											GOSUB score_add
											#pop = 8
											mpt = 10
											mpx = shx(c) - 4
											mpy = yc - 4
											#tbx = shx(c) + 4
											#tby = yc + 4
											GOSUB spawn_ring
											d = 5
										END IF
									END IF
								END IF
							NEXT d
						END IF
					END IF
				END IF
			END IF
		END IF
		' slot do anel escrito SEMPRE (cache; regras de esconde idem v0.13)
		IF sha(c) <> 0 THEN
			IF #shy(c) < 4112 THEN	' (1+256)*16: entrada pelo alto enrola
				SPRITE q3,$f0,0,0,0	' o byte do y p/ 192+ = NAO pode usar
			ELSE				' shyc>=240 p/ esconder (cobre ate y=-64)!
				' esconde durante wrap de x (-8..-1) na saida p/ esquerda:
				' senao o sprite pisca na borda direita por alguns frames
				IF shvx(c) < 0 AND shx(c) > 240 AND shf(c) = 1 THEN
					SPRITE q3,$f0,0,0,0
				ELSE
					SPRITE q3,shyc(c) - 1,shx(c),125 + ((FRAME / 4) AND 3) * 2,2
				END IF
			END IF
		ELSE
			SPRITE q3,$f0,0,0,0
		END IF
	NEXT c

	' --- Enemy4: cruza do alto a base (descida de meteoro); atira 1x mirado ---
	' v0.14: metade por frame (passo dobrado = mesma velocidade; o loop com
	' 8 Enemy4 era o MAIOR slowdown medido do v0.13: ~10% dos frames!),
	' slots fixos 41-56 como sempre (fora do anel: prioridade classica)
	FOR c = 0 TO 7
		IF e4a(c) <> 0 THEN
			IF (c AND 1) = (FRAME AND 1) THEN
				#e4y(c) = #e4y(c) + e4w(c)
				#e4y(c) = #e4y(c) + e4w(c)
				yc = #e4y(c) / 16 - 256		' y real
				IF #e4y(c) >= 7904 THEN		' (238+256)*16: escapou por baixo
					e4a(c) = 0
					SPRITE 41 + c * 2,$f0,0,0,0
					SPRITE 42 + c * 2,$f0,0,0,0
				ELSE
					' Tiro unico mirado ao cruzar a faixa topo-meio (y 64-127):
					' antes era timer de 2.5s e 90% morria sem atirar (v0.10)
					IF e4f(c) <> 0 THEN
						IF yc >= 64 THEN
							IF yc < 128 THEN
								e4f(c) = 0
								#tbx = e4x(c) + 4
								#tby = yc + 8
								#adx = px + 8
								#adx = #adx - (e4x(c) + 8)
								#ady = py + 8
								#ady = #ady - (yc + 8)
								GOSUB aim_8dir
								ebs = 0
								GOSUB eb_spawn
							END IF
						END IF
					END IF
					IF #e4y(c) < 4112 THEN	' entrando pelo alto: esconde
						SPRITE 41 + c * 2,$f0,0,0,0	' p/ nao aparecer embaixo
						SPRITE 42 + c * 2,$f0,0,0,0
					ELSE
					' 2 sprites 8x16, 1 frame estatico (byte OAM IMPAR! bit0=1 ->
					' tabela $1000; 137 = T68 -> tiles fis. 392/393; pal0 = meteorito)
					SPRITE 41 + c * 2,yc - 1,e4x(c),137,0
					SPRITE 42 + c * 2,yc - 1,e4x(c) + 8,139,0
					END IF
					IF yc < 224 THEN		' so interage dentro da tela
						IF ded = 0 AND inv = 0 THEN
							#c1 = px
							#c1 = #c1 - e4x(c)
							IF ABS(#c1) < 12 THEN
								#c2 = py
								#c2 = #c2 - yc
								IF ABS(#c2) < 12 THEN
									' colisao = 1 tiro de dano no enemy4 tambem
									e4a(c) = 0
									SPRITE 41 + c * 2,$f0,0,0,0
									SPRITE 42 + c * 2,$f0,0,0,0
									e = 3
									d = 0
									GOSUB score_add
									#pop = 8
									mpt = 10
									mpx = e4x(c)
									mpy = yc
									GOTO player_dies
								END IF
							END IF
						END IF
						' Levou tiro? (janelas byte: colunas longe das bordas)
						FOR d = 0 TO 4
							IF bty(d) <> 0 THEN
								IF btx(d) + 6 > e4x(c) AND btx(d) < e4x(c) + 14 THEN
									IF bty(d) + 8 > yc AND bty(d) < yc + 16 THEN
										bty(d) = 0
										SPRITE 16 + d,$f0,0,0,0
										e4a(c) = 0
										SPRITE 41 + c * 2,$f0,0,0,0
										SPRITE 42 + c * 2,$f0,0,0,0
										e = 3		' 300 pontos (igual ao medA do original)
										d = 0
										GOSUB score_add
										#pop = 8
										mpt = 10
										mpx = e4x(c)
										mpy = yc
										d = 5
									END IF
								END IF
							END IF
						NEXT d
					END IF
				END IF
			END IF
		END IF
	NEXT c

	' --- Miniboss (v0.11: 32x32, entra pelo topo, desce ate o meio, ---
	' patrulha esq/dir e lanca aneis de 8 tiros, tipo o shard ao morrer)
	IF mba THEN
		BANK SELECT 1
		GOSUB mb_frame			' v0.15: bloco moveu p/ proc (banco 1 no mapper 30)
		IF diek THEN			' proc pediu morte da nave
			diek = 0
			GOTO player_dies
		END IF
	END IF

	' --- BOSS (v0.12): 96x128 = centro em BG + asas em sprite; ------
	' fases: 1) leques de 3 alternando as asas; 2) saraivada p/ baixo
	' de posicoes/velocidades variadas; 3) laser do meio 3x; repete ---
	IF bsa THEN
		BANK SELECT 1
		GOSUB boss_frame		' v0.15: bloco moveu p/ proc (banco 1 no mapper 30)
		IF diek THEN
			diek = 0
			GOTO player_dies
		END IF
	END IF

	' --- Tiros inimigos: metade por frame (passo dobrado = mesma velocidade) ---
	FOR c = 0 TO 7
		IF eba(c) <> 0 THEN
			IF (c AND 1) = (FRAME AND 1) THEN
				#ebx(c) = #ebx(c) + ebxv(c)
				#eby(c) = #eby(c) + ebyv(c)
				#ebx(c) = #ebx(c) + ebxv(c)
				#eby(c) = #eby(c) + ebyv(c)
				' fora da tela? (matar antes do wrap do byte: x em [-4,252], y em [-8,224])
			IF #ebx(c) < 4032 OR #ebx(c) > 8128 OR #eby(c) > 7680 OR #eby(c) < 3968 THEN
				IF ebt(c) = 1 THEN
					nsm = nsm - 1		' saiu tiro de small: libera a cota
					ebt(c) = 0
				END IF
				eba(c) = 0
				SPRITE 25 + c,$f0,0,0,0
				ELSE
					' 2 divisoes por tiro (reuso p/ desenho E colisao)
					#t1 = #ebx(c) / 16
					#t2 = #eby(c) / 16
					xb = #t1 - 256
					yc = #t2 - 256
					SPRITE 25 + c,yc - 1,xb,133 + ((FRAME / 4) AND 1) * 2,3
					IF ded = 0 AND inv = 0 THEN
						' janela (px-4, px+12) em escala "real+256" = (px+252, px+268)
						' (um teste por IF: ver nota do codegen no shard)
						#c1 = px
						#c1 = #c1 + 252
						IF #t1 >= #c1 THEN
							#c1 = px
							#c1 = #c1 + 268
							IF #t1 < #c1 THEN
								#c2 = py
								#c2 = #c2 + 252
								IF #t2 >= #c2 THEN
									#c2 = py
									#c2 = #c2 + 268
									IF #t2 < #c2 THEN
										GOTO player_dies
									END IF
								END IF
							END IF
						END IF
					END IF
				END IF
			END IF
		END IF
	NEXT c

	' --- Mini-explosao de morte de inimigo ---
	IF mpt > 0 THEN
		SPRITE 33,mpy - 1,mpx,13,3
		SPRITE 34,mpy - 1,mpx + 8,15,3
		mpt = mpt - 1
		IF mpt = 0 THEN
			SPRITE 33,$f0,0,0,0
			SPRITE 34,$f0,0,0,0
		END IF
	END IF

	' --- Fim da onda? ---
	IF wact <> 0 AND qn = 0 THEN
		e = sma(0) + sma(1) + sma(2) + sma(3) + sma(4) + sma(5)
		e = e + sha(0) + sha(1) + sha(2) + sha(3)
		e = e + e4a(0) + e4a(1) + e4a(2) + e4a(3)
		e = e + e4a(4) + e4a(5) + e4a(6) + e4a(7)
		e = e + mba
		e = e + bsa
		IF e = 0 THEN
			wact = 0
			wpausa = 30			' v0.9: era 70 (jogo mais desafiador)
			wnum = wnum + 1
			wtipo = wtipo + 1		' cicla 0 (small) -> 1 (shard) -> 2 (enemy4)
			IF wtipo >= 3 THEN wtipo = 0
			wdif = wnum / 2
			IF wdif > 3 THEN wdif = 3
		END IF
	END IF

	' Som do tiro (subindo de tom) - no PULSO 2: divide canal so com o arpejo
	' (antes era SOUND 10 = pulso 1 = mesmo canal da melodia => picotava ela)
	IF #pew > 0 THEN
		SOUND 11,$0800 + 200 + #pew * 40,$89
		#pew = #pew - 1
		IF #pew = 0 THEN SOUND 11,,$10
	END IF

	' Som de destruicao (ruido decaindo)
	IF #pop > 0 THEN
		SOUND 14,$e6 + (#pop AND 1),$13 + #pop / 2
		#pop = #pop - 1
		IF #pop = 0 THEN SOUND 14,,$10
	END IF

	GOTO game_loop

	'
	' v0.19: FASE 01 COMPLETA -> fade -> cartao FASE 02 -> begin_stage
	'
fase1_clear:
	VPOKE $3F00,$0F		' fim do estrobo
	POKE $1C,$00		' v0.28: cartoes/textos saem da pagina 0
	BANK SELECT 1
	GOSUB fase_completa
	IF fase = 5 THEN	' v0.28: GORF vencido = FIM DE JOGO
		GOSUB end_vitoria
		GOSUB end_creditos
		GOSUB end_theend
		BANK SELECT 0
		GOTO go_reset		' depois do THE END? volta ao splash com reset completo
	END IF
	fase = fase + 1
	GOSUB stage_card	' v0.28: cartao generico (usa a var fase)
	BANK SELECT 0
	GOTO begin_stage

	'
	' A NAVE EXPLODIU
	'
player_dies:
	ded = 40
	li = li - 1
	GOSUB update_lives
	SOUND 10,,$10
	SOUND 11,,$10
death_loop:
	WAIT
	e = py - 1 + RANDOM(5) - 2
	d = px + RANDOM(5) - 2
	SPRITE 0,$f0,0,0,0	' esconde canopy/chama
	SPRITE 1,$f0,0,0,0
	SPRITE 2,e,d,13,3	' explosao no lugar do corpo
	SPRITE 3,e,d + 8,15,3
	SOUND 14,$e4 + (ded AND 3),$1d
	IF (ded AND 8) = 0 THEN
		PALETTE 0,$10
	ELSE
		PALETTE 0,$0f
	END IF
	ded = ded - 1
	IF ded <> 0 THEN GOTO death_loop

	GOSUB silence
	PALETTE 0,$0f
	SPRITE 2,$f0,0,0,0
	SPRITE 3,$f0,0,0,0

	IF li > 0 THEN
		' Respawn embaixo no centro, invencivel por 1.5s
		px = 120
		py = 200
		dir = 0
		ret = 0
		an = 0
		slot = 0
		inv = 90
		GOTO game_loop
	END IF

	FOR c = 0 TO 63		' esconde todos os sprites
		SPRITE c,$f0,0,0,0
	NEXT c

	' v0.13: morreu DURANTE o boss? devolve a tabela $0000 ANTES de
	' imprimir os textos (senao a fonte sai da tabela errada!)
	IF bsa THEN
		ASM LDA #$A8
		ASM STA ppu_ctrl
		bsa = 0
		bsw = 0
		bol = 0
		boff = 0
	END IF

	PLAY OFF		' para a musica no game over
	POKE $1C,$00		' v0.28: texto do GO sai da pagina 0 (apos lava/agua)
	CLS
	SCROLL 0,0
	PALETTE LOAD game_palette_title
	WAIT			' separa a carga da paleta dos attrs (limite do NMI)
	FOR i = 0 TO 39		' zera attrs das linhas 0-4 (se morreu no boss)
		VPOKE $23C0 + i,0
		IF i = 31 THEN WAIT	' no maximo 32 escritas por VBlank
	NEXT i
	WAIT
	VPOKE $23D2,$40		' "GAME OVER"  -> pal1 (branco)
	VPOKE $23D3,$50
	VPOKE $23D4,$50
	VPOKE $23D9,$04		' "PONTOS/ONDA" -> pal1
	VPOKE $23DA,$45		' + "APERTE START" (quads inf.)
	VPOKE $23DB,$55
	VPOKE $23DC,$55
	VPOKE $23DD,$10
	WAIT

	BANK SELECT 1		' v0.18: desenho+fade do game over mora no banco 1
	GOSUB go_draw
	BANK SELECT 0
go_wait:
	WAIT
	IF (FRAME AND 16) = 0 THEN
		PRINT AT 458,"APERTE START"
	ELSE
		PRINT AT 458,"            "
	END IF
	IF CONT1.KEY = 11 THEN GOTO go_reset	' v0.25: reset de software!
	IF CONT1.BUTTON THEN GOTO go_reset
	GOTO go_wait

go_reset:				' v0.25: game over = RESET COMPLETO (pedido do Saulo)
	' Zera os 2KB de RAM, zera PPU/APU, reseta a pilha e salta p/ o vetor
	' de reset ($FFFC) = volta ao inicio do programa, tudo zerado.
	PLAY OFF
	ASM LDA #$00
	ASM STA $2000
	ASM STA $2001
	ASM STA $4015
	ASM LDA #$40
	ASM STA $4017
	ASM TAY
	ASM STA $00
	ASM STA $01
	ASM LDX #$08
	ASM go_reset_zap:
	ASM STA ($00),Y
	ASM INY
	ASM BNE go_reset_zap
	ASM INC $01
	ASM DEX
	ASM BNE go_reset_zap
	ASM LDX #$FF
	ASM TXS
	ASM JMP ($FFFC)

	'
	' Sub-rotinas
	'
silence:	PROCEDURE
	SOUND 10,,$10
	SOUND 11,,$10
	SOUND 14,,$10
	END

	' (v0.28: anim_idle mora no banco 1 - ver antes da FONTE SAULO.)

	' v0.28: QUEM saiu do banco 0 p/ dar folga foi o anim_idle (banco 1,
	' mesmo padrao do mb_frame/boss_frame). stars_fill FICA aqui: ele
	' cai na metade FIXA ($C000+) do banco 0, que e' alcancavel de
	' qualquer janela SEM wrapper (banco 0 estourou 97B com as 5 fases).
stars_fill:	PROCEDURE	' desenha o layout do boot nas TRES nametables
	' ($2000, $2400, $2800). Por que 3? A vizinha de scroll vertical da
	' $2000 depende do espelhamento que o emulador aplica p/ o byte6=0:
	' no fceumm/medido aqui e a $2800 (a $2400 e espelho da $2000!); no
	' hardware/emuladores "de manual" seria a $2400. Escrevendo nas duas
	' (uma das escritas sempre e no-op por ser a mesma RAM) o loop de 240px
	' fica perfeito em QUALQUER caso. Layout: malha de 48 setores 4x5
	' (1 estrela/setor: nunca aglomera, nunca deixa buraco).
	' Lacos separados por WAIT: o buffer de escrita da PPU drena ~21 VPOKEs
	' pendentes por NMI; escrever demais de uma vez PERDE escritas.
	FOR sk = 0 TO 47
		VPOKE $2000 + #stw(sk), stt(sk)
		IF sk = 31 THEN WAIT
	NEXT sk
	WAIT
	FOR sk = 0 TO 47
		VPOKE $2400 + #stw(sk), stt(sk)
		IF sk = 31 THEN WAIT
	NEXT sk
	WAIT
	FOR sk = 0 TO 47
		VPOKE $2800 + #stw(sk), stt(sk)
		IF sk = 31 THEN WAIT
	NEXT sk
	WAIT
END

update_score:	PROCEDURE	' placar em sprites (o fundo esta rolando!)
	SPRITE 35,16,$c0,s0 * 2 + 192,0
	SPRITE 36,16,$c8,s1 * 2 + 192,0
	SPRITE 37,16,$d0,s2 * 2 + 192,0
	SPRITE 38,16,$d8,s3 * 2 + 192,0
	SPRITE 39,16,$e0,s4 * 2 + 192,0
	END

score_add:	PROCEDURE	' e = centenas, d = dezenas a somar (chama update_score)
	s2 = s2 + e
	s3 = s3 + d
	WHILE s3 > 9
		s3 = s3 - 10
		s2 = s2 + 1
	WEND
	WHILE s2 > 9
		s2 = s2 - 10
		s1 = s1 + 1
	WEND
	WHILE s1 > 9
		s1 = s1 - 10
		s0 = s0 + 1
	WEND
	IF s0 > 9 THEN s0 = 9
	GOSUB update_score
	END

update_lives:	PROCEDURE	' vidas como digito em sprite (canto sup. esquerdo)
	IF li > 9 THEN li = 9
	SPRITE 40,16,$30,li * 2 + 192,0
	END

aim_8dir:	PROCEDURE	' mira do ponto (#tbx,#tby) na nave: 8 direcoes
	' entrada: #adx,#ady (assinados) | saida: tbvx,tbvy
	#t1 = ABS(#adx)
	#t2 = ABS(#ady)
	ebspd = 19 + wdif * 2
	IF #t2 + #t2 < #t1 THEN		' horizontal dominante
		tbvy = 0
		IF #adx < 0 THEN
			tbvx = 0 - ebspd
		ELSE
			tbvx = ebspd
		END IF
	ELSEIF #t1 + #t1 < #t2 THEN	' vertical dominante
		tbvx = 0
		IF #ady < 0 THEN
			tbvy = 0 - ebspd
		ELSE
			tbvy = ebspd
		END IF
	ELSE					' diagonal
		#tw = ebspd * 11 / 16
		IF #adx < 0 THEN
			tbvx = 0 - #tw
		ELSE
			tbvx = #tw
		END IF
		IF #ady < 0 THEN
			tbvy = 0 - #tw
		ELSE
			tbvy = #tw
		END IF
	END IF
	END

	' === gerado por gera_boss.py (v0.13): ceu preto + boss BG $1000 ===
eb_spawn:	PROCEDURE	' nasce tiro inimigo em (#tbx,#tby) com vel (tbvx,tbvy)
	' NOTA: nao usar "#arr(i) = #var * 16"! O shift do *16 reutiliza o temp
	' que guarda o endereco do elemento e a escrita vai parar em $0000.
	' Por isso o *16 vai antes para o global #tw e so depois p/ o array.
	' (eb_spawn tambem nao pode usar c: destruiria o FOR das waves!)
	' ebs = dono do tiro (1 = small; 0 = outros) p/ a cota de 3 do v0.12
	k = 0
	WHILE k < 8
		IF eba(k) = 0 THEN
			eba(k) = 1
			ebt(k) = ebs
			IF ebs = 1 THEN nsm = nsm + 1
			#tw = (#tbx + 256) * 16
			#ebx(k) = #tw
			#tw = (#tby + 256) * 16
			#eby(k) = #tw
			ebxv(k) = tbvx
			ebyv(k) = tbvy
			k = 8
		ELSE
			k = k + 1
		END IF
	WEND
	END

spawn_ring:	PROCEDURE	' anel de 8 tiros do shard morto (145px/s ~ 24/16)
	FOR i = 0 TO 7
		IF i = 0 THEN
			tbvx = 24
			tbvy = 0
		ELSEIF i = 1 THEN
			tbvx = 17
			tbvy = 17
		ELSEIF i = 2 THEN
			tbvx = 0
			tbvy = 24
		ELSEIF i = 3 THEN
			tbvx = -17
			tbvy = 17
		ELSEIF i = 4 THEN
			tbvx = -24
			tbvy = 0
		ELSEIF i = 5 THEN
			tbvx = -17
			tbvy = -17
		ELSEIF i = 6 THEN
			tbvx = 0
			tbvy = -24
		ELSE
			tbvx = 17
			tbvy = -17
		END IF
		ebs = 0
		GOSUB eb_spawn
	NEXT i
	END


	'
	' Paletas do Space Blast NES
	'
' Paleta do titulo/game over: pal0 = estrelas (cinza escuro, nao confunde
' com tiros); pal1 = logo azul/ciano/branco + textos brancos;
' pal2 = faixa vermelha da logo.
oam_ring:	' slots fisicos p/ o rodizio (v0.14, 16 slots)
	DATA BYTE 4,5,6,7,8,9,10,11,12,13,14,15
	DATA BYTE 21,22,23,24

game_palette_title:
	DATA BYTE $0F,$11,$21,$00	' fundo 0: preto, azuis + cinza escuro (estrelas)
	DATA BYTE $0F,$00,$10,$30	' fundo 1: cinza/branco (SPACE)
	DATA BYTE $0F,$06,$16,$30	' fundo 2: vermelhos (BLAST)
	DATA BYTE $0F,$1C,$10,$30	' fundo 3: teal/cinza/branco (cometa)
	DATA BYTE $0F,$00,$10,$30	' sprites 0: cinzas (corpo da nave, placar)
	DATA BYTE $0F,$16,$21,$12	' sprites 1: vermelho/azul/azul esc (canopy + small)
	DATA BYTE $0F,$19,$2A,$30	' sprites 2: verdes (chama da nave + shard)
	DATA BYTE $0F,$1C,$3C,$30	' sprites 3: quentes (explosao, tiro, ebullet)

' Paleta do gameplay: atributos todos 0 -> so o fundo 0 e usado.
game_palette_play:
	DATA BYTE $0F,$11,$21,$00	' fundo 0: preto, azuis + cinza escuro
	DATA BYTE $0F,$11,$21,$00	' fundo 1
	DATA BYTE $0F,$11,$21,$00	' fundo 2
	DATA BYTE $0F,$11,$21,$00	' fundo 3
	DATA BYTE $0F,$00,$10,$30	' sprites 0: cinzas (corpo da nave, placar)
	DATA BYTE $0F,$16,$21,$12	' sprites 1: vermelho/azul/azul esc (canopy + small)
	DATA BYTE $0F,$19,$2A,$30	' sprites 2: verdes (chama da nave + shard)
	DATA BYTE $0F,$1C,$3C,$30	' sprites 3: quentes (explosao, tiro, ebullet)

	' Tiles de estrela nao-vazios (p/ sorteio harmonico)
nep_tab:
	DATA BYTE 1,2,3,4,5,6,7,8
	DATA BYTE 9,10,11,12,13,14,15,16
	DATA BYTE 17,18,19,20,21,22,23

	' Mapa de tiles da logo (255 = transparente, nao plota)
logo_map:
	DATA BYTE 255,255,96,97,98,99,100,98
	DATA BYTE 101,102,103,104,105,106,107,108
	DATA BYTE 255,255,109,110,111,112,113,114
	DATA BYTE 115,116,117,118,119,120,121,122
	DATA BYTE 255,255,255,123,124,125,126,127
	DATA BYTE 128,127,129,124,130,131,255,255
	DATA BYTE 255,255,255,132,133,134,135,136
	DATA BYTE 137,138,139,140,141,142,255,255
	DATA BYTE 255,255,255,143,144,145,146,147
	DATA BYTE 148,149,150,151,152,153,255,255
	DATA BYTE 255,255,255,154,155,156,157,158
	DATA BYTE 159,160,161,162,163,164,255,255

falcon_map:
	DATA BYTE 96,96,96,96,96,96,97,98,99,96,96,96,96,96,96,96
	DATA BYTE 96,96,96,96,96,96,100,96,101,102,96,96,96,96,96,96
	DATA BYTE 96,96,96,103,104,105,106,107,108,109,110,111,112,96,96,96
	DATA BYTE 96,96,96,113,114,115,116,117,118,119,120,121,122,96,96,96
	DATA BYTE 96,96,123,124,125,126,127,128,129,130,131,132,133,134,96,96
	DATA BYTE 96,96,135,136,137,138,139,140,141,142,143,144,145,146,96,96
	DATA BYTE 96,147,148,149,150,151,152,153,154,155,156,157,158,159,160,96
	DATA BYTE 96,161,162,163,164,165,166,167,168,169,170,171,172,173,174,96
	DATA BYTE 96,96,96,96,96,96,175,176,177,178,96,96,96,96,96,96
	DATA BYTE 96,96,96,96,96,96,179,180,181,96,96,96,96,96,96,96

falcon_txt:
	DATA BYTE 182,185,186,183,187,183,184,188,182

' Fade da splash por palette cycling (idx2=cinza, idx3=branco).
' 7 passos x 4 frames ~0.47s por direcao.
fade_tbl:
	DATA BYTE $0F,$0F
	DATA BYTE $0F,$00
	DATA BYTE $00,$00
	DATA BYTE $00,$10
	DATA BYTE $10,$10
	DATA BYTE $10,$20
	DATA BYTE $10,$30
fade_tbl_out:
	DATA BYTE $10,$30
	DATA BYTE $10,$20
	DATA BYTE $10,$10
	DATA BYTE $00,$10
	DATA BYTE $00,$00
	DATA BYTE $0F,$00
	DATA BYTE $0F,$0F

	'
	' Tabela seno do zigzag: sin(i * 2pi / 64) * 127 + 128
	'
sintab:
	DATA BYTE 128,140,153,165,177,189,200,211
	DATA BYTE 221,229,236,242,247,251,253,255
	DATA BYTE 255,253,251,247,242,236,229,221
	DATA BYTE 211,200,189,177,165,153,140,128
	DATA BYTE 128,116,103,91,79,67,56,45
	DATA BYTE 35,27,20,14,9,5,3,1
	DATA BYTE 1,3,5,9,14,20,27,35
	DATA BYTE 45,56,67,79,91,103,116,128

	'
	' Blocos de video (CHR)
	'

BANK 1	' v0.15: procs frios grandes (miniboss + boss) saem do banco 0
sky_clear:	PROCEDURE	' ceu 100% preto p/ luta (Saulo autorizou)
	' apaga as 960 celulas visiveis, 16 por frame (dreno do buffer)
	#bk = $2000
	gbc = 0
sky_clear_loop:
	FOR i = 0 TO 15
		VPOKE #bk, 0
		#bk = #bk + 1
	NEXT i
	WAIT
	gbc = gbc + 1
	IF gbc < 60 THEN GOTO sky_clear_loop
	END

boss_write:	PROCEDURE	' desenha o corpo 96x64 (linhas 3-10)
	VPOKE $2069,0
	VPOKE $206A,0
	VPOKE $206B,0
	VPOKE $206C,0
	VPOKE $206D,0
	VPOKE $206E,0
	VPOKE $206F,0
	VPOKE $2070,0
	VPOKE $2071,0
	VPOKE $2072,0
	VPOKE $2073,0
	VPOKE $2074,0
	VPOKE $2089,0
	VPOKE $208A,0
	VPOKE $208B,0
	VPOKE $208C,0
	VPOKE $208D,0
	VPOKE $208E,0
	VPOKE $208F,0
	WAIT	' (gera_boss: drena buffer da PPU)
	VPOKE $2090,0
	VPOKE $2091,0
	VPOKE $2092,0
	VPOKE $2093,0
	VPOKE $2094,0
	VPOKE $20A9,0
	VPOKE $20AA,0
	VPOKE $20AB,0
	VPOKE $20AC,0
	VPOKE $20AD,0
	VPOKE $20AE,0
	VPOKE $20AF,0
	VPOKE $20B0,0
	VPOKE $20B1,0
	VPOKE $20B2,0
	VPOKE $20B3,0
	VPOKE $20B4,0
	VPOKE $20C9,0
	VPOKE $20CA,0
	WAIT	' (gera_boss: drena buffer da PPU)
	VPOKE $20CB,0
	VPOKE $20CC,0
	VPOKE $20CD,0
	VPOKE $20CE,0
	VPOKE $20CF,0
	VPOKE $20D0,0
	VPOKE $20D1,0
	VPOKE $20D2,0
	VPOKE $20D3,0
	VPOKE $20D4,0
	VPOKE $20E9,0
	VPOKE $20EA,0
	VPOKE $20EB,0
	VPOKE $20EC,0
	VPOKE $20ED,0
	VPOKE $20EE,0
	VPOKE $20EF,0
	VPOKE $20F0,0
	VPOKE $20F1,0
	WAIT	' (gera_boss: drena buffer da PPU)
	VPOKE $20F2,0
	VPOKE $20F3,0
	VPOKE $20F4,0
	VPOKE $2109,0
	VPOKE $210A,0
	VPOKE $210B,0
	VPOKE $210C,0
	VPOKE $210D,0
	VPOKE $210E,0
	VPOKE $210F,0
	VPOKE $2110,0
	VPOKE $2111,0
	VPOKE $2112,0
	VPOKE $2113,0
	VPOKE $2114,0
	VPOKE $2129,0
	VPOKE $212A,0
	VPOKE $212B,0
	VPOKE $212C,0
	WAIT	' (gera_boss: drena buffer da PPU)
	VPOKE $212D,0
	VPOKE $212E,0
	VPOKE $212F,0
	VPOKE $2130,0
	VPOKE $2131,0
	VPOKE $2132,0
	VPOKE $2133,0
	VPOKE $2134,0
	VPOKE $2149,0
	VPOKE $214A,0
	VPOKE $214B,0
	VPOKE $214C,0
	VPOKE $214D,0
	VPOKE $214E,0
	VPOKE $214F,0
	VPOKE $2150,0
	VPOKE $2151,0
	VPOKE $2152,0
	VPOKE $2153,0
	WAIT	' (gera_boss: drena buffer da PPU)
	VPOKE $2154,0
	VPOKE $2069,1
	VPOKE $2089,11
	VPOKE $20A9,187
	VPOKE $20C9,199
	VPOKE $20E9,211
	VPOKE $2109,227
	VPOKE $2129,239
	VPOKE $2149,-256
	VPOKE $206A,2
	VPOKE $208A,16
	VPOKE $20AA,188
	VPOKE $20CA,200
	VPOKE $20EA,212
	VPOKE $210A,228
	VPOKE $212A,240
	VPOKE $214A,251
	VPOKE $206B,-256
	VPOKE $208B,17
	WAIT	' (gera_boss: drena buffer da PPU)
	VPOKE $20AB,189
	VPOKE $20CB,201
	VPOKE $20EB,213
	VPOKE $210B,229
	VPOKE $212B,241
	VPOKE $214B,252
	VPOKE $206C,3
	VPOKE $208C,18
	VPOKE $20AC,190
	VPOKE $20CC,202
	VPOKE $20EC,214
	VPOKE $210C,230
	VPOKE $212C,242
	VPOKE $214C,-256
	VPOKE $206D,4
	VPOKE $208D,19
	VPOKE $20AD,191
	VPOKE $20CD,203
	VPOKE $20ED,215
	WAIT	' (gera_boss: drena buffer da PPU)
	VPOKE $210D,231
	VPOKE $212D,243
	VPOKE $214D,-256
	VPOKE $206E,5
	VPOKE $208E,180
	VPOKE $20AE,192
	VPOKE $20CE,204
	VPOKE $20EE,220
	VPOKE $210E,232
	VPOKE $212E,244
	VPOKE $214E,-256
	VPOKE $206F,6
	VPOKE $208F,181
	VPOKE $20AF,193
	VPOKE $20CF,205
	VPOKE $20EF,221
	VPOKE $210F,233
	VPOKE $212F,245
	VPOKE $214F,-256
	WAIT	' (gera_boss: drena buffer da PPU)
	VPOKE $2070,7
	VPOKE $2090,182
	VPOKE $20B0,194
	VPOKE $20D0,206
	VPOKE $20F0,222
	VPOKE $2110,234
	VPOKE $2130,246
	VPOKE $2150,-256
	VPOKE $2071,8
	VPOKE $2091,183
	VPOKE $20B1,195
	VPOKE $20D1,207
	VPOKE $20F1,223
	VPOKE $2111,235
	VPOKE $2131,247
	VPOKE $2151,-256
	VPOKE $2072,-256
	VPOKE $2092,184
	VPOKE $20B2,196
	WAIT	' (gera_boss: drena buffer da PPU)
	VPOKE $20D2,208
	VPOKE $20F2,224
	VPOKE $2112,236
	VPOKE $2132,248
	VPOKE $2152,253
	VPOKE $2073,9
	VPOKE $2093,185
	VPOKE $20B3,197
	VPOKE $20D3,209
	VPOKE $20F3,225
	VPOKE $2113,237
	VPOKE $2133,249
	VPOKE $2153,254
	VPOKE $2074,10
	VPOKE $2094,186
	VPOKE $20B4,198
	VPOKE $20D4,210
	VPOKE $20F4,226
	VPOKE $2114,238
	WAIT	' (gera_boss: drena buffer da PPU)
	VPOKE $2134,250
	VPOKE $2154,-256
	VPOKE $23C2,$55
	VPOKE $23C3,$55
	VPOKE $23C4,$55
	VPOKE $23C5,$55
	VPOKE $23CA,$55
	VPOKE $23CB,$55
	VPOKE $23CC,$55
	VPOKE $23CD,$55
	VPOKE $23D2,$55
	VPOKE $23D3,$55
	VPOKE $23D4,$55
	VPOKE $23D5,$55
	END

boss_erase:	PROCEDURE	' remove o boss do BG (apos a morte)
	' retangulo cols 9-20, linhas 3-10 (1/2 linha por frame)
	FOR #j = $2069 TO $206E
		VPOKE #j,0
	NEXT #j
	FOR #j = $206F TO $2074
		VPOKE #j,0
	NEXT #j
	WAIT
	FOR #j = $2089 TO $208E
		VPOKE #j,0
	NEXT #j
	FOR #j = $208F TO $2094
		VPOKE #j,0
	NEXT #j
	WAIT
	FOR #j = $20A9 TO $20AE
		VPOKE #j,0
	NEXT #j
	FOR #j = $20AF TO $20B4
		VPOKE #j,0
	NEXT #j
	WAIT
	FOR #j = $20C9 TO $20CE
		VPOKE #j,0
	NEXT #j
	FOR #j = $20CF TO $20D4
		VPOKE #j,0
	NEXT #j
	WAIT
	FOR #j = $20E9 TO $20EE
		VPOKE #j,0
	NEXT #j
	FOR #j = $20EF TO $20F4
		VPOKE #j,0
	NEXT #j
	WAIT
	FOR #j = $2109 TO $210E
		VPOKE #j,0
	NEXT #j
	FOR #j = $210F TO $2114
		VPOKE #j,0
	NEXT #j
	WAIT
	FOR #j = $2129 TO $212E
		VPOKE #j,0
	NEXT #j
	FOR #j = $212F TO $2134
		VPOKE #j,0
	NEXT #j
	WAIT
	FOR #j = $2149 TO $214E
		VPOKE #j,0
	NEXT #j
	FOR #j = $214F TO $2154
		VPOKE #j,0
	NEXT #j
	WAIT
	VPOKE $23C2,0
	VPOKE $23C3,0
	VPOKE $23C4,0
	VPOKE $23C5,0
	VPOKE $23CA,0
	VPOKE $23CB,0
	VPOKE $23CC,0
	VPOKE $23CD,0
	VPOKE $23D2,0
	VPOKE $23D3,0
	VPOKE $23D4,0
	VPOKE $23D5,0
	WAIT
	END

boss_start:	PROCEDURE	' BOSS (v0.13): 1 nave 96x64 no alto, 100% BG
	bsw = 1
	bsa = 1
	bsph = 1			' fase 1: leques alternados das asas
	bst = 60			' 1s de graca apos o warp-in
	bsn = 0
	bshw = 0			' proximo leque: asa esquerda
	bshp = 120			' HP do boss (constante p/ ajuste fino)
	bol = 0
	boff = 0			' balanco comeca no centro
	bdir = 0
	bpf = 0
	scroll_y = 0
	SCROLL 0,0			' boss e BG: congela o cenario no zero
	GOSUB sky_clear		' ceu 100% preto (~1s, top-down: dramatico)
	VPOKE $3F05,$03		' BG pal1 = paleta do boss (roxo/lilas/dourado)
	VPOKE $3F06,$23		' (cores exatas do boss.png do Saulo)
	VPOKE $3F07,$38
	' BG passa a ler a tabela $1000 (a arte do boss mora la); sprites
	' 8x16 escolhem a tabela pelo bit0 do byte: nada muda p/ eles!
	ASM LDA #$B8
	ASM STA ppu_ctrl
	GOSUB boss_write		' desenha o corpo 96x64 (com WAITs)
	END

boss_kill:	PROCEDURE	' morte do boss: +5000, cerimonia, restaura cenario
	bsa = 0
	bsw = 0
	bol = 0
	SPRITE 61,$f0,0,0,0	' esconde o laser gêmeo
	SPRITE 62,$f0,0,0,0
	' BG volta p/ tabela $0000 (estrelas/fonte!)
	ASM LDA #$A8
	ASM STA ppu_ctrl
	VPOKE $3F05,$11		' restaura BG pal1 (estrelas)
	VPOKE $3F06,$21
	VPOKE $3F07,$00
	mpt = 24			' explosao longa no centro do boss
	mpx = 112 + boff
	mpy = 56
	#pop = 24
	GOSUB boss_erase		' apaga o boss do BG (com WAITs)
	' v0.28: SEM refill do mar aqui! banco1 -> banco3 (janela->janela,
	' aninhado) trava a CPU. E nao precisa: o boss e' o FIM da fase; o
	' fundo da fase seguinte e' refeito no begin_stage (banco 0->3, ok).
	IF (fase AND 1) = 1 THEN	' (espaco: stars_fill e' fixo, sem wrap)
		GOSUB stars_fill	' devolve as estrelas ao cenario
	END IF
	bsc = 70			' v0.19: cerimonia (estrobo+estouros) p/ transicao
	e = 50				' +5000 pontos (chefe da fase 1!)
	d = 0
	GOSUB score_add
	nsma = 0			' boss volta a contar do zero (proximo ciclo)
	nsha = 0
	ne4 = 0
	END

mb_kill:	PROCEDURE	' morte do miniboss: +500, explosao grande central
	mba = 0
	mlr = 0
	FOR i = 41 TO 48
		SPRITE i,$f0,0,0,0
	NEXT i
	FOR i = 57 TO 60	' laser do miniboss (v0.12)
		SPRITE i,$f0,0,0,0
	NEXT i
	VPOKE $3F19,$19		' restaura pal2 (verde da chama/shards)
	VPOKE $3F1A,$2A
	VPOKE $3F1B,$30
	mpt = 16
	mpx = mbx + 8
	mpy = yc + 8
	e = 5				' 500 pontos (= medB/miniboss do jogo original)
	d = 0
	GOSUB score_add
	#pop = 16
	END

mb_frame:	PROCEDURE	' v0.15: frames do MINIBOSS (patrulha, laser, aneis, colisoes).
							' Sai com diek=1 quando a nave morre (GOTO p/ fora de proc e' ilegal).
		yc = (#mby / 16) - 256
		IF mbs = 1 THEN
			' descendo ate UM POUCO ACIMA do meio da tela (v0.12: era y=100)
			#mby = #mby + 16
			IF #mby >= 5248 THEN mbs = 2	' 5248 = (72+256)*16
		ELSE
			' patrulha esquerda/direita (1 px/frame, inverte nas margens)
			IF mbdir = 0 THEN
				mbx = mbx + 1
				IF mbx >= 200 THEN mbdir = 1
			ELSE
				mbx = mbx - 1
				IF mbx <= 16 THEN mbdir = 0
			END IF
			' v0.14: laser em 3 pontos do passeio (pedido do Saulo):
			' centro exato (112) E os dois extremos (16/200)
			e2 = 0
			IF mbx = 112 THEN e2 = 1
			IF mbx = 200 THEN e2 = 1
			IF mbx = 16 THEN e2 = 1
			IF mlr = 0 THEN
				IF mbx <> mbxo THEN
					IF e2 = 1 THEN
						mlr = 1
						mlx = mbx + 8
						#tw = yc + 276		' y do inicio do laser
						#mly = #tw * 16
					END IF
				END IF
			END IF
			mbxo = mbx
			' Aneis de tempos em tempos; SO dispara quando o pool de tiros
			' inimigos esvaziou (trava anti-slowdown pedida pelo Saulo)
			IF mbt > 0 THEN mbt = mbt - 1
			IF mbt = 0 THEN
				e = eba(0) + eba(1) + eba(2) + eba(3) + eba(4) + eba(5) + eba(6) + eba(7)
				IF e = 0 THEN
					#tbx = mbx + 16
					#tby = yc + 16
					GOSUB spawn_ring
					mbt = 150		' 2.5s de descanso apos disparar
				END IF
			END IF
		END IF
		IF #mby < 4112 THEN
			FOR c = 41 TO 48	' ainda entrando: escondido
				SPRITE c,$f0,0,0,0
			NEXT c
		ELSE
			' desenha: 2 frames animados (bases 141/157); reuse dos slots
			' 41-48 do enemy4 (eles NUNCA coexistem: ondas exclusivas)
			d = (FRAME / 8) AND 1
			d = d * 16
			d = d + 141
			e = mbx
			FOR c = 41 TO 44
				SPRITE c,yc - 1,e,d,2
				e = e + 8
				d = d + 2
			NEXT c
			e = mbx
			FOR c = 45 TO 48
				SPRITE c,yc + 15,e,d,2
				e = e + 8
				d = d + 2
			NEXT c
		END IF
		' Encostou na nave? (colisao = 1 tiro de dano no miniboss tambem)
		IF ded = 0 AND inv = 0 THEN
			IF #mby >= 4112 THEN
				#c1 = px
				#c1 = #c1 - mbx
				#c1 = #c1 - 8
				IF ABS(#c1) < 20 THEN
					#c2 = py
					#c2 = #c2 - yc
					#c2 = #c2 - 16
					IF ABS(#c2) < 20 THEN
						mbhp = mbhp - 1
						IF mbhp = 0 THEN GOSUB mb_kill
						diek = 1: RETURN		' v0.15: era GOTO player_dies (fora de proc nao pode!)
					END IF
				END IF
			END IF
		END IF
		' Levou tiro?
		FOR d = 0 TO 4
			IF bty(d) <> 0 THEN
				IF btx(d) + 6 > mbx AND btx(d) < mbx + 26 THEN
					IF bty(d) + 8 > yc AND bty(d) < yc + 32 THEN
						bty(d) = 0
						SPRITE 16 + d,$f0,0,0,0
						mpt = 6				' faisca no impacto
						mpx = btx(d) - 3
						mpy = bty(d)
						mbhp = mbhp - 1
						#pop = 4
					IF mbhp = 0 THEN GOSUB mb_kill
					d = 5
				END IF
			END IF
		END IF
	NEXT d
	' --- Laser do miniboss (v0.12: arte laser.png do Saulo, 16x32) ---
	IF mlr THEN
		#mly = #mly + 96	' desce rapido: 6 px/frame
		IF #mly >= 7808 THEN mlr = 0	' (232+256)*16: saiu da tela
		IF mlr THEN
			ly = (#mly / 16) - 256
			SPRITE 57,ly - 1,mlx,173,3
			SPRITE 58,ly + 15,mlx,175,3
			SPRITE 59,ly - 1,mlx + 8,177,3
			SPRITE 60,ly + 15,mlx + 8,179,3
			IF ded = 0 AND inv = 0 THEN
				#c1 = px
				#c1 = #c1 - mlx
				#c1 = #c1 - 4
				IF ABS(#c1) < 10 THEN
					#c2 = py
					#c2 = #c2 - ly
					#c2 = #c2 - 12
					IF ABS(#c2) < 20 THEN
						diek = 1: RETURN		' v0.15: era GOTO player_dies (fora de proc nao pode!)
					END IF
				END IF
			END IF
		END IF
	ELSE
		FOR c = 57 TO 60	' laser apagado: esconde (so nesta onda)
			SPRITE c,$f0,0,0,0
		NEXT c
	END IF
	END

boss_frame:	PROCEDURE	' v0.15: frames do BOSS (3 fases, leques, saraivada, hits).
							' Idem diek.
		IF bsph = 1 THEN
			bst = bst - 1
			IF bst = 0 THEN
				e = eba(0) + eba(1) + eba(2) + eba(3) + eba(4) + eba(5) + eba(6) + eba(7)
				IF e < 5 THEN			' trava anti-slowdown (pool de 8)
					#tbx = 84 + #bo		' asas acompanham o balanco
					IF bshw <> 0 THEN
						#tbx = 156 + #bo	' (16-bit c/ sinal: asa dir >127!)
					END IF
					#tby = 80
					tbvy = 35
					tbvx = 247			' -9 (em byte) = leque p/ esq
					ebs = 0
					GOSUB eb_spawn
					tbvx = 0
					ebs = 0
					GOSUB eb_spawn
					tbvx = 9			' leque p/ dir
					ebs = 0
					GOSUB eb_spawn
					bshw = 1 - bshw
					bsn = bsn + 1
					bst = 42
					IF bsn >= 8 THEN
						bsph = 2
						bsn = 0
						bst = 20
					END IF
				ELSE
					bst = 10			' pool cheio: remarca
				END IF
			END IF
		ELSE
			IF bsph = 2 THEN
				bst = bst - 1
				IF bst = 0 THEN
					e = eba(0) + eba(1) + eba(2) + eba(3) + eba(4) + eba(5) + eba(6) + eba(7)
					IF e < 8 THEN
						#tbx = 88 + RANDOM(64)	' diferentes locais...
						#tbx = #tbx + #bo		' ...acompanhando o balanco
						#tby = 82
						tbvx = 0
						tbvy = 26 + RANDOM(23)	' ...e diferentes velocidades
						ebs = 0
						GOSUB eb_spawn
						bsn = bsn + 1
						bst = 8
						IF bsn >= 20 THEN
							bsph = 3
							bsn = 0
							bst = 30
						END IF
					ELSE
						bst = 6
					END IF
				END IF
			ELSE
				bst = bst - 1
				IF bst = 0 THEN
					IF bol = 0 THEN
						bol = 1
						#boy = 5504			' (88+256)*16
						bsn = bsn + 1
						IF bsn >= 3 THEN
							bsph = 1			' repete o ciclo
							bsn = 0
							bst = 90
						ELSE
							bst = 50
						END IF
					ELSE
						bst = 8			' espera o laser sair da tela
					END IF
				END IF
			END IF
		END IF
		' laser do boss (do meio dele; arte laser.png, metade 16x16)
		IF bol THEN
			#boy = #boy + 96	' desce rapido: 6 px/frame
			IF #boy >= 7808 THEN bol = 0
			IF bol THEN
				ly = (#boy / 16) - 256
				e = 112 + boff			' acompanha o balanco do corpo
				SPRITE 61,ly - 1,e,173,3
				e = 120 + boff
				SPRITE 62,ly - 1,e,177,3
				e = 116 + boff
				IF ded = 0 AND inv = 0 THEN
					#c1 = px
					#c1 = #c1 - e
					IF ABS(#c1) < 10 THEN
						#c2 = py
						#c2 = #c2 - ly
						#c2 = #c2 - 8
						IF ABS(#c2) < 14 THEN
							diek = 1: RETURN		' v0.15: era GOTO player_dies (fora de proc nao pode!)
						END IF
					END IF
				END IF
			END IF
		ELSE
			SPRITE 61,$f0,0,0,0
			SPRITE 62,$f0,0,0,0
		END IF
		' Encostou na nave? (boss 96x64 no alto: caixa 72..167 x 24..88)
		e = 120 + boff
		IF ded = 0 AND inv = 0 THEN
			#c1 = px
			#c1 = #c1 + 8
			#c1 = #c1 - e
			IF ABS(#c1) < 52 THEN
				#c2 = py
				#c2 = #c2 - 56
				IF ABS(#c2) < 36 THEN
					diek = 1: RETURN		' v0.15: era GOTO player_dies (fora de proc nao pode!)
				END IF
			END IF
		END IF
		' Levou tiro?
		FOR d = 0 TO 4
			IF bty(d) <> 0 THEN
				e = 72 + boff
				e2 = 168 + boff
				IF btx(d) + 6 > e AND btx(d) < e2 THEN
					IF bty(d) + 8 > 24 AND bty(d) < 88 THEN
						bty(d) = 0
						SPRITE 16 + d,$f0,0,0,0
						mpt = 6				' faisca no impacto
						mpx = btx(d) - 3
						mpy = bty(d)
						bshp = bshp - 1
						#pop = 4
						IF bshp = 0 THEN GOSUB boss_kill
						d = 5
					END IF
				END IF
			END IF
		NEXT d
	END



	' v0.16: SPLASH FALCON SOFT. CHR-ROM pagina 1 via POKE $1C,$20 (BANKSEL
	' bits 5-6 do CHR-RAM; o NMI restaura ORA CHRRAM_BANK a cada frame).
	' Logo 128x80 (tiles 96-181) centralizada + "apresenta" (tiles 182-188,
	' glifos da fonte CVBasic). Fade por PALETTE CYCLING em $3F02/$3F03
	' (7 passos x 4 frames). Qualquer botao corta DIRETO p/ o titulo;
	' senao, ~3.4s e sai com o mesmo fade suave.
falcon_splash: PROCEDURE
	POKE $1C,$20
	SCREEN DISABLE
	CLS
	RESTORE falcon_map
	FOR r = 0 TO 159
		READ BYTE e
		IF e THEN
			#tw = r / 16 + 9
			#tw = #tw * 32
			e2 = r AND 15
			#tw = #tw + e2 + 8
			VPOKE $2000 + #tw, e
		END IF
	NEXT r
	RESTORE falcon_txt
	FOR r = 0 TO 8
		READ BYTE e
		VPOKE $2000 + 651 + r, e
	NEXT r
	VPOKE $3F00,$0F
	VPOKE $3F01,$0F
	VPOKE $3F02,$0F
	VPOKE $3F03,$0F
	WAIT
	SCREEN ENABLE
	RESTORE fade_tbl
	FOR sk = 0 TO 1
		FOR r = 0 TO 6
			READ BYTE e
			READ BYTE e2
			VPOKE $3F02,e
			VPOKE $3F03,e2
			FOR q = 0 TO 3
				WAIT
				IF CONT1.KEY = 11 THEN GOTO fs_fim
				IF CONT1.BUTTON THEN GOTO fs_fim
			NEXT q
		NEXT r
		IF sk = 0 THEN
			' hold ~2.5s com a logo acesa
			FOR q = 0 TO 149
				WAIT
				IF CONT1.KEY = 11 THEN GOTO fs_fim
				IF CONT1.BUTTON THEN GOTO fs_fim
			NEXT q
			RESTORE fade_tbl_out
		END IF
	NEXT sk
fs_fim:
	SCREEN DISABLE
	POKE $1C,$00
	WAIT
	END

	'
	' v0.18: CARTAO DE FASE — tela preta, texto central, entra em fade
	' (palette cycling, mesma rampa da Falcon), sai com START ou sozinha
	' (~4s). Texto usa pal0/cor3: attrs zerados pelo CLS, nada mais p/ setar.
	'
title_idle_wait: PROCEDURE
	#bo = 0
	sk = 0
title_idle_loop:
	WAIT
	IF (FRAME AND 16) = 0 THEN
		PRINT AT 714,"APERTE START"
	ELSE
		PRINT AT 714,"            "
	END IF
	IF CONT1.KEY = 11 THEN GOTO title_idle_done
	IF CONT1.BUTTON THEN GOTO title_idle_done
	#bo = #bo + 1
	IF #bo < 300 THEN GOTO title_idle_loop
	' Cinco segundos sem START: historia; ao voltar, o banco 0 faz reset completo.
	GOSUB history_screen
	sk = 1
title_idle_done:
	END

stage_card: PROCEDURE
sc_release:				' espera soltar o START do game over/titulo
	WAIT
	IF CONT1.KEY = 11 THEN GOTO sc_release
	IF CONT1.BUTTON THEN GOTO sc_release
	SCREEN DISABLE
	CLS
	SCROLL 0,0
	PRINT AT 460,"FASE 0",<1>fase	' v0.28: cartao generico p/ as 5 fases
	IF fase = 1 THEN PRINT AT 514,"A CAMINHO DO PLANETA DE FOGO"
	IF fase = 2 THEN PRINT AT 519,"O PLANETA DE FOGO"
	IF fase = 3 THEN
		PRINT AT 516,"O CINTURAO DE ASTEROIDES"
		VPOKE $2000 + 492,26	' til sobre o A de CINTURAO
		VPOKE $2000 + 503,27	' agudo sobre o O de ASTEROIDES
	END IF
	IF fase = 4 THEN
		PRINT AT 518,"O GERADOR DE ESCUDOS"
		PRINT AT 582,"DO PLANETA ATLANTIS"
	END IF
	IF fase = 5 THEN PRINT AT 516,"A BATALHA FINAL COM GORF"
	VPOKE $3F01,$0F		' texto invisivel: cores do pal0 em preto
	VPOKE $3F02,$0F
	VPOKE $3F03,$0F
	WAIT
	SCREEN ENABLE
	RESTORE fade_tbl
	FOR r = 0 TO 6			' fade-in
		READ BYTE e
		READ BYTE e		' (coluna "clara" da rampa)
		VPOKE $3F03,e
		FOR q = 0 TO 3
			WAIT
			IF CONT1.KEY = 11 THEN GOTO sc_fim
			IF CONT1.BUTTON THEN GOTO sc_fim
		NEXT q
	NEXT r
	FOR q = 0 TO 239		' hold ~4s
		WAIT
		IF CONT1.KEY = 11 THEN GOTO sc_fim
		IF CONT1.BUTTON THEN GOTO sc_fim
	NEXT q
	RESTORE fade_tbl_out		' fade-out so quando sai sozinha
	FOR r = 0 TO 6
		READ BYTE e
		READ BYTE e
		VPOKE $3F03,e
		FOR q = 0 TO 3
			WAIT
		NEXT q
	NEXT r
sc_fim:
	SCREEN DISABLE
	WAIT
	END

	'
	' v0.18: desenha a tela de GAME OVER apagada (cores em preto), escreve
	' tudo invisivel e acende com FADE por palette cycling (rampa da Falcon)
	'
clear_nts: PROCEDURE
	' v0.19.2: zera $2000/$2800 p/ a volta da fase 1 via SELECT
	' CUIDADO: FOR de 8 bits com TO 255/1023 nunca termina (o contador
	' embrulha em 255->0 e BCS sempre salta = loop infinito! autopsia:
	' boot travado em tela preta COM musica - NMI viva, cpu presa).
	FOR w = 0 TO 15
		FOR i = 0 TO 63
			VPOKE $2000+w*64+i,0
			IF (i AND 15) = 15 THEN WAIT	' drena o PPUBUF (16 writes/frame)
		NEXT i
	NEXT w
	FOR w = 0 TO 15
		FOR i = 0 TO 63
			VPOKE $2800+w*64+i,0
			IF (i AND 15) = 15 THEN WAIT
		NEXT i
	NEXT w
	FOR w = 0 TO 15		' $2400 tb: canhoes/streams pisam na 3a pagina
		FOR i = 0 TO 63
			VPOKE $2400+w*64+i,0
			IF (i AND 15) = 15 THEN WAIT
		NEXT i
	NEXT w
END

go_draw: PROCEDURE
	VPOKE $3F01,$0F		' paletas do texto em preto (invisivel)
	VPOKE $3F02,$0F
	VPOKE $3F03,$0F
	VPOKE $3F05,$0F
	VPOKE $3F06,$0F
	VPOKE $3F07,$0F
	VPOKE $214B,32	' "GAMEOVER" junto, centralizado (col 12-19)
	VPOKE $214C,214
	VPOKE $214D,215
	VPOKE $214E,216
	VPOKE $214F,217
	VPOKE $2150,218
	VPOKE $2151,219
	VPOKE $2152,220
	VPOKE $2153,221
	VPOKE $2154,32
	PRINT AT 391,"PONTOS: ",<1>s0,<1>s1,<1>s2,<1>s3,<1>s4
	' 1 linha de espaco entre frases: GO linha10, PONTOS 12, ONDA 14, START 16
	WAIT
	RESTORE fade_tbl		' fade-in (texto -> cor 3 de pal0 E pal1)
	FOR r = 0 TO 6
		READ BYTE e
		READ BYTE e		' (coluna "clara" da rampa)
		VPOKE $3F03,e	' ONDA linha14 e APERTE linha16 caem em pal0!
		VPOKE $3F07,e
		FOR q = 0 TO 3
			WAIT
		NEXT q
	NEXT r
	END

	'
	' v0.19: telas de transicao de fase (mesmo estilo do stage_card)
	'
fase_completa: PROCEDURE
fc_release:
	WAIT
	IF CONT1.KEY = 11 THEN GOTO fc_release
	IF CONT1.BUTTON THEN GOTO fc_release
	SCREEN DISABLE
	FOR c = 0 TO 63		' tela limpa: esconde sprites (HUD + nave)
		SPRITE c,$f0,0,0,0
	NEXT c
	CLS
	SCROLL 0,0
	PRINT AT 392,"FASE 0",<1>fase," COMPLETA"	' v0.28: generico
	PRINT AT 455,"PONTUACAO: ",<1>s0,<1>s1,<1>s2,<1>s3,<1>s4
	PRINT AT 487,"VIDAS: ",<1>li
	VPOKE $3F01,$0F
	VPOKE $3F02,$0F
	VPOKE $3F03,$0F
	WAIT
	SCREEN ENABLE
	RESTORE fade_tbl
	FOR r = 0 TO 6
		READ BYTE e
		READ BYTE e
		VPOKE $3F03,e
		FOR q = 0 TO 3
			WAIT
			IF CONT1.KEY = 11 THEN GOTO fc_fim
			IF CONT1.BUTTON THEN GOTO fc_fim
		NEXT q
	NEXT r
	FOR q = 0 TO 209
		WAIT
		IF CONT1.KEY = 11 THEN GOTO fc_fim
		IF CONT1.BUTTON THEN GOTO fc_fim
	NEXT q
	RESTORE fade_tbl_out
	FOR r = 0 TO 6
		READ BYTE e
		READ BYTE e
		VPOKE $3F03,e
		FOR q = 0 TO 3
			WAIT
		NEXT q
	NEXT r
fc_fim:
	SCREEN DISABLE
	WAIT
	END

	'
	' v0.28: FIM DE JOGO - 3 telas (vitoria, creditos, THE END?)
	' no mesmo estilo dos cartoes (fade por palette cycling, START pula)
	'
end_vitoria: PROCEDURE
ev_release:
	WAIT
	IF CONT1.KEY = 11 THEN GOTO ev_release
	IF CONT1.BUTTON THEN GOTO ev_release
	SCREEN DISABLE
	FOR c = 0 TO 63		' tela limpa: esconde sprites (HUD + nave)
		SPRITE c,$f0,0,0,0
	NEXT c
	CLS
	SCROLL 0,0
	PRINT AT 196,"VOCE CONSEGUIU DESTRUIR"
	PRINT AT 264,"O IMPERIO GORF E"
	PRINT AT 327,"SALVAR A GALAXIA!"
	PRINT AT 454,"PARABENS GUERREIRO!"
	PRINT AT 517,"MAS A LUTA ESTA LONGE"
	PRINT AT 586,"DE TERMINAR!"
	VPOKE $2000 + 307,27	' agudo na linha acima do A de GALAXIA
	VPOKE $2000 + 427,27	' agudo na linha acima do E de PARABENS
	VPOKE $2000 + 499,27	' agudo na linha acima do A de ESTA
	VPOKE $3F01,$0F
	VPOKE $3F02,$0F
	VPOKE $3F03,$0F
	WAIT
	SCREEN ENABLE
	RESTORE fade_tbl
	FOR r = 0 TO 6
		READ BYTE e
		READ BYTE e
		VPOKE $3F03,e
		FOR q = 0 TO 3
			WAIT
			IF CONT1.KEY = 11 THEN GOTO ev_fim
			IF CONT1.BUTTON THEN GOTO ev_fim
		NEXT q
	NEXT r
	' CVBasic counters are 8-bit: never use a FOR limit above 254.
	' 2 x 135 frames = 270 frames (~4.5s), as intended.
	FOR r = 0 TO 1
		FOR q = 0 TO 134
			WAIT
			IF CONT1.KEY = 11 THEN GOTO ev_fim
			IF CONT1.BUTTON THEN GOTO ev_fim
		NEXT q
	NEXT r
	RESTORE fade_tbl_out
	FOR r = 0 TO 6
		READ BYTE e
		READ BYTE e
		VPOKE $3F03,e
		FOR q = 0 TO 3
			WAIT
		NEXT q
	NEXT r
ev_fim:
	SCREEN DISABLE
	WAIT
	END

end_creditos: PROCEDURE
ec_release:
	WAIT
	IF CONT1.KEY = 11 THEN GOTO ec_release
	IF CONT1.BUTTON THEN GOTO ec_release
	SCREEN DISABLE
	FOR c = 0 TO 63
		SPRITE c,$f0,0,0,0
	NEXT c
	POKE $1C,$00		' fonte Saulo; os acentos sao tiles na linha vazia acima
	PALETTE LOAD game_palette_title
	CLS			' primeira nametable
	GOSUB scroll_clear_nt2	' segunda nametable ($2800), necessaria ao scroll
	GOSUB scroll_draw_credits
	GOSUB scroll_set_tail_attrs
	#bk = 0
	SCROLL 0,#bk
	VPOKE $3F01,$0F
	VPOKE $3F02,$0F
	VPOKE $3F03,$0F
	VPOKE $3F07,$0F
	WAIT
	SCREEN ENABLE
	RESTORE fade_tbl
	FOR r = 0 TO 6
		READ BYTE e
		READ BYTE e
		VPOKE $3F03,e
		FOR q = 0 TO 3
			WAIT
			IF CONT1.KEY = 11 THEN GOTO ec_fim
		NEXT q
	NEXT r
	' Primeiro trecho: 256 pixels ate $2800 ocupar a tela inteira.
	FOR r = 0 TO 1
		FOR q = 0 TO 127
			WAIT
			IF CONT1.KEY = 11 THEN GOTO ec_fim
			#bk = #bk + 1
			SCROLL 0,#bk
			WAIT
			IF CONT1.KEY = 11 THEN GOTO ec_fim
		NEXT q
	NEXT r
	' $2000 ja esta fora da tela; revela o trecho final que ficou escondido.
	VPOKE $3F07,$30
	WAIT
	' Restante: 204 pixels; terminamos em #bk=460, antes de $2800 repetir.
	FOR q = 0 TO 203
		WAIT
		IF CONT1.KEY = 11 THEN GOTO ec_fim
		#bk = #bk + 1
		SCROLL 0,#bk
		WAIT
		IF CONT1.KEY = 11 THEN GOTO ec_fim
	NEXT q
	RESTORE fade_tbl_out
	FOR r = 0 TO 6
		READ BYTE e
		READ BYTE e
		VPOKE $3F03,e
		FOR q = 0 TO 3
			WAIT
		NEXT q
	NEXT r
ec_fim:
	SCREEN DISABLE
	POKE $1C,$00
	#bk = 0
	SCROLL 0,#bk
	WAIT
	END

end_theend: PROCEDURE
te_release:
	WAIT
	IF CONT1.KEY = 11 THEN GOTO te_release
	IF CONT1.BUTTON THEN GOTO te_release
	SCREEN DISABLE
	FOR c = 0 TO 63
		SPRITE c,$f0,0,0,0
	NEXT c
	CLS
	SCROLL 0,0
	PRINT AT 460,"THE END?"
	VPOKE $3F01,$0F
	VPOKE $3F02,$0F
	VPOKE $3F03,$0F
	WAIT
	SCREEN ENABLE
	RESTORE fade_tbl
	FOR r = 0 TO 6
		READ BYTE e
		READ BYTE e
		VPOKE $3F03,e
		FOR q = 0 TO 3
			WAIT
			IF CONT1.KEY = 11 THEN GOTO te_fim
			IF CONT1.BUTTON THEN GOTO te_fim
		NEXT q
	NEXT r
	' CVBasic counters are 8-bit: never use a FOR limit above 254.
	' 2 x 135 frames = 270 frames (~4.5s), as intended.
	FOR r = 0 TO 1
		FOR q = 0 TO 134
			WAIT
			IF CONT1.KEY = 11 THEN GOTO te_fim
			IF CONT1.BUTTON THEN GOTO te_fim
		NEXT q
	NEXT r
	RESTORE fade_tbl_out
	FOR r = 0 TO 6
		READ BYTE e
		READ BYTE e
		VPOKE $3F03,e
		FOR q = 0 TO 3
			WAIT
		NEXT q
	NEXT r
te_fim:
	SCREEN DISABLE
	WAIT
	END

	' v0.33: cada linha usa uma linha vazia acima; os tiles 26/27/28
	' (til/agudo/circunflexo) ficam exatamente sobre a vogal. As duas
	' metades sao montadas com a tela desligada; o scroll nao escreve VRAM.
	' A paleta revela a segunda metade na fronteira, sem piscar o texto.
history_text:
	DATA BYTE 1,4,23,79,32,73,77,80,69,82,73,79,32,71,79,82,70,32,65,77,69,65,29,65,32,65
	DATA BYTE 0,9,1,27
	DATA BYTE 3,1,29,71,65,76,65,88,73,65,33,32,65,32,72,85,77,65,78,73,68,65,68,69,32,80,82,69,67,73,83,65
	DATA BYTE 2,4,1,27
	DATA BYTE 5,3,25,82,69,83,73,83,84,73,82,32,69,32,69,78,70,82,69,78,84,65,82,32,69,83,83,69
	DATA BYTE 7,1,31,73,78,73,77,73,71,79,32,84,69,82,82,73,86,69,76,33,32,79,83,32,76,65,67,65,73,79,83,32,68,69
	DATA BYTE 6,13,1,27
	DATA BYTE 9,3,26,71,79,82,70,32,69,78,67,79,78,84,82,65,82,65,77,32,65,32,84,69,82,82,65,32,69
	DATA BYTE 11,5,21,73,78,73,67,73,65,82,65,77,32,85,77,65,32,71,85,69,82,82,65,46
	DATA BYTE 13,1,30,69,77,32,83,69,77,65,78,65,83,44,32,65,83,32,70,79,82,29,65,83,32,68,65,32,84,69,82,82,65
	DATA BYTE 15,1,30,69,32,68,79,83,32,73,78,73,77,73,71,79,83,32,83,79,70,82,69,82,65,77,32,77,85,73,84,65,83
	DATA BYTE 17,2,27,66,65,73,88,65,83,44,32,77,65,83,32,69,76,69,83,32,69,83,84,65,86,65,77,32,69,77
	DATA BYTE 19,3,26,77,65,73,79,82,32,78,85,77,69,82,79,32,69,32,67,79,78,83,69,71,85,73,82,65,77
	DATA BYTE 18,10,1,27
	DATA BYTE 21,5,21,83,73,84,73,65,82,32,78,79,83,83,79,32,80,76,65,78,69,84,65,46
	DATA BYTE 23,2,28,67,79,77,79,32,85,76,84,73,77,79,32,82,69,67,85,82,83,79,44,32,79,83,32,84,82,69,83
	DATA BYTE 22,7,1,27
	DATA BYTE 22,28,1,28
	DATA BYTE 25,1,31,77,69,76,72,79,82,69,83,32,80,73,76,79,84,79,83,32,68,65,32,84,69,82,82,65,32,70,79,82,65,77
	DATA BYTE 27,2,28,69,78,86,73,65,68,79,83,32,78,85,77,65,32,77,73,83,83,65,79,32,83,85,73,67,73,68,65
	DATA BYTE 26,20,1,26
	DATA BYTE 26,27,1,27
	DATA BYTE 29,3,26,80,65,82,65,32,79,32,83,73,83,84,69,77,65,32,89,65,82,73,83,44,32,80,65,82,65
	DATA BYTE 31,2,27,84,69,78,84,65,82,32,68,69,82,82,79,84,65,82,32,71,79,82,70,32,69,77,32,83,85,65
	DATA BYTE 33,9,13,80,82,79,80,82,73,65,32,67,65,83,65,46
	DATA BYTE 32,11,1,27
	DATA BYTE 35,3,25,65,32,77,73,83,83,65,79,58,32,65,76,67,65,78,29,65,82,32,89,65,82,73,83,44
	DATA BYTE 34,9,1,26
	DATA BYTE 37,1,29,80,65,83,83,65,82,32,80,79,82,32,86,85,76,67,65,78,44,32,79,32,67,73,78,84,85,82,65,79
	DATA BYTE 36,28,1,26
	DATA BYTE 39,3,25,68,69,32,65,83,84,69,82,79,73,68,69,83,44,32,68,69,83,84,82,85,73,82,32,79
	DATA BYTE 38,11,1,27
	DATA BYTE 41,1,30,71,69,82,65,68,79,82,32,68,69,32,69,83,67,85,68,79,83,32,69,77,32,65,84,76,65,78,84,73,83
	DATA BYTE 43,4,24,80,65,82,65,32,67,72,69,71,65,82,32,65,32,71,79,82,70,70,73,79,78,32,69
	DATA BYTE 45,3,26,68,69,83,84,82,85,73,82,32,71,79,82,70,32,69,77,32,83,85,65,32,66,65,83,69,33
	DATA BYTE 47,1,29,66,79,65,32,83,79,82,84,69,44,32,86,79,67,69,83,32,83,65,79,32,65,32,85,76,84,73,77,65
	DATA BYTE 46,15,1,28
	DATA BYTE 46,19,1,26
	DATA BYTE 46,24,1,27
	DATA BYTE 49,6,19,69,83,80,69,82,65,78,29,65,32,68,65,32,84,69,82,82,65,33

credits_text:
	DATA BYTE 1,6,20,81,85,69,77,32,70,69,90,32,83,80,65,67,69,32,66,76,65,83,84
	DATA BYTE 3,2,27,80,82,79,71,82,65,77,65,29,65,79,58,32,83,65,85,76,79,32,83,65,78,84,73,65,71,79
	DATA BYTE 2,11,1,26
	DATA BYTE 5,4,24,71,82,65,70,73,67,79,83,58,32,83,65,85,76,79,32,83,65,78,84,73,65,71,79
	DATA BYTE 4,6,1,27
	DATA BYTE 7,5,21,65,85,68,73,79,58,32,83,65,85,76,79,32,83,65,78,84,73,65,71,79
	DATA BYTE 9,6,19,80,82,79,68,85,29,65,79,58,32,76,77,83,32,82,69,84,82,79
	DATA BYTE 8,12,1,26
	DATA BYTE 11,4,23,80,85,66,76,73,67,65,29,65,79,58,32,70,65,76,67,79,78,32,83,79,70,84
	DATA BYTE 10,12,1,26
	DATA BYTE 13,2,27,84,69,83,84,69,83,58,32,77,65,82,67,79,83,32,70,69,76,73,80,69,44,32,76,85,67,65
	DATA BYTE 15,1,29,86,79,76,79,84,65,79,44,32,76,85,67,65,83,32,77,85,78,72,79,90,44,32,70,73,76,73,80,69
	DATA BYTE 14,6,1,26
	DATA BYTE 17,11,9,71,82,65,67,73,79,76,76,73
	DATA BYTE 19,3,25,65,71,82,65,68,69,67,73,77,69,78,84,79,83,32,69,83,80,69,67,73,65,73,83,58
	DATA BYTE 21,5,21,87,65,82,80,90,79,78,69,44,32,67,65,78,65,76,51,44,32,82,73,79
	DATA BYTE 23,5,21,82,69,84,82,79,71,65,77,69,83,44,32,83,72,77,85,80,83,66,82,44
	DATA BYTE 25,2,27,77,65,82,67,79,83,32,70,69,76,73,80,69,44,32,82,65,70,65,69,76,32,76,73,77,65,44
	DATA BYTE 27,4,23,80,86,32,82,65,68,84,75,69,44,32,89,85,82,73,32,68,65,86,73,76,65,44
	DATA BYTE 26,21,1,27
	DATA BYTE 29,1,29,84,72,73,65,71,79,32,77,73,78,69,73,82,79,44,32,76,85,67,65,83,32,77,85,78,72,79,90,44
	DATA BYTE 31,6,20,71,85,83,84,65,86,79,32,86,65,76,68,73,86,73,69,83,83,79,44
	DATA BYTE 33,5,22,77,65,82,73,79,32,78,69,83,82,79,67,75,83,44,32,67,65,82,73,78,65
	DATA BYTE 35,5,21,86,79,76,79,84,65,79,44,32,76,85,67,65,32,69,32,82,65,86,73,44
	DATA BYTE 34,10,1,26
	DATA BYTE 37,3,26,84,79,68,79,83,32,79,83,32,65,77,73,71,79,83,32,81,85,69,32,83,69,77,80,82,69
	DATA BYTE 39,2,28,65,67,82,69,68,73,84,65,82,65,77,32,78,65,32,70,65,76,67,79,78,32,83,79,70,84,32,69
	DATA BYTE 41,3,26,86,79,67,69,44,32,81,85,69,32,80,82,69,83,84,73,71,73,79,85,32,78,79,83,83,79
	DATA BYTE 40,6,1,28
	DATA BYTE 43,12,8,84,82,65,66,65,76,72,79
	DATA BYTE 45,3,26,86,73,83,73,84,69,32,65,32,70,65,76,67,79,78,83,79,70,84,46,67,79,77,46,66,82
	DATA BYTE 47,8,16,80,65,82,65,32,78,79,86,79,83,32,74,79,71,79,83
	DATA BYTE 49,2,28,65,80,79,73,69,77,32,83,69,77,80,82,69,32,79,83,32,73,78,68,73,69,32,71,65,77,69,83
	DATA BYTE 51,10,12,66,82,65,83,73,76,69,73,82,79,83,33

	' v0.33: a PRINT do CVBasic so endereca $2000-$27FF; para a segunda
	' nametable o texto entra por VPOKE em $2800. A tela fica desligada
	' durante a montagem e cada linha termina com WAIT para drenar a fila.
scroll_clear_nt2: PROCEDURE
	' Segunda nametable + atributos; a primeira e limpa pela CLS.
	#tw = $2800
	FOR r = 0 TO 29
		FOR q = 0 TO 31
			VPOKE #tw,32
			#tw = #tw + 1
		NEXT q
		WAIT
	NEXT r
	#tw = $2BC0
	FOR q = 0 TO 63
		VPOKE #tw,0
		IF (q AND 15) = 15 THEN WAIT
	NEXT q
	END

scroll_set_tail_attrs: PROCEDURE
	' O texto que fica em $2000 inicia invisivel (pal1/preto) e acende
	' junto com o segundo trecho, depois que $2000 nao esta mais na tela.
	#tw = $23C0
	FOR q = 0 TO 63
		VPOKE #tw,$55
		IF (q AND 15) = 15 THEN WAIT
	NEXT q
	END

scroll_draw_history: PROCEDURE
	RESTORE history_text
	FOR c = 0 TO 39
		READ BYTE r
		READ BYTE e2
		READ BYTE sk
		IF r < 30 THEN
			#tw = $2800 + r * 32 + e2
		ELSE
			r = r - 30
			#tw = $2000 + r * 32 + e2
		END IF
		FOR q = 0 TO sk - 1
			READ BYTE e
			VPOKE #tw,e
			#tw = #tw + 1
		NEXT q
		WAIT
	NEXT c
	END

scroll_draw_credits: PROCEDURE
	RESTORE credits_text
	FOR c = 0 TO 33
		READ BYTE r
		READ BYTE e2
		READ BYTE sk
		IF r < 30 THEN
			#tw = $2800 + r * 32 + e2
		ELSE
			r = r - 30
			#tw = $2000 + r * 32 + e2
		END IF
		FOR q = 0 TO sk - 1
			READ BYTE e
			VPOKE #tw,e
			#tw = #tw + 1
		NEXT q
		WAIT
	NEXT c
	END

history_screen: PROCEDURE
	SCREEN DISABLE
	FOR c = 0 TO 63
		SPRITE c,$f0,0,0,0
	NEXT c
	POKE $1C,$00		' fonte Saulo; os acentos sao tiles na linha vazia acima
	PALETTE LOAD game_palette_title
	CLS
	GOSUB scroll_clear_nt2
	GOSUB scroll_draw_history
	GOSUB scroll_set_tail_attrs
	#bk = 0
	SCROLL 0,#bk
	VPOKE $3F01,$0F
	VPOKE $3F02,$0F
	VPOKE $3F03,$0F
	VPOKE $3F07,$0F
	WAIT
	SCREEN ENABLE
	RESTORE fade_tbl
	FOR r = 0 TO 6
		READ BYTE e
		READ BYTE e
		VPOKE $3F03,e
		FOR q = 0 TO 3
			WAIT
			IF CONT1.KEY = 11 THEN GOTO hs_fim
		NEXT q
	NEXT r
	' Primeiro trecho: 256 pixels ate $2800 ocupar a tela inteira.
	FOR r = 0 TO 1
		FOR q = 0 TO 127
			WAIT
			IF CONT1.KEY = 11 THEN GOTO hs_fim
			#bk = #bk + 1
			SCROLL 0,#bk
			WAIT
			IF CONT1.KEY = 11 THEN GOTO hs_fim
		NEXT q
	NEXT r
	' $2000 ja esta fora da tela; revela o trecho final que ficou escondido.
	VPOKE $3F07,$30
	WAIT
	' Restante: 204 pixels; terminamos em #bk=460, antes de $2800 repetir.
	FOR q = 0 TO 203
		WAIT
		IF CONT1.KEY = 11 THEN GOTO hs_fim
		#bk = #bk + 1
		SCROLL 0,#bk
		WAIT
		IF CONT1.KEY = 11 THEN GOTO hs_fim
	NEXT q
hs_fim:
	SCREEN DISABLE
	POKE $1C,$00
	#bk = 0
	SCROLL 0,#bk
	WAIT
	END

	CHRROM 0
	'
	' Estrelas do fundo (sheet estrelas-cinzas.png do Saulo)
	' idx 0 = vazio (cls preenche com 0). cores: 1=azul 2=branco 3=cinza
	'
	CHRROM PATTERN 0
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP "........"
	BITMAP "........"
	BITMAP "......3."
	BITMAP ".....323"
	BITMAP "......3."
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "....2..."
	BITMAP "........"
	BITMAP "..3....."
	BITMAP "........"
	BITMAP "........"

	BITMAP "........"
	BITMAP "........"
	BITMAP "...3...."
	BITMAP "..323..."
	BITMAP "...3...."
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP "........"
	BITMAP "........"
	BITMAP ".3......"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP "........"
	BITMAP "....1..."
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP ".....3.."
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP "........"
	BITMAP "........"
	BITMAP "..3....."
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP "........"
	BITMAP "........"
	BITMAP ".....3.."
	BITMAP "..1....."
	BITMAP "........"
	BITMAP "....1..."
	BITMAP "........"
	BITMAP "........"

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "......3."
	BITMAP "........"
	BITMAP "........"

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "....2..."
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "......2."
	BITMAP "........"
	BITMAP "........"

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "....1..."
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP "........"
	BITMAP "........"
	BITMAP ".....3.."
	BITMAP "....323."
	BITMAP ".....3.."
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP ".....1.."
	BITMAP "........"

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "..2.1..."
	BITMAP "......33"

	BITMAP "........"
	BITMAP "........"
	BITMAP "..3....."
	BITMAP "...1...."
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP "........"
	BITMAP "..3....."
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "....1..."
	BITMAP "........"
	BITMAP "........"

	BITMAP "........"
	BITMAP "........"
	BITMAP ".1......"
	BITMAP "....3..."
	BITMAP "........"
	BITMAP "..3....."
	BITMAP "........"
	BITMAP "........"

	BITMAP "........"
	BITMAP "........"
	BITMAP ".....1.."
	BITMAP "........"
	BITMAP "........"
	BITMAP "...3...."
	BITMAP "........"
	BITMAP "........"

	BITMAP "........"
	BITMAP "........"
	BITMAP "..2....."
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "..1....."
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "....3..."
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "..2....."
	BITMAP "........"
	BITMAP ".....1.."
	BITMAP "........"
	BITMAP "........"

	BITMAP "........"
	BITMAP "........"
	BITMAP "....3..."
	BITMAP "...2...."
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP "........"
	BITMAP "........"
	BITMAP ".2......"
	BITMAP "........"
	BITMAP ".....3.."
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"



	' ===== FONTE SAULO v0.17 — INICIO (gera_fonte.py) =====
	' spritefont 16x6 do Saulo (uploads/Sprite_font.png). pixels '3' (2
	' planos) = mesmo estilo da fonte CVBasic -> paleta identica.
	' ASCII 32-95: digitos 0-9, A-Z e pontuacao mapeada.
	CHRROM PATTERN 32

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP "...333.."
	BITMAP "...333.."
	BITMAP "...333.."
	BITMAP "...33..."
	BITMAP "...33..."
	BITMAP "........"
	BITMAP "...33..."
	BITMAP "...33..."

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP "33333333"
	BITMAP "33333333"
	BITMAP "33333333"
	BITMAP "33333333"
	BITMAP "33333333"
	BITMAP "33333333"
	BITMAP "33333333"
	BITMAP "33333333"

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "....3..."
	BITMAP "...3...."
	BITMAP "........"

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "..3..3.."
	BITMAP "...33..."
	BITMAP "...33..."
	BITMAP "..3..3.."
	BITMAP "........"

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "...33..."
	BITMAP "...33..."
	BITMAP "....3..."

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP "..333..."
	BITMAP ".3..33.."
	BITMAP "33...33."
	BITMAP "33...33."
	BITMAP "33...33."
	BITMAP ".33..3.."
	BITMAP "..333..."
	BITMAP "........"

	BITMAP "...33..."
	BITMAP "...33..."
	BITMAP "...33..."
	BITMAP "...33..."
	BITMAP "...33..."
	BITMAP "...33..."
	BITMAP ".333333."
	BITMAP "........"

	BITMAP ".33333.."
	BITMAP "33...33."
	BITMAP "....333."
	BITMAP "..3333.."
	BITMAP ".3333..."
	BITMAP "333....."
	BITMAP "3333333."
	BITMAP "........"

	BITMAP ".333333."
	BITMAP "....33.."
	BITMAP "...33..."
	BITMAP "..3333.."
	BITMAP ".....33."
	BITMAP "33...33."
	BITMAP ".33333.."
	BITMAP "........"

	BITMAP "...333.."
	BITMAP "..3333.."
	BITMAP ".33.33.."
	BITMAP "33..33.."
	BITMAP "3333333."
	BITMAP "....33.."
	BITMAP "....33.."
	BITMAP "........"

	BITMAP "333333.."
	BITMAP "33......"
	BITMAP "333333.."
	BITMAP ".....33."
	BITMAP ".....33."
	BITMAP "33...33."
	BITMAP ".33333.."
	BITMAP "........"

	BITMAP "..3333.."
	BITMAP ".33....."
	BITMAP "33......"
	BITMAP "333333.."
	BITMAP "33...33."
	BITMAP "33...33."
	BITMAP ".33333.."
	BITMAP "........"

	BITMAP "3333333."
	BITMAP "33...33."
	BITMAP "....33.."
	BITMAP "...33..."
	BITMAP "..33...."
	BITMAP "..33...."
	BITMAP "..33...."
	BITMAP "........"

	BITMAP ".33333.."
	BITMAP "33...33."
	BITMAP "33...33."
	BITMAP ".33333.."
	BITMAP "33...33."
	BITMAP "33...33."
	BITMAP ".33333.."
	BITMAP "........"

	BITMAP ".33333.."
	BITMAP "33...33."
	BITMAP "33...33."
	BITMAP ".333333."
	BITMAP ".....33."
	BITMAP "....33.."
	BITMAP ".3333..."
	BITMAP "........"

	BITMAP "...33..."
	BITMAP "...33..."
	BITMAP "........"
	BITMAP "........"
	BITMAP "...33..."
	BITMAP "...33..."
	BITMAP "........"
	BITMAP "........"

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP "...3...."
	BITMAP "..33...."
	BITMAP ".333...."
	BITMAP "33333333"
	BITMAP "33333333"
	BITMAP ".333...."
	BITMAP "..33...."
	BITMAP "...3...."

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP "..3333.."
	BITMAP ".33..33."
	BITMAP ".33..33."
	BITMAP ".....33."
	BITMAP "...33..."
	BITMAP "........"
	BITMAP "...33..."
	BITMAP "...33..."

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP "..333..."
	BITMAP ".33.33.."
	BITMAP "33...33."
	BITMAP "33...33."
	BITMAP "3333333."
	BITMAP "33...33."
	BITMAP "33...33."
	BITMAP "........"

	BITMAP "333333.."
	BITMAP "33...33."
	BITMAP "33...33."
	BITMAP "333333.."
	BITMAP "33...33."
	BITMAP "33...33."
	BITMAP "333333.."
	BITMAP "........"

	BITMAP "..3333.."
	BITMAP ".33..33."
	BITMAP "33......"
	BITMAP "33......"
	BITMAP "33......"
	BITMAP ".33..33."
	BITMAP "..3333.."
	BITMAP "........"

	BITMAP "33333..."
	BITMAP "33..33.."
	BITMAP "33...33."
	BITMAP "33...33."
	BITMAP "33...33."
	BITMAP "33..33.."
	BITMAP "33333..."
	BITMAP "........"

	BITMAP "3333333."
	BITMAP "33......"
	BITMAP "33......"
	BITMAP "333333.."
	BITMAP "33......"
	BITMAP "33......"
	BITMAP "3333333."
	BITMAP "........"

	BITMAP "3333333."
	BITMAP "33......"
	BITMAP "33......"
	BITMAP "333333.."
	BITMAP "33......"
	BITMAP "33......"
	BITMAP "33......"
	BITMAP "........"

	BITMAP "..33333."
	BITMAP ".33....."
	BITMAP "33......"
	BITMAP "33..333."
	BITMAP "33...33."
	BITMAP ".33..33."
	BITMAP "..33333."
	BITMAP "........"

	BITMAP "33...33."
	BITMAP "33...33."
	BITMAP "33...33."
	BITMAP "3333333."
	BITMAP "33...33."
	BITMAP "33...33."
	BITMAP "33...33."
	BITMAP "........"

	BITMAP ".333333."
	BITMAP "...33..."
	BITMAP "...33..."
	BITMAP "...33..."
	BITMAP "...33..."
	BITMAP "...33..."
	BITMAP ".333333."
	BITMAP "........"

	BITMAP "...3333."
	BITMAP ".....33."
	BITMAP ".....33."
	BITMAP ".....33."
	BITMAP "33...33."
	BITMAP "33...33."
	BITMAP ".33333.."
	BITMAP "........"

	BITMAP "33...33."
	BITMAP "33..33.."
	BITMAP "33.33..."
	BITMAP "3333...."
	BITMAP "33333..."
	BITMAP "33.333.."
	BITMAP "33..333."
	BITMAP "........"

	BITMAP ".33....."
	BITMAP ".33....."
	BITMAP ".33....."
	BITMAP ".33....."
	BITMAP ".33....."
	BITMAP ".33....."
	BITMAP ".333333."
	BITMAP "........"

	BITMAP "33...33."
	BITMAP "333.333."
	BITMAP "3333333."
	BITMAP "3333333."
	BITMAP "33.3.33."
	BITMAP "33...33."
	BITMAP "33...33."
	BITMAP "........"

	BITMAP "33...33."
	BITMAP "333..33."
	BITMAP "3333.33."
	BITMAP "3333333."
	BITMAP "33.3333."
	BITMAP "33..333."
	BITMAP "33...33."
	BITMAP "........"

	BITMAP ".33333.."
	BITMAP "33...33."
	BITMAP "33...33."
	BITMAP "33...33."
	BITMAP "33...33."
	BITMAP "33...33."
	BITMAP ".33333.."
	BITMAP "........"

	BITMAP "333333.."
	BITMAP "33...33."
	BITMAP "33...33."
	BITMAP "33...33."
	BITMAP "333333.."
	BITMAP "33......"
	BITMAP "33......"
	BITMAP "........"

	BITMAP ".33333.."
	BITMAP "33...33."
	BITMAP "33...33."
	BITMAP "33...33."
	BITMAP "33.3333."
	BITMAP "33..33.."
	BITMAP ".3333.3."
	BITMAP "........"

	BITMAP "333333.."
	BITMAP "33...33."
	BITMAP "33...33."
	BITMAP "33..333."
	BITMAP "33333..."
	BITMAP "33.333.."
	BITMAP "33..333."
	BITMAP "........"

	BITMAP ".3333..."
	BITMAP "33..33.."
	BITMAP "33......"
	BITMAP ".33333.."
	BITMAP ".....33."
	BITMAP "33...33."
	BITMAP ".33333.."
	BITMAP "........"

	BITMAP ".333333."
	BITMAP "...33..."
	BITMAP "...33..."
	BITMAP "...33..."
	BITMAP "...33..."
	BITMAP "...33..."
	BITMAP "...33..."
	BITMAP "........"

	BITMAP "33...33."
	BITMAP "33...33."
	BITMAP "33...33."
	BITMAP "33...33."
	BITMAP "33...33."
	BITMAP "33...33."
	BITMAP ".33333.."
	BITMAP "........"

	BITMAP "33...33."
	BITMAP "33...33."
	BITMAP "33...33."
	BITMAP "333.333."
	BITMAP ".33333.."
	BITMAP "..333..."
	BITMAP "...3...."
	BITMAP "........"

	BITMAP "33...33."
	BITMAP "33...33."
	BITMAP "33.3.33."
	BITMAP "3333333."
	BITMAP "3333333."
	BITMAP "333.333."
	BITMAP "33...33."
	BITMAP "........"

	BITMAP "33...33."
	BITMAP "333.333."
	BITMAP ".33333.."
	BITMAP "..333..."
	BITMAP ".33333.."
	BITMAP "333.333."
	BITMAP "33...33."
	BITMAP "........"

	BITMAP ".33..33."
	BITMAP ".33..33."
	BITMAP ".33..33."
	BITMAP "..3333.."
	BITMAP "...33..."
	BITMAP "...33..."
	BITMAP "...33..."
	BITMAP "........"

	BITMAP "3333333."
	BITMAP "....333."
	BITMAP "...333.."
	BITMAP "..333..."
	BITMAP ".333...."
	BITMAP "333....."
	BITMAP "3333333."
	BITMAP "........"

	BITMAP "........"
	BITMAP ".333...."
	BITMAP "...3...."
	BITMAP "...3...."
	BITMAP "...3...."
	BITMAP "...3...."
	BITMAP ".333...."
	BITMAP "........"

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP "...33..."
	BITMAP "..3333.."
	BITMAP ".333333."
	BITMAP "33333333"
	BITMAP "...33..."
	BITMAP "...33..."
	BITMAP "...33..."
	BITMAP "...33..."

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	' --- digitos do placar (sprites 8x16): par = glifo, impar = vazio;
	'     T = 192 + 2*d (byte OAM par -> tabela $0000, pares T/T+1)
	CHRROM PATTERN 192

	BITMAP "..333..."
	BITMAP ".3..33.."
	BITMAP "33...33."
	BITMAP "33...33."
	BITMAP "33...33."
	BITMAP ".33..3.."
	BITMAP "..333..."
	BITMAP "........"

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP "...33..."
	BITMAP "...33..."
	BITMAP "...33..."
	BITMAP "...33..."
	BITMAP "...33..."
	BITMAP "...33..."
	BITMAP ".333333."
	BITMAP "........"

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP ".33333.."
	BITMAP "33...33."
	BITMAP "....333."
	BITMAP "..3333.."
	BITMAP ".3333..."
	BITMAP "333....."
	BITMAP "3333333."
	BITMAP "........"

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP ".333333."
	BITMAP "....33.."
	BITMAP "...33..."
	BITMAP "..3333.."
	BITMAP ".....33."
	BITMAP "33...33."
	BITMAP ".33333.."
	BITMAP "........"

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP "...333.."
	BITMAP "..3333.."
	BITMAP ".33.33.."
	BITMAP "33..33.."
	BITMAP "3333333."
	BITMAP "....33.."
	BITMAP "....33.."
	BITMAP "........"

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP "333333.."
	BITMAP "33......"
	BITMAP "333333.."
	BITMAP ".....33."
	BITMAP ".....33."
	BITMAP "33...33."
	BITMAP ".33333.."
	BITMAP "........"

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP "..3333.."
	BITMAP ".33....."
	BITMAP "33......"
	BITMAP "333333.."
	BITMAP "33...33."
	BITMAP "33...33."
	BITMAP ".33333.."
	BITMAP "........"

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP "3333333."
	BITMAP "33...33."
	BITMAP "....33.."
	BITMAP "...33..."
	BITMAP "..33...."
	BITMAP "..33...."
	BITMAP "..33...."
	BITMAP "........"

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP ".33333.."
	BITMAP "33...33."
	BITMAP "33...33."
	BITMAP ".33333.."
	BITMAP "33...33."
	BITMAP "33...33."
	BITMAP ".33333.."
	BITMAP "........"

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP ".33333.."
	BITMAP "33...33."
	BITMAP "33...33."
	BITMAP ".333333."
	BITMAP ".....33."
	BITMAP "....33.."
	BITMAP ".3333..."
	BITMAP "........"

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	' --- GAME OVER estilizado (cells 80-87 da folha)
	CHRROM PATTERN 214

	BITMAP ".3333333"
	BITMAP "33333333"
	BITMAP "33.....3"
	BITMAP "33..3333"
	BITMAP "33..3..3"
	BITMAP "33..33.3"
	BITMAP "33.....3"
	BITMAP ".3333333"

	BITMAP "33333333"
	BITMAP "33333333"
	BITMAP "3......3"
	BITMAP "3..333.3"
	BITMAP "3......3"
	BITMAP "3..333.3"
	BITMAP "3..333.3"
	BITMAP "33333333"

	BITMAP "33333333"
	BITMAP "33333333"
	BITMAP "3..333.3"
	BITMAP "3...3..3"
	BITMAP "3..3.3.3"
	BITMAP "3..333.3"
	BITMAP "3..333.3"
	BITMAP "33333333"

	BITMAP "33333333"
	BITMAP "33333333"
	BITMAP "3.....33"
	BITMAP "3..33333"
	BITMAP "3.....33"
	BITMAP "3..33333"
	BITMAP "3.....33"
	BITMAP "33333333"

	BITMAP "33333333"
	BITMAP "33333333"
	BITMAP "3......3"
	BITMAP "3..333.3"
	BITMAP "3..333.3"
	BITMAP "3..333.3"
	BITMAP "3......3"
	BITMAP "33333333"

	BITMAP "33333333"
	BITMAP "33333333"
	BITMAP "3..333.3"
	BITMAP "3..333.3"
	BITMAP "3..33.33"
	BITMAP "33..3.33"
	BITMAP "33...333"
	BITMAP "33333333"

	BITMAP "33333333"
	BITMAP "33333333"
	BITMAP "3......3"
	BITMAP "3..33333"
	BITMAP "3......3"
	BITMAP "3..33333"
	BITMAP "3......3"
	BITMAP "33333333"

	BITMAP "3333333."
	BITMAP "33333333"
	BITMAP "3.....33"
	BITMAP "3..333.3"
	BITMAP "3.....33"
	BITMAP "3..3.333"
	BITMAP "3..33.33"
	BITMAP "3333333."

	' --- decor/mini-labels reservados: BONUS parts, 1UP, <|
	CHRROM PATTERN 224

	BITMAP "......3."
	BITMAP ".33..3.3"
	BITMAP ".3.3...."
	BITMAP ".3.3..3."
	BITMAP ".33..3.3"
	BITMAP ".3.3.3.3"
	BITMAP ".3.3.3.3"
	BITMAP ".33...3."

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP ".3...3.3"
	BITMAP ".33..3.3"
	BITMAP ".3.3.3.3"
	BITMAP ".3.3.3.3"
	BITMAP ".3.3..3."

	BITMAP "........"
	BITMAP "........"
	BITMAP ".....33."
	BITMAP ".333.33."
	BITMAP ".3....3."
	BITMAP "..33..3."
	BITMAP "...3...."
	BITMAP ".33...3."

	BITMAP "........"
	BITMAP "........"
	BITMAP "...33..."
	BITMAP "...33..."
	BITMAP "....3..."
	BITMAP "....3..."
	BITMAP "....3..."
	BITMAP "...333.."

	BITMAP "........"
	BITMAP "........"
	BITMAP "3.3.33.."
	BITMAP "3.3.3.3."
	BITMAP "3.3.3.3."
	BITMAP "3.3.33.."
	BITMAP "3.3.3..."
	BITMAP ".3..3..."

	BITMAP "..33...."
	BITMAP "..333..."
	BITMAP "..3333.."
	BITMAP "..33333."
	BITMAP "..33333."
	BITMAP "..3333.."
	BITMAP "..333..."
	BITMAP "..33...."

	'
	' v0.28: desvira + idle da nave. Saiu do banco 0 (estourou 97 bytes
	' com as 5 fases + fim de jogo); mesmo padrao do mb_frame/boss_frame
	' (proc quente chamado do game_loop com BANK SELECT 1/0).
	'
anim_idle:	PROCEDURE	' soltou o direcional: desvira (6,5,4) e faz idle
	IF ret = 0 THEN
		IF dir <> 0 THEN
			ret = 1
			an = 0
		END IF
	END IF
	IF ret <> 0 THEN
		an = an + 1
		IF an >= 12 THEN
			ret = 0
			dir = 0
			an = 0
		ELSE
			slot = 6 - an / 4
		END IF
	ELSE
		an = an + 1
		IF an > 19 THEN an = 0
		slot = (an / 5) % 4
	END IF
	END

	' ===== FONTE SAULO v0.17 — FIM =====

	' v0.28: acentos da spritefont do Saulo (tecnica dele: glifo na
	' "linha logo acima da letra acentuada") em 3 tiles livres da
	' pagina 0. 26 = TIL (cell 13), 27 = AGUDO (cell 11),
	' 28 = CIRCUNFLEXO e 29 = Ç. Uso: VPOKE no slot (linha-1, col); Ç tem glifo proprio.
	' v0.30: padrao dedicado de Ç; tile 96 e a arte do logo, portanto nao e reutilizado.
	CHRROM PATTERN 29
	BITMAP "..3333.."
	BITMAP ".33..33."
	BITMAP "33......"
	BITMAP "33......"
	BITMAP ".33..33."
	BITMAP "..3333.."
	BITMAP "...33..."
	BITMAP "....3..."

	CHRROM PATTERN 26
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "...3.3.."
	BITMAP "..3.3..."
	BITMAP "........"
	CHRROM PATTERN 27
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "...3...."
	BITMAP "..3....."
	BITMAP "........"
	CHRROM PATTERN 28
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "...3...."
	BITMAP "..3.3..."
	BITMAP "........"

	CHRROM PATTERN 96

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "...33333"
	BITMAP "...33333"
	BITMAP "..333333"
	BITMAP "..333..."

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "33333.33"
	BITMAP "33333.33"
	BITMAP "33333.33"
	BITMAP "......33"

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "3333333."
	BITMAP "3333333."
	BITMAP "33333333"
	BITMAP "3.....33"

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "...33333"
	BITMAP "...33333"
	BITMAP "3.333333"
	BITMAP "3.333..."

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "333....3"
	BITMAP "333....3"
	BITMAP "33333.33"
	BITMAP "..333.33"

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "..333333"
	BITMAP "..333333"
	BITMAP "3.333333"
	BITMAP "3.333..."

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "33333..."
	BITMAP "33333..."
	BITMAP "33333..."
	BITMAP "........"

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "..3.1..."
	BITMAP "......22"

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP ".2......"
	BITMAP "........"
	BITMAP "....3..."
	BITMAP "........"
	BITMAP "11111222"

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP ".2......"
	BITMAP "....1..."
	BITMAP "........"
	BITMAP ".1112111"
	BITMAP "22111311"

	BITMAP "........"
	BITMAP "....3.1."
	BITMAP ".......1"
	BITMAP "..2....."
	BITMAP "....1.11"
	BITMAP ".....111"
	BITMAP "11111132"
	BITMAP "22221112"

	BITMAP "........"
	BITMAP "..1....."
	BITMAP "1...3..."
	BITMAP "1111.1.."
	BITMAP "111111.."
	BITMAP "222211.."
	BITMAP "2332211."
	BITMAP "2222211."

	BITMAP "........"
	BITMAP "........"
	BITMAP "..3....."
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP "..333333"
	BITMAP "..333333"
	BITMAP "...22222"
	BITMAP "........"
	BITMAP "..222222"
	BITMAP "..222222"
	BITMAP "..222222"
	BITMAP "........"

	BITMAP "333...33"
	BITMAP "333...33"
	BITMAP "22222.22"
	BITMAP "..222.22"
	BITMAP "22222.22"
	BITMAP "22222.22"
	BITMAP "222...22"
	BITMAP "........"

	BITMAP "3.....33"
	BITMAP "3.....33"
	BITMAP "22222222"
	BITMAP "2222222."
	BITMAP "2......."
	BITMAP "2......."
	BITMAP "2......."
	BITMAP "........"

	BITMAP "3.333..."
	BITMAP "3.333..."
	BITMAP "2.222222"
	BITMAP "..222222"
	BITMAP "..222..."
	BITMAP "..222..."
	BITMAP "..222..."
	BITMAP "........"

	BITMAP "..333.33"
	BITMAP "..333.33"
	BITMAP "22222.22"
	BITMAP "22222.22"
	BITMAP "..222.22"
	BITMAP "..222.22"
	BITMAP "..222..2"
	BITMAP "........"

	BITMAP "3......."
	BITMAP "3......."
	BITMAP "2......."
	BITMAP "2.....22"
	BITMAP "22222222"
	BITMAP "22222222"
	BITMAP "2222222."
	BITMAP "........"

	BITMAP "..333333"
	BITMAP "..333333"
	BITMAP "..222222"
	BITMAP "2.222..."
	BITMAP "2.222222"
	BITMAP "2.222222"
	BITMAP "..222222"
	BITMAP "........"

	BITMAP "333....."
	BITMAP "333....."
	BITMAP "222....."
	BITMAP "........"
	BITMAP "22222..."
	BITMAP "22222..."
	BITMAP "22222..."
	BITMAP "........"

	BITMAP "12222112"
	BITMAP "..111111"
	BITMAP "........"
	BITMAP ".....2.."
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP "23222311"
	BITMAP "11111111"
	BITMAP "...111.."
	BITMAP ".1......"
	BITMAP ".....1.."
	BITMAP "..3....."
	BITMAP "........"
	BITMAP "........"

	BITMAP "12322222"
	BITMAP "11111111"
	BITMAP "..1111.."
	BITMAP "........"
	BITMAP ".3....2."
	BITMAP "...1...."
	BITMAP "........"
	BITMAP "........"

	BITMAP "21312322"
	BITMAP "11111112"
	BITMAP ".1...111"
	BITMAP "....2.11"
	BITMAP "..1....."
	BITMAP "......21"
	BITMAP "...3.1.."
	BITMAP "........"

	BITMAP "2223211."
	BITMAP "2322211."
	BITMAP "222211.."
	BITMAP "111111.."
	BITMAP "1111...."
	BITMAP "..3.1..."
	BITMAP ".1......"
	BITMAP "........"

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "..1....."
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "....3333"
	BITMAP "....3222"
	BITMAP "....3222"
	BITMAP "....3222"
	BITMAP "....3222"

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "33333333"
	BITMAP "22222222"
	BITMAP "22222222"
	BITMAP "22222222"
	BITMAP "22222222"

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "3..33333"
	BITMAP "23.32222"
	BITMAP "23.32222"
	BITMAP "23.32222"
	BITMAP "23.32222"

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "3......."
	BITMAP "3......."
	BITMAP "3......."
	BITMAP "3......."
	BITMAP "3......."

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP ".3333333"
	BITMAP "32222222"
	BITMAP "32222222"
	BITMAP "32222222"
	BITMAP "32222222"

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "333333.."
	BITMAP "2222223."
	BITMAP "2222223."
	BITMAP "2222223."
	BITMAP "2222223."

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "33333.33"
	BITMAP "22223.32"
	BITMAP "22223.32"
	BITMAP "22223.32"
	BITMAP "22223.32"

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "3333..33"
	BITMAP "2223..32"
	BITMAP "2223..32"
	BITMAP "2223..32"
	BITMAP "2223..32"

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "3333...."
	BITMAP "2223...."
	BITMAP "2223...."
	BITMAP "2223...."
	BITMAP "2223...."

	BITMAP "....3222"
	BITMAP "....3222"
	BITMAP "....3222"
	BITMAP "....3222"
	BITMAP "....3222"
	BITMAP "....3222"
	BITMAP "....3222"
	BITMAP "....3222"

	BITMAP "23332222"
	BITMAP "3...3222"
	BITMAP "3...3222"
	BITMAP "3...3222"
	BITMAP "3...3222"
	BITMAP "3...3222"
	BITMAP "23332222"
	BITMAP "22222222"

	BITMAP "23.32222"
	BITMAP "23.32222"
	BITMAP "23.32222"
	BITMAP "23.32222"
	BITMAP "23.32222"
	BITMAP "23.32222"
	BITMAP "23.32222"
	BITMAP "3..32111"

	BITMAP "3......."
	BITMAP "3......."
	BITMAP "3......."
	BITMAP "3......."
	BITMAP "3......."
	BITMAP "3......."
	BITMAP "3......."
	BITMAP "3......."

	BITMAP "32222222"
	BITMAP "32222222"
	BITMAP "32222233"
	BITMAP "322223.."
	BITMAP "322223.."
	BITMAP "322223.."
	BITMAP "322223.."
	BITMAP "311113.."

	BITMAP "2222223."
	BITMAP "2222223."
	BITMAP "3222223."
	BITMAP ".322223."
	BITMAP ".322223."
	BITMAP ".322223."
	BITMAP ".322223."
	BITMAP ".311113."

	BITMAP "32222222"
	BITMAP "32222222"
	BITMAP "32222233"
	BITMAP "322223.."
	BITMAP "322223.."
	BITMAP "32222233"
	BITMAP "32222222"
	BITMAP "31111111"

	BITMAP "22223.32"
	BITMAP "22223.32"
	BITMAP "33333.33"
	BITMAP "........"
	BITMAP "........"
	BITMAP "3333...."
	BITMAP "22223..."
	BITMAP "11123..."

	BITMAP "22222222"
	BITMAP "22222222"
	BITMAP "33222222"
	BITMAP "..322223"
	BITMAP "..322223"
	BITMAP "..322223"
	BITMAP "..322223"
	BITMAP "..322223"

	BITMAP "2223..32"
	BITMAP "2223..32"
	BITMAP "3333..32"
	BITMAP "......32"
	BITMAP "......32"
	BITMAP "......32"
	BITMAP "......32"
	BITMAP "......32"

	BITMAP "2223...."
	BITMAP "2223...."
	BITMAP "2223...."
	BITMAP "2223...."
	BITMAP "2223...."
	BITMAP "2223...."
	BITMAP "2223...."
	BITMAP "2223...."

	BITMAP "....3222"
	BITMAP "....3111"
	BITMAP "....3111"
	BITMAP "....3111"
	BITMAP "....3111"
	BITMAP "....3111"
	BITMAP "....3111"
	BITMAP "....3111"

	BITMAP "22211111"
	BITMAP "11111111"
	BITMAP "13331111"
	BITMAP "3...3111"
	BITMAP "3...3111"
	BITMAP "3...3111"
	BITMAP "3...3111"
	BITMAP "3...3111"

	BITMAP "3..31111"
	BITMAP "3..31111"
	BITMAP "3..31111"
	BITMAP "13.31111"
	BITMAP "13.31111"
	BITMAP "13.31111"
	BITMAP "13.31111"
	BITMAP "13.31111"

	BITMAP "3......."
	BITMAP "3......."
	BITMAP "3......."
	BITMAP "3......."
	BITMAP "3......."
	BITMAP "3......."
	BITMAP "1333333."
	BITMAP "1111113."

	BITMAP "31111133"
	BITMAP "31111111"
	BITMAP "31111111"
	BITMAP "31111111"
	BITMAP "31111111"
	BITMAP "31111111"
	BITMAP "31111111"
	BITMAP "31111133"

	BITMAP "3111113."
	BITMAP "1111113."
	BITMAP "1111113."
	BITMAP "1111113."
	BITMAP "1111113."
	BITMAP "1111113."
	BITMAP "1111113."
	BITMAP "3111113."

	BITMAP "31111111"
	BITMAP "31111111"
	BITMAP "31111111"
	BITMAP "31111111"
	BITMAP ".3333331"
	BITMAP ".......3"
	BITMAP "33333331"
	BITMAP "31111111"

	BITMAP "11113..."
	BITMAP "11113..."
	BITMAP "11113..."
	BITMAP "11113..."
	BITMAP "11113..."
	BITMAP "11113..."
	BITMAP "11113..."
	BITMAP "11113..."

	BITMAP "..311113"
	BITMAP "..311113"
	BITMAP "..311113"
	BITMAP "..311113"
	BITMAP "..311113"
	BITMAP "..311113"
	BITMAP "..311113"
	BITMAP "..311113"

	BITMAP "......32"
	BITMAP "......31"
	BITMAP "......31"
	BITMAP "......31"
	BITMAP "......31"
	BITMAP "......33"
	BITMAP "........"
	BITMAP "........"

	BITMAP "2223...."
	BITMAP "1113...."
	BITMAP "1113...."
	BITMAP "1113...."
	BITMAP "1113...."
	BITMAP "3333...."
	BITMAP "........"
	BITMAP "........"

	BITMAP "....3111"
	BITMAP "....3111"
	BITMAP "....3111"
	BITMAP "....3111"
	BITMAP "....3111"
	BITMAP "....3333"
	BITMAP "........"
	BITMAP "........"

	BITMAP "13331111"
	BITMAP "11111111"
	BITMAP "11111111"
	BITMAP "11111111"
	BITMAP "11111111"
	BITMAP "33333333"
	BITMAP "........"
	BITMAP "........"

	BITMAP "13.31111"
	BITMAP "13.31111"
	BITMAP "13.31111"
	BITMAP "13.31111"
	BITMAP "13.31111"
	BITMAP "3..33333"
	BITMAP "........"
	BITMAP "........"

	BITMAP "1111113."
	BITMAP "1111113."
	BITMAP "1111113."
	BITMAP "1111113."
	BITMAP "1111113."
	BITMAP "3333333."
	BITMAP "........"
	BITMAP "........"

	BITMAP "311113.."
	BITMAP "311113.."
	BITMAP "311113.."
	BITMAP "311113.."
	BITMAP "311113.."
	BITMAP "333333.."
	BITMAP "........"
	BITMAP "........"

	BITMAP ".311113."
	BITMAP ".311113."
	BITMAP ".311113."
	BITMAP ".311113."
	BITMAP ".311113."
	BITMAP ".333333."
	BITMAP "........"
	BITMAP "........"

	BITMAP "31111111"
	BITMAP "31111111"
	BITMAP "31111111"
	BITMAP "31111111"
	BITMAP "31111111"
	BITMAP "33333333"
	BITMAP "........"
	BITMAP "........"

	BITMAP "11113..."
	BITMAP "11113..."
	BITMAP "11113..."
	BITMAP "11113..."
	BITMAP "11113..."
	BITMAP "3333...."
	BITMAP "........"
	BITMAP "........"

	BITMAP "..311113"
	BITMAP "..311113"
	BITMAP "..311113"
	BITMAP "..311113"
	BITMAP "..311113"
	BITMAP "..333333"
	BITMAP "........"
	BITMAP "........"

	BITMAP "......33"
	BITMAP "......31"
	BITMAP "......31"
	BITMAP "......31"
	BITMAP "......31"
	BITMAP "......33"
	BITMAP "........"
	BITMAP "........"

	BITMAP "3333...."
	BITMAP "1113...."
	BITMAP "1113...."
	BITMAP "1113...."
	BITMAP "1113...."
	BITMAP "3333...."
	BITMAP "........"
	BITMAP "........"

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	' bullet "•" do rodape (bits 3, sai ciano na regiao pal3)
	BITMAP "........"
	BITMAP "...33..."
	BITMAP "..3333.."
	BITMAP "..3333.."
	BITMAP "...33..."
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	CHRROM PATTERN 268
	' Explosao (padroes 268-271, frames 13 e 15)
	BITMAP "................"
	BITMAP "..1..........1.."
	BITMAP ".3.1........1.3."
	BITMAP "..3.1......1.3.."
	BITMAP "...3.11..11.3..."
	BITMAP "....33122133...."
	BITMAP "...3122222213..."
	BITMAP "..112222222211.."
	BITMAP "..112222222211.."
	BITMAP "...3122222213..."
	BITMAP "....33122133...."
	BITMAP "...3.11..11.3..."
	BITMAP "..3.1......1.3.."
	BITMAP ".3.1........1.3."
	BITMAP "..1..........1.."
	BITMAP "................"

	'
	' Nave do jogador (16x16, 4 sprites em camadas):
	'   corpoE (pal 0) / corpoD (pal 0) / canopy (pal 1) / chama (pal 2)
	'   11 slots de animacao, metade 8x16 cada: f = 21 + slot*8 + metade*2
	'   slots 0-3 = idle, 4-6 = virando p/ direita, 7-10 = segurando p/ direita (orig 10-13)
	'   (lado esquerdo = mesmo desenho com H-FLIP, atributo +$40)
	'
	CHRROM PATTERN 276
	' slot 0 = frame original 0
	' corpoE f=21
	BITMAP "........"
	BITMAP ".......1"
	BITMAP "......12"
	BITMAP ".....112"
	BITMAP ".....232"
	BITMAP ".....121"
	BITMAP ".....111"
	BITMAP "....1122"
	BITMAP "...11221"
	BITMAP "..122311"
	BITMAP ".1121121"
	BITMAP ".1111133"
	BITMAP ".1112121"
	BITMAP ".23..213"
	BITMAP "11......"
	BITMAP "........"
	' corpoD f=23
	BITMAP "........"
	BITMAP "1......."
	BITMAP "21......"
	BITMAP "211....."
	BITMAP "332....."
	BITMAP "121....."
	BITMAP "111....."
	BITMAP "2211...."
	BITMAP "12211..."
	BITMAP "113221.."
	BITMAP "1211211."
	BITMAP "3311111."
	BITMAP "1212111."
	BITMAP "312..32."
	BITMAP "......11"
	BITMAP "........"
	' canopy f=25
	BITMAP "........"
	BITMAP "........"
	BITMAP "...22..."
	BITMAP "...22..."
	BITMAP "...23..."
	BITMAP "........"
	BITMAP "........"
	BITMAP ".1....1."
	BITMAP "........"
	BITMAP "........"
	BITMAP "...11..."
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	' chama  f=27
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "...22..."
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	' slot 1 = frame original 1
	' corpoE f=29
	BITMAP "........"
	BITMAP ".......1"
	BITMAP "......12"
	BITMAP ".....112"
	BITMAP ".....232"
	BITMAP ".....121"
	BITMAP ".....111"
	BITMAP "....1122"
	BITMAP "...11221"
	BITMAP "..122311"
	BITMAP ".1121121"
	BITMAP ".1111122"
	BITMAP ".1112111"
	BITMAP ".23..1.2"
	BITMAP "11.....1"
	BITMAP "........"
	' corpoD f=31
	BITMAP "........"
	BITMAP "1......."
	BITMAP "21......"
	BITMAP "211....."
	BITMAP "232....."
	BITMAP "121....."
	BITMAP "111....."
	BITMAP "2211...."
	BITMAP "12211..."
	BITMAP "113221.."
	BITMAP "1211211."
	BITMAP "2211111."
	BITMAP "1112111."
	BITMAP "2.1..32."
	BITMAP "1.....11"
	BITMAP "........"
	' canopy f=33
	BITMAP "........"
	BITMAP "........"
	BITMAP "...22..."
	BITMAP "...22..."
	BITMAP "...22..."
	BITMAP "........"
	BITMAP "........"
	BITMAP ".1....1."
	BITMAP "........"
	BITMAP "........"
	BITMAP "...11..."
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	' chama  f=35
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "...22..."
	BITMAP "........"
	BITMAP "..2222.."
	BITMAP ".121121."
	BITMAP ".2.22.2."
	BITMAP "...22..."
	BITMAP "........"
	' slot 2 = frame original 2
	' corpoE f=37
	BITMAP "........"
	BITMAP ".......1"
	BITMAP "......12"
	BITMAP ".....112"
	BITMAP ".....232"
	BITMAP ".....121"
	BITMAP ".....111"
	BITMAP "....1122"
	BITMAP "...11221"
	BITMAP "..122311"
	BITMAP ".1121121"
	BITMAP ".1111133"
	BITMAP ".1112121"
	BITMAP ".23..2.3"
	BITMAP "11....23"
	BITMAP ".......2"
	' corpoD f=39
	BITMAP "........"
	BITMAP "1......."
	BITMAP "21......"
	BITMAP "211....."
	BITMAP "332....."
	BITMAP "121....."
	BITMAP "111....."
	BITMAP "2211...."
	BITMAP "12211..."
	BITMAP "113221.."
	BITMAP "1211211."
	BITMAP "3311111."
	BITMAP "1212111."
	BITMAP "3.2..32."
	BITMAP "32....11"
	BITMAP "2......."
	' canopy f=41
	BITMAP "........"
	BITMAP "........"
	BITMAP "...22..."
	BITMAP "...22..."
	BITMAP "...23..."
	BITMAP "........"
	BITMAP "........"
	BITMAP ".1....1."
	BITMAP "........"
	BITMAP "........"
	BITMAP "...11..."
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	' chama  f=43
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "...22..."
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "..2..2.."
	BITMAP "...22..."
	' slot 3 = frame original 3
	' corpoE f=45
	BITMAP "........"
	BITMAP ".......1"
	BITMAP "......12"
	BITMAP ".....112"
	BITMAP ".....232"
	BITMAP ".....121"
	BITMAP ".....111"
	BITMAP "....1122"
	BITMAP "...11221"
	BITMAP "..122311"
	BITMAP ".1121121"
	BITMAP ".1111122"
	BITMAP ".1112111"
	BITMAP ".23..1.2"
	BITMAP "11.....2"
	BITMAP ".......2"
	' corpoD f=47
	BITMAP "........"
	BITMAP "1......."
	BITMAP "21......"
	BITMAP "211....."
	BITMAP "232....."
	BITMAP "121....."
	BITMAP "111....."
	BITMAP "2211...."
	BITMAP "12211..."
	BITMAP "113221.."
	BITMAP "1211211."
	BITMAP "2211111."
	BITMAP "1112111."
	BITMAP "2.1..32."
	BITMAP "2.....11"
	BITMAP "2......."
	' canopy f=49
	BITMAP "........"
	BITMAP "........"
	BITMAP "...22..."
	BITMAP "...22..."
	BITMAP "...22..."
	BITMAP "........"
	BITMAP "........"
	BITMAP ".1....1."
	BITMAP "........"
	BITMAP "........"
	BITMAP "...11..."
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	' chama  f=51
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "...22..."
	BITMAP "........"
	BITMAP "..2222.."
	BITMAP ".121121."
	BITMAP ".2.22.2."
	BITMAP "...22..."
	BITMAP "...22..."
	' slot 4 = frame original 4
	' corpoE f=53
	BITMAP "........"
	BITMAP ".......1"
	BITMAP "......12"
	BITMAP ".....112"
	BITMAP ".....232"
	BITMAP ".....121"
	BITMAP ".....111"
	BITMAP "....1122"
	BITMAP "...11221"
	BITMAP "..122311"
	BITMAP ".1121121"
	BITMAP ".1111133"
	BITMAP ".1112121"
	BITMAP ".23..2.3"
	BITMAP "11....23"
	BITMAP ".......2"
	' corpoD f=55
	BITMAP "........"
	BITMAP "1......."
	BITMAP "21......"
	BITMAP "211....."
	BITMAP "332....."
	BITMAP "121....."
	BITMAP "111....."
	BITMAP "2211...."
	BITMAP "12211..."
	BITMAP "113221.."
	BITMAP "1211211."
	BITMAP "3311111."
	BITMAP "1212111."
	BITMAP "3.2..32."
	BITMAP "32....11"
	BITMAP "2......."
	' canopy f=57
	BITMAP "........"
	BITMAP "........"
	BITMAP "...22..."
	BITMAP "...22..."
	BITMAP "...23..."
	BITMAP "........"
	BITMAP "........"
	BITMAP ".1....1."
	BITMAP "........"
	BITMAP "........"
	BITMAP "...11..."
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	' chama  f=59
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "...22..."
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "..2..2.."
	BITMAP "...22..."
	' slot 5 = frame original 5
	' corpoE f=61
	BITMAP "........"
	BITMAP ".......1"
	BITMAP "......12"
	BITMAP ".....112"
	BITMAP ".....212"
	BITMAP ".....121"
	BITMAP ".....111"
	BITMAP "...11221"
	BITMAP "..122221"
	BITMAP ".1122211"
	BITMAP ".1112121"
	BITMAP ".1111231"
	BITMAP ".23.1111"
	BITMAP "11...112"
	BITMAP ".......1"
	BITMAP "........"
	' corpoD f=63
	BITMAP "........"
	BITMAP "1......."
	BITMAP "2......."
	BITMAP "21......"
	BITMAP "321....."
	BITMAP "111....."
	BITMAP "111....."
	BITMAP "211....."
	BITMAP "1221...."
	BITMAP "21121..."
	BITMAP "1132111."
	BITMAP "311131.."
	BITMAP "111111.."
	BITMAP "211.121."
	BITMAP "1....12."
	BITMAP "........"
	' canopy f=65
	BITMAP "........"
	BITMAP "........"
	BITMAP "...22..."
	BITMAP "...22..."
	BITMAP "..123..."
	BITMAP "........"
	BITMAP ".1......"
	BITMAP ".....11."
	BITMAP "........"
	BITMAP "...1.1.."
	BITMAP "....1..."
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	' chama  f=67
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "....2..."
	BITMAP "........"
	BITMAP "...2.2.."
	BITMAP ".121111."
	BITMAP ".112221."
	BITMAP "...22..."
	BITMAP "........"
	' slot 6 = frame original 6
	' corpoE f=69
	BITMAP "........"
	BITMAP ".......1"
	BITMAP ".......2"
	BITMAP ".....111"
	BITMAP ".....123"
	BITMAP ".....112"
	BITMAP "....1111"
	BITMAP "..122212"
	BITMAP ".1122312"
	BITMAP ".1211111"
	BITMAP ".1131111"
	BITMAP ".2312121"
	BITMAP "11...221"
	BITMAP "......13"
	BITMAP "........"
	BITMAP "........"
	' corpoD f=71
	BITMAP "........"
	BITMAP "1......."
	BITMAP "2......."
	BITMAP "21......"
	BITMAP "321....."
	BITMAP "111....."
	BITMAP "11......"
	BITMAP "121....."
	BITMAP "111....."
	BITMAP "1111...."
	BITMAP "11211..."
	BITMAP "23212..."
	BITMAP "11111..."
	BITMAP "321211.."
	BITMAP "....11.."
	BITMAP "........"
	' canopy f=73
	BITMAP "........"
	BITMAP "........"
	BITMAP "...22..."
	BITMAP "....2..."
	BITMAP "....3..."
	BITMAP "........"
	BITMAP ".1......"
	BITMAP "........"
	BITMAP "........"
	BITMAP "....1.1."
	BITMAP ".....1.."
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	' chama  f=75
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP ".....2.."
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	' slot 7 = frame original 10
	' corpoE f=77
	BITMAP "........"
	BITMAP ".......1"
	BITMAP ".......1"
	BITMAP ".....111"
	BITMAP ".....121"
	BITMAP ".....112"
	BITMAP "....1111"
	BITMAP "..122212"
	BITMAP ".1122312"
	BITMAP ".1211111"
	BITMAP ".1131111"
	BITMAP ".2312121"
	BITMAP "11...221"
	BITMAP "......13"
	BITMAP "........"
	BITMAP "........"
	' corpoD f=79
	BITMAP "........"
	BITMAP "1......."
	BITMAP "2......."
	BITMAP "21......"
	BITMAP "321....."
	BITMAP "111....."
	BITMAP "11......"
	BITMAP "121....."
	BITMAP "111....."
	BITMAP "1111...."
	BITMAP "11211..."
	BITMAP "23212..."
	BITMAP "11111..."
	BITMAP "321211.."
	BITMAP "....11.."
	BITMAP "........"
	' canopy f=81
	BITMAP "........"
	BITMAP "........"
	BITMAP "...22..."
	BITMAP "....2..."
	BITMAP "....3..."
	BITMAP "........"
	BITMAP ".1......"
	BITMAP "........"
	BITMAP "........"
	BITMAP "....1.1."
	BITMAP ".....1.."
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	' chama  f=83
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP ".....2.."
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	' slot 8 = frame original 11
	' corpoE f=85
	BITMAP "........"
	BITMAP ".......1"
	BITMAP ".......2"
	BITMAP ".....111"
	BITMAP ".....121"
	BITMAP ".....112"
	BITMAP "....1111"
	BITMAP "..122212"
	BITMAP ".1122312"
	BITMAP ".1211111"
	BITMAP ".1131111"
	BITMAP ".2312111"
	BITMAP "11...111"
	BITMAP "......12"
	BITMAP ".......1"
	BITMAP "........"
	' corpoD f=87
	BITMAP "........"
	BITMAP "1......."
	BITMAP "2......."
	BITMAP "21......"
	BITMAP "321....."
	BITMAP "111....."
	BITMAP "11......"
	BITMAP "121....."
	BITMAP "111....."
	BITMAP "1111...."
	BITMAP "11211..."
	BITMAP "12212..."
	BITMAP "11111..."
	BITMAP "211211.."
	BITMAP "1...11.."
	BITMAP "........"
	' canopy f=89
	BITMAP "........"
	BITMAP "........"
	BITMAP "...22..."
	BITMAP "....2..."
	BITMAP "....3..."
	BITMAP "........"
	BITMAP ".1......"
	BITMAP "........"
	BITMAP "........"
	BITMAP "....1.1."
	BITMAP ".....1.."
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	' chama  f=91
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP ".....2.."
	BITMAP "........"
	BITMAP "..2.22.."
	BITMAP ".221111."
	BITMAP "..1222.."
	BITMAP "...22..."
	BITMAP "........"
	' slot 9 = frame original 12
	' corpoE f=93
	BITMAP "........"
	BITMAP ".......1"
	BITMAP ".......1"
	BITMAP ".....111"
	BITMAP ".....121"
	BITMAP ".....112"
	BITMAP "....1111"
	BITMAP "..122212"
	BITMAP ".1122312"
	BITMAP ".1211111"
	BITMAP ".1131111"
	BITMAP ".2312121"
	BITMAP "11...221"
	BITMAP "......13"
	BITMAP "......23"
	BITMAP ".......2"
	' corpoD f=95
	BITMAP "........"
	BITMAP "1......."
	BITMAP "2......."
	BITMAP "21......"
	BITMAP "321....."
	BITMAP "111....."
	BITMAP "11......"
	BITMAP "121....."
	BITMAP "111....."
	BITMAP "1111...."
	BITMAP "11211..."
	BITMAP "23212..."
	BITMAP "11111..."
	BITMAP "311211.."
	BITMAP "32..11.."
	BITMAP "2......."
	' canopy f=97
	BITMAP "........"
	BITMAP "........"
	BITMAP "...22..."
	BITMAP "....2..."
	BITMAP "....3..."
	BITMAP "........"
	BITMAP ".1......"
	BITMAP "........"
	BITMAP "........"
	BITMAP "....1.1."
	BITMAP ".....1.."
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	' chama  f=99
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP ".....2.."
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP ".....2.."
	BITMAP "..2..2.."
	BITMAP "...22..."
	' slot 10 = frame original 13
	' corpoE f=101
	BITMAP "........"
	BITMAP ".......1"
	BITMAP ".......2"
	BITMAP ".....111"
	BITMAP ".....121"
	BITMAP ".....112"
	BITMAP "....1111"
	BITMAP "..122212"
	BITMAP ".1122312"
	BITMAP ".1211111"
	BITMAP ".1131111"
	BITMAP ".2312111"
	BITMAP "11...111"
	BITMAP ".......2"
	BITMAP ".......2"
	BITMAP ".......2"
	' corpoD f=103
	BITMAP "........"
	BITMAP "1......."
	BITMAP "2......."
	BITMAP "21......"
	BITMAP "321....."
	BITMAP "111....."
	BITMAP "11......"
	BITMAP "121....."
	BITMAP "111....."
	BITMAP "1111...."
	BITMAP "11211..."
	BITMAP "12212..."
	BITMAP "11111..."
	BITMAP "2.1211.."
	BITMAP "2...11.."
	BITMAP "2......."
	' canopy f=105
	BITMAP "........"
	BITMAP "........"
	BITMAP "...22..."
	BITMAP "....2..."
	BITMAP "....3..."
	BITMAP "........"
	BITMAP ".1......"
	BITMAP "........"
	BITMAP "........"
	BITMAP "....1.1."
	BITMAP ".....1.."
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	' chama  f=107
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP ".....2.."
	BITMAP "........"
	BITMAP "..2.22.."
	BITMAP ".221111."
	BITMAP "...22..."
	BITMAP "...22..."
	BITMAP "...22..."
	' ======= SPACE BLAST (ex-Caravan Blast): arte convertida do jogo HTML5 =======
	' f: tiro03 113/115 | small 113+4+4i/115+4+4i (esq=HFLIP) | shard 125/127/129/131 | ebullet 133/135
	' tiles: tiro03 364-367 | small 368-379 | shard 380-387 | ebullet 388-391
	CHRROM PATTERN 364
	' tiro03 fr0 f=113
	BITMAP "........"
	BITMAP "...11..."
	BITMAP "...12..."
	BITMAP ".2112.21"
	BITMAP ".2112.21"
	BITMAP ".2112.21"
	BITMAP ".21.1.21"
	BITMAP ".21...21"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	' tiro03 fr1 f=115
	BITMAP "........"
	BITMAP "....2..."
	BITMAP ".2.23.2."
	BITMAP ".3223.32"
	BITMAP ".3223.32"
	BITMAP ".3223.32"
	BITMAP ".3223.32"
	BITMAP ".2....2."
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	' small fr13 metade0 f=117 (16x16 real)
	BITMAP "........"
	BITMAP ".......2"
	BITMAP ".......3"
	BITMAP "....33.1"
	BITMAP "...333.1"
	BITMAP "..3333.3"
	BITMAP "..333223"
	BITMAP "..1332.3"
	BITMAP "..1332.3"
	BITMAP "..1333.3"
	BITMAP "..133313"
	BITMAP "..3333.3"
	BITMAP "..3333.3"
	BITMAP "...333.."
	BITMAP "....33.."
	BITMAP ".....3.."
	' small fr13 metade1 f=119 (16x16 real)
	BITMAP "........"
	BITMAP "22......"
	BITMAP "33......"
	BITMAP "33.3...."
	BITMAP "33333..."
	BITMAP "3.3333.."
	BITMAP "113333.."
	BITMAP "1.3333.."
	BITMAP "333333.."
	BITMAP "33.233.."
	BITMAP "132233.."
	BITMAP "13.233.."
	BITMAP "...233.."
	BITMAP "...233.."
	BITMAP "..333..."
	BITMAP "..33...."
	' small fr15 metade0 f=121 (16x16 real)
	BITMAP "........"
	BITMAP ".......2"
	BITMAP ".......3"
	BITMAP ".....3.3"
	BITMAP "....3333"
	BITMAP "...3333."
	BITMAP "...33331"
	BITMAP "...1333."
	BITMAP "...13333"
	BITMAP "...132.3"
	BITMAP "...13223"
	BITMAP "...332.3"
	BITMAP "...332.."
	BITMAP "....32.."
	BITMAP "....333."
	BITMAP ".....33."
	' small fr15 metade1 f=123 (16x16 real)
	BITMAP "........"
	BITMAP "22......"
	BITMAP "33......"
	BITMAP "3333...."
	BITMAP "33333..."
	BITMAP "3.333..."
	BITMAP "11233..."
	BITMAP "1.233..."
	BITMAP "33233..."
	BITMAP "33333..."
	BITMAP "13333..."
	BITMAP "13333..."
	BITMAP "..333..."
	BITMAP "..333..."
	BITMAP "..33...."
	BITMAP "..3....."
	' small fr18 metade0 f=125 (16x16 real)
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP ".......3"
	BITMAP ".......3"
	BITMAP ".......3"
	BITMAP "......33"
	BITMAP "......31"
	BITMAP "......31"
	BITMAP "......31"
	BITMAP "......31"
	BITMAP "......31"
	BITMAP "......33"
	BITMAP ".......3"
	BITMAP ".......3"
	BITMAP "........"
	' small fr18 metade1 f=127 (16x16 real)
	BITMAP "2......."
	BITMAP "2......."
	BITMAP "333....."
	BITMAP "133....."
	BITMAP "333....."
	BITMAP "333....."
	BITMAP "313....."
	BITMAP "313....."
	BITMAP "333....."
	BITMAP "333....."
	BITMAP "213....."
	BITMAP "233....."
	BITMAP "2......."
	BITMAP "2......."
	BITMAP "3......."
	BITMAP "3......."
	' shard fr0 f=125
	BITMAP "........"
	BITMAP "...12..."
	BITMAP "..1121.."
	BITMAP ".112211."
	BITMAP "....1222"
	BITMAP "..21.111"
	BITMAP "...2.11."
	BITMAP ".....1.."
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	' shard fr2 f=127
	BITMAP "........"
	BITMAP "...22..."
	BITMAP "..2221.."
	BITMAP ".112.21."
	BITMAP "..1.2.22"
	BITMAP "..12.211"
	BITMAP "...1111."
	BITMAP ".....1.."
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	' shard fr5 f=129
	BITMAP "....1..."
	BITMAP "...12..."
	BITMAP "..2..2.."
	BITMAP ".1..2.2."
	BITMAP "1..22..2"
	BITMAP "..2...21"
	BITMAP "...2.21."
	BITMAP ".....1.."
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	' shard fr7 f=131
	BITMAP "........"
	BITMAP "...12..."
	BITMAP "..1222.."
	BITMAP ".12..22."
	BITMAP "...33.22"
	BITMAP "..22.211"
	BITMAP "...1.23."
	BITMAP ".....1.."
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	' ebullet fr0 f=133
	BITMAP "..1111.."
	BITMAP ".111111."
	BITMAP "11133111"
	BITMAP "11333311"
	BITMAP "11333311"
	BITMAP "11133111"
	BITMAP ".111111."
	BITMAP "..1111.."
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	' ebullet fr2 f=135
	BITMAP "..3333.."
	BITMAP ".333333."
	BITMAP "33333333"
	BITMAP "33333333"
	BITMAP "33333333"
	BITMAP "33333333"
	BITMAP ".333333."
	BITMAP "..3333.."
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	' Enemy4 (sprite do Saulo, frame estatico, 16x16; gera_enemy4.py)
	CHRROM PATTERN 392
	' enemy4 fr0 metade0 (byte OAM 137)
	BITMAP "...22..."
	BITMAP "..222.22"
	BITMAP ".222.222"
	BITMAP "31222212"
	BITMAP "31222212"
	BITMAP "31222112"
	BITMAP "31222112"
	BITMAP ".2222122"
	BITMAP ".2222221"
	BITMAP "..2..221"
	BITMAP "..2..221"
	BITMAP ".222..23"
	BITMAP ".222...2"
	BITMAP "..222..2"
	BITMAP "..222..."
	BITMAP "...2...."
	CHRROM PATTERN 394
	' enemy4 fr0 metade1 (byte OAM 139)
	BITMAP "...22..."
	BITMAP "22.222.."
	BITMAP "222.222."
	BITMAP "21222213"
	BITMAP "21222213"
	BITMAP "21122213"
	BITMAP "21122213"
	BITMAP "2212222."
	BITMAP "1222222."
	BITMAP "122..2.."
	BITMAP "112..2.."
	BITMAP "32..222."
	BITMAP "2...222."
	BITMAP "2..222.."
	BITMAP "...222.."
	BITMAP "....2..."

	' MINIBOSS do Saulo (miniboss-1.png: 32x32, 2 frames, pal2;
	' gera_miniboss.py). Onda a cada 4; o codigo troca pal2 p/
	' $03/$23/$38 (cores exatas da arte) e restaura ao morrer.
	' OAM: frame A = bytes 141-155, frame B = 157-171.
	CHRROM PATTERN 396
	' miniboss f0 top col0 (byte OAM 141)
	BITMAP "........"
	BITMAP "1......."
	BITMAP "11......"
	BITMAP "13122221"
	BITMAP "11122221"
	BITMAP "13122221"
	BITMAP "13122221"
	BITMAP "11111111"
	BITMAP ".1.....1"
	BITMAP "...111.."
	BITMAP "..12221."
	BITMAP ".1122211"
	BITMAP ".1322231"
	BITMAP ".1122211"
	BITMAP "..12221."
	BITMAP "...111.."
	CHRROM PATTERN 398
	' miniboss f0 top col1 (byte OAM 143)
	BITMAP "........"
	BITMAP "........"
	BITMAP "1......."
	BITMAP "1....1.."
	BITMAP "3....112"
	BITMAP "1....132"
	BITMAP "1..1.112"
	BITMAP "...1.131"
	BITMAP "1.11.11."
	BITMAP "1.111..."
	BITMAP "1.113.11"
	BITMAP ".1.11.1."
	BITMAP ".1.13.31"
	BITMAP ".1.11.11"
	BITMAP "11.13.1."
	BITMAP "...11.12"
	CHRROM PATTERN 400
	' miniboss f0 top col2 (byte OAM 145)
	BITMAP "........"
	BITMAP "........"
	BITMAP ".......1"
	BITMAP "..1....1"
	BITMAP "211....3"
	BITMAP "231....1"
	BITMAP "211.1..1"
	BITMAP "131.1..."
	BITMAP ".11.11.1"
	BITMAP "...111.1"
	BITMAP "11.311.1"
	BITMAP ".1.11.1."
	BITMAP "13.31.1."
	BITMAP "11.11.1."
	BITMAP ".1.31.11"
	BITMAP "21.11..."
	CHRROM PATTERN 402
	' miniboss f0 top col3 (byte OAM 147)
	BITMAP "........"
	BITMAP ".......1"
	BITMAP "......11"
	BITMAP "12222131"
	BITMAP "12222111"
	BITMAP "12222131"
	BITMAP "12222131"
	BITMAP "11111111"
	BITMAP "1.....1."
	BITMAP "..111..."
	BITMAP ".12221.."
	BITMAP "1122211."
	BITMAP "1322231."
	BITMAP "1122211."
	BITMAP ".12221.."
	BITMAP "..111..."
	CHRROM PATTERN 404
	' miniboss f0 bot col0 (byte OAM 149)
	BITMAP "..13331."
	BITMAP "..13331."
	BITMAP "...111.."
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP ".......1"
	BITMAP "......11"
	BITMAP "......11"
	BITMAP "......12"
	BITMAP "......12"
	BITMAP "......12"
	BITMAP "......12"
	BITMAP ".....113"
	BITMAP ".....133"
	BITMAP "......11"
	CHRROM PATTERN 406
	' miniboss f0 bot col1 (byte OAM 151)
	BITMAP "11..1112"
	BITMAP "311..111"
	BITMAP "1311..21"
	BITMAP "11311.12"
	BITMAP ".1131.21"
	BITMAP "11113.13"
	BITMAP "11.11.32"
	BITMAP "11....12"
	BITMAP "211..113"
	BITMAP "321.1132"
	BITMAP "221.1.12"
	BITMAP "321...23"
	BITMAP "221...31"
	BITMAP "3311..1."
	BITMAP "3331...."
	BITMAP "111....."
	CHRROM PATTERN 408
	' miniboss f0 bot col2 (byte OAM 153)
	BITMAP "2111..11"
	BITMAP "111..113"
	BITMAP "12..1131"
	BITMAP "21.11311"
	BITMAP "12.1311."
	BITMAP "31.31111"
	BITMAP "23.11.11"
	BITMAP "21....11"
	BITMAP "311..112"
	BITMAP "2311.123"
	BITMAP "21.1.122"
	BITMAP "32...123"
	BITMAP "13...122"
	BITMAP ".1..1133"
	BITMAP "....1333"
	BITMAP ".....111"
	CHRROM PATTERN 410
	' miniboss f0 bot col3 (byte OAM 155)
	BITMAP ".13331.."
	BITMAP ".13331.."
	BITMAP "..111..."
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "1......."
	BITMAP "11......"
	BITMAP "11......"
	BITMAP "21......"
	BITMAP "21......"
	BITMAP "21......"
	BITMAP "21......"
	BITMAP "311....."
	BITMAP "331....."
	BITMAP "11......"
	CHRROM PATTERN 412
	' miniboss f1 top col0 (byte OAM 157)
	BITMAP "........"
	BITMAP "1...33.."
	BITMAP "11.3333."
	BITMAP "13122221"
	BITMAP "11122221"
	BITMAP "13122221"
	BITMAP "13122221"
	BITMAP "11111111"
	BITMAP ".1.....1"
	BITMAP "...111.."
	BITMAP "..12221."
	BITMAP ".1122211"
	BITMAP ".1322231"
	BITMAP ".1122211"
	BITMAP "..12221."
	BITMAP "...111.."
	CHRROM PATTERN 414
	' miniboss f1 top col1 (byte OAM 159)
	BITMAP "......33"
	BITMAP ".....333"
	BITMAP "1...3333"
	BITMAP "1...3133"
	BITMAP "3....112"
	BITMAP "1....132"
	BITMAP "1..1.112"
	BITMAP "...1.131"
	BITMAP "1.11.11."
	BITMAP "1.111..."
	BITMAP "1.113.11"
	BITMAP ".1.11.1."
	BITMAP ".1.13.31"
	BITMAP ".1.11.11"
	BITMAP "11.13.1."
	BITMAP "...11.12"
	CHRROM PATTERN 416
	' miniboss f1 top col2 (byte OAM 161)
	BITMAP "33......"
	BITMAP "333....."
	BITMAP "3333...1"
	BITMAP "3313...1"
	BITMAP "211....3"
	BITMAP "231....1"
	BITMAP "211.1..1"
	BITMAP "131.1..."
	BITMAP ".11.11.1"
	BITMAP "...111.1"
	BITMAP "11.311.1"
	BITMAP ".1.11.1."
	BITMAP "13.31.1."
	BITMAP "11.11.1."
	BITMAP ".1.31.11"
	BITMAP "21.11..."
	CHRROM PATTERN 418
	' miniboss f1 top col3 (byte OAM 163)
	BITMAP "........"
	BITMAP "..33...1"
	BITMAP ".3333.11"
	BITMAP "12222131"
	BITMAP "12222111"
	BITMAP "12222131"
	BITMAP "12222131"
	BITMAP "11111111"
	BITMAP "1.....1."
	BITMAP "..111..."
	BITMAP ".12221.."
	BITMAP "1122211."
	BITMAP "1322231."
	BITMAP "1122211."
	BITMAP ".12221.."
	BITMAP "..111..."
	CHRROM PATTERN 420
	' miniboss f1 bot col0 (byte OAM 165)
	BITMAP "..13331."
	BITMAP "..13331."
	BITMAP "...111.."
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP ".......1"
	BITMAP "......11"
	BITMAP "......11"
	BITMAP "......12"
	BITMAP "......12"
	BITMAP "......12"
	BITMAP "......12"
	BITMAP ".....113"
	BITMAP ".....133"
	BITMAP "......11"
	CHRROM PATTERN 422
	' miniboss f1 bot col1 (byte OAM 167)
	BITMAP "11..1112"
	BITMAP "311..111"
	BITMAP "1311..21"
	BITMAP "11311.12"
	BITMAP ".1131.21"
	BITMAP "11113.13"
	BITMAP "11.11.32"
	BITMAP "11....12"
	BITMAP "211..113"
	BITMAP "321.1132"
	BITMAP "221.1.12"
	BITMAP "321...23"
	BITMAP "221...31"
	BITMAP "3311..1."
	BITMAP "3331...."
	BITMAP "111....."
	CHRROM PATTERN 424
	' miniboss f1 bot col2 (byte OAM 169)
	BITMAP "2111..11"
	BITMAP "111..113"
	BITMAP "12..1131"
	BITMAP "21.11311"
	BITMAP "12.1311."
	BITMAP "31.31111"
	BITMAP "23.11.11"
	BITMAP "21....11"
	BITMAP "311..112"
	BITMAP "2311.123"
	BITMAP "21.1.122"
	BITMAP "32...123"
	BITMAP "13...122"
	BITMAP ".1..1133"
	BITMAP "....1333"
	BITMAP ".....111"
	CHRROM PATTERN 426
	' miniboss f1 bot col3 (byte OAM 171)
	BITMAP ".13331.."
	BITMAP ".13331.."
	BITMAP "..111..."
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "1......."
	BITMAP "11......"
	BITMAP "11......"
	BITMAP "21......"
	BITMAP "21......"
	BITMAP "21......"
	BITMAP "21......"
	BITMAP "311....."
	BITMAP "331....."
	BITMAP "11......"
	' Laser do Saulo (16x32, pal3 ciano; gera_boss.py)
	CHRROM PATTERN 428
	' laser L cima (byte OAM 173)
	BITMAP "..2232.."
	BITMAP "...32..."
	BITMAP "..2232.."
	BITMAP "...32..."
	BITMAP "..2232.."
	BITMAP "...32..."
	BITMAP "..2232.."
	BITMAP "...32..."
	BITMAP "..2232.."
	BITMAP "...32..."
	BITMAP "..2232.."
	BITMAP "...32..."
	BITMAP "..2232.."
	BITMAP "...32..."
	BITMAP "..2232.."
	BITMAP "...32..."
	CHRROM PATTERN 430
	' laser L baixo (byte OAM 175)
	BITMAP "..2232.."
	BITMAP "...32..."
	BITMAP "..2232.."
	BITMAP "...32..."
	BITMAP "..2232.."
	BITMAP "...32..."
	BITMAP "..2232.."
	BITMAP "...32..."
	BITMAP "..2232.."
	BITMAP "...32..."
	BITMAP "..2232.."
	BITMAP "...32..."
	BITMAP "..2232.."
	BITMAP "...32..."
	BITMAP "..2232.."
	BITMAP "...32..."
	CHRROM PATTERN 432
	' laser R cima (byte OAM 177)
	BITMAP "..2332.."
	BITMAP "..2332.."
	BITMAP "..2332.."
	BITMAP "..2332.."
	BITMAP "..2332.."
	BITMAP "..2332.."
	BITMAP "..2332.."
	BITMAP "..2332.."
	BITMAP "..2332.."
	BITMAP "..2332.."
	BITMAP "..2332.."
	BITMAP "..2332.."
	BITMAP "..2332.."
	BITMAP "..2332.."
	BITMAP "..2332.."
	BITMAP "..2332.."
	CHRROM PATTERN 434
	' laser R baixo (byte OAM 179)
	BITMAP "..2332.."
	BITMAP "..2332.."
	BITMAP "..2332.."
	BITMAP "..2332.."
	BITMAP "..2332.."
	BITMAP "..2332.."
	BITMAP "..2332.."
	BITMAP "..2332.."
	BITMAP "..2332.."
	BITMAP "..2332.."
	BITMAP "..2332.."
	BITMAP "..2332.."
	BITMAP "..2332.."
	BITMAP "..2332.."
	BITMAP "..2332.."
	BITMAP "..2332.."
	' Tiro novo do player (Saulo, 2 frames 8x8; pal3 ciano;
	' bytes OAM 217/219; gera_boss.py)
	CHRROM PATTERN 472
	BITMAP "........"
	BITMAP "...22..."
	BITMAP "..2222.."
	BITMAP "..2222.."
	BITMAP "..2222.."
	BITMAP "..2222.."
	BITMAP "...22..."
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	CHRROM PATTERN 474
	BITMAP "........"
	BITMAP "...33..."
	BITMAP "..2332.."
	BITMAP "..2332.."
	BITMAP "..2332.."
	BITMAP "..2332.."
	BITMAP "...33..."
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	' BOSS em BG $1000 (gera_boss.py): 1 nave 96x64, frame 0
	CHRROM PATTERN 257
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "......21"
	BITMAP ".....1.."
	BITMAP ".....2.1"
	BITMAP ".......1"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "212....."
	BITMAP "3212121."
	BITMAP "31212121"
	BITMAP "3.....12"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "...3...."
	BITMAP "..13...."
	BITMAP "..13...."
	BITMAP ".113...."
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "1...33.."
	BITMAP "11.3333."
	BITMAP "13122221"
	BITMAP "11122221"
	BITMAP "13122221"
	BITMAP "........"
	BITMAP "........"
	BITMAP "......33"
	BITMAP ".....333"
	BITMAP "1...3333"
	BITMAP "1...3133"
	BITMAP "3....112"
	BITMAP "1....132"
	BITMAP "........"
	BITMAP "........"
	BITMAP "33......"
	BITMAP "333....."
	BITMAP "3333...1"
	BITMAP "3313...1"
	BITMAP "211....3"
	BITMAP "231....1"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "..33...1"
	BITMAP ".3333.11"
	BITMAP "12222131"
	BITMAP "12222111"
	BITMAP "12222131"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "....3..."
	BITMAP "....31.."
	BITMAP "....31.."
	BITMAP "....311."
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP ".....212"
	BITMAP ".1212123"
	BITMAP "12121213"
	BITMAP "21.....3"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "12......"
	BITMAP "..1....."
	BITMAP "1.2....."
	BITMAP "1......."
	BITMAP "......21"
	BITMAP "......11"
	BITMAP "......22"
	BITMAP ".....211"
	BITMAP ".....212"
	BITMAP "........"
	BITMAP "....1222"
	BITMAP "....3133"
	CHRROM PATTERN 272
	BITMAP "3......."
	BITMAP "3....111"
	BITMAP "23..1122"
	BITMAP "13..1..."
	BITMAP "13...122"
	BITMAP "....1322"
	BITMAP "221.1122"
	BITMAP "313.1..."
	BITMAP "........"
	BITMAP "1......."
	BITMAP "11......"
	BITMAP ".1.121.1"
	BITMAP "1......1"
	BITMAP "31.21.11"
	BITMAP "11....11"
	BITMAP ".1.1.111"
	BITMAP ".13....."
	BITMAP "113....."
	BITMAP "113....."
	BITMAP "113.2121"
	BITMAP "13......"
	BITMAP "13.21212"
	BITMAP "13......"
	BITMAP "13.12121"
	BITMAP "13122221"
	BITMAP "11111111"
	BITMAP ".1.....1"
	BITMAP "...111.."
	BITMAP "..12221."
	BITMAP ".1122211"
	BITMAP ".1322231"
	BITMAP ".1122211"
	CHRROM PATTERN 436
	BITMAP "1..1.112"
	BITMAP "...1.131"
	BITMAP "1.11.11."
	BITMAP "1.131..."
	BITMAP "1.111.11"
	BITMAP ".1.1.112"
	BITMAP ".3..1123"
	BITMAP ".1.11233"
	BITMAP "211.1..1"
	BITMAP "131.1..."
	BITMAP ".11.11.1"
	BITMAP "...131.1"
	BITMAP "11.111.1"
	BITMAP "211.1.1."
	BITMAP "3211..3."
	BITMAP "33211.1."
	BITMAP "12222131"
	BITMAP "11111111"
	BITMAP "1.....1."
	BITMAP "..111..."
	BITMAP ".12221.."
	BITMAP "1122211."
	BITMAP "1322231."
	BITMAP "1122211."
	BITMAP ".....31."
	BITMAP ".....311"
	BITMAP ".....311"
	BITMAP "1212.311"
	BITMAP "......31"
	BITMAP "21212.31"
	BITMAP "......31"
	BITMAP "12121.31"
	BITMAP "........"
	BITMAP ".......1"
	BITMAP "......11"
	BITMAP "1.121.1."
	BITMAP "1......1"
	BITMAP "11.12.13"
	BITMAP "11....11"
	BITMAP "111.1.1."
	BITMAP ".......3"
	BITMAP "111....3"
	BITMAP "2211..32"
	BITMAP "...1..31"
	BITMAP "221...31"
	BITMAP "2231...."
	BITMAP "2211.122"
	BITMAP "...1.313"
	BITMAP "12......"
	BITMAP "11......"
	BITMAP "22......"
	BITMAP "112....."
	BITMAP "212....."
	BITMAP "........"
	BITMAP "2221...."
	BITMAP "3313...."
	BITMAP "........"
	BITMAP "....1222"
	BITMAP "....1111"
	BITMAP "....1212"
	BITMAP "...11111"
	BITMAP "...11112"
	BITMAP "...11121"
	BITMAP "........"
	BITMAP ".....122"
	BITMAP "23..1322"
	BITMAP "13..1122"
	BITMAP "13..1322"
	BITMAP "13..1122"
	BITMAP "23...111"
	BITMAP "13......"
	BITMAP ".3......"
	BITMAP "1....1.1"
	BITMAP "31..1111"
	BITMAP "11..1111"
	BITMAP "31.11.11"
	BITMAP "11.11113"
	BITMAP "1...1113"
	BITMAP "...2...."
	BITMAP ".1112223"
	BITMAP "3......."
	BITMAP "31...33."
	BITMAP "311.3333"
	BITMAP "31312222"
	BITMAP ".1112222"
	BITMAP ".1312222"
	BITMAP ".1312222"
	BITMAP ".1111111"
	BITMAP "..12221."
	BITMAP "...111.."
	BITMAP ".113331."
	BITMAP "1113331."
	BITMAP "13.111.."
	BITMAP "11......"
	BITMAP "11.1111."
	BITMAP "1..121.."
	BITMAP "13.11233"
	BITMAP "...11123"
	BITMAP "11..1112"
	BITMAP "311..111"
	BITMAP "1311..21"
	BITMAP "11311.12"
	BITMAP ".1131.21"
	BITMAP "11113.13"
	BITMAP "33211.31"
	BITMAP "32111..."
	BITMAP "2111..11"
	BITMAP "111..113"
	BITMAP "12..1131"
	BITMAP "21.11311"
	BITMAP "12.1311."
	BITMAP "31.31111"
	BITMAP ".12221.."
	BITMAP "..111..."
	BITMAP ".133311."
	BITMAP ".1333111"
	BITMAP "..111.31"
	BITMAP "......11"
	BITMAP ".1111.11"
	BITMAP "..121..1"
	BITMAP ".......3"
	BITMAP ".33...13"
	BITMAP "3333.113"
	BITMAP "22221313"
	BITMAP "2222111."
	BITMAP "2222131."
	BITMAP "2222131."
	BITMAP "1111111."
	BITMAP "1.1....1"
	BITMAP "1111..13"
	BITMAP "1111..11"
	BITMAP "11.11.13"
	BITMAP "31111.11"
	BITMAP "3111...1"
	BITMAP "....2..."
	BITMAP "3222111."
	BITMAP "221....."
	BITMAP "2231..32"
	BITMAP "2211..31"
	BITMAP "2231..31"
	BITMAP "2211..31"
	BITMAP "111...32"
	BITMAP "......31"
	BITMAP "......3."
	BITMAP "........"
	BITMAP "2221...."
	BITMAP "1111...."
	BITMAP "2121...."
	BITMAP "11111..."
	BITMAP "21111..."
	BITMAP "12111..."
	BITMAP "........"
	BITMAP "...11.12"
	BITMAP "..113.11"
	BITMAP "..213.11"
	BITMAP "..113.11"
	BITMAP "..213.11"
	BITMAP "..111.11"
	BITMAP ".111.111"
	BITMAP ".11.1112"
	BITMAP "13......"
	BITMAP "113....."
	BITMAP "113....."
	BITMAP "213....2"
	BITMAP "113....1"
	BITMAP "113...11"
	BITMAP "223...12"
	BITMAP "113..211"
	BITMAP ".1211113"
	BITMAP "11212113"
	BITMAP "11112111"
	BITMAP ".1111111"
	BITMAP "2.1111.1"
	BITMAP "12.11111"
	BITMAP "112....."
	BITMAP "11122222"
	BITMAP "..1....."
	BITMAP "....111."
	BITMAP "3..12221"
	BITMAP "3.112221"
	BITMAP "3.132223"
	BITMAP "3.112221"
	BITMAP "...12221"
	BITMAP "3...111."
	BITMAP "11.11..1"
	BITMAP ".1.22.11"
	BITMAP ".1.11.11"
	BITMAP "1..22.12"
	BITMAP "1.111.12"
	BITMAP "1.121.12"
	BITMAP "..11..12"
	BITMAP ".111.113"
	BITMAP "11.11.32"
	BITMAP "11....12"
	BITMAP "211..113"
	BITMAP "321.1132"
	BITMAP "221.1.12"
	BITMAP "321...23"
	BITMAP "221...31"
	BITMAP "3311..12"
	BITMAP "23.11.11"
	BITMAP "21....11"
	BITMAP "311..112"
	BITMAP "2311.123"
	BITMAP "21.1.122"
	BITMAP "32...123"
	BITMAP "13...122"
	BITMAP "21..1133"
	BITMAP "1..11.11"
	BITMAP "11.22.1."
	BITMAP "11.11.1."
	BITMAP "21.22..1"
	BITMAP "21.111.1"
	BITMAP "21.121.1"
	BITMAP "21..11.."
	BITMAP "311.111."
	BITMAP ".....1.."
	BITMAP ".111...."
	BITMAP "12221..3"
	BITMAP "122211.3"
	BITMAP "322231.3"
	BITMAP "122211.3"
	BITMAP "12221..."
	BITMAP ".111...3"
	BITMAP "3111121."
	BITMAP "31121211"
	BITMAP "11121111"
	BITMAP "1111111."
	BITMAP "1.1111.2"
	BITMAP "11111.21"
	BITMAP ".....211"
	BITMAP "22222111"
	BITMAP "......31"
	BITMAP ".....311"
	BITMAP ".....311"
	BITMAP "2....312"
	BITMAP "1....311"
	BITMAP "11...311"
	BITMAP "21...322"
	BITMAP "112..311"
	BITMAP "21.11..."
	BITMAP "11.311.."
	BITMAP "11.312.."
	BITMAP "11.311.."
	BITMAP "11.312.."
	BITMAP "11.111.."
	BITMAP "111.111."
	BITMAP "2111.11."
	BITMAP ".1.11211"
	BITMAP "..112111"
	BITMAP "..111121"
	BITMAP "...11211"
	BITMAP "........"
	BITMAP "...11111"
	BITMAP "..111112"
	BITMAP ".1211123"
	BITMAP "113..121"
	BITMAP "213..112"
	BITMAP "113..111"
	BITMAP "21....11"
	BITMAP ".......1"
	BITMAP "113....."
	BITMAP "1113...."
	BITMAP "2113...."
	BITMAP "12111211"
	BITMAP "11111211"
	BITMAP "21121211"
	BITMAP "12111211"
	BITMAP "11211211"
	BITMAP "11121211"
	BITMAP ".1112211"
	BITMAP "..11.211"
	BITMAP "3..13331"
	BITMAP "3..13331"
	BITMAP "13..111."
	BITMAP "13......"
	BITMAP "113....."
	BITMAP "213....."
	BITMAP "113....."
	BITMAP "2113...."
	BITMAP ".22..133"
	BITMAP ".11...11"
	BITMAP ".222...."
	BITMAP ".1212..."
	BITMAP "..3212.."
	BITMAP "...1212."
	BITMAP "....3212"
	BITMAP ".....121"
	CHRROM PATTERN 476
	BITMAP "3331...3"
	BITMAP "111...12"
	BITMAP ".......1"
	BITMAP "......12"
	BITMAP ".......3"
	BITMAP "......12"
	BITMAP ".......1"
	BITMAP "2.....12"
	BITMAP "3...1333"
	BITMAP "21...111"
	BITMAP "1......."
	BITMAP "21......"
	BITMAP "3......."
	BITMAP "21......"
	BITMAP "1......."
	BITMAP "21.....2"
	BITMAP "331..22."
	BITMAP "11...11."
	BITMAP "....222."
	BITMAP "...2121."
	BITMAP "..2123.."
	BITMAP ".2121..."
	BITMAP "2123...."
	BITMAP "121....."
	BITMAP "13331..3"
	BITMAP "13331..3"
	BITMAP ".111..31"
	BITMAP "......31"
	BITMAP ".....311"
	BITMAP ".....312"
	BITMAP ".....311"
	BITMAP "....3112"
	BITMAP "11211121"
	BITMAP "11211111"
	BITMAP "11212112"
	BITMAP "11211121"
	BITMAP "11211211"
	BITMAP "11212111"
	BITMAP "1122111."
	BITMAP "112.11.."
	BITMAP "121..311"
	BITMAP "211..312"
	BITMAP "111..311"
	BITMAP "11....12"
	BITMAP "1......."
	BITMAP ".....311"
	BITMAP "....3111"
	BITMAP "....3112"
	BITMAP "11211.1."
	BITMAP "111211.."
	BITMAP "121111.."
	BITMAP "11211..."
	BITMAP "........"
	BITMAP "11111..."
	BITMAP "211111.."
	BITMAP "3211121."
	BITMAP ".1121123"
	BITMAP ".1112112"
	BITMAP ".1111211"
	BITMAP "..111121"
	BITMAP "...31112"
	BITMAP "....3111"
	BITMAP ".....111"
	BITMAP "......11"
	BITMAP "21113..."
	BITMAP "11113..."
	BITMAP "111113.."
	BITMAP "112113.."
	BITMAP "1111113."
	BITMAP "2111113."
	BITMAP "12112113"
	BITMAP "12111113"
	BITMAP "......21"
	BITMAP ".....112"
	BITMAP ".....111"
	BITMAP "......11"
	BITMAP ".......1"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "1113...."
	BITMAP "11113..."
	BITMAP "21113..."
	BITMAP "12113..."
	BITMAP "112113.."
	BITMAP "111213.."
	BITMAP ".11123.."
	BITMAP "..11113."
	BITMAP "......32"
	BITMAP "......31"
	BITMAP "......33"
	BITMAP "......33"
	BITMAP "......33"
	BITMAP "......33"
	BITMAP ".......3"
	BITMAP ".......3"
	BITMAP "1......3"
	BITMAP "21......"
	BITMAP "12......"
	BITMAP "21......"
	BITMAP "12......"
	BITMAP "21......"
	BITMAP "31......"
	BITMAP "33......"
	BITMAP "3......1"
	BITMAP "......12"
	BITMAP "......21"
	BITMAP "......12"
	BITMAP "......21"
	BITMAP "......12"
	BITMAP "......13"
	BITMAP "......33"
	BITMAP "23......"
	BITMAP "13......"
	BITMAP "33......"
	BITMAP "33......"
	BITMAP "33......"
	BITMAP "33......"
	BITMAP "3......."
	BITMAP "3......."
	BITMAP "....3111"
	BITMAP "...31111"
	BITMAP "...31112"
	BITMAP "...31121"
	BITMAP "..311211"
	BITMAP "..312111"
	BITMAP "..32111."
	BITMAP ".31111.."
	BITMAP "12......"
	BITMAP "211....."
	BITMAP "111....."
	BITMAP "11......"
	BITMAP "1......."
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "...31112"
	BITMAP "...31111"
	BITMAP "..311111"
	BITMAP "..311211"
	BITMAP ".3111111"
	BITMAP ".3111112"
	BITMAP "31121121"
	BITMAP "31111121"
	BITMAP "3211211."
	BITMAP "2112111."
	BITMAP "1121111."
	BITMAP "121111.."
	BITMAP "21113..."
	BITMAP "1113...."
	BITMAP "111....."
	BITMAP "11......"
	BITMAP ".......3"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "11211111"
	BITMAP "31121121"
	BITMAP ".1112111"
	BITMAP "..111211"
	BITMAP "...31121"
	BITMAP "....3112"
	BITMAP ".....111"
	BITMAP "......12"
	BITMAP "3......."
	BITMAP "3......."
	BITMAP "13......"
	BITMAP "13......"
	BITMAP "113....."
	BITMAP "123....."
	BITMAP "2113...."
	BITMAP "1113...."
	BITMAP "...1113."
	BITMAP "....1113"
	BITMAP ".....113"
	BITMAP "......11"
	BITMAP ".......1"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "3......."
	BITMAP "3......."
	BITMAP "13......"
	BITMAP ".3......"
	BITMAP "........"
	BITMAP "33......"
	BITMAP ".3......"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "......33"
	BITMAP "......3."
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP ".......3"
	BITMAP ".......3"
	BITMAP "......31"
	BITMAP "......3."
	BITMAP "........"
	BITMAP ".3111..."
	BITMAP "3111...."
	BITMAP "311....."
	BITMAP "11......"
	BITMAP "1......."
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP ".......3"
	BITMAP ".......3"
	BITMAP "......31"
	BITMAP "......31"
	BITMAP ".....311"
	BITMAP ".....321"
	BITMAP "....3112"
	BITMAP "....3111"
	BITMAP "11111211"
	BITMAP "12112113"
	BITMAP "1112111."
	BITMAP "112111.."
	BITMAP "12113..."
	BITMAP "2113...."
	BITMAP "111....."
	BITMAP "21......"
	BITMAP "3......."
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP ".......1"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "11113..."
	BITMAP "31213..."
	BITMAP ".31113.."
	BITMAP "..1113.."
	BITMAP "...1213."
	BITMAP "....113."
	BITMAP ".....113"
	BITMAP "......13"
	BITMAP "...31111"
	BITMAP "...31213"
	BITMAP "..31113."
	BITMAP "..3111.."
	BITMAP ".3121..."
	BITMAP ".311...."
	BITMAP "311....."
	BITMAP "31......"
	BITMAP "1......."
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	' ---- LOGO FALCON SOFT (v0.16) ----
	' splash inicial: CHRROM 1 = CHRRAM pagina 1 (POKE $1C,$20)
	' cinza=idx2 branco=idx3; fade por palette cycling ($3F02/$3F03)
	CHRROM 1
	CHRROM PATTERN 96

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "...22222"
	BITMAP "..22...."
	BITMAP "....2..."
	BITMAP "....2..."
	BITMAP "....2..."

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "22222222"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "2......."
	BITMAP "2222...."
	BITMAP "....22.."
	BITMAP "......2."
	BITMAP ".22222.2"

	BITMAP "....2..."
	BITMAP "....2..."
	BITMAP "....2..."
	BITMAP "...2...."
	BITMAP "...2...."
	BITMAP "..2....."
	BITMAP "..2....."
	BITMAP ".2......"

	BITMAP "...2..22"
	BITMAP "...2.22."
	BITMAP "........"
	BITMAP "........"
	BITMAP "......22"
	BITMAP ".....2.."
	BITMAP "........"
	BITMAP "....2222"

	BITMAP "222222.."
	BITMAP "......2."
	BITMAP "......2."
	BITMAP "......2."
	BITMAP "222....2"
	BITMAP "...222.2"
	BITMAP ".22...22"
	BITMAP "2......."

	BITMAP "........"
	BITMAP "........"
	BITMAP ".......2"
	BITMAP "........"
	BITMAP "......33"
	BITMAP "......33"
	BITMAP ".....333"
	BITMAP ".....333"

	BITMAP "........"
	BITMAP "........"
	BITMAP "22222222"
	BITMAP "........"
	BITMAP "33333333"
	BITMAP "33333333"
	BITMAP "33333333"
	BITMAP "33333333"

	BITMAP ".......2"
	BITMAP ".....22."
	BITMAP "22222..."
	BITMAP "........"
	BITMAP "3333.333"
	BITMAP "333..333"
	BITMAP "333.3333"
	BITMAP "333.3333"

	BITMAP "2......."
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "3333...."
	BITMAP "3333...3"
	BITMAP "3333...3"
	BITMAP "3333...3"

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "33....33"
	BITMAP "33....33"
	BITMAP "33....33"

	BITMAP ".......2"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "3333...."
	BITMAP "33333..3"
	BITMAP "3.333.33"

	BITMAP "........"
	BITMAP "222....."
	BITMAP "...22222"
	BITMAP "........"
	BITMAP "..3333.."
	BITMAP "33333333"
	BITMAP "33333333"
	BITMAP "33333333"

	BITMAP "........"
	BITMAP "........"
	BITMAP "22222222"
	BITMAP "........"
	BITMAP "........"
	BITMAP "3...3333"
	BITMAP "33..3333"
	BITMAP "333.3333"

	BITMAP "........"
	BITMAP "........"
	BITMAP "22222222"
	BITMAP "........"
	BITMAP "........"
	BITMAP "33...333"
	BITMAP "333...33"
	BITMAP "3333..33"

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "33......"
	BITMAP "333....."
	BITMAP "333....."

	BITMAP "....3333"
	BITMAP "....3333"
	BITMAP "...33333"
	BITMAP "...33333"
	BITMAP "...33333"
	BITMAP "..333333"
	BITMAP "..333333"
	BITMAP ".3333333"

	BITMAP "33......"
	BITMAP "33......"
	BITMAP "33......"
	BITMAP "3......."
	BITMAP "3......."
	BITMAP "3......."
	BITMAP "........"
	BITMAP "3333333."

	BITMAP "....3333"
	BITMAP "...33333"
	BITMAP "...33333"
	BITMAP "..333333"
	BITMAP "..333333"
	BITMAP "..333333"
	BITMAP ".3333333"
	BITMAP ".3333333"

	BITMAP "3333...3"
	BITMAP "3333...3"
	BITMAP "3333..33"
	BITMAP "3333..33"
	BITMAP "3333..33"
	BITMAP "3333..33"
	BITMAP "3333..33"
	BITMAP "3333..33"

	BITMAP "33....33"
	BITMAP "33....33"
	BITMAP "33....33"
	BITMAP "33....33"
	BITMAP "33....33"
	BITMAP "33....33"
	BITMAP "33....33"
	BITMAP "33....33"

	BITMAP "3.333.33"
	BITMAP "3.333.33"
	BITMAP "3.333.33"
	BITMAP "3.333..3"
	BITMAP "3.333..3"
	BITMAP "3.333..3"
	BITMAP "3......3"
	BITMAP "3......3"

	BITMAP "3333..33"
	BITMAP "3333..33"
	BITMAP "3333..33"
	BITMAP "3333..33"
	BITMAP "33333..3"
	BITMAP "33333..3"
	BITMAP "33333..3"
	BITMAP "33333..3"

	BITMAP "333..333"
	BITMAP "3333.333"
	BITMAP "3333.333"
	BITMAP "3333..33"
	BITMAP "3333..33"
	BITMAP "33333.33"
	BITMAP "33333.33"
	BITMAP "33333..3"

	BITMAP "33333..3"
	BITMAP "33333..3"
	BITMAP "333333.3"
	BITMAP "333333.."
	BITMAP "3333333."
	BITMAP "33333333"
	BITMAP "33333333"
	BITMAP "33333333"

	BITMAP "333....."
	BITMAP "3333...."
	BITMAP "3333...."
	BITMAP "33333..."
	BITMAP "33333..."
	BITMAP ".33333.."
	BITMAP ".33333.."
	BITMAP "3333333."

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP ".......3"
	BITMAP ".......3"
	BITMAP "......33"
	BITMAP "......33"
	BITMAP ".....333"

	BITMAP ".3333333"
	BITMAP "33333333"
	BITMAP "33333333"
	BITMAP "3333333."
	BITMAP "333333.."
	BITMAP "333333.."
	BITMAP "33333..."
	BITMAP "33333..."

	BITMAP "333333.."
	BITMAP "333333.."
	BITMAP "333333.."
	BITMAP ".......3"
	BITMAP ".......3"
	BITMAP "......33"
	BITMAP "......22"
	BITMAP "......22"

	BITMAP "333333.3"
	BITMAP "333333.3"
	BITMAP "333333.3"
	BITMAP "33333..3"
	BITMAP "33332..2"
	BITMAP "32222..2"
	BITMAP "22222222"
	BITMAP "22222222"

	BITMAP "3333..33"
	BITMAP "3333..33"
	BITMAP "3333..22"
	BITMAP "2222..22"
	BITMAP "2222..22"
	BITMAP "2222..22"
	BITMAP "2222..22"
	BITMAP "2222..22"

	BITMAP "33....33"
	BITMAP "33....33"
	BITMAP "22....22"
	BITMAP "22....22"
	BITMAP "22....22"
	BITMAP "22....22"
	BITMAP "22....22"
	BITMAP "22....22"

	BITMAP "3......3"
	BITMAP "3......3"
	BITMAP "2.2222.2"
	BITMAP "2.2222.2"
	BITMAP "2.2222.2"
	BITMAP "2.2222.."
	BITMAP "2.2222.."
	BITMAP "2.2222.."

	BITMAP "33333..3"
	BITMAP "33333..."
	BITMAP "222233.."
	BITMAP "222222.."
	BITMAP "222222.."
	BITMAP "222222.."
	BITMAP "222222.."
	BITMAP "2222222."

	BITMAP "333333.3"
	BITMAP "333333.3"
	BITMAP "333333.."
	BITMAP "223333.."
	BITMAP "2222223."
	BITMAP "2222222."
	BITMAP ".222222."
	BITMAP ".2222222"

	BITMAP "33333333"
	BITMAP "33333333"
	BITMAP "33333.33"
	BITMAP "33333..3"
	BITMAP "333333.3"
	BITMAP "333333.3"
	BITMAP ".22233.."
	BITMAP ".222222."

	BITMAP "3333333."
	BITMAP "33333333"
	BITMAP "33333333"
	BITMAP "33333333"
	BITMAP "33333333"
	BITMAP "33333333"
	BITMAP "33333333"
	BITMAP "33333333"

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "3......."
	BITMAP "3......."
	BITMAP "33......"
	BITMAP "33......"
	BITMAP "33......"

	BITMAP ".....333"
	BITMAP ".....333"
	BITMAP "....3333"
	BITMAP "....3333"
	BITMAP "...33332"
	BITMAP "...33322"
	BITMAP "..332222"
	BITMAP "..222222"

	BITMAP "3333...."
	BITMAP "3333...."
	BITMAP "3333...."
	BITMAP "332....."
	BITMAP "222....."
	BITMAP "22......"
	BITMAP "22......"
	BITMAP "22......"

	BITMAP ".....222"
	BITMAP ".....222"
	BITMAP "....2222"
	BITMAP "....2222"
	BITMAP "....2222"
	BITMAP "...22222"
	BITMAP "...22222"
	BITMAP "..222222"

	BITMAP "22222222"
	BITMAP "22222222"
	BITMAP "22222222"
	BITMAP "222...22"
	BITMAP "222...22"
	BITMAP "22....22"
	BITMAP "22....22"
	BITMAP "22....22"

	BITMAP "2222..22"
	BITMAP "2222..22"
	BITMAP "2222..22"
	BITMAP "2222..22"
	BITMAP "2222..22"
	BITMAP "222....."
	BITMAP "22......"
	BITMAP "2..33333"

	BITMAP "22....22"
	BITMAP "22222.22"
	BITMAP "22222.22"
	BITMAP "22222.22"
	BITMAP "22222..2"
	BITMAP "........"
	BITMAP "........"
	BITMAP "...3333."

	BITMAP "2.2222.."
	BITMAP "2.2222.."
	BITMAP "222222.."
	BITMAP "222222.."
	BITMAP "2222...."
	BITMAP "........"
	BITMAP "........"
	BITMAP ".33333.3"

	BITMAP "2222222."
	BITMAP "2222222."
	BITMAP "2222222."
	BITMAP "2222222."
	BITMAP "2222222."
	BITMAP "......22"
	BITMAP "......22"
	BITMAP "33333..2"

	BITMAP ".2222222"
	BITMAP ".2222222"
	BITMAP ".2222222"
	BITMAP "..222222"
	BITMAP "..222222"
	BITMAP "..222222"
	BITMAP "..222222"
	BITMAP "..222222"

	BITMAP ".222222."
	BITMAP ".222222."
	BITMAP "..222222"
	BITMAP "2.222222"
	BITMAP "2.222222"
	BITMAP "2..22222"
	BITMAP "2..22222"
	BITMAP "22.22222"

	BITMAP ".3333333"
	BITMAP ".2223333"
	BITMAP "..222233"
	BITMAP "...22222"
	BITMAP "...22222"
	BITMAP "2...2222"
	BITMAP "2...2222"
	BITMAP "2....222"

	BITMAP "333....."
	BITMAP "333....."
	BITMAP "3333...."
	BITMAP "3333...."
	BITMAP "22333..."
	BITMAP "22223..."
	BITMAP "222223.."
	BITMAP "222222.."

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP ".......2"
	BITMAP ".......2"
	BITMAP "......22"

	BITMAP ".2222222"
	BITMAP ".2222222"
	BITMAP "22222222"
	BITMAP "22222222"
	BITMAP "2222222."
	BITMAP "2222222."
	BITMAP "2222222."
	BITMAP "222222.."

	BITMAP "2......."
	BITMAP "2......."
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP "..222222"
	BITMAP "..222222"
	BITMAP ".2222222"
	BITMAP ".2222222"
	BITMAP "22222222"
	BITMAP "22222222"
	BITMAP ".....222"
	BITMAP "........"

	BITMAP "22....22"
	BITMAP "2.....22"
	BITMAP "2.....22"
	BITMAP "2.....22"
	BITMAP "......22"
	BITMAP "......22"
	BITMAP "......22"
	BITMAP "........"

	BITMAP "..333333"
	BITMAP "..333333"
	BITMAP "..333.33"
	BITMAP ".333.333"
	BITMAP ".333.333"
	BITMAP ".3333.33"
	BITMAP "..333..."
	BITMAP "..3333.."

	BITMAP "..333333"
	BITMAP "..333333"
	BITMAP ".333.333"
	BITMAP ".333.333"
	BITMAP ".333.333"
	BITMAP ".333.333"
	BITMAP ".333.333"
	BITMAP ".333.333"

	BITMAP ".33333.3"
	BITMAP ".33333.3"
	BITMAP ".333...."
	BITMAP ".333...."
	BITMAP ".333...."
	BITMAP ".333...."
	BITMAP ".333...."
	BITMAP ".333...."

	BITMAP "33333..2"
	BITMAP "333....2"
	BITMAP "3333...2"
	BITMAP ".333.222"
	BITMAP ".333.222"
	BITMAP ".333..22"
	BITMAP ".333..22"
	BITMAP ".333...."

	BITMAP "..222222"
	BITMAP "22222222"
	BITMAP "22222222"
	BITMAP "22222222"
	BITMAP "22222222"
	BITMAP "22222222"
	BITMAP "2222222."
	BITMAP "22222..."

	BITMAP "22.22222"
	BITMAP "22..2222"
	BITMAP "22..2222"
	BITMAP "22..2222"
	BITMAP "2....222"
	BITMAP "2....222"
	BITMAP "........"
	BITMAP "........"

	BITMAP "22....22"
	BITMAP "22....22"
	BITMAP "22.....2"
	BITMAP "222....2"
	BITMAP "222....."
	BITMAP "2222...."
	BITMAP "..22...."
	BITMAP "........"

	BITMAP "2222222."
	BITMAP "2222222."
	BITMAP "22222222"
	BITMAP "22222222"
	BITMAP "22222222"
	BITMAP "22222222"
	BITMAP ".2222222"
	BITMAP ".2222222"

	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "2......."
	BITMAP "2......."
	BITMAP "22......"

	BITMAP "......22"
	BITMAP ".....222"
	BITMAP ".....22."
	BITMAP "....2..."
	BITMAP "......22"
	BITMAP "....22.."
	BITMAP "...2...."
	BITMAP "..2....."

	BITMAP "22222..."
	BITMAP "22....22"
	BITMAP "...222.."
	BITMAP "222....."
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP "...22222"
	BITMAP "222....."
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP "22222222"
	BITMAP ".......2"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP "........"
	BITMAP "22......"
	BITMAP "..22...."
	BITMAP "....2..."
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP "...333.."
	BITMAP "...3333."
	BITMAP "333.333."
	BITMAP "333.3222"
	BITMAP "333.2222"
	BITMAP "332..222"
	BITMAP "322.2222"
	BITMAP "222.2222"

	BITMAP ".333.222"
	BITMAP ".222.222"
	BITMAP ".222.222"
	BITMAP ".222.222"
	BITMAP ".222.222"
	BITMAP ".222.222"
	BITMAP ".222.222"
	BITMAP ".222.222"

	BITMAP ".222.33."
	BITMAP ".222222."
	BITMAP ".222222."
	BITMAP ".2222..."
	BITMAP ".222...."
	BITMAP ".222...."
	BITMAP ".222...."
	BITMAP ".222...."

	BITMAP ".333...."
	BITMAP ".333...."
	BITMAP ".333...."
	BITMAP ".2233..."
	BITMAP ".2223..."
	BITMAP ".2222..."
	BITMAP ".2222..."
	BITMAP "..222..."

	BITMAP "........"
	BITMAP "......22"
	BITMAP "....22.."
	BITMAP "...2...."
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP "22222222"
	BITMAP "2......."
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP "22222..."
	BITMAP ".....222"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP "....2222"
	BITMAP "22.....2"
	BITMAP "..222..."
	BITMAP ".....222"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP "22......"
	BITMAP "222....."
	BITMAP "..2....."
	BITMAP "...2...."
	BITMAP "22......"
	BITMAP "..2....."
	BITMAP "...22..."
	BITMAP "........"

	BITMAP "222.2222"
	BITMAP ".2222222"
	BITMAP "..222222"
	BITMAP "...2222."
	BITMAP "........"
	BITMAP "........"
	BITMAP "22......"
	BITMAP "..22...."

	BITMAP ".222.222"
	BITMAP ".222.222"
	BITMAP ".222.222"
	BITMAP ".222.222"
	BITMAP ".222.222"
	BITMAP ".2222222"
	BITMAP "..222222"
	BITMAP "..222222"

	BITMAP ".222...."
	BITMAP ".222...."
	BITMAP ".222...."
	BITMAP ".222...."
	BITMAP ".222...."
	BITMAP ".222...."
	BITMAP ".222...."
	BITMAP ".222...."

	BITMAP "..222..."
	BITMAP "..222..."
	BITMAP "..22...."
	BITMAP "..2....."
	BITMAP "........"
	BITMAP "....2..."
	BITMAP "..22...."
	BITMAP "22......"

	BITMAP "....22.."
	BITMAP "......2."
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	BITMAP "....2222"
	BITMAP ".....22."
	BITMAP ".2......"
	BITMAP "..222222"
	BITMAP "....2222"
	BITMAP "......2."
	BITMAP "........"
	BITMAP "........"

	BITMAP ".22....2"
	BITMAP "......2."
	BITMAP "...2...."
	BITMAP "222....."
	BITMAP "2......."
	BITMAP "........"
	BITMAP "........"
	BITMAP "........"

	' letra 'a' (fonte CVBasic) p/ "apresenta"
	CHRROM PATTERN 182
	BITMAP "..333..."
	BITMAP ".33.33.."
	BITMAP "33...33."
	BITMAP "33...33."
	BITMAP "3333333."
	BITMAP "33...33."
	BITMAP "33...33."
	BITMAP "........"

	' letra 'e' (fonte CVBasic) p/ "apresenta"
	CHRROM PATTERN 183
	BITMAP "3333333."
	BITMAP "33......"
	BITMAP "33......"
	BITMAP "333333.."
	BITMAP "33......"
	BITMAP "33......"
	BITMAP "3333333."
	BITMAP "........"

	' letra 'n' (fonte CVBasic) p/ "apresenta"
	CHRROM PATTERN 184
	BITMAP "33...33."
	BITMAP "333..33."
	BITMAP "3333.33."
	BITMAP "3333333."
	BITMAP "33.3333."
	BITMAP "33..333."
	BITMAP "33...33."
	BITMAP "........"

	' letra 'p' (fonte CVBasic) p/ "apresenta"
	CHRROM PATTERN 185
	BITMAP "333333.."
	BITMAP "33...33."
	BITMAP "33...33."
	BITMAP "33...33."
	BITMAP "333333.."
	BITMAP "33......"
	BITMAP "33......"
	BITMAP "........"

	' letra 'r' (fonte CVBasic) p/ "apresenta"
	CHRROM PATTERN 186
	BITMAP "333333.."
	BITMAP "33...33."
	BITMAP "33...33."
	BITMAP "33..333."
	BITMAP "33333..."
	BITMAP "33.333.."
	BITMAP "33..333."
	BITMAP "........"

	' letra 's' (fonte CVBasic) p/ "apresenta"
	CHRROM PATTERN 187
	BITMAP ".3333..."
	BITMAP "33..33.."
	BITMAP "33......"
	BITMAP ".33333.."
	BITMAP ".....33."
	BITMAP "33...33."
	BITMAP ".33333.."
	BITMAP "........"

	' letra 't' (fonte CVBasic) p/ "apresenta"
	CHRROM PATTERN 188
	BITMAP ".333333."
	BITMAP "...33..."
	BITMAP "...33..."
	BITMAP "...33..."
	BITMAP "...33..."
	BITMAP "...33..."
	BITMAP "...33..."
	BITMAP "........"

BANK 3	' v0.19: FASE 2 - PLANETA DE LAVA (setup, terreno, canhoes)

lava_wr: PROCEDURE		' escreve 960 tiles a partir do READ em #bk (base NT)
	FOR r = 0 TO 29
		FOR i = 0 TO 31
			READ BYTE e
			VPOKE #bk, e
			#bk = #bk + 1
		NEXT i
	NEXT r
	END

lava_setup: PROCEDURE	' v0.26: scroll da lava = scroll da fase 1 (PONTO)
	PALETTE LOAD lava_palette
	POKE $1C,$40		' CHR-RAM pagina 2 (tiles + sprites da lava)
	' Igual a fase 1 (que sempre funcionou): TRES nametables IDENTICAS,
	' so' conteudo estatico, e o scroll byte cuida do loop. Conteudo =
	' mar de lava (textura 2x2 dos tiles 96/97/98/99, do proprio
	' desenho do Saulo) + 5 ilhas PEQUENAS 2x2 (v0.27) nas mesmas
	' posicoes das 3 paginas. Sem canhoes, sem eventos, sem anel,
	' sem flip, sem strip.
	#bk = $2000
	GOSUB lava_sea_fill
	#bk = $2400
	GOSUB lava_sea_fill
	#bk = $2800
	GOSUB lava_sea_fill
	END

lava_sea_fill:	' mar de lava 2x2 + ilhas 2x2 em cima de #bk (v0.27)
	#tw = #bk
	FOR r = 0 TO 29
		FOR c = 0 TO 31
			VPOKE #tw, 96 + (c AND 1) + 2 * (r AND 1)
			#tw = #tw + 1
		NEXT c
		WAIT			' 32 writes/frame: folga no buffer do NMI
	NEXT r
	' v0.27: 5 ilhas PEQUENAS (2x2 = 4 tiles de 8x8) em linhas/cols
	' pares, iguais nas 3 paginas -> conteudo estatico, scroll perfeito.
	#tw = #bk + 134		' ilha A: linha 4, col 6
	GOSUB lava_isl_a
	#tw = #bk + 342		' ilha B: linha 10, col 22
	GOSUB lava_isl_b
	#tw = #bk + 524		' ilha C: linha 16, col 12
	GOSUB lava_isl_c
	WAIT
	#tw = #bk + 666		' ilha A: linha 20, col 26
	GOSUB lava_isl_a
	#tw = #bk + 834		' ilha B: linha 26, col 2
	GOSUB lava_isl_b
	WAIT
	RETURN

lava_isl_a:	' ilha pequena A (2x2) com topo-esquerdo em #tw
	VPOKE #tw, 108
	VPOKE #tw + 1, 109
	VPOKE #tw + 32, 110
	VPOKE #tw + 33, 111
	RETURN

lava_isl_b:	' ilha pequena B (2x2)
	VPOKE #tw, 119
	VPOKE #tw + 1, 153
	VPOKE #tw + 32, 154
	VPOKE #tw + 33, 155
	RETURN

lava_isl_c:	' ilha pequena C (2x2)
	VPOKE #tw, 149
	VPOKE #tw + 1, 150
	VPOKE #tw + 32, 151
	VPOKE #tw + 33, 152
	RETURN


lava_tick: PROCEDURE	' v0.24: flip no TOPO na fase 7; strip $2800 na 6
	' (bug v0.22 provado no emu: 64/70 writes caiam em slots VISIVEIS
	' inclusive o MEIO da tela porque #ld andava +32 e o topo anda -32;
	' v0.23 acertou o slot mas flipava 8px cedo e abandonou o $2800).
	IF (scroll_y AND 7) = 7 THEN
		GOSUB lava_in
	ELSEIF (scroll_y AND 7) = 6 THEN
		IF wrf = 1 THEN GOSUB lava_strip
	END IF
	END

lava_in: PROCEDURE	' v0.24: flip do slot do TOPO no frame da costura
	IF wrf = 0 THEN		' 1a costura: trava a fase do anel com o scroll
		wr = scroll_y / 8		' slot do topo agora (0-29)
		wrf = 1
	ELSE
		wr = wr - 1		' linha-mundo seguinte (anel 60: wrap 0->59)
		IF wr = $ff THEN wr = 59
	END IF
	w = wr			' w = linha dentro do mapa (0-29), RESTORE na metade
	IF w >= 30 THEN
		w = w - 30
		RESTORE lava_map_b
	ELSE
		RESTORE lava_map_a
	END IF
	' #ld = $2000 + w*32; read_pointer += w*32 (low=w<<5, high=w>>3;
	' 16 bits de verdade = adeus bug do ASL sem carry da v0.19)
	ASM LDA cvb_W
	ASM ASL A
	ASM ASL A
	ASM ASL A
	ASM ASL A
	ASM ASL A
	ASM STA cvb_#LD
	ASM STA cvb_#T2
	ASM LDA cvb_W
	ASM LSR A
	ASM LSR A
	ASM LSR A
	ASM STA cvb_#T2+1
	ASM CLC
	ASM ADC #$20
	ASM STA cvb_#LD+1
	ASM LDA read_pointer
	ASM CLC
	ASM ADC cvb_#T2
	ASM STA read_pointer
	ASM LDA read_pointer+1
	ASM ADC cvb_#T2+1
	ASM STA read_pointer+1
	FOR c = 0 TO 31		' 32 writes na mesma moldura (< PPUSIZE 48)
		READ BYTE e
		VPOKE #ld + c,e
	NEXT c
	END

lava_strip: PROCEDURE	' $2800 slot 0 = linha ABAIXO da janela (topo + 30)
	w = wr + 30
	IF w >= 60 THEN w = w - 60
lava_strip_w:		' entrada com w ja' calculado (lava_setup reusa)
	IF w >= 30 THEN
		w = w - 30
		RESTORE lava_map_b
	ELSE
		RESTORE lava_map_a
	END IF
	ASM LDA cvb_W
	ASM ASL A
	ASM ASL A
	ASM ASL A
	ASM ASL A
	ASM ASL A
	ASM STA cvb_#T2
	ASM LDA cvb_W
	ASM LSR A
	ASM LSR A
	ASM LSR A
	ASM STA cvb_#T2+1
	ASM LDA read_pointer
	ASM CLC
	ASM ADC cvb_#T2
	ASM STA read_pointer
	ASM LDA read_pointer+1
	ASM ADC cvb_#T2+1
	ASM STA read_pointer+1
	FOR c = 0 TO 31
		READ BYTE e
		VPOKE $2800 + c,e
	NEXT c
	END

	' ==== gerado por gera_lava.py (v0.19): layout da fase 2 ====
	' mapas EXPANDIDOS: 30 tile-rows x 32 tiles por metade
	' (metatile mx*2,my*2 -> tiles 2x2 via tabela de ids dedup)
lava_map_a:
	DATA BYTE 96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,112,113,116,97,96,97,96,97
	DATA BYTE 98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,114,115,117,118,98,99,98,99
	DATA BYTE 96,97,96,97,96,97,96,97,96,97,96,97,96,97,119,153,96,97,96,97,96,97,96,127,130,131,134,135,96,97,96,97
	DATA BYTE 98,99,98,99,98,99,98,99,98,99,98,99,98,99,154,155,98,99,98,99,98,99,128,129,132,133,136,137,98,99,98,99
	DATA BYTE 96,97,96,97,108,109,96,97,96,97,112,113,116,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97
	DATA BYTE 98,99,98,99,110,111,98,99,98,99,114,115,117,118,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99
	DATA BYTE 96,97,96,97,96,97,96,97,96,127,130,131,134,135,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97
	DATA BYTE 98,99,98,99,98,99,98,99,128,129,132,133,136,137,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99
	DATA BYTE 96,97,96,97,96,97,96,97,96,97,96,97,108,109,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97
	DATA BYTE 98,99,98,99,98,99,98,99,98,99,98,99,110,111,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99
	DATA BYTE 96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97
	DATA BYTE 98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99
	DATA BYTE 96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,119,153,96,97,96,97,96,97,96,97,96,97
	DATA BYTE 98,99,98,99,98,99,98,99,156,99,98,99,98,99,98,99,98,99,98,99,154,155,98,99,98,99,98,99,98,99,98,99
	DATA BYTE 96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97
	DATA BYTE 98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99
	DATA BYTE 96,97,96,97,96,97,119,153,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97
	DATA BYTE 98,99,98,99,98,99,154,155,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99
	DATA BYTE 96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97
	DATA BYTE 98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99
	DATA BYTE 96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,108,109,96,97,96,97,96,97,96,97,96,97,96,97
	DATA BYTE 98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,110,111,98,99,98,99,98,99,98,99,98,99,98,99
	DATA BYTE 96,97,96,97,96,97,96,97,96,97,119,153,149,150,96,97,149,150,108,109,96,97,96,97,96,97,119,153,96,97,96,97
	DATA BYTE 98,99,98,99,98,99,98,99,98,99,154,155,151,152,98,99,151,152,110,111,98,99,98,99,98,99,154,155,98,99,98,99
	DATA BYTE 96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97
	DATA BYTE 98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99
	DATA BYTE 96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97
	DATA BYTE 98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99
	DATA BYTE 96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,119,153,96,97,96,97,96,97
	DATA BYTE 98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,154,155,98,99,98,99,98,99
lava_map_b:
	DATA BYTE 96,97,96,97,96,97,96,97,96,97,96,97,108,109,96,97,96,97,96,97,96,97,96,97,96,97,149,150,96,97,96,97
	DATA BYTE 98,99,98,99,98,99,98,99,98,99,98,99,110,111,98,99,98,99,98,99,98,99,98,99,156,99,151,152,98,99,98,99
	DATA BYTE 119,120,123,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,108,109,96,97,96,97
	DATA BYTE 121,122,124,125,126,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,156,99,98,99,98,99,110,111,98,99,98,99
	DATA BYTE 96,138,141,142,145,146,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,119,153,96,97,96,97
	DATA BYTE 139,140,143,144,147,148,156,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,154,155,98,99,98,99
	DATA BYTE 96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97
	DATA BYTE 98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99
	DATA BYTE 96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97
	DATA BYTE 98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99
	DATA BYTE 96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,108,109,96,97,119,153,96,97
	DATA BYTE 98,99,98,99,98,99,98,99,156,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,110,111,98,99,154,155,98,99
	DATA BYTE 96,97,96,97,96,97,119,153,96,97,108,109,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,108,109,96,97
	DATA BYTE 98,99,98,99,98,99,154,155,98,99,110,111,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,110,111,98,99
	DATA BYTE 96,97,119,120,123,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,119,153,96,97,96,97
	DATA BYTE 98,99,121,122,124,125,126,99,98,99,98,99,98,99,156,99,98,99,98,99,98,99,98,99,98,99,154,155,98,99,98,99
	DATA BYTE 96,97,96,138,141,142,145,146,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97
	DATA BYTE 98,99,139,140,143,144,147,148,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99
	DATA BYTE 96,97,96,97,96,97,149,150,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97
	DATA BYTE 98,99,98,99,156,99,151,152,98,99,98,99,98,99,156,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99
	DATA BYTE 96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,108,109,96,97,119,153,96,97,96,97,96,97,96,97
	DATA BYTE 98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,110,111,98,99,154,155,98,99,98,99,98,99,98,99
	DATA BYTE 96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97
	DATA BYTE 98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,156,99,98,99
	DATA BYTE 96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,119,153,96,97,149,150
	DATA BYTE 98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,154,155,98,99,151,152
	DATA BYTE 96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,108,109,108,109,96,97,96,97,96,97,96,97,96,97,96,97
	DATA BYTE 98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,110,111,110,111,98,99,98,99,98,99,98,99,98,99,98,99
	DATA BYTE 96,97,96,97,96,97,119,153,96,97,96,97,149,150,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97,96,97
	DATA BYTE 98,99,98,99,98,99,154,155,98,99,98,99,151,152,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99,98,99
	' v0.28: FASE 4 - ATLANTIS. MESMOS tiles da lava (mar + ilhotas),
	' so' muda a paleta p/ agua. Setup identico (3 paginas estaticas
	' identicas) = scroll perfeito pelo mesmo esquema da fase 1.
agua_setup: PROCEDURE
	PALETTE LOAD agua_palette
	POKE $1C,$40		' mesma pagina 2 de CHR-RAM da lava
	#bk = $2000
	GOSUB lava_sea_fill
	#bk = $2400
	GOSUB lava_sea_fill
	#bk = $2800
	GOSUB lava_sea_fill
	END

	' (v0.28: stars_fill VOLTOU p/ o banco 0 - ver nota la'.)

lava_can:
	DATA BYTE 5
	DATA BYTE 12,9
	DATA BYTE 1,8
	DATA BYTE 10,28
	DATA BYTE 13,21
	DATA BYTE 5,29
lava_palette:
	DATA BYTE $07,$16,$1C,$0C	' fundo 0: LAVA (fundo universal $07)
	DATA BYTE $07,$16,$1C,$0C	' fundo 1 (idem: reserva)
	DATA BYTE $07,$16,$1C,$0C	' fundo 2
	DATA BYTE $07,$16,$1C,$0C	' fundo 3
	DATA BYTE $0F,$00,$10,$30	' sprites 0: cinzas (nave, placar)
	DATA BYTE $0F,$16,$21,$12	' sprites 1: vermelho/azuis
	DATA BYTE $0F,$19,$2A,$30	' sprites 2: verdes (chama/shard)
	DATA BYTE $0F,$1C,$3C,$30	' sprites 3: quentes (explosao/tiros)
agua_palette:					' v0.28: ATLANTIS (fase 4) - mesma
	DATA BYTE $0C,$11,$02,$01	'   estrutura da lava, so' azuis:
	DATA BYTE $0C,$11,$02,$01	'   universal $0C (azul profundo),
	DATA BYTE $0C,$11,$02,$01	'   veias $11, rocha $02/$01
	DATA BYTE $0C,$11,$02,$01
	DATA BYTE $0F,$00,$10,$30	' sprites iguais aos da lava
	DATA BYTE $0F,$16,$21,$12
	DATA BYTE $0F,$19,$2A,$30
	DATA BYTE $0F,$1C,$3C,$30

BANK 2	' v0.15: trilhas (~2.9KB): player do NMI rele music_bank a cada nota
mus_stage1:
	DATA BYTE 1
	MUSIC G4Y,G4X,G2W,M1
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,A4#X,S,M2
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,D5X,S,M1
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,G5X,S,M2
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,D5X,S,M1
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,A4#X,S,M2
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,M1
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,G4X,F2W,M1
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,A4#X,S,M2
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC G4Y,G4X,F2W,M1
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,A4#X,S,M2
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,D5X,S,M1
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,G5X,S,M2
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,D5X,S,M1
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,G5X,S,M2
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,M1
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,D5X,S,M1
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC D4#Y,A4#X,S,M2
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC D4#Y,F4X,F2W,M1
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,A4X,S,M2
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,C5X,S,M1
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,F5X,S,M2
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,C5X,G2W,M1
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,A4X,S,M2
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,M1
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC C4Y,F4X,S,M1
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,A4X,S,M2
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC C4Y,F4X,G2W,M1
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,A4X,S,M2
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,C5X,S,M1
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,A4X,S,M2
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,G4X,S,M1
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC D4Y,A4#X,S,M2
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,M1
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,D5X,S,M1
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC D4Y,G5X,S,M1
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC D4Y,G4X,G2W,M1
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,A4#X,S,M2
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,D5X,S,M1
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,G5X,S,M2
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,D5X,S,M1
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,A4#X,S,M2
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,M1
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,G4X,F2W,M1
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,A4#X,S,M2
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC D4Y,G4X,F2W,M1
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,A4#X,S,M2
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,D5X,S,M1
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,G5X,S,M2
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,D5X,S,M1
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,G5X,S,M2
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,M1
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,D5X,S,M1
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC D4#Y,A4#X,S,M2
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC D4#Y,F4X,F2W,M1
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,A4X,S,M2
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,C5X,S,M1
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,F5X,S,M2
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,C5X,G2W,M1
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,A4X,S,M2
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,M1
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC C4Y,F4X,S,M1
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,A4X,S,M2
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC C4Y,F4X,G2W,M1
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,A4X,S,M2
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,C5X,S,M1
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC D4Y,A4X,S,M2
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,G4X,S,M1
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,A4#X,S,M2
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,M1
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC D4Y,D5X,S,M1
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,G5X,S,M1
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC REPEAT

mus_title:
	DATA BYTE 2
	MUSIC D4#Y,B4W,G2#W,M1
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,G4#W,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,B4W,S,M1
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,D5#W,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC D4#Y,B4W,G2#W,M1
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,G4#W,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC D4#Y,D5#W,S,M1
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,B2W,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC G4#Y,B4W,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,C3W,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC G4#Y,B4W,G2#W,M1
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,G4#W,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,B4W,S,M1
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC F4#Y,D5#W,S,M1
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC F4#Y,G4#W,G2#W,M1
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,E4W,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,C4#W,C3#W,M1
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,E4W,S,M1
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC G4Y,G4W,G2W,M1
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,M2
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,B4W,S,M1
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,M2
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,D5W,S,M1
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,M2
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,G5W,S,M1
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,M2
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC G4Y,G4W,G2W,M1
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,M2
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,B4W,S,M1
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,M2
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC D4Y,D5W,S,M1
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,M2
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,B4W,S,M1
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,M2
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC B3Y,G4W,G2W,M1
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,M2
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC C4Y,B4W,S,M1
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,M2
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC D4#Y,D5W,S,M1
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,F2#W,M2
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,G5W,S,M1
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,M2
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC D4#Y,D5#W,G2W,M1
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,M2
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,C5#W,S,M1
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,M2
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,B4W,G2#W,M1
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC C4#Y,S,S,M2
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,G4#W,S,M1
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,M2
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC S,S,S,-
	MUSIC REPEAT

	' ==== gerado por gera_lava.py (v0.19): CHRROM 2 = fase 2 (lava) ====
	CHRROM 2

	' FONTE DO SAULO (32-95): copia byte-exata do ROM atual
	CHRROM PATTERN 32

	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"

	BITMAP "00033300"
	BITMAP "00033300"
	BITMAP "00033300"
	BITMAP "00033000"
	BITMAP "00033000"
	BITMAP "00000000"
	BITMAP "00033000"
	BITMAP "00033000"

	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"

	BITMAP "33333333"
	BITMAP "33333333"
	BITMAP "33333333"
	BITMAP "33333333"
	BITMAP "33333333"
	BITMAP "33333333"
	BITMAP "33333333"
	BITMAP "33333333"

	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"

	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"

	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"

	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00003000"
	BITMAP "00030000"
	BITMAP "00000000"

	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"

	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"

	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00300300"
	BITMAP "00033000"
	BITMAP "00033000"
	BITMAP "00300300"
	BITMAP "00000000"

	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"

	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00033000"
	BITMAP "00033000"
	BITMAP "00003000"

	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"

	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"

	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"

	BITMAP "00333000"
	BITMAP "03003300"
	BITMAP "33000330"
	BITMAP "33000330"
	BITMAP "33000330"
	BITMAP "03300300"
	BITMAP "00333000"
	BITMAP "00000000"

	BITMAP "00033000"
	BITMAP "00033000"
	BITMAP "00033000"
	BITMAP "00033000"
	BITMAP "00033000"
	BITMAP "00033000"
	BITMAP "03333330"
	BITMAP "00000000"

	BITMAP "03333300"
	BITMAP "33000330"
	BITMAP "00003330"
	BITMAP "00333300"
	BITMAP "03333000"
	BITMAP "33300000"
	BITMAP "33333330"
	BITMAP "00000000"

	BITMAP "03333330"
	BITMAP "00003300"
	BITMAP "00033000"
	BITMAP "00333300"
	BITMAP "00000330"
	BITMAP "33000330"
	BITMAP "03333300"
	BITMAP "00000000"

	BITMAP "00033300"
	BITMAP "00333300"
	BITMAP "03303300"
	BITMAP "33003300"
	BITMAP "33333330"
	BITMAP "00003300"
	BITMAP "00003300"
	BITMAP "00000000"

	BITMAP "33333300"
	BITMAP "33000000"
	BITMAP "33333300"
	BITMAP "00000330"
	BITMAP "00000330"
	BITMAP "33000330"
	BITMAP "03333300"
	BITMAP "00000000"

	BITMAP "00333300"
	BITMAP "03300000"
	BITMAP "33000000"
	BITMAP "33333300"
	BITMAP "33000330"
	BITMAP "33000330"
	BITMAP "03333300"
	BITMAP "00000000"

	BITMAP "33333330"
	BITMAP "33000330"
	BITMAP "00003300"
	BITMAP "00033000"
	BITMAP "00330000"
	BITMAP "00330000"
	BITMAP "00330000"
	BITMAP "00000000"

	BITMAP "03333300"
	BITMAP "33000330"
	BITMAP "33000330"
	BITMAP "03333300"
	BITMAP "33000330"
	BITMAP "33000330"
	BITMAP "03333300"
	BITMAP "00000000"

	BITMAP "03333300"
	BITMAP "33000330"
	BITMAP "33000330"
	BITMAP "03333330"
	BITMAP "00000330"
	BITMAP "00003300"
	BITMAP "03333000"
	BITMAP "00000000"

	BITMAP "00033000"
	BITMAP "00033000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00033000"
	BITMAP "00033000"
	BITMAP "00000000"
	BITMAP "00000000"

	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"

	BITMAP "00030000"
	BITMAP "00330000"
	BITMAP "03330000"
	BITMAP "33333333"
	BITMAP "33333333"
	BITMAP "03330000"
	BITMAP "00330000"
	BITMAP "00030000"

	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"

	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"

	BITMAP "00333300"
	BITMAP "03300330"
	BITMAP "03300330"
	BITMAP "00000330"
	BITMAP "00033000"
	BITMAP "00000000"
	BITMAP "00033000"
	BITMAP "00033000"

	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"

	BITMAP "00333000"
	BITMAP "03303300"
	BITMAP "33000330"
	BITMAP "33000330"
	BITMAP "33333330"
	BITMAP "33000330"
	BITMAP "33000330"
	BITMAP "00000000"

	BITMAP "33333300"
	BITMAP "33000330"
	BITMAP "33000330"
	BITMAP "33333300"
	BITMAP "33000330"
	BITMAP "33000330"
	BITMAP "33333300"
	BITMAP "00000000"

	BITMAP "00333300"
	BITMAP "03300330"
	BITMAP "33000000"
	BITMAP "33000000"
	BITMAP "33000000"
	BITMAP "03300330"
	BITMAP "00333300"
	BITMAP "00000000"

	BITMAP "33333000"
	BITMAP "33003300"
	BITMAP "33000330"
	BITMAP "33000330"
	BITMAP "33000330"
	BITMAP "33003300"
	BITMAP "33333000"
	BITMAP "00000000"

	BITMAP "33333330"
	BITMAP "33000000"
	BITMAP "33000000"
	BITMAP "33333300"
	BITMAP "33000000"
	BITMAP "33000000"
	BITMAP "33333330"
	BITMAP "00000000"

	BITMAP "33333330"
	BITMAP "33000000"
	BITMAP "33000000"
	BITMAP "33333300"
	BITMAP "33000000"
	BITMAP "33000000"
	BITMAP "33000000"
	BITMAP "00000000"

	BITMAP "00333330"
	BITMAP "03300000"
	BITMAP "33000000"
	BITMAP "33003330"
	BITMAP "33000330"
	BITMAP "03300330"
	BITMAP "00333330"
	BITMAP "00000000"

	BITMAP "33000330"
	BITMAP "33000330"
	BITMAP "33000330"
	BITMAP "33333330"
	BITMAP "33000330"
	BITMAP "33000330"
	BITMAP "33000330"
	BITMAP "00000000"

	BITMAP "03333330"
	BITMAP "00033000"
	BITMAP "00033000"
	BITMAP "00033000"
	BITMAP "00033000"
	BITMAP "00033000"
	BITMAP "03333330"
	BITMAP "00000000"

	BITMAP "00033330"
	BITMAP "00000330"
	BITMAP "00000330"
	BITMAP "00000330"
	BITMAP "33000330"
	BITMAP "33000330"
	BITMAP "03333300"
	BITMAP "00000000"

	BITMAP "33000330"
	BITMAP "33003300"
	BITMAP "33033000"
	BITMAP "33330000"
	BITMAP "33333000"
	BITMAP "33033300"
	BITMAP "33003330"
	BITMAP "00000000"

	BITMAP "03300000"
	BITMAP "03300000"
	BITMAP "03300000"
	BITMAP "03300000"
	BITMAP "03300000"
	BITMAP "03300000"
	BITMAP "03333330"
	BITMAP "00000000"

	BITMAP "33000330"
	BITMAP "33303330"
	BITMAP "33333330"
	BITMAP "33333330"
	BITMAP "33030330"
	BITMAP "33000330"
	BITMAP "33000330"
	BITMAP "00000000"

	BITMAP "33000330"
	BITMAP "33300330"
	BITMAP "33330330"
	BITMAP "33333330"
	BITMAP "33033330"
	BITMAP "33003330"
	BITMAP "33000330"
	BITMAP "00000000"

	BITMAP "03333300"
	BITMAP "33000330"
	BITMAP "33000330"
	BITMAP "33000330"
	BITMAP "33000330"
	BITMAP "33000330"
	BITMAP "03333300"
	BITMAP "00000000"

	BITMAP "33333300"
	BITMAP "33000330"
	BITMAP "33000330"
	BITMAP "33000330"
	BITMAP "33333300"
	BITMAP "33000000"
	BITMAP "33000000"
	BITMAP "00000000"

	BITMAP "03333300"
	BITMAP "33000330"
	BITMAP "33000330"
	BITMAP "33000330"
	BITMAP "33033330"
	BITMAP "33003300"
	BITMAP "03333030"
	BITMAP "00000000"

	BITMAP "33333300"
	BITMAP "33000330"
	BITMAP "33000330"
	BITMAP "33003330"
	BITMAP "33333000"
	BITMAP "33033300"
	BITMAP "33003330"
	BITMAP "00000000"

	BITMAP "03333000"
	BITMAP "33003300"
	BITMAP "33000000"
	BITMAP "03333300"
	BITMAP "00000330"
	BITMAP "33000330"
	BITMAP "03333300"
	BITMAP "00000000"

	BITMAP "03333330"
	BITMAP "00033000"
	BITMAP "00033000"
	BITMAP "00033000"
	BITMAP "00033000"
	BITMAP "00033000"
	BITMAP "00033000"
	BITMAP "00000000"

	BITMAP "33000330"
	BITMAP "33000330"
	BITMAP "33000330"
	BITMAP "33000330"
	BITMAP "33000330"
	BITMAP "33000330"
	BITMAP "03333300"
	BITMAP "00000000"

	BITMAP "33000330"
	BITMAP "33000330"
	BITMAP "33000330"
	BITMAP "33303330"
	BITMAP "03333300"
	BITMAP "00333000"
	BITMAP "00030000"
	BITMAP "00000000"

	BITMAP "33000330"
	BITMAP "33000330"
	BITMAP "33030330"
	BITMAP "33333330"
	BITMAP "33333330"
	BITMAP "33303330"
	BITMAP "33000330"
	BITMAP "00000000"

	BITMAP "33000330"
	BITMAP "33303330"
	BITMAP "03333300"
	BITMAP "00333000"
	BITMAP "03333300"
	BITMAP "33303330"
	BITMAP "33000330"
	BITMAP "00000000"

	BITMAP "03300330"
	BITMAP "03300330"
	BITMAP "03300330"
	BITMAP "00333300"
	BITMAP "00033000"
	BITMAP "00033000"
	BITMAP "00033000"
	BITMAP "00000000"

	BITMAP "33333330"
	BITMAP "00003330"
	BITMAP "00033300"
	BITMAP "00333000"
	BITMAP "03330000"
	BITMAP "33300000"
	BITMAP "33333330"
	BITMAP "00000000"

	BITMAP "00000000"
	BITMAP "03330000"
	BITMAP "00030000"
	BITMAP "00030000"
	BITMAP "00030000"
	BITMAP "00030000"
	BITMAP "03330000"
	BITMAP "00000000"

	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"

	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"

	BITMAP "00033000"
	BITMAP "00333300"
	BITMAP "03333330"
	BITMAP "33333333"
	BITMAP "00033000"
	BITMAP "00033000"
	BITMAP "00033000"
	BITMAP "00033000"

	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"


	' tiles da lava (dedup): metatiles 16x16 -> 4 subtiles 8x8
	CHRROM PATTERN 96

	BITMAP "01000000"
	BITMAP "10000011"
	BITMAP "01000100"
	BITMAP "00111000"
	BITMAP "01000100"
	BITMAP "10000011"
	BITMAP "00000100"
	BITMAP "00111000"

	BITMAP "10010000"
	BITMAP "10010111"
	BITMAP "01011000"
	BITMAP "00100100"
	BITMAP "00100100"
	BITMAP "11000011"
	BITMAP "00100010"
	BITMAP "00010010"

	BITMAP "11001000"
	BITMAP "00001111"
	BITMAP "00001000"
	BITMAP "00000100"
	BITMAP "11001011"
	BITMAP "00110001"
	BITMAP "00100000"
	BITMAP "01000000"

	BITMAP "00010011"
	BITMAP "00011100"
	BITMAP "11010000"
	BITMAP "00101000"
	BITMAP "11000111"
	BITMAP "00001000"
	BITMAP "10010000"
	BITMAP "10010000"

	BITMAP "00111111"
	BITMAP "01222222"
	BITMAP "12333131"
	BITMAP "12332222"
	BITMAP "12323333"
	BITMAP "12123322"
	BITMAP "12023230"
	BITMAP "12323201"

	BITMAP "11111100"
	BITMAP "22222210"
	BITMAP "31313321"
	BITMAP "22223321"
	BITMAP "33332321"
	BITMAP "22332121"
	BITMAP "03232021"
	BITMAP "10232321"

	BITMAP "12323201"
	BITMAP "12123230"
	BITMAP "12023322"
	BITMAP "12323333"
	BITMAP "12332222"
	BITMAP "12333131"
	BITMAP "01222222"
	BITMAP "00111111"

	BITMAP "10232321"
	BITMAP "03232121"
	BITMAP "22332021"
	BITMAP "33332321"
	BITMAP "22223321"
	BITMAP "31313321"
	BITMAP "22222210"
	BITMAP "11111100"

	BITMAP "00111111"
	BITMAP "01221012"
	BITMAP "12333011"
	BITMAP "12302120"
	BITMAP "12301100"
	BITMAP "12120012"
	BITMAP "12001211"
	BITMAP "12301101"

	BITMAP "11111100"
	BITMAP "22222210"
	BITMAP "30313321"
	BITMAP "10223321"
	BITMAP "30032321"
	BITMAP "11102121"
	BITMAP "01210021"
	BITMAP "11010321"

	BITMAP "12320111"
	BITMAP "12120010"
	BITMAP "12020112"
	BITMAP "12320111"
	BITMAP "12311002"
	BITMAP "12301031"
	BITMAP "01222211"
	BITMAP "00111111"

	BITMAP "10211121"
	BITMAP "11230111"
	BITMAP "02310011"
	BITMAP "13102321"
	BITMAP "11023321"
	BITMAP "10313321"
	BITMAP "22222210"
	BITMAP "11111100"

	BITMAP "01000000"
	BITMAP "10000011"
	BITMAP "01000132"
	BITMAP "00111222"
	BITMAP "01002323"
	BITMAP "10000011"
	BITMAP "00000100"
	BITMAP "00111000"

	BITMAP "10010000"
	BITMAP "10010111"
	BITMAP "31011000"
	BITMAP "33100100"
	BITMAP "33300100"
	BITMAP "11000011"
	BITMAP "00100010"
	BITMAP "00010010"

	BITMAP "11001003"
	BITMAP "00001223"
	BITMAP "00003232"
	BITMAP "00022233"
	BITMAP "11232333"
	BITMAP "00110001"
	BITMAP "00100000"
	BITMAP "01000000"

	BITMAP "30010011"
	BITMAP "33011100"
	BITMAP "33310000"
	BITMAP "32301000"
	BITMAP "33330111"
	BITMAP "00001000"
	BITMAP "10010000"
	BITMAP "10010000"

	BITMAP "01000000"
	BITMAP "10000011"
	BITMAP "01000100"
	BITMAP "00111000"
	BITMAP "01000103"
	BITMAP "10000033"
	BITMAP "00000133"
	BITMAP "00111032"

	BITMAP "10010000"
	BITMAP "10010111"
	BITMAP "01011000"
	BITMAP "00100100"
	BITMAP "30100100"
	BITMAP "23300011"
	BITMAP "33330010"
	BITMAP "33233010"

	BITMAP "11001332"
	BITMAP "00001311"
	BITMAP "00003323"
	BITMAP "00033122"
	BITMAP "11031211"
	BITMAP "00332221"
	BITMAP "00322323"
	BITMAP "03322233"

	BITMAP "23313311"
	BITMAP "23311133"
	BITMAP "11313323"
	BITMAP "32131332"
	BITMAP "11332311"
	BITMAP "33333222"
	BITMAP "13232232"
	BITMAP "13332222"

	BITMAP "01000000"
	BITMAP "10000011"
	BITMAP "01000100"
	BITMAP "00113300"
	BITMAP "01033330"
	BITMAP "10033233"
	BITMAP "00323123"
	BITMAP "03311333"

	BITMAP "33221332"
	BITMAP "32221113"
	BITMAP "22231333"
	BITMAP "23222123"
	BITMAP "11221311"
	BITMAP "23113331"
	BITMAP "22133233"
	BITMAP "21333333"

	BITMAP "00010011"
	BITMAP "30011100"
	BITMAP "21010000"
	BITMAP "30101000"
	BITMAP "31000111"
	BITMAP "30001000"
	BITMAP "33010000"
	BITMAP "13010000"

	BITMAP "01000000"
	BITMAP "10000011"
	BITMAP "01000100"
	BITMAP "00111000"
	BITMAP "01000100"
	BITMAP "10000011"
	BITMAP "00000100"
	BITMAP "00111002"

	BITMAP "10010000"
	BITMAP "10010111"
	BITMAP "01011000"
	BITMAP "00100100"
	BITMAP "00100100"
	BITMAP "11000011"
	BITMAP "32220010"
	BITMAP "23233010"

	BITMAP "11001032"
	BITMAP "00001221"
	BITMAP "00002322"
	BITMAP "00022132"
	BITMAP "11021211"
	BITMAP "00232223"
	BITMAP "01111111"
	BITMAP "01000000"

	BITMAP "22212311"
	BITMAP "22311330"
	BITMAP "11313323"
	BITMAP "23131333"
	BITMAP "11233113"
	BITMAP "23332332"
	BITMAP "11111123"
	BITMAP "10010322"

	BITMAP "01000000"
	BITMAP "10000011"
	BITMAP "01000100"
	BITMAP "00111000"
	BITMAP "01000100"
	BITMAP "10000011"
	BITMAP "00000100"
	BITMAP "00122230"

	BITMAP "11221223"
	BITMAP "00221113"
	BITMAP "02321332"
	BITMAP "22222133"
	BITMAP "21221211"
	BITMAP "22112331"
	BITMAP "22123233"
	BITMAP "21233332"

	BITMAP "00010011"
	BITMAP "30011100"
	BITMAP "33010022"
	BITMAP "32301223"
	BITMAP "11332211"
	BITMAP "33323222"
	BITMAP "13222223"
	BITMAP "13212233"

	BITMAP "11001000"
	BITMAP "00001111"
	BITMAP "00001000"
	BITMAP "23300100"
	BITMAP "11331011"
	BITMAP "33133001"
	BITMAP "33133000"
	BITMAP "31323000"

	BITMAP "10010000"
	BITMAP "10010113"
	BITMAP "01011003"
	BITMAP "00100133"
	BITMAP "00100132"
	BITMAP "11000331"
	BITMAP "00103312"
	BITMAP "00033212"

	BITMAP "11001000"
	BITMAP "00001133"
	BITMAP "00001333"
	BITMAP "00000100"
	BITMAP "11001011"
	BITMAP "00110001"
	BITMAP "00100000"
	BITMAP "01000000"

	BITMAP "03312311"
	BITMAP "33211122"
	BITMAP "33333333"
	BITMAP "00333323"
	BITMAP "11003333"
	BITMAP "00001000"
	BITMAP "10010000"
	BITMAP "10010000"

	BITMAP "33232333"
	BITMAP "32223311"
	BITMAP "21233123"
	BITMAP "22111333"
	BITMAP "21233122"
	BITMAP "12322211"
	BITMAP "32222123"
	BITMAP "22111232"

	BITMAP "13332322"
	BITMAP "33312111"
	BITMAP "33211222"
	BITMAP "32122132"
	BITMAP "22122122"
	BITMAP "11232211"
	BITMAP "22122212"
	BITMAP "22212313"

	BITMAP "11221222"
	BITMAP "22321111"
	BITMAP "33333332"
	BITMAP "33330103"
	BITMAP "11001011"
	BITMAP "00110001"
	BITMAP "00100000"
	BITMAP "01000000"

	BITMAP "23212211"
	BITMAP "22211133"
	BITMAP "31213323"
	BITMAP "33131333"
	BITMAP "13333111"
	BITMAP "00331333"
	BITMAP "10033332"
	BITMAP "10010033"

	BITMAP "21333333"
	BITMAP "13323311"
	BITMAP "21333133"
	BITMAP "22111332"
	BITMAP "31333133"
	BITMAP "13233311"
	BITMAP "33332123"
	BITMAP "33111333"

	BITMAP "13310000"
	BITMAP "12333111"
	BITMAP "33333300"
	BITMAP "32323300"
	BITMAP "33333300"
	BITMAP "13332331"
	BITMAP "33233330"
	BITMAP "33333330"

	BITMAP "11321332"
	BITMAP "33331111"
	BITMAP "33231323"
	BITMAP "23333133"
	BITMAP "11331311"
	BITMAP "33113331"
	BITMAP "33132333"
	BITMAP "33333300"

	BITMAP "33230011"
	BITMAP "33331100"
	BITMAP "11330000"
	BITMAP "33133000"
	BITMAP "11332311"
	BITMAP "33333300"
	BITMAP "33010000"
	BITMAP "10010000"

	BITMAP "10012222"
	BITMAP "10013111"
	BITMAP "01022322"
	BITMAP "00232222"
	BITMAP "11111111"
	BITMAP "11000011"
	BITMAP "00100010"
	BITMAP "00010010"

	BITMAP "11001000"
	BITMAP "00001111"
	BITMAP "00001000"
	BITMAP "00000102"
	BITMAP "11001022"
	BITMAP "00110223"
	BITMAP "00101111"
	BITMAP "01000000"

	BITMAP "00010012"
	BITMAP "00022222"
	BITMAP "12223232"
	BITMAP "32121222"
	BITMAP "11232111"
	BITMAP "22222222"
	BITMAP "11111112"
	BITMAP "10010011"

	BITMAP "31232333"
	BITMAP "12233312"
	BITMAP "21223132"
	BITMAP "32223332"
	BITMAP "11111122"
	BITMAP "10000232"
	BITMAP "00222122"
	BITMAP "02211222"

	BITMAP "22213333"
	BITMAP "32213111"
	BITMAP "21211333"
	BITMAP "32132133"
	BITMAP "22133133"
	BITMAP "11333311"
	BITMAP "22123313"
	BITMAP "23313313"

	BITMAP "32221323"
	BITMAP "22321111"
	BITMAP "32221222"
	BITMAP "23232133"
	BITMAP "11221311"
	BITMAP "32113333"
	BITMAP "23333333"
	BITMAP "11111111"

	BITMAP "33313211"
	BITMAP "32311133"
	BITMAP "11313332"
	BITMAP "33131333"
	BITMAP "11333233"
	BITMAP "33311111"
	BITMAP "11110000"
	BITMAP "10010000"

	BITMAP "31333000"
	BITMAP "13233311"
	BITMAP "21333200"
	BITMAP "33111300"
	BITMAP "31323330"
	BITMAP "13333333"
	BITMAP "32333133"
	BITMAP "33111332"

	BITMAP "10010000"
	BITMAP "10010111"
	BITMAP "01011000"
	BITMAP "00100100"
	BITMAP "00100100"
	BITMAP "11000011"
	BITMAP "30100010"
	BITMAP "33010010"

	BITMAP "11331333"
	BITMAP "33331111"
	BITMAP "33231333"
	BITMAP "33333133"
	BITMAP "31331011"
	BITMAP "33110333"
	BITMAP "13333111"
	BITMAP "11111000"

	BITMAP "32010011"
	BITMAP "33311100"
	BITMAP "11330000"
	BITMAP "33131000"
	BITMAP "11331111"
	BITMAP "33311000"
	BITMAP "11110000"
	BITMAP "10010000"

	BITMAP "01000000"
	BITMAP "10000011"
	BITMAP "01000100"
	BITMAP "00111000"
	BITMAP "01000003"
	BITMAP "10000322"
	BITMAP "00001223"
	BITMAP "00023122"

	BITMAP "10010000"
	BITMAP "00330011"
	BITMAP "03323000"
	BITMAP "33233000"
	BITMAP "13333300"
	BITMAP "21332310"
	BITMAP "21333331"
	BITMAP "23131110"

	BITMAP "10322123"
	BITMAP "00221322"
	BITMAP "03231221"
	BITMAP "33333333"
	BITMAP "11111111"
	BITMAP "00000000"
	BITMAP "00100000"
	BITMAP "01000000"

	BITMAP "21331000"
	BITMAP "12333100"
	BITMAP "33233100"
	BITMAP "33333310"
	BITMAP "11111100"
	BITMAP "00000000"
	BITMAP "10010000"
	BITMAP "10010000"

	BITMAP "10010000"
	BITMAP "10010111"
	BITMAP "01011000"
	BITMAP "00100100"
	BITMAP "00100100"
	BITMAP "12300011"
	BITMAP "22330010"
	BITMAP "23230010"

	BITMAP "11001122"
	BITMAP "00001111"
	BITMAP "00001000"
	BITMAP "00000100"
	BITMAP "11001011"
	BITMAP "00110001"
	BITMAP "00100000"
	BITMAP "01000000"

	BITMAP "33333111"
	BITMAP "11111100"
	BITMAP "11010000"
	BITMAP "00101000"
	BITMAP "11000111"
	BITMAP "00001000"
	BITMAP "10010000"
	BITMAP "10010000"

	BITMAP "11001000"
	BITMAP "00001111"
	BITMAP "00023000"
	BITMAP "00223300"
	BITMAP "12233331"
	BITMAP "01333111"
	BITMAP "00111000"
	BITMAP "01000000"


	' pares 8x16 dos digitos do placar (copia)
	CHRROM PATTERN 192

	BITMAP "00333000"
	BITMAP "03003300"
	BITMAP "33000330"
	BITMAP "33000330"
	BITMAP "33000330"
	BITMAP "03300300"
	BITMAP "00333000"
	BITMAP "00000000"

	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"

	BITMAP "00033000"
	BITMAP "00033000"
	BITMAP "00033000"
	BITMAP "00033000"
	BITMAP "00033000"
	BITMAP "00033000"
	BITMAP "03333330"
	BITMAP "00000000"

	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"

	BITMAP "03333300"
	BITMAP "33000330"
	BITMAP "00003330"
	BITMAP "00333300"
	BITMAP "03333000"
	BITMAP "33300000"
	BITMAP "33333330"
	BITMAP "00000000"

	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"

	BITMAP "03333330"
	BITMAP "00003300"
	BITMAP "00033000"
	BITMAP "00333300"
	BITMAP "00000330"
	BITMAP "33000330"
	BITMAP "03333300"
	BITMAP "00000000"

	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"

	BITMAP "00033300"
	BITMAP "00333300"
	BITMAP "03303300"
	BITMAP "33003300"
	BITMAP "33333330"
	BITMAP "00003300"
	BITMAP "00003300"
	BITMAP "00000000"

	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"

	BITMAP "33333300"
	BITMAP "33000000"
	BITMAP "33333300"
	BITMAP "00000330"
	BITMAP "00000330"
	BITMAP "33000330"
	BITMAP "03333300"
	BITMAP "00000000"

	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"

	BITMAP "00333300"
	BITMAP "03300000"
	BITMAP "33000000"
	BITMAP "33333300"
	BITMAP "33000330"
	BITMAP "33000330"
	BITMAP "03333300"
	BITMAP "00000000"

	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"

	BITMAP "33333330"
	BITMAP "33000330"
	BITMAP "00003300"
	BITMAP "00033000"
	BITMAP "00330000"
	BITMAP "00330000"
	BITMAP "00330000"
	BITMAP "00000000"

	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"

	BITMAP "03333300"
	BITMAP "33000330"
	BITMAP "33000330"
	BITMAP "03333300"
	BITMAP "33000330"
	BITMAP "33000330"
	BITMAP "03333300"
	BITMAP "00000000"

	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"

	BITMAP "03333300"
	BITMAP "33000330"
	BITMAP "33000330"
	BITMAP "03333330"
	BITMAP "00000330"
	BITMAP "00003300"
	BITMAP "03333000"
	BITMAP "00000000"

	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"


	' GAMEOVER estilizado (copia)
	CHRROM PATTERN 214

	BITMAP "03333333"
	BITMAP "33333333"
	BITMAP "33000003"
	BITMAP "33003333"
	BITMAP "33003003"
	BITMAP "33003303"
	BITMAP "33000003"
	BITMAP "03333333"

	BITMAP "33333333"
	BITMAP "33333333"
	BITMAP "30000003"
	BITMAP "30033303"
	BITMAP "30000003"
	BITMAP "30033303"
	BITMAP "30033303"
	BITMAP "33333333"

	BITMAP "33333333"
	BITMAP "33333333"
	BITMAP "30033303"
	BITMAP "30003003"
	BITMAP "30030303"
	BITMAP "30033303"
	BITMAP "30033303"
	BITMAP "33333333"

	BITMAP "33333333"
	BITMAP "33333333"
	BITMAP "30000033"
	BITMAP "30033333"
	BITMAP "30000033"
	BITMAP "30033333"
	BITMAP "30000033"
	BITMAP "33333333"

	BITMAP "33333333"
	BITMAP "33333333"
	BITMAP "30000003"
	BITMAP "30033303"
	BITMAP "30033303"
	BITMAP "30033303"
	BITMAP "30000003"
	BITMAP "33333333"

	BITMAP "33333333"
	BITMAP "33333333"
	BITMAP "30033303"
	BITMAP "30033303"
	BITMAP "30033033"
	BITMAP "33003033"
	BITMAP "33000333"
	BITMAP "33333333"

	BITMAP "33333333"
	BITMAP "33333333"
	BITMAP "30000003"
	BITMAP "30033333"
	BITMAP "30000003"
	BITMAP "30033333"
	BITMAP "30000003"
	BITMAP "33333333"

	BITMAP "33333330"
	BITMAP "33333333"
	BITMAP "30000033"
	BITMAP "30033303"
	BITMAP "30000033"
	BITMAP "30030333"
	BITMAP "30033033"
	BITMAP "33333330"


	' mini-labels BONUS/1UP (copia)
	CHRROM PATTERN 224

	BITMAP "00000030"
	BITMAP "03300303"
	BITMAP "03030000"
	BITMAP "03030030"
	BITMAP "03300303"
	BITMAP "03030303"
	BITMAP "03030303"
	BITMAP "03300030"

	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "03000303"
	BITMAP "03300303"
	BITMAP "03030303"
	BITMAP "03030303"
	BITMAP "03030030"

	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000330"
	BITMAP "03330330"
	BITMAP "03000030"
	BITMAP "00330030"
	BITMAP "00030000"
	BITMAP "03300030"

	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00033000"
	BITMAP "00033000"
	BITMAP "00003000"
	BITMAP "00003000"
	BITMAP "00003000"
	BITMAP "00033300"

	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "30303300"
	BITMAP "30303030"
	BITMAP "30303030"
	BITMAP "30303300"
	BITMAP "30303000"
	BITMAP "03003000"

	BITMAP "00330000"
	BITMAP "00333000"
	BITMAP "00333300"
	BITMAP "00333330"
	BITMAP "00333330"
	BITMAP "00333300"
	BITMAP "00333000"
	BITMAP "00330000"


	' metade SPRITE: copia integral da pagina 0 (nave/inimigos/tiros/HUD)
	CHRROM PATTERN 256

	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"

	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000021"
	BITMAP "00000100"
	BITMAP "00000201"
	BITMAP "00000001"

	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "21200000"
	BITMAP "32121210"
	BITMAP "31212121"
	BITMAP "30000012"

	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00030000"
	BITMAP "00130000"
	BITMAP "00130000"
	BITMAP "01130000"

	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "10003300"
	BITMAP "11033330"
	BITMAP "13122221"
	BITMAP "11122221"
	BITMAP "13122221"

	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000033"
	BITMAP "00000333"
	BITMAP "10003333"
	BITMAP "10003133"
	BITMAP "30000112"
	BITMAP "10000132"

	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "33000000"
	BITMAP "33300000"
	BITMAP "33330001"
	BITMAP "33130001"
	BITMAP "21100003"
	BITMAP "23100001"

	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00330001"
	BITMAP "03333011"
	BITMAP "12222131"
	BITMAP "12222111"
	BITMAP "12222131"

	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00003000"
	BITMAP "00003100"
	BITMAP "00003100"
	BITMAP "00003110"

	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000212"
	BITMAP "01212123"
	BITMAP "12121213"
	BITMAP "21000003"

	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "12000000"
	BITMAP "00100000"
	BITMAP "10200000"
	BITMAP "10000000"

	BITMAP "00000021"
	BITMAP "00000011"
	BITMAP "00000022"
	BITMAP "00000211"
	BITMAP "00000212"
	BITMAP "00000000"
	BITMAP "00001222"
	BITMAP "00003133"

	BITMAP "00000000"
	BITMAP "00100000"
	BITMAP "03010000"
	BITMAP "00301000"
	BITMAP "00030110"
	BITMAP "00003312"
	BITMAP "00031222"
	BITMAP "00112222"

	BITMAP "00112222"
	BITMAP "00031222"
	BITMAP "00003312"
	BITMAP "00030110"
	BITMAP "00301000"
	BITMAP "03010000"
	BITMAP "00100000"
	BITMAP "00000000"

	BITMAP "00000000"
	BITMAP "00000100"
	BITMAP "00001030"
	BITMAP "00010300"
	BITMAP "01103000"
	BITMAP "21330000"
	BITMAP "22213000"
	BITMAP "22221100"

	BITMAP "22221100"
	BITMAP "22213000"
	BITMAP "21330000"
	BITMAP "01103000"
	BITMAP "00010300"
	BITMAP "00001030"
	BITMAP "00000100"
	BITMAP "00000000"

	BITMAP "30000000"
	BITMAP "30000111"
	BITMAP "23001122"
	BITMAP "13001000"
	BITMAP "13000122"
	BITMAP "00001322"
	BITMAP "22101122"
	BITMAP "31301000"

	BITMAP "00000000"
	BITMAP "10000000"
	BITMAP "11000000"
	BITMAP "01012101"
	BITMAP "10000001"
	BITMAP "31021011"
	BITMAP "11000011"
	BITMAP "01010111"

	BITMAP "01300000"
	BITMAP "11300000"
	BITMAP "11300000"
	BITMAP "11302121"
	BITMAP "13000000"
	BITMAP "13021212"
	BITMAP "13000000"
	BITMAP "13012121"

	BITMAP "13122221"
	BITMAP "11111111"
	BITMAP "01000001"
	BITMAP "00011100"
	BITMAP "00122210"
	BITMAP "01122211"
	BITMAP "01322231"
	BITMAP "01122211"

	BITMAP "00000000"
	BITMAP "00000001"
	BITMAP "00000012"
	BITMAP "00000112"
	BITMAP "00000232"
	BITMAP "00000121"
	BITMAP "00000111"
	BITMAP "00001122"

	BITMAP "00011221"
	BITMAP "00122311"
	BITMAP "01121121"
	BITMAP "01111133"
	BITMAP "01112121"
	BITMAP "02300213"
	BITMAP "11000000"
	BITMAP "00000000"

	BITMAP "00000000"
	BITMAP "10000000"
	BITMAP "21000000"
	BITMAP "21100000"
	BITMAP "33200000"
	BITMAP "12100000"
	BITMAP "11100000"
	BITMAP "22110000"

	BITMAP "12211000"
	BITMAP "11322100"
	BITMAP "12112110"
	BITMAP "33111110"
	BITMAP "12121110"
	BITMAP "31200320"
	BITMAP "00000011"
	BITMAP "00000000"

	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00022000"
	BITMAP "00022000"
	BITMAP "00023000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "01000010"

	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00011000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"

	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"

	BITMAP "00000000"
	BITMAP "00022000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"

	BITMAP "00000000"
	BITMAP "00000001"
	BITMAP "00000012"
	BITMAP "00000112"
	BITMAP "00000232"
	BITMAP "00000121"
	BITMAP "00000111"
	BITMAP "00001122"

	BITMAP "00011221"
	BITMAP "00122311"
	BITMAP "01121121"
	BITMAP "01111122"
	BITMAP "01112111"
	BITMAP "02300102"
	BITMAP "11000001"
	BITMAP "00000000"

	BITMAP "00000000"
	BITMAP "10000000"
	BITMAP "21000000"
	BITMAP "21100000"
	BITMAP "23200000"
	BITMAP "12100000"
	BITMAP "11100000"
	BITMAP "22110000"

	BITMAP "12211000"
	BITMAP "11322100"
	BITMAP "12112110"
	BITMAP "22111110"
	BITMAP "11121110"
	BITMAP "20100320"
	BITMAP "10000011"
	BITMAP "00000000"

	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00022000"
	BITMAP "00022000"
	BITMAP "00022000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "01000010"

	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00011000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"

	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"

	BITMAP "00000000"
	BITMAP "00022000"
	BITMAP "00000000"
	BITMAP "00222200"
	BITMAP "01211210"
	BITMAP "02022020"
	BITMAP "00022000"
	BITMAP "00000000"

	BITMAP "00000000"
	BITMAP "00000001"
	BITMAP "00000012"
	BITMAP "00000112"
	BITMAP "00000232"
	BITMAP "00000121"
	BITMAP "00000111"
	BITMAP "00001122"

	BITMAP "00011221"
	BITMAP "00122311"
	BITMAP "01121121"
	BITMAP "01111133"
	BITMAP "01112121"
	BITMAP "02300203"
	BITMAP "11000023"
	BITMAP "00000002"

	BITMAP "00000000"
	BITMAP "10000000"
	BITMAP "21000000"
	BITMAP "21100000"
	BITMAP "33200000"
	BITMAP "12100000"
	BITMAP "11100000"
	BITMAP "22110000"

	BITMAP "12211000"
	BITMAP "11322100"
	BITMAP "12112110"
	BITMAP "33111110"
	BITMAP "12121110"
	BITMAP "30200320"
	BITMAP "32000011"
	BITMAP "20000000"

	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00022000"
	BITMAP "00022000"
	BITMAP "00023000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "01000010"

	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00011000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"

	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"

	BITMAP "00000000"
	BITMAP "00022000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00200200"
	BITMAP "00022000"

	BITMAP "00000000"
	BITMAP "00000001"
	BITMAP "00000012"
	BITMAP "00000112"
	BITMAP "00000232"
	BITMAP "00000121"
	BITMAP "00000111"
	BITMAP "00001122"

	BITMAP "00011221"
	BITMAP "00122311"
	BITMAP "01121121"
	BITMAP "01111122"
	BITMAP "01112111"
	BITMAP "02300102"
	BITMAP "11000002"
	BITMAP "00000002"

	BITMAP "00000000"
	BITMAP "10000000"
	BITMAP "21000000"
	BITMAP "21100000"
	BITMAP "23200000"
	BITMAP "12100000"
	BITMAP "11100000"
	BITMAP "22110000"

	BITMAP "12211000"
	BITMAP "11322100"
	BITMAP "12112110"
	BITMAP "22111110"
	BITMAP "11121110"
	BITMAP "20100320"
	BITMAP "20000011"
	BITMAP "20000000"

	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00022000"
	BITMAP "00022000"
	BITMAP "00022000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "01000010"

	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00011000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"

	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"

	BITMAP "00000000"
	BITMAP "00022000"
	BITMAP "00000000"
	BITMAP "00222200"
	BITMAP "01211210"
	BITMAP "02022020"
	BITMAP "00022000"
	BITMAP "00022000"

	BITMAP "00000000"
	BITMAP "00000001"
	BITMAP "00000012"
	BITMAP "00000112"
	BITMAP "00000232"
	BITMAP "00000121"
	BITMAP "00000111"
	BITMAP "00001122"

	BITMAP "00011221"
	BITMAP "00122311"
	BITMAP "01121121"
	BITMAP "01111133"
	BITMAP "01112121"
	BITMAP "02300203"
	BITMAP "11000023"
	BITMAP "00000002"

	BITMAP "00000000"
	BITMAP "10000000"
	BITMAP "21000000"
	BITMAP "21100000"
	BITMAP "33200000"
	BITMAP "12100000"
	BITMAP "11100000"
	BITMAP "22110000"

	BITMAP "12211000"
	BITMAP "11322100"
	BITMAP "12112110"
	BITMAP "33111110"
	BITMAP "12121110"
	BITMAP "30200320"
	BITMAP "32000011"
	BITMAP "20000000"

	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00022000"
	BITMAP "00022000"
	BITMAP "00023000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "01000010"

	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00011000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"

	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"

	BITMAP "00000000"
	BITMAP "00022000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00200200"
	BITMAP "00022000"

	BITMAP "00000000"
	BITMAP "00000001"
	BITMAP "00000012"
	BITMAP "00000112"
	BITMAP "00000212"
	BITMAP "00000121"
	BITMAP "00000111"
	BITMAP "00011221"

	BITMAP "00122221"
	BITMAP "01122211"
	BITMAP "01112121"
	BITMAP "01111231"
	BITMAP "02301111"
	BITMAP "11000112"
	BITMAP "00000001"
	BITMAP "00000000"

	BITMAP "00000000"
	BITMAP "10000000"
	BITMAP "20000000"
	BITMAP "21000000"
	BITMAP "32100000"
	BITMAP "11100000"
	BITMAP "11100000"
	BITMAP "21100000"

	BITMAP "12210000"
	BITMAP "21121000"
	BITMAP "11321110"
	BITMAP "31113100"
	BITMAP "11111100"
	BITMAP "21101210"
	BITMAP "10000120"
	BITMAP "00000000"

	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00022000"
	BITMAP "00022000"
	BITMAP "00123000"
	BITMAP "00000000"
	BITMAP "01000000"
	BITMAP "00000110"

	BITMAP "00000000"
	BITMAP "00010100"
	BITMAP "00001000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"

	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"

	BITMAP "00000000"
	BITMAP "00002000"
	BITMAP "00000000"
	BITMAP "00020200"
	BITMAP "01211110"
	BITMAP "01122210"
	BITMAP "00022000"
	BITMAP "00000000"

	BITMAP "00000000"
	BITMAP "00000001"
	BITMAP "00000002"
	BITMAP "00000111"
	BITMAP "00000123"
	BITMAP "00000112"
	BITMAP "00001111"
	BITMAP "00122212"

	BITMAP "01122312"
	BITMAP "01211111"
	BITMAP "01131111"
	BITMAP "02312121"
	BITMAP "11000221"
	BITMAP "00000013"
	BITMAP "00000000"
	BITMAP "00000000"

	BITMAP "00000000"
	BITMAP "10000000"
	BITMAP "20000000"
	BITMAP "21000000"
	BITMAP "32100000"
	BITMAP "11100000"
	BITMAP "11000000"
	BITMAP "12100000"

	BITMAP "11100000"
	BITMAP "11110000"
	BITMAP "11211000"
	BITMAP "23212000"
	BITMAP "11111000"
	BITMAP "32121100"
	BITMAP "00001100"
	BITMAP "00000000"

	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00022000"
	BITMAP "00002000"
	BITMAP "00003000"
	BITMAP "00000000"
	BITMAP "01000000"
	BITMAP "00000000"

	BITMAP "00000000"
	BITMAP "00001010"
	BITMAP "00000100"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"

	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"

	BITMAP "00000000"
	BITMAP "00000200"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"

	BITMAP "00000000"
	BITMAP "00000001"
	BITMAP "00000001"
	BITMAP "00000111"
	BITMAP "00000121"
	BITMAP "00000112"
	BITMAP "00001111"
	BITMAP "00122212"

	BITMAP "01122312"
	BITMAP "01211111"
	BITMAP "01131111"
	BITMAP "02312121"
	BITMAP "11000221"
	BITMAP "00000013"
	BITMAP "00000000"
	BITMAP "00000000"

	BITMAP "00000000"
	BITMAP "10000000"
	BITMAP "20000000"
	BITMAP "21000000"
	BITMAP "32100000"
	BITMAP "11100000"
	BITMAP "11000000"
	BITMAP "12100000"

	BITMAP "11100000"
	BITMAP "11110000"
	BITMAP "11211000"
	BITMAP "23212000"
	BITMAP "11111000"
	BITMAP "32121100"
	BITMAP "00001100"
	BITMAP "00000000"

	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00022000"
	BITMAP "00002000"
	BITMAP "00003000"
	BITMAP "00000000"
	BITMAP "01000000"
	BITMAP "00000000"

	BITMAP "00000000"
	BITMAP "00001010"
	BITMAP "00000100"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"

	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"

	BITMAP "00000000"
	BITMAP "00000200"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"

	BITMAP "00000000"
	BITMAP "00000001"
	BITMAP "00000002"
	BITMAP "00000111"
	BITMAP "00000121"
	BITMAP "00000112"
	BITMAP "00001111"
	BITMAP "00122212"

	BITMAP "01122312"
	BITMAP "01211111"
	BITMAP "01131111"
	BITMAP "02312111"
	BITMAP "11000111"
	BITMAP "00000012"
	BITMAP "00000001"
	BITMAP "00000000"

	BITMAP "00000000"
	BITMAP "10000000"
	BITMAP "20000000"
	BITMAP "21000000"
	BITMAP "32100000"
	BITMAP "11100000"
	BITMAP "11000000"
	BITMAP "12100000"

	BITMAP "11100000"
	BITMAP "11110000"
	BITMAP "11211000"
	BITMAP "12212000"
	BITMAP "11111000"
	BITMAP "21121100"
	BITMAP "10001100"
	BITMAP "00000000"

	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00022000"
	BITMAP "00002000"
	BITMAP "00003000"
	BITMAP "00000000"
	BITMAP "01000000"
	BITMAP "00000000"

	BITMAP "00000000"
	BITMAP "00001010"
	BITMAP "00000100"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"

	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"

	BITMAP "00000000"
	BITMAP "00000200"
	BITMAP "00000000"
	BITMAP "00202200"
	BITMAP "02211110"
	BITMAP "00122200"
	BITMAP "00022000"
	BITMAP "00000000"

	BITMAP "00000000"
	BITMAP "00000001"
	BITMAP "00000001"
	BITMAP "00000111"
	BITMAP "00000121"
	BITMAP "00000112"
	BITMAP "00001111"
	BITMAP "00122212"

	BITMAP "01122312"
	BITMAP "01211111"
	BITMAP "01131111"
	BITMAP "02312121"
	BITMAP "11000221"
	BITMAP "00000013"
	BITMAP "00000023"
	BITMAP "00000002"

	BITMAP "00000000"
	BITMAP "10000000"
	BITMAP "20000000"
	BITMAP "21000000"
	BITMAP "32100000"
	BITMAP "11100000"
	BITMAP "11000000"
	BITMAP "12100000"

	BITMAP "11100000"
	BITMAP "11110000"
	BITMAP "11211000"
	BITMAP "23212000"
	BITMAP "11111000"
	BITMAP "31121100"
	BITMAP "32001100"
	BITMAP "20000000"

	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00022000"
	BITMAP "00002000"
	BITMAP "00003000"
	BITMAP "00000000"
	BITMAP "01000000"
	BITMAP "00000000"

	BITMAP "00000000"
	BITMAP "00001010"
	BITMAP "00000100"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"

	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"

	BITMAP "00000000"
	BITMAP "00000200"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000200"
	BITMAP "00200200"
	BITMAP "00022000"

	BITMAP "00000000"
	BITMAP "00000001"
	BITMAP "00000002"
	BITMAP "00000111"
	BITMAP "00000121"
	BITMAP "00000112"
	BITMAP "00001111"
	BITMAP "00122212"

	BITMAP "01122312"
	BITMAP "01211111"
	BITMAP "01131111"
	BITMAP "02312111"
	BITMAP "11000111"
	BITMAP "00000002"
	BITMAP "00000002"
	BITMAP "00000002"

	BITMAP "00000000"
	BITMAP "10000000"
	BITMAP "20000000"
	BITMAP "21000000"
	BITMAP "32100000"
	BITMAP "11100000"
	BITMAP "11000000"
	BITMAP "12100000"

	BITMAP "11100000"
	BITMAP "11110000"
	BITMAP "11211000"
	BITMAP "12212000"
	BITMAP "11111000"
	BITMAP "20121100"
	BITMAP "20001100"
	BITMAP "20000000"

	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00022000"
	BITMAP "00002000"
	BITMAP "00003000"
	BITMAP "00000000"
	BITMAP "01000000"
	BITMAP "00000000"

	BITMAP "00000000"
	BITMAP "00001010"
	BITMAP "00000100"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"

	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"

	BITMAP "00000000"
	BITMAP "00000200"
	BITMAP "00000000"
	BITMAP "00202200"
	BITMAP "02211110"
	BITMAP "00022000"
	BITMAP "00022000"
	BITMAP "00022000"

	BITMAP "00000000"
	BITMAP "00011000"
	BITMAP "00012000"
	BITMAP "02112021"
	BITMAP "02112021"
	BITMAP "02112021"
	BITMAP "02101021"
	BITMAP "02100021"

	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"

	BITMAP "00000000"
	BITMAP "00002000"
	BITMAP "02023020"
	BITMAP "03223032"
	BITMAP "03223032"
	BITMAP "03223032"
	BITMAP "03223032"
	BITMAP "02000020"

	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"

	BITMAP "00000000"
	BITMAP "00000002"
	BITMAP "00000003"
	BITMAP "00003301"
	BITMAP "00033301"
	BITMAP "00333303"
	BITMAP "00333223"
	BITMAP "00133203"

	BITMAP "00133203"
	BITMAP "00133303"
	BITMAP "00133313"
	BITMAP "00333303"
	BITMAP "00333303"
	BITMAP "00033300"
	BITMAP "00003300"
	BITMAP "00000300"

	BITMAP "00000000"
	BITMAP "22000000"
	BITMAP "33000000"
	BITMAP "33030000"
	BITMAP "33333000"
	BITMAP "30333300"
	BITMAP "11333300"
	BITMAP "10333300"

	BITMAP "33333300"
	BITMAP "33023300"
	BITMAP "13223300"
	BITMAP "13023300"
	BITMAP "00023300"
	BITMAP "00023300"
	BITMAP "00333000"
	BITMAP "00330000"

	BITMAP "00000000"
	BITMAP "00000002"
	BITMAP "00000003"
	BITMAP "00000303"
	BITMAP "00003333"
	BITMAP "00033330"
	BITMAP "00033331"
	BITMAP "00013330"

	BITMAP "00013333"
	BITMAP "00013203"
	BITMAP "00013223"
	BITMAP "00033203"
	BITMAP "00033200"
	BITMAP "00003200"
	BITMAP "00003330"
	BITMAP "00000330"

	BITMAP "00000000"
	BITMAP "22000000"
	BITMAP "33000000"
	BITMAP "33330000"
	BITMAP "33333000"
	BITMAP "30333000"
	BITMAP "11233000"
	BITMAP "10233000"

	BITMAP "33233000"
	BITMAP "33333000"
	BITMAP "13333000"
	BITMAP "13333000"
	BITMAP "00333000"
	BITMAP "00333000"
	BITMAP "00330000"
	BITMAP "00300000"

	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000003"
	BITMAP "00000003"
	BITMAP "00000003"
	BITMAP "00000033"
	BITMAP "00000031"

	BITMAP "00000031"
	BITMAP "00000031"
	BITMAP "00000031"
	BITMAP "00000031"
	BITMAP "00000033"
	BITMAP "00000003"
	BITMAP "00000003"
	BITMAP "00000000"

	BITMAP "20000000"
	BITMAP "20000000"
	BITMAP "33300000"
	BITMAP "13300000"
	BITMAP "33300000"
	BITMAP "33300000"
	BITMAP "31300000"
	BITMAP "31300000"

	BITMAP "33300000"
	BITMAP "33300000"
	BITMAP "21300000"
	BITMAP "23300000"
	BITMAP "20000000"
	BITMAP "20000000"
	BITMAP "30000000"
	BITMAP "30000000"

	BITMAP "00000000"
	BITMAP "00012000"
	BITMAP "00112100"
	BITMAP "01122110"
	BITMAP "00001222"
	BITMAP "00210111"
	BITMAP "00020110"
	BITMAP "00000100"

	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"

	BITMAP "00000000"
	BITMAP "00022000"
	BITMAP "00222100"
	BITMAP "01120210"
	BITMAP "00102022"
	BITMAP "00120211"
	BITMAP "00011110"
	BITMAP "00000100"

	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"

	BITMAP "00001000"
	BITMAP "00012000"
	BITMAP "00200200"
	BITMAP "01002020"
	BITMAP "10022002"
	BITMAP "00200021"
	BITMAP "00020210"
	BITMAP "00000100"

	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"

	BITMAP "00000000"
	BITMAP "00012000"
	BITMAP "00122200"
	BITMAP "01200220"
	BITMAP "00033022"
	BITMAP "00220211"
	BITMAP "00010230"
	BITMAP "00000100"

	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"

	BITMAP "00111100"
	BITMAP "01111110"
	BITMAP "11133111"
	BITMAP "11333311"
	BITMAP "11333311"
	BITMAP "11133111"
	BITMAP "01111110"
	BITMAP "00111100"

	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"

	BITMAP "00333300"
	BITMAP "03333330"
	BITMAP "33333333"
	BITMAP "33333333"
	BITMAP "33333333"
	BITMAP "33333333"
	BITMAP "03333330"
	BITMAP "00333300"

	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"

	BITMAP "00022000"
	BITMAP "00222022"
	BITMAP "02220222"
	BITMAP "31222212"
	BITMAP "31222212"
	BITMAP "31222112"
	BITMAP "31222112"
	BITMAP "02222122"

	BITMAP "02222221"
	BITMAP "00200221"
	BITMAP "00200221"
	BITMAP "02220023"
	BITMAP "02220002"
	BITMAP "00222002"
	BITMAP "00222000"
	BITMAP "00020000"

	BITMAP "00022000"
	BITMAP "22022200"
	BITMAP "22202220"
	BITMAP "21222213"
	BITMAP "21222213"
	BITMAP "21122213"
	BITMAP "21122213"
	BITMAP "22122220"

	BITMAP "12222220"
	BITMAP "12200200"
	BITMAP "11200200"
	BITMAP "32002220"
	BITMAP "20002220"
	BITMAP "20022200"
	BITMAP "00022200"
	BITMAP "00002000"

	BITMAP "00000000"
	BITMAP "10000000"
	BITMAP "11000000"
	BITMAP "13122221"
	BITMAP "11122221"
	BITMAP "13122221"
	BITMAP "13122221"
	BITMAP "11111111"

	BITMAP "01000001"
	BITMAP "00011100"
	BITMAP "00122210"
	BITMAP "01122211"
	BITMAP "01322231"
	BITMAP "01122211"
	BITMAP "00122210"
	BITMAP "00011100"

	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "10000000"
	BITMAP "10000100"
	BITMAP "30000112"
	BITMAP "10000132"
	BITMAP "10010112"
	BITMAP "00010131"

	BITMAP "10110110"
	BITMAP "10111000"
	BITMAP "10113011"
	BITMAP "01011010"
	BITMAP "01013031"
	BITMAP "01011011"
	BITMAP "11013010"
	BITMAP "00011012"

	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000001"
	BITMAP "00100001"
	BITMAP "21100003"
	BITMAP "23100001"
	BITMAP "21101001"
	BITMAP "13101000"

	BITMAP "01101101"
	BITMAP "00011101"
	BITMAP "11031101"
	BITMAP "01011010"
	BITMAP "13031010"
	BITMAP "11011010"
	BITMAP "01031011"
	BITMAP "21011000"

	BITMAP "00000000"
	BITMAP "00000001"
	BITMAP "00000011"
	BITMAP "12222131"
	BITMAP "12222111"
	BITMAP "12222131"
	BITMAP "12222131"
	BITMAP "11111111"

	BITMAP "10000010"
	BITMAP "00111000"
	BITMAP "01222100"
	BITMAP "11222110"
	BITMAP "13222310"
	BITMAP "11222110"
	BITMAP "01222100"
	BITMAP "00111000"

	BITMAP "00133310"
	BITMAP "00133310"
	BITMAP "00011100"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000001"
	BITMAP "00000011"

	BITMAP "00000011"
	BITMAP "00000012"
	BITMAP "00000012"
	BITMAP "00000012"
	BITMAP "00000012"
	BITMAP "00000113"
	BITMAP "00000133"
	BITMAP "00000011"

	BITMAP "11001112"
	BITMAP "31100111"
	BITMAP "13110021"
	BITMAP "11311012"
	BITMAP "01131021"
	BITMAP "11113013"
	BITMAP "11011032"
	BITMAP "11000012"

	BITMAP "21100113"
	BITMAP "32101132"
	BITMAP "22101012"
	BITMAP "32100023"
	BITMAP "22100031"
	BITMAP "33110010"
	BITMAP "33310000"
	BITMAP "11100000"

	BITMAP "21110011"
	BITMAP "11100113"
	BITMAP "12001131"
	BITMAP "21011311"
	BITMAP "12013110"
	BITMAP "31031111"
	BITMAP "23011011"
	BITMAP "21000011"

	BITMAP "31100112"
	BITMAP "23110123"
	BITMAP "21010122"
	BITMAP "32000123"
	BITMAP "13000122"
	BITMAP "01001133"
	BITMAP "00001333"
	BITMAP "00000111"

	BITMAP "01333100"
	BITMAP "01333100"
	BITMAP "00111000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "10000000"
	BITMAP "11000000"

	BITMAP "11000000"
	BITMAP "21000000"
	BITMAP "21000000"
	BITMAP "21000000"
	BITMAP "21000000"
	BITMAP "31100000"
	BITMAP "33100000"
	BITMAP "11000000"

	BITMAP "00000000"
	BITMAP "10003300"
	BITMAP "11033330"
	BITMAP "13122221"
	BITMAP "11122221"
	BITMAP "13122221"
	BITMAP "13122221"
	BITMAP "11111111"

	BITMAP "01000001"
	BITMAP "00011100"
	BITMAP "00122210"
	BITMAP "01122211"
	BITMAP "01322231"
	BITMAP "01122211"
	BITMAP "00122210"
	BITMAP "00011100"

	BITMAP "00000033"
	BITMAP "00000333"
	BITMAP "10003333"
	BITMAP "10003133"
	BITMAP "30000112"
	BITMAP "10000132"
	BITMAP "10010112"
	BITMAP "00010131"

	BITMAP "10110110"
	BITMAP "10111000"
	BITMAP "10113011"
	BITMAP "01011010"
	BITMAP "01013031"
	BITMAP "01011011"
	BITMAP "11013010"
	BITMAP "00011012"

	BITMAP "33000000"
	BITMAP "33300000"
	BITMAP "33330001"
	BITMAP "33130001"
	BITMAP "21100003"
	BITMAP "23100001"
	BITMAP "21101001"
	BITMAP "13101000"

	BITMAP "01101101"
	BITMAP "00011101"
	BITMAP "11031101"
	BITMAP "01011010"
	BITMAP "13031010"
	BITMAP "11011010"
	BITMAP "01031011"
	BITMAP "21011000"

	BITMAP "00000000"
	BITMAP "00330001"
	BITMAP "03333011"
	BITMAP "12222131"
	BITMAP "12222111"
	BITMAP "12222131"
	BITMAP "12222131"
	BITMAP "11111111"

	BITMAP "10000010"
	BITMAP "00111000"
	BITMAP "01222100"
	BITMAP "11222110"
	BITMAP "13222310"
	BITMAP "11222110"
	BITMAP "01222100"
	BITMAP "00111000"

	BITMAP "00133310"
	BITMAP "00133310"
	BITMAP "00011100"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000001"
	BITMAP "00000011"

	BITMAP "00000011"
	BITMAP "00000012"
	BITMAP "00000012"
	BITMAP "00000012"
	BITMAP "00000012"
	BITMAP "00000113"
	BITMAP "00000133"
	BITMAP "00000011"

	BITMAP "11001112"
	BITMAP "31100111"
	BITMAP "13110021"
	BITMAP "11311012"
	BITMAP "01131021"
	BITMAP "11113013"
	BITMAP "11011032"
	BITMAP "11000012"

	BITMAP "21100113"
	BITMAP "32101132"
	BITMAP "22101012"
	BITMAP "32100023"
	BITMAP "22100031"
	BITMAP "33110010"
	BITMAP "33310000"
	BITMAP "11100000"

	BITMAP "21110011"
	BITMAP "11100113"
	BITMAP "12001131"
	BITMAP "21011311"
	BITMAP "12013110"
	BITMAP "31031111"
	BITMAP "23011011"
	BITMAP "21000011"

	BITMAP "31100112"
	BITMAP "23110123"
	BITMAP "21010122"
	BITMAP "32000123"
	BITMAP "13000122"
	BITMAP "01001133"
	BITMAP "00001333"
	BITMAP "00000111"

	BITMAP "01333100"
	BITMAP "01333100"
	BITMAP "00111000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "10000000"
	BITMAP "11000000"

	BITMAP "11000000"
	BITMAP "21000000"
	BITMAP "21000000"
	BITMAP "21000000"
	BITMAP "21000000"
	BITMAP "31100000"
	BITMAP "33100000"
	BITMAP "11000000"

	BITMAP "00223200"
	BITMAP "00032000"
	BITMAP "00223200"
	BITMAP "00032000"
	BITMAP "00223200"
	BITMAP "00032000"
	BITMAP "00223200"
	BITMAP "00032000"

	BITMAP "00223200"
	BITMAP "00032000"
	BITMAP "00223200"
	BITMAP "00032000"
	BITMAP "00223200"
	BITMAP "00032000"
	BITMAP "00223200"
	BITMAP "00032000"

	BITMAP "00223200"
	BITMAP "00032000"
	BITMAP "00223200"
	BITMAP "00032000"
	BITMAP "00223200"
	BITMAP "00032000"
	BITMAP "00223200"
	BITMAP "00032000"

	BITMAP "00223200"
	BITMAP "00032000"
	BITMAP "00223200"
	BITMAP "00032000"
	BITMAP "00223200"
	BITMAP "00032000"
	BITMAP "00223200"
	BITMAP "00032000"

	BITMAP "00233200"
	BITMAP "00233200"
	BITMAP "00233200"
	BITMAP "00233200"
	BITMAP "00233200"
	BITMAP "00233200"
	BITMAP "00233200"
	BITMAP "00233200"

	BITMAP "00233200"
	BITMAP "00233200"
	BITMAP "00233200"
	BITMAP "00233200"
	BITMAP "00233200"
	BITMAP "00233200"
	BITMAP "00233200"
	BITMAP "00233200"

	BITMAP "00233200"
	BITMAP "00233200"
	BITMAP "00233200"
	BITMAP "00233200"
	BITMAP "00233200"
	BITMAP "00233200"
	BITMAP "00233200"
	BITMAP "00233200"

	BITMAP "00233200"
	BITMAP "00233200"
	BITMAP "00233200"
	BITMAP "00233200"
	BITMAP "00233200"
	BITMAP "00233200"
	BITMAP "00233200"
	BITMAP "00233200"

	BITMAP "10010112"
	BITMAP "00010131"
	BITMAP "10110110"
	BITMAP "10131000"
	BITMAP "10111011"
	BITMAP "01010112"
	BITMAP "03001123"
	BITMAP "01011233"

	BITMAP "21101001"
	BITMAP "13101000"
	BITMAP "01101101"
	BITMAP "00013101"
	BITMAP "11011101"
	BITMAP "21101010"
	BITMAP "32110030"
	BITMAP "33211010"

	BITMAP "12222131"
	BITMAP "11111111"
	BITMAP "10000010"
	BITMAP "00111000"
	BITMAP "01222100"
	BITMAP "11222110"
	BITMAP "13222310"
	BITMAP "11222110"

	BITMAP "00000310"
	BITMAP "00000311"
	BITMAP "00000311"
	BITMAP "12120311"
	BITMAP "00000031"
	BITMAP "21212031"
	BITMAP "00000031"
	BITMAP "12121031"

	BITMAP "00000000"
	BITMAP "00000001"
	BITMAP "00000011"
	BITMAP "10121010"
	BITMAP "10000001"
	BITMAP "11012013"
	BITMAP "11000011"
	BITMAP "11101010"

	BITMAP "00000003"
	BITMAP "11100003"
	BITMAP "22110032"
	BITMAP "00010031"
	BITMAP "22100031"
	BITMAP "22310000"
	BITMAP "22110122"
	BITMAP "00010313"

	BITMAP "12000000"
	BITMAP "11000000"
	BITMAP "22000000"
	BITMAP "11200000"
	BITMAP "21200000"
	BITMAP "00000000"
	BITMAP "22210000"
	BITMAP "33130000"

	BITMAP "00000000"
	BITMAP "00001222"
	BITMAP "00001111"
	BITMAP "00001212"
	BITMAP "00011111"
	BITMAP "00011112"
	BITMAP "00011121"
	BITMAP "00000000"

	BITMAP "00000122"
	BITMAP "23001322"
	BITMAP "13001122"
	BITMAP "13001322"
	BITMAP "13001122"
	BITMAP "23000111"
	BITMAP "13000000"
	BITMAP "03000000"

	BITMAP "10000101"
	BITMAP "31001111"
	BITMAP "11001111"
	BITMAP "31011011"
	BITMAP "11011113"
	BITMAP "10001113"
	BITMAP "00020000"
	BITMAP "01112223"

	BITMAP "30000000"
	BITMAP "31000330"
	BITMAP "31103333"
	BITMAP "31312222"
	BITMAP "01112222"
	BITMAP "01312222"
	BITMAP "01312222"
	BITMAP "01111111"

	BITMAP "00122210"
	BITMAP "00011100"
	BITMAP "01133310"
	BITMAP "11133310"
	BITMAP "13011100"
	BITMAP "11000000"
	BITMAP "11011110"
	BITMAP "10012100"

	BITMAP "13011233"
	BITMAP "00011123"
	BITMAP "11001112"
	BITMAP "31100111"
	BITMAP "13110021"
	BITMAP "11311012"
	BITMAP "01131021"
	BITMAP "11113013"

	BITMAP "33211031"
	BITMAP "32111000"
	BITMAP "21110011"
	BITMAP "11100113"
	BITMAP "12001131"
	BITMAP "21011311"
	BITMAP "12013110"
	BITMAP "31031111"

	BITMAP "01222100"
	BITMAP "00111000"
	BITMAP "01333110"
	BITMAP "01333111"
	BITMAP "00111031"
	BITMAP "00000011"
	BITMAP "01111011"
	BITMAP "00121001"

	BITMAP "00000003"
	BITMAP "03300013"
	BITMAP "33330113"
	BITMAP "22221313"
	BITMAP "22221110"
	BITMAP "22221310"
	BITMAP "22221310"
	BITMAP "11111110"

	BITMAP "10100001"
	BITMAP "11110013"
	BITMAP "11110011"
	BITMAP "11011013"
	BITMAP "31111011"
	BITMAP "31110001"
	BITMAP "00002000"
	BITMAP "32221110"

	BITMAP "22100000"
	BITMAP "22310032"
	BITMAP "22110031"
	BITMAP "22310031"
	BITMAP "22110031"
	BITMAP "11100032"
	BITMAP "00000031"
	BITMAP "00000030"

	BITMAP "00000000"
	BITMAP "22210000"
	BITMAP "11110000"
	BITMAP "21210000"
	BITMAP "11111000"
	BITMAP "21111000"
	BITMAP "12111000"
	BITMAP "00000000"

	BITMAP "00011012"
	BITMAP "00113011"
	BITMAP "00213011"
	BITMAP "00113011"
	BITMAP "00213011"
	BITMAP "00111011"
	BITMAP "01110111"
	BITMAP "01101112"

	BITMAP "13000000"
	BITMAP "11300000"
	BITMAP "11300000"
	BITMAP "21300002"
	BITMAP "11300001"
	BITMAP "11300011"
	BITMAP "22300012"
	BITMAP "11300211"

	BITMAP "01211113"
	BITMAP "11212113"
	BITMAP "11112111"
	BITMAP "01111111"
	BITMAP "20111101"
	BITMAP "12011111"
	BITMAP "11200000"
	BITMAP "11122222"

	BITMAP "00100000"
	BITMAP "00001110"
	BITMAP "30012221"
	BITMAP "30112221"
	BITMAP "30132223"
	BITMAP "30112221"
	BITMAP "00012221"
	BITMAP "30001110"

	BITMAP "11011001"
	BITMAP "01022011"
	BITMAP "01011011"
	BITMAP "10022012"
	BITMAP "10111012"
	BITMAP "10121012"
	BITMAP "00110012"
	BITMAP "01110113"

	BITMAP "11011032"
	BITMAP "11000012"
	BITMAP "21100113"
	BITMAP "32101132"
	BITMAP "22101012"
	BITMAP "32100023"
	BITMAP "22100031"
	BITMAP "33110012"

	BITMAP "23011011"
	BITMAP "21000011"
	BITMAP "31100112"
	BITMAP "23110123"
	BITMAP "21010122"
	BITMAP "32000123"
	BITMAP "13000122"
	BITMAP "21001133"

	BITMAP "10011011"
	BITMAP "11022010"
	BITMAP "11011010"
	BITMAP "21022001"
	BITMAP "21011101"
	BITMAP "21012101"
	BITMAP "21001100"
	BITMAP "31101110"

	BITMAP "00000100"
	BITMAP "01110000"
	BITMAP "12221003"
	BITMAP "12221103"
	BITMAP "32223103"
	BITMAP "12221103"
	BITMAP "12221000"
	BITMAP "01110003"

	BITMAP "31111210"
	BITMAP "31121211"
	BITMAP "11121111"
	BITMAP "11111110"
	BITMAP "10111102"
	BITMAP "11111021"
	BITMAP "00000211"
	BITMAP "22222111"

	BITMAP "00000031"
	BITMAP "00000311"
	BITMAP "00000311"
	BITMAP "20000312"
	BITMAP "10000311"
	BITMAP "11000311"
	BITMAP "21000322"
	BITMAP "11200311"

	BITMAP "21011000"
	BITMAP "11031100"
	BITMAP "11031200"
	BITMAP "11031100"
	BITMAP "11031200"
	BITMAP "11011100"
	BITMAP "11101110"
	BITMAP "21110110"

	BITMAP "01011211"
	BITMAP "00112111"
	BITMAP "00111121"
	BITMAP "00011211"
	BITMAP "00000000"
	BITMAP "00011111"
	BITMAP "00111112"
	BITMAP "01211123"

	BITMAP "11300121"
	BITMAP "21300112"
	BITMAP "11300111"
	BITMAP "21000011"
	BITMAP "00000001"
	BITMAP "11300000"
	BITMAP "11130000"
	BITMAP "21130000"

	BITMAP "12111211"
	BITMAP "11111211"
	BITMAP "21121211"
	BITMAP "12111211"
	BITMAP "11211211"
	BITMAP "11121211"
	BITMAP "01112211"
	BITMAP "00110211"

	BITMAP "30013331"
	BITMAP "30013331"
	BITMAP "13001110"
	BITMAP "13000000"
	BITMAP "11300000"
	BITMAP "21300000"
	BITMAP "11300000"
	BITMAP "21130000"

	BITMAP "02200133"
	BITMAP "01100011"
	BITMAP "02220000"
	BITMAP "01212000"
	BITMAP "00321200"
	BITMAP "00012120"
	BITMAP "00003212"
	BITMAP "00000121"

	BITMAP "00000000"
	BITMAP "00022000"
	BITMAP "00222200"
	BITMAP "00222200"
	BITMAP "00222200"
	BITMAP "00222200"
	BITMAP "00022000"
	BITMAP "00000000"

	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"

	BITMAP "00000000"
	BITMAP "00033000"
	BITMAP "00233200"
	BITMAP "00233200"
	BITMAP "00233200"
	BITMAP "00233200"
	BITMAP "00033000"
	BITMAP "00000000"

	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"

	BITMAP "33310003"
	BITMAP "11100012"
	BITMAP "00000001"
	BITMAP "00000012"
	BITMAP "00000003"
	BITMAP "00000012"
	BITMAP "00000001"
	BITMAP "20000012"

	BITMAP "30001333"
	BITMAP "21000111"
	BITMAP "10000000"
	BITMAP "21000000"
	BITMAP "30000000"
	BITMAP "21000000"
	BITMAP "10000000"
	BITMAP "21000002"

	BITMAP "33100220"
	BITMAP "11000110"
	BITMAP "00002220"
	BITMAP "00021210"
	BITMAP "00212300"
	BITMAP "02121000"
	BITMAP "21230000"
	BITMAP "12100000"

	BITMAP "13331003"
	BITMAP "13331003"
	BITMAP "01110031"
	BITMAP "00000031"
	BITMAP "00000311"
	BITMAP "00000312"
	BITMAP "00000311"
	BITMAP "00003112"

	BITMAP "11211121"
	BITMAP "11211111"
	BITMAP "11212112"
	BITMAP "11211121"
	BITMAP "11211211"
	BITMAP "11212111"
	BITMAP "11221110"
	BITMAP "11201100"

	BITMAP "12100311"
	BITMAP "21100312"
	BITMAP "11100311"
	BITMAP "11000012"
	BITMAP "10000000"
	BITMAP "00000311"
	BITMAP "00003111"
	BITMAP "00003112"

	BITMAP "11211010"
	BITMAP "11121100"
	BITMAP "12111100"
	BITMAP "11211000"
	BITMAP "00000000"
	BITMAP "11111000"
	BITMAP "21111100"
	BITMAP "32111210"

	BITMAP "01121123"
	BITMAP "01112112"
	BITMAP "01111211"
	BITMAP "00111121"
	BITMAP "00031112"
	BITMAP "00003111"
	BITMAP "00000111"
	BITMAP "00000011"

	BITMAP "21113000"
	BITMAP "11113000"
	BITMAP "11111300"
	BITMAP "11211300"
	BITMAP "11111130"
	BITMAP "21111130"
	BITMAP "12112113"
	BITMAP "12111113"

	BITMAP "00000021"
	BITMAP "00000112"
	BITMAP "00000111"
	BITMAP "00000011"
	BITMAP "00000001"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"

	BITMAP "11130000"
	BITMAP "11113000"
	BITMAP "21113000"
	BITMAP "12113000"
	BITMAP "11211300"
	BITMAP "11121300"
	BITMAP "01112300"
	BITMAP "00111130"

	BITMAP "00000032"
	BITMAP "00000031"
	BITMAP "00000033"
	BITMAP "00000033"
	BITMAP "00000033"
	BITMAP "00000033"
	BITMAP "00000003"
	BITMAP "00000003"

	BITMAP "10000003"
	BITMAP "21000000"
	BITMAP "12000000"
	BITMAP "21000000"
	BITMAP "12000000"
	BITMAP "21000000"
	BITMAP "31000000"
	BITMAP "33000000"

	BITMAP "30000001"
	BITMAP "00000012"
	BITMAP "00000021"
	BITMAP "00000012"
	BITMAP "00000021"
	BITMAP "00000012"
	BITMAP "00000013"
	BITMAP "00000033"

	BITMAP "23000000"
	BITMAP "13000000"
	BITMAP "33000000"
	BITMAP "33000000"
	BITMAP "33000000"
	BITMAP "33000000"
	BITMAP "30000000"
	BITMAP "30000000"

	BITMAP "00003111"
	BITMAP "00031111"
	BITMAP "00031112"
	BITMAP "00031121"
	BITMAP "00311211"
	BITMAP "00312111"
	BITMAP "00321110"
	BITMAP "03111100"

	BITMAP "12000000"
	BITMAP "21100000"
	BITMAP "11100000"
	BITMAP "11000000"
	BITMAP "10000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"

	BITMAP "00031112"
	BITMAP "00031111"
	BITMAP "00311111"
	BITMAP "00311211"
	BITMAP "03111111"
	BITMAP "03111112"
	BITMAP "31121121"
	BITMAP "31111121"

	BITMAP "32112110"
	BITMAP "21121110"
	BITMAP "11211110"
	BITMAP "12111100"
	BITMAP "21113000"
	BITMAP "11130000"
	BITMAP "11100000"
	BITMAP "11000000"

	BITMAP "00000003"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"

	BITMAP "11211111"
	BITMAP "31121121"
	BITMAP "01112111"
	BITMAP "00111211"
	BITMAP "00031121"
	BITMAP "00003112"
	BITMAP "00000111"
	BITMAP "00000012"

	BITMAP "30000000"
	BITMAP "30000000"
	BITMAP "13000000"
	BITMAP "13000000"
	BITMAP "11300000"
	BITMAP "12300000"
	BITMAP "21130000"
	BITMAP "11130000"

	BITMAP "00011130"
	BITMAP "00001113"
	BITMAP "00000113"
	BITMAP "00000011"
	BITMAP "00000001"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"

	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "30000000"
	BITMAP "30000000"
	BITMAP "13000000"
	BITMAP "03000000"
	BITMAP "00000000"

	BITMAP "33000000"
	BITMAP "03000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"

	BITMAP "00000033"
	BITMAP "00000030"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"

	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000003"
	BITMAP "00000003"
	BITMAP "00000031"
	BITMAP "00000030"
	BITMAP "00000000"

	BITMAP "03111000"
	BITMAP "31110000"
	BITMAP "31100000"
	BITMAP "11000000"
	BITMAP "10000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"

	BITMAP "00000003"
	BITMAP "00000003"
	BITMAP "00000031"
	BITMAP "00000031"
	BITMAP "00000311"
	BITMAP "00000321"
	BITMAP "00003112"
	BITMAP "00003111"

	BITMAP "11111211"
	BITMAP "12112113"
	BITMAP "11121110"
	BITMAP "11211100"
	BITMAP "12113000"
	BITMAP "21130000"
	BITMAP "11100000"
	BITMAP "21000000"

	BITMAP "30000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"

	BITMAP "00000001"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"

	BITMAP "11113000"
	BITMAP "31213000"
	BITMAP "03111300"
	BITMAP "00111300"
	BITMAP "00012130"
	BITMAP "00001130"
	BITMAP "00000113"
	BITMAP "00000013"

	BITMAP "00031111"
	BITMAP "00031213"
	BITMAP "00311130"
	BITMAP "00311100"
	BITMAP "03121000"
	BITMAP "03110000"
	BITMAP "31100000"
	BITMAP "31000000"

	BITMAP "10000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"

	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"
	BITMAP "00000000"

