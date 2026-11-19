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

func chapter_state() -> Dictionary:
	return {"quest": quest, "lured": lured, "backed": backed, "ginseng": has_ginseng, "clams": clams_done, "pearls": pearls, "fish": fish_seen, "ending": ending}

func restore_chapter_state(d: Dictionary) -> void:
	quest = d.get("quest", 0)
	lured = d.get("lured", true)
	backed = d.get("backed", true)
	has_ginseng = d.get("ginseng", false)
	clams_done = d.get("clams", false)
	pearls = d.get("pearls", [false, false, false])
	fish_seen = d.get("fish", [false, false, false, false])
	ending = d.get("ending", "")

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
	make_undersea()
	make_palace()
	make_story()
	var r := RandomNumberGenerator.new()
	r.seed = 7
	make_clouds(r)
	add_ridge_ring(170.0, 40.0, 10.0, 26.0, Color(0.3, 0.5, 0.28), Color(0.42, 0.6, 0.36), 41, Vector3(0, 0, 10))

func after_ui() -> void:
	player.position = Vector3(0, height_at(0, 46) + 0.2, 46)

func start_chapter() -> void:
	set_time_of_day(0.0)
	above_fog = [env_ref.fog_density, env_ref.fog_light_color, env_ref.ambient_light_color, sun_light.light_energy]
	apply_story_state()
	if resumed:
		show_card("3장 별주부전\n이어서 걸어요...", 0.6, 1.6, Callable())
		return
	show_card("3장\n별주부전\n\n책장을 넘기자\n짭조름한 바닷바람이 불어왔어요.", 1.0, 4.0, Callable())

func cam_ground(x: float, z: float) -> float:
	return height_at(x, z)

func cam_ceiling() -> float:
	return -0.35 if swimming else INF

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
		h += height_noise.get_noise_2d(x, z) * 1.4 * smoothstep(4.0, 20.0, d)
		# 용궁 터는 평평한 너른 바닥
		var pal := (1.0 - smoothstep(16.0, 24.0, absf(x))) * smoothstep(-94.0, -100.0, z) * smoothstep(-142.0, -136.0, z)
		h = lerpf(h, PALACE_Y, pal)
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
	var c := Vector3(0, 0, (SHORE_Z + C3_Z0) / 2.0)
	var wd := C3_X1 - C3_X0
	var dp := SHORE_Z - C3_Z0 + 4.0
	add_mbox(self, water_material(2, Vector4(c.x, c.z, wd / 2.0, dp / 2.0), Color(0.08, 0.36, 0.55), Color(0.3, 0.68, 0.78), Vector2(0.0, 0.03), 0.9), Vector3(wd, 0.02, dp), c + Vector3(0, 0.05, 2.0))


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
const RABBIT_SPOTS := [Vector3(-17, 0, 25), Vector3(-29, 0, 34), Vector3(-22, 0, 45), Vector3(-33, 0, 23)]
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
var ending := ""
var sea_wall: CollisionShape3D
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

const FISH_KINDS := [
	{"name": "줄돔", "col": Color(0.98, 0.85, 0.3), "stripe": Color(0.2, 0.2, 0.25), "c": Vector3(-9, -4.0, -20), "r": 4.5},
	{"name": "쥐치", "col": Color(0.45, 0.72, 0.98), "stripe": Color(0.95, 0.95, 1.0), "c": Vector3(11, -5.0, -30), "r": 5.0},
	{"name": "볼락", "col": Color(0.9, 0.45, 0.38), "stripe": Color(0.6, 0.25, 0.25), "c": Vector3(-7, -7.0, -55), "r": 4.0},
	{"name": "등불고기", "col": Color(0.55, 1.0, 0.9), "stripe": Color(1.0, 1.0, 0.7), "c": Vector3(5, -10.0, -80), "r": 5.0},
]

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
			if Vector2(p2.x - sp.x, p2.y - sp.z).length() < 3.0:
				near_spot = true
		if near_spot:
			continue
		make_tree(on_ground(p2.x, p2.y, -0.1))
	# 토끼가 숨는 덤불
	var bushes := []
	for sp in RABBIT_SPOTS:
		for k in 4:
			var a := k * TAU / 4.0 + 0.5
			bushes.append([on_ground(sp.x + cos(a) * 1.4, sp.z + sin(a) * 1.2, 0.35), Vector3(1.3, 0.9, 1.2), Color(0.32, 0.55, 0.28).lerp(Color(0.45, 0.66, 0.32), r.randf())])
	add_blobs(self, bushes)
	# 갯벌 (조개 캐기)
	flat_ellipse(on_ground(CLAM_POS.x, CLAM_POS.z) + Vector3(0, 0.03, 0), 3.2, 2.2, 0.0, make_color(Color(0.42, 0.36, 0.3)))
	make_spot(on_ground(CLAM_POS.x, CLAM_POS.z), "clam", "", "갯벌", true)
	# 산삼 (뒷산 깊은 곳 나무 아래)
	var gs := make_spot(on_ground(GINSENG_POS.x, GINSENG_POS.z), "ginseng", "", "", true)
	add_blobs(gs, [
		[Vector3(0, 0.25, 0), Vector3(0.06, 0.5, 0.06), Color(0.3, 0.5, 0.2)],
		[Vector3(0.12, 0.45, 0), Vector3(0.3, 0.04, 0.14), Color(0.35, 0.62, 0.28), Vector3(0, 0, -20)],
		[Vector3(-0.12, 0.45, 0.05), Vector3(0.3, 0.04, 0.14), Color(0.35, 0.62, 0.28), Vector3(0, 30, 20)],
		[Vector3(0, 0.56, 0), Vector3(0.12, 0.1, 0.12), Color(0.9, 0.2, 0.2)],
	])
	# 남쪽 끝 이정표 (2장으로 돌아가기)
	var gate := make_spot(on_ground(3.2, 49.0), "gate", "", "", true)
	add_mcyl(gate, wood_mat, 0.1, 0.12, 2.2, Vector3(0, 1.1, 0))
	add_mbox(gate, plank_mat, Vector3(1.6, 0.45, 0.08), Vector3(0, 1.85, 0.08))
	add_tag(gate, "2장 고갯길로 가는 길", 2.6)

# ---------- 바닷속 ----------

