	'
	' TESTE DO PLAYER DE MUSICA NES (CVBasic)
	' Escala c/ instrumentos W/X/Y/Z, sustain, bateria M1/M2/M3.
	'

	PLAY FULL
	PLAY teste

loop:
	WAIT
	GOTO loop

teste:
	DATA BYTE 2
	' 1) oitavas C3..C6 em piano (W) - 8 notas x 4 ticks
	MUSIC C3W,-,-,-
	MUSIC S,-,-,-
	MUSIC S,-,-,-
	MUSIC S,-,-,-
	MUSIC C4W,-,-,-
	MUSIC S,-,-,-
	MUSIC S,-,-,-
	MUSIC S,-,-,-
	MUSIC C5W,-,-,-
	MUSIC S,-,-,-
	MUSIC S,-,-,-
	MUSIC S,-,-,-
	MUSIC C6W,-,-,-
	MUSIC S,-,-,-
	MUSIC S,-,-,-
	MUSIC S,-,-,-
	' 2) clarinete X com vibrato: C5 E5 G5 C6
	MUSIC C5X,-,-,-
	MUSIC S,-,-,-
	MUSIC S,-,-,-
	MUSIC S,-,-,-
	MUSIC E5X,-,-,-
	MUSIC S,-,-,-
	MUSIC S,-,-,-
	MUSIC S,-,-,-
	MUSIC G5X,-,-,-
	MUSIC S,-,-,-
	MUSIC S,-,-,-
	MUSIC S,-,-,-
	MUSIC C6X,-,-,-
	MUSIC S,-,-,-
	MUSIC S,-,-,-
	MUSIC S,-,-,-
	' 3) flauta Y + triangulo (oitava acima) + baixo Z
	MUSIC C5Y,C5Y,-,-
	MUSIC S,S,-,-
	MUSIC S,S,-,-
	MUSIC S,S,-,-
	MUSIC G4Y,G4Y,-,-
	MUSIC S,S,-,-
	MUSIC S,S,-,-
	MUSIC S,S,-,-
	' 4) bateria: M1 (longa), M2 (curta), M3 (rolo)
	MUSIC -,-,-,M1
	MUSIC -,-,-,-
	MUSIC -,-,-,-
	MUSIC -,-,-,-
	MUSIC -,-,-,M2
	MUSIC -,-,-,-
.MUSLOOP2:
	MUSIC -,-,-,-
	MUSIC -,-,-,-
	MUSIC -,-,-,M3
	MUSIC -,-,-,-
	MUSIC -,-,-,-
	MUSIC -,-,-,-
	' 5) baixo Z C2 (soa C1?) vs C3 - 6 ticks
	MUSIC C2Z,-,-,-
	MUSIC S,-,-,-
	MUSIC S,-,-,-
	MUSIC S,-,-,-
	MUSIC S,-,-,-
	MUSIC S,-,-,-
	MUSIC C3Z,-,-,-
	MUSIC S,-,-,-
	MUSIC S,-,-,-
	MUSIC S,-,-,-
	MUSIC S,-,-,-
	MUSIC S,-,-,-
	MUSIC REPEAT
