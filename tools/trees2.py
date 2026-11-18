# 잎 카드로 만든 나무: 활엽수 2종, 소나무 2종, 버드나무 1종 -> models/trees.glb
# 잎은 textures/leaves.png(2x2 그림 모음)의 칸을 써요. 잎 카드의 법선은 수관 중심에서 바깥으로 향하게 해서 둥글고 부드럽게 빛을 받아요
import sys, math, random
sys.path.insert(0, "/home/claude/jeonrae/tools")
from blcommon import *
import bmesh
from mathutils import Vector

OUT = sys.argv[-1] if sys.argv[-1].endswith(".glb") else "/home/claude/jeonrae/source/models/trees.glb"
b = Builder()
M_BARK = b.mat("Bark", (0.42, 0.29, 0.18))
M_BARKR = b.mat("BarkRed", (0.6, 0.35, 0.22))
M_LEAF = b.mat("Leaf", (0.4, 0.62, 0.3))
UV = {"broad": (0.0, 0.5, 0.5, 1.0), "pine": (0.5, 0.5, 1.0, 1.0), "willow": (0.0, 0.0, 0.5, 0.5), "light": (0.5, 0.0, 1.0, 0.5)}

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
    o = b.curve(pts, r0, m or M_BARK, res=2, radii=radii)
    return o, Vector(pts[-1]), [Vector(q) for q in pts]

class Cards:
    """잎 카드들을 한 메시에 모아요"""
    def __init__(self, name):
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new("UVMap")
        self.col = self.bm.loops.layers.float_color.new("Col")
        self.nrm = {}   # vert -> 바깥 방향 법선

    def quad(self, corners, region, colr, normal, uvs=None):
        vs = [self.bm.verts.new(c) for c in corners]
        f = self.bm.faces.new(vs)
        u0, v0, u1, v1 = UV[region]
        pad = 0.01
        uvs = uvs or [(u0 + pad, v0 + pad), (u1 - pad, v0 + pad), (u1 - pad, v1 - pad), (u0 + pad, v1 - pad)]
        for loop, uv in zip(f.loops, uvs):
            loop[self.uv].uv = uv
            loop[self.col] = (*colr, 1.0)
        for v in vs:
            self.nrm[v] = normal
        return f

    def card(self, center, size, outward, region, colr, rnd, up_bias=0.0, soft_center=None):
        n = (outward.normalized() + Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-1, 1) + up_bias)) * 0.9).normalized()
        ref = Vector((0, 0, 1)) if abs(n.z) < 0.9 else Vector((1, 0, 0))
        t = n.cross(ref).normalized()
        bb = n.cross(t).normalized()
        a = rnd.uniform(0, 2 * math.pi)
        t, bb = t * math.cos(a) + bb * math.sin(a), -t * math.sin(a) + bb * math.cos(a)
        h = size / 2
        c = Vector(center)
        corners = [c - t * h - bb * h, c + t * h - bb * h, c + t * h + bb * h, c - t * h + bb * h]
        nn = (outward.normalized() * 0.8 + Vector((0, 0, 0.35))).normalized()
        self.quad(corners, region, colr, nn)

    def blob(self, center, size, region, colr, subdiv=1):
        """수관 속을 채우는 어두운 덩어리 (구멍 사이로 하늘이 덜 보이게)"""
        u0, v0, u1, v1 = UV[region]
        cu, cv = (u0 + u1) / 2, (v0 + v1) / 2
        tmp = bmesh.new()
        bmesh.ops.create_icosphere(tmp, subdivisions=subdiv, radius=1.0)
        vmap = {}
        for v in tmp.verts:
            p = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2])) + Vector(center)
            nv = self.bm.verts.new(p)
            vmap[v] = nv
            self.nrm[nv] = (v.co.normalized() + Vector((0, 0, 0.3))).normalized()
        for f in tmp.faces:
            nf = self.bm.faces.new([vmap[v] for v in f.verts])
            for loop in nf.loops:
                loop[self.uv].uv = (cu, cv)
                loop[self.col] = (*colr, 1.0)
        tmp.free()

    def finish(self, name):
        me = bpy.data.meshes.new(name)
        verts = list(self.bm.verts)
        self.bm.verts.index_update()
        normals = [self.nrm.get(v, Vector((0, 0, 1))) for v in verts]
        self.bm.to_mesh(me)
        me.normals_split_custom_set_from_vertices([tuple(n) for n in normals])
        o = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(o)
        me.materials.append(M_LEAF)
        b.parts.append(o)
        return o

