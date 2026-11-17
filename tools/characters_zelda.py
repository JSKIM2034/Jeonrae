# 등장인물 v3 (블렌더, 젤다풍 비율). 키 2 (발바닥 z=-1, 머리카락 끝 z=+1), 앞쪽 = -Y.
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

SKIN0 = C("Skin", (0.96, 0.77, 0.63))
SKIN = SKIN0
BLUSH = C("Blush", (1.0, 0.76, 0.7))
WHITE = C("EyeWhite", (1.0, 1.0, 1.0), 0.25)
IRIS = C("Iris", (0.32, 0.18, 0.1), 0.25)
PUPIL = C("Pupil", (0.07, 0.04, 0.03), 0.25)
LID = C("Lid", (0.2, 0.12, 0.09))
MOUTH = C("Mouth", (0.62, 0.3, 0.27))
COLLAR = C("Collar", (0.98, 0.96, 0.9))
SOCK = C("Beoseon", (0.97, 0.96, 0.93))

HEAD_Z = 0.64          # 머리 부품을 설계한 기준 좌표 (아래에서 줄이고 옮겨요)
HR = (0.265, 0.245, 0.275)
HS = 0.62              # 머리 크기 비율: 키가 머리 5.5개쯤
HZN = 0.79             # 실제 머리 중심 높이

