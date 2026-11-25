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
		return
	coins = cf.get_value("world", "coins", 0)
	shown_coins = coins
	var bag: Dictionary = cf.get_value("common", "bag", {})
	has_yeot = bool(bag.get("yeot", false))
	has_shoes = bool(bag.get("shoes", false))
	has_sickle = bool(bag.get("sickle", false))
	has_hanbok = bool(bag.get("hanbok", false))
	load_book(cf)

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
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.92, 0.6, 0.25)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var disc := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r * 0.75
	cm.bottom_radius = r * 0.75
	cm.height = 0.02
	cm.radial_segments = 32
	disc.mesh = cm
	disc.material_override = mat
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	disc.position = at + Vector3(0, 0.06, 0)
	add_child(disc)
	# 테두리에 빛나는 고리, 가운데 위로 은은한 빛기둥 (길 끝이 멀리서도 보이게)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = r * 0.72
	tm.outer_radius = r * 0.82
	tm.rings = 32
	tm.ring_segments = 6
	ring.mesh = tm
	var ring_mat := mat.duplicate() as StandardMaterial3D
	ring.material_override = ring_mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.scale = Vector3(1, 0.3, 1)
	disc.add_child(ring)
	var beam := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = r * 0.55
	bm.bottom_radius = r * 0.7
	bm.height = 2.4
	bm.cap_top = false
	bm.cap_bottom = false
	beam.mesh = bm
	var beam_mat := mat.duplicate() as StandardMaterial3D
	beam.material_override = beam_mat
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beam.position.y = 1.2
	disc.add_child(beam)
	if label != "":
		add_tag(disc, label, 2.6)
	exits.append({"c": Vector2(at.x, at.z), "r": r, "to": to, "mat": mat, "ring": ring_mat, "beam": beam_mat, "node": disc})

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
		var pulse := 0.5 + 0.5 * sin(anim_t * 2.5 + i)
		var base_c := Color(1.0, 0.88, 0.45) if open else Color(0.85, 0.88, 0.95)
		(e["mat"] as StandardMaterial3D).albedo_color = Color(base_c, (0.18 + 0.12 * pulse) if open else 0.1)
		(e["ring"] as StandardMaterial3D).albedo_color = Color(base_c, (0.55 + 0.3 * pulse) if open else 0.25)
		(e["beam"] as StandardMaterial3D).albedo_color = Color(base_c, (0.06 + 0.06 * pulse) if open else 0.0)
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
	for tab in [["fish", tr("물고기")], ["herb", tr("약초")], ["story", tr("이야기")], ["ending", tr("엔딩")]]:
		var b := Button.new()
		b.text = tab[1]
		b.clip_text = true
		page.add_child(b)
		place(b, tx, 0.09, tx + 0.22, 0.15)
		b.pressed.connect(func(): show_book(tab[0]))
		book_tabs[tab[0]] = b
		tx += 0.2367
	make_ending_page(page)
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
	book_canvas.visible = tab != "story" and tab != "ending"
	ending_page.visible = tab == "ending"
	for key in book_tabs:
		var b: Button = book_tabs[key]
		var on: bool = key == tab
		skin_button(b, make_round(Color(0.95, 0.72, 0.3) if on else Color(0.9, 0.84, 0.7), font_size * 0.35), INK, 0.85)
	if tab == "ending":
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
		if herbs_in(book_village).is_empty():
			book_footer.text = tr("이 마을 약초는 준비 중이에요.")
		elif herb_done_in(book_village) >= herbs_in(book_village).size():
			book_footer.text = tr("이 마을 약초를 다 모았어요!")
		elif book_village == "ch2" or book_village == "ch3":
			book_footer.text = tr("종류마다 3번씩 캐면 도감에 올라가요.\n이 마을 것을 다 모으면 엽전 30냥!")
		else:
			book_footer.text = tr("종류마다 3번씩 캐면 도감에 올라가요.\n캔 자리는 3분 뒤 다시 자라요. 다 모으면 40냥!")
	village_row.visible = tab == "fish" or tab == "herb"
	if village_row.visible:
		for v in VILLAGES:
			var vb: Button = village_buttons[v]
			var got := 0
			var tot := 0
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
			pos.y = cam_ground(pos.x, pos.z) if place != "ch1" else pos.y
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
		6:  # 고사리: 돌돌 말린 순과 깃털 잎
			for i in 5:
				var a := i * TAU / 5.0 + r.randf() * 0.4
				var top := Vector3(cos(a) * 0.12, r.randf_range(0.38, 0.55), sin(a) * 0.12)
				add_beam(n, make_color(Color(0.42, 0.5, 0.26)), Vector3(0, 0.02, 0), top, 0.018, 0.018)
				items.append([top + Vector3(0, 0.03, 0), Vector3(0.09, 0.09, 0.05), Color(0.5, 0.58, 0.3), Vector3(0, -rad_to_deg(a), 0)])
				for k in 4:
					items.append([top * (0.45 + k * 0.12), Vector3(0.18 - k * 0.03, 0.025, 0.05), Color(0.36, 0.56, 0.26), Vector3(0, -rad_to_deg(a) + 90, 10)])
		7:  # 취나물: 넓은 하트 잎 무더기
			for i in 7:
				var a := i * TAU / 7.0
				var hh := r.randf_range(0.12, 0.3)
				items.append([Vector3(cos(a) * 0.17, hh, sin(a) * 0.17), Vector3(0.24, 0.03, 0.2), Color(0.32, 0.55, 0.26).lerp(Color(0.45, 0.66, 0.34), r.randf()), Vector3(r.randf_range(-20, 20), -rad_to_deg(a), 18)])
		8:  # 오미자: 덩굴 잎과 빨간 열매 송이
			for i in 6:
				var a := i * TAU / 6.0
				items.append([Vector3(cos(a) * 0.2, 0.35 + r.randf_range(-0.08, 0.08), sin(a) * 0.2), Vector3(0.2, 0.03, 0.14), Color(0.3, 0.52, 0.24), Vector3(0, -rad_to_deg(a), 25)])
			for c in 3:
				var bc := Vector3(r.randf_range(-0.12, 0.12), 0.3, r.randf_range(-0.12, 0.12))
				for k in 7:
					items.append([bc + Vector3(r.randf_range(-0.04, 0.04), -k * 0.03, r.randf_range(-0.04, 0.04)), Vector3(0.06, 0.06, 0.06), Color(0.85, 0.1, 0.15)])
		9:  # 칡: 땅 위 굵은 뿌리와 세 갈래 큰 잎
			add_beam(n, make_color(Color(0.5, 0.38, 0.26)), Vector3(-0.3, 0.05, 0.1), Vector3(0.3, 0.08, -0.05), 0.07, 0.06)
			for i in 3:
				var a := i * TAU / 3.0
				var base := Vector3(cos(a) * 0.15, 0.32, sin(a) * 0.15)
				add_beam(n, make_color(Color(0.4, 0.5, 0.26)), Vector3(0, 0.05, 0), base, 0.02, 0.02)
				for k in 3:
					var b := a + (k - 1) * 0.9
					items.append([base + Vector3(cos(b) * 0.12, 0.02, sin(b) * 0.12), Vector3(0.2, 0.03, 0.15), Color(0.34, 0.56, 0.28), Vector3(0, -rad_to_deg(b), 10)])
		10:  # 영지버섯: 그루터기에 붙은 반질반질 붉은 갓
			add_mcyl(n, dark_wood_mat, 0.28, 0.32, 0.4, Vector3(0, 0.2, 0))
			for i in 3:
				var a := i * TAU / 3.0 + 0.3
				var p := Vector3(cos(a) * 0.3, 0.18 + i * 0.07, sin(a) * 0.3)
				items.append([p, Vector3(0.22, 0.05, 0.18), Color(0.55, 0.18, 0.1), Vector3(0, -rad_to_deg(a), -8)])
				items.append([p + Vector3(cos(a) * 0.05, 0.02, sin(a) * 0.05), Vector3(0.14, 0.03, 0.1), Color(0.75, 0.42, 0.2), Vector3(0, -rad_to_deg(a), -8)])
		11:  # 톳: 바위에 붙은 통통한 갈색 가지
			items.append([Vector3(0, 0.1, 0), Vector3(0.5, 0.2, 0.4), Color(0.3, 0.3, 0.32)])
			for i in 8:
				var a := i * TAU / 8.0
				for k in 4:
					items.append([Vector3(cos(a) * 0.12, 0.22 + k * 0.07, sin(a) * 0.12), Vector3(0.05, 0.08, 0.05), Color(0.42, 0.3, 0.12)])
		12:  # 미역: 넘실대는 넓은 띠
			for i in 5:
				var a := i * TAU / 5.0
				for k in 5:
					items.append([Vector3(cos(a) * 0.12 + sin(k * 0.9 + i) * 0.06, 0.15 + k * 0.22, sin(a) * 0.12), Vector3(0.2, 0.24, 0.03), Color(0.22, 0.38, 0.16).lerp(Color(0.35, 0.45, 0.2), k / 5.0), Vector3(0, -rad_to_deg(a), sin(k + i) * 15)])
		13:  # 함초: 마디진 통통한 줄기 (붉은 기)
			for i in 6:
				var a := i * TAU / 6.0
				var base := Vector3(cos(a) * 0.12, 0, sin(a) * 0.12)
				for k in 4:
					items.append([base + Vector3(0, 0.07 + k * 0.1, 0), Vector3(0.06, 0.1, 0.06), Color(0.45, 0.6, 0.3).lerp(Color(0.7, 0.3, 0.3), k / 4.0)])
		14:  # 갯방풍: 모래 위 반질한 잎과 하얀 꽃우산
			for i in 6:
				var a := i * TAU / 6.0
				items.append([Vector3(cos(a) * 0.18, 0.05, sin(a) * 0.18), Vector3(0.24, 0.04, 0.14), Color(0.28, 0.48, 0.3), Vector3(0, -rad_to_deg(a), 8)])
			add_beam(n, make_color(Color(0.55, 0.45, 0.4)), Vector3(0, 0.03, 0), Vector3(0, 0.35, 0), 0.03, 0.03)
			for k in 9:
				var b := k * TAU / 9.0
				items.append([Vector3(cos(b) * 0.1, 0.37, sin(b) * 0.1), Vector3(0.06, 0.04, 0.06), Color(1, 1, 0.95)])
		15:  # 해당화: 덤불과 분홍 꽃, 주황빛 둥근 열매
			for i in 10:
				var a := r.randf() * TAU
				items.append([Vector3(cos(a) * 0.25, r.randf_range(0.15, 0.5), sin(a) * 0.25), Vector3(0.16, 0.08, 0.12), Color(0.26, 0.48, 0.24), Vector3(0, -rad_to_deg(a), 20)])
			for i in 3:
				items.append([Vector3(r.randf_range(-0.2, 0.2), 0.55, r.randf_range(-0.2, 0.2)), Vector3(0.14, 0.05, 0.14), Color(0.95, 0.45, 0.65)])
			for i in 6:
				items.append([Vector3(r.randf_range(-0.22, 0.22), r.randf_range(0.3, 0.5), r.randf_range(-0.22, 0.22)), Vector3(0.09, 0.09, 0.09), Color(0.95, 0.45, 0.15)])
	add_blobs(n, items)
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
	return float(f["w"]) * float(wx.get(weather, 1.0))

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
	{"id": "juldom", "place": "ch3_sea", "rare": 1, "name": tr("줄돔"), "hint": tr("바닷속 산호 숲"), "pay": 0, "w": 0, "hard": 0.3, "col": Color(0.98, 0.85, 0.3), "len": 1.0, "thin": 0.4, "tex": "sea_fish0"},
	{"id": "jwichi", "place": "ch3_sea", "rare": 1, "name": tr("쥐치"), "hint": tr("바닷속 해초 숲"), "pay": 0, "w": 0, "hard": 0.3, "col": Color(0.45, 0.72, 0.98), "len": 1.0, "thin": 0.4, "tex": "sea_fish1"},
	{"id": "bollak", "place": "ch3_sea", "rare": 2, "name": tr("볼락"), "hint": tr("바닷속 골짜기"), "pay": 0, "w": 0, "hard": 0.3, "col": Color(0.9, 0.45, 0.38), "len": 1.0, "thin": 0.4, "tex": "sea_fish2"},
	{"id": "deungbul", "place": "ch3_sea", "rare": 3, "name": tr("등불고기"), "hint": tr("깊은 골짜기"), "pay": 0, "w": 0, "hard": 0.3, "col": Color(0.55, 1.0, 0.9), "len": 1.0, "thin": 0.4, "tex": "sea_fish3"},
]
# 물고기 잡는 곳 (도감 마을 칸과 보상)
const FISH_PLACES_KO := {"ch1_pond": "남쪽 연못", "ch1_creek": "개울 여울", "ch2_pool": "바위 웅덩이", "ch3_rock": "갯바위", "ch3_sea": "바닷속"}
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
	var n := 0
	for c in herb_counts:
		if int(c) >= HERB_NEED:
			n += 1
	return n

func read_story(i: int) -> void:
	if not story_read[i]:
		return
	sfx("tap")
	var st: Dictionary = STORY[i]
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
	add_blobs(fish, [
		[Vector3.ZERO, Vector3(0.5 * ln, 0.22, 0.14), col],
		[Vector3(-0.3 * ln, 0, 0), Vector3(0.16, 0.18, 0.05), col.darkened(0.15)],
		[Vector3(0.18 * ln, 0.04, 0.06), Vector3(0.05, 0.05, 0.03), Color(0.05, 0.05, 0.05)],
		[Vector3(0.18 * ln, 0.04, -0.06), Vector3(0.05, 0.05, 0.03), Color(0.05, 0.05, 0.05)],
	], blob_gloss())
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

# ---------- 글꼴 데이터 (주아체, SIL OFL 라이선스, 압축됨) ----------
const FONT_B64 := "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"
