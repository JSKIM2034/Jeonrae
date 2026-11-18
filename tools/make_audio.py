# 효과음과 배경음을 코드로 만들어요 (악기 소리도 직접 합성)
# - 발자국: 기분 좋은 기계식 키보드처럼 "도각" 하는 소리 4가지
# - 배경음: 가야금(뜯는 현) + 대금(숨 섞인 피리) + 장구, 평화로운 5음 음계, 끊김 없이 반복
import numpy as np, sys, subprocess, os
from scipy.signal import butter, sosfilt
OUT = sys.argv[1]
SR = 44100
rng = np.random.default_rng(1)

def t_(d): return np.arange(int(d * SR)) / SR
def env(n, a, d):
    t = np.arange(n) / SR
    e = np.minimum(1.0, t / max(a, 1e-4)) * np.exp(-np.maximum(t - a, 0) / max(d, 1e-4))
    return e
def bp(x, lo, hi, order=2): return sosfilt(butter(order, [lo, hi], "bandpass", fs=SR, output="sos"), x)
def lp(x, f, order=2): return sosfilt(butter(order, f, "lowpass", fs=SR, output="sos"), x)
def hp(x, f, order=2): return sosfilt(butter(order, f, "highpass", fs=SR, output="sos"), x)
def sine(freq, d, ph=0.0):
    f = np.asarray(freq, float) if np.ndim(freq) else np.full(int(d * SR), float(freq))
    return np.sin(2 * np.pi * np.cumsum(f) / SR + ph)
def noise(d): return rng.uniform(-1, 1, int(d * SR))
def norm(x, peak=0.7): return x / (np.max(np.abs(x)) + 1e-9) * peak
def fade(x, ms=4):
    n = int(ms / 1000 * SR)
    if n * 2 < len(x):
        x[:n] *= np.linspace(0, 1, n); x[-n:] *= np.linspace(1, 0, n)
    return x
def pad(x, d):
    out = np.zeros(int(d * SR)); out[:min(len(x), len(out))] = x[:len(out)]; return out

def reverb(x, wet=0.25, size=1.0):
    y = np.zeros(len(x) + int(1.5 * SR))
    y[:len(x)] = x
    out = np.zeros_like(y)
    for dl, g in ((0.0297, 0.77), (0.0371, 0.75), (0.0411, 0.73), (0.0437, 0.71)):
        d = int(dl * size * SR)
        buf = y.copy()
        for i in range(d, len(buf), d):
            buf[i:i + d] += buf[i - d:i][:len(buf[i:i + d])] * g
        out += buf
    out = lp(out, 5000) * 0.25
    return y * (1 - wet) + out * wet

def save_wav(name, x):
    from scipy.io import wavfile
    x = fade(np.asarray(x, float).copy())
    wavfile.write(f"{OUT}/{name}.wav", SR, (np.clip(x, -1, 1) * 32000).astype(np.int16))

def save_ogg(name, x, q=4):
    from scipy.io import wavfile
    tmp = f"/tmp/_{name}.wav"
    wavfile.write(tmp, SR, (np.clip(x, -1, 1) * 32000).astype(np.int16))
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", str(q), f"{OUT}/{name}.ogg"], check=True)
    os.remove(tmp)

# ---------- 발자국: 키보드처럼 "도각" ----------
for i, body_f in enumerate((310, 350, 285, 330)):
    d = 0.13
    n = int(d * SR)
    click = bp(noise(d), 2500, 7000) * env(n, 0.0004, 0.004) * 0.55
    body = (sine(body_f, d) + 0.35 * sine(body_f * 2.02, d)) * env(n, 0.0012, 0.028)
    thump = sine(np.linspace(150, 95, n), d) * env(n, 0.002, 0.04) * 0.7
    x = lp(click + body * 0.8 + thump, 7000)
    save_wav(f"step{i + 1}", norm(x, 0.55))

# ---------- 작은 효과음 ----------
def marimba(f, d=0.35, bright=0.4):
    n = int(d * SR)
    return (sine(f, d) * env(n, 0.002, d * 0.35) + bright * sine(f * 4.0, d) * env(n, 0.001, 0.025) + 0.15 * sine(f * 10.0, d) * env(n, 0.0005, 0.006))

