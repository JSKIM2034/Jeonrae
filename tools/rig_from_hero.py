# 뼈대 없는 Meshy 아이 모델(A자 자세)에 지금 주인공의 뼈대와 동작(걷기·뛰기·헤엄 등)을 그대로 씌워요.
# Meshy 리깅 없이 Image to 3D 결과만 있으면 돼요. 옷 입은 주인공 모델도 같은 방법으로 써요.
#  1) 주인공 뼈대(tools/hero_meshy_anim_source.glb)를 가져와 새 모델 키(1.7)에 맞춰요
#  2) 팔·목·무릎 관절 위치를 새 모델 모양에 맞게 옮겨요 (SHOULDER, FINGERTIP, NECK_Z, HEAD_Z, KNEE_Z)
#  3) Meshy 모델은 구멍 난 조각이라 빈틈없는 복제본(복셀)에서 자동 무게를 계산해 원본으로 옮겨요
#  4) 가방 뼈(Bone_002~005)는 쓰지 않아요 (가방이 허리를 따라 움직여요)
# 그다음 tools/prep_meshy_anim.py 로 주먹 모양과 1024 텍스처를 만들어요.
# 사용: python3 -I tools/rig_from_hero.py 원본.glb 중간.glb [어깨x 어깨z 손끝x 손끝z 목z 머리z 무릎z]
#       python3 -I tools/prep_meshy_anim.py 중간.glb source/models/새이름.glb 1.0
# 관절 위치는 원본을 키 1.7로 맞춘 좌표(발바닥 0, 앞쪽 -y)예요. 여자 주인공(hero_girl) 값이 기본값.
import bpy, math, numpy as np, sys
from mathutils import Vector, Matrix
args=[a for a in sys.argv[1:]]
src_glb,out=args[0],args[1]
P=[float(x) for x in args[2:9]] if len(args)>=9 else [0.16,1.12,0.455,0.59,1.15,1.20,0.43]
SHOULDER=(P[0],P[1]); FINGERTIP=(P[2],P[3]); NECK_Z,HEAD_Z,KNEE_Z=P[4],P[5],P[6]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=__import__('os').path.join(__import__('os').path.dirname(__import__('os').path.abspath(__file__)),'hero_meshy_anim_source.glb'))
arm=[o for o in bpy.data.objects if o.type=='ARMATURE'][0]
for o in list(bpy.data.objects):
    if o.type=='MESH': bpy.data.objects.remove(o)
assert arm.matrix_world==Matrix.Identity(4)
bpy.ops.import_scene.gltf(filepath=src_glb)
g=[o for o in bpy.data.objects if o.type=='MESH'][0]
for o in list(bpy.data.objects):
    if o not in (arm,g): bpy.data.objects.remove(o)
bpy.ops.object.select_all(action='DESELECT')
bpy.context.view_layer.objects.active=g; g.select_set(True)
bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
co=np.array([v.co[:] for v in g.data.vertices])
s=1.7/(co[:,2].max()-co[:,2].min()); zmin=co[:,2].min()
for v in g.data.vertices:
    v.co=Vector(((v.co.x)*s,(v.co.y)*s,(v.co.z-zmin)*s))
g.data.update()
# --- 뼈 위치 맞추기
bpy.ops.object.select_all(action='DESELECT')
bpy.context.view_layer.objects.active=arm; arm.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')
eb=arm.data.edit_bones
for n in ['mixamorig:Spine','mixamorig:Spine1','mixamorig:Spine2','mixamorig:Neck','mixamorig:Head','mixamorig:LeftShoulder','mixamorig:LeftArm']:
    print(n, eb[n].head[:], eb[n].tail[:])
def chain(root):
    out=[root]
    for c in root.children_recursive: out.append(c)
    return out
