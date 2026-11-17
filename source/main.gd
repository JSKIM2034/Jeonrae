extends Node3D

const SPEED := 6.0
const JUMP := 8.0
const GRAVITY := 20.0
const REACH := 2.6
const MAP_HALF := 40.0
const PIECE_TOTAL := 7
const HERB_TOTAL := 3
const MISCHIEF_NEED := 3
const RICH_COINS := 80       # 엽전이 이만큼 모이면 숨겨진 선택지가 나타나요
const ENDING_COUNT := 4
# 글자 크기: 숫자를 줄이면 글자가 커져요 (16 이면 더 크게, 22 면 더 작게)
const TEXT_DIVIDER := 18.0
const INK := Color(0.2, 0.13, 0.08)
const PAPER := Color(0.98, 0.94, 0.84)

enum { Q_NOLBU, Q_MEET, Q_RICE, Q_VILLAGE, Q_SNAKE, Q_HERB, Q_GIVE, Q_SEASON, Q_SEED, Q_GOURD, Q_NOLBU2, Q_DOKKAEBI, Q_RETURN, Q_END }

# ---------- 진행 상태 ----------
var quest := Q_NOLBU
var coins := 0
var herbs_found := 0
var gourds_done := 0
var pieces_found := 0
var mischief := {}
var mischief_done := 0
var laundry_found := 0
var hide_state := 0
var hiders_found := 0
var axe_done := false
var helped_nolbu := false
var axe_lied := false
var ending_id := ""
var has_yeot := false
var has_shoes := false
var has_sickle := false
var has_hanbok := false

# ---------- 3D ----------
var player: CharacterBody3D
var player_body: Node3D
var cam: Camera3D
var cam_yaw := 0.0
var cam_yaw_target := 0.0
var jump_wanted := false
var npcs := {}
var things: Array = []
var current_thing: Dictionary = {}
var hut: Node3D
var nolbu_gourd: Node3D
var bush_col: CollisionShape3D
var saw_thing: Dictionary = {}
var rng := RandomNumberGenerator.new()
# 살아있는 느낌(흔들림, 물결, 나비, 구름)용
# 폰이 버벅이면 아래 두 값을 줄여 보세요 (그림자 끄기: false, 풀 개수: 800)
const SHADOWS_ON := true
const GRASS_COUNT := 2600
var light_mode := OS.has_feature("web") or OS.has_feature("mobile")  # 폰/웹은 가볍게
const CAM_OFFSET := Vector3(0, 7.0, 7.2)   # 카메라가 캐릭터 뒤 위에서 따라와요 (작을수록 가까워요)
var grass_mat: StandardMaterial3D
var sand_mat: StandardMaterial3D
var forest_mat: StandardMaterial3D
var water_mat: StandardMaterial3D
var anim_t := 0.0
var people := []         # 눈 깜빡임 등을 위한 모든 사람 몸
var limb_amt := 0.0       # 팔다리 흔들림 세기 (걷는 중이면 1)
var arm_up_amt := 0.0     # 점프할 때 팔 번쩍
var sway_items := []      # [노드, 처음 위치, 종류(0 둥실, 1 살랑), 위상, 세기]
var lantern_mats := []    # [재질, 위상]
var npc_bodies := []      # [몸, 처음 높이, 위상]
var creek_mat: StandardMaterial3D
var foam_mm: MultiMesh
var foam_data := []
var butterflies := []
var clouds := []

# ---------- 효과 (소리, 흔들림, 튀는 글자) ----------
var sounds := {}
var sound_players: Array = []
var sound_index := 0
var fx_layer: Control
var flash_rect: ColorRect
var shake_amt := 0.0
var shown_coins := 0
var walk_phase := 0.0
var step_count := 0
var was_on_floor := true
var idle_time := 0.0

# ---------- 화면 ----------
var font: Font
var font_size := 32
var drag_range := 100.0
var short_side := 1000.0
var touching := false
var touch_start := Vector2.ZERO
var move_input := Vector2.ZERO

var ui_layer: CanvasLayer
var action_button: Button
var jump_button: Button
var turn_button: Button
var quest_label: Label
var dialog_panel: PanelContainer
var name_label: Label
var text_label: Label
var next_hint: Label
var options_box: VBoxContainer
var talking := false
var asking := false
var line_index := 0
var current_lines: Array = []
var talk_done := Callable()
var ask_done := Callable()
var last_advance_ms := 0

var card_overlay: ColorRect
var card_label: Label
var in_card := false
var card_done := Callable()

# ---------- 미니게임 공통 ----------
var mg_overlay: ColorRect
var mg_title: Label
var mg_bar: ProgressBar
var mg_info: Label
var mg_stage: Control
var mg_active := false
var mg_type := ""
var mg_cfg: Dictionary = {}
var mg_done := Callable()
var mg_progress := 0.0
var mg_lives := 3
var mg_perfect := true
var mg_count := 0
var mg_timer := 0.0
var mg_touch := false
var mg_started := false
var mg_pos := Vector2.ZERO
var mg_phase := 0.0
var mg_off := 0.0
var mg_frame_angle := 0.0
var mg_speed := 0.0
var mg_last_angle := 0.0
var mg_has_last := false
var mg_warn_time := 0.0
var mg_items: Array = []
var mg_a: Panel
var mg_b: Panel
var mg_c: ColorRect
var mg_r := 100.0
var mg_big: Panel
var mg_step := 0
var mg_trail := 0.0
var mg_dir := 1.0

# ---------- 마을 사람들 (놀부 심술 수습) ----------
var villagers := {
	"dori": {
		"name": "돌이",
		"ask": [["돌이", "으아앙! 놀부 아저씨가 내 엿을 뺏어 먹었어!"], ["돌이", "엿 먹고 싶어... 장터 아저씨가 파는데..."]],
		"wait": "훌쩍... 엿은 장터 아저씨가 팔아.",
		"done": "우와, 엿이다! 고마워! 이제 안 울게.",
	},
	"suni": {
		"name": "순이 엄마",
		"ask": [["순이 엄마", "놀부가 빨랫줄을 끊어 놔서 빨래가 개울가에 다 흩어졌지 뭐니."], ["순이 엄마", "개울 따라 세 장만 찾아 주겠니?"]],
		"wait": "빨래는 개울가를 따라 흩어졌단다.",
		"done": "아이고, 다 찾아 왔구나! 고맙다.",
	},
	"kim": {
		"name": "김 서방",
		"ask": [["김 서방", "놀부가 다 익은 호박마다 말뚝을 박아 놨지 뭐냐!"], ["김 서방", "말뚝이 보이면 재빨리 눌러서 뽑아 다오."]],
		"fail": "말뚝이 너무 깊이 들어갔구나. 다시 해 보자.",
		"done": "호박이 살았다! 고맙다, 얘야.",
		"game": "tap",
		"cfg": {"title": "호박에 박힌 말뚝을\n사라지기 전에 눌러 뽑아요", "goal": 8, "interval": 0.9, "life": 1.5, "target": "말뚝", "center": "호박", "color": Color(0.95, 0.6, 0.2)},
	},
	"ong": {
		"name": "옹기 할멈",
		"ask": [["옹기 할멈", "놀부가 지나가다 장독을 발로 차서 금이 갔단다."], ["옹기 할멈", "진흙을 살살 돌려 발라 주겠니? 세게 하면 또 깨진단다."]],
		"fail": "에구, 금이 더 갔구나. 다시 살살 해 보자.",
		"done": "감쪽같구나! 장맛을 지켰다.",
		"game": "circle",
		"cfg": {"title": "깨진 장독 둘레에\n진흙을 살살 돌려 발라요", "label": "장독", "turns": 5.0, "max_speed": 10.0, "warn": "너무 세게 바르면 깨져요!", "color": Color(0.5, 0.33, 0.2)},
	},
	"park": {
		"name": "박 첨지",
		"ask": [["박 첨지", "놀부가 제 논에만 물을 대려고 우리 물꼬를 막아 버렸어!"], ["박 첨지", "나랑 박자 맞춰 삽질 좀 해 다오."]],
		"fail": "박자가 안 맞아 삽이 엇나갔구나. 다시 해 보자.",
		"done": "물이 콸콸 들어온다! 올해 농사는 살았다.",
		"game": "follow",
		"cfg": {"title": "박 첨지와 박자 맞춰 삽질!\n갈색 삽을 손가락으로 따라가세요", "slow": 2.0, "tol": 0.4, "goal": 5.0, "patience": 4.0, "color": Color(0.4, 0.6, 0.85)},
	},
}

var proverbs := [
	"콩 심은 데 콩 나고 팥 심은 데 팥 난다.",
	"가는 말이 고와야 오는 말이 곱다.",
	"티끌 모아 태산.",
	"백지장도 맞들면 낫다.",
	"뿌린 대로 거둔다.",
	"고생 끝에 낙이 온다.",
	"하늘은 스스로 돕는 자를 돕는다.",
]

# ---------- 시작 ----------

func _ready() -> void:
	# 어떤 폰에서도 글자와 버튼이 같은 비율로 보이도록 화면 기준을 고정해요
	var window := get_tree().root
	window.content_scale_size = Vector2i(720, 1280)
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	short_side = 720.0
	font_size = int(short_side / TEXT_DIVIDER)
	drag_range = short_side / 6.0
	mg_r = short_side * 0.2
	rng.seed = 7
	# 동화책 느낌의 둥글둥글한 글꼴(주아체)을 코드 안에 넣어 두었어요 (아래 FONT_B64)
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["Apple SD Gothic Neo", "sans-serif"])
	var ff := FontFile.new()
	ff.data = Marshalls.base64_to_raw(FONT_B64).decompress_dynamic(-1, FileAccess.COMPRESSION_DEFLATE)
	ff.fallbacks = [sf]
	font = ff

	make_sounds()
	make_world()
	make_village()
	make_forest()
	make_decor()
	apply_distance_culling(self)
	if light_mode:
		# 3D 화면은 조금 낮은 해상도로 그리고, 글자와 버튼은 그대로 또렷하게
		get_viewport().scaling_3d_scale = 0.7
	make_player()
	make_ui()
	make_game_ui()
	make_fx_ui()
	card_overlay = make_overlay(1.0)
	card_label = add_label(card_overlay, "", 1.0, 0.08, 0.25, 0.92, 0.75)
	update_quest_text()

	cam = Camera3D.new()
	cam.fov = 64.0
	add_child(cam)
	cam.make_current()
	show_card("할머니 댁 다락방에서\n낡은 옛이야기 책을 펼쳤더니...\n\n눈을 떠 보니\n책 속 세상이었어요!", 1.0, 4.0, Callable())

# ---------- 3D 부품 ----------

