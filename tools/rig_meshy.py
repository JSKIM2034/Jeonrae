# Meshy에서 받은 A자 자세 캐릭터(GLB 한 덩어리)에 뼈대를 넣고, 웹용으로 가볍게 줄여서 내보내요.
# 사용: python3 rig_meshy.py 입력.glb 출력.glb
import bpy, bmesh, sys, math, mathutils
from mathutils import Vector

src, dst = sys.argv[-2], sys.argv[-1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
mesh = [o for o in bpy.data.objects if o.type == "MESH"][0]
for o in list(bpy.data.objects):
    if o != mesh:
        bpy.data.objects.remove(o)
bpy.context.view_layer.objects.active = mesh
mesh.select_set(True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

# 손가락을 손바닥 쪽으로 말아 주먹을 쥐어요 (손가락 뼈가 없어서 모양 자체를 바꿔요)
import numpy as np
co = np.array([tuple(v.co) for v in mesh.data.vertices])
H = co[:, 2].max() - co[:, 2].min()
xm = np.abs(co[:, 0]).max()
hand_info = {}
for sx in (-1, 1):
    pick = co[:, 0] * sx > 0.82 * xm
    hc = co[pick].mean(0)
    _, _, vt = np.linalg.svd(co[pick] - hc)
    ax = vt[0] if vt[0][2] < 0 else -vt[0]          # 손끝 쪽(아래)
    nrm = vt[2] if vt[2][1] < 0 else -vt[2]         # 손바닥 쪽(앞)
    d = co - hc
    t = d @ ax
    tmax = t[pick].max()
    t0 = tmax - 0.058 * H                            # 손가락 뿌리
    R = (tmax - t0) / 3.5
    perp = d - np.outer(t, ax)
    r = np.linalg.norm(perp, axis=1)
    sel = (co[:, 0] * sx > 0) & (t > t0) & (r < 0.05 * H)
    for i in np.nonzero(sel)[0]:
        u = t[i] - t0
        v = perp[i] @ nrm
        wv = perp[i] - nrm * v
        ph = u / R
        cpt = hc + ax * t0 + ax * R * np.sin(ph) + nrm * R * (1 - np.cos(ph))
        nn = -ax * np.sin(ph) + nrm * np.cos(ph)
        newp = cpt + nn * v + wv * (1.0 - 0.15 * min(1.0, u / (tmax - t0)))
        mesh.data.vertices[int(i)].co = Vector(newp.tolist())
    hand_info[sx] = (hc + ax * (tmax - 0.1 * H), hc + ax * (t0 + R))
    print("FIST", sx, int(sel.sum()))

# 키 2.0, 발바닥이 z=-1 (게임에서 몸 중심이 땅에서 1 위에 있어요)
zs = [v.co.z for v in mesh.data.vertices]
zmin, zmax = min(zs), max(zs)
S = 2.0 / (zmax - zmin)
def M(x, y, z):
    return Vector((x * S, y * S, (z - zmin) * S - 1.0))
for v in mesh.data.vertices:
    v.co = M(v.co.x, v.co.y, v.co.z)

# 뼈대 위치 (원래 크기 기준으로 잰 값). L은 -x 쪽
J = {
    "hips": ((0, 0, -0.25), (0, 0, -0.05), None),
    "spine": ((0, 0, -0.05), (0, 0, 0.3), "hips"),
    "head": ((0, 0, 0.3), (0, 0, 0.9), "spine"),
}
for side, sx in (("L", -1), ("R", 1)):
    J["arm" + side] = ((0.17 * sx, 0.01, 0.19), (0.33 * sx, 0.02, 0.065), "spine")
    wr, tip = hand_info[sx]
    J["fore" + side] = ((0.33 * sx, 0.02, 0.065), tuple(wr), "arm" + side)
    J["hand" + side] = (tuple(wr), tuple(tip), "fore" + side)
    J["thigh" + side] = ((0.1 * sx, 0.0, -0.25), (0.11 * sx, 0.0, -0.52), "hips")
    J["shin" + side] = ((0.11 * sx, 0.0, -0.52), (0.11 * sx, 0.0, -0.84), "thigh" + side)
    J["foot" + side] = ((0.11 * sx, 0.0, -0.84), (0.11 * sx, -0.16, -0.93), "shin" + side)
W = {k: (M(*a), M(*b), p) for k, (a, b, p) in J.items()}

arm_data = bpy.data.armatures.new("Rig")
rig = bpy.data.objects.new("Rig", arm_data)
bpy.context.scene.collection.objects.link(rig)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode="EDIT")
eb = {}
for name in ["hips", "spine", "head", "armL", "foreL", "handL", "armR", "foreR", "handR", "thighL", "shinL", "footL", "thighR", "shinR", "footR"]:
    h, t, p = W[name]
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

for name in W:
    mesh.vertex_groups.new(name=name)
vg = {g.name: g for g in mesh.vertex_groups}
z_of = lambda z: (z - zmin) * S - 1.0
crotch = z_of(-0.3)
hip_top = z_of(-0.18)
for v in mesh.data.vertices:
    p = v.co
    w = {}
    side = "L" if p.x < 0 else "R"
    arm_d = min(seg_dist(p, W["arm" + side][0], W["arm" + side][1]), seg_dist(p, W["fore" + side][0], W["fore" + side][1]))
    hand_d = seg_dist(p, W["hand" + side][0], W["hand" + side][1])
    z_orig = (p.z + 1.0) / S + zmin
    # 옆구리(몸통 옆면)는 팔에 붙지 않게: 겨드랑이 아래쪽은 더 바깥만 팔로 쳐요
    side_ok = abs(p.x) > (0.2 if z_orig > 0.12 else 0.31) * S
    # 몸통·가방보다 바깥은 모두 팔 (가방은 +x 쪽 허리 높이에만 있어요)
    beyond = -0.3 < z_orig < 0.26 and (abs(p.x) > 0.30 * S or (abs(p.x) > 0.25 * S and (p.x < 0 or z_orig > 0.02)))
    if beyond or (side_ok and (arm_d < 0.1 * S or hand_d < 0.13 * S)):
        # 팔: 가까운 뼈 두 개를 부드럽게 섞어요
        cands = {}
        for b in ("arm", "fore", "hand"):
            d = seg_dist(p, W[b + side][0], W[b + side][1])
            cands[b + side] = 1.0 / (d ** 4 + 1e-6)
        tot = sum(cands.values())
        w = {k: c / tot for k, c in cands.items()}
        # 어깨 부근은 몸통과 섞어요
        sh = (p - W["arm" + side][0]).length / S
        k = 1.0 - smooth(0.0, 0.13, sh)
        if k > 0:
            w = {kk: vv * (1 - k * 0.5) for kk, vv in w.items()}
            w["spine"] = w.get("spine", 0) + k * 0.5
    elif p.z < hip_top:
        legw = 1.0 - smooth(crotch - 0.03, hip_top, p.z)
        cands = {}
        for b in ("thigh", "shin", "foot"):
            d = seg_dist(p, W[b + side][0], W[b + side][1])
            cands[b + side] = 1.0 / (d ** 4 + 1e-6)
        tot = sum(cands.values())
        w = {k: c / tot * legw for k, c in cands.items()}
        w["hips"] = 1.0 - legw
    else:
        hb = smooth(z_of(0.28), z_of(0.38), p.z)
        sb = smooth(z_of(-0.12), z_of(0.05), p.z)
        w = {"head": hb, "spine": (1 - hb) * sb, "hips": (1 - hb) * (1 - sb)}
    top = sorted(w.items(), key=lambda kv: -kv[1])[:3]
    tot = sum(x for _, x in top) or 1.0
    for k, x in top:
        if x / tot > 0.01:
            vg[k].add([v.index], x / tot, "REPLACE")

mesh.parent = rig
mod = mesh.modifiers.new("Armature", "ARMATURE")
mod.object = rig
mesh.name = "HeroMesh"

# 웹용: 색 텍스처만 1024로, 노멀/금속 텍스처는 빼요
mat = mesh.data.materials[0]
nt = mat.node_tree
bsdf = [n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"][0]
base_img = None
for l in list(nt.links):
    if l.to_node == bsdf and l.to_socket.name == "Base Color":
        base_img = l.from_node.image
    elif l.to_node == bsdf or l.to_node.type == "NORMAL_MAP" or l.to_node.type == "SEPARATE_COLOR":
        nt.links.remove(l)
for n in list(nt.nodes):
    if n.type == "TEX_IMAGE" and n.image != base_img:
        nt.nodes.remove(n)
    elif n.type in ("NORMAL_MAP", "SEPARATE_COLOR"):
        nt.nodes.remove(n)
bsdf.inputs["Metallic"].default_value = 0.0
bsdf.inputs["Roughness"].default_value = 0.75
base_img.scale(1024, 1024)
mat.name = "HeroSkin"

bpy.ops.object.select_all(action="DESELECT")
rig.select_set(True)
mesh.select_set(True)
bpy.ops.export_scene.gltf(filepath=dst, export_format="GLB", use_selection=True, export_skins=True, export_animations=False,
                          export_image_format="JPEG", export_jpeg_quality=88)
print("EXPORTED", dst)
