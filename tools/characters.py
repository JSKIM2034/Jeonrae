# 등장인물 v2 (블렌더). 키 2 (발바닥 z=-1, 머리카락 끝 z=+1), 앞쪽 = -Y.
# 그림 비율에 맞춰 머리는 키의 1/4 남짓, 다리는 길게.
# Char_<종류> 아래에 Body, Eyes, ArmL, ArmR, LegL, LegR. 팔다리 원점 = 어깨/엉덩이 관절.
import sys, math, random
sys.path.insert(0, "/home/claude/jeonrae/tools")
from blcommon import *

OUT = "/home/claude/jeonrae/source/models/characters.glb"
b = Builder()
MATC = {}
def srgb(c):
    return tuple(((x + 0.055) / 1.055) ** 2.4 if x > 0.04045 else x / 12.92 for x in c)
def C(name, col, rough=0.8):
    if name not in MATC:
        m = bpy.data.materials.new(name)
        lin = srgb(col)
        m.diffuse_color = (*lin, 1.0)
        if m.node_tree:
            bs = m.node_tree.nodes.get("Principled BSDF")
            if bs:
                bs.inputs["Base Color"].default_value = (*lin, 1.0)
                bs.inputs["Roughness"].default_value = rough
        MATC[name] = m
    return MATC[name]

SKIN0 = C("Skin", (1.0, 0.84, 0.72))
SKIN = SKIN0
BLUSH = C("Blush", (1.0, 0.64, 0.6))
WHITE = C("EyeWhite", (1.0, 1.0, 1.0), 0.25)
IRIS = C("Iris", (0.32, 0.18, 0.1), 0.25)
PUPIL = C("Pupil", (0.07, 0.04, 0.03), 0.25)
LID = C("Lid", (0.2, 0.12, 0.09))
MOUTH = C("Mouth", (0.62, 0.3, 0.27))
COLLAR = C("Collar", (0.98, 0.96, 0.9))
SOCK = C("Beoseon", (0.97, 0.96, 0.93))

HEAD_Z = 0.64
HR = (0.265, 0.245, 0.275)

class Char:
    def __init__(self, kind, ox):
        self.kind, self.ox = kind, ox
        self.groups = {k: [] for k in ("Body", "Eyes", "ArmL", "ArmR", "LegL", "LegR")}
        self.cur = "Body"
    def P(self, p):
        return (p[0] + self.ox, p[1], p[2])
    def add(self, o):
        self.groups[self.cur].append(o)
        b.parts.remove(o)
        return o
    def sph(self, size, loc, m, rot=(0, 0, 0), segs=14, rings=9):
        return self.add(b.blob(size, self.P(loc), m, rot, segs, rings))
    def tube(self, p0, p1, r0, r1, m, verts=14, sy=1.0):
        p0, p1 = Vector(self.P(p0)), Vector(self.P(p1))
        d = p1 - p0
        o = b.cyl(r0, d.length, tuple((p0 + p1) / 2), m, verts=verts, r2=r1)
        if sy != 1.0:
            o.scale = (1, sy, 1)
            bpy.ops.object.transform_apply(scale=True)
        o.rotation_mode = "QUATERNION"
        o.rotation_quaternion = Vector((0, 0, -1)).rotation_difference(d.normalized())
        return self.add(o)
    def curve(self, pts, r, m, res=2, radii=None):
        return self.add(b.curve([self.P(p) for p in pts], r, m, res=res, radii=radii))
    def lathe(self, prof, m, sy=0.85, segs=32, cy=0.0):
        """prof: [(반지름, z)...] 위에서 아래로. 단면을 돌려 매끈한 몸통을 만들어요"""
        bm = bmesh.new()
        rings = []
        for (r, z) in prof:
            ring = []
            for i in range(segs):
                a = 2 * math.pi * i / segs
                ring.append(bm.verts.new(self.P((math.cos(a) * r, cy + math.sin(a) * r * sy, z))))
            rings.append(ring)
        for k in range(len(rings) - 1):
            for i in range(segs):
                j = (i + 1) % segs
                bm.faces.new((rings[k][i], rings[k][j], rings[k + 1][j], rings[k + 1][i]))
        for ring in (rings[0], rings[-1]):
            if len(set(tuple(v.co) for v in ring)) > 1:
                bm.faces.new(ring)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        me = bpy.data.meshes.new("lathe")
        bm.to_mesh(me)
        o = bpy.data.objects.new("lathe", me)
        b.scene.collection.objects.link(o)
        b.finish(o, m, smooth=True)
        return self.add(o)
    def box(self, size, loc, m, bevel=0.012, rot=(0, 0, 0)):
        return self.add(b.box(size, self.P(loc), m, bevel, rot, segs=2))
    def done(self, pivots):
        empty = bpy.data.objects.new("Char_" + self.kind, None)
        b.scene.collection.objects.link(empty)
        empty.location = (self.ox, 0, 0)
        for gname, objs in self.groups.items():
            if not objs:
                continue
            bpy.ops.object.select_all(action="DESELECT")
            for o in objs:
                o.select_set(True)
            bpy.context.view_layer.objects.active = objs[0]
            bpy.ops.object.convert(target="MESH")
            if len(objs) > 1:
                bpy.ops.object.join()
            o = bpy.context.object
            o.name = "%s_%s" % (self.kind, gname)
            b.scene.cursor.location = self.P(pivots.get(gname, (0, 0, 0)))
            bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
            o.parent = empty
            o.matrix_parent_inverse = empty.matrix_world.inverted()

