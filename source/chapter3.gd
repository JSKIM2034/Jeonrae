extends "res://core.gd"

# 3장: 별주부전 (만드는 중)
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
const VILLAGE_C := Vector3(0, 0, 30)

var height_noise := FastNoiseLite.new()

func chapter_id() -> String:
	return "ch3"

func chapter_state() -> Dictionary:
	return {"quest": quest}

func restore_chapter_state(d: Dictionary) -> void:
	quest = d.get("quest", 0)

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
	var r := RandomNumberGenerator.new()
	r.seed = 7
	make_clouds(r)
	add_ridge_ring(170.0, 40.0, 10.0, 26.0, Color(0.3, 0.5, 0.28), Color(0.42, 0.6, 0.36), 41, Vector3(0, 0, 10))

func after_ui() -> void:
	player.position = Vector3(0, height_at(0, 46) + 0.2, 46)

func start_chapter() -> void:
	set_time_of_day(0.0)
	if resumed:
		show_card("3장 별주부전\n이어서 걸어요...", 0.6, 1.6, Callable())
		return
	show_card("3장\n별주부전\n\n(만드는 중인 바닷가를 미리 걸어 봐요.\n바닷속은 곧 열려요.)", 1.0, 4.0, Callable())

func update_quest_text() -> void:
	quest_label.text = "할 일: 바닷가를 둘러보기\n(3장 미리 보기 · 만드는 중) | 엽전 %d냥" % shown_coins

func cam_ground(x: float, z: float) -> float:
	return maxf(height_at(x, z), 0.2) if z < SHORE_Z else height_at(x, z)

# 남쪽 끝 이정표: 2장으로 돌아가요
func on_gate() -> void:
	ask("", "2장 오누이네 고갯길로 돌아갈까요?", ["돌아가기", "더 둘러볼래요"], func(i: int):
		if i == 0:
			go_to_chapter("ch2"))

# ---------- 땅 높이 ----------

func height_at(x: float, z: float) -> float:
	var h := 0.0
	if z > SHORE_Z:
		# 모래사장(물가에서 완만하게 오르다가) → 마을 언덕
		h = remap(clampf(z, SHORE_Z, 14.0), SHORE_Z, 14.0, 0.0, 1.0)
		h += smoothstep(14.0, 40.0, z) * 0.8
		h += height_noise.get_noise_2d(x, z) * 0.6 * smoothstep(10.0, 20.0, z)
	else:
		# 바다 밑: 물가에서 깊어져 산호 숲(-8 m) → 골짜기(-14 m) → 용궁 터(-11 m)
		var d := SHORE_Z - z
		h = -smoothstep(0.0, 30.0, d) * 8.0
		h -= smoothstep(60.0, 90.0, d) * 6.0
		h += smoothstep(110.0, 130.0, d) * 3.0
		h += height_noise.get_noise_2d(x, z) * 1.4 * smoothstep(4.0, 20.0, d)
	# 양옆은 바위 절벽, 남쪽 끝은 뒷산
	h += 26.0 * smoothstep(40.0, 56.0, absf(x))
	h += 18.0 * smoothstep(48.0, 58.0, z)
	h += 30.0 * smoothstep(-136.0, -148.0, z)
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
	# 바닷속은 아직 만드는 중: 물가에서 막아 둬요
	add_solid(Vector3(0, 5, SHORE_Z - 3.0), Vector3(90, 20, 1), none)

# 모래사장은 흙빛, 마을 길도 흙빛으로
func paint_ground_splat() -> void:
	var x := -44.0
	while x <= 44.0:
		var z := SHORE_Z - 30.0
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
	var c := Vector3(0, 0, (SHORE_Z + C3_Z0) / 2.0)
	var wd := C3_X1 - C3_X0
	var dp := SHORE_Z - C3_Z0 + 4.0
	add_mbox(self, water_material(2, Vector4(c.x, c.z, wd / 2.0, dp / 2.0), Color(0.08, 0.36, 0.55), Color(0.3, 0.68, 0.78), Vector2(0.0, 0.03), 0.9), Vector3(wd, 0.02, dp), c + Vector3(0, 0.05, 2.0))

# ---------- 바닷가 마을 (만드는 중) ----------

func make_shore_village() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 13
	var c := VILLAGE_C
	make_house(on_ground(c.x - 8, c.z), Vector3(4.4, 2.7, 3.4), Color(0.93, 0.89, 0.8), Color(0.8, 0.66, 0.3), "thatch")
	make_house(on_ground(c.x + 9, c.z + 2), Vector3(4.2, 2.6, 3.3), Color(0.93, 0.89, 0.8), Color(0.78, 0.64, 0.3), "thatch")
	# 모래사장 바위
	var rocks := []
	for i in 26:
		var p := Vector2(r.randf_range(-36, 36), r.randf_range(SHORE_Z - 2.0, 8.0))
		if absf(p.x) < 4.0:
			continue
		var sz := Vector3(r.randf_range(0.6, 1.8), r.randf_range(0.4, 1.0), r.randf_range(0.6, 1.5))
		rocks.append([on_ground(p.x, p.y, sz.y * 0.3), sz, stone_color(r)])
	add_blobs(self, rocks, stone_blob_mat)
	# 마을 뒤 나무
	for k in 16:
		var p2 := Vector2(r.randf_range(-36, 36), r.randf_range(22, 48))
		if absf(p2.x) < 5.0 or Vector2(p2.x - c.x, p2.y - c.z).length() < 12.0:
			continue
		make_tree(on_ground(p2.x, p2.y, -0.1))
	# 남쪽 끝 이정표 (2장으로 돌아가기)
	var gate := make_spot(on_ground(3.2, 49.0), "gate", "", "", true)
	add_mcyl(gate, wood_mat, 0.1, 0.12, 2.2, Vector3(0, 1.1, 0))
	add_mbox(gate, plank_mat, Vector3(1.6, 0.45, 0.08), Vector3(0, 1.85, 0.08))
	add_tag(gate, "2장 고갯길로 가는 길", 2.6)
