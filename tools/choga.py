# 흥부네 초가집 (블렌더 5.x, 화면 없이 실행: python3 choga.py)
# 앞쪽이 블렌더의 -Y (게임에서는 +Z), 바닥이 z=0, 몸채 크기 4.5 x 3.5, 벽 높이 2.8
import bpy, bmesh, math, random
from mathutils import Vector, Matrix

OUT = "/home/claude/jeonrae/source/models/choga.glb"
W, D, H = 4.5, 3.5, 2.8
BASE = 0.32
HX, HY = W / 2, D / 2
rnd = random.Random(7)

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

MATS = {}
def mat(name, col):
    if name not in MATS:
        m = bpy.data.materials.new(name)
        m.diffuse_color = (*col, 1.0)
        m.use_nodes = True
        m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*col, 1.0)
        MATS[name] = m
    return MATS[name]

M_THATCH = mat("Thatch", (0.9, 0.75, 0.42))
M_THATCHD = mat("ThatchDark", (0.75, 0.6, 0.35))
M_PLASTER = mat("Plaster", (0.93, 0.89, 0.8))
M_WOOD = mat("Wood", (0.6, 0.4, 0.25))
M_DWOOD = mat("DarkWood", (0.42, 0.27, 0.16))
M_PLANK = mat("Plank", (0.75, 0.55, 0.35))
M_PAPER = mat("Paper", (0.98, 0.95, 0.86))
M_STONE = mat("Stone", (0.7, 0.68, 0.64))
M_ROPE = mat("Rope", (0.5, 0.37, 0.2))
M_CLAY = mat("Clay", (0.62, 0.5, 0.38))
M_STRAW = mat("Straw", (0.86, 0.72, 0.42))

parts = []

def finish(obj, m, bevel=0.0, segs=2, smooth=False):
    obj.data.materials.append(m)
    if bevel > 0:
        md = obj.modifiers.new("bev", "BEVEL")
        md.width = bevel
        md.segments = segs
        md.limit_method = "NONE"
    if smooth:
        for p in obj.data.polygons:
            p.use_smooth = True
    parts.append(obj)
    return obj

def box(size, loc, m, bevel=0.015, rot=(0, 0, 0), segs=2):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    o = bpy.context.object
    o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    return finish(o, m, bevel, segs, smooth=segs > 2)

def cyl(r, depth, loc, m, rot=(0, 0, 0), verts=12, r2=None, bevel=0.0):
    if r2 is None:
        bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=depth, location=loc, rotation=rot, vertices=verts)
    else:
        bpy.ops.mesh.primitive_cone_add(radius1=r, radius2=r2, depth=depth, location=loc, rotation=rot, vertices=verts)
    o = bpy.context.object
    return finish(o, m, bevel, 2, smooth=True)

def blob(size, loc, m, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.5, location=loc, rotation=rot, segments=12, ring_count=8)
    o = bpy.context.object
    o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    return finish(o, m, 0, 2, smooth=True)