func make_undersea() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 77
	# 산호 숲 (얕은 곳, 알록달록)
	var coral := []
	var coral_cols := [Color(1.0, 0.45, 0.5), Color(1.0, 0.65, 0.3), Color(0.75, 0.45, 0.95), Color(1.0, 0.85, 0.4), Color(0.4, 0.85, 0.85)]
	for i in 140:
		var x := r.randf_range(-34, 34)
		var z := r.randf_range(-46, -10)
		if absf(x) < 3.0 and z > -40.0:
			continue
		var base := on_ground(x, z)
		var col: Color = coral_cols[r.randi() % coral_cols.size()]
		var kind := r.randi() % 3
		if kind == 0:
			# 가지 산호
			for k in 4:
				var a := r.randf() * TAU
				coral.append([base + Vector3(cos(a) * 0.2, 0.45 + k * 0.1, sin(a) * 0.2), Vector3(0.14, 0.9, 0.14), col, Vector3(r.randf_range(-25, 25), 0, r.randf_range(-25, 25))])
		elif kind == 1:
			# 뇌산호 덩어리
			coral.append([base + Vector3(0, 0.25, 0), Vector3(1.0, 0.6, 0.9) * r.randf_range(0.7, 1.4), col.darkened(0.15)])
		else:
			# 부채 산호
			coral.append([base + Vector3(0, 0.6, 0), Vector3(1.2, 1.1, 0.08), col, Vector3(0, r.randf() * 180.0, 0)])
	add_blobs(self, coral, blob_gloss())
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

# 해초: 길쭉한 띠가 물결 따라 하늘하늘
func make_kelp(r: RandomNumberGenerator) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for blade in 3:
		var a := blade * TAU / 3.0
		var off := Vector3(cos(a) * 0.15, 0, sin(a) * 0.15)
		var side := Vector3(-sin(a), 0, cos(a)) * 0.16
		var segs := 8
		for k in segs:
			var y0 := k * 0.7
			var y1 := (k + 1) * 0.7
			var w0 := 1.0 - 0.6 * k / segs
			var w1 := 1.0 - 0.6 * (k + 1) / segs
			var c0 := Color(0.25, 0.42, 0.18).lerp(Color(0.5, 0.62, 0.25), float(k) / segs)
			var c1 := Color(0.25, 0.42, 0.18).lerp(Color(0.5, 0.62, 0.25), float(k + 1) / segs)
			var pa := off + Vector3(0, y0, 0) - side * w0
			var pb := off + Vector3(0, y0, 0) + side * w0
			var pc := off + Vector3(0, y1, 0) + side * w1
			var pd := off + Vector3(0, y1, 0) - side * w1
			for v in [[pa, c0], [pb, c0], [pc, c1], [pa, c0], [pc, c1], [pd, c1]]:
				st.set_color(v[1])
				st.add_vertex(v[0])
	st.generate_normals()
	var mesh := st.commit()
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode cull_disabled;
void vertex() {
	float h = max(VERTEX.y, 0.0);
	float ph = MODEL_MATRIX[3].x * 0.7 + MODEL_MATRIX[3].z * 0.4;
	VERTEX.x += sin(TIME * 0.9 + ph + h * 0.6) * 0.08 * h;
	VERTEX.z += cos(TIME * 0.7 + ph + h * 0.5) * 0.06 * h;
}
void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.9;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	var xs := []
	var tries := 0
	while xs.size() < 260 and tries < 3000:
		tries += 1
		var x := r.randf_range(-36, 36)
		var z := r.randf_range(-68, -40)
		if absf(x) < 2.5:
			continue
		if Vector2(x - WRECK_C.x, z - WRECK_C.z).length() < 7.0:
			continue
		xs.append(Transform3D(Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3(1, r.randf_range(0.7, 1.3), 1)), on_ground(x, z, -0.1)))
	for i in 60:
		var x2 := r.randf_range(-38, 38)
		var z2 := r.randf_range(-96, -12)
		xs.append(Transform3D(Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3(0.8, r.randf_range(0.4, 0.8), 0.8)), on_ground(x2, z2, -0.1)))
	mm.instance_count = xs.size()
	for i in xs.size():
		mm.set_instance_transform(i, xs[i])
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

# 물고기 떼: 네 종류가 저마다 동그랗게 맴돌아요
func make_fish_schools() -> void:
	var body_mesh := SphereMesh.new()
	body_mesh.radius = 0.5
	body_mesh.height = 1.0
	body_mesh.radial_segments = 10
	body_mesh.rings = 5
	var tail_mesh := PrismMesh.new()
	tail_mesh.size = Vector3(1, 1, 0.1)
	for fk in FISH_KINDS.size():
		var info: Dictionary = FISH_KINDS[fk]
		var c: Vector3 = info["c"]
		c.y = maxf(c.y, height_at(c.x, c.z) + 2.5)
		var mats := []
		for col in [info["col"], info["stripe"]]:
			var m := StandardMaterial3D.new()
			m.albedo_color = col
			m.roughness = 0.4
			if fk == 3:
				m.emission_enabled = true
				m.emission = col
				m.emission_energy_multiplier = 1.4
			mats.append(m)
		var parts := []
		for k in 2:
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = body_mesh if k == 0 else tail_mesh
			mm.instance_count = 10
			var mi := MultiMeshInstance3D.new()
			mi.multimesh = mm
			mi.material_override = mats[k]
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mi)
			parts.append(mm)
		schools.append([parts[0], parts[1], c, float(info["r"]), 0.35 + fk * 0.06, fk])

func update_fish(t: float) -> void:
	for sc in schools:
		var bm: MultiMesh = sc[0]
		var tm: MultiMesh = sc[1]
		var c: Vector3 = sc[2]
		var rad: float = sc[3]
		var sp: float = sc[4]
		var fk: int = sc[5]
		for i in 10:
			var a := t * sp + i * 0.42 + fk
			var rr := rad + sin(i * 2.1) * 0.9
			var p := c + Vector3(cos(a) * rr, sin(a * 2.0 + i) * 0.6 + (i % 3) * 0.35, sin(a) * rr * 0.7)
			var fwd := Vector3(-sin(a) * rr, 0, cos(a) * rr * 0.7).normalized()
			var bas := Basis.looking_at(-fwd, Vector3.UP)
			var wig := sin(t * 9.0 + i) * 0.35
			bm.set_instance_transform(i, Transform3D(bas.scaled(Vector3(0.18, 0.28, 0.5)), p))
			var tb := bas * Basis(Vector3.UP, wig) * Basis(Vector3.RIGHT, PI / 2.0)
			tm.set_instance_transform(i, Transform3D(tb.scaled(Vector3(0.24, 0.24, 0.9)), p - fwd * 0.3))
		# 가까이 가면 도감에 올라요
		if not fish_seen[fk] and player.position.distance_to(c) < rad + 3.5:
			fish_seen[fk] = true
			sfx("good")
			float_text("물고기 도감: %s!" % FISH_KINDS[fk]["name"], get_viewport().get_visible_rect().size * Vector2(0.5, 0.35), Color(0.7, 0.95, 1.0), 1.6)
			var all := true
			for b in fish_seen:
				all = all and b
			if all:
				earn(20)
				float_text("물고기 도감 완성!", get_viewport().get_visible_rect().size * Vector2(0.5, 0.45), Color(1, 0.9, 0.4), 2.0)
			update_quest_text()
			save_progress()