class Char:
    def __init__(self, kind, ox):
        self.kind, self.ox = kind, ox
        self.groups = {k: [] for k in ("Body", "Eyes", "ArmL", "ArmR", "ForeL", "ForeR", "LegL", "LegR", "ShinL", "ShinR")}
        self.cur = "Body"
        self.hm = True     # 머리 모드: 머리 좌표를 줄여서 목 위로 옮겨요
    def P(self, p):
        if self.hm:
            return (p[0] * HS + self.ox, p[1] * HS, HZN + (p[2] - HEAD_Z) * HS)
        return (p[0] + self.ox, p[1], p[2])
    def k(self):
        return HS if self.hm else 1.0
    def add(self, o):
        self.groups[self.cur].append(o)
        b.parts.remove(o)
        return o
    def sph(self, size, loc, m, rot=(0, 0, 0), segs=16, rings=10):
        k = self.k()
        return self.add(b.blob(tuple(x * k for x in size), self.P(loc), m, rot, segs, rings))
    def tube(self, p0, p1, r0, r1, m, verts=16, sy=1.0):
        r0, r1 = r0 * self.k(), r1 * self.k()
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
        return self.add(b.curve([self.P(p) for p in pts], r * self.k(), m, res=res, radii=radii))
    def lathe(self, prof, m, sy=0.85, segs=32, cy=0.0):
        self.hm = False
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
        k = self.k()
        return self.add(b.box(tuple(x * k for x in size), self.P(loc), m, bevel * k, rot, segs=2))
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
    ch.sph((0.42 * wide, 0.34, 0.24), (0, -0.05, hz - 0.1), SKIN, segs=20, rings=12)       # 볼
    ch.sph((0.2 * wide, 0.2, 0.16), (0, -0.1, hz - 0.2), SKIN, segs=16, rings=10)         # 갸름한 턱 끝
    ch.tube((0, 0.01, hz - 0.2), (0, 0.01, hz - 0.5), 0.085, 0.095, SKIN)              # 목
    for sx in (-1, 1):
        ch.sph((0.08, 0.05, 0.12), (sx * 0.262 * wide, 0.02, hz - 0.02), SKIN)         # 귀
        ch.sph((0.045, 0.03, 0.06), (sx * 0.272 * wide, -0.005, hz - 0.02), C("EarIn", (0.95, 0.72, 0.62)))
        ch.sph((0.08, 0.015, 0.045), (sx * 0.155, -0.218, hz - 0.075), BLUSH)
    ch.sph((0.045, 0.05, 0.07), (0, -0.24, hz - 0.035), SKIN, rot=(0.35, 0, 0))   # 콧대
    ch.sph((0.05, 0.04, 0.04), (0, -0.252, hz - 0.068), C("Nose", (0.99, 0.78, 0.66)))
    # 눈썹
    for sx in (-1, 1):
        if brows == "angry":
            pts = [(sx * 0.045, -0.235, hz + 0.06), (sx * 0.1, -0.235, hz + 0.088), (sx * 0.165, -0.21, hz + 0.105)]
        else:
            pts = [(sx * 0.05, -0.238, hz + 0.088), (sx * 0.1, -0.24, hz + 0.1), (sx * 0.15, -0.222, hz + 0.093)]
        ch.curve(pts, 0.012, brow_col, radii=[0.8, 1.0, 0.5])
    # 입
    if mouth == "smile":
        ch.curve([(-0.05, -0.236, hz - 0.13), (-0.017, -0.247, hz - 0.146), (0.017, -0.247, hz - 0.146), (0.05, -0.236, hz - 0.13)], 0.01, MOUTH)
    elif mouth == "smirk":
        ch.curve([(-0.05, -0.243, hz - 0.14), (0.0, -0.25, hz - 0.142), (0.05, -0.238, hz - 0.122)], 0.009, MOUTH)
    elif mouth == "grin":
        ch.sph((0.13, 0.03, 0.06), (0, -0.24, hz - 0.14), MOUTH)
        ch.box((0.1, 0.012, 0.022), (0, -0.255, hz - 0.125), WHITE, 0.004)
    # 눈 (깜빡일 수 있게 따로)
    ch.cur = "Eyes"
    for sx in (-1, 1):
        x = sx * 0.1
        # 갸름한 아몬드 눈: 가로로 길고, 눈동자는 진하고, 빛은 작게
        ch.sph((0.11, 0.03, 0.068), (x, -0.224, hz), WHITE, rot=(0, sx * 0.12, 0))
        ch.sph((0.062, 0.03, 0.066), (x + sx * 0.004, -0.233, hz - 0.002), IRIS)
        ch.sph((0.032, 0.02, 0.036), (x + sx * 0.004, -0.242, hz - 0.002), PUPIL)
        ch.sph((0.014, 0.01, 0.014), (x + 0.012, -0.247, hz + 0.014), WHITE)
        ch.curve([(x - sx * 0.055, -0.22, hz + 0.004), (x - sx * 0.02, -0.236, hz + 0.034), (x + sx * 0.03, -0.236, hz + 0.036), (x + sx * 0.062, -0.217, hz + 0.012)], 0.0075, LID)
        ch.curve([(x - 0.035, -0.232, hz - 0.03), (x + 0.035, -0.232, hz - 0.03)], 0.003, C("LowLid", (0.82, 0.6, 0.52)))
        if lids == "half":
            ch.sph((0.115, 0.035, 0.04), (x, -0.228, hz + 0.022), SKIN)
            ch.curve([(x - 0.05, -0.238, hz + 0.008), (x + 0.05, -0.238, hz + 0.008)], 0.008, LID)
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
    else:
        # 이마 위 잔머리와 귀 앞 구레나룻 (머리카락 결)
        for k in range(-3, 4):
            x = k * 0.05
            ch.curve([(x * 1.2, -0.12, hz + 0.27), (x * 1.3, -0.21, hz + 0.21), (x * 1.25 + 0.015, -0.235, hz + 0.16)], 0.03, col, radii=[1, 0.8, 0.25])
        for sx in (-1, 1):
            ch.curve([(sx * 0.24, -0.08, hz + 0.12), (sx * 0.255, -0.12, hz + 0.03), (sx * 0.25, -0.13, hz - 0.04)], 0.028, col, radii=[1, 0.7, 0.2])

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
        ch.sph((0.04, 0.025, 0.035), (0, -0.215, hz - 0.225), col)
    elif kind == "point":
        ch.tube((0, -0.225, hz - 0.17), (0, -0.21, hz - 0.25), 0.035, 0.006, col)
    elif kind == "long":
        ch.sph((0.24, 0.12, 0.34), (0, -0.19, hz - 0.28), col)
        ch.tube((0, -0.2, hz - 0.35), (0, -0.19, hz - 0.55), 0.08, 0.01, col)
    elif kind == "mustache":
        for sx in (-1, 1):
            ch.curve([(0, -0.25, hz - 0.095), (sx * 0.05, -0.248, hz - 0.1), (sx * 0.1, -0.235, hz - 0.085), (sx * 0.12, -0.225, hz - 0.06)], 0.014, col, radii=[1, 1, 0.7, 0.3])

