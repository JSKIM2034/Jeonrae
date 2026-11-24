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
