extends Node3D

# 모든 장이 함께 쓰는 공통 부분: 주인공, 카메라, 화면, 대화, 미니게임 틀, 소리, 3D 부품.
# 장마다 다른 맵과 이야기는 chapter1.gd, chapter2.gd ... 가 이 파일을 이어받아 만들어요.


const SPEED := 6.0
var speed_boost := 0.0   # 남은 시간(초) 동안 빨라져요
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
	var org := Color(0.88, 0.45, 0.1)
	var stripe := Color(0.22, 0.12, 0.07)
	var fur := Color(1.0, 0.96, 0.9)
	var bean := Color(1.0, 0.55, 0.66)
	# 굵고 짧은 팔, 손목 쪽은 하얀 털
	var arm := [
		[Vector3(0, 1.2, -0.1), Vector3(0.86, 2.0, 0.72), org],
		[Vector3(0, 0.36, -0.02), Vector3(0.82, 0.5, 0.68), fur],
	]
	# 호랑이 줄무늬: 원판처럼 감지 않고, 보이는 쪽 겉에 양옆에서 들어오는 뾰족한 무늬로
	var bands := [[0.75, 0.0], [1.12, 0.06], [1.5, -0.04], [1.86, 0.05]]
	for band in bands:
		var y: float = band[0]
		var sh: float = band[1]
		for sx in [-1.0, 1.0]:
			arm.append([Vector3(sx * 0.24 + sh, y, 0.18), Vector3(0.36, 0.075, 0.16), stripe, Vector3(0, 0, sx * -22.0)])
	add_blobs(paw3d, arm)
	# 발: 하얀 털에 분홍 젤리. 광주리 쪽으로 손을 뻗어 움켜쥐려는 각도 (발바닥이 앞을 보며 살짝 이쪽으로)
	var hand := Node3D.new()
	paw3d.add_child(hand)
	hand.rotation = Vector3(0.5, 0.25, 0.0)
	var items := [
		[Vector3(0, 0, 0), Vector3(0.98, 0.82, 0.64), fur],
		[Vector3(0, 0.02, 0.3), Vector3(0.42, 0.32, 0.1), bean],
	]
	for k in 4:
		var x := -0.34 + k * 0.227
		var y := -0.36 - (0.04 if k == 1 or k == 2 else 0.0)
		items.append([Vector3(x, y, 0.04), Vector3(0.3, 0.32, 0.5), fur])
		items.append([Vector3(x, y - 0.03, 0.29), Vector3(0.15, 0.13, 0.08), bean])
	add_blobs(hand, items)
	paw3d_claws = Node3D.new()
	hand.add_child(paw3d_claws)
	var cl := []
	for k in 4:
		var x2 := -0.34 + k * 0.227
		cl.append([Vector3(x2, -0.58, 0.12), Vector3(0.07, 0.2, 0.07), Color(0.98, 0.97, 0.92)])
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

	ENDINGS = {}
	for t in ENDINGS_KO:
		var arr := []
		for e in ENDINGS_KO[t]:
			arr.append([e[0], tr(e[1]), tr(e[2]), tr(e[3])])
		ENDINGS[t] = arr
	migrate_save()
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
	start_weather()
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
	var from := take_entry()
	if from != "":
		arrive_from(from)
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
	# 살짝 처진 빨랫줄 (꼰 새끼줄)
	var st0 := MeshKit.begin()
	var sag := 0.06 * clampf(length / 3.0, 0.5, 2.0)
	for k in 12:
		var x0 := -length / 2.0 + length * k / 12.0
		var x1 := -length / 2.0 + length * (k + 1) / 12.0
		var y0 := -sag * (1.0 - pow(2.0 * x0 / length, 2.0))
		var y1 := -sag * (1.0 - pow(2.0 * x1 / length, 2.0))
		MeshKit.tube(st0, Vector3(x0, y0, 0), Vector3(x1, y1, 0), 0.014, 0.014, Color(0.74, 0.64, 0.45) if k % 2 == 0 else Color(0.66, 0.56, 0.38), 5)
	kit_instance(root, MeshKit.finish(st0))
	# 흰 보자기(줄에 걸쳐 앞뒤로 늘어짐), 옥색 저고리(어깨로 걸림, 소매 펼침), 분홍 치마(주름)
	var kinds := ["sheet", "jeogori", "chima"]
	var cols := [Color(0.97, 0.97, 0.94), Color(0.72, 0.86, 0.9), Color(0.98, 0.78, 0.8)]
	var xs := [-0.95, 0.0, 0.95]
	for k in 3:
		var cl := Node3D.new()
		var x: float = xs[k] * length / 3.0
		cl.position = Vector3(x, -sag * (1.0 - pow(2.0 * x / length, 2.0)), 0)
		root.add_child(cl)
		kit_instance(cl, laundry_mesh(kinds[k], cols[k], int(a.x * 7.0 + k)))
		sway_items.append([cl, cl.position, 1, xs[k] * 2.0 + a.x, 0.1])

# ---------- 천(빨래) 모양: 결이 진 얇은 천을 격자로 짓고 주름만큼 밀어내요 ----------
# o: 한쪽 모서리, du/dv: 두 변(길이 포함), nu/nv: 칸 수, foldf(u, v) -> 천 면에서 밀려나는 거리(u, v는 0~1)
# 접힌 골은 어둡게, 솟은 결은 밝게. 가장자리엔 박음질 단
func cloth_sheet(st: SurfaceTool, o: Vector3, du: Vector3, dv: Vector3, nu: int, nv: int, col: Color, foldf: Callable, hem: Color = Color(0, 0, 0, 0)) -> void:
	var nrm := du.cross(dv).normalized()
	var pts := []
	var cols := []
	for j in nv + 1:
		var row := []
		var crow := []
		for i in nu + 1:
			var u := float(i) / nu
			var v := float(j) / nv
			var f: float = foldf.call(u, v)
			row.append(o + du * u + dv * v + nrm * f)
			# 주름 음영: 옆 칸과의 높이 차로 골/결을 찾아요
			var fx: float = foldf.call(minf(u + 0.04, 1.0), v) - foldf.call(maxf(u - 0.04, 0.0), v)
			var c := col.darkened(clampf(fx * 9.0 + (0.08 if f < 0.0 else 0.0), -0.12, 0.32))
			if hem.a > 0.0 and (u < 0.035 or u > 0.965 or v > 0.965):
				c = hem
			crow.append(c)
		pts.append(row)
		cols.append(crow)
	for j in nv:
		for i in nu:
			MeshKit.quad(st, pts[j][i], pts[j][i + 1], pts[j + 1][i + 1], pts[j + 1][i], cols[j][i], cols[j][i + 1], cols[j + 1][i + 1], cols[j + 1][i])

# 빨랫줄에 걸린 빨래 (줄이 y=0, 아래로 늘어져요)
func laundry_mesh(kind: String, col: Color, seed_v: int) -> ArrayMesh:
	var key := "laundry_%s_%d" % [kind, seed_v % 3]
	if prop_mesh_cache.has(key):
		return prop_mesh_cache[key]
	var ph := float(seed_v % 3) * 1.7
	var st := MeshKit.begin()
	match kind:
		"sheet":
			# 줄에 반 접어 걸친 보자기: 앞자락 길고 뒷자락 짧게, 아래로 갈수록 물결
			var w := 0.74
			var front := func(u: float, v: float) -> float:
				return (0.035 * sin(u * 11.0 + ph) + 0.015 * sin(u * 23.0 + 1.0)) * pow(v, 1.2) + 0.012 * sin(v * 3.0)
			cloth_sheet(st, Vector3(-w / 2.0, 0, 0.012), Vector3(w, 0, 0), Vector3(0, -0.78, 0), 16, 10, col, front, col.darkened(0.08))
			var back := func(u: float, v: float) -> float:
				return -(0.03 * sin(u * 9.0 + ph + 2.0)) * v
			cloth_sheet(st, Vector3(-w / 2.0, 0, -0.012), Vector3(w, 0, 0), Vector3(0, -0.42, 0), 14, 6, col.darkened(0.05), back)
			# 줄 위로 둥글게 넘어가는 접힌 자리
			for k in 8:
				var x0 := -w / 2.0 + w * k / 8.0
				MeshKit.tube(st, Vector3(x0, 0.006, 0), Vector3(x0 + w / 8.0, 0.006, 0), 0.016, 0.016, col.lightened(0.05), 6)
			# 빨래집게 대신 묶은 끈
			for sx in [-0.3, 0.3]:
				MeshKit.tube(st, Vector3(sx, 0.03, 0), Vector3(sx, -0.05, 0.025), 0.008, 0.008, Color(0.6, 0.48, 0.3), 4)
		"jeogori":
			# 어깨를 줄에 걸친 저고리: 몸판, 양 소매(살짝 늘어짐), 흰 동정과 깃, 붉은 고름 두 가닥
			var body := func(u: float, v: float) -> float:
				return 0.02 * sin(u * 8.0 + ph) * v + 0.01 * sin(v * 9.0)
			cloth_sheet(st, Vector3(-0.22, -0.02, 0.012), Vector3(0.44, 0, 0), Vector3(0, -0.46, 0), 10, 10, col, body, col.darkened(0.12))
			cloth_sheet(st, Vector3(-0.22, -0.02, -0.01), Vector3(0.44, 0, 0), Vector3(0, -0.46, 0), 6, 6, col.darkened(0.1), func(u, v): return 0.0)
			for sx in [-1.0, 1.0]:
				# 소매: 어깨에서 밖으로, 끝으로 갈수록 처지고 소매 끝은 둥근 배래
				var sleeve := func(u: float, v: float) -> float:
					return 0.015 * sin(u * 7.0 + v * 3.0 + ph)
				var so := Vector3(sx * 0.2, -0.02, 0.008)
				var du := Vector3(sx * 0.36, -0.12, 0)
				var dv := Vector3(0, -0.24, 0)
				cloth_sheet(st, so, du, dv, 8, 5, col.lightened(0.04), sleeve, col.darkened(0.1))
				# 소매 끝동 (색 띠)
				cloth_sheet(st, so + du * 0.9 + Vector3(0, 0, 0.002), du * 0.1, dv, 2, 5, Color(0.55, 0.3, 0.45), func(u, v): return 0.0)
			# 깃과 흰 동정 (목 둘레에서 비스듬히 내려오는 띠)
			MeshKit.tube(st, Vector3(-0.08, -0.03, 0.028), Vector3(0.05, -0.2, 0.03), 0.018, 0.016, Color(0.98, 0.98, 0.95), 6)
			MeshKit.tube(st, Vector3(0.08, -0.03, 0.026), Vector3(0.0, -0.12, 0.028), 0.016, 0.014, Color(0.98, 0.98, 0.95), 6)
			# 고름: 매듭에서 늘어진 붉은 두 가닥
			var knot := Vector3(0.06, -0.22, 0.034)
			MeshKit.ball(st, knot, Vector3(0.018, 0.014, 0.01), Color(0.82, 0.18, 0.25), 6, 4)
			for g in 2:
				var a0 := knot
				for q in 4:
					var a1 := a0 + Vector3(0.01 + g * 0.012 + sin(q + ph) * 0.006, -0.05, 0.004)
					MeshKit.tube(st, a0, a1, 0.011, 0.011, Color(0.82, 0.18, 0.25), 4)
					a0 = a1
		"chima":
			# 허리말기를 줄에 걸친 치마: 아래로 넓어지고 세로 주름이 촘촘
			var top_w := 0.42
			var bot_w := 0.62
			var nu := 20
			var nv := 10
			var pts := []
			var cs := []
			for jv in nv + 1:
				var v := float(jv) / nv
				var row := []
				var crow := []
				var wv := lerpf(top_w, bot_w, v)
				for iu in nu + 1:
					var u := float(iu) / nu
					var pleat := sin(u * TAU * 7.0) * lerpf(0.012, 0.03, v) + sin(u * 5.0 + v * 2.0 + ph) * 0.02 * v
					row.append(Vector3((u - 0.5) * wv, -0.06 - v * 0.74, 0.012 + pleat))
					var c := col.darkened(clampf(-cos(u * TAU * 7.0) * 0.12, -0.06, 0.12))
					if v > 0.95:
						c = col.darkened(0.12)
					crow.append(c)
				pts.append(row)
				cs.append(crow)
			for jv in nv:
				for iu in nu:
					MeshKit.quad(st, pts[jv][iu], pts[jv][iu + 1], pts[jv + 1][iu + 1], pts[jv + 1][iu], cs[jv][iu], cs[jv][iu + 1], cs[jv + 1][iu + 1], cs[jv + 1][iu])
			# 흰 허리말기와 끈
			cloth_sheet(st, Vector3(-top_w / 2.0, 0.01, 0.016), Vector3(top_w, 0, 0), Vector3(0, -0.075, 0), 6, 2, Color(0.97, 0.96, 0.92), func(u, v): return 0.0)
			MeshKit.tube(st, Vector3(top_w / 2.0, -0.03, 0.02), Vector3(top_w / 2.0 + 0.05, -0.2, 0.03), 0.009, 0.008, Color(0.97, 0.96, 0.92), 4)
	var m := MeshKit.finish(st)
	prop_mesh_cache[key] = m
	return m

# 땅에 흩어진 빨래 더미: 구겨져 겹친 천 몇 장 + 개켜진 저고리 + 붉은 고름 (가운데가 (0,0,0), 땅 위)
func laundry_pile_mesh(seed_v: int) -> ArrayMesh:
	var key := "laundry_pile_%d" % (seed_v % 3)
	if prop_mesh_cache.has(key):
		return prop_mesh_cache[key]
	var r := RandomNumberGenerator.new()
	r.seed = 300 + seed_v % 3
	var st := MeshKit.begin()
	var cloth := [Color(0.88, 0.88, 0.84), Color(0.68, 0.8, 0.9), Color(0.92, 0.74, 0.74), Color(0.86, 0.8, 0.62)]
	for i in 4:
		var a := r.randf() * TAU
		# du × dv 가 위(+y)를 보게 (주름이 땅 위로 솟게)
		var du := Vector3(-sin(a), 0, cos(a)) * r.randf_range(0.5, 0.65)
		var dv := Vector3(cos(a), 0, sin(a)) * r.randf_range(0.7, 0.9)
		var o := Vector3(r.randf_range(-0.12, 0.12), 0.035 + i * 0.04, r.randf_range(-0.1, 0.1)) - (du + dv) / 2.0
		var p1 := r.randf() * TAU
		var p2 := r.randf() * TAU
		# 구겨진 천: 가운데가 불룩하고 이리저리 접힌 골, 가장자리는 땅에 처짐
		var crumple := func(u: float, v: float) -> float:
			var mid := sin(u * PI) * sin(v * PI)
			# 가장자리는 땅 쪽으로 처지되 땅 밑으로 꺼지지 않게
			var edge := minf(minf(u, 1.0 - u), minf(v, 1.0 - v))
			return mid * 0.1 + 0.03 * sin(u * 9.0 + p1) * sin(v * 7.0 + p2) * (0.4 + mid) + 0.015 * sin((u + v) * 13.0 + p1) - 0.03 * (1.0 - clampf(edge * 6.0, 0.0, 1.0)) + 0.01
		cloth_sheet(st, o, du, dv, 12, 10, cloth[i], crumple, cloth[i].darkened(0.1))
	# 비틀어 짠 빨래 뭉치 둘: 꼬인 주름이 진 굵은 천 타래
	for q in 2:
		var cc: Color = cloth[(q + 1) % 4]
		var a := r.randf() * TAU
		var dirv := Vector3(cos(a), 0, sin(a))
		var start := Vector3(r.randf_range(-0.15, 0.15), 0.2 + q * 0.03, r.randf_range(-0.12, 0.12)) - dirv * 0.22
		var rings := []
		for k in 11:
			var t := float(k) / 10.0
			var c := start + dirv * t * 0.44 + Vector3(0, sin(t * PI) * 0.05, 0) + dirv.cross(Vector3.UP) * sin(t * 4.0 + q) * 0.04
			var rad := 0.05 * (0.55 + 0.45 * sin(t * PI))
			rings.append([c, rad, rad * 0.8])
		var tw := float(q) * 1.3
		kit_loft(st, rings, dirv.cross(Vector3.UP).normalized(), Vector3.UP, 12, func(t: float, ang: float) -> Color:
			# 꼬인 결: 비스듬한 골이 진하게
			return cc.darkened(0.2) if sin(ang * 2.0 + t * 22.0 + tw) > 0.55 else cc.lightened(0.04 * sin(ang)))
	# 위에 반쯤 개켜진 저고리 (몸판, 접힌 소매, 흰 동정)
	var jo := Vector3(-0.18, 0.2, -0.14)
	var jcol := Color(0.66, 0.82, 0.8)
	cloth_sheet(st, jo, Vector3(0, 0.01, 0.32), Vector3(0.42, 0.02, 0), 6, 8, jcol, func(u, v): return 0.02 * sin(v * 6.0) * sin(u * PI), jcol.darkened(0.12))
	cloth_sheet(st, jo + Vector3(0.36, 0.03, 0.02), Vector3(-0.04, 0.01, 0.2), Vector3(0.28, -0.04, 0.1), 4, 6, jcol.lightened(0.02), func(u, v): return 0.015 * sin(u * PI))
	MeshKit.tube(st, jo + Vector3(0.08, 0.035, 0.02), jo + Vector3(0.2, 0.04, 0.25), 0.016, 0.014, Color(1, 1, 0.98), 6)
	# 붉은 고름 한 가닥 (구불구불)
	var g0 := jo + Vector3(0.24, 0.04, 0.22)
	for q in 5:
		var g1 := g0 + Vector3(0.06, -0.008, 0.03 * sin(q * 1.7))
		MeshKit.tube(st, g0, g1, 0.012, 0.012, Color(0.84, 0.2, 0.28), 4)
		g0 = g1
	var m := MeshKit.finish(st)
	prop_mesh_cache[key] = m
	return m

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
	# 좌판: 널빤지 여러 장을 이은 판, 판 아래 앞가림 널
	for k in 5:
		var pz := -0.48 + k * 0.24
		var pl := add_mbox(root, plank_mat, Vector3(4.0, 0.08, 0.22), Vector3(0, 0.92 + (k % 2) * 0.006, pz))
		pl.rotation.y = (k - 2) * 0.004
	add_mbox(root, dark_wood_mat, Vector3(3.9, 0.08, 0.08), Vector3(0, 0.84, 0.56))
	for k in 13:
		add_mbox(root, plank_mat, Vector3(0.28, 0.76, 0.05), Vector3(-1.8 + k * 0.3, 0.44, 0.52))
	add_mbox(root, dark_wood_mat, Vector3(3.9, 0.7, 0.9), Vector3(0, 0.42, -0.02))
	# 둥근 기둥 넷과 들보
	for sx in [-1.95, 1.95]:
		for sz in [-0.6, 1.6]:
			var h := 2.72 if sz < 0.0 else 2.38
			add_mcyl(root, dark_wood_mat, 0.065, 0.075, h, Vector3(sx, h / 2.0, sz))
	add_mcyl(root, dark_wood_mat, 0.055, 0.055, 4.1, Vector3(0, 2.7, -0.6)).rotation.z = PI / 2.0
	add_mcyl(root, dark_wood_mat, 0.055, 0.055, 4.1, Vector3(0, 2.36, 1.6)).rotation.z = PI / 2.0
	# 줄무늬 천 차양
	kit_instance(root, awning_mesh())
	# 바구니(엮은 결)와 과일, 옹기
	for i in 3:
		var bp := Vector3(-1.3 + i * 1.0, 0.96, 0.1)
		add_mcyl(root, basket_mat, 0.3, 0.22, 0.18, bp + Vector3(0, 0.09, 0))
		var rim := MeshInstance3D.new()
		var tor := TorusMesh.new()
		tor.inner_radius = 0.27
		tor.outer_radius = 0.33
		tor.rings = 24
		tor.ring_segments = 6
		rim.mesh = tor
		rim.material_override = basket_mat
		rim.position = bp + Vector3(0, 0.18, 0)
		root.add_child(rim)
	kit_instance(root, stall_goods_mesh())
	# 비단 두루마리 셋 (끝에 둥근 심)
	for i in 3:
		var col: Color = [Color(0.4, 0.6, 0.85), Color(0.95, 0.6, 0.7), Color(0.55, 0.8, 0.55)][i]
		var roll := add_mcyl(root, glossy_mat(col), 0.1, 0.1, 0.62, Vector3(1.55, 1.06, -0.25 + i * 0.22))
		roll.rotation.x = PI / 2.0
		var core := add_mcyl(root, dark_wood_mat, 0.035, 0.035, 0.72, Vector3(1.55, 1.06, -0.25 + i * 0.22))
		core.rotation.x = PI / 2.0

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
# save.cfg 안의 칸 (version 2, docs/world_plan.md 5장)
#   [world]  지금 있는 지역(chapter), 떠나온 지역(entry), 엽전(coins), version
#   [common] 모든 지역이 함께 쓰는 것: bag(가방), book(도감), endings(본 결말), tales_done(끝낸 이야기), roads_open(가 본 길)
#   [home]   집 마을 진행 / [ch1_state], [ch2_state] ...  장마다의 이야기 진행 (각 장 스크립트가 채워요)
#   예전(version 1) 칸 [world] has_*, [ch1], [ch3] 은 지우지 않고 남겨 두지만 더는 읽지 않아요
const SAVE_PATH := "user://save.cfg"
const SAVE_VERSION := 2
const TALE_IDS := ["ch1", "ch2", "ch3"]
const TALE_NAMES_KO := {"ch1": "흥부와 놀부", "ch2": "해와 달이 된 오누이", "ch3": "별주부전"}
var TALE_NAMES: Dictionary = trd(TALE_NAMES_KO)
const TALE_SHORT_KO := {"ch1": "흥부", "ch2": "해와 달", "ch3": "별주부"}
var TALE_SHORT: Dictionary = trd(TALE_SHORT_KO)
# 이야기마다의 결말: [id, 이름, 한 줄, 못 봤을 때 힌트]
const ENDINGS_KO := {
	"ch1": [
		["original", "권선징악", "놀부는 벌을 받고 흥부네 담장 밖을 오래 서성였어요.", "형님을 벌 받은 대로 두면 어떻게 될까?"],
		["awkward", "아직은 어색한 화해", "흥부는 형님을 모셨지만 마을 사람들은 아직 대문을 못 열었어요.", "형님과 함께 살자고 해 보렴. 마을 일은 조금 남겨 둔 채로."],
		["true", "함께 사는 집", "놀부가 마을 사람들에게 고개를 숙이고 함께 살게 되었어요.", "놀부를 도와주고, 마을 사람들 걱정을 모두 풀어 준 뒤에 함께 살자고 해 보렴."],
		["greed", "작은 놀부", "보물로 땅을 사던 흥부가 '작은 놀부'라고 불리게 되었어요.", "엽전을 아주 많이(80냥) 모은 채 마지막 한 줄을 쓰면 다른 길이 보인단다."],
	],
	"ch2": [
		["oppa_sun", "오빠는 해, 누이는 달", "오빠가 낮을, 누이가 밤길을 환하게 비추게 되었어요.", "하늘에 오를 때 누이의 물음에 오빠가 해가 되겠다고 해 보렴."],
		["nui_sun", "누이는 해, 오빠는 달", "밤이 무서운 누이가 해가 되어 눈부시게 빛나게 되었어요.", "하늘에 오를 때 밤을 무서워하는 누이에게 해를 양보해 보렴."],
		["mom_saved", "서낭당이 지킨 엄마", "서낭당 돌무더기 뒤에 숨었던 엄마가 살아 돌아와 해와 달이 된 오누이를 올려다봐요.", "고개마다 서낭당에 돌을 얹어 빌고, 셋째 고개에서 엄마와 함께 가겠다고 해 보렴."],
		["fight", "호랑이를 쫓아낸 밤", "솔방울과 횃불로 맞서 호랑이를 깊은 산으로 쫓아냈어요.", "솔방울로 호랑이를 막을 때 기회를 하나도 잃지 않으면, 다른 길이 열린단다."],
	],
	"ch3": [
		["ginseng", "산삼 한 뿌리", "자라에게 건넨 산삼으로 용왕님이 씻은 듯이 나으셨어요.", "토끼를 데려다주기 전에 뒷산 산삼을 캐 두었다가 자라에게 건네 보렴."],
		["plain", "꾀 많은 토끼", "토끼는 뒷산으로 달아나고 용왕님은 아직 앓아누워 계세요.", "산삼 없이 자라를 위로만 하고 끝내면 어떻게 될까?"],
		["late", "늦게 도착한 약", "늦게라도 구해 온 산삼으로 용왕님이 자리를 털고 일어나셨어요.", "위로만 하고 끝낸 뒤에, 뒷산 산삼을 다시 구해 자라에게 가져가 보렴."],
	],
}
var ENDINGS: Dictionary = {}
const CHAPTER_SCENES := {"ch1": "res://main.tscn", "ch2": "res://chapter2.tscn", "ch3": "res://chapter3.tscn", "home": "res://home.tscn"}
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

# 이 지역의 진행을 넣어 두는 저장 칸 이름 (집 마을은 [home])
func state_section() -> String:
	return chapter_id() + "_state"

# 다른 지역에서 걸어 들어왔을 때 설 자리 (from: 떠나온 지역). 각 지역이 덮어써요
func arrive_from(_from: String) -> void:
	pass

# 저장된 "떠나온 지역"을 한 번 꺼내고 지워요
func take_entry() -> String:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) != OK:
		return ""
	var e: String = cf.get_value("world", "entry", "")
	if e != "":
		cf.set_value("world", "entry", "")
		cf.save(SAVE_PATH)
	return e

func load_world() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) != OK:
		load_requests(cf)
		return
	coins = cf.get_value("world", "coins", 0)
	shown_coins = coins
	var bag: Dictionary = cf.get_value("common", "bag", {})
	has_yeot = bool(bag.get("yeot", false))
	has_shoes = bool(bag.get("shoes", false))
	has_sickle = bool(bag.get("sickle", false))
	has_hanbok = bool(bag.get("hanbok", false))
	load_book(cf)
	load_requests(cf)

# 도감(물고기, 약초, 이야기 조각)은 어느 지역에서든 같은 걸 보여요
# book: fish {id: 잡은 수}, herbs {id: 캔 수}, story {"ch1": [..]}, rewards {이름: true}
# (2026-11-25 이전 모양 ch1_fish/ch1_herbs/ch1_story 배열도 읽어요)
var book_rewards := {}

func load_book(cf: ConfigFile) -> void:
	var book: Dictionary = cf.get_value("common", "book", {})
	var fd: Dictionary = book.get("fish", {})
	if fd.is_empty():
		var got: Array = book.get("ch1_fish", [])
		for i in mini(got.size(), 6):
			fd[FISH[i]["id"]] = int(got[i])
	for i in FISH.size():
		fish_caught[i] = int(fd.get(FISH[i]["id"], 0))
	var hd: Dictionary = book.get("herbs", {})
	if hd.is_empty():
		var hg: Array = book.get("ch1_herbs", [])
		for i in mini(hg.size(), HERBS.size()):
			hd[HERBS[i]["id"]] = int(hg[i])
	for i in HERBS.size():
		herb_counts[i] = int(hd.get(HERBS[i]["id"], 0))
	var sd: Dictionary = book.get("story", {})
	var sr: Array = sd.get("ch1", book.get("ch1_story", []))
	for i in mini(sr.size(), story_read.size()):
		story_read[i] = bool(sr[i])
	for g in tale_read:
		var tr_arr: Array = sd.get(g, [])
		var flags: Array = tale_read[g]
		for i in mini(tr_arr.size(), flags.size()):
			flags[i] = bool(tr_arr[i])
	book_rewards = (book.get("rewards", {}) as Dictionary).duplicate()
	if bool(book.get("fish_reward", false)):
		book_rewards["fish_ch1_pond"] = true
	if bool(book.get("herb_reward", false)):
		book_rewards["herb_ch1"] = true
	fish_reward = book_rewards.has("fish_ch1_pond")
	herb_reward = book_rewards.has("herb_ch1")
	harvests = int(book.get("harvests", 0))

func save_book() -> void:
	var cf := ConfigFile.new()
	cf.load(SAVE_PATH)
	var book: Dictionary = cf.get_value("common", "book", {})
	var fd := {}
	for i in FISH.size():
		if int(fish_caught[i]) > 0:
			fd[FISH[i]["id"]] = int(fish_caught[i])
	var hd := {}
	for i in HERBS.size():
		if int(herb_counts[i]) > 0:
			hd[HERBS[i]["id"]] = int(herb_counts[i])
	var sd: Dictionary = book.get("story", {})
	sd["ch1"] = story_read.duplicate()
	for g in tale_read:
		sd[g] = (tale_read[g] as Array).duplicate()
	if fish_reward:
		book_rewards["fish_ch1_pond"] = true
	if herb_reward:
		book_rewards["herb_ch1"] = true
	book["fish"] = fd
	book["herbs"] = hd
	book["story"] = sd
	book["rewards"] = book_rewards
	book["fish_reward"] = fish_reward
	book["herb_reward"] = herb_reward
	book["harvests"] = harvests
	cf.set_value("common", "book", book)
	cf.save(SAVE_PATH)

# ---------- 결말 기록 (모든 이야기가 [common] endings 하나에) ----------

func ending_info(tale: String, id: String) -> Array:
	for e in ENDINGS.get(tale, []):
		if e[0] == id:
			return e
	return []

func endings_seen(tale: String) -> Array:
	var cf := ConfigFile.new()
	cf.load(SAVE_PATH)
	var all: Dictionary = cf.get_value("common", "endings", {})
	return (all.get(tale, []) as Array).duplicate()

func ending_total(tale: String) -> int:
	return (ENDINGS.get(tale, []) as Array).size()

# 결말을 기록하고, 그 이야기를 "끝낸 이야기"에 넣어요. 그 이야기에서 모은 결말 수를 돌려줘요
func record_ending(tale: String, id: String) -> int:
	var cf := ConfigFile.new()
	cf.load(SAVE_PATH)
	var all: Dictionary = cf.get_value("common", "endings", {})
	var got: Array = all.get(tale, [])
	if not got.has(id):
		got.append(id)
	all[tale] = got
	cf.set_value("common", "endings", all)
	var done: Array = cf.get_value("common", "tales_done", [])
	if not done.has(tale):
		done.append(tale)
	cf.set_value("common", "tales_done", done)
	cf.save(SAVE_PATH)
	refresh_roads()
	return got.size()

func tales_done_list() -> Array:
	var cf := ConfigFile.new()
	cf.load(SAVE_PATH)
	return cf.get_value("common", "tales_done", [])

# 모든 이야기를 통틀어 [본 결말 수, 전체 결말 수]
func endings_progress() -> Array:
	var cf := ConfigFile.new()
	cf.load(SAVE_PATH)
	var all: Dictionary = cf.get_value("common", "endings", {})
	var seen := 0
	var total := 0
	for t in TALE_IDS:
		var got: Array = all.get(t, [])
		for e in ENDINGS.get(t, []):
			total += 1
			if got.has(e[0]):
				seen += 1
	return [seen, total]