def leaf_col(rnd, base, p, center, radius):
    out = min(1.0, (p - center).length / radius)
    up = max(0.0, min(1.0, (p.z - center.z) / radius * 0.5 + 0.5))
    k = 0.55 + 0.3 * out + 0.25 * up
    return tuple(min(1.0, c * k * rnd.uniform(0.92, 1.08)) for c in base)

def paint_bark(objs, c):
    for ob in objs:
        if ob.type == "MESH" and "Col" not in ob.data.color_attributes:
            paint_vertex_colors(ob, lambda co, n: c)

def finish_tree(name, start, ox):
    objs = b.parts[start:]
    paint_bark(objs, (1.0, 1.0, 1.0))
    o = b.join_export(name, None, objs)
    o.location.x -= ox
    bpy.ops.object.transform_apply(location=True)
    b.parts = b.parts[:start]
    return o

def broadleaf(name, ox, seed, light=False):
    rnd = random.Random(seed)
    start = len(b.parts)
    _, top, tpts = branch((ox, 0, -0.1), (0.08, 0.05, 1), 2.5, 0.3, 0.17, rnd, bend=0.12, n=8)
    for k in range(4):
        a = k * math.pi / 2 + rnd.uniform(-0.3, 0.3)
        branch((ox + math.cos(a) * 0.15, math.sin(a) * 0.15, 0.25), (math.cos(a), math.sin(a), -0.6), 0.5, 0.13, 0.05, rnd, bend=0.05, n=3)
    tips = [top]
    for k in range(5):
        a = k * math.pi * 2 / 5 + rnd.uniform(-0.4, 0.4)
        s = tpts[rnd.randint(4, 6)]
        _, tip, _ = branch(tuple(s), (math.cos(a), math.sin(a), 0.8), rnd.uniform(1.2, 1.7), 0.12, 0.04, rnd, bend=0.2, n=5)
        tips.append(tip)
    center = top + Vector((0, 0, 0.5))
    R = 2.0
    cards = Cards(name + "_leaf")
    base = (0.62, 0.86, 0.5) if light else (0.55, 0.78, 0.48)
    for tip in tips:
        cards.blob(tuple(tip + Vector((0, 0, 0.15))), (0.55, 0.55, 0.45), "broad", (0.3, 0.42, 0.26))
    for tip in tips:
        for j in range(26):
            p = tip + Vector((rnd.uniform(-0.85, 0.85), rnd.uniform(-0.85, 0.85), rnd.uniform(-0.45, 0.7)))
            region = "light" if (light or rnd.random() < 0.3) else "broad"
            cards.card(p, rnd.uniform(0.75, 1.05), p - center, region, leaf_col(rnd, base, p, center, R), rnd, up_bias=0.4)
    cards.finish(name + "_leaf")
    paint_bark(b.parts[start:], (1.0, 1.0, 1.0))
    return finish_tree(name, start, ox)