# ---------- 얼굴 ----------
def face(ch, brow_col, brows="kind", mouth="smile", lids="open", wide=1.0):
    ch.cur = "Body"
    hz = HEAD_Z
    ch.sph((HR[0] * 2 * wide, HR[1] * 2, HR[2] * 2), (0, 0, hz), SKIN, segs=32, rings=20)
    ch.sph((0.34 * wide, 0.26, 0.2), (0, -0.07, hz - 0.13), SKIN, segs=20, rings=12)       # 볼과 턱
    ch.tube((0, 0.01, hz - 0.22), (0, 0.01, hz - 0.34), 0.075, 0.08, SKIN)              # 목
    for sx in (-1, 1):
        ch.sph((0.08, 0.05, 0.12), (sx * 0.262 * wide, 0.02, hz - 0.02), SKIN)         # 귀
        ch.sph((0.045, 0.03, 0.06), (sx * 0.272 * wide, -0.005, hz - 0.02), C("EarIn", (0.95, 0.72, 0.62)))
        ch.sph((0.08, 0.015, 0.045), (sx * 0.155, -0.218, hz - 0.075), BLUSH)
    ch.sph((0.05, 0.04, 0.045), (0, -0.25, hz - 0.055), C("Nose", (1.0, 0.78, 0.66)))
    # 눈썹
    for sx in (-1, 1):
        if brows == "angry":
            pts = [(sx * 0.045, -0.235, hz + 0.06), (sx * 0.1, -0.235, hz + 0.088), (sx * 0.165, -0.21, hz + 0.105)]
        else:
            pts = [(sx * 0.05, -0.238, hz + 0.088), (sx * 0.1, -0.24, hz + 0.1), (sx * 0.15, -0.222, hz + 0.093)]
        ch.curve(pts, 0.016, brow_col, radii=[0.9, 1.0, 0.8])
    # 입
    if mouth == "smile":
        ch.curve([(-0.045, -0.238, hz - 0.13), (-0.015, -0.248, hz - 0.145), (0.015, -0.248, hz - 0.145), (0.045, -0.238, hz - 0.13)], 0.008, MOUTH)
    elif mouth == "smirk":
        ch.curve([(-0.05, -0.243, hz - 0.14), (0.0, -0.25, hz - 0.142), (0.05, -0.238, hz - 0.122)], 0.009, MOUTH)
    elif mouth == "grin":
        ch.sph((0.13, 0.03, 0.06), (0, -0.24, hz - 0.14), MOUTH)
        ch.box((0.1, 0.012, 0.022), (0, -0.255, hz - 0.125), WHITE, 0.004)
    # 눈 (깜빡일 수 있게 따로)
    ch.cur = "Eyes"
    for sx in (-1, 1):
        x = sx * 0.095
        ch.sph((0.112, 0.03, 0.128), (x, -0.222, hz), WHITE)
        ch.sph((0.092, 0.03, 0.104), (x + sx * 0.003, -0.232, hz - 0.006), IRIS)
        ch.sph((0.05, 0.02, 0.058), (x + sx * 0.003, -0.243, hz - 0.008), PUPIL)
        ch.sph((0.03, 0.012, 0.03), (x + 0.018, -0.251, hz + 0.022), WHITE)
        ch.sph((0.014, 0.01, 0.014), (x - 0.016, -0.25, hz - 0.026), WHITE)
        # 얇은 윗눈꺼풀 선
        ch.curve([(x - 0.052, -0.22, hz + 0.028), (x - 0.02, -0.236, hz + 0.062), (x + 0.02, -0.236, hz + 0.063), (x + 0.054, -0.219, hz + 0.03)], 0.0055, LID)
        if lids == "half":
            ch.sph((0.11, 0.035, 0.06), (x, -0.226, hz + 0.035), SKIN)
            ch.curve([(x - 0.05, -0.236, hz + 0.012), (x + 0.05, -0.236, hz + 0.012)], 0.009, LID)
    ch.cur = "Body"

