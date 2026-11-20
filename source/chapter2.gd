extends "res://core.gd"

# 2장: 해와 달이 된 오누이 (만드는 중)
# 공통 부분(core.gd)을 그대로 쓰고, 맵과 이야기만 여기에 새로 만들어요.
#
# 맵은 남쪽 잔칫집 마을에서 시작해 북쪽으로 고개 셋을 넘어 오누이 오두막과 수수밭까지 이어지는 한 갈래 길이에요.
# 북쪽으로 갈수록 시간이 흘러 한낮 → 노을 → 깊은 밤이 돼요.

# 땅의 범위 (x: 왼쪽~오른쪽, z: 북쪽~남쪽)
const C2_X0 := -50.0
const C2_X1 := 50.0
const C2_Z0 := -84.0
const C2_Z1 := 72.0
const C2_STEP := 2.0

const VILLAGE_C := Vector3(0, 0, 28)
const COTTAGE_C := Vector3(6, 0, -62)
const FIELD_C := Vector3(24, 0, -66)

# 고개 셋: [능선 z, 고개(길이 넘는 낮은 곳) x, 높이]
const RIDGES := [[2.0, -10.0, 7.0], [-20.0, 12.0, 10.0], [-42.0, -8.0, 12.0]]

# 길이 지나가는 점들 (마을 → 고개 셋 → 오두막 → 수수밭)
const ROAD := [
	Vector2(0, 54), Vector2(0, 40), Vector2(0, 28), Vector2(-3, 16), Vector2(-8, 8), Vector2(-10, 2),
	Vector2(-7, -6), Vector2(2, -12), Vector2(10, -17), Vector2(12, -20.5), Vector2(9, -27), Vector2(1, -33),
	Vector2(-6, -38.5), Vector2(-8, -42.5), Vector2(-5, -49), Vector2(0, -55), Vector2(5, -59),
]
const FIELD_ROAD := [Vector2(5, -59), Vector2(12, -62.5), Vector2(18, -64.5)]

var height_noise := FastNoiseLite.new()
var road_pts: PackedVector2Array

func chapter_id() -> String:
	return "ch2"

func chapter_state() -> Dictionary:
	return {"time": time_of_day, "quest": quest, "feast": feast, "delivered": delivered, "stones": stones, "ending": ending, "basket": basket}

func restore_chapter_state(d: Dictionary) -> void:
	time_of_day = d.get("time", 0.0)
	quest = d.get("quest", S_ARRIVE)
	feast = d.get("feast", feast)
	delivered = d.get("delivered", [])
	stones = d.get("stones", stones)
	ending = d.get("ending", "")
	basket = d.get("basket", BASKET_FULL)

func build_chapter() -> void:
	height_noise.seed = 21
	height_noise.frequency = 0.035
	height_noise.fractal_octaves = 2
	road_pts = smooth_road(ROAD, 6)
	make_surface_materials()
	make_light_and_sky()
	make_stars()
	splat_rect = Rect2(-100, -142, 200, 200)
	make_terrain()
	make_feast_village()
	make_passes()
	make_cottage()
	make_sorghum()
	make_terrain_grass()
	make_story()
	var r := RandomNumberGenerator.new()
	r.seed = 5
	make_clouds(r)
	var mid := Vector3(0, 0, -20)
	add_ridge_ring(150.0, 40.0, 14.0, 30.0, Color(0.28, 0.48, 0.24), Color(0.4, 0.58, 0.34), 31, mid)
	add_ridge_ring(200.0, 50.0, 28.0, 56.0, Color(0.34, 0.48, 0.5), Color(0.46, 0.58, 0.64), 37, mid)

func after_ui() -> void:
	player.position = Vector3(0, height_at(0, 46) + 0.2, 46)

func start_chapter() -> void:
	apply_story_state()
	time_of_day = story_time(player.position.z)
	set_time_of_day(time_of_day)
	if resumed:
		show_card("2장 해와 달이 된 오누이\n이어서 걸어요...", 0.6, 1.6, Callable())
		return
	show_card("2장\n해와 달이 된 오누이\n\n책장을 넘기자\n왁자지껄한 잔칫집 마당이 펼쳐졌어요.", 1.0, 4.0, Callable())

# 걸어갈수록 시간이 흘러요: 마을은 한낮, 첫째 고개 넘어 늦은 오후, 셋째 고개에서 해 질 녘, 오두막은 깊은 밤
func _process(delta: float) -> void:
	super(delta)
	if player == null:
		return
	var t := story_time(player.position.z)
	set_time_of_day(lerpf(time_of_day, t, minf(1.0, delta * 2.0)))
	update_story(delta)

func cam_ground(x: float, z: float) -> float:
	return height_at(x, z)

# 남쪽 끝 이정표: 1장 마을로 돌아가요
func on_gate() -> void:
	ask("", "1장 흥부네 마을로 돌아갈까요?", ["돌아가기", "더 둘러볼래요"], func(i: int):
		if i == 0:
			go_to_chapter("ch1"))

# ---------- 땅 높이 ----------

const STREAM_Z := -30.0
const STREAM_HALF := 3.6
const STREAM_DEPTH := 2.4

func height_at(x: float, z: float) -> float:
	var h := 0.0
	for rd in RIDGES:
		var rz: float = rd[0]
		var sx: float = rd[1]
		var hh: float = rd[2]
		# 길이 넘는 고개 자리는 낮고, 옆으로 갈수록 봉우리처럼 높아져요
		var across := exp(-pow((z - rz) / 8.0, 2.0))
		var side := 0.5 + 0.5 * smoothstep(0.0, 16.0, absf(x - sx))
		h += hh * across * side
	# 양옆과 남북 끝은 산으로 막혀 있어요
	h += 22.0 * smoothstep(30.0, 46.0, absf(x))
	h += 18.0 * smoothstep(58.0, 70.0, z)
	h += 18.0 * smoothstep(-72.0, -82.0, z)
	# 잔잔한 굴곡
	h += height_noise.get_noise_2d(x, z) * 1.2
	# 마을과 오두막 마당은 평평하게
	var flat := 1.0
	flat *= smoothstep(14.0, 24.0, Vector2(x - VILLAGE_C.x, z - VILLAGE_C.z).length())
	flat *= smoothstep(9.0, 16.0, Vector2(x - COTTAGE_C.x, z - COTTAGE_C.z).length())
	flat *= smoothstep(9.0, 15.0, Vector2(x - FIELD_C.x, z - FIELD_C.z).length())
	# 길 위는 굴곡을 줄여 걷기 편하게
	var road_d := road_distance(Vector2(x, z))
	var road_soft := smoothstep(1.5, 6.0, road_d)
	h = h * flat + (1.0 - flat) * 0.0
	h -= height_noise.get_noise_2d(x, z) * 1.2 * (1.0 - road_soft) * flat
	# 둘째·셋째 고개 사이 개울 (징검다리로 건너요)
	h -= STREAM_DEPTH * (1.0 - smoothstep(STREAM_HALF - 0.6, STREAM_HALF + 0.8, absf(z - STREAM_Z)))
	return h

func road_distance(p: Vector2) -> float:
	var best := 1e9
	for i in range(0, road_pts.size() - 1):
		var a := road_pts[i]
		var b := road_pts[i + 1]
		var ab := b - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		best = minf(best, p.distance_to(a + ab * t))
	return best

