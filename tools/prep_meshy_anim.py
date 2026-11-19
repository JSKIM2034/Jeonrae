# Meshy 에서 뼈대와 동작(걷기·뛰기 등)을 넣어 받은 GLB 를 게임용으로 다듬어요.
#  1) 군더더기(빈 공 모양 등) 지우기
#  2) 손가락을 말아 주먹 쥔 모양을 기본 자세로 굳히기 (동작에서 손가락 움직임은 빼요)
#  3) 색 텍스처만 1024 로 남기고 내보내기 (동작은 그대로)
#
# 사용: python3 -I prep_meshy_anim.py 입력.glb 출력.glb [주먹 정도 0~1]
import bpy, sys, math
from mathutils import Vector, Quaternion, Matrix

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[-3:]
src, dst = args[0], args[1]
FIST = float(args[2]) if len(args) > 2 else 1.0

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
arm = [o for o in bpy.data.objects if o.type == "ARMATURE"][0]
meshes = [o for o in bpy.data.objects if o.type == "MESH" and o.parent == arm]
for o in list(bpy.data.objects):
    if o.type == "MESH" and o not in meshes:
        bpy.data.objects.remove(o)
mesh = meshes[0]
print("BONES", len(arm.data.bones), "MESH", mesh.name, len(mesh.data.vertices))

FINGERS = ("Thumb", "Index", "Middle", "Ring", "Pinky")


def is_finger(name):
    return any(f in name for f in FINGERS)


# ---- 1) 동작 정리: 손가락 움직임 빼기 ----
def all_fcurves(action):
    out = []
    if hasattr(action, "fcurves") and action.fcurves is not None and len(action.fcurves) > 0:
        return list(action.fcurves), action.fcurves
    for layer in getattr(action, "layers", []):
        for strip in layer.strips:
            for cb in strip.channelbags:
                out.append(cb)
    return out, None


removed = 0
for act in bpy.data.actions:
    if hasattr(act, "layers") and len(act.layers) > 0:
        for layer in act.layers:
            for strip in layer.strips:
                for cb in strip.channelbags:
                    for fc in list(cb.fcurves):
                        if is_finger(fc.data_path):
                            cb.fcurves.remove(fc)
                            removed += 1
    else:
        for fc in list(act.fcurves):
            if is_finger(fc.data_path):
                act.fcurves.remove(fc)
                removed += 1
print("ACTIONS", [a.name for a in bpy.data.actions], "finger curves removed", removed)

# ---- 2) 주먹 쥐기 ----
# 손가락 뼈를 돌리면 Meshy 손 모양(손가락이 붙어 있는 덩어리)이 찌그러져서,
# 주인공 때처럼 손 모양 자체를 손바닥 쪽으로 말아 주먹을 만들어요 (기본 자세의 모양을 바꿔요).
import numpy as np
M = mesh.matrix_world
Mi = M.inverted()
co = np.array([tuple(M @ v.co) for v in mesh.data.vertices])
H = co[:, 2].max() - co[:, 2].min()
gname = {g.index: g.name for g in mesh.vertex_groups}
dom = []
for v in mesh.data.vertices:
    best, bw = "", 0.0
    for g in v.groups:
        if g.weight > bw:
            best, bw = gname[g.group], g.weight
    dom.append(best)
dom = np.array(dom)
moved = 0
if FIST > 0:
    for side in ("Left", "Right"):
        pick = np.array([("%sHand" % side) in d for d in dom])
        if pick.sum() < 20:
            continue
        hc = co[pick].mean(0)
        _, _, vt = np.linalg.svd(co[pick] - hc)
        ax = vt[0] if vt[0][2] < 0 else -vt[0]          # 손끝 쪽(아래)
        nrm = vt[2] if vt[2][1] < 0 else -vt[2]         # 손바닥 쪽(앞)
        d = co - hc
        t = d @ ax
        tmax = t[pick].max()
        t0 = tmax - 0.058 * H * FIST ** 0.0             # 손가락 뿌리
        R = (tmax - t0) / 3.5
        perp = d - np.outer(t, ax)
        r = np.linalg.norm(perp, axis=1)
        sel = pick & (t > t0) & (r < 0.05 * H)
        for i in np.nonzero(sel)[0]:
            u = t[i] - t0
            v = perp[i] @ nrm
            wv = perp[i] - nrm * v
            ph = u / R * FIST
            cpt = hc + ax * t0 + ax * R * np.sin(ph) + nrm * R * (1 - np.cos(ph))
            nn = -ax * np.sin(ph) + nrm * np.cos(ph)
            newp = cpt + nn * v + wv * (1.0 - 0.15 * min(1.0, u / (tmax - t0)))
            mesh.data.vertices[int(i)].co = Mi @ Vector(newp.tolist())
            moved += 1
print("FIST verts", moved)

# ---- 3) 텍스처 ----
for mat in mesh.data.materials:
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
    if base_img is not None and base_img.size[0] > 1024:
        base_img.scale(1024, 1024)

for o in bpy.data.objects:
    o.select_set(o in (arm, mesh))
bpy.ops.export_scene.gltf(filepath=dst, export_format="GLB", use_selection=True, export_skins=True,
                          export_animations=True, export_animation_mode="ACTIONS", export_image_format="JPEG", export_jpeg_quality=88)
print("EXPORTED", dst)
