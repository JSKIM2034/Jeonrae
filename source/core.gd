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
# 저장: [common] book story {"ch2": [5칸], "ch3": [5칸]}. 이야기 조각 자리 이름표는 "ch2:0" 처럼 묶음:번호
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
}
var TALE_DONE := {
	"ch2": tr("고갯길 사람들은 지금도 해 질 녘이면 하늘을 올려다봐요.\n해님과 달님이 잠깐 함께 떠 있는 그 짧은 시간에\n오누이가 엄마에게 손을 흔든다고 믿거든요."),
	"ch3": tr("자라는 지금도 가끔 갯바위에 올라 뒷산을 바라봐요.\n토끼가 굴 앞에 앉아 귀를 쫑긋 세우면\n둘은 멀리서 모르는 척 고개를 한 번 끄덕인대요."),
}
const TALE_REWARD := 30
var tale_read := {"ch2": [false, false, false, false, false], "ch3": [false, false, false, false, false]}
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
		"coins": 10, "gift": "pool_stone"},
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