func smooth_road(pts: Array, sub: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in pts.size() - 1:
		var p0: Vector2 = pts[maxi(i - 1, 0)]
		var p1: Vector2 = pts[i]
		var p2: Vector2 = pts[i + 1]
		var p3: Vector2 = pts[mini(i + 2, pts.size() - 1)]
		for s in sub:
			var t := float(s) / sub
			var t2 := t * t
			var t3 := t2 * t
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	out.append(pts[pts.size() - 1])
	return out

func on_ground(x: float, z: float, lift: float = 0.0) -> Vector3:
	return Vector3(x, height_at(x, z) + lift, z)

# ---------- 땅 만들기 (모양 + 밟을 수 있는 바닥) ----------

func make_terrain() -> void:
	var nx := int((C2_X1 - C2_X0) / C2_STEP) + 1
	var nz := int((C2_Z1 - C2_Z0) / C2_STEP) + 1
	var heights := PackedFloat32Array()
	heights.resize(nx * nz)
	for iz in nz:
		for ix in nx:
			heights[iz * nx + ix] = height_at(C2_X0 + ix * C2_STEP, C2_Z0 + iz * C2_STEP)
	# 보이는 땅
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for iz in nz - 1:
		for ix in nx - 1:
			var q := []
			for c in [[ix, iz], [ix + 1, iz], [ix + 1, iz + 1], [ix, iz + 1]]:
				q.append(Vector3(C2_X0 + c[0] * C2_STEP, heights[c[1] * nx + c[0]], C2_Z0 + c[1] * C2_STEP))
			for idx in [0, 1, 2, 0, 2, 3]:
				st.add_vertex(q[idx])
	st.index()
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = ground_mat
	add_child(mi)
	# 밟는 바닥 (같은 높이 자료)
	var body := StaticBody3D.new()
	add_child(body)
	var col := CollisionShape3D.new()
	var hs := HeightMapShape3D.new()
	hs.map_width = nx
	hs.map_depth = nz
	# 바닥 모양은 크기를 고르게 키워야 해서, 높이를 미리 나눠 두고 통째로 C2_STEP 배 키워요
	var scaled := PackedFloat32Array()
	scaled.resize(heights.size())
	for i in heights.size():
		scaled[i] = heights[i] / C2_STEP
	hs.map_data = scaled
	col.shape = hs
	col.scale = Vector3.ONE * C2_STEP
	col.position = Vector3((C2_X0 + C2_X1) / 2.0, 0, (C2_Z0 + C2_Z1) / 2.0)
	body.add_child(col)
	# 보이지 않는 울타리 (산 너머로 못 가게)
	var none := Color(0, 0, 0, 0)
	add_solid(Vector3(0, 10, 52), Vector3(100, 40, 1), none)
	add_solid(Vector3(0, 10, C2_Z0 + 10), Vector3(100, 40, 1), none)
	add_solid(Vector3(-36, 10, -10), Vector3(1, 40, 160), none)
	add_solid(Vector3(36, 10, -10), Vector3(1, 40, 160), none)

func paint_ground_splat() -> void:
	for i in road_pts.size() - 1:
		var a := road_pts[i]
		var b := road_pts[i + 1]
		var n := int(a.distance_to(b) / 0.5) + 1
		for k in n:
			var p := a.lerp(b, float(k) / n)
			splat_stamp(splat_r, p.x, p.y, 0.5, 1.7)
	var fr := smooth_road(FIELD_ROAD, 6)
	for i in fr.size() - 1:
		for k in 8:
			var p2 := fr[i].lerp(fr[i + 1], k / 8.0)
			splat_stamp(splat_r, p2.x, p2.y, 0.3, 1.3)
	# 잔칫집 마당, 오두막 마당은 흙이 드러나요
	for yard in [[VILLAGE_C + Vector3(-6, 0, -2), 7.0], [COTTAGE_C, 5.0]]:
		var c: Vector3 = yard[0]
		var rr: float = yard[1]
		var t := 0.0
		while t < TAU:
			for k in 4:
				var d := rr * (k + 1) / 4.0
				splat_stamp(splat_r, c.x + cos(t) * d, c.z + sin(t) * d, 0.8, 2.4, 0.62)
			t += 0.35
	# 수수밭 흙
	for ix in 7:
		for iz in 6:
			splat_stamp(splat_g, FIELD_C.x - 6 + ix * 2.0, FIELD_C.z - 5 + iz * 2.0, 1.0, 2.2, 0.8)

# 고개 숲 바닥은 살짝 짙게
func splat_forest(x: float, z: float) -> float:
	return clampf(height_at(x, z) / 6.0, 0.0, 1.0) * 0.8

# ---------- 잔칫집 마을 (한낮, 시작) ----------

func make_feast_village() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 12
	var c := VILLAGE_C
	# 잔치를 여는 큰 기와집
	make_house(c + Vector3(-9, 0, -4), Vector3(7.5, 3.4, 4.6), Color(0.95, 0.92, 0.85), Color(0.36, 0.38, 0.42), "tile")
	# 둘레 초가들
	make_house(c + Vector3(9, 0, -6), Vector3(4.6, 2.8, 3.6), Color(0.93, 0.89, 0.8), Color(0.8, 0.66, 0.3), "thatch")
	make_house(c + Vector3(10, 0, 8), Vector3(4.2, 2.7, 3.4), Color(0.93, 0.89, 0.8), Color(0.78, 0.64, 0.3), "thatch")
	make_house(c + Vector3(-11, 0, 9), Vector3(4.4, 2.7, 3.4), Color(0.93, 0.89, 0.8), Color(0.8, 0.66, 0.3), "thatch")
	# 마당에 친 차일 (하얀 천 그늘막)과 잔칫상
	var tent := c + Vector3(-6, 0, 2.5)
	for px in [-2.6, 2.6]:
		for pz in [-1.8, 1.8]:
			add_mcyl(self, wood_mat, 0.06, 0.07, 2.6, tent + Vector3(px, 1.3, pz))
	var cloth := add_mbox(self, make_color(Color(0.98, 0.96, 0.9)), Vector3(5.8, 0.06, 4.2), tent + Vector3(0, 2.6, 0))
	cloth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for tx in [-1.4, 1.4]:
		add_mbox(self, dark_wood_mat, Vector3(2.0, 0.08, 0.8), tent + Vector3(tx, 0.45, 0))
		for leg in [-0.85, 0.85]:
			add_mbox(self, dark_wood_mat, Vector3(0.08, 0.42, 0.6), tent + Vector3(tx + leg, 0.21, 0))
		# 떡 접시 (시루떡, 백설기, 쑥떡, 꿀떡)
		var cakes := []
		for k in 4:
			var cp := tent + Vector3(tx - 0.65 + k * 0.43, 0.52, r.randf_range(-0.15, 0.15))
			cakes.append([cp, Vector3(0.32, 0.03, 0.32), Color(0.95, 0.95, 0.92)])
			var cc: Color = [Color(0.72, 0.42, 0.32), Color(0.98, 0.97, 0.92), Color(0.45, 0.6, 0.32), Color(0.95, 0.78, 0.4)][k]
			for m in 3:
				cakes.append([cp + Vector3((m - 1) * 0.07, 0.05 + (m % 2) * 0.03, 0), Vector3(0.09, 0.06, 0.09), cc])
		add_blobs(self, cakes)
	# 등롱 줄
	for k in 5:
		add_lantern(self, tent + Vector3(-2.4 + k * 1.2, 2.25, 2.0))
	# 장독대, 바구니, 평상
	make_jangdok(c + Vector3(-15, 0, -6), r)
	make_bench(c + Vector3(4, 0, 4), 0.3)
	make_basket(c + Vector3(-3, 0, 5.5), 1.0, Color(0.98, 0.97, 0.92))
	make_stall(c + Vector3(6, 0, -12))
	# 마을 둘레 나무
	for k in 18:
		var ang := k * TAU / 18.0 + r.randf_range(-0.1, 0.1)
		var p := Vector2(c.x + cos(ang) * r.randf_range(19, 24), c.z + sin(ang) * r.randf_range(17, 22))
		if road_distance(p) > 4.0:
			make_tree(on_ground(p.x, p.y))
	# 마을 북쪽 어귀의 장승
	make_jangseung(on_ground(-8.5, 12), false)
	make_jangseung(on_ground(-1.2, 12), true)
	# 남쪽 끝 이정표 (1장으로 돌아가기)
	var gate := make_spot(on_ground(3.2, 49.0), "gate", "", "", true)
	add_mcyl(gate, wood_mat, 0.1, 0.12, 2.2, Vector3(0, 1.1, 0))
	add_mbox(gate, plank_mat, Vector3(1.6, 0.45, 0.08), Vector3(0, 1.85, 0.08))
	add_tag(gate, "1장 마을로 가는 길", 2.6)
	# 북쪽 끝 이정표 (3장 바닷가로)
	var gate3 := make_spot(on_ground(-6.0, -71.0), "gate", "ch3", "", true)
	add_mcyl(gate3, wood_mat, 0.1, 0.12, 2.2, Vector3(0, 1.1, 0))
	add_mbox(gate3, plank_mat, Vector3(1.6, 0.45, 0.08), Vector3(0, 1.85, 0.08))
	add_tag(gate3, "3장 바닷가로 가는 길", 2.6)

# ---------- 고개 셋 (숲과 바위) ----------

func make_passes() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 33
	var placed := 0
	var tries := 0
	while placed < 120 and tries < 4000:
		tries += 1
		var x := r.randf_range(-32, 32)
		var z := r.randf_range(-50, 14)
		var p := Vector2(x, z)
		if road_distance(p) < 4.5:
			continue
		var h := height_at(x, z)
		# 언덕 위일수록 숲이 빽빽해요
		if r.randf() > clampf(0.25 + h / 8.0, 0.0, 0.95):
			continue
		make_tree(Vector3(x, h - 0.1, z))
		placed += 1
	# 길가 바위
	var rocks := []
	for i in 60:
		var t := r.randf()
		var idx := int(t * (road_pts.size() - 2))
		var a := road_pts[idx]
		var dir := (road_pts[idx + 1] - a).normalized()
		var side := Vector2(-dir.y, dir.x) * (r.randf_range(2.6, 5.0) * (1.0 if r.randf() < 0.5 else -1.0))
		var p2 := a + side
		if p2.y > 14.0 or p2.y < -50.0:
			continue
		var sz := Vector3(r.randf_range(0.5, 1.4), r.randf_range(0.35, 0.8), r.randf_range(0.5, 1.2))
		rocks.append([on_ground(p2.x, p2.y, sz.y * 0.3), sz, stone_color(r)])
	add_blobs(self, rocks, stone_blob_mat)
	# 고개마다 서낭당 돌무더기 (지나는 사람이 돌을 하나씩 얹어요)
	for rd in RIDGES:
		var sx: float = rd[1] + 3.2
		var sz2: float = rd[0]
		var base := on_ground(sx, sz2)
		var pile := []
		for k in 14:
			var lv := k / 5
			pile.append([base + Vector3(r.randf_range(-0.5, 0.5) * (1.0 - lv * 0.3), 0.15 + lv * 0.28, r.randf_range(-0.5, 0.5) * (1.0 - lv * 0.3)), Vector3(0.4, 0.28, 0.35), stone_color(r)])
		add_blobs(self, pile, stone_blob_mat)

# ---------- 오누이 오두막 (깊은 밤) ----------

func make_cottage() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 44
	var c := COTTAGE_C
	var hut := make_house(c + Vector3(-1, 0, -3), Vector3(4.2, 2.6, 3.3), Color(0.8, 0.74, 0.64), Color(0.6, 0.53, 0.38), "thatch")
	make_hut_shabby(hut)
	# 창호지로 새어 나오는 등잔불
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.72, 0.4)
	lamp.light_energy = 1.6
	lamp.omni_range = 7.0
	lamp.position = c + Vector3(-1, 1.4, -0.9)
	add_child(lamp)
	# 우물과 그 옆 큰 나무 (오누이가 올라갈 나무)
	var well := StaticBody3D.new()
	well.position = c + Vector3(4.5, 0, 1.5)
	add_child(well)
	var wc := CollisionShape3D.new()
	var ws := CylinderShape3D.new()
	ws.radius = 0.9
	ws.height = 1.2
	wc.shape = ws
	wc.position.y = 0.6
	well.add_child(wc)
	make_well_visual(well)
	make_tree(c + Vector3(6.6, 0, -0.6), "Broad1")
	# 싸리 울타리
	var fence := []
	for k in 26:
		var a := k * TAU / 26.0
		if absf(wrapf(a - PI * 0.5, -PI, PI)) < 0.45:
			continue
		var p := c + Vector3(cos(a) * 8.0, 0, sin(a) * 6.5)
		fence.append([p + Vector3(0, 0.45, 0), Vector3(0.9, 0.9, 0.12), Color(0.55, 0.44, 0.3), Vector3(0, -rad_to_deg(a) + 90, 0)])
	add_blobs(self, fence, thatch_blob_mat)
	make_jangdok(c + Vector3(-5.5, 0, 1.0), r)
	# 둘레 숲
	for k in 22:
		var ang := k * TAU / 22.0 + r.randf_range(-0.1, 0.1)
		var p2 := Vector2(c.x + cos(ang) * r.randf_range(12, 17), c.z + sin(ang) * r.randf_range(11, 15))
		if road_distance(p2) > 4.0 and p2.distance_to(Vector2(FIELD_C.x, FIELD_C.z)) > 9.0:
			make_tree(on_ground(p2.x, p2.y, -0.1))

# ---------- 수수밭 (이야기 끝에 붉게 물드는 곳) ----------

func make_sorghum() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 55
	var stalk := CylinderMesh.new()
	stalk.top_radius = 0.025
	stalk.bottom_radius = 0.035
	stalk.height = 2.2
	stalk.radial_segments = 5
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = stalk
	var heads := []
	var xs := []
	for ix in 12:
		for iz in 10:
			var p := FIELD_C + Vector3(-6.5 + ix * 1.15 + r.randf_range(-0.2, 0.2), 0, -5.5 + iz * 1.15 + r.randf_range(-0.2, 0.2))
			var hgt := r.randf_range(1.9, 2.5)
			var tilt := Basis(Vector3(r.randf_range(-1, 1), 0, r.randf_range(-1, 1)).normalized(), r.randf_range(0.0, 0.12))
			xs.append([Transform3D(tilt.scaled(Vector3(1, hgt / 2.2, 1)), p + tilt * Vector3(0, hgt / 2.0, 0)), Color(0.55, 0.62, 0.32).lerp(Color(0.66, 0.6, 0.34), r.randf())])
			var top := p + tilt * Vector3(0, hgt, 0)
			heads.append([top + Vector3(0, 0.12, 0), Vector3(0.16, 0.34, 0.16), Color(0.62, 0.3, 0.2).lerp(Color(0.72, 0.42, 0.24), r.randf()), Vector3(r.randf_range(-20, 20), 0, r.randf_range(-20, 20))])
			# 길쭉한 잎 두 장
			for lf in 2:
				var ly := r.randf_range(0.6, 1.4)
				heads.append([p + tilt * Vector3(0, ly, 0) + Vector3((lf * 2 - 1) * 0.22, 0, 0), Vector3(0.48, 0.03, 0.08), Color(0.48, 0.62, 0.3), Vector3(0, r.randf() * 180.0, (lf * 2 - 1) * -25.0)])
	mm.instance_count = xs.size()
	for i in xs.size():
		mm.set_instance_transform(i, xs[i][0])
		mm.set_instance_color(i, xs[i][1])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	sorghum_mm = mm
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	mi.material_override = m
	add_child(mi)
	add_blobs(self, heads)

# ---------- 풀 포기 (언덕 높이를 따라) ----------

func make_terrain_grass() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 66
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = make_tuft_mesh()
	var items := []
	var tries := 0
	while items.size() < 2600 and tries < 9000:
		tries += 1
		var x := r.randf_range(-34, 34)
		var z := r.randf_range(-80, 52)
		var p := Vector2(x, z)
		if road_distance(p) < 1.4:
			continue
		if Vector2(x - FIELD_C.x, z - FIELD_C.z).length() < 8.0:
			continue
		items.append(Vector3(x, height_at(x, z) - 0.02, z))
	mm.instance_count = items.size()
	for i in items.size():
		var bs := Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3.ONE * r.randf_range(0.6, 1.1))
		mm.set_instance_transform(i, Transform3D(bs, items[i]))
		mm.set_instance_color(i, Color(0.42, 0.66, 0.32).lerp(Color(0.62, 0.82, 0.42), r.randf()))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = grass_material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

# ======================================================================
# 이야기: 해와 달이 된 오누이
# 잔칫집에서 일하는 엄마를 돕고, 떡 광주리를 이고 함께 고개 셋을 넘어요.
# 호랑이가 고개마다 "떡 하나 주면 안 잡아먹지"... 엄마의 일은 부드럽게, 말로만 전해요.
# ======================================================================

const S_ARRIVE := 0   # 잔칫집에서 엄마 찾기
const S_FEAST := 1    # 잔치 일 돕기
const S_LEAVE := 2    # 엄마와 첫째 고개로
const S_PASS2 := 3    # 둘째 고개
const S_PASS3 := 4    # 셋째 고개
const S_RUN := 5      # 오두막까지 먼저 달려가기
const S_WARN := 6     # 오누이에게 알리기
const S_DOOR := 7     # 엄마 흉내 내는 호랑이
const S_TREE := 8     # 우물가 나무로
const S_ROPE := 9     # 동아줄
const S_END := 10

const BASKET_FULL := 12
const MOM_POS := Vector3(-2.6, 0, 27.4)
const HOST_POS := Vector3(-9.5, 0, 27.2)
const COOK_POS := Vector3(-4.5, 0, 37.0)
const ANBAN_POS := Vector3(3.4, 0, 25.0)
const GUEST_POS := {"guest1": Vector3(4.8, 0, 32.4), "guest2": Vector3(9.4, 0, 31.6), "guest3": Vector3(6.4, 0, 19.4)}
const GUEST_NAME := {"guest1": "김 서방", "guest2": "새댁", "guest3": "윤 영감"}
# 고개마다 호랑이가 나타나는 자리와, 그 일이 생기는 높이(z)
const TIGER_SPOTS := [Vector3(-9.6, 0, -1.5), Vector3(11.6, 0, -24.0), Vector3(-7.4, 0, -46.0)]
const TRIGGER_Z := [7.0, -15.5, -38.5]

var feast := {"pound": false, "tteok": false}
var delivered: Array = []
var stones := [false, false, false]
var ending := ""
var basket := BASKET_FULL
var sorghum_mm: MultiMesh
var mom_follow := false
var mom_phase := 0.0
var mom_amt := 0.0
var tiger: Node3D
var tiger_tail: Node3D
var tiger_disguise: Node3D
var tiger_goal := Vector3.ZERO
var tiger_speed := 0.0
var run_active := false
var run_wait := 0.0
var run_path: PackedVector2Array
var run_i := 0
var event_lock := false
var tree_pos := COTTAGE_C + Vector3(6.6, 0, -0.6)
var well_pos := COTTAGE_C + Vector3(4.5, 0, 1.5)
var kids_home := {"oppa": COTTAGE_C + Vector3(0.6, 0, 1.0), "nui": COTTAGE_C + Vector3(-0.9, 0, 1.1)}
var anban_dough: Node3D
var sky_rope: Node3D