# ---------- 머리 ----------
def hair_hero(ch, col):
    hz = HEAD_Z
    ch.sph((0.58, 0.54, 0.36), (0, 0.03, hz + 0.15), col, segs=24, rings=12)
    ch.sph((0.56, 0.4, 0.44), (0, 0.08, hz + 0.01), col, segs=20, rings=12)
    for sx in (-1, 1):
        ch.sph((0.09, 0.2, 0.2), (sx * 0.25, -0.04, hz + 0.06), col)
    # 위로 솟아 옆으로 넘긴 앞머리 결
    locks = [
        ((-0.2, 0.06, hz + 0.24), (-0.08, -0.06, hz + 0.33), (0.06, -0.16, hz + 0.31), (0.13, -0.22, hz + 0.22), 0.075),
        ((-0.12, 0.1, hz + 0.28), (0.02, 0.0, hz + 0.37), (0.15, -0.1, hz + 0.32), (0.22, -0.15, hz + 0.2), 0.07),
        ((-0.24, -0.02, hz + 0.2), (-0.2, -0.16, hz + 0.24), (-0.1, -0.23, hz + 0.18), (-0.05, -0.25, hz + 0.12), 0.055),
        ((0.0, 0.14, hz + 0.25), (0.14, 0.06, hz + 0.3), (0.24, -0.02, hz + 0.22), (0.27, -0.06, hz + 0.12), 0.06),
        ((-0.25, 0.08, hz + 0.18), (-0.29, -0.02, hz + 0.12), (-0.28, -0.1, hz + 0.04), (-0.25, -0.12, hz - 0.02), 0.05),
        ((0.1, 0.18, hz + 0.18), (0.0, 0.2, hz + 0.3), (-0.12, 0.12, hz + 0.33), (-0.22, 0.02, hz + 0.3), 0.06),
    ]
    for l in locks:
        ch.curve(list(l[:4]), l[4], col, res=2, radii=[0.8, 1.0, 0.75, 0.3])
    ch.curve([(-0.17, 0.0, hz + 0.33), (-0.22, -0.02, hz + 0.39), (-0.16, -0.06, hz + 0.41)], 0.03, col, radii=[1, 0.8, 0.3])

def hair_cap(ch, col, part=False):
    hz = HEAD_Z
    ch.sph((0.565, 0.53, 0.34), (0, 0.03, hz + 0.15), col, segs=24, rings=12)
    ch.sph((0.55, 0.4, 0.44), (0, 0.08, hz + 0.01), col, segs=20, rings=12)
    for sx in (-1, 1):
        ch.sph((0.07, 0.16, 0.16), (sx * 0.25, -0.02, hz + 0.03), col)
    dk = C(col.name + "Dark", tuple(x * 0.75 for x in col.diffuse_color[:3]))
    for k in range(-3, 4):
        x = k * 0.06
        ch.curve([(x * 0.3, -0.2, hz + 0.21), (x * 0.7, -0.05, hz + 0.31), (x, 0.12, hz + 0.27)], 0.008, col)
    if part:
        ch.curve([(0, -0.22, hz + 0.2), (0, -0.08, hz + 0.31), (0, 0.06, hz + 0.31)], 0.007, SKIN)

def topknot(ch, col):
    hz = HEAD_Z
    ch.sph((0.15, 0.15, 0.17), (0, 0.04, hz + 0.37), col)
    ch.tube((0, 0.04, hz + 0.3), (0, 0.04, hz + 0.33), 0.055, 0.055, col)

def low_bun(ch, col, pin=(0.95, 0.8, 0.35)):
    hz = HEAD_Z
    ch.sph((0.22, 0.17, 0.18), (0, 0.24, hz - 0.08), col)
    ch.tube((-0.15, 0.25, hz - 0.07), (0.15, 0.25, hz - 0.07), 0.012, 0.012, C("Pin", pin, 0.3))

