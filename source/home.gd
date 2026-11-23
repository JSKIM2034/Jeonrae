extends "res://core.gd"

# 집 마을 "이야기골" (첫 버전)
# 세 이야기 지역의 남쪽 가운데에 있는 작은 마을. 주인공의 허름한 초가, 이야기꾼 할머니, 큰 정자나무, 빈 집터 다섯 곳.
# 이야기를 하나 끝낼 때마다 정자나무에 등불이 하나씩 켜져요. (설계: docs/world_plan.md 2장)
# 이정표로 오가요: 서북 버드나무 길 ↔ 1장, 북쪽 돌고개 ↔ 2장, 동북 갈대 나루 ↔ 3장 (모두 각 장의 남쪽 이정표로 이어져요).
# 내 집 문으로 들어가면 마을 밖 멀리 지어 둔 방(ROOM_C)으로 옮겨 가요. 카메라 쪽 벽은 숨겨서 방 안이 보여요.
# 진행은 저장 파일의 [home] 칸에만 넣어요.

const HOME_HALF := 35.0
const HOUSE_POS := Vector3(0, 0, 15)       # 주인공 초가 (문이 북쪽 정자나무를 봐요)
const GRANNY_HOUSE := Vector3(17, 0, 2)
const TREE_POS := Vector3(-1.5, 0, -3)     # 큰 정자나무
const GRANNY_POS := Vector3(2.2, 0, -0.6)  # 할머니는 정자나무 그늘 평상 옆에
const POND_HOME := Vector3(22, 0, -9)
const ARRIVE_CH1 := Vector3(-23.5, 0, -19.3)   # 버드나무 길로 들어온 자리
const ARRIVE_CH2 := Vector3(0.8, 0, -25.5)     # 돌고개로 들어온 자리
const ARRIVE_CH3 := Vector3(23.0, 0, -15.0)    # 갈대 나루로 들어온 자리
const ROOM_C := Vector3(80, 0, 0)              # 내 집 방 안 (마을 밖 멀리)
const ROOM_SIZE := Vector3(7.0, 3.0, 5.4)
# 빈 집터: [자리, 이사 올 이야기] (ch1 흥부네, ch2 오누이, ch3 토끼·자라, 나머지는 다음 이야기)
const LOTS := [[Vector3(-20, 0, -6), "ch1"], [Vector3(-9, 0, -21), "ch2"], [Vector3(11, 0, -21), "ch3"], [Vector3(-18, 0, 10), ""], [Vector3(17, 0, 16), ""]]
const LOT_SIZE := Vector2(6.0, 4.6)

var met_granny := false
var granny_hint := 0
var tales := {}            # 끝낸 이야기 {"ch1": true, ...} (각 장의 저장에서 읽어요)
var lot_tags: Array = []
var room_walls: Array = []  # [벽 메시, 바깥 방향]
var zoom_before := 1.0

func chapter_id() -> String:
	return "home"

func state_section() -> String:
	return "home"

func chapter_state() -> Dictionary:
	return {"met": met_granny, "hint": granny_hint}

func restore_chapter_state(d: Dictionary) -> void:
	met_granny = d.get("met", false)
	granny_hint = d.get("hint", 0)

# 집 마을엔 개울이 없어요 (개울 소리와 풀 자리 계산이 멀리 가도록)
func creek_z(_x: float) -> float:
	return 9999.0

func arrive_from(from: String) -> void:
	var at := Vector3.ZERO
	var yaw := 0.0
	match from:
		"ch1":
			# 마을 안쪽(남동쪽)을 보고 서요
			at = ARRIVE_CH1
			yaw = -PI * 0.75
		"ch2":
			at = ARRIVE_CH2
			yaw = PI
		"ch3":
			at = ARRIVE_CH3
			yaw = PI * 0.75
		_:
			return
	player.position = at + Vector3(0, 0.3, 0)
	cam_yaw = yaw
	cam_yaw_target = yaw

# ---------- 끝낸 이야기 세기 (각 장의 저장을 읽기만 해요) ----------

func read_tales() -> void:
	tales = {}
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) != OK:
		return
	if not (cf.get_value("ch1", "endings", []) as Array).is_empty():
		tales["ch1"] = true
	var c2: Dictionary = cf.get_value("ch2_state", "data", {})
	if int(c2.get("quest", 0)) >= 10:
		tales["ch2"] = true
	var c3: Dictionary = cf.get_value("ch3_state", "data", {})
	if not (cf.get_value("ch3", "endings", []) as Array).is_empty() or str(c3.get("ending", "")) != "":
		tales["ch3"] = true

func tales_count() -> int:
	return tales.size()

# ---------- 짓기 ----------

