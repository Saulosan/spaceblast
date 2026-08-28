	'
	' PROBE: mapeamento de nametables no fceumm byte6=0
	' col 5: 'A' em $2000, col 10: 'B' em $2400, col 15: 'C' em $2800
	' (todas as 30 linhas). Scroll desce 1px/frame.
	'
	DIM i, s
	DIM #tw
	CLS
	PALETTE LOAD ppal
	SCREEN DISABLE
	FOR i = 0 TO 29
		#tw = i * 32
		VPOKE $2000 + #tw + 5, 65
		VPOKE $2400 + #tw + 10, 66
		VPOKE $2800 + #tw + 15, 67
	NEXT i
	SCREEN ENABLE
	s = 0
probe_loop:
	WAIT
	s = s + 1
	IF s = 240 THEN s = 0
	SCROLL 0, s
	GOTO probe_loop

ppal:
	DATA BYTE $0F,$11,$21,$00
	DATA BYTE $0F,$11,$21,$00
	DATA BYTE $0F,$11,$21,$00
	DATA BYTE $0F,$11,$21,$00
	DATA BYTE $0F,$11,$21,$00
	DATA BYTE $0F,$11,$21,$00
	DATA BYTE $0F,$11,$21,$00
	DATA BYTE $0F,$11,$21,$00
