# 집 재질 질감: 초가 짚, 회벽, 나뭇결, 마루널, 돌, 한지, 기와 얼룩 (모두 이음새 없는 타일)
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
import sys
out = sys.argv[1]
rng = np.random.default_rng(11)

def tile_noise(n, scale, seed, aniso=(1.0, 1.0)):
    r = np.random.default_rng(seed)
    f = np.fft.fft2(r.standard_normal((n, n)))
    ky = np.fft.fftfreq(n)[:, None] * aniso[1]
    kx = np.fft.fftfreq(n)[None, :] * aniso[0]
    k = np.sqrt(kx * kx + ky * ky)
    f *= np.exp(-(k * n / scale) ** 2)
    a = np.real(np.fft.ifft2(f))
    return (a - a.min()) / (a.max() - a.min())

def lerp(a, b, t):
    return a + (b - a) * t[..., None]

def wrap_draw(d, n, fn):
    for ox in (-n, 0, n):
        for oy in (-n, 0, n):
            fn(d, ox, oy)

def save(arr, name):
    Image.fromarray((np.clip(arr, 0, 1) * 255).astype(np.uint8)).save(f"{out}/{name}.png")

N = 512
# ---- 초가 짚: 결이 한 방향으로 흐르는 지푸라기 ----
base = tile_noise(N, 6, 1)
streak = tile_noise(N, 40, 2, aniso=(6.0, 0.4))
c_old = np.array([0.62, 0.52, 0.36])
c_new = np.array([0.86, 0.72, 0.46])
col = lerp(c_old, c_new, np.clip(base * 0.6 + streak * 0.6 - 0.15, 0, 1))
img = Image.fromarray((col * 255).astype(np.uint8))
d = ImageDraw.Draw(img, "RGBA")
for i in range(9000):
    x, y = rng.uniform(0, N, 2)
    ln = rng.uniform(18, 46)
    ang = np.pi / 2 + rng.normal(0, 0.12)
    bend = rng.normal(0, 3)
    sh = rng.choice([0.62, 0.78, 1.12, 1.25], p=[0.2, 0.3, 0.35, 0.15])
    c = np.clip(col[int(y) % N, int(x) % N] * sh, 0, 1)
    rgba = tuple(int(v * 255) for v in c) + (int(rng.uniform(140, 230)),)
    pts = [(x + np.cos(ang) * ln * t + bend * np.sin(t * 3.1) , y + np.sin(ang) * ln * t) for t in np.linspace(0, 1, 5)]
    wrap_draw(d, N, lambda dd, ox, oy: dd.line([(px + ox, py + oy) for px, py in pts], fill=rgba, width=int(rng.choice([1, 2]))))
img = img.filter(ImageFilter.GaussianBlur(0.4))
img.save(f"{out}/thatch.png")

# ---- 회벽: 흙손 자국과 얼룩, 아주 가는 금 (밝은 회색 → 벽 색으로 물들여요) ----
low = tile_noise(N, 5, 11)
mid = tile_noise(N, 22, 12)
hi = tile_noise(N, 120, 13)
v = 0.84 + low * 0.08 + mid * 0.06 + hi * 0.04
arr = np.stack([v, v * 0.985, v * 0.96], -1)
img = Image.fromarray((np.clip(arr, 0, 1) * 255).astype(np.uint8))
d = ImageDraw.Draw(img, "RGBA")
for i in range(260):   # 흙손으로 바른 둥근 자국
    x, y = rng.uniform(0, N, 2)
    r = rng.uniform(20, 60)
    a0 = rng.uniform(0, 360)
    c = (255, 252, 245, 40) if i % 2 else (190, 182, 170, 34)
    wrap_draw(d, N, lambda dd, ox, oy: dd.arc([x + ox - r, y + oy - r * 0.6, x + ox + r, y + oy + r * 0.6], a0, a0 + rng.uniform(40, 110), fill=c, width=2))
for i in range(14):   # 가는 금
    x, y = rng.uniform(0, N, 2)
    pts = [(x, y)]
    for k in range(rng.integers(3, 7)):
        x += rng.normal(0, 9); y += rng.uniform(4, 12)
        pts.append((x, y))
    wrap_draw(d, N, lambda dd, ox, oy: dd.line([(px + ox, py + oy) for px, py in pts], fill=(150, 140, 128, 90), width=1))
for i in range(1500):
    x, y = rng.uniform(0, N, 2)
    wrap_draw(d, N, lambda dd, ox, oy: dd.point((x + ox, y + oy), fill=(160, 152, 140, 110)))