func build_chapter() -> void:
	read_tales()
	make_surface_materials()
	make_light_and_sky()
	splat_rect = Rect2(-45, -45, 90, 90)
	var full := HOME_HALF * 2.0
	var none := Color(0, 0, 0, 0)
	var ground_col := add_solid(Vector3(0, -0.5, 0), Vector3(full + 20.0, 1, full + 20.0), Color(0.45, 0.7, 0.35))
	(ground_col.get_parent().get_child(0) as MeshInstance3D).material_override = ground_mat
	add_solid(Vector3(0, 2, -HOME_HALF), Vector3(full, 8, 1), none)
	add_solid(Vector3(0, 2, HOME_HALF), Vector3(full, 8, 1), none)
	add_solid(Vector3(-HOME_HALF, 2, 0), Vector3(1, 8, full), none)
	add_solid(Vector3(HOME_HALF, 2, 0), Vector3(1, 8, full), none)
	make_home_paths()
	make_my_house()
	make_granny_house()
	make_village_tree()
	make_lots()
	make_roads()
	make_small_pond()
	var r := RandomNumberGenerator.new()
	r.seed = 21
	make_home_border(r)
	make_home_decor(r)
	make_home_grass(r)
	make_clouds(r)
	add_ridge_ring(150.0, 40.0, 10.0, 24.0, Color(0.3, 0.5, 0.28), Color(0.42, 0.6, 0.36), 23)
	make_room()
	make_npc("storyteller", tr("이야기꾼 할머니"), Color.WHITE, GRANNY_POS, 1.0, true)
	npcs["storyteller"].rotation.y = -0.5

func after_ui() -> void:
	player.position = ARRIVE_CH1 + Vector3(0, 0.3, 0)
	cam_yaw = -PI * 0.75
	cam_yaw_target = cam_yaw

func start_chapter() -> void:
	update_lots()
	if in_room():
		cam_zoom = 0.6
		cam_zoom_target = 0.6
	if resumed and met_granny:
		show_card(tr("이야기골\n집 마을에 돌아왔어요."), 0.6, 1.6, Callable())
		return
	show_card(tr("이야기골\n\n옛이야기가 돌아와 쉬는 작은 마을.\n정자나무 아래에서\n이야기꾼 할머니가 기다리고 있어요."), 1.0, 5.0, func():
		if not walk_hint_seen:
			show_walk_hint())

func make_home_paths() -> void:
	# 서북 버드나무 길 (1장), 북쪽 돌고개 (2장), 동북 갈대 나루 (3장), 남쪽 안개 숲길 (닫힘)
	make_dirt_path([Vector2(-30.0, -27.5), Vector2(-25.0, -21.5), Vector2(-18.0, -16.0), Vector2(-11.0, -10.0), Vector2(-5.0, -6.5), Vector2(-1.0, -5.5)], 2.4, 2.0)
	make_dirt_path([Vector2(0.5, -6.0), Vector2(1.2, -12.0), Vector2(0.4, -19.0), Vector2(1.0, -26.0), Vector2(0.5, -33.5)], 2.2, 3.0)
	make_dirt_path([Vector2(2.5, -5.5), Vector2(8.0, -8.5), Vector2(14.0, -12.0), Vector2(20.0, -16.5), Vector2(26.5, -21.5), Vector2(30.5, -25.0)], 2.2, 4.0)
	# 정자나무에서 내 집 마당으로, 그리고 마당 옆을 돌아 남쪽 안개 길로
	make_dirt_path([Vector2(0.0, -0.5), Vector2(0.6, 4.0), Vector2(-0.2, 8.5), Vector2(0.2, 11.8)], 2.0, 5.0)
	make_dirt_path([Vector2(3.8, 12.0), Vector2(6.2, 16.0), Vector2(5.6, 21.0), Vector2(2.6, 25.5), Vector2(0.6, 30.0), Vector2(0.4, 34.0)], 1.8, 6.0)
	# 할머니 집으로
	make_dirt_path([Vector2(3.0, -1.0), Vector2(7.5, 0.6), Vector2(12.0, 3.6), Vector2(15.5, 5.6)], 1.8, 7.0)

func paint_ground_splat() -> void:
	for pl in path_lines:
		var line: Array = pl[0]
		var w: float = pl[1]
		for i in line.size():
			var p: Vector2 = line[i]
			splat_stamp(splat_r, p.x, p.y, w * 0.2, w * 0.72)
	# 내 집 마당, 할머니네 마당, 정자나무 그늘은 흙이 드러나요
	for yard in [Rect2(-5.0, 9.5, 10.0, 6.0), Rect2(12.0, 3.0, 10.0, 4.5), Rect2(-5.5, -6.5, 10.0, 7.5)]:
		var y := 0.0
		while y <= yard.size.y:
			var x := 0.0
			while x <= yard.size.x:
				splat_stamp(splat_r, yard.position.x + x, yard.position.y + y, 0.6, 2.2, 0.55)
				x += 1.2
			y += 1.2
	for i in 40:
		var a := TAU * i / 40.0
		splat_stamp(splat_g, POND_HOME.x + cos(a) * 4.6, POND_HOME.z + sin(a) * 3.2, 0.4, 1.4)

