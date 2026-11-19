# Meshy에서 받은 A자 자세 인물(GLB 한 덩어리)을 가볍게 줄이고 뼈대를 넣어 웹용 GLB로 내보내요.
# 주인공용 rig_meshy.py 를 인물마다 관절 위치만 바꿔 쓸 수 있게 일반화한 것.
#
# 사용: python3 -I rig_npc.py 입력.glb 출력.glb 설정.json
#
# 설정.json (모든 좌표는 키 2.0, 발바닥 z=-1, 정면이 -y, 왼쪽(L)이 -x 인 기준)
# {
#   "polys": 16000,                       줄일 면 개수
#   "hips": [-0.4, -0.1], "spine_top": 0.3, "head_top": 0.95,
#   "shoulder": [0.2, 0.0, 0.22], "elbow": [...], "wrist": [...], "tip": [...],     오른쪽(+x) 기준, 왼쪽은 x 를 뒤집어요
#   "hip_joint": [...], "knee": [...], "ankle": [...], "toe": [...],
#   "arm_x_hi": 0.21, "arm_x_lo": 0.3, "arm_split_z": 0.1, "arm_min_z": -0.32,   이 x 보다 바깥이면 팔
#   "crotch": -0.45, "hip_top": -0.3,                                              다리와 엉덩이가 섞이는 높이
#   "neck": [0.3, 0.4], "waist": [-0.25, -0.05],
#   "robe_bottom": -2.0, "robe_leg": 1.0                                           두루마기·치마: 이 높이 위는 다리 영향을 줄여요
# }
import bpy, sys, json
from mathutils import Vector

src, dst, cfg_path = sys.argv[-3], sys.argv[-2], sys.argv[-1]
C = json.load(open(cfg_path))

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
mesh = [o for o in bpy.data.objects if o.type == "MESH"][0]
for o in list(bpy.data.objects):
    if o != mesh:
        bpy.data.objects.remove(o)
bpy.context.view_layer.objects.active = mesh
mesh.select_set(True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

# 1) 면 줄이기 (Meshy 원본은 수십만~백만 면이라 폰에서 무거워요)
# 그냥 줄이면 그림 이음매가 뭉개져 얼굴과 옷 무늬가 찌그러져요.
# 그래서 줄인 모양에 새로 그림 자리를 펴고, 원본의 색을 그대로 구워 옮겨요.
n = len(mesh.data.polygons)
target = C.get("polys", 16000)
baked_img = None
if n > target * 1.2:
    high = mesh
    bpy.ops.object.duplicate()
    mesh = bpy.context.view_layer.objects.active
    mod = mesh.modifiers.new("dec", "DECIMATE")
    mod.ratio = target / n
    mod.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier="dec")
    # 매끈하게: 모서리 각이 큰 곳만 각지게
    for poly in mesh.data.polygons:
        poly.use_smooth = True
    # 새 그림 자리
    while len(mesh.data.uv_layers) > 0:
        mesh.data.uv_layers.remove(mesh.data.uv_layers[0])
    mesh.data.uv_layers.new(name="UVMap")
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=1.15, island_margin=0.004)
    bpy.ops.object.mode_set(mode="OBJECT")
    size = C.get("tex", 2048)
    baked_img = bpy.data.images.new("baked", size, size)
    mat = bpy.data.materials.new(C.get("name", "Npc") + "Skin")
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = [nd for nd in nt.nodes if nd.type == "BSDF_PRINCIPLED"][0]
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = baked_img
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    nt.nodes.active = tex
    mesh.data.materials.clear()
    mesh.data.materials.append(mat)
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 1
    sc.render.bake.use_pass_direct = False
    sc.render.bake.use_pass_indirect = False
    sc.render.bake.use_pass_color = True
    sc.render.bake.use_selected_to_active = True
    sc.render.bake.cage_extrusion = C.get("cage", 0.02)
    sc.render.bake.max_ray_distance = C.get("ray", 0.06)
    sc.render.bake.margin = 6
    for o in bpy.data.objects:
        o.select_set(o in (high, mesh))
    bpy.context.view_layer.objects.active = mesh
    bpy.ops.object.bake(type="DIFFUSE")
    bpy.data.objects.remove(high)
    bpy.context.view_layer.objects.active = mesh
    mesh.select_set(True)
print("POLYS", n, "->", len(mesh.data.polygons), "baked" if baked_img else "")