def headband(ch):
    hz = HEAD_Z
    w = C("Band", (0.97, 0.94, 0.86))
    pts = [(math.cos(2 * math.pi * i / 36) * 0.285, math.sin(2 * math.pi * i / 36) * 0.268, hz + 0.13 + 0.02 * math.sin(2 * math.pi * i / 36)) for i in range(37)]
    ch.curve(pts, 0.03, w)
    ch.sph((0.08, 0.07, 0.07), (-0.29, -0.06, hz + 0.12), w)
    ch.curve([(-0.3, -0.06, hz + 0.12), (-0.37, -0.1, hz + 0.06), (-0.38, -0.12, hz - 0.02)], 0.022, w, radii=[1, 0.9, 0.5])
    ch.curve([(-0.3, -0.04, hz + 0.12), (-0.36, 0.0, hz + 0.08), (-0.36, 0.02, hz + 0.0)], 0.02, w, radii=[1, 0.9, 0.5])

def gat(ch, gold=False):
    hz = HEAD_Z
    blk = C("Gat", (0.1, 0.09, 0.11), 0.55)
    ch.tube((0, 0, hz + 0.25), (0, 0, hz + 0.27), 0.45, 0.45, blk, verts=36)
    ch.tube((0, 0, hz + 0.27), (0, 0, hz + 0.52), 0.15, 0.135, blk, verts=24)
    ch.tube((0, 0, hz + 0.52), (0, 0, hz + 0.53), 0.135, 0.12, blk, verts=24)
    sc = C("GoldStrap", (0.95, 0.76, 0.28), 0.3) if gold else blk
    for sx in (-1, 1):
        ch.curve([(sx * 0.27, -0.02, hz + 0.25), (sx * 0.27, -0.08, hz + 0.05), (sx * 0.17, -0.18, hz - 0.17), (0, -0.2, hz - 0.24)], 0.009, sc)
    ch.curve([(0, -0.2, hz - 0.24), (0.01, -0.21, hz - 0.36)], 0.012, sc)

def beard(ch, col, kind):
    hz = HEAD_Z
    if kind == "goatee":
        ch.sph((0.05, 0.03, 0.05), (0, -0.236, hz - 0.18), col)
    elif kind == "point":
        ch.tube((0, -0.225, hz - 0.17), (0, -0.21, hz - 0.25), 0.035, 0.006, col)
    elif kind == "long":
        ch.sph((0.24, 0.12, 0.34), (0, -0.19, hz - 0.28), col)
        ch.tube((0, -0.2, hz - 0.35), (0, -0.19, hz - 0.55), 0.08, 0.01, col)
    elif kind == "mustache":
        for sx in (-1, 1):
            ch.curve([(0, -0.25, hz - 0.095), (sx * 0.05, -0.248, hz - 0.1), (sx * 0.1, -0.235, hz - 0.085), (sx * 0.12, -0.225, hz - 0.06)], 0.014, col, radii=[1, 1, 0.7, 0.3])

# ---------- 옷 ----------
def jeogori(ch, col, hem_z=-0.18, rad=(0.24, 0.29), collar=COLLAR, tie=None, patch=False, belt=None):
    r0, r1 = rad
    ch.lathe([(0.07, 0.38), (0.17, 0.355), (r0, 0.3), (r0 + 0.01, 0.2), (r0 + 0.015, 0.0), (r1, hem_z), (r1 - 0.01, hem_z - 0.025), (0.05, hem_z - 0.025)], col, sy=0.8)
    # 깃 (오른쪽 위에서 왼쪽 아래로 여민 흰 동정)
    ch.curve([(-0.1, -0.15, 0.345), (-0.03, -0.195, 0.24), (0.07, -0.205, 0.1), (0.12, -0.205, 0.03)], 0.02, collar)
    ch.curve([(0.1, -0.15, 0.345), (0.05, -0.185, 0.26)], 0.018, collar)
    if tie:
        ch.sph((0.07, 0.04, 0.05), (0.12, -0.23, 0.04), tie)
        ch.curve([(0.12, -0.235, 0.03), (0.11, -0.25, -0.08), (0.13, -0.24, -0.18)], 0.018, tie, radii=[1, 1, 0.8])
        ch.curve([(0.13, -0.235, 0.03), (0.17, -0.23, -0.06)], 0.018, tie)
    if belt:
        ch.tube((0, 0, -0.02), (0, 0, -0.07), rad[0] + 0.03, rad[0] + 0.033, belt, verts=20, sy=0.8)
        ch.sph((0.1, 0.05, 0.06), (-0.04, -0.235, -0.045), belt, rot=(0, 0.3, 0))
        ch.sph((0.1, 0.05, 0.06), (0.06, -0.235, -0.045), belt, rot=(0, -0.3, 0))
        ch.curve([(0.0, -0.24, -0.06), (-0.02, -0.245, -0.18)], 0.016, belt)
        ch.curve([(0.02, -0.24, -0.06), (0.05, -0.245, -0.17)], 0.016, belt)
    if patch:
        ch.box((0.08, 0.012, 0.07), (-0.17, -0.205, -0.12), C("Patch", (0.62, 0.56, 0.62)), 0.006)