# 주인공 집: 처음엔 허름한 초가 (1장 흥부네처럼 낡고 기운 집)
func make_my_house() -> void:
	var h := make_house(HOUSE_POS, Vector3(4.5, 2.8, 3.5), Color(0.8, 0.74, 0.64), Color(0.6, 0.53, 0.38), "thatch")
	make_hut_shabby(h)
	h.rotation.y = PI
	# 쓰러진 싸리 울타리
	var fence := []
	for i in 9:
		var x := -4.6 + i * 0.55
		var lean := 0.0 if i % 3 != 1 else 28.0
		fence.append([Vector3(x, 0.45, HOUSE_POS.z - 3.6), Vector3(0.07, 0.9, 0.07), Color(0.52, 0.42, 0.3), Vector3(lean, 0, 0)])
	for i in 6:
		var x2 := 2.0 + i * 0.5
		fence.append([Vector3(x2, 0.12, HOUSE_POS.z - 3.9 - i * 0.05), Vector3(0.07, 0.07, 0.9), Color(0.5, 0.4, 0.28), Vector3(0, 12.0 * i, 0)])
	add_blobs(self, fence)
	var door := make_spot(HOUSE_POS + Vector3(0, 0, -2.6), "door", "in", "", true)
	add_tag(door, tr("내 집"), 3.6)

func make_granny_house() -> void:
	make_house(GRANNY_HOUSE, Vector3(4.5, 2.8, 3.5), Color(0.93, 0.89, 0.8), Color(0.74, 0.64, 0.42), "thatch")
	var r := RandomNumberGenerator.new()
	r.seed = 5
	make_jangdok(GRANNY_HOUSE + Vector3(3.6, 0, 1.2), r)
	make_flowers(GRANNY_HOUSE + Vector3(-3.2, 0, 2.6), r)
	make_laundry(GRANNY_HOUSE + Vector3(-2.5, 0, 4.4), GRANNY_HOUSE + Vector3(2.0, 0, 4.6))

# 큰 정자나무: 이야기를 하나 끝낼 때마다 등불이 하나씩 켜져요 (자리 다섯)
func make_village_tree() -> void:
	make_tree(TREE_POS, "Broad0")
	var tree := get_child(get_child_count() - 1) as Node3D
	tree.scale = Vector3(1.9, 1.7, 1.9)
	make_bench(TREE_POS + Vector3(2.6, 0, 2.0), -0.4)
	var well := Node3D.new()
	well.position = TREE_POS + Vector3(-5.0, 0, 3.2)
	add_child(well)
	make_well_visual(well)
	add_solid(well.position + Vector3(0, 0.6, 0), Vector3(1.8, 1.2, 1.8), Color(0, 0, 0, 0))
	var rope_mat := make_color(Color(0.55, 0.42, 0.28))
	var lit := tales_count()
	for i in 5:
		var a := -0.4 + i * TAU / 5.0
		var p := TREE_POS + Vector3(cos(a) * 2.7, 2.7, sin(a) * 2.7)
		add_beam(self, rope_mat, p + Vector3(0, 0.25, 0), p + Vector3(0, 1.1, 0), 0.02, 0.02)
		if i < lit:
			add_lantern(self, p - Vector3(0, 0.28, 0))
			# 낮에도 잘 보이게 더 환하고 붉은 빛으로
			var lm: StandardMaterial3D = lantern_mats[lantern_mats.size() - 1][0]
			lm.albedo_color = Color(1.0, 0.72, 0.45)
			lm.emission = Color(2.6, 1.5, 0.7)
		else:
			# 아직 꺼진 등불: 빛바랜 종이 등
			add_box(self, Color(0.3, 0.2, 0.12), Vector3(0.28, 0.06, 0.28), p)
			add_ball(self, Color(0.56, 0.52, 0.47), 0.2, p - Vector3(0, 0.28, 0))
	var spot := make_spot(TREE_POS + Vector3(1.6, 0, 1.0), "look", "tree", "", true)
	add_tag(spot, tr("정자나무"), 5.4)

# 빈 집터: 돌 기단과 팻말
func make_lots() -> void:
	for li in LOTS.size():
		var c: Vector3 = LOTS[li][0]
		var r := RandomNumberGenerator.new()
		r.seed = 50 + li
		var stones := []
		var w := LOT_SIZE.x / 2.0
		var d := LOT_SIZE.y / 2.0
		var t := -1.0
		while t <= 1.0:
			for e in [[Vector3(t * w, 0, -d)], [Vector3(t * w, 0, d)], [Vector3(-w, 0, t * d)], [Vector3(w, 0, t * d)]]:
				var p: Vector3 = c + e[0] + Vector3(r.randf_range(-0.1, 0.1), 0.12, r.randf_range(-0.1, 0.1))
				stones.append([p, Vector3(r.randf_range(0.5, 0.75), r.randf_range(0.22, 0.32), r.randf_range(0.45, 0.6)), stone_color(r)])
			t += 0.2
		# 주춧돌 네 개
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				stones.append([c + Vector3(sx * w * 0.55, 0.16, sz * d * 0.5), Vector3(0.6, 0.32, 0.6), stone_color(r)])
		add_blobs(self, stones, stone_blob_mat)
		house_rects.append(Rect2(c.x - w - 0.5, c.z - d - 0.5, LOT_SIZE.x + 1.0, LOT_SIZE.y + 1.0))
		# 팻말
		var sign := make_spot(c + Vector3(0, 0, d + 0.9), "look", "lot%d" % li, "", true)
		add_mcyl(sign, dark_wood_mat, 0.05, 0.06, 1.2, Vector3(0, 0.6, 0))
		add_mbox(sign, plank_mat, Vector3(1.1, 0.34, 0.06), Vector3(0, 1.15, 0))
		var lab := Label3D.new()
		lab.font = font
		lab.font_size = 30
		lab.modulate = Color(0.25, 0.14, 0.08)
		lab.outline_size = 0
		lab.pixel_size = 0.0034
		lab.position = Vector3(0, 1.15, 0.04)
		sign.add_child(lab)
		lot_tags.append(lab)

