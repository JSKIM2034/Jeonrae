# 등장인물 (블렌더). 키 2 (발 z=-1, 정수리 z=+1), 앞쪽 = -Y.
# 인물마다 빈 오브젝트 Char_<종류> 아래에 Body, Eyes, ArmL, ArmR, LegL, LegR 를 두어요.
# 팔다리의 원점은 어깨/엉덩이 관절이라 게임에서 돌리면 걷는 것처럼 움직여요.
import sys, math, random
sys.path.insert(0, "/home/claude/jeonrae/tools")
from blcommon import *

OUT = "/home/claude/jeonrae/source/models/characters.glb"
b = Builder()
MATC = {}
def M(name, col, rough=0.8):
    if name not in MATC:
        m = bpy.data.materials.new(name)
        m.diffuse_color = (*col, 1.0)
        if m.node_tree:
            bsdf = m.node_tree.nodes.get("Principled BSDF")
            if bsdf:
                bsdf.inputs["Base Color"].default_value = (*col, 1.0)
                bsdf.inputs["Roughness"].default_value = rough
        MATC[name] = m
    return MATC[name]

def srgb(c):
    return tuple(((x + 0.055) / 1.055) ** 2.4 if x > 0.04045 else x / 12.92 for x in c)

def C(name, col, rough=0.8):
    return M(name, srgb(col), rough)

SKIN = C("Skin", (0.99, 0.84, 0.72))
BLUSH = C("Blush", (1.0, 0.62, 0.6))
WHITE = C("EyeWhite", (1.0, 1.0, 1.0), 0.3)
IRIS = C("Iris", (0.42, 0.24, 0.14), 0.3)
PUPIL = C("Pupil", (0.06, 0.04, 0.04), 0.3)
MOUTH = C("Mouth", (0.72, 0.28, 0.28))

# ---------- 부품 만들기 ----------
def sphere(size, loc, m, rot=(0, 0, 0), segs=12, rings=8):
    return b.blob(size, loc, m, rot, segs, rings)

def tube(p0, p1, r0, r1, m, verts=12):
    p0, p1 = Vector(p0), Vector(p1)
    d = p1 - p0
    o = b.cyl(r0, d.length, tuple((p0 + p1) / 2), m, verts=verts, r2=r1)
    o.rotation_mode = "QUATERNION"
    o.rotation_quaternion = Vector((0, 0, -1)).rotation_difference(d.normalized())
    return o

def curve(pts, r, m, res=1):
    return b.curve(pts, r, m, res=res)

def group(objs, name, pivot):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.convert(target="MESH")
    if len(objs) > 1:
        bpy.ops.object.join()
    o = bpy.context.object
    o.name = name
    b.scene.cursor.location = pivot
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    return o

class Char:
    def __init__(self, kind, ox):
        self.kind, self.ox = kind, ox
        self.groups = {k: [] for k in ("Body", "Eyes", "ArmL", "ArmR", "LegL", "LegR")}
        self.cur = "Body"
    def P(self, x, y, z):
        return (x + self.ox, y, z)
    def add(self, o):
        self.groups[self.cur].append(o)
        b.parts.remove(o)
        return o
    def sphere(self, size, loc, m, rot=(0, 0, 0), segs=12, rings=8):
        return self.add(sphere(size, self.P(*loc), m, rot, segs, rings))
    def tube(self, p0, p1, r0, r1, m, verts=12):
        return self.add(tube(self.P(*p0), self.P(*p1), r0, r1, m, verts))
    def curve(self, pts, r, m, res=1):
        return self.add(curve([self.P(*p) for p in pts], r, m, res))
    def box(self, size, loc, m, bevel=0.02, rot=(0, 0, 0)):
        return self.add(b.box(size, self.P(*loc), m, bevel, rot, segs=2))
    def done(self, pivots):
        empty = bpy.data.objects.new("Char_" + self.kind, None)
        b.scene.collection.objects.link(empty)
        empty.location = (self.ox, 0, 0)
        for gname, objs in self.groups.items():
            if not objs:
                continue
            pv = pivots.get(gname, (0, 0, 0))
            o = group(objs, "%s_%s" % (self.kind, gname), self.P(*pv))
            o.parent = empty
            o.matrix_parent_inverse = empty.matrix_world.inverted()

