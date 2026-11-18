# 땅 질감 만들기: 이어 붙여도 이음새가 없는(타일) 그림 같은 풀밭, 흙, 큰 얼룩 무늬
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
import sys
out = sys.argv[1]
rng = np.random.default_rng(7)
N = 512

def tile_noise(n, scale, seed):
    # 주기적인 잡음: 저주파만 남긴 무작위 (FFT) → 자연스럽게 이어져요
    r = np.random.default_rng(seed)
    f = np.fft.fft2(r.standard_normal((n, n)))
    ky = np.fft.fftfreq(n)[:, None]
    kx = np.fft.fftfreq(n)[None, :]
    k = np.sqrt(kx * kx + ky * ky)
    f *= np.exp(-(k * n / scale) ** 2)
    a = np.real(np.fft.ifft2(f))
    a = (a - a.min()) / (a.max() - a.min())
    return a

def lerp(a, b, t):
    return a + (b - a) * t[..., None]

# ---- 풀밭 ----
low = tile_noise(N, 4, 1)
mid = tile_noise(N, 14, 2)
hi = tile_noise(N, 60, 3)
c_dark = np.array([0.36, 0.55, 0.24])
c_light = np.array([0.58, 0.72, 0.32])
c_warm = np.array([0.66, 0.70, 0.34])
g = lerp(c_dark, c_light, np.clip(low * 0.7 + mid * 0.5 - 0.1, 0, 1))
g = lerp(g, c_warm, np.clip((mid - 0.6) * 2.0, 0, 1) * 0.5)
g *= (0.9 + hi[..., None] * 0.2)
img = Image.fromarray((np.clip(g, 0, 1) * 255).astype(np.uint8))
d = ImageDraw.Draw(img, "RGBA")
for i in range(7000):
    x, y = rng.uniform(0, N, 2)
    ln = rng.uniform(5, 13)
    ang = rng.normal(-np.pi / 2, 0.45)
    dx, dy = np.cos(ang) * ln, np.sin(ang) * ln
    base = g[int(y) % N, int(x) % N]
    shade = rng.choice([0.72, 0.82, 1.15, 1.28], p=[0.25, 0.3, 0.3, 0.15])
    col = np.clip(base * shade + (np.array([0.05, 0.04, -0.02]) if shade > 1 else 0), 0, 1)
    rgba = tuple(int(c * 255) for c in col) + (int(rng.uniform(120, 220)),)
    w = int(rng.choice([1, 2], p=[0.6, 0.4]))
    for ox in (-N, 0, N):
        for oy in (-N, 0, N):
            d.line([(x + ox, y + oy), (x + dx + ox, y + dy + oy)], fill=rgba, width=w)
# 아주 드문 작은 꽃잎 점
for i in range(90):
    x, y = rng.uniform(0, N, 2)
    col = [(255, 250, 235, 200), (255, 220, 120, 190), (250, 190, 210, 180)][i % 3]
    for ox in (-N, 0, N):
        for oy in (-N, 0, N):
            d.ellipse([x + ox - 1.5, y + oy - 1.5, x + ox + 1.5, y + oy + 1.5], fill=col)
img = img.filter(ImageFilter.GaussianBlur(0.5))
img.save(f"{out}/grass.png")

# ---- 흙 ----
low = tile_noise(N, 5, 11)
mid = tile_noise(N, 20, 12)
hi = tile_noise(N, 90, 13)
c1 = np.array([0.62, 0.50, 0.34])
c2 = np.array([0.78, 0.66, 0.46])
dcol = lerp(c1, c2, np.clip(low * 0.6 + mid * 0.6 - 0.1, 0, 1)) * (0.92 + hi[..., None] * 0.16)
img = Image.fromarray((np.clip(dcol, 0, 1) * 255).astype(np.uint8))
d = ImageDraw.Draw(img, "RGBA")
for i in range(420):
    x, y = rng.uniform(0, N, 2)
    r = rng.uniform(1.0, 3.6)
    sh = rng.uniform(0.55, 0.85)
    base = (np.array([0.7, 0.68, 0.64]) * sh * 255).astype(int)
    for ox in (-N, 0, N):
        for oy in (-N, 0, N):
            d.ellipse([x + ox - r, y + oy - r * 0.8, x + ox + r, y + oy + r * 0.8], fill=tuple(base) + (230,))
            d.ellipse([x + ox - r * 0.5, y + oy - r * 0.6, x + ox + r * 0.2, y + oy - r * 0.1], fill=(255, 250, 240, 90))
for i in range(2500):
    x, y = rng.uniform(0, N, 2)
    for ox in (-N, 0, N):
        for oy in (-N, 0, N):
            d.point((x + ox, y + oy), fill=(80, 60, 40, 150))
img = img.filter(ImageFilter.GaussianBlur(0.45))
img.save(f"{out}/dirt.png")

# ---- 큰 얼룩 (풀색 변화와 경계를 들쭉날쭉하게) ----
a = tile_noise(256, 6, 21)
b = tile_noise(256, 24, 22)
c = tile_noise(256, 70, 23)
Image.fromarray((np.stack([a, b, c], -1) * 255).astype(np.uint8)).save(f"{out}/macro.png")
print("ok")
