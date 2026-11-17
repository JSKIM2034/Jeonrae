# 나무: 느티나무 같은 활엽수 2종 + 소나무 2종 -> models/trees.glb (오브젝트 4개)
import sys, math, random
sys.path.insert(0, "/home/claude/jeonrae/tools")
from blcommon import *

OUT = "/home/claude/jeonrae/source/models/trees.glb"
b = Builder()
M_BARK = b.mat("Bark", (0.42, 0.29, 0.18))
M_BARKR = b.mat("BarkRed", (0.6, 0.35, 0.22))
M_LEAF = b.mat("Leaf", (0.4, 0.62, 0.3))
M_NEEDLE = b.mat("Needle", (0.25, 0.45, 0.28))

def lumpy(size, loc, m, rnd, strength=0.3, subdiv=3):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdiv, radius=1.0, location=loc)
    o = bpy.context.object
    o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    tex = bpy.data.textures.new("n", "CLOUDS")
    tex.noise_scale = 0.38
    md = o.modifiers.new("d", "DISPLACE")
    md.texture = tex
    md.strength = strength
    md.texture_coords = "GLOBAL"
    o.location.x += 0  # 텍스처 위치를 덩어리마다 다르게
    tex.noise_basis = "ORIGINAL_PERLIN"
    md.mid_level = 0.5
    bpy.ops.object.modifier_apply(modifier="d")
    return b.finish(o, m, smooth=True)

def branch(start, direction, length, r0, r1, rnd, bend=0.25, n=7, m=None):
    pts, radii = [], []
    d = Vector(direction).normalized()
    p = Vector(start)
    for i in range(n):
        t = i / (n - 1)
        pts.append(tuple(p))
        radii.append((1 - t) * 1.0 + t * (r1 / r0))
        jitter = Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-0.2, 0.4))) * bend
        d = (d + jitter * 0.35).normalized()
        p = p + d * (length / (n - 1))
    return b.curve(pts, r0, m or M_BARK, res=2, radii=radii), Vector(pts[-1])

def broadleaf(name, ox, seed):
    rnd = random.Random(seed)
    start = len(b.parts)
    trunk, top = branch((ox, 0, -0.1), (0.08, 0.05, 1), 2.6, 0.32, 0.18, rnd, bend=0.12, n=8)
    # 뿌리 부분 불룩
    for k in range(4):
        a = k * math.pi / 2 + rnd.uniform(-0.3, 0.3)
        branch((ox + math.cos(a) * 0.15, math.sin(a) * 0.15, 0.25), (math.cos(a), math.sin(a), -0.6), 0.5, 0.14, 0.05, rnd, bend=0.05, n=3)
    tips = [top]
    for k in range(4):
        a = k * math.pi * 2 / 4 + rnd.uniform(-0.4, 0.4)
        s = Vector((ox, 0, 0)) + (top - Vector((ox, 0, 0))) * rnd.uniform(0.62, 0.85)
        _, tip = branch(tuple(s), (math.cos(a), math.sin(a), 0.9), rnd.uniform(1.2, 1.7), 0.13, 0.05, rnd, bend=0.2, n=5)
        tips.append(tip)
    leaves = []
    for tip in tips:
        for j in range(2):
            c = tip + Vector((rnd.uniform(-0.4, 0.4), rnd.uniform(-0.4, 0.4), rnd.uniform(0.0, 0.5)))
            r = rnd.uniform(0.85, 1.25)
            leaves.append(lumpy((r * 1.15, r * 1.15, r * 0.85), tuple(c), M_LEAF, rnd))
    leaves.append(lumpy((1.5, 1.5, 1.1), tuple(top + Vector((0, 0, 0.6))), M_LEAF, rnd))
    for lf in leaves:
        tint = rnd.uniform(-0.04, 0.05)
        def col(co, n, tint=tint):
            up = max(0.0, min(1.0, (co.z - 2.2) / 3.0))
            side = 0.5 + 0.5 * n.z
            g = 0.42 + 0.3 * up * 0.6 + 0.18 * side
            return (0.24 + tint + 0.2 * up + 0.1 * side, g + tint, 0.18 + 0.06 * up)
        paint_vertex_colors(lf, col)
    objs = b.parts[start:]
    for ob in objs:
        if "Col" not in ob.data.color_attributes:
            paint_vertex_colors(ob, lambda co, n: (0.5, 0.35, 0.22))
    o = b.join_export(name, None, objs)
    o.location.x -= ox
    bpy.ops.object.transform_apply(location=True)
    b.parts = b.parts[:start]
    return o

def pine(name, ox, seed):
    rnd = random.Random(seed)
    start = len(b.parts)
    # 구불구불한 붉은 줄기
    pts, radii = [], []
    p = Vector((ox, 0, -0.1))
    d = Vector((0.15, 0, 1)).normalized()
    for i in range(10):
        t = i / 9
        pts.append(tuple(p))
        radii.append(1 - 0.6 * t)
        d = (d + Vector((math.sin(i * 1.3 + seed) * 0.35, math.cos(i * 0.9 + seed) * 0.2, 0.25))).normalized()
        p = p + d * 0.45
    b.curve(pts, 0.26, M_BARKR, res=2, radii=radii)
    top = Vector(pts[-1])
    pads = []
    for k in range(5):
        t = 0.45 + k * 0.12
        s = Vector(pts[int(t * 9)])
        a = k * 2.3 + rnd.uniform(-0.3, 0.3)
        _, tip = branch(tuple(s), (math.cos(a), math.sin(a), 0.35), rnd.uniform(0.9, 1.5), 0.09, 0.04, rnd, bend=0.15, n=4, m=M_BARKR)
        pads.append(tip)
    pads.append(top)
    for tip in pads:
        r = rnd.uniform(0.95, 1.35)
        pad = lumpy((r * 1.3, r * 1.2, r * 0.42), tuple(tip + Vector((0, 0, 0.12))), M_NEEDLE, rnd, strength=0.14)
        def col(co, n):
            side = 0.5 + 0.5 * n.z
            return (0.14 + 0.12 * side, 0.32 + 0.2 * side, 0.2 + 0.06 * side)
        paint_vertex_colors(pad, col)
    objs = b.parts[start:]
    for ob in objs:
        if "Col" not in ob.data.color_attributes:
            paint_vertex_colors(ob, lambda co, n: (0.5, 0.35, 0.22))
    o = b.join_export(name, None, objs)
    o.location.x -= ox
    bpy.ops.object.transform_apply(location=True)
    b.parts = b.parts[:start]
    return o

broadleaf("Broad0", 0, 3)
broadleaf("Broad1", 10, 11)
pine("Pine0", 20, 5)
pine("Pine1", 30, 9)
b.export(OUT)
