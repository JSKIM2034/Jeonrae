extends "res://core.gd"

# 3장: 별주부전
# 공통 부분(core.gd)을 그대로 쓰고, 맵과 이야기만 여기에 새로 만들어요.
#
# 남쪽(+z)은 바닷가 마을과 뒷산, 북쪽(-z)으로 모래사장을 지나 바다가 펼쳐져요.
# 바닷속(산호 숲 → 해초 숲 → 난파선 → 깊은 골짜기 → 용궁)은 같은 땅의 바다 밑바닥으로 이어질 거예요.

# 땅의 범위 (x: 왼쪽~오른쪽, z: 북쪽~남쪽)
const C3_X0 := -60.0
const C3_X1 := 60.0
const C3_Z0 := -150.0
const C3_Z1 := 60.0
const C3_STEP := 2.0

const SHORE_Z := -6.0          # 물가 (여기서부터 바다)
const PALACE_Y := -11.0        # 용궁 바닥 높이
const VILLAGE_C := Vector3(0, 0, 30)

var height_noise := FastNoiseLite.new()

func chapter_id() -> String:
	return "ch3"

# 다른 마을 부탁을 말할 때 (해녀: 조개를 다 캔 뒤, 용왕: 병이 나은 뒤)
func request_open(id: String) -> bool:
	match id:
		"haenyeo_ssuk":
			return clams_done
		"yongwang_yeongji":
			return king_healed()
	return false

func chapter_state() -> Dictionary:
	return {"quest": quest, "lured": lured, "backed": backed, "ginseng": has_ginseng, "clams": clams_done, "pearls": pearls, "fish": fish_seen, "ending": ending, "king_thanked": king_thanked, "mulji": mulji_done, "octo": octo_found, "chest": chest_done, "seafisher": seafisher_met}

func restore_chapter_state(d: Dictionary) -> void:
	quest = d.get("quest", 0)
	lured = d.get("lured", true)
	backed = d.get("backed", true)
	has_ginseng = d.get("ginseng", false)
	clams_done = d.get("clams", false)
	pearls = d.get("pearls", [false, false, false])
	fish_seen = d.get("fish", [false, false, false, false])
	sync_sea_book()
	ending = d.get("ending", "")
	king_thanked = d.get("king_thanked", false)
	mulji_done = d.get("mulji", false)
	octo_found = d.get("octo", [false, false, false, false, false])
	chest_done = d.get("chest", false)
	seafisher_met = d.get("seafisher", false)

func build_chapter() -> void:
	height_noise.seed = 31
	height_noise.frequency = 0.03
	height_noise.fractal_octaves = 2
	make_surface_materials()
	make_light_and_sky()
	make_stars()
	splat_rect = Rect2(-110, -150, 220, 220)
	make_terrain()
	make_sea()
	make_shore_village()
	make_rock_fishing()
	make_tales()
	make_wild_spots("ch3")
	make_undersea()
	make_palace()
	make_story()
	var r := RandomNumberGenerator.new()
	r.seed = 7
	make_clouds(r)
	# 먼 산은 뭍(남쪽) 뒤로만: 바다 쪽 수평선은 탁 트이게
	add_ridge_ring(170.0, 40.0, 10.0, 26.0, Color(0.3, 0.5, 0.28), Color(0.42, 0.6, 0.36), 41, Vector3(0, 0, 10), Vector2(-0.15, PI + 0.15))

func after_ui() -> void:
	player.position = Vector3(0, height_at(0, 46) + 0.2, 46)

func start_chapter() -> void:
	set_time_of_day(0.0)
	above_fog = [env_ref.fog_density, env_ref.fog_light_color, env_ref.ambient_light_color, sun_light.light_energy]
	apply_story_state()
	if resumed:
		show_card(tr("바닷가 마을\n이어서 걸어요..."), 0.6, 1.6, Callable())
		return
	show_card(tr("바닷가 마을\n별주부전\n\n책장을 넘기자\n짭조름한 바닷바람이 불어왔어요."), 1.0, 4.0, Callable())

# 바닷속은 빛과 안개를 따로 다뤄서 날씨는 들어올 때 정한 그대로예요
func weather_can_change() -> bool:
	return false

func weather_sheltered() -> bool:
	return player != null and (player.position.y < -0.4 or swimming)

func cam_ground(x: float, z: float) -> float:
	return height_at(x, z)

func cam_ceiling() -> float:
	return -0.35 if swimming else INF

func leave_blocked() -> String:
	if event_lock or swimming:
		return tr("지금은 떠날 수 없어요!")
	return ""

# 남쪽 끝 이정표: 2장으로 돌아가요
func on_gate() -> void:
	ask("", tr("어디로 갈까요?\n(바닷가 마을 이야기는 저장돼요.)"), [tr("갈대 나루 건너 이야기골(집 마을)로"), tr("오누이 고갯길로 돌아가기"), tr("더 둘러볼래요")], func(i: int):
		if i == 0:
			go_to_chapter("home", road_card_text("home"))
		elif i == 1:
			try_go("ch2"))

# 집 마을에서 갈대 나루를 건너오면 남쪽 어귀에서 바다(북쪽)를 보고 서요
func arrive_from(from: String) -> void:
	if from == "home":
		player.position = Vector3(0, height_at(0, 46) + 0.3, 46)
		cam_yaw = 0.0
		cam_yaw_target = 0.0

# ---------- 땅 높이 ----------

func height_at(x: float, z: float) -> float:
	var h := 0.0
	if z > SHORE_Z:
		# 모래사장(물가에서 완만하게 오르다가) → 마을 언덕
		h = remap(clampf(z, SHORE_Z, 14.0), SHORE_Z, 14.0, 0.0, 1.0)
		h += smoothstep(14.0, 40.0, z) * 0.8
		h += height_noise.get_noise_2d(x, z) * 0.6 * smoothstep(10.0, 20.0, z)
		# 양옆은 완만한 언덕 (뭍에서만)
		h += 12.0 * smoothstep(30.0, 58.0, absf(x)) * smoothstep(SHORE_Z + 2.0, SHORE_Z + 18.0, z)
	else:
		# 바다 밑: 물가에서 깊어져 산호 숲(-8 m) → 골짜기(-14 m) → 용궁 터(-11 m)
		var d := SHORE_Z - z
		h = -smoothstep(0.0, 30.0, d) * 8.0
		h -= smoothstep(60.0, 90.0, d) * 6.0
		h += height_noise.get_noise_2d(x, z) * 1.4 * smoothstep(4.0, 20.0, d)
		# 용궁 터는 평평한 너른 바닥
		var pal := (1.0 - smoothstep(16.0, 24.0, absf(x))) * smoothstep(-94.0, -100.0, z) * smoothstep(-142.0, -136.0, z)
		h = lerpf(h, PALACE_Y, pal)
	# 남쪽 끝은 뒷산 (완만하게)
	h += 12.0 * smoothstep(44.0, 62.0, z)
	if z <= SHORE_Z:
		# 바다 양옆은 물속 바위 언덕 (수면 위로는 안 솟아요 → 탁 트인 바다)
		var ridge := 7.0 * smoothstep(34.0, 58.0, absf(x))
		var cap := -1.5 * smoothstep(SHORE_Z, SHORE_Z - 10.0, z)
		h = maxf(h, minf(h + ridge, cap))
	return h

func on_ground(x: float, z: float, lift: float = 0.0) -> Vector3:
	return Vector3(x, height_at(x, z) + lift, z)

# ---------- 땅 만들기 (모양 + 밟을 수 있는 바닥) ----------

func make_terrain() -> void:
	var nx := int((C3_X1 - C3_X0) / C3_STEP) + 1
	var nz := int((C3_Z1 - C3_Z0) / C3_STEP) + 1
	var heights := PackedFloat32Array()
	heights.resize(nx * nz)
	for iz in nz:
		for ix in nx:
			heights[iz * nx + ix] = height_at(C3_X0 + ix * C3_STEP, C3_Z0 + iz * C3_STEP)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for iz in nz - 1:
		for ix in nx - 1:
			var q := []
			for c in [[ix, iz], [ix + 1, iz], [ix + 1, iz + 1], [ix, iz + 1]]:
				q.append(Vector3(C3_X0 + c[0] * C3_STEP, heights[c[1] * nx + c[0]], C3_Z0 + c[1] * C3_STEP))
			for idx in [0, 1, 2, 0, 2, 3]:
				st.add_vertex(q[idx])
	st.index()
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = ground_mat
	add_child(mi)
	var body := StaticBody3D.new()
	add_child(body)
	var col := CollisionShape3D.new()
	var hs := HeightMapShape3D.new()
	hs.map_width = nx
	hs.map_depth = nz
	var scaled := PackedFloat32Array()
	scaled.resize(heights.size())
	for i in heights.size():
		scaled[i] = heights[i] / C3_STEP
	hs.map_data = scaled
	col.shape = hs
	col.scale = Vector3.ONE * C3_STEP
	col.position = Vector3((C3_X0 + C3_X1) / 2.0, 0, (C3_Z0 + C3_Z1) / 2.0)
	body.add_child(col)
	var none := Color(0, 0, 0, 0)
	add_solid(Vector3(0, 10, 54), Vector3(120, 40, 1), none)
	add_solid(Vector3(-44, 10, -40), Vector3(1, 40, 220), none)
	add_solid(Vector3(44, 10, -40), Vector3(1, 40, 220), none)
	add_solid(Vector3(0, 0, -142), Vector3(120, 60, 1), none)
	# 바닷속은 아직 만드는 중: 물가에서 막아 둬요
	sea_wall = add_solid(Vector3(0, 5, SHORE_Z - 3.0), Vector3(90, 20, 1), none)

# 모래사장은 흙빛, 마을 길도 흙빛으로
func paint_ground_splat() -> void:
	var x := -44.0
	while x <= 44.0:
		var z := -146.0
		while z <= 14.0:
			splat_stamp(splat_r, x, z, 1.2, 2.6, 0.95)
			z += 2.0
		x += 2.0
	var z2 := 14.0
	while z2 < 48.0:
		splat_stamp(splat_r, 0.0, z2, 0.6, 1.8)
		z2 += 0.6

func splat_forest(_x: float, _z: float) -> float:
	return 0.0

# ---------- 바다 ----------

func make_sea() -> void:
	sea_uv_t = 0.0
	# 수면은 수평선까지 넓게
	var wd := 900.0
	var dp := 700.0
	var c := Vector3(0, 0, SHORE_Z - dp / 2.0)
	var sea_mat := water_material(2, Vector4(c.x, c.z, wd / 2.0, dp / 2.0), Color(0.08, 0.36, 0.55), Color(0.3, 0.68, 0.78), Vector2(0.0, 0.03), 0.9, false)
	# 수면이 아주 넓어서 물가 빛깔이 바닷가 몇 미터에만 생기게 폭을 맞춰요
	sea_mat.set_shader_parameter("edge_scale", dp / 2.0 / 6.0)
	sea_top = add_mbox(self, sea_mat, Vector3(wd, 0.02, dp), c + Vector3(0, 0.05, 2.0))
	make_shore_wash()
	# 물속에서 올려다본 수면: 밝게 일렁이는 반투명 막
	var under := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(wd, dp)
	under.mesh = pm
	under.rotation.x = PI
	under.position = c + Vector3(0, 0.0, 2.0)
	var um := StandardMaterial3D.new()
	um.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	um.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	um.albedo_color = Color(0.75, 0.97, 1.0, 0.45)
	um.albedo_texture = tex_or("sea_sand", null)
	um.uv1_scale = Vector3(wd / 9.0, dp / 9.0, 1)
	um.disable_fog = false
	under.material_override = um
	under.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(under)
	sea_under = under


# ======================================================================
# 이야기: 별주부전
# 바닷가에서 지친 자라를 만나 뒷산 토끼를 찾아 주고, 자라 등에 올라 바닷속 용궁까지.
# 용왕의 병에 토끼 간이 필요하다는 말에 토끼는 꾀를 내고, 문어 장군을 따돌려 물 위로!
# ======================================================================

const S_ARRIVE := 0   # 바닷가에서 자라 만나기
const S_FIND := 1     # 뒷산에서 토끼 찾기
const S_LURE := 2     # 토끼를 데리고 자라에게
const S_DIVE := 3     # 물살 고리 따라 내려가기
const S_DEEP := 4     # 산호 숲·해초 숲·골짜기를 지나 용궁 문으로
const S_GATE := 5     # 넙치 문지기
const S_COURT := 6    # 용왕 뵙기
const S_FEAST := 7    # 용궁 잔치 돕기
const S_ESCAPE := 8   # 문어 장군을 따돌리고 물 위로
const S_END := 9

const JARA_BEACH := Vector3(4, 0, -3.2)
const HAENYEO_POS := Vector3(15, 0, 5)
const CLAM_POS := Vector3(22, 0, -3.5)
const GINSENG_POS := Vector3(-35, 0, 45)
# 토끼가 숨을 수 있는 덤불 자리 (할 때마다 이 중 넷을 골라 숨어요)
const RABBIT_SPOTS := [Vector3(-17, 0, 25), Vector3(-29, 0, 34), Vector3(-22, 0, 45), Vector3(-33, 0, 23), Vector3(-12, 0, 40),
	Vector3(-38, 0, 38), Vector3(-26, 0, 20), Vector3(14, 0, 40), Vector3(24, 0, 30), Vector3(30, 0, 44)]
var rabbit_route: Array = []
var tree_spots: Array = []
var rabbit_stam := 1.0
var rabbit_rest := 0.0
var rabbit_phase := 0.0
var rabbit_caught := false
var rabbit_taunt := 0.0
var rabbit_dir := Vector3.FORWARD
const RABBIT_CATCHES := 3      # 세 번 잡아야 항복해요 (두 번은 쏙 빠져나가요)
var rabbit_catches := 0
var rabbit_called := false

func pick_rabbit_route() -> void:
	var idx := range(RABBIT_SPOTS.size())
	idx.shuffle()
	rabbit_route = []
	for k in 4:
		rabbit_route.append(RABBIT_SPOTS[idx[k]])
	# 첫 자리는 바닷가 마을에서 가장 가까운 덤불 (처음부터 한참 헤매지 않게)
	var best := 0
	for k in rabbit_route.size():
		if (rabbit_route[k] as Vector3).distance_to(VILLAGE_C) < (rabbit_route[best] as Vector3).distance_to(VILLAGE_C):
			best = k
	var first: Vector3 = rabbit_route[best]
	rabbit_route.remove_at(best)
	rabbit_route.push_front(first)
	rabbit_hop = 0
	rabbit_catches = 0
	rabbit_called = false

# 토끼를 찾는 동안은 머리 위 이름이 나무 뒤에서도 노랗게 보여요
func set_rabbit_beacon(on: bool) -> void:
	var rb := npc("rabbit")
	if rb == null:
		return
	for lb in rb.find_children("*", "Label3D", false, false):
		var l := lb as Label3D
		l.no_depth_test = on
		l.modulate = Color(1.0, 0.9, 0.35) if on else Color.WHITE
		l.outline_size = 18 if on else 12
const GATE_Z := -101.0
const YONGWANG_POS := Vector3(0, 0, -115.5)
const OCTOPUS_POS := Vector3(-6, 0, -111)
const CRAB_POS := Vector3(6, 0, -110)
const FLATFISH_POS := Vector3(4.2, 0, -100)
const DRUM_POS := Vector3(9, 0, -113)
const BIGCLAM_POS := Vector3(-10, 0, -110)
const WRECK_C := Vector3(17, 0, -58)

var lured := true          # 토끼를 함께 꾀었는지
var backed := true         # 토끼 꾀에 맞장구쳤는지
var has_ginseng := false
var clams_done := false
var pearls := [false, false, false]
var fish_seen := [false, false, false, false]
var ending := ""   # "ginseng": 산삼을 줌, "plain": 위로만 함(용왕은 아직 앓음), "late": 나중에 산삼을 가져다줌
var king_thanked := false
var ginseng_spot: Node3D

func king_healed() -> bool:
	return ending == "ginseng" or ending == "late"
var sea_wall: CollisionShape3D
var sea_top: MeshInstance3D
var sea_under: MeshInstance3D
var above_fog: Array = []
var under_amt := -1.0
var rings: Array = []          # [노드, 지났는지]
var ring_next := 0
var rabbit_hop := 0
var rabbit_busy := false
var follow_on := false
var follow_phase := {}
var schools: Array = []        # [몸 멀티메시, 꼬리 멀티메시, 중심, 반지름, 속도, 높이]
var jellies: Array = []        # [노드, 처음 위치, 위상]
var jelly_cool := 0.0
var shafts: Array = []
var bubbles: CPUParticles3D
var helmet: Node3D
var chase_on := false
var chase_wait := 0.0
var ink_t := 0.0
var event_lock := false
var swim_shown := false
var gate_parts: Array = []     # 카메라가 지나갈 때 잠깐 숨겨요

# 물살 고리: 산호 숲을 굽이굽이 지나 해초 숲 어귀까지
# 물살 고리: 물가에서 용궁 문 앞 골짜기 끝까지 약 10m 간격으로 길을 안내해요
const RING_PTS := [Vector3(2, -2.2, -12), Vector3(-5, -3.6, -22), Vector3(-9, -5.0, -32), Vector3(-2, -6.0, -42),
	Vector3(7, -7.0, -51), Vector3(6, -8.0, -61), Vector3(-2, -9.0, -70), Vector3(-5, -10.0, -79), Vector3(0, -9.5, -88)]

const FISH_KINDS_KO := [
	{"name": "줄돔", "col": Color(0.98, 0.85, 0.3), "stripe": Color(0.2, 0.2, 0.25), "c": Vector3(-9, -4.0, -20), "r": 4.5},
	{"name": "쥐치", "col": Color(0.45, 0.72, 0.98), "stripe": Color(0.95, 0.95, 1.0), "c": Vector3(11, -5.0, -30), "r": 5.0},
	{"name": "볼락", "col": Color(0.9, 0.45, 0.38), "stripe": Color(0.6, 0.25, 0.25), "c": Vector3(-7, -7.0, -55), "r": 4.0},
	{"name": "등불고기", "col": Color(0.55, 1.0, 0.9), "stripe": Color(1.0, 1.0, 0.7), "c": Vector3(5, -10.0, -80), "r": 5.0},
]
var FISH_KINDS: Array = trd(FISH_KINDS_KO)

func npc(id: String) -> Node3D:
	return npcs[id]

func body_of(n: Node3D) -> Node3D:
	for ch in n.get_children():
		if ch is Node3D and (ch as Node3D).has_meta("blink_at"):
			return ch
	return null

# ---------- 바닷가 마을과 뒷산 ----------

