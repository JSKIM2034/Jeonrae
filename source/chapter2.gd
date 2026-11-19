extends "res://core.gd"

# 2장: 해와 달이 된 오누이 (만드는 중)
# 공통 부분(core.gd)을 그대로 쓰고, 맵과 이야기만 여기에 새로 만들어요.
#
# 맵은 남쪽 잔칫집 마을에서 시작해 북쪽으로 고개 셋을 넘어 오누이 오두막과 수수밭까지 이어지는 한 갈래 길이에요.
# 북쪽으로 갈수록 시간이 흘러 한낮 → 노을 → 깊은 밤이 돼요.

# 땅의 범위 (x: 왼쪽~오른쪽, z: 북쪽~남쪽)
const C2_X0 := -50.0
const C2_X1 := 50.0
const C2_Z0 := -140.0
const C2_Z1 := 58.0
const C2_STEP := 2.0

const VILLAGE_C := Vector3(0, 0, 28)
const COTTAGE_C := Vector3(6, 0, -108)
const FIELD_C := Vector3(24, 0, -112)

# 고개 셋: [능선 z, 고개(길이 넘는 낮은 곳) x, 높이]
const RIDGES := [[-6.0, -10.0, 7.0], [-42.0, 12.0, 10.0], [-78.0, -8.0, 12.0]]

# 길이 지나가는 점들 (마을 → 고개 셋 → 오두막 → 수수밭)
const ROAD := [
	Vector2(0, 54), Vector2(0, 40), Vector2(0, 28), Vector2(-3, 16), Vector2(-8, 4), Vector2(-10, -6),
	Vector2(-7, -18), Vector2(2, -28), Vector2(10, -36), Vector2(12, -42), Vector2(9, -52), Vector2(1, -62),
	Vector2(-6, -71), Vector2(-8, -78), Vector2(-5, -88), Vector2(0, -98), Vector2(5, -104),
]
const FIELD_ROAD := [Vector2(5, -104), Vector2(12, -108), Vector2(18, -111)]

var height_noise := FastNoiseLite.new()
var road_pts: PackedVector2Array

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
	var r := RandomNumberGenerator.new()
	r.seed = 5
	make_clouds(r)
	var mid := Vector3(0, 0, -42)
	add_ridge_ring(150.0, 40.0, 14.0, 30.0, Color(0.28, 0.48, 0.24), Color(0.4, 0.58, 0.34), 31, mid)
	add_ridge_ring(200.0, 50.0, 28.0, 56.0, Color(0.34, 0.48, 0.5), Color(0.46, 0.58, 0.64), 37, mid)

func after_ui() -> void:
	player.position = Vector3(0, height_at(0, 50) + 0.2, 50)

func start_chapter() -> void:
	set_time_of_day(0.0)
	show_card("2장\n해와 달이 된 오누이\n\n(만드는 중인 땅을 미리 걸어 봐요.\n북쪽 고개를 넘을수록 해가 저물어요.)", 1.0, 5.0, Callable())

func update_quest_text() -> void:
	quest_label.text = "할 일: 길을 따라 고개 셋을 넘어 오누이네 오두막까지 가 보기\n(2장 미리 보기 · 만드는 중)"

# 걸어갈수록 시간이 흘러요: 마을은 한낮, 첫째 고개 넘어 늦은 오후, 셋째 고개에서 해 질 녘, 오두막은 깊은 밤
func _process(delta: float) -> void:
	super(delta)
	if player == null:
		return
	var z := player.position.z
	var t := 0.0
	if z < 14.0:
		t = remap(z, 14.0, -50.0, 0.0, 0.68)
	if z < -50.0:
		t = remap(z, -50.0, -96.0, 0.68, 1.0)
	set_time_of_day(lerpf(time_of_day, clampf(t, 0.0, 1.0), minf(1.0, delta * 2.0)))

# 남쪽 끝 이정표: 1장 마을로 돌아가요
func on_gate() -> void:
	ask("", "1장 흥부네 마을로 돌아갈까요?", ["돌아가기", "더 둘러볼래요"], func(i: int):
		if i == 0:
			get_tree().change_scene_to_file("res://main.tscn"))

# ---------- 땅 높이 ----------

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
	h += 18.0 * smoothstep(50.0, 58.0, z)
	h += 18.0 * smoothstep(-126.0, -138.0, z)
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
	add_solid(Vector3(0, 10, C2_Z1 - 2), Vector3(100, 40, 1), none)
	add_solid(Vector3(0, 10, C2_Z0 + 8), Vector3(100, 40, 1), none)
	add_solid(Vector3(C2_X0 + 8, 10, -42), Vector3(1, 40, 200), none)
	add_solid(Vector3(C2_X1 - 8, 10, -42), Vector3(1, 40, 200), none)

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
	var gate := make_spot(on_ground(3.2, 47.0), "gate", "", "", true)
	add_mcyl(gate, wood_mat, 0.1, 0.12, 2.2, Vector3(0, 1.1, 0))
	add_mbox(gate, plank_mat, Vector3(1.6, 0.45, 0.08), Vector3(0, 1.85, 0.08))
	add_tag(gate, "1장 마을로 가는 길", 2.6)

# ---------- 고개 셋 (숲과 바위) ----------

func make_passes() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 33
	var placed := 0
	var tries := 0
	while placed < 120 and tries < 4000:
		tries += 1
		var x := r.randf_range(-32, 32)
		var z := r.randf_range(-96, 14)
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
		if p2.y > 14.0 or p2.y < -96.0:
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
		var z := r.randf_range(-124, 52)
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
