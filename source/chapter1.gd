extends "res://core.gd"

# 1장: 흥부와 놀부. 맵 배치, 이야기 진행, 1장 미니게임.

var treasure_pos: Array = []   # 박을 탄 자리 (쌀, 비단, 금은보화 순서)

func chapter_id() -> String:
	return "ch1"

func chapter_state() -> Dictionary:
	var vis := []
	for t in things:
		vis.append((t["node"] as Node3D).visible)
	return {
		"quest": quest, "herbs_found": herbs_found, "gourds_done": gourds_done, "pieces_found": pieces_found,
		"mischief": mischief, "mischief_done": mischief_done, "laundry_found": laundry_found,
		"hide_state": hide_state, "hiders_found": hiders_found, "axe_done": axe_done, "axe_lied": axe_lied,
		"helped_nolbu": helped_nolbu, "ending_id": ending_id, "treasure_pos": treasure_pos,
		"things_vis": vis,
	}

func restore_chapter_state(d: Dictionary) -> void:
	quest = d.get("quest", Q_NOLBU)
	herbs_found = d.get("herbs_found", 0)
	gourds_done = d.get("gourds_done", 0)
	pieces_found = d.get("pieces_found", 0)
	mischief = d.get("mischief", {})
	mischief_done = d.get("mischief_done", 0)
	laundry_found = d.get("laundry_found", 0)
	hide_state = d.get("hide_state", 0)
	hiders_found = d.get("hiders_found", 0)
	axe_done = d.get("axe_done", false)
	axe_lied = d.get("axe_lied", false)
	helped_nolbu = d.get("helped_nolbu", false)
	ending_id = d.get("ending_id", "")
	# 줍거나 나타난 물건들 (조각, 약초, 박, 빨래, 숨은 동생, 덤불)
	var vis: Array = d.get("things_vis", [])
	if vis.size() == things.size():
		for i in things.size():
			var t: Dictionary = things[i]
			var node: Node3D = t["node"]
			node.visible = vis[i]
			if t["kind"] == "bush" and not node.visible and bush_col != null:
				bush_col.disabled = true
	# 이야기에 따라 바뀐 마을 모습
	if quest == Q_RICE:
		(npcs["heungbu"] as Node3D).position = Vector3(12.2, 0, 9.8)
	if nolbu_gourd != null:
		nolbu_gourd.visible = quest == Q_NOLBU2
	(npcs["dokkaebi"] as Node3D).visible = quest >= Q_DOKKAEBI
	(npcs["sansin"] as Node3D).visible = axe_done
	if mischief.get("ong", 0) == 2:
		for c in ong_cracks:
			(c as Node3D).visible = false
	var tp: Array = d.get("treasure_pos", [])
	treasure_pos = []
	for i in tp.size():
		treasure_pos.append(tp[i])
		spawn_treasure(i, tp[i])
	# 계절이 바뀌는 사이에 멈췄다면 박이 열린 뒤로 이어가요
	if quest == Q_SEASON or quest == Q_SEED:
		after_seed()

func build_chapter() -> void:
	load_south()
	make_world()
	make_village()
	make_forest()
	make_decor()

func after_ui() -> void:
	scatter_items()

func start_chapter() -> void:
	if resumed:
		show_card(tr("지난번 이야기에 이어서\n책장을 다시 펼쳐요..."), 0.6, 1.6, Callable())
		return
	show_card(tr("흥부와 놀부, 해와 달이 된 오누이...\n\n점점 잊혀 가는 옛이야기들이\n이 책 속에 잠들어 있어요.\n\n우리 이야기를 다시 세상에 들려줄\n첫 장을 펼쳐 볼까요?"), 1.0, 8.0, func():
		if not walk_hint_seen:
			show_walk_hint())
# 박: 뽀얀 둥근 몸통에 은은한 골, 꼭지, 덩굴과 하얀 박꽃
func make_gourd_visual(g: Node3D, c: Color, radius: float) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = int(g.position.x * 10.0 + g.position.z)
	var R := radius
	var body := [[Vector3(0, R * 0.9, 0), Vector3(2.0 * R, 1.8 * R, 2.0 * R), c]]
	for i in 8:
		var a := i * TAU / 8.0
		body.append([Vector3(cos(a) * R * 0.3, R * 0.9, sin(a) * R * 0.3), Vector3(R * 1.5, 1.74 * R, R * 1.5), c.lightened(0.07) if i % 2 == 0 else c.darkened(0.04)])
	body.append([Vector3(-R * 0.35, R * 1.35, R * 0.55), Vector3(R * 0.5, R * 0.35, R * 0.3), c.lightened(0.3)])
	add_blobs(g, body, blob_gloss())
	var stem := make_color(Color(0.45, 0.4, 0.2))
	var top := Vector3(0, R * 1.78, 0)
	add_beam(g, stem, top, top + Vector3(0.05, R * 0.22, 0.02), R * 0.09, R * 0.09)
	add_beam(g, stem, top + Vector3(0.05, R * 0.22, 0.02), top + Vector3(R * 0.22, R * 0.3, 0.06), R * 0.06, R * 0.06)
	var leaves := leaf_items(Vector3.ZERO, 5, R * 0.95, r, Color(0.3, 0.56, 0.24))
	for i in 2:
		var a := r.randf() * TAU
		leaves.append([Vector3(cos(a) * R * 1.4, 0.2, sin(a) * R * 1.4), Vector3(0.32, 0.08, 0.32) * R, Color(1, 1, 0.97)])
		leaves.append([Vector3(cos(a) * R * 1.4, 0.24, sin(a) * R * 1.4), Vector3(0.1, 0.06, 0.1) * R, Color(1.0, 0.92, 0.5)])
	add_blobs(g, leaves, null, true)
	var vine := make_color(Color(0.28, 0.48, 0.2))
	var prev := Vector3(0, 0.08, 0)
	for k in 6:
		var nxt := prev + Vector3(r.randf_range(0.2, 0.6), 0, r.randf_range(-0.5, 0.5)) * R
		nxt.y = 0.08
		add_beam(g, vine, prev, nxt, 0.06, 0.06)
		prev = nxt

# 처마 밑 제비 둥지: 진흙 사발 + 입 벌린 아기 제비 셋
func make_nest_visual(n: Node3D) -> void:
	var root := Node3D.new()
	# 흥부네 처마 밑, 앞쪽 왼편 기둥에 붙어 있어요
	root.position = Vector3(0.12, 1.98, -0.5)
	root.scale = Vector3(1.45, 1.45, 1.45)
	n.add_child(root)
	add_mbox(root, dark_wood_mat, Vector3(0.7, 0.06, 0.45), Vector3(0, -0.2, 0))
	var mud := []
	var r := RandomNumberGenerator.new()
	r.seed = 9
	for i in 12:
		var a := i * TAU / 12.0
		mud.append([Vector3(cos(a) * 0.24, r.randf_range(-0.04, 0.04), sin(a) * 0.17), Vector3(0.2, 0.17, 0.17), Color(0.55, 0.42, 0.28).lightened(r.randf() * 0.15)])
	mud.append([Vector3(0, -0.1, 0), Vector3(0.5, 0.18, 0.36), Color(0.5, 0.38, 0.25)])
	for i in 6:
		mud.append([Vector3(r.randf_range(-0.25, 0.25), 0.05, r.randf_range(-0.15, 0.15)), Vector3(0.3, 0.02, 0.02), Color(0.9, 0.78, 0.45), Vector3(0, r.randf_range(0, 180), r.randf_range(-20, 20))])
	for i in 3:
		var x := (i - 1) * 0.14
		mud.append([Vector3(x, 0.12, 0.02), Vector3(0.13, 0.13, 0.13), Color(0.15, 0.17, 0.28)])
		mud.append([Vector3(x, 0.09, 0.07), Vector3(0.08, 0.06, 0.04), Color(0.98, 0.95, 0.9)])
		mud.append([Vector3(x, 0.17, 0.1), Vector3(0.09, 0.03, 0.08), Color(1.0, 0.75, 0.2), Vector3(-25, 0, 0)])
		mud.append([Vector3(x, 0.14, 0.1), Vector3(0.08, 0.025, 0.07), Color(1.0, 0.6, 0.15), Vector3(20, 0, 0)])
	add_blobs(root, mud)

# 약초: 가는 줄기, 톱니 잎, 보랏빛 도라지꽃
func make_herb_visual(h: Node3D) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = int(h.position.x * 7.0 + h.position.z)
	var items := leaf_items(Vector3.ZERO, 6, 0.28, r, Color(0.26, 0.52, 0.24))
	var stem := make_color(Color(0.3, 0.5, 0.22))
	for i in 4:
		var a := i * TAU / 4.0 + r.randf() * 0.5
		var top := Vector3(cos(a) * 0.18, r.randf_range(0.55, 0.85), sin(a) * 0.18)
		add_beam(h, stem, Vector3(0, 0.02, 0), top, 0.035, 0.035)
		items.append([top * 0.55, Vector3(0.18, 0.04, 0.1), Color(0.34, 0.6, 0.28), Vector3(0, -rad_to_deg(a), 25)])
		var fc := Color(0.66, 0.45, 0.92) if i % 2 == 0 else Color(0.95, 0.5, 0.75)
		for k in 5:
			var b := k * TAU / 5.0
			items.append([top + Vector3(cos(b) * 0.07, 0.02, sin(b) * 0.07), Vector3(0.09, 0.05, 0.09), fc])
		items.append([top + Vector3(0, 0.04, 0), Vector3(0.05, 0.05, 0.05), Color(1.0, 0.95, 0.6)])
	add_blobs(h, items)
	# 뿌리 쪽 흙더미
	add_blobs(h, [[Vector3(0, 0.02, 0), Vector3(0.6, 0.12, 0.6), Color(0.45, 0.33, 0.22)]], null, true)

# 이야기 조각: 빛나는 두루마리가 둥실둥실 돌아요
func make_piece_visual(p: Node3D) -> void:
	var f := Node3D.new()
	f.position.y = 0.6
	p.add_child(f)
	var paper := make_color(Color(1.0, 0.95, 0.78))
	paper.emission_enabled = true
	paper.emission = Color(1.0, 0.85, 0.45)
	paper.emission_energy_multiplier = 0.45
	add_mbox(f, paper, Vector3(0.5, 0.34, 0.02), Vector3.ZERO)
	var ink := make_color(Color(0.35, 0.25, 0.2))
	for i in 4:
		add_mbox(f, ink, Vector3(0.025, 0.24, 0.025), Vector3(-0.14 + i * 0.09, 0, 0.012))
	var roll := make_color(Color(0.75, 0.22, 0.2))
	for sx in [-1.0, 1.0]:
		add_mcyl(f, roll, 0.045, 0.045, 0.44, Vector3(sx * 0.27, 0, 0))
		add_mcyl(f, glossy_mat(Color(0.95, 0.75, 0.25)), 0.03, 0.03, 0.54, Vector3(sx * 0.27, 0, 0))
	var halo := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 0.42
	tor.outer_radius = 0.46
	halo.mesh = tor
	var hm := make_color(Color(1.0, 0.9, 0.5))
	hm.emission_enabled = true
	hm.emission = Color(1.0, 0.85, 0.4)
	hm.emission_energy_multiplier = 1.0
	halo.material_override = hm
	halo.rotation.x = PI / 2.0
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	f.add_child(halo)

# 놀부가 흩뜨려 놓은 빨래: 구겨진 천 더미 + 저고리 한 벌
func make_laundry_pile(n: Node3D) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = int(n.position.x * 3.0 + n.position.z)
	var cloth := [Color(0.98, 0.98, 0.96), Color(0.82, 0.9, 1.0), Color(1.0, 0.88, 0.86)]
	var items := []
	for i in 5:
		items.append([Vector3(r.randf_range(-0.35, 0.35), 0.04 + i * 0.03, r.randf_range(-0.3, 0.3)), Vector3(r.randf_range(0.7, 1.0), 0.05, r.randf_range(0.5, 0.7)), cloth[i % 3], Vector3(r.randf_range(-5, 5), r.randf_range(0, 180), r.randf_range(-5, 5))])
	items.append([Vector3(0.1, 0.2, 0.0), Vector3(0.5, 0.18, 0.35), cloth[0], Vector3(0, 30, 10)])
	# 빨간 고름 하나
	items.append([Vector3(0.25, 0.2, 0.1), Vector3(0.05, 0.03, 0.34), Color(0.85, 0.25, 0.3), Vector3(0, 35, 0)])
	add_blobs(n, items, null, true)

# 김 서방네 호박: 골 깊은 주황 호박 + 꼭지 + 잎
func make_pumpkin(pos: Vector3, s: float, r: RandomNumberGenerator) -> void:
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	var c := Color(0.9, 0.42, 0.06)
	var items := []
	for i in 8:
		var a := i * TAU / 8.0
		items.append([Vector3(cos(a) * 0.2 * s, 0.38 * s, sin(a) * 0.2 * s), Vector3(0.48, 0.66, 0.48) * s, c.lightened(0.06) if i % 2 == 0 else c.darkened(0.08)])
	items.append([Vector3(0, 0.4 * s, 0), Vector3(0.8, 0.7, 0.8) * s, c])
	add_blobs(root, items, blob_gloss())
	add_beam(root, make_color(Color(0.42, 0.45, 0.2)), Vector3(0, 0.7 * s, 0), Vector3(0.05, 0.86 * s, 0.03), 0.07 * s, 0.07 * s)
	add_blobs(root, leaf_items(Vector3.ZERO, 4, 0.55 * s, r, Color(0.3, 0.55, 0.24)), null, true)

# 박 첨지네 논: 논두렁 + 찰랑이는 물 + 줄 맞춘 모
func make_paddy(center: Vector3, w: float, d: float) -> void:
	var earth := make_tex_material(Color(0.6, 0.5, 0.34), plaster_tex, 0.4)
	add_mbox(self, earth, Vector3(w, 0.25, 0.4), center + Vector3(0, 0.12, d / 2.0))
	add_mbox(self, earth, Vector3(w, 0.25, 0.4), center + Vector3(0, 0.12, -d / 2.0))
	add_mbox(self, earth, Vector3(0.4, 0.25, d), center + Vector3(w / 2.0, 0.12, 0))
	add_mbox(self, earth, Vector3(0.4, 0.25, d), center + Vector3(-w / 2.0, 0.12, 0))
	add_mbox(self, make_color(Color(0.42, 0.34, 0.24)), Vector3(w - 0.4, 0.04, d - 0.4), center + Vector3(0, 0.02, 0))
	var wtr := add_mbox(self, water_material(2, Vector4(center.x, center.z, w / 2.0 - 0.2, d / 2.0 - 0.2), Color(0.36, 0.44, 0.36), Color(0.52, 0.6, 0.48), Vector2.ZERO, 0.25), Vector3(w - 0.4, 0.02, d - 0.4), center + Vector3(0, 0.08, 0))
	wtr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var rice := []
	var nx := 9
	for ix in nx:
		for iz in nx:
			var p := center + Vector3(-w / 2.0 + 0.55 + ix * (w - 1.1) / (nx - 1), 0.25, -d / 2.0 + 0.55 + iz * (d - 1.1) / (nx - 1))
			rice.append([p, Vector3(0.18, 0.4, 0.18), Color(0.45, 0.7, 0.3)])
			rice.append([p + Vector3(0.05, 0.08, 0), Vector3(0.08, 0.36, 0.08), Color(0.55, 0.78, 0.35), Vector3(0, 0, -20)])
	add_blobs(self, rice)
	house_rects.append(Rect2(center.x - w / 2.0 - 0.3, center.z - d / 2.0 - 0.3, w + 0.6, d + 0.6))

func spawn_rice(pile: Node3D) -> void:
	for i in 3:
		var p := Vector3((i - 1) * 0.85, 0, rng.randf_range(-0.2, 0.2))
		add_blobs(pile, [[p + Vector3(0, 0.5, 0), Vector3(0.75, 1.0, 0.6), Color(1, 0.95, 0.8)], [p + Vector3(0, 1.02, 0), Vector3(0.4, 0.2, 0.35), Color(0.95, 0.85, 0.6)]], thatch_blob_mat)
		add_beam(pile, make_color(Color(0.55, 0.4, 0.2)), p + Vector3(-0.3, 0.9, 0), p + Vector3(0.3, 0.9, 0), 0.04, 0.04)
	var heap := [[Vector3(0, 0.2, 0.75), Vector3(1.3, 0.4, 0.9), Color(0.98, 0.97, 0.92)]]
	for i in 14:
		heap.append([Vector3(rng.randf_range(-0.8, 0.8), 0.04, 0.75 + rng.randf_range(-0.6, 0.6)), Vector3(0.06, 0.04, 0.04), Color(1, 1, 0.96)])
	add_blobs(pile, heap)

func spawn_silk(pile: Node3D) -> void:
	var silk := [Color(0.85, 0.2, 0.3), Color(0.2, 0.4, 0.8), Color(0.95, 0.75, 0.2), Color(0.3, 0.65, 0.4), Color(0.75, 0.45, 0.85)]
	var y := 0.2
	for i in 5:
		var roll := add_mcyl(pile, glossy_mat(silk[i]), 0.2, 0.2, 1.3, Vector3(-0.42 + (i % 2) * 0.42 + (0.21 if i >= 2 else 0.0), y + (i / 2) * 0.38, 0))
		roll.rotation.z = PI / 2.0
		add_mcyl(pile, glossy_mat(Color(0.95, 0.8, 0.3)), 0.205, 0.205, 0.08, roll.position).rotation.z = PI / 2.0

func spawn_gold(pile: Node3D) -> void:
	var gold := glossy_mat(Color(1.0, 0.78, 0.2))
	gold.metallic = 0.7
	gold.roughness = 0.25
	# 열린 궤짝
	add_mbox(pile, dark_wood_mat, Vector3(1.2, 0.6, 0.8), Vector3(0, 0.3, 0))
	var lid := add_mbox(pile, make_color(Color(0.65, 0.18, 0.15)), Vector3(1.2, 0.08, 0.8), Vector3(0, 0.85, -0.55))
	lid.rotation.x = -1.1
	for sx in [-0.55, 0.55]:
		add_mbox(pile, gold, Vector3(0.06, 0.62, 0.82), Vector3(sx, 0.31, 0))
	var heap := []
	for i in 22:
		heap.append([Vector3(rng.randf_range(-0.45, 0.45), 0.62 + rng.randf() * 0.15, rng.randf_range(-0.28, 0.28)), Vector3(0.16, 0.05, 0.16), Color(1, 0.82, 0.25)])
	var jewels := [Color(0.9, 0.15, 0.25), Color(0.2, 0.75, 0.5), Color(0.3, 0.45, 0.95)]
	for i in 4:
		heap.append([Vector3(rng.randf_range(-0.35, 0.35), 0.75, rng.randf_range(-0.2, 0.2)), Vector3(0.12, 0.12, 0.12), jewels[i % 3]])
	add_blobs(pile, heap, blob_gloss())
	# 말굽 은덩이와 엽전 꾸러미
	for i in 3:
		add_mbox(pile, gold, Vector3(0.36, 0.16, 0.22), Vector3(-0.9 + i * 0.25, 0.08, 0.75))
	for i in 3:
		for k in 5:
			add_mcyl(pile, gold, 0.12, 0.12, 0.035, Vector3(0.75 + i * 0.28, 0.02 + k * 0.04, 0.7 - i * 0.1))

func make_signpost(pos: Vector3) -> void:
	var sign := make_spot(pos, "gate", "", "", true)
	add_mcyl(sign, dark_wood_mat, 0.07, 0.08, 1.9, Vector3(0, 0.95, 0))
	var board := add_mbox(sign, plank_mat, Vector3(1.7, 0.42, 0.08), Vector3(0, 1.62, 0))
	board.rotation.z = -0.05
	var lab := Label3D.new()
	lab.text = tr("이 길 끝은 오누이 고갯길\n해와 달이 된 오누이")
	lab.font = font
	lab.font_size = 34
	lab.modulate = Color(0.25, 0.14, 0.08)
	lab.outline_size = 0
	lab.position = Vector3(0, 1.62, 0.05)
	lab.pixel_size = 0.0034
	sign.add_child(lab)
	add_tag(sign, tr("다음 이야기로 가는 길"), 2.4)

func make_border(r: RandomNumberGenerator) -> void:
	# 보이지 않는 벽 바깥에 나무와 덤불을 둘러 심어, 마을이 숲에 감싸인 것처럼
	var side := MAP_HALF + 2.5
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
			if edge == 1 and absf(p.x + 2.0) < 4.5:
				continue
			make_tree(p)
			if r.randf() < 0.5:
				make_tree(p + Vector3(r.randf_range(-3, 3), 0, r.randf_range(-3, 3)) + p.normalized() * 4.0)
		t += r.randf_range(4.5, 6.5)
	# 다음 이야기로 가는 남쪽 길목
	make_jangseung(Vector3(-4.7, 0, 37.5), false)
	make_jangseung(Vector3(0.7, 0, 37.5), true)
	make_signpost(Vector3(1.6, 0, 34.0))

func make_paths() -> void:
	make_dirt_path([Vector2(-2.0, -13.6), Vector2(-2.3, -8.0), Vector2(-1.6, -2.5), Vector2(-2.3, 3.5), Vector2(-1.8, 8.0), Vector2(-2.4, 12.5), Vector2(-2.0, 18.0), Vector2(-2.7, 25.0), Vector2(-1.7, 32.0), Vector2(-2.2, 39.0), Vector2(-2.0, 48.0)], 2.5, 1.0)
	# 남쪽 갈림길: 왼쪽은 연못 낚시터, 오른쪽은 최 영감네 논
	make_dirt_path([Vector2(-2.3, 30.0), Vector2(-6.0, 31.2), Vector2(-10.5, 30.6), Vector2(-15.4, 31.0)], 1.8, 7.0)
	make_dirt_path([Vector2(-1.8, 29.0), Vector2(3.5, 30.0), Vector2(9.5, 29.4), Vector2(15.0, 30.4), Vector2(19.0, 31.0)], 1.8, 9.0)
	make_dirt_path([Vector2(-12.2, 6.4), Vector2(-7.5, 8.4), Vector2(-2.0, 8.0), Vector2(4.0, 7.5), Vector2(9.5, 8.4), Vector2(14.5, 8.0), Vector2(19.6, 8.6), Vector2(20.4, 13.5), Vector2(19.8, 17.6)], 2.3, 4.0)

func make_creek() -> void:
	var line := []
	var x := -45.0
	while x <= 45.0:
		line.append(Vector2(x, creek_z(x)))
		x += 0.8
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in line.size() - 1:
		var a: Vector2 = line[i]
		var b: Vector2 = line[i + 1]
		var ha := creek_half(a.x)
		var hb := creek_half(b.x)
		var quad := [[Vector3(a.x, 0.03, a.y - ha), Vector2((a.x + 45.0) / 90.0, 0)], [Vector3(a.x, 0.03, a.y + ha), Vector2((a.x + 45.0) / 90.0, 1)], [Vector3(b.x, 0.03, b.y - hb), Vector2((b.x + 45.0) / 90.0, 0)], [Vector3(b.x, 0.03, b.y + hb), Vector2((b.x + 45.0) / 90.0, 1)]]
		for k in [0, 2, 1, 1, 2, 3]:
			st.set_normal(Vector3.UP)
			st.set_uv(quad[k][1])
			st.add_vertex(quad[k][0])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = water_material(0, Vector4(0, 0, 1, 1), Color(0.13, 0.4, 0.6), Color(0.42, 0.72, 0.82), Vector2(0.06, 0.0), 0.8)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func make_gourd_at(pos: Vector3, c: Color, radius: float) -> Node3D:
	var g := Node3D.new()
	g.position = pos
	add_child(g)
	make_gourd_visual(g, c, radius)
	g.set_meta("radius", radius)
	add_tag(g, tr("박"), radius * 2.0 + 0.7)
	g.visible = false
	return g

func make_world() -> void:
	make_surface_materials()
	make_light_and_sky()

	var full := MAP_HALF * 2.0
	var none := Color(0, 0, 0, 0)
	var ground_col := add_solid(Vector3(0, -0.5, 0), Vector3(full, 1, full), Color(0.45, 0.7, 0.35))
	(ground_col.get_parent().get_child(0) as MeshInstance3D).material_override = ground_mat
	add_solid(Vector3(0, 2, -MAP_HALF), Vector3(full, 8, 1), none)
	add_solid(Vector3(0, 2, MAP_HALF), Vector3(full, 8, 1), none)
	add_solid(Vector3(-MAP_HALF, 2, 0), Vector3(1, 8, full), none)
	add_solid(Vector3(MAP_HALF, 2, 0), Vector3(1, 8, full), none)

	# 숲 바닥, 개울, 다리, 길
	make_creek()
	add_box(self, Color(0.55, 0.4, 0.25), Vector3(3, 0.2, 4), Vector3(-2, 0.1, -15.5)).material_override = plank_mat
	# 개울은 다리로만 건널 수 있어요 (점프로도 못 넘는 보이지 않는 벽, 다리 자리만 비워 둠)
	var creek_left_len := (-3.5) - (-MAP_HALF)
	var creek_right_len := MAP_HALF - (-0.5)
	add_solid(Vector3(-MAP_HALF + creek_left_len / 2.0, 2, -15.5), Vector3(creek_left_len, 5, 3), none)
	add_solid(Vector3(-0.5 + creek_right_len / 2.0, 2, -15.5), Vector3(creek_right_len, 5, 3), none)
	make_paths()