def sleeves(ch, col, cuff=None, wide=0.0, hand_item=None):
    for side, sx in (("ArmL", -1), ("ArmR", 1)):
        ch.cur = side
        sh = (sx * 0.24, 0, 0.28)
        wr = (sx * 0.33, -0.02, -0.1)
        ch.sph((0.15, 0.15, 0.15), sh, col)
        ch.tube(sh, wr, 0.07, 0.075 + wide, col)
        if cuff:
            ch.tube((sx * 0.325, -0.02, -0.07), (sx * 0.335, -0.02, -0.13), 0.074 + wide, 0.078 + wide, cuff)
        ch.sph((0.085, 0.065, 0.1), (sx * 0.34, -0.025, -0.19), SKIN)
        ch.sph((0.035, 0.03, 0.05), (sx * 0.31, -0.06, -0.16), SKIN, rot=(0, sx * 0.4, 0))
        if hand_item and sx == 1:
            hand_item(ch)
    ch.cur = "Body"

def legs(ch, shoe, pants=None, baggy=False, cuff=None, hidden=False, sock=SOCK):
    for side, sx in (("LegL", -1), ("LegR", 1)):
        ch.cur = side
        x = sx * 0.1
        if pants and not hidden:
            if baggy:
                ch.sph((0.24, 0.24, 0.5), (x * 1.15, 0, -0.48), pants)
                ch.tube((x, 0, -0.72), (x, -0.005, -0.8), 0.07, 0.06, pants)
                ch.tube((x, 0, -0.77), (x, 0, -0.8), 0.068, 0.068, C("AnkleTie", (0.95, 0.92, 0.84)))
                ch.tube((x, 0, -0.8), (x, -0.01, -0.9), 0.055, 0.055, sock)
            else:
                ch.tube((x, 0, -0.18), (x * 1.05, 0, -0.8), 0.1, 0.09, pants)
                if cuff:
                    ch.tube((x * 1.05, 0, -0.76), (x * 1.05, 0, -0.84), 0.1, 0.1, cuff)
                ch.tube((x * 1.05, 0, -0.83), (x * 1.05, -0.005, -0.9), 0.05, 0.05, SKIN)
        else:
            ch.tube((x, 0, -0.8), (x, -0.01, -0.9), 0.05, 0.05, sock)
        shoe(ch, x)
    ch.cur = "Body"

def sneaker(ch, x):
    w = C("Sneaker", (0.97, 0.97, 0.96), 0.6)
    ch.box((0.13, 0.27, 0.045), (x, -0.05, -0.975), C("Sole", (0.9, 0.89, 0.86)), 0.02)
    ch.sph((0.125, 0.25, 0.11), (x, -0.045, -0.92), w)
    ch.sph((0.13, 0.12, 0.07), (x, 0.03, -0.9), C("Stripe", (0.32, 0.47, 0.78)))
    for k in range(3):
        ch.curve([(x - 0.03, -0.1 + k * 0.035, -0.875), (x + 0.03, -0.1 + k * 0.035, -0.875)], 0.006, w)

def straw_shoe(ch, x):
    s = C("StrawShoe", (0.88, 0.7, 0.36))
    ch.sph((0.12, 0.25, 0.07), (x, -0.05, -0.965), s)
    ch.curve([(x - 0.05, -0.13, -0.94), (x, -0.16, -0.92), (x + 0.05, -0.13, -0.94)], 0.01, s)
    ch.curve([(x - 0.055, -0.02, -0.93), (x, -0.06, -0.9), (x + 0.055, -0.02, -0.93)], 0.01, s)

def black_shoe(ch, x):
    s = C("Shoe", (0.16, 0.12, 0.11), 0.45)
    ch.sph((0.13, 0.27, 0.09), (x, -0.05, -0.955), s)
    ch.sph((0.05, 0.06, 0.04), (x, -0.19, -0.92), s)

def white_shoe(ch, x):
    s = C("Kkotsin", (0.95, 0.55, 0.6))
    ch.sph((0.11, 0.24, 0.07), (x, -0.06, -0.965), s)
    ch.sph((0.04, 0.05, 0.035), (x, -0.19, -0.935), s)

# ---------- 인물 ----------
X = [0]
def nxt():
    X[0] += 3
    return X[0]

