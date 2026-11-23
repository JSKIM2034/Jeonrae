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
