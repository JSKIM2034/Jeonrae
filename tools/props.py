# 소품: 옹기 항아리, 우물 돌테, 볏가리(짚더미), 그루터기와 도끼·장작, 장승(남/여)
# 사용: python3 props.py 출력폴더   -> prop_*.glb (그늘은 bake_ao.py로 따로 구워요)
import bpy, bmesh, sys, math, random
from mathutils import Vector, noise, Matrix
OUT = sys.argv[-1]

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)

def mat(name):
    return bpy.data.materials.get(name) or bpy.data.materials.new(name)

def obj_from_bm(bm, name, m):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    me.materials.append(mat(m))
    for p in me.polygons:
        p.use_smooth = True
    return o

def lathe(profile, m, steps=28, name="lathe", uv=True, wobble=0.0, seed=0):
    """profile: [(반지름, 높이)] 아래→위. u는 둘레, v는 옆선을 따라가요"""
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.new("UVMap")
    rows = []
    total = 0.0
    lens = [0.0]
    for i in range(1, len(profile)):
        total += math.dist(profile[i], profile[i - 1])
        lens.append(total)
    for i, (r, z) in enumerate(profile):
        row = []
        for k in range(steps + 1):
            a = 2 * math.pi * k / steps
            rr = r * (1 + wobble * noise.noise(Vector((math.cos(a) * 2, math.sin(a) * 2, z * 3 + seed))))
            row.append((bm.verts.new((rr * math.cos(a), rr * math.sin(a), z)) if k < steps else None, (k / steps, lens[i] / max(total, 1e-6))))
        row[steps] = (row[0][0], row[steps][1])
        rows.append(row)
    for i in range(len(rows) - 1):
        for k in range(steps):
            a, b2 = rows[i][k], rows[i][k + 1]
            c, d = rows[i + 1][k], rows[i + 1][k + 1]
            vs = [a[0], b2[0], d[0], c[0]]
            if len(set(vs)) < 3:
                continue
            try:
                f = bm.faces.new(vs if len(set(vs)) == 4 else list(dict.fromkeys(vs)))
            except ValueError:
                continue
            for loop, src in zip(f.loops, [a, b2, d, c]):
                loop[uvl].uv = src[1]
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    return obj_from_bm(bm, name, m)

def disc(r, z, m, steps=28, name="disc", uv_planar=True, up=True):
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.new("UVMap")
    vs = [bm.verts.new((r * math.cos(2 * math.pi * k / steps), r * math.sin(2 * math.pi * k / steps), z)) for k in range(steps)]
    f = bm.faces.new(vs if up else list(reversed(vs)))
    for loop in f.loops:
        co = loop.vert.co
        loop[uvl].uv = (co.x / (2 * r) + 0.5, co.y / (2 * r) + 0.5)
    return obj_from_bm(bm, name, m)

def box(size, loc, m, rot=(0, 0, 0), bevel=0.02):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    o = bpy.context.object
    o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    if bevel:
        md = o.modifiers.new("b", "BEVEL"); md.width = bevel; md.segments = 2
        bpy.ops.object.modifier_apply(modifier="b")
    o.data.materials.append(mat(m))
    return o

def blob(size, loc, m, rot=(0, 0, 0), sub=2, lump=0.0, seed=0):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=sub, radius=0.5, location=loc, rotation=rot)
    o = bpy.context.object
    for v in o.data.vertices:
        v.co = v.co * (1 + lump * noise.noise(v.co * 4 + Vector((seed, seed, seed))))
    o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    o.data.materials.append(mat(m))
    for p in o.data.polygons:
        p.use_smooth = True
    return o

def cyl(r1, r2, h, loc, m, rot=(0, 0, 0), verts=14):
    bpy.ops.mesh.primitive_cone_add(radius1=r1, radius2=r2, depth=h, location=loc, rotation=rot, vertices=verts)
    o = bpy.context.object
    o.data.materials.append(mat(m))
    for p in o.data.polygons:
        p.use_smooth = len(p.vertices) == 4
    return o