for side,sx in (('Left',1),('Right',-1)):
    up=eb['mixamorig:%sArm'%side]
    tip=eb['mixamorig:%sHandMiddle4'%side]
    S_h=Vector((up.head.x*sx,up.head.z)); T_h=Vector((tip.tail.x*sx,tip.tail.z))
    S_g=Vector(SHOULDER); T_g=Vector(FINGERTIP)
    vh=T_h-S_h; vg=T_g-S_g
    k=vg.length/vh.length; ang=math.atan2(vg.y,vg.x)-math.atan2(vh.y,vh.x)
    ca,sa=math.cos(ang),math.sin(ang)
    def f(p):
        q=Vector((p.x*sx,p.z))-S_h
        q=Vector((ca*q.x-sa*q.y, sa*q.x+ca*q.y))*k+S_g
        return Vector((q.x*sx, p.y, q.y))
    bones=chain(up)
    newp={b.name:(f(b.head),f(b.tail)) for b in bones}
    for b in bones:
        b.head,b.tail=newp[b.name]
    sh=eb['mixamorig:%sShoulder'%side]; sh.tail=eb['mixamorig:%sArm'%side].head
    print(side,'scale',round(k,3),'angle',round(math.degrees(ang),1),'hand',eb['mixamorig:%sHand'%side].head[:])
    leg=eb['mixamorig:%sLeg'%side]; 
    knee=leg.head.copy(); knee.z=KNEE_Z
    leg.head=knee; eb['mixamorig:%sUpLeg'%side].tail=knee
neck=eb['mixamorig:Neck']; head=eb['mixamorig:Head']
neck.head.z=NECK_Z; neck.tail.z=HEAD_Z; head.head.z=HEAD_Z
sp2=eb['mixamorig:Spine2']; 
if sp2.tail.z>NECK_Z: sp2.tail.z=NECK_Z
bpy.ops.object.mode_set(mode='OBJECT')
for n in ['Bone_002','Bone_003','Bone_004','Bone_005']:
    arm.data.bones[n].use_deform=False
# --- 몸 무게 자동
arm.data.pose_position='REST'
bpy.ops.object.select_all(action='DESELECT')
g.select_set(True); arm.select_set(True); bpy.context.view_layer.objects.active=arm
# Meshy 모델은 구멍 난 조각이라 그대로는 자동 무게가 안 돼요. 빈틈없는 복제본(복셀)에서 계산해 원본으로 옮겨요.
bpy.ops.object.select_all(action='DESELECT')
bpy.context.view_layer.objects.active=g; g.select_set(True)
bpy.ops.object.duplicate()
proxy=bpy.context.active_object
proxy.data.remesh_voxel_size=0.009
bpy.ops.object.voxel_remesh()
print('proxy verts',len(proxy.data.vertices))
bpy.ops.object.select_all(action='DESELECT')
proxy.select_set(True); arm.select_set(True); bpy.context.view_layer.objects.active=arm
bpy.ops.object.parent_set(type='ARMATURE_AUTO')
print('proxy unweighted',sum(1 for v in proxy.data.vertices if len(v.groups)==0))
for vgp in proxy.vertex_groups: g.vertex_groups.new(name=vgp.name)
dt=g.modifiers.new('dt','DATA_TRANSFER'); dt.object=proxy
dt.use_vert_data=True; dt.data_types_verts={'VGROUP_WEIGHTS'}; dt.vert_mapping='POLYINTERP_NEAREST'
dt.layers_vgroup_select_src='ALL'; dt.layers_vgroup_select_dst='NAME'
bpy.ops.object.select_all(action='DESELECT')
bpy.context.view_layer.objects.active=g; g.select_set(True)
bpy.ops.object.modifier_apply(modifier='dt')
bpy.data.objects.remove(proxy)
g.parent=arm
am=g.modifiers.new('Armature','ARMATURE'); am.object=arm
empty=[vg.name for vg in g.vertex_groups]
cnt=sum(1 for v in g.data.vertices if len(v.groups)==0)
print('groups',len(empty),'unweighted verts',cnt,'of',len(g.data.vertices))
arm.data.pose_position='POSE'
g.name='output_unwrapped'
bpy.ops.export_scene.gltf(filepath=out, export_format='GLB', export_animations=True, export_animation_mode='ACTIONS', export_skins=True)