def curve_line(points, radius, m, res=6):
    cu = bpy.data.curves.new("rope", "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = radius
    cu.bevel_resolution = 1
    sp = cu.splines.new("POLY")
    sp.points.add(len(points) - 1)
    for i, p in enumerate(points):
        sp.points[i].co = (p[0], p[1], p[2], 1)
    o = bpy.data.objects.new("rope", cu)
    scene.collection.objects.link(o)
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    bpy.ops.object.convert(target="MESH")
    o = bpy.context.object
    return finish(o, m, 0, 2, smooth=True)

# ---------- 기단과 주춧돌 ----------
box((W + 0.55, D + 0.55, BASE), (0, 0, BASE / 2), M_STONE, 0.04, segs=3)
x = -HX - 0.28
while x < HX + 0.25:
    w = rnd.uniform(0.38, 0.62)
    box((w, 0.26, BASE * rnd.uniform(0.85, 1.0)), (x + w / 2, -HY - 0.2, BASE * 0.45), M_STONE, 0.07, rot=(0, 0, rnd.uniform(-0.05, 0.05)), segs=3)
    x += w + 0.02

POSTS_F = [-HX, 0.0, HX]
for px in POSTS_F:
    cyl(0.2, 0.12, (px, -HY, BASE + 0.06), M_STONE, verts=10, r2=0.16)
for px in (-HX, HX):
    cyl(0.2, 0.12, (px, HY, BASE + 0.06), M_STONE, verts=10, r2=0.16)

# ---------- 기둥, 벽, 도리 ----------
TOP = H
for px in POSTS_F:
    box((0.22, 0.22, TOP - BASE - 0.12), (px, -HY, (TOP + BASE + 0.12) / 2), M_WOOD, 0.025)
for px in (-HX, HX):
    box((0.22, 0.22, TOP - BASE - 0.12), (px, HY, (TOP + BASE + 0.12) / 2), M_WOOD, 0.025)
wall_h = TOP - BASE - 0.2
wz = BASE + 0.08 + wall_h / 2
# 앞 벽은 문 둘레만, 옆/뒤는 회벽에 나무 띠
box((W - 0.1, 0.16, wall_h), (0, -HY + 0.1, wz), M_PLASTER, 0.01)
box((W - 0.1, 0.16, wall_h), (0, HY - 0.1, wz), M_PLASTER, 0.01)
box((0.16, D - 0.1, wall_h), (-HX + 0.1, 0, wz), M_PLASTER, 0.01)
box((0.16, D - 0.1, wall_h), (HX - 0.1, 0, wz), M_PLASTER, 0.01)
for sx in (-1, 1):
    box((0.2, D - 0.2, 0.12), (sx * (HX + 0.02), 0, BASE + 1.3), M_WOOD, 0.015)
    box((0.08, 0.14, wall_h), (sx * (HX + 0.06), 0, wz), M_WOOD, 0.01)
box((W - 0.2, 0.2, 0.12), (0, HY + 0.02, BASE + 1.3), M_WOOD, 0.015)
# 도리 (둥근 나무)
for y in (-HY, HY):
    cyl(0.14, W + 0.5, (0, y, TOP - 0.1), M_WOOD, rot=(0, math.pi / 2, 0), verts=12)
for x in (-HX, HX):
    cyl(0.12, D + 0.3, (x, 0, TOP - 0.1), M_WOOD, rot=(math.pi / 2, 0, 0), verts=12)
# 하방 (문 아래 가로 나무)
box((W, 0.2, 0.14), (0, -HY - 0.02, BASE + 0.08), M_DWOOD, 0.02)

# ---------- 문: 창호지 + 격자 문살 ----------
def lattice_door(cx, cz, w, h, y, rot_z=0.0):
    rm = Matrix.Rotation(rot_z, 4, "Z")
    def P(lx, ly, lz):
        v = rm @ Vector((lx, ly, lz))
        return (cx + v.x, y + v.y, cz + v.z) if rot_z == 0 else (v.x + cx, v.y + y, cz + v.z)
    box((w, 0.02, h), P(0, -0.0, 0), M_PAPER, 0.0, rot=(0, 0, rot_z))
    f = 0.07
    for dz in (h / 2 + f / 2, -h / 2 - f / 2):
        box((w + 2 * f, 0.09, f), P(0, -0.03, dz), M_DWOOD, 0.01, rot=(0, 0, rot_z))
    for dx in (w / 2 + f / 2, -w / 2 - f / 2):
        box((f, 0.09, h), P(dx, -0.03, 0), M_DWOOD, 0.01, rot=(0, 0, rot_z))
    n = max(2, int(w / 0.16))
    for i in range(1, n):
        box((0.022, 0.04, h), P(-w / 2 + w * i / n, -0.025, 0), M_DWOOD, 0.0, rot=(0, 0, rot_z))
    m = max(2, int(h / 0.16))
    for j in range(1, m):
        if j < m * 0.2:
            continue
        box((w, 0.04, 0.022), P(0, -0.025, -h / 2 + h * j / m), M_DWOOD, 0.0, rot=(0, 0, rot_z))
    # 아래 나무판
    box((w, 0.05, h * 0.2), P(0, -0.02, -h / 2 + h * 0.1), M_WOOD, 0.008, rot=(0, 0, rot_z))

door_h = 1.75
for bx in (-HX / 2, HX / 2):
    lattice_door(bx, BASE + 0.16 + door_h / 2, 1.3, door_h, -HY - 0.02)
    # 문고리
    cyl(0.035, 0.03, (bx + (0.5 if bx < 0 else -0.5), -HY - 0.1, BASE + 0.16 + door_h * 0.5), M_DWOOD, rot=(math.pi / 2, 0, 0), verts=10)
# 옆 창
for sx in (-1, 1):
    lattice_door(sx * (HX + 0.03), BASE + 1.55, 0.8, 0.62, 0.6, rot_z=sx * math.pi / 2)

# ---------- 툇마루, 댓돌, 짚신 ----------
MY0 = -HY - 0.12
MD = 0.95
MZ = BASE + 0.1
n = 9
pw = (W - 0.2) / n
for i in range(n):
    box((pw - 0.025, MD, 0.08), (-HX + 0.1 + pw * (i + 0.5), MY0 - MD / 2, MZ), M_PLANK, 0.01)
box((W - 0.1, 0.1, 0.1), (0, MY0 - MD + 0.05, MZ - 0.08), M_DWOOD, 0.015)
for lx in (-HX + 0.2, 0, HX - 0.2):
    box((0.12, 0.12, MZ), (lx, MY0 - MD + 0.12, MZ / 2), M_DWOOD, 0.012)
box((1.3, 0.62, 0.2), (0.2, MY0 - MD - 0.4, 0.1), M_STONE, 0.07, segs=3)
for sx in (-0.07, 0.11):
    blob((0.14, 0.3, 0.08), (0.25 + sx, MY0 - MD - 0.42, 0.23), M_STRAW)

# ---------- 굴뚝 (오른쪽 뒤) ----------
for i in range(5):
    r = 0.34 - i * 0.03
    blob((r * 2, r * 2, 0.32), (HX + 0.75, HY - 0.3, 0.16 + i * 0.27), M_CLAY)
cyl(0.16, 0.5, (HX + 0.75, HY - 0.3, 1.55), M_CLAY, verts=10, r2=0.13)
blob((0.5, 0.5, 0.18), (HX + 0.75, HY - 0.3, 1.82), M_THATCHD)

# ---------- 초가지붕 ----------
RX, RY = HX + 0.95, HY + 0.95
RH = H * 0.58 + 0.3
ROOF_Z = TOP - 0.04
NA, NT = 64, 22
BANDS = 5

def boundary(th):
    c, s = math.cos(th), math.sin(th)
    return RX * math.copysign(abs(c) ** 0.6, c), RY * math.copysign(abs(s) ** 0.6, s)

def roof_point(th, t):
    bx, by = boundary(th)
    z = RH * (max(0.0, math.cos(t * math.pi * 0.5)) ** 0.62)
    # 이엉을 층층이 덮은 모양: 띠마다 아래쪽 끝이 살짝 부풀어요
    band = (t * BANDS) % 1.0
    puff = 0.07 * band ** 2 * (1.0 if t < 0.97 else 0.0)
    out = Vector((bx * t, by * t, 0)).normalized() if t > 0.01 else Vector((0, 0, 0))
    return Vector((bx * t, by * t, ROOF_Z + z)) + out * puff + Vector((0, 0, puff * 0.5))

bm = bmesh.new()
uv_layer = bm.loops.layers.uv.new("UVMap")
rows = []
URE = max(2.0, round((RX + RY) * 1.15))
VRE = (max(RX, RY) + RH) / 2.2
for it in range(NT + 3):
    row = []
    for ia in range(NA + 1):
        th = 2 * math.pi * ia / NA
        if it <= NT:
            t = it / NT
            p = roof_point(th, t)
            v = t * VRE
        elif it == NT + 1:
            bx, by = boundary(th)
            p = Vector((bx * 1.03, by * 1.03, ROOF_Z - 0.12))
            v = VRE + 0.06
        else:
            bx, by = boundary(th)
            p = Vector((bx * 0.95, by * 0.95, ROOF_Z - 0.3))
            v = VRE + 0.12
        row.append((bm.verts.new(p), (ia / NA * URE, v)))
    rows.append(row)
for it in range(len(rows) - 1):
    for ia in range(NA):
        a, b = rows[it][ia], rows[it][ia + 1]
        c, d = rows[it + 1][ia], rows[it + 1][ia + 1]
        try:
            f = bm.faces.new((a[0], c[0], d[0], b[0]))
        except ValueError:
            continue
        for loop, src in zip(f.loops, (a, c, d, b)):
            loop[uv_layer].uv = src[1]
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0001)
me = bpy.data.meshes.new("roof")
bm.to_mesh(me)
roof = bpy.data.objects.new("roof", me)
scene.collection.objects.link(roof)
bpy.context.view_layer.objects.active = roof
tex = bpy.data.textures.new("lump", "CLOUDS")
tex.noise_scale = 0.35
dm = roof.modifiers.new("lump", "DISPLACE")
dm.texture = tex
dm.strength = 0.07
dm.mid_level = 0.5
finish(roof, M_THATCH, smooth=True)