func make_color(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	return m

func add_box(parent: Node3D, c: Color, size: Vector3, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = make_color(c)
	mi.position = pos
	if maxf(size.x, size.z) > 30.0:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

func add_ball(parent: Node3D, c: Color, radius: float, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	mi.mesh = sphere
	mi.material_override = make_color(c)
	mi.position = pos
	parent.add_child(mi)
	return mi

func add_capsule(parent: Node3D, c: Color, solid: bool) -> MeshInstance3D:
	var body := MeshInstance3D.new()
	body.mesh = CapsuleMesh.new()
	body.material_override = make_color(c)
	body.position.y = 1.0
	parent.add_child(body)
	if solid:
		var col := CollisionShape3D.new()
		col.shape = CapsuleShape3D.new()
		col.position.y = 1.0
		parent.add_child(col)
	return body

func add_tag(parent: Node3D, text: String, height: float) -> void:
	var tag := Label3D.new()
	tag.text = text
	tag.font_size = 96
	tag.position.y = height
	parent.add_child(tag)
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.font = font

# 부딪히는 상자. c 의 투명도가 0 이면 보이지 않는 벽
func add_solid(pos: Vector3, size: Vector3, c: Color) -> CollisionShape3D:
	var body := StaticBody3D.new()
	body.position = pos
	add_child(body)
	if c.a > 0.0:
		add_box(body, c, size, Vector3.ZERO)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	return col

func add_thing(node: Node3D, kind: String, id: String) -> void:
	things.append({"node": node, "kind": kind, "id": id})

func make_spot(pos: Vector3, kind: String, id: String, label: String, shown: bool) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	add_child(n)
	if label != "":
		add_tag(n, label, 1.8)
	n.visible = shown
	add_thing(n, kind, id)
	return n

# 둥근 지붕(반구). 가로·높이·세로 크기를 따로 정해요
func add_dome(parent: Node3D, c: Color, rx: float, ry: float, rz: float, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = 1.0
	sp.height = 1.0
	sp.is_hemisphere = true
	sp.radial_segments = 24
	sp.rings = 10
	mi.mesh = sp
	mi.material_override = make_color(c)
	mi.position = pos
	mi.scale = Vector3(rx, ry, rz)
	parent.add_child(mi)

# 납작한 원기둥(처마 두께, 돌단 등)
func add_disc(parent: Node3D, c: Color, rx: float, h: float, rz: float, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cy := CylinderMesh.new()
	cy.top_radius = 1.0
	cy.bottom_radius = 1.0
	cy.height = h
	cy.radial_segments = 24
	mi.mesh = cy
	mi.material_override = make_color(c)
	mi.position = pos
	mi.scale = Vector3(rx, 1.0, rz)
	parent.add_child(mi)
	return mi

# 새끼줄 띠(얇은 고리)
func add_ring(parent: Node3D, c: Color, rx: float, rz: float, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.97
	t.outer_radius = 1.03
	t.rings = 24
	t.ring_segments = 8
	mi.mesh = t
	mi.material_override = make_color(c)
	mi.position = pos
	mi.scale = Vector3(rx, 3.0, rz)
	parent.add_child(mi)

func add_lantern(parent: Node3D, pos: Vector3) -> void:
	add_box(parent, Color(0.3, 0.2, 0.12), Vector3(0.28, 0.06, 0.28), pos + Vector3(0, 0.28, 0))
	var mi := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = 0.22
	sp.height = 0.55
	mi.mesh = sp
	var mat := make_color(Color(1.0, 0.95, 0.75))
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.85, 0.5)
	mat.emission_energy_multiplier = 0.6
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	lantern_mats.append([mat, pos.x * 1.7 + pos.z])

# 문살 있는 한지 문 한 짝
func add_door(parent: Node3D, pos: Vector3, w: float, h: float) -> void:
	var wood := Color(0.5, 0.33, 0.2)
	add_box(parent, wood, Vector3(w, h, 0.1), pos)
	add_box(parent, Color(0.97, 0.93, 0.8), Vector3(w - 0.16, h - 0.16, 0.14), pos)
	add_box(parent, wood, Vector3(0.06, h - 0.16, 0.18), pos)
	add_box(parent, wood, Vector3(w - 0.16, 0.06, 0.18), pos + Vector3(0, h * 0.18, 0))
	add_box(parent, wood, Vector3(w - 0.16, 0.06, 0.18), pos + Vector3(0, -h * 0.18, 0))

# 한옥. style: "thatch" 초가집 / "tile" 기와집. 앞쪽은 +z 방향
# ---------- 고운 질감: 코드로 직접 그린 그림들 ----------

func tex_from(img: Image) -> ImageTexture:
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

# 0~1 사이 값이 부드럽게 오르내리는 줄 (짚결, 나뭇결에 써요)
func rand_row(r: RandomNumberGenerator, n: int, passes: int) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(n)
	for i in n:
		a[i] = r.randf()
	for p in passes:
		var b := a.duplicate()
		for i in n:
			a[i] = (b[(i + n - 1) % n] + b[i] * 2.0 + b[(i + 1) % n]) * 0.25
	var lo := 1.0
	var hi := 0.0
	for v in a:
		lo = minf(lo, v)
		hi = maxf(hi, v)
	for i in n:
		a[i] = (a[i] - lo) / maxf(hi - lo, 0.001)
	return a

# 초가지붕 짚: 결이 아래로 흐르고, 층층이 덮인 그늘이 있어요
func make_thatch_tex() -> ImageTexture:
	var n := 256
	var r := RandomNumberGenerator.new()
	r.seed = 31
	var fine := rand_row(r, n, 0)
	var mid := rand_row(r, n, 2)
	var coarse := rand_row(r, n, 8)
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	var dark := Color(0.58, 0.41, 0.18)
	var light := Color(1.0, 0.87, 0.5)
	for y in n:
		var band := fposmod(float(y), 64.0) / 64.0
		var shade := 0.86 + 0.14 * smoothstep(0.0, 0.25, band)
		var shift := int(y / 64) * 53 + int(sin(y * 0.11) * 2.0) + n * 4
		for x in n:
			var xi := (x + shift) % n
			var s := fine[xi] * 0.35 + mid[xi] * 0.4 + coarse[xi] * 0.25
			var c := dark.lerp(light, s)
			img.set_pixel(x, y, Color(c.r * shade, c.g * shade, c.b * shade))
	return tex_from(img)

# 기와: 둥근 수키와 줄 + 한 장 한 장 끝의 그늘
func make_tile_tex() -> ImageTexture:
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	for y in n:
		var row := fposmod(float(y), 32.0) / 32.0
		var edge := 0.6 + 0.4 * smoothstep(0.0, 0.2, row)
		for x in n:
			var ux := fposmod(float(x), 32.0) / 32.0
			var ridge := 0.5 + 0.5 * pow(sin(ux * PI), 0.7)
			var v := ridge * edge
			img.set_pixel(x, y, Color(v, v, v * 1.02))
	return tex_from(img)

# 나뭇결 (세로 결). plank_every > 0 이면 마루 널빤지 이음매가 생겨요
func make_wood_tex(seed_v: int, plank_every: int) -> ImageTexture:
	var n := 128
	var r := RandomNumberGenerator.new()
	r.seed = seed_v
	var grain := rand_row(r, n, 1)
	var wave := rand_row(r, n, 5)
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	for y in n:
		for x in n:
			var wob := int(sin(y * 0.05 + wave[x] * 6.0) * 3.0)
			var g := grain[(x + wob + n) % n]
			var v := 0.76 + 0.24 * g
			if plank_every > 0:
				var px := x % plank_every
				if px < 2:
					v *= 0.55
				elif px < 4:
					v *= 1.08
			img.set_pixel(x, y, Color(v, v * 0.97, v * 0.93))
	return tex_from(img)

# 문살과 창호지 (아래쪽은 나무 판)
func make_lattice_tex() -> ImageTexture:
	var w := 128
	var h := 192
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	var paper := Color(0.98, 0.95, 0.86)
	var wood := Color(0.47, 0.3, 0.17)
	var panel_top := int(h * 0.8)
	for y in h:
		for x in w:
			var c := paper
			var frame := x < 7 or x >= w - 7 or y < 7 or y >= h - 7
			if frame or y >= panel_top:
				c = wood
				if y >= panel_top and not frame and (y == panel_top + 3 or x == w / 2):
					c = wood.darkened(0.3)
			elif (x - 7) % 15 < 2 or (y - 7) % 15 < 2:
				c = wood.lightened(0.08)
			else:
				var k := 0.96 + 0.04 * sin(x * 0.9 + y * 0.37)
				c = Color(paper.r * k, paper.g * k, paper.b * k)
			img.set_pixel(x, y, c)
	return tex_from(img)

# 대나무 바구니 엮음
func make_weave_tex() -> ImageTexture:
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	for y in n:
		for x in n:
			var horiz := ((x / 8) + (y / 8)) % 2 == 0
			var t := fposmod(float(y if horiz else x), 8.0) / 8.0
			var v := 0.62 + 0.38 * sin(t * PI)
			img.set_pixel(x, y, Color(0.88 * v, 0.7 * v, 0.42 * v))
	return tex_from(img)

var stone_mat: StandardMaterial3D
var stone_blob_mat: StandardMaterial3D
var thatch_blob_mat: StandardMaterial3D
var thatch_dark_mat: StandardMaterial3D
var wood_mat: StandardMaterial3D
var dark_wood_mat: StandardMaterial3D
var plank_mat: StandardMaterial3D
var lattice_mat: StandardMaterial3D
var basket_mat: StandardMaterial3D
var thatch_tex: ImageTexture
var tile_tex: ImageTexture
var plaster_tex: Texture2D
var house_rects: Array = []

func make_village_materials() -> void:
	var stone_tex := make_noise_tex(Color(0.62, 0.62, 0.62), Color(1.0, 1.0, 1.0), 0.09, 17)
	stone_mat = make_tex_material(Color(0.86, 0.84, 0.8), stone_tex, 0.6)
	stone_blob_mat = make_tex_material(Color(1.0, 1.0, 1.0), stone_tex, 0.9)
	stone_blob_mat.vertex_color_use_as_albedo = true
	thatch_tex = make_thatch_tex()
	thatch_blob_mat = make_tex_material(Color(1, 1, 1), thatch_tex, 0.7)
	thatch_blob_mat.vertex_color_use_as_albedo = true
	thatch_dark_mat = make_tex_material(Color(0.92, 0.82, 0.62), thatch_tex, 1.4)
	var wtex := make_wood_tex(41, 0)
	wood_mat = make_tex_material(Color(0.62, 0.42, 0.26), wtex, 0.9)
	dark_wood_mat = make_tex_material(Color(0.42, 0.27, 0.16), wtex, 0.9)
	plank_mat = make_tex_material(Color(0.78, 0.57, 0.36), make_wood_tex(43, 32), 0.7)
	tile_tex = make_tile_tex()
	lattice_mat = StandardMaterial3D.new()
	lattice_mat.albedo_texture = make_lattice_tex()
	lattice_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	lattice_mat.roughness = 1.0
	basket_mat = make_tex_material(Color(1, 1, 1), make_weave_tex(), 2.2)
	plaster_tex = make_noise_tex(Color(0.88, 0.86, 0.82), Color(1, 1, 1), 0.035, 23)

func plaster_mat(c: Color) -> StandardMaterial3D:
	return make_tex_material(c, plaster_tex, 0.5)

func glossy_mat(c: Color) -> StandardMaterial3D:
	var m := make_color(c)
	m.roughness = 0.34
	m.metallic_specular = 0.45
	return m

func add_mbox(parent: Node3D, mat: Material, size: Vector3, pos: Vector3) -> MeshInstance3D:
	var mi := add_box(parent, Color.WHITE, size, pos)
	mi.material_override = mat
	return mi

func add_mcyl(parent: Node3D, mat: Material, top_r: float, bottom_r: float, h: float, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cy := CylinderMesh.new()
	cy.top_radius = top_r
	cy.bottom_radius = bottom_r
	cy.height = h
	cy.radial_segments = 16
	mi.mesh = cy
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi

# 두 점을 잇는 막대 (밧줄, 지붕 마루 등)
func add_beam(parent: Node3D, mat: Material, a: Vector3, b: Vector3, w: float, h: float) -> MeshInstance3D:
	var mi := add_mbox(parent, mat, Vector3(w, h, a.distance_to(b)), (a + b) / 2.0)
	var dir := (b - a).normalized()
	var up := Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT
	mi.basis = Basis.looking_at(dir, up)
	return mi

func mesh_tri(st: SurfaceTool, pts: Array) -> void:
	for p in pts:
		st.set_uv(p[1])
		st.add_vertex(p[0])

# 초가지붕: 둥글게 부푼 짚더미 모양 + 두툼한 처마
func build_thatch_roof(rx: float, rz: float, h: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var na := 56
	var nt := 16
	var urep := maxf(2.0, roundf((rx + rz) * 1.15))
	var vrep := (maxf(rx, rz) + h) / 2.2
	var rows := []
	for it in nt + 3:
		var row := []
		for ia in na + 1:
			var th := TAU * ia / na
			var c := cos(th)
			var s := sin(th)
			var bx := rx * signf(c) * pow(absf(c), 0.6)
			var bz := rz * signf(s) * pow(absf(s), 0.6)
			var p := Vector3.ZERO
			var v := 0.0
			if it <= nt:
				var t := float(it) / nt
				p = Vector3(bx * t, h * pow(cos(t * PI * 0.5), 0.62), bz * t)
				v = t * vrep
			elif it == nt + 1:
				p = Vector3(bx * 1.02, -0.2, bz * 1.02)
				v = vrep + 0.06
			else:
				p = Vector3(bx * 0.96, -0.42, bz * 0.96)
				v = vrep + 0.12
			row.append([p, Vector2(float(ia) / na * urep, v)])
		rows.append(row)
	for it in rows.size() - 1:
		for ia in na:
			var a: Array = rows[it][ia]
			var b: Array = rows[it][ia + 1]
			var c2: Array = rows[it + 1][ia]
			var d: Array = rows[it + 1][ia + 1]
			mesh_tri(st, [a, b, c2])
			mesh_tri(st, [b, d, c2])
	st.index()
	st.generate_normals()
	return st.commit()

# 기와지붕 높이: 가운데 용마루에서 오목하게 내려가고, 네 귀퉁이 처마가 하늘로 들려요
func tile_roof_y(x: float, z: float, rxx: float, rz: float, ridge: float, h: float, lift: float) -> float:
	var ax := absf(x)
	var dz := absf(z) / rz
	var dx := clampf((ax - ridge) / (rxx - ridge), 0.0, 1.0)
	var d := maxf(dz, dx)
	var y := h * pow(1.0 - d, 1.55)
	y += lift * pow((ax / rxx) * dz, 2.0)
	y += lift * 0.35 * pow(ax / rxx, 4.0) * d
	return y

func build_tile_roof(rx: float, rz: float, h: float, lift: float, edge_mat: Material) -> Dictionary:
	var nz := 12
	var step := rz / nz
	var nxh := int(ceil(rx / step))
	var rxx := nxh * step
	var ridge := maxf(rxx - rz, step)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows := []
	for iz in range(-nz, nz + 1):
		var row := []
		for ix in range(-nxh, nxh + 1):
			var x := ix * step
			var z := iz * step
			var dz := absf(z) / rz
			var dx := clampf((absf(x) - ridge) / (rxx - ridge), 0.0, 1.0)
			var y := tile_roof_y(x, z, rxx, rz, ridge, h, lift)
			var uv := Vector2(x / 1.4, (1.0 - dz) * rz / 1.6)
			if dx > dz:
				uv = Vector2(z / 1.4, (1.0 - dx) * (rxx - ridge) / 1.6)
			row.append([Vector3(x, y, z), uv])
		rows.append(row)
	for iz in rows.size() - 1:
		for ix in rows[0].size() - 1:
			var a: Array = rows[iz][ix]
			var b: Array = rows[iz][ix + 1]
			var c: Array = rows[iz + 1][ix]
			var d: Array = rows[iz + 1][ix + 1]
			mesh_tri(st, [a, b, c])
			mesh_tri(st, [b, d, c])
	st.index()
	st.generate_normals()
	var mesh := st.commit()
	# 처마 두께 (가장자리를 아래로 내린 띠)
	var edge := []
	var nx: int = rows[0].size()
	for ix in nx:
		edge.append(rows[0][ix][0])
	for iz in range(1, rows.size()):
		edge.append(rows[iz][nx - 1][0])
	for ix in range(nx - 2, -1, -1):
		edge.append(rows[rows.size() - 1][ix][0])
	for iz in range(rows.size() - 2, -1, -1):
		edge.append(rows[iz][0][0])
	var st2 := SurfaceTool.new()
	st2.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in edge.size() - 1:
		var p0: Vector3 = edge[i]
		var p1: Vector3 = edge[i + 1]
		var down := Vector3(0, -0.26, 0)
		mesh_tri(st2, [[p0, Vector2.ZERO], [p1, Vector2.ZERO], [p0 + down, Vector2.ZERO]])
		mesh_tri(st2, [[p1, Vector2.ZERO], [p1 + down, Vector2.ZERO], [p0 + down, Vector2.ZERO]])
	st2.generate_normals()
	st2.commit(mesh)
	mesh.surface_set_material(1, edge_mat)
	return {"mesh": mesh, "rxx": rxx, "ridge": ridge}

func add_lattice(parent: Node3D, pos: Vector3, w: float, h: float, rot_y: float) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = rot_y
	parent.add_child(root)
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(w, h)
	q.mesh = qm
	q.material_override = lattice_mat
	q.position.z = 0.02
	root.add_child(q)
	var f := 0.09
	add_mbox(root, dark_wood_mat, Vector3(w + f * 2.0, f, 0.1), Vector3(0, h / 2.0 + f / 2.0, 0))
	add_mbox(root, dark_wood_mat, Vector3(w + f * 2.0, f, 0.1), Vector3(0, -h / 2.0 - f / 2.0, 0))
	add_mbox(root, dark_wood_mat, Vector3(f, h, 0.1), Vector3(w / 2.0 + f / 2.0, 0, 0))
	add_mbox(root, dark_wood_mat, Vector3(f, h, 0.1), Vector3(-w / 2.0 - f / 2.0, 0, 0))

func make_house(pos: Vector3, size: Vector3, wall: Color, roof: Color, style: String = "thatch") -> Node3D:
	var house := StaticBody3D.new()
	house.position = pos
	add_child(house)
	house_rects.append(Rect2(pos.x - size.x / 2.0 - 0.7, pos.z - size.z / 2.0 - 0.7, size.x + 1.4, size.z + 2.6))
	var r := RandomNumberGenerator.new()
	r.seed = int(pos.x * 13.0 + pos.z * 7.0 + size.x)
	var base_h := 0.32
	var body_h := size.y - base_h
	var hx := size.x / 2.0
	var hz := size.z / 2.0
	# 돌 기단 + 앞쪽 둥근 돌
	add_mbox(house, stone_mat, Vector3(size.x + 0.5, base_h, size.z + 0.5), Vector3(0, base_h / 2.0, 0))
	var rim := []
	var x := -hx - 0.25
	while x < hx + 0.2:
		var w := r.randf_range(0.42, 0.7)
		rim.append([Vector3(x + w / 2.0, base_h * 0.5, hz + 0.26), Vector3(w * 1.06, base_h * 0.98, 0.24), stone_color(r)])
		x += w
	add_blobs(house, rim, stone_blob_mat)
	# 회벽
	add_mbox(house, plaster_mat(wall), Vector3(size.x - 0.06, body_h, size.z - 0.06), Vector3(0, base_h + body_h / 2.0, 0))
	# 기둥
	var post := 0.26
	var xs: Array = [-hx, hx]
	if size.x > 5.5:
		xs += [-hx / 3.0, hx / 3.0]
	else:
		xs += [0.0]
	xs.sort()
	for px in xs:
		add_mbox(house, wood_mat, Vector3(post, body_h, post), Vector3(px, base_h + body_h / 2.0, hz))
	for px in [-hx, hx]:
		add_mbox(house, wood_mat, Vector3(post, body_h, post), Vector3(px, base_h + body_h / 2.0, -hz))
	# 도리 (지붕 아래 가로 나무)와 아랫단
	add_mbox(house, wood_mat, Vector3(size.x + 0.3, 0.26, 0.3), Vector3(0, size.y - 0.13, hz))
	add_mbox(house, wood_mat, Vector3(size.x + 0.3, 0.26, 0.3), Vector3(0, size.y - 0.13, -hz))
	add_mbox(house, wood_mat, Vector3(0.3, 0.26, size.z), Vector3(hx, size.y - 0.13, 0))
	add_mbox(house, wood_mat, Vector3(0.3, 0.26, size.z), Vector3(-hx, size.y - 0.13, 0))
	add_mbox(house, wood_mat, Vector3(size.x, 0.12, 0.16), Vector3(0, base_h + 0.06, hz + 0.02))
	# 문과 창 (문살 + 창호지)
	var dh := body_h * 0.7
	var door_y := base_h + 0.14 + dh / 2.0
	for i in xs.size() - 1:
		var x0: float = xs[i]
		var x1: float = xs[i + 1]
		var cx := (x0 + x1) / 2.0
		var bw := x1 - x0 - post
		if xs.size() == 4 and i != 1:
			add_lattice(house, Vector3(cx, base_h + body_h * 0.55, hz), bw * 0.62, body_h * 0.4, 0.0)
		elif xs.size() == 4:
			add_lattice(house, Vector3(cx - bw * 0.24, door_y, hz), bw * 0.44, dh, 0.0)
			add_lattice(house, Vector3(cx + bw * 0.24, door_y, hz), bw * 0.44, dh, 0.0)
		else:
			add_lattice(house, Vector3(cx, door_y, hz), bw * 0.64, dh, 0.0)
	for sx in [-1.0, 1.0]:
		add_lattice(house, Vector3(sx * hx, base_h + body_h * 0.56, 0), minf(size.z * 0.35, 1.2), body_h * 0.34, sx * PI / 2.0)
	# 툇마루와 디딤돌
	var maru_d := 0.95
	var mz := hz + 0.25 + maru_d / 2.0
	add_mbox(house, plank_mat, Vector3(size.x - 0.2, 0.13, maru_d), Vector3(0, base_h, mz))
	for lx in [-hx + 0.35, 0.0, hx - 0.35]:
		add_mbox(house, dark_wood_mat, Vector3(0.15, base_h, 0.15), Vector3(lx, base_h / 2.0, mz + maru_d / 2.0 - 0.14))
	add_blobs(house, [[Vector3(0, 0.08, mz + maru_d / 2.0 + 0.42), Vector3(1.3, 0.16, 0.62), Color(0.84, 0.82, 0.78)]], stone_blob_mat, true)
	# 등롱
	for sx in [-1.0, 1.0]:
		var lp := Vector3(sx * (hx - 0.45), size.y - 0.8, hz + 0.42)
		add_box(house, Color(0.3, 0.22, 0.15), Vector3(0.025, 0.5, 0.025), lp + Vector3(0, 0.5, 0))
		add_lantern(house, lp)
	# 지붕
	var roof_mi := MeshInstance3D.new()
	if style == "thatch":
		var rx := hx + 0.95
		var rz := hz + 0.95
		var rh := size.y * 0.58 + 0.3
		roof_mi.mesh = build_thatch_roof(rx, rz, rh)
		var tm := StandardMaterial3D.new()
		tm.albedo_texture = thatch_tex
		tm.albedo_color = Color(1, 1, 1).lerp(roof * 1.25, 0.2)
		tm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		tm.cull_mode = BaseMaterial3D.CULL_DISABLED
		tm.roughness = 1.0
		roof_mi.material_override = tm
		roof_mi.position.y = size.y - 0.04
		house.add_child(roof_mi)
		# 용마름 (꼭대기 짚 두루마리)과 새끼줄
		var top := size.y - 0.04 + rh
		var ridge := MeshInstance3D.new()
		var cap := CapsuleMesh.new()
		cap.radius = 0.24
		cap.height = rx * 1.0
		ridge.mesh = cap
		ridge.material_override = thatch_dark_mat
		ridge.rotation.z = PI / 2.0
		ridge.position.y = top - 0.02
		house.add_child(ridge)
		var rope := make_color(Color(0.42, 0.3, 0.17))
		for i in 5:
			var rxp := (i - 2) * rx * 0.22
			var ring := MeshInstance3D.new()
			var tor := TorusMesh.new()
			tor.inner_radius = 0.24
			tor.outer_radius = 0.28
			ring.mesh = tor
			ring.material_override = rope
			ring.rotation.z = PI / 2.0
			ring.position = Vector3(rxp, top - 0.02, 0)
			house.add_child(ring)
	else:
		var rx := hx + 1.25
		var rz := hz + 1.15
		var rh := size.y * 0.62
		var lift := 0.6
		var edge := make_color(roof.darkened(0.45))
		edge.cull_mode = BaseMaterial3D.CULL_DISABLED
		var data := build_tile_roof(rx, rz, rh, lift, edge)
		roof_mi.mesh = data["mesh"]
		var tm := StandardMaterial3D.new()
		tm.albedo_texture = tile_tex
		tm.albedo_color = Color(minf(roof.r * 1.7, 1.0), minf(roof.g * 1.7, 1.0), minf(roof.b * 1.7, 1.0))
		tm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		tm.cull_mode = BaseMaterial3D.CULL_DISABLED
		tm.roughness = 0.55
		tm.metallic_specular = 0.55
		roof_mi.set_surface_override_material(0, tm)
		var base_y := size.y + 0.08
		roof_mi.position.y = base_y
		house.add_child(roof_mi)
		var rxx: float = data["rxx"]
		var rdg: float = data["ridge"]
		var dark := make_color(roof.darkened(0.35))
		var lime := make_color(Color(0.95, 0.94, 0.9))
		# 용마루 (흰 줄 + 짙은 기와)
		add_box(house, Color(0.95, 0.94, 0.9), Vector3(rdg * 2.0 + 0.5, 0.14, 0.62), Vector3(0, base_y + rh + 0.02, 0)).material_override = lime
		add_mbox(house, dark, Vector3(rdg * 2.0 + 0.4, 0.3, 0.44), Vector3(0, base_y + rh + 0.2, 0))
		for sx in [-1.0, 1.0]:
			var tip := add_mbox(house, dark, Vector3(0.5, 0.26, 0.42), Vector3(sx * (rdg + 0.35), base_y + rh + 0.36, 0))
			tip.rotation.z = -sx * 0.6
			# 내림마루 (용마루 끝에서 네 귀퉁이로)
			for sz in [-1.0, 1.0]:
				var prev := Vector3(sx * rdg, base_y + rh + 0.1, 0)
				for k in range(1, 5):
					var f := float(k) / 4.0
					var px: float = sx * (rdg + (rxx - rdg) * f)
					var pz: float = sz * rz * f
					var cur := Vector3(px, base_y + tile_roof_y(px, pz, rxx, rz, rdg, rh, lift) + 0.12, pz)
					add_beam(house, dark, prev, cur, 0.26, 0.2)
					prev = cur
		# 서까래 끝 (처마 아래 줄지어 보이는 나무)
		var rafters := []
		var rx2 := -hx - 0.6
		while rx2 <= hx + 0.6:
			for sz in [-1.0, 1.0]:
				rafters.append([Vector3(rx2, size.y + 0.02, sz * (hz + 0.65)), Vector3(0.13, 0.13, 1.3), Color(0.5, 0.33, 0.2)])
			rx2 += 0.38
		add_blobs(house, rafters)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	col.position.y = size.y / 2.0
	house.add_child(col)
	return house

# 멀리 있는 작은 물건은 그리지 않아요 (안개에 가려 어차피 잘 안 보여요)
func apply_distance_culling(n: Node) -> void:
	for c in n.get_children():
		if c is GeometryInstance3D:
			var g := c as GeometryInstance3D
			var size := g.get_aabb().size
			var big := maxf(size.x, maxf(size.y, size.z))
			if big < 1.5:
				g.visibility_range_end = 30.0 if light_mode else 45.0
			elif big < 6.0:
				g.visibility_range_end = 55.0 if light_mode else 80.0
		apply_distance_culling(c)

# ---------- 이야기 속 물건들 (박, 둥지, 약초, 조각, 빨래, 보물) ----------

var soft_gloss_mat: StandardMaterial3D

func blob_gloss() -> StandardMaterial3D:
	if soft_gloss_mat == null:
		soft_gloss_mat = StandardMaterial3D.new()
		soft_gloss_mat.vertex_color_use_as_albedo = true
		soft_gloss_mat.roughness = 0.42
		soft_gloss_mat.metallic_specular = 0.6
	return soft_gloss_mat

# 넓적한 잎사귀 몇 장 (땅에 깔림)
func leaf_items(center: Vector3, count: int, size: float, r: RandomNumberGenerator, c: Color) -> Array:
	var items := []
	for i in count:
		var a := i * TAU / count + r.randf_range(-0.3, 0.3)
		var d := size * r.randf_range(0.7, 1.0)
		items.append([center + Vector3(cos(a) * d, 0.06 + r.randf() * 0.06, sin(a) * d), Vector3(size * 1.1, 0.06, size * 0.8), c.lightened(r.randf() * 0.12), Vector3(r.randf_range(-12, 12), -rad_to_deg(a), 0)])
	return items

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
	root.position = Vector3(0.52, 1.45, 0.0)
	root.rotation.y = -PI / 2.0
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
	var c := Color(0.95, 0.58, 0.18)
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
	var wtr := add_mbox(self, water_mat, Vector3(w - 0.4, 0.02, d - 0.4), center + Vector3(0, 0.08, 0))
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

# ---------- 마을 소품 ----------

func make_jangdok(pos: Vector3, r: RandomNumberGenerator) -> void:
	var root := StaticBody3D.new()
	root.position = pos
	add_child(root)
	add_mbox(root, stone_mat, Vector3(3.2, 0.36, 2.1), Vector3(0, 0.18, 0))
	var rim := []
	for i in 22:
		var a := i * TAU / 22.0
		var p := Vector3(cos(a) * 1.7, 0.2, sin(a) * 1.15)
		rim.append([p, Vector3(0.55, 0.42, 0.42), stone_color(r)])
	add_blobs(root, rim, stone_blob_mat)
	var jars := [[-1.0, -0.4, 1.0], [0.05, -0.45, 1.15], [1.05, -0.3, 0.95], [-0.55, 0.45, 0.75], [0.45, 0.5, 0.68], [1.15, 0.55, 0.5]]
	for j in jars:
		make_jar(root, Vector3(j[0], 0.36, j[1]), j[2], Color(0.36, 0.2, 0.12).lerp(Color(0.5, 0.3, 0.18), r.randf()))

func make_laundry(a: Vector3, b: Vector3) -> void:
	for p in [a, b]:
		add_mbox(self, dark_wood_mat, Vector3(0.13, 1.9, 0.13), p + Vector3(0, 0.95, 0))
	var d := b - a
	var root := Node3D.new()
	root.position = (a + b) / 2.0 + Vector3(0, 1.78, 0)
	root.rotation.y = atan2(-d.z, d.x)
	add_child(root)
	var length := d.length()
	add_box(root, Color(0.78, 0.68, 0.48), Vector3(length, 0.03, 0.03), Vector3.ZERO)
	var cloths := [[-0.95, 0.75, Color(0.99, 0.99, 0.97)], [0.0, 0.95, Color(0.84, 0.92, 1.0)], [0.95, 0.62, Color(1.0, 0.9, 0.86)]]
	for c in cloths:
		var cl := Node3D.new()
		cl.position = Vector3(c[0] * length / 3.0, 0, 0)
		root.add_child(cl)
		add_box(cl, c[2], Vector3(0.72, c[1], 0.03), Vector3(0, -c[1] / 2.0, 0))
		sway_items.append([cl, cl.position, 1, c[0] * 2.0 + a.x, 0.1])

func make_basket(pos: Vector3, s: float, fill: Color) -> void:
	add_mcyl(self, basket_mat, 0.34 * s, 0.25 * s, 0.34 * s, pos + Vector3(0, 0.17 * s, 0))
	var rim := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 0.31 * s
	tor.outer_radius = 0.38 * s
	rim.mesh = tor
	rim.material_override = basket_mat
	rim.position = pos + Vector3(0, 0.34 * s, 0)
	add_child(rim)
	if fill.a > 0.0:
		var items := []
		for i in 7:
			var a := i * TAU / 7.0
			items.append([pos + Vector3(cos(a) * 0.16 * s, 0.36 * s, sin(a) * 0.16 * s), Vector3(0.17, 0.15, 0.17) * s, fill.lightened(0.1 * (i % 3))])
		items.append([pos + Vector3(0, 0.42 * s, 0), Vector3(0.18, 0.16, 0.18) * s, fill])
		add_blobs(self, items)

# 벽에 기대 둔 둥근 채반
func make_sieve(pos: Vector3, rot_y: float) -> void:
	var mi := add_mcyl(self, basket_mat, 0.55, 0.55, 0.06, pos + Vector3(0, 0.55, 0))
	mi.rotation = Vector3(deg_to_rad(72.0), rot_y, 0)

func make_bench(pos: Vector3, rot_y: float) -> void:
	var root := StaticBody3D.new()
	root.position = pos
	root.rotation.y = rot_y
	add_child(root)
	add_mbox(root, plank_mat, Vector3(2.0, 0.12, 1.3), Vector3(0, 0.5, 0))
	add_mbox(root, dark_wood_mat, Vector3(2.08, 0.08, 0.1), Vector3(0, 0.46, 0.66))
	for sx in [-0.9, 0.9]:
		for sz in [-0.55, 0.55]:
			add_mbox(root, dark_wood_mat, Vector3(0.12, 0.46, 0.12), Vector3(sx, 0.22, sz))
	# 상 위에 소쿠리와 그릇
	add_mcyl(root, basket_mat, 0.3, 0.22, 0.12, Vector3(-0.45, 0.62, 0.1))
	add_blobs(root, [[Vector3(-0.45, 0.7, 0.1), Vector3(0.36, 0.1, 0.36), Color(0.95, 0.5, 0.15)], [Vector3(0.5, 0.64, -0.2), Vector3(0.3, 0.14, 0.3), Color(0.96, 0.95, 0.9)]])
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.0, 0.56, 1.3)
	col.shape = shape
	col.position.y = 0.28
	root.add_child(col)

# 콩 넝쿨 지지대
func make_trellis(a: Vector3, b: Vector3, r: RandomNumberGenerator) -> void:
	var n := 4
	var leaves := []
	for i in n:
		var p := a.lerp(b, float(i) / (n - 1))
		add_beam(self, dark_wood_mat, p, p + Vector3(0, 1.7, 0), 0.06, 0.06)
		for k in 6:
			var y := r.randf_range(0.3, 1.6)
			leaves.append([p + Vector3(r.randf_range(-0.2, 0.2), y, r.randf_range(-0.12, 0.12)), Vector3(0.26, 0.2, 0.08), Color(0.32, 0.62, 0.26).lightened(r.randf() * 0.15)])
	add_beam(self, dark_wood_mat, a + Vector3(0, 1.55, 0), b + Vector3(0, 1.55, 0), 0.05, 0.05)
	add_beam(self, dark_wood_mat, a + Vector3(0, 0.8, 0), b + Vector3(0, 0.8, 0), 0.04, 0.04)
	add_blobs(self, leaves)

func make_well_visual(n: Node3D) -> void:
	add_mcyl(n, stone_mat, 0.78, 0.85, 0.85, Vector3(0, 0.42, 0))
	var water := add_mcyl(n, water_mat, 0.62, 0.62, 0.04, Vector3(0, 0.78, 0))
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var r := RandomNumberGenerator.new()
	r.seed = 77
	var rim := []
	for i in 14:
		var a := i * TAU / 14.0
		rim.append([Vector3(cos(a) * 0.74, 0.9, sin(a) * 0.74), Vector3(0.36, 0.2, 0.3), stone_color(r)])
	add_blobs(n, rim, stone_blob_mat)
	for sx in [-0.95, 0.95]:
		add_mbox(n, dark_wood_mat, Vector3(0.14, 2.1, 0.14), Vector3(sx, 1.05, 0))
	var bar := add_mcyl(n, wood_mat, 0.07, 0.07, 2.0, Vector3(0, 1.75, 0))
	bar.rotation.z = PI / 2.0
	for sz in [-1.0, 1.0]:
		var plank := add_mbox(n, plank_mat, Vector3(2.3, 0.06, 0.75), Vector3(0, 2.25, sz * 0.32))
		plank.rotation.x = sz * 0.5
	add_beam(n, make_color(Color(0.7, 0.6, 0.42)), Vector3(0.2, 1.75, 0), Vector3(0.2, 1.25, 0), 0.025, 0.025)
	add_mcyl(n, wood_mat, 0.17, 0.14, 0.26, Vector3(0.2, 1.12, 0))

func make_haystack_visual(n: Node3D) -> void:
	add_blobs(n, [
		[Vector3(0, 0.45, 0), Vector3(1.8, 1.0, 1.4), Color(1.0, 0.92, 0.7)],
		[Vector3(0.1, 0.85, 0.05), Vector3(1.3, 0.8, 1.0), Color(1.0, 0.95, 0.75)],
		[Vector3(0, 1.15, 0), Vector3(0.6, 0.4, 0.5), Color(0.95, 0.85, 0.6)],
	], thatch_blob_mat)
	# 세워 둔 짚단과 만들다 만 짚신
	for i in 3:
		var sheaf := add_mcyl(n, thatch_dark_mat, 0.14, 0.2, 0.9, Vector3(-1.1 + i * 0.25, 0.45, 0.75))
		sheaf.rotation.z = (i - 1) * 0.15
	add_blobs(n, [[Vector3(0.9, 0.06, 0.8), Vector3(0.22, 0.1, 0.42), Color(0.86, 0.7, 0.4)], [Vector3(1.15, 0.06, 0.85), Vector3(0.22, 0.1, 0.42), Color(0.86, 0.7, 0.4)]], thatch_blob_mat)

func make_stump_visual(n: Node3D) -> void:
	add_mcyl(n, dark_wood_mat, 0.48, 0.58, 0.7, Vector3(0, 0.35, 0))
	add_mcyl(n, make_color(Color(0.86, 0.7, 0.5)), 0.47, 0.47, 0.02, Vector3(0, 0.71, 0))
	var ring := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 0.22
	tor.outer_radius = 0.26
	ring.mesh = tor
	ring.material_override = make_color(Color(0.7, 0.52, 0.34))
	ring.position.y = 0.715
	ring.scale.y = 0.2
	n.add_child(ring)
	# 꽂혀 있는 도끼
	var handle := add_mbox(n, wood_mat, Vector3(0.07, 0.75, 0.07), Vector3(0.1, 1.05, 0.05))
	handle.rotation.z = -0.35
	add_mbox(n, make_color(Color(0.55, 0.57, 0.6)), Vector3(0.3, 0.2, 0.05), Vector3(-0.02, 0.78, 0.05))
	for i in 3:
		var lg := add_mcyl(n, wood_mat, 0.12, 0.12, 0.7, Vector3(0.9, 0.12, -0.4 + i * 0.26))
		lg.rotation.x = PI / 2.0

func make_stall(pos: Vector3) -> void:
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	add_mbox(root, plank_mat, Vector3(4.0, 0.12, 1.2), Vector3(0, 0.9, 0))
	add_mbox(root, dark_wood_mat, Vector3(3.9, 0.8, 1.0), Vector3(0, 0.45, 0))
	for sx in [-1.95, 1.95]:
		for sz in [-0.6, 1.6]:
			add_mbox(root, dark_wood_mat, Vector3(0.14, 2.6, 0.14), Vector3(sx, 1.3, sz))
	# 줄무늬 차양
	for i in 8:
		var c := Color(0.86, 0.26, 0.24) if i % 2 == 0 else Color(0.98, 0.94, 0.84)
		var s := add_box(root, c, Vector3(0.58, 0.06, 2.6), Vector3(-2.03 + i * 0.58, 2.62, 0.5))
		s.rotation.x = -0.18
	for i in 8:
		var fc := Color(0.86, 0.26, 0.24) if i % 2 == 0 else Color(0.98, 0.94, 0.84)
		add_box(root, fc, Vector3(0.56, 0.32, 0.04), Vector3(-2.03 + i * 0.58, 2.28, 1.78))
	# 물건: 과일 바구니, 옹기, 비단 두루마리
	for i in 3:
		var bp := Vector3(-1.3 + i * 1.0, 0.96, 0.1)
		add_mcyl(root, basket_mat, 0.3, 0.22, 0.18, bp + Vector3(0, 0.09, 0))
		var fc: Color = [Color(0.98, 0.5, 0.12), Color(0.85, 0.2, 0.2), Color(0.95, 0.85, 0.3)][i]
		var fr := []
		for k in 6:
			var a := k * TAU / 6.0
			fr.append([bp + Vector3(cos(a) * 0.13, 0.22, sin(a) * 0.13), Vector3(0.16, 0.14, 0.16), fc])
		fr.append([bp + Vector3(0, 0.28, 0), Vector3(0.16, 0.14, 0.16), fc])
		add_blobs(root, fr)
	for i in 3:
		var roll := add_mcyl(root, make_color([Color(0.4, 0.6, 0.85), Color(0.95, 0.6, 0.7), Color(0.55, 0.8, 0.55)][i]), 0.1, 0.1, 0.7, Vector3(1.55, 1.06 + i * 0.0, -0.25 + i * 0.22))
		roll.rotation.x = PI / 2.0

func make_rock(pos: Vector3, size: Vector3, r: RandomNumberGenerator) -> void:
	var items := [[pos, size * Vector3(1.15, 1.0, 1.15), stone_color(r).darkened(0.05)]]
	for i in 3:
		items.append([pos + Vector3(r.randf_range(-0.3, 0.3), -size.y * 0.2, r.randf_range(-0.3, 0.3)) * size, size * r.randf_range(0.6, 0.85), stone_color(r)])
	items.append([pos + Vector3(0, size.y * 0.42, 0), Vector3(size.x * 0.7, 0.12, size.z * 0.7), Color(0.45, 0.62, 0.32)])
	add_blobs(self, items, stone_blob_mat)

# ---------- 땅, 풀, 물 질감 ----------

func make_noise_tex(c1: Color, c2: Color, freq: float, seed_v: int) -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = freq
	n.fractal_octaves = 3
	n.seed = seed_v
	var g := Gradient.new()
	g.set_color(0, c1)
	g.set_color(1, c2)
	var t := NoiseTexture2D.new()
	t.width = 256
	t.height = 256
	t.seamless = true
	t.noise = n
	t.color_ramp = g
	return t

func make_tex_material(tint: Color, tex: Texture2D, tile: float, shiny: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.albedo_texture = tex
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(tile, tile, tile)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	m.roughness = 1.0
	m.metallic_specular = shiny
	return m

func make_surface_materials() -> void:
	var tex := make_noise_tex(Color(0.8, 0.92, 0.7), Color(1.0, 1.0, 0.9), 0.012, 5)
	grass_mat = make_tex_material(Color(0.5, 0.68, 0.3), tex, 0.05)
	forest_mat = make_tex_material(Color(0.4, 0.58, 0.28), tex, 0.06)
	var sand_tex := make_noise_tex(Color(0.9, 0.85, 0.72), Color(1.0, 1.0, 0.95), 0.015, 9)
	sand_mat = make_tex_material(Color(0.78, 0.67, 0.45), sand_tex, 0.07)
	# 물: 일렁이는 무늬 + 반짝임 (_process에서 흘러가요)
	var wtex := make_noise_tex(Color(0.62, 0.8, 0.95), Color(0.95, 1.0, 1.0), 0.045, 3)
	water_mat = StandardMaterial3D.new()
	water_mat.albedo_color = Color(0.35, 0.6, 0.85)
	water_mat.albedo_texture = wtex
	water_mat.uv1_scale = Vector3(16, 1.6, 1)
	water_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	water_mat.roughness = 0.22
	water_mat.metallic_specular = 0.7
	make_village_materials()

# 바람에 살랑이는 풀 더미 (뾰족한 잎 세 개)
func make_tuft_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var blades := [[Vector2(-0.05, 0.0), 0.5, 12.0], [Vector2(0.06, 0.03), 0.38, -16.0], [Vector2(0.0, -0.05), 0.3, 6.0]]
	for b in blades:
		var o: Vector2 = b[0]
		var h: float = b[1]
		var lean := deg_to_rad(b[2])
		var base_c := Color(0.55, 0.68, 0.5)
		var tip := Vector3(o.x + sin(lean) * h * 0.5, h, o.y)
		var corners := [Vector3(o.x - 0.045, 0, o.y), Vector3(o.x + 0.045, 0, o.y), Vector3(o.x, 0, o.y + 0.045)]
		for i in 3:
			var a: Vector3 = corners[i]
			var c: Vector3 = corners[(i + 1) % 3]
			for v in [[a, base_c], [c, base_c], [tip, Color(1, 1, 1)]]:
				st.set_normal(Vector3.UP)
				st.set_color(v[1])
				st.add_vertex(v[0])
	return st.commit()

func make_grass(r: RandomNumberGenerator) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = make_tuft_mesh()
	# 풀이 나면 안 되는 곳: 길, 개울, 다리, 텃밭, 연못
	var keep_out := [
		Rect2(-3.6, -18.0, 3.4, 36.0), Rect2(-12.6, 6.5, 27.0, 3.0), Rect2(18.4, 6.5, 3.2, 15.0),
		Rect2(-40.0, -17.4, 80.0, 3.8), Rect2(-19.6, -5.8, 4.4, 3.0), Rect2(-10.2, 12.0, 3.4, 2.4),
		Rect2(30.0, -39.0, 7.0, 7.0), Rect2(9.0, -1.5, 10.0, 7.0), Rect2(-15.5, -4.2, 5.5, 4.8)] + house_rects
	var spots := []
	var tries := 0
	var grass_n := GRASS_COUNT / 2 if light_mode else GRASS_COUNT
	while spots.size() < grass_n and tries < grass_n * 4:
		tries += 1
		var p := Vector2(r.randf_range(-38, 38), r.randf_range(-38, 38))
		var ok := true
		for k in keep_out:
			if k.has_point(p):
				ok = false
				break
		if ok:
			spots.append(p)
	mm.instance_count = spots.size()
	for i in spots.size():
		var p: Vector2 = spots[i]
		var sc := r.randf_range(0.55, 1.0)
		var basis := Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3(sc, sc * r.randf_range(0.8, 1.3), sc))
		mm.set_instance_transform(i, Transform3D(basis, Vector3(p.x, 0.0, p.y)))
		mm.set_instance_color(i, Color(0.36, 0.6, 0.27).lerp(Color(0.62, 0.8, 0.34), r.randf()))
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode cull_disabled;
void vertex() {
	float h = max(VERTEX.y, 0.0);
	float ph = MODEL_MATRIX[3].x * 0.9 + MODEL_MATRIX[3].z * 0.6;
	VERTEX.x += sin(TIME * 1.7 + ph) * 0.09 * h;
	VERTEX.z += cos(TIME * 1.3 + ph) * 0.05 * h;
}
void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	# 들꽃 (작은 알록달록 점)
	var wild := []
	var palette := [Color(1.0, 0.8, 0.85), Color(1.0, 0.97, 0.8), Color(0.85, 0.8, 1.0), Color(1.0, 0.9, 0.45), Color(1, 1, 1)]
	for i in 160:
		var p: Vector2 = spots[r.randi() % spots.size()]
		wild.append([Vector3(p.x, 0.13, p.y), Vector3(0.13, 0.1, 0.13), palette[r.randi() % palette.size()]])
	var wmi := add_blobs(self, wild)
	wmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func make_tree(pos: Vector3) -> void:
	var tree := StaticBody3D.new()
	tree.position = pos
	add_child(tree)
	var pine := rng.randf() < 0.4  # 소나무
	var trunk_h := 3.4 if pine else 2.3
	var trunk := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.2
	cyl.bottom_radius = 0.38
	cyl.height = trunk_h
	cyl.radial_segments = 8
	trunk.mesh = cyl
	var bark := Color(0.52, 0.33, 0.2) if pine else Color(0.45, 0.31, 0.19)
	trunk.material_override = make_color(bark)
	trunk.position.y = trunk_h / 2.0
	if pine:
		trunk.rotation_degrees = Vector3(rng.randf_range(-4, 4), 0, rng.randf_range(-6, 6))
	tree.add_child(trunk)
	var blobs := []
	var base_y := trunk_h + 0.2
	if pine:
		# 넓적하게 층층이 퍼진 소나무 잎
		var tone := rng.randf_range(0.0, 0.06)
		for i in 4:
			var w := 3.0 - i * 0.55
			blobs.append([Vector3(rng.randf_range(-0.25, 0.25), base_y - 0.3 + i * 0.62, rng.randf_range(-0.25, 0.25)), Vector3(w, 0.95, w * 0.92), Color(0.14 + tone + i * 0.02, 0.38 + i * 0.03, 0.24)])
		blobs.append([Vector3(0.4, base_y + 0.5, 0.2), Vector3(1.5, 0.8, 1.3), Color(0.2 + tone, 0.46, 0.27)])
	else:
		var hue := rng.randf_range(0.0, 0.08)
		var spread := rng.randf_range(0.8, 1.1)
		blobs.append([Vector3(0, base_y + 0.7, 0), Vector3(2.9, 2.5, 2.9), Color(0.2 + hue, 0.5 + hue, 0.22)])
		for i in 5:
			var a := i * TAU / 5.0 + rng.randf() * 0.5
			var up := rng.randf_range(0.2, 1.4)
			blobs.append([Vector3(cos(a) * spread, base_y + up, sin(a) * spread), Vector3(rng.randf_range(1.5, 2.0), rng.randf_range(1.3, 1.7), rng.randf_range(1.5, 2.0)), Color(0.24 + hue, 0.55 + hue * 0.8, 0.25)])
		blobs.append([Vector3(rng.randf_range(-0.3, 0.3), base_y + 1.9, rng.randf_range(-0.3, 0.3)), Vector3(1.7, 1.2, 1.7), Color(0.4 + hue, 0.7, 0.3)])
	var canopy := add_blobs(tree, blobs)
	sway_items.append([canopy, canopy.position, 0, pos.x * 0.7 + pos.z * 0.5, 0.6])
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.45
	shape.height = 2.0
	col.shape = shape
	col.position.y = 1.0
	tree.add_child(col)

# ---------- 사람 만들기 (둥글둥글한 덩어리를 한 번에 그려요) ----------

# 종류(kind)마다 옷, 머리, 모자를 다르게 해요. 키는 2, 발이 -1, 정수리가 +1 쯤이에요
func person_parts(kind: String, c: Color) -> Dictionary:
	var items := []
	var outfit := []
	var skin := Color(0.99, 0.83, 0.69)
	var top := c
	var bottom := Color(0.82, 0.78, 0.66)
	var shoe := Color(0.35, 0.27, 0.2)
	var hair_c := Color(0.12, 0.09, 0.09)
	var hair := "short"
	var hat := ""
	var long_coat := false
	var skirt := false
	var mustache := false
	var beard := false
	match kind:
		"hero":
			top = Color(0.25, 0.42, 0.78)
			bottom = Color(0.3, 0.32, 0.42)
			shoe = Color(0.96, 0.96, 0.96)
		"heungbu":
			top = Color(0.84, 0.72, 0.5)
			bottom = Color(0.7, 0.62, 0.48)
			hair = "topknot"
			hat = "band"
		"nolbu":
			top = Color(0.78, 0.2, 0.22)
			long_coat = true
			hair = "topknot"
			hat = "gat"
			mustache = true
		"wife":
			top = Color(0.97, 0.82, 0.75)
			bottom = c
			skirt = true
			hair = "bun"
		"suni":
			top = Color(0.97, 0.95, 0.85)
			bottom = c
			skirt = true
			hair = "bun"
		"ong":
			top = Color(0.92, 0.9, 0.84)
			bottom = c
			skirt = true
			hair = "bun"
			hair_c = Color(0.84, 0.84, 0.88)
		"kim":
			hat = "gat"
			hair = "topknot"
		"park":
			hair = "topknot"
			hair_c = Color(0.86, 0.86, 0.9)
			beard = true
		"merchant", "woodman":
			hat = "band"
			hair = "topknot"
		"sansin":
			top = Color(0.96, 0.96, 1.0)
			long_coat = true
			hair = "topknot"
			hair_c = Color(0.95, 0.95, 0.97)
			beard = true
		"dokkaebi":
			skin = Color(0.35, 0.78, 0.72)
			top = skin
			bottom = Color(1.0, 0.72, 0.18)
			shoe = skin
			hair = "short"
			hair_c = Color(0.1, 0.1, 0.16)
	var limbs := []
	var eyes := []
	# 다리와 신발 (걸을 때 번갈아 움직여요)
	var leg_idx := {-1.0: [], 1.0: []}
	if not (long_coat or skirt):
		for sx in [-1.0, 1.0]:
			items.append([Vector3(sx * 0.17, -0.78, 0), Vector3(0.3, 0.46, 0.34), bottom])
			leg_idx[sx].append(items.size() - 1)
	for sx in [-1.0, 1.0]:
		items.append([Vector3(sx * 0.17, -0.93, 0.07), Vector3(0.32, 0.2, 0.46), shoe])
		leg_idx[sx].append(items.size() - 1)
		limbs.append({"idx": leg_idx[sx], "pivot": Vector3(sx * 0.17, -0.55, 0), "sx": sx, "arm": false})
	# 몸통
	if skirt:
		items.append([Vector3(0, -0.52, 0), Vector3(1.1, 0.9, 0.95), bottom])
		items.append([Vector3(0, -0.12, 0), Vector3(0.82, 0.56, 0.62), top])
	elif long_coat:
		var w := 1.0
		if kind == "nolbu":
			w = 1.15
		items.append([Vector3(0, -0.42, 0), Vector3(0.9 * w, 1.1, 0.8), top])
	else:
		items.append([Vector3(0, -0.28, 0), Vector3(0.86, 0.8, 0.62), top])
	outfit.append(items.size() - 1)
	# 팔과 손
	for sx in [-1.0, 1.0]:
		items.append([Vector3(sx * 0.5, -0.22, 0), Vector3(0.26, 0.58, 0.28), top, Vector3(0, 0, sx * 12.0)])
		outfit.append(items.size() - 1)
		var arm_i := items.size() - 1
		items.append([Vector3(sx * 0.57, -0.5, 0.03), Vector3(0.2, 0.2, 0.2), skin])
		limbs.append({"idx": [arm_i, items.size() - 1], "pivot": Vector3(sx * 0.5, 0.04, 0), "sx": sx, "arm": true})
	# 머리와 얼굴
	items.append([Vector3(0, 0.52, 0), Vector3(0.92, 0.88, 0.88), skin])
	for sx in [-1.0, 1.0]:
		# 크고 또랑또랑한 눈 + 반짝이는 하이라이트 + 눈썹 + 볼터치
		items.append([Vector3(sx * 0.2, 0.5, 0.395), Vector3(0.14, 0.2, 0.08), Color(0.1, 0.07, 0.07)])
		eyes.append(items.size() - 1)
		items.append([Vector3(sx * 0.2 + 0.03, 0.56, 0.43), Vector3(0.06, 0.07, 0.04), Color(1, 1, 1)])
		eyes.append(items.size() - 1)
		items.append([Vector3(sx * 0.2, 0.69, 0.365), Vector3(0.15, 0.04, 0.05), hair_c, Vector3(0, 0, -sx * 8.0)])
		items.append([Vector3(sx * 0.31, 0.37, 0.33), Vector3(0.17, 0.1, 0.06), Color(1.0, 0.6, 0.58)])
	items.append([Vector3(0, 0.3, 0.405), Vector3(0.13, 0.06, 0.05), Color(0.82, 0.3, 0.32)])
	# 머리카락
	items.append([Vector3(0, 0.62, -0.07), Vector3(0.98, 0.78, 0.92), hair_c])
	if hair == "short":
		for sx in [-1.0, 1.0]:
			items.append([Vector3(sx * 0.2, 0.8, 0.26), Vector3(0.36, 0.22, 0.28), hair_c])
	elif hair == "topknot":
		items.append([Vector3(0, 1.06, -0.02), Vector3(0.28, 0.3, 0.28), hair_c])
	elif hair == "bun":
		items.append([Vector3(0, 0.5, -0.5), Vector3(0.32, 0.32, 0.32), hair_c])
	# 모자와 수염
	if hat == "gat":
		items.append([Vector3(0, 0.98, 0), Vector3(1.35, 0.08, 1.35), Color(0.1, 0.08, 0.08)])
		items.append([Vector3(0, 1.14, 0), Vector3(0.5, 0.36, 0.5), Color(0.14, 0.11, 0.11)])
	elif hat == "band":
		for a in range(-4, 5):
			var ang := deg_to_rad(a * 20.0)
			items.append([Vector3(sin(ang) * 0.38, 0.78, cos(ang) * 0.37), Vector3(0.17, 0.1, 0.17), Color(0.94, 0.92, 0.86)])
	if mustache:
		items.append([Vector3(0, 0.4, 0.42), Vector3(0.4, 0.07, 0.06), Color(0.12, 0.09, 0.09)])
	if beard:
		items.append([Vector3(0, 0.2, 0.34), Vector3(0.4, 0.6, 0.2), hair_c])
	# 사람마다 다른 소품
	if kind == "hero":
		items.append([Vector3(0, -0.02, 0.26), Vector3(0.42, 0.2, 0.22), Color(0.97, 0.97, 0.97)])
		items.append([Vector3(-0.62, -0.45, -0.1), Vector3(0.3, 0.4, 0.36), Color(0.95, 0.8, 0.25)])
		items.append([Vector3(-0.62, -0.3, -0.1), Vector3(0.32, 0.16, 0.38), Color(0.85, 0.65, 0.15)])
	elif kind == "heungbu":
		items.append([Vector3(0.2, -0.18, 0.3), Vector3(0.2, 0.2, 0.08), Color(0.55, 0.65, 0.72)])
		items.append([Vector3(-0.22, -0.42, 0.28), Vector3(0.22, 0.22, 0.08), Color(0.78, 0.55, 0.4)])
	elif kind == "dokkaebi":
		for sx in [-1.0, 1.0]:
			items.append([Vector3(sx * 0.2, 1.0, 0.0), Vector3(0.14, 0.36, 0.14), Color(1.0, 0.9, 0.3), Vector3(0, 0, -sx * 20.0)])
			items.append([Vector3(sx * 0.08, 0.31, 0.4), Vector3(0.05, 0.1, 0.04), Color(1, 1, 1)])
		items.append([Vector3(0.72, -0.2, 0.15), Vector3(0.22, 0.9, 0.22), Color(0.5, 0.33, 0.2), Vector3(0, 0, -8.0)])
	return {"items": items, "outfit": outfit, "limbs": limbs, "eyes": eyes}

func make_person(parent: Node3D, kind: String, c: Color, solid: bool) -> Node3D:
	var data := person_parts(kind, c)
	var body := Node3D.new()
	body.position.y = 1.0
	parent.add_child(body)
	var mmi := add_blobs(body, data["items"])
	body.set_meta("mmi", mmi)
	body.set_meta("outfit", data["outfit"])
	var base := []
	for i in data["items"].size():
		base.append(mmi.multimesh.get_instance_transform(i))
	body.set_meta("base", base)
	body.set_meta("limbs", data["limbs"])
	body.set_meta("eyes", data["eyes"])
	body.set_meta("blink_at", rng.randf_range(1.0, 4.0))
	body.set_meta("blink_on", false)
	people.append(body)
	if solid:
		var col := CollisionShape3D.new()
		col.shape = CapsuleShape3D.new()
		col.position.y = 1.0
		parent.add_child(col)
	return body

# 팔다리 흔들기. swing: -1~1 (걷는 박자), arm_up: 0~1 (팔 번쩍)
func pose_person(body: Node3D, swing: float, arm_up: float) -> void:
	var mmi: MultiMeshInstance3D = body.get_meta("mmi")
	var base: Array = body.get_meta("base")
	for l in body.get_meta("limbs"):
		var sx: float = l["sx"]
		var ang := swing * 0.75 * sx
		if l["arm"]:
			ang = -swing * 0.6 * sx
			ang = lerpf(ang, -2.5, arm_up)
		var pv: Vector3 = l["pivot"]
		var rot := Transform3D(Basis(Vector3.RIGHT, ang), pv) * Transform3D(Basis.IDENTITY, -pv)
		for i in l["idx"]:
			mmi.multimesh.set_instance_transform(i, rot * base[i])

# 눈 깜빡이기
func blink_person(body: Node3D, closed: bool) -> void:
	if body.get_meta("blink_on") == closed:
		return
	body.set_meta("blink_on", closed)
	var mmi: MultiMeshInstance3D = body.get_meta("mmi")
	var base: Array = body.get_meta("base")
	for i in body.get_meta("eyes"):
		var t: Transform3D = base[i]
		if closed:
			t = Transform3D(Basis.from_scale(Vector3(1, 0.12, 1)) * t.basis, t.origin)
		mmi.multimesh.set_instance_transform(i, t)

# 옷 색 바꾸기 (한복을 사 입을 때)
func recolor_outfit(body: Node3D, c: Color) -> void:
	var mmi: MultiMeshInstance3D = body.get_meta("mmi")
	for i in body.get_meta("outfit"):
		mmi.multimesh.set_instance_color(i, c)

func make_npc(id: String, label: String, c: Color, pos: Vector3, size: float, solid: bool) -> Node3D:
	var n: Node3D
	if solid:
		n = StaticBody3D.new()
	else:
		n = Node3D.new()
	n.position = pos
	add_child(n)
	var body := make_person(n, id, c, solid)
	npc_bodies.append([body, body.position.y, pos.x * 0.9 + pos.z * 1.3])
	if label != "":
		add_tag(n, label, 2.6)
	n.scale = Vector3(size, size, size)
	npcs[id] = n
	add_thing(n, "npc", id)
	return n

func make_gourd_at(pos: Vector3, c: Color, radius: float) -> Node3D:
	var g := Node3D.new()
	g.position = pos
	add_child(g)
	make_gourd_visual(g, c, radius)
	add_tag(g, "박", radius * 2.0 + 0.7)
	g.visible = false
	return g

# ---------- 세상 만들기 ----------

func make_world() -> void:
	make_surface_materials()
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, 38, 0)
	sun.light_color = Color(1.0, 0.93, 0.8)
	sun.light_energy = 0.85
	# 부드러운 그림자 (가까운 곳만 그려서 가볍게)
	sun.shadow_enabled = SHADOWS_ON
	sun.shadow_blur = 1.6
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.0
	if light_mode:
		# 가까운 곳만 한 장으로 그림자 그리기
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
		sun.directional_shadow_max_distance = 22.0
		RenderingServer.directional_shadow_atlas_set_size(1024, true)
	else:
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		sun.directional_shadow_max_distance = 42.0
		RenderingServer.directional_shadow_atlas_set_size(2048, true)
	add_child(sun)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.36, 0.62, 0.92)
	sky_mat.sky_horizon_color = Color(0.78, 0.9, 0.97)
	sky_mat.ground_horizon_color = Color(0.6, 0.78, 0.55)
	sky_mat.ground_bottom_color = Color(0.45, 0.68, 0.42)
	sky.sky_material = sky_mat
	e.sky = sky
	# 따뜻하고 포근한 빛: 하늘 대신 부드러운 크림색으로 전체를 밝혀요
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(1.0, 0.96, 0.88)
	e.ambient_light_energy = 0.5
	# 멀리는 살짝 뿌옇게 (공기감) + 색을 조금 선명하게
	e.fog_enabled = true
	e.fog_light_color = Color(0.72, 0.84, 0.92)
	e.fog_density = 0.0018
	e.fog_sky_affect = 0.0
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = 1.05
	e.tonemap_white = 5.0
	e.adjustment_enabled = true
	e.adjustment_saturation = 1.12
	e.adjustment_contrast = 1.02
	env.environment = e
	add_child(env)

	var full := MAP_HALF * 2.0
	var none := Color(0, 0, 0, 0)
	var ground_col := add_solid(Vector3(0, -0.5, 0), Vector3(full, 1, full), Color(0.45, 0.7, 0.35))
	(ground_col.get_parent().get_child(0) as MeshInstance3D).material_override = grass_mat
	add_solid(Vector3(0, 2, -MAP_HALF), Vector3(full, 8, 1), none)
	add_solid(Vector3(0, 2, MAP_HALF), Vector3(full, 8, 1), none)
	add_solid(Vector3(-MAP_HALF, 2, 0), Vector3(1, 8, full), none)
	add_solid(Vector3(MAP_HALF, 2, 0), Vector3(1, 8, full), none)

	# 숲 바닥, 개울, 다리, 길
	add_box(self, Color(0.33, 0.58, 0.3), Vector3(full, 0.04, 23), Vector3(0, 0.02, -28.5)).material_override = forest_mat
	var creek := add_box(self, Color(0.35, 0.6, 0.85), Vector3(full, 0.06, 3), Vector3(0, 0.03, -15.5))
	creek.material_override = water_mat
	creek_mat = water_mat
	add_box(self, Color(0.55, 0.4, 0.25), Vector3(3, 0.2, 4), Vector3(-2, 0.1, -15.5)).material_override = plank_mat
	# 개울은 다리로만 건널 수 있어요 (점프로도 못 넘는 보이지 않는 벽, 다리 자리만 비워 둠)
	var creek_left_len := (-3.5) - (-MAP_HALF)
	var creek_right_len := MAP_HALF - (-0.5)
	add_solid(Vector3(-MAP_HALF + creek_left_len / 2.0, 2, -15.5), Vector3(creek_left_len, 5, 3), none)
	add_solid(Vector3(-0.5 + creek_right_len / 2.0, 2, -15.5), Vector3(creek_right_len, 5, 3), none)
	add_box(self, Color(0.8, 0.72, 0.5), Vector3(2.5, 0.04, 30), Vector3(-2, 0.02, 1)).material_override = sand_mat
	add_box(self, Color(0.8, 0.72, 0.5), Vector3(26, 0.04, 2.5), Vector3(1, 0.02, 8)).material_override = sand_mat
	add_box(self, Color(0.8, 0.72, 0.5), Vector3(2.5, 0.04, 14), Vector3(20, 0.02, 14)).material_override = sand_mat

func make_village() -> void:
	# 놀부네
	make_house(Vector3(14, 0, 2), Vector3(9, 4, 6), Color(0.95, 0.93, 0.86), Color(0.28, 0.3, 0.36), "tile")
	make_npc("nolbu", "놀부", Color(0.6, 0.2, 0.45), Vector3(14, 0, 7.5), 1.15, true)
	make_npc("wife", "놀부 마누라", Color(0.75, 0.3, 0.3), Vector3(10.5, 0, 7.8), 1.0, true)
	nolbu_gourd = make_gourd_at(Vector3(19, 0, 8.5), Color(0.6, 0.68, 0.4), 1.7)
	make_npc("dokkaebi", "도깨비", Color(0.2, 0.55, 0.6), Vector3(19, 0, 8.5), 1.3, false).visible = false

	# 흥부네
	hut = make_house(Vector3(-13, 0, -2), Vector3(4.5, 2.4, 3.5), Color(0.93, 0.89, 0.8), Color(0.8, 0.66, 0.3), "thatch")
	make_npc("heungbu", "흥부", Color(0.85, 0.6, 0.35), Vector3(-12, 0, 2.5), 1.0, true)
	make_npc("kid1", "첫째", Color(0.95, 0.75, 0.5), Vector3(-16.5, 0, 4), 0.7, true)
	make_npc("kid2", "막내", Color(0.98, 0.82, 0.6), Vector3(-9, 0, 5), 0.55, true)
	var nest := make_spot(Vector3(-16.1, 0, -3.15), "nest", "", "제비 둥지", true)
	make_nest_visual(nest)
	for pos in [Vector3(-6.5, 0, -3), Vector3(-5, 0, 0), Vector3(-6.5, 0, 3)]:
		add_thing(make_gourd_at(pos, Color(0.82, 0.9, 0.62), 1.2), "gourd", "")

	# 장터
	add_solid(Vector3(20, 1, 19.2), Vector3(4, 2, 1.2), Color(0, 0, 0, 0))
	make_stall(Vector3(20, 0, 19.2))
	make_npc("merchant", "장터 상인", Color(0.3, 0.5, 0.35), Vector3(20, 0, 21.2), 1.0, true)

	# 놀부 심술에 당한 마을 사람들
	make_npc("dori", "돌이", Color(0.9, 0.8, 0.45), Vector3(9, 0, 19), 0.6, true)
	make_npc("suni", "순이 엄마", Color(0.55, 0.65, 0.85), Vector3(-9, 0, -12), 1.0, true)
	make_npc("kim", "김 서방", Color(0.5, 0.45, 0.3), Vector3(-24, 0, 15), 1.0, true)
	make_npc("ong", "옹기 할멈", Color(0.6, 0.5, 0.55), Vector3(27, 0, -9), 0.9, true)
	make_npc("park", "박 첨지", Color(0.4, 0.5, 0.55), Vector3(-31, 0, -5), 1.0, true)
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
		add_beam(self, crack, c0, c0 + Vector3(0.12, -0.2, 0.02), 0.025, 0.02)
		add_beam(self, crack, c0 + Vector3(0.12, -0.2, 0.02), c0 + Vector3(0.02, -0.4, 0.04), 0.025, 0.02)
	make_paddy(Vector3(-34.5, 0, -3), 6.0, 6.0)
	for pos in [Vector3(-14, 0, -13.2), Vector3(-21, 0, -17.6), Vector3(5, 0, -13.2)]:
		var cloth := make_spot(pos, "laundry", "", "빨래", false)
		make_laundry_pile(cloth)

	# 품팔이 터
	var well := make_spot(Vector3(4, 0, -3), "job", "water", "우물", true)
	make_well_visual(well)
	add_solid(Vector3(4, 0.45, -3), Vector3(1.4, 0.9, 1.4), Color(0, 0, 0, 0))
	var straw := make_spot(Vector3(-17.5, 0, 8.5), "job", "shoes", "짚더미", true)
	make_haystack_visual(straw)
	add_solid(Vector3(-17.5, 0.4, 8.5), Vector3(1.6, 0.8, 1.2), Color(0, 0, 0, 0))
	var stump := make_spot(Vector3(15, 0, -19.5), "job", "wood", "나무터", true)
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
	for pos in [Vector3(14, 0, -6.5), Vector3(-31, 0, -12), Vector3(-9, 0, -36), Vector3(35, 0, 33), Vector3(-27.5, 0, 23.5), Vector3(30.8, 2.2, 5.6)]:
		var p := make_spot(pos, "piece", "", "", true)
		make_piece_visual(p)

# ---------- 마을 꾸미기 (돌담, 감나무, 장독대, 텃밭, 꽃, 징검돌, 시냇가) ----------

# 둥근 덩어리 여러 개를 한 번에 그려요. items 한 칸: [위치, 크기(가로,높이,세로), 색]
func add_blobs(parent: Node3D, items: Array, mat_in: Material = null, flat: bool = false) -> MultiMeshInstance3D:
	if items.is_empty():
		return null
	var sph := SphereMesh.new()
	sph.radius = 0.5
	sph.height = 0.25 if flat else 1.0
	sph.radial_segments = 12
	sph.rings = 6
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = sph
	mm.instance_count = items.size()
	for i in items.size():
		var sc: Vector3 = items[i][1]
		if flat:
			sc.y /= 0.25
		var basis := Basis.from_scale(sc)
		if items[i].size() > 3:
			var rd: Vector3 = items[i][3]
			basis = Basis.from_euler(Vector3(deg_to_rad(rd.x), deg_to_rad(rd.y), deg_to_rad(rd.z))) * basis
		mm.set_instance_transform(i, Transform3D(basis, items[i][0]))
		mm.set_instance_color(i, items[i][2])
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mat if mat_in == null else mat_in
	parent.add_child(mi)
	return mi

func stone_color(r: RandomNumberGenerator) -> Color:
	var v := r.randf()
	return Color(0.56 + 0.14 * v, 0.55 + 0.12 * v, 0.53 + 0.1 * v)

# 둥근 돌을 쌓은 낮은 돌담. 점프하면 넘을 수 있어요
func make_stone_wall(a: Vector2, b: Vector2, r: RandomNumberGenerator) -> void:
	var d := b - a
	var length := d.length()
	var root := StaticBody3D.new()
	root.position = Vector3((a.x + b.x) / 2.0, 0, (a.y + b.y) / 2.0)
	root.rotation.y = atan2(-d.y, d.x)
	add_child(root)
	var items := []
	var n := int(ceil(length / 0.62))
	var step := length / n
	for i in n:
		var x := -length / 2.0 + (i + 0.5) * step
		items.append([Vector3(x, 0.26, r.randf_range(-0.06, 0.06)), Vector3(step * 1.15, 0.52, 0.64), stone_color(r)])
		if i < n - 1:
			items.append([Vector3(x + step * 0.5, 0.74, r.randf_range(-0.05, 0.05)), Vector3(step * 1.1, 0.46, 0.58), stone_color(r)])
		items.append([Vector3(x, 1.06, r.randf_range(-0.04, 0.04)), Vector3(step * 0.95, 0.3, 0.5), stone_color(r)])
	add_blobs(root, items, stone_blob_mat)
	for e in [-1.0, 1.0]:
		add_mbox(root, dark_wood_mat, Vector3(0.3, 1.3, 0.3), Vector3(e * length / 2.0, 0.65, 0))
		add_mbox(root, stone_mat, Vector3(0.44, 0.16, 0.44), Vector3(e * length / 2.0, 1.38, 0))
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(length + 0.3, 1.2, 0.7)
	col.shape = shape
	col.position.y = 0.6
	root.add_child(col)

func make_jar(root: StaticBody3D, pos: Vector3, s: float, c: Color) -> void:
	var belly := add_ball(root, c, 0.5 * s, pos + Vector3(0, 0.5 * s, 0))
	belly.material_override = glossy_mat(c)
	belly.scale = Vector3(1.0, 1.08, 1.0)
	var neck := MeshInstance3D.new()
	var cy := CylinderMesh.new()
	cy.top_radius = 0.2 * s
	cy.bottom_radius = 0.3 * s
	cy.height = 0.28 * s
	neck.mesh = cy
	neck.material_override = glossy_mat(c.darkened(0.1))
	neck.position = pos + Vector3(0, 1.0 * s, 0)
	root.add_child(neck)
	add_disc(root, c.darkened(0.3), 0.3 * s, 0.07 * s, 0.3 * s, pos + Vector3(0, 1.17 * s, 0)).material_override = glossy_mat(c.darkened(0.25))
	add_ball(root, c.darkened(0.3), 0.07 * s, pos + Vector3(0, 1.23 * s, 0)).material_override = glossy_mat(c.darkened(0.3))
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.9 * s, 1.1 * s, 0.9 * s)
	col.shape = shape
	col.position = pos + Vector3(0, 0.55 * s, 0)
	root.add_child(col)

# 마을 한가운데 감나무와 돌단 위 장독대
func make_persimmon(pos: Vector3, r: RandomNumberGenerator) -> void:
	var root := StaticBody3D.new()
	root.position = pos
	add_child(root)
	add_disc(root, Color(0.72, 0.7, 0.66), 2.7, 0.22, 2.7, Vector3(0, 0.11, 0)).material_override = stone_mat
	add_disc(root, Color(0.62, 0.6, 0.56), 2.3, 0.14, 2.3, Vector3(0, 0.29, 0)).material_override = stone_mat
	var trunk := MeshInstance3D.new()
	var cy := CylinderMesh.new()
	cy.top_radius = 0.32
	cy.bottom_radius = 0.55
	cy.height = 2.8
	trunk.mesh = cy
	trunk.material_override = dark_wood_mat
	trunk.position.y = 1.5
	root.add_child(trunk)
	var tcol := CollisionShape3D.new()
	var tshape := CylinderShape3D.new()
	tshape.radius = 0.55
	tshape.height = 2.8
	tcol.shape = tshape
	tcol.position.y = 1.5
	root.add_child(tcol)
	var canopy := [[0.0, 3.7, 0.0, 1.9], [1.3, 3.3, 0.4, 1.45], [-1.3, 3.4, -0.3, 1.45], [0.1, 4.6, 0.1, 1.3], [0.4, 3.2, -1.3, 1.3], [-0.3, 3.1, 1.3, 1.3]]
	var items := []
	for c in canopy:
		var k: float = r.randf()
		items.append([Vector3(c[0], c[1], c[2]), Vector3(c[3] * 2.0, c[3] * 1.7, c[3] * 2.0), Color(0.3 + 0.08 * k, 0.6 + 0.1 * k, 0.25)])
	for i in 18:
		var c: Array = canopy[r.randi() % canopy.size()]
		var dir := Vector3(r.randf_range(-1, 1), r.randf_range(-0.3, 1), r.randf_range(-1, 1)).normalized()
		var at := Vector3(c[0], c[1], c[2]) + dir * float(c[3]) * 0.95
		items.append([at, Vector3(0.44, 0.4, 0.44), Color(0.98, 0.45 + 0.12 * r.randf(), 0.1)])
	var canopy_mi := add_blobs(root, items)
	sway_items.append([canopy_mi, Vector3.ZERO, 1, 0.5, 0.012])
	make_falling_leaves(root)
	var jars := [[-1.3, -1.2, 1.0, Color(0.46, 0.28, 0.18)], [-0.4, -1.7, 1.3, Color(0.4, 0.24, 0.16)], [0.7, -1.4, 1.1, Color(0.5, 0.3, 0.2)], [1.5, -0.6, 0.8, Color(0.44, 0.27, 0.17)], [-1.8, -0.2, 0.7, Color(0.5, 0.31, 0.2)], [1.9, -1.3, 0.6, Color(0.42, 0.26, 0.17)]]
	for j in jars:
		make_jar(root, Vector3(j[0], 0.34, j[1]), j[2], j[3])

func make_garden(pos: Vector3, w: float, d: float, r: RandomNumberGenerator) -> void:
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	var wood := Color(0.5, 0.33, 0.2)
	add_box(root, Color(0.4, 0.27, 0.18), Vector3(w, 0.14, d), Vector3(0, 0.07, 0))
	add_mbox(root, wood_mat, Vector3(w + 0.2, 0.22, 0.12), Vector3(0, 0.11, d / 2.0 + 0.06))
	add_mbox(root, wood_mat, Vector3(w + 0.2, 0.22, 0.12), Vector3(0, 0.11, -d / 2.0 - 0.06))
	add_mbox(root, wood_mat, Vector3(0.12, 0.22, d), Vector3(w / 2.0 + 0.06, 0.11, 0))
	add_mbox(root, wood_mat, Vector3(0.12, 0.22, d), Vector3(-w / 2.0 - 0.06, 0.11, 0))
	var items := []
	var nx := int(w / 0.8)
	var nz := int(d / 0.8)
	for ix in nx:
		for iz in nz:
			var x := -w / 2.0 + (ix + 0.5) * (w / nx)
			var z := -d / 2.0 + (iz + 0.5) * (d / nz)
			if (ix + iz) % 3 == 0:
				items.append([Vector3(x, 0.3, z), Vector3(0.28, 0.5, 0.28), Color(0.97, 0.96, 0.9)])
				items.append([Vector3(x, 0.55, z), Vector3(0.5, 0.3, 0.5), Color(0.3, 0.62, 0.28)])
			else:
				var k: float = r.randf()
				items.append([Vector3(x, 0.33, z), Vector3(0.62, 0.5, 0.62), Color(0.45 + 0.12 * k, 0.75, 0.38)])
	add_blobs(root, items)

func make_flowers(pos: Vector3, r: RandomNumberGenerator) -> void:
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	var petals := [Color(0.97, 0.55, 0.7), Color(0.98, 0.98, 0.95), Color(0.98, 0.85, 0.25), Color(0.85, 0.6, 0.95)]
	var pc: Color = petals[r.randi() % petals.size()]
	var items := []
	for i in 3:
		items.append([Vector3(r.randf_range(-0.3, 0.3), 0.3, r.randf_range(-0.3, 0.3)), Vector3(0.9, 0.6, 0.9), Color(0.25 + 0.1 * r.randf(), 0.55 + 0.1 * r.randf(), 0.25)])
	for i in 9:
		items.append([Vector3(r.randf_range(-0.5, 0.5), r.randf_range(0.4, 0.62), r.randf_range(-0.5, 0.5)), Vector3(0.22, 0.2, 0.22), pc if i % 4 != 0 else Color(1.0, 0.95, 0.6)])
	add_blobs(root, items)
	sway_items.append([root, Vector3.ZERO, 1, pos.x * 1.1 + pos.z, 0.05])

func make_firewood(pos: Vector3) -> void:
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	var rows := [[-0.3, 0.14], [0.0, 0.14], [0.3, 0.14], [-0.15, 0.4], [0.15, 0.4], [0.0, 0.66]]
	for row in rows:
		var log_mi := MeshInstance3D.new()
		var cy := CylinderMesh.new()
		cy.top_radius = 0.14
		cy.bottom_radius = 0.14
		cy.height = 0.95
		cy.radial_segments = 10
		log_mi.mesh = cy
		log_mi.material_override = wood_mat
		log_mi.rotation_degrees.x = 90.0
		log_mi.position = Vector3(row[0], row[1], 0)
		root.add_child(log_mi)

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
	for zb in [-14.1, -16.9]:
		var bank := []
		var x := -38.0
		while x < 38.0:
			x += r.randf_range(1.0, 1.7)
			if absf(x + 2.0) < 2.3:
				continue
			bank.append([Vector3(x, 0.08, zb + r.randf_range(-0.25, 0.25)), Vector3(r.randf_range(0.6, 1.1), r.randf_range(0.35, 0.6), r.randf_range(0.5, 0.8)), stone_color(r)])
		add_blobs(self, bank, stone_blob_mat)
	var foam := []
	for i in 22:
		foam.append([Vector3(r.randf_range(-38, 38), 0.07, r.randf_range(-16.4, -14.6)), Vector3(r.randf_range(0.6, 1.4), 0.04, 0.12), Color(0.85, 0.95, 1.0)])
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
	add_box(self, Color(0.42, 0.66, 0.38), Vector3(600, 1, 600), Vector3(0, -0.6, 0))
	var hills := []
	for i in 28:
		var ang := i * TAU / 28.0 + r.randf_range(-0.08, 0.08)
		var rad := r.randf_range(78.0, 92.0)
		var k := r.randf()
		hills.append([Vector3(cos(ang) * rad, -3.0, sin(ang) * rad), Vector3(r.randf_range(30, 46), r.randf_range(14, 24), r.randf_range(30, 46)), Color(0.42 + 0.08 * k, 0.7 - 0.06 * k, 0.45 + 0.05 * k)])
	add_blobs(self, hills)
	var far := []
	for i in 20:
		var ang := i * TAU / 20.0 + r.randf_range(-0.1, 0.1)
		var rad := r.randf_range(125.0, 145.0)
		far.append([Vector3(cos(ang) * rad, -6.0, sin(ang) * rad), Vector3(r.randf_range(50, 75), r.randf_range(34, 52), r.randf_range(40, 60)), Color(0.46, 0.64, 0.6).lerp(Color(0.55, 0.7, 0.72), r.randf())])
	var far_mi := add_blobs(self, far)
	far_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

# ---------- 살아있는 느낌 (바람, 물결, 나비, 구름, 낙엽) ----------

func make_falling_leaves(parent: Node3D) -> void:
	var p := CPUParticles3D.new()
	p.position = Vector3(0, 3.8, 0)
	p.amount = 8
	p.lifetime = 6.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 1.8
	p.direction = Vector3(0, -1, 0)
	p.spread = 25.0
	p.gravity = Vector3(0.25, -0.55, 0.1)
	p.initial_velocity_min = 0.05
	p.initial_velocity_max = 0.25
	var q := QuadMesh.new()
	q.size = Vector2(0.2, 0.2)
	var mat := make_color(Color(0.98, 0.62, 0.22))
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	q.material = mat
	p.mesh = q
	parent.add_child(p)

func make_butterflies(r: RandomNumberGenerator) -> void:
	var spots := [Vector3(-8.9, 0, 2.2), Vector3(6.4, 0, 2.6), Vector3(-4.4, 0, -7), Vector3(0.7, 0, 18), Vector3(-5.6, 0, -12.5), Vector3(21.6, 0, 2.6), Vector3(-18.6, 0, 2.4)]
	var cols := [Color(1.0, 0.9, 0.35), Color(1.0, 1.0, 1.0), Color(1.0, 0.65, 0.8), Color(0.7, 0.85, 1.0)]
	for i in spots.size():
		var root := Node3D.new()
		add_child(root)
		add_box(root, Color(0.25, 0.18, 0.12), Vector3(0.05, 0.05, 0.2), Vector3.ZERO)
		var c: Color = cols[i % cols.size()]
		var left := Node3D.new()
		var right := Node3D.new()
		root.add_child(left)
		root.add_child(right)
		add_box(left, c, Vector3(0.24, 0.02, 0.2), Vector3(-0.13, 0, 0))
		add_box(right, c, Vector3(0.24, 0.02, 0.2), Vector3(0.13, 0, 0))
		butterflies.append([root, left, right, spots[i], r.randf_range(1.2, 2.2), r.randf_range(0.5, 0.9), r.randf_range(0, TAU)])

func make_clouds(r: RandomNumberGenerator) -> void:
	for i in 10:
		var root := Node3D.new()
		var ang := r.randf_range(0, TAU)
		var rad := r.randf_range(55, 110)
		root.position = Vector3(cos(ang) * rad, r.randf_range(26, 38), sin(ang) * rad)
		add_child(root)
		var puffs := []
		for k in 5:
			puffs.append([Vector3(k * 3.2 - 6.4 + r.randf_range(-1, 1), r.randf_range(-0.6, 0.8), r.randf_range(-1.5, 1.5)), Vector3(r.randf_range(6, 9), r.randf_range(3, 4.5), r.randf_range(5, 7)), Color(1.0, 1.0, 1.0)])
		add_blobs(root, puffs)
		clouds.append([root, r.randf_range(0.5, 1.2)])

func _process(delta: float) -> void:
	anim_t += delta
	var t := anim_t
	# 바람에 살랑이는 나무와 꽃
	for it in sway_items:
		var node: Node3D = it[0]
		if not is_instance_valid(node):
			continue
		var ph: float = it[3]
		if it[2] == 0:
			node.position = it[1] + Vector3(sin(t * 1.2 + ph) * 0.07, 0, cos(t * 0.9 + ph) * 0.05)
			node.scale = Vector3(1, 1.0 + sin(t * 1.7 + ph) * 0.015, 1)
		else:
			var a: float = it[4]
			node.rotation = Vector3(cos(t * 1.1 + ph) * a * 0.7, 0, sin(t * 1.4 + ph) * a)
	# 등롱이 깜빡깜빡
	for l in lantern_mats:
		var m: StandardMaterial3D = l[0]
		m.emission_energy_multiplier = 0.6 + sin(t * 3.1 + l[1]) * 0.12 + sin(t * 7.3 + l[1] * 2.0) * 0.06
	# 사람들이 숨 쉬듯 살짝 오르내리기
	for nb in npc_bodies:
		var body: Node3D = nb[0]
		if is_instance_valid(body):
			body.position.y = nb[1] + sin(t * 2.2 + nb[2]) * 0.03
	# 눈 깜빡임과 손 살랑살랑
	for pb in people:
		if not is_instance_valid(pb):
			continue
		var next_blink: float = pb.get_meta("blink_at")
		if t >= next_blink:
			if t < next_blink + 0.13:
				blink_person(pb, true)
			else:
				blink_person(pb, false)
				pb.set_meta("blink_at", t + rng.randf_range(2.0, 5.0))
	for nb in npc_bodies:
		var nbody: Node3D = nb[0]
		if is_instance_valid(nbody):
			pose_person(nbody, sin(t * 1.6 + nb[2]) * 0.1, 0.0)
	# 시냇물 흐름
	if creek_mat != null:
		creek_mat.albedo_color = Color(0.35, 0.6, 0.85).lerp(Color(0.44, 0.7, 0.92), 0.5 + 0.5 * sin(t * 0.8))
		creek_mat.uv1_offset = Vector3(t * 0.03, sin(t * 0.5) * 0.04, 0)
	if foam_mm != null:
		for i in foam_data.size():
			var fd: Array = foam_data[i]
			var x := fposmod(fd[0] + t * 0.7 + 38.0, 76.0) - 38.0
			foam_mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(fd[2], 0.04, 0.12)), Vector3(x, 0.07, fd[1])))
	# 나비
	for b in butterflies:
		var root: Node3D = b[0]
		var c: Vector3 = b[3]
		var rad: float = b[4]
		var sp: float = b[5]
		var ang: float = t * sp + b[6]
		var nxt := ang + 0.1
		var pos := c + Vector3(cos(ang) * rad, 1.1 + sin(ang * 1.7) * 0.35, sin(ang * 0.8) * rad)
		var pos2 := c + Vector3(cos(nxt) * rad, 1.1, sin(nxt * 0.8) * rad)
		root.position = pos
		var d := pos2 - pos
		root.rotation.y = atan2(-d.x, -d.z)
		var flap := sin(t * 18.0 + b[6]) * 0.9
		(b[1] as Node3D).rotation.z = flap
		(b[2] as Node3D).rotation.z = -flap
	# 구름이 천천히 흘러가요
	for cl in clouds:
		var node: Node3D = cl[0]
		node.position.x += delta * float(cl[1])
		if node.position.x > 130.0:
			node.position.x = -130.0