func make_village() -> void:
	# 놀부네
	make_house(Vector3(14, 0, 2), Vector3(9, 4, 6), Color(0.95, 0.93, 0.86), Color(0.28, 0.3, 0.36), "tile")
	make_npc("nolbu", tr("놀부"), Color(0.6, 0.2, 0.45), Vector3(14, 0, 7.5), 1.15, true)
	make_npc("wife", tr("놀부 마누라"), Color(0.75, 0.3, 0.3), Vector3(10.5, 0, 7.8), 1.0, true)
	nolbu_gourd = make_gourd_at(Vector3(19, 0, 8.5), Color(0.6, 0.68, 0.4), 1.7)
	make_npc("dokkaebi", tr("도깨비"), Color(0.2, 0.55, 0.6), Vector3(19, 0, 8.5), 1.3, false).visible = false

	# 흥부네
	hut = make_house(Vector3(-13, 0, -2), Vector3(4.5, 2.8, 3.5), Color(0.8, 0.74, 0.64), Color(0.6, 0.53, 0.38), "thatch")
	make_hut_shabby(hut)
	make_npc("heungbu", tr("흥부"), Color(0.85, 0.6, 0.35), Vector3(-12, 0, 2.5), 1.0, true)
	make_npc("kid1", tr("첫째"), Color(0.95, 0.75, 0.5), Vector3(-16.5, 0, 4), 0.7, true)
	make_npc("kid2", tr("막내"), Color(0.98, 0.82, 0.6), Vector3(-9, 0, 5), 0.55, true)
	var nest := make_spot(Vector3(-15.2, 0, 0.7), "nest", "", "", true)
	add_tag(nest, tr("제비 둥지"), 3.4)
	make_nest_visual(nest)
	for pos in [Vector3(-6.5, 0, -3), Vector3(-5, 0, 0), Vector3(-6.5, 0, 3)]:
		add_thing(make_gourd_at(pos, Color(0.82, 0.9, 0.62), 1.2), "gourd", "")

	# 장터
	add_solid(Vector3(20, 1, 19.2), Vector3(4, 2, 1.2), Color(0, 0, 0, 0))
	make_stall(Vector3(20, 0, 19.2))
	make_npc("merchant", tr("장터 상인"), Color(0.3, 0.5, 0.35), Vector3(20, 0, 21.2), 1.0, true)

	# 놀부 심술에 당한 마을 사람들
	make_npc("dori", tr("돌이"), Color(0.9, 0.8, 0.45), Vector3(9, 0, 19), 0.6, true)
	make_npc("suni", tr("순이 엄마"), Color(0.55, 0.65, 0.85), Vector3(-9, 0, -12), 1.0, true)
	make_npc("kim", tr("김 서방"), Color(0.5, 0.45, 0.3), Vector3(-24, 0, 15), 1.0, true)
	make_npc("ong", tr("옹기 할멈"), Color(0.6, 0.5, 0.55), Vector3(27, 0, -9), 0.9, true)
	make_npc("park", tr("박 첨지"), Color(0.4, 0.5, 0.55), Vector3(-31, 0, -5), 1.0, true)
	var pr := RandomNumberGenerator.new()
	pr.seed = 15
	for pos in [Vector3(-26.5, 0, 16.8), Vector3(-22.3, 0, 17), Vector3(-25, 0, 18.5)]:
		make_pumpkin(pos, 1.25, pr)
	var ong_jars := StaticBody3D.new()
	add_child(ong_jars)
	var crack := make_color(Color(0.15, 0.1, 0.08))
	for pos in [Vector3(29, 0, -10), Vector3(29.8, 0, -8.6), Vector3(28.6, 0, -7.6)]:
		make_jar(ong_jars, pos, 1.05, Color(0.42, 0.25, 0.15))
		# 놀부가 차서 생긴 금
		var c0: Vector3 = pos + Vector3(-0.1, 0.85, 0.5)
		ong_cracks.append(add_beam(self, crack, c0, c0 + Vector3(0.12, -0.2, 0.02), 0.025, 0.02))
		ong_cracks.append(add_beam(self, crack, c0 + Vector3(0.12, -0.2, 0.02), c0 + Vector3(0.02, -0.4, 0.04), 0.025, 0.02))
	make_paddy(Vector3(-34.5, 0, -3), 6.0, 6.0)
	for pos in [Vector3(-14, 0, -13.2), Vector3(-21, 0, -17.6), Vector3(5, 0, -13.2)]:
		var cloth := make_spot(pos, "laundry", "", tr("빨래"), false)
		make_laundry_pile(cloth)

	# 품팔이 터
	var well := make_spot(Vector3(4, 0, -3), "job", "water", tr("우물"), true)
	make_well_visual(well)
	add_solid(Vector3(4, 0.45, -3), Vector3(1.4, 0.9, 1.4), Color(0, 0, 0, 0))
	var straw := make_spot(Vector3(-17.5, 0, 8.5), "job", "shoes", tr("짚더미"), true)
	make_haystack_visual(straw)
	add_solid(Vector3(-17.5, 0.4, 8.5), Vector3(1.6, 0.8, 1.2), Color(0, 0, 0, 0))
	var stump := make_spot(Vector3(15, 0, -19.5), "job", "wood", tr("나무터"), true)
	make_spot(Vector3(3, 0, 5.4), "job", "gam", tr("감나무"), true)
	make_stump_visual(stump)
	add_solid(Vector3(15, 0.35, -19.5), Vector3(1.0, 0.7, 1.0), Color(0, 0, 0, 0))

	# 숨바꼭질하는 흥부네 동생들
	for pos in [Vector3(18.6, 0, -2.6), Vector3(-23.4, 0, 6.6), Vector3(5.2, 0, 12.4), Vector3(-4.4, 0, -13)]:
		var kid := make_spot(pos, "hider", "", "", false)
		make_person(kid, "kid", Color(0.98, 0.78, 0.5), false)
		kid.scale = Vector3(0.5, 0.5, 0.5)

	# 마을 나무
	for pos in [Vector3(5, 0, 14), Vector3(-22, 0, 8), Vector3(24, 0, -6), Vector3(-26, 0, 22), Vector3(30, 0, 18), Vector3(8, 0, -8), Vector3(-20, 0, -9)]:
		make_tree(pos)

	# 바위 (점프해서 올라가요)
	add_solid(Vector3(29, 0.55, 7.5), Vector3(1.8, 1.1, 1.8), Color(0, 0, 0, 0))
	add_solid(Vector3(30.8, 1.1, 5.6), Vector3(2.4, 2.2, 2.4), Color(0, 0, 0, 0))
	var rr := RandomNumberGenerator.new()
	rr.seed = 5
	make_rock(Vector3(29, 0.45, 7.5), Vector3(2.0, 1.25, 2.0), rr)
	make_rock(Vector3(30.8, 1.0, 5.6), Vector3(2.6, 2.4, 2.6), rr)

	# 이웃 초가집들과 살림살이
	make_house(Vector3(-28, 0, 10), Vector3(4.6, 2.4, 3.4), Color(0.94, 0.9, 0.82), Color(0.8, 0.66, 0.3), "thatch")
	make_house(Vector3(30, 0, -3), Vector3(4.4, 2.3, 3.4), Color(0.93, 0.89, 0.8), Color(0.8, 0.66, 0.3), "thatch")
	make_house(Vector3(-10, 0, 22), Vector3(4.8, 2.4, 3.5), Color(0.95, 0.91, 0.83), Color(0.8, 0.66, 0.3), "thatch")
	make_jangdok(Vector3(7.8, 0, -2.7), rr)
	make_laundry(Vector3(-19.4, 0, 0.9), Vector3(-17.0, 0, 0.9))
	make_laundry(Vector3(-13.2, 0, 25.0), Vector3(-6.8, 0, 25.0))
	make_basket(Vector3(-10.3, 0, 0.9), 1.0, Color(0.95, 0.55, 0.15))
	make_basket(Vector3(-25.2, 0, 13.0), 0.9, Color(0.4, 0.7, 0.3))
	make_basket(Vector3(-7.1, 0, 25.5), 1.1, Color(0, 0, 0, 0))
	make_sieve(Vector3(-11.6, 0, -4.15), PI)
	make_sieve(Vector3(27.6, 0, -1.25), 0.3)
	make_bench(Vector3(8.6, 0, 11.6), 0.2)
	make_trellis(Vector3(-10.0, 0, 11.9), Vector3(-7.0, 0, 11.9), rr)

	# 숨은 이야기 조각
	var piece_pos := [Vector3(14, 0, -6.5), Vector3(-31, 0, -12), Vector3(-9, 0, -36), Vector3(-27.5, 0, 23.5), Vector3(35, 0, 33), Vector3(30.8, 2.2, 5.6)]
	for i in piece_pos.size():
		var p := make_spot(piece_pos[i], "piece", str(i), "", true)
		make_piece_visual(p)
	make_south()
	make_wild_herbs()


# ---------- 약초 도감 (6종, 종류마다 3번, 캐면 3분 뒤 다시 자라요) ----------
func make_wild_herbs() -> void:
	for k in HERBS.size():
		for pos in HERBS[k]["spots"]:
			var n := make_spot(pos, "wild", str(k), "", true)
			add_tag(n, HERBS[k]["name"], 1.25)
			make_wild_visual(n, k)
			wild_spots.append([n, k, 0.0])

func wild_keep_clear() -> Array:
	var out := []
	for h in HERBS:
		out += h["spots"]
	return out

func make_wild_visual(n: Node3D, kind: int) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = int(n.position.x * 13.0 + n.position.z * 3.0)
	var items := []
	match kind:
		0:  # 쑥: 은빛 도는 잎 무더기
			for i in 9:
				var a := i * TAU / 9.0
				var hh := r.randf_range(0.25, 0.5)
				items.append([Vector3(cos(a) * 0.14, hh * 0.5, sin(a) * 0.14), Vector3(0.16, hh, 0.07), Color(0.52, 0.66, 0.48).lerp(Color(0.7, 0.78, 0.66), r.randf()), Vector3(0, -rad_to_deg(a), 22)])
		1:  # 냉이: 바닥에 붙은 잎과 하얀 꽃대
			for i in 8:
				var a := i * TAU / 8.0
				items.append([Vector3(cos(a) * 0.2, 0.04, sin(a) * 0.2), Vector3(0.3, 0.04, 0.1), Color(0.36, 0.58, 0.3), Vector3(0, -rad_to_deg(a), 0)])
			for i in 3:
				var top := Vector3(r.randf_range(-0.1, 0.1), r.randf_range(0.4, 0.55), r.randf_range(-0.1, 0.1))
				add_beam(n, make_color(Color(0.4, 0.6, 0.3)), Vector3(0, 0.03, 0), top, 0.025, 0.025)
				for k in 4:
					items.append([top + Vector3(r.randf_range(-0.05, 0.05), r.randf_range(-0.06, 0.02), r.randf_range(-0.05, 0.05)), Vector3(0.06, 0.06, 0.06), Color(1, 1, 0.97)])
		2:  # 달래: 가는 잎과 하얀 알뿌리
			for i in 9:
				var tilt := Vector3(r.randf_range(-25, 25), 0, r.randf_range(-25, 25))
				items.append([Vector3(r.randf_range(-0.08, 0.08), 0.28, r.randf_range(-0.08, 0.08)), Vector3(0.035, 0.55, 0.035), Color(0.4, 0.66, 0.32), tilt])
			items.append([Vector3(0.12, 0.06, 0.05), Vector3(0.12, 0.1, 0.12), Color(0.98, 0.96, 0.9)])
			items.append([Vector3(-0.08, 0.05, 0.1), Vector3(0.1, 0.09, 0.1), Color(0.98, 0.94, 0.88)])
		3:  # 도라지: 보랏빛 별꽃
			for i in 3:
				var a := i * TAU / 3.0
				var top := Vector3(cos(a) * 0.15, r.randf_range(0.55, 0.75), sin(a) * 0.15)
				add_beam(n, make_color(Color(0.32, 0.52, 0.24)), Vector3(0, 0.02, 0), top, 0.03, 0.03)
				items.append([top * 0.5, Vector3(0.16, 0.04, 0.08), Color(0.36, 0.6, 0.28), Vector3(0, -rad_to_deg(a), 25)])
				var fc := Color(0.6, 0.45, 0.92) if i != 1 else Color(0.96, 0.96, 1.0)
				for k in 5:
					var b := k * TAU / 5.0
					items.append([top + Vector3(cos(b) * 0.08, 0.0, sin(b) * 0.08), Vector3(0.1, 0.04, 0.07), fc, Vector3(0, -rad_to_deg(b), 0)])
				items.append([top + Vector3(0, 0.03, 0), Vector3(0.04, 0.04, 0.04), Color(1.0, 0.95, 0.6)])
		4:  # 더덕: 막대를 감아 오르는 덩굴과 종 모양 꽃
			add_mcyl(n, dark_wood_mat, 0.03, 0.035, 0.9, Vector3(0, 0.45, 0))
			for i in 7:
				var a := i * 1.4
				var y := 0.12 + i * 0.11
				items.append([Vector3(cos(a) * 0.08, y, sin(a) * 0.08), Vector3(0.14, 0.05, 0.1), Color(0.34, 0.56, 0.28), Vector3(0, -rad_to_deg(a), 15)])
			for y in [0.5, 0.78]:
				items.append([Vector3(0.1, y, 0.0), Vector3(0.1, 0.13, 0.1), Color(0.66, 0.72, 0.5)])
				items.append([Vector3(0.1, y - 0.06, 0.0), Vector3(0.11, 0.04, 0.11), Color(0.55, 0.3, 0.4)])
		5:  # 산삼: 손바닥 잎 다섯 장과 빨간 열매
			add_beam(n, make_color(Color(0.36, 0.5, 0.26)), Vector3(0, 0.02, 0), Vector3(0, 0.55, 0), 0.03, 0.03)
			for i in 3:
				var a := i * TAU / 3.0
				var base := Vector3(cos(a) * 0.12, 0.42, sin(a) * 0.12)
				add_beam(n, make_color(Color(0.36, 0.5, 0.26)), Vector3(0, 0.4, 0), base, 0.02, 0.02)
				for k in 5:
					var b := a + (k - 2) * 0.45
					items.append([base + Vector3(cos(b) * 0.1, 0.0, sin(b) * 0.1), Vector3(0.14, 0.03, 0.06), Color(0.3, 0.55, 0.26), Vector3(0, -rad_to_deg(b), 0)])
			for i in 7:
				items.append([Vector3(r.randf_range(-0.05, 0.05), 0.6 + r.randf_range(0, 0.06), r.randf_range(-0.05, 0.05)), Vector3(0.06, 0.06, 0.06), Color(0.9, 0.12, 0.12)])
	add_blobs(n, items)
	add_blobs(n, [[Vector3(0, 0.02, 0), Vector3(0.55, 0.1, 0.55), Color(0.45, 0.33, 0.22)]], null, true)

func update_wild(delta: float) -> void:
	for ws in wild_spots:
		var node: Node3D = ws[0]
		if node.visible:
			continue
		ws[2] = float(ws[2]) - delta
		if float(ws[2]) <= 0.0:
			if node.has_meta("anchor"):
				node.position = random_near(node.get_meta("anchor"), SCATTER_HERB)
			node.visible = true
			pop3d(node, true)

func herb_kinds_done() -> int:
	var n := 0
	for c in herb_counts:
		if int(c) >= HERB_NEED:
			n += 1
	return n

func pick_wild(t: Dictionary) -> void:
	var node: Node3D = t["node"]
	var k := int(t["id"])
	node.visible = false
	for ws in wild_spots:
		if ws[0] == node:
			ws[2] = HERB_REGROW
	sfx("pop")
	burst3d(node.position + Vector3(0, 0.6, 0), Color(0.6, 0.9, 0.5))
	herb_counts[k] = int(herb_counts[k]) + 1
	var nm: String = HERBS[k]["name"]
	var lines := []
	var cnt := int(herb_counts[k])
	if cnt < HERB_NEED:
		lines.append(["", tr("%s을(를) 캤다! (%d/%d) 3분 뒤에 다시 자라요.") % [nm, cnt, HERB_NEED]])
	elif cnt == HERB_NEED:
		var rw: int = HERBS[k]["reward"]
		earn(rw)
		lines.append(["", tr("%s을(를) %d번 모아 약초 도감에 올렸다! 장터에 팔아 엽전 %d냥. (약초 도감 %d/%d)") % [nm, HERB_NEED, rw, herb_kinds_done(), HERBS.size()]])
		if herb_kinds_done() >= HERBS.size() and not herb_reward:
			herb_reward = true
			earn(40)
			lines.append(["", tr("약초 도감을 모두 채웠다! 마을 사람들이 고맙다며 엽전 40냥을 모아 주었다.")])
	else:
		earn(1)
		lines.append(["", tr("%s을(를) 캐서 장터에 팔았다. 엽전 1냥.") % nm])
	save_south()
	say(lines, Callable())

func read_story(i: int) -> void:
	if not story_read[i]:
		return
	sfx("tap")
	var st: Dictionary = STORY[i]
	story_reader_label.text = "%d. %s\n\n%s" % [i + 1, st["title"], st["text"]]
	story_box.visible = false
	story_reader.visible = true

func laundry_spot(seg: int) -> Vector3:
	var ranges := [[-35.0, -15.0], [-13.0, 12.0], [14.0, 35.0]]
	var rg: Array = ranges[seg % 3]
	for i in 40:
		var x := rng.randf_range(rg[0], rg[1])
		if absf(x + 2.0) < 3.0:
			continue
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var p := Vector3(x, 0, creek_z(x) + side * (creek_half(x) + rng.randf_range(1.2, 2.2)))
		if ground_ok(p):
			return p
	return Vector3(rng.randf_range(rg[0], rg[1]), 0, -13.0)

func scatter_items() -> void:
	# 물리 세상이 준비될 때까지 잠깐 기다려요
	await get_tree().physics_frame
	await get_tree().physics_frame
	rng.randomize()
	for t in things:
		var node: Node3D = t["node"]
		var kind: String = t["kind"]
		var radius := 0.0
		if kind == "piece" and node.position.y < 0.5:
			radius = SCATTER_PIECE
		elif kind == "herb":
			radius = SCATTER_HERB
		elif kind == "wild" and node.position.x < 36.0:
			radius = SCATTER_HERB
		if kind == "laundry":
			node.position = laundry_spot(laundry_seg)
			laundry_seg += 1
		if radius > 0.0:
			if not node.has_meta("anchor"):
				node.set_meta("anchor", node.position)
			node.position = random_near(node.get_meta("anchor"), radius)


# ---------- 이야기 조각 7개: 놀부는 왜 놀부가 되었을까 ----------
func story_count() -> int:
	var n := 0
	for r in story_read:
		if r:
			n += 1
	return n

func get_piece_id(id: int, extra: String) -> void:
	pieces_found += 1
	update_quest_text()
	var first: bool = not story_read[id]
	story_read[id] = true
	save_south()
	var st: Dictionary = STORY[id]
	var found := []
	if extra != "":
		found.append(["", extra])
	found.append([tr("이야기 조각 “%s”") % st["title"], st["text"]])
	if first:
		found.append(["", tr("새 이야기 조각을 찾았어요! 도감의 '이야기'에서 다시 읽을 수 있어요. (%d/%d)") % [story_count(), STORY.size()]])
	if pieces_found >= PIECE_TOTAL:
		found.append([tr("이야기 조각"), tr("일곱 조각이 하나로 이어졌어요.\n놀부의 욕심 뒤에는, 동생들을 지키고 싶었던 겁 많은 형이 있었어요.")])
	say(found, Callable())


# ---------- 마을 안에서 하는 3D 미니게임 (우물, 나무하기, 낚시) ----------
func world_pose(delta: float) -> void:
	if scene_pose():
		return
	match mg_type:
		"wood3d":
			var t: float = w.get("chop", 0.0)
			var arm := Vector3(lerpf(-2.75, -0.85, t), lerpf(0.12, 0.28, t), lerpf(-0.55, -0.08, t))
			pose_custom(arm, arm, lerpf(-0.14, 0.32, t), 0.18 + t * 0.15)
			var sh := (bone_world("armL") + bone_world("armR")) * 0.5
			place_tool((((bone_world("handL") + bone_world("handR")) * 0.5) - sh).normalized() + Vector3(0, 0.25 * (1.0 - t), 0))
		"well3d":
			var ph: float = w.get("pull_anim", 0.0)
			var reach := -1.35 - 0.35 * sin(ph)
			var reach2 := -1.35 + 0.35 * sin(ph)
			pose_custom(Vector3(reach, 0.25, -0.7), Vector3(reach2, 0.25, -0.7), 0.15, 0.15)
		"fish":
			var jerk: float = w.get("jerk", 0.0)
			var fight := 0.0
			if mg_step >= 2:
				fight = sin(anim_t * 18.0) * 0.06
			pose_custom(Vector3(-0.5, 0.45, -0.3), Vector3(-1.05 - jerk * 0.6 + fight, 0.3, -0.85 + jerk * 0.3), 0.06 - jerk * 0.1, 0.12)
			var fwd := Vector3(sin(player.rotation.y), 0, cos(player.rotation.y))
			place_tool((fwd * 0.75 + Vector3(0, 0.62 + jerk * 0.5, 0)).normalized())

# --- 효과 ---

func splash3d(pos: Vector3, big: bool = false) -> void:
	burst3d(pos + Vector3(0, 0.1, 0), Color(0.75, 0.9, 1.0), 26 if big else 12)
	ripple3d(pos, 1.6 if big else 0.9)

func ripple3d(pos: Vector3, size: float) -> void:
	var mi := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 0.9
	tor.outer_radius = 1.0
	tor.rings = 24
	mi.mesh = tor
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1, 1, 1, 0.8)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(pos.x, 0.1, pos.z)
	mi.scale = Vector3(0.15, 0.04, 0.15)
	add_child(mi)
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3(size, 0.04, size), 0.7).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(m, "albedo_color:a", 0.0, 0.7)
	tw.tween_callback(mi.queue_free)

func chips3d(pos: Vector3) -> void:
	var p := CPUParticles3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.09, 0.03, 0.05)
	mesh.material = make_color(Color(0.9, 0.74, 0.5))
	p.mesh = mesh
	p.amount = 22
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = 0.8
	p.direction = Vector3.UP
	p.spread = 80.0
	p.initial_velocity_min = 2.5
	p.initial_velocity_max = 5.0
	p.gravity = Vector3(0, -12, 0)
	p.angular_velocity_min = -720
	p.angular_velocity_max = 720
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	p.position = pos
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)


# ---------- 나무하기: 타이밍 맞춰 도끼로 쩍! ----------
func start_wood3d() -> void:
	var stump := job_spot("wood")
	var s := stump.position
	start_game("wood3d", {"world": true, "art": "world", "title": tr("막대가 초록 칸에 왔을 때 눌러서\n도끼로 장작을 쪼개요!"), "goal": 6}, job_done)
	world_game_begin(s + Vector3(0, 0, 1.15), s, s + Vector3(2.5, 2.1, 2.8), s + Vector3(0, 0.75, 0.35), stump)
	if stump.has_meta("axe"):
		world_hide(stump.get_meta("axe"))
	hold_tool("axe")
	w["chop"] = 0.0
	w["busy"] = false
	w["stump"] = s
	wood_new_log()

func job_spot(id: String) -> Node3D:
	for t in things:
		if t["kind"] == "job" and t["id"] == id:
			return t["node"]
	return self

func wood_new_log() -> void:
	# 게임이 끝난 뒤 늦게 불리면 아무것도 안 해요
	if not mg_active or mg_type != "wood3d" or not w.has("stump"):
		return
	var s: Vector3 = w["stump"]
	var lg := Node3D.new()
	lg.position = s + Vector3(0, 0.72, 0)
	world_node(lg)
	var body := add_mcyl(lg, dark_wood_mat, 0.2, 0.21, 0.52, Vector3(0, 0.26, 0))
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var cap := add_mcyl(lg, endgrain_mat(), 0.195, 0.195, 0.01, Vector3(0, 0.525, 0))
	cap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w["log"] = lg
	pop3d(lg, true)

func wood_marker() -> float:
	return sin(mg_phase)

func wood_zone() -> float:
	return maxf(0.08, 0.2 - mg_count * 0.018)

func update_wood3d(delta: float) -> void:
	if not w.get("busy", false):
		mg_phase += delta * (2.0 + mg_count * 0.32)
	mg_progress = float(mg_count) / float(mg_cfg["goal"])
	mg_info.text = tr("장작 %d/%d | 남은 기회 %d") % [mg_count, mg_cfg["goal"], mg_lives]

func wood_strike() -> void:
	if w.get("busy", false) or not mg_active:
		return
	w["busy"] = true
	var hit := absf(wood_marker()) < wood_zone()
	var tw := create_tween()
	tw.tween_method(func(v): w["chop"] = v, 0.0, 1.0, 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): wood_impact(hit))
	tw.tween_interval(0.18)
	tw.tween_method(func(v): w["chop"] = v, 1.0, 0.0, 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		w["busy"] = false
		if hit and mg_active:
			wood_new_log())

