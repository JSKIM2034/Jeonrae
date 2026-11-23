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
