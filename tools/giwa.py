# 놀부네 기와집 (블렌더). 앞쪽 = 블렌더 -Y, 몸채 9 x 6, 벽 높이 4 -> models/giwa.glb
import sys, math, random
sys.path.insert(0, "/home/claude/jeonrae/tools")
from blcommon import *

OUT = "/home/claude/jeonrae/source/models/giwa.glb"
W, D, H = 9.0, 6.0, 4.0
HX, HY = W / 2, D / 2
BASE = 0.5
rnd = random.Random(3)
b = Builder()
M_TILE = b.mat("Tile", (0.3, 0.32, 0.38))
M_TILEB = b.mat("TileBase", (0.2, 0.21, 0.25))
M_LIME = b.mat("Lime", (0.95, 0.94, 0.9))
M_PLASTER = b.mat("Plaster", (0.95, 0.93, 0.86))
M_WOOD = b.mat("Wood", (0.6, 0.4, 0.25))
M_DWOOD = b.mat("DarkWood", (0.42, 0.27, 0.16))
M_PLANK = b.mat("Plank", (0.75, 0.55, 0.35))
M_PAPER = b.mat("Paper", (0.98, 0.95, 0.86))
M_STONE = b.mat("Stone", (0.7, 0.68, 0.64))
M_PAINT = b.mat("Paint", (0.3, 0.55, 0.45))   # 단청 초록
M_RED = b.mat("PaintRed", (0.7, 0.25, 0.2))

# ---------- 기단 (다듬은 돌) + 계단 ----------
b.box((W + 0.9, D + 0.9, BASE), (0, 0, BASE / 2), M_STONE, 0.03, segs=2)
z = 0.0
for row in range(2):
    x = -HX - 0.45
    hgt = BASE / 2
    while x < HX + 0.45:
        w = rnd.uniform(0.55, 0.9)
        w = min(w, HX + 0.45 - x)
        b.box((w - 0.03, 0.08, hgt - 0.03), (x + w / 2, -HY - 0.47, hgt / 2 + row * hgt), M_STONE, 0.025, segs=2)
        x += w
for i, (dw, dy) in enumerate(((2.2, 0.0), (2.0, 0.32))):
    b.box((dw, 0.36, BASE * (2 - i) / 2), (0, -HY - 0.62 - (1 - i) * 0.32, BASE * (2 - i) / 4), M_STONE, 0.03, segs=2)

# ---------- 둥근 기둥, 주춧돌 ----------
xs = [-HX, -HX / 3, HX / 3, HX]
TOP = H
for y in (-HY, HY):
    for x in xs:
        b.cyl(0.24, 0.16, (x, y, BASE + 0.08), M_STONE, verts=12, r2=0.2)
        b.cyl(0.17, TOP - BASE - 0.16, (x, y, (TOP + BASE + 0.16) / 2), M_WOOD, verts=14)
for x in (-HX, HX):
    b.cyl(0.24, 0.16, (x, 0, BASE + 0.08), M_STONE, verts=12, r2=0.2)
    b.cyl(0.17, TOP - BASE - 0.16, (x, 0, (TOP + BASE + 0.16) / 2), M_WOOD, verts=14)

# ---------- 벽: 회벽 + 나무 틀 ----------
wall_h = TOP - BASE - 0.5
wz = BASE + 0.1 + wall_h / 2
b.box((W - 0.2, 0.18, wall_h), (0, HY - 0.1, wz), M_PLASTER, 0.01)
b.box((0.18, D - 0.2, wall_h), (-HX + 0.1, 0, wz), M_PLASTER, 0.01)
b.box((0.18, D - 0.2, wall_h), (HX - 0.1, 0, wz), M_PLASTER, 0.01)
# 앞면: 가운데 칸 큰 문, 양쪽 칸 창 + 회벽
b.box((W - 0.2, 0.16, wall_h), (0, -HY + 0.25, wz), M_PLASTER, 0.01)
for y in (-HY + 0.12, HY + 0.02):
    b.box((W, 0.16, 0.16), (0, y - 0.02, BASE + 0.12), M_DWOOD, 0.015)
    b.box((W, 0.16, 0.14), (0, y - 0.02, BASE + 0.1 + wall_h * 0.62), M_WOOD, 0.015)