func lot_text(li: int) -> String:
	var tale: String = LOTS[li][1]
	if tale != "" and tales.has(tale):
		return tr("이사 올\n준비 중")
	return tr("빈 집터")

func update_lots() -> void:
	for li in lot_tags.size():
		(lot_tags[li] as Label3D).text = lot_text(li)

# 길 끝 이정표 세 개와 닫힌 안개 숲길
func make_roads() -> void:
	make_road_sign(Vector3(-27.6, 0, -22.4), "ch1", tr("버드나무 길\n(흥부네 마을)"), 0.75)
	make_road_sign(Vector3(2.8, 0, -29.5), "ch2", tr("돌고개\n(오누이 고갯길)"), 0.0)
	make_road_sign(Vector3(26.8, 0, -18.2), "ch3", tr("갈대 나루\n(바닷가 마을)"), -0.75)
	make_road_sign(Vector3(3.0, 0, 28.5), "fog", tr("안개 숲길"), PI)
	make_jangseung(Vector3(-31.0, 0, -24.0), false)
	make_jangseung(Vector3(-27.0, 0, -29.5), true)
	# 버드나무 길: 늘어진 나무를 길가에 (버드나무 모델 대신 잎이 둥근 나무)
	for p in [Vector3(-22.5, 0, -24.0), Vector3(-16.0, 0, -19.5), Vector3(-25.0, 0, -15.5), Vector3(-12.5, 0, -15.0)]:
		make_tree(p, "Broad1")
	# 갈대 나루: 갈대 덤불
	var reeds := []
	var r := RandomNumberGenerator.new()
	r.seed = 9
	for i in 70:
		var base := Vector3(r.randf_range(23.0, 33.0), 0, r.randf_range(-30.0, -24.0))
		if absf(base.x - 30.0) < 1.6 and base.z > -27.0:
			continue
		var hgt := r.randf_range(0.9, 1.6)
		reeds.append([base + Vector3(0, hgt * 0.5, 0), Vector3(0.05, hgt, 0.05), Color(0.6, 0.66, 0.34), Vector3(r.randf_range(-12, 12), 0, r.randf_range(-12, 12))])
		if i % 2 == 0:
			reeds.append([base + Vector3(0, hgt, 0), Vector3(0.1, 0.32, 0.1), Color(0.78, 0.7, 0.5), Vector3.ZERO])
	add_blobs(self, reeds)
	# 남쪽 안개: 길을 덮은 뽀얀 안개와 막힌 길
	var fog_mat := StandardMaterial3D.new()
	fog_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fog_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fog_mat.albedo_color = Color(0.95, 0.96, 1.0, 0.55)
	var fog := []
	for i in 26:
		var p := Vector3(r.randf_range(-9.0, 9.0), r.randf_range(0.6, 2.4), r.randf_range(30.5, 34.5))
		fog.append([p, Vector3(r.randf_range(2.6, 4.2), r.randf_range(1.4, 2.4), r.randf_range(2.0, 3.0)), Color(1, 1, 1)])
	var fmi := add_blobs(self, fog, fog_mat)
	fmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sway_items.append([fmi, fmi.position, 0, 1.3, 0.5])
	add_solid(Vector3(0, 2, 31.0), Vector3(16, 8, 1), Color(0, 0, 0, 0))

func make_road_sign(pos: Vector3, id: String, text: String, rot_y: float) -> void:
	var sign := make_spot(pos, "gate", id, "", true)
	sign.rotation.y = rot_y
	add_mcyl(sign, dark_wood_mat, 0.07, 0.08, 1.9, Vector3(0, 0.95, 0))
	var board := add_mbox(sign, plank_mat, Vector3(1.7, 0.5, 0.08), Vector3(0, 1.6, 0))
	board.rotation.z = -0.04
	var lab := Label3D.new()
	lab.text = text
	lab.font = font
	lab.font_size = 34
	lab.modulate = Color(0.25, 0.14, 0.08)
	lab.outline_size = 0
	lab.position = Vector3(0, 1.6, 0.05)
	lab.pixel_size = 0.0034
	sign.add_child(lab)

func make_small_pond() -> void:
	var c := POND_HOME
	flat_ellipse(c, 3.8, 2.4, 0.06, water_material(1, Vector4(c.x, c.z, 3.8, 2.4), Color(0.12, 0.36, 0.52), Color(0.42, 0.68, 0.72)))
	var r := RandomNumberGenerator.new()
	r.seed = 12
	var stones := []
	var a := 0.0
	while a < TAU:
		a += r.randf_range(0.22, 0.34)
		stones.append([c + Vector3(cos(a) * 4.1, 0.08, sin(a) * 2.7), Vector3(r.randf_range(0.5, 0.9), r.randf_range(0.28, 0.45), r.randf_range(0.4, 0.7)), stone_color(r)])
	add_blobs(self, stones, stone_blob_mat)
	add_solid(c + Vector3(0, 0.5, 0), Vector3(6.4, 1.0, 3.8), Color(0, 0, 0, 0))
	house_rects.append(Rect2(c.x - 4.8, c.z - 3.4, 9.6, 6.8))