# ---------- 얼굴 ----------
def face(ch, hair_col, brows="kind", mouth="smile", eye_scale=1.0):
    ch.cur = "Body"
    ch.sphere((0.96, 0.88, 0.88), (0, 0, 0.5), SKIN, segs=24, rings=14)
    ch.sphere((0.6, 0.5, 0.36), (0, -0.12, 0.3), SKIN, segs=20, rings=12)   # 볼살
    for sx in (-1, 1):
        ch.sphere((0.12, 0.09, 0.17), (sx * 0.47, 0.02, 0.47), SKIN)
        ch.sphere((0.12, 0.03, 0.075), (sx * 0.27, -0.395, 0.36), BLUSH)
    ch.sphere((0.075, 0.06, 0.06), (0, -0.445, 0.42), SKIN)
    hc = hair_col
    for sx in (-1, 1):
        if brows == "angry":
            pts = [(sx * 0.07, -0.42, 0.63), (sx * 0.17, -0.42, 0.68), (sx * 0.27, -0.39, 0.71)]
        elif brows == "worried":
            pts = [(sx * 0.07, -0.42, 0.69), (sx * 0.17, -0.42, 0.67), (sx * 0.26, -0.39, 0.63)]
        else:
            pts = [(sx * 0.08, -0.42, 0.66), (sx * 0.17, -0.425, 0.69), (sx * 0.26, -0.395, 0.665)]
        ch.curve(pts, 0.024, hc)
    if mouth == "smile":
        ch.curve([(-0.08, -0.425, 0.315), (-0.03, -0.44, 0.29), (0.03, -0.44, 0.29), (0.08, -0.425, 0.315)], 0.014, MOUTH)
    elif mouth == "smirk":
        ch.curve([(-0.08, -0.43, 0.3), (0.0, -0.44, 0.295), (0.09, -0.42, 0.33)], 0.014, MOUTH)
    elif mouth == "grin":
        ch.sphere((0.24, 0.05, 0.1), (0, -0.43, 0.29), MOUTH)
        ch.box((0.18, 0.02, 0.04), (0, -0.455, 0.31), WHITE, 0.01)
    ch.cur = "Eyes"
    es = eye_scale
    for sx in (-1, 1):
        x = sx * 0.17
        ch.sphere((0.15 * es, 0.05, 0.18 * es), (x, -0.4, 0.5), WHITE)
        ch.sphere((0.12 * es, 0.05, 0.15 * es), (x, -0.418, 0.49), IRIS)
        ch.sphere((0.07 * es, 0.04, 0.09 * es), (x, -0.432, 0.485), PUPIL)
        ch.sphere((0.045 * es, 0.02, 0.045 * es), (x + 0.025, -0.448, 0.535), WHITE)
        ch.sphere((0.02 * es, 0.02, 0.02 * es), (x - 0.03, -0.446, 0.465), WHITE)
    ch.cur = "Body"