# 2) 키 2.0, 발바닥 z=-1 로 맞춰요
zs = [v.co.z for v in mesh.data.vertices]
zmin, zmax = min(zs), max(zs)
S = 2.0 / (zmax - zmin)
for v in mesh.data.vertices:
    v.co = Vector((v.co.x * S + C.get("shift_x", 0.0), v.co.y * S, (v.co.z - zmin) * S - 1.0))

# 3) 뼈대
def P(a, sx=1.0):
    return Vector((a[0] * sx, a[1], a[2]))

J = {
    "hips": (Vector((0, 0, C["hips"][0])), Vector((0, 0, C["hips"][1])), None),
    "spine": (Vector((0, 0, C["hips"][1])), Vector((0, 0, C["spine_top"])), "hips"),
    "head": (Vector((0, 0, C["spine_top"])), Vector((0, 0, C["head_top"])), "spine"),
}
for side, sx in (("L", -1.0), ("R", 1.0)):
    # 양팔 자세가 다르면 "shoulder_L" 처럼 왼쪽(-x)을 따로 적어요 (x 를 뒤집지 않고 그대로)
    def A(k):
        return P(C[k + "_L"]) if side == "L" and (k + "_L") in C else P(C[k], sx)
    J["arm" + side] = (A("shoulder"), A("elbow"), "spine")
    J["fore" + side] = (A("elbow"), A("wrist"), "arm" + side)
    J["hand" + side] = (A("wrist"), A("tip"), "fore" + side)
    J["thigh" + side] = (P(C["hip_joint"], sx), P(C["knee"], sx), "hips")
    J["shin" + side] = (P(C["knee"], sx), P(C["ankle"], sx), "thigh" + side)
    J["foot" + side] = (P(C["ankle"], sx), P(C["toe"], sx), "shin" + side)

arm_data = bpy.data.armatures.new("Rig")
rig = bpy.data.objects.new("Rig", arm_data)
bpy.context.scene.collection.objects.link(rig)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode="EDIT")
eb = {}
for name in ["hips", "spine", "head", "armL", "foreL", "handL", "armR", "foreR", "handR", "thighL", "shinL", "footL", "thighR", "shinR", "footR"]:
    h, t, p = J[name]
    b = arm_data.edit_bones.new(name)
    b.head, b.tail = h, t
    if p:
        b.parent = eb[p]
        b.use_connect = (eb[p].tail - h).length < 1e-4
    eb[name] = b
bpy.ops.object.mode_set(mode="OBJECT")


def seg_dist(p, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / ab.length_squared))
    return (a + ab * t - p).length


def smooth(e0, e1, x):
    t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


# 4) 살 붙이기 (어느 뼈를 따라 움직일지)
for name in J:
    mesh.vertex_groups.new(name=name)
vg = {g.name: g for g in mesh.vertex_groups}
crotch, hip_top = C["crotch"], C["hip_top"]
robe_bottom = C.get("robe_bottom", -2.0)
robe_leg = C.get("robe_leg", 1.0)
counts = {"arm": 0, "leg": 0, "body": 0}
for v in mesh.data.vertices:
    p = v.co
    side = "L" if p.x < 0 else "R"
    if "arm_lim" in C:
        # 높이별 팔 경계선 [[z, x], ...] (위에서 아래로), 사이는 이어서 써요
        L = C["arm_lim"]
        lim = L[0][1] if p.z >= L[0][0] else L[-1][1]
        for (z0, x0), (z1, x1) in zip(L, L[1:]):
            if z1 <= p.z < z0:
                lim = x0 + (x1 - x0) * (z0 - p.z) / (z0 - z1)
    else:
        lim = C["arm_x_hi"] if p.z >= C["arm_split_z"] else C["arm_x_lo"]
    prop = None
    for bx in C.get("props", []):
        # 손에 든 물건(주걱, 방망이, 지팡이): [xmin, xmax, ymin, ymax, zmin, zmax, 뼈]
        if bx[0] <= p.x <= bx[1] and bx[2] <= p.y <= bx[3] and bx[4] <= p.z <= bx[5]:
            prop = bx[6]
    if prop:
        w = {prop: 1.0}
    elif C["arm_min_z"] < p.z < C.get("arm_max_z", C["shoulder"][2] + 0.12) and abs(p.x) > lim:
        cands = {}
        for b in ("arm", "fore", "hand"):
            d = seg_dist(p, J[b + side][0], J[b + side][1])
            cands[b + side] = 1.0 / (d ** 4 + 1e-6)
        tot = sum(cands.values())
        w = {k: c / tot for k, c in cands.items()}
        # 어깨 부근은 몸통과 섞어요
        sh = (p - J["arm" + side][0]).length
        k = 1.0 - smooth(0.0, 0.14, sh)
        if k > 0:
            w = {kk: vv * (1 - k * 0.5) for kk, vv in w.items()}
            w["spine"] = w.get("spine", 0) + k * 0.5
        counts["arm"] += 1
    elif p.z < hip_top:
        legw = 1.0 - smooth(crotch - 0.03, hip_top, p.z)
        # 두루마기·치마 자락은 다리를 덜 따라가요 (찢어지듯 늘어나지 않게)
        if p.z > robe_bottom:
            legw *= robe_leg
        cands = {}
        for b in ("thigh", "shin", "foot"):
            d = seg_dist(p, J[b + side][0], J[b + side][1])
            cands[b + side] = 1.0 / (d ** 4 + 1e-6)
        tot = sum(cands.values())
        w = {k: c / tot * legw for k, c in cands.items()}
        w["hips"] = 1.0 - legw
        counts["leg"] += 1
    else:
        hb = smooth(C["neck"][0], C["neck"][1], p.z)
        sb = smooth(C["waist"][0], C["waist"][1], p.z)
        w = {"head": hb, "spine": (1 - hb) * sb, "hips": (1 - hb) * (1 - sb)}
        counts["body"] += 1
    top = sorted(w.items(), key=lambda kv: -kv[1])[:3]
    tot = sum(x for _, x in top) or 1.0
    for k, x in top:
        if x / tot > 0.01:
            vg[k].add([v.index], x / tot, "REPLACE")