# ---------- 옷 (실제 크기 좌표: 어깨 z 0.5, 허리 0.1, 엉덩이 0, 발목 -0.88) ----------
def jeogori(ch, col, hem_z=-0.06, collar=COLLAR, tie=None, patch=False, belt=None, flare=0.24):
    ch.hm = False
    ch.lathe([(0.06, 0.585), (0.12, 0.565), (0.19, 0.51), (0.2, 0.4), (0.19, 0.25), (0.205, 0.1), (flare, hem_z), (flare - 0.015, hem_z - 0.02), (0.04, hem_z - 0.02)], col, sy=0.72)
    ch.curve([(-0.08, -0.1, 0.58), (-0.03, -0.14, 0.48), (0.05, -0.148, 0.34), (0.09, -0.15, 0.26)], 0.016, collar)
    ch.curve([(0.08, -0.1, 0.58), (0.04, -0.135, 0.5)], 0.014, collar)
    if tie:
        ch.sph((0.05, 0.03, 0.035), (0.09, -0.155, 0.27), tie)
        ch.curve([(0.09, -0.158, 0.26), (0.08, -0.17, 0.15), (0.095, -0.17, 0.06)], 0.012, tie)
        ch.curve([(0.1, -0.158, 0.26), (0.13, -0.155, 0.17)], 0.012, tie)
    if belt:
        ch.tube((0, 0, 0.13), (0, 0, 0.09), 0.215, 0.217, belt, verts=24, sy=0.74)
        ch.sph((0.075, 0.035, 0.045), (-0.03, -0.165, 0.11), belt, rot=(0, 0.3, 0))
        ch.sph((0.075, 0.035, 0.045), (0.045, -0.165, 0.11), belt, rot=(0, -0.3, 0))
        ch.curve([(0.0, -0.168, 0.1), (-0.015, -0.175, 0.0)], 0.011, belt)
        ch.curve([(0.015, -0.168, 0.1), (0.035, -0.175, 0.01)], 0.011, belt)
    if patch:
        ch.box((0.06, 0.01, 0.055), (-0.13, -0.163, 0.02), C("Patch", (0.62, 0.56, 0.62)), 0.005)

def sleeves(ch, col, cuff=None, wide=0.0, hand_item=None, glove=None):
    ch.hm = False
    for side, sx in (("ArmL", -1), ("ArmR", 1)):
        ch.cur = side
        sh = (sx * 0.2, 0, 0.49)
        el = (sx * 0.245, 0.0, 0.22)
        wr = (sx * 0.27, -0.02, -0.02)
        ch.sph((0.12, 0.12, 0.12), sh, col)
        ch.tube(sh, el, 0.055, 0.052 + wide * 0.4, col)
        ch.sph((0.1 + wide * 0.8, 0.1 + wide * 0.8, 0.1), el, col)
        ch.cur = "Fore" + side[-1]          # 팔꿈치 아래는 따로 (접히게)
        ch.sph((0.098 + wide * 0.8, 0.098 + wide * 0.8, 0.098), el, col)
        ch.tube(el, wr, 0.052 + wide * 0.4, 0.05 + wide, col)
        if cuff:
            ch.tube((sx * 0.268, -0.02, 0.02), (sx * 0.272, -0.02, -0.035), 0.052 + wide, 0.054 + wide, cuff)
        sk = glove or SKIN
        ch.tube((sx * 0.272, -0.02, -0.02), (sx * 0.275, -0.022, -0.045), 0.032, 0.034, sk)
        ch.sph((0.06, 0.032, 0.075), (sx * 0.278, -0.022, -0.085), sk)
        ch.sph((0.05, 0.03, 0.055), (sx * 0.276, -0.024, -0.135), sk)
        ch.sph((0.022, 0.02, 0.045), (sx * 0.262, -0.05, -0.08), sk, rot=(0.3, 0, sx * 0.4))
        if hand_item and sx == 1:
            hand_item(ch)
    ch.cur = "Body"