func wood_impact(hit: bool) -> void:
	var lg: Node3D = w.get("log")
	if lg == null or not is_instance_valid(lg):
		return
	var top := lg.global_position + Vector3(0, 0.5, 0)
	if hit:
		mg_count += 1
		sfx("crack", rng.randf_range(0.95, 1.1))
		sfx("saw", 1.4)
		hit_stop(0.07)
		shake(12)
		cam_kick = 0.35
		chips3d(top)
		flash(Color(1, 0.95, 0.8))
		var at := cam.unproject_position(top)
		float_text([tr("쩍!"), tr("탁!"), tr("쩌억!")][mg_count % 3], at, Color(1, 0.95, 0.75), 1.5)
		burst(at, Color(1, 0.85, 0.4), 10)
		# 통나무가 반으로 갈라져 양쪽으로 날아가요
		lg.visible = false
		for sx in [-1.0, 1.0]:
			var half := Node3D.new()
			half.position = lg.global_position + Vector3(sx * 0.1, 0, 0)
			add_child(half)
			var hm := add_mcyl(half, dark_wood_mat, 0.2, 0.21, 0.52, Vector3(0, 0.26, 0))
			hm.scale = Vector3(0.5, 1, 1)
			add_mbox(half, endgrain_mat(), Vector3(0.01, 0.5, 0.38), Vector3(-sx * 0.0, 0.26, 0))
			var dest := half.position + Vector3(sx * rng.randf_range(0.7, 1.0), -0.6, rng.randf_range(-0.3, 0.3))
			var tw := half.create_tween()
			tw.tween_property(half, "position", half.position + Vector3(sx * 0.4, 0.55, 0), 0.18).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(half, "rotation", Vector3(0, 0, -sx * 1.4), 0.5)
			tw.tween_property(half, "position", dest, 0.3).set_ease(Tween.EASE_IN)
			tw.tween_property(half, "scale", Vector3(0.01, 0.01, 0.01), 0.35)
			tw.tween_callback(half.queue_free)
		lg.queue_free()
	else:
		mg_lives -= 1
		mg_perfect = false
		sfx("bad")
		sfx("tick", 0.6)
		shake(6)
		var at2 := cam.unproject_position(top)
		float_text(tr("빗나갔어요!"), at2, Color(1, 0.6, 0.5), 1.1)
		var tw2 := lg.create_tween()
		tw2.tween_property(lg, "rotation:z", 0.25, 0.06)
		tw2.tween_property(lg, "rotation:z", -0.18, 0.08)
		tw2.tween_property(lg, "rotation:z", 0.0, 0.12)


# ---------- 우물: 두레박을 당겨 물 길어 올리기 ----------
func start_well3d() -> void:
	var well := job_spot("water")
	var p := well.position
	start_game("well3d", {"world": true, "art": "world", "title": tr("손가락으로 위로 살살, 여러 번 쓸어 줄을 당겨요\n홱 잡아채면 물이 쏟아져요!")}, job_done)
	world_game_begin(p + Vector3(0, 0, 1.3), p, p + Vector3(-2.2, 2.4, 3.0), p + Vector3(0, 0.8, 0), well)
	for k in ["bucket", "rope"]:
		if well.has_meta(k):
			world_hide(well.get_meta(k))
	var bk := Node3D.new()
	bk.position = p + Vector3(0.2, WELL_TOP, 0)
	world_node(bk)
	add_mcyl(bk, wood_mat, 0.17, 0.14, 0.26, Vector3(0, -0.13, 0))
	add_mcyl(bk, make_color(Color(0.3, 0.22, 0.14)), 0.175, 0.175, 0.03, Vector3(0, -0.02, 0))
	var wtr := add_mcyl(bk, water_material(1, Vector4(0, 0, 0.15, 0.15), Color(0.2, 0.45, 0.6), Color(0.45, 0.7, 0.8), Vector2.ZERO, 0.0), 0.15, 0.15, 0.01, Vector3(0, -0.24, 0))
	w["bucket"] = bk
	w["water_disc"] = wtr
	var rope := MeshInstance3D.new()
	var rb := BoxMesh.new()
	rb.size = Vector3(0.025, 1.0, 0.025)
	rope.mesh = rb
	rope.material_override = make_color(Color(0.75, 0.62, 0.4))
	world_node(rope)
	w["rope"] = rope
	w["pulley"] = p + Vector3(0.2, 1.75, 0)
	w["well"] = well
	w["y"] = WELL_TOP
	w["water"] = 0.0
	w["sway"] = 0.0
	w["state"] = "lower"
	w["timer"] = 0.0
	w["fill"] = 0.0
	w["pull_anim"] = 0.0
	w["last_y"] = -1.0
	w["target"] = WELL_TOP

func update_well3d(delta: float) -> void:
	var st: String = w["state"]
	var y: float = w["y"]
	w["timer"] = float(w["timer"]) + delta
	w["sway"] = maxf(0.0, float(w["sway"]) - delta * 0.9)
	if st == "lower":
		y = move_toward(y, WELL_WATER, delta * 0.9)
		if y <= WELL_WATER + 0.001:
			sfx("splash")
			splash3d((w["pulley"] as Vector3) * Vector3(1, 0, 1) + Vector3(0, 0.62, 0))
			w["state"] = "fill"
			w["timer"] = 0.0
		mg_info.text = tr("두레박을 내려요...")
	elif st == "fill":
		w["water"] = minf(1.0, float(w["timer"]) / 0.6)
		if float(w["timer"]) > 0.7:
			w["state"] = "pull"
			w["target"] = y
		mg_info.text = tr("물이 차오르고 있어요")
	elif st == "pull":
		# 두레박은 손가락을 그대로 따라오지 않고, 당긴 만큼을 일정한 빠르기로 천천히 따라 올라와요
		# (한 번에 휙 쓸어 올려도 바로 올라오지 않아요)
		y = move_toward(y, float(w["target"]), delta * WELL_PULL_SPEED)
		var sway: float = w["sway"]
		if sway > 0.5:
			# 너무 흔들리면 물이 쏟아져요
			var spill := (sway - 0.5) * delta * 3.0
			w["water"] = maxf(0.0, float(w["water"]) - spill)
			if rng.randf() < delta * 8.0:
				var bkn: Node3D = w["bucket"]
				burst3d(bkn.global_position, Color(0.7, 0.88, 1.0), 4)
		if y >= WELL_TOP - 0.001:
			var got: float = w["water"]
			if got < 0.3:
				mg_lives -= 1
				mg_perfect = false
				sfx("bad")
				float_text(tr("물이 다 쏟아졌어요!"), cam.unproject_position((w["bucket"] as Node3D).global_position), Color(1, 0.6, 0.5), 1.1)
			else:
				if got < 0.85:
					mg_perfect = false
				w["fill"] = float(w["fill"]) + got * 0.36
				sfx("splash", 1.2)
				sfx("good")
				shake(4)
				var bp := (w["bucket"] as Node3D).global_position
				splash3d(bp + Vector3(0.4, -0.3, 0.5))
				float_text(tr("물 한 동이!") if got >= 0.85 else tr("조금 쏟았어요"), cam.unproject_position(bp), Color(0.8, 0.95, 1.0), 1.2)
			w["water"] = 0.0
			w["state"] = "lower"
		var sw_txt := tr("흔들려요! 살살~") if sway > 0.5 else tr("위로 쓸어 올려요")
		mg_info.text = tr("%s | 항아리 %d%% | 남은 기회 %d") % [sw_txt, int(minf(float(w["fill"]), 1.0) * 100.0), mg_lives]
	w["y"] = y
	mg_progress = minf(float(w["fill"]), 1.0)
	# 3D 위치 갱신
	var bk: Node3D = w["bucket"]
	var pul: Vector3 = w["pulley"]
	var swing := sin(anim_t * 9.0) * minf(float(w["sway"]), 1.2) * 0.35
	bk.global_position = Vector3(pul.x + sin(swing) * 0.15, (w["well"] as Node3D).position.y + y, pul.z)
	bk.rotation.z = swing
	(w["water_disc"] as Node3D).visible = float(w["water"]) > 0.02
	(w["water_disc"] as Node3D).position.y = -0.24 + float(w["water"]) * 0.2
	var rope: MeshInstance3D = w["rope"]
	var top := pul
	var bot := bk.global_position
	rope.global_position = (top + bot) * 0.5
	rope.scale = Vector3(1, maxf(0.05, top.distance_to(bot)), 1)
	rope.rotation = Vector3(0, 0, -swing * 0.3)

const WELL_PULL_SPEED := 0.16   # 두레박이 올라오는 가장 빠른 빠르기 (한 동이에 2.5초쯤)
const WELL_PULL_GAIN := 0.32    # 화면을 한 번 끝까지 쓸어도 우물 깊이의 4분의 3쯤만 당겨요
const WELL_CALM := 0.45         # 이보다 빨리 당기면 두레박이 흔들려요

func well_drag(dy: float, dt_ms: float) -> void:
	if w.get("state", "") != "pull":
		return
	var h := mg_overlay.size.y
	var rise := dy / h * WELL_PULL_GAIN
	if rise <= 0.0:
		return
	# 이미 당겨 둔 줄이 많이 남아 있으면 더 당겨도 줄이 느슨하게 쌓일 뿐이에요
	var target: float = w.get("target", float(w["y"]))
	w["target"] = minf(WELL_TOP, minf(target + rise, float(w["y"]) + 0.18))
	w["pull_anim"] = float(w["pull_anim"]) + rise * 14.0
	var speed := rise / maxf(dt_ms / 1000.0, 0.008)
	if speed > WELL_CALM:
		w["sway"] = minf(1.6, float(w["sway"]) + (speed - WELL_CALM) * 0.6)
		# 홱 잡아채면 그 자리에서 물이 출렁 쏟아져요
		if speed > WELL_CALM * 2.0:
			w["water"] = maxf(0.0, float(w["water"]) - (speed - WELL_CALM * 2.0) * 0.12)
	if rng.randf() < 0.3:
		sfx("tick", rng.randf_range(0.7, 0.9))


# ---------- 낚시 (3D): 연못 위 찌, 물고기 그림자, 튀어 오르는 물고기 ----------
func start_fishing3d() -> void:
	start_game("fish", {"world": true, "art": "world", "title": tr("찌가 쏙 들어가면 눌러서 채요!\n걸리면 눌렀다 뗐다 하며 초록 칸에")}, fish_done)
	var stand := POND_C + Vector3(4.1, 0.0, 0.0)
	var fspot: Node3D = null
	for t in things:
		if t["kind"] == "fish":
			fspot = t["node"]
	world_game_begin(stand, POND_C, POND_C + Vector3(7.4, 3.3, 3.8), POND_C + Vector3(1.6, 0.3, 0.0), fspot)
	for d in pond_deco:
		world_hide(d)
	hold_tool("rod")
	var bob := Node3D.new()
	world_node(bob)
	add_ball(bob, Color(0.9, 0.2, 0.2), 0.07, Vector3(0, 0.05, 0))
	add_ball(bob, Color(1, 1, 1), 0.065, Vector3(0, -0.01, 0))
	w["bobber"] = bob
	w["bob_at"] = POND_C + Vector3(1.0, 0.09, 0.4)
	var shadow := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	shadow.mesh = sm
	var shm := StandardMaterial3D.new()
	shm.albedo_color = Color(0.05, 0.12, 0.18, 0.55)
	shm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow.material_override = shm
	shadow.scale = Vector3(0.7, 0.05, 0.28)
	shadow.visible = false
	world_node(shadow)
	w["shadow"] = shadow
	var lab := Label3D.new()
	lab.text = "!"
	lab.font = font
	lab.font_size = 140
	lab.modulate = Color(1, 0.3, 0.2)
	lab.outline_size = 18
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.visible = false
	world_node(lab)
	w["bang"] = lab
	line_mesh = ImmediateMesh.new()
	line_node = MeshInstance3D.new()
	line_node.mesh = line_mesh
	var lm := StandardMaterial3D.new()
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm.albedo_color = Color(1, 1, 1, 0.9)
	line_node.material_override = lm
	line_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world_node(line_node)
	w["jerk"] = 0.0
	w["last_step"] = 0
	w["splash_t"] = 0.0

func update_fish_world(delta: float) -> void:
	if not mg_world or not w.has("bobber"):
		return
	var bob: Node3D = w["bobber"]
	var base: Vector3 = w["bob_at"]
	var shadow: Node3D = w["shadow"]
	var bang: Label3D = w["bang"]
	w["jerk"] = maxf(0.0, float(w["jerk"]) - delta * 3.0)
	var target := base
	if mg_step == 0:
		var nib := 0.03 if fmod(mg_phase, 1.7) < 0.15 else 0.0
		bob.visible = true
		bob.position = base + Vector3(0, sin(mg_phase * 2.2) * 0.015 - nib, 0)
		shadow.visible = false
		bang.visible = false
		if nib > 0.0 and rng.randf() < 0.1:
			ripple3d(base, 0.5)
	elif mg_step == 1:
		bob.position = base + Vector3(0, -0.08, 0)
		bang.visible = true
		bang.position = base + Vector3(0, 0.75 + sin(anim_t * 20.0) * 0.05, 0)
		if rng.randf() < delta * 6.0:
			ripple3d(base, 0.8)
	else:
		bob.visible = false
		bang.visible = false
		shadow.visible = true
		var fx := (mg_trail - 0.5) * 3.4
		var fz := sin(mg_phase * 2.3) * 0.9
		target = POND_C + Vector3(1.0 + fz * 0.4, 0.07, fx)
		shadow.position = target
		shadow.rotation.y = atan2(mg_dir - mg_trail, 0.2) * 0.8
		w["splash_t"] = float(w["splash_t"]) - delta
		if float(w["splash_t"]) <= 0.0:
			w["splash_t"] = rng.randf_range(0.35, 0.8)
			splash3d(target)
			sfx("splash", rng.randf_range(1.2, 1.5))
		target += Vector3(0, 0.02, 0)
	# 낚싯줄
	var tip := tool_tip(2.3)
	var end := bob.position + Vector3(0, 0.06, 0) if mg_step < 2 else target
	line_mesh.clear_surfaces()
	line_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	var sag := 0.25 if mg_step < 2 else 0.05
	for i in 13:
		var t := i / 12.0
		var p := tip.lerp(end, t) - Vector3(0, sag * sin(t * PI), 0)
		line_mesh.surface_add_vertex(p)
	line_mesh.surface_end()

func fish_world_hooked() -> void:
	if not mg_world:
		return
	w["jerk"] = 1.0
	cam_kick = 0.3
	hit_stop(0.05)
	splash3d(w["bob_at"], true)

# 낚아 올린 물고기가 물에서 튀어 올라 품으로 와요
func fish_leap(kind: int) -> void:
	var f: Dictionary = FISH[kind]
	var col: Color = f["col"]
	var fish := Node3D.new()
	add_child(fish)
	var ln: float = f["len"]
	add_blobs(fish, [
		[Vector3.ZERO, Vector3(0.5 * ln, 0.22, 0.14), col],
		[Vector3(-0.3 * ln, 0, 0), Vector3(0.16, 0.18, 0.05), col.darkened(0.15)],
		[Vector3(0.18 * ln, 0.04, 0.06), Vector3(0.05, 0.05, 0.03), Color(0.05, 0.05, 0.05)],
		[Vector3(0.18 * ln, 0.04, -0.06), Vector3(0.05, 0.05, 0.03), Color(0.05, 0.05, 0.05)],
	], blob_gloss())
	var from: Vector3 = POND_C + Vector3(1.0, 0.1, 0.3)
	var to := player.position + Vector3(0, 1.3, 0)
	fish.position = from
	splash3d(from, true)
	sfx("splash", 0.9)
	var tw := fish.create_tween()
	tw.tween_method(func(t):
		fish.position = from.lerp(to, t) + Vector3(0, sin(t * PI) * 1.6, 0)
		fish.rotation = Vector3(0, 0, sin(t * 12.0) * 0.6 + t * 6.0), 0.0, 1.0, 0.7)
	tw.tween_callback(func():
		burst3d(fish.position, Color(1, 0.9, 0.4), 18)
		sfx("coin"))
	tw.tween_property(fish, "scale", Vector3(0.01, 0.01, 0.01), 0.25)
	tw.tween_callback(fish.queue_free)

# 오른쪽 힘겨루기 칸 (낚시)
func draw_reel_meter(ci: CanvasItem) -> void:
	var w2 := mg_overlay.size.x
	var h := mg_overlay.size.y
	var mx := w2 * 0.88
	var y0 := h * 0.4
	var y1 := h * 0.82
	var span := y1 - y0
	d_box(ci, Vector2(mx, (y0 + y1) / 2.0), Vector2(54, span + 20), 0.0, Color(0.62, 0.45, 0.28), 4)
	d_box(ci, Vector2(mx, (y0 + y1) / 2.0), Vector2(38, span), 0.0, Color(0.3, 0.5, 0.66), 0.0)
	var hard: float = FISH[fish_kind]["hard"]
	var half := lerpf(0.16, 0.1, hard)
	var zone_c := y1 - mg_off * span
	var inside := mg_step == 2
	var z_top := maxf(zone_c - half * span, y0)
	var z_bot := minf(zone_c + half * span, y1)
	d_box(ci, Vector2(mx, (z_top + z_bot) / 2.0), Vector2(40, z_bot - z_top), 0.0, Color(0.45, 0.9, 0.45, 0.85) if inside else Color(0.6, 0.85, 0.5, 0.6), 3)
	draw_fish2d(ci, Vector2(mx, y1 - mg_trail * span), 17, fish_kind, -PI / 2.0 + sin(anim_t * 10.0) * 0.3, true)

func scene_setup(scene: String) -> void:
	w["scene"] = scene
	w["seen"] = {}
	w["count0"] = mg_count
	w["lives0"] = mg_lives
	match scene:
		"heal":
			var nest := Vector3(-15.2, 0, 0.7)
			var stand := Vector3(-13.6, 0, 3.4)
			var table := stand + Vector3(-0.15, 0, -0.75)
			world_game_begin(stand, table, table + Vector3(1.0, 1.25, -1.15), table + Vector3(-0.05, 0.6, 0.35))
			# 소반 위에 다친 제비
			var tb := Node3D.new()
			tb.position = table
			world_node(tb)
			add_mcyl(tb, wood_mat, 0.42, 0.42, 0.05, Vector3(0, 0.42, 0))
			for k in 4:
				var a := k * TAU / 4.0 + 0.4
				add_mcyl(tb, dark_wood_mat, 0.035, 0.03, 0.4, Vector3(cos(a) * 0.3, 0.2, sin(a) * 0.3))
			var bird := Node3D.new()
			bird.position = table + Vector3(0, 0.5, 0)
			bird.rotation.y = 0.6
			world_node(bird)
			var navy := Color(0.17, 0.2, 0.38)
			add_blobs(bird, [
				[Vector3(0, 0.1, 0), Vector3(0.26, 0.17, 0.34), navy],
				[Vector3(0, 0.07, 0.03), Vector3(0.18, 0.11, 0.24), Color(0.97, 0.95, 0.9)],
				[Vector3(0, 0.2, 0.15), Vector3(0.16, 0.15, 0.15), navy],
				[Vector3(0, 0.18, 0.24), Vector3(0.05, 0.04, 0.07), Color(1, 0.6, 0.2)],
				[Vector3(0.06, 0.22, 0.2), Vector3(0.035, 0.035, 0.035), Color(0.05, 0.05, 0.05)],
				[Vector3(-0.06, 0.22, 0.2), Vector3(0.035, 0.035, 0.035), Color(0.05, 0.05, 0.05)],
				[Vector3(0, 0.12, -0.24), Vector3(0.08, 0.03, 0.22), navy, Vector3(10, 18, 0)],
				[Vector3(0, 0.12, -0.24), Vector3(0.08, 0.03, 0.22), navy, Vector3(10, -18, 0)],
			], blob_gloss())
			var wl := add_blobs(bird, [[Vector3(0.14, 0.14, -0.02), Vector3(0.08, 0.04, 0.26), navy.lightened(0.1), Vector3(0, 0, -25)]], blob_gloss())
			var wr := add_blobs(bird, [[Vector3(-0.14, 0.14, -0.02), Vector3(0.08, 0.04, 0.26), navy.lightened(0.1), Vector3(0, 0, 25)]], blob_gloss())
			# 다친 다리 + 부목
			add_beam(bird, make_color(Color(0.85, 0.55, 0.35)), Vector3(0.05, 0.03, 0.02), Vector3(0.12, -0.02, 0.1), 0.02, 0.02)
			add_beam(bird, wood_mat, Vector3(0.07, 0.04, 0.0), Vector3(0.15, -0.01, 0.13), 0.035, 0.012)
			w["bird"] = bird
			w["wings"] = [wl, wr]
			w["threads"] = []
		"straw":
			var hay := job_spot("shoes").position
			var stand := hay + Vector3(0.6, 0, 1.6)
			var mat_at := stand + Vector3(-0.1, 0, -0.65)
			world_game_begin(stand, mat_at, mat_at + Vector3(2.7, 1.9, 1.3), mat_at + Vector3(-0.1, 0.5, 0.3), job_spot("shoes"))
			var sandal := Node3D.new()
			sandal.position = mat_at + Vector3(0, 0.36, 0)
			world_node(sandal)
			add_mbox(sandal, thatch_dark_mat, Vector3(0.7, 0.06, 0.5), Vector3(0, -0.04, 0))
			var sole := Node3D.new()
			sandal.add_child(sole)
			add_blobs(sole, [[Vector3(0, 0, 0), Vector3(0.18, 0.04, 0.4), Color(0.9, 0.76, 0.46)], [Vector3(0, 0.04, -0.08), Vector3(0.14, 0.05, 0.16), Color(0.85, 0.7, 0.42)]], thatch_blob_mat)
			w["sole"] = sole
			var twist := Node3D.new()
			twist.position = Vector3(0, 0.12, 0.25)
			sandal.add_child(twist)
			for k in 6:
				var tor := MeshInstance3D.new()
				var tm := TorusMesh.new()
				tm.inner_radius = 0.025
				tm.outer_radius = 0.05
				tor.mesh = tm
				tor.material_override = thatch_dark_mat
				tor.position = Vector3(0, 0, -k * 0.05)
				tor.rotation.x = PI / 2.0 + k * 0.4
				twist.add_child(tor)
			w["twist"] = twist
		"ong":
			var jar := Vector3(29, 0, -10)
			var stand := jar + Vector3(-1.05, 0, 0.95)
			world_game_begin(stand, jar + Vector3(0, 0, 0.4), jar + Vector3(0.9, 1.5, 2.9), jar + Vector3(-0.3, 0.75, 0.4))
			for c in ong_cracks:
				world_hide(c)
			var patch := blob_node([[Vector3.ZERO, Vector3(0.34, 0.5, 0.06), Color(0.62, 0.45, 0.3)]])
			patch.position = jar + Vector3(-0.05, 0.66, 0.52)
			patch.scale = Vector3(0.05, 0.05, 1)
			w["patch"] = patch
			w["crack_on"] = []
			var cr := make_color(Color(0.15, 0.1, 0.08))
			var c0 := jar + Vector3(-0.1, 0.85, 0.53)
			w["crack_on"].append(world_node(add_beam(self, cr, c0, c0 + Vector3(0.12, -0.2, 0.02), 0.025, 0.02)))
			w["crack_on"].append(world_node(add_beam(self, cr, c0 + Vector3(0.12, -0.2, 0.02), c0 + Vector3(0.02, -0.4, 0.04), 0.025, 0.02)))
			var trowel := blob_node([[Vector3.ZERO, Vector3(0.16, 0.04, 0.24), Color(0.55, 0.57, 0.6)], [Vector3(0, 0.06, -0.14), Vector3(0.04, 0.12, 0.04), Color(0.55, 0.38, 0.22)]], blob_gloss())
			w["trowel"] = trowel
			w["jar_c"] = jar + Vector3(-0.05, 0.66, 0.58)
		"saw":
			var g: Node3D = saw_thing["node"]
			var gp := g.position
			# 박의 실제 높이를 재서 톱을 꼭대기에 올려요
			var top_y := 0.0
			for mi in g.find_children("*", "GeometryInstance3D", true, false):
				if mi is Label3D:
					continue
				var gi := mi as GeometryInstance3D
				var bb := gi.get_aabb()
				var tr: Transform3D = g.global_transform.affine_inverse() * gi.global_transform
				top_y = maxf(top_y, (tr * (bb.position + bb.size)).y)
			var rad: float = maxf(0.5, top_y / 2.0) if top_y > 0.1 else g.get_meta("radius", 1.2)
			w["rad"] = rad
			var stand := gp + Vector3(rad + 0.75, 0, 0.0)
			world_game_begin(stand, gp, gp + Vector3(0.4, rad * 2.0 + 1.6, rad * 2.0 + 4.6), gp + Vector3(0.0, rad * 1.1, 0.0))
			if npcs.has("heungbu"):
				world_move(npcs["heungbu"], gp + Vector3(-rad - 0.75, 0, 0.0), gp)
			var saw := Node3D.new()
			saw.position = gp + Vector3(0, rad * 2.0, 0.0)
			world_node(saw)
			add_mbox(saw, make_color(Color(0.42, 0.44, 0.5)), Vector3(rad * 2.0 + 1.4, 0.3, 0.04), Vector3(0, 0, 0))
			add_mbox(saw, make_color(Color(0.8, 0.82, 0.86)), Vector3(rad * 2.0 + 1.4, 0.05, 0.05), Vector3(0, -0.15, 0))
			for sx in [-(rad + 0.7), rad + 0.7]:
				add_mcyl(saw, wood_mat, 0.04, 0.04, 0.35, Vector3(sx, 0.1, 0))
			w["saw"] = saw
			w["gp"] = gp
			var cut := MeshInstance3D.new()
			var cb := BoxMesh.new()
			cb.size = Vector3(0.9, 1.0, 0.05)
			cut.mesh = cb
			cut.material_override = make_color(Color(0.95, 0.95, 0.85))
			world_node(cut)
			w["cut"] = cut
			w["dir_last"] = 1.0
		"ditch":
			var pd := Vector3(-34.5, 0, -3)
			var dig := pd + Vector3(3.8, 0, 1.2)
			var stand := dig + Vector3(0.0, 0, 1.0)
			world_game_begin(stand, dig, dig + Vector3(2.2, 2.4, 3.6), dig + Vector3(-0.3, 0.4, 0))
			if npcs.has("park"):
				world_move(npcs["park"], dig + Vector3(-0.9, 0, 0.9), dig)
			hold_tool("shovel")
			var pile := blob_node([[Vector3.ZERO, Vector3(0.7, 0.4, 0.6), Color(0.45, 0.33, 0.22)]])
			pile.position = dig + Vector3(1.0, 0.0, -0.3)
			pile.scale = Vector3(0.2, 0.2, 0.2)
			w["pile"] = pile
			var ch := MeshInstance3D.new()
			var chm := BoxMesh.new()
			chm.size = Vector3(1, 0.02, 0.5)
			ch.mesh = chm
			ch.material_override = water_material(2, Vector4(0, 0, 0.5, 0.25), Color(0.3, 0.42, 0.4), Color(0.45, 0.58, 0.5), Vector2(0.1, 0.0), 0.3)
			world_node(ch)
			w["channel"] = ch
			w["dig"] = dig
			w["pd"] = pd
		"snake":
			var nest := Vector3(-15.08, 2.0, 0.2)
			var stand := Vector3(-12.5, 0, 1.3)
			world_game_begin(stand, nest * Vector3(1, 0, 1), Vector3(-11.2, 2.7, 5.4), Vector3(-14.7, 0.9, 0.9))
			if npcs.has("heungbu"):
				world_move(npcs["heungbu"], Vector3(-10.6, 0, -0.6), nest * Vector3(1, 0, 1))
			hold_tool("stick")
			w["nest"] = nest
		"kim":
			var pumps := [Vector3(-26.5, 0, 16.8), Vector3(-22.3, 0, 17), Vector3(-25, 0, 18.5)]
			var mid: Vector3 = (pumps[0] + pumps[1] + pumps[2]) / 3.0
			var stand := mid + Vector3(2.4, 0, 0.6)
			world_game_begin(stand, mid, mid + Vector3(6.6, 4.8, 2.0), mid + Vector3(0.3, 0.2, 0.2))
			w["pumps"] = pumps
		"sparrow":
			var stand := FARM_C + Vector3(-5.2, 0, 1.6)
			world_game_begin(stand, FARM_C, FARM_C + Vector3(-8.4, 5.6, 5.4), FARM_C + Vector3(-1.2, 0.3, 0.6))
			for s2 in sparrows:
				world_hide(s2[0])
		"rice":
			var wife: Node3D = npcs["wife"]
			var wp := wife.position
			for lb in wife.find_children("*", "Label3D", true, false):
				world_hide(lb)
			var stand := wp + Vector3(0, 0, 2.6)
			world_game_begin(stand, wp, wp + Vector3(0.0, 2.3, 7.4), wp + Vector3(0, 2.9, 1.4))
			var bowl := blob_node([[Vector3.ZERO, Vector3(0.6, 0.22, 0.6), Color(0.86, 0.76, 0.5)], [Vector3(0, 0.08, 0), Vector3(0.48, 0.08, 0.48), Color(0.98, 0.97, 0.92)]], thatch_blob_mat)
			w["bowl"] = bowl
			w["items"] = {}
			w["center"] = stand
			w["depth"] = cam_depth_of(stand + Vector3(0, 2.4, 0), wp + Vector3(0.0, 2.3, 7.4))
		"plant":
			var stand := FARM_C + Vector3(-3.0, 0, 1.2)
			world_game_begin(stand, stand + Vector3(1, 0, -0.9), stand + Vector3(5.6, 3.4, -0.9), stand + Vector3(1.2, 0.3, -0.9))
			var line := MeshInstance3D.new()
			var lb := BoxMesh.new()
			lb.size = Vector3(0.02, 0.02, 2.6)
			line.mesh = lb
			line.material_override = make_color(Color(0.95, 0.9, 0.75))
			world_node(line)
			w["rope"] = line
			var marks := []
			for k in 4:
				var mk := blob_node([[Vector3.ZERO, Vector3(0.07, 0.07, 0.07), Color(0.9, 0.2, 0.15)]])
				marks.append(mk)
			w["marks"] = marks
			var bundle := blob_node([[Vector3(0, 0.15, 0), Vector3(0.12, 0.35, 0.12), Color(0.45, 0.72, 0.3)], [Vector3(0, 0.0, 0), Vector3(0.1, 0.1, 0.1), Color(0.99, 0.83, 0.69)]])
			w["bundle"] = bundle
			var ring := MeshInstance3D.new()
			var tm := TorusMesh.new()
			tm.inner_radius = 0.2
			tm.outer_radius = 0.3
			tm.rings = 32
			ring.mesh = tm
			var rmat := StandardMaterial3D.new()
			rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			rmat.albedo_color = Color(1.0, 0.85, 0.15)
			rmat.no_depth_test = true
			rmat.render_priority = 5
			ring.material_override = rmat
			ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			world_node(ring)
			w["ring"] = ring
			w["planted"] = []
			w["base"] = stand + Vector3(0.9, 0, -1.0)
			farm_stages_hidden_for_plant()
			if has_node("Scarecrow"):
				world_hide(get_node("Scarecrow"))