def bell(f, d=0.8):
    n = int(d * SR)
    return sum(a * sine(f * r, d) * env(n, 0.001, d * k) for r, a, k in ((1, 1, 0.5), (2.76, 0.45, 0.25), (5.4, 0.22, 0.12), (8.9, 0.1, 0.06)))

def pluck(f, d=1.2, damp=0.996, bright=0.6):
    """카플러스-스트롱: 가야금처럼 뜯는 현. 끝에서 살짝 흔들어요(농현)"""
    n = int(d * SR)
    period = SR / f
    p = int(period)
    buf = lp(rng.uniform(-1, 1, p), 1500 + 5000 * bright, 1)
    out = np.zeros(n)
    frac = period - p
    for i in range(n):
        j = i % p
        out[i] = buf[j]
        nxt = buf[(j + 1) % p]
        buf[j] = damp * (0.5 * (buf[j] + nxt))
    # 농현: 뒤쪽에서 음높이를 살짝 떨어요 (위상을 늦췄다 당겨요)
    t = np.arange(n) / SR
    vib = 1 + 0.004 * np.sin(2 * np.pi * 5.5 * t) * np.clip((t - 0.25) / 0.3, 0, 1)
    idx = np.clip(np.cumsum(vib), 0, n - 1).astype(int)
    return out[idx] * env(n, 0.001, d * 0.45)

save_wav("tap", norm(bp(noise(0.05), 800, 3000) * env(int(0.05 * SR), 0.0005, 0.008) + 0.6 * sine(880, 0.05) * env(int(0.05 * SR), 0.001, 0.015), 0.45))
save_wav("blip", norm(marimba(660, 0.12, 0.25), 0.3))
save_wav("tick", norm(marimba(1250, 0.06, 0.5), 0.3))
n = int(0.12 * SR)
save_wav("pop", norm(sine(np.geomspace(380, 1150, n), 0.12) * env(n, 0.002, 0.04), 0.5))
save_wav("coin", norm(np.concatenate([bell(1568, 0.09)[:int(0.07 * SR)], bell(2093, 0.6)]), 0.45))
save_wav("good", norm(np.concatenate([marimba(784, 0.11), marimba(1175, 0.45)]), 0.5))
n = int(0.28 * SR)
bonk = (sine(np.geomspace(240, 140, n), 0.28) + 0.3 * sine(np.geomspace(480, 280, n), 0.28)) * env(n, 0.003, 0.08)
save_wav("bad", norm(lp(bonk, 2000), 0.5))
n = int(0.2 * SR)
tt = np.arange(n) / SR
boing = sine(np.geomspace(260, 720, n) * (1 + 0.04 * np.sin(2 * np.pi * 28 * tt)), 0.2) * env(n, 0.003, 0.09)
save_wav("jump", norm(boing, 0.42))
n = int(0.14 * SR)
save_wav("land", norm(lp(noise(0.14), 600) * env(n, 0.001, 0.03) + sine(np.linspace(110, 70, n), 0.14) * env(n, 0.002, 0.05), 0.5))
n = int(0.6 * SR)
buk = sine(np.geomspace(95, 55, n), 0.6) * env(n, 0.002, 0.18) + 0.25 * lp(noise(0.6), 900) * env(n, 0.001, 0.03)
save_wav("drum", norm(buk, 0.7))
n = int(0.35 * SR)
save_wav("crack", norm(bp(noise(0.35), 900, 4500) * env(n, 0.0005, 0.02) + 0.7 * sine(np.geomspace(200, 70, n), 0.35) * env(n, 0.002, 0.08), 0.6))
strokes = np.zeros(int(0.16 * SR))
nn = len(strokes)
shape = np.sin(np.linspace(0, np.pi, nn)) ** 1.5
save_wav("saw", norm(bp(noise(0.16), 1800, 5200) * shape * (0.7 + 0.3 * np.sin(np.linspace(0, 60, nn))), 0.35))
chirp = np.zeros(0)
for f0, f1 in ((2600, 3600), (3400, 2500), (2800, 3900)):
    m = int(0.06 * SR)
    chirp = np.concatenate([chirp, sine(np.linspace(f0, f1, m), 0.06) * np.sin(np.linspace(0, np.pi, m)), np.zeros(int(0.025 * SR))])
