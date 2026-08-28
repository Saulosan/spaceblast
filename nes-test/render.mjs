// Teste de fumaça do Cata-Estrelas no jsnes (headless)
// Uso: node render.mjs
import { NES, Controller } from 'jsnes';
import fs from 'fs';

const ROM = '/home/user/cata-estrelas/cata-estrelas.nes';
const romData = fs.readFileSync(ROM).toString('binary');

let frame = null;
const nes = new NES({
  onFrame: (fb) => { frame = fb.slice(); },
  onAudioSample: () => {},
});

nes.loadROM(romData);

const P1 = 1;
let shots = 0;

function run(n, key) {
  if (key !== undefined && key !== null) nes.buttonDown(P1, key);
  for (let i = 0; i < n; i++) nes.frame();
  if (key !== undefined && key !== null) nes.buttonUp(P1, key);
}

function shot(name) {
  if (!frame) throw new Error('sem frame');
  const w = 256, h = 240;
  const out = Buffer.alloc(1 + w * h * 3);
  for (let i = 0; i < w * h; i++) {
    const px = frame[i];
    let r, g, b;
    if (typeof px === 'object' && px !== null) { r = px.r; g = px.g; b = px.b; }
    else { r = (px >> 16) & 0xff; g = (px >> 8) & 0xff; b = px & 0xff; }
    out[i * 3] = r; out[i * 3 + 1] = g; out[i * 3 + 2] = b;
  }
  fs.writeFileSync(`/home/user/nes-test/shot_${name}.raw`, out);
  console.log('shot', name);
  shots++;
}

// 1) Titulo (~3s)
run(180);
shot('1_titulo');

// 2) Aperta START e entra no jogo
run(3, Controller.BUTTON_START);
run(120);
shot('2_jogo_inicio');

// 3) Move a nave um pouco (esquerda e cima)
run(40, Controller.BUTTON_LEFT);
run(20, Controller.BUTTON_UP);
run(60);
shot('3_jogo_movendo');

// 4) Deixa rolar bastante tempo mexendo pra la e pra ca (vai colidir uma hora)
let pat = [Controller.BUTTON_LEFT, Controller.BUTTON_RIGHT, Controller.BUTTON_DOWN, Controller.BUTTON_UP];
for (let k = 0; k < 40; k++) {
  run(45, pat[k % 4]);
  if (k == 10) shot('4_jogo_metade');
}
shot('5_final');

console.log('OK, frames gerados');