func make_story() -> void:
	# 잔칫집 사람들
	make_npc("mom", "엄마", Color.WHITE, MOM_POS, 1.0, false)
	make_npc("host", "잔칫집 영감", Color.WHITE, HOST_POS, 1.0, true)
	make_npc("cook", "떡집 할머니", Color.WHITE, COOK_POS, 1.0, true)
	for g in GUEST_POS:
		make_npc(g, GUEST_NAME[g], Color.WHITE, GUEST_POS[g], 1.0, true)
	# 오누이
	make_npc("oppa", "오빠", Color.WHITE, kids_home["oppa"], 0.72, false)
	make_npc("nui", "누이", Color.WHITE, kids_home["nui"], 0.66, false)
	# 떡메치기 안반 (넓적한 나무판 위의 찰떡)
	var anban := make_spot(ANBAN_POS, "pound", "", "떡메치기", true)
	add_mbox(anban, plank_mat, Vector3(1.5, 0.12, 0.75), Vector3(0, 0.46, 0))
	for lx in [-0.6, 0.6]:
		add_mbox(anban, dark_wood_mat, Vector3(0.12, 0.4, 0.6), Vector3(lx, 0.2, 0))
	anban_dough = Node3D.new()
	anban_dough.position = Vector3(0, 0.56, 0)
	anban.add_child(anban_dough)
	add_blobs(anban_dough, [[Vector3.ZERO, Vector3(0.95, 0.2, 0.55), Color(0.98, 0.97, 0.92)], [Vector3(0.15, 0.04, 0.05), Vector3(0.5, 0.14, 0.32), Color(1, 1, 0.97)]])
	add_solid(ANBAN_POS + Vector3(0, 0.4, 0), Vector3(1.5, 0.8, 0.75), Color(0, 0, 0, 0))
	# 떡 찌는 아궁이와 시루
	var hearth := COOK_POS + Vector3(-1.1, 0, -0.9)
	add_blobs(self, [
		[hearth + Vector3(0, 0.35, 0), Vector3(1.1, 0.7, 0.9), Color(0.55, 0.5, 0.46)],
		[hearth + Vector3(0, 0.25, 0.42), Vector3(0.42, 0.32, 0.1), Color(0.95, 0.45, 0.15)],
		[hearth + Vector3(0, 0.86, 0), Vector3(0.7, 0.42, 0.7), Color(0.6, 0.38, 0.26)],
		[hearth + Vector3(0, 1.1, 0), Vector3(0.6, 0.1, 0.6), Color(0.96, 0.95, 0.9)],
	], stone_blob_mat)
	add_solid(hearth + Vector3(0, 0.5, 0), Vector3(1.1, 1.0, 0.9), Color(0, 0, 0, 0))
	# 고개마다 서낭당 돌무더기에 돌을 얹을 수 있어요
	for i in RIDGES.size():
		var rd: Array = RIDGES[i]
		var p := on_ground(float(rd[1]) + 3.4, float(rd[0]) + 1.5)
		make_spot(p, "stone", str(i), "", true)
	# 오두막 우물가 나무: 오르기, 하늘에 빌기
	make_spot(tree_pos + Vector3(-1.2, 0, 1.4), "climb", "", "", true)
	make_spot(tree_pos + Vector3(-1.4, 0, 1.6), "pray", "", "", true)
	make_tiger()
	make_stack_table()
	make_fireflies()
	make_stream()
	make_lantern()

# 호랑이: Meshy 모델(호랑이, 엄마 옷 입은 호랑이)이 있으면 그걸 쓰고, 없으면 둥글둥글한 덩어리로 만들어요
var tiger_plain: Node3D
var tiger_models: Array = []   # 뼈대 있는 몸 (걸음 자세용)

func set_disguise(on: bool) -> void:
	tiger_disguise.visible = on
	if tiger_plain != null:
		tiger_plain.visible = not on

func make_tiger() -> void:
	tiger = Node3D.new()
	tiger.visible = false
	add_child(tiger)
	var body := Node3D.new()
	body.name = "Body"
	tiger.add_child(body)
	tiger_tail = Node3D.new()
	if ResourceLoader.exists("res://models/tiger.glb"):
		body.add_child(tiger_tail)
		tiger_plain = Node3D.new()
		body.add_child(tiger_plain)
		tiger_disguise = Node3D.new()
		tiger_disguise.visible = false
		body.add_child(tiger_disguise)
		for pair in [[tiger_plain, "tiger"], [tiger_disguise, "tigermom"]]:
			var mdl := make_person(pair[0], pair[1], Color.WHITE, false)
			if mdl != null and mdl.has_meta("skel"):
				tiger_models.append(mdl)
		return
	body.scale = Vector3.ONE * 1.25
	var org := Color(0.96, 0.56, 0.18)
	var wht := Color(0.99, 0.96, 0.9)
	var blk := Color(0.14, 0.11, 0.1)
	var items := [
		[Vector3(0, 0.85, 0), Vector3(0.9, 0.78, 1.6), org],
		[Vector3(0, 0.7, 0.08), Vector3(0.72, 0.5, 1.3), wht],
		[Vector3(0, 1.38, 0.86), Vector3(0.86, 0.76, 0.74), org],
		[Vector3(0, 1.24, 1.16), Vector3(0.46, 0.32, 0.26), wht],
		[Vector3(0, 1.34, 1.29), Vector3(0.13, 0.09, 0.07), Color(0.3, 0.15, 0.15)],
		[Vector3(0, 1.13, 1.2), Vector3(0.2, 0.08, 0.1), Color(0.75, 0.3, 0.3)],
	]
	for sx in [-1.0, 1.0]:
		items.append([Vector3(sx * 0.18, 1.47, 1.16), Vector3(0.11, 0.13, 0.05), blk])
		items.append([Vector3(sx * 0.18 + 0.03, 1.5, 1.19), Vector3(0.04, 0.04, 0.02), Color(1, 1, 1)])
		items.append([Vector3(sx * 0.28, 1.72, 0.8), Vector3(0.2, 0.22, 0.1), org])
		items.append([Vector3(sx * 0.28, 1.71, 0.84), Vector3(0.11, 0.13, 0.04), wht])
		items.append([Vector3(sx * 0.33, 1.38, 1.0), Vector3(0.05, 0.22, 0.05), blk, Vector3(0, 0, sx * 70)])
		for fz in [0.52, -0.52]:
			items.append([Vector3(sx * 0.28, 0.36, fz), Vector3(0.27, 0.74, 0.27), org])
			items.append([Vector3(sx * 0.28, 0.07, fz + 0.06), Vector3(0.31, 0.15, 0.38), wht])
	for k in 5:
		items.append([Vector3(0, 0.86, -0.56 + k * 0.27), Vector3(0.92, 0.8, 0.07), blk])
	for k in 3:
		items.append([Vector3(0, 1.66, 0.7 + k * 0.12), Vector3(0.08 + k * 0.04, 0.06, 0.1), blk])
	add_blobs(body, items, blob_gloss())
	tiger_tail.position = Vector3(0, 1.0, -0.78)
	body.add_child(tiger_tail)
	var tail := []
	for k in 6:
		tail.append([Vector3(0, k * 0.1, -k * 0.09), Vector3(0.16, 0.16, 0.2), org if k % 2 == 0 else blk])
	add_blobs(tiger_tail, tail, blob_gloss())
	# 엄마 옷으로 변장 (머릿수건과 치마)
	tiger_disguise = Node3D.new()
	tiger_disguise.visible = false
	body.add_child(tiger_disguise)
	add_blobs(tiger_disguise, [
		[Vector3(0, 1.66, 0.8), Vector3(0.9, 0.34, 0.82), Color(0.97, 0.95, 0.88)],
		[Vector3(0, 1.58, 0.42), Vector3(0.3, 0.3, 0.3), Color(0.97, 0.95, 0.88)],
		[Vector3(0, 0.82, -0.08), Vector3(0.98, 0.86, 1.25), Color(0.45, 0.55, 0.45)],
		[Vector3(0, 1.0, 0.45), Vector3(0.82, 0.5, 0.5), Color(0.97, 0.93, 0.82)],
	])

func tiger_show(at: Vector3, face: Vector3) -> void:
	tiger.position = on_ground(at.x, at.z)
	tiger.rotation.y = atan2(face.x - at.x, face.z - at.z)
	tiger.visible = true
	tiger_goal = Vector3.ZERO
	pop3d(tiger, true)
	burst3d(tiger.position + Vector3(0, 1.0, 0), Color(0.95, 0.6, 0.25), 18)
	sfx("crack", 0.6)
	shake(12)

# 호랑이가 숲으로 어슬렁어슬렁 사라져요
func tiger_leave() -> void:
	var side := Vector3(tiger.basis.x.x, 0, tiger.basis.x.z) * 9.0
	tiger_goal = tiger.position + side
	tiger_speed = 4.0
	tiger.set_meta("hide_at_goal", true)

func body_of(n: Node3D) -> Node3D:
	for ch in n.get_children():
		if ch is Node3D and (ch as Node3D).has_meta("blink_at"):
			return ch
	return null

func npc(id: String) -> Node3D:
	return npcs[id]

# ---------- 이야기 진행에 맞춰 사람과 물건 놓기 ----------

func apply_story_state() -> void:
	# 고갯길 한가운데서 껐다 켜면, 엄마와 다시 마을 어귀에서 출발해요
	if quest >= S_LEAVE and quest <= S_RUN:
		quest = S_LEAVE
		basket = BASKET_FULL
		reset_fireflies()
		player.position = on_ground(-4.5, 13.5, 0.3)
	var mom := npc("mom")
	mom.visible = quest <= S_RUN
	mom_follow = quest >= S_LEAVE and quest <= S_PASS3
	if mom_follow:
		mom.position = player.position + Vector3(1.6, 0, 1.6)
		mom.position.y = height_at(mom.position.x, mom.position.z)
	for k in ["oppa", "nui"]:
		var kid := npc(k)
		kid.visible = quest <= S_ROPE
		if quest >= S_TREE:
			kid.position = tree_pos + (Vector3(-0.9, 0, 0.9) if k == "oppa" else Vector3(-1.5, 0, 0.3))
			kid.position.y = height_at(kid.position.x, kid.position.z)
		if quest >= S_ROPE:
			kid.position.y += 3.4 if k == "oppa" else 3.0
		if quest >= S_END:
			kid.visible = false
	if quest == S_DOOR:
		tiger_show_disguised()
	if quest == S_ROPE:
		tiger.visible = true
		tiger.position = on_ground(well_pos.x - 1.4, well_pos.z + 0.6)
		tiger.rotation.y = atan2(tree_pos.x - tiger.position.x, tree_pos.z - tiger.position.z)
		make_sky_rope()
	if quest >= S_END:
		paint_sorghum_red()
	update_quest_text()

func story_time(z: float) -> float:
	if quest >= S_END:
		return 0.0
	if quest >= S_WARN:
		return 1.0
	var t := 0.0
	if z < 14.0:
		t = remap(z, 14.0, -26.0, 0.0, 0.68)
	if z < -26.0:
		t = remap(z, -26.0, -55.0, 0.68, 1.0)
	if quest < S_LEAVE:
		t = minf(t, 0.12)
	return clampf(t, 0.0, 1.0)

func update_quest_text() -> void:
	var t := ""
	match quest:
		S_ARRIVE:
			t = "잔칫집 마당에서 일하는 아주머니 찾기"
		S_FEAST:
			var a := "끝" if feast["pound"] else "  "
			var b := "끝" if feast["tteok"] else "  "
			t = "잔치 일 돕기: 떡메치기 [%s] · 떡 받기 [%s] · 떡 돌리기 %d/3" % [a, b, delivered.size()]
			if feast["pound"] and feast["tteok"] and delivered.size() >= 3:
				t = "엄마에게 돌아가기"
		S_LEAVE:
			t = "엄마와 함께 북쪽 첫째 고개 넘기"
		S_PASS2:
			t = "엄마와 함께 둘째 고개 넘기"
		S_PASS3:
			t = "엄마와 함께 셋째 고개 넘기"
		S_RUN:
			t = "호랑이보다 먼저 오두막에 닿기! 길 따라 달려요"
		S_WARN:
			t = "오두막의 오누이에게 알리기"
		S_DOOR:
			t = "문밖에 누가 왔어요... 오빠에게 말 걸기"
		S_TREE:
			t = "우물가 큰 나무에 오누이가 오르도록 돕기"
		S_ROPE:
			t = "나무 아래에서 하늘에 빌기"
		S_END:
			t = "2장 끝! 마을과 고갯길을 둘러보세요"
	var extra := ""
	if quest >= S_LEAVE and quest <= S_PASS3:
		extra = " | 떡 광주리 %d개 | 반딧불 %d/%d" % [basket, fireflies_got, FIREFLY_N]
	if sneak_on:
		t = "호랑이가 돌아보면 꼼짝 마! 살금살금 호랑이 뒤로 지나가기"
	var st := 0
	for b2 in stones:
		if b2:
			st += 1
	quest_label.text = "할 일: %s\n엽전 %d냥 | 서낭당 돌 %d/3%s" % [t, shown_coins, st, extra]

# ---------- 매 순간 ----------

func update_story(delta: float) -> void:
	update_mom(delta)
	update_tiger(delta)
	update_rocks(delta)
	update_fireflies(delta)
	update_stream(delta)
	if sneak_on and not is_busy():
		update_sneak(delta)
	if is_busy() or event_lock:
		return
	var z := player.position.z
	if quest == S_LEAVE and z < TRIGGER_Z[0]:
		event_pass(0)
	elif quest == S_PASS2 and z < TRIGGER_Z[1]:
		event_pass(1)
	elif quest == S_PASS3 and z < TRIGGER_Z[2] and not sneak_on:
		event_pass(2)
	elif quest == S_RUN:
		update_run(delta)

func update_mom(delta: float) -> void:
	var mom := npc("mom")
	var body := body_of(mom)
	var speed := 0.0
	if mom_follow and mom.visible and not event_lock:
		var to := player.position - mom.position
		to.y = 0.0
		var d := to.length()
		if d > 14.0:
			mom.position = player.position - to.normalized() * 2.4
		elif d > 2.2:
			speed = clampf((d - 2.2) * 3.0, 0.0, 6.6)
			mom.position += to.normalized() * speed * delta
		if d > 0.4:
			mom.rotation.y = lerp_angle(mom.rotation.y, atan2(to.x, to.z), minf(1.0, delta * 8.0))
		mom.position.y = height_at(mom.position.x, mom.position.z)
	if body != null:
		mom_amt = lerpf(mom_amt, clampf(speed / 2.0, 0.0, 1.0), minf(1.0, delta * 8.0))
		mom_phase += delta * speed / 1.7
		body.set_meta("gait", [fposmod(mom_phase, 1.0), mom_amt, clampf((speed - 3.5) / 3.0, 0.0, 1.0)])

