// Dump de diagnóstico: OAM, nametable, paleta
import { NES, Controller } from 'jsnes';
import fs from 'fs';

const romData = fs.readFileSync('/home/user/cata-estrelas/cata-estrelas.nes').toString('binary');
const nes = new NES({ onFrame: () => {}, onAudioSample: () => {} });
nes.loadROM(romData);

function dump(tag) {
  const p = nes.ppu;
  console.log(`\n===== ${tag} =====`);
  console.log('f_spriteSize:', p.f_spriteSize);
  console.log('OAM (idx: y tile attr x):');
  for (let i = 0; i < 16; i++) {
    const y = p.spriteMem[i*4], t = p.spriteMem[i*4+1], a = p.spriteMem[i*4+2], x = p.spriteMem[i*4+3];
    if (y !== 0xf0 || i < 12)
      console.log(` ${String(i).padStart(2)}: y=${String(y).padStart(3)} tile=${String(t).padStart(3)} (0x${t.toString(16).padStart(2,'0')}) attr=${a.toString(16).padStart(2,'0')} x=${String(x).padStart(3)}`);
  }
  const nt = p.vramMem;
  let row = '';
  for (let i = 0; i < 64; i++) row += nt[0x2000 + i].toString(16).padStart(2,'0') + ' ';
  console.log('NT $2000 rows0-1:', row);
  let pal = '';
  for (let i = 0; i < 32; i++) pal += nt[0x3f00 + i].toString(16).padStart(2,'0') + ' ';
  console.log('PAL:', pal);
}

// boot + titulo
for (let i = 0; i < 120; i++) nes.frame();
dump('TITULO');

// start
nes.buttonDown(1, Controller.BUTTON_START);
for (let i = 0; i < 3; i++) nes.frame();
nes.buttonUp(1, Controller.BUTTON_START);

for (let i = 0; i < 60; i++) nes.frame();
dump('JOGO +60f');

for (let i = 0; i < 300; i++) nes.frame();
dump('JOGO +360f');

// move esquerda
nes.buttonDown(1, Controller.BUTTON_LEFT);
for (let i = 0; i < 30; i++) nes.frame();
nes.buttonUp(1, Controller.BUTTON_LEFT);
for (let i = 0; i < 60; i++) nes.frame();
dump('JOGO +450f (moveu)');