func make_forest() -> void:
	var herb_spots := [Vector3(-24, 0, -25), Vector3(5, 0, -32), Vector3(27, 0, -22)]
	for pos in herb_spots:
		var h := make_spot(pos, "herb", "", "약초", false)
		make_herb_visual(h)

	# 가시덤불로 막힌 연못 (금도끼 은도끼)
	var hedge := Color(0.2, 0.4, 0.22)
	add_solid(Vector3(23, 1.1, -37.5), Vector3(1, 2.2, 4), hedge)
	add_solid(Vector3(23, 1.1, -31.25), Vector3(1, 2.2, 2.5), hedge)
	add_solid(Vector3(31.25, 1.1, -30), Vector3(17.5, 2.2, 1), hedge)
	bush_col = add_solid(Vector3(23, 1.0, -34), Vector3(1, 2.0, 3), Color(0.35, 0.45, 0.2))
	var bush: Node3D = bush_col.get_parent()
	add_tag(bush, "가시덤불", 1.6)
	add_thing(bush, "bush", "")
	var pond := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 3.2
	disc.bottom_radius = 3.2
	disc.height = 0.08
	pond.mesh = disc
	pond.material_override = water_mat
	pond.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pond.position = Vector3(33.5, 0.05, -35.5)
	add_child(pond)
	make_npc("woodman", "나무꾼", Color(0.55, 0.42, 0.3), Vector3(28, 0, -33), 1.0, true)
	make_npc("sansin", "산신령", Color(0.95, 0.95, 1.0), Vector3(31.5, 0, -35), 1.2, false).visible = false

	var keep_clear := herb_spots + [Vector3(-9, 0, -36), Vector3(-2, 0, -19), Vector3(15, 0, -19.5)]
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