def export(name):
    objs = [o for o in bpy.data.objects if o.type == "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    bpy.ops.export_scene.gltf(filepath=f"{OUT}/prop_{name}.glb", export_format="GLB", use_selection=True)
    print("EXPORTED", name)

# ---- 옹기 항아리 (s=1일 때 키 약 1.3) ----
reset()
body = [(0.2, 0.0), (0.3, 0.02), (0.42, 0.18), (0.51, 0.42), (0.53, 0.58), (0.49, 0.76), (0.4, 0.9), (0.3, 0.99), (0.255, 1.03), (0.26, 1.09), (0.3, 1.12), (0.29, 1.14), (0.24, 1.13)]
lathe(body, "Onggi", steps=32, name="jar", wobble=0.012, seed=1)
disc(0.2, 0.0, "OnggiDark", steps=32, up=False)
lid = [(0.31, 1.12), (0.32, 1.14), (0.27, 1.2), (0.17, 1.25), (0.06, 1.27), (0.065, 1.29), (0.08, 1.31), (0.06, 1.34), (0.0, 1.345)]
lathe(lid, "OnggiDark", steps=32, name="lid")
# 어깨의 띠 무늬
lathe([(0.495, 0.755), (0.505, 0.765), (0.49, 0.78)], "OnggiDark", steps=32, name="band")
export("jar")

# ---- 우물 돌테: 둥글게 맞춘 돌 두 줄 + 위 덮개돌 ----
reset()
random.seed(3)
for course, (z, h) in enumerate([(0.22, 0.42), (0.6, 0.36)]):
    n = 11
    for i in range(n):
        a = 2 * math.pi * (i + 0.5 * course) / n
        w = 2 * math.pi * 0.8 / n * 1.04
        o = blob((w, 0.3, h), (math.cos(a) * 0.8, math.sin(a) * 0.8, z), "Stone", rot=(0, 0, a + math.pi / 2), sub=2, lump=0.12, seed=i * 3 + course)
        ca = o.data.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
        k = random.uniform(0.75, 1.0)
        tone = random.choice([(0.82, 0.8, 0.76), (0.8, 0.76, 0.68), (0.74, 0.76, 0.78)])
        for d in ca.data:
            d.color = (tone[0] * k, tone[1] * k, tone[2] * k, 1)
for i in range(9):
    a = 2 * math.pi * i / 9
    o = blob((0.62, 0.42, 0.14), (math.cos(a) * 0.8, math.sin(a) * 0.8, 0.86), "Stone", rot=(0, 0, a + math.pi / 2), sub=2, lump=0.08, seed=50 + i)
    ca = o.data.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
    k = random.uniform(0.82, 1.0)
    for d in ca.data:
        d.color = (0.85 * k, 0.83 * k, 0.8 * k, 1)
lathe([(0.68, 0.0), (0.66, 0.8)], "Clay", steps=24, name="inner")
for o in bpy.data.objects:
    if o.type == "MESH" and not o.data.color_attributes:
        ca = o.data.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
        for d in ca.data:
            d.color = (1, 1, 1, 1)
export("wellring")

# ---- 볏가리 (짚더미): 층층이 덮은 짚 + 꼭대기 매듭 ----
reset()
prof = [(0.85, 0.0), (0.88, 0.12), (0.84, 0.32), (0.9, 0.36), (0.8, 0.6), (0.84, 0.64), (0.66, 0.9), (0.7, 0.94), (0.45, 1.18), (0.48, 1.21), (0.2, 1.42), (0.08, 1.52), (0.0, 1.55)]
o = lathe(prof, "Thatch", steps=26, name="hay", wobble=0.05, seed=4)
o.scale = (1.0, 0.82, 1.0)
cyl(0.1, 0.03, 0.35, (0, 0, 1.62), "Straw")
for z in (0.62, 1.0):
    bpy.ops.mesh.primitive_torus_add(major_radius=0.78 if z < 0.8 else 0.6, minor_radius=0.025, location=(0, 0, z))
    t = bpy.context.object
    t.scale = (1.0, 0.82, 1.0)
    t.data.materials.append(mat("Rope"))
export("hay")

# ---- 그루터기 + 도끼 + 장작 ----
reset()
prof = [(0.66, 0.0), (0.56, 0.08), (0.5, 0.25), (0.48, 0.5), (0.47, 0.7)]
lathe(prof, "Bark", steps=22, name="stump", wobble=0.06, seed=7)
disc(0.47, 0.7, "EndGrain", steps=22)
for k in range(5):   # 뿌리
    a = k * 2 * math.pi / 5 + 0.3
    cyl(0.14, 0.04, 0.6, (math.cos(a) * 0.55, math.sin(a) * 0.55, 0.06), "Bark", rot=(math.pi / 2 - 0.25, 0, a + math.pi / 2), verts=8)
# 도끼: 자루 + 쇠날 (그루터기에 비스듬히 꽂혀 있어요)
cyl(0.035, 0.03, 0.8, (0.08, 0.0, 1.02), "Wood", rot=(0, -0.35, 0), verts=8)
box((0.26, 0.04, 0.17), (-0.04, 0.0, 0.76), "Iron", rot=(0, -0.35, 0), bevel=0.01)
# 장작 더미 (반으로 쪼갠 통나무)
random.seed(8)
for row, z in enumerate((0.12, 0.33)):
    for i in range(4 - row):
        y = -0.36 + i * 0.24 + row * 0.12
        x = 1.05
        o = cyl(0.12, 0.12, 0.72, (x, y, z), "Bark", rot=(0, math.pi / 2, random.uniform(-0.1, 0.1)), verts=10)
        for end in (-1, 1):
            d = disc(0.115, 0.0, "EndGrain", steps=10)
            d.location = (x + end * 0.361, y, z)
            d.rotation_euler = (0, end * math.pi / 2, 0)
export("stump")

# ---- 장승: 남(천하대장군) / 여(지하여장군) ----
for female in (False, True):
    reset()
    prof = [(0.3, 0.0), (0.29, 0.4), (0.27, 1.0), (0.26, 1.6), (0.25, 2.1), (0.24, 2.5)]
    lathe(prof, "Wood", steps=18, name="pole", wobble=0.04, seed=11 if female else 12)
    # 모자
    if female:
        lathe([(0.3, 2.45), (0.33, 2.55), (0.3, 2.68), (0.2, 2.8), (0.08, 2.86), (0.0, 2.87)], "PaintRed", steps=18, name="hat")
        blob((0.14, 0.14, 0.14), (0, 0, 2.9), "PaintRed")
    else:
        lathe([(0.44, 2.45), (0.45, 2.5), (0.29, 2.52), (0.27, 2.85), (0.22, 2.95), (0.0, 2.97)], "PaintBlack", steps=18, name="hat")
    fy = -0.24   # 얼굴은 -y 쪽(정면)
    for sx in (-1, 1):
        blob((0.2, 0.08, 0.18), (sx * 0.11, fy - 0.01, 2.2), "Lime")                       # 눈흰자
        blob((0.08, 0.06, 0.08), (sx * 0.11, fy - 0.06, 2.2), "PaintBlack")                  # 눈동자
        blob((0.24, 0.08, 0.06), (sx * 0.13, fy - 0.03, 2.36), "PaintBlack", rot=(0, sx * 0.35, 0))   # 눈썹
        if female:
            blob((0.1, 0.03, 0.07), (sx * 0.16, fy - 0.02, 2.0), "PaintRed")                 # 볼연지
    blob((0.12, 0.14, 0.2), (0, fy - 0.06, 2.06), "Wood", lump=0.05)                       # 코
    blob((0.28, 0.07, 0.1), (0, fy - 0.02, 1.84), "PaintBlack")                              # 입
    for i in range(5):
        blob((0.045, 0.03, 0.05), (-0.09 + i * 0.045, fy - 0.07, 1.86), "Lime")               # 이빨
    if not female:
        blob((0.08, 0.04, 0.2), (0, fy - 0.02, 1.66), "PaintBlack")                           # 수염
    # 글씨 칸 (세로 띠)
    box((0.2, 0.02, 1.0), (0, fy + 0.01, 1.0), "Lime" if female else "Lime", bevel=0.005)
    export("jangseung_f" if female else "jangseung_m")
