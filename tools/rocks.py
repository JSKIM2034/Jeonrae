# 돌멩이 4종 (크기 1x1x1, 가운데 원점) -> models/rocks.glb
import sys, random
sys.path.insert(0, "/home/claude/jeonrae/tools")
from blcommon import *

OUT = "/home/claude/jeonrae/source/models/rocks.glb"
b = Builder()
M = b.mat("Rock", (0.7, 0.7, 0.68))
for k in range(4):
    rnd = random.Random(20 + k)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=0.5, location=(k * 3, 0, 0))
    o = bpy.context.object
    for v in o.data.vertices:
        d = v.co.normalized()
        s = rnd.uniform(0.82, 1.12)
        # 납작한 면 몇 개 (깎인 돌 느낌)
        for cut in ((0, 0, -1, 0.32), (1, 0, 0.2, 0.42), (-0.6, 0.8, 0, 0.44)):
            n = Vector(cut[:3]).normalized()
            if d.dot(n) * 0.5 * s > cut[3]:
                s = cut[3] / max(0.01, d.dot(n) * 0.5)
        v.co = d * 0.5 * s
    for p in o.data.polygons:
        p.use_smooth = True
    o.data.materials.append(M)
    # 크기를 1x1x1 로 맞추고 가운데로
    bpy.ops.object.origin_set(type="ORIGIN_GEOMETRY", center="BOUNDS")
    dims = o.dimensions.copy()
    o.scale = (1 / dims.x, 1 / dims.y, 1 / dims.z)
    bpy.ops.object.transform_apply(scale=True, location=False)
    o.location = (k * 3, 0, 0)
    o.name = "Rock%d" % k
b.export(OUT)
