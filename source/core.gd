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
		elif book_village == "ch2":
			book_footer.text = tr("약초꾼 할아버지가 모자란 약초를 알려 줘요.\n종류마다 3번씩, 다 모으면 30냥!")
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
				sub = tr("%d마리 낚음 | %d냥") % [fish_caught[i], f["pay"]]
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
]
# 물고기 잡는 곳 (도감 마을 칸과 보상)
const FISH_PLACES_KO := {"ch1_pond": "남쪽 연못", "ch1_creek": "개울 여울", "ch2_pool": "바위 웅덩이"}
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

# 힘겨루기가 얼마나 어려운지 (칡뿌리는 물고기가 아니라 따로)
func fish_hard() -> float:
	if fish_place == "ch2_chik":
		return 0.55
	return float(FISH[fish_kind]["hard"])

func update_fish_world(delta: float) -> void:
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
	var half := lerpf(0.16, 0.1, hard)
	var zone_c := y1 - mg_off * span
	var inside := mg_step == 2
	var z_top := maxf(zone_c - half * span, y0)
	var z_bot := minf(zone_c + half * span, y1)
	d_box(ci, Vector2(mx, (z_top + z_bot) / 2.0), Vector2(40, z_bot - z_top), 0.0, Color(0.45, 0.9, 0.45, 0.85) if inside else Color(0.6, 0.85, 0.5, 0.6), 3)
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
		if mg_touch:
			mg_speed += 2.6 * delta
		else:
			mg_speed -= 2.2 * delta
		mg_speed = clampf(mg_speed, -1.1, 1.1)
		mg_off += mg_speed * delta
		if mg_off <= 0.0 or mg_off >= 1.0:
			mg_off = clampf(mg_off, 0.0, 1.0)
			mg_speed = 0.0
		mg_frame_angle -= delta
		if mg_frame_angle <= 0.0:
			mg_dir = rng.randf_range(0.05, 0.95)
			mg_frame_angle = rng.randf_range(lerpf(1.5, 0.45, hard), lerpf(2.4, 1.0, hard))
		mg_trail = move_toward(mg_trail, mg_dir, delta * lerpf(0.22, 0.85, hard))
		mg_trail = clampf(mg_trail + sin(mg_phase * 9.0) * 0.004 * hard, 0.0, 1.0)
		var half := lerpf(0.16, 0.1, hard)
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
			mg_info.text = tr("꾹 누르면 초록 칸이 올라가요 | 남은 기회 %d") % mg_lives

func draw_fish2d(ci: CanvasItem, c: Vector2, s: float, kind: int, rot: float, shadow: bool) -> void:
	var f: Dictionary = FISH[kind]
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