func make_player() -> void:
	player = CharacterBody3D.new()
	player.position = Vector3(-2, 0, 16)
	add_child(player)
	player_body = make_person(player, "hero", Color(0.25, 0.42, 0.78), true)

# ---------- 화면 부품 ----------

func style(c: Control, scale: float = 1.0) -> void:
	c.add_theme_font_override("font", font)
	c.add_theme_font_size_override("font_size", int(font_size * scale))

func place(c: Control, l: float, t: float, r: float, b: float) -> void:
	c.set_anchor(SIDE_RIGHT, r, true, true)
	c.set_anchor(SIDE_BOTTOM, b, true, true)
	c.set_anchor(SIDE_LEFT, l, true, true)
	c.set_anchor(SIDE_TOP, t, true, true)
	c.offset_left = 0
	c.offset_top = 0
	c.offset_right = 0
	c.offset_bottom = 0

func make_paper(radius: float) -> StyleBoxFlat:
	var paper := StyleBoxFlat.new()
	paper.bg_color = Color(PAPER.r, PAPER.g, PAPER.b, 0.96)
	paper.border_color = Color(0.45, 0.3, 0.15)
	paper.set_border_width_all(4)
	paper.set_corner_radius_all(int(radius))
	paper.set_content_margin_all(radius)
	return paper