# 깊은 골짜기의 빛나는 해파리 (닿으면 찌릿!)
func make_jellies(r: RandomNumberGenerator) -> void:
	var dome := SphereMesh.new()
	dome.radius = 0.55
	dome.height = 0.7
	dome.is_hemisphere = true
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.6, 1.0, 0.6)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.8, 0.5, 1.0)
	mat.emission_energy_multiplier = 1.2
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var tmat := StandardMaterial3D.new()
	tmat.albedo_color = Color(0.95, 0.75, 1.0, 0.7)
	tmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tmat.emission_enabled = true
	tmat.emission = Color(0.9, 0.6, 1.0)
	for i in 11:
		var x := r.randf_range(-12, 12)
		var z := r.randf_range(-94, -68)
		var y := height_at(x, z) + r.randf_range(2.5, 7.0)
		var n := Node3D.new()
		n.position = Vector3(x, y, z)
		add_child(n)
		var d := MeshInstance3D.new()
		d.mesh = dome
		d.material_override = mat
		d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.add_child(d)
		for k in 5:
			var a := k * TAU / 5.0
			var tm := add_mcyl(n, tmat, 0.02, 0.01, 1.1, Vector3(cos(a) * 0.3, -0.5, sin(a) * 0.3))
			tm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		jellies.append([n, n.position, r.randf() * TAU])

func update_jellies(t: float, delta: float) -> void:
	jelly_cool = maxf(0.0, jelly_cool - delta)
	var body_c := player.position + Vector3(0, 0.8, 0)
	for j in jellies:
		var n: Node3D = j[0]
		var base: Vector3 = j[1]
		var ph: float = j[2]
		n.position = base + Vector3(sin(t * 0.3 + ph) * 1.2, sin(t * 0.8 + ph) * 1.0, cos(t * 0.25 + ph) * 1.0)
		n.scale = Vector3(1.0 + sin(t * 2.4 + ph) * 0.08, 1.0 - sin(t * 2.4 + ph) * 0.1, 1.0 + sin(t * 2.4 + ph) * 0.08)
		if jelly_cool <= 0.0 and swimming and n.position.distance_to(body_c) < 1.3:
			jelly_cool = 1.0
			var away := (body_c - n.position).normalized()
			player.velocity = away * 7.0 + Vector3(0, 1.5, 0)
			sfx("bad")
			shake(10)
			flash(Color(0.85, 0.6, 1.0))
			float_text("찌릿!", cam.unproject_position(body_c), Color(0.95, 0.7, 1.0), 1.0)

# 물 위에서 비쳐 드는 빛줄기
func make_light_shafts(r: RandomNumberGenerator) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.97, 1.0, 0.07)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = false
	for i in 16:
		var x := r.randf_range(-24, 24)
		var z := r.randf_range(-70, -10)
		var h := -height_at(x, z)
		var mi := add_mbox(self, mat, Vector3(r.randf_range(1.2, 2.6), h + 1.0, 0.02), Vector3(x, -h / 2.0, z))
		mi.rotation = Vector3(0.0, r.randf() * PI, r.randf_range(0.18, 0.32))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		shafts.append([mi, r.randf() * TAU])

