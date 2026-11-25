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

func add_exit(at: Vector3, r: float, to: String) -> void:
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
		elif herb_kinds_done() >= HERBS.size():
			book_footer.text = tr("다 모았어요! 마을 최고의 약초꾼이에요.")
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
]
# 물고기 잡는 곳 (도감 마을 칸과 보상)
const FISH_PLACES_KO := {"ch1_pond": "남쪽 연못", "ch1_creek": "개울 여울"}
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
	return fish_found_in(fish_place)

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