for x in (-HX - 0.02, HX + 0.02):
    b.box((0.16, D, 0.14), (x, 0, BASE + 0.1 + wall_h * 0.62), M_WOOD, 0.015)
door_h = wall_h * 0.6
for i in range(3):
    cx = (xs[i] + xs[i + 1]) / 2
    bw = xs[i + 1] - xs[i] - 0.4
    if i == 1:
        for sx in (-0.25, 0.25):
            b.lattice_door(cx + sx * bw, BASE + 0.2 + door_h / 2, bw * 0.48, door_h, -HY + 0.12, 0.0, M_PAPER, M_DWOOD, M_WOOD)
    else:
        b.lattice_door(cx, BASE + 0.2 + wall_h * 0.35, bw * 0.7, wall_h * 0.38, -HY + 0.12, 0.0, M_PAPER, M_DWOOD, M_WOOD, panel=False)
for sx in (-1, 1):
    b.lattice_door(sx * (HX + 0.02), BASE + 0.2 + wall_h * 0.38, 1.2, wall_h * 0.36, 0, sx * math.pi / 2, M_PAPER, M_DWOOD, M_WOOD, panel=False)

# ---------- 툇마루 ----------
n = 18
pw = (W - 0.3) / n
for i in range(n):
    b.box((pw - 0.03, 0.95, 0.09), (-HX + 0.15 + pw * (i + 0.5), -HY - 0.2, BASE + 0.12), M_PLANK, 0.01)

# ---------- 도리, 창방, 단청 공포 ----------
for y in (-HY, HY):
    b.box((W + 0.5, 0.26, 0.3), (0, y, TOP - 0.15), M_PAINT, 0.02)
    b.box((W + 0.5, 0.22, 0.08), (0, y, TOP - 0.34), M_RED, 0.01)
    b.cyl(0.18, W + 1.0, (0, y, TOP + 0.12), M_WOOD, rot=(0, math.pi / 2, 0), verts=12)
for x in (-HX, HX):
    b.box((0.26, D + 0.5, 0.3), (x, 0, TOP - 0.15), M_PAINT, 0.02)
for y in (-HY, HY):
    for x in xs:
        b.box((0.42, 0.42, 0.22), (x, y, TOP + 0.02), M_PAINT, 0.03)
        b.box((0.3, 0.6, 0.12), (x, y, TOP - 0.05), M_RED, 0.02)

# ---------- 기와지붕 ----------
RX, RZ = HX + 1.3, HY + 1.25
RH = H * 0.62
LIFT = 0.65
ROOF_Z = TOP + 0.3
NZ = 12
STEP = RZ / NZ
NXH = int(math.ceil(RX / STEP))
RXX = NXH * STEP
RIDGE = max(RXX - RZ, STEP)

def roof_h(x, y):
    ax = abs(x)
    dz = abs(y) / RZ
    dx = min(1.0, max(0.0, (ax - RIDGE) / (RXX - RIDGE)))
    d = max(dz, dx)
    h = RH * (1 - d) ** 1.55
    h += LIFT * ((ax / RXX) * dz) ** 2
    h += LIFT * 0.35 * (ax / RXX) ** 4 * d
    return ROOF_Z + h

bm = bmesh.new()
grid = []
for iz in range(-NZ, NZ + 1):
    row = []
    for ix in range(-NXH, NXH + 1):
        x, y = ix * STEP, iz * STEP
        row.append(bm.verts.new((x, y, roof_h(x, y))))
    grid.append(row)
for iz in range(len(grid) - 1):
    for ix in range(len(grid[0]) - 1):
        bm.faces.new((grid[iz][ix], grid[iz][ix + 1], grid[iz + 1][ix + 1], grid[iz + 1][ix]))
# 처마 두께
edge = [grid[0][i] for i in range(len(grid[0]))] + [grid[j][-1] for j in range(1, len(grid))] + \
       [grid[-1][i] for i in range(len(grid[0]) - 2, -1, -1)] + [grid[j][0] for j in range(len(grid) - 2, 0, -1)]
