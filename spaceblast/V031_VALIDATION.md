# Space Blast v0.31 — validação da ROM final

## Artefato

- ROM: `space-blast-v031.nes`
- Tamanho: `524304` bytes
- SHA-256: `de7466386263b9432e9350a924f3a39c1eec4fc33e91aa7c0a0a29e5170293d0`
- Mapper: 30, 32 bancos PRG, CHR-RAM
- Build reproduzível: `./build-v031.sh`

Uma segunda execução de `build-v031.sh` produziu o mesmo SHA-256 da ROM e do
assembly.

## Alterações verificadas

- Fonte de texto preservada com a fonte original do jogo.
- Acentos continuam em tiles separados, na linha vazia acima da letra-base.
- Os registros de história e créditos não ultrapassam as 32 colunas físicas.
- Os registros de texto têm ao menos uma linha vazia entre linhas consecutivas.
- Créditos técnicos e agradecimentos estão divididos em linhas físicas.
- Cartão da fase 03: til em `CINTURÃO` e agudo em `ASTERÓIDES`.
- Cartão da fase 04 permanece em duas linhas.
- `THE END?` permanece visível antes do reset completo.

## Testes no FCEUmm

- Boot sem START: história iniciou no frame 717, após o splash e cinco segundos
  de espera no título.
- História automática: percorreu o scroll até `#bk=460`, sem tela preta na
  costura; o texto final ficou visível e o reset retornou ao splash e ao título.
- START durante a história: interrompeu a sequência e também retornou ao splash.
- Percurso de fases 1–5, cenários espaciais/lava/água e scroll verificados.
- Boss da fase 05: iniciou com HP 120 e morreu no percurso determinístico.
- Créditos iniciaram no frame 2150 e chegaram a `#bk=460` no frame 3074.
- `THE END?` ficou legível por 302 frames consecutivos no teste, incluindo a
  permanência solicitada de alguns segundos.
- Reset após o ending: estado limpo no frame 3622, splash visível no 3683 e
  título visível no 3912, com `FASE=0` e `LI=0` durante o boot reiniciado.
