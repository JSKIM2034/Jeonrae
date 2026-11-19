"""main.gd 를 공통(core.gd)과 1장(chapter1.gd)으로 나눠요.

- 모든 var/const/enum 은 core.gd 에 둬요 (상태 값은 데이터라 함께 써도 괜찮아요).
- 1장 이야기·맵 배치·1장 미니게임 함수는 chapter1.gd 로 옮겨요.
- core.gd 안에서 1장 함수를 부르는 곳이 있으면, core.gd 에 같은 모양의 빈 함수(훅)를 만들어 둬요.
  chapter1.gd 가 그 함수를 덮어써서 실제로 동작해요. 2장도 같은 방식으로 덮어쓰면 돼요.
"""
import re
import sys

SRC = sys.argv[1]
OUT_CORE = sys.argv[2]
OUT_CH1 = sys.argv[3]

CH1_SECTIONS = [
    "약초 도감", "이야기 조각 7개", "나무하기", "우물:", "낚시 (3D)", "남쪽 들판",
    "놀부네", "흥부네", "1장 엔딩", "마을 사람 돕기", "품팔이와 장터", "숨은 이야기", "감나무:",
]
CH1_FUNCS = {
    # 이야기 속 물건
    "make_gourd_visual", "make_nest_visual", "make_herb_visual", "make_piece_visual", "make_laundry_pile",
    "make_pumpkin", "make_paddy", "spawn_rice", "spawn_silk", "spawn_gold", "make_gourd_at",
    # 1장 맵 배치
    "make_world", "make_village", "make_border", "make_signpost", "make_paths", "make_creek",
    "make_decor", "make_forest", "make_sansin_pond", "make_butterflies",
    "scatter_items", "laundry_spot", "read_story",
    # 1장 장면 미니게임 구성, 퀘스트 글
    "scene_setup", "farm_stages_hidden_for_plant", "plant_world_pos", "update_quest_text",
    # 1장 대화 연결
    "talk_to",
}
KEEP_IN_CORE = {"flat_ellipse"}

text = open(SRC).read()
font_idx = text.index("\n# ---------- 글꼴 데이터")
font_tail = text[font_idx:]
body = text[:font_idx]
lines = body.split("\n")

# 위쪽 머리말(extends 줄)을 떼어 내요
assert lines[0].startswith("extends")
lines = lines[1:]

# 최상위 덩어리로 자르기: 들여쓰기 없는 줄에서 새 덩어리가 시작돼요.
# 바로 위의 주석 줄은 아래 덩어리에 붙여요.
chunks = []  # (kind, name, section, text)
section = ""
pending = []
cur = None


def flush():
    global cur
    if cur is not None:
        chunks.append(cur)
        cur = None


for ln in lines:
    if ln.startswith("# ----------"):
        flush()
        section = ln
        chunks.append(("section", "", section, ln + "\n"))
        continue
    top = ln != "" and not ln[0].isspace()
    if top and ln.startswith("#"):
        flush()
        pending.append(ln)
        continue
    if top:
        flush()
        m = re.match(r"(?:static )?func (\w+)", ln)
        if m:
            kind, name = "func", m.group(1)
        else:
            kind, name = "decl", ""
        cur = [kind, name, section, "\n".join(pending + [ln]) + "\n"]
        pending = []
        continue
    if cur is None:
        if ln == "":
            if pending:
                pending.append(ln)
            else:
                chunks.append(("blank", "", section, "\n"))
            continue
        raise SystemExit("unexpected indented line outside chunk: %r" % ln)
    cur[3] += ln + "\n"
flush()
if pending:
    chunks.append(("decl", "", section, "\n".join(pending) + "\n"))


def is_ch1(kind, name, sec):
    if kind != "func":
        return False
    if name in KEEP_IN_CORE:
        return False
    if name in CH1_FUNCS:
        return True
    return any(k in sec for k in CH1_SECTIONS)


core_parts, ch1_parts = [], []
ch1_funcs = {}
for kind, name, sec, t in chunks:
    if kind == "section":
        core_parts.append(t)
        if any(k in sec for k in CH1_SECTIONS):
            ch1_parts.append("\n" + t)
        continue
    if is_ch1(kind, name, sec):
        ch1_parts.append(t)
        ch1_funcs[name] = t
    else:
        core_parts.append(t)

core_text = "".join(core_parts)

# core 에서 부르는 1장 함수 → 빈 훅 함수
DEFAULTS = {
    "void": None, "bool": "false", "int": "0", "float": "0.0", "String": '""', "Vector3": "Vector3.ZERO",
    "Vector2": "Vector2.ZERO", "Array": "[]", "Dictionary": "{}", "Color": "Color()",
}
hooks = []
for name, t in ch1_funcs.items():
    if not re.search(r"\b%s\b" % re.escape(name), core_text):
        continue
    sig_lines = []
    for ln in t.split("\n"):
        if ln.startswith("#"):
            continue
        sig_lines.append(ln)
        if ln.rstrip().endswith(":"):
            break
    sig = "\n".join(sig_lines)
    m = re.search(r"->\s*([\w\.]+)\s*:\s*$", sig)
    ret = m.group(1) if m else "void"
    if ret in DEFAULTS:
        val = DEFAULTS[ret]
    else:
        val = "null"
    body_line = "\tpass" if val is None else "\treturn %s" % val
    hooks.append(sig + "\n" + body_line + "\n")

header = (
    "extends Node3D\n\n"
    "# 모든 장이 함께 쓰는 공통 부분: 주인공, 카메라, 화면, 대화, 미니게임 틀, 소리, 3D 부품.\n"
    "# 장마다 다른 맵과 이야기는 chapter1.gd, chapter2.gd ... 가 이 파일을 이어받아 만들어요.\n\n"
)
hook_text = ""
if hooks:
    hook_text = (
        "\n# ---------- 장마다 덮어쓰는 훅 (빈 함수: 각 장 스크립트가 실제 내용을 채워요) ----------\n\n"
        + "\n".join(hooks)
    )
open(OUT_CORE, "w").write(header + core_text.rstrip("\n") + "\n" + hook_text + font_tail)

ch1_header = (
    'extends "res://core.gd"\n\n'
    "# 1장: 흥부와 놀부. 맵 배치, 이야기 진행, 1장 미니게임.\n"
)
open(OUT_CH1, "w").write(ch1_header + "".join(ch1_parts))
print("core funcs:", sum(1 for c in chunks if c[0] == "func") - len(ch1_funcs), "ch1 funcs:", len(ch1_funcs), "hooks:", len(hooks))