img = img.filter(ImageFilter.GaussianBlur(0.5))
img.save(f"{out}/plaster.png")

# ---- 나뭇결 (밝은 색 → 나무 색으로 물들여요), 세로 결 ----
def wood(seed, boards):
    g = tile_noise(N, 60, seed, aniso=(0.25, 8.0))
    ring = np.sin((tile_noise(N, 10, seed + 1, aniso=(0.4, 4.0)) * 22.0 + g * 6.0)) * 0.5 + 0.5
    v = 0.74 + ring * 0.14 + g * 0.12
    arr = np.stack([v, v * 0.93, v * 0.84], -1)
    img = Image.fromarray((np.clip(arr, 0, 1) * 255).astype(np.uint8))
    d = ImageDraw.Draw(img, "RGBA")
    for i in range(10):   # 옹이
        x, y = rng.uniform(0, N, 2)
        for k in range(5):
            r = 3 + k * 3
            wrap_draw(d, N, lambda dd, ox, oy: dd.ellipse([x + ox - r * 0.6, y + oy - r * 1.6, x + ox + r * 0.6, y + oy + r * 1.6], outline=(120, 90, 60, 120 - k * 18), width=2))
    if boards:
        for bx in range(0, N, N // boards):
            wrap_draw(d, N, lambda dd, ox, oy: dd.line([(bx + ox, 0 + oy), (bx + ox, N + oy)], fill=(70, 50, 34, 230), width=3))
            wrap_draw(d, N, lambda dd, ox, oy: dd.line([(bx + 3 + ox, 0 + oy), (bx + 3 + ox, N + oy)], fill=(255, 245, 230, 60), width=1))
    return img.filter(ImageFilter.GaussianBlur(0.4))
wood(21, 0).save(f"{out}/wood.png")
wood(23, 6).save(f"{out}/plank.png")

# ---- 돌 (화강암처럼 점이 박힌 밝은 회색 → 돌마다 색을 달리해요) ----
low = tile_noise(N, 6, 31)
hi = tile_noise(N, 140, 32)
v = 0.74 + low * 0.14 + hi * 0.12
arr = np.stack([v, v * 0.985, v * 0.96], -1)
img = Image.fromarray((np.clip(arr, 0, 1) * 255).astype(np.uint8))
d = ImageDraw.Draw(img, "RGBA")
for i in range(5000):
    x, y = rng.uniform(0, N, 2)
    c = [(70, 70, 72, 150), (240, 236, 228, 140), (150, 130, 110, 120)][i % 3]
    r = rng.uniform(0.5, 1.6)
    wrap_draw(d, N, lambda dd, ox, oy: dd.ellipse([x + ox - r, y + oy - r, x + ox + r, y + oy + r], fill=c))
img.filter(ImageFilter.GaussianBlur(0.5)).save(f"{out}/stone.png")

# ---- 한지: 하얀 바탕에 닥나무 섬유 ----
v = 0.95 + tile_noise(256, 12, 41) * 0.05
arr = np.stack([v, v * 0.98, v * 0.93], -1)
img = Image.fromarray((np.clip(arr, 0, 1) * 255).astype(np.uint8))
d = ImageDraw.Draw(img, "RGBA")
for i in range(500):
    x, y = rng.uniform(0, 256, 2)
    ang = rng.uniform(0, np.pi)
    ln = rng.uniform(4, 16)
    wrap_draw(d, 256, lambda dd, ox, oy: dd.line([(x + ox, y + oy), (x + ox + np.cos(ang) * ln, y + oy + np.sin(ang) * ln)], fill=(210, 196, 170, 90), width=1))
img.save(f"{out}/hanji.png")

# ---- 기와 얼룩 (밝은 회색 → 기와 색으로) ----
v = 0.86 + tile_noise(256, 8, 51) * 0.1 + tile_noise(256, 60, 52) * 0.06
save(np.stack([v, v, v * 1.02], -1), "tile_mottle")
# ---- 나이테 (그루터기, 장작 단면) ----
yy, xx = np.mgrid[0:256, 0:256]
rr = np.hypot(xx - 128, yy - 128) / 128.0
ring = 0.5 + 0.5 * np.sin(rr * 46.0 + tile_noise(256, 10, 61) * 4.0)
v = 0.82 - ring * 0.12 - np.clip(rr - 0.9, 0, 1) * 2.0
arr = np.stack([v, v * 0.82, v * 0.6], -1)
save(arr, "endgrain")
print("ok")