func make_home_border(r: RandomNumberGenerator) -> void:
	var side := HOME_HALF + 2.5
	var t := -side
	while t <= side:
		for edge in 4:
			var p := Vector3.ZERO
			match edge:
				0: p = Vector3(t, 0, -side)
				1: p = Vector3(t, 0, side)
				2: p = Vector3(-side, 0, t)
				3: p = Vector3(side, 0, t)
			p += Vector3(r.randf_range(-1.5, 1.5), 0, r.randf_range(-1.5, 1.5))
			# 길이 나가는 자리는 비워요 (북, 남)
			if (edge == 0 or edge == 1) and absf(p.x) < 4.0:
				continue
			make_tree(p)
			if r.randf() < 0.45:
				make_tree(p + Vector3(r.randf_range(-3, 3), 0, r.randf_range(-3, 3)) + p.normalized() * 4.0)
		t += r.randf_range(5.0, 7.0)
	# 안쪽 띄엄띄엄 나무
	for p in [Vector3(-28, 0, 4), Vector3(-26, 0, 22), Vector3(-12, 0, 26), Vector3(24, 0, 24), Vector3(29, 0, 8), Vector3(14, 0, -30), Vector3(-17, 0, -30), Vector3(28, 0, -4)]:
		make_tree(p)

func make_home_decor(r: RandomNumberGenerator) -> void:
	make_flowers(Vector3(-4.5, 0, 9.0), r)
	make_flowers(Vector3(6.5, 0, -3.5), r)
	make_firewood(HOUSE_POS + Vector3(3.4, 0, 0.8))
	make_basket(TREE_POS + Vector3(4.2, 0, 3.4), 0.9, Color(0.95, 0.6, 0.25))
	for p in [Vector3(-8, 0, 3), Vector3(8, 0, 9), Vector3(-24, 0, -4), Vector3(24, 0, 2)]:
		make_rock(p, Vector3(1.2, 0.7, 1.0), r)

func make_home_grass(r: RandomNumberGenerator) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = make_tuft_mesh()
	var keep_out := house_rects + [Rect2(-6.0, -7.0, 11.0, 9.0)]
	var spots := []
	var tries := 0
	var clump := Vector2.ZERO
	var grass_n := 600 if light_mode else 1100
	while spots.size() < grass_n and tries < grass_n * 4:
		tries += 1
		if tries % 5 == 1 or spots.is_empty():
			clump = Vector2(r.randf_range(-33, 33), r.randf_range(-33, 33))
		var p := clump + Vector2(r.randf_range(-0.9, 0.9), r.randf_range(-0.9, 0.9))
		var ok := true
		var jag := r.randf_range(-0.7, 0.5)
		for k in keep_out:
			if (k as Rect2).grow(jag).has_point(p):
				ok = false
				break
		if ok and near_path(p, -0.1 + jag * 0.5):
			ok = false
		if ok:
			spots.append(p)
	mm.instance_count = spots.size()
	for i in spots.size():
		var p: Vector2 = spots[i]
		var sc := r.randf_range(0.6, 1.25)
		var basis := Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3(sc, sc * r.randf_range(0.8, 1.3), sc))
		mm.set_instance_transform(i, Transform3D(basis, Vector3(p.x, 0.0, p.y)))
		mm.set_instance_color(i, Color(0.42, 0.66, 0.32).lerp(Color(0.62, 0.82, 0.42), r.randf()))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = grass_material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var wild := []
	var palette := [Color(1.0, 0.8, 0.85), Color(1.0, 0.97, 0.8), Color(0.85, 0.8, 1.0), Color(1.0, 0.9, 0.45), Color(1, 1, 1)]
	for i in 90:
		var p: Vector2 = spots[r.randi() % spots.size()]
		wild.append([Vector3(p.x, 0.13, p.y), Vector3(0.13, 0.1, 0.13), palette[r.randi() % palette.size()]])
	var wmi := add_blobs(self, wild)
	wmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

# ---------- 할 일 ----------

func update_quest_text() -> void:
	var t := ""
	if not met_granny:
		t = tr("정자나무 아래 이야기꾼 할머니께 인사하기")
	elif not tales.has("ch1"):
		t = tr("서북쪽 버드나무 길 이정표로 흥부네 마을 가기")
	else:
		t = tr("이야기골을 둘러보기. 이야기를 끝낼 때마다 정자나무 등불이 켜져요")
	quest_label.text = tr("할 일: %s\n엽전 %d냥 | 되찾은 이야기 %d/3") % [t, shown_coins, tales_count()]

# ---------- 말 걸기와 살펴보기 ----------

