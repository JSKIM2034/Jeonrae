# 모델에 은은한 그늘(AO)을 꼭짓점 색으로 구워 넣어요. 처마 밑, 기둥 사이, 땅에 닿는 곳이 자연스럽게 어두워져요
# 사용: python3 bake_ao.py 입력.glb 출력.glb [최소밝기] [AO거리]
import bpy, bmesh, sys, math
from mathutils import Vector
args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[-4:]
src, dst = args[0], args[1]
floor_v = float(args[2]) if len(args) > 2 else 0.4
dist = float(args[3]) if len(args) > 3 else 1.0
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
meshes = [o for o in bpy.data.objects if o.type == "MESH"]
for o in bpy.data.objects:
    o.select_set(o.type == "MESH")
bpy.context.view_layer.objects.active = meshes[0]
if len(meshes) > 1:
    bpy.ops.object.join()
obj = bpy.context.view_layer.objects.active
bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)

# 넓은 면은 잘게 나눠야 그늘이 부드럽게 번져요
bm = bmesh.new()
bm.from_mesh(obj.data)
for limit, cuts in ((1.2, 3), (0.6, 1)):
    long_edges = [e for e in bm.edges if e.calc_length() > limit]
    if long_edges:
        bmesh.ops.subdivide_edges(bm, edges=long_edges, cuts=cuts, use_grid_fill=True)
bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 4])
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
bm.to_mesh(obj.data)
bm.free()
if obj.data.has_custom_normals:
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.ops.mesh.customdata_custom_splitnormals_clear()

zmin = min((obj.matrix_world @ v.co).z for v in obj.data.vertices)
bpy.ops.mesh.primitive_plane_add(size=60, location=(0, 0, zmin - 0.005))
ground = bpy.context.object

# 직접 광선을 쏴서 그늘을 계산해요 (꼭짓점마다 반구 방향으로 여러 줄)
from mathutils.bvhtree import BVHTree
import random
random.seed(3)
dg = bpy.context.evaluated_depsgraph_get()
bm2 = bmesh.new()
for o2 in (obj, ground):
    m2 = o2.evaluated_get(dg).to_mesh()
    m2.transform(o2.matrix_world)
    bm2.from_mesh(m2)
    o2.evaluated_get(dg).to_mesh_clear()
tree = BVHTree.FromBMesh(bm2)
dirs = []
while len(dirs) < 40:
    v = Vector((random.uniform(-1, 1), random.uniform(-1, 1), random.uniform(-1, 1)))
    if 0.05 < v.length <= 1.0:
        dirs.append(v.normalized())
me = obj.data
# 이미 색(돌 색 등)이 있으면 그 위에 그늘을 곱해요
old = None
if me.color_attributes:
    oc = me.color_attributes[0]
    if oc.domain == "POINT":
        old = [tuple(d.color) for d in oc.data]
    else:
        old = [(1.0, 1.0, 1.0, 1.0)] * len(me.vertices)
        for poly in me.polygons:
            for li in poly.loop_indices:
                old[me.loops[li].vertex_index] = tuple(oc.data[li].color)
    for c2 in list(me.color_attributes):
        me.color_attributes.remove(c2)
col = me.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
me.color_attributes.active_color = col
me.color_attributes.default_color_name = col.name   # 내보낼 때 이 색을 써요
mw = obj.matrix_world
nm = mw.to_3x3().inverted().transposed()
vals = []
for v in me.vertices:
    p = mw @ v.co
    n = (nm @ v.normal).normalized()
    best = 0.0
    for sgn in (1.0, -1.0):
        nn = n * sgn
        tot = 0.0
        free = 0.0
        for dvec in dirs:
            c = dvec.dot(nn)
            if c <= 0.05:
                continue
            tot += c
            hit = tree.ray_cast(p + nn * 0.02, dvec, dist)
            if hit[0] is None:
                free += c
            else:
                free += c * (hit[3] / dist) ** 2
        if tot > 0:
            best = max(best, free / tot)
    vals.append(best)
s2 = sorted(vals)
print("AO raw min/med/max", s2[0], s2[len(s2)//2], s2[-1])
for i2, a in enumerate(vals):
    vv = floor_v + (1.0 - floor_v) * (a ** 1.2)
    oc4 = old[i2] if old else (1.0, 1.0, 1.0, 1.0)
    col.data[i2].color = (vv * oc4[0], vv * oc4[1], vv * oc4[2], 1.0)
bpy.data.objects.remove(ground)
obj.data.calc_loop_triangles()
print("TRIS", len(obj.data.loop_triangles))
bpy.ops.object.select_all(action="DESELECT")
obj.select_set(True)
kw = dict(filepath=dst, export_format="GLB", use_selection=True)
try:
    bpy.ops.export_scene.gltf(export_vertex_color="ACTIVE", **kw)
except TypeError:
    bpy.ops.export_scene.gltf(export_colors=True, **kw)
print("EXPORTED", dst)