func update_tiger(delta: float) -> void:
	if tiger == null or not tiger.visible:
		return
	var body: Node3D = tiger.get_node("Body")
	tiger_tail.rotation.y = sin(anim_t * 2.4) * 0.5
	tiger_tail.rotation.x = -0.4 + sin(anim_t * 1.7) * 0.2
	var moving := false
	if tiger_goal != Vector3.ZERO:
		var to := tiger_goal - tiger.position
		to.y = 0.0
		if to.length() < 0.3:
			tiger_goal = Vector3.ZERO
			if tiger.get_meta("hide_at_goal", false):
				tiger.set_meta("hide_at_goal", false)
				tiger.visible = false
		else:
			moving = true
			tiger.position += to.normalized() * minf(tiger_speed * delta, to.length())
			tiger.rotation.y = lerp_angle(tiger.rotation.y, atan2(to.x, to.z), minf(1.0, delta * 6.0))
	tiger.position.y = height_at(tiger.position.x, tiger.position.z)
	var chasing := run_active and run_wait <= 0.0
	pose_tiger(delta, 4.5 if moving else (5.0 if chasing else 0.0))
	if chasing:
		return
	if not tiger_models.is_empty():
		body.rotation.x = 0.0
		body.position.y = 0.0
		return
	if moving:
		body.position.y = absf(sin(anim_t * 9.0)) * 0.12
		body.rotation.x = sin(anim_t * 9.0) * 0.05
	else:
		body.position.y = sin(anim_t * 2.0) * 0.03
		body.rotation.x = 0.0

# 뼈대 있는 호랑이는 사람처럼 걸어요
var tiger_phase := 0.0
var tiger_amt := 0.0

func pose_tiger(delta: float, speed: float) -> void:
	tiger_amt = lerpf(tiger_amt, clampf(speed / 2.0, 0.0, 1.0), minf(1.0, delta * 8.0))
	tiger_phase += delta * speed / 2.0
	for mdl in tiger_models:
		if (mdl as Node3D).is_visible_in_tree():
			mdl.set_meta("gait", [fposmod(tiger_phase, 1.0), tiger_amt, clampf((speed - 3.5) / 3.0, 0.0, 1.0)])
			pose_person(mdl, 0.0, 0.0)

# ---------- 고갯길: 위에서 굴러 내려오는 돌 (옆으로 피하거나 점프!) ----------
var rolling: Array = []      # [노드, 길 점들, 지금 칸, 옆으로 비킨 정도]
var rock_t := 2.0
var rock_hits := 0

func nearest_road_i(p: Vector3) -> int:
	var best := 0
	var bd := 1e9
	for k in road_pts.size():
		var d := road_pts[k].distance_squared_to(Vector2(p.x, p.z))
		if d < bd:
			bd = d
			best = k
	return best

func update_rocks(delta: float) -> void:
	var on := mom_follow and quest >= S_LEAVE and quest <= S_PASS3 and not event_lock and not is_busy() and player.position.z < 16.0 and absf(player.position.z - STREAM_Z) > 7.0
	if on:
		rock_t -= delta
		if rock_t <= 0.0:
			rock_t = rng.randf_range(1.6, 2.8)
			var i0 := nearest_road_i(player.position)
			if i0 + 10 < road_pts.size():
				var n := blob_node([[Vector3.ZERO, Vector3(0.9, 0.8, 0.9), Color(0.55, 0.52, 0.48)], [Vector3(0.15, 0.15, 0.1), Vector3(0.5, 0.4, 0.5), Color(0.62, 0.6, 0.56)]], stone_blob_mat)
				mg_nodes.erase(n)
				var side := rng.randf_range(-1.3, 1.3)
				rolling.append([n, i0 + 10, maxi(0, i0 - 8), side, 0.0])
				var sp := road_pts[i0 + 10]
				n.global_position = on_ground(sp.x, sp.y, 0.45)
				pop3d(n, true)
				sfx("crack", 0.55)
	for r in rolling.duplicate():
		var n: Node3D = r[0]
		if not is_instance_valid(n):
			rolling.erase(r)
			continue
		var idx: int = r[1]
		var stop_i: int = r[2]
		r[4] = float(r[4]) + delta
		if idx <= stop_i or float(r[4]) > 8.0 or not on:
			var tw := n.create_tween()
			tw.tween_property(n, "scale", Vector3.ONE * 0.01, 0.25)
			tw.tween_callback(n.queue_free)
			rolling.erase(r)
			continue
		var tgt := road_pts[idx - 1]
		var cur := Vector2(n.global_position.x, n.global_position.z)
		var dirv := road_pts[idx - 1] - road_pts[idx]
		var perp := Vector2(-dirv.y, dirv.x).normalized() * float(r[3])
		tgt += perp
		var step := 6.5 * delta
		var to := tgt - cur
		if to.length() <= step:
			r[1] = idx - 1
		var nv := cur + to.normalized() * minf(step, to.length())
		n.global_position = on_ground(nv.x, nv.y, 0.45)
		if to.length() > 0.01:
			n.rotate(Vector3(to.y, 0, -to.x).normalized(), -step / 0.45)
		# 부딪히면 아야!
		var pd := Vector2(player.position.x - nv.x, player.position.z - nv.y).length()
		var low := player.position.y - height_at(player.position.x, player.position.z) < 0.7
		if pd < 1.0 and low:
			rock_hits += 1
			var back := Vector3(player.position.x - nv.x, 0, player.position.z - nv.y).normalized()
			player.velocity = back * 6.0 + Vector3(0, 4.0, 0)
			sfx("crack", 0.8)
			shake(12)
			hit_stop(0.05)
			burst3d(player.position + Vector3(0, 1.0, 0), Color(0.75, 0.7, 0.6), 12)
			float_text("아야!", cam.unproject_position(player.position + Vector3(0, 2.2, 0)), Color(1, 0.6, 0.5), 1.2)
			if rock_hits % 2 == 1:
				float_text("엄마: 얘야, 조심하렴! 돌이 굴러온다!", get_viewport().get_visible_rect().size * Vector2(0.5, 0.3), Color(1, 0.95, 0.85), 1.0)
			r[2] = idx

# ---------- 떡 쌓기 (잔칫집 곁가지) ----------
const STACK_POS := Vector3(-7.6, 0, 35.2)
var stack_best := 0

func make_stack_table() -> void:
	var t := make_spot(STACK_POS, "stack", "", "떡 쌓기", true)
	add_mbox(t, plank_mat, Vector3(1.4, 0.1, 0.9), Vector3(0, 0.7, 0))
	for lx in [-0.55, 0.55]:
		for lz in [-0.35, 0.35]:
			add_mbox(t, dark_wood_mat, Vector3(0.08, 0.7, 0.08), Vector3(lx, 0.35, lz))
	add_mcyl(t, make_color(Color(0.85, 0.82, 0.75)), 0.45, 0.4, 0.04, Vector3(0, 0.77, 0))
	add_solid(STACK_POS + Vector3(0, 0.5, 0), Vector3(1.4, 1.0, 0.9), Color(0, 0, 0, 0))

func start_stack() -> void:
	start_game("stack", {"world": true, "scene": "stack", "art": "world", "title": "떡 쌓기! 움직이는 떡판을 톡 눌러 쌓아요\n딱 맞으면 퍼펙트, 어긋나면 잘려요", "goal": 12, "base_w": 0.5, "speed": 0.5, "lives": 3, "unit": "층"}, stack_done)

func stack_done(ok: bool, _good: bool) -> void:
	var h := mg_count
	var first := h > stack_best
	stack_best = maxi(stack_best, h)
	earn(h)
	var l := [["떡집 할머니", "%d층이나 쌓았구나!%s" % [h, " 잔칫상에 올려야겠다!" if ok else " 다음엔 더 높이 쌓아 보렴."]]]
	if first and ok:
		l.append(["", "가장 높이 쌓은 기록: %d층" % stack_best])
	say(l, Callable())

# ---------- 반딧불 모으기 (첫째→둘째 고개, 해 질 녘) ----------
const FIREFLY_N := 16
var fireflies: Array = []      # [노드, 처음 자리, 위상, (잡으면 true)]
var fireflies_got := 0
var lantern: Node3D
var lantern_light: OmniLight3D

func make_fireflies() -> void:
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(0.95, 1.0, 0.6)
	glow.emission_enabled = true
	glow.emission = Color(0.85, 1.0, 0.4)
	glow.emission_energy_multiplier = 3.0
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var sm := SphereMesh.new()
	sm.radius = 0.09
	sm.height = 0.18
	sm.radial_segments = 8
	sm.rings = 4
	var r := RandomNumberGenerator.new()
	r.seed = 55
	var cands := []
	for k in road_pts.size():
		var p := road_pts[k]
		if p.y < 0.0 and p.y > -19.0:
			cands.append(p)
	for i in FIREFLY_N:
		var p: Vector2 = cands[int(float(i) / FIREFLY_N * cands.size())]
		var off := Vector2(r.randf_range(-5, 5), r.randf_range(-1.5, 1.5))
		var base := on_ground(p.x + off.x, p.y + off.y, r.randf_range(0.8, 1.8))
		var n := MeshInstance3D.new()
		n.mesh = sm
		n.material_override = glow
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.position = base
		n.visible = false
		add_child(n)
		fireflies.append([n, base, r.randf() * TAU])

func make_lantern() -> void:
	# 엄마가 든 청사초롱: 반딧불을 모을수록 환해져요
	lantern = Node3D.new()
	var mom := npc("mom")
	mom.add_child(lantern)
	lantern.position = Vector3(0.55, 1.25, 0.35)
	var paper := StandardMaterial3D.new()
	paper.albedo_color = Color(1.0, 0.85, 0.55)
	paper.emission_enabled = true
	paper.emission = Color(1.0, 0.75, 0.4)
	paper.emission_energy_multiplier = 0.6
	add_mcyl(lantern, paper, 0.16, 0.16, 0.34, Vector3.ZERO)
	add_mcyl(lantern, make_color(Color(0.25, 0.3, 0.6)), 0.17, 0.17, 0.08, Vector3(0, 0.2, 0))
	add_mcyl(lantern, make_color(Color(0.8, 0.25, 0.25)), 0.17, 0.17, 0.08, Vector3(0, -0.2, 0))
	add_mcyl(lantern, dark_wood_mat, 0.015, 0.015, 0.5, Vector3(0, 0.45, 0))
	lantern_light = OmniLight3D.new()
	lantern_light.light_color = Color(1.0, 0.8, 0.5)
	lantern_light.omni_range = 5.0
	lantern_light.light_energy = 0.4
	lantern.add_child(lantern_light)
	lantern.visible = false

func update_fireflies(delta: float) -> void:
	var on := quest >= S_LEAVE and quest <= S_PASS3
	if lantern != null:
		lantern.visible = on and npc("mom").visible
		var target := 0.35 + 0.12 * fireflies_got
		lantern_light.light_energy = lerpf(lantern_light.light_energy, target if on else 0.0, minf(1.0, delta * 3.0))
		lantern_light.omni_range = 4.0 + fireflies_got * 0.35
	for f in fireflies:
		var n: MeshInstance3D = f[0]
		if f.size() > 3:
			continue
		n.visible = on
		if not on:
			continue
		var base: Vector3 = f[1]
		var ph: float = f[2]
		n.position = base + Vector3(sin(anim_t * 0.8 + ph) * 0.8, sin(anim_t * 1.3 + ph * 2.0) * 0.35, cos(anim_t * 0.7 + ph) * 0.8)
		n.scale = Vector3.ONE * (0.8 + 0.4 * absf(sin(anim_t * 3.0 + ph)))
		if n.position.distance_to(player.position + Vector3(0, 1.0, 0)) < 1.6:
			f.append(true)
			fireflies_got += 1
			sfx("tick", 1.4 + fireflies_got * 0.03)
			burst3d(n.position, Color(0.9, 1.0, 0.5), 8)
			var tw := n.create_tween()
			tw.tween_property(n, "global_position", npc("mom").global_position + Vector3(0.55, 1.25, 0.35), 0.4).set_ease(Tween.EASE_IN)
			tw.tween_callback(func(): n.visible = false)
			float_text("반딧불 %d/%d" % [fireflies_got, FIREFLY_N], cam.unproject_position(n.position), Color(0.9, 1.0, 0.6), 0.9)
			if fireflies_got == FIREFLY_N:
				earn(15)
				float_text("엄마: 초롱이 대낮처럼 환하구나! 고맙다.", get_viewport().get_visible_rect().size * Vector2(0.5, 0.32), Color(1, 0.95, 0.75), 2.0)
			update_quest_text()

func reset_fireflies() -> void:
	fireflies_got = 0
	for f in fireflies:
		while f.size() > 3:
			f.pop_back()

# ---------- 징검다리 (둘째→셋째 고개 사이 개울) ----------
var stones_move: Array = []   # [몸, 위 높이, 아래 높이, 위상]
var stream_side := 1
var stream_cool := 0.0

func water_y(x: float) -> float:
	return minf(height_at(x, STREAM_Z + STREAM_HALF + 1.2), height_at(x, STREAM_Z - STREAM_HALF - 1.2)) - 0.55

