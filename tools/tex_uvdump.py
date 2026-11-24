# 모델의 그림 자리(UV) 삼각형을 글로 뽑아요 (tex_dilate.py 에서 써요). 사용: python3 -I tex_uvdump.py 모델.glb uv.txt
import bpy, sys
src, out = sys.argv[-2], sys.argv[-1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
mesh = max([o for o in bpy.data.objects if o.type == "MESH"], key=lambda o: len(o.data.polygons))
uv = mesh.data.uv_layers.active.data
with open(out, "w") as f:
    for poly in mesh.data.polygons:
        pts = [uv[li].uv for li in poly.loop_indices]
        f.write(" ".join("%.6f,%.6f" % (p.x, p.y) for p in pts) + "\n")
print("polys", len(mesh.data.polygons))