def legs(ch, shoe, pants=None, baggy=False, cuff=None, hidden=False, sock=SOCK):
    ch.hm = False
    for side, sx in (("LegL", -1), ("LegR", 1)):
        ch.cur = side
        x = sx * 0.085
        if pants and not hidden:
            if baggy:
                ch.sph((0.19, 0.19, 0.5), (x * 1.15, 0, -0.22), pants)
                ch.cur = "Shin" + side[-1]
                ch.sph((0.17, 0.17, 0.36), (x * 1.1, 0, -0.52), pants)
                ch.tube((x, 0, -0.6), (x, -0.005, -0.76), 0.06, 0.05, pants)
                ch.tube((x, 0, -0.72), (x, 0, -0.76), 0.055, 0.055, C("AnkleTie", (0.95, 0.92, 0.84)))
                ch.tube((x, 0, -0.76), (x, -0.008, -0.88), 0.042, 0.042, sock)
            else:
                ch.tube((x, 0, 0.02), (x * 1.04, 0, -0.42), 0.085, 0.072, pants)
                ch.sph((0.15, 0.15, 0.12), (x * 1.04, -0.005, -0.42), pants)
                ch.cur = "Shin" + side[-1]
                ch.sph((0.144, 0.144, 0.12), (x * 1.04, -0.005, -0.42), pants)
                ch.tube((x * 1.04, 0, -0.42), (x * 1.06, 0, -0.8), 0.072, 0.068, pants)
                if cuff:
                    ch.tube((x * 1.06, 0, -0.76), (x * 1.06, 0, -0.83), 0.078, 0.078, cuff)
                ch.tube((x * 1.06, 0, -0.82), (x * 1.06, -0.005, -0.88), 0.04, 0.04, SKIN)
        else:
            ch.cur = "Shin" + side[-1]
            ch.tube((x, 0, -0.78), (x, -0.008, -0.88), 0.042, 0.042, sock)
        ch.cur = "Shin" + side[-1]
        shoe(ch, x)
    ch.cur = "Body"

def sneaker(ch, x):
    w = C("Sneaker", (0.97, 0.97, 0.96), 0.6)
    ch.box((0.1, 0.22, 0.035), (x, -0.04, -0.98), C("Sole", (0.9, 0.89, 0.86)), 0.015)
    ch.sph((0.096, 0.2, 0.085), (x, -0.035, -0.935), w)
    ch.sph((0.1, 0.1, 0.06), (x, 0.03, -0.92), C("Stripe", (0.32, 0.47, 0.78)))
    for k in range(3):
        ch.curve([(x - 0.025, -0.085 + k * 0.03, -0.9), (x + 0.025, -0.085 + k * 0.03, -0.9)], 0.005, w)

def straw_shoe(ch, x):
    s = C("StrawShoe", (0.88, 0.7, 0.36))
    ch.sph((0.095, 0.2, 0.055), (x, -0.04, -0.97), s)
    ch.curve([(x - 0.04, -0.1, -0.95), (x, -0.125, -0.935), (x + 0.04, -0.1, -0.95)], 0.008, s)
    ch.curve([(x - 0.045, -0.01, -0.945), (x, -0.045, -0.92), (x + 0.045, -0.01, -0.945)], 0.008, s)

def black_shoe(ch, x):
    s = C("Shoe", (0.16, 0.12, 0.11), 0.45)
    ch.sph((0.1, 0.22, 0.07), (x, -0.04, -0.965), s)
    ch.sph((0.04, 0.05, 0.03), (x, -0.155, -0.94), s)