func farm_stages_hidden_for_plant() -> void:
	for st in farm_stages:
		world_hide(st)

func plant_world_pos(row: int, col: int) -> Vector3:
	var base: Vector3 = w["base"]
	return base + Vector3(row * 0.75, 0.12, (1.5 - col) * 0.55)


# ---------- 남쪽 들판: 연못 낚시터와 최 영감네 논 ----------
func make_south() -> void:
	make_fishing_pond()
	make_farm()

func make_fishing_pond() -> void:
	var c := POND_C
	var rx := 5.6
	var rz := 4.0
	var r := RandomNumberGenerator.new()
	r.seed = 33
	var none := Color(0, 0, 0, 0)
	flat_ellipse(c, rx, rz, 0.06, water_material(1, Vector4(c.x, c.z, rx, rz), Color(0.12, 0.36, 0.52), Color(0.42, 0.68, 0.72)))
	# 물가 돌 (나루터 쪽은 비워요)
	var stones := []
	var a := 0.0
	while a < TAU:
		a += r.randf_range(0.18, 0.3)
		if absf(wrapf(a, -PI, PI)) < 0.3:
			continue
		var k := r.randf_range(0.0, 0.35)
		stones.append([c + Vector3(cos(a) * (rx + 0.3 + k), 0.08, sin(a) * (rz + 0.3 + k)), Vector3(r.randf_range(0.5, 1.0), r.randf_range(0.3, 0.55), r.randf_range(0.45, 0.8)), stone_color(r)])
	add_blobs(self, stones, stone_blob_mat)
	# 갈대와 부들
	var reeds := []
	for ang in [2.2, 2.55, 3.5, 3.9, 1.3, 4.9, 5.4]:
		var base := c + Vector3(cos(ang) * rx * 0.93, 0, sin(ang) * rz * 0.93)
		for i in 7:
			var p := base + Vector3(r.randf_range(-0.5, 0.5), 0, r.randf_range(-0.4, 0.4))
			var hgt := r.randf_range(0.9, 1.5)
			var tilt := Vector3(r.randf_range(-12, 12), 0, r.randf_range(-12, 12))
			reeds.append([p + Vector3(0, hgt * 0.5, 0), Vector3(0.05, hgt, 0.05), Color(0.42, 0.62, 0.28), tilt])
			if i % 2 == 0:
				reeds.append([p + Vector3(0, hgt * 0.85, 0), Vector3(0.1, 0.3, 0.1), Color(0.48, 0.3, 0.16), tilt])
			else:
				reeds.append([p + Vector3(0.06, hgt * 0.35, 0), Vector3(0.16, hgt * 0.6, 0.04), Color(0.5, 0.7, 0.32), tilt + Vector3(0, 0, 18)])
	add_blobs(self, reeds)
	# 연잎과 연꽃
	var pads := []
	for i in 9:
		var pa := r.randf_range(0.5, TAU - 0.5)
		var pr := r.randf_range(0.35, 0.8)
		var p := c + Vector3(cos(pa) * rx * pr, 0.085, sin(pa) * rz * pr)
		pads.append([p, Vector3(0.75, 0.04, 0.65), Color(0.36, 0.62, 0.3).lerp(Color(0.48, 0.7, 0.34), r.randf())])
		if i % 3 == 0:
			pads.append([p + Vector3(0.1, 0.08, 0), Vector3(0.24, 0.16, 0.24), Color(1.0, 0.7, 0.8)])
			pads.append([p + Vector3(0.1, 0.14, 0), Vector3(0.1, 0.08, 0.1), Color(1.0, 0.92, 0.5)])
	add_blobs(self, pads, null, true)
	# 나루터 (나무 발판)
	for i in 8:
		var plank := add_mbox(self, plank_mat, Vector3(0.42, 0.08, 1.45 + r.randf_range(-0.08, 0.08)), Vector3(c.x + rx + 0.3 - i * 0.48, 0.12, c.z + r.randf_range(-0.04, 0.04)))
		plank.rotation.y = r.randf_range(-0.04, 0.04)
	for px in [c.x + rx - 3.0, c.x + rx - 1.4]:
		for pz in [-0.72, 0.72]:
			add_mcyl(self, dark_wood_mat, 0.07, 0.08, 0.7, Vector3(px, 0.1, c.z + pz))
	# 꽂아 둔 낚싯대와 동동 뜬 찌
	var tip := Vector3(c.x + rx - 4.6, 1.9, c.z + 1.3)
	pond_deco.append(add_beam(self, make_color(Color(0.55, 0.42, 0.22)), Vector3(c.x + rx - 2.8, 0.2, c.z + 0.6), tip, 0.04, 0.04))
	var bob_pos := Vector3(c.x + rx - 5.4, 0.1, c.z + 1.6)
	pond_deco.append(add_beam(self, make_color(Color(0.95, 0.95, 0.95)), tip, bob_pos, 0.012, 0.012))
	var bob := Node3D.new()
	bob.position = bob_pos
	add_child(bob)
	add_ball(bob, Color(0.9, 0.2, 0.2), 0.08, Vector3(0, 0.04, 0))
	add_ball(bob, Color(1, 1, 1), 0.07, Vector3(0, -0.02, 0))
	sway_items.append([bob, bob_pos, 0, 1.3, 0.0])
	pond_deco.append(bob)
	# 물이 막아요 (나루터 자리는 열어 둬요)
	add_solid(Vector3(c.x - 0.8, 1, c.z), Vector3(8.0, 2, 6.0), none)
	add_solid(Vector3(c.x - 5.2, 1, c.z), Vector3(0.8, 2, 3.4), none)
	add_solid(Vector3(c.x + 4.2, 1, c.z - 1.67), Vector3(2.0, 2, 1.85), none)
	add_solid(Vector3(c.x + 4.2, 1, c.z + 1.68), Vector3(2.0, 2, 1.85), none)
	var spot := make_spot(Vector3(c.x + rx - 2.0, 0, c.z), "fish", "", tr("낚시터"), true)
	spot.visible = true
	make_basket(Vector3(c.x + rx + 0.9, 0, c.z - 1.3), 0.9, Color(0.62, 0.68, 0.74))
	make_npc("fisher", tr("강태공"), Color(0.5, 0.6, 0.66), Vector3(c.x + rx + 1.6, 0, c.z + 2.0), 1.0, true)
	make_tree(Vector3(c.x - 5.8, 0, c.z - 4.8), "Willow0")
	make_tree(Vector3(c.x - 6.3, 0, c.z + 4.6), "Willow0")
	house_rects.append(Rect2(c.x - rx - 0.4, c.z - rz - 0.4, rx * 2.0 + 0.8, rz * 2.0 + 0.8))

func make_farm() -> void:
	var c := FARM_C
	var w := 9.0
	var d := 7.0
	var r := RandomNumberGenerator.new()
	r.seed = 44
	var earth := make_tex_material(Color(0.5, 0.42, 0.3), plaster_tex, 0.4)
	add_mbox(self, earth, Vector3(w + 0.5, 0.25, 0.5), c + Vector3(0, 0.12, d / 2.0))
	add_mbox(self, earth, Vector3(w + 0.5, 0.25, 0.5), c + Vector3(0, 0.12, -d / 2.0))
	add_mbox(self, earth, Vector3(0.5, 0.25, d), c + Vector3(w / 2.0, 0.12, 0))
	add_mbox(self, earth, Vector3(0.5, 0.25, d), c + Vector3(-w / 2.0, 0.12, 0))
	add_mbox(self, earth, Vector3(0.4, 0.2, d), c + Vector3(0, 0.1, 0))
	add_mbox(self, make_color(Color(0.42, 0.34, 0.24)), Vector3(w - 0.4, 0.04, d - 0.4), c + Vector3(0, 0.02, 0))
	var pmat := water_material(2, Vector4(c.x, c.z, w / 2.0 - 0.2, d / 2.0 - 0.2), Color(0.3, 0.3, 0.2), Color(0.46, 0.42, 0.3), Vector2.ZERO, 0.12)
	pmat.set_shader_parameter("spec", 0.25)
	pmat.set_shader_parameter("rough", 0.3)
	pmat.set_shader_parameter("mud", 1.0)
	var wtr := add_mbox(self, pmat, Vector3(w - 0.4, 0.02, d - 0.4), c + Vector3(0, 0.08, 0))
	wtr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# 자라는 단계마다 벼 모양을 따로 만들어 두고 바꿔 보여 줘요
	var young := []
	var green := []
	var gold := []
	var nx := 12
	var nz := 8
	for ix in nx:
		for iz in nz:
			var p := c + Vector3(-w / 2.0 + 0.55 + ix * (w - 1.1) / (nx - 1), 0, -d / 2.0 + 0.55 + iz * (d - 1.1) / (nz - 1))
			if absf(p.x - c.x) < 0.4 or (absf(p.x - c.x - 1.5) < 0.55 and absf(p.z - c.z) < 0.55):
				continue
			p += Vector3(r.randf_range(-0.05, 0.05), 0, r.randf_range(-0.05, 0.05))
			young.append([p + Vector3(0, 0.2, 0), Vector3(0.09, 0.28, 0.09), Color(0.5, 0.76, 0.32)])
			young.append([p + Vector3(0.04, 0.22, 0), Vector3(0.045, 0.24, 0.045), Color(0.6, 0.82, 0.38), Vector3(0, 0, -22)])
			var rot := r.randf_range(0, 180)
			for k in 3:
				var lean := Vector3(0, rot + k * 60.0, -14.0 + k * 14.0)
				green.append([p + Vector3((k - 1) * 0.06, 0.4, 0), Vector3(0.07, 0.8, 0.07), Color(0.36, 0.62, 0.25).lerp(Color(0.5, 0.74, 0.32), k / 2.0), lean])
				gold.append([p + Vector3((k - 1) * 0.06, 0.38, 0), Vector3(0.06, 0.76, 0.06), Color(0.8, 0.68, 0.3).lerp(Color(0.9, 0.78, 0.36), k / 2.0), lean])
			# 고개 숙인 이삭
			for k in 2:
				var sx := -1.0 if k == 0 else 1.0
				gold.append([p + Vector3(sx * 0.13, 0.74, 0.0), Vector3(0.09, 0.22, 0.07), Color(0.98, 0.82, 0.34), Vector3(0, rot, sx * -50.0)])
	farm_stages = [add_blobs(self, young), add_blobs(self, green), add_blobs(self, gold)]
	# 논두렁에 난 풀
	var bank_mm := MultiMesh.new()
	bank_mm.transform_format = MultiMesh.TRANSFORM_3D
	bank_mm.use_colors = true
	bank_mm.mesh = make_tuft_mesh()
	var tufts := []
	for k in 70:
		var side := k % 5
		var t := r.randf_range(-0.5, 0.5)
		var q := Vector3.ZERO
		match side:
			0: q = Vector3(t * w, 0.25, d / 2.0 + r.randf_range(-0.15, 0.15))
			1: q = Vector3(t * w, 0.25, -d / 2.0 + r.randf_range(-0.15, 0.15))
			2: q = Vector3(w / 2.0 + r.randf_range(-0.15, 0.15), 0.25, t * d)
			3: q = Vector3(-w / 2.0 + r.randf_range(-0.15, 0.15), 0.25, t * d)
			_: q = Vector3(r.randf_range(-0.12, 0.12), 0.2, t * d)
		tufts.append(c + q)
	bank_mm.instance_count = tufts.size()
	for k in tufts.size():
		var bs := Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3.ONE * r.randf_range(0.5, 0.9))
		bank_mm.set_instance_transform(k, Transform3D(bs, tufts[k]))
		bank_mm.set_instance_color(k, Color(0.42, 0.66, 0.32).lerp(Color(0.62, 0.82, 0.42), r.randf()))
	var bank_mi := MultiMeshInstance3D.new()
	bank_mi.multimesh = bank_mm
	bank_mi.material_override = grass_material()
	bank_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bank_mi)
	# 허수아비
	var sc := Node3D.new()
	sc.name = "Scarecrow"
	sc.position = c + Vector3(1.5, 0, 0)
	sc.rotation.y = -0.4
	add_child(sc)
	var pole := make_color(Color(0.55, 0.4, 0.24))
	add_mcyl(sc, pole, 0.06, 0.07, 2.1, Vector3(0, 1.05, 0))
	add_beam(sc, pole, Vector3(-0.95, 1.45, 0), Vector3(0.95, 1.45, 0), 0.08, 0.08)
	add_mbox(sc, plaster_mat(Color(0.78, 0.66, 0.5)), Vector3(0.75, 0.75, 0.4), Vector3(0, 1.28, 0))
	add_mbox(sc, make_color(Color(0.55, 0.62, 0.78)), Vector3(0.25, 0.22, 0.42), Vector3(0.18, 1.18, 0.0))
	add_mbox(sc, plaster_mat(Color(0.78, 0.66, 0.5)), Vector3(1.5, 0.22, 0.3), Vector3(0, 1.48, 0))
	add_blobs(sc, [
		[Vector3(0, 1.98, 0), Vector3(0.55, 0.55, 0.5), Color(0.96, 0.88, 0.62)],
		[Vector3(-0.85, 1.42, 0), Vector3(0.28, 0.2, 0.2), Color(0.95, 0.85, 0.55)],
		[Vector3(0.85, 1.42, 0), Vector3(0.28, 0.2, 0.2), Color(0.95, 0.85, 0.55)],
		[Vector3(0, 0.88, 0), Vector3(0.6, 0.18, 0.36), Color(0.95, 0.85, 0.55)],
	], thatch_blob_mat)
	# 밀짚모자, 얼굴
	add_mcyl(sc, thatch_dark_mat, 0.52, 0.55, 0.04, Vector3(0, 2.2, 0))
	add_mcyl(sc, thatch_dark_mat, 0.16, 0.26, 0.22, Vector3(0, 2.33, 0))
	for ex in [-0.11, 0.11]:
		add_ball(sc, Color(0.15, 0.1, 0.08), 0.045, Vector3(ex, 2.02, 0.25))
		add_ball(sc, Color(1.0, 0.55, 0.55), 0.05, Vector3(ex * 1.7, 1.93, 0.22))
	add_beam(sc, make_color(Color(0.5, 0.2, 0.15)), Vector3(-0.08, 1.88, 0.26), Vector3(0.08, 1.88, 0.26), 0.02, 0.02)
	sway_items.append([sc, sc.position, 1, 2.0, 0.025])
	# 참새 (참새 떼가 몰려오면 보여요)
	for i in 6:
		var sp := Node3D.new()
		var pos := c + Vector3(r.randf_range(-3.6, 3.6), 0.95, r.randf_range(-2.8, 2.8))
		sp.position = pos
		sp.rotation.y = r.randf() * TAU
		add_child(sp)
		add_blobs(sp, [
			[Vector3(0, 0, 0), Vector3(0.26, 0.2, 0.32), Color(0.6, 0.42, 0.28)],
			[Vector3(0, 0.1, 0.13), Vector3(0.17, 0.16, 0.16), Color(0.55, 0.32, 0.2)],
			[Vector3(0, 0.07, 0.18), Vector3(0.12, 0.08, 0.08), Color(0.98, 0.95, 0.9)],
			[Vector3(0, 0.02, -0.2), Vector3(0.1, 0.05, 0.16), Color(0.45, 0.3, 0.2)],
			[Vector3(0, 0.1, 0.23), Vector3(0.05, 0.04, 0.06), Color(0.3, 0.25, 0.2)],
		])
		sp.visible = false
		sparrows.append([sp, pos])
	# 논 앞 팻말, 논 주인, 볏짚단
	make_spot(Vector3(c.x - w / 2.0 - 0.9, 0, c.z), "farm", "", tr("최 영감네 논"), true)
	make_npc("choi", tr("최 영감"), Color(0.62, 0.55, 0.42), Vector3(c.x - w / 2.0 - 1.8, 0, c.z - 3.4), 1.0, true)
	var stack := Node3D.new()
	stack.position = c + Vector3(w / 2.0 + 1.8, 0, -2.2)
	add_child(stack)
	make_haystack_visual(stack)
	add_solid(stack.position + Vector3(0, 0.4, 0), Vector3(1.6, 0.8, 1.2), Color(0, 0, 0, 0))
	house_rects.append(Rect2(c.x - w / 2.0 - 0.4, c.z - d / 2.0 - 0.4, w + 0.8, d + 0.8))
	farm_visual()

func farm_visual() -> void:
	if farm_stages.size() < 3:
		return
	var stage := -1
	if farm_state == 1 or farm_state == 2:
		stage = 0
	elif farm_state == 3:
		stage = 1
	elif farm_state == 4:
		stage = 2
	for i in 3:
		(farm_stages[i] as Node3D).visible = (i == stage)
	for s in sparrows:
		(s[0] as Node3D).visible = farm_state == 2

func update_south(delta: float) -> void:
	update_walk_hint(delta)
	update_wild(delta)
	if farm_state == 1 or farm_state == 3:
		farm_timer -= delta
		if farm_timer <= 0.0:
			farm_state += 1
			farm_visual()
			if farm_state == 2:
				float_text(tr("참새 떼가 논에 몰려왔어요!"), Vector2(short_side * 0.5, 300), Color(1, 0.9, 0.6), 1.0)
			else:
				float_text(tr("최 영감네 벼가 누렇게 익었어요!"), Vector2(short_side * 0.5, 300), Color(1, 0.9, 0.4), 1.0)
	if farm_state == 2:
		for i in sparrows.size():
			var node: Node3D = sparrows[i][0]
			var base: Vector3 = sparrows[i][1]
			var hop := absf(sin(anim_t * 5.0 + i * 1.7))
			node.position = base + Vector3(0, hop * 0.18, 0)
			node.rotation.x = 0.5 * maxf(0.0, sin(anim_t * 9.0 + i))

func farm_action_text() -> String:
	match farm_state:
		-1: return tr("논 살펴보기")
		0: return tr("모내기")
		2: return tr("참새 쫓기")
		4: return tr("벼 베기")
	return tr("벼 살펴보기")

# --- 저장 (도감은 다음에 와도 남아 있어요) ---

func load_south() -> void:
	var cf := ConfigFile.new()
	if cf.load("user://save.cfg") != OK:
		return
	var got: Array = cf.get_value("ch1", "fish", [])
	for i in mini(got.size(), fish_caught.size()):
		fish_caught[i] = int(got[i])
	fish_reward = cf.get_value("ch1", "fish_reward", false)
	harvests = cf.get_value("ch1", "harvests", 0)
	var hg: Array = cf.get_value("ch1", "herbs", [])
	for i in mini(hg.size(), herb_counts.size()):
		herb_counts[i] = int(hg[i])
	herb_reward = cf.get_value("ch1", "herb_reward", false)
	var sr: Array = cf.get_value("ch1", "story", [])
	for i in mini(sr.size(), story_read.size()):
		story_read[i] = bool(sr[i])

func save_south() -> void:
	var cf := ConfigFile.new()
	cf.load("user://save.cfg")
	cf.set_value("ch1", "fish", fish_caught)
	cf.set_value("ch1", "fish_reward", fish_reward)
	cf.set_value("ch1", "harvests", harvests)
	cf.set_value("ch1", "herbs", herb_counts)
	cf.set_value("ch1", "herb_reward", herb_reward)
	cf.set_value("ch1", "story", story_read)
	cf.save("user://save.cfg")

# --- 낚시 ---

func fish_kinds_found() -> int:
	var n := 0
	for k in fish_caught:
		if int(k) > 0:
			n += 1
	return n

func fish_book() -> String:
	var parts := []
	for i in FISH.size():
		if int(fish_caught[i]) > 0:
			parts.append(tr("%s %d마리") % [FISH[i]["name"], fish_caught[i]])
		else:
			parts.append("???")
	return tr("물고기 도감 %d/%d\n%s") % [fish_kinds_found(), FISH.size(), ", ".join(parts)]

func fish_how() -> Array:
	return [
		[tr("강태공"), tr("찌가 쏙 들어가면 바로 화면을 눌러 낚싯대를 채거라. 너무 일찍 채면 물고기가 놀라 도망간단다.")],
		[tr("강태공"), tr("물고기가 걸리면 화면을 꾹 눌렀다 뗐다 하며 초록 칸 안에 물고기를 붙잡아 두거라.")],
	]