func make_stream() -> void:
	# 물줄기: 개울을 따라 휘는 띠
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var x := -36.0
	while x < 36.0:
		var x2 := x + 2.0
		var q := [Vector3(x, water_y(x), STREAM_Z - STREAM_HALF - 0.4), Vector3(x2, water_y(x2), STREAM_Z - STREAM_HALF - 0.4), Vector3(x2, water_y(x2), STREAM_Z + STREAM_HALF + 0.4), Vector3(x, water_y(x), STREAM_Z + STREAM_HALF + 0.4)]
		for idx in [0, 2, 1, 0, 3, 2]:
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(q[idx].x / 6.0, q[idx].z / 6.0))
			st.add_vertex(q[idx])
		x = x2
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = water_material(2, Vector4(0, STREAM_Z, 36.0, STREAM_HALF + 0.4), Color(0.12, 0.35, 0.45), Color(0.35, 0.65, 0.7), Vector2(0.06, 0.0), 0.85)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	# 떴다 가라앉았다 하는 징검돌 다섯 개 (길을 따라)
	var a := Vector2(9.2, STREAM_Z + STREAM_HALF + 0.3)
	var b := Vector2(0.8, STREAM_Z - STREAM_HALF - 0.3)
	for k in 5:
		var t := (k + 0.5) / 5.0
		var p := a.lerp(b, t)
		var wy := water_y(p.x)
		var body := AnimatableBody3D.new()
		body.sync_to_physics = true
		body.position = Vector3(p.x, wy + 0.25, p.y)
		add_child(body)
		var col := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.62
		cyl.height = 0.5
		col.shape = cyl
		body.add_child(col)
		add_blobs(body, [[Vector3(0, 0, 0), Vector3(1.35, 0.5, 1.2), Color(0.55, 0.53, 0.5)], [Vector3(0.1, 0.18, 0.05), Vector3(0.9, 0.2, 0.8), Color(0.62, 0.6, 0.56)]], stone_blob_mat)
		stones_move.append([body, wy + 0.3, wy - 0.55, k * 1.3])

func update_stream(delta: float) -> void:
	for sm in stones_move:
		var body: AnimatableBody3D = sm[0]
		# 떠 있음 2.2초 → 가라앉음 → 잠김 0.6초 → 떠오름
		var cyc := fposmod(anim_t + float(sm[3]), 3.8)
		var up := 1.0
		if cyc > 2.2 and cyc < 2.8:
			up = 1.0 - (cyc - 2.2) / 0.6
		elif cyc >= 2.8 and cyc < 3.4:
			up = 0.0
		elif cyc >= 3.4:
			up = (cyc - 3.4) / 0.4
		var wob := sin(anim_t * 9.0) * 0.03 if (cyc > 1.8 and cyc < 2.2) else 0.0
		body.position.y = lerpf(float(sm[2]), float(sm[1]), up) + wob
	stream_cool = maxf(0.0, stream_cool - delta)
	var pz := player.position.z
	if pz > STREAM_Z + STREAM_HALF + 0.6:
		stream_side = 1
	elif pz < STREAM_Z - STREAM_HALF - 0.6:
		stream_side = -1
	if absf(pz - STREAM_Z) < STREAM_HALF + 0.2 and player.position.y < water_y(player.position.x) - 0.05 and stream_cool <= 0.0:
		stream_cool = 1.0
		sfx("splash")
		burst3d(player.position + Vector3(0, 0.5, 0), Color(0.75, 0.9, 1.0), 20)
		float_text("풍덩! 돌이 떠 있을 때 건너요", get_viewport().get_visible_rect().size * Vector2(0.5, 0.35), Color(0.8, 0.95, 1.0), 1.6)
		var back := Vector2(9.6, STREAM_Z + STREAM_HALF + 1.4) if stream_side > 0 else Vector2(0.4, STREAM_Z - STREAM_HALF - 1.4)
		player.position = on_ground(back.x, back.y, 0.3)
		player.velocity = Vector3.ZERO

# ---------- 무궁화 꽃이 피었습니다 (셋째 고개: 호랑이 몰래 지나가기) ----------
var sneak_on := false
var sneak_state := "away"      # away(엄마를 봄) → warn(으르렁) → look(돌아봄)
var sneak_t := 0.0
var sneak_start := Vector3.ZERO
var sneak_banner: Label

func start_sneak() -> void:
	event_lock = false
	mom_follow = false
	sneak_on = true
	sneak_state = "away"
	sneak_t = 2.5
	sneak_start = player.position
	var mom := npc("mom")
	tiger.rotation.y = atan2(mom.position.x - tiger.position.x, mom.position.z - tiger.position.z)
	if sneak_banner == null:
		sneak_banner = Label.new()
		style(sneak_banner, 1.6)
		sneak_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sneak_banner.add_theme_font_size_override("font_size", int(font_size * 1.6))
		sneak_banner.add_theme_constant_override("outline_size", 10)
		sneak_banner.add_theme_color_override("font_outline_color", Color(0.15, 0.1, 0.05))
		sneak_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ui_layer.add_child(sneak_banner)
		place(sneak_banner, 0.0, 0.3, 1.0, 0.38)
	sneak_banner.visible = true
	update_quest_text()

func update_sneak(delta: float) -> void:
	var mom := npc("mom")
	sneak_t -= delta
	var face_mom := atan2(mom.position.x - tiger.position.x, mom.position.z - tiger.position.z)
	var face_me := atan2(player.position.x - tiger.position.x, player.position.z - tiger.position.z)
	match sneak_state:
		"away":
			tiger.rotation.y = lerp_angle(tiger.rotation.y, face_mom, minf(1.0, delta * 8.0))
			sneak_banner.text = "살금살금 지나가요!"
			sneak_banner.add_theme_color_override("font_color", Color(0.7, 1.0, 0.6))
			if sneak_t <= 0.0:
				sneak_state = "warn"
				sneak_t = 0.6
				sfx("crack", 0.5)
		"warn":
			sneak_banner.text = "으르렁...?"
			sneak_banner.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
			tiger_tail.rotation.y = sin(anim_t * 20.0) * 0.6
			if sneak_t <= 0.0:
				sneak_state = "look"
				sneak_t = rng.randf_range(1.2, 2.0)
		"look":
			tiger.rotation.y = lerp_angle(tiger.rotation.y, face_me, minf(1.0, delta * 10.0))
			sneak_banner.text = "멈춰! 꼼짝 마!"
			sneak_banner.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4))
			var mv := Vector2(player.velocity.x, player.velocity.z).length()
			if mv > 0.6 and absf(angle_difference(tiger.rotation.y, face_me)) < 0.4:
				sneak_caught()
				return
			if sneak_t <= 0.0:
				sneak_state = "away"
				sneak_t = rng.randf_range(1.6, 3.2)
	# 호랑이 뒤로 다 지나가면 성공
	if player.position.z < tiger.position.z - 5.0:
		sneak_on = false
		sneak_banner.visible = false
		sfx("good")
		float_text("지나갔다! 이제 달려요!", get_viewport().get_visible_rect().size * Vector2(0.5, 0.4), Color(1, 0.9, 0.4), 1.6)
		start_run()

func sneak_caught() -> void:
	sfx("bad")
	shake(16)
	flash(Color(1, 0.6, 0.5))
	float_text("어흥! 들켰다!", get_viewport().get_visible_rect().size * Vector2(0.5, 0.4), Color(1, 0.55, 0.45), 1.5)
	player.position = sneak_start
	player.velocity = Vector3.ZERO
	sneak_state = "away"
	sneak_t = 2.2

# ---------- 솔방울 던지기 (나무 위로 올라오는 호랑이) ----------
func start_pine() -> void:
	start_game("aim", {"world": true, "scene": "pine", "art": "world", "title": "호랑이가 도끼로 콕콕 나무를 올라와요!\n새총을 뒤로 당겼다 놓아 솔방울을 맞혀요", "goal": 6, "climb_speed": 0.05, "knock": 0.16, "target_r": 0.1, "hit_text": "딱! 아야!", "lose_text": "호랑이가 너무 높이 올라왔어요!", "unit": "명중"}, pine_done)

func pine_done(ok: bool, _good: bool) -> void:
	tiger.position = on_ground(tree_pos.x - 0.9, tree_pos.z + 0.9)
	if not ok:
		say([["누이", "으앙, 다시 던져 줘! 호랑이를 막아 줘!"]], start_pine)
		return
	say([
		["호랑이", "아이고 머리야! 솔방울이 우박처럼 쏟아지네!"],
		["오빠", "지금이야! 하느님, 저희를 살리시려거든 튼튼한 동아줄을 내려 주세요!"],
	], func():
		make_sky_rope()
		start_rope())

func aim_target() -> Vector2:
	if w.get("scene", "") == "pine" and tiger != null:
		return cam.unproject_position(tiger.global_position + Vector3(0, 1.6, 0))
	return super()

# ---------- 말 걸기 ----------

func talk_to(id: String) -> void:
	match id:
		"mom":
			talk_mom()
		"host":
			talk_host()
		"cook":
			talk_cook()
		"guest1", "guest2", "guest3":
			talk_guest(id)
		"oppa", "nui":
			talk_kids(id)

func talk_mom() -> void:
	if quest == S_ARRIVE:
		say([
			["엄마", "어머, 처음 보는 옷차림이로구나. 어디서 왔니?"],
			["엄마", "책 속으로 들어왔다고? 호호, 신기한 일도 다 있네."],
			["엄마", "나는 고개 너머 오두막에 사는 아이 엄마란다. 오늘은 이 잔칫집에서 일을 거들고 있지."],
			["엄마", "일을 다 마치면 떡을 얻어 우리 오누이에게 가져다줄 생각이란다."],
			["엄마", "그런데 일손이 모자라서 큰일이구나... 혹시 좀 도와주겠니?"],
			["엄마", "잔칫집 영감님께 여쭈면 할 일을 알려 주실 게다."],
		], func(): set_quest(S_FEAST))
	elif quest == S_FEAST:
		if feast["pound"] and feast["tteok"] and delivered.size() >= 3:
			say([
				["엄마", "세상에, 그 많은 일을 다 했구나! 덕분에 일찍 마쳤단다."],
				["잔칫집 영감", "수고 많았네. 약속한 떡일세. 광주리 가득 담았으니 아이들과 나눠 먹게."],
				["엄마", "고맙습니다, 영감님! 우리 아이들이 얼마나 좋아할까."],
				["엄마", "벌써 해가 기우는구나. 집에 가려면 고개를 셋이나 넘어야 해."],
				["엄마", "같이 가 주겠니? 혼자 넘기엔 고갯길이 좀 무섭단다."],
			], start_journey)
		else:
			say([["엄마", "영감님이 시키신 일을 하나씩 해 보렴. 떡메치기, 떡 받기, 손님들께 떡 돌리기란다."]], Callable())
	elif quest >= S_LEAVE and quest <= S_PASS3:
		say([["엄마", "조금만 더 가면 돼. 우리 오누이가 문 앞에서 기다리고 있을 게다."]], Callable())

func start_journey() -> void:
	basket = BASKET_FULL
	mom_follow = true
	earn(15)
	set_quest(S_LEAVE)

func talk_host() -> void:
	if quest == S_FEAST or quest == S_ARRIVE:
		if quest == S_ARRIVE:
			say([["잔칫집 영감", "허허, 오늘은 우리 손녀 돌잔치라네. 저기 떡을 나르는 아주머니께 먼저 인사하게나."]], Callable())
			return
		say([
			["잔칫집 영감", "자네가 일손을 보태 준다고? 고맙네!"],
			["잔칫집 영감", "첫째, 마당 안반에서 떡메를 쳐 주게. 쫄깃해야 하네."],
			["잔칫집 영감", "둘째, 아궁이 옆 떡집 할머니가 떡을 쪄 내면 채반으로 받아 주고."],
			["잔칫집 영감", "셋째, 그 떡을 손님 세 분께 돌려 주게. 김 서방, 새댁, 윤 영감일세."],
		], Callable())
	elif quest == S_END:
		say([["잔칫집 영감", "오누이가 해와 달이 되었다지? 이제 밤길도 무섭지 않겠구먼."]], Callable())
	else:
		say([["잔칫집 영감", "해 지기 전에 고개를 넘어야 할 텐데... 조심해서 가게나."]], Callable())

func talk_cook() -> void:
	if quest == S_FEAST and not feast["tteok"]:
		say([
			["떡집 할머니", "시루떡이 다 쪄졌다! 뜨거우니 채반으로 받아라."],
			["떡집 할머니", "아궁이 불똥이 튀니 그건 피하고!"],
		], start_tteok)
	elif quest == S_FEAST:
		say([["떡집 할머니", "떡은 식기 전에 손님들께 돌려야 맛있단다."]], Callable())
	else:
		say([["떡집 할머니", "쑥떡, 꿀떡, 백설기... 오늘 떡은 내 평생 제일 잘 쪄졌구나."]], Callable())

func talk_guest(id: String) -> void:
	var nm: String = GUEST_NAME[id]
	if quest == S_FEAST and feast["tteok"] and not delivered.has(id):
		delivered.append(id)
		sfx("good")
		earn(5)
		var lines := {
			"guest1": [[nm, "오, 꿀떡이구먼! 잔칫집 떡은 역시 달아."]],
			"guest2": [[nm, "어머, 고마워라. 우리 아기도 백설기 한 입 줘야겠네."]],
			"guest3": [[nm, "허허, 쑥떡이라. 고갯길 넘어가는 사람은 떡을 넉넉히 챙겨야 한다네. 호랑이가 떡을 좋아하거든."]],
		}
		var l: Array = lines[id]
		l.append(["", "떡을 드렸다. (%d/3)" % delivered.size()])
		say(l, func(): update_quest_text(); save_progress())
	elif quest == S_FEAST and not feast["tteok"]:
		say([[nm, "떡은 아직인가? 떡집 할머니 시루에서 김이 펄펄 나던데."]], Callable())
	elif quest == S_END:
		say([[nm, "어젯밤 하늘에 해님 달님이 새로 떴다는 얘기 들었나?"]], Callable())
	else:
		say([[nm, "잔치는 역시 떡 먹는 맛이지!"]], Callable())