def hair(ch, style, col):
    if style == "hero":
        ch.sphere((1.0, 0.94, 0.72), (0, 0.05, 0.69), col, segs=24, rings=14)
        ch.sphere((0.94, 0.7, 0.72), (0, 0.15, 0.52), col)
        for (x, z, rx, rot) in ((-0.2, 0.86, 0.36, 0.5), (0.04, 0.9, 0.4, -0.2), (0.24, 0.85, 0.32, -0.6), (-0.34, 0.74, 0.24, 0.9)):
            ch.sphere((rx, 0.26, 0.16), (x, -0.27, z), col, rot=(0.4, rot, 0))
        for sx in (-1, 1):
            ch.sphere((0.16, 0.3, 0.36), (sx * 0.42, -0.06, 0.6), col)
    elif style == "kid":
        ch.sphere((0.98, 0.92, 0.66), (0, 0.04, 0.7), col, segs=24, rings=14)
        ch.sphere((0.92, 0.66, 0.7), (0, 0.15, 0.52), col)
        ch.sphere((0.7, 0.22, 0.16), (0, -0.3, 0.8), col, rot=(0.4, 0, 0))
    elif style == "topknot":
        ch.sphere((0.98, 0.92, 0.62), (0, 0.05, 0.71), col, segs=24, rings=14)
        ch.sphere((0.92, 0.66, 0.68), (0, 0.15, 0.53), col)
        ch.sphere((0.27, 0.27, 0.3), (0, 0.04, 1.06), col)
        ch.tube((0, 0.04, 0.95), (0, 0.04, 1.0), 0.1, 0.1, col)
        for sx in (-1, 1):
            ch.curve([(sx * 0.38, -0.2, 0.7), (sx * 0.45, -0.28, 0.6), (sx * 0.43, -0.3, 0.5)], 0.03, col)
    elif style == "bun":
        ch.sphere((0.98, 0.92, 0.62), (0, 0.05, 0.71), col, segs=24, rings=14)
        ch.sphere((0.94, 0.7, 0.74), (0, 0.15, 0.53), col)
        ch.sphere((0.36, 0.3, 0.3), (0, 0.46, 0.4), col)
        ch.tube((-0.26, 0.48, 0.42), (0.26, 0.48, 0.42), 0.022, 0.022, C("Pin", (0.95, 0.8, 0.35), 0.3))

def gat(ch, gold=False):
    blk = C("Gat", (0.1, 0.09, 0.1), 0.6)
    ch.tube((0, 0, 0.94), (0, 0, 0.98), 0.66, 0.66, blk, verts=32)
    ch.tube((0, 0, 0.98), (0, 0, 1.36), 0.24, 0.22, blk, verts=24)
    ch.tube((0, 0, 1.36), (0, 0, 1.38), 0.22, 0.2, blk, verts=24)
    sc = C("GoldStrap", (0.95, 0.75, 0.25), 0.3) if gold else blk
    for sx in (-1, 1):
        ch.curve([(sx * 0.42, -0.05, 0.95), (sx * 0.46, -0.12, 0.6), (sx * 0.3, -0.3, 0.2), (0, -0.33, 0.12)], 0.016, sc)
    ch.curve([(0, -0.33, 0.12), (0.02, -0.34, -0.1)], 0.018, sc)

def headband(ch):
    w = C("Band", (0.96, 0.93, 0.85))
    pts = []
    for i in range(33):
        a = 2 * math.pi * i / 32
        pts.append((math.cos(a) * 0.5, math.sin(a) * 0.47, 0.76 + 0.03 * math.sin(a)))
    ch.curve(pts, 0.055, w)
    ch.sphere((0.16, 0.14, 0.14), (-0.5, -0.05, 0.75), w)
    ch.sphere((0.1, 0.22, 0.28), (-0.6, 0.0, 0.62), w, rot=(0.3, 0.2, 0))
    ch.sphere((0.1, 0.2, 0.24), (-0.58, 0.1, 0.6), w, rot=(-0.3, 0.2, 0))

# ---------- 몸 ----------
def hanbok_top(ch, col, collar=(0.97, 0.95, 0.9), ribbon=None, patch=False, short=False):
    top = C("Outfit", col) if col is None else col
    z = 0.02 if short else -0.2
    h = 0.46 if short else 0.72
    w = 0.96 if short else 0.86
    ch.sphere((w, 0.7 if short else 0.64, h), (0, 0, z), top, segs=16, rings=10)
    cm = C("Collar", collar)
    ch.curve([(-0.22, -0.29, 0.1), (-0.05, -0.33, -0.02), (0.14, -0.32, -0.16)], 0.045, cm)
    ch.curve([(0.18, -0.27, 0.1), (0.06, -0.31, 0.02)], 0.04, cm)
    rc = ribbon if ribbon else cm
    ch.sphere((0.1, 0.06, 0.08), (0.14, -0.34, -0.15), rc)
    ch.curve([(0.14, -0.34, -0.17), (0.12, -0.35, -0.32), (0.15, -0.34, -0.42)], 0.03, rc)
    ch.curve([(0.16, -0.34, -0.17), (0.2, -0.33, -0.3)], 0.03, rc)
    if patch:
        ch.box((0.16, 0.03, 0.14), (-0.25, -0.3, -0.38), C("Patch", (0.6, 0.55, 0.6)), 0.01)