def white_shoe(ch, x):
    s = C("Kkotsin", (0.95, 0.55, 0.6))
    ch.sph((0.09, 0.2, 0.055), (x, -0.05, -0.97), s)
    ch.sph((0.035, 0.04, 0.028), (x, -0.155, -0.948), s)

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
    ch.hm = False
    ch.lathe([(0.06, 0.585), (0.12, 0.565), (0.2, 0.51), (0.205, 0.4), (0.19, 0.25), (0.2, 0.08), (0.205, 0.0), (0.04, 0.0)], jacket, sy=0.72)
    ch.tube((0, 0, 0.02), (0, 0, -0.04), 0.208, 0.205, navy, verts=24, sy=0.74)
    ch.curve([(math.cos(a) * 0.1, math.sin(a) * 0.085, 0.58) for a in [2 * math.pi * i / 20 for i in range(21)]], 0.032, navy)
    ch.sph((0.22, 0.1, 0.14), (0, 0.11, 0.55), navy)
    ch.box((0.09, 0.008, 0.46), (0, -0.152, 0.3), C("Shirt", (0.97, 0.92, 0.78)), 0.004)
    ch.box((0.005, 0.008, 0.44), (0.05, -0.154, 0.28), C("Zip", (0.7, 0.7, 0.72)), 0.002)
    gold = C("Gold", (0.96, 0.76, 0.26), 0.3)
    for z in (0.38, 0.26, 0.14):
        ch.sph((0.024, 0.015, 0.024), (0.075, -0.155, z), gold)
    for sx in (-1, 1):
        ch.box((0.075, 0.012, 0.055), (sx * 0.11, -0.145, 0.42), jacket, 0.006)
        ch.box((0.075, 0.01, 0.02), (sx * 0.11, -0.152, 0.445), jacket, 0.004)
    lea = C("Leather", (0.9, 0.62, 0.24))
    ch.curve([(-0.11, -0.155, 0.55), (0.0, -0.165, 0.35), (0.13, -0.165, 0.12), (0.18, -0.15, 0.04)], 0.013, lea)
    ch.box((0.13, 0.055, 0.115), (0.2, -0.15, -0.03), lea, 0.022)
    ch.box((0.13, 0.015, 0.06), (0.2, -0.18, 0.0), lea, 0.012)
    ch.box((0.024, 0.01, 0.045), (0.2, -0.19, -0.015), C("Buckle", (0.45, 0.26, 0.14)), 0.003)
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
    jeogori(ch, C("Vest", (0.86, 0.76, 0.6)), patch=True, belt=band)
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
    ch.hm = False
    ch.lathe([(0.06, 0.585), (0.13, 0.565), (0.21, 0.5), (0.24, 0.38), (0.27, 0.2), (0.265, 0.02), (0.27, -0.2), (0.3, -0.5), (0.33, -0.86), (0.31, -0.88), (0.04, -0.88)], coat, sy=0.82)
    ch.lathe([(0.24, -0.6), (0.29, -0.8), (0.3, -0.9), (0.04, -0.9)], inner, sy=0.8)
    ch.curve([(0.04, -0.215, 0.05), (0.07, -0.24, -0.4), (0.09, -0.27, -0.86)], 0.008, inner)
    ch.curve([(math.cos(a) * 0.1, math.sin(a) * 0.09, 0.58) for a in [2 * math.pi * i / 20 for i in range(21)]], 0.018, COLLAR)
    ch.curve([(-0.06, -0.09, 0.575), (0.0, -0.17, 0.48), (0.05, -0.2, 0.4)], 0.012, COLLAR)
    sash = C("Sash", (0.56, 0.22, 0.32))
    ch.tube((0, 0, 0.1), (0, 0, 0.04), 0.272, 0.27, sash, verts=28, sy=0.84)
    ch.sph((0.09, 0.045, 0.06), (0.07, -0.225, 0.07), sash)
    ch.curve([(0.07, -0.23, 0.05), (0.055, -0.24, -0.16)], 0.022, sash)
    ch.curve([(0.09, -0.23, 0.05), (0.12, -0.23, -0.12)], 0.019, sash)
    gold = C("Gold", (0.96, 0.76, 0.26), 0.3)
    ch.sph((0.04, 0.025, 0.04), (0.16, -0.225, 0.0), gold)
    ch.curve([(0.16, -0.23, -0.02), (0.16, -0.235, -0.06)], 0.006, gold)
    ch.tube((0.16, -0.235, -0.06), (0.16, -0.235, -0.18), 0.014, 0.034, gold)
    sleeves(ch, inner, cuff=COLLAR, wide=0.045)
    legs(ch, black_shoe, hidden=True)
    return ch

