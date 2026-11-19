# 주인공 기존 동작 파일(걷기·뛰기)에 새 동작(헤엄·올라오기·끄덕·깜짝)만 더해요
import bpy, sys
base, extra, dst = sys.argv[-3], sys.argv[-2], sys.argv[-1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=base)
keep = set(bpy.data.objects)
arm = [o for o in keep if o.type == "ARMATURE"][0]
names_before = set(a.name for a in bpy.data.actions)
bpy.ops.import_scene.gltf(filepath=extra)
arm2 = [o for o in bpy.data.objects if o.type == "ARMATURE" and o not in keep][0]
same = set(b.name for b in arm.data.bones) == set(b.name for b in arm2.data.bones)
print("SAME_BONES", same, len(arm.data.bones), len(arm2.data.bones))
for o in list(bpy.data.objects):
    if o not in keep:
        bpy.data.objects.remove(o)
for a in list(bpy.data.actions):
    if a.name not in names_before and a.name.split(".")[0] not in ("Swimming", "Climb", "Nod", "Surprise"):
        bpy.data.actions.remove(a)
# 새 동작을 기존 뼈대에 붙여요 (슬롯 연결)
ad = arm.animation_data or arm.animation_data_create()
for a in bpy.data.actions:
    a.use_fake_user = True
    if a.name not in names_before:
        ad.action = a
        if hasattr(ad, "action_slot") and len(a.slots) > 0:
            ad.action_slot = a.slots[0]
        a.name = a.name.split(".")[0]
for a in list(bpy.data.actions):
    if a.name in ("Agree_Gesture", "Alert"):
        bpy.data.actions.remove(a)
print("ACTIONS", [a.name for a in bpy.data.actions])
for o in bpy.data.objects:
    o.select_set(True)
bpy.ops.export_scene.gltf(filepath=dst, export_format="GLB", export_skins=True, export_animations=True,
                          export_animation_mode="ACTIONS", export_image_format="JPEG", export_jpeg_quality=92)