def arms(ch, sleeve, cuff=None, wide=False, hand_item=None):
    for side, sx in (("ArmL", -1), ("ArmR", 1)):
        ch.cur = side
        sh = (sx * 0.38, 0, 0.02)
        el = (sx * 0.52, -0.02, -0.4)
        ch.sphere((0.26, 0.26, 0.26), sh, sleeve)
        ch.tube(sh, el, 0.12, 0.17 if wide else 0.13, sleeve)
        if cuff:
            ch.tube((el[0] * 0.98, el[1], el[2] + 0.04), (el[0] * 1.01, el[1], el[2] - 0.03), 0.17 if wide else 0.135, 0.18 if wide else 0.14, cuff)
        ch.sphere((0.2, 0.18, 0.2), (sx * 0.54, -0.03, -0.5), SKIN)
        if hand_item and sx == 1:
            hand_item(ch)
    ch.cur = "Body"

def legs(ch, pants, shoe, baggy=False, hidden=False, sock=None, cuff=None):
    for side, sx in (("LegL", -1), ("LegR", 1)):
        ch.cur = side
        hip = (sx * 0.17, 0, -0.5)
        ank = (sx * 0.18, -0.02, -0.86)
        if not hidden:
            if baggy:
                ch.sphere((0.36, 0.38, 0.46), (sx * 0.18, 0, -0.66), pants)
                ch.tube((sx * 0.18, -0.01, -0.78), ank, 0.12, 0.09, sock or pants)
            else:
                ch.tube(hip, ank, 0.15, 0.13, pants)
                if cuff:
                    ch.tube((ank[0], ank[1], -0.8), (ank[0], ank[1], -0.87), 0.15, 0.15, cuff)
        elif sock:
            ch.tube((sx * 0.18, -0.01, -0.8), ank, 0.08, 0.08, sock)
        shoe(ch, sx)
    ch.cur = "Body"

def sneaker(ch, sx):
    ch.sphere((0.27, 0.44, 0.2), (sx * 0.18, -0.08, -0.9), C("Sneaker", (0.97, 0.97, 0.97), 0.6))
    ch.sphere((0.28, 0.45, 0.07), (sx * 0.18, -0.08, -0.98), C("Sole", (0.88, 0.88, 0.86)))
    ch.curve([(sx * 0.31, -0.12, -0.88), (sx * 0.31, -0.02, -0.92)], 0.02, C("Stripe", (0.3, 0.45, 0.8)))

def straw_shoe(ch, sx):
    ch.sphere((0.26, 0.44, 0.15), (sx * 0.18, -0.08, -0.93), C("StrawShoe", (0.86, 0.68, 0.32)))

def black_shoe(ch, sx):
    ch.sphere((0.26, 0.46, 0.16), (sx * 0.18, -0.08, -0.93), C("Shoe", (0.18, 0.13, 0.12), 0.5))
    ch.sphere((0.1, 0.12, 0.08), (sx * 0.18, -0.3, -0.88), C("Shoe", (0.18, 0.13, 0.12), 0.5))

def white_shoe(ch, sx):
    ch.sphere((0.24, 0.42, 0.14), (sx * 0.18, -0.08, -0.93), C("Beoseon", (0.96, 0.95, 0.92)))
    ch.sphere((0.08, 0.1, 0.07), (sx * 0.18, -0.3, -0.88), C("Beoseon", (0.96, 0.95, 0.92)))

def skirt(ch, col):
    m = col
    ch.tube((0, 0, -0.12), (0, 0, -0.92), 0.32, 0.6, m, verts=24)
    ch.sphere((1.06, 0.98, 0.9), (0, 0, -0.56), m, segs=20, rings=12)
    ch.sphere((1.22, 1.14, 0.14), (0, 0, -0.93), m, segs=20, rings=6)