func make_shore_village() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 13
	var c := VILLAGE_C
	make_house(on_ground(c.x - 8, c.z), Vector3(4.4, 2.7, 3.4), Color(0.93, 0.89, 0.8), Color(0.8, 0.66, 0.3), "thatch")
	make_house(on_ground(c.x + 9, c.z + 2), Vector3(4.2, 2.6, 3.3), Color(0.93, 0.89, 0.8), Color(0.78, 0.64, 0.3), "thatch")
	# 해녀네 작은 초가와 그물
	make_house(on_ground(HAENYEO_POS.x + 3.5, HAENYEO_POS.z + 3.2), Vector3(3.6, 2.4, 3.0), Color(0.9, 0.86, 0.78), Color(0.74, 0.62, 0.32), "thatch")
	# 모래사장 바위 (자라가 쉬는 넓적 바위 포함)
	var rocks := [[on_ground(JARA_BEACH.x + 1.6, JARA_BEACH.z - 0.6, 0.2), Vector3(2.4, 0.7, 1.8), Color(0.52, 0.5, 0.48)]]
	for i in 26:
		var p := Vector2(r.randf_range(-36, 36), r.randf_range(SHORE_Z - 2.0, 8.0))
		if absf(p.x) < 6.0:
			continue
		var sz := Vector3(r.randf_range(0.6, 1.8), r.randf_range(0.4, 1.0), r.randf_range(0.6, 1.5))
		rocks.append([on_ground(p.x, p.y, sz.y * 0.3), sz, stone_color(r)])
	add_blobs(self, rocks, stone_blob_mat)
	# 뒷산 숲 (토끼가 숨는 곳)
	for k in 70:
		var p2 := Vector2(r.randf_range(-40, 36), r.randf_range(18, 50))
		if absf(p2.x) < 4.0 or Vector2(p2.x - c.x, p2.y - c.z).length() < 12.0:
			continue
		var near_spot := false
		for sp in RABBIT_SPOTS:
			if Vector2(p2.x - sp.x, p2.y - sp.z).length() < 3.5:
				near_spot = true
		if near_spot:
			continue
		make_tree(on_ground(p2.x, p2.y, -0.1))
		tree_spots.append(Vector2(p2.x, p2.y))
	# 토끼가 숨는 덤불 (잎 그림을 엇갈려 꽂은 풍성한 덤불)
	for sp in RABBIT_SPOTS:
		for k in 3:
			var a := k * TAU / 3.0 + r.randf_range(-0.4, 0.4)
			var bp := on_ground(sp.x + cos(a) * 1.5, sp.z + sin(a) * 1.3)
			make_leaf_bush(bp, Vector3(r.randf_range(1.5, 2.2), r.randf_range(1.0, 1.4), r.randf_range(1.4, 2.0)), Color(0.32, 0.55, 0.26).lerp(Color(0.42, 0.62, 0.3), r.randf()), int(sp.x * 13.0 + sp.z * 7.0) + k)
	# 갯벌 (조개 캐기)
	flat_ellipse(on_ground(CLAM_POS.x, CLAM_POS.z) + Vector3(0, 0.03, 0), 3.2, 2.2, 0.0, make_color(Color(0.42, 0.36, 0.3)))
	clam_spot = make_spot(on_ground(CLAM_POS.x, CLAM_POS.z), "clam", "", tr("갯벌"), true)
	# 산삼 (뒷산 깊은 곳 나무 아래)
	var gs := make_spot(on_ground(GINSENG_POS.x, GINSENG_POS.z), "ginseng", "", "", true)
	ginseng_spot = gs
	add_blobs(gs, [
		[Vector3(0, 0.25, 0), Vector3(0.06, 0.5, 0.06), Color(0.3, 0.5, 0.2)],
		[Vector3(0.12, 0.45, 0), Vector3(0.3, 0.04, 0.14), Color(0.35, 0.62, 0.28), Vector3(0, 0, -20)],
		[Vector3(-0.12, 0.45, 0.05), Vector3(0.3, 0.04, 0.14), Color(0.35, 0.62, 0.28), Vector3(0, 30, 20)],
		[Vector3(0, 0.56, 0), Vector3(0.12, 0.1, 0.12), Color(0.9, 0.2, 0.2)],
	])
	# 남쪽 길 끝: 걸어 들어가면 갈대 나루 건너 이야기골로
	add_exit(on_ground(0.0, 51.8), 1.8, "home", tr("이야기골 가는 길"))

func make_leaf_bush(pos: Vector3, size: Vector3, c: Color, seed_v: int) -> void:
	if not tree_tried:
		load_trees()
	var r := RandomNumberGenerator.new()
	r.seed = seed_v
	var mi := MeshInstance3D.new()
	mi.mesh = leaf_bush_mesh(size, c, int(maxf(size.x, size.z) * 7.0) + 6, r)
	mi.material_override = leaf_mat
	mi.position = pos + Vector3(0, size.y * 0.45, 0)
	add_child(mi)

# ---------- 바닷속 ----------

func make_undersea() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 77
	# 산호 숲 (얕은 곳, 알록달록): 가지 산호, 관 산호, 부채 산호를 한 덩어리 메시로
	var spots := []
	for i in 150:
		var x := r.randf_range(-34, 34)
		var z := r.randf_range(-48, -10)
		if absf(x) < 3.0 and z > -40.0:
			continue
		spots.append(on_ground(x, z, -0.05))
	add_coral_field(spots, r)
	# 바닷속 바위
	var rocks := []
	for i in 70:
		var x2 := r.randf_range(-38, 38)
		var z2 := r.randf_range(-130, -10)
		if absf(x2) < 18.0 and z2 < -96.0:
			continue
		var sz := Vector3(r.randf_range(1.0, 3.0), r.randf_range(0.6, 2.0), r.randf_range(1.0, 2.6))
		rocks.append([on_ground(x2, z2, sz.y * 0.2), sz, stone_color(r).darkened(0.1)])
	add_blobs(self, rocks, stone_blob_mat)
	make_seabed()
	make_sea_decor(r)
	make_kelp(r)
	make_wreck()
	make_fish_schools()
	make_jellies(r)
	make_light_shafts(r)
	make_rings()
	# 헤엄칠 때 뽀글뽀글 거품
	bubbles = CPUParticles3D.new()
	bubbles.amount = 14
	bubbles.lifetime = 1.6
	bubbles.emitting = false
	var bm := SphereMesh.new()
	bm.radius = 0.05
	bm.height = 0.1
	bm.radial_segments = 6
	bm.rings = 3
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.9, 0.97, 1.0, 0.55)
	bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.material = bmat
	bubbles.mesh = bm
	bubbles.direction = Vector3.UP
	bubbles.spread = 25.0
	bubbles.gravity = Vector3(0, 1.6, 0)
	bubbles.initial_velocity_min = 0.3
	bubbles.initial_velocity_max = 0.8
	bubbles.scale_amount_min = 0.6
	bubbles.scale_amount_max = 1.6
	bubbles.position = Vector3(0, 1.6, 0.3)
	bubbles.local_coords = false
	player_bubbles_pending = true

var player_bubbles_pending := false

# ---------- 산호 만들기 (둥근 덩어리 대신 진짜 가지·대롱 모양) ----------
const CORAL_COLS := [Color(1.0, 0.5, 0.55), Color(1.0, 0.62, 0.55), Color(0.7, 0.55, 0.95), Color(0.95, 0.55, 0.78), Color(1.0, 0.7, 0.45)]

func coral_tube(st: SurfaceTool, a: Vector3, b: Vector3, r0: float, r1: float, c0: Color, c1: Color, sides: int = 6) -> void:
	var axis := (b - a).normalized()
	var ref := Vector3.UP if absf(axis.y) < 0.9 else Vector3.RIGHT
	var u := axis.cross(ref).normalized()
	var v := axis.cross(u)
	for k in sides:
		var a0 := TAU * k / sides
		var a1 := TAU * (k + 1) / sides
		var d0 := u * cos(a0) + v * sin(a0)
		var d1 := u * cos(a1) + v * sin(a1)
		var vs := [[a + d0 * r0, d0, c0], [b + d0 * r1, d0, c1], [b + d1 * r1, d1, c1], [a + d0 * r0, d0, c0], [b + d1 * r1, d1, c1], [a + d1 * r0, d1, c0]]
		for vv in vs:
			st.set_normal(vv[1])
			st.set_color(vv[2])
			st.add_vertex(vv[0])

func coral_bulb(st: SurfaceTool, p: Vector3, dir: Vector3, r: float, c: Color) -> void:
	coral_tube(st, p, p + dir * r * 0.7, r * 0.9, r * 1.05, c, c.lightened(0.1))
	coral_tube(st, p + dir * r * 0.7, p + dir * r * 1.4, r * 1.05, r * 0.05, c.lightened(0.1), c.lightened(0.25))

func coral_branch(st: SurfaceTool, r: RandomNumberGenerator, p: Vector3, dir: Vector3, length: float, rad: float, depth: int, c: Color) -> void:
	var mid := p + dir * length * 0.5 + Vector3(r.randf_range(-1, 1), 0, r.randf_range(-1, 1)) * length * 0.08
	var e := p + dir * length
	coral_tube(st, p, mid, rad, rad * 0.9, c.darkened(0.12), c.darkened(0.05))
	coral_tube(st, mid, e, rad * 0.9, rad * 0.8, c.darkened(0.05), c)
	if depth <= 0:
		coral_bulb(st, e, dir, rad * 0.95, c)
		return
	var n := 2 if r.randf() < 0.7 else 3
	for k in n:
		var side := Vector3(r.randf_range(-1, 1), 0, r.randf_range(-1, 1)).normalized()
		var nd := (dir + side * r.randf_range(0.45, 0.8) + Vector3(0, 0.35, 0)).normalized()
		coral_branch(st, r, e, nd, length * r.randf_range(0.62, 0.78), rad * 0.78, depth - 1, c)

func coral_tubes(st: SurfaceTool, r: RandomNumberGenerator, base: Vector3) -> void:
	var c := Color(1.0, 0.84, 0.3).lerp(Color(1.0, 0.94, 0.55), r.randf())
	for k in r.randi_range(4, 7):
		var a := r.randf() * TAU
		var off := Vector3(cos(a), 0, sin(a)) * r.randf_range(0.0, 0.32)
		var h := r.randf_range(0.35, 0.95)
		var rad := r.randf_range(0.09, 0.14)
		var tilt := Vector3(off.x, 1.0, off.z).normalized()
		var top := base + off + tilt * h
		coral_tube(st, base + off, top, rad * 0.85, rad, c.darkened(0.15), c)
		# 위가 뻥 뚫린 대롱: 두툼한 테두리와 어두운 안쪽
		coral_tube(st, top, top + tilt * 0.03, rad, rad * 0.72, c.lightened(0.15), c.lightened(0.1))
		coral_tube(st, top + tilt * 0.03, top - tilt * h * 0.5, rad * 0.72, rad * 0.65, c.darkened(0.45), c.darkened(0.6))

func coral_fan(st: SurfaceTool, r: RandomNumberGenerator, base: Vector3, c: Color) -> void:
	var yaw := r.randf() * TAU
	var right := Vector3(cos(yaw), 0, sin(yaw))
	var stems := [[base, Vector3.UP, 0.5, 0.05, 3]]
	while not stems.is_empty():
		var sdat: Array = stems.pop_back()
		var p: Vector3 = sdat[0]
		var d: Vector3 = sdat[1]
		var e: Vector3 = p + d * float(sdat[2])
		coral_tube(st, p, e, sdat[3], float(sdat[3]) * 0.85, c.darkened(0.08), c, 5)
		if int(sdat[4]) > 0:
			for sgn in [-1.0, 1.0]:
				var nd: Vector3 = (d + right * float(sgn) * r.randf_range(0.35, 0.7)).normalized()
				stems.append([e, nd, float(sdat[2]) * 0.78, float(sdat[3]) * 0.8, int(sdat[4]) - 1])
		else:
			coral_bulb(st, e, d, float(sdat[3]) * 1.2, c)

func add_coral_field(spots: Array, r: RandomNumberGenerator) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for base in spots:
		var c: Color = CORAL_COLS[r.randi() % CORAL_COLS.size()]
		var kind := r.randi() % 3
		if kind == 0:
			for k in r.randi_range(3, 5):
				var d := (Vector3(r.randf_range(-0.5, 0.5), 1.0, r.randf_range(-0.5, 0.5))).normalized()
				coral_branch(st, r, base, d, r.randf_range(0.4, 0.6), r.randf_range(0.07, 0.1), 2, c)
		elif kind == 1:
			coral_tubes(st, r, base)
		else:
			coral_fan(st, r, base, c)
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.5
	m.rim_enabled = true
	m.rim = 0.25
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m
	add_child(mi)

# 바닷속 작은 꾸밈: 불가사리, 소라, 큰 진주조개, 바위 아치 (분위기 그림처럼)
func make_sea_decor(r: RandomNumberGenerator) -> void:
	var items := []
	for i in 60:
		var x := r.randf_range(-34, 34)
		var z := r.randf_range(-130, -9)
		var p := on_ground(x, z, 0.05)
		if r.randf() < 0.5:
			# 불가사리
			var col := Color(1.0, 0.55, 0.3).lerp(Color(1.0, 0.75, 0.4), r.randf())
			var yaw := r.randf() * 360.0
			for k in 5:
				var a := deg_to_rad(yaw + k * 72.0)
				items.append([p + Vector3(cos(a) * 0.17, 0.03, sin(a) * 0.17), Vector3(0.12, 0.06, 0.34), col, Vector3(0, -rad_to_deg(a) + 90.0, 0)])
			items.append([p + Vector3(0, 0.05, 0), Vector3(0.18, 0.08, 0.18), col.lightened(0.1)])
		else:
			# 소라 껍데기
			var sc := Color(0.98, 0.94, 0.88).lerp(Color(0.95, 0.8, 0.85), r.randf())
			for k in 3:
				items.append([p + Vector3(0, 0.09 + k * 0.09, -k * 0.05), Vector3(0.3 - k * 0.08, 0.2 - k * 0.04, 0.36 - k * 0.09), sc, Vector3(-20, 0, 0)])
	add_blobs(self, items, blob_gloss())
	# 커다란 진주조개 (꾸밈)
	var shine := StandardMaterial3D.new()
	shine.albedo_color = Color(1.0, 0.97, 0.95)
	shine.emission_enabled = true
	shine.emission = Color(1.0, 0.9, 0.95)
	shine.emission_energy_multiplier = 1.0
	for cp in [Vector2(-8, -15), Vector2(13, -36), Vector2(-14, -112)]:
		var c := on_ground(cp.x, cp.y)
		add_blobs(self, [
			[c + Vector3(0, 0.3, 0), Vector3(1.8, 0.45, 1.5), Color(0.98, 0.85, 0.85)],
			[c + Vector3(0, 0.9, -0.5), Vector3(1.75, 0.3, 1.35), Color(0.95, 0.82, 0.9), Vector3(-50, 0, 0)],
		], blob_gloss())
		var pe := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.32
		sm.height = 0.64
		pe.mesh = sm
		pe.material_override = shine
		pe.position = c + Vector3(0, 0.75, 0.1)
		add_child(pe)
	# 바위 아치 (아래로 헤엄쳐 지나갈 수 있어요)
	var ac := on_ground(-14, -30)
	var arch := []
	for k in 9:
		var a := PI * k / 8.0
		arch.append([ac + Vector3(cos(a) * 3.2, sin(a) * 3.4, 0), Vector3(1.8, 1.6, 1.8), Color(0.5, 0.55, 0.58).lerp(Color(0.42, 0.6, 0.45), (k % 3) * 0.3)])
	add_blobs(self, arch, stone_blob_mat)
	for k in [0, 8]:
		var a2: float = PI * k / 8.0
		add_solid(ac + Vector3(cos(a2) * 3.2, 1.0, 0), Vector3(1.6, 2.4, 1.6), Color(0, 0, 0, 0))

# 바다 밑 모래: 물결빛이 일렁이는 모래 그림을 깔고, 반짝이는 빛 그물이 천천히 흘러요
func make_seabed() -> void:
	var z0 := C3_Z0 + 2.0
	var z1 := SHORE_Z + 4.0
	var step := 2.0
	var nx := int((C3_X1 - C3_X0 - 8.0) / step) + 1
	var nz := int((z1 - z0) / step) + 1
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for iz in nz - 1:
		for ix in nx - 1:
			var q := []
			for c in [[ix, iz], [ix + 1, iz], [ix + 1, iz + 1], [ix, iz + 1]]:
				var x: float = C3_X0 + 4.0 + c[0] * step
				var z: float = z0 + c[1] * step
				q.append(Vector3(x, minf(height_at(x, z) + 0.04, -0.02), z))
			for idx in [0, 1, 2, 0, 2, 3]:
				st.add_vertex(q[idx])
	st.generate_normals()
	var sh := Shader.new()
	sh.code = """shader_type spatial;
uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float shore_z = -6.0;
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 uv = wp.xz / 7.0;
	vec3 base = texture(tex, uv).rgb;
	vec3 move = texture(tex, uv * 1.37 + vec2(TIME * 0.035, TIME * 0.022)).rgb;
	float glint = max(dot(move, vec3(0.333)) - 0.86, 0.0) * 2.5;
	float depth = clamp(-wp.y / 14.0, 0.0, 1.0);
	vec3 col = base * 0.78 * mix(vec3(1.0), vec3(0.32, 0.38, 0.62), depth);
	ALBEDO = col;
	EMISSION = vec3(1.0, 0.97, 0.85) * glint * (1.0 - depth * 0.85);
	ROUGHNESS = 0.95;
	float edge = smoothstep(shore_z + 3.0, shore_z - 1.0, wp.z);
	ALPHA = edge;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("tex", tex_or("sea_sand", null))
	m.set_shader_parameter("shore_z", SHORE_Z)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

# 해초: 그림(다시마 한 가닥)을 십자로 세운 판 두 장, 물결 따라 하늘하늘
func make_kelp(r: RandomNumberGenerator) -> void:
	var tex := tex_or("sea_kelp", null)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for card in 2:
		var a := card * PI / 2.0 + 0.3
		var side := Vector3(cos(a), 0, sin(a)) * 0.5
		var segs := 6
		for k in segs:
			var y0 := float(k) / segs
			var y1 := float(k + 1) / segs
			var pa := Vector3(0, y0, 0) - side
			var pb := Vector3(0, y0, 0) + side
			var pc := Vector3(0, y1, 0) + side
			var pd := Vector3(0, y1, 0) - side
			for v in [[pa, Vector2(0, 1.0 - y0)], [pb, Vector2(1, 1.0 - y0)], [pc, Vector2(1, 1.0 - y1)], [pa, Vector2(0, 1.0 - y0)], [pc, Vector2(1, 1.0 - y1)], [pd, Vector2(0, 1.0 - y1)]]:
				st.set_uv(v[1])
				st.set_normal(Vector3(-side.z, 0.3, side.x).normalized())
				st.add_vertex(v[0])
	var mesh := st.commit()
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode cull_disabled;
uniform sampler2D tex : source_color, filter_linear_mipmap;
void vertex() {
	float h = VERTEX.y;
	float ph = MODEL_MATRIX[3].x * 0.7 + MODEL_MATRIX[3].z * 0.4;
	VERTEX.x += sin(TIME * 0.9 + ph + h * 2.4) * 0.22 * h * h;
	VERTEX.z += cos(TIME * 0.7 + ph + h * 2.0) * 0.16 * h * h;
}
void fragment() {
	vec4 c = texture(tex, UV);
	if (c.a < 0.45) { discard; }
	ALBEDO = c.rgb * COLOR.rgb;
	ROUGHNESS = 0.6;
	BACKLIGHT = vec3(0.25, 0.35, 0.1);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("tex", tex)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	var xs := []
	var tries := 0
	while xs.size() < 190 and tries < 4000:
		tries += 1
		var x := r.randf_range(-36, 36)
		var z := r.randf_range(-70, -38)
		if absf(x) < 2.5:
			continue
		if Vector2(x - WRECK_C.x, z - WRECK_C.z).length() < 7.0:
			continue
		var near_ring := false
		for rp in RING_PTS:
			if Vector2(x - rp.x, z - rp.z).length() < 3.2:
				near_ring = true
		if near_ring:
			continue
		var hgt := r.randf_range(3.5, 7.0)
		xs.append([Transform3D(Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3(hgt * 0.42, hgt, hgt * 0.42)), on_ground(x, z, -0.1)), Color(1, 1, 1).lerp(Color(0.75, 0.95, 0.6), r.randf())])
	for i in 60:
		var x2 := r.randf_range(-38, 38)
		var z2 := r.randf_range(-96, -10)
		var h2 := r.randf_range(1.6, 3.2)
		xs.append([Transform3D(Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3(h2 * 0.42, h2, h2 * 0.42)), on_ground(x2, z2, -0.1)), Color(1, 1, 1).lerp(Color(0.85, 1.0, 0.7), r.randf())])
	mm.instance_count = xs.size()
	for i in xs.size():
		mm.set_instance_transform(i, xs[i][0])
		mm.set_instance_color(i, xs[i][1])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

# 가라앉은 옛 배 (진주 세 알이 숨어 있어요)
func make_wreck() -> void:
	var c := on_ground(WRECK_C.x, WRECK_C.z)
	var hull := Node3D.new()
	hull.position = c + Vector3(0, 0.6, 0)
	hull.rotation = Vector3(0.12, 0.6, 0.25)
	add_child(hull)
	var wood := make_color(Color(0.38, 0.27, 0.18))
	add_mbox(hull, wood, Vector3(2.6, 1.4, 7.0), Vector3(0, 0, 0))
	add_mbox(hull, make_color(Color(0.3, 0.21, 0.14)), Vector3(2.2, 0.15, 6.4), Vector3(0, 0.75, 0))
	var mast := add_mcyl(hull, wood, 0.12, 0.14, 4.5, Vector3(0, 2.6, -0.8))
	mast.rotation.z = 0.5
	add_mbox(hull, make_color(Color(0.85, 0.82, 0.72)), Vector3(0.05, 1.8, 2.2), Vector3(0.6, 3.4, -0.8))
	add_solid(c + Vector3(0, 0.8, 0), Vector3(3.0, 1.6, 7.0), Color(0, 0, 0, 0))
	var spots := [Vector3(2.4, 0, 2.2), Vector3(-2.6, 0, -1.4), Vector3(0.8, 0, -4.6)]
	for i in 3:
		var sp: Vector3 = WRECK_C + spots[i]
		var n := make_spot(on_ground(sp.x, sp.z), "pearl", str(i), "", true)
		add_blobs(n, [
			[Vector3(0, 0.12, 0), Vector3(0.7, 0.22, 0.6), Color(0.75, 0.68, 0.62)],
			[Vector3(0, 0.28, -0.12), Vector3(0.66, 0.12, 0.5), Color(0.82, 0.75, 0.7), Vector3(-30, 0, 0)],
			[Vector3(0, 0.26, 0.05), Vector3(0.2, 0.2, 0.2), Color(1.0, 0.98, 0.95)],
		], blob_gloss())

# 물고기 떼: 네 종류가 저마다 동그랗게 맴돌아요. 꼬리 쪽이 살랑살랑
# 몸은 그림 모양을 따라 가운데가 도톰한 입체예요(tools/fish_mesh.py 가 만든 models/sea_fishN.obj).
# 양쪽 옆구리에 같은 그림이 입혀지고, 지느러미와 꼬리는 얇아요
func make_fish_schools() -> void:
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode cull_disabled;
uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform float glow = 0.0;
void vertex() {
	float tail = clamp(0.6 - UV.x, 0.0, 1.0);
	float ph = TIME * 9.0 + float(INSTANCE_ID) * 1.7;
	// 꼬리는 크게, 몸통은 살짝 휘며 헤엄쳐요
	VERTEX.z += sin(ph - UV.x * 4.0) * 0.14 * tail * tail * 1.6;
	VERTEX.z += sin(ph) * 0.015;
}
void fragment() {
	vec4 c = texture(tex, UV);
	// 테두리는 모양(입체 몸)이 정해요. 그림 밖으로 많이 벗어난 곳만 지워요
	if (c.a < 0.15) { discard; }
	ALBEDO = c.rgb;
	EMISSION = c.rgb * glow;
	ROUGHNESS = 0.35;
	SPECULAR = 0.6;
	RIM = 0.3;
	RIM_TINT = 0.5;
}
"""
	for fk in FISH_KINDS.size():
		var info: Dictionary = FISH_KINDS[fk]
		var c: Vector3 = info["c"]
		c.y = maxf(c.y, height_at(c.x, c.z) + 2.5)
		var m := ShaderMaterial.new()
		m.shader = sh
		m.set_shader_parameter("tex", tex_or("sea_fish%d" % fk, null))
		m.set_shader_parameter("glow", 0.6 if fk == 3 else 0.0)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = load("res://models/sea_fish%d.obj" % fk)
		mm.instance_count = 10
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		schools.append([mm, null, c, float(info["r"]), 0.35 + fk * 0.06, fk])

