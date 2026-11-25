# 바닷속 물고기 그림(source/textures/sea_fishN.png)으로 입체 물고기 모양을 만들어요.
# 그림의 모양(투명하지 않은 곳)을 따라 가운데는 도톰하고 가장자리(지느러미, 꼬리)는 얇게 부풀려
# 양쪽에 같은 그림이 입혀지는 둥근 몸을 만들고 source/models/sea_fishN.obj 로 저장해요.
# 크기는 예전 그림 판과 같아요(가로 1.0, 세로 0.75, 머리가 +x). 실행: python3 tools/fish_mesh.py
import os
import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = os.path.join(os.path.dirname(__file__), "..", "source")
GX, GY = 44, 33          # 격자 칸 수 (휴대폰에서도 가볍게)
W, H = 1.0, 0.75
THICK = 0.30             # 가장 두꺼운 곳의 전체 두께 (가로 1.0 기준)


def build(idx):
    im = Image.open(os.path.join(ROOT, "textures", "sea_fish%d.png" % idx)).convert("RGBA")
    a = np.asarray(im)[:, :, 3] > 128
    a = ndimage.binary_opening(a, iterations=1)
    dist = ndimage.distance_transform_edt(a)
    # 몸통만 도톰하게: 얇은 지느러미를 지운 몸통 거리와 섞어요
    body = ndimage.binary_opening(a, structure=np.ones((3, 3)), iterations=6)
    bdist = ndimage.distance_transform_edt(body)
    dmax = max(1.0, bdist.max())
    ih, iw = a.shape

    def sample(arr, u, v):
        x = min(iw - 1, max(0, int(u * (iw - 1) + 0.5)))
        y = min(ih - 1, max(0, int(v * (ih - 1) + 0.5)))
        return arr[y, x]

    def half_thick(u, v):
        if not sample(a, u, v):
            return 0.0
        b = sample(bdist, u, v) / dmax
        f = min(1.0, sample(dist, u, v) / 6.0)
        t = (np.sqrt(b) * 0.92 + 0.08 * f) if b > 0 else 0.012 * f
        return THICK * 0.5 * t

    verts = {}
    vlist = []
    uvs = []

    def vid(i, j, side):
        key = (i, j, side)
        if key in verts:
            return verts[key]
        u = i / GX
        v = j / GY
        z = half_thick(u, v) * side
        x = (u - 0.5) * W
        y = (0.5 - v) * H
        verts[key] = len(vlist)
        vlist.append((x, y, z))
        uvs.append((u, v))
        return verts[key]

    tris = []
    for j in range(GY):
        for i in range(GX):
            corners = [(i, j), (i + 1, j), (i + 1, j + 1), (i, j + 1)]
            if not any(sample(a, c[0] / GX, c[1] / GY) for c in corners):
                continue
            for side in (1, -1):
                q = [vid(c[0], c[1], side) for c in corners]
                if side == 1:
                    tris.append((q[0], q[2], q[1]))
                    tris.append((q[0], q[3], q[2]))
                else:
                    tris.append((q[0], q[1], q[2]))
                    tris.append((q[0], q[2], q[3]))
    # 정점 노멀 (면 노멀 평균)
    V = np.array(vlist)
    N = np.zeros_like(V)
    for t in tris:
        p0, p1, p2 = V[t[0]], V[t[1]], V[t[2]]
        n = np.cross(p1 - p0, p2 - p0)
        for k in t:
            N[k] += n
    ln = np.linalg.norm(N, axis=1, keepdims=True)
    ln[ln == 0] = 1
    N /= ln
    out = os.path.join(ROOT, "models", "sea_fish%d.obj" % idx)
    with open(out, "w") as f:
        f.write("# made by tools/fish_mesh.py\n")
        for p in vlist:
            f.write("v %.4f %.4f %.4f\n" % p)
        for uv in uvs:
            f.write("vt %.4f %.4f\n" % (uv[0], 1.0 - uv[1]))
        for n in N:
            f.write("vn %.4f %.4f %.4f\n" % tuple(n))
        for t in tris:
            f.write("f " + " ".join("%d/%d/%d" % (k + 1, k + 1, k + 1) for k in t) + "\n")
    print(out, len(vlist), "verts", len(tris), "tris")


for i in range(4):
    build(i)
