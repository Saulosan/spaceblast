import ctypes, os, sys
import numpy as np

core = ctypes.CDLL('/tmp/fceumm_libretro.so')
ENVF = ctypes.CFUNCTYPE(ctypes.c_bool, ctypes.c_uint, ctypes.c_void_p)
VIDF = ctypes.CFUNCTYPE(None, ctypes.c_void_p, ctypes.c_uint, ctypes.c_uint, ctypes.c_size_t)
AUDF = ctypes.CFUNCTYPE(None, ctypes.c_int16, ctypes.c_int16)
AUDB = ctypes.CFUNCTYPE(ctypes.c_size_t, ctypes.c_void_p, ctypes.c_size_t)
INPF = ctypes.CFUNCTYPE(None)
INSF = ctypes.CFUNCTYPE(ctypes.c_int16, ctypes.c_uint, ctypes.c_uint, ctypes.c_uint, ctypes.c_uint)

pcm_chunks = []
def envf(cmd, data):
    if cmd == 10: ctypes.cast(data, ctypes.POINTER(ctypes.c_int)).contents.value = 1; return True
    if cmd == 11: ctypes.cast(data, ctypes.POINTER(ctypes.c_bool)).contents.value = True; return True
    if cmd in (16,17): return True
    return False
def vidf(d,w,h,p): pass
def audf(l,r): pass
def audb(d,n):
    arr = np.ctypeslib.as_array(ctypes.cast(d, ctypes.POINTER(ctypes.c_int16)), shape=(n*2,))
    pcm_chunks.append(arr.copy())
    return n
def inpf(): pass
def insf(a,b,c,d): return 0
_cb = ENVF(envf), VIDF(vidf), AUDF(audf), AUDB(audb), INPF(inpf), INSF(insf)
class RGI(ctypes.Structure):
    _fields_ = [('path', ctypes.c_char_p), ('data', ctypes.c_void_p), ('size', ctypes.c_size_t), ('meta', ctypes.c_char_p)]
core.retro_set_environment(_cb[0]); core.retro_set_video_refresh(_cb[1])
core.retro_set_audio_sample(_cb[2]); core.retro_set_audio_sample_batch(_cb[3])
core.retro_set_input_poll(_cb[4]); core.retro_set_input_state(_cb[5])
core.retro_init()
gi = RGI(os.path.abspath(sys.argv[1]).encode(), None, 0, None)
print('load:', core.retro_load_game(ctypes.byref(gi)), flush=True)
core.retro_get_memory_data.restype = ctypes.c_void_p

warm = int(sys.argv[2]) if len(sys.argv) > 2 else 0
steps = int(sys.argv[3]) if len(sys.argv) > 3 else 200
f0 = int(sys.argv[4]) if len(sys.argv) > 4 else 0

for i in range(warm): core.retro_run()
ram = (ctypes.c_ubyte * 2048).from_address(core.retro_get_memory_data(2))

NN = ['C','C#','D','D#','E','F','F#','G','G#','A','A#','B']
def nname(nb):
    if nb == 0: return '---'
    n = nb & 0x3f
    if n == 0x3f: return 'SUS'
    return NN[(n-1)%12] + str((n-1)//12 + 2)

total_samples = 0
for f in range(steps):
    c0 = sum(len(c) for c in pcm_chunks)
    core.retro_run()
    c1 = sum(len(c) for c in pcm_chunks)
    # rms do audio deste frame
    if c1 > c0:
        flat = np.concatenate(pcm_chunks)[c0:c1:2].astype(np.float32)
        rms = float(np.sqrt((flat**2).mean()))
    else:
        rms = 0.0
    ch1n, ch2n, ch3n = ram[0x38]>>1, ram[0x3b]>>1, ram[0x3e]>>1
    line = (f'f{warm+f:4d} rms={rms:8.1f} | tim={ram[0x31]} cnt={ram[0x36]:2d} | '
            f'ch1 {ram[0x37]:02x}/{nname(ram[0x38]):>4} f={ram[0x43]:02x}{ram[0x42]:02x} v={ram[0x48]:02x} | '
            f'ch2 {ram[0x3a]:02x}/{nname(ram[0x3b]):>4} f={ram[0x45]:02x}{ram[0x44]:02x} v={ram[0x49]:02x} | '
            f'ch3 {ram[0x3d]:02x}/{nname(ram[0x3e]):>4} f={ram[0x47]:02x}{ram[0x46]:02x} v={ram[0x4a]:02x} | '
            f'drm={ram[0x40]} p={ram[0x34]:02x}{ram[0x35]:02x}')
    if warm+f >= f0: print(line, flush=True)

allp = np.concatenate(pcm_chunks) if pcm_chunks else np.zeros(1, np.int16)
import wave
w = wave.open('/tmp/diag.wav','wb'); w.setnchannels(2); w.setsampwidth(2); w.setframerate(48000)
w.writeframes(allp.astype('<i2').tobytes()); w.close()
print('wav /tmp/diag.wav', flush=True)