def build_lady(kind, top, skirt_col, hair_col, brows="kind", mouth="smile"):
    ch = Char(kind, nxt())
    face(ch, hair_col, brows=brows, mouth=mouth)
    hair_cap(ch, hair_col, part=True)
    low_bun(ch, hair_col)
    sk = skirt_col
    ch.hm = False
    ch.lathe([(0.13, 0.43), (0.16, 0.32), (0.21, 0.05), (0.27, -0.35), (0.32, -0.75), (0.34, -0.93), (0.32, -0.97), (0.04, -0.97)], sk, sy=0.9, segs=36)
    ch.lathe([(0.06, 0.585), (0.12, 0.565), (0.18, 0.51), (0.19, 0.42), (0.195, 0.36), (0.18, 0.34), (0.04, 0.34)], top, sy=0.76)
    ch.curve([(-0.075, -0.1, 0.58), (-0.02, -0.135, 0.49), (0.05, -0.14, 0.38)], 0.013, COLLAR)
    ch.curve([(0.075, -0.1, 0.58), (0.04, -0.13, 0.51)], 0.012, COLLAR)
    rib = C("Ribbon", (0.86, 0.3, 0.36))
    ch.sph((0.05, 0.03, 0.035), (0.055, -0.145, 0.38), rib)
    ch.curve([(0.055, -0.15, 0.37), (0.045, -0.17, 0.2), (0.06, -0.2, 0.0)], 0.013, rib)
    ch.curve([(0.065, -0.15, 0.37), (0.09, -0.17, 0.24)], 0.012, rib)
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
    ch.curve([(0.29, -0.06, 0.45), (0.29, -0.07, -0.2), (0.28, -0.07, -0.98)], 0.018, C("Staff", (0.5, 0.33, 0.2)))
    ch.sph((0.08, 0.08, 0.08), (0.29, -0.06, 0.48), C("Staff", (0.5, 0.33, 0.2)))

def club(ch):
    ch.tube((0.28, -0.04, -0.15), (0.33, -0.1, 0.5), 0.03, 0.075, C("Club", (0.56, 0.36, 0.2)))
    for k in range(5):
        a = k * 1.3
        ch.sph((0.03, 0.03, 0.03), (0.31 + math.cos(a) * 0.065, -0.08 + math.sin(a) * 0.065, 0.2 + k * 0.05), C("Stud", (0.92, 0.86, 0.7)))

def build_dokkaebi():
    global SKIN
    ch = Char("dokkaebi", nxt())
    SKIN = C("SkinTeal", (0.42, 0.78, 0.72))
    hc = C("HairNight", (0.14, 0.13, 0.2))
    face(ch, hc, brows="angry", mouth="grin", wide=1.08)
    hair_cap(ch, hc)
    for sx in (-1, 1):
        ch.tube((sx * 0.12, 0, HEAD_Z + 0.24), (sx * 0.18, -0.02, HEAD_Z + 0.42), 0.05, 0.008, C("Horn", (1.0, 0.88, 0.35)))
    ch.hm = False
    ch.lathe([(0.06, 0.585), (0.13, 0.565), (0.22, 0.5), (0.23, 0.35), (0.22, 0.15), (0.21, 0.1), (0.04, 0.1)], SKIN, sy=0.78)
    tiger = C("Tiger", (1.0, 0.72, 0.2))
    ch.lathe([(0.2, 0.14), (0.22, 0.05), (0.24, -0.2), (0.22, -0.22), (0.04, -0.22)], tiger, sy=0.8)
    for k in range(7):
        a = 2 * math.pi * k / 7
        ch.curve([(math.cos(a) * 0.222, math.sin(a) * 0.18, 0.1), (math.cos(a + 0.25) * 0.24, math.sin(a + 0.25) * 0.195, -0.18)], 0.011, C("Stripe2", (0.16, 0.1, 0.08)))
    sleeves(ch, SKIN, hand_item=club)
    legs(ch, lambda c, x: c.sph((0.1, 0.2, 0.07), (x, -0.04, -0.965), SKIN), pants=SKIN)
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
PIV = {"ArmL": (-0.2, 0, 0.49), "ArmR": (0.2, 0, 0.49), "ForeL": (-0.245, 0, 0.22), "ForeR": (0.245, 0, 0.22),
       "LegL": (-0.085, 0, 0.0), "LegR": (0.085, 0, 0.0), "ShinL": (-0.088, 0, -0.42), "ShinR": (0.088, 0, -0.42), "Eyes": (0, -0.23 * HS, HZN)}
for ch in chars:
    ch.done(PIV)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=OUT, export_apply=True, export_yup=True, export_materials="EXPORT")
tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in bpy.data.objects if o.type == "MESH")
print("saved", OUT, "triangles", tris, "per char", tris // len(chars))