func talk_kids(id: String) -> void:
	if quest == S_WARN:
		say([
			["오빠", "누구세요? 엄마는요?"],
			["누이", "엄마는 잔칫집에서 떡 얻어 오신다고 했는데..."],
			["", "(엄마가 문을 꼭 걸어 잠그라고 하셨다고 전했다.)"],
			["오빠", "알았어. 누이야, 문고리 단단히 걸자. 엄마 목소리가 아니면 절대 열어 주면 안 돼."],
			["누이", "응... 엄마 빨리 오셨으면 좋겠다."],
		], after_warn)
	elif quest == S_DOOR:
		door_scene()
	elif quest == S_TREE:
		say([["오빠", "저 나무 위로 올라가자! 가지를 잡게 도와줘."]], Callable())
	elif quest < S_WARN:
		if id == "oppa":
			say([["오빠", "엄마가 떡 가져오신다고 했어. 누이랑 기다리는 중이야."]], Callable())
		else:
			say([["누이", "해가 지면 무서워... 엄마 언제 오실까?"]], Callable())

# ---------- 잔치 일: 떡메치기, 떡 받기 ----------

func start_pound() -> void:
	start_game("rhythm", {"world": true, "scene": "pound", "art": "world", "title": "쿵덕쿵덕 떡메치기! 박자에 맞춰 톡!\n영감님이 떡을 뒤집을 땐(빨간 X) 멈춰요", "goal": 14, "bpm": 100, "bad_ratio": 0.2, "note": "쿵", "bad_text": "앗, 영감님 손!", "unit": "떡메"}, pound_done)

func pound_done(ok: bool, good: bool) -> void:
	if not ok:
		say([["잔칫집 영감", "떡이 식으면 안 쳐진다네. 다시 해 보게!"]], Callable())
		return
	feast["pound"] = true
	earn(10)
	var l := [["잔칫집 영감", "쫄깃쫄깃하구먼! 떡메 솜씨가 일품일세."]]
	if good:
		l.append(["잔칫집 영감", "한 번도 안 놓쳤어. 떡장수 해도 되겠네!"])
	say(l, func(): update_quest_text(); save_progress())

func start_tteok() -> void:
	start_game("catch", {"world": true, "scene": "tteok", "art": "world", "title": "떡집 할머니가 던지는 떡은 채반으로 받고\n튀는 불똥은 피하세요", "goal": 12, "interval": 0.62, "speed": 0.42, "bad_ratio": 0.3, "good": "떡", "bad": "불똥", "basket": "채반"}, tteok_done)

func tteok_done(ok: bool, _good: bool) -> void:
	if not ok:
		say([["떡집 할머니", "아이고 뜨거워라! 불똥 조심하고 다시 받아 보자."]], Callable())
		return
	feast["tteok"] = true
	earn(10)
	say([["떡집 할머니", "잘 받았다! 이 떡 접시 셋을 손님들께 돌려 다오."], ["", "떡 접시 3개를 받았다."]], func(): update_quest_text(); save_progress())

# ---------- 고갯길: 떡 하나 주면 안 잡아먹지 ----------

func event_pass(i: int) -> void:
	event_lock = true
	var mom := npc("mom")
	var spot: Vector3 = TIGER_SPOTS[i]
	tiger_show(spot, player.position)
	# 엄마와 주인공이 호랑이를 바라봐요
	mom.rotation.y = atan2(spot.x - mom.position.x, spot.z - mom.position.z)
	player.rotation.y = atan2(spot.x - player.position.x, spot.z - player.position.z)
	if i == 0:
		say([
			["호랑이", "어흥! 떡 하나 주면 안 잡아먹지~"],
			["엄마", "(엄마가 광주리를 꼭 끌어안았다) 얘야, 엄마 뒤에 있으렴."],
		], func(): ask("엄마", "떡을 하나 주면 보내 줄까...?", ["떡을 하나 던져 준다", "엄마 손을 꼭 잡는다"], pass1_choice))
	elif i == 1:
		say([
			["호랑이", "어흥! 떡 하나 주면 안 잡아먹지~ 아니, 한 개로는 모자라!"],
			["엄마", "아이고, 앞발이 광주리로 쑥쑥 들어오네!"],
			["엄마", "얘야, 떡을 하나씩 던져 주며 앞발을 막아 다오!"],
		], start_paws)
	else:
		basket = 0
		say([
			["호랑이", "어흥! 떡 하나 주면 안 잡아먹지~"],
			["엄마", "이를 어쩌나... 광주리가 텅 비었구나."],
			["엄마", "(엄마가 조용히 무릎을 굽히고 네 손을 꼭 잡았다)"],
			["엄마", "얘야, 잘 들으렴. 너는 발이 빠르지? 먼저 오두막으로 달려가거라."],
			["엄마", "우리 오누이에게, 엄마 목소리가 아니면 절대 문을 열지 말라고 전해 다오."],
		], func(): ask("엄마", "엄마는 호랑이를 달래 놓고 금방 뒤따라가마.", ["엄마도 같이 가요!", "...꼭 오셔야 해요"], pass3_choice))

func pass1_choice(i: int) -> void:
	basket -= 1
	var l := []
	if i == 0:
		l.append(["", "떡을 하나 휙 던졌다. 호랑이가 덥석 받아먹었다."])
	else:
		l.append(["엄마", "(엄마가 떨리는 손으로 떡을 하나 던져 주었다)"])
	l.append(["호랑이", "냠냠, 꿀떡이로구나! 다음 고개에서 또 보자~"])
	say(l, func():
		tiger_leave()
		event_lock = false
		set_quest(S_PASS2))

func start_paws() -> void:
	start_game("swipe", {"world": true, "scene": "paws", "art": "world", "title": "호랑이 앞발이 광주리로 쑥!\n앞발 쪽으로 손가락을 휙 쳐내 막아요", "goal": 10, "tele": 0.85, "window": 0.55, "gap": 0.8, "feint_ratio": 0.22, "hit_text": "떡을 빼앗겼어요!", "unit": "막기"}, paws_done)

func paws_done(ok: bool, _good: bool) -> void:
	if not ok:
		say([["엄마", "앞발이 너무 빨라! 숨 한 번 고르고 다시 막아 보자."]], start_paws)
		return
	basket = 2
	say([
		["호랑이", "꺼억~ 배가 좀 부르다. 셋째 고개에서 마저 먹어야지!"],
		["엄마", "휴... 이제 떡이 두 개밖에 안 남았구나."],
	], func():
		tiger_leave()
		event_lock = false
		set_quest(S_PASS3))

func pass3_choice(i: int) -> void:
	var l := []
	if i == 0:
		l.append(["엄마", "착하기도 하지. 하지만 아이들이 기다린단다. 어서!"])
	else:
		l.append(["엄마", "그래, 약속하마. 어서 가거라!"])
	l.append(["엄마", "(소곤소곤) 엄마가 호랑이 눈을 끄는 사이에 호랑이 뒤로 살금살금 지나가렴."])
	l.append(["엄마", "호랑이가 뒤돌아보면 꼼짝 말고 멈춰 있어야 한다!"])
	say(l, start_sneak)

# 호랑이보다 먼저 오두막에 닿기
func start_run() -> void:
	mom_follow = false
	event_lock = false
	set_quest(S_RUN)
	run_active = true
	run_wait = 2.5
	run_path = PackedVector2Array()
	var start_i := 0
	var best := 1e9
	for k in road_pts.size():
		var d := road_pts[k].distance_to(Vector2(tiger.position.x, tiger.position.z))
		if d < best:
			best = d
			start_i = k
	for k in range(start_i, road_pts.size()):
		run_path.append(road_pts[k])
	run_i = 0
	float_text("달려요!", get_viewport().get_visible_rect().size / 2.0, Color(1, 0.9, 0.4), 1.5)

func update_run(delta: float) -> void:
	if not run_active:
		return
	var mom := npc("mom")
	if mom.visible and player.position.distance_to(mom.position) > 16.0:
		mom.visible = false
	if Vector2(player.position.x - COTTAGE_C.x, player.position.z - COTTAGE_C.z).length() < 9.0:
		run_active = false
		tiger.visible = false
		mom.visible = false
		sfx("good")
		set_quest(S_WARN)
		say([["", "헉헉... 오두막에 먼저 닿았다! 문 앞에 아이 둘이 서 있다."]], Callable())
		return
	if run_wait > 0.0:
		run_wait -= delta
		return
	# 호랑이는 길을 따라 성큼성큼
	var left := 5.0 * delta
	while left > 0.0 and run_i < run_path.size():
		var tgt := run_path[run_i]
		var cur := Vector2(tiger.position.x, tiger.position.z)
		var d := cur.distance_to(tgt)
		if d <= left:
			tiger.position.x = tgt.x
			tiger.position.z = tgt.y
			left -= d
			run_i += 1
		else:
			var nv := cur + (tgt - cur).normalized() * left
			tiger.position.x = nv.x
			tiger.position.z = nv.y
			tiger.rotation.y = lerp_angle(tiger.rotation.y, atan2(tgt.x - cur.x, tgt.y - cur.y), minf(1.0, delta * 8.0))
			left = 0.0
	if tiger_models.is_empty():
		(tiger.get_node("Body") as Node3D).position.y = absf(sin(anim_t * 10.0)) * 0.14
	if tiger.position.distance_to(player.position) < 1.8 or run_i >= run_path.size():
		run_active = false
		sfx("fail")
		shake(16)
		show_card("호랑이가 앞질러 버렸어요!\n\n셋째 고개에서 다시 달려 봐요.", 0.0, 2.0, func():
			var sp: Vector3 = TIGER_SPOTS[2]
			player.position = on_ground(sp.x + 1.0, sp.z + 6.0, 0.3)
			player.velocity = Vector3.ZERO
			tiger.position = on_ground(sp.x, sp.z)
			tiger.visible = true
			start_run())

# ---------- 오두막: 엄마 흉내 내는 호랑이 ----------

func after_warn() -> void:
	set_quest(S_DOOR)
	show_card("깊은 밤이 되었어요.\n\n똑똑, 똑똑...\n누군가 문을 두드려요.", 0.0, 3.0, func():
		tiger_show_disguised()
		say([["???", "얘들아~ 엄마 왔다. 문 열어라~"]], Callable()))

func tiger_show_disguised() -> void:
	var gate := COTTAGE_C + Vector3(0.2, 0, 6.2)
	tiger.position = on_ground(gate.x, gate.z)
	tiger.rotation.y = PI
	tiger.visible = true
	set_disguise(true)
	tiger_goal = Vector3.ZERO

func door_scene() -> void:
	say([
		["???", "얘들아~ 엄마 왔다. 어서 문 열어라~"],
		["누이", "엄마 목소리가 왜 그렇게 쉬었어요?"],
		["???", "잔칫집에서 하루 종일 노래를 불러서 그렇단다~"],
	], func(): ask("오빠", "정말 엄마일까? 어떻게 알아보지?", ["문틈으로 손을 보여 달라고 한다", "얼굴을 보여 달라고 한다"], door_choice))

func door_choice(i: int) -> void:
	var l := []
	if i == 0:
		l.append(["", "문틈으로 손이 쑥 들어왔다. 누런 털이 숭숭, 발톱이 뾰족!"])
		l.append(["???", "이, 일을 많이 해서 손이 거칠어졌단다~"])
	else:
		l.append(["", "문구멍 너머로 커다란 눈이 번쩍! 머릿수건 아래로 줄무늬가 보인다."])
		l.append(["???", "어, 어두워서 그렇게 보이는 거란다~"])
	l.append(["오빠", "(속닥속닥) 엄마가 아니야... 호랑이야!"])
	l.append(["누이", "(속닥속닥) 그럼 엄마는...?"])
	l.append(["오빠", "(누이 손을 꼭 잡으며) 쉿. 뒷문으로 나가자. 우물가 큰 나무로!"])
	say(l, func():
		show_card("호랑이는 엄마의 옷을 입고 있었어요.\n\n엄마는... 끝내 집으로 돌아오지 못했어요.\n\n오누이는 울음을 꾹 참고\n살금살금 뒷문으로 빠져나갔어요.", 0.0, 5.0, after_door))

func after_door() -> void:
	tiger.visible = false
	set_disguise(false)
	for k in ["oppa", "nui"]:
		var kid := npc(k)
		kid.position = tree_pos + (Vector3(-0.9, 0, 0.9) if k == "oppa" else Vector3(-1.5, 0, 0.3))
		kid.position.y = height_at(kid.position.x, kid.position.z)
	set_quest(S_TREE)

func start_climb() -> void:
	start_game("alternate", {"world": true, "scene": "climb", "art": "world", "title": "오누이가 나무에 올라요! 가지 있는 쪽을 눌러요\n나무가 흔들리면 꾹 누르고 버텨요", "goal": 12, "step_time": 1.5, "shake_every": 4.5, "unit": "가지"}, climb_done)

func climb_done(ok: bool, _good: bool) -> void:
	if not ok:
		say([["오빠", "미끄러졌어! 다시 해 보자, 누이야. 꽉 잡아!"]], Callable())
		return
	for k in ["oppa", "nui"]:
		var kid := npc(k)
		kid.position.y = height_at(kid.position.x, kid.position.z) + (3.4 if k == "oppa" else 3.0)
	# 호랑이가 우물가로
	tiger.position = on_ground(well_pos.x - 1.4, well_pos.z + 0.6)
	tiger.rotation.y = atan2(well_pos.x - tiger.position.x, well_pos.z - tiger.position.z)
	tiger.visible = true
	set_disguise(false)
	say([
		["오빠", "너는 저 장독 뒤에 숨어! 어서!"],
		["", "(장독 뒤에 몸을 숨겼다. 호랑이가 우물가로 어슬렁어슬렁 다가온다.)"],
		["호랑이", "어라? 우물 속에 애들이 있네? 얘들아, 거기 어떻게 들어갔니~"],
		["누이", "(킥킥) 바보 호랑이! 우리는 나무 위에 있지롱!"],
		["호랑이", "오호라! 너희는 거기 어떻게 올라갔니?"],
		["오빠", "참기름 바르고 올라왔지!"],
		["", "호랑이가 나무에 참기름을 바르고 오르다... 미끌, 쿵! 엉덩방아를 찧었다."],
		["누이", "바보, 도끼로 콕콕 찍으면서 올라오면 되는데!"],
		["오빠", "쉿! 누이야!"],
		["호랑이", "옳거니! 도끼로 콕, 콕!"],
		["", "(장독 뒤에서 솔방울을 한 움큼 주웠다. 호랑이를 막아야 해!)"],
	], func():
		set_quest(S_ROPE)
		tiger_climb_shake()
		start_pine())

