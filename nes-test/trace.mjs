import { NES, Controller } from 'jsnes';
import fs from 'fs';
const romData = fs.readFileSync('/home/user/cata-estrelas/cata-estrelas.nes').toString('binary');
const nes = new NES({ onFrame: () => {}, onAudioSample: () => {} });
nes.loadROM(romData);

const mem = () => nes.cpu.mem;
for (let i = 0; i < 120; i++) nes.frame();
nes.buttonDown(1, Controller.BUTTON_START);
for (let i = 0; i < 3; i++) nes.frame();
nes.buttonUp(1, Controller.BUTTON_START);

function i16(a) { let v = mem()[a] | (mem()[a+1] << 8); return v > 32767 ? v - 65536 : v; }

console.log('frame | my0 my1 my2 my3 | ms0-3 | sy | score');
for (let f = 0; f < 200; f++) {
  nes.frame();
  if (f % 10 === 0) {
    let m = mem();
    let mys = [i16(0x60), i16(0x62), i16(0x64), i16(0x66)].map(String).join(',').padEnd(20);
    let mss = [m[0x88], m[0x89], m[0x8a], m[0x8b]].join(',');
    let sy = i16(0x5b);
    let sc = i16(0x55);
    console.log(String(f).padStart(5), '|', mys, '|', mss.padEnd(8), '|', String(sy).padStart(6), '|', sc);
  }
}