low = [bm.verts.new((v.co.x * 0.985, v.co.y * 0.985, v.co.z - 0.28)) for v in edge]
for i in range(len(edge)):
    j = (i + 1) % len(edge)
    bm.faces.new((edge[i], edge[j], low[j], low[i]))
me = bpy.data.meshes.new("roofbase")
bm.to_mesh(me)
ro = bpy.data.objects.new("roofbase", me)
b.scene.collection.objects.link(ro)
b.finish(ro, M_TILEB, smooth=True)

# 수키와 줄: 용마루에서 처마까지 한 줄씩
def tile_row(pts):
    b.curve(pts, 0.075, M_TILE, res=0, fill_caps=True)
    p, q = Vector(pts[-1]), Vector(pts[-2])
    d = (p - q).normalized()
    b.cyl(0.11, 0.05, tuple(p + d * 0.02), M_TILE, rot=(0, 0, 0), verts=10)
    o = b.parts[-1]
    o.rotation_mode = "QUATERNION"
    o.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(d)

TS = 0.36
x = -RXX + 0.2
while x <= RXX - 0.2:
    for side in (-1, 1):
        pts = []
        for k in range(15):
            t = k / 14
            y = side * t * RZ
            if abs(x) > RIDGE and (abs(x) - RIDGE) / (RXX - RIDGE) > t:
                continue
            pts.append((x, y, roof_h(x, y) + 0.06))
        if len(pts) > 2:
            tile_row(pts)
    x += TS
y = -RZ + 0.2
while y <= RZ - 0.2:
    for side in (-1, 1):
        pts = []
        for k in range(10):
            t = k / 9
            xx = side * (RIDGE + t * (RXX - RIDGE))
            if abs(y) / RZ > t:
                continue
            pts.append((xx, y, roof_h(xx, y) + 0.06))
        if len(pts) > 2:
            tile_row(pts)
    y += TS

# 용마루 + 하얀 줄 + 치켜든 끝
top = ROOF_Z + RH
b.box((RIDGE * 2 + 0.6, 0.7, 0.16), (0, 0, top + 0.02), M_LIME, 0.03)
b.box((RIDGE * 2 + 0.4, 0.5, 0.34), (0, 0, top + 0.24), M_TILEB, 0.06, segs=3)
b.box((RIDGE * 2 + 0.3, 0.56, 0.08), (0, 0, top + 0.43), M_TILE, 0.03)
for sx in (-1, 1):
    b.box((0.5, 0.46, 0.5), (sx * (RIDGE + 0.35), 0, top + 0.42), M_TILEB, 0.08, rot=(0, sx * 0.55, 0), segs=3)
    # 내림마루
    for sy in (-1, 1):
        prev = Vector((sx * RIDGE, 0, top + 0.12))
        pts = [tuple(prev)]
        for k in range(1, 9):
            f = k / 8
            px = sx * (RIDGE + (RXX - RIDGE) * f)
            py = sy * RZ * f
            pts.append((px, py, roof_h(px, py) + 0.16))
        b.curve(pts, 0.17, M_TILEB, res=1)
        b.curve([(p[0], p[1], p[2] + 0.1) for p in pts], 0.06, M_LIME, res=1)

# 서까래 (처마 밑 둥근 나무 끝)
x = -HX - 0.9
while x <= HX + 0.9:
    for sy in (-1, 1):
        y0, y1 = sy * (HY - 0.1), sy * (RZ - 0.25)
        b.curve([(x, y0, TOP + 0.25), (x, y1, roof_h(x, y1) - 0.2)], 0.06, M_DWOOD, res=1)
    x += 0.42

# 등롱 둘
for sx in (-1, 1):
    b.curve([(sx * 3.0, -HY - 0.5, TOP + 0.2), (sx * 3.0, -HY - 0.5, TOP - 0.55)], 0.012, M_DWOOD)
    b.blob((0.36, 0.36, 0.5), (sx * 3.0, -HY - 0.5, TOP - 0.8), M_PAPER)
    b.box((0.3, 0.3, 0.05), (sx * 3.0, -HY - 0.5, TOP - 0.53), M_DWOOD, 0.01)

o = b.join_export("Giwa", None)
b.export(OUT)