# 자라를 따라가는 물살 고리
func make_rings() -> void:
	var pts := [Vector3(1.5, -2.0, -12), Vector3(-3, -3.2, -18), Vector3(3, -4.4, -24), Vector3(-2, -5.4, -30), Vector3(1, -6.0, -36)]
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
	add_mbox(self, make_color(Color(0.78, 0.74, 0.68)), Vector3(26, 0.4, 30), Vector3(0, y + 0.05, -118))
	# 큰 전각
	make_house(Vector3(0, y + 0.25, -123), Vector3(13, 5.5, 7), Color(0.95, 0.9, 0.82), Color(0.28, 0.55, 0.58), "tile")
	for px in [-5.5, -2.0, 2.0, 5.5]:
		add_mcyl(self, red, 0.28, 0.3, 4.6, Vector3(px, y + 2.5, -119.2))
	# 용궁 문 (붉은 기둥 두 개와 지붕)
	for gx in [-3.0, 3.0]:
		gate_parts.append(add_mcyl(self, red, 0.35, 0.38, 6.0, Vector3(gx, y + 3.0, GATE_Z)))
		add_solid(Vector3(gx, y + 3.0, GATE_Z), Vector3(0.8, 6.0, 0.8), Color(0, 0, 0, 0))
	gate_parts.append(add_mbox(self, jade, Vector3(8.4, 0.5, 1.4), Vector3(0, y + 6.2, GATE_Z)))
	gate_parts.append(add_mbox(self, red, Vector3(7.6, 0.6, 0.6), Vector3(0, y + 5.6, GATE_Z)))
	add_tag_at(Vector3(0, y + 7.2, GATE_Z), "용궁")
	# 진주 등불
	var pearl := StandardMaterial3D.new()
	pearl.albedo_color = Color(1.0, 0.97, 0.9)
	pearl.emission_enabled = true
	pearl.emission = Color(1.0, 0.92, 0.75)
	pearl.emission_energy_multiplier = 2.0
	for k in 6:
		var lx := -9.0 + (k % 2) * 18.0
		var lz := -104.0 - (k / 2) * 7.0
		add_mcyl(self, gold, 0.08, 0.1, 2.4, Vector3(lx, y + 1.2, lz))
		var orb := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.4
		sm.height = 0.8
		orb.mesh = sm
		orb.material_override = pearl
		orb.position = Vector3(lx, y + 2.7, lz)
		add_child(orb)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(0.9, 0.95, 1.0)
	lamp.light_energy = 2.5
	lamp.omni_range = 22.0
	lamp.position = Vector3(0, y + 6.0, -112)
	add_child(lamp)
	# 둘레 산호와 커다란 조개
	var r := RandomNumberGenerator.new()
	r.seed = 88
	var coral := []
	for i in 50:
		var a := r.randf() * TAU
		var rr := r.randf_range(13.0, 17.0)
		var p := Vector3(cos(a) * rr, 0, -116 + sin(a) * rr * 1.1)
		coral.append([on_ground(p.x, p.z, 0.5), Vector3(0.9, 1.4, 0.9) * r.randf_range(0.6, 1.4), Color(1.0, 0.5, 0.55).lerp(Color(0.6, 0.45, 1.0), r.randf())])
	add_blobs(self, coral, blob_gloss())
	# 북 (꽃게와 북 치기)
	var drum := make_spot(Vector3(DRUM_POS.x, y, DRUM_POS.z), "drum", "", "용궁 북", true)
	add_mcyl(drum, red, 0.65, 0.65, 0.9, Vector3(0, 1.3, 0)).rotation.x = PI / 2.0
	add_mcyl(drum, make_color(Color(0.95, 0.9, 0.8)), 0.6, 0.6, 0.92, Vector3(0, 1.3, 0)).rotation.x = PI / 2.0
	add_mbox(drum, make_color(Color(0.4, 0.28, 0.18)), Vector3(0.2, 0.8, 0.2), Vector3(0, 0.4, 0))
	# 큰 조개 (진주 받기)
	var bc := make_spot(Vector3(BIGCLAM_POS.x, y, BIGCLAM_POS.z), "bigclam", "", "커다란 조개", true)
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
	make_npc("jara", "자라", Color.WHITE, on_ground(JARA_BEACH.x, JARA_BEACH.z), 1.0, false)
	make_npc("haenyeo", "해녀", Color.WHITE, on_ground(HAENYEO_POS.x, HAENYEO_POS.z), 1.0, true)
	make_npc("rabbit", "토끼", Color.WHITE, on_ground(RABBIT_SPOTS[0].x, RABBIT_SPOTS[0].z), 0.85, false)
	make_npc("flatfish", "넙치 문지기", Color.WHITE, Vector3(FLATFISH_POS.x, PALACE_Y + 0.25, FLATFISH_POS.z), 1.0, true)
	make_npc("yongwang", "용왕", Color.WHITE, Vector3(YONGWANG_POS.x, PALACE_Y + 0.25, YONGWANG_POS.z), 1.0, true)
	make_npc("octopus", "문어 장군", Color.WHITE, Vector3(OCTOPUS_POS.x, PALACE_Y + 0.25, OCTOPUS_POS.z), 1.0, false)
	make_npc("crab", "꽃게 신하", Color.WHITE, Vector3(CRAB_POS.x, PALACE_Y + 0.25, CRAB_POS.z), 0.9, true)
	npc("jara").rotation.y = PI * 0.15

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
		rabbit.position = on_ground(RABBIT_SPOTS[rabbit_hop].x, RABBIT_SPOTS[rabbit_hop].z)
	if follow_on:
		jara.position = player.position + Vector3(1.6, 0, 1.4)
		rabbit.position = player.position + Vector3(-1.6, 0, 1.4)
	if quest == S_COURT or quest == S_FEAST:
		jara.position = Vector3(-2.5, PALACE_Y + 0.25, -111)
		rabbit.position = Vector3(2.0, PALACE_Y + 0.25, -111.5)
		jara.rotation.y = PI
		rabbit.rotation.y = PI
	if quest >= S_END:
		rabbit.visible = false
		jara.position = on_ground(JARA_BEACH.x, JARA_BEACH.z)
	update_quest_text()

func resumed_in_sea() -> bool:
	return player.position.z < SHORE_Z

func update_quest_text() -> void:
	var t := ""
	match quest:
		S_ARRIVE:
			t = "모래사장 바위에 지쳐 있는 자라에게 말 걸기"
		S_FIND:
			t = "뒷산 숲에서 토끼 찾기 (덤불 사이로 숨어요)"
		S_LURE:
			t = "토끼를 데리고 바닷가 자라에게 가기"
		S_DIVE:
			t = "자라를 따라 빛나는 물살 고리 지나기 (%d/%d) | 위로 버튼을 누르면 떠올라요" % [ring_next, rings.size()]
		S_DEEP:
			t = "산호 숲과 해초 숲, 깊은 골짜기를 지나 북쪽 용궁 문까지 헤엄치기"
		S_GATE:
			t = "용궁 문 앞의 넙치 문지기에게 말 걸기"
		S_COURT:
			t = "용궁 전각 앞 용왕님 뵙기"
		S_FEAST:
			t = "용궁 잔치 돕기: 꽃게 신하의 북 · 문어 장군의 큰 조개, 다 하면 용왕님께"
		S_ESCAPE:
			t = "문어 장군이 쫓아와요! 남쪽 물가까지 헤엄쳐 올라가기"
		S_END:
			t = "3장 끝! 체험판을 모두 마쳤어요. 바닷속을 마음껏 헤엄쳐 보세요"
	var pc := 0
	for b in pearls:
		pc += 1 if b else 0
	var fc := 0
	for b2 in fish_seen:
		fc += 1 if b2 else 0
	quest_label.text = "할 일: %s\n엽전 %d냥 | 진주 %d/3 | 물고기 도감 %d/4" % [t, shown_coins, pc, fc]

# ---------- 헤엄치기 ----------

func is_swimming() -> bool:
	if player == null or quest < S_DIVE:
		return false
	return player.position.z < SHORE_Z + 1.0 and height_at(player.position.x, player.position.z) < -1.0

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
	update_fish(t)
	update_jellies(t, delta)
	for sh in shafts:
		(sh[0] as MeshInstance3D).transparency = 0.0
		(sh[0] as Node3D).rotation.y += delta * 0.02
	update_underwater_look()
	if cam != null and not gate_parts.is_empty():
		var near_gate := absf(cam.global_position.z - GATE_Z) < 2.6 and absf(cam.global_position.x) < 5.5
		for gp in gate_parts:
			(gp as Node3D).visible = not near_gate
	if bubbles != null:
		bubbles.emitting = swimming
	if swimming != swim_shown and jump_button != null:
		swim_shown = swimming
		jump_button.text = "위로" if swimming else "점프"
		if swimming and not shown_swim_tip:
			shown_swim_tip = true
			float_text("위로 버튼을 누르고 있으면 떠올라요", get_viewport().get_visible_rect().size * Vector2(0.5, 0.4), Color(0.8, 0.95, 1.0), 2.4)
	update_followers(delta)
	update_story(delta)