# 용마름: 꼭대기를 덮은 짚 두루마리 + 엇갈려 엮은 짚 다발
RLEN = RX * 1.05
cyl(0.24, RLEN, (0, 0, ROOF_Z + RH + 0.02), M_THATCHD, rot=(0, math.pi / 2, 0), verts=14)
k = 0
x = -RLEN / 2 + 0.08
while x < RLEN / 2:
    side = 1 if k % 2 == 0 else -1
    blob((0.13, 0.42, 0.12), (x, side * 0.12, ROOF_Z + RH + 0.12), M_THATCHD, rot=(side * 0.6, 0, 0.5))
    x += 0.15
    k += 1
for sx in (-1, 1):
    blob((0.34, 0.5, 0.46), (sx * RLEN / 2, 0, ROOF_Z + RH - 0.02), M_THATCHD)

# 새끼줄 그물: 위에서 처마로 내려오는 줄 + 가로 줄 두 개
def surf(th, t, lift=0.035):
    p = roof_point(th, t)
    n = (p - Vector((0, 0, ROOF_Z))).normalized()
    return p + n * lift
for i in range(18):
    th = 2 * math.pi * (i + 0.5) / 18
    pts = [surf(th, t) for t in [0.18 + 0.8 * j / 20 for j in range(21)]]
    curve_line(pts, 0.022, M_ROPE)