print("WEIGHTS", counts)

# 옷 색을 바꿀 수 있게: 꼭짓점 색 R = 윗옷, G = 아래옷(치마·바지) 자리 (손, 얼굴, 신발은 0)
if "cloth" in C:
    top_hi, split, low = C["cloth"]
    ca = mesh.data.color_attributes.new("Col", "BYTE_COLOR", "POINT")
    gidx = {g.index: g.name for g in mesh.vertex_groups}
    for v in mesh.data.vertices:
        hand = sum(g.weight for g in v.groups if gidx[g.group].startswith("hand"))
        z = v.co.z
        k = (1.0 - smooth(top_hi - 0.03, top_hi + 0.01, z)) * smooth(low - 0.02, low + 0.02, z) * (1.0 - smooth(0.7, 0.95, hand))
        up = smooth(split - 0.03, split + 0.03, z)
        ca.data[v.index].color = (k * up, k * (1.0 - up), 0.0, 1.0)
    mesh.data.color_attributes.active_color = ca

mesh.parent = rig
mod = mesh.modifiers.new("Armature", "ARMATURE")
mod.object = rig
mesh.name = C.get("name", "NpcMesh")

# 5) 웹용: 색 텍스처만 남기고, 노멀·금속 텍스처는 빼요
mat = mesh.data.materials[0]
nt = mat.node_tree
bsdf = [n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"][0]
base_img = None
for l in list(nt.links):
    if l.to_node == bsdf and l.to_socket.name == "Base Color":
        base_img = l.from_node.image
    elif l.to_node == bsdf or l.to_node.type == "NORMAL_MAP" or l.to_node.type == "SEPARATE_COLOR":
        nt.links.remove(l)
for nd in list(nt.nodes):
    if nd.type == "TEX_IMAGE" and nd.image != base_img:
        nt.nodes.remove(nd)
    elif nd.type in ("NORMAL_MAP", "SEPARATE_COLOR"):
        nt.nodes.remove(nd)
bsdf.inputs["Metallic"].default_value = 0.0
bsdf.inputs["Roughness"].default_value = 0.75
# 갓 챙, 소매, 치맛자락처럼 얇은 곳은 뒷면도 보이게
mat.use_backface_culling = False
if base_img is not None and base_img.size[0] > C.get("tex", 1024):
    base_img.scale(C.get("tex", 1024), C.get("tex", 1024))
mat.name = C.get("name", "Npc") + "Skin"

bpy.ops.object.select_all(action="DESELECT")
rig.select_set(True)
mesh.select_set(True)
bpy.ops.export_scene.gltf(filepath=dst, export_format="GLB", use_selection=True, export_skins=True, export_animations=False,
                          export_image_format="JPEG", export_jpeg_quality=88,
                          **({"export_vertex_color": "ACTIVE"} if "cloth" in C else {}))
print("EXPORTED", dst)