def build_hero():
    ch = Char("hero", nxt())
    hc = C("HairBrown", (0.27, 0.17, 0.12))
    face(ch, hc)
    hair_hero(ch, hc)
    jacket = C("Outfit", (0.29, 0.43, 0.76))
    navy = C("Navy", (0.15, 0.2, 0.38))
    ch.lathe([(0.08, 0.37), (0.18, 0.35), (0.255, 0.29), (0.26, 0.2), (0.255, 0.0), (0.26, -0.17), (0.05, -0.17)], jacket, sy=0.78)
    ch.tube((0, 0, -0.16), (0, 0, -0.24), 0.258, 0.25, navy, verts=20, sy=0.8)    # 밑단 고무단
    # 후드 (목 둘레 + 등 뒤)
    ch.curve([(math.cos(a) * 0.13, math.sin(a) * 0.11, 0.35) for a in [2 * math.pi * i / 20 for i in range(21)]], 0.045, navy)
    ch.sph((0.3, 0.14, 0.18), (0, 0.15, 0.33), navy)
    ch.box((0.12, 0.012, 0.4), (0, -0.207, 0.1), C("Shirt", (0.97, 0.92, 0.78)), 0.005)
    ch.box((0.006, 0.012, 0.4), (0.065, -0.209, 0.08), C("Zip", (0.7, 0.7, 0.72)), 0.002)
    gold = C("Gold", (0.96, 0.76, 0.26), 0.3)
    for z in (0.12, 0.0, -0.12):
        ch.sph((0.032, 0.02, 0.032), (0.105, -0.205, z), gold)
    for sx in (-1, 1):
        ch.box((0.1, 0.015, 0.07), (sx * 0.15, -0.19, 0.17), jacket, 0.008)
        ch.box((0.1, 0.012, 0.025), (sx * 0.15, -0.2, 0.2), jacket, 0.006)
        ch.sph((0.022, 0.012, 0.022), (sx * 0.15, -0.205, 0.195), gold)
    # 크로스백
    lea = C("Leather", (0.9, 0.62, 0.24))
    ch.curve([(-0.14, -0.21, 0.31), (0.0, -0.225, 0.12), (0.17, -0.22, -0.08), (0.24, -0.2, -0.14)], 0.018, lea, radii=[1, 1, 1, 1])
    ch.box((0.17, 0.07, 0.15), (0.27, -0.2, -0.22), lea, 0.03)
    ch.box((0.17, 0.02, 0.08), (0.27, -0.24, -0.18), lea, 0.015)
    ch.box((0.03, 0.012, 0.06), (0.27, -0.252, -0.2), C("Buckle", (0.45, 0.26, 0.14)), 0.004)
    sleeves(ch, jacket, cuff=navy)
    legs(ch, sneaker, pants=C("Pants", (0.33, 0.33, 0.38)), cuff=C("Cuff", (0.58, 0.58, 0.62)))
    return ch

def build_heungbu():
    ch = Char("heungbu", nxt())
    hc = C("HairDark", (0.26, 0.16, 0.1))
    face(ch, hc)
    hair_cap(ch, hc)
    topknot(ch, hc)
    headband(ch)
    beard(ch, hc, "goatee")
    for sx in (-1, 1):
        ch.curve([(sx * 0.24, -0.06, HEAD_Z + 0.02), (sx * 0.27, -0.12, HEAD_Z - 0.06), (sx * 0.25, -0.14, HEAD_Z - 0.12)], 0.016, hc)
    band = C("Band", (0.97, 0.94, 0.86))
    jeogori(ch, C("Vest", (0.86, 0.76, 0.6)), hem_z=-0.2, rad=(0.24, 0.3), patch=True, belt=band)
    sleeves(ch, C("Sleeve", (0.96, 0.92, 0.82)), wide=0.025)
    legs(ch, straw_shoe, pants=C("Baji", (0.26, 0.5, 0.52)), baggy=True)
    return ch