def coat(ch, col, inner):
    ch.tube((0, 0, -0.3), (0, 0, -0.92), 0.4, 0.5, inner, verts=20)
    ch.sphere((1.04, 0.86, 1.0), (0, 0, -0.42), col, segs=20, rings=12)
    ch.tube((0, 0, -0.55), (0, 0, -0.82), 0.5, 0.6, col, verts=20)
    ch.curve([(0.06, -0.43, -0.3), (0.1, -0.5, -0.6), (0.12, -0.56, -0.82)], 0.018, inner)

# ---------- 인물들 ----------
X = [0]
def nxt():
    X[0] += 3
    return X[0]

def build_hero():
    ch = Char("hero", nxt())
    face(ch, C("HairBrown", (0.26, 0.17, 0.12)))
    hair(ch, "hero", C("HairBrown", (0.26, 0.17, 0.12)))
    jacket = C("Outfit", (0.27, 0.43, 0.78))
    navy = C("Navy", (0.13, 0.18, 0.36))
    ch.sphere((0.88, 0.66, 0.66), (0, 0, -0.2), jacket, segs=20, rings=12)
    ch.tube((0, 0, 0.14), (0, 0, 0.06), 0.3, 0.33, navy)       # 후드 깃
    ch.box((0.2, 0.05, 0.42), (0, -0.31, -0.15), C("Shirt", (0.97, 0.93, 0.8)), 0.02)
    for z in (-0.02, -0.18, -0.34):
        ch.sphere((0.05, 0.03, 0.05), (0.13, -0.33, z), C("Gold", (0.95, 0.75, 0.25), 0.3))
    for sx in (-1, 1):
        ch.box((0.16, 0.04, 0.11), (sx * 0.22, -0.3, -0.08), jacket, 0.02)
    ch.tube((0, 0, -0.48), (0, 0, -0.56), 0.4, 0.38, navy)       # 밑단 고무줄
    # 크로스백
    ch.curve([(-0.3, -0.3, 0.08), (0.0, -0.36, -0.15), (0.3, -0.32, -0.42)], 0.03, C("Leather", (0.85, 0.6, 0.25)))
    ch.box((0.24, 0.1, 0.22), (0.36, -0.32, -0.5), C("Leather", (0.85, 0.6, 0.25)), 0.04)
    ch.box((0.05, 0.02, 0.08), (0.36, -0.38, -0.47), C("Buckle", (0.45, 0.28, 0.15)), 0.01)
    arms(ch, jacket, cuff=navy)
    legs(ch, C("Pants", (0.33, 0.34, 0.4)), sneaker, cuff=C("Cuff", (0.55, 0.56, 0.6)))
    return ch

def build_heungbu():
    ch = Char("heungbu", nxt())
    hc = C("HairDark", (0.24, 0.15, 0.1))
    face(ch, hc)
    hair(ch, "topknot", hc)
    headband(ch)
    ch.sphere((0.09, 0.05, 0.08), (0, -0.36, 0.14), hc)     # 짧은 턱수염
    hanbok_top(ch, C("Vest", (0.85, 0.76, 0.6)), ribbon=C("Band", (0.96, 0.93, 0.85)), patch=True)
    arms(ch, C("Sleeve", (0.95, 0.91, 0.82)), wide=True)
    legs(ch, C("Baji", (0.25, 0.48, 0.5)), straw_shoe, baggy=True, sock=C("Beoseon", (0.96, 0.95, 0.92)))
    return ch

