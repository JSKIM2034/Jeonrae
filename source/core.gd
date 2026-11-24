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

# 검지로 화면을 누르는 손 (손끝이 tip 자리)
func draw_finger_hand(ci: CanvasItem, tip: Vector2, r: float) -> void:
	var skin := Color(1.0, 0.86, 0.72)
	var line := Color(0.45, 0.28, 0.16)
	var fw := r * 0.13          # 손가락 반폭
	var fl := r * 0.62          # 검지 길이
	var palm := tip + Vector2(r * 0.12, fl + r * 0.28)
	# 손목
	d_box(ci, palm + Vector2(r * 0.02, r * 0.42), Vector2(r * 0.42, r * 0.36), 0.0, Color(0.55, 0.72, 0.95), 4.0)
	# 손바닥
	d_ell(ci, palm, r * 0.34, r * 0.32, skin, 0.0, 4.0)
	# 접힌 손가락 셋 (오른쪽)
	for k in 3:
		d_ell(ci, palm + Vector2(r * (0.06 + k * 0.1), -r * 0.24 + k * r * 0.06), r * 0.1, r * 0.12, skin, 0.0, 3.0)
	# 엄지 (왼쪽으로 비스듬히)
	d_ell(ci, palm + Vector2(-r * 0.32, -r * 0.06), r * 0.09, r * 0.2, skin, -0.6, 3.0)
	# 쭉 편 검지
	var base := tip + Vector2(0, fl)
	ci.draw_colored_polygon(PackedVector2Array([tip + Vector2(-fw, 0), tip + Vector2(fw, 0), base + Vector2(fw * 1.1, 0), base + Vector2(-fw * 1.1, 0)]), skin)
	ci.draw_line(tip + Vector2(-fw, 0), base + Vector2(-fw * 1.1, 0), line, 4.0, true)
	ci.draw_line(tip + Vector2(fw, 0), base + Vector2(fw * 1.1, 0), line, 4.0, true)
	ci.draw_circle(tip, fw, skin)
	ci.draw_arc(tip, fw, PI, TAU, 16, line, 4.0, true)
	# 손톱
	d_ell(ci, tip + Vector2(0, fw * 0.5), fw * 0.55, fw * 0.7, Color(1.0, 0.94, 0.9), 0.0, 2.0)

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