func action_text(t: Dictionary) -> String:
	if t["kind"] == "look":
		return tr("살펴보기")
	if t["kind"] == "door":
		return tr("들어가기") if t["id"] == "in" else tr("나가기")
	if t["kind"] == "room":
		return {"bed": tr("잠자기"), "shelf": tr("이야기 책장 보기"), "chest": tr("살펴보기")}.get(t["id"], tr("살펴보기"))
	return super.action_text(t)

func on_action() -> void:
	if current_thing.is_empty() or is_busy():
		return
	if current_thing["kind"] == "look":
		sfx("tap")
		look_at_thing(current_thing["id"])
		return
	if current_thing["kind"] == "door":
		sfx("tap")
		if current_thing["id"] == "in":
			enter_room()
		else:
			leave_room()
		return
	if current_thing["kind"] == "room":
		sfx("tap")
		use_room(current_thing["id"])
		return
	super.on_action()

func talk_to(id: String) -> void:
	if id == "storyteller":
		talk_granny()

func talk_granny() -> void:
	var g := tr("이야기꾼 할머니")
	if not met_granny:
		say([
			[g, tr("어서 오너라. 여기는 이야기골, 잊혀 가던 옛이야기가 돌아와 쉬는 마을이란다.")],
			[g, tr("저 허름한 초가가 이제 네 집이야. 이야기를 하나 되찾을 때마다 이 정자나무에 등불이 켜지고, 빈 집터에 이웃이 이사 온단다.")],
			[g, tr("서북쪽 버드나무 길을 따라가면 흥부네 마을이야. 이 책을 들고 다녀오렴.")],
		], func():
			met_granny = true
			earn(10)
			float_text(tr("이야기 책을 받았어요!"), get_viewport().get_visible_rect().size * Vector2(0.5, 0.4), Color(1.0, 0.85, 0.4))
			update_quest_text()
			save_progress())
		return
	var lines := granny_hints()
	var line: String = lines[granny_hint % lines.size()]
	granny_hint += 1
	say([[g, line]], func(): save_progress())

# 할머니가 들려주는 말: 아직 못 본 이야기와 결말 힌트
func granny_hints() -> Array:
	var out := []
	var cf := ConfigFile.new()
	cf.load(SAVE_PATH)
	var e1: Array = cf.get_value("ch1", "endings", [])
	var e3: Array = cf.get_value("ch3", "endings", [])
	if not tales.has("ch1"):
		out.append(tr("흥부네 박은 아직 다 안 탔니? 버드나무 길 끝 장승을 지나면 바로란다."))
		out.append(tr("흥부네 마을 사람들은 일손이 늘 모자라. 품을 팔면 엽전도 모인단다."))
	elif e1.size() < ENDING_COUNT:
		out.append(tr("흥부 이야기는 끝이 하나가 아니란다. 엽전을 넉넉히 모으면 다른 길이 보일지도 모르지. (흥부와 놀부 엔딩 %d/%d)") % [e1.size(), ENDING_COUNT])
	if tales.has("ch1") and not tales.has("ch2"):
		out.append(tr("흥부네 남쪽 이정표에서 고갯길로 가면 해와 달이 된 오누이 이야기가 있단다. 호랑이를 조심하렴."))
	if tales.has("ch2") and not tales.has("ch3"):
		out.append(tr("오누이 고갯길 북쪽 끝에서 바닷가로 내려가면 별주부 이야기가 기다린단다."))
	if tales.has("ch3") and e3.size() < 3:
		out.append(tr("용왕님 이야기도 끝이 여럿이란다. 자라에게 무엇을 주느냐에 따라 달라지지. (별주부전 엔딩 %d/3)") % e3.size())
	out.append(tr("북쪽 돌고개를 넘으면 오누이 고갯길, 동북쪽 갈대 나루에서 배를 타면 바닷가 마을이란다."))
	out.append(tr("집에 들어가 푹 쉬어 가렴. 책장에는 네가 모은 이야기들이 꽂혀 있지."))
	out.append(tr("이야기를 다 들려주고 나면, 저 빈 집터들도 북적북적해질 게다."))
	return out

func look_at_thing(id: String) -> void:
	if id == "house":
		say([["", tr("지붕은 내려앉고 벽엔 금이 갔다. 그래도 오늘부터 내 집이다.")],
			["", tr("(엽전을 모으고 이야기를 되찾으면 집을 고칠 수 있게 될 거예요. 준비 중)")]], Callable())
	elif id == "tree":
		var n := tales_count()
		if n == 0:
			say([["", tr("큰 정자나무 가지에 꺼진 종이 등 다섯 개가 매달려 있다. 이야기를 되찾으면 하나씩 켜진대요.")]], Callable())
		else:
			say([["", tr("정자나무에 등불 %d개가 환하게 켜져 있다. 되찾은 이야기 하나에 등불 하나.") % n]], Callable())
	elif id.begins_with("lot"):
		var li := int(id.substr(3))
		var tale: String = LOTS[li][1]
		var names := {"ch1": tr("흥부네 식구"), "ch2": tr("오누이"), "ch3": tr("토끼와 자라")}
		if tale != "" and tales.has(tale):
			say([["", tr("빈 집터. 팻말에 “%s 이사 올 자리”라고 새로 적혀 있다. (이사는 준비 중)") % names[tale]]], Callable())
		else:
			say([["", tr("돌 기단만 남은 빈 집터. 이야기를 되찾으면 누군가 이사 올 자리래요.")]], Callable())