var shown_swim_tip := false

# 카메라가 물속에 들어가면 푸른 안개로 바꿔요 (깊을수록 어둡게)
func update_underwater_look() -> void:
	if above_fog.is_empty() or cam == null:
		return
	var cp := cam.global_position
	var u := 0.0
	if cp.z < SHORE_Z + 3.0 and cp.y < -0.05:
		u = 1.0
	var depth := clampf(-cp.y / 16.0, 0.0, 1.0) * u
	var key := u + depth * 0.5
	if absf(key - under_amt) < 0.01:
		return
	under_amt = key
	if u > 0.5:
		env_ref.fog_density = lerpf(0.035, 0.05, depth)
		env_ref.fog_light_color = Color(0.2, 0.55, 0.68).lerp(Color(0.05, 0.16, 0.3), depth)
		env_ref.fog_sky_affect = 1.0
		env_ref.ambient_light_color = Color(0.55, 0.85, 0.95).lerp(Color(0.35, 0.5, 0.8), depth)
		sun_light.light_energy = lerpf(0.75, 0.35, depth)
		sun_light.light_color = Color(0.75, 0.95, 1.0)
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
		if follow_on and n.visible and not event_lock and not mg_active:
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
	match quest:
		S_FIND:
			update_rabbit_hide()
		S_DIVE:
			update_rings()
		S_DEEP:
			if player.position.z < GATE_Z + 6.0:
				event_lock = true
				say([
					["자라", "저기 붉은 기둥이 보이지요? 용궁 문이오!"],
					["토끼", "우와... 정말 진주로 지은 궁궐이네? 벼슬 준다는 말도 진짜겠지?"],
					["자라", "문지기 넙치에게 먼저 아뢰어야 하오. 넙치는 수수께끼를 좋아한다오."],
				], func():
					event_lock = false
					set_quest(S_GATE))
		S_ESCAPE:
			update_chase(delta)

# 토끼 숨바꼭질: 가까이 가면 다음 덤불로 깡충깡충
func update_rabbit_hide() -> void:
	if rabbit_busy:
		return
	var rabbit := npc("rabbit")
	var d := Vector2(player.position.x - rabbit.position.x, player.position.z - rabbit.position.z).length()
	if d < 5.5 and rabbit_hop < RABBIT_SPOTS.size() - 1:
		rabbit_hop += 1
		rabbit_busy = true
		var to: Vector3 = RABBIT_SPOTS[rabbit_hop]
		var dest := on_ground(to.x, to.z)
		rabbit.rotation.y = atan2(dest.x - rabbit.position.x, dest.z - rabbit.position.z)
		sfx("jump", 1.3)
		float_text("깡충!", cam.unproject_position(rabbit.position + Vector3(0, 2, 0)), Color(1, 1, 0.9), 1.0)
		var tw := rabbit.create_tween()
		var steps := 4
		for k in steps:
			var p := rabbit.position.lerp(dest, float(k + 1) / steps)
			p.y = height_at(p.x, p.z)
			tw.tween_property(rabbit, "position", p + Vector3(0, 1.2, 0), 0.18).set_ease(Tween.EASE_OUT)
			tw.tween_property(rabbit, "position", p, 0.16).set_ease(Tween.EASE_IN)
		tw.tween_callback(func(): rabbit_busy = false)

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
				["자라", "잘 따라오셨소! 이제 물살이 잔잔하니 마음껏 헤엄쳐도 되오."],
				["자라", "용궁은 북쪽 깊은 곳에 있소. 산호 숲, 해초 숲, 깊은 골짜기를 지나야 하오."],
				["자라", "골짜기의 빛나는 해파리는 건드리면 찌릿하니 조심하시오!"],
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

func talk_jara() -> void:
	match quest:
		S_ARRIVE:
			say([
				["자라", "헉헉... 뭍은 어찌 이리 덥고 메마르단 말이오..."],
				["자라", "아, 실례했소. 나는 바닷속 용궁의 신하 별주부라 하오."],
				["자라", "우리 용왕님께서 큰 병이 드셨는데, 뭍의 토끼라는 짐승이 있어야 낫는다 하오."],
				["자라", "(자라가 둘둘 만 그림을 펼쳐 보였다. 귀가 길쭉한 하얀 짐승이다.)"],
				["자라", "그런데 내 다리가 짧아 뒷산까지 오르기가 힘들구려. 토끼를 좀 찾아 주겠소?"],
			], func():
				rabbit_hop = 0
				npc("rabbit").position = on_ground(RABBIT_SPOTS[0].x, RABBIT_SPOTS[0].z)
				set_quest(S_FIND))
		S_FIND:
			say([["자라", "토끼는 뒷산 숲 덤불 사이에 산다 하오. 귀가 쫑긋하니 금방 알아볼 게요."]], Callable())
		S_LURE:
			say([
				["자라", "오오, 이분이 토끼 선생이시구려! 반갑소."],
				["토끼", "용궁 구경에 벼슬까지 준다니, 어서 가요 어서!"],
				["자라", "물속에서도 숨을 쉴 수 있게, 이 물방울 구슬을 하나씩 드리겠소."],
				["", "물방울 구슬을 받았다! 머리에 투명한 거품이 씌워졌다."],
				["자라", "내 뒤를 따라 빛나는 물살 고리를 지나 오시오. 위로 버튼을 누르면 떠오르고, 떼면 가라앉소."],
			], start_dive)
		S_END:
			if ending == "ginseng":
				say([["자라", "산삼 덕에 용왕님 병이 씻은 듯 나으셨다오. 그대의 고마움은 잊지 않겠소."]], Callable())
			else:
				say([["자라", "토끼에게는 속았지만... 그대와 함께한 바닷길은 즐거웠소."]], Callable())
		_:
			say([["자라", "용궁은 북쪽 깊은 바닷속이오. 함께 갑시다."]], Callable())

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
		if rabbit_hop < RABBIT_SPOTS.size() - 1:
			say([["토끼", "메롱~ 나 잡아 봐라!"]], Callable())
			return
		say([
			["토끼", "헉헉, 내가 졌다! 너 발 빠르구나. 그런데 무슨 일이야?"],
			["", "(바닷가에서 자라가 토끼를 찾고 있다고 전했다.)"],
			["토끼", "자라가 날? 왜?"],
		], func(): ask("", "자라가 \"용궁 구경시켜 주고 벼슬도 준다\"고 했다고 전할까?", ["\"용궁 구경 가자! 벼슬도 준대\"", "\"...좀 이상하긴 한데, 조심해\""], on_lure))
	elif quest == S_END:
		say([["토끼", "히히, 간을 빼놓고 다니는 짐승이 어디 있니? 그래도 너는 고마웠어!"]], Callable())
	else:
		say([["토끼", "용궁엔 진주가 산더미래! 벼슬은 무슨 벼슬일까?"]], Callable())