func talk_fisher() -> void:
	if not fisher_met:
		fisher_met = true
		say([[tr("강태공"), tr("허허, 세월을 낚는 중이란다. 너도 한번 해 보겠느냐? 나루터 끝의 낚싯대를 쓰거라.")]] + fish_how() + [[tr("강태공"), tr("물고기는 모두 여섯 가지. 금빛 잉어는 나도 평생 두 번밖에 못 봤단다.")]], Callable())
		return
	var lines := [[tr("강태공"), fish_book()]]
	if fish_kinds_found() >= FISH.size():
		lines.append([tr("강태공"), tr("허허, 이 연못 물고기를 다 낚아 보다니! 네가 진짜 강태공이로구나.")])
	else:
		lines.append([tr("강태공"), tr("물고기마다 힘이 달라. 큰 놈일수록 초록 칸에 붙잡아 두기 어렵단다.")])
	say(lines, Callable())

func start_fishing() -> void:
	if not fisher_met:
		fisher_met = true
		say([[tr("강태공"), tr("낚시는 처음이냐? 내 알려 주마.")]] + fish_how(), start_fishing)
		return
	start_fishing3d()

func pick_fish() -> int:
	var total := 0
	for f in FISH:
		total += int(f["w"])
	var roll := rng.randi_range(1, total)
	for i in FISH.size():
		roll -= int(FISH[i]["w"])
		if roll <= 0:
			return i
	return 0

func fish_done(ok: bool, _good: bool) -> void:
	if not ok:
		say([["", tr("물고기가 모두 달아났다. 다시 해 보자.")]], Callable())
		return
	var f: Dictionary = FISH[fish_kind]
	var first := int(fish_caught[fish_kind]) == 0
	fish_caught[fish_kind] = int(fish_caught[fish_kind]) + 1
	var pay: int = f["pay"]
	earn(pay)
	var lines := []
	if first:
		lines.append(["", tr("%s를 낚았다! 처음 보는 물고기다. (물고기 도감 %d/%d)") % [f["name"], fish_kinds_found(), FISH.size()]])
	else:
		lines.append(["", tr("%s를 낚았다! (%d마리째)") % [f["name"], fish_caught[fish_kind]]])
	lines.append(["", tr("장터에 팔아 엽전 %d냥을 받았다.") % pay])
	if fish_kinds_found() >= FISH.size() and not fish_reward:
		fish_reward = true
		earn(50)
		lines.append([tr("강태공"), tr("허허! 여섯 가지 물고기를 다 낚았구나. 상으로 엽전 50냥을 주마!")])
	save_south()
	say(lines, Callable())

func fish_tap() -> void:
	var at := Vector2(mg_overlay.size.x * 0.42, mg_overlay.size.y * 0.58)
	if mg_step == 0:
		mg_lives -= 1
		mg_perfect = false
		mg_timer = rng.randf_range(1.6, 3.2)
		sfx("bad")
		shake(10)
		float_text(tr("너무 일찍 챘어요!"), at, Color(1, 0.6, 0.5), 1.1)
	elif mg_step == 1:
		mg_step = 2
		sfx("splash", rng.randf_range(0.9, 1.1))
		fish_world_hooked()
		mg_progress = 0.3
		mg_off = 0.25
		mg_trail = 0.3
		mg_dir = 0.5
		mg_speed = 0.0
		mg_frame_angle = 0.0
		sfx("good")
		shake(8)
		burst(at, Color(0.8, 0.95, 1.0), 10)
		float_text(tr("걸렸다!"), at, Color(1, 1, 1), 1.3)

func update_fish(delta: float) -> void:
	mg_phase += delta
	var at := Vector2(mg_overlay.size.x * 0.42, mg_overlay.size.y * 0.58)
	if mg_step == 0:
		mg_timer -= delta
		mg_info.text = tr("찌를 잘 보세요... | 남은 기회 %d") % mg_lives
		if mg_timer <= 0.0:
			fish_kind = pick_fish()
			mg_step = 1
			mg_timer = lerpf(0.95, 0.6, FISH[fish_kind]["hard"])
			sfx("pop", 0.7)
			shake(4)
	elif mg_step == 1:
		mg_timer -= delta
		mg_info.text = tr("지금이에요! 눌러요!")
		if mg_timer <= 0.0:
			mg_step = 0
			mg_timer = rng.randf_range(1.5, 3.2)
			float_text(tr("미끼만 먹고 갔어요..."), at, Color(1, 1, 1), 1.0)
	else:
		var hard: float = FISH[fish_kind]["hard"]
		if mg_touch:
			mg_speed += 2.6 * delta
		else:
			mg_speed -= 2.2 * delta
		mg_speed = clampf(mg_speed, -1.1, 1.1)
		mg_off += mg_speed * delta
		if mg_off <= 0.0 or mg_off >= 1.0:
			mg_off = clampf(mg_off, 0.0, 1.0)
			mg_speed = 0.0
		mg_frame_angle -= delta
		if mg_frame_angle <= 0.0:
			mg_dir = rng.randf_range(0.05, 0.95)
			mg_frame_angle = rng.randf_range(lerpf(1.5, 0.45, hard), lerpf(2.4, 1.0, hard))
		mg_trail = move_toward(mg_trail, mg_dir, delta * lerpf(0.22, 0.85, hard))
		mg_trail = clampf(mg_trail + sin(mg_phase * 9.0) * 0.004 * hard, 0.0, 1.0)
		var half := lerpf(0.16, 0.1, hard)
		if absf(mg_trail - mg_off) < half:
			mg_progress += delta / lerpf(2.4, 4.2, hard)
			mg_step = 2
		else:
			mg_progress -= delta * 0.2
			mg_step = 3
		if mg_progress <= 0.0:
			mg_lives -= 1
			mg_perfect = false
			mg_progress = 0.0
			mg_step = 0
			mg_timer = rng.randf_range(1.5, 3.0)
			sfx("bad")
			shake(14)
			flash(Color(1, 0.3, 0.3))
			float_text(tr("줄이 풀려 놓쳤어요!"), at, Color(1, 0.6, 0.5), 1.1)
		else:
			mg_info.text = tr("꾹 누르면 초록 칸이 올라가요 | 남은 기회 %d") % mg_lives

func draw_fish2d(ci: CanvasItem, c: Vector2, s: float, kind: int, rot: float, shadow: bool) -> void:
	var f: Dictionary = FISH[kind]
	var col: Color = f["col"]
	var ln: float = f["len"]
	var th: float = f["thin"]
	var ol := 3.0
	if shadow:
		col = Color(0.12, 0.22, 0.32, 0.45)
		ol = 0.0
	var wig := sin(anim_t * 12.0) * 0.25
	var tail := PackedVector2Array([c + Vector2(-s * ln * 0.75, 0).rotated(rot), c + Vector2(-s * ln * 1.25, -s * 0.38).rotated(rot + wig), c + Vector2(-s * ln * 1.2, s * 0.38).rotated(rot + wig)])
	d_poly(ci, tail, col.darkened(0.1), ol)
	d_ell(ci, c, s * ln * 0.85, s * th, col, rot, ol)
	if shadow:
		return
	d_ell(ci, c + Vector2(-s * 0.1, -s * th * 0.75).rotated(rot), s * 0.3, s * 0.12, col.darkened(0.15), rot, 2.0)
	d_ell(ci, c + Vector2(s * ln * 0.05, s * th * 0.35).rotated(rot), s * ln * 0.55, s * th * 0.4, col.lightened(0.3), rot, 0.0)
	var eye := c + Vector2(s * ln * 0.55, -s * th * 0.25).rotated(rot)
	ci.draw_circle(eye, s * 0.11, Color(1, 1, 1))
	ci.draw_circle(eye + Vector2(s * 0.02, 0).rotated(rot), s * 0.065, Color(0.1, 0.08, 0.08))
	if kind == 4:
		for k in [-1.0, 1.0]:
			d_line(ci, c + Vector2(s * ln * 0.8, s * 0.05).rotated(rot), c + Vector2(s * ln * 1.25, k * s * 0.35).rotated(rot), col.darkened(0.3), 3)
	if kind == 5:
		for k in 3:
			ci.draw_circle(c + Vector2((k - 1) * s * 0.35, -s * 0.05).rotated(rot), s * 0.08, Color(1, 1, 0.85, 0.8))

func draw_bobber(ci: CanvasItem, c: Vector2, s: float) -> void:
	d_line(ci, c + Vector2(0, -s * 1.3), c, Color(0.95, 0.4, 0.3), 4)
	d_ell(ci, c, s * 0.42, s * 0.55, Color(0.92, 0.25, 0.22), 0.0, 3.0)
	d_ell(ci, c + Vector2(0, s * 0.3), s * 0.42, s * 0.28, Color(1, 1, 0.97), 0.0, 2.0)

func draw_pond_scene(ci: CanvasItem) -> void:
	var w := mg_overlay.size.x
	var h := mg_overlay.size.y
	var pc := Vector2(w * 0.42, h * 0.6)
	var rx := w * 0.38
	var ry := h * 0.17
	d_ell(ci, pc, rx + 14, ry + 12, Color(0.56, 0.46, 0.32), 0.0, 0.0)
	d_ell(ci, pc, rx, ry, Color(0.42, 0.7, 0.9), 0.0, 4.0)
	d_ell(ci, pc + Vector2(0, ry * 0.15), rx * 0.6, ry * 0.5, Color(0.36, 0.62, 0.84), 0.0, 0.0)
	# 물결 반짝이
	for k in 5:
		var gx := pc.x + sin(anim_t * 0.6 + k * 1.9) * rx * 0.6
		var gy := pc.y + cos(k * 2.3) * ry * 0.6
		d_line(ci, Vector2(gx - 16, gy), Vector2(gx + 16, gy), Color(1, 1, 1, 0.45), 3)
	# 연잎
	for lp in [[-0.7, -0.3], [-0.55, 0.45], [0.65, 0.5], [0.72, -0.4]]:
		var lc := pc + Vector2(rx * lp[0], ry * lp[1])
		d_ell(ci, lc, 30, 16, Color(0.4, 0.66, 0.32), 0.0, 3.0)
		d_line(ci, lc, lc + Vector2(26, -6), Color(0.42, 0.7, 0.9), 4)
	ci.draw_circle(pc + Vector2(rx * 0.72, -ry * 0.4) + Vector2(-6, -8), 9, Color(1, 0.72, 0.82))
	# 갈대
	for rd in [-0.95, -0.88, -0.8, 0.86, 0.93]:
		var base := pc + Vector2(rx * rd, ry * 0.55)
		var top := base + Vector2(sin(anim_t * 1.3 + rd * 5.0) * 6.0, -h * 0.12)
		d_line(ci, base, top, Color(0.38, 0.58, 0.26), 5)
		d_ell(ci, top + Vector2(0, 14), 7, 20, Color(0.5, 0.32, 0.18), 0.0, 2.0)
	# 낚싯대와 줄
	var hold := Vector2(w * 0.06, h * 0.86)
	var bend := 0.0
	if mg_step >= 2:
		bend = 0.12 + sin(anim_t * 14.0) * 0.03
	var tip := hold + Vector2(w * 0.34, -h * 0.34).rotated(bend)
	var mid := hold.lerp(tip, 0.5) + Vector2(0, 20 + bend * 200.0)
	ci.draw_polyline(PackedVector2Array([hold, mid, tip]), Color(0.55, 0.38, 0.2), 9, true)
	d_ell(ci, hold + Vector2(10, -10), 16, 26, Color(0.6, 0.45, 0.25), -0.7, 3.0)
	var bob := pc + Vector2(0, -ry * 0.1)
	if mg_step == 0:
		var nibble := 0.0
		if fmod(mg_phase, 1.7) < 0.15:
			nibble = 5.0
		bob.y += sin(mg_phase * 2.2) * 4.0 + nibble
		d_line(ci, tip, bob + Vector2(0, -18), Color(1, 1, 1, 0.85), 2)
		draw_bobber(ci, bob, 18)
		ci.draw_polyline(ell_pts(bob + Vector2(0, 8), 30 + sin(mg_phase * 2.2) * 4.0, 8), Color(1, 1, 1, 0.5), 2, true)
	elif mg_step == 1:
		bob.y += 16
		d_line(ci, tip, bob + Vector2(0, -6), Color(1, 1, 1, 0.85), 2)
		d_line(ci, bob + Vector2(0, -6), bob + Vector2(0, -18), Color(0.95, 0.4, 0.3), 4)
		for k in 3:
			var rr := 20.0 + fmod(mg_phase * 70.0 + k * 22.0, 66.0)
			ci.draw_polyline(ell_pts(bob, rr, rr * 0.3), Color(1, 1, 1, 0.8 - rr / 90.0), 3, true)
		ci.draw_string(font, bob + Vector2(-16, -40), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, int(font_size * 2.0), Color(0.95, 0.25, 0.2))
	else:
		# 물고기가 이리저리 버둥대요 (그림자만 보여요)
		var fx := pc.x + (mg_trail - 0.5) * rx * 1.3
		var fpos := Vector2(fx, pc.y + sin(mg_phase * 3.0) * ry * 0.25)
		var dirv := signf(mg_dir - mg_trail)
		if dirv == 0.0:
			dirv = 1.0
		draw_fish2d(ci, fpos, 34, fish_kind, 0.0 if dirv > 0.0 else PI, true)
		d_line(ci, tip, fpos, Color(1, 1, 1, 0.9), 2)
		for k in 2:
			var rr := 26.0 + fmod(mg_phase * 60.0 + k * 30.0, 60.0)
			ci.draw_polyline(ell_pts(fpos, rr, rr * 0.3), Color(1, 1, 1, 0.6 - rr / 120.0), 3, true)
		# 오른쪽 힘겨루기 칸
		var mx := w * 0.88
		var y0 := h * 0.4
		var y1 := h * 0.82
		var span := y1 - y0
		d_box(ci, Vector2(mx, (y0 + y1) / 2.0), Vector2(54, span + 20), 0.0, Color(0.62, 0.45, 0.28), 4)
		d_box(ci, Vector2(mx, (y0 + y1) / 2.0), Vector2(38, span), 0.0, Color(0.3, 0.5, 0.66), 0.0)
		var hard: float = FISH[fish_kind]["hard"]
		var half := lerpf(0.16, 0.1, hard)
		var zone_c := y1 - mg_off * span
		var inside := mg_step == 2
		var z_top := maxf(zone_c - half * span, y0)
		var z_bot := minf(zone_c + half * span, y1)
		d_box(ci, Vector2(mx, (z_top + z_bot) / 2.0), Vector2(40, z_bot - z_top), 0.0, Color(0.45, 0.9, 0.45, 0.85) if inside else Color(0.6, 0.85, 0.5, 0.6), 3)
		draw_fish2d(ci, Vector2(mx, y1 - mg_trail * span), 17, fish_kind, -PI / 2.0 + sin(anim_t * 10.0) * 0.3, true)

# --- 모내기 ---

func plant_slot(row: int, col: int) -> Vector2:
	var w := mg_overlay.size.x
	var h := mg_overlay.size.y
	var sc := 1.0 - row * 0.12
	return Vector2(w * 0.5 + (col - 1.5) * w * 0.2 * sc, h * (0.76 - row * 0.12))

func plant_cursor_x() -> float:
	var w := mg_overlay.size.x
	var row := mini(mg_count / 4, 2)
	var sc := 1.0 - row * 0.12
	return w * 0.5 + w * 0.36 * sc * sin(mg_phase)

func plant_tap() -> void:
	if mg_count >= 12:
		return
	var row := mg_count / 4
	var col := mg_count % 4
	var target := plant_slot(row, col)
	var cx := plant_cursor_x()
	if absf(cx - target.x) < mg_overlay.size.x * 0.05:
		mg_items.append([row, col, cx - target.x])
		mg_count += 1
		sfx("pop", 1.0 + mg_count * 0.04)
		shake(3)
		burst(target, Color(0.6, 0.9, 0.5), 7)
		float_text([tr("쏙!"), tr("착!"), tr("꾹!")][mg_count % 3], target + Vector2(0, -40), Color(1, 1, 1), 1.0)
	else:
		mg_lives -= 1
		mg_perfect = false
		sfx("bad")
		shake(10)
		flash(Color(1, 0.3, 0.3))
		float_text(tr("삐뚤빼뚤!"), Vector2(cx, target.y - 40), Color(1, 0.6, 0.5), 1.1)

func update_plant(delta: float) -> void:
	var row := mini(mg_count / 4, 2)
	mg_phase += delta * (1.7 + row * 0.45)
	mg_progress = float(mg_count) / 12.0
	mg_info.text = tr("모 %d/12 | 남은 기회 %d") % [mg_count, mg_lives]

func draw_seedling(ci: CanvasItem, c: Vector2, s: float, lean: float) -> void:
	for k in 5:
		var a := -0.5 + k * 0.25 + lean
		d_line(ci, c, c + Vector2(0, -s).rotated(a), Color(0.42, 0.7, 0.3).lerp(Color(0.6, 0.82, 0.38), k / 4.0), 5)

func draw_plant_scene(ci: CanvasItem) -> void:
	var w := mg_overlay.size.x
	var h := mg_overlay.size.y
	var top := h * 0.44
	var bot := h * 0.83
	var field := PackedVector2Array([Vector2(w * 0.16, top), Vector2(w * 0.84, top), Vector2(w * 0.98, bot), Vector2(w * 0.02, bot)])
	d_poly(ci, PackedVector2Array([field[0] + Vector2(-14, -12), field[1] + Vector2(14, -12), field[2] + Vector2(14, 12), field[3] + Vector2(-14, 12)]), Color(0.62, 0.5, 0.34), 3.0)
	d_poly(ci, field, Color(0.5, 0.62, 0.66), 3.0)
	for k in 4:
		var gy := lerpf(top, bot, 0.15 + k * 0.23)
		var gx := w * 0.5 + sin(anim_t * 0.5 + k * 2.0) * w * 0.25
		d_line(ci, Vector2(gx - 20, gy), Vector2(gx + 20, gy), Color(1, 1, 1, 0.4), 3)
	var row := mini(mg_count / 4, 2)
	# 못줄: 지금 심는 줄에 빨간 눈금
	if mg_count < 12:
		var a := plant_slot(row, 0) + Vector2(-w * 0.12 * (1.0 - row * 0.12), 0)
		var b := plant_slot(row, 3) + Vector2(w * 0.12 * (1.0 - row * 0.12), 0)
		d_line(ci, a, b, Color(0.95, 0.9, 0.75), 3)
		for col in 4:
			var p := plant_slot(row, col)
			if col == mg_count % 4:
				var pulse := 1.0 + sin(anim_t * 8.0) * 0.15
				ci.draw_polyline(ell_pts(p, 26 * pulse, 12 * pulse), Color(1, 0.9, 0.3), 4, true)
			ci.draw_circle(p, 6, Color(0.9, 0.25, 0.2))
	for it in mg_items:
		var p := plant_slot(it[0], it[1]) + Vector2(it[2], 0)
		draw_seedling(ci, p, 46 * (1.0 - it[0] * 0.12), float(it[2]) * 0.01)
	# 모 한 움큼을 든 손
	if mg_count < 12:
		var cx := plant_cursor_x()
		var target := plant_slot(row, mg_count % 4)
		var near := absf(cx - target.x) < w * 0.05
		var hp := Vector2(cx, target.y - 60)
		draw_seedling(ci, hp + Vector2(0, 30), 50, 0.0)
		d_ell(ci, hp + Vector2(0, 34), 24, 18, Color(0.99, 0.83, 0.69), 0.0, 3.0)
		d_box(ci, hp + Vector2(0, 62), Vector2(30, 26), 0.0, Color(0.85, 0.78, 0.6), 3.0)
		if near:
			ci.draw_polyline(ell_pts(hp + Vector2(0, 34), 36, 30), Color(0.5, 1.0, 0.5), 4, true)

# --- 참새 쫓기 ---

func draw_sparrow2d(ci: CanvasItem, c: Vector2, s: float, danger: float, flap: float) -> void:
	var brown := Color(0.62, 0.42, 0.26).lerp(Color(0.85, 0.35, 0.25), danger * 0.5)
	d_poly(ci, PackedVector2Array([c + Vector2(-s * 0.5, 0), c + Vector2(-s * 1.0, -s * 0.25), c + Vector2(-s * 0.95, s * 0.15)]), brown.darkened(0.2), 3)
	d_ell(ci, c, s * 0.62, s * 0.45, brown, 0.0, 3.0)
	d_ell(ci, c + Vector2(-s * 0.05, s * 0.15), s * 0.4, s * 0.25, Color(0.96, 0.92, 0.84), 0.0, 0.0)
	var peck := sin(anim_t * (6.0 + danger * 14.0)) * 0.25 * (0.5 + danger)
	var head := c + Vector2(s * 0.5, -s * 0.3) + Vector2(0, peck * s)
	d_ell(ci, head, s * 0.32, s * 0.3, Color(0.5, 0.3, 0.2), 0.0, 3.0)
	ci.draw_circle(head + Vector2(-s * 0.02, s * 0.12), s * 0.14, Color(0.98, 0.96, 0.92))
	ci.draw_circle(head + Vector2(s * 0.12, -s * 0.05), s * 0.06, Color(0.1, 0.08, 0.08))
	d_poly(ci, PackedVector2Array([head + Vector2(s * 0.28, -s * 0.04), head + Vector2(s * 0.5, s * 0.04), head + Vector2(s * 0.28, s * 0.1)]), Color(0.35, 0.28, 0.2), 0.0)
	d_ell(ci, c + Vector2(-s * 0.1, -s * 0.12), s * 0.38, s * 0.2, brown.darkened(0.15), -0.3 + flap, 2.0)

func draw_scarecrow2d(ci: CanvasItem, c: Vector2, s: float) -> void:
	var wood := Color(0.55, 0.4, 0.24)
	d_line(ci, c + Vector2(0, -s * 0.6), c + Vector2(0, s * 1.2), wood, s * 0.1)
	d_line(ci, c + Vector2(-s * 1.0, -s * 0.2), c + Vector2(s * 1.0, -s * 0.2), wood, s * 0.08)
	d_box(ci, c + Vector2(0, s * 0.15), Vector2(s * 0.8, s * 0.8), 0.0, Color(0.8, 0.68, 0.5), 4.0)
	d_box(ci, c + Vector2(s * 0.15, s * 0.3), Vector2(s * 0.25, s * 0.22), 0.2, Color(0.55, 0.62, 0.8), 3.0)
	d_box(ci, c + Vector2(0, -s * 0.2), Vector2(s * 1.6, s * 0.24), 0.0, Color(0.8, 0.68, 0.5), 4.0)
	for sx in [-1.0, 1.0]:
		for k in 3:
			d_line(ci, c + Vector2(sx * s * 0.8, -s * 0.2), c + Vector2(sx * s * 1.05, -s * 0.3 + k * s * 0.1), Color(0.95, 0.85, 0.55), 5)
	d_ell(ci, c + Vector2(0, -s * 0.62), s * 0.36, s * 0.34, Color(0.96, 0.88, 0.62), 0.0, 4.0)
	for ex in [-0.13, 0.13]:
		ci.draw_circle(c + Vector2(ex * s, -s * 0.66), s * 0.05, Color(0.15, 0.1, 0.08))
		ci.draw_circle(c + Vector2(ex * s * 1.7, -s * 0.56), s * 0.06, Color(1, 0.55, 0.55, 0.8))
	d_line(ci, c + Vector2(-s * 0.1, -s * 0.52), c + Vector2(s * 0.1, -s * 0.52), Color(0.5, 0.2, 0.15), 3)
	d_ell(ci, c + Vector2(0, -s * 0.9), s * 0.62, s * 0.1, Color(0.85, 0.72, 0.42), 0.0, 3.0)
	d_poly(ci, PackedVector2Array([c + Vector2(-s * 0.26, -s * 0.92), c + Vector2(-s * 0.16, -s * 1.15), c + Vector2(s * 0.16, -s * 1.15), c + Vector2(s * 0.26, -s * 0.92)]), Color(0.85, 0.72, 0.42), 3.0)

func draw_rice_field(ci: CanvasItem) -> void:
	var w := mg_overlay.size.x
	var h := mg_overlay.size.y
	d_box(ci, Vector2(w * 0.5, h * 0.62), Vector2(w * 1.1, h * 0.46), 0.0, Color(0.5, 0.66, 0.42), 0.0)
	var rr := RandomNumberGenerator.new()
	rr.seed = 9
	for k in 70:
		var x := rr.randf_range(0.0, w)
		var y := rr.randf_range(h * 0.4, h * 0.85)
		var sway := sin(anim_t * 1.5 + x * 0.02) * 0.12
		draw_seedling(ci, Vector2(x, y), 30.0 + (y - h * 0.4) * 0.08, sway)

# --- 최 영감네 논 ---

func talk_choi() -> void:
	if farm_state == -1:
		farm_state = 0
		say([
			[tr("최 영감"), tr("아이고 허리야... 올해는 모내기를 못 하겠구나.")],
			[tr("최 영감"), tr("얘야, 나 대신 모를 심어 주겠니? 벼를 거두면 쌀을 팔아 엽전을 나눠 주마.")],
			[tr("최 영감"), tr("논 앞 팻말에서 '모내기'를 누르면 된단다. 못줄 눈금에 맞춰 반듯하게 심어야 한다!")],
		], Callable())
		return
	match farm_state:
		0:
			say([[tr("최 영감"), tr("모내기를 부탁하마. 반듯하게 심어야 벼가 잘 자란단다.")]], Callable())
		1, 3:
			say([[tr("최 영감"), tr("벼가 쑥쑥 자라는 중이란다. 마을 일을 보고 오너라.")]], Callable())
		2:
			say([[tr("최 영감"), tr("참새 떼가 몰려왔다! 허수아비만으로는 안 되겠어. 어서 쫓아 다오!")]], Callable())
		4:
			say([[tr("최 영감"), tr("누렇게 잘 익었구나! 벼를 베어 다오.")]], Callable())