func make_round(c: Color, radius: float) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.set_corner_radius_all(int(radius))
	return s

func skin_button(b: Button, box: StyleBoxFlat, text_color: Color, scale: float) -> void:
	style(b, scale)
	for state in ["normal", "pressed", "hover", "focus"]:
		b.add_theme_stylebox_override(state, box)
	for state in ["font_color", "font_pressed_color", "font_hover_color", "font_focus_color"]:
		b.add_theme_color_override(state, text_color)

func make_overlay(alpha: float) -> ColorRect:
	var o := ColorRect.new()
	o.color = Color(0, 0, 0, alpha)
	o.visible = false
	ui_layer.add_child(o)
	place(o, 0, 0, 1, 1)
	return o

func add_label(parent: Node, text: String, scale: float, l: float, t: float, r: float, b: float) -> Label:
	var lb := Label.new()
	lb.text = text
	style(lb, scale)
	lb.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	lb.add_theme_constant_override("outline_size", 8)
	lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	parent.add_child(lb)
	place(lb, l, t, r, b)
	return lb

func add_hud_button(text: String, l: float, r: float, pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	skin_button(b, make_paper(font_size * 0.4), INK, 0.8)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 터치는 _input에서 직접 처리
	ui_layer.add_child(b)
	place(b, l, 0.83, r, 0.92)
	return b

func make_ui() -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)

	quest_label = add_label(ui_layer, "", 0.8, 0.04, 0.15, 0.96, 0.36)
	quest_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	quest_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP

	turn_button = add_hud_button("돌리기", 0.03, 0.25, on_turn)
	action_button = add_hud_button("", 0.28, 0.72, on_action)
	jump_button = add_hud_button("점프", 0.75, 0.97, on_jump)
	action_button.visible = false

	dialog_panel = PanelContainer.new()
	dialog_panel.add_theme_stylebox_override("panel", make_paper(font_size * 0.5))
	dialog_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	dialog_panel.visible = false
	dialog_panel.gui_input.connect(on_dialog_input)
	ui_layer.add_child(dialog_panel)
	place(dialog_panel, 0.04, 0.72, 0.96, 0.95)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialog_panel.add_child(vbox)
	name_label = Label.new()
	style(name_label, 0.85)
	name_label.add_theme_color_override("font_color", Color(0.7, 0.3, 0.1))
	vbox.add_child(name_label)
	text_label = Label.new()
	style(text_label)
	text_label.add_theme_color_override("font_color", INK)
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(text_label)
	options_box = VBoxContainer.new()
	options_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	options_box.visible = false
	vbox.add_child(options_box)
	next_hint = Label.new()
	next_hint.text = "다음 >"
	style(next_hint, 0.8)
	next_hint.add_theme_color_override("font_color", Color(0.7, 0.3, 0.1))
	next_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vbox.add_child(next_hint)

# ---------- 미니게임 꾸미기 (마을과 같은 따뜻한 색) ----------

# 테두리와 부드러운 그림자가 있는 둥근 모양
func make_fancy(c: Color, radius: float) -> StyleBoxFlat:
	var sb := make_round(c, radius)
	sb.set_border_width_all(5)
	sb.border_color = c.darkened(0.28)
	sb.shadow_color = Color(0, 0, 0, 0.22)
	sb.shadow_size = 8
	sb.shadow_offset = Vector2(0, 5)
	return sb