func update_fish_schools(t: float) -> void:
	for sc in schools:
		var bm: MultiMesh = sc[0]
		var c: Vector3 = sc[2]
		var rad: float = sc[3]
		var sp: float = sc[4]
		var fk: int = sc[5]
		for i in 10:
			var a := t * sp + i * 0.42 + fk
			var rr := rad + sin(i * 2.1) * 0.9
			var p := c + Vector3(cos(a) * rr, sin(a * 2.0 + i) * 0.6 + (i % 3) * 0.35, sin(a) * rr * 0.7)
			var fwd := Vector3(-sin(a) * rr, 0, cos(a) * rr * 0.7).normalized()
			# 그림 판의 오른쪽(+x)이 머리: 헤엄치는 쪽을 보게 돌려요
			var side := fwd.cross(Vector3.UP).normalized()
			var bas := Basis(fwd, Vector3.UP, side)
			var sz := 0.9 + (i % 4) * 0.08
			bm.set_instance_transform(i, Transform3D(bas.scaled(Vector3(sz, sz, sz)), p))
		# 가까이 가면 도감에 올라요
		if not fish_seen[fk] and player.position.distance_to(c) < rad + 3.5:
			fish_seen[fk] = true
			sync_sea_book()
			sfx("good")
			float_text(tr("물고기 도감: %s!") % FISH_KINDS[fk]["name"], get_viewport().get_visible_rect().size * Vector2(0.5, 0.35), Color(0.7, 0.95, 1.0), 1.6)
			var all := true
			for b in fish_seen:
				all = all and b
			if all:
				earn(20)
				float_text(tr("물고기 도감 완성!"), get_viewport().get_visible_rect().size * Vector2(0.5, 0.45), Color(1, 0.9, 0.4), 2.0)
			update_quest_text()
			save_progress()

# 깊은 골짜기의 빛나는 해파리 (닿으면 찌릿!)
# 해파리: 둥근 종 모양 몸(가장자리가 물결치는 갓), 속에서 빛나는 네 잎 무늬, 너울대는 입 팔 넷, 가는 촉수 열둘
# 몸은 가장자리로 갈수록 진하게 빛나서(프레넬) 납작하지 않고 둥글게 보여요. 촉수는 셰이더로 물살에 흔들려요.
const JELLY_SHADER := """
shader_type spatial;
render_mode blend_add, cull_disabled, depth_draw_never, unshaded;
uniform vec4 tint : source_color = vec4(0.85, 0.6, 1.0, 1.0);
uniform float rim = 2.2;
uniform float base_a = 0.18;
void fragment() {
	float f = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), rim);
	ALBEDO = tint.rgb * (base_a + f * 1.3);
}
"""
const JELLY_TENTACLE := """
shader_type spatial;
render_mode blend_add, cull_disabled, depth_draw_never, unshaded;
uniform vec4 tint : source_color = vec4(0.95, 0.75, 1.0, 1.0);
uniform float amp = 0.12;
void vertex() {
	float k = UV.y;
	float ph = NODE_POSITION_WORLD.x * 1.7 + NODE_POSITION_WORLD.z * 0.9 + UV.x * 6.28;
	VERTEX.x += sin(TIME * 1.8 + k * 5.0 + ph) * amp * k;
	VERTEX.z += cos(TIME * 1.4 + k * 4.0 + ph) * amp * k;
}
void fragment() {
	ALBEDO = tint.rgb * (0.55 - UV.y * 0.35);
}
"""

# 종 모양 갓: 옆에서 본 윤곽(반지름, 높이)을 돌려 만들어요. 가장자리는 물결 모양
func jelly_bell_mesh(scale_in: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var prof := []
	for k in 13:
		var t := k / 12.0
		var a := t * PI * 0.52
		var rr := sin(a) * 0.62 * (1.0 + 0.08 * t)
		var hh := cos(a) * 0.5 - 0.05 * t * t
		prof.append(Vector2(rr, hh) * scale_in)
	var seg := 32
	for k in prof.size() - 1:
		for a in seg:
			var a0 := TAU * a / seg
			var a1 := TAU * (a + 1) / seg
			var p0: Vector2 = prof[k]
			var p1: Vector2 = prof[k + 1]
			# 가장자리일수록 꽃잎처럼 물결쳐요
			var w0 := 1.0 + (0.06 * sin(a0 * 8.0) if k + 1 >= prof.size() - 3 else 0.0)
			var w1 := 1.0 + (0.06 * sin(a1 * 8.0) if k + 1 >= prof.size() - 3 else 0.0)
			var v := [Vector3(cos(a0) * p0.x, p0.y, sin(a0) * p0.x), Vector3(cos(a1) * p0.x, p0.y, sin(a1) * p0.x),
				Vector3(cos(a1) * p1.x * w1, p1.y, sin(a1) * p1.x * w1), Vector3(cos(a0) * p1.x * w0, p1.y, sin(a0) * p1.x * w0)]
			for q in [0, 2, 1, 0, 3, 2]:
				st.add_vertex(v[q])
	st.generate_normals()
	return st.commit()

# 가는 띠 여러 가닥 (촉수, 입 팔): UV.x 는 가닥 번호, UV.y 는 매달린 곳에서 끝까지 0→1
func jelly_strands_mesh(count: int, ring_r: float, length: float, width: float, frilly: bool) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 10
	for c in count:
		var a := TAU * c / count
		var root := Vector3(cos(a) * ring_r, 0, sin(a) * ring_r)
		var side := Vector3(-sin(a), 0, cos(a)) * width
		for k in steps:
			var t0 := float(k) / steps
			var t1 := float(k + 1) / steps
			var y0 := -length * t0
			var y1 := -length * t1
			var w0 := 1.0 - t0 * 0.6
			var w1 := 1.0 - t1 * 0.6
			if frilly:
				w0 *= 1.0 + 0.6 * absf(sin(t0 * 18.0))
				w1 *= 1.0 + 0.6 * absf(sin(t1 * 18.0))
			var q := [root + Vector3(0, y0, 0) - side * w0, root + Vector3(0, y0, 0) + side * w0, root + Vector3(0, y1, 0) + side * w1, root + Vector3(0, y1, 0) - side * w1]
			var uvs := [Vector2(float(c) / count, t0), Vector2(float(c) / count, t0), Vector2(float(c) / count, t1), Vector2(float(c) / count, t1)]
			for idx in [0, 1, 2, 0, 2, 3]:
				st.set_uv(uvs[idx])
				st.set_normal(Vector3(cos(a), 0, sin(a)))
				st.add_vertex(q[idx])
	return st.commit()

func make_jellies(r: RandomNumberGenerator) -> void:
	var bell := jelly_bell_mesh(1.0)
	var inner := jelly_bell_mesh(0.7)
	var tentacles := jelly_strands_mesh(12, 0.55, 1.9, 0.012, false)
	var arms := jelly_strands_mesh(4, 0.12, 1.0, 0.06, true)
	var bell_sh := Shader.new()
	bell_sh.code = JELLY_SHADER
	var ten_sh := Shader.new()
	ten_sh.code = JELLY_TENTACLE
	var palettes := [Color(0.85, 0.55, 1.0), Color(1.0, 0.55, 0.75), Color(0.5, 0.75, 1.0)]
	for i in 11:
		var x := r.randf_range(-12, 12)
		var z := r.randf_range(-94, -68)
		var y := height_at(x, z) + r.randf_range(2.5, 7.0)
		var n := Node3D.new()
		n.position = Vector3(x, y, z)
		add_child(n)
		var col: Color = palettes[i % palettes.size()]
		var bm := ShaderMaterial.new()
		bm.shader = bell_sh
		bm.set_shader_parameter("tint", col)
		var im := ShaderMaterial.new()
		im.shader = bell_sh
		im.set_shader_parameter("tint", col.lightened(0.3))
		im.set_shader_parameter("base_a", 0.1)
		var tm := ShaderMaterial.new()
		tm.shader = ten_sh
		tm.set_shader_parameter("tint", col.lightened(0.2))
		var am := ShaderMaterial.new()
		am.shader = ten_sh
		am.set_shader_parameter("tint", col)
		am.set_shader_parameter("amp", 0.08)
		for pair in [[bell, bm, Vector3.ZERO], [inner, im, Vector3(0, -0.02, 0)], [tentacles, tm, Vector3(0, 0.0, 0)], [arms, am, Vector3(0, 0.05, 0)]]:
			var mi := MeshInstance3D.new()
			mi.mesh = pair[0]
			mi.material_override = pair[1]
			mi.position = pair[2]
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			n.add_child(mi)
		# 속에서 빛나는 네 잎 무늬
		var glow := StandardMaterial3D.new()
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow.albedo_color = col.lightened(0.45)
		glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glow.albedo_color.a = 0.85
		for k in 4:
			var a := k * TAU / 4.0 + PI / 4.0
			var petal := MeshInstance3D.new()
			var pm := SphereMesh.new()
			pm.radius = 0.09
			pm.height = 0.06
			pm.radial_segments = 12
			pm.rings = 6
			petal.mesh = pm
			petal.material_override = glow
			petal.position = Vector3(cos(a) * 0.13, 0.3, sin(a) * 0.13)
			petal.scale = Vector3(1.3, 1.0, 0.7)
			petal.rotation.y = -a
			petal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			n.add_child(petal)
		var s0 := r.randf_range(0.8, 1.25)
		n.scale = Vector3.ONE * s0
		jellies.append([n, n.position, r.randf() * TAU, s0])

func update_jellies(t: float, delta: float) -> void:
	jelly_cool = maxf(0.0, jelly_cool - delta)
	var body_c := player.position + Vector3(0, 0.8, 0)
	for j in jellies:
		var n: Node3D = j[0]
		var base: Vector3 = j[1]
		var ph: float = j[2]
		n.position = base + Vector3(sin(t * 0.3 + ph) * 1.2, sin(t * 0.8 + ph) * 1.0, cos(t * 0.25 + ph) * 1.0)
		var s0: float = j[3] if j.size() > 3 else 1.0
		# 갓을 오므렸다 펴며 헤엄쳐요 (오므릴 때 살짝 위로)
		var pulse := sin(t * 2.4 + ph)
		n.scale = Vector3(1.0 - pulse * 0.1, 1.0 + pulse * 0.12, 1.0 - pulse * 0.1) * s0
		n.position.y += maxf(0.0, pulse) * 0.15
		if jelly_cool <= 0.0 and swimming and n.position.distance_to(body_c) < 1.3:
			jelly_cool = 1.0
			var away := (body_c - n.position).normalized()
			player.velocity = away * 7.0 + Vector3(0, 1.5, 0)
			sfx("bad")
			shake(10)
			flash(Color(0.85, 0.6, 1.0))
			float_text(tr("찌릿!"), cam.unproject_position(body_c), Color(0.95, 0.7, 1.0), 1.0)

# 물 위에서 비쳐 드는 빛줄기: 가운데가 밝고 가장자리·아래로 갈수록 부드럽게 사라지는 판을 십자로
func make_light_shafts(r: RandomNumberGenerator) -> void:
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform float strength = 0.16;
void fragment() {
	float across = 1.0 - abs(UV.x * 2.0 - 1.0);
	across = across * across * (3.0 - 2.0 * across);
	float down = pow(1.0 - UV.y, 1.6) * smoothstep(0.0, 0.06, UV.y);
	float shimmer = 0.75 + 0.25 * sin(TIME * 1.3 + NODE_POSITION_WORLD.x * 0.7 + UV.y * 3.0);
	ALBEDO = vec3(1.0, 0.95, 0.75);
	ALPHA = across * down * shimmer * strength;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	for i in 18:
		var x := r.randf_range(-26, 26)
		var z := r.randf_range(-74, -10)
		if z < -60.0:
			z = r.randf_range(-118, -100)
		var floor_y := height_at(x, z)
		var h := -floor_y + 0.5
		var root := Node3D.new()
		root.position = Vector3(x, 0.2, z)
		root.rotation = Vector3(r.randf_range(0.18, 0.3), r.randf() * PI, 0)
		add_child(root)
		var w := r.randf_range(1.6, 3.2)
		for q in 2:
			var mi := MeshInstance3D.new()
			var qm := QuadMesh.new()
			qm.size = Vector2(w, h)
			qm.center_offset = Vector3(0, -h / 2.0, 0)
			mi.mesh = qm
			mi.material_override = mat
			mi.rotation.y = q * PI / 2.0
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(mi)
		shafts.append([root, r.randf() * TAU])

# 자라를 따라가는 물살 고리
func make_rings() -> void:
	var pts := RING_PTS
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.9, 0.4)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.85, 0.3)
	mat.emission_energy_multiplier = 1.6
	for p in pts:
		var pp: Vector3 = p
		pp.y = maxf(pp.y, height_at(pp.x, pp.z) + 2.0)
		pp.y = minf(pp.y, -1.6)
		var mi := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 1.05
		tm.outer_radius = 1.3
		tm.rings = 32
		mi.mesh = tm
		mi.material_override = mat.duplicate()
		mi.position = pp
		mi.rotation.x = PI / 2.0
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false
		add_child(mi)
		rings.append([mi, false])

# ---------- 용궁 ----------

func make_palace() -> void:
	var y := PALACE_Y
	var red := make_color(Color(0.85, 0.25, 0.22))
	var jade := make_color(Color(0.35, 0.72, 0.68))
	var gold := glossy_mat(Color(0.95, 0.78, 0.3))
	# 바닥 돌판
	add_mbox(self, make_color(Color(0.5, 0.58, 0.64)), Vector3(26, 0.4, 30), Vector3(0, y + 0.05, -118))
	# 큰 전각
	make_house(Vector3(0, y + 0.25, -123), Vector3(13, 5.5, 7), Color(0.96, 0.9, 0.8), Color(0.2, 0.34, 0.7), "tile")
	# 양옆 작은 전각
	for sx in [-1.0, 1.0]:
		make_house(Vector3(sx * 11.5, y + 0.25, -124), Vector3(6, 3.6, 4.4), Color(0.96, 0.9, 0.8), Color(0.2, 0.34, 0.7), "tile")
	# 전각 앞 하얀 돌계단
	var stone := make_color(Color(0.88, 0.9, 0.9))
	for k in 4:
		add_mbox(self, stone, Vector3(7.0 - k * 0.4, 0.25, 0.6), Vector3(0, y + 0.37 + k * 0.25, -117.6 - k * 0.55))
	# 둘레 하얀 돌난간 (기둥마다 작은 진주)
	var rail := []
	var pearl_tops := []
	for side in [-1.0, 1.0]:
		var zz := -104.0
		while zz > -131.0:
			rail.append([Vector3(side * 12.6, y + 0.75, zz), Vector3(0.32, 1.1, 0.32), Color(0.9, 0.92, 0.92)])
			pearl_tops.append(Vector3(side * 12.6, y + 1.42, zz))
			zz -= 2.2
		add_mbox(self, stone, Vector3(0.18, 0.16, 27.0), Vector3(side * 12.6, y + 1.05, -117.5))
	for xx in [-11.0, -8.8, -6.6, -4.4, 4.4, 6.6, 8.8, 11.0]:
		rail.append([Vector3(xx, y + 0.75, -103.4), Vector3(0.32, 1.1, 0.32), Color(0.9, 0.92, 0.92)])
		pearl_tops.append(Vector3(xx, y + 1.42, -103.4))
	add_blobs(self, rail)
	var shine := StandardMaterial3D.new()
	shine.albedo_color = Color(1.0, 0.97, 0.92)
	shine.emission_enabled = true
	shine.emission = Color(1.0, 0.92, 0.8)
	shine.emission_energy_multiplier = 0.8
	var small := SphereMesh.new()
	small.radius = 0.16
	small.height = 0.32
	for pt in pearl_tops:
		var o := MeshInstance3D.new()
		o.mesh = small
		o.material_override = shine
		o.position = pt
		add_child(o)
	for px in [-5.5, -2.0, 2.0, 5.5]:
		add_mcyl(self, red, 0.28, 0.3, 4.6, Vector3(px, y + 2.5, -119.2))
	# 용궁 문 (붉은 기둥 두 개와 지붕)
	for gx in [-3.0, 3.0]:
		gate_parts.append(add_mcyl(self, red, 0.35, 0.38, 6.0, Vector3(gx, y + 3.0, GATE_Z)))
		add_solid(Vector3(gx, y + 3.0, GATE_Z), Vector3(0.8, 6.0, 0.8), Color(0, 0, 0, 0))
	gate_parts.append(add_mbox(self, jade, Vector3(8.4, 0.5, 1.4), Vector3(0, y + 6.2, GATE_Z)))
	gate_parts.append(add_mbox(self, red, Vector3(7.6, 0.6, 0.6), Vector3(0, y + 5.6, GATE_Z)))
	add_tag_at(Vector3(0, y + 7.2, GATE_Z), tr("용궁"))
	# 진주 등불
	var pearl := StandardMaterial3D.new()
	pearl.albedo_color = Color(1.0, 0.97, 0.9)
	pearl.emission_enabled = true
	pearl.emission = Color(1.0, 0.92, 0.75)
	pearl.emission_energy_multiplier = 2.0
	# 길 양옆 진주 등불: 하얀 돌기둥 위 조개껍데기에 커다란 진주
	var shell_items := []
	for k in 8:
		var lx := -3.6 + (k % 2) * 7.2
		var lz := -105.0 - (k / 2) * 3.4
		add_mbox(self, stone, Vector3(0.6, 1.3, 0.6), Vector3(lx, y + 0.85, lz))
		for f in 5:
			var fa := -1.0 + f * 0.5
			shell_items.append([Vector3(lx + sin(fa) * 0.28, y + 1.62, lz - 0.1 + cos(fa) * 0.05), Vector3(0.22, 0.08, 0.5), Color(1.0, 0.82, 0.7), Vector3(-25, rad_to_deg(fa), 0)])
		var orb := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.36
		sm.height = 0.72
		orb.mesh = sm
		orb.material_override = pearl
		orb.position = Vector3(lx, y + 1.95, lz)
		add_child(orb)
	add_blobs(self, shell_items, blob_gloss())
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(0.9, 0.95, 1.0)
	lamp.light_energy = 2.5
	lamp.omni_range = 22.0
	lamp.position = Vector3(0, y + 6.0, -112)
	add_child(lamp)
	# 둘레 산호와 커다란 조개
	var r := RandomNumberGenerator.new()
	r.seed = 88
	var cspots := []
	for i in 46:
		var a := r.randf() * TAU
		var rr := r.randf_range(14.0, 18.0)
		var p := Vector3(cos(a) * rr, 0, -116 + sin(a) * rr * 1.1)
		cspots.append(on_ground(p.x, p.z, -0.05))
	add_coral_field(cspots, r)
	# 북 (꽃게와 북 치기)
	var drum := make_spot(Vector3(DRUM_POS.x, y, DRUM_POS.z), "drum", "", tr("용궁 북"), true)
	add_mcyl(drum, red, 0.65, 0.65, 0.9, Vector3(0, 1.3, 0)).rotation.x = PI / 2.0
	add_mcyl(drum, make_color(Color(0.95, 0.9, 0.8)), 0.6, 0.6, 0.92, Vector3(0, 1.3, 0)).rotation.x = PI / 2.0
	add_mbox(drum, make_color(Color(0.4, 0.28, 0.18)), Vector3(0.2, 0.8, 0.2), Vector3(0, 0.4, 0))
	# 큰 조개 (진주 받기)
	var bc := make_spot(Vector3(BIGCLAM_POS.x, y, BIGCLAM_POS.z), "bigclam", "", tr("커다란 조개"), true)
	add_blobs(bc, [
		[Vector3(0, 0.4, 0), Vector3(2.2, 0.6, 1.8), Color(0.85, 0.78, 0.9)],
		[Vector3(0, 1.0, -0.6), Vector3(2.1, 0.4, 1.6), Color(0.88, 0.8, 0.95), Vector3(-40, 0, 0)],
		[Vector3(0, 0.75, 0.1), Vector3(0.5, 0.5, 0.5), Color(1.0, 0.98, 0.92)],
	], blob_gloss())