func on_gate() -> void:
	var id: String = current_thing.get("id", "")
	match id:
		"ch1":
			ask("", tr("버드나무 길을 따라 흥부네 마을로 갈까요?\n(이야기골은 저장돼요.)"), [tr("흥부네 마을로 가기"), tr("더 둘러볼래요")], func(i: int):
				if i == 0:
					go_to_chapter("ch1"))
		"ch2":
			ask("", tr("돌고개를 넘어 오누이 고갯길로 갈까요?\n(이야기골은 저장돼요.)"), [tr("오누이 고갯길로 가기"), tr("더 둘러볼래요")], func(i: int):
				if i == 0:
					go_to_chapter("ch2"))
		"ch3":
			ask("", tr("갈대 나루에서 배를 타고 바닷가 마을로 갈까요?\n(이야기골은 저장돼요.)"), [tr("바닷가 마을로 가기"), tr("더 둘러볼래요")], func(i: int):
				if i == 0:
					go_to_chapter("ch3"))
		_:
			say([["", tr("아직 이 길은 안개에 덮여 있어요. 언젠가 새 이야기가 열릴 곳이래요.")]], Callable())

# ---------- 내 집 방 안 ----------

func weather_sheltered() -> bool:
	return in_room()

func in_room() -> bool:
	return player != null and player.position.x > ROOM_C.x - 20.0

