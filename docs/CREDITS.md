# 재료 출처와 라이선스 기록

출시할 때 크레딧 화면과 스토어 설명에 그대로 옮겨 쓰려고 모아 둔 기록이에요.
새 재료를 넣을 때마다 아래 표에 한 줄씩 더해 주세요.

## 앱 정보

| 항목 | 값 | 메모 |
|---|---|---|
| 앱 고유 ID (안드로이드·iOS 공통) | `com.lostjeonrae2034.game` | 정한 이름 `lostjeonrae2034` 을 안드로이드 규칙(점으로 나눈 두 부분 이상)에 맞춘 형태. 스토어에 한 번 올리면 바꿀 수 없어요. |
| 게임 제목 | 미정 | 지금 쓰는 임시 제목: "옛이야기 책 속으로". 정하면 상표 검색(KIPRIS) 먼저. |
| 판매 주체 | 미정 (개발 먼저) | 개인 계정이면 애플은 실명이 판매자로, 구글은 유료 판매 시 주소가 공개돼요. 회사 겸업 조항 확인 후 결정. |

## 엔진과 글꼴

| 재료 | 출처 | 라이선스 | 해야 할 일 |
|---|---|---|---|
| Godot Engine 4.4.1 | godotengine.org | MIT | 배포하는 게임에 Godot 라이선스 문구와 포함된 서드파티 라이선스 표시 (Engine.get_license_text 로 화면에 띄울 수 있음) |
| 주아체 (Jua) | 우아한형제들 | SIL Open Font License 1.1 | 크레딧에 글꼴 이름과 라이선스 표기. 글꼴 자체를 따로 팔면 안 됨 |

## 캐릭터 (원화 → 3D → 뼈대)

| 캐릭터 | 원화 | 3D 변환 | 플랜 | 3D 라이선스 | 게임에 넣은 날 |
|---|---|---|---|---|---|
| 주인공 | ChatGPT 이미지 | Meshy (모델: 무료 때 생성 / 뼈대·걷기·뛰기 동작: 유료 결제 후 Meshy Animate) | 무료 → 유료 | 모델은 CC BY 4.0 (출처 표시 필요, 유료로 다시 만들면 불필요) | 2026-11-18, 동작 2026-11-19 |
| 흥부 | ChatGPT 이미지 | Meshy | 유료 결제 후 받음 (만든 시점의 플랜 확인 필요) | 유료 플랜이면 출처 표시 불필요 | 2026-11-19 |
| 놀부 | ChatGPT 이미지 | Meshy | 유료 결제 후 받음 (만든 시점의 플랜 확인 필요) | 유료 플랜이면 출처 표시 불필요 | 2026-11-19 |
| 호랑이 | ChatGPT 이미지 (2026-11-19) | Meshy 예정 | | | |
| 누이 | ChatGPT 이미지 (2026-11-19) | Meshy 예정 | | | |
| 오빠 | ChatGPT 이미지 (2026-11-19) | Meshy 예정 | | | |
| 엄마 | ChatGPT 이미지 (2026-11-19) | Meshy 예정 | | | |
| 엄마 옷 입은 호랑이 | ChatGPT 이미지 (2026-11-19) | Meshy 예정 | | | |

- ChatGPT 이미지: OpenAI 이용약관상 생성물의 권리는 사용자에게 있고 상업적 사용 가능.
- Meshy 무료 플랜 결과물: CC BY 4.0. 상업적 사용 가능하지만 출처 표시 필요.
  유료 플랜에서 다시 만들면 출처 표시 없이 쓸 수 있어요. 다시 만든 모델은 표의 "플랜" 칸을 고쳐 주세요.
- 주인공 걷기·뛰기 동작은 Meshy 동작 라이브러리. 주먹 쥔 손 모양과 서 있는 자세는 `tools/prep_meshy_anim.py` 와 게임 코드로 직접 작업.
- 뼈대(리깅)와 손 모양, 몸 무게 나누기는 `tools/rig_meshy.py`(주인공), `tools/rig_npc.py` + `tools/rig_cfg/*.json`(다른 인물)로 직접 작업.

## 직접 만든 재료 (코드와 스크립트로 생성, 외부 재료 없음)

| 재료 | 만든 스크립트 |
|---|---|
| 초가·기와집 모델 (`choga.glb`, `giwa.glb`) | `tools/choga.py`, `tools/giwa.py`, `tools/bake_ao.py` |
| 나무 (`trees.glb`), 잎 그림 | `tools/trees2.py`, `tools/leaf_textures.py` |
| 돌담, 바위, 소품 (장독, 우물, 짚더미, 그루터기, 장승) | `tools/stonewall.py`, `tools/rocks.py`, `tools/props.py` |
| 예전 마을 사람 모델 (`characters.glb`) | `tools/characters*.py` |
| 땅·벽·지붕·한지 질감 | `tools/ground_textures.py`, `tools/house_textures.py` |
| 배경음, 효과음, 자연 소리 | `tools/make_audio.py` (가야금·대금·장구 소리를 수학적으로 합성) |
| 맵, 풀, 꽃, 물, 하늘, 미니게임 그림 | 게임 코드(`source/*.gd`) 안에서 직접 생성 |
| 게임 코드, 대사, 이야기 조각 글 | 개발자와 Claude(Anthropic)가 함께 작성 |

제작 도구로만 쓰고 게임에는 들어가지 않는 것: Blender(bpy), Python 라이브러리(numpy, scipy, Pillow, fontTools).

## 크레딧 화면에 넣을 문구 (초안)

```
엔진: Godot Engine (MIT License)
글꼴: 주아체 © 우아한형제들 (SIL Open Font License 1.1)
일부 3D 모델: Model created with Meshy – CC BY 4.0 License (https://www.meshy.ai)
```

## 마을 사람 (2026-11-19)
- 기본 체형 5종(아저씨·아줌마·할아버지·할머니·아이): ChatGPT 원화 → Meshy 유료 플랜 3D. 옷 색·모자·수염은 게임 코드로 바꿔 12명에 씀.
- 놀부 마누라, 도깨비, 산신령: ChatGPT 원화 → Meshy 유료 플랜 3D.
- 뼈대·가볍게 줄이기: tools/rig_npc.py (설정: tools/rig_cfg/*.json)
