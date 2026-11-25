# 바닷속 물고기 그림(source/textures/sea_fishN.png)으로 입체 물고기 모양을 만들어요.
# 그림의 모양(투명하지 않은 곳)을 따라 가운데는 도톰하고 가장자리(지느러미, 꼬리)는 얇게 부풀려
# 양쪽에 같은 그림이 입혀지는 둥근 몸을 만들고 source/models/sea_fishN.obj 로 저장해요.
# 크기는 예전 그림 판과 같아요(가로 1.0, 세로 0.75, 머리가 +x). 실행: python3 tools/fish_mesh.py
import os
import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = os.path.join(os.path.dirname(__file__), "..", "source")
GX, GY = 52, 39          # 격자 칸 수 (휴대폰에서도 가볍게)
W, H = 1.0, 0.75
THICK = 0.30             # 가장 두꺼운 곳의 전체 두께 (가로 1.0 기준)


def fill_rim(path):
    # 그림 밖 투명한 곳의 색(검정)을 가장 가까운 물고기 색으로 채워요(투명도는 그대로).
    # 비스듬히 볼 때 테두리가 검게 번지거나 찢어져 보이지 않게
    arr = np.asarray(Image.open(path).convert("RGBA")).copy()
    solid = arr[:, :, 3] > 200
    idx = ndimage.distance_transform_edt(~solid, return_distances=False, return_indices=True)
    rgb = arr[:, :, :3][idx[0], idx[1]]
    arr[:, :, :3] = np.where(solid[:, :, None], arr[:, :, :3], rgb)
    Image.fromarray(arr, "RGBA").save(path)


def build(idx):
    tex = os.path.join(ROOT, "textures", "sea_fish%d.png" % idx)
    fill_rim(tex)
    im = Image.open(tex).convert("RGBA")
    a = np.asarray(im)[:, :, 3] > 128
    a = ndimage.binary_opening(a, iterations=1)
    dist = ndimage.distance_transform_edt(a)
    # 몸통만 도톰하게: 얇은 지느러미를 지운 몸통 거리와 섞어요
    body = ndimage.binary_opening(a, structure=np.ones((3, 3)), iterations=6)
    bdist = ndimage.distance_transform_edt(body)
    # 두께가 계단지지 않게 부드럽게 펴요
    bdist = ndimage.gaussian_filter(bdist, 2.0)
    dist = ndimage.gaussian_filter(dist, 1.0)
    dmax = max(1.0, bdist.max())
    ih, iw = a.shape
    # 그림 밖 점은 가장 가까운 그림 가장자리로 끌어당겨서 테두리가 매끈한 곡선이 되게 해요
    _, near = ndimage.distance_transform_edt(~a, return_indices=True)

    def snap(u, v):
        x = min(iw - 1, max(0, int(u * (iw - 1) + 0.5)))
        y = min(ih - 1, max(0, int(v * (ih - 1) + 0.5)))
        if a[y, x]:
            return u, v, True
        ny, nx = near[0][y, x], near[1][y, x]
        return nx / (iw - 1), ny / (ih - 1), False

    def sample(arr, u, v):
        x = min(iw - 1, max(0, int(u * (iw - 1) + 0.5)))
        y = min(ih - 1, max(0, int(v * (ih - 1) + 0.5)))
        return arr[y, x]

    def half_thick(u, v):
        if not sample(a, u, v):
            return 0.0
        b = max(0.0, sample(bdist, u, v)) / dmax
        f = min(1.0, sample(dist, u, v) / 6.0)
        t = (np.sqrt(b) * 0.92 + 0.08 * f) if b > 0.02 else 0.012 * f + b * 2.0
        return THICK * 0.5 * t

    verts = {}
    vlist = []
    uvs = []

    def vid(i, j, side):
        key = (i, j, side)
        if key in verts:
            return verts[key]
        u, v, inside = snap(i / GX, j / GY)
        z = half_thick(u, v) * side if inside else 0.0
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