func on_lure(i: int) -> void:
	lured = i == 0
	var l := []
	if lured:
		l.append(["토끼", "용궁? 벼슬? 우와, 이런 산골에서 풀만 뜯을 수야 없지! 가자 가자!"])
	else:
		l.append(["토끼", "조심하라고? 에이, 걱정 마. 이 몸은 꾀주머니 토끼라고!"])
		l.append(["토끼", "그래도 용궁 구경은 놓칠 수 없지. 가 보자!"])
	say(l, func():
		follow_on = true
		set_quest(S_LURE))

func talk_haenyeo() -> void:
	if not clams_done:
		say([
			["해녀", "어머, 처음 보는 꼬마네! 바다 구경 왔니?"],
			["해녀", "저기 갯벌 숨구멍에서 조개가 뽀글뽀글 올라온단다. 좀 캐다 줄래?"],
			["해녀", "다 캐면 바닷속에서 쓰는 좋은 걸 하나 알려 주마."],
		], Callable())
	elif quest < S_DIVE:
		say([["해녀", "바닷속에선 숨이 제일이야. 자라가 물방울 구슬을 준다면 꼭 받으렴."]], Callable())
	elif quest == S_END:
		say([["해녀", "용궁에 다녀왔다고? 호호, 다음엔 나도 데려가 줘!"]], Callable())
	else:
		say([["해녀", "가라앉은 배 안에 진주가 숨어 있다더라. 물고기 떼도 가까이서 보면 참 예뻐."]], Callable())

func talk_flatfish() -> void:
	if quest == S_GATE:
		say([
			["넙치 문지기", "멈추시오! 용궁에 들어가려면 내 수수께끼를 풀어야 하오."],
		], func(): ask("넙치 문지기", "\"눈은 둘인데 한쪽에만 붙었고, 바닥에 납작 엎드려 사는 건?\"", ["넙치!", "가자미!", "문어!"], on_riddle))
	elif quest > S_GATE:
		say([["넙치 문지기", "(두 눈을 데굴데굴) 수상한 자는 못 들어간다... 아, 그대는 이미 들어왔지."]], Callable())
	else:
		say([["넙치 문지기", "여기는 용궁 문이오."]], Callable())

func on_riddle(i: int) -> void:
	if i == 2:
		say([["넙치 문지기", "문어 장군이 들으면 섭섭하겠소! 다시 생각해 보시오."]], talk_flatfish)
		return
	var l := []
	if i == 0:
		l.append(["넙치 문지기", "허허, 바로 나요! 맞혔소!"])
	else:
		l.append(["넙치 문지기", "가자미 녀석도 닮긴 했지... 반쯤 맞힌 걸로 치겠소!"])
	l.append(["넙치 문지기", "들어가시오. 용왕님께서 전각 앞에서 기다리신다오."])
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
				["용왕", "콜록콜록... 그대가 토끼를 데려왔구려..."],
				["토끼", "용왕님! 벼슬은 언제 주시나요? 진주 관이면 좋겠는데요!"],
				["용왕", "벼슬이라... 미안하오, 토끼여. 내 병에는 그대의 간이 약이라 하오."],
				["토끼", "가, 간이요?! (귀가 바짝 섰다)"],
				["문어 장군", "그렇다! 여봐라, 토끼를 붙잡아라!"],
				["토끼", "(토끼가 꼴깍 침을 삼키더니, 갑자기 껄껄 웃었다)"],
				["토끼", "아이고, 용왕님! 하필 오늘 간을 꺼내서 바닷가 바위에 말려 두고 왔지 뭡니까!"],
				["토끼", "토끼 간은 영험해서, 사흘에 한 번 꺼내 햇볕에 말려야 하거든요."],
			], func(): ask("용왕", "(용왕이 그대를 바라본다) 정말 그러하냐?", ["\"네! 바위에 간이 널려 있는 걸 봤어요\"", "(아무 말 없이 고개를 숙인다)"], on_back))
		S_FEAST:
			if feast_done("drum") and feast_done("pearl"):
				say([
					["용왕", "잔치가 흥겨웠소. 이제 자라와 함께 가서 간을 가져오시오."],
					["문어 장군", "(소곤) 수상하다... 간을 꺼내 말리는 짐승이 어디 있어?"],
					["문어 장군", "용왕님, 소장이 뒤따라가 지켜보겠습니다!"],
					["자라", "(소곤) 서두르시오! 문어 장군이 쫓아오기 전에 물 위로 올라갑시다!"],
				], start_escape)
			else:
				say([["용왕", "떠나기 전에 잔치를 열어 주겠소. 꽃게와 문어 장군을 도와주시오."]], Callable())
		S_END:
			say([["용왕", "(멀리서 들려오는 듯한 목소리) 고맙소, 뭍의 아이여..."]], Callable())
		_:
			say([["용왕", "콜록... 어서 오시오."]], Callable())

var feast_flags := {}

func feast_done(k: String) -> bool:
	return feast_flags.get(k, false)

func on_back(i: int) -> void:
	backed = i == 0
	var l := []
	if backed:
		l.append(["토끼", "(눈을 찡긋) 봐요, 이 아이도 봤다잖아요!"])
	else:
		l.append(["토끼", "(땀을 삐질) 이 아이는 부끄럼이 많아서요. 아무튼 정말이라니까요!"])
	l.append(["용왕", "허허, 그렇다면 자라와 함께 뭍에 다녀오시오."])
	l.append(["용왕", "그 전에 먼 길 떠나는 손님을 위해 잔치를 열어라!"])
	l.append(["꽃게 신하", "네, 넷! 북, 북을 칠 사람이... 아이고 바쁘다 바빠!"])
	say(l, func(): set_quest(S_FEAST))

