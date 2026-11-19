# Meshy 의 "swimming_to_edge"(헤엄쳐 와서 물가로 올라오기) 동작을 잘라
#  - Swimming: 앞부분 한 번 젓는 구간을 반복 동작으로 (앞으로 나가는 움직임은 빼요)
#  - Climb:    뒷부분 물가를 짚고 올라서는 동작
# 으로 나누고, Agree_Gesture → Nod, Alert → Surprise 로 이름을 바꿔요.
# 사용: python3 -I cut_swim.py 입력.glb 출력.glb   (그다음 prep_meshy_anim.py 로 주먹·텍스처 정리)
import bpy, sys
src, dst = sys.argv[-2], sys.argv[-1]
LOOP = (4, 49)
CLIMB = (50, 120)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
arm = [o for o in bpy.data.objects if o.type == "ARMATURE"][0]


def curves(act):
    out = []
    if hasattr(act, "layers") and len(act.layers) > 0:
        for layer in act.layers:
            for strip in layer.strips:
                for cb in strip.channelbags:
                    out += list(cb.fcurves)
    else:
        out = list(act.fcurves)
    return out


def trim(act, f0, f1, loop):
    for fc in curves(act):
        kps = fc.keyframe_points
        first = fc.evaluate(f0)
        last_ok = fc.evaluate(f1)
        for i in range(len(kps) - 1, -1, -1):
            if kps[i].co.x < f0 or kps[i].co.x > f1:
                kps.remove(kps[i])
        for kp in kps:
            kp.co.x -= f0
            kp.handle_left.x -= f0
            kp.handle_right.x -= f0
        hips_move = "Hips" in fc.data_path and fc.data_path.endswith("location") and fc.array_index in (0, 1, 2)
        if loop and hips_move and fc.array_index != 2:
            # 앞으로 나가는 움직임은 빼요 (높이 출렁임만 남겨요)
            for kp in kps:
                kp.co.y = first
                kp.handle_left.y = first
                kp.handle_right.y = first
        if loop and len(kps) > 1:
            # 끝 자세를 처음 자세로 맞춰 이음매 없이 반복
            kps[-1].co.y = kps[0].co.y
            kps[-1].handle_left.y = kps[0].co.y
            kps[-1].handle_right.y = kps[0].co.y
        fc.update()
    act.frame_range = (0, f1 - f0)


swim = bpy.data.actions.get("swimming_to_edge")
climb = swim.copy()
climb.name = "Climb"
swim.name = "Swimming"
trim(swim, LOOP[0], LOOP[1], True)
trim(climb, CLIMB[0], CLIMB[1], False)
for old, new in (("Agree_Gesture", "Nod"), ("Alert", "Surprise")):
    if old in bpy.data.actions:
        bpy.data.actions[old].name = new
for a in bpy.data.actions:
    a.use_fake_user = True
print("ACTIONS", [(a.name, tuple(a.frame_range)) for a in bpy.data.actions])
for o in bpy.data.objects:
    o.select_set(True)
bpy.ops.export_scene.gltf(filepath=dst, export_format="GLB", export_skins=True, export_animations=True,
                          export_animation_mode="ACTIONS", export_image_format="JPEG", export_jpeg_quality=92)
print("EXPORTED", dst)
