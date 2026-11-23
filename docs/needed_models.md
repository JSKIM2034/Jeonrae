# 새로 만들 모델 목록과 그림 프롬프트

사용자가 ChatGPT로 원화를 뽑고 Meshy로 3D를 만들어 주는 목록이에요. 만든 파일을 저장소에 올리거나 Claude에게 주면 뼈대를 붙이고(tools/rig_meshy.py, tools/rig_npc.py) 게임에 넣어요.
다 넣은 항목은 `[x]`로 바꾸고 docs/CREDITS.md 에 한 줄 더해 주세요.

## 뽑는 방법 (모든 항목 공통)

1. 전래동화 캐릭터를 만들어 둔 ChatGPT 대화방에서 이어서 뽑아요(그림체가 맞아요). 그 방에서는 "공통 앞부분"의 첫 줄(첨부 그림 참고)을 빼고 붙여요. 새 방에서 뽑거나 그림체가 달라지면 주인공 원화를 첨부하고 첫 줄까지 붙여요.
2. 결과 그림이 정면, 전신, 팔이 몸에서 조금 떨어진 자세, 흰 배경인지 확인해요. 손에 든 물건이나 바닥 그림자가 있으면 다시 뽑아요(3D로 바꿀 때 몸에 붙어 버려요).
3. Meshy "Image to 3D"에 넣어요. 주인공 옷(아래 2번)은 Meshy에서 뼈대 붙이기(Rigging)까지 해 주면 걷기 동작을 그대로 씌울 수 있어요.
4. 파일 이름은 각 항목의 `파일:` 이름으로 저장해 주세요.

공통 앞부분 (복사해서 맨 앞에 붙여요):

```
Use the attached character as a strict style reference (same 3D cel-shaded stylized look, same proportions, same face style).
Create a 3D game character concept: full body, front view, standing in a relaxed A-pose with arms held slightly away from the body and legs slightly apart, hands open and empty, plain pure white background, no ground shadow, no props, no text.
Setting: a cozy storybook version of Joseon-era Korea.
```

## 리깅은 이제 필요 없어요 (2026-11-23)

여자 주인공을 만들면서, 지금 주인공의 뼈대와 동작(걷기·뛰기·헤엄·끄덕·깜짝·오르기)을 새 모델에 그대로 씌우는 도구(tools/rig_from_hero.py)를 만들었어요.
그래서 옷 입은 주인공도 **Meshy에서 Image to 3D만** 해 주면 돼요(리깅 크레딧 아낌). 받은 파일은 tools/<이름>_meshy_source.glb 로 보관하고,
rig_from_hero.py 의 관절 위치(어깨, 손끝, 목, 머리, 무릎)를 그 모델에 맞춰 넣은 뒤 prep_meshy_anim.py 로 마무리해요. 치마·도포는 다리 사이가 이어져 있어서 걸을 때 늘어날 수 있으니 화면으로 꼭 확인.

## 원화 상태 (2026-11-23)

15장 모두 원화를 뽑았어요. `docs/concepts/<파일 이름>.jpg` 에 보관 (예: docs/concepts/hero_girl.jpg). 3D 변환은 Meshy 크레딧이 돌아오면 진행.
3D가 오기 전에는 이 원화를 보고 옷가게 화면의 옷 그림, 임시 인물의 옷 색을 맞춰요. 어부 소년(outfit_m_fisher)은 등의 삿갓을 뺀 그림으로 확정.

## 1. 여자 주인공 (가장 먼저)

지금 주인공은 파란 점퍼와 노란 가방을 멘 요즘 남자아이예요. 처음 시작할 때 남자/여자 주인공을 고를 수 있게 하려면 같은 그림체의 여자아이가 필요해요.

- [x] **여자 주인공 기본 옷** · 파일: `hero_girl.glb` (2026-11-23 받음. Meshy 리깅 없이 주인공 뼈대와 동작을 tools/rig_from_hero.py 로 씌움. 걷기·뛰기·헤엄 확인)

```
A modern-day Korean girl, about 10 years old, the same age and height as the reference boy. Shoulder-length dark brown hair with a small hair clip, friendly bright eyes. Wears a light coral zip-up jacket over a white T-shirt, dark navy knee-length shorts over leggings, white sneakers, and a small yellow crossbody bag (same bag as the reference boy). Cheerful, curious expression.
```

## 2. 장터에서 사 입는 옷 (남자 5벌, 여자 5벌)

장터 옷가게에서 엽전으로 사서 갈아입는 옷이에요. 지역마다 파는 옷이 달라서 여러 곳을 오가는 이유가 돼요.
옷 한 벌마다 **주인공이 그 옷을 입은 전신 모델 하나**를 만들어요(옷만 따로 만들면 몸에 맞추기 어려워요). 남자는 지금 주인공 원화를, 여자는 1번 여자 주인공 원화를 첨부해서 "같은 아이가 이 옷을 입은 모습"으로 뽑아요.