func add_tag_at(pos: Vector3, text: String) -> void:
	var holder := Node3D.new()
	holder.position = pos
	add_child(holder)
	add_tag(holder, text, 0.0)

# ---------- 사람들 ----------

func make_story() -> void:
	make_npc("jara", tr("자라"), Color.WHITE, on_ground(JARA_BEACH.x, JARA_BEACH.z), 1.0, false)
	make_npc("haenyeo", tr("해녀"), Color.WHITE, on_ground(HAENYEO_POS.x, HAENYEO_POS.z), 1.0, true)
	pick_rabbit_route()
	make_npc("rabbit", tr("토끼"), Color.WHITE, on_ground(rabbit_route[0].x, rabbit_route[0].z), 0.85, false)
	make_npc("flatfish", tr("넙치 문지기"), Color.WHITE, Vector3(FLATFISH_POS.x, PALACE_Y + 0.25, FLATFISH_POS.z), 1.0, true)
	make_npc("yongwang", tr("용왕"), Color.WHITE, Vector3(YONGWANG_POS.x, PALACE_Y + 0.25, YONGWANG_POS.z), 1.0, true)
	make_npc("octopus", tr("문어 장군"), Color.WHITE, Vector3(OCTOPUS_POS.x, PALACE_Y + 0.25, OCTOPUS_POS.z), 1.0, false)
	make_npc("crab", tr("꽃게 신하"), Color.WHITE, Vector3(CRAB_POS.x, PALACE_Y + 0.25, CRAB_POS.z), 0.9, true)
	npc("jara").rotation.y = PI * 0.15
	make_mulji_items()
	make_octos()
	make_chest()
	make_ink_trail()

# 이야기 단계에 맞춰 사람들 자리 정하기 (껐다 켜도 이어지게)
func apply_story_state() -> void:
	var jara := npc("jara")
	var rabbit := npc("rabbit")
	if quest == S_ESCAPE:
		# 쫓기던 중이면 용궁 문 앞에서 다시
		player.position = Vector3(0, PALACE_Y + 0.6, GATE_Z + 3.0)
		npc("octopus").position = Vector3(OCTOPUS_POS.x, PALACE_Y + 0.25, OCTOPUS_POS.z)
	if quest >= S_DIVE and quest <= S_DEEP and not resumed_in_sea():
		pass
	if quest >= S_DIVE:
		sea_wall.set_deferred("disabled", true)
		add_helmet()
	if quest == S_DIVE:
		ring_next = 0
		for rg in rings:
			(rg[0] as Node3D).visible = true
	follow_on = quest >= S_LURE and quest <= S_ESCAPE and quest != S_COURT and quest != S_FEAST
	if quest == S_FIND:
		var rp0: Vector3 = rabbit_route[rabbit_hop]
		rabbit.position = on_ground(rp0.x, rp0.z)
		set_rabbit_beacon(true)
	if follow_on:
		if quest >= S_DIVE:
			jara.position = player.position + Vector3(1.6, 0, 1.4)
		else:
			jara.position = on_ground(JARA_BEACH.x, JARA_BEACH.z)
		rabbit.position = player.position + Vector3(-1.6, 0, 1.4)
	if quest == S_COURT or quest == S_FEAST:
		jara.position = Vector3(-2.5, PALACE_Y + 0.25, -111)
		rabbit.position = Vector3(2.0, PALACE_Y + 0.25, -111.5)
		jara.rotation.y = PI
		rabbit.rotation.y = PI
	if quest >= S_END:
		rabbit.visible = false
		jara.position = on_ground(JARA_BEACH.x, JARA_BEACH.z)
	if ginseng_spot != null:
		ginseng_spot.visible = not has_ginseng and not king_healed()
	for i in octos.size():
		octos[i][1] = octo_found[i]
		(octos[i][0] as Node3D).visible = not octo_found[i]
	if chest_lid != null:
		chest_lid.rotation.x = -1.6 if chest_done else 0.0
	update_quest_text()

func resumed_in_sea() -> bool:
	return player.position.z < SHORE_Z

func update_quest_text() -> void:
	var t := ""
	match quest:
		S_ARRIVE:
			t = tr("모래사장 바위에 지쳐 있는 자라에게 말 걸기")
		S_FIND:
			t = tr("뒷산 숲에서 노란 이름표의 토끼를 쫓아가 잡기! (바짝 붙거나 점프해서 덮쳐요) %d/%d") % [rabbit_catches, RABBIT_CATCHES]
		S_LURE:
			t = tr("토끼를 데리고 바닷가 자라에게 가기")
		S_DIVE:
			t = tr("자라를 따라 빛나는 물살 고리 지나기 (%d/%d) | 위로 버튼을 누르면 떠올라요") % [ring_next, rings.size()]
		S_DEEP:
			t = tr("산호 숲과 해초 숲, 깊은 골짜기를 지나 북쪽 용궁 문까지 헤엄치기")
		S_GATE:
			t = tr("용궁 문 앞의 넙치 문지기에게 말 걸기")
		S_COURT:
			t = tr("용궁 전각 앞 용왕님 뵙기")
		S_FEAST:
			t = tr("용궁 잔치 돕기: 꽃게 신하의 북 · 문어 장군의 큰 조개 · 자라와 용궁 춤, 다 하면 용왕님께")
		S_ESCAPE:
			t = tr("문어 장군이 쫓아와요! 남쪽 물가까지 헤엄쳐 올라가기")
		S_END:
			if ending == "plain":
				if has_ginseng:
					t = tr("산삼을 바닷가 자라에게 가져다주기 (용왕님이 아직 앓고 계세요)")
				else:
					t = tr("용왕님이 아직 앓고 계세요. 뒷산 깊은 숲 나무 아래에서 약이 될 풀 찾기")
			else:
				t = tr("별주부전 이야기 끝! 체험판을 모두 마쳤어요. 바닷속을 마음껏 헤엄쳐 보세요")
	var pc := 0
	for b in pearls:
		pc += 1 if b else 0
	var fc := 0
	for b2 in fish_seen:
		fc += 1 if b2 else 0
	if dive_on:
		t = tr("해녀 물질: 숨을 참고 들어가 반짝이는 전복·소라 줍기 (%d/%d) | 위로 버튼으로 숨 쉬기") % [mulji_got, mulji_items.size()]
	var extra := ""
	if quest >= S_DIVE:
		extra = tr(" | 새끼 문어 %d/5") % octo_count()
	quest_label.text = tr("할 일: %s\n엽전 %d냥 | 진주 %d/3 | 물고기 도감 %d/4%s") % [t, shown_coins, pc, fc, extra]

# ---------- 헤엄치기 ----------

func is_swimming() -> bool:
	if player == null or (quest < S_DIVE and not dive_on):
		return false
	# 물가에서 걷기/헤엄치기가 번갈아 깜빡이지 않게, 나올 때는 더 얕아져야 걸어요
	var limit := -0.6 if swimming else -1.0
	return player.position.z < SHORE_Z + 1.0 and height_at(player.position.x, player.position.z) < limit

func swim_ceiling() -> float:
	return -1.1

func fall_limit() -> float:
	return -40.0

func respawn_point() -> Vector3:
	return on_ground(0, 40, 0.5)

# 물방울 구슬: 머리에 투명한 거품을 씌워 물속에서 숨을 쉬어요
func add_helmet() -> void:
	if helmet != null or not player_body.has_meta("skel"):
		return
	var skel: Skeleton3D = player_body.get_meta("skel")
	var bones: Dictionary = player_body.get_meta("bones")
	if not bones.has("head") or not bones.has("hips"):
		return
	var hi: int = (bones["head"] as Array)[0]
	var hip_i: int = (bones["hips"] as Array)[0]
	var head_rest := skel.get_bone_global_rest(hi)
	var tall := head_rest.origin.y - skel.get_bone_global_rest(hip_i).origin.y
	var att := BoneAttachment3D.new()
	att.bone_name = skel.get_bone_name(hi)
	skel.add_child(att)
	helmet = Node3D.new()
	att.add_child(helmet)
	helmet.transform = head_rest.affine_inverse()
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = tall * 0.62
	sm.height = tall * 1.24
	mi.mesh = sm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.8, 0.95, 1.0, 0.16)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.05
	m.metallic_specular = 1.0
	m.rim_enabled = true
	m.rim = 0.6
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = head_rest.origin + Vector3(0, tall * 0.42, tall * 0.05)
	helmet.add_child(mi)

func _process(delta: float) -> void:
	super(delta)
	if player == null:
		return
	if player_bubbles_pending and bubbles != null:
		player_bubbles_pending = false
		player.add_child(bubbles)
	var t := anim_t
	update_fish_schools(t)
	update_rock_waves(delta)
	update_jellies(t, delta)
	for sh in shafts:
		(sh[0] as Node3D).rotation.y += delta * 0.015
	if sea_under != null and sea_under.visible:
		sea_uv_t += delta
		(sea_under.material_override as StandardMaterial3D).uv1_offset = Vector3(sea_uv_t * 0.01, sea_uv_t * 0.007, 0)
	update_underwater_look()
	apply_ink_look()
	if cam != null and not gate_parts.is_empty():
		var near_gate := absf(cam.global_position.z - GATE_Z) < 2.6 and absf(cam.global_position.x) < 5.5
		for gp in gate_parts:
			(gp as Node3D).visible = not near_gate
	if bubbles != null:
		bubbles.emitting = swimming
	if swimming != swim_shown and jump_button != null:
		swim_shown = swimming
		jump_button.text = tr("위로") if swimming else tr("점프")
		if swimming and not shown_swim_tip:
			shown_swim_tip = true
			float_text(tr("위로 버튼을 누르고 있으면 떠올라요"), get_viewport().get_visible_rect().size * Vector2(0.5, 0.4), Color(0.8, 0.95, 1.0), 2.4)
	update_followers(delta)
	update_story(delta)

var shown_swim_tip := false
var sea_uv_t := 0.0

# 카메라가 물속에 들어가면 바닷속 빛으로 바꿔요 (분위기 그림을 따라 구역마다 달라요)
# [z, 안개 색, 안개 짙기, 주변 빛 색, 해 밝기]
const SEA_ZONES := [
	[-6.0, Color(0.32, 0.78, 0.82), 0.022, Color(0.75, 0.95, 0.95), 0.95],     # 얕은 산호 숲: 맑은 청록
	[-40.0, Color(0.2, 0.6, 0.66), 0.026, Color(0.65, 0.9, 0.85), 0.8],
	[-62.0, Color(0.1, 0.32, 0.5), 0.034, Color(0.45, 0.62, 0.85), 0.55],     # 해초 숲 끝: 짙은 바다빛
	[-80.0, Color(0.07, 0.1, 0.32), 0.04, Color(0.55, 0.45, 0.95), 0.35],     # 깊은 골짜기: 남보랏빛
	[-96.0, Color(0.08, 0.16, 0.38), 0.036, Color(0.55, 0.55, 0.95), 0.4],
	[-104.0, Color(0.28, 0.7, 0.8), 0.024, Color(0.8, 0.95, 1.0), 0.85],      # 용궁: 밝은 물빛
]

func update_underwater_look() -> void:
	if above_fog.is_empty() or cam == null:
		return
	var cp := cam.global_position
	var u := 0.0
	if cp.z < SHORE_Z + 3.0 and cp.y < -0.05:
		u = 1.0
	var key := u * 1000.0 + roundf(cp.z * 0.5)
	if absf(key - under_amt) < 0.01:
		return
	under_amt = key
	if sea_top != null:
		sea_top.visible = u < 0.5
	if u > 0.5:
		var a: Array = SEA_ZONES[0]
		var b: Array = SEA_ZONES[SEA_ZONES.size() - 1]
		var k := 0.0
		if cp.z >= float(SEA_ZONES[0][0]):
			b = a
		elif cp.z > float(b[0]):
			for n in SEA_ZONES.size() - 1:
				if cp.z <= float(SEA_ZONES[n][0]) and cp.z >= float(SEA_ZONES[n + 1][0]):
					a = SEA_ZONES[n]
					b = SEA_ZONES[n + 1]
					k = (cp.z - float(a[0])) / (float(b[0]) - float(a[0]))
					break
		else:
			a = b
		env_ref.fog_light_color = (a[1] as Color).lerp(b[1], k)
		env_ref.fog_density = lerpf(a[2], b[2], k)
		env_ref.fog_sky_affect = 1.0
		env_ref.ambient_light_color = (a[3] as Color).lerp(b[3], k)
		sun_light.light_energy = lerpf(a[4], b[4], k)
		sun_light.light_color = Color(1.0, 0.95, 0.8)
	else:
		env_ref.fog_density = above_fog[0]
		env_ref.fog_light_color = above_fog[1]
		env_ref.fog_sky_affect = 0.0
		env_ref.ambient_light_color = above_fog[2]
		sun_light.light_energy = above_fog[3]
		sun_light.light_color = TOD_KEYS[0][2]

# 자라와 토끼가 주인공을 따라와요 (물속에서는 위아래로도)
func update_followers(delta: float) -> void:
	var ids := ["jara", "rabbit"]
	for k in ids.size():
		var id: String = ids[k]
		var n := npc(id)
		var body := body_of(n)
		var speed := 0.0
		# 토끼를 데려가는 동안 자라는 바닷가 바위에서 기다려요
		var waits := id == "jara" and quest < S_DIVE
		if waits and n.position.distance_to(player.position) < 9.0:
			# 다가오면 반갑게 고개를 돌려요
			var tp := player.position - n.position
			n.rotation.y = lerp_angle(n.rotation.y, atan2(tp.x, tp.z), minf(1.0, delta * 4.0))
		if follow_on and n.visible and not event_lock and not mg_active and not waits:
			var side := Vector3(1.8 if k == 0 else -1.8, 0, 0).rotated(Vector3.UP, player.rotation.y)
			var goal := player.position + side - Vector3(sin(player.rotation.y), 0, cos(player.rotation.y)) * 1.2
			if quest == S_DIVE and id == "jara" and ring_next < rings.size():
				# 자라는 다음 고리 앞에서 기다려요
				var rp: Vector3 = (rings[ring_next][0] as Node3D).position
				goal = rp + Vector3(0, -0.8, -2.2)
			var to := goal - n.position
			var flat := Vector3(to.x, 0, to.z)
			var d := to.length()
			if d > 18.0:
				n.position = goal
			elif d > 0.6:
				speed = clampf(d * 2.2, 0.0, 6.0)
				n.position += to.normalized() * minf(speed * delta, d)
			if flat.length() > 0.3:
				n.rotation.y = lerp_angle(n.rotation.y, atan2(flat.x, flat.z), minf(1.0, delta * 6.0))
			var gh := height_at(n.position.x, n.position.z)
			if n.position.z > SHORE_Z or gh > -1.0:
				n.position.y = gh
			else:
				n.position.y = clampf(n.position.y, gh, -1.2)
		if body != null:
			var ph: float = follow_phase.get(id, 0.0) + delta * speed / 1.6
			follow_phase[id] = ph
			var amt: float = body.get_meta("gait", [0.0, 0.0, 0.0])[1]
			amt = lerpf(amt, clampf(speed / 2.0, 0.0, 1.0), minf(1.0, delta * 8.0))
			body.set_meta("gait", [fposmod(ph, 1.0), amt, clampf((speed - 3.5) / 3.0, 0.0, 1.0)])

# ---------- 매 순간 이야기 ----------

func update_story(delta: float) -> void:
	if is_busy() or event_lock:
		return
	update_mulji(delta)
	update_octos(delta)
	match quest:
		S_FIND:
			update_rabbit_chase(delta)
		S_DIVE:
			update_rings()
		S_DEEP:
			if player.position.z < GATE_Z + 6.0:
				event_lock = true
				say([
					[tr("자라"), tr("저기 붉은 기둥이 보이지요? 용궁 문이오!")],
					[tr("토끼"), tr("우와... 정말 진주로 지은 궁궐이네? 벼슬 준다는 말도 진짜겠지?")],
					[tr("자라"), tr("문지기 넙치에게 먼저 아뢰어야 하오. 넙치는 수수께끼를 좋아한다오.")],
				], func():
					event_lock = false
					set_quest(S_GATE))
		S_ESCAPE:
			update_chase(delta)
			update_ink(delta)

# 토끼 잡기: 다가가면 깡충깡충 지그재그로 도망쳐요. 오래 뛰면 지쳐서 느려지고 숨을 골라요.
# 바짝 붙거나, 점프해서 덮치면 잡혀요!
const RABBIT_BOX := Rect2(-42, 16, 76, 34)