save_wav("chirp", norm(chirp, 0.3))
G = {"G3": 196.0, "A3": 220.0, "C4": 261.6, "D4": 293.7, "E4": 329.6, "G4": 392.0, "A4": 440.0, "C5": 523.3, "D5": 587.3, "E5": 659.3, "G5": 784.0, "A5": 880.0}
win = np.zeros(int(1.6 * SR))
for k, nm in enumerate(["G4", "A4", "C5", "D5", "G5"]):
    s = pluck(G[nm], 1.0, 0.997)
    st = int(k * 0.1 * SR)
    win[st:st + len(s)] += s[:len(win) - st]
save_wav("win", norm(reverb(win, 0.3)[:int(1.8 * SR)], 0.55))
fail = np.zeros(int(1.0 * SR))
for k, nm in enumerate(["D4", "A3", "G3"]):
    s = pluck(G[nm], 0.7, 0.994, 0.3)
    st = int(k * 0.16 * SR)
    fail[st:st + len(s)] += s[:len(fail) - st]
save_wav("fail", norm(fail, 0.5))
# 두루마리 펼치는 소리 (종이가 스르륵)
n = int(0.7 * SR)
sw = bp(noise(0.7), 1500, 7000) * np.sin(np.linspace(0, np.pi, n)) ** 2
crk = np.zeros(n)
for i in range(40):
    p = int(rng.uniform(0.05, 0.6) * SR)
    crk[p:p + 200] += rng.uniform(-1, 1, 200) * np.exp(-np.arange(200) / 40)
save_wav("scroll", norm(sw * 0.7 + hp(crk, 2000) * 0.25, 0.32))
# 물 첨벙 (낚시)
n = int(0.5 * SR)
spl = lp(noise(0.5), 3000) * env(n, 0.002, 0.08)
for i in range(6):
    p = int(rng.uniform(0.05, 0.35) * SR)
    m = int(0.05 * SR)
    spl[p:p + m] += sine(np.geomspace(500, 1400, m), 0.05) * env(m, 0.001, 0.015) * 0.4
save_wav("splash", norm(spl, 0.5))

# ---------- 배경음: 굿거리 느낌의 3박, 가야금 + 대금 + 장구 ----------
BPM = 76
beat = 60 / BPM
bars = 16
L = bars * 3 * beat
music = np.zeros(int((L + 3) * SR))
def put(x, at, gain=1.0):
    st = int(at * SR)
    end = min(len(music), st + len(x))
    music[st:end] += x[:end - st] * gain

def daegeum(f, d):
    """대금: 숨소리 섞인 부드러운 피리. 긴 음은 점점 떨어요"""
    n = int(d * SR)
    t = np.arange(n) / SR
    vib = 1 + 0.012 * np.sin(2 * np.pi * 5.2 * t) * np.clip((t - 0.3) / 0.5, 0, 1)
    slide = 1 - 0.03 * np.exp(-t / 0.05)   # 살짝 아래에서 밀어 올려요
    fr = f * vib * slide
    tone = sine(fr, d) + 0.28 * sine(fr * 2, d) + 0.08 * sine(fr * 3, d)
    breath = bp(noise(d), f * 1.5, min(f * 6, 12000)) * 0.12
    e = np.minimum(1, t / 0.06) * np.minimum(1, (d - t) / 0.12) * (0.85 + 0.15 * np.exp(-t / 0.2))
    return (tone + breath) * np.clip(e, 0, 1)

mel = [("D5", 2), ("E5", 1), ("D5", 1), ("C5", 1), ("A4", 1), ("G4", 2), ("A4", 1), ("C5", 3),
       ("D5", 2), ("E5", 1), ("G5", 1), ("E5", 1), ("D5", 1), ("C5", 2), ("A4", 1), ("D5", 3),
       ("D5", 2), ("E5", 1), ("D5", 1), ("C5", 1), ("A4", 1), ("G4", 1), ("A4", 1), ("C5", 1), ("A4", 3),
       ("G4", 2), ("A4", 1), ("C5", 1), ("D5", 1), ("E5", 1), ("D5", 1), ("C5", 1), ("A4", 1), ("G4", 3)]