def build_nolbu():
    ch = Char("nolbu", nxt())
    hc = C("HairDark", (0.26, 0.16, 0.1))
    face(ch, hc, brows="angry", mouth="smirk", lids="half", wide=1.1)
    hair_cap(ch, hc)
    topknot(ch, hc)
    gat(ch, gold=True)
    beard(ch, hc, "mustache")
    beard(ch, hc, "point")
    coat = C("Coat", (0.86, 0.38, 0.22))
    inner = C("CoatInner", (0.56, 0.22, 0.32))
    ch.lathe([(0.08, 0.38), (0.2, 0.35), (0.3, 0.27), (0.35, 0.12), (0.37, -0.05), (0.36, -0.25), (0.38, -0.55), (0.42, -0.86), (0.4, -0.88), (0.05, -0.88)], coat, sy=0.82)
    ch.lathe([(0.3, -0.6), (0.37, -0.8), (0.385, -0.9), (0.05, -0.9)], inner, sy=0.8)
    ch.curve([(0.06, -0.31, -0.2), (0.1, -0.33, -0.55), (0.12, -0.35, -0.86)], 0.01, inner)
    ch.curve([(math.cos(a) * 0.14, math.sin(a) * 0.12, 0.37) for a in [2 * math.pi * i / 20 for i in range(21)]], 0.025, COLLAR)
    ch.curve([(-0.08, -0.12, 0.36), (0.0, -0.2, 0.28), (0.06, -0.24, 0.2)], 0.016, COLLAR)
    sash = C("Sash", (0.56, 0.22, 0.32))
    ch.tube((0, 0, -0.1), (0, 0, -0.18), 0.375, 0.37, sash, verts=28, sy=0.84)
    ch.sph((0.12, 0.06, 0.08), (0.1, -0.31, -0.14), sash)
    ch.curve([(0.1, -0.31, -0.17), (0.08, -0.32, -0.42)], 0.03, sash)
    ch.curve([(0.12, -0.31, -0.17), (0.15, -0.31, -0.38)], 0.026, sash)
    gold = C("Gold", (0.96, 0.76, 0.26), 0.3)
    ch.sph((0.05, 0.03, 0.05), (0.2, -0.31, -0.24), gold)
    ch.curve([(0.2, -0.31, -0.26), (0.2, -0.32, -0.31)], 0.008, gold)
    ch.tube((0.2, -0.32, -0.31), (0.2, -0.32, -0.46), 0.018, 0.045, gold)
    sleeves(ch, inner, cuff=COLLAR, wide=0.06)
    legs(ch, black_shoe, hidden=True)
    return ch

def build_lady(kind, top, skirt_col, hair_col, brows="kind", mouth="smile"):
    ch = Char(kind, nxt())
    face(ch, hair_col, brows=brows, mouth=mouth)
    hair_cap(ch, hair_col, part=True)
    low_bun(ch, hair_col)
    sk = skirt_col
    ch.lathe([(0.17, 0.2), (0.22, 0.08), (0.28, -0.15), (0.35, -0.45), (0.41, -0.75), (0.44, -0.93), (0.42, -0.97), (0.05, -0.97)], sk, sy=0.9, segs=36)
    ch.lathe([(0.07, 0.38), (0.17, 0.355), (0.23, 0.3), (0.255, 0.2), (0.26, 0.13), (0.24, 0.11), (0.05, 0.11)], top, sy=0.82)
    ch.curve([(-0.1, -0.15, 0.345), (-0.03, -0.19, 0.25), (0.07, -0.2, 0.15)], 0.018, COLLAR)
    ch.curve([(0.1, -0.15, 0.345), (0.05, -0.18, 0.27)], 0.016, COLLAR)
    rib = C("Ribbon", (0.86, 0.3, 0.36))
    ch.sph((0.07, 0.04, 0.05), (0.07, -0.212, 0.15), rib)
    ch.curve([(0.07, -0.22, 0.14), (0.06, -0.25, -0.05), (0.08, -0.29, -0.3)], 0.018, rib, radii=[1, 1, 0.9])
    ch.curve([(0.08, -0.22, 0.14), (0.11, -0.25, -0.02)], 0.016, rib)
    sleeves(ch, top, cuff=COLLAR)
    legs(ch, white_shoe, hidden=True)
    return ch

def build_man(kind, top, pants, hair_col=None, hat=None, beard_kind=None, item=None, kid=False):
    ch = Char(kind, nxt())
    hc = hair_col or C("HairDark", (0.26, 0.16, 0.1))
    face(ch, hc)
    hair_cap(ch, hc)
    if not kid:
        topknot(ch, hc)
    if hat == "gat":
        gat(ch)
    elif hat == "band":
        headband(ch)
    if beard_kind:
        beard(ch, hc, beard_kind)
    jeogori(ch, top, belt=C("Band", (0.97, 0.94, 0.86)) if not kid else None, tie=None if not kid else C("Ribbon", (0.86, 0.3, 0.36)))
    sleeves(ch, top, wide=0.02, hand_item=item)
    legs(ch, straw_shoe, pants=pants, baggy=True)
    return ch

def staff(ch):
    ch.curve([(0.36, -0.06, 0.25), (0.36, -0.07, -0.3), (0.35, -0.07, -0.98)], 0.022, C("Staff", (0.5, 0.33, 0.2)))
    ch.sph((0.1, 0.1, 0.1), (0.36, -0.06, 0.28), C("Staff", (0.5, 0.33, 0.2)))