func update_rabbit_chase(delta: float) -> void:
	if rabbit_caught:
		return
	var rabbit := npc("rabbit")
	var body := body_of(rabbit)
	var to_r := rabbit.position - player.position
	to_r.y = 0.0
	var d := to_r.length()
	var airborne := not player.is_on_floor()
	if not rabbit_called and d < 26.0:
		rabbit_called = true
		sfx("pop", 1.4)
		float_text(tr("여기야 여기! 메롱~"), cam.unproject_position(rabbit.position + Vector3(0, 2.4, 0)), Color(1, 1, 0.8), 1.2)
	if d < (2.0 if airborne else 1.3):
		rabbit_catches += 1
		if rabbit_catches < RABBIT_CATCHES:
			# 쏙 빠져나가 다음 덤불로 깡충!
			sfx("bad")
			shake(8)
			burst3d(rabbit.position + Vector3(0, 0.8, 0), Color(1, 1, 0.95), 16)
			float_text(tr("앗! 쏙 빠져나갔다! (%d/%d)") % [rabbit_catches, RABBIT_CATCHES], get_viewport().get_visible_rect().size * Vector2(0.5, 0.4), Color(1, 0.85, 0.5), 1.4)
			rabbit_hop = (rabbit_hop + 1) % rabbit_route.size()
			var nxt: Vector3 = rabbit_route[rabbit_hop]
			var to_spot := Vector3(nxt.x, 0, nxt.z) - Vector3(rabbit.position.x, 0, rabbit.position.z)
			# 너무 멀면 그 방향으로 12m만 뛰어요
			if to_spot.length() > 12.0:
				to_spot = to_spot.normalized() * 12.0
			var land := rabbit.position + to_spot
			rabbit.position = on_ground(land.x, land.z)
			pop3d(rabbit)
			rabbit_stam = 1.0
			rabbit_rest = 0.0
			rabbit_taunt = 0.0
			update_quest_text()
			return
		rabbit_caught = true
		sfx("win")
		hit_stop(0.1)
		shake(12)
		burst3d(rabbit.position + Vector3(0, 1.0, 0), Color(1, 1, 0.95), 24)
		float_text(tr("잡았다!") if not airborne else tr("덮쳤다! 잡았다!"), get_viewport().get_visible_rect().size * Vector2(0.5, 0.4), Color(1, 0.9, 0.4), 1.8)
		rabbit.rotation.y = atan2(-to_r.x, -to_r.z)
		if body != null:
			body.set_meta("gait", [0.0, 0.0, 0.0])
		get_tree().create_timer(0.6).timeout.connect(on_rabbit_caught)
		return
	var speed := 0.0
	rabbit_taunt -= delta
	if rabbit_rest > 0.0:
		rabbit_rest -= delta
		rabbit_stam = minf(1.0, rabbit_stam + delta * 0.25)
		if d < 2.8:
			rabbit_rest = 0.0
	elif d < 12.0:
		# 도망: 반대쪽으로, 지그재그로, 숲 가장자리와 나무를 피해서
		var away := to_r.normalized()
		var zig := sin(anim_t * 2.6 + rabbit_phase * 0.1) * (0.75 + 0.15 * rabbit_catches)
		var dir := away.rotated(Vector3.UP, zig)
		var p := Vector2(rabbit.position.x, rabbit.position.z)
		var box := RABBIT_BOX
		var steer := Vector2.ZERO
		if p.x < box.position.x + 4.0:
			steer.x += 1.0
		if p.x > box.end.x - 4.0:
			steer.x -= 1.0
		if p.y < box.position.y + 4.0:
			steer.y += 1.0
		if p.y > box.end.y - 4.0:
			steer.y -= 1.0
		for tp in tree_spots:
			var off: Vector2 = p - tp
			if off.length() < 1.8:
				steer += off.normalized() * (1.8 - off.length()) * 1.5
		dir = (dir + Vector3(steer.x, 0, steer.y) * 1.4).normalized()
		# 구석에 몰리면 옆으로 쏙 빠져요
		if steer.length() > 0.5 and d < 4.0:
			dir = (dir + away.cross(Vector3.UP) * (1.0 if sin(anim_t) > 0.0 else -1.0)).normalized()
		rabbit_dir = rabbit_dir.lerp(dir, minf(1.0, delta * 6.0)).normalized()
		# 잡힐 때마다 조금씩 더 빨라져요
		speed = lerpf(4.2, 7.0 + rabbit_catches * 0.3, rabbit_stam)
		rabbit_stam = maxf(0.0, rabbit_stam - delta * 0.07)
		if rabbit_stam < 0.25 and rng.randf() < delta * 0.5:
			rabbit_rest = 0.5
			float_text(tr("헉헉..."), cam.unproject_position(rabbit.position + Vector3(0, 2.2, 0)), Color(1, 1, 0.9), 0.9)
		elif rabbit_taunt <= 0.0 and d < 6.0:
			rabbit_taunt = rng.randf_range(2.5, 4.5)
			float_text([tr("메롱~"), tr("나 잡아 봐라!"), tr("느림보~"), tr("여기야 여기!")][rng.randi() % 4], cam.unproject_position(rabbit.position + Vector3(0, 2.2, 0)), Color(1, 1, 0.9), 1.0)
	else:
		rabbit_stam = minf(1.0, rabbit_stam + delta * 0.12)
	if speed > 0.0:
		var np := rabbit.position + rabbit_dir * speed * delta
		np.x = clampf(np.x, RABBIT_BOX.position.x, RABBIT_BOX.end.x)
		np.z = clampf(np.z, RABBIT_BOX.position.y, RABBIT_BOX.end.y)
		rabbit.position = np
		rabbit.rotation.y = lerp_angle(rabbit.rotation.y, atan2(rabbit_dir.x, rabbit_dir.z), minf(1.0, delta * 10.0))
		rabbit_phase += delta * speed * 1.7
	# 깡충깡충
	var hop := absf(sin(rabbit_phase)) * (0.5 if speed > 0.0 else 0.0)
	rabbit.position.y = height_at(rabbit.position.x, rabbit.position.z) + hop
	if body != null:
		body.set_meta("gait", [fposmod(rabbit_phase / PI, 1.0), clampf(speed / 3.0, 0.0, 1.0), 1.0 if speed > 4.5 else 0.0])

func on_rabbit_caught() -> void:
	set_rabbit_beacon(false)
	say([
		[tr("토끼"), tr("헉헉, 내가 졌다! 너 발 빠르구나. 그런데 무슨 일이야?")],
		["", tr("(바닷가에서 자라가 토끼를 찾고 있다고 전했다.)")],
		[tr("토끼"), tr("자라가 날? 왜?")],
	], func(): ask("", tr("자라가 \"용궁 구경시켜 주고 벼슬도 준다\"고 했다고 전할까?"), [tr("\"용궁 구경 가자! 벼슬도 준대\""), tr("\"...좀 이상하긴 한데, 조심해\"")], on_lure))

func update_rings() -> void:
	if ring_next >= rings.size():
		return
	var rg: Node3D = rings[ring_next][0]
	var body_c := player.position + Vector3(0, 0.7, 0)
	var m: StandardMaterial3D = rg.material_override
	m.emission_energy_multiplier = 1.6 + sin(anim_t * 6.0) * 0.8
	rg.scale = Vector3.ONE * (1.0 + sin(anim_t * 4.0) * 0.05)
	if body_c.distance_to(rg.position) < 1.9:
		rings[ring_next][1] = true
		sfx("good", 1.0 + ring_next * 0.08)
		burst3d(rg.position, Color(1, 0.9, 0.5), 16)
		var tw := rg.create_tween()
		tw.tween_property(rg, "scale", Vector3.ONE * 1.8, 0.3)
		tw.tween_callback(func(): rg.visible = false)
		ring_next += 1
		update_quest_text()
		if ring_next >= rings.size():
			earn(10)
			say([
				[tr("자라"), tr("잘 따라오셨소! 물살 고리 길은 여기까지라오.")],
				[tr("자라"), tr("저 앞에 붉은 기둥이 보이오? 바로 용궁 문이오. 조금만 더 북쪽으로 헤엄치면 되오.")],
				[tr("자라"), tr("골짜기의 빛나는 해파리는 건드리면 찌릿하니 조심하시오!")],
				[tr("자라"), tr("참, 해초 숲엔 길 잃은 새끼 문어 다섯이 모래빛으로 숨어 있다 하오. 가까이 가면 꼼지락거린다오.")],
			], func(): set_quest(S_DEEP))

# ---------- 말 걸기 ----------

func talk_to(id: String) -> void:
	match id:
		"jara":
			talk_jara()
		"rabbit":
			talk_rabbit()
		"haenyeo":
			talk_haenyeo()
		"flatfish":
			talk_flatfish()
		"yongwang":
			talk_yongwang()
		"octopus":
			talk_octopus()
		"crab":
			talk_crab()
		"seafisher":
			talk_seafisher()

func talk_jara() -> void:
	match quest:
		S_ARRIVE:
			say([
				[tr("자라"), tr("헉헉... 뭍은 어찌 이리 덥고 메마르단 말이오...")],
				[tr("자라"), tr("아, 실례했소. 나는 바닷속 용궁의 신하 별주부라 하오.")],
				[tr("자라"), tr("우리 용왕님께서 큰 병이 드셨는데, 뭍의 토끼라는 짐승이 있어야 낫는다 하오.")],
				[tr("자라"), tr("(자라가 둘둘 만 그림을 펼쳐 보였다. 귀가 길쭉한 하얀 짐승이다.)")],
				[tr("자라"), tr("그런데 내 다리가 짧아 뒷산까지 오르기가 힘들구려. 토끼를 좀 찾아 주겠소?")],
			], func():
				pick_rabbit_route()
				var rp: Vector3 = rabbit_route[0]
				npc("rabbit").position = on_ground(rp.x, rp.z)
				set_rabbit_beacon(true)
				set_quest(S_FIND))
		S_FIND:
			say([[tr("자라"), tr("토끼는 뒷산 숲 덤불 사이에 산다 하오. 귀가 쫑긋하니 금방 알아볼 게요.")]], Callable())
		S_LURE:
			say([
				[tr("자라"), tr("오오, 이분이 토끼 선생이시구려! 반갑소.")],
				[tr("토끼"), tr("용궁 구경에 벼슬까지 준다니, 어서 가요 어서!")],
				[tr("자라"), tr("물속에서도 숨을 쉴 수 있게, 이 물방울 구슬을 하나씩 드리겠소.")],
				["", tr("물방울 구슬을 받았다! 머리에 투명한 거품이 씌워졌다.")],
				[tr("자라"), tr("내 뒤를 따라 빛나는 물살 고리를 지나 오시오. 위로 버튼을 누르면 떠오르고, 떼면 가라앉소.")],
			], start_dive)
		S_FEAST:
			if not feast_done("dance"):
				say([[tr("자라"), tr("잔치에 춤이 빠질 수 있소? 내가 먼저 출 테니 똑같이 따라 추시오!")]], start_dance)
			else:
				say([[tr("자라"), tr("허허, 그대 춤 솜씨에 용왕님 얼굴이 다 밝아지셨소.")]], Callable())
		S_END:
			if king_healed():
				say([[tr("자라"), tr("산삼 덕에 용왕님 병이 씻은 듯 나으셨다오. 그대의 고마움은 잊지 않겠소.")]], Callable())
			elif has_ginseng:
				ask("", tr("자라에게 산삼을 건넬까?"), [tr("산삼을 건넨다"), tr("나중에")], func(i: int):
					if i == 0:
						give_ginseng_late())
			else:
				say([
					[tr("자라"), tr("토끼에게는 속았지만... 그대와 함께한 바닷길은 즐거웠소.")],
					[tr("자라"), tr("그런데 용왕님께서 아직도 앓아누워 계시오. 이를 어쩌면 좋단 말이오...")],
					[tr("자라"), tr("뒷산 깊은 숲, 큰 나무 아래에 빨간 열매가 달린 귀한 풀이 자란다는 소문은 들었소만... 내 짧은 다리로는 갈 수가 없구려.")],
				], func(): update_quest_text())
		_:
			say([[tr("자라"), tr("용궁은 북쪽 깊은 바닷속이오. 함께 갑시다.")]], Callable())

func start_dive() -> void:
	sea_wall.set_deferred("disabled", true)
	add_helmet()
	ring_next = 0
	for rg in rings:
		(rg[0] as Node3D).visible = true
		rg[1] = false
	follow_on = true
	set_quest(S_DIVE)

func talk_rabbit() -> void:
	if quest == S_FIND:
		if not rabbit_caught:
			say([[tr("토끼"), tr("메롱~ 말로는 안 잡히지! 나 잡아 봐라!")]], Callable())
			return
		on_rabbit_caught()
	elif quest == S_END:
		say([[tr("토끼"), tr("히히, 간을 빼놓고 다니는 짐승이 어디 있니? 그래도 너는 고마웠어!")]], Callable())
	else:
		say([[tr("토끼"), tr("용궁엔 진주가 산더미래! 벼슬은 무슨 벼슬일까?")]], Callable())

func on_lure(i: int) -> void:
	lured = i == 0
	var l := []
	if lured:
		l.append([tr("토끼"), tr("용궁? 벼슬? 우와, 이런 산골에서 풀만 뜯을 수야 없지! 가자 가자!")])
	else:
		l.append([tr("토끼"), tr("조심하라고? 에이, 걱정 마. 이 몸은 꾀주머니 토끼라고!")])
		l.append([tr("토끼"), tr("그래도 용궁 구경은 놓칠 수 없지. 가 보자!")])
	say(l, func():
		follow_on = true
		set_quest(S_LURE))

func talk_haenyeo() -> void:
	if not clams_done:
		say([
			[tr("해녀"), tr("어머, 처음 보는 꼬마네! 바다 구경 왔니?")],
			[tr("해녀"), tr("저기 갯벌 숨구멍에서 조개가 뽀글뽀글 올라온단다. 좀 캐다 줄래?")],
			[tr("해녀"), tr("다 캐면 바닷속에서 쓰는 좋은 걸 하나 알려 주마.")],
		], Callable())
	elif dive_on:
		say([[tr("해녀"), tr("반짝이는 게 전복이랑 소라야. 숨이 차면 위로 올라와서 쉬렴!")]], Callable())
	elif not mulji_done and quest < S_DIVE:
		say([
			[tr("해녀"), tr("조개 캐는 솜씨가 좋던걸? 이번엔 물질 한번 해 볼래?")],
			[tr("해녀"), tr("숨을 꾹 참고 들어가서 바닥에 반짝이는 전복이랑 소라 여섯 개만 주워 오렴.")],
			[tr("해녀"), tr("숨이 모자라면 위로 버튼을 눌러 물 위로 올라와서 숨을 쉬어야 해!")],
		], start_mulji)
	elif quest < S_DIVE:
		say([[tr("해녀"), tr("바닷속에선 숨이 제일이야. 자라가 물방울 구슬을 준다면 꼭 받으렴.")]], Callable())
	elif quest == S_END:
		say([[tr("해녀"), tr("용궁에 다녀왔다고? 호호, 다음엔 나도 데려가 줘!")]], Callable())
	else:
		say([[tr("해녀"), tr("가라앉은 배 안에 진주가 숨어 있다더라. 물고기 떼도 가까이서 보면 참 예뻐.")]], Callable())

func talk_flatfish() -> void:
	if quest == S_GATE:
		say([
			[tr("넙치 문지기"), tr("멈추시오! 용궁에 들어가려면 내 수수께끼를 풀어야 하오.")],
		], func(): ask(tr("넙치 문지기"), tr("\"눈은 둘인데 한쪽에만 붙었고, 바닥에 납작 엎드려 사는 건?\""), [tr("넙치!"), tr("가자미!"), tr("문어!")], on_riddle))
	elif quest > S_GATE and not tale_read["ch3"][3]:
		var l := [[tr("넙치 문지기"), tr("(두 눈을 데굴데굴) 아, 우리 형제를 다 찾아낸 그대로구려. 상으로 이야기 하나 들려주리다.")]]
		l.append_array(tale_lines("ch3", 3))
		sfx("good")
		say(l, func(): update_quest_text(); save_progress())
	elif quest > S_GATE:
		say([[tr("넙치 문지기"), tr("(두 눈을 데굴데굴) 수상한 자는 못 들어간다... 아, 그대는 이미 들어왔지.")]], Callable())
	else:
		say([[tr("넙치 문지기"), tr("여기는 용궁 문이오.")]], Callable())

func on_riddle(i: int) -> void:
	if i == 2:
		say([[tr("넙치 문지기"), tr("문어 장군이 들으면 섭섭하겠소! 다시 생각해 보시오.")]], talk_flatfish)
		return
	var l := []
	if i == 0:
		l.append([tr("넙치 문지기"), tr("허허, 바로 나요! 맞혔소!")])
	else:
		l.append([tr("넙치 문지기"), tr("가자미 녀석도 닮긴 했지... 반쯤 맞힌 걸로 치겠소!")])
	l.append([tr("넙치 문지기"), tr("하지만 수수께끼 하나로는 어림없소! 두 번째 시험이오.")])
	l.append([tr("넙치 문지기"), tr("내 형제들이 모래 속에 숨어 눈만 빼꼼 내민다오. 눈이 보이면 얼른 톡 건드려 찾아내시오!")])
	say(l, start_sand)

func start_sand() -> void:
	start_game("tap", {"world": true, "scene": "sand", "art": "world", "title": tr("모래 속 넙치 형제들이 눈만 빼꼼!\n다시 숨기 전에 톡 건드려요"), "goal": 12, "interval": 0.62, "life": 1.25, "target": tr("넙치"), "center": tr("모래"), "color": Color(0.85, 0.75, 0.55)}, sand_done)

func sand_done(ok: bool, _good: bool) -> void:
	if not ok:
		say([[tr("넙치 문지기"), tr("허허, 내 형제들이 모래 속에 쏙 숨어 버렸구려. 다시 해 보시오!")]], start_sand)
		return
	var l := [[tr("넙치 문지기"), tr("열둘을 다 찾아내다니! 눈썰미가 넙치만 하구려. 들어가시오.")]]
	l.append([tr("넙치 문지기"), tr("용왕님께서 전각 앞에서 기다리신다오.")])
	if not tale_read["ch3"][3]:
		l.append([tr("넙치 문지기"), tr("그 눈썰미에 상으로 우리 형제 이야기를 하나 들려주리다.")])
		l.append_array(tale_lines("ch3", 3))
	say(l, func():
		follow_on = false
		var jara := npc("jara")
		var rabbit := npc("rabbit")
		var t1 := jara.create_tween()
		t1.tween_property(jara, "position", Vector3(-2.5, PALACE_Y + 0.25, -111), 2.0)
		var t2 := rabbit.create_tween()
		t2.tween_property(rabbit, "position", Vector3(2.0, PALACE_Y + 0.25, -111.5), 2.0)
		set_quest(S_COURT))

func talk_yongwang() -> void:
	match quest:
		S_COURT:
			say([
				[tr("용왕"), tr("콜록콜록... 그대가 토끼를 데려왔구려...")],
				[tr("토끼"), tr("용왕님! 벼슬은 언제 주시나요? 진주 관이면 좋겠는데요!")],
				[tr("용왕"), tr("벼슬이라... 미안하오, 토끼여. 내 병에는 그대의 간이 약이라 하오.")],
				[tr("토끼"), tr("가, 간이요?! (귀가 바짝 섰다)")],
				[tr("문어 장군"), tr("그렇다! 여봐라, 토끼를 붙잡아라!")],
				[tr("토끼"), tr("(토끼가 꼴깍 침을 삼키더니, 갑자기 껄껄 웃었다)")],
				[tr("토끼"), tr("아이고, 용왕님! 하필 오늘 간을 꺼내서 바닷가 바위에 말려 두고 왔지 뭡니까!")],
				[tr("토끼"), tr("토끼 간은 영험해서, 사흘에 한 번 꺼내 햇볕에 말려야 하거든요.")],
			], func(): ask(tr("용왕"), tr("(용왕이 그대를 바라본다) 정말 그러하냐?"), [tr("\"네! 바위에 간이 널려 있는 걸 봤어요\""), tr("(아무 말 없이 고개를 숙인다)")], on_back))
		S_FEAST:
			if feast_done("drum") and feast_done("pearl") and feast_done("dance"):
				say([
					[tr("용왕"), tr("잔치가 흥겨웠소. 이제 자라와 함께 가서 간을 가져오시오.")],
					[tr("문어 장군"), tr("(소곤) 수상하다... 간을 꺼내 말리는 짐승이 어디 있어?")],
					[tr("문어 장군"), tr("용왕님, 소장이 뒤따라가 지켜보겠습니다!")],
					[tr("자라"), tr("(소곤) 서두르시오! 문어 장군이 쫓아오기 전에 물 위로 올라갑시다!")],
				], start_escape)
			else:
				say([[tr("용왕"), tr("떠나기 전에 잔치를 열어 주겠소. 꽃게와 문어 장군을 돕고, 자라와 춤도 춰 주시오.")]], Callable())
		S_END:
			if king_healed():
				if not king_thanked:
					king_thanked = true
					say([
						[tr("용왕"), tr("오오, 뭍의 아이여! 보시오, 이렇게 자리에서 일어났소.")],
						[tr("용왕"), tr("토끼의 간이 아니라 그대의 마음이 나를 살렸구려. 내가 욕심이 과했소.")],
						[tr("용왕"), tr("용궁의 보물 상자에서 조금 덜어 주겠소. 사양 말고 받으시오.")],
						["", tr("엽전 30냥을 받았다!")],
					], func():
						earn(30)
						save_progress())
				else:
					say([[tr("용왕"), tr("허허, 또 왔구려! 용궁은 언제든 그대를 반긴다오.")]], Callable())
			else:
				say([
					[tr("용왕"), tr("(이불 속에서) 콜록콜록... 뭍의 아이로구나...")],
					[tr("용왕"), tr("토끼를 원망하지는 않소. 남의 간으로 살려 한 내 욕심이 컸지...")],
					[tr("꽃게 신하"), tr("(소곤) 뭍에는 사람을 살리는 귀한 풀이 있다던데... 자라에게 물어보시오.")],
				], Callable())
		_:
			say([[tr("용왕"), tr("콜록... 어서 오시오.")]], Callable())

var feast_flags := {}

func feast_done(k: String) -> bool:
	return feast_flags.get(k, false)

func on_back(i: int) -> void:
	backed = i == 0
	var l := []
	if backed:
		l.append([tr("토끼"), tr("(눈을 찡긋) 봐요, 이 아이도 봤다잖아요!")])
	else:
		l.append([tr("토끼"), tr("(땀을 삐질) 이 아이는 부끄럼이 많아서요. 아무튼 정말이라니까요!")])
	l.append([tr("용왕"), tr("허허, 그렇다면 자라와 함께 뭍에 다녀오시오.")])
	l.append([tr("용왕"), tr("그 전에 먼 길 떠나는 손님을 위해 잔치를 열어라!")])
	l.append([tr("꽃게 신하"), tr("네, 넷! 북, 북을 칠 사람이... 아이고 바쁘다 바빠!")])
	say(l, func(): set_quest(S_FEAST))