# 위치(비율)에 고정 크기의 동그라미를 놓아요
func add_dot_at(parent: Control, fx: float, fy: float, px: float, c: Color) -> Panel:
	var d := Panel.new()
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	d.add_theme_stylebox_override("panel", make_round(c, px))
	parent.add_child(d)
	place(d, fx, fy, fx, fy)
	d.offset_left = -px
	d.offset_top = -px
	d.offset_right = px
	d.offset_bottom = px
	return d

func add_deco(parent: Control, l: float, t: float, r: float, b: float, sb: StyleBox) -> Panel:
	var d := Panel.new()
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	d.add_theme_stylebox_override("panel", sb)
	parent.add_child(d)
	place(d, l, t, r, b)
	return d

func make_plaque() -> StyleBoxFlat:
	var sb := make_paper(26)
	sb.set_border_width_all(6)
	sb.border_color = Color(0.5, 0.33, 0.2)
	sb.shadow_color = Color(0, 0, 0, 0.25)
	sb.shadow_size = 8
	sb.shadow_offset = Vector2(0, 5)
	return sb

# 하늘, 해, 구름, 언덕, 풀밭, 꽃으로 된 미니게임 배경
func make_mg_back() -> void:
	mg_overlay.color = Color(0.62, 0.83, 0.96, 1.0)
	mg_overlay.clip_contents = true
	var back := Control.new()
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mg_overlay.add_child(back)
	place(back, 0, 0, 1, 1)
	mg_overlay.move_child(back, 0)
	add_deco(back, 0.8, 0.015, 0.94, 0.075, make_round(Color(1.0, 0.92, 0.55), 400))
	for cl in [[0.05, 0.02, 0.32, 0.07], [0.18, 0.045, 0.42, 0.09], [0.55, 0.05, 0.78, 0.095]]:
		add_deco(back, cl[0], cl[1], cl[2], cl[3], make_round(Color(1, 1, 1, 0.9), 400))
	add_deco(back, -0.3, 0.46, 0.6, 1.1, make_round(Color(0.6, 0.8, 0.48), 900))
	add_deco(back, 0.35, 0.4, 1.3, 1.1, make_round(Color(0.5, 0.74, 0.42), 900))
	var meadow := ColorRect.new()
	meadow.color = Color(0.56, 0.8, 0.4)
	meadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_child(meadow)
	place(meadow, 0, 0.66, 1, 1)
	var fr := RandomNumberGenerator.new()
	fr.seed = 5
	var cols := [Color(0.97, 0.55, 0.7), Color(1, 1, 0.95), Color(1.0, 0.85, 0.3)]
	for i in 22:
		add_dot_at(back, fr.randf_range(0.04, 0.96), fr.randf_range(0.69, 0.83), 9.0, cols[i % 3])
	add_deco(back, 0.03, 0.115, 0.97, 0.285, make_plaque())
	add_deco(back, 0.03, 0.85, 0.97, 0.965, make_plaque())

# 제비 얼굴: 하얀 배, 눈, 볼터치, 주황 부리
func mg_swallow_face(p: Panel, r: float) -> void:
	add_dot_at(p, 0.5, 0.74, r * 0.52, Color(0.97, 0.95, 0.9))
	for ex in [0.34, 0.66]:
		add_dot_at(p, ex, 0.38, r * 0.11, Color(0.1, 0.08, 0.08))
		add_dot_at(p, ex + 0.02, 0.35, r * 0.04, Color(1, 1, 1))
		add_dot_at(p, 0.2 if ex < 0.5 else 0.8, 0.5, r * 0.1, Color(1.0, 0.6, 0.6, 0.75))
	add_dot_at(p, 0.5, 0.5, r * 0.09, Color(1.0, 0.65, 0.2))

# 박: 위쪽에 작은 혹과 꼭지
func mg_gourd_decor(big: Panel, r: float, c: Color) -> void:
	var bulb := Panel.new()
	bulb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bulb.add_theme_stylebox_override("panel", make_fancy(c, r))
	bulb.size = Vector2(r * 1.0, r * 1.0)
	bulb.position = Vector2(r - r * 0.5, -r * 0.95)
	big.add_child(bulb)
	var stem := Panel.new()
	stem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stem.add_theme_stylebox_override("panel", make_round(Color(0.45, 0.3, 0.18), 8))
	stem.size = Vector2(r * 0.14, r * 0.3)
	stem.position = Vector2(r - r * 0.07, -r * 1.2)
	big.add_child(stem)

func mg_item_color(name: String) -> Color:
	match name:
		"밥풀": return Color(0.98, 0.97, 0.93)
		"주걱": return Color(0.82, 0.62, 0.34)
		"물": return Color(0.55, 0.8, 0.98)
		"돌": return Color(0.62, 0.62, 0.66)
		"구렁이": return Color(0.5, 0.66, 0.3)
		"장작": return Color(0.72, 0.5, 0.28)
	return Color(0.9, 0.8, 0.6)

func make_game_ui() -> void:
	mg_overlay = make_overlay(0.6)
	mg_overlay.gui_input.connect(on_mg_input)
	make_mg_back()
	mg_title = add_label(mg_overlay, "", 0.8, 0.05, 0.125, 0.95, 0.275)
	mg_title.add_theme_color_override("font_color", INK)
	mg_title.add_theme_constant_override("outline_size", 0)
	mg_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mg_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mg_bar = ProgressBar.new()
	mg_bar.show_percentage = false
	mg_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bar_bg := make_round(Color(0.5, 0.33, 0.2), 16)
	var bar_fill := make_round(Color(1.0, 0.72, 0.2), 16)
	mg_bar.add_theme_stylebox_override("background", bar_bg)
	mg_bar.add_theme_stylebox_override("fill", bar_fill)
	mg_overlay.add_child(mg_bar)
	place(mg_bar, 0.1, 0.31, 0.9, 0.34)
	mg_info = add_label(mg_overlay, "", 0.8, 0.05, 0.855, 0.95, 0.96)
	mg_info.add_theme_color_override("font_color", INK)
	mg_info.add_theme_constant_override("outline_size", 0)
	mg_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mg_info.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mg_stage = Control.new()
	mg_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mg_overlay.add_child(mg_stage)
	place(mg_stage, 0, 0, 1, 1)

# ---------- 효과 상자 ----------
# 소리는 파일 없이 코드로 만들어요. 각 줄은 [시작 음높이, 끝 음높이, 길이(초), 크기, 종류]
# 종류: 0 부드러운 음, 1 거친 음, 2 바람 소리, 3 통통한 음

func make_sounds() -> void:
	var defs := {
		"tap": [[700, 900, 0.05, 0.45, 0]],
		"blip": [[520, 520, 0.04, 0.3, 3]],
		"tick": [[900, 900, 0.025, 0.25, 0]],
		"good": [[660, 660, 0.07, 0.5, 0], [990, 990, 0.12, 0.5, 0]],
		"bad": [[180, 110, 0.22, 0.35, 1]],
		"coin": [[1320, 1320, 0.06, 0.4, 0], [1760, 1760, 0.16, 0.4, 0]],
		"pop": [[480, 1100, 0.07, 0.5, 0]],
		"saw": [[0, 0, 0.1, 0.35, 2]],
		"step": [[140, 80, 0.05, 0.3, 0]],
		"jump": [[300, 650, 0.12, 0.4, 3]],
		"land": [[160, 70, 0.09, 0.5, 0]],
		"drum": [[120, 55, 0.25, 0.8, 0]],
		"crack": [[0, 0, 0.06, 0.6, 2], [240, 60, 0.3, 0.7, 0]],
		"chirp": [[2200, 3000, 0.05, 0.3, 0], [3000, 2200, 0.05, 0.3, 0], [2400, 3200, 0.06, 0.3, 0]],
		"win": [[523, 523, 0.09, 0.5, 0], [659, 659, 0.09, 0.5, 0], [784, 784, 0.09, 0.5, 0], [1046, 1046, 0.28, 0.5, 0]],
		"fail": [[400, 300, 0.15, 0.45, 3], [300, 170, 0.32, 0.45, 3]],
	}
	for key in defs:
		sounds[key] = make_wave(defs[key])
	for i in 6:
		var sp := AudioStreamPlayer.new()
		add_child(sp)
		sound_players.append(sp)

func make_wave(parts: Array) -> AudioStreamWAV:
	var rate := 22050
	var total := 0
	for part in parts:
		var d: float = part[2]
		total += int(d * rate)
	var data := PackedByteArray()
	data.resize(total * 2)
	var at := 0
	for part in parts:
		var f0: float = part[0]
		var f1: float = part[1]
		var dur: float = part[2]
		var vol: float = part[3]
		var kind: int = part[4]
		var n := int(dur * rate)
		var phase := 0.0
		for i in n:
			var t := float(i) / n
			phase += lerpf(f0, f1, t) / rate
			var v := 0.0
			if kind == 0:
				v = sin(phase * TAU)
			elif kind == 1:
				v = 0.6 if fmod(phase, 1.0) < 0.5 else -0.6
			elif kind == 2:
				v = rng.randf_range(-1.0, 1.0)
			else:
				v = absf(fmod(phase, 1.0) * 4.0 - 2.0) - 1.0
			var env := minf(1.0, t * 20.0) * (1.0 - t)
			data.encode_s16(at, int(clampf(v * env * vol, -1.0, 1.0) * 32000.0))
			at += 2
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav

func sfx(key: String, pitch: float = 1.0) -> void:
	var sp: AudioStreamPlayer = sound_players[sound_index]
	sound_index = (sound_index + 1) % sound_players.size()
	sp.stream = sounds[key]
	sp.pitch_scale = pitch
	sp.play()

func make_fx_ui() -> void:
	fx_layer = Control.new()
	fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(fx_layer)
	place(fx_layer, 0, 0, 1, 1)
	flash_rect = ColorRect.new()
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_rect.color = Color(1, 1, 1, 0)
	fx_layer.add_child(flash_rect)
	place(flash_rect, 0, 0, 1, 1)

# 화면 흔들기 (숫자가 클수록 세게)
func shake(amount: float) -> void:
	shake_amt = maxf(shake_amt, amount)

# 화면이 잠깐 번쩍
func flash(c: Color) -> void:
	flash_rect.color = Color(c.r, c.g, c.b, 0.35)
	flash_rect.create_tween().tween_property(flash_rect, "color:a", 0.0, 0.25)

# 아주 잠깐 멈칫 (묵직한 손맛)
func hit_stop(sec: float) -> void:
	Engine.time_scale = 0.05
	get_tree().create_timer(sec, true, false, true).timeout.connect(func(): Engine.time_scale = 1.0)