func tiger_climb_shake() -> void:
	tiger.position = on_ground(tree_pos.x - 0.9, tree_pos.z + 0.9)
	tiger.rotation.y = atan2(tree_pos.x - tiger.position.x, tree_pos.z - tiger.position.z)
	shake(10)
	sfx("crack", 0.8)

func make_sky_rope() -> void:
	if sky_rope != null and is_instance_valid(sky_rope):
		return
	sky_rope = Node3D.new()
	sky_rope.position = tree_pos + Vector3(-0.3, 0, 0.3)
	add_child(sky_rope)
	var rope := add_mcyl(sky_rope, make_color(Color(0.86, 0.74, 0.5)), 0.05, 0.05, 30.0, Vector3(0, 18.5, 0))
	rope.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(1.0, 0.95, 0.7)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.9, 0.5)
	glow.emission_energy_multiplier = 1.5
	for k in 12:
		add_mcyl(sky_rope, glow, 0.09, 0.09, 0.1, Vector3(0, 3.6 + k * 2.4, 0))
	sky_rope.position.y = 30.0
	var tw := sky_rope.create_tween()
	tw.tween_property(sky_rope, "position:y", height_at(tree_pos.x, tree_pos.z), 2.0).set_ease(Tween.EASE_OUT)

func start_rope() -> void:
	start_game("mash", {"world": true, "scene": "rope", "art": "world", "title": "동아줄을 영차영차 당겨요! 빠르게 연타\n줄이 기울면 반대쪽을 눌러 균형을 잡아요", "goal": 10, "balance": true, "per": 3, "sway": 0.9, "unit": "당기기"}, rope_done)

func rope_done(ok: bool, _good: bool) -> void:
	if not ok:
		say([["오빠", "놓쳤어! 다시 한 번만 더... 하느님!"]], Callable())
		return
	event_lock = true
	# 오누이가 동아줄을 타고 하늘로
	flash(Color(1, 0.97, 0.85))
	sfx("win")
	for k in ["oppa", "nui"]:
		var kid := npc(k)
		var tw := kid.create_tween()
		tw.tween_property(kid, "position:y", kid.position.y + 26.0, 4.0).set_ease(Tween.EASE_IN)
		tw.tween_callback(func(): kid.visible = false)
	if sky_rope != null:
		var tw2 := sky_rope.create_tween()
		tw2.tween_interval(1.0)
		tw2.tween_property(sky_rope, "position:y", sky_rope.position.y + 30.0, 4.0).set_ease(Tween.EASE_IN)
	get_tree().create_timer(3.0).timeout.connect(func():
		say([
			["호랑이", "어라? 나도! 하느님, 저에게도 동아줄을 내려 주세요!"],
			["", "하늘에서 동아줄이 스르륵 내려왔다. 그런데... 어딘가 낡아 보인다."],
			["호랑이", "히히, 나도 하늘로 간다~"],
		], tiger_fall))

func tiger_fall() -> void:
	tiger.visible = true
	var top := tree_pos + Vector3(-0.3, 5.0, 0.3)
	var field := on_ground(FIELD_C.x, FIELD_C.z)
	var tw := tiger.create_tween()
	tw.tween_property(tiger, "position", top, 1.6).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		sfx("crack", 0.7)
		float_text("뚝!", cam.unproject_position(top), Color(1, 0.8, 0.5), 1.4))
	tw.tween_property(tiger, "position", (top + field) * 0.5 + Vector3(0, 4.0, 0), 0.6)
	tw.tween_property(tiger, "position", field, 0.6).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(tiger, "rotation:z", 3.0, 1.2)
	tw.tween_callback(func():
		shake(26)
		hit_stop(0.1)
		burst3d(field + Vector3(0, 1.0, 0), Color(0.75, 0.25, 0.2), 40)
		paint_sorghum_red()
		tiger.visible = false
		tiger.rotation.z = 0.0
		show_card("썩은 동아줄이 뚝!\n호랑이는 수수밭으로 쿵 떨어졌어요.\n\n그 뒤로 수숫대는\n붉게 물들었대요.", 0.0, 4.0, ask_ending))

func paint_sorghum_red() -> void:
	if sorghum_mm == null:
		return
	var r := RandomNumberGenerator.new()
	r.seed = 9
	for i in sorghum_mm.instance_count:
		sorghum_mm.set_instance_color(i, Color(0.72, 0.22, 0.16).lerp(Color(0.62, 0.3, 0.2), r.randf()))

func ask_ending() -> void:
	ask("누이", "오빠, 하늘나라에 가면 우리는 무엇이 될까?", ["오빠는 해, 누이는 달", "누이는 해, 오빠는 달"], on_ending)

func on_ending(i: int) -> void:
	var l := []
	if i == 0:
		ending = "oppa_sun"
		l.append(["오빠", "내가 해가 되어 낮을 밝힐게. 누이는 달이 되어 밤길을 비춰 주렴."])
		l.append(["누이", "응! 밤에 길 잃은 사람이 없게 환하게 비출게."])
	else:
		ending = "nui_sun"
		l.append(["누이", "오빠, 나는 밤이 무서워... 내가 해 하면 안 될까?"])
		l.append(["오빠", "그래, 누이가 해가 되렴. 오빠가 달이 되어 밤을 지킬게."])
		l.append(["누이", "그런데 다들 나만 쳐다보면 부끄러운데... 그럼 눈부시게 빛나야지!"])
	say(l, func():
		show_card("오누이는 해와 달이 되어\n세상을 환하게 비추었어요.\n\n그날 밤, 달 곁에서\n별 하나가 유난히 반짝였대요.\n엄마가 웃는 것처럼요.", 0.0, 5.0, finish_chapter2))

func finish_chapter2() -> void:
	event_lock = false
	earn(30)
	set_quest(S_END)
	for k in ["oppa", "nui"]:
		npc(k).visible = false
	if sky_rope != null:
		sky_rope.queue_free()
	say([["", "빈 책장에 해님 달님 그림이 새로 생겼다. 2장 이야기가 채워졌다!"]], Callable())

# ---------- 물건 누르기 ----------

func is_active(t: Dictionary) -> bool:
	var kind: String = t["kind"]
	match kind:
		"pound":
			return quest == S_FEAST and not feast["pound"]
		"stack":
			return quest <= S_FEAST or quest == S_END
		"stone":
			return not stones[int(t["id"])]
		"climb":
			return quest == S_TREE
		"pray":
			return quest == S_ROPE and not mg_active
	return super(t)

func action_text(t: Dictionary) -> String:
	match t["kind"]:
		"pound":
			return "떡메 치기"
		"stack":
			return "떡 쌓기"
		"stone":
			return "돌 얹기"
		"climb":
			return "나무 오르기"
		"pray":
			return "하늘에 빌기"
	return super(t)

func on_action() -> void:
	if current_thing.is_empty() or is_busy():
		return
	var t := current_thing
	match t["kind"]:
		"pound":
			sfx("tap")
			start_pound()
		"stack":
			sfx("tap")
			start_stack()
		"stone":
			sfx("tap")
			var i := int(t["id"])
			stones[i] = true
			burst3d((t["node"] as Node3D).position + Vector3(0, 0.8, 0), Color(0.8, 0.78, 0.7), 14)
			earn(5)
			var wish: String = ["엄마와 무사히 집에 닿게 해 주세요.", "고갯길의 호랑이가 배불러서 그냥 가게 해 주세요.", "오누이가 무섭지 않게 해 주세요."][i]
			if quest >= S_END:
				wish = "해님 달님이 늘 우리를 비춰 주기를."
			say([["", "돌무더기에 돌 하나를 살짝 얹고 빌었다. \"%s\"" % wish]], func(): update_quest_text(); save_progress())
		"climb":
			sfx("tap")
			start_climb()
		"pray":
			sfx("tap")
			make_sky_rope()
			start_rope()
		"gate":
			sfx("tap")
			if t["id"] == "ch3":
				ask("", "“이 길을 따라가면 별주부전 이야기”\n3장 바닷가로 넘어갈까요?\n(2장 이야기는 저장돼요.)", ["3장으로 가기", "다음에 갈게요"], func(i: int):
					if i == 0:
						go_to_chapter("ch3"))
			else:
				on_gate()
		_:
			super()

# ---------- 3D 미니게임 장면 ----------

func is_tap_scene(scene: String) -> bool:
	return scene in ["pound", "paws", "climb", "rope"] or super(scene)

func is_catch_scene(scene: String) -> bool:
	return scene == "tteok" or super(scene)

func scene_setup(scene: String) -> void:
	w["scene"] = scene
	w["seen"] = {}
	w["count0"] = mg_count
	w["lives0"] = mg_lives
	match scene:
		"stack":
			var sp := STACK_POS
			world_game_begin(sp + Vector3(-1.3, 0, 0.7), sp, sp + Vector3(0.5, 2.0, 3.1), sp + Vector3(0, 1.15, 0))
			w["stack_base"] = sp + Vector3(0, 0.79, 0)
			w["stack_span"] = 1.3
		"pine":
			var tp3 := tree_pos
			var st3 := tp3 + Vector3(2.4, 0, 3.2)
			st3.y = height_at(st3.x, st3.z)
			world_game_begin(st3, tp3, tp3 + Vector3(4.2, 2.0, 8.4), tp3 + Vector3(0, 2.6, 0))
			w["tiger_base"] = tiger.position
			w["aim3d"] = func() -> Vector3: return tiger.global_position + Vector3(0, 1.6, 0)
		"pound":
			var a := ANBAN_POS
			var stand := a + Vector3(0, 0, 1.15)
			world_game_begin(stand, a, a + Vector3(2.8, 2.6, 3.0), a + Vector3(-0.2, 0.7, 0))
			hold_tool("mallet")
		"tteok":
			var cp := npc("cook").position
			for lb in npc("cook").find_children("*", "Label3D", true, false):
				world_hide(lb)
			var stand := cp + Vector3(0, 0, 2.6)
			world_game_begin(stand, cp, cp + Vector3(0.0, 2.3, 7.4), cp + Vector3(0, 2.9, 1.4))
			var tray := blob_node([[Vector3.ZERO, Vector3(0.75, 0.12, 0.75), Color(0.8, 0.66, 0.4)], [Vector3(0, 0.05, 0), Vector3(0.62, 0.05, 0.62), Color(0.88, 0.76, 0.5)]], thatch_blob_mat)
			w["bowl"] = tray
			w["items"] = {}
			w["center"] = stand
			w["ground_y"] = cp.y
			w["depth"] = cam_depth_of(stand + Vector3(0, 2.4, 0), cp + Vector3(0.0, 2.3, 7.4))
		"paws":
			var mom := npc("mom")
			var f := fwd_of(mom.position, tiger.position)
			var side := f.cross(Vector3.UP).normalized()
			var basket_at := mom.position + f * 0.8 + Vector3(0, 0.55, 0)
			var stand := mom.position + side * 1.3
			world_game_begin(stand, tiger.position, mom.position - f * 5.2 + side * 2.6 + Vector3(0, 3.6, 0), mom.position + f * 2.2 + Vector3(0, 0.4, 0))
			var bk := blob_node([[Vector3.ZERO, Vector3(0.9, 0.42, 0.9), Color(0.82, 0.68, 0.42)], [Vector3(0, 0.18, 0), Vector3(0.74, 0.12, 0.74), Color(0.98, 0.96, 0.9)]], thatch_blob_mat)
			bk.position = basket_at
			w["basket"] = basket_at
			w["fwd"] = f
			w["side"] = side
		"climb":
			var tp := tree_pos
			var stand := tp + Vector3(0.9, 0, 2.4)
			stand.y = height_at(stand.x, stand.z)
			world_game_begin(stand, tp, tp + Vector3(2.6, 2.4, 6.8), tp + Vector3(-0.4, 2.0, 0))
			w["kid_base"] = {}
			for k in ["oppa", "nui"]:
				(w["kid_base"] as Dictionary)[k] = npc(k).position
		"rope":
			var tp2 := tree_pos
			var stand2 := tp2 + Vector3(0.9, 0, 2.4)
			stand2.y = height_at(stand2.x, stand2.z)
			world_game_begin(stand2, tp2, tp2 + Vector3(2.4, 1.4, 7.4), tp2 + Vector3(-0.3, 5.0, 0))

func scene_spawn_target() -> Vector3:
	match w["scene"]:
		"pound":
			return ANBAN_POS + Vector3(rng.randf_range(-0.45, 0.45), 0.66, rng.randf_range(-0.2, 0.2))
		"paws":
			var f: Vector3 = w["fwd"]
			var side: Vector3 = w["side"]
			var b: Vector3 = w["basket"]
			var p := b + f * rng.randf_range(1.6, 2.6) + side * rng.randf_range(-2.0, 2.0)
			p.y = height_at(p.x, p.z) + 0.3
			return p
		"climb":
			var ang := rng.randf_range(-0.9, 0.9) + atan2(-1.0, 1.0)
			var y := 0.8 + rng.randf() * 2.6
			return tree_pos + Vector3(sin(ang) * 0.42, y, cos(ang) * 0.42)
		"rope":
			return tree_pos + Vector3(-0.3, rng.randf_range(4.6, 7.8), 0.3)
	return super()