func talk_crab() -> void:
	if quest == S_FEAST and not feast_done("drum"):
		say([[tr("꽃게 신하"), tr("집게로 북채를 잡으니 자꾸 미끄러져요! 대신 북 좀 쳐 주시겠어요?")]], start_drum)
	elif quest == S_FEAST:
		say([[tr("꽃게 신하"), tr("둥둥! 잔치 북소리 덕분에 용궁이 들썩들썩해요!")]], Callable())
	else:
		say([[tr("꽃게 신하"), tr("아이고 바쁘다 바빠! 옆으로 걸으니 더 바쁘네!")]], Callable())

func talk_octopus() -> void:
	if quest == S_FEAST and not feast_done("pearl"):
		say([
			[tr("문어 장군"), tr("흥, 뭍의 꼬마가 잔치를 돕겠다고? 솜씨 좀 보자.")],
			[tr("문어 장군"), tr("저 큰 조개가 진주를 뱉어 낸다. 진주는 받고, 뾰족한 성게는 피해라!")],
		], start_pearl)
	elif quest == S_FEAST:
		say([[tr("문어 장군"), tr("제법이군... 그래도 토끼 녀석은 영 수상해.")]], Callable())
	elif quest == S_END:
		say([[tr("문어 장군"), tr("(먹물을 뿜으며) 다음엔 안 놓친다!")]], Callable())
	else:
		say([[tr("문어 장군"), tr("용궁을 지키는 문어 장군이다! 수상한 자는 이 삼지창 맛을 보리라!")]], Callable())

# ---------- 물건 누르기 ----------

func is_active(t: Dictionary) -> bool:
	match t["kind"]:
		"clam":
			return not clams_done
		"ginseng":
			return not has_ginseng and not king_healed()
		"pearl":
			return not pearls[int(t["id"])]
		"drum":
			return quest == S_FEAST and not feast_done("drum")
		"bigclam":
			return quest == S_FEAST and not feast_done("pearl")
		"chest":
			return not chest_done
	return super(t)

func action_text(t: Dictionary) -> String:
	match t["kind"]:
		"clam":
			return tr("조개 캐기")
		"ginseng":
			return tr("약초 캐기")
		"pearl":
			return tr("진주 줍기")
		"drum":
			return tr("북 치기")
		"bigclam":
			return tr("진주 받기")
		"chest":
			return tr("보물 상자 열기")
	return super(t)

func on_action() -> void:
	if current_thing.is_empty() or is_busy():
		return
	var t := current_thing
	var node: Node3D = t["node"]
	match t["kind"]:
		"clam":
			sfx("tap")
			start_clam()
		"ginseng":
			sfx("good")
			has_ginseng = true
			node.visible = false
			burst3d(node.position + Vector3(0, 0.5, 0), Color(0.9, 0.3, 0.3), 16)
			say([["", tr("빨간 열매가 달린 산삼을 캤다! 귀한 약초다. 언젠가 쓸 데가 있겠지.")]], func():
				update_quest_text()
				save_progress())
		"pearl":
			sfx("good")
			pearls[int(t["id"])] = true
			node.visible = false
			burst3d(node.position + Vector3(0, 0.4, 0), Color(1, 0.98, 0.9), 14)
			earn(5)
			var n := 0
			for b in pearls:
				n += 1 if b else 0
			var l := [["", tr("조개 속에서 동그란 진주를 찾았다! (%d/3)") % n]]
			if n >= 3:
				earn(15)
				l.append(["", tr("진주 세 알을 모두 모았다! 반짝반짝 예쁘다.")])
			say(l, func(): update_quest_text(); save_progress())
		"drum":
			sfx("tap")
			start_drum()
		"bigclam":
			sfx("tap")
			start_pearl()
		"chest":
			sfx("tap")
			start_shell()
		"gate":
			sfx("tap")
			on_gate()
		_:
			super()

# ---------- 미니게임 ----------

func start_clam() -> void:
	start_game("dig", {"world": true, "scene": "clam", "art": "world", "title": tr("거품이 뽀글뽀글 오르는 숨구멍을 톡!\n바지락은 톡톡, 맛조개는 위로 쓱, 꽃게는 피해요"), "goal": 8, "lives": 3, "unit": tr("조개")}, clam_done)

func clam_done(ok: bool, _good: bool) -> void:
	if not ok:
		say([[tr("해녀"), tr("호호, 조개가 쏙 숨어 버렸네. 다시 해 보렴!")]], Callable())
		return
	clams_done = true
	earn(15)
	say([
		[tr("해녀"), tr("와, 바구니 가득이네! 고맙다.")],
		[tr("해녀"), tr("바닷속 비밀 하나 알려 줄게. 가라앉은 배 안 조개에 진주가 숨어 있단다.")],
		[tr("해녀"), tr("그리고 물고기 떼는 가까이 다가가야 이름을 알 수 있어.")],
	], func(): save_progress())

func start_drum() -> void:
	start_game("rhythm", {"world": true, "scene": "drum", "art": "world", "title": tr("둥둥! 용궁 잔치 북을 박자에 맞춰 톡!\n꽃게 집게(빨간 X)가 올 땐 멈춰요"), "goal": 16, "bpm": 112, "bad_ratio": 0.18, "note": tr("둥"), "bad_text": tr("앗, 꽃게 집게!"), "unit": tr("북")}, drum_done)

func drum_done(ok: bool, _good: bool) -> void:
	if not ok:
		say([[tr("꽃게 신하"), tr("박자가 엉켰어요! 다시 한 번만요!")]], Callable())
		return
	feast_flags["drum"] = true
	earn(10)
	say([[tr("꽃게 신하"), tr("둥둥 덩실! 물고기들이 춤을 춰요! 고마워요!")]], func(): update_quest_text())

func start_pearl() -> void:
	start_game("catch", {"world": true, "scene": "pearl", "art": "world", "title": tr("큰 조개가 뱉는 진주는 받고\n뾰족한 성게는 피하세요"), "goal": 12, "interval": 0.62, "speed": 0.4, "bad_ratio": 0.32, "good": tr("진주"), "bad": tr("성게"), "basket": tr("소쿠리")}, pearl_done)

func pearl_done(ok: bool, _good: bool) -> void:
	if not ok:
		say([[tr("문어 장군"), tr("성게에 찔렸느냐? 흥, 다시 해 봐라.")]], Callable())
		return
	feast_flags["pearl"] = true
	earn(10)
	say([[tr("문어 장군"), tr("...제법이구나. 진주 하나 흘리지 않다니.")]], func(): update_quest_text())

func is_tap_scene(scene: String) -> bool:
	return scene == "drum" or scene == "sand" or super(scene)

func is_catch_scene(scene: String) -> bool:
	return scene == "pearl" or super(scene)

func scene_setup(scene: String) -> void:
	w["scene"] = scene
	w["seen"] = {}
	w["count0"] = mg_count
	w["lives0"] = mg_lives
	match scene:
		"sand":
			var fc := Vector3(FLATFISH_POS.x, PALACE_Y + 0.25, FLATFISH_POS.z + 2.0)
			var stand_s := fc + Vector3(0, 0, 3.2)
			world_game_begin(stand_s, fc, fc + Vector3(0.0, 3.9, 5.5), fc + Vector3(0, 0, 0.2))
			w["sand_c"] = fc
			# 모래 둔덕 일곱 개 (넙치가 숨는 자리): 휴대폰 세로 화면에도 다 들어오게 두 줄로 좁게 (앞 넷, 뒤 셋)
			var mounds := []
			for k in 7:
				var front := k < 4
				var mx := (-1.5 + k * 1.0) if front else (-1.0 + (k - 4) * 1.0)
				var mp := fc + Vector3(mx, 0.0, 0.9 if front else -0.5)
				mounds.append(mp)
				var hump := blob_node([[Vector3.ZERO, Vector3(0.9, 0.12, 0.7), Color(0.86, 0.78, 0.6)], [Vector3(0.1, 0.05, 0.05), Vector3(0.5, 0.1, 0.4), Color(0.9, 0.83, 0.66)]])
				hump.global_position = mp
			w["mounds"] = mounds
		"clam":
			var c := on_ground(CLAM_POS.x, CLAM_POS.z)
			var stand := c + Vector3(-0.9, 0, 1.6)
			world_game_begin(stand, c, c + Vector3(0.0, 5.6, 3.4), c + Vector3(0.0, 0.0, -0.9), clam_spot)
			hold_tool("shovel")
			var hs := []
			for hp2 in [Vector2(-1.3, -1.6), Vector2(0.2, -1.8), Vector2(1.5, -1.3), Vector2(-0.6, -0.8), Vector2(0.9, -0.4), Vector2(-1.6, 0.1), Vector2(0.1, 0.4), Vector2(1.5, 0.8)]:
				var hp3 := Vector3(c.x + hp2.x, maxf(height_at(c.x + hp2.x, c.z + hp2.y), c.y + 0.035), c.z + hp2.y)
				hs.append(hp3)
				var hole := blob_node([[Vector3.ZERO, Vector3(0.34, 0.04, 0.3), Color(0.3, 0.24, 0.18)], [Vector3(0, 0.015, 0), Vector3(0.18, 0.03, 0.16), Color(0.12, 0.09, 0.07)]])
				hole.global_position = hp3 + Vector3(0, 0.01, 0)
			w["dig_holes"] = hs
		"drum":
			var d := Vector3(DRUM_POS.x, PALACE_Y + 0.25, DRUM_POS.z)
			var stand := d + Vector3(-1.1, 0, 0.7)
			world_game_begin(stand, d, d + Vector3(2.6, 2.4, 5.2), d + Vector3(-0.6, 1.1, 0))
			hold_tool("stick")
		"pearl":
			var b := Vector3(BIGCLAM_POS.x, PALACE_Y + 0.25, BIGCLAM_POS.z)
			var stand := b + Vector3(0, 0, 2.6)
			world_game_begin(stand, b, b + Vector3(0.0, 2.3, 7.4), b + Vector3(0, 2.9, 1.4))
			var tray := blob_node([[Vector3.ZERO, Vector3(0.75, 0.12, 0.75), Color(0.8, 0.66, 0.4)], [Vector3(0, 0.05, 0), Vector3(0.62, 0.05, 0.62), Color(0.88, 0.76, 0.5)]], thatch_blob_mat)
			w["bowl"] = tray
			w["items"] = {}
			w["center"] = stand
			w["ground_y"] = b.y
			w["depth"] = cam_depth_of(stand + Vector3(0, 2.4, 0), b + Vector3(0.0, 2.3, 7.4))
		"chest":
			var cc := chest_c
			world_game_begin(cc + Vector3(1.5, 0, 0.6), cc, cc + Vector3(-0.6, 2.3, 3.6), cc + Vector3(0, 0.3, 0.8))
			var sp5 := []
			for k in 5:
				var px := -1.0 + k * 0.5
				sp5.append(Vector3(cc.x + px, height_at(cc.x + px, cc.z + 1.3 - absf(px) * 0.3) + 0.04, cc.z + 1.3 - absf(px) * 0.3))
			w["simon_pts"] = sp5
		"dance":
			var jp := Vector3(-2.5, PALACE_Y + 0.25, -111)
			var stand := jp + Vector3(2.0, 0, 0)
			world_game_begin(stand, jp + Vector3(1.0, 0, 3.0), jp + Vector3(1.0, 2.4, 6.4), jp + Vector3(1.0, 1.0, 0))
			npc("jara").rotation.y = 0.0
			w["jara_y"] = npc("jara").position.y
			w["dance_a"] = npc("jara")
			w["dance_b"] = player
			w["me_y"] = player.position.y

func scene_spawn_target() -> Vector3:
	match w["scene"]:
		"sand":
			var mounds: Array = w["mounds"]
			return (mounds[rng.randi() % mounds.size()] as Vector3) + Vector3(rng.randf_range(-0.15, 0.15), 0.02, rng.randf_range(-0.1, 0.1))
		"clam":
			var c := on_ground(CLAM_POS.x, CLAM_POS.z)
			return c + Vector3(rng.randf_range(-2.2, 2.2), 0.08, rng.randf_range(-1.4, 1.4))
		"drum":
			var d := Vector3(DRUM_POS.x, PALACE_Y + 0.25, DRUM_POS.z)
			var a := rng.randf() * TAU
			return d + Vector3(cos(a) * rng.randf_range(0.0, 0.42), 1.3 + sin(a) * rng.randf_range(0.0, 0.42), 0.48)
	return super()

func scene_make_target(at: Vector3) -> Node3D:
	match w["scene"]:
		"sand":
			var n := Node3D.new()
			n.position = at
			world_node(n)
			# 모래빛 넙치 몸 (납작하게, 점무늬) + 툭 튀어나온 두 눈
			var fish := Node3D.new()
			n.add_child(fish)
			add_blobs(fish, [[Vector3(0, 0.02, 0), Vector3(0.7, 0.08, 0.45), Color(0.72, 0.6, 0.42)],
				[Vector3(0.12, 0.05, 0.06), Vector3(0.08, 0.02, 0.08), Color(0.5, 0.4, 0.3)], [Vector3(-0.15, 0.05, -0.08), Vector3(0.07, 0.02, 0.07), Color(0.5, 0.4, 0.3)],
				[Vector3(-0.38, 0.03, 0), Vector3(0.2, 0.05, 0.28), Color(0.66, 0.55, 0.4)]])
			for ex in [0.12, 0.22]:
				var eye := Node3D.new()
				eye.position = Vector3(ex, 0.08, 0.05)
				fish.add_child(eye)
				add_ball(eye, Color(0.98, 0.97, 0.92), 0.055, Vector3.ZERO)
				add_ball(eye, Color(0.08, 0.06, 0.05), 0.03, Vector3(0.0, 0.025, 0.035))
			fish.rotation.y = rng.randf() * TAU
			n.set_meta("fish", fish)
			n.set_meta("from", at)
			add_target_marker(n)
			pop3d(n, true)
			burst3d(at + Vector3(0, 0.1, 0), Color(0.9, 0.82, 0.62), 8)
			return n
		"clam", "drum":
			var n := Node3D.new()
			n.position = at
			world_node(n)
			if w["scene"] == "clam":
				add_blobs(n, [[Vector3.ZERO, Vector3(0.24, 0.06, 0.24), Color(0.3, 0.25, 0.2)], [Vector3(0, 0.08, 0), Vector3(0.1, 0.1, 0.1), Color(0.9, 0.95, 1.0)]])
			else:
				add_blobs(n, [[Vector3.ZERO, Vector3(0.22, 0.22, 0.04), Color(1.0, 0.85, 0.3)]])
			n.set_meta("from", at)
			add_target_marker(n)
			pop3d(n, true)
			return n
	return super(at)

func scene_target_tip(n: Node3D, age: float, life: float) -> Vector3:
	match w["scene"]:
		"sand":
			# 모래에서 쏙 올라왔다가, 시간이 다 되면 다시 가라앉아요
			var t := clampf(age / life, 0.0, 1.0)
			var up := minf(1.0, t * 5.0) * (1.0 - smoothstep(0.8, 1.0, t))
			var from: Vector3 = n.get_meta("from")
			n.position = from + Vector3(0, -0.12 + up * 0.12, 0)
			var fish: Node3D = n.get_meta("fish")
			fish.rotation.z = sin(anim_t * 14.0 + from.x) * 0.04
			return n.position + Vector3(0, 0.15, 0)
		"clam":
			n.scale = Vector3.ONE * (1.0 + absf(sin(anim_t * 10.0)) * 0.3)
			return n.position + Vector3(0, 0.1, 0)
		"drum":
			return n.position
	return super(n, age, life)

func scene_target_hit(n: Node3D) -> void:
	var at := n.global_position
	match w["scene"]:
		"clam":
			hide_target_marker(n)
			w["swing"] = 1.0
			sfx("pop", 1.1)
			burst3d(at, Color(0.45, 0.38, 0.3), 10)
			var clam := blob_node([[Vector3.ZERO, Vector3(0.3, 0.14, 0.24), Color(0.85, 0.78, 0.66)]])
			clam.global_position = at
			var tw := clam.create_tween()
			tw.tween_property(clam, "global_position", at + Vector3(0, 0.8, 0), 0.25).set_ease(Tween.EASE_OUT)
			tw.tween_property(clam, "scale", Vector3(0.01, 0.01, 0.01), 0.2)
			float_text(tr("쏙!"), cam.unproject_position(at), Color(1, 0.95, 0.7), 1.1)
			n.queue_free()
			return
		"drum":
			hide_target_marker(n)
			w["swing"] = 1.0
			cam_kick = 0.12
			sfx("drum", 0.9 + rng.randf() * 0.2)
			burst3d(at, Color(1, 0.85, 0.4), 8)
			float_text(tr("둥!"), cam.unproject_position(at), Color(1, 0.95, 0.7), 1.0)
			n.queue_free()
			return
	super(n)

func scene_target_miss(n: Node3D) -> void:
	match w["scene"]:
		"clam", "drum":
			hide_target_marker(n)
			float_text(tr("조개가 숨었어요!") if w["scene"] == "clam" else tr("박자를 놓쳤어요!"), cam.unproject_position(n.global_position), Color(1, 0.55, 0.45), 1.0)
			var tw := n.create_tween()
			tw.tween_property(n, "scale", Vector3(0.01, 0.01, 0.01), 0.25)
			tw.tween_callback(n.queue_free)
			return
	super(n)

# 새 미니게임의 3D 연출
var clam_node: Node3D
var clam_spot: Node3D

func cg_event(kind: String, info: Dictionary = {}) -> void:
	match w.get("scene", ""):
		"chest":
			if kind == "pad":
				var k := int(info.get("k", 0))
				burst3d(chest_c + Vector3(-0.44 + k * 0.22, 0.35, 0.45), SIMON_COLS[k], 8)
			elif kind == "round":
				cam_kick = 0.12
				if chest_lid != null:
					var tw := chest_lid.create_tween()
					tw.tween_property(chest_lid, "rotation:x", -0.25, 0.1)
					tw.tween_property(chest_lid, "rotation:x", 0.0, 0.15)
			elif kind == "wrong":
				shake(8)
		"dance":
			if kind == "show":
				dance_hop(npc("jara"), String(info.get("dir", "")), float(w.get("jara_y", PALACE_Y + 0.25)))
			elif kind == "step":
				dance_hop(player, String(info.get("dir", "")), float(w.get("me_y", PALACE_Y + 0.25)))
				burst3d(player.position + Vector3(0, 0.2, 0), Color(0.8, 0.95, 1.0), 6)
			elif kind == "round":
				cam_kick = 0.12
				burst3d(player.position + Vector3(0, 1.2, 0), Color(1, 0.85, 0.5), 18)
		"clam":
			if kind == "round":
				w["swing"] = 1.0
			elif kind == "escape":
				burst3d((info.get("at", player.position) as Vector3) + Vector3(0, 0.1, 0), Color(0.9, 0.95, 1.0), 8)
		"drum":
			var d := Vector3(DRUM_POS.x, PALACE_Y + 0.25, DRUM_POS.z)
			if kind in ["perfect", "good"]:
				w["swing"] = 1.0
				cam_kick = 0.16 if kind == "perfect" else 0.08
				sfx("drum", 0.85 if kind == "perfect" else 1.0)
				burst3d(d + Vector3(0, 1.3, 0.5), Color(1, 0.85, 0.4), 16 if kind == "perfect" else 8)
				var crab := npc("crab")
				crab.create_tween().tween_property(crab, "position:y", crab.position.y + 0.3, 0.1).set_ease(Tween.EASE_OUT)
				get_tree().create_timer(0.12).timeout.connect(func(): crab.position.y = PALACE_Y + 0.25)
			elif kind == "bad":
				w["swing"] = 1.0
				flash(Color(1, 0.6, 0.5))
				float_text(tr("집게에 콕!"), cam.unproject_position(d + Vector3(0.5, 1.8, 0.5)), Color(1, 0.6, 0.5), 1.3)

func catch_item_node(bad: bool) -> Node3D:
	if w.get("scene", "") != "pearl":
		return super(bad)
	if bad:
		var items := [[Vector3.ZERO, Vector3(0.28, 0.28, 0.28), Color(0.3, 0.15, 0.35)]]
		for k in 8:
			var a := k * TAU / 8.0
			items.append([Vector3(cos(a) * 0.18, sin(a) * 0.18, 0), Vector3(0.05, 0.05, 0.3), Color(0.25, 0.12, 0.3), Vector3(0, 0, rad_to_deg(a))])
		return blob_node(items)
	return blob_node([[Vector3.ZERO, Vector3(0.24, 0.24, 0.24), Color(1.0, 0.98, 0.94)]], blob_gloss())