func farm_action() -> void:
	match farm_state:
		-1:
			say([["", tr("물이 찰랑이는 빈 논이다. 옆에 있는 최 영감에게 먼저 말을 걸어 보자.")]], Callable())
		0:
			farm_perfect = true
			start_game("plant", {"art": "world", "world": true, "scene": "plant", "title": tr("손이 노란 동그라미에 왔을 때 눌러서\n못줄 눈금에 맞춰 모를 심어요")}, plant_done)
		1, 3:
			say([["", tr("벼가 자라고 있다. (약 %d초 남았어요)") % int(ceil(farm_timer))]], Callable())
		2:
			start_game("tap", {"art": "world", "world": true, "scene": "sparrow", "title": tr("참새가 벼를 쪼아 먹어요!\n눌러서 훠이 쫓아요"), "goal": 10, "interval": 0.75, "life": 1.6, "target": tr("참새"), "center": tr("허수아비"), "color": Color(0.85, 0.72, 0.45)}, sparrow_done)
		4:
			harvest_rice()

func plant_done(ok: bool, good: bool) -> void:
	if not ok:
		say([[tr("최 영감"), tr("허허, 모가 삐뚤빼뚤하구나. 다시 심어 보자.")]], Callable())
		return
	farm_perfect = good
	farm_state = 1
	farm_timer = FARM_GROW
	farm_visual()
	say([[tr("최 영감"), tr("반듯하게 잘 심었구나! 이제 벼가 자라기를 기다리자.")]], Callable())

func sparrow_done(ok: bool, good: bool) -> void:
	if not ok:
		say([[tr("최 영감"), tr("아이쿠, 참새들이 아직 남았구나. 다시 쫓아 다오!")]], Callable())
		return
	farm_perfect = farm_perfect and good
	farm_state = 3
	farm_timer = FARM_GROW
	farm_visual()
	say([[tr("최 영감"), tr("훠이훠이! 참새들이 다 날아갔구나. 이제 이삭이 여물 차례란다.")]], Callable())

func harvest_rice() -> void:
	farm_state = 0
	farm_visual()
	harvests += 1
	save_south()
	sfx("good")
	shake(6)
	burst3d(FARM_C + Vector3(0, 1, 0), Color(1, 0.85, 0.35), 30)
	var pay := 25
	var lines := [["", tr("누렇게 익은 벼를 쓱싹쓱싹 베었다!")]]
	if farm_perfect:
		pay = 30
		lines.append([tr("최 영감"), tr("모도 반듯하고 참새도 말끔히 쫓았으니 올해 쌀이 최고로구나! 덤까지 얹어 주마.")])
	else:
		lines.append([tr("최 영감"), tr("수고했다! 쌀을 판 돈이다.")])
	earn(pay)
	lines.append(["", tr("엽전 %d냥을 받았다! (수확 %d번째) 빈 논에 다시 모를 심을 수 있어요.") % [pay, harvests]])
	say(lines, Callable())

func make_decor() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 21
	# 돌담 (앞쪽은 열어 두었어요)
	make_stone_wall(Vector2(-20, -7), Vector2(-8.2, -7), r)
	make_stone_wall(Vector2(-20, -7), Vector2(-20, 2), r)
	make_stone_wall(Vector2(-8.2, -7), Vector2(-8.2, -1.5), r)
	make_stone_wall(Vector2(5.5, -4.5), Vector2(22.5, -4.5), r)
	make_stone_wall(Vector2(5.5, -4.5), Vector2(5.5, 1.5), r)
	make_stone_wall(Vector2(22.5, -4.5), Vector2(22.5, 1.5), r)
	# 마을 한가운데
	make_persimmon(Vector3(3, 0, 2.5), r)
	# 텃밭, 장작
	make_garden(Vector3(-17.6, 0, -4.6), 3.2, 1.8, r)
	make_garden(Vector3(-8.5, 0, 13), 3.0, 1.6, r)
	make_firewood(Vector3(-9.6, 0, -2.6))
	# 꽃덤불
	for pos in [Vector3(-18.6, 0, 2.4), Vector3(-8.9, 0, 2.2), Vector3(6.4, 0, 2.6), Vector3(21.6, 0, 2.6), Vector3(-4.4, 0, -7), Vector3(0.7, 0, -9), Vector3(-4.4, 0, 13), Vector3(0.7, 0, 18), Vector3(-5.6, 0, -12.5), Vector3(1.8, 0, -12.5), Vector3(7.4, 0, 5.8), Vector3(-11.5, 0, 7.2)]:
		make_flowers(pos, r)
	# 징검돌 (집 앞에서 큰길까지)
	var steps := []
	for z in [1.9, 2.9, 3.9, 4.9, 5.9]:
		steps.append([Vector3(-12 + r.randf_range(-0.25, 0.25), 0.05, z + r.randf_range(-0.1, 0.1)), Vector3(0.85, 0.12, 0.65), stone_color(r)])
	for z in [6.0, 7.0]:
		steps.append([Vector3(14 + r.randf_range(-0.25, 0.25), 0.05, z + r.randf_range(-0.1, 0.1)), Vector3(0.9, 0.12, 0.7), stone_color(r)])
	for x in [-9.0, -8.0, -7.0]:
		steps.append([Vector3(x, 0.05, 3.2 + r.randf_range(-0.2, 0.2)), Vector3(0.8, 0.12, 0.6), stone_color(r)])
	add_blobs(self, steps, stone_blob_mat, true)
	# 시냇가 돌과 물빛, 다리 난간
	for side in [1.0, -1.0]:
		var bank := []
		var x := -38.0
		while x < 38.0:
			x += r.randf_range(1.0, 1.7)
			if absf(x + 2.0) < 2.3:
				continue
			var zb: float = creek_z(x) + side * (creek_half(x) + 0.12)
			bank.append([Vector3(x, 0.08, zb + r.randf_range(-0.2, 0.2)), Vector3(r.randf_range(0.6, 1.1), r.randf_range(0.35, 0.6), r.randf_range(0.5, 0.8)), stone_color(r)])
		add_blobs(self, bank, stone_blob_mat)
	var foam := []
	for i in 22:
		foam.append([Vector3(r.randf_range(-38, 38), 0.07, r.randf_range(-0.9, 0.9)), Vector3(r.randf_range(0.6, 1.4), 0.04, 0.12), Color(0.85, 0.95, 1.0)])
	var foam_mi := add_blobs(self, foam)
	foam_mm = foam_mi.multimesh
	for f in foam:
		foam_data.append([f[0].x, f[0].z, f[1].x, f[2]])
	var rail := Color(0.55, 0.38, 0.22)
	for sx in [-3.45, -0.55]:
		for pz in [-17.3, -15.5, -13.7]:
			add_mbox(self, dark_wood_mat, Vector3(0.16, 0.95, 0.16), Vector3(sx, 0.55, pz))
			add_ball(self, Color(0.72, 0.7, 0.66), 0.14, Vector3(sx, 1.05, pz))
		add_mbox(self, wood_mat, Vector3(0.12, 0.1, 3.9), Vector3(sx, 0.92, -15.5))
		add_mbox(self, wood_mat, Vector3(0.1, 0.08, 3.9), Vector3(sx, 0.55, -15.5))
	# 멀리 보이는 둥근 언덕
	make_butterflies(r)
	make_clouds(r)
	make_grass(r)
	add_box(self, Color(0.42, 0.66, 0.38), Vector3(600, 1, 600), Vector3(0, -0.502, 0)).material_override = ground_mat
	make_border(r)
	# 멀리 겹겹이 보이는 부드러운 산 능선 (가까운 초록 언덕, 먼 푸른 산)
	add_ridge_ring(84.0, 26.0, 9.0, 22.0, Color(0.28, 0.48, 0.24), Color(0.4, 0.58, 0.34), 11)
	add_ridge_ring(128.0, 40.0, 22.0, 46.0, Color(0.34, 0.48, 0.5), Color(0.46, 0.58, 0.64), 23)

func make_butterflies(r: RandomNumberGenerator) -> void:
	var spots := [Vector3(-8.9, 0, 2.2), Vector3(6.4, 0, 2.6), Vector3(-4.4, 0, -7), Vector3(0.7, 0, 18), Vector3(-5.6, 0, -12.5), Vector3(21.6, 0, 2.6), Vector3(-18.6, 0, 2.4)]
	var cols := [Color(1.0, 0.82, 0.25), Color(0.98, 0.98, 1.0), Color(1.0, 0.58, 0.78), Color(0.55, 0.78, 1.0)]
	var body_mat := make_color(Color(0.22, 0.16, 0.12))
	for i in spots.size():
		var root := Node3D.new()
		add_child(root)
		var c: Color = cols[i % cols.size()]
		var wing := butterfly_wing_mesh(c)
		var wmat := StandardMaterial3D.new()
		wmat.vertex_color_use_as_albedo = true
		wmat.cull_mode = BaseMaterial3D.CULL_DISABLED
		wmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var left := Node3D.new()
		var right := Node3D.new()
		root.add_child(left)
		root.add_child(right)
		for side in [[left, -1.0], [right, 1.0]]:
			var mi := MeshInstance3D.new()
			mi.mesh = wing
			mi.material_override = wmat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.scale = Vector3(side[1], 1, 1)
			(side[0] as Node3D).add_child(mi)
		# 몸통과 더듬이
		var bd := add_mcyl(root, body_mat, 0.018, 0.012, 0.16, Vector3.ZERO)
		bd.rotation.x = PI / 2.0
		add_ball(root, Color(0.22, 0.16, 0.12), 0.026, Vector3(0, 0.005, 0.085))
		for sx in [-1.0, 1.0]:
			var an := add_mcyl(root, body_mat, 0.004, 0.004, 0.11, Vector3(sx * 0.022, 0.03, 0.13))
			an.rotation = Vector3(PI / 2.0 - 0.5, 0, -sx * 0.35)
			add_ball(root, Color(0.22, 0.16, 0.12), 0.011, Vector3(sx * 0.04, 0.06, 0.175))
		root.scale = Vector3.ONE * 1.25
		butterflies.append([root, left, right, spots[i], r.randf_range(1.2, 2.2), r.randf_range(0.5, 0.9), r.randf_range(0, TAU)])

# 산신령 연못: 이끼 낀 돌 테두리, 뒤쪽 갈대, 연잎과 연꽃, 큰 바위
func make_sansin_pond(c: Vector3) -> void:
	var rad := 3.2
	var r := RandomNumberGenerator.new()
	r.seed = 77
	flat_ellipse(c + Vector3(0, -0.01, 0), rad, rad, 0.06, water_material(1, Vector4(c.x, c.z, rad, rad), Color(0.1, 0.32, 0.46), Color(0.38, 0.64, 0.68)))
	var stones := []
	var a := 0.0
	while a < TAU:
		a += r.randf_range(0.2, 0.32)
		# 나무꾼이 서는 쪽은 낮은 조약돌만
		var front := absf(wrapf(a - 2.53, -PI, PI)) < 0.45
		var k := r.randf_range(0.0, 0.3)
		var sz := Vector3(r.randf_range(0.5, 0.95), r.randf_range(0.3, 0.55), r.randf_range(0.45, 0.8))
		if front:
			sz = Vector3(0.35, 0.12, 0.3)
		stones.append([c + Vector3(cos(a) * (rad + 0.25 + k), 0.06, sin(a) * (rad + 0.25 + k)), sz, stone_color(r)])
		if not front and r.randf() < 0.4:
			stones.append([c + Vector3(cos(a) * (rad + 0.3 + k), sz.y * 0.45, sin(a) * (rad + 0.3 + k)), sz * Vector3(0.7, 0.25, 0.7), Color(0.36, 0.5, 0.26)])
	# 뒤편의 큰 이끼 바위
	stones.append([c + Vector3(1.6, 0.5, -3.3), Vector3(1.8, 1.3, 1.4), Color(0.56, 0.56, 0.54)])
	stones.append([c + Vector3(1.6, 1.1, -3.3), Vector3(1.4, 0.3, 1.1), Color(0.38, 0.52, 0.28)])
	stones.append([c + Vector3(2.6, 0.3, -2.6), Vector3(0.9, 0.7, 0.8), Color(0.6, 0.59, 0.56)])
	add_blobs(self, stones, stone_blob_mat)
	var reeds := []
	for ang in [-1.2, -0.7, -0.2, 0.4, 0.9]:
		var base := c + Vector3(cos(ang) * rad * 0.95, 0, sin(ang) * rad * 0.95)
		for i in 6:
			var p := base + Vector3(r.randf_range(-0.4, 0.4), 0, r.randf_range(-0.4, 0.4))
			var hgt := r.randf_range(0.9, 1.5)
			var tilt := Vector3(r.randf_range(-12, 12), 0, r.randf_range(-12, 12))
			reeds.append([p + Vector3(0, hgt * 0.5, 0), Vector3(0.05, hgt, 0.05), Color(0.42, 0.62, 0.28), tilt])
			if i % 2 == 0:
				reeds.append([p + Vector3(0, hgt * 0.85, 0), Vector3(0.1, 0.3, 0.1), Color(0.48, 0.3, 0.16), tilt])
			else:
				reeds.append([p + Vector3(0.06, hgt * 0.35, 0), Vector3(0.16, hgt * 0.6, 0.04), Color(0.5, 0.7, 0.32), tilt + Vector3(0, 0, 18)])
	add_blobs(self, reeds)
	var pads := []
	for i in 7:
		var pa := r.randf_range(-1.6, 1.4)
		var pr := r.randf_range(0.45, 0.85)
		var p := c + Vector3(cos(pa) * rad * pr, 0.075, sin(pa) * rad * pr)
		pads.append([p, Vector3(0.7, 0.04, 0.6), Color(0.36, 0.62, 0.3).lerp(Color(0.48, 0.7, 0.34), r.randf())])
		if i % 2 == 0:
			pads.append([p + Vector3(0.1, 0.08, 0), Vector3(0.24, 0.16, 0.24), Color(1.0, 0.72, 0.82)])
			pads.append([p + Vector3(0.1, 0.14, 0), Vector3(0.1, 0.08, 0.1), Color(1.0, 0.92, 0.5)])
	add_blobs(self, pads, null, true)
	make_tree(c + Vector3(-1.2, 0, -4.6), "Willow0")

func make_forest() -> void:
	var herb_spots := [Vector3(-24, 0, -25), Vector3(5, 0, -32), Vector3(27, 0, -22)]
	for pos in herb_spots:
		var h := make_spot(pos, "herb", "", tr("약초"), false)
		make_herb_visual(h)

	# 가시덤불로 막힌 연못 (금도끼 은도끼)
	var none := Color(0, 0, 0, 0)
	for hd in [[Vector3(23, 1.1, -37.5), Vector3(1, 2.2, 4)], [Vector3(23, 1.1, -31.25), Vector3(1, 2.2, 2.5)], [Vector3(31.25, 1.1, -30), Vector3(17.5, 2.2, 1)]]:
		var hc := add_solid(hd[0], hd[1], none)
		make_thorn_shrubs(hc.get_parent(), hd[1], Color(0.2, 0.42, 0.22))
	bush_col = add_solid(Vector3(23, 1.0, -34), Vector3(1, 2.0, 3), none)
	make_thorn_shrubs(bush_col.get_parent(), Vector3(1, 2.0, 3), Color(0.36, 0.46, 0.2))
	var bush: Node3D = bush_col.get_parent()
	add_tag(bush, tr("가시덤불"), 1.6)
	add_thing(bush, "bush", "")
	make_sansin_pond(Vector3(33.5, 0, -35.5))
	make_npc("woodman", tr("나무꾼"), Color(0.55, 0.42, 0.3), Vector3(28, 0, -33), 1.0, true)
	make_npc("sansin", tr("산신령"), Color(0.95, 0.95, 1.0), Vector3(31.5, 0, -35), 1.2, false).visible = false

	var keep_clear := herb_spots + wild_keep_clear() + [Vector3(-9, 0, -36), Vector3(-2, 0, -19), Vector3(15, 0, -19.5)]
	var planted := 0
	var tries := 0
	while planted < 30 and tries < 500:
		tries += 1
		var pos := Vector3(rng.randf_range(-37, 37), 0, rng.randf_range(-37.5, -19))
		var ok := not (pos.x > 20.0 and pos.z < -27.5)
		for c in keep_clear:
			if pos.distance_to(c) < 3.0:
				ok = false
		if ok:
			make_tree(pos)
			keep_clear.append(pos)
			planted += 1

func update_quest_text() -> void:
	var t := ""
	if quest == Q_NOLBU:
		t = tr("큰 기와집에 가서 여기가 어딘지 물어보기 (길 따라 오른쪽)")
	elif quest == Q_MEET:
		t = tr("길 건너 초가집의 흥부 만나기 (왼쪽)")
	elif quest == Q_RICE:
		t = tr("흥부와 함께 놀부 마누라에게 쌀 부탁하기")
	elif quest == Q_VILLAGE:
		if mischief_done >= MISCHIEF_NEED:
			t = tr("흥부에게 돌아가기")
		else:
			t = tr("놀부 심술에 당한 마을 사람 돕기 (%d/%d) | 마을 곳곳을 돌아다녀 보세요") % [mischief_done, MISCHIEF_NEED]
	elif quest == Q_SNAKE:
		t = tr("흥부네 처마 밑 제비 둥지 지키기")
	elif quest == Q_HERB:
		t = tr("개울 건너 숲에서 약초 찾기 (%d/%d)") % [herbs_found, HERB_TOTAL]
	elif quest == Q_GIVE:
		t = tr("흥부에게 약초 가져다주기")
	elif quest == Q_GOURD:
		t = tr("흥부네 마당에서 박 타기 (%d/3)") % gourds_done
	elif quest == Q_NOLBU2:
		t = tr("시끌시끌한 놀부네에 가 보기")
	elif quest == Q_RETURN:
		t = tr("흥부에게 돌아가 소식 전하기")
	elif quest == Q_END:
		t = tr("흥부와 놀부 이야기 끝! 마을을 둘러보고, 흥부에게 말을 걸면 엔딩을 다시 고를 수 있어요")
	quest_label.text = tr("할 일: %s\n엽전 %d냥 | 조각 %d/%d | 심술 수습 %d/5") % [t, shown_coins, pieces_found, PIECE_TOTAL, mischief_done]

func talk_to(id: String) -> void:
	if id == "nolbu":
		talk_nolbu()
	elif id == "wife":
		talk_wife()
	elif id == "heungbu":
		talk_heungbu()
	elif id == "kid1":
		talk_kid1()
	elif id == "kid2":
		if gourds_done >= 1:
			say([[tr("막내"), tr("쌀밥 세 그릇이나 먹었어! 배가 뽈록해.")]], Callable())
		else:
			say([[tr("막내"), tr("배고파... 그래도 제비가 빨리 나았으면 좋겠어.")]], Callable())
	elif id == "dokkaebi":
		say([[tr("도깨비"), tr("껄껄, 책 밖에서 온 아이로구나. 너는 착하니 겁낼 것 없다.")]], Callable())
	elif id == "merchant":
		shop()
	elif id == "woodman":
		talk_woodman()
	elif id == "fisher":
		talk_fisher()
	elif id == "choi":
		talk_choi()
	elif id == "sansin":
		say([[tr("산신령"), tr("정직한 마음을 잊지 말거라. 그것이 금도끼보다 귀하니라.")]], Callable())
	else:
		talk_villager(id)


# ---------- 놀부네 ----------
func talk_nolbu() -> void:
	if quest == Q_NOLBU:
		say([
			[tr("놀부"), tr("뭐냐, 웬 꼬마가 남의 집 앞에서 얼쩡거려?")],
			[tr("놀부"), tr("옷차림은 또 그게 뭐냐? 저고리도 아니고, 신발은 왜 그 모양이야?")],
			[tr("놀부"), tr("길을 잃었다고? 내 알 바 아니다! 책 속에서 왔다니, 별 실없는 소리를 다 듣겠네.")],
			[tr("놀부"), tr("밥? 흥! 물 한 모금도 아깝다. 길 건너 내 아우 흥부한테나 가 보든지.")],
		], func(): set_quest(Q_MEET))
	elif quest == Q_NOLBU2:
		say([
			[tr("놀부"), tr("흥부 놈이 제비 덕에 부자가 됐다지? 그깟 거 나도 한다!")],
			[tr("놀부"), tr("그래서 내가 제비 다리를 똑 부러뜨린 다음 고쳐 줬지. 으하하!")],
			[tr("놀부"), tr("자, 봐라. 내 박은 흥부네 것보다 훨씬 크지? 슬근슬근 톱질하세...")],
			[tr("놀부"), tr("어? 어어? 박 속에서 뭐가 나온다!")],
		], after_nolbu_boast)
	elif quest == Q_DOKKAEBI:
		ask(tr("놀부"), tr("얘야... 염치없다만, 흥부한테 내 얘기 좀 잘 해 주겠느냐?"), [tr("도와준다"), tr("모른 척한다")], on_nolbu_choice)
	elif quest >= Q_RETURN:
		if helped_nolbu:
			say([[tr("놀부"), tr("네가 내 편을 들어 주다니... 박대해서 미안했다, 얘야. 이제 심술은 안 부리마.")]], Callable())
		else:
			say([[tr("놀부"), tr("내가 욕심이 과했다... 다 내 탓이지, 누굴 원망하겠느냐.")]], Callable())
	else:
		say([[tr("놀부"), tr("아직도 안 갔느냐? 내 마당 흙 닳는다, 썩 가거라!")]], Callable())

func talk_wife() -> void:
	if quest == Q_RICE:
		say([
			[tr("흥부"), tr("형수님, 아이들이 굶고 있습니다. 쌀 한 되만 꾸어 주십시오.")],
			[tr("놀부 마누라"), tr("뭐야? 남 줄 쌀이 어디 있어! 이 밥주걱 맛이나 봐라!")],
			[tr("흥부"), tr("아이고! ...어? 뺨에 밥풀이 붙었네. 형수님, 이쪽 뺨도 마저 때려 주십시오!")],
			[tr("흥부"), tr("얘야, 바가지를 들고 튀는 밥풀을 받아 다오. 주걱은 피하고!")],
		], start_rice)
	elif quest >= Q_RETURN:
		say([[tr("놀부 마누라"), tr("아이고, 내 팔자야... 주걱으로 때린 벌을 받나 보다.")]], Callable())
	else:
		say([[tr("놀부 마누라"), tr("뭘 봐? 우리 집엔 남 줄 쌀 한 톨 없어!")]], Callable())

func start_rice() -> void:
	start_game("catch", {"world": true, "scene": "rice", "title": tr("놀부 마누라의 밥주걱은 피하고\n튀는 밥풀만 바가지로 받으세요"), "goal": 12, "interval": 0.6, "speed": 0.42, "bad_ratio": 0.35, "good": tr("밥풀"), "bad": tr("주걱"), "basket": tr("바가지"), "art": "world"}, rice_done)

func rice_done(ok: bool, _good: bool) -> void:
	if not ok:
		say([[tr("흥부"), tr("아이쿠, 주걱에 너무 많이 맞았다... 형수님께 다시 부탁해 보자꾸나.")]], Callable())
		return
	var heungbu: Node3D = npcs["heungbu"]
	heungbu.position = Vector3(-12, 0, 2.5)
	say([
		[tr("흥부"), tr("허허, 밥풀이 한 줌은 되는구나. 아이들 죽이라도 끓여 주겠다.")],
		[tr("놀부 마누라"), tr("저, 저런 못난이들! 썩 꺼져!")],
		[tr("흥부"), tr("나는 품을 팔러 가야겠다. 형님 심술에 마을 사람들이 고생이 많은데, 네가 좀 도와주겠느냐?")],
	], func(): set_quest(Q_VILLAGE))

func after_nolbu_boast() -> void:
	nolbu_gourd.visible = false
	var dok: Node3D = npcs["dokkaebi"]
	dok.visible = true
	pop3d(dok, true)
	sfx("crack")
	shake(22)
	hit_stop(0.08)
	flash(Color(1, 1, 1))
	burst3d(dok.position + Vector3(0, 1.5, 0), Color(0.6, 0.68, 0.4), 30)
	set_quest(Q_DOKKAEBI)
	say([
		[tr("도깨비"), tr("이놈 놀부야! 멀쩡한 제비 다리를 일부러 부러뜨려?")],
		[tr("놀부"), tr("아이고, 도깨비님! 잘못했습니다, 살려 주십시오!")],
		[tr("도깨비"), tr("욕심으로 얻은 재물은 내가 몽땅 가져가마. 뚝딱!")],
		[tr("놀부"), tr("아이고, 내 재산... 내 기와집... 흑흑.")],
	], func(): ask(tr("놀부"), tr("얘야... 염치없다만, 흥부한테 내 얘기 좀 잘 해 주겠느냐?"), [tr("도와준다"), tr("모른 척한다")], on_nolbu_choice))

func on_nolbu_choice(i: int) -> void:
	helped_nolbu = i == 0
	if helped_nolbu:
		say([[tr("놀부"), tr("고, 고맙다... 박대한 나를 도와주다니. 내가 부끄럽구나.")]], func(): set_quest(Q_RETURN))
	else:
		say([[tr("놀부"), tr("그래, 내가 한 짓이 있는데 무슨 낯으로... 흑흑.")]], func(): set_quest(Q_RETURN))