공통 뒷부분 (옷 프롬프트 뒤에 붙여요):

```
It must be the exact same child as the reference image (same face and hairstyle), only the outfit changes. Keep the skirt or robe hem no wider than shoulder width and no longer than the ankles so walking animation does not clip. No hat brim wider than the shoulders.
```

| 순서 | 옷 이름 | 파는 곳 | 남자 파일 | 여자 파일 |
|---|---|---|---|---|
| 1 | 설빔 색동옷 | 1장 장터 | `outfit_m_seolbim.glb` | `outfit_f_seolbim.glb` |
| 2 | 농사꾼 옷 | 1장 장터 | `outfit_m_farmer.glb` | `outfit_f_farmer.glb` |
| 3 | 잔칫날 나들이옷 | 2장 잔칫집 | `outfit_m_festival.glb` | `outfit_f_festival.glb` |
| 4 | 바닷가 어부 옷 | 3장 바닷가 | `outfit_m_fisher.glb` | `outfit_f_fisher.glb` |
| 5 | 선비·규수 옷 (특별) | 집 마을 (이야기 3개 끝내면) | `outfit_m_scholar.glb` | `outfit_f_lady.glb` |

### 2-1. 설빔 색동옷
- [ ] 남자: 
```
Wears a traditional Korean New Year children's hanbok: a jeogori jacket with rainbow saekdong striped sleeves, a deep blue kkachi durumagi vest-coat to the knees, light gray baji trousers tied at the ankles, a black bokgeon cloth cap, and traditional white beoseon socks with black shoes.
```
- [ ] 여자:
```
Wears a traditional Korean New Year children's hanbok: a yellow jeogori jacket with rainbow saekdong striped sleeves and a red ribbon tie, a bright red ankle-length chima skirt (not too wide), a black jobawi winter cap with small red tassels, white beoseon socks and flower-shaped shoes. Hair in a single braid with a red daenggi ribbon.
```

### 2-2. 농사꾼 옷
- [ ] 남자:
```
Wears simple undyed hemp work clothes from old Korea: a beige short jeoksam shirt with rolled-up sleeves, beige baji trousers rolled up to the shins and tied with cloth, a straw jipsin sandal on each foot, a white cloth headband, and a small straw rope belt.
```
- [ ] 여자:
```
Wears simple undyed cotton work clothes from old Korea: a cream short jeogori with rolled sleeves, a faded indigo mid-calf work skirt tucked up at one side, a white apron, a white cloth head scarf tied at the back, and straw jipsin sandals.
```

### 2-3. 잔칫날 나들이옷
- [ ] 남자:
```
Wears a festive children's hanbok for a village feast: a jade green jeogori, a sleeveless orange kwaeja vest with a gold-patterned belt sash, light blue baji trousers, a small black hogeon cap with a tiger-pattern front, and black shoes.
```
- [ ] 여자:
```
Wears a festive children's hanbok for a village feast: a pink jeogori with a purple collar band, a jade green ankle-length chima skirt with a thin gold border, a small flower hairpin, hair in two short braids with pink daenggi ribbons, white socks and pink flower shoes.
```

### 2-4. 바닷가 어부 옷
- [ ] 남자:
```
Wears old Korean seaside fisher clothes for a child: an indigo short-sleeved cotton jacket, knee-length indigo trousers, a woven straw conical hat hanging on the back by a string, a rope belt with a small wooden float charm, and straw sandals.
```
- [ ] 여자:
```
Wears old Korean seaside village clothes for a child: a white cotton short jeogori, a knee-length dark indigo work skirt over white leggings, a white cotton head cloth tied in the style of Jeju island divers (fully clothed, not a swimsuit), a rope belt with a small shell charm, and straw sandals.
```

### 2-5. 선비·규수 옷 (특별)
- [ ] 남자:
```
Wears a child-sized scholar outfit of Joseon Korea: a white-and-light-blue dopo robe reaching the shins with a thin blue sash tied at the chest, light gray baji trousers, and a small black bokgeon scholar cap. Looks neat and proud.
```
- [ ] 여자:
```
Wears an elegant child-sized dangui ceremonial jacket in soft green with gold flower patterns over a deep red ankle-length chima skirt (not too wide), hair in a neat braid with a gold-patterned daenggi ribbon and a small jade hairpin.
```

## 3. 새 장소에 필요한 인물 (집 마을, 새 낚시터·약초 자리)

이 인물들은 걷기 동작이 꼭 필요하지 않아서 뼈대 없이 Meshy "Image to 3D"까지만 해 주면 돼요(뼈대는 Claude가 tools/rig_npc.py 로 붙여요).
지금 있는 할머니·아저씨 모델로 대신할 수도 있지만, 얼굴이 겹치지 않게 새로 뽑으면 더 좋아요. 위 "공통 앞부분"을 붙이되 "child" 대신 각 인물 설명을 써요.

