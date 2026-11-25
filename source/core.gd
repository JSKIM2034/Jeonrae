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
		if fish_place == "ch3_rock":
			# 갯바위: 물고기가 파도를 타고 밀려왔다 빠졌다 해요 (박자가 일정해요)
			mg_dir = 0.5 + 0.42 * sin(mg_phase * 1.7)
			mg_frame_angle = 1.0
		elif mg_frame_angle <= 0.0:
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
