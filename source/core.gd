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
func load_book(cf: ConfigFile) -> void:
	var book: Dictionary = cf.get_value("common", "book", {})
	var got: Array = book.get("ch1_fish", [])
	for i in mini(got.size(), fish_caught.size()):
		fish_caught[i] = int(got[i])
	var hg: Array = book.get("ch1_herbs", [])
	for i in mini(hg.size(), herb_counts.size()):
		herb_counts[i] = int(hg[i])
	var sr: Array = book.get("ch1_story", [])
	for i in mini(sr.size(), story_read.size()):
		story_read[i] = bool(sr[i])
	fish_reward = bool(book.get("fish_reward", false))
	herb_reward = bool(book.get("herb_reward", false))
	harvests = int(book.get("harvests", 0))

func save_book() -> void:
	var cf := ConfigFile.new()
	cf.load(SAVE_PATH)
	var book: Dictionary = cf.get_value("common", "book", {})
	book["ch1_fish"] = fish_caught.duplicate()
	book["ch1_herbs"] = herb_counts.duplicate()
	book["ch1_story"] = story_read.duplicate()
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

func add_exit(at: Vector3, r: float, to: String) -> void:
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

func open_book(tab: String = "") -> void:
	if is_busy():
		return
	sfx("tap")
	book_open = true
	move_input = Vector2.ZERO
	book_overlay.visible = true
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
	update_exits(delta)
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
	var n := 0
	for c in herb_counts:
		if int(c) >= HERB_NEED:
			n += 1
	return n

func pick_wild(t: Dictionary) -> void:
	pass

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
	var n := 0
	for k in fish_caught:
		if int(k) > 0:
			n += 1
	return n

func start_fishing() -> void:
	pass

func fish_tap() -> void:
	pass

func update_fish(delta: float) -> void:
	pass

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