- [x] (3D 받음, 뼈대 전) **이야기꾼 할머니** (집 마을, 처음 대화 상대) · 파일: `storyteller.glb`
```
A kind elderly Korean grandmother storyteller, small and slightly hunched, white hair in a low bun with a wooden binyeo hairpin, warm smiling wrinkled face. Wears a muted plum jeogori and a gray chima skirt, with a cloth-wrapped old picture book tied on her back (attached, not held in hands).
```
- [x] (3D 받음, 뼈대 전) **옷가게 아주머니** (장터 옷가게, 옷을 파는 사람) · 파일: `tailor.glb`
```
A cheerful middle-aged Korean cloth merchant woman, round face, hair in a bun with a red cloth band, a measuring cord hanging around her neck, a bright yellow jeogori, a deep blue chima skirt with a striped apron, and a small pincushion tied at her wrist.
```
- [x] (3D 받음, 뼈대 전) **약초꾼 할아버지** (2장 산 계곡 약초 자리) · 파일: `herbalist.glb`
```
A lean, friendly old Korean mountain herb gatherer, long thin white beard, a straw pae-raeng-i hat, a faded green hemp jacket, gray trousers with leg wraps, straw sandals, and a woven bamboo jigae back-basket full of leaves strapped to his back.
```
- [x] (3D 받음, 뼈대 전) **갯바위 어부 아저씨** (3장 갯바위 낚시터) · 파일: `seafisher.glb`
```
A sturdy, sun-tanned Korean seaside fisherman in his forties, short beard, a white towel tied around his head, an indigo short jacket with rolled sleeves, knee-length trousers, straw sandals, and a woven fish basket tied at his hip.
```

## 받은 3D 파일 (GitHub 릴리스 model-1, 저장소에는 너무 커서 안 넣음)

파일이 40~50MB(4K 텍스처 3장)라서 저장소 대신 릴리스에 있어요. 작업할 때 내려받아(curl -L) 쓰고, 게임용으로 줄인 결과만 source/models 에 넣어요.
모양은 약 1000면으로 가볍고, 뼈대는 없어요. tools/rig_npc.py + tools/rig_cfg/<이름>.json 으로 뼈대를 붙이고 텍스처는 1024 로 줄여요.

| 인물 | 게임 파일 이름 | 내려받기 |
|---|---|---|
| 이야기꾼 할머니 | storyteller.glb | https://github.com/JSKIM2034/Jeonrae/releases/download/model-1/export_Meshy_AI_2026-11-23_9a96d5.glb |
| 옷가게 아주머니 | tailor.glb | https://github.com/JSKIM2034/Jeonrae/releases/download/model-1/export_Meshy_AI_2026-11-23_3de71a.glb |
| 약초꾼 할아버지 | herbalist.glb | https://github.com/JSKIM2034/Jeonrae/releases/download/model-1/export_Meshy_AI_2026-11-23_214039.glb |
| 갯바위 어부 아저씨 | seafisher.glb | https://github.com/JSKIM2034/Jeonrae/releases/download/model-1/export_Meshy_AI_2026-11-23_1396de.glb |

| (다시 받음) 엄마 원본 | mom.glb | https://github.com/JSKIM2034/Jeonrae/releases/download/model-1/Little.Hanbok.Helper_Meshy_AI_2026-11-19_7bd92a.glb |
| (다시 받음) 놀부 원본 | nolbu.glb | https://github.com/JSKIM2034/Jeonrae/releases/download/model-1/Smiling.Joseon.Nobleman_Meshy_AI_2026-11-18_062d1d.glb |

- 원본이 백만 면 넘게 무거우면 rig_cfg 에 "keep_uv": true 를 넣어 다시 굽지 않고 줄여요(다시 구우면 그림이 잘게 쪼개져 얼굴이 금 간 것처럼 보여요). 3만 면으로 줄이면 그림 이음매에 금이 남아서 6만 면으로.
- 새 모델은 모두 이 릴리스(model-1)에 "Edit → 파일 추가" 로 올려 달라고 안내해요.

## 메모 (Claude가 구현할 때)

- 지금 주인공은 뼈대가 있는 모델이라 `recolor_outfit()` 이 바로 return 해요. 그래서 1장 "한복"(has_hanbok)을 사도 실제로 옷이 안 바뀌고 있어요. 옷 갈아입기는 "옷마다 주인공 모델 하나를 바꿔 끼우기"로 만들고, 걷기·뛰기·헤엄 동작은 지금 주인공 동작을 같은 뼈대 이름으로 옮겨 씌워요(tools/merge_anims.py).
- 모델이 도착하기 전에는 옷가게 화면과 저장(가진 옷, 입은 옷, 남/여 선택)만 먼저 만들고, 아직 없는 옷은 "준비 중"으로 보여 줘요.
- 웹 용량: 옷 모델 하나에 약 1~2MB(30000면, 1024 텍스처, 손실 압축). 10벌이면 index.pck 가 70MB 를 넘지 않는지 꼭 확인. 넘으면 면 수와 텍스처를 더 줄여요.
