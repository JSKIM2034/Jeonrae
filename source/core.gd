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
		elif book_village == "ch2" or book_village == "ch3" or book_village == "home":
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
		16:  # 민들레: 톱니 잎 방석과 노란 꽃, 솜털 공
			for i in 7:
				var a := i * TAU / 7.0
				items.append([Vector3(cos(a) * 0.16, 0.03, sin(a) * 0.16), Vector3(0.26, 0.03, 0.07), Color(0.32, 0.55, 0.26), Vector3(0, -rad_to_deg(a), 0)])
			add_beam(n, make_color(Color(0.4, 0.6, 0.3)), Vector3(0, 0.02, 0), Vector3(0.05, 0.3, 0), 0.015, 0.015)
			items.append([Vector3(0.05, 0.31, 0), Vector3(0.12, 0.05, 0.12), Color(1.0, 0.85, 0.15)])
			add_beam(n, make_color(Color(0.4, 0.6, 0.3)), Vector3(0, 0.02, 0), Vector3(-0.06, 0.38, 0.04), 0.012, 0.012)
			items.append([Vector3(-0.06, 0.4, 0.04), Vector3(0.11, 0.11, 0.11), Color(0.97, 0.97, 0.95)])
		17:  # 질경이: 넓은 타원 잎과 가는 꽃대
			for i in 6:
				var a := i * TAU / 6.0
				items.append([Vector3(cos(a) * 0.15, 0.04, sin(a) * 0.15), Vector3(0.24, 0.03, 0.12), Color(0.3, 0.52, 0.26), Vector3(0, -rad_to_deg(a), 10)])
			for i in 3:
				var top := Vector3(r.randf_range(-0.06, 0.06), 0.4, r.randf_range(-0.06, 0.06))
				add_beam(n, make_color(Color(0.42, 0.55, 0.3)), Vector3(0, 0.03, 0), top, 0.012, 0.012)
				items.append([top, Vector3(0.03, 0.12, 0.03), Color(0.6, 0.55, 0.35)])
		18:  # 제비꽃: 하트 잎과 보라 꽃
			for i in 5:
				var a := i * TAU / 5.0
				items.append([Vector3(cos(a) * 0.1, 0.08, sin(a) * 0.1), Vector3(0.12, 0.03, 0.11), Color(0.3, 0.55, 0.28), Vector3(0, -rad_to_deg(a), 25)])
			for i in 4:
				var fc := Vector3(r.randf_range(-0.12, 0.12), 0.2, r.randf_range(-0.12, 0.12))
				add_beam(n, make_color(Color(0.4, 0.58, 0.3)), Vector3(0, 0.02, 0), fc, 0.01, 0.01)
				for k in 5:
					var b := k * TAU / 5.0
					items.append([fc + Vector3(cos(b) * 0.04, 0, sin(b) * 0.04), Vector3(0.05, 0.02, 0.04), Color(0.52, 0.3, 0.8), Vector3(0, -rad_to_deg(b), 30)])
		19:  # 네잎클로버: 세잎 사이에 숨은 네 잎
			for i in 9:
				var c := Vector3(r.randf_range(-0.25, 0.25), 0.06, r.randf_range(-0.25, 0.25))
				var nl := 4 if i == 0 else 3
				for k in nl:
					var b := k * TAU / nl
					items.append([c + Vector3(cos(b) * 0.05, 0.0, sin(b) * 0.05), Vector3(0.06, 0.015, 0.05), Color(0.28, 0.6, 0.3) if i != 0 else Color(0.35, 0.75, 0.35), Vector3(0, -rad_to_deg(b), 0)])
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

# ---------- 글꼴 데이터 (주아체, SIL OFL 라이선스, 압축됨) ----------
const FONT_B64 := "eNrMvQmYZGlZJhr/f/Z9X+JEnBPLiSUj9yUiMrMqK6u6lq6lq6t6qd5Zumk2oZvFZlNZFAWBuSiICyAz1xlZVOYqKiAMLiAIojgw4sh1QFQYRB1XFASks+77nxORmVW90N1Sz3O7q6srIyOjzvm//f3e7zsVUqlUjMr3V7jKdSevO3/j8RecfX5F/Mt/wavNkzfedLRSregV8cs+vrbP37i0unzjzNMq4qdehK/vvPveu57zvPnf+iF8/f9WKv4Hn3bXfc9h78PP/y3+Lz/tnu956se++2lj/PlzFfGX/9fTn3LXk33jZZ+tiB96MV4bPx0vSC8Q34afv4CvO0+/93kvWvjWM5+E77+7UjF/5p5n332X9j0ff1NF/BV8vvnWe+960XO4d5EdfP0+dn3PuuvepwSvXPrZivilN1YqZPU5z77veRffV1nF3/8J9v0KrVx98R8rn6PfrKSVtUrF2yZrq2GUUTFw6kQyySLp41dvPHKGYy8jUUbM3ZfX8eZxeJNcN7RADVyBk6TebE/iOEKI+H2cQDkqmrqW1WNBIIKYWF6X/oWhEyoORkN750/8GdexiWMrNc3peuS83rv/NYIianHkCwIVbcPsmpZGeFzkcXoPuYe7GwfXwkXicvB341pS4ouS2Fu//IUbLUrIYMGVOc9devv+L+iLrb5/7XLTl/vBtd6MrlHz8hfKM6F/Qr9YeWHl+3BqIW5YWs3o9OZzaXWMP0u+Sdp526SSyUniIsUVsF958R78wgmVr8ziuEbD8fpquLaetxfpaLhND5JtDt/LiveuLW/TUfHejBC8h/4HURQ0QUlqkcALvGnyS71Mz6PAI9nskkNxi4QXzci3a75CqcTzMvdCURMFx3cXXJ0XNY6TOCNvhk7oL/ozG1rkaVZcNw7zihU4XifRRMkQny+IolgL1Dhydz7wPb0X0V814mScEEEWxTDyKKXvpJQkfuBLad7knFbd56jq1y0rNZ2uU11NwgXDEF292W6ZZmrKnus1CHknpziGHeiCt7w0a9qC3anWD9Sjekyjg6ZIJXfntnfClmYufpIe4oTKMyvPr7y8UhFKpeJWit/LsxsXZx6NJkrYL49xPDnoLVLKPPLDKAwK3WSHKbL39Sdfi9JUGlJbzEjgc8Xr0cgkBH+LH0rhNiXPV5qtGg+tJdGhyGplVRG67Fiq77pKdChxF0wjkOd9VZVFvaY3XGfoy7rvu3UJP9I8UQ9rhPimXTechShYdDZGlJiyr+t1x5n12cd+gOiyklitOWJTK6oZHLGy0IgNnfcc6no2p8mi4US2Xkt8iE63ICf+F0WVFyTB6bjdyM/xA7otyzI1G5pjUmq61FE1UwpsM0/MhFJLkh36GtGTors3e00zVjVLFhTesC3iUEH2RFGiz6Xpzh8akWtw+cmcKl69IlTWLv4Z/WP6hUq9cqJyZ+UFldcWsiitvjxpdmAZF4XsMLlw35GaTE794VQg7Be3Pg4jIrYf8POk/HnCXusPmYzKDym+VxrK6PKX6X2t7WY8Iyu8KM2l0XIUzjiyqUpEEAx1vkd9zaybvWt6dsNRglo7NF0SambD6p3tmU1LdsPEcTK689PNE804l2VOlOaLT+k7jkcFSdMGZNmRLYngRNumaRBKBduRg503y5pgcbJjNU1bhzsrXo1w9uqo2jzSSkeKDC9nmFJUTbTekTyt0V8JZpxkmBx/5Yn0YGb1mi5HQzOa9Wuj5MSrTtQ3amZW8zne93a+KZvKKG4daaYjVeYINUxzJuid79QaOz9CFXPeteYUmUhSbOntVo2D8/o1IgrWgmf3cQ+yHFla3q7hB2FERy5+kf4C/VLlhsozKi+B4EpLWZzIIlqkOG4aFqcPP8X+1yC9bcq+B2fGlWfN3H1hNtx68XUhxUVaiLCwKPYBXiGi4sOL1zJKVC3UZk67tsbRapXqpk78SJRU+/jNj+svDHhK9CRSPEFTQyKpCpHDat0yoZGWySuOQiwi1mwx8fo61TSJeoNafqZltZtVkYqqyslVpzvoH0QMMbwzzVbGcZQ3rWAj8lzKKfGgSjlOnu03z+T5qSrVdIVUtw4fri9tBFoQ3rJcHa7O23Igm9ESvqkRLfZknveqtaovmFWDOlRfGS5Igm9S23P5qAtbehY1/Koleb4rej01FPjhXLTmxh65g87WrbReVS3e0hp+vJR7FVJ5Nr2n8sUiKD0wJL304YMOfvr4xXfDBSWV9Ym9cf2p8EaXWNRuzJXEwJ+YEgs+IsnkrmVWQ0+Cd5J1jqe8IJiKGlpaGulty5UlizdjORF5WRYtVYwoGRuKKIT1VI9XkupaPTmYRuOsebDRwB9WbUmi1A5jtXuyc999m+PqShKvRs7A4wVc7xDXm5XXG+Eap8a9Ph4Ni8uGqo3D3euLmLPddRWIj73jhNBIVC1RlnkxkWNTMCXZtdp6lGpWqCqmIOAOOF2WAwOmWzWt7hjBzxs40WqcrFTHm/fd1znZVePQRsiT7NUoZdfdzMb4Q1JfqyYrsZ7WQ0FUcLXLlQ9TmT65ciOL38z1iL05snt407zmskDdFqXZwnrG4UHSK80Ib29Mvo3bY1a0doCQb2qEqpqW6ddqkSaoCJO8lmY1WQu0ZdHWTfhqhTdlfNPveUZVdwXHHDiHbEOvCVzdcXO1o8e6bJl6phi8X1evtnrkvYqp10SRc3NX9lXJklxZi3Wn4VyjRoIIG4qrie60HUpEbcHUuChw5iMbita2Nr2Op7kIW5o7mOlYOIBB5afI39OXV7ZwABG78kIctD1HAnYaeRv3R4ejft4WmZ0XOsetRaVcWQ4YihE58hzHMU1JlF1HI8/gcMe+2hRkiSMXNMvQ5cCxVUMztNOEmnJdM2sCi4gfIeU7Q/bO5zl58QnV2CHPJHDBVoi3QVkJuTZacTTds4P5CBfcuPjHlc9UfqGSQL96/dJJsQyAaY/JHTBlASeAxCSpaUbNUwQ+ridwi447oMwPxwoL4hyneVUNiVNVklxHxcfOkOvgPz+D9LZCCv2cnEM+VYIipQjXyVOd3JIkXGmCK/2IXo0DBRfnBAsR+TSvm5Kv6TVJUVlyyykQtOm0RIUQ/BXdix+q/GzlSEWrVNZ8drL4SJzgz3aTpMv+K37v9fDO/sV/Iu+jH630cI9IBJG3rufTwFnopbAbXJ+ih7YMRyiT/Fi3tVETTDd2kqpgOo7fWGi7XVc0ZTmzZNM33NQ691PXXP3iLS00eEmbSToLvZkjd50dnOlqyFZsZLQzFY4eop+sdHCdlW67N/U0xSEXhlsGeBYSuPbEcAO/DB1MNeCgyBr+1tqKv7w6I0Vpww6T5nWtxaOLcDCU5zW3HvRuG5o1aL8c2F5Vb4X+wE3bDgev0ljjEHC70fgNZ59+l9PL65KqqlTWNs8/frl5uJkeGK8E3QE9ISBPMjs3zM49rufWRAGfunX1mSw7Os5xfM7FHTKkn4VuV7xJuozr81Gr+OHUkqHAI5PLEc4KTf6UpItS4Dk8D8FRVTWXHFeS4InShE/mOL6bNg/RP6SIppCqotbqNW2HaFEcSBoRxbbzQ/e/EukwzzmNZkfRmJ72KyJt0U9XzuEimAqxEyxjbOCzWoC5OxzZGmqEcJxNg2veaousjBpul3UCh2QnL875P1mDXhUJY1A14kPHjqXX3Wp1Dy1YTVuohzxSmDBZrapxHCL3I8jae87Om9RIcUncnXWTrVq+kpnby/khX9TIlyPV7sZ2L29oXt2kSvWemwdXbW13jcTgbdtEegNHhWwGuQUMxCKUE+pWda7btKLFKF2eHURr61k6uUtKdugnKjex2Daa+r+iNuQKL4j7zDh2x6yiKb1/ka1PkgRu14IXiThHmJPZNIgoh6tp1InyG7tWFluEGGFNDzfC/umNVvfo7eNoNFxydIezfaueVPXu9f3Q5yLfW1yctRy9NdAlzzEop7uBeMxs5y16tx5rgeyLuC3cmmhFjt9ppXo0jIRk8cTy8g2H2rJddfVWnkoCRYiP5Mjoz3R0TZZNx5uf7RmS73uyzPwWJ8NQejCUs/T3K9uVqyahA/VFCo+Iu4PnaIuIEEG9iMi0sKItishSGNS+mL0+XrXIGvmERAV88JwWo1acqVPDNhAokFu6jugiatB3pUciV9RCtXey4895Zqsaz9/y9rfT/6Y5+el8cN3gJkF3jSYiNz2u1Wsximv8Uew7XKubUcdotZrG2jOGtdVaMK9rv/M3kFzv4g6t0t+r3FYYyUGyOp5kfyJTOHgnXLjPnKAYro/ZbU3idFk39aZyhP5OVRT32Rvu3trTlNT/V6OVRQJHFNdINpJ0vq61FWTpsCIn6PTWbr2qS6h8buvkG4+4mSRLkZMmVSNarW9fc+4oApjdyFLDYNoIiIDI9AOKANnZahI5hGUBHNUtW3RyB2FPqa3fuK66yuE7g5owQPIVLGiyYME+raMb40PIEFROsc0ZJz2Qppup4zNnhyM4Sj8FQOMUZDjJWTlpm5S3y3SWZbulMTLT5dhNTpNhbuLtPq34Wn5jJ+3HOqmdO7R229HezIknrh95Yu43Ql1Plzvt6y5c6KqJy+sox/y3trdCE9fTnFuLawtNh+Pi3ipdFA3e5Bxzdnggrc2lGzeMRrcczvttf+XwDaP52y+cSWsZj7w5qucuL/OAHRqJMxdUu5HCcVG+VEv7oVSEjh06pr9bGZYgTauAIIrQuFuJ7dZg/d7E5CDObT1zyDPMpuGKRlJPBLtWrdn+WiS5Ueoklu513NpSTa5XLS7fbN/lDjpVHD/9DZGjkjo3Ojia07LV1dVscFtfj21eNsdR+0R77Qlr1tziggOJS2E1iFGK9CuEpvQPKxuV85UnsRhTVBBFWjWpJYoMo7juSamOq96FlDiOZYlQvbDwGkwZ8Ur53vXVMStISDc7fHDN8SwqHF7mHdfidEsw/IYxs7jkwUs2Rv5MZAm+wZmOzcfzqOg43/NWxpvVcKGbcNSqtp2ZrlkNHFHhrHDUiGabDiGq6SzH3XXH0NtrRPTatfRYPj7rq6ZBjbazcHfXrjoqkussnL93067pyPwkYqVJcuDAehimrkw6RA3yxG9EBpw9J6iOFYycxCYHqRp2al7L9CUSdtJVlA2ldnYRiueZhxGKPAy3t1rc6drqNu0DYZqgRIW/LeIK12OGyL7aq8OIuXhTbkSK6huIcEo0SlsbfVdIz7THt2y3O0cft3Hklk437179XfNubtaashN6w9GybWtSaJt9GjT0RqOhy6oje3pzeLTleI3NG1aHt13V7Xb7L33ahf/ryev0VliktnLggOfqYux5c3N9SzNwF+uVuyrvoTcg6YkqlfV9aY+z78/vmaZA0/9+ZpILkVunSRErhZTK+4tPQlrk7ftp7oFp4O4Hvumh80HqTj77/s8/bGZ41cU/J1+k/wI5VMheqUL3apiyKuuNpr4PV0G+KKu878xek+uxSczqRtPru7HqLzTsrJ5ov366fnw2WW+ZrbpL32PVNdFz8nNzZtbsePmRBmqBeDTj6sieMuOTx9buyq/tJWsulKmOc1iovJf8D3oUmerBb5Oreg+byH7//kT2T/Ynsn/8kN8hmw+T4hLh4fPfIQ7yj8uD9KC0U7gHsGEBjJK9anZa4eLX0K3jmNaT2eP107+uJfXMbiz4auz2veYGynMz1vNrZh2fV2X6Hq9uEcldS3rX5netHfukkaWRpLszo9jr+Y0juddpZubcudzxRI0d5NbFT5F/pN/AMV5TVObru7kirHNZ2sNn6XiKWcFD9Uxa5mpwND4rkArJQw+j8AhPFG212T554qq00eCCgDjzXijzXNQIAgCwYjMyktDmOD1u++5MOyAEXkBzO1lA0jCo1wL8U6sHITWAr7aHlm3IcMMnz17TpFE3iJbS+oCQat638sNIyOrNwOs38CFa1PT1ahSqDgnznUYahWFcbwRRFOIuRxf/khvSf6o8ufJcpsCXuAau1GPmbZmn5fIJKMTthrtJ+sKNij+1GfbDvtUbTs4qkJjCI3eDTyZjegMvqPVqwAN4lgT7xOOeOT54Nhcje3zyhjltabaqSvOjkXX+dasriwLvd0ad2Tuf+ozRwZvWPFFaHypJ1nY1R5eQschJva4uHWiKojw8fqZBUAkqaS24l5Op1FheNaxwYUz6el32eStR3IXFeW/zujnOC87d/dyNwfZsSKU4cT2Z0K3DW28+O3Ph2qMInUC3k/NPfsGRA9/VFFWiGHIUIL2tqvDGVF3aujpfPNZUMk5HRNAkybP+AjBiexS63ZmNqlr45H+lb6AfgU9De6bLbKtIifq9/j6VLYLYEgJrfx8EOv2Fg+pPC2n8u+IVHqP8bQwdKv5lWILHAMjyw4qfRJ5IX88URpWqdVOjRSorIPwKALwIT4ITrz4RIOlDVsThJVEo3wHosyqpHPJW4GCfAmTGfgbIioamCdB9Ge/Di5/iuP9j1CwkFvieVTPcXz4uapKuCgpn8rxCWdlDBEXAL17iFWmFkBW8GX8uXySsMKIKjxRGEVRd0kRFUWjFFlXJUEVVkAX8Iyu6asAX2zsVRfnbdLupeAp+NbfT+QLn/2fq0t9GfnCkQGP2mkj5JOVEb4mFuiIxKE8JNeiev2AtFmAWcHcMhlzEN5GIB35W+pVxj/xKOtAN0jg2Ts81+jf2HYvjo95y4g+C1smm5Thqs8H3/2fjiG5oQuBEW6kZOTLOVtNmFxqDCE4s6c/ZnT7Hr5PnemvdwY0nR5okEyILVRu3u1FvWMztKbqgyHp67flTO39OVdOeWxjorkYE00yGsdnSNJn8BQQZRV7X9T1UnGK3s8Dq1sHFr9FTqCk2oVtFJs4SIm590gGaep3+IpkGIOaYGJJODxrx8FjWOn36RJr3XYKUcu7QoHHt+ZNVO7etlhm6thQfObxu2R5Sb3tpvJ7Inh/o7tzPpeuLbVS6TitOr3/c4wfd62AoriHVInN1uCDzguEqaaANmu3rbzyXxZkum7xlm5xoFubwVbqBC55laAHZhfxZUb2HUjpbhW6XleE68yoT55OHfiD6KTpcyFgFQR0Px685Hi2FriKIlBUwUF+omKgLoiG/4+jTz8y+F5iu75rz40MpIY3N0QL5sdbVrc17ejMp3i5wMqciCxHRzqAHUdCbkAQ6hJTjebp5673/nJ27/tosrFtiOs46x5ufIILbYtDPxW+S+2HUr0IUkNZghMgp1kodQwXHLJb9OwcLjIDp7Wmf5LPXc7Et5WK/3ZuFouK+e2Ubiv0OGz9E1pmlozIelSeAODE6QMfFXxOuRqvh3l8zOTxAb9Iv05nBkb6gR5oeao6GElATTAMdgKX3048tyaYoGyISMqZtqm4HVS3WxHMX/NjzbcD+YmGNrIQnxW9E5RXZsmXABEEczJzq8Xi/xj4Ylq3xiiga+EB54Xfp2f/I3i5wom7YgiFoisTxsO2PMAdAeUnVcLrot/JKUUdTVdIhJ7ghDeITkPXz5173is5GS9A8FdWyzt5X/IP2pG6aIiBQDe6GSZYUB/91fPXhyvOKCtovD3p6BIF0gKzjuB8ojOKcmDimFemeUy36TJDB+ugwGQ8ZSDkaDwvt2zv43XMn/6aw42HeypBFU1r4H0T2zJnDPVGLdBwPYFX0JtDiMSTJkBffx5AhVDuiZtdiOMZSRaf/sAOXJcNyZMEN/di/7pxQfopD367buHMNqlncOPez7P0cL0KeaMbKCHeUCZL8lcycKQQtoAWlc4rEU7E8WVm2z72ueTSfHG3oONK+ky2gxX+im/RjlcfDcxToEneJ49hDsnd9R1gWsIcASbAUZjcglaDEwTKvLNQ8oJui22lYg4V57/ZnH3QELhgcmu0//o7zkQ0oudnLRckP4tHKnOmgj4HDUxq9Wa/W9iXDF8LAVVTcrioyjcUp36GleBNlbdS/zw5trnmqoXCEu/5Frz3Su/WGo2jz27N5cqYN4KAWRH3D4u12WD14+HC6MmdXLbQ6o2YPSQ86oZpdnB+iHTs/SeJlQYMshUK1vooD+d3KDzDVgo/hJpG6UBXmnoZTVRmOxlCW3CKXveMhdGmS4q+Vhsv+xaczVV1FLwBHuNuT2X0L+pMbBCbJU4QFtx4ZAp0AbOy38e/TvW+pChSMkl3LLVA4ARHftmVdBBjFASaicmAOn7Y5/S7VgFDJBjo6Ms6BvgF+b3D/N1R4TU3URSYPWaes5wO/CBWUgJWefyn52/1vEM1C09j3ZcU6/4bm8U5nI+fVQFM9FfqPEEc0STFU9tlvI3ThhoX936MqflbDoV998auVP8Sho149THFkcPyl4xvvP42yJClEIu5Lii7xnL31k5PbVyXTtuDtkEYIpZmIhRlykiC7tRjC3/V15Bn7L90NTHX34kQG72qig4PhFLEMEeXRTPxXee+sxrz4FXoOlnQXU5yiBbKbu6ElIoYlkDJtZDEcYpvrIbs4RMYjpM9tgHyjKQlhX+CDRe25M5wDPaYyJ6Bx4FDokqRLm0QROb02326evfbq2AhlPfQaacMbDDODK/2G2JvvA8y3ZY+5EgrPJJkyft0p2mr/bEdEUwlUD/pOxrUQ0BkVymNxbn/37dnh9UVDV+Uk0vN+V9f0pM6r3uzW9gF/9NQRX1gjgRrCeEJZgGbgYiaHSmS+sKd/pj7Qwlex1GTipfvtvSi/RKMCK5xIszexsUKkzMSGoyUyZPAgs6FheSirE30Ii3ZoVJjNYVJmwtPiMPJ3j9+iGVdkxux13L0k6KIqapbIYr7ASBAyr38QZ4VSQeI1y6oaKAqBgk48JXPfOGRLthSQWgwN58McMrEbVm1UQxdfRsvJUyxJQFMZHUYRHyjw6EN/AFSPRKmtxhwCr3XKQiQVJAQuHhQM9h5B5Y2Pf1zhFbANRJlXWfyESUFTVeS+6Koyesb5Nxw5wzQTFCjftxShsHMF4pctKMDge83MqY8SDiwD+HZA1MxSJVNDNi2wG5QF47esVqOm1Nfr7FKdAur7Z/J1+qHKSSaTEqrdTUd64uK0y7EvAZnY4W4GU6RfXLT3GvkaHIHixAEaivy1N/iry30ZSdgkl8DhGS7ODvaElkuRnn10CS4dvkmTtLOCJ+KA4FIKw+UEL0A8ax9tvv6VnY22oPoqmpAKi1uigEwC5QVUX3B3BqUr5KSiDXfxX+hr6MfB9al0p9646EAeKhB03Eq/ZFExtfNFhtHiv0mmeZg1qob7b7PQmGi7DIXcntNmLigsf9FXE/TDZc0yE800mLLQ/hqoMrJtGXy81Sz8kF3rBECiC/cj8DLCPI7BT9GAdkFNGLicrEigPEVVRwrrjYmz5vkyLzilJxpUlYVqpVrPjHNvsl3LczmrddX5OTQ3ZN0Qswtb5MgT733CYSd14dEzw0zMc29+5S0XNE+xZRwa3zcV4LLq7NVVTgMhyG7kszW93YyYj5QVQ8Fxbjxr4/jrjpvNQje+Sk8D2r6xPMdJ+F9i/+MmmoK+4m5kK93U/q48ClDGs2ERbZcawrAaF20OeopItp6lidzeTC84PR9XpNrVlicVigLVVnhHyw0WbxRmlrAl7cukcMZxlmkI/0Jhjmednq7ykqXN3rbwstqxdOflit1gUc6ud13n3Oubx/K5O2cjG1wenhW6CPCFqQv2zo8fbR4DejDrhIYtAqaFgaim9pKdb73ErKEyYd236+nvVDLGQ/CKVgXdjTbTsoow+Ji2pQminBWe50+O3XvzIc+yOQWVqlY9v9Q8fvRQtTETisDZ5w8TX8e9tRa2umHD01iB7TvJifZ6qtP/WhVXbljrXbjxunbU8+bGqPOcVjU7f8utM90L5w7vPHnpBcPmSuJqveVhnGxurvlZJOuHwqKQup/muNwt1kibsP3KX7PIhKc9y6Ka2kf6ADnwEpkxCUkMowIsnPfaZX0VrAMrJn/S6/D86trMuaUg9XiP5xRPaxqmJ/ISLfp9UM4goI2zVTPWQDlQHUX2kGiYCyToLcci6gYRKQYYWPGBYZe+Ir9refFa3zFZf5580pvRkNUDa1Aihw6giQghSGIFeZIjFwkPUhCgAu+KO7FZxPHGZsvtOER020xeF/+NPpH+d/AxnlAAK6Xll5np0h6XlJswxyBMq8xs8d71It72poQ/hsRNzmN7r6kDAdPb2NWqkirDr+qKptadQdg8BulmPSZdt7s5uPs18/kAzXLXqvGSsfMD2U1dM+YsEKq4AsUAfqGiqtTgBNAeFZHpnxkFqa+xWO6fBBfD1BCYoPOiEtshgBe7XWtcf+vtM73bbjiiN/qrM/e84IVry2YkSNYT+gg4IW+BmmdrPGvZIacpEZbWmWtON3u1RBusjQtVmRTbCyhTb648pQjCZlkz9stim+FNcJVSHjDQQ7wUluoVajMxclQ/ewGgfGdjQnkJOegKa6ow5REDOk/YNQEms2RbdzRI9dlIP4Ku7zGhmnqQwROJBeTEPCNOuRov3DqfXlWHg9PyztoGlejjFMRKQFLc191WzSX81kp6AvTPeVVBsGRJHWpQZLC+9ukiI36PDMjelrQISR/YqUVFhLx4A6mJpgEKKEpPBeicpjZvXxzfHkKm77d5uBod/Kg7jDB1VlcoHdx0oGhyfgMAxcfBe2NW5YvTZmxJG12d3DVYtcPCJ0yh3qm/KOMMa9RnkxYTXQSiwNt3ft8PrjUXbSBprq1WYzTVB1Hr2HrbrOZBvLK6HC0uK1mredsYFc4Kmp+m4NlpEqu16/KwVwMVx6lm1sLtc/PbJDfzTm5sXNNW6+6wqQHjRPpiGUGuaXyykMaNgDGekEp4526/rZmCAiCaoaW2um1d5Sxf9k2eM+M8tEMTPBDRcQ4UYfR+egf8yS1FFntpZS0yx2AyAlpUFNTsu8FuXcTScGd2yufGF1v74EnAH7vkLXodU3rYUpmErrm5s1sI85xghjVHASGTpa1zPSiGHIDPxhm8I+uubCv54fzAfZtGrCs2fRsKYUhXZTknpNk4+YQX33BWhR0IDEpDo1dUFTgYSYHNKmpZILFcFZ5fF3SZUyg/KZl4gVOK279IbwAudXUh9n3ksqKb29tipODCV0yyBDLlsExdKx32C35TkWqeQbhCBPI0e3H9UDZ64kzW8QVGA5CVZt7EdbLroXroj2vVNfDWKC/iJUXOkiCRFfra5Zf9wH15sODWBqlN4JjTo6fPDbzNQwd8o9FIdQNos2yrrQvnj9pbdzVT9AcamVbXe095xlMHrmX4xEMnjYX0b9EXgxR09QRq48q2CT9l1ZUZ9SUhvEb2EwQnNwTRvVAAqtZsZqoaNgZputxrxL7cWE0kV3BTFOqoR5DUwg+xGgLw8Ot+RGJJoMAj4eVQORlA5ETPoz8eLXn9O++8qZ4cPTzUdSMfbYy842884W9uLimMLMOzuKKC0cN+OTtPIW92BE1i5RY8qMjEhrAeFxL7R/o1lF0vnfDoLbIHmk9MlusXt1x6Ozqlf6/vwmphg+zdPBdNyVLFn7lpabFHvCjCREi/wjMeATFzU4eVwnl7cc2OIyRY4F4orm1wslfrJb6MqsAfyBZuRlJEpuRwN8jcdEMRWH0NrVQSjdd1XTRqNlqodc9JVMVxbHBxFZk36qj7CZ0co8ybqqHbhkrf4gUopPntVx9afdEqOA9WpHGas1WVljdHRrgxnlP95TZ6IiESwmv+c+Oq3Gn1V1sAgSwkQhRRSAbFAbWtMHzSgjvaHMKrLMb9RJakxThcWZq1NMRQe3zviB28yM5ewM8hJVPVQqfuR7X7icqLWEQRL+9lLF3WuuhPGq1loba016bbi73T7sU0/u4r6dYn3Y1p4LIoexs9BlowF5mubqlFocPAsFf8EGHREKAhUzTDaugiBU0dCmnE5uNfrbPWAyIyAwQ4lUd8sCEp34YbItVBFeaHX9FcTFFNgSLk2ehJg54NVRNEgESc/prHjxX3cX4G7js8BqCEIksFL+WDH0T1yLOyT2B6AaxJr9UTHWHZyf0f/qiDfgYcDsMNgFqhkYIUXzc8SINvHWqzdFcV2odaKK01DwMsEAJAE9TpYNWi7+F89IfPooNLimTnGHCSJ5aWXPpmi3PEEoEKdhGRyekOR84SnWDqvRLNjKam/uBHXfZI6FGGMyJkIrkwvj+iU2IXiER11LAiaxzR8OVo1oC6xgIxcl7NdDUUHI4Ex87FsxHFYUg0msVhGrIR2o4H0JKX6ZsEVTQ1EwW44Lw/3fkavixcNf4BLAQNQ0YuFvk/cdrvcxVdgyCRPBkKSlp8qGQrqqPxzYNtVsprtL3V5BVPdVGXUxXiK9w4kvhN+hsYNqhM3MEBLlwtMfgGWd5TJnZ+eQuMq157Erb6AB7Wh73LKNKH6d6kzTS+FfAw4Pj1NcZbY2S8CQ2e2mZmHn7JtmWjh7YySNYSpo4AMU00N3mZJSOKsPMTKHihiDxzanpR+OIMmPLCzpHx0uHjw7nIqdv5oa2r+maXxUBFtQIfXC4hve8WAPHRWgCUQCeGT1eCGf/2X7mjiCf4CMWvShrDqXZRZpyxyuZu8H0U4RzjkEBXORjG6R9OD7eTPisHCVIjDX0nlJXyBEukOnojWtbMcKqvvfgbmL0RkGpXWPzbI/yy/hknHtz/Ys5KibLvRm53OgVDlyUPC8C58bkzcxPWbqMRkxPxTM1ym/NVxuCc0npVNzZ2zBN7L4jx7GaTpo21jn8p0VVglBaknmsTr8IVJCthN5qR7/1OMl0ZWPkb5MnlMXiM7uUwLEGaJbuEV8aJ63NIDOfI/lfX/q4630R5MBOfIHGjIeOczNyZm2FImWMtENMPi9c6Dif4nbXG/V9sbs7GkJUshKoP2OME+YoRu+reC7iYmPwteSu9WBSrRQMNhDoW3B7A8C8HZPLZXc87oZKSH+URu0JZc1TZQLMIxZs341ugyNd0K1Krw6qrdUxQrx1VBeHfdSygSyyo66IDLSVwegB0Za2mVuciN0ZKJ8g1s3djr9ZSNcy8ZICX/VCAY6MirvfAxTeTv6lIGGmsdPeRxvMC+ZsSTN68j9L9V+BwRwWFm99H+mZFBM69oIMXRTtPq+RDlfaEvZbtGyliqfiEfciCeTQh4ITbjIBPxf+YHb1qK0nqIu8GHgbcEqsWOlI07jUPtObWU5SmG9umjb9aXU6yhYjaen9+jrzNQqOzmmz3kvn5+TiaAy8evbSsBeevaOunLwzGx+82e7Oztokpt8764cRziYULHVy8n7wbDrzPWrUeEwwFkCYy/ifrBBQspJKbNe6zdNMbT5rUqCkCCec1Swc918FdV0FLXT+/ArNtb98y3j5SY/b66+uBplN0WetZOwSLzKMv6syrgl9rWK8BXGiQ5ub5pY3rhlXavnD9uTdeq4b1/o7D1azZ2b6hazjWF92Io2V9IdBzf458DGS7CapQMJWmFLGCsc2ul4jSHsYwrbFD8haZyErLV0zLs6zcDBNZw7m5ThvgD4iMqFX1eT8+mOiJPn+wweuARTba+Tn4gh8wm6aLhEdlrUuQDRbWhi4m0RCABYd6tUyzasiTwVLg7YNnLgz64zxAEeEZBRLwDfLL9INAbhYZvSkrevoYMmXq1S4SkGhtxNJ3LmTXD2hzsehokTs99Knh/Jz2+uCel/C0vn79cF103xKsaz4ysHyzbtlUpR8QJD9zVzeCnT8Yn1oIlac+e/m6zQb5VbtR8+//X2mBEtP3i1yodwczuJ4cR/hpDAasVo5C2QvOS8nf3jdBVeopLZJysY3XC4LimMWXIjhxByF98nK9Gpi6G6rpNTPju4Hlqdqou/CctfYYdFB2TG69X4tn55dSzsl6bntb9QK071OfqmBWfITIr+ao7CEVdA3eQHzqL8zfs3zgdJjQyFrrKEla11y/6AljzDD1VEKtT4RsCk6KmDKZXtlyJffSN1bOlgqBq2tLaHyxTra/WwMWN3YI3azR4t7Qy+p4rUijd8cnC8ovVB6u+SR4j2LdbsHlMcBdDasWaL5lshGtaCiHRMEIbBqhJABpPj2TmRiF1H3F8x0Mo1AS9ck7hJrVkHjy5biqqAJKBwYQY1RYLVBE7sDwOUN0oUT8BM9G7drHN+eQUuhC5roZ/lZUNIBzpSplc7ndizXyMfLzkNlZ1hBl97bH5mKUczIhT5D13YFcWG7ZKl1ls3C9EhHYZVoQ8jHWXdM1c7nX3GgGy7NNkOzrPUdfHK6YmFpbe+YtI57rzuW3DuKlmaZscB9SPaT/CNUYqzI7nZbGMEXdXP6N5plmliWHkvYKGMoYGUjysAa2X9UNeSewNmqBtv74g2u3g/iu12uzN3w/4FO/mtlGMw059Bw0xejNzti+W4hzh/wS/QPGX0YLoGj70nFxiya1yITCPMUM9/CxgnYHPATSY+3LYqyD/CLLXfQqa7kwuWlJ0sptNqQNAmCWFiAeMmWkebpomSJ6JEzPZh/X6fZd7nf8Obe2APoL11tZNcPNtQ48e60Hwr7bb4b9lB5mPQONiZIlM+iVQJEFz/cEoXm07ZjE9ZYPHC3nTyq/hJSvCZojSJ5hfXd6FFRAlO67VTvXZ6GmECSE9Pby2oNG4T8p0PgkrYkso+81BpiMrndYxAvJ99WvvuZ0w8ozj9DVhWhr+2BszsBpygrQqLCW/qacpkHToYbezKq4nPbFHyTfSz+Awf1tGMz+vzGqc0HRCtx1A6VGYVZqi5teKDvWM9mswFm18gI8IljNevNsJxyYLsqS3LGzLAPZEjYgycYAc06A044pDVyFjatoZMlv6kevPeVlx49uegGISb7tjSK0UWQbxEGlPRjYYaOWBvryaBH0P00K4mqhF98ir0SAuhec2yKH2hvRnyQOmBH0y1ID2MdeC3Zab2yRSzWmHJ1m6lJSdvC9ST1djAMJ/xAGCq+GoRthojmq6tGsobBiV7Jl1nmb9BJBXqjDM3BFlxv1GF/wGwwRDOwyVZVtDKlrxmxUXbLNyA1DMFeCv4wClapB5C7VwHvTFWdBLz4C5V6fqRSYFUrZU4ej1MACYmwL5jNAXNALrRML6oWsmJ6rDlCrbeX5YfQZTJnDX7YA1kK9tuRHoGgqQYkeQQc/VMG2BQy6AhqzyCXo2NSaxpcfjcTa2qyp9P8gUwe0IRhxDfkWqySLtggn63BqAJdhPmV3+zpceQDvyHwd6COYdULLcpnBJaxzqOA98B2+o86oqJTy9uHGHyLVVwuq2A66MF8Eq7Mw/PouRA7H1VsvBqRNNvwJegJQ6r0OUJGRTFBNNt7BCqj2pMFWDG9EbICF3V40nfCgV0OQqqpniceaNqKuhIHNTVgvIAbXMI1RtuAxaDswQfMhmtDIM4EFA1nKbBfiI1ojPTPvN+LVhS6K7r9ubjZ1LHxADox6YnExmu15K5hyxkCYUdPxTXB38U0OAzFRP4xWIgzbekjvJSlMUuOqJ6aWbTvaYHUteB2GFtGH8Wotq9oSzKFvKMRtx81zJQmE/A75awysg3DcK+0xKtuALKlExNjtBpWnxkqOOkHPpD4NFTixAVHkrutigwJRs2Yq967BzClcJFtWYVgBwJ4C/qZkZba5DN8m9xLNkBhhkjwlGoJxL3B2AEplaIqtzO3PzoVHDhvtFsokgKQmxkFT3Vv0l1Z4fq5thGFit05HMVQElqy1NlssBQEvUCVfqMQg2u3lxeFu0vZgCfHPt06dPFaP2rITp+Ygyq5ubd2x7lj2oVOWzWu6Oqw3l6vU0eeWFslHbFPOatFVjfXnLIe5hpFRbnzhmRtb13y3Obuw4Fo+co0Dx+tA/a2iD2FjdPOv4KCZT8RwV3khrO+wDycqGRDOcNpZ5KKCPN3OoXIBWm9H0uXcIyvrs7ctA5dhmEuc2CzPKTVLUDbyeG2pZ/JBbyXmDHiRaG2+QX5bXzhwrL12e+w43K8BXwDyg991iWAoTzWYH1gAzKAjmMLeNf1P6/0quk1AGY4R2c2K9NIkH8XVj5hWrO8bhkH532DuzZmg5ZdzUmAfjB7d88puAIxllrx+E52GftNMHb2/NIzzMUMGCeK1rNi1EOkLKQp5wkn+ut99XrzcCwDuLqzFuDjzePUJ48Vbm2YgCRiRJV41Rk/5/k/jHlQwODAHbyhgp8BtIHQaNfMn4U9QJ7U5Leqjq4hpkuUnLRae4Cvkw+TrxVaWCarNbDgo7oixLSfsWXZHwbRXjig1QDIut0HcAtOs0UwogDO7nSiK2fa1TGsPvdAmVt5y64WvfpLeaDUwYkbMKLVtX4e/lcWg3nKrRKAmxXi8E76udmAppaRlW7OLS/4kCv0X8iU2W9wtwdptbjIXyOifPZOEZWOl6ExMck2E0VXcA4m8pZVFb4DeyeL6gcTptRDPBSsyrCSpWVGmYZZlcWHOaVnxwZn02FUHYctO07fn5wdWSN+FLQOW2bhjMW446EZobs03YqAHYHarxE0yTdV126yduhoSM7PIHjRA+g10xewWoMTXyGfp61m+XwLtOcq70sUWXIQxI1OU44yT8+4xasve9IAfFIR68mnZcJQsb+vMO4KR01jDOCHTCUvvdpvw8gqQiqMpU3ddsxo1tGV5oloz/SZ5v7cI+JOn2eGt9dDqd2o82G5G3s2N2WeOYR2KkdUCxgZDkokPa0FV9MjUW52ORXmruImvFL5vlREAppQl5IVl52NcDCwyBiDbpjGcbH8AVebDlHfyZv3Ika04zpC88oy4ma2VLKtgZSWywKYVmh3w8uHd/751bHvVQlB2LGt5Yys5ccxoNWuSXZ+PNqL2+e2GKW2sxwc2VwzXJbZrr2weLNTi38hfkz9jtTMJp6OwsDaxcLjcdMZgj7sx2XjzJZ6HiSeLDdFyAx2RUtUDF+yZIKp7AlICsJ6zTFHA2xAB56u2hUmtqqvUsyp5r541Um301C291UhEEdNoYtJo6dHM0qF5PckatuViIwVadi09PZ5GjaxTT1Y9VRK94ij/kb6I/Gnlwv7rnci/Pxmq4/bqCm4Kx3JlAOWm/BMa0mcrArrCToJZTiuwnKqj8waKU9fkdXwR51UX+FqAnSBeowvWm4rkxsJ6Bg1pioMRsQTbWVQZKZIkg1cEsBYTukmN/LaxfviQv3jdslkPzbgzY82fTtPjc9ZcD+lwd7gR1I6eOJF6TQPrArK84/TmomiupzfqVdGyOkuen8YYVAzj1DfaeVPTLE4teqdfJZ8nn2fDMd2Mm8TDYXu020ub9AImmAHda7rvDtJMB4AJuU/r54B85mNnftAEfmrKajVtWH5XEN0MrU7sa2mmauzD4/mgyCSLIZyhYMn+oGqkWHYDbDhSo7aleL9lImQ5iazLM/N9Rr6HAUDpRDlwg8W5GcsMVKubabWs6VieJCreRhWcLtnW4iF4c5Jr2M2splVnXDUqdLFJvgXZ3lb0nVgFtdd52teDKkPBtHO0Pmk+FRXkbs9pX29pAgowDOWf4cixhgJtDTOx7dREyrtsRCZyI6lm1Xxd4kt+BEdPMx5ZmjUxNIFcUE5Ar3FQIc/4Q9mQ0HhCNq1IjBVmiKppkd807cgRYFS80DjQah5K0aR/GqYbET/0iFDwtBRGuGZktv/EKLknThzN1CiKdcsguurORzO3zj7LzkynYwFux3UILCMFc604la8hpnyhcgCiZ/lgWBIN2FjzdF/PYTLFSsvoeYCwZHgyQwxS0wGrm6eipTnusj943MCEsinolZl98yVPQU8Fw3YyUiXRQ5KDIfgF0+00I6T0lq/+9IvgDtVkoCGTY4mVAPip71SXnbeCUCIrURwx4kBR5gWRldZq+u/ikk9OUO3rHgTVRlJeKGIBJiKffyDEDbBjkS6RHitquFH/wfFuBmGAMY8o4RvCg4HfBGVty+LVHOAHIQ8GhZ+KkrgeO77tGH4YtrI7LkfGb7JDP7TnAOQvgSLmGndPgPLvufh3lR36b2ytWTRpiLZHRYK1NxLD9hsg4f8nyfUD1Ici0RGkXcvqYdCHFk1qVBMFaRjfSm36cj12NdDM0d+YM3cw09kI8TcdwUG+tTzIAhcHWlY06mANXHGQDwDJwewsBqQZNFsc5GWA+ZcZYE7Y4eQqb7XY4TwYfI4RXQxsoKKwAxzvg2LpdyOOeNZS1E/minO66XJo/Y6sFYa+4di+g3NOolMPQNoXyCw9Q3mGME/X5eTtKZiel1yw3vqlJNS13fEVtO1gm4Hemp9tWHUD9IVqrdlSTBMskEiWB8HcSi8xq7pWNapdnzFuDTuNyc+hZ+RkZhd9YXS9ZAezFQbguTxKZuwG5o1lVImgn8LqDc3HOBCu85VUq/wD3anUIAYobTl6XiYfDJ39mAR8DWUppjPCWl2RWN7JiDqKQb8heGGsqHkvV7EgDFGtO9vX1Frswefgg2+mTuUDHC0+eJEx1sfl5CUzCX/q258kFqsSWPswThMJhE1w97BXTDFpVfQjWG/ex8djYZKKT1dx8zZGdZBe2xf/iOtjS9i1lR/E54fTbvEuFZP9PiXiId0uQ/6UlVfOae2uddumq1GBr0h7PzXNDHbXho2n5AD8/gXXQ3O2utwWPdfkoCG+iVZbtd/uhH5NVe3G1Z5OhL7Uma2uDxdt27AP3LmhoqFJAUUCCpDTdsfSgSM59mB25vlSEC2cWxAbeRucL9Y9tu23aQ5QG292YbWuxZgqNtJDTWCC2fmeboJXbvYT8hUAoLo68+SxKqHNXl2YnwttsOFEHhlTnHWc5oar++4HMMSpNNoNVDxq97APqMBTRk/ZgGfQ03YvsLPIYmFhUcf/MIHWzDvwgo6jd27YfC6Qc4zrNNtNY/WuuaRupCupbjFWAbw3JpdvWS1WoPxvLoQcnjCdpNtb3CJm3ITZxO12kPheKafdRIZm5RgoN12uBxygitY3VqbJgW9zcs2IVuYaPI/9drpgabA6QHpAksN+nZFiJaW/tNIPeT7QWOzzklSXPQ8Td7WFzfU5xfbYWKDjotzHiLko+4qkkq9StrxIJmjYyX5D9doNWNjKgUPDLqAE3WQLDmFGmHGUNJ0XomooWNVsK/UXg6Cd1mwVbk/3Qq1IVZ2orvuDfm7pQpg7ySjxEpzKiYoMlsmnis7CJHsZl5seJknd5Fh6zKnivsnPYBo8kNztfPbIfOhmPb95dg7mFSkSAHVh+ZZrNl2dtE9szGz0EwUW0um21bRNSGvjdL9//Mh2Y+3CPHiVNlFMg+9eeOJ3bQ2ecttW1F0IYCvmxc9xpzh0IiuvRpwtUbeyVGO/MPVY9AGLOnqXYHFwL98oatUSIC33NPVG7Jur+3h9+Ih2AKAyLCo/vGuZQR3OpEzcA4IBeuDTSM6mDBgeJxnSErgo6PhDy1ExKSBAeFKwGP6iATlaDForOt2KbTiOgWUR5B3oEAIY9qsCG/OxF23GGedBlfRpnFpop8lSTQstUyinW14LiinZtpuO4BbYGJ3Mu0hqZnsezIUtRGGkQYx/1B1w3nfeR1IMX6qhb7OQ2uyT55SEL7RUOqDIs16DgPUtLWO4ahqNrKZgh2DSG9j0BuJEVQBHKAcdXsaWRFkNZhnMLF38O+4CdrksVJ5WeSNLdICG12lYYj/l5o/+1nS0VMRiHoZfMCl4B3Y3l4XS3ooXOi4WE2JIepaK5aoXuhs41oRhnQblclCGyeGH8gnsysIPt+L0xnshh/7IbB93l0YC2tuWXI5/JL2mRXZ+ihjY0INlmnUsHkHWXFMKRhzGpNH/QZurYMeppsuWUMrqXPPqrmmwboqDkIQtiPRmPoxDoMgUI2bLaYT9oBgF9jBiiDE0fKFmaKMzXs1XO9Em57hYORlqQYIPsP1I4/3AY4kEr5hqH7xEQi6CGqcbfXvu5jmTkdlMMDFNK+/1nOoYYZANCQjUjRPQjdkwDj1DEgTZQnKWpqUqiHTnsf0Ms4yS6DoG2eY7OupaH8msGkJI4sUvcdehMd7HQM6Psm1YGLTpTTaPwaP50x00a61llqcyyZHHIh5yqTBKtuykopEukVv++cEqtA2ySQD/ySWwzdWwHAl9MMiGCkw2O//3YxHOjZAAFiM6lsHEwYlqw0nlcu6JD6shD8dLmdhqefS6MCrFEkAsaavOgCJsA1V7gSly1qOUys7n7oAQDPCaRDDeyBkhhxDQRSmkoD2Z7olLhEz0i5/hzsFwjlZejH1mjK1dHnxrykqYLIc7QMMDZG00eblXjiOiUACFh9maX7J2gkvMqYBkp/Ji7hAJ+iz3IOLyy7RtdIndXCopib7LqgpaV69qO0v+HCy7AKkVc9QhUrJ+9089a8dXsSsVy2EwemWDuWkp9uHnvPMla2OAQ4m+0/2vpRBVhbHYd6XIGhpMiIoyEaJhlkJMdCbEa7KGo4ERvs+YyCVGtwgT7jBPSOqR2wPfQHMEMgeQHZ0TWRFLcnx+zkwQC5foh0tZWvNn54xG8xJZzkOWAKFLSepSIcl/uD7pS3ouk7k9S1La6vWXmFyFv3j/xS9yZyDELlhor6u8m5lWiXOOJq2ftdbefpMyX8u7vfaV933lioq11fUWEtLV4hPYrKbUKspPKAjw5pvY6DFCFWda9Tr5jDfj+mw4B3wr1mKJtPv/1cj+4Up6x/v/DOamMDx20zQQI1U27SVV1Z2/CWdDcH5xMS6VG1jt4aAkt7FwhHWBu76zsLiADRc8i46ceSV95/2/KCiTrhuYqQo2nMpljGXDb6h/eMS/LxXxb1R5duVnKh8t1osChG2Xoa9o/086XXA1YMW1RhPg0C/GIIt9IOTKq0O7x8jZxXanMDpAxqtj5j62i04W1GKWYvCePkk5fPOTbt6W/XkHboyJWEKZlfNIychPEsM1ZzW2mQn1r1zLsp3/cyV1Y6etACcgQmDUj2Zca3m83AIdXkfSLnkqXTl946mVuGBhGgrWOJOz6Qo1qyLzMIafIIhkbgj+oKpU9cXbF00PvRoA2FdUVX6b7TQEj3PS00MZiqF0FtkqHPzE5wo/sY71Mf+ldPZl70nc4wlLl3G19+95Zu/mrnzCdEf3VK43Oc7QnKbbPd52mgD8MFejalUlOZRqdeyyRcaOwNa7tY/UVrSxs9v0tV+9kprw/mRYVwPHzBQTmedspFVR2OCTZdmXwwU294lNh00HPPH0cN3wTMFgQI0vk3+9slkVhPqnhVBPYj7+V1iXm9tbS1hWfGG0u8uq5Db5E6pDT5xsZOvtfnXlY8Kfa1EtcwJJDyW37ctemFhW7DlSp+U0XHuuUXwRz0UiGwtqO+3VyPIMrOUrfswWa7OB5ZqK/+QrKWxMEbugl9ebmZYerGsJFguxZZ3qxjp2OUUrxeZONT/dUdC5Vh1J849kHvX02LFSoPqi4m8m7Os6/cgVFT6L/J8vhO8BpHlp5ccg/mFZ7k63dF55p85YtcW6HuTvBXJ8ZnT795448b23j6b/B5h1BWX1gs7myTw/sd5ur5/I85ObnRctbKFj1NpaW93Cfp7WFv3FK+pwP+yAp8epvgO4m5eDfTn1zUjGfq0oRtmho+icbNscDUtQ8iCyZwZfr5dQ+2RlLCMugIAyLijsIZY+hrssPZaVF6OSyLqvZKYddLEOrd7Ud24M+nEY8MWAL6/VFrBom//o8OkjvdNpSFD++rC+80ZQbwC4ORI2JmIfJ4m1uqrxmJDQklGw8wpweqjAhi7kJ1+RBHzeT+AVWKjLXdD6va7ntM2smGdHny2nZSdEjougDBrBDMZm2FRzs8AofueKJOTQgM8VGrBaeVblJyo/z8xyPRenu1YhdAayF65Z2u2zSBmZGu0+2WZsL913UrowV6SFs8WUXEaL7OuFS+g2sMdJuD7wnj/HpA2A7gD7J+lbrE6eYBNg1LA8f+mGZ21vP+uG5S9P5VhOMXynBPmm5uqRRvPQcpYtH2o2jqw2r12sod1vO04Dm3viwIEDsNDx0jEi6WFSXCBGHnfnY1mO5+nHJ3IMu51ucLkk249Vkjv3GoCvwCbQ2Z3ogPn4i3/PWRhLHOIRJsWUlZgXHad8b8F62cdhp8945CW9ufwqINh6sEUKEZK8N1l6WfZdwrUHwQKLnaCciacoOIYTaNxVwNSwRsqTHZGqnhOZGCu9SgqCEERx/v6vEbYlef441rsjF+2EPwriXAnxqQV7l+vn6FoJt9c2LDVud81/+Wa0ghEC2VmO6HVmWvV5wdY6c0vhj33GbKchni6id2dm7R3RSjqr13339VhK74Lq1knTRkHB4wtEL3ZqG/WdD5L6DNapzWPBY+EAP4cRFR5g6EtZSkImQ2JF8Jgq53R7zLJYJwy1XJ/obOHtnBLhZBPjBZst5/7dqeqDGNG0tTW1IXptAdmgy2Kaqs5Ifwy0CdGjL1qXiVmsejLtRqKywl7EZI7uI83DaSxIjzFn/WMlvsQpVuu1fbZ0k23pjrtnSORlBbQjiMB2HJ2Qw5eCO34tYTutb8byGMvyeT7U2/zOOwg+Arcl60q1liindv7nY81k/3zqLG9+gLMcFyYGt7prYwUm/lnwOLjKacTBSrGbqsfWzPT6lzxKAt4QAZEhFSVQB2NgjrEwgunCntLItrDgoi98J7B1+mKhzVbg4tgMtv8FnF2MsKLF7ikH2WADuCkODRIMdXBs/oYrmKdRje2BwXk+ZmD9FFu8ht0o4I3qTYzU8Wz1zynd1+KlGI+dQQvOqjbtZKO2c7p9EgwPtl6N1vqzdsddWFrw3vLvBtphm8bFz9K/ASdkFpsHfpxN/GRoqYd7KHlJKGU7wFv95QlKvuathvssKdy1OAALk2iUT4JRIVEkNMALCwbrcELI2xV4uarAyfdZOJbr0ddmuS8+BBRb4OQWKbDYjyj1PXvB83wQfGoYYS7MRVGTWqy0DnaKRJKNLmLaszc8NOoTNV0ElIAd8wX0WtCVJTl1mgyhYy0+E9ujMRDIk7/DJEOsPy8M93DyiP1EIUnsmuiFAPvw0CBYgt63579rfs8S/LXkGXkGTwwpMDPQ0AvDj+38A+VA1QETh+37gnGGjKwMarDg6zm/898K85QxhYpvPAUCigDl2PsEtIuFtxhezgheo13IHO2gEjHnrriAPr8Lh9//rwMMwNBOJABsBQ+vkNIqmb/Ckrl9iohXo/8guoErFhLChDeDzGsMMqdv35XLEy+Vy50PJpe/eli5vGq/XH4KcjEv/m/6DcjlTOUVDGJl8Qr96/35OY6YCak9HclaC1mKvz7dyFQ+kAybJdvAP6cshXGfXGnRncWmBlDLfI78XtDzHUxL4BEuA8MhO28Xfd8pBodBDRAQNX7Ts19fnXE0EytZ7G4oVFsz3uL6zqfwrARTsEsKj3yF5fymYBlPXYM8MQLpOjHbyICRZ9d3KC3WVGFDq6pXfV8kk2U0QtcMV0P6kl3h33Sp8G9+9MJ/gFGGCGU6p1WO4Ylb73pAm4SRjaZpXGvESrjdoc6yUcIqPaYp/85GiT9dpMO0oz1NeVbZc0fWJtTPEtUt0n6Qff/Ijoueibqz5c+HtQAniJZJJ2xgXpy8Y+c85pxjdE0US2DzNWXbRHbYDuBfWxvjwRWJsbP6isdStt0F9EQ1PcswbSfX0i6e6QQSoKwnBgYLGME4xepZKNMqPHuXLVMgzehqraFh6H9Q1G6y5ut7/ZOzRf9kQH/r22Uglyb5/3nSCJPb5j3Qtxq6EPi4a/DwL08EuQZ5Ex5A0dPG2WhtiKrNRBulAgs/UPku9Cd/tSSfXVHTJI+oT7P+CLoo5MIVNssd+gj6NBe+bSeF/u2jMtNvPQoz3RG/XZfmJd+ujWJd/BL9+q4GfOwxaoDwqDTgEbRELmvmsDz4EbRzbrrSGvG2S3ojS+tL+3ojZPXUhZMr5K6H6eX8BDEv6+XQLzwa5fjLS3Tj6GW68d8v1Y3ve6i2yI/ua99cZ6V4QNFuA6cD1LfjVqcNnLsmDZwiF/hLzoOeHKrcU3nrJVpS4DWX6EnvO+MqHlMFvOcVytveVQK2O+07owWNx1j47jmCEI8rCS+Vtm1aj9YXvGW/vH9w57OPscgtMJ6/5mpAL57AFhh1HyFkUyI9e7uZVgvAxym5W1PDxaDmHq4jFIuu9zO4CiWCL2dZAuEfFs15EpuZxF5KvNhyeDaNKMQh2xSrieRJu1APxnoMP7Y8tv5J0mKM9YhK8VSBZ3x7SOf07xk1AxUtsFxKMjwO1KE780+vgssIAr9Yy+ry18kL9lCf6wwFxAsPzxum12LvWYxR72JDhHD2J0/+Y7IM39q8+AUcq4EHud1V+REWXbuTqoaV9g9JAyIPB4UW/38AjDOh/0zwppXR7nPh2K/RHjQKjnU0WYi2D3Uqf6yA6bf4MRdOSh4/89WHYgo9A6XRDjcFcqao6BTJKU1NveoyKIeCG4ldPVDgkiAUOn0sLGUWB4lCEBoGWbCgi8PzQgHKhk5NLWjBmiqBDu5gwxEeT7DCyiHdi7QfZgQiZE0WCERCvTElENH3TmFR7MW+HBbVO72Ofjlqs/NLjDwEcxUL9tA7CKZMUpgc28n2nAJs4r0SawKXTHXYUl6gTC1h58WF+WEfCJD/+rEGGRw6uT1bIOF/yiWQ+mkkzr9Q+eRj6k+i/dTuPVSP8hHgeo9CIda+nUI81u6lM5dwyKv3+pfthwX+rvk22qI7M1NtqZmPUFsec1MzmYHP2NfU/NCjwQF3/uISjXr+rkbBMC7VqEsV6p2XKVR77eBaXoCKfwbt5rEM4g0IvAXSfpANrjqTselSWGxRy2iCCe6Ov3OYl1sq56oveY18RyDFlxWTfB7FA48xAYulBXC4bHT4tqgqFKv3sPtMrmepTG7xMkB1xQuY22sYO297zJAifRXWDtYUg9RAj73/l4gTxzLmo0zsa5xdWTIxLILnHah45i5Gh4pU19psoYLGcmT2qi1MNoy0RjvWdwJcBOJL/2qCXf3MFQUXvb2XmGRGBbA8ZFvBJokxG9hCW2vZn2pFsS+SvuIR4ox/8JiS58+YNZUrTs/V+ZazcI1Zx9RIZN+MSXsZm5tc9ggOzPpJvszSJyw3p18vAMeX7Qcca2n1UsCRXHxURdPrVAdPzTZ5RkWkxwmsqh7bhOvooYKEjQO5X+8YO19Kmg1U/RoWvLmeK0B6HpBHhRPBrH8ha9vsgRzt3TUyE5yDoRn7cY7eQ8IcD+Gkyd5Y0fQho/kyqh+yj2YAiGN3n8tocTI6WjroCcZRZ4tPsfCIfgo4h97Dc0H3cUPxWPWl0GdAx7t3jk6BDvYA6inO4cK4yEemOEfvlwfNyxEOPAH8PhtpDJaMETxlEs8lRa24/HT2sGPMbjp26YudfsPjOC80sB1h0PbZH/WOI6B1BBUqBXmIsUStYkN9PXIapqJlqiWTVgl1BOEe0nEcSieTLn2vOJh/IF8hWmkEElu40Y6DgGXf4CYj3dUUcCgwUEJs0az6BchxkmC9YlD8UU41D6mgiiw8wsNOXgLHHxVox5dgqxrIYPdV3lP57AMog4+wynxo4324wmf6/Nip+RYTuMXYNR7rMhr3JgnBgxkx6T8yGuHdj6r03PnSgxt8yVF5mEIJQFvgCrtGXzXzVvEKM3sSRB5lLlQOH2D7rID+sYcpoOnKqQunluNHXZ3Sb+z6imsu8xVO9CBV1TvZQt49d7HNvjTSqsMWvGNDvDz1GDCRr+56DGw63PmbhyYaoofxp9w64sBJYOW//+/npD3W8voyLUP75FHoGTe6/zvDVLvpIWrwb6ta2qWqFek4hD3dwnjZQ+kWiyvfMQrbe3brdASCS+v0Ew+qUe+4VKM0tbFfp+I42K9Tf3FZFOKxA+PP6Dfptyp3YpLqPaSBJG/twP61+CyhSMuFONPmcG+y/3M4KuJJoRUMIcWOjzmJTddOn3w+LjwYFoSuFeuT17jdTep7j83YffTJ/k/uDichMC/Tl72npZf76QEGHCgfWbs+9ooZrCglTrC30HQ6lorPGTFgP58+V2ZyTWyH8XgdnnCO7H4H+rpdxsd19nSAg+zPew8fY3zq57o8e7KIjNVIWOzK1tyyFI1nD1LC9Kgsg4fFFzw7jm1+xuYfETsWZDs46eDJUmwlBfuOht0EsqkgMiIoLuFxMnMzB7KDzdZ2Wl/156uxoUWL/mo93W41D2bpir8QR3i8lSxjzUANj3W27YZh17E5F9O9hhPpddtgr9lODSPJ9muKRbW4KtZEx0iGiwcQ8sXy5KbMxjVEjBGyx0GIYkTxbB8JffB28WrxtIHidTXA7bGnIbJNwJpsuXju3ZcolrIiqINl5hu3L8w1Jp8mGIA60AXA5gg84BaDuBo2ZG5g/sNAKVGsbGaQCfrveMSMZkklCfH+N4Q9M/UsPMyalc2y1UpXMcxbd/DMMJ7tgNVkO816WATE9uPzBeiN9B3PFMCjMrDkgC/vEAugX8WDLAJN1nY+orB1zgqQFzwLWmGbj/EINjzYDv1/PBsa8gGjALeDpHyB3Rneh6KBtyFObA4QUTZEeB4Tz1a0gSrFHmMOrxqAVwimYcEr/KP/X/EK/12OlvTph68M4/D2x9C6wvPbH6PXhVf7DpERH1l366cfjZ/9gl+t7sbuolL7wv/H3HcAyJJW5XZVdVV1deXcOU53T7wzd+LNm+7ejWwGNrDkuEiSKD70SRAQWGWRBQQEJAgiEhRFeOoT0MciShJRBBQBFRBERXmG6fu+81dVd3VP6pl77z5R2Ltze3p66pz//Cd85/sE8BehF/c/2cZqus3JLlOSomZNziENvc+wOifSrOusyenJo13OVi/V5uSifmYkbzHS7qzxYqsXvWfc7Qxajabbbhe6h8IX4ZgWwqjbSQRL0rVxx1NRmjTM4aKOp8k6ng8l9lnqeQZ5LOCjv5knPTndBCOCwBqfXqDw/efJpPl07V1mubt609Oj3udUNSgSA6US9T2tFYt7zKDvKcRtz941zXTf81n4QEGjE/U9+flrXn/Ff5SWfIj24HCyBuiD4gZoZXr289xLuBeia+Fl2kKB/waO7iuwSh+NbpMOFLs4aMGOHvbyQOyIFI0YZDPqIUey1OtECQfmLSg/dEnuHc+czi8d60h+OaLBaOJvBuy9YMNGghys9FaT/X0/ZNzY99pzoArJ5qrohrtFD0UElE7E6bUTaz0wG1pO24E4larJUY0s5dWG7bkkfQwmIQN6Oj5O2l1e1fPqxMnK/YcgCXaVsWgUApvb/Az+2l+yQeuDmkz0p1pTId02qj7VKvBHHrvqtPgHKw7YZ/HIKIdIEklSwg3LoDcuGe6yO3P9jFVHI0MEGKFjzU6HG4FdJ+IlthreP0OFnmb4alFmdEzAhuIKkYjP8ov4hRwQVKhF5+t00cHrvbPf4/+J/z6b29xDnAlCdPkjISBBDGaCWpILDIewUXhlqSbtDsOZxTRRspgiSl7HSiRm8etxUusjEeXc5REIT7rXHcSt7mfajQI0aerhCohicmCWEGePXnJsRsQ9WgA3OrkWcZHnPesQkarTDSSHpZLS/5IECTneTrEzb35nQM9caDeniqu1MrFSceCBOlbjwBjD434qcZt/2m3hUVd80RZ1I8eu6Wa7tsjxj+UUq+Q2LD0bq1LKct1jQxqvkZN4Q+2YsgMmPEVm9vqrHTigOe62GpafEB2Q7ipc/ytD/M6jUvuuuTKB7Jhtvgnb/GPmRkxef5cQ092INmJPhM0xceWYMA6ymeMGGJv7yconiYgqwtncN4az+eVxnA0n1A+tLnVkAXIqQhpwE9bbzh1DvM2R+8ctXmV4lgkGY3EUc6PrGsPcMMRNKULcxIAb/qL9OclHd3SSG2InAZmOwjE3+BJzg4swMHjPliZUjLSJFo9HtpHX4xXldPdJ2MXyAhWTaarsKLuJ7J6OpaIU5+k7GZ5/E7pPei/VfaIOLZpPxsVPftuPsrXkYd/JtMzW4dOPetHtg77Twq42pvAbaX/HNgY1Qha68juaWNUiG1eLtaGNz1xxyRqvWV2LtaDq4ZVqk/pPU9R9Cgo5YjrEfKB9NcalOa7LL20xrmBC2sQsAUETm7cMCgaUvfTR3oFERnWAl49tC3quxLjXJcYtkHGzMO7nmXHX0HP6pczvHWxN9f45zsJ4Q+nwsOvEX6KcuuVhN5/ctrf0sq29pen75xg/eoi+WDpz0+WLUXfJ0WdTTaRrqovDDdUiegKlYQvpwUkL6e79He5P7ni4b01ugArdAPemmkRx84iPjvxnmFccz9yVed1et3IgbTFva9y8Qlts7W5dkdKgOpfCVLDBUESZNIal2PNuBnh8/7ZrjNjueP8zbhsqyY/sXNTWqijyCE1xnwY1OUiMzs/1zDSO4rKePcc/ZjsbLVy9MLSQF7hQIhaGBiqJ7KRDYriw7RX9myiS1exFpflKPrSNCiEnniODggcjjFq1KA8wEyC9X6jo1EO2Me/5F+RTc5nbUUW8Nw7X/pChvd0aytatptARAVscZOZjWSzpHCZDWZhxORigIQgEc4h6hIOmDNWrsV4tGwUc507ElN2SH+UKAmPCjH9wO2rCsJPLsq2Ayfee4vhHB1N6sahPBcFarXoRaKRr1bUgaBtFNHHxtWqNvlatrdHWR7ZYq8hrz3z89WZhGpM6Vy3olzzvkpVHrRRPgUQWZld8D/RN/OshlZWVBNJVFRdumes/Mwz1MG8gQpqNS5tPBMNsqYhYyGV0P6eo789h+1EJTLNh/ww4xSqm45BOY822W87ldsM0gy/nXLN0eLFquDmZpn8obhQZyubVxZmKEeSoDqavKpApCIp+pNlDpbQ7D6Z+qjdBgw1RzzPeoekKNAQKjSflmiSXSzMwtB/AwqdOm2gWCU7XrRUFvgS1b/y6Qv83RROVI6aSlLZgJwpSyzaaRCL7DDyNi2yUkA8VZFB/Pj0Fgoo5dyKtV4+WeyKy1fYWsqIaGGg6XXZ7H+diyCpPKq5yjHyKOrzMiis0LSLmHnbjcxGBWLvJZoiR25DDuIlUd02g0VDA5gJCCZy7agASNDZx9aZ9GtSaHqiU8UuBm1ENTQJEkRE3f8SDKo+UtyqFHzyjoLAegKRiDm+ELVJgzuUVkxO0+rHDaDcpnqGG3O+p9JCUltV/pmY5so/eU97p2fKhtpC1oCsUtFhlI7QW14tN7jeRZ+OLkJaMZrL4CeHGsaMFsBxV4inuCMmROr92bLkjvU8LfTNvgXH/UtBfWVJYCqTC4YLSaFYkaaqmPvv2Tt5LdMiF/gkWgSyZDKnWrIpiUj3karaYDR1++uilx2fpQ+EAV0AtdhIjvzOZZwDU/m0E3xVSicVUPRZ0RglKiCT+eHZ5IPfNEBnNdtTEZEe7O5wUbXQifFrEW97uUj+TMZTFo0NG/0bXOfr63koaQ0U9AqpbWarH6qRVtg2UKEuTqh8VxWhQRe1Qd8DMz0WflFHax1dFxJwVKyXS+nJEkfaCSxCgDfRGNBm8Y9RlLHr+6SZkoNFkA2AULdCp/j1MWh2tOInEoyGSgC9nucc5TVK54wkKJ/Huoc7VXbNZCagVaMxW/gExsqyqKt5FKv4ZhQyZFN2YRhz6hwx/uvmfbk1FwLV0CMdnMe8X6YiSxG5udR26t9I/41rM23NwQmqS8lOIvgo47CiTyKMJldd0fqrqRbRo0GVpGU4DIyFgbiH7pUh6TjKlQhGNL2g356DxqTAJ+ix1UdHwBNOoIlFHk1/nIdJo648V8bFkptMo5AMH+1BFjInRDYa4VNOonVpp9t9GU1DsauKBZCGxBjp4Doz8hdvD0NMNjtTW8qJO7WdbJA5hjj+uFQpB3uFAgpsDCTNgHSe0AnDCQA/iR6It4zIIw13VMojkqk3zijdlxEwdg+crBDgfUoAfybyBEPZb9tjpimBcrWLckk/CBu+FsLG4HCQqgYBkePIySBDDY5HDUrbQTLNYdkYhd/Cp5SAeQckJ21qkxkrk2i42ZikapTZmH75667NPn372baurt9E/b13lfkQNHJXkm/NCZ+3E6hSYvdVBLPn20wusNc9N9/+Hd7hCyIqg1tR0plDNgWmvUnanbPSrjBmn/ybOcD1MYDR1is+T/kFo2GU2WQGqR/exOrZcJU1KHqALbMqjjZmV20fPtFqn15vN9dOt1pmj7SfOrlXzUnl9cXGtLMvlNe7VkGoJbkaMSLosghyFFMi8XaY7lq3d3O5M81z1mK0hfZRlv1g18StQ8SeVrKIHBFgWLuaC903Xv6VWygVQtbumPx9Ul8GAzjnFSh4D6FlU9BCINkgEA6epCDmB/j+j7EH+CZI9/BNBEWFnDmu0TXQfr848NfOLmU/h8vDiNVBc5Tsugq7T0kN7FMw1uk06QadluBQ67G53SXhIGIeNCQOXYf9KgfFUHLw8eWPIOtvt8c/dZTsUIAM+DxrBnVdLn5Xqyvxbd37brsyJFLwQp7mATU7ShpI1K/+EMazYbORAWC5Up/QVygaqjcjXboGXAZAi03fzb+VqnTYlgbVLvZGF0RcPFkaNmYU5U+WeM1w6BaHY00Z2Tjc/OGzr3JZu67DdSf65cUv7cTrcRjOwOq06XeciTWOQYt70whgldhN5F8Knhi0RvnqRG3mh6ZZdvWaCHVhv6XmF1RegfvTOfoH/T/6bmR9nBWSUEyYIlXa8YJpQNxOOFBg//D8FDYLwNlvxCurqgAQaeUITLVS4RqKn7CcXCrrXK8PBIPtpcxx5ANohH8lqyIoUswRcDQz1hYITkpCnTAEROiWw/DtZcMVsJ2827f5/WiDFZrOjHPQvQEMMQZWc2cDKjQJQtIkF1Ej6ZEahL0GZGudNW9A/TCuppNMKnVxDciTJkz6I0OvmHEWBrinLyO4DiTimHTn6syQ5SBLx3dgUxxUmsa9hiAQdS5IMNQrGDbmi8mL6KpjCQWsvUQV6r+5BIxW9ahdJfZ//VuZlmS/SkAkTVyGJiVIyumTA9ZM8pWPx+Cl+ljR6P86vzfH4Kh0o5OntuHHD5ExYjT947HQg0Z5uIiGkaxsPucpHd3YbWlbI3OeyqJBGdElhKjT9+IDleUnNL4deEOlCIX9IZHFoq3h1kSk9zHFduYkPy//oglvkqMGMebNBbee8IQrosOCaF/vzCtTn8ShEmpWS8jcv/tktszOQsPQ6mOpBNBwvlWiGE8lCiqQqmqUtXYhc85dArM3En114sGwh8uPKDCVFkhYW7+j/b5DSIoeQZSBAHZCr5s2aceKzVtOE5oHmYWqD80rXJ5aRwRsMfU0VPwqfQ0CcoIGurvW/2Facv1ehkHCqjukuCWrDsiDRBmd63lOmLDgVRGwbYjQKFm7hmNV56uURzT/0rkRq8AmUDwjs0kdiYeRVSzGFSPP2UJd7Hq3zWErJQXTMRc6Iv8xCHtxueg9EOx3CRyBeRxkA1UxR8wEpN/DXcGqB+usqerjf4P8lc0nmNZkv4D4fkAjG0iGYY5OtA5aYkTPhvyEVDF4kXS1HHBk9HGN8K+5ctxUr9cQsziuU92FkxLMkkEq5ONOrEcjXT3yHvmWV3uYEm7izzzCXxU/jOVZariQZ46BUpU/SbEvJfvpJbr1HG+lROUH/hwukyj0M3PZ5W0Jyjlk3ZoyA6dRmA8RxUBPbs8X14Fqmn44FM881bEnL3uIAF5Izp3HSsRIhMiFcCJoEekltqrJ95dVWVW1Sfr6A+lQmbXXSjvJyjpZ3RUrz6PFjsK5CaLB2kdNzj1zKvVOGhD02HzREGNIlxQQHKapo9q+qIY0FDl8mJ4biaQjQoUkdAJ47zZNDO6riinTlQEKuYACDm+On9SwklzAPz2Vd2DQLRbpKpQ1X7CHrw0wsH+Qgyw2qaPooAiEKDCWc9b264fkhQdEAFcGYTjFdmmHL5Cv47+a/CaQHmNUIiKDbhDSgGShK1ayqWPlpp27M6q6Zp6mfCina3CJx6HooRpoI60+jTsKg/3+cIkYkBxsBclejqcBwTh0VJBLJ0fgrqWEBa9uxxI3Jj9K0YCWKGzUuNScgsuqDzwhuHbT9384dunXWXrDsOiyAjVvMwPgTOOcGygIB7EBzvrh85wr32tRwAErSh2/+8QdJjgMYBIRoaTigvfddUrFnB5qVGgioUKDJXralEdVZObrc2buN+O/Uiho0+a2GCmsAgYBrHxgR2tHL5zzNLIjkKnrFGU4BqK0kVUU+6jHllDmfDQFyTtHk1/ZqEpZNkG57SZOQXdtfgn3/kSGD99HWp6/hAo81OoYOsMUUvQkahytpn4HLEOY/PTLgPzwOJRUiJKlxyVPfvrWZbzQPnZzhhPDq666EmNvA7tx32UNJnv/36PmXt1ivh0lrd7SNyAuVobscftQKx//CYFCwjA7+AER6JkKQTg3wo9TBdwoum9CIA9vqNUBqymFiBH7bpuGdCwDJjDiBU7Lr7SsYFHWKGe7zzHD3DQ3H7vY0KDi2XXv75Wd2iC+YBY9HvSdQPsf5/GqP+n8xUiV6KZI2fETuDWReYpG9dwgUzuuLQVavH11+Ppp2xcjC8mAfWsH6hPh8/gKamH9yZR64EQ2WKso25zqQAJDRFSyrUJWveK95i2LRnnTXpBZUNQSmpYtVaVi/E69Kw9T5CEAMVYtxD6hO5gH2qAfYBSiw56cLjykeC6A8kNcql9fL9GvzITDuMj/D+vZfZG7xpswfU+tow1/Z4hwbkW+Ea6NA8RXK3C7kmcYfkkPd28BYcD3uM1W4BE9Bx32YJ57gBrrMp4iIJp4rsEGzFxWPx7ivviOhIP6x2HkYBTG85xk/M849/CLovGwTF77DH8hp8C3FMacROwHigdE0PsOX6pWsW3M8g8FLaRtbV1+gNfS8TBNnQTcN5w5axcb9oJkmhgDsQ2AGZDnmnYspAmN72QCBMXbwxwiM0XrYElnUQm4Sv4IW4ohfuWXPCrFIzhiRee5DbMtB6XgqJBBUb9rTLJFhoxS2yg1Rzam2ZrnIxf8CG9vEjU2icrwilBuVLMMGMT/8PMsbnow29O9HdFNt5gaJttHqIH9on0dvE/Y/u+ztMlQUuCRD4AipGypeVxKjjAIukHai74vCgSIPtL4iJ/qNfY0vOzuMFbnHM4P2dMuh5SKngMSGmlwpJzHaWnpQuL2TXLWAxZTESfpPSCPeayvDYWV7e7z7bTsOFb8Gp/g2GDt+ChR8rJ+4kUokRx1hm1wS0CvCCMSEfBOnhwJRugz8iUtzY5Ltr5+58pFHue2sul2qyK3fcWknaTFessXE0xunNqa3zf5o6wUOkos85JvkIdx7x5uET+qsQpfWahpjRhvNB81SyBv1lenFjaqiVDcwf9897QM1j5cDNiA2ed8EEBcZo20ZNuKO5MA0DZoaQpXoJnDOfzCCw3UTKrBIoQo9l/Vhx6VN83rWCGwlAo69aGLYTgaLfMQihkjOpfiSINoO/d6RzWKpBoGcASw74ZdjSShrFqEhgW8ZmVNFG9nBU+weBH2zrh5Uw5+3piBhqPMb3pzpWobT9bLFimNq8AFVg94vHmhxDuFTJiko3qhomobGssn9Nh7JLw6JlL7mlS2ZKUNIg1U05fBzfv8d1LQXRPR3VUNB2Ju6WJMRbjTA4qoqtYQDra2z5iDHP86ynaIBtDDk7t2Za+efiPEGIHBFkU1+uWC+U5FlzdP0o42Y+QK21tH8NWDqWcVvLnU2v5X08PKWry4daxrSYBkNAikuC8i/poWaJGu4+jGBZOPsr6h2vkRgU65QtWWBesKymm0FtPT9piuOKSrjzfkS/8+CAzTPazJ/cM5ontSR7axRchFPA2IBIeF4ItkYCdUlzX+G94h8KZY0QAewJdI+YjSToog8OhKwvdg9wFgntbr8b++rKhiH+DwaHoCGPnMBrkDAdkforB5fYVMCRce/i2jelQvfPna5ls0yAV5EAkUuw7HqFTcsSUXI4kEIjvNatuVyr1XAg8tJEIJTbyA8MTmEXaQZAca5LeycyKI51SzuXTAMknzupTxJ0akOvAIfx5zTnexwVABNoLyHHgdkqgpNNi04iqiFMKFA4UiLJE3s+rKFa8bWzEOQg4eiC3xKyxcxD/s7knUeUAIsBP2vlmwst4qYKOe4iC31bwRd0MCWejOUpt6Npi5mxeyEM/cIV+xtmRXi3exuZyu0eIRJIRbRASSZXcQRmr0Xkwfg+2cZTpl1/IfhJEYdRv6D6wDtKfoRNHz+V0WVhethAkiBKqFSzp+k/hl0aoHwb7ts0AMywRJkjtHl19WSjkYvTwQMjmFXYgKGfr581GXNfINtAym56FnnTSwETc+1RcPDlECYLrnD4MFlvbKpyBVM6q2qybUqgITlBbPuilAXRiqE3pxTV8nc/76VuqH5NN21HQ0g5mIKqfzQUaqGNxKSmf9YrhgzqQalpTACoYdByRaLUNkkumTIcCkAz/UznKJrHgUSQcCekwYVbsSct1aBN5L00H03WwULGAmkCLG7a0lGTByG3cNj9orM1dnGBlJyiFNWGFzZhBkY2nWte4KP1hS4bmswzQEGmv+BaJAtMC8TYzaM2Bji5kNSD/ml3jwesoGY7lYbEHzmpqLn3DvNFXMJ8S3OZ2w2NnJXYDV5CqrtdYFtcQk0hsE4FkMwFisd/hHA74SIjg4OQHjDm6/4j3Dxw/T0ojCcpac3CNn3Jg/wFzlCsw+JbUfN4VXDQIvYq5N1+1yU+HyPZcMEoHwrCd23sDEHeft2FCVZdRT/y9po8YWQmy6luAlxWMIgiaaGLpKevYdw/Lu0Om1GYv6TrzXpfrkLnczk34Q3pvOiaRm70XKSGS1ufm5LHjS1tLHU3gaOJUbVS5wob7Is6L9Ss7b/2mHWhuqVKywVVOx08KWaueCF09X4X1ChSDulSks7ZLepvCidDPfzu03O2M5Anf8h/1mINz45TpLWo0QHGzcAPFMnky1PwvvRQg8r/GBwHW+bYXZNYsYsH8UmJTVDUA4JJJDODC4uD3MsojuQXuXMqYgoWr3VhLSjreSOnT6WM7HK1W1VpFxUCmaxeIGsIGfkyy4facWTKDPU3DC9+zKeMbRZrXrB1NkSAN8uzUUbAP5Vd1925Uv5M9CTW8EoL7IMNkzLG42wGmKJWW80G7pZNRUCGSmNMD/VbcjNjYZi4zobLAds/iUn6wXPM9nTjzMdiWaJsetzcP3jWGt5yVYgIbKD8+S/HG1WRcACqKBH2IIY4Ia1K8IcBiTk+cpxV81dfsPp3F6O2meO+s9DR+1LOznqCbvXhILfArC34uZfcBbE4TDprZjYxDAa9uoTj11092n+jvPpl9w0p2BhFZKMHGE69MDXNYsSAIFBw1kX/ytCnv8esJyU2x/P4smvrscwLqTscwLduNGgJ14Zo4kh69EwFAabBFUinUgWiRjUqNfq9lLTeDYH2mCWYOMZGiY1o9XJxWRgj5dA+ZBWKnkmdRtvIB+XllmvMJo34dv85zjl+46e8RoO2zjEnEQXy2HLAzrTu/WBSO0cV0CJW9KNovHyBYXG0It3Hup2NELF8QKoSAHoqYQbm38AqmAM3TE5y0KBVxF1RTRltqvFH1cszGO1nq4U+1fPzamOqAsEqnE1jN6Xbi2fmPmt1X98ltGoVVQMbEhA3K7NHbnprruPhIaOrA7bleX+JdyXeW/Wo2BDsB1q6NAHrkLTMpeNiEGytfm1cqkOVnWR1dsykJ5VkV4I/UrByasuMCnE79F/MABGzhQA4ZCfLJ4JFejpKTS64mYEgI2w8IapDW/JRetm2ZGRUXYZfPvrMPPfMp2pl2R+dWKdqd3O4fhsZXgORXphdMjgMkJ7h1M2icbUI0e4Cz+2hbuwr+qk5rnbYR2drdA4LSwW47P6N9ZMq0DHkFOaZ573v1+27UHsPzshR+yMkiP20zJTFUZgODsgMKx69vzCfEJgyD9r2+q71WgNkdlGI6m9P5AvlnY6qcB35gdciPmtXIhsEQOv/DZDZb/ywMHU3QfQunPBo+qH9gey5q6dJL4+fJ/x9ef2B7P+0F4B1zj7SX4TGM4e5QkdI0Hfxui1bYui4LwolAKDw4ADshpWLJZX51heXY3yaq7fOzCv0Ry6DViPNnKoqVkGzfF3aZUKGgyia/uHQvEBv3TlpuLcdn5Ii77JY3eRkRa97MISbi+l0Wy4pk5E07MB4xjuJP4TQ93J7Pkk2n4NKnzVgpi2DlBKRC+UtZSm21IJhTwBu/Y9+yIheqjhuETHqJtTvY4dHDt1zEctrNLeNS/6pKPDD0i1CQj405l33j+k2t2J7bO+mrYOgtc1Aybtr4xt+L3qIEzaygEpZ16bEHBG4MIIdwhyzloew/mD0mc/YX+0MT83NG+3Y889cFZHs9K0mXH1bpaJgPwl/48wLVFmv+n/G2X2Hhblf2vAkL24lSE7RRy1lSF7wBzVeftBGLJv282IaVrsSyNa7PY2tNhnGC12Z7+02C/bw3ZZ8Pd8nf9X2K4DFpbnZ94xcaJ3HoLiFhNNkt89bgJu6u8cLGzuetg2v3gepEOtfcXVn97deJu/vjvHNeMu5s/CthtY+bj3oCKQuzEyHdzU/MkDkgn/3A4US+dk3I8dVCfnH3dmNr70ACbFedRBeunAZhcD8vwm0pQLk4kVw1T2lqR4FpZgLNkcJGnsVDh2bQ4TdemAohO7py90VtGHCgjRy2JyFxBell36v2x3kR1izSXvq5UQy8S2oGEDMScBA29wfwSOFFW1MV0C4EVrQ9eIIx3lomGA1GTWL1b6n7oAZ7d/C8aS2eyXiblHfI+W13NcTbZk3OPQ/+Efghd7uhc4YAcBcDEAMifHGISqrQpx02CLa0FXCcAIGEByfq8fPb83bGfsN48Y2++0p/yxE/xebPOJHJpmZZ4xXQMLgSw/A02tKwUOI5KPsl27GNAy6N/B0DKeN8k+oErxo72Jpd6WrTsiFaGNFykguFToAU69gaQoVQ3Etqe28KAMwNVL09kRIi7w+AxX6KOKAO9hrzLobVRVDEuG+BU9/p9wd6KBqgYImkg+ZEO3DlkxOiCbVzSPL1RBoIomSxm7JgRM4Vlaj9pa3Py1pKAQOMkN1CJqiRyVEjm/HlwFQHLezf8EIdyjooLnY/SKWcIVrpckk8omVo/4Mis3QOBoy0ZJxAj806xwQA+TJKHYbh4Lo4LWbDX11WUDG3plBU3x0viKHmJDx4GyHbBjR0USiuP6n6SyBPN6S3RYm0bKBzY5IStHWBM1rkjKqEg+yhOJtjerCllVrU+jE8o9bfCteLfj/Q+yV+QD1JD0mtoMQ1p/lwl/PgGD1U9Ql7/bZhOuRIYORjjErW6wKRezKqXQiV2DBEq/EVGrJfU5a7nBf0YsikoxeheOkjGatlS4IaPriaixR6uZzVbM6LrR2VktVKZ8LhxRJOQeIxVwhqyShzVLMkVEycrM7HiAQZOZ8a/Mzu3wKAyseMq7MbOBkbMin5jYjE2MJSwuPwtmRjZZFw0zGlAKpW7C8WoAh4D6ir91R1FRbkyckH8Ox5Uvv3hdKyxi1Q4mkOZX5kWsg8L/IkORlT0bpe3AzAxbSIamXcKcMn/koqNzysDOwzeQvP5PToVHBduxQKqtDnlgPd+lYTC4JPI9H8kjY1IeqJBenVYhVS9X0HgclaFkcHzhCv4snOSVRLZwfziJMN4yH2FzjyoAd9Q9VtMbXKNqle0L4Btvn1neicj9ikHp3WTrWpYdMbyyZa1qLhGthCCCZxEZ1YX2i82ntMOfS7XgCf8WU7uzWp37zh2xwg3bzLp6VA3w0fzQHSQkESq6txQyOqCP+/3MNydN6s/Na8KVcBK3EfcXMSYoCR44QUkA2MV+vQurO9zuoef2iYPK5n3nXj2gK3MBHfDN+4o4/Vfspa9DAYlccA07AJ/N/PBA/C/Cf0N/nIiQ+NZdCInv5fQx1OXZ/6+u2ddGqImX1pdGqImvuvnKw2lq4murh4dAzRJ+Ws0JEqDm7QmrzM/+N/LUt+xCXqwi0yYnvQsURZ8/11tzQn9zD1KFb1zoNGtPj/raAev1z/13SbwuO2CN/xf7S8Uo8n2VOZWLbuivUQm3heDgfkjO9hfVhDR4+RhqyKvXbn/u5Zc/9/a15J9c+fxn7pPHqJdPHb2i3b58o9XauLzdvuLo1HMWTrSNfPPEyvKJpqo2T/CXX0jf+fX9RZxfsj3QveCnmV4eCEymM/UNCL1mse74fkSZbavltZHCvCslG5Bxg5uhgdCYYSuxW4vziIR1S3EO6SmP/bUfDCCxpGBeieJPImIe6ZYHiYz5QNOcK9H8iIhxdA0L0xqAsRGAnOiYK7IaKBo6GSjGLfAdIImWhKAcZsWcIUJ+T4R8uYyjFpfmRggspVqQdHrwss59h2xsKMVigA354xil5tVQK+Rs4EpttQgSpexxLh/6vqlqWf7RePHR/vv4cnfWynsY6JGNUCljdMidsRomZoJRBQ0j+zZgRMARyXycoEQzwbJVurjc/zh7C2+aGbnagw4N90x8v0CUKsBa9OtAwIaHweWQtQ1v1v83wKWlYMWwIK2DwcnlerMaojUEIqWlleCnP2lMtcCjZGrT8wtYncuc/Sr/D+BsZpQmB+qyVDlCpW8QgxkttHc31nYWvWF4r1Vae6Yzz8bx/l49mi1O98Z9N1n0NtDwMTwMDEl21MJJNHAkPh7KNqaa8qT9mNfto4XyAPpXzdAMvbRSNNKCOO8cCOLUbNCSQEcbo7kwX28CJ6tF7/PkPdov/edu6b7wiOaRiPa9bN/o/EVufyIpQOr07tylmUhz53zU1VlF3kscsBBOGeMB3p1Qgefcb/78YoNnDeMtYoHvT4sFPpn4pRs4w9unCM+eQBEcLpGHS/xfyKm8NvPlyCWoD3vuGaO/vq2+LwoiYasa8C5ecc7TV+7RUmicY/YICOEWDWD0UVJKwZqfG/eXKwYT2qNbJ7S/0r925wnth5MJ7SL/fI4rnjp2eOhLIN7dny/NVuh32KId3P/nEY1h3IJateilXGnwg9DO+cC+xrpwKg06o6RI/Gps2J7XQmTyQIOs8DyWLNxjz0MRMmngGc8tP3ZQqdJzj0RHk0j08LFI9Mp0JHohiTXNp9LNmcWZQRx6wMEVTXNQNDUwPnw1QXLTmeZAhGHvRHNlhzxzi/BpsFX5dG2Ri5VPhfFUlNtdBdUHdyMemx4i0yyoqUTTHU00czKEONzQG+aZziDPPD3USrX9XCSW6kViqbDUaepPWSVbNQdZ6F9LOnDlDqg1sSdiDJd24ozzg8N0MYjTzUvG0k1tl3Tz+q+ktnMsI1ZWfVxaYeDr/EPZzzArgZ5kpE+NM9LNXx4qrV47ur7zaqa0Sg2Mrwht0Ondk/lS5u/OY35S4SKKvZV01GACEFuixk7TgXMTggKitBdHrvOQwCCrx2MsKowfSVbqTiNPUi6yDuyMZ2LZERdNsOyOBZFXnh9RKO7HglVPAAFkWAzFcw8wghLNt+HLjRzIhmiY7MmB7/D9j6C16EgKiNWwvgg2LZnfftbwrvMkGMX9Xw7I7egoIPY4mWkoX/xz5rbM6+GKbFxIqygQ0wti4icj9kMsCcBTIxBqxO9I0hgMaxySMAY8kMhIvQiyMKBt30gCB+0PrAyUPUnnJoY4hIzYLVhZjxcKYn0npEJytAbOXyvk8+BTew99ZhVkyFUFZatAsPnCgq24ag8JS9Yt1wzJzLdPN5ZuP3TEbttmreRmaY+S57Vc03NDQtBvfpam2566/IgV76hLpEnYCbNyII0iCj3+KuygedNuJ8xhOCHA2CiQN38QzHmHVKjIyLyFfmoAYAOQEw2heW0zWHBBv6Foat0onSh+iDFy8WoLXIpYEGT4PZQ+nu1Ped5KWF9t1C9u2AYvFOxwtdj/ATgCiXHkTQiI8JA82D+ZOIpkKSCmEwrYLsGHNUQlog2Wc9o8Q/l/CbSnfw887AMzP8PQBuN0+ANm7TFebZkljIn2C4X1QfGBPYvWoPjAQx+WvyyWjDRJuZHoIXR2TWuC5McPehfYD1zt8h9KE29/cUC8ffhxKwnt9pG7mjMLbEqs4sTLQlyG2CU16H9gOCXmPszlfbmEsAzSfGjtZqXQ+u0dWlj9u7YGnxYLPsA56/l8dCzioAVWLIFTuBcTfb6XLwzY0wOjKjKg3iNjcu5qo6bwbyuFp8VqswZgrhBVITgKbDyMGqQTYjz8PMkD92zetQmKbXLp8GAcWlnUh8cevB3VbUIKGCNNQ7WM3tycVehQJMqpeT3/YNtiECTyih9irfDxmTcSuds57XJP4lIcPKp3f7jKb57Tcjd3Nu1pfzz0tKdFnsbD0R5yQV1oP3vePxWJNaS9rRx52+nI24xDNv+RC+hJItsiyvFfxxz6BshD/k7maxNPoieNQ/eH17gTzKDvnGAGzd+wQ6D60WGgetiF9Z/cJGPo3ReTuPfvGMVurYWCUIk0QPiPXTjP2vze7htNpHj7p8zxrsk8B1r0f51gXxlIkjplrAc6WERLl65r7ThFoXSkSVMS5KXtmuDu6JFbNCd6jJBsIp/ECyZxSW48jt3jNSzQjpp683RVWVpfzmdnl2YFu+04064e0g2fLZv2lOO2HA4YwHfbhhYIvFcAnyT3e85UDdgRr9K2XpQ9fHx5Lu2VfzLUrThx6uRAt+LIgx6iTuiWOXlvv+TH3PLSnA3dR0x7JFPNgoYky9uuRVJwEqjaTSrnDEemDTBN4ZR8nvglQYRM3JUyJCL9PKxfqATcTTt45qg6Df9xSEzu5JkzCzOJZ4IK+7E7u2X5pmbKKa9mF6dx9rNgXeUyD4bS3q9nvjXmdeJEXkeuRMPCKpPNi5xPHHW+1vm5Q1e7B3K9V6VcT6pM9aaqcnZ2eVvnm2LO9xbPMorkfJ+bCx10UO9O+R9f7sx1KtPbe+Dhpx7oWuX6T9yv/12dc/VcEGD4ZOmALAek81GoFHhwLsMvBEuTNNFywQerKA58QVOp+2cYXo+3g5Jq+Qj9OcfxC3m8sYFv17mfSF2+/A537/t2iZAgQxtGSLXU2sURL0k74lHmiP7ZvxBuRlvgUiAbXoV7NzPYu+XXLwJnH9ElsaF0QEQQaSXCCofrLFEhpP3NtrA2yOYhQ4p2zei8AYCXtrszyX578GZrnQFpv8EIGgc+LUT8TfB7rlzlwaXetF0HyYwiTSuF0LSKdQt0UKuLrTGpwkim0MdDlzgn/PNonmBTHt+f7fDR3CEBhdLTDZrTzvNGaPa9tko0+8bRhu6BYd90FaF/L10lTrmWcPZfghllQUm41Pu/rhQDa77Kv+D5Vl2jAFWBVuH1WS1wgIYRR1QN20B4tmNFQysoWze42ubfsySeYTybU49PTxoiCGg3zbdfO1WP+fZd9WJvyiCmfei6S0v+jBWxpodFzLxAH5PN6k0dvNOIPqIB1cRKRjh79uy3UZGa2Ot5AQQ/Mm60MZWIUVLFTbsCW1QosW019ACKDEMhyiR+xZ7EppNcpPmChfwtoi9QZvFpRrXC5gyxXAsbMS+H28i6/Ky6nFKpBHu+peZOXH48t5s+Ja1qM4HKDcq0oPYixv7D5M+Q3D+XBGAcfkQBJmq+bz6T7x2elyI0eiLfwnM/0fQGMi+PTMm88NcNBSx5gd9WwNKDI3spCUvC30calmarUZSmr59O+Uy+XCnn+3fvJAcjtRfXIRvY/wybpswudIRI0yU7NT8tc9pW2Rc0YErQXNvE0v4jMj9POgsGzywYI7cTJVEjGhwJycoHMTR0R31jZ6FSYT2BsTB9HrR2YibOeBkTpHsSg/hFBCYr/DtzWJj2wGjMR+LUOTlWEz3JOCZhL5CsgUKbJsdYAi7pgLQubxUrtSKWwzGxUstq19zW4oqluHmoA5Mys2Gb05auE6K/sXp4uRbOaipnyAWoU3CvseohknIrrFn5mcVFh8iREP25XODbwvTRhlXz0Qj2yg2rTIx8/G6Kpf1fxb5AwS8WSTfD7HandLetIhWtgXlIvQtzRLsL3hIiSi+jmp5GKnoHmrSfZFLOEzRORpiw9yQwxMF1V9fvj/r5JZO0UT49MevhdRx148JSMXWtv32nauclgg9I0MitPr97tfPNvRopVl3dlRFRqzjcc6gVz+10T88tzqcqGZBg71bJdGdn05XMLeyuLoPJhvxjOXMr5FD/DyM1hRzCkLlpC3PuqAeEe3PY3E/O8b7lW4jieMDtFF570zX+Th6wKKfomb66A+vNX11Y/+AaPO/Ppgifxohv087wu7tS5fz7BXWSOIggoXsCdgL/9Pxwqo/FkW0I0u0DlAfi/lwNXvP754OFfSy4jNGp7+UY4+UA97B9+B03CVn7bp5FHOzOoG3HP2wfqX6wq9u1plqpGqLAYs3XWawhbfKP0cBwvBu373tnZdvu3YWIN+OeJkzQlXt8uiv3wYmvpXu3XyG577xGo3GnC/bbmtvr8tLLzna0Qru6zPT8dCpSgcqmuo8OyF5tOYH0hkD/KYJ95cVEWLi/kkROu98oRWQvTQ7cjQuTvegn43IG+k4rkaMnhU77rRNXIgJy8O0pJBeGRJOzfKRh/4gdaSn7h5LyBaTBjMk9LmuwSTJh1WFiLr8jteSQf9JsGlHhUdiDs5K/MqlZwCliNs1hLYNCw8qU+X/lvwZa52fBisCiEiOvEMvnMEEtKR7cDlHHq1TnzfEyzXT94V/QU6cF8l7sC1zA6gs0zJpStOg+vLaQFosIOIs5TPH9UtV4/Q+POB0d03eBuXYEFjX0qalylpRvdOBXnySlvkYPhtfyj8IZyVv8u72wOW11HjDV/1b7SJizZFuneiQLNT4rz3emjBL/NMO0NNMHixNgJrqums1Lmg2MXadcf86BxGHVCdcLb3VMQ8lyD8BfXJn68vSNswpp9KAUUfsVBKuilhwOdH2g2iVZeWDhUD/k2CSW+AxpUkLcqb9NdcL5oibs3R/RmP/ABOkcd8MEJFs/ckGj7KN2TeMO70rA9YkLFzozEjzgDzGy+G5mCgxJz8i8JfOHWJvLdGIqa1gVzxq2YwzWLEvD/yAWziFikkIqvx5jJ8ZkMBN/WE+oLoXD7TF/qnCxWjKorva0fB0yeXjBIkepHuE35MSrhqDDOsc6BN01l4kzt9DZD/hPl4vNW65aDuWwXg+vrgdB/Ub6E0Lp5r05NN++vLYy99CWiCQcouLWIW/zo3CPMHEPLofyktwL+kn6vbPHk+Ye48oabHy/YS9vELi5RhkPDBme6htdmzxMrQdp9+KNoAxe97JdbPaa09fWNtyCVDs5t1Cvel61YBeLdoH+ZHa5R0dKSSJ4SW0jSxqYGhyGMJ/9V0WL3OCR4Erha/1wyLFeabC1Xn5qZ+d4ertZLRxBcicFXORtfiXtaS/SA1Nplze/LxS8QrFQrIYDJMd3MbN/YOaFWDs6R/51ag43I1JGmJLaEu4ErhGbfe8yAI5LL+Q/cE7j+LfYlabNHzKm6oFXm7I2P6pXCuZb9vQBzS8bldoEWX6vVa2PJPdXRsl9Z2zgfiXL3LvQ3ESfSwn8sJAnpA5+wo42vtsOTKleuGqPFP4VlW6nymLDH8ex4WEgaXov5uj/MGFsEMdUeRLUN8nyxPaO5JLCMUEfF7K6x/iVROQdgiZjAWVj0lhxkpu0LKRf44SQjhp/snPUuCtSc3rs/9ii4vTslXWmpvTI1+ACTkSgXh452KzozF793A88D3Gm7uVg+/zmp9KB5ua9Q8hso1GZpETkyX9KURy5eTSOBBRHgiiO6GpDTZwqJe/UmLo6Ul/iUnpQ3AfofXNqvWgj6eFSIecjO/vaj7dnZkrH9ioWpzpTer07WwUS2tr82DC0MBAHfzZOTX4KqclXJgZx7Cc/kYY3yQXpTk1SLt42AuL41FbuWB4gjoV0DvPltO9QDrNCOcxld5FzGEv20DVev1MGc8++u1Z+UigeGi0U/3V/GA6Id9saFSakGeLoqjFMdP6AeQrHX6iG1t74jfbZTwshAt4lmF7dQ5tXaJsTejS+zagtutqNOxYkOQd/ImeLVhToRXCXKlMKZ9ySbdEXWPUwyI/wVmLKITsTxKfozpo0PfaS0Md/2O9AzaPS0Po3+71C4GPvn/JLtbwQYH/hD1cfv6ZNTdVlgG0rq5X+a7EyAMr0L6oVoMYh7K32W4+j/Ij7QZQa5Qvlsrb5p4nfdbgv7RmIZlqNyiSZMljYy8qUB306tvTZdkorJbfj2uDsYkWLqgNywcDHQq5AW5A9EGALU9yrkzyoAH1hmqbFYSn3q7tGnN5sT683Zxp75cobzdb8VIkG20SN9RX+O4wA997JCXDvR8qrb+1Ok7v56xeM1erUVhrdB4/T6H5bcW668HxV+tm/4VHMZm5EqvJ2jDPQDoDUM8NiM945vksSPDTyYmPDpHUwIAkPq6KXcNTx8T4BF1O/Mxb3yH69SDU2prcLWKsI9iYa+OYyCT8lWwpM4pcdxWSTIe7/HCV1Z7nqLhgkoQqzGXxxtRj6YE/HysX0MeXoU9fLEo4RJPA06DWX6w0QeVCjYdk3Qcxua6j7s33Db6g67CtgUAmIP4lJs2WQxcrVnGIWT0p117FUYpqLlHV1Wy3o9Rw175590m7ax3tITwoQnbbMGbuy2FqBzCu9VORRp7rEKkfLZnyupNdWjp1arnmB6Ut50+y5lUW9kNeq1UDc/KYITfGpQBMhaS276s8IlSY4qWU5R6hv0NHngM0hScfvuiU1Z8qmmnPU9tSV7TVzdq7DNmV877D/oe7FOGSXgRXjFAx4DZG5bmArLL46A6oUhhzREbaeqa/EvZsE279KELhkUyjRbuFC8Vyo7CJcSZrK7rP0jCQ04wqqjuxFsztmjiA2uCmNsiEGpSD7EK/jmQ0wvUGai3m3hTVlTfNFkvYODkBPx/6a+Om+jx8Bel/G2gcOahHaJIpYsEwS0MWFrKhqyWicbv4rYFBcdWbO9uZUJKgCdh/rNs7Rq3eioEOetBcFHdtsBgXdRkRBh9vyMNqqF6Ot2sWQ+X8SxYAbD1c21rtEskzRLKry0cineSFL0PyBhEg34YiIaQB2ohWBeSlJwzlCi3adXY1VLqKUZGCRjVkGN4jWdk7FDVxEyMFLsDLEovDral3Tpd9YJ8R7zokSARA8/pFu0yLXdJmbZ+QQlBo4UkwPIRYNKGxvT2LT5WT7sY0eDmWtB3qdhVnDh+AaUbRL6lyAYTXP/VNOw0WZNUBKjgssW6hWpNIVVb9i5yImUSnfA9oAvVKsuXA3616xPveEudLREKLW0Ay4DPuELSaKJJlQbAztF0SkEFAwyQ5oIfIaP+Dk2oYY4l0GAjgo7Yv0CdB7dSr+U3XPcTQPOyeG66vPoihi6SagRwqJxGOVw674gCf4ge46tmZD0zsIH26USGVZyCyDY4ns3stcR4JL4QSEbNwF8Yw/moRobfMHO1n9TwdWb0VWL+RyIUA+EvU/xNqOVi/vwZn25L2N+PxRIz5tTyPisS+h13IKSndrmWdn3sP63ye49VVGpT9gt+NRvkqsHU5Pdnk9KY3iBFaMZEloiNb0mwMKV6Z/0qZuzQkuejeY8ji/BiWVQ1wsCdRcdpmYfTSFGzI0UsSlS46FXKFK4D7wU6HWoU9xGgNIbDQZBhqdMtaDIAwCQ4hQ21m++GLb7mHAkUUvOjTOZkzo1Nn8Ywy9UgaXf/8o9w/gS0J/A3bpGP1L5xB86j5L1k3bLiw9fOkrS6/59h2OEai8ooTFEiC6v7H+NkylCmrZgqHCWqNEcgn8VNdyFD4nYd2O8g3BQ9b/zkpFveTKk3IlZFkvbse8ZFWb0yW/52kRdJdTlUq1IOL+zPLG43Md+wHlOXQpcC26uA90fFOzepUI5pC8Dgb0OTMsq6Q5VMCdB1wQZSod3BClmV6FD9uzwdORPYHzFqrHZW3eilQcJIUdps8Ll4O251HQO3kv412dTGc63Esme0vjJSQo5dZz6AVjp9CLNv7XRtl7RlgTZf6m7QSlZxNB6Ve8O9UCefOYDna+vL78y1u6J790DImG3P/k8LCWwcDrxBznyucHZ3WphqvMU0d4e0aOJ1ffXVea217peqwR4iviTewcPzB9jgvEdp6c4qfcWOrJWhtixkNqHqWVv3Gcmekw1AcpXkadjLdPzHV+YW7TCRoSN02wVXLifN+lm5/ZcxLt7sVVOEno3f/9+fK9SAeTRGglczuwVB/ckXSQFYfEOYhUZpRy8MLcjwdlDcxXyp7ASAOFsDmVT3EG9tfOewoV7MkD2NrKA5jNokhnNIBukJOUNAsg94y9feD6UR84tbcPvGYXOr/DKFzI/MtYQb57/3z3XNi5INbnZ/bJRlE93On/4fm272/vk1QiECu37m3AHxs14OMnyZ8Og7SAzHRV5qkUhDf2zxSAxIf1W5KvCBfEbp864P6/PVcSUA0OGQBOnW9b1g+6wF+axpFJLfC3L0CYZnH4q8zCbuZY5ilUmoxTIF6YK3ULjeHF4zSGt51vS+zJTMjpF+ImHKcYpEP1OfbIrwck55cPtHk2su8ono+LcCxVfeOBN8fG1xajtbHNs+dszRFbQujZyIWBgy0wQzCx22AKfLFaxBaYTFtgWFHURQvi2NChwBZYPtoCswxvGp8g5zlBAS09Dt/nogu/p9Ffftuo0S8aM/pDxqPmMpYLycAPzvwE1ScHWS0c9ON8dhYDLIikLE0l587FyL4s/YaD7wgil1RnaRX0bqfT8EE91UnM3c+QuekEDswtnIO1z2Hnr2B4lpqfDrds/R0ns/utessfGP5Yq9BKlSp33Dhq9vUxs98xanY+Mweyub6gw+x0VVK9MgDFEXMKhHWEiAZyI5HCiroOAGh5FCHRTI9641BrCYOob1eNoI9zXMeT0irCxCsJelA7kAf0QRH2zl5NCtCAve0KUmn2847FAy+8e5X7s8BSfJUo2cDAg6IlagTllDJ1WXUDa1UCG0ihQSNdhLmEPz8VgrWxqnsdu87DKYQgD5psKLgA38dx12I5B/pl+GbkKISdU9QmtLbzQAPhr0AXKhKlCSYrsK0lMH1imEwRJbM55TTtB914fTjtXWH6ogdABnmcIMiKjo8H0pymZklrZ66/9nK7rApQcJVkQp6UK3nTI5lt8ZheNXDFirqsw/xq3pQ3+5uFYmA76DsgYzJ0HPZn1fxQgDy4CZ5S1ZHv+2zThRtrAnrJkFF1w9AlzcHjKDqJkesYmrPPj9ay2gOF2x4dQhorjkojRGuY4Vpc+LMppksUrsJhwuKQuVE7sEZfHVPOGj9JtMavr7uaE0bilIc4yfCNsM2T4EGQk7N0QA4x2RyrXqLaW+FlBVp3Zr9YmQJXHzB84UwJr/pEDqDWzddt6Q/Esfctg9O4nPcdTXX12bC0Xudep4au1gu5Hx+VLoASzswU9yR0lUzTg/qO1spuPgutUMJO5S1ffaqE8IAFnvmFW3kxb3H+npGVPfMvYPUxC0G6l1CH7twF6ZgeUjxSoglH20/pbwtr48IWEOzeWEvkkiKLcns2fPg/Og8CdfxhTlLzODGurommsBQFRIUGhRp4jtLGzpbtWCbJt00bhEWbb9+h5zMw6fxWVsPuNqyGV0Wshtx1kPhE5M3ntMpivXZ7HPmIRRnCTxT5XIy18hh4w/o3cdzVGvzBhCo4dogU+EH/V/bo+zBLf17AchdqiXsINXseagnOS0tfgagK86kRayds2slZZUPHMJbHig/rJOfxr89XeYGBFGyuaqAtZuJX2GYQmKiJnAd2HXZnRHVDw4stO33ON9+251H2z1e9sc44EEHip2E7ZcrE0340I9UUpUjX5ObR4JDN3YoP81AtHR36r947AmQzvbN/yv8L/MJFJ+inwIa4lYR9aGYYbu2CWVkcr0kePF6T8D8/NJ+JR3nercflx4uUJ48XKd2BXSpn6rDKHXjikVXQWx5XmzmgVf5yCy16Mmi+IfOGiHpsbDQMRtJqvF++7VDYC/1tR8o9fFk8f3Nr/vtikB4TG4ddrGpsGRCjBck5FX7La53K5tfPbVQN4js+nhar0bQYfuAClrPjmNhectrc4JuQ8hjRN72Yu+LcBtc4WsexRHYLExe6GqX9286hiz52AXIjRUQ73i2L/ryzmgH66CtNnKxBB709KxIFtkR4kCeMNNA/uhXRp+m1xR1uvd/TQ0yQs70yrqp04RBeQ39Crnm4GuysYLD5bcPiltBTZf1zQSjkb3rKlTMBepUG62FHcj+HxlroS8tLgxZ61D592MjtdzG7/QwvUEKPu3ykVjiZ6D9xQlqt4OJkJJLP5VV98z22wHrnAQQN0TcHb6wBky6d/WvhKiZZcQQaBS+aqF9zXoy3pWNz83h0vHzPOdRBrPPE8Yj43PGI6O/49KNoxl26w9MP00//ltGn/9EtIfAIwLVfFJTMKfAvZjjoceIZRayWGPZCXHMiDYDOeYx1N8gLawuyXQ9yoGaQNCu3cnw1h5k6w8SYwYDvvz7k++8/MxXeAL3YLrw9dbfwdn005/WrLoKbwpLIhZsWEnr/Qqtrbb5tW3r/tcmC2Xd2CmZC5iTyhL8H7fY89ibg950dKPVneRIeH3Dqb2zXMtly9bNXrW6M829Hz3qcgJt/PpHlR0qGoygK1a4u3vCcW8F3Lai2Vsd3D9ogoxf+l5MjcWf1EEwjWF4WrK9D7mzshSbk2XZMnv1Dxnj/E57ndxAUnbCoZkvVYkKRQDQ1d7KWBgZnfvpmb3enUjf7+0UvD9sy+hvu6ID2mkfNAd7rd6Z5r1+FZ34ULY0fgj//FGbtr5ygOhsboI8UZsLec/Rh9MFkPnobnJONUZZ9qtogRPB7gxLsyNYS7N39a0R7vAIrtLmPJNXXoZk9g9VxJHMJCf7zqlOiYAZlwzxZSfPkTyYK3kjI47m1PULV3JC3/mXQrG9amOcJ3Oo4v/36iccB7X/87BeB3lRxEdyJEervZD6Oy4AF81GMw8bYXkl3y1pJb2/TiACHSYymt4sT1o3IUKizFH0DbLISzWtZNOuNGFKODbm+rSEJeBaurH3uV7APS/ZUnxdjHwjzqgD88Jy7YUdgbIHEjXEPL6WtEaNpvHVPG+LerdvhbFD0DLdounS/U/hCoy2gJexbsVNWy2NYK+QnMvYHxPyVdy7C4lOEMcSakb2MNyCbz5HFvXBYWF9HFsdr8ntY/J78xqkN1Wvy7KOZhbLu12sNvziLJV/8+u5UYwHKyDnMkhGxf23oHj/Lxe7BcUvbuEf/HW01x20gYThz9hv8DxA2pzFveGbmdUPE4R4RkTxlx4gYQ+a5idLJjQngE+/ZKVIObPmiQaSsTzXGIuVUKexu/vsECIxb9sRLRHDCPaLou3ghFUYvGQ+jHyhONesv2/yXvaAXz9sLJHEC4ferzHY3Zp7E1vDPw21GtqPGJCQHsAdY49ZXRMI3IM8g+AXDNxxAAPKt52TAbkENbLX/YreI02naEne5aCFLMy2RW7nqgVcd5p6yi0zjqzljTKaRezAz4srayogRW1PtlBHfLu5mwz/oFCWz6D6n/zT8LENhDEpA6/tAw3E/G4MriKrq9tbRocjiITRbpp0iE1nsaYceHMMrGBDxH/h/R2v5cOYWEDXHC4HxypPdY1xSLHqOyTZETP5hwss3To5Q4RkFYGckXVxCj2AsW/Qk1qaOM8/aQGeeLDicFgHXchwqDIVIhUHi7lJcdP94JVTK+VuHcg1NGxj090k6ESQgoqb5EfCINr82mj6mk0eepZ6Vmq0neSeHGoslnqVa6RFpsQVSDVBd05lREWg/ntJmqEXSDHO/qxMn2DaKC+XVi6573AsfVFqK00qL0sqbFq940PUn1ZGkclZtPOlZP9JgSWnEzhFnpSoGI5SW4gBOY0HiO5jkzaDx8eNskSVe1KUDtCN+d5Jm08ZIB2uNWBTigxod2ajw8jdisY/oukw0HUDByP8tQ+r2OSxH5ndC9D4CiN7NX92p6/SC5GR+CwUXGPfyuUhY+QH2NPgU6aQKxSYUW7KiWqsD9HIUd6SWC3AdkWVFbIgZYUnjDxOAV/cK6gsJ4It7EMcL29P1BOCLk7K139ScarGjiGEcjmIW4RlmiDqLv4WDBBZF1WQ34h2soZV1zU6QheKGrZNIi681xf4To0ZY2JqmLuI8QuUPYKnLwIT+uszvno9Jwt5Z0cbYrHVNHjcjm/JFS0obJ7hxUyb1IXbkTmTX+f+VmiocopSW3/9UYXaHnGhg7H9NjB0PXq8cWrvQaOm0y1Uy6paMc8KdigxeTgwOcLFli8AfCyN57+VR3tvZZr5wJUt8p7m5PeYDL31Q7AJYioMPvIjG9Plq4gSn4AQYvWbduKuZOAL6mXCETzJHwAQSS3gV8HDWFlYP1Rm05XPIBiKM2YugbbwnyowbBZnB5JOgzDbkCY/yVvvHR/mK9tVtrSIISgp05iegszPVcL2YhpwZxVLV6b97z1P9XWH0WF+XPtad1LHeeqrBf/L+8lIlX7WxL29ICQbNSTBos7Zh6bl6gkDzDFXnVePaPc/5i69IH/Qfn/Cgvz510HmUpH+FNkw2cwUCcoajugK9L3swqqUSo7sW/zmRHcEBxxcj6qHU105w1JEEwJNiOLH4pZsvWGdD4+WEEBHh+vx16NAWwmLNwq5jJVADjJs57mfCokhaHpKE0Du3PJ/jXurWSGCIviBNHVqy+z9puv4ytk/NetHknXLLFhtIf6iH3J6R2RWph02Pukz8PdZ0q1Bozzibv2LUSw5awWVbWb/4BFhKQYGFMQNrKLMU0TrS5MFbbOj0VYu+Sv8pNfrHEZLoqjaLvl8CdS0aBJ1m41jz+jfewPoqdrOQh2pKqWYgKzlx9pv8JlpaxzKPzryM+vpMN4gtzy5yQ3gK3BgaP4e4hId0RGxIWBphv6EKb409shCLYtGd2Ns9a432fvk/BzVQu1TqcdeUusgNeMHxs41OQzQWnMI07nrax3R8odJup8SBhOHOyg9nDjEK3qrOqEboClzmPr9TWvrm0pQgNFv892SIlPL9l3anGuVboTOjI5ZpFmtTXUKQCFW0sGSrWixLVMqJjM/mrUN2mmdLju+g04sAlXULZVIi9Onu+0uWhB4/eXwkCaWuG50Irl4Ky4hSp6BF+h3YwGW7QS/d2tDtjDdeO5M8zgPZ8votAy9/vPvav2SPJ8pddxA7jmPxlkfbr9GjPHL0yMij7M72ho+Se29kyY+QJY+NWnJhF0tCDtbPlIQi/0/YEUJ+t76SZnBvYn98oCBAXd7lENslG12G7omIGtdowz1Jt+HyxJlChS502QJKKBh3QhDGFFuIMTIJLfkhxZ2VYJ3/GOgI7CpjVSeWu83PIA/1l2zfAcldIC7dscwJ1Sb4Ty272ypLRHgk8KqGdqkb5Bl/GOAhMVMv15VNRS1qdk/VJNE2wvlSLsh1ruG4wuz0bOi0fp64cjXDV4syEVBD+guaag2J1upeImWj7bq8783ftoyF8sC3wB6L+OYXwlwIRyoFdiEnRGBuy/WKpp3TqQGJsSjeCrHZO/u3/D8xkfZ7dhMoYjIM2J7qSskjXEftuXYqZpdj7NPBgJcEXo2SM36I0bsheyPGFNDoH+PcHdm3UmxJ/FvSvPXfGSon4EMUczoPuji7165IWUYLDuEslZd4jeRoHSVH+1e4OMFKrUHdqYl6xpnT8oKpNdotM+fkWgW0gk6dPFJP8Wp9a4xXi55SRKz1gkj5IBgoH3iJ8sHVTMos8FWAsmYPz4p6EetRtPuF0kTHoMJRHozrPBdpioG7rqSzBoY9b3D9Lw7D0ZPSe3ag4aRQxGzzJWabizLvvGAyQTsbdt9m5d90HvV/UgZvN6eKOWBGxwyetaXtzd2KzZ0ztXqjycwdwtwXX3zsfAj8cGAyGBqdoiSMDuzq0OSnRkzu67QwxxkNnXCm3tm/ZibtYIXiAwfT60mRaBxngrXn41AuB5NsTJ3Ztw4PmREoNbLj69A6O7dDW4+s2C/u2RL0J+BokYdnWgLFhwoKGJm7jEsZtzfX2+ZEX7PdiTZ7qN37n9iLotM7+wVm/tvQG/ypPePt1hMZWTQSk1zZYst2fBC5rekItQk52pKq8Ww1asfoSoft+hEb5Yq2Xskx6yi8o3FzWwxzSWSXzXeu3vrs06effdvq6m30z1tXebV99EyrdXq92Vw/3WqdOdrmXrFjLL1sEEgXWSCF9qfGHvijadV8+Kitrs71Pzu7XldzlY3FxfUqbLu+aAFGbqMAQyEl2akn/UjQLPzm5Dcb8cUnndP08akJKzsHvqj8iELmca7XjiIx/bm5Mtg+pjFMhTGwxt0F9rVeBzgbvC/SFEbUCaAUoz/Z1T50kGas4nzTg3cBfa0ro0dIyNkIHDuen82/t7sgT+GVXN5XK6GwriGw5SSAoAzuj4B7UVWAtPHoLa2tkZPXVLtoGLyan/WLFUh+IzHLZr+MLFEX36Pldfj4zka9lNqubqeeGDUHgtrBSXqgZlJukjpFWOTrXyWbsgvKE3zCyzlPQ0oMIiXk6X6pIBOXBrglij6R/AB+M6erKOn414OMV+QsXfVoJkMLA/AA/+znAFJTcdZ+JfM5RvwebXUjPWxG3fZ1mvzH3DRslTjmQu0OBTW4MLYZpYVktDaNvuLviQ+j7A2wjimoVEqFasCxur7RJjYdajYwOrm1YbcpUvFcYfvkMq0uRt+E0jZ+N9bIop/JfjSTkOC/R3eXThBGRdx8v9nM5RRNL/hzhq9087a6/kSjCTY19ojsUFMKLeAzwDSkNk41uHxpSZR6xfs4/phVsY4YYC5xZOBaeRccOEB6m6xyBdpCa3neoWr1SKN+vFxZ8vwmpHQDQ4ONVbAdce3pj/Kkiam2Cia1Bb5mGCC/fZ+MoZ9PzF0/YWFb2gPYWVJkT8PW+kV23TQruu5zTwIwnDExoBOhNTSwRvP8iayuGVN28XCpMK/KXmDVLOLbyWbtaqWM7kKLmHp5dDJ+F6grkeR/6PYJOk49DziFJBMQHRRBUs7S8ihSAmwzSlClgT6tC+EXgADlbF7HB8mCMwZo9mxOeiMAFyqUsNjqNvrdgoIdb+qd431IYsIGfOcS9KTmMdF5Ia2us8ZxTA1gcnGM3SLPIu49oB2qtwz0nrfItyRlIP/xrAf6G6+EZ1DFjDQfBkWARYayK0zIdvM7O/QSv5K0mPof4CvtZizM4gITKQVlrEtwT0ops7yKlFnyQFKRNAv3IaaNWgjBV+C4wl/Zc91S2O5Z/ENSiDirsHTra5J+4VKynDHaL/wTigfa7EyDtFZ4PnS0TrdBYisBZMMisRXUP5HaipCpn/0TYR3Tl2szL2ecK8vsqDAwMREORSNsHuOw1BOd44CPYslMeIxLqFpjarwkZXLZckYaxozvrXMDFDO94QiGOQEvc1tkmBjdWcRUwNRguLXHFU4SkmA9qrcjEyhEZp1lRvhcYoQbshhzmAXfnbJ1gIxnnP67OMP1JFJkU6d+Ac2JIO83bT0LMqEEvQzSL1e+xqza1kwdnSJHvjUFXbb0hSvajliew/wF1XxahUm1c6WZbLbd9TW/7kBy4+cFzu8ZmlMoPzps+ZoBUVwgVlzrqKqg6ef4OfQxmx5d/jmpZIWeiYmAIqHpJ8u63n8ntnp82cIFgX9CUjvCK+edIH9nOFcIF3h0CAv5Hx1gledrLudeOg/KFXfeA2HE6bQEU+UIca+2a1XjGqsWYldkusrKnj/jf8j/AFOB10dMEakMBwRjw2yXjtcacVhxh5fof0F8xTq222XACQiLnUSWCgfrjNluPUhaLcTDHyvwRGI+tWGPOW4aoKnDtfjbx+7V3MbJjdxIasvtkN7G2SEluRq6jaqrfhoawmqhXwtnQFZtsHYC37Q6jaC1uGz1vK7XxYt5kwnvRBTXxcrC7AL3d7g1V6JbkxoAsIWnop0gZ4Hc0hDA1aaK+ZviKll5awqL8R3EgNQccENJMht9sv5v4ja2e8RljqBcDCIFntqZAunvcEyAZ0p15nwuqmW+JzSRYlGz/g3npKwyOprzQwnzzvXlnjBRBTPqE8NcmX/X8kNHFVOuuu7KyRRTvpQvF+xBM4AmdHzQnm4H3H0TV5w5YERyW0tWJorSrCSiKLWJRFFEw7dvSLUIGhFv5ZuHBr1ypCYpRCUn3ashy6jbM+2oSo1OF7Pakyms7lfqhPQrACXCs95VvgJvOC53co62/PD+dUxASNNs+Uqr25R3MvphjwQpUlomS+dq30N7dhgQwVmKCip8DOQDnTX1xHzO1wCdyLE+XdUaCpZ8YY++wjatCBxNDaPVf2dUHQ+lOrMDrGU8S91WrEFOqTmg1zzLdYaSDyzx3UEZYmP8OvZHUcvfHcAR6urTxlQZckO9BmtuptG/cyjpwL3Umzdj4Yda3fecRPihe/qKkas1l9ysA8TKMY5hEMqEQfjWVt2FYqLLgPVji3vjULkha6TlHd6UyDv8Mid8hNKat5Q6UVJjlkoV+87UMgwOVKYOZ/y7zHGEwei6SnJ/iR2q2JtpqXPYcY7Sef4YVePsChLip02sqoNtC1DAS/zTUq3h8JqbbqwM+8qprjJczAJbSOuSx1/HGsp9tJ8Lph5dKAuluag57V/12suufCn3q8NWMHNF6h/fsPy0ke5x75YjdiUb84D0n8nJegHriixEUQcaj0oiqnV2D/wNKIz7mVZmAylyxo20L6MWRdKFaCbTve4qR2SzQjx6Wmev5JKXdVpJ+U3h5laQK1ntMlApWok7rHfaRa857fV/xV/Cw+P4S4NZyjaCfL9yaKrjN6so/j5l10PDrbXNzT/IlYrOQi1YPHXzM17Pv08vh+ZC6yG+zauBR7KWQl49VBI78/Ob7682TE8X2+HTq50u9tlaohG6jo+qU1B9u1GmA8d+zT/j/4t1Y5+/az92fRIK+HOKhsKIJEGQViSIpTyoONyG/h1qK7OBcfzxb/rR/vR4N7a+cNFDnz/oxh4750hYzvn5wp+vLs/d2cx6027dMyE78CmmSoFJq14GpfPWYKlw3bF27ANYHGwfJA72f5t9WdZrRZMkBNDjcBQPm5t8ZM7Po7rLZZ4IoMGvnU9Gsu1xKsg1GTPZMnEixe7ea8ZSse6WXlPsB2i/4iWLUcjmz2zHRhYkbGSveUuKjezeMTYyvX50+fmgtSxuYSQDOER8acRK9rKL777nlZdZHYTcWtvavE+rAO0fVGbGukugcORudGa1vGzaR2r9t5Zn6y5yVJbeHIyULEahjNCS/SLLSEH47xc01J+q71ggYOXOpPyAiCcVNI8MLPZRk+kpyfXnnb0PhzcHjtW7kw3lc5In587tuBLGjJl8nKydFfYv2p/a+I60HaQ2vvlf53psq5e/4iZu1m4UrTElGSRQlROKrcu+bwkYXjK1Rx7s0hzgJuB04C2iTTU8IB5yOZ2optELF8F76ExRQ84BnTMpiYP1nv/D/Seu/TeBvjV0vYF6jANMqUaNXgdtvn/jzwJwey2a6gnclgHdV2Ogu8+wfqnEJMTVLGEgHEO5kkRnPbXqGLLubMR8LUTnO4FgUi9O+q2xmTr1X8bQs0fya6evPb2mXubZiottRZZ/cs90bKOaw22seN8QFd0rsxQICzZGnB1FI4NsxB40GKBbKBhrFw8H6FH68beMMocHyXwYsPIB3W/ZKZqEbr0Ioku6yOiqkQI8IjxhUCoUzIenfvHN9264TaQux89+jf8CzskdtB+1IWEKHgYMbhctfsaVc6QPQH1TUlHF841oNHup1iYIOu3VbgI7Zk9rPcGrUrIDJCt1SSU/7noPwK/4vm4EmFxnvc8I4Hofdukl5R5MlMD8AC9xTPJntPVA5o0Wck4ycq5kKr+D+RwgASYRpWeJxZmiPa+UQOiTh3cAs8SB7ILXGD0FT13KUtHAl4lGnCPOS1G3A9+AFhn+9hsGImuWVnjw7DWZuoOuBhbNPOmFkTqYIKh4nrKes5omTie3JrrKXN6jJnqgEbkmDpuYlwz6QJu/hZESjkOWxHXAAo/iktck9IJk9DsfHroqYHH5vJr3c9hL9hUGhvwG/3lBzpwA4v8NmT8mR2YP6GQWzzbOHDeiIFTN1oj2OyQbHUcdHT+0iFeE6zIYVPckvxqHNpopriQtED9gKyGePNClpBEjzsGGh1ziOB/hygViYe/N0vCP5kbY4ZerwqCBPmhrEy0q2ftkNmllJ/DlKndPxUdTz+dVlDmSIYMdWFNMwuwS4Xcu63zWlLM4JriHHK/S/11AqbAMJNiqUTW4T+RNFXuFuKgjYWMyPqIEvF4T+0rFVB9OnN05LAAqsBlmgXlk+f1/U10DDCloYoLtBJFPBqk4jgAcBHS/DMTCi0YWSgkge/clXuJul6BGFrQW1tcPGSWrGsh5SEDwpA1Xa1xZaXfRfEM9gPYdoiCmLAhvcknOQUPAzsGWlto+5tQ008llKVXJZdGMMfJzGkYlJbxdVgPMmijms/ITidxagDyDZRF7OXlyTjcMjatLWhaeJomglsf7i2BwhVQ2dC1ufrARgMnVsugR0cvhefkSDuwKKBhpp/sqiFiRakMIghOZkpT4JEI23I6Y2AUaEzBbROTwDChHm7sGj8Vul0B0QD0ndV1bliqRNpwsbe1l4/x+qLqYJTFpXd247EwhFx4OrUqOnhY9HaneLAvf5qqtBn5TgZcdryOZ9Y1DRlVmQipOKHSOnuae65TxHFwXZBS8VggKFSPN/y0Kr8BFWHLokpDFkq3WsWLKvUsotYjDR+Jky5LQpcyySTs8BR+c67/DK9JFdyJbCBAW7AJXuvj05XW920arxKt3LP6xqSb1xjOOMiqvTwsXoTQ+BsjLG6N2ftTxi/JnPMGNE0k7GCldjaEV2S0vtHt4FmzugzyRD4bswIkKOO0ygtLi8EBpemM/1E5Cm3u52ag4jUMr7mucTrOUox0GOiOKa3ldoTazNFMT9EoJCj0cOkYo0j7M68cuOvb92V602lgUDXMg2YX0jut/kDNxQ0sW0Hb8sT34m4qVYrToi8VUVOH/RyRAYkETJF3Te50y/xtQ9vQkTAKjqhBJvD1t5wBh4t7G8X87FR6FCowrYCtjIMgFWF1AaCNMk0D/DWjjd56yO6PhU4Zrv/l8THb32dhcT8r8HGRVD2KwfRqBijmifGbvtjsNewJE3Z6I/YDm5C7el6H6LqDJN4OdfbVjTM9Mb6Vm//4oNbtDxM7tTsfYlpzd3afdxRt3p9cbs2j/7WBpF+xGvUJAwj052uk1k3C0H8Oc/9UH8g1hAlp3d3/+84LE6q+Y2OrrJzbevDPL+8kBYrZ4IY9wv7YH4/vfPnn30/vUsdNLO1SfFTZgn43MjxJv4kaXlO8S3SC6lGh1rc0EhdgAHE9+ICsk06yFsLAX4MRvZbe8ltP8isn9jt/1bJcDPN2ayebChZt+8k4MvmiCp+S5nyxO22HetDqBevVz3/7Y6Rlu7UCm5h6wLxbM9wc1Jyfk5MCxCyBh5wGFc2wwpWG9FQRPsx4ttnMAd3xQ0AoDa6NZxv8qmPfcUWt3I2u/gePN/VOPCpmZs38kXAG+vCuAqvka7NmM8AqEqGCEaye4oe5PtLXTbad4gNcpKdlgzY1qkpcQSb8QoS7WNlBIbETSQSuxdNDKiHhN4A9WP4hTqOdT0hrJ1ySk/axG6UWcUx1WfER/Mcf+MMiUiPh9dbi2R5xDHluPpI44Emvq9OCX+1/ct5CqCeij6Zt/7tiUvkPBx0bjXj1k9IrcJf18Ts4LlKGCAEzG313kLdS5h5amsR3Cg+pSR+XcP/EKPvoPATXwdCv+Gjr/83kndwj1BMj6sAmHXUigIUSkmVibdn5nVq+aL7R0W1Jtswh8sBHkP4gOLuYJ+CmYK/KSUVTLkA5GCS8ooPLLMnUxDNFlVOpS15YFVjLZspaTDVnLBi1JgR6eZOZc9YEilIygO0AvOJxFaurpoH3AN4gosaz2zSB9NtCu4W7PW/AG0fiFKqqhvGTKyK0jMR/6QapsG8iuAaKIfrmf50mlTQkCTY3qMcAJTNF6PbJ2Q4YcL77zxprj0GPAhQRtgSVezeUpycaWmuTl8Af8+jkoDdzEIj/25ZchzXgaBeoxDIPfkvlk5psHS9jQfl2PmYwqUfke1zHJgJJ2TBJfEA+2kB+LkiWSAgmuZwt9J5q3KHgjmas4HWfIHsDIDnZxvJ4v1StZt+lAyJtJgAGKqas/rTV0XPqUKuum4fT/5B3Jsv6PjS3rP+Nnxpf1XxQv63MvqNVzlsRUCMTQGMgQDG4ZBKcXRwQ8Ug08eOzSQufBBPzsm+izD4LRVLPA37v16qlFwejnOJ6wIYDhdDx1qjulQosNWwBMBkth+9iO1pvuaZYL9aeP7m+X/xW3lyBbQ+oFq1F8216+oH8DtrmzzU6DAPW8ItC6M8NyMh/8eOyDD8v8AjLQPzmQD3IXVE90H86XqH8e0Nu4p+8sGvr0qNl859O3NJmfHIuG3nZ3qkf9gtgRH7O3l70gEvrcp1f1HzMqDNqwPc9uHEAY9M9PJV5U2NWLjqdFgw+f/QZon0gP4+EgYvng5Lqe+/YtcV/8wZMAvR82AvT++FZmr7xe41oHq25u2QeNMKQYY6h3dxTqvTmAett7qmX89f4KmitH86JrxvKiHxvjCt9bNeMvhKvhBoczP4Ir7BM7qGas43wPaBrIARKSBuH8u8NOChoVbg8JjeuVk7c89OaTA0aHeqPYIjaHZ3FNJx94+oDM4dMH84wH7k9So5iW1KjNLc3VhpIa3OJl11+2MJWS1Li+tsJ3ylirwunnuPkSpOdFLbQPPTlmfOClcTd57Y5u8hKO10+Ousn83rTyrydxDVHPptU1nERdYxmbz1dDe/OyiGGejSOFWEhjAtsjlVlGWzdKJNz9SXPAMTb2F0GeYk95jDsTeu56o1nP/9g2dq725nvVgZ3Vpv1xJoCrL60tfX2/kh2n25+ctPIlaaSPosNsgKjM/X/MnQmAI3WV//OrSl2pVCWVyn2n00n39DF9d88Mc8AwwwwMyDUKyCEgIHItIoK4nhwqiijiff0Rd8UVbzzxWhFdFVHAdVE5VBDdVTzA++jM//v7VVVSuZPudCM7skxPd7on7/1+9d73vfd5WPyIEKjjuTckMpkvoW+Rq/y63yUeXObRhhUdz2+fElvLGzaA77gJGZQJqsiVFE/RhE51Rpv7tXqnnDdD2q9ymN3O7WwcIiWbLAujcDs8Eb21D+vSEKHtOYYm7j7BVzZOqr5scutwQC1sm5vdNqSqQ9vINbYhw3Fd6NGKXENeu79qkWAhdWH9ibzViKg8bfIIoCEcu59hH3oOZxDtTXmeC73x36h9FpfEalX4IOfE4I20zACrRasgR2qHOfvoMgMiu2X14HojWnVIvigJPa0ha+I4XhwOwU0B7giFAQK4H8GlUdiIkPhDgeECRHN/JKHlp467aPv2C4+dOoZerZpzYPlkaczkyOjmrZHQMDWq7DLqdwL5BHIIM5Xzf4wsd1tA9sr87MG5/NapTGZqaz538Gz+8GgRRuGDBnjzZNjI80I0I2cEooSCgZDKp8ZKG5M+X3Ij+QYCCdRLdF1Alw0FwsOySbyRt1UtiwmWVJjBvz7+fHv72Dl128fOqzfklVpAAYwBS/YwuSnqqJRkD/yW+x2YA/sw/eGhJXsjbCN5KF8cVTBH0KXJn1HFJdUiZ3Zq5mrlTHqMrCmiqJM90vgbpdAq4JqqvoZV9Z+3DI1/0WRytjonIlr6BNay0hXaJpUcqFJC/xeb5X5pdeLmUehWuD208ONVcjpd7MfThBpOrWHQRlCxAhlG20PfRpSNATYQlcpbREXwIztHEi0CfhSUbkQxTInK4SD0BZbp07wdsBxR0yWfeLtkSCE9aOXzsillIufoIAPhrcfiQrOkxrQZdExq3PfwKssfRVUumkLnKtpC/vR7HbNyIRHlOYwOZHQFRJEy4ne6x8MP7QF7HPAL5X0lqj3yCwXFW9DmIXxI+vL7aEUuJAUEWaFbfL34O6FZIaAquqJL5FHRUKQQGJSCzFkLnTGhFJRAePIBcUGh3LJQrrxBN7x0lyEbEfg29zive3Z7XkRBWw3M6c7A6TDqXZFm5LR1ftn2DlIu0nWstP7vOrn0XLpuX0LzMjfQEiQL1vIHRWykCrTkflXHoD6kI4B6NFIHoP6KNrJhRPOlkyESKZSDrxueDrLmDvvICuOz44LrFn4HebBOR+ZrMjKWe2nBAGE6Mjm2hqQ+NBc9uw4Tfm7DDgExMg4OPTm3Hkn9B9rBiobBKBoW0LhRyIS5L7RKxnAzVy5PxF4fi9TKQsk0pWBaGMxyVBdw72bBCPk9pp5NmPNySrZohRS3djlQYiv9+DxSFZiQfiJ9YlYpaUXBmcuw7t9y4/XbaMSuEHHyM7Ai9ETB68OllIASLoyg6BJMmlpI8aYTobgm7Khc/P4MBsg3lREXT85FhrcG6x6YjYZ6J/lK49PvCgpU0Ia2TjmU3E1oVfSX42TBjxkLjg8khwyO+MFrIOS5gZSJO0CPJv2Vz0dGcTq1c/I8SabzJvHHtaFs1HWbNliDNHFys1j8fheAFotYcAxOLhMVbFAuCAqL6Npsz8mFlCWtuhDN7ZHQtlcF44LeeFSexvuA4hpVKG6SQnHpOphbBlCMZpP7ejRPobgUxhUfG5/K2EzcFIDfyx+oMnFzBolsvfj0lVancVNlD3yH+wne30PRdf8etHa4wwT6Vg6VbV/tJeIjbSi6eEtddw7pCIOsw+NuIx/S5jbPaY1BPUcSpclIL7HfHeR+ytdtU7+qu3g+0AEp6KbnCuRrVpQQQBgfVSmLjgWAw8lW1wwLACuvYLzdqzCYVL1p0rmk1+qnsq8adEu5QZBHNEIE3+vm6V7LbPcY92Pew2z37lXbrhV5pwq/cOA7ZmvbRVuRjVdtOrRQO9XFikp5PNxwDLK9C8jz9arJ0oV0zWR5xbGYbvOO+zfZ8uN1TJ5wSGSms5A8cYbkIS+iBstaBuPI6VWDCWFqr5e67fVWZi9KlVNhr2vo4PfqmXLmbHVee5xkOMrtwTzwktNS5ZSjpKLD6NlG5++dYHKO1IF1h5zUG2bGr5aY5BpTbnMzJvmDlSPbM+Vud9q3p94eNY28beJH0X75rDNDTEAD8Qg+IkwkMsXrU7FwCQ95WgfAolE0J4URo3DHu7C6RlHNlICeAjlL9ie1/jHKUOJtjjJ3N8+BIQmalVhKLfoVWWNXBOpIclk1U2x/Am1lhMNsKKdRy6SAXClgTaXdWIPoXgDvS0G5xIf3tWIs00jiUe4REFgP9TwfWMEvrvbICr1fpCMLg6Prrv5KfkWPN62XLD8xGA7vd/s9/i/uDOX9gvtsX7785KrhvPQuf7jqGveus2v0sKW4QRveSjffd+X4rqerVN5ct8d4ammqbo/x3v17ZsgZ/YF/19ZrKv/abqXx613i8DGBTDxAqlDgYSjEwzYUGDuXz3CgwJQu+2Pu/+BBh7BNHm93exBZcw/qRpn7tOMIYZYa9O0Gl1XdIN/txvhld+wcNaxAGegusw4XYq30u7JhCOQ1dWbd33HRwQsrb+hMn2NK3o9pY4TnYOisH/TcQetvdZiWadFuY+8V1ULWztQ8kwEpnj1NWuFgIu+pR7agqZPvi9qyc5Wu0fGGKMeMYLpyJ+PC3Mu4MO9jXJgsVChUXCnJBT2/JIxZvZDFcoligsliuSSzCZvlMqlhxBwSyOP0Pmh2m9va3AZX17nN8Y1u83lsVQsPXYwtKgoG4CFvxDkWR6KzAMHiBEYXK1AJZzzHUxyXm/GNbRbdGN9VCbFhqJbKi1AjSmusFh5ikb/NNuRvrUr+/ggvSHTW1lA4OoRr6kbcGsLlKzeuiWpYxwX/My/4wzYW/FvNWPCJ/0LzU5ULfoKbCy4ced2eyj+S0+cNUjckGNjN8nEM7D4bBqfjWDajhwXuZXtkwtLfbcWigE5ELAy10IQlJx1gcnKsDj3ptDNW4ZPkSJKcyMRmIhiHpAIFYmtZW0yT95H0UI7pEzLIDpW3xJCqEl4CsYbsnykAvQKLJacnT9hI/u7iTL7uzpftKcpclTT55lfi9agYkc1EyKe5aCbnD/vR7A0pIhT0ors+GIkIJ/vSIlSLgIBhmog8RF3/Gk6uASXpcl3Gk2RsgHu4J7gnkem+pSsya6N1PuhBCVtCj40BYJcl7cErMH4Ki3WXtvDMae3haNbZacOzJNr9EnW10lME1xQpOYePn2lPghwuJyaOC/vzmRia1+gtgtHSVCrKk89GJsP0OKCNczQqeCvvEUzWT+RNqv7yznP2HZHYYIQlgbZyyhvmlqKUBrl1U3nDpNVHb6CPnq0PIK+v/ETPxGnFQ2HL+q7sgC/D7+GFCBT8/jNIMJbyUWFIlvJW2yYl8YRiJi+xrb2JRDhM4w+j7Cc3pcvZxfGMWFMtEqmYl6pfIbpeS4KRmG0eXHfbrA7UOTI8kpg8frXmGUXpBebZtnUp6yJ0POmCdQYU3oF1ThByTlsL7XFb6IrWFkrmUg0WCm4Ak+yXNZnifHeHtB6osTrvtc3zn+tmHvu6qjIarJ5qPGMKNNfAN2dpJuXcbBHmtvAO8sHqkh3D46jgtAd0xM2NHWWu0obji5ttAufyx+krSPFkmCffdPVaawap3IJ9yFigR3sWvVBAIirhcxvnp0sSXx4v8+i9VnVAsvF6QixXDJ1cuUdG9UsIKp34c5tWdCqxn5pU/oY95HRIT6i1XiOglZAjg4xFvxLPMX/S6r6mD0qhpDM/+A64gyp6vt7Wgx9YBYv5xQYDsrY+BH+WBWMlp9BcdzZ7RLfUi1kdqbobz5jEMiNuYiO5NzwcDoYIZxrhIS1ITjnk5QejYY8tBNHTOjlPG8rFeEzm5gPKxOKmiAXTTbZjtGy/4OZLKtkqcMDEIjTyy7kJS6qaBoqzHWkVmzkDqVLk2VNjsEHGMBLIGnkqEoVMhmHHcIgeTgeR5gMeQiqXunkCe9Uiha+MUEEqGkOIBBMczWACZTYh/hAz08W4TW/vjofcyBWdE2uFelx0hUd2YAJR+2u3NJKITGwYUvz5bIzWjRmJqv97d2aRntltBy0t3z4Yeeg9bU/pdueUQnT0X0A0AE0wCM51OaX6EKVFMtLrxgbS69TMlCMKvaieyZqrE4V0CwRh39z/5vnKut3dfP/7mkYa1aKZmqS0bhf4PmX7/me5egDd4s5rm8SdUq0hb/qw43ZPWeJRSFubG3uvS9HZl5mqLXlKQM9J1vQcZ8nTSS41yFaJbDTIfbZHXLmOwVZHeacrs3cANl7YEusD5Ns+Et7stuD5rS0YTcQaT3MON/gDY0s5v5zZNDW1lFGUzBKwvjiuMsC+yF2JGMID1gB1LoWb+xy2lKselmlvcZmjYE1ag6F7ADrX/iOWprNol3J4S9XhaH4vREXJ6SiIRJ0SDi1rW8VwG9e5wIKwRUa/Ii9zUTR/SCmaEYFCNDMGF02lREambWoMmN86724MsEQ8bMHygy1ATaWqWi6f9VkdsD8jchR1GbStHYKVrFoUs5MoOAOwHUcfkPcQIkcwKAkGCLkJKK0qV1PNBqPAajIaTnHDiErkuFaEpnJPmxaBe+lPipo7pAAdWTSe+/LIeEnck9qs++JDJf0nP4/Noi0pOBPlNvGSoONBIwhBNTe8IXr7T/XSEDrTAv7RjZNB1qXzIJ8EyPNUdD//Lw7TlipiY6TKQaGmmcPol6OjVStotozGGghYL1zVYnUqHDoJEJf1CfaUqgwLTOo27qvHmEXf++qvAM4z7ZMpzvMxhvMEqGNYw4hAqJhLSmwfHd/UBB3F4ASs/u1W+hwOyEx7FuhhwaFgaxZoeXuGyh4RITkWCoTotglX95Ea8fEdG5BSursBibxH1gpocwl4KQbUb4YDmoLpfT+V5ZIRnXsOhhGxScVvuRD1oDgVc5/GRDy/LeJhnqLyETkBgHMVHHpQDRz6nMRC1AGHvrIKDl2k4NClJXqXSH6Q+kxITO6mJY0cW9e1dHB915JXPhFfelpdzxK7PX6JOCaA+g/Yoks2gHd+ydLlWMRM0TEM9mnHzu6LnLWtgAAE5YouIdpBZp2LHCIwQN6tAL72nYQtdBHWOENHEPkGwgJlgNMxsMhFNTgvWln46HQ4mLLnqsBMEJNJlMTV8LBpxeah4YjX+14tJQXpnY6uuwhAkp+aLIRBjAygHLS1yKKe97kupTNql9II934kLYoCD4lndDdJmAVIH6DfUx6bLLHXloSYYSZJdnxuEn/JiTCVHIGZTRvBmJd2vIhG4F+UILv/dSUeN0MSS4q8wxOjFPEbSyZrVxEl/M7Oz2IDdTZtd9tAH65xGqobqNnt8RuADH2e53hexzDAqIfV2YpbiaGAoQlHlmqI4AZ2GmmrethhOTo06gXfKh6xxlFceJSA7lE1IFezX67efp9qsN9/Vu0nz4KMR45qhgTTa4U7w6WG/KlhdQl+wzaXLNeRgAnthUfrqJrQdDCHvOSdAXTnOKZNZBJ8K8NK0FkV27BRy7CK6ZPoAx144ETYuhjAB46i+5arfK2mlJzkUkpkPFXQC7XJTf898pW78Sewto7GLHpdJLCck4Hbf4TWXR9AezfTeZlVLT6xHKabt2AJNkU+RSh2ls7aVWUSvIbjK/UPLcdXSg1UaGjGza7AfWZ1i1FIeMJscqNIvRt9GkmxRPfBSYpfeCSWCWLAFkXV4bC6a5ScX3sy1fmQt6N/9LMt5To8EuBJUepJ0US02ZNw9rlAVhZooQDNwdEQdSQSwmVNZC2vhZUASvQy9SOT+tEDbkcpb0IK3sJVHFT0H7En+Uo7TqdBOoXmFy392JH0eZekr1vNoRvpbcyEMmRYYZF+8SzGySn6bbYnJDQYx0AtWUjo90KbEgL66ORU+P2TR00GsiCPhqx+RBaIv4Nky0NM8PeGFSUdzo0eunPvpBzGC7M3GAS1lDJ8yPDCMxaml3/TCwxao88IiwX9AyFM31CEyl4lpBePGtnl9CVyVmMiqgE0B/daLTcctgNmTSloYMIGL1K5tRXzOb0jVmM+J23mM6sQ8AWkRifRjuslB3NzEB1sXeoAfLbPkkSHJujpxBngndhqodq/OA55ZFWZFD2aV9N+NqQK6Ge7DwZoD33Oh6cis6cD/3uTLfurPkf1R9+bkVSjlV+sLqXybd2zM2jsPGLnKbT7sBTTwb4S9jrEZ7OO+JxX2STGEQJcexcKdwK9RyJJ3ioIhNBaSg//Bf1nxjVUN8x2uOfFuFTBFlv12yysnPbd5pn6uQG92eTHK+Z+P9zmOUq+sZL3/ZYVoL5bPTWtTWCAdnNQJG5fV2j3Rrsa2lBdEK15Qvrl+HzWyrjFCWVdXoLaqiVxI0deL4L3JZSWNpsg99Ur2JUfB7IBSNgqx2OW5Uve7FDGC9B8hJ/K+zTK6RiO+LYcenAgODk1HijsLMRTgI52fwDqqWAXmDe+Ww3mvTsxGwX4tqpl045HLx+1WiFRolX9SdOUrGifCt+SpU/+nJ3dLdg+8jZrLmKpp8uWcqnsubTVn3fXkASjoW4nR2/Ye+bmHu7XxVMOLTs60vktzviHG874f7jOeHH7mXVnfPOhO3DGD99JXt+oR51bmsmgt3V7x9t1O1FTs6NT8wlRTMyjAWwFh7ryXr8ugeano+0ZBvRSC0VB5eMZbf2F9LHYN22drCznpF86Yge3sd6A7eTPfRDZD69LO7ukLd+kaQsLOH2HHbcvaCc+0Z6g7n1B28mnMLg1jPmW1lnoploWGjFYjGklOJVeWO/stD2Aiq7g2QWB8QYKM1+1aYjL3C39oUfY/s7Vm4P7RM3EDcZfPqW1qTL5CACCtqlGdpHfrOzdLzs2xC4n7oxmG9/ezjxvcczzHpjHyx6EST7k2QlM6n947mIG4lZlne3EYm5XJ+bZ6l3dEoNrk/J8dZbaumCL1Dg208UuotNLdqjuUhZcSaBBV1PXWR8tYltWJAz4Dj16r2NS8kyzCPX1zFAmMxTXMmiBpDP138Rknh7xhSfGRwKuaXqzWCyGjfFnhcdh3lSoHMYkXijol2P+HDqI6G6ZcTB0JEw98fAGJInMHTh0ZkrlkK5QzYBaHLxbI8FSRmjjfegGjjN8RRO9qneHFkbnkRw39DSdt79IUrGqStZSCYyzOpP2UV8AFTBdi/2Eg1tE/Bm/hbdMlREpSAZdJ2aX9ihRGo9g6kH8SzETrzvkY7IRa3FqXWWT0crfklPW2gakjt/3HAUCfC11hNOM2APbfaeOizRvbL/H4R0qdt8F9JGJjeFj3nesTjNEuhuK5YhJ+iB8A8kOD9H3DjmirKTN3MjBO3ZNyqYZ4BjHRJTkpHzse46eXn7CtduhWNvtcD3d7XAVGr3QrhBixy2khzbOTptncMlC0coHne4wqT4fnA1J6WwSBV2+8vqOqx5+hOfok4w/+87B5BFWPpgmrdLBKkd1boQhvGYXY6xW05qkjr769w8qh/hM25zwE7X8MpzY+7QjMzuu3yUYI4VIC146dhysLHV4JIkkMFPI1jJASlsn1sQsTSQ/z+IcKZFqIKIHOSfds8z0L7SAOYjwr3v+RlpbxjIMK5fSazg2MBP9vZfE7ZgWltGYYXg9b8yfvwXWW5mJKu/qlLORUaIkU/GqcaIRjdqGMEiGfZQes230TtqcPgAb8R3awdi8bc/tYOb6nrZL1qAnLL9mZ7Py7ebGMMpu1Oh+ttZ9YeSKLsf1R5QgCcH7tf0u5WreLDO4lD1Wt2amvlZS7rRmpg9te5DpekEOq4kHF+bGTxsSgBBER0IQK2fugMljzqHvQ9JeQbJ+G/sNmvIDCYMunEEBFOeejkiyyPVRdt5L7E6+vVcc3ADuBam302z20HR2Yl0n2N3NXDiiZQ8d0K1wXA8n+OlO19lUfdfZH6pdZ6Gum8AfWcklMNr+QFfu6LwF3MtWD1FXWPC8zPN+yjQX+m8GI+vmF6RT29nhfbWDVY5dR98g32nTfDbWZ5sYeWLQHvLGto1nTnj9QgCWBxETxOz0lnRJb+mvdY6xP2wlrqUdRX+XtLV86Igx/siaPdB/aKWjyYm0L2Ynoy+0k9FsJuFORjOTaS32tQ7Pcnq2f4hU6UlwbE7F6b6xmWMzkJzJbmBDT+hQGVun3BaaI419g1sbu/nOG1QI/qBRzkfQUuSTY4mEjxPzO//1y6+tWgTPsx81yrTn1Br8soqSXSLvrFrshNYWC5jBJottZfuhsP9MqhoAwaFSudfVLohtd7RdcObAt0ADELHi6KpaZCWxmc2RYitYTd3kF23Fd1A1mMy0Uc1YGs8wEYuzdBX83KzgICCchVHN84A0xyW/V3WqAAyjPTsZH4pt7wiuka0I+EUOtwbjYRLd2KhwBiRcn1rE02SG0FEE6o1qLB1kqp7MVL2MpeqRa6gYYBpBzhJfEoaaT0Po+SiXHGrQA1CbxDel4Brht9xBEwKvmpKFcCDP9cf82FADZLhkCXiEO8+fTscxIWgakY0x4aib9y4rIdxfRczX/zd6/bajX+c6OhvNzbacl21uy6xNy7bipLC52UZKSmna7tmzTTgPTpHdkcdgKTggH2k79Tp8aF0XZtE984rxBDry+ocaFyXv5qLAsygXZZqQvRRkTukngp+3l5ihcQ5XRc5Hg/+7WL6O8MOeZKVdl3Su/TNNXZfDRcpC+VktoXyhWlIjw1USSpKRUP6mY+xBVr3YuzdcLhlYDbYU0cCoDBhY74yJ/LLXpl/cDROUwC98reejPYeZqwMhTNcG1fGZi/MNdugFOby/LrS8ozm0xP6zo1YNuzEcYI0quiyWMbLUYst/csLJ4fpw8oA7nOxCG/6/fnEG/7DMKmvMquNPH6u36fJtnakWFvHmVzD5oZ5/HQChqD927Hammy91sf/qCRWvKm13EWO3dCXGimYkouhh9Ued7N0/eqJycJ+IWEGRmJx7Wb2RzxtrcXAfxi4+HoHDCZ4r0O3YHDis6RFtYoweNXPC5bt3X3bC7OwJl+3effkJM89a9eELdTLGxYWFXcXizrlcbm5nsbhrofDCBsIDuXbQJ+sbDcwISmF+EPuECBPlPoOyAAT8MJ7d0C+tFnQ7eqBvPN0Ma9fgafxgvfMsmqshI4bwjgvWLsXaZkkaJ5Qx0l+UkM0hVLK2rhWnR5rbgiNWV7BI940h+kCNYalklbWk6TSXsaYDswhalkxyPZ4vGdmPCpIaxd4NfSgZXkychsWcCB/82XxGdUINwDmTaWzI00m2VMBTX4B7YpWh6ieb0DSOQhO+XqIlQaysDG4MOtwUCuPzhy0YX21rG7F6EsNEESpjycAQi8iAE+B5YHu9cXzdv1wxtu+IfWOzdPZdUKMQzAzL8jwNR1jd6Va0qxUx8IBG8WBALcoSu/BuZUGLCrIDVrtRSh/PrkE+sSNpNQ+nFHSqJxu7h3EsSyGAa7F9cRcoAfjxbkXkFFWoe30R6qDoZzNxe8lpOHTzB37Nnwba7+FgTn7A82WrEGRJaWWR1W0cNkDtbG2nC+DQ9I9EKVpdcsnO2DzidtFZVdNpSRzFgzauiBPrBg3aotppCLuFX1ikUZFIo38ww6Jc3PDRKDzl07B7cC45c/qsOelXmBDu9YqxQGI2ATXNCAGNEQTGcDYZLNAwZ8g4nVk3OZ4KpF/Xcoucw++zSx7ciYztTOfSbbJzjQ7cyO7/qDcucZGYyXHqiJ/T0aNPyA+klKElseqF+RQSDDkE3leGvJ03KMsLzAir+Z097eiPb+g0OOK9gUx5OCfRryD/S1fNIWatXzUXjpisQIKJlZEIWjN+anGgsYbT2W5k04NbwtlZhKzG1YuY0PdqjfnGY/zJ7C54HpLxTw/QN0jvO8ccr5h3j5/U46GLa+cSlYfbLyXbUw2PC2ycJGgENOoSbJgkU13mgAWAYVSxmUN8Yo0coiJ3WVz2q5NtgBybFDmiflLkLK7mCGK00Q8E+MGj7I6gwu1Nnjs9D/S8yWNgd0lfN0QvwTbfymWe28OYL/m3AbjVQ73fId/sOlacbHaq7kH6kwPwOqmvC6byuo5hPHl5s+ONHXiYfzocj0aEr8ZS4NtaQJFX42IS+81SX87VFCaSVp709CaA8udW7jbMZR7u2WWua+SQVbY0e0hTbPnqFTrE25gr8P25ws31cSd5YaPtec8kKvghgKl2o+nzJghXduRJo84GyrIdeNqU5VrgOU74sIRte/TDMCOAVDaLin0tnWlN25/uLI5ir2Svi5irzbg6ESfiRfyBfSXRkBNlCnK7HWv6FEn129FmbCbaEGv+nMQzKSfUxA5tXLNYlidgJZROzqQG1CHuRTHIdxDtnhWiqj8uG+jvMdSEHJMOIj7AwwOq37v8GLBgIk0zWHSCMBOSGOgw5GonsOSlalT5kZZRZeWweBCfRb6L/rLKBnx6bAaDkV5wJMYij//Yq4jRObQQASA1G+WWQDWHTsrJ0Z0TH/yWPjwEnDPmWicmIYchokzPzsymP8siStG7l2z2hX0IG/IHHsF8Mg/s3LUo5n6Jhg2868zpVTW+dm5Rdi26cgn30XUNprKWpBVNppqtGzfqog5UfiH3R9jLLJHDNE31a84Z3EldfGcgrbkOMT5B0+LDQ8OJpoPMHVYbOKV5Xp8Tp6alufk3bG0XepyH0GP5DjGEk0kkHO4E97h1Mq1D6b1Iy/vp67rOtN0kZp/q97lOdeWw6lSpPjU3E9DIVXVzpZd0nytdfqml2r2NxiB4HwKIQYR0zolBuGn609+osXYrdrYf4v6Ecv8ez/VsOcVGvkpbR/PG0hyS8xG6DbMtcr2MuSOwBGmDGiIQ3k5St9gUYfsKQI5aFjvmqOHqVcG1zim5S6RkOgkqe8SiskPaLBaslQKt0OwiywXJA3ibdTlRjmHMFH3SyEOXEqcBmtM6C50gqUJW8FaT0A8PNSaRebzqvGVBLZpjvHbr1k8Uk8mJhO6Gtn+0Cm3P1sZIY5EF9E+Sg6uJqICVGb6IYiWivaSi7RNIqr39nBFlKR38k6tMEiLWb3oCvJf6gIQLLTMEbqXP5DPYI/nKXpHvD1XZkTQb6MAPr4y1SBBub/Nk/kyXJ/On2ZP5PoaEv9SNhLd3kteQ8P+oA4w/owEw/nE3d/SivP2ovo49qt+vMRd4hI2rDtIFzIFz4tfEBb5ZzQGX/9wSHf/rp9D0lbfV6imvBUbBzZbPoNRGu/Ru6Gj6V9ex5R3Tv9brrZn+Ae4AY82/yvNZz7cHY/pVA+v7JM6Ho5aAMEjHuK+KsJ9aMcKeK7KgoQcSvbB8i+09Nd+5s43vfLiL73zI8p3n9gW3J0fWAPUv7wiovzROv+dH2Xd+l+YR4UL3c7+FC23ynAed6XOexzHm4Fla2QriEtqoRSoyw/PoxB9rpibYp12mwDJq7DmrR8DyOVgeYFu+b5ethbNShP1G6NPhskRsqVnd80FnR/FLGnYUv/D6xh3F1zo7im+BHYzYWDQR1s0EWxlG/1GFcDRKO9hP9GFFMNbRc/znBd/eN7jderSbW2tmyKRBcDQOxz5KC2PDciBNM7ne3BI//PIHm6+1U/vaYPxC39L2JTVcsGobAfD5IrlsPpIYwwAN3hpzOD+J+gmG6EFM1i4vqjL4FedK8d6TWSdyHiqgYvJOS88ne3tcuJBdmJufs+/F57FH4mute/EhBFX0kfhadDreO5B7kei8G+6zSB+QsSrdh31BA98HX1Cu/o481c/KyvfVWCprRMC/qXJ8AnHTkIYLRi4UHM+x38THYy6Uj6kpYZV9WVBMjUVAAVHCLhT3U/BMPT2QCmGqKQ2qtoPwIXok4du0lFxMxmY49pvi4cNVjM/BWZMz/XEjkDFBnVDCm5P092ny2dUEXQI87D4Kk7HXpX7Jc99gfAzLud27Hu1VY/gcCxFGl1zRzjhbfFvZc7bBr+h4IS3h0pZKB/S2Wld7zZTo2g/5E04OaMEMYE08967AcDEpeP2xXMAMsxWRFx03zV3Y/5PW7VN3s02Q26az2eltbBPkap++L9qYqi6S9GOSENpfIO4P+L08FMCoJhCtGC9NxHHnTWAhUF+PXrjRlcyN3qVVLtT8qHdqNNvDADfb7vAHPgLthq6geyvVW1eku4EYI0VYNr7UhSAfcfHmF0YIbSBrSZOnD3iKW2grw33ZkeECAQMynBdNcS1kuAcZddyW4bBG05encpuUGFaUsKnhIUDh8aMMHu+vwuMtyDySbpW+azFRM2P0KUvHR4PV8VF++f64DGGvXpmjewiuaqHMfaxlkn3F8TceT5PzL9Vw8fc24+JnznSz5R+r3K2Bd2Ox43fWs+PfvOfnyWnuCOIVmFY3O5v+XFWrO4hqdYKt1QmebZ6zPW9Ewf/ORrUu1o9U14PKxtdrdwu0E855Fi0t1LR3gBjw0k57Bm4Pgz6hHAEIuI2t3kWhg2J3MDm4d7nupJ4Et/fhjgAizCdbZb6oMQpSGH0MCcUg3mM1mwtK6CmFmoUrJ2qkKIsISotPgpZqCLI3wJPKpvaa3S09C3bLuzuqbeRsKsajFcjS724hctiXwXOGqm/nMC3Pa9pSHlQgQ8MzByJeQai8jD1zELZ4fSL4cmTD1j1bx7a5pTvqMA/xG5nDXIN9Efd7frYahzFXGdGsky/tIDt69qWlAcU4l/zTONvcoAKem+vc8gU9u+XHG9yyMLt5dqjOLekscxIbLX7lOReMTTyzFuuWUmD2qyjWVlIApz83Yi8csRLLBde6OugMrm13mASIuZZZj0QjMfQ8RxdJ9ePO7ruhctPmu/qXyhDuDgxdurZZLN+DUk91l4Ww6QWbcIDxjsS8VmjAC16vYS2lu9DZZufPG1eQszEPHvUxuTlZGg2co8ah9pcOHg0NVdR9uhaP2g1qESHu143Tw0V0JuCdspbciSZe7yK8Xs5uS7viTbC9UtuHATIzZp7pQgxCLlV8cgiYWxgurT/KuszwlrKL0VlmhxZCuBtdnodFuAg2Xs6a1r3OR03d2mwH38zksv5ft3yNw3dYiB9Ah/+GkQHUjEyn87JqHFiO2s71js6nuSW7Twy3RowWDKzTz80uzLnfepQHorYxHMYtNRm1Zxjk4VhbvDHgxmyAsMcZ7TeFZ3CGLdu1ea+p7dSEzyf7Yn5KHIGBxZmlCa3OvoR9FttVyDRa1IcM8xxwK8im88ZbI5Bn9s/KSb8eIOf3MrdNvoxOB19Bx6LcF6DEYAii3zaITw2UdDSM5EfY+lksJ4TjBAKXCWW14XMEki/lGCQ3p8i4zVglCxfMEI1lGBnZzbN3doTQN+dH3Wa72SDQz2xnuMXz+X82d+C7gar/CRzhqz0QrJ9SL6jcMjafUoTEwpSNIwLqGn8q0dkVPFJFg3kBhe39zXMmmj9+WIfbw1ObbYgYsVaYtWV6FUWKF0cFnSalncB7Zg8e4nJCx7NIX47pejEXpQ836MYTx4xJjPnw7TBf4xGBcr4I9yYabbQ745/uwXvgmoZo4XWZz22erUz07K4YI6Ev5WMvVYX6gabCktjWaDfCBYeTJNke6se9s+ZNqXyyyZuYlwbUhP85Vf+r/KDquue0dt10IcVct+6VmEv9BCA5CcMh7/P8ZEUouS6gPxuwWzeTTtbZuVbGmjviaXvD7f1v5tl1mDly17r62qbuJLqI0YEviAn1mItD923HUdBtgb8q9bhsg8flA2rMf2TN4/7EPqj7o9q+Vh7nJWbMtDzO/UqsH+YBHuAbz2GITm9k/Q6r6lnTbW8zB0TVMgfbPHserVgkFyDC/X61qK1cC6Xtp210tWs662reZ2ohvyWthbuAuD7WDsR1nQPiehO8baMtpT2TSWmX0o418JTgZo8gNX4JnUIi0aFZlgLU5wnU0nx90jFXnyYI0Znpdl9Zn65ws40pBt8evzQGtgRkMT20o5Y9YBG2c05lRbAqH1bWoe4/znW+r6q83evVQgt1uQX9ylObT3Nhumi4TvO/7HShmibdqKbhfbu3k7ezVRl1mQLhgekPmQoyjgecbIGa2s4Vdh+0p+XXqCOG+yuYCFf9ksohbZhO1sTyvTDc3zxjnmNQrqHA7d7C/VJPvJ8VBhYLK7/8L+olBeCS3cBAu68dW8EVvzRRmV/ZFf9gt7TgE52IQuTcvoMIUrl/ZVGE1+YU/M1zLHTyT3h+S/uSB4UeYnL6P59X7V4DRBF3eHDDULwznGp8XX3w1f2Tja72Ya1HO6d8xvo65fd4uipzB8T8mzwPrZaj1Av8iKz75bY62tIx3QlJXHZdPW68jx0Db2mLVyLb+g5oSeWPK41owwe+yW6/jZ6nocf763C0PiArJSac0I82gFUKbCvcejsUOas/Cgs5MVDMmGFfOBLXl7/rgq+Q4dwRR+6T19V5HuoP3HIH54uE4iFZ4jh2V1FoC+aXyfnrd0vxng0H/pv7BXcAzd//Qoe8rWLx7JDduu2uNfc0XUx6RI9Qfa7l2PAboTkRObEl5lSQgWmigxxSu7HhMiil9WPD5c4MkspEUjbDVN2xm7qNcIhNBj//iuNvON5ux7ZrxK5O7NbjG8t3NMNITqqHkdxAYSTcAp5cPO3aXtw1/CV31/YZ0NoLGPPejkfF0Z7vwQSrGdDGv9IEuqkzni3obOQXCS4Gt2GDLfQxYesjTmM+Qp4R5Jki8l/7MJeXFhlxz85prLl8TAuPlIuSzSlmEix9HDmDHvimYfYDW+1+jAPAidwvVjTDbY9wLz+KshM+DQZXC0MFtXhUUactmkDHCJocHomENprIc2OSntTj02HZh8yevbSiRBMp/Rz/mKbwaKZApHS7PqQgjpET6fh0/K3hsXCUpjFsoTx2T2E+H98A9yq9gr7ebtD7kG6D3sMhQU9Plawx77dyaiAoaVO6FBVY4yCqSTI0WNQiseTexwISRm7S0fuQzsU3bBhPmItB4ASQ9MmpbSl1WFF5WQW+PzMpAX6EMhXEW8RmxkywsHOouCUWYVUhnOIxzI3vx2jeLs8llPhOXI2anEVWoCrtAh30hl2svjKnKEbv9GrLZjEyZ+ln0d4HxulNXjcBLBXbz/CRb/gT2g+iG2PRtEX7VfSZ2CPfEEF31qRwAOvFceEO+7HEDdW4u+Y3I1JI6b/4GfojjJjgf29vM+F1A3ix9qN6R1OkVDahDA3nZR+2yhhQpnHoQ/6MhuPPk7Hy+YEJH4I4sM6jgZHn9jToDSB8sjhUP2J3tHseb7t7Ho8Z7zH+WFzBuzwXeN4xGOMNeKJ7dUarPDnIqe1+jVZ5VZdh7J9e5R7GfnH9eNVF7mFs2Kp84H7+RBy03Z7X1KNRnbbobe3648tOezz9gzo1Wuxm7nKjtdmz02XuJdy79jbQunnZ+lPJ3e60MzvButPOHEFSRW6rHIqLK9HY2Iz2BYHcybqbk/5Kifij6faeEPQHZLcj8BJoJy5X+GM2Z4CFUXcI6w7rRncv8gZdsZuRrVb3pnZk5FATONKZuJIv5uAMCTUobabOYCRTgIzxZEPpXMk08VfgyMHwBr18+bHJEclfxEvWDqEy5Du27rQiph7DkP1+NmR/HtArX+55xH4AZ9fs6zrtYbj+Wb3M0Z+2mhP+RI8X7vKPu47Pd5+Vf25/558c2c91vPyRbnSrMcRq1qP2xZ4PD+hRuxLGlbl+T92zSntdsKtd3WFXwVCIwq5+vkbP4X/vF3qFwV8KvSIfbnaFy92ucE7Tk/kh29bXeb44oCfzKpvs1s/qleUBNc/93xq5QeUrA+qF417UV8TmZSSM/YyEcSIUl3e34GCs93OgiYOxvwl5cel63PCXNdIumsgWyppe319tQKhR4Opv2GTGPNDW6EVs2qFusSbqNqhb4Al2EJ3NnVT1GGH61g4YGm97GWPvW9Fz4GTEC/YZhsjFom6IGSz2Rlu95MQI1PSg4wYAT6MCLv0cp0LMWCY8lqkbmrNM3R9TTRnKlM80YmyZusR2qfu9ZPk2TlVoqVQU6RORwxYejr+JF8PsSeULXyUVVOSxYF/oEHsAHgvSLRD6swJoW/XSHk1QXw0VUooUkKVY3OTYXneBewu2blJdPRSQx81npjYF2HL1x5+MzeiGTzamY9xheiGLfTpBdXRqLvqG7+ulYsJZrb78BVT9zGBgDHvEb8SjwKdDLBVVJaRwiXzelwph/7BiqGJMlFT7CavH5XAkyN8p5ktFmcZ8/BY+Dk0nInEAUGvJeACxAk1vp/HMHQF9ZIvnFRhJ9JjVMyK5Y+cl55SxCqsrbnZGEsURwd2ivNCAqpgW04QKKEtuVoXhBl7gJBfNlTysP/EJ+xxhJPL99hnknEP4rnewExjy2bHzeYfMb9aDsc1kQ0dKRVIndYvRq4wLbFGd9K7wkU1+a8XJASusLpaLshNVo5wUqIXV+qhP515UI1OA1UwOr8+dwqkk7S97hhtNYbcPU7qFkkglle2V76/wYY6jPYRJ95+xPRX04YxpugU2ls7UKpgOchRAFdjxKjo2ZwcVD1L2OLWTMuvT5xqUsrY62UBVMlwuVCM7m8pQwF8r4XLGoPuPeIXmTWJM06gCKZspbChHYQFTdshbeR/mp+R9lbOq2lhsU6yVMkaF35a62HEuXez9bl3sqha6WGxTiKpi3HZ/0T+KbyzrQNVrvDmSUQ15+RbeJ/j9KqWKckENF0z4D9ZfBlidgBwwMa3jw8ALeR/nDxhVMYw2AzRqYeyfFWthm9xa2APckxj23AVF+z0DCtAHTsBYXWj2loGjLvqNvZ7XA8fiybqRytMbRio/5h6pPNuWwaTB2m3w2IrV2e1/u/EpHlkre1X+UYNPvKIBPpHMxBl84vo+4BOWRAJskI9JJG+nN/D6SSRL/VisB4Xk3F4UkqevxvIv6HlI+qj1l0he3sdBrVzTWSChfvEYu3+XIJDcSoftG7bJbCWL8933yfDr7Sa1JTK4HrB4ZJZuUmjYNMNdqOx4xpnP2N5yvcybm9bLfHx9POaN1iKZiJbemeULU0tTBb62aWZ27/49M3HXhpljApl4gFR3zAwjZx6u7Zg5w9kxc84gXeirbhc6rvJ2e8eMUwas7p5hT4Gf8wp7ClDveerktaV1eyg8c4Wh+qVr9ax45woj8vs7+sC73T7wQltcizNLX0dniv4ZxLV1s3nliQFpa1esWcAwKHGNfKSfMJAyDx5mjw+qrb2KLnVdC22tn9PdJK09o0lau7iFL3znk6194TO2L3zP8YULejWhd9DaWl/P/Xc0KGte1ELv41EL98wyWP0XqKX6wpWsvu5Z6pd4wjfDTV7bH5uEbFtN/ZOoPZNNbmyEmBzaB4Tk4P6qokbPzJLKtfWMEt4zAnroX3Fen4dZ7++wa9xqBqOLqjJM6Tyo2tFE2/yKdKqFGtee9t+IgNDKGKoaCj6wWLbiLltJscw458xhRC0phXaSSfCbOda8MMt2k1nfh0o/mGxjso1FF7anegih+R+AX3BKRxyiPW7OznSKMqVNVUvMdchLOMgPMc0YCm9Hf5cgvMkXUnymIOOQxrJD2qnZPPpYQQ1GomC382TSl2ARGBtRgTYjhMSreb+cDHJczMD1ndua3WGGQhrCLZy4w/hk5izTRLeaGkhQMcdaxuvTgtgMIi6Eixyap3w+8hwRdfmYzFqIsHAE7VQCXYaO2X1OZGpLiLwe03zY3s0p2lu9GsQdyCtKwR8KsS+CcAh+Ak5xbGMsNDs/a+BHSufwB1CRfaqix4JodKJSMscPRY2kQO8dMSFq+O6iwr8+ueXW5BhPrgiNy5wSxPePjMXSC5nKDi0iGiXVL+payXgnEwjlEJaqcJkNk8Gjnla5wJ/0R8O6wtP3Bu16KqQKURe5F0Pawi81CAlv7MCPwSvlsQztHui69RIct7i0hYs2i3B00rTWrsbcg7oLg8qtWIdDhiKS9oTbrfRiYvKhndzS+AK4W8tnqh8jS1u5xXtrTWtG0FBD45MTRr04p4AVA5yEKNmNaxgcZr3Fljx3ClqAHXnuXW557grIc5FAgzw3DCCA4sNyS0EBfo1LpF0EXNwCx8YSAg/JDfdTAK+SlMmRZlaQrA+oS2gv3ciFcBj8cV2MCFZmxyHUQxYQwVNcUIi9lJ0Tddn0Z/XJi6ZCkwFdo08qXkluT6pDig/NloIipyZEKs2JkOZEKs1tDOSPzBe2w56y9cInutm4H6uycVOGUhzboOsq7lDo3RZRl35BaNcIHVvGXwQfDdJGPKQsuRTdjEO3YaSAJqRq0afWUy0ijJRUHyIUIQnaQQTCiSHRapO1f7+Vq4YX5L7VBI1PdlOPyJloKeUkDYNG4YBfBHaJDxQLSZSCcEVEINDh80uFlMjTdxcfAaYoodAuV0nJhfKrkZTa8Ey510rpTJyr3EK0UEhU/JKGSYEMFEJcOznVH2RxxyGEl31CEFGtGrS2GoejplcOynQvEtt78igPgzOd6SMUrLaOrTj92roWSfYiO12y5rLTgRU4BB3ktDxi+bGnoF3nVVI0EuIqn+/kMpONLqPkZdthls/rpk/h5gAk1+NZ9JyCxdcP9KRPsQcDahWOOlXqRS0qibhFWrhLudlbLPwahoQH4LTc5R1FKhXfLU9N7OxAvrGrfERuTQ+3dhzr9w1u44PTJSu/7jsnMvSHHL/tIlihgR8/MimMbTzK1quubycpfZnLZcOW+0Qd9zmYug+lHTU6T9jyve9isKA/r2UPpIfsB9J1NJb5Z5AzVnF73beajLbyy8GoG5xvVdfXU9dP9KnV3WHsknoYxTAPU0He5fnYGnUYrdxBmkSR85tEkeesxoVW9+C6YOBdSKt9Kr2sqS9pw4EHuX/wGoBK/zWIrBnPLOwb7i1rPoh0g39uIyNuVChGB9E5RR9QLF1uhoKSl604UabO0TlPFg9viwAVycmKSdeEKxQVevjRsMIV8AKfqKnoRrCxoJj9CtHZr+urOfJbuubIM7Uc2cybdI+Q3ClH3nd2Mxl06HluMii0NiUUCOUoRvRaoo7+bd+/7zngSU5HNPRO8BYw9BwXMNRDbIre/6EQ0p2hFxspNl4GsMwSnUAQWXpbldOYTMJcwtqsZItqhYgNznFQe4hoopiQ70LJO/0scq41S8A6EOgwgRCTyLMrN2KWQNTEiEZjEGFYxSRBMTg1vxD9ljEUjOt4t2U6T/ACcp1iyJhLEEAESagfImj92BALDbWF4HHcaYQrJ5XRibIc96dUA4bdT2ckzVgyFGKuJUhT0avlZJqRQo4BpNwID8sCfxr9ARnY7h7uCd7wvBKoAA+poYIa8WKYy55bqC43sCJCi67Ltlgh4JvfTubZytsxbqThE9krYABv0Z71iFp5SUFy3mX2JuM70ylbqTvgghmUey8gY5iDbKKMxYuF4cQF1A4Z2g+o6BujRd/0wYfv2hwMhYNBtGZxR2lbDj9u3xadrTkIYl5SRUbtw/WkGEru9ElizC3i+lICI0ZlgZD7ZUO2Vyao92IW4+CDt5S7YCx4XIvoOLkA+brgV+o4Y3GLM7aIL4+H5nV1FIIkeyRoAfqjcYqshBX8UALTNfBPoXy4Eo8BQ0BGEfIZIxjIBqKGvCMZ29oWSYEdvEDVUfP+hpn3GlY+bAuPWz/rmrP1u+NdU1lReyiLGVZ/auyaJf6AxokhNUmWHy5PwALpiGAIms7oQlyhmJ1CEtcWHrd5VUbN6KTy15qMcJJrTgsdq3h4METYg7ZB384GLtbYpHao1NqkjEi4hZCOxMHtXF/2nNh8yLYFlz0XDj1i12Jrez5jcrlmzuMJ+arLnF9g1lz+QA+gwee3tebUaqyJkIhUftmIEcScJn7igN8PIZiIVPM1DvwSmkfA83xW3UMmA7twCy2fXzEWz9Y/v2ykS4tykGgfuzRdGEijGmvCjjXoWVdoCdPTTNnFxdo8PR2OWfutL+LSxQL4vkRvfrT9z0+aH2zEV/dMO+B+ol1EyPsKYdWPmEgZClbO8AdDEnRWiLcj3PshiytKIIQBaNR8IAgn1VhAEy347wfodxUS2YLGnnfF4YL9vMOHD3c98Njj7grncbe9+rjTCtm4QPxSLJlUYEvaA58NptFIOmsNMadtHbZuhrm6o4xdpD/g/sz9AUPpL2dD6e2jher0Y4+xxxxZdM6OSM1u83ls/vPIAhseH7JMBoQPd0zd23sGucn9BlfObxF/XF55Wbv4Aw+rYtYcmpoLKqYvsyVD5/J1IzAaRLMtXDs/PzObjY35VaJL8Ri6cf/A3uCTnTd4rPoGM7Oks8lqGDJeF4ZUsNYRZbpEQqXzilNJs6j6FDkLCJuKDX9ho4xWWjscAQHR8DydzpOShnlSFKPmbSAHWAs8u8CKdUuXOt9e1EykDtNpUxzKzbREWzqFrtUdz8nd5lw7lUPqrjPyLOciq5zrLFVqfiq5brHDybdlA7Ch6vT2dzhv7PCn7Y0Afag1kg/z4anI7GkAH761E3aTU+0LiV1mGGkQQQ/AfcYBFN7mLjtMiURCuMtKlWMcvJWZCtsAQ+DnXPzCnErxhVwIylQHiKYNUP4z93ucn9es5flpPDxNp0la+5NER4SRKrmO0dUNx+pY95H6/UqPlFE7UumZuOtEHUpyE8m637tPmAfFCO4xz1Ge8yGoQIxv+d5bCfXIvHt6u1FIqW42s4D1hQ58v++mT0WJxno+Y0cFXT12Ent7eUsL2RiN0N1jF1QuhSJiIlUVqRwCYkSIvplvnJtnrQOAJJ11dmti39sO3XstOZfaKm6ESzLVM0aQFo2XZS7Mo/KK8Okw1BZoyQ7vHk+mRy+V09kE1PHKxW3oe1a0BZQau45eDmli9RdSQ4RM/Z4fJM8vxn2wehUt1V9Fz69eRfvbX0X1AfL/yMb8YHB9O67ftap76Ifd8Hu3dMLvWZb8jW3Jf/XcvDaW7CG1IU+NFYO9ZDXHrLURT+iU2iBw7mrBH/EGH8R805VosFodP860RJ/6l6gamUbQBddr0KoqhQW5dGOkQlVrzdn8WvYomx6q4peps7DQYOVIOFPfetiu2O+r3nCMyxvGo9DbyM2VeZB5sKpRk4SiCil+/qDNsb+wFyiplaedHiyElp6z7dDX7BUio+jIMo3JyPIXjGgcuomuZRDizvbBePszS4Gqn22M6tbnFyweBWrv9LN3sc++xbYcEQVsxQv46Y4hSYiilYIuXLdIbY+6juTX1+ZQkt7K472dy17K2IM+u8ufrquL391UF68QLctN93B4KxucAvZUfQH7D9UC9mrO9/IjnJxm1e+xavU7EzYmJieq1e9/73jGK98XfNVita8VbaL2OL66qmcN2l/6ogU+Jbd55Y4+qYBHrvXN/kh/qL+Pd77q6c3wfdvOb8SE871rdTOUq/XkgyCcOHf9QaTAKk2cE77S+tNctAZrxOS02eN9gfY9/AcqEjSYLgNaV6ZDs5GB3xE/Msog+8FIvoiajvGL/hRKNCLGo3Vy15COpmZDlPyozGFqlaLBs6qR0HVO9Y1FEumlXq4OLM4BcvxB2EgTPuz3afLqroq7pADrucXPvJuE/ai3YUkQ4O2RZFySvbTMFU1ECM/Ac+OaqtB74JOdL4+vcQoRSFBTw3Ron+6LokPRCfTjPsr9Ax2VtzodlWii7HGq2WqmdKaao1Q9tRsb++yntDsqhd5wkP/psxoEe5hltlola7PMp4iRaFRsS/lrbJdUs6D30YZJLtGZEklolBCURBM+zxoj6cxyfV+k/Y/dFxldWFyIhzZYnZGwUdfWyL1OayT72/yxmSN5VD1H8hrKkcQjIYP55sfQMks7H29Y1/nmaRcKYXFh0fpm9h43uBP5/HrMNHPnO0MRqigLFiMfb1sGW4epcroGc8xv0EMmnYNAHFguGeNPR3N2Qg0YtK4f0cpeZpJHud+B4HcEntLvtar54zyrTJRHtnnnl2yTjJPq8WGH4CCeqgYWmgJvLDVk5CCOlSNZuZ4CWMVatL7gMEcWF2oqhT3ghtOX4WjTQMnWIGA0nGH7vC0yfTtCboeOk/jhxGRMCwLZH4hrMfVnuUelkGjoFOnvTRpoPTbUu1Ijeg7HL6D5xZD085+ZZiQV+AsOCVQGIYQVEiJX8UfyqqYw1D/mwlB683IyOhson4BMpY8g5wAoEjaMlKnRIxIIqGE5AVrr4ThzXr+RwJj/cCGhJFSdbpzbhpMfg+uLMBFHgF8tPRevGZPpgAKXwnqLP4NxogjqKO4zNFaLoqHNjRqFlAHGCaei9wZGl7wyHU3Drw2THPkLKHOGgUNtJrHIXR4mslbIJyWc40J4CBZL4BA9jkN0qOfVdAdIafVL7gcwzdLlfHGf7LTF/pOVne232N/p5Fcl7LNYzfwK3+nwzfa3pL5PdF+gyzH0smP4fzAq7RS+jjZNrV+ncNe7sYc86uQ1bwfubL7l+9e/3Tfb2ajLt3XD8WUO3I82Kvo0vNTztgHNAfQzLIxJ4XrTz6MNq9H4X4PRHmkw2g+/3Npod9hGe/g3ttF+0s9wcGZT6S+DfD5WHu9nEjgqZU6pM2hk05alSNPjEq1v/F7grsc9L2O0YqhVM7Sabi2CraLGlwxrgo+j4OpOVGzMZnSlYiM6FSnQ2OZis5SXfc7Iwla0u81bhh5H3xt9cYCgcOsAuJ8fxdyVF5X8XC5JPqWURouyTnvFZN/QhvFQfjP5bju+dUe6tcO3/iIedqf64z7V/mBMJE8HZw3/9VsIcuVARSCRdNbn13EvqFGzsLeIxSrFyalgOIRqSeWRNqRqf6FY0LqyqlHmBRtsk0Wrrtwn09yCF0UUUDQzZGpPaBj8lE2FA4jejEREXLBFGzO9w3MhEC13wXQi9qnY9qLrVtngHP1/1QNiN5pxIg1qKL8cv5ilysLaAKaFMQvxlSEiWh2nw/ZecpqeRtkPtEDPKK2M4duQE6WZTbMyCRXzSQxNsdoMjGUGhDBI8o9EZ0zMV9oDULwS8Cc3k1KPCGoTiZ/Fyyu7eXl0JktwEVF/q2AmTqEpg1eQh0MkOZRCvCKL1oIT/DQhhRxPUyO/Xxstge2upo1QUc/zdDZTt7BOkl9J5wsAgQWX4IpaQlcTibBXJaetAa96E+IzIcyNYbu6HwmS6GPvGZFx15hx7B5Dyq7yzFV+Bqh1Ba7yHM+bPXeszlX4weKsS2vrIq/pA3cdcuGusw7u2oSFHNz18s97cJDjVugglTd2YWM/eq6bjf2ser7bBW429qd68gsRfvE1BtCmfnG957Oexzy/W51v2I9vVonFJQLDHURTJFb8wL/w+bQliO+JkE3sehY/U2zwuLSlj1KX4/vyHjoShJVTyM9WcNdcmkokd+TiEwUzJsVyudgRuWg0dyz9LxkD2N1Y2pVrcSHRIpiITuq3jB1kOWXCmhisXls39OBfmpEojBRGV3wRVf6aXTJNv+iNFcaTk7lMOJxBDpgw/PS/AmXykl6o3JUXWVcW5DJ0XrwtEqteaUI6z9yWK/bihMs38/FwPBFPZGLsnrrf9sdrPB+iW21X5YuDwMH35KlrfIWRPVVU/OYWqPj/qBzVFhV/u4OKn+LS3Tx0+cc9ON9zGp0urUZbOZ3a6HT/1S9L/gsnt3TDPXVueKPlY9HWPuZ3PQC/ZzvWrRhaPbA6x4rZ7UNpKwMpz49QaYlt5SmPWPEwtKM5d6tqgwfaZeJiay2DDohQCOY/g+8tpyeSIJ5I8VRCMogZUvDNlGggBTFfS4ff+l4lSHtq/NQ531L1TUATpqJeLbd59krEtAmryCxVVRDmmtduSWpZ6SdPqVPulXTfaPzsxJaoP+D1+dO7cym6H4yL6SmfxG1AK22wHKBj+JmYIetliCgBKpVYIgra0HyWz0YU4a7BOasAZ33MDuxfAEzy9zx/XZ27mvUTtY5g2Yn3Zq5ZjM/3Mqvbv5v+Vtm+/1nHb2s5ZXsdxsTqUXAX97oh4a/dnW+ve2A3Pzk/ma8N7HJTe449bGrlD+o3uwZvj8zMcNWx2ySi12wo6nDinmnP3XJfIQhH6pOHk1aXPCz/oy0ejt6qD9qOShcd3bPKW7VPMFyfSxfWOBN9sk9uXGZz8ZsD9MIV+9g7+sTLRZVsq8UNq01R6aX3sO1Lx6Nu8zHPnavUMxondAfpK9ZtZbtK4+xt/75T+eXMCZfv3n3ZCbOzJ1y2e/flJ8xwr1i1b1jiE/MNtbCwq1jcOZfLze0sFnctFFbsLQ80TO5yZw3EFfwoMjj3zXIT2awIstlpzDNe7/lPz69XnxSwggO9ZIQR3d4h7i4EWuPVC8VqcZ0Wl+A5GOcvZoV/pkuH7A3ng4ooBLTCroyYHh4Zzkjesdkx3iiGQqOmFqMVcW8qAHnRhG9gnOa94aCe4LlwHMsGyJdDw1koCOF0MXgNlyqNl9LTvbrdWgpllX8opi7HoiFeCup8IBwNB3gukUlwioFxS4E38MlCEBx1DDWHfMTnVynQKqiHR2nXRTgUjVMBF1+H+uTJg7+qeM8m9PIGeMWzwXMaekExTRBro5ez/avM1qTvVRedJHERLkg2qYFUEZ/IS4KYSkXJDXJuKCuhj4VHHVbJFIeDqXKSPNHrFgv0xilbURdWLDY9ZwpkIYx/cb8j0cJwoCKRSCrj82tU+46Y+d1Fch5fmJgKmCHqk8vnOQsq/vC32oKKXe4FFa+8y72gonK0HGC7L8QMVbgN0/9Hv98Xk02Z03QhhHOLZ0IW9Mm/YNOEiVr+DZ5/93yrBXnBOtbFPq6E2ADWTjRd+tYRHml13ucwvQ0/mD+lCcpwCC/hGC+lJDqTTs99ouncq++KTrFzf9vK10/kGgEMlc9YR3RJ0WqnOBjaGpbo9dKEZzhRjcdNr0rs8zxSSpG8XkSW5Ys0nudcXv/VANZQvKn+IUB+zo4eZ53PPAZSsvb5xE6C8vgozmQWjVa/wZkcw9p59OGU6g4jXZLr7KC3K43wIKYPzdI2rPalp5hg5+a07wqz/bQVa6E9mA68QsgB1O/QIbgVxP9qtepuJZfPoN5Du8UwSp/JDoXOkmLK5vxoVKncjcKTFFCUslJffTo6HmYZ8X9iNLeYUzlYSw9m2d5pnxIwrGKWg5cTrWLW1XU1qmAmnQmRd4Ry6aSOBioSHZ6KV3bISa5NdUnTfUntAdpzNVVGswItYR2WnEvoblTcB6qouGxtRDHmyxWymDXH8zqLbo4/g0G5g6Hov77KOG7gyx76E0yO7/uZnBz4OojK/jV82p7TQ8/VPzruIri9Dk375h5LUlmIHP6BecnAV0ustZdcUK09VUhLfOAP/im8w4UDuLyBKhhLRHpYVHGp2zlu7d05HuCWATPegcbZz3p+MdA6wErayaoRQ7lHtjGYtm08CN3irTzocGnj/FQ7D/pBKw86o9p/trm5/+yDlSPb95/d7vSfTXFDVlQhKVJC7MJAplHeww2upgGpqg+uRnBXfy1rp9uRBp6BQ/oFnVDJ2YW5+bub1dcW2msWXWt/Z3tUzva8yfMVVER77FszV+GhS2t1MfE9NLpd2EOj2wP93m9/HeTtdeUAOuEuXOEF+OZBP/qW/7dzE52V9Vjx0/FILz/q+eqAlbA1ewo2JUV9PxYrv27MkTj/QJ+DQ42p0MCkMHLzwD2lUQqjWc7jwLvzyHEuAS3VVh4s5aALQa4Y6ShPtAbJ2RMhYqmrGJG1xIidHdhwO7soFb8AJi6pBYIioZg4mDVtDX/w3aSJz93bjHubeI4b9/bbL3YWL9Iu7NuRLuxbTDjyzXt+l5x+ZW9aBbQhwXM6Wl8pGgloZBJxKw0zCxQSJ/WvV0jsiC7UdEXA/xqZR/QFFp1jbOkVTlYKzMhW7yK/EsWCOxPhAUg4PtlqjIrqQwgKetcsQPQXikEcRzWbC0pecP2W/950wOegNUKjSvnoJJGg+iRFDqJA7A3wJNufcEHuOxnPKxRZRNYh9QLi1Y7pS7oYEmnscQ5TLLymJVgs39ekeatRn6HhZEO8KAi2eIFFkF6fmD40Rwqzm2eHlu/pW8HIAb7/C4hdJ4D1cD2cpwv+fiTSrj8X8esiUzgyxELVQoiwpQ5uca6T1rEVwTFemOL0ubPbIOzPCWlVUeNLjS24x0tDlqSBsS8xVSxqle2WtOENx0yhXtw4zRY37iRnGX5JkvPFAvdqt87wUTeSfmxmShf2dei/5Zi2caTd0EsKC5WJLjLHg4HNBY6/wprWszNSDpTXHQxt/sB6ZKSrgAILa5ygntmVb3/Z6nDmj69P2vrCxrQ1GWkLw5/pBsOvMWRf3GNZkz4WODuYozLHjwYczNmvYo+wEco4Z53amEjGvg44Qdl+STb8EDEws0mq63f59Q/w/tJ0/3MSncrl2ReH/N6YHz8D+5CsxYLEQDGKoHIhR32JkAROulfxSWGZxnzU/XoK+ibXLug7jBN9ilcP6F7VQECi+nL0A1omQduIfPF4BJRawocVmk5XfprM55CsqtgCHjJDwhMrCgLpPXUvW8q3w/NWzwNEXvd6qPUIYeHhXK0uyq/KE8nIWgtuKy+V3od0Uh3DiDp3c61g+narYLpvpc7ba8KyYi3lUdnU5GjUQBFV4wMmiqE8F0/HUUQVaRE16MfKoqAp+wxFQRFVsYqouh4e4Yy4Hg6qvlHwxuRQKBL34e+g4wU0srMfb38knEhY3q7G1Sd6an2z6GBx7pcorPbGWaY0NdGaL1ukT1nrKcnK9VneFvCoOwNmxcUoLDQWXeQxLb+dK9MDgi8sTg+xT4ngeID92hmwfMIpWPblT25NJMcFgf4VwDAKlEdGDGQ3sXyBhSYETWe6sRiKjEXSES49NjKaDA3dijdZxMSXkkzcGQDZRgNb24jGlDe3Jyu/is6tc1wknZ6bmc0cpuUxMStRbxFwTnL5BPkK4Nh6WqLA7GtphYGgUxFcSU0X9wdjGBfA+8uFtFf6VS+x2CXcEyARnOl5neeTXcGtrHsfxIiRoQW39sU0TmiYeKccVCE9y44ONk4Zhb1jlGmeabZRqIpjfLEqUnUkuJLn+kyfllV5R8XS0zpO8ZcSqWgqAWCFOYoAi7AqKRW04uqX8Mb0wlBms0PHwhI+qj1hlgytXAjhkSsnlZP5sZkxPjIWVSgr4XUWwjVaRbiGHYTrFna8ZUee2kzlKcFrESmYSBWbj4VHw45KpQ8b5D+6scbIxfUKUrqmICETpZb+tm3pj3r+Zx0szTMkSXlkgUkII3iNEUY53E7Q2bnIIl56qUdcDxMaB0fFmE26ASUElBvy1HnCHUpajwb8gl4w4Qp4KyXjuPwI3v3sSEgfLg3rkRQgYUpI1uNAW+NY+SIhHe+lVxAi0nbNhGSeLfpPr7xr3Z2lcooSgEqPYWIsoPPqZkQ9SUdvqJGPxxVKx/eF0pFzMNrqC8mBHAZZg3gsocyux3R/WD06GDONuOpVL8S+gC4uhcsD7LNTPe9mjXldqM8rcigH0L0qrtqqfejcPl3oCxa321wVZi3fi9/cRv0mVMeJTll+s9XtNbPNXjNZ9Rod/OLKS3snrnHbOojVFkLNvmpejXmd763DZdMbT22ph7rHU/jkWb69h5rL/q5Vj8z6Xzend2OsvagjQ4080cM9w/zpBtR9196bhD5oa/xT5y+Ve/ojrr1k3R3jpv4IbHCTDn5A75Wf2X5wmef/eW5bj3ulQVhpvh3mF+fLTfauk0ToGMsaXRhNiwSubzYxzzfZ+CVN2wau7NXqu5qtvqPpOni0Yb8AF6qzqzcYDHirls2JlXAQcRSiq6BuQEcUDXbk/5uBuac9ZwBAQZEhrXI60jKni/VFri91yPvIb0KH7DkkhKenK7PL7isgrwtnsq68bhJ53RtaMutnHGb9zOS0m1mPnTqtcz9yNnufrBwvl8zZOV5ArGZ4V9UyvGPd/PpD3XTtZ1bp2vc4+V/Ulf/treZ/INuzI/U2z5fRR1vHoadLfHF4ysUqPLaeRs/ecopswVvcnUdP+jqFLNBr/8iuO25X1xKz7xJu44ljxmQQm9lAp5fERjy9QcHcwuypc3gj3tSJUF/5UM/nsXIMO8D7e7hfT3HStfB4gHZmAl0vhlU3uz4Qp7x1Ljic7MSuJ1f1dA/jQy/p9mx9gDnAi7FpCZPVJXeathjN0bnAnt0ApseRpCIgRvlpji9Gq7Ihzf/YWmjarLlUhKNU/5Af4dfMNYiBe2W7k7VltqLttVf/QItUcksmkjZk9uYBCDJiJjAEBRw/hb550XGNUJnejoKojkdZinjjWvjMGXbulvDRrw7m/R0dB1MzrK7JK0Y6EvULoMWZaLk2TEGKxnbqSUYVUECk9Ppjx2nhUMgf5q0ckXxuID7lZVRz6lMLnnNRs8TmZ3Ml9hWsRRc6X7TK1fZWjHYeGOvOOe8pVntpvybk8rP7se6CC4RjvmwBZZ3Ykcfti7RzrimpB+r5Fb1Eaj/u1VqfwaNkLKNCXuaSWXzcXpnRyn2+1BGG3j1Mx5aUoOe5CM6+3h8KnX5svquJ8RAvwk/qcvu1uzq42/vK3vXCxm0buNgRT9sbbn+xzDwbnvKOaoa/Yy2ui+7odD1idPABwgVieo2u/o2eJITmS6FeFBDgHfcz7zgHu1K/5XmC6Ig2InNNKIQly0tiC/UMjjlKV8CAZW8eotNmW9a8tCL3ECAgLdokM9pkEXGCy6LzvcsLtTJaTwolqaYKyFRoXwUXtu6lLeTh9zscjytsVILD8bj0NY30jmtkNCuRXpxMGI4g9yvo9/TrYuhtTObSkC5DYZ099+ifaupV/rzmQzWfwzAzKI8YTunhirqeyhNoofKjnQXiBPUNjKoDqHTqlJv7Mavb2I966Adcx/R3dFTs/wlG+X208Rev9O5ePfUh9mGlFFbzQ3kVf4DCPttxqrAXCPmLw0V/0JSAuD6lg1Mv30GTGeCY0EiNm4FP5dNepnOwu9Dy9ld4PuN5GHfhbJQKB85KBzzN5svVfTUHkd6uPkSBDA7tiBIMLU5LoyiIsYKovXXNBoTjig3YHT5reEn+R6SEabt03l85PjISB3pGoIBsr5qajEIJf30vF2Jue94/PJyTsLI5PZ+uvA0NkgoYo1IwYdA8Kq6m0cPnEw01uRCpXIPKG/wBjX3yC9bi9pwIA2zC1rsVQ8m5pFkyDaDKiUoPQwdP1EEr4byqZhQ5xnPk5TiDMiCvHlUlgbaW5JkffWcg16nXk0fcrqGxcKvnYqzog/pu0vr+Uu1agmexyQNW5F+y6/wWMaE4VhuBI05f0UGkocvTavK0lgmzCceZBRrAl9ybyewdI6INCCkiEKBZH9zEFMv0UmdfHpGqhXurak/7jLfZFMGnOUV6NREqpWOxQwpBRfVigiy/lb5x6BYMqbliCd1925ec0j497bdVlwrn1OfZK4Tt3lA4h06bRikyPDi+IV85FZtJ/X48ExBIvyOcCiiSrofKZiYfMQ0ynFbDQR8/suu9oiabPr1WfC+a56O6I2mM5Y6WH59Afhc6KFMoI3UIiQGNt8fp6T/hYnS4WI7n92WY+4gozgOKXDkKvYtmIJSiK4V/AUEuJiGFC0YmY8fctOdvsamEBsGFs2DiMnkXUTQsMtPhXV6sVvcH2OotvAU3ZcbgqlrM/AAO1230I7RsPlqdV/Ai9VA0ZY9COfp41m448B2cizh6QU5HAP5Fz92rXExDx2mdjkJs35pfjMzbHR30uRwxaU5nQ1znZ0fq3cgI2x5URv43VC65LrmZ0iLbyOV4j+VI1icg4ywPYZUFlXqshdtg43PfroZkm+tDsu0X3HxJJdtYUCls3Hn61dWCyjRZVJOTQ1+m3akSoO94H2XFDMLvfo+OD7iTSkTqTcfQ4wtaKPBnlPwuyOoQNt1LQgA07MrxuLtElM4iZoCca47pwaRRCmdTGC8XE/5CPgZrBFJ6wCTID+PGq9G5HCj3UVk5I55FDwVQpL5klKBZmQgp2i2OVy2WKhfiDwJ+XwLOtCwItY7kyWjlvqTh031I+tAkQC5F/4fg86F/Eqxv7EYImClVYjg5IzcblHjJ8Ac2pvDjPAjQqCErWITjBfZvw4G7uCf5kGfS8zTPS1C4udPz3x6PUMUELS10YQTxfM9uspVfGJyXsAUIVKG3MEEzZctZzEbnuUQ56JhnHr1F3rpUTwK6jOgWCQiHOTE8/oLenKSFi3DeQHko3buL/BxLmNkKUx+ZO+KEw2eDakB7btVtZqnDLG04LjdfI/wkcIElQwmH8POsjfEs2OwfdTtNMpeoc5oLak5z6nmL4Iy2dBvi7cNtKtfwKPCwpl1FjaH99ySXHyH28eSg3f6vZ9GzH8A+iPQNLTeQcqkc61ZzGxRd0n5nn7nIiNBLtmrLI5RizV/jZJo1PjP+mkjVW+49mq3PBoyNoch4JI3GvfL+Mp7qiQmUxYkl5+aOHMIC8kgmu/w/riV+xdoSv+uxxO/Fkl+8OjkUB1xCEqwOMlEq6d8NRGIgNNMZa4GKt9z35VwhQW6PbYzrLDvmWdBAtdxMZnrjdAatU0qRUu5lpucuH9Zuyx95OftKKLchYH2LiKElXourKmctEVHwvMLMXrHoV9n+5Q0H/od7hBc9o55jPC+kEyCdSM20E3yO9Lb1o9SiRXyhsUOcvJo2d1f7v7/c2P+9H/3f5IbOuzyW76It4YLijSdjDS3hz0UzAr3oH2dj6omO3d7L+5p3dJxWv6Pj5r1PKKHz3F3gxsTeC4+tawJHgDWKYlOF1zwnYqTmq54/UhGrzBrL7DCdDvTPO22VC/YGliW6v42tAI1ZQ59I8hB2RCW06aF/MUo7LemyEsmiAdINLOUi7XGIVkPvEdYXbgHZmDQSc61wwQYJ3Ha4TBlXl33Myie2EYaznwfVfsnGmrMHvuGY2WqpLFF1nhHPY9YrL83ik/Gt8AJl9GIulIvYHDQCOMqQxMK/yOtp7yGATz5BdJapoADtE8Ayk4Ww6BMfCieToaDIs6CVTeaIvE/Eqh59M49FK4EAeRTvsonYSsJKCnMDTgkXCsWxLAIu7fdxIvUKTsFimHAwq5FjcDfx8vMFr71Bhw8Cmx306RGEQvQg8V4E/wHUitTKMI3HldDzBeygkXmZNv7SHTCAX8jC8w2V14E+IydiswWidinkU03QEaQdUlC5mEcFXfHil8YicKSomBiTMbwRlAqY7/CGwoZ3H11UoWHpEBBqWFyBpuLf4sSVwNbA90D68DrMLY0KEh/xB2hHDeZqsQhHUqUzrGPLCX+UDR+CzP16Qn8+dnpgmDYYVNHtyXF+VQ9XbsRlixfET4JmyPslGQcCR0LBX5E2EIneaPgQQeNkL93NoXnVRTT32l75B4x67WA7MVaJQhXKFrndlTZSf0SEyBQKlv7R/AFrhOyUwM5Eh9AyYcPYcPl226sg9DXyfHy/I8+Vx/GskuLJME++ESmHDZPg7gtu0FCI/IAYDhsYDUQu6MVYdET9lBl8VQIbhrAXKhAsRdVd5Yn5yg9lWdKFoMKWNr264/aFv/c06bzSPvLbI9NhHwJ6XpaiISOORxSmGnk4I3tx+Cmm2fyJcFi0/vpw95IenY3+tfN+hrnmhvIWs/WjB+7lfskc69lYb3b/6hyr1HXdQn8+0Tiqb/8QHYi9TbP6fbsVeX5HT/hHT55wVnUa/1B7Gh/NPM40/k2VZ9Sm8TWpbhj/Y07SsnnFvd5z9VsehnKFSEvH6DT6vvxh1+z9btHArhfodKPW9H3Mhec9RY9h+H6UOdL9tiO9ZQCQhs66GRU2ViCHkaf2wiJbq5rZaS00s6/Pn7rg1sPe16CHaXV62Btqehh5ZAAeu+LJgq+1Fs6op/Qgi51cf4cdMda3qyIK3gzw6CnYWbIFosc7rVlJa+xZcmYlrXjYDnjtP0asGwbeaw6WxQilMOAdJiMSvgq/yLmcPxGPBP0ay9Sg3ckm9gfcFx8PaZogBeKhWSYRcO/Du/Hu1SwsqZxNPsxd6RseTqryhtnZYOUGvjQ1E5ACSNoETtZ9uSwGWFR9KGOOQzjlpKWtUwQmNoR9A1xV8omfEjU/XPDJ4L5LuBamsZbkYOAa59DQ80a6zstBtLFJdPSJEASu9uw5PbQHcYv2Kk3rrTXXaBMJ7hPI2nSMCZo2psTDlmRK7lGDYSU5nFi6cDEY8XuJ3QMgJdMpGaZ4hVbkODWglvFucfwHe9w30htGsfImauizg7o/pdCQREXr5+Xkcl84gM5KGq5GsgUN0spCRMtmM6oW5H1aak8+OmQa47iEZTkXDEUqp6zBYpFlxLx6RGcNBpxRMFTZ0hunIUZbxj3L8yrPpz3f6du8S/0YjdQ3qViTBLVukiWqLPAj1khB+26UssgPxPh/69WsJ7kHCDLHZCKpoFTXPfI3I6lbbSW8TJeOisk9LftPAsrdA/AQoy/Lf6uuCUXBAMHFdc0jl9HomfaVBDRNVOgDz+5AAXLC3YFyutWBkm7pSfSaeIzfhi2Nc56TPdeyPY39+REZ7BaawVwPlb/3sW3GcG2byTjbZijkxNk2U3nFAIy/fGSXrTK/Otm9VeaIelzjWe6tMvEOprQuhZdi5Oi/+jflirJTWqJqyE+fggdC5XnVnPShhpz0xsac9Etm8AZXTiokCqPmxqXKPe6s9Np1fXSQleWhXHn1zxKvZwiV811wm92A2bzdc0vT3s+VLWwJswxhzO7eoFiUsu13NOCfc/ud0NOCDQGwpKLIQj7kG1y1h8PpFarbxXJb5dC2u1judHaxlEiiaCbKycVnL+bz9F3R4FtJmepNhHzcF6Su5YNRta47hS7guNss60fVjf0uWLk0XKBCLdmYjCxt2RRJjsaYl+jpQCBiLNlugnq78bVeFgL5giMhZI01436PGfd81m58N1Wq12Vpysha2/+4tV2IUlwDzyC5ge05uWrtfIYGl4+y50jJc5LnNUCwfL3nnbFrGYL2MkrW5lGyr5cdsi9aixB0+cddp8c+1eIB0p2jd8Nahp4f6YjGI8e1TUqs+GMBDanvwIqAH7iL2T3vvOHX0ol62XrTzou4pyk7nnHmM7a3XG7zlqblNq9Zk5RmyL3mpjC9OF1wrbmZOfz4vTOXtPCneJ8LbNBHuIbudUe7VTYUxN7Gsx5mnmV69qDaep3n39oD6NfCbZqgbe3y2IOb0PJvWAsvuKwRpPOnFjZvwsfPrKVNv9rAWdvfJdh8BojCH6SzpaU1EZzNNQ8/O3Zhfn3+3IUVdVjeuwZhx8SqdOLL1i7S4D2LiDQ05g3v8tyEgn+YJpZ0L8Ai+iqXrBr/IoNUxOgZo1KkYXdI2v+yxGViNQmgS9xwGqDsr4MQFbFIq/ijJRe6MUYr+8wP6P/N2q0D7DuknS1XFNeZtr0LMfHIZ9HN6pPjvjTqC0gmed2fVDRZE2n3jtfgJF7EwgcoyX7pbXqUjnf6gd9jFXwRYAdJ/v/MfQeYJFd1db+qrqqunLs6x+metJN3ZlYbJe0qCyFARgmEJJIAgcgIDBhZIAsRRBDBZLAJAmwQToBNsAFjwESDMQZhARLG5geMRTJoev/zXlWn6eme7unZBb4FZnp7J9S9774bzj0nmQ4knOQzEoC9YvqUcNMW5uh07H46voAMSCvOgsD+gZvNq6Z0OijcAjNovPuZHLlTY6RtnJT4kGIrroZJuux5WS0NColE4wXFMyFrgNk6nWfDpHEOaCkTJgB+nWMUipaY0AQZIi6mpEsbTwP1IXC63FWurhuqyFtITZUkZgDaB38CCKara0C22ZOeGmhg/Ny4T8sbesYCYmY9+MW9WqB7JYFXyBWf/TzO9P7jX8MwIB47BYyJt8f+DjXGCuaPXeHWbkZnhozpDc+Y9Ajjy4EEtALt1Cios1Vh1q1uixS4gFPDLYL9lMbvECEauK1bIZiF633pbCGVz5ZSm8O1jHkCIVfvXAJkuasvxW+tSPBEYgYZjVPFXLlIM69HqWhQyfYUO2oF0/Ea90ahnP14yxl//6EDvu55bhTKp0s/3QXxj3RwU+BvViPgWmIEZOJ0HGMha04yF/g6zoOCg/wypH0/PFFhnd+RY1EKNL/buza1IPGN966t1ts4HsrBvNgkb6Wby7Vup+E+eWLiPzeqL74UDQSaJiRkmbYxwfLY6YxxtppIZ5K+bdoAFFFvBIoex1sw+cb13Y421kXBHe3x0vs2eSm9P7q89E9wMVzIcgpUSKGnruHycDE0U/DE4J4PIaR2CgeXNSHLgo0/mXrqJ3XbxqUHT80tPOoU6oQpo4Lb5OjxOwHbkzGN/EOQa40wjaRTLgDujhCmMsNHKjNoc67SDaLRtGaESeSDbP745OHmj8LM6jKqUd3IAk7vIEgwdZmqHW7k9BeYafwUAoBkpLnj3kOnaBw//2H6BYxkyY0mjlwc/TBgH4bTl6EZo6D93ReJf9hvzhqPofLL4vivgDDuJRCIGrnzvOu6IX27ynePkpADrroN++rw8iA/2apR/IftnNxJF7YfIvx9e130RZsIVfPl7BA6IDd38p+/ZrFPln4q23VRY0ex6/InsTt6WsI70O4YJSMn7UpsaJWP7vT8a7sgytEYKhdPs2TAcE19e92OxtM60vLl0UQ2njhsHt74UTRHGkaMo97d+cM55u7DOV5Hv3jrDs5BwF53vYcTjHCwx2vhPGNAC+dVza2EVgvnzaPEipuHjgSv6OrhLKwvdPRwyPLZF5219NBtejgXmvmUSVpdnAl0cSbaSwpXNbs4fzxadLljBOWExq0jNnHoJfF93mWXBHWuD4wOSBlRmJin714/6XfG40dUIBYtx6Gl31NP6k3SmBlRcFhABcPFvcR3RnCSra8XWvZ/F56gY0z9ZlwvQ5X9/nDaGqP3BgYrbmxX9Z8zQGjjnOFbAtz5EN2wddMBXH2T6MZbtyv9n/jNXtmNypM6ZTf+7+YRmwPP7NDhuLJbh+PNZ/06s0gORHX/N/EuAQQD7459MXbX1kIb9Ul/mxINtSAs313X5cneyFTdehvu+Bpi2yl0gNVM6qz0HrpJe8Oewh3aLM1SVrC5NMMajlPk9M5CDmC/zQIc17USlIXeBOUvG6f3T1A+2UxQauQj/SU7Go/miilUdsl0mh6673cpclwFed64eP3mJsLhziZCch+yns0l3WNQTpjxXm2OF4+Uy3DXdyt3fGqTckdhbu988VWILvtVBw0Ga4rVdv8BX4PPAabwMuSjQxZ0q+0akG8VZtsoejBB4GjOSf/nIFdfZe7R9SIh925f1bUrwBtosUY+0kfM43CQFng0/kQRe4izNjnoFgQp/FSdzHxxuLLuBR2V4LF2eQZpiH5iHtXpaQPNP11CN4vVgrhNpPxEzQbgRMUPhlctWiESrryK8z4HNcAf4wJfxZLz9YwNcMgLPMryfXcoEdH1PtdwwOzcIrZfZbthYLU/wkX56NbSCuTr7LDOb3N7g4cUk1Yc1tuH1A399y1u4bsxyG+R0KeN6pqRUygD/WlYT08EWyonDHtx45zCZdjVfdEQUqH/vNXVu67Ybdb4+xOcwVzKIvyElpSbhPETeuPLbXkEgAmFqBzEcIeVg38Z+4fdKAdHwQe540oadNeGn9uN0OsMUxy+dBxVgh+ejFrxP3esJHBu/8rxfbGvxX50cirHcV3jd7aafOE4rvO7WmA27h3F3X7YikNqRW38cGTQwDGABiS4JAUNvATI5g+NDRpwx1T56RV/6+NZj+vBETzzpDgPvZDiPWJv9w6DLjh4Il1hk2JP4/8NiTY4FWMpg42lbgQe+mu/C2iDXb7MvnBi5lCfPqnX20lCKOzWbUflcTJMHucJVP1zCHmckAuZIeAYYpoxZ4pe6CBrK/gv5apbi+5DtKbEJGtlYPMbf5qCOdTblukNlQQMP2C31EHW9AIAEgwCuMkkFD7bS+fUDzn+Mr2xMBnkTT+typ6jsxkeZwtBJrhHNalNdddbUK04CzT7zZpZOlzg0nMze1JOpbEYr9pcZXF9qcJjoVHQNSjl8Dq+j3C3DIkjQm7rL6hzC6wp6HIJxMpfp1RwUCUkVL9OyJXzQGQyGjEe6NxsEId+HWh37D2TwTkXnB0cQkvkxUxhRzYF0r4I4rbvUxlT+leqxoPtriWVoaA58XI0srcjLsdTrlekFkpxfY0ZCM+cmqe8TA2E7IWZR2rlKlVsPlCGlCoSmOW1YYV2KM01LEgJPmhUYd+hQFoZB6JIvVIN05JkXxbz6amZNB586vSUP8tyDzeppHyTdYksIVhIEU9GQwBsOoaDrwhD0wszU4DapU3XUHMG2fc0axjhnf2cifCWW8+6uWzeVTyVto1gcpZPJBzl1fz82jwvV8CyQ54bkpp3SmM0Sc2j1CLrkXe7Nbq3ZGtyWaY9RMbYksgknHxcqkzMPXbecDRVpW5nllTu9duq8JwqS02sKvv/VmLAcxrcBK6QOf4j7ue8FPt9NJ3/KUTARxw3TZZJChCptuZMawe4VZCpcZV2m5n+CR2DTqFYIzrP0Z4leLtwpA+1S9A8j6/rRT1pmB6bcgc4dyXsZdJ7pcrcIYTTr0fsTOE2a5NvBG1JNEN5PnlApEDnQ1x5loJfuHcksARsUJ69BEf5jiRE840fLdEaE+trYDl3F/4Unb3CJSrY/jy6rMviIog/pEAEB4oMUpCnXzF1v0N1SrwkoJlb811KpAMmjLyGL7Z+SXb+yJH9CdwItFso4BEjAm7cOeki2YvjC4K7SOVFlaOQMySDcmLv3vRNkp1+YLmc/SClC2nc93x8cfLIOIUzuaik9HgcfQ1M5RW9jkqFkw9yjDBOxN+h+wjSJvXj6DjbFPXOJSZdN6TAjHuqjh9IUjnJciaWT9lvpHVNEWUJ1CD8RKpxH76qnFCdvGLzKvjqLsNGFXqYuCDiAqg/wPOuCpZAmYPeDr4eSdCL+Xg7KqRBk/wuRrmwOSrQ+3tTWNhxVKBmHFtIZ7xooWpt0QMc2sWFkaNF4AUsWowvriOPEEjeE2rs+M1AksCyViSyM9WOJG9qRZKgI5JYzUhyRTuSKJ5CGjeNwAqn9wYVhQWVOEcnH03JHd6NPRq1xR2s+b39DTPeBbOroju7cgvtjlvtkgqPOIJ/vb7vRbXYdq+3DHCvVNdFBfUH0njgmJI8X93mHqMu9y9wOY8ROn8u9oOTkdTwo+9vkFFci2zutSy1GzInNvlZlQ9f9LAHHdqyd/Oint5N44pR0qB2s2XxzAeesRB2Y6DXffPu50eN8zu6NuflF/oyF14c9Wy4iwf72cbxzt5K2HNhBMv28bv4K9i074P06qTetEInKdEwPqptSFdts7KpsOG8dmUzy5LlfDjLDa87NgIIyXFJN9GHR/94TZqPcFbcpg3JkRZtCJIryviGAhnEIWy6g1foFKBfuUQL6SdwuWqZ7dbKoIrdE5VGQiXoLIye16yK/CVIhJCoLCqaJXJr2UPZAW6xitV4mmY5ko/kRHEmKf0M/E4NTJ0Vt5QuhENLChxqoCAA2YgoRiOfkGuEfh/Mh0wHeD8j3rhbsEylWVadRvl6MVZK2+9iNIpBrmCEfIqskPpXFFKBxWTAhXQ+TcsoWkP5gcdqqDgtrgpicHZYReklDDeIJgWZjAxGBFSBasHKyZh1CB0cIy3M37WUYST8BWi9rpmSIbXJSvCf9FwmJCvJYcyULNUsMsPqMi+d6qjL3KTDAdWIQFY8/q/8g0CjeBW6cl+O/QcQAEjJwaPH/KjZhgsbKDyassn93HrXbDjq2qE7gstsGZwUwf42cfckcqqIzJT+E5dJKePTJiqEOmgx+myNfkiHg5HScpN6mX5IugEBLCkPwvdWW0Q1TabmVQwP16u0fbecRIHw6OBgBadvKYh6dSCUY506KmnEiaXpuXqqG+abnqBDZM10MoE7ASAA4K/TTuPNwNt7oohkXJ34c8D9kopftvV4wpScipdwkxlTQ0NJOs8EBfJ00Uz7jnSJqAJAULEry4Fp6XNnVR0hOws+ZHIBpU8NDDtL6VNBnqzqPlL+U0oiBXVLqpoGDSPI1b/PhpSquHJgBUNLjlgl5mZ2Jq95mSDrpWeTGu2ugOoZfKqkavusveIpqv5ZxYW/ItV3FZB30sgiZizdlk1aDKD2gOdIut74BNSQfckSJQ3/r+Ync2rGN4niJJWHBrOpYA5QWC+lPBkdK1uxJdXbU3CJe/oecFy4ezyX5w6quWxKBCDB9PckK8cwB0HDMae46l7UAPBZQ8IJw+WbhubTd+GmpWYzsIjc/9e8AZ4sCm37wpgMzS6lkN+qbTzAYxGb4LDr+1tURx2+St2xtsnlCsTbztO4vx8rKSfErTk9DeW+booGtE8eBw/NhQ56e+Sgmjqhc0aXh5FNjvXLDsdaHj4Tp+NRtemAgZvyNM911NAFJUGDC6Y7XPCvIxcEWAMv6RBQAAUXvq4syiAF11Xunk7nqe9bWa30Os17sYOTbA4Risi56Mz7EjBcfQAolzsRrEaOVJNNs28RoxiB0uhZltvtKm3Vgraj8ANyK7fLib5HSHY1PWysCio+uV9HlOp0AvK/8uEH9UurbulJq+SBLjPf3mxdOPMB7Tzq1s4Y9UI9o40YoTiSRd8hDE9GMzwp4PWCgzTOHTWf+mSnS53/3GO9DtX44FYpFRdrByfamPga90vgWy5FcKIsDZQHD7kOHKepkRhq65W7OHFpztUCNa6zvhYFtXl0VLG2znj2Ik+KCHK9gO/sfomsOcnYcMUWZW2Ta7cafR/Kiks9jbLs1vaTSaCkgJWhPwB4a2coJTH2RA0KmYO/M46YdQxK1imFREhhvMp9ggnsFfNIMQpy0gILZuPnqi+rHsYDvECJWWgbChA1TLM9OUXzBXIFB1IjFIW6LOhIt7G+BNpucNOCIEe1ktmU7ideTwty8NBiX02mrGxoCn1VT8qBKsWBSwK+BmZJcNMJ5+G03yUL35z2gblDuaXJFG2TQINIodxPsuDAJzXw1sIstyeU+JpZsk+zM3quEhEJShKSfSshWuKnZPzcrqLZaFKhvZZw9oDjNmHgh0to4gwYJOiWTVyCzrPUOIbmlw6+bjuhoydvTKt+zrFsjfa+LFlH+BKvoV9BdlTXSMQp1+5XeYxfeHDwUdANpFuURAlnEjy+zVwLTIdCU0UQqy6XYxX6X7pUBNvKJvVeYZOoSWAMpR7YVTWywWS7bmTMfWHlCNZCsat2xKYUXII2O9ZHKQU7NAW/wNF+P1X00jdrmJS8BX/5CmgJktcM1BJ8S0ddyIJaZ2GIF8LKMJwjtzoSqcn6VAqQXNrQODp8wdeSGFT9pmYJRCU6JEuKKlUs4eDGAxUGL2X130eb9Z/gIntvVYBx23XiYQ0Y7Nt/StCsAmnn49FDtA5+zPzlbGh7vp2qDLjjW5fKxeF+a+rF7d1eLGoYxbhRXObJ4xqZq4e+1JSSw4dNz9u5ltzLRmgV/NVOTf5+jtFGGpHInKLIqjJAL+fVA2Xm3rvtCCWMN+nYY2N/FvvW6Epz1DXqLEZVorCU7PYNWrlXqqjju6XmRm9c7TD47ER6Ds93Zv3I+pS4VZyCsyx5VNSyrT133ugt0h0GpKlt82tU9aG5Nc31ddaOIjzzFkzv8TL+vp2Cf2S0bnufiNTVP6ce9U/Mo14e+yrh2x41MtsUK8O2dy3/wNDEV+SkeR15w84oqm4cyvOesC1DVuPbJ80lJ4fktqKF2yDHrG9DoXUCfJXent+Hr5qx02NPgkrPxzffnqGLsAx7112Epy3W1fUBF2uU00mUdDVEtdXaMDOyxtCMzYsyg+WQlp03IjP7W5p5olJrmvmclplTQcpVlM1mvonfs7InNPOzp8+++pQBdyhL365cIWsPOVpvSqhzao86+jd33YqNxdpSXuMgvxZdkm7XJVkKM7Q1omaXpyIR9QVInmDUbmDzCt89biBoZYEnm0LQeh4ESv53WzTZkLfejjUGT97t+P7BmoND3YTFQzsTHbzhpMWoPjA0vGlgSJoYTofwQyfiFl2EDNHdkCHaDz35x++I8mBYWaLW9szDRqI1uHGwCFHj2SOTGOw7/SC2XfY39g+nO3T6J4i/7LdJ0e/h7oFWwoOgk/Uiighu6WSFdXGViixV6s3WB3qth0QmJNtusYSNvZVmZyV8UAy7g/5cc0c1bKg0gT5CW3Khpf7piWhnVuomCYRwHhb2WvDuRDgvay+q5vkcZCyJQGE3Ki+ocYP2Q/TrsmtZ0UQ1yUR4KGgGqCCoBSDoJiDD+AG0RuSEaKjQ2AHhUJy7C/lEPMHJkqva+LxRmEkrGlg03ABPlaN/KYS6BNxTL7mcI39NXsBhJ9CoGxrraWDPMQHug4QtF6hb3oAhJvon+IIc61XwIuBCUOPB8dqzb+9iriCZFOBDZXbiFFYsC/mJ0+s12ocz8Z2wi2jR5TFH2fgYvgAvof9S84FAViF6dhPW0AzQRWmMix8CXVISNIR2tUreF49fBMk+W4YAnKThHKuOWp1YWjl1QQ9EU8JLApV3xDaqUdBq779Iy8Do89hb+j8Yna6vvILyTJ3c9ZVtxS+6Eb1/vxvrKcpQ3AXZQfIVJ4es4OuDpXT+vZvNdhKJmAxL0hXynfCM7GyFfDv79Vsb//QomP3n7XBt/CcDbfjM3+aq+NMG2/ZXffY2po9/m/sFjEz3Nh4DXcxXjb23sd0JHHov47KevYzrRqKTSQ4y1hN7Fi/+60QsXnxvsFU2/mnI3YrZ418GBpSPXRx7fuwdkKBgUZUh0ejZEibZ3L05WF/rPFT0sYYvhvMBlmZQ8wYGP1ktCPxuB1eDdrmj8Pp+r2TJomDq5WN5MTcxOZGX4jMQGrWrjjPl6gETk8uakFdxIdkD0MlbPctABuKlvgJIlzrjY63hpc5EAfMIL1e1XsBla7O13Pd2Kd4yyicacM8FRxcG5TYvWTpvusDU81wql+JkW5Qkgbc0URMsN6HYsoz0VNZU3JSCYXiTnJ0yPEtVpgIJmavjp5Akcwa+gE6ubkdl6iQDovJ3un3kvE0+8iUr7yATVRLtuPwtADpI7Hzcru8CYzQGEqE9wowzTCRpzRKK0K6FSahHD7Tory0fYVqkzT1tL9lMXKtkHG0ghhjq0gYSADgSwSSxgqpmffJNqTmkrOBnQM6a8RP0clNLBnJaI4lhUjj40WvAr8hBlO/S7J5lvEHg8uTKHWgGcZFk0MY7CTnyFEKOETRDlEIxFQ9TXD9Jc9xPks8wHI5BYTjo7oJj6Ky9GHp2ZMnP1csT1TBLxk/6sX46QpXtdYRqDqhEkf2thzpCNyQOHN0vffqUa+rk0wjGe6AidAUYOo+gvHgThk1UR6jTXIEUJdB8VQhtfoh02FzqsrhPhtYUqvVn45VoGhZ0kbPWktSs63CmlUlyzdmolJLUZCqt262mwRo/YjUKDG4ETYOf3zR3giwOJynUl5SXbOJg3Xg7x134FHI/wl1P8qHlUoWK+4rM6YWm2SLT/0fb8hNTTcPXKo2rhxIU+s7lnay853ay8qpnoErupvCdsSeMo8SpmEeZcb/OXw3jngYNoT/HZveHxzAuKsPdkI0Yiou329znYnHAb5obCDNje3NL9LOH7IKCBFffjop3463MDe5PuBvgBhCjRumWKcIN1guS1eUGn2u7QaYQuYGkW0l74xWjSkp8YBgu3jnAa0/HIrtxFBF8AtyJOvAHF4Bd+zbgi6MIvnfbCL6EkOr1xPB286FKNW1tBOJm0h2S6oarMCHXRhi4Q3wo4+Sts1UafAbVIhquUSuLCNgv8SctDcWo7qPLI9EALSeBhkvo2BrRGCs+AbEIaHJc3zVUilmk4RpoDN+3eHIHPaCGu6QnxHW0JxQw26YSuF9tW00DlhtfJwnf901Vi288f+kaQlY4cOLK+XyK52yjlHM8X88a3D+SzxELOoy6YeQtLp1PccHEQpqQjyuVCtLiyYVFs/FkrVSpYExEIZCEOwvjt0YGSVSw5GUACZ/x/+//xWUxuWJYoGuBiMu5ejkfYPqPhtHiSvLmfzYmKsg3TG1qz1zjh4nDZx2Svpw9sL7skC/jyE4c/wq/CDtROdoPxj4Kyfi+R1aqRLy4A+JxJ4MuDjcbgXRx+Gzi4UUvCB9EOVZEw8sPWVEdwTfGW6PDC2ALDu885vegX4W5KKKfNzmdwwapzX8lOUnPc4epl6GNA9krumn45TanLk2jVB/KOYMYebNGFyHv0FXWfg8XkgcmHW6V+gPhLif1diB/Q+aUzkCezqbV77RP8NxSRyD/pxa1rlGpTZiAhl7e5uftFXuKJy6Br16hddLzbrx86Aps3tLirvkbu26cQdyqeUZMRKD/XnSLPxK3+D9gC+4LY93j/HByIJv49cNUbhuufWkYoQ9+/Pv++BBLJ9xTuwn5z6MfIYdfyif7pwEbd227qjIxZmawcfl2+iDch7pC/aGmdBi0TLdKFpQE0HEb7xks+/G6durAI+O/k/sJACW3gI3ptWPl+7QNDTaftVFIdieRJ1I65tYlw7OMXory+9Eze2D4fGCu4twAwl0u7iM6dJYA59AEHuwIR3aWxD+NxCcvnRqGc7dYLqghCP+mrrz/MEvTSZiy4xbfc/xuXgNa9XGox/+OEvXQ1HqEg53fFBOGY+TcLdk4t+NUc9f6VX3Ys9wdANCU3oZBcePulljcZzaJxb1zCwHzrcTiOiXMD0bHmfwAJz1zWn64Q5ztPPtrYWnYw6d4Ryef4hMad+xMJ448p310abH+Hzi68djTsBB9Y+zWsQ/vCtWXHkip1pENdh/Umk/5DBjD2uhnVs9nfNh7a0a1R/BS7zElc0Yx68d3WHP7pDyj9OVSm5zfY+jlSsXY8mw+7nlUyTlfrdkU+gL2iDj3K4AJngE4HvbR15rPNBkeu47nJQVry9FodyDHRHJlstp1vLe0oi+xRLrZByGfnj/fY2dHySfY4eHDiV4mm+Rfzs2cP+NUrE1sEnd3sUmsPGSe3JBabR3NcPZnnDHXrqvJK0nj6Qhc3MMJmaRPE4OibLnuvkKvTU22ItkttF3B9SONIOSWyGTHW4PAeWRkrcP0NhetlwfgN0FEewBDbNA97yng1V4FYeo300EB3cbulymzXceg7zYldiml1sNdCyGLeTaDDyeDrP51h+N/IKEFVtar5JNk/ny3M3TxNn34yaTLv4Dse+zs1uuPSxct/1F0VjLVTDpOx2944nsIZumQDme17duGYXYgF5GXk8a1N5Lnc//G0Q6kq4DPEnwnRtJ9SuZIKxexCwkaWfpsLq42w9xf5SsGJo0iup5p7FSlbXSY8NNbG/dtS+HwDD1QycLiQstwC2j83w4esb/YznDsL0cyXHQqmoajphxrQ7/Dnp9o2dOzN9nz+QPteXOnPYVOc6ounaBy3xpvyafSMvT3OYo6sOVU0kS5pHv2NcH+rIhWPa2xMHMMDe10GTpavJ+nWxG5bMD/aaaoAz2hkwAN7cAUYXOsqJkbh0bYrz9KAYize2ZR0XrHPxMd1bfEPgJczadPymEdfeNmctA6zck41M8ZaWO51mcJ+SfDHXorP+jQr2x36O/73ohrNJduuSKz1hEYYjm0B36MIf7NWMW6revahAmKpOPSFJpm7Z/PhEzC/a5TANHr4HQJs96w87FykF/teoGPrlKPXqT/2LxIfSuFMrJ5jeYCCBPTzNUG84mTaSY2nffj8ehyDbAotPENjBSSrctVnzBwJ6oq1nV9PJXnsI+LOXQK0Euktyr3/PBSpV1F61D9FV21QWSh/+rIPsl0R1Mi4GRdS/ZetcDUzMtKwknIcSWwjRpaV7pvR6+ogYVXyOXuHgstTUjk3D/iJfgl939g5n167NnQXuk2zba9hU2m4RlNbDjpZStPUU0RUTRPrs4QkR1cVnYsr4AKWKJ2YAnN37Tt0HH4WAXxpN4Kom2HMMhWC25lYcXCAitFpHGg+rbNKUvX6TSltHdpuRDMaCoB0Q5sBVFRZgLuJu4P6SlinV07yLk3t09RvNXZLaRMJ4kjymXgqZjGNVu7jRdgSJPy02kKxy6ek3GrKqghCgYYJa4Ey6tdB1iNbyBxJ0cJzeFZvKSrHFOxM2PPRGLzdtyTg+OlMEwwxIi0ucextgtbHB3x8D/6x8PGo7cLeZ9dvghtt+Z2BscH5z/wvPGWM24ZKvzFtwlvjXWO82fy0fIFdu8HrF58dODqxa+aEY4a9nvMsA+OvTH297gGP9cru3uAcqjiSABQigp7gI0kyhsHr1jZWqZ3LHcZpkHXzoqu6uyz/RWZv2TGnrNAgtDPirO+QMHrr95apPcp43hT4zvbduZIqekfTjedC/i02Px2axsjG3O3YHzh/ncMH9t4xmC+mF913o1F/Ag/Rkh4FCgJnx4FYBpSmcF6rdtd6jMWs1YEZj0eSpkROpawnGwP3ykxDOC2bOTTUUZ+ZuZMN6rL2eJ/2LdJpTxqlAVmFMlCWR+wqCvlajNJFnfVrGQkGm+1iilTZ9UlN5eZDW8//5yXHp0474zD5GywpjSeBKEz7tKoflRZ+fjXvd1SaGi17rpWdYg2DRqmbyOSnvI8k9mNXnVpoApZwUkXBlIJ8jCSyObS0sNYf+SrwB+JscnYU8PrrDYcRFbYHcwD3wVS4H42GEC7cft4KIbfNHEIq71w2is3w2nvlZ253YArHO7EGHAxC+iRvWhI/QFdZQ1RRHjY1U76PaNjpiRGLUaka+FQqUXKv9b8rDVvWl9jTeP1vSEm6AgJZ1ZByEWT9NqAXPanSMZCnIQ0IZ2IE/IVLBqDgM7KESdrmhm6fZ5O4UajVpWh0WTL8bhZTspq4NjoS2HQQOGrGjMu3iPyeP7gjgfKF8IgtGbmMYB2Vc52FaByeSbogZdBruHrQIZSKDCWhYmxA2wK+2sKTvkDgAbUjFHkUrZV0YErrgP4YGMXm1N8WhDERbuUiDt22oGjQW4Cf+EA3UaBqvi2qitjIkeXpVVbtYrOB4HxVZOyjpiJJWzgfOFjbsFf2bviQ3EuWXeTs76C3yYBdQwhAZ2qPlCW8vZQFtYtB5RlXwhlQatNAXxlFaRFcxh8vY4tbAyJP6E8ROhphowx6IHTKCh2wLcNwrxz0YiHyWmtPTatN2daTTbXrTEr3HXDAE5OM9D9TRVVhvg06YqnEiStAjBgooDx9bxn5QXBLdWN2qGSA5B7klNTthpwt4aqkLg0HDEaUQlpw64ktsSq/HwopMmVou1NTZQMH7el43mqXc5aoGecde20UVzM+XOZZBFtiPoDZtx8tRTwuhfnbro80neEFk1z5ATUeWvW2YtQYVb7V2a18wEt/BAjkmehd5Up9UwiH5qkFT7CJ7ja16IkBTdSB8SwZa8iiay1QGon3KTk53LOSJqaYJRdJPj0rrMfWJpE16sw6RgTtQnDzyLtg76ukTJUF4dO8R0D7Quw3PrSYd2Fdlyhql258bWTYnVNNiHfA5Q9MBVARvjqpQaKc7uUSiEX4njFyfmPAlGGAi6DoqVnLbA60xF2ANUh9f5W4NopNa4+/tcnyytUiEyucI3YPsiPvBQ7eG1zhvOHaBNjkEndzQULsx6tWMotBUq3eza9SSm2097VyaaZSraWYbymYjZnTTEzeapbt6xCZKaDJSdTyvmcmoOZXtYlAtypL0LOaulNlhmkAVzGTHWIARoKiSa+COMt7Nxw1IjktPbzt+fB7AhRSACCLWfBNUtW9kiSGiCvS0b94hmvVAe0hBqgcXs1eFlHNQL1yBxVj2zWKuS710Qqggyg8LBugMK1XNs0Yow//ivgyJag53UG0Np/2rNesSMgGD/yYR0GOMa9chcwXzfs8HC+cTuo2PyoMK8DOzh6zx4GGoYsWEE1SmNwLfZQLM38dW8tujXmgz/xQXaI8vPUIcAdtZMSYzc+s23N6WwH5iDXnZQQ23jJQPwH84l7mE+sAgz8NkqlLeyAHvTEO8gwmi7c0QHaLa8m+qZu+sbXT4q3NLQu5ZbFtcUO5RZu6ZwHnb3UqdJyfn6p3VjP4PooOMlmY/2ypkbLtSfHed7aT5+F+c23md+4sfOwOn1b7z7PiY8aPSs+q5tXecyTYuEXb17y6dnnMU+Ovd7WveaDMtzGmuRvIPq8TC1UC/G589yqXbU7sboM6cGgQs3GBiulSXPdp4n/YdX5+mFhvasIjwrzSLo56li2y3C+GC5wdVT/3K/R7QNtr6/yx6DDqfmqj6KZVz07MALxGNCiSV1T4xs/J9gTpPQRKESNAiBtio4FLHzqZvJZqB2y4hl9FF6wFSovD6kPERyveI2WzwoeEtF0ldACHPW6kSFWysA1G6TOyu4zlVSFNoEaG8GSYSsJezHg7m+UC0FcsIJz5t7xeaNWTaOo12ozM1bjGhJkk2BYUVCJ00IZk5MUKmWusGdlrhJHBoCi+I6wKBbhc6yvyFPKuISSNmYeMxNVxfM+n0z7lCBPaxbjM0a9yBLhr6FBFQeZ05OofGoHiBfHAKzPTXhlfwwvjsbKJhAvTb46lfnqe+vNorgtzTe5KedeCc9YjnSf1YXIEbift5G6YGgyaupAoC429X25E6p7VVeizG+tw/ckQGKVZFYx8qYCI8ieix6NxbNmRMLOOkYgxK18WXv8Y/B4VZ88sgXGhdaksQMobmM5HdwU+JvF97iW9t4jJcubpCe4krRrSXuynARIKSFnslkZy1mF2Zw/nfELumi88kbNh/+xEdq3uXthUjd2GSCVb+q38TiSkXuA2qTHeskBxhM2R8yLN0dM7pXd5s0ONq9QsTuNu3Gsx3DmlBiZrbzZbNzatoGzOLZhX9NtuIm8K1lomwZbm+0LPRE0jQj6FaxE/h5FHLlhuAsLTUwn8cdLdjYbpWhVkjY1qu3WZtTYXO/+g83G1aZ48X4umKRo2ZBWm61CUjFk9LS8NuaeRtzJ9foMN0kpGpsgS7z503jCqSrvC6A34VmXER22wMCefwIKGkpCCDTTU715m0PxiXjIl1bKFngTxQDE1LwQrOcBRwTpImVQ5LifIV7S/mSuUjPxXir1wcvmso0BOMIf8l5s5kgOiBV5F93mBFb2dfAkQtyUp33Ox5g5M1elozMvlVKCepBdyzl1JzPnZw6ljIxhT9oqWqUgilwLOMBqwItYPbdi4cs5ZgZkknseMKMFEF8GpEzAH7xS5CW0O5F2PCKZnKdUHwCqyAZvy5l8Qd94C34NjChwpVPAvDeTvl721D9A5MEvRNuspiskEGAl2PFLgNHOgFXjFbgLh5ItHbljuLUyeXh8N2NsuauGVCU9dWdZDPnflvp4caLUxs5iutUEz9oRePZHQ6iPPmYHOcx7qbB4KRQWh6hfCwjLoQECJOzfdSJhn8GMdA9grNRID2dGWuyaSuP+oscj6vOgcx+2eWo7aBrVRpCQ5z7SauBs/HJ6Ho9/IgBphm7BYNRYy6TxtztrGnHusPrwl7UHzi8CabgjMkO5qSzt8mRpl+c/d9Iyeu9A4febO83zmugM3Y1s8ihQxu/dDcqNkWuEdhsPwbAl7kRpT9fojlmrUmV3IyYC3HtbzBun9DJvvLtxfn/mjQ83sXYLr9phFfFu3JWSYoCk2rDsqpqvoRWclHSqRIfkEHQmdj5hxHGLjsjEMbeDk7gvav0lKsa18LIsGi34mudxluuKsk6rCtNS6urawUcjc6HH8EtM+JUq4Xyqqy+7+3FwqNp+R8Kz1RMeOBuvGiDLyi1RWVZy1UiKsuT3dj/OfrHzID+i8fv9yvpbR1aLZUHh+9x/Rs7y5hPsKvxOuF5OvBcs7pDn5UTYuvtObXx6hzwvzLB3chsw7FkY4r8P1QuIPDoUNxhDXdCS3GAG6xbdAPChqbuBz/gT6RefUINswYZgZLKlomGmXFuaKNtFx5otsk9Ss0GHkIarI01k/8wSszO+6Riy954T7ilFM+sgUc2VCmr+QKiSQQw/rexbz6xlgiWOfVI9Z6KllHFqweVcLWWbeReIbNk7JUM/z5HaCc/G6DXwbe6b0cn+fbpUdGKvgU3VcW1zrXriz/HGf/eUw/7mEvUknNlnb6qClzcVpVT98r94E62FxdiFULCI1bx233TVnmSAB1ZDrjQHO+tNWJJvBxTz1AV06QA8ibUT1vO7CuVYCrTk2NIXCaSPbDDBgTAxqyzQqlH1gBQp21iZf7MIrRjTkWEl+D8A6iEqit/48YnqBl6VLgSmhzZrtpBLELDxaZ7pTIODj/y1ntVRgzooPgtgjLK5xp6P6DKmiG4qp3P3U/PZlASVCIr2F85/8Vm/ziy+58Q2CuMx//g3ke4LyMGfguWKT+1yFj5ED6nW3aNaZSD7JhfUantQi97I+kHSpG2CM9j0vDeXCAFJPhhf4z6zC8R4b+joOWXDnlOd9ZwgMZnr6TnV0M6CghfUZNgQPmlPAWhHo4NQtQjgSoWiJcWhfz1PWyBJO6uIlPhSVSQQO2BoHIdg2IjpenWkDtSraYsLuULY4rqJgFwxj8BBQX+nsXZX3I26XeDFsHUEEfS5ykLjUyyGxHkFfKvolZHC3N750F++BUSZwIL4bRR5U9tJDlX77bnIWTtMrhqnjdSLrI/vFx/aYa51wUgO8uIuB3lhp4M8cJCDvHGTg0ysHVmrocGpYHX4X3CXPJeC0080UjPZgmqSrZCa7uCd43Bc1brSeDjPAmGqKF2vkc92ATRTuwbQBHoxQmiyOwXAyVQHQPOWPmvLlwZpgTZWqSpgIlfIJ8jFbgH9TPYC0qei3gnOLDFwZmEMcObbO8GZHBU9ZOjMmYfObIHNxNJ8v+3nmaUFA2LR4HtVQmlA1g40TynTHTL8ZnjVoq/S/5RX4UkSdoZ+Bd7/36fXEmHJRneKB+lS/F9vnrhNm7WVQVZE6o/cWvR5u21HRq9NiNQiBGavcJ+ljLbQWjRMz0Q7Gc/WKBTSCJ29KaWyXSYq2xLPQ6QxSKNTWCtnkXFQSzg+Eoe0TLOZuCQXndJGY4eFiz2boaZvly7cPZKHeTSuAd1xRBmqfJqh5gmWQOXedFQYnMJqwKJrmsV6gnMAliuChSJJtVjyKmcTcDXKGriR22kxk5miHdJWMYOENnX8h9j64GMPQwvhY6zWHCUL7aRg7sxCg81JqNubGrdzYOqvvte6tg6RrkSaUhzZkbx8b/r8i1FyU8uOI4KEuSle12W6OKsZek9i+rcdWfIiz2hqMBgRMH1Dnox0Op8EXzqy6dM734cFXuA8RV3VdNNReJpFo8LJIIv+5yFy0/d15aaIUnE+yk0f3ZGbBtlsojszBckrzZqLNGt+aJg1g/odO6dGlDdfw5JsieXYb+QQtKI3P+Tj5/3RWY3fZBZ96HNj0NSTWSOwUHKFFPdLUAQ/BkVoOGKj2kTN4dl6vV1ZhjK1PNOfFee5BUK2o1kIJls7oNibAfYYzCY/d+cyzoyKFexE4UBFnbC9gKP07/oiiMJwlgHJWFrdG+BJKb6Zz6WUvyJTm0gVvtRFqnDVI3GLgJCnUvRJanp6OnAq5Fx7IiFoVO/Tk6uHC3LFdoNCNpiDpqYgQag2k0lJKfyUWb1cKkAJQ3OUdzQ+1o9PgeOeGy50Ej3r3EgHSUyRha7ez8QO4sndFj47I4TGb/302n+4KD9cIFG8FAYLU++NTiETNZeG4034gVvLyK5jSwlCH/RpFTWPTnn4oPdYgUn50xIIIUcnNFuUzfyq6+11LwWvmA1qGjJIwXxvIYtlTyZFXh+KN+FnekFg2YHmO5aUPRBIaQ27L+BIRUIfFzOYTerAeBf2FkAfB+dP22bRPlWVExpnV68Pl6qTraVqr6UBXQB4C59O2OT27SgTmB7zPTDXbGwWmoG30juUDyUl2HNjt19IY5Ck047DXAjZweK8G6oth+z0ob5ffT1i1GUrnN5KOCsDb0wrx1+N7txQxSIk8WlX8wyfT82Pq/FdZsbTbDt/sHjOrWf/BUAy2LTyPOgurD9m1c5V7EA9VDurXLMhf4B8AbqP8Y17vDxU/TArlow9wCexzTnbTOsP+8DDzInGA5ERa6VyAXkYSRZKcv3CuiCUatUEFWHmspnkvOWfgqU5JP2VYOKM0mX1+5EnI9v2LDtD2emJaNnehAh2J+6gmzWxSbUQYOTc+D7v54pAt9NaDGoglWMl1ZZVMOv46YwWl+gCIQx0m4g8DiT7lqiIZjGfVsoHynlZt9w4SjlkhWo68CZVeyKQU2kfN729GpxWWG+dpr2xwyBjes8wp4nfldM0FpfFtmcM+4/0EI15ytyx2Cw4Z8vjB2CHEx2/BJ379T2AT+zLcHEsOoDz4IF67vBkFgy+871W6LyVspacrOBJhgJlrw8BmT4p8XXjw0MAsy/afkv3xEfgxpXd+7+9y73PGriey5zi7pZTPAc6ZyfPKQZ1x+mw9OTY+l17L6ECT5fuHSD0dBIM+W8ze7OykF5daMo6WVjBQvvIMlDNE9FmV+ld3H3oe50CRfpXNO3UThz5I6QraWyG62bWSE0kJCmEILxWezdDvSAkIyeoMFdYZzXatGaEt8tBeCVXywxMFN7bv/IglFZP2xM0sZSMVJCxHkAXylRtxkwaaD2oCVdBgpnGzqOseEY2lZSfDxOZtDGB5gLAWqm8QSVgEhk1MHWmawR2yqdyldlJMVwEtSDJnqzQVclby56qYRdMrliNqzTLkXyBkxVnktzhl1wbd61qaqkgKdvZdNq8mt15YeLp1iwgsLxcruhrE7WygmvYU16M3Xz3u+GyZi7qF3TtaraoDRtPYLpGM3M1XrOFeODEJ/ZMgcdBCjIZ2UKkiPNqwcoB2EVTe6wFEt7HAtjjkO90FH2DMvzOE4WnK0R5EaVMiGhGZglVZi+QTrkC8E2ihQQcAXnJWnJPABfFkWkm+TgvOd20Wkk+uOAJAODsvCAl8M1cJpAbq8E0JghGuNc+a9Wgw7CwbE16da+OeMeZIbUIDSHp3OL8Ihes+VMesg67zhJ9+rSrRwpy0XScwHcmms87a4G0ZfLsevtp300Ahp40GNmwmk6GXCK5wynKJUIiMhFnFgwy7BFSHc8ZoExf06UaPJTCnL+9aDA/RojrEAD+4hAScgP1f784ToRr6flKZw9UizuXHyjn+9pxYhvLIO9mtlqOXUc1UMhoLC21MSxBtmd44W6nyrmd1CwDdXMbZ4x15bx7CGYXUgInSznX5GQpDOJk+ZdxTNO4qA2we3gno0uWMrqwQ0alTSug4viz0aVyAVsEiIkR3A7id8EXpIxHndn7OCXGTvRvuQC/ky9X6mWpn91DIVKurYF75ngVRmnbrNzIWuye4+Ia2lpJnfU9BCXha6Yl0AyNM/JGW9r2rvFqCXZKv89O6fmxF1Jz9zL2DBNZt6TpGSdd5IfI+Dcx82wfcV+3Zbr+mnFO9uXb5vpmdx6+bxv9zl4OHnWss37F4CyfHvZPMfvfH8IJLEZLQcfQlI2cGLxp87D0CBnsF+PEbwRnmOshtSNVLQ8wCB2GfkbzLcNXvD2zk2bnGPTopFFNDrb9mLG7yHFnHsjsyVEyuRyddl4vYU9ESeiFfFpqzTmTSn4up7rGhf3t+9Wx71N6Uguox54B7cexqrHdUeX9zTjP9ZO7o7T7g7FOx3WhqO7CwEO5sI2ornf8a+wEPRwYlQ/SCFpvmeQAmaxGayvrB7hhnvcBEhkspKvKEUY+Hp1H1qckY9jdpcIlK3QQQEno61jCqoOYRPRvtesylbRMYAYLzsc1DR2lhIjVJ+N9Q5joNqjMqiqEvTRIc2tVjeqYFFTM1wxOVWb8dK5x2ziegmIvEY9/CwAFXfgzDcMmMg2GMde1wfrBnUE8DbMsDTXuIBseQsyP+5gx0GkS4YA3os1R0PTM6qpM/2V+LD86j5OJQCxd9bhQ+jZBQaWl4/8OmqpqrBy7PHYTls3ZOI0xcC1tAqSFeDSyg7qdZ5CAyJ1C7rMowUKfBbxptL6hiLSGgDJKNxkDl8QYuHIh1kxoGF4OWIyUVQV4A5V6kExbF9BKXdGmoZtHK3XJla3AT4P9QVZcA+q58vPw2My/MHKapmFbEbPQF3p7TFkyDKfu5ks+5oMTOXSwFX7ymEQlh7mQk4u7GrE7kFBjWP5ccOFbzvpNsEC+45Ucu4wS3VBTgS9bmVTKfFjSwxYBLRlLgZuxMIam8se+VpkoYTiku8rNpqY6jW8QcIAGPq0d4xgMa5QWjdqVvDo/g96IHrhvwmgoDkt8HuuJAfRD6Mbpp0bLanvazEPCe0NbCmuMf44N4RlMv3V6KQ8QjQjV0IRhUd/hJNhVXpvcBFzEDtWHx+o+XwdUmZouanaNjvNVOs5PYZyfCMf5/qzPgKXlSaN+sHyDWrC1gDzfmzGtrFPz4ilAzDSiuFqxQAldM3vA6SGBz83IYilNlHwX+3bXQgu3jim9LFP4KXAaSc1OixRxXxu+JU2+gB2xbDqpWAVbxEZJQvcMfCnDNnQXyZRPyXtQqaq5udJVioUEp8AhC0xn6fo6BatUVQnCSBqy5lD5gvIearaM7coE/4ei5BkC80dsBQDVIbQHsHPJH2QWGJDsH7kG/GUZhISvgxJFrEYnpgCa8dtkRrQ1tgVDRC98bCsHmSXUQfxcK8LXqYvM0I9CkFiT0nCgj2BwT57uVguBcLWTz1dS+jYplFutVj17tvHffTyDAm/6eMYt3iz1jLoXz+Sx+SPoulYE1S+fng0dI8G3IwT3uL6O8SVdjKvxI7rnJs1EKsqynhBlWfCCzizLBOrB0ANSEAyrkE0BzuGIpmnLRhKYIF1CQ1AyfM2bDOy076S1uFZcqjxGhb4EXI3XzSBNXQRKo2bGtxPMSQrLYXYMH8F942qYxL2ly0WObnKRxjczNTaoL4I1+Fdoul5MkzG+p423t5Ur9xavbFjfn6PyuBqkMlazX3cE/TqNUlvR6i9BL0yf0v4AFWcq1WMdPbt3Nb7bwUVZ7eSiPPuF5PSE5zvxzb05xzEnDKeUiObwGFQmaIPu/h0Nujc3rupDP8mx9Odb6GqmkJZejRJyrLR0iL4NOnhRuoT0hcKAm+eCLlRF/OkYEv/PiW/XXIjFeCzqz3mAf2x8g1jgVtR0PWcCGmGU7L2P23/kpcfId8cr3gZS704RrOSnHIPSMEkJPQltMdrT5cKlaGaZf8Se8wxuved201rt4M4bpzkDGR4oGuMbBSvJ5Wa2O9ltuzXuA2Pda2M2Zv484anpb62uzF5REUCHjFGMNe9t/AOsGjStWhjh+vrvcUe8bKog4JzZBmXaxZH0dYrCZmO5z+K8lUBi9OTYH1Niq52QGI1xSCW4Bt1BDVa2PooRawAZIDfAnTOSFEDj9eOc5j9Jn33B+XkcRmGLA4uihtoW+cbWagMrI8oAcLlxDvyjWA0jpbNe61Q7eD70WDdeuZXAAHOHu+AOM2DeuDD2LMoruJl5w91lW1fqM3x1s7E3T2gPbp6d/uXumpDI5TOf8/EXdRvxns3dgWtn1otaIr9vYWE9L8v5dfI341jnaQOsc6dlo7GWoENZVFWiw7Dmn+X+CTTMz4W6+G8Za84NRwD9W8KSHx/MEP1bBIxf1ssp/djNnNIbssMYXz8NYysAs93KzN2G6eZD5puQWntvnULbJitiuKG0wjDZ62sdlu2kTKGsKa11Nnp3ix0baKEKXVgHMOSatNUfuFuN/u88Ry+GECMHa3OXli3JhEmQLQiKIadWNRrWCs4tS1cuZw9kA0cUnVTOeogiYboOQLYuybpQpcRVgPVCoE5ghEEwhiqB4cSE1YBnlQQtv5SRTDxrDjmzBvA02gVexTgi4/mbYK5BhUGpS8BNiU/j2ENUuTdzuZyPRJ1o6pyjgbmT437DSXFJFBQRX+KWbAULgQkpI+XKE+B1oaIuidnAcmRyuWhR9IQjOZDQTUwja8VPBpOLaMgrAvIF21QVHixmaHt7dtrUCmdWsHOoprXAlBXKsM9p3pT/AFzkElDeJt28EhS0jUT6XAg/FUy7hQnnF/6850gSiGAy6vm3RcQddwO/PQW0xQt6iDvYDuiu0HYsdmrbItQeJBEdEtsgQhHKfaBF1tHgdpes461NRo5QopYw4iMskhaoHkAnQYdaU9v0HBmIDe+UniMwHJeuhermRL1m+/v2r/sIy6ppU/i9r9fjESfHN/DkKSfHG38rnBzdNqFhuNsib92FHb/n7ZCC408G2ewk0G5Uuiw4+3szm+wXB1H+97ivYf3qwYiSH4r9EMVi5/Yd22za24x4zUhHad023WesAdMMfd33KK3C3VBxFfxvUcyLkIUhMz77YpTgHmRT0YoDgMQU/jG5TnVFkge4MsoUVCvry/hpKBPPJKJ2eZaj4AWSx4iWSUwbLQb2qE+DbwXJJThFtGYRJlR5Mm9YoHcCht5LTYKHBHEH+20a5aoyGTmqKAq6oLmaFqD9SkMn8gcEIwvoIoROu2iDlxF/kXATMqaemuZPUnAv7WkhQ46rYqZIPqmK6PAonkQvUlDqY3asCqkGVY+wpSuoLGzCIBNZRDbQYVNPFATDb9w3PWtQlDDud9QYeI8kwh0RqWUKO+bo1aDiKyVoIBXpPUAuSZSAhE4UlvL55ZKCW1VA4DXQe2WNCVAPi9KSosoeMgjNyOmKregpTXMSDnydrkFMed489ggSIni40wkl8PCdhcbr4rgpgKR2ExMrWlZL4MugH4SfWpCwJaRO7QFAK0Xxy5SQEuH/2jij/BJxS7jsZ43T+wj6piSDzrKgYCEN811wkquiY+JnwJOpXvwsEU1n/Hr4vQRZAZd53fortvb/LbC/8NgYvS72yoirfXTuFTJeGNkitA/HAXuufPhB/cqoW3rKqI3P7zCwDLwMGvVOVpji3N65YgcrzMKZDzhjoTwy1Qp52g7iz6ndN0itOrHpBtn4aF+O15Da5aeRJ7x8/M3h3blOFna0D5xTG2ecCFN/Yqc7vzswZqr7MnlM72ViY5eXGuzU2PXo0X+gZ/C6KIYSU+HwlZRXth2s7rL1SJ9h603dw1bTtfn2vJV8brth6sanT8gxPrVnylqQLOxZsikrcITE072ko9F9sHgym44GqUG2OUid04HWxL30lB0Ye8/gzGHjfc3xqs+xRU2gQiNtlAfxCWhA3xH7LlvCFaNzGSUE4hLLESqroDzsRdoiureO70pbVofAQp4YMl0O+Tb8GVqXpdatztDF9b+Fxko8DukpOU6lTbwJLEoakqZwEM5SE0RzTTWOVxTHN9KyrFgiHIfKhIFjg8PCJepzVU8IcY2XGACIl4D5kVS0Hge+Bw1YTnjxMNIu3CWMOdpwbTXijW7rAmxijSYvUHwUUbwAlrjikWpyPqm6IqcQgccyaLlSVPCKmUbprun5bEbNruYdB2xtq7JLswpJooAtvDdhpR0iEieVDTJJu2xjJrn9+3IH84L66qEEYr4T0lArUouEOhIY6Cfp4UI44n4gCTwj9rfUBXdFOGILb5Po7LG/M0pisqODN8oRWBWGk5143y7ITixt5XMcsDX9XZJmwswf+R0cA+7i3dar4G7t9bNyYSk4vemH5d6/X7LnAuaB4sgnIOk4xt8NqXZROP4V/hJexsD6XbEvxr5Hu8DrVTHcBcDm7wHCyCZYo4K1cnGbcRLt6EY94t9BpwPjPfLwGVpuNbvKNyxgL91AH8Px0Ga8iwN/iZX3aRHzBnOimoHTBEXT9RYe+ITDh5/wwEXld87j/ri0fGqxdGixUFg8VCqeulw6Op/F1rll20XIV6d8GwHVTGFCC+lW105C7E6vpmp7UolEag/3xpPufR8exvsaD9ehvwS2KapZFtfQ+VaP34l9bBlp9DdC8cHQ2iFT9GRIdxA5QE8/u0Vz0MG1lWMbu0XmO/SdW74NjAZeEgU8fCXCaTR5L/A919m3DjvqmBHTfTPWIVhf7U/CghUaOC39ubBLA6KVa3TPQwluCUxsTrIsnWfuoTt42ae3pJ64UKTrW6hPUX1aMoe7E6VpxMtFGXSyK6wDHqd+x95gNd/AsVYA+qhzRKTNVZTSKZVYniG6IIP/lpFFJyAJH0PvwLDm7JCJBEp4ph0q4TU5WMRQCe8ibOHEwWNCOa4TQLgnhEI1HwfKKu4kkho65e9WJ2k7/P1dFAjodQsRA8I1M7rreJq/kr/fVagqLAFvvmurd/rrp6z57L1qNpeRr+M1w+DRrzdNkrTZt349/ZGMZMmN1PDgJJqs6ui3G518LO9q8bEU2vtVgVKZKKuChrsWZGBYclOQ7v157M7fcro3FKH2SLzL5m8n0bthSFpucuew7M2/9VTvTUPwe983kAv6jk6KwicwIMU3wdZBuaA/FPvvXek7n9T7lozGJO0luc/tApP0g0/27ft4Jt4wBAV1fLRmOPeik37xNv5fm8L66QMprB/HVjhA1cD9AsP/D9G4SL0FwSpo+hNMyzxqLXSo1qjY7+xutGb/1IPQ21xeC/pubGNfu7PvHjlbNL5cnYxa+PRbkeG4UUghkY4rtJ8A4ifVhfyGIJN4PK4ISZXDeBITOTOu0DKUU3QKFsADTRAczwU/O5m2SjbZ99jZrbe6ly5axr/zJ6m4ql7MeklQBXmJw3TUFydCPK6yb2GTC4dhToEeNm3VF4GiVFx1SXEMfORaOSkDx4sLbL6Gxo6gOSnbl2VwKGWTaEYDd+dLAmd70zmraHrzbIhJR9edHA7R5vdhyt85q1oVSy2gqY7NaN9NnIk8IWEbU6IhJDDcRLze+Om2DCuRX4Cj7KWxu37H/IKn2tEdmPUm9RUdoVboV2ZwvyQSs/3Cyn6+iZKnb6MC3vCdZlP2t+8638C3RrKW8XjyMb/u2S7hfNua1rG6f4eI/hlFIoADDQEVzFd8cX7vYk3i67N1Pj1lq5hamFYtKQTFqnN540sJqH0jLyTcfb8zjnaL4aHJqKjYmJOSjp2iySmKfkB9ObrrAJSaomU8j63n0wWMmsE871+4X/LJ2DNj74bn7W2Nvru9rI0a7LnRNo322q5EAW5tj225Kfwx/CD0NXetiX8S6V0cOVjEtDm5OkNENuGJFunJV9hACeCBTT6DRDWBXzRBnUYmsiY6yZQCt7GrrgKoUAoQPisROUiQ9UpNB1HQYI0cMEGhJGacPUtKWSWDusVx/96qFtzKwoolu0p+f55WBEa4T0/Vokt7l5YLwYyG7XspFQDJe3ucIXd1esWwuRyvgc6snMoj68G+RmBi7UXBWobEJ4ik5U6pB/OB7kObngjASGQOWPjcyuCW0fV8Lqtd5QTQopnD2EYLvyB8CV9R9rWyh1vItCuOkXEnVlKN50G3OuWHG/nFczJ0Iz9ayL8SWZZdByCYb23luwAAf61rKx9b3jO08z0ZduL7LgNXYQ7YaIj1/F0IYhHZ02R9qEjVtdTPzV8yY89ZcId+C8OzvkA3hgl326Dt/j9ux6wq/GG0mEWdDxj5FIzmeNtGpxYXAKD6XLgIsdVCOeGsicwgNgDuL8aNSEjiMTBWaaCQnCEiD4PYV/CT/Q/QHn88VBhh+TXHKrLdiSMDIPrkmwOChmmaLGhghwoxIymbQTJpjh01Grd2oPvn2uj+1wLdz93YJ0bMTE4GYF9JsRiRYjECbmfl8mV/mCjxe1tEiXO6owSwtIO2A/4dkCAFWOU3xj65O1nIaAd4yBS0NtxeAamfvKM7ZE6aGWIPgRdP9unduHO7BPWd268vfAHrCz7WF94f+9cx1xfIzr2J9Rs7IwUYBrvcd7XHews0vTrhKw/kEztzM+AF4m0vS0QOjUSxr0MLwsZPtl+QqA+/IMH9hU2bpqO7GWKMZXhtN+OYX5spFZ0a5taB6tubvVr0Gl8etFFRA1GNw9voLN4e+3zsS1v2FtlV0nmzdIAFDpGWg7T60UmvLgb9G4utMIeSam/7jQXiNm8toLT5ehcULsfRHiTeC/xwRURWVe3aCix3VGaEr6xyl8clQnfWPDuenDbNgilIsGs67SgCUR1T5a2CqXqBlcXgXrUlgKsl2i8GWC3uoNtiAEhl8EI87BeiF6EnVDchUS54PFU4HN6UUPFPBC0eYqnRfMlgbeoOQda9LFs1Rpg0ol3jCHIT/19l7awLzlpTj3q27EpGmEORP3BsI5/AfSYDhk4ertCFSCD642LpWC1YDkRcazK+nwGsXAX8lXgJNxVuO6OQz2n5UwrYBve9fUlLo+t7aE7DvRNyUnfRGnTT+XQ2BbCEW/ccj74NEDaR3ZO4mWj7CiqrFBgWt9g786cWBa3xjoQl6c0VQO6q4KBBl5ZBpZW532UPu+TcIHko75bXWBOekyQtSLKMCk9PctImRTdxpxA2CvkqpG7F2CRTIxgOhv87MTHhfjYYld94ym9xHLLai8u/cjMu/17ZSf4ODUFwn60c/wz0qXkoTL079hmWCp20+QWNMvVWlBluesHKZ1ojbwk9X0jE3ZMzraCBBZi2Zw45qeCuFLELbGUlk+9GOJEb3WnjJI4lEjS+uOyNlXM+yIYSN3UOJfKlbPdQ4tkyYo1tFs4s+/tO2QL9voIpRBb+89zYW2MfP7n+0/k2d5NQ6VrHli66Lr8zfhO+x8h9rr0kQabn4UGl1pIE/c+Pf0fcpf2+yjmN97Q3LI5VDpf9bHPDIptP879u+8lpZ5za6yfToG9zmZ/cESYzPX7SVG0+UWEmzGRGRNCSYH2w66zInIt2hN3hOnYOXUhs8QADa1Q6XWdqzJCDi0828qPCb/Pr9V+O4E46HAoDsfJERcuvJM1k250O7270OR4bEbmbJPmntr3s0GkHe71sCWv/x7DLMRe7AZQqMXeZpbR8hKZtSYPXo65fe/N0bZmEmxjtbJWmRHUJAFlw0GI9TfLD4fjiZC8TLRaqKBGtSPGW+Gh5JblOlsOvHd1j+HpmiORgLQT+/7CDUM+nQCRCsf+Cm/YPVIqn5rNlAzJoKIyRK+I2d/WZA6JOfo0ZJholahJNcjSzkZ9a81aYuVK0heaFaAs5IWXVpGkIIdoCf42NVKGhYsEVpQltgyuykrNsbJ2K9NKizRDJLlDVFTGfOXru/SbmHzK38LB6aRpjB9taLC2uzFw0s29fMJd0YIaCNpMgjS8w6hIVU2qk3hF2gjqVhv6EHpLTZmWQJmQ2s9PGacWHaQOWQNYFisohjY9q2lRq/ppFd3Zm0rQdjvNQT0173owHPtfMwdUqyqA8urjn8kYshYr7qbGbo8hB84KodxvtD5ItwK4LpNYUEOGXOiSx6k2Uazhg7odzpdxi6LvQf0Yvl8McedHBFVF85DXZuamZ1EK1Plu9eI+Xz2SIsgmZGm+cJviBQ3hVFl3HwJojxaRSnjtHjFCpQtqwK4k2LjXdxmM1XhHXM36wtjgh8FIwXfRnJjLcj0pPvOARVxNU3MVHrK4+tJzLoPElKhs/phhSD2y5nRjS+3MUPerlEW/i5N7rGH5UoPNriiC9ArApRaPT2n4Y0vnkZDkD75ss+rPVFJZknDKzxDf5M3C2qCWuiT27ryX4zSwZeHgIvoCct+5ol4kqRGhj1shgZsiTzudfHfr5/8n0ck8OJi9dd/sTaEOKi9u4Zac1F1sIBrqGeGpqyS7LqgQQnB/3HERavVJovGiLh/69rR/6ff9TDV7WQX0BBfAchRARekFOoBwg977UnsRuMtUHw6owhanhcRsV5wlc+zmLe7Z4zAIe8ycjh38ImEveF/vEIJdvkVtSsuXW2sDmVW6uJf7Gr0tht2etA/bd90j47bMQkqDgvfxSdZN9cyQUDhv2sOzJz2g05IiiDUkjdeoghOCw9KIm0UvRgXkBWNGA0IQOoZoMdVrQqgluECTWZMc2BRqtAhm/w8ATdUHrLD0EPqDjY1l0HP0Ppwuho6SjVAvaYOsjHLZfK7ZIRw88vTsvsCc93FQSgEaSnjGVjJJ2RMjCiHStWEkrWPKWUtmsQuK6ToETMveDR3afxIs2ncRH82384pPYCfbYCZ4IXuYHrcMtlCaKaI19ZAvvEcEp9o/8Bcx7DsUegRn72yh9aj//8UJnwU0Im+LlA/TvWIcS/4MjSvm7+aFgsU2OnK29I2LJ6XERl26OYbSOip+8tI+3PD2bLl90znIgBcVicG4xmSw+gH4E8aPMdrjWxpuY7UWHmv7VMwc2mz5cHtB67f9TO12eLE/1dYOLC+tuSiwcmp0r5j0vD8aotK3Rj8w6ec5Q6NQnhuh+atxM8LZO4xZhXMqj85e95m0s8ykvlU6l8wHCcQYo/2O8A5T/ZUh2btsdnL8begqLEXQogWM8lP1ra/Uuy65z79gFcP7Vj3qcJF11ZWa6XsfGrSNNnHoJ+dW2Vn+2UC75y3NlnFK/nvcmyylhZEz9XdJTH3fZ1YJhGFMLy6m1B66lGl8YxrDHJg6De6Cag9mSgFhYsJQIS32BWcoDK9dTY68HUvRDrTPZ+aSHOY5C2H0NVjeh+VaClhlnib+yv0XGMEvCN+7QjqTjiCq95uCcvsdz40qsgMHeT7wpnBhILUyefAO1sJ7zrn0rZo502kD95NWRm9y4EwMTEh5Z3ugx3Mbp/U+rrpaQxwJMR0F2GD8roR+UJs41smB0nMYyqFU3ac8+H5AdOkBD7jy1JRQoV7D4fCFoGv64b2x2d7Lpub4LKW6fOHzvDjVgv7J95ttp2htGuIw/ucPFz29c3n0Ln7vDfLiEhYLQlFdCSeD2/vnw6NKYfIcsJjlxRr15h9qX7J+1lS/Jf504I8/sVOHSzLvIMFsKl+Qdu2J1AVb/dmT1PWBaeRolF+yXXm2ivNoFQ7qdjFb74VP9LNv47uplzzrjjGddttr8f+6WsY30fxOnnFWtnrFeqayfUa2edcpEX6vdOHewaijlgyvLB8uqWj5IXrYbT7/xEhusO7ziAdKkYIDLrPEfkTUuZcnuhwdVpWPtYbvjW4/vs3rdz4jfHm8l+7FjG/zcnu3rfha/70c7Wsv+2a64xVO3XMSuYRO/gX2vebDl3kxbgQM6gWudHV/aC0yy9sQ8t2pX7fBj9kab7mfR3axIY2qVIYbpZ7Bis+G3+aomDJnBfyfjTWSDnCmxhp8TePtK+UOZTFFzBKxxUNoUHkTA6JAtZkQN7B2JJGjbfJU/jQNeK8CQ2wb/k+paSehLxU8jCd/3DYjRko3vWIahAWOJL2smAt0IqMqiKDAqLOwuGCnu53GhkDly1rkT8xfNLV4R9vessL93wUxuMRfMBLTBl9eCVJxsPDhzCsbjFQx8Y43jyWXDVhL2YsAdjktxCE8GcdHSphZWkjd/3qhV01i+0abm5uzGAfTygoWrFusXlGgnz/eA2XOKnj+NWOVlDu2lWgGTSH5y6CBdiCnAW0LYVXe7tTLpibSFygbLWzVavcDfqk1bmfQZt+PQzV53cHeW+4KQ7Gy3GmWTSotvbrQinSCqRXreq1qNygj9XX6bBi1Zp71/1nJVo5YrdJSNQt9Wq73oVEnr3wCdYrB/80eEfH6EVu/Gi4dozyZBd3ARC8BnYoT8ypHas1tzEXT1AKWqH1o7/Lg/S4HQk/M8v09DITcci0BXcAzOox+h0bOUT/anF2i8dvjEphEbavcfpL+d0e9Qs3VI9C05AZQEBI7/cstsNXn8nshQpwIA/5KRurdh+6bcbt+eWBO9cot2bjhSJ2e1xqYTJ9hAW/Z46YJhNAPlPrw7lhE6LHNB7I/QHvj7/kXh6Jy6u2Qqfhjmp372/B/5yIOvfvDhLQmhXk30TYRQT9wlw17XyQBVXlxbLHcwQC2d86Czl/qa/t4Oaqjz80ttft2MSekok01iqMua/Lp/vSu+0HhxXyYoIZZCpnuUlzDZvDT2/NifEymCLYcmhP5UmM5O1lsEuMxpcFsuR+DPjiyng8gOkDaxizaOfhWAuLBrHl6eFFYeXbMtKBfmm8vRV3P3Rv+KLkpVxOjNzFnYulSBdhmZb7nYm6LIUwoFay5ZVEOnZD+Nxy50qqQ1S0ulLjq75k9Gh0V7O/ZC8Y/yhDwnP6tlJH514dFGSgGxqgICzuSSCfrMRDEo7QEaXbUShiZiMdRq3KVpRinw9xbyR6rlU/OFlaRfMYIgP4W8In9quXokX9jrByUjRTJgEuUUEZjMrJHSMLo0RWRqGMdbigbZLErJCvJQQf1hQpEDw8jZbhl/TCdnGEkIhFp2zsg5Ztk9Ax/kbedZeiBqcctVaDIMdDEg7FnDP9fGF4QPxw2PfspgjJDOBvYda6FanKltIe6AVc7wMgA/UhQ99wN7KnvgnKsXF+gnWLM3i0tz+9LLyVTNzWKuBSdmWwAbLwyqlhHI2JPiaIqJ7CEwMmtLhbyVwBZW66Ui+ZjqJ1TGWAqHwze1FA9+rnoJ+gsmQKIaj2tKwm08J0G3+vENaMqKD+ImRSRSvl2KkdYl7gBUUvHM4pgNg+1UxU97AJmNHAczBij0PDSQREWgfH/4VQBwECJSW3IURYurKiDYA1QCbL+g2ePcqMt9KnqnD4Y66Z/G/gZd7uUk7X5FeGuGyqhHmnDJZdrQXg+ZRJhoO215gx2RQK2dIuWTnYt9ddonN9kZWl7p7XsLOwucvX1wv4bObq6kNR7kT6bQ/RZoDRRXs3NJrCn/495rVrWJiaKE/kVub67xWmx8g48YuNe0TVewUmpOUeOKaKuZVb/xAooaRN8cixiZLVrjP9tJ5HxNbzN1j5dBd4dGoKqTWcm4NddGtsma5apuVzlG08UnUiwoAqENWItAU9USgwZ8t6cD+5TRo+NtvX30eGzh+A95CxXdPqg6PI6lMF0FmN0s2g6Rqp9slepdVRsINVZWq2SUWtDdpq7jLjtGi7GkSYsxWrVZtGo7hqpNBBN0Z9kG0MOxY42Xj1IH8tvWdgcf3FWGxZrF25OegdItIYe123pH7Vae3gOxkD8iyyMVhW8corybOX4n9x3YZwFtsddsB77pKbmjYcYYZCjC4KLuF2FJVnRYpUVLssOsJKuxkgwOLEY1WXItD9DN4415o1pQh+U2gZrYpiou11nFWdvBbPLruVbxlcQTb5xPTbxY76AnUbRh6UnKEyXQk/ztEPVbifGX0OTzKLahbupfv+06ucjQXWpi7zodSOO+EVrQvxqbuuPDndQdj8z1mSbcAxztEIbYBHQFT8ZqL7W3e0IM8fhW9bXxyy2Zvf/thBjgkR3M3qID3u42t3e+nGXT8pcOfP43dz7/1+T69PU/iXZhCLu5Bbtd/xBZgI8ukd0C3RwhA0zDd1tme9DNpnSDWY7L7b3f3vWLqwsTbctN7wLm5tNDG/cT22Fu9guZ2cj4KRh/Ty00/tTZayUjKF29i5CbX49wMBsP2xZzs+eY1XYcxS+wg3s39BSp4zw89goqs9Dv4LK9/uS23BK4+zYRS1QrUotZAkQB5ESc7cb3aPrO+CLu3MQX8crNfBEfda2Xd9JEpMtT7vx6B08E/EE/IZHgT/1FT1Fw4rtYH7A/xVgfKK8EeB/SIe9Dk/ghic7wI8cOzzWAHwXUIUdjl0Dm9k27Qbe0BdZmREqkAhF7gTefb7Ek7e9lSbq9cb/+LEkfai5xLh7YAumRGpbICEe88aTeqmJEeqNv9SJwntemH7p2EP1QYXVl71N7Cwga478HCsBwdns5QFNv73tYg83nJhjh0JFNauUr5a2EyNeHEBPvd1rjvWfmf4c9cBs/7lQoJ1/fUn78om0VxPud0Z/2Hh9+lBgscokiUyZfZsrkVHq85tlz83NN6fHnCHJLO1zu1Q6nVv4Cfx6z8vWxd4IC97P9+6n4lAZhiU76QOwJ7oWQASjJCkoYJPw43F4kUgts05+Fm2OBfaz0y8W3ZQQxeDfVFuzjA+eiEvTTlXNqyemiGz6PuCD6qaQkoSR5JWSOHCww6yID3hl5Q82hoFB8R5+AFwiCLpllW0cIdQsA9uzJ5SfKvJwzkq8ZJ3BjKWF6jwn6Ik7V0Mrp11+9i5oOP6+WSztzi/OOauq6oho8FLAscJjw6oSp6XEefS1dy7oAoPBAFBklx0g50N40MRj19DTENOu+k4GYZuFopTRdi6sWRJYy40X6xgVaBrv/i7TnSq/272NnqRkvXnliogW/E6TXiQgMKzuEeJ2oSPDNHeK7ImhWlRnuavC9vn03oVnhLnIHPOtEZGOv3CEwy57NUHmxDmjW9SckD9sxKiszRbfR26isD46ZmAmxIvBYYuuMXge6hBNzp28Cc9V6kFgvOQFX9X/2oLj8YTFY456+l22CcC1vgb36Z+44nvypmEjdHHtD7C/HF7vg+9/TOz5j/VBXt42Hrvp+n1nnOOftoh681VIbVvXQfrCqQiXXDaviC30wB/eOeTlei4VCgSQdM9sJtJpFWx5EK7EHoG9F1xC8NkruUAd5Td/O70rUjV+J8mWWMi8zJgg7YIpaXTigDlIKsUankFy9b2v+CkzrUkkRcuogbzmHt4sDm+0i7cz7WTQpzuPZ5ESVlbKNZ/w2UVct3cTkDgqSlG/CCfkm+I1/B7bOoo+zX3/+ynQhMNFfRmMll/gJd/iZK52N9lNncvtywZ6ORjua8qlDR8+ufE3P6pjzYPjDF8Cxa3ONmY/qMuQMeTeV07kL29LfewLh/Nee9dPM4tMEyT7tvLNT9Us6WvTTrEVf8zJrczlcjNPH/42v8QLK2MfFXsYwWG1YI51mrVZhKSqnSru7fDt0Un4GapjV9rQrKfru1qrYXYgR/iBprkvjcNsey5AjjhicyPgaG5mxV+kXXeOehDoT01OMVnU6rUpCCFy89ILkRLniuRlTLFbyZ1etlJ805ibjsidULTwztVC0pDjPk/eHK/Xa9MF+CJLHoof5PAzIEkk7S1ljQPihSDKGtRhEYj268TrRzDv1YhCnpMAZRK+3UIwi0h6RbfO9E4Z+yJWUWsQ0gYJLL19dzKTjVK9SSt9/RaYUIo9ChuTzcTeEMG7cEHYuX0uxJHA4E1gSIVdsYkm4Z6pJxdZxCONJrSw0/oAdwjivYOiXO1ok0wfPOjjzN3PnahLvT+U92ikTpnHo9gLd+GNA6c6FvO4bIhq6rYckB8lq1MI82FZvPcjVV0Oans4XSW2kkc12ILprKWZOd7l0rmNcgvnj4SCNhXDajdRNa9YmB90Cpr3sU3Uy03jVSHMafpuxC3dz57zkfa15SdaWq9PThqGCMFFSJDZmQWCV8hM1m/KT4ifFqxYDznHl1ZtGGt4MBZ3rHL1cjNbheKOXnuU6dhdzkc2wSjRZiQjEuKiNxAgMfHvRa7oL/eKrY09hftp7r30V2zQ87e9wjhZPG9U1I4c6LrBOIziHAXq4YEcC5k2Bsh69HWm7eaxpDEn1Xl6PVOw4RJXjqo3ofIzgzOVSFuEnNBDnoEPmQU15Qm/ckykVRUrTBJU+1xE2zWUoOmu8uQxht1p3xlKFSZuTgpXV8Otyzc/byY6we2MacjV9xJIOBj/P1EQJv79ZLYOfDMmD4+N54v21clakB4LgFdw5aZned3FJLjqlxm27OrzhXiTl8imu8U5AwXCxorMP7rklipFQ0CbULJZqnIaeryJYwCWo9AWkHiUgbBKU+uHnWzZs549/mdeihu0bsEZ9Yhq27J5sHzIYvsqArJS4ZD+VX6tHwXKrw0Yme7u3X90Fqdazt8CG3Cj5Ps15okMYaHga7CV6Dgl48yh5pJJI9hxGmqr+tLebOzVaN/f7vd3cZ3GiIrePpKoU6Qt6Pm1T7Thwgiaa5xK/03e9dDo8l2pKfe2g3m4tdjj2h7FX002QYKg+bL/e4Lim7alDhuj3PnmI1iyxtz72Px3HwlsUI7dv2wJ2mq3ag52t2sXlxWarlpf6FCKvGcX2P2zFZHCpX79FWXJ9d0e42O4IB82OcPOmvT+6eO8EneIICNuw7qcYsi0Btvyu+8lQUNs+sf83m6C2cS3pyMB9Uajtq3q0V5O77DKP6ILcLqwvdEBuyfLZF531/6n7DjBJrvLarqqu1JVz5xwm57A5SLvalbRa5QTKssCSQAQbI4v4eOQgMMk8sgAbCYxNxsbGYAyYYLLJOfqzsc0DjDGY6X3n3qrOPTM9uzOSHl5rd2Znp3vq/ve//z3/f85Zf+T2X7pGbo9lZlg58Aw24dh2lxVrRZ25smXF+r4NIwjuFlLXqX6qO4LuGBJBT9tg8LZ46nsRlnhn7C9j/xj7xgPQTthqjEWSVUPDa7TuQnlnugsf2lrEcWrg6jlxnXBLjtZt+MWOdRuYt24lj33FzGP6FtN5Q5PYjb2Nh29GjYeLcJS9ZZtZ4meUsbjRUewvnWZD4XGnm5ZIVbslHPt0KeQv3Mq6/1XnTpGv5Pk71xn/+gRXjcjkf7oRjfUMyeT319q/eJuo5Xfeb7HgbxfT/NFbSgqd4MC40dDgCDnn8ajHQWYDXzk653zb13tkBvq/DfQu+O1eS1zfT5uRfs5WVul7vbDAnSNy0z8JAe+wP/K62Ltin9q5/sh2r/J6PZM3n1nP5NfbfHNZLy4OD/RRFjt9lEvX66Nk8qm+PkpxO64vI8TOrayDvooDqk6nr0LoDv+ObB/HneVRUJl4UYvCzgR7mSGdEq+v7cJtCN3yYf9EHN5e6dGurEd8LhKODtgwePWfkEZJMiV5x1p9Epn2ScJui0G7LVeKycpcYQOGewN4UmJYY2XtW23SQ1wWrQyaKhafyH4ZHIgj7C/QIMnsLR4faI9MPby703Ilm12ZLnYaLYcHGi23nf/qYz9Nz3ldTZUTXU2VtV9QwsOlc8784oyJ1qnnzty6mDx5/gpzYvL66fdif5ehTJlDL+V47KkYMXhP7KPDuynr9VNajPTelsppTYM4W+yxrMJJJ2znkDeYZ9jb+nou1hjG6azLDg7puuRqCdLe7Ou76KdZ6r1sC52YJzKyj5clDSF88Rd62jI1RnLjwoFDQxsz1kwuLigG6c2oPb2Zpnia9R/zV71dm3f0dW1KC7sXyv1dm1UosyvkTexFD8kdRwSNo+iboRH0YlDb/iH2le2IIGYbZlrONJ4ec6bx1Hz6tk3AvO4BDbG1W7ZpVIa9extCjphXpbgkXDmPxa4DJA5eZLdvYgn83bZ1Ijn9A9Ju6hQa0S9CiggWVvaQpedWwhQV1Q55EnPshzGRY+WoeyHx0Vj7HHiL3lxoDOXzV17D5PeszNqBcenxuZsXxi+pW0W9gkGZmWMPnWezM1NTabv8aBzO++eyl1y4T+DE9Ey1cm7FquT9l+B4lFVM/OPQhj8YoAcYOxUFnBXsi9mEX0kXzqmfvDUwZTwYS/KN+lULuy9cTP4R6VQxl2rq0iK+nVobS06VkzgqRE6xM9TU54fwKj0VW8II0W0RsXqomSR8fYidJPmQVtkCsasnj8JZ6Gn/0GmVVj/cj9rhYe0MJb3VhQMse89wf8dkpVRNPempf3bviSc/ZP6FeOPZQ4f25BnVIEKWSppZ+3Z9Cg8h6/EWjEaIxQnLlir5WYYx8yvnT3/0luuq5+6rMXeua7F4vnj85CUnGLO2f/rSY7w9qTLN73Z6NFcrJaXdoZEsMeyiJk3pULbI8FpAH9ZH6cPag9bz3Zs/LG65604SmnXuoTLsp2+b1H0HIcjohs9y9dqz67NXPvki8jyrxx5xnD5Q58w8ju6r7Tm3Wj1nV6W862iVPu93kudt9zzvTPi8d3FGYbE+vlLQ5Pzq9PhyQWNQJjPN27ZgTHSlaQHili2cqOif8xbODvfU37P/TVfhetwH/7xtsrvlldhZ1cn+peI6epJbX7Wj2y42GQwsZKgjybxr3fVcHbKeOazny7ZHZpJ9ZN9ar/1lRz+ys/mWwDZ67GllKv4ApY511ZmzTMRa4/rry9PPWM0POJV8wN9UO1hRc7gXk7rwE6pnwuHNnZpsGN0V4dkNa5IpdGevx6+bvU70Zq8plXmdRs64g+mpbCKAvxip5O4UFQ5FnJbPpcR2DecnctNZLWBe1Z3N4l2pn0xh3H5aj7TR/Zg2nBTdNFv1P8fDXY9l7V+Wrnr8kSOPv3pp6Wry+1VLrFLZfU65fGSlVFo5Ui6fs7vCPH/dR7fa8+jMlMp8setRNJMTSxmZTy3Pzi6lBCG1NGsi+6P6gwoZThnBwrOyTn0XantEyPZhIHi/ZaiI7UpHnivLtF0UiKQHikTBJz4Kob7XJDNM3gu/3JaLAhEvIcMvizTXkKuuH+muLUQwSaVE51/C8QlmQLt2bAiNyUF1KMCEwCdDQnQCKbRSIG0fjCsZNtjdoDGhek0rgaFRGQTipMDCzW7tVtbPZITQdwEybKpfJloIbyy5isrxvFw2m49TTVv0ePhj2g2mPNg3HyJQ23wjE3kqqIaoix1PBfwvNZ0OPRWy0QRTj85Xm/H9CGKoANrVL6if3MR0jVMtPh7Y8erUmMioYpBOyybO8jin5M2sjFz0xGECC4VTX+Mu5coQWLgBeMM9IYV/ZWm5hTYt5qnnl4de9cIBiCjsYfpMBCOhNWe5y8GSaBP1zi6hg1lxeuc5of0SLi75yrauG3UOIpZkjZV6VGOS3jn+4cODfWXGn/SnCs960uKlu1F8X3cxaiQ7HThVS0PhP243XwfXTxfIrKpUZ8PxJGIEwDQnamyLkKq3xphYvzRmP4mTBCXQqe8aMKKKonmqpO8uCsRCTVSUFNznZDn+WbKqy/PVuNDY407UMjzzepY1igaLDv35jSsu4lIzZ00cPiFVRZVEjySkzZSLq0Ecg2kOZOM0rflpOqpEFb5K1d/tnmUKBcDqSjaThFCKY3hTfnkfJG4YO5WFQEoR04NYdR1+csQuMAUf5l/nGhi3SKT8/BTCzrHpOv5HtI7XoUJ73WmvI9NX1A6pae/fdWTv6CqE/6s+hXUcLIR/cb8t40e76uYuqbCobJ4500X8crSId8buJeXd6W5GatTXDQksEGu9NiJQYPrwgBYQwNyvS/vnGA7zEx66xmjEtu/80F5yxPONHKjIBSPl2eJVXRd+U5s+VrH5zKRj2MzJ+23V3yRhw4omYG78ruQa4aU+YfuJa4PJZDANj0E3mXhs+0I/lXcY56wpTZCdKdfh2H1nEheE8PLNKC5OQEbzxS2bo9OJjP5mUe+CZxlyRdhgyYOB4v4MY0AYqG/io62q2F8GffnMl/kjE6sFVcrtmp1dzohiZpm9rnvdrFQQGO2VOz5k5UwLY0hoU+gGXKfjJpvqX0oO9dR/YLZUARjzZHKTrg0taxajCmhpNSqy2gggXWUUTAT/5/vEj1pa/xsI1vaBeMxTusqYr3XKmJzVKXoYu+r1wnf5qovRiSP7wjLph9A/0s2Waq3mwwiMp+pHSb0lWutrRCepOdaHvL1eFb1kslOk+KRIISszNdvgiHqU1Q+5mbO7z65efJNCtHHqMxPiscxuPUGUj77742BBhy/mvM/u4kReL+IewptKoTruv/97eq2MKXxDHZuZNn+vf6yenpzsr7G5FjA1+kQiMeUM31er6+2p1a2fmS0tvA2z6Q+Y5Eyys40ecpK5oLOF7utsIY29cYQjcq1nWzF9u+lrA5vnVXTrqJ2tc/ACqUa2zuDGUdhNjsVd3dvoxDOPjpD0uDZseQFMbe7aHLjEQ67vZ+l69HRK2wAmI4YPfnE4gomBzAZll5Feavh9hHI3rBngba59g3d5vw1rGuMYJ8eUWu1wsh/ZFC7apwBVZ8bsyccOxzWflt6dI5e021wyQ8vLNgU6NdUfADqJv+u1mHK0JLleGUQ7T16L8NTNs8fXxzvfgVEoBV8BTbBrBewPkaHX4I/Ra/A85G9ujz2p7xpc6roGL9bRG+i5BZOByMKIjvY9iAJkcRrhnW+RmoDpDPtGPDFDFKVkeDdesHzcjXPBOYzESRddEt6NT1wAhgbjj+JDz3y96/78j+hKEbGup5MmsjvBPBYxr7oysqWE3qVGIR484PEMBuPPORhdlfcdNWEFWjDu2cw5nnlR1236BbBUjBsVy6mhXKFjhC2cYSF2VuzS2MNjT9jwEa8Me8ZBiDMIQ54efXibIw/rPN1FMnIsXXTuG+898aSr5o7Txyvnls+dvvnqa66rHt9T/XjryYnkwTX/dAQc4q7hD9eDftnA0w2MH5NnVyx2P7wMBu7Is2v+yWbABEHFvsz+CuKo+9CKjRR43Ki11UIiW786vfCIBdOZuox0Usu9iuErlAUQkk2pFiTimSIUrZQttnpnOGtxWhBBOmYp0kStRy22SDwV34bkrcXQQZT9B6KbCY2aWvmGfUcgs+jWbKtopGuykkgoSjWpZOzSmFtzMOrYcK1xF/2trEJG/6W1Nweeq4q8ySVESOSjFc5elDBkUxE4U/IUL/MRmkeIzi6gN+JIzVH3akHiob5YtvPT/oTn1cwyD6dsSdZS8GIvOMer+YKGmYrLMcOvOEp9H0FpcTrAu9OqJYO5THrGditgXfCyRJhY1KlckeLofxmQqE8km2ej2SfZMOAmNumEMcKBXgWwT8bEuBgXr5BNHqiqBQ9zTJDKumQKgs4LWlwdN3LMkwMTLqmSSOg/DHlXRU9PmERihpzxgmYqTgjYcSWOiTlQHH8ECqcYQ8dtO6EfUFlZD02qsF9JO6etA5pY0u9huo/dYIQDm24iuulIVmNec/xJD11aeuiTjke/f2ThukX8sIYbJPKEZR2ce/K4h9FSUQiN5Nl9Rl7XM4rCYTpoVuxt5gw9oI/Vzt1TfeT15L/VPecy70tUDq8uHKrpifLhXauHK4m3gt9ZyiqYgWHTeSgwUrUjWIS6BF6WyKh+QnJVAygg9+6NT2NW8ZxygAnZwHc8haWb6bNcCZnqDsqj6OLNbN6qIZ/DzDwAHtKvrmzw1Mk3RLO6p6/DbZq/3r+lto1emtk/zgZ4454Mt3NxvRWZdxeuxfq9st3feXyr8zBxxVMvP/aEa5fZYn+foLFp90bPmCF0GFcx5eJr9BjnE5KnGibJhCyLselOi+eCVkdhejWXSORWp/tbPiTyv4bI93DvuwHY/8sHCS57mdUNgj166uLiUBZM3yZq9IX8COSVG7vJK+9h1t8ERXfWW7hhkXnlcH7LfN/uOt6zF5rNTXkpWVbKUl7KBOWl7GttDqdncxQVieTEPYS2knOtqempFm2F+Wn/dvt63y5ZewefaFNOEoMiRNEmwlo56NM8bniOEoORejAHmY3XlNk0OeFRXzNaH0av+BuvW/M7vYnpU0MS0/69o/ViFEc/tsHSPL0/M5EN8GM8VAUPtQFhlz8YfKyNCYZwZ/LsakiYAZWHMqOXR9kX4E6vK+7xmmExmV0+MduKyheMH79p9wgxv3LN2fUNqqZPS8VDWMmKKhUO7Vo9VJQ+I7kOmSxFweP5jiutfb62UMAwzcKGQb3AwLt7LAIuZlVTwkyMkSBIhGCEzGNIFvIo9m8Bzv/nbSeWfI+GQvcEGgURaA8mHDNyWpzVvUyfMkP3YCG9y84vEw1DqgzbevYLftc5gNoXxRq5MOB1mJVOrRb2csLKK2pHvscq6CYEKpERwdcYK6eQK0HSsGQ9o2dX/IlSwi8n7bpXKo9VZFv2rwf3ScUREcgF5THRiGE21G5AyaQrac3AhZc3J8eLzWv1rKoChXAB6zzHnTJkUdftupMvgEzEVLOKaya4+hHGExIQeEABJFpyemmqCHv0hFfTofme05wk+y+ipRhVwvXW0mp5r6Nr8aiVg4rHM7JXTPtzU9h2KOJYItIurJ2LoSQAmBlotDP/gu0YiErcNr3p4KLXH/tNMJvS0Mhj0Y/yXcNkXsPgUhh4OlY8juEmFSabEpXce11uApWaFjhvxgudlUujISQgS0qcaJYzVlXPkJKLTGWRefK9p77O+ZwRswEiPgwox2tJBHD04ka3CWrkEWCMGpkxbQHHB5mIXk7UCpd7uno4Gig8FUmk4ryqdAcD4dOFsdAYwA+ZgxTuEB99Q3p2ZioA/sFWRoA3mEehNo2zPBANRVT4DMdWD6mi6pKRToJ8+GpFo1/efDKjBGoh5+EJps5Jd0XAFe6kgYFce9I50I+GYCiXQCDHTzJ8hCauHd6oxvqg4LgWpF9EKkiZmf+wYiXSGBVm7yBICFa77BMNj5cdOzp9CLWLZKnaUhH/jm+tNBsnl3+sNHb5wiAgvICr+ykugOHvCWAj90Hxbss1Ww/LGSsfmV8hDEjLLtznhH7Yu9Utt90uIGqVfHd+ra10Lkxki9OM0lp/bG1mhSACQtirxVKzHwtLu0BpLsKvoVXazfj6oUe96THNJOqrTmmH2+Seh9/7jAVSr6W05sT1i5ftycWNv5u45oKFJzMvJYRHRiB7Pk906sl6WymCdPESrj46XGbtfHMKiw3ELFzt38dqy2LGrruFvJ/KsIpFg4LMVIEiBuzBLo7bk0d4zimOWVqtmvVZRS/ScT8m7R5K4KQTmRKWV3JdkYiAcEy2eFhNS/gs/jh7oPJ8ubR/+Ypzmt9jRM1SEyns9hlMxXUmjqf95gfTVkI3eU42a+xbmXtB0BfgZoEIIF4LuuypOTXUz7VzCZETLRUEeJpaMk4axWLcy8GgBBx+0aFR8fdcGlGhw1XmibG3xj6APd69sqffFtr+kGgMDQlmuntZrzrD/tDM1qPihk5UJA0nxShOFBWMmRseFlB66Kz1WvLMGkXMPZ1YObs/Vu7pipV3M69ZP1a8ikJjJeGqNFZqA7EiAPX+HOqqAlDWPbFbwTV4e+xvh852bH4mrHaCwxoSHLTbEAaSUOajPy4P/8qa53bOjN7arSuQyJHRipkVhnvo9aJw5WVBrUzHjMXi7pNsZoQDQ+0Ex0JvcJD7jNhAeCgSG0wxV9E/g/TR/0XNspCKDpLj3TEktmNoAnhtcQGaGkY+XalzWf7C8w6cBJclkYfiTG13zVqrd06Rm7tPkQw5Re4BGcIIg4E5tz8aHgXgXklAwpuTE4HMJOmfEBnMq4Z+5XNThQWTRoUOrxRW0nBBpbHTHTrJ0jjP+UUt4xtANGIiouQfYL9RQNV4BDbWL8U58+XYj2Ixfh1TqoWWKdXSClmsFl++J6xoXemMFjOAFECXqm1H0DD9dPp5cJso4x6C6qTwB1qHASL2BfKBS6+/dP9Q46rnlifKbItI37yNBN4Vl9PAq+cQdp/bPKLgiZNJ2sxDTz+kGKXjaDV7zsVHZ506NHi0nFhvGFnfZOVz9HzaWSE3U8gmJwObOSs1wWpFHrCjYvuYcc8aBmOa4zeOq1YCwtrcxfyJsw/sQVS6u0u1lZK+9m9dYVfpD6Z3d8IOdB1GaIfdFUO/8hFGK+ysidw6YQclIUYEQi3Qk40DGwCsaPZWAMOwVlxA5S72XmAuBeL72tO4wDBdF5ShN5hNLiw6uzM3FuaazrWk78Kyds0GNxRW9UAtJ3eUykEm2O47ity6hKSSNnvj4CXl7etdS55vpCH9QC8mL8V3v3zDiwlBTT4BHF+LZeD3dFtrVfsZj4T74qy0YEKhEonpR/SUxnJj4BPlsJVOapADTG+zD5XnRfas3tAE6fl/WDz//GPZ1bHJBe+cC85LzR5/hFnJO9nGNPA6sj05HU1oU9PIdN7bkJy7P94XTKgKo4tJNAaZT4qsPdnIXnbRAdLkm6tmzjm6m/0XKW8vXjN56dWMYFrFm3etXFbWPSjocHozAaGDpJdKKQyTO5RyKgogpTzCQLmMKexPd3/Myq41BkPP+I/8+ckC5goTlZrfKHoQYOc9ipB8BSe5DITk4tjjqTd1P/AklBGhbXB8lYCwbaR8p2FypeggklswOcM8meU7oPlzthMwf69SPXt14SwEcfXsXatnV5U34kCbS0aAuTHtBmO5Fno+Blmz4dD5xzeEzi+AOoVTxhC5kvSdQKWoX6yAbPXzWDa2gggml+qILtN13JHBm5WWZR45aiKfMdRXpMyiz55f8Dv2tsRWD4ov7ysf2LXgE57M7LnXzo9fc/WF2cDwx3ZX527+AF50Zc6s+Lm9C9U47SsbBTO1e6HRnDNRu2qUhsNOpyfDZrV37t1nV88/egAKgpKVS9ZvXdh92WrGbIwVLq03ju2bAnu3+Q00jw9hRFb2arnkXCPLkQsZ79abv4+qNOm6Bn1W0cVUIB4sNPx+gJ4QQT13U4x6IPyczaOIWVhpTVbUy5VwuKIeduNg7kbmsMFMXgn6Yc/n9gXbd0cIGuYiq1HyXHPaxQZf+xpjYlJV1bSsQRSFi9bS7XsO3n2k+du+XoxWP7q6cPY4Cv6ju1aP1rXmPRuFCXKYnMY5r5MsJ8JsxdNUk7rlUYMKZpbXU065xILF7DspnadP8ROcxDm40JNN/Lwzu873N1VABdzLkq+DE+NC3wxL6zGv9HZeUAm91SC3c0iXNJfcCd/tup3f8cbHNNPo0kW3c/Q2DNPf/fA3P2NxWTMJ/3nqD/q7KQ3JVVLfXF6cvK7MY/fpYHjPuGsfxuMPWo+f+W1/w6XOalbNog2XfPI8pYheD1OHIp0U+HKCNlxKtfP0XIJ89qrx3RVTK+2Znt5T0vD7S+nhBnKykbJ0Yq8o4d6oEfWyvzNdBS1MF0gPGgmSQxv1X0MMq4jhGvrJN1Erpo2bIw79dCtgw+s1kuG2mUA8d8OGyH9Y1ZzdiuGPia6jNwKhR0fs0wN9libTZfEw29tH+c92H4X58GZ9kObPmEQQuDS4OcWxcoXmlb3Nl8Huyl0bt07IAnwfC6BTlP9IVAj0LcCAzAUSwmJv3mj9i7484fT3FJm7jt31kMXFh9x17NgTyO9PaD6hf7qBOYw0wPekCjGddq1UVmG86vHdlduvxX+r1d3H7xsA9D+VKB9cmT9YhfbEodWVg+VE863Tu0uqnN87P7+3IMuFvcwVSANiKtN5ioaPZiIPNSWnhPa7DIjDS7BrX7ZsMlAIPyZb5hiRtMIzp77HnkKn9rLYC2N/H/s5ptX62f6odslRQqgU7REHvzMHBUpGa4ghqpjLOKqoEiJ+QZyCfL+a79JxB8LewG9u+6sb4dzDMsF6ODrAs0LlnKNhCXA4uOjORXORUCazGJCSwO/lbmf2ldaYxR7iV4tLU/gNFjHJtbAS/W3b/yiCodo+s3eOWYTSmwhMsxK4s2nbkhwpjsCW8SgTliUALFJQQVNRUfI/Di2TjKWldS0DW3RcWHgbXy6gANTETAqOinfRLxOpD6skJzULvkb0X6MCNHQJ8wjA3TQBxfE3NTKnkVDxbTDQdr1Vcc6B+eutKPBBMpElARGtCSpP7KTuSsBdVW++EoWa5DbQ+ZXIdxJJyYOBR57FgEacsk7wXtIZLakQ71WZuTK7lJ5Lpad9lO9WEnKXREcBPwPYKLyU4FTRdhI+sbpCg1kA3c0UGiUrrUoqrFXpV6L7LGr/6U4EbwjGnMeaBR3vw0zwIhIBTF0xtsebIuZIEpzCXqylzYwF7glcWQ1IgAM8by7GRQBHlqa1nh55aUG0NMeQifYDeSq3OF7SKBg88RfjZE8BCTtviSjrRRQ3PAHiqSKYkkhRsfCvsBDsj81gY9+5mUdkv0Wk3iIURVOSQ0XB/drGssS/2lBeGCmoxwXyJ3iCJBqUIGvSO5lE72S58E7GNIMzc33ctatXN3hZRSGJaUgysUNvWwx7rZrNokvAO5Y3E/AXvOH4/5XtkyPJC3++LS98Cyzfz9DZca6jWUsEZTDkVF9piQRg8UZXp82MqCPM3tjSy1dAwKdfxfGqVLLyCQwjN5+5ZQfHJ3fzbNK5VK9m8It02yHi95pRrdesycsnNMS/ZRCBWU+rx/9sqGpXHQ1pDtetudhjYq8h7sRM6O3G0QxXHirAEppiR7NmVPgv9Lzm6Zfvj6+EAd3+miAXX/RRq6FkIwxEIljLdM2ztROhSDhzrdyOvBlWE6s8bcYKISLvLNVb7yHwmBftT6MNxpVXz5tYTEB6C788fQZ5CmBn0bXrgTsDz2vUrCSRCSZzhW5zkEY0FHALjz/pOY+c8QoqcDEduDjrcQIgIoHUhS5GuMyEMH/0kvP3GylWb/4FthD+CSyttaSmpxXVkxIwMkZ+NGUlCetBxSU2uRrH/CG0hUrFBm2gQOxXcpQgYNmfVFYzZ41PH1/MwEIBVzUpvxgspTILQbJmGZ5A7KiJTjHxsxbW7khabkrRSNYRAuX/OK7uK2S2GJRgGUi8kHKKeT1EOz6rWDKZQJOhRo4o0hUpRd5MwsXomUA3uAIfa9t7Ax5OURQnchi6LYNSWSqkgQewXNErR0LDJAaOQObpSUSmZ0BoOMpSg1LD9S0oDffuv6WVfUz/DhzQEv5UW0v47EhLGKm9pSX8+uYVHS1hTeyREn57axJq9/6QQWmPjU+1GZRm176kVtBAtnR4XIT78gkbawUfFSzH4qEWPBaqBcNjsi0WfI0eoHwfY781SJF8Vs/u9GqVqkf2p2G19ufLhvEZZ059CqxNGdfyp8beAIWeoT0NsmXCcU7i2LnUAEWiMRFuYG8DZvtM+Pzb17DKcAVpLDpuXIurm6XPAe5qfoiI8yuzU3DmVmFxmRItxrFl7GwZunUKJbj/8TCCOxPy4uNaYffC07BFUwP8eGih8M/Zk9by4g+3urAcP7hSuqgnxpK3pPb4qhFPqNmjhYxPZLGCQao75lLrkI4mzPhIOrrDjfdk/pZhGXnDFUdZAe+3acpQ3o0excvRDX/30FXfWdGDLS92RxRh2Lqz2W3XPfijrS41o4TCCEP4y2tnbY/yAXPbxgv+/IEFb8odaQSqAE4LHqIAfgNW/xVnqADObLXk2brC9/Cb+XoK38BLN1q1Z26g4b3uHd/ezG5xXQ3vZ228Wn+2uVD34NV/8tTX2d9gMKmOqcnnxN5EJBNRUfnk/sjWW9e/CKUKFa8Ww6l6rtxoTeGHi1jfz0W1Tqgr4IZbezGU8KZEO8gsY5poqf2v6J2S/l/rnoxFDG+fzsIKomiSqxN5Z9rjCbHIRad9JYnksYjhCumCrkaSXJzHvBp+JwK/6B84+2gWlYSXnDdtVyr65empKdB2cAvUVfUNoiQavI/jF7USfUhxWZFzWZ/IIqKwijNPYSyoEuMuRqxuISGTa34XMADWCxinl0NZ5UPfEGWPCq6bDREfxcc0vah/G4a84F5MnyyeVZQyWR89Nc+fCFavW/kEvR6yAqxOcE2mHTxccCXDMC0Hgkr/UV7ZffKWeT/AgrK4JhvFhfnl5blgzMwBOqN6CfE4/9sfkijUyW0XPiqwiua5C4tKOu3DZIXTdeQhGPQKTNlKg8opVyZnHGfXco0dD1zLlg0YyuL04WXXKaQcH00x3HNQWCXiquQ2z1d9k2YLFHIWQ+BS5qSkoHUEXyMZss2C4XD11cN7p6SqBt0G3M1gY+Fnwv7gF7hleve5Dkf/S89ETZfZQEx3u+5Ez95M7CwTuETsDFSnjbRy/2er6WHdC1NhRNEyO+9upIR7QTtFNCbGRkoRkditGIndnozGfEcUu93yeowsZvvTATHbF271YTPC6YvVTvXm2utHyLX9erRkU3wc8U4e7O/C4f616z/W1gFJLo18g86JtTZBt44ot1ypR5+kHCk8U2wPKFw724YVHHSLpizwhlY6khOy1UY1J8YnFiY4q2LbY44W0AyWMayq7VRtBln+HiD5KY51kyKqjg/a1byHD7IV8xlspjZZy561bTvkItnR0Xqw0cbWOcPFcC4HhncKhA1ML/CcBc4Hb7pSwgaDOsEkVIVgTVCSH8OLSq7tJxX8Af8OB8jh3sU9f8Rd8imIj4biwk8A/PvmMxcX3rYyaB3x4HeemXhw87fbVRWtDMgDL3TkgS9ZTx44PSAPXNi+yugGVoYCMFQmkx0FYPZU89R3uBNcDAQSMqO/EJ1HLZ1fIYvEFRCYPc9HnXqhM8Md/dLDse4QyV/uxlO7SJBEuXOS8h7rIY+IXouh9Yt/PYnLMWYEwk5Be6wCVEcrshGjhiiwt8pxzIvG81oSELaIQd60pY8nyY/iF6rFJCcZRDNJkyzFziahjJySBRn2arJTKJY9Je0CV/XJ6mEJpLiAhp7Eh1gP6E+6JJjsWUs2X1dVG2UNYECdfblfB/ouGZavTURINxAfY8GAwxypFaDxpJsFzRLi7JckHvzErJql8BTrFevu7B5fxMtlxmYnSoJeMgVT1kkHgAzRlIkrJkrxYHJyKqXaoFaDsqiYeLfAviRcsQiW5UiuhwJW8OO/ZoVq2dNMlmv+ivWsui6TMnvPhZXzKvhygPKoaXRLQ5sCdNULJV3Q4TjG45qmOrnV3OPBaYRvEXqO52Ge6WpYjP0NlnpOcMkj7eKm0gqzVam2oHJyMa23vcOgvhrtXfLxHm41hMVbsHqFMrSzbKTLFYG9+5gWilhpk7RXax0RWvJF81b4EisRuiiS2y+dB6G1NZ2oOwtValrGzhZV3qmjX6JYjj+mOtABzuoZURe0rD1eRd8BBiLgr7oJuTFWjh9Si4U07RFAfjlXznP/OraKIpb0QXwJTRImNtGgJO+2VhMuJOl6CymOSN7sVZgfwoAb7hO2QPRm8SGf0q2yJGC8hlSQcT/p89ARhxTsXI59VjIPuYcAW1BBm8KZCmSfJGq9YCo5JUPq8ZyWx/g9yLYooxO1RjF+CWIXXClVR9pOuLjJ2RizIIpbd1SD3VyQ9jk0TAbQ5bisJ6jI0/eIkqyKShccfNvSmPPiVTUBVqskhyqxR2WQeMkPFwc7N5dweQZBoYKlcRG6e5ciwd/XGxTbEQ7chradIYLpeJ3LDcIg7PG1osDrjoAKcz6Id4uZ7Vv7vxhfWM/D81jb4K6EpRYTphXqDCP5FqxctOrUgBdEZDZc80w5x1Z2ZzZd7cnZevyadVZ77dJK8KquCY94sVaMfDzp/AfzvadhnTWEIhEMZp5JlYDbi/yHbGeBBRzh2qmPcVAtwqZ/MvTDPxv7+o5t/FHQLpDfWpoxHTnp/lUWWyPg3HylL3yyYdlI4ifogrNO7ExeeMi6iJiZLxAQH3GRyNfsVih0bf/mS5E5yGSQYNvayyf2trTgqD9iO7/8KoS7tjNXrH10fZyMedLF6YaoViRmEqnB43gXMSOXExf3JIXmXWFGIQ3ldPAKL2hnHD5bpI6y+7u1QgOAoTchwI5CIPbvBvoSHQR7g8YE+YteclB3ZE1uR7wyIwUe+xHMmZFmRpv6TWakZUCfHgAG5l3NszFYSsBtCd0MoRvbJsaIYLim1Wbt071RtA1n1p9sFm01BFtVJ72PbGCNg0aQJ1aJkyHe7XY1P05Sp8RZ9nPdIeOmgy0G37FO8DX/bZSYwsUwwNTeZag+arGnAC7/6qiwqbMjyYrfeu0xAux63QjGiv++M6nqnC0VJ2sfH912cT3Ilr1n+5LWOy7prVwOb1q5NF+wMcobxtvliLdl3Fs/EvvX9SkkKy0KyaDtIvNgCb5R3BrZq/tsGbuJJC+H7W2vLSOm6nYkEo9tKRKbbI+b49zKXI+b47mXHp9Pd5k2nsjNs3pKIGPdGqhlmNK0feramFJnHhK5NrKv38bAPLc3MHdtHpivW9flkZyVX4S0MQ+/vVdQe9DhxfZpVtpn6Nm29aC8AtPuu1NdoVPakzvtuPnLbbJyW9viLY1U7MmFVDtK0tOF4SHysPUKrru3y9Lt7df0Btv5m9/fSJr7Dg0pJ/ZITB+8NxZb7cOrHywHKNcPg1/Xj3b/984kpIu2FBHP78fP/7APJmcPZcv5LaaX69ZLL7f0rvhlm6eXN/Yh7mzMPvVd9r+hV7JKetG1lkLnslWxOgtNcLReiU46LkQ/EmtkZoGIiKEuJkLze8NxlagfCoFWAWdiaAY0LIC6uHA9MUTDiP0VxDotrSXWCeY9hrAw1JlwrICqdYpUrFPFVOLbzWLG5fJ4fmaSAw7Kvrc8iQFFXssn7CBPGNEcUSmE1hjGYM0yhA4SuuOUFTOrJVJkFlaAbXtgWnkzLvKOKCREwcLz48Ug6fInMrsMqtvJsM1mMK9bYMfNBexByBPqpXwQRzsTyp/+sz+t1yqplnQnokOq5LykAO8FsKiyfDgfWF8+gOYixEIhM4bOgSWllwp6SdGTOkgvRl2XbAkkO3cc3rWg6ltjupXX8Qmj0SgKWC/t1LfYn2Je6BiB08NpkRbEuQrp1BUiplpfDVdrL8g9npVlWkZ6ISiK+SGi/7YPBjBYR24hal6D7pxlqD5isP52rzfcsteZxKaIe/eCWaFJU301nBAM2NvBIbQKgE1ZDOHp5rRF9wwTT8iGBRV7Ix6XZDGNcVVScpAH9KnxPUDJ9WrywCIJXSlLoHgJW3oMi6laXjChOSUYd0FfBjp8sN8T9Kw9WU/I2FIA6l2yq+RCIc3vr4NjqmFUvcBjyePMcfL9db/oROL1mDo2VF1LL0Ltr1DIRNr1a/cyVjKJxrCp5zva9UGiUMorvMr8sZ7LZLLo4rJWJedyjwbvWSok1LQp22LmUBHraKR0d8ozCwbpgJPLjCN7IOBzAgymDCtvkKUcbxRBa8egYK2YTBJtXxzuDvy/f8wlgLQ8HT6MO4SyOKPN0ZKFXopsn5dbyxvB95TsLLScwZeZS3Yk7f5yxAFc5t7cDCIH5lxxQPh45AC6RPRVQAUCi530XKzIC3xbEdWH0WHd3+8e1g2A5PUM6/4PZm0SRQUMVfLWrwD2Csge1lgsYMBKvPlm6o2FDoyKv3k8DYBvQtZ3hwOAmevhti3Vkdg78BjnRSTJ4QFAiRJW5X4JAGaxjZ82lXFQmNlqwBshAEbCYIF5f3vls6VsZ+WLBK1odduilc/Xi1tc+XXLtU92eHTPg9qHLbSNqOK5UobAW8z/JgufDxeeZW5rLzzvknW/rXvd76Hr/nlI4yiYgH9F7BNDJnPXgb+6Bzh3Hv/qmh/az7Q/jVDBEPcyiaKofKMnP5o37D+053p3R3O9uNi05nrf0jzRmesV2uOA4WDv+1uDvbN/s+1QGISnAMXrjqHpZjCn5mowf/dBltHrDuaKeND8chKMVaCC3DUOfBbmP4GHVaL5T1ftAGLnUECsxn56+wCx10bovFTWryIxnQFiRF7sWtZ0HEHWSHlnmIm6srLv4ZSH+V32K+xarAqN/Z8wCVLA12kxEHGjvTYgUamVhRYbimvptoeqAVH5JRB0YxJxRPq1Xk8ZQL2YorKuK3Yi6kCji5zV6tGu9HVxDzIkosLg5WnsIKZDlH81/EVHNFrcL8riEjpza/Rtk8nnsE9MOgTLK5xQDjkFnrvoLtJ9QDl2CElyql0J/dYgPZ9lXuDO2Brhv0h8xgiaacmEkDgo8cwE0YAFL8lilt2cls6SskBK49AmPdHDIBJhGpQHcwp1IJhCKpbRIacSCmjovCoJQ5Bt0m/V0EeXGjyRscY/TIxV0boPIGQNLC8hkOExQ5YdBZWAe1DQSXEuqcyfIgJwuy/hO9iEsYSpNEs0ZNQzeC1KZCbCtAnVMi0ddwuWXdZTEBVFxvtHCZczJB20nllmEvCAD09egReFP1YLalpWGDUxZoIB68/5pkLpUCKYC8B3f1fUjbyqSsAYMzlsNQNFsJmU0fO10M0mvCGMueGH4FQwpHyPl2FojJ8djrkS4ZPJ+HlV+DtLnICesS6CYKvpCmZJ8DMmwp9Rxk/j3kJe8ihPuF234cHx2HwiL+K18COqvC5/GXrinEleTQY/DCwLBcw04XHImtDT13mleTlURhKE7CZQNTIDgyo84Rw7p77A/idOyNXYH8U+FPvxACa3j4G08QOEygVbqZlGwuN+bwM87mWM3o/HfXFHjuHXbVBesWJXedW8rweJm12d7ULi2Pnjlx2fm+xC4i4yckkw3lpYXBWgR9VOtbC4G1tY3Du2r2Z7XU85dnl/OfY33cfyzc0nrgvDkTD8Nm5gCYqZvCb2jvsLM9k4wvqqsgG45NJ+uOTUjsTL6zeIl7Aqa9fj/UjJnf1IyeHtW/z7ehb/+v7Fv6978R/RfGUfSMLRzPNfWPILMeTwtbBGO6PpQ+aBjxD2jds2t8ilydwiLA3u7wzUG1EXbtu4I7tr+0LvtT2hd9mGeed3EGr2qX/jLI6DbNQl5BpYczsw6f7QYTu6EESNz7aIKQx2rCDUOuWGs44FZiehuhtRJyR9AeCKIjAn2qK2mcQeQsKG7wvO+ZKFMcV7IKkFVxgnESfiUUZbPIpbe9VOYng3pvKBAfq0kMlnpd+GgrZllB6f1CDvJOFdg9GZhzCWxTan/kaTUb1xThIxeaIjEkYkUJ937DfpOXbfDmB78VgOqhIZoPHnQNf+VShxQveNoWvQjby1E0Od1tl91z+PGa5l0zNKxQ2zdF8Z6t2+upnxOvMEu4YdmzBskFwtTwdWJ4BO2bDsvJXgIbSAzrEjScVyJl5Q0kkXaxlPKz+vTui4CcI10pVw/6szPwov/+r4vvVGrG4DRPDGQRd3CIsMmrXPrO+wznzWWaUbXIfgmQlvaSHNm1OaYUDyLdrgY5OV8JKWSvfv75NNJYQDXkGGrpAyDY+MuhSy0dAVc0uPQ/ubkWoSOSW0YX9Yjw17vNc8/Sl95unj+47tm6A3vo9zKvhH52Ik622xL2w9SIg82ZAo6RJ6b9/uupTqegXfoQDlB6vrB014/mwlaB47ctAs0qAh6V8zTWEgbsq14xW1yHEakZGvHSnDFkZJwqEgoaTk9P5ct5j8VQ2rbOmpdM5+ZG8YTbTDiDNxLnQH0q4NAumvRwqkh0YnhUiJht2xdFPzJemlbMKz9DyRpbcmAgxlSy4CTpJcyZ822uL06UTuYFZzdEWDyO+XeiLsKe0II1vlro1C7Pa+EJs6fP7hafQY9FPfYX/OxWPnk54QM9ggKHRCboadZdAS6Au2ob0Afv2exD4CDtAr/r7WxDeHkJkNBZ96Pse8sbdB8KhWYwBySZZwJ3Onn3c2bwYg/8uy5rCpbFcHAs29q4MUbqmh6a6Uzeck5konD2FE+gkoc0DW/judFkADhlWkBfCSzAqF/hOGJd7NMC/1vUG43+iC+6/sbjj8RbvhkLHkiflZXVcITS0RmuxSSNnYXUInBBw48lmTfJb8r7SMcqEEHa4qKtNzYy+JfaWFGvce3bNdUjgr4WPc/mEA4EstcmM4EEDrkd6Ss9IS5Kf5IXwHbOvjDsrM3IDUbje6C8jlVS1j2/NJWjkajtwY37mRAGsyDScCvjMUQFQxoZMCSyjDNVRBJBS+SiktoIXD2R6AfwDTtVJG4KjCg+2hbEjJpJ6Ji3LBLrLPSpey7KPdyVYRmTeXDkJSUvckWkAGbmJ6rhG/bD3E+enrDwisdgYEzhscEEiPEYpBe0CA/SLoIybbfA9meWxBhuQOXgugZlxJAOBUTYpWTxPoBaoWqKNMWrDKNaIkRGghyAtuLA2Hu3+G5NuzQqVuKjSG9Q5coVU0cpG0LRf6NoZWIfVQ2PQAwOOKQGMEnyAV6CKziUveCgzFViOOrAfJEMDg/gp7i10vuk6uapX2kNl7+EnlThZl3wTOlCuV1dxMo+YybgaWTqlCyTCKuUxC49ycPn5JWedfnnKtHHnIGTQj9XKN+WDHM49oEK59DnCW1/bMu+F3cJADLqwUfSY5Pj4e2GX2n3kV7ppplTwyNoN4g39V8XAxAV12ADOMJnnVcsVhDGj1CQ7YqQkdJ5tbyiSV4tkl3bamwNpBmRDYGhb4z4mNnqp7AzZ6LHurnCAlY1xJ2Y8jdQ+VH/0MGOR87NWxLzEmVdMKD9qDTDfeSvUAgJS2bb9WV1q9AlLx7aG8qCitExkJ/L9QCS+kiz3yW93WY36XslGPX1n3zaCjvAVpdbqsQkdai2+5KtAjgTasOzdU3D3wi748R6jQLmS8hEq3Mxr1LUPXGj9YKTw6Qro1+WYUzEYcXeJS53NZto5CN0U0IJSJKR/5WdDz4FXsdBH2Y0TqxZXtRCCp6D1IzDMUV/YMKy4SW9CkNgZ1rhLuiEBCWYhZCUQiSobglJgAwInDxZEAmULEnKhQiUqxWskaUHPxFSKxhcuGCWkZCYgp7gxEIyulJTwZB7Rssy8xiOEZkCSo1QD7XPv+nOYkkopMxnOT/muSehbXUQm3IfanEMByMD9s6EnyLSEBJkTaVrLQnCbGZCIAVCQIwUb7QsT147f1jMe8V3Z5cr+UlRKP/ImiCdiszJVIYsKtHNiyaiihTpiW8AONDDtyXDHUzCL3fahLESa1TLTC8G9xfEq4KONjeD5IsgqhMJxN+ApUXPgUB9YZuEtx8r3pK/FEjfeEmCTPCvhuKFImYYbdMjjQiTioyYlUggtoMYRq8JyxVFwToK540GHxfoiDPfk2CaGBp+lT0SqiQSlwgl4lotMs9HlCEU/2Z9DQqMX+N5Tg/2kLKgod4CaKno6yXKN9hWptItIxCU+vcPeskA4DCVCS9oA7i17/JmnlMb7LKpFIIpHRjCjOSd4bZR74nBHmgdm0UzUximSoxaO5zAy4BoqG26eekdJTaZfkKpxWcUc/akF0btq9zQwMSPQqInoHUtUJTNi1PMScaKArl5tegDqdiaMBcm+KkHASTu1cq0KzYiq0Ypy3AnoJTlZK1dRSPgN9bCZ76NCeZmqUeeCNFRfZk1JSE1HCsaIBS1G47QlQ2IYbE3xFVMljGdNNaNgcZRntN18sELFpAbd+xSQOZqLrJdMK7clxhGJDYkh234GaSXETiCLivclCw1PP8eRMZfbkMfeJD6sW0/zCxlqPJNa+SGNtGSXWh2LfOq1RYOfBEnjcgKx8pxnBHpYPXLaelvzzBloO+QdB6P1OZ9p37pxLjs6GTQhbm+jqNZyfm+1M/aZQPaU7nYYrW52Gax+o8HtDV3MhajpEMsU/pFF3LeXBv7MlNP5gyF2bWiDe/iCIjLV7NzeAZZceqFX/6mZ+sSQAvoAAyMKM90Uwxvk8aTOtRsUzKY33UtM4ejUTF1sLKxIl00ho4kGTcYjDXaVlekcD5JpZARgHwDLbBZjyXRaoi5nz0OZmX21UK2k+rgYFw3FnL7njwIE7LpljjQdBPF1cXDhUKO6fy+fn9hcLhxaKZ89kUPmYllVgGSjjWxgTNpIYKYTkvgPCN89olWRtClTz5BR7YEtxxqwXZ0xXnL2LxJmdSLbjjJgX0zg7EsXZDOLshRoqM1VTVJ54fOL6YJ36Lh34vgwexF8JwZ3tnhVaaelCRixuKu1IBkMIQR/6vD4ZEApHRXo6FeGwd0sIiShFEkngRaL9uXggHHKlOAWdQF6IdCIqJTq2GL4X5iXbPjH0IVILK/A8IYKpBAQyZ8xWUxgQkmFjiFWnorhpWERrAhP6qbqkkF27lS00qgJDLySmoqh+mWg/PKPkKirUHOWy2XycatqiB5e0hN1gf9l97z+jDlTz72gJg2uraoi6GE28hu87NZ1eWsDIaz4bIVCQk7CCFABUQy90Rl4fgVkNMur4CypLPjFd41SLjwd2vDo1BrMDMUinZRPlKYyX82YWkxsEHyAW1+yvYM/+wu09r8iIqtg1kcREODb1zAlPokmGxG+++9uv4L6I74tqjX3UphkEV5otZRBdbSWQphmMa/DVCA0MSmYNslmzC2YDMrd17DrWCB04yPNPZacnppnPJDIG7M0dTrJ1HXL6Gu798EHReMPXE+i72r6K7Sw3EhCPSEkXExRHMJS8attYUslPZnMaXcmLJQzr4F6K6Gy+n1Fcq0HMTbDqKZ/6dDDZA0lizMFEzhz2JFpodJmIlRYpLWDDt9pSVNhL2NejeJC6IpncCgX8scW5VgNguT1MPMnsaL379I6swhcQ55sbmrL/h1wix6epTAMEqgyRi9pIFiTJ3r2Tp8s1ZBy4Fuhk3On4hn6o58FwOR0cIRNTLsmUaS4cLLYdkw4Wf3X7axUKJ/1HFAsvIvSfHa0anG03PWefuZNrt7Ltluk7UXA2vz+6z/rfbuQC0soMSOB3xN5/f5qqt9pJ5RA47gu4ENrcONSEBn2J+8t8nflbO4dejysXKhXQPaYnbNPQUlJ6Iu2M+zY0ST33SPlI41YD8ZZSML4IaeeqHUC2kLnUHK/neSE7tWDkJ7PoCjjVse32aU/hL7SKTqSkZQe61dghKqeZCiZNGcN2comSVcKPyKCykZNIh+SubDtBkCD0BZb4nTk0NfyApoYTsbfEPrO9Ru47mWXuRxv4nUXfmhdsFVbb2HB77v5B3ZrlEQA1GlgEUPu72LcffICaQ8scneaxzYJ8IzztmgcPnrZCoph0CnGSbRzvT3gQQ2rNf2fZquFgVMvLl9cP9t8OxdRIRvsmDbw9mGv4s3Bud3WkkhcjC/cHrEKgklC9F1AJs0KxkgvHj9+0e4QMtXLN2fU20rW6k6GU6ofRrqvN50A73ri8Pc4omYWxCO7C62x/bBRN+GZh1MbUoWYGFAYLHnpwekA7nk05dTuAdrRmGmAMO8yiU+zy8FwmHnmbeHYKLcvOv95uKIN5cXsms6A8ps+3U+o4epqT48XmtRvYeDLVLDXxrB/hvG7Ewtsy7+l4B7FYq4cTmRli4vovg+6dqZa7J8Z6TeY163l5vi6HNEWcPMH0wkmzeOofYTBux84DiP7+2L8PRsDAym8koSF2rftOWZN33KeJN7nYZQhcIQHSZR1MfpHUVekKKOZjvVEzhb61UdO7AqZaWCdexHQ+r54Lt0gripe7z9DM/EDHXVhfx13Y4lX3VneCOgXX3HgqS1CVVMvAPD0J6SlkhUQUi46Bf5hwBIighgGHBjiqXHvclz2qvYEfLZGGU5QeqDTQMnAbT8CIguSKOKhKGVWHR9nSGTqef6bjNuz3Wwh/rGM2DIvhzzC3wKQPcqIpWQwLopa3sFbzowKJxfiNaSP9ce10RcDZP4jdszPp6gwthXcuPbEv3LKpcK7oOVYrGzWOcMy2ZaPf/mYTM+E/XddMuJWAXholoBBeuSD2e7GXxT65QQI6jRw0gtd9rbPeQ93IhdpAholGM8OKaMQcM7Dwo6cZ9g+6cJP/Ws8E9WLg6XVkDFmO9+WS5qm+BMJrWuRIPiyBGH0JRHISiI+t5pDLN8JR3iyINAPQjtKgzfgX0rMv6U0LdcO34bRHve7nMsMSgwuZVQm9wIMgnP391pAZ1t/DDIAtO1bB8qM4t7Lv3BJKY5Tnj9z8jId0wJdP7GR1u/abzZ1fFzYFbDpYzMT2t/7uW9cqlurDfIn9JcwLrw9nNHdS3GVEr0PmDTsk6cI+dWPjQ/arnVHtGvx4zkStReoa3167btAB8fp+B8SfyzYlDn6R/SHYXETU408fYFWXTTTyd0jI4yenY6U4IJG/A+otT+yxWswmR7Ba7Ojj06X9PkZAw6W994HVa9nceG+nVFr2t1Va1n41VKWFedj9taxrn+scynf3SbPky5SOhafaY9EHtSxvyLp+EZ7zHNVjef+DVY9lk73MvrctvzI7KL/y7uZZ68uvfKR1zta+su0l/j0bxcLE1iRXPrV9kivP3mSvE8r/99l/RkyMxZ4Gx6+PDzRDwF+5H+WHN1v9UTogj+x0QFBkeCLzF4M2b4qW//rOpI2TGwXC2r+2+h613r5Hs933cHrkhTmi2DOoMPwGIs65tahYT1S/+ZONzY3W3rmZnjCRd/tXRBDRLnkX0RB4EGmXbBpPI+mV3Lo1vZJv7ZBc54ZGO9VNRUrKWxcpuXcbS5NTG/ssrX1gA3lgIiD3P7QgeT714tmZWnOLNGEmWH1g6s4/2SINOLen8t/3WwW6sEWary/lb+ryqRu3Jn932CH1bQgIclSX5oWQA7ufdGk2yx4DUjTX9kvR/HJnUsFVGy3nXZvLz+RrW1UNvGW99f5B77Z+eP+2/vgQxZm/h+IMF7si9lbYrsRqCz7ZWxHgQ4anliIbrNC/GV6fK61tSb4Ia5MjUA1mcUN7jEjljfztBLjI5GsXFne+Mh1yFWHf69Vgbpwtqs1LvUYS3hg88SyLK5lpH9Xox5Z+d1mtVgsiAPjsUrb5CkJn4+KWaKawR3NMEgCdAr66paSXveYzgK6h5Yj+lfTCbS9X79sogJIubK7puG/FTu9PO7OOBXc4WrAqmlVh6T/gpDI9PDCrPaaI+DlZlrbR2W9tX/X66s1sx2lq+Cd41nJw4nslvLv+aRt8+B6YQmQd174XnqFr3w8egATUXB5w+BvvOPxdup7DX6bf4Y99+zaeS7/c+Ca09iZqAeiYEBxsWwByMQVjFRdyDCDHt8U+TNyQMb/qIzxc2gblotQTYVNtaBFoMD4MtbMic50IdibrHuLQFGjkF+jiEy5AN/MknMwABgI+QagzMNcY5BN4lE6ACjpiFIB0zBM5y9XodSp4s/CbYz6BH0YAhDjNCAQvBOEesh+mqwsO7Ll2aa4ryS6gKkEh4hmWbXIa/JFBGkbtpUkXITSZRTsvRNAkc9dMFdBw+reEyoo5cR93GeC6GN6QLiFcgISsuqH4Nca+M4pvEPMdNiQOMDLfJGIPToMIDNyIT908/pC05tiuqmSyGfkOTtV1TknrhsH4loSxRekmqy6hOZWWeTWT9ng+X8nFrRI+JfmqXdTfojQUs2C/EZPSVi7pkYUuNKBz8dKIIgDzc4xr2DAtZtRKtaKF7ICMjK5tup8egGqlZoOtDFLyLkIQYJnj3mJu5bzwJd5WvSAg7xQZxzv1Wfj1SLErY8/AXPFHERXoI7gAob0uw+LZUANkhqH5IUwb7Q+75GoY2nha8fdyoSdAJFdad7bqFtgyiesxcRo0G6iREXbBLeCNEK4588+WpjH+UqCaAl8xgoI1d76ZMUwXrtHgQmNVrzZ9w4S1khTsyqWJszTULwU+nRDdxsEFMPhd5V4rsDQiICMJoi0p4qu2YBoIPpESWQ90HJz6nVAOwnYarJO8LxPS9eNIjsvnEsm9KX3GhfSZXHTmroI5tw+xK7C5delGK2Gn82r1SOUOlmSDDGQgQgV2ZC1ZcDybIzmh+QhiHghRtF7zwEjtumMe+ChqRQDBLWJE8NiOlxOxIYDieq8NwbuY7N5MOS8/kokJsTL0jIgD2KW4tvxt7EexX8Z+G0YLbr1nEitMb6wwobIA1TtoI3Zh3yxY7rUUWwza8F2j5mcZgaoY1CtkupnSHIh1ep1KIOHdLbZcaIluwUg+Ye3wIu8c8eUgXQaLy8zPwBLB8/cXo0DzSaAZvYFmtAJtNZdOZFLdgTaPJXh/X5g1v30fWtOJKjzJnggJMmJJFnmSeXe+oM+JTHrOAjEhK2nMm5AhrGDcT7m6kzJsAsAgfyG+fA9aA8xVso6eVyKBnuymRnb7EJYOy+UUk3Rq/oNPHGdfgB9xyg32BPoUAluQCvbMZZYJW1Miwwa20rWWbKWzauVQ5QqWtFzT5KWYUAZAkXnHtWhkrn10jtGsGm3D5QNrSVcLyGQMGshx2U1KiRAwLFYv1jMJ9OafqOw6tFvxytSZnjGTOc0rFkp+egqdfTwPt1aatQpI7rKUVHWGe2hkS7a8gS3Z25hMLV3S3fjlzNqXq4rM7IZjooep6esQzsux5wA+/m7sp6c13spte/wHW8qAI0E+Tm+aZB+xJQepP7LCaD/dtKoE6l/3RfsvR0+X6gbGUew8MY4a706oW3aReiHDBDPeKOn3IT3plwR5V/p9/UO78+p5vXl1C+5RxNuvQVLu1Qwt2L7FeSjYbobnz19R0g/O5TMo2bjl4SUbDxqThe/qt4fWUHARcXG/JSaPoRTCYm6xOtsmM0JUpIXfuVWk/RH5qXhRjjcYPh4nSLXgJQAtKgJEsrl5VF+iCJtVMCMwWcEZBuokywL7kSh7KeI5RNyEGTcyPK6WKdLrODpWACfPY64ipbkuB0kPhfouVLUY+kiDWcHIlplAKkGxwyQ818NwF8+sfYyRZLPMETG4y7Fgj/amJ+t6p0B75CYFGqTr+gq0+wTTNnnUT2/GvdhI+Q4hXmYqrh8vYKqoiSFXPlhwNSVuERnJ//lZXBb8JR3M4wWfPU8j/jMwcFXG55f8//UPeq2cAl9EHZ+e+Twqs+VzW9/7HfUT6ag2szF/n4e82yUQmfxI7Hv0tMUB6KKQ7k034R87+abzMbnLifSPi6u0LvO7j1q3+xq3nyFHbq9UYJR+/JYleI4AEtFlbyXUCOTIGdzd064vkcvlBFfptLQdYJB4S3jvWY7mMCpTRPMh8+eiCHsshjk/AZAvpTllvTqecFSjaKqYG8KogCU0EraawBg1ZOEVzOw4Jjfr5zm2WLkbjX2RfW02qRLhLyiOQZ+c+R1S/Csq1oHe5jAWxFFjXzEh63pCJWMfxNrXl6BwQ9g5GZ3e98xCmhxFj+hxCqYJqTFWGr/wmXd0WuC34XAVdMirY/3jNpR0FEeU2ccyjDVr2Y8zGp6tC4mKO7+ip+EZrsplm4xBuNIukEgVXVUWAsVKKPlcEP9dli2mvQK56eJ6h+IN0yNs88tU7g+i7qo+NjVh4P3dSc0GIuFA5uG9XsBxieyL61TcGg3DxSVULcebc6ngmYHXWwiyRF1Io21z5u6IZSz7yUAiiTyeJHrxGelm5B0PeScG76LrQfy4d8cuig6qftqIXdncB2kf26gNuw5+cSeug+dYBVfihYq/B2MrG1ggNZ/ec/+7eofuf82fql7BcZMTN01u4oAkexPH964Mv+gVTn0ec0kJXPSeBi30D+3QRe9MfIuG2tb0X/F+dkZXPNQi0sAV702jehh9sS1xTezAN3Cyab59my55fVVG844R/Ix+22Nrc0Ofrc1LunWsn/bHnQsegQJ+BFXjlrHRh7cpQvi+CNl2Y6NtBwEASA7EyH9tNj/z1dOMjadsFwCw9o3NHY/u7gmNK/pC49ndofHHXaHBI3l8h3OolcLNsRdjQO7dg02rMwsWYWWx7xq0hQjo6VwtHCBvpSsiHt/fxmLuOt0IiX/0G31x8YejLvuAjULzne04iItPmN5XNZTS/sWF/WVFKe9nD7XCYiGlr24hLPiemHhFz3pf0Lfer+le7+c1n0vcGznFQ28LPo2yhymGdgSQPtd3EELx2HEUBB9AatiSRjAzRCOYfE7cmcJiGHCMjTZcSXhvl5KwOWYx+zs6wsqU/7adqC+av+2pG569rsrw1PJCr8owgmpAYxi5oDSV2aHa45vDigkiMJuDwOyPoD/wRMQC6nqP9J6I3DRF4GajVlGwAqVP3BM2kY5dCFrapGzY7SJX1f1sl4jWIvqq+OeNCukORKu7zL5ETUOURTsKkU5VmXautUo2djAzd/WcXTY31Iqdu2qecWuSNWlL6XxBV8Gcko4oALkmoDkLlf1ySizJzPeqS3PfeiYENSsTjsPewRTNbK7kPVrGj4J2uXurN+lhuvhuUiyw62nDMszLkqu6t+QlfI3V8exTyg1GOpWzx1FZxv0AksMMmyzXkxwzZmeTSePwrtRilVIJPsn+DBIPD4fgB1H3xtFGBb3Z1gM2mJZ212YqX6tzg8+3o/Db9Xy5UCsm27WdO1IxbZAe1zm8Eew49jEEbfMP454mkQW4BgtA5rkZdtfvT66j1jUxNgHjVbcu4Ws7z36/509B5hkEg1JSKErMZyrzM1NtHZiMwnTJwMC/pA28fwl6TdXxIs8+l7EqyWOC69hxnjXOM/IwFQBXcsLC2xGJzlvQ1t/y9Gyov3W2kGBtRHbeEE2Zge6rbUurQTGNUioOe40UFsYvVPzmsXRwFp8t5QQvxUkTftzzHYqpS3qiRq5SH/BzzuxYYYYuGpGgZGI3xF4PB5ohiyZusmBYro5S7yar5ZwJuyRcQ+TIgUXEJZVhdt22zgLOX7aAbDnK+nlnRB55NVa2MmHBcu2l0dKCDMSz+vkqtNugWE2X1e5Z1nS4rGO4tIXLCis0NlpWvxQtay4dLevay1nVqOqUHJIJjgCYAyhdIWOswFcwrIDubb6MIVaZfPaRWOKZhjHmtwQf2VOxWzC+879AFhu2yq2F3rOJAh/1aBxhqWvRjttc0nHIlqQDj9n9+1a9dfZko9pI2QVx0xVtvjvabs1bR9BsfPHAlsT7MGd0OmWhOMN25AnBKiU2249ctN3WvrCZNiMbJlHsx7dH8GlnKQhk7y12nJ4W/RbZCgs4gk/UImkGVE536zYojDeYGGrtXXlP11p9BZp2T+vycWIzxMeJq+dbtlDvGdEQ6gtoBH5+86080b3wX8XCl4AyDUkRzc+1Ninzhu7tKPuqw0g2CENI3Kzmeo5mJAm3Co5P6mWsl3Th9cQTryeDKFUb0Ok24UgoMzL1eoobmltnFctXT2dfM0PTxc/bG5iS9KB+939hxXAX5V5h+3aXLwQBb21ioRHdMYTe2mTY2bnS2pZ0mCYa44qcUxrLEwx17Wyp4TGtl6SFzAsMQIQoZACZK4Ll+fK1ZskGsywTYKDKRqFSqpIF0ugC7VNMhW+kXehZcpUUjCmZn9SW53NmJe+UZxdNCJ+T8StIXuqhnh0RFCwuzS/kgwkV6ndiMkDb4aqnw6EJZY3N/iEj68l03r5RwngJmiWsLF/j1BwFbyjByo43r9VrcFtgNSXw/cQR3Q9SZqZTuqRQujRfBp5k0gu17ArLaaJlF0nZnQBgYdUNUhM92jIxRKbtnvdninQViITVqdhN8Ef/ix55O6JPRaaGGuGs07oCVcQHFbl6BJG7oQmarO3IG7aVgLsk7T7LzFw1YcE+XuTW06Oa9HgiSMW8dCNZu/cPZmx0Q3Cyi/iLUQ7adlpua9jZVZ2iR8PFxbCrYJGwgYQduzKQutF/hukoxvlGKJi47nrok5yJ/PswyLi8Z0t8WAwRLW2oPBduLyB3fRJl66x1jwXCSItNsvDWZMoyl55kg+MXnOOYjkriIfBNhp3DhBk62wpXcCfcuZvmmTd1CLKfXWfp4yJWcitrjxRc3pTrqhAXC3I2oNOfAFmTapPJko3xMwQkqzpKhw372N4sigiQjThpp7DtGNgwC4cxEBZMLbWEKyHu8Z7WiNEZNs37UcVR1V24rWi7OH3zH8wvznDwg4CLAFze3AcisSMJvsSZAcWXV7qZdTQW3tkzznHaoxwEY+we5fiTLvGXn20g/hL4sGx59XraC69vaS/ci6j8cGc4A0Cje+qrCMVT8Iu4Hb2n98U+OLJjxDbse47MZodMeBDm22R4GncLflTk4fY2Cm+rdUc+OYo5RPGM84BoNUqea067WM+1r4ED74skBRESPKcXraXb9xy8+0izsKlQ3T3RUZLb1AfifcPPiO4MsfG1+teclMwkbZ2MIokSbFlQC5IrArXURhf0UxvK07H7OqfM+Kl/QpdfiDVQzr0ap8yIdPf7D3wkni0bEeCbP9x5mHF5kAt/Qz8X/hfwvqndn0giaUt+AzZJHG1LvonaJzxwbclNptr5nrbCGXYicRQU4m/qOwheNCoH//YNJ9aPdHUWtq/BNFLzcRM6/nx3v7EAh6wmlv4wQJT3xT42CoW7xVsIL+SDFO7tH0d1thQUFfbjZsAnKoTQvcud8dNeOMVZ9fOE0H1v8yQmWIJwnhOEbr5CGjKUzv2XC8uaQarCBSZ/hgN3kEf5cF9grY0YL4i9cUaPhjXLwXGIAqKMnKTeTuB3e5qZIP+4WLsIVxwQIdgbTnN8rj+21jbmUzY6U3GkGflttKIIf+7hmN18TUshsr8Zuc1jmVtlz/U2ISu3DHQhn7/9c5UbLvNTBzqQH+le9wFe3e7tmYz89SZM2T5KHZvpXeovQBeQg7fKc7HMHyIMuy26q2z/VWPzQOi3UekLhZdtzVWFueYMA4WONDgDh82GwfLMfheV5ie7g2Urniq3I452jRRHv7NhivjFJpynl/RYqLCXM9l5Ekc3E7ElD8yn49wkKoz/hhUjWWhCo2yfJpFz5eoiHUZpTzyS/+TaF0niEQnEQYzqkwAXhmDAa6f1u9jDspuJVCV7jRcjzl03CbtjDlkbYFFRdxZQ6eDKshmXCv/p41J9SFA4VOeZyqJop0iJkeBUQVCFp2P2mFfhcInnCrdqlt3vjus6SGqwCqwoiLGpVOigIsEIkQfejBlJ/F8cxDVFI7I6ih4ojgKwQSaHmoQpRYN8XyiaC4YkGAkXOpMyD2k2jl558D0QtHglTDzr4DKwq33UK12LjFs24F/RvyYELLAbLe77FO92bBHj17iB4KrFKg1Z82SHyLlzCu7Hki2PwznR0BBe+OHIP4C4pCPcgZ/IjGsSsUuE+LuODYTaWE2ZBLMxDBUBJUBP0pNlD+i2rBHyBZmgcGX8cg1W8EwzYZHPCqiqJc4GfisT6/h7+yhbkasLp5Yqpc14W9TVpcPbwv0meerfufO4QuxG0MWHms0PuDojvLsZnARO28u0XYG9xZ4xYKIcRyevouDdIbIWc7dVFojTugV82MoSkOFms4oJBkcUMJ9ryen5nJS0lGzGJ1QALoXLDkLlYtbwrRyyOsPsroQW4gL8KFVHtaHeh6CzMdn7P9vM0mI+BTWeBOVnGgVDTeqPtLSQmqm6Su5gfpXc4FvUTNx0xiVBsHHZhpogAMkWTZMBKqxaGKwllE/1G4SgRe5uPQQtNEd6CVpbIhLgiEye+hh3kgbHM0Hr/Ers+zseIK0mCW7GeAXgI1Qhl6KwixRHIWqZozGsWsqY3HylTxkzG043kGHAgLBZ6mWwu/ydjCHm8kyqdNm5C9ApLBSC8wq+X7iY/EkCMLEpfeq5CDMijinAQ/XlE3vDO1wqHBBsB+OvrFSpURrbieBqPjG/6iSF/P7J6ULOdXNQ3UxZKvmTUWeedHFEkprcgCTVvCuMQfCX0Rt4hRe0Y5TPFqkq134u6SZTyVQuoDnpKzTsjqJ985mBqxtlkKwjwFVv6W+FggddIwk7G7a1kSKSfTtgSqLI1Yb8Ix4e9A+Akr+reTbScqqPkYdupkQVuUDLS6vN2jd3MEov3CwWZxCK4VxDNrDGdRkcekh0TYYSXW7QUeg6SRW6ZpnXbH84mqNEHCCAJEh45GSrAbn7y9g3t2IPvKORsqVzbQQ0+PIRUGBmZgej5vyRj761T4ziZtKl6qUMSnoxP9r+kBK2xrB7wWZCX0mgCCT0nNjjMND8/iEYwoMpyAbghfMG8IQjD4rwef5mej3MMx7w2HjDgIpPEjgDCYYLQY35fniataWX+cYo80ArBIlsTxM9qGKHfalbNFujQkK22qjmxBEHhkSgfx8cmDxqrj0oQu1C2dHRabQxVaRzBlo5BsemcinMFolktghYg8abLgm0hJ1gEnS2iDd1dwxvQHJtPwmYgcG/g4vQE3cgJg92x+TMZoU8C6zr+7hCVqA8SHpYYfTMsISI24kk0HDrbe5tSMStk5ghTFyvFqpHhSrS4TzM+sI/62lHd0ksMG18LVRQ8PBTSj6m68ATOMyKCcAGDtiZuOc6pg/b1PhhRvI8DwRH7LHryzO6yEJR3R0fIwLZiiRZEFiP6yVETkJx7bJipLF8asKT0QorF2QBMBUniCZInjyGlFy+ni8JusfL6IAqmFm4kuWAmNueh5v3yfRuXUmWa/ovf+0v6FZCsuYC9gDapTph2QqmOja76L/oS3qtkgI5Qx2bnrZOJjJaTklj0p8t5vjfk6BKn5OVFOB3MbU3pxUSelJ1ICNeVo2C5dasMS7uY3LMyOIrJL1ezQvfYgnZIVAMnCiZTAqjHyLDq7sXaf74EgiT5BJ2L3GA3uHtz3foL/h+y9tJ26UX/E5LbEfvW3/QIerikZ45T3cIY28Hblq3t8m52bMLeEsP7aHmnjcCNXdhCDWXwl1RD43G07e4GRpPb439fMfjicOh1WWQQ9H0oO2QQ7+m1yOn1Sevtz/DbENI7mSwvUwJMnnLg5dM2yHHwAyFWC1ZBducLNAPkpNBl0mOo2Hs0ZpMEy1/U8hMeAZ8LVw2diZRuyNX/wuNjI2JgWwxr+T2hi451EFu12p6JR3Ms/SDyrnVtlPOobzDOmrSSo8Ry2LZ3Z0mH2eZ5TMN7aisFqOy+m9in7vfy+ptyY39xfbtA8V25cGaF5/yQNTfZ5wT1z7SV5Kzsdypb7H/xo3FjsX+DQmwTtauxRzcg06Nh0v2Uq9uQOjJ1SMbsEQEm2Euvo8Ynjz4mz7sw/RZ3Sr4Es/CW0OX0rlMeLRherclQgCouE+F4IYHaW+HORfxo/tFhzZAiJhTqpxOL6Y2ETFAXASJQqmgwHRsnfZOdaC9U79f2zs4oacwt/RzLo8T+gWUD7vDPRk6wEQzaL2LljfBVzZVVQjTnBWlxejMXmbesHMJ7DdkiglEYofP82mLjUozvMrsJU98CC3O4hYpzt7e5k5nS9kWd7pkGVCX5VgRvWlDdiVKnmY+uf056zN0munZRjGDoX1pMgBJPhvR+pQqqrBvryOjwGoJQp5+e0ieRkgR9vQtiIgKlU8gEfF8nHwjRwRdya33YLZPRmFLIVEaCImHdELi7L6QyHfOtBOb6Se8JzcdBUOhWmgFQ7mbSA/jr1GDgRFUZWs11PM2F0+4qycgbusj0z+pJx7uDjMEKqExmNi+OvaFqEMibD7d1hpKv9/6InxXeYSuzQTT/jaEV7MSan1Fyne0XwLLW4H9EpgRPBYZwPDBQeeSVzavIc4lZl3GlFs8W4FI3VtatIeDf72DtdNDw1LJlw1NN+Vk0uNzNT7u+KImqTOYoolzvIe5W0mP00l0lLyaZWfEcNztqFIj427AK+K6YsNDTKhUL9LTGHRrMPdtHHTTI2YgiB+3g+5oq0qSyvoNBNzKoYOA389nTccRZLhswffFTNSVlfz87Bxq68ypH6AkyqNb8gzglF86zW5Ju0baluhZ3SjFuEKXSscofZLbevoknxq0OuHQJ8l2xU9+JvM7Zh3BI2vxM46eN7QPpEK12JuDYEZntQRcbmk1SKZ7GyT/Ndgg2dPdIJldmG03SH7YDqfMau5RloFjRTwzuLEnO93al53ejpCPhD6uad7d2xrJ9bRGVJq5fgy1F3KSvYS4GO5wbTPMqYLbwKbiwVLmvLvfuCJvCrA3FFMlq7g/q8DQruVbcaJhFazcsdqxB7Tgaf5nv5lFErAqJPv1nOJP9HhZLGY1T/eFzKd7gur3+2ugF/eceY8Kb//sLxA55Pb/HMK5vp9v/07/zZ3bSrRcOXDNX9258PlB/0V9duToGLjSP30HouW+3ht5X/kzQj1M+hkO+hnzsYuhLA5eB7mo0DnZxZYbV2tmkXU9K5xybGnvMt28vZ4JR7L6O97pYN7apuRlEnOgtKEEVdCXKMGQlsVNN+kLuNMqGJQFxZJLCMgBmmHLLCHvwYkUpzfTvHJHOyDMBbgeG/Y4YeJ9XssQHh/sNrC/BD+w2Gbjkal8YLhcXMjks9JvmH0nXnHsN+k5T8MVneOcJJwQru643S7IO9ccIUgOkY4ai52I/WyrwlHcKoCcRq9wFLdaX2L+v0Bz1pOcurpLckrK5nMSc2VHdAriqIDQmuc9WAd211erGpub6VWrolWFNp3p1auilcf4kea7Hszgzre4aVoAvZXogv9/0H6hKbRXFa/S4kTToy98c2zr406hvpMl0lu2q+vC/DdHFH41HIIuNENE3DWNSilNqI2c7aGDBjShVsoIRCCNwWeQ4VIytgEXF+WCXdyRcuqibWq7sO+BNIrNNv8ayuu2IKuiBr2BHDFaSsBdUzXpeTsNi6IEb8LJSCGfQLFelCRTIuQHKseW5pLc8di1MC2MMctRLkTcwd17pUWLYeqVBsZqaTxFZNcorxHcHIV2nZx/BGRfbjFsSKpeCOUZmM1E3IJG18tS3TfmEuxmRauWksyFYl60x8pJHBKVcesu4qUjGvXxhukUJCFbqqhzl4wzhYlp05ybn9E01s6b5jjs00AO/v1yOmgQLoCtiobMeWk0Sz+7objbTeSChheuQOVi5vwZu8x+owIPHg93MzVtL2OBpWQqQ0TFshLkYOGnWioVTXeq4Gq8IRXOqTN+qaKpOZux3UI6qaq5YsnSAweWBHFI2gQOYeOs/dV6im8s+2T5/1H3HnCSlHX6eL1VXVVdXV3VVV1VXZ3jdPdMT84bZmdhl2VJS85JAREEEyieeorhFEVMPwMop4IZvTOHU86c9cR4mAAxB8zgqec5zf9536rOPTM9OzPof935yITunu3v9/2+3/Q8TwiYGyWgJqIvoM3PBmmUMI2I8mJwuX/QiymDq7v3iruznWs/j51t13nvuMvWIIVrPJiSVK1PK3Xl4FLuyFX29kq5nzOXTcGpyRM7FN3RIGNi7seuwkxVKgwl2AN5kj7iiF0rtw3AOzU3uJA73KZDxz2bhUCAacuO2lJ0R+7HxNzfQ1mr7FCsyVpl6xmPmGiX9yh9yCT176zHSSVw5oP3IbBMcI9AnxiTA2thzstW0FazV78ohD65rdB9Dwnd9xA2PByWZWEnvxcnZLue6BLBNTO7LDQuLn+1aMZXFisV2IjBe40fg7PfLY4jBB3qivrDNOoHorYlIqfsvFLEGPpwz+q4VLTiUEkP1tqvFf6NNG1RIlGMudCegzpXUnUjGpNuw3m7ks9VhyQPF4Rlo3CsTNExNxZsNSwgSSka9YvCRlR2RB7rXlX+o+GKng5qxSwsFSGdYVz0mnCBKFjwoCTWuhviEQl77/KT226HyFC1HJlovx/qWQ/Ak/aToA78TnOEVX8EfalgbbwshE0x4EYDQ2PDMgnLbjKpGOhxBQQ1a6SVSBDxm0pZ/69wBPAbdNmD4RBrHtyGHXl2cBt4Z1qpVPEF/2uLM/45dmd3NY+97Fm8iATZifWmtq0v0ByXklRV2lPcVs3USnW9+6C61JPk+qRqjayEESqk2xLkZso03wJv+7/6LN2ZZMKHxMHJei4k0EREYFUJ0V5yyAQjWEwJi0I4eBlkOwK8FJKNUAQvBYE34RUhqLtZYGoWJEOOIs8YgVcd0HQeOYBEk4egGgI2ENkeEt8IUmHG0BmImHmzmNPimooRj05/DPQkURnScaaox1SUPGDGMROKqRioxSUKTTsqZEigegxa5GvQbcMPOyHd1T/DsuyAgAQUL2DLMhopIn+n6iqqKSOXh/iFLockyiQ4hYVE1EVJSRFn4LKypIsADWh4nIjEvkwBcPirQk0Oaboomco46khJxNkwJTUgIaDR/B9xiKI9RfA14HnFEPwtCKkfDTebggMQNNC9QxotoqFMCwc8ZUASYEKVMhEh0OEqRZobB6QyqIv4VUYoRFTCc9UfpIJndhLJMl4EdyPUNfDuhKLBEO1O43QCwqYFXwKjaLjXFMVCdsTTjSWWelAaL1xs59FY1kbiVWmSN1X6czfBNwCRHYC8a7svyjZKr6/wAffYE49xwOelddN55e1JZ+bCWcLftBaZ1/u3955sMnxZKZtxOYlhMOy0EXzlVMrvxUchf7MGwRf5zvbckYzx67fMHy7iXkGX6rc9zbE8P9KFkie3ugZjGH1dd6ZjbtoGOPOnEwuz/HXba8MF5kV8xHZD2QIOdcPj+jLITeLKiFBgmZokK9+vQDSLTzuiKWp6kCHtC6XsJNmulKeO8twppFXMPfhk1s42XK4fqdzHWgPUc2I+dgzJMhpISMZZnPge/GI3dwX35Q3xwLGvoSQpVlhsKfrhJNZpWCCjwQWHe6eTC25N5yt1O59HOtjInVb1vhK8z79JN8gPpxcm9ozgTast7l0clvoFGVh82qaUgTe3SOK+aJUMtDai4fxiJjU9oDtKirCeP8oSc8eZ9XnjHOYUYIgLW47G0l9cz9TwUZF6Ib7fIo6TlJgKVzQEUfVcESUyXFFjrmgR04InRpUiCi8EJzgTr0qhuBoxeH7Y88RgCuWo5cQpmWSAUD+0GP38D4WqMIlW8neJhMEnO+zYe4CTwEisD9jW4YAyLp2rN6RxRxsNGOS71Dscv3cHnWZKMsncRGiWw239vs5mn/d3gmVfXVkQ/duSK2Q/wMcWqfssk5hLk+mFttwMxJWjgFnMtLceKexiNjYLZ8/iSlzcxf4d81hhQ9pUKni1AP7iV0+TS4LIHNCciyYy+geWTrAqiA6phALKNmQAQyg09uaSsiFFbSFiorty8SNerUbVfBnNQkHSQxC8nTj2wumrXxZJ8ymqrGRrRFEhNKRFEiE9FqbJiEaXqs0g2BnADRFOgPtTA7srlbBipHQBdNYOBCnyMYRcTFKlIzKRcR1ZR4CmKcFkLqclL6xOjwpPtIfBJBqUVDAygOPUnXALdOANhQ0xZKpBp34kjCy6Y/GhfUfur/BaJMyjM4dWuRqo/3I85IQCyEkQZyg7qjPuTJrpiBMWd1JlXSQ6yBlkVQnwgWQ2LaPwXkTkyhYVOzSO9qhZ1ij2NsCfgEZh0HRAt4XXBFU8nJHyh4kBJE14G6nikgyWO9BugG0NxQkuSewu4IfwWZGmP+DMoD/Og+5QDiDOh0TwEABA6cZp0y1GM1NZjITQKKAJVMBP1NB6DdaTbI7j6brxcaSaQYE1pShamF2Wd7PLcol7HaW+osOyxbmBEicZ/fO2kdq2XrGU0YTWnIzRhCywhsBJIwcv3smvmywRsnD+/kqzWF/c3ps10d0LuLA8jUGH5kbWypV0nCk1NTPsV+x4re25TPOGjuOBRV0d3gOiFNjfY8ZcAL3Nq+igvbwxFkth/bZ0FTJsTUYbXKe7eK8rvcjIikH036fh0NoxG4wlEwOf9ekrEbEYfWXVzLc6A0lgeEKXdjabZzIkYLlxpdEYIKqmSwJV0x6nbKWumXUh2N3Ve5hpdpzr17fRY15vj61CjznVxmP5wOo8ljJtGhDyGXuk0SFIRcIJ/ZL27vF8Nuf3BmS24R8GngsFmwYfUMPhzs5Drtk8vncQbsw2D7mI+xfunQNNIqqrTSIGs3nDxfi56b4+OCB1KvnFAIbuN1ZoGXnX6lteqSYpqtjlbyvnD2R/8sA6Ju0cCAxmU77BfgpyRf6iXq+6fTWb39iw+ev8XvHdmJdO+0sUb++/RLHdEb+z/2t5r44RQpMVtYMUdamnL/tQh/oTKAFqfGgk2mA/1drJTy+vLebCwcyOycnFjKJkFsn/bVOQrxkmtqmCtN8Lh5SiZG9Aj1uuqzCOU6TPLYpTVhR9l/+pUAMt1Z3/P6GlEiVb9gS32WINMl0s1QCEumg29zlYezlGfzFs9MkfH3SOfZSd75hj17Z5jg1CKFMHg1jMpuys/h/08ET260UxiIdutkCmV5lSl3um1NWHdEr9RzydMYR9EV4s2HiEXjLLByujZ40RREtJCgl0nyCkRG03tztXqzFM4Y/5T2OovYM7A3SbQBh7nsF8gqr7VCt7xAW2mkFmfZ+hEsAZAXUJes6UJdknIkN6SqE3zfuBcuqK2zsj518GsWak6YB1qxriZz01asUFy8TILkCTdwlVAG9IcWshHMZ2EtL+mGkk7DBN+yIRqjbi8PVvbt+k+3SB1gmBcNlCw1rVYs/TLEywVErDHxTgcNSp5Gg2S9UY7g9Zqm7jVESx/mOqeeJgpSIBvXYx4+bv2fpJNbP9XfznsYKzn3sz9/lBiFYbpWyDqyf2EO+kr0OyyL8EjRfK0hOqn9W7ff7C+hV0+5x2XxjNqs/S4xGtvqbRWTl05zbuoc+vRa44g/KvrNGWS97dhxk/6HlKHj2Paodb/DxHM36eMnnD1rvEBWtzKcJjEhhJfQoecyV3B1uBmfFunbS3k4vIj6CP6oLdVl4GSLssu5o9jlY3ZE9Hd6/U37vge1h5ma3+nd1qb3osiTVvOZ5KyCaxomgWyEosksIahpa2b3o97hra8aP0UDc22aH4ENihAlpu58yzEYkSXtNPbrodI4e6fldSy8r7/l4eR3KyHhqOX5rYFQtHAqFw+kAuhYKdgK8kFZLB+QuPrKAJyJOMSxf64JQR6noN2t9gyHNKRxE/8NB7I+OJ4j/DkA/Pg67al/9BeKLWc6cOxEML8FBqAzxc2AF4eFcv4CEHwEP57+U2Kw82oA7loGJGG0iH326ACeonW+8up61DBPu+Br4BaXYf6ieBc3Eb/tBH6r37IcU3UBFUmUo39gAbsHe82OtOHrsL21gXHPKibdzUKy22wAwfVuOGboRuQgmbaWAYTqyaRVNPJDPRn/Z4DExIXcaAgte2bNr9MjXbAi48OWhDDyL4mHa8wlJai+mqxqv62Z2+8agaxuxWFLiMEJbZ3WxeQ9UVR329F6JED4PKNVemGHGpwhplDZMszExPxRbplrq3YEn/luiIqeLvJ3uKD+zqatVYdAGTSWcKPqZgnmwthy85AZTGlhE1rEgam5KKqtdimNDr78WQBi17CfsTJ8JImNWj26KHwI8bFC3ZmYjdoWXCoCtUPBLagGJopqklRYO8ZjPkuy+BtNpL8UnI1gumo1EJ1LwxbYpRRtXk9byx9h7KAs2GMger8DiQohCS9bSZXkzX30Uy1VEjFLMN7DSo+Sp5zJaS5mYAxz0IJZmTuSeD342Dlo8n3eH1LejegUtFppCx7GoWyLS/bcvgC/ePZ2mq2Gp2eNbBDzO3ELrHxywS0PlxoQnNtTppuubaiSc6aSdL/1U4umyaJG86OKlD+skoGNKszoMRA5KoGDR1pXbRg+kcvkPIg4oKPQ+6BRLUlPSJOVRpfP4Mt4MWp10/ghxsQnALDCRpmBGNUmwxNolMsMEkCTIaaI7wlGCLfwbWZkYTLhAoxPvDuuhKpGi6O3fvdNNTcT0aUPXsQkmQ5bBlqRSBwNa+7bJN+JXLS+5L24bBFGJNobSNUTH5lUcUofbliXgE3yLIkpADWOCKPEIIIgd4EjhH/2vQHGCrDV+eS/OdlKGl1dnYBsE8Hj8AN+SVW+Qe5BcdDGruqlxrK/dungWSf/Xm3GecJEvFTpq0k9o51ZbbOdVW3rk24SPPBTFC5oUwNwtB5Ra/2rxZMmNN5BElWPPY1WiHbZ6FZEa1JpN+9wRKGu+aQC204WuCNK4JHLtgzGzSqklYQ6O8anzIMl3dlY/EFMLVwtBkr+ONGdJ1LaRp8VkbSTm0ovDlQPhfKLOdSgex43oOzQYZ7WotSNB5wA59tGq9EW+brMFAPF2gjLkRXc2I+qHUDkwtQaIGDpH/daf1oOLxqJ3OSNREwz1m/LavMAo1PhIenhg36nPYdHixF/ITfsjfZdRM0ewK+bZh2qrUGfIzy+n67dB2GDXsWggBP1dFkE4++CN+BfoOx3CPp1JfbSxSyIDwfhcPg73H6r/e0xGfyepBYabZNu0JCsxanSGBkabxP2kx9tCUaIOUPTYLyvXwyNJqofsKhO6VdyV3ZnSNJHToOECy7wgcefxqWF2UQ2h+oW0a8LliVCmZScp42MeIg+m8CCGwUDC2HDcyqPiSC+ToJluPPjI6GtHI4zroei4cgK7nWm/T51U0uKNEjDiUJTrXCO78Es5/xcUqcPPg40MEYDAbceYX553EaEwzQKqcms4J4bBhqFTFnv3y0RGMkZlj3APhyAA0Wl/K3YsJyBZAZNr9aL7Lj6Z8wanFdkdqx9PwVMyrvKVe860tA8dcvKazJXXSQUHWdFVE5/H6xVvkVbmtIiE70HJGTJXJsZ3eaKeStEA4s4NQ7z1Nh1YSqaSy/PJNuh8dzNyDwYwC8qlbEJXYrv2iP4FZpNgJysLZST7VhWXsZp/qvT12k1Z9gS9vtLbgL9JTbVRRxrjpmSnQJIpqIg4bPFHfY+VDJByJpHfh1KuRXYW3+qWDoOaXF3oLh0+tVjicS5+ySe1EpyNhjL+0AcmdytUhkDt9DvXDzdSxopGqGVdmDbtRO2ykamC7YXfxPxBCyPT/mU5LtzrhI4OJxw1CteMj8z65Vdnc6wfUiyNfbGLLaX7vY8sz7ew6PrkFf83mcrb6UwcQiftbB5T8zC6uijd7SHKPreKpzL73QAQqBHLmm6hK3JbYd6FVyG38ahHar5XDt/vS+nb/VbvdF5eZ2Y/kD/PiYA9ruzYuGdgpDrMOFPwy8A2HezdEMpYktd0NH1rTcW5vd5xLEcWjD94LjrYAtCXf0LfRs8kQvDEoO1lc4nuw7PgiwatsWVyeXwVxvtyGODdGTbLUwpur1STt5LyyFYnHjPzhRGK+vCoyvDQy0okMh4PJmaGy2YkMx6VSmMeBd3Dgoyygv4r7/ja0bjZ54tl6Jt90EdQZjMWtgl1furc7v1Dxn4xNARxzym74Blvd+/QWRf/wFoWBx9ItN1FgFVw0HHDDeAPYl4KaaxATvQLqBcFYKBGVBUo/CVW5II0MFJK96RbRlsWG84EPA+YqogdUk9ZgoRz9gpZJ0DFXCKCmICKZYGP5ArPfHybzOQyGsWdM28MiW8X9GgC6Ye44dJdeD5+Tiq3+fI/PzXhUaNimayMpKtNuAt3UohDo2WpxIkDWheDGGghc2cNApUk/CFRTcWv2d4V95Sg4wvJRZziGBPAeLI/ARSjITcQitMg7oRBWQniZoqpzobBA6ldF4kbQTOb04iMffUmOqOO79u6aJG9ZBXBr4+2eyy4irqRPOvW4ymowp/p722S1Xk1EPg9Ca1FsugAJRfS8UTtxNDke1Q3scBpjUV4FGT8jlSH01qR/6vd5oNp4E1Qba4Bqp7JJQRrRXZPcRoFMmUK2hWLCZlGDqZFioXzr/S+stxcLc7dvDF/Cx3aRDtTIeqafbYs37dav+MbHT8D4vLiO8ZdZpGGgX+oA/Ns3BCWJFKePuuS55zZRIqcU9g15jmEzx7ir5RgB5hghg+6x0YAO18h7rvHEXN5MUMe48uIcMU+54DTy6na3+HHDLWLxeDSe0FFUsI08eMaxw+uiRlqQkKfAPzIxO9rmHyjGwjndzuXydmLEBGpTDcPU/BBELOk1wNSKHiQy9Q236RuOnvZ8IxNBEglXxNwL43nCViZ/zE5vmbsaq/SfHLg3PNgp77b0Js55b0OYFpPtLeHY0R394Dt6R8JEy944SBxoWHvNQPDOgQJBPdFoB08228FQ5UQ/+I9eP1ig7WAoxifN5FyzHWyB8266yXnHv2+1OOHk0nmnGSninZFiyIsUDwwQKepf6pCMDxjRSKDRBdbSTHH6c8JpgoYw8U8YIXx+k4GC/QfvScyz4+/hsZcp85g7icWYeb8WWPDyFOYEbudSdZq5mZdvlJpDwsYK9nyZIYlm8Di5uQBcYP4HnOJ/NCPGoc6IMX3BK6+uH+yOGNnanvOe1YwYh6DqrAWzhQxufqH+gJt0LPCJaLWJMT06bZM65nFZ4+DNpwAFBBxMQMLFKZ6KZWvsSnuy9cQuqZoTDuo78xJdkJUhGI8kDyvZdSi+EjtTTFvk6ZFcChPavFG/RUva2lwhu4G4EYlNWKpGwmEJa5c6n7VtLEp5f0aw9AjtWYy3PWsHNTWl5TH5jgOdY0UQstxhi/ZzEmks2+1FexLtB3S1vPVsuEoBEmq6ha3LyDBRYrbtIsHSYpF8giMUqsj/mf8VSDY5qyL5+Hua6TG3QAc55s3/YzON3VqWCAhN2WGJLjgBCe9Z0+farM7X0M9mlQOzKe0YLHpu5y9T+5rDWLRkV0ilBtbz35WOzpnRYjQ27O4ILh9cxiIp9oiDiqUANw4yU8G78HEaJXF6pjg5ayhWKLMrg+MmgPhg2NDoxiHJz03PZN1aWCU6iMWQEb1bRER4PAhQ0OJDZ03kscAaGl3cs2NctUddPjy568id4/yloJ+XMkkUD3Kjj4YnDpmRsjl1yqQ2PD5q8PF8gkL1SKQ2WtWwmBBSglmsJqhPQiPArEQoN0pyIRMFwF6xwmpzhEzQhibs5v4CIFAaNhNfRse0DQiUh8UE9G0NLK8MHF2JUr+1oFCwAy0B2Aq1QDcZm5vqC7NssL/gv72sEKDEB8XGyH+RYvS8yJ8jsX5L8CeNHHPxTjJxds0cp3voq0F2Rx2RIjjnz9tXbm7DX057ZNiRKGSVgIhBzsNJGhpFFMGP1qahKuO79y1NqnbNIRMXXnhuTc9QyFLejA07K4jse8GFIAIKZ6uKeEH34vvp5bm8wZvFMNPe7g/ORbzM2ryemx3299/5F9QO1pJVV9OBrpEV0zC0MBY6QmLDOCQaQRaN4xhKJm0/YuOUmlp+5ZVdK+6MfyiHE/ND7lzM2jkLx8NzY6/gqgme23vED/0u2s5T5F2z8AGPd4TZT6AJMfMBkd7KjUBJV22eqrghZQLv3xTzXHVqz/6laTV/sAK8RyEaG3H1tP5zvIkZiEApWGFSIJjNOyqCDf6tuE2CmXwWjPpC/TwlrKEBAvo9IxePaIxZiC8lRz1aIefYF+8/5nryP8S7vOwFFC8iP5J0421dZtw60ciQOfX4KX1ydhyMgAF0qYfKFdRSYVmPovaS6rjqtbhtR5iJKGcQUCASBQmyw/ATdE007kTuidy/0nHYFrqztT7ynVAsCAMZUjBIf6QHnpV/05Z5sz4Aup2cTKEdtjFuo/3RF92x98VH8e86fIe+eS3oOtiglWQqHtXpcgRCb6wdwuGDOL6GxXyNezQU6imIY7eAtxIxvtNcC0gMSLu12JvsWyu2WOiyVrOd4UOsqE06DbJANpO7XArQTeLuHYnlPN6h+iVtBjTBP7L7yKUJZr/xSx/x8Jqe9uznDDsk0jCg4hmQZXESBTOgUTBhr3wK5nEb5uFP3lRNQz5MN8GSdkQNY2CNtNa/Osy8EaA3HgG/t2X52SRYOSPhrG5Pz85YVgbwcxEnywTiEnloGEaj69b1xw2efTRxWBpX4Z7C3cp9pqeowJvdf+u02Ypa7eAiR2T2mKUtwXXvocFO5SCrJue0Sgs9qverLVQtyx/hd5+24HybAxzdeq25ZNq5alJvrpokWG2BVZMarS0QcGHUjG2OjY81i4uvOUDJO40IADqc3giAxpWi9I8B9e+secrrn+ooLPosl0Qe/Bb/K0HCTuHztnenUGxQM0l+idCF0nQYTDMGGcXmruAS2xWc2+Su4OtwTvBWyKqbNhjwMsiAlxkPeElehB7yizu3AZeN2ODbgO/s6ibXwjQlx14pwgNDVBL+wnA6HQf9kWU6E6546A3H/IGRddoY/92LHRI6/nvt3238t84q+Ke2auT3ogFHfvyVay12b7ZtW3+Op57SPubz9VNaY76nrQsycdG2+Q1W+vZj/ecFMJ1/2VGPl2KtjkupUSV5WQ/19LkFH78oFVuL1Pguac9yJpkuSq+m/C5abBFveU/yDEbXvmYXaDPur5nlTC3P3hIsISQz6SBc716SDKLfobpBQ5nbHS85lH9CzYaNydlpK4nPMqaN6DNLvufrwNOFnszImPfWwlbRphQ8JFSNHLhRyDF4z4OWMRHG+gHRbVsEYTz/v2je1MachZ0Ljp7LZcK6EQjp6QNFQROtoBUy2b1HZNti1CvMbuU4WirUjCsXthKZKX14dDgSay7nZAoZ70SflRh17Co2LjU1VyzopJzI4kJ0h2qmP0n/KY7SfpA3fXBLYGKDHcZY8yjCFGudxfXwO+9owsIme2Fh76/vWx0W9plG2lEOFpZaRzXZ/6h6CTA9qQoYPf6n46ge5R9VyguyVRgw/tCq53XisRON0xpxYwmz/3l9cJ2zyHMzyHaOxVb8VdxnmeXZPTOKa0z2NIrarhqapcwsUj9YbKCQPT7ZUZLhaYuEftn/luxjwyQGCPMuJ3wZeFKa5Pg/tNWL8ndrKh/RY1PuCK4W0yyX86EQW2dS0BEEt0vwvjBlH0K3VAGol84dhZT7NwMwr9BFaJOnsKNCI6sI/MKTJWUEboEgx8t5K1AoTAtywDTyyDBJYlPr80o2nwaimIaEIEDo1UqaJ98hVPpF1/2fwxp2UKPoXid3VnSYrfdICtigDImyig4vkSHdIYEAi1V4niNWW6AvDr5Av9hcoJ9+8DvChYLInck9hyo5EI9xABuZ/vzTR6f4OkGoYNocoUR7VxAuXmhzEtn3KMd3ABYAaLBI8z5lpH/BLnlETEyKtjH5WiSrrV03HsZWQz2ZIm/1+hsNJ7jVLA/lVZZXtrkACThGw/p82uXdhfMP5kfJWQCaJ6n9aYtTBB/kXUiOdfGdZj4ifapW9aJ5QtQjXjQXkpXGxdsYh50biIOOGozOgqTN5OPIJ6UwumugS1I1tmQtupFoTpHZvv07wP+eAj2SrKtqqZQk9xI9irsizJiL0DUw0Tiw02SMGjIgBvO6HBEjchIyAvg2+fqQu1Mwo4aAhYfWRWw7FhuPKXqo6lCmok+QWC4XZF5phtWCGpPIWSB10oCqFwDoB4XeCYGqDrAyTzeAwfsP61cBnzidWf9aCpPZFusPhKHYsN2/sOV2/8sgoIrpjZj9nZsye3225D6tHVeBDat2XAX/nyQ1VOo0+NM7Df7MPgb/gm/w67mPbZPB+0n9tHNP9Kr9/COY/zndQj95wwPIqQkluSfTjpI7m6LkMrtK9z6EzvBAt6xPQvUgckE7GBvv0PXZm9YsPRbMkg9hEb/c6SCP7nSQa/o4yBd9B3kd981tchCyydWcfwBvqT+4NXs5fOgh9KFztmgLh3/Ohq+aABzrXuZYFshBb6GXTR++o613tfJGfaVHFfqMHrmoJ2y5NxF7A17w2G5Jqad0C0VdFkwk4tRNNPRYcm4fN5FlO0VmfDdJeW6S893kt73G3ddp3MVO467c0SPrPAv2ew27fVcxUGaGrFIuFFHXl9K8NO2ZDB1sZk+3ibNGOSE0/GGgyoQ0EF9Y13NacO8m4Itx3rcjvt4LOkw1NAtK7rjqKHQiIYIG85Qg+oRoQPKSHZWLxRQfiWQjAahD8bpmT9gZ8L5YaMIMFTMhBfm3IATRhAY0S/6IiqYoiOcVQLvCtGPJJ507+HMp9EtrQL/Ah9RCfqGEo9CvGIN+8Wp8nOX/lOke3J4R5P/WSCGW0G1aAMA4ASWTTaGeQDERVitlLH3fQyJoj+tas5gA2XkUlYGdW/lzA/r1lzqAX6aH+zrWx32pw5Ozsed9uR35hfBffvBO/s9Ypj0TTbbPrR/+Zw+rHNg8RodVFO3dugpbr2HFRKtdR17XOKlP7ntS7+48qGr1JHpQJ7sP6vvYQb2OHtSPHz4GZ6YjvRRWWeF/LwaV6fUjfLkzwmf8o3vk5lE19YR7HbZ3utb6+Wa7j/UQ7uH/BNjMcUwSux02s4tfDzdT6QuckR+CRsRMWyeCf5w+3qHAnk4GO4A1WUP0FqtVV24ga65vtRv29203/KBPu+F+1m7Y1dVuOKWz3WCOmW39hgP05bRYriGoHkDaaawKugGPWAfqJpvPAHXzng22HeyRnrYDSCza2w6sVXAXZWRD3/CVNDZsCb3U6tEF7M4dxu6ILh2RpRlYxBZCG3xEzZZxQ+DY6xK3KRzH+P9qdhJ39nYS314/YfVO4u2NTuLk/62VDuhU0kjpkw5c15EKSM1MYJRFGN2iysZmSW3pGsNdBMCgm7LG4gb5pV6ELneCRhZ0oouFBLkTmsimSHnUGINryAyqspXCqcHoCLs9Eh3ZJjTKuOaD9VSqYPxM1J+p1QSMl56IPG/6we9T+kaW570aWicPTZ63uAGATk+Kd2VPinfZlqd4twwKwwl0p3c9OqCXb6oKGFtF4dOXEO5A19Rv7srsBG4Eep8KxuUPgwjZe5DbdYbdtXO5DQZ3awNaovPm2lqit13Rlt1d5Sd2w7UCEju7mdgN2dXkSLJfWvf+PmndZ//aph5a6VAPpfsIbeqh4756aLJdPRRctoR8tpXpWeVMtNST53kB3E/17lo11av/iemEVujm3bd6dUKLV7XrhOKxSyfc0i0U+vA2oVDYeQJ2TqFcexaYuL6Ca74ToD/PVOGqdm9ut9mE0e8DzLf4NQCuGQTsLyyRxoyokTG2JNDnlwIL/FX0ggvC1z1GlJg5rOEMdCZ44mYyRjVExIghlgwcOzWbM0ApL5C3DIT7fxKYOlAjpEISCx3YYQgaYJQLRBDFb6X8Keg8ecj9t5KgLWMVs5X1BTaUM0rY5lXp4P6RLDsMWF5yuHLD2mD/x6mxkAllIB5pY0GsP4PFiYAQCoSk9P4cGVk6uFRD9J9AQznC3OY/uLuRNfy9HQfLOROk2NAbxrphMwfAo93CvJ8P2I7kg3yK1np+RDyOfHwXs04MOP3tPKrjsEAbnRCcqJG/k7MZyt4zLz5zOWiPgUAVrhTSZTNolgJ8KExuhPKkXlMhuyUSpI2pbDa6utPVn6U4hkowNkzvywqFqYWpgiDqqDsl2Qrx08eedsw0+UaHX16zTX65j54VSVNSEDs6PjPF6wmJ/hSkrHB0slGwNIMANxGeOHtCt5BqB/hPdnrqe7o8tTCzc6a48lXkeYoqmo0xK94QrFzjeVl982PAjILYz/ykr2TM1nX6lDEDaxkvURr/h7bEuQqEuYqM+6aBEk2ralym3aQz24WJU1h9IKe3CxOns9rzH5pSh38hq2hkqRNMipIGaNLK+GgfnWHruLE+OsPJWl3dYMWTmOhT8Qz1VDxfFIYgbHQmNgN/sl3jsb+vLvDWz09/vFWMJ2ivbEoO+O/VLe9W/v3iJpV/iaf8y/+WNlPL6yn0zrjV1TqmhVYQaYoUFTJwT7qmunqEsecqNKlnFOB0twd7xvi/ZqDyf7aCptwCav/YAhiF1xLunTp/hhyMGhXmbUK7r72KRRWgXuBxIl1DFdKx+pnB3Mi4O7/cs7KxNH2dxjpusJ+cswNidX73fEWagi4piy5CIpCmIUwdK5H4SJWqEbxiNTVfQh7NokYJzVCiYF090hk1ZNCemE5uWmkFDY0FDRsCV1PwTL4ZNvjoHO5JPCHTBKaL418BaFGBIvCHfRLS1TGEbYGlabhmH8QjFGSNk13i9GxXUCkVXGnB7THQTHv5BUUzeyM4ZP71awj2HmFGhkrZEAB4eEdooRQCiusjKJGgeypJrEZKOfUzQhO79swVzkd/PRmKKboXL1ytfgV9lJQzRZDm7J6riJNB0QSXKFAbqMUimj1pjwTnUkwPeCB8Mrl8VejgDG3EBjNph/wHaBdQ0CnstwvIVARAlQynSnseiGeg7w9LCVRsDJKIIEHkWNyGiiYJQ//hpesilKmxPwdjp7iXcF/tY2xf43Uga8d8fm3RhbV7rpDBrO2jUa3NQAh6fUANdzlBrt0Jwhr5GJbo4AShgEBdwK5fSuAEy3MF4nmB2/QCvX550wuq8IKq5wX5lhdM2SPKHGIldQNrczCDm6h/RENOwz/Aya+nPAeZA4hKCdIE842ApmogDPAcBIKwWL6zSYruYwJqQDenVMkJtTmIBB9AsU1oe65+3QaAB3Sj+ZtYi7WxEvsJ7p6GhuZAscGvYXo6pOsGhpl14oKw8XKp2l35TLfKI/618B1ACnzn+W3MCyCj1HdKib3wnaIfQCiDCI0ft3vxg5GEoMVSPys0sXN5tnBeT/h4dMNxgseecWywX/CYTZHUEXt3HVSWT3/YaXv6VkQ3ICHorIjKzRqHTB196oFJrwiKauT5gKmDRVlxRZm5jxaJaWlvTXPK8x5Itb6TzwfbfEcKSRG73HCdcID2kkUKNvJji+862OQg9UMdVc5kq8pJIOtIRhONKucsv8o5p61k8UsZnjQDkI3b5qP/MLeNSCH0OdJFkM30aITubaB/kCun/hGrlHXFi8t7S+EMGqB0J+iLYcfQnZA9NlqNtG8D7a+ao+QJ23373IxWvBrYmxxLh1xTTzOObFkFyCWoZTMJubn/EwtlxtOa68EMfVd4A13z/gdxBtI1DSh342//QTxg5bYesSu1G5S7/Vav31+bSyliYn7S1y2cNGjWKVNYLo6+ZLIj/1XAcv8IcMUbGyUqW5wQBzVpDK36mR6rNtL/DOlrXHmhYcPBcPD8a723eNweViaWjlqaDBqREsK/wkacAov/YaQOZpCaUvR67Hb9/ND4zj0zhXNhygQI531TxrTH7Z56tpYIU3NmYc7y3M65sjgBIly6pxEwSllrcJT8rWzZA5UHWvShQj7O/wqjMcg5qZ7JIDOFZXtwaix6yb+c1SAkD15rEnVx6ljiTwL/gQXsuOOD5F3LbgfJ72iC5L0IDSh8CNMxynK33sEZ3Ip9D6bQkmofUHF0fan2H6x7hih0cPe4ssmzel67YvsAGqRrKrZjX77PEdvIGa1PNPJ8FaCltZRGbXUtVfam3KPIPZJ7ftvWdcVvDXqtmrk2c7PavcfgwNN0dwYlu71un2t2BtlW7hZpPvJYVeINzZ2KHZ2aTDfreJwDJaozhT1SYCU8KnqWnKTd+h8IYc3Ba/wanlqZ1vAvRHNQT+i0etal/zLyEfnXm9Z8/HwQq3SQPKE9IV5hs27+WwSwGTrkY90CAcO5YBBHOpoKQYbUW7gK5nQR7R+cavBpA47l9YCm1hF7fPdqYo+vaIg9vsZrAnBxuMZ93NO41/SP0Zto1azVp6FTWB98szq3AqYVH2w2fJWp5QPLU0rf/sybevozlVj99GB+ZDK+eGRbf6bgPnnP3A2dzZmRheWFYcmOG+Eg686s/Ecb/8J4O//C0PEHlsklSiqd8Pbc/K5MqLeXCzEU2pWZbXVl7ITXkhnpaMnUP7AKG4NHTXIX5bBEPH4pFczb7ohMtoyg4Y6HKA6Tn20ZfQO/6SA8vyaLg7o2iwNjkBNMIQ1qqLfRDs3miKE6De61aoTdfL/seHat+ns1jxKapp5t54dgwMkGndBCjH/f5voi/6YYHZ4QrT8K+3jVcfdqzxecpi+E+1Xd2ZbHTVCP27VvF/O4YqfHhZeNQnTxsj37X3CM6AzbEcMyx52Vj5ixONoDupbBCttGyOb+SMO4HMDCTEjSvQYNcLwua9BADVRs6884rMhGiS7T2vr1rMGD4SBf/xffLYgkpjQHmvQEoEoxBjEilabwjBriDoQGG3xzL8Q9/e3B+eao0bYnfIhbRxNx4gAMdNfiTIpjew7sGdvG+PLRQegjcr3UdFIbMx2ebbiDPkLtwx5xSBZXiT3v6h97iu2x511rk0d8bj3yiBmsVv8a5BFVmgOUByN42B6ELl8prTo2vm9tAoj6ynqj4f6g2+Go4xzVNcE5D9mfhNVbqe9weKGXGuJh3dQQ9yvRk7dj7qsCJX0+coL94CLHBiNhOGW6STiHJkWWQdgoj3QNLU9SZSUWlgQqlF+gslhhuHafj4C+qTHJ3VrgcxmtFAHGmzWn5ugaAhhG8Jx8JRCMjlk8icaASI4LvJEsWImZeOX4SnI2GS7kYrwA5WyqSUIi2Uwc89mYuxA/+bUn25O6Tr6yGZTzCuKxEDiHZvun0hqHvxqBABlxPFg/k34nYGYTruItWIcd03VDhLeGouQMoegSXEpujWZmGKTOvWdVdbDiwODmnR64+UQMVOtvEKJBcq2dTKKngFNbRlQvY0XpPEiGHYLw+hupwpTldymIx1kAZmfW+l4Spr09D+yVskYZfmBhxt9pjHkuITiesLrNXGKL1cLKC1ii92WHitTZ8Ip6o1rDyusM+7tMrrbHoBCNWTZCjRygrROszlhxOuOO4o43c6ZVtt+qpzQAFSQ9OmqzEBV3cbOriptIhj+5lXJi9QPs4XglGXwKAUkIMgsidIM7Bk6GFdcLwrY+DEFSXACOOo+rhko54ZfCsqkD6W3RK9xF2Y3kFGxbahMzU3BFMMZMREAQRerP3zLBMZRo0jKYVdnEgd59hgwqzDMkTfQdXGAO823hYuwDHeBeDtrhH/VsvrfUb3uX3yuN3Xf6jfbsUdgqpysjpLD1tPkOTbJOX5LFAX2J/wxqI7oR38wm6exLgfStE0BD5X31/ThcVPwW7EEgrm/TvqXcGmiJJ8P18umbdUiyL5szwd3ZrlVGOjTN6svredkE2kdDNE4hmzRHdEXN0g35UW9D3nZbC/InsgX5SbJzc175lFOSVYja4yVagmVKMXRKh7KZuL6/CZAw+wl2KEPc8dwzgbRY/fbhWee1cf2wbbSuC8ijMvWyz3ZknDkIMq5ckRCr0MpkNw2QOtR50IpTzGwUyy9mhI/FBF53M1F3IhZNxBNmfDKuptEo4c1MAWgForsO3YuxnZHY0BF7jiib0OmUSZDsGBAOt/Lfno2EIEXFSfyTvFvFDdZP8m6VTNz1KEsD6P64uGF4pTwypBD0PWO4VyJu1btXUEI4K//dQMP9rd4GhzupHQ53fYcQmo7cLZTV608VEAivs5IYyck84kES2cE0MHLHYMz/+YZsdvN00sZp83wSn9vCt4bbc8q9Q04ZHme3QLpqo8h7gf50dfXQkCZtoYE8M5wI2xI0oTAMo4mtaeCSViPDTv0PSiwWxbIWePaDUoouWMlRyYzhsGB3PaHKlZEhmVxx+Ng5fYPYfMmIRhX0Yf/GMhQJRSLojVFOMGcJBGQ8d0DEiea/D6xLzD/Pk3PT3nmuRRwUl4BkDNFogP79zvZgELMiIitS6zdtAdruzg3C+rEyjGrCDn4NgWRfTyA5pzOQUEkdDqtH+0FX99o+CleoCQfTt5qjy6zCJrNgsX/a+rSNKlydvUqeu3/tPPeVXp5b/wINHafQd+g4RmQ21yNylSglB5O4cuYdMUz2H26ue8mqCepd/N8Q/w+BZ/ettE21ZQmqu+UiV+KW5ahG1nz/GinBjwcVwbpnUKBV/aPrJqqntacEx66fEsztWmhPCR65aZWsr7TDsU4p4NCf2nPoH9WdrTZQmi8Hm+mvtwKnuYFcFbhNYY1cdaMAzUFLoDYg565eIOfb6odWB3J+uNEKnXrkuj6qxsMA4KyVuJ44KHwzsH6dtEGA5/zm8tdCC+T5pDVBnlfGBymagsCPZYATnOFOA93H++GGbWi9Pf59wXA2i53YvpgH7nP74/j8xpi0RUmx3C/H5R8HRV27gd4bUyiKiKL83NBQC+VnOiDV52/ByoCpRSyMCzGttHQz7vXJhPoHN58n/7Ej+z2rHcL3exjZikSHVWrVn7cB/gzdR/x9rj+0b8wVPegf/7BmMn3aqsn0ULXUP5l2/NT4WpoaP7uRGotIje9k8K9jwPzxOu7T3K+2LDkeiPCh3A9s5t9fXciwxfVgXuJDlBa/ZiBeiLt74WRom+KW6wKATawB6XratmbDwXWII37dgxYLZXDtBXoQX4EB8Ft3DZb+gjCY1WkvpNKAGxbyI5OkV8dP3p4s+FmrSPod2y7pt2CSg22SfjPJc7c0Feafv6q0XxWCMd3SfpGdhV5hv+Xw1mbDAmvXpgQOcPOPeBis/lgnJtLD5riby5Sn3P6QqSW+mQcLUx0jfJq2zLfYhwXHa/kKg6Yuf+pFORVyqB0DLKOof+GwM2egpOxVUFIUWsVAUkKzv7vy5xGMRvgh/LjHYkyj0Aw5bb0shf+pnM7E+fpbu+BNGNoIEk0sDjOH5lWdpcRHdiOjAgg6AR8btXJRax/gBinqRCUWgKx4inaFU7QrTB4zeNYcYgI13+LqD3HWDF/kV8+aFzclRUmqh5FEHz6v8nmDuOuaOfSnD1epcqCa7qFNqssbkav8kZ1IeHKValw9abDJBOVaobHxzUCX/XCV6Eh9JbYl8RGfD4IpXWvFm/KtkMMPjXo2jeglS5uJjS6NjfxAGNKVZ3RTw/BONz9L/ZMDhMh+CFA8RE0EDzdEijIdsK+LHl15Rhd9zEwnpQu5ZP3wSPcXUwCg/hKqqS8eDII6X+yowyoMKt2/CmOcLSynypCOnGqUNBClYPFn6wqz8+1JE/ib1keaWvFQaj6lFfMuLyTKtQjLhfKZRDDsuu6OxMiTn/HkEXsaG96KEgha4+i9Wq7NJxKQyEmWbKRR55B4bbgG8Gj9Olyan6JvyMfYyvcrVweTPq8r3TlFGOvIdoKxuCN7iVIx+JaOPOn59AXI82DOc5ELPdXNZlgqFDBth+2vfY//A/9n7nI0d167LqajZQFCCZKabz8T7fLeflwx7M236U5o17u/MbAogU2w/7Y2aHQ4tTel5dK2bwuBbzfF1f90NTUFSO6pISjYv9MSx28ADfrYTwSwy75/t0xe5GE0Yk2Mht3AaIx7Nophd8TaYTL7oMQlomFM68w4JG1aCbo/Eoj41kFgJm9bDwdKbgnIJzFj/YZ/gL8fKgv/zd2FLm6pIXRX9VRgaHxtxFhvBR8C5Wh7obx06AFjh0z2d7AxuaQHxA/Ls41HSc3pDiuFpWqRrYP5T7/AVr9nab7AXpo6SMUP07toNVMlM27HkrHMbFplewy+HiIEEBtTKHgECnhaw+NUUidatChmwJm9JYcpMCpP7FRpWjimJvWbALz4bigWjsOevMzbMRXvcx6NExXIlRAPLlHsWBnBu3iyZBSMZT0OpKVqQAASFaqA76GowJOt/ICp0ipB9NuVKXwUg2Zo5DWiISu6pGkhISyCkwmsulEURWiGYHcN+hBozKB5o0m4TFfuxraMiO4IthyNgMyHFVpN0TY/xc+lgKTSPvJJ+OGX+Gt5uvmG4jkGMV0aVQVTT8QxbsZCOB9BC2+ENnZwFosqaAFA4wRHUbCfiK5eMGxBkBL3kxigegyCAMIDTVdpg4jfjf1xJhFhYFOFSWiilRSuR+iWFehcZXEEm1LYb9Hdc7DKYMpUQ0LEdrWINwCj9gA6wWwqwad5UTyGehWHZQf+Z9wJCAAf8GYDLXlJKsnnzDNq/VK7rCJp4QccfxEMJ97BbuCsPy+kHiRSs7rUzbwP6j9Ug7TpIc6sr+PXAIwg9Dc9boH6w8IijUBznlzHXgI1tLl53PPYeaRYCLwmVWeZfa2Mta48si0zlNaJFsH0jGSx6IV3OSIWAAAgv0a/O2zLCi5PuWyNET6r2pAKlUWUyaocUeqPw/WkKygTCHQP8qqSTyi6DAo7fFnIn5aXDVmjTTEdeVUxt5xPGA46IdG4mDOxI443X9REVf4VFtxxc/67zUSQgmQaEV1RUqoZlpmUR1WNFRdGwbMlKhltCG5BrRaUlZgG00QjkiH/Gy5tSFEVVWiQEVvAc+pKBbuEFBl6MDYCc+N31JUzgrwi6VMGH2QUAWEnFY5CfonqY8LYtHlH55zPk9GJeTlWCw3VzY6kBeyssjDyLeC7fskdC/TAS2Bw3IBz8xu7SUu1QPt1LPiPpUAPH8ZFFwxphPHs6nfBwM2JvI0Ura6rFy1GMCm0h+6nPvupa9+i2vjC7oVxrf0qTrgjGjBYHgKgYJTzseLkjFG1K3aFGijiIbaYMFh6vDb+XCFwFw3232ZdJXIHqS3Mq6tcqk7wias0H9DzUG2zSgEbSMcTMQ+wlV6OU7gW8fFa0VFo/ZBzcP+er5mW14oo6v76eIH/PXcB+kmQAVxsoatwzBZ9eFU/IVP/uMj2APgqsqFrurPjze75sn8TP6d1H34D3tyAUPXKmTIM1cNnofG+FoSq/ouNXNb20ScctLpue7KvcSuf37grAcU5xgdTSVaHpGneQ1MdJwbXQlPx+X73NlR/zY57m7Rd9RkzIM95uRSAeCr3WPAY/ufGsAD0a1S+FvsUeN/XVK/FE6Ik7wAOCJszcMO8/O0bWvzXCxN7RngX/zzcopWCvJqw7bRNdW35m5sIAWGTZl9uGH1m3QV/PWV4KnLAkWlAebK8WgwFnTCYzoJMOC2jt1AAl27U9kdSyzMdeRzjv+IK/X+4Qj/eu9e/mwxymGf7Lv9v9vRaA6zuN3Lti9pX+D8wwAm/uWfLf+XPWvbEzR7sYGM5f2fncv59zeV8sqvhBdHONf2lNU//rj5b/Ldu/MSv/GrN5Xy+1PCLn7HwfhSo355Pt/StrQrFtCWylwzgUy2Va3RNCG2OUDINHxp/+9YF4PppTOZ6fY9ZOH9/ZXUEPP+0wwu/9anyDLAkE2saf5wPZ6BlPQ9Z0vT8pGGgXjBwJ8HfDZYHUzXqe5EWXcY9vbUl2ZP58BtoRKwBkrT6tCAkm/94/3THPvbk46w1+w7X/PM1fsa08obVlahpy+F2egV/kGY9T2jMVt696mhlAr2GYk+vYeWtq8lRkwfRaXgEMp3ndKwg2Q/+FhagJ+EKxMh/3YKTsHW4x6p/pt662dPAa1sFbHxr41gdznlY+csmlKn/4OUyOrBFfwG2aD93JahXNw1YsQaUn/WUaztmmTgTI5sConxkHQAS3RJlSJMz6JFoAU3OWmvceHrPuHHlg4Phi8j36VzyjXQu+fSOIxJ58Ff8z/k6dw6E815PmUItr+E+709pUBLvkYsoqljfhREpARGIG62VMlAiSMnNsEaQ2464B3MGA5T6fRlcCF5PhtbVtLPezDxcWqYDKQr+JRyZioSHOZKd4fG0DBaGJJWR4nuDbrp05c+KXMbiRFk7zokkY9Tf0dOwqbCdGBBN6M5oeHfl3NCQftI7QsmUi94Fj/0DO4SEzXElaMGoWHSCLk0QOuyyFJHiBLD9IO1/iFosUneHXScUjLrgVcIGq4KZNoNaTqSPPQn4OyeIGT+4i/hAIS3RKuN96MtpmhVBOUB7AYi26A1lGKprD3ZxJCg8R4CsB3I/kHh4DL08MMWKAcWKAU4Y0bBBjGZODI0eSayFE/rJqLslXjbCqh2kDQGe3As+JhEVeCqmqxHnQ6ohaUyoGNMWUOdIIztwon4Gh6C/JTYoEmHzjFAmxItu0XyFlVOCaFvJmUO5m5Kzo1nqnUIsulApnnDcfjgClVP9A5NT/X9Aid710I8O1wKHrCOlOjAs5MMP1WhwrR1QcvJaWqv1g/9Ysz9nbTHWOwcZ8FFx+r1CiYvjHr4V4CN0/IXmIr9PGyuIa8ALpdjG4YXsCvCuDFDdwi9og9G/sGn7ggo6zDc3qZjSr7DcaGGwwMaCk0DsheMmokLCjp107lnZZAy7PwHLVodndpLfrYY2HAxvWL/dHlblQChUm6hilwrTrkjwSbNjgYCl0xgSSOgVxj2hODlQZaloZwSzwWtjeRvcHtGIXqnmZQtPEwXk1DJ5g5864eEXXzhUHZGAJd1TLh84al/ByljKcauAERP7kgNCEY/0oIi/BJKhqoWZpflkOhMN0/5gAGh8NJkzNAM2FmNk5cNCZnjCNkdHSipUiC1j5NTR2KQmUJ6KAJegsEVhAvDhk9AIvAGuwGxNM9YFqp2N/2t0azPUUg5lBgHvx+FiEvtCEkXK9TfBezUJ+d9apXjKqSfsHoo70USxmHhOMR4v3kD/K+wk6r8fBFWYJHRx0rAMjQqdYWGkgD1RicG94kk34ETRyociWn0xP5kZmxvLxIo18sDk6ZmELeXmjhkbPiKRi7m5vA36PSidxXKJI1a+tA468Af/0o4OfDrbPWNoLeyePa4dHDgqjVeyww6xR3KpSkxiyJ8vCycKk0ACPhrd9/duDRKQDATgK9syI4puZMSMWov23XfTjAM/jgNNp0jM6PidaN8AP1EqepUle0r+K01w3+4+4L7X1M9dFdz3jga4b4n8bV1s3k8dY2bP/tzUKY4RkgzFDEeVSMSMXRmYmKkIV8d1wzBigAHJ4Y/Z1aCezGDmbqoRJBVyVDeKpY0C9z46CPKuMDacL1uY1szW8qOVVCQF9mndjkW0bDodGBnRDMeK6GoqknkkH7UzsxEkDjj1mXRcwoKFiNP3I8gkT4AK4hCkcl9EpU8GI4MY7JS6nSewww/YVdwJ5mSnkBS9YygM0DC6qoPr4dt9u0Dk6Wsd59/B3pKqW6ZK9087jN9t/onWWT1m3caQxQdzrB0002RtKNvm+MR4s9+jTx7KJGJidvbofsf9wCPw64eDmBZGTY2c1vIAnOYDikipPNq8YB4FDY40PdElO1D/rKg020JKL2cDNfvXmdmraPm/GEf+04OG3cMRnjgMH/AjsTCIJMXa4fppG1KOuOywvCGwhqYEmWGaEuvE9g+30aSekJleVQzi3IYYBDmv3T2OW8c9ljojfv2OVVUiqGvc47vGbtwGz6SjuQFv5G49rA3ZXejmyyQbuJIv7dlmesHAhnxhz97T7W138p8mT8kkHCk7d3BseE+33fbUzxjfXdCU3O7Zmd15RcnvJjec1m6XEzrsclKPXepvNS1U9dBbgoCSQJC8HSnVmpYqOyLu5uyDP8C+WJDbA1q9V3O/pMADn0SbRmLwUpaqvmwHvYWFGRimwaS8TPxUGLkysuDdvOyn0+1jnEY3hPg03uyh1kITubKHNAC3LaUGPMSTevD/0mUM0cutcXnTZIGKlDr+xY42yx6eVXYt3C8amvysV/jjf81BPFJ2GJxcRnUSgkyiCpe2ruY/aqeDiKsGyK0j2ZQqIIqFg7KFpJjOVwQ+b9nnOiUsNuBKxbaERJcNE1ZpeHikErfjVOsNGw7Ri482kB9hm4HR4dC9CJBgShpdKWPgNIja8Sj1cXJRxckBpHK0JE7mcwBxkiPphoPpGlEHeS1aBhEN2sH4hkBXeXkBSg9hEy5Huzx0Y/z9mOslE6ISoF0fISgFAZEy6O8mYlvSQJsBm6DozwRlvKKsBBTpJTyw4Vm7OJeYTCSmYvERXNeqHRCMcCm9PISbxIS+ct48eEr9DEHDtgg6DWEnVEXGErLxL5DopSIwgmazVnFrbsgNhyyKLOQnMFyKpUQ7biLyBX/xGy0Obr+IHJBzUS0e5o8UlWzEBOUcLVjlSCjkhPETk6/9USEI7KiK/VPQj6r4KliNQtFgEyge4SrcY7Cg+b5GgPAdaPUIIbYWOBEN5lmjqAPY0gUOl2gXyPVLex8bLhwOFLxMYwleVGKx5D/LhfHHTE/vi5pBt1BwH5133cLV9L+CpkWOaiG0I4CFOJQBcg14d0pvR3e/9DDx3PUH0qXpTHbGSBXJb2vHJopB2z59V2HRycRiWTQZE1YhG4tlnMW3N3HWgIzgpc9rQbV7GUECwbMR7C4MdyC1xcMEZr9NyherUNMcrsVzRoA5wT3CBHOCx4Nf8LMDO8FW6MJsgR+RgV3i81um+8JtxrfqoQF9pG5skcALmd+0t93f6TU0u/h+M7t4IoaRNx12dtElfj7bYJhrCKH3zTt6JDI3mWV0ZBLu8fS/0MqbzsRWTz+uWTPfWDtPrF/QtfTMn9ORT+xp8v9ofdPDUBAcdiuf6NqUXujpB6SghPyAUOH2cRdyN3Lv7kexsBGGhTL6MzF/5NhoELPDv5GOHKJCR0uu4sUCryUH4eNutgVWAK3OtlB/+8SBiYQgohtzxtToyRm08YB1DERN2sd760bacEA6kI4+nJFIzodafThS6mFimJ1LjncSMbyzPxHDEIgY7ufLSyfWlv95ooaDlM2hkTd6cjW9mKadvFv6N+CwMd9owAXjyZTa0YLDxoAT62rBUWKGCa7GnYGhz43+keSZ/uja1eDW8y5457FU8c4oPZHJXct70unpIbvfoXzF1tMnvC0/aaaGotZQ2mycSMsWlbA6NLGzMLK391B+YwA6hPs3oE57FM5jrOiGiRorxdmJpHHzx4B+0j7Nydwz2HrPRvo0A5jSPXwjDdKouXqQRs3T1jH2Ew7ThgfX7dZE1+3WaOu5wZ7NWLh+x9odG3pGfyZY7IxeDPO/cQNn9HAS5sVtPLJnH2aS/MTtO8G3HWZS/O1NnWpa2/9IwKCfOw5jsDdydzbEkvA+464zPYXOfqrQezyVmVXL9/KamtHltRoIZI0GgrDhrgDhGlU5OYHIkQjK3rwJ+IDQlJEWyQG639C/XudP8hWmjSYXhe4pTNfXahEc09sgSG6o8ufLjWIcfjYRzqRjYlNzunYFI6wIUMKKVPAmEknrq9fq559wU7ce9dltetSJjTYJVr60wdqfFWrf43+HZC4FxpLHcB9is9ZtTsfWFJdd7KUk6JWWBYiHXyDJhyxHO2M1VVmeHNVOVTBtkqPaqAomceMb25uf8UMdYrJvaReTNRfS3ewFPUKy9O6q1YrsCqEVO71CrkbT5rODXyGkvWQnm5Ny9d1gYB3XDV4u9f/rqNbNWu7wanXyZ0B0g0YsYmTljQq01o/c6P0T6KjY3VGAfyzXr9f9TwYRZP2AB8f9sGRj5hfZmBpr/fV9s06Kw6Yes8w9G4XBbRvwme56/fC1fFcr2gd3iqt7KvcbNiXB++ieGv4dGzV5TyV/y+bUdFee0aeq77ZnDPkGAXnVQewW38p9g6E3vbt6ti9ZVWfOUZL+4fON8jwVBwWk9y/IO8Kx0DUNYisdJP9BL/HQMZlgDFiXgSKoX9Jxek/SAVWyJPY06xdtZ9JBQmfQH6Sphxo3v96P/Oqqdq6sKc1YJet41PFv7s462qmy1G3POp58uVWirEcMYQ+JZ2GKOwsbvBy2rN357sjhxYn22IGNECq6TNWd0K1dC5RPFmjqQYMKnRou8y8YvXCifGjvcNJN0u7tpyUjG49DSO3LbrHojqVzgcDIvjMmSXpyfDwZLRproOzJxwOx0d359O6ZUkByJ44opBYnqc7yo8TkzIm7Ro9M0AAzEnIwL4k4oRH6WerQwuRxM4lLaQOCXw1EXyzNFkwqkllOV6bTISmaw5qziRTtj0IV8IynYAdjPfg7W+Znu82zrn8HZyjZoFflxdhW3AYx7j1ihW9aA+y+cPZyIWqX+cB47muExI1oMWl8yBwpJ3m+mjTKR124awOA9v/Mz+4rFI6YyWZnjigU9s3mybNXFR+cBUxqcqgQ56NuMU6yKVOUeM2N5FHOR6O5BCZ15amMBrRViLxuXTD7KTrIgHDFA+WKqC9GYAbjwftghmlwvL2Z8ucTT67YaSHVxVJjpZwtI8AU3o2FLQQv1WG7rS5LYGfZ8ioMA/TwTGO8yZ6phYuhf6l1oIkCS+WIt+2KG9Jbi6bcTB7+2PVWYd1YmqdrFkAJWAuN9KpRB3qvwXbdF8AtwTyDfxMmfmjWI23G2l5MDa38btIZFnjLRMdeXdq3KKdnnNGlVChNUYgBRce6JzrI5teRduKQmzqY1t6j2CHbDhoQvOU1XEYAktsKcs9CIo6TKQ5NLU4VgRSn2xV0kV8N8ys/KiVdKiaruaA3E8NAp8OUPArj0f2nj10HpJIRD6eNI/caaYwa5WhUTmrhlK7nQC1pmKmwlsF+7SPo3nsYAScuw8wCrrtUzKyw7dR5BEy5NLe/ih8RLfDT0Qs8VwOzNkF41yMFegCxIB1RjCxg80QfNSsZLRpUVFSa6JabuvAggCNS2M6rETQitMTDcNNDZ0djZM0hRcWulMnW8j8WwrviqTbSGB5WHEehC/sCVWED5w0dh5oQJPVO78UgEnnBVp7fas9WxLoyo1twch/efSbr4gCioVtybt/bdSrr+9YTCqXR8weYKakob99Mlc7o+zlLC1A2s1g7S3VY0pLFjnDGa7R4u4tTXkFLzxBZaC0hp0lzCVliGAd/DZlVuPhK7xqyTf/ajSVkqpfS1S17LJ+rDkm01QeFUJq/2iBjLZXiyF8TxRckoBAnmE6tUkYofW7BVsPQXFaKRv2asBGVHWjWhaJV/u10CZweb6pKxKrU1s4xaAUiUQxAgNjBjZ5U3YgmEQ+LCryQLNTH8lONxNUp1m6jj5LSxVIYMIRwcXxHYWhHjOauI+BwwnwIuWtsx9Dk8ZlUGPQEaYmEZTeZhCASBpWCmjXSCrCvGvH3i8MRWZdb+8X4kxj3N4zT/uCjY8G4Ofh4NF0vBpGJNFSJ5bBDFbTy8VQpSvug6Qe/K5wmHMCy8D+BRBrdDAuhcQHEAczW65oaKBIZ5A0zNFmM+cJjDUAWW3yZb16KdF/c6ZptUIkhqxMzxFhD/AK41NxTb0hSzpdpf6RSLbEJI1m4zF0qklA4MZa3Qrxv6HiJGRob/eVSCpUTbJt0rSEzHdVHovVbgGuz0YEU1aFJb55h0nuzXivz3twjIeqNuQcfKwxHn46UDhr0ZorpVNolVXPCQX1nXqK4IllVE5oO/FGg/nk9bipDiblY1swMkZeh7xwNCWIoWZzIlpLU0gUrlbIK1PoYStV2JuwQUaMUhBTUcgkbDJcBRYHIAThEtPpd7GKtOrhYC0OXt49CbMfCC1fUNLRokX9GnLFYcQmFDYkm0iFLzWOVGXYHRwb6uUGQbZrkbUJAtcx8UkBgiCdDArP6b32rX4ND/sGttvoAIL6/n9X5x7bB+f60Cpzvgb+H0b+5FsCPn9isyb8HXMBJ3CkYd3wStSozOYpUL4td7GtxlloxxltsGDYM3th1803ula2w+aY0Eju9Ic0SNL8J1scbYuib+u6QFS6zpzOIkNQZ5Hix5QvFOAq7CJa0xhOWbaVT8AUIxgZb3iBJzB0u25wu4q0dnhKrasxT9ha7PeUdej5lJu1To3HMrtPk/VhYQSQOublaNut0eEoW7Lm6k0u6YS0i5GjgDkoofTXF8xZU0p67PHMDQogPa3eexHDUdx5b5Yd7vecteEXLTIPPN5Y04azodKSxouYFjEtAKbYdF0V3f2tD8YGS3VChmjYQPNnCkCH1pGuBweKD3J3V1T+xlQHjG7X5TEhKLUxOzqdkOTXPX7iBGFF/wKAyxpTyA/+Pqo58sTdqJB78LNoNJXS4XgRy9k95/UpmTZ/jqSMW+JiTWXyst7ZG2jVpFvZ4Rl1r4wz0Yl0bZz4+edXEQvBSQ5l6QIx8LF3EptcuK2mGaRTImfX7YGBLCofVknYq3qh9R0b0EO1wPrYYd4vXxBOJOMVjn9NaMqNYwh3i6htmgYLdvmG28iFEMtRtdqYQJt9aNb94MJMyEgUzmVvkq8Ul2wymkOXJUjyimorOrBWybLr+rqOSO3YhOWKmoma2ajiOUc2Y0bQ5Uv99c7FMBx93JPzijsWyp/dZLLugY69s5U1EsaNOCtlGfuiyzmwjiirwJjGZiqYMSQjkMrkCSoTMg/dh9yDCnc2WJzjaX6YVQmWgAoGV7LRCwHFHv7JflVBepwqg3dSuzP/ZfHG0SnNxEre8xD9Hj/mLx+KJ6s30mMdp4m8OQcc7kMqnxMm29P/i9vT/ZX2zfI/yntT3deT3t9I6Vopnc2GQu7Wl97M0vZ9tpfdhS1Tz+ZREK4WwHEvEWym+jRR/V1sSXx2N8oc6k3ilUB4239WTvFNuiwxrBl6ICdT1Psqsf2OP0Ulhc3yuyjjYBukZQvyUvtuosZYhMdzZFwRgvUpfDM/LnhQN50WA0fmvGKAFkeWgCwbela8GWu0/RzRyjNsAw91cdNV2org4FqJHI2gozuh1fTqGbzZKlLUhha1u9mPBG6GsrjuhZlswmmBtQTkMpvq9GGTqamFid8XvL+Yb/cW831/ceQpgbOZe6LcGSKmnk/gmKC/g1gjiuaS9sJYnA34P/2dhBzcGpM9VrDWB7iqTXF3rHS0JC42rjRFeeO+v5MsIVOdrRGIYIJ9trdz1dvNXGUhmhveeCmDcBactauFh+vbd2Xj7vkXfPs0oZa3i5KyhWCFwKuIAC7pHjUarxfzc9EzWrYVBpCbHEfzJmwKRofl8er6WCQjR8mIhNTOc4q90d1bG9tZcPjJ6wnJm0kZvKjelWLqi6JYyRT+rvxEchHHHo0PLzSUpHZrPhnY81rbMCqhDhB/kx9MgaBSj+USmlgxLkWSDEw0ZxBVgzn7Lxmm0cNiLFRbxPR5BkCR0cmjRJgJKaApw7BDfbm8DeWbq6RW5PU2fw6DMwk1aW9y7OCyBJkdblS+rRZdFvtBsFE2e8aSjDz7x1InuVtJTu/tG60tfg8eQtSP4cNgCVQ7rEwuUKycCXmz65VQbL9YXm/2i2kxaUdIztd6e0mu727oUbH4Xpl4HsXN8Lvfc5saxP8P0Lv4+hYTQGE7uJl0sIe3DLvYkRalGyo10gmecB20IG8Q2kJ3Sn4OPWJ2XAG+0jS6xc95q/GRsVUsBGBRmEi059So6h4qz5Rda9VEKSPBJIjNAq9QYHcnXL9DT4XAYmHhse19vj0UUWdejFSuTd7DeMJSG9klIqB71iY7rgJ9GrIeOT1Bll8HCMMk5dE6JywBzSjsj2BMrP/IkWVIQPyYPYDnLlUFSZzjj7sm3HvyrO5mgRuMFhTKZB8htiG5hgD6DlLwEiBjKx0ObgeTWTA0Xj+Zat8Ho4Z6rQaTHDSvHB6Bgfzn3Ku5z3Hc2q2LfsDHpTvbb742YS/Mvz8oUU9hpaF89hfXZ95CaZ0vWbffqyAZFqV8TMNrJBudt1Te0f0w3eEJ7qjYrWXQXdu1MzO7TxHixGH9GyQ27dvjpNP8T9ZPhKOCMpH5SocI66AWGzQRL9ZH2yFVMLU3RLl2YzjqOhTMZzmUoE6RdstSUijQNlLUycMKEPM6qRYxUtIzkU49lIpEMSob00EYU7PeXxm1dFzBv2D1TcFO2ncwY4J4Bm0XStlOJG9F3j4ZDCXjTNKZtrankeKz+e9QgGC3qoqAYZf4ZN8BtIPgiC7IZBk8BvB7UtFrIVJA5groWm6TxFLLMb4txw8DImwf/pWqFpY4DfyxABtcNeOCtVn023ffEb8cR/5F/jCkhUOcBXzl/mw70v/snlnID8Rf1nujbVzvDNzbO8Otg8VjfM/xd/nvCMjfMnYk98rfQJeUBjyF6zgStdKm3KCrMt7SUUDiVe4+gvxLQewTdtoLb7HO4JR8WVvLRH19rnjFU3F1njIBE1buovIpIl9sqovobWGMWabjfma3fj5MWaz9pRUtNd5y0x9v0pJmVB9CFr+B8ovjuOrn1o9NIk+adLE4gf1Z13gWrBrr7+3cW4hmQtuXMpByOKLkMxgvp+rCQyMSFaEntaryytqwVo5ojiWu7D5RHUhduO1GJFOAqEOlih5CNkMhE9zH9a3LybjEdzcYFvGY4pkvM8ndgx9CL3jei2fKlhyZ6y01byyXqGB6SqLklUmz3C7HlDXTdpMsbHN8b2iL2BzcXsatrRmzVHqWBtmIHMlnbcYCu9ByFWEWMxTNJhTkKjj7/xNUd5NSOKF3eQJQ+eu0o/eGmL1CXd/Ma8xmQCfkKpg2XeXy7p6x0OcqdycnPd8dmmlZ/HfXIOOqRy9DLP6x6pLsY6alO5PbKhC2mSjG/LIkIgfLSSY2yJNZb1QmNsoSyg2CJp60meU5XjXJKe31ys7LvyB2nBqUD+1OTQ3H+Cnd/W2Wyk1UmlUZlUmGVyb+2KpPMzkRbYXKI5MbaC5X9zULl+0cuB/jh2d0ztEShp+4bKFFmGJjuatxzL6fg8A3XD8s83b5CY2q+2n7BdXJ4SkW8h47XXu87d6ZKLIwB2gUnBP/cjdcK9eBxe6l7Xd+vHqGsnWoe3HsLy6tPoP+EcKYldLsMyrvvt0qF+Vw4nJtfs1QwAQkJRuuTs7t13H06ROYQFp126s6MyiTsjJSh75ifXMwoSmYRo2igNIJ0FI0rW4p+HtrbVEvBVhs0nti6HsNy/4UNP6+u6+drMHV27zrxj6L7TLV9Z07NVC45d9nvUXxSQmQG2FL6L+rNK3euzsFJnhWwqjvy6R0T+YBkjy4VUnOjOf5kdBmmjp1JEn3yrGP9NkSt0Yao0c9Wvr4q6eYNvctNAVZIE+alp/rrTYP4qDXY5lJ5QG7Nnor56nU99P2D7C/xyQFoNM/t9vV291y1kl2pr7bDBGojtsP03jUpND/QrxL+rW+KQwx9O6gptozi9DDM8JetIjM9TCtctwkW074m+JpgIlOq4v57EQg2BzTBZpIpofn+z/pVC5uATBXbZDQWYr2bRNeua5vfbCpFOmQUoouX7dn/gmNEZ9iOGJY57qx8xIzFMU3QtQw6yeR7PTb7wyA22zF4KkSe4duKSGJKcyJQMxVkWYwFLZWStZB/72fCL/gmfDnUye4YPKAxCZK0h7mr0M52pVoTRqledEO8pClEwj7r4l7zzV3qz7RJJxM0IG6bsZ+fHksCYSfHUwnZJFYUkBQohoBwDNrRafum14OSmboDpWG7scnCxofAwhbQcjtnng3awITnEXKTSpORsF2/K6ll5fr12+UO9SFZDw3HL03sioUjgVA4fSCHVUL8bi42zmQenVDNqETokl/GNYN6Bfv2EcqT6TFoIgsIecxsjiK+fIPOQnO0H7aF3FdReY2B3IUMhu4dLO6SQbj3DyM211/XAeu9owfWWydalp8aIDjXR5oYXVVVnBZG948tqv2nH14Aj3QS8/cy75N3rxnE619ak2Sf3NvP6Hf7Rt/d3AkdyOg9JBcDmbeHO0s4HFs+u2dp4KwBDHewOwu3Ds9KN9QWc+FgZsekn1yT89c2yje7km/yq36B+jN+oL6WexNDPg4YqJuakp5e0FzFV89gUTbWXNWV2A/BOpj2L8xSW8T8xqCftMNiEbZnNDO7fZfwz5wyJJrS+XD9NKcaB+WlSOh7pqbGAZcMfG7u8vnw0FBOBnosPZeuvwrQE0UImLKRMOnYDYrtwJiEJFNNzjv156KGR+0DewdftG2384iNe4RtoZaiYE63ypZZ1LMs3KqaWeIZA7IQjDMKPCwVA+cp0vIizw7hiw/jvv4JuBNMoNhO7m0Hr0N22GSKFxq81V4QTvMS5ThH07coFSXM+HyJ9Ub1vNBGWyx0NYSVtoawP/V/FW0Jv4ZO/QG6+q2oaHaK9YRB5a37TWF/oTdwvzqz77h9s+p+21QsEAyzSplcGQWeNIjqTrG/3dERJt/p6Aj3Weet091+rdHF4S9yl3TaD46NuclD5z7s7OPc2J6MVVhgrR9elsNujNXFWDWWMbxmRIU7+yzqJkHd/2sUwFWwyj6dTt3KA5Lv++hkobRtZDH3rUPFv3Pi4Eyawo7DQ+NT8dFz2oDHo/NL7/GBx+MztQbw+JkdwOOpLuBxFcDj568CPF4YkK3/6w2QsZNz1O1igfmpkGRgz7NhsJds4JisrxvOipLFTtL2uYUl0qJt9/iZNors/F1L5vsvvTLfqlvZcdY/X4ZUBOQQVie5es7UHQQkUp/dKHJzKYB00isIn9klzZ1Mx3Hvk/s7GNKd3cu7nCZHOh8PgSS9/sc+bBBTTKv7AAj3Hw1S1tdtBeF+g5NtHQuK69Hps0FJszO+FXraJFYuTTxhlu43puNxGgMfTxccn0RjYCKBHuWalPjTmdJsLpKlh3Zog+z336kdSpSCWKmpzWVrR7idK4zuER9am93+92KxNFxT7LwTB5FFFzHP1Zh63bbVxDzr2Yb8nch4CFnTQrMPPQPPLWubrn7fRll3EAI5TriNrHAyx3mfrfrnzTRechz/ZI6jDxQ/ynHyLnzg8+AwPr7Fccq3OS6EplvoXo5T9+Hj0fj4GceF/43jtCmO02McF4ng42scZ3yT48y3clz0GCwuY2/LXsQHFHDs/+U4B6tzMTw+hqV4F1ltQuS45MM5LnUJx6XxO6S/x3HZ0zguByXl/Ds5rljCx885rlRHSHkZx1UeyXFVfH0YHyMXcFwN/elRPPcY5rXj7+C4CdSok/h8Cl+fBinN7PEcN/cEjpv/IsctnIEP/H6LeNwODR94zZ1hfOCxuy7Hx184bvfnOG4Jz7HnlRy3jNda/h+O24vnPeI+jjsSOtv7wBi6/5857igFH5/nuAOv4rijZ/GB7x98F8cdcxw+/spxx/6B447D+3b8rznuhFs47tC1+PgFx52Ix5z0OHx8geNOrnDcKfh3nPoZjjvtVI47/escd+aTOO7sEMed81WOOw+fX/BnjnvYlznuIvz+l+DfdCneq8t2ctzlD+O4K/D7Xfl/HPcYqKI9bo7jrprmuCfADtfEOe6fjuC4p2Q47qlP5LinXcFx10JN8Zlnc9yz8f3nwMjX4Xmej8fdADzKi3mOewns9FL8+1/2Co57BbSlboTtX4V/782w4WsOcNzr8O+9FffqG57JcW+COt9b8Ny34fneDsa1f8fv/M5Jjnv30Rz33q9w3Pt/zHEfxL/3Q4/iuNvxHB8Bevqjd3Pcx+Fnn4Affep8jvsMfOJzQxz3ebSgvghbfAl+8eVHcNxX8hz31b9x3NdB3PdNvNd3Yg3627D/d2GHu/E73YvX/eHVHPfj53LcT/Hv+jn+nb+Ev/wKses3v+O4332f4+7H6/0RP/cn2OUvkCH76584bgX++uD/cIT8lSPCrzkiPosj8us5onyOI2GNI/qLOGKcwRH4LbHexhHn5xxxP8uR5D6OpD+IEchXOJK/miPFWY6UfsKR8t0cqZ7GkZERjoyGOTL2G/AM4nmnXo5C7RqOzP6CI/A5svgJjuzEa+3Cay/dy5HlP3PkiNdwZN+pHDmqzJEDt3DkYI4jx+Bxx01x5IQzOXJilCMn4flPwddO28ORM07myFkVjpyN1z/nTxw57ykcOf9THLnwQo48fJojF+Nxl9zMkUvxvJf9f+19eVxUVf//+67iGgYoKiimKOgMOwjMAIPsMKwDhqaFqaWPZuSSWvqoj5qWe6lplkuZYg4wbLINCAjDIrKIgJqWlT2Zj5aV5pLK9zOXkXCp1+/3f8Pr/fqce9bP53POed9z7+HeS7rNmgRmNtky5z6YuTlgUneCmceDmS8QSMeFxWAWfQhmySowbx0DszQSzL9TwSynvCtfBrNqBZg1dmDeuQ7m3RQw66nOTTZgtowA8z7l3eYGZvspMB9Sm7uWgdlNcR9Xg9kzGsze78DsJ70/2wbm80wwh34Bc5j0OkJ+SM8Dk9EIRjcbTHYvMLlkZ14hmPxKMIVtYIrngymhNo5lgSmfCuY42VBFuhiojpo0MHUzwdAYYRpEMI3UfvMbYFrIltOkZxvZc0YB5lwomPNjwXzlBeZiLJhvqY3vPgXz/TNg/vs+mMtrwFyJAvO/JjDXSKefyc+/kH03poD5fSKY2xZg7nqCuceAeUA+6+gAy44HfXUIbI8lYHs2gu19DGzf62DN14J9NgqsZTLYAS+Ctc4CO2QEWNveYIdWgrW7BXbEBrD2N8E6uIF1zAc79jZYeR5Y56lgXSPAuk8D6xkLdtyrYH0swPq2g1X+BDaAB6vSgx0/B2zwarChFWDDtWAjj4NVvwY2Zj7YOGov4QrYxNNgnx8JduLbYF+oBTvlCNiXToKdSnHTOLDTKf2Vz8HOVIOdlQN2Nun0mhXYuWRXah+wbzSAnb8X7MJmsIsKwb5FZd6+BHbZIrDLHcGueAD2P7+CXX0Q7DsvgV33Htj3PgW7kWzavB7s+95gt30D9kM52F1hYHefAftJINi9pPs+8sFntmA/9wV7KBfsF+PAahPApl8Dq3MCm5UJNpdsPfo82EJ3sEUbweqp3dI6sGXfgj1ObVRR2Wp7sDWUVrcJbD3FN5wF20R1t3wPti0U7Bny47ldYM+THl8lgv36ENhv/cBe2gH2v1+D/XES2Cu/g73aAvZn0uf6ZbC/DQN74x7YWy5g78wE+wf5+D75puMjcEwKOG4aOOEyuB4vg+vpBq73GHB914J7ZitdkSeDs6gEZ0Wf/x4YCG7QdHBDboGzvQvOLgHc8JvgiN64UbSf6pAEbkwNOHkoOGcq60ZfkPZQgvM6AM67BZyCFmF+QeACtoMbT3UFR4IL/RJcOJWl0wkXVQcuOhNc7ARw8aSLhsomDQJHfc4l14N7gQU3JRHci1fATaV3Aby8Bdy038DN0IJ7dQ+4WVXgZpM9cxrAzT0ELvUbcPOcwc3fB27hH+AWZYFbUg3u7anglnmCWx4BbuVKcKtGg1vdBO6dz8CtmwXuPVdw69vAbVwIbvMUcFvfA/cB+Wg72b7jAbidd8DtdgT3Cem/dxu4/Y3gPrsG7nOq5yCVS6NyX5D+2kXgMujJhkzySRbZmJ0PLjcV3FGqs4BQRP4p3guupADcsfHgyueBO74DXCXZYvAGV0Offa6zBXfiKLiTpFvjZnDNPcGdqgXX+gK49hngzg4A9+VAcBeoLy+OAPetDtz39D8cP5BdV+zAXaV6fsoGd30/uF9J7xt6cL9T/90hP/1RDO5+NS2FeoBnncHz28GLr4Lv8Qv4nsnge+8A33cF+GfGgO/vBd6CrkAtb4EfsAa89T7wg93B29BFkW0m+GER4Ie/Dn7kK+BHzQPv8Cx4RwP4sbHgZY3gnekhfJefwLvlgPfYBd7rO/DeH4P3XQteSfX69wQfkAc+8N/ggwLBB/8APnQv+PDN4COPgFdfBh87GXx8DHjNbPBJw8E/PxX0NT7wL9CX0KYcBf9iPfiX7oCfuhz8tDfBTyfbZvwG/tUW8LN2g6exwb+2GPzrlD+1Ffy818DPbwC/kGx/cwP4xZS25Cz4t0n/ZUPB/3s++OXF4FcSVr0Lfg3ps/YE+HfJPxuWgt+UCH4z+WyrJfj3CR9MAr/tDPgdE8F/uAr8R+Sz3eSnT+hWy16yf99n4D+l/Ae2gj9IZdPI/i/Iz0eywKeT3ZnTwGepweeQXXnkg/xPwRfWgdf7gi8lPcvJ5uMjwFeSPQbySY0WfN0B8MQTfCOln0oCfzocfBv5+Az1ybnT4C+MA/8VpX9D/fAtlfue7LscAv4K2XRVD/5n6qdfqN9+GwD+Jr2AjDiCv+MH/g/q+wfG2+S0TKZlk8BnQhBXQjCrgdDrNwh9KNxvMgRzDwi0/hUs34Mw4BoEa8LgIgi2ZhCGvQJh+FsQRhyAMGo+BMeBEMYOgCDfDMF5GgTXNRDc90Hw/BTCOB0EOi8IvlQ/rUsF/2QIqtcgBFJbQWcghFyAEN4TQqQ/hKi7EKJvQoiTQ0iwhpCYAuH5oRAmKiC8kA1hym0IKdTeyysgzKDrv1fKIMwyhzC7DsJcaiOV8syrhLDgNIRFoyAs2QThbWp3GR0vp3b+Q/qtCYDwzjcQ1l2F8F4HhI1k02Yqv/VbCNuGQ9hxC8JOwu5BED7pC2EPhfdPh/AZ6fL5+xDS7CB8MReClmzI0EDQjYSQTek5pNvR/hAKtkAo8oOgt4VQOgFCWT8IFf+BUKmCYCDUvAqhbiOEE2TryWMQGntAaNJDOLUdwulyCG1KCO3U5tm1EL5cBeHCNghfU7vfUPg78vf39yH8cAXCj59B+F81hGtUx8/fQ/iF7P6N/HvzOwi3D0G4mwXhvg+EBzch4lvQpgFEYRrEHnMh9pwA2g8EvQ0JYr+7EM23Q3z2PxAtdRAHPIBofRji4Hcg2uRDHDYaol01xBGpEO0pPHoGRMerEMdSnU6vQ3TxhOi2G6JnPMRxRRB9xkP0/RmiXwjEAC+IqnKI4zdBDF4HMXQfxPBoiBFfQIyaBFF9EmJMG8R4N4i0ThQTKe+EYojJ2RAnUdrkKRBfvA4xhWyYNhbi9GaI1OfiTLLjX9MhzvGBOHcPxNRDEOedhbiA9F5kA3FxIMQlNRDf7oC4bDnE5XMg0rpQXJUEcc0HENeuh/jupxDXO0Lc8DHEja0QN++FuDUY4gdbIG4nv3zIQtwlg/jRYogfW0L8ZCjEPVT/PorbT/YdoHYO9od4aCfEw1T2iBVErQFiRhjEzHsQs85JYKQr1/HzppfZvPSM8iaGcJeNF6yNR4MSjfKbhtvXO2519ONepnM1qKfYzutcthGhzGhCMYK5UISy8+BAX2J1p0+DqpipeJ1JQjAzCR6sD1zY4XBkbDGMOUf/+1sDe+ZrjGanw4HZjf5sBIXpNjC7AKPYQMK/4MBOoWPal2GjKf+PGIcHoM0ABLIc5OxQqtMDSm4ePNliyisn/AuObApJe4IdYSrsCQ6MNemVip6kgzF+NJtN8g2SSwgRFF5LMolkCrW7iuRbhE8xmrMluZDSZhOM9ZzFRqPOJEOZVtCWBXzZADo+T3Y1kD1nKfwHRjDbKe91Om4nvdsovA/PMWkUpmPSw5H5H8mxlO8qpf1EZS5TnIHi6IKbuUZtmVN4L0mO9BlJeX6Q2g5j5mAJ8yNUdPdAzsjwDmECFwhzQn9CCP1PdT/uefQgiIQ+nLrjvnSsMUqCUb5E8RqCP3jOXpL9uGHoSy+mGcjZUFiOARTfjxuOZ6RjYz5/2FH6w7xGWEjSi8qMgCM3FlZSmgyWnPAU9CD9XiL4w4ZTYxjJsfSUpSX514K9gd6cJ4WfBktq15L08ZfaHiDF9SZYEWxM0ghj23YEGwl96NHBgaRLP5J9qT3j0q63BDUhxCRjpDijbbSElHToJZX1hxnZ35vKPyu1YUN1dMrO+pOMtnZ0UHgw5R3yGCxIP/Mu/R7CQtJxBNUJ8ldfCgcRXAluBBeTdP0LuNG7psaSVHTBhsZmZx0KqbwFvKleP24ofEgqqP1QbhDNjTGUNojm42jIKN6V4n0oj5LC/lTO6i/6ytiXxr4aJvn6YV84kW+sTLaYS33T6Xsn8pM1tclQG/5wf0TvTtscTeFOG0O70jrj+2Eo14va6o+h7BXCfUKHFDeUoxtU7D2SPSQb3Dh3auOvxthDaEy6P7TBguzp/ZSxZRxPLiQduo0pq6eMLSMGEAaT3gMxgv2VdLpFIGmyw6MLSRhDUi7NF2eSvMkOK0JfwgiCnVTOQcpjRHd7HurmR/FP08dG8tlwsnEMjd8x3CSM6gobES+17yr5/Tk8x3nQsQthDEFGoF0bmrNjqO8cKH4U2T5aiutuw0PIqa3HfW306UNfPu4z+8eOGQyirwLbUv/akhxEfWhLOtnSnHMkP40gXUdwyQRjeJJJakyYTPCnMT2AfGVjwkjCUMIgkw8Hmo5F6mNj2nAT/m589P4LnukcD3amMeko5aObnqSvA21NOpA9ndKf5k/nmO6O50x4PM6L4GuCca4GE1QmGdwtPYj0lj+Wpupmx+BHbJhKfZBENrsS7B+bo4/aM4TGrAvp7kJc7URyNM0FR8JY8v1o8rGM6jLO2ZESkilsL/GKjMbLaJrTj/puxGP+M/axj5TfnNDLhN7Ejbe7HfciPftLfDqU8g/BIPYnOh/1RA/2Lkm67qOxQf/4R8d3SPpLnGrkHyua972IZ4xx1t180f+J8Wj1N336sF8HEsxMPPDY/Gavo5cRkg6kE7Vrzt6mdgcSnqP6kyktnng9mcaWl9E+Sb8nx1T3ueoPe4rrbeJDd9O4MnKfbRcipfE2WMIUCqd0gzuVl5Fv44mjjJhIiCQ/REv5nak/x3Txx5+wfyLOWeJBO+l8a9RhDM3rcV3pTo/k9XpMGtvpHMeP8kCfbuHJ5B/j+TyGEElQd+Nd2f/DvOtsR9Ht/DDMBLun+vXP8/0QWjuMNZUfZbKlE85d9j7qi9COB+R3jnzYh3Tty02nNUI0IYkwkTCF0Hku60tcbWFcm0jrHEjj1oLGQ2ecP+Xxp/4zjoFx0vpouGSr+VP4Zko3vvxr+927pI20JupLPrYgOy2IOy2I7yyIBy2IIzpha5JJNL6Ma5Ep1EcTSUZL4+1Z0/gc1k1aPJUTH+o10qSHlXTecezqA1eTjKZ64mnsGZEkjcE/ZaSUx1qCN2G45BeZtNYJJGkprYlk5EdrU72d6bJu89fo60f9YtHNN5162Unz1JrOu9bEE4PYH0n+Qf3V2batZKMvrdusaH7YEjrPRRZSvxl9Ym9a6/Q1tRvfjTcf5wQZrXvNpfiBkv+jaVym0NxNofn4EEkS77lTW/Z0Hu2+dnPsNhY747v7nnmK/5XdzvX2XdKN+rQ39a09jVN7bjzZ1skVFqZ5bi+tU5+Ms+9qr4eprqeNv4c2G9fM1mTvs1IdltTWILJvMDeTpDFslO7SeqWTp4xxPlKfDuqCM6W7SOmdx67EVUYdzKhvzejcYCadr/qTLTYkbcj3nejMbyvlfaijcS32rEnSO4HJ/5ZPXW/YP7besDeVGdGlh/EcPIiujzr3Zu06vHGXu0zXr+e5lx/fn+XS6CpgBLPFeKeJfY+lnTZEdUrmRbjR36M/pnvx8dF2diiDXftOUxv/ws8Pd4AZHUs7kLCjK2VIICqh5304KZXu1VnS3qcwijYIezKjKNdL+Led7Shx1Awto+W1Ztr+WivtIK2N1ln7hnaBdrF2pXaVdoN2i3af9rBWpy3UlmjLtZXai9pL2svaX7S/aW9q76UjvX+6Tfpr6anpb6YvS1+ZviF9S/qB9LL0i+m30+9lIMMso3eGS4ZHhneGKiMoIzIjOiMuY0rGSxlTM2ZmlGRUZjRmnMk0y5RnemQqM4MyIzJXZBZm6jPLMmt0fXTBunBdpE6tS9RN0S3VrdDt1H2k+1i3X3dYl6nL1RXo9LpaXZPuou77rJ5Z5lkWWYOyRmY5ZMmyxmWpsoKzkrIWZy3NWpG1Lmtj1rastGw+2yy7T7Zd9pbsbdm7sg9ma7Nrss9k/zf7cvbV7J+yb2bfyr6Tw+RY5STlJOdMzpmRMytnbk5qTlVOTU59TmvO2Zx7uea51rk2uXa58bmJucm5M3Ln5B7Izc+9kHsx91Lutdyfc3/Js8yzzhuZNzrPMc81zyNPlReSp86Ly9ufdyAvLe9IXm6ePq8sr+lo/6P2Rz85euDo9XzHfJd8RX5K/rL8Ffmr8zfkb83fmX8k/1r+9Xx65VGBWcHIAocCzwKfAlXBlIKUgjcKdAU/FiYXLixcXLi0cHXh2sJNhemFusLcQn3hscLawvrChsLmwrOFXxZ+VXip8E6RT5GySFUUXhRdlFg0qyi1aEHRmqK1RYeLjhTpigqKiotKir2KvYuVxf7F0cVxxcnFU4vLim8X39ND318/QG+tt9Xb6x31cr2rPkK/Wr9Ov0G/Xf+hfp8+TV+ir9Sf1DfrW/U39bf190qEEvOSkSVxJRNLVpasLnm3ZHvJrtLg0vBSdenzpRNLXyidWjqzdGnp5tK00qbS9mNmxwKPhR+LP6Y7Vn+s6dj5suSyLWXpZbqy3LKSsvKy2rIL5bblduUjy+XlruXe5aryqPLE8pnlqeUby7eUbyv/uHx/+cWKQRU2FXYVDhVjK+QVbhVzKhZULK84UJFWoa3IqyisuFBxseJSxbWKnyt+r7hzHMctjs86nnr87PGvK2dU/lJ5u6pPlWOVrEpRFVIVWaWu0lRNrHqxKqVqWdWKqo1VW6u2V+2syqsqrNJXVVbVVjVUNVWdrrpWdb3qhoExiAYzg41hpMHBIDO4G8YZfAyBhmBDkmGyYalhu+GwQWfINRQYygzHDVWGekOT4bThouGq4U41X21XPbJaWa2qDq5WV8dXJ1cvrF5cvax6TfV71Zuqt1Zvq95RvbN6f/Xn1doapoavMavpXzOgxqbGrsa5xrtGXfNGzcqaNTUbau7Xopav7Vvbv9a6VlYbV5tYu6W2vLaytqa2ubaltrX2XO2F2h9qr9XeqYuui6ubWre6rqSusq65ruVExIm4E9NPXKrvW29ZP7zesd6p3qXeu96/PqR+Yv2u+o/r99Wn1R+pT6/PrW+qv3TS7KTtycknt5/cefLjkwdOHj6pO3m5wbMhuWFyw9SGmQ2zGxY0LG5Y3bClYVvDgYbvG2432jS6NCY1Tm6c3ri48WLjzaY5TalNC5qWNn3elNakbSpvqmxqbbrQ7NLs3RzSrG6Oa57SPLN5afP+5rTmrOac5rxT8lMrThWc0p8qO1Vz6npLnxbzFssWhxZFy7KW1S27WnJbClr0LbUt11qun558esnpFafXnd7YyreatSpbVa3Brcmtk1tTWme1vta6oHVd6+etta1nWr9svdSGNqs2mzafNmVbdFtSW3Lb5LZZbW+0bWhLa6tsq2+72Ha5fVC7XbtHe0R7fHti+8T2lPYZ7bPa57Sva9/QvqV9J+0PG9l0OKba2YwSiCch8aS51oJ4cgjxZCrx5CLtii6eTJN4Ut/Fkz88xpNziCfn/y1PjjPxpJp4crKJJ/VdPCmTeHK8xJMFT/Ck5hGe3KdL0x0x8WSNiSfNJJ60/kuefP8xntzZxZOXiCf/Rzz5m5EnszuIJxMlnpxu4slK4skTOacf4cm4R3jyPPHkd7lXH+NJl248ua+LJ4slnjTv4kmHfGeJJ5eaeHKzxJNXiSfv5XcU9JB40qPAm3hysoknLxNPLujGk9ounqyReLJJ4skLEk96P5Un07rxpMfTeLK4g3jSknhyiH6kxJMuT/Ckvosnb0g8yXfx5AriyXVP8GTKYzypeoIntWWZxJN64ska4kkbE086P8KTG7rxpPXf8uR5iSevduPJmSaenF55XeJJB4kng6vCJZ58XuLJpd14MreqoKqYeNJg4smrRp6suifx5JBHeFJFPJko8eS2/y+eXEA8ubR6VfU64sktJp7cV32AeBIST5rXWHXjydSaFcST62vuSTzZ5xGeLJN4skniybO15yWevF2nNvGk3sST4Sae7CPx5GgTT/rVB9cn1+/8C57c9hSeTHmCJy/9DU8ekHiyjHiypen8Ezy5r4snZX/Bk0uJJ3d28eRViScX/wVPzpR4ci3xZE0XT1oST3pLPJn4VJ60NvFkHPFk8pM8ya3tuNjx9UX637+z9xOnJU5NfDHx+cQJiZrEhERVIjQPNPc0NzU3NFc1P2rOaVo0JzVVmuOaMk2p5jPNPs0ezQ7Nds02zSbNes3bmjc0z2nsNEM11horTW+NWcLNhHMJxQkHEvYn7En4MGF7whsJcxPmJMxImJYwJWFywqSE2ISYhOiEsPgb8T/FX4o/H58e/1786vhl8Yvj58f7xYvxfDwTdzcuP25F3LK4pXFvxy2Mey0uNk4d5xnnEece5xI3Js4xzj7uubhhcZZx/WI7Yv+IPRvbEtscezL2eGxZbElsTuyR2LTYnbFvxs6PTY2dFTsjdmpsTMxvMddjrsWci5kdMzNmRszEmMQYn5gxMcNihsbYxAyJGRgzIMYqxjz6fvSx6JLoouicaF20NvpIdHL0hOjE6OjoyGiHaKvoftG9o83UZ9Xt6tPqGnWFer16iTpJrVHHqyPVEepw9Sj1CLW1eoDaSv2Muq+ajXoQdTvqZtTBqANR+6P2Rn0YtTVqU9TyKFWUPPJopC5yRqRTpGPksIg/Ii5GfBXxZcTpiFMR9RFFEW9FLI54LWJOxKsR6oiICP8IZYRXxJCIQRE9w0+EbwsfFd47vGe4GNYRdj/sVti5sDNhrWENYfVhlWEVYeVhZWGFYQVh+WHZYXvCUsJeDHshLDEsLiwyzCvMJUweZhtmE3ov9I/QW6HXQ38KvRa6KPTN0Pmh80Knh74c+kKoJuRmSGlIcUhhyOGQQyEHQw6E7AnZHbIzZEfI8pCQkPEhASHjQrxCnEJGh1iG9AsRQ2ibJPjb4IvBF4LbguuDC4M3Bb8TnBL8YvALwXHB0UGfBe0L+iTog6D3g7YGbQxaG7Qg6OWgyKARQbbjr40/Ol43Po0ePXEeLxs/PPBg4OuBiYGawLjAiMDQQFWgXPWz6prqiupb1TeqL1WnVXWqClWmKk21UbVetU61UrVMFaAyU4kqLuBewN2AOwE3A/QBeQFHAtYGrA5YGbAk4M2AxICEgNiA8ICwgMCAgACfgNH+Lf4n/Wf4p/id90vwU/v5+A31s/Hr5yf68X6c8r7yrvJ35U3lOeUZZb2yVmlQVioPKw8pDyr3KvcoP1LuUu5QLlcuU76lnK98XTlXOVmZpExQxiojlKHKEGWA0k/ppHRQ9lT8qvhacVbRpmhR1CvqFLWK44oyRYkiW3FIsVuxVfGmYr5ismKiYoIiVhGlCFGMUTgo7BV2iqGKIYrBCmvFQMUAxTOKvooevrm+2b6Zvmm+n/vu8/3Ed7PvWt8FvvG+Qb4qX4VPvU+dT7VPmU+JT77PAZ+VPv/2CfKx9HnW5xkfM58ePqIP58N63/G+4X3Fe6f3Du93vKd7y71Hew/xHjzu4Lh94zaO6+f1g9c3Xq1eTV71Xie8Kr3KvIq9DnvN9prl9YrXS15TvCZ7TfBSeDl4CZ6/eOZ4LvV8y3ORZ6rnHM9XPJ09vvMo9yj1KPbI88jxOOKR5vGJx/semz1WeAR6OHv0cb/j3ure6F7jnuce4+7rVulW7lbqlu+2xW2T23q3xW5vus10e9nN3K2n633XW643XC+7fuV6wjXN9VPXj1x3ue50fc6lyWWXyw6XD1w2uMxwiXQJcwl2cXUZ5vy181lng7PW+bDzQeePnBc7v+nc2+m60xWn75y+dprl9IqTu5OLk9xpsNNAJ0unvk69nHj5r/I2ea78oPyA/GP5Svlc+Ux5tDxKrpB7yt3lLvKRcls5J7ssOykzyHJkWtky2SLZdFmcLFIWLguRBcgUMm+Zl2yIzFpmJev3510AYSj++f3z++f3z++f35O/qaDnF+j/MycZ71zy9GwCvZ8HpjBD/weUYAqz6EdPBHaGOXqf0SumMI8B9GrczjDtZdKTT51hkeIr6CG215FK7/uZh1n0ppOZ9OCtHd1xdYErvCmUSDEzSI6ntyLY0RuSkhBI0vgE1ev0wt0Z9NJ+Y/5AekPYAsr5OsXPp1wLSecESjW+OWwOhedRbU5Up7FWBdURRV+Zi6FQZ075Y3k7Y+0ei51AR8baZ1Ercyn1zxqfXkvn3V76deQ9cQfZdB9Z+o/3Z6TzUC/QDjc9pRCqToSZ9GAQpLsdD58m6oU+5F3p939XrLAL"