for t in (0.45, 0.72):
    pts = [surf(2 * math.pi * j / 80, t) for j in range(81)]
    curve_line(pts, 0.024, M_ROPE)

# ---------- 살림살이: 처마에 매단 메주, 벽에 건 망태 ----------
for i, x in enumerate((-1.55, -1.2)):
    curve_line([(x, -HY - 0.35, TOP - 0.05), (x, -HY - 0.35, TOP - 0.45)], 0.012, M_ROPE)
    box((0.2, 0.16, 0.24), (x, -HY - 0.35, TOP - 0.58), M_CLAY, 0.06, segs=3)
blob((0.42, 0.2, 0.36), (HX - 0.6, -HY - 0.14, BASE + 1.15), M_STRAW)

# ---------- 합치고 내보내기 ----------
bpy.ops.object.select_all(action="DESELECT")
for o in parts:
    o.select_set(True)
bpy.context.view_layer.objects.active = parts[0]
bpy.ops.object.convert(target="MESH")
bpy.ops.object.join()
obj = bpy.context.object
obj.name = "Choga"
tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
print("triangles:", tris, "materials:", [m.name for m in obj.data.materials])
bpy.ops.export_scene.gltf(filepath=OUT, export_apply=True, export_yup=True, export_texcoords=True, export_normals=True, export_materials="EXPORT")
print("saved", OUT)