func make_room() -> void:
	var w := ROOM_SIZE.x
	var h := ROOM_SIZE.y
	var d := ROOM_SIZE.z
	# 바닥: 장판 방(누런 장판) + 방 밖은 어둑한 흙마당
	var outside := add_solid(ROOM_C + Vector3(0, -0.5, 0), Vector3(40, 1, 40), Color(0.22, 0.18, 0.14))
	(outside.get_parent().get_child(0) as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var floor_mi := add_box(self, Color(0.86, 0.66, 0.36), Vector3(w, 0.06, d), ROOM_C + Vector3(0, 0.03, 0))
	floor_mi.material_override = glossy_mat(Color(0.86, 0.66, 0.36))
	var wall_mat := plaster_mat(Color(0.86, 0.8, 0.68))
	for wd in [[Vector3(0, h / 2.0, -d / 2.0), Vector3(w + 0.3, h, 0.15), Vector3(0, 0, -1)],
			[Vector3(0, h / 2.0, d / 2.0), Vector3(w + 0.3, h, 0.15), Vector3(0, 0, 1)],
			[Vector3(-w / 2.0, h / 2.0, 0), Vector3(0.15, h, d), Vector3(-1, 0, 0)],
			[Vector3(w / 2.0, h / 2.0, 0), Vector3(0.15, h, d), Vector3(1, 0, 0)]]:
		var col := add_solid(ROOM_C + wd[0], wd[1], Color(0.86, 0.8, 0.68))
		var holder := col.get_parent() as Node3D
		var mi := holder.get_child(0) as MeshInstance3D
		mi.material_override = wall_mat
		# 아래 걸레받이 나무
		add_mbox(holder, dark_wood_mat, Vector3(wd[1].x + 0.02, 0.18, wd[1].z + 0.02), ROOM_C + wd[0] + Vector3(0, -h / 2.0 + 0.09, 0) - holder.position)
		add_mbox(holder, dark_wood_mat, Vector3(wd[1].x + 0.04, 0.14, wd[1].z + 0.04), ROOM_C + wd[0] + Vector3(0, h / 2.0 - 0.07, 0) - holder.position)
		room_walls.append([holder, wd[2]])
	# 북쪽 벽 창문 (문살)
	add_lattice(room_walls[0][0], Vector3(1.6, 1.5 - h / 2.0, 0.1), 1.2, 0.9, 0.0)
	# 이부자리: 요와 이불, 베개 (서쪽)
	var bed := make_spot(ROOM_C + Vector3(-2.3, 0, -0.6), "room", "bed", "", true)
	add_box(bed, Color(0.92, 0.88, 0.8), Vector3(1.4, 0.12, 2.2), Vector3(0, 0.08, 0))
	add_box(bed, Color(0.78, 0.36, 0.38), Vector3(1.36, 0.14, 1.5), Vector3(0, 0.2, 0.3))
	add_box(bed, Color(0.95, 0.82, 0.4), Vector3(1.36, 0.02, 0.2), Vector3(0, 0.28, -0.35))
	add_blobs(bed, [[Vector3(0, 0.24, -0.82), Vector3(0.7, 0.2, 0.32), Color(0.4, 0.55, 0.78)]])
	# 이야기 책장 (북동쪽)
	var shelf := make_spot(ROOM_C + Vector3(2.4, 0, -1.9), "room", "shelf", "", true)
	add_mbox(shelf, dark_wood_mat, Vector3(1.5, 1.7, 0.45), Vector3(0, 0.85, 0))
	var books := []
	var r := RandomNumberGenerator.new()
	r.seed = 4
	var lit := tales_count()
	for row in 3:
		var x := -0.6
		while x < 0.6:
			var bw := r.randf_range(0.07, 0.13)
			var c: Color = [Color(0.7, 0.25, 0.22), Color(0.25, 0.4, 0.62), Color(0.85, 0.7, 0.3), Color(0.3, 0.55, 0.35), Color(0.9, 0.88, 0.8)][r.randi() % 5]
			if row == 2 and x > 0.0:
				break
			books.append([Vector3(x + bw / 2.0, 0.42 + row * 0.5, 0.18), Vector3(bw, r.randf_range(0.3, 0.4), 0.3), c])
			x += bw + 0.01
		add_mbox(shelf, plank_mat, Vector3(1.4, 0.04, 0.4), Vector3(0, 0.22 + row * 0.5, 0.0))
	add_blobs(shelf, books)
	# 반닫이(궤) 와 호롱불
	var chest := make_spot(ROOM_C + Vector3(0.6, 0, -2.2), "room", "chest", "", true)
	add_mbox(chest, wood_mat, Vector3(1.2, 0.7, 0.5), Vector3(0, 0.35, 0.0))
	for bx in [-0.4, 0.0, 0.4]:
		add_box(chest, Color(0.75, 0.6, 0.25), Vector3(0.12, 0.12, 0.02), Vector3(bx, 0.45, 0.26))
	add_lantern(chest, Vector3(0.35, 0.72, 0))
	# 밥상과 방석
	add_mcyl(self, wood_mat, 0.5, 0.45, 0.06, ROOM_C + Vector3(1.2, 0.34, 0.6))
	for lx in [-0.3, 0.3]:
		for lz in [-0.3, 0.3]:
			add_mbox(self, dark_wood_mat, Vector3(0.06, 0.32, 0.06), ROOM_C + Vector3(1.2 + lx, 0.16, 0.6 + lz))
	add_blobs(self, [[ROOM_C + Vector3(1.2, 0.42, 0.6), Vector3(0.22, 0.1, 0.22), Color(0.96, 0.95, 0.9)],
		[ROOM_C + Vector3(0.1, 0.05, 0.9), Vector3(0.7, 0.08, 0.7), Color(0.55, 0.3, 0.45)]])
	# 문 (남쪽 벽 가운데, 안쪽에서 나가기)
	add_door(room_walls[1][0], Vector3(0, 0.95 - h / 2.0, -0.09), 1.0, 1.9)
	make_spot(ROOM_C + Vector3(0, 0, d / 2.0 - 0.7), "door", "out", "", true)
	var lamp := OmniLight3D.new()
	lamp.position = ROOM_C + Vector3(0, 2.2, 0)
	lamp.light_color = Color(1.0, 0.85, 0.6)
	lamp.light_energy = 0.8
	lamp.omni_range = 6.0
	add_child(lamp)

func enter_room() -> void:
	zoom_before = cam_zoom_target
	show_card(tr("삐걱, 문을 열고 들어갔어요."), 1.0, 0.6, Callable())
	player.position = ROOM_C + Vector3(0, 0.3, ROOM_SIZE.z / 2.0 - 1.4)
	player.velocity = Vector3.ZERO
	cam_yaw = 0.0
	cam_yaw_target = 0.0
	cam_zoom = 0.6
	cam_zoom_target = 0.6
	save_progress()

func leave_room() -> void:
	show_card(tr("마당으로 나왔어요."), 1.0, 0.5, Callable())
	player.position = HOUSE_POS + Vector3(0, 0.3, -3.6)
	player.velocity = Vector3.ZERO
	# 마당에서 내 집을 바라보게 (뒤쪽에서 보면 카메라가 지붕에 묻혀요)
	cam_yaw = PI
	cam_yaw_target = PI
	cam_zoom = maxf(zoom_before, 0.9)
	cam_zoom_target = cam_zoom
	save_progress()

func use_room(id: String) -> void:
	match id:
		"bed":
			ask("", tr("이부자리에 누워 한숨 잘까요?"), [tr("잠자기"), tr("그만두기")], func(i: int):
				if i == 0:
					show_card(tr("포근한 이불 속에서\n옛이야기 꿈을 꾸었어요.\n\n개운하게 일어났어요!"), 1.0, 2.2, func(): save_progress()))
		"shelf":
			say([["", tr("이야기 책장. 되찾은 이야기 %d권과 도감이 꽂혀 있다.") % tales_count()]], func(): open_book())
		_:
			say([["", tr("낡은 반닫이. 안에는 아직 아무것도 없다. (엽전을 모으면 집을 고칠 수 있게 될 거예요. 준비 중)")]], Callable())

# 카메라와 방 사이를 가리는 벽은 숨겨요 (부딪힘은 그대로)
func _process(delta: float) -> void:
	super._process(delta)
	if cam == null or room_walls.is_empty():
		return
	var inside := in_room()
	for rw in room_walls:
		var holder: Node3D = rw[0]
		var out_dir: Vector3 = rw[1]
		var wall_pos := ROOM_C + out_dir * Vector3(ROOM_SIZE.x / 2.0, 0, ROOM_SIZE.z / 2.0)
		var show := not inside or (cam.position - wall_pos).dot(out_dir) < 0.0
		for c in holder.get_children():
			if c is MeshInstance3D:
				(c as MeshInstance3D).visible = show
