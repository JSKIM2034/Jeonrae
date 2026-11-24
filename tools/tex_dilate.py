# 다시 구운 인물 그림(_baked.jpg)의 그림 조각 사이 검은 틈을 가장 가까운 조각 색으로 메워요 (멀리서 볼 때 얼굴에 금이 가 보이는 것 막기)
# 사용: python3 -I tools/tex_uvdump.py 모델.glb uv.txt  (Blender) → python3 -I tools/tex_dilate.py 그림.jpg uv.txt 결과.jpg
import sys, numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage
tex, uvf, out = sys.argv[1], sys.argv[2], sys.argv[3]
im = np.asarray(Image.open(tex).convert("RGB")).astype(np.float32)
H, W = im.shape[:2]
mask = Image.new("L", (W, H), 0)
d = ImageDraw.Draw(mask)
for line in open(uvf):
    pts = [tuple(map(float, p.split(","))) for p in line.split()]
    # glTF/Blender UV: v=0 아래 → 그림 좌표는 위가 0
    d.polygon([(u * W, (1.0 - v) * H) for u, v in pts], fill=255)
m = np.asarray(mask) > 0
# 섬 가장자리 1픽셀은 이미 번진 색일 수 있어 살짝 안으로 줄여요
core = ndimage.binary_dilation(m, iterations=2)
# 가장 가까운 섬 안쪽 픽셀의 색으로 바깥을 채워요
idx = ndimage.distance_transform_edt(~core, return_distances=False, return_indices=True)
filled = im[idx[0], idx[1]]
res = np.where(core[..., None], im, filled)
Image.fromarray(res.clip(0, 255).astype(np.uint8)).save(out, quality=92)
print("coverage %.2f" % m.mean())