# 화면 부품이 커졌다가 통 하고 돌아오기
func pop(c: Control, amount: float = 1.25) -> void:
	c.pivot_offset = c.size / 2.0
	c.scale = Vector2(amount, amount)
	c.create_tween().tween_property(c, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# 3D 물체가 통 하고 튀기 (from_zero 가 참이면 뿅 하고 나타나기)
func pop3d(n: Node3D, from_zero: bool = false) -> void:
	if not n.has_meta("base"):
		n.set_meta("base", n.scale)
	var base: Vector3 = n.get_meta("base")
	n.scale = base * (0.05 if from_zero else 1.25)
	n.create_tween().tween_property(n, "scale", base, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# 위로 떠오르며 사라지는 글자
func float_text(text: String, pos: Vector2, c: Color, scale: float = 1.0) -> void:
	var lb := Label.new()
	lb.text = text
	style(lb, scale)
	lb.add_theme_color_override("font_color", c)
	lb.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	lb.add_theme_constant_override("outline_size", 10)
	fx_layer.add_child(lb)
	lb.reset_size()
	lb.position = pos - lb.size / 2.0
	pop(lb, 1.6)
	var tw := lb.create_tween()
	tw.tween_property(lb, "position:y", lb.position.y - font_size * 1.8, 0.7)
	tw.parallel().tween_property(lb, "modulate:a", 0.0, 0.3).set_delay(0.4)
	tw.tween_callback(lb.queue_free)

# 화면에서 조각이 사방으로 튀기
func burst(pos: Vector2, c: Color, count: int = 8) -> void:
	var s := short_side * 0.016
	for i in count:
		var bit := ColorRect.new()
		bit.color = c
		bit.size = Vector2(s, s)
		bit.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fx_layer.add_child(bit)
		bit.position = pos
		var angle := rng.randf() * TAU
		var dist := short_side * rng.randf_range(0.06, 0.16)
		var target := pos + Vector2(cos(angle), sin(angle)) * dist + Vector2(0, dist * 0.5)
		var tw := bit.create_tween()
		tw.tween_property(bit, "position", target, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(bit, "modulate:a", 0.0, 0.45)
		tw.tween_callback(bit.queue_free)

# 3D 세상에서 알갱이가 튀기
func burst3d(pos: Vector3, c: Color, count: int = 14) -> void:
	var p := CPUParticles3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.09
	mesh.height = 0.18
	mesh.material = make_color(c)
	p.mesh = mesh
	p.amount = count
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = 0.6
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 2.5
	p.initial_velocity_max = 5.0
	p.gravity = Vector3(0, -12, 0)
	p.position = pos
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.5).timeout.connect(p.queue_free)

# ---------- 이야기 카드 ----------

func show_card(text: String, start_alpha: float, hold: float, done: Callable) -> void:
	in_card = true
	sfx("drum")
	card_done = done
	card_label.text = text
	card_overlay.modulate.a = start_alpha
	card_overlay.visible = true
	var tw := create_tween()
	if start_alpha < 1.0:
		tw.tween_property(card_overlay, "modulate:a", 1.0, 1.0)
	tw.tween_interval(hold)
	tw.tween_property(card_overlay, "modulate:a", 0.0, 1.0)
	tw.tween_callback(end_card)

func end_card() -> void:
	card_overlay.visible = false
	in_card = false
	if card_done.is_valid():
		card_done.call()

# ---------- 대화와 선택 ----------

func say(lines: Array, done: Callable) -> void:
	current_lines = lines
	talk_done = done
	talking = true
	line_index = 0
	last_advance_ms = Time.get_ticks_msec()
	show_line()
	dialog_panel.visible = true
	pop(dialog_panel, 1.04)

func show_line() -> void:
	name_label.text = current_lines[line_index][0]
	text_label.text = current_lines[line_index][1]
	if current_lines[line_index][0] == "제비":
		sfx("chirp")
	else:
		sfx("blip", rng.randf_range(0.9, 1.15))

func on_dialog_input(event: InputEvent) -> void:
	if (event is InputEventScreenTouch or event is InputEventMouseButton) and event.pressed:
		next_line()

func next_line() -> void:
	if asking or not talking:
		return
	var now := Time.get_ticks_msec()
	if now - last_advance_ms < 250:
		return
	last_advance_ms = now
	line_index += 1
	if line_index < current_lines.size():
		show_line()
		return
	talking = false
	dialog_panel.visible = false
	var done := talk_done
	talk_done = Callable()
	if done.is_valid():
		done.call()

func ask(who: String, text: String, options: Array, done: Callable) -> void:
	asking = true
	talking = true
	ask_done = done
	name_label.text = who
	text_label.text = text
	next_hint.visible = false
	for old in options_box.get_children():
		options_box.remove_child(old)
		old.queue_free()
	for i in options.size():
		var b := Button.new()
		b.text = options[i]
		skin_button(b, make_paper(font_size * 0.3), INK, 0.85)
		b.pressed.connect(on_option.bind(i))
		options_box.add_child(b)
	options_box.visible = true
	dialog_panel.visible = true
	sfx("blip")

func on_option(i: int) -> void:
	sfx("tap")
	asking = false
	talking = false
	options_box.visible = false
	next_hint.visible = true
	dialog_panel.visible = false
	var done := ask_done
	ask_done = Callable()
	if done.is_valid():
		done.call(i)

# ---------- 퀘스트 표시 ----------

func update_quest_text() -> void:
	var t := ""
	if quest == Q_NOLBU:
		t = "큰 기와집에 가서 여기가 어딘지 물어보기 (길 따라 오른쪽)"
	elif quest == Q_MEET:
		t = "길 건너 초가집의 흥부 만나기 (왼쪽)"
	elif quest == Q_RICE:
		t = "흥부와 함께 놀부 마누라에게 쌀 부탁하기"
	elif quest == Q_VILLAGE:
		if mischief_done >= MISCHIEF_NEED:
			t = "흥부에게 돌아가기"
		else:
			t = "놀부 심술에 당한 마을 사람 돕기 (%d/%d) | 마을 곳곳을 돌아다녀 보세요" % [mischief_done, MISCHIEF_NEED]
	elif quest == Q_SNAKE:
		t = "흥부네 처마 밑 제비 둥지 지키기"
	elif quest == Q_HERB:
		t = "개울 건너 숲에서 약초 찾기 (%d/%d)" % [herbs_found, HERB_TOTAL]
	elif quest == Q_GIVE:
		t = "흥부에게 약초 가져다주기"
	elif quest == Q_GOURD:
		t = "흥부네 마당에서 박 타기 (%d/3)" % gourds_done
	elif quest == Q_NOLBU2:
		t = "시끌시끌한 놀부네에 가 보기"
	elif quest == Q_RETURN:
		t = "흥부에게 돌아가 소식 전하기"
	elif quest == Q_END:
		t = "1장 끝! 마을을 둘러보고, 흥부에게 말을 걸면 엔딩을 다시 고를 수 있어요"
	quest_label.text = "할 일: %s\n엽전 %d냥 | 조각 %d/%d | 심술 수습 %d/5" % [t, shown_coins, pieces_found, PIECE_TOTAL, mischief_done]

func set_quest(q: int) -> void:
	quest = q
	update_quest_text()

func earn(amount: int) -> void:
	coins += amount
	sfx("coin")
	float_text("+%d냥" % amount, quest_label.position + Vector2(short_side * 0.25, quest_label.size.y * 0.75), Color(1, 0.85, 0.3), 1.2)
	update_quest_text()

# ---------- 말 걸기, 줍기 ----------

func is_busy() -> bool:
	return talking or mg_active or in_card

func is_active(t: Dictionary) -> bool:
	var node: Node3D = t["node"]
	if not node.visible:
		return false
	var kind: String = t["kind"]
	if kind == "herb":
		return quest == Q_HERB
	if kind == "gourd":
		return quest == Q_GOURD
	if kind == "nest":
		return quest == Q_SNAKE
	return true

func find_thing() -> Dictionary:
	var best: Dictionary = {}
	var best_d := REACH
	for t in things:
		if is_active(t):
			var node: Node3D = t["node"]
			var d := player.position.distance_to(node.position)
			if d < best_d:
				best_d = d
				best = t
	return best

func action_text(t: Dictionary) -> String:
	var kind: String = t["kind"]
	if kind == "herb":
		return "약초 캐기"
	if kind == "gourd":
		return "박 타기"
	if kind == "nest":
		return "둥지 지키기"
	if kind == "piece":
		return "살펴보기"
	if kind == "laundry":
		return "빨래 줍기"
	if kind == "hider":
		return "찾았다!"
	if kind == "bush":
		return "덤불 베기"
	if kind == "job":
		if t["id"] == "water":
			return "물 긷기"
		if t["id"] == "wood":
			return "나무하기"
		return "짚신 삼기"
	return "말 걸기"

func on_action() -> void:
	if current_thing.is_empty() or is_busy():
		return
	var t := current_thing
	var node: Node3D = t["node"]
	var kind: String = t["kind"]
	var above := node.position + Vector3(0, 0.6, 0)
	sfx("tap")
	if kind == "npc":
		pop3d(node)
		talk_to(t["id"])
	elif kind == "herb":
		node.visible = false
		sfx("pop")
		burst3d(above, Color(0.95, 0.4, 0.6))
		herbs_found += 1
		if herbs_found >= HERB_TOTAL:
			set_quest(Q_GIVE)
		else:
			update_quest_text()
	elif kind == "gourd":
		saw_thing = t
		start_saw()
	elif kind == "nest":
		start_snake()
	elif kind == "piece":
		node.visible = false
		sfx("good")
		burst3d(above, Color(1.0, 0.85, 0.3), 20)
		get_piece("")
	elif kind == "laundry":
		node.visible = false
		sfx("pop")
		burst3d(above, Color(1, 1, 1))
		laundry_found += 1
		say([["", "빨래를 주웠다. (%d/3)" % laundry_found]], Callable())
	elif kind == "hider":
		node.visible = false
		sfx("good")
		burst3d(above, Color(0.98, 0.85, 0.65))
		hiders_found += 1
		say([["동생", "앗, 들켰다! 헤헤. (%d/4)" % hiders_found]], Callable())
	elif kind == "bush":
		if has_sickle:
			node.visible = false
			sfx("saw")
			shake(8)
			burst3d(above, Color(0.3, 0.5, 0.2), 24)
			bush_col.set_deferred("disabled", true)
			say([["", "낫으로 가시덤불을 베어 냈다. 안쪽에서 울음소리가 들린다..."]], Callable())
		else:
			say([["", "가시덤불이 길을 막고 있다. 낫이 있으면 벨 수 있겠다. (장터에서 팔아요)"]], Callable())
	elif kind == "job":
		start_job(t["id"])

func get_piece(extra: String) -> void:
	pieces_found += 1
	update_quest_text()
	var found := [["이야기 조각 %d/%d" % [pieces_found, PIECE_TOTAL], proverbs[pieces_found - 1]]]
	if extra != "":
		found.insert(0, ["", extra])
	if pieces_found >= PIECE_TOTAL:
		found.append(["이야기 조각", "조각을 모두 모았어요! 책 귀퉁이에 속담 일곱 줄이 새겨졌습니다."])
	say(found, Callable())

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
			say([["막내", "쌀밥 세 그릇이나 먹었어! 배가 뽈록해."]], Callable())
		else:
			say([["막내", "배고파... 그래도 제비가 빨리 나았으면 좋겠어."]], Callable())
	elif id == "dokkaebi":
		say([["도깨비", "껄껄, 책 밖에서 온 아이로구나. 너는 착하니 겁낼 것 없다."]], Callable())
	elif id == "merchant":
		shop()
	elif id == "woodman":
		talk_woodman()
	elif id == "sansin":
		say([["산신령", "정직한 마음을 잊지 말거라. 그것이 금도끼보다 귀하니라."]], Callable())
	else:
		talk_villager(id)

# ---------- 놀부네 ----------

func talk_nolbu() -> void:
	if quest == Q_NOLBU:
		say([
			["놀부", "뭐냐, 웬 꼬마가 남의 집 앞에서 얼쩡거려?"],
			["놀부", "옷차림은 또 그게 뭐냐? 저고리도 아니고, 신발은 왜 그 모양이야?"],
			["놀부", "길을 잃었다고? 내 알 바 아니다! 책 속에서 왔다니, 별 실없는 소리를 다 듣겠네."],
			["놀부", "밥? 흥! 물 한 모금도 아깝다. 길 건너 내 아우 흥부한테나 가 보든지."],
		], func(): set_quest(Q_MEET))
	elif quest == Q_NOLBU2:
		say([
			["놀부", "흥부 놈이 제비 덕에 부자가 됐다지? 그깟 거 나도 한다!"],
			["놀부", "그래서 내가 제비 다리를 똑 부러뜨린 다음 고쳐 줬지. 으하하!"],
			["놀부", "자, 봐라. 내 박은 흥부네 것보다 훨씬 크지? 슬근슬근 톱질하세..."],
			["놀부", "어? 어어? 박 속에서 뭐가 나온다!"],
		], after_nolbu_boast)
	elif quest >= Q_RETURN:
		if helped_nolbu:
			say([["놀부", "네가 내 편을 들어 주다니... 박대해서 미안했다, 얘야. 이제 심술은 안 부리마."]], Callable())
		else:
			say([["놀부", "내가 욕심이 과했다... 다 내 탓이지, 누굴 원망하겠느냐."]], Callable())
	else:
		say([["놀부", "아직도 안 갔느냐? 내 마당 흙 닳는다, 썩 가거라!"]], Callable())

func talk_wife() -> void:
	if quest == Q_RICE:
		say([
			["흥부", "형수님, 아이들이 굶고 있습니다. 쌀 한 되만 꾸어 주십시오."],
			["놀부 마누라", "뭐야? 남 줄 쌀이 어디 있어! 이 밥주걱 맛이나 봐라!"],
			["흥부", "아이고! ...어? 뺨에 밥풀이 붙었네. 형수님, 이쪽 뺨도 마저 때려 주십시오!"],
			["흥부", "얘야, 바가지를 들고 튀는 밥풀을 받아 다오. 주걱은 피하고!"],
		], start_rice)
	elif quest >= Q_RETURN:
		say([["놀부 마누라", "아이고, 내 팔자야... 주걱으로 때린 벌을 받나 보다."]], Callable())
	else:
		say([["놀부 마누라", "뭘 봐? 우리 집엔 남 줄 쌀 한 톨 없어!"]], Callable())

func start_rice() -> void:
	start_game("catch", {"title": "놀부 마누라의 밥주걱은 피하고\n튀는 밥풀만 바가지로 받으세요", "goal": 12, "interval": 0.6, "speed": 0.42, "bad_ratio": 0.35, "good": "밥풀", "bad": "주걱", "basket": "바가지"}, rice_done)

func rice_done(ok: bool, _good: bool) -> void:
	if not ok:
		say([["흥부", "아이쿠, 주걱에 너무 많이 맞았다... 형수님께 다시 부탁해 보자꾸나."]], Callable())
		return
	var heungbu: Node3D = npcs["heungbu"]
	heungbu.position = Vector3(-12, 0, 2.5)
	say([
		["흥부", "허허, 밥풀이 한 줌은 되는구나. 아이들 죽이라도 끓여 주겠다."],
		["놀부 마누라", "저, 저런 못난이들! 썩 꺼져!"],
		["흥부", "나는 품을 팔러 가야겠다. 형님 심술에 마을 사람들이 고생이 많은데, 네가 좀 도와주겠느냐?"],
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
		["도깨비", "이놈 놀부야! 멀쩡한 제비 다리를 일부러 부러뜨려?"],
		["놀부", "아이고, 도깨비님! 잘못했습니다, 살려 주십시오!"],
		["도깨비", "욕심으로 얻은 재물은 내가 몽땅 가져가마. 뚝딱!"],
		["놀부", "아이고, 내 재산... 내 기와집... 흑흑."],
	], func(): ask("놀부", "얘야... 염치없다만, 흥부한테 내 얘기 좀 잘 해 주겠느냐?", ["도와준다", "모른 척한다"], on_nolbu_choice))

func on_nolbu_choice(i: int) -> void:
	helped_nolbu = i == 0
	if helped_nolbu:
		say([["놀부", "고, 고맙다... 박대한 나를 도와주다니. 내가 부끄럽구나."]], func(): set_quest(Q_RETURN))
	else:
		say([["놀부", "그래, 내가 한 짓이 있는데 무슨 낯으로... 흑흑."]], func(): set_quest(Q_RETURN))

# ---------- 흥부네 ----------

func talk_heungbu() -> void:
	if quest == Q_NOLBU:
		say([["흥부", "어서 오너라. 처음 보는 옷이로구나. 길을 잃었으면 저기 큰 기와집 형님께 먼저 여쭤 보렴."]], Callable())
	elif quest == Q_MEET:
		say([
			["흥부", "아이고, 형님 댁에서 그냥 쫓겨났다고? 저런, 많이 놀랐겠구나."],
			["흥부", "옛이야기 책을 펼쳤더니 여기였다고? 허허, 신기한 일도 다 있구나. 그 책 좀 보자."],
			["흥부", "이런, 책장이 텅 비었구나. 이야기가 채워져야 돌아갈 길이 열리려나 보다."],
			["흥부", "밥이라도 먹이고 싶다만... 실은 쌀이 똑 떨어졌단다."],
			["흥부", "형님 댁에 쌀을 꾸러 가려던 참인데, 같이 가 주겠느냐?"],
		], after_meet)
	elif quest == Q_RICE:
		say([["흥부", "형수님께 같이 부탁드려 보자꾸나. 바로 옆에 계신다."]], Callable())
	elif quest == Q_VILLAGE:
		if mischief_done >= MISCHIEF_NEED:
			say([
				["흥부", "마을 사람들을 도와줬다고? 장하구나!"],
				["흥부", "그런데 큰일이다! 처마 밑 제비 둥지에 구렁이가 나타났어!"],
			], func(): set_quest(Q_SNAKE))
		else:
			say([["흥부", "형님 심술에 당한 사람이 마을에 다섯이나 된단다. 셋만 도와줘도 큰 힘이 될 게다."]], Callable())
	elif quest == Q_SNAKE:
		say([["흥부", "어서 둥지를 지켜 다오! 우리 집 처마 밑이다."]], Callable())
	elif quest == Q_HERB:
		say([["흥부", "약초는 개울 건너 뒷산 숲에 있단다. 나무 사이를 잘 살펴보렴."]], Callable())
	elif quest == Q_GIVE:
		say([
			["흥부", "오오, 세 포기나! 정말 고맙구나."],
			["흥부", "약초를 바르고 실로 다리를 감아 줘야 한단다."],
			["흥부", "내 손은 거칠어서... 네가 살살 감아 주겠느냐?"],
		], start_heal)
	elif quest == Q_GOURD:
		say([["흥부", "박은 마당에 있단다. 하나씩 같이 타 보자꾸나."]], Callable())
	elif quest == Q_NOLBU2:
		say([["흥부", "형님 댁이 시끌시끌하구나. 무슨 일인지 가 보겠느냐?"]], Callable())
	elif quest == Q_RETURN:
		var lines := [["흥부", "형님이 도깨비한테 혼쭐이 나셨다고? 저런..."]]
		if helped_nolbu:
			lines.append(["흥부", "네가 형님 편을 들어 주었구나. 고맙다. 우리 새 집에서 함께 지내시라 해야겠다."])
		else:
			lines.append(["흥부", "미워도 내 형님이다. 우리 새 집에서 함께 지내시라 해야겠구나."])
		lines.append(["흥부", "얘야, 네 책 좀 보렴. 빈 책장에 우리 이야기가 거의 채워졌구나. 마지막 한 줄만 비어 있다."])
		lines.append(["흥부", "그 한 줄은 네가 정해 다오. 네 덕에 제비도 살고 우리 식구도 살았으니."])
		say(lines, ask_final)
	else:
		ask("흥부", "집으로 돌아가는 길, 꼭 찾기를 바란다. 이야기의 마지막 한 줄을 다시 고르겠느냐?", ["다시 고를래요", "이대로 둘래요"], on_replay_choice)

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
		say([["첫째", "그 옷 어디서 났어? 처음 봐! 참, 심심한데 숨바꼭질 하자."], ["첫째", "동생 넷이 마을 어딘가에 숨었어. 다 찾으면 내 보물을 줄게!"]], Callable())
	elif hide_state == 1:
		if hiders_found >= 4:
			hide_state = 2
			earn(20)
			say([["첫째", "벌써 다 찾았어? 대단하다! 약속한 보물이야."], ["", "엽전 20냥을 받았다!"]], Callable())
		else:
			say([["첫째", "아직 %d명 남았어. 집 뒤, 나무 뒤, 다리 밑을 잘 봐!" % (4 - hiders_found)]], Callable())
	elif gourds_done >= 2:
		say([["첫째", "나도 새 옷 입었어! 다음엔 어느 이야기로 가? 나도 따라가고 싶다."]], Callable())
	else:
		say([["첫째", "우리 아버지는 세상에서 제일 착해. 가난해도 제비까지 돌봐 준다니까!"]], Callable())

# 구렁이 쫓기
func start_snake() -> void:
	start_game("tap", {"title": "구렁이가 제비 둥지로 기어와요!\n닿기 전에 눌러서 쫓아내세요", "goal": 12, "interval": 0.75, "life": 1.6, "target": "구렁이", "center": "둥지", "color": Color(0.5, 0.38, 0.25)}, snake_done)

func snake_done(ok: bool, _good: bool) -> void:
	if not ok:
		say([["흥부", "구렁이가 둥지에 닿았다! 얼른 다시 쫓아 다오!"]], Callable())
		return
	for t in things:
		if t["kind"] == "herb":
			var node: Node3D = t["node"]
			node.visible = true
	say([
		["", "구렁이는 달아났지만, 놀란 새끼 제비 한 마리가 떨어져 다리를 다쳤다."],
		["흥부", "저런, 가엾어라! 뒷산 숲에서 약초를 세 포기만 구해다 주겠느냐? 분홍빛 나는 풀이란다."],
	], func(): set_quest(Q_HERB))

# 제비 치료
func start_heal() -> void:
	start_game("circle", {"title": "제비 둘레를 손가락으로 천천히\n빙글빙글 돌려 실을 감아 주세요", "label": "제비", "turns": 6.0, "max_speed": 11.0, "warn": "너무 빨라요! 제비가 아파해요", "color": Color(0.2, 0.22, 0.35)}, heal_done)

func heal_done(ok: bool, good: bool) -> void:
	if not ok:
		say([["흥부", "제비가 놀라서 푸드덕거리는구나. 숨을 고르고 다시 살살 감아 보자."]], start_heal)
		return
	var lines := [["제비", "짹짹!"]]
	if good:
		lines.append(["흥부", "허허, 아주 꼼꼼하게 감았구나. 제비가 하나도 안 아파하는구나."])
	else:
		lines.append(["흥부", "조금 놀랐나 보다만, 그래도 잘 감아 주었구나."])
	lines.append(["흥부", "어라, 네 책에 제비 그림이 생겼구나! 이야기가 채워지고 있나 보다."])
	lines.append(["흥부", "다 나으면 강남으로 날아가겠지. 고맙다, 얘야."])
	say(lines, after_heal_talk)

func after_heal_talk() -> void:
	set_quest(Q_SEASON)
	show_card("제비는 따뜻한 강남으로 날아갔어요.\n\n계절이 바뀌고,\n이듬해 봄...", 0.0, 3.0, after_season)

func after_season() -> void:
	set_quest(Q_SEED)
	say([
		["제비", "짹짹! 짹짹!"],
		["흥부", "아니, 작년 그 제비가 아니냐! 입에 문 건... 박씨로구나."],
		["흥부", "마당에 심었더니 어느새 커다란 박이 세 통이나 열렸단다."],
		["흥부", "얘야, 나와 같이 박을 타 보지 않겠느냐? 박자가 너무 어긋나면 톱이 끼니 조심하고."],
	], after_seed)

func after_seed() -> void:
	for t in things:
		if t["kind"] == "gourd":
			var node: Node3D = t["node"]
			node.visible = true
	set_quest(Q_GOURD)

# 박 타기
func start_saw() -> void:
	start_game("follow", {"title": "슬근슬근 톱질하세! (%d번째 박)\n갈색 톱을 손가락으로 따라가세요" % (gourds_done + 1), "slow": 2.4 - gourds_done * 0.35, "tol": 0.42 - gourds_done * 0.04, "goal": 6.0, "patience": 4.0 - gourds_done * 0.5, "color": Color(0.82, 0.9, 0.62)}, saw_done)

func saw_done(ok: bool, _good: bool) -> void:
	if not ok:
		say([["흥부", "아이쿠, 박자가 어긋나 톱이 박에 끼었구나. 숨 한번 돌리고 다시 타 보자."]], Callable())
		return
	var g: Node3D = saw_thing["node"]
	g.visible = false
	sfx("crack")
	shake(22)
	hit_stop(0.08)
	flash(Color(1, 1, 1))
	burst3d(g.position + Vector3(0, 1.2, 0), PAPER, 30)
	spawn_treasure(gourds_done, g.position)
	var all_lines := [
		[
			["흥부", "아이고, 쌀이다! 하얀 쌀이 끝도 없이 쏟아지는구나!"],
			["막내", "쌀밥이다! 아버지, 오늘은 배불리 먹어요?"],
			["흥부", "그럼, 그럼. 네 몫으로 엽전도 나왔구나. 자, 다음 박도 타 보자."],
		],
		[
			["흥부", "이번엔 비단이로구나! 고운 비단이 필필이 나온다!"],
			["첫째", "우와, 우리도 새 옷 입는 거예요?"],
			["흥부", "허허, 마지막 박이 남았구나. 톱질이 점점 빨라지니 잘 따라오너라."],
		],
		[
			["흥부", "아니, 이번엔 목수들이 우르르 나오는구나!"],
			["흥부", "뚝딱뚝딱, 눈 깜짝할 사이에 새 집을 지어 주었구나!"],
			["흥부", "착한 일을 하면 복이 온다더니... 이 은혜는 잊지 않으마."],
			["흥부", "그런데 형님 댁이 왜 저리 시끄러울꼬? 한번 가 보겠느냐?"],
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
		add_tag(pile, "쌀", 2.0)
	elif order == 1:
		spawn_silk(pile)
		add_tag(pile, "비단", 2.0)
	else:
		spawn_gold(pile)
		add_tag(pile, "금은보화", 1.6)
		hut.visible = false
		pop3d(make_house(hut.position, Vector3(7, 3.4, 4.5), Color(0.96, 0.94, 0.88), Color(0.2, 0.35, 0.5), "tile"), true)
	pop3d(pile, true)

# ---------- 1장 엔딩 ----------

func ask_final() -> void:
	var opts := ["형님도 우리 집에서 함께 지내요", "형님은 벌 받은 대로 두어요"]
	if coins >= RICH_COINS:
		opts.append("보물로 땅을 더 사서 불려요")
	ask("흥부", "이야기의 마지막 한 줄이다. 형님을 어찌하면 좋을꼬?", opts, on_final_choice)

func on_replay_choice(i: int) -> void:
	if i == 0:
		say([["흥부", "그래, 마지막 한 줄은 몇 번이고 다시 쓸 수 있지."]], ask_final)

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
			return ["함께 사는 집", "놀부는 마을 사람들을 하나하나 찾아가 고개를 숙였어요.\n처음엔 닫혀 있던 대문들이 하나둘 열렸고,\n흥부네 처마 밑 제비집은 둘로 늘었답니다.\n\n책의 첫 장이 환하게 채워졌어요."]
		"awkward":
			return ["아직은 어색한 화해", "흥부는 형님을 새 집에 모셨어요.\n하지만 놀부에게 상처받은 마을 사람들은\n아직 대문을 활짝 열지 못했어요.\n\n용서는 한 사람만의 일이라서\n시간이 더 필요한가 봐요.\n\n책의 첫 장이 반쯤 채워졌어요."]
		"greed":
			return ["작은 놀부", "보물로 땅을 사고 또 사던 흥부네 대문은\n해마다 높아지고 굳게 닫혔어요.\n처마 밑 제비는 다른 집으로 떠났고,\n마을 사람들은 흥부를 '작은 놀부'라 불렀어요.\n\n책장의 글씨가 흐릿하게 번졌어요.\n욕심은 누구의 마음에든 찾아오나 봐요."]
	return ["권선징악", "놀부는 도깨비에게 모든 것을 잃고\n흥부네 담장 밖을 오래 서성였어요.\n\n착한 마음에는 복이, 욕심에는 화가 따른다지만\n담장 밖 뒷모습이 자꾸 마음에 걸렸어요.\n\n책의 첫 장이 채워졌어요."]

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
	show_card("%s\n\n엔딩 “%s” (모은 엔딩 %d/%d)\n1장 흥부와 놀부  끝" % [d[1], d[0], seen, ENDING_COUNT], 0.0, 5.0, Callable())

# ---------- 마을 사람 돕기 ----------

func talk_villager(id: String) -> void:
	var v: Dictionary = villagers[id]
	var who: String = v["name"]
	var state: int = mischief.get(id, 0)
	if state == 2:
		say([[who, "네 덕에 한시름 놓았다. 고맙다!"]], Callable())
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
	if ok:
		finish_mischief(id)
	else:
		say([[v["name"], v["fail"]]], Callable())

func finish_mischief(id: String) -> void:
	var v: Dictionary = villagers[id]
	mischief[id] = 2
	mischief_done += 1
	earn(10)
	say([[v["name"], v["done"]], ["", "엽전 10냥을 받았다! (놀부 심술 수습 %d/5)" % mischief_done]], Callable())

# ---------- 품팔이와 장터 ----------

func start_job(id: String) -> void:
	if id == "water":
		start_game("catch", {"title": "두레박으로 물방울만 받으세요\n돌멩이는 피해요", "goal": 10, "interval": 0.55, "speed": 0.5, "bad_ratio": 0.3, "good": "물", "bad": "돌", "basket": "두레박"}, job_done)
	elif id == "wood":
		start_game("tap", {"title": "장작이 보이면\n사라지기 전에 눌러 패세요", "goal": 10, "interval": 0.7, "life": 1.3, "target": "장작", "center": "나무", "color": Color(0.5, 0.35, 0.2)}, job_done)
	else:
		start_game("circle", {"title": "짚을 빙글빙글 꼬아 짚신을 삼아요\n너무 빠르면 짚이 끊어져요", "label": "짚신", "turns": 5.0, "max_speed": 12.0, "warn": "짚이 끊어질 것 같아요!", "color": Color(0.8, 0.68, 0.35)}, job_done)

func job_done(ok: bool, good: bool) -> void:
	if not ok:
		say([["", "일을 망쳐서 품삯을 받지 못했다. 다시 해 보자."]], Callable())
		return
	var pay := 10
	if good:
		pay = 15
	earn(pay)
	if good:
		say([["", "솜씨가 좋다고 덤까지 받았다. 엽전 %d냥!" % pay]], Callable())
	else:
		say([["", "품삯으로 엽전 %d냥을 받았다." % pay]], Callable())

func shop() -> void:
	ask("장터 상인", "어서 오너라! 무엇을 줄까? (가진 엽전 %d냥)" % coins, ["엿 5냥", "짚신 20냥 (발이 빨라져요)", "낫 15냥 (덤불을 베요)", "한복 40냥 (옷 갈아입기)", "그만 볼래요"], on_shop)

func on_shop(i: int) -> void:
	if i >= 4:
		return
	var prices := [5, 20, 15, 40]
	var owned := (i == 0 and has_yeot) or (i == 1 and has_shoes) or (i == 2 and has_sickle) or (i == 3 and has_hanbok)
	if owned:
		say([["장터 상인", "그건 이미 가지고 있잖니."]], shop)
		return
	if coins < prices[i]:
		say([["장터 상인", "엽전이 모자라는구나. 우물, 나무터, 짚더미에서 품을 팔면 엽전을 벌 수 있단다."]], Callable())
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
	say([["장터 상인", "옜다, 잘 쓰거라!"]], shop)

# ---------- 숨은 이야기: 금도끼 은도끼 ----------

func talk_woodman() -> void:
	if axe_done:
		say([["나무꾼", "네 정직함 덕분에 어머니를 잘 모시게 됐어. 고마워!"]], Callable())
		return
	var sansin: Node3D = npcs["sansin"]
	sansin.visible = true
	pop3d(sansin, true)
	burst3d(sansin.position + Vector3(0, 1, 0), Color(0.6, 0.8, 1.0), 20)
	say([
		["나무꾼", "엉엉... 하나뿐인 쇠도끼를 연못에 빠뜨렸어. 나무를 해야 어머니를 모시는데..."],
		["산신령", "어흠. 나는 이 연못의 산신령이니라."],
		["산신령", "책 밖에서 온 아이야, 네가 대신 답해 보아라."],
	], func(): ask("산신령", "이 번쩍이는 금도끼가 저 나무꾼의 도끼냐?", ["아니에요", "맞아요"], on_axe_gold))

func on_axe_gold(i: int) -> void:
	if i == 1:
		axe_lie()
	else:
		ask("산신령", "그러면 이 은도끼가 나무꾼의 도끼냐?", ["맞아요", "아니에요"], on_axe_silver)

func on_axe_silver(i: int) -> void:
	if i == 0:
		axe_lie()
		return
	axe_done = true
	earn(30)
	say([
		["산신령", "참으로 정직하구나! 쇠도끼는 물론이고, 금도끼와 은도끼도 모두 주마."],
		["나무꾼", "고맙다, 얘야! 네 덕분이야. 이건 내 마음이니 받아 줘."],
		["", "엽전 30냥을 받았다!"],
	], func(): get_piece("산신령이 책에 이야기 한 조각을 새겨 주었다."))

func axe_lie() -> void:
	axe_lied = true
	var sansin: Node3D = npcs["sansin"]
	sansin.visible = false
	sfx("bad")
	shake(8)
	say([
		["산신령", "허허, 거짓을 말하는구나. 정직하지 못한 자에겐 아무것도 줄 수 없다."],
		["", "산신령이 연못 속으로 사라졌다. 나무꾼에게 다시 말을 걸어 보자."],
	], Callable())

# ---------- 미니게임 공통 ----------

func start_game(type: String, cfg: Dictionary, done: Callable) -> void:
	mg_type = type
	mg_cfg = cfg
	mg_done = done
	mg_progress = 0.0
	mg_lives = 3
	mg_perfect = true
	mg_count = 0
	mg_timer = 0.5
	mg_touch = false
	mg_started = false
	mg_phase = 0.0
	mg_off = 0.0
	mg_frame_angle = 0.0
	mg_speed = 0.0
	mg_has_last = false
	mg_warn_time = 0.0
	mg_items = []
	mg_step = 0
	mg_trail = 0.0
	mg_dir = 1.0
	sfx("drum")
	mg_title.text = cfg["title"]
	mg_info.text = ""
	mg_bar.value = 0
	mg_overlay.visible = true
	mg_pos = mg_overlay.size / 2.0
	var w := mg_overlay.size.x
	var h := mg_overlay.size.y
	var c: Color = cfg.get("color", PAPER)
	if type == "circle":
		if cfg["label"] == "제비":
			mg_big = mg_dot(c, mg_r, "")
			mg_swallow_face(mg_big, mg_r)
		else:
			mg_big = mg_dot(c, mg_r, cfg["label"])
		mg_move(mg_big, w * 0.5, h * 0.6)
		mg_a = mg_dot(PAPER, font_size * 0.45, "")
		mg_a.visible = false
	elif type == "follow":
		var big := mg_dot(c, mg_r, "")
		mg_big = big
		mg_move(big, w * 0.5, h * 0.6)
		mg_gourd_decor(big, mg_r, c)
		mg_c = ColorRect.new()
		mg_c.color = Color(0.25, 0.18, 0.1)
		mg_c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		big.add_child(mg_c)
		place(mg_c, 0.5, 0, 0.5, 0)
		mg_c.offset_left = -5
		mg_c.offset_right = 5
		var track := Panel.new()
		track.add_theme_stylebox_override("panel", make_round(Color(0.62, 0.45, 0.28), 8))
		track.mouse_filter = Control.MOUSE_FILTER_IGNORE
		track.size = Vector2(w * 0.8, 14)
		track.position = Vector2(w * 0.1, h * 0.78 - 7)
		mg_stage.add_child(track)
		mg_a = mg_dot(Color(0.6, 0.38, 0.16), short_side * 0.06, "")
		mg_b = mg_dot(PAPER, short_side * 0.042, "")
	elif type == "catch":
		mg_a = mg_dot(Color(0.78, 0.58, 0.32), short_side * 0.09, cfg["basket"])
	elif type == "tap":
		mg_big = mg_dot(c, mg_r * 0.8, cfg["center"])
		mg_move(mg_big, w * 0.5, h * 0.62)
	mg_active = true
	pop(mg_title, 1.15)

func end_game(ok: bool) -> void:
	mg_active = false
	mg_overlay.visible = false
	mg_items = []
	for child in mg_stage.get_children():
		child.queue_free()
	var mid := mg_overlay.size / 2.0
	if ok:
		sfx("win")
		float_text("성공!", mid, Color(1, 0.9, 0.4), 2.0)
		burst(mid, Color(1, 0.85, 0.3), 18)
	else:
		sfx("fail")
		shake(16)
		float_text("아이쿠!", mid, Color(1, 0.55, 0.45), 2.0)
	var done := mg_done
	mg_done = Callable()
	if done.is_valid():
		done.call(ok, mg_perfect)

func mg_dot(c: Color, r: float, text: String) -> Panel:
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", make_fancy(c, r))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size = Vector2(r * 2.0, r * 2.0)
	mg_stage.add_child(p)
	if text != "":
		add_label(p, text, 0.7, 0, 0, 1, 1)
	return p

func mg_move(p: Control, x: float, y: float) -> void:
	p.position = Vector2(x, y) - p.size / 2.0

func on_mg_input(event: InputEvent) -> void:
	if not mg_active:
		return
	var is_button: bool = event is InputEventScreenTouch or event is InputEventMouseButton
	var is_move: bool = event is InputEventScreenDrag or (event is InputEventMouseMotion and event.button_mask != 0)
	if is_button and not event.pressed:
		mg_touch = false
		return
	if not (is_button or is_move):
		return
	mg_touch = true
	mg_started = true
	mg_pos = event.position
	if mg_type == "circle":
		if is_button:
			mg_has_last = false
		var center := Vector2(mg_overlay.size.x * 0.5, mg_overlay.size.y * 0.6)
		var offset: Vector2 = mg_pos - center
		mg_move(mg_a, mg_pos.x, mg_pos.y)
		mg_a.visible = true
		if offset.length() < mg_r * 0.5:
			mg_has_last = false
			return
		var a := offset.angle()
		if mg_has_last:
			var turned := absf(wrapf(a - mg_last_angle, -PI, PI))
			mg_frame_angle += turned
			mg_trail += turned
			if mg_trail > 0.3:
				# 손가락이 지나간 자리에 실 자국 남기기
				mg_trail = 0.0
				var mark := mg_dot(PAPER, font_size * 0.18, "")
				mg_move(mark, mg_pos.x, mg_pos.y)
				var tw := mark.create_tween()
				tw.tween_property(mark, "modulate:a", 0.0, 1.2)
				tw.tween_callback(mark.queue_free)
		mg_last_angle = a
		mg_has_last = true

func update_game(delta: float) -> void:
	if mg_type == "circle":
		update_circle(delta)
	elif mg_type == "follow":
		update_follow(delta)
	elif mg_type == "catch":
		update_catch(delta)
	else:
		update_tap(delta)
	mg_bar.value = mg_progress * 100.0
	if mg_lives <= 0:
		end_game(false)
	elif mg_progress >= 1.0:
		end_game(true)

# 빙글빙글 돌리기: 너무 빠르면 기회가 줄어요
func update_circle(delta: float) -> void:
	var max_speed: float = mg_cfg["max_speed"]
	var turns: float = mg_cfg["turns"]
	mg_speed = lerpf(mg_speed, mg_frame_angle / delta, 0.2)
	if mg_speed > max_speed:
		# 빠르게 돌리기 시작할 때, 그리고 계속 빠르면 1초마다 기회가 줄어요
		mg_off += delta
		if mg_warn_time <= 0.0 or mg_off >= 1.0:
			mg_lives -= 1
			mg_perfect = false
			mg_off = 0.0
			sfx("bad")
			shake(14)
			flash(Color(1, 0.3, 0.3))
			pop(mg_big, 0.8)
		mg_warn_time = 1.0
	else:
		mg_progress += mg_frame_angle / (turns * TAU)
		var step := int(mg_progress * 16.0)
		if step != mg_step:
			mg_step = step
			sfx("tick", 1.0 + mg_progress)
			pop(mg_big, 1.04)
	mg_frame_angle = 0.0
	mg_warn_time -= delta
	if mg_warn_time > 0.0:
		mg_info.text = "%s\n남은 기회 %d" % [mg_cfg["warn"], mg_lives]
	else:
		mg_info.text = "남은 기회 %d" % mg_lives

# 박자 따라가기: 너무 오래 어긋나면 실패해요
func update_follow(delta: float) -> void:
	var w := mg_overlay.size.x
	var h := mg_overlay.size.y
	var slow: float = mg_cfg["slow"]
	var goal: float = mg_cfg["goal"]
	var patience: float = mg_cfg["patience"]
	var tol: float = mg_cfg["tol"]
	var amp := w * 0.33
	var period := lerpf(slow, slow - 0.5, mg_progress)
	mg_phase += delta * TAU / period
	var guide_x := w * 0.5 + amp * sin(mg_phase)
	mg_move(mg_a, guide_x, h * 0.78)
	mg_move(mg_b, mg_pos.x, h * 0.78)
	var in_sync := mg_touch and absf(mg_pos.x - guide_x) < amp * tol
	var dir_now := signf(cos(mg_phase))
	if dir_now != mg_dir:
		# 톱이 방향을 바꾸는 순간: 박자가 맞으면 쓱싹!
		mg_dir = dir_now
		if in_sync:
			sfx("saw", rng.randf_range(0.9, 1.15))
			shake(5)
			pop(mg_big, 1.05)
			pop(mg_b, 1.5)
			burst(mg_big.position + Vector2(mg_r, mg_progress * mg_r * 2.0), PAPER, 5)
	if in_sync:
		mg_progress += delta / goal
		mg_b.modulate = Color(0.6, 1.0, 0.6)
		mg_info.text = "박자가 맞아요!"
	else:
		mg_b.modulate = Color(1, 1, 1)
		if mg_started:
			mg_off += delta
		mg_info.text = "갈색을 따라 좌우로!\n남은 여유 %d초" % int(ceil(patience - mg_off))
	if mg_off > patience * 0.4:
		mg_perfect = false
	if mg_off >= patience:
		mg_lives = 0
	mg_c.offset_bottom = mg_progress * mg_r * 2.0

# 떨어지는 것 받기: 나쁜 것을 세 번 받으면 실패해요
func update_catch(delta: float) -> void:
	var w := mg_overlay.size.x
	var h := mg_overlay.size.y
	var goal: int = mg_cfg["goal"]
	var interval: float = mg_cfg["interval"]
	var speed: float = mg_cfg["speed"]
	var bad_ratio: float = mg_cfg["bad_ratio"]
	var basket_y := h * 0.78
	var r := short_side * 0.055
	mg_move(mg_a, mg_pos.x, basket_y)
	mg_timer -= delta
	if mg_timer <= 0.0:
		mg_timer = interval
		var bad := rng.randf() < bad_ratio
		var item: Panel
		if bad:
			item = mg_dot(mg_item_color(mg_cfg["bad"]), r, mg_cfg["bad"])
		else:
			item = mg_dot(mg_item_color(mg_cfg["good"]), r * 0.8, mg_cfg["good"])
		mg_move(item, rng.randf_range(w * 0.12, w * 0.88), h * 0.37)
		mg_items.append([item, bad])
	for i in range(mg_items.size() - 1, -1, -1):
		var node: Panel = mg_items[i][0]
		var is_bad: bool = mg_items[i][1]
		node.position.y += h * speed * delta
		var center := node.position + node.size / 2.0
		var caught := absf(center.y - basket_y) < r * 1.5 and absf(center.x - mg_pos.x) < short_side * 0.09 + r * 0.5
		if caught:
			if is_bad:
				mg_lives -= 1
				mg_perfect = false
				sfx("bad")
				shake(16)
				hit_stop(0.05)
				flash(Color(1, 0.3, 0.3))
				float_text("아야!", center, Color(1, 0.55, 0.45), 1.2)
			else:
				mg_count += 1
				sfx("pop", 1.0 + mg_count * 0.04)
				pop(mg_a, 1.3)
				burst(center, Color(1, 1, 1), 5)
				float_text("+1", center, Color(1, 1, 1), 1.0)
		if caught or center.y > h * 0.9:
			node.queue_free()
			mg_items.remove_at(i)
	mg_progress = float(mg_count) / goal
	mg_info.text = "%s %d/%d | 남은 기회 %d" % [mg_cfg["good"], mg_count, goal, mg_lives]

# 나타나는 것 누르기: 세 번 놓치면 실패해요
func update_tap(delta: float) -> void:
	var w := mg_overlay.size.x
	var h := mg_overlay.size.y
	var goal: int = mg_cfg["goal"]
	var interval: float = mg_cfg["interval"]
	var life: float = mg_cfg["life"]
	var r := short_side * 0.085
	mg_timer -= delta
	if mg_timer <= 0.0:
		mg_timer = interval
		var b := Button.new()
		b.text = mg_cfg["target"]
		skin_button(b, make_fancy(mg_item_color(mg_cfg["target"]), r), Color(1, 1, 1), 0.7)
		b.size = Vector2(r * 2.0, r * 2.0)
		mg_stage.add_child(b)
		var angle := rng.randf() * TAU
		var dist := mg_r * rng.randf_range(1.2, 1.9)
		var x := clampf(w * 0.5 + cos(angle) * dist, r, w - r)
		var y := clampf(h * 0.62 + sin(angle) * dist, h * 0.38, h * 0.84)
		mg_move(b, x, y)
		pop(b, 0.3)
		b.pressed.connect(on_tap.bind(b))
		mg_items.append([b, 0.0])
	for i in range(mg_items.size() - 1, -1, -1):
		var node: Button = mg_items[i][0]
		var age: float = mg_items[i][1] + delta
		mg_items[i][1] = age
		node.modulate = Color(1, 1, 1).lerp(Color(1.0, 0.45, 0.4), age / life)
		if age >= life:
			mg_lives -= 1
			mg_perfect = false
			sfx("bad")
			shake(12)
			flash(Color(1, 0.3, 0.3))
			node.queue_free()
			mg_items.remove_at(i)
	mg_progress = float(mg_count) / goal
	mg_info.text = "%s %d/%d | 남은 기회 %d" % [mg_cfg["target"], mg_count, goal, mg_lives]

func on_tap(b: Button) -> void:
	for i in mg_items.size():
		if mg_items[i][0] == b:
			mg_items.remove_at(i)
			mg_count += 1
			var at := b.position + b.size / 2.0
			sfx("pop", 1.0 + mg_count * 0.04)
			shake(4)
			burst(at, Color(0.6, 0.9, 0.5), 7)
			float_text(["뽁!", "쏙!", "얍!"][mg_count % 3], at, Color(1, 1, 1), 1.1)
			# 눌린 것은 커지면서 사라져요
			b.disabled = true
			b.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.pivot_offset = b.size / 2.0
			var tw := b.create_tween()
			tw.tween_property(b, "scale", Vector2(1.6, 1.6), 0.15)
			tw.parallel().tween_property(b, "modulate:a", 0.0, 0.15)
			tw.tween_callback(b.queue_free)
			return

# ---------- 조작과 매 프레임 ----------

func stretch_player(shape: Vector3) -> void:
	player_body.scale = shape
	player_body.create_tween().tween_property(player_body, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func on_turn() -> void:
	cam_yaw_target += PI / 2.0

func on_jump() -> void:
	jump_wanted = true

# 화면 버튼(돌리기/점프/행동)은 터치를 직접 처리해요.
# 한 손가락으로 걷는 중에도 다른 손가락으로 점프를 누를 수 있게 하기 위해서예요.
var btn_touches: Array = []
var stick_index := -1

func hud_button_hit(pos: Vector2) -> Button:
	for b in [jump_button, turn_button, action_button]:
		if b != null and b.is_visible_in_tree() and b.get_global_rect().has_point(pos):
			return b
	return null

func hud_press(b: Button) -> void:
	if b == jump_button:
		on_jump()
	elif b == turn_button:
		on_turn()
	elif b == action_button:
		on_action()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			var b := hud_button_hit(event.position)
			if b != null:
				btn_touches.append(event.index)
				hud_press(b)
				get_viewport().set_input_as_handled()
		elif event.index in btn_touches:
			btn_touches.erase(event.index)
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		if event.index in btn_touches:
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.device != -1:
		# 컴퓨터 마우스 (터치에서 만들어진 가짜 마우스 이벤트는 제외)
		var b2 := hud_button_hit(event.position)
		if b2 != null:
			hud_press(b2)
			get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if stick_index == -1:
				stick_index = event.index
				touching = true
				touch_start = event.position
				move_input = Vector2.ZERO
		elif event.index == stick_index:
			stick_index = -1
			touching = false
			move_input = Vector2.ZERO
	elif event is InputEventScreenDrag and touching and event.index == stick_index:
		move_input = ((event.position - touch_start) / drag_range).limit_length(1.0)

func _physics_process(delta: float) -> void:
	if mg_active:
		update_game(delta)
	var busy := is_busy()
	if busy:
		move_input = Vector2.ZERO
		jump_wanted = false
		stick_index = -1
		touching = false
		btn_touches.clear()
	cam_yaw = lerp_angle(cam_yaw, cam_yaw_target, minf(1.0, delta * 8.0))
	var speed := SPEED
	if has_shoes:
		speed = SPEED * 1.3
	var dir := Vector3(move_input.x, 0, move_input.y).rotated(Vector3.UP, cam_yaw)
	player.velocity.x = dir.x * speed
	player.velocity.z = dir.z * speed
	if player.is_on_floor():
		if jump_wanted:
			player.velocity.y = JUMP
			sfx("jump")
			stretch_player(Vector3(0.8, 1.25, 0.8))
		else:
			player.velocity.y = 0
	else:
		player.velocity.y -= GRAVITY * delta
	jump_wanted = false
	var fall_speed := -player.velocity.y
	player.move_and_slide()
	var on_floor := player.is_on_floor()
	if on_floor and not was_on_floor and fall_speed > 3.0:
		# 착지: 쿵 하고 납작해졌다 돌아오기
		sfx("land")
		stretch_player(Vector3(1.3, 0.7, 1.3))
		burst3d(player.position, Color(0.85, 0.8, 0.65), 8)
	was_on_floor = on_floor
	if on_floor and dir.length() > 0.1:
		# 걸을 때 통통 튀고 발소리 내기
		walk_phase += delta * 11.0 * dir.length()
		player_body.position.y = 1.0 + absf(sin(walk_phase)) * 0.12
		limb_amt = lerpf(limb_amt, 1.0, 0.3)
		var steps := int(walk_phase / PI)
		if steps != step_count:
			step_count = steps
			sfx("step", rng.randf_range(0.85, 1.15))
	else:
		player_body.position.y = lerpf(player_body.position.y, 1.0, 0.3)
		limb_amt = lerpf(limb_amt, 0.0, 0.25)
	arm_up_amt = lerpf(arm_up_amt, 0.0 if on_floor else 1.0, 0.3)
	pose_person(player_body, sin(walk_phase) * limb_amt, arm_up_amt)
	if dir.length() > 0.1 and on_floor:
		player_body.rotation.x = lerpf(player_body.rotation.x, 0.12, 0.2)
	else:
		player_body.rotation.x = lerpf(player_body.rotation.x, 0.0, 0.2)
	if player.position.y < -10.0:
		player.position = Vector3(-2, 0, 16)
		player.velocity = Vector3.ZERO
	if dir.length() > 0.1:
		player.rotation.y = lerp_angle(player.rotation.y, atan2(dir.x, dir.z), minf(1.0, delta * 14.0))
	cam.position = player.position + CAM_OFFSET.rotated(Vector3.UP, cam_yaw)
	cam.look_at(player.position + Vector3(0, 1.3, 0))

	# 화면 흔들림
	if shake_amt > 0.3:
		var jolt := Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * shake_amt * short_side / 1000.0
		ui_layer.offset = jolt
		cam.position += Vector3(jolt.x, jolt.y, 0) * 0.012
		shake_amt = lerpf(shake_amt, 0.0, minf(1.0, delta * 12.0))
	else:
		shake_amt = 0.0
		ui_layer.offset = Vector2.ZERO
	# 엽전 숫자가 또르르 올라가기
	if shown_coins != coins:
		shown_coins += signi(coins - shown_coins)
		update_quest_text()
	# 이야기 조각이 둥실둥실
	idle_time += delta
	for t in things:
		if t["kind"] == "piece":
			var piece: Node3D = t["node"]
			var ball: Node3D = piece.get_child(0)
			ball.position.y = 0.75 + sin(idle_time * 3.0 + piece.position.x) * 0.12
			ball.rotation.y = idle_time * 1.4 + piece.position.x

	current_thing = {}
	if not busy:
		current_thing = find_thing()
	if current_thing.is_empty():
		action_button.visible = false
	else:
		action_button.text = action_text(current_thing)
		action_button.visible = true
	jump_button.visible = not busy
	turn_button.visible = not busy

# ---------- 글꼴 데이터 (주아체, SIL OFL 라이선스, 압축됨) ----------
const FONT_B64 := "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"