func talk_crab() -> void:
	if quest == S_FEAST and not feast_done("drum"):
		say([["꽃게 신하", "집게로 북채를 잡으니 자꾸 미끄러져요! 대신 북 좀 쳐 주시겠어요?"]], start_drum)
	elif quest == S_FEAST:
		say([["꽃게 신하", "둥둥! 잔치 북소리 덕분에 용궁이 들썩들썩해요!"]], Callable())
	else:
		say([["꽃게 신하", "아이고 바쁘다 바빠! 옆으로 걸으니 더 바쁘네!"]], Callable())

func talk_octopus() -> void:
	if quest == S_FEAST and not feast_done("pearl"):
		say([
			["문어 장군", "흥, 뭍의 꼬마가 잔치를 돕겠다고? 솜씨 좀 보자."],
			["문어 장군", "저 큰 조개가 진주를 뱉어 낸다. 진주는 받고, 뾰족한 성게는 피해라!"],
		], start_pearl)
	elif quest == S_FEAST:
		say([["문어 장군", "제법이군... 그래도 토끼 녀석은 영 수상해."]], Callable())
	elif quest == S_END:
		say([["문어 장군", "(먹물을 뿜으며) 다음엔 안 놓친다!"]], Callable())
	else:
		say([["문어 장군", "용궁을 지키는 문어 장군이다! 수상한 자는 이 삼지창 맛을 보리라!"]], Callable())

# ---------- 물건 누르기 ----------

func is_active(t: Dictionary) -> bool:
	match t["kind"]:
		"clam":
			return not clams_done
		"ginseng":
			return not has_ginseng
		"pearl":
			return not pearls[int(t["id"])]
		"drum":
			return quest == S_FEAST and not feast_done("drum")
		"bigclam":
			return quest == S_FEAST and not feast_done("pearl")
	return super(t)

func action_text(t: Dictionary) -> String:
	match t["kind"]:
		"clam":
			return "조개 캐기"
		"ginseng":
			return "약초 캐기"
		"pearl":
			return "진주 줍기"
		"drum":
			return "북 치기"
		"bigclam":
			return "진주 받기"
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
			say([["", "빨간 열매가 달린 산삼을 캤다! 귀한 약초다. 언젠가 쓸 데가 있겠지."]], func(): save_progress())
		"pearl":
			sfx("good")
			pearls[int(t["id"])] = true
			node.visible = false
			burst3d(node.position + Vector3(0, 0.4, 0), Color(1, 0.98, 0.9), 14)
			earn(5)
			var n := 0
			for b in pearls:
				n += 1 if b else 0
			var l := [["", "조개 속에서 동그란 진주를 찾았다! (%d/3)" % n]]
			if n >= 3:
				earn(15)
				l.append(["", "진주 세 알을 모두 모았다! 반짝반짝 예쁘다."])
			say(l, func(): update_quest_text(); save_progress())
		"drum":
			sfx("tap")
			start_drum()
		"bigclam":
			sfx("tap")
			start_pearl()
		"gate":
			sfx("tap")
			on_gate()
		_:
			super()

# ---------- 미니게임 ----------

func start_clam() -> void:
	start_game("mash", {"world": true, "scene": "clam", "art": "world", "title": "갯벌 숨구멍이 뽀글뽀글!\n조개가 깊이 숨기 전에 빠르게 연타해 캐요", "goal": 6, "taps": 9, "round_time": 2.6, "decay": 0.25, "lose_text": "쏙 숨었어요!", "unit": "조개"}, clam_done)

func clam_done(ok: bool, _good: bool) -> void:
	if not ok:
		say([["해녀", "호호, 조개가 쏙 숨어 버렸네. 다시 해 보렴!"]], Callable())
		return
	clams_done = true
	earn(15)
	say([
		["해녀", "와, 바구니 가득이네! 고맙다."],
		["해녀", "바닷속 비밀 하나 알려 줄게. 가라앉은 배 안 조개에 진주가 숨어 있단다."],
		["해녀", "그리고 물고기 떼는 가까이 다가가야 이름을 알 수 있어."],
	], func(): save_progress())

func start_drum() -> void:
	start_game("rhythm", {"world": true, "scene": "drum", "art": "world", "title": "둥둥! 용궁 잔치 북을 박자에 맞춰 톡!\n꽃게 집게(빨간 ✕)가 올 땐 멈춰요", "goal": 16, "bpm": 112, "bad_ratio": 0.18, "note": "둥", "bad_text": "앗, 꽃게 집게!", "unit": "북"}, drum_done)

func drum_done(ok: bool, _good: bool) -> void:
	if not ok:
		say([["꽃게 신하", "박자가 엉켰어요! 다시 한 번만요!"]], Callable())
		return
	feast_flags["drum"] = true
	earn(10)
	say([["꽃게 신하", "둥둥 덩실! 물고기들이 춤을 춰요! 고마워요!"]], func(): update_quest_text())

func start_pearl() -> void:
	start_game("catch", {"world": true, "scene": "pearl", "art": "world", "title": "큰 조개가 뱉는 진주는 받고\n뾰족한 성게는 피하세요", "goal": 12, "interval": 0.62, "speed": 0.4, "bad_ratio": 0.32, "good": "진주", "bad": "성게", "basket": "소쿠리"}, pearl_done)

func pearl_done(ok: bool, _good: bool) -> void:
	if not ok:
		say([["문어 장군", "성게에 찔렸느냐? 흥, 다시 해 봐라."]], Callable())
		return
	feast_flags["pearl"] = true
	earn(10)
	say([["문어 장군", "...제법이구나. 진주 하나 흘리지 않다니."]], func(): update_quest_text())

func is_tap_scene(scene: String) -> bool:
	return scene in ["clam", "drum"] or super(scene)

func is_catch_scene(scene: String) -> bool:
	return scene == "pearl" or super(scene)

func scene_setup(scene: String) -> void:
	w["scene"] = scene
	w["seen"] = {}
	w["count0"] = mg_count
	w["lives0"] = mg_lives
	match scene:
		"clam":
			var c := on_ground(CLAM_POS.x, CLAM_POS.z)
			var stand := c + Vector3(-1.4, 0, 2.0)
			world_game_begin(stand, c, c + Vector3(-2.6, 3.2, 5.0), c + Vector3(0.2, 0.0, 0))
			hold_tool("shovel")
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

func scene_spawn_target() -> Vector3:
	match w["scene"]:
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
			float_text("쏙!", cam.unproject_position(at), Color(1, 0.95, 0.7), 1.1)
			n.queue_free()
			return
		"drum":
			hide_target_marker(n)
			w["swing"] = 1.0
			cam_kick = 0.12
			sfx("drum", 0.9 + rng.randf() * 0.2)
			burst3d(at, Color(1, 0.85, 0.4), 8)
			float_text("둥!", cam.unproject_position(at), Color(1, 0.95, 0.7), 1.0)
			n.queue_free()
			return
	super(n)