func scene_make_target(at: Vector3) -> Node3D:
	match w["scene"]:
		"pound", "paws", "climb", "rope":
			var n := Node3D.new()
			n.position = at
			world_node(n)
			match w["scene"]:
				"pound":
					add_blobs(n, [[Vector3.ZERO, Vector3(0.26, 0.1, 0.26), Color(1, 1, 0.97)]])
				"paws":
					var org := Color(0.96, 0.56, 0.18)
					add_blobs(n, [
						[Vector3(0, 0, -0.35), Vector3(0.24, 0.24, 0.7), org],
						[Vector3(0, 0, -0.3), Vector3(0.25, 0.06, 0.1), Color(0.14, 0.11, 0.1)],
						[Vector3(0, -0.02, 0.05), Vector3(0.32, 0.2, 0.32), Color(0.99, 0.96, 0.9)],
					], blob_gloss())
				"climb":
					add_blobs(n, [[Vector3.ZERO, Vector3(0.5, 0.09, 0.09), Color(0.5, 0.36, 0.22)], [Vector3(0.2, 0.05, 0), Vector3(0.18, 0.08, 0.12), Color(0.4, 0.62, 0.3)]])
				"rope":
					var glow := StandardMaterial3D.new()
					glow.albedo_color = Color(1.0, 0.95, 0.7)
					glow.emission_enabled = true
					glow.emission = Color(1.0, 0.85, 0.4)
					glow.emission_energy_multiplier = 2.0
					var mi := add_mcyl(n, glow, 0.16, 0.16, 0.22, Vector3.ZERO)
					mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			n.set_meta("from", at)
			add_target_marker(n)
			pop3d(n, true)
			return n
	return super(at)

func scene_target_tip(n: Node3D, age: float, life: float) -> Vector3:
	var t := clampf(age / life, 0.0, 1.0)
	var from: Vector3 = n.get_meta("from")
	match w["scene"]:
		"pound":
			n.scale = Vector3.ONE * (1.0 + sin(anim_t * 8.0) * 0.08)
			return n.position + Vector3(0, 0.1, 0)
		"paws":
			# 앞발이 광주리로 쑥 다가와요
			var b: Vector3 = w["basket"]
			n.position = from.lerp(b, t * 0.85)
			n.look_at(b + Vector3(0, 0.001, 0), Vector3.UP)
			n.rotate_object_local(Vector3.UP, PI)
			return n.position + Vector3(0, 0.15, 0)
		"climb":
			n.rotation.z = sin(anim_t * 3.0 + from.y) * 0.08
			return n.position
		"rope":
			n.position = from + Vector3(0, -t * 1.2, 0)
			return n.position
	return super(n, age, life)

func scene_target_hit(n: Node3D) -> void:
	var at := n.global_position
	match w["scene"]:
		"pound":
			hide_target_marker(n)
			cam_kick = 0.18
			w["swing"] = 1.0
			shake(8)
			hit_stop(0.04)
			sfx("land", 0.75)
			burst3d(at, Color(1, 1, 0.97), 12)
			float_text("쿵덕!", cam.unproject_position(at), Color(1, 0.95, 0.7), 1.3)
			if anban_dough != null:
				var tw := anban_dough.create_tween()
				anban_dough.scale = Vector3(1.12, 0.7, 1.08)
				tw.tween_property(anban_dough, "scale", Vector3.ONE, 0.25).set_ease(Tween.EASE_OUT)
			n.queue_free()
			return
		"climb":
			hide_target_marker(n)
			w["swing"] = 1.0
			sfx("tick", 1.0 + mg_count * 0.04)
			burst3d(at, Color(0.5, 0.7, 0.35), 8)
			float_text("영차!", cam.unproject_position(at), Color(1, 0.95, 0.7), 1.1)
			n.queue_free()
			return
		"rope":
			hide_target_marker(n)
			w["swing"] = 1.0
			sfx("good", 1.0 + mg_count * 0.05)
			burst3d(at, Color(1, 0.92, 0.6), 12)
			float_text("꽉!", cam.unproject_position(at), Color(1, 0.95, 0.7), 1.2)
			n.queue_free()
			return
		"paws":
			# 떡을 던져 주면 앞발이 쏙 들어가요
			var tk := blob_node([[Vector3.ZERO, Vector3(0.2, 0.12, 0.2), [Color(0.98, 0.97, 0.92), Color(0.45, 0.6, 0.32), Color(0.95, 0.78, 0.4)][rng.randi() % 3]]])
			tk.global_position = (w["basket"] as Vector3) + Vector3(0, 0.3, 0)
			var tw2 := tk.create_tween()
			tw2.tween_property(tk, "global_position", at, 0.18)
			tw2.tween_callback(tk.queue_free)
			hide_target_marker(n)
			w["swing"] = 1.0
			sfx("pop", 0.9)
			float_text("옜다, 떡!", cam.unproject_position(at), Color(1, 0.95, 0.7), 1.2)
			var back: Vector3 = n.get_meta("from")
			var tw3 := n.create_tween()
			tw3.tween_interval(0.15)
			tw3.tween_property(n, "position", back + (back - (w["basket"] as Vector3)).normalized() * 1.5, 0.3)
			tw3.tween_callback(n.queue_free)
			return
	super(n)

func scene_target_miss(n: Node3D) -> void:
	var at := n.global_position
	match w["scene"]:
		"pound", "climb", "rope", "paws":
			hide_target_marker(n)
			var msg: String = {"pound": "떡이 식어요!", "climb": "미끄러워요!", "rope": "매듭을 놓쳤어요!", "paws": "떡을 빼앗겼어요!"}[w["scene"]]
			float_text(msg, cam.unproject_position(at), Color(1, 0.55, 0.45), 1.0)
			var tw := n.create_tween()
			tw.tween_property(n, "scale", Vector3(0.01, 0.01, 0.01), 0.25)
			tw.tween_callback(n.queue_free)
			return
	super(n)

func scene_update(delta: float) -> void:
	super(delta)
	if not w.has("scene"):
		return
	var goal := float(mg_cfg.get("goal", 10))
	var prog := clampf(float(mg_count) / goal, 0.0, 1.0)
	match w["scene"]:
		"climb":
			# 오누이가 가지를 잡을 때마다 조금씩 위로
			var base: Dictionary = w["kid_base"]
			for k in base:
				var kid := npc(k)
				var b: Vector3 = base[k]
				var top := tree_pos + (Vector3(-0.35, 0, 0.35) if k == "oppa" else Vector3(-0.55, 0, -0.1))
				var p := b.lerp(top, minf(1.0, prog * 2.0))
				p.y = b.y + prog * (3.4 if k == "oppa" else 3.0)
				kid.position = kid.position.lerp(p, minf(1.0, delta * 6.0))
		"pine":
			var tb: Vector3 = w["tiger_base"]
			tiger.position = tb + Vector3(0, float(cg.get("climb", 0.0)) * 3.4, 0)
			(tiger.get_node("Body") as Node3D).rotation.z = sin(anim_t * 6.0) * 0.06
		"rope":
			var sw: float = w.get("swing", 0.0)
			var tilt: float = cg.get("tilt", 0.0)
			for k in ["oppa", "nui"]:
				var kid := npc(k)
				kid.rotation.y = sin(anim_t * 2.0) * 0.1 + sw * 0.2
				kid.rotation.z = lerpf(kid.rotation.z, -tilt * 0.35, 0.2)
			if sky_rope != null:
				sky_rope.rotation.z = lerpf(sky_rope.rotation.z, -tilt * 0.06, 0.2)

# 새 미니게임의 3D 연출
func cg_event(kind: String, info: Dictionary = {}) -> void:
	match w.get("scene", ""):
		"stack":
			if kind in ["drop", "perfect"]:
				cam_kick = 0.08
		"pine":
			if kind == "throw":
				w["swing"] = 1.0
			elif kind == "hit":
				burst3d(tiger.global_position + Vector3(0, 1.8, 0), Color(0.6, 0.42, 0.25), 14)
				float_text("아야!", cam.unproject_position(tiger.global_position + Vector3(0, 2.6, 0)), Color(1, 0.7, 0.5), 1.0)
		"pound":
			if kind in ["perfect", "good"]:
				w["swing"] = 1.0
				cam_kick = 0.2 if kind == "perfect" else 0.1
				sfx("land", 0.7 if kind == "perfect" else 0.85)
				var at := ANBAN_POS + Vector3(rng.randf_range(-0.3, 0.3), 0.7, rng.randf_range(-0.12, 0.12))
				burst3d(at, Color(1, 1, 0.97), 18 if kind == "perfect" else 9)
				if anban_dough != null:
					var sq := 0.62 if kind == "perfect" else 0.8
					anban_dough.scale = Vector3(1.18, sq, 1.1)
					anban_dough.create_tween().tween_property(anban_dough, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			elif kind == "bad":
				w["swing"] = 1.0
				flash(Color(1, 0.6, 0.5))
				float_text("아야야!", cam.unproject_position(ANBAN_POS + Vector3(0.6, 1.2, 0)), Color(1, 0.6, 0.5), 1.3)
			elif kind == "whiff":
				w["swing"] = 0.6
		"paws":
			var bk: Vector3 = w.get("basket", Vector3.ZERO)
			if kind == "block":
				w["swing"] = 1.0
				cam_kick = 0.18
				burst3d(bk + Vector3(0, 0.4, 0) + (w["fwd"] as Vector3) * 1.0, Color(1.0, 0.8, 0.4), 14)
				var tw := tiger.create_tween()
				tiger.scale = Vector3(1.08, 0.92, 1.08)
				tw.tween_property(tiger, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK)
			elif kind == "hit":
				var tk := blob_node([[Vector3.ZERO, Vector3(0.22, 0.13, 0.22), [Color(0.98, 0.97, 0.92), Color(0.45, 0.6, 0.32), Color(0.95, 0.78, 0.4)][rng.randi() % 3]]])
				tk.global_position = bk + Vector3(0, 0.3, 0)
				var tw2 := tk.create_tween()
				tw2.tween_property(tk, "global_position", tiger.position + Vector3(0, 2.0, 0), 0.35).set_ease(Tween.EASE_OUT)
				tw2.tween_callback(tk.queue_free)
			elif kind in ["feint", "fooled"]:
				float_text("히히, 속았지?", cam.unproject_position(tiger.position + Vector3(0, 3.2, 0)), Color(1, 0.8, 0.5), 1.2)
		"climb":
			if kind == "climb":
				w["swing"] = 1.0
				burst3d(tree_pos + Vector3(-0.4, 1.0 + float(mg_count) / 12.0 * 3.0, 0.4), Color(0.5, 0.7, 0.35), 8)
			elif kind == "shake" or kind == "warn":
				burst3d(tree_pos + Vector3(0, 4.5, 0), Color(0.4, 0.62, 0.3), 20)
			elif kind == "slip":
				for k in ["oppa", "nui"]:
					var kid := npc(k)
					kid.create_tween().tween_property(kid, "position:y", kid.position.y - 0.4, 0.15)
		"rope":
			if kind == "pull":
				w["swing"] = 1.0
				burst3d(tree_pos + Vector3(-0.3, 4.2, 0.3), Color(1, 0.92, 0.6), 8)
				for k in ["oppa", "nui"]:
					var kid := npc(k)
					kid.position.y += 0.08
			elif kind == "fall":
				for k in ["oppa", "nui"]:
					var kid2 := npc(k)
					kid2.position.y -= 0.3

func catch_item_node(bad: bool) -> Node3D:
	if w.get("scene", "") != "tteok":
		return super(bad)
	if bad:
		var spark := StandardMaterial3D.new()
		spark.albedo_color = Color(1.0, 0.55, 0.15)
		spark.emission_enabled = true
		spark.emission = Color(1.0, 0.45, 0.1)
		spark.emission_energy_multiplier = 2.5
		var n := Node3D.new()
		world_node(n)
		add_ball(n, Color(1.0, 0.6, 0.2), 0.14, Vector3.ZERO).material_override = spark
		add_ball(n, Color(1.0, 0.85, 0.3), 0.07, Vector3(0.08, 0.1, 0)).material_override = spark
		return n
	var cc: Color = [Color(0.72, 0.42, 0.32), Color(0.98, 0.97, 0.92), Color(0.45, 0.6, 0.32), Color(0.95, 0.78, 0.4)][rng.randi() % 4]
	return blob_node([[Vector3.ZERO, Vector3(0.36, 0.14, 0.3), cc], [Vector3(0, 0.08, 0), Vector3(0.3, 0.06, 0.24), cc.lightened(0.15)]])

func scene_pose() -> bool:
	if not w.has("scene"):
		return false
	var sw: float = w.get("swing", 0.0)
	match w["scene"]:
		"pound":
			var t := sw
			var arm := Vector3(lerpf(-2.75, -0.95, t), lerpf(0.12, 0.28, t), lerpf(-0.55, -0.1, t))
			pose_custom(arm, arm, lerpf(-0.12, 0.34, t), 0.18 + t * 0.15)
			var sh := (bone_world("armL") + bone_world("armR")) * 0.5
			place_tool((((bone_world("handL") + bone_world("handR")) * 0.5) - sh).normalized() + Vector3(0, 0.3 * (1.0 - t), 0))
			return true
		"stack":
			pose_custom(Vector3(-1.2, 0.3, -0.4), Vector3(-1.2, 0.3, -0.4), 0.1, 0.1)
			return true
		"pine":
			var t4 := sw
			pose_custom(Vector3(-0.4, 0.4, -0.3), Vector3(lerpf(-2.8, -1.0, t4), 0.3, lerpf(-0.4, 0.1, t4)), lerpf(-0.1, 0.25, t4), 0.1)
			return true
		"paws", "climb", "rope":
			var arm3 := Vector3(lerpf(-2.4, -0.9, sw), 0.25, lerpf(-0.6, -0.1, sw))
			pose_custom(Vector3(-0.3, 0.45, -0.3), arm3, lerpf(-0.05, 0.2, sw), 0.15)
			return true
		"tteok":
			pose_custom(Vector3(-2.7, 0.15, -0.5), Vector3(-2.7, 0.15, -0.5), -0.05, 0.1)
			return true
	return super()
