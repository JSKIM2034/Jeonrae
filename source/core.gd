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