# ---------- 예전 저장(version 1)을 새 모양(version 2)으로 한 번만 옮겨요 ----------
# 예전 칸은 지우지 않아요. 테스트(tools/tests/save_migrate.gd)도 이 함수를 불러요
static func migrate_config(cf: ConfigFile) -> bool:
	if int(cf.get_value("world", "version", 0)) >= 2:
		return false
	if cf.get_sections().is_empty():
		return false
	var bag := {}
	for k in ["yeot", "shoes", "sickle", "hanbok"]:
		if bool(cf.get_value("world", "has_" + k, false)):
			bag[k] = true
	var book := {
		"ch1_fish": cf.get_value("ch1", "fish", []),
		"ch1_herbs": cf.get_value("ch1", "herbs", []),
		"ch1_story": cf.get_value("ch1", "story", []),
		"fish_reward": cf.get_value("ch1", "fish_reward", false),
		"herb_reward": cf.get_value("ch1", "herb_reward", false),
		"harvests": cf.get_value("ch1", "harvests", 0),
	}
	var c1: Dictionary = cf.get_value("ch1_state", "data", {})
	var c2: Dictionary = cf.get_value("ch2_state", "data", {})
	var c3: Dictionary = cf.get_value("ch3_state", "data", {})
	var endings := {}
	var e1: Array = (cf.get_value("ch1", "endings", []) as Array).duplicate()
	var id1 := str(c1.get("ending_id", ""))
	if id1 != "" and not e1.has(id1):
		e1.append(id1)
	if not e1.is_empty():
		endings["ch1"] = e1
	var id2 := str(c2.get("ending", ""))
	if id2 != "" and int(c2.get("quest", 0)) >= 10:
		endings["ch2"] = [id2]
	var e3: Array = (cf.get_value("ch3", "endings", []) as Array).duplicate()
	var id3 := str(c3.get("ending", ""))
	if id3 != "" and not e3.has(id3):
		e3.append(id3)
	if not e3.is_empty():
		endings["ch3"] = e3
	var done := []
	if endings.has("ch1") or int(c1.get("quest", 0)) >= 13:
		done.append("ch1")
	if int(c2.get("quest", 0)) >= 10:
		done.append("ch2")
	if endings.has("ch3"):
		done.append("ch3")
	var roads := ["home", "ch1"]
	for t in ["ch2", "ch3"]:
		if done.has(t) or cf.has_section(t + "_state"):
			roads.append(t)
	cf.set_value("common", "bag", bag)
	cf.set_value("common", "book", book)
	cf.set_value("common", "endings", endings)
	cf.set_value("common", "tales_done", done)
	cf.set_value("common", "roads_open", roads)
	var region := str(cf.get_value("world", "chapter", ""))
	if region != "":
		cf.set_value("world", "region", region)
	cf.set_value("world", "version", 2)
	return true

func migrate_save() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) != OK:
		return
	if migrate_config(cf):
		cf.save(SAVE_PATH)

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
	cf.set_value("world", "region", chapter_id())
	cf.set_value("world", "coins", coins)
	var bag: Dictionary = cf.get_value("common", "bag", {})
	bag["yeot"] = has_yeot
	bag["shoes"] = has_shoes
	bag["sickle"] = has_sickle
	bag["hanbok"] = has_hanbok
	cf.set_value("common", "bag", bag)
	var roads: Array = cf.get_value("common", "roads_open", [])
	if not roads.has(chapter_id()):
		roads.append(chapter_id())
		cf.set_value("common", "roads_open", roads)
	var st := chapter_state()
	if player != null:
		st["pos"] = player.position
		st["yaw"] = cam_yaw_target
	cf.set_value(state_section(), "data", st)
	cf.save(SAVE_PATH)
	save_timer = 0.0

# 저장된 진행이 있으면 되살리고 true
func restore_progress() -> bool:
	if has_hanbok and player_body != null:
		recolor_outfit(player_body, Color(0.45, 0.78, 0.72))
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) != OK:
		return false
	var st: Dictionary = cf.get_value(state_section(), "data", {})
	if st.is_empty():
		return false
	restore_chapter_state(st)
	var pos: Vector3 = st.get("pos", Vector3(0, -100, 0))
	if pos.y > -5.0:
		player.position = pos + Vector3(0, 0.3, 0)
		cam_yaw = st.get("yaw", 0.0)
		cam_yaw_target = cam_yaw
	return true

# ---------- 걸어서 오가기: 길 끝(나가는 곳)에 걸어 들어가면 다음 지역으로 ----------
# 지역마다 add_exit 로 길 끝을 정해요. 도착하자마자 다시 나가지지 않게, 한 번 길 끝에서 떨어져야 켜져요.
var exits: Array = []          # [{c: Vector2, r: float, to: String, mat: 재질}]
var exits_armed := false
var exit_msg_cool := 0.0
var exit_last_out := Vector3.ZERO
var roads_cache := {}          # 지역 id -> 열렸나

func add_exit(at: Vector3, r: float, to: String, label: String = "") -> void:
	# 길 끝: 기둥 대신 나뭇잎 사이로 비스듬히 내려오는 햇살 몇 줄기, 땅에 번진 따스한 빛, 떠오르는 빛 먼지
	var root := Node3D.new()
	root.position = at
	add_child(root)
	var rr := RandomNumberGenerator.new()
	rr.seed = int(at.x * 13.0 + at.z * 7.0)
	var shaft := make_sun_shafts(root, rr, 4, r * 0.75, 7.0, Vector2(0.7, 1.5))
	var glow := make_ground_glow(root, r * 1.5)
	var motes := make_motes(root, r * 0.7)
	if label != "":
		add_tag(root, label, 2.6)
	exits.append({"c": Vector2(at.x, at.z), "r": r, "to": to, "shaft": shaft, "glow": glow, "motes": motes, "node": root, "level": 0.0})

# 햇살 줄기: 모두 같은 쪽(해 쪽)에서 비스듬히 내려와 땅에 닿아요. 위아래로 스르르 사라지고 천천히 일렁여요
var sun_shaft_shader: Shader
func make_sun_shafts(parent: Node3D, rr: RandomNumberGenerator, count: int, spread: float, height: float, width: Vector2) -> ShaderMaterial:
	if sun_shaft_shader == null:
		sun_shaft_shader = Shader.new()
		sun_shaft_shader.code = """shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
uniform float strength = 0.0;
uniform vec3 tint : source_color = vec3(1.0, 0.9, 0.62);
void fragment() {
	float across = 1.0 - abs(UV.x * 2.0 - 1.0);
	across = across * across * (3.0 - 2.0 * across);
	float v = UV.y;
	float fade = smoothstep(0.0, 0.45, v) * (1.0 - smoothstep(0.9, 1.0, v));
	float bottom = mix(0.55, 1.0, v);
	float shimmer = 0.7 + 0.3 * sin(TIME * 0.9 + NODE_POSITION_WORLD.x * 0.6 + v * 5.0 + UV.x * 2.0);
	ALBEDO = tint;
	ALPHA = clamp(across * fade * bottom * shimmer * strength, 0.0, 1.0);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sun_shaft_shader
	var tilt := Basis.from_euler(Vector3(0.32, 0.6, 0.0))
	for i in count:
		var h := height * rr.randf_range(0.8, 1.1)
		var foot := Vector3(rr.randf_range(-spread, spread), 0.0, rr.randf_range(-spread, spread))
		var top := foot - tilt * Vector3(0, -h, 0)
		var holder := Node3D.new()
		holder.position = top
		holder.basis = tilt * Basis(Vector3.UP, rr.randf_range(-0.3, 0.3))
		parent.add_child(holder)
		var w := rr.randf_range(width.x, width.y)
		for q in 2:
			var mi := MeshInstance3D.new()
			var qm := QuadMesh.new()
			qm.size = Vector2(w, h)
			qm.center_offset = Vector3(0, -h / 2.0, 0)
			mi.mesh = qm
			mi.material_override = mat
			mi.rotation.y = q * PI / 2.0 + 0.4
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			holder.add_child(mi)
	return mat

# 땅에 번진 빛: 가장자리가 부드럽게 사라지는 둥근 빛 웅덩이 (고리 테두리 없이)
var ground_glow_shader: Shader
func make_ground_glow(parent: Node3D, radius: float) -> ShaderMaterial:
	if ground_glow_shader == null:
		ground_glow_shader = Shader.new()
		ground_glow_shader.code = """shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
uniform float strength = 0.0;
uniform vec3 tint : source_color = vec3(1.0, 0.88, 0.55);
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d = length(p);
	float a = pow(max(0.0, 1.0 - d), 2.0);
	float dapple = 0.8 + 0.2 * sin(p.x * 7.0 + TIME * 0.7) * sin(p.y * 6.0 - TIME * 0.5);
	ALBEDO = tint;
	ALPHA = clamp(a * dapple * strength, 0.0, 1.0);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = ground_glow_shader
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(radius * 2.0, radius * 2.0)
	mi.mesh = pm
	mi.material_override = mat
	mi.position.y = 0.07
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mat

# 햇살 속을 천천히 떠오르는 작은 빛 먼지
func make_motes(parent: Node3D, radius: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.07, 0.07)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_color = Color(1.0, 0.9, 0.6, 0.8)
	m.albedo_texture = soft_dot_tex()
	qm.material = m
	p.mesh = qm
	p.amount = 14
	p.lifetime = 4.5
	p.preprocess = 4.5
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radius
	p.direction = Vector3(0, 1, 0)
	p.spread = 25.0
	p.initial_velocity_min = 0.08
	p.initial_velocity_max = 0.22
	p.gravity = Vector3(0, 0.02, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0))
	curve.add_point(Vector2(0.3, 1))
	curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve
	p.position.y = 0.9
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	return p

var soft_dot_cache: Texture2D
func soft_dot_tex() -> Texture2D:
	if soft_dot_cache == null:
		var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
		for y in 32:
			for x in 32:
				var d := Vector2(x - 15.5, y - 15.5).length() / 16.0
				var a := clampf(1.0 - d, 0.0, 1.0)
				img.set_pixel(x, y, Color(1, 1, 1, a * a))
		soft_dot_cache = ImageTexture.create_from_image(img)
	return soft_dot_cache

# 이 길이 열렸나 (흥부네는 처음부터, 오누이는 흥부와 놀부를 끝내면, 바닷가는 오누이를 끝내면. 가 본 곳은 계속 열림)
func road_open(id: String) -> bool:
	if id == "home" or id == "ch1":
		return true
	if roads_cache.is_empty():
		refresh_roads()
	return bool(roads_cache.get(id, false))

func refresh_roads() -> void:
	var cf := ConfigFile.new()
	cf.load(SAVE_PATH)
	var done: Array = cf.get_value("common", "tales_done", [])
	var seen: Array = cf.get_value("common", "roads_open", [])
	roads_cache = {"home": true, "ch1": true,
		"ch2": done.has("ch1") or seen.has("ch2"),
		"ch3": done.has("ch2") or seen.has("ch3")}

func road_locked_text(id: String) -> String:
	match id:
		"ch2":
			return tr("오누이 고갯길로 가는 길은 아직 짙은 안개에 덮여 있어요.\n흥부와 놀부 이야기를 끝내면 길이 열려요.")
		"ch3":
			return tr("바닷가 마을로 가는 길은 아직 짙은 안개에 덮여 있어요.\n해와 달이 된 오누이 이야기를 끝내면 길이 열려요.")
	return tr("아직 이 길은 안개에 덮여 있어요. 언젠가 새 이야기가 열릴 곳이래요.")

# 지금은 떠날 수 없는 까닭 (빈 글이면 떠날 수 있어요). 각 지역이 덮어써요
func leave_blocked() -> String:
	return ""

# 지역 사이 길 이름 (전환 카드에 써요)
func road_card_text(to: String) -> String:
	var from := chapter_id()
	var pair := [from, to]
	pair.sort()
	match "%s-%s" % [pair[0], pair[1]]:
		"ch1-home":
			return tr("버드나무 길을 따라\n흥부네 마을로...") if to == "ch1" else tr("버드나무 길을 따라\n이야기골로...")
		"ch2-home":
			return tr("돌고개를 넘어\n오누이 고갯길로...") if to == "ch2" else tr("돌고개를 넘어\n이야기골로...")
		"ch3-home":
			return tr("갈대 나루에서 배를 타고\n바닷가 마을로...") if to == "ch3" else tr("갈대 나루로 배를 타고\n이야기골로...")
		"ch2-ch3":
			return tr("고갯마루 지름길로\n바닷가 마을로...") if to == "ch3" else tr("고갯마루 지름길로\n오누이 고갯길로...")
	return tr("책장을 넘기는 중...")

# 이정표 묻는 창에서 고른 길로 가요 (막힌 길이면 까닭을 말해요)
func try_go(id: String) -> void:
	if not road_open(id):
		say([["", road_locked_text(id)]], Callable())
		return
	go_to_chapter(id, road_card_text(id))

func update_exits(delta: float) -> void:
	if exits.is_empty() or leaving_scene:
		return
	exit_msg_cool = maxf(0.0, exit_msg_cool - delta)
	var p := Vector2(player.position.x, player.position.z)
	var inside := -1
	var near_any := false
	for i in exits.size():
		var e: Dictionary = exits[i]
		var d := p.distance_to(e["c"])
		var open := road_open(e["to"])
		var breathe := 0.85 + 0.15 * sin(anim_t * 0.8 + i * 1.7)
		# 해가 지면 햇살이 달빛처럼 푸르스름하고 옅어져요. 닫힌 길은 햇살 없이 옅은 안개빛만
		var night := 1.0 if is_night() else smoothstep(0.55, 0.9, time_of_day)
		var warm := Color(1.0, 0.88, 0.58).lerp(Color(0.7, 0.8, 1.0), night)
		var lv: float = (1.0 + float(e.get("boost", 0.0))) * (0.65 if weather == "rain" or weather == "fog" else 1.0)
		var sm: ShaderMaterial = e["shaft"]
		var gm: ShaderMaterial = e["glow"]
		sm.set_shader_parameter("tint", warm)
		gm.set_shader_parameter("tint", warm if open else Color(0.75, 0.8, 0.9))
		sm.set_shader_parameter("strength", (0.24 * breathe * lv * (1.0 - night * 0.4)) if open else 0.0)
		gm.set_shader_parameter("strength", (0.45 * breathe * lv) if open else 0.08)
		(e["motes"] as CPUParticles3D).emitting = open
		if d < float(e["r"]) + 1.0:
			near_any = true
		if d < float(e["r"]):
			inside = i
	if inside < 0:
		exit_last_out = player.position
	if not exits_armed:
		exits_armed = not near_any
		return
	if inside < 0 or is_busy():
		return
	var ex: Dictionary = exits[inside]
	var why := leave_blocked()
	if why == "" and not road_open(ex["to"]):
		why = road_locked_text(ex["to"])
	if why != "":
		# 길 끝에 들어오기 전 자리로 되돌리고 까닭을 말해요
		player.position = exit_last_out
		player.velocity = Vector3.ZERO
		if exit_msg_cool <= 0.0:
			exit_msg_cool = 3.0
			say([["", why]], Callable())
		return
	go_to_chapter(ex["to"], road_card_text(ex["to"]))

# 다른 장으로 옮겨 가요 (지금 장을 저장하고, 다음에 켜면 그 장에서 이어져요)
func go_to_chapter(id: String, card_text: String = "") -> void:
	if leaving_scene:
		return
	save_progress()
	var cf := ConfigFile.new()
	cf.load(SAVE_PATH)
	cf.set_value("world", "chapter", id)
	cf.set_value("world", "entry", chapter_id())
	cf.save(SAVE_PATH)
	leaving_scene = true
	# 다음 장을 짓는 동안 화면이 멈춰 보이지 않게, 두루마리를 먼저 펼쳐 둬요
	show_card(card_text if card_text != "" else tr("책장을 넘기는 중..."), 1.0, 30.0, Callable())
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
	if cf.has_section(state_section()):
		cf.erase_section(state_section())
	cf.save(SAVE_PATH)
	leaving_scene = true
	get_tree().change_scene_to_file(CHAPTER_SCENES[id])

func reset_progress() -> void:
	var cf := ConfigFile.new()
	cf.load(SAVE_PATH)
	for sec in cf.get_sections():
		if sec == "world" or sec == "home" or sec.ends_with("_state"):
			cf.erase_section(sec)
	# 가방은 비우고, 도감·결말·끝낸 이야기·가 본 길은 남겨요
	if cf.has_section_key("common", "bag"):
		cf.set_value("common", "bag", {})
	cf.set_value("world", "version", SAVE_VERSION)
	cf.save(SAVE_PATH)
	leaving_scene = true
	get_tree().change_scene_to_file(CHAPTER_SCENES["home"])

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
	wx_base = {"sun": sun_light.light_energy, "top": sky_mat_ref.sky_top_color, "hor": sky_mat_ref.sky_horizon_color,
		"ghor": sky_mat_ref.ground_horizon_color, "fogc": env_ref.fog_light_color, "amb": env_ref.ambient_light_energy}
	apply_weather_look()

# ---------- 날씨: 맑음, 구름, 비, 안개 ----------
# 지역에 들어올 때마다 날씨를 하나 골라요. 흥부네 마을과 이야기골에서는 몇 분마다 천천히 바뀌어요.
# 시간대(set_time_of_day)가 정한 빛과 하늘 위에 날씨를 덧입혀요.
const WEATHER_KINDS := {
	"clear": {"sun": 1.0, "gray": 0.0, "fog": 1.0, "rain": 0.0, "shadow": 0.85, "white": 0.0, "expo": 1.0},
	"cloudy": {"sun": 0.5, "gray": 0.6, "fog": 1.8, "rain": 0.0, "shadow": 0.45, "white": 0.0, "expo": 0.93},
	"rain": {"sun": 0.25, "gray": 0.9, "fog": 3.6, "rain": 1.0, "shadow": 0.25, "white": 0.0, "expo": 0.82},
	"mist": {"sun": 0.7, "gray": 0.35, "fog": 9.0, "rain": 0.0, "shadow": 0.55, "white": 0.7, "expo": 1.02},
}
const WEATHER_ODDS := [["clear", 0.45], ["cloudy", 0.25], ["rain", 0.2], ["mist", 0.1]]
const WEATHER_BLEND := 18.0      # 날씨가 바뀌는 데 걸리는 시간(초)
var weather := "clear"
var wx_from := {}
var wx_to := {}
var wx_k := 1.0
var wx_base := {}
var wx_fog0 := -1.0
var wx_timer := 0.0
var wx_apply_t := 0.0
var rain_fx: CPUParticles3D
var rain_player: AudioStreamPlayer

# 날씨가 저절로 바뀌어도 되는 지역인지 (바닷속처럼 빛을 따로 다루는 곳은 덮어써서 false)
func weather_can_change() -> bool:
	return true

# 지붕 아래·물속처럼 비를 맞지 않는 곳 (각 지역이 덮어써요)
func weather_sheltered() -> bool:
	return false

func roll_weather(avoid: String = "") -> String:
	var r := rng.randf()
	var acc := 0.0
	for wo in WEATHER_ODDS:
		acc += float(wo[1])
		if r <= acc:
			if wo[0] == avoid:
				return "clear" if avoid != "clear" else "cloudy"
			return wo[0]
	return "clear"

func start_weather() -> void:
	var r := RandomNumberGenerator.new()
	r.randomize()
	rng.seed = rng.seed ^ r.randi()
	weather = roll_weather()
	wx_to = WEATHER_KINDS[weather]
	wx_from = wx_to
	wx_k = 1.0
	wx_timer = rng.randf_range(240.0, 420.0)
	make_rain_fx()
	if tod_applied < 0.0:
		set_time_of_day(time_of_day)
	else:
		apply_weather_look()

func set_weather(kind: String, instant: bool = false) -> void:
	if not WEATHER_KINDS.has(kind):
		return
	wx_from = current_wx()
	weather = kind
	wx_to = WEATHER_KINDS[kind]
	wx_k = 1.0 if instant else 0.0
	apply_weather_look()

func current_wx() -> Dictionary:
	if wx_to.is_empty():
		return WEATHER_KINDS["clear"]
	var out := {}
	for key in wx_to:
		out[key] = lerpf(float(wx_from.get(key, 0.0)), float(wx_to[key]), smoothstep(0.0, 1.0, wx_k))
	return out

func apply_weather_look() -> void:
	if sun_light == null or wx_base.is_empty():
		return
	if wx_fog0 < 0.0:
		wx_fog0 = env_ref.fog_density
	var c := current_wx()
	var gray := float(c["gray"])
	var cloud := Color(0.58, 0.62, 0.68)
	sun_light.light_energy = float(wx_base["sun"]) * float(c["sun"])
	sun_light.shadow_opacity = float(c["shadow"])
	sky_mat_ref.sky_top_color = (wx_base["top"] as Color).lerp(cloud * (wx_base["top"] as Color).get_luminance() * 1.6, gray)
	sky_mat_ref.sky_horizon_color = (wx_base["hor"] as Color).lerp(Color(0.78, 0.8, 0.82) * clampf((wx_base["hor"] as Color).get_luminance() * 1.2, 0.0, 1.0), gray)
	sky_mat_ref.ground_horizon_color = (wx_base["ghor"] as Color).lerp(Color(0.66, 0.7, 0.72) * clampf((wx_base["ghor"] as Color).get_luminance() * 1.2, 0.0, 1.0), gray)
	env_ref.fog_density = wx_fog0 * float(c["fog"])
	env_ref.fog_light_color = (wx_base["fogc"] as Color).lerp(Color(0.9, 0.92, 0.94) * clampf((wx_base["fogc"] as Color).get_luminance() * 1.3, 0.0, 1.0), clampf(gray + float(c["white"]), 0.0, 1.0))
	env_ref.ambient_light_energy = float(wx_base["amb"]) * lerpf(1.0, 1.15, gray)
	env_ref.tonemap_exposure = 1.04 * float(c.get("expo", 1.0))
	env_ref.adjustment_saturation = 1.1 - gray * 0.25
	if star_node != null and star_node.visible:
		(star_node.material_override as StandardMaterial3D).albedo_color.a *= 1.0 - gray

func make_rain_fx() -> void:
	if rain_fx != null:
		return
	rain_fx = CPUParticles3D.new()
	rain_fx.amount = 420 if light_mode else 800
	rain_fx.lifetime = 0.9
	rain_fx.local_coords = false
	rain_fx.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	rain_fx.emission_box_extents = Vector3(11, 0.5, 11)
	rain_fx.direction = Vector3(0.08, -1, 0.05)
	rain_fx.spread = 2.0
	rain_fx.gravity = Vector3.ZERO
	rain_fx.initial_velocity_min = 13.0
	rain_fx.initial_velocity_max = 16.0
	var drop := BoxMesh.new()
	drop.size = Vector3(0.016, 0.6, 0.016)
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.albedo_color = Color(0.86, 0.91, 1.0, 0.42)
	drop.material = dm
	rain_fx.mesh = drop
	rain_fx.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rain_fx.emitting = false
	add_child(rain_fx)
	# 빗소리: 코드로 만든 쏴아 소리 (낮게 거른 잡음을 이어 붙여 반복)
	rain_player = AudioStreamPlayer.new()
	rain_player.stream = make_rain_sound()
	rain_player.volume_db = -80.0
	add_child(rain_player)