def build_nolbu():
    ch = Char("nolbu", nxt())
    hc = C("HairDark", (0.24, 0.15, 0.1))
    face(ch, hc, brows="angry", mouth="smirk", eye_scale=0.85)
    hair(ch, "topknot", hc)
    gat(ch, gold=True)
    ch.curve([(-0.2, -0.43, 0.33), (-0.08, -0.45, 0.37), (0, -0.45, 0.36)], 0.028, hc)
    ch.curve([(0.2, -0.43, 0.33), (0.08, -0.45, 0.37), (0, -0.45, 0.36)], 0.028, hc)
    ch.sphere((0.1, 0.08, 0.18), (0, -0.38, 0.17), hc)
    coat(ch, C("Coat", (0.86, 0.36, 0.22)), C("CoatInner", (0.55, 0.2, 0.3)))
    ch.sphere((0.92, 0.7, 0.6), (0, 0, -0.12), C("Coat", (0.86, 0.36, 0.22)), segs=20, rings=12)
    ch.curve([(-0.22, -0.31, 0.12), (-0.05, -0.35, 0.0), (0.12, -0.36, -0.12)], 0.045, C("Collar", (0.97, 0.95, 0.9)))
    sash = C("Sash", (0.55, 0.2, 0.3))
    ch.tube((0, 0, -0.32), (0, 0, -0.42), 0.44, 0.45, sash)
    ch.sphere((0.16, 0.08, 0.12), (0.15, -0.42, -0.37), sash)
    ch.curve([(0.15, -0.44, -0.4), (0.13, -0.47, -0.7)], 0.04, sash)
    gold = C("Gold", (0.95, 0.75, 0.25), 0.3)
    ch.sphere((0.07, 0.04, 0.07), (0.26, -0.44, -0.45), gold)
    ch.curve([(0.26, -0.44, -0.48), (0.26, -0.45, -0.55)], 0.012, gold)
    ch.tube((0.26, -0.45, -0.55), (0.26, -0.45, -0.72), 0.03, 0.06, gold)
    arms(ch, C("SleevePurple", (0.55, 0.2, 0.3)), cuff=C("Collar", (0.97, 0.95, 0.9)), wide=True)
    legs(ch, None, black_shoe, hidden=True, sock=C("Beoseon", (0.96, 0.95, 0.92)))
    return ch

def build_lady(kind, top, skirt_col, hair_col, brows="kind", mouth="smile"):
    ch = Char(kind, nxt())
    face(ch, hair_col, brows=brows, mouth=mouth)
    hair(ch, "bun", hair_col)
    skirt(ch, skirt_col)
    hanbok_top(ch, top, ribbon=C("Ribbon", (0.85, 0.3, 0.35)), short=True)
    arms(ch, top, cuff=C("Collar", (0.97, 0.95, 0.9)))
    legs(ch, None, white_shoe, hidden=True)
    return ch

def build_man(kind, top, pants, hair_style="topknot", hair_col=None, hat=None, beard=None, item=None):
    ch = Char(kind, nxt())
    hc = hair_col or C("HairDark", (0.24, 0.15, 0.1))
    face(ch, hc)
    hair(ch, hair_style, hc)
    if hat == "gat":
        gat(ch)
    elif hat == "band":
        headband(ch)
    if beard == "white":
        ch.sphere((0.36, 0.2, 0.5), (0, -0.33, 0.12), hc)
    elif beard == "short":
        ch.sphere((0.09, 0.05, 0.08), (0, -0.36, 0.14), hc)
    hanbok_top(ch, top)
    arms(ch, top, wide=True, hand_item=item)
    legs(ch, pants, straw_shoe, baggy=True, sock=C("Beoseon", (0.96, 0.95, 0.92)))
    return ch

def staff(ch):
    ch.curve([(0.56, -0.05, 0.1), (0.57, -0.06, -0.5), (0.56, -0.06, -1.0)], 0.035, C("Staff", (0.5, 0.33, 0.2)))
    ch.sphere((0.16, 0.16, 0.16), (0.56, -0.05, 0.14), C("Staff", (0.5, 0.33, 0.2)))

def club(ch):
    ch.tube((0.56, -0.04, -0.5), (0.62, -0.1, 0.3), 0.05, 0.13, C("Club", (0.55, 0.36, 0.2)))
    for k in range(5):
        a = k * 1.3
        ch.sphere((0.05, 0.05, 0.05), (0.6 + math.cos(a) * 0.12, -0.08 + math.sin(a) * 0.12, 0.05 + k * 0.05), C("Stud", (0.9, 0.85, 0.7)))

