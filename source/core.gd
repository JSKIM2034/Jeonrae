extends Node3D

# 모든 장이 함께 쓰는 공통 부분: 주인공, 카메라, 화면, 대화, 미니게임 틀, 소리, 3D 부품.
# 장마다 다른 맵과 이야기는 chapter1.gd, chapter2.gd ... 가 이 파일을 이어받아 만들어요.


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
var cam_zoom := 1.0        # 1 보다 작으면 가까이, 크면 멀리
var cam_zoom_target := 1.0
var pinch_points := {}
var pinch_start_dist := 0.0
var pinch_start_zoom := 1.0
const ZOOM_MIN := 0.3
# 가까이 당기면 카메라가 낮아져 하늘이 보여요 (주인공 뒤 어깨 높이)
const CAM_NEAR := Vector3(0, 1.5, 4.0)
var pinch_start_angle := 0.0
var pinch_start_yaw := 0.0
var pinch_rotating := false
var cam_hint_seen := false
var cam_hint_timer := 0.0
const ZOOM_MAX := 1.8
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
var gait_run := 0.0
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
var quest_panel: PanelContainer
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

# ---------- 미니게임 그림 (동그라미 대신 진짜 장면을 그려요) ----------

var mg_art: Control
var mg_fx: Array = []   # [종류, 위치, 나이, 방향]

func art_key() -> String:
	return mg_cfg.get("art", "")

func ell_pts(c: Vector2, rx: float, ry: float, rot: float = 0.0, n: int = 28) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
	return pts

func d_poly(ci: CanvasItem, pts: PackedVector2Array, col: Color, outline: float = 4.0) -> void:
	ci.draw_colored_polygon(pts, col)
	if outline > 0.0:
		var closed := pts.duplicate()
		closed.append(pts[0])
		ci.draw_polyline(closed, col.darkened(0.4), outline, true)

func d_ell(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color, rot: float = 0.0, outline: float = 4.0) -> void:
	d_poly(ci, ell_pts(c, rx, ry, rot), col, outline)

func d_box(ci: CanvasItem, c: Vector2, size: Vector2, rot: float, col: Color, outline: float = 4.0) -> void:
	var h := size / 2.0
	var pts := PackedVector2Array([c + Vector2(-h.x, -h.y).rotated(rot), c + Vector2(h.x, -h.y).rotated(rot), c + Vector2(h.x, h.y).rotated(rot), c + Vector2(-h.x, h.y).rotated(rot)])
	d_poly(ci, pts, col, outline)

func d_shadow(ci: CanvasItem, c: Vector2, rx: float) -> void:
	ci.draw_colored_polygon(ell_pts(c, rx, rx * 0.22), Color(0, 0, 0, 0.16))

func d_line(ci: CanvasItem, a: Vector2, b: Vector2, col: Color, w: float) -> void:
	ci.draw_line(a, b, col, w, true)

# 꼬인 줄 (실, 새끼줄)
func d_rope(ci: CanvasItem, a: Vector2, b: Vector2, col: Color, w: float) -> void:
	var n := int(a.distance_to(b) / 10.0) + 2
	var side := (b - a).normalized().orthogonal() * w * 0.35
	for strand in 2:
		var pts := PackedVector2Array()
		for i in n + 1:
			var t := float(i) / n
			pts.append(a.lerp(b, t) + side * sin(t * n * 1.2 + strand * PI + anim_t * 8.0))
		ci.draw_polyline(pts, col if strand == 0 else col.darkened(0.2), w * 0.6, true)

func mg_center() -> Vector2:
	return Vector2(mg_overlay.size.x * 0.5, mg_overlay.size.y * (0.62 if mg_type == "tap" else 0.6))

func node_center(c: Control) -> Vector2:
	return c.position + c.size / 2.0

func pop_scale(c: Control) -> float:
	return c.scale.x if is_instance_valid(c) else 1.0

# --- 등장인물과 물건 ---

# 막기 놀이에서 공격(앞발)이 화면 어디에 얼마나 크게 있는지: [위치, 반지름, 가운데]
func swipe_geom(a: Dictionary, W: float, H: float, jitter: bool) -> Array:
	var c := Vector2(W * 0.5, H * 0.55)
	var edge := {"left": Vector2(W * 0.17, H * 0.55), "right": Vector2(W * 0.83, H * 0.55), "up": Vector2(W * 0.5, H * 0.42)}   # 위쪽은 제목 칸에 가리지 않게
	var p: Vector2 = edge[a["dir"]]
	var tm: float = a["time"]
	var grow := 0.6
	if a["phase"] == "tele":
		grow = 0.55 + tm * 0.5
		if jitter:
			p += Vector2(rng.randf_range(-3, 3), rng.randf_range(-3, 3))
	elif a["phase"] == "strike":
		grow = 1.25
		p = p.lerp(c, minf(1.0, tm * 1.4) * 0.35)
	else:
		grow = maxf(0.2, 0.9 - tm * 1.6)
	return [p, font_size * 1.6 * grow, c]

# 3D 호랑이 앞발 (고양이 손 모양). 화면의 앞발 자리에 진짜 입체 앞발을 띄워요
var paw3d: Node3D
var paw3d_claws: Node3D

func make_paw3d() -> void:
	paw3d = Node3D.new()
	world_node(paw3d)
	var org := Color(0.96, 0.56, 0.18)
	var stripe := Color(0.25, 0.14, 0.08)
	var fur := Color(1.0, 0.86, 0.66)
	var bean := Color(1.0, 0.55, 0.66)
	var arm := [[Vector3(0, 1.45, -0.12), Vector3(0.66, 2.5, 0.6), org]]
	for y in [0.75, 1.2, 1.65, 2.1]:
		arm.append([Vector3(0, y, -0.12), Vector3(0.7, 0.1, 0.64), stripe])
	add_blobs(paw3d, arm)
	# 발은 손바닥이 정면을 보지 않게 비스듬히 (내려치는 듯 앞으로 숙이고 살짝 옆으로)
	var hand := Node3D.new()
	paw3d.add_child(hand)
	hand.rotation = Vector3(0.8, 0.0, 0.35)
	var items := [
		[Vector3(0, 0, 0), Vector3(0.92, 0.98, 0.62), fur],
		[Vector3(0, 0.1, 0.28), Vector3(0.4, 0.36, 0.1), bean],
	]
	for k in 4:
		var a := -0.75 + k * 0.5
		items.append([Vector3(sin(a) * 0.3, -cos(a) * 0.3, 0.27), Vector3(0.17, 0.15, 0.08), bean])
		# 발등 쪽 동글동글한 발가락
		items.append([Vector3(sin(a) * 0.3, -cos(a) * 0.34, -0.06), Vector3(0.24, 0.24, 0.34), fur])
	add_blobs(hand, items)
	paw3d_claws = Node3D.new()
	hand.add_child(paw3d_claws)
	var cl := []
	for k in 4:
		var a2 := -0.75 + k * 0.5
		cl.append([Vector3(sin(a2) * 0.5, -cos(a2) * 0.5, 0.08), Vector3(0.07, 0.22, 0.07), Color(0.98, 0.97, 0.92), Vector3(0, 0, rad_to_deg(a2))])
	add_blobs(paw3d_claws, cl)
	for mi in paw3d.find_children("*", "GeometryInstance3D", true, false):
		(mi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func update_paw3d() -> void:
	if not mg_world or mg_cfg.get("scene", "") != "paws" or cam == null:
		return
	if paw3d == null or not is_instance_valid(paw3d):
		make_paw3d()
	var a: Dictionary = cg.get("atk", {})
	if a.is_empty():
		paw3d.visible = false
		return
	var geo := swipe_geom(a, mg_overlay.size.x, mg_overlay.size.y, false)
	var base := mg_overlay.global_position
	var p: Vector2 = base + geo[0]
	var c: Vector2 = base + geo[2]
	var depth := 4.0
	if w.has("basket"):
		depth = maxf(1.5, cam.global_position.distance_to(w["basket"]) * 0.8)
	var wp := cam.project_position(p, depth)
	var wr := cam.project_position(p + Vector2(geo[1], 0), depth).distance_to(wp)
	var to_cam := (cam.global_position - wp).normalized()
	var out := (wp - cam.project_position(c, depth)).normalized()   # 가운데에서 앞발 쪽 (팔이 뻗어 나온 쪽)
	out = (out - to_cam * out.dot(to_cam)).normalized()
	var xb := out.cross(to_cam).normalized()
	paw3d.global_transform = Transform3D(Basis(xb, out, to_cam).scaled(Vector3.ONE * wr / 0.46), wp)
	paw3d.visible = true
	paw3d_claws.visible = a["phase"] == "strike"

# 고양이 손 같은 호랑이 앞발: 줄무늬 팔 끝에 말랑한 발, 분홍 젤리 발바닥. 내려칠 땐 발톱이 쏙
func draw_cat_paw(ci: CanvasItem, p: Vector2, toward: Vector2, r: float, claws: bool) -> void:
	var d := (toward - p).normalized()
	var n := d.orthogonal()
	var ang := d.angle()
	var org := Color(0.96, 0.56, 0.18)
	var bean := Color(1.0, 0.6, 0.7)
	var arm_end := p - d * r * 3.2
	d_poly(ci, PackedVector2Array([arm_end + n * r * 0.62, p + n * r * 0.62, p - n * r * 0.62, arm_end - n * r * 0.62]), org, 5.0)
	for k in 3:
		d_box(ci, p - d * r * (0.95 + k * 0.6), Vector2(r * 0.16, r * 1.16), ang, Color(0.25, 0.14, 0.08), 0.0)
	if claws:
		for k in 4:
			var a := -0.75 + k * 0.5
			var dir := d.rotated(a)
			var base := p + dir * r * 0.75
			var w := dir.orthogonal() * r * 0.1
			d_poly(ci, PackedVector2Array([base + w, p + dir * r * 1.3, base - w]), Color(0.97, 0.95, 0.88), 3.0)
	d_ell(ci, p, r * 0.85, r * 0.95, Color(1.0, 0.9, 0.76), ang, 5.0)
	d_ell(ci, p - d * r * 0.18, r * 0.34, r * 0.42, bean, ang, 3.0)
	for k in 4:
		var a2 := -0.75 + k * 0.5
		d_ell(ci, p + d.rotated(a2) * r * 0.55, r * 0.15, r * 0.13, bean, ang + a2, 3.0)

func draw_swallow(ci: CanvasItem, c: Vector2, s: float, prog: float, ouch: bool) -> void:
	var navy := Color(0.17, 0.2, 0.38)
	d_shadow(ci, c + Vector2(0, s * 0.95), s * 0.8)
	# 꼬리 (제비 꼬리는 가위 모양)
	d_poly(ci, PackedVector2Array([c + Vector2(s * 0.45, -s * 0.05), c + Vector2(s * 1.15, -s * 0.38), c + Vector2(s * 0.75, s * 0.02), c + Vector2(s * 1.12, s * 0.3), c + Vector2(s * 0.45, s * 0.12)]), navy)
	# 몸통, 배, 날개
	d_ell(ci, c, s * 0.66, s * 0.44, navy, -0.12)
	d_ell(ci, c + Vector2(-s * 0.05, s * 0.14), s * 0.46, s * 0.26, Color(0.98, 0.96, 0.9), -0.12, 0.0)
	d_ell(ci, c + Vector2(s * 0.12, -s * 0.1), s * 0.5, s * 0.2, navy.lightened(0.12), 0.32)
	# 다리 (다친 다리에 부목 + 실 감기)
	var hip := c + Vector2(s * 0.08, s * 0.36)
	var foot := hip + Vector2(s * 0.02, s * 0.42)
	d_line(ci, c + Vector2(-s * 0.18, s * 0.38), c + Vector2(-s * 0.2, s * 0.75), Color(0.85, 0.55, 0.35), s * 0.06)
	d_line(ci, hip, foot, Color(0.85, 0.55, 0.35), s * 0.07)
	d_box(ci, hip.lerp(foot, 0.5) + Vector2(s * 0.07, 0), Vector2(s * 0.06, s * 0.5), 0.0, Color(0.72, 0.52, 0.3), 2.0)
	var wraps := int(prog * 9.0)
	for i in wraps:
		var y := hip.y + s * 0.06 + i * s * 0.04
		d_line(ci, Vector2(hip.x - s * 0.06, y + s * 0.03), Vector2(hip.x + s * 0.13, y - s * 0.02), Color(1, 1, 1), s * 0.035)
	# 머리
	var head := c + Vector2(-s * 0.55, -s * 0.3)
	d_ell(ci, head, s * 0.32, s * 0.3, navy)
	d_ell(ci, head + Vector2(s * 0.04, s * 0.2), s * 0.15, s * 0.1, Color(0.88, 0.32, 0.26), 0.0, 0.0)
	d_poly(ci, PackedVector2Array([head + Vector2(-s * 0.26, -s * 0.02), head + Vector2(-s * 0.48, s * 0.05), head + Vector2(-s * 0.25, s * 0.09)]), Color(1.0, 0.7, 0.2), 2.0)
	var eye := head + Vector2(-s * 0.1, -s * 0.06)
	if ouch:
		d_line(ci, eye + Vector2(-s * 0.06, -s * 0.05), eye + Vector2(s * 0.05, 0), Color(1, 1, 1), 4)
		d_line(ci, eye + Vector2(-s * 0.06, s * 0.05), eye + Vector2(s * 0.05, 0), Color(1, 1, 1), 4)
	else:
		ci.draw_circle(eye, s * 0.075, Color(1, 1, 1))
		ci.draw_circle(eye + Vector2(-s * 0.01, s * 0.01), s * 0.05, Color(0.05, 0.05, 0.08))
		ci.draw_circle(eye + Vector2(-s * 0.025, -s * 0.02), s * 0.018, Color(1, 1, 1))
	ci.draw_circle(head + Vector2(s * 0.1, s * 0.08), s * 0.05, Color(1, 0.6, 0.6, 0.7))
	if prog >= 0.99:
		for k in 3:
			ci.draw_circle(c + Vector2(-s * 0.8 + k * s * 0.18, -s * 0.85 - sin(anim_t * 6.0 + k) * 6.0), 5, Color(1, 0.9, 0.4))

func draw_sandal(ci: CanvasItem, c: Vector2, s: float, prog: float) -> void:
	var straw := Color(0.9, 0.76, 0.42)
	d_shadow(ci, c + Vector2(0, s * 0.85), s * 0.6)
	# 다 삼은 모양 (희미한 밑그림)
	ci.draw_colored_polygon(ell_pts(c, s * 0.42, s * 0.8), Color(1, 1, 1, 0.25))
	var rows := 20
	for i in rows:
		if float(i) / rows > prog:
			break
		var y := c.y + s * 0.78 - i * (s * 1.56 / rows)
		var t := (y - c.y) / (s * 0.8)
		var half := s * 0.42 * sqrt(maxf(0.0, 1.0 - t * t))
		var col := straw if i % 2 == 0 else straw.darkened(0.12)
		d_line(ci, Vector2(c.x - half, y), Vector2(c.x + half, y), col, s * 1.56 / rows + 1.0)
	# 날줄 (세로 새끼줄 네 가닥)
	for k in 4:
		var x := c.x + (k - 1.5) * s * 0.16
		var top := c.y + s * 0.78 - prog * s * 1.56
		d_line(ci, Vector2(x, c.y + s * 0.76), Vector2(x, top), Color(0.62, 0.46, 0.22), 3)
	if prog > 0.35:
		var rim := ell_pts(c, s * 0.42, s * 0.8)
		rim.append(rim[0])
		ci.draw_polyline(rim, Color(0.7, 0.54, 0.26), 7, true)
	if prog > 0.85:
		d_ell(ci, c + Vector2(0, -s * 0.72), s * 0.1, s * 0.07, Color(0.75, 0.58, 0.3))
		for sx in [-1.0, 1.0]:
			d_rope(ci, c + Vector2(sx * s * 0.38, -s * 0.1), c + Vector2(0, -s * 0.7), Color(0.78, 0.62, 0.32), 8)
	# 옆에 놓인 짚 다발
	for k in 7:
		var a := -0.3 + k * 0.1
		d_line(ci, c + Vector2(s * 0.85, s * 0.8), c + Vector2(s * 0.85, s * 0.8) + Vector2(0, -s * 0.9).rotated(a), straw.darkened(0.05 * (k % 3)), 5)
	d_line(ci, c + Vector2(s * 0.72, s * 0.5), c + Vector2(s * 0.98, s * 0.5), Color(0.6, 0.42, 0.2), 6)

func jar_pts(c: Vector2, s: float) -> PackedVector2Array:
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in 17:
		var t := float(i) / 16.0
		var y := c.y - s * 0.78 + t * s * 1.56
		var half := s * (0.34 + 0.46 * sin(PI * pow(t, 0.75)))
		if t > 0.92:
			half *= 1.0 - (t - 0.92) * 2.0
		right.append(Vector2(c.x + half, y))
		left.append(Vector2(c.x - half, y))
	left.reverse()
	return right + left

func draw_jar(ci: CanvasItem, c: Vector2, s: float, prog: float, ouch: bool) -> void:
	d_shadow(ci, c + Vector2(0, s * 0.8), s * 0.75)
	var body := Color(0.5, 0.29, 0.16)
	d_poly(ci, jar_pts(c, s), body, 5)
	d_ell(ci, c + Vector2(-s * 0.36, -s * 0.15), s * 0.1, s * 0.34, Color(1, 1, 1, 0.22), 0.15, 0.0)
	d_line(ci, c + Vector2(-s * 0.72, -s * 0.28), c + Vector2(s * 0.72, -s * 0.28), body.lightened(0.1), 4)
	d_ell(ci, c + Vector2(0, -s * 0.78), s * 0.36, s * 0.08, body.darkened(0.3))
	d_ell(ci, c + Vector2(0, -s * 0.86), s * 0.4, s * 0.1, Color(0.4, 0.22, 0.12))
	# 금 (지그재그) + 진흙으로 메운 자리
	var crack := PackedVector2Array([Vector2(0.12, -0.6), Vector2(-0.02, -0.4), Vector2(0.1, -0.2), Vector2(-0.06, 0.02), Vector2(0.08, 0.22), Vector2(-0.04, 0.45)])
	var pts := PackedVector2Array()
	for p in crack:
		pts.append(c + p * s)
	ci.draw_polyline(pts, Color(0.12, 0.06, 0.03), 7 if not ouch else 10, true)
	var n := pts.size() - 1
	for k in n:
		if float(k) / n < prog:
			d_ell(ci, pts[k].lerp(pts[k + 1], 0.5), s * 0.14, s * 0.12, Color(0.68, 0.5, 0.33), 0.4, 2.0)

func draw_nest(ci: CanvasItem, c: Vector2, s: float) -> void:
	d_shadow(ci, c + Vector2(0, s * 0.45), s * 0.8)
	for k in 3:
		var bc := c + Vector2((k - 1) * s * 0.32, -s * 0.18 - absf(sin(anim_t * 7.0 + k)) * s * 0.08)
		d_ell(ci, bc, s * 0.17, s * 0.16, Color(0.17, 0.2, 0.38))
		d_poly(ci, PackedVector2Array([bc + Vector2(-s * 0.1, -s * 0.06), bc + Vector2(0, -s * 0.28), bc + Vector2(s * 0.1, -s * 0.06)]), Color(1.0, 0.78, 0.2), 2)
		d_poly(ci, PackedVector2Array([bc + Vector2(-s * 0.06, -s * 0.06), bc + Vector2(0, -s * 0.16), bc + Vector2(s * 0.06, -s * 0.06)]), Color(1.0, 0.4, 0.3), 0)
		ci.draw_circle(bc + Vector2(-s * 0.07, s * 0.0), s * 0.03, Color(0, 0, 0))
		ci.draw_circle(bc + Vector2(s * 0.07, s * 0.0), s * 0.03, Color(0, 0, 0))
	d_ell(ci, c + Vector2(0, s * 0.12), s * 0.82, s * 0.36, Color(0.55, 0.4, 0.25))
	var r := RandomNumberGenerator.new()
	r.seed = 3
	for k in 16:
		var a := Vector2(r.randf_range(-0.75, 0.75), r.randf_range(-0.15, 0.35)) * s + c
		d_line(ci, a, a + Vector2(r.randf_range(0.15, 0.3) * s, 0).rotated(r.randf_range(-0.4, 0.4)), Color(0.85, 0.7, 0.4) if k % 2 == 0 else Color(0.4, 0.28, 0.16), 4)

func draw_snake(ci: CanvasItem, head: Vector2, toward: Vector2, s: float, danger: float) -> void:
	var dir := (toward - head).normalized()
	var side := dir.orthogonal()
	var col := Color(0.42, 0.62, 0.26).lerp(Color(0.75, 0.3, 0.2), danger)
	var pts := PackedVector2Array()
	for i in 12:
		var t := float(i) / 11.0
		pts.append(head - dir * t * s * 2.2 + side * sin(t * 7.0 + anim_t * 9.0) * s * 0.28 * t)
	ci.draw_polyline(pts, col.darkened(0.4), s * 0.42, true)
	ci.draw_polyline(pts, col, s * 0.32, true)
	ci.draw_polyline(pts, col.lightened(0.35), s * 0.08, true)
	d_ell(ci, head, s * 0.32, s * 0.24, col, dir.angle())
	for sx in [-1.0, 1.0]:
		var e: Vector2 = head + dir * s * 0.08 + side * sx * s * 0.12
		ci.draw_circle(e, s * 0.07, Color(1, 0.95, 0.5))
		ci.draw_circle(e, s * 0.035, Color(0, 0, 0))
	var tip := head + dir * s * 0.32
	if fmod(anim_t * 3.0, 1.0) < 0.5:
		d_line(ci, tip, tip + dir * s * 0.2, Color(0.9, 0.2, 0.25), 3)
		d_line(ci, tip + dir * s * 0.2, tip + dir * s * 0.28 + side * s * 0.07, Color(0.9, 0.2, 0.25), 3)
		d_line(ci, tip + dir * s * 0.2, tip + dir * s * 0.28 - side * s * 0.07, Color(0.9, 0.2, 0.25), 3)

func draw_stump(ci: CanvasItem, c: Vector2, s: float) -> void:
	d_shadow(ci, c + Vector2(0, s * 0.62), s * 0.9)
	var bark := Color(0.45, 0.3, 0.18)
	d_box(ci, c + Vector2(0, s * 0.3), Vector2(s * 1.4, s * 0.6), 0.0, bark, 0)
	d_ell(ci, c + Vector2(0, s * 0.6), s * 0.7, s * 0.22, bark)
	d_ell(ci, c, s * 0.7, s * 0.24, Color(0.86, 0.7, 0.48))
	for k in 3:
		ci.draw_arc(c, s * (0.15 + k * 0.17), 0, TAU, 32, Color(0.7, 0.52, 0.32), 2, true)
	# 꽂힌 도끼
	var hand_a := c + Vector2(s * 0.12, -s * 0.05)
	d_line(ci, hand_a, hand_a + Vector2(s * 0.75, -s * 0.55), Color(0.62, 0.42, 0.24), s * 0.08)
	d_poly(ci, PackedVector2Array([c + Vector2(-s * 0.18, -s * 0.1), c + Vector2(s * 0.18, -s * 0.2), c + Vector2(s * 0.2, s * 0.02), c + Vector2(-s * 0.12, s * 0.06)]), Color(0.65, 0.68, 0.72), 3)

func draw_log(ci: CanvasItem, c: Vector2, s: float, danger: float) -> void:
	d_shadow(ci, c + Vector2(0, s * 0.85), s * 0.8)
	d_ell(ci, c, s * 0.88, s * 0.88, Color(0.42, 0.28, 0.16).lerp(Color(0.7, 0.25, 0.2), danger * 0.6))
	d_ell(ci, c, s * 0.7, s * 0.7, Color(0.9, 0.74, 0.5), 0.0, 0.0)
	for k in 3:
		ci.draw_arc(c + Vector2(s * 0.03, 0), s * (0.16 + k * 0.17), 0, TAU, 28, Color(0.74, 0.55, 0.34), 2.5, true)
	d_line(ci, c + Vector2(-s * 0.05, -s * 0.6), c + Vector2(s * 0.04, -s * 0.2), Color(0.55, 0.38, 0.22), 3)

func draw_pumpkin(ci: CanvasItem, c: Vector2, s: float, stake: bool, danger: float) -> void:
	d_shadow(ci, c + Vector2(0, s * 0.62), s * 0.85)
	var o := Color(0.94, 0.5, 0.1)
	d_ell(ci, c + Vector2(-s * 0.36, 0), s * 0.42, s * 0.58, o.darkened(0.08))
	d_ell(ci, c + Vector2(s * 0.36, 0), s * 0.42, s * 0.58, o.darkened(0.08))
	d_ell(ci, c, s * 0.46, s * 0.62, o)
	d_ell(ci, c + Vector2(-s * 0.15, -s * 0.22), s * 0.08, s * 0.2, Color(1, 1, 1, 0.3), 0.0, 0.0)
	d_box(ci, c + Vector2(0, -s * 0.66), Vector2(s * 0.12, s * 0.22), 0.2, Color(0.4, 0.45, 0.2), 3)
	d_ell(ci, c + Vector2(s * 0.3, -s * 0.66), s * 0.25, s * 0.12, Color(0.3, 0.58, 0.25), -0.4)
	if stake:
		var wood := Color(0.6, 0.42, 0.24).lerp(Color(0.8, 0.3, 0.25), danger * 0.6)
		d_box(ci, c + Vector2(s * 0.05, -s * 0.55), Vector2(s * 0.2, s * 0.85), 0.15, wood, 3)
		d_poly(ci, PackedVector2Array([c + Vector2(-s * 0.06, -s * 0.97), c + Vector2(s * 0.21, -s * 1.0), c + Vector2(s * 0.1, -s * 1.1)]), wood.darkened(0.15), 2)

func draw_gourd2d(ci: CanvasItem, c: Vector2, s: float, col: Color, prog: float) -> void:
	d_shadow(ci, c + Vector2(0, s * 0.95), s)
	d_ell(ci, c, s, s * 0.92, col)
	for k in 4:
		var x := (k - 1.5) * s * 0.42
		d_ell(ci, c + Vector2(x, 0), s * 0.2, s * 0.86 * sqrt(1.0 - pow(x / s, 2.0)), col.lightened(0.06 if k % 2 == 0 else -0.04), 0.0, 0.0)
	d_ell(ci, c + Vector2(-s * 0.45, -s * 0.4), s * 0.16, s * 0.25, Color(1, 1, 1, 0.35), 0.4, 0.0)
	d_box(ci, c + Vector2(0, -s * 0.98), Vector2(s * 0.12, s * 0.22), 0.1, Color(0.45, 0.4, 0.22), 3)
	# 톱이 지나간 자리 (하얀 속살)
	var depth := prog * s * 1.8
	if depth > 2.0:
		d_box(ci, c + Vector2(0, -s * 0.9 + depth / 2.0), Vector2(s * 0.08, depth), 0.0, Color(0.98, 0.98, 0.92), 2)

func draw_saw(ci: CanvasItem, c: Vector2, blade_len: float, in_sync: bool) -> void:
	var blade := Color(0.78, 0.8, 0.84) if not in_sync else Color(0.85, 0.95, 0.85)
	var top := c.y - 10.0
	var pts := PackedVector2Array([Vector2(c.x - blade_len / 2.0, top), Vector2(c.x + blade_len / 2.0, top), Vector2(c.x + blade_len / 2.0, top + 22.0)])
	var teeth := 22
	for i in range(teeth, -1, -1):
		var x := c.x - blade_len / 2.0 + blade_len * i / teeth
		pts.append(Vector2(x, top + (30.0 if i % 2 == 0 else 22.0)))
	d_poly(ci, pts, blade, 3)
	for sx in [-1.0, 1.0]:
		d_box(ci, Vector2(c.x + sx * (blade_len / 2.0 + 16.0), c.y), Vector2(26, 70), 0.0, Color(0.6, 0.4, 0.22), 3)

func draw_ditch(ci: CanvasItem, c: Vector2, s: float, prog: float) -> void:
	var w := s * 2.6
	# 왼쪽 물길, 가운데 흙둑(물꼬), 오른쪽 메마른 논
	d_box(ci, c + Vector2(-w * 0.3, s * 0.2), Vector2(w * 0.5, s * 0.5), 0.0, Color(0.42, 0.66, 0.9), 3)
	var paddy := Color(0.78, 0.68, 0.48).lerp(Color(0.5, 0.72, 0.9), prog)
	d_box(ci, c + Vector2(w * 0.3, s * 0.2), Vector2(w * 0.5, s * 0.7), 0.0, paddy, 3)
	for k in 3:
		for j in 2:
			var p := c + Vector2(w * 0.12 + k * w * 0.12, s * 0.02 + j * s * 0.3)
			d_line(ci, p, p + Vector2(-4, -s * 0.16), Color(0.4, 0.68, 0.3), 4)
			d_line(ci, p, p + Vector2(6, -s * 0.14), Color(0.48, 0.74, 0.32), 4)
	var mound := maxf(0.05, 1.0 - prog)
	d_ell(ci, c + Vector2(0, s * 0.3 - s * 0.25 * mound), s * 0.38, s * 0.5 * mound + 4.0, Color(0.55, 0.4, 0.24))
	if prog > 0.15:
		var flow := minf(1.0, prog * 1.4)
		for k in 4:
			var y := c.y + s * 0.12 + k * s * 0.08
			var ph := fmod(anim_t * 2.0 + k * 0.3, 1.0)
			d_line(ci, Vector2(c.x - s * 0.3 + ph * s * 0.6 * flow, y), Vector2(c.x - s * 0.1 + ph * s * 0.6 * flow, y), Color(0.85, 0.95, 1.0, flow), 4)

func draw_shovel(ci: CanvasItem, tip: Vector2, s: float) -> void:
	d_line(ci, tip + Vector2(0, -s * 0.2), tip + Vector2(s * 0.1, -s * 1.2), Color(0.62, 0.42, 0.24), 9)
	d_box(ci, tip + Vector2(s * 0.1, -s * 1.25), Vector2(s * 0.3, 10), 0.08, Color(0.55, 0.36, 0.2), 3)
	d_poly(ci, PackedVector2Array([tip + Vector2(-s * 0.16, -s * 0.24), tip + Vector2(s * 0.16, -s * 0.2), tip + Vector2(s * 0.1, s * 0.08), tip + Vector2(-s * 0.02, s * 0.14), tip + Vector2(-s * 0.13, s * 0.06)]), Color(0.6, 0.62, 0.66), 3)

func draw_bucket(ci: CanvasItem, c: Vector2, s: float, prog: float) -> void:
	d_rope(ci, c + Vector2(0, -s * 0.9), Vector2(c.x, mg_overlay.size.y * 0.31), Color(0.78, 0.66, 0.42), 7)
	d_line(ci, c + Vector2(-s * 0.55, -s * 0.35), c + Vector2(0, -s * 0.9), Color(0.5, 0.36, 0.2), 5)
	d_line(ci, c + Vector2(s * 0.55, -s * 0.35), c + Vector2(0, -s * 0.9), Color(0.5, 0.36, 0.2), 5)
	var pts := PackedVector2Array([c + Vector2(-s * 0.62, -s * 0.35), c + Vector2(s * 0.62, -s * 0.35), c + Vector2(s * 0.48, s * 0.5), c + Vector2(-s * 0.48, s * 0.5)])
	d_poly(ci, pts, Color(0.66, 0.46, 0.27), 4)
	var lvl := clampf(prog, 0.0, 1.0)
	if lvl > 0.02:
		var y := lerpf(c.y + s * 0.42, c.y - s * 0.28, lvl)
		d_ell(ci, Vector2(c.x, y), s * lerpf(0.5, 0.58, lvl), s * 0.1, Color(0.55, 0.8, 0.98), 0.0, 2.0)
	for k in 3:
		var x := c.x + (k - 1) * s * 0.36
		d_line(ci, Vector2(x, c.y - s * 0.33), Vector2(x * 0.98 + c.x * 0.02, c.y + s * 0.48), Color(0.55, 0.38, 0.22), 2)
	for yy in [-0.12, 0.3]:
		var hw := lerpf(0.62, 0.48, (yy + 0.35) / 0.85)
		d_line(ci, c + Vector2(-s * hw, s * yy), c + Vector2(s * hw, s * yy), Color(0.35, 0.33, 0.3), 6)

func draw_dipper(ci: CanvasItem, c: Vector2, s: float, prog: float) -> void:
	var pts := PackedVector2Array()
	for i in 17:
		var a := PI * i / 16.0
		pts.append(c + Vector2(cos(a) * s * 0.75, sin(a) * s * 0.55 - s * 0.1))
	d_poly(ci, pts, Color(0.95, 0.88, 0.62), 4)
	if prog > 0.02:
		var hh := s * 0.32 * clampf(prog, 0.0, 1.0)
		d_ell(ci, c + Vector2(0, -s * 0.1), s * 0.62, hh + 3.0, Color(1, 1, 0.97), 0.0, 2.0)
		for k in 8:
			ci.draw_circle(c + Vector2((k - 3.5) * s * 0.13, -s * 0.1 - hh * 0.5 + (k % 2) * 4.0), 4, Color(0.92, 0.9, 0.82))
	d_ell(ci, c + Vector2(0, -s * 0.1), s * 0.75, s * 0.1, Color(0.85, 0.75, 0.48), 0.0, 3.0)

func draw_drop(ci: CanvasItem, c: Vector2, s: float) -> void:
	var pts := PackedVector2Array([c + Vector2(0, -s * 1.3)])
	for i in 13:
		var a := -0.25 * PI + 1.5 * PI * i / 12.0
		pts.append(c + Vector2(cos(a), sin(a)) * s * 0.75 + Vector2(0, s * 0.15))
	d_poly(ci, pts, Color(0.45, 0.75, 0.98), 3)
	ci.draw_circle(c + Vector2(-s * 0.25, -s * 0.05), s * 0.15, Color(1, 1, 1, 0.8))

func draw_pebble(ci: CanvasItem, c: Vector2, s: float, rot: float) -> void:
	var pts := PackedVector2Array()
	var bumps := [1.0, 0.85, 1.05, 0.9, 1.1, 0.8, 0.95, 1.0]
	for i in 8:
		var a := TAU * i / 8.0 + rot
		pts.append(c + Vector2(cos(a), sin(a) * 0.8) * s * float(bumps[i]))
	d_poly(ci, pts, Color(0.6, 0.6, 0.64), 3)
	ci.draw_circle(c + Vector2(-s * 0.3, -s * 0.25), s * 0.15, Color(1, 1, 1, 0.3))

func draw_rice(ci: CanvasItem, c: Vector2, s: float) -> void:
	for k in 7:
		var a := k * TAU / 7.0
		d_ell(ci, c + Vector2(cos(a), sin(a)) * s * 0.45, s * 0.32, s * 0.2, Color(1, 1, 0.97), a, 2.0)
	d_ell(ci, c, s * 0.4, s * 0.3, Color(1, 1, 0.98), 0.0, 2.0)

func draw_paddle(ci: CanvasItem, c: Vector2, s: float, rot: float) -> void:
	d_line(ci, c, c + Vector2(0, s * 1.4).rotated(rot), Color(0.62, 0.42, 0.24), s * 0.32)
	d_ell(ci, c, s * 0.7, s * 0.85, Color(0.82, 0.62, 0.36), rot)
	ci.draw_circle(c + Vector2(-s * 0.15, -s * 0.2).rotated(rot), s * 0.12, Color(1, 1, 0.97))

# 손가락 위치에 들고 있는 도구
func draw_cursor(ci: CanvasItem) -> void:
	if not (is_instance_valid(mg_a) and mg_a.visible and mg_touch):
		return
	var p := mg_pos
	match art_key():
		"heal":
			d_rope(ci, mg_center() + Vector2(mg_r * 0.1, mg_r * 0.55), p, Color(1, 1, 1), 5)
			d_ell(ci, p, 18, 14, Color(0.95, 0.92, 0.85))
		"straw":
			d_rope(ci, mg_center() + Vector2(0, mg_r * (0.78 - mg_progress * 1.56)), p, Color(0.88, 0.74, 0.4), 10)
			for k in 5:
				d_line(ci, p, p + Vector2(0, -34).rotated(-0.5 + k * 0.25), Color(0.9, 0.78, 0.45), 5)
		"ong":
			d_ell(ci, p, 26, 20, Color(0.66, 0.48, 0.3), 0.3)
			d_ell(ci, p + Vector2(-6, -6), 8, 5, Color(1, 1, 1, 0.3), 0.0, 0.0)

func draw_mg_art() -> void:
	var ci: CanvasItem = mg_art
	var key := art_key()
	var c := mg_center()
	var w := mg_overlay.size.x
	var h := mg_overlay.size.y
	var ouch := mg_warn_time > 0.0
	match key:
		"heal":
			draw_swallow(ci, c, mg_r * pop_scale(mg_big), mg_progress, ouch)
		"straw":
			draw_sandal(ci, c, mg_r * pop_scale(mg_big), mg_progress)
		"ong":
			draw_jar(ci, c, mg_r * pop_scale(mg_big), mg_progress, ouch)
		"saw", "ditch":
			var s := mg_r * pop_scale(mg_big)
			var in_sync := is_instance_valid(mg_b) and mg_b.modulate.r < 0.9
			var tool_x := c.x + (mg_pos.x - w * 0.5) * 0.55
			if key == "saw":
				draw_gourd2d(ci, c, s, mg_cfg.get("color", PAPER), mg_progress)
				draw_saw(ci, Vector2(tool_x, c.y - s * 0.9 + mg_progress * s * 1.8), s * 2.3, in_sync)
			else:
				draw_ditch(ci, c, s, mg_progress)
				draw_shovel(ci, Vector2(tool_x, c.y + s * 0.3), s)
			# 박자 길잡이: 나무 판 위 손잡이 두 개
			var ty := h * 0.78
			d_box(ci, Vector2(w * 0.5, ty), Vector2(w * 0.82, 18), 0.0, Color(0.68, 0.5, 0.3), 3)
			if is_instance_valid(mg_a):
				var gx := node_center(mg_a).x
				d_box(ci, Vector2(gx, ty), Vector2(30, 66), 0.0, Color(0.55, 0.35, 0.18), 4)
				ci.draw_string(font, Vector2(gx - 26, ty - 44), tr("흥부") if key == "saw" else tr("첨지"), HORIZONTAL_ALIGNMENT_LEFT, -1, int(font_size * 0.5), INK)
			if mg_touch:
				d_box(ci, Vector2(mg_pos.x, ty), Vector2(30, 66), 0.0, Color(0.6, 0.95, 0.6) if in_sync else Color(0.98, 0.95, 0.85), 4)
		"world":
			draw_world_ui(ci)
		"fish":
			draw_pond_scene(ci)
		"plant":
			draw_plant_scene(ci)
		"snake", "wood", "kim", "sparrow":
			var s := mg_r * 0.8 * pop_scale(mg_big)
			if key == "sparrow":
				draw_rice_field(ci)
				draw_scarecrow2d(ci, c, s * 1.1)
			elif key == "snake":
				draw_nest(ci, c, s)
			elif key == "wood":
				draw_stump(ci, c, s)
			else:
				draw_pumpkin(ci, c, s * 1.1, false, 0.0)
			var life: float = mg_cfg.get("life", 1.5)
			for it in mg_items:
				var b: Control = it[0]
				if not is_instance_valid(b):
					continue
				var p := node_center(b)
				var r := b.size.x * 0.5 * b.scale.x
				var danger := clampf(float(it[1]) / life, 0.0, 1.0)
				if key == "sparrow":
					draw_sparrow2d(ci, p, r * 0.9, danger, sin(anim_t * 20.0) * 0.2 * danger)
				elif key == "snake":
					draw_snake(ci, p, c, r, danger)
				elif key == "wood":
					draw_log(ci, p, r, danger)
				else:
					draw_pumpkin(ci, p, r * 1.15, true, danger)
		"water", "rice":
			for it in mg_items:
				var node: Control = it[0]
				if not is_instance_valid(node):
					continue
				var p := node_center(node)
				var r := node.size.x * 0.5
				if key == "water":
					if it[1]:
						draw_pebble(ci, p, r, p.y * 0.01)
					else:
						draw_drop(ci, p, r)
				else:
					if it[1]:
						draw_paddle(ci, p, r, p.y * 0.02)
					else:
						draw_rice(ci, p, r)
			var bp := Vector2(mg_pos.x, h * 0.78)
			var bs := short_side * 0.11 * pop_scale(mg_a)
			if key == "water":
				draw_bucket(ci, bp, bs, mg_progress)
			else:
				draw_dipper(ci, bp, bs, mg_progress)
	# 효과: 쪼개진 장작, 뽑힌 말뚝, 달아나는 구렁이
	for f in mg_fx:
		var p: Vector2 = f[1]
		var age: float = f[2]
		var a := 1.0 - age / 0.6
		match f[0]:
			"split":
				var r := mg_r * 0.5
				for sx in [-1.0, 1.0]:
					var off := Vector2(sx * age * 260.0, -age * 120.0 + age * age * 500.0)
					var pts := PackedVector2Array()
					for i in 13:
						var an := -PI / 2.0 + PI * i / 12.0
						pts.append(Vector2(cos(an) * sx, sin(an)) * r)
					var rot: float = sx * age * 5.0
					var moved := PackedVector2Array()
					for q in pts:
						moved.append(p + off + q.rotated(rot))
					d_poly(ci, moved, Color(0.9, 0.74, 0.5, a), 3)
			"stake":
				d_box(ci, p + Vector2(age * 80.0, -age * 420.0 + age * age * 300.0), Vector2(mg_r * 0.14, mg_r * 0.6), age * 9.0, Color(0.6, 0.42, 0.24, a), 3)
			"sparrow":
				var sdir: Vector2 = f[3]
				draw_sparrow2d(ci, p + Vector2(sdir.x * 300.0, -420.0) * age, mg_r * 0.3, 0.0, sin(age * 60.0) * 0.9)
			"snake":
				var dir: Vector2 = f[3]
				draw_snake(ci, p + dir * age * 500.0, p + dir * (age * 500.0 + 10.0), mg_r * 0.35, 0.0)
	draw_cursor(ci)

func add_mg_fx(kind: String, at: Vector2) -> void:
	mg_fx.append([kind, at, 0.0, (at - mg_center()).normalized()])

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
		"name": tr("돌이"),
		"ask": [[tr("돌이"), tr("으아앙! 놀부 아저씨가 내 엿을 뺏어 먹었어!")], [tr("돌이"), tr("엿 먹고 싶어... 장터 아저씨가 파는데...")]],
		"wait": tr("훌쩍... 엿은 장터 아저씨가 팔아."),
		"done": tr("우와, 엿이다! 고마워! 이제 안 울게."),
	},
	"suni": {
		"name": tr("순이 엄마"),
		"ask": [[tr("순이 엄마"), tr("놀부가 빨랫줄을 끊어 놔서 빨래가 개울가에 다 흩어졌지 뭐니.")], [tr("순이 엄마"), tr("개울 따라 세 장만 찾아 주겠니?")]],
		"wait": tr("빨래는 개울가를 따라 흩어졌단다."),
		"done": tr("아이고, 다 찾아 왔구나! 고맙다."),
	},
	"kim": {
		"name": tr("김 서방"),
		"ask": [[tr("김 서방"), tr("놀부가 다 익은 호박마다 말뚝을 박아 놨지 뭐냐!")], [tr("김 서방"), tr("말뚝이 보이면 재빨리 눌러서 뽑아 다오.")]],
		"fail": tr("말뚝이 너무 깊이 들어갔구나. 다시 해 보자."),
		"done": tr("호박이 살았다! 고맙다, 얘야."),
		"game": "tap",
		"cfg": {"title": tr("호박에 박힌 말뚝을\n사라지기 전에 눌러 뽑아요"), "goal": 8, "interval": 0.9, "life": 1.9, "target": tr("말뚝"), "center": tr("호박"), "color": Color(0.95, 0.6, 0.2), "art": "world", "world": true, "scene": "kim"},
	},
	"ong": {
		"name": tr("옹기 할멈"),
		"ask": [[tr("옹기 할멈"), tr("놀부가 지나가다 장독을 발로 차서 금이 갔단다.")], [tr("옹기 할멈"), tr("진흙을 살살 돌려 발라 주겠니? 세게 하면 또 깨진단다.")]],
		"fail": tr("에구, 금이 더 갔구나. 다시 살살 해 보자."),
		"done": tr("감쪽같구나! 장맛을 지켰다."),
		"game": "circle",
		"cfg": {"title": tr("깨진 장독 둘레에\n진흙을 살살 돌려 발라요"), "label": tr("장독"), "turns": 5.0, "max_speed": 10.0, "warn": tr("너무 세게 바르면 깨져요!"), "color": Color(0.5, 0.33, 0.2), "art": "world", "world": true, "scene": "ong", "trail": Color(0.66, 0.48, 0.3)},
	},
	"park": {
		"name": tr("박 첨지"),
		"ask": [[tr("박 첨지"), tr("놀부가 제 논에만 물을 대려고 우리 물꼬를 막아 버렸어!")], [tr("박 첨지"), tr("나랑 박자 맞춰 삽질 좀 해 다오.")]],
		"fail": tr("박자가 안 맞아 삽이 엇나갔구나. 다시 해 보자."),
		"done": tr("물이 콸콸 들어온다! 올해 농사는 살았다."),
		"game": "follow",
		"cfg": {"art": "world", "world": true, "scene": "ditch", "title": tr("박 첨지와 박자 맞춰 삽질!\n아래 손잡이를 좌우로 따라가세요"), "slow": 2.0, "tol": 0.4, "goal": 5.0, "patience": 4.0, "color": Color(0.4, 0.6, 0.85)},
	},
}


# ---------- 시작 ----------

# ---------- 언어 (한국어 / English) ----------
# 브라우저나 기기 언어가 한국어면 한국어, 그 밖은 영어로 시작해요. 설정에서 바꾸면 user://lang.cfg 에 남아요.
const LANG_PATH := "user://lang.cfg"

func lang() -> String:
	var cf := ConfigFile.new()
	if cf.load(LANG_PATH) == OK:
		var l: String = cf.get_value("lang", "code", "")
		if l != "":
			return l
	var sys := OS.get_locale_language()
	if OS.has_feature("web"):
		var nl = JavaScriptBridge.eval("(navigator.languages && navigator.languages[0]) || navigator.language || ''", true)
		if nl is String and nl != "":
			sys = nl.substr(0, 2).to_lower()
	return "ko" if sys == "ko" else "en"

func ensure_lang() -> void:
	if Engine.has_meta("jr_lang_ready"):
		return
	Engine.set_meta("jr_lang_ready", true)
	var t := Translation.new()
	t.locale = "en"
	var en: Dictionary = preload("res://lang_en.gd").EN
	for k in en:
		t.add_message(k, en[k])
	TranslationServer.add_translation(t)
	TranslationServer.set_locale(lang())

func set_lang(l: String) -> void:
	var cf := ConfigFile.new()
	cf.set_value("lang", "code", l)
	cf.save(LANG_PATH)
	TranslationServer.set_locale(l)
	leaving_scene = true
	get_tree().reload_current_scene()

# 표 안의 글자만 지금 언어로 바꾼 사본 (id 같은 키는 그대로)
func trd(v: Variant) -> Variant:
	ensure_lang()
	if v is String:
		return TranslationServer.translate(v) if v != "" else v
	if v is Dictionary:
		var d := {}
		for k in v:
			d[k] = trd(v[k])
		return d
	if v is Array:
		var a := []
		for x in v:
			a.append(trd(x))
		return a
	return v

func _ready() -> void:
	ensure_lang()
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

	load_controls()
	# 마지막으로 있던 장이 다른 장이면 그리로 바로 가요 (처음 켤 때 1장 화면이 열리므로)
	var want := saved_chapter()
	if want != "" and want != chapter_id() and CHAPTER_SCENES.has(want) and chapter_id() != "":
		leaving_scene = true
		get_tree().change_scene_to_file.call_deferred(CHAPTER_SCENES[want])
		return
	load_world()
	make_sounds()
	build_chapter()
	apply_ground_splat()
	apply_distance_culling(self)
	if light_mode:
		# 3D 화면은 조금 낮은 해상도로 그리고, 글자와 버튼은 그대로 또렷하게
		get_viewport().scaling_3d_scale = 0.7
	make_player()
	make_ui()
	make_book_ui()
	make_settings_ui()
	make_walk_hint()
	apply_hand()
	after_ui()
	make_game_ui()
	make_fx_ui()
	card_overlay = make_overlay(1.0)
	card_overlay.gui_input.connect(on_card_input)
	card_label = add_label(card_overlay, "", 0.92, 0.13, 0.26, 0.87, 0.74)
	resumed = restore_progress()
	update_quest_text()

	cam = Camera3D.new()
	cam.fov = 64.0
	add_child(cam)
	cam.make_current()
	make_card_scroll()
	start_chapter()

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

# ---------- 고운 질감: 코드로 직접 그린 그림들 ----------
# 한옥. style: "thatch" 초가집 / "tile" 기와집. 앞쪽은 +z 방향

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
var thatch_img: Texture2D
var tile_tex: ImageTexture
var plaster_tex: Texture2D
var house_rects: Array = []

# 블렌더/파이썬으로 미리 그려 둔 질감이 있으면 그걸 쓰고, 없으면 코드로 그려요
func tex_or(name: String, fallback: Texture2D) -> Texture2D:
	var path := "res://textures/%s.png" % name
	if ResourceLoader.exists(path):
		return load(path)
	return fallback

func make_village_materials() -> void:
	var stone_tex: Texture2D = tex_or("stone", make_noise_tex(Color(0.62, 0.62, 0.62), Color(1.0, 1.0, 1.0), 0.09, 17))
	stone_mat = make_tex_material(Color(0.86, 0.84, 0.8), stone_tex, 0.6)
	stone_blob_mat = make_tex_material(Color(1.0, 1.0, 1.0), stone_tex, 0.9)
	stone_blob_mat.vertex_color_use_as_albedo = true
	thatch_tex = make_thatch_tex()
	thatch_img = tex_or("thatch", thatch_tex)
	thatch_blob_mat = make_tex_material(Color(1, 1, 1), thatch_tex, 0.7)
	thatch_blob_mat.vertex_color_use_as_albedo = true
	thatch_dark_mat = make_tex_material(Color(0.8, 0.72, 0.6), thatch_img, 0.8)
	var wtex: Texture2D = tex_or("wood", make_wood_tex(41, 0))
	wood_mat = make_tex_material(Color(0.78, 0.55, 0.36), wtex, 0.7)
	dark_wood_mat = make_tex_material(Color(0.52, 0.35, 0.22), wtex, 0.7)
	plank_mat = make_tex_material(Color(0.95, 0.72, 0.5), tex_or("plank", make_wood_tex(43, 32)), 0.45)
	tile_tex = make_tile_tex()
	lattice_mat = StandardMaterial3D.new()
	lattice_mat.albedo_texture = make_lattice_tex()
	lattice_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	lattice_mat.roughness = 1.0
	basket_mat = make_tex_material(Color(1, 1, 1), make_weave_tex(), 2.2)
	plaster_tex = tex_or("plaster", make_noise_tex(Color(0.88, 0.86, 0.82), Color(1, 1, 1), 0.035, 23))
	load_rocks()

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
				p = Vector3(bx * 1.02, -0.14, bz * 1.02)
				v = vrep + 0.06
			else:
				p = Vector3(bx * 0.96, -0.28, bz * 0.96)
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

# 블렌더로 만든 초가집 모델 (models/choga.glb). 없으면 코드로 그린 집을 써요
var choga_scene: PackedScene = null
var choga_tried := false

func thatch_roof_mat(roof: Color) -> StandardMaterial3D:
	var tm := StandardMaterial3D.new()
	tm.albedo_texture = thatch_img
	tm.albedo_color = Color(1, 1, 1).lerp(roof * 1.25, 0.12)
	tm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	tm.cull_mode = BaseMaterial3D.CULL_DISABLED
	tm.roughness = 1.0
	return tm

var house_scenes := {}
var house_ao_cache := {}
var endgrain_cache: StandardMaterial3D

# 나이테가 보이는 나무 단면 (UV로 붙여요)
func endgrain_mat() -> StandardMaterial3D:
	if endgrain_cache == null:
		endgrain_cache = StandardMaterial3D.new()
		endgrain_cache.albedo_texture = tex_or("endgrain", null)
		endgrain_cache.albedo_color = Color(1.0, 0.95, 0.88)
		endgrain_cache.roughness = 0.95
	return endgrain_cache

# 블렌더로 만든 소품 하나를 놓아요 (재질 이름에 맞춰 게임 재질을 입혀요)
func place_prop(parent: Node3D, file: String, pos: Vector3, s: float = 1.0, c: Color = Color(0.45, 0.27, 0.16), rot_y: float = 0.0) -> bool:
	if not ResourceLoader.exists("res://models/%s.glb" % file):
		return false
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation.y = rot_y
	parent.add_child(holder)
	return make_choga_from_model(holder, Vector3(s, s, s), c, Color(0.8, 0.66, 0.3), file, Vector3(1, 1, 1))

func make_choga_from_model(house: Node3D, size: Vector3, wall: Color, roof: Color, file: String = "choga", base: Vector3 = Vector3(4.5, 2.8, 3.5)) -> bool:
	if not house_scenes.has(file):
		house_scenes[file] = null
		if ResourceLoader.exists("res://models/%s.glb" % file):
			house_scenes[file] = load("res://models/%s.glb" % file)
	if house_scenes[file] == null:
		return false
	var inst := (house_scenes[file] as PackedScene).instantiate() as Node3D
	inst.scale = Vector3(size.x / base.x, size.y / base.y, size.z / base.z)
	house.add_child(inst)
	var paper := make_color(Color(0.98, 0.95, 0.86))
	paper.emission_enabled = true
	paper.emission = Color(1.0, 0.95, 0.8)
	paper.emission_energy_multiplier = 0.12
	var tile_base := make_color(roof.darkened(0.25))
	tile_base.cull_mode = BaseMaterial3D.CULL_DISABLED
	var map := {
		"Thatch": thatch_roof_mat(roof), "ThatchDark": thatch_dark_mat, "Plaster": plaster_mat(wall),
		"Wood": wood_mat, "DarkWood": dark_wood_mat, "Plank": plank_mat, "Stone": stone_mat, "Paper": paper,
		"Rope": make_color(Color(0.5, 0.37, 0.2)), "Clay": make_tex_material(Color(0.66, 0.52, 0.38), plaster_tex, 0.6),
		"Straw": make_tex_material(Color(1.0, 0.94, 0.82), thatch_img, 1.0),
		"Tile": glossy_mat(Color(minf(roof.r * 1.35, 1.0), minf(roof.g * 1.35, 1.0), minf(roof.b * 1.35, 1.0))),
		"TileBase": tile_base, "Lime": make_color(Color(0.95, 0.94, 0.9)),
		"Paint": make_color(Color(0.32, 0.58, 0.48)), "PaintRed": make_color(Color(0.72, 0.28, 0.22)),
		"PaintBlack": make_color(Color(0.1, 0.09, 0.09)), "Bark": dark_wood_mat,
		"Onggi": glossy_mat(wall), "OnggiDark": glossy_mat(wall.darkened(0.3)),
		"Iron": make_color(Color(0.48, 0.5, 0.54)), "EndGrain": endgrain_mat(),
	}
	var hanji: Texture2D = tex_or("hanji", null)
	if hanji != null:
		paper.albedo_texture = hanji
		paper.uv1_triplanar = true
		paper.uv1_world_triplanar = true
		paper.uv1_scale = Vector3(1.5, 1.5, 1.5)
	var mottle: Texture2D = tex_or("tile_mottle", null)
	if mottle != null:
		var tile_m: StandardMaterial3D = map["Tile"]
		tile_m.albedo_texture = mottle
		tile_m.uv1_triplanar = true
		tile_m.uv1_world_triplanar = true
		tile_m.uv1_scale = Vector3(0.6, 0.6, 0.6)
	# 블렌더에서 구운 그늘(꼭짓점 색)을 곱해 줘요
	if not house_ao_cache.has(file):
		house_ao_cache[file] = {}
	var cache: Dictionary = house_ao_cache[file]
	for node in inst.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var has_ao := false
		for i in mi.mesh.get_surface_count():
			var arrays: int = mi.mesh.surface_get_format(i)
			if arrays & Mesh.ARRAY_FORMAT_COLOR:
				has_ao = true
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i)
			var key := m.resource_name if m != null else ""
			if map.has(key):
				var use: Material = map[key]
				if has_ao and use is StandardMaterial3D:
					var ck := "%s|%d" % [key, (use as Object).get_instance_id()]
					if not cache.has(ck):
						var dup := (use as StandardMaterial3D).duplicate() as StandardMaterial3D
						dup.vertex_color_use_as_albedo = true
						cache[ck] = dup
					use = cache[ck]
				mi.set_surface_override_material(i, use)
	return true

# 가난한 흥부네 초가: 바랜 나무, 기운 창호지, 금 간 벽, 군데군데 삭은 지붕, 받침대로 버틴 처마
func make_hut_shabby(house: Node3D) -> void:
	var weather := Color(0.8, 0.76, 0.7)
	for mi in house.find_children("*", "MeshInstance3D", true, false):
		var m3 := mi as MeshInstance3D
		m3.rotation.z = 0.022
		m3.rotation.x = -0.012
		for i in m3.mesh.get_surface_count():
			var cur := m3.get_surface_override_material(i)
			if cur is StandardMaterial3D:
				var d := (cur as StandardMaterial3D).duplicate() as StandardMaterial3D
				var key := ""
				var base_m := m3.mesh.surface_get_material(i)
				if base_m != null:
					key = base_m.resource_name
				var tint := weather
				if key == "Paper":
					tint = Color(0.92, 0.86, 0.7)
					d.emission_energy_multiplier = 0.03
				# 볕과 비에 바래서 잿빛이 도는 나무와 짚
				var greys := {"Wood": Color(0.5, 0.43, 0.37), "DarkWood": Color(0.36, 0.31, 0.27), "Plank": Color(0.56, 0.49, 0.42),
					"Thatch": Color(0.64, 0.6, 0.56), "ThatchDark": Color(0.5, 0.46, 0.42), "Straw": Color(0.66, 0.6, 0.54)}
				if greys.has(key):
					d.albedo_color = greys[key]
				else:
					d.albedo_color = d.albedo_color * tint
				m3.set_surface_override_material(i, d)
	var dirt := Color(0.36, 0.3, 0.24)
	# 창호지 기운 자국과 구멍
	for pt in [[Vector2(-1.45, 1.55), Vector2(0.26, 0.2), Color(0.74, 0.64, 0.45)], [Vector2(-0.95, 0.95), Vector2(0.2, 0.24), Color(0.8, 0.72, 0.54)],
			[Vector2(0.75, 1.7), Vector2(0.3, 0.18), Color(0.72, 0.62, 0.44)], [Vector2(1.15, 1.05), Vector2(0.18, 0.2), Color(0.78, 0.7, 0.52)],
			[Vector2(-1.15, 1.85), Vector2(0.09, 0.07), Color(0.18, 0.14, 0.1)], [Vector2(0.95, 0.75), Vector2(0.07, 0.1), Color(0.18, 0.14, 0.1)]]:
		var v: Vector2 = pt[0]
		var sz: Vector2 = pt[1]
		add_box(house, pt[2], Vector3(sz.x, sz.y, 0.012), Vector3(v.x, v.y, 1.8))
	# 벽의 금 (지그재그)
	for crack in [[Vector3(-0.05, 2.3, 1.76), [Vector2(0.06, -0.25), Vector2(-0.08, -0.22), Vector2(0.05, -0.3)]],
			[Vector3(1.95, 1.9, 1.76), [Vector2(-0.1, -0.2), Vector2(0.07, -0.28), Vector2(-0.05, -0.2), Vector2(0.06, -0.25)]],
			[Vector3(2.25, 2.2, 0.9), [Vector2(-0.12, -0.24), Vector2(0.1, -0.3), Vector2(-0.08, -0.26)]],
			[Vector3(2.25, 1.3, -0.6), [Vector2(0.15, -0.22), Vector2(-0.1, -0.2)]]]:
		var at: Vector3 = crack[0]
		var side_wall := at.x > 2.2
		for seg in crack[1]:
			var dv: Vector2 = seg
			var to := at + (Vector3(0, dv.y, dv.x) if side_wall else Vector3(dv.x, dv.y, 0))
			add_beam(house, make_color(Color(0.3, 0.25, 0.2)), at, to, 0.018, 0.018)
			at = to
	# 흙으로 덕지덕지 메운 벽
	add_blobs(house, [
		[Vector3(1.55, 0.75, 1.75), Vector3(0.45, 0.32, 0.05), Color(0.62, 0.5, 0.36)],
		[Vector3(2.25, 0.9, 0.2), Vector3(0.05, 0.4, 0.55), Color(0.6, 0.48, 0.34)],
		[Vector3(-2.24, 1.4, 0.6), Vector3(0.05, 0.35, 0.45), Color(0.64, 0.52, 0.38)],
	])
	# 처마가 내려앉아 막대기로 받쳐 놨어요
	var pole_mat := make_color(Color(0.45, 0.36, 0.26))
	add_beam(house, pole_mat, Vector3(2.95, 0.0, 2.55), Vector3(2.85, 2.5, 2.45), 0.08, 0.08)
	add_beam(house, make_color(Color(0.55, 0.45, 0.3)), Vector3(2.78, 1.5, 2.43), Vector3(2.98, 1.62, 2.55), 0.04, 0.1)
	add_beam(house, pole_mat, Vector3(-3.0, 0.0, 2.5), Vector3(-2.9, 2.45, 2.42), 0.07, 0.07)
	# 깨진 독과 낡은 지게
	var jar := Node3D.new()
	jar.position = Vector3(-2.75, 0, 1.2)
	house.add_child(jar)
	add_mcyl(jar, glossy_mat(Color(0.42, 0.3, 0.22)), 0.2, 0.17, 0.35, Vector3(0, 0.17, 0))
	add_box(jar, Color(0.2, 0.15, 0.12), Vector3(0.12, 0.14, 0.03), Vector3(0.1, 0.25, 0.18))
	var shard := add_mbox(jar, glossy_mat(Color(0.42, 0.3, 0.22)), Vector3(0.18, 0.03, 0.12), Vector3(0.38, 0.02, 0.1))
	shard.rotation.y = 0.6

func make_house(pos: Vector3, size: Vector3, wall: Color, roof: Color, style: String = "thatch") -> Node3D:
	var house := StaticBody3D.new()
	house.position = pos
	add_child(house)
	house_rects.append(Rect2(pos.x - size.x / 2.0 - 0.7, pos.z - size.z / 2.0 - 0.7, size.x + 1.4, size.z + 2.6))
	var modeled := false
	if style == "thatch":
		modeled = make_choga_from_model(house, size, wall, roof)
	else:
		modeled = make_choga_from_model(house, size, wall, roof, "giwa", Vector3(9, 4, 6))
	if modeled:
		var mcol := CollisionShape3D.new()
		var mshape := BoxShape3D.new()
		mshape.size = size
		mcol.shape = mshape
		mcol.position.y = size.y / 2.0
		house.add_child(mcol)
		return house
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
		if sx < 0.0 and pos.is_equal_approx(Vector3(-13, 0, -2)) and style == "thatch":
			continue
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
		soft_gloss_mat.roughness = 0.55
		soft_gloss_mat.metallic_specular = 0.35
	return soft_gloss_mat

# 넓적한 잎사귀 몇 장 (땅에 깔림)
func leaf_items(center: Vector3, count: int, size: float, r: RandomNumberGenerator, c: Color) -> Array:
	var items := []
	for i in count:
		var a := i * TAU / count + r.randf_range(-0.3, 0.3)
		var d := size * r.randf_range(0.7, 1.0)
		items.append([center + Vector3(cos(a) * d, 0.06 + r.randf() * 0.06, sin(a) * d), Vector3(size * 1.1, 0.06, size * 0.8), c.lightened(r.randf() * 0.12), Vector3(r.randf_range(-12, 12), -rad_to_deg(a), 0)])
	return items

# 가시덤불: 작은 잎 뭉치와 삐죽한 가시 가지
func make_thorn_shrubs(parent: Node3D, size: Vector3, c: Color) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = int(parent.position.x * 7.0 + parent.position.z * 3.0)
	if not tree_tried:
		load_trees()
	var n := int(maxf(size.x, size.z) * 6.0) + 4
	var mi := MeshInstance3D.new()
	mi.mesh = leaf_bush_mesh(size, c, n, r)
	mi.material_override = leaf_mat
	parent.add_child(mi)
	# 가시 돋친 덩굴 가지
	var thorn := make_color(Color(0.36, 0.24, 0.16))
	var spike := make_color(Color(0.62, 0.5, 0.36))
	for i in int(n / 2):
		var a := Vector3(r.randf_range(-0.5, 0.5) * size.x, r.randf_range(-0.45, 0.2) * size.y, r.randf_range(-0.5, 0.5) * size.z)
		var b := a + Vector3(r.randf_range(-0.6, 0.6), r.randf_range(0.3, 0.7), r.randf_range(-0.6, 0.6))
		var m := (a + b) * 0.5 + Vector3(r.randf_range(-0.15, 0.15), 0.12, r.randf_range(-0.15, 0.15))
		add_beam(parent, thorn, a, m, 0.025, 0.025)
		add_beam(parent, thorn, m, b, 0.02, 0.02)
		for k in 3:
			var at := a.lerp(m, 0.3 + k * 0.35) if k < 2 else m.lerp(b, 0.5)
			var out := Vector3(r.randf_range(-1, 1), r.randf_range(-0.2, 0.6), r.randf_range(-1, 1)).normalized() * 0.09
			add_beam(parent, spike, at, at + out, 0.012, 0.004)

# 잎 그림 카드를 엇갈려 꽂아 만든 덤불 (나무 잎과 같은 그림)
func leaf_bush_mesh(size: Vector3, tint: Color, n: int, r: RandomNumberGenerator) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var regions := [Rect2(0.02, 0.03, 0.47, 0.45), Rect2(0.52, 0.56, 0.47, 0.42)]
	for i in n:
		var ctr := Vector3(r.randf_range(-0.5, 0.5) * size.x, r.randf_range(-0.42, 0.3) * size.y, r.randf_range(-0.5, 0.5) * size.z)
		var sz := r.randf_range(0.8, 1.2)
		var reg: Rect2 = regions[r.randi() % 2]
		var col := tint.lightened(r.randf() * 0.2 + (ctr.y / size.y + 0.5) * 0.25)
		var yaw := r.randf() * PI
		for q in 2:
			var bas := Basis(Vector3.UP, yaw + q * PI / 2.0) * Basis(Vector3(1, 0, 0), r.randf_range(-0.35, 0.35))
			var rx := bas * Vector3(sz * 0.5, 0, 0)
			var ry := bas * Vector3(0, sz * 0.5, 0)
			var nrm := bas * Vector3(0, 0.4, 1).normalized()
			var corners := [[ctr - rx - ry, Vector2(reg.position.x, reg.end.y)], [ctr + rx - ry, reg.end], [ctr + rx + ry, Vector2(reg.end.x, reg.position.y)], [ctr - rx + ry, reg.position]]
			for idx in [0, 1, 2, 0, 2, 3]:
				var v: Array = corners[idx]
				st.set_color(col)
				st.set_normal(nrm)
				st.set_uv(v[1])
				st.add_vertex(v[0])
	return st.commit()

# ---------- 맵 가장자리: 둘러 심은 나무, 다음 이야기로 가는 장승과 이정표 ----------

func make_jangseung(pos: Vector3, female: bool) -> void:
	var root := StaticBody3D.new()
	root.position = pos
	root.rotation.y = randf_range(-0.08, 0.08)
	add_child(root)
	var carved := place_prop(root, "prop_jangseung_f" if female else "prop_jangseung_m", Vector3.ZERO)
	if carved:
		var col2 := CollisionShape3D.new()
		var cs2 := CylinderShape3D.new()
		cs2.radius = 0.32
		cs2.height = 2.8
		col2.shape = cs2
		col2.position.y = 1.4
		root.add_child(col2)
		var lab2 := Label3D.new()
		lab2.text = tr("지\n하\n여\n장\n군") if female else tr("천\n하\n대\n장\n군")
		lab2.font = font
		lab2.font_size = 44
		lab2.modulate = Color(0.15, 0.08, 0.05)
		lab2.outline_size = 0
		lab2.position = Vector3(0, 1.0, 0.25)
		lab2.pixel_size = 0.0042
		root.add_child(lab2)
		return
	add_mcyl(root, wood_mat, 0.26, 0.3, 2.6, Vector3(0, 1.3, 0))
	add_mcyl(root, make_color(Color(0.65, 0.15, 0.12) if female else Color(0.12, 0.1, 0.1)), 0.3, 0.28, 0.42, Vector3(0, 2.75, 0))
	add_mcyl(root, make_color(Color(0.65, 0.15, 0.12) if female else Color(0.12, 0.1, 0.1)), 0.42, 0.42, 0.06, Vector3(0, 2.55, 0))
	var face := []
	for sx in [-1.0, 1.0]:
		face.append([Vector3(sx * 0.12, 2.2, 0.22), Vector3(0.18, 0.16, 0.08), Color(1, 1, 1)])
		face.append([Vector3(sx * 0.12, 2.2, 0.26), Vector3(0.08, 0.08, 0.05), Color(0.08, 0.06, 0.05)])
		face.append([Vector3(sx * 0.13, 2.36, 0.22), Vector3(0.2, 0.05, 0.06), Color(0.1, 0.08, 0.07), Vector3(0, 0, sx * -18.0)])
		face.append([Vector3(sx * 0.15, 2.0, 0.24), Vector3(0.1, 0.07, 0.04), Color(0.85, 0.3, 0.25)])
	face.append([Vector3(0, 2.05, 0.28), Vector3(0.1, 0.18, 0.1), Color(0.7, 0.5, 0.32)])
	face.append([Vector3(0, 1.82, 0.25), Vector3(0.24, 0.07, 0.06), Color(0.15, 0.08, 0.06)])
	face.append([Vector3(0, 1.84, 0.27), Vector3(0.18, 0.03, 0.03), Color(1, 1, 1)])
	add_blobs(root, face)
	var lab := Label3D.new()
	lab.text = tr("지\n하\n여\n장\n군") if female else tr("천\n하\n대\n장\n군")
	lab.font = font
	lab.font_size = 48
	lab.modulate = Color(0.15, 0.08, 0.05)
	lab.outline_size = 0
	lab.position = Vector3(0, 1.0, 0.31)
	lab.pixel_size = 0.0045
	root.add_child(lab)
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.32
	shape.height = 2.8
	col.shape = shape
	col.position.y = 1.4
	root.add_child(col)

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
	var water := add_mcyl(n, water_material(1, Vector4(n.position.x, n.position.z, 0.66, 0.66), Color(0.08, 0.2, 0.28), Color(0.18, 0.34, 0.4), Vector2.ZERO, 0.3), 0.66, 0.66, 0.04, Vector3(0, 0.62, 0))
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if not place_prop(n, "prop_wellring", Vector3.ZERO):
		add_mcyl(n, stone_mat, 0.78, 0.85, 0.85, Vector3(0, 0.42, 0))
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
	n.set_meta("rope", add_beam(n, make_color(Color(0.7, 0.6, 0.42)), Vector3(0.2, 1.75, 0), Vector3(0.2, 1.25, 0), 0.025, 0.025))
	n.set_meta("bucket", add_mcyl(n, wood_mat, 0.17, 0.14, 0.26, Vector3(0.2, 1.12, 0)))

func make_haystack_visual(n: Node3D) -> void:
	if place_prop(n, "prop_hay", Vector3.ZERO):
		for i in 3:
			var sheaf2 := add_mcyl(n, thatch_dark_mat, 0.14, 0.2, 0.9, Vector3(-1.2 + i * 0.25, 0.45, 0.75))
			sheaf2.rotation.z = (i - 1) * 0.15
		add_blobs(n, [[Vector3(0.95, 0.06, 0.85), Vector3(0.22, 0.1, 0.42), Color(0.86, 0.7, 0.4)], [Vector3(1.2, 0.06, 0.9), Vector3(0.22, 0.1, 0.42), Color(0.86, 0.7, 0.4)]], thatch_blob_mat)
		return
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
	if place_prop(n, "prop_stump", Vector3.ZERO, 1.0, Color(0.45, 0.27, 0.16), 0.4):
		# 그루터기에 비스듬히 꽂힌 도끼 (나무하기 할 때는 손에 들어요)
		var axe := Node3D.new()
		axe.position = Vector3(0.05, 0.72, 0.0)
		axe.rotation = Vector3(0, 0.4, -0.35)
		n.add_child(axe)
		add_mcyl(axe, wood_mat, 0.035, 0.03, 0.8, Vector3(0, 0.38, 0))
		add_mbox(axe, make_color(Color(0.5, 0.52, 0.56)), Vector3(0.05, 0.17, 0.26), Vector3(0, 0.06, 0.0))
		n.set_meta("axe", axe)
		return
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

# ---------- 자연스러운 흙길과 개울 ----------

var path_lines: Array = []   # [[점들(Vector2)], 폭]

# 개울 한가운데 z (x 에 따라 살짝 굽이쳐요)
func creek_z(x: float) -> float:
	return -15.5 + sin(x * 0.21) * 0.16 + sin(x * 0.53 + 1.3) * 0.08

func creek_half(x: float) -> float:
	return 1.32 + sin(x * 0.37 + 0.7) * 0.12 + sin(x * 0.91) * 0.06

# 점들을 부드러운 곡선으로 이어요 (캣멀-롬)
func smooth_line(pts: Array, step: float) -> Array:
	var out := []
	for i in pts.size() - 1:
		var p0: Vector2 = pts[maxi(i - 1, 0)]
		var p1: Vector2 = pts[i]
		var p2: Vector2 = pts[i + 1]
		var p3: Vector2 = pts[mini(i + 2, pts.size() - 1)]
		var n := maxi(2, int(p1.distance_to(p2) / step))
		for k in n:
			var t := float(k) / n
			var t2 := t * t
			var t3 := t2 * t
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	out.append(pts[pts.size() - 1])
	return out

# 굽은 띠 모양 땅 (가장자리가 울퉁불퉁, 양 끝은 둥글게)
func build_ribbon(line: Array, width: float, y: float, seed_v: float, round_ends: bool) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lefts := []
	var rights := []
	var dist := 0.0
	for i in line.size():
		var p: Vector2 = line[i]
		var a: Vector2 = line[maxi(i - 1, 0)]
		var b: Vector2 = line[mini(i + 1, line.size() - 1)]
		var dir := (b - a).normalized()
		var nrm := Vector2(-dir.y, dir.x)
		if i > 0:
			dist += p.distance_to(line[i - 1])
		var wl := width * 0.5 * (1.0 + 0.16 * sin(dist * 0.9 + seed_v) + 0.08 * sin(dist * 2.3 + seed_v * 2.0))
		var wr := width * 0.5 * (1.0 + 0.16 * sin(dist * 0.8 + seed_v + 2.0) + 0.08 * sin(dist * 2.7 + seed_v))
		lefts.append(p + nrm * wl)
		rights.append(p - nrm * wr)
	for i in line.size() - 1:
		var l0: Vector2 = lefts[i]
		var l1: Vector2 = lefts[i + 1]
		var r0: Vector2 = rights[i]
		var r1: Vector2 = rights[i + 1]
		for v in [l0, r0, l1, r0, r1, l1]:
			st.set_normal(Vector3.UP)
			st.add_vertex(Vector3(v.x, y, v.y))
	if round_ends:
		for e in [0, line.size() - 1]:
			var c: Vector2 = line[e]
			var other: Vector2 = line[1] if e == 0 else line[line.size() - 2]
			var back := (c - other).normalized()
			var rad := width * 0.5
			var prev := c + Vector2(-back.y, back.x) * rad
			for k in range(1, 9):
				var ang := PI * k / 8.0
				var nxt := c + (Vector2(-back.y, back.x) * cos(ang) + back * sin(ang)) * rad
				for v in [c, nxt, prev]:
					st.set_normal(Vector3.UP)
					st.add_vertex(Vector3(v.x, y, v.y))
				prev = nxt
	return st.commit()

func add_ribbon(line: Array, width: float, y: float, mat: Material, seed_v: float, round_ends: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = build_ribbon(line, width, y, seed_v, round_ends)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi

func make_dirt_path(pts: Array, width: float, seed_v: float) -> void:
	var line := smooth_line(pts, 0.5)
	path_lines.append([line, width])
	var worn := make_tex_material(Color(0.66, 0.72, 0.44), sand_mat.albedo_texture, 0.07)
	worn.cull_mode = BaseMaterial3D.CULL_DISABLED
	var dirt := sand_mat.duplicate() as StandardMaterial3D
	dirt.cull_mode = BaseMaterial3D.CULL_DISABLED
	# 바깥: 풀이 닳은 자리, 안: 흙, 가운데: 발길에 다져진 자국
	# 흙길 자체는 땅 셰이더가 그려요 (apply_ground_splat). 여기서는 돌멩이만
	# 길 위 자갈과 길가 돌멩이
	var r := RandomNumberGenerator.new()
	r.seed = int(seed_v * 100.0)
	var stones := []
	for i in range(0, line.size(), 2):
		var p: Vector2 = line[i]
		if r.randf() < 0.55:
			var off := Vector2(r.randf_range(-1, 1), r.randf_range(-1, 1)) * width * 0.42
			stones.append([Vector3(p.x + off.x, 0.04, p.y + off.y), Vector3(r.randf_range(0.08, 0.2), 0.06, r.randf_range(0.08, 0.16)), stone_color(r)])
		if r.randf() < 0.12:
			var a: Vector2 = line[mini(i + 1, line.size() - 1)] - p
			var side := Vector2(-a.y, a.x).normalized() * (width * 0.62) * (1.0 if r.randf() < 0.5 else -1.0)
			stones.append([Vector3(p.x + side.x, 0.08, p.y + side.y), Vector3(r.randf_range(0.3, 0.5), 0.2, r.randf_range(0.25, 0.4)), stone_color(r)])
	add_blobs(self, stones, stone_blob_mat, true)

func near_path(p: Vector2, extra: float) -> bool:
	for pl in path_lines:
		var line: Array = pl[0]
		var lim: float = pl[1] * 0.5 + extra
		for i in range(0, line.size(), 2):
			if p.distance_squared_to(line[i]) < lim * lim:
				return true
	return false

# ---------- 이어하기: 진행 저장 (모든 장이 하나의 세계로 이어져요) ----------
# save.cfg 안의 칸
#   [world]  모든 장이 함께 쓰는 것: 지금 있는 장, 엽전, 가진 물건, 입은 옷
#   [ch1_state], [ch2_state] ...  장마다의 이야기 진행 (각 장 스크립트가 채워요)
const SAVE_PATH := "user://save.cfg"
const SAVE_VERSION := 1
const CHAPTER_SCENES := {"ch1": "res://main.tscn", "ch2": "res://chapter2.tscn", "ch3": "res://chapter3.tscn"}
var resumed := false
var save_timer := 0.0
var leaving_scene := false

# 이 장의 이름 ("ch1", "ch2" ...)
func chapter_id() -> String:
	return ""

# 이 장의 진행을 사전으로 (각 장이 덮어써요)
func chapter_state() -> Dictionary:
	return {}

# 저장된 사전으로 이 장을 되살려요 (각 장이 덮어써요)
func restore_chapter_state(_d: Dictionary) -> void:
	pass

func load_world() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) != OK:
		return
	coins = cf.get_value("world", "coins", 0)
	shown_coins = coins
	has_yeot = cf.get_value("world", "has_yeot", false)
	has_shoes = cf.get_value("world", "has_shoes", false)
	has_sickle = cf.get_value("world", "has_sickle", false)
	has_hanbok = cf.get_value("world", "has_hanbok", false)

func saved_chapter() -> String:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) != OK:
		return ""
	return cf.get_value("world", "chapter", "")

func save_progress() -> void:
	if chapter_id() == "" or leaving_scene:
		return
	var cf := ConfigFile.new()
	cf.load(SAVE_PATH)
	cf.set_value("world", "version", SAVE_VERSION)
	cf.set_value("world", "chapter", chapter_id())
	cf.set_value("world", "coins", coins)
	cf.set_value("world", "has_yeot", has_yeot)
	cf.set_value("world", "has_shoes", has_shoes)
	cf.set_value("world", "has_sickle", has_sickle)
	cf.set_value("world", "has_hanbok", has_hanbok)
	var st := chapter_state()
	if player != null:
		st["pos"] = player.position
		st["yaw"] = cam_yaw_target
	cf.set_value(chapter_id() + "_state", "data", st)
	cf.save(SAVE_PATH)
	save_timer = 0.0

# 저장된 진행이 있으면 되살리고 true
func restore_progress() -> bool:
	if has_hanbok and player_body != null:
		recolor_outfit(player_body, Color(0.45, 0.78, 0.72))
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) != OK:
		return false
	var st: Dictionary = cf.get_value(chapter_id() + "_state", "data", {})
	if st.is_empty():
		return false
	restore_chapter_state(st)
	var pos: Vector3 = st.get("pos", Vector3(0, -100, 0))
	if pos.y > -5.0:
		player.position = pos + Vector3(0, 0.3, 0)
		cam_yaw = st.get("yaw", 0.0)
		cam_yaw_target = cam_yaw
	return true

# 다른 장으로 옮겨 가요 (지금 장을 저장하고, 다음에 켜면 그 장에서 이어져요)
func go_to_chapter(id: String) -> void:
	save_progress()
	var cf := ConfigFile.new()
	cf.load(SAVE_PATH)
	cf.set_value("world", "chapter", id)
	cf.save(SAVE_PATH)
	leaving_scene = true
	# 다음 장을 짓는 동안 화면이 멈춰 보이지 않게, 두루마리를 먼저 펼쳐 둬요
	show_card(tr("책장을 넘기는 중..."), 1.0, 30.0, Callable())
	await get_tree().create_timer(0.9).timeout
	get_tree().change_scene_to_file(CHAPTER_SCENES[id])

# 이야기 진행만 지우고 처음부터 (도감, 엔딩, 설정은 남겨요)
# 지금 장의 이야기만 처음으로 (엽전·물건·다른 장 진행은 그대로)
func reset_chapter() -> void:
	var id := chapter_id()
	if id == "":
		return
	var cf := ConfigFile.new()
	cf.load(SAVE_PATH)
	if cf.has_section(id + "_state"):
		cf.erase_section(id + "_state")
	cf.save(SAVE_PATH)
	leaving_scene = true
	get_tree().change_scene_to_file(CHAPTER_SCENES[id])

func reset_progress() -> void:
	var cf := ConfigFile.new()
	cf.load(SAVE_PATH)
	for sec in cf.get_sections():
		if sec == "world" or sec.ends_with("_state"):
			cf.erase_section(sec)
	cf.save(SAVE_PATH)
	leaving_scene = true
	get_tree().change_scene_to_file(CHAPTER_SCENES["ch1"])

# 화면 돌리기·가까이 보기 안내 (한 번만)
func update_cam_hint(delta: float) -> void:
	if cam_hint_seen or chapter_id() == "":
		return
	if is_busy() or mg_active or in_card or (walk_hint != null and walk_hint.visible):
		cam_hint_timer = 0.0
		return
	cam_hint_timer += delta
	if cam_hint_timer > 4.0:
		cam_hint_seen = true
		save_controls()
		say([["", tr("두 손가락을 화면에 대고 비틀면 화면이 돌아가요.\n벌리면 가까이, 오므리면 멀리 보여요.\n아주 가까이 당기면 하늘도 올려다볼 수 있어요!") if is_touch_device() else tr("마우스 오른쪽 버튼을 누른 채 끌면 시야가 돌아가요.\n마우스 휠로 가까이, 멀리 볼 수 있어요.\n아주 가까이 당기면 하늘도 올려다볼 수 있어요!")]], Callable())

func update_autosave(delta: float) -> void:
	save_timer += delta
	if save_timer > 5.0 and not mg_active and not is_busy() and chapter_id() != "":
		save_progress()

func _notification(what: int) -> void:
	# 마우스가 게임 화면 밖으로 나가거나 창을 벗어나면, 누르고 있던 마우스 버튼을 모두 뗀 것으로 쳐요
	# (화면 밖에서 버튼을 떼면 게임이 그 신호를 못 받아서 계속 눌린 것처럼 되기 때문이에요)
	if what in [NOTIFICATION_WM_MOUSE_EXIT, NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		release_mouse_holds()
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if player != null and not mg_active:
			save_progress()

# ---------- 해와 하늘 (모든 장 공통) ----------

var sun_light: DirectionalLight3D
var sky_mat_ref: ProceduralSkyMaterial
var env_ref: Environment
var star_node: MeshInstance3D
var time_of_day := 0.0

func make_light_and_sky() -> void:
	var sun := DirectionalLight3D.new()
	sun_light = sun
	sun.rotation_degrees = Vector3(-46, 36, 0)
	# 늦은 오후 같은 따뜻한 햇빛
	sun.light_color = Color(1.0, 0.9, 0.74)
	sun.light_energy = 0.82
	# 부드러운 그림자 (가까운 곳만 그려서 가볍게)
	sun.shadow_enabled = SHADOWS_ON
	sun.shadow_blur = 2.2
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.0
	sun.shadow_opacity = 0.85
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
	sky_mat_ref = sky_mat
	# 위는 맑은 파랑, 지평선은 따뜻한 크림빛
	sky_mat.sky_top_color = Color(0.33, 0.58, 0.9)
	sky_mat.sky_horizon_color = Color(0.93, 0.9, 0.82)
	sky_mat.sky_curve = 0.12
	sky_mat.ground_horizon_color = Color(0.8, 0.84, 0.72)
	sky_mat.ground_bottom_color = Color(0.5, 0.62, 0.45)
	sky_mat.sun_angle_max = 20.0
	sky.sky_material = sky_mat
	# 하늘빛이 바뀔 때 다시 그리는 반사 지도를 작게 해서 버벅이지 않게
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	e.sky = sky
	# 하늘빛으로 은은하게 밝혀서, 그늘은 살짝 푸르고 해 드는 곳은 따뜻해요
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_sky_contribution = 0.55
	e.ambient_light_color = Color(1.0, 0.95, 0.86)
	e.ambient_light_energy = 0.62
	# 멀리는 따뜻하게 뿌옇게 (공기감)
	e.fog_enabled = true
	e.fog_light_color = Color(0.86, 0.88, 0.86)
	e.fog_light_energy = 1.0
	e.fog_sun_scatter = 0.18
	e.fog_density = 0.0024
	e.fog_sky_affect = 0.0
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = 1.04
	e.tonemap_white = 5.0
	e.adjustment_enabled = true
	e.adjustment_saturation = 1.1
	e.adjustment_contrast = 1.04
	env.environment = e
	env_ref = e
	add_child(env)

# 하루의 시간대: 0 = 한낮, 0.5 = 늦은 오후, 0.68 = 노을, 0.82 = 해 질 녘, 1 = 깊은 밤
const TOD_KEYS := [
	[0.0, -46.0, Color(1.0, 0.9, 0.74), 0.82, Color(0.33, 0.58, 0.9), Color(0.93, 0.9, 0.82), Color(0.86, 0.88, 0.86), 0.62, Color(1.0, 0.95, 0.86)],
	[0.5, -24.0, Color(1.0, 0.8, 0.58), 0.8, Color(0.36, 0.54, 0.84), Color(0.98, 0.84, 0.66), Color(0.92, 0.84, 0.74), 0.58, Color(1.0, 0.9, 0.78)],
	[0.68, -9.0, Color(1.0, 0.56, 0.32), 0.7, Color(0.34, 0.36, 0.62), Color(1.0, 0.58, 0.36), Color(0.92, 0.6, 0.46), 0.5, Color(1.0, 0.78, 0.66)],
	[0.82, -4.0, Color(0.8, 0.45, 0.4), 0.18, Color(0.12, 0.13, 0.3), Color(0.44, 0.3, 0.42), Color(0.36, 0.3, 0.42), 0.42, Color(0.7, 0.66, 0.86)],
	[1.0, -52.0, Color(0.58, 0.68, 1.0), 0.32, Color(0.03, 0.04, 0.12), Color(0.1, 0.12, 0.26), Color(0.1, 0.12, 0.22), 0.42, Color(0.55, 0.62, 0.95)],
]

var tod_applied := -1.0

func set_time_of_day(t: float) -> void:
	if sun_light == null:
		return
	t = clampf(t, 0.0, 1.0)
	time_of_day = t
	# 하늘을 다시 그리는 건 무거워서, 눈에 띌 만큼 바뀌었을 때만 바꿔요
	if tod_applied >= 0.0 and absf(t - tod_applied) < 0.012:
		return
	tod_applied = t
	var a: Array = TOD_KEYS[0]
	var b: Array = TOD_KEYS[TOD_KEYS.size() - 1]
	for i in TOD_KEYS.size() - 1:
		if t >= float(TOD_KEYS[i][0]) and t <= float(TOD_KEYS[i + 1][0]):
			a = TOD_KEYS[i]
			b = TOD_KEYS[i + 1]
			break
	var k := 0.0
	if float(b[0]) > float(a[0]):
		k = (t - float(a[0])) / (float(b[0]) - float(a[0]))
	sun_light.rotation_degrees.x = lerpf(a[1], b[1], k)
	sun_light.light_color = (a[2] as Color).lerp(b[2], k)
	sun_light.light_energy = lerpf(a[3], b[3], k)
	sky_mat_ref.sky_top_color = (a[4] as Color).lerp(b[4], k)
	sky_mat_ref.sky_horizon_color = (a[5] as Color).lerp(b[5], k)
	sky_mat_ref.ground_horizon_color = (a[5] as Color).lerp(b[5], k).darkened(0.1)
	sky_mat_ref.ground_bottom_color = Color(0.5, 0.62, 0.45).lerp(Color(0.05, 0.07, 0.12), smoothstep(0.6, 1.0, t))
	env_ref.fog_light_color = (a[6] as Color).lerp(b[6], k)
	env_ref.ambient_light_energy = lerpf(a[7], b[7], k)
	env_ref.ambient_light_color = (a[8] as Color).lerp(b[8], k)
	if star_node != null:
		var sa := smoothstep(0.78, 0.95, t)
		star_node.visible = sa > 0.01
		(star_node.material_override as StandardMaterial3D).albedo_color.a = sa

# 밤하늘의 별 (멀리 둥근 천장에 작은 점들)
func make_stars() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r := RandomNumberGenerator.new()
	r.seed = 99
	for i in 420:
		var y := r.randf_range(0.12, 1.0)
		var ang := r.randf() * TAU
		var dir := Vector3(cos(ang) * sqrt(1.0 - y * y), y, sin(ang) * sqrt(1.0 - y * y))
		var c := dir * 260.0
		var s := r.randf_range(0.35, 1.0) * (1.6 if r.randf() < 0.08 else 1.0)
		var u := dir.cross(Vector3.UP).normalized() * s
		if u.length() < 0.01:
			u = Vector3(s, 0, 0)
		var v := dir.cross(u).normalized() * s
		var col := Color(1.0, 0.96, 0.85).lerp(Color(0.8, 0.88, 1.0), r.randf())
		for p in [c - u, c + v, c + u, c - u, c + u, c - v]:
			st.set_color(col)
			st.add_vertex(p)
	star_node = MeshInstance3D.new()
	star_node.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.disable_fog = true
	m.albedo_color = Color(1, 1, 1, 0)
	star_node.material_override = m
	star_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	star_node.visible = false
	add_child(star_node)

# ---------- 땅과 물 셰이더 (그림 같은 풀밭, 땅에 스며든 흙길, 반짝이는 물) ----------

const GROUND_SHADER := """
shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;
uniform sampler2D grass_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D dirt_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D macro_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D splat_tex : filter_linear, repeat_disable;
uniform vec4 world_rect = vec4(-50.0, -50.0, 100.0, 100.0);
varying vec3 wp;
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 p = wp.xz;
	vec3 mac = texture(macro_tex, p * 0.012).rgb;
	vec3 mac2 = texture(macro_tex, p * 0.05 + 0.37).rgb;
	vec3 g1 = texture(grass_tex, p * 0.16).rgb;
	vec3 g2 = texture(grass_tex, p * 0.047 + 0.5).rgb;
	vec3 grass = mix(g1, g2, 0.35);
	grass *= mix(vec3(0.9, 1.0, 0.92), vec3(1.1, 1.05, 0.84), smoothstep(0.3, 0.75, mac.r));
	grass *= 0.8 + mac2.g * 0.22;
	grass = mix(grass, grass * vec3(0.82, 0.95, 0.9), smoothstep(0.55, 0.85, mac2.r) * 0.6);
	vec2 suv = (p - world_rect.xy) / world_rect.zw;
	vec4 s = texture(splat_tex, suv);
	float inside = step(0.0, suv.x) * step(suv.x, 1.0) * step(0.0, suv.y) * step(suv.y, 1.0);
	s *= inside;
	float tuft = dot(g1, vec3(0.33)) * 2.2 - 0.9;
	float jit = (mac2.b - 0.5) * 0.55 + (texture(macro_tex, p * 0.21).g - 0.5) * 0.5 + tuft * 0.35;
	float dirt_m = smoothstep(0.42, 0.6, s.r + jit);
	float worn = smoothstep(0.0, 0.45, s.r + jit) * (1.0 - dirt_m);
	float mud_m = smoothstep(0.36, 0.66, s.g + jit);
	vec3 dirt = texture(dirt_tex, p * 0.22).rgb * (0.86 + mac.g * 0.16);
	// 발길이 많이 닿는 가운데는 조금 더 진하고 매끈해요
	dirt *= mix(1.0, 0.86, smoothstep(0.8, 1.0, s.r) * (0.5 + 0.5 * mac2.g));
	vec3 mud = texture(dirt_tex, p * 0.3 + 0.2).rgb * vec3(0.6, 0.58, 0.52);
	vec3 col = mix(grass, grass * vec3(0.74, 0.84, 0.8), s.b);
	col = mix(col, col * vec3(1.06, 0.98, 0.76), worn * 0.75);
	col = mix(col, mud, mud_m);
	col = mix(col, dirt, dirt_m);
	ALBEDO = col;
	ROUGHNESS = mix(0.95, 0.55, mud_m * (1.0 - dirt_m));
	SPECULAR = 0.25;
}
"""

const WATER_SHADER := """
shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx, cull_disabled;
uniform sampler2D ripple : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec3 deep = vec3(0.14, 0.42, 0.62);
uniform vec3 shallow = vec3(0.45, 0.74, 0.84);
uniform int shape = 0;
uniform vec4 area = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec2 flow = vec2(0.035, 0.0);
uniform float foam_amt = 0.7;
uniform float spec = 0.75;
uniform float rough = 0.07;
uniform float mud = 0.0;
varying vec3 wp;
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float edge = 1.0;
	if (shape == 0) {
		edge = 1.0 - abs(UV.y * 2.0 - 1.0);
	} else if (shape == 1) {
		edge = 1.0 - length((wp.xz - area.xy) / area.zw);
	} else {
		vec2 q = abs(wp.xz - area.xy) / area.zw;
		edge = 1.0 - max(q.x, q.y);
	}
	edge = clamp(edge, 0.0, 1.0);
	vec3 n1 = texture(ripple, wp.xz * 0.16 + TIME * flow).rgb;
	vec3 n2 = texture(ripple, wp.xz * 0.29 + vec2(TIME * 0.013, -TIME * 0.019) - TIME * flow * 0.6).rgb;
	NORMAL_MAP = normalize((n1 + n2) * 0.5);
	NORMAL_MAP_DEPTH = 0.7;
	vec3 col = mix(shallow, deep, smoothstep(0.0, 0.55, edge));
	float wave = 0.6 + 0.4 * sin(TIME * 1.6 + wp.x * 1.7 + wp.z * 1.3);
	float foam = smoothstep(0.14, 0.0, edge) * wave * foam_amt;
	col = mix(col, vec3(0.94, 0.98, 1.0), foam);
	// 논물: 흙이 비치는 얼룩
	float blot = texture(ripple, wp.xz * 0.05).r;
	col = mix(col, col * (0.8 + blot * 0.4), mud);
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = spec;
}
"""

var ground_mat: ShaderMaterial
var ripple_tex: NoiseTexture2D

func make_ground_mat() -> void:
	var sh := Shader.new()
	sh.code = GROUND_SHADER
	ground_mat = ShaderMaterial.new()
	ground_mat.shader = sh
	for k in ["grass", "dirt", "macro"]:
		var path := "res://textures/%s.png" % k
		if ResourceLoader.exists(path):
			ground_mat.set_shader_parameter(k + "_tex", load(path))

func water_material(shape: int, area: Vector4, deep: Color, shallow: Color, flow: Vector2 = Vector2(0.0, 0.0), foam: float = 0.7) -> ShaderMaterial:
	if ripple_tex == null:
		var n := FastNoiseLite.new()
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		n.frequency = 0.04
		n.fractal_octaves = 3
		ripple_tex = NoiseTexture2D.new()
		ripple_tex.width = 256
		ripple_tex.height = 256
		ripple_tex.seamless = true
		ripple_tex.as_normal_map = true
		ripple_tex.bump_strength = 6.0
		ripple_tex.noise = n
	var sh := Shader.new()
	sh.code = WATER_SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("ripple", ripple_tex)
	m.set_shader_parameter("shape", shape)
	m.set_shader_parameter("area", area)
	m.set_shader_parameter("deep", Vector3(deep.r, deep.g, deep.b))
	m.set_shader_parameter("shallow", Vector3(shallow.r, shallow.g, shallow.b))
	m.set_shader_parameter("flow", flow)
	m.set_shader_parameter("foam_amt", foam)
	return m

# 흙길·진흙·숲 바닥 자리를 그림 한 장(512x512 = 100m)에 칠해서 땅 셰이더에 넘겨요
const SPLAT_N := 512
const SPLAT_SIZE := 100.0
# 흙길 그림이 덮는 땅 영역 (장마다 바꿀 수 있어요: x, z, 한 변 길이)
var splat_rect := Rect2(-50, -50, 100, 100)
var splat_r: PackedFloat32Array
var splat_g: PackedFloat32Array

func splat_stamp(ch: PackedFloat32Array, cx: float, cz: float, r_in: float, r_out: float, strength: float = 1.0) -> void:
	var k := SPLAT_N / splat_rect.size.x
	var px := (cx - splat_rect.position.x) * k
	var pz := (cz - splat_rect.position.y) * k
	var ro := r_out * k
	var x0 := maxi(1, int(px - ro))
	var x1 := mini(SPLAT_N - 2, int(px + ro) + 1)
	var z0 := maxi(1, int(pz - ro))
	var z1 := mini(SPLAT_N - 2, int(pz + ro) + 1)
	for z in range(z0, z1 + 1):
		var dz := (z + 0.5 - pz) / k
		for x in range(x0, x1 + 1):
			var dx := (x + 0.5 - px) / k
			var d := sqrt(dx * dx + dz * dz)
			if d >= r_out:
				continue
			var v := (1.0 - smoothstep(r_in, r_out, d)) * strength
			var i := z * SPLAT_N + x
			if v > ch[i]:
				ch[i] = v

func apply_ground_splat() -> void:
	splat_r = PackedFloat32Array()
	splat_r.resize(SPLAT_N * SPLAT_N)
	splat_g = PackedFloat32Array()
	splat_g.resize(SPLAT_N * SPLAT_N)
	paint_ground_splat()
	var bytes := PackedByteArray()
	bytes.resize(SPLAT_N * SPLAT_N * 4)
	for z in SPLAT_N:
		var wz := splat_rect.position.y + z * splat_rect.size.x / SPLAT_N
		for x in SPLAT_N:
			var forest := splat_forest(splat_rect.position.x + x * splat_rect.size.x / SPLAT_N, wz)
			var i := z * SPLAT_N + x
			bytes[i * 4] = int(splat_r[i] * 255.0)
			bytes[i * 4 + 1] = int(splat_g[i] * 255.0)
			bytes[i * 4 + 2] = int(forest * 255.0)
			bytes[i * 4 + 3] = 255
	var img := Image.create_from_data(SPLAT_N, SPLAT_N, false, Image.FORMAT_RGBA8, bytes)
	ground_mat.set_shader_parameter("splat_tex", ImageTexture.create_from_image(img))
	ground_mat.set_shader_parameter("world_rect", Vector4(splat_rect.position.x, splat_rect.position.y, splat_rect.size.x, splat_rect.size.x))

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
	grass_mat = make_tex_material(Color(0.54, 0.76, 0.4), tex, 0.05)
	forest_mat = make_tex_material(Color(0.46, 0.66, 0.35), tex, 0.06)
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
	make_ground_mat()

# 바람에 살랑이는 풀 더미 (뾰족한 잎 세 개)
func make_tuft_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r := RandomNumberGenerator.new()
	r.seed = 4
	for blade in 6:
		var ang := blade * TAU / 6.0 + r.randf_range(-0.35, 0.35)
		var dir := Vector3(cos(ang), 0, sin(ang))
		var side := Vector3(-dir.z, 0, dir.x)
		var h := r.randf_range(0.26, 0.52)
		var lean := r.randf_range(0.25, 0.6)
		var base := dir * r.randf_range(0.0, 0.05)
		var w := r.randf_range(0.03, 0.045)
		var pts := []
		for k in 3:
			var t := k / 2.0
			var center := base + dir * lean * h * t * t + Vector3(0, h * t, 0)
			var hw := w * (1.0 - t * 0.92)
			var c := Color(0.5, 0.6, 0.45).lerp(Color(1.0, 1.0, 0.9), t)
			pts.append([center - side * hw, center + side * hw, c])
		for k in 2:
			var p0: Array = pts[k]
			var p1: Array = pts[k + 1]
			for v in [[p0[0], p0[2]], [p0[1], p0[2]], [p1[1], p1[2]], [p0[0], p0[2]], [p1[1], p1[2]], [p1[0], p1[2]]]:
				st.set_normal(Vector3(dir.x * 0.3, 1.0, dir.z * 0.3).normalized())
				st.set_color(v[1])
				st.add_vertex(v[0])
	return st.commit()

var tuft_mat: ShaderMaterial = null

# 바람에 살랑이는 풀 포기 재질 (한 번만 만들어 같이 써요)
func grass_material() -> ShaderMaterial:
	if tuft_mat != null:
		return tuft_mat
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
	tuft_mat = ShaderMaterial.new()
	tuft_mat.shader = sh
	return tuft_mat

func make_grass(r: RandomNumberGenerator) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = make_tuft_mesh()
	# 풀이 나면 안 되는 곳: 길, 개울, 다리, 텃밭, 연못
	var keep_out := [
		Rect2(-19.6, -5.8, 4.4, 3.0), Rect2(-10.2, 12.0, 3.4, 2.4),
		Rect2(30.0, -39.0, 7.0, 7.0), Rect2(9.0, -1.5, 10.0, 7.0), Rect2(-15.5, -4.2, 5.5, 4.8)] + house_rects
	var spots := []
	var tries := 0
	var clump := Vector2.ZERO
	var grass_n := GRASS_COUNT / 2 if light_mode else GRASS_COUNT
	while spots.size() < grass_n and tries < grass_n * 4:
		tries += 1
		# 풀은 포기끼리 무리 지어 자라요
		if tries % 5 == 1 or spots.is_empty():
			clump = Vector2(r.randf_range(-38, 38), r.randf_range(-38, 38))
		var p := clump + Vector2(r.randf_range(-0.9, 0.9), r.randf_range(-0.9, 0.9))
		var ok := true
		# 경계가 반듯하지 않게 조금씩 들쭉날쭉
		var jag := r.randf_range(-0.7, 0.5)
		for k in keep_out:
			if k.grow(jag).has_point(p):
				ok = false
				break
		if ok and absf(p.y - creek_z(p.x)) < creek_half(p.x) + 0.35 + jag * 0.3:
			ok = false
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
	# 들꽃 (작은 알록달록 점)
	var wild := []
	var palette := [Color(1.0, 0.8, 0.85), Color(1.0, 0.97, 0.8), Color(0.85, 0.8, 1.0), Color(1.0, 0.9, 0.45), Color(1, 1, 1)]
	for i in 160:
		var p: Vector2 = spots[r.randi() % spots.size()]
		wild.append([Vector3(p.x, 0.13, p.y), Vector3(0.13, 0.1, 0.13), palette[r.randi() % palette.size()]])
	var wmi := add_blobs(self, wild)
	wmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

# 블렌더로 만든 나무 (models/trees.glb: 활엽수 2, 소나무 2). 없으면 코드로 그린 나무
var tree_meshes := {}
var tree_tried := false
var leaf_mat: ShaderMaterial
var bark_mat: StandardMaterial3D
var bark_red_mat: StandardMaterial3D

func load_trees() -> void:
	tree_tried = true
	if not ResourceLoader.exists("res://models/trees.glb"):
		return
	var root: Node = (load("res://models/trees.glb") as PackedScene).instantiate()
	for node in root.find_children("*", "MeshInstance3D", true, false):
		tree_meshes[node.name] = (node as MeshInstance3D).mesh
	root.free()
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode cull_disabled;
uniform sampler2D leaf_tex : source_color, filter_linear_mipmap;
uniform float has_tex = 1.0;
void vertex() {
	float h = max(VERTEX.y - 1.6, 0.0);
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float ph = wp.x * 0.35 + wp.z * 0.27;
	VERTEX.x += sin(TIME * 1.3 + ph) * 0.05 * h;
	VERTEX.z += cos(TIME * 1.05 + ph * 1.3) * 0.035 * h;
	// 잎 하나하나도 살랑살랑
	VERTEX.y += sin(TIME * 3.1 + wp.x * 2.3 + wp.z * 1.7) * 0.025 * min(h, 1.0);
}
void fragment() {
	vec4 t = has_tex > 0.5 ? texture(leaf_tex, UV) : vec4(1.0);
	if (t.a < 0.45) {
		discard;
	}
	ALBEDO = t.rgb * COLOR.rgb * (has_tex > 0.5 ? 1.05 : 0.75);
	ROUGHNESS = 0.8;
	SPECULAR = 0.2;
}
"""
	leaf_mat = ShaderMaterial.new()
	leaf_mat.shader = sh
	var lt: Texture2D = tex_or("leaves", null)
	leaf_mat.set_shader_parameter("leaf_tex", lt)
	leaf_mat.set_shader_parameter("has_tex", 1.0 if lt != null else 0.0)
	bark_mat = make_tex_material(Color(0.5, 0.35, 0.22), wood_mat.albedo_texture, 1.6)
	bark_red_mat = make_tex_material(Color(0.66, 0.38, 0.24), wood_mat.albedo_texture, 1.6)

func make_tree(pos: Vector3, kind: String = "") -> void:
	if not tree_tried:
		load_trees()
	var tree := StaticBody3D.new()
	tree.position = pos
	add_child(tree)
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.45
	shape.height = 2.0
	col.shape = shape
	col.position.y = 1.0
	tree.add_child(col)
	if tree_meshes.size() >= 4:
		var pine := rng.randf() < 0.4
		var key := ("Pine" if pine else "Broad") + str(rng.randi() % 2)
		if kind != "" and tree_meshes.has(kind):
			key = kind
		var mi := MeshInstance3D.new()
		mi.mesh = tree_meshes[key]
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i)
			var nm := m.resource_name if m != null else ""
			if nm == "Leaf" or nm == "Needle":
				mi.set_surface_override_material(i, leaf_mat)
			elif nm == "BarkRed":
				mi.set_surface_override_material(i, bark_red_mat)
			else:
				mi.set_surface_override_material(i, bark_mat)
		mi.rotation.y = rng.randf() * TAU
		var sc := rng.randf_range(0.78, 1.02)
		mi.scale = Vector3(sc, sc * rng.randf_range(0.95, 1.12), sc)
		tree.add_child(mi)
		return
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
		"fisher":
			hat = "gat"
			hair = "topknot"
			hair_c = Color(0.86, 0.86, 0.9)
			beard = true
		"choi":
			hat = "band"
			hair = "topknot"
			hair_c = Color(0.8, 0.8, 0.84)
			mustache = true
			bottom = Color(0.86, 0.82, 0.7)
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

# 블렌더로 만든 인물 (models/characters.glb). 몸, 눈, 팔 둘, 다리 둘로 나뉘어 있어요
var char_lib := {}
var char_tried := false
const FIXED_LOOK := ["hero", "heungbu", "nolbu", "sansin", "dokkaebi"]

func load_chars() -> void:
	char_tried = true
	if not ResourceLoader.exists("res://models/characters.glb"):
		return
	var root: Node = (load("res://models/characters.glb") as PackedScene).instantiate()
	for holder in root.find_children("Char_*", "", true, false):
		var kind := String(holder.name).substr(5)
		var parts := {}
		for ch in holder.get_children():
			if ch is MeshInstance3D:
				var nm := String(ch.name)
				parts[nm.substr(nm.rfind("_") + 1)] = [(ch as MeshInstance3D).mesh, (ch as Node3D).transform]
		char_lib[kind] = parts
	root.free()

# 젤다처럼 빛과 그림자가 또렷하게 나뉘는 셀 셰이딩 + 가장자리 빛
var toon_cache := {}
const CHAR_TOON := false   # true 로 바꾸면 셀 셰이딩

func toon_of(m: Material) -> Material:
	if m == null or not CHAR_TOON:
		return m
	if toon_cache.has(m):
		return toon_cache[m]
	var t: StandardMaterial3D
	if m is StandardMaterial3D:
		t = (m as StandardMaterial3D).duplicate() as StandardMaterial3D
	else:
		t = StandardMaterial3D.new()
	t.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	t.specular_mode = BaseMaterial3D.SPECULAR_TOON
	t.metallic_specular = 0.25
	t.roughness = maxf(t.roughness, 0.6)
	t.rim_enabled = true
	t.rim = 0.22
	t.rim_tint = 0.5
	toon_cache[m] = t
	return t

# Meshy로 만든 주인공: 뼈대(Skeleton3D)를 돌려서 걷고 뛰어요
const RIG_BONES := ["hips", "spine", "head", "armL", "foreL", "handL", "armR", "foreR", "handR", "thighL", "shinL", "footL", "thighR", "shinR", "footR"]
# Meshy 가 넣어 준 뼈대(믹사모 이름)를 우리 이름에 맞춰요. 우리 L 은 모델의 -x 쪽 = 믹사모의 Right 예요
const MIXAMO_BONES := {
	"hips": "mixamorig_Hips", "spine": "mixamorig_Spine1", "head": "mixamorig_Head",
	"armL": "mixamorig_RightArm", "foreL": "mixamorig_RightForeArm", "handL": "mixamorig_RightHand",
	"armR": "mixamorig_LeftArm", "foreR": "mixamorig_LeftForeArm", "handR": "mixamorig_LeftHand",
	"thighL": "mixamorig_RightUpLeg", "shinL": "mixamorig_RightLeg", "footL": "mixamorig_RightFoot",
	"thighR": "mixamorig_LeftUpLeg", "shinR": "mixamorig_LeftLeg", "footR": "mixamorig_LeftFoot",
}

func make_rigged_model(parent: Node3D, file: String) -> Node3D:
	var path := "res://models/%s.glb" % file
	if not ResourceLoader.exists(path):
		return null
	var body := Node3D.new()
	body.position.y = 1.0
	parent.add_child(body)
	var inst := (load(path) as PackedScene).instantiate()
	body.add_child(inst)
	var found := inst.find_children("*", "Skeleton3D", true, false)
	if found.is_empty():
		body.queue_free()
		return null
	var skel: Skeleton3D = found[0]
	var bones := {}
	var mixamo := skel.find_bone("mixamorig_Hips") >= 0
	for bn in RIG_BONES:
		var i := skel.find_bone(MIXAMO_BONES[bn] if mixamo else bn)
		if i >= 0:
			bones[bn] = [i, skel.get_bone_rest(i).basis.get_rotation_quaternion(), skel.get_bone_global_rest(i).basis.orthonormalized().inverse(), skel.get_bone_global_rest(i).basis.y.normalized()]
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	body.set_meta("skel", skel)
	body.set_meta("bones", bones)
	# Meshy 동작(걷기·뛰기)이 들어 있으면 틀 준비를 해요
	var players := inst.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		var ap: AnimationPlayer = players[0]
		for an in ap.get_animation_list():
			var a := ap.get_animation(an)
			a.loop_mode = Animation.LOOP_LINEAR
		ap.playback_default_blend_time = 0.25
		body.set_meta("anim", ap)
		if file == "hero":
			find_step_times(body)
	return body

# 가만히 서 있는 자세(코드로 만든 자세)를 동작 클립으로 만들어, 걷기와 부드럽게 섞이게 해요
func make_idle_clip(body: Node3D) -> void:
	if not body.has_meta("anim"):
		return
	var ap: AnimationPlayer = body.get_meta("anim")
	var skel: Skeleton3D = body.get_meta("skel")
	skel.reset_bone_poses()
	body.set_meta("gait", [0.0, 0.0, 0.0])
	pose_rig(body, 0.0, 0.0)
	var root: Node = ap.get_node(ap.root_node)
	var spath := str(root.get_path_to(skel))
	var a := Animation.new()
	a.length = 3.0
	a.loop_mode = Animation.LOOP_LINEAR
	var bones: Dictionary = body.get_meta("bones")
	for bi in skel.get_bone_count():
		var bname := skel.get_bone_name(bi)
		if bname.contains("Hand") and not bname.ends_with("Hand"):
			continue
		var t := a.add_track(Animation.TYPE_ROTATION_3D)
		a.track_set_path(t, NodePath(spath + ":" + bname))
		var q := skel.get_bone_pose_rotation(bi)
		a.rotation_track_insert_key(t, 0.0, q)
		# 숨 쉬듯 가슴과 팔이 살짝 오르내려요
		var breathe := Quaternion.IDENTITY
		if bones.has("spine") and bi == (bones["spine"] as Array)[0]:
			breathe = Quaternion(Vector3.RIGHT, -0.03)
		a.rotation_track_insert_key(t, 1.5, q * breathe)
		a.rotation_track_insert_key(t, 3.0, q)
	var hip_i: int = (bones["hips"] as Array)[0]
	var pt := a.add_track(Animation.TYPE_POSITION_3D)
	a.track_set_path(pt, NodePath(spath + ":" + skel.get_bone_name(hip_i)))
	a.position_track_insert_key(pt, 0.0, skel.get_bone_rest(hip_i).origin)
	var lib: AnimationLibrary
	if ap.has_animation_library(""):
		lib = ap.get_animation_library("")
	else:
		lib = AnimationLibrary.new()
		ap.add_animation_library("", lib)
	lib.add_animation("Idle", a)
	skel.reset_bone_poses()
	ap.play("Idle")

# 걷기·뛰기·서 있기를 동작 클립으로 틀어요. 동작 클립이 없거나 특별한 자세일 땐 false
func drive_anim(body: Node3D, moving: float, run: float, speed_ratio: float) -> bool:
	if not body.has_meta("anim"):
		return false
	var ap: AnimationPlayer = body.get_meta("anim")
	var want := "Idle"
	if moving > 0.35:
		want = "Running" if run > 0.5 and ap.has_animation("Running") else "Walking"
	if body == player_body and swimming and ap.has_animation("Swimming"):
		if ap.current_animation != "Swimming" or not ap.is_playing():
			ap.play("Swimming")
		ap.speed_scale = lerpf(0.45, 1.15, clampf(moving, 0.0, 1.0))
		body.set_meta("anim_on", true)
		return true
	if not ap.has_animation(want):
		return false
	if ap.current_animation != want or not ap.is_playing():
		ap.play(want)
	ap.speed_scale = 1.0 if want == "Idle" else clampf(speed_ratio, 0.6, 1.8)
	body.set_meta("anim_on", true)
	return true

# 걷기·뛰기 동작에서 발이 땅에 닿는 순간(0~1)을 미리 찾아 둬요. 발자국 소리를 그때 울려요
func find_step_times(body: Node3D) -> void:
	var ap: AnimationPlayer = body.get_meta("anim")
	var skel: Skeleton3D = body.get_meta("skel")
	var bones: Dictionary = body.get_meta("bones")
	if not bones.has("footL") or not bones.has("footR"):
		return
	var out := {}
	for clip in ["Walking", "Running"]:
		if not ap.has_animation(clip):
			continue
		var length := ap.get_animation(clip).length
		ap.play(clip)
		var n := 48
		var ys := {"footL": [], "footR": []}
		for i in n:
			ap.seek(length * i / n, true)
			for f in ys:
				var bi: int = (bones[f] as Array)[0]
				(ys[f] as Array).append(skel.get_bone_global_pose(bi).origin.y)
		var times := []
		for f in ys:
			var arr: Array = ys[f]
			# 발이 가장 낮아지기 시작하는 때 = 땅을 딛는 순간
			var lo: float = arr.min()
			var hi: float = arr.max()
			var th := lo + (hi - lo) * 0.12
			for i in n:
				var prev: float = arr[(i - 1 + n) % n]
				if arr[i] <= th and prev > th:
					times.append(float(i) / n)
		out[clip] = times
		ap.stop()
	skel.reset_bone_poses()
	body.set_meta("step_times", out)
	body.set_meta("step_last", 0.0)

func anim_footsteps(on_ground: bool) -> void:
	if not player_body.has_meta("step_times"):
		return
	var ap: AnimationPlayer = player_body.get_meta("anim")
	var st: Dictionary = player_body.get_meta("step_times")
	var clip := String(ap.current_animation)
	if not st.has(clip) or not on_ground:
		player_body.set_meta("step_last", -1.0)
		return
	var length := ap.current_animation_length
	var now := fposmod(ap.current_animation_position / maxf(length, 0.001), 1.0)
	var last: float = player_body.get_meta("step_last", -1.0)
	player_body.set_meta("step_last", now)
	if last < 0.0:
		return
	for t in st[clip]:
		var hit: bool = (last < now and t > last and t <= now) or (last > now and (t > last or t <= now))
		if hit:
			sfx("step", rng.randf_range(0.85, 1.15) * (1.08 if clip == "Running" else 1.0))

# 동작 클립을 멈추고 코드로 자세를 잡을 준비 (점프·미니게임)
func stop_anim(body: Node3D) -> void:
	if not body.has_meta("anim") or not body.get_meta("anim_on", false):
		return
	var ap: AnimationPlayer = body.get_meta("anim")
	ap.stop()
	(body.get_meta("skel") as Skeleton3D).reset_bone_poses()
	body.set_meta("anim_on", false)

# 뼈를 모델 기준 축으로 돌려요. turns = [[축, 각도], ...]
func turn_bone(skel: Skeleton3D, bones: Dictionary, bn: String, turns: Array) -> void:
	if not bones.has(bn):
		return
	var b: Array = bones[bn]
	var q: Quaternion = b[1]
	var inv: Basis = b[2]
	for tr in turns:
		var ang: float = tr[1]
		if absf(ang) > 0.0001:
			q = q * Quaternion((inv * (tr[0] as Vector3)).normalized(), ang)
	skel.set_bone_pose_rotation(b[0], q)

# ---------- 사람 걸음 자료로 만든 걷기·달리기 ----------
# 한 걸음 주기(0~1, 0 = 발뒤꿈치가 닿는 순간)마다 엉덩이·무릎·발목이 몇 도인지 (보행 분석 자료를 단순하게)
const GAIT_WALK := {
	"hip": [[0.0, 30.0], [0.1, 26.0], [0.2, 17.0], [0.3, 8.0], [0.4, 0.0], [0.5, -8.0], [0.55, -10.0], [0.62, -2.0], [0.7, 12.0], [0.8, 26.0], [0.88, 31.0], [1.0, 30.0]],
	"knee": [[0.0, 5.0], [0.08, 15.0], [0.15, 19.0], [0.25, 12.0], [0.4, 5.0], [0.5, 8.0], [0.58, 30.0], [0.65, 52.0], [0.72, 61.0], [0.8, 50.0], [0.88, 25.0], [0.95, 8.0], [1.0, 5.0]],
	"ankle": [[0.0, 0.0], [0.06, -6.0], [0.12, -3.0], [0.3, 6.0], [0.45, 10.0], [0.52, 6.0], [0.58, -8.0], [0.63, -18.0], [0.7, -8.0], [0.78, 0.0], [1.0, 0.0]],
}
const GAIT_RUN := {
	"hip": [[0.0, 32.0], [0.15, 18.0], [0.3, 0.0], [0.4, -10.0], [0.5, 0.0], [0.6, 22.0], [0.72, 42.0], [0.85, 40.0], [1.0, 32.0]],
	"knee": [[0.0, 22.0], [0.15, 40.0], [0.3, 25.0], [0.4, 15.0], [0.5, 45.0], [0.6, 85.0], [0.7, 100.0], [0.8, 75.0], [0.9, 35.0], [1.0, 22.0]],
	"ankle": [[0.0, 2.0], [0.15, 14.0], [0.3, 6.0], [0.4, -20.0], [0.5, -12.0], [0.65, 2.0], [0.85, 4.0], [1.0, 2.0]],
}

# 표에서 부드럽게 값을 읽어요 (캣멀-롬 곡선)
func gait_at(tab: Array, p: float) -> float:
	p = fposmod(p, 1.0)
	var n := tab.size()
	for i in n - 1:
		var a: Array = tab[i]
		var b: Array = tab[i + 1]
		if p >= a[0] and p <= b[0]:
			var t: float = (p - a[0]) / maxf(b[0] - a[0], 0.0001)
			var a0: float = (tab[i - 1] as Array)[1] if i > 0 else (tab[n - 2] as Array)[1]
			var b1: float = (tab[i + 2] as Array)[1] if i + 2 < n else (tab[1] as Array)[1]
			var y0: float = a[1]
			var y1: float = b[1]
			var t2 := t * t
			var t3 := t2 * t
			return 0.5 * ((2.0 * y0) + (-a0 + y1) * t + (2.0 * a0 - 5.0 * y0 + 4.0 * y1 - b1) * t2 + (-a0 + 3.0 * y0 - 3.0 * y1 + b1) * t3)
	return (tab[0] as Array)[1]

func gait_angle(key: String, p: float, run: float) -> float:
	return lerpf(gait_at(GAIT_WALK[key], p), gait_at(GAIT_RUN[key], p), run)

func pose_rig(body: Node3D, swing: float, arm_up: float) -> void:
	var skel: Skeleton3D = body.get_meta("skel")
	var bones: Dictionary = body.get_meta("bones")
	var a := arm_up
	# 걸음 정보: [주기 위치, 얼마나 걷는지 0~1, 달리기 정도 0~1]
	var gait: Array = body.get_meta("gait", [0.0, absf(swing), 0.0])
	var phase: float = gait[0]
	var amt: float = gait[1]
	var run: float = gait[2]
	var hips_deg := {}
	for side in ["R", "L"]:
		var p := phase + (0.0 if side == "R" else 0.5)
		hips_deg[side] = gait_angle("hip", p, run)
	for side in ["L", "R"]:
		var sx := -1.0 if side == "L" else 1.0
		var lead: bool = side == "L"
		var p := phase + (0.0 if side == "R" else 0.5)
		# 다리: 서 있을 땐 무릎을 살짝 굽힌 자세, 걸으면 자료대로
		var hip_r := deg_to_rad(hips_deg[side])
		var knee_r := deg_to_rad(gait_angle("knee", p, run))
		var ank_r := deg_to_rad(gait_angle("ankle", p, run))
		var thigh := lerpf(-0.14, -hip_r, amt)
		var knee := lerpf(0.26, knee_r, amt)
		var foot := lerpf(-(thigh + knee) * 0.9 - 0.02, -ank_r, amt)
		turn_bone(skel, bones, "thigh" + side, [[Vector3.RIGHT, lerpf(thigh, -0.5 if lead else -0.2, a)]])
		turn_bone(skel, bones, "shin" + side, [[Vector3.RIGHT, lerpf(knee, 0.85 if lead else 0.5, a)]])
		turn_bone(skel, bones, "foot" + side, [[Vector3.RIGHT, lerpf(foot, 0.3, a)]])
		# 팔: 반대쪽 다리와 함께 앞뒤로. 앞으로 갈 땐 위팔이 더 올라오고 팔꿈치가 굽어요. 달리면 팔꿈치를 직각으로
		var opp: float = hips_deg["L" if side == "R" else "R"]
		var fwd := clampf((opp - 10.0) / 20.0, -1.0, 1.0) * amt
		var amp := lerpf(0.42, 0.5, run)
		var arm_swing := -fwd * amp * lerpf(1.35, 1.1, run) * (1.0 if fwd > 0.0 else 0.6) - 0.06 - run * 0.08 * amt
		var arm_down: float = body.get_meta("arm_down", 0.44)
		var arm_adj: float = body.get_meta("arm_adj", 0.0)
		var down := -sx * (lerpf(lerpf(arm_down, arm_down + 0.08, run * amt), 0.25, a) - arm_adj)
		var twist: Vector3 = (bones["arm" + side] as Array)[3] if bones.has("arm" + side) else Vector3.UP
		turn_bone(skel, bones, "arm" + side, [[Vector3.RIGHT, lerpf(arm_swing, -0.35, a)], [Vector3.BACK, down], [twist, sx * 0.9]])
		var elbow := lerpf(-0.3 - maxf(fwd, 0.0) * 0.5, -1.35 + maxf(fwd, 0.0) * 0.2, run * amt)
		turn_bone(skel, bones, "fore" + side, [[Vector3.RIGHT, lerpf(elbow, -0.9, a)]])
	# 골반은 앞으로 나간 다리 쪽으로 살짝 돌고, 어깨(가슴)는 반대로 비틀어요. 달리면 몸을 앞으로 기울여요
	var yaw: float = (hips_deg["R"] - hips_deg["L"]) / 40.0 * lerpf(0.07, 0.11, run) * amt
	turn_bone(skel, bones, "hips", [[Vector3.UP, yaw]])
	turn_bone(skel, bones, "spine", [[Vector3.UP, -yaw * 1.8], [Vector3.RIGHT, a * 0.06 + run * amt * 0.14]])
	turn_bone(skel, bones, "head", [[Vector3.UP, yaw * 0.8], [Vector3.RIGHT, -a * 0.1 - run * amt * 0.08]])

# 몸이 위아래로 오르내리는 높이 (걷기: 한 발로 설 때 높고, 달리기: 공중에 뜰 때 높아요)
func gait_bob(phase: float, run: float) -> float:
	var walk_b := -cos(phase * TAU * 2.0) * 0.022
	var run_b := cos((phase - 0.45) * TAU * 2.0) * 0.05
	return lerpf(walk_b, run_b, run)

# 뼈대를 넣은 Meshy 인물 모델: 모델 크기, 팔을 얼마나 내리는지(A자 자세가 모델마다 달라요)
const RIGGED_PEOPLE := {
	"hero": {"scale": 1.27, "offset": -1.0, "arm_down": 0.44, "arm_adj": 0.31, "idle_clip": true},
	"heungbu": {"scale": 1.25, "arm_down": 0.3},
	"nolbu": {"scale": 1.0, "arm_down": 0.22},
	"wife": {"scale": 1.2, "arm_down": 0.04},
	"dokkaebi": {"scale": 1.0, "arm_down": 0.08},
	"sansin": {"scale": 1.1, "arm_down": 0.0},
	"mom": {"scale": 1.25, "arm_down": 0.18},
	"oppa": {"scale": 1.25, "arm_down": 0.2},
	"nui": {"scale": 1.25, "arm_down": 0.2},
	"tiger": {"scale": 1.45, "arm_down": 0.05},
	"tigermom": {"scale": 1.45, "arm_down": 0.08},
	"jara": {"scale": 1.2, "arm_down": 0.15},
	"rabbit": {"scale": 1.1, "arm_down": 0.16},
	"yongwang": {"scale": 1.5, "arm_down": 0.0},
	"octopus": {"scale": 1.45, "arm_down": 0.04},
	"crab": {"scale": 1.15, "arm_down": 0.04},
	"flatfish": {"scale": 1.35, "arm_down": 0.0},
	"haenyeo": {"scale": 1.2, "arm_down": 0.25},
}

# 마을 사람: 기본 체형 5개(Meshy)를 옷 색, 모자, 수염만 바꿔 여러 사람으로 써요
# hat_y: 머리카락 꼭대기 높이, chin/front: 턱 높이와 얼굴 앞쪽 (모델 키 2, 발 -1 기준)
const VIL_BASE := {
	"vil_man": {"arm_down": 0.2, "hat_y": 0.83, "head_r": 0.31, "chin": 0.3, "front": 0.26},
	"vil_woman": {"arm_down": 0.2, "hat_y": 0.98, "head_r": 0.37, "chin": 0.28, "front": 0.3},
	"vil_grandpa": {"arm_down": 0.16, "hat_y": 0.86, "head_r": 0.35, "chin": 0.22, "front": 0.3},
	"vil_grandma": {"arm_down": 0.2, "hat_y": 0.98, "head_r": 0.38, "chin": 0.3, "front": 0.33},
	"vil_child": {"arm_down": 0.2, "hat_y": 0.98, "head_r": 0.4, "chin": 0.28, "front": 0.31},
}
const VILLAGERS_KO := {
	"suni": {"base": "vil_woman", "scale": 1.2, "bottom": Color(0.6, 0.7, 0.9)},
	"ong": {"base": "vil_grandma", "scale": 1.15, "bottom": Color(0.66, 0.56, 0.62)},
	"kim": {"base": "vil_man", "scale": 1.2, "bottom": Color(0.72, 0.64, 0.48), "hat": "straw"},
	"merchant": {"base": "vil_man", "scale": 1.2, "top": Color(0.45, 0.68, 0.5), "hat": "pae"},
	"woodman": {"base": "vil_man", "scale": 1.32, "top": Color(0.78, 0.62, 0.45), "bottom": Color(0.6, 0.5, 0.4), "hat": "band"},
	"park": {"base": "vil_grandpa", "scale": 1.2, "top": Color(0.6, 0.72, 0.9), "hat": "gat", "beard": 0.8},
	"fisher": {"base": "vil_grandpa", "scale": 1.2, "top": Color(0.62, 0.74, 0.62), "hat": "sat", "beard": 1.0},
	"choi": {"base": "vil_grandpa", "scale": 1.22, "top": Color(0.42, 0.7, 0.64), "hat": "tang", "beard": 1.4},
	"kid1": {"base": "vil_child", "scale": 1.25, "bottom": Color(0.8, 0.7, 0.55)},
	"kid2": {"base": "vil_child", "scale": 1.25, "top": Color(1.0, 0.72, 0.8), "bottom": Color(0.98, 0.88, 0.6)},
	"dori": {"base": "vil_child", "scale": 1.25, "top": Color(0.62, 0.78, 1.0)},
	"kid": {"base": "vil_child", "scale": 1.25, "top": Color(1.0, 0.9, 0.6)},
	# 2장: 잔칫집 사람들
	"host": {"base": "vil_grandpa", "scale": 1.22, "top": Color(0.82, 0.72, 0.95), "hat": "gat", "beard": 1.0},
	"cook": {"base": "vil_grandma", "scale": 1.15, "bottom": Color(0.72, 0.52, 0.42)},
	"guest1": {"base": "vil_man", "scale": 1.2, "top": Color(0.66, 0.78, 0.95), "hat": "gat"},
	"guest2": {"base": "vil_woman", "scale": 1.2, "top": Color(1.0, 0.82, 0.45), "bottom": Color(0.5, 0.6, 0.88)},
	"guest3": {"base": "vil_grandpa", "scale": 1.2, "top": Color(0.85, 0.85, 0.8), "hat": "tang", "beard": 1.2},
}
var VILLAGERS: Dictionary = trd(VILLAGERS_KO)
const CLOTH_SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform vec3 top_c : source_color = vec3(1.0);
uniform vec3 bot_c : source_color = vec3(1.0);
void fragment() {
	vec3 c = texture(tex, UV).rgb;
	vec3 g = sqrt(c);
	float skin = smoothstep(0.09, 0.15, g.r - g.g);
	float l = min(dot(c, vec3(0.3, 0.5, 0.2)) / 0.8, 1.0);
	vec3 o = mix(c, top_c * l, COLOR.r * (1.0 - skin));
	ALBEDO = mix(o, bot_c * l, COLOR.g * (1.0 - skin));
	ROUGHNESS = 0.78;
}
"""
var cloth_shader: Shader

func make_villager(parent: Node3D, kind: String) -> Node3D:
	var v: Dictionary = VILLAGERS[kind]
	var base: String = v["base"]
	var bd: Dictionary = VIL_BASE[base]
	var rb := make_rigged_model(parent, base)
	if rb == null:
		return null
	var sc: float = v["scale"]
	(rb.get_child(0) as Node3D).scale = Vector3.ONE * sc
	(rb.get_child(0) as Node3D).position.y = sc - 1.0
	rb.set_meta("arm_down", bd["arm_down"])
	rb.set_meta("arm_adj", 0.0)
	rb.set_meta("gait", [0.0, 0.0, 0.0])
	# 옷 색 (흰 옷 자리에만 물을 들여요. 얼굴·손은 그대로)
	if v.has("top") or v.has("bottom"):
		if cloth_shader == null:
			cloth_shader = Shader.new()
			cloth_shader.code = CLOTH_SHADER
		for mi in rb.find_children("*", "MeshInstance3D", true, false):
			var mesh := (mi as MeshInstance3D).mesh
			var old := mesh.surface_get_material(0) as BaseMaterial3D
			if old == null:
				continue
			var sm := ShaderMaterial.new()
			sm.shader = cloth_shader
			sm.set_shader_parameter("tex", old.albedo_texture)
			sm.set_shader_parameter("top_c", v.get("top", Color.WHITE))
			sm.set_shader_parameter("bot_c", v.get("bottom", Color.WHITE))
			(mi as MeshInstance3D).set_surface_override_material(0, sm)
	# 모자와 수염은 머리뼈에 붙여요 (고개를 돌리면 같이 돌아요)
	if v.has("hat") or v.has("beard"):
		var skel: Skeleton3D = rb.get_meta("skel")
		var hi := skel.find_bone("head")
		if hi >= 0:
			var att := BoneAttachment3D.new()
			att.bone_name = "head"
			skel.add_child(att)
			var holder := Node3D.new()
			att.add_child(holder)
			holder.transform = skel.get_bone_global_rest(hi).affine_inverse()
			if v.has("hat"):
				add_villager_hat(holder, v["hat"], bd)
			if v.has("beard"):
				var bl: float = v["beard"]
				var bm := MeshInstance3D.new()
				var sp := SphereMesh.new()
				sp.radius = 0.08
				sp.height = 0.16
				bm.mesh = sp
				bm.material_override = make_color(Color(0.95, 0.95, 0.93))
				bm.scale = Vector3(0.8, 1.5 * bl, 0.55)
				bm.position = Vector3(0, float(bd["chin"]) - 0.04 - 0.07 * bl, float(bd["front"]) - 0.03)
				holder.add_child(bm)
	return rb

func add_villager_hat(holder: Node3D, hat: String, bd: Dictionary) -> void:
	var y: float = bd["hat_y"]
	var r: float = bd["head_r"]
	var parts := []   # [메시, 위치, 색]
	match hat:
		"gat":
			parts.append([cyl(r + 0.26, r + 0.26, 0.02), y - 0.04, Color(0.08, 0.07, 0.07)])
			parts.append([cyl(0.15, 0.18, 0.3), y + 0.1, Color(0.1, 0.08, 0.08)])
		"tang":
			parts.append([cyl(0.17, 0.22, 0.2), y + 0.03, Color(0.12, 0.1, 0.1)])
		"straw":
			parts.append([cyl(r + 0.3, r + 0.3, 0.03), y - 0.08, Color(0.9, 0.78, 0.48)])
			parts.append([cyl(r - 0.02, r + 0.02, 0.2), y + 0.0, Color(0.88, 0.75, 0.45)])
			parts.append([cyl(r + 0.025, r + 0.025, 0.05), y - 0.05, Color(0.55, 0.25, 0.2)])
		"pae":
			parts.append([cyl(r + 0.17, r + 0.17, 0.03), y - 0.06, Color(0.82, 0.7, 0.46)])
			parts.append([cyl(0.12, r, 0.24), y + 0.04, Color(0.8, 0.67, 0.42)])
		"sat":
			parts.append([cyl(0.02, r + 0.32, 0.34), y + 0.02, Color(0.78, 0.66, 0.42)])
		"band":
			var t := TorusMesh.new()
			t.inner_radius = r - 0.03
			t.outer_radius = r + 0.03
			parts.append([t, y - 0.12, Color(0.96, 0.95, 0.9)])
	for p in parts:
		var mi := MeshInstance3D.new()
		mi.mesh = p[0]
		mi.position = Vector3(0, p[1], 0)
		mi.material_override = make_color(p[2])
		holder.add_child(mi)

func cyl(top: float, bottom: float, h: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = h
	m.radial_segments = 20
	m.rings = 1
	return m

func make_person_model(parent: Node3D, kind: String, c: Color) -> Node3D:
	if VILLAGERS.has(kind):
		var vb := make_villager(parent, kind)
		if vb != null:
			return vb
	if RIGGED_PEOPLE.has(kind):
		var rp: Dictionary = RIGGED_PEOPLE[kind]
		var rb := make_rigged_model(parent, kind)
		if rb != null:
			(rb.get_child(0) as Node3D).scale = Vector3.ONE * float(rp["scale"])
			(rb.get_child(0) as Node3D).position.y = float(rp.get("offset", float(rp["scale"]) - 1.0))
			rb.set_meta("arm_down", rp["arm_down"])
			rb.set_meta("arm_adj", rp.get("arm_adj", 0.0))
			# 서 있는 사람: 걸음 없이 숨만 쉬어요
			rb.set_meta("gait", [0.0, 0.0, 0.0])
			if rp.get("idle_clip", false):
				make_idle_clip(rb)
			return rb
	if kind == "hero":
		var rigged := make_rigged_model(parent, "hero")
		if rigged != null:
			(rigged.get_child(0) as Node3D).scale = Vector3.ONE * 1.1
			(rigged.get_child(0) as Node3D).position.y = 0.1
			return rigged
	if not char_tried:
		load_chars()
	var key := kind
	if not char_lib.has(key):
		key = "kid" if (kind.begins_with("kid") or kind == "dori") else "villager"
	if not char_lib.has(key):
		return null
	var body := Node3D.new()
	body.position.y = 1.0
	parent.add_child(body)
	var nodes := {}
	var outfit: Material = toon_of(make_color(c)) if not FIXED_LOOK.has(kind) else null
	for part in char_lib[key]:
		var mi := MeshInstance3D.new()
		mi.mesh = char_lib[key][part][0]
		mi.transform = char_lib[key][part][1]
		body.add_child(mi)
		nodes[part] = mi
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i)
			if outfit != null and m != null and m.resource_name == "Outfit":
				mi.set_surface_override_material(i, outfit)
			else:
				mi.set_surface_override_material(i, toon_of(m))
	# 아래팔은 위팔에, 정강이는 허벅지에 매달아요 (팔꿈치와 무릎이 접혀요)
	for pair in [["ForeL", "ArmL"], ["ForeR", "ArmR"], ["ShinL", "LegL"], ["ShinR", "LegR"]]:
		if nodes.has(pair[0]) and nodes.has(pair[1]):
			var child: Node3D = nodes[pair[0]]
			var holder: Node3D = nodes[pair[1]]
			var t := holder.transform.affine_inverse() * child.transform
			body.remove_child(child)
			holder.add_child(child)
			child.transform = t
	body.set_meta("model_parts", nodes)
	return body

func make_person(parent: Node3D, kind: String, c: Color, solid: bool) -> Node3D:
	var model := make_person_model(parent, kind, c)
	if model != null:
		model.set_meta("blink_at", rng.randf_range(1.0, 4.0))
		model.set_meta("blink_on", false)
		people.append(model)
		if solid:
			var mcol := CollisionShape3D.new()
			mcol.shape = CapsuleShape3D.new()
			mcol.position.y = 1.0
			parent.add_child(mcol)
		return model
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
	if body.has_meta("skel"):
		pose_rig(body, swing, arm_up)
		return
	if body.has_meta("model_parts"):
		var nodes: Dictionary = body.get_meta("model_parts")
		for side in ["L", "R"]:
			var sx := -1.0 if side == "L" else 1.0
			var leg := swing * 0.65 * sx
			if nodes.has("Leg" + side):
				(nodes["Leg" + side] as Node3D).rotation.x = lerpf(leg, -0.55, arm_up)
			if nodes.has("Shin" + side):
				# 다리가 뒤로 갈 때 무릎이 접혀요. 점프하면 웅크려요
				var knee := clampf(leg * 1.3, 0.0, 1.1) + absf(swing) * 0.15
				(nodes["Shin" + side] as Node3D).rotation.x = lerpf(knee, 1.0, arm_up)
			if nodes.has("Arm" + side):
				(nodes["Arm" + side] as Node3D).rotation.x = lerpf(-swing * 0.6 * sx, -2.5, arm_up)
			if nodes.has("Fore" + side):
				# 걸을 때 팔꿈치가 살짝 굽어요
				var elbow := -0.18 - absf(swing) * 0.45 - maxf(0.0, -swing * sx) * 0.3
				(nodes["Fore" + side] as Node3D).rotation.x = lerpf(elbow, -0.2, arm_up)
		return
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
	if body.has_meta("skel"):
		return
	if body.has_meta("model_parts"):
		var nodes: Dictionary = body.get_meta("model_parts")
		if nodes.has("Eyes"):
			(nodes["Eyes"] as Node3D).scale.y = 0.12 if closed else 1.0
		return
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
	if body.has_meta("skel"):
		return
	if body.has_meta("model_parts"):
		var mat := toon_of(make_color(c))
		for mi in (body.get_meta("model_parts") as Dictionary).values():
			for i in (mi as MeshInstance3D).mesh.get_surface_count():
				var m: Material = (mi as MeshInstance3D).mesh.surface_get_material(i)
				if m != null and m.resource_name == "Outfit":
					(mi as MeshInstance3D).set_surface_override_material(i, mat)
		return
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

# ---------- 세상 만들기 ----------

# ---------- 약초 도감 (6종, 종류마다 3번, 캐면 3분 뒤 다시 자라요) ----------

var HERBS := [
	{"name": tr("쑥"), "hint": tr("마을 길가"), "reward": 5, "spots": [Vector3(-5.6, 0, 16.5), Vector3(8.5, 0, 24.5)]},
	{"name": tr("냉이"), "hint": tr("논 근처"), "reward": 5, "spots": [Vector3(16.5, 0, 35.8), Vector3(31.2, 0, 36.2)]},
	{"name": tr("달래"), "hint": tr("개울가"), "reward": 6, "spots": [Vector3(-27.0, 0, -13.1), Vector3(12.0, 0, -13.2)]},
	{"name": tr("도라지"), "hint": tr("개울 건너 숲"), "reward": 8, "spots": [Vector3(-14.0, 0, -27.0), Vector3(10.0, 0, -26.0)]},
	{"name": tr("더덕"), "hint": tr("깊은 숲 속"), "reward": 10, "spots": [Vector3(-33.0, 0, -31.0), Vector3(3.0, 0, -37.0)]},
	{"name": tr("산삼"), "hint": tr("아무도 안 가는 숲 구석"), "reward": 25, "spots": [Vector3(-36.5, 0, -36.5), Vector3(37.0, 0, -31.5)]},
]
const HERB_NEED := 3
const HERB_REGROW := 180.0
var herb_counts := [0, 0, 0, 0, 0, 0]
var herb_reward := false
var wild_spots: Array = []   # [노드, 종류, 다시 자랄 때까지 남은 시간]

# ---------- 도감 책 ----------

var book_button: Button
var book_overlay: ColorRect
var book_canvas: Control
var book_title: Label
var book_footer: Label
var book_tab := "fish"
var book_open := false
var book_tabs := {}
var story_box: VBoxContainer
var story_buttons: Array = []
var story_reader: Panel
var story_reader_label: Label

func make_book_ui() -> void:
	book_button = Button.new()
	book_button.text = tr("도감")
	skin_button(book_button, make_paper(font_size * 0.4), INK, 0.8)
	book_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(book_button)
	place(book_button, 0.78, 0.075, 0.97, 0.135)
	book_overlay = make_overlay(0.55)
	book_overlay.visible = false
	var page := Panel.new()
	page.add_theme_stylebox_override("panel", make_paper(font_size * 0.6))
	book_overlay.add_child(page)
	place(page, 0.04, 0.08, 0.96, 0.93)
	book_title = add_label(page, "", 1.0, 0.05, 0.015, 0.95, 0.08)
	book_title.add_theme_color_override("font_color", INK)
	book_title.add_theme_constant_override("outline_size", 0)
	book_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var tx := 0.04
	for tab in [["fish", tr("물고기")], ["herb", tr("약초")], ["story", tr("이야기")]]:
		var b := Button.new()
		b.text = tab[1]
		page.add_child(b)
		place(b, tx, 0.09, tx + 0.29, 0.15)
		b.pressed.connect(func(): show_book(tab[0]))
		book_tabs[tab[0]] = b
		tx += 0.315
	# 이야기 탭: 조각 목록과 읽기 화면
	story_box = VBoxContainer.new()
	story_box.add_theme_constant_override("separation", 8)
	page.add_child(story_box)
	place(story_box, 0.05, 0.17, 0.95, 0.81)
	for i in STORY.size():
		var sb := Button.new()
		sb.alignment = HORIZONTAL_ALIGNMENT_LEFT
		sb.size_flags_vertical = Control.SIZE_EXPAND_FILL
		story_box.add_child(sb)
		sb.pressed.connect(func(): read_story(i))
		story_buttons.append(sb)
	story_reader = Panel.new()
	story_reader.add_theme_stylebox_override("panel", make_round(Color(1.0, 0.97, 0.88), font_size * 0.4))
	page.add_child(story_reader)
	place(story_reader, 0.04, 0.17, 0.96, 0.81)
	story_reader_label = add_label(story_reader, "", 0.85, 0.06, 0.04, 0.94, 0.82)
	story_reader_label.add_theme_color_override("font_color", INK)
	story_reader_label.add_theme_constant_override("outline_size", 0)
	story_reader_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story_reader_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	var back := Button.new()
	back.text = tr("목록으로")
	skin_button(back, make_round(Color(0.9, 0.84, 0.7), font_size * 0.35), INK, 0.8)
	story_reader.add_child(back)
	place(back, 0.3, 0.85, 0.7, 0.96)
	back.pressed.connect(func():
		sfx("tap")
		story_reader.visible = false
		story_box.visible = true)
	book_canvas = Control.new()
	book_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(book_canvas)
	place(book_canvas, 0.03, 0.16, 0.97, 0.82)
	book_canvas.draw.connect(draw_book)
	book_footer = add_label(page, "", 0.72, 0.05, 0.82, 0.95, 0.9)
	book_footer.add_theme_color_override("font_color", INK)
	book_footer.add_theme_constant_override("outline_size", 0)
	book_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	book_footer.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	book_footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var close := Button.new()
	close.text = tr("닫기")
	skin_button(close, make_round(Color(0.75, 0.45, 0.25), font_size * 0.4), Color(1, 1, 1), 0.85)
	page.add_child(close)
	place(close, 0.3, 0.905, 0.7, 0.975)
	close.pressed.connect(close_book)

func open_book() -> void:
	if is_busy():
		return
	sfx("tap")
	book_open = true
	move_input = Vector2.ZERO
	book_overlay.visible = true
	show_book(book_tab)
	pop(book_overlay.get_child(0) as Control, 1.05)

func close_book() -> void:
	sfx("tap")
	book_open = false
	book_overlay.visible = false

func show_book(tab: String) -> void:
	book_tab = tab
	story_box.visible = tab == "story"
	story_reader.visible = false
	book_canvas.visible = tab != "story"
	for key in book_tabs:
		var b: Button = book_tabs[key]
		var on: bool = key == tab
		skin_button(b, make_round(Color(0.95, 0.72, 0.3) if on else Color(0.9, 0.84, 0.7), font_size * 0.35), INK, 0.85)
	if tab == "fish":
		book_title.text = tr("물고기 도감 %d/%d") % [fish_kinds_found(), FISH.size()]
		if fish_kinds_found() >= FISH.size():
			book_footer.text = tr("다 모았어요! 강태공 할아버지도 깜짝 놀랐어요.")
		else:
			book_footer.text = tr("남쪽 연못 나루터에서 낚시해요.\n다 모으면 50냥!")
	elif tab == "story":
		book_title.text = tr("이야기 조각 %d/%d") % [story_count(), STORY.size()]
		for i in STORY.size():
			var sb: Button = story_buttons[i]
			if story_read[i]:
				sb.text = "  %d. %s" % [i + 1, STORY[i]["title"]]
				skin_button(sb, make_round(Color(1.0, 0.95, 0.8), font_size * 0.3), INK, 0.8)
			else:
				sb.text = "  %d. ???   (%s)" % [i + 1, STORY[i]["hint"]]
				skin_button(sb, make_round(Color(0.88, 0.84, 0.76), font_size * 0.3), Color(0.5, 0.45, 0.4), 0.72)
		if story_count() >= STORY.size():
			book_footer.text = tr("일곱 조각이 하나로 이어졌어요. 놀부는 어떤 형이었을까요?")
		else:
			book_footer.text = tr("찾은 조각을 누르면 다시 읽을 수 있어요.\n산신령에게서 받는 조각도 있어요.")
	else:
		book_title.text = tr("약초 도감 %d/%d") % [herb_kinds_done(), HERBS.size()]
		if herb_kinds_done() >= HERBS.size():
			book_footer.text = tr("다 모았어요! 마을 최고의 약초꾼이에요.")
		else:
			book_footer.text = tr("종류마다 3번씩 캐면 도감에 올라가요.\n캔 자리는 3분 뒤 다시 자라요. 다 모으면 40냥!")
	book_canvas.queue_redraw()

func draw_herb2d(ci: CanvasItem, c: Vector2, s: float, kind: int, dark: bool) -> void:
	var leaf := Color(0.38, 0.62, 0.3)
	var shade := Color(0.25, 0.22, 0.2, 0.35)
	var ol := 0.0 if dark else 3.0
	var L := shade if dark else leaf
	ci.draw_colored_polygon(ell_pts(c + Vector2(0, s * 0.9), s * 0.6, s * 0.12), Color(0.45, 0.33, 0.22, 0.25 if dark else 0.6))
	match kind:
		0:
			for i in 7:
				var a := -1.2 + i * 0.4
				d_ell(ci, c + Vector2(0, s * 0.35) + Vector2(0, -s * 0.45).rotated(a), s * 0.14, s * 0.42, shade if dark else Color(0.55, 0.68, 0.5), a, ol)
		1:
			for i in 6:
				var a := -1.4 + i * 0.56
				d_ell(ci, c + Vector2(0, s * 0.82) + Vector2(0, -s * 0.3).rotated(a), s * 0.1, s * 0.32, L, a, ol)
			for x in [-0.15, 0.1, 0.3]:
				d_line(ci, c + Vector2(0, s * 0.8), c + Vector2(x * s, -s * 0.5), L, 3)
				for k in 3:
					ci.draw_circle(c + Vector2(x * s + (k - 1) * s * 0.07, -s * 0.5 - (k % 2) * s * 0.06), s * 0.06, shade if dark else Color(1, 1, 0.97))
		2:
			for i in 7:
				var a := -0.5 + i * 0.16
				d_line(ci, c + Vector2(0, s * 0.75), c + Vector2(0, s * 0.75) + Vector2(0, -s * 1.3).rotated(a), L, 4)
			d_ell(ci, c + Vector2(0, s * 0.8), s * 0.18, s * 0.14, shade if dark else Color(0.98, 0.96, 0.9), 0.0, ol)
		3:
			for x in [-0.35, 0.0, 0.35]:
				var top := c + Vector2(x * s, -s * 0.45 + absf(x) * s * 0.4)
				d_line(ci, c + Vector2(0, s * 0.85), top, L, 4)
				d_ell(ci, c + Vector2(x * s * 0.5, s * 0.3), s * 0.16, s * 0.07, L, 0.5 * signf(x + 0.01), ol)
				for k in 5:
					var b := k * TAU / 5.0 - PI / 2.0
					d_ell(ci, top + Vector2(cos(b), sin(b)) * s * 0.13, s * 0.11, s * 0.07, shade if dark else Color(0.62, 0.48, 0.92), b, 0.0 if dark else 2.0)
				ci.draw_circle(top, s * 0.05, shade if dark else Color(1.0, 0.95, 0.6))
		4:
			d_line(ci, c + Vector2(0, s * 0.9), c + Vector2(0, -s * 0.8), shade if dark else Color(0.45, 0.32, 0.2), 5)
			for i in 6:
				var y := s * 0.75 - i * s * 0.27
				var sx := -1.0 if i % 2 == 0 else 1.0
				d_ell(ci, c + Vector2(sx * s * 0.18, y), s * 0.17, s * 0.09, L, sx * 0.4, ol)
			for y in [-0.15, -0.6]:
				var bell := PackedVector2Array([c + Vector2(s * 0.18, y * s - s * 0.1), c + Vector2(s * 0.32, y * s + s * 0.15), c + Vector2(s * 0.04, y * s + s * 0.15)])
				d_poly(ci, bell, shade if dark else Color(0.68, 0.74, 0.52), ol)
		5:
			d_line(ci, c + Vector2(0, s * 0.85), c + Vector2(0, -s * 0.2), L, 4)
			for a in [-0.9, 0.0, 0.9]:
				var base := c + Vector2(0, -s * 0.15) + Vector2(0, -s * 0.15).rotated(a)
				for k in 5:
					var b: float = a + (k - 2) * 0.38 - PI / 2.0
					d_ell(ci, base + Vector2(cos(b), sin(b)) * s * 0.26, s * 0.2, s * 0.08, L, b, 0.0 if dark else 2.0)
			for k in 6:
				ci.draw_circle(c + Vector2((k % 3 - 1) * s * 0.07, -s * 0.48 - (k / 3) * s * 0.08), s * 0.06, shade if dark else Color(0.9, 0.12, 0.12))

func draw_book() -> void:
	var ci: CanvasItem = book_canvas
	var sz := book_canvas.size
	var cw := sz.x / 2.0
	var ch := sz.y / 3.0
	var fs := int(font_size * 0.72)
	var small := int(font_size * 0.55)
	var rarity := [tr("흔함"), tr("흔함"), tr("보통"), tr("보통"), tr("드묾"), tr("아주 드묾")]
	for i in 6:
		var cc := Vector2(cw * (i % 2) + cw / 2.0, ch * (i / 2) + ch / 2.0)
		var got := false
		var name_t := "???"
		var sub := ""
		if book_tab == "fish":
			got = int(fish_caught[i]) > 0
			if got:
				name_t = FISH[i]["name"]
				sub = tr("%d마리 낚음 | %d냥") % [fish_caught[i], FISH[i]["pay"]]
			else:
				sub = rarity[i]
		else:
			got = int(herb_counts[i]) >= HERB_NEED
			if int(herb_counts[i]) > 0:
				name_t = HERBS[i]["name"]
			sub = "%d/%d  %s" % [mini(int(herb_counts[i]), HERB_NEED), HERB_NEED, HERBS[i]["hint"] if not got else tr("완성!")]
		var card_col := Color(1.0, 0.97, 0.88) if got else Color(0.9, 0.86, 0.78)
		d_box(ci, cc, Vector2(cw - 18, ch - 18), 0.0, card_col, 3.0)
		var pic := cc + Vector2(0, -ch * 0.1)
		if book_tab == "fish":
			draw_fish2d(ci, pic, cw * 0.22, i, 0.0, not got)
		else:
			draw_herb2d(ci, pic, ch * 0.22, i, int(herb_counts[i]) == 0)
		if got:
			ci.draw_circle(cc + Vector2(cw * 0.36, -ch * 0.34), 14, Color(0.95, 0.4, 0.3))
		ci.draw_string(font, Vector2(cc.x - cw / 2.0, cc.y + ch * 0.26), name_t, HORIZONTAL_ALIGNMENT_CENTER, cw, fs, INK)
		ci.draw_string(font, Vector2(cc.x - cw / 2.0, cc.y + ch * 0.4), sub, HORIZONTAL_ALIGNMENT_CENTER, cw, small, Color(0.45, 0.35, 0.25))

# ---------- 랜덤 위치 (원래 자리 근처에서 매번 조금씩 다른 곳에 나타나요) ----------

const SCATTER_PIECE := 6.0
const SCATTER_HERB := 4.0

func ground_ok(p: Vector3) -> bool:
	if absf(p.x) > 37.0 or absf(p.z) > 37.0:
		return false
	for rc in house_rects:
		if (rc as Rect2).grow(0.6).has_point(Vector2(p.x, p.z)):
			return false
	if absf(p.z - creek_z(p.x)) < creek_half(p.x) + 1.0:
		return false
	var q := (p - POND_C) / Vector3(6.8, 1, 5.2)
	if Vector2(q.x, q.z).length() < 1.0:
		return false
	var space := get_world_3d().direct_space_state
	var shape := SphereShape3D.new()
	shape.radius = 0.75
	var prm := PhysicsShapeQueryParameters3D.new()
	prm.shape = shape
	prm.transform = Transform3D(Basis(), p + Vector3(0, 0.9, 0))
	if player != null:
		prm.exclude = [player.get_rid()]
	return space.intersect_shape(prm, 1).is_empty()

func random_near(anchor: Vector3, radius: float) -> Vector3:
	if radius <= 0.0:
		return anchor
	for i in 40:
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf()) * radius
		var p := anchor + Vector3(cos(a) * d, 0, sin(a) * d)
		p.y = 0.0
		if ground_ok(p):
			return p
	return anchor

# 빨래는 개울 양쪽 물가를 따라 세 구간에 하나씩 흩어져요
var laundry_seg := 0
# 돌리기 버튼: 동그랗게 도는 화살표
func draw_turn_icon(ci: Control) -> void:
	var c := ci.size / 2.0
	var r := minf(ci.size.x, ci.size.y) * 0.3
	var col := INK
	var a0 := -PI * 0.15
	var a1 := PI * 1.45
	ci.draw_arc(c, r, a0, a1, 32, col, r * 0.28, true)
	var end := c + Vector2(cos(a1), sin(a1)) * r
	var tangent := Vector2(-sin(a1), cos(a1))
	var normal := Vector2(cos(a1), sin(a1))
	var h := r * 0.55
	ci.draw_colored_polygon(PackedVector2Array([end + tangent * h, end + normal * h * 0.75 - tangent * h * 0.15, end - normal * h * 0.75 - tangent * h * 0.15]), col)

# ---------- 설정 (왼손잡이/오른손잡이), 처음 한 번 걷기 안내 ----------

var settings_button: Button
var settings_overlay: ColorRect
var settings_open := false
var hand_buttons := {}
var left_handed := false
var walk_hint: Control
var walk_hint_on := false
var walk_hint_seen := false
var walk_hint_time := 0.0

func load_controls() -> void:
	var cf := ConfigFile.new()
	if cf.load("user://save.cfg") != OK:
		return
	left_handed = cf.get_value("ui", "left_handed", false)
	walk_hint_seen = cf.get_value("ui", "walk_hint_seen", false)
	cam_hint_seen = cf.get_value("ui", "cam_hint_seen", false)
	auto_cam = cf.get_value("ui", "auto_cam", true)

func save_controls() -> void:
	var cf := ConfigFile.new()
	cf.load("user://save.cfg")
	cf.set_value("ui", "left_handed", left_handed)
	cf.set_value("ui", "walk_hint_seen", walk_hint_seen)
	cf.set_value("ui", "cam_hint_seen", cam_hint_seen)
	cf.set_value("ui", "auto_cam", auto_cam)
	cf.set_value("ui", "music_on", music_on)
	cf.set_value("ui", "sfx_on", sfx_on)
	cf.save("user://save.cfg")

func apply_hand() -> void:
	if left_handed:
		place(jump_button, 0.03, 0.83, 0.25, 0.92)
	else:
		place(jump_button, 0.75, 0.83, 0.97, 0.92)

func make_settings_ui() -> void:
	settings_button = Button.new()
	settings_button.text = tr("설정")
	skin_button(settings_button, make_paper(font_size * 0.4), INK, 0.8)
	settings_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(settings_button)
	ui_layer.move_child(settings_button, book_button.get_index())
	place(settings_button, 0.57, 0.075, 0.76, 0.135)
	settings_overlay = make_overlay(0.55)
	var page := Panel.new()
	page.add_theme_stylebox_override("panel", make_paper(font_size * 0.6))
	settings_overlay.add_child(page)
	place(page, 0.06, 0.17, 0.94, 0.83)
	var title := add_label(page, tr("설정"), 1.0, 0.05, 0.04, 0.95, 0.17)
	title.add_theme_color_override("font_color", INK)
	title.add_theme_constant_override("outline_size", 0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub := add_label(page, tr("점프 버튼 위치"), 0.8, 0.05, 0.13, 0.95, 0.21)
	sub.add_theme_color_override("font_color", Color(0.45, 0.35, 0.25))
	sub.add_theme_constant_override("outline_size", 0)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var opts := [[false, tr("오른손잡이\n(점프 오른쪽)")], [true, tr("왼손잡이\n(점프 왼쪽)")]]
	var x := 0.06
	for o in opts:
		var b := Button.new()
		b.text = o[1]
		page.add_child(b)
		place(b, x, 0.22, x + 0.42, 0.4)
		var val: bool = o[0]
		b.pressed.connect(func(): set_hand(val))
		hand_buttons[val] = b
		x += 0.46
	var again := Button.new()
	again.text = tr("걷기 안내 보기")
	skin_button(again, make_round(Color(0.9, 0.84, 0.7), font_size * 0.35), INK, 0.78)
	page.add_child(again)
	place(again, 0.06, 0.645, 0.48, 0.725)
	cam_btn = Button.new()
	page.add_child(cam_btn)
	place(cam_btn, 0.52, 0.645, 0.94, 0.725)
	cam_btn.pressed.connect(func():
		auto_cam = not auto_cam
		save_controls()
		refresh_hand_buttons()
		sfx("tap"))
	var restart := Button.new()
	restart.text = tr("처음부터 다시 하기...")
	skin_button(restart, make_round(Color(0.93, 0.78, 0.72), font_size * 0.35), Color(0.55, 0.18, 0.12), 0.75)
	page.add_child(restart)
	place(restart, 0.06, 0.74, 0.48, 0.81)
	# 언어 바꾸기: 어느 언어 상태에서도 찾을 수 있게 영어와 한국어를 같이 써요
	var lang_btn := Button.new()
	lang_btn.text = "Language: 한국어" if lang() == "ko" else "Language: English"
	skin_button(lang_btn, make_round(Color(0.72, 0.8, 0.95), font_size * 0.35), INK, 0.75)
	page.add_child(lang_btn)
	place(lang_btn, 0.52, 0.74, 0.94, 0.81)
	lang_btn.pressed.connect(func():
		sfx("tap")
		set_lang("en" if lang() == "ko" else "ko"))
	restart.pressed.connect(func():
		close_settings()
		ask("", tr("어디부터 다시 할까요?\n- 이 장만: 지금 장 이야기만 처음으로 (엽전·물건·다른 장은 그대로)\n- 모든 장: 1장부터 새로 (도감, 엔딩 기록, 설정은 남아요)"), [tr("이 장만 처음부터"), tr("모든 장 처음부터"), tr("그만둘래요")], func(i: int):
			if i == 0:
				reset_chapter()
			elif i == 1:
				reset_progress()))
	var snd := add_label(page, tr("소리"), 0.8, 0.05, 0.43, 0.95, 0.5)
	snd.add_theme_color_override("font_color", Color(0.45, 0.35, 0.25))
	snd.add_theme_constant_override("outline_size", 0)
	snd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	music_btn = Button.new()
	page.add_child(music_btn)
	place(music_btn, 0.06, 0.51, 0.48, 0.62)
	music_btn.pressed.connect(func():
		music_on = not music_on
		apply_audio_toggles()
		save_controls()
		refresh_hand_buttons())
	sfx_btn = Button.new()
	page.add_child(sfx_btn)
	place(sfx_btn, 0.52, 0.51, 0.94, 0.62)
	sfx_btn.pressed.connect(func():
		sfx_on = not sfx_on
		apply_audio_toggles()
		save_controls()
		refresh_hand_buttons()
		sfx("tap"))
	again.pressed.connect(func():
		close_settings()
		show_walk_hint())
	var close := Button.new()
	close.text = tr("닫기")
	skin_button(close, make_round(Color(0.75, 0.45, 0.25), font_size * 0.4), Color(1, 1, 1), 0.85)
	page.add_child(close)
	place(close, 0.3, 0.84, 0.7, 0.95)
	close.pressed.connect(close_settings)
	refresh_hand_buttons()

var music_btn: Button
var sfx_btn: Button
var cam_btn: Button

func refresh_hand_buttons() -> void:
	if music_btn != null:
		music_btn.text = tr("배경음 켜짐") if music_on else tr("배경음 꺼짐")
		skin_button(music_btn, make_round(Color(0.95, 0.72, 0.3) if music_on else Color(0.85, 0.8, 0.72), font_size * 0.35), INK, 0.78)
		sfx_btn.text = tr("효과음 켜짐") if sfx_on else tr("효과음 꺼짐")
		skin_button(sfx_btn, make_round(Color(0.95, 0.72, 0.3) if sfx_on else Color(0.85, 0.8, 0.72), font_size * 0.35), INK, 0.78)
	if cam_btn != null:
		cam_btn.text = tr("카메라 따라오기 켜짐") if auto_cam else tr("카메라 따라오기 꺼짐")
		skin_button(cam_btn, make_round(Color(0.95, 0.72, 0.3) if auto_cam else Color(0.85, 0.8, 0.72), font_size * 0.35), INK, 0.7)
	for key in hand_buttons:
		var on: bool = key == left_handed
		skin_button(hand_buttons[key], make_round(Color(0.95, 0.72, 0.3) if on else Color(0.9, 0.84, 0.7), font_size * 0.35), INK, 0.8)

func set_hand(v: bool) -> void:
	sfx("tap")
	left_handed = v
	apply_hand()
	refresh_hand_buttons()
	save_controls()

func open_settings() -> void:
	if is_busy():
		return
	sfx("tap")
	settings_open = true
	move_input = Vector2.ZERO
	settings_overlay.visible = true
	refresh_hand_buttons()
	pop(settings_overlay.get_child(0) as Control, 1.05)

func close_settings() -> void:
	sfx("tap")
	settings_open = false
	settings_overlay.visible = false

# 화면 가운데에 손가락이 밀어 보이는 그림으로 걷는 법을 알려 줘요
func make_walk_hint() -> void:
	walk_hint = Control.new()
	walk_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	walk_hint.visible = false
	ui_layer.add_child(walk_hint)
	place(walk_hint, 0, 0, 1, 1)
	walk_hint.draw.connect(draw_walk_hint)

func show_walk_hint() -> void:
	walk_hint_on = true
	walk_hint_time = 0.0
	walk_hint.visible = true
	walk_hint.modulate.a = 1.0

func hide_walk_hint() -> void:
	walk_hint_on = false
	walk_hint_seen = true
	save_controls()
	var tw := walk_hint.create_tween()
	tw.tween_property(walk_hint, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func(): walk_hint.visible = false)

func update_walk_hint(delta: float) -> void:
	if not walk_hint_on:
		return
	walk_hint.queue_redraw()
	if move_input.length() > 0.3 and not is_busy():
		walk_hint_time += delta
		if walk_hint_time > 1.2:
			hide_walk_hint()

func draw_walk_hint() -> void:
	var ci: CanvasItem = walk_hint
	var sz := walk_hint.size
	var c := Vector2(sz.x * 0.5, sz.y * 0.6)
	var r := short_side * 0.16
	ci.draw_colored_polygon(ell_pts(c, r * 1.9, r * 1.55), Color(0, 0, 0, 0.18))
	ci.draw_arc(c, r, 0, TAU, 48, Color(1, 1, 1, 0.85), 6, true)
	for k in 4:
		var a := k * PI / 2.0
		var tip := c + Vector2(cos(a), sin(a)) * (r + 26)
		var side := Vector2(cos(a), sin(a)).orthogonal() * 14
		var back := c + Vector2(cos(a), sin(a)) * (r + 8)
		ci.draw_colored_polygon(PackedVector2Array([tip, back + side, back - side]), Color(1, 1, 1, 0.85))
	# 손가락이 위쪽, 오른쪽으로 밀었다 돌아와요
	var t := fmod(anim_t * 0.6, 2.0)
	var dir := Vector2(0, -1) if t < 1.0 else Vector2(1, 0)
	var push := sin(fmod(t, 1.0) * PI)
	var knob := c + dir * r * 0.7 * push
	ci.draw_circle(knob, r * 0.42, Color(1.0, 0.85, 0.45, 0.95))
	ci.draw_arc(knob, r * 0.42, 0, TAU, 32, Color(0.6, 0.4, 0.2), 4, true)
	d_ell(ci, knob + Vector2(10, 30), 22, 34, Color(0.99, 0.84, 0.7), 0.0, 3.0)
	d_ell(ci, knob + Vector2(10, -2), 12, 16, Color(1, 0.92, 0.85), 0.0, 2.0)
	var msg := tr("화면 아무 곳이나 누른 채\n밀면 그쪽으로 걸어요") if is_touch_device() else tr("WASD나 방향키로 걷고, 스페이스로 점프해요\nE나 엔터로 말을 걸어요")
	var fs := int(font_size * 0.95)
	var y := c.y + r * 1.25
	for line in msg.split("\n"):
		ci.draw_string_outline(font, Vector2(0, y + fs), line, HORIZONTAL_ALIGNMENT_CENTER, sz.x, fs, 10, Color(0.25, 0.15, 0.08))
		ci.draw_string(font, Vector2(0, y + fs), line, HORIZONTAL_ALIGNMENT_CENTER, sz.x, fs, Color(1, 1, 1))
		y += fs * 1.3

# ---------- 이야기 조각 7개: 놀부는 왜 놀부가 되었을까 ----------

var STORY := [
	{"title": tr("담벼락의 키 재기"), "hint": tr("놀부네 담장 근처"), "text": tr("놀부네 담장 뒤편에는 희미한 금이 두 줄 그어져 있어요.\n어린 형제가 해마다 키를 재며 새긴 자국이에요.\n놀부의 금은 언제나 흥부보다 손가락 한 마디 높았어요.\n“형은 동생보다 커야 해. 그래야 지켜 줄 수 있으니까.”")},
	{"title": tr("첫 박씨"), "hint": tr("서쪽 개울가"), "text": tr("어느 봄, 아버지는 형제에게 박씨를 하나씩 주었어요.\n놀부의 박은 장맛비에 썩고, 흥부의 박만 주렁주렁 열렸어요.\n아버지가 흥부의 머리를 쓰다듬던 날 밤,\n놀부는 처음으로 몰래 이불을 덮고 울었어요.")},
	{"title": tr("흉년의 겨울"), "hint": tr("개울 건너 깊은 숲"), "text": tr("큰 흉년이 든 겨울, 아버지가 세상을 떠났어요.\n굶어서 우는 동생들을 보며 열다섯 살 놀부는 맹세했어요.\n“다시는 우리 집에 배고픈 사람이 없게 할 테야.”\n그날부터 놀부는 곳간 열쇠를 꼭 쥐고 잠들었어요.")},
	{"title": tr("높아진 대문"), "hint": tr("마을 남서쪽 집들 근처"), "text": tr("놀부가 부자가 되자 사람들이 줄지어 찾아왔어요.\n빌려 간 쌀은 돌아오지 않았고, 고맙다는 말도 없었어요.\n놀부는 대문을 한 자, 또 한 자 높이 쌓았어요.\n“베풀면 바보가 되는 거야.” 놀부는 그렇게 믿기로 했어요.")},
	{"title": tr("대문 밖의 쌀자루"), "hint": tr("남동쪽 논 근처"), "text": tr("흥부네가 쫓겨나던 날, 아무도 모르게\n놀부네 대문 밖에 쌀자루 하나가 놓여 있었어요.\n흥부는 이웃이 두고 간 줄 알았지요.\n자루를 묶은 매듭은, 놀부만 묶을 줄 아는 매듭이었어요.")},
	{"title": tr("제비가 본 것"), "hint": tr("점프해야 닿는 큰 바위 위"), "text": tr("강남으로 떠나기 전, 제비는 이 바위에서 쉬어 갔어요.\n그리고 보았어요. 밤마다 놀부가 담장에 기대어\n흥부네 초가 굴뚝 연기를 오래 바라보다\n한숨을 쉬고 돌아서는 것을요.")},
	{"title": tr("산신령의 말"), "hint": tr("숲속 연못의 산신령"), "text": tr("“욕심은 두려움에서 자라느니라.\n놀부가 움켜쥔 것은 재물이 아니라\n다시는 굶지 않겠다던 어린 날의 약속이란다.\n그 마음을 알아주는 이가 있다면, 높은 대문도 열리느니라.”")},
]
var story_read := [false, false, false, false, false, false, false]

# ---------- 마을 안에서 하는 3D 미니게임 (우물, 나무하기, 낚시) ----------
var mg_world := false
var mg_back: Control
var mg_world_ui: Control
var mg_nodes: Array = []        # 게임 동안만 있는 3D 물체
var world_cam: Transform3D
var hud_hidden: Array = []
var tool_node: MeshInstance3D   # 손에 든 도구 (도끼, 낚싯대)
var tool_kind := ""
var w := {}                     # 게임마다 쓰는 상태
var cam_kick := 0.0             # 내려찍을 때 카메라가 움찔
var line_mesh: ImmediateMesh
var line_node: MeshInstance3D

var world_hidden: Array = []

# ---------- 나무하기: 타이밍 맞춰 도끼로 쩍! ----------

# ---------- 우물: 두레박을 당겨 물 길어 올리기 ----------

const WELL_TOP := 1.12
const WELL_WATER := 0.72

# ---------- 낚시 (3D): 연못 위 찌, 물고기 그림자, 튀어 오르는 물고기 ----------

# ---------- 화면 위 안내 (3D 게임은 배경 없이 막대·안내만) ----------

func draw_world_ui(ci: CanvasItem) -> void:
	var w2 := mg_overlay.size.x
	var h := mg_overlay.size.y
	if mg_type == "wood3d":
		var y := h * 0.8
		var bw := w2 * 0.8
		var x0 := w2 * 0.1
		d_box(ci, Vector2(w2 * 0.5, y), Vector2(bw + 16, 46), 0.0, Color(0.55, 0.38, 0.22), 4)
		d_box(ci, Vector2(w2 * 0.5, y), Vector2(bw, 30), 0.0, Color(0.95, 0.88, 0.7), 0)
		var zw := wood_zone() * bw
		d_box(ci, Vector2(w2 * 0.5, y), Vector2(zw, 30), 0.0, Color(0.45, 0.85, 0.4), 0)
		var mx := x0 + (wood_marker() * 0.5 + 0.5) * bw
		var inz := absf(wood_marker()) < wood_zone()
		d_box(ci, Vector2(mx, y), Vector2(14, 64), 0.0, Color(0.95, 0.35, 0.25) if not inz else Color(1, 0.95, 0.4), 3)
		ci.draw_string(font, Vector2(0, y - 46), tr("지금!") if inz else "", HORIZONTAL_ALIGNMENT_CENTER, w2, int(font_size * 0.9), Color(1, 1, 0.85))
	elif mg_type == "well3d":
		if w.get("state", "") == "pull":
			# 위로 쓸어 올리라는 화살표
			var x := w2 * 0.85
			var k := fmod(anim_t * 1.2, 1.0)
			for i in 3:
				var yy := h * (0.72 - 0.12 * i) - k * 30.0
				var a := 0.35 + 0.2 * i
				ci.draw_colored_polygon(PackedVector2Array([Vector2(x, yy - 30), Vector2(x - 26, yy), Vector2(x + 26, yy)]), Color(1, 1, 1, a))
			var sway: float = w.get("sway", 0.0)
			var y2 := h * 0.8
			d_box(ci, Vector2(w2 * 0.35, y2), Vector2(w2 * 0.5, 22), 0.0, Color(0.3, 0.3, 0.3, 0.5), 0)
			d_box(ci, Vector2(w2 * 0.1 + w2 * 0.25 * minf(sway, 1.6) / 1.6, y2), Vector2(w2 * 0.5 * minf(sway, 1.6) / 1.6, 22), 0.0, Color(0.95, 0.4, 0.3) if sway > 0.5 else Color(0.5, 0.85, 0.5), 0)
			ci.draw_string(font, Vector2(w2 * 0.1, y2 - 18), tr("흔들림"), HORIZONTAL_ALIGNMENT_LEFT, -1, int(font_size * 0.6), Color(1, 1, 1))
	elif mg_type == "fish" and mg_step >= 2:
		draw_reel_meter(ci)
	elif mg_type == "circle":
		# 여기를 빙글빙글 돌려요
		var c := Vector2(w2 * 0.5, h * 0.6)
		var r := mg_r
		var n := 36
		for i in n:
			if i % 2 == 0:
				var a0 := TAU * i / n + anim_t * 0.6
				var a1 := TAU * (i + 1) / n + anim_t * 0.6
				ci.draw_line(c + Vector2(cos(a0), sin(a0)) * r, c + Vector2(cos(a1), sin(a1)) * r, Color(1, 1, 1, 0.55), 5, true)
		var ah := anim_t * 1.8
		var tipp := c + Vector2(cos(ah), sin(ah)) * r
		var tang := Vector2(-sin(ah), cos(ah))
		ci.draw_colored_polygon(PackedVector2Array([tipp + tang * 22, tipp - tang * 6 + (tipp - c).normalized() * 14, tipp - tang * 6 - (tipp - c).normalized() * 14]), Color(1, 0.95, 0.6, 0.8))
		if mg_warn_time > 0.0:
			ci.draw_arc(c, r, 0, TAU, 48, Color(1, 0.4, 0.3, 0.7), 8, true)
	elif mg_type == "follow":
		var ty := h * 0.78
		d_box(ci, Vector2(w2 * 0.5, ty), Vector2(w2 * 0.82, 18), 0.0, Color(0.68, 0.5, 0.3), 3)
		var in_sync := is_instance_valid(mg_b) and mg_b.modulate.r < 0.9
		if is_instance_valid(mg_a):
			var gx := node_center(mg_a).x
			d_box(ci, Vector2(gx, ty), Vector2(30, 66), 0.0, Color(0.55, 0.35, 0.18), 4)
			ci.draw_string(font, Vector2(gx - 26, ty - 44), tr("흥부") if w.get("scene", "") == "saw" else tr("첨지"), HORIZONTAL_ALIGNMENT_LEFT, -1, int(font_size * 0.5), Color(1, 1, 1))
		if mg_touch:
			d_box(ci, Vector2(mg_pos.x, ty), Vector2(30, 66), 0.0, Color(0.6, 0.95, 0.6) if in_sync else Color(0.98, 0.95, 0.85), 4)

# ---------- 나머지 미니게임도 마을 안 3D 장면으로 ----------
# 놀이 규칙(원 그리기, 박자 맞추기, 받기, 누르기, 모내기)은 그대로 두고, 보이는 것만 3D로 바꿔요.
# 누르기 게임은 보이지 않는 버튼이 3D 물체를 따라다녀서 물체를 누르면 돼요.
var ong_cracks: Array = []
var world_moved: Array = []    # [노드, 원래 위치, 원래 회전]

func world_move(n: Node3D, pos: Vector3, face: Vector3) -> void:
	world_moved.append([n, n.position, n.rotation])
	n.position = pos
	n.rotation.y = atan2(face.x - pos.x, face.z - pos.z)

func world_restore() -> void:
	for it in world_moved:
		var n: Node3D = it[0]
		if is_instance_valid(n):
			n.position = it[1]
			n.rotation = it[2]
	world_moved = []

func fwd_of(from: Vector3, to: Vector3) -> Vector3:
	var d := to - from
	d.y = 0
	return d.normalized()

func blob_node(items: Array, mat: Material = null) -> Node3D:
	var n := Node3D.new()
	world_node(n)
	add_blobs(n, items, mat)
	return n

func cam_depth_of(target: Vector3, cam_pos: Vector3) -> float:
	return target.distance_to(cam_pos)

# 3D 물체를 화면 위치로 바꿔 보이지 않는 버튼을 거기 놓아요
func pin_button(b: Control, at: Vector3) -> void:
	var sp := cam.unproject_position(at)
	b.position = sp - b.size / 2.0

func scene_spawn_target() -> Vector3:
	match w["scene"]:
		"snake":
			var a := rng.randf_range(-1.0, 0.45)
			return Vector3(-15.08, 0.05, 0.6) + Vector3(sin(a) * 2.6, 0, cos(a) * 2.2)
		"kim":
			var pumps: Array = w["pumps"]
			return (pumps[rng.randi() % 3] as Vector3) + Vector3(rng.randf_range(-0.2, 0.2), 0.85, rng.randf_range(-0.15, 0.15))
		"sparrow":
			return FARM_C + Vector3(rng.randf_range(-3.6, 3.6), 0.6, rng.randf_range(-2.6, 2.6))
	return Vector3.ZERO

func scene_make_target(at: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = at
	world_node(n)
	match w["scene"]:
		"snake":
			var segs := []
			for k in 7:
				var seg := add_ball(n, Color(0.42, 0.58, 0.26).lerp(Color(0.55, 0.7, 0.3), k / 6.0), 0.1 - k * 0.008, Vector3.ZERO)
				segs.append(seg)
			add_ball(segs[0], Color(0.1, 0.08, 0.05), 0.022, Vector3(0.05, 0.05, 0.07))
			add_ball(segs[0], Color(0.1, 0.08, 0.05), 0.022, Vector3(-0.05, 0.05, 0.07))
			n.set_meta("segs", segs)
			n.set_meta("from", at)
		"kim":
			add_mbox(n, make_color(Color(0.86, 0.66, 0.4)), Vector3(0.14, 0.75, 0.14), Vector3(0, 0.05, 0))
			add_mbox(n, dark_wood_mat, Vector3(0.2, 0.08, 0.2), Vector3(0, 0.43, 0))
			n.set_meta("from", at)
		"sparrow":
			add_blobs(n, [
				[Vector3(0, 0, 0), Vector3(0.26, 0.2, 0.32), Color(0.6, 0.42, 0.28)],
				[Vector3(0, 0.1, 0.13), Vector3(0.17, 0.16, 0.16), Color(0.55, 0.32, 0.2)],
				[Vector3(0, 0.07, 0.18), Vector3(0.12, 0.08, 0.08), Color(0.98, 0.95, 0.9)],
				[Vector3(0, 0.1, 0.23), Vector3(0.05, 0.04, 0.06), Color(0.3, 0.25, 0.2)],
			])
			n.rotation.y = rng.randf() * TAU
			n.scale = Vector3(1.6, 1.6, 1.6)
			n.set_meta("from", at)
	add_target_marker(n)
	pop3d(n, true)
	return n

# 눌러야 할 목표 표시: 바닥의 줄어드는 노란 고리(남은 시간)와 위에서 콕콕 가리키는 화살표
func add_target_marker(n: Node3D) -> void:
	if n.has_meta("ring"):
		for k in ["ring", "arrow"]:
			(n.get_meta(k) as Node3D).visible = true
		return
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.24
	tm.outer_radius = 0.31
	tm.rings = 32
	ring.mesh = tm
	var rmat := StandardMaterial3D.new()
	rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rmat.albedo_color = Color(1.0, 0.85, 0.15)
	rmat.no_depth_test = true
	rmat.render_priority = 5
	ring.material_override = rmat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.top_level = true
	n.add_child(ring)
	var arrow := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.2
	cm.bottom_radius = 0.0
	cm.height = 0.36
	arrow.mesh = cm
	arrow.material_override = rmat
	arrow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	arrow.top_level = true
	n.add_child(arrow)
	n.set_meta("ring", ring)
	n.set_meta("arrow", arrow)

func update_target_marker(n: Node3D, tip: Vector3, t: float) -> void:
	if not n.has_meta("ring"):
		return
	var ring: MeshInstance3D = n.get_meta("ring")
	var arrow: MeshInstance3D = n.get_meta("arrow")
	var ground := Vector3(tip.x, maxf(0.06, tip.y - 0.25), tip.z)
	ring.global_position = ground
	ring.scale = Vector3.ONE * lerpf(1.25, 0.45, t)
	(ring.material_override as StandardMaterial3D).albedo_color = Color(1.0, 0.85, 0.15).lerp(Color(1.0, 0.35, 0.25), t)
	arrow.global_position = tip + Vector3(0, 0.55 + absf(sin(anim_t * 7.0)) * 0.18, 0)

func hide_target_marker(n: Node3D) -> void:
	for k in ["ring", "arrow"]:
		if n.has_meta(k):
			(n.get_meta(k) as Node3D).visible = false

func scene_target_update(n: Node3D, age: float, life: float) -> Vector3:
	var tip0 := scene_target_tip(n, age, life)
	update_target_marker(n, tip0, clampf(age / life, 0.0, 1.0))
	return tip0

func scene_target_tip(n: Node3D, age: float, life: float) -> Vector3:
	var t := clampf(age / life, 0.0, 1.0)
	var from: Vector3 = n.get_meta("from")
	match w["scene"]:
		"snake":
			# 기둥 밑까지 기어와서 둥지로 올라가요
			var base := Vector3(-15.05, 0.05, 0.45)
			var head: Vector3
			if t < 0.65:
				head = from.lerp(base, t / 0.65)
			else:
				head = base.lerp(Vector3(-15.05, 1.85, 0.35), (t - 0.65) / 0.35)
			var segs: Array = n.get_meta("segs")
			var dir := (head - (n.get_meta("prev", head) as Vector3))
			n.set_meta("prev", head)
			for k in segs.size():
				var back := (from - head).normalized() if t < 0.65 else Vector3(0, -1, 0)
				var side := back.cross(Vector3.UP).normalized() if t < 0.65 else Vector3(1, 0, 0)
				(segs[k] as Node3D).global_position = head + back * k * 0.12 + side * sin(anim_t * 10.0 - k * 0.9) * 0.06
			return head + Vector3(0, 0.1, 0)
		"kim":
			n.position = from + Vector3(0, -t * 0.35, 0)
			return n.position + Vector3(0, 0.25, 0)
		"sparrow":
			n.position = from + Vector3(0, absf(sin(anim_t * 9.0 + from.x)) * 0.08, 0)
			n.rotation.x = -0.6 * maxf(0.0, sin(anim_t * (8.0 + t * 10.0) + from.z))
			return n.position + Vector3(0, 0.15, 0)
	return n.position

func scene_target_hit(n: Node3D) -> void:
	var at := n.global_position
	hide_target_marker(n)
	shake(7)
	hit_stop(0.04)
	cam_kick = 0.15
	w["swing"] = 1.0
	match w["scene"]:
		"snake":
			sfx("crack", 1.4)
			burst3d(at + Vector3(0, 0.2, 0), Color(0.6, 0.75, 0.35), 12)
			float_text(tr("퍽!"), cam.unproject_position(at), Color(1, 0.95, 0.7), 1.3)
		"kim":
			sfx("pop", 0.8)
			chips3d(at)
			float_text(tr("쏙!"), cam.unproject_position(at), Color(1, 0.95, 0.7), 1.3)
		"sparrow":
			sfx("chirp", rng.randf_range(0.9, 1.2))
			burst3d(at + Vector3(0, 0.2, 0), Color(0.75, 0.55, 0.35), 10)
			float_text(tr("훠이!"), cam.unproject_position(at), Color(1, 0.95, 0.7), 1.2)
	# 날아가 버리기
	var away := Vector3(rng.randf_range(-1.5, 1.5), 2.5, rng.randf_range(-1.5, 1.5))
	var tw := n.create_tween()
	tw.tween_property(n, "position", n.position + away, 0.45).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(n, "rotation", n.rotation + Vector3(rng.randf_range(-6, 6), 6.0, 0), 0.45)
	tw.tween_property(n, "scale", Vector3(0.01, 0.01, 0.01), 0.15)
	tw.tween_callback(n.queue_free)

func scene_target_miss(n: Node3D) -> void:
	var at := n.global_position
	hide_target_marker(n)
	match w["scene"]:
		"snake":
			burst3d(Vector3(-15.08, 2.0, 0.3), Color(0.3, 0.3, 0.4), 10)
			float_text(tr("둥지가 위험해요!"), cam.unproject_position(at), Color(1, 0.55, 0.45), 1.0)
		"kim":
			float_text(tr("말뚝이 깊이 박혔어요!"), cam.unproject_position(at), Color(1, 0.55, 0.45), 1.0)
		"sparrow":
			float_text(tr("벼를 쪼아 먹었어요!"), cam.unproject_position(at), Color(1, 0.55, 0.45), 1.0)
	var tw := n.create_tween()
	tw.tween_property(n, "scale", Vector3(0.01, 0.01, 0.01), 0.25)
	tw.tween_callback(n.queue_free)

func scene_update(delta: float) -> void:
	if not w.has("scene"):
		return
	var scene: String = w["scene"]
	w["swing"] = maxf(0.0, float(w.get("swing", 0.0)) - delta * 4.0)
	if is_tap_scene(scene):
		tap_scene_update()
		return
	if is_catch_scene(scene):
		catch_scene_update()
		return
	match scene:
		"heal":
			var bird: Node3D = w["bird"]
			var threads: Array = w["threads"]
			var want := int(mg_progress * 9.0)
			while threads.size() < want:
				var k := threads.size()
				var tor := MeshInstance3D.new()
				var tm := TorusMesh.new()
				tm.inner_radius = 0.02
				tm.outer_radius = 0.034
				tor.mesh = tm
				tor.material_override = make_color(Color(1, 1, 0.97))
				tor.position = Vector3(0.07, 0.035, 0.0).lerp(Vector3(0.13, 0.0, 0.11), k / 8.0)
				tor.rotation = Vector3(0.6, 0.5, 0)
				bird.add_child(tor)
				threads.append(tor)
				sfx("tick", 1.0 + k * 0.05)
			var ouch := mg_warn_time > 0.0
			bird.position.y = (w["bird"] as Node3D).position.y
			bird.rotation.z = sin(anim_t * 40.0) * 0.08 if ouch else 0.0
			var flap := sin(anim_t * (30.0 if ouch else 3.0)) * (0.5 if ouch else 0.05)
			(w["wings"][0] as Node3D).rotation.z = flap
			(w["wings"][1] as Node3D).rotation.z = -flap
		"straw":
			var sole: Node3D = w["sole"]
			sole.scale = Vector3(1, 1, maxf(0.05, mg_progress))
			sole.position.z = -0.2 * (1.0 - mg_progress)
			(w["twist"] as Node3D).rotation.z = mg_last_angle * 2.0
		"ong":
			var patch: Node3D = w["patch"]
			var s := 0.05 + mg_progress * 0.95
			patch.scale = Vector3(s, s, 1)
			for c in w["crack_on"]:
				(c as Node3D).visible = mg_progress < 0.85
			var tr: Node3D = w["trowel"]
			var jc: Vector3 = w["jar_c"]
			tr.global_position = jc + Vector3(cos(mg_last_angle) * 0.2, -sin(mg_last_angle) * 0.2, 0.06)
			tr.rotation = Vector3(-1.2, 0, mg_last_angle)
			if mg_warn_time > 0.0:
				tr.position += Vector3(rng.randf_range(-0.02, 0.02), rng.randf_range(-0.02, 0.02), 0)
		"saw", "ditch":
			var wsz := mg_overlay.size.x
			var guide := 0.0
			if is_instance_valid(mg_a):
				guide = ((mg_a.position.x + mg_a.size.x / 2.0) - wsz * 0.5) / (wsz * 0.33)
			w["guide"] = guide
			var in_sync := is_instance_valid(mg_b) and mg_b.modulate.r < 0.9
			var dir_now := signf(cos(mg_phase))
			if dir_now != float(w.get("dir_last", 1.0)):
				w["dir_last"] = dir_now
				if in_sync:
					w["swing"] = 1.0
					if scene == "saw":
						var gp: Vector3 = w["gp"]
						burst3d(gp + Vector3(0, float(w["rad"]) * 2.0 - mg_progress * float(w["rad"]) * 0.7, 0.3), Color(0.95, 0.92, 0.8), 10)
						cam_kick = 0.08
					else:
						var dig: Vector3 = w["dig"]
						burst3d(dig + Vector3(0, 0.1, 0), Color(0.45, 0.33, 0.22), 10)
						cam_kick = 0.1
			if scene == "saw":
				var gp: Vector3 = w["gp"]
				var rad: float = w["rad"]
				(w["saw"] as Node3D).position = gp + Vector3(guide * 0.45, rad * 2.0 + 0.1 - mg_progress * rad * 0.45, 0)
				var cut: MeshInstance3D = w["cut"]
				cut.position = gp + Vector3(0, rad * 2.0 - mg_progress * rad * 0.35, 0)
				cut.scale = Vector3(rad * 0.9, maxf(0.02, mg_progress * rad * 0.7), 1)
				if npcs.has("heungbu"):
					var hb: Node3D = npcs["heungbu"]
					for ch in hb.get_children():
						if ch is Node3D and (ch as Node3D).has_meta("blink_at"):
							pose_person(ch, guide, 0.0)
			else:
				var pile: Node3D = w["pile"]
				var s2 := 0.2 + mg_progress * 0.9
				pile.scale = Vector3(s2, s2, s2)
				var ch2: MeshInstance3D = w["channel"]
				var dig: Vector3 = w["dig"]
				var pd: Vector3 = w["pd"]
				var len := 0.2 + mg_progress * 3.0
				ch2.position = dig + Vector3(-len / 2.0, 0.03, 0)
				ch2.scale = Vector3(len, 1, 1)
				if npcs.has("park"):
					var pk: Node3D = npcs["park"]
					for c2 in pk.get_children():
						if c2 is Node3D and (c2 as Node3D).has_meta("blink_at"):
							pose_person(c2, -guide, 0.0)
		"plant":
			var marks: Array = w["marks"]
			var row := mini(mg_count / 4, 2)
			for k in 4:
				(marks[k] as Node3D).global_position = plant_world_pos(row, k) + Vector3(0, 0.05, 0)
				(marks[k] as Node3D).scale = Vector3.ONE * (1.6 if k == mg_count % 4 and mg_count < 12 else 1.0)
			var rope: Node3D = w["rope"]
			rope.global_position = plant_world_pos(row, 1) .lerp(plant_world_pos(row, 2), 0.5) + Vector3(0, 0.05, 0)
			var planted: Array = w["planted"]
			while planted.size() < mg_items.size():
				var it: Array = mg_items[planted.size()]
				var p := plant_world_pos(it[0], it[1]) + Vector3(0, 0.1, float(it[2]) * 0.004)
				var sd := blob_node([[Vector3(0, 0.12, 0), Vector3(0.07, 0.3, 0.07), Color(0.45, 0.72, 0.3)], [Vector3(0.03, 0.14, 0), Vector3(0.04, 0.26, 0.04), Color(0.55, 0.8, 0.36), Vector3(0, 0, -20)]])
				sd.global_position = p
				pop3d(sd, true)
				splash3d(p)
				planted.append(sd)
			if mg_count < 12:
				var wsz := mg_overlay.size.x
				var sc := 1.0 - row * 0.12
				var u := (plant_cursor_x() - wsz * 0.5) / (wsz * 0.2 * sc) + 1.5
				var bundle: Node3D = w["bundle"]
				var a0 := plant_world_pos(row, 0)
				var a1 := plant_world_pos(row, 3)
				bundle.global_position = a0.lerp(a1, u / 3.0) + Vector3(0, 0.45, 0)
				var target := plant_slot(row, mg_count % 4)
				var near := absf(plant_cursor_x() - target.x) < wsz * 0.05
				bundle.scale = Vector3.ONE * (1.25 if near else 1.0)
				var ring: MeshInstance3D = w["ring"]
				ring.visible = true
				ring.global_position = plant_world_pos(row, mg_count % 4) + Vector3(0, 0.06, 0)
				var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.008) * 0.1
				ring.scale = Vector3.ONE * (1.35 if near else pulse)
				(ring.material_override as StandardMaterial3D).albedo_color = Color(1.0, 0.95, 0.4) if near else Color(1.0, 0.8, 0.1)
			elif w.has("ring"):
				(w["ring"] as Node3D).visible = false

# 눌러서 쫓는 미니게임(구렁이, 말뚝, 참새 ...): 화면의 버튼마다 3D 목표를 하나씩 붙여요
func is_tap_scene(scene: String) -> bool:
	return scene in ["snake", "kim", "sparrow"]

func tap_scene_update() -> void:
	var scene: String = w["scene"]
	var life: float = mg_cfg.get("life", 1.5)
	var seen: Dictionary = w["seen"]
	var alive := {}
	for it in mg_items:
		var b: Control = it[0]
		if not is_instance_valid(b):
			continue
		var key := b.get_instance_id()
		alive[key] = true
		if not seen.has(key):
			seen[key] = scene_make_target(scene_spawn_target())
		var tip := scene_target_update(seen[key], float(it[1]), life)
		pin_button(b, tip)
	for key in seen.keys():
		if not alive.has(key):
			var n: Node3D = seen[key]
			if is_instance_valid(n):
				if mg_count > int(w["count0"]):
					scene_target_hit(n)
				else:
					scene_target_miss(n)
			seen.erase(key)
	w["count0"] = mg_count

# 받는 미니게임(밥풀 ...): 떨어지는 것들을 3D로 보여 주고 주인공이 손가락을 따라가요
func is_catch_scene(scene: String) -> bool:
	return scene == "rice"

# 떨어지는 물건 모양 (장마다 바꿀 수 있어요)
func catch_item_node(bad: bool) -> Node3D:
	if bad:
		return blob_node([[Vector3.ZERO, Vector3(0.22, 0.34, 0.06), Color(0.85, 0.66, 0.4)], [Vector3(0, -0.3, 0), Vector3(0.07, 0.36, 0.05), Color(0.7, 0.5, 0.3)]])
	return blob_node([[Vector3.ZERO, Vector3(0.2, 0.17, 0.2), Color(1, 1, 0.97)], [Vector3(0.06, 0.06, 0.03), Vector3(0.1, 0.08, 0.1), Color(1, 1, 1)]])

func catch_scene_update() -> void:
	var h := mg_overlay.size.y
	var depth: float = w["depth"]
	var items: Dictionary = w["items"]
	var alive := {}
	for it in mg_items:
		var node: Control = it[0]
		if not is_instance_valid(node):
			continue
		var key := node.get_instance_id()
		alive[key] = true
		if not items.has(key):
			items[key] = catch_item_node(it[1])
		var sp := node.position + node.size / 2.0
		var n2: Node3D = items[key]
		n2.global_position = cam.project_position(sp, depth)
		n2.rotation.z += 0.08 if it[1] else 0.02
	for key in items.keys():
		if not alive.has(key):
			var n3: Node3D = items[key]
			if is_instance_valid(n3):
				var p3 := n3.global_position
				if absf(cam.unproject_position(p3).y - h * 0.78) < h * 0.08:
					burst3d(p3, Color(1, 1, 0.95) if mg_lives == int(w["lives0"]) else Color(1, 0.5, 0.4), 8)
					if mg_lives < int(w["lives0"]):
						cam_kick = 0.25
						hit_stop(0.05)
				n3.queue_free()
			items.erase(key)
	w["lives0"] = mg_lives
	var bowl: Node3D = w["bowl"]
	# 손가락 아래 땅으로 주인공이 옮겨 가고, 바가지는 머리 위에
	var feet_y := cam.unproject_position(player.position).y
	var ro := cam.project_ray_origin(Vector2(mg_pos.x, feet_y))
	var rd := cam.project_ray_normal(Vector2(mg_pos.x, feet_y))
	if absf(rd.y) > 0.01:
		var gy: float = w.get("ground_y", 0.0)
		var gpt := ro + rd * ((gy - ro.y) / rd.y)
		var lim: Vector3 = w["center"]
		gpt.x = clampf(gpt.x, lim.x - 2.4, lim.x + 2.4)
		player.position = player.position.lerp(Vector3(gpt.x, player.position.y, lim.z), 0.35)
	bowl.global_position = player.position + Vector3(0, 2.2, 0.15)
	mg_cfg["basket_px"] = cam.unproject_position(bowl.global_position).y
	mg_cfg["spawn_px"] = maxf(h * 0.12, float(mg_cfg["basket_px"]) - h * 0.38)

func scene_pose() -> bool:
	if not w.has("scene"):
		return false
	var sw: float = w.get("swing", 0.0)
	match w["scene"]:
		"heal", "straw":
			var mov := sin(mg_last_angle) * 0.15
			pose_custom(Vector3(-0.95 + mov, 0.35, -1.0), Vector3(-0.95 - mov, 0.35, -1.0), 0.35, 0.55)
		"ong":
			pose_custom(Vector3(-0.4, 0.45, -0.3), Vector3(-1.25 + sin(mg_last_angle) * 0.25, 0.35 + cos(mg_last_angle) * 0.2, -0.6), 0.18, 0.25)
		"saw":
			var g: float = w.get("guide", 0.0)
			var arm := Vector3(-1.15 - g * 0.35, 0.3, -0.7 + g * 0.3)
			pose_custom(arm, arm, 0.18 + g * 0.08, 0.2)
		"ditch":
			var g2: float = w.get("guide", 0.0)
			var arm2 := Vector3(-0.8 - g2 * 0.5, 0.25, -0.6)
			pose_custom(arm2, arm2, 0.3 + absf(g2) * 0.15, 0.3)
			var fwd := Vector3(sin(player.rotation.y), 0, cos(player.rotation.y))
			place_tool((fwd * 0.6 + Vector3(0, -0.8 + g2 * 0.4, 0)).normalized())
		"snake", "kim", "sparrow", "gam":
			var arm3 := Vector3(lerpf(-2.4, -0.9, sw), 0.25, lerpf(-0.6, -0.1, sw))
			pose_custom(Vector3(-0.3, 0.45, -0.3), arm3, lerpf(-0.05, 0.2, sw), 0.15)
			if tool_node != null:
				var sh := bone_world("armR")
				place_tool((bone_world("handR") - sh).normalized())
		"rice":
			pose_custom(Vector3(-2.7, 0.15, -0.5), Vector3(-2.7, 0.15, -0.5), -0.05, 0.1)
		"plant":
			pose_custom(Vector3(-0.9, 0.3, -0.5), Vector3(-1.3, 0.25, -0.4), 0.6, 0.45)
		_:
			return false
	return true

# ---------- 남쪽 들판: 연못 낚시터와 최 영감네 논 ----------

var FISH := [
	{"name": tr("피라미"), "pay": 3, "w": 30, "hard": 0.1, "col": Color(0.78, 0.84, 0.9), "len": 0.85, "thin": 0.34},
	{"name": tr("붕어"), "pay": 4, "w": 28, "hard": 0.25, "col": Color(0.72, 0.64, 0.42), "len": 1.0, "thin": 0.48},
	{"name": tr("미꾸라지"), "pay": 6, "w": 16, "hard": 0.5, "col": Color(0.58, 0.5, 0.32), "len": 1.5, "thin": 0.2},
	{"name": tr("잉어"), "pay": 8, "w": 14, "hard": 0.45, "col": Color(0.92, 0.58, 0.3), "len": 1.2, "thin": 0.44},
	{"name": tr("메기"), "pay": 12, "w": 9, "hard": 0.7, "col": Color(0.38, 0.38, 0.34), "len": 1.35, "thin": 0.36},
	{"name": tr("금빛 잉어"), "pay": 30, "w": 3, "hard": 0.9, "col": Color(1.0, 0.8, 0.22), "len": 1.2, "thin": 0.44},
]
var fish_caught := [0, 0, 0, 0, 0, 0]
var fish_kind := 0
var pond_deco: Array = []
var fisher_met := false
var fish_reward := false
const POND_C := Vector3(-22, 0, 31)
const FARM_C := Vector3(25, 0, 31)
const FARM_GROW := 45.0
var farm_state := -1      # -1 부탁 전, 0 빈 논, 1 자라는 중, 2 참새 떼, 3 다시 자라는 중, 4 다 익음
var farm_timer := 0.0
var farm_perfect := true
var harvests := 0
var farm_stages: Array = []   # [어린 모, 푸른 벼, 누런 벼]
var sparrows: Array = []      # [노드, 처음 위치]

func flat_ellipse(c: Vector3, rx: float, rz: float, y: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.0
	cm.bottom_radius = 1.0
	cm.height = 0.04
	cm.radial_segments = 40
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = mat
	mi.scale = Vector3(rx, 1, rz)
	mi.position = c + Vector3(0, y, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi

# ---------- 마을 꾸미기 (돌담, 감나무, 장독대, 텃밭, 꽃, 징검돌, 시냇가) ----------

# 둥근 덩어리 여러 개를 한 번에 그려요. items 한 칸: [위치, 크기(가로,높이,세로), 색]
var rock_meshes: Array = []

func load_rocks() -> void:
	if not ResourceLoader.exists("res://models/rocks.glb"):
		return
	var root: Node = (load("res://models/rocks.glb") as PackedScene).instantiate()
	var found := root.find_children("Rock*", "MeshInstance3D", true, false)
	found.sort_custom(func(x, y): return String(x.name) < String(y.name))
	for node in found:
		rock_meshes.append((node as MeshInstance3D).mesh)
	root.free()

# 돌은 블렌더로 만든 울퉁불퉁한 돌 모양 네 가지를 번갈아 써요
func add_rocks(parent: Node3D, items: Array, mat_in: Material) -> MultiMeshInstance3D:
	var first: MultiMeshInstance3D = null
	for k in rock_meshes.size():
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = rock_meshes[k]
		var mine := []
		for i in items.size():
			if i % rock_meshes.size() == k:
				mine.append(items[i])
		if mine.is_empty():
			continue
		mm.instance_count = mine.size()
		for i in mine.size():
			var sc: Vector3 = mine[i][1]
			var yaw := (PI if i % 2 == 1 else 0.0) + sin(i * 2.7 + k) * 0.25
			var basis := Basis(Vector3.UP, yaw) * Basis.from_scale(sc * 1.08)
			if mine[i].size() > 3:
				var rd: Vector3 = mine[i][3]
				basis = Basis.from_euler(Vector3(deg_to_rad(rd.x), deg_to_rad(rd.y), deg_to_rad(rd.z))) * basis
			mm.set_instance_transform(i, Transform3D(basis, mine[i][0]))
			mm.set_instance_color(i, mine[i][2])
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.material_override = mat_in
		parent.add_child(mi)
		if first == null:
			first = mi
	return first

func add_blobs(parent: Node3D, items: Array, mat_in: Material = null, flat: bool = false) -> MultiMeshInstance3D:
	if items.is_empty():
		return null
	if mat_in != null and mat_in == stone_blob_mat and not flat and rock_meshes.size() > 0:
		return add_rocks(parent, items, mat_in)
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
	# 블렌더로 만든 돌담 한 칸(2m)을 이어 붙여요. 흥부네 쪽은 짚, 놀부네 쪽은 기와를 얹어요
	var file := "wall_tile" if (a.x + b.x) / 2.0 > 0.0 else "wall_straw"
	if ResourceLoader.exists("res://models/%s.glb" % file):
		var n := maxi(1, int(round(length / 2.0)))
		var seg := length / n
		var roof_c := Color(0.28, 0.3, 0.36) if file == "wall_tile" else Color(0.8, 0.66, 0.3)
		for i in n:
			var holder := Node3D.new()
			holder.position = Vector3(-length / 2.0 + (i + 0.5) * seg, 0, 0)
			root.add_child(holder)
			make_choga_from_model(holder, Vector3(seg, 1, 1), Color(0.92, 0.9, 0.86), roof_c, file, Vector3(2.0, 1, 1))
		var mcol := CollisionShape3D.new()
		var mshape := BoxShape3D.new()
		mshape.size = Vector3(length + 0.1, 1.3, 0.66)
		mcol.shape = mshape
		mcol.position.y = 0.65
		root.add_child(mcol)
		return
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
	if place_prop(root, "prop_jar", pos, s * 0.97, c, randf() * TAU):
		var jcol := CollisionShape3D.new()
		var jshape := BoxShape3D.new()
		jshape.size = Vector3(0.9 * s, 1.1 * s, 0.9 * s)
		jcol.shape = jshape
		jcol.position = pos + Vector3(0, 0.55 * s, 0)
		root.add_child(jcol)
		return
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
	if not tree_tried:
		load_trees()
	var use_model := tree_meshes.has("Broad1")
	if use_model:
		# 블렌더 나무에 감을 주렁주렁
		trunk.visible = false
		var mi := MeshInstance3D.new()
		mi.mesh = tree_meshes["Broad1"]
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i)
			mi.set_surface_override_material(i, leaf_mat if (m != null and m.resource_name == "Leaf") else bark_mat)
		mi.scale = Vector3(1.15, 1.1, 1.15)
		root.add_child(mi)
		var aabb := mi.mesh.get_aabb()
		var ctr := (aabb.position + aabb.size * Vector3(0.5, 0.64, 0.5)) * mi.scale
		var rad := aabb.size.x * 0.5 * mi.scale.x * 0.6
		persimmon_ctr = pos + ctr
		persimmon_rad = rad
		for i in 22:
			var dir := Vector3(r.randf_range(-1, 1), r.randf_range(-0.55, 0.7), r.randf_range(-1, 1)).normalized()
			items.append([ctr + dir * rad * Vector3(1, 0.62, 1), Vector3(0.4, 0.36, 0.4), Color(0.95, 0.34 + 0.1 * r.randf(), 0.04)])
	for c in canopy:
		if use_model:
			break
		var k: float = r.randf()
		items.append([Vector3(c[0], c[1], c[2]), Vector3(c[3] * 2.0, c[3] * 1.7, c[3] * 2.0), Color(0.3 + 0.08 * k, 0.6 + 0.1 * k, 0.25)])
	for i in (0 if use_model else 18):
		var c: Array = canopy[r.randi() % canopy.size()]
		var dir := Vector3(r.randf_range(-1, 1), r.randf_range(-0.3, 1), r.randf_range(-1, 1)).normalized()
		var at := Vector3(c[0], c[1], c[2]) + dir * float(c[3]) * 0.95
		items.append([at, Vector3(0.44, 0.4, 0.44), Color(0.95, 0.34 + 0.1 * r.randf(), 0.04)])
	var canopy_mi := add_blobs(root, items)
	if use_model:
		persimmon_fruit_mi = canopy_mi
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
				# 무: 흙 위로 솟은 하얀 뿌리 + 연두 어깨 + 길쭉한 잎
				items.append([Vector3(x, 0.26, z), Vector3(0.24, 0.4, 0.24), Color(0.98, 0.97, 0.92)])
				items.append([Vector3(x, 0.44, z), Vector3(0.22, 0.12, 0.22), Color(0.72, 0.85, 0.5)])
				for k in 4:
					var a := k * TAU / 4.0 + r.randf() * 0.5
					items.append([Vector3(x + cos(a) * 0.1, 0.7, z + sin(a) * 0.1), Vector3(0.1, 0.5, 0.05), Color(0.28, 0.58, 0.24), Vector3(sin(a) * 25.0, -rad_to_deg(a), cos(a) * 25.0)])
			else:
				# 배추: 바깥 잎이 벌어지고 속은 노르스름하게 차 있어요
				var k: float = r.randf()
				for j in 6:
					var a := j * TAU / 6.0 + k
					items.append([Vector3(x + cos(a) * 0.17, 0.3, z + sin(a) * 0.17), Vector3(0.34, 0.42, 0.14), Color(0.3 + 0.06 * k, 0.6, 0.26), Vector3(sin(a) * 30.0, -rad_to_deg(a) + 90.0, cos(a) * 30.0)])
				items.append([Vector3(x, 0.36, z), Vector3(0.34, 0.46, 0.34), Color(0.82, 0.9, 0.55)])
				items.append([Vector3(x, 0.55, z), Vector3(0.22, 0.14, 0.22), Color(0.9, 0.94, 0.68)])
	add_blobs(root, items)

var flower_meshes := {}
var flower_mat: StandardMaterial3D = null

func make_flowers(pos: Vector3, r: RandomNumberGenerator) -> void:
	var petals := [Color(0.95, 0.4, 0.6), Color(0.98, 0.98, 0.95), Color(0.98, 0.78, 0.12), Color(0.72, 0.45, 0.92)]
	var k := r.randi() % petals.size()
	if not flower_meshes.has(k):
		flower_meshes[k] = flower_clump_mesh(petals[k], 30 + k)
	if flower_mat == null:
		flower_mat = StandardMaterial3D.new()
		flower_mat.vertex_color_use_as_albedo = true
		flower_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		flower_mat.roughness = 0.9
	var mi := MeshInstance3D.new()
	mi.mesh = flower_meshes[k]
	mi.material_override = flower_mat
	mi.position = pos
	mi.rotation.y = r.randf() * TAU
	mi.scale = Vector3.ONE * r.randf_range(0.85, 1.15)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	sway_items.append([mi, Vector3.ZERO, 1, pos.x * 1.1 + pos.z, 0.05])

# 길쭉한 잎 포기 사이로 가는 줄기가 올라와 다섯 잎 꽃이 핀 들꽃 한 무더기
func flower_clump_mesh(pc: Color, seed_v: int) -> ArrayMesh:
	var r := RandomNumberGenerator.new()
	r.seed = seed_v
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var up := Vector3.UP
	# 잎
	for i in 9:
		var ang := i * TAU / 9.0 + r.randf_range(-0.3, 0.3)
		var dir := Vector3(cos(ang), 0, sin(ang))
		var side := Vector3(-dir.z, 0, dir.x)
		var h := r.randf_range(0.18, 0.32)
		var lean := r.randf_range(0.5, 0.9)
		var w := r.randf_range(0.035, 0.05)
		var prev := []
		for s2 in 4:
			var t := s2 / 3.0
			var c := dir * lean * h * t * (0.6 + t * 0.4) + Vector3(0, h * t - h * 0.35 * t * t, 0) + dir * 0.03
			var hw := w * sin(minf(1.0, t + 0.15) * PI) + 0.004
			var col := Color(0.24, 0.42, 0.18).lerp(Color(0.5, 0.72, 0.3), t)
			var cur := [c - side * hw, c + side * hw, col]
			if s2 > 0:
				for v in [[prev[0], prev[2]], [prev[1], prev[2]], [cur[1], cur[2]], [prev[0], prev[2]], [cur[1], cur[2]], [cur[0], cur[2]]]:
					st.set_color(v[1]); st.set_normal(up); st.add_vertex(v[0])
			prev = cur
	# 줄기와 꽃
	for i in 6:
		var ang2 := r.randf() * TAU
		var d := r.randf_range(0.02, 0.2)
		var base := Vector3(cos(ang2) * d, 0, sin(ang2) * d)
		var top := base + Vector3(r.randf_range(-0.06, 0.06), r.randf_range(0.3, 0.46), r.randf_range(-0.06, 0.06))
		var sd := (top - base).cross(Vector3(1, 0, 0)).normalized() * 0.008
		var stem_c := Color(0.32, 0.52, 0.22)
		for v in [base - sd, base + sd, top + sd, base - sd, top + sd, top - sd]:
			st.set_color(stem_c); st.set_normal(up); st.add_vertex(v)
		var fr := r.randf_range(0.045, 0.06)
		var tilt := Basis(Vector3(r.randf_range(-1, 1), 0, r.randf_range(-1, 1)).normalized(), r.randf_range(0.2, 0.5))
		var col_p := pc.lightened(r.randf() * 0.15)
		for pidx in 5:
			var a0 := pidx * TAU / 5.0
			var tip := tilt * Vector3(cos(a0) * fr, 0.01, sin(a0) * fr)
			var l := tilt * Vector3(cos(a0 - 0.5) * fr * 0.55, 0.0, sin(a0 - 0.5) * fr * 0.55)
			var rr := tilt * Vector3(cos(a0 + 0.5) * fr * 0.55, 0.0, sin(a0 + 0.5) * fr * 0.55)
			for v in [[Vector3.ZERO, col_p.darkened(0.15)], [l, col_p], [tip, col_p.lightened(0.2)], [Vector3.ZERO, col_p.darkened(0.15)], [tip, col_p.lightened(0.2)], [rr, col_p]]:
				st.set_color(v[1]); st.set_normal(up); st.add_vertex(top + v[0])
		var cc := Color(1.0, 0.86, 0.3)
		for q in 3:
			var a1 := q * TAU / 3.0
			for v in [Vector3.ZERO, Vector3(cos(a1), 0.4, sin(a1)) * 0.016, Vector3(cos(a1 + TAU / 3.0), 0.4, sin(a1 + TAU / 3.0)) * 0.016]:
				st.set_color(cc); st.set_normal(up); st.add_vertex(top + tilt * v + Vector3(0, 0.012, 0))
	return st.commit()

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

func add_ridge_ring(r0: float, depth: float, hmin: float, hmax: float, low: Color, high: Color, seed_v: int, center: Vector3 = Vector3.ZERO, arc: Vector2 = Vector2(0.0, TAU)) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = seed_v
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.6
	noise.fractal_octaves = 2
	var n := 220
	var rows := 9
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var grid := []
	for i in n + 1:
		var ang := lerpf(arc.x, arc.y, float(i) / n)
		var nx := cos(ang) * 3.0
		var nz := sin(ang) * 3.0
		var hh := lerpf(hmin, hmax, clampf(noise.get_noise_2d(nx, nz) * 0.9 + 0.5, 0.0, 1.0))
		var col := []
		for j in rows:
			var t := float(j) / (rows - 1)
			# 앞쪽은 완만하게 올라가고, 능선을 넘어 뒤로 내려가요
			var prof := sin(t * PI)
			prof = pow(prof, 0.8)
			var rr := r0 + t * depth
			var y := -3.0 + prof * (hh + 3.0)
			col.append(center + Vector3(cos(ang) * rr, y, sin(ang) * rr))
		grid.append(col)
	for i in n:
		for j in rows - 1:
			var quad := [grid[i][j], grid[i + 1][j], grid[i + 1][j + 1], grid[i][j + 1]]
			for idx in [0, 2, 1, 0, 3, 2]:
				var v: Vector3 = quad[idx]
				var k := clampf((v.y + 3.0) / (hmax + 3.0), 0.0, 1.0)
				st.set_color(low.lerp(high, k))
				st.add_vertex(v)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


# ---------- 살아있는 느낌 (바람, 물결, 나비, 구름, 낙엽) ----------

# 끝이 뾰족한 감잎 모양 (떨어지는 낙엽용, 가운데 잎맥이 보여요)
func leaf_card_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 10
	var pts := []
	for i in n + 1:
		var t := float(i) / n
		var y := lerpf(-0.1, 0.11, t)
		var wd := sin(t * PI) * 0.065 * (1.0 - t * 0.25)
		pts.append([Vector3(-wd, y, 0), Vector3(wd, y, 0), Vector3(0, y, 0)])
	var edge := Color(1, 1, 1)
	var vein := Color(0.8, 0.72, 0.6)
	for i in n:
		var a: Array = pts[i]
		var b: Array = pts[i + 1]
		for tri in [[a[0], a[2], b[2]], [a[0], b[2], b[0]], [a[2], a[1], b[1]], [a[2], b[1], b[2]]]:
			for v in tri:
				st.set_color(vein if absf((v as Vector3).x) < 0.001 else edge)
				st.set_normal(Vector3(0, 0, 1))
				st.add_vertex(v)
	return st.commit()

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
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.angular_velocity_min = -90.0
	p.angular_velocity_max = 90.0
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.2
	var q := leaf_card_mesh()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	q.surface_set_material(0, mat)
	p.mesh = q
	p.color_ramp = null
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	grad.colors = PackedColorArray([Color(1.0, 0.75, 0.3), Color(0.98, 0.5, 0.18), Color(0.85, 0.35, 0.15)])
	p.color_initial_ramp = grad
	parent.add_child(p)

# 위아래 날개가 둥글게 이어진 나비 날개 (오른쪽 날개, 왼쪽은 뒤집어 써요)
func butterfly_wing_mesh(c: Color) -> ArrayMesh:
	var outline := [
		Vector2(0.0, 0.03), Vector2(0.05, 0.11), Vector2(0.12, 0.16), Vector2(0.19, 0.165), Vector2(0.235, 0.13),
		Vector2(0.24, 0.07), Vector2(0.2, 0.02), Vector2(0.15, -0.005),
		Vector2(0.18, -0.05), Vector2(0.175, -0.11), Vector2(0.13, -0.15), Vector2(0.07, -0.15), Vector2(0.025, -0.1), Vector2(0.0, -0.04),
	]
	var edge := c.darkened(0.45)
	var inner := c.lightened(0.25)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var centers := [Vector2(0.1, 0.07), Vector2(0.09, -0.07)]
	for k in outline.size():
		var a: Vector2 = outline[k]
		var b: Vector2 = outline[(k + 1) % outline.size()]
		var ctr: Vector2 = centers[0] if (a.y + b.y) * 0.5 >= 0.0 else centers[1]
		# 가운데는 밝고, 가장자리는 진한 테두리에 흰 점
		var spot := (k % 3 == 1)
		var ca := edge.lerp(Color(1, 1, 1), 0.6) if spot else edge
		for v in [[ctr, inner], [ctr.lerp(a, 0.72), c], [ctr.lerp(b, 0.72), c]]:
			st.set_color(v[1]); st.add_vertex(Vector3(v[0].x, 0, v[0].y))
		for v in [[ctr.lerp(a, 0.72), c], [a, ca], [b, edge]]:
			st.set_color(v[1]); st.add_vertex(Vector3(v[0].x, 0, v[0].y))
		for v in [[ctr.lerp(a, 0.72), c], [b, edge], [ctr.lerp(b, 0.72), c]]:
			st.set_color(v[1]); st.add_vertex(Vector3(v[0].x, 0, v[0].y))
	st.generate_normals()
	return st.commit()

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
	if player == null:
		return
	update_autosave(delta)
	update_cam_hint(delta)
	anim_t += delta
	update_audio()
	if in_card and card_scroll != null:
		card_scroll.queue_redraw()
	update_south(delta)
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
			foam_mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(fd[2], 0.04, 0.12)), Vector3(x, 0.07, creek_z(x) + fd[1])))
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
		var flap := 0.35 + sin(t * 16.0 + b[6]) * 0.85
		(b[1] as Node3D).rotation.z = -flap
		(b[2] as Node3D).rotation.z = flap
	# 구름이 천천히 흘러가요
	for cl in clouds:
		var node: Node3D = cl[0]
		node.position.x += delta * float(cl[1])
		if node.position.x > 130.0:
			node.position.x = -130.0

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

	# 할 일 글씨 뒤에 반투명한 바탕을 깔아 하늘 위에서도 잘 읽혀요
	quest_panel = PanelContainer.new()
	var qbox := StyleBoxFlat.new()
	qbox.bg_color = Color(0.16, 0.1, 0.05, 0.38)
	qbox.set_corner_radius_all(int(font_size * 0.45))
	qbox.content_margin_left = font_size * 0.45
	qbox.content_margin_right = font_size * 0.45
	qbox.content_margin_top = font_size * 0.2
	qbox.content_margin_bottom = font_size * 0.25
	quest_panel.add_theme_stylebox_override("panel", qbox)
	quest_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(quest_panel)
	place(quest_panel, 0.03, 0.148, 0.97, 0.148)
	quest_panel.grow_vertical = Control.GROW_DIRECTION_END
	quest_label = Label.new()
	style(quest_label, 0.8)
	quest_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	quest_label.add_theme_constant_override("outline_size", 5)
	quest_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quest_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	quest_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	quest_panel.add_child(quest_label)

	turn_button = add_hud_button(tr("돌리기"), 0.03, 0.25, on_turn)
	place(turn_button, 0.03, 0.075, 0.16, 0.135)
	turn_button.text = ""
	var icon := Control.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	turn_button.add_child(icon)
	place(icon, 0, 0, 1, 1)
	icon.draw.connect(func(): draw_turn_icon(icon))
	# 손가락 닿은 자리에 보이는 조이스틱
	stick_view = Control.new()
	stick_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(stick_view)
	stick_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	stick_view.draw.connect(draw_stick)
	action_button = add_hud_button("", 0.28, 0.72, on_action)
	jump_button = add_hud_button(tr("점프"), 0.75, 0.97, on_jump)
	action_button.visible = false

	dialog_panel = PanelContainer.new()
	var dbox := StyleBoxFlat.new()
	dbox.bg_color = Color(0.98, 0.94, 0.84)
	dbox.shadow_color = Color(0, 0, 0, 0.25)
	dbox.shadow_size = 10
	dbox.shadow_offset = Vector2(4, 6)
	dbox.content_margin_left = font_size * 0.95
	dbox.content_margin_right = font_size * 0.95
	dbox.content_margin_top = font_size * 0.85
	dbox.content_margin_bottom = font_size * 0.8
	dialog_panel.add_theme_stylebox_override("panel", dbox)
	dialog_panel.draw.connect(func(): draw_scroll_frame(dialog_panel))
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
	next_hint.text = tr("다음 >")
	style(next_hint, 0.8)
	next_hint.add_theme_color_override("font_color", Color(0.7, 0.3, 0.1))
	next_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vbox.add_child(next_hint)

# 대화창을 시작 화면처럼 두루마리로: 양옆 짙은 여백, 붉은 두 줄 테두리, 위아래 나무 막대
func draw_scroll_frame(ci: Control) -> void:
	var w := ci.size.x
	var h := ci.size.y
	var side := font_size * 0.35
	ci.draw_rect(Rect2(0, 0, side, h), Color(0.93, 0.87, 0.74))
	ci.draw_rect(Rect2(w - side, 0, side, h), Color(0.93, 0.87, 0.74))
	var inset := Rect2(Vector2(side + 6, font_size * 0.32), Vector2(w - side * 2.0 - 12, h - font_size * 0.64))
	ci.draw_rect(inset, Color(0.72, 0.22, 0.18, 0.85), false, 2.5)
	ci.draw_rect(inset.grow(-6), Color(0.72, 0.22, 0.18, 0.5), false, 1.2)
	var rod_h := font_size * 0.42
	for yy in [0.0, h]:
		var rod := Rect2(-font_size * 0.4, yy - rod_h * 0.5, w + font_size * 0.8, rod_h)
		ci.draw_rect(rod, Color(0.45, 0.26, 0.14))
		ci.draw_rect(Rect2(rod.position.x, rod.position.y + rod_h * 0.15, rod.size.x, rod_h * 0.25), Color(0.62, 0.4, 0.22))
		for ex in [rod.position.x, rod.end.x]:
			d_ell(ci, Vector2(ex, yy), rod_h * 0.45, rod_h * 0.65, Color(0.95, 0.75, 0.3), 0.0, 2.0)


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
	mg_back = back
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
	var cols := {tr("밥풀"): Color(0.98, 0.97, 0.93), tr("주걱"): Color(0.82, 0.62, 0.34), tr("물"): Color(0.55, 0.8, 0.98),
		tr("돌"): Color(0.62, 0.62, 0.66), tr("구렁이"): Color(0.5, 0.66, 0.3), tr("장작"): Color(0.72, 0.5, 0.28)}
	return cols.get(name, Color(0.9, 0.8, 0.6))

func make_game_ui() -> void:
	mg_overlay = make_overlay(0.6)
	mg_overlay.gui_input.connect(on_mg_input)
	make_mg_back()
	mg_world_ui = Control.new()
	mg_world_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mg_overlay.add_child(mg_world_ui)
	place(mg_world_ui, 0, 0, 1, 1)
	var wp1 := make_plaque()
	wp1.bg_color.a = 0.82
	add_deco(mg_world_ui, 0.03, 0.115, 0.97, 0.285, wp1)
	var wp2 := make_plaque()
	wp2.bg_color.a = 0.82
	add_deco(mg_world_ui, 0.03, 0.85, 0.97, 0.965, wp2)
	mg_world_ui.visible = false
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
	# 미리 만들어 둔 소리 파일이 있으면 그걸 써요 (tools/make_audio.py)
	for key in defs.keys() + ["step1", "step2", "step3", "step4", "scroll", "splash"]:
		var path := "res://sounds/%s.wav" % key
		if ResourceLoader.exists(path):
			sounds[key] = load(path)
	setup_audio()
	for i in 8:
		var sp := AudioStreamPlayer.new()
		add_child(sp)
		sound_players.append(sp)

# ---------- 배경음, 자연 소리, 소리 켜고 끄기 ----------
var music_on := true
var sfx_on := true
var bgm_player: AudioStreamPlayer
var amb_player: AudioStreamPlayer
var creek_player: AudioStreamPlayer3D

func setup_audio() -> void:
	# 웹에서는 실행 중에 만든 오디오 버스가 소리를 막아서, 모두 기본(Master) 버스로 내보내요
	var cf := ConfigFile.new()
	if cf.load("user://save.cfg") == OK:
		music_on = cf.get_value("ui", "music_on", true)
		sfx_on = cf.get_value("ui", "sfx_on", true)
	if ResourceLoader.exists("res://sounds/bgm.ogg"):
		bgm_player = AudioStreamPlayer.new()
		bgm_player.stream = load("res://sounds/bgm.ogg")
		bgm_player.volume_db = -11.0
		add_child(bgm_player)
		bgm_player.play()
	if ResourceLoader.exists("res://sounds/ambience.ogg"):
		amb_player = AudioStreamPlayer.new()
		amb_player.stream = load("res://sounds/ambience.ogg")
		amb_player.volume_db = -14.0
		add_child(amb_player)
		amb_player.play()
	if ResourceLoader.exists("res://sounds/creek.ogg"):
		# 개울에서 가장 가까운 곳을 따라다니며 졸졸 소리가 나요
		creek_player = AudioStreamPlayer3D.new()
		creek_player.stream = load("res://sounds/creek.ogg")
		creek_player.unit_size = 4.0
		creek_player.max_distance = 22.0
		creek_player.volume_db = -4.0
		add_child(creek_player)
		creek_player.play()
	apply_audio_toggles()

func apply_audio_toggles() -> void:
	if bgm_player != null:
		bgm_player.stream_paused = not music_on
	for ap in [amb_player, creek_player]:
		if ap != null:
			ap.stream_paused = not sfx_on

func update_audio() -> void:
	if creek_player != null and player != null:
		creek_player.position = Vector3(player.position.x, 0.3, creek_z(player.position.x))

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
	if not sfx_on:
		return
	if key == "step" and sounds.has("step1"):
		key = "step%d" % (rng.randi() % 4 + 1)
	if not sounds.has(key):
		return
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
	sfx("scroll" if sounds.has("scroll") else "drum")
	card_done = done
	card_label.text = text
	card_overlay.modulate.a = start_alpha
	card_overlay.visible = true
	set_scroll_open(0.0)
	var tw := create_tween()
	card_tween = tw
	if start_alpha < 1.0:
		tw.tween_property(card_overlay, "modulate:a", 1.0, 0.5)
	# 두루마리가 위아래로 스르륵 펼쳐져요
	tw.tween_method(set_scroll_open, 0.0, 1.0, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_interval(hold)
	tw.tween_method(set_scroll_open, 1.0, 0.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(card_overlay, "modulate:a", 0.0, 0.45)
	tw.tween_callback(end_card)

# ---------- 두루마리 글 카드 ----------
var scroll_open := 0.0
var card_scroll: Control

func set_scroll_open(v: float) -> void:
	scroll_open = v
	card_label.modulate.a = clampf((v - 0.6) / 0.4, 0.0, 1.0)
	if card_scroll != null:
		card_scroll.queue_redraw()

func make_card_scroll() -> void:
	card_overlay.color = Color(1, 1, 1, 1)
	card_scroll = Control.new()
	card_scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_overlay.add_child(card_scroll)
	card_overlay.move_child(card_scroll, 0)
	place(card_scroll, 0, 0, 1, 1)
	card_scroll.draw.connect(draw_card_scroll)
	card_label.add_theme_color_override("font_color", INK)
	card_label.add_theme_constant_override("outline_size", 0)

func draw_card_scroll() -> void:
	var ci: CanvasItem = card_scroll
	var w := card_scroll.size.x
	var h := card_scroll.size.y
	# 쪽빛 밤하늘 바탕 + 구름 무늬 + 반짝이는 별
	ci.draw_rect(Rect2(0, 0, w, h), Color(0.2, 0.22, 0.36))
	ci.draw_rect(Rect2(0, h * 0.55, w, h * 0.45), Color(0.24, 0.25, 0.4))
	var rr := RandomNumberGenerator.new()
	rr.seed = 12
	for i in 40:
		var p := Vector2(rr.randf() * w, rr.randf() * h)
		var tw2 := 0.5 + 0.5 * sin(anim_t * 2.0 + i)
		ci.draw_circle(p, 1.5 + rr.randf() * 2.0, Color(1, 0.95, 0.75, 0.25 + 0.5 * tw2))
	for c in [[0.15, 0.1, 1.0], [0.82, 0.13, 0.8], [0.12, 0.9, 0.9], [0.86, 0.88, 1.1]]:
		draw_cloud_motif(ci, Vector2(w * float(c[0]), h * float(c[1])), short_side * 0.07 * float(c[2]))
	# 펼쳐지는 종이
	var cx := w * 0.5
	var cy := h * 0.5
	var pw := w * 0.86
	var full_h := h * 0.6
	var ph := maxf(full_h * scroll_open, 6.0)
	var paper := Rect2(cx - pw / 2.0, cy - ph / 2.0, pw, ph)
	ci.draw_rect(Rect2(paper.position + Vector2(8, 10), paper.size), Color(0, 0, 0, 0.25))
	ci.draw_rect(paper, Color(0.98, 0.94, 0.84))
	ci.draw_rect(Rect2(paper.position.x, paper.position.y, 18, ph), Color(0.93, 0.87, 0.74))
	ci.draw_rect(Rect2(paper.end.x - 18, paper.position.y, 18, ph), Color(0.93, 0.87, 0.74))
	if scroll_open > 0.3:
		# 옛 책처럼 붉은 테두리 두 줄
		var a := clampf((scroll_open - 0.3) / 0.4, 0.0, 1.0)
		var inset := paper.grow(-28)
		ci.draw_rect(inset, Color(0.72, 0.22, 0.18, a), false, 4.0)
		ci.draw_rect(inset.grow(-9), Color(0.72, 0.22, 0.18, a * 0.7), false, 1.5)
		# 모서리 매화
		for corner in [inset.position + Vector2(26, 26), Vector2(inset.end.x - 26, inset.position.y + 26), Vector2(inset.position.x + 26, inset.end.y - 26), inset.end - Vector2(26, 26)]:
			draw_blossom(ci, corner, 13.0, a)
		# 오른쪽 아래 붉은 도장
		if scroll_open > 0.95:
			var sp := Vector2(inset.end.x - 100, inset.end.y - 104)
			ci.draw_rect(Rect2(sp, Vector2(52, 52)), Color(0.78, 0.18, 0.15, 0.9))
			ci.draw_rect(Rect2(sp + Vector2(4, 4), Vector2(44, 44)), Color(0.98, 0.9, 0.85, 0.9), false, 2.0)
			ci.draw_string(font, sp + Vector2(5, 24), tr("전래"), HORIZONTAL_ALIGNMENT_LEFT, -1, int(font_size * 0.55), Color(0.98, 0.92, 0.88))
			ci.draw_string(font, sp + Vector2(5, 46), tr("동화"), HORIZONTAL_ALIGNMENT_LEFT, -1, int(font_size * 0.55), Color(0.98, 0.92, 0.88))
	# 위아래 두루마리 막대 (끝에 금빛 장식)
	for yy in [paper.position.y, paper.end.y]:
		var rod := Rect2(cx - pw / 2.0 - 26, yy - 15, pw + 52, 30)
		ci.draw_rect(rod, Color(0.45, 0.26, 0.14))
		ci.draw_rect(Rect2(rod.position.x, rod.position.y + 4, rod.size.x, 7), Color(0.62, 0.4, 0.22))
		for ex in [rod.position.x, rod.end.x]:
			d_ell(ci, Vector2(ex, yy), 14, 20, Color(0.95, 0.75, 0.3), 0.0, 3.0)
	# 다 펼쳐지면 넘기기 안내가 깜빡여요
	if scroll_open > 0.98:
		var al := 0.45 + 0.35 * sin(anim_t * 3.0)
		ci.draw_string(font, Vector2(0, paper.end.y + 78), tr("화면을 누르면 넘어가요"), HORIZONTAL_ALIGNMENT_CENTER, w, int(font_size * 0.75), Color(1, 0.95, 0.82, al))

# 전통 구름 무늬 (동글동글 말린 구름)
func draw_cloud_motif(ci: CanvasItem, c: Vector2, s: float) -> void:
	var col := Color(0.95, 0.88, 0.7, 0.22)
	for k in 3:
		var p := c + Vector2((k - 1) * s * 0.9, absf(k - 1) * s * 0.15)
		ci.draw_arc(p, s * 0.55, PI, TAU * 1.1, 24, col, s * 0.12, true)
		ci.draw_arc(p + Vector2(s * 0.15, s * 0.05), s * 0.25, PI * 0.8, TAU * 0.95, 16, col, s * 0.1, true)
	ci.draw_line(c + Vector2(-s * 1.5, s * 0.1), c + Vector2(s * 1.6, s * 0.1), col, s * 0.12, true)

func draw_blossom(ci: CanvasItem, c: Vector2, s: float, a: float) -> void:
	for k in 5:
		var ang := TAU * k / 5.0 - PI / 2.0
		ci.draw_circle(c + Vector2(cos(ang), sin(ang)) * s * 0.75, s * 0.55, Color(0.98, 0.62, 0.7, a))
	ci.draw_circle(c, s * 0.35, Color(1.0, 0.85, 0.35, a))


var card_tween: Tween

# 글 카드는 화면을 누르면 넘어가요
func on_card_input(event: InputEvent) -> void:
	if (event is InputEventScreenTouch or event is InputEventMouseButton) and event.pressed:
		if in_card and card_tween != null and card_tween.is_valid() and card_overlay.modulate.a > 0.6:
			card_tween.kill()
			end_card()

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
	if current_lines[line_index][0] == tr("제비"):
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
		var ob := StyleBoxFlat.new()
		ob.bg_color = Color(1.0, 0.97, 0.9)
		ob.border_color = Color(0.72, 0.22, 0.18, 0.8)
		ob.set_border_width_all(2)
		ob.set_corner_radius_all(int(font_size * 0.25))
		ob.set_content_margin_all(font_size * 0.22)
		skin_button(b, ob, INK, 0.85)
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

func set_quest(q: int) -> void:
	quest = q
	update_quest_text()
	save_progress()

func earn(amount: int) -> void:
	coins += amount
	sfx("coin")
	float_text(tr("+%d냥") % amount, quest_label.global_position + Vector2(short_side * 0.25, quest_label.size.y * 0.75), Color(1, 0.85, 0.3), 1.2)
	update_quest_text()

# ---------- 말 걸기, 줍기 ----------

func is_busy() -> bool:
	return talking or mg_active or in_card or book_open or settings_open

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
		return tr("약초 캐기")
	if kind == "gourd":
		return tr("박 타기")
	if kind == "nest":
		return tr("둥지 지키기")
	if kind == "piece":
		return tr("살펴보기")
	if kind == "laundry":
		return tr("빨래 줍기")
	if kind == "hider":
		return tr("찾았다!")
	if kind == "bush":
		return tr("덤불 베기")
	if kind == "gate":
		return tr("이정표 보기")
	if kind == "wild":
		return tr("약초 캐기")
	if kind == "fish":
		return tr("낚시하기")
	if kind == "farm":
		return farm_action_text()
	if kind == "job":
		if t["id"] == "water":
			return tr("물 긷기")
		if t["id"] == "wood":
			return tr("나무하기")
		if t["id"] == "gam":
			return tr("감 따기")
		return tr("짚신 삼기")
	return tr("말 걸기")

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
		get_piece_id(int(t["id"]), "")
	elif kind == "laundry":
		node.visible = false
		sfx("pop")
		burst3d(above, Color(1, 1, 1))
		laundry_found += 1
		say([["", tr("빨래를 주웠다. (%d/3)") % laundry_found]], Callable())
	elif kind == "hider":
		node.visible = false
		sfx("good")
		burst3d(above, Color(0.98, 0.85, 0.65))
		hiders_found += 1
		say([[tr("동생"), tr("앗, 들켰다! 헤헤. (%d/4)") % hiders_found]], Callable())
	elif kind == "gate":
		on_gate()
	elif kind == "bush":
		if has_sickle:
			node.visible = false
			sfx("saw")
			shake(8)
			burst3d(above, Color(0.3, 0.5, 0.2), 24)
			bush_col.set_deferred("disabled", true)
			say([["", tr("낫으로 가시덤불을 베어 냈다. 안쪽에서 울음소리가 들린다...")]], Callable())
		else:
			say([["", tr("가시덤불이 길을 막고 있다. 낫이 있으면 벨 수 있겠다. (장터에서 팔아요)")]], Callable())
	elif kind == "job":
		start_job(t["id"])
	elif kind == "wild":
		pick_wild(t)
	elif kind == "fish":
		start_fishing()
	elif kind == "farm":
		farm_action()

# ---------- 놀부네 ----------

# ---------- 흥부네 ----------

# ---------- 1장 엔딩 ----------

# ---------- 마을 사람 돕기 ----------

# ---------- 품팔이와 장터 ----------

# ---------- 숨은 이야기: 금도끼 은도끼 ----------

const AXE_GOAL := 3

# ---------- 감나무: 장대로 감 따기 (꼭대기 까치밥은 남겨요) ----------

const GAM_GOAL := 8
var persimmon_ctr := Vector3(3, 3.7, 2.5)
var persimmon_rad := 2.0
var persimmon_fruit_mi: Node3D = null

# ---------- 주변 세상에서 하는 미니게임 (공통) ----------

func world_hide(n: Node) -> void:
	if n != null and is_instance_valid(n) and (n as Node3D).visible:
		(n as Node3D).visible = false
		world_hidden.append(n)

func world_game_begin(stand: Vector3, face: Vector3, cam_pos: Vector3, cam_at: Vector3, spot: Node3D = null) -> void:
	mg_world = true
	if spot != null:
		for lb in spot.find_children("*", "Label3D", true, false):
			world_hide(lb)
	player.position = stand
	player.velocity = Vector3.ZERO
	player.rotation.y = atan2(face.x - stand.x, face.z - stand.z)
	player_body.rotation = Vector3.ZERO
	world_cam = Transform3D(Basis(), cam_pos).looking_at(cam_at, Vector3.UP)
	hud_hidden = []
	for c in [action_button, jump_button, turn_button, book_button, settings_button, quest_panel]:
		if c != null and c.visible:
			hud_hidden.append(c)
			c.visible = false

func world_game_end() -> void:
	mg_world = false
	for n in world_hidden:
		if is_instance_valid(n):
			(n as Node3D).visible = true
	world_hidden = []
	for n in mg_nodes:
		if is_instance_valid(n):
			n.queue_free()
	mg_nodes = []
	for c in hud_hidden:
		if is_instance_valid(c):
			c.visible = true
	hud_hidden = []
	drop_tool()
	world_restore()
	update_quest_text()

func world_node(n: Node3D) -> Node3D:
	if n.get_parent() == null:
		add_child(n)
	mg_nodes.append(n)
	return n

func hold_tool(kind: String) -> void:
	drop_tool()
	tool_kind = kind
	tool_node = MeshInstance3D.new()
	var root := Node3D.new()
	if kind == "shovel":
		add_mcyl(root, wood_mat, 0.03, 0.035, 1.2, Vector3(0, 0.6, 0))
		add_mbox(root, make_color(Color(0.5, 0.52, 0.56)), Vector3(0.24, 0.3, 0.03), Vector3(0, 1.3, 0))
	elif kind == "stick":
		add_mcyl(root, make_color(Color(0.6, 0.45, 0.25)), 0.025, 0.035, 1.1, Vector3(0, 0.55, 0))
		add_blobs(root, [[Vector3(0, 1.12, 0), Vector3(0.22, 0.3, 0.22), Color(0.85, 0.72, 0.45)]], thatch_blob_mat)
	elif kind == "pole":
		# 끝이 갈라진 대나무 장대
		add_mcyl(root, make_color(Color(0.72, 0.68, 0.38)), 0.022, 0.03, 2.6, Vector3(0, 1.3, 0))
		for k in 4:
			add_mcyl(root, make_color(Color(0.5, 0.48, 0.26)), 0.034, 0.034, 0.03, Vector3(0, 0.4 + k * 0.6, 0))
		var fa := add_mcyl(root, make_color(Color(0.72, 0.68, 0.38)), 0.012, 0.016, 0.25, Vector3(0.05, 2.68, 0))
		fa.rotation.z = -0.35
		var fb := add_mcyl(root, make_color(Color(0.72, 0.68, 0.38)), 0.012, 0.016, 0.25, Vector3(-0.05, 2.68, 0))
		fb.rotation.z = 0.35
	elif kind == "mallet":
		# 떡메: 긴 자루 끝에 굵은 나무 방망이
		add_mcyl(root, wood_mat, 0.035, 0.04, 1.05, Vector3(0, 0.52, 0))
		var head := add_mcyl(root, make_color(Color(0.62, 0.45, 0.28)), 0.15, 0.15, 0.5, Vector3(0, 1.08, 0))
		head.rotation.x = PI / 2.0
	elif kind == "axe":
		var handle := add_mcyl(root, wood_mat, 0.035, 0.04, 0.95, Vector3(0, 0.47, 0))
		handle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_mbox(root, make_color(Color(0.5, 0.52, 0.56)), Vector3(0.07, 0.2, 0.3), Vector3(0, 0.9, 0.1))
		add_mbox(root, make_color(Color(0.85, 0.86, 0.88)), Vector3(0.075, 0.18, 0.04), Vector3(0, 0.9, 0.26))
	else:
		add_mcyl(root, make_color(Color(0.55, 0.42, 0.22)), 0.012, 0.03, 2.3, Vector3(0, 1.15, 0))
		add_mcyl(root, make_color(Color(0.3, 0.2, 0.12)), 0.04, 0.04, 0.3, Vector3(0, 0.1, 0))
	tool_node.add_child(root)
	add_child(tool_node)

func drop_tool() -> void:
	if tool_node != null and is_instance_valid(tool_node):
		tool_node.queue_free()
	tool_node = null
	tool_kind = ""

func bone_world(bn: String) -> Vector3:
	if not player_body.has_meta("skel"):
		return player.position + Vector3(0, 1.0, 0)
	var skel: Skeleton3D = player_body.get_meta("skel")
	var bones: Dictionary = player_body.get_meta("bones")
	if not bones.has(bn):
		return player.position + Vector3(0, 1.0, 0)
	var i: int = (bones[bn] as Array)[0]
	return skel.global_transform * skel.get_bone_global_pose(i).origin

# 도구는 손에 붙이고, 정해 준 방향(dir)으로 뻗게 해요
func place_tool(dir: Vector3) -> void:
	if tool_node == null:
		return
	var hand := bone_world("handR").lerp(bone_world("handL"), 0.5 if tool_kind in ["axe", "mallet"] else 0.0)
	var y := dir.normalized()
	var x := y.cross(Vector3.UP if absf(y.y) < 0.95 else Vector3.FORWARD).normalized()
	var z := x.cross(y).normalized()
	tool_node.global_transform = Transform3D(Basis(x, y, z), hand - y * 0.12)

func tool_tip(length: float) -> Vector3:
	if tool_node == null:
		return player.position
	return tool_node.global_transform * Vector3(0, length, 0)

# 여러 자세를 직접 잡아요 (팔: 앞으로 드는 정도·벌림·팔꿈치, 몸 숙임)
func pose_custom(arm_l: Vector3, arm_r: Vector3, lean: float, crouch: float) -> void:
	if not player_body.has_meta("skel"):
		pose_person(player_body, 0.0, 0.0)
		return
	var skel: Skeleton3D = player_body.get_meta("skel")
	var bones: Dictionary = player_body.get_meta("bones")
	for side in ["L", "R"]:
		var sx := -1.0 if side == "L" else 1.0
		var arm: Vector3 = arm_l if side == "L" else arm_r
		var twist: Vector3 = (bones["arm" + side] as Array)[3] if bones.has("arm" + side) else Vector3.UP
		var adj: float = player_body.get_meta("arm_adj", 0.0)
		turn_bone(skel, bones, "arm" + side, [[Vector3.RIGHT, arm.x], [Vector3.BACK, -sx * (arm.y - adj)], [twist, sx * 0.9]])
		turn_bone(skel, bones, "fore" + side, [[Vector3.RIGHT, arm.z]])
		turn_bone(skel, bones, "thigh" + side, [[Vector3.RIGHT, -0.14 - crouch * 0.5]])
		turn_bone(skel, bones, "shin" + side, [[Vector3.RIGHT, 0.26 + crouch]])
		turn_bone(skel, bones, "foot" + side, [[Vector3.RIGHT, -0.12 - crouch * 0.45]])
	turn_bone(skel, bones, "hips", [])
	turn_bone(skel, bones, "spine", [[Vector3.RIGHT, lean]])
	turn_bone(skel, bones, "head", [[Vector3.RIGHT, -lean * 0.4]])
	player_body.position.y = 1.0 - crouch * 0.12

# ---------- 손맛 미니게임: 리듬 · 스와이프 · 번갈아 오르기 · 연타 ----------
# 화면 위 그림(cg_draw)과 판정은 여기서, 3D 세상 쪽 연출은 장마다 cg_event()로 해요.
const CUSTOM_GAMES := ["rhythm", "swipe", "alternate", "mash", "stack", "aim", "simon", "dance", "dig"]
var cg := {}
var cg_draw: Control
var mg_lives_start := 3

# 장마다 바꿔 쓰는 연출 (kind: perfect, good, miss, bad, block, hit, feint, climb, slip, pull, fall, round, ...)
func cg_event(_kind: String, _info: Dictionary = {}) -> void:
	pass

func custom_begin() -> void:
	cg = {"t": -1.4, "combo": 0, "best": 0, "press": null, "msg": "", "msg_t": 0.0}
	g3 = {}
	mg_lives = int(mg_cfg.get("lives", 5 if mg_type == "rhythm" else 3))
	cg_draw = Control.new()
	cg_draw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mg_stage.add_child(cg_draw)
	place(cg_draw, 0, 0, 1, 1)
	cg_draw.draw.connect(custom_draw)
	match mg_type:
		"rhythm":
			cg["notes"] = []
			cg["next"] = 0.4
			cg["beat"] = 60.0 / float(mg_cfg.get("bpm", 96))
			cg["made"] = 0
		"swipe":
			cg["atk"] = {}
			cg["next"] = 1.0
		"alternate":
			cg["side"] = 0 if rng.randf() < 0.5 else 1
			cg["step_t"] = 0.0
			cg["shake"] = ""
			cg["shake_t"] = 0.0
			cg["shake_in"] = float(mg_cfg.get("shake_every", 5.0))
			cg["held"] = 0.0
		"mash":
			cg["tilt"] = 0.0
			cg["drift"] = 0.0
			cg["gauge"] = 0.0
			cg["round_t"] = 0.0
			cg["pulse"] = 0.0
		"stack":
			var bw := float(mg_cfg.get("base_w", 0.5))
			cg["layers"] = [[0.5, bw]]
			cg["cur"] = [0.1 + bw / 2.0, bw, 1.0]
			cg["falls"] = []
			cg["scroll"] = 0.0
		"aim":
			cg["climb"] = 0.0
			cg["shot"] = {}
			cg["drag"] = null
			cg["hit_flash"] = 0.0
		"simon":
			cg["seq"] = []
			for k in int(mg_cfg.get("start_len", 3)):
				(cg["seq"] as Array).append(rng.randi() % 5)
			cg["phase"] = "wait"
			cg["show_i"] = 0
			cg["show_t"] = -0.4
			cg["input_i"] = 0
			cg["lit"] = -1
			cg["lit_t"] = 0.0
		"dig":
			cg["tgt"] = {}
			cg["gap"] = 0.3
			cg["last"] = -1
			cg["razor_press"] = null
		"dance":
			cg["seq"] = []
			for k in int(mg_cfg.get("start_len", 3)):
				(cg["seq"] as Array).append(SW_DIRS4[rng.randi() % 4])
			cg["phase"] = "wait"
			cg["show_i"] = 0
			cg["show_t"] = -0.4
			cg["input_i"] = 0
			cg["flash_dir"] = ""
			cg["flash_t"] = 0.0
	cg_say(tr("준비!"), Color(1, 0.95, 0.7))

func cg_say(text: String, col: Color) -> void:
	cg["msg"] = text
	cg["msg_c"] = col
	cg["msg_t"] = 0.0

func cg_judge(text: String, col: Color, big: bool) -> void:
	var at := Vector2(mg_overlay.size.x * 0.5, mg_overlay.size.y * 0.42)
	float_text(text, at, col, 1.7 if big else 1.2)

func cg_combo_up() -> void:
	cg["combo"] = int(cg["combo"]) + 1
	cg["best"] = maxi(int(cg["best"]), int(cg["combo"]))
	if int(cg["combo"]) >= 3:
		float_text(tr("%d 콤보!") % cg["combo"], Vector2(mg_overlay.size.x * 0.5, mg_overlay.size.y * 0.5), Color(1, 0.8, 0.35), 1.0)

func cg_combo_break() -> void:
	cg["combo"] = 0

func cg_lose(text: String) -> void:
	mg_lives -= 1
	mg_perfect = false
	cg_combo_break()
	sfx("bad")
	shake(14)
	cg_judge(text, Color(1, 0.5, 0.42), true)

func cg_progress() -> void:
	mg_progress = clampf(float(mg_count) / float(mg_cfg.get("goal", 10)), 0.0, 1.0)
	mg_info.text = tr("%s %d/%d | 남은 기회 %d") % [mg_cfg.get("unit", ""), mg_count, int(mg_cfg.get("goal", 10)), mg_lives]

func custom_input(event: InputEvent) -> void:
	var is_button: bool = event is InputEventScreenTouch or event is InputEventMouseButton
	var is_move: bool = event is InputEventScreenDrag or (event is InputEventMouseMotion and event.button_mask != 0)
	# 터치에서 따라 만들어진 가짜 마우스 신호는 버려요 (두 번 눌리지 않게)
	if (event is InputEventMouseButton or event is InputEventMouseMotion) and event.device == -1:
		return
	if is_button and event.pressed:
		mg_touch = true
		mg_pos = event.position
		cg["press"] = event.position
		cg["swiped"] = false
		custom_press(event.position)
	elif is_button:
		mg_touch = false
		custom_release(event.position)
		cg["press"] = null
	elif is_move:
		mg_pos = event.position
		custom_drag(event.position)

func update_custom(delta: float) -> void:
	cg["t"] = float(cg["t"]) + delta
	cg["msg_t"] = float(cg["msg_t"]) + delta
	if float(cg["t"]) >= 0.0 and cg.get("go_said", false) == false:
		cg["go_said"] = true
		cg_say(tr("시작!"), Color(1, 0.9, 0.4))
		sfx("drum")
	match mg_type:
		"rhythm":
			update_rhythm(delta)
		"swipe":
			update_swipe(delta)
			update_paw3d()
		"alternate":
			update_alternate(delta)
		"mash":
			update_mash(delta)
		"stack":
			update_stack(delta)
		"aim":
			update_aim(delta)
		"simon":
			update_simon(delta)
		"dance":
			update_dance(delta)
		"dig":
			update_dig(delta)
	update_g3(delta)
	cg_progress()
	if is_instance_valid(cg_draw):
		cg_draw.queue_redraw()

func custom_press(pos: Vector2) -> void:
	if float(cg["t"]) < 0.0:
		return
	match mg_type:
		"rhythm":
			rhythm_press()
		"alternate":
			alternate_press(pos)
		"mash":
			mash_press(pos)
		"stack":
			stack_press()
		"aim":
			cg["drag"] = pos
		"simon":
			simon_press(pos)
		"dig":
			dig_press(pos)

func custom_release(pos: Vector2) -> void:
	if mg_type == "swipe":
		swipe_check(pos, true)
	elif mg_type == "aim":
		aim_release(pos)
	elif mg_type == "dance":
		dance_check(pos)
	elif mg_type == "dig":
		dig_release(pos)

func custom_drag(pos: Vector2) -> void:
	if mg_type == "swipe":
		swipe_check(pos, false)
	elif mg_type == "aim" and cg.get("drag") != null:
		cg["drag"] = pos
	elif mg_type == "dance":
		dance_check(pos)
	elif mg_type == "dig":
		dig_drag(pos)

# --- 리듬: 오른쪽에서 다가오는 박자가 동그라미에 겹칠 때 누르기. 빨간 손 박자는 누르면 안 돼요 ---
const R_PERFECT := 0.075
const R_GOOD := 0.17
const R_TRAVEL := 1.6

func update_rhythm(_delta: float) -> void:
	var t: float = cg["t"]
	var beat: float = cg["beat"]
	var goal := int(mg_cfg.get("goal", 14))
	# 박자 미리 만들기 (화면 오른쪽 끝에서 나타나요)
	while float(cg["next"]) < t + R_TRAVEL + 0.2 and int(cg["made"]) < goal * 3:
		var bad: bool = rng.randf() < float(mg_cfg.get("bad_ratio", 0.18)) and int(cg["made"]) > 2
		(cg["notes"] as Array).append({"t": float(cg["next"]), "bad": bad, "done": false})
		cg["made"] = int(cg["made"]) + 1
		var gaps := [1.0, 1.0, 1.0, 0.5, 0.5, 1.5, 2.0]
		cg["next"] = float(cg["next"]) + beat * float(gaps[rng.randi() % gaps.size()])
	for n in cg["notes"]:
		if n["done"]:
			continue
		if t - float(n["t"]) > R_GOOD:
			n["done"] = true
			if not n["bad"]:
				cg_lose(tr("놓쳤어요!"))
				cg_event("miss")
			else:
				cg_event("dodge")

func rhythm_press() -> void:
	var t: float = cg["t"]
	var best: Dictionary = {}
	var bd := 9.0
	for n in cg["notes"]:
		if n["done"]:
			continue
		var d := absf(t - float(n["t"]))
		if d < bd:
			bd = d
			best = n
	if best.is_empty() or bd > R_GOOD + 0.05:
		cg_combo_break()
		cg_judge(tr("헛손질!"), Color(0.85, 0.85, 0.9), false)
		cg_event("whiff")
		return
	best["done"] = true
	if best["bad"]:
		cg_lose(String(mg_cfg.get("bad_text", tr("앗, 손!"))))
		hit_stop(0.08)
		cg_event("bad")
		return
	mg_count += 1
	cg_combo_up()
	if bd <= R_PERFECT:
		cg_judge(tr("퍼펙트!"), Color(1, 0.88, 0.3), true)
		sfx("good", 1.1)
		hit_stop(0.05)
		shake(10)
		cg_event("perfect")
	else:
		cg_judge(tr("좋아!"), Color(0.7, 0.95, 1.0), false)
		mg_perfect = false
		shake(5)
		cg_event("good")

# --- 스와이프: 화면 가장자리에서 공격이 오면, 그쪽으로 손가락을 휙! 가짜 공격엔 속지 마세요 ---
const SW_DIRS := ["left", "right", "up"]

func update_swipe(delta: float) -> void:
	if float(cg["t"]) < 0.0:
		return
	var a: Dictionary = cg["atk"]
	if a.is_empty():
		cg["next"] = float(cg["next"]) - delta
		if float(cg["next"]) <= 0.0:
			var fake: bool = rng.randf() < float(mg_cfg.get("feint_ratio", 0.22)) and mg_count > 1
			cg["atk"] = {"dir": SW_DIRS[rng.randi() % 3], "phase": "tele", "time": 0.0, "fake": fake}
			sfx("tick", 0.8)
		return
	a["time"] = float(a["time"]) + delta
	var tele := float(mg_cfg.get("tele", 0.85)) * maxf(0.6, 1.0 - mg_count * 0.025)
	match a["phase"]:
		"tele":
			if float(a["time"]) >= tele:
				a["time"] = 0.0
				if a["fake"]:
					a["phase"] = "back"
					cg_event("feint", a)
				else:
					a["phase"] = "strike"
					sfx("crack", 1.3)
		"strike":
			if float(a["time"]) >= float(mg_cfg.get("window", 0.5)):
				cg_lose(String(mg_cfg.get("hit_text", tr("앗, 당했다!"))))
				cg_event("hit", a)
				cg["atk"] = {}
				cg["next"] = float(mg_cfg.get("gap", 0.9))
		"back":
			if float(a["time"]) >= 0.45:
				cg["atk"] = {}
				cg["next"] = 0.4

func swipe_check(pos: Vector2, released: bool) -> void:
	if cg.get("press") == null or cg.get("swiped", false) or float(cg["t"]) < 0.0:
		return
	var from: Vector2 = cg["press"]
	var d := pos - from
	if d.length() < short_side * 0.09:
		return
	cg["swiped"] = true
	var dir := "up"
	if absf(d.x) > absf(d.y):
		dir = "right" if d.x > 0.0 else "left"
	elif d.y > 0.0:
		dir = "down"
	var a: Dictionary = cg["atk"]
	if a.is_empty():
		cg_judge(tr("휙~"), Color(0.85, 0.85, 0.9), false)
		cg_combo_break()
		return
	if a["phase"] == "back" or (a["phase"] == "tele" and a["fake"]):
		cg_lose(tr("속았지롱!"))
		cg_event("fooled", a)
		cg["atk"] = {}
		cg["next"] = 0.7
		return
	if a["phase"] == "tele":
		cg_judge(tr("너무 빨라요!"), Color(1, 0.75, 0.5), false)
		cg_combo_break()
		return
	if dir != a["dir"]:
		cg_lose(tr("반대쪽이에요!"))
		cg_event("hit", a)
		cg["atk"] = {}
		cg["next"] = 0.8
		return
	mg_count += 1
	cg_combo_up()
	var quick: bool = float(a["time"]) < float(mg_cfg.get("window", 0.5)) * 0.45
	cg_judge(tr("퍽! 막았다!") if quick else tr("막았다!"), Color(1, 0.88, 0.3) if quick else Color(0.7, 0.95, 1.0), quick)
	sfx("crack", 1.0)
	hit_stop(0.07)
	shake(12 if quick else 7)
	cg_event("block", a)
	cg["atk"] = {}
	cg["next"] = float(mg_cfg.get("gap", 0.9)) * rng.randf_range(0.6, 1.2)

# --- 번갈아 오르기: 가지가 있는 쪽(왼쪽/오른쪽)을 눌러 한 칸씩. 흔들릴 땐 꾹 누르고 버티기 ---
func update_alternate(delta: float) -> void:
	if float(cg["t"]) < 0.0:
		return
	if cg["shake"] == "":
		cg["step_t"] = float(cg["step_t"]) + delta
		cg["shake_in"] = float(cg["shake_in"]) - delta
		if float(cg["step_t"]) > float(mg_cfg.get("step_time", 1.6)):
			cg["step_t"] = 0.0
			cg_lose(tr("미끄러져요!"))
			cg_event("slip")
		if float(cg["shake_in"]) <= 0.0:
			cg["shake"] = "warn"
			cg["shake_t"] = 0.0
			cg_say(tr("흔들린다! 꾹 누르고 버텨요!"), Color(1, 0.6, 0.45))
			sfx("crack", 0.7)
			cg_event("warn")
	else:
		cg["shake_t"] = float(cg["shake_t"]) + delta
		if cg["shake"] == "warn" and float(cg["shake_t"]) > 0.9:
			cg["shake"] = "shake"
			cg["shake_t"] = 0.0
			cg["held"] = 0.0
			shake(18)
			cg_event("shake")
		elif cg["shake"] == "shake":
			shake(4)
			if mg_touch:
				cg["held"] = float(cg["held"]) + delta
			if not mg_touch and float(cg["shake_t"]) > 0.15:
				cg_lose(tr("손을 놓쳤어요!"))
				cg_event("slip")
				cg["shake"] = ""
				cg["shake_in"] = float(mg_cfg.get("shake_every", 5.0)) * rng.randf_range(0.8, 1.2)
				cg["step_t"] = 0.0
			elif float(cg["shake_t"]) > 1.2:
				cg["shake"] = ""
				cg["shake_in"] = float(mg_cfg.get("shake_every", 5.0)) * rng.randf_range(0.8, 1.2)
				cg["step_t"] = 0.0
				cg_judge(tr("버텼다!"), Color(1, 0.88, 0.3), true)
				sfx("good")
				cg_event("held")

func alternate_press(pos: Vector2) -> void:
	if cg["shake"] != "":
		return
	var side := 0 if pos.x < mg_overlay.size.x * 0.5 else 1
	if side != int(cg["side"]):
		cg_combo_break()
		cg_judge(tr("헛디딤!"), Color(1, 0.75, 0.5), false)
		sfx("tick", 0.6)
		cg["step_t"] = float(cg["step_t"]) + 0.35
		return
	mg_count += 1
	var quick: bool = float(cg["step_t"]) < 0.45
	if quick:
		cg_combo_up()
	cg_judge(tr("영차!") if not quick else tr("영차영차!"), Color(1, 0.88, 0.3) if quick else Color(0.8, 0.95, 1.0), quick)
	sfx("tick", 1.0 + mg_count * 0.03)
	shake(4)
	cg["step_t"] = 0.0
	cg["side"] = (1 - side) if rng.randf() < 0.7 else side
	cg_event("climb")

# --- 연타: 빠르게 눌러 당기기. balance 이면 기운 반대쪽을 눌러 균형, rounds 이면 제한 시간 안에 게이지 채우기 ---
func update_mash(delta: float) -> void:
	if float(cg["t"]) < 0.0:
		return
	cg["pulse"] = maxf(0.0, float(cg["pulse"]) - delta * 4.0)
	if mg_cfg.get("balance", false):
		if rng.randf() < delta * 1.2:
			cg["drift"] = rng.randf_range(-1.0, 1.0) * float(mg_cfg.get("sway", 0.9))
		cg["tilt"] = float(cg["tilt"]) + (float(cg["drift"]) + float(cg["tilt"]) * 0.8) * delta
		if absf(float(cg["tilt"])) >= 1.0:
			cg["tilt"] = 0.0
			mg_count = maxi(0, mg_count - 2)
			cg_lose(tr("휘청!"))
			cg_event("fall")
	else:
		cg["round_t"] = float(cg["round_t"]) + delta
		cg["gauge"] = maxf(0.0, float(cg["gauge"]) - delta * float(mg_cfg.get("decay", 0.22)))
		if float(cg["round_t"]) > float(mg_cfg.get("round_time", 2.6)):
			cg_lose(String(mg_cfg.get("lose_text", tr("쏙 숨었어요!"))))
			cg_event("escape")
			cg["round_t"] = 0.0
			cg["gauge"] = 0.0

func mash_press(pos: Vector2) -> void:
	cg["pulse"] = 1.0
	if mg_cfg.get("balance", false):
		var left: bool = pos.x < mg_overlay.size.x * 0.5
		cg["tilt"] = float(cg["tilt"]) + (-0.16 if left else 0.16)
		if absf(float(cg["tilt"])) < 0.6:
			cg["pull"] = int(cg.get("pull", 0)) + 1
			if int(cg["pull"]) % int(mg_cfg.get("per", 3)) == 0:
				mg_count += 1
				cg_combo_up()
				sfx("tick", 1.0 + mg_count * 0.02)
				cg_event("pull")
		else:
			cg_judge(tr("균형부터!"), Color(1, 0.75, 0.5), false)
	else:
		cg["gauge"] = float(cg["gauge"]) + 1.0 / float(mg_cfg.get("taps", 9))
		sfx("tap", 0.9 + float(cg["gauge"]) * 0.4)
		cg_event("tap")
		if float(cg["gauge"]) >= 1.0:
			mg_count += 1
			var quick: bool = float(cg["round_t"]) < float(mg_cfg.get("round_time", 2.6)) * 0.55
			if quick:
				cg_combo_up()
			cg_judge(tr("쑥!") if not quick else tr("쑥! 빠르다!"), Color(1, 0.88, 0.3), quick)
			sfx("good")
			hit_stop(0.05)
			shake(9)
			cg_event("round")
			cg["gauge"] = 0.0
			cg["round_t"] = 0.0

# --- 떡 쌓기: 좌우로 움직이는 떡판을 톡! 어긋난 만큼 잘려 나가요 ---
func update_stack(delta: float) -> void:
	if float(cg["t"]) < 0.0:
		return
	var cur: Array = cg["cur"]
	var sp := float(mg_cfg.get("speed", 0.45)) * (1.0 + mg_count * 0.06)
	cur[0] = float(cur[0]) + float(cur[2]) * sp * delta
	var half := float(cur[1]) / 2.0
	if float(cur[0]) + half > 0.97:
		cur[2] = -1.0
	if float(cur[0]) - half < 0.03:
		cur[2] = 1.0
	for f in cg["falls"]:
		f[3] = float(f[3]) + delta * 2.2
		f[2] = float(f[2]) + float(f[3]) * delta
	cg["scroll"] = lerpf(float(cg["scroll"]), maxf(0.0, (cg["layers"] as Array).size() - 6.0), minf(1.0, delta * 5.0))

func stack_press() -> void:
	var layers: Array = cg["layers"]
	var top: Array = layers[layers.size() - 1]
	var cur: Array = cg["cur"]
	var l0 := maxf(float(top[0]) - float(top[1]) / 2.0, float(cur[0]) - float(cur[1]) / 2.0)
	var r0 := minf(float(top[0]) + float(top[1]) / 2.0, float(cur[0]) + float(cur[1]) / 2.0)
	var over := r0 - l0
	var lvl := layers.size()
	if over <= 0.02:
		cg_lose(tr("툭, 떨어졌어요!"))
		(cg["falls"] as Array).append([float(cur[0]), float(cur[1]), 0.0, 0.0, lvl])
		cg["cur"] = [0.1 + float(top[1]) / 2.0, float(top[1]), 1.0]
		cg_event("fall")
		return
	var perfect := absf(float(cur[0]) - float(top[0])) < 0.018
	var nx := (l0 + r0) / 2.0
	var nw := over
	if perfect:
		nx = float(top[0])
		nw = minf(float(top[1]) + 0.01, float(mg_cfg.get("base_w", 0.5)))
		cg_combo_up()
		cg_judge(tr("퍼펙트!"), Color(1, 0.88, 0.3), true)
		sfx("good", 1.0 + lvl * 0.03)
		hit_stop(0.04)
		shake(7)
		cg_event("perfect")
	else:
		# 잘려 나간 조각
		var cut_l := float(cur[0]) - float(cur[1]) / 2.0
		var cut_r := float(cur[0]) + float(cur[1]) / 2.0
		if cut_l < l0:
			(cg["falls"] as Array).append([(cut_l + l0) / 2.0, l0 - cut_l, 0.0, 0.0, lvl])
		if cut_r > r0:
			(cg["falls"] as Array).append([(r0 + cut_r) / 2.0, cut_r - r0, 0.0, 0.0, lvl])
		cg_combo_break()
		cg_judge(tr("탁!"), Color(0.8, 0.95, 1.0), false)
		sfx("land", 1.2)
		shake(4)
		cg_event("drop")
	layers.append([nx, nw])
	mg_count += 1
	var from_left := mg_count % 2 == 0
	cg["cur"] = [(0.03 + nw / 2.0) if from_left else (0.97 - nw / 2.0), nw, 1.0 if from_left else -1.0]
	if nw < 0.05:
		cg_lose(tr("너무 좁아졌어요!"))
		cg["cur"] = [0.1 + 0.2, 0.4, 1.0]
		layers.append([0.5, 0.4])

# --- 조준해 던지기: 아래쪽에서 손가락을 뒤로 끌었다 놓으면 휙! 목표(장마다 정해요)를 맞혀요 ---
func aim_target() -> Vector2:
	var W := mg_overlay.size.x
	var H := mg_overlay.size.y
	return Vector2(W * (0.5 + sin(float(cg["t"]) * 1.1) * 0.3), H * lerpf(0.62, 0.22, float(cg["climb"])))

func aim_anchor() -> Vector2:
	return Vector2(mg_overlay.size.x * 0.5, mg_overlay.size.y * 0.8)

func update_aim(delta: float) -> void:
	if float(cg["t"]) < 0.0:
		return
	cg["hit_flash"] = maxf(0.0, float(cg["hit_flash"]) - delta * 3.0)
	cg["climb"] = float(cg["climb"]) + delta * float(mg_cfg.get("climb_speed", 0.045))
	if float(cg["climb"]) >= 1.0:
		mg_lives = 0
		cg_judge(String(mg_cfg.get("lose_text", tr("다 올라와 버렸어요!"))), Color(1, 0.5, 0.42), true)
		cg_event("top")
		return
	var sh: Dictionary = cg["shot"]
	if sh.is_empty():
		return
	sh["v"] = (sh["v"] as Vector2) + Vector2(0, mg_overlay.size.y * 1.4) * delta
	sh["p"] = (sh["p"] as Vector2) + (sh["v"] as Vector2) * delta
	sh["spin"] = float(sh["spin"]) + delta * 12.0
	var tgt := aim_target()
	var rad := short_side * float(mg_cfg.get("target_r", 0.09))
	if (sh["p"] as Vector2).distance_to(tgt) < rad:
		mg_count += 1
		cg["climb"] = maxf(0.0, float(cg["climb"]) - float(mg_cfg.get("knock", 0.14)))
		cg["hit_flash"] = 1.0
		cg_combo_up()
		cg_judge(String(mg_cfg.get("hit_text", tr("딱! 맞았다!"))), Color(1, 0.88, 0.3), true)
		sfx("crack", 1.1)
		hit_stop(0.07)
		shake(12)
		cg_event("hit")
		cg["shot"] = {}
	elif (sh["p"] as Vector2).y > mg_overlay.size.y + 40.0 or (sh["p"] as Vector2).y < -200.0 or (sh["p"] as Vector2).x < -60.0 or (sh["p"] as Vector2).x > mg_overlay.size.x + 60.0:
		cg_combo_break()
		cg_judge(tr("빗나갔어요"), Color(0.85, 0.85, 0.9), false)
		cg_event("miss")
		cg["shot"] = {}

func aim_release(pos: Vector2) -> void:
	if cg.get("drag") == null or float(cg["t"]) < 0.0:
		cg["drag"] = null
		return
	var pull := aim_anchor() - (cg["drag"] as Vector2)
	cg["drag"] = null
	if pull.length() < short_side * 0.05 or not (cg["shot"] as Dictionary).is_empty():
		return
	cg["shot"] = {"p": aim_anchor(), "v": pull * 5.2, "spin": 0.0}
	sfx("jump", 1.3)
	cg_event("throw")

# --- 소리 기억: 조개가 울리는 순서를 기억했다가 똑같이 눌러요 ---
func simon_pads() -> Array:
	if mg_world and w.has("simon_pts"):
		var o := []
		for p in w["simon_pts"]:
			o.append(cam.unproject_position(p))
		return o
	var W := mg_overlay.size.x
	var H := mg_overlay.size.y
	var out := []
	for k in 5:
		var a := PI + PI * (k + 0.5) / 5.0
		out.append(Vector2(W * 0.5, H * 0.86) + Vector2(cos(a), sin(a)) * W * 0.36)
	return out

const SIMON_COLS := [Color(1.0, 0.55, 0.55), Color(1.0, 0.8, 0.4), Color(0.6, 0.9, 0.6), Color(0.55, 0.75, 1.0), Color(0.8, 0.6, 1.0)]

func simon_light(k: int) -> void:
	cg["lit"] = k
	cg["lit_t"] = 0.0
	sfx("tick", 0.75 + k * 0.14)
	cg_event("pad", {"k": k})

func update_simon(delta: float) -> void:
	cg["lit_t"] = float(cg["lit_t"]) + delta
	if float(cg["t"]) < 0.0:
		return
	var seq: Array = cg["seq"]
	match cg["phase"]:
		"wait":
			cg["show_t"] = float(cg["show_t"]) + delta
			if float(cg["show_t"]) > 0.5:
				cg["phase"] = "show"
				cg["show_i"] = 0
				cg["show_t"] = 0.0
				cg_say(tr("잘 들어 봐요..."), Color(1, 0.95, 0.7))
		"show":
			cg["show_t"] = float(cg["show_t"]) + delta
			var step := maxf(0.38, 0.62 - mg_count * 0.04)
			if float(cg["show_t"]) >= step:
				cg["show_t"] = 0.0
				if int(cg["show_i"]) < seq.size():
					simon_light(int(seq[int(cg["show_i"])]))
					cg["show_i"] = int(cg["show_i"]) + 1
				else:
					cg["phase"] = "input"
					cg["input_i"] = 0
					cg_say(tr("이제 따라 눌러요!"), Color(1, 0.9, 0.4))

func simon_press(pos: Vector2) -> void:
	if cg["phase"] != "input":
		return
	var pads := simon_pads()
	var best := -1
	for k in 5:
		if pos.distance_to(pads[k]) < short_side * 0.11:
			best = k
	if best < 0:
		return
	simon_light(best)
	var seq: Array = cg["seq"]
	if best != int(seq[int(cg["input_i"])]):
		cg_lose(tr("앗, 틀렸어요!"))
		cg_event("wrong")
		cg["phase"] = "wait"
		cg["show_t"] = -0.3
		return
	cg["input_i"] = int(cg["input_i"]) + 1
	if int(cg["input_i"]) >= seq.size():
		mg_count += 1
		cg_combo_up()
		cg_judge(tr("딩동댕!"), Color(1, 0.88, 0.3), true)
		sfx("good")
		shake(6)
		cg_event("round")
		seq.append(rng.randi() % 5)
		cg["phase"] = "wait"
		cg["show_t"] = -0.4

# --- 춤 따라 하기: 보여 준 화살표 순서대로 휙휙! ---
const SW_DIRS4 := ["left", "right", "up", "down"]
const ARROW_VEC := {"left": Vector2(-1, 0), "right": Vector2(1, 0), "up": Vector2(0, -1), "down": Vector2(0, 1)}

func update_dance(delta: float) -> void:
	cg["flash_t"] = float(cg["flash_t"]) + delta
	if float(cg["t"]) < 0.0:
		return
	var seq: Array = cg["seq"]
	match cg["phase"]:
		"wait":
			cg["show_t"] = float(cg["show_t"]) + delta
			if float(cg["show_t"]) > 0.5:
				cg["phase"] = "show"
				cg["show_i"] = 0
				cg["show_t"] = 0.0
				cg_say(tr("잘 봐요!"), Color(1, 0.95, 0.7))
		"show":
			cg["show_t"] = float(cg["show_t"]) + delta
			var step := maxf(0.42, 0.7 - mg_count * 0.05)
			if float(cg["show_t"]) >= step:
				cg["show_t"] = 0.0
				if int(cg["show_i"]) < seq.size():
					cg["flash_dir"] = seq[int(cg["show_i"])]
					cg["flash_t"] = 0.0
					sfx("drum", 1.1)
					cg_event("show", {"dir": seq[int(cg["show_i"])]})
					cg["show_i"] = int(cg["show_i"]) + 1
				else:
					cg["phase"] = "input"
					cg["input_i"] = 0
					cg["flash_dir"] = ""
					cg_say(tr("이제 따라 휙휙!"), Color(1, 0.9, 0.4))

func dance_check(pos: Vector2) -> void:
	if cg["phase"] != "input" or cg.get("press") == null or cg.get("swiped", false):
		return
	var d := pos - (cg["press"] as Vector2)
	if d.length() < short_side * 0.08:
		return
	cg["swiped"] = true
	var dir := ""
	if absf(d.x) > absf(d.y):
		dir = "right" if d.x > 0.0 else "left"
	else:
		dir = "down" if d.y > 0.0 else "up"
	cg["flash_dir"] = dir
	cg["flash_t"] = 0.0
	var seq: Array = cg["seq"]
	if dir != String(seq[int(cg["input_i"])]):
		cg_lose(tr("스텝이 꼬였어요!"))
		cg_event("wrong")
		cg["phase"] = "wait"
		cg["show_t"] = -0.3
		return
	sfx("drum", 0.9)
	cg_event("step", {"dir": dir})
	cg["input_i"] = int(cg["input_i"]) + 1
	if int(cg["input_i"]) >= seq.size():
		mg_count += 1
		cg_combo_up()
		cg_judge(tr("얼쑤!"), Color(1, 0.88, 0.3), true)
		sfx("good")
		hit_stop(0.05)
		shake(8)
		cg_event("round")
		seq.append(SW_DIRS4[rng.randi() % 4])
		cg["phase"] = "wait"
		cg["show_t"] = -0.5

func draw_arrow(ci: Control, c: Vector2, dir: String, size: float, col: Color) -> void:
	var v: Vector2 = ARROW_VEC[dir]
	var tip := c + v * size
	var tail := c - v * size
	ci.draw_line(tail, tip, col, size * 0.32)
	ci.draw_colored_polygon(PackedVector2Array([tip + v * size * 0.35, tip + v.rotated(PI / 2.0) * size * 0.55, tip - v.rotated(PI / 2.0) * size * 0.55]), col)

# --- 화면 그림 ---
func custom_draw() -> void:
	var ci := cg_draw
	var W := mg_overlay.size.x
	var H := mg_overlay.size.y
	var ink := Color(0.2, 0.13, 0.08)
	var paper := Color(1.0, 0.97, 0.88)
	# 알림 글씨
	if float(cg.get("msg_t", 9.0)) < 1.2 and cg.get("msg", "") != "":
		var a := clampf(1.2 - float(cg["msg_t"]), 0.0, 1.0)
		var col: Color = cg.get("msg_c", paper)
		col.a = a
		ci.draw_string(font, Vector2(0, H * 0.33), cg["msg"], HORIZONTAL_ALIGNMENT_CENTER, W, int(font_size * 1.5), col)
	match mg_type:
		"dig":
			dig_draw(ci, W, H, paper)
		"rhythm":
			var y := H * 0.74
			var hx := W * 0.24
			var span := W * 0.7
			ci.draw_rect(Rect2(W * 0.06, y - font_size * 0.9, W * 0.88, font_size * 1.8), Color(0, 0, 0, 0.28))
			var t: float = cg["t"]
			var beat_pulse := 1.0 + 0.08 * maxf(0.0, cos(fposmod(t, float(cg["beat"])) / float(cg["beat"]) * TAU))
			ci.draw_circle(Vector2(hx, y), font_size * 1.15 * beat_pulse, Color(1, 0.86, 0.3, 0.35))
			ci.draw_arc(Vector2(hx, y), font_size * 1.15 * beat_pulse, 0, TAU, 40, Color(1, 0.86, 0.3), 5.0)
			for n in cg["notes"]:
				if n["done"]:
					continue
				var k := (float(n["t"]) - t) / R_TRAVEL
				if k > 1.05:
					continue
				var x := hx + k * span
				var r := font_size * 0.8
				if n["bad"]:
					ci.draw_circle(Vector2(x, y), r, Color(0.9, 0.25, 0.22))
					ci.draw_line(Vector2(x - r * 0.45, y - r * 0.45), Vector2(x + r * 0.45, y + r * 0.45), paper, 6.0)
					ci.draw_line(Vector2(x + r * 0.45, y - r * 0.45), Vector2(x - r * 0.45, y + r * 0.45), paper, 6.0)
				else:
					ci.draw_circle(Vector2(x, y), r, paper)
					ci.draw_arc(Vector2(x, y), r, 0, TAU, 32, ink, 4.0)
					ci.draw_string(font, Vector2(x - r, y + font_size * 0.32), String(mg_cfg.get("note", tr("쿵"))), HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, int(font_size * 0.8), ink)
			ci.draw_string(font, Vector2(0, y + font_size * 2.2), tr("동그라미에 겹칠 때 톡! 빨간 X는 누르지 마세요"), HORIZONTAL_ALIGNMENT_CENTER, W, int(font_size * 0.8), paper)
		"swipe":
			var a: Dictionary = cg["atk"]
			if not a.is_empty():
				var geo := swipe_geom(a, W, H, true)
				var p: Vector2 = geo[0]
				var r: float = geo[1]
				var c: Vector2 = geo[2]
				var col := Color(0.96, 0.56, 0.18)
				if mg_cfg.get("scene", "") == "paws":
					if not (paw3d != null and is_instance_valid(paw3d)):
						draw_cat_paw(ci, p, c, r, a["phase"] == "strike")
				else:
					ci.draw_circle(p, r, col)
					for k in 3:
						var ang := -0.6 + k * 0.6
						var off := (c - p).normalized().rotated(ang) * r * 0.75
						ci.draw_circle(p + off, r * 0.22, Color(1, 0.96, 0.9))
					ci.draw_circle(p + (c - p).normalized() * r * 0.05, r * 0.38, Color(1, 0.96, 0.9))
				if a["phase"] == "strike":
					ci.draw_arc(p, r * 1.12, 0, TAU, 40, Color(1, 0.3, 0.25), 6.0)
					var dirv := (p - c).normalized()
					var s := c + dirv * W * 0.08
					var e := c + dirv * W * 0.26
					ci.draw_line(s, e, paper, 10.0)
					ci.draw_line(e, e - dirv.rotated(0.5) * font_size, paper, 10.0)
					ci.draw_line(e, e - dirv.rotated(-0.5) * font_size, paper, 10.0)
			ci.draw_string(font, Vector2(0, H * 0.86), tr("공격이 오는 쪽으로 손가락을 휙! (가짜엔 속지 마요)"), HORIZONTAL_ALIGNMENT_CENTER, W, int(font_size * 0.8), paper)
		"alternate":
			var side := int(cg["side"])
			for k in 2:
				var rect := Rect2(W * (0.04 + k * 0.5), H * 0.7, W * 0.42, H * 0.16)
				var on: bool = k == side and cg["shake"] == ""
				ci.draw_rect(rect, Color(1, 0.86, 0.3, 0.75) if on else Color(0, 0, 0, 0.25))
				ci.draw_string(font, rect.position + Vector2(0, rect.size.y * 0.62), tr("< 왼쪽") if k == 0 else tr("오른쪽 >"), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, int(font_size * 1.1), ink if on else paper)
			if cg["shake"] == "":
				var lim := float(mg_cfg.get("step_time", 1.6))
				var left := 1.0 - float(cg["step_t"]) / lim
				ci.draw_rect(Rect2(W * 0.1, H * 0.67, W * 0.8 * left, font_size * 0.3), Color(1, 0.86, 0.3) if left > 0.35 else Color(1, 0.4, 0.3))
			else:
				var hold := 1.0
				if cg["shake"] == "shake":
					hold = 1.0 - float(cg["shake_t"]) / 1.2
				ci.draw_string(font, Vector2(0, H * 0.62), tr("꾹 누르고 버텨요!"), HORIZONTAL_ALIGNMENT_CENTER, W, int(font_size * 1.4), Color(1, 0.55, 0.45))
				ci.draw_arc(Vector2(W * 0.5, H * 0.78), font_size * 2.0, -PI / 2.0, -PI / 2.0 + TAU * hold, 40, Color(1, 0.86, 0.3), 10.0)
		"mash":
			var pulse: float = cg["pulse"]
			if mg_cfg.get("balance", false):
				var tilt: float = cg["tilt"]
				var c2 := Vector2(W * 0.5, H * 0.74)
				var len := H * 0.14
				var tip := c2 + Vector2(sin(tilt * 0.9), -cos(tilt * 0.9)) * len
				ci.draw_arc(c2, len, -PI / 2.0 - 0.9, -PI / 2.0 + 0.9, 30, Color(0, 0, 0, 0.35), 18.0)
				ci.draw_arc(c2, len, -PI / 2.0 - 0.54, -PI / 2.0 + 0.54, 30, Color(0.5, 0.9, 0.5, 0.6), 18.0)
				ci.draw_line(c2, tip, Color(0.86, 0.74, 0.5), 12.0)
				ci.draw_circle(tip, font_size * (0.5 + pulse * 0.15), paper)
				var warn: bool = absf(tilt) > 0.55
				var hint := tr("< 왼쪽을 눌러요") if tilt > 0.0 else tr("오른쪽을 눌러요 >")
				ci.draw_string(font, Vector2(0, H * 0.84), hint if warn else tr("빠르게 연타! 기울면 반대쪽을 눌러요"), HORIZONTAL_ALIGNMENT_CENTER, W, int(font_size * (1.0 if warn else 0.8)), Color(1, 0.6, 0.45) if warn else paper)
			else:
				var g: float = cg["gauge"]
				var c3 := Vector2(W * 0.5, H * 0.74)
				var rr := font_size * (2.2 + pulse * 0.25)
				ci.draw_circle(c3, rr, Color(0, 0, 0, 0.3))
				ci.draw_arc(c3, rr, -PI / 2.0, -PI / 2.0 + TAU * g, 48, Color(1, 0.86, 0.3), 14.0)
				var tl := 1.0 - float(cg["round_t"]) / float(mg_cfg.get("round_time", 2.6))
				ci.draw_arc(c3, rr + 14.0, -PI / 2.0, -PI / 2.0 + TAU * maxf(0.0, tl), 48, Color(1, 0.45, 0.35) if tl < 0.35 else Color(0.7, 0.95, 1.0), 5.0)
				ci.draw_string(font, c3 + Vector2(-rr, font_size * 0.35), tr("연타!"), HORIZONTAL_ALIGNMENT_CENTER, rr * 2.0, int(font_size * 1.1), paper)
		"stack":
			if g3_on("stack_base"):
				return
			var lh := H * 0.04
			var by := H * 0.84
			var scroll: float = cg["scroll"]
			var cols := [Color(0.98, 0.97, 0.92), Color(0.55, 0.72, 0.4), Color(1.0, 0.75, 0.8), Color(0.98, 0.85, 0.45)]
			var layers: Array = cg["layers"]
			for k in layers.size():
				var y := by - (k - scroll) * lh
				if y > H or y < H * 0.25:
					continue
				var L: Array = layers[k]
				var rect := Rect2(W * (float(L[0]) - float(L[1]) / 2.0), y - lh, W * float(L[1]), lh - 2.0)
				ci.draw_rect(rect, cols[k % 4])
				ci.draw_rect(Rect2(rect.position, Vector2(rect.size.x, 4.0)), (cols[k % 4] as Color).lightened(0.25))
			var cur: Array = cg["cur"]
			var cy := by - (layers.size() - scroll) * lh
			var crect := Rect2(W * (float(cur[0]) - float(cur[1]) / 2.0), cy - lh, W * float(cur[1]), lh - 2.0)
			ci.draw_rect(crect, cols[layers.size() % 4])
			ci.draw_rect(crect, ink, false, 3.0)
			for f in cg["falls"]:
				var fy := by - (int(f[4]) - scroll) * lh + float(f[2]) * H
				if fy < H + 40.0:
					ci.draw_rect(Rect2(W * (float(f[0]) - float(f[1]) / 2.0), fy - lh, W * float(f[1]), lh - 2.0), Color(0.9, 0.88, 0.8, 0.8))
			ci.draw_string(font, Vector2(0, H * 0.36), tr("움직이는 떡판이 아래 떡과 딱 겹칠 때 톡!"), HORIZONTAL_ALIGNMENT_CENTER, W, int(font_size * 0.8), paper)
		"aim":
			if g3_on("aim3d"):
				var climb3: float = cg["climb"]
				ci.draw_rect(Rect2(W * 0.92, H * 0.25, font_size * 0.5, H * 0.45), Color(0, 0, 0, 0.3))
				ci.draw_rect(Rect2(W * 0.92, H * 0.25 + H * 0.45 * (1.0 - climb3), font_size * 0.5, H * 0.45 * climb3), Color(1, 0.45, 0.3) if climb3 > 0.7 else Color(1, 0.8, 0.4))
				return
			var tgt := aim_target()
			var rad := short_side * float(mg_cfg.get("target_r", 0.09))
			var hf: float = cg["hit_flash"]
			ci.draw_arc(tgt, rad * (1.0 + hf * 0.3), 0, TAU, 40, Color(1, 0.4 + hf * 0.5, 0.3), 5.0)
			ci.draw_arc(tgt, rad * 0.5, 0, TAU, 30, Color(1, 0.5, 0.35, 0.6), 3.0)
			# 올라오는 정도
			var climb: float = cg["climb"]
			ci.draw_rect(Rect2(W * 0.92, H * 0.25, font_size * 0.5, H * 0.45), Color(0, 0, 0, 0.3))
			ci.draw_rect(Rect2(W * 0.92, H * 0.25 + H * 0.45 * (1.0 - climb), font_size * 0.5, H * 0.45 * climb), Color(1, 0.45, 0.3) if climb > 0.7 else Color(1, 0.8, 0.4))
			var an := aim_anchor()
			ci.draw_line(an + Vector2(-font_size * 1.2, -font_size * 1.6), an, Color(0.45, 0.3, 0.18), 10.0)
			ci.draw_line(an + Vector2(font_size * 1.2, -font_size * 1.6), an, Color(0.45, 0.3, 0.18), 10.0)
			ci.draw_line(an, an + Vector2(0, font_size * 1.4), Color(0.45, 0.3, 0.18), 12.0)
			if cg.get("drag") != null:
				var dp: Vector2 = cg["drag"]
				ci.draw_line(an + Vector2(-font_size * 1.2, -font_size * 1.6), dp, Color(0.95, 0.85, 0.6), 4.0)
				ci.draw_line(an + Vector2(font_size * 1.2, -font_size * 1.6), dp, Color(0.95, 0.85, 0.6), 4.0)
				ci.draw_circle(dp, font_size * 0.45, Color(0.55, 0.38, 0.2))
				# 날아갈 길 미리 보기
				var pp := an
				var vv := (an - dp) * 5.2
				for k in 14:
					vv += Vector2(0, H * 1.4) * 0.05
					pp += vv * 0.05
					ci.draw_circle(pp, 4.0, Color(1, 1, 1, 0.7 - k * 0.045))
			var sh: Dictionary = cg["shot"]
			if not sh.is_empty():
				var sp: Vector2 = sh["p"]
				ci.draw_set_transform(sp, float(sh["spin"]), Vector2.ONE)
				ci.draw_circle(Vector2.ZERO, font_size * 0.42, Color(0.55, 0.38, 0.2))
				for k in 3:
					ci.draw_line(Vector2(-font_size * 0.35, -font_size * 0.2 + k * font_size * 0.2), Vector2(font_size * 0.35, -font_size * 0.2 + k * font_size * 0.2), Color(0.35, 0.22, 0.12), 3.0)
				ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			ci.draw_string(font, Vector2(0, H * 0.36), tr("아래에서 손가락을 뒤로 끌었다 놓아 던져요"), HORIZONTAL_ALIGNMENT_CENTER, W, int(font_size * 0.8), paper)
		"simon":
			var pads := simon_pads()
			var lit := int(cg["lit"])
			var lt: float = cg["lit_t"]
			for k in (0 if g3_on("simon_pts") else 5):
				var on := k == lit and lt < 0.3
				var col: Color = SIMON_COLS[k]
				var r := short_side * 0.095 * (1.15 if on else 1.0)
				ci.draw_circle(pads[k], r, col.lightened(0.45) if on else col.darkened(0.15))
				for f in 5:
					var fa := -PI * 0.85 + f * PI * 0.17
					ci.draw_line(pads[k], (pads[k] as Vector2) + Vector2(cos(fa), sin(fa)) * r * 0.9, col.darkened(0.35), 3.0)
				if on:
					ci.draw_arc(pads[k], r * 1.25, 0, TAU, 36, Color(1, 1, 0.85), 5.0)
			var msg2 := tr("따라 누르는 중 %d/%d") % [int(cg["input_i"]), (cg["seq"] as Array).size()] if cg["phase"] == "input" else tr("조개 소리를 잘 들어요")
			ci.draw_string(font, Vector2(0, H * 0.6), msg2, HORIZONTAL_ALIGNMENT_CENTER, W, int(font_size * 0.95), paper)
		"dance":
			var fd: String = cg["flash_dir"]
			var ft: float = cg["flash_t"]
			var center := Vector2(W * 0.5, H * 0.58)
			if not g3_on("dance_a"):
				ci.draw_circle(center, short_side * 0.14, Color(0, 0, 0, 0.18))
			if fd != "" and ft < 0.45 and not g3_on("dance_a"):
				draw_arrow(cg_draw, center, fd, short_side * 0.1, Color(1, 0.86, 0.3) if cg["phase"] == "show" else Color(0.7, 0.95, 1.0))
			var seqn := (cg["seq"] as Array).size()
			for k in seqn:
				var px := W * 0.5 + (k - (seqn - 1) / 2.0) * font_size * 1.1
				var done: bool = cg["phase"] == "input" and k < int(cg["input_i"])
				ci.draw_circle(Vector2(px, H * 0.72), font_size * 0.3, Color(1, 0.86, 0.3) if done else Color(1, 1, 1, 0.35))
			ci.draw_string(font, Vector2(0, H * 0.79), tr("보여 준 순서대로 손가락을 휙휙!") if cg["phase"] == "input" else tr("화살표 순서를 잘 봐요"), HORIZONTAL_ALIGNMENT_CENTER, W, int(font_size * 0.85), paper)

# --- 갯벌 캐기: 여러 숨구멍 중 뽀글뽀글 거품이 오르는 곳을 찾아요 ---
# 바지락은 톡톡, 큰 백합은 빠르게 연타, 맛조개는 쏙 나올 때 위로 쓱!, 꽃게는 건드리면 따끔!
const DIG_KINDS_KO := {
	"clam": {"name": "바지락", "taps": 3, "life": 2.4},
	"big": {"name": "백합", "taps": 7, "life": 2.8},
	"razor": {"name": "맛조개", "taps": 0, "life": 1.1},
	"crab": {"name": "꽃게", "taps": 0, "life": 1.5},
}
var DIG_KINDS: Dictionary = trd(DIG_KINDS_KO)

func dig_holes() -> Array:
	return w.get("dig_holes", [])

func dig_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.45
	return m

func dig_make_node(kind: String) -> Node3D:
	var n := Node3D.new()
	world_node(n)
	match kind:
		"clam":
			add_blobs(n, [[Vector3(0, 0.06, 0), Vector3(0.26, 0.12, 0.2), Color(0.82, 0.74, 0.62)], [Vector3(0, 0.1, 0), Vector3(0.2, 0.06, 0.16), Color(0.65, 0.55, 0.45)]], blob_gloss())
		"big":
			add_blobs(n, [[Vector3(0, 0.1, 0), Vector3(0.46, 0.22, 0.38), Color(0.9, 0.86, 0.78)], [Vector3(0, 0.17, 0), Vector3(0.36, 0.1, 0.3), Color(0.72, 0.62, 0.52)]], blob_gloss())
		"razor":
			var mi := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.045
			cm.bottom_radius = 0.045
			cm.height = 0.55
			mi.mesh = cm
			mi.material_override = dig_mat(Color(0.86, 0.76, 0.5))
			mi.position = Vector3(0, 0.2, 0)
			n.add_child(mi)
			add_blobs(n, [[Vector3(0, 0.49, 0), Vector3(0.07, 0.07, 0.07), Color(1.0, 0.9, 0.85)]])
		"crab":
			var items := [[Vector3(0, 0.12, 0), Vector3(0.4, 0.16, 0.3), Color(0.85, 0.3, 0.2)], [Vector3(-0.08, 0.22, 0.12), Vector3(0.05, 0.08, 0.05), Color(0.1, 0.05, 0.05)], [Vector3(0.08, 0.22, 0.12), Vector3(0.05, 0.08, 0.05), Color(0.1, 0.05, 0.05)], [Vector3(-0.26, 0.14, 0.12), Vector3(0.14, 0.1, 0.12), Color(0.9, 0.35, 0.22)], [Vector3(0.26, 0.14, 0.12), Vector3(0.14, 0.1, 0.12), Color(0.9, 0.35, 0.22)]]
			for k in 3:
				items.append([Vector3(-0.22, 0.06, -0.06 - k * 0.07), Vector3(0.16, 0.03, 0.03), Color(0.75, 0.25, 0.15)])
				items.append([Vector3(0.22, 0.06, -0.06 - k * 0.07), Vector3(0.16, 0.03, 0.03), Color(0.75, 0.25, 0.15)])
			add_blobs(n, items)
	return n

func update_dig(delta: float) -> void:
	if float(cg["t"]) < 0.0:
		return
	var holes := dig_holes()
	if holes.is_empty():
		return
	var tg: Dictionary = cg["tgt"]
	if tg.is_empty():
		cg["gap"] = float(cg["gap"]) - delta
		if float(cg["gap"]) <= 0.0:
			var i := rng.randi() % holes.size()
			if i == int(cg["last"]):
				i = (i + 1 + rng.randi() % (holes.size() - 1)) % holes.size()
			cg["last"] = i
			var r := rng.randf()
			var kind := "clam"
			if mg_count >= 1:
				if r < 0.22:
					kind = "big"
				elif r < 0.44:
					kind = "razor"
				elif r < 0.6:
					kind = "crab"
			cg["tgt"] = {"i": i, "kind": kind, "state": "tell", "t": 0.0, "taps": 0, "bub": 0.0}
		return
	tg["t"] = float(tg["t"]) + delta
	var hp: Vector3 = holes[int(tg["i"])]
	var kind2: String = tg["kind"]
	var sp := 1.0 + mg_count * 0.04
	if tg["state"] == "tell":
		tg["bub"] = float(tg["bub"]) - delta
		if float(tg["bub"]) <= 0.0:
			tg["bub"] = 0.1
			burst3d(hp + Vector3(0, 0.05, 0), Color(0.85, 0.95, 1.0) if kind2 != "crab" else Color(0.95, 0.75, 0.6), 3)
			sfx("tick", 1.6 + rng.randf() * 0.3)
		if float(tg["t"]) > 0.55 / sp:
			tg["state"] = "up"
			tg["t"] = 0.0
			var n := dig_make_node(kind2)
			n.global_position = hp + Vector3(0, -0.25, 0)
			n.rotation.y = rng.randf() * TAU
			var rise := 0.0 if kind2 in ["clam", "big"] else (0.18 if kind2 == "razor" else 0.05)
			n.create_tween().tween_property(n, "global_position:y", hp.y + rise, 0.15).set_ease(Tween.EASE_OUT)
			tg["node"] = n
			if kind2 == "crab":
				sfx("crack", 1.6)
		return
	var life: float = float(DIG_KINDS[kind2]["life"]) / sp
	var node: Node3D = tg.get("node")
	if kind2 == "crab" and node != null:
		node.rotation.y += sin(anim_t * 18.0) * 0.08
	if kind2 == "razor" and node != null:
		node.position.y = hp.y + 0.18 + sin(anim_t * 20.0) * 0.03
	if float(tg["t"]) > life:
		if kind2 == "crab":
			cg_judge(tr("휴~ 꽃게가 지나갔어요"), Color(0.85, 0.95, 1.0), false)
			if node != null:
				var tw := node.create_tween()
				tw.tween_property(node, "global_position", node.global_position + Vector3(1.8, 0, 0.3), 0.5)
				tw.tween_callback(node.queue_free)
		else:
			cg_lose(tr("쏙 숨었어요!"))
			cg_event("escape", {"at": hp})
			if node != null:
				var tw2 := node.create_tween()
				tw2.tween_property(node, "global_position:y", hp.y - 0.4, 0.2)
				tw2.tween_callback(node.queue_free)
		cg["tgt"] = {}
		cg["gap"] = 0.45

func dig_hole_at(pos: Vector2) -> int:
	var best := -1
	var bd := short_side * 0.14
	var holes := dig_holes()
	for k in holes.size():
		var d := pos.distance_to(cam.unproject_position(holes[k]))
		if d < bd:
			bd = d
			best = k
	return best

func dig_go(hp: Vector3) -> void:
	# 주인공이 그 구멍 옆으로 폴짝 옮겨 가요
	var stand := hp + Vector3(-0.55, 0, 0.45)
	stand.y = player.position.y
	if player.position.distance_to(stand) > 0.2:
		player.create_tween().tween_property(player, "position", stand, 0.12)
	player.rotation.y = atan2(hp.x - stand.x, hp.z - stand.z)

func dig_press(pos: Vector2) -> void:
	var k := dig_hole_at(pos)
	if k < 0:
		return
	var holes := dig_holes()
	var hp: Vector3 = holes[k]
	dig_go(hp)
	var tg: Dictionary = cg["tgt"]
	if tg.is_empty() or int(tg["i"]) != k:
		w["swing"] = 1.0
		burst3d(hp + Vector3(0, 0.05, 0), Color(0.45, 0.38, 0.3), 4)
		cg_judge(tr("거긴 빈 구멍!"), Color(0.85, 0.85, 0.9), false)
		cg_combo_break()
		return
	if tg["state"] == "tell":
		cg_judge(tr("아직! 나오면 캐요"), Color(1, 0.9, 0.6), false)
		return
	var kind: String = tg["kind"]
	var node: Node3D = tg.get("node")
	match kind:
		"crab":
			cg_lose(tr("앗 따가워! 꽃게였어요"))
			flash(Color(1, 0.6, 0.5))
			if node != null:
				var tw := node.create_tween()
				tw.tween_property(node, "global_position", node.global_position + Vector3(-1.6, 0, 0.6), 0.4)
				tw.tween_callback(node.queue_free)
			cg["tgt"] = {}
			cg["gap"] = 0.5
		"razor":
			cg["razor_press"] = pos
		_:
			w["swing"] = 1.0
			tg["taps"] = int(tg["taps"]) + 1
			cam_kick = 0.06
			sfx("tap", 0.9 + int(tg["taps"]) * 0.05)
			burst3d(hp + Vector3(0, 0.08, 0), Color(0.42, 0.36, 0.3), 5)
			if node != null:
				node.global_position.y = hp.y + 0.03 * int(tg["taps"])
				node.scale = Vector3.ONE * 1.12
				node.create_tween().tween_property(node, "scale", Vector3.ONE, 0.1)
			if int(tg["taps"]) >= int(DIG_KINDS[kind]["taps"]):
				dig_got(tg, hp)

func dig_drag(pos: Vector2) -> void:
	var tg: Dictionary = cg["tgt"]
	if cg.get("razor_press") == null or tg.is_empty() or tg["kind"] != "razor" or tg["state"] != "up":
		return
	var d := (cg["razor_press"] as Vector2) - pos
	if d.y > short_side * 0.07:
		cg["razor_press"] = null
		var hp: Vector3 = dig_holes()[int(tg["i"])]
		dig_got(tg, hp)

func dig_release(_pos: Vector2) -> void:
	if cg.get("razor_press") != null:
		cg["razor_press"] = null
		var tg: Dictionary = cg["tgt"]
		if not tg.is_empty() and tg["kind"] == "razor":
			cg_judge(tr("위로 쓱 당겨요!"), Color(1, 0.9, 0.6), false)

func dig_got(tg: Dictionary, hp: Vector3) -> void:
	var kind: String = tg["kind"]
	var node: Node3D = tg.get("node")
	mg_count += 1
	w["swing"] = 1.0
	var quick := float(tg["t"]) < 0.9
	if quick:
		cg_combo_up()
	cg_judge(tr("%s 쏙!%s") % [DIG_KINDS[kind]["name"], tr(" 빠르다!") if quick else ""], Color(1, 0.88, 0.3), kind != "clam")
	sfx("pop", 1.0 if kind != "big" else 0.8)
	hit_stop(0.05 if kind == "big" else 0.03)
	shake(10 if kind == "big" else 6)
	cam_kick = 0.14
	burst3d(hp + Vector3(0, 0.2, 0), Color(0.45, 0.38, 0.3), 14)
	cg_event("round", {"at": hp})
	if node != null:
		var tw := node.create_tween()
		tw.tween_property(node, "global_position", hp + Vector3(-0.5, 1.4, 0.5), 0.28).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(node, "rotation", Vector3(3, 2, 0), 0.28)
		tw.tween_property(node, "scale", Vector3.ONE * 0.01, 0.18)
		tw.tween_callback(node.queue_free)
	cg["tgt"] = {}
	cg["gap"] = 0.35

func dig_draw(ci: CanvasItem, W: float, H: float, paper: Color) -> void:
	var tg: Dictionary = cg["tgt"]
	if tg.is_empty() or tg["state"] != "up":
		ci.draw_string(font, Vector2(0, H * 0.8), tr("뽀글뽀글 거품이 오르는 구멍을 봐요"), HORIZONTAL_ALIGNMENT_CENTER, W, int(font_size * 0.85), paper)
		return
	var hp: Vector3 = dig_holes()[int(tg["i"])]
	var sp := cam.unproject_position(hp + Vector3(0, 0.5, 0))
	var kind: String = tg["kind"]
	var txt := ""
	var col := paper
	match kind:
		"clam", "big":
			txt = tr("톡톡! %d") % (int(DIG_KINDS[kind]["taps"]) - int(tg["taps"]))
			col = Color(1, 0.95, 0.7)
		"razor":
			txt = tr("위로 쓱!")
			col = Color(0.75, 0.95, 1.0)
		"crab":
			txt = tr("꽃게! 건드리지 마요")
			col = Color(1, 0.55, 0.45)
	ci.draw_string(font, sp - Vector2(W * 0.3, 0), txt, HORIZONTAL_ALIGNMENT_CENTER, W * 0.6, int(font_size * 1.1), col)


# ---------- 미니게임 3D 연출: 월드에서 하는 쌓기·던지기·조개·춤은 그림 대신 진짜 물건으로 ----------
var g3 := {}

func g3_on(key: String) -> bool:
	return mg_world and w.has(key)

func g3_mat(c: Color, glow: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.6
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = glow
	return m

func g3_box(size: Vector3, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = g3_mat(c)
	world_node(mi)
	return mi

# 두 점 사이를 잇는 가는 막대 (새총 고무줄)
func g3_stretch(mi: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var d := b - a
	var l := d.length()
	if l < 0.001:
		mi.visible = false
		return
	mi.visible = true
	var y := d / l
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	mi.global_transform = Transform3D(Basis(x, y * l, z), (a + b) / 2.0)

func update_g3(delta: float) -> void:
	if not mg_world:
		return
	if g3.get("cam0") == null:
		g3["cam0"] = world_cam
	match mg_type:
		"stack":
			if w.has("stack_base"):
				g3_stack(delta)
		"aim":
			if w.has("aim3d"):
				g3_aim(delta)
		"simon":
			if w.has("simon_pts"):
				g3_simon(delta)
		"dance":
			if w.has("dance_a"):
				g3_dance(delta)

const STACK_COLS := [Color(0.98, 0.97, 0.92), Color(0.55, 0.72, 0.4), Color(1.0, 0.75, 0.8), Color(0.98, 0.85, 0.45)]
const STACK_TH := 0.13

func stack_world(x: float, k: int) -> Vector3:
	var base: Vector3 = w["stack_base"]
	var span: float = w.get("stack_span", 1.5)
	return base + Vector3((x - 0.5) * span, k * STACK_TH + STACK_TH / 2.0, 0)

func g3_stack(delta: float) -> void:
	var span: float = w.get("stack_span", 1.5)
	var layers: Array = cg["layers"]
	if not g3.has("layers"):
		g3["layers"] = []
		g3["falls_n"] = 0
		g3["cur"] = g3_box(Vector3(1, STACK_TH * 0.92, 0.55), STACK_COLS[1])
	var made: Array = g3["layers"]
	while made.size() < layers.size():
		var k := made.size()
		var L: Array = layers[k]
		var n := g3_box(Vector3(float(L[1]) * span, STACK_TH * 0.92, 0.55), STACK_COLS[k % 4])
		n.position = stack_world(float(L[0]), k)
		if k > 0:
			# 내려앉는 맛: 살짝 눌렸다가 펴져요
			n.scale = Vector3(1.06, 0.6, 1.06)
			n.create_tween().tween_property(n, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			burst3d(n.position + Vector3(0, STACK_TH / 2.0, 0.28), Color(1, 0.97, 0.85), 6)
		made.append(n)
	var cur: Array = cg["cur"]
	var cn: MeshInstance3D = g3["cur"]
	(cn.mesh as BoxMesh).size = Vector3(float(cur[1]) * span, STACK_TH * 0.92, 0.55)
	(cn.material_override as StandardMaterial3D).albedo_color = STACK_COLS[layers.size() % 4]
	cn.position = stack_world(float(cur[0]), layers.size()) + Vector3(0, 0.03 + sin(anim_t * 6.0) * 0.015, 0)
	# 잘려 떨어지는 조각
	var falls: Array = cg["falls"]
	while int(g3["falls_n"]) < falls.size():
		var f: Array = falls[int(g3["falls_n"])]
		g3["falls_n"] = int(g3["falls_n"]) + 1
		var fnode := g3_box(Vector3(float(f[1]) * span, STACK_TH * 0.92, 0.55), STACK_COLS[int(f[4]) % 4])
		var p0 := stack_world(float(f[0]), int(f[4]))
		fnode.position = p0
		var side := signf(float(f[0]) - 0.5) if absf(float(f[0]) - 0.5) > 0.01 else 1.0
		var tw := fnode.create_tween()
		tw.tween_property(fnode, "position", p0 + Vector3(side * 0.6, -1.4 - int(f[4]) * STACK_TH, 0.2), 0.7).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(fnode, "rotation", Vector3(0.8, 0.0, -side * 2.2), 0.7)
		tw.tween_callback(fnode.queue_free)
	# 높이 쌓일수록 카메라가 따라 올라가요
	var lift := maxf(0.0, layers.size() - 5.0) * STACK_TH
	var c0: Transform3D = g3["cam0"]
	g3["lift"] = lerpf(float(g3.get("lift", 0.0)), lift, minf(1.0, delta * 4.0))
	world_cam = c0.translated(Vector3(0, float(g3["lift"]), 0))

func g3_aim(delta: float) -> void:
	if not g3.has("pine"):
		var pine := Node3D.new()
		world_node(pine)
		var body := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.11
		sm.height = 0.3
		body.mesh = sm
		body.material_override = g3_mat(Color(0.5, 0.33, 0.18))
		pine.add_child(body)
		for k in 6:
			var sc := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.24, 0.03, 0.08)
			sc.mesh = bm
			sc.material_override = g3_mat(Color(0.38, 0.24, 0.12))
			sc.position = Vector3(0, -0.1 + k * 0.04, 0)
			sc.rotation.y = k * 1.1
			pine.add_child(sc)
		pine.visible = false
		g3["pine"] = pine
		# 새총: Y자 나뭇가지 + 고무줄 두 가닥 + 가죽 주머니
		var sling := Node3D.new()
		world_node(sling)
		var wood := g3_mat(Color(0.45, 0.3, 0.18))
		for part in [[Vector3(0, -0.09, 0), Vector3(0.035, 0.2, 0.035), 0.0], [Vector3(-0.05, 0.05, 0), Vector3(0.03, 0.14, 0.03), 0.5], [Vector3(0.05, 0.05, 0), Vector3(0.03, 0.14, 0.03), -0.5]]:
			var mi := MeshInstance3D.new()
			var bx := BoxMesh.new()
			bx.size = part[1]
			mi.mesh = bx
			mi.material_override = wood
			mi.position = part[0]
			mi.rotation.z = part[2]
			sling.add_child(mi)
		g3["sling"] = sling
		var band := g3_mat(Color(0.9, 0.78, 0.55))
		for nm in ["bandL", "bandR"]:
			var b := MeshInstance3D.new()
			var bb := BoxMesh.new()
			bb.size = Vector3(0.008, 1.0, 0.008)
			b.mesh = bb
			b.material_override = band
			world_node(b)
			g3[nm] = b
		var pouch := MeshInstance3D.new()
		var ps := SphereMesh.new()
		ps.radius = 0.03
		ps.height = 0.05
		pouch.mesh = ps
		pouch.material_override = g3_mat(Color(0.5, 0.33, 0.2))
		world_node(pouch)
		g3["pouch"] = pouch
		var dots := []
		var dm := SphereMesh.new()
		dm.radius = 0.012
		dm.height = 0.024
		for k in 10:
			var d := MeshInstance3D.new()
			d.mesh = dm
			d.material_override = g3_mat(Color(1, 1, 0.9), 1.5)
			d.material_override.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			world_node(d)
			dots.append(d)
		g3["dots"] = dots
		# 과녁: 호랑이 머리 둘레에 도는 빛 고리
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.42
		tm.outer_radius = 0.5
		ring.mesh = tm
		var rm := g3_mat(Color(1, 0.5, 0.35), 2.0)
		rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		rm.no_depth_test = true
		rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		rm.albedo_color.a = 0.75
		ring.material_override = rm
		world_node(ring)
		g3["ring"] = ring
	var near := 1.0
	var an := aim_anchor()
	var fork := cam.project_position(an + Vector2(0, -font_size * 1.2), near)
	var sling: Node3D = g3["sling"]
	sling.global_transform = Transform3D(cam.global_transform.basis.scaled(Vector3.ONE * 1.0), cam.project_position(an, near))
	var cb := cam.global_transform.basis
	var tipL := sling.global_position + cb * Vector3(-0.09, 0.12, 0)
	var tipR := sling.global_position + cb * Vector3(0.09, 0.12, 0)
	var pouch_p := (tipL + tipR) / 2.0
	var dots: Array = g3["dots"]
	for d in dots:
		(d as Node3D).visible = false
	if cg.get("drag") != null:
		var dp: Vector2 = cg["drag"]
		pouch_p = cam.project_position(dp, near)
		var pp := an
		var vv := (an - dp) * 5.2
		var H := mg_overlay.size.y
		for k in dots.size():
			vv += Vector2(0, H * 1.4) * 0.05
			pp += vv * 0.05
			var dn: Node3D = dots[k]
			dn.visible = true
			dn.global_position = cam.project_position(pp, near + k * 0.35)
	g3_stretch(g3["bandL"], tipL, pouch_p)
	g3_stretch(g3["bandR"], tipR, pouch_p)
	(g3["pouch"] as Node3D).global_position = pouch_p
	var tgt3: Vector3 = w["aim3d"].call()
	var ring: Node3D = g3["ring"]
	var hf: float = cg["hit_flash"]
	ring.global_transform = Transform3D(Basis(cb.x, cb.z, -cb.y).scaled(Vector3.ONE * (1.0 + hf * 0.4 + sin(anim_t * 5.0) * 0.05)), tgt3)
	var pine: Node3D = g3["pine"]
	var sh: Dictionary = cg["shot"]
	if sh.is_empty():
		pine.visible = cg.get("drag") != null
		if pine.visible:
			pine.global_position = pouch_p
	else:
		pine.visible = true
		sh["age"] = float(sh.get("age", 0.0)) + delta
		var far := cam.global_position.distance_to(tgt3)
		var depth := lerpf(near, far, clampf(float(sh["age"]) / 0.45, 0.0, 1.0))
		pine.global_position = cam.project_position(sh["p"], depth)
		pine.rotation = Vector3(float(sh["spin"]), float(sh["spin"]) * 0.7, 0)
		pine.scale = Vector3.ONE * (0.5 + depth * 0.12)

func g3_simon(_delta: float) -> void:
	var pts: Array = w["simon_pts"]
	if not g3.has("shells"):
		var shells := []
		for k in pts.size():
			var n := Node3D.new()
			world_node(n)
			n.global_position = pts[k]
			var col: Color = SIMON_COLS[k]
			var m := g3_mat(col, 0.0)
			m.roughness = 0.3
			# 부채꼴 가리비: 납작한 반구 + 골 다섯 줄
			var cap := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.32
			sm.height = 0.3
			sm.is_hemisphere = true
			cap.mesh = sm
			cap.material_override = m
			cap.scale = Vector3(1.0, 0.55, 0.85)
			n.add_child(cap)
			for f in 5:
				var rib := MeshInstance3D.new()
				var bm := BoxMesh.new()
				bm.size = Vector3(0.035, 0.05, 0.3)
				rib.mesh = bm
				rib.material_override = g3_mat(col.darkened(0.3))
				rib.position = Vector3(0, 0.1, 0.02)
				rib.rotation = Vector3(0.35, (f - 2) * 0.38, 0)
				n.add_child(rib)
			var hinge := MeshInstance3D.new()
			var hb := BoxMesh.new()
			hb.size = Vector3(0.16, 0.06, 0.08)
			hinge.mesh = hb
			hinge.material_override = g3_mat(col.darkened(0.2))
			hinge.position = Vector3(0, 0.03, -0.24)
			n.add_child(hinge)
			n.set_meta("mat", m)
			shells.append(n)
		g3["shells"] = shells
	var lit := int(cg["lit"])
	var lt: float = cg["lit_t"]
	var shells2: Array = g3["shells"]
	for k in shells2.size():
		var n: Node3D = shells2[k]
		var m: StandardMaterial3D = n.get_meta("mat")
		var on := k == lit and lt < 0.3
		m.emission_enabled = on
		m.emission = SIMON_COLS[k]
		m.emission_energy_multiplier = 2.2
		var s := 1.0 + (0.25 * (1.0 - lt / 0.3) if on else 0.0)
		n.scale = Vector3(s, s, s)
		n.position.y = (pts[k] as Vector3).y + (0.12 * (1.0 - lt / 0.3) if on else 0.0)

func g3_dance(_delta: float) -> void:
	if not g3.has("arrow"):
		var a := Node3D.new()
		world_node(a)
		var m := g3_mat(Color(1, 0.86, 0.3), 1.6)
		var shaft := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.4, 0.14, 0.08)
		shaft.mesh = bm
		shaft.material_override = m
		shaft.position = Vector3(-0.12, 0, 0)
		a.add_child(shaft)
		var head := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = 0.2
		cm.height = 0.3
		cm.radial_segments = 3
		head.mesh = cm
		head.material_override = m
		head.position = Vector3(0.2, 0, 0)
		head.rotation.z = -PI / 2.0
		a.add_child(head)
		a.set_meta("mat", m)
		g3["arrow"] = a
	var arrow: Node3D = g3["arrow"]
	var fd: String = cg["flash_dir"]
	var ft: float = cg["flash_t"]
	arrow.visible = fd != "" and ft < 0.45
	if not arrow.visible:
		return
	var who: Node3D = w["dance_a"] if cg["phase"] == "show" else w["dance_b"]
	var cb := cam.global_transform.basis
	var ang := {"right": 0.0, "up": PI / 2.0, "left": PI, "down": -PI / 2.0}
	var rot := Basis(cb.z, float(ang.get(fd, 0.0)))
	var pop := 1.0 + maxf(0.0, 0.15 - ft) * 3.0
	arrow.global_transform = Transform3D((rot * cb).scaled(Vector3.ONE * pop), who.global_position + Vector3(0, 2.3, 0))
	(arrow.get_meta("mat") as StandardMaterial3D).albedo_color = Color(1, 0.86, 0.3) if cg["phase"] == "show" else Color(0.7, 0.95, 1.0)
	(arrow.get_meta("mat") as StandardMaterial3D).emission = (arrow.get_meta("mat") as StandardMaterial3D).albedo_color


# ---------- 미니게임 공통 ----------

func start_game(type: String, cfg: Dictionary, done: Callable) -> void:
	w = {}
	world_hidden = []
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
		if cfg["label"] == tr("제비"):
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
	elif type == "fish":
		mg_timer = rng.randf_range(1.2, 2.4)
	mg_fx = []
	if art_key() != "":
		# 판정용 동그라미는 숨기고, 그 위치에 진짜 그림을 그려요
		for child in mg_stage.get_children():
			if child is CanvasItem and not child.is_queued_for_deletion():
				(child as CanvasItem).modulate.a = 0.0
		mg_art = Control.new()
		mg_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mg_stage.add_child(mg_art)
		place(mg_art, 0, 0, 1, 1)
		mg_art.draw.connect(draw_mg_art)
	var is_world: bool = cfg.get("world", false)
	mg_overlay.color = Color(0, 0, 0, 0) if is_world else Color(0.62, 0.83, 0.96, 1.0)
	mg_back.visible = not is_world
	mg_world_ui.visible = is_world
	mg_active = true
	if cfg.has("scene"):
		scene_setup(cfg["scene"])
	if CUSTOM_GAMES.has(type):
		custom_begin()
	mg_lives_start = mg_lives
	pop(mg_title, 1.15)

func end_game(ok: bool) -> void:
	mg_active = false
	if mg_world:
		if ok and mg_type == "fish":
			fish_leap(fish_kind)
		world_game_end()
		mg_back.visible = true
		mg_world_ui.visible = false
		mg_overlay.color = Color(0.62, 0.83, 0.96, 1.0)
	mg_overlay.visible = false
	mg_items = []
	for child in mg_stage.get_children():
		child.queue_free()
	var mid := mg_overlay.size / 2.0
	if ok:
		sfx("win")
		float_text(tr("성공!"), mid, Color(1, 0.9, 0.4), 2.0)
		burst(mid, Color(1, 0.85, 0.3), 18)
		# 별점: 기회를 하나도 안 잃으면 별 셋 (덤으로 엽전)
		var lost := mg_lives_start - mg_lives
		var stars := 3 if lost <= 0 else (2 if lost == 1 else 1)
		float_text("★".repeat(stars) + "☆".repeat(3 - stars), mid + Vector2(0, font_size * 2.6), Color(1, 0.86, 0.25), 2.2)
		if stars == 3 and CUSTOM_GAMES.has(mg_type):
			coins += 5
			float_text(tr("별 셋! +5냥"), mid + Vector2(0, font_size * 4.6), Color(1, 0.95, 0.6), 1.2)
	else:
		sfx("fail")
		shake(16)
		float_text(tr("아이쿠!"), mid, Color(1, 0.55, 0.45), 2.0)
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
	if CUSTOM_GAMES.has(mg_type):
		custom_input(event)
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
	var real_press: bool = is_button and not (event is InputEventMouseButton and event.device == -1)
	if mg_type == "well3d":
		var now := float(Time.get_ticks_msec())
		if is_button:
			w["last_y"] = mg_pos.y
			w["last_ms"] = now
		elif w.has("last_y"):
			well_drag(float(w["last_y"]) - mg_pos.y, now - float(w.get("last_ms", now)))
			w["last_y"] = mg_pos.y
			w["last_ms"] = now
	if real_press and mg_type == "wood3d":
		wood_strike()
	elif real_press and mg_type == "fish":
		fish_tap()
	elif real_press and mg_type == "plant":
		plant_tap()
	elif real_press and mg_type == "axe":
		axe_tap()
	elif real_press and mg_type == "gam":
		gam_tap(mg_pos)
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
				var mark := mg_dot(mg_cfg.get("trail", PAPER), font_size * 0.18, "")
				mg_move(mark, mg_pos.x, mg_pos.y)
				var tw := mark.create_tween()
				tw.tween_property(mark, "modulate:a", 0.0, 1.2)
				tw.tween_callback(mark.queue_free)
		mg_last_angle = a
		mg_has_last = true

func update_game(delta: float) -> void:
	for f in mg_fx:
		f[2] += delta
	mg_fx = mg_fx.filter(func(f): return f[2] < 0.6)
	if is_instance_valid(mg_art) and art_key() != "":
		mg_art.queue_redraw()
	if mg_type == "circle":
		update_circle(delta)
	elif mg_type == "follow":
		update_follow(delta)
	elif mg_type == "catch":
		update_catch(delta)
	elif mg_type == "fish":
		update_fish(delta)
		update_fish_world(delta)
	elif mg_type == "wood3d":
		update_wood3d(delta)
	elif mg_type == "well3d":
		update_well3d(delta)
	elif mg_type == "plant":
		update_plant(delta)
	elif mg_type == "gam":
		update_gam(delta)
	elif mg_type == "axe":
		update_axe(delta)
		mg_progress = float(mg_count) / AXE_GOAL
	elif CUSTOM_GAMES.has(mg_type):
		update_custom(delta)
	else:
		update_tap(delta)
	if mg_world:
		scene_update(delta)
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
		mg_info.text = tr("%s\n남은 기회 %d") % [mg_cfg["warn"], mg_lives]
	else:
		mg_info.text = tr("남은 기회 %d") % mg_lives

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
		mg_info.text = tr("박자가 맞아요!")
	else:
		mg_b.modulate = Color(1, 1, 1)
		if mg_started:
			mg_off += delta
		mg_info.text = tr("갈색을 따라 좌우로!\n남은 여유 %d초") % int(ceil(patience - mg_off))
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
	var basket_y: float = mg_cfg.get("basket_px", h * 0.78)
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
		mg_move(item, rng.randf_range(w * 0.12, w * 0.88), float(mg_cfg.get("spawn_px", h * 0.37)))
		if art_key() != "":
			item.modulate.a = 0.0
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
				float_text(tr("아야!"), center, Color(1, 0.55, 0.45), 1.2)
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
	mg_info.text = tr("%s %d/%d | 남은 기회 %d") % [mg_cfg["good"], mg_count, goal, mg_lives]

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
		if mg_world:
			# 3D 장면에서는 움직이는 목표라서, 손가락이 닿는 순간 바로 눌리고 판정도 넉넉하게 해요
			b.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
			b.size = Vector2(r * 3.0, r * 3.0)
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
		if art_key() != "":
			node.modulate = Color(1, 1, 1, 0)
		else:
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
	mg_info.text = tr("%s %d/%d | 남은 기회 %d") % [mg_cfg["target"], mg_count, goal, mg_lives]

func on_tap(b: Button) -> void:
	for i in mg_items.size():
		if mg_items[i][0] == b:
			mg_items.remove_at(i)
			mg_count += 1
			var at := b.position + b.size / 2.0
			match art_key():
				"wood": add_mg_fx("split", at)
				"kim": add_mg_fx("stake", at)
				"snake": add_mg_fx("snake", at)
				"sparrow": add_mg_fx("sparrow", at)
			sfx("pop", 1.0 + mg_count * 0.04)
			shake(4)
			burst(at, Color(0.6, 0.9, 0.5), 7)
			float_text([tr("뽁!"), tr("쏙!"), tr("얍!")][mg_count % 3], at, Color(1, 1, 1), 1.1)
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

var stick_view: Control
var stick_alpha := 0.0
var auto_cam := true          # 걸어가는 쪽으로 카메라가 천천히 따라 돌아요

func draw_stick() -> void:
	if stick_alpha <= 0.01:
		return
	var r := drag_range
	var a := stick_alpha
	stick_view.draw_circle(touch_start, r * 1.05, Color(0, 0, 0, 0.18 * a))
	stick_view.draw_arc(touch_start, r, 0, TAU, 48, Color(1, 1, 1, 0.55 * a), maxf(3.0, r * 0.05), true)
	var knob := touch_start + move_input * r
	stick_view.draw_circle(knob, r * 0.42, Color(1, 0.97, 0.88, 0.75 * a))
	stick_view.draw_arc(knob, r * 0.42, 0, TAU, 32, Color(0.45, 0.32, 0.2, 0.6 * a), maxf(2.0, r * 0.03), true)

func update_stick_and_cam(delta: float) -> void:
	var want := 1.0 if touching and stick_index != -1 else 0.0
	stick_alpha = move_toward(stick_alpha, want, delta * (8.0 if want > 0.0 else 4.0))
	if stick_view != null:
		stick_view.queue_redraw()
	# 옆으로 걸으면 카메라가 천천히 주인공 뒤로 돌아와요 (뒤로 걸을 땐 그대로)
	if auto_cam and touching and move_input.length() > 0.35 and not swimming:
		var a := atan2(move_input.x, -move_input.y)
		if absf(a) < 2.2:
			cam_yaw_target -= a * minf(1.0, delta * 0.6) * move_input.length()

func on_turn() -> void:
	cam_yaw_target += PI / 2.0

func on_jump() -> void:
	jump_wanted = true
	# 물속에서는 한 번 톡 눌러도 쑥 떠올라요 (꾹 누르면 계속 올라가요)
	if swimming and player != null:
		player.velocity.y = maxf(player.velocity.y, SWIM_UP * 1.15)
		sfx("splash", 1.4)

# ---------- 헤엄치기 (장마다 물속인지 알려 줘요) ----------
const SWIM_UP := 3.2
const SWIM_SINK := 0.9
var swimming := false
var cam_prev := Vector3.ZERO
var cam_smooth_ok := false
var jump_touch := -1
var jump_mouse := false

func is_swimming() -> bool:
	return false

# 헤엄칠 때 발이 올라갈 수 있는 가장 높은 곳 (물 위로 튀어나가지 않게)
func swim_ceiling() -> float:
	return 0.0

const MOUSE_STICK := -2
var rmb_turning := false
func release_mouse_holds() -> void:
	rmb_turning = false
	jump_mouse = false
	if stick_index == MOUSE_STICK:
		stick_index = -1
		touching = false
		move_input = Vector2.ZERO
# 휴대폰/태블릿이면 터치 안내, 컴퓨터면 키보드·마우스 안내를 보여 줘요
func is_touch_device() -> bool:
	if OS.has_feature("web_android") or OS.has_feature("web_ios") or OS.has_feature("android") or OS.has_feature("ios"):
		return true
	if OS.has_feature("web"):
		return DisplayServer.is_touchscreen_available() and not JavaScriptBridge.eval("matchMedia('(pointer: fine)').matches", true)
	return false
var kb_moving := false
func keyboard_move() -> Vector2:
	var v := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		v.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		v.x += 1.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		v.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		v.y += 1.0
	return v.normalized()

func jump_held() -> bool:
	return jump_touch >= 0 or jump_mouse or Input.is_physical_key_pressed(KEY_SPACE)

# 카메라가 올라갈 수 있는 가장 높은 곳 (물속에서는 물 밑에 머물러요)
func cam_ceiling() -> float:
	return INF

func fall_limit() -> float:
	return -10.0

func respawn_point() -> Vector3:
	return Vector3(-2, 0, 16)

# 화면 버튼(돌리기/점프/행동)은 터치를 직접 처리해요.
# 한 손가락으로 걷는 중에도 다른 손가락으로 점프를 누를 수 있게 하기 위해서예요.
var btn_touches: Array = []
var stick_index := -1

func hud_button_hit(pos: Vector2) -> Button:
	if book_open or settings_open:
		return null
	for b in [jump_button, turn_button, action_button, book_button, settings_button]:
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
	elif b == book_button:
		open_book()
	elif b == settings_button:
		open_settings()

func _input(event: InputEvent) -> void:
	if player == null:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			var b := hud_button_hit(event.position)
			if b != null:
				btn_touches.append(event.index)
				if b == jump_button:
					jump_touch = event.index
				hud_press(b)
				get_viewport().set_input_as_handled()
		elif event.index in btn_touches:
			btn_touches.erase(event.index)
			if event.index == jump_touch:
				jump_touch = -1
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		if event.index in btn_touches:
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and not event.pressed:
		jump_mouse = false
	elif event is InputEventMouseButton and event.pressed and event.device != -1:
		# 컴퓨터 마우스 (터치에서 만들어진 가짜 마우스 이벤트는 제외)
		var b2 := hud_button_hit(event.position)
		if b2 != null:
			if b2 == jump_button:
				jump_mouse = true
			hud_press(b2)
			get_viewport().set_input_as_handled()

func pinch_dist() -> float:
	var ps := pinch_points.values()
	return (ps[0] as Vector2).distance_to(ps[1])

func pinch_angle() -> float:
	var ps := pinch_points.values()
	var d: Vector2 = (ps[1] as Vector2) - (ps[0] as Vector2)
	return atan2(d.y, d.x)

func _unhandled_input(event: InputEvent) -> void:
	if player == null:
		return
	# ---------- 컴퓨터 조작: WASD/방향키 걷기, 스페이스 점프, E/엔터 말 걸기·행동, Q/R 화면 돌리기 ----------
	if event is InputEventKey and event.pressed and not event.echo:
		var k: int = event.physical_keycode
		# 글 카드와 대화는 스페이스/엔터/E로도 넘겨요
		if k in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_E]:
			if in_card and card_tween != null and card_tween.is_valid() and card_overlay.modulate.a > 0.6:
				card_tween.kill()
				end_card()
				return
			if talking and not asking:
				next_line()
				return
		match k:
			KEY_SPACE:
				if not is_busy():
					on_jump()
			KEY_E, KEY_ENTER, KEY_KP_ENTER:
				if action_button != null and action_button.visible:
					on_action()
			KEY_Q:
				cam_yaw_target += PI / 4.0
			KEY_R:
				cam_yaw_target -= PI / 4.0
	# 진짜 마우스로 끌기 = 휴대폰의 손가락 끌기와 같은 조이스틱 (터치에서 만든 가짜 마우스는 device -1이라 제외)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.device != -1:
		if event.pressed and stick_index == -1:
			stick_index = MOUSE_STICK
			touching = true
			touch_start = event.position
			move_input = Vector2.ZERO
		elif not event.pressed and stick_index == MOUSE_STICK:
			stick_index = -1
			touching = false
			move_input = Vector2.ZERO
	elif event is InputEventMouseMotion and event.device != -1 and stick_index == MOUSE_STICK:
		move_input = ((event.position - touch_start) / drag_range).limit_length(1.0)
	# 마우스 오른쪽 버튼을 누른 채 좌우로 끌면 시야가 돌아가요 (컴퓨터용)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.device != -1:
		rmb_turning = event.pressed
	elif event is InputEventMouseMotion and event.device != -1 and rmb_turning:
		if (event.button_mask & MOUSE_BUTTON_MASK_RIGHT) == 0:
			rmb_turning = false   # 버튼을 뗀 신호를 놓쳤어도 실제로 안 눌려 있으면 멈춰요
		else:
			cam_yaw_target -= event.relative.x * 0.006
			cam_yaw = cam_yaw_target
	# 두 손가락으로 벌리고 오므려 확대/축소, 컴퓨터는 마우스 휠
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam_zoom_target = clampf(cam_zoom_target * 0.9, ZOOM_MIN, ZOOM_MAX)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam_zoom_target = clampf(cam_zoom_target * 1.1, ZOOM_MIN, ZOOM_MAX)
	if event is InputEventScreenTouch:
		if event.pressed:
			pinch_points[event.index] = event.position
		else:
			pinch_points.erase(event.index)
		if pinch_points.size() == 2:
			pinch_start_dist = maxf(pinch_dist(), 1.0)
			pinch_start_zoom = cam_zoom_target
			pinch_start_angle = pinch_angle()
			pinch_start_yaw = cam_yaw_target
			pinch_rotating = false
			# 확대 중에는 걷지 않아요
			stick_index = -1
			touching = false
			move_input = Vector2.ZERO
			return
		if pinch_points.size() > 2:
			return
	elif event is InputEventScreenDrag and pinch_points.has(event.index):
		pinch_points[event.index] = event.position
		if pinch_points.size() == 2:
			cam_zoom_target = clampf(pinch_start_zoom * pinch_start_dist / maxf(pinch_dist(), 1.0), ZOOM_MIN, ZOOM_MAX)
			# 두 손가락을 비틀면 화면이 돌아가요 (지도 앱처럼 손가락을 따라 세상이 돌아요)
			var turn := wrapf(pinch_angle() - pinch_start_angle, -PI, PI)
			if not pinch_rotating and absf(turn) > 0.14:
				pinch_rotating = true
				pinch_start_angle = pinch_angle()
				turn = 0.0
			if pinch_rotating:
				cam_yaw_target = pinch_start_yaw + turn
			return
	if event is InputEventScreenTouch:
		if event.pressed:
			if stick_index == -1 and pinch_points.size() == 1:
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
	if player == null:
		return
	if mg_active:
		update_game(delta)
	var busy := is_busy()
	if busy:
		move_input = Vector2.ZERO
		jump_wanted = false
		stick_index = -1
		touching = false
		btn_touches.clear()
		pinch_points.clear()
	update_stick_and_cam(delta)
	var kb := keyboard_move() if not busy else Vector2.ZERO
	if kb != Vector2.ZERO:
		move_input = kb
		kb_moving = true
	elif kb_moving:
		kb_moving = false
		if stick_index == -1:
			move_input = Vector2.ZERO
	cam_yaw = lerp_angle(cam_yaw, cam_yaw_target, minf(1.0, delta * 8.0))
	var speed := SPEED
	if has_shoes:
		speed = SPEED * 1.3
	var dir := Vector3(move_input.x, 0, move_input.y).rotated(Vector3.UP, cam_yaw)
	player.velocity.x = dir.x * speed
	player.velocity.z = dir.z * speed
	swimming = is_swimming()
	if swimming:
		# 물속: 위로 버튼을 누르고 있으면 떠오르고, 떼면 천천히 가라앉아요
		player.velocity.x *= 0.72
		player.velocity.z *= 0.72
		var want_vy := SWIM_UP if (jump_held() and not busy) else -SWIM_SINK
		player.velocity.y = lerpf(player.velocity.y, want_vy, minf(1.0, delta * 3.0))
		if player.position.y > swim_ceiling() and player.velocity.y > 0.0:
			player.velocity.y = 0.0
	elif player.is_on_floor():
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
	if on_floor and not was_on_floor and fall_speed > 3.0 and not swimming:
		# 착지: 쿵 하고 납작해졌다 돌아오기
		sfx("land")
		stretch_player(Vector3(1.3, 0.7, 1.3))
		burst3d(player.position, Color(0.85, 0.8, 0.65), 8)
	was_on_floor = on_floor
	if on_floor and dir.length() > 0.1 and not swimming:
		# 걸을 때 통통 튀고 발소리 내기
		# 살짝 밀면 걷고, 끝까지 밀면 달려요. 빠를수록 걸음 박자도 빨라져요
		var push := dir.length()
		gait_run = lerpf(gait_run, clampf((push - 0.45) / 0.45, 0.0, 1.0), 0.15)
		walk_phase += delta * lerpf(6.5, 12.5, gait_run) * maxf(push, 0.35)
		if player_body.has_meta("skel"):
			player_body.position.y = 1.0 + gait_bob(fposmod(walk_phase / TAU, 1.0), gait_run) * limb_amt
		else:
			player_body.position.y = 1.0 + absf(sin(walk_phase)) * 0.12
		limb_amt = lerpf(limb_amt, 1.0, 0.3)
		var steps := int(walk_phase / PI)
		if steps != step_count:
			step_count = steps
			# 동작 클립으로 걸을 땐 발이 땅에 닿는 순간에 맞춰 따로 울려요
			if not player_body.get_meta("anim_on", false) or not player_body.has_meta("step_times"):
				sfx("step", rng.randf_range(0.85, 1.15))
	else:
		player_body.position.y = lerpf(player_body.position.y, 1.0, 0.3)
		limb_amt = lerpf(limb_amt, 0.0, 0.25)
	arm_up_amt = lerpf(arm_up_amt, 0.0 if (on_floor or swimming) else 1.0, 0.3)
	player_body.set_meta("gait", [fposmod(walk_phase / TAU, 1.0), limb_amt, gait_run])
	var cur_speed := Vector2(player.velocity.x, player.velocity.z).length()
	if swimming:
		limb_amt = lerpf(limb_amt, clampf(cur_speed / 2.0, 0.0, 1.0), 0.2)
	if not (mg_active and mg_world) and (on_floor or swimming) and arm_up_amt < 0.15 and drive_anim(player_body, limb_amt, gait_run, cur_speed / lerpf(2.6, 6.5, gait_run)):
		# 동작 클립이 몸의 오르내림까지 해 줘요
		player_body.position.y = lerpf(player_body.position.y, 1.0, 0.3)
		anim_footsteps(on_floor and not swimming)
	else:
		stop_anim(player_body)
		if mg_active and mg_world:
			world_pose(delta)
		else:
			pose_person(player_body, sin(walk_phase) * limb_amt, arm_up_amt)
	if dir.length() > 0.1 and on_floor:
		player_body.rotation.x = lerpf(player_body.rotation.x, 0.04 if player_body.has_meta("skel") else 0.12, 0.2)
	else:
		player_body.rotation.x = lerpf(player_body.rotation.x, 0.0, 0.2)
	if player.position.y < fall_limit():
		player.position = respawn_point()
		player.velocity = Vector3.ZERO
	if dir.length() > 0.1:
		player.rotation.y = lerp_angle(player.rotation.y, atan2(dir.x, dir.z), minf(1.0, delta * 14.0))
	cam_zoom = lerpf(cam_zoom, cam_zoom_target, minf(1.0, delta * 10.0))
	if mg_active and mg_world:
		# 미니게임 자리로 카메라가 스르륵 다가가요
		cam.global_transform = cam.global_transform.interpolate_with(world_cam, minf(1.0, delta * 5.0))
	else:
		# 기본보다 가까이 당기면 카메라가 점점 낮아지며 앞을 바라봐요 (하늘이 보여요)
		var offs := CAM_OFFSET * cam_zoom
		var look_y := 1.3
		if cam_zoom < 1.0:
			var nk := clampf((cam_zoom - ZOOM_MIN) / (1.0 - ZOOM_MIN), 0.0, 1.0)
			nk = nk * nk * (3.0 - 2.0 * nk)
			offs = CAM_NEAR.lerp(CAM_OFFSET, nk)
			look_y = lerpf(2.6, 1.3, nk)
		if swimming:
			# 물속: 뒤에서 낮게 따라가며 앞을 바라봐요 (물 위로 튀어나가지 않게)
			offs = Vector3(0, 2.2, 7.0) * clampf(cam_zoom, 0.6, 1.4)
			look_y = 0.6
		cam.position = player.position + offs.rotated(Vector3.UP, cam_yaw)
		var gh := cam_ground(cam.position.x, cam.position.z)
		if cam.position.y < gh + 1.2:
			cam.position.y = gh + 1.2
		var ceil_y := cam_ceiling()
		if cam.position.y > ceil_y:
			cam.position.y = maxf(ceil_y, gh + 0.5)
		# 물속에서는 카메라가 부드럽게 따라와요 (출렁임 줄이기)
		if swimming and cam_smooth_ok:
			cam.position = cam_prev.lerp(cam.position, minf(1.0, delta * 6.0))
		cam_prev = cam.position
		cam_smooth_ok = true
		cam.look_at(player.position + Vector3(0, look_y, 0))
	if cam_kick > 0.01:
		cam.position -= cam.global_transform.basis.z * cam_kick * 0.5
		cam.position.y -= cam_kick * 0.15
		cam_kick = lerpf(cam_kick, 0.0, minf(1.0, delta * 14.0))

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
	turn_button.visible = false

# ---------- 장마다 덮어쓰는 훅 (빈 함수: 각 장 스크립트가 실제 내용을 채워요) ----------

# 맵과 마을을 지어요 (주인공과 화면을 만들기 전에 불려요)
func build_chapter() -> void:
	pass

# 화면 부품을 만든 뒤 물건을 흩어 놓는 등 마무리해요
func after_ui() -> void:
	pass

# 첫 이야기 카드를 보여 주며 장을 시작해요
func start_chapter() -> void:
	pass

# 흙길·마당 같은 땅 얼룩을 칠해요 (splat_stamp 로 splat_r, splat_g 에)
func paint_ground_splat() -> void:
	pass

# 숲 바닥처럼 땅을 살짝 짙게 할 곳 (0~1)
func splat_forest(_x: float, _z: float) -> float:
	return 0.0

# 이정표(다음 이야기로 가는 길)를 눌렀을 때
func on_gate() -> void:
	pass

# 카메라 자리의 땅 높이 (언덕이 있는 장은 덮어써서 카메라가 땅속에 묻히지 않게 해요)
func cam_ground(_x: float, _z: float) -> float:
	return -100.0

func make_world() -> void:
	pass

func make_village() -> void:
	pass

func herb_kinds_done() -> int:
	return 0

func pick_wild(t: Dictionary) -> void:
	pass

func read_story(i: int) -> void:
	pass

func scatter_items() -> void:
	pass

func story_count() -> int:
	return 0

func get_piece_id(id: int, extra: String) -> void:
	pass

func world_pose(delta: float) -> void:
	scene_pose()


func splash3d(pos: Vector3, big: bool = false) -> void:
	pass

func chips3d(pos: Vector3) -> void:
	pass

func wood_marker() -> float:
	return 0.0

func wood_zone() -> float:
	return 0.0

func update_wood3d(delta: float) -> void:
	pass

func wood_strike() -> void:
	pass

func update_well3d(delta: float) -> void:
	pass

func well_drag(dy: float, dt_ms: float) -> void:
	pass

func update_fish_world(delta: float) -> void:
	pass

func fish_leap(kind: int) -> void:
	pass

func draw_reel_meter(ci: CanvasItem) -> void:
	pass

func scene_setup(scene: String) -> void:
	pass

func plant_world_pos(row: int, col: int) -> Vector3:
	return Vector3.ZERO

func update_south(delta: float) -> void:
	pass

func farm_action_text() -> String:
	return ""


func load_south() -> void:
	pass


func fish_kinds_found() -> int:
	return 0

func start_fishing() -> void:
	pass

func fish_tap() -> void:
	pass

func update_fish(delta: float) -> void:
	pass

func draw_fish2d(ci: CanvasItem, c: Vector2, s: float, kind: int, rot: float, shadow: bool) -> void:
	pass

func draw_pond_scene(ci: CanvasItem) -> void:
	pass


func plant_slot(row: int, col: int) -> Vector2:
	return Vector2.ZERO

func plant_cursor_x() -> float:
	return 0.0

func plant_tap() -> void:
	pass

func update_plant(delta: float) -> void:
	pass

func draw_plant_scene(ci: CanvasItem) -> void:
	pass


func draw_sparrow2d(ci: CanvasItem, c: Vector2, s: float, danger: float, flap: float) -> void:
	pass

func draw_scarecrow2d(ci: CanvasItem, c: Vector2, s: float) -> void:
	pass

func draw_rice_field(ci: CanvasItem) -> void:
	pass

func farm_action() -> void:
	pass

func make_decor() -> void:
	pass

func make_forest() -> void:
	pass

func update_quest_text() -> void:
	pass

func talk_to(id: String) -> void:
	pass

func start_snake() -> void:
	pass

func start_saw() -> void:
	pass

func start_job(id: String) -> void:
	pass

func update_axe(delta: float) -> void:
	pass

func axe_tap() -> void:
	pass

func update_gam(delta: float) -> void:
	pass

func gam_tap(pos: Vector2) -> void:
	pass

# ---------- 글꼴 데이터 (주아체, SIL OFL 라이선스, 압축됨) ----------
const FONT_B64 := "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"