func make_rain_sound() -> AudioStreamWAV:
	var rate := 22050
	var n := rate * 2
	var data := PackedByteArray()
	data.resize(n * 2)
	var r := RandomNumberGenerator.new()
	r.seed = 99
	var lp := 0.0
	var lp2 := 0.0
	for i in n:
		var white := r.randf_range(-1.0, 1.0)
		lp += (white - lp) * 0.22
		lp2 += (lp - lp2) * 0.5
		# 가끔 굵은 빗방울 똑
		var drip := 0.0
		if r.randf() < 0.0009:
			drip = r.randf_range(0.3, 0.6)
		var v := clampf((lp2 * 0.9 + drip * white) * 0.55, -1.0, 1.0)
		# 이음매가 안 들리게 앞뒤를 살짝 줄여요
		var edge := minf(1.0, minf(float(i), float(n - i)) / 600.0)
		data.encode_s16(i * 2, int(v * edge * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_end = n
	return wav

func update_weather(delta: float) -> void:
	if wx_to.is_empty() or player == null:
		return
	if weather_can_change():
		wx_timer -= delta
		if wx_timer <= 0.0:
			wx_timer = rng.randf_range(240.0, 420.0)
			var nxt := roll_weather(weather)
			if nxt != weather:
				set_weather(nxt)
				var msg: String = {"clear": tr("구름이 걷히고 해가 났어요"), "cloudy": tr("하늘에 구름이 잔뜩 꼈어요"), "rain": tr("후드득, 비가 내리기 시작했어요"), "mist": tr("뽀얀 안개가 피어올라요")}[nxt]
				if not mg_active and not in_card:
					float_text(msg, get_viewport().get_visible_rect().size * Vector2(0.5, 0.3), Color(0.9, 0.95, 1.0), 1.0)
	if wx_k < 1.0:
		wx_k = minf(1.0, wx_k + delta / WEATHER_BLEND)
		wx_apply_t -= delta
		# 하늘을 다시 그리는 건 무거워서 0.4초마다만
		if wx_apply_t <= 0.0 or wx_k >= 1.0:
			wx_apply_t = 0.4
			apply_weather_look()
	var rain := float(current_wx()["rain"])
	var wet := rain > 0.05 and not weather_sheltered()
	if rain_fx != null:
		rain_fx.emitting = wet
		rain_fx.global_position = player.global_position + Vector3(0, 9.0, 0) + Vector3(player.velocity.x, 0, player.velocity.z) * 0.5
	if rain_player != null:
		var vol := -80.0
		if rain > 0.05 and sfx_on:
			vol = linear_to_db(rain * (0.35 if weather_sheltered() else 0.7))
		rain_player.volume_db = move_toward(rain_player.volume_db, vol, delta * 30.0)
		if vol > -60.0 and not rain_player.playing:
			rain_player.play()
		elif rain_player.volume_db <= -79.0 and rain_player.playing:
			rain_player.stop()

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
uniform float edge_scale = 1.0;
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
	// 가장자리가 반듯한 선이 되지 않게 잔물결처럼 들쭉날쭉
	float wob = texture(ripple, wp.xz * 0.11).g - 0.5;
	edge = clamp(edge * edge_scale + wob * 0.09 - 0.045, 0.0, 1.0);
	vec3 n1 = texture(ripple, wp.xz * 0.16 + TIME * flow).rgb;
	vec3 n2 = texture(ripple, wp.xz * 0.29 + vec2(TIME * 0.013, -TIME * 0.019) - TIME * flow * 0.6).rgb;
	NORMAL_MAP = normalize((n1 + n2) * 0.5);
	NORMAL_MAP_DEPTH = 0.7;
	vec3 col = mix(mix(shallow, deep, 0.75), deep, smoothstep(0.2, 0.6, edge));
	// 물가: 얕은 물 아래 젖은 흙이 비치는 빛깔로 (하얀 테두리 대신)
	vec3 bank = mix(deep, vec3(0.13, 0.14, 0.08), 0.7);
	col = mix(bank, col, smoothstep(0.02, 0.28, edge));
	// 물결이 닿는 곳에만 끊어진 거품이 살짝
	float wave = 0.6 + 0.4 * sin(TIME * 1.6 + wp.x * 1.7 + wp.z * 1.3);
	float lap = smoothstep(0.03, 0.08, edge) * smoothstep(0.16, 0.08, edge);
	float broken = smoothstep(0.52, 0.7, texture(ripple, wp.xz * 0.35 + vec2(TIME * 0.02, 0.0)).b);
	float foam = lap * broken * wave * foam_amt * 0.2;
	col = mix(col, vec3(0.9, 0.95, 0.97), foam);
	// 논물: 흙이 비치는 얼룩
	float blot = texture(ripple, wp.xz * 0.05).r;
	col = mix(col, col * (0.8 + blot * 0.4), mud);
	ALBEDO = col;
	// 물가 얕은 곳은 하늘을 덜 비춰요 (밝은 테두리가 생기지 않게)
	ROUGHNESS = mix(0.95, rough, smoothstep(0.12, 0.5, edge));
	SPECULAR = spec * smoothstep(0.12, 0.5, edge);
	//SOFT ALPHA = smoothstep(0.0, 0.16, edge) * 0.9 + smoothstep(0.16, 0.6, edge) * 0.1;
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

var water_shaders := {}

# soft: 물가로 갈수록 투명해져 땅과 스르르 섞여요 (넓은 바다 수면처럼 끝이 안 보여야 하는 곳은 false)
func water_material(shape: int, area: Vector4, deep: Color, shallow: Color, flow: Vector2 = Vector2(0.0, 0.0), foam: float = 0.7, soft: bool = true) -> ShaderMaterial:
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
	if not water_shaders.has(soft):
		var sh := Shader.new()
		sh.code = WATER_SHADER.replace("//SOFT ", "") if soft else WATER_SHADER
		if soft:
			sh.code = sh.code.replace("cull_disabled;", "cull_disabled, depth_draw_opaque;")
		water_shaders[soft] = sh
	var m := ShaderMaterial.new()
	m.shader = water_shaders[soft]
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

# 나무 모델의 잎 면 가운데 숨은 둥근 덩어리(그림 자리가 한 점이라 단색 공처럼 보임, 버드나무에 있었음)를 빼요.
# 잎 카드는 그림 자리가 넓으니 그대로 남아요.
func strip_leaf_blobs(mesh: Mesh) -> Mesh:
	var am := mesh as ArrayMesh
	if am == null:
		return mesh
	var out := ArrayMesh.new()
	var changed := false
	for i in am.get_surface_count():
		var mat := am.surface_get_material(i)
		var arr := am.surface_get_arrays(i)
		if mat != null and mat.resource_name == "Leaf" and arr[Mesh.ARRAY_INDEX] != null and arr[Mesh.ARRAY_TEX_UV] != null:
			var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
			var keep := PackedInt32Array()
			for t in range(0, idx.size(), 3):
				var a := uv[idx[t]]
				var b := uv[idx[t + 1]]
				var c := uv[idx[t + 2]]
				if a.distance_squared_to(b) < 1e-8 and a.distance_squared_to(c) < 1e-8:
					changed = true
					continue
				keep.append(idx[t])
				keep.append(idx[t + 1])
				keep.append(idx[t + 2])
			arr[Mesh.ARRAY_INDEX] = keep
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		out.surface_set_material(i, mat)
	return out if changed else mesh

func load_trees() -> void:
	tree_tried = true
	if not ResourceLoader.exists("res://models/trees.glb"):
		return
	var root: Node = (load("res://models/trees.glb") as PackedScene).instantiate()
	for node in root.find_children("*", "MeshInstance3D", true, false):
		tree_meshes[node.name] = strip_leaf_blobs((node as MeshInstance3D).mesh)
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
	"storyteller": {"scale": 1.1, "arm_down": 0.2},
	"tailor": {"scale": 1.2, "arm_down": 0.2},
	"herbalist": {"scale": 1.2, "arm_down": 0.2},
	"seafisher": {"scale": 1.25, "arm_down": 0.2},
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
	{"id": "ssuk", "place": "ch1", "name": tr("쑥"), "hint": tr("마을 길가"), "reward": 5, "spots": [Vector3(-5.6, 0, 16.5), Vector3(8.5, 0, 24.5)]},
	{"id": "naengi", "place": "ch1", "name": tr("냉이"), "hint": tr("논 근처"), "reward": 5, "spots": [Vector3(16.5, 0, 35.8), Vector3(31.2, 0, 36.2)]},
	{"id": "dallae", "place": "ch1", "name": tr("달래"), "hint": tr("개울가"), "reward": 6, "spots": [Vector3(-27.0, 0, -13.1), Vector3(12.0, 0, -13.2)]},
	{"id": "doraji", "place": "ch1", "name": tr("도라지"), "hint": tr("개울 건너 숲"), "reward": 8, "spots": [Vector3(-14.0, 0, -27.0), Vector3(10.0, 0, -26.0)]},
	{"id": "deodeok", "place": "ch1", "name": tr("더덕"), "hint": tr("깊은 숲 속"), "reward": 10, "spots": [Vector3(-33.0, 0, -31.0), Vector3(3.0, 0, -37.0)]},
	{"id": "sansam", "place": "ch1", "name": tr("산삼"), "hint": tr("아무도 안 가는 숲 구석"), "reward": 25, "spots": [Vector3(-36.5, 0, -36.5), Vector3(37.0, 0, -31.5)]},
	# 오누이 고갯길 (약초꾼 할아버지)
	{"id": "gosari", "place": "ch2", "name": tr("고사리"), "hint": tr("고갯길 길가"), "reward": 4, "spots": [Vector3(-12.5, 0, -3.5), Vector3(5.5, 0, -11.0), Vector3(-4.5, 0, 20.0)]},
	{"id": "chwi", "place": "ch2", "name": tr("취나물"), "hint": tr("수수밭 둑"), "reward": 6, "spots": [Vector3(15.0, 0, -59.0), Vector3(20.5, 0, -59.5)]},
	{"id": "omija", "place": "ch2", "name": tr("오미자"), "hint": tr("셋째 고개 덤불"), "reward": 8, "spots": [Vector3(-9.5, 0, -45.0), Vector3(-1.5, 0, -51.0)]},
	{"id": "chik", "place": "ch2", "name": tr("칡뿌리"), "hint": tr("첫째 고개 너머 언덕"), "reward": 10, "spots": [Vector3(-19.5, 0, -8.0), Vector3(12.5, 0, -15.5)]},
	{"id": "yeongji", "place": "ch2", "name": tr("영지버섯"), "hint": tr("비·안개 날 그루터기"), "only": ["rain", "mist"], "reward": 16, "spots": [Vector3(-22.0, 0, -5.0), Vector3(9.0, 0, -55.0)]},
	# 바닷가 마을 (해녀와 함께)
	{"id": "tot", "place": "ch3", "name": tr("톳"), "hint": tr("갯바위 아래 물가"), "reward": 4, "spots": [Vector3(-16.5, 0, -6.6), Vector3(-24.0, 0, -6.4), Vector3(12.0, 0, -6.2)]},
	{"id": "miyeok", "place": "ch3", "name": tr("미역"), "hint": tr("얕은 바닷속"), "reward": 6, "spots": [Vector3(-3.0, 0, -13.0), Vector3(6.0, 0, -15.5)]},
	{"id": "hamcho", "place": "ch3", "name": tr("함초"), "hint": tr("동쪽 갯벌"), "reward": 7, "spots": [Vector3(27.0, 0, -4.5), Vector3(31.5, 0, -2.5)]},
	{"id": "bangpung", "place": "ch3", "name": tr("갯방풍"), "hint": tr("모래 언덕"), "reward": 9, "spots": [Vector3(-8.0, 0, 6.0), Vector3(20.0, 0, 9.0)]},
	{"id": "haedang", "place": "ch3", "name": tr("해당화 열매"), "hint": tr("뒷산 길 · 맑은 날"), "only": ["clear"], "reward": 15, "spots": [Vector3(-20.0, 0, 20.0), Vector3(-30.0, 0, 40.0)]},
	# 이야기골
	{"id": "mindeulle", "place": "home", "name": tr("민들레"), "hint": tr("마을 길가"), "reward": 3, "spots": [Vector3(-6.0, 0, -12.0), Vector3(8.0, 0, -15.0), Vector3(-12.0, 0, 4.0)]},
	{"id": "jilgyeong", "place": "home", "name": tr("질경이"), "hint": tr("정자나무 아래"), "reward": 4, "spots": [Vector3(-5.0, 0, -6.5), Vector3(3.0, 0, -7.0)]},
	{"id": "jebikkot", "place": "home", "name": tr("제비꽃"), "hint": tr("할머니 집 울타리"), "reward": 6, "spots": [Vector3(13.5, 0, 5.5), Vector3(21.0, 0, 5.0)]},
	{"id": "nepip", "place": "home", "name": tr("네잎클로버"), "hint": tr("어딘가 풀밭 (아주 드묾)"), "reward": 20, "spots": [Vector3(-24.0, 0, 16.0), Vector3(26.0, 0, 20.0)]},
]
const HERB_NEED := 3
const HERB_REGROW := 180.0
var herb_counts: Array = zeros(HERBS.size())
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
const VILLAGES := ["ch1", "ch2", "ch3", "home"]
const VILLAGE_SHORT_KO := {"ch1": "흥부네", "ch2": "고갯길", "ch3": "바닷가", "home": "이야기골"}
var VILLAGE_SHORT: Dictionary = trd(VILLAGE_SHORT_KO)
var book_village := "ch1"
var village_row: Control
var village_buttons := {}

func herbs_in(v: String) -> Array:
	var out := []
	for i in HERBS.size():
		if HERBS[i]["place"] == v:
			out.append(i)
	return out

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
	var tx := 0.03
	for tab in [["fish", tr("물고기")], ["herb", tr("약초")], ["story", tr("이야기")], ["ending", tr("엔딩")], ["request", tr("부탁")]]:
		var b := Button.new()
		b.text = tab[1]
		b.clip_text = true
		page.add_child(b)
		place(b, tx, 0.09, tx + 0.178, 0.15)
		b.pressed.connect(func(): show_book(tab[0]))
		book_tabs[tab[0]] = b
		tx += 0.1885
	make_ending_page(page)
	make_request_page(page)
	# 물고기·약초 쪽: 마을 칸
	village_row = Control.new()
	page.add_child(village_row)
	place(village_row, 0.04, 0.165, 0.96, 0.215)
	var vx := 0.0
	for v in VILLAGES:
		var vb := Button.new()
		vb.clip_text = true
		village_row.add_child(vb)
		place(vb, vx, 0.0, vx + 0.235, 1.0)
		vb.pressed.connect(func():
			sfx("tap")
			book_village = v
			show_book(book_tab))
		village_buttons[v] = vb
		vx += 0.255
	# 이야기 탭: 조각 목록과 읽기 화면
	story_box = VBoxContainer.new()
	story_box.add_theme_constant_override("separation", 8)
	page.add_child(story_box)
	place(story_box, 0.05, 0.225, 0.95, 0.81)
	for i in STORY.size():
		var sb := Button.new()
		sb.alignment = HORIZONTAL_ALIGNMENT_LEFT
		sb.clip_text = true
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
	place(book_canvas, 0.03, 0.225, 0.97, 0.82)
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

func open_book(tab: String = "") -> void:
	if is_busy():
		return
	sfx("tap")
	book_open = true
	move_input = Vector2.ZERO
	book_overlay.visible = true
	if VILLAGES.has(chapter_id()):
		book_village = chapter_id()
	show_book(tab if tab != "" else book_tab)
	pop(book_overlay.get_child(0) as Control, 1.05)

func close_book() -> void:
	sfx("tap")
	book_open = false
	book_overlay.visible = false

func show_book(tab: String) -> void:
	book_tab = tab
	story_box.visible = tab == "story"
	story_reader.visible = false
	book_canvas.visible = tab != "story" and tab != "ending" and tab != "request"
	ending_page.visible = tab == "ending"
	request_page.visible = tab == "request"
	for key in book_tabs:
		var b: Button = book_tabs[key]
		var on: bool = key == tab
		skin_button(b, make_round(Color(0.95, 0.72, 0.3) if on else Color(0.9, 0.84, 0.7), font_size * 0.35), INK, 0.85)
	if tab == "request":
		book_title.text = tr("마을 사람 부탁 %d/%d") % [requests_done(), REQUESTS.size()]
		show_request_page()
		book_footer.text = tr("모은 물고기와 약초를 다른 마을 사람에게 가져다줘요.\n부탁한 사람에게 말을 걸면 드릴 수 있어요.")
	elif tab == "ending":
		var pr := endings_progress()
		book_title.text = tr("엔딩 모음 %d/%d (%d%%)") % [pr[0], pr[1], int(round(100.0 * pr[0] / maxf(1.0, pr[1])))]
		show_ending_tale(ending_tale)
		book_footer.text = tr("못 본 결말은 이야기골 할머니가 힌트를 들려줘요.")
	elif tab == "fish":
		var all_found := 0
		for i in FISH.size():
			if int(fish_caught[i]) > 0:
				all_found += 1
		book_title.text = tr("물고기 도감 %d/%d") % [all_found, FISH.size()]
		var here := fish_in(book_village)
		if here.is_empty():
			book_footer.text = tr("이 마을 물고기는 준비 중이에요.")
		elif fish_found_in(book_village) >= here.size():
			book_footer.text = tr("이 마을 물고기를 다 모았어요!")
		elif book_village == "ch1":
			book_footer.text = tr("남쪽 연못 나루터와 개울 여울에서 낚시해요.\n한 곳을 다 모으면 엽전 상!")
		else:
			book_footer.text = tr("카드 아래에 어디서, 언제 나오는지 적혀 있어요.")
	elif tab == "story":
		var all := tales_all_count()
		book_title.text = tr("이야기 조각 %d/%d") % [all[0], all[1]]
		var g := book_village
		var list := tale_list(g)
		var flags := tale_flags(g)
		for i in story_buttons.size():
			var sb: Button = story_buttons[i]
			sb.visible = i < list.size()
			if i >= list.size():
				continue
			if flags[i]:
				sb.text = "  %d. %s" % [i + 1, list[i]["title"]]
				skin_button(sb, make_round(Color(1.0, 0.95, 0.8), font_size * 0.3), INK, 0.8)
			else:
				sb.text = "  %d. ???   (%s)" % [i + 1, list[i]["hint"]]
				skin_button(sb, make_round(Color(0.88, 0.84, 0.76), font_size * 0.3), Color(0.5, 0.45, 0.4), 0.72)
		if list.is_empty():
			book_footer.text = tr("이 마을 이야기 조각은 준비 중이에요.")
		elif g == "ch1" and tale_count(g) >= list.size():
			book_footer.text = tr("일곱 조각이 하나로 이어졌어요. 놀부는 어떤 형이었을까요?")
		elif g == "ch1":
			book_footer.text = tr("찾은 조각을 누르면 다시 읽을 수 있어요.\n산신령에게서 받는 조각도 있어요.")
		elif tale_count(g) >= list.size():
			book_footer.text = tr("조각을 다 모았어요! 찾은 조각을 누르면 다시 읽어요.")
		else:
			book_footer.text = tr("빛나는 두루마리를 찾거나 부탁을 들어주면 모여요.\n다 모으면 숨은 이야기와 엽전 30냥!")
	else:
		book_title.text = tr("약초 도감 %d/%d") % [herb_kinds_done(), HERBS.size()]
		if herbs_in(book_village).is_empty():
			book_footer.text = tr("이 마을 약초는 준비 중이에요.")
		elif herb_done_in(book_village) >= herbs_in(book_village).size():
			book_footer.text = tr("이 마을 약초를 다 모았어요!")
		elif book_village == "ch2" or book_village == "ch3" or book_village == "home":
			book_footer.text = tr("종류마다 3번씩 캐면 도감에 올라가요.\n이 마을 것을 다 모으면 엽전 30냥!")
		else:
			book_footer.text = tr("종류마다 3번씩 캐면 도감에 올라가요.\n캔 자리는 3분 뒤 다시 자라요. 다 모으면 40냥!")
	village_row.visible = tab == "fish" or tab == "herb" or tab == "story"
	if village_row.visible:
		for v in VILLAGES:
			var vb: Button = village_buttons[v]
			var got := 0
			var tot := 0
			if tab == "story":
				tot = tale_list(v).size()
				got = tale_count(v)
				vb.text = "%s %d/%d" % [STORY_SHORT[v], got, tot] if tot > 0 else STORY_SHORT[v]
				skin_button(vb, make_round(Color(0.95, 0.72, 0.3) if v == book_village else Color(0.9, 0.84, 0.7), font_size * 0.3), INK, 0.55)
				continue
			if tab == "fish":
				tot = fish_in(v).size()
				got = fish_found_in(v)
			else:
				for i in herbs_in(v):
					tot += 1
					if int(herb_counts[i]) >= HERB_NEED:
						got += 1
			vb.text = "%s %d/%d" % [VILLAGE_SHORT[v], got, tot] if tot > 0 else VILLAGE_SHORT[v]
			skin_button(vb, make_round(Color(0.95, 0.72, 0.3) if v == book_village else Color(0.9, 0.84, 0.7), font_size * 0.3), INK, 0.55)
	book_canvas.queue_redraw()

# ---------- 약초 캐기 (모든 마을이 함께 써요: 자리 만들기, 모양, 캐기, 다시 자라기) ----------
func make_wild_spots(place: String) -> void:
	for k in HERBS.size():
		if HERBS[k]["place"] != place:
			continue
		for p in HERBS[k]["spots"]:
			var pos: Vector3 = p
			pos.y = cam_ground(pos.x, pos.z) if place != "ch1" and place != "home" else pos.y
			var n := make_spot(pos, "wild", str(k), "", true)
			add_tag(n, HERBS[k]["name"], 1.25)
			make_wild_visual(n, k)
			wild_spots.append([n, k, 0.0])

# 정해 둔 날씨에만 돋는 약초인가 (영지버섯: 비 오거나 안개 낀 날)
func herb_in_season(k: int) -> bool:
	var only: Array = HERBS[k].get("only", [])
	return only.is_empty() or only.has(weather)

func herb_done_in(place: String) -> int:
	var n := 0
	for i in herbs_in(place):
		if int(herb_counts[i]) >= HERB_NEED:
			n += 1
	return n

func make_wild_visual(n: Node3D, kind: int) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = herb_mesh(kind)
	mi.material_override = kit_material()
	mi.rotation.y = fposmod(n.position.x * 1.7 + n.position.z * 0.9, TAU)
	mi.scale = Vector3.ONE * 1.3
	n.add_child(mi)
	add_blobs(n, [[Vector3(0, 0.02, 0), Vector3(0.55, 0.1, 0.55), Color(0.45, 0.33, 0.22)]], null, true)

func update_wild(delta: float) -> void:
	for ws in wild_spots:
		var node: Node3D = ws[0]
		if not herb_in_season(int(ws[1])):
			node.visible = false
			continue
		if node.visible:
			continue
		ws[2] = float(ws[2]) - delta
		if float(ws[2]) <= 0.0:
			if node.has_meta("anchor"):
				node.position = random_near(node.get_meta("anchor"), SCATTER_HERB)
			node.visible = true
			pop3d(node, true)

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
		var place: String = HERBS[k]["place"]
		var here := herbs_in(place).size()
		lines.append(["", tr("%s을(를) %d번 모아 약초 도감에 올렸다! 장터에 팔아 엽전 %d냥. (약초 도감 %d/%d)") % [nm, HERB_NEED, rw, herb_done_in(place), here]])
		if place == "ch1" and herb_done_in(place) >= here and not herb_reward:
			herb_reward = true
			earn(40)
			lines.append(["", tr("약초 도감을 모두 채웠다! 마을 사람들이 고맙다며 엽전 40냥을 모아 주었다.")])
		elif place != "ch1" and herb_done_in(place) >= here and not book_rewards.has("herb_" + place):
			book_rewards["herb_" + place] = true
			earn(30)
			lines.append(["", herb_complete_line(place)])
	else:
		earn(1)
		lines.append(["", tr("%s을(를) 캐서 장터에 팔았다. 엽전 1냥.") % nm])
	save_book()
	say(lines, Callable())


func herb_complete_line(place: String) -> String:
	if place == "ch2":
		return tr("고갯길 약초 다섯 가지를 다 모았다! 약초꾼 할아버지가 엽전 30냥을 쥐여 주었다.")
	if place == "ch3":
		return tr("바닷가 약초 다섯 가지를 다 모았다! 해녀 아주머니가 엽전 30냥을 건네주었다.")
	if place == "home":
		return tr("이야기골 약초 네 가지를 다 모았다! 할머니가 엽전 30냥을 꺼내 주셨다.")
	return tr("이 마을 약초를 다 모았다! 엽전 30냥.")

func make_fish_world_parts() -> void:
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

func fish_world_hooked() -> void:
	if not mg_world:
		return
	w["jerk"] = 1.0
	cam_kick = 0.3
	hit_stop(0.05)
	splash3d(w["bob_at"], true)

func fish_weight(i: int) -> float:
	var f: Dictionary = FISH[i]
	var wx: Dictionary = f.get("wx", {})
	if bool(f.get("night_only", false)) and not is_night():
		return 0.0
	return float(f["w"]) * float(wx.get(weather, 1.0))

# 지금이 밤인가 (이야기골은 잠자리에서 밤까지 쉬면 밤이 돼요)
func is_night() -> bool:
	return false

# 뜰채 놀이 (이야기골이 덮어써요)
func update_net(_delta: float) -> void:
	pass

func pick_fish() -> int:
	var list := fish_in(fish_place)
	var total := 0.0
	for i in list:
		total += fish_weight(i)
	var roll := rng.randf() * total
	for i in list:
		roll -= fish_weight(i)
		if roll <= 0.0:
			return i
	return list[0]

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
	var here := fish_in(fish_place).size()
	if first:
		lines.append(["", tr("%s를 낚았다! 처음 보는 물고기다. (%s %d/%d)") % [f["name"], FISH_PLACES[fish_place], fish_kinds_found(), here]])
	else:
		lines.append(["", tr("%s를 낚았다! (%d마리째)") % [f["name"], fish_caught[fish_kind]]])
	lines.append(["", tr("장터에 팔아 엽전 %d냥을 받았다.") % pay])
	if fish_place == "ch1_pond" and fish_kinds_found() >= here and not fish_reward:
		fish_reward = true
		earn(50)
		lines.append([tr("강태공"), tr("허허! 여섯 가지 물고기를 다 낚았구나. 상으로 엽전 50냥을 주마!")])
	if fish_place == "home_pond" and fish_kinds_found() >= here and not book_rewards.has("fish_home_pond"):
		book_rewards["fish_home_pond"] = true
		earn(30)
		lines.append([tr("이야기꾼 할머니"), tr("어머나, 연못 식구를 다 떠 보았구나! 옛날 우리 오라버니도 못 한 일이란다. 30냥 받으렴.")])
	if fish_place == "ch3_rock" and fish_kinds_found() >= here and not book_rewards.has("fish_ch3_rock"):
		book_rewards["fish_ch3_rock"] = true
		earn(30)
		lines.append([tr("갯바위 어부"), tr("허허, 갯바위 물고기를 다 낚았구먼! 바다 사나이 다 됐네. 30냥 받게.")])
	if fish_place == "ch2_pool" and fish_kinds_found() >= here and not book_rewards.has("fish_ch2_pool"):
		book_rewards["fish_ch2_pool"] = true
		earn(30)
		lines.append([tr("약초꾼 할아버지"), tr("허허, 웅덩이 식구를 다 만나 봤구나! 내 약초 판 돈에서 30냥 떼어 주마.")])
	if fish_place == "ch1_creek" and fish_kinds_found() >= here and not book_rewards.has("fish_ch1_creek"):
		book_rewards["fish_ch1_creek"] = true
		earn(30)
		lines.append(["", tr("개울 여울 물고기 네 가지를 다 낚았다! 소문을 들은 강태공 할아버지가 엽전 30냥을 보내왔다.")])
	save_book()
	say(lines, Callable())

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

func draw_bobber(ci: CanvasItem, c: Vector2, s: float) -> void:
	d_line(ci, c + Vector2(0, -s * 1.3), c, Color(0.95, 0.4, 0.3), 4)
	d_ell(ci, c, s * 0.42, s * 0.55, Color(0.92, 0.25, 0.22), 0.0, 3.0)
	d_ell(ci, c + Vector2(0, s * 0.3), s * 0.42, s * 0.28, Color(1, 1, 0.97), 0.0, 2.0)

# ---------- 입체 물고기 (종류마다 몸 모양·무늬·지느러미가 달라요, meshkit.gd) ----------
const MeshKit = preload("res://meshkit.gd")
var fish_mesh_cache := {}
var kit_mat: StandardMaterial3D

func kit_material() -> StandardMaterial3D:
	if kit_mat == null:
		kit_mat = StandardMaterial3D.new()
		kit_mat.vertex_color_use_as_albedo = true
		kit_mat.roughness = 0.45
		kit_mat.metallic_specular = 0.55
		kit_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return kit_mat

func fish_node(k: int) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = fish_mesh(k)
	mi.material_override = kit_material()
	if FISH[k]["id"] == "moon_ingeo":
		var glow := kit_material().duplicate() as StandardMaterial3D
		glow.emission_enabled = true
		glow.emission = Color(0.55, 0.65, 0.95)
		glow.emission_energy_multiplier = 0.8
		mi.material_override = glow
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

func fish_hash(a: int, b: int) -> float:
	var v := sin(a * 12.9898 + b * 78.233) * 43758.5453
	return v - floorf(v)

func fish_mesh(k: int) -> ArrayMesh:
	if fish_mesh_cache.has(k):
		return fish_mesh_cache[k]
	var f: Dictionary = FISH[k]
	var st := MeshKit.begin()
	if f["id"] == "gajae":
		build_crayfish(st, f)
		var cm := MeshKit.finish(st)
		fish_mesh_cache[k] = cm
		return cm
	var id: String = f["id"]
	var col: Color = f["col"]
	var L: float = 0.5 * float(f["len"])
	var H: float = L * float(f["thin"]) * 0.95
	var roundish := id in ["megi", "mikkuraji", "dongjagae", "mangdungeo", "ureok"]
	var W: float = H * (0.75 if roundish else 0.45)
	var xs := -0.4 * L
	var B := 0.8 * L
	var back := col.darkened(0.35)
	var belly := col.lightened(0.5)
	var fin_col: Color = f.get("fin", col.darkened(0.12))
	var n := 12
	var m := 10
	var rings := []
	for i in n + 1:
		var t := float(i) / n
		var hp := pow(sin(PI * clampf(0.12 + 0.88 * t, 0.0, 0.97)), 0.65)
		var x := xs + t * B
		var yc := H * 0.06 * sin(PI * t)
		var ring := []
		for j in m:
			var a := TAU * j / m
			var sa := sin(a)
			var y := yc + 0.5 * H * hp * sa * (1.0 if sa > 0.0 else 0.85)
			var z := 0.5 * W * hp * cos(a)
			var c := belly.lerp(back, (sa + 1.0) * 0.5)
			if f.has("stripe") and absf(sa) < 0.3 and t > 0.12 and t < 0.88:
				c = f["stripe"]
			if f.has("bars") and t > 0.12 and t < 0.86 and fposmod(t * 4.5, 1.0) < 0.32 and sa > -0.7:
				c = f["bars"]
			if f.has("spots") and sa > -0.35 and fish_hash(i, j) < 0.22 and t > 0.1 and t < 0.85:
				c = f["spots"]
			ring.append([Vector3(x, y, z), c])
		rings.append(ring)
	for i in n:
		for j in m:
			var a0: Array = rings[i][j]
			var a1: Array = rings[i][(j + 1) % m]
			var b0: Array = rings[i + 1][j]
			var b1: Array = rings[i + 1][(j + 1) % m]
			MeshKit.quad(st, a0[0], b0[0], b1[0], a1[0], a0[1], b0[1], b1[1], a1[1])
	# 주둥이 끝
	var tip := Vector3(xs + B + 0.015 * L, H * 0.02, 0)
	for j in m:
		var r0: Array = rings[n][j]
		var r1: Array = rings[n][(j + 1) % m]
		MeshKit.tri(st, r0[0], tip, r1[0], r0[1], col, r1[1])
	# 꼬리지느러미 (갈라진 꼬리 / 둥근 꼬리)
	var tc := Vector3(xs + 0.02 * L, 0, 0)
	var tail_pts := []
	var round_tail := id in ["megi", "mikkuraji", "dongjagae", "mangdungeo", "sancheoneo", "yeolmogeo", "ureok"]
	for q in 9:
		var u := float(q) / 8.0
		var ang := lerpf(-1.0, 1.0, u)
		var reach := 0.24 * L
		if not round_tail:
			reach *= 0.62 + 0.55 * absf(ang)
		tail_pts.append(Vector3(xs - reach * (0.75 + 0.25 * cos(ang * 1.4)), ang * 0.42 * H + 0.0, 0))
	MeshKit.fan(st, tc, tail_pts, fin_col, fin_col.lightened(0.25))
	# 등지느러미
	var dorsal := []
	for q in 7:
		var u2 := float(q) / 6.0
		var t2 := lerpf(0.32, 0.72, u2)
		var hp2 := pow(sin(PI * (0.12 + 0.88 * t2)), 0.65)
		var top := 0.5 * H * hp2 + H * 0.06 * sin(PI * t2)
		dorsal.append(Vector3(xs + t2 * B, top + H * 0.32 * sin(PI * u2) * (1.0 - u2 * 0.4), 0))
	MeshKit.fan(st, Vector3(xs + 0.52 * B, 0.35 * H, 0), dorsal, fin_col, fin_col.lightened(0.2))
	# 가슴지느러미 (양옆)
	for sz in [-1.0, 1.0]:
		var pc := Vector3(xs + 0.72 * B, -0.12 * H, sz * W * 0.42)
		MeshKit.fan(st, pc, [pc + Vector3(-0.02 * L, 0.04 * H, 0), pc + Vector3(-0.13 * L, -0.08 * H, sz * W * 0.35), pc + Vector3(-0.08 * L, -0.2 * H, sz * W * 0.2)], fin_col, fin_col.lightened(0.2))
	# 눈 (흰자 + 검은 눈동자)
	var ex := xs + 0.86 * B
	var hpe := pow(sin(PI * (0.12 + 0.88 * 0.86)), 0.65)
	for sz in [-1.0, 1.0]:
		var ec := Vector3(ex, 0.12 * H, sz * W * 0.5 * hpe * 0.82)
		MeshKit.ball(st, ec, Vector3.ONE * H * 0.1, Color(0.97, 0.96, 0.92), 8, 5)
		MeshKit.ball(st, ec + Vector3(0.01 * L, 0.005 * H, sz * H * 0.05), Vector3.ONE * H * 0.065, Color(0.05, 0.05, 0.06), 6, 4)
	# 메기·동자개 수염
	if id in ["megi", "dongjagae"]:
		for sz in [-1.0, 1.0]:
			for q in 2:
				var a3 := tip + Vector3(-0.02 * L, -0.05 * H - q * 0.06 * H, sz * W * 0.2)
				MeshKit.tube(st, a3, a3 + Vector3(-0.05 * L, -0.12 * H, sz * (0.22 + q * 0.08) * L), 0.006, 0.003, back, 4)
	var mesh := MeshKit.finish(st)
	fish_mesh_cache[k] = mesh
	return mesh

func build_crayfish(st: SurfaceTool, f: Dictionary) -> void:
	var col: Color = f["col"]
	var dark := col.darkened(0.3)
	# 머리가슴 + 꼬리 마디 + 부채 꼬리
	MeshKit.ball(st, Vector3(0.05, 0.04, 0), Vector3(0.09, 0.05, 0.06), col, 10, 6)
	for q in 5:
		MeshKit.ball(st, Vector3(-0.06 - q * 0.04, 0.035 - q * 0.004, 0), Vector3(0.028, 0.035 - q * 0.003, 0.045 - q * 0.004), col.lightened(0.05 * (q % 2)), 8, 5)
	MeshKit.fan(st, Vector3(-0.25, 0.02, 0), [Vector3(-0.31, 0.02, -0.05), Vector3(-0.33, 0.02, 0.0), Vector3(-0.31, 0.02, 0.05)], dark, col)
	# 집게 다리 두 개
	for sz in [-1.0, 1.0]:
		var sh := Vector3(0.12, 0.03, sz * 0.04)
		var el := Vector3(0.19, 0.03, sz * 0.09)
		MeshKit.tube(st, sh, el, 0.012, 0.012, col, 5)
		MeshKit.ball(st, el + Vector3(0.05, 0.0, sz * 0.015), Vector3(0.05, 0.022, 0.028), col.darkened(0.1), 8, 5)
		MeshKit.ball(st, el + Vector3(0.1, 0.0, sz * 0.03), Vector3(0.025, 0.012, 0.012), dark, 6, 4)
		MeshKit.ball(st, el + Vector3(0.095, 0.0, sz * 0.005), Vector3(0.022, 0.01, 0.01), dark, 6, 4)
		# 걷는 다리 넷
		for q in 4:
			var lb := Vector3(0.06 - q * 0.035, 0.02, sz * 0.045)
			MeshKit.tube(st, lb, lb + Vector3(-0.01, -0.03, sz * 0.05), 0.005, 0.004, dark, 4)
		# 더듬이
		MeshKit.tube(st, Vector3(0.13, 0.05, sz * 0.02), Vector3(0.3, 0.07, sz * 0.12), 0.004, 0.002, dark, 4)
		# 눈
		MeshKit.ball(st, Vector3(0.13, 0.065, sz * 0.025), Vector3.ONE * 0.01, Color(0.05, 0.05, 0.05), 5, 4)

# ---------- 참새, 허수아비, 장터 물건 (meshkit.gd 로 짓는 입체 모양, 정점 색 하나의 재질) ----------
var prop_mesh_cache := {}

func kit_instance(parent: Node3D, mesh: Mesh, pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = kit_material()
	mi.position = pos
	parent.add_child(mi)
	return mi

# 고리(단면) 여러 개를 이어 한 덩어리 몸을 지어요. rings: [[가운데, 가로 반지름, 세로 반지름], ...]
# u, v: 단면을 펼치는 두 방향, colf(t, a) -> 색 (t: 0~1 고리 순서, a: 단면 각도), radf(t, a) -> 반지름 배율
func kit_loft(st: SurfaceTool, rings: Array, u: Vector3, v: Vector3, seg: int, colf: Callable, radf: Callable = Callable(), cap: bool = true) -> void:
	var pts := []
	var cols := []
	var n := rings.size()
	for i in n:
		var rg: Array = rings[i]
		var t := float(i) / float(n - 1)
		var row := []
		var crow := []
		for k in seg + 1:
			var a := TAU * k / seg
			var m := 1.0
			if radf.is_valid():
				m = float(radf.call(t, a))
			row.append((rg[0] as Vector3) + u * cos(a) * float(rg[1]) * m + v * sin(a) * float(rg[2]) * m)
			crow.append(colf.call(t, a))
		pts.append(row)
		cols.append(crow)
	for i in n - 1:
		for k in seg:
			MeshKit.quad(st, pts[i][k], pts[i + 1][k], pts[i + 1][k + 1], pts[i][k + 1], cols[i][k], cols[i + 1][k], cols[i + 1][k + 1], cols[i][k + 1])
	if cap:
		for e in [0, n - 1]:
			var c: Vector3 = (rings[e] as Array)[0]
			for k in seg:
				var col: Color = cols[e][k]
				if e == 0:
					MeshKit.tri(st, c, pts[e][k + 1], pts[e][k], col, col, col)
				else:
					MeshKit.tri(st, c, pts[e][k], pts[e][k + 1], col, col, col)

# 매끈한 몸 단면 표 [z(또는 y), 가운데 높이, 가로, 세로] 를 촘촘한 고리로 (캣멀-롬)
func smooth_rings(ctrl: Array, per: int, axis_z: bool) -> Array:
	var out := []
	for i in ctrl.size() - 1:
		var p0: Array = ctrl[maxi(i - 1, 0)]
		var p1: Array = ctrl[i]
		var p2: Array = ctrl[i + 1]
		var p3: Array = ctrl[mini(i + 2, ctrl.size() - 1)]
		for k in per:
			var t := float(k) / per
			var vals := []
			for j in 4:
				var a := float(p0[j])
				var b := float(p1[j])
				var c := float(p2[j])
				var d := float(p3[j])
				vals.append(0.5 * ((2.0 * b) + (-a + c) * t + (2.0 * a - 5.0 * b + 4.0 * c - d) * t * t + (-a + 3.0 * b - 3.0 * c + d) * t * t * t))
			var ctr := Vector3(0, vals[1], vals[0]) if axis_z else Vector3(0, vals[0], vals[1])
			out.append([ctr, vals[2], vals[3]])
	var last: Array = ctrl[ctrl.size() - 1]
	out.append([Vector3(0, last[1], last[0]) if axis_z else Vector3(0, last[0], last[1]), last[2], last[3]])
	return out

# 쓰러진 통나무: 울퉁불퉁 껍질 결이 진 줄기(x 방향, 길이 4.2), 잘린 면의 나이테, 부러진 가지 그루터기 몇 개, 이끼
func fallen_log_mesh() -> ArrayMesh:
	if prop_mesh_cache.has("fallen_log"):
		return prop_mesh_cache["fallen_log"]
	var st := MeshKit.begin()
	var bark := Color(0.36, 0.25, 0.16)
	var bark_dk := Color(0.2, 0.14, 0.09)
	var moss := Color(0.36, 0.5, 0.24)
	var rings := []
	var n := 16
	for i in n + 1:
		var t := float(i) / n
		var x := lerpf(-2.1, 2.1, t)
		var r := lerpf(0.25, 0.19, t) * (1.0 + 0.05 * sin(t * 17.0))
		rings.append([Vector3(x, r * 0.95 + 0.01 * sin(t * 9.0), 0.03 * sin(t * 5.0)), r, r * 0.95])
	var colf := func(t: float, a: float) -> Color:
		var up := sin(a)
		# 세로로 갈라진 껍질 결
		var c := bark_dk if sin(a * 11.0 + sin(t * 30.0) * 0.8) > 0.55 else bark.lerp(bark.lightened(0.12), clampf(up, 0.0, 1.0))
		if up > 0.8 and sin(t * 13.0) > 0.6:
			c = c.lerp(moss, 0.45)   # 위쪽에 이끼 조금
		return c
	kit_loft(st, rings, Vector3(0, 0, 1), Vector3(0, 1, 0), 16, colf, Callable(), false)
	# 잘린 면: 나이테
	for e in [0, n]:
		var rg: Array = rings[e]
		var c: Vector3 = rg[0]
		var rr: float = rg[1]
		var sgn := -1.0 if e == 0 else 1.0
		for ring in 4:
			var r0 := rr * ring / 4.0
			var r1 := rr * (ring + 1) / 4.0
			var col := Color(0.82, 0.66, 0.44) if ring % 2 == 0 else Color(0.72, 0.56, 0.36)
			if ring == 3:
				col = bark_dk
			for k in 16:
				var a0 := TAU * k / 16.0
				var a1 := TAU * (k + 1) / 16.0
				var p00 := c + Vector3(0, sin(a0) * r0 * 0.95, cos(a0) * r0)
				var p01 := c + Vector3(0, sin(a1) * r0 * 0.95, cos(a1) * r0)
				var p10 := c + Vector3(0, sin(a0) * r1 * 0.95, cos(a0) * r1)
				var p11 := c + Vector3(0, sin(a1) * r1 * 0.95, cos(a1) * r1)
				if sgn < 0.0:
					MeshKit.quad(st, p00, p10, p11, p01, col, col, col, col)
				else:
					MeshKit.quad(st, p00, p01, p11, p10, col, col, col, col)
	# 부러진 가지 그루터기
	for b in [[-1.1, 0.7, 0.4], [0.4, 1.9, -0.5], [1.4, 0.9, 0.6]]:
		var x := float(b[0])
		var a := float(b[1])
		var base := Vector3(x, 0.22, 0) + Vector3(0, sin(a), cos(a)) * 0.2
		var tip := base + Vector3(float(b[2]) * 0.2, sin(a), cos(a)) * 0.32
		MeshKit.tube(st, base, tip, 0.07, 0.045, bark, 8)
		MeshKit.ball(st, tip, Vector3(0.045, 0.045, 0.045), Color(0.78, 0.62, 0.4), 6, 4)
	var m := MeshKit.finish(st)
	prop_mesh_cache["fallen_log"] = m
	return m

# 짚신: 발 모양 바닥(씨줄로 촘촘히 엮은 결, 날줄 네 가닥), 앞코 매듭, 양옆 고리(총) 넷씩과 그 사이를 꿴 총갱기,
# 둥글게 세운 뒤축. 앞(+z)이 발끝, 길이 0.4, 가운데가 (0,0,0)
func jipsin_mesh() -> ArrayMesh:
	if prop_mesh_cache.has("jipsin"):
		return prop_mesh_cache["jipsin"]
	var st := MeshKit.begin()
	var straw := Color(0.88, 0.74, 0.45)
	var straw_dk := Color(0.66, 0.52, 0.3)
	var straw_lt := Color(0.95, 0.85, 0.58)
	# 발바닥 윤곽 [z, 가운데 높이, 반폭, 두께]
	var ctrl := [
		[-0.2, 0.012, 0.03, 0.012],
		[-0.185, 0.012, 0.062, 0.016],
		[-0.14, 0.012, 0.07, 0.017],
		[-0.06, 0.012, 0.064, 0.017],
		[0.02, 0.012, 0.078, 0.017],
		[0.1, 0.012, 0.086, 0.017],
		[0.16, 0.012, 0.072, 0.016],
		[0.19, 0.013, 0.045, 0.014],
		[0.205, 0.014, 0.012, 0.01],
	]
	var rings := smooth_rings(ctrl, 4, true)
	var colf := func(t: float, a: float) -> Color:
		var z := lerpf(-0.2, 0.205, t)
		var x := cos(a)
		# 날줄 네 가닥이 지나는 자리
		for wx in [-0.62, -0.2, 0.2, 0.62]:
			if absf(x - wx) < 0.07:
				return straw_dk
		# 씨줄: 가로로 촘촘히 엮인 짚, 한 줄씩 엇갈린 결
		var row := sin(z * 230.0)
		var off := sin(x * 18.0 + (PI if row > 0.0 else 0.0))
		var c: Color = straw_lt if off > 0.3 else straw
		if absf(row) < 0.25:
			c = straw_dk.lerp(straw, 0.4)
		return c
	kit_loft(st, rings, Vector3(1, 0, 0), Vector3(0, 1, 0), 18, colf)
	# 앞코: 날줄을 모아 묶은 작은 매듭과 발등으로 올라가는 앞총 끈
	MeshKit.ball(st, Vector3(0, 0.03, 0.19), Vector3(0.022, 0.018, 0.02), straw_dk, 8, 5)
	# 양옆 고리(총): 바닥 가장자리에서 솟은 작은 짚 고리 넷씩
	var rope_pts := {-1.0: [], 1.0: []}
	for sx in [-1.0, 1.0]:
		for k in 4:
			var z := lerpf(0.11, -0.1, k / 3.0)
			var half := 0.0
			for rg in rings:
				if absf((rg[0] as Vector3).z - z) < 0.012:
					half = float(rg[1])
			var base := Vector3(sx * (half - 0.004), 0.02, z)
			var top := base + Vector3(sx * -0.012, 0.045, 0)
			# 고리 = 짧은 두 기둥과 위쪽 반원
			var prev := base + Vector3(0, 0, 0.014)
			for q in 7:
				var a := PI * (q + 1) / 7.0
				var pt := base + Vector3(sx * -0.012 * sin(a), 0.045 * sin(a), 0.014 * cos(a))
				MeshKit.tube(st, prev, pt, 0.0045, 0.0045, straw_dk.lerp(straw, 0.5), 4)
				prev = pt
			rope_pts[sx].append(top)
	# 총갱기: 고리 끝을 꿰어 발등을 두르는 새끼줄 (앞코에서 시작해 양옆 고리, 뒤축까지)
	for sx in [-1.0, 1.0]:
		var pts: Array = [Vector3(0, 0.035, 0.18)] + rope_pts[sx] + [Vector3(sx * 0.045, 0.06, -0.17)]
		for k in pts.size() - 1:
			var a0: Vector3 = pts[k]
			var a1: Vector3 = pts[k + 1]
			var mid := (a0 + a1) / 2.0 + Vector3(sx * 0.004, 0.006, 0)
			MeshKit.tube(st, a0, mid, 0.0055, 0.0055, straw, 5)
			MeshKit.tube(st, mid, a1, 0.0055, 0.0055, straw.darkened(0.05), 5)
	# 뒤축: 발뒤꿈치를 감싸는 둥근 짚 둑 (여러 겹)
	for layer in 3:
		var y := 0.024 + layer * 0.014
		var prev2 := Vector3.ZERO
		for q in 11:
			var a := lerpf(-1.25, 1.25, q / 10.0)
			var pt := Vector3(sin(a) * 0.06, y, -0.17 - cos(a) * 0.022)
			if q > 0:
				MeshKit.tube(st, prev2, pt, 0.008, 0.008, straw if layer % 2 == 0 else straw_lt, 5)
			prev2 = pt
	# 삐져나온 짚 끝 몇 가닥
	var r := RandomNumberGenerator.new()
	r.seed = 12
	for k in 7:
		var sx := -1.0 if k % 2 == 0 else 1.0
		var z := r.randf_range(-0.16, 0.16)
		var b := Vector3(sx * 0.06, 0.015, z)
		MeshKit.tube(st, b, b + Vector3(sx * r.randf_range(0.015, 0.035), r.randf_range(-0.004, 0.01), r.randf_range(-0.015, 0.015)), 0.0025, 0.001, straw_lt, 3)
	var m := MeshKit.finish(st)
	prop_mesh_cache["jipsin"] = m
	return m

# 새끼줄: 두 가닥 짚을 꼬아 만든 줄 (z 방향, 0 에서 -length 까지)
func straw_rope_mesh(length: float) -> ArrayMesh:
	var key := "rope_%d" % int(length * 100.0)
	if prop_mesh_cache.has(key):
		return prop_mesh_cache[key]
	var st := MeshKit.begin()
	var n := int(length / 0.012)
	for strand in 2:
		var ph := PI * strand
		var col := Color(0.86, 0.72, 0.44) if strand == 0 else Color(0.78, 0.62, 0.36)
		var prev := Vector3.ZERO
		for k in n + 1:
			var z := -length * k / n
			var a := z * 70.0 + ph
			var pt := Vector3(cos(a) * 0.012, sin(a) * 0.012, z)
			if k > 0:
				MeshKit.tube(st, prev, pt, 0.011, 0.011, col.lightened(0.08 * sin(a)), 6)
			prev = pt
	# 끝에 풀린 짚 몇 가닥
	for k in 5:
		var a := k * TAU / 5.0
		MeshKit.tube(st, Vector3(0, 0, 0.0), Vector3(cos(a) * 0.02, sin(a) * 0.02, 0.03), 0.003, 0.0015, Color(0.92, 0.8, 0.5), 3)
	var m := MeshKit.finish(st)
	prop_mesh_cache[key] = m
	return m

# 제비: 매끈한 유선형 몸(남색 등, 흰 배, 붉은 이마와 멱), 긴 제비 꼬리(갈라진 두 가닥). 앞(+z), 가운데 (0,0,0)
func swallow_mesh() -> ArrayMesh:
	if prop_mesh_cache.has("swallow"):
		return prop_mesh_cache["swallow"]
	var st := MeshKit.begin()
	var ctrl := [
		[-0.16, 0.02, 0.01, 0.008],
		[-0.12, 0.012, 0.03, 0.026],
		[-0.05, 0.004, 0.052, 0.05],
		[0.03, 0.006, 0.058, 0.056],
		[0.09, 0.022, 0.046, 0.046],
		[0.12, 0.038, 0.04, 0.04],
		[0.155, 0.048, 0.042, 0.04],
		[0.19, 0.05, 0.032, 0.03],
		[0.21, 0.048, 0.012, 0.012],
	]
	var rings := smooth_rings(ctrl, 4, true)
	var navy := Color(0.14, 0.17, 0.36)
	var navy_hi := Color(0.24, 0.3, 0.55)
	var white := Color(0.97, 0.95, 0.9)
	var red := Color(0.78, 0.3, 0.2)
	var colf := func(t: float, a: float) -> Color:
		var z := lerpf(-0.16, 0.21, t)
		var up := sin(a)
		if z > 0.12:
			# 머리: 붉은 이마·멱, 위는 남색
			if up < -0.2 or (z > 0.18 and up < 0.5):
				return red
			return navy.lerp(navy_hi, clampf(up, 0.0, 1.0) * 0.6)
		if z > 0.09 and up < -0.35:
			return navy   # 가슴의 남색 띠
		if up < -0.15:
			return white
		return navy.lerp(navy_hi, clampf(up, 0.0, 1.0) * 0.5)
	kit_loft(st, rings, Vector3(1, 0, 0), Vector3(0, 1, 0), 20, colf)
	for sx in [-1.0, 1.0]:
		var ep := Vector3(sx * 0.034, 0.062, 0.17)
		MeshKit.ball(st, ep, Vector3(0.009, 0.01, 0.009), Color(0.04, 0.04, 0.05), 8, 6)
		MeshKit.ball(st, ep + Vector3(sx * 0.006, 0.004, 0.004), Vector3(0.003, 0.003, 0.003), Color(1, 1, 1), 4, 3)
		# 길게 갈라진 꼬리깃 (수평으로 V자)
		MeshKit.leaf(st, Vector3(sx * 0.008, 0.02, -0.14), Vector3(sx * 0.3, 0.05, -1.0), Vector3(1, 0, 0), 0.24, 0.035, navy, 0.0, "long")
		# 다리
		MeshKit.tube(st, Vector3(sx * 0.02, -0.04, 0.03), Vector3(sx * 0.024, -0.07, 0.045), 0.006, 0.005, Color(0.3, 0.2, 0.18), 4)
	# 작은 부리
	MeshKit.tube(st, Vector3(0, 0.044, 0.205), Vector3(0, 0.042, 0.232), 0.011, 0.002, Color(0.12, 0.1, 0.1), 6)
	var m := MeshKit.finish(st)
	prop_mesh_cache["swallow"] = m
	return m

# 제비 날개 한 짝: 어깨에서 뒤로 뻗은 길고 뾰족한 칼깃 날개 (side: +1 오른쪽, -1 왼쪽)
func swallow_wing_mesh(side: float) -> ArrayMesh:
	var key := "swallow_wing_%d" % int(side)
	if prop_mesh_cache.has(key):
		return prop_mesh_cache[key]
	var st := MeshKit.begin()
	var navy := Color(0.16, 0.19, 0.38)
	# 몸 옆에 접어 붙인 날개: 수평 깃 몇 장이 뒤로 길게 (끝이 꼬리 쪽으로 뾰족)
	for k in 4:
		MeshKit.leaf(st, Vector3(0, k * 0.004, 0.04 - k * 0.018), Vector3(side * 0.12, -0.02, -1.0), Vector3(1, 0, 0), 0.26 - k * 0.03, 0.06 - k * 0.008, navy.lightened(k * 0.05), 0.04, "long")
	var m := MeshKit.finish(st)
	prop_mesh_cache[key] = m
	return m

# 구렁이: 등뼈 점들을 따라 단면 고리를 이어 한 덩어리 몸으로. 납작하고 넓적한 머리, 가는 목, 통통한 몸통,
# 끝으로 가늘어지는 꼬리. 등은 누런 올리브색에 검은 가로띠, 배는 크림빛 비늘판. 눈과 날름거리는 혀
const SNAKE_RINGS := 30
const SNAKE_LEN := 1.25
const SNAKE_R := 1.45   # 굵기 배율
func snake_radius(t: float) -> float:
	# t: 0 주둥이 끝 → 1 꼬리 끝
	if t < 0.025:
		return lerpf(0.006, 0.03, sqrt(t / 0.025))
	if t < 0.07:
		return lerpf(0.03, 0.046, (t - 0.02) / 0.05)    # 넓적한 머리
	if t < 0.1:
		return lerpf(0.046, 0.032, (t - 0.07) / 0.03)    # 목
	if t < 0.35:
		return lerpf(0.032, 0.05, (t - 0.1) / 0.25)
	if t < 0.6:
		return 0.05
	return lerpf(0.05, 0.004, pow((t - 0.6) / 0.4, 1.3))

func snake_mesh(spine: Array, sd: float) -> ArrayMesh:
	var st := MeshKit.begin()
	var n := spine.size()
	var olive := Color(0.5, 0.46, 0.24)
	var olive_lt := Color(0.66, 0.6, 0.32)
	var band := Color(0.16, 0.14, 0.08)
	var belly := Color(0.9, 0.84, 0.6)
	var head_c := Color(0.42, 0.38, 0.2)
	var rings := []
	var us := []
	var vs := []
	var prev_side := Vector3(1, 0, 0)
	for i in n:
		var p: Vector3 = spine[i]
		var fwd: Vector3 = ((spine[maxi(i - 1, 0)] as Vector3) - (spine[mini(i + 1, n - 1)] as Vector3))
		fwd = fwd.normalized() if fwd.length() > 0.0001 else Vector3(0, 0, 1)
		var side := fwd.cross(Vector3.UP)
		if side.length() < 0.2:
			side = prev_side   # 기둥을 오를 때(위를 볼 때)
		side = side.normalized()
		if side.dot(prev_side) < 0.0 and i > 0:
			side = -side
		prev_side = side
		var up := side.cross(fwd).normalized()
		if up.y < 0.0 and absf(fwd.y) < 0.7:
			up = -up
			side = -side
		var t := float(i) / float(n - 1)
		var r := snake_radius(t) * SNAKE_R
		var flat := 0.72 if t < 0.08 else 0.86   # 머리는 더 납작, 몸도 배가 조금 납작
		rings.append([p, r, r * flat])
		us.append(side)
		vs.append(up)
	# 고리마다 방향이 달라서 kit_loft 대신 여기서 직접 이어요
	var seg := 12
	var pts := []
	var cols := []
	for i in n:
		var t := float(i) / float(n - 1)
		var d := t * SNAKE_LEN
		var row := []
		var crow := []
		for k in seg + 1:
			var a := TAU * k / seg
			var c: Vector3 = rings[i][0]
			var off: Vector3 = (us[i] as Vector3) * cos(a) * float(rings[i][1]) + (vs[i] as Vector3) * sin(a) * float(rings[i][2])
			# 배는 납작하게
			if sin(a) < -0.3:
				off -= (vs[i] as Vector3) * (sin(a) + 0.3) * float(rings[i][2]) * 0.35
			row.append(c + off)
			var upv := sin(a)
			var col: Color
			if upv < -0.5:
				# 배 비늘판: 가로로 한 칸씩 살짝 진하게
				col = belly if (i % 2 == 0) else belly.darkened(0.08)
			elif t < 0.09:
				# 머리: 위는 짙고 입술 쪽은 밝게
				col = head_c if upv > -0.1 else olive_lt.lerp(belly, 0.5)
				if t > 0.055 and upv > 0.2:
					col = head_c.darkened(0.25)   # 뒤통수 무늬
			else:
				var bandv := sin(d * 34.0 + sd)
				var dorsal := olive.lerp(olive_lt, clampf(-upv * 1.2 + 0.2, 0.0, 1.0))
				col = band if (bandv > 0.62 and upv > -0.35) else dorsal
				# 비늘 결: 촘촘한 마름모 음영
				if sin(d * 160.0 + a * 6.0) > 0.7:
					col = col.darkened(0.12)
			crow.append(col)
		pts.append(row)
		cols.append(crow)
	for i in n - 1:
		for k in seg:
			MeshKit.quad(st, pts[i][k], pts[i + 1][k], pts[i + 1][k + 1], pts[i][k + 1], cols[i][k], cols[i + 1][k], cols[i + 1][k + 1], cols[i][k + 1])
	# 주둥이 끝 막기
	for k in seg:
		MeshKit.tri(st, rings[0][0], pts[0][k + 1], pts[0][k], cols[0][k], cols[0][k], cols[0][k])
	# 눈: 머리 양옆 위쪽, 노란 눈에 세로 동공
	var hi := 2
	var hc: Vector3 = rings[hi][0]
	var hu: Vector3 = us[hi]
	var hv: Vector3 = vs[hi]
	var hf: Vector3 = ((spine[0] as Vector3) - (spine[4] as Vector3)).normalized()
	for sx in [-1.0, 1.0]:
		var ep: Vector3 = hc + hu * sx * float(rings[hi][1]) * 0.82 + hv * float(rings[hi][2]) * 0.45
		var eb := Basis(hu, hv, hf)
		MeshKit.ball(st, ep, Vector3(0.0135, 0.0135, 0.0135), Color(0.85, 0.7, 0.2), 8, 6, eb)
		MeshKit.ball(st, ep + hu * sx * 0.011, Vector3(0.006, 0.013, 0.006), Color(0.05, 0.04, 0.03), 6, 4, eb)
		MeshKit.ball(st, ep + hu * sx * 0.014 + hv * 0.006, Vector3(0.003, 0.003, 0.003), Color(1, 1, 1), 4, 3)
	# 날름거리는 갈라진 혀
	var flick := sin(anim_t * 14.0 + sd)
	if flick > 0.2:
		var tip0: Vector3 = (spine[0] as Vector3) - hv * 0.006
		var tl := 0.07 * (flick - 0.2) / 0.8
		var mid: Vector3 = tip0 + hf * tl
		var tongue := Color(0.75, 0.12, 0.15)
		MeshKit.tube(st, tip0, mid, 0.003, 0.0025, tongue, 4)
		for sx in [-1.0, 1.0]:
			MeshKit.tube(st, mid, mid + hf * 0.018 + hu * sx * 0.01, 0.0025, 0.001, tongue, 4)
	return MeshKit.finish(st)

# 밥풀: 찰기 있는 쌀알 여러 톨이 서로 붙은 작은 덩이. 쌀알 하나하나가 길쭉한 낟알 모양(한쪽에 씨눈 자국)
# 반들반들 반투명한 흰빛. variant 마다 붙은 모양이 달라요
func rice_clump_mesh(variant: int) -> ArrayMesh:
	var key := "rice_clump%d" % variant
	if prop_mesh_cache.has(key):
		return prop_mesh_cache[key]
	var st := MeshKit.begin()
	var r := RandomNumberGenerator.new()
	r.seed = 77 + variant * 13
	# 낟알들이 비슷한 방향으로 나란히 기대어 붙은 작은 덩이 (두 층)
	var main_dir := Vector3(r.randf_range(-1, 1), r.randf_range(-0.4, 0.4), r.randf_range(-1, 1)).normalized()
	var across := main_dir.cross(Vector3.UP).normalized()
	var count := 5 + variant % 3
	for g in count:
		var row := g % 3
		var layer := g / 3
		var c := across * (float(row) - 1.0) * 0.027 + Vector3.UP * float(layer) * 0.022 \
			+ main_dir * r.randf_range(-0.02, 0.02) + across * float(layer) * 0.013
		var dir := main_dir.rotated(Vector3.UP, r.randf_range(-0.6, 0.6)).rotated(across, r.randf_range(-0.35, 0.35)).normalized()
		var side := dir.cross(Vector3.UP).normalized()
		var up := side.cross(dir).normalized()
		# 낟알마다 길이 축으로 조금씩 돌려서 납작한 면이 제각각
		var roll := r.randf_range(-0.8, 0.8)
		var side2 := side.rotated(dir, roll)
		var up2 := up.rotated(dir, roll)
		rice_grain(st, c, dir, side2, up2, r.randf_range(0.92, 1.08), r.randf())
	var m := MeshKit.finish(st)
	prop_mesh_cache[key] = m
	return m

func rice_grain(st: SurfaceTool, c: Vector3, dir: Vector3, side: Vector3, up: Vector3, size: float, shade: float) -> void:
	var L := 0.064 * size      # 낟알 길이 (짧고 통통한 멥쌀 밥알)
	var W := 0.027 * size
	var H := 0.022 * size
	var white := Color(0.93, 0.92, 0.88).lerp(Color(0.88, 0.87, 0.8), shade * 0.6)
	var glow := Color(1.0, 1.0, 0.98)
	var rings := []
	var nr := 15
	for i in nr:
		var t := float(i) / float(nr - 1)
		# 끝은 둥글고 가운데가 통통한 낟알
		# 끝이 뭉툭하게 둥근 통통한 낟알 (초타원 단면 윤곽)
		var e := absf(2.0 * t - 1.0)
		var prof := pow(maxf(1.0 - pow(e, 2.6), 0.0), 0.42)
		prof = maxf(prof, 0.12)
		# 살짝 휜 낟알
		rings.append([c + dir * (t - 0.5) * L + up * sin(PI * t) * L * 0.06, W * 0.5 * prof, H * 0.5 * prof])
	var colf := func(t: float, a: float) -> Color:
		# 가장자리는 살짝 어둡고 투명한 듯, 등은 반들반들 밝게
		var col := white.lerp(glow, clampf(sin(a) * 0.7, 0.0, 1.0)).darkened(0.16 * (1.0 - absf(sin(a))))
		# 끝은 조금 더 투명한 회백색
		if t < 0.1 or t > 0.9:
			col = col.lerp(Color(0.84, 0.85, 0.82), 0.4)
		# 씨눈 자국: 한쪽 끝 옆에 살짝 오목한 크림색
		if t > 0.1 and t < 0.24 and cos(a) > 0.55:
			col = Color(0.9, 0.87, 0.76)
		# 길이 방향 옅은 골
		if absf(cos(a)) < 0.12:
			col = col.darkened(0.05)
		return col
	var radf := func(t: float, a: float) -> float:
		var m := 1.0
		if t > 0.1 and t < 0.24 and cos(a) > 0.55:
			m = 0.86   # 씨눈 자리 오목
		return m
	kit_loft(st, rings, side, up, 14, colf, radf)

# 밥주걱: 넓적한 타원 머리가 살짝 오목하고 손잡이로 가늘어지는 나무 주걱 (나뭇결 무늬, 밥풀 몇 톨 묻음)
func paddle_mesh() -> ArrayMesh:
	if prop_mesh_cache.has("paddle"):
		return prop_mesh_cache["paddle"]
	var st := MeshKit.begin()
	# [y, 가운데 z, 가로 반지름, 두께 반지름]
	var ctrl := [
		[0.2, 0.0, 0.01, 0.006],
		[0.18, 0.004, 0.085, 0.012],
		[0.12, 0.008, 0.11, 0.014],
		[0.04, 0.006, 0.105, 0.015],
		[-0.03, 0.002, 0.07, 0.015],
		[-0.07, 0.0, 0.035, 0.016],
		[-0.12, 0.0, 0.026, 0.017],
		[-0.38, 0.0, 0.024, 0.018],
		[-0.41, 0.0, 0.02, 0.016],
		[-0.42, 0.0, 0.004, 0.004],
	]
	var rings := smooth_rings(ctrl, 4, false)
	var wood := Color(0.82, 0.63, 0.38)
	var grain := Color(0.66, 0.46, 0.25)
	var colf := func(t: float, a: float) -> Color:
		var y := lerpf(0.2, -0.42, t)
		var gx := cos(a)
		var col := wood.lerp(wood.lightened(0.12), clampf(sin(a), 0.0, 1.0))
		if sin(y * 70.0 + gx * 9.0 + sin(y * 15.0) * 2.0) > 0.75:
			col = grain
		if y < -0.36:
			col = col.darkened(0.15)   # 손때 묻은 손잡이 끝
		return col
	# 앞면이 살짝 오목하게 (가운데를 조금 들여요)
	var radf := func(t: float, a: float) -> float:
		if t < 0.45 and sin(a) > 0.5:
			return 0.55
		return 1.0
	kit_loft(st, rings, Vector3(1, 0, 0), Vector3(0, 0, 1), 16, colf, radf)
	# 머리에 붙은 밥풀 몇 톨
	var r := RandomNumberGenerator.new()
	r.seed = 9
	for g in 4:
		var c := Vector3(r.randf_range(-0.06, 0.06), r.randf_range(0.03, 0.15), 0.014)
		var dir := Vector3(r.randf_range(-1, 1), r.randf_range(-1, 1), 0.2).normalized()
		var side := dir.cross(Vector3(0, 0, 1)).normalized()
		rice_grain(st, c, dir, side, side.cross(dir).normalized(), 0.8, r.randf())
	var m := MeshKit.finish(st)
	prop_mesh_cache["paddle"] = m
	return m

# 참새(멧참새): 머리와 몸이 한 덩어리로 이어진 통통한 몸. 밤색 정수리, 흰 뺨의 검은 점, 검은 턱,
# 줄무늬 진 갈색 등, 잿빛 흰 배. 앞(+z)을 봐요. 몸 한가운데가 (0,0,0)
func sparrow_mesh() -> ArrayMesh:
	if prop_mesh_cache.has("sparrow"):
		return prop_mesh_cache["sparrow"]
	var st := MeshKit.begin()
	# [z, 가운데 높이, 가로 반지름, 세로 반지름]
	var ctrl := [
		[-0.125, 0.025, 0.012, 0.01],
		[-0.1, 0.018, 0.045, 0.04],
		[-0.05, 0.004, 0.08, 0.078],
		[0.01, -0.004, 0.094, 0.094],
		[0.06, 0.008, 0.086, 0.09],
		[0.095, 0.035, 0.066, 0.07],
		[0.125, 0.06, 0.062, 0.064],
		[0.16, 0.066, 0.055, 0.055],
		[0.185, 0.066, 0.036, 0.038],
		[0.2, 0.064, 0.012, 0.014],
	]
	var rings := smooth_rings(ctrl, 4, true)
	var crown := Color(0.55, 0.3, 0.17)
	var back := Color(0.56, 0.39, 0.25)
	var streak := Color(0.26, 0.17, 0.11)
	var belly := Color(0.86, 0.83, 0.77)
	var white := Color(0.97, 0.96, 0.93)
	var black := Color(0.1, 0.08, 0.07)
	var colf := func(t: float, a: float) -> Color:
		var z := lerpf(-0.125, 0.2, t)
		var up := sin(a)
		var side := absf(cos(a))
		if z > 0.105:
			# 머리
			if up > 0.25:
				return crown
			if z > 0.165 and up < 0.05:
				return black
			if up < -0.45:
				return black if z > 0.12 else belly
			if side > 0.55:
				if absf(z - 0.137) < 0.016 and up < 0.02 and up > -0.32:
					return black
				return white
			return crown.lerp(white, 0.5)
		if z > 0.085 and up < -0.3:
			return black
		# 날개: 몸 옆에 접힌 깃 (짙은 줄, 흰 띠)
		if side > 0.5 and up > -0.3 and up < 0.62 and z < 0.075 and z > -0.105:
			if absf(z - 0.035) < 0.009 and up < 0.4:
				return Color(0.95, 0.92, 0.85)
			if z < -0.02 and sin(up * 30.0) > 0.2:
				return streak
			return Color(0.5, 0.33, 0.2) if sin(z * 160.0 + up * 6.0) < 0.6 else streak.lightened(0.1)
		if up > 0.15:
			var s := sin(z * 140.0 + cos(a) * 9.0)
			return streak if s > 0.55 else back.lerp(back.lightened(0.15), (up - 0.15))
		if up > -0.35:
			return back.lerp(belly, (0.15 - up) / 0.5)
		return belly
	kit_loft(st, rings, Vector3(1, 0, 0), Vector3(0, 1, 0), 20, colf)
	# 눈: 머리 옆 표면에 박힌 까만 눈 + 작은 반짝임
	for sx in [-1.0, 1.0]:
		var ep: Vector3 = Vector3(sx * 0.049, 0.079, 0.162)
		MeshKit.ball(st, ep, Vector3(0.011, 0.012, 0.012), black, 8, 6)
		MeshKit.ball(st, ep + Vector3(sx * 0.008, 0.005, 0.004), Vector3(0.0035, 0.0035, 0.0035), Color(1, 1, 1), 4, 3)
		# 날개 끝 칼깃: 꽁지 쪽으로 몸에 붙어 짧게
		for k in 3:
			MeshKit.leaf(st, Vector3(sx * (0.066 - k * 0.006), 0.012 + k * 0.008, -0.06 - k * 0.006), Vector3(sx * 0.06, 0.06, -1.0), Vector3(0, 1, 0), 0.085, 0.022, streak, 0.02, "long")
		# 다리와 발가락
		MeshKit.tube(st, Vector3(sx * 0.03, -0.075, 0.02), Vector3(sx * 0.032, -0.15, 0.03), 0.008, 0.007, Color(0.62, 0.46, 0.36), 4)
		for t in [-0.4, 0.0, 0.4]:
			MeshKit.tube(st, Vector3(sx * 0.032, -0.15, 0.03), Vector3(sx * 0.032 + sin(t) * 0.03, -0.152, 0.03 + cos(t) * 0.03), 0.005, 0.004, Color(0.62, 0.46, 0.36), 3)
	# 짧고 단단한 부리 (윗부리, 아랫부리)
	MeshKit.tube(st, Vector3(0, 0.068, 0.19), Vector3(0, 0.062, 0.232), 0.017, 0.002, Color(0.25, 0.22, 0.2), 8)
	MeshKit.tube(st, Vector3(0, 0.056, 0.188), Vector3(0, 0.055, 0.222), 0.012, 0.002, Color(0.35, 0.3, 0.26), 6)
	# 꽁지깃
	MeshKit.leaf(st, Vector3(0, 0.025, -0.115), Vector3(0, 0.1, -1.0), Vector3(1, 0, 0), 0.13, 0.06, Color(0.36, 0.24, 0.15), 0.0, "long")
	MeshKit.leaf(st, Vector3(0, 0.03, -0.112), Vector3(0, 0.12, -1.0), Vector3(1, 0, 0), 0.11, 0.035, streak, 0.0, "long")
	var m := MeshKit.finish(st)
	prop_mesh_cache["sparrow"] = m
	return m

# 허수아비 머리: 자루를 목에서 새끼줄로 동여맨 모양 (아래는 주름져 퍼지고, 울퉁불퉁, 앞은 살짝 납작)
const SACK_CTRL := [
	[1.52, 0.0, 0.2, 0.17],
	[1.58, 0.0, 0.15, 0.13],
	[1.63, 0.0, 0.085, 0.08],
	[1.67, 0.0, 0.1, 0.095],
	[1.74, 0.0, 0.19, 0.17],
	[1.84, 0.0, 0.235, 0.205],
	[1.94, 0.0, 0.225, 0.2],
	[2.02, 0.0, 0.17, 0.155],
	[2.07, 0.0, 0.06, 0.06],
]

func sack_rad(t: float, a: float) -> float:
	var y := lerpf(1.52, 2.07, t)
	var m := 1.0 + 0.035 * sin(a * 3.0 + 1.0) * sin(y * 20.0) + 0.02 * sin(a * 5.0 + y * 9.0)
	# 동여맨 목 위아래로 잡힌 주름
	var near := clampf(1.0 - absf(y - 1.645) / 0.12, 0.0, 1.0)
	m *= 1.0 + 0.16 * near * sin(a * 9.0)
	# 아래 자락은 어깨 위로 펄럭
	if y < 1.6:
		m *= 1.0 + 0.08 * sin(a * 6.0 + 0.7)
	return m

func sack_point(y: float, a: float) -> Vector3:
	var rings := smooth_rings(SACK_CTRL, 1, false)
	var best: Array = rings[0]
	var best2: Array = rings[1]
	for i in rings.size() - 1:
		if float((rings[i][0] as Vector3).y) <= y and float((rings[i + 1][0] as Vector3).y) >= y:
			best = rings[i]
			best2 = rings[i + 1]
	var y0 := (best[0] as Vector3).y
	var y1 := (best2[0] as Vector3).y
	var t := clampf((y - y0) / maxf(0.0001, y1 - y0), 0.0, 1.0)
	var rx := lerpf(float(best[1]), float(best2[1]), t)
	var rz := lerpf(float(best[2]), float(best2[2]), t)
	var m := sack_rad((y - 1.52) / 0.55, a)
	return Vector3(cos(a) * rx * m, y, sin(a) * rz * m)

# 자루 겉에 붙인 납작한 그림(눈, 볼, 천 조각): 겉면 방향으로 눕혀요
func sack_decal(st: SurfaceTool, y: float, a: float, size: Vector2, col: Color, lift: float = 0.003) -> void:
	var p := sack_point(y, a)
	var nrm := Vector3(p.x, 0, p.z).normalized()
	var b := Basis.looking_at(-nrm, Vector3.UP)
	MeshKit.ball(st, p + nrm * lift, Vector3(size.x, size.y, 0.004), col, 12, 6, b)

# 허수아비: 둥근 장대와 가로대, 어깨가 납작한 삼베 저고리(흰 동정, 붉은 옷고름, 기운 천),
# 소매와 밑단에 삐져나온 짚, 목을 동여맨 자루 머리에 숯으로 그린 얼굴, 고깔 밀짚모자. 바닥이 (0,0,0), 앞(+z)
func scarecrow_mesh() -> ArrayMesh:
	if prop_mesh_cache.has("scarecrow"):
		return prop_mesh_cache["scarecrow"]
	var r := RandomNumberGenerator.new()
	r.seed = 77
	var st := MeshKit.begin()
	var wood := Color(0.5, 0.36, 0.22)
	MeshKit.tube(st, Vector3(0, 0, 0), Vector3(0, 1.7, 0), 0.07, 0.058, wood, 8, wood.lightened(0.1))
	MeshKit.tube(st, Vector3(-0.98, 1.45, 0), Vector3(0.98, 1.45, 0), 0.05, 0.045, wood.darkened(0.05), 8)
	# 저고리: 단면이 납작한 몸통 (밑단 → 어깨)
	var cloth := Color(0.8, 0.72, 0.56)
	var body_ctrl := [[0.86, 0.0, 0.36, 0.27], [1.05, 0.0, 0.34, 0.25], [1.3, 0.0, 0.31, 0.225], [1.48, 0.0, 0.29, 0.2], [1.56, 0.0, 0.2, 0.15], [1.6, 0.0, 0.08, 0.07]]
	var body_col := func(t: float, a: float) -> Color:
		var c := cloth.darkened(0.06 * (1.0 - t))
		if sin(a * 2.0 + t * 6.0) > 0.92:
			c = c.darkened(0.07)
		return c
	kit_loft(st, smooth_rings(body_ctrl, 3, false), Vector3(1, 0, 0), Vector3(0, 0, 1), 18, body_col)
	for sx in [-1.0, 1.0]:
		MeshKit.tube(st, Vector3(sx * 0.2, 1.46, 0), Vector3(sx * 0.78, 1.45, 0), 0.14, 0.125, cloth.darkened(0.04), 12)
		MeshKit.tube(st, Vector3(sx * 0.7, 1.45, 0), Vector3(sx * 0.79, 1.45, 0), 0.135, 0.135, cloth.darkened(0.12), 12)
		for k in 12:
			var a := r.randf() * TAU
			var d := Vector3(sx, r.randf_range(-0.45, 0.45), r.randf_range(-0.45, 0.45)).normalized()
			MeshKit.leaf(st, Vector3(sx * 0.76, 1.45 + sin(a) * 0.06, cos(a) * 0.06), d, Vector3(0, cos(a), sin(a)) + Vector3(0.01, 0, 0), r.randf_range(0.16, 0.3), 0.03, Color(0.92, 0.8, 0.45).lerp(Color(0.8, 0.66, 0.32), r.randf()), 0.25, "long")
	# 밑단 짚
	for k in 28:
		var a := k * TAU / 28.0 + r.randf_range(-0.1, 0.1)
		var out := Vector3(cos(a) * 0.34, 0, sin(a) * 0.25)
		MeshKit.leaf(st, out + Vector3(0, 0.9, 0), (out.normalized() * 0.35 + Vector3(0, -1, 0)).normalized(), Vector3(-sin(a), 0, cos(a)), r.randf_range(0.22, 0.36), 0.035, Color(0.92, 0.8, 0.45).lerp(Color(0.78, 0.64, 0.3), r.randf()), -0.15, "long")
	# 흰 동정 깃, 붉은 옷고름, 기운 파란 천과 바늘땀
	# 깃: 오른쪽 어깨에서 내려오는 긴 섶과 왼쪽에서 만나는 짧은 깃 (V자)
	MeshKit.tube(st, Vector3(0.1, 1.55, 0.13), Vector3(0.04, 1.31, 0.228), 0.024, 0.022, Color(0.97, 0.96, 0.92), 6)
	MeshKit.tube(st, Vector3(-0.1, 1.55, 0.13), Vector3(0.04, 1.31, 0.228), 0.024, 0.022, Color(0.97, 0.96, 0.92), 6)
	MeshKit.tube(st, Vector3(0.04, 1.31, 0.228), Vector3(0.1, 0.92, 0.27), 0.012, 0.012, Color(0.68, 0.6, 0.45), 4)
	MeshKit.leaf(st, Vector3(0.05, 1.3, 0.235), Vector3(0.25, -1, 0.2), Vector3(1, 0.2, -0.3), 0.26, 0.06, Color(0.82, 0.22, 0.2), -0.05, "long")
	MeshKit.leaf(st, Vector3(0.05, 1.3, 0.235), Vector3(0.05, -1, 0.25), Vector3(1, 0, -0.1), 0.2, 0.05, Color(0.78, 0.2, 0.18), -0.05, "long")
	MeshKit.ball(st, Vector3(-0.17, 1.08, 0.205), Vector3(0.09, 0.08, 0.012), Color(0.42, 0.52, 0.72), 10, 5, Basis(Vector3.UP, -0.55))
	for k in 6:
		var y := 1.02 + k * 0.024
		MeshKit.tube(st, Vector3(-0.255, y, 0.17), Vector3(-0.24, y, 0.19), 0.005, 0.005, Color(0.3, 0.22, 0.15), 3)
	# 자루 머리: 삼베 결(밝고 어두운 올), 옆 솔기
	var sack := Color(0.84, 0.74, 0.52)
	var sack_col := func(t: float, a: float) -> Color:
		var c := sack
		var y := lerpf(1.52, 2.07, t)
		if int(floor(a * 18.0 / TAU) + floor(y * 60.0)) % 2 == 0:
			c = c.darkened(0.04)
		if absf(cos(a)) > 0.985:
			c = c.darkened(0.25)
		if y < 1.6:
			c = c.darkened(0.05)
		return c
	kit_loft(st, smooth_rings(SACK_CTRL, 3, false), Vector3(1, 0, 0), Vector3(0, 0, 1), 28, sack_col, sack_rad)
	# 목 새끼줄 (꼬인 두 가닥)
	for k in 24:
		var a0 := k * TAU / 24.0
		var a1 := (k + 1) * TAU / 24.0
		for q in 2:
			var off := q * PI
			var p0 := Vector3(cos(a0) * 0.098, 1.645 + sin(a0 * 4.0 + off) * 0.008, sin(a0) * 0.092)
			var p1 := Vector3(cos(a1) * 0.098, 1.645 + sin(a1 * 4.0 + off) * 0.008, sin(a1) * 0.092)
			MeshKit.tube(st, p0, p1, 0.012, 0.012, Color(0.72, 0.58, 0.34).darkened(0.1 * q), 5)
	MeshKit.tube(st, Vector3(0.07, 1.64, 0.07), Vector3(0.11, 1.56, 0.12), 0.01, 0.008, Color(0.72, 0.58, 0.34), 4)
	MeshKit.tube(st, Vector3(0.07, 1.64, 0.07), Vector3(0.14, 1.58, 0.06), 0.01, 0.008, Color(0.66, 0.52, 0.3), 4)
	# 숯으로 그린 얼굴: 눈썹, 동그란 눈(흰 반짝임), 볼, 코, 바늘땀 입
	var front := PI / 2.0
	for sx in [-1.0, 1.0]:
		var ea: float = front - sx * 0.36
		sack_decal(st, 1.885, ea, Vector2(0.03, 0.036), Color(0.1, 0.08, 0.07))
		sack_decal(st, 1.895, ea + sx * 0.06, Vector2(0.009, 0.009), Color(0.98, 0.97, 0.94), 0.006)
		sack_decal(st, 1.8, front - sx * 0.62, Vector2(0.045, 0.028), Color(0.95, 0.55, 0.5))
		var prev_b: Vector3 = sack_point(1.945, front - sx * 0.22)
		for k in 5:
			var t := float(k + 1) / 5.0
			var pb: Vector3 = sack_point(1.945 + sin(t * PI) * 0.016 - t * 0.01, front - sx * (0.22 + t * 0.3))
			var nb := Vector3(pb.x, 0, pb.z).normalized()
			MeshKit.tube(st, prev_b + nb * 0.003, pb + nb * 0.003, 0.008, 0.008, Color(0.15, 0.12, 0.1), 4)
			prev_b = pb
	sack_decal(st, 1.84, front, Vector2(0.022, 0.016), Color(0.5, 0.32, 0.22))
	var prev := sack_point(1.775, front + 0.42)
	for k in 9:
		var t := float(k + 1) / 9.0
		var p := sack_point(1.775 - sin(t * PI) * 0.03, front + 0.42 - t * 0.84)
		var nrm := Vector3(p.x, 0, p.z).normalized()
		MeshKit.tube(st, prev + nrm * 0.004, p + nrm * 0.004, 0.008, 0.008, Color(0.42, 0.16, 0.12), 4)
		# 입을 가로지르는 바늘땀
		var mid := (prev + p) * 0.5 + nrm * 0.005
		MeshKit.tube(st, mid + Vector3(0, 0.016, 0), mid - Vector3(0, 0.016, 0), 0.004, 0.004, Color(0.3, 0.22, 0.16), 3)
		prev = p
	# 머리 옆에 덧댄 천 조각과 바늘땀
	sack_decal(st, 1.9, front + 1.15, Vector2(0.065, 0.055), Color(0.62, 0.48, 0.38), 0.005)
	# 고깔 밀짚모자: 넓은 챙(엮은 결), 둥근 꼭대기, 붉은 띠
	var straw := Color(0.82, 0.66, 0.36)
	var hat_col := func(t: float, a: float) -> Color:
		return straw.darkened(0.08) if int(floor(a * 40.0 / TAU) + floor(t * 6.0)) % 2 == 0 else straw.lightened(0.04)
	kit_loft(st, [[Vector3(0, 1.99, 0), 0.58, 0.58], [Vector3(0, 2.05, 0), 0.45, 0.45], [Vector3(0, 2.12, 0), 0.3, 0.3], [Vector3(0, 2.18, 0), 0.19, 0.19]], Vector3(1, 0, 0), Vector3(0, 0, 1), 32, hat_col, Callable(), false)
	kit_loft(st, [[Vector3(0, 2.17, 0), 0.19, 0.19], [Vector3(0, 2.3, 0), 0.16, 0.16], [Vector3(0, 2.36, 0), 0.11, 0.11], [Vector3(0, 2.385, 0), 0.03, 0.03]], Vector3(1, 0, 0), Vector3(0, 0, 1), 24, hat_col, Callable(), false)
	MeshKit.tube(st, Vector3(0, 2.18, 0), Vector3(0, 2.23, 0), 0.192, 0.185, Color(0.75, 0.2, 0.18), 20)
	MeshKit.tube(st, Vector3(0, 1.985, 0), Vector3(0, 1.995, 0), 0.585, 0.58, straw.darkened(0.25), 32)
	var m := MeshKit.finish(st)
	prop_mesh_cache["scarecrow"] = m
	return m

# 장터 차양: 줄무늬 천이 가운데가 살짝 처지고 앞자락이 물결 모양으로 늘어져요
func awning_mesh() -> ArrayMesh:
	if prop_mesh_cache.has("awning"):
		return prop_mesh_cache["awning"]
	var st := MeshKit.begin()
	var x0 := -2.1
	var x1 := 2.1
	var z0 := -0.85
	var z1 := 1.85
	var stripes := 8
	var per := 4
	var nz := 6
	var red := Color(0.84, 0.24, 0.22)
	var cream := Color(0.98, 0.94, 0.84)
	var fn := func(x: float, z: float) -> Vector3:
		var tz := (z - z0) / (z1 - z0)
		var y := 2.78 - tz * 0.42 - sin((x - x0) / (x1 - x0) * PI * stripes / 2.0) * 0.0 - sin(tz * PI) * 0.05 * (1.0 - absf((x - (x0 + x1) * 0.5) / (x1 - x0)) * 1.6)
		return Vector3(x, y, z)
	for s in stripes:
		var col := red if s % 2 == 0 else cream
		for q in per:
			var xa := x0 + (x1 - x0) * (s * per + q) / float(stripes * per)
			var xb := x0 + (x1 - x0) * (s * per + q + 1) / float(stripes * per)
			for k in nz:
				var za := z0 + (z1 - z0) * k / float(nz)
				var zb := z0 + (z1 - z0) * (k + 1) / float(nz)
				var shade := col.darkened(0.08 * k / float(nz))
				MeshKit.quad(st, fn.call(xa, za), fn.call(xb, za), fn.call(xb, zb), fn.call(xa, zb), shade, shade, shade, shade)
		# 앞자락: 줄마다 둥글게 늘어진 반달
		var xs := x0 + (x1 - x0) * s / float(stripes)
		var xe := x0 + (x1 - x0) * (s + 1) / float(stripes)
		var top_a: Vector3 = fn.call(xs, z1)
		var top_b: Vector3 = fn.call(xe, z1)
		var n := 8
		for k in n:
			var ta := float(k) / n
			var tb := float(k + 1) / n
			var pa := top_a.lerp(top_b, ta)
			var pb := top_a.lerp(top_b, tb)
			var da := pa + Vector3(0, -0.2 - sin(ta * PI) * 0.12, 0.02)
			var db := pb + Vector3(0, -0.2 - sin(tb * PI) * 0.12, 0.02)
			MeshKit.quad(st, pa, pb, db, da, col, col, col.darkened(0.12), col.darkened(0.12))
	var m := MeshKit.finish(st)
	prop_mesh_cache["awning"] = m
	return m

# 장터 물건: 감·사과·배가 담긴 바구니 속 과일, 옹기 항아리 두 개 (바구니와 좌판은 따로)
func stall_goods_mesh() -> ArrayMesh:
	if prop_mesh_cache.has("goods"):
		return prop_mesh_cache["goods"]
	var r := RandomNumberGenerator.new()
	r.seed = 12
	var st := MeshKit.begin()
	for i in 3:
		var bp := Vector3(-1.3 + i * 1.0, 1.12, 0.1)
		var pts := []
		for k in 6:
			var a := k * TAU / 6.0 + 0.3
			pts.append(bp + Vector3(cos(a) * 0.15, 0.04, sin(a) * 0.15))
		pts.append(bp + Vector3(0.0, 0.14, 0.0))
		pts.append(bp + Vector3(0.06, 0.12, -0.08))
		for p in pts:
			match i:
				0:  # 감: 납작 둥근 주황, 네 갈래 꼭지
					MeshKit.ball(st, p, Vector3(0.085, 0.07, 0.085), Color(0.98, 0.5, 0.12).lerp(Color(0.95, 0.42, 0.1), r.randf()), 10, 6)
					for q in 4:
						var a2 := q * TAU / 4.0 + 0.4
						MeshKit.leaf(st, p + Vector3(0, 0.065, 0), Vector3(cos(a2), 0.25, sin(a2)), Vector3(-sin(a2), 0, cos(a2)), 0.05, 0.035, Color(0.35, 0.45, 0.2), 0.05)
				1:  # 사과: 빨갛고 위가 살짝 오목, 꼭지
					MeshKit.ball(st, p, Vector3(0.08, 0.075, 0.08), Color(0.82, 0.16, 0.16).lerp(Color(0.9, 0.35, 0.2), r.randf() * 0.5), 10, 6)
					MeshKit.tube(st, p + Vector3(0, 0.06, 0), p + Vector3(0.01, 0.1, 0), 0.007, 0.005, Color(0.35, 0.25, 0.15), 4)
				_:  # 배: 누렇고 둥글넓적, 점무늬
					MeshKit.ball(st, p, Vector3(0.088, 0.08, 0.088), Color(0.9, 0.78, 0.4).lerp(Color(0.85, 0.7, 0.35), r.randf()), 10, 6)
					MeshKit.tube(st, p + Vector3(0, 0.07, 0), p + Vector3(0, 0.1, 0.01), 0.006, 0.005, Color(0.35, 0.25, 0.15), 4)
		if i == 1:
			MeshKit.leaf(st, bp + Vector3(0.05, 0.2, 0.0), Vector3(1, 0.3, 0.2), Vector3(0, 0, 1), 0.08, 0.045, Color(0.3, 0.55, 0.25), 0.1)
	# 옹기 항아리 (좌판 옆 땅바닥): 배가 불룩한 몸, 좁은 목, 두툼한 입술
	for j in 2:
		var c := Vector3(-2.45 + j * 0.05, 0.0, 0.55 + j * 0.6)
		var s := 1.0 - j * 0.25
		var glaze := Color(0.42, 0.26, 0.16).lerp(Color(0.5, 0.32, 0.2), j)
		var prof := [[0.0, 0.14], [0.08, 0.2], [0.25, 0.27], [0.42, 0.26], [0.55, 0.19], [0.62, 0.13], [0.66, 0.15], [0.7, 0.14]]
		for k in prof.size() - 1:
			var a: Array = prof[k]
			var b: Array = prof[k + 1]
			MeshKit.tube(st, c + Vector3(0, float(a[0]) * s, 0), c + Vector3(0, float(b[0]) * s, 0), float(a[1]) * s, float(b[1]) * s, glaze.darkened(0.05 * (1.0 - float(a[0]))), 16, glaze.lightened(0.04))
		MeshKit.ball(st, c + Vector3(0, 0.6 * s, 0), Vector3(0.13, 0.015, 0.13) * s, Color(0.15, 0.1, 0.08), 12, 3)
		# 어깨에 손으로 그은 물결 무늬
		for k in 12:
			var a := k * TAU / 12.0
			var a2 := (k + 1) * TAU / 12.0
			var ra := 0.255 * s
			MeshKit.tube(st, c + Vector3(cos(a) * ra, (0.46 + sin(k * 1.7) * 0.015) * s, sin(a) * ra), c + Vector3(cos(a2) * ra, (0.46 + sin((k + 1) * 1.7) * 0.015) * s, sin(a2) * ra), 0.006, 0.006, Color(0.75, 0.62, 0.45), 3)
	var m := MeshKit.finish(st)
	prop_mesh_cache["goods"] = m
	return m

# ---------- 벼 포기 (흥부네 최 영감네 논, 모내기): 0 어린 모, 1 푸른 벼, 2 누런 벼 ----------
var rice_mesh_cache := {}

func rice_mesh(stage: int, variant: int) -> ArrayMesh:
	var key := stage * 10 + variant
	if rice_mesh_cache.has(key):
		return rice_mesh_cache[key]
	var r := RandomNumberGenerator.new()
	r.seed = 700 + key * 31
	var st := MeshKit.begin()
	match stage:
		0:  # 어린 모: 가늘고 여린 잎 여섯 일곱 장이 부채처럼, 밑동은 흙 묻은 연두
			var n := 6 + variant % 2
			for i in n:
				var a := i * TAU / n + r.randf_range(-0.3, 0.3)
				var lean := r.randf_range(0.18, 0.5)
				var d := Vector3(cos(a) * lean, 1.0, sin(a) * lean).normalized()
				MeshKit.leaf(st, Vector3(cos(a) * 0.01, 0.0, sin(a) * 0.01), d, Vector3(-sin(a), 0, cos(a)), r.randf_range(0.26, 0.4), 0.028, Color(0.5, 0.76, 0.32).lerp(Color(0.66, 0.86, 0.4), r.randf()), 0.35, "long")
			MeshKit.tube(st, Vector3(0, -0.02, 0), Vector3(0, 0.06, 0), 0.022, 0.016, Color(0.62, 0.72, 0.42), 6)
		1:  # 푸른 벼: 곧게 솟은 줄기와 길게 휘어 늘어진 잎이 수북
			for i in 7:
				var a := r.randf() * TAU
				var top := Vector3(cos(a) * r.randf_range(0.03, 0.08), r.randf_range(0.45, 0.62), sin(a) * r.randf_range(0.03, 0.08))
				MeshKit.tube(st, Vector3(cos(a) * 0.015, 0, sin(a) * 0.015), top, 0.011, 0.007, Color(0.4, 0.62, 0.28), 4)
			for i in 16:
				var a := i * TAU / 16.0 + r.randf_range(-0.25, 0.25)
				var lean := r.randf_range(0.12, 0.5)
				var d := Vector3(cos(a) * lean, 1.0, sin(a) * lean).normalized()
				MeshKit.leaf(st, Vector3(cos(a) * 0.02, r.randf_range(0.0, 0.18), sin(a) * 0.02), d, Vector3(-sin(a), 0, cos(a)), r.randf_range(0.5, 0.85), 0.052, Color(0.24, 0.5, 0.16).lerp(Color(0.4, 0.64, 0.22), r.randf()), 0.4, "long")
		_:  # 누런 벼: 이삭이 무거워 고개를 숙인 줄기, 잎은 노랗게
			for i in 8:
				var a := i * TAU / 8.0 + r.randf_range(-0.3, 0.3)
				var lean := r.randf_range(0.2, 0.5)
				var d := Vector3(cos(a) * lean, 1.0, sin(a) * lean).normalized()
				MeshKit.leaf(st, Vector3(cos(a) * 0.02, r.randf_range(0.0, 0.15), sin(a) * 0.02), d, Vector3(-sin(a), 0, cos(a)), r.randf_range(0.4, 0.65), 0.035, Color(0.78, 0.66, 0.3).lerp(Color(0.66, 0.62, 0.3), r.randf()), 0.45, "long")
			for i in 5:
				var a := i * TAU / 5.0 + r.randf_range(-0.3, 0.3)
				var out := Vector3(cos(a), 0, sin(a))
				var top := out * r.randf_range(0.06, 0.12) + Vector3(0, r.randf_range(0.62, 0.74), 0)
				MeshKit.tube(st, out * 0.015, top, 0.01, 0.007, Color(0.72, 0.62, 0.3), 4)
				# 이삭: 줄기 끝에서 바깥으로 둥글게 휘어 내려가는 낟알 줄
				var prev := top
				for q in 7:
					var t := float(q + 1) / 7.0
					var p := top + out * (sin(t * 1.4) * 0.2) + Vector3(0, -t * t * 0.26 + t * 0.04, 0)
					MeshKit.tube(st, prev, p, 0.006, 0.005, Color(0.8, 0.68, 0.3), 3)
					var side := out.cross(Vector3.UP) * (0.014 if q % 2 == 0 else -0.014)
					MeshKit.ball(st, p + side, Vector3(0.016, 0.026, 0.016), Color(0.96, 0.8, 0.32).lerp(Color(0.9, 0.7, 0.26), r.randf()), 5, 3)
					prev = p
	var m := MeshKit.finish(st)
	rice_mesh_cache[key] = m
	return m

# ---------- 입체 약초 (잎·줄기·꽃·열매를 진짜 모양으로, meshkit.gd) ----------
var herb_mesh_cache := {}

func herb_mesh(k: int) -> ArrayMesh:
	if herb_mesh_cache.has(k):
		return herb_mesh_cache[k]
	var r := RandomNumberGenerator.new()
	r.seed = 900 + k * 17
	var st := MeshKit.begin()
	var G := Color(0.32, 0.56, 0.26)
	var id: String = HERBS[k]["id"]
	match id:
		"ssuk":  # 쑥: 갈라진 은빛 잎이 위로 수북
			for i in 11:
				var a := i * TAU / 11.0 + r.randf() * 0.3
				var d := Vector3(cos(a) * 0.45, 1.0, sin(a) * 0.45).normalized()
				MeshKit.leaf(st, Vector3(cos(a) * 0.04, 0.02, sin(a) * 0.04), d, Vector3(-sin(a), 0, cos(a)), r.randf_range(0.3, 0.45), 0.11, Color(0.55, 0.68, 0.5).lerp(Color(0.72, 0.8, 0.7), r.randf()), 0.3, "tooth")
		"naengi":  # 냉이: 땅에 붙은 깃꼴 잎 방석과 하얀 꽃대
			for i in 9:
				var a := i * TAU / 9.0
				MeshKit.leaf(st, Vector3(0, 0.02, 0), Vector3(cos(a), 0.12, sin(a)), Vector3(-sin(a), 0, cos(a)), 0.28, 0.08, G, 0.05, "tooth")
			for i in 3:
				var top := Vector3(r.randf_range(-0.08, 0.08), r.randf_range(0.42, 0.55), r.randf_range(-0.08, 0.08))
				MeshKit.tube(st, Vector3(0, 0.02, 0), top, 0.012, 0.008, Color(0.42, 0.6, 0.3), 5)
				for q in 6:
					MeshKit.ball(st, top + Vector3(r.randf_range(-0.04, 0.04), r.randf_range(-0.08, 0.02), r.randf_range(-0.04, 0.04)), Vector3.ONE * 0.022, Color(1, 1, 0.97), 6, 4)
		"dallae":  # 달래: 가늘고 긴 잎과 하얀 알뿌리
			for i in 10:
				var a := r.randf() * TAU
				MeshKit.leaf(st, Vector3(cos(a) * 0.03, 0.03, sin(a) * 0.03), Vector3(cos(a) * 0.25, 1.0, sin(a) * 0.25), Vector3(-sin(a), 0, cos(a)), r.randf_range(0.4, 0.58), 0.035, Color(0.38, 0.64, 0.3), 0.55, "long")
			MeshKit.ball(st, Vector3(0.06, 0.05, 0.03), Vector3(0.05, 0.045, 0.05), Color(0.98, 0.96, 0.9), 8, 6)
			MeshKit.ball(st, Vector3(-0.05, 0.045, 0.05), Vector3(0.04, 0.04, 0.04), Color(0.98, 0.94, 0.88), 8, 6)
		"doraji":  # 도라지: 줄기마다 마주난 잎, 끝에 보라·하얀 별꽃
			for i in 3:
				var a := i * TAU / 3.0
				var top := Vector3(cos(a) * 0.15, r.randf_range(0.55, 0.72), sin(a) * 0.15)
				MeshKit.tube(st, Vector3(0, 0.02, 0), top, 0.014, 0.01, Color(0.34, 0.52, 0.26), 5)
				for q in 3:
					var at := top * (0.3 + q * 0.2)
					MeshKit.leaf(st, at, Vector3(cos(a + 1.5), 0.3, sin(a + 1.5)), Vector3(0, 1, 0), 0.13, 0.06, G, 0.1)
					MeshKit.leaf(st, at, Vector3(cos(a - 1.5), 0.3, sin(a - 1.5)), Vector3(0, 1, 0), 0.13, 0.06, G, 0.1)
				MeshKit.flower(st, top, 5, 0.09, 0.07, Color(0.6, 0.45, 0.92) if i != 1 else Color(0.97, 0.97, 1.0), Color(0.95, 0.9, 0.6), 0.6)
		"deodeok":  # 더덕: 막대를 감아 오르는 덩굴, 종 모양 꽃
			MeshKit.tube(st, Vector3(0, 0, 0), Vector3(0, 0.95, 0), 0.025, 0.02, Color(0.45, 0.32, 0.2), 6)
			var prev := Vector3(0.04, 0.05, 0)
			for i in 14:
				var a := i * 0.9
				var p := Vector3(cos(a) * 0.045, 0.05 + i * 0.062, sin(a) * 0.045)
				MeshKit.tube(st, prev, p, 0.008, 0.008, Color(0.35, 0.5, 0.25), 4)
				if i % 2 == 0:
					MeshKit.leaf(st, p, Vector3(cos(a), 0.1, sin(a)), Vector3(0, 1, 0), 0.12, 0.06, G, 0.15)
				prev = p
			for y in [0.5, 0.78]:
				MeshKit.tube(st, Vector3(0.1, y, 0), Vector3(0.1, y - 0.1, 0), 0.012, 0.045, Color(0.66, 0.72, 0.52), 8, Color(0.55, 0.3, 0.42))
		"sansam":  # 산삼: 손바닥 잎 다섯 장씩 세 갈래, 빨간 열매
			MeshKit.tube(st, Vector3(0, 0, 0), Vector3(0, 0.5, 0), 0.016, 0.012, Color(0.36, 0.5, 0.26), 5)
			for i in 3:
				var a := i * TAU / 3.0
				var base := Vector3(cos(a) * 0.13, 0.44, sin(a) * 0.13)
				MeshKit.tube(st, Vector3(0, 0.45, 0), base, 0.008, 0.008, Color(0.36, 0.5, 0.26), 4)
				for q in 5:
					var b := a + (q - 2) * 0.42
					MeshKit.leaf(st, base, Vector3(cos(b), 0.05, sin(b)), Vector3(0, 1, 0), 0.15, 0.07, Color(0.28, 0.55, 0.26), 0.12)
			for i in 9:
				MeshKit.ball(st, Vector3(r.randf_range(-0.035, 0.035), 0.58 + r.randf_range(0, 0.05), r.randf_range(-0.035, 0.035)), Vector3.ONE * 0.028, Color(0.88, 0.1, 0.1), 6, 4)
		"gosari":  # 고사리: 돌돌 말린 순과 깃털 잎
			for i in 5:
				var a := i * TAU / 5.0 + r.randf() * 0.4
				var top := Vector3(cos(a) * 0.16, r.randf_range(0.4, 0.55), sin(a) * 0.16)
				MeshKit.tube(st, Vector3(0, 0, 0), top, 0.012, 0.008, Color(0.45, 0.48, 0.24), 4)
				MeshKit.ball(st, top + Vector3(0, 0.03, 0), Vector3(0.04, 0.04, 0.025), Color(0.5, 0.56, 0.28), 8, 5)
				for q in 6:
					var at := top * (0.35 + q * 0.1)
					var side := Vector3(-sin(a), 0, cos(a))
					MeshKit.leaf(st, at, side + Vector3(0, 0.15, 0), Vector3(0, 1, 0), 0.1 - q * 0.01, 0.035, Color(0.36, 0.58, 0.26), 0.1, "long")
					MeshKit.leaf(st, at, -side + Vector3(0, 0.15, 0), Vector3(0, 1, 0), 0.1 - q * 0.01, 0.035, Color(0.36, 0.58, 0.26), 0.1, "long")
		"chwi":  # 취나물: 큰 하트 잎 무더기
			for i in 8:
				var a := i * TAU / 8.0
				var hgt := r.randf_range(0.12, 0.28)
				var at := Vector3(cos(a) * 0.05, hgt, sin(a) * 0.05)
				MeshKit.tube(st, Vector3(0, 0, 0), at, 0.008, 0.008, Color(0.36, 0.5, 0.26), 4)
				MeshKit.leaf(st, at, Vector3(cos(a), 0.2, sin(a)), Vector3(0, 1, 0), 0.22, 0.2, Color(0.3, 0.55, 0.26).lerp(Color(0.42, 0.64, 0.32), r.randf()), 0.2, "heart")
		"omija":  # 오미자: 덩굴 잎과 늘어진 빨간 열매 송이
			for i in 7:
				var a := i * TAU / 7.0
				MeshKit.leaf(st, Vector3(cos(a) * 0.1, 0.32 + r.randf_range(-0.08, 0.1), sin(a) * 0.1), Vector3(cos(a), 0.1, sin(a)), Vector3(0, 1, 0), 0.18, 0.11, Color(0.3, 0.52, 0.24), 0.2)
			MeshKit.tube(st, Vector3(0, 0, 0), Vector3(0, 0.42, 0), 0.014, 0.01, Color(0.4, 0.3, 0.2), 5)
			for c in 3:
				var bc := Vector3(r.randf_range(-0.14, 0.14), 0.34, r.randf_range(-0.14, 0.14))
				for q in 8:
					MeshKit.ball(st, bc + Vector3(r.randf_range(-0.025, 0.025), -q * 0.025, r.randf_range(-0.025, 0.025)), Vector3.ONE * 0.025, Color(0.86, 0.1, 0.15), 6, 4)
		"chik":  # 칡: 땅 위 굵은 뿌리와 세 갈래 큰 잎
			MeshKit.tube(st, Vector3(-0.32, 0.04, 0.1), Vector3(0.0, 0.07, 0.0), 0.06, 0.07, Color(0.5, 0.37, 0.25), 7)
			MeshKit.tube(st, Vector3(0.0, 0.07, 0.0), Vector3(0.3, 0.05, -0.08), 0.07, 0.05, Color(0.52, 0.38, 0.25), 7)
			for i in 4:
				var a := i * TAU / 4.0 + 0.3
				var base := Vector3(cos(a) * 0.12, 0.3, sin(a) * 0.12)
				MeshKit.tube(st, Vector3(0, 0.06, 0), base, 0.01, 0.008, Color(0.4, 0.5, 0.26), 4)
				for q in 3:
					var b := a + (q - 1) * 0.9
					MeshKit.leaf(st, base, Vector3(cos(b), 0.15, sin(b)), Vector3(0, 1, 0), 0.17, 0.13, Color(0.34, 0.56, 0.28), 0.15)
		"yeongji":  # 영지버섯: 그루터기에 붙은 반질한 콩팥 모양 갓
			MeshKit.tube(st, Vector3(0, 0, 0), Vector3(0, 0.42, 0), 0.3, 0.27, Color(0.42, 0.3, 0.2), 10)
			MeshKit.ball(st, Vector3(0, 0.42, 0), Vector3(0.27, 0.02, 0.27), Color(0.62, 0.5, 0.34), 10, 3)
			for i in 3:
				var a := i * TAU / 3.0 + 0.3
				var p := Vector3(cos(a) * 0.3, 0.16 + i * 0.08, sin(a) * 0.3)
				MeshKit.ball(st, p, Vector3(0.2, 0.035, 0.15), Color(0.55, 0.16, 0.1), 10, 4, Basis(Vector3.UP, -a))
				MeshKit.ball(st, p + Vector3(cos(a) * 0.09, 0.016, sin(a) * 0.09), Vector3(0.11, 0.02, 0.09), Color(0.78, 0.45, 0.2), 8, 3, Basis(Vector3.UP, -a))
		"tot":  # 톳: 바위에 붙은 통통한 갈색 가지
			MeshKit.ball(st, Vector3(0, 0.08, 0), Vector3(0.26, 0.1, 0.2), Color(0.32, 0.32, 0.34), 10, 6)
			for i in 9:
				var a := i * TAU / 9.0
				var b := Vector3(cos(a) * 0.12, 0.14, sin(a) * 0.12)
				var t := b + Vector3(cos(a) * 0.05, 0.25, sin(a) * 0.05)
				MeshKit.tube(st, b, t, 0.01, 0.008, Color(0.38, 0.28, 0.12), 4)
				for q in 4:
					MeshKit.ball(st, b.lerp(t, 0.25 + q * 0.22) + Vector3(0.02, 0, 0), Vector3(0.018, 0.03, 0.018), Color(0.45, 0.32, 0.12), 6, 4)
		"miyeok":  # 미역: 넘실대는 넓은 띠
			for i in 6:
				var a := i * TAU / 6.0
				MeshKit.leaf(st, Vector3(cos(a) * 0.05, 0.02, sin(a) * 0.05), Vector3(cos(a) * 0.25, 1.0, sin(a) * 0.25), Vector3(-sin(a), 0, cos(a)), r.randf_range(0.8, 1.1), 0.16, Color(0.24, 0.36, 0.16), 0.1, "ribbon")
		"hamcho":  # 함초: 마디진 통통한 줄기 (끝이 붉어요)
			for i in 7:
				var a := i * TAU / 7.0
				var p := Vector3(cos(a) * 0.1, 0, sin(a) * 0.1)
				for q in 5:
					var c := Color(0.42, 0.6, 0.3).lerp(Color(0.72, 0.28, 0.28), q / 5.0)
					MeshKit.ball(st, p + Vector3(0, 0.05 + q * 0.075, 0), Vector3(0.028, 0.045, 0.028), c, 6, 4)
		"bangpung":  # 갯방풍: 모래 위 반질한 잎, 하얀 꽃우산
			for i in 6:
				var a := i * TAU / 6.0
				MeshKit.leaf(st, Vector3(0, 0.02, 0), Vector3(cos(a), 0.15, sin(a)), Vector3(0, 1, 0), 0.22, 0.12, Color(0.26, 0.46, 0.3), 0.05, "round")
			MeshKit.tube(st, Vector3(0, 0, 0), Vector3(0, 0.34, 0), 0.016, 0.012, Color(0.58, 0.46, 0.42), 5)
			for q in 10:
				var b := q * TAU / 10.0
				var e := Vector3(cos(b) * 0.09, 0.4, sin(b) * 0.09)
				MeshKit.tube(st, Vector3(0, 0.34, 0), e, 0.004, 0.004, Color(0.6, 0.5, 0.45), 3)
				MeshKit.ball(st, e, Vector3.ONE * 0.022, Color(1, 1, 0.95), 5, 4)
		"haedang":  # 해당화: 덤불 잎, 분홍 꽃, 주황빛 둥근 열매
			for i in 12:
				var a := r.randf() * TAU
				MeshKit.leaf(st, Vector3(cos(a) * 0.08, r.randf_range(0.12, 0.42), sin(a) * 0.08), Vector3(cos(a), 0.2, sin(a)), Vector3(0, 1, 0), 0.14, 0.08, Color(0.26, 0.48, 0.24), 0.2)
			for i in 3:
				MeshKit.flower(st, Vector3(r.randf_range(-0.18, 0.18), 0.5, r.randf_range(-0.18, 0.18)), 5, 0.08, 0.08, Color(0.95, 0.45, 0.65), Color(1.0, 0.85, 0.3), 0.3)
			for i in 5:
				MeshKit.ball(st, Vector3(r.randf_range(-0.2, 0.2), r.randf_range(0.28, 0.45), r.randf_range(-0.2, 0.2)), Vector3.ONE * 0.04, Color(0.95, 0.4, 0.12), 8, 5)
		"mindeulle":  # 민들레: 톱니 잎 방석, 노란 꽃, 하얀 솜털 공
			for i in 8:
				var a := i * TAU / 8.0
				MeshKit.leaf(st, Vector3(0, 0.02, 0), Vector3(cos(a), 0.08, sin(a)), Vector3(0, 1, 0), 0.24, 0.07, G, 0.02, "tooth")
			MeshKit.tube(st, Vector3(0, 0, 0), Vector3(0.05, 0.3, 0), 0.01, 0.008, Color(0.45, 0.6, 0.3), 4)
			MeshKit.flower(st, Vector3(0.05, 0.3, 0), 12, 0.06, 0.02, Color(1.0, 0.82, 0.12), Color(1.0, 0.7, 0.1), 0.35)
			MeshKit.tube(st, Vector3(0, 0, 0), Vector3(-0.06, 0.38, 0.04), 0.008, 0.007, Color(0.45, 0.6, 0.3), 4)
			MeshKit.ball(st, Vector3(-0.06, 0.41, 0.04), Vector3.ONE * 0.05, Color(0.97, 0.97, 0.95), 8, 6)
		"jilgyeong":  # 질경이: 넓은 타원 잎 방석, 가는 꽃대
			for i in 7:
				var a := i * TAU / 7.0
				MeshKit.leaf(st, Vector3(0, 0.02, 0), Vector3(cos(a), 0.25, sin(a)), Vector3(0, 1, 0), 0.22, 0.12, Color(0.3, 0.52, 0.26), 0.12)
			for i in 3:
				var top := Vector3(r.randf_range(-0.06, 0.06), 0.42, r.randf_range(-0.06, 0.06))
				MeshKit.tube(st, Vector3(0, 0, 0), top, 0.008, 0.006, Color(0.42, 0.55, 0.3), 4)
				MeshKit.tube(st, top, top + Vector3(0, 0.12, 0), 0.016, 0.01, Color(0.6, 0.55, 0.36), 5)
		"jebikkot":  # 제비꽃: 하트 잎과 보라 꽃
			for i in 6:
				var a := i * TAU / 6.0
				MeshKit.leaf(st, Vector3(0, 0.02, 0), Vector3(cos(a), 0.45, sin(a)), Vector3(0, 1, 0), 0.12, 0.1, Color(0.3, 0.55, 0.28), 0.1, "heart")
			for i in 4:
				var fc := Vector3(r.randf_range(-0.1, 0.1), 0.2, r.randf_range(-0.1, 0.1))
				MeshKit.tube(st, Vector3(0, 0, 0), fc, 0.006, 0.006, Color(0.4, 0.58, 0.3), 3)
				MeshKit.flower(st, fc, 5, 0.045, 0.035, Color(0.52, 0.3, 0.82), Color(1.0, 0.95, 0.85), 0.1, Vector3(0.3, 0.6, 0.6))
		"nepip":  # 네잎클로버: 세잎 사이에 숨은 네 잎
			for i in 10:
				var c := Vector3(r.randf_range(-0.24, 0.24), 0.0, r.randf_range(-0.24, 0.24))
				var nl := 4 if i == 0 else 3
				var top := c + Vector3(0, 0.07 if i != 0 else 0.11, 0)
				MeshKit.tube(st, c, top, 0.005, 0.005, Color(0.36, 0.55, 0.3), 3)
				for q in nl:
					var b := q * TAU / nl + r.randf() * 0.5
					MeshKit.leaf(st, top, Vector3(cos(b), 0.05, sin(b)), Vector3(0, 1, 0), 0.05, 0.05, Color(0.3, 0.62, 0.3) if i != 0 else Color(0.4, 0.8, 0.38), 0.0, "heart")
	var mesh := MeshKit.finish(st)
	herb_mesh_cache[k] = mesh
	return mesh

# ---------- 도감 "엔딩" 쪽: 이야기마다 본 결말과 못 본 결말(??? + 힌트) ----------
var ending_page: Control
var ending_tale := "ch1"
var ending_tale_buttons := {}
var ending_rows: Array = []   # [바탕 Panel, 글 Label]

func make_ending_page(page: Control) -> void:
	ending_page = Control.new()
	ending_page.visible = false
	page.add_child(ending_page)
	place(ending_page, 0.04, 0.165, 0.96, 0.82)
	var tx := 0.0
	for t in TALE_IDS:
		var b := Button.new()
		b.clip_text = true
		ending_page.add_child(b)
		place(b, tx, 0.0, tx + 0.32, 0.1)
		b.pressed.connect(func():
			sfx("tap")
			show_ending_tale(t))
		ending_tale_buttons[t] = b
		tx += 0.34
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	ending_page.add_child(box)
	place(box, 0.0, 0.12, 1.0, 1.0)
	for i in 4:
		var pnl := PanelContainer.new()
		pnl.size_flags_vertical = Control.SIZE_EXPAND_FILL
		box.add_child(pnl)
		var lb := Label.new()
		style(lb, 0.62)
		lb.add_theme_color_override("font_color", INK)
		lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lb.size_flags_vertical = Control.SIZE_EXPAND_FILL
		pnl.add_child(lb)
		ending_rows.append([pnl, lb])

var request_page: ScrollContainer
var request_rows_ui: Array = []

func make_request_page(page: Control) -> void:
	request_page = ScrollContainer.new()
	request_page.visible = false
	request_page.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(request_page)
	place(request_page, 0.04, 0.165, 0.96, 0.82)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	request_page.add_child(box)
	for i in REQUESTS_KO.size():
		var pnl := PanelContainer.new()
		pnl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_child(pnl)
		var lb := Label.new()
		style(lb, 0.52)
		lb.add_theme_color_override("font_color", INK)
		lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lb.custom_minimum_size = Vector2(0, font_size * 1.5)
		lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		pnl.add_child(lb)
		request_rows_ui.append([pnl, lb])

func show_request_page() -> void:
	var rows := request_rows()
	for i in request_rows_ui.size():
		var pnl: PanelContainer = request_rows_ui[i][0]
		var lb: Label = request_rows_ui[i][1]
		pnl.visible = i < rows.size()
		if i >= rows.size():
			continue
		var done: bool = rows[i][0]
		var asked: bool = not done and not String(rows[i][1]).begins_with("???")
		var box := make_round(Color(1.0, 0.95, 0.8) if done else (Color(1.0, 0.9, 0.7) if asked else Color(0.88, 0.84, 0.76)), font_size * 0.3)
		box.set_content_margin_all(font_size * 0.3)
		pnl.add_theme_stylebox_override("panel", box)
		lb.text = rows[i][1]
		lb.add_theme_color_override("font_color", INK if done or asked else Color(0.45, 0.4, 0.35))
	request_page.scroll_vertical = 0

func show_ending_tale(t: String) -> void:
	ending_tale = t
	var done := tales_done_list().has(t)
	var seen := endings_seen(t)
	for k in ending_tale_buttons:
		var b: Button = ending_tale_buttons[k]
		var n := endings_seen(k).size()
		b.text = "%s %d/%d" % [TALE_SHORT[k], n, ending_total(k)]
		var on: bool = k == t
		skin_button(b, make_round(Color(0.95, 0.72, 0.3) if on else Color(0.9, 0.84, 0.7), font_size * 0.3), INK, 0.58)
	var list: Array = ENDINGS.get(t, [])
	for i in ending_rows.size():
		var pnl: PanelContainer = ending_rows[i][0]
		var lb: Label = ending_rows[i][1]
		pnl.visible = i < list.size()
		if i >= list.size():
			continue
		var e: Array = list[i]
		var got := seen.has(e[0])
		var box := make_round(Color(1.0, 0.95, 0.8) if got else Color(0.88, 0.84, 0.76), font_size * 0.3)
		box.set_content_margin_all(font_size * 0.35)
		pnl.add_theme_stylebox_override("panel", box)
		if got:
			lb.text = "★ %s\n%s" % [e[1], e[2]]
			lb.add_theme_color_override("font_color", INK)
		elif done:
			lb.text = "??? \n" + tr("힌트: %s") % e[3]
			lb.add_theme_color_override("font_color", Color(0.45, 0.4, 0.35))
		else:
			lb.text = "??? \n" + tr("이야기를 끝내면 힌트가 보여요.")
			lb.add_theme_color_override("font_color", Color(0.45, 0.4, 0.35))

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
		6:
			for x in [-0.3, 0.0, 0.3]:
				d_line(ci, c + Vector2(0, s * 0.85), c + Vector2(x * s, -s * 0.3), L, 3)
				ci.draw_arc(c + Vector2(x * s + s * 0.08, -s * 0.38), s * 0.1, 0.0, TAU * 0.8, 12, shade if dark else Color(0.5, 0.58, 0.3), 4.0)
		7:
			for i in 5:
				var a := -1.2 + i * 0.6
				d_ell(ci, c + Vector2(0, s * 0.4) + Vector2(0, -s * 0.4).rotated(a), s * 0.22, s * 0.3, L, a, ol)
		8:
			for i in 3:
				d_ell(ci, c + Vector2((i - 1) * s * 0.35, -s * 0.35), s * 0.2, s * 0.1, L, (i - 1) * 0.5, ol)
			for k in 7:
				ci.draw_circle(c + Vector2((k % 2) * s * 0.1 - s * 0.05, -s * 0.15 + k * s * 0.1), s * 0.08, shade if dark else Color(0.85, 0.1, 0.15))
		9:
			d_line(ci, c + Vector2(-s * 0.6, s * 0.7), c + Vector2(s * 0.6, s * 0.55), shade if dark else Color(0.5, 0.38, 0.26), 9)
			for i in 3:
				var a := -0.9 + i * 0.9
				d_ell(ci, c + Vector2(0, -s * 0.1) + Vector2(0, -s * 0.35).rotated(a), s * 0.2, s * 0.3, L, a, ol)
		10:
			d_box(ci, c + Vector2(0, s * 0.5), Vector2(s * 0.9, s * 0.6), 0.0, shade if dark else Color(0.45, 0.32, 0.2), ol)
			for i in 3:
				d_ell(ci, c + Vector2((i - 1) * s * 0.3, s * 0.15 - i * s * 0.15), s * 0.28, s * 0.12, shade if dark else Color(0.55, 0.18, 0.1), 0.0, ol)
		11:
			d_ell(ci, c + Vector2(0, s * 0.7), s * 0.45, s * 0.18, shade if dark else Color(0.35, 0.35, 0.38), 0.0, ol)
			for x in [-0.25, 0.0, 0.25]:
				for k in 4:
					ci.draw_circle(c + Vector2(x * s, s * 0.45 - k * s * 0.22), s * 0.08, shade if dark else Color(0.42, 0.3, 0.12))
		12:
			for x in [-0.25, 0.0, 0.25]:
				var pts := PackedVector2Array()
				for k in 7:
					pts.append(c + Vector2(x * s + sin(k * 1.1 + x * 9.0) * s * 0.1, s * 0.8 - k * s * 0.25))
				ci.draw_polyline(pts, shade if dark else Color(0.22, 0.4, 0.18), s * 0.14)
		13:
			for x in [-0.3, -0.1, 0.1, 0.3]:
				for k in 4:
					ci.draw_circle(c + Vector2(x * s, s * 0.6 - k * s * 0.28), s * 0.08, shade if dark else Color(0.45, 0.6, 0.3).lerp(Color(0.75, 0.3, 0.3), k / 4.0))
		14:
			for i in 4:
				d_ell(ci, c + Vector2((i - 1.5) * s * 0.3, s * 0.55), s * 0.2, s * 0.1, L, 0.0, ol)
			d_line(ci, c + Vector2(0, s * 0.5), c + Vector2(0, -s * 0.3), shade if dark else Color(0.55, 0.45, 0.4), 4)
			for k in 7:
				ci.draw_circle(c + Vector2(cos(k * 0.9) * s * 0.25, -s * 0.35 + sin(k * 0.9) * s * 0.08), s * 0.07, shade if dark else Color(1, 1, 0.95))
		15:
			for i in 5:
				d_ell(ci, c + Vector2((i - 2) * s * 0.22, s * 0.3 - (i % 2) * s * 0.2), s * 0.18, s * 0.1, L, (i - 2) * 0.3, ol)
			for k in 4:
				ci.draw_circle(c + Vector2((k - 1.5) * s * 0.25, -s * 0.15 + (k % 2) * s * 0.12), s * 0.1, shade if dark else Color(0.95, 0.45, 0.15))
		16:
			for i in 5:
				d_ell(ci, c + Vector2((i - 2) * s * 0.2, s * 0.7), s * 0.18, s * 0.06, L, (i - 2) * 0.3, ol)
			d_line(ci, c + Vector2(0, s * 0.7), c + Vector2(0, -s * 0.2), L, 3)
			ci.draw_circle(c + Vector2(0, -s * 0.3), s * 0.2, shade if dark else Color(1.0, 0.85, 0.15))
		17:
			for i in 5:
				d_ell(ci, c + Vector2((i - 2) * s * 0.2, s * 0.6), s * 0.15, s * 0.28, L, (i - 2) * 0.4, ol)
			for x in [-0.15, 0.15]:
				d_line(ci, c + Vector2(x * s, s * 0.5), c + Vector2(x * s, -s * 0.6), shade if dark else Color(0.6, 0.55, 0.35), 4)
		18:
			for i in 3:
				d_ell(ci, c + Vector2((i - 1) * s * 0.3, s * 0.55), s * 0.16, s * 0.14, L, 0.0, ol)
			for k in 5:
				var b := k * TAU / 5.0
				d_ell(ci, c + Vector2(cos(b), sin(b)) * s * 0.18 + Vector2(0, -s * 0.2), s * 0.13, s * 0.08, shade if dark else Color(0.52, 0.3, 0.8), b, 0.0 if dark else 2.0)
		19:
			for k in 4:
				var b := k * TAU / 4.0 + PI / 4.0
				d_ell(ci, c + Vector2(cos(b), sin(b)) * s * 0.25, s * 0.22, s * 0.16, shade if dark else Color(0.35, 0.72, 0.35), b, ol)
			d_line(ci, c, c + Vector2(s * 0.2, s * 0.7), L, 3)

func draw_book() -> void:
	var ci: CanvasItem = book_canvas
	var sz := book_canvas.size
	var list: Array = fish_in(book_village) if book_tab == "fish" else herbs_in(book_village)
	if list.is_empty():
		ci.draw_string(font, Vector2(0, sz.y * 0.45), tr("준비 중이에요. 곧 이 마을에도 생겨요!"), HORIZONTAL_ALIGNMENT_CENTER, sz.x, int(font_size * 0.7), Color(0.45, 0.35, 0.25))
		return
	var n := list.size()
	# 여섯 개까지는 큰 카드(그림 위, 글 아래), 그보다 많으면 가로 카드(그림 왼쪽, 글 오른쪽) 두 줄
	var wide := n > 6
	var cols := 2
	var rows := maxi(3, ceili(float(n) / cols))
	var cw := sz.x / cols
	var ch := sz.y / rows
	var fs := int(font_size * (0.6 if wide else 0.72))
	var small := int(font_size * (0.46 if wide else 0.55))
	var rarity := [tr("흔함"), tr("보통"), tr("드묾"), tr("아주 드묾")]
	for k in n:
		var i: int = list[k]
		var cc := Vector2(cw * (k % cols) + cw / 2.0, ch * (k / cols) + ch / 2.0)
		var got := false
		var name_t := "???"
		var sub := ""
		var hint := ""
		if book_tab == "fish":
			var f: Dictionary = FISH[i]
			got = int(fish_caught[i]) > 0
			hint = f["hint"]
			if got:
				name_t = f["name"]
				sub = tr("바닷속에서 보았어요") if f["place"] == "ch3_sea" else tr("%d마리 낚음 | %d냥") % [fish_caught[i], f["pay"]]
			else:
				sub = rarity[int(f["rare"])]
		else:
			got = int(herb_counts[i]) >= HERB_NEED
			if int(herb_counts[i]) > 0:
				name_t = HERBS[i]["name"]
			sub = "%d/%d  %s" % [mini(int(herb_counts[i]), HERB_NEED), HERB_NEED, HERBS[i]["hint"] if not got else tr("완성!")]
		var card_col := Color(1.0, 0.97, 0.88) if got else Color(0.9, 0.86, 0.78)
		d_box(ci, cc, Vector2(cw - 12, ch - 10), 0.0, card_col, 3.0)
		if wide:
			var pc := cc + Vector2(-cw * 0.27, 0)
			if book_tab == "fish":
				var fl: float = FISH[i]["len"]
				draw_fish2d(ci, pc, minf(cw * 0.15 / maxf(1.0, fl), ch * 0.3), i, 0.0, not got)
			else:
				draw_herb2d(ci, pc, ch * 0.3, i, int(herb_counts[i]) == 0)
			if got:
				ci.draw_circle(cc + Vector2(cw * 0.42, -ch * 0.3), 8, Color(0.95, 0.4, 0.3))
			var tx := cc.x - cw * 0.14
			var tw := cw * 0.6
			var ty := cc.y - ch * 0.5 + (ch - (fs + small * 2.3)) * 0.5 + fs * 0.85
			ci.draw_string(font, Vector2(tx, ty), name_t, HORIZONTAL_ALIGNMENT_LEFT, tw, fs, INK)
			ci.draw_string(font, Vector2(tx, ty + small * 1.2), sub, HORIZONTAL_ALIGNMENT_LEFT, tw, small, Color(0.45, 0.35, 0.25))
			if hint != "":
				ci.draw_string(font, Vector2(tx, ty + small * 2.35), hint, HORIZONTAL_ALIGNMENT_LEFT, tw, small, Color(0.3, 0.45, 0.55))
			continue
		var big := true
		var pic := cc + Vector2(0, -ch * (0.12 if hint != "" else 0.1))
		if book_tab == "fish":
			draw_fish2d(ci, pic, minf(cw * 0.22, ch * 0.3), i, 0.0, not got)
		else:
			draw_herb2d(ci, pic, ch * 0.22, i, int(herb_counts[i]) == 0)
		if got:
			ci.draw_circle(cc + Vector2(cw * 0.36, -ch * 0.34), 12 if big else 9, Color(0.95, 0.4, 0.3))
		var y0 := cc.y + ch * (0.18 if hint != "" else 0.26)
		ci.draw_string(font, Vector2(cc.x - cw / 2.0, y0), name_t, HORIZONTAL_ALIGNMENT_CENTER, cw, fs, INK)
		ci.draw_string(font, Vector2(cc.x - cw / 2.0 + 6, y0 + fs * 1.05), sub, HORIZONTAL_ALIGNMENT_CENTER, cw - 12, small, Color(0.45, 0.35, 0.25))
		if hint != "":
			ci.draw_string(font, Vector2(cc.x - cw / 2.0 + 6, y0 + fs * 1.05 + small * 1.15), hint, HORIZONTAL_ALIGNMENT_CENTER, cw - 12, small, Color(0.3, 0.45, 0.55))

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
		ask("", tr("어디부터 다시 할까요?\n- 이 이야기만: 지금 있는 마을의 이야기만 처음으로 (엽전, 물건, 다른 마을은 그대로)\n- 모두: 처음부터 새로 (도감, 엔딩 기록, 설정은 남아요)"), [tr("이 이야기만 처음부터"), tr("모두 처음부터"), tr("그만둘래요")], func(i: int):
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

# 검지로 화면을 누르는 손 (손끝이 tip 자리). 손등이 보이는 오른손을 부드러운 곡선 한 줄로 그려요
const HAND_OUTLINE := [
	Vector2(0, -2), Vector2(6, -0.5), Vector2(10, 4), Vector2(11, 12), Vector2(11, 30), Vector2(11.5, 46),
	Vector2(14, 50), Vector2(20, 49), Vector2(25, 52), Vector2(28, 56), Vector2(32, 57), Vector2(36, 61), Vector2(37, 67),
	Vector2(39, 71), Vector2(39, 78), Vector2(36, 84), Vector2(33, 92), Vector2(28, 100), Vector2(24, 106),
	Vector2(-14, 106), Vector2(-18, 98), Vector2(-21, 88), Vector2(-26, 80), Vector2(-34, 72), Vector2(-40, 64),
	Vector2(-41, 58), Vector2(-37, 55), Vector2(-30, 57), Vector2(-22, 62), Vector2(-15, 64), Vector2(-12, 56),
	Vector2(-11, 30), Vector2(-11, 12), Vector2(-10, 4), Vector2(-6, -0.5), Vector2(0, -2),
]

func hand_pts(tip: Vector2, k: float, pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in smooth_line(pts, 2.0):
		out.append(tip + (p as Vector2) * k)
	return out

func draw_finger_hand(ci: CanvasItem, tip: Vector2, r: float) -> void:
	var k := r / 105.0
	var skin := Color(1.0, 0.85, 0.72)
	var shade := Color(0.93, 0.72, 0.6)
	var line := Color(0.5, 0.3, 0.2)
	# 소매 (주인공 파란 옷)
	var cuff := PackedVector2Array([tip + Vector2(-20, 100) * k, tip + Vector2(30, 100) * k, tip + Vector2(33, 132) * k, tip + Vector2(-23, 132) * k])
	ci.draw_colored_polygon(cuff, Color(0.33, 0.5, 0.82))
	ci.draw_polyline(cuff + PackedVector2Array([cuff[0]]), line, 3.0, true)
	ci.draw_line(tip + Vector2(-21, 106) * k, tip + Vector2(31, 106) * k, Color(0.9, 0.93, 1.0), 4.0, true)
	# 그림자 (살짝 아래 오른쪽)
	var outline := hand_pts(tip, k, HAND_OUTLINE)
	var sh := PackedVector2Array()
	for p in outline:
		sh.append(p + Vector2(4, 5) * k)
	ci.draw_colored_polygon(sh, Color(0, 0, 0, 0.22))
	# 손 바탕
	ci.draw_colored_polygon(outline, skin)
	# 손등 오른쪽은 살짝 그늘
	var dark := hand_pts(tip, k, [Vector2(14, 58), Vector2(26, 60), Vector2(35, 68), Vector2(36, 80), Vector2(30, 96), Vector2(22, 104), Vector2(16, 100), Vector2(20, 84), Vector2(18, 68), Vector2(14, 58)])
	ci.draw_colored_polygon(dark, shade)
	# 손등 밝은 부분
	d_ell(ci, tip + Vector2(-2, 80) * k, 10 * k, 13 * k, Color(1.0, 0.92, 0.84), -0.2, 0.0)
	ci.draw_polyline(outline, line, 3.5, true)
	# 검지 손톱과 마디 주름
	var nail := hand_pts(tip, k, [Vector2(-6, 3), Vector2(0, 1), Vector2(6, 3), Vector2(6.5, 11), Vector2(0, 13), Vector2(-6.5, 11), Vector2(-6, 3)])
	ci.draw_colored_polygon(nail, Color(1.0, 0.93, 0.9))
	ci.draw_polyline(nail, Color(0.82, 0.6, 0.52), 2.0, true)
	for cy in [24.0, 40.0]:
		ci.draw_polyline(hand_pts(tip, k, [Vector2(-6, cy), Vector2(0, cy + 1.5), Vector2(6, cy)]), Color(0.78, 0.55, 0.45), 2.0, true)
	# 접힌 손가락 사이 선과 마디
	ci.draw_polyline(hand_pts(tip, k, [Vector2(13, 52), Vector2(15, 58), Vector2(16, 64)]), line, 2.5, true)
	ci.draw_polyline(hand_pts(tip, k, [Vector2(27, 57), Vector2(27, 63), Vector2(26, 68)]), line, 2.5, true)
	ci.draw_polyline(hand_pts(tip, k, [Vector2(36, 66), Vector2(33, 72), Vector2(30, 75)]), line, 2.5, true)
	# 엄지 경계
	ci.draw_polyline(hand_pts(tip, k, [Vector2(-15, 64), Vector2(-14, 74), Vector2(-16, 84)]), Color(0.78, 0.55, 0.45), 2.5, true)
	# 엄지 손톱
	d_ell(ci, tip + Vector2(-35, 60) * k, 4.5 * k, 3.5 * k, Color(1.0, 0.93, 0.9), -0.5, 1.5)

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
	# 누른 자리에 퍼지는 물결
	ci.draw_arc(knob, r * (0.18 + 0.12 * push), 0, TAU, 32, Color(1, 1, 1, 0.5 + 0.4 * push), 4, true)
	draw_finger_hand(ci, knob, r)
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


# ---------- 다른 이야기의 이야기 조각 (오누이 고갯길, 바닷가 마을) ----------
# 저장: [common] book story {"ch2": [5칸], "ch3": [5칸], "home": [5칸]}. 이야기 조각 자리 이름표는 "ch2:0" 처럼 묶음:번호
const TALE_GROUPS := ["ch1", "ch2", "ch3", "home"]
const STORY_SHORT_KO := {"ch1": "흥부", "ch2": "해와 달", "ch3": "별주부", "home": "이야기골"}
var STORY_SHORT: Dictionary = trd(STORY_SHORT_KO)
var TALES := {
	"ch2": [
		{"title": tr("엄마의 떡 광주리"), "hint": tr("잔칫집 떡집 아궁이 뒤"), "text": tr("엄마는 잔칫집 일을 마치면 늘 떡 광주리를 이고 고개를 넘었어요.\n광주리 맨 밑에는 오누이 몫으로 떡 두 개를 꼭 숨겨 두었지요.\n고개마다 떡을 하나씩 내주면서도 그 두 개만은 끝까지 지켰어요.\n“우리 애들 먹을 건 내 손으로 지킬 거야.”")},
		{"title": tr("오빠의 첫 나무 오르기"), "hint": tr("오두막 우물가 나무 뒤"), "text": tr("오빠가 처음 우물가 나무에 오른 건 일곱 살 때였어요.\n가지 끝에서 내려오지 못해 그만 엉엉 울었지요.\n그때 누이가 나무 밑에서 노래를 불러 주었어요.\n오빠는 그날부터 누이 앞에서는 울지 않기로 했어요.")},
		{"title": tr("누이가 무서워한 밤"), "hint": tr("오두막 앞 (반딧불을 다 모으면)"), "text": tr("누이는 어둠이 무서워 밤마다 엄마 치맛자락을 붙잡고 잤어요.\n엄마가 늦는 날이면 오빠가 반딧불을 잡아 박 속에 넣어 주었지요.\n“이건 달님 조각이야. 달님이 지켜 준대.”\n누이가 밤 대신 해를 맡고 싶어 한 건 그 밤들 때문이었어요.")},
		{"title": tr("서낭당에 빈 소원"), "hint": tr("세 고개 서낭당에 돌을 모두 얹으면"), "text": tr("고개를 넘는 사람들은 서낭당 돌무더기에 돌을 얹고 빌었어요.\n엄마도 고개를 넘을 때마다 늘 같은 소원을 빌었지요.\n“제 걱정일랑 말고, 우리 애들만 무사하게 해 주세요.”\n돌무더기는 그 많은 소원을 하나도 잊지 않고 품고 있었어요.")},
		{"title": tr("하늘에서 내려다본 고갯길"), "hint": tr("약초꾼 할아버지의 부탁"), "text": tr("해님이 된 누이는 날마다 하늘에서 고갯길을 내려다보았어요.\n떡을 이고 고개를 넘는 사람이 보이면 햇볕을 더 따뜻하게 비추었지요.\n밤이 되면 달님이 된 오빠가 그 길을 환하게 밝혔어요.\n그래서 이 고갯길에선 길 잃는 사람이 없대요.")},
	],
	"ch3": [
		{"title": tr("자라가 처음 뭍에 오른 날"), "hint": tr("서쪽 갯바위 낚시터 근처"), "text": tr("어린 자라가 처음 뭍에 올라온 곳은 이 갯바위였어요.\n햇볕이 너무 뜨거워 등껍질 속에 머리를 쏙 넣고 하루를 버텼지요.\n그날부터 자라는 뭍 짐승 얼굴을 그려 두는 버릇이 생겼어요.\n토끼를 한눈에 알아본 건 그 그림 덕분이었답니다.")},
		{"title": tr("토끼의 뒷산 굴"), "hint": tr("뒷산 숲 산삼 자리 근처"), "text": tr("토끼의 굴은 뒷산 바위틈에 있어요. 입구가 셋이나 되지요.\n하나는 여우를 피하는 문, 하나는 매를 피하는 문,\n마지막 하나는 친구들이 놀러 올 때 쓰는 문이에요.\n토끼는 겁이 많아서 꾀가 늘었대요.")},
		{"title": tr("용왕님의 젊은 시절"), "hint": tr("용궁 전각 옆"), "text": tr("젊은 용왕은 바다에서 가장 빠른 헤엄꾼이었어요.\n태풍이 오면 앞장서서 물고기 떼를 깊은 곳으로 이끌었지요.\n그렇게 바다를 지키다 얻은 병이 오래 낫지 않았던 거예요.\n신하들이 뭍까지 약을 찾아 나선 건 그런 용왕을 아꼈기 때문이에요.")},
		{"title": tr("넙치 형제의 숨바꼭질"), "hint": tr("용궁 문 넙치 문지기"), "text": tr("넙치 형제는 열두 마리, 모두 두 눈이 한쪽에 몰려 있어요.\n어릴 적 숨바꼭질하다 모래 속에 너무 오래 숨은 탓이래요.\n맏형이 문지기가 된 건 술래를 한 번도 진 적이 없어서예요.\n그래서 넙치 앞에서는 아무도 몰래 지나가지 못한대요.")},
		{"title": tr("문어 장군의 먹물"), "hint": tr("해녀의 부탁"), "text": tr("문어 장군은 무섭게 생겼지만 사실 수줍음이 많아요.\n놀라거나 부끄러우면 저도 모르게 먹물을 뿜어 버리지요.\n해녀가 처음 인사했을 때도 먹물을 뿜고 바위 뒤로 숨었대요.\n그 뒤로 둘은 먹물 없이 인사를 나누는 사이가 되었답니다.")},
	],
	"home": [
		{"title": tr("할머니가 책을 얻은 날"), "hint": tr("할머니 집 장독대 옆"), "text": tr("할머니가 그 책을 얻은 건 큰비가 그친 이튿날이었어요.\n장독대 옆 진흙 속에 겉장이 다 젖은 책 한 권이 묻혀 있었지요.\n할머니는 한 장 한 장 말리며 지워진 글자를 기억으로 메웠어요.\n그래서 그 책의 절반은 할머니 손글씨래요.")},
		{"title": tr("정자나무가 심어진 해"), "hint": tr("정자나무 뒤 (등불이 하나라도 켜지면)"), "text": tr("정자나무는 마을에 처음 아이가 태어난 해에 심었대요.\n아이가 자라 어른이 될 때마다 가지에 등불을 하나씩 걸었지요.\n사람들이 하나둘 떠나자 등불도 하나둘 꺼졌어요.\n나무는 그 등불들이 다시 켜지기를 지금도 기다린대요.")},
		{"title": tr("빈 집터의 옛 주인"), "hint": tr("서쪽 빈 집터 안"), "text": tr("이 집터에는 옛날 짚신 삼는 할아버지가 살았어요.\n마을을 떠나는 사람마다 새 짚신을 한 켤레씩 쥐여 주었지요.\n“먼 길 가다 지치면 이 신 신고 돌아오게.”\n돌 기단 밑에는 아직 짚신 한 켤레가 묻혀 있대요.")},
		{"title": tr("마을 이름 이야기골"), "hint": tr("이야기꾼 할머니의 부탁"), "text": tr("옛날 이 골짜기엔 이름이 없었어요.\n밤마다 사람들이 정자나무 아래 모여 옛이야기를 나누었는데,\n지나가던 나그네가 그 소리를 듣고 “여기는 이야기가 사는 골짜기로구나” 했대요.\n그날부터 이 마을은 이야기골이 되었답니다.")},
		{"title": tr("내 집의 지난 주인"), "hint": tr("내 집 방 안 (마을 도감을 다 채우면)"), "text": tr("내 집에 마지막으로 살던 사람은 떠돌이 이야기꾼이었어요.\n마을을 떠나며 궤짝 옆 벽 틈에 쪽지 하나를 끼워 두었지요.\n“이 집에 올 다음 사람에게. 이야기를 다 찾으면 꼭 들려주렴.”\n쪽지 끝에는 할머니가 아는 그 소년의 이름이 적혀 있었어요.")},
	],
}
var TALE_DONE := {
	"ch2": tr("고갯길 사람들은 지금도 해 질 녘이면 하늘을 올려다봐요.\n해님과 달님이 잠깐 함께 떠 있는 그 짧은 시간에\n오누이가 엄마에게 손을 흔든다고 믿거든요."),
	"ch3": tr("자라는 지금도 가끔 갯바위에 올라 뒷산을 바라봐요.\n토끼가 굴 앞에 앉아 귀를 쫑긋 세우면\n둘은 멀리서 모르는 척 고개를 한 번 끄덕인대요."),
	"home": tr("할머니는 쪽지를 오래오래 들여다보다 웃었어요.\n“그 아이가 결국 이 마을로 돌아왔었구나.”\n그날 밤 정자나무 아래에서 할머니는 처음으로 자기 이야기를 들려주었어요."),
}
const TALE_REWARD := 30
var tale_read := {"ch2": [false, false, false, false, false], "ch3": [false, false, false, false, false], "home": [false, false, false, false, false]}
var story_group := "ch1"

func tale_list(g: String) -> Array:
	if g == "ch1":
		return STORY
	return TALES.get(g, [])

func tale_flags(g: String) -> Array:
	if g == "ch1":
		return story_read
	return tale_read.get(g, [])

func tale_count(g: String) -> int:
	var n := 0
	for r in tale_flags(g):
		if r:
			n += 1
	return n

func tales_all_count() -> Array:
	var got := 0
	var tot := 0
	for g in TALE_GROUPS:
		got += tale_count(g)
		tot += tale_list(g).size()
	return [got, tot]

# 장마다 조각 자리가 나타나는 조건 (장 스크립트가 바꿔요)
func tale_spot_ready(_g: String, _i: int) -> bool:
	return true

func make_tale_spot(pos: Vector3, g: String, i: int) -> Node3D:
	var p := make_spot(pos, "tale", "%s:%d" % [g, i], "", true)
	make_piece_visual(p)
	return p

func tale_key(t: Dictionary) -> Array:
	var parts: PackedStringArray = String(t["id"]).split(":")
	return [parts[0], int(parts[1])]

# 조각 하나를 얻고, 보여 줄 대사 줄을 돌려줘요 (묶음을 다 모으면 엽전과 숨은 이야기도)
func tale_lines(g: String, i: int, extra: String = "") -> Array:
	var flags := tale_flags(g)
	var lines := []
	if i < 0 or i >= flags.size():
		return lines
	if extra != "":
		lines.append(["", extra])
	var st: Dictionary = tale_list(g)[i]
	var first: bool = not flags[i]
	flags[i] = true
	lines.append([tr("이야기 조각 “%s”") % st["title"], st["text"]])
	if first:
		lines.append(["", tr("새 이야기 조각을 찾았어요! 도감의 '이야기' %s 칸에서 다시 읽을 수 있어요. (%d/%d)") % [STORY_SHORT[g], tale_count(g), flags.size()]])
	var rk := "tale_" + g
	if g != "ch1" and tale_count(g) >= flags.size() and not book_rewards.has(rk):
		book_rewards[rk] = true
		lines.append([tr("숨은 이야기"), TALE_DONE.get(g, "")])
		lines.append(["", tr("%s 이야기 조각을 모두 모았어요! 엽전 %d냥을 받았어요.") % [STORY_SHORT[g], TALE_REWARD]])
		earn(TALE_REWARD)
	save_book()
	return lines

func get_tale(g: String, i: int, extra: String = "") -> void:
	var lines := tale_lines(g, i, extra)
	if lines.is_empty():
		return
	sfx("good")
	say(lines, func():
		update_quest_text()
		save_progress())


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
			# 한 줄로 이어진 매끈한 몸 (매 프레임 등뼈를 따라 다시 지어요)
			var body := MeshInstance3D.new()
			body.material_override = kit_material()
			n.add_child(body)
			n.set_meta("body", body)
			n.set_meta("from", at)
			n.set_meta("seed", rng.randf() * TAU)
		"kim":
			add_mbox(n, make_color(Color(0.86, 0.66, 0.4)), Vector3(0.14, 0.75, 0.14), Vector3(0, 0.05, 0))
			add_mbox(n, dark_wood_mat, Vector3(0.2, 0.08, 0.2), Vector3(0, 0.43, 0))
			n.set_meta("from", at)
		"sparrow":
			kit_instance(n, sparrow_mesh(), Vector3(0, 0.08, 0))
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
			var ground_back := (from - base) * Vector3(1, 0, 1)
			ground_back = ground_back.normalized() if ground_back.length() > 0.01 else Vector3(0, 0, 1)
			var climbed := maxf(head.y - base.y, 0.0)
			var gside := ground_back.cross(Vector3.UP).normalized()
			var sd: float = n.get_meta("seed", 0.0)
			# 등뼈: 주둥이 끝에서 꼬리 끝까지 0.9m. 땅에선 S자로 꿈틀, 기둥을 오를 땐 위는 기둥을 따라 곧게
			var spine := []
			for i in SNAKE_RINGS:
				var d := SNAKE_LEN * float(i) / float(SNAKE_RINGS - 1)
				var p: Vector3
				var wig := sin(anim_t * 9.0 + sd - d * 9.0) * 0.09 * clampf(d / 0.2, 0.0, 1.0)
				if d < climbed:
					p = Vector3(head.x, head.y - d, head.z) + Vector3(1, 0, 0) * wig * 0.35
				else:
					var g := d - climbed
					var start := head if climbed <= 0.0 else base
					p = start + ground_back * g + gside * wig
				spine.append(p - n.global_position + Vector3(0, 0.06, 0))
			n.get_meta("body").mesh = snake_mesh(spine, sd)
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
			var want := int(overall_progress() * 9.0)
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
				# 손이 있던 자리 그대로 심어요: 화면 칸 어긋남(픽셀)을 못줄 간격 비율로 바꿔요 (큰 화면에서도 같은 자리)
				var sc_i := 1.0 - int(it[0]) * 0.12
				var du := float(it[2]) / maxf(1.0, mg_overlay.size.x * 0.2 * sc_i)
				var p := plant_world_pos(it[0], it[1]).lerp(plant_world_pos(it[0], int(it[1]) + 1), du) + Vector3(0, 0.02, 0)
				var sd := MeshInstance3D.new()
				sd.mesh = rice_mesh(0, planted.size() % 3)
				sd.material_override = kit_material()
				sd.rotation.y = planted.size() * 1.7
				world_node(sd)
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
	var n := Node3D.new()
	world_node(n)
	if bad:
		kit_instance(n, paddle_mesh(), Vector3(0, 0.08, 0)).scale = Vector3.ONE * 1.25
	else:
		var mi := kit_instance(n, rice_clump_mesh(rng.randi() % 4))
		mi.scale = Vector3.ONE * 2.3
		mi.rotation = Vector3(rng.randf() * TAU, rng.randf() * TAU, 0)
	return n

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

# 물고기 표 (docs/collect_plan.md). 순서는 바꾸지 말고 끝에 이어 붙여요(저장은 id 로 해요).
# place: 잡는 곳, rare: 0 흔함 1 보통 2 드묾 3 아주 드묾, wx: 날씨에 따라 나오는 정도(배), hint: 도감에 보이는 곳·때
var FISH := [
	{"id": "pirami", "place": "ch1_pond", "rare": 0, "name": tr("피라미"), "hint": tr("남쪽 연못"), "pay": 3, "w": 30, "hard": 0.1, "col": Color(0.78, 0.84, 0.9), "len": 0.85, "thin": 0.34},
	{"id": "bungeo", "place": "ch1_pond", "rare": 0, "name": tr("붕어"), "hint": tr("남쪽 연못"), "pay": 4, "w": 28, "hard": 0.25, "col": Color(0.72, 0.64, 0.42), "len": 1.0, "thin": 0.48},
	{"id": "mikkuraji", "place": "ch1_pond", "rare": 1, "name": tr("미꾸라지"), "hint": tr("남쪽 연못 · 비 오는 날"), "wx": {"rain": 2.0}, "pay": 6, "w": 16, "hard": 0.5, "col": Color(0.58, 0.5, 0.32), "len": 1.5, "thin": 0.2},
	{"id": "ingeo", "place": "ch1_pond", "rare": 1, "name": tr("잉어"), "hint": tr("남쪽 연못 · 구름 낀 날"), "wx": {"cloudy": 2.0}, "pay": 8, "w": 14, "hard": 0.45, "col": Color(0.92, 0.58, 0.3), "len": 1.2, "thin": 0.44},
	{"id": "megi", "place": "ch1_pond", "rare": 2, "name": tr("메기"), "hint": tr("남쪽 연못 · 비 오는 날"), "wx": {"rain": 2.0}, "pay": 12, "w": 9, "hard": 0.7, "col": Color(0.38, 0.38, 0.34), "len": 1.35, "thin": 0.36},
	{"id": "gold_ingeo", "place": "ch1_pond", "rare": 3, "name": tr("금빛 잉어"), "hint": tr("남쪽 연못 · 맑은 날"), "wx": {"clear": 1.5}, "pay": 30, "w": 3, "hard": 0.9, "col": Color(1.0, 0.8, 0.22), "len": 1.2, "thin": 0.44},
	{"id": "beodeulchi", "place": "ch1_creek", "rare": 0, "name": tr("버들치"), "hint": tr("개울 여울 · 맑은 날"), "wx": {"clear": 1.5}, "pay": 3, "w": 30, "hard": 0.15, "col": Color(0.66, 0.66, 0.52), "len": 0.85, "thin": 0.3},
	{"id": "galgyeoni", "place": "ch1_creek", "rare": 1, "name": tr("갈겨니"), "hint": tr("개울 여울"), "pay": 5, "w": 20, "hard": 0.35, "col": Color(0.74, 0.8, 0.86), "len": 0.95, "thin": 0.32, "fin": Color(0.9, 0.45, 0.3)},
	{"id": "kkeokji", "place": "ch1_creek", "rare": 2, "name": tr("꺽지"), "hint": tr("개울 여울 · 구름, 비"), "wx": {"cloudy": 2.0, "rain": 2.0}, "pay": 10, "w": 9, "hard": 0.6, "col": Color(0.5, 0.46, 0.32), "len": 1.0, "thin": 0.44, "spots": Color(0.3, 0.28, 0.2)},
	{"id": "swiri", "place": "ch1_creek", "rare": 3, "name": tr("쉬리"), "hint": tr("개울 여울 · 맑은 날"), "wx": {"clear": 2.0}, "pay": 20, "w": 4, "hard": 0.8, "col": Color(0.85, 0.82, 0.7), "len": 1.05, "thin": 0.28, "stripe": Color(0.25, 0.3, 0.6)},
	{"id": "dongjagae", "place": "ch2_pool", "rare": 0, "name": tr("동자개"), "hint": tr("바위 웅덩이"), "pay": 4, "w": 30, "hard": 0.3, "col": Color(0.78, 0.62, 0.28), "len": 1.0, "thin": 0.32, "spots": Color(0.4, 0.3, 0.15)},
	{"id": "gajae", "place": "ch2_pool", "rare": 1, "name": tr("가재"), "hint": tr("웅덩이 가 돌 밑"), "pay": 6, "w": 0, "hard": 0.3, "col": Color(0.62, 0.36, 0.24), "len": 0.85, "thin": 0.28},
	{"id": "yeolmogeo", "place": "ch2_pool", "rare": 2, "name": tr("열목어"), "hint": tr("바위 웅덩이 · 안개"), "wx": {"mist": 2.5}, "pay": 14, "w": 10, "hard": 0.6, "col": Color(0.62, 0.56, 0.5), "len": 1.2, "thin": 0.34, "spots": Color(0.32, 0.24, 0.24)},
	{"id": "sancheoneo", "place": "ch2_pool", "rare": 3, "name": tr("산천어"), "hint": tr("바위 웅덩이 · 맑은 날"), "wx": {"clear": 2.0}, "pay": 22, "w": 4, "hard": 0.8, "col": Color(0.6, 0.66, 0.74), "len": 1.1, "thin": 0.34, "fin": Color(0.88, 0.45, 0.45), "spots": Color(0.32, 0.36, 0.52)},
	{"id": "mangdungeo", "place": "ch3_rock", "rare": 0, "name": tr("망둥어"), "hint": tr("갯바위"), "pay": 3, "w": 30, "hard": 0.15, "col": Color(0.66, 0.58, 0.44), "len": 1.0, "thin": 0.3, "spots": Color(0.42, 0.36, 0.26)},
	{"id": "noraemi", "place": "ch3_rock", "rare": 1, "name": tr("노래미"), "hint": tr("갯바위 · 구름 낀 날"), "wx": {"cloudy": 2.0}, "pay": 6, "w": 18, "hard": 0.4, "col": Color(0.58, 0.46, 0.3), "len": 1.05, "thin": 0.34, "spots": Color(0.35, 0.26, 0.16)},
	{"id": "ureok", "place": "ch3_rock", "rare": 1, "name": tr("우럭"), "hint": tr("갯바위"), "pay": 8, "w": 14, "hard": 0.5, "col": Color(0.36, 0.34, 0.32), "len": 1.1, "thin": 0.46},
	{"id": "gamseongdom", "place": "ch3_rock", "rare": 2, "name": tr("감성돔"), "hint": tr("갯바위 · 비 오는 날"), "wx": {"rain": 2.0}, "pay": 15, "w": 8, "hard": 0.7, "col": Color(0.58, 0.62, 0.68), "len": 1.1, "thin": 0.5},
	{"id": "doldom", "place": "ch3_rock", "rare": 3, "name": tr("돌돔"), "hint": tr("갯바위 · 맑은 날"), "wx": {"clear": 2.0}, "pay": 30, "w": 3, "hard": 0.9, "col": Color(0.86, 0.86, 0.8), "len": 1.05, "thin": 0.5, "bars": Color(0.15, 0.15, 0.18)},
	{"id": "songsari", "place": "home_pond", "rare": 0, "name": tr("송사리"), "hint": tr("이야기골 연못"), "pay": 2, "w": 30, "hard": 0.1, "col": Color(0.72, 0.74, 0.62), "len": 0.7, "thin": 0.26},
	{"id": "gaksi", "place": "home_pond", "rare": 1, "name": tr("각시붕어"), "hint": tr("이야기골 연못 · 맑은 날"), "wx": {"clear": 1.8}, "pay": 5, "w": 16, "hard": 0.3, "col": Color(0.78, 0.66, 0.6), "len": 0.85, "thin": 0.42, "fin": Color(0.95, 0.45, 0.4)},
	{"id": "napjaru", "place": "home_pond", "rare": 2, "name": tr("납자루"), "hint": tr("이야기골 연못 · 구름 낀 날"), "wx": {"cloudy": 2.0}, "pay": 9, "w": 8, "hard": 0.5, "col": Color(0.6, 0.66, 0.72), "len": 0.95, "thin": 0.4, "stripe": Color(0.3, 0.45, 0.65)},
	{"id": "moon_ingeo", "place": "home_pond", "rare": 3, "name": tr("달빛 잉어"), "hint": tr("이야기골 연못 · 밤에만"), "night_only": true, "pay": 25, "w": 6, "hard": 0.7, "col": Color(0.92, 0.94, 1.0), "len": 1.2, "thin": 0.44},
	{"id": "juldom", "place": "ch3_sea", "rare": 1, "name": tr("줄돔"), "hint": tr("바닷속 산호 숲"), "pay": 0, "w": 0, "hard": 0.3, "col": Color(0.98, 0.85, 0.3), "len": 1.0, "thin": 0.4, "tex": "sea_fish0"},
	{"id": "jwichi", "place": "ch3_sea", "rare": 1, "name": tr("쥐치"), "hint": tr("바닷속 해초 숲"), "pay": 0, "w": 0, "hard": 0.3, "col": Color(0.45, 0.72, 0.98), "len": 1.0, "thin": 0.4, "tex": "sea_fish1"},
	{"id": "bollak", "place": "ch3_sea", "rare": 2, "name": tr("볼락"), "hint": tr("바닷속 골짜기"), "pay": 0, "w": 0, "hard": 0.3, "col": Color(0.9, 0.45, 0.38), "len": 1.0, "thin": 0.4, "tex": "sea_fish2"},
	{"id": "deungbul", "place": "ch3_sea", "rare": 3, "name": tr("등불고기"), "hint": tr("깊은 골짜기"), "pay": 0, "w": 0, "hard": 0.3, "col": Color(0.55, 1.0, 0.9), "len": 1.0, "thin": 0.4, "tex": "sea_fish3"},
]
# 물고기 잡는 곳 (도감 마을 칸과 보상)
const FISH_PLACES_KO := {"ch1_pond": "남쪽 연못", "ch1_creek": "개울 여울", "ch2_pool": "바위 웅덩이", "ch3_rock": "갯바위", "ch3_sea": "바닷속", "home_pond": "이야기골 연못"}
var FISH_PLACES: Dictionary = trd(FISH_PLACES_KO)
var fish_caught: Array = zeros(FISH.size())
var fish_place := "ch1_pond"

func zeros(n: int) -> Array:
	var a := []
	a.resize(n)
	a.fill(0)
	return a

func fish_index(id: String) -> int:
	for i in FISH.size():
		if FISH[i]["id"] == id:
			return i
	return -1

# 한 곳(또는 한 마을: "ch1")의 물고기 번호들
func fish_in(where: String) -> Array:
	var out := []
	for i in FISH.size():
		var pl: String = FISH[i]["place"]
		if pl == where or pl.begins_with(where + "_"):
			out.append(i)
	return out

func fish_found_in(where: String) -> int:
	var n := 0
	for i in fish_in(where):
		if int(fish_caught[i]) > 0:
			n += 1
	return n

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
	update_exits(delta)
	if not wild_spots.is_empty():
		update_wild(delta)
	update_cam_hint(delta)
	update_walk_hint(delta)
	update_weather(delta)
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
		if is_instance_valid(body) and not body.has_meta("pose_lock"):
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
		if is_instance_valid(nbody) and not nbody.has_meta("pose_lock"):
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
	# 긴 이름(영어 이야기 조각 제목 등)이 대화 창을 화면 밖으로 밀지 않게 줄을 바꿔요
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	if kind == "tale":
		var k := tale_key(t)
		return not tale_flags(k[0])[k[1]] and tale_spot_ready(k[0], k[1])
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
	if kind == "piece" or kind == "tale":
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
		var jt := ""
		if t["id"] == "water":
			jt = tr("물 긷기")
		elif t["id"] == "wood":
			jt = tr("나무하기")
		elif t["id"] == "gam":
			jt = tr("감 따기")
		else:
			jt = tr("짚신 삼기")
		return jt + job_badge(t["id"])
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
		if request_talk(t["id"]):
			return
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
	elif kind == "tale":
		node.visible = false
		burst3d(above, Color(1.0, 0.85, 0.3), 20)
		var k := tale_key(t)
		get_tale(k[0], k[1])
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

# 다른 사람(마을 사람) 몸에 코드로 자세를 잡아요. legs = [왼 허벅지, 왼 정강이, 오른 허벅지, 오른 정강이]
# 자세를 잡는 동안은 숨쉬기·흔들기가 덮어쓰지 않게 pose_lock 표시를 붙여요 (풀 때는 release_pose)
func pose_other(body: Node3D, arm_l: Vector3, arm_r: Vector3, lean: float, legs: Array) -> void:
	if body == null or not body.has_meta("skel"):
		return
	if not body.has_meta("pose_lock"):
		body.set_meta("pose_lock", true)
		if body.has_meta("anim"):
			(body.get_meta("anim") as AnimationPlayer).stop()
	var skel: Skeleton3D = body.get_meta("skel")
	var bones: Dictionary = body.get_meta("bones")
	var adj: float = body.get_meta("arm_adj", 0.0)
	for side in ["L", "R"]:
		var sx := -1.0 if side == "L" else 1.0
		var arm: Vector3 = arm_l if side == "L" else arm_r
		var twist: Vector3 = (bones["arm" + side] as Array)[3] if bones.has("arm" + side) else Vector3.UP
		turn_bone(skel, bones, "arm" + side, [[Vector3.RIGHT, arm.x], [Vector3.BACK, -sx * (arm.y - adj)], [twist, sx * 0.9]])
		turn_bone(skel, bones, "fore" + side, [[Vector3.RIGHT, arm.z]])
		var li := 0 if side == "L" else 2
		turn_bone(skel, bones, "thigh" + side, [[Vector3.RIGHT, float(legs[li])]])
		turn_bone(skel, bones, "shin" + side, [[Vector3.RIGHT, float(legs[li + 1])]])
		turn_bone(skel, bones, "foot" + side, [[Vector3.RIGHT, -0.2]])
	turn_bone(skel, bones, "hips", [])
	turn_bone(skel, bones, "spine", [[Vector3.RIGHT, lean]])
	turn_bone(skel, bones, "head", [[Vector3.RIGHT, -lean * 0.6]])

func release_pose(body: Node3D) -> void:
	if body == null or not body.has_meta("pose_lock"):
		return
	body.remove_meta("pose_lock")
	if body.has_meta("skel"):
		(body.get_meta("skel") as Skeleton3D).reset_bone_poses()
	if body.has_meta("anim"):
		var ap: AnimationPlayer = body.get_meta("anim")
		if ap.has_animation("Idle"):
			ap.play("Idle")

# 몸(뼈대 있는 모델)을 찾아요: 마을 사람 노드 아래 skel 표시가 붙은 것
func body_of(n: Node3D) -> Node3D:
	if n == null:
		return null
	for c in n.get_children():
		if c is Node3D and (c as Node3D).has_meta("skel"):
			return c
	return null

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

# ---------- 미니게임 단계 (2026-11-28: 이야기 미니게임을 2~3단계로 길게) ----------
# cfg "rounds": [{바꿀 값...}, ...] 를 주면 한 단계를 이길 때마다 값을 바꿔 다음 단계를 이어서 해요.
# 남은 기회는 단계를 넘어 이어지고, 지면 처음 단계부터 다시. 별점은 모든 단계를 합쳐서 매겨요.
var mg_round := 0
var mg_round_total := 1
var mg_round_base: Dictionary = {}
var mg_hold := 0.0
var mg_carry_lives := -1
var mg_carry_perfect := true
var mg_first_lives := 3

# 여러 단계를 통틀어 얼마나 왔는지 (0~1). 나무 오르기·동아줄처럼 단계가 바뀌어도 이어서 오르는 놀이에 써요
func overall_progress() -> float:
	var goal := maxf(float(mg_cfg.get("goal", 1)), 0.001)
	var here := clampf(float(mg_count) / goal, 0.0, 1.0)
	if mg_type == "circle":
		here = clampf(mg_progress, 0.0, 1.0)
	return (float(mg_round) + here) / float(maxi(mg_round_total, 1))

# 품팔이 단골 표시 (흥부네 마을이 바꿔요)
func job_badge(_id: String) -> String:
	return ""

func round_cfg(i: int) -> Dictionary:
	var c := mg_round_base.duplicate()
	var rounds: Array = mg_round_base.get("rounds", [])
	if i > 0 and i - 1 < rounds.size():
		var o: Dictionary = rounds[i - 1]
		for k in o:
			c[k] = o[k]
	c["_round"] = i
	return c

# 단계 사이 안내: 화면 가운데 두루마리 띠에 "N단계 성공!"과 다음 단계 설명 (줄바꿈되어 화면 안에)
func round_banner(head: String, text: String, hold: float) -> void:
	var vs := get_viewport().get_visible_rect().size
	var pw := minf(vs.x * 0.86, font_size * 22.0)
	var pad := font_size * 0.7
	var inner := pw - pad * 2.0
	var hs := int(font_size * 1.3)
	var ts := int(font_size * 0.95)
	var hh: float = font.get_multiline_string_size(head, HORIZONTAL_ALIGNMENT_CENTER, inner, hs).y
	var th: float = font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, inner, ts).y
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", make_round(Color(1.0, 0.96, 0.86, 0.94), font_size * 0.5))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size = Vector2(pw, pad * 2.0 + hh + th + font_size * 0.3)
	panel.position = Vector2((vs.x - pw) / 2.0, vs.y * 0.42 - panel.size.y / 2.0)
	fx_layer.add_child(panel)
	var y := pad
	for row in [[head, hs, Color(0.78, 0.4, 0.08), hh], [text, ts, INK, th]]:
		var lb := Label.new()
		lb.text = row[0]
		lb.add_theme_font_override("font", font)
		lb.add_theme_font_size_override("font_size", row[1])
		lb.add_theme_color_override("font_color", row[2])
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lb.position = Vector2(pad, y)
		lb.size = Vector2(inner, row[3])
		panel.add_child(lb)
		y += float(row[3]) + font_size * 0.3
	panel.pivot_offset = panel.size / 2.0
	pop(panel, 1.1)
	var tw := panel.create_tween()
	tw.tween_interval(maxf(hold - 0.35, 0.3))
	tw.tween_property(panel, "modulate:a", 0.0, 0.35)
	tw.tween_callback(panel.queue_free)

func next_round() -> void:
	mg_carry_lives = maxi(mg_lives, 1)
	mg_carry_perfect = mg_perfect
	mg_round += 1
	var t := mg_type
	var d := mg_done
	# 이번 단계를 치우고 (카메라와 장면은 같은 프레임에 다시 차려요) 다음 단계를 차려요
	mg_active = false
	if mg_world:
		world_game_end()
	for child in mg_stage.get_children():
		# 지울 그림판은 바로 숨겨요 (이번 프레임에 새 그림판 대신 그려지지 않게)
		if child is CanvasItem:
			(child as CanvasItem).visible = false
		child.queue_free()
	mg_items = []
	start_game(t, round_cfg(mg_round), d)

func start_game(type: String, cfg: Dictionary, done: Callable) -> void:
	if not cfg.has("_round"):
		mg_round = 0
		mg_round_base = cfg
		mg_round_total = 1 + (cfg.get("rounds", []) as Array).size()
		mg_carry_lives = -1
		mg_carry_perfect = true
	mg_hold = 0.0
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
	mg_title.text = cfg["title"] if mg_round_total <= 1 else tr("[%d/%d] %s") % [mg_round + 1, mg_round_total, cfg["title"]]
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
	if mg_round == 0:
		mg_lives_start = mg_lives
		mg_first_lives = mg_lives
	else:
		mg_lives_start = mg_first_lives
		mg_lives = mg_carry_lives
		mg_perfect = mg_carry_perfect
		mg_hold = 2.0
		sfx("good")
		round_banner(tr("%d단계 성공!") % mg_round, String(cfg.get("round_text", tr("다음 단계!"))), mg_hold)
	pop(mg_title, 1.15)

func end_game(ok: bool) -> void:
	if ok and mg_active and mg_round + 1 < mg_round_total:
		next_round()
		return
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
	if mg_hold > 0.0:
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
	if mg_hold > 0.0:
		# 다음 단계로 넘어가는 잠깐 (안내 글을 읽을 시간)
		mg_hold -= delta
		if mg_world:
			scene_update(0.0)
		return
	if mg_type == "circle":
		update_circle(delta)
	elif mg_type == "follow":
		update_follow(delta)
	elif mg_type == "catch":
		update_catch(delta)
	elif mg_type == "fish":
		update_fish(delta)
		update_fish_world(delta)
	elif mg_type == "net":
		update_net(delta)
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
	if speed_boost > 0.0:
		# 물살을 탄 동안 쑥쑥 (용궁 탈출)
		speed_boost -= delta
		speed *= 1.55
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
		if t["kind"] == "tale":
			var tk := tale_key(t)
			(t["node"] as Node3D).visible = not tale_flags(tk[0])[tk[1]] and tale_spot_ready(tk[0], tk[1])
		if t["kind"] == "piece" or t["kind"] == "tale":
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
	var n := 0
	for c in herb_counts:
		if int(c) >= HERB_NEED:
			n += 1
	return n

func read_story(i: int) -> void:
	sfx("tap")
	if not tale_flags(book_village)[i]:
		return
	var st: Dictionary = tale_list(book_village)[i]
	story_reader_label.text = "%d. %s\n\n%s" % [i + 1, st["title"], st["text"]]
	story_box.visible = false
	story_reader.visible = true

func scatter_items() -> void:
	pass

func story_count() -> int:
	var n := 0
	for r in story_read:
		if r:
			n += 1
	return n

func get_piece_id(id: int, extra: String) -> void:
	pass

func world_pose(delta: float) -> void:
	if scene_pose():
		return
	if mg_type == "fish" and fish_place == "ch2_chik":
		# 칡뿌리: 쪼그려 앉아 두 손으로 덩굴을 잡고 몸을 뒤로 젖혀 당겨요
		var tug := sin(anim_t * 9.0) * (0.12 if mg_step == 3 else 0.05)
		pose_custom(Vector3(-0.75 + tug, 0.15, -0.35), Vector3(-0.75 - tug, 0.15, -0.35), -0.35 - mg_progress * 0.15, 0.55)
		return
	if mg_type == "fish":
		var jerk: float = w.get("jerk", 0.0)
		var fight := 0.0
		if mg_step >= 2:
			fight = sin(anim_t * 18.0) * 0.06
		pose_custom(Vector3(-0.5, 0.45, -0.3), Vector3(-1.05 - jerk * 0.6 + fight, 0.3, -0.85 + jerk * 0.3), 0.06 - jerk * 0.1, 0.12)
		if tool_node != null and tool_node.visible:
			var fwd := Vector3(sin(player.rotation.y), 0, cos(player.rotation.y))
			place_tool((fwd * 0.75 + Vector3(0, 0.62 + jerk * 0.5, 0)).normalized())


func splash3d(pos: Vector3, big: bool = false) -> void:
	burst3d(pos + Vector3(0, 0.1, 0), Color(0.75, 0.9, 1.0), 26 if big else 12)
	ripple3d(pos, 1.6 if big else 0.9)

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

# 개울 흘림 낚시 찌 흐르기 (흥부네가 덮어써요)
func update_creek_drift(_delta: float) -> void:
	pass

# 바위 웅덩이 들여다보기 낚시, 칡 당기기 (고갯길이 덮어써요)
func update_pool_bite(_delta: float) -> void:
	pass

func update_chik_world(_delta: float) -> void:
	pass

var reel_was_touch := false
var reel_from_y := 0.0
var reel_from_off := 0.0

# 초록 칸 반 높이 (넉넉하게: 어려운 물고기도 맞추기 쉽게)
func reel_half(hard: float) -> float:
	return lerpf(0.21, 0.15, hard)

# 힘겨루기가 얼마나 어려운지 (칡뿌리는 물고기가 아니라 따로)
func fish_hard() -> float:
	if fish_place == "ch2_chik":
		return 0.55
	return float(FISH[fish_kind]["hard"])

func update_fish_world(delta: float) -> void:
	if mg_world and fish_place == "ch2_chik" and mg_type == "fish":
		update_chik_world(delta)
		return
	if not mg_world or not w.has("bobber"):
		return
	var bob: Node3D = w["bobber"]
	var base: Vector3 = w["bob_at"]
	var shadow: Node3D = w["shadow"]
	var bang: Label3D = w["bang"]
	w["jerk"] = maxf(0.0, float(w["jerk"]) - delta * 3.0)
	var target := base
	if fish_place == "ch2_chik":
		update_chik_world(delta)
		return
	if fish_place == "ch1_creek" and mg_step <= 1:
		update_creek_drift(delta)
		base = w["bob_at"]
	elif fish_place == "ch2_pool" and mg_step <= 1:
		update_pool_bite(delta)
		base = w["bob_at"]
	if mg_step == 0:
		var nib := 0.03 if fmod(mg_phase, 1.7) < 0.15 else 0.0
		if fish_place == "ch1_creek":
			nib = 0.0
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
		var fc: Vector3 = w["fight_c"]
		if fish_place == "ch1_creek":
			# 개울에서는 물살을 따라 좌우로 끌려다녀요
			target = fc + Vector3(fx * 0.8, 0.0, fz * 0.25)
		else:
			target = fc + Vector3(fz * 0.4, 0.0, fx)
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

func fish_leap(kind: int) -> void:
	if fish_place == "ch2_chik":
		return
	var f: Dictionary = FISH[kind]
	var col: Color = f["col"]
	var fish := Node3D.new()
	add_child(fish)
	var ln: float = f["len"]
	fish.add_child(fish_node(kind))
	var from: Vector3 = (w["bob_at"] as Vector3) + Vector3(0, 0.01, 0) if w.has("bob_at") else POND_C + Vector3(1.0, 0.1, 0.3)
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

func draw_reel_meter(ci: CanvasItem) -> void:
	var w2 := mg_overlay.size.x
	var h := mg_overlay.size.y
	var mx := w2 * 0.88
	var y0 := h * 0.4
	var y1 := h * 0.82
	var span := y1 - y0
	d_box(ci, Vector2(mx, (y0 + y1) / 2.0), Vector2(54, span + 20), 0.0, Color(0.62, 0.45, 0.28), 4)
	d_box(ci, Vector2(mx, (y0 + y1) / 2.0), Vector2(38, span), 0.0, Color(0.3, 0.5, 0.66), 0.0)
	var hard: float = fish_hard()
	var half := reel_half(hard)
	var zone_c := y1 - mg_off * span
	var inside := mg_step == 2
	var z_top := maxf(zone_c - half * span, y0)
	var z_bot := minf(zone_c + half * span, y1)
	d_box(ci, Vector2(mx, (z_top + z_bot) / 2.0), Vector2(40, z_bot - z_top), 0.0, Color(0.45, 0.9, 0.45, 0.85) if inside else Color(0.6, 0.85, 0.5, 0.6), 3)
	if fish_place == "ch2_chik":
		# 칡뿌리 표시: 갈색 뿌리 토막
		var rc := Vector2(mx, y1 - mg_trail * span)
		d_ell(ci, rc, 9, 20, Color(0.55, 0.38, 0.22), sin(anim_t * 8.0) * 0.2, 3.0)
		d_line(ci, rc + Vector2(0, 18), rc + Vector2(-7, 30), Color(0.55, 0.38, 0.22), 3)
		return
	draw_fish2d(ci, Vector2(mx, y1 - mg_trail * span), 17, fish_kind, -PI / 2.0 + sin(anim_t * 10.0) * 0.3, true)

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
	return fish_found_in(fish_place)

func start_fishing() -> void:
	pass

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
		mg_timer -= delta * (1.6 if good_rod else 1.0)
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
		var hard: float = fish_hard()
		# 손가락(마우스)을 위아래로 끌면 초록 칸이 그만큼 따라 움직여요. 손을 떼면 그 자리에 멈춰요
		# (예전엔 누르면 올라가고 떼면 떨어지는 방식이라 미끄러져서 맞추기 어려웠어요)
		if mg_touch and not reel_was_touch:
			reel_from_y = mg_pos.y
			reel_from_off = mg_off
		reel_was_touch = mg_touch
		if mg_touch:
			var span_px := maxf(1.0, mg_overlay.size.y * 0.42)
			var want := clampf(reel_from_off + (reel_from_y - mg_pos.y) / span_px, 0.0, 1.0)
			mg_off = move_toward(mg_off, want, delta * 6.0)
		mg_speed = 0.0
		mg_frame_angle -= delta
		if fish_place == "ch3_rock":
			# 갯바위: 물고기가 파도를 타고 밀려왔다 빠졌다 해요 (박자가 일정해요)
			mg_dir = 0.5 + 0.42 * sin(mg_phase * 1.7)
			mg_frame_angle = 1.0
		elif mg_frame_angle <= 0.0:
			mg_dir = rng.randf_range(0.05, 0.95)
			mg_frame_angle = rng.randf_range(lerpf(1.5, 0.45, hard), lerpf(2.4, 1.0, hard))
		mg_trail = move_toward(mg_trail, mg_dir, delta * lerpf(0.18, 0.6, hard))
		mg_trail = clampf(mg_trail + sin(mg_phase * 9.0) * 0.004 * hard, 0.0, 1.0)
		var half := reel_half(hard)
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
			mg_info.text = tr("위아래로 끌어 초록 칸 맞추기 | 남은 기회 %d") % mg_lives

func draw_fish2d(ci: CanvasItem, c: Vector2, s: float, kind: int, rot: float, shadow: bool) -> void:
	var f: Dictionary = FISH[kind]
	if f.has("tex"):
		var tx: Texture2D = tex_or(f["tex"], null)
		if tx != null:
			var sz := Vector2(s * 2.6, s * 1.95)
			ci.draw_set_transform(c, rot, Vector2.ONE)
			ci.draw_texture_rect(tx, Rect2(-sz / 2.0, sz), false, Color(0.1, 0.18, 0.28, 0.45) if shadow else Color(1, 1, 1))
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			return
	if f["id"] == "gajae":
		var cc: Color = Color(0.12, 0.22, 0.32, 0.45) if shadow else f["col"]
		var o := 0.0 if shadow else 3.0
		d_ell(ci, c, s * 0.55, s * 0.26, cc, rot, o)
		for k in 3:
			d_ell(ci, c + Vector2(-s * (0.65 + k * 0.22), 0).rotated(rot), s * 0.14, s * (0.22 - k * 0.03), cc, rot, o)
		for side in [-1.0, 1.0]:
			d_line(ci, c + Vector2(s * 0.4, side * s * 0.1).rotated(rot), c + Vector2(s * 0.75, side * s * 0.35).rotated(rot), cc, 4)
			d_ell(ci, c + Vector2(s * 0.85, side * s * 0.38).rotated(rot), s * 0.2, s * 0.1, cc, rot + side * 0.3, o)
		if not shadow:
			ci.draw_circle(c + Vector2(s * 0.42, -s * 0.12).rotated(rot), s * 0.05, Color(0.05, 0.05, 0.05))
		return
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
	if f.has("stripe"):
		d_ell(ci, c + Vector2(s * 0.05, 0).rotated(rot), s * ln * 0.7, s * th * 0.22, f["stripe"], rot, 0.0)
	if f.has("bars"):
		for k in 4:
			d_ell(ci, c + Vector2((k - 1.5) * s * 0.3, 0).rotated(rot), s * 0.07, s * th * 0.85, f["bars"], rot, 0.0)
	if f.has("spots"):
		for k in 5:
			ci.draw_circle(c + Vector2((k - 2) * s * 0.18, (k % 2) * s * th * 0.4 - s * th * 0.2).rotated(rot), s * 0.06, f["spots"])
	if f.has("fin"):
		d_ell(ci, c + Vector2(-s * 0.05, s * th * 0.85).rotated(rot), s * 0.22, s * 0.08, f["fin"], rot, 0.0)
	if f["id"] == "megi":
		for k in [-1.0, 1.0]:
			d_line(ci, c + Vector2(s * ln * 0.8, s * 0.05).rotated(rot), c + Vector2(s * ln * 1.25, k * s * 0.35).rotated(rot), col.darkened(0.3), 3)
	if f["id"] == "gold_ingeo":
		for k in 3:
			ci.draw_circle(c + Vector2((k - 1) * s * 0.35, -s * 0.05).rotated(rot), s * 0.08, Color(1, 1, 0.85, 0.8))

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

# ---------- 다른 마을 부탁 (collect_plan.md 5장) ----------
# 모은 물고기·약초를 다른 마을 사람에게 가져다줘요. 가진 수 = 도감에 센 수 - 이미 드린 수
# 저장: [common] requests {id: "asked"/"done"}, given {"herb.miyeok": 3}, gifts [이름표]
# [id, 말 거는 사람 id, 그 사람 마을, 부르는 이름, 필요한 것 [[종류, id, 수]], 부탁 대사, 고맙다는 대사, 엽전, 선물 이름표]
const REQUESTS_KO := [
	{"id": "heungbu_miyeok", "npc": "heungbu", "region": "ch1", "who": "흥부", "need": [["herb", "miyeok", 3]],
		"ask": ["얘야, 부탁이 하나 있단다. 곧 우리 막내 생일이거든.", "생일엔 미역국을 끓여 줘야 하는데, 이 산골엔 미역이 없지 뭐냐.", "바닷가 마을 얕은 바닷속에 미역이 자란다더구나. 미역 세 줄기만 구해다 주겠느냐?"],
		"thanks": ["아이고, 미역이로구나! 바다 냄새가 물씬 나는걸.", "막내가 미역국 한 그릇에 얼마나 좋아할지... 정말 고맙다.", "이건 내가 박 속을 파서 만든 바가지란다. 네 집에 두고 쓰렴."],
		"coins": 15, "gift": "gourd_bowl"},
	{"id": "fisher_doldom", "npc": "fisher", "region": "ch1", "who": "강태공", "need": [["fish", "doldom", 1]],
		"ask": ["허허, 평생 이 연못에서 세월만 낚았구나.", "바다엔 줄무늬가 선명한 돌돔이란 놈이 산다던데, 그놈 얼굴 한번 보는 게 소원이란다.", "바닷가 갯바위에서 맑은 날 잘 문다더구나. 한 마리만 보여 주겠느냐?"],
		"thanks": ["오오, 이게 돌돔이로구나! 줄무늬가 꼭 먹으로 그은 것 같구나.", "평생소원을 풀었다. 답례로 내가 아끼던 대나무 낚싯대를 주마.", "이 낚싯대로 낚으면 물고기가 훨씬 빨리 물 게다."],
		"coins": 0, "gift": "good_rod"},
	{"id": "herbalist_hamcho", "npc": "herbalist", "region": "ch2", "who": "약초꾼 할아버지", "need": [["herb", "hamcho", 2]],
		"ask": ["이보게, 바닷가 갯벌엔 짠맛이 나는 풀이 자란다던데 들어 봤나?", "함초라고 하더군. 산에서만 약초를 캔 나는 평생 구경도 못 했지.", "바닷가 동쪽 갯벌에서 함초 두 포기만 캐다 주게나. 약효를 꼭 알아보고 싶구먼."],
		"thanks": ["허허, 이게 함초로군! 마디마디가 통통한 게 꼭 작은 대나무 같구먼.", "어디 보자... 짭짤하구먼! 고마우이.", "답례로 귀띔 하나 해 주지. 영지버섯은 비나 안개 낀 날, 첫째 고개 너머와 수수밭 둑 근처 그루터기에 돋는다네."],
		"coins": 10, "gift": "", "tale": ["ch2", 4], "tale_say": "약초꾼 할아버지가 어릴 적 들은 옛이야기를 하나 들려주었다."},
	{"id": "host_fish", "npc": "host", "region": "ch2", "who": "잔칫집 영감", "need": [["fish", "bungeo", 2], ["fish", "ingeo", 1]],
		"ask": ["자네 덕에 고갯길이 다시 조용해졌으니 동네 잔치를 한 번 더 열까 하네.", "그런데 잔치 국을 끓일 물고기가 없구먼. 이 고갯길 웅덩이 물고기는 너무 작아.", "흥부네 마을 남쪽 연못에서 붕어 두 마리와 잉어 한 마리만 구해다 주겠나?"],
		"thanks": ["옳지, 붕어가 통통하고 잉어도 실하구먼!", "이 정도면 온 동네 사람들이 한 그릇씩 먹고도 남겠네.", "떡집 할머니가 쪄 둔 떡을 광주리째 주겠네. 집에 가져가게나."],
		"coins": 20, "gift": "rice_cake_basket"},
	{"id": "haenyeo_ssuk", "npc": "haenyeo", "region": "ch3", "who": "해녀", "need": [["herb", "ssuk", 3]],
		"ask": ["물질하고 나오면 몸이 꽁꽁 얼어서 말이야.", "쑥뜸을 뜨면 금방 따뜻해지는데, 이 바닷가엔 쑥이 잘 안 자라.", "흥부네 마을 길가에 쑥이 많다던데, 쑥 세 줌만 뜯어다 줄래?"],
		"thanks": ["어머, 향긋한 쑥이네! 벌써 몸이 따뜻해지는 것 같아.", "고마워. 이건 내가 물질하다 주운 진주야. 작지만 참 곱지?"],
		"coins": 15, "gift": "pearl", "tale": ["ch3", 4], "tale_say": "해녀가 물질하다 만난 문어 장군 이야기를 들려주었다."},
	{"id": "yongwang_yeongji", "npc": "yongwang", "region": "ch3", "who": "용왕", "need": [["herb", "yeongji", 1]],
		"ask": ["뭍의 아이여, 덕분에 병은 나았소만 아직 기운이 없구려.", "뭍의 산에는 영지라는 귀한 버섯이 있다지? 몸보신에 그만이라 들었소.", "오누이 고갯길 그루터기에 비 오거나 안개 낀 날 돋는다 하오. 하나만 구해 주겠소?"],
		"thanks": ["오오, 이것이 영지로구려! 빛깔이 꼭 옻칠한 것 같소.", "벌써 기운이 솟는구려. 이번엔 욕심이 아니라 고마움으로 주는 것이오.", "용궁 앞뜰에서 자란 붉은 산호 가지라오. 뭍에서도 오래 고울 게요."],
		"coins": 30, "gift": "coral"},
	{"id": "granny_sancheoneo", "npc": "storyteller", "region": "home", "who": "이야기꾼 할머니", "need": [["fish", "sancheoneo", 1]],
		"ask": ["얘야, 할미가 젊었을 적 이야기 하나 해 줄까?", "고갯길 바위 웅덩이에 산천어라는 물고기가 살았는데, 몸에 고운 점무늬가 있었지.", "그걸 다시 한번 보면 잊어버린 옛이야기 하나가 떠오를 것 같구나. 맑은 날 잘 나온단다."],
		"thanks": ["아이고, 산천어로구나... 이 점무늬, 그대로야.", "옛날 옛적, 할미가 너만 했을 때 고갯길 웅덩이에서 한 소년을 만났단다. 그 아이는 웅덩이 물고기들에게 이름을 하나씩 붙여 주었지.", "그러고는 '이야기는 누가 들려줘야 살아 있는 거야' 하고 웃었단다. 그 말 때문에 할미는 평생 이야기꾼이 되었지.", "고맙다. 오래 잊었던 이야기를 되찾았구나. 이건 그때 그 웅덩이 가에서 주운 매끈한 돌이란다."],
		"coins": 10, "gift": "pool_stone", "tale": ["home", 3], "tale_say": "할머니가 이야기골이라는 마을 이름에 얽힌 이야기도 들려주었다."},
]
var REQUESTS: Array = []
const GIFT_NAMES_KO := {"gourd_bowl": "박 바가지", "good_rod": "대나무 낚싯대", "rice_cake_basket": "떡 광주리", "pearl": "진주", "coral": "붉은 산호 가지", "pool_stone": "웅덩이 매끈한 돌"}
var GIFT_NAMES: Dictionary = {}
var req_state := {}
var req_given := {}
var req_gifts: Array = []
var req_declined := {}   # 이번에 들렀을 때 "다음에" 한 부탁 (다시 말 걸면 평소 대화)
var good_rod := false

func load_requests(cf: ConfigFile) -> void:
	if REQUESTS.is_empty():
		REQUESTS = trd(REQUESTS_KO)
		GIFT_NAMES = trd(GIFT_NAMES_KO)
		for i in REQUESTS.size():
			REQUESTS[i]["id"] = REQUESTS_KO[i]["id"]
			REQUESTS[i]["npc"] = REQUESTS_KO[i]["npc"]
			REQUESTS[i]["region"] = REQUESTS_KO[i]["region"]
			REQUESTS[i]["need"] = REQUESTS_KO[i]["need"]
			REQUESTS[i]["gift"] = REQUESTS_KO[i]["gift"]
			if REQUESTS_KO[i].has("tale"):
				REQUESTS[i]["tale"] = REQUESTS_KO[i]["tale"]
	req_state = (cf.get_value("common", "requests", {}) as Dictionary).duplicate()
	req_given = (cf.get_value("common", "given", {}) as Dictionary).duplicate()
	req_gifts = (cf.get_value("common", "gifts", []) as Array).duplicate()
	good_rod = req_gifts.has("good_rod")
	# 이야기 조각이 생기기 전에 끝낸 부탁은 그 조각을 이미 받은 걸로 (2026-11-27)
	for r in REQUESTS:
		if r.has("tale") and req_state.get(r["id"], "") == "done":
			var flags := tale_flags(r["tale"][0])
			if int(r["tale"][1]) < flags.size():
				flags[int(r["tale"][1])] = true

func save_requests() -> void:
	var cf := ConfigFile.new()
	cf.load(SAVE_PATH)
	cf.set_value("common", "requests", req_state)
	cf.set_value("common", "given", req_given)
	cf.set_value("common", "gifts", req_gifts)
	cf.save(SAVE_PATH)

func item_index(kind: String, id: String) -> int:
	if kind == "fish":
		return fish_index(id)
	for i in HERBS.size():
		if HERBS[i]["id"] == id:
			return i
	return -1

func item_name(kind: String, id: String) -> String:
	var i := item_index(kind, id)
	if i < 0:
		return id
	return FISH[i]["name"] if kind == "fish" else HERBS[i]["name"]

# 지금 가진 수 (모은 수 - 이미 드린 수)
func item_have(kind: String, id: String) -> int:
	var i := item_index(kind, id)
	if i < 0:
		return 0
	var got := int(fish_caught[i]) if kind == "fish" else int(herb_counts[i])
	return maxi(0, got - int(req_given.get(kind + "." + id, 0)))

# 그 물건이 나는 마을
func item_village(kind: String, id: String) -> String:
	var i := item_index(kind, id)
	if i < 0:
		return ""
	var pl: String = FISH[i]["place"] if kind == "fish" else HERBS[i]["place"]
	return pl.split("_")[0]

func item_where(kind: String, id: String) -> String:
	var i := item_index(kind, id)
	if i < 0:
		return ""
	var v := item_village(kind, id)
	return "%s · %s" % [VILLAGE_SHORT.get(v, v), FISH[i]["hint"] if kind == "fish" else HERBS[i]["hint"]]

func request_of(id: String) -> Dictionary:
	for r in REQUESTS:
		if r["id"] == id:
			return r
	return {}

# 이 부탁을 말할 수 있는 때인가 (마을마다 덮어써요: 그 사람을 만났는지, 이야기를 끝냈는지)
func request_open(_id: String) -> bool:
	return false

# 부탁이 생길 수 있나: 이 마을 사람이고, 필요한 물건이 나는 마을 길이 열렸고, 마을 조건도 맞고
func request_can_ask(r: Dictionary) -> bool:
	if r["region"] != chapter_id():
		return false
	for n in r["need"]:
		if not road_open(item_village(n[0], n[1])):
			return false
	return request_open(r["id"])

func request_has_all(r: Dictionary) -> bool:
	for n in r["need"]:
		if item_have(n[0], n[1]) < int(n[2]):
			return false
	return true

func request_need_text(r: Dictionary) -> String:
	var parts := []
	for n in r["need"]:
		parts.append("%s %d/%d" % [item_name(n[0], n[1]), mini(item_have(n[0], n[1]), int(n[2])), int(n[2])])
	return ", ".join(parts)

func requests_done() -> int:
	var c := 0
	for r in REQUESTS:
		if req_state.get(r["id"], "") == "done":
			c += 1
	return c

# 말 걸 때 부탁을 먼저 들려줘요. 부탁 이야기를 했으면 true
func request_talk(npc: String) -> bool:
	if REQUESTS.is_empty():
		return false
	for r in REQUESTS:
		if r["npc"] != npc:
			continue
		var st: String = req_state.get(r["id"], "")
		if st == "done":
			continue
		if st == "" and request_can_ask(r):
			var lines := []
			for l in r["ask"]:
				lines.append([r["who"], l])
			lines.append(["", tr("부탁을 받았어요: %s\n(도감 \"부탁\" 쪽에서 볼 수 있어요)") % request_need_text(r)])
			req_state[r["id"]] = "asked"
			save_requests()
			say(lines, func():
				sfx("good")
				update_quest_text())
			return true
		if st == "asked" and r["region"] == chapter_id() and request_has_all(r) and not req_declined.has(r["id"]):
			ask(r["who"], tr("(부탁받은 것을 모두 가지고 있어요: %s)") % request_need_text(r), [tr("드리기"), tr("다음에")], func(i: int):
				if i == 0:
					finish_request(r)
				else:
					req_declined[r["id"]] = true)
			return true
	return false

func finish_request(r: Dictionary) -> void:
	for n in r["need"]:
		var key: String = n[0] + "." + n[1]
		req_given[key] = int(req_given.get(key, 0)) + int(n[2])
	req_state[r["id"]] = "done"
	var gift: String = r["gift"]
	if gift != "" and not req_gifts.has(gift):
		req_gifts.append(gift)
	good_rod = req_gifts.has("good_rod")
	save_requests()
	var lines := []
	for l in r["thanks"]:
		lines.append([r["who"], l])
	if gift != "":
		lines.append(["", tr("선물을 받았어요: %s") % GIFT_NAMES.get(gift, gift)])
	if r.has("tale"):
		lines.append_array(tale_lines(r["tale"][0], int(r["tale"][1]), r.get("tale_say", "")))
	if requests_done() >= REQUESTS.size():
		lines.append(["", tr("마을 사람 부탁을 모두 들어주었어요! (%d/%d)") % [requests_done(), REQUESTS.size()]])
	say(lines, func():
		if int(r["coins"]) > 0:
			earn(int(r["coins"]))
		sfx("good")
		burst(get_viewport().get_visible_rect().size * Vector2(0.5, 0.45), Color(1.0, 0.85, 0.4), 16)
		update_quest_text()
		save_progress())

# 도감 "부탁" 쪽 글
func request_rows() -> Array:
	var out := []
	for r in REQUESTS:
		var st: String = req_state.get(r["id"], "")
		var v: String = r["region"]
		var where: String = VILLAGE_SHORT.get(v, v)
		if st == "done":
			var g: String = r["gift"]
			var got := tr("엽전 %d냥") % int(r["coins"]) if int(r["coins"]) > 0 else ""
			if g != "":
				got = (got + ", " if got != "" else "") + GIFT_NAMES.get(g, g)
			out.append([true, "★ %s (%s)\n%s" % [r["who"], where, tr("다 들어줌 · 받은 것: %s") % got]])
		elif st == "asked":
			var wh := []
			for n in r["need"]:
				var w: String = item_where(n[0], n[1])
				wh.append(w if r["need"].size() == 1 else "%s: %s" % [item_name(n[0], n[1]), w])
			out.append([false, "%s (%s): %s\n%s" % [r["who"], where, request_need_text(r), tr("어디서: %s") % " / ".join(wh)]])
		else:
			out.append([false, "??? (%s)\n%s" % [where, tr("이 마을 누군가가 부탁할 일이 있대요.")]])
	return out

# ---------- 글꼴 데이터 (주아체, SIL OFL 라이선스, 압축됨) ----------
const FONT_B64 := "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"