at = 0.0
for nm, b in mel:
    put(daegeum(G[nm], b * beat * 0.98), at, 0.32)
    at += b * beat
roots = ["G3", "C4", "G3", "C4", "G3", "A3", "C4", "D4", "G3", "C4", "G3", "A3", "C4", "D4", "D4", "G3"]
up = {"G3": ("D4", "G4"), "C4": ("G4", "C5"), "A3": ("E4", "A4"), "D4": ("A4", "D5")}
for bi, r in enumerate(roots):
    t0 = bi * 3 * beat
    put(pluck(G[r], 2.2, 0.998, 0.4), t0, 0.5)
    put(pluck(G[up[r][0]], 1.4, 0.997, 0.5), t0 + beat, 0.32)
    put(pluck(G[up[r][1]], 1.2, 0.997, 0.55), t0 + 2 * beat, 0.3)
    if bi % 2 == 1:
        put(pluck(G[up[r][0]], 0.9, 0.996, 0.5), t0 + 2.5 * beat, 0.2)
# 장구: 덩(쿵+따) - 기덕 쿵 (아주 작게)
def kung(d=0.5):
    n = int(d * SR)
    return sine(np.geomspace(110, 70, n), d) * env(n, 0.002, 0.15)
def ttak(d=0.12):
    n = int(d * SR)
    return bp(noise(d), 1500, 6000) * env(n, 0.0005, 0.02) + 0.4 * sine(780, d) * env(n, 0.001, 0.03)
for bi in range(bars):
    t0 = bi * 3 * beat
    put(kung(), t0, 0.35); put(ttak(), t0, 0.12)
    put(ttak(), t0 + 1.5 * beat, 0.08); put(ttak(), t0 + 2 * beat, 0.07)
    put(kung(0.35), t0 + 2.5 * beat, 0.2)
wet = reverb(music, 0.28, 1.3)
loop = wet[:int(L * SR)].copy()
tail = wet[int(L * SR):]
loop[:len(tail)] += tail[:len(loop)]
loop = lp(loop, 9000)
save_ogg("bgm", norm(loop, 0.5), 4)

# ---------- 바람과 새소리 (아주 작게 깔리는 소리) ----------
D = 24.0
amb = lp(noise(D), 500) * (0.5 + 0.5 * np.sin(np.linspace(0, 2 * np.pi * 3, int(D * SR)))) * 0.15
for i in range(14):
    p = rng.uniform(0.5, D - 1)
    f0 = rng.uniform(2400, 3600)
    seq = np.zeros(0)
    for k in range(rng.integers(2, 5)):
        m = int(rng.uniform(0.04, 0.09) * SR)
        a, b2 = f0 * rng.uniform(0.85, 1.15), f0 * rng.uniform(0.85, 1.25)
        seq = np.concatenate([seq, sine(np.linspace(a, b2, m), m / SR) * np.sin(np.linspace(0, np.pi, m)), np.zeros(int(0.03 * SR))])
    st = int(p * SR)
    amb[st:st + len(seq)] += seq * rng.uniform(0.05, 0.12)
save_ogg("ambience", norm(amb, 0.35), 2)

# ---------- 시냇물 졸졸 (개울 근처에서만 들려요) ----------
D = 6.0
cr = bp(noise(D), 300, 2500) * 0.25
for i in range(140):
    p = int(rng.uniform(0, D - 0.06) * SR)
    m = int(rng.uniform(0.01, 0.03) * SR)
    cr[p:p + m] += sine(np.geomspace(rng.uniform(500, 900), rng.uniform(900, 2200), m), m / SR) * env(m, 0.001, 0.008) * 0.5
xf = int(0.5 * SR)
cr[:xf] = cr[:xf] * np.linspace(0, 1, xf) + cr[-xf:] * np.linspace(1, 0, xf)
cr = cr[:-xf]
save_ogg("creek", norm(cr, 0.4), 2)
print("ok")
