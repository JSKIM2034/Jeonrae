# 웹 빌드용: 모델에서 꺼낸 인물 그림(jpg)을 손실 압축(WebP)으로 바꿔 용량을 줄여요.
# 사용: python3 web_textures.py <godot 프로젝트 폴더>   (그다음 --import 다시)
import sys, glob, os, re
root = sys.argv[1]
n = 0
for imp in glob.glob(os.path.join(root, "models", "*.jpg.import")):
    src = imp[:-7]
    s = open(imp).read()
    t = re.sub(r"compress/mode=\d", "compress/mode=1", s)
    t = re.sub(r"compress/lossy_quality=[\d.]+", "compress/lossy_quality=0.82", t)
    if t != s:
        open(imp, "w").write(t)
        n += 1
print("lossy textures:", n)
