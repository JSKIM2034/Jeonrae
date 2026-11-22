import base64, subprocess, re, zlib
import glob
p='/home/claude/jeonrae/source/core.gd'
s=open(p).read()
s=re.sub(r'\n\n# ---------- 글꼴 데이터.*','',s,flags=re.S).rstrip('\n')
allsrc=s+'\n'+'\n'.join(open(f).read() for f in sorted(glob.glob('/home/claude/jeonrae/source/chapter*.gd'))+['/home/claude/jeonrae/source/lang_en.gd'])
lines=[l for l in allsrc.splitlines() if not l.lstrip().startswith('#')]
chars=sorted(set(c for c in '\n'.join(lines) if ord(c)>127))
text=''.join(chr(i) for i in range(32,127))+''.join(chars)+'“”♥★☆'
open('/tmp/fonts/subset.txt','w').write(text)
subprocess.check_call(['pyftsubset','/tmp/fonts/Jua-Regular.ttf','--text-file=/tmp/fonts/subset.txt','--output-file=/tmp/fonts/jua-sub.ttf','--layout-features=','--no-hinting','--desubroutinize'])
b=open('/tmp/fonts/jua-sub.ttf','rb').read()
from fontTools.ttLib import TTFont
cm=TTFont('/tmp/fonts/Jua-Regular.ttf').getBestCmap()
print('missing in Jua:', ''.join(c for c in chars if ord(c) not in cm))
s+='\n\n# ---------- 글꼴 데이터 (주아체, SIL OFL 라이선스, 압축됨) ----------\nconst FONT_B64 := "'+base64.b64encode(zlib.compress(b,9)).decode()+'"\n'
open(p,'w').write(s)
print(len(chars),'chars')
