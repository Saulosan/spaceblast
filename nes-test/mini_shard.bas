	' mini repro: shard dive->exit bug
	DIM sha(4)
	DIM shx(4)
	DIM #shy(4)
	DIM shf(4)
	DIM shvx(4)
	SIGNED #ad,shvx

	GOSUB silence
	CLS
	' spawn: emula onda shard
	FOR c = 0 TO 3
		sha(c) = 1
		shf(c) = 0
		#shy(c) = 7000 - c * 4	' quase no fundo, p/ testar rapido
		shx(c) = 51
	NEXT c
	shf(0) = 99 ' marca: shard 0 comeca na fase de saida? nao: usa dive normal

loop:
	WAIT
	FOR c = 0 TO 3
		IF sha(c) <> 0 THEN
			IF shf(c) = 0 THEN
				#shy(c) = #shy(c) + 32
				IF #shy(c) >= 7712 THEN
					shf(c) = 1
					shvx(c) = 2
				END IF
			ELSE
				#ad = shx(c)
				#ad = #ad + shvx(c)
				IF #ad < -16 OR #ad > 272 OR #shy(c) < 3840 THEN
					sha(c) = 0
					SPRITE 19 + c,$f0,0,0,0
				ELSE
					shx(c) = #ad
					#shy(c) = #shy(c) - 32
				END IF
			END IF
			IF sha(c) <> 0 THEN
				SPRITE 19 + c,#shy(c) / 16 - 256 - 1,shx(c),125,2
			END IF
		END IF
	NEXT c
	IF (FRAME AND 31) = 0 THEN
		PRINT AT 32 * (FRAME / 32 AND 7), "S0 A",<2>sha(0)," F",<2>shf(0)," X",<3>shx(0)," Y",<5>#shy(0)
	END IF
	GOTO loop

silence:	PROCEDURE
	SOUND 10,,$10
	SOUND 11,,$10
	SOUND 14,,$10
	END

	CHRROM 0
	CHRROM PATTERN 380
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

game_palette:
	DATA BYTE $0F,$11,$21,$30
	DATA BYTE $0F,$11,$21,$30
	DATA BYTE $0F,$11,$21,$30
	DATA BYTE $0F,$11,$21,$30
	DATA BYTE $0F,$00,$10,$30
	DATA BYTE $0F,$16,$21,$12
	DATA BYTE $0F,$19,$2A,$30
	DATA BYTE $0F,$16,$27,$30
