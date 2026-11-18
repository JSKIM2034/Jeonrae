# 잎 그림 모음(2x2): 왼쪽 위 활엽수 잎 뭉치, 오른쪽 위 솔잎 다발, 왼쪽 아래 버드나무 가지, 오른쪽 아래 연두 잎 뭉치
import numpy as np, math, sys
from PIL import Image, ImageDraw, ImageFilter
out = sys.argv[1]
rng = np.random.default_rng(4)
S = 512
atlas = Image.new("RGBA", (S * 2, S * 2), (0, 0, 0, 0))

def leaf_poly(cx, cy, length, width, ang):
    pts = []
    for i in range(13):
        t = i / 12
        x = t * length
        w = width * math.sin(math.pi * t) ** 0.8 * (1 - 0.25 * t)
        pts.append((x, w))
    for i in range(12, -1, -1):
        t = i / 12
        x = t * length
        w = width * math.sin(math.pi * t) ** 0.8 * (1 - 0.25 * t)
        pts.append((x, -w))
    ca, sa = math.cos(ang), math.sin(ang)
    return [(cx + x * ca - y * sa, cy + x * sa + y * ca) for x, y in pts]

def broad(ox, oy, base, seed):
    r = np.random.default_rng(seed)
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx, cy = S / 2, S / 2
    # 잔가지
    for k in range(6):
        a = r.uniform(0, 2 * math.pi)
        d.line([(cx, cy), (cx + math.cos(a) * 150, cy + math.sin(a) * 150)], fill=(92, 66, 40, 255), width=5)
    leaves = []
    for k in range(46):
        a = r.uniform(0, 2 * math.pi)
        dist = r.uniform(20, 170)
        px, py = cx + math.cos(a) * dist, cy + math.sin(a) * dist
        ang = a + r.normal(0, 0.5)
        ln = r.uniform(70, 120)
        wd = ln * r.uniform(0.26, 0.34)
        shade = r.uniform(0.75, 1.15)
        leaves.append((dist, px, py, ln, wd, ang, shade))
    leaves.sort(key=lambda t: -t[0])
    for dist, px, py, ln, wd, ang, shade in leaves:
        c = np.clip(np.array(base) * shade, 0, 255).astype(int)
        poly = leaf_poly(px - math.cos(ang) * ln * 0.3, py - math.sin(ang) * ln * 0.3, ln, wd, ang)
        d.polygon(poly, fill=tuple(c) + (255,), outline=tuple((c * 0.6).astype(int)) + (255,))
        # 잎맥과 한쪽 밝은 면
        x0, y0 = px - math.cos(ang) * ln * 0.3, py - math.sin(ang) * ln * 0.3
        d.line([(x0, y0), (x0 + math.cos(ang) * ln * 0.9, y0 + math.sin(ang) * ln * 0.9)], fill=tuple(np.clip(c * 1.2, 0, 255).astype(int)) + (150,), width=2)
        half = leaf_poly(x0, y0, ln, wd * 0.5, ang + 0.05)
        d.polygon(half[:13] + [(x0, y0)], fill=tuple(np.clip(c * 1.1, 0, 255).astype(int)) + (55,))
    img = img.filter(ImageFilter.GaussianBlur(0.6))
    atlas.paste(img, (ox, oy), img)

def pine(ox, oy):
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx, cy = S / 2, S * 0.62
    d.line([(cx, S * 0.95), (cx, cy)], fill=(110, 60, 40, 255), width=8)
    for k in range(700):
        a = rng.normal(-math.pi / 2, 0.9)
        ln = rng.uniform(80, 190)
        bx = cx + rng.normal(0, 30)
        by = cy + rng.normal(0, 25)
        c = np.array([46, 92, 54]) * rng.uniform(0.7, 1.35)
        c = tuple(np.clip(c, 0, 255).astype(int)) + (255,)
        d.line([(bx, by), (bx + math.cos(a) * ln, by + math.sin(a) * ln * 0.75)], fill=c, width=int(rng.choice([2, 3])))
    img = img.filter(ImageFilter.GaussianBlur(0.5))
    atlas.paste(img, (ox, oy), img)

def willow(ox, oy):
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for k in range(9):
        x = 40 + k * 54 + rng.uniform(-10, 10)
        sway = rng.uniform(-20, 20)
        pts = [(x + sway * (t ** 2), 10 + t * 490) for t in np.linspace(0, 1, 20)]
        d.line(pts, fill=(110, 120, 60, 255), width=2)
        for t in np.linspace(0.05, 0.98, 26):
            px, py = x + sway * t * t, 10 + t * 490
            for side in (-1, 1):
                ang = math.pi / 2 + side * rng.uniform(0.25, 0.55)
                c = np.array([120, 170, 80]) * rng.uniform(0.8, 1.2)
                d.polygon(leaf_poly(px, py, rng.uniform(26, 40), 5, ang), fill=tuple(np.clip(c, 0, 255).astype(int)) + (255,))
    img = img.filter(ImageFilter.GaussianBlur(0.5))
    atlas.paste(img, (ox, oy), img)

broad(0, 0, (78, 132, 62), 1)
pine(S, 0)
willow(0, S)
broad(S, S, (118, 160, 70), 2)
# 투명한 가장자리 색이 검게 번지지 않도록 바깥 색을 퍼뜨려요
arr = np.array(atlas).astype(np.float32)
rgb, a = arr[..., :3], arr[..., 3:] / 255.0
blur = np.array(Image.fromarray(np.uint8(np.clip(rgb * a, 0, 255))).filter(ImageFilter.GaussianBlur(8))).astype(np.float32)
wa = np.array(Image.fromarray(np.uint8(a[..., 0] * 255)).filter(ImageFilter.GaussianBlur(8))).astype(np.float32)[..., None] / 255.0
fill = blur / np.maximum(wa, 1e-3)
rgb = np.where(a > 0.02, rgb, fill)
Image.fromarray(np.uint8(np.clip(np.concatenate([rgb, a * 255], -1), 0, 255)), "RGBA").save(f"{out}/leaves.png")
print("ok")
