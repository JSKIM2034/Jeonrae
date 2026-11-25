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
		elif book_village == "ch2" or book_village == "ch3" or book_village == "home":
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
