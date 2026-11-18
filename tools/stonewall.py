# 돌담 한 칸(길이 2m): 흙 속에 박힌 둥근 돌 + 위에 짚(이엉) 또는 기와를 얹어요
# 사용: python3 stonewall.py 출력.glb straw|tile
import bpy, bmesh, sys, math, random
from mathutils import Vector, noise
dst, cap = sys.argv[-2], sys.argv[-1]
random.seed(5 if cap == "straw" else 9)
bpy.ops.wm.read_factory_settings(use_empty=True)
L, H, D = 2.0, 1.0, 0.62

def mat(name):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    return m

objs = []
def add(obj, m):
    obj.data.materials.append(mat(m))
    objs.append(obj)
    return obj

# 흙 속 (돌 사이로 보이는 흙)
bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, H * 0.48))
core = bpy.context.object
core.scale = (L, D * 0.82, H * 0.96)
bpy.ops.object.transform_apply(scale=True)
add(core, "Clay")

def stone(c, size):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=0.5, location=c)
    o = bpy.context.object
    seed = random.random() * 100
    for v in o.data.vertices:
        p = v.co
        n = noise.noise(p * 3.0 + Vector((seed, seed, seed)))
        v.co = p * (1.0 + 0.18 * n)
    o.scale = size
    o.rotation_euler = (random.uniform(-0.2, 0.2), random.uniform(-0.2, 0.2), random.uniform(0, math.pi))
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    for p in o.data.polygons:
        p.use_smooth = True
    # 돌마다 색을 조금씩 다르게 (회색, 누런 회색, 푸른 회색)
    base = random.choice([(0.78, 0.76, 0.72), (0.82, 0.77, 0.66), (0.7, 0.72, 0.74), (0.74, 0.7, 0.64)])
    k = random.uniform(0.74, 0.92)
    colr = tuple(min(1.0, c2 * k) for c2 in base)
    ca = o.data.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
    for d in ca.data:
        d.color = (*colr, 1.0)
    return add(o, "Stone")

# 줄마다 돌을 쌓아요 (앞뒤 양면, 위로 갈수록 작게)
courses = [(0.17, 0.32, 0.36), (0.47, 0.28, 0.32), (0.74, 0.25, 0.28), (0.95, 0.2, 0.22)]
for ci, (z, h, w) in enumerate(courses):
    for side in (-1, 1):
        x = -L / 2 - random.uniform(0, w * 0.5) if ci % 2 else -L / 2 + random.uniform(-0.05, 0.05)
        while x < L / 2 + w * 0.3:
            sw = w * random.uniform(0.8, 1.25)
            cx = x + sw / 2
            if -L / 2 - 0.05 < cx < L / 2 + 0.05:
                stone((cx, side * (D * 0.36 + random.uniform(-0.02, 0.03)), z + random.uniform(-0.03, 0.03)),
                      (sw * 1.02, random.uniform(0.32, 0.42) * (1 + 0.15 * (ci == 0)), h * random.uniform(0.9, 1.1)))
            x += sw * random.uniform(0.86, 0.96)

top = H
if cap == "straw":
    # 이엉: 둥글게 덮은 짚 + 묶은 새끼줄
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.5, depth=L + 0.04, location=(0, 0, 0), rotation=(0, math.pi / 2, 0))
    o = bpy.context.object
    bpy.ops.object.transform_apply(location=True, rotation=True)
    o.scale = (1, 0.86, 0.36)
    o.location = (0, 0, 0)
    bpy.ops.object.transform_apply(scale=True)
    for v in o.data.vertices:
        z = v.co.z
        if z < 0.0:
            z = z * 0.3
        v.co.z = top + 0.04 + z + 0.02 * noise.noise(v.co * 6.0)
    for p in o.data.polygons:
        p.use_smooth = True
    add(o, "ThatchDark")
    for x in (-0.6, 0.0, 0.6):
        bpy.ops.mesh.primitive_torus_add(major_radius=0.36, minor_radius=0.02, location=(x, 0, top + 0.07), rotation=(0, math.pi / 2, 0))
        t = bpy.context.object
        bpy.ops.object.transform_apply(rotation=True)
        t.scale = (1, 0.88, 0.42)
        bpy.ops.object.transform_apply(scale=True)
        add(t, "Rope")
else:
    # 기와 지붕: 회반죽 띠 + 암키와 바닥 + 수키와 줄 + 용마루
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, top + 0.04))
    o = bpy.context.object
    o.scale = (L + 0.02, D * 0.92, 0.08)
    bpy.ops.object.transform_apply(scale=True)
    add(o, "Lime")
    for side in (-1, 1):
        bpy.ops.mesh.primitive_cube_add(size=1, location=(0, side * 0.24, top + 0.15))
        o = bpy.context.object
        o.scale = (L + 0.04, 0.5, 0.05)
        o.rotation_euler = (side * -0.42, 0, 0)
        bpy.ops.object.transform_apply(rotation=True, scale=True)
        add(o, "TileBase")
        n = 10
        for i in range(n):
            x = -L / 2 + (i + 0.5) * L / n
            nrm = Vector((0, side * math.sin(0.42), math.cos(0.42)))
            ctr = Vector((x, side * 0.24, top + 0.15)) + nrm * 0.06
            bpy.ops.mesh.primitive_cylinder_add(vertices=10, radius=0.06, depth=0.55, location=ctr, rotation=(-side * (math.pi / 2 + 0.42), 0, 0))
            o = bpy.context.object
            for p in o.data.polygons:
                p.use_smooth = True
            add(o, "Tile")
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.08, depth=L + 0.04, location=(0, 0, top + 0.33), rotation=(0, math.pi / 2, 0))
    o = bpy.context.object
    bpy.ops.object.transform_apply(rotation=True)
    for p in o.data.polygons:
        p.use_smooth = True
    add(o, "Tile")

# 흙·지붕에도 흰 색 칸을 만들어 두고 하나로 합쳐요
for o in objs:
    if not o.data.color_attributes:
        ca = o.data.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
        for d in ca.data:
            d.color = (1, 1, 1, 1)
bpy.ops.object.select_all(action="DESELECT")
for o in objs:
    o.select_set(True)
bpy.context.view_layer.objects.active = objs[0]
bpy.ops.object.join()
bpy.ops.export_scene.gltf(filepath=dst, export_format="GLB", use_selection=True, export_vertex_color="ACTIVE")
print("EXPORTED", dst)