def pine(name, ox, seed):
    rnd = random.Random(seed)
    start = len(b.parts)
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
        _, tip, _ = branch(tuple(s), (math.cos(a), math.sin(a), 0.35), rnd.uniform(0.9, 1.5), 0.09, 0.04, rnd, bend=0.15, n=4, m=M_BARKR)
        pads.append(tip)
    pads.append(top)
    cards = Cards(name + "_leaf")
    for tip in pads:
        c0 = tip + Vector((0, 0, 0.12))
        cards.blob(tuple(c0), (0.75, 0.7, 0.22), "pine", (0.22, 0.32, 0.22))
        for j in range(24):
            off = Vector((rnd.uniform(-0.85, 0.85), rnd.uniform(-0.8, 0.8), rnd.uniform(-0.12, 0.2)))
            q = c0 + off
            col = tuple(min(1.0, c * (0.6 + 0.4 * (off.z + 0.12) / 0.32) * rnd.uniform(0.9, 1.1)) for c in (0.7, 0.85, 0.72))
            cards.card(q, rnd.uniform(0.6, 0.85), Vector((off.x, off.y, 0.0)) * 0.6 + Vector((0, 0, 1.0)), "pine", col, rnd, up_bias=0.6)
    cards.finish(name + "_leaf")
    return finish_tree(name, start, ox)

def willow(name, ox, seed):
    rnd = random.Random(seed)
    start = len(b.parts)
    _, top, tpts = branch((ox, 0, -0.1), (0.1, 0.0, 1), 2.8, 0.32, 0.18, rnd, bend=0.15, n=8)
    tips = []
    for k in range(7):
        a = k * math.pi * 2 / 7 + rnd.uniform(-0.3, 0.3)
        s = tpts[rnd.randint(5, 7)]
        _, tip, _ = branch(tuple(s), (math.cos(a), math.sin(a), 0.55), rnd.uniform(1.3, 1.8), 0.1, 0.035, rnd, bend=0.15, n=5)
        tips.append(tip)
    center = top + Vector((0, 0, 0.4))
    cards = Cards(name + "_leaf")
    cards.blob(tuple(center), (0.95, 0.95, 0.45), "light", (0.5, 0.62, 0.36), subdiv=2)
    for tip in tips + [top]:
        for j in range(16):
            p = tip + Vector((rnd.uniform(-0.6, 0.6), rnd.uniform(-0.6, 0.6), rnd.uniform(-0.2, 0.35)))
            cards.card(p, rnd.uniform(0.7, 0.95), p - center, "light", leaf_col(rnd, (0.7, 0.86, 0.5), p, center, 2.0), rnd, up_bias=0.5)
    # 늘어진 가지: 세로로 긴 카드
    for k in range(46):
        a = rnd.uniform(0, 2 * math.pi)
        r = rnd.uniform(1.1, 2.2)
        topz = center.z + rnd.uniform(-0.3, 0.3) - (r - 1.1) * 0.35
        ln = rnd.uniform(1.6, 2.4)
        w = 0.55
        out = Vector((math.cos(a), math.sin(a), 0))
        side = Vector((-math.sin(a), math.cos(a), 0)) * (w / 2)
        tw = rnd.uniform(-0.6, 0.6)
        side = side * math.cos(tw) + out * (w / 2) * math.sin(tw)
        base = Vector((ox, 0, 0)) + out * r
        tp = Vector((base.x, base.y, topz))
        bt = tp + Vector((0, 0, -ln)) + out * 0.15
        col = tuple(min(1.0, c * rnd.uniform(0.8, 1.05)) for c in (0.8, 0.9, 0.62))
        u0, v0, u1, v1 = UV["willow"]
        us = rnd.choice([0.0, 0.1, 0.2, 0.3])
        uvs = [(u0 + us, v0), (u0 + us + 0.11, v0), (u0 + us + 0.11, v1), (u0 + us, v1)]
        cards.quad([bt - side, bt + side, tp + side, tp - side], "willow", col, (out * 0.8 + Vector((0, 0, 0.3))).normalized(), uvs)
    cards.finish(name + "_leaf")
    return finish_tree(name, start, ox)

broadleaf("Broad0", 0, 3)
broadleaf("Broad1", 10, 11, light=True)
pine("Pine0", 20, 5)
pine("Pine1", 30, 9)
willow("Willow0", 40, 7)
b.export(OUT)