# ---------- 흥부네 ----------
func talk_heungbu() -> void:
	if quest == Q_NOLBU:
		say([[tr("흥부"), tr("어서 오너라. 처음 보는 옷이로구나. 길을 잃었으면 저기 큰 기와집 형님께 먼저 여쭤 보렴.")]], Callable())
	elif quest == Q_MEET:
		say([
			[tr("흥부"), tr("아이고, 형님 댁에서 그냥 쫓겨났다고? 저런, 많이 놀랐겠구나.")],
			[tr("흥부"), tr("옛이야기 책을 펼쳤더니 여기였다고? 허허, 신기한 일도 다 있구나. 그 책 좀 보자.")],
			[tr("흥부"), tr("이런, 책장이 텅 비었구나. 이야기가 채워져야 돌아갈 길이 열리려나 보다.")],
			[tr("흥부"), tr("밥이라도 먹이고 싶다만... 실은 쌀이 똑 떨어졌단다.")],
			[tr("흥부"), tr("형님 댁에 쌀을 꾸러 가려던 참인데, 같이 가 주겠느냐?")],
		], after_meet)
	elif quest == Q_RICE:
		say([[tr("흥부"), tr("형수님께 같이 부탁드려 보자꾸나. 바로 옆에 계신다.")]], Callable())
	elif quest == Q_VILLAGE:
		if mischief_done >= MISCHIEF_NEED:
			say([
				[tr("흥부"), tr("마을 사람들을 도와줬다고? 장하구나!")],
				[tr("흥부"), tr("그런데 큰일이다! 처마 밑 제비 둥지에 구렁이가 나타났어!")],
			], func(): set_quest(Q_SNAKE))
		else:
			say([[tr("흥부"), tr("형님 심술에 당한 사람이 마을에 다섯이나 된단다. 셋만 도와줘도 큰 힘이 될 게다.")]], Callable())
	elif quest == Q_SNAKE:
		say([[tr("흥부"), tr("어서 둥지를 지켜 다오! 우리 집 처마 밑이다.")]], Callable())
	elif quest == Q_HERB:
		say([[tr("흥부"), tr("약초는 개울 건너 뒷산 숲에 있단다. 나무 사이를 잘 살펴보렴.")]], Callable())
	elif quest == Q_GIVE:
		say([
			[tr("흥부"), tr("오오, 세 포기나! 정말 고맙구나.")],
			[tr("흥부"), tr("약초를 바르고 실로 다리를 감아 줘야 한단다.")],
			[tr("흥부"), tr("내 손은 거칠어서... 네가 살살 감아 주겠느냐?")],
		], start_heal)
	elif quest == Q_GOURD:
		say([[tr("흥부"), tr("박은 마당에 있단다. 하나씩 같이 타 보자꾸나.")]], Callable())
	elif quest == Q_NOLBU2:
		say([[tr("흥부"), tr("형님 댁이 시끌시끌하구나. 무슨 일인지 가 보겠느냐?")]], Callable())
	elif quest == Q_RETURN:
		var lines := [[tr("흥부"), tr("형님이 도깨비한테 혼쭐이 나셨다고? 저런...")]]
		if helped_nolbu:
			lines.append([tr("흥부"), tr("네가 형님 편을 들어 주었구나. 고맙다. 우리 새 집에서 함께 지내시라 해야겠다.")])
		else:
			lines.append([tr("흥부"), tr("미워도 내 형님이다. 우리 새 집에서 함께 지내시라 해야겠구나.")])
		lines.append([tr("흥부"), tr("얘야, 네 책 좀 보렴. 빈 책장에 우리 이야기가 거의 채워졌구나. 마지막 한 줄만 비어 있다.")])
		lines.append([tr("흥부"), tr("그 한 줄은 네가 정해 다오. 네 덕에 제비도 살고 우리 식구도 살았으니.")])
		say(lines, ask_final)
	else:
		ask(tr("흥부"), tr("집으로 돌아가는 길, 꼭 찾기를 바란다. 이야기의 마지막 한 줄을 다시 고르겠느냐?"), [tr("다시 고를래요"), tr("이대로 둘래요")], on_replay_choice)

func after_meet() -> void:
	var heungbu: Node3D = npcs["heungbu"]
	heungbu.position = Vector3(12.2, 0, 9.8)
	set_quest(Q_RICE)

func talk_kid1() -> void:
	if hide_state == 0:
		hide_state = 1
		for t in things:
			if t["kind"] == "hider":
				var node: Node3D = t["node"]
				node.visible = true
		say([[tr("첫째"), tr("그 옷 어디서 났어? 처음 봐! 참, 심심한데 숨바꼭질 하자.")], [tr("첫째"), tr("동생 넷이 마을 어딘가에 숨었어. 다 찾으면 내 보물을 줄게!")]], Callable())
	elif hide_state == 1:
		if hiders_found >= 4:
			hide_state = 2
			earn(20)
			say([[tr("첫째"), tr("벌써 다 찾았어? 대단하다! 약속한 보물이야.")], ["", tr("엽전 20냥을 받았다!")]], Callable())
		else:
			say([[tr("첫째"), tr("아직 %d명 남았어. 집 뒤, 나무 뒤, 다리 밑을 잘 봐!") % (4 - hiders_found)]], Callable())
	elif gourds_done >= 2:
		say([[tr("첫째"), tr("나도 새 옷 입었어! 다음엔 어느 이야기로 가? 나도 따라가고 싶다.")]], Callable())
	else:
		say([[tr("첫째"), tr("우리 아버지는 세상에서 제일 착해. 가난해도 제비까지 돌봐 준다니까!")]], Callable())

# 구렁이 쫓기
func start_snake() -> void:
	start_game("tap", {"world": true, "scene": "snake", "title": tr("구렁이가 제비 둥지로 기어와요!\n닿기 전에 눌러서 쫓아내세요"), "goal": 12, "interval": 0.75, "life": 1.6, "target": tr("구렁이"), "center": tr("둥지"), "color": Color(0.5, 0.38, 0.25), "art": "world"}, snake_done)

func snake_done(ok: bool, _good: bool) -> void:
	if not ok:
		say([[tr("흥부"), tr("구렁이가 둥지에 닿았다! 얼른 다시 쫓아 다오!")]], Callable())
		return
	for t in things:
		if t["kind"] == "herb":
			var node: Node3D = t["node"]
			node.visible = true
	say([
		["", tr("구렁이는 달아났지만, 놀란 새끼 제비 한 마리가 떨어져 다리를 다쳤다.")],
		[tr("흥부"), tr("저런, 가엾어라! 뒷산 숲에서 약초를 세 포기만 구해다 주겠느냐? 분홍빛 나는 풀이란다.")],
	], func(): set_quest(Q_HERB))

# 제비 치료
func start_heal() -> void:
	start_game("circle", {"world": true, "scene": "heal", "art": "world", "trail": Color(1, 1, 1), "title": tr("다친 제비 다리에 부목을 대고\n둘레를 천천히 돌며 실을 감아요"), "label": tr("제비"), "turns": 6.0, "max_speed": 11.0, "warn": tr("너무 빨라요! 제비가 아파해요"), "color": Color(0.2, 0.22, 0.35)}, heal_done)

func heal_done(ok: bool, good: bool) -> void:
	if not ok:
		say([[tr("흥부"), tr("제비가 놀라서 푸드덕거리는구나. 숨을 고르고 다시 살살 감아 보자.")]], start_heal)
		return
	var lines := [[tr("제비"), tr("짹짹!")]]
	if good:
		lines.append([tr("흥부"), tr("허허, 아주 꼼꼼하게 감았구나. 제비가 하나도 안 아파하는구나.")])
	else:
		lines.append([tr("흥부"), tr("조금 놀랐나 보다만, 그래도 잘 감아 주었구나.")])
	lines.append([tr("흥부"), tr("어라, 네 책에 제비 그림이 생겼구나! 이야기가 채워지고 있나 보다.")])
	lines.append([tr("흥부"), tr("다 나으면 강남으로 날아가겠지. 고맙다, 얘야.")])
	say(lines, after_heal_talk)

func after_heal_talk() -> void:
	set_quest(Q_SEASON)
	show_card(tr("제비는 따뜻한 강남으로 날아갔어요.\n\n계절이 바뀌고,\n이듬해 봄..."), 0.0, 3.0, after_season)

func after_season() -> void:
	set_quest(Q_SEED)
	say([
		[tr("제비"), tr("짹짹! 짹짹!")],
		[tr("흥부"), tr("아니, 작년 그 제비가 아니냐! 입에 문 건... 박씨로구나.")],
		[tr("흥부"), tr("마당에 심었더니 어느새 커다란 박이 세 통이나 열렸단다.")],
		[tr("흥부"), tr("얘야, 나와 같이 박을 타 보지 않겠느냐? 박자가 너무 어긋나면 톱이 끼니 조심하고.")],
	], after_seed)

func after_seed() -> void:
	for t in things:
		if t["kind"] == "gourd":
			var node: Node3D = t["node"]
			node.visible = true
	set_quest(Q_GOURD)

# 박 타기
func start_saw() -> void:
	start_game("follow", {"world": true, "scene": "saw", "art": "world", "title": tr("슬근슬근 톱질하세! (%d번째 박)\n아래 손잡이를 흥부와 같이 좌우로") % (gourds_done + 1), "slow": 2.4 - gourds_done * 0.35, "tol": 0.42 - gourds_done * 0.04, "goal": 6.0, "patience": 4.0 - gourds_done * 0.5, "color": Color(0.82, 0.9, 0.62)}, saw_done)

func saw_done(ok: bool, _good: bool) -> void:
	if not ok:
		say([[tr("흥부"), tr("아이쿠, 박자가 어긋나 톱이 박에 끼었구나. 숨 한번 돌리고 다시 타 보자.")]], Callable())
		return
	var g: Node3D = saw_thing["node"]
	g.visible = false
	sfx("crack")
	shake(22)
	hit_stop(0.08)
	flash(Color(1, 1, 1))
	burst3d(g.position + Vector3(0, 1.2, 0), PAPER, 30)
	spawn_treasure(gourds_done, g.position)
	treasure_pos.append(g.position)
	var all_lines := [
		[
			[tr("흥부"), tr("아이고, 쌀이다! 하얀 쌀이 끝도 없이 쏟아지는구나!")],
			[tr("막내"), tr("쌀밥이다! 아버지, 오늘은 배불리 먹어요?")],
			[tr("흥부"), tr("그럼, 그럼. 네 몫으로 엽전도 나왔구나. 자, 다음 박도 타 보자.")],
		],
		[
			[tr("흥부"), tr("이번엔 비단이로구나! 고운 비단이 필필이 나온다!")],
			[tr("첫째"), tr("우와, 우리도 새 옷 입는 거예요?")],
			[tr("흥부"), tr("허허, 마지막 박이 남았구나. 톱질이 점점 빨라지니 잘 따라오너라.")],
		],
		[
			[tr("흥부"), tr("아니, 이번엔 목수들이 우르르 나오는구나!")],
			[tr("흥부"), tr("뚝딱뚝딱, 눈 깜짝할 사이에 새 집을 지어 주었구나!")],
			[tr("흥부"), tr("착한 일을 하면 복이 온다더니... 이 은혜는 잊지 않으마.")],
			[tr("흥부"), tr("그런데 형님 댁이 왜 저리 시끄러울꼬? 한번 가 보겠느냐?")],
		],
	]
	var lines: Array = all_lines[gourds_done]
	gourds_done += 1
	earn(15)
	say(lines, after_gourd_talk)

func after_gourd_talk() -> void:
	if gourds_done >= 3:
		nolbu_gourd.visible = true
		set_quest(Q_NOLBU2)
	else:
		update_quest_text()

func spawn_treasure(order: int, pos: Vector3) -> void:
	var pile := Node3D.new()
	pile.position = pos
	add_child(pile)
	if order == 0:
		spawn_rice(pile)
		add_tag(pile, tr("쌀"), 2.0)
	elif order == 1:
		spawn_silk(pile)
		add_tag(pile, tr("비단"), 2.0)
	else:
		spawn_gold(pile)
		add_tag(pile, tr("금은보화"), 1.6)
		hut.visible = false
		pop3d(make_house(hut.position, Vector3(7, 3.4, 4.5), Color(0.96, 0.94, 0.88), Color(0.2, 0.35, 0.5), "tile"), true)
	pop3d(pile, true)


# ---------- 1장 엔딩 ----------
func ask_final() -> void:
	var opts := [tr("형님도 우리 집에서 함께 지내요"), tr("형님은 벌 받은 대로 두어요")]
	if coins >= RICH_COINS:
		opts.append(tr("보물로 땅을 더 사서 불려요"))
	ask(tr("흥부"), tr("이야기의 마지막 한 줄이다. 형님을 어찌하면 좋을꼬?"), opts, on_final_choice)

func on_replay_choice(i: int) -> void:
	if i == 0:
		say([[tr("흥부"), tr("그래, 마지막 한 줄은 몇 번이고 다시 쓸 수 있지.")]], ask_final)

func on_final_choice(i: int) -> void:
	var id := "original"
	if i == 0:
		if helped_nolbu and mischief_done >= 5:
			id = "true"
		else:
			id = "awkward"
	elif i == 2:
		id = "greed"
	finish_chapter(id)

func ending_data(id: String) -> Array:
	match id:
		"true":
			return [tr("함께 사는 집"), tr("놀부는 마을 사람들을 하나하나 찾아가 고개를 숙였어요.\n처음엔 닫혀 있던 대문들이 하나둘 열렸고,\n흥부네 처마 밑 제비집은 둘로 늘었답니다.\n\n책의 첫 장이 환하게 채워졌어요.")]
		"awkward":
			return [tr("아직은 어색한 화해"), tr("흥부는 형님을 새 집에 모셨어요.\n하지만 놀부에게 상처받은 마을 사람들은\n아직 대문을 활짝 열지 못했어요.\n\n용서는 한 사람만의 일이라서\n시간이 더 필요한가 봐요.\n\n책의 첫 장이 반쯤 채워졌어요.")]
		"greed":
			return [tr("작은 놀부"), tr("보물로 땅을 사고 또 사던 흥부네 대문은\n해마다 높아지고 굳게 닫혔어요.\n처마 밑 제비는 다른 집으로 떠났고,\n마을 사람들은 흥부를 '작은 놀부'라 불렀어요.\n\n책장의 글씨가 흐릿하게 번졌어요.\n욕심은 누구의 마음에든 찾아오나 봐요.")]
	return [tr("권선징악"), tr("놀부는 도깨비에게 모든 것을 잃고\n흥부네 담장 밖을 오래 서성였어요.\n\n착한 마음에는 복이, 욕심에는 화가 따른다지만\n담장 밖 뒷모습이 자꾸 마음에 걸렸어요.\n\n책의 첫 장이 채워졌어요.")]

# 모은 엔딩을 파일에 기억해요. 지금까지 모은 개수를 돌려줘요
func save_ending(id: String) -> int:
	var cf := ConfigFile.new()
	cf.load("user://save.cfg")
	var got: Array = cf.get_value("ch1", "endings", [])
	if not got.has(id):
		got.append(id)
		cf.set_value("ch1", "endings", got)
		cf.save("user://save.cfg")
	return got.size()

func finish_chapter(id: String) -> void:
	ending_id = id
	var seen := save_ending(id)
	set_quest(Q_END)
	var d := ending_data(id)
	show_card(tr("%s\n\n엔딩 “%s” (모은 엔딩 %d/%d)\n흥부와 놀부  끝") % [d[1], d[0], seen, ENDING_COUNT], 0.0, 5.0, Callable())


# ---------- 마을 사람 돕기 ----------
func talk_villager(id: String) -> void:
	var v: Dictionary = villagers[id]
	var who: String = v["name"]
	var state: int = mischief.get(id, 0)
	if state == 2:
		say([[who, tr("네 덕에 한시름 놓았다. 고맙다!")]], Callable())
	elif v.has("game"):
		say(v["ask"], func(): start_game(v["game"], v["cfg"], villager_game_done.bind(id)))
	elif state == 0:
		mischief[id] = 1
		if id == "suni":
			for t in things:
				if t["kind"] == "laundry":
					var node: Node3D = t["node"]
					node.visible = true
		say(v["ask"], Callable())
	elif (id == "dori" and has_yeot) or (id == "suni" and laundry_found >= 3):
		if id == "dori":
			has_yeot = false
		finish_mischief(id)
	else:
		say([[who, v["wait"]]], Callable())

func villager_game_done(ok: bool, _good: bool, id: String) -> void:
	var v: Dictionary = villagers[id]
	if ok and id == "ong":
		# 진흙을 발라 금이 사라졌어요
		for c in ong_cracks:
			(c as Node3D).visible = false
	if ok:
		finish_mischief(id)
	else:
		say([[v["name"], v["fail"]]], Callable())

func finish_mischief(id: String) -> void:
	var v: Dictionary = villagers[id]
	mischief[id] = 2
	mischief_done += 1
	earn(10)
	say([[v["name"], v["done"]], ["", tr("엽전 10냥을 받았다! (놀부 심술 수습 %d/5)") % mischief_done]], Callable())


# ---------- 품팔이와 장터 ----------
func start_job(id: String) -> void:
	if id == "water":
		start_well3d()
		return
	if id == "water_2d":
		start_game("catch", {"art": "water", "title": tr("두레박을 좌우로 움직여 물방울만 받아요\n돌멩이는 피해요"), "goal": 10, "interval": 0.55, "speed": 0.5, "bad_ratio": 0.3, "good": tr("물"), "bad": tr("돌"), "basket": tr("두레박")}, job_done)
	elif id == "wood":
		start_wood3d()
	elif id == "gam":
		start_gam3d()
	elif id == "wood_2d":
		start_game("tap", {"art": "wood", "title": tr("통나무가 올라오면\n눌러서 쩍! 장작을 패요"), "goal": 10, "interval": 0.7, "life": 1.3, "target": tr("장작"), "center": tr("나무"), "color": Color(0.5, 0.35, 0.2)}, job_done)
	else:
		start_game("circle", {"world": true, "scene": "straw", "art": "world", "trail": Color(0.9, 0.78, 0.42), "title": tr("짚을 빙글빙글 꼬아 짚신을 삼아요\n너무 빠르면 짚이 끊어져요"), "label": tr("짚신"), "turns": 5.0, "max_speed": 12.0, "warn": tr("짚이 끊어질 것 같아요!"), "color": Color(0.8, 0.68, 0.35)}, job_done)

func job_done(ok: bool, good: bool) -> void:
	if not ok:
		say([["", tr("일을 망쳐서 품삯을 받지 못했다. 다시 해 보자.")]], Callable())
		return
	var pay := 10
	if good:
		pay = 15
	earn(pay)
	if good:
		say([["", tr("솜씨가 좋다고 덤까지 받았다. 엽전 %d냥!") % pay]], Callable())
	else:
		say([["", tr("품삯으로 엽전 %d냥을 받았다.") % pay]], Callable())

func shop() -> void:
	ask(tr("장터 상인"), tr("어서 오너라! 무엇을 줄까? (가진 엽전 %d냥)") % coins, [tr("엿 5냥"), tr("짚신 20냥 (발이 빨라져요)"), tr("낫 15냥 (덤불을 베요)"), tr("한복 40냥 (옷 갈아입기)"), tr("그만 볼래요")], on_shop)

func on_shop(i: int) -> void:
	if i >= 4:
		return
	var prices := [5, 20, 15, 40]
	var owned := (i == 0 and has_yeot) or (i == 1 and has_shoes) or (i == 2 and has_sickle) or (i == 3 and has_hanbok)
	if owned:
		say([[tr("장터 상인"), tr("그건 이미 가지고 있잖니.")]], shop)
		return
	if coins < prices[i]:
		say([[tr("장터 상인"), tr("엽전이 모자라는구나. 우물, 나무터, 짚더미, 감나무에서 품을 팔거나 남쪽 연못에서 낚시를 하고, 최 영감네 논일을 도우면 엽전을 벌 수 있단다.")]], Callable())
		return
	coins -= prices[i]
	if i == 0:
		has_yeot = true
	elif i == 1:
		has_shoes = true
	elif i == 2:
		has_sickle = true
	else:
		has_hanbok = true
		recolor_outfit(player_body, Color(0.45, 0.78, 0.72))
		pop3d(player)
		burst3d(player.position + Vector3(0, 1, 0), Color(0.45, 0.78, 0.72), 20)
	sfx("coin")
	update_quest_text()
	say([[tr("장터 상인"), tr("옜다, 잘 쓰거라!")]], shop)


# ---------- 숨은 이야기: 금도끼 은도끼 ----------
func talk_woodman() -> void:
	if axe_done:
		say([[tr("나무꾼"), tr("네 정직함 덕분에 어머니를 잘 모시게 됐어. 고마워!")]], Callable())
		return
	var sansin: Node3D = npcs["sansin"]
	sansin.visible = true
	pop3d(sansin, true)
	burst3d(sansin.position + Vector3(0, 1, 0), Color(0.6, 0.8, 1.0), 20)
	say([
		[tr("나무꾼"), tr("엉엉... 하나뿐인 쇠도끼를 연못에 빠뜨렸어. 나무를 해야 어머니를 모시는데...")],
		[tr("산신령"), tr("어흠. 나는 이 연못의 산신령이니라.")],
		[tr("산신령"), tr("책 밖에서 온 아이야, 네가 대신 시험을 받아 보아라.")],
		[tr("산신령"), tr("내가 연못에서 도끼를 하나씩 들어 올리마. 나무꾼의 낡은 쇠도끼일 때만 눌러 받거라.")],
		[tr("산신령"), tr("번쩍이는 금도끼, 은도끼에 손을 대면... 욕심으로 알겠느니라!")],
	], start_axe_game)

func start_axe_game() -> void:
	start_game("axe", {"world": true, "art": "world", "title": tr("산신령이 도끼를 들어 올려요\n낡은 쇠도끼일 때만 눌러서 받아요!")}, axe_game_done)
	var sansin: Node3D = npcs["sansin"]
	var sp := sansin.position
	var stand := Vector3(29.3, 0, -32.6)
	var dir := (stand - sp) * Vector3(1, 0, 1)
	dir = dir.normalized()
	var side := dir.cross(Vector3.UP)
	world_game_begin(stand, sp, Vector3(26.4, 1.9, -31.4), sp + Vector3(0, 0.75, 0))
	world_move(sansin, sp, stand)
	if npcs.has("woodman"):
		var wm: Node3D = npcs["woodman"]
		world_move(wm, stand + Vector3(0.9, 0, 0.9), sp)
		for lb2 in wm.find_children("*", "Label3D", true, false):
			world_hide(lb2)
	for lb in sansin.find_children("*", "Label3D", true, false):
		world_hide(lb)
	var axes := {}
	for kind in ["gold", "silver", "iron"]:
		var ax := make_axe_model(kind)
		ax.visible = false
		axes[kind] = ax
	w["axes"] = axes
	w["sansin"] = sp
	# 도끼 머리가 위쪽 안내판에 가리지 않게 낮게, 산신령 앞쪽으로 들어 올려요
	w["top"] = sp + dir * 0.8 + side * 0.55 + Vector3(0, 0.65, 0)
	w["state"] = "gap"
	w["timer"] = 1.0
	w["cur"] = ""
	w["since_iron"] = 0
	axe_info()

# 도끼 머리: 둥글게 휜 날, 날 쪽으로 얇아지는 두께, 반짝이는 날끝 (코드로 만든 고운 모양)
func axe_head_mesh(edge_col: Color, body_col: Color) -> ArrayMesh:
	# 옆에서 본 모양 (x: 날 쪽, y: 위). 자루 구멍(눈)은 x=0 근처
	var outline := PackedVector2Array()
	outline.append(Vector2(-0.075, 0.30))
	outline.append(Vector2(0.0, 0.295))
	for i in 7:
		var t := i / 6.0
		# 아래쪽 턱: 날 쪽으로 갈수록 아래로 휘어 내려가요
		outline.append(Vector2(0.03 + t * 0.22, 0.29 - t * t * 0.11))
	for i in 13:
		var t := -1.0 + i / 6.0
		# 날끝: 바깥으로 둥글게 부풀어요
		outline.append(Vector2(0.265 + 0.045 * (1.0 - t * t), 0.365 + t * 0.19))
	for i in 7:
		var t := 1.0 - i / 6.0
		outline.append(Vector2(0.03 + t * 0.22, 0.43 + t * t * 0.125))
	outline.append(Vector2(0.0, 0.425))
	outline.append(Vector2(-0.075, 0.42))
	var tris := Geometry2D.triangulate_polygon(outline)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# 두께: 눈 쪽 두껍고 날 쪽 얇게
	var thick := func(x: float) -> float:
		return lerpf(0.075, 0.012, clampf((x + 0.02) / 0.32, 0.0, 1.0))
	var col_at := func(p: Vector2) -> Color:
		var edge := clampf((p.x - 0.22) / 0.08, 0.0, 1.0)
		return body_col.lerp(edge_col, edge)
	for side in [1.0, -1.0]:
		for k in range(0, tris.size(), 3):
			var ids := [tris[k], tris[k + 1], tris[k + 2]]
			if side < 0.0:
				ids = [tris[k], tris[k + 2], tris[k + 1]]
			for id in ids:
				var p: Vector2 = outline[id]
				st.set_color(col_at.call(p))
				st.add_vertex(Vector3(p.x, p.y, side * thick.call(p.x) * 0.5))
	# 둘레 띠
	var n := outline.size()
	for i in n:
		var a: Vector2 = outline[i]
		var b: Vector2 = outline[(i + 1) % n]
		var ta: float = thick.call(a.x) * 0.5
		var tb: float = thick.call(b.x) * 0.5
		var ca: Color = col_at.call(a)
		var cb: Color = col_at.call(b)
		var q := [[Vector3(a.x, a.y, ta), ca], [Vector3(b.x, b.y, tb), cb], [Vector3(b.x, b.y, -tb), cb], [Vector3(a.x, a.y, -ta), ca]]
		for idx in [0, 2, 1, 0, 3, 2]:
			st.set_color(q[idx][1])
			st.add_vertex(q[idx][0])
	st.generate_normals()
	return st.commit()