func scene_pose() -> bool:
	if not w.has("scene"):
		return false
	var sw: float = w.get("swing", 0.0)
	match w["scene"]:
		"clam", "drum":
			var arm3 := Vector3(lerpf(-2.4, -0.9, sw), 0.25, lerpf(-0.6, -0.1, sw))
			pose_custom(Vector3(-0.3, 0.45, -0.3), arm3, lerpf(-0.05, 0.3 if w["scene"] == "clam" else 0.15, sw), 0.25 if w["scene"] == "clam" else 0.12)
			if tool_node != null:
				place_tool((bone_world("handR") - bone_world("armR")).normalized())
			return true
		"pearl":
			pose_custom(Vector3(-2.7, 0.15, -0.5), Vector3(-2.7, 0.15, -0.5), -0.05, 0.1)
			return true
	return super()

# ---------- 해녀 물질 (숨 참고 전복·소라 줍기) ----------
const MULJI_PTS := [Vector3(19.5, 0, -10), Vector3(24, 0, -12.5), Vector3(28, 0, -15), Vector3(21, 0, -17.5), Vector3(25.5, 0, -20), Vector3(29, 0, -22.5)]
var dive_on := false
var mulji_done := false
var breath := 1.0
var mulji_items: Array = []    # [노드, 주웠는지]
var mulji_got := 0
var mulji_warn := 0.0
var breath_box: Control
var breath_fill: ColorRect
var breath_label: Label

func make_mulji_items() -> void:
	var shine := StandardMaterial3D.new()
	shine.albedo_color = Color(0.85, 0.95, 1.0)
	shine.emission_enabled = true
	shine.emission = Color(0.6, 0.9, 1.0)
	shine.emission_energy_multiplier = 1.4
	for i in MULJI_PTS.size():
		var p: Vector3 = MULJI_PTS[i]
		var n := Node3D.new()
		n.position = on_ground(p.x, p.z, 0.05)
		add_child(n)
		if i % 2 == 0:
			# 전복: 납작한 껍데기, 안쪽은 무지갯빛
			add_blobs(n, [[Vector3(0, 0.08, 0), Vector3(0.5, 0.14, 0.36), Color(0.45, 0.36, 0.3)], [Vector3(0, 0.12, 0.02), Vector3(0.36, 0.06, 0.24), Color(0.7, 0.85, 0.9)]], blob_gloss())
		else:
			# 소라: 뾰족한 고깔
			var shell := add_mcyl(n, make_color(Color(0.92, 0.75, 0.6)), 0.02, 0.2, 0.42, Vector3(0, 0.2, 0))
			shell.rotation.z = 1.2
			add_blobs(n, [[Vector3(0.12, 0.12, 0), Vector3(0.22, 0.2, 0.2), Color(0.98, 0.85, 0.78)]], blob_gloss())
		var sp := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.05
		sm.height = 0.1
		sp.mesh = sm
		sp.material_override = shine
		sp.position = Vector3(0, 0.45, 0)
		n.add_child(sp)
		n.visible = false
		mulji_items.append([n, false])

func make_breath_hud() -> void:
	breath_box = Control.new()
	breath_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(breath_box)
	place(breath_box, 0.25, 0.3, 0.75, 0.33)
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.1, 0.18, 0.7)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	breath_box.add_child(bg)
	breath_fill = ColorRect.new()
	breath_fill.color = Color(0.45, 0.85, 1.0)
	breath_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	breath_fill.anchor_bottom = 1.0
	breath_fill.anchor_right = 1.0
	breath_box.add_child(breath_fill)
	breath_label = Label.new()
	style(breath_label, 0.9)
	breath_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	breath_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	breath_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	breath_label.add_theme_font_size_override("font_size", int(font_size * 0.9))
	breath_label.add_theme_constant_override("outline_size", 6)
	breath_label.add_theme_color_override("font_outline_color", Color(0.05, 0.1, 0.2))
	breath_box.add_child(breath_label)
	breath_box.visible = false

func start_mulji() -> void:
	dive_on = true
	breath = 1.0
	sea_wall.set_deferred("disabled", true)
	for it in mulji_items:
		(it[0] as Node3D).visible = not bool(it[1])
	if breath_box == null:
		make_breath_hud()
	float_text(tr("바다로 들어가 반짝이는 전복·소라를 주워요!"), get_viewport().get_visible_rect().size * Vector2(0.5, 0.4), Color(0.8, 0.95, 1.0), 2.2)
	update_quest_text()

func update_mulji(delta: float) -> void:
	if not dive_on:
		return
	mulji_warn = maxf(0.0, mulji_warn - delta)
	var under := swimming and player.position.y < swim_ceiling() - 0.35
	if under:
		breath -= delta / 10.0
	else:
		breath = minf(1.0, breath + delta * 0.6)
	breath_box.visible = swimming
	breath_fill.anchor_right = clampf(breath, 0.0, 1.0)
	breath_fill.color = Color(0.45, 0.85, 1.0) if breath > 0.3 else Color(1.0, 0.45, 0.4).lerp(Color(1, 0.8, 0.5), absf(sin(anim_t * 8.0)))
	breath_label.text = tr("숨 %d%%  |  전복·소라 %d/%d%s") % [int(breath * 100.0), mulji_got, mulji_items.size(), tr("  (위로 버튼으로 숨 쉬기!)") if breath < 0.3 else ""]
	if breath <= 0.0:
		sfx("bad")
		flash(Color(0.6, 0.8, 1.0))
		float_text(tr("숨이 차요! 물 위로 올라왔어요"), get_viewport().get_visible_rect().size * Vector2(0.5, 0.4), Color(1, 0.7, 0.6), 1.8)
		player.position = on_ground(20, SHORE_Z + 2.5, 0.3)
		player.velocity = Vector3.ZERO
		breath = 1.0
		return
	# 너무 멀리 가지 않게
	var p := player.position
	if swimming and (p.z < -26.0 or p.x < 6.0 or p.x > 37.0):
		player.position.x = clampf(p.x, 6.2, 36.8)
		player.position.z = maxf(p.z, -25.8)
		player.velocity = Vector3.ZERO
		if mulji_warn <= 0.0:
			mulji_warn = 2.0
			float_text(tr("해녀: 너무 멀리 가면 위험해!"), get_viewport().get_visible_rect().size * Vector2(0.5, 0.36), Color(1, 0.9, 0.7), 1.5)
	for it in mulji_items:
		if bool(it[1]):
			continue
		var n: Node3D = it[0]
		n.rotation.y += delta * 0.6
		if n.position.distance_to(p + Vector3(0, 0.5, 0)) < 1.5:
			it[1] = true
			mulji_got += 1
			sfx("good", 1.0 + mulji_got * 0.06)
			burst3d(n.position + Vector3(0, 0.3, 0), Color(0.8, 0.95, 1.0), 14)
			breath = minf(1.0, breath + 0.1)
			var tw := n.create_tween()
			tw.tween_property(n, "position", n.position + Vector3(0, 1.2, 0), 0.35).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(n, "scale", Vector3.ONE * 0.01, 0.35)
			tw.tween_callback(func(): n.visible = false)
			float_text("%s! (%d/%d)" % [tr("전복") if mulji_items.find(it) % 2 == 0 else tr("소라"), mulji_got, mulji_items.size()], cam.unproject_position(n.position), Color(0.85, 1.0, 1.0), 1.0)
			if mulji_got >= mulji_items.size():
				end_mulji()
			return

func end_mulji() -> void:
	dive_on = false
	mulji_done = true
	breath_box.visible = false
	earn(20)
	say([
		[tr("해녀"), tr("(물 위로 고개를 내밀며) 호오이~ 숨비소리 한 번 시원하구나!")],
		[tr("해녀"), tr("처음인데 여섯 개나? 너 해녀 해도 되겠다! 자, 수고비다.")],
	], func():
		player.position = on_ground(HAENYEO_POS.x - 1.5, HAENYEO_POS.z - 1.0, 0.3)
		player.velocity = Vector3.ZERO
		if quest < S_DIVE:
			sea_wall.set_deferred("disabled", false)
		update_quest_text()
		save_progress())

# ---------- 새끼 문어 찾기 (해초 숲에 숨은 다섯 마리) ----------
const OCTO_PTS := [Vector3(-14, 0, -44), Vector3(9, 0, -49), Vector3(-25, 0, -57), Vector3(27, 0, -63), Vector3(-4, 0, -67)]
var octos: Array = []          # [노드, 찾았는지]
var octo_found := [false, false, false, false, false]

func make_octos() -> void:
	for i in OCTO_PTS.size():
		var p: Vector3 = OCTO_PTS[i]
		var n := Node3D.new()
		n.position = on_ground(p.x, p.z, 0.02)
		add_child(n)
		var sand := Color(0.72, 0.66, 0.5)
		var items := [[Vector3(0, 0.22, 0), Vector3(0.36, 0.32, 0.34), sand], [Vector3(-0.08, 0.28, 0.15), Vector3(0.06, 0.06, 0.04), Color(0.1, 0.08, 0.08)], [Vector3(0.08, 0.28, 0.15), Vector3(0.06, 0.06, 0.04), Color(0.1, 0.08, 0.08)]]
		for k in 6:
			var a := k * TAU / 6.0
			items.append([Vector3(cos(a) * 0.2, 0.05, sin(a) * 0.2), Vector3(0.24, 0.07, 0.08), sand.darkened(0.1), Vector3(0, -rad_to_deg(a), 0)])
		var b := blob_node(items)
		mg_nodes.erase(b)
		b.reparent(n, false)
		b.position = Vector3.ZERO
		n.set_meta("body", b)
		octos.append([n, octo_found[i]])
		n.visible = not octo_found[i]

func octo_count() -> int:
	var c := 0
	for b in octo_found:
		c += 1 if b else 0
	return c

func update_octos(delta: float) -> void:
	if quest < S_DIVE or quest == S_ESCAPE or not swimming:
		return
	var p := player.position + Vector3(0, 0.5, 0)
	for i in octos.size():
		var o: Array = octos[i]
		if bool(o[1]):
			continue
		var n: Node3D = o[0]
		var d := n.position.distance_to(p)
		var b: Node3D = n.get_meta("body")
		if d < 5.0:
			# 가까이 오면 꼼지락꼼지락 (몸빛이 살짝 붉어져요)
			var k := 1.0 - d / 5.0
			b.scale = Vector3(1.0 + sin(anim_t * 14.0) * 0.12 * k, 1.0 + cos(anim_t * 11.0) * 0.1 * k, 1.0)
			b.rotation.y = sin(anim_t * 6.0) * 0.4 * k
		else:
			b.scale = Vector3.ONE
		if d < 1.7:
			o[1] = true
			octo_found[i] = true
			var c := octo_count()
			sfx("good", 1.1 + c * 0.05)
			burst3d(n.position + Vector3(0, 0.4, 0), Color(1.0, 0.55, 0.6), 16)
			var tw := n.create_tween()
			tw.tween_property(b, "scale", Vector3.ONE * 1.3, 0.15)
			tw.tween_property(n, "position", n.position + Vector3(0, 3.0, -1.5), 0.9).set_ease(Tween.EASE_IN)
			tw.parallel().tween_property(n, "scale", Vector3.ONE * 0.01, 0.9)
			tw.tween_callback(func(): n.visible = false)
			float_text(tr("꼬물꼬물! 새끼 문어를 찾았다 (%d/5)") % c, cam.unproject_position(n.position), Color(1, 0.75, 0.78), 1.4)
			earn(3)
			if c >= 5:
				earn(15)
				float_text(tr("새끼 문어들: 찾아 줘서 고마워요~!"), get_viewport().get_visible_rect().size * Vector2(0.5, 0.34), Color(1, 0.85, 0.85), 2.2)
			update_quest_text()
			save_progress()
			return

# ---------- 난파선 보물 상자 (조개 소리 따라 하기) ----------
var chest_done := false
var chest_lid: Node3D
var chest_c := Vector3.ZERO

func half_cyl_mesh(length: float, r: float, segs: int = 12) -> ArrayMesh:
	# 둥근 뚜껑: x축으로 누운 반원기둥 (양 끝 막음)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hx := length / 2.0
	for k in segs:
		var a0 := PI * k / segs
		var a1 := PI * (k + 1) / segs
		var p0 := Vector3(0, sin(a0) * r, cos(a0) * r)
		var p1 := Vector3(0, sin(a1) * r, cos(a1) * r)
		var n0 := Vector3(0, sin(a0), cos(a0))
		var n1 := Vector3(0, sin(a1), cos(a1))
		for v in [[p0, n0, -hx], [p1, n1, -hx], [p1, n1, hx], [p0, n0, -hx], [p1, n1, hx], [p0, n0, hx]]:
			st.set_normal(v[1])
			st.set_uv(Vector2((float(v[2]) + hx) / length, float(k) / segs))
			st.add_vertex(Vector3(float(v[2]), 0, 0) + (v[0] as Vector3))
		for sx in [-hx, hx]:
			var nn := Vector3(signf(sx), 0, 0)
			var tri := [Vector3(sx, 0, 0), Vector3(sx, p0.y, p0.z), Vector3(sx, p1.y, p1.z)]
			if sx > 0.0:
				tri = [tri[0], tri[2], tri[1]]
			for q in tri:
				st.set_normal(nn)
				st.set_uv(Vector2(0.5, 0.5))
				st.add_vertex(q)
	return st.commit()

func make_chest() -> void:
	chest_c = on_ground(WRECK_C.x - 5.0, WRECK_C.z + 6.5)
	var n := make_spot(chest_c, "chest", "", tr("보물 상자"), true)
	var body := Node3D.new()
	n.add_child(body)
	body.rotation = Vector3(0.04, 0.25, -0.05)
	var wood := make_color(Color(0.45, 0.28, 0.15))
	var wood_d := make_color(Color(0.3, 0.18, 0.1))
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.36, 0.38, 0.4)
	iron.metallic = 0.7
	iron.roughness = 0.4
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(0.95, 0.75, 0.3)
	gold.metallic = 0.9
	gold.roughness = 0.25
	var L := 1.2
	var D := 0.76
	var Hb := 0.56
	# 몸통: 가로 널빤지 네 장 + 사이 홈
	for k in 4:
		add_mbox(body, wood if k % 2 == 0 else make_color(Color(0.5, 0.31, 0.17)), Vector3(L, Hb / 4.0 - 0.012, D), Vector3(0, Hb / 8.0 + k * Hb / 4.0, 0))
	add_mbox(body, wood_d, Vector3(L - 0.02, Hb - 0.02, D - 0.02), Vector3(0, Hb / 2.0, 0))
	# 쇠 띠 두 줄 + 모서리 쇠
	for bx in [-0.36, 0.36]:
		add_mbox(body, iron, Vector3(0.07, Hb + 0.01, D + 0.03), Vector3(bx, Hb / 2.0, 0))
	for cx in [-L / 2.0, L / 2.0]:
		for cz in [-D / 2.0, D / 2.0]:
			add_mbox(body, gold, Vector3(0.09, Hb + 0.02, 0.09), Vector3(cx, Hb / 2.0, cz))
	# 앞쪽 자물쇠판 + 조개 무늬 다섯 알
	add_mbox(body, gold, Vector3(0.22, 0.24, 0.04), Vector3(0, Hb - 0.1, D / 2.0 + 0.02))
	add_mcyl(body, make_color(Color(0.15, 0.1, 0.05)), 0.03, 0.03, 0.05, Vector3(0, Hb - 0.12, D / 2.0 + 0.04)).rotation.x = PI / 2.0
	for k in 5:
		add_blobs(body, [[Vector3(-0.44 + k * 0.22, 0.16, D / 2.0 + 0.02), Vector3(0.11, 0.09, 0.03), SIMON_COLS[k]]], blob_gloss())
	# 둥근 뚜껑 (뒤쪽 경첩을 축으로 열려요)
	chest_lid = Node3D.new()
	chest_lid.position = Vector3(0, Hb, -D / 2.0)
	body.add_child(chest_lid)
	var lid := MeshInstance3D.new()
	lid.mesh = half_cyl_mesh(L, D / 2.0)
	# 둥근 뚜껑은 어느 쪽에서 봐도 꽉 차 보이게 양면으로 그려요 (예전엔 뒤에서 보면 비어 보였어요)
	var lid_wood := wood.duplicate() as StandardMaterial3D
	lid_wood.cull_mode = BaseMaterial3D.CULL_DISABLED
	lid.material_override = lid_wood
	lid.position = Vector3(0, 0, D / 2.0)
	chest_lid.add_child(lid)
	for bx in [-0.36, 0.36]:
		var band := MeshInstance3D.new()
		band.mesh = half_cyl_mesh(0.07, D / 2.0 + 0.015)
		var band_iron := iron.duplicate() as StandardMaterial3D
		band_iron.cull_mode = BaseMaterial3D.CULL_DISABLED
		band.material_override = band_iron
		band.position = Vector3(bx, 0, D / 2.0)
		chest_lid.add_child(band)
	add_mbox(chest_lid, gold, Vector3(0.16, 0.16, 0.04), Vector3(0, 0.02, D + 0.01))
	# 안쪽 보물 (열리면 보여요)
	add_blobs(body, [[Vector3(0, Hb - 0.04, 0), Vector3(1.0, 0.1, 0.6), Color(0.95, 0.78, 0.3)], [Vector3(0.15, Hb + 0.02, -0.05), Vector3(0.2, 0.2, 0.2), Color(0.15, 0.12, 0.2)], [Vector3(-0.25, Hb + 0.0, 0.1), Vector3(0.12, 0.12, 0.12), Color(1, 0.98, 0.95)]], blob_gloss())
	# 둘레에 흩어진 엽전과 따개비
	var r := RandomNumberGenerator.new()
	r.seed = 77
	var bits := []
	for k in 9:
		var a := r.randf() * TAU
		var d := r.randf_range(0.8, 1.4)
		bits.append([Vector3(cos(a) * d, 0.02, sin(a) * d), Vector3(0.12, 0.025, 0.12), Color(0.9, 0.72, 0.3)])
	add_blobs(n, bits, blob_gloss())
	if chest_done:
		chest_lid.rotation.x = -1.6


func start_shell() -> void:
	start_game("simon", {"world": true, "scene": "chest", "art": "world", "title": tr("상자 자물쇠는 조개 소리로 열려요!\n울리는 순서를 기억했다가 똑같이 눌러요"), "goal": 4, "start_len": 3, "lives": 3, "unit": tr("소리")}, shell_done)

func shell_done(ok: bool, _good: bool) -> void:
	if not ok:
		say([["", tr("철컥... 자물쇠가 다시 잠겼다. 조개 소리를 다시 들어 보자.")]], Callable())
		return
	chest_done = true
	sfx("good")
	burst3d(chest_c + Vector3(0, 0.9, 0), Color(1, 0.9, 0.5), 30)
	if chest_lid != null:
		chest_lid.create_tween().tween_property(chest_lid, "rotation:x", -1.6, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	earn(30)
	say([["", tr("끼이익- 상자가 열렸다! 주먹만 한 흑진주와 엽전이 가득하다!")]], func(): update_quest_text(); save_progress())

# ---------- 용궁 춤 따라 하기 (잔치 셋째 일) ----------
func start_dance() -> void:
	start_game("dance", {"world": true, "scene": "dance", "art": "world", "title": tr("자라가 추는 용궁 춤을 잘 보고\n화살표 순서대로 휙휙 따라 해요"), "goal": 4, "start_len": 3, "lives": 3, "unit": tr("마디")}, dance_done)

func dance_done(ok: bool, _good: bool) -> void:
	var jara := npc("jara")
	jara.position = Vector3(-2.5, PALACE_Y + 0.25, -111)
	jara.rotation.y = PI
	if not ok:
		say([[tr("자라"), tr("허허, 발이 꼬였구려. 다시 한 번 춰 봅시다!")]], Callable())
		return
	feast_flags["dance"] = true
	earn(10)
	say([[tr("자라"), tr("얼씨구 좋다! 용궁 물고기들도 덩실덩실 따라 추는구려!")]], func(): update_quest_text())

func dance_hop(n: Node3D, dir: String, base_y: float) -> void:
	var v: Vector2 = ARROW_VEC.get(dir, Vector2.ZERO)
	var tw := n.create_tween()
	if dir == "up":
		tw.tween_property(n, "position:y", base_y + 0.7, 0.14).set_ease(Tween.EASE_OUT)
		tw.tween_property(n, "position:y", base_y, 0.16).set_ease(Tween.EASE_IN)
	elif dir == "down":
		tw.tween_property(n, "scale", Vector3(1.15, 0.7, 1.15), 0.12)
		tw.tween_property(n, "scale", Vector3.ONE, 0.16)
	else:
		tw.tween_property(n, "rotation:y", n.rotation.y + v.x * 0.9, 0.14)
		tw.parallel().tween_property(n, "position:y", base_y + 0.3, 0.14)
		tw.tween_property(n, "rotation:y", n.rotation.y, 0.16)
		tw.parallel().tween_property(n, "position:y", base_y, 0.16)

# ---------- 먹물 미로 (탈출 중 깊은 골짜기) ----------
var ink_amt := 0.0
var ink_left := 0.0
var ink_fired := false
var ink_trail: Array = []      # [노드, 주웠는지]

func make_ink_trail() -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.98, 0.9)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.95, 0.75)
	m.emission_energy_multiplier = 3.0
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.disable_fog = true
	var sm := SphereMesh.new()
	sm.radius = 0.16
	sm.height = 0.32
	for i in 14:
		var z := -86.0 + i * 2.2
		var x := sin(i * 0.75) * 5.0
		var n := MeshInstance3D.new()
		n.mesh = sm
		n.material_override = m
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.position = on_ground(x, z, 1.4)
		n.visible = false
		add_child(n)
		ink_trail.append([n, false])