def club(ch):
    ch.tube((0.35, -0.04, -0.25), (0.42, -0.1, 0.4), 0.035, 0.09, C("Club", (0.56, 0.36, 0.2)))
    for k in range(5):
        a = k * 1.3
        ch.sph((0.035, 0.035, 0.035), (0.4 + math.cos(a) * 0.08, -0.08 + math.sin(a) * 0.08, 0.1 + k * 0.05), C("Stud", (0.92, 0.86, 0.7)))

def build_dokkaebi():
    global SKIN
    ch = Char("dokkaebi", nxt())
    SKIN = C("SkinTeal", (0.42, 0.78, 0.72))
    hc = C("HairNight", (0.14, 0.13, 0.2))
    face(ch, hc, brows="angry", mouth="grin", wide=1.08)
    hair_cap(ch, hc)
    for sx in (-1, 1):
        ch.tube((sx * 0.12, 0, HEAD_Z + 0.24), (sx * 0.18, -0.02, HEAD_Z + 0.42), 0.05, 0.008, C("Horn", (1.0, 0.88, 0.35)))
    ch.sph((0.54, 0.4, 0.24), (0, 0, 0.27), SKIN)
    ch.tube((0, 0, 0.29), (0, 0, -0.1), 0.24, 0.27, SKIN, verts=20, sy=0.8)
    tiger = C("Tiger", (1.0, 0.72, 0.2))
    ch.tube((0, 0, -0.08), (0, 0, -0.4), 0.28, 0.3, tiger, verts=20, sy=0.82)
    for k in range(7):
        a = 2 * math.pi * k / 7
        ch.curve([(math.cos(a) * 0.29, math.sin(a) * 0.24, -0.12), (math.cos(a + 0.25) * 0.3, math.sin(a + 0.25) * 0.25, -0.36)], 0.014, C("Stripe2", (0.16, 0.1, 0.08)))
    sleeves(ch, SKIN, hand_item=club)
    legs(ch, lambda c, x: c.sph((0.13, 0.24, 0.09), (x, -0.04, -0.955), SKIN), pants=SKIN)
    SKIN = SKIN0
    return ch

DK = C("HairDark", (0.26, 0.16, 0.1))
chars = [
    build_hero(), build_heungbu(), build_nolbu(),
    build_lady("wife", C("WifeTop", (1.0, 0.82, 0.74)), C("Outfit", (0.75, 0.3, 0.3)), DK, brows="angry", mouth="smirk"),
    build_lady("suni", C("WhiteTop", (0.98, 0.95, 0.88)), C("Outfit", (0.55, 0.65, 0.85)), DK),
    build_lady("ong", C("GreyTop", (0.9, 0.88, 0.82)), C("Outfit", (0.6, 0.5, 0.55)), C("HairGrey", (0.84, 0.84, 0.88))),
    build_man("kim", C("Outfit", (0.62, 0.55, 0.4)), C("Baji", (0.84, 0.8, 0.68)), hat="gat"),
    build_man("park", C("Outfit", (0.5, 0.6, 0.65)), C("Baji", (0.84, 0.8, 0.68)), hair_col=C("HairWhite", (0.92, 0.92, 0.94)), beard_kind="long"),
    build_man("merchant", C("Outfit", (0.35, 0.58, 0.4)), C("Baji", (0.84, 0.8, 0.68)), hat="band"),
    build_man("woodman", C("Outfit", (0.62, 0.48, 0.34)), C("Baji2", (0.7, 0.62, 0.48)), hat="band", beard_kind="goatee"),
    build_man("sansin", C("Robe", (0.97, 0.97, 1.0)), C("Robe", (0.97, 0.97, 1.0)), hair_col=C("HairWhite", (0.92, 0.92, 0.94)), beard_kind="long", item=staff),
    build_man("kid", C("Outfit", (0.98, 0.8, 0.5)), C("Baji", (0.84, 0.8, 0.68)), kid=True),
    build_man("villager", C("Outfit", (0.7, 0.62, 0.5)), C("Baji", (0.84, 0.8, 0.68))),
    build_dokkaebi(),
]
PIV = {"ArmL": (-0.24, 0, 0.28), "ArmR": (0.24, 0, 0.28), "LegL": (-0.1, 0, -0.18), "LegR": (0.1, 0, -0.18), "Eyes": (0, -0.23, HEAD_Z)}
for ch in chars:
    ch.done(PIV)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=OUT, export_apply=True, export_yup=True, export_materials="EXPORT")
tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in bpy.data.objects if o.type == "MESH")
print("saved", OUT, "triangles", tris, "per char", tris // len(chars))