func make_axe_model(kind: String) -> Node3D:
	var n := Node3D.new()
	world_node(n)
	var metal := StandardMaterial3D.new()
	metal.vertex_color_use_as_albedo = true
	var body := Color.WHITE
	var edge := Color.WHITE
	match kind:
		"gold":
			body = Color(0.95, 0.68, 0.16)
			edge = Color(1.0, 0.93, 0.62)
			metal.metallic = 0.75
			metal.roughness = 0.22
			metal.emission_enabled = true
			metal.emission = Color(1.0, 0.68, 0.2)
			metal.emission_energy_multiplier = 0.3
		"silver":
			# 산신령의 흰 옷 앞에서도 보이게 푸른빛 도는 은색
			body = Color(0.55, 0.62, 0.74)
			edge = Color(0.95, 0.98, 1.0)
			metal.metallic = 0.7
			metal.roughness = 0.2
			metal.emission_enabled = true
			metal.emission = Color(0.45, 0.62, 0.95)
			metal.emission_energy_multiplier = 0.35
		_:
			body = Color(0.3, 0.29, 0.28)
			edge = Color(0.62, 0.6, 0.58)
			metal.metallic = 0.35
			metal.roughness = 0.75
	var head := MeshInstance3D.new()
	head.mesh = axe_head_mesh(edge, body)
	head.material_override = metal
	n.add_child(head)
	# 자루: 아래로 살짝 굵어지고 끝에 둥근 꼭지
	var plain := StandardMaterial3D.new()
	plain.metallic = metal.metallic
	plain.roughness = metal.roughness + 0.1
	plain.albedo_color = body
	if metal.emission_enabled:
		plain.emission_enabled = true
		plain.emission = metal.emission
		plain.emission_energy_multiplier = metal.emission_energy_multiplier
	var handle: Material = plain if kind != "iron" else wood_mat
	var hc := MeshInstance3D.new()
	var cy := CylinderMesh.new()
	cy.top_radius = 0.028
	cy.bottom_radius = 0.036
	cy.height = 0.98
	cy.radial_segments = 24
	cy.rings = 4
	hc.mesh = cy
	hc.material_override = handle
	hc.position = Vector3(0, 0.0, 0)
	n.add_child(hc)
	var knob := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = 0.045
	sp.height = 0.07
	sp.radial_segments = 20
	sp.rings = 10
	knob.mesh = sp
	knob.material_override = handle
	knob.position = Vector3(0, -0.5, 0)
	n.add_child(knob)
	# 자루 꼭대기와 손잡이 띠 (금·은은 무늬 띠, 쇠도끼는 감은 끈)
	var band_mat: Material = metal if kind != "iron" else make_color(Color(0.55, 0.42, 0.28))
	var band_y := [0.47, -0.22, -0.3, -0.38] if kind != "iron" else [-0.24, -0.29, -0.34, -0.39]
	for by in band_y:
		var bm := MeshInstance3D.new()
		var tor := TorusMesh.new()
		tor.inner_radius = 0.03
		tor.outer_radius = 0.042
		tor.rings = 20
		tor.ring_segments = 8
		bm.mesh = tor
		bm.material_override = band_mat
		bm.position = Vector3(0, by, 0)
		n.add_child(bm)
	if kind == "iron":
		# 녹슨 자국과 이 빠진 날
		# 날 표면에 얇게 번진 녹 (납작한 얼룩)
		add_blobs(n, [[Vector3(0.12, 0.4, 0.024), Vector3(0.07, 0.045, 0.006), Color(0.55, 0.32, 0.18)],
			[Vector3(0.06, 0.33, 0.03), Vector3(0.05, 0.03, 0.006), Color(0.5, 0.3, 0.18)],
			[Vector3(0.17, 0.32, -0.019), Vector3(0.06, 0.04, 0.006), Color(0.48, 0.28, 0.16)]])
	else:
		# 날에 박힌 보석 한 알
		var gem := MeshInstance3D.new()
		var gs := SphereMesh.new()
		gs.radius = 0.022
		gs.height = 0.03
		gem.mesh = gs
		var gm := StandardMaterial3D.new()
		gm.albedo_color = Color(0.85, 0.15, 0.2) if kind == "gold" else Color(0.2, 0.45, 0.9)
		gm.emission_enabled = true
		gm.emission = gm.albedo_color
		gm.emission_energy_multiplier = 0.5
		gm.roughness = 0.1
		gem.material_override = gm
		for z in [0.034, -0.034]:
			var g2 := gem.duplicate() as MeshInstance3D
			g2.position = Vector3(0.05, 0.36, z)
			n.add_child(g2)
	n.scale = Vector3.ONE * 1.5
	return n

func axe_info() -> void:
	mg_progress = float(mg_count) / AXE_GOAL
	mg_info.text = tr("쇠도끼 %d/%d | 남은 기회 %d") % [mg_count, AXE_GOAL, mg_lives]

func axe_pick_next() -> String:
	# 쇠도끼가 너무 오래 안 나오지 않게 해요
	var since: int = w["since_iron"]
	if since >= 3 or rng.randf() < 0.3:
		w["since_iron"] = 0
		return "iron"
	w["since_iron"] = since + 1
	return "gold" if rng.randf() < 0.55 else "silver"

func update_axe(delta: float) -> void:
	var axes: Dictionary = w["axes"]
	var sp: Vector3 = w["sansin"]
	var top: Vector3 = w["top"]
	w["timer"] = float(w["timer"]) - delta
	var st: String = w["state"]
	var cur: String = w["cur"]
	var show_time := 1.25 - mg_count * 0.15
	if st == "gap":
		if float(w["timer"]) <= 0.0:
			cur = axe_pick_next()
			w["cur"] = cur
			w["state"] = "rise"
			w["timer"] = 0.35
			var ax: Node3D = axes[cur]
			ax.visible = true
			ax.global_position = sp + Vector3(0, 0.1, 0)
			splash3d(sp + Vector3(0, 0.05, 0))
			sfx("splash", 1.2)
	elif st == "rise":
		var ax2: Node3D = axes[cur]
		var k := 1.0 - clampf(float(w["timer"]) / 0.35, 0.0, 1.0)
		ax2.global_position = (sp + Vector3(0, 0.1, 0)).lerp(top, ease(k, 0.4))
		ax2.rotation = Vector3(0, axe_face_yaw(ax2.global_position) + (1.0 - k) * TAU, 0.2)
		if float(w["timer"]) <= 0.0:
			w["state"] = "show"
			w["timer"] = show_time
			if cur != "iron":
				burst3d(top + Vector3(0, 0.3, 0), Color(1.0, 0.85, 0.3) if cur == "gold" else Color(0.85, 0.9, 1.0), 12)
				sfx("coin", 1.3 if cur == "gold" else 1.6)
	elif st == "show":
		var ax3: Node3D = axes[cur]
		ax3.global_position = top + Vector3(0, sin(anim_t * 4.0) * 0.05, 0)
		# 날의 넓은 면이 카메라를 보게 (옆에서 보면 얇은 막대로만 보여요)
		ax3.rotation = Vector3(0, axe_face_yaw(ax3.global_position) + sin(anim_t * 2.5) * 0.3, 0.2)
		if float(w["timer"]) <= 0.0:
			if cur == "iron":
				# 쇠도끼를 놓쳤어요
				mg_lives -= 1
				mg_perfect = false
				sfx("bad")
				shake(10)
				float_text(tr("쇠도끼를 놓쳤어요!"), cam.unproject_position(top), Color(1, 0.55, 0.45), 1.1)
				axe_info()
			axe_sink()
	elif st == "sink":
		var ax4: Node3D = axes[cur]
		var k2 := 1.0 - clampf(float(w["timer"]) / 0.3, 0.0, 1.0)
		ax4.global_position = top.lerp(sp + Vector3(0, -0.3, 0), k2)
		if float(w["timer"]) <= 0.0:
			ax4.visible = false
			w["state"] = "gap"
			w["timer"] = rng.randf_range(0.35, 0.7)
	elif st == "fly":
		var ax5: Node3D = axes[cur]
		var k3 := 1.0 - clampf(float(w["timer"]) / 0.35, 0.0, 1.0)
		ax5.global_position = (w["fly_from"] as Vector3).lerp(player.global_position + Vector3(0, 1.2, 0), k3 * k3)
		ax5.rotation = Vector3(0, k3 * TAU, 0.2)
		ax5.scale = Vector3.ONE * 1.5 * (1.0 - k3 * 0.6)
		if float(w["timer"]) <= 0.0:
			ax5.visible = false
			ax5.scale = Vector3.ONE * 1.5
			w["state"] = "gap"
			w["timer"] = 0.6
	var sansin: Node3D = npcs["sansin"]
	sansin.position.y = sin(anim_t * 1.8) * 0.06 + 0.1

func axe_face_yaw(at: Vector3) -> float:
	return atan2(cam.global_position.x - at.x, cam.global_position.z - at.z)

func axe_sink() -> void:
	w["state"] = "sink"
	w["timer"] = 0.3
	splash3d((w["sansin"] as Vector3) + Vector3(0, 0.05, 0))

func axe_tap() -> void:
	var st: String = w.get("state", "")
	if st != "show" and st != "rise":
		return
	var cur: String = w["cur"]
	var ax: Node3D = w["axes"][cur]
	var at := ax.global_position
	if cur == "iron":
		mg_count += 1
		sfx("good")
		shake(6)
		hit_stop(0.05)
		cam_kick = 0.15
		burst3d(at, Color(0.6, 0.9, 1.0), 16)
		float_text([tr("정직하구나!"), tr("옳지!"), tr("바로 그거다!")][mg_count % 3], cam.unproject_position(at), Color(1, 0.95, 0.7), 1.3)
		# 도끼가 내 손으로 날아와요
		w["state"] = "fly"
		w["timer"] = 0.35
		w["fly_from"] = at
	else:
		mg_lives -= 1
		mg_perfect = false
		sfx("bad")
		shake(14)
		flash(Color(1, 0.3, 0.3))
		float_text(tr("욕심이로구나!"), cam.unproject_position(at), Color(1, 0.5, 0.4), 1.3)
		axe_sink()
	axe_info()

func axe_game_done(ok: bool, _good: bool) -> void:
	if not ok:
		axe_lie()
		return
	axe_done = true
	earn(30)
	say([
		[tr("산신령"), tr("참으로 정직하구나! 쇠도끼는 물론이고, 금도끼와 은도끼도 모두 주마.")],
		[tr("나무꾼"), tr("고맙다, 얘야! 네 덕분이야. 이건 내 마음이니 받아 줘.")],
		["", tr("엽전 30냥을 받았다!")],
	], func(): get_piece_id(6, tr("산신령이 책에 이야기 한 조각을 새겨 주었다.")))

func axe_lie() -> void:
	axe_lied = true
	var sansin: Node3D = npcs["sansin"]
	sansin.visible = false
	sfx("bad")
	shake(8)
	say([
		[tr("산신령"), tr("허허, 욕심에 눈이 흐려졌구나. 정직하지 못한 자에겐 아무것도 줄 수 없다.")],
		["", tr("산신령이 연못 속으로 사라졌다. 나무꾼에게 다시 말을 걸어 보자.")],
	], Callable())


# ---------- 감나무: 장대로 감 따기 (꼭대기 까치밥은 남겨요) ----------
func start_gam3d() -> void:
	start_game("gam", {"world": true, "art": "world", "title": tr("빨갛게 익은 감을 눌러 장대로 톡!\n초록 감과 꼭대기 까치밥은 남겨요")}, job_done)
	var c := persimmon_ctr
	var stand := Vector3(c.x + 1.9, 0, c.z + 3.0)
	world_game_begin(stand, Vector3(c.x, 0, c.z), Vector3(c.x + 0.6, 1.3, c.z + 8.0), Vector3(c.x + 0.5, c.y + 0.15, c.z), job_spot("gam"))
	if persimmon_fruit_mi != null:
		world_hide(persimmon_fruit_mi)
	hold_tool("pole")
	w["scene"] = "gam"
	w["swing"] = 0.0
	# 감이 달릴 자리: 카메라 쪽으로 보이는 나무 앞쪽
	var slots := []
	var r := RandomNumberGenerator.new()
	r.seed = 5
	var tries := 0
	while slots.size() < 11 and tries < 400:
		tries += 1
		var d := Vector3(r.randf_range(-1, 1), r.randf_range(-0.5, 0.35), r.randf_range(0.6, 1)).normalized()
		var p := c + d * persimmon_rad * Vector3(1.35, 0.85, 1.45)
		var ok := true
		for q in slots:
			if (q as Vector3).distance_to(p) < 0.75:
				ok = false
				break
		if ok:
			slots.append(p)
	var fruits := []
	for p in slots:
		var f := blob_node([[Vector3.ZERO, Vector3(0.44, 0.38, 0.44), Color(0.45, 0.65, 0.2)], [Vector3(0, 0.19, 0), Vector3(0.2, 0.06, 0.2), Color(0.25, 0.4, 0.15)]])
		f.global_position = p
		f.visible = false
		fruits.append({"node": f, "pos": p, "state": "empty", "t": r.randf_range(0.3, 6.0), "dur": 0.0})
	w["fruits"] = fruits
	# 꼭대기 까치밥 세 알과 까치
	var top := c + Vector3(0.2, persimmon_rad * 0.75, 0.5)
	var kk := []
	for k in 3:
		var kp := top + Vector3((k - 1) * 0.42, absf(k - 1) * -0.18, 0.1)
		var kf := blob_node([[Vector3.ZERO, Vector3(0.34, 0.3, 0.34), Color(0.92, 0.3, 0.06)], [Vector3(0, 0.15, 0), Vector3(0.16, 0.05, 0.16), Color(0.25, 0.4, 0.15)]])
		kf.global_position = kp
		kk.append(kf)
	w["kkachi"] = kk
	var bird := blob_node([
		[Vector3(0, 0, 0), Vector3(0.26, 0.24, 0.4), Color(0.08, 0.08, 0.12)],
		[Vector3(0.0, -0.03, 0.04), Vector3(0.2, 0.14, 0.24), Color(0.96, 0.96, 0.96)],
		[Vector3(0, 0.13, 0.16), Vector3(0.17, 0.16, 0.17), Color(0.08, 0.08, 0.12)],
		[Vector3(0, 0.12, 0.27), Vector3(0.05, 0.04, 0.09), Color(0.2, 0.2, 0.22)],
		[Vector3(0, 0.04, -0.34), Vector3(0.08, 0.05, 0.42), Color(0.1, 0.12, 0.25)],
	])
	bird.global_position = top + Vector3(0.85, 0.12, 0.0)
	bird.rotation.y = -0.6
	w["bird"] = bird
	# 땅에 놓인 바구니
	var basket := Node3D.new()
	world_node(basket)
	basket.global_position = stand + Vector3(-0.8, 0, 0.4)
	add_mcyl(basket, thatch_dark_mat, 0.32, 0.24, 0.3, Vector3(0, 0.15, 0))
	add_blobs(basket, [[Vector3(0, 0.29, 0), Vector3(0.6, 0.08, 0.6), Color(0.9, 0.78, 0.5)]], thatch_blob_mat)
	w["basket"] = basket
	w["in_basket"] = 0
	gam_info()

func gam_info() -> void:
	mg_progress = float(mg_count) / GAM_GOAL
	mg_info.text = tr("감 %d/%d | 남은 기회 %d") % [mg_count, GAM_GOAL, mg_lives]

func gam_ripe_color(k: float) -> Color:
	return Color(0.45, 0.65, 0.2).lerp(Color(0.98, 0.62, 0.12), clampf(k * 1.4, 0, 1)).lerp(Color(0.94, 0.32, 0.05), clampf(k * 1.4 - 0.4, 0, 1))

func update_gam(delta: float) -> void:
	var fruits: Array = w["fruits"]
	var speed := 1.0 + mg_count * 0.04
	var growing := 0
	for f in fruits:
		if f["state"] != "empty":
			growing += 1
	for f in fruits:
		var n: Node3D = f["node"]
		f["t"] = float(f["t"]) - delta * speed
		match f["state"]:
			"empty":
				if float(f["t"]) <= 0.0 and growing < 4:
					f["state"] = "green"
					f["dur"] = 0.0
					f["t"] = rng.randf_range(3.2, 5.0)
					n.visible = true
					n.scale = Vector3.ONE * 0.01
					n.global_position = f["pos"]
					gam_color(n, 0.0)
					growing += 1
			"green":
				f["dur"] = float(f["dur"]) + delta * speed
				var k := clampf(float(f["dur"]) / (float(f["dur"]) + maxf(float(f["t"]), 0.001)), 0, 1)
				n.scale = Vector3.ONE * minf(1.0, float(f["dur"]) * 4.0)
				gam_color(n, k * 0.75)
				n.global_position = (f["pos"] as Vector3) + Vector3(0, sin(anim_t * 2.0 + n.position.x) * 0.02, 0)
				if float(f["t"]) <= 0.0:
					f["state"] = "ripe"
					f["t"] = 3.0
					gam_color(n, 1.0)
					add_target_marker(n)
					pop3d(n)
			"ripe":
				var left := clampf(float(f["t"]) / 3.0, 0, 1)
				n.scale = Vector3.ONE * (1.0 + sin(anim_t * 9.0) * 0.06)
				update_target_marker(n, f["pos"], 1.0 - left)
				if float(f["t"]) <= 0.0:
					# 너무 익어서 툭 떨어졌어요
					hide_target_marker(n)
					f["state"] = "drop"
					f["vy"] = 0.0
					mg_lives -= 1
					mg_perfect = false
					sfx("bad")
					shake(8)
					float_text(tr("홍시가 떨어졌어요!"), cam.unproject_position(f["pos"]), Color(1, 0.55, 0.45), 1.0)
					gam_info()
			"drop":
				f["vy"] = float(f["vy"]) - 12.0 * delta
				n.global_position.y += float(f["vy"]) * delta
				if n.global_position.y <= 0.4:
					splash_gam(n.global_position)
					gam_reset(f)
			"pick":
				# 장대에 맞아 포물선을 그리며 바구니로
				var u := clampf(float(f["dur"]) + delta * 2.4, 0, 1)
				f["dur"] = u
				var a: Vector3 = f["from"]
				var b: Vector3 = (w["basket"] as Node3D).global_position + Vector3(0, 0.35, 0)
				n.global_position = a.lerp(b, u) + Vector3(0, sin(u * PI) * 0.8, 0)
				n.rotation.x += delta * 9.0
				if u >= 1.0:
					sfx("coin", 1.0 + mg_count * 0.05)
					w["in_basket"] = int(w["in_basket"]) + 1
					var bk: Node3D = w["basket"]
					var heap := blob_node([[Vector3.ZERO, Vector3(0.24, 0.21, 0.24), Color(0.94, 0.38, 0.06)]])
					var ib: int = w["in_basket"]
					heap.global_position = bk.global_position + Vector3(cos(ib * 2.4) * 0.14, 0.33 + ib * 0.025, sin(ib * 2.4) * 0.14)
					pop3d(bk)
					gam_reset(f)
	var bird: Node3D = w["bird"]
	bird.rotation.x = -0.4 * maxf(0.0, sin(anim_t * 5.0))
	gam_info()

func gam_color(n: Node3D, k: float) -> void:
	for mm in n.find_children("*", "MultiMeshInstance3D", true, false):
		var mmi := mm as MultiMeshInstance3D
		mmi.multimesh.set_instance_color(0, gam_ripe_color(k))
		return

func gam_reset(f: Dictionary) -> void:
	var n: Node3D = f["node"]
	n.visible = false
	n.rotation = Vector3.ZERO
	f["state"] = "empty"
	f["t"] = rng.randf_range(1.5, 3.0)

func splash_gam(at: Vector3) -> void:
	burst3d(at, Color(0.95, 0.4, 0.1), 12)
	sfx("pop", 0.6)

func gam_tap(pos: Vector2) -> void:
	var best := -1
	var best_d := short_side * 0.12
	var fruits: Array = w["fruits"]
	for i in fruits.size():
		var f: Dictionary = fruits[i]
		if f["state"] != "green" and f["state"] != "ripe":
			continue
		var sp := cam.unproject_position(f["pos"])
		var d := sp.distance_to(pos)
		if d < best_d:
			best_d = d
			best = i
	var kk: Array = w["kkachi"]
	for k in kk.size():
		var kn: Node3D = kk[k]
		if not kn.visible:
			continue
		var d2 := cam.unproject_position(kn.global_position).distance_to(pos)
		if d2 < best_d:
			best_d = d2
			best = 100 + k
	if best >= 100:
		var kn2: Node3D = kk[best - 100]
		mg_lives -= 1
		mg_perfect = false
		sfx("bad")
		shake(10)
		w["swing"] = 1.0
		float_text(tr("까치밥은 남겨 둬야지!"), cam.unproject_position(kn2.global_position), Color(1, 0.5, 0.4), 1.2)
		var bird: Node3D = w["bird"]
		pop3d(bird)
		sfx("chirp", 0.8)
		gam_info()
		return
	if best >= 0:
		gam_pick(best)

func gam_pick(i: int) -> void:
	var f: Dictionary = w["fruits"][i]
	var n: Node3D = f["node"]
	w["swing"] = 1.0
	if f["state"] == "green":
		mg_lives -= 1
		mg_perfect = false
		sfx("bad")
		shake(8)
		float_text(tr("아직 떫어요!"), cam.unproject_position(f["pos"]), Color(1, 0.55, 0.45), 1.1)
		pop3d(n)
		gam_info()
		return
	if f["state"] != "ripe":
		return
	hide_target_marker(n)
	mg_count += 1
	sfx("crack", 1.5)
	shake(4)
	hit_stop(0.04)
	cam_kick = 0.1
	burst3d(n.global_position, Color(1.0, 0.7, 0.2), 10)
	float_text([tr("톡!"), tr("쏙!"), tr("잘 익었다!")][mg_count % 3], cam.unproject_position(n.global_position), Color(1, 0.95, 0.7), 1.2)
	f["state"] = "pick"
	f["dur"] = 0.0
	f["from"] = n.global_position
	gam_info()

# ---------- 1장 땅 얼룩: 흙길, 마당, 개울가 진흙 ----------

func paint_ground_splat() -> void:
	# 흙길
	for pl in path_lines:
		var line: Array = pl[0]
		var w: float = pl[1]
		for i in line.size():
			var p: Vector2 = line[i]
			splat_stamp(splat_r, p.x, p.y, w * 0.2, w * 0.72)
	# 집 마당 (흥부네, 놀부네)은 흙이 드러나요
	for yard in [Rect2(-17.5, -5.2, 9.0, 8.0), Rect2(7.0, -3.0, 14.0, 9.5)]:
		var y := 0.0
		while y <= yard.size.y:
			var x := 0.0
			while x <= yard.size.x:
				splat_stamp(splat_r, yard.position.x + x, yard.position.y + y, 0.6, 2.2, 0.62)
				x += 1.2
			y += 1.2
	# 개울가 진흙
	var cx := -50.0
	while cx <= 50.0:
		splat_stamp(splat_g, cx, creek_z(cx), creek_half(cx) + 0.2, creek_half(cx) + 1.4)
		cx += 0.6
	# 연못 둘레
	for i in 48:
		var a := TAU * i / 48.0
		splat_stamp(splat_g, POND_C.x + cos(a) * 5.4, POND_C.z + sin(a) * 3.9, 0.4, 1.6)
	# 논두렁 둘레
	for fc in [[FARM_C, 9.0, 7.0], [Vector3(-34.5, 0, -3), 6.0, 6.0]]:
		var c: Vector3 = fc[0]
		var w2: float = fc[1] / 2.0 + 0.5
		var d2: float = fc[2] / 2.0 + 0.5
		var t := -1.0
		while t <= 1.0:
			splat_stamp(splat_g, c.x + t * w2, c.z - d2, 0.3, 1.1, 0.8)
			splat_stamp(splat_g, c.x + t * w2, c.z + d2, 0.3, 1.1, 0.8)
			splat_stamp(splat_g, c.x - w2, c.z + t * d2, 0.3, 1.1, 0.8)
			splat_stamp(splat_g, c.x + w2, c.z + t * d2, 0.3, 1.1, 0.8)
			t += 0.12

# 개울 건너 숲 바닥은 살짝 짙게
func splat_forest(_x: float, z: float) -> float:
	return clampf((-17.5 - z) / 4.0, 0.0, 1.0)

# 남쪽 이정표: 2장으로, 또는 버드나무 길 따라 집 마을(이야기골)로 가요
func on_gate() -> void:
	ask("", tr("“이 길을 따라가면 해와 달이 된 오누이 이야기”\n이정표 아래 작은 팻말: “버드나무 길: 이야기골(집 마을)”\n(흥부네 마을 이야기는 저장돼요. 돌아오면 이어서 할 수 있어요.)"), [tr("오누이 고갯길로 가기"), tr("이야기골(집 마을)로 가기"), tr("다음에 갈게요")], func(i: int):
		if i == 0:
			go_to_chapter("ch2")
		elif i == 1:
			go_to_chapter("home"))

# 집 마을에서 버드나무 길로 돌아오면 남쪽 이정표 안쪽에서 북쪽을 보고 서요
func arrive_from(from: String) -> void:
	if from == "home":
		player.position = Vector3(-2.0, 0.3, 29.0)
		cam_yaw = 0.0
		cam_yaw_target = 0.0