def build_dokkaebi():
    ch = Char("dokkaebi", nxt())
    global SKIN
    old = SKIN
    SKIN = C("SkinTeal", (0.4, 0.78, 0.72))
    hc = C("HairNight", (0.12, 0.12, 0.18))
    face(ch, hc, brows="angry", mouth="grin")
    hair(ch, "kid", hc)
    for sx in (-1, 1):
        ch.tube((sx * 0.2, 0, 0.92), (sx * 0.3, 0, 1.22), 0.08, 0.01, C("Horn", (1.0, 0.88, 0.35)))
    ch.sphere((0.86, 0.64, 0.66), (0, 0, -0.2), SKIN, segs=20, rings=12)
    tiger = C("Tiger", (1.0, 0.72, 0.18))
    ch.tube((0, 0, -0.35), (0, 0, -0.62), 0.42, 0.44, tiger)
    for k in range(6):
        a = 2 * math.pi * k / 6
        ch.curve([(math.cos(a) * 0.44, math.sin(a) * 0.44, -0.38), (math.cos(a + 0.2) * 0.45, math.sin(a + 0.2) * 0.45, -0.58)], 0.025, C("Stripe2", (0.15, 0.1, 0.08)))
    arms(ch, SKIN, hand_item=club)
    legs(ch, SKIN, lambda c, sx: c.sphere((0.24, 0.4, 0.16), (sx * 0.18, -0.06, -0.93), SKIN))
    SKIN = old
    return ch

chars = [
    build_hero(), build_heungbu(), build_nolbu(),
    build_lady("wife", C("WifeTop", (0.98, 0.84, 0.78)), C("Outfit", (0.75, 0.3, 0.3)), C("HairDark", (0.24, 0.15, 0.1)), brows="angry", mouth="smirk"),
    build_lady("suni", C("WhiteTop", (0.97, 0.95, 0.88)), C("Outfit", (0.55, 0.65, 0.85)), C("HairDark", (0.24, 0.15, 0.1))),
    build_lady("ong", C("GreyTop", (0.92, 0.9, 0.84)), C("Outfit", (0.6, 0.5, 0.55)), C("HairGrey", (0.82, 0.82, 0.86))),
    build_man("kim", C("Outfit", (0.62, 0.55, 0.4)), C("Baji", (0.82, 0.78, 0.66)), hat="gat"),
    build_man("park", C("Outfit", (0.5, 0.6, 0.65)), C("Baji", (0.82, 0.78, 0.66)), hair_col=C("HairWhite", (0.9, 0.9, 0.92)), beard="white"),
    build_man("merchant", C("Outfit", (0.35, 0.58, 0.4)), C("Baji", (0.82, 0.78, 0.66)), hat="band"),
    build_man("woodman", C("Outfit", (0.62, 0.48, 0.34)), C("Baji", (0.7, 0.62, 0.48)), hat="band", beard="short"),
    build_man("sansin", C("Robe", (0.97, 0.97, 1.0)), C("Robe", (0.97, 0.97, 1.0)), hair_col=C("HairWhite", (0.9, 0.9, 0.92)), beard="white", item=staff),
    build_man("kid", C("Outfit", (0.98, 0.8, 0.5)), C("Baji", (0.88, 0.84, 0.72)), hair_style="kid"),
    build_man("villager", C("Outfit", (0.7, 0.62, 0.5)), C("Baji", (0.82, 0.78, 0.66))),
    build_dokkaebi(),
]
PIV = {"ArmL": (-0.38, 0, 0.02), "ArmR": (0.38, 0, 0.02), "LegL": (-0.17, 0, -0.5), "LegR": (0.17, 0, -0.5), "Eyes": (0, -0.42, 0.5)}
for ch in chars:
    ch.done(PIV)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=OUT, export_apply=True, export_yup=True, export_materials="EXPORT")
tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in bpy.data.objects if o.type == "MESH")
print("saved", OUT, "triangles", tris, "per char", tris // len(chars))