func scene_target_miss(n: Node3D) -> void:
	match w["scene"]:
		"clam", "drum":
			hide_target_marker(n)
			float_text("조개가 숨었어요!" if w["scene"] == "clam" else "박자를 놓쳤어요!", cam.unproject_position(n.global_position), Color(1, 0.55, 0.45), 1.0)
			var tw := n.create_tween()
			tw.tween_property(n, "scale", Vector3(0.01, 0.01, 0.01), 0.25)
			tw.tween_callback(n.queue_free)
			return
	super(n)

# 새 미니게임의 3D 연출
var clam_node: Node3D

func cg_event(kind: String, info: Dictionary = {}) -> void:
	match w.get("scene", ""):
		"clam":
			var c := on_ground(CLAM_POS.x, CLAM_POS.z)
			if kind == "tap":
				w["swing"] = 1.0
				burst3d(c + Vector3(0.3, 0.15, 0), Color(0.42, 0.36, 0.3), 4)
				if clam_node == null or not is_instance_valid(clam_node):
					clam_node = blob_node([[Vector3.ZERO, Vector3(0.36, 0.16, 0.3), Color(0.85, 0.78, 0.66)], [Vector3(0, 0.07, 0), Vector3(0.3, 0.1, 0.26), Color(0.92, 0.86, 0.75)]])
					clam_node.global_position = c + Vector3(0.3, -0.12, 0)
				clam_node.global_position.y = minf(clam_node.global_position.y + 0.03, c.y + 0.12)
			elif kind == "round":
				w["swing"] = 1.0
				cam_kick = 0.15
				sfx("pop", 1.1)
				burst3d(c + Vector3(0.3, 0.3, 0), Color(0.45, 0.38, 0.3), 14)
				if clam_node != null and is_instance_valid(clam_node):
					var cn := clam_node
					clam_node = null
					var tw := cn.create_tween()
					tw.tween_property(cn, "global_position", cn.global_position + Vector3(-0.4, 1.4, 0.4), 0.3).set_ease(Tween.EASE_OUT)
					tw.parallel().tween_property(cn, "rotation", Vector3(3, 2, 0), 0.3)
					tw.tween_property(cn, "scale", Vector3.ONE * 0.01, 0.2)
					tw.tween_callback(cn.queue_free)
			elif kind == "escape":
				if clam_node != null and is_instance_valid(clam_node):
					clam_node.queue_free()
					clam_node = null
				burst3d(c + Vector3(0.3, 0.1, 0), Color(0.9, 0.95, 1.0), 10)
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
				float_text("집게에 콕!", cam.unproject_position(d + Vector3(0.5, 1.8, 0.5)), Color(1, 0.6, 0.5), 1.3)

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
	float_text("남쪽으로 헤엄쳐요!", get_viewport().get_visible_rect().size / 2.0, Color(1, 0.9, 0.4), 1.6)

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
	var sp := 3.7
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
		show_card("문어 장군에게 붙잡혔어요!\n\n용궁 문 앞에서 다시 헤엄쳐 봐요.", 0.0, 2.0, func():
			player.position = Vector3(0, PALACE_Y + 0.6, GATE_Z + 3.0)
			player.velocity = Vector3.ZERO
			oc.position = Vector3(OCTOPUS_POS.x, PALACE_Y + 0.25, OCTOPUS_POS.z)
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
		["토끼", "휴우, 살았다! 뭍이다 뭍!"],
		["자라", "자, 토끼 선생. 바위에 말려 둔 간을 어서 가져오시오."],
		["토끼", "(깡충 뛰어 바위 위로 올라가더니 배를 잡고 웃었다)"],
		["토끼", "이 미련한 자라야! 세상에 간을 꺼내 놓고 다니는 짐승이 어디 있니?"],
		["토끼", "벼슬은 됐고, 나는 내 뒷산으로 간다! 안녕~"],
	]
	if not lured:
		l.append(["토끼", "(돌아보며) 너는 처음부터 조심하라고 했지? 고마웠어!"])
	l.append(["자라", "아아... 이를 어쩐단 말이오. 용왕님 뵐 낯이 없구려..."])
	say(l, func():
		var tw := rabbit.create_tween()
		var dest := on_ground(RABBIT_SPOTS[2].x, RABBIT_SPOTS[2].z)
		tw.tween_property(rabbit, "position", dest, 2.5)
		tw.tween_callback(func(): rabbit.visible = false)
		if has_ginseng:
			ask("", "축 처진 자라에게 뒷산에서 캔 산삼을 건넬까?", ["산삼을 건넨다", "그냥 위로한다"], on_ginseng)
		else:
			on_ginseng(1))

func on_ginseng(i: int) -> void:
	var l := []
	if i == 0:
		ending = "ginseng"
		has_ginseng = false
		l.append(["자라", "이, 이건 백 년 묵은 산삼이 아니오?!"])
		l.append(["자라", "이것이면 용왕님 병도 나으실 게요. 고맙소, 정말 고맙소!"])
		l.append(["", "자라는 산삼을 품에 안고 기쁘게 바다로 돌아갔다."])
	else:
		ending = "plain"
		l.append(["", "자라의 등딱지를 토닥토닥 두드려 주었다."])
		l.append(["자라", "...그래도 그대 덕에 용궁 구경은 즐거웠소. 언젠가 또 봅시다."])
	say(l, func():
		var card := "자라는 바닷속으로,\n토끼는 뒷산으로 돌아갔어요.\n\n"
		if ending == "ginseng":
			card += "얼마 뒤 바닷가에 소식이 들려왔어요.\n용왕님이 산삼을 드시고\n씻은 듯이 나으셨대요."
		else:
			card += "꾀 많은 토끼 이야기는\n바닷가 마을에 두고두고 전해졌대요."
		show_card(card, 0.0, 5.0, finish_trial))

func finish_trial() -> void:
	event_lock = false
	earn(30)
	set_quest(S_END)
	show_card("빈 책장에 별주부전 그림이 새로 생겼어요.\n\n세 이야기가 모두 채워졌어요!\n\n(체험판은 여기까지예요.\n다음 이야기 책장도 곧 열려요.)", 0.0, 5.0, Callable())
