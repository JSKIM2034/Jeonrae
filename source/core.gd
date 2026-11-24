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
# save.cfg 안의 칸
#   [world]  모든 장이 함께 쓰는 것: 지금 있는 장, 엽전, 가진 물건, 입은 옷
#   [ch1_state], [ch2_state] ...  장마다의 이야기 진행 (각 장 스크립트가 채워요)
const SAVE_PATH := "user://save.cfg"
const SAVE_VERSION := 1
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

# 다른 장으로 옮겨 가요 (지금 장을 저장하고, 다음에 켜면 그 장에서 이어져요)
func go_to_chapter(id: String) -> void:
	save_progress()
	var cf := ConfigFile.new()
	cf.load(SAVE_PATH)
	cf.set_value("world", "chapter", id)
	cf.set_value("world", "entry", chapter_id())
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