func update_ink(delta: float) -> void:
	if not ink_fired and player.position.z > -88.0 and player.position.z < -80.0:
		ink_fired = true
		ink_left = 9.0
		sfx("splash", 0.5)
		shake(10)
		spawn_ink(player.position + Vector3(0, 1.0, -2.0))
		float_text(tr("문어 장군의 먹물이다! 앞이 캄캄해요\n진주 불빛을 따라 남쪽으로!"), get_viewport().get_visible_rect().size * Vector2(0.5, 0.36), Color(1, 0.95, 0.75), 2.6)
		for t in ink_trail:
			t[1] = false
			(t[0] as Node3D).visible = true
			(t[0] as Node3D).scale = Vector3.ONE
	if ink_left > 0.0:
		ink_left -= delta
		ink_amt = minf(1.0, ink_amt + delta * 2.5)
		for t in ink_trail:
			if bool(t[1]):
				continue
			var n: Node3D = t[0]
			n.scale = Vector3.ONE * (1.0 + sin(anim_t * 5.0 + n.position.z) * 0.2)
			if n.position.distance_to(player.position + Vector3(0, 0.6, 0)) < 1.6:
				t[1] = true
				sfx("tick", 1.5)
				earn(1)
				burst3d(n.position, Color(1, 0.95, 0.8), 6)
				n.visible = false
	else:
		ink_amt = maxf(0.0, ink_amt - delta * 0.8)
		if ink_fired and ink_amt <= 0.0:
			for t in ink_trail:
				(t[0] as Node3D).visible = false

func apply_ink_look() -> void:
	if ink_amt <= 0.0 or env_ref == null:
		return
	env_ref.fog_light_color = env_ref.fog_light_color.lerp(Color(0.02, 0.02, 0.05), ink_amt)
	env_ref.fog_density = lerpf(env_ref.fog_density, 0.2, ink_amt)
	env_ref.ambient_light_color = env_ref.ambient_light_color.lerp(Color(0.08, 0.08, 0.12), ink_amt * 0.8)

func reset_ink() -> void:
	ink_fired = false
	ink_left = 0.0
	ink_amt = 0.0
	for t in ink_trail:
		(t[0] as Node3D).visible = false


# ---------- 탈출: 문어 장군을 따돌리고 물 위로 ----------

func start_escape() -> void:
	follow_on = true
	chase_on = true
	chase_wait = 3.0
	ink_t = 2.0
	var oc := npc("octopus")
	oc.position = Vector3(OCTOPUS_POS.x, PALACE_Y + 0.25, OCTOPUS_POS.z)
	# 용궁 문 밖에서 출발해요 (문어 장군은 전각 앞에서 뒤쫓아요)
	player.position = Vector3(0, PALACE_Y + 0.6, GATE_Z + 3.0)
	player.rotation.y = 0.0
	player.velocity = Vector3.ZERO
	cam_yaw_target = 0.0
	set_quest(S_ESCAPE)
	float_text(tr("남쪽으로 헤엄쳐요!"), get_viewport().get_visible_rect().size / 2.0, Color(1, 0.9, 0.4), 1.6)

func update_chase(delta: float) -> void:
	if not chase_on:
		chase_on = true
		chase_wait = 3.0
	var oc := npc("octopus")
	var body := body_of(oc)
	# 물가에 닿으면 성공
	if player.position.z > SHORE_Z - 1.0 and not swimming:
		chase_on = false
		follow_on = false
		event_lock = true
		oc.position = Vector3(OCTOPUS_POS.x, PALACE_Y + 0.25, OCTOPUS_POS.z)
		shore_ending()
		return
	if chase_wait > 0.0:
		chase_wait -= delta
		return
	var tgt := player.position + Vector3(0, 0.4, 0)
	var to := tgt - oc.position
	var d := to.length()
	var sp := 2.0 if ink_amt > 0.3 else 3.7
	oc.position += to.normalized() * minf(sp * delta, d)
	var gh := height_at(oc.position.x, oc.position.z)
	oc.position.y = maxf(oc.position.y, gh)
	oc.rotation.y = lerp_angle(oc.rotation.y, atan2(to.x, to.z), minf(1.0, delta * 6.0))
	if body != null:
		var ph: float = follow_phase.get("oc", 0.0) + delta * sp / 1.6
		follow_phase["oc"] = ph
		body.set_meta("gait", [fposmod(ph, 1.0), 1.0, 0.6])
	# 가끔 먹물을 뿜어요
	ink_t -= delta
	if ink_t <= 0.0:
		ink_t = 3.5
		spawn_ink(oc.position + Vector3(0, 1.5, 0))
	if d < 1.6:
		chase_on = false
		sfx("fail")
		shake(16)
		show_card(tr("문어 장군에게 붙잡혔어요!\n\n용궁 문 앞에서 다시 헤엄쳐 봐요."), 0.0, 2.0, func():
			player.position = Vector3(0, PALACE_Y + 0.6, GATE_Z + 3.0)
			player.velocity = Vector3.ZERO
			oc.position = Vector3(OCTOPUS_POS.x, PALACE_Y + 0.25, OCTOPUS_POS.z)
			reset_ink()
			chase_on = true
			chase_wait = 3.0)

func spawn_ink(at: Vector3) -> void:
	var n := blob_node([[Vector3.ZERO, Vector3(2.2, 1.8, 2.2), Color(0.08, 0.06, 0.12)], [Vector3(0.6, 0.3, 0.2), Vector3(1.4, 1.2, 1.4), Color(0.12, 0.08, 0.16)]])
	mg_nodes.erase(n)
	n.global_position = at
	n.scale = Vector3.ONE * 0.2
	sfx("splash", 0.6)
	var tw := n.create_tween()
	tw.tween_property(n, "scale", Vector3.ONE * 1.4, 0.6).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.4)
	tw.tween_property(n, "scale", Vector3.ONE * 0.01, 1.0)
	tw.tween_callback(n.queue_free)

# ---------- 바닷가: 토끼의 꾀, 그리고 끝 ----------

func shore_ending() -> void:
	var rabbit := npc("rabbit")
	var jara := npc("jara")
	jara.position = on_ground(player.position.x + 1.8, player.position.z + 0.5)
	rabbit.position = on_ground(player.position.x - 1.8, player.position.z + 1.0)
	var l := [
		[tr("토끼"), tr("휴우, 살았다! 뭍이다 뭍!")],
		[tr("자라"), tr("자, 토끼 선생. 바위에 말려 둔 간을 어서 가져오시오.")],
		[tr("토끼"), tr("(깡충 뛰어 바위 위로 올라가더니 배를 잡고 웃었다)")],
		[tr("토끼"), tr("이 미련한 자라야! 세상에 간을 꺼내 놓고 다니는 짐승이 어디 있니?")],
		[tr("토끼"), tr("벼슬은 됐고, 나는 내 뒷산으로 간다! 안녕~")],
	]
	if not lured:
		l.append([tr("토끼"), tr("(돌아보며) 너는 처음부터 조심하라고 했지? 고마웠어!")])
	l.append([tr("자라"), tr("아아... 이를 어쩐단 말이오. 용왕님 뵐 낯이 없구려...")])
	say(l, func():
		var tw := rabbit.create_tween()
		var dest := on_ground(RABBIT_SPOTS[1].x, RABBIT_SPOTS[1].z)
		tw.tween_property(rabbit, "position", dest, 2.5)
		tw.tween_callback(func(): rabbit.visible = false)
		if has_ginseng:
			ask("", tr("축 처진 자라에게 뒷산에서 캔 산삼을 건넬까?"), [tr("산삼을 건넨다"), tr("그냥 위로한다")], on_ginseng)
		else:
			on_ginseng(1))

func on_ginseng(i: int) -> void:
	var l := []
	if i == 0:
		ending = "ginseng"
		has_ginseng = false
		l.append([tr("자라"), tr("이, 이건 백 년 묵은 산삼이 아니오?!")])
		l.append([tr("자라"), tr("이것이면 용왕님 병도 나으실 게요. 고맙소, 정말 고맙소!")])
		l.append(["", tr("자라는 산삼을 품에 안고 기쁘게 바다로 돌아갔다.")])
	else:
		ending = "plain"
		l.append(["", tr("자라의 등딱지를 토닥토닥 두드려 주었다.")])
		l.append([tr("자라"), tr("...그래도 그대 덕에 용궁 구경은 즐거웠소. 언젠가 또 봅시다.")])
	record_ch3_ending()
	say(l, func():
		var card := tr("자라는 바닷속으로,\n토끼는 뒷산으로 돌아갔어요.\n\n")
		if ending == "ginseng":
			card += tr("얼마 뒤 바닷가에 소식이 들려왔어요.\n용왕님이 산삼을 드시고\n씻은 듯이 나으셨대요.") + "\n\n" + tr("엔딩 “산삼 한 뿌리”")
		else:
			card += tr("꾀 많은 토끼 이야기는\n바닷가 마을에 두고두고 전해졌대요.\n하지만 용궁의 용왕님은\n아직 자리에서 일어나지 못하셨대요.") + "\n\n" + tr("엔딩 “꾀 많은 토끼”")
		card += ch3_ending_count_text()
		show_card(card, 0.0, 5.0, finish_trial))

# 위로만 하고 끝났을 때, 나중에라도 산삼을 가져다주면 용왕님이 나아요 (두 번째 기회)
func give_ginseng_late() -> void:
	has_ginseng = false
	ending = "late"
	record_ch3_ending()
	say([
		[tr("자라"), tr("이, 이건 백 년 묵은 산삼이 아니오?! 이걸 구하러 그 먼 뒷산까지...")],
		[tr("자라"), tr("늦었지만, 아직 늦지 않았소! 당장 용궁으로 가져가리다. 고맙소, 정말 고맙소!")],
		["", tr("자라는 산삼을 품에 안고 서둘러 바다로 들어갔다.")],
	], func():
		show_card(tr("며칠 뒤 바닷가에 소식이 들려왔어요.\n늦게 도착한 산삼 한 뿌리로\n용왕님이 자리를 털고 일어나셨대요.\n\n엔딩 “늦게 도착한 약”") + ch3_ending_count_text(), 0.0, 5.0, func():
			earn(20)
			if ginseng_spot != null:
				ginseng_spot.visible = false
			update_quest_text()
			save_progress()))

# 3장 엔딩 기록 (1장처럼 모은 엔딩 수를 세요)
const CH3_ENDINGS := ["ginseng", "plain", "late"]
func record_ch3_ending() -> void:
	record_ending("ch3", ending)

func ch3_ending_count_text() -> String:
	return tr("\n(별주부전 엔딩 %d/%d)") % [endings_seen("ch3").size(), CH3_ENDINGS.size()]

func finish_trial() -> void:
	event_lock = false
	earn(30)
	set_quest(S_END)
	show_card(tr("빈 책장에 별주부전 그림이 새로 생겼어요.\n\n세 이야기가 모두 채워졌어요!\n\n(체험판은 여기까지예요.\n다음 이야기 책장도 곧 열려요.)"), 0.0, 5.0, Callable())

# ---------- 바닷속에서 본 물고기는 공용 도감(바닷속 칸)에도 올라가요 ----------
const SEA_IDS := ["juldom", "jwichi", "bollak", "deungbul"]
func sync_sea_book() -> void:
	var changed := false
	for k in SEA_IDS.size():
		var i := fish_index(SEA_IDS[k])
		if fish_seen[k] and int(fish_caught[i]) == 0:
			fish_caught[i] = 1
			changed = true
		elif int(fish_caught[i]) > 0 and not fish_seen[k]:
			fish_seen[k] = true
	if changed:
		save_book()

# ---------- 갯바위 낚시 (collect_plan.md: 망둥어·노래미·우럭·감성돔·돌돔, 갯바위 어부) ----------
# 걸린 물고기가 파도를 타고 밀려왔다 빠졌다 해요. 파도 박자에 맞춰 초록 칸을 움직여요
const ROCK_C := Vector3(-20.0, 0, -5.2)
var waves_t := 0.0

func rock_stand() -> Vector3:
	return on_ground(ROCK_C.x, ROCK_C.z)

func make_rock_fishing() -> void:
	var st := rock_stand()
	var rocks := []
	var r := RandomNumberGenerator.new()
	r.seed = 41
	# 물가로 뻗은 검은 갯바위
	for i in 14:
		var x := ROCK_C.x + r.randf_range(-3.5, 3.5)
		var z := ROCK_C.z + r.randf_range(-4.5, -1.0)
		if absf(x - ROCK_C.x) < 1.0 and z > ROCK_C.z - 1.6:
			continue
		var g := height_at(x, z)
		var sz := Vector3(r.randf_range(1.0, 1.9), r.randf_range(0.6, 1.3), r.randf_range(0.9, 1.6))
		rocks.append([Vector3(x, maxf(g, -0.2) + sz.y * 0.35, z), sz, Color(0.3, 0.3, 0.32).lerp(Color(0.42, 0.4, 0.38), r.randf()), Vector3(r.randf_range(-10, 10), r.randf_range(0, 360), r.randf_range(-10, 10))])
	add_blobs(self, rocks, stone_blob_mat, true)
	var spot := make_spot(st, "fish", "rock", tr("갯바위 낚시터"), true)
	spot.visible = true
	make_basket(st + Vector3(1.2, 0, 0.8), 0.8, Color(0.5, 0.62, 0.7))
	var n := make_npc("seafisher", tr("갯바위 어부"), Color(0.4, 0.45, 0.55), on_ground(ROCK_C.x - 2.2, ROCK_C.z + 1.6), 1.0, true)
	n.rotation.y = PI * 0.8

var seafisher_met := false
func talk_seafisher() -> void:
	var who := tr("갯바위 어부")
	if not seafisher_met:
		seafisher_met = true
		say([
			[who, tr("어이, 꼬마 낚시꾼! 갯바위 낚시는 연못하고 딴판이라네.")],
			[who, tr("물고기가 걸리면 파도를 타고 밀려왔다 빠졌다 하지. 파도 박자를 읽어서 초록 칸을 맞추게.")],
			[who, tr("여기선 망둥어, 노래미, 우럭, 감성돔, 그리고 귀한 돌돔이 올라와. 비 오는 날엔 감성돔, 맑은 날엔 돌돔이 잘 물지.")],
		], Callable())
		return
	var here := fish_in("ch3_rock")
	var got := fish_found_in("ch3_rock")
	if got >= here.size():
		say([[who, tr("갯바위 물고기를 다 낚아 본 꼬마라니, 이 바다에 소문이 자자하네!")]], Callable())
	else:
		say([[who, tr("갯바위 물고기 %d/%d. 날씨가 바뀌면 다시 와 보게. 물고기도 날씨를 탄다네.") % [got, here.size()]]], Callable())

func start_fishing() -> void:
	if current_thing.get("id", "") == "rock":
		start_rock_fishing()

func start_rock_fishing() -> void:
	fish_place = "ch3_rock"
	start_game("fish", {"world": true, "art": "world", "title": tr("찌가 쏙 들어가면 눌러서 채요!\n걸리면 파도 박자에 맞춰 초록 칸을 움직여요")}, fish_done)
	var st := rock_stand()
	var sea := Vector3(ROCK_C.x + 0.5, 0.0, ROCK_C.z - 6.0)
	var fspot: Node3D = null
	for t in things:
		if t["kind"] == "fish" and t["id"] == "rock":
			fspot = t["node"]
	world_game_begin(st, sea, st + Vector3(2.4, 3.2, 3.4), sea + Vector3(0, 0, 1.5))
	if fspot != null:
		world_hide(fspot)
	hold_tool("rod")
	var bob := Node3D.new()
	world_node(bob)
	add_ball(bob, Color(0.9, 0.2, 0.2), 0.08, Vector3(0, 0.05, 0))
	add_ball(bob, Color(1, 1, 1), 0.075, Vector3(0, -0.01, 0))
	w["bobber"] = bob
	w["bob_at"] = sea + Vector3(0, 0.06, 0)
	w["fight_c"] = sea + Vector3(0, 0.02, 0)
	make_fish_world_parts()
	waves_t = 0.0

func update_rock_waves(delta: float) -> void:
	if not (mg_active and fish_place == "ch3_rock" and w.has("bob_at")):
		return
	waves_t -= delta
	if waves_t <= 0.0:
		waves_t = 1.0 / 0.54
		# 파도가 갯바위에 부서져요 (힘겨루기 박자와 같아요)
		splash3d(rock_stand() + Vector3(rng.randf_range(-2.0, 2.0), 0.2, -2.6), true)
		sfx("splash", rng.randf_range(0.7, 0.85))

# ---------- 이야기 조각 (collect_plan.md 7장: 별주부전 5조각) ----------
# 0 갯바위 낚시터 옆, 1 뒷산 산삼 자리 근처, 2 용궁 전각 옆(용궁에 들어간 뒤), 3 넙치 문지기(모래 찾기를 끝내면), 4 해녀 부탁
func make_tales() -> void:
	make_tale_spot(on_ground(ROCK_C.x + 2.4, ROCK_C.z + 2.4), "ch3", 0)
	make_tale_spot(on_ground(GINSENG_POS.x + 2.6, GINSENG_POS.z + 2.2), "ch3", 1)
	make_tale_spot(Vector3(-9.6, PALACE_Y + 0.25, -119.4), "ch3", 2)

func tale_spot_ready(g: String, i: int) -> bool:
	if g != "ch3":
		return true
	match i:
		2:
			return quest >= S_COURT and quest != S_ESCAPE
		3, 4:
			return false
	return true

# 물가: 바다와 모래가 만나는 곳을 얇은 물막·밀려왔다 빠지는 거품·젖은 모래로 덮어 반듯한 선이 안 보이게
func make_shore_wash() -> void:
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform float line_z = -5.0;
uniform vec3 water = vec3(0.16, 0.42, 0.5);
uniform vec3 wet = vec3(0.42, 0.34, 0.22);
varying vec3 wp;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float d = wp.z - line_z;
	float wob = (noise(wp.xz * vec2(0.35, 0.8)) - 0.5) * 0.9;
	float reach = 0.7 + 0.8 * (0.5 + 0.5 * sin(TIME * 0.55 + wp.x * 0.09)) + wob;
	vec3 col;
	float a;
	if (d < reach) {
		// 얇은 물막: 바다 쪽에서 짙고 물가로 갈수록 투명
		float t = smoothstep(-2.5, reach, d);
		col = mix(water, mix(water, wet, 0.5), t);
		a = 0.88 * smoothstep(-2.8, -0.7, d) * (1.0 - 0.65 * smoothstep(0.2, reach, d));
		// 물 끝의 거품 줄
		float foam = smoothstep(reach - 0.25, reach - 0.05, d) * (0.55 + 0.45 * noise(wp.xz * vec2(1.5, 3.0) + vec2(TIME * 0.3, 0.0)));
		col = mix(col, vec3(0.93, 0.96, 0.95), foam * 0.85);
		a = max(a, foam * 0.8);
	} else {
		// 물이 빠진 뒤 젖은 모래가 점점 마르는 쪽
		float dry = smoothstep(reach, reach + 2.8 + wob, d);
		col = wet;
		a = (1.0 - dry) * 0.5;
	}
	ALBEDO = col;
	ROUGHNESS = 0.7;
	ALPHA = clamp(a, 0.0, 1.0);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("line_z", SHORE_Z + 1.0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var xs := 80
	var zs := 14
	for i in xs:
		for k in zs:
			var pts := []
			for q in [[i, k], [i + 1, k], [i + 1, k + 1], [i, k + 1]]:
				var x: float = -80.0 + q[0] * 2.0
				var z: float = SHORE_Z - 3.0 + q[1] * 0.6
				pts.append(Vector3(x, maxf(height_at(x, z), 0.05) + 0.035, z))
			for idx in [0, 1, 2, 0, 2, 3]:
				st.set_normal(Vector3.UP)
				st.add_vertex(pts[idx])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	shore_wash = mi

var shore_wash: MeshInstance3D
