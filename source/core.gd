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
	# 좌판: 널빤지 여러 장을 이은 판, 판 아래 앞가림 널
	for k in 5:
		var pz := -0.48 + k * 0.24
		var pl := add_mbox(root, plank_mat, Vector3(4.0, 0.08, 0.22), Vector3(0, 0.92 + (k % 2) * 0.006, pz))
		pl.rotation.y = (k - 2) * 0.004
	add_mbox(root, dark_wood_mat, Vector3(3.9, 0.08, 0.08), Vector3(0, 0.84, 0.56))
	for k in 13:
		add_mbox(root, plank_mat, Vector3(0.28, 0.76, 0.05), Vector3(-1.8 + k * 0.3, 0.44, 0.52))
	add_mbox(root, dark_wood_mat, Vector3(3.9, 0.7, 0.9), Vector3(0, 0.42, -0.02))
	# 둥근 기둥 넷과 들보
	for sx in [-1.95, 1.95]:
		for sz in [-0.6, 1.6]:
			var h := 2.72 if sz < 0.0 else 2.38
			add_mcyl(root, dark_wood_mat, 0.065, 0.075, h, Vector3(sx, h / 2.0, sz))
	add_mcyl(root, dark_wood_mat, 0.055, 0.055, 4.1, Vector3(0, 2.7, -0.6)).rotation.z = PI / 2.0
	add_mcyl(root, dark_wood_mat, 0.055, 0.055, 4.1, Vector3(0, 2.36, 1.6)).rotation.z = PI / 2.0
	# 줄무늬 천 차양
	kit_instance(root, awning_mesh())
	# 바구니(엮은 결)와 과일, 옹기
	for i in 3:
		var bp := Vector3(-1.3 + i * 1.0, 0.96, 0.1)
		add_mcyl(root, basket_mat, 0.3, 0.22, 0.18, bp + Vector3(0, 0.09, 0))
		var rim := MeshInstance3D.new()
		var tor := TorusMesh.new()
		tor.inner_radius = 0.27
		tor.outer_radius = 0.33
		tor.rings = 24
		tor.ring_segments = 6
		rim.mesh = tor
		rim.material_override = basket_mat
		rim.position = bp + Vector3(0, 0.18, 0)
		root.add_child(rim)
	kit_instance(root, stall_goods_mesh())
	# 비단 두루마리 셋 (끝에 둥근 심)
	for i in 3:
		var col: Color = [Color(0.4, 0.6, 0.85), Color(0.95, 0.6, 0.7), Color(0.55, 0.8, 0.55)][i]
		var roll := add_mcyl(root, glossy_mat(col), 0.1, 0.1, 0.62, Vector3(1.55, 1.06, -0.25 + i * 0.22))
		roll.rotation.x = PI / 2.0
		var core := add_mcyl(root, dark_wood_mat, 0.035, 0.035, 0.72, Vector3(1.55, 1.06, -0.25 + i * 0.22))
		core.rotation.x = PI / 2.0

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
	# 길 끝: 기둥 대신 나뭇잎 사이로 비스듬히 내려오는 햇살 몇 줄기, 땅에 번진 따스한 빛, 떠오르는 빛 먼지
	var root := Node3D.new()
	root.position = at
	add_child(root)
	var rr := RandomNumberGenerator.new()
	rr.seed = int(at.x * 13.0 + at.z * 7.0)
	var shaft := make_sun_shafts(root, rr, 4, r * 0.75, 7.0, Vector2(0.7, 1.5))
	var glow := make_ground_glow(root, r * 1.5)
	var motes := make_motes(root, r * 0.7)
	if label != "":
		add_tag(root, label, 2.6)
	exits.append({"c": Vector2(at.x, at.z), "r": r, "to": to, "shaft": shaft, "glow": glow, "motes": motes, "node": root, "level": 0.0})

# 햇살 줄기: 모두 같은 쪽(해 쪽)에서 비스듬히 내려와 땅에 닿아요. 위아래로 스르르 사라지고 천천히 일렁여요
var sun_shaft_shader: Shader
func make_sun_shafts(parent: Node3D, rr: RandomNumberGenerator, count: int, spread: float, height: float, width: Vector2) -> ShaderMaterial:
	if sun_shaft_shader == null:
		sun_shaft_shader = Shader.new()
		sun_shaft_shader.code = """shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
uniform float strength = 0.0;
uniform vec3 tint : source_color = vec3(1.0, 0.9, 0.62);
void fragment() {
	float across = 1.0 - abs(UV.x * 2.0 - 1.0);
	across = across * across * (3.0 - 2.0 * across);
	float v = UV.y;
	float fade = smoothstep(0.0, 0.45, v) * (1.0 - smoothstep(0.9, 1.0, v));
	float bottom = mix(0.55, 1.0, v);
	float shimmer = 0.7 + 0.3 * sin(TIME * 0.9 + NODE_POSITION_WORLD.x * 0.6 + v * 5.0 + UV.x * 2.0);
	ALBEDO = tint;
	ALPHA = clamp(across * fade * bottom * shimmer * strength, 0.0, 1.0);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sun_shaft_shader
	var tilt := Basis.from_euler(Vector3(0.32, 0.6, 0.0))
	for i in count:
		var h := height * rr.randf_range(0.8, 1.1)
		var foot := Vector3(rr.randf_range(-spread, spread), 0.0, rr.randf_range(-spread, spread))
		var top := foot - tilt * Vector3(0, -h, 0)
		var holder := Node3D.new()
		holder.position = top
		holder.basis = tilt * Basis(Vector3.UP, rr.randf_range(-0.3, 0.3))
		parent.add_child(holder)
		var w := rr.randf_range(width.x, width.y)
		for q in 2:
			var mi := MeshInstance3D.new()
			var qm := QuadMesh.new()
			qm.size = Vector2(w, h)
			qm.center_offset = Vector3(0, -h / 2.0, 0)
			mi.mesh = qm
			mi.material_override = mat
			mi.rotation.y = q * PI / 2.0 + 0.4
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			holder.add_child(mi)
	return mat

# 땅에 번진 빛: 가장자리가 부드럽게 사라지는 둥근 빛 웅덩이 (고리 테두리 없이)
var ground_glow_shader: Shader
func make_ground_glow(parent: Node3D, radius: float) -> ShaderMaterial:
	if ground_glow_shader == null:
		ground_glow_shader = Shader.new()
		ground_glow_shader.code = """shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
uniform float strength = 0.0;
uniform vec3 tint : source_color = vec3(1.0, 0.88, 0.55);
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d = length(p);
	float a = pow(max(0.0, 1.0 - d), 2.0);
	float dapple = 0.8 + 0.2 * sin(p.x * 7.0 + TIME * 0.7) * sin(p.y * 6.0 - TIME * 0.5);
	ALBEDO = tint;
	ALPHA = clamp(a * dapple * strength, 0.0, 1.0);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = ground_glow_shader
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(radius * 2.0, radius * 2.0)
	mi.mesh = pm
	mi.material_override = mat
	mi.position.y = 0.07
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mat

# 햇살 속을 천천히 떠오르는 작은 빛 먼지
func make_motes(parent: Node3D, radius: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.07, 0.07)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_color = Color(1.0, 0.9, 0.6, 0.8)
	m.albedo_texture = soft_dot_tex()
	qm.material = m
	p.mesh = qm
	p.amount = 14
	p.lifetime = 4.5
	p.preprocess = 4.5
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radius
	p.direction = Vector3(0, 1, 0)
	p.spread = 25.0
	p.initial_velocity_min = 0.08
	p.initial_velocity_max = 0.22
	p.gravity = Vector3(0, 0.02, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0))
	curve.add_point(Vector2(0.3, 1))
	curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve
	p.position.y = 0.9
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	return p

var soft_dot_cache: Texture2D
func soft_dot_tex() -> Texture2D:
	if soft_dot_cache == null:
		var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
		for y in 32:
			for x in 32:
				var d := Vector2(x - 15.5, y - 15.5).length() / 16.0
				var a := clampf(1.0 - d, 0.0, 1.0)
				img.set_pixel(x, y, Color(1, 1, 1, a * a))
		soft_dot_cache = ImageTexture.create_from_image(img)
	return soft_dot_cache

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
		var breathe := 0.85 + 0.15 * sin(anim_t * 0.8 + i * 1.7)
		# 해가 지면 햇살이 달빛처럼 푸르스름하고 옅어져요. 닫힌 길은 햇살 없이 옅은 안개빛만
		var night := 1.0 if is_night() else smoothstep(0.55, 0.9, time_of_day)
		var warm := Color(1.0, 0.88, 0.58).lerp(Color(0.7, 0.8, 1.0), night)
		var lv: float = (1.0 + float(e.get("boost", 0.0))) * (0.65 if weather == "rain" or weather == "fog" else 1.0)
		var sm: ShaderMaterial = e["shaft"]
		var gm: ShaderMaterial = e["glow"]
		sm.set_shader_parameter("tint", warm)
		gm.set_shader_parameter("tint", warm if open else Color(0.75, 0.8, 0.9))
		sm.set_shader_parameter("strength", (0.24 * breathe * lv * (1.0 - night * 0.4)) if open else 0.0)
		gm.set_shader_parameter("strength", (0.45 * breathe * lv) if open else 0.08)
		(e["motes"] as CPUParticles3D).emitting = open
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
uniform float edge_scale = 1.0;
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
	// 가장자리가 반듯한 선이 되지 않게 잔물결처럼 들쭉날쭉
	float wob = texture(ripple, wp.xz * 0.11).g - 0.5;
	edge = clamp(edge * edge_scale + wob * 0.09 - 0.045, 0.0, 1.0);
	vec3 n1 = texture(ripple, wp.xz * 0.16 + TIME * flow).rgb;
	vec3 n2 = texture(ripple, wp.xz * 0.29 + vec2(TIME * 0.013, -TIME * 0.019) - TIME * flow * 0.6).rgb;
	NORMAL_MAP = normalize((n1 + n2) * 0.5);
	NORMAL_MAP_DEPTH = 0.7;
	vec3 col = mix(mix(shallow, deep, 0.75), deep, smoothstep(0.2, 0.6, edge));
	// 물가: 얕은 물 아래 젖은 흙이 비치는 빛깔로 (하얀 테두리 대신)
	vec3 bank = mix(deep, vec3(0.13, 0.14, 0.08), 0.7);
	col = mix(bank, col, smoothstep(0.02, 0.28, edge));
	// 물결이 닿는 곳에만 끊어진 거품이 살짝
	float wave = 0.6 + 0.4 * sin(TIME * 1.6 + wp.x * 1.7 + wp.z * 1.3);
	float lap = smoothstep(0.03, 0.08, edge) * smoothstep(0.16, 0.08, edge);
	float broken = smoothstep(0.52, 0.7, texture(ripple, wp.xz * 0.35 + vec2(TIME * 0.02, 0.0)).b);
	float foam = lap * broken * wave * foam_amt * 0.2;
	col = mix(col, vec3(0.9, 0.95, 0.97), foam);
	// 논물: 흙이 비치는 얼룩
	float blot = texture(ripple, wp.xz * 0.05).r;
	col = mix(col, col * (0.8 + blot * 0.4), mud);
	ALBEDO = col;
	// 물가 얕은 곳은 하늘을 덜 비춰요 (밝은 테두리가 생기지 않게)
	ROUGHNESS = mix(0.95, rough, smoothstep(0.12, 0.5, edge));
	SPECULAR = spec * smoothstep(0.12, 0.5, edge);
	//SOFT ALPHA = smoothstep(0.0, 0.16, edge) * 0.9 + smoothstep(0.16, 0.6, edge) * 0.1;
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

var water_shaders := {}

# soft: 물가로 갈수록 투명해져 땅과 스르르 섞여요 (넓은 바다 수면처럼 끝이 안 보여야 하는 곳은 false)
func water_material(shape: int, area: Vector4, deep: Color, shallow: Color, flow: Vector2 = Vector2(0.0, 0.0), foam: float = 0.7, soft: bool = true) -> ShaderMaterial:
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
	if not water_shaders.has(soft):
		var sh := Shader.new()
		sh.code = WATER_SHADER.replace("//SOFT ", "") if soft else WATER_SHADER
		if soft:
			sh.code = sh.code.replace("cull_disabled;", "cull_disabled, depth_draw_opaque;")
		water_shaders[soft] = sh
	var m := ShaderMaterial.new()
	m.shader = water_shaders[soft]
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

# ---------- 참새, 허수아비, 장터 물건 (meshkit.gd 로 짓는 입체 모양, 정점 색 하나의 재질) ----------
var prop_mesh_cache := {}

func kit_instance(parent: Node3D, mesh: Mesh, pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = kit_material()
	mi.position = pos
	parent.add_child(mi)
	return mi

# 고리(단면) 여러 개를 이어 한 덩어리 몸을 지어요. rings: [[가운데, 가로 반지름, 세로 반지름], ...]
# u, v: 단면을 펼치는 두 방향, colf(t, a) -> 색 (t: 0~1 고리 순서, a: 단면 각도), radf(t, a) -> 반지름 배율
func kit_loft(st: SurfaceTool, rings: Array, u: Vector3, v: Vector3, seg: int, colf: Callable, radf: Callable = Callable(), cap: bool = true) -> void:
	var pts := []
	var cols := []
	var n := rings.size()
	for i in n:
		var rg: Array = rings[i]
		var t := float(i) / float(n - 1)
		var row := []
		var crow := []
		for k in seg + 1:
			var a := TAU * k / seg
			var m := 1.0
			if radf.is_valid():
				m = float(radf.call(t, a))
			row.append((rg[0] as Vector3) + u * cos(a) * float(rg[1]) * m + v * sin(a) * float(rg[2]) * m)
			crow.append(colf.call(t, a))
		pts.append(row)
		cols.append(crow)
	for i in n - 1:
		for k in seg:
			MeshKit.quad(st, pts[i][k], pts[i + 1][k], pts[i + 1][k + 1], pts[i][k + 1], cols[i][k], cols[i + 1][k], cols[i + 1][k + 1], cols[i][k + 1])
	if cap:
		for e in [0, n - 1]:
			var c: Vector3 = (rings[e] as Array)[0]
			for k in seg:
				var col: Color = cols[e][k]
				if e == 0:
					MeshKit.tri(st, c, pts[e][k + 1], pts[e][k], col, col, col)
				else:
					MeshKit.tri(st, c, pts[e][k], pts[e][k + 1], col, col, col)

# 매끈한 몸 단면 표 [z(또는 y), 가운데 높이, 가로, 세로] 를 촘촘한 고리로 (캣멀-롬)
func smooth_rings(ctrl: Array, per: int, axis_z: bool) -> Array:
	var out := []
	for i in ctrl.size() - 1:
		var p0: Array = ctrl[maxi(i - 1, 0)]
		var p1: Array = ctrl[i]
		var p2: Array = ctrl[i + 1]
		var p3: Array = ctrl[mini(i + 2, ctrl.size() - 1)]
		for k in per:
			var t := float(k) / per
			var vals := []
			for j in 4:
				var a := float(p0[j])
				var b := float(p1[j])
				var c := float(p2[j])
				var d := float(p3[j])
				vals.append(0.5 * ((2.0 * b) + (-a + c) * t + (2.0 * a - 5.0 * b + 4.0 * c - d) * t * t + (-a + 3.0 * b - 3.0 * c + d) * t * t * t))
			var ctr := Vector3(0, vals[1], vals[0]) if axis_z else Vector3(0, vals[0], vals[1])
			out.append([ctr, vals[2], vals[3]])
	var last: Array = ctrl[ctrl.size() - 1]
	out.append([Vector3(0, last[1], last[0]) if axis_z else Vector3(0, last[0], last[1]), last[2], last[3]])
	return out

# 참새(멧참새): 머리와 몸이 한 덩어리로 이어진 통통한 몸. 밤색 정수리, 흰 뺨의 검은 점, 검은 턱,
# 줄무늬 진 갈색 등, 잿빛 흰 배. 앞(+z)을 봐요. 몸 한가운데가 (0,0,0)
func sparrow_mesh() -> ArrayMesh:
	if prop_mesh_cache.has("sparrow"):
		return prop_mesh_cache["sparrow"]
	var st := MeshKit.begin()
	# [z, 가운데 높이, 가로 반지름, 세로 반지름]
	var ctrl := [
		[-0.125, 0.025, 0.012, 0.01],
		[-0.1, 0.018, 0.045, 0.04],
		[-0.05, 0.004, 0.08, 0.078],
		[0.01, -0.004, 0.094, 0.094],
		[0.06, 0.008, 0.086, 0.09],
		[0.095, 0.035, 0.066, 0.07],
		[0.125, 0.06, 0.062, 0.064],
		[0.16, 0.066, 0.055, 0.055],
		[0.185, 0.066, 0.036, 0.038],
		[0.2, 0.064, 0.012, 0.014],
	]
	var rings := smooth_rings(ctrl, 4, true)
	var crown := Color(0.55, 0.3, 0.17)
	var back := Color(0.56, 0.39, 0.25)
	var streak := Color(0.26, 0.17, 0.11)
	var belly := Color(0.86, 0.83, 0.77)
	var white := Color(0.97, 0.96, 0.93)
	var black := Color(0.1, 0.08, 0.07)
	var colf := func(t: float, a: float) -> Color:
		var z := lerpf(-0.125, 0.2, t)
		var up := sin(a)
		var side := absf(cos(a))
		if z > 0.105:
			# 머리
			if up > 0.25:
				return crown
			if z > 0.165 and up < 0.05:
				return black
			if up < -0.45:
				return black if z > 0.12 else belly
			if side > 0.55:
				if absf(z - 0.137) < 0.016 and up < 0.02 and up > -0.32:
					return black
				return white
			return crown.lerp(white, 0.5)
		if z > 0.085 and up < -0.3:
			return black
		# 날개: 몸 옆에 접힌 깃 (짙은 줄, 흰 띠)
		if side > 0.5 and up > -0.3 and up < 0.62 and z < 0.075 and z > -0.105:
			if absf(z - 0.035) < 0.009 and up < 0.4:
				return Color(0.95, 0.92, 0.85)
			if z < -0.02 and sin(up * 30.0) > 0.2:
				return streak
			return Color(0.5, 0.33, 0.2) if sin(z * 160.0 + up * 6.0) < 0.6 else streak.lightened(0.1)
		if up > 0.15:
			var s := sin(z * 140.0 + cos(a) * 9.0)
			return streak if s > 0.55 else back.lerp(back.lightened(0.15), (up - 0.15))
		if up > -0.35:
			return back.lerp(belly, (0.15 - up) / 0.5)
		return belly
	kit_loft(st, rings, Vector3(1, 0, 0), Vector3(0, 1, 0), 20, colf)
	# 눈: 머리 옆 표면에 박힌 까만 눈 + 작은 반짝임
	for sx in [-1.0, 1.0]:
		var ep: Vector3 = Vector3(sx * 0.049, 0.079, 0.162)
		MeshKit.ball(st, ep, Vector3(0.011, 0.012, 0.012), black, 8, 6)
		MeshKit.ball(st, ep + Vector3(sx * 0.008, 0.005, 0.004), Vector3(0.0035, 0.0035, 0.0035), Color(1, 1, 1), 4, 3)
		# 날개 끝 칼깃: 꽁지 쪽으로 몸에 붙어 짧게
		for k in 3:
			MeshKit.leaf(st, Vector3(sx * (0.066 - k * 0.006), 0.012 + k * 0.008, -0.06 - k * 0.006), Vector3(sx * 0.06, 0.06, -1.0), Vector3(0, 1, 0), 0.085, 0.022, streak, 0.02, "long")
		# 다리와 발가락
		MeshKit.tube(st, Vector3(sx * 0.03, -0.075, 0.02), Vector3(sx * 0.032, -0.15, 0.03), 0.008, 0.007, Color(0.62, 0.46, 0.36), 4)
		for t in [-0.4, 0.0, 0.4]:
			MeshKit.tube(st, Vector3(sx * 0.032, -0.15, 0.03), Vector3(sx * 0.032 + sin(t) * 0.03, -0.152, 0.03 + cos(t) * 0.03), 0.005, 0.004, Color(0.62, 0.46, 0.36), 3)
	# 짧고 단단한 부리 (윗부리, 아랫부리)
	MeshKit.tube(st, Vector3(0, 0.068, 0.19), Vector3(0, 0.062, 0.232), 0.017, 0.002, Color(0.25, 0.22, 0.2), 8)
	MeshKit.tube(st, Vector3(0, 0.056, 0.188), Vector3(0, 0.055, 0.222), 0.012, 0.002, Color(0.35, 0.3, 0.26), 6)
	# 꽁지깃
	MeshKit.leaf(st, Vector3(0, 0.025, -0.115), Vector3(0, 0.1, -1.0), Vector3(1, 0, 0), 0.13, 0.06, Color(0.36, 0.24, 0.15), 0.0, "long")
	MeshKit.leaf(st, Vector3(0, 0.03, -0.112), Vector3(0, 0.12, -1.0), Vector3(1, 0, 0), 0.11, 0.035, streak, 0.0, "long")
	var m := MeshKit.finish(st)
	prop_mesh_cache["sparrow"] = m
	return m

# 허수아비 머리: 자루를 목에서 새끼줄로 동여맨 모양 (아래는 주름져 퍼지고, 울퉁불퉁, 앞은 살짝 납작)
const SACK_CTRL := [
	[1.52, 0.0, 0.2, 0.17],
	[1.58, 0.0, 0.15, 0.13],
	[1.63, 0.0, 0.085, 0.08],
	[1.67, 0.0, 0.1, 0.095],
	[1.74, 0.0, 0.19, 0.17],
	[1.84, 0.0, 0.235, 0.205],
	[1.94, 0.0, 0.225, 0.2],
	[2.02, 0.0, 0.17, 0.155],
	[2.07, 0.0, 0.06, 0.06],
]

func sack_rad(t: float, a: float) -> float:
	var y := lerpf(1.52, 2.07, t)
	var m := 1.0 + 0.035 * sin(a * 3.0 + 1.0) * sin(y * 20.0) + 0.02 * sin(a * 5.0 + y * 9.0)
	# 동여맨 목 위아래로 잡힌 주름
	var near := clampf(1.0 - absf(y - 1.645) / 0.12, 0.0, 1.0)
	m *= 1.0 + 0.16 * near * sin(a * 9.0)
	# 아래 자락은 어깨 위로 펄럭
	if y < 1.6:
		m *= 1.0 + 0.08 * sin(a * 6.0 + 0.7)
	return m

func sack_point(y: float, a: float) -> Vector3:
	var rings := smooth_rings(SACK_CTRL, 1, false)
	var best: Array = rings[0]
	var best2: Array = rings[1]
	for i in rings.size() - 1:
		if float((rings[i][0] as Vector3).y) <= y and float((rings[i + 1][0] as Vector3).y) >= y:
			best = rings[i]
			best2 = rings[i + 1]
	var y0 := (best[0] as Vector3).y
	var y1 := (best2[0] as Vector3).y
	var t := clampf((y - y0) / maxf(0.0001, y1 - y0), 0.0, 1.0)
	var rx := lerpf(float(best[1]), float(best2[1]), t)
	var rz := lerpf(float(best[2]), float(best2[2]), t)
	var m := sack_rad((y - 1.52) / 0.55, a)
	return Vector3(cos(a) * rx * m, y, sin(a) * rz * m)

# 자루 겉에 붙인 납작한 그림(눈, 볼, 천 조각): 겉면 방향으로 눕혀요
func sack_decal(st: SurfaceTool, y: float, a: float, size: Vector2, col: Color, lift: float = 0.003) -> void:
	var p := sack_point(y, a)
	var nrm := Vector3(p.x, 0, p.z).normalized()
	var b := Basis.looking_at(-nrm, Vector3.UP)
	MeshKit.ball(st, p + nrm * lift, Vector3(size.x, size.y, 0.004), col, 12, 6, b)

# 허수아비: 둥근 장대와 가로대, 어깨가 납작한 삼베 저고리(흰 동정, 붉은 옷고름, 기운 천),
# 소매와 밑단에 삐져나온 짚, 목을 동여맨 자루 머리에 숯으로 그린 얼굴, 고깔 밀짚모자. 바닥이 (0,0,0), 앞(+z)
func scarecrow_mesh() -> ArrayMesh:
	if prop_mesh_cache.has("scarecrow"):
		return prop_mesh_cache["scarecrow"]
	var r := RandomNumberGenerator.new()
	r.seed = 77
	var st := MeshKit.begin()
	var wood := Color(0.5, 0.36, 0.22)
	MeshKit.tube(st, Vector3(0, 0, 0), Vector3(0, 1.7, 0), 0.07, 0.058, wood, 8, wood.lightened(0.1))
	MeshKit.tube(st, Vector3(-0.98, 1.45, 0), Vector3(0.98, 1.45, 0), 0.05, 0.045, wood.darkened(0.05), 8)
	# 저고리: 단면이 납작한 몸통 (밑단 → 어깨)
	var cloth := Color(0.8, 0.72, 0.56)
	var body_ctrl := [[0.86, 0.0, 0.36, 0.27], [1.05, 0.0, 0.34, 0.25], [1.3, 0.0, 0.31, 0.225], [1.48, 0.0, 0.29, 0.2], [1.56, 0.0, 0.2, 0.15], [1.6, 0.0, 0.08, 0.07]]
	var body_col := func(t: float, a: float) -> Color:
		var c := cloth.darkened(0.06 * (1.0 - t))
		if sin(a * 2.0 + t * 6.0) > 0.92:
			c = c.darkened(0.07)
		return c
	kit_loft(st, smooth_rings(body_ctrl, 3, false), Vector3(1, 0, 0), Vector3(0, 0, 1), 18, body_col)
	for sx in [-1.0, 1.0]:
		MeshKit.tube(st, Vector3(sx * 0.2, 1.46, 0), Vector3(sx * 0.78, 1.45, 0), 0.14, 0.125, cloth.darkened(0.04), 12)
		MeshKit.tube(st, Vector3(sx * 0.7, 1.45, 0), Vector3(sx * 0.79, 1.45, 0), 0.135, 0.135, cloth.darkened(0.12), 12)
		for k in 12:
			var a := r.randf() * TAU
			var d := Vector3(sx, r.randf_range(-0.45, 0.45), r.randf_range(-0.45, 0.45)).normalized()
			MeshKit.leaf(st, Vector3(sx * 0.76, 1.45 + sin(a) * 0.06, cos(a) * 0.06), d, Vector3(0, cos(a), sin(a)) + Vector3(0.01, 0, 0), r.randf_range(0.16, 0.3), 0.03, Color(0.92, 0.8, 0.45).lerp(Color(0.8, 0.66, 0.32), r.randf()), 0.25, "long")
	# 밑단 짚
	for k in 28:
		var a := k * TAU / 28.0 + r.randf_range(-0.1, 0.1)
		var out := Vector3(cos(a) * 0.34, 0, sin(a) * 0.25)
		MeshKit.leaf(st, out + Vector3(0, 0.9, 0), (out.normalized() * 0.35 + Vector3(0, -1, 0)).normalized(), Vector3(-sin(a), 0, cos(a)), r.randf_range(0.22, 0.36), 0.035, Color(0.92, 0.8, 0.45).lerp(Color(0.78, 0.64, 0.3), r.randf()), -0.15, "long")
	# 흰 동정 깃, 붉은 옷고름, 기운 파란 천과 바늘땀
	# 깃: 오른쪽 어깨에서 내려오는 긴 섶과 왼쪽에서 만나는 짧은 깃 (V자)
	MeshKit.tube(st, Vector3(0.1, 1.55, 0.13), Vector3(0.04, 1.31, 0.228), 0.024, 0.022, Color(0.97, 0.96, 0.92), 6)
	MeshKit.tube(st, Vector3(-0.1, 1.55, 0.13), Vector3(0.04, 1.31, 0.228), 0.024, 0.022, Color(0.97, 0.96, 0.92), 6)
	MeshKit.tube(st, Vector3(0.04, 1.31, 0.228), Vector3(0.1, 0.92, 0.27), 0.012, 0.012, Color(0.68, 0.6, 0.45), 4)
	MeshKit.leaf(st, Vector3(0.05, 1.3, 0.235), Vector3(0.25, -1, 0.2), Vector3(1, 0.2, -0.3), 0.26, 0.06, Color(0.82, 0.22, 0.2), -0.05, "long")
	MeshKit.leaf(st, Vector3(0.05, 1.3, 0.235), Vector3(0.05, -1, 0.25), Vector3(1, 0, -0.1), 0.2, 0.05, Color(0.78, 0.2, 0.18), -0.05, "long")
	MeshKit.ball(st, Vector3(-0.17, 1.08, 0.205), Vector3(0.09, 0.08, 0.012), Color(0.42, 0.52, 0.72), 10, 5, Basis(Vector3.UP, -0.55))
	for k in 6:
		var y := 1.02 + k * 0.024
		MeshKit.tube(st, Vector3(-0.255, y, 0.17), Vector3(-0.24, y, 0.19), 0.005, 0.005, Color(0.3, 0.22, 0.15), 3)
	# 자루 머리: 삼베 결(밝고 어두운 올), 옆 솔기
	var sack := Color(0.84, 0.74, 0.52)
	var sack_col := func(t: float, a: float) -> Color:
		var c := sack
		var y := lerpf(1.52, 2.07, t)
		if int(floor(a * 18.0 / TAU) + floor(y * 60.0)) % 2 == 0:
			c = c.darkened(0.04)
		if absf(cos(a)) > 0.985:
			c = c.darkened(0.25)
		if y < 1.6:
			c = c.darkened(0.05)
		return c
	kit_loft(st, smooth_rings(SACK_CTRL, 3, false), Vector3(1, 0, 0), Vector3(0, 0, 1), 28, sack_col, sack_rad)
	# 목 새끼줄 (꼬인 두 가닥)
	for k in 24:
		var a0 := k * TAU / 24.0
		var a1 := (k + 1) * TAU / 24.0
		for q in 2:
			var off := q * PI
			var p0 := Vector3(cos(a0) * 0.098, 1.645 + sin(a0 * 4.0 + off) * 0.008, sin(a0) * 0.092)
			var p1 := Vector3(cos(a1) * 0.098, 1.645 + sin(a1 * 4.0 + off) * 0.008, sin(a1) * 0.092)
			MeshKit.tube(st, p0, p1, 0.012, 0.012, Color(0.72, 0.58, 0.34).darkened(0.1 * q), 5)
	MeshKit.tube(st, Vector3(0.07, 1.64, 0.07), Vector3(0.11, 1.56, 0.12), 0.01, 0.008, Color(0.72, 0.58, 0.34), 4)
	MeshKit.tube(st, Vector3(0.07, 1.64, 0.07), Vector3(0.14, 1.58, 0.06), 0.01, 0.008, Color(0.66, 0.52, 0.3), 4)
	# 숯으로 그린 얼굴: 눈썹, 동그란 눈(흰 반짝임), 볼, 코, 바늘땀 입
	var front := PI / 2.0
	for sx in [-1.0, 1.0]:
		var ea: float = front - sx * 0.36
		sack_decal(st, 1.885, ea, Vector2(0.03, 0.036), Color(0.1, 0.08, 0.07))
		sack_decal(st, 1.895, ea + sx * 0.06, Vector2(0.009, 0.009), Color(0.98, 0.97, 0.94), 0.006)
		sack_decal(st, 1.8, front - sx * 0.62, Vector2(0.045, 0.028), Color(0.95, 0.55, 0.5))
		var prev_b: Vector3 = sack_point(1.945, front - sx * 0.22)
		for k in 5:
			var t := float(k + 1) / 5.0
			var pb: Vector3 = sack_point(1.945 + sin(t * PI) * 0.016 - t * 0.01, front - sx * (0.22 + t * 0.3))
			var nb := Vector3(pb.x, 0, pb.z).normalized()
			MeshKit.tube(st, prev_b + nb * 0.003, pb + nb * 0.003, 0.008, 0.008, Color(0.15, 0.12, 0.1), 4)
			prev_b = pb
	sack_decal(st, 1.84, front, Vector2(0.022, 0.016), Color(0.5, 0.32, 0.22))
	var prev := sack_point(1.775, front + 0.42)
	for k in 9:
		var t := float(k + 1) / 9.0
		var p := sack_point(1.775 - sin(t * PI) * 0.03, front + 0.42 - t * 0.84)
		var nrm := Vector3(p.x, 0, p.z).normalized()
		MeshKit.tube(st, prev + nrm * 0.004, p + nrm * 0.004, 0.008, 0.008, Color(0.42, 0.16, 0.12), 4)
		# 입을 가로지르는 바늘땀
		var mid := (prev + p) * 0.5 + nrm * 0.005
		MeshKit.tube(st, mid + Vector3(0, 0.016, 0), mid - Vector3(0, 0.016, 0), 0.004, 0.004, Color(0.3, 0.22, 0.16), 3)
		prev = p
	# 머리 옆에 덧댄 천 조각과 바늘땀
	sack_decal(st, 1.9, front + 1.15, Vector2(0.065, 0.055), Color(0.62, 0.48, 0.38), 0.005)
	# 고깔 밀짚모자: 넓은 챙(엮은 결), 둥근 꼭대기, 붉은 띠
	var straw := Color(0.82, 0.66, 0.36)
	var hat_col := func(t: float, a: float) -> Color:
		return straw.darkened(0.08) if int(floor(a * 40.0 / TAU) + floor(t * 6.0)) % 2 == 0 else straw.lightened(0.04)
	kit_loft(st, [[Vector3(0, 1.99, 0), 0.58, 0.58], [Vector3(0, 2.05, 0), 0.45, 0.45], [Vector3(0, 2.12, 0), 0.3, 0.3], [Vector3(0, 2.18, 0), 0.19, 0.19]], Vector3(1, 0, 0), Vector3(0, 0, 1), 32, hat_col, Callable(), false)
	kit_loft(st, [[Vector3(0, 2.17, 0), 0.19, 0.19], [Vector3(0, 2.3, 0), 0.16, 0.16], [Vector3(0, 2.36, 0), 0.11, 0.11], [Vector3(0, 2.385, 0), 0.03, 0.03]], Vector3(1, 0, 0), Vector3(0, 0, 1), 24, hat_col, Callable(), false)
	MeshKit.tube(st, Vector3(0, 2.18, 0), Vector3(0, 2.23, 0), 0.192, 0.185, Color(0.75, 0.2, 0.18), 20)
	MeshKit.tube(st, Vector3(0, 1.985, 0), Vector3(0, 1.995, 0), 0.585, 0.58, straw.darkened(0.25), 32)
	var m := MeshKit.finish(st)
	prop_mesh_cache["scarecrow"] = m
	return m

# 장터 차양: 줄무늬 천이 가운데가 살짝 처지고 앞자락이 물결 모양으로 늘어져요
func awning_mesh() -> ArrayMesh:
	if prop_mesh_cache.has("awning"):
		return prop_mesh_cache["awning"]
	var st := MeshKit.begin()
	var x0 := -2.1
	var x1 := 2.1
	var z0 := -0.85
	var z1 := 1.85
	var stripes := 8
	var per := 4
	var nz := 6
	var red := Color(0.84, 0.24, 0.22)
	var cream := Color(0.98, 0.94, 0.84)
	var fn := func(x: float, z: float) -> Vector3:
		var tz := (z - z0) / (z1 - z0)
		var y := 2.78 - tz * 0.42 - sin((x - x0) / (x1 - x0) * PI * stripes / 2.0) * 0.0 - sin(tz * PI) * 0.05 * (1.0 - absf((x - (x0 + x1) * 0.5) / (x1 - x0)) * 1.6)
		return Vector3(x, y, z)
	for s in stripes:
		var col := red if s % 2 == 0 else cream
		for q in per:
			var xa := x0 + (x1 - x0) * (s * per + q) / float(stripes * per)
			var xb := x0 + (x1 - x0) * (s * per + q + 1) / float(stripes * per)
			for k in nz:
				var za := z0 + (z1 - z0) * k / float(nz)
				var zb := z0 + (z1 - z0) * (k + 1) / float(nz)
				var shade := col.darkened(0.08 * k / float(nz))
				MeshKit.quad(st, fn.call(xa, za), fn.call(xb, za), fn.call(xb, zb), fn.call(xa, zb), shade, shade, shade, shade)
		# 앞자락: 줄마다 둥글게 늘어진 반달
		var xs := x0 + (x1 - x0) * s / float(stripes)
		var xe := x0 + (x1 - x0) * (s + 1) / float(stripes)
		var top_a: Vector3 = fn.call(xs, z1)
		var top_b: Vector3 = fn.call(xe, z1)
		var n := 8
		for k in n:
			var ta := float(k) / n
			var tb := float(k + 1) / n
			var pa := top_a.lerp(top_b, ta)
			var pb := top_a.lerp(top_b, tb)
			var da := pa + Vector3(0, -0.2 - sin(ta * PI) * 0.12, 0.02)
			var db := pb + Vector3(0, -0.2 - sin(tb * PI) * 0.12, 0.02)
			MeshKit.quad(st, pa, pb, db, da, col, col, col.darkened(0.12), col.darkened(0.12))
	var m := MeshKit.finish(st)
	prop_mesh_cache["awning"] = m
	return m

# 장터 물건: 감·사과·배가 담긴 바구니 속 과일, 옹기 항아리 두 개 (바구니와 좌판은 따로)
func stall_goods_mesh() -> ArrayMesh:
	if prop_mesh_cache.has("goods"):
		return prop_mesh_cache["goods"]
	var r := RandomNumberGenerator.new()
	r.seed = 12
	var st := MeshKit.begin()
	for i in 3:
		var bp := Vector3(-1.3 + i * 1.0, 1.12, 0.1)
		var pts := []
		for k in 6:
			var a := k * TAU / 6.0 + 0.3
			pts.append(bp + Vector3(cos(a) * 0.15, 0.04, sin(a) * 0.15))
		pts.append(bp + Vector3(0.0, 0.14, 0.0))
		pts.append(bp + Vector3(0.06, 0.12, -0.08))
		for p in pts:
			match i:
				0:  # 감: 납작 둥근 주황, 네 갈래 꼭지
					MeshKit.ball(st, p, Vector3(0.085, 0.07, 0.085), Color(0.98, 0.5, 0.12).lerp(Color(0.95, 0.42, 0.1), r.randf()), 10, 6)
					for q in 4:
						var a2 := q * TAU / 4.0 + 0.4
						MeshKit.leaf(st, p + Vector3(0, 0.065, 0), Vector3(cos(a2), 0.25, sin(a2)), Vector3(-sin(a2), 0, cos(a2)), 0.05, 0.035, Color(0.35, 0.45, 0.2), 0.05)
				1:  # 사과: 빨갛고 위가 살짝 오목, 꼭지
					MeshKit.ball(st, p, Vector3(0.08, 0.075, 0.08), Color(0.82, 0.16, 0.16).lerp(Color(0.9, 0.35, 0.2), r.randf() * 0.5), 10, 6)
					MeshKit.tube(st, p + Vector3(0, 0.06, 0), p + Vector3(0.01, 0.1, 0), 0.007, 0.005, Color(0.35, 0.25, 0.15), 4)
				_:  # 배: 누렇고 둥글넓적, 점무늬
					MeshKit.ball(st, p, Vector3(0.088, 0.08, 0.088), Color(0.9, 0.78, 0.4).lerp(Color(0.85, 0.7, 0.35), r.randf()), 10, 6)
					MeshKit.tube(st, p + Vector3(0, 0.07, 0), p + Vector3(0, 0.1, 0.01), 0.006, 0.005, Color(0.35, 0.25, 0.15), 4)
		if i == 1:
			MeshKit.leaf(st, bp + Vector3(0.05, 0.2, 0.0), Vector3(1, 0.3, 0.2), Vector3(0, 0, 1), 0.08, 0.045, Color(0.3, 0.55, 0.25), 0.1)
	# 옹기 항아리 (좌판 옆 땅바닥): 배가 불룩한 몸, 좁은 목, 두툼한 입술
	for j in 2:
		var c := Vector3(-2.45 + j * 0.05, 0.0, 0.55 + j * 0.6)
		var s := 1.0 - j * 0.25
		var glaze := Color(0.42, 0.26, 0.16).lerp(Color(0.5, 0.32, 0.2), j)
		var prof := [[0.0, 0.14], [0.08, 0.2], [0.25, 0.27], [0.42, 0.26], [0.55, 0.19], [0.62, 0.13], [0.66, 0.15], [0.7, 0.14]]
		for k in prof.size() - 1:
			var a: Array = prof[k]
			var b: Array = prof[k + 1]
			MeshKit.tube(st, c + Vector3(0, float(a[0]) * s, 0), c + Vector3(0, float(b[0]) * s, 0), float(a[1]) * s, float(b[1]) * s, glaze.darkened(0.05 * (1.0 - float(a[0]))), 16, glaze.lightened(0.04))
		MeshKit.ball(st, c + Vector3(0, 0.6 * s, 0), Vector3(0.13, 0.015, 0.13) * s, Color(0.15, 0.1, 0.08), 12, 3)
		# 어깨에 손으로 그은 물결 무늬
		for k in 12:
			var a := k * TAU / 12.0
			var a2 := (k + 1) * TAU / 12.0
			var ra := 0.255 * s
			MeshKit.tube(st, c + Vector3(cos(a) * ra, (0.46 + sin(k * 1.7) * 0.015) * s, sin(a) * ra), c + Vector3(cos(a2) * ra, (0.46 + sin((k + 1) * 1.7) * 0.015) * s, sin(a2) * ra), 0.006, 0.006, Color(0.75, 0.62, 0.45), 3)
	var m := MeshKit.finish(st)
	prop_mesh_cache["goods"] = m
	return m

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
# 저장: [common] book story {"ch2": [5칸], "ch3": [5칸], "home": [5칸]}. 이야기 조각 자리 이름표는 "ch2:0" 처럼 묶음:번호
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
	"home": [
		{"title": tr("할머니가 책을 얻은 날"), "hint": tr("할머니 집 장독대 옆"), "text": tr("할머니가 그 책을 얻은 건 큰비가 그친 이튿날이었어요.\n장독대 옆 진흙 속에 겉장이 다 젖은 책 한 권이 묻혀 있었지요.\n할머니는 한 장 한 장 말리며 지워진 글자를 기억으로 메웠어요.\n그래서 그 책의 절반은 할머니 손글씨래요.")},
		{"title": tr("정자나무가 심어진 해"), "hint": tr("정자나무 뒤 (등불이 하나라도 켜지면)"), "text": tr("정자나무는 마을에 처음 아이가 태어난 해에 심었대요.\n아이가 자라 어른이 될 때마다 가지에 등불을 하나씩 걸었지요.\n사람들이 하나둘 떠나자 등불도 하나둘 꺼졌어요.\n나무는 그 등불들이 다시 켜지기를 지금도 기다린대요.")},
		{"title": tr("빈 집터의 옛 주인"), "hint": tr("서쪽 빈 집터 안"), "text": tr("이 집터에는 옛날 짚신 삼는 할아버지가 살았어요.\n마을을 떠나는 사람마다 새 짚신을 한 켤레씩 쥐여 주었지요.\n“먼 길 가다 지치면 이 신 신고 돌아오게.”\n돌 기단 밑에는 아직 짚신 한 켤레가 묻혀 있대요.")},
		{"title": tr("마을 이름 이야기골"), "hint": tr("이야기꾼 할머니의 부탁"), "text": tr("옛날 이 골짜기엔 이름이 없었어요.\n밤마다 사람들이 정자나무 아래 모여 옛이야기를 나누었는데,\n지나가던 나그네가 그 소리를 듣고 “여기는 이야기가 사는 골짜기로구나” 했대요.\n그날부터 이 마을은 이야기골이 되었답니다.")},
		{"title": tr("내 집의 지난 주인"), "hint": tr("내 집 방 안 (마을 도감을 다 채우면)"), "text": tr("내 집에 마지막으로 살던 사람은 떠돌이 이야기꾼이었어요.\n마을을 떠나며 궤짝 옆 벽 틈에 쪽지 하나를 끼워 두었지요.\n“이 집에 올 다음 사람에게. 이야기를 다 찾으면 꼭 들려주렴.”\n쪽지 끝에는 할머니가 아는 그 소년의 이름이 적혀 있었어요.")},
	],
}
var TALE_DONE := {
	"ch2": tr("고갯길 사람들은 지금도 해 질 녘이면 하늘을 올려다봐요.\n해님과 달님이 잠깐 함께 떠 있는 그 짧은 시간에\n오누이가 엄마에게 손을 흔든다고 믿거든요."),
	"ch3": tr("자라는 지금도 가끔 갯바위에 올라 뒷산을 바라봐요.\n토끼가 굴 앞에 앉아 귀를 쫑긋 세우면\n둘은 멀리서 모르는 척 고개를 한 번 끄덕인대요."),
	"home": tr("할머니는 쪽지를 오래오래 들여다보다 웃었어요.\n“그 아이가 결국 이 마을로 돌아왔었구나.”\n그날 밤 정자나무 아래에서 할머니는 처음으로 자기 이야기를 들려주었어요."),
}
const TALE_REWARD := 30
var tale_read := {"ch2": [false, false, false, false, false], "ch3": [false, false, false, false, false], "home": [false, false, false, false, false]}
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
			kit_instance(n, sparrow_mesh(), Vector3(0, 0.08, 0))
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
	# 긴 이름(영어 이야기 조각 제목 등)이 대화 창을 화면 밖으로 밀지 않게 줄을 바꿔요
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
		"coins": 10, "gift": "pool_stone", "tale": ["home", 3], "tale_say": "할머니가 이야기골이라는 마을 이름에 얽힌 이야기도 들려주었다."},
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
const FONT_B64 := "eNq0vQecHGl5J9zvWznn0NVd1aE6TE8O3T0z0mikVViF1UobtJmwy7KAYZdwSzobjI0NBu7DBuMAHHef70ywjT9nsDkcwGBwwAdn7uDnD4wxGBvjhLHBgNnR/d+q7pmRNrC7RtJoNJ1qqt73if/n/zxVIZVKxah8X4WrXHfyuvM3Hn/h2RdUpPmfx7PNkzfedLRSreh4/BE8ts/fuLS6fOPM0ytS8H14fOfd99313L9cXP4CHn+2Ugme+/S77n8uex/e/1b8Lz/93v/4tL8dvvpT+PnTFfGrX3rGPXc91Tde9qmKJMp4bvwMPCG9UPwgPv8EPO48477nv/h17332H+H1I5WKVb/3OXffpd/6A5+oiF/7Ih4377vrxc/lPkp28Pj32fk9+6777gleufTTFWnuukqFrD73Ofc//+JvVFbx+3+QvV6hlasvfrnyafrNSlpZq1S8bbK2GkYZFQOnTiSTLJI+vnrjkTMcexmJMmLuPr2ON4/Dm+S6oQVq4AqcJPVmexLHEULE7+EEylHR1LWsHgsCEcTE8rr0LwydUHEwGto7f+rPuI5NHFupaU7XI+f13gOvERRRiyNfEKhoG2bXtDTC4ySP03vJvdzdWLgWThKng9+Nc0mJL0pib/3yJ260KCGDBVfmPHfp7fsf0JdYff/a5aYv94NrvRldo+blT5RrQv+Ufr7yosr3YNVCXLC0mtHpxefS6hg/S75J2nnbpJLJSeIixRmwr7x4D76wQuUzs1iu0XC8vhqureftRToabtODZJvDa1nx3rXlbToq3psRgvfQ/ySKgiYoSS0SeIE3TX6pl+l5FHgkm11yKC6R8KIZ+XbNVyiVeF7mXiRqouD47oKr86LGcRJn5M3QCf1Ff2ZDizzNiuvGYV6xAsfrJJooGeILBFEUa4EaR+7Oe/9j78X0V404GSdEkEUxjDxK6TspJYkf+FKaNzmnVfc5qvp1y0pNp+tUV5NwwTBEV2+2W6aZmrLneg1C3skpjmEHuuAtL82atmB3qvUD9age0+igKVLJ3bntndClmYsfpYc4ofKsygsqL69UhFKouJXie7l242LNo9FECPvlMo4nC71Fyj2P/DAKg0I22WKK7H39yWNRmu6G1BYzEvhc8Xw0MgnBb/FDKdym5AVKs1XjIbUkOhRZrawqQpYdS/VdV4kOJe6CaQTyvK+qsqjX9IbrDH1Z9323LuEjzRP1sEaIb9p1w1mIgkVnY0SJKfu6XnecWZ8d9r1El5XEas0Rm1pRzeCIlYVGbOi851DXszlNFg0nsvVa4mPrdAv7xP+CqPKCJDgdtxv5OT6g27IsU7OhOSalpksdVTOlwDbzxEwotSTZoa8RPSm6e7PXNGNVs2RB4Q3bIg4VZE8UJfo8mu78iRG5BpefzKni1StCZe3in9NP0M9V6pUTlTsrL6y8ttiLUuvLlWYLlnFRyBaTC/ctqcn2qT+cbgj74tbHYUTE9oM+T8rPE/Zcf8j2qDxI8VqpKKPLn6b3t7ab8Yys8KI0l0bLUTjjyKYqEUEw1Pke9TWzbvau6dkNRwlq7dB0SaiZDat3tmc2LdkNE8fJ6M5/bp5oxrksc6I0Xxyl7zgeFSRNG5BlR7YkghVtm6ZBKBVsRw523ixrgsXJjtU0bR3mrHg2wtqro2rzSCsdKTKsnGFKUTXRekfytEZ/JZhxkmFy/JUn0oOZ1Wu6HA3NaNavjZITrzpR36iZWc3neN/b+aZsKqO4daSZjlSZI9QwzZmgd75Ta+z8MFXMedeaU2QiSbGlt1s1Dsbr14koWAue3cc1yHJkaXm7hg9CiY5c/Dz9OfqFyg2VZ1Zeio0rNWVxshfRIsVy07BYfdgp9l+D9LYpew3GjCvXmpn7Qm249eJxsYuLtNjCQqPYAbxii4qDF89llKhaqM2cdm2No9Uq1U2d+JEoqfbxm5/QXxjwlOhJpHiCpoZEUhUih9W6ZUIiLZNXHIVYRKzZYuL1dappEvUGtfxMy2o3qyIVVZWTq0530D8IH2J4Z5qtjOMob1rBRuS5lFPiQZVynDzbb57J81NVqukKqW4dPlxf2gi0ILxluTpcnbflQDajJbyoES32ZJ73qrWqL5hVgzpUXxkuSIJvUttz+agLXXo2NfyqJXm+K3o9NRT44Vy05sYeuYPO1q20XlUt3tIafryUexVSeQ69t/L5wik92CV97yM7HXz6+MVfgwlKKusTfeP6080bXaJRuz5XEgN/okrM+Ygkk7uWWQ09CdZJ1jme8oJgKmpoaWmkty1XlizejOVE5GVZtFQxomRsKKIQ1lM9Xkmqa/XkYBqNs+bBRgM/rNqSRKkdxmr3ZOf++zfH1ZUkXo2cgccLON8hzjcrzzfCOU6Ve308GhanDVEbh7vnFzFju2sq4B97xwmhkahaoizzYiLHpmBKsmu19SjVrFBVTEHAFXC6LAcGVLdqWt0xnJ83cKLVOFmpjjfvv79zsqvGoQ2XJ9mrUcrOu5mN8UNSX6smK7Ge1kNBVHC2y5UPUJk+tXIj89/M9Ii9ObK7eNO45jJH3Ral2UJ7xuFB0ivVCG9vTF7G5TEtWjtAyDc1QlVNy/RrtUgTVLhJXkuzmqwF2rJo6yZstcKbMl70e55R1V3BMQfOIdvQawJXd9xc7eixLlumnikG79fVq60eebdi6jVR5NzclX1VsiRX1mLdaTjXqJEgQofiaqI7bYcSUVswNS4KnPnIhqC1rU2v42ku3JbmDmY6FhZgUPlJ8g/05ZUtLEDEzrzYDtqeIwFbjbyN66PDUT9vi0zPC5nj1qJyX1kMGIoROfJcxzFNxKKuo5FncrhiX20KssSRC5pl6HLg2KqhGdppQk25rpk1gXnED5LynSF75/OdvDhCNXbIswhMsBXibRBWQq6NVhxN9+xgPsIJNy5+ovLJys9VEshXr18aKRYBMOkxuQOmLGAFEJgkNc2oeYrAx/UEZtFxB5TZ4VhhTpzjNK+qIXCqSpLrqDjsDLkO9vOTCG8rpJDPyTrkUyEoQopwnTzNyS1JwpkmONMP6tU4UHByTrAQkY/zuin5ml6TFJUFt5yCjTadlqgQgl/Rvfj+yk9XjlS0SmXNZyuLQ2IFf7qbJF32r/je6+Gd/Yv/RH6DfqjSwzUiEETcup5PHWchl8Kuc71HD20ZhlAm+bFua6MmmG7sJFXBdBy/sdB2u65oynJmyaZvuKl17ievufolW1po8JI2k3QWejNH7jo7ONPVEK3YiGhnKhw9RD9a6eA8K912b2ppikUuFLd08MwlcO2J4gZ+6TqYaMBAkTX81tqKv7w6I0Vpww6T5nWtxaOLMDCU5zW3HvRuG5o1SL8c2F5Vb4X+wE3bDger0ljj4HC70fgNZ59xl9PL65KqqlTWNs8/cbl5uJkeGK8E3QE9ISBOMjs3zM49oefWRAFH3br6TJYdHedYPufiDhnST0G2K94kXMb5+chV/HCqyRDgkcnlcGeFJH9M0kUp8Byex8ZRVTWXHFeSYInShE/mOL6bNg/RP6HwpthVRa3Va9oO0aI4kDQiim3nBx94JcJhnnMazY6iMTntV0Taoh+vnMNJMBFiK1j62MBnuQAzd1iyNeQI4TibOte81RZZGjXcLvMEDsFOXqzzf7UGvSoCxqBqxIeOHUuvu9XqHlqwmrZQD3mEMGGyWlXjOETsRxC195ydN6mR4pK4O+smW7V8JTO3l/NDvqiRv45UuxvbvbyheXWTKtV7bx5ctbXdNRKDt20T4Q0MFaIZxBZQEItQTqhb1blu04oWo3R5dhCtrWfp5Cop2aEfqdzEfNtoav+K3JArrCCuM+PYFbOMprT+RbQ+CRK4XQ1eJOIcYUZm0yCiHK6mUSfKb+xaWWwRYoQ1PdwI+6c3Wt2jt4+j0XDJ0R3O9q16UtW71/dDn4t8b3Fx1nL01kCXPMegnO4G4jGznbfo3XqsBbIv4rJwaaIVOX6nlerRMBKSxRPLyzccast21dVbeSoJFC4+kiOjP9PRNVk2HW9+tmdIvu/JMrNbnAxF6UFRztI/qmxXrpq4DuQXKSwirg6Woy3CQwT1wiPTQou2KDxLoVD7fPb6eNUia+QjEhVw4DktRq44U6eGbcBRILZ0HdGF16C/lB6JXFEL1d7Jjj/nma1qPH/L299O/4fm5KfzwXWDmwTdNZrw3PS4Vq/FSK7xo9h3uFY3o47RajWNtWcOa6u1YF7Xfu9L2LnexR1apX9Yua1QkoNkdTyJ/kQmcLBOOHGfGUExXB+zy5r46TJv6k33EfI7FVFcZ2+4e2lPV1L/X41WFgkcUVwj2UjS+brWVhClQ4ucoNNbu/WqLqHyua2TbzziZpIsRU6aVI1otb59zbmjcGB2I0sNg0kjIAIi0/cqAvbOVpPIISwK4Khu2aKTO3B7Sm39xnXVVQ7fGdSEAYKvYEGTBQv6aR3dGB9ChKByim3OOOmBNN1MHZ8ZOyzBUfoxABqnsIeTmJWTtkl5uUxmWbRbKiNTXY5d5DQY5ibW7uOKr+U3dtJ+rJPauUNrtx3tzZx48vqRJ+d+I9T1dLnTvu7Cha6auLyOdMx/a3srNHE+zbm1uLbQdDgu7q3SRdHgTc4xZ4cH0tpcunHDaHTL4bzf9lcO3zCav/3CmbSW8Yibo3ru8jIP2KGROHNBtRspHBflS7W0H0qF69ihY/r7lWEJ0rQKCKJwjbuZ2G4O1u9NVA7bua1nDnmm2TRc0UjqiWDXqjXbX4skN0qdxNK9jltbqsn1qsXlm+273EGniuWnvyVyVFLnRgdHc1q2urqaDW7r67HNy+Y4ap9orz1pzZpbXHCw41JYDWKkIv0KoSn9k8pG5XzlKczHFBlEEVZNcokiwijOe5Kq46x3ISWOY1EiRC8srAYTRjxTvnd9dcwSEtLNDh9cczyLCoeXece1ON0SDL9hzCwuebCSjZE/E1mCb3CmY/PxPDI6zve8lfFmNVzoJhy1qm1npmtWA0dUOCscNaLZpkOIajrLcXfdMfT2GhG9di09lo/P+qppUKPtLNzdtauOiuA6C+fv27RrOiI/iVhpkhw4sB6GqSuTDlGDPPEbkQFjzwmqYwUjJ7HJQaqGnZrXMn2JhJ10FWlDKZ1duOJ5ZmGEIg7D5a0WV7q2uk37QJgmKFFhbwu/wvWYIrJHe3kYMRdvyo1IUX0DHk6JRmlro+8K6Zn2+JbtdufoEzaO3NLp5t2rv2vezc1aU3ZCbzhatm1NCm2zT4OG3mg0dFl1ZE9vDo+2HK+xecPq8Larut1u/3uffuH/eeo6vRUaqa0cOOC5uhh73txc39IMXMV65a7Ku+gNCHqiSmV9X9jj7Pv5XdMQaPrvpyaxELl1GhSxVEipvKc4EsIib9+nuQeHgbsHfNPDx4PUnRz7gc88YmR41cXPks/Tf8E+VMheqkL3cpgyK+uNprYPZ0E+L6u878xek+uxSczqRtPru7HqLzTsrJ5ov3m6fnw2WW+ZrbpL32XVNdFz8nNzZtbsePmRBnKBeDTj6oieMuOjx9buyq/tJWsuhKmOdViovJv8L3oUkerBbxOreo8YyH7f/kD2T/cHsp942FfI5iOEuER45Ph3iIX8RLmQHoR2CvcANiyAUbKXzU4zXHwN3TqWaT2ZPV4//ZtaUs/sxoKvxm7fa24gPTdjPb9m1vF5Vabv8uoWkdy1pHdtftfasY8aWRpJujszir2e3ziSe51mZs6dyx1P1NhCbl38GPky/QaW8ZoiM1/fjRWhncvSHj5Lx1PMChaqZ9IyVoOh8VmCVOw85DAKj/BE0Vab7ZMnrkobDS4IiDPvhTLPRY0gAAArNiMjCW2O0+O27860A0JgBTS3kwUkDYN6LcCfWj0IqQF8tT20bEOGGT559pomjbpBtJTWB4RU876VH0ZAVm8GXr+Bg2hR09erUag6JMx3GmkUhnG9EURRiKscXfwrbkj/qfLUyvOYAF9iGrhSjpm1ZZaWyyegELfr7ibhCzcqfmoz7Ie91BtO1iqQmMAjdoNNJmN6Ay+o9WrAA3iWBPvEE541Png2FyN7fPKGOW1ptqpK86ORdf51qyuLAu93Rp3ZO5/2zNHBm9Y8UVofKknWdjVHlxCxyEm9ri4daIqiPDx+pkGQCSppLbiPk6nUWF41rHBhTPp6XfZ5K1HchcV5b/O6Oc4Lzt39vI3B9mxIpThxPZnQrcNbbz47c+Hao3CdQLeT80994ZED39UUVaIYchQgvK2qsMZUXdq6Ol881lQyTodH0CTJs/4CMGJ7FLrdmY2qWtjkf6VvoB+ETUN5pst0qwiJ+r3+PpEtnNgSHGt/HwQ6/cJC9aeJNP6ueIXFKL+NIUPFX4YleAyALA9WfBJxIn09ExhVqtZNjRahrAD3KwDwIjwJTrz6RICgD1ERh6dEoXwHoM+qpHKIW4GDfQyQGfsMkBUNRROg+zLehyc/xnF/a9QsBBZ4zaoZ7i8fFzVJVwWFM3leoSztIYIi4IuXeEVaIWQFb8bP5ZOEJUZU4RHCKIKqS5qoKAqt2KIqGaqoCrKAP7KiqwZssb1TUZS/S7ebiqfgq7mdzhc4/z9Tl/4u4oMjBRqzV0TKJyEnakvM1RWBQblKyEH37AUrsQCzgLljMOQiXkQgHvhZaVfGPfIr6UA3SOPYOD3X6N/YdyyOj3rLiT8IWiebluOozQbf/z+NI7qhCYETbaVm5MhYW02bXWgMIhixpD9nd/ocv06e5611BzeeHGmSTIgsVG1c7ka9YTGzp+iCIuvptedP7XyWqqY9tzDQXY0IppkMY7OlaTL5C2xkFHld1/eQcYrdzgLLWwcXv0ZPIafYhGwVkTgLiLj1SQVoanX6i2TqgJhhYkg6PWjEw2NZ6/TpE2nedwlCyrlDg8a1509W7dy2Wmbo2lJ85PC6ZXsIve2l8Xoie36gu3M/k64vtpHpOq04vf4JTxx0r4OiuIZUi8zV4YLMC4arpIE2aLavv/FcFme6bPKWbXKiWajDV+kGTniWoQVkF/JnSfUeSulsFbJdZobrzKpMjE8e+oHop6hwIWIVBHU8HL/meLQUuoogUpbAQHwhYqIuiIb8jqPPODP7bmC6vmvOjw+lhDQ2RwvkR1tXtzbv7c2keLvAyZyKKEREOYMeREJvYidQIaQcz9PNW+/75+zc9ddmYd0S03HWOd78CBHcFoN+Ln6TPAClfhW8gLQGJURMsVbKGDI4prHs7xw0MAKmtyd9ks+ez8W2lIv9dm8Wgorr7pVlKPYdOn6IrDNNR2Y8KlcAfmJ0gI6LXxOuRqvh3q+ZLB6gN+mX6czgSF/QI00PNUdDCqgJpoEKwNJ76IeXZFOUDREBGZM2VbeDqhZr4rkLfuz5NmB/sdBGlsKT4htReUW2bBkwQRAHM6d6PN6vsQNDszVeEUUDB5QXfp+e/S/s7QIn6oYtGIKmSBwP3f4gMwCUl1QNq4t6K68UeTRVJR37BDOkYfsERP38ude9orPREjRPRbass/cVf1Ce1E1TBASqwdywnSXFwn8djz5QeX6RQfvlQk+XIJAOkHUs94M3o1gnth3TjHTPqBZ1JuzB+ugwGQ8ZSDkaDwvp21v43XUn/6aw5WHWypBFU1r4X0T2zJnDPVGLdCwPYFXUJlDiMSTJkBd/gyFDyHZEza7FMIyliE7/sAWXJcNyZMEN/di/7pxQHsWhb9dtXLkG0SwunPtp9n6OF7GfKMbKcHeUbST5osyMKTZaQAlK5xSJp2K5srJsn3td82g+WdrQcaR9K1tAi/9EN+mHK0+E5SjQJe4Sw7GHZO/ajrBMYA8BkmAhzK5DKkGJg2VcWYh5QDdFt9OwBgvz3u3POegIXDA4NNt/4h3nIxtQcrOXi5IfxKOVOdNBHQOLpzR6s16t7UuGL4SBq6i4XFVkEotVvkNL8SbKyqj/kB3aXPNUQ+EId/2LX3ukd+sNR1Hmt2fz5EwbwEEtiPqGxdvtsHrw8OF0Zc6uWih1Rs0egh5UQjW7WD94O7Z+ksTLgoa9FArR+ioW5Pcr389ECzaGm3jqQlSYeRpORWU4GkNYcotc9o6HkaVJiL9WKi77i6MzUV1FLQBLuFuT2X0L6pMbBCrJU7gFtx4ZAp0AbOzb+I/o3kuqAgGjZFdzCxROgMe3bVkXAUZxgImoHJjDp29OX6UaECrZQEVHxjrQN8DuDR74hgqrqYm6yPZD1imr+cAuQgQlYKXnv5f83f43iGYhaex1WbHOv6F5vNPZyHk10FRPhfzDxRFNUgyVHftthC7csLD/NarisxoW/eqLX638CRYd+ephiiWD4S8N33j/apQpSbEl4r6g6BLL2Vs/Obl8VTJtC9YOYYRQqolYqCEnCbJbi7H5u7aOPHP/qbuBqe6enMjgXU10sDCcIpYuolyaif0qr53lmBe/Qs9Bk+5iglOUQHZjN5RExLAEUqaFLIZDbHM9RBeHyHiE8LkNkG80JSHsc3zQqD1zhnWgx1RmBDQOHApdknRpkygip9fm282z114dG6Gsh14jbXiDYWZwpd0Qe/N9gPm27DFTQmGZJFPG152irfbPdkQUlUD1oO9kXAsBlVGhXBbn9l+7PTu8vmjoqpxEet7v6pqe1HnVm93aPuCPnjbiC20kEEMoTygLkAyczGRRicwX+vTP1Ada+CoWmkysdL+95+WXaFRghZPd7E10rNhSpmLD0RIZMniQ6dCwXJTViTyERTk0KtTmMCkj4WlyGPm7y2/RjCsiY/Y8rl4SdFEVNUtkPl9gJAiZ19+HtUKqIPGaZVUNJIVAQSeWkplvLLIlWwpILYaG9WEGmdgNqzaqoYovo+TkKZYkoKiMCqOIAwo86tDvBdUjUWqrMQfHa52y4EkFCY6LBwWDvUdQeeMP/kDhFbANRJlXmf+ESkFSVcS+qKoyesb5Nxw5wyQTFCjftxSh0HMF2y9bEIDBd5uZUx8lHFgGsO2AqJmmSqaGaFpgFygLxu9YrUZNqa/X2ak6BdT3z+Tr9P2Vk2xPSqh2NxzpiYvTKse+AGSih7sRTBF+cdHec+RrMASKEwcoKPLX3uCvLvdlBGGTWAKLZ7hYO+gTSi5FePahJZh02CZN0s4KnogFgkkpFJcTvAD+rH20+fpXdjbaguqrKEIqzG+JAiIJpBcQfcHdGZSmkJOKMtzFf6GvoX8Ark+lO7XGRQXyUIGg41L6JYuKiZ0vMowW/yaR5mFWqBruv8xCYqLt0hVye0abmaCw/KKvJqiHy5plJpppMGGh/TVQZWTbMvh4q1nYIbvWCYBEF+ZH4GW4eSyDn6IA7YKaMHA5WZFAeYqqjhTWGxNjzfNlXHBKTzSIKnPVSrWeGefeZLuW53JW66rzcyhuyLohZhe2yJEn3/ekw07qwqJnhpmY5978ylsuaJ5iy1g0vm8qwGXV2aurnAZCkN3IZ2t6uxkxGykrhoLl3Hj2xvHXHTebhWx8lZ4GtH1juY4T97/E/uMmkoK64q5nK83U/qo8ElDGs2EebZcawrAaF2UOeopItp6lidzeTC84PR9npNrVlicVggLRVnhHyw3mbxSmltAl7a9JYYzjLNPg/oVCHc86PV3lJUubvW3hZbVj6c7LFbvBvJxd77rOudc3j+Vzd85GNrg8PEt04eALVRfsnR872jwG9GDWCQ1bBEwLBVFN7aU733qpWUNmwqpv19Pfq2SMh+AVpQq6622maRVh8DFtSxNEOSssz58eu+/mQ55lcwoyVa16fql5/OihamMmFIGzzx8mvo5ray1sdcOGp7EE23eSE+31VKc/XxVXbljrXbjxunbU8+bGyPOcVjU7f8utM90L5w7vPHXphcPmSuJqveVhnGxurvlZJOuHwiKReoDmON0tVkibsP3Kr1lEwtOaZZFN7SN9gBx4yZ6xHZIYRgVYOO+1y/wqWAdWTP601+H51bWZc0tB6vEezyme1jRMT+QlWtT7IJxBQBtnq2asgXKgOorsIdAwF0jQW45F5A0iQgwwsOIDwy59RX7X8uK1vmOy+jz5qDejIaoH1qBEDh1AEuFCEMQK8iRGLgIehCBABX4p7sRm4ccbmy234xDRbbP9uvhv9Mn0f4KP8aQCWCk1v4xMl/a4pNyEOYbNtMrIFu9dL/xtb0r4Y0jcZD2294o62GB6GztbVVJl2FVd0dS6Mwibx7C7WY/trtvdHNz9mvl8gGK5a9V4ydj5/uymrhlzFghVXIFiAL9QkVVqMAIoj4qI9M+MgtTXmC/3T4KLYWpwTJB5UYntEMCL3a41rr/19pnebTcc0Rv91Zl7X/iitWUzEiTrSX04nJC3QM2zNZ6V7BDTlAhL68w1p5u9WqIN1saFqEyS7QWkqTdX7imcsFnmjP0y2WZ4E0yllAcM9BAvhaV6hdhMlBzZz54DKN/ZmFBeQg6ywooqTHjEgM4Tdk6AySzZ1h0Nu/ochB9B1/fYppp6kMESiQXkxCwjVrkaL9w6n15Vh4HT8s7aBpXoExT4SkBS3NfdVs0l/NZKegL0z3lVgbNkQR1yUESwvvbxIiJ+lwzI3pa0CEEf2KlFRoS4eAOhiaYBCihSTwXonKY2b18c3x5iT99j8zA1OvhRdxhh6qyuUDq46UBR5PwGAIo/AO+NaZUvTouxJW10dXLVYNUOC5swhXqn9qL0M6xQn01KTHQRiAJv3/k9P7DWXLSBpLm2Wo1RVB9ErWPrbbOaB/HK6nK0uKxkreZtY2Q4Kyh+moJnp0ms1q7Lw14NVBynmlkLt8/Nb5PczDu5sXFNW627w6YGjBPhi2UEuabxyUIaNwLGeEIo4Z27/bZmCgqAaIaW2uq2dZWzfNk3ec6M89AOTfBARMc5ULjRB+gdsCe3FFHspZm1yAyDyQhoUZFQs1eD3byIheHO7JTPjQdb++BJwB+75C16HRN66FIZhK65ubObCPOcYIY1RwEhk4Wtcz0IhhyAz8YZvCPrrmwr+eH8wP2bRqwrNn0bEmHsrspiTuxm4+STXnLDWRV6IDAoDYVeUVVgYCQFOquoZYLEYlVYfl3QZU6h/CRl4gVOKS7/Ir0BuNTVxbbvI5cV1dzeFiMFF7ZiEiWQKYdlalrpsF/wm4pQ8wzcFTyQp9mL64ey0ZNnso4vMBqArDTzJs6TnQ/VQ39cq66Bt0Z5EU8pcpYEiazQ1y6/7Pvvz4MFtzZIbQLDnB49fW7gbR464BuNRqobQJtlW21dOH/U3rqrmaI+0Mi0ut6755lPG7iW4RMPlTTm0r9FXwJS0NUTqI0ryyb8lFVXRtSXuPAa2U8QnFwQtu5FAlC1ZjNT1bAxSNPlXiP25cZqIrmCmyJRRz6CoBZ2iOUQgIdf98MSCwIFHgEvh8zJACIneh79sWjJ699550315Ojhoa4b+Whj5B1/4wl/c3NJYWQZnvkVFYwe9uXs3EPe7AiaxNItWFCRbRvcelzs2Jfp15B2fe+ER2+RPdB8orJcv7jk0trRKf17fRdWCxtk7+K5aEqWKn7mpqnFHvGicBMh/QrPeATEzE0dWgrj7cU1O44QYIF7obi2wclerZf4MrICfyBbuBhJEZmQw9wgctMNRWD5NaRSSTRe13XRqNkoodY9J1EVx7HBxVVk3qgj7yd0sowyb6qGbhsqfYsXIJHmt199aPXFq+A8WJHGac5WVVreHBnhxnhO9ZfbqImECAiv+W+Nq3Kn1V9tAQSyEAhReCEZFAfktsLwKQvuaHMIq7IY9xNZkhbjcGVp1tLgQ+3xfSO28CJbewGfQ0imqoVMPYBs9yOVFzOPIl5ey1i6rHTRnxRay0Rtaa9Mt+d7p9WLqf/dl9KtT6obU8dlUfY2egy0YC4yXd1Si0SHgWGv+EHCvCFAQyZohtXQRQqaOgTSiM0nvlpnpQd4ZAYIcCoP/2Bjp3wbZohUB1WoH76iuZgimwJFyLNRkwY9G6ImiACJOP01Txwr7hP8DNx3WAxACUWUCl7K+96H7JFnaZ/A5AJYk16rJzrcspP7P/QhB/UMGByGGwC1QiEFIb5ueNgNvnWozcJdVWgfaiG11jw0sGATAJogTwerFnUP50M/dBYVXFIEO8eAkzy51OTSNlucI5YIVLCLiExWdzhylugEU++VaGY0VfWHXuqyRkKPMpwRLhPBhfF9EZ0Su0AkqiOHFVnhiIYvR7EG1DXmiBHzaqarIeFwJBh2Lp6NKBZDotEsFtOQjdB2PICWvEzfJKiiqZlIwAXnPenO1/CwMNX4A1gIEoaIXCzif+K0f8NVdA0bieDJUJDS4qCSraiOxjcPtlkqr9H2VpNXPNVFXk5VbF9hxhHEb9LfQrNBZWIODnDhaonBN8jynjCx9ctbYFz12hO31QfwsD7sXUaRPkz3Om2m/q2AhwHHr68x3hoj401o8NQ2M/PwS7ctGzW0lUGyljBxBIhporjJyywYUYSdH0fCC0HkmVHTi8QXa8CEF3qOiJcOnxjORU7dzg9tXdU3u8wHKqoV+OByCen9twCIj9YCoAQ6MXy6Esz4t//KHYU/wSEUvyppDKfaRZmxxirru8HrSMI5xiGBrHJQjNM/lB5uJ32WDhKERhrqTkgr5QmWSHXURrSsmWFVX3vxt9B7IyDUrjD/t0f4ZfUzTjy4/8mcpRJl3Y3c7nQKhi4LHhaAc+O4M3MT1m6jEZMT8UzNcpvzVcbgnNJ6VTc2dswTe0+I8exmk6aNtY5/KdFVYJQWhJ5rE6vCFSQrYdebke/+TjJdGVj5W+Sp5TJ4jO7lMCxBmiW7hFfGietzCAznyP5n1/6+Ot9EejATnyBxoyFjnczcmZthSJljLRDTD4vnOg4n+J21xgOfb27OxtgrWQhVH7DHCfIVI3bVvSdwMjH5O/JWerFIVosCGgh1zLk9iOFfNsjks7uWd0IlJT/Cw3eFsuaosoFiEZI3b8a3QJGv6VakVodVV+uYoF47qgrCv+tYQJeYU9dFB1JKYPQA6MpaTa3ORW6MkE6Qa2bvxl6tpWroeckAL/uhAMNGRZzvgYtvJl+qSGhprHT3kcbzAvmbEkzevI/S/UVwuKOCws3vI32zJALrXtDBi6Sdp1Xy/kp7wl7L9rUUsVB8wj5kzjyaEHDCbUbAp+J/yY5etZUkdZF3Aw8NbolVCx0pGveaB1pz6ylS041t08avVpeTbCGitt6fnyNvs1DorCbbvWR+fj6O5sCLRy0ta8H4K9r66QuD8fG7zd7srG2iy62zfjjxXGLhRAcXHyC/BgPeZ6Vaj20MBZAmMv4nqwQULKSSmzXus3DTG0+K1MgpAgnrNUsHPdfBVVdBS10/vwK1bW/fMt4+UmP6+pvrgaZTVFnrWTsEi8yjL+7Mq4Jfa1ivAVxokObm+aWN64ZV2r5w/bk3XquG9f6Ow9Ws2dm+oWtY1hffiKVldSHQc3+GfBhkuwmqUDCVphSxgrHNzpeI0h7GMM2xQ/IWmchKy1dMy7Os3AwTWcO6uU4b4A+IjMhV9Xk/PpjoiT5/sMHrgEU22vk52ILvN5umi4BHZaVLkA0W1oYuOtHggAWHerVMs2qIk8FS4O2DZy4M+uM8QBLhGQUS8A3yy/R9QG4WGb0pK2r6aDJl4tUuApBobcTCdy5k5w9oc7GoaJE7PdSpYfyc9vrg3pfytL5+/XBddN8SrGs+IrB8s27ZVKXvFSQ/c1c3gp0/Hp9aCJWnPWf5us0G+VW7UfMf+P/TAiWm7xG5UO8OZnA+OZbw42gMWK0chbAXnJeSv72vg6qUU1oE5WIbzxcExTHzL4Vz4g5i98nL9Wpg6m6optfMjO8Glqdqo+7Cc9faY9BB2TK59X4tnp1fSjkn67ntbdULUL5PfaqCWfFBIr+ao7KHUNA1eAP+qb8wf+/ygdNhQiNrraMkaV1z/aImjDbD1FMJtT4Ssi44KWLCZHplyZXcR99YOVsKBM6uLaHwxSrZ/m4OWFzYIVSzRot7TS+r47UijN5tnywovxB5mOaT4D2KdbsFk8cAdzWsWqD5lsFGtKIhHRIFI7BphJQApPn0TGaiFVL3Fc930IxCSdQn7xBqVkPiyV/HVUUVkDowgBitwmqBInIHhs8dogol4hM8a7VrH9+cQ0ihC5nrZvityGgA50pVyvpyuxdr5MPkZ7FnZ1lBlF3bHpuLUc7JhDxB1ncbcqG5Zal0lfXC9UpEYJdpQciHWXVN18zlXnOjGSzPNkGyr/ccfXG4YqJrbe1Zt4x4rjuX3zqIl2aassG9X/UQ/sNVo63K7HRaGsMUdXP5t5pnmlmWHEraK2Aoo2UgycMa2H5VN+SdwNqoBdr6Ew+u3Q7iu16vzd7wfYBP/WpmG8005FBz0BSjNztj+26xnTvkF+kfM/4ySgBF2ZeOi0s0qUUmFOYpZriHjxW0O+Ah2D1WvizaOsgvsNhFr7KSC9s3LUlauc2atEEAzNICxEOkjDBPFy1TRI2EydnsEzrdvsv9nj/n1hZAf+F6K6tmuLnWgWWv9UDYd/vNsJ/Sw6xmoLGtZMEMaiUQZMHzPUFoHm07JnG95QNHy/6Tyi8i5GuC5giSZ1jf7R4FFRCp+27WzvWZqyk2Epv09vLcg0ZhPynQ+CStiSyi7zUG6Iyud5jHC8n31K++5nTDyjOP0NWFaGv7YGzOwGjKCtCosJb+tpymQdOhht7Mqjid9sUfIN9N34vG/W0ozP7fGNW5oCgF7pqBUqLQK7XFTU+ULeuZbFbgrFp5Ah4RrGa9ebYTDkwXaUnu2FmWgWwJHZBkY4A+J8Bpx5QGzsLGWTSy5Lf1o9ee8rLjRze9AMQk3/ZGEcoosg3ioNIeDOywUUsDfXm0CPqfJgVxtZCLb5FXwkHdB85tEUPttehPAgf0CPplqgHsY68EO803tsilElO2TjNxKSk7eG2STxftQMI/hoHCq2HoRuhojqp6NGsoLNmVbJlV3ia1RJAX6rAMXFHlRj7GF/wGQwQDuwxVZRtN6poxG1WXbDNywxDMleCvokClahC5SzXw3nTFWdCLQyDd6zORArNCKWvqMJQaWECMbcFsBogLeiF1YkG9kBXTc9UBcrWtPD+MOoMpc/hlC2At1GtLfgSKphKU6BFk8P2VMRYPiyMBar4EHZtq0/jypZFYWZsVlf4/ROqANgQjriHeYplkURbhZB1GDeAy1Kesbl+HMw9gHZmtA30EvU4oWS4zuIRVDhW8B7bDd9QZFZlS3j7c+BOE+mpBFdtBFebzYHUWil/fhchhuHrrRYO0yZo/QU8ASr1XASoikgmqydo7WALVnhTYiuaNiDWwsMuLph0e9GpspKrqWeKxoo2oK2FgcxPWC4jBNXRjlCV4NNoOTNB8iCY08kxgzkCWMtvF9hGtkZ6Z9xvx6kIXSfffNDebOgY+IAZGPrG4GM32vBV0OaMhzKjpeBHcXbzIoSEm6ofRSoRmWw/hvSSFSWpc9eTUsm1HG6yuBa9D0yLqMF6tZVVbgjn0DYW47bh5riSBkN8jf4OGdRCOe6U+RmUZkAWV8Bi71aBy1VjKUSeomdSnrgIrNiCK3HVdTFAgatZM5d416DmFiWTDKgwrANhTwN+UrMw2l2Hb5F6iGRIjTJJ7oiEY9wJnB6BUhqbYytz+7Fx45LDRbiFNAkhqoh001b1Ff2mF5+faRhgmdut0FENEoMlaa7PFQhDwAlXyuUoMot1eXBzuBm0PFRD/bOvUyWP1qC07cWoOouzq1tYd645lHzpl2bymq8N6c7lKHX1uaZF80DblrBZd1Vh/7nKYa2gZ5cYXnrWxdc1/MGcXFlzLR6xx4HgdqL9V1CFstG5+EQaa2UQ0d5UnwuoO+3CikgHhDKeVRS4qyNPtHCIXoPR2JF3OPbKyPnvbMnAZhrnEic3inFKyBGUjj9eWeiYf9FZizoAVidbmG+R39YUDx9prt8eOw/068AUgP/iuSwRNearB7MACYAYdzhT6rul/Vu9XUW0CynCMyG5WhJcm+RDOfsSkYn1fMwzS/wYzb84ELb+ckwL9YPTonldWA6Ass+T1m6g09Jtm6uj9pWGcjxkySOCvZcWuhQhfSJHIE07y1/3u8+PlXgBwd2EtxsmZx6tPGi/e2jQDSUCLLPGqMWrKD3wc16CCwYE+eEMBOwVmA67TqJk/AXuCPKnNaVEfVUV0kyw/ZbGwBF8hHyBfL6ayTFBtpsNBcUWMbTlhz7IrCqa1cnipAYJxuQ3iFphmjWZCAZzZ7URRzLavZVp76IU2sfKWWy9s9VP0RquBFjNiRqlt+zrsrSwG9ZZbJQI1KdrjnfB1tQNLKSUt25pdXPInXui/ky+w3uJuCdZuc5O+QEb/7JkkLAsrRWViEmvCja7iGkjkLa0segPUThbXDyROrwV/LliRYSVJzYoyDb0siwtzTsuKD86kx646CF12mr49Pz+wQvpLmDJgmY07FuOGg2qE5tZ8IwZ6AGa3Stwk01Rdt83aqauxY2YW2YMGSL+BrpjdApT4GvkUfT2L90ugPUd6V5rYgoswZmSKsp1xst49Rm3Z6x7wg4JQTz4uG46S5W2dWUcwchpraCdkMmHp3W4TVl4BUnE0ZeKua1ajhrIsT1Rrpt8k7/EWAX/yNDu8tR5a/U6NB9vNyLu5MfusMbRDMbJawNhgCDJxsBZERY9MvdXpWJS3iov4SmH7VhkBYEpZQlxYVj7GRcMiYwCyaRrDyfQHUGU+QHknb9aPHNmK4wzBK8+Im9laybIKVlYiC2xaodkBLx/W/R9ax7ZXLThlx7KWN7aSE8eMVrMm2fX5aCNqn99umNLGenxgc8VwXWK79srmwUIs/o38DflzljuTcNoKC20TC4PLTXsM9rgbk4k3X+B5qHiy2BAtN9DhKVU9cMGeCaK6JyAkAOs5yxQFvA0RcL5qW+jUqrpKPauSd+tZI9VGT9vSW41EFNGNJiaNlh7NLB2a15OsYVsuJlKgZNfS0+Np1Mg69WTVUyXRK5byy/TF5M8qF/af72T/+5OmOm4vr+CmcCxXOlBuyj+hIX2OIqAq7CTo5bQCy6k6Om8gOXVNXseDOK+6wNcCzATxGl2w3lQENxbGM2gIUxy0iCWYzqLKCJEkGbwigLXo0E1q5HeN9cOH/MXrls16aMadGWv+dJoen7PmegiHu8ONoHb0xInUaxoYF5DlHac3F0VzPb1Rr4qW1Vny/DRGo2IYp77RzpuaZnFqUTv9KvkM+Qxrjulm3MQfDtuj3VrapBYwwQzoXtF9t5Fm2gBMyP1aPwfkMx8784Mm8FNTVqtpw/K7guhmKHViXkszVWMfFs8HRSZZDGEMBUv2B1UjxbAbYMORGrUtxfsdEy7LSWRdnpnvM/I9FABCJ8qBGyzOzVhmoFrdTKtlTcfyJFHxNqrgdMm2Fg/Bm5Ncw25mNa0646pRIYtN8i3s7W1F3YllUHuVp301qNIVTCtH65PiU5FB7tac9tWWJqAAw1D+GYYcYyhQ1jAT205NhLzLRmQiNpJqVs3XJb7kR3D0NOORpVkTTROIBeUE9BoHGfKMP5QNCYUnRNOKxFhhhqiaFvlt044cAUrFC40DreahFEX6p6O7Ef5DjwgFT0thhGtGZvuvjJJ74sTRTI2iWLcMoqvufDRz6+yz7cx0OhbgdpyHwCJSMNeKVfkafMrnKgew9SweDEuiAWtrns7rOUymWGnpPQ8QFgxPeohBajpgdfNUtDTHXfYHTxiYEDYFtTKzb770HtRU0GwnI1QSPQQ5aIJfMN1OM0JIb/nqf34xzKGaDDREciywEgA/9Z3qsvNWEEpkJYojRhwo0rwgstJaTf99nPLJCap93UOg2gjKC0EswETE8w+GuAF2LNIl0mNJDTfqPzTezSAMMObhJXxDeCjwmyCtbVm8mgP8IOShoPBTURLXY8e3HcMPw1Z2x+XI+E126If2HID8JVDEXOPuCVD+Hy/+fWWH/hsbaxZNCqLtURFg7bXEsPkGCPj/SXL9APmhSHQ4adeyemj0oUWRGtlEQRrGS6lNX67HrgaaOeobc+YOejobIX7TESzkW8uFLHBxoGVFoQ7awBUL+SCQHMzOokGaQbPFQl4GmP81A8wJW5xc5a0WW5yHgs/RoouGDWQUdoDlfUgs/W74Ec9aivrJXLFON10Ord+RtcLQNxzbd7DOSXTqQUj7ApmlZyjPEObpuJy8PQXT85IL1lu/lIS6ttu+grIddDPQW/OzDatugL5QrTVbimmCBRLJ8iCYW+klZlXXqka16zPGrWGnMfkZ1IyczOyiLoyql+ygt8IAPJdHyYzdQL+xjCwR9FNovaH5aAfCeb6SapV/pDuVGrYBQlu2npfBB0NnPywBX0Naiu6MsFZXJBZ3MqKOYtBvCF4YK2rey1UMCINX6872NbUWe7A5OPDN1Km8l6PFgRcZY31cdl4ylfCntv0pYjEqgZUP4zSRQNgEdw9zxRSTVkU/gvbmfRweA5NUHF3Fxdto1UF4bV/831wfU8KurfwAjh9Oq8W7VEz2fUrEQ7hduvwpK6/s09od67ZNV6MCX5H2PjWNDHbHho2n5AB8/5zroThbXW6LnmtykBDfRKmt2m93Qr+mqnbjak8nQl/qzFbXh4u2bdgH7txQUdCkgCIBBchpu2PpwJEcezA78wIpiBbOLYiNvA3OF6se2/bbNAeojTe7sFrXYnQVG+mhJjDB7HxPN8ErN/sJ+QoAUF2deepYlVBmry7Mz4U22HAij4gpzjpOc8PVffe9aOJUGu0GMh61e9gHVOApo3s2YBn0tN0L7CyymFtY1PEfOtCaeQdW0HH0zg2bzwNyjnadZrtprN41l9SNdCXVLcYqgPVG5/Itq8UIlL/kQuzDk6addHuDW8SMmzCbuN0KEt8r92k3kKFZ2QbKTYfrAQeoovSNkWly4NucXDOilbkGz2O+nS5YGrQOkB6Q5LBfZ6RYSekvrfRDng805vu8JNVlz0PHXW1hc31OsT3WFui4SPfRYi7KviKp5KuUDS+SCQp2st9QvXYDGrZy4NCwCyhBN9mAQ6gRehwlTeeFqBoKVjXbSv3FIGinNVuF2dO9UCtCVSeq6/6gn1u6EOZOMkq8BKtyoiKDZfKxorIwiV7G5aSHSVA3WZYeM6q4bvJT6AYPJHc7nz0yH7pZz2+enYN6RYoEQF1YvuWaTVcn7RMbMxv9RIGGdLptNW0T0to43e8fP7LdWLswD16lTRTT4LsXnvxdW4N7btuKugsBdMW8+GnuFIdKZOXV8LMl6lamauwLXY9FHbDIo3cJFgf34o0iVy0B0nJOU2/EXlzdx+vDIdoBgMqwyPzwrmUGdTiTNHEPCAbogaORnHUZMDxOMqQlcFFQ8YeUI2NSQIDwpGAx/AUD+2gxaK2odCu24TgGhkWQd6BCCGDYrwqszcdetBlnnAdV0qdxaqGcJks1LbRMoexueS0opmTbbjqCW2BjdNLvIqmZ7XlQFzYQhZEG0f5Rd8B53/kNkqL5Ug19m7nUZp88tyR8oaTSAUWe1RoEjG9pGcNV02hkNQUzBJPewKY3ECeqAjhCOujwMqYkymowy2Bm6eLfcxcwy2Wh8vTKG1mgAzS8TsMS+yknf/S3pq2lIgbzMPyC7YJ3YHdyWSjtjXih42IwIZqkZ6lYjnqhu45jTRjWaVAOB2WYHD6UT2BX5n64Fac33nM59Idn+7i6NBJQ3rbksv0j6TUtsvOTxMCEHgzTrGPwCKLmmlIw4tAmjfoPylwFO041XTaEUlbnmld3TYNVUxy4JExBpDfzYRwCRaZoMVtOI8wHRSuwhxZDtKHhgZqhjM54NV/tRJuc42LkZKgFCQ5g+5HG+4HHAgleMdU+eImEXAQ1Tjf69tzNcyYjs5lgYppW3us51THcIGsSEKgbJ6Abs2YceoYkcLLFzlmalqog0p3H9DP0Mkqi6xhkm+/oyGt9BLNqiE0SL36Buw6F8T4acn6ETcNCo01vMnkMFs2fzqBZay2zOJXtHHk820Mu3YySLTvJaKRL9i3/zGAV0oa9SQD/ySWwzdUwHAl1MOwNFdje7Py/j2dzbsQOYDCiYxlsOzhRbTipXPY98WE15GF4Kdu2Wh69LozKbQmwLWmrzoAiTANVe4EpctZj3JWdT9+BTTDAaxLBeCNnhBybgCpKsQvaU+nedonYE/3iJ7lzUJyjlZdgnhlja5cL35qyEibD4Q7Q8ABZG02e7pXtiEgUQOFhuuaXrJ3gEnUqINnpfjFziAB9lnuI7fLLsG10id5culMS/SWrKmhdvartLPlz0OwCpFbMUYdIyfrdP/nsHV/FrFQMh0HrlQ3mpqXYh5/7zpeujQEOJfpO9+fLTVQVxmLf3UVW0GCbqCiTTTTMchMTnW3iNVnD0cAI36dM5BKlW4QKd5glJPXI7YFvoDkCmQPIjsqJrIglOT4/ZybwhUv0A+VeWvNn54xG85K9nMdeAoQud1KXip38x+uTvqTnMpnb0ySlrV5/icpV+IsPXPw8dwab2AUL7XWVX2OqVeKco0npZ621N9+kjNfybq995W1fOaJibXW9hYB0tTgC69WUWkX6CQEB3nwTaz2Gq+JMq14nn/RmXJ8154BvxUoskfbAvxrZP15J6/jAn0PdFIbHbpoGfKTKur2kqrrzpXA2BOcXJ+NSuYHRHg5SchsDR1gVuOs7C4sLmHDBM+/ImVfSdj7wC4IyqbqBmapgwqlc+ljW/Ib8h4f/+0Lh/0aV51R+qvKhYrwoQNh26fqK8v+k0gVTA1ZcazQBDv2iDbKYB0KuvDi0e4ycXUx3CqMDZLw6ZuZju6hkQSxmKRrv6VOUwzc/5eZt2Z93YMbYFktIs3IeIRn5CWK45qzGJjMh/5VrWbbzt1dSNnbaCnACIgRG/WjGtZbHyy3Q4XUE7ZKn0pXTN55aiQsWpqFgjDM5m65QsyoyC2P4CZxI5obgD6pKVV+8fdH0UKsBgH1FReV32UxD8DgnNT2koWhKZ56twsFOfLqwE+sYH/PfS2Nf1p7EPZ6wdBlXe/+cZ/Zu7soHTHd0T+V6k+MMzWm63eNtpwnAD301qlZVkkOpVscsW0TscGy9W/sIbUUbM7tNX/vVKykJ70mGdTVwzEwxEXnORloViQ2OLMu+HC6wvk9MOmw64Imnh+uGZwoGA2p8mfzrlY2qsKl/VmzqSfTH/wqrcnN7YwnLjC+MdmdZldwmf0J16ImTiWy93UdX3id8VotqmRNIeii5bV/2wsSyYs+ROi2n4dpzjeJBPBeJrC2o7bRXI8szMJav+Jgt1mYDyzUV/6lXcrPRReyCXl5vZlp6sK4lGCzEhnWqG+uY5RStFJM71fx0R0HlWnUkzT+SedTTY8dKgeqLir+ZsMd1+sEruvnM83+m2HwPIM33Vn4U2z8s093plM4rb9QZq7YY14P4vUCOz4xu/+4TJ7779tH0f4BZV3CvXtjZPJnnJ9bb7fUTeX5ys/PihS1UjFpba6tbmM/T2qK/cEUN7gcc8PQ41XcAd/NysC+mvhnB2K8XyShbdCSdk2mbo2EJSh5E9Mzg6/USap+MjGXEBRBQxgWFPcTQx3CXpcei8qJVElH3lYy0gy7GodWb+s6NQT8OA75o8OW12gIGbfMfGj5jpHc6DQnCXx/Wd94I6g0AN0fCxETM4ySxVlc1Hh0SWjIKdl4BTg8VWNOF/NQrEoDP+wmsAnN1uQtav9f1nLaZFf3sqLPltKyEyHHhlEEjmEHbDOtqbhYYxe9dkYAcEvDpQgJWK8+u/HjlZ5larufidNYqNp2B7IVplnbrLFJGpkq7b28zNpfuO7m7UFeEhbNFl1xGi+jrRUuoNrDbSbg+8J7PotMGQHeA+ZP0LVYnTzAJMGpYnr90w7O3t599w/JfT/ex7GL4Tm3km5qrRxrNQ8tZtnyo2Tiy2rx2sYZyv+04DUzuiQMHBsBCxUtHi6SHTnGBGHncnY9lOZ6nfzDZx7Db6QaX72T78e7kzn0G4CuwCXR2JTpgPv7iP3AW2hKHuIVJ0WUl5kXFKd8bsF7WcdjqMx55SW8uHwUEUw+2SLGFJO9Nhl6WdZdw7SGwwGImKGfiLgqO4QQadxUwNYyR8mRHpKrnRCbaSq+SgiAEUZx/4GuETUmeP47x7ohFO+GPgDhXQnxqwd7l+jmqVsLttQ1Ljdtd81++Ga2ghUB2liN6nZlWfV6wtc7cUvijnzTbaYi7i+jdmVl7R7SSzup1/+F6DKV3QXXrpGmjoODxBaIXO7WN+s77SH0G49TmMeCxMICfRosKDzD0e1lIQiZNYoXzmArndHrMslgnDLVcn8hsYe2cEuFkHeMFmy3n/t2h6kMo0bS0NdUhem0B2aDKYpqqzkh/DLQJUaMvSpeJWYx6Mu1GorLEXkRnju4jzMNqLEiPM2b9hBJfYhSr9do+XbrJtnTH3VMk8rIC2hFEYDuOTsjhS8Edv5awmdY3Y3iMZfk8H+ptfucdBIfAZcm6Uq0lyqmd//N4I9nPTo3lzQ8yluNCxWBWd3WswMQ/BR4HVzkNP1gpZlP12JiZXv+SW0nAGsIhMqSiBOqgDMwwFkowHdhTKtkWBlz0he8Etk5fIrTZCFwsm8Hmv4CzixZWlNg95SBrbAA3xaFBgqYOjvXfcAXzNKqxOTBYz8cNrJ9ig9cwGwW8Ub2Jljqejf45pftavBTjtjMowVnVpp1s1HZOt0+C4cHGq9Faf9buuAtLC95b/t1AO3TTuPgp+iVwQmYxeeDHWMdPhpJ6uIeSl4RSNgO81V+eoORr3mq4T5PCXY0DsDDxRvnEGRU7ioAGeGHBYB1OCHm7G16OKnDyfRqO4Xr0tVnuiw8DxRY4uUUKLPaDSn1PX3A/HzifGlqYC3VR1KQWK62DnSKQZK2L6PbsDQ+N+kRNFwElYMZ8Ab0WdGVJTp0mQ+hYic/E9Gg0BPLk79HJEOvPD8M9nDxinyh2ErMmeiHAPtw0CJqg9+3575rf0wR/LXlmnsESYxeYGmioheFjO/9IOVB1wMRh876gnCEjK4MaLPh6zu/8j0I9ZXSh4oV7sEERoBx73wbtYuEthpczgtdoFzJHOahEzLkrvkGf2YXDH/jXARpgaCcSALaCh1fs0iqZv8I7c/sUEa9G/0l0A1csdggd3gwyrzHInL59d1+efOm+3PlQ+/LFR9yXV+3fl5/EvpgX/5J+A/typvIKBrEyf4X69f74HEvMNqk9bclaC1mIvz6dyFTekAyTJdvAP6cshXGfXOmtO4tJDaCW+Rz5w6DnO+iWwC1cBoZDdt4u+r5TNA6DGiDAa/y2Z7++OuNoJkay2N1QqLZmvMX1nY/hXgmmYJcUHvkK7/ObgmXcdQ37iRZI14nZRAa0PLu+Q2kxpgoTWlW96vsimQyjEbpmuBrSl+5u/k2Xbv7Nj33zH6SUIVyZzmmVY7jj1i89qEzCyEbTMK41YincblNnWShhmR6TlH9nocSfDtJh0tGehjyr7L4jaxPqZ4nqFmE/yL7/246Lmom6s+XPh7UAK4iSSSdsoF+cvGPnPPqcY1RNFEtg/TVl2UR22AzgX18b48YVibGz+orHk7bdBfRENT3LMG0n19Iu7ukEEqCsJwYaCxjBOMXoWQjTKix7lw1TIM3oaq2hoel/UORusubre/WTs0X9ZEB/59tFIJcG+f9tUgiT2+a9kLcaqhA43DW4+ZcnglyDuAk3oOhp42y0NkTWZqKMUoGGH6h8F+qTv1qSz66oapJHVadZfxRVFHLhCqvlDn0UdZoL37aSQv/uManptx6Dmu6I365K89JvV0axLn6Bfn1XAj78OCVAeEwS8ChKIpcVc1gc/CjKOTddaYl42yW1kaX1pX21EbJ66sLJFXLXI9RyfpyYl9Vy6Ocei3D81SWycfQy2fifl8rG9zxcWeRH9pVvrrNS3KBot4DTAerbcavTAs5dkwJOEQv8FedBTg5V7q289RIpKfCaS+Sk950xFY8rA96zCuVl7woBm532nZGCxuNMfPcMQYjblYSX7rZtWo/VFrxl/37/wM6nHmeSi80NAN+iM7dyPW6L+r7HCd9m5HLgFlqBhyxUf3zg3h7+/mh8Pw6NYdyPA8ddvWftMgT3y41+DU15zsaBkXn8cUF/dxWwyqOIBrDLl8O5Sw8N5zboPiyXkJy1jL73sWKAv7MXHtz6iOHB0txigf39DVcDqvUkNtiq+yihvBIB3JvZtVoAgU7J6ZsadDTw7uF9QjEAfT+zrzAu8PEseiT8I6J8T2G9tJhXiidbDs+6VIU4ZBOENZE8ZRcCRLuX4ceWx8aCSVqMdi9RKe428cxvD/Wd/kOjZgDpgIRQkuE2sQ7dmX9GFRxXNHaItawuf528cA8NvM5QQMjxcB9qei3m4cUYAVBMDhHO/sTJLyfL8LnNi5/Dshq4wd9dlR9mUVd3ku0yyOdh6WHkkbSo+P9B8N6EFjbBIVdGu/cLZF+jPcgc3PtoMihvHxpZfqzQ/y1+zIWTVNjPfPXhGGTPRMq8w00BvqnKTBG+0gSrV10G8VFwZjHDCYatJI6FTh+DbJklxo5iIzQ0OGFwG4f7yAKsD52aWtDFNVVCm4CDyVe4bcUKS5N1L9J+iBHLoDoWiGVCvTElltF3T1UF89IvVxW90+vol6N5O7/ISGUw42LBKnsHQfdRClPMZvU9twAhea/EIMExVB02rBnoY0vYeUlhljEnBvakfqxBBodObs8WFZI/4xLs+mkkVD9X+ejjqlujLNnuPVzt+lHgvY9BINa+nUA83qq2M5dwyLf26trtRwSEr/k20qI7M1NpqZmPUloed7E7mYHN2Ffsfv9jwYd3/uISiXrBrkRBMS6VqEsF6p2XCVR77eBaXoDNfw7p5jEk5A0IyIoKzEHW0OxM2unLzWIDfEYTrHh3LAKHPsqlst/+kufIdwRqflnR4elR3AgbndEYZgGDy1rKb4uqQjGSETPx5HqWyuQWLwOEWzyBfs6GsfO2xw0101dhHGVNMUgNtOkHfpE4cSyjb87EHM/ZlSUTTUS4D4aKezGjpaxIgazNFpAVDM1mz9rCZPJMa7RjfSdAZ1QC6BcnmOZPXVHQ2dt7iu3MqCg4DNm0uEmExBr5UO5c9qdSUcwRpa94lPjzHz+upOqTZk3litVzdb7lLFxj1tFNFNk3YwKDjIleLrs1C3pAJV9mYTWG3tOvF0D0y/YD0bW0eikQTS4+pmT6daqDu6mbPKOo0uMEWlWPbcJ19FBBIM+h6UPvGDtfSJoNoEEaBv+5nitg9zwg0gonouPiRayctwd+tXfHC03wL4Zy7ce/eg8Lfz2MkSZ77WbTm8/my8iK94W/7DYnu3N+RouTluLSQE/i3zobiMsi4I8B/9J7uF/sPs4wVcyl0GcA2K/tHJ0CYOzG5FP8y4VykQ9O8a/eLw+alyNfuDP8/TbCGAyfI7j7KO5XCwxh+RnsJtjo6XXs0hY7/YbHcV5oYGrGoO2zH/WOI6CkCBEqN/IQYw9bxZ0L6pHTMBUtUy2ZtEoILAj3ELDjEDqZdOm7xcH8g3ks0UojkNgglnYcBCwrA2cdaZCmgFuDRiNii2bVL6LbkwRjN4PiRznVPISCKrKzCDfBeSkMf1SgYF+ArmogCd5feVflUw+ikj5K9OHhlfeREuLpfYWn6lt0Zhft+Ljdz2jcmwQED6XEpP/o6KV3PyZIYucLD63wJXfpERJoJGGBK+wqfdXMW8UzTO1JEHmUmVA5fJDuM2DlRx8BWKErpy6cWo4fM2pBv7FrK665zFY40UNk2+9kg5r3zMU2e2ikVYcN/sedA+SpxYCKfHXXYmAC5s6XHp6AitrWn3Hr8AMnUUP5o38/V/Hxwi6XSRnKao9BzrjRA98ZBuNND4PNfFvR0i4VrUjHIuzJFtoOH062mF/5jlEb37WL38ARXIrfnHhIiXrHpRKlqY39MhXHwX6Z+ovLvBCP2Sh/Tr9Jv1W5Ex127yINBHlrB/bfLoEFFGk5KGlKGuhN5sIOR4U/KaSCIeeY/TInsa7r/nSOUmHBMDh2rRirvcbtTtjfu53K7i1x9h+5O5y4wLwMX9qTd8AKFZ8DGHCgvJXx+tgrevOilDjB3qDbabsyjjNioE8+vd/Q5JzYbOvxOizhHNl9BfK6XfrHdXbXiIPs572b0jGe/fNcnt1xRsbILAz8ZeOPWYjGsxtsoatYloHu8AX/kmMTwTERSsTsDdkOTjq44xgbVcJe0TCzQjYVeEY4xSXcZmhu5kB2sNnaTuur/nw1NrRo0V+tp9ut5sEsXfEX4gi3PZNljJ+o4Xbftt0w7DomKqPr23AivW4b7DnbqaFV3X5NMcAYZ8XIFWjVcXFjSr4Yqt2UWRuPiPZSdpsQUYwo7vkkgR/RLp4t7kJRPK8GuDx2l0w2IVqTLRf3Q/wCxbBeOHVgV75x+8JcY3I0wQDUAfgHE0Vw42M0aGuYnLqBviADqUQxyptBJuBl4NZDmiWV5NQH3hD2zNSzcJNzljbLVitdRZN33cG95Hg2G1iT7TTrYUAUu28CXxRDEL7jXhO4hQqGX/DlFWIw+Kt4kIggydrOBxU25vv/MvcdAJKlVbl17617q27dnCvHrqrO3dNxpidsmtkMu+wubGKXnJacER76SAICqyy6gICAZBFJoghPeYJpESWLkiQrrCAiQXx2zfvOf++tulWdqntmVlVkpqe6uvqe85//hO98n4zOCzTCZWLEhjQfBA+BC4FmOOwDpAl+HSTlc/Sb4XUoGtImzAlGCQllQwCdrjRR9wFCR/L2/YZljuFNP/c/Cm96RoGW6x6ogzkGEvWmA4w0uU8cNOoiqp0lkOp4U8/X7CfOfsMtFPp3N6vUviGA1wq9uP/NNpmTbU52mZJEOWtyDuQJPIbhOpZk42dNTjcz3OVsdhNtTi7sZ4ayJ0PtziovNrvhe0bdTr9ZbzitVr4zH7wAxzQfhN1OIt6Srow6nrLcoCEfF3Y8DdbxvJVYiann6edAzID+Zo50BjUDTBkCa3y6vsz3np0hLbArbzNKnZVrnhz2PicqfoGYSeWw72kum9zD+n1PIWp7dq9oJPueT8MH8uvtsO/Jz17xmkv+s7joQcwJh5M1QO8XNUDLk9Of5V7EPR9dCzfVEvL8t3B0XwaKhbCtH3eg2MVBi5f0sJf6IlikdMWgvGEPOZQrXyOqQDCyQREEonVN6j3Q+aVjHcpyh/QoDfxLn9UZLOlIkP3l7krM6+AFjDP9TmsGFDLpbAVTEqfgooiAAo44uXpstQvGS9Nu2RAtU9RMWCNLOaVuuQ5JYoNhSofOkoeTdptbcd0acfVy/ylIglVh7Cp53+I2P4V/9hYt0D2hJhO9ieZEQLeNok008/zhh6/YTf562QYrMR4Z5RBxIkkKyUEJtNdF3Vlypq6aMmtoZIgAqbTN6clg3bdqRMjFKAN6F1Ohp+qeUsgwmi5ghnGFSMRz+gX8QjaIS5SC/U266OD17ukf8P/G/5DN8+4gLg0hvPyREJBQCjNBNc4FBsP5MLyyVJN2yuHMYpJAW0wQaK9hVRZzmrUoqfWQiHLO0hC0K9nr9qNW91Oteh5aRbVgGQRCWTCOiNNHLtiYEnGP5sGZT65FHPU515wnsn26gTJBsSj3vihBWpC3Eqzdm3f3abvzrcZEYaVaIrYyDvxgG1UOTEI87qcit/m5ThOPuuyJlqjpWXZNN1rVBY5/OCebRaduaulIrTSTqblseOfWsxKvK20jY4MhUc4we/3jDtzgHHdjFUtxiA5Id2Wu95UBrushiT3obInAl8w234Zt/hXjuF9N/Qkh6TshncieyKsNcXlDGAVfzXB97NU9ZOXjRFAW4q/uGsFfvW0Uf8UJtfmVxXZGgMyOkARiBbWWffMAh3X4nnGLV+iuaYDZWhzGYmmayrBYDIlVDJFYERCLP29/TvLRHZ3k6shJQLIkc8wNvsjc4DwMDN61pQkVIbDChfShLfW1aHU92X0SdrG8wGanCQr1MLsJ7Z6MpaIU5ek7GZ5/PbpPWjfRfaIOLZpP+vmPe/OT2Lr6oO9kmEbz0MmHvOCmft9pblcbU/gNNeEjG4MyI+2BPWgnEytqaONKoTqw8cWXXLDKq2bHZC2oWnCp0qD+0wR1n/x8lhgwMR9oXY4xepbr8ItbjCsYkLwxihidRuYtgZoDZS99tLcikVFs7FFEtgVtW2zce8fGzZNx0zDuZ5lxV9Fz+u3URw62vnzPHGdhtKF0aNB14i+QT1z3gGuPb9tbesnW3tLkPXOMHzpA5SxefM2phbC7ZGvTiSbSFZWFweZyAT2B4qCFdH3cQrp9f4f74zse7hviG6BMN8CdiSZR1DziwyP/KeYVR1O3pV69163sS1vM2xw1r9ASm7tbV6Q0qMYlsDZsMBRSaY1gbPa8m7FUsH/b1Ydsd7T3KacF9ewHt89rqRUUeYSyuUuFyiCkZ2dnukYSX3NR15rhH7adjeYunxtYyPUdKFQLAwMVRXbSIT2d3/aK/gMUyUr6vOJsORdYepkQNc/IgJoJI4xqpZDpY2kghjBX1qiHbGHe8+/Ip2ZSN6GKeHcUrr0Bc3+rOZAzXEmgI3y2UMrMx7JY0r+Mh7Iw45LfR0MQOGqeeoT9pgzVq5GOMRsFHOWORVTukhfmCgJjSI1+cCtswrCTy7Itn8k6n+D4h/oTWqGgTfj+arVyHujFq5VV32/pBTRx8bVKlb5Wqa7SNlC6UC1nVp/6yKuM/CQmdY6S1y549gXLD1kunAC5MMwuey5ovfjXQEItLQmktyvOXTfTe2oQaEFOR4Q06hc2Hg3m4WIBsZBLaV5WVt6bxVas7BtG3foVcM2VDdsm/c6qZTXtU1bdMPwvZx2jeGihojvZDE3/UNzIGSjeVxamyrqfpTqYvipDvsIveKGWE5XSziwUHKjeBD06xF4vducny9CWyNcfm22QjDLNwNB+ADujMmmgWSTYHadaEPgiVODx6wq9PxANVI6YSlLagl05SHBbaBKJ7DPwNC6yUELeKmRACfvkBDgu4mIKNYBdWvoKSXhbW0isqmAmanfY7X2Ui6DMPKn7ZiJEXNjhZVZcpmkRMTqxG58LieVaDTZDDN2GHMaJJdyrAo2GfDYXEIrgYlZ8kOOxias76dGg1nBBsY1fCpydSmAQUI6MuPkYF2pNUs4s53/8lLzMegCSgjm8HjRJmTubkw1OUGsbh9Bukl1dCbiPKPSQ5KbZe6pq2hkPvaec3bUy8y0hbUJvym+yykZoLqwVGtwfIM/GFyE5Gs5k8ROC9Y0jebBflaMp7hD5lTK7urHUlt6jBp6RM6HEcCFo0UwpKPpS/lBerjfKkjRRVZ5+Uzvnxvr0Qu8Yi0BmhgypVM2ybFA95KiWmA5sfvLIhUen6UPhAJdBOXccI7+LU0/BssP3EHyXST0YU/VI6BslKCGS+KPppb4MPENkNFphE5Md7c5gUrTeDnGLIZ99q0P9TMZcF40OGS0gXefo67vLSQwV9QiobmWpHquTVtiWWKw4TmqPVBSjQRW2Q52+YgMXflImdRBdFSGjWqSgSWvtIXXe8y5AgNbRG1Ez4KOjLmPB9U42IA+OJhuAxGiBTvTuICFvasVJJCoO8Qx8Oc09wm6Q+iFPEEmJd+bbl3eMRtmnVqA+Xf4XxMiSoih4F6nwdxQyMqT0x7QD0T9kuOTN/+dUFQRcUws0aCyiJ0hHlKSXsytr0EOWfoRrMWfNwAmpScpPIPrK4DakTCKHJlRO1fiJihvS5UGvp6nbdYyEgMWGHJwsaVnJkPIFNL6g6Z2F9qss06wwTV1UNDzBQCtL1NHk13iId1raw0V8rAzT7xRyvo09uQLGxOgGQ3SsoVdPLDd6b6YpKHZ48UDSkN6DTAAHpYb8TUHgajpHKnw5UaP2syUStzTHH1XzeT9ncyBHzoKcG7COY2oe+HGgSvEj0ZZxGIThtkoJBIOVhnHJ61NiqobB8yUCnA8pwGNSr6XNiy38BnRFMA5fMWrJx2GDdwPYWFzyY/VIQDLczBLIMYON0GEpW2gk2U3bw5A7+NSSH42gMjELX6jSS6TrDjapKRolNqkfuHLD00+efPqNKys30n/fsMI9RvFthWS9c0J79djKBBjflX4s+d6T86w1z032/pd7qEzICr/aUDWmXM6BgbFcciYs9Kv0Kbv3ek53XExgVGWCz5EuRqBbJTZZAapH87BSuFQhrVIeoAswKKCNmc60jlzcbJ5cazTWTjabFx9pPXp6tZKTSmsLC6ulTKa0yv0GJHz8axEj4i6LkAlDCuT/LtJs01KvbbUnea6yYalIHzMZr1Ax8CtQ8ScVzYILBFgaLuaAD1DTvquUS3lQ+DuGN+tXlsCMz9mFcg4D6GlU9BAO10kcBaepAJmJ3o9Q9iD/BPki/htBEWFnBuvVDXQfL089IfVbqU/g8nCj9WBc5TsuCK8RILY1DOYa3jIeo9MygOUOutsdEqQSRmFjQt9l2F8pMJ6IgpebWR+wEXe6/DN32RoGyIDPgV5y55XjpyW6Mj/tzG7blTmWgBfiNOex4UuaYRnVzD1qBCs2HToQlk6VCW2ZsoFKPfS16+BlAKRk6Lv5N3HVdouSwOqF7tAi8Qv7i8T61NyMoXDPGCwjg2juiUO7yJsfGLR1bky2ddhOLf/MqKX9CA1uo+pYqVfsjn2eqjKoOW+4QYQSu4a8C+FTBV6Yr5znhF5oOCVHqxpgjdaaWk5m9QUoQd3Tn+f/H//t1LNYARnmhDFCpRUtHseU3oQjBcYP/0dBgyC8jWa0mrzSJwdHntBACxWuEetse/GFgu718mAwyH7aDEcegHbIh9MqsiLZKAJXA0N9Pm8HJPCaoYAI/RpY/u0suGK2kzMaVu//mSBLZ7OjLHRRQE8NoZ2sUccqlgywvIHF5FASZ0qmL0GxHOdNndM+RKvKpN8L/WRdsiXJlT6A0OtkbVmG3i3LyO4CuTymHVn6syTZSBLx3WAQwBUmsa9hiAR9U5KS1fP61dmC/EL6KhjkIXcgUQV6p+ZCOxe9agdJfY//buolqS/QkAkTVyGOiVI8umQLDcd5Ssei8VP0LGn0fpRfneHxVTpQyNNbUeOGydywGr//2OlAoj3dQEJI1zYecoUP7+wWNM6Quc+kUSEN6dXCVGj68T7L8+KaPxO4fqgXhvwhlkuibfOVBaYAMsN1Mg18WP5Jc06BowYz5s06tZ1zuiigw4JrXuzNyqZEj0KkWSkpwvPi3103PQVpU7eNqR7E5PFSiWY4oVyoSGqzadrehvg5fwFE/Az82YEHZ0xEflyZgSRL0tzCzb3/C7Ji5BCZDBCgNkh3c0ZVP/Zps2FAC0N1MbXBeaXrE0vq4JOG7qqCH4XPISBO0EBXU3tfaMn2PytQzjhRw3SXhNZhWZCrg0s/58oTJpwK4sZ1MRwFC9dxzOo89fJI/gE6aCI1+ATKBwR26SOx0HOKKRtCqIU83+GeTWteply0ER2zoTPiH9OQjbca7n3RTocgFgj5UQZATVVUPUDKdfwznFqg/rqCHu63+H9PXZB6ZerzuM/75JKRpAzm2GRrnyVm5Ez4T0AFgxtKmmdC7pQujjG+FXeu04wUnCJ272XK+zAy4lkSSKVclOlVCeTrxb5D37JCb3OMTdzZZ5hJ46fxHCstl+OMsV+q0idptKSYt+A4t9YlpoKwnKD/xQVS4R4AzYOcJSE5x6wbM0bAdKrTPuI4KKut6cKafyU9LwGbBa6jW5Kavs4GLiRrTOKkY1VGZALJELrxtaLSUDLWpZebFaVB+fkc6lM4F880xdysreYckdI8evwYrCsQoKyeZ3edwxdyb88YWdqIURFhSK8WExykqKLRu6yKNBY4/Aw5MZRwA4AODeoA8NxJnhzaVmRHpCsH0oJ5HRjcLD+ppSHFhXl4Nu3ApmkoFZbLLbhiF1kfZmI5Pwu5dlCI00cRCFGgy8G059Z01wsIigaoCMZ0suHQDDtDvoL/bP5UIJ3ItEpABM0ipAHNQFGqphXZzE3aNX1ac4wcTf0USBRnF4hb2UUx0kBYfyJ1Evr9/6MUMUKZ4BCQuxJOBQZz6rAgkUimyFtODAtY244lbkyWlqYFy2HcqHKJOQGRmB98RnBDv+3/Fm7+hmlrzrRqsAA2sTED44/hnOsoCwSwRs144tIty9yrEsMBKIwfuvZZ95NsGzAICBTTcEB99zukQtfyVTMxEFCgTJS+aEsjqr18ZKm9dxvx59SK6jf5zboCawCBgGsfGBHa3cxlXdXIi+QqWtkeTAGorSRVRD7sMWXlGY8NAbJ2weBX92oSlgyQsbtxk5Bd21+Eff+VIYP30danr+ECj7RbBg6wxRTdMRqHy0mfgcsQ5j85MuA/NAolFUIkqX7BE96ytZmvN+aPT3FCcPm9L4XIX9/u3PfZQ4mf/w/o+Ze2WK+LSWtnuI3IC+WBuxx6yDLH/2Z/ULCEDn4fRHpxiCCd6ONHqYNv5x02oRH7ttWqgNSUgtgI/LZNw1vmAJIZcgK7aNValzAo6gQz3GeZ4e4aGI7d7UlQcGS71vZL8ewQnzMLHg17T6ACj/L5lS71/yKkSvhSJG34iNxrybzELnznACic0xb8tFY7svRcNO0KoYUz/T15GesT4nP5c2hi/nHlWeBGVFiqkLE4x4Y0RAZdwZKimlrZfeUbZZP25zsGtaAqATAtHazQw/rtaIUeps6FAGKonYx6QGU8D7CGPcDKmwj+k/mHFTZ8KFLk1PKpWol+bT4Axj3DT7G+/ReYW7w+9TfUOlr3lrc4x3roG8HqMFB8mTK3c3mm8Yf4UHfXMRZci/pMZS7GU9BxH+SJx7i+XvcJIiiK5gps0OyGxeMG99W3xtTUvxA5D6Omhvc85VdGOalfAP2fbeLC3fyBnAbfUhhxGrHtIx7oDf1TfLFWTjtV29UZvJS29DXleWpdy2Vo4ixohm7fTCv6uB9Uw8AQgH0IzIBM27hlIUFsbS3pILYGN8MIsTVaD1sii5LPjuNX0Mgc8iun5JoBCAYYUzbPfZBtOchtV4E0huJOuqopMmyUzFb8IbY60VJNB7n4P2CTnzjTSWyQl4VSvZxm2CDmh59lecPj0Ib+05CGrMXcINa8WunnD62z6G3C/meX3V2GigIXZwgcIXUD2e1IYphRwAWSTvRDUThQ5IEGXOhEv7+v8WV7h7Ei90hm0K5m2rRcZOeR2FCTK+EkektNDgq3d5LL5rCYEjtJ71FJxHt1eTCsbG2Pd79xx6Hi1+EU3wOTy3NAzcj6ieuJRHLYEbbJJQG9IoxARNQ4dnooENVP35+4JGcq2f6qqUsffITbzqrbpYrc2s0XtuMW4wVbTDy5fmJ9ctvsj7Ze4CDZ0EO+TR7CvXu0SfjY9gr0is2GPmK04XzQKAa8XlueXFivyHJlHfP33dM+UDa5WWADIpP3DABxkTFapm4h7kg2TFOnqSHUqq6BFsEHQjhcJ6aIC5XL0HNZG3RcWjSvZ43AZizs2Q0nhq14sMiH7HKI5FyCR2ueJ13noc1iqQrhpD4sO+YdZEkoaxahIYFvGZpThRvZ/uOtLoSe047mV4JfNycgbanx6+6M4Zi63XHThbJtqPABRYUONB5oYQbhM0MSYbxeVlUVjWWD+yM8kt8aEGx93S2ZGaYYIvVX0eRDz/jTt1LTXhDR31V0GWFv4nw1g3CjAhZXUagl7KstjTUHOf4RpmUXdKCFBcVzpq6cfTTGG4DAFUQ2+eX82XY5k1FdVTtSjxhRYGsNzV8dpp6WvcZie/O7cQ8vZ3rK4kZDl/rLaBDOcVhA/j01UKWMiqsfE0g2zv6KYuWKBDbl8hUrI1BPOKOkmz4tfb/+kg1ZYXxKX+R/JNhA87wy9ednjOZJHNn2KiUX0TQgEpYSjsZSnqGAYdz8Z3iP0JciqQt0AJsi7SOGMymKyMMjAcuN3ANMhlKzw//RvqqCUYjPQ+EBaOgzF+DyBGy3hfbK0WU2JZA1/F1E866U/97GKTWdZsLMiARypgTHqpWdoCgVIJcIgUDObVqmw71KBj8yJ0EgULma8MTkEFaBZgQY5zaxc5IRjYlGYe+CoZ/kcy/mSaJQseEV+DjGjGanB6MCaEXlXPQ4IF+Wb7BpwRFELYQJGcpXaih1Y9WWTFwzlmrMl/BdTwAEylBzBczD/onkvvuUAHN+76tFC8utIibKWS5k0f2GoAkqWHSvhQLZO9HUxayYnXDmHsGytS2zQrSb3WlvhRYPMSlE4kqAJLOLOESzdyPyAHz/NMMps47/IJxEqMPQf3AdoD1FP4KGzz+RlYxwFUwAiVg5kEu549Q/g34xEP4thw16QDJZhPw1uvyaUtTQ6OWJgMHWrXJEwNDLlY44rJmvs20gQqXTs84ZWAianGmJuospgTBZdAbBg0u7JUPOlDGpNysG1ywDEpYTjJojQnUaqRB6c3ZNIXP/fCt1Q+OJmmPZKkDMhQRS+dZhqobXEZKZ/1i2ELFr+MXFIAShB37REgtQXyUabcizyQDP9VKcrKkuBRJBwJ6TCnV2xJw3VYA3krTAeSdbBfMZOagIEcQrSV5OHITdQyP2Cs3V3sYGUnyIE1boX9mEGRjYdbVzjA/XFLhOsz/NAQaa/7Goky0wLxMjNozIGOLm/RMP+cXuLB6yjpjuVOoQAucmwufcPckVsjErCs5nZDY2cpdhtczE4up8TWBbXAKNYTCOxRCMxUqbfxDwOwGio40DEFz9hkv+M1j4ED29MAyn6en1Q/ad8QP8LY7Q7AOyk2FzuJXAV0NW83jdPhsmPj9g2TABKKH0w6GRLvkeMFFhlGTVUfSX1eHiCyE3WUpxY+KwhH4STQ1dJD17D+H4d6g12ozE/CdXbdD9chs6mfHfhNcl86LJDHajM3FmtLD5mS150MTi+mJrGziWGFYvUaK8ybKg/0rM2v5rh1kbqlcuv5hXsNPBF6vGnBtMVqK/oEKRdkqVFnfIbhN5UTIZ7uV2m5yxnYEa/zP+0xD1fFyUJK2FiQ42bgB4pk4mW56E96OFHpT5/uA62jbD7JpErlk+ik1KaoagHAIoNjK4uDTIsYjuQHqFPaMgoqi1ZgOSn5ac3Ti5kTWwytVplqVsWAqmsXiBrCCr50oOSxwZ160ClT9M776MZwzNXrOWNzS2BMC3ijPhBoB32e0XXfpi/mLoDC5jlBdaBhumpfV6UAmwxKzVG3XNqBgygYzkepCb6NQzjfW6bOE66y8HbH6Jy2h51zXY048yHYlmiZHrc3D9o1hredFWICGxNZ0d/+VosyoEFnSarRBbEAHcsHZFmEOfBF5fPuqq2VNXn8zu5ag95qg/GjhqT9rJUY9Z3QaUHeeAvRU3/4EzIRqISW/ZwCaGXrdWHr1x3u0n+ZvPpl9yk5yMhVVIdXKE6dB8T1NNSgAEBg1nXfyvCDn+B8ByUm5/NI0nv7IWwbiQss8IdOOGg55oZYwmhqxHw1AYbBJUDvVDWSRiUKNus9NNTOPZHGidWYKNZ2iY1AhXJxfigT1eAkVMWqnkmQRytIF8VFpivcJw3oRv855hl+46crFbt9nGIeYkmlgKmi7Qme4N90VqZzsCStyiphf0l87JNIZeuGW+01YJFccLoKgFoKccrG/+OSikMXTH5CwNZWZZ1GTRyLBdLf6obGIeq3Y1udC7fGZGsUVNIFCNo2L0vnhD6djUH67869P0erWsYGBDwvJWdebwNbfdfjjQNWR12K4s9S7gvsy70y4FG4LtUEOHPnAFWqfZdEgMkq7OrpaKNbDti6zezgDpWRHphdA1Feyc4gCTQvwevesBMLInAAiHLGnh4kCGzqJMoytuSgDYCAtvmNrwZqZgXpuxM8goOwy+/U2Y+TtMf+xFqd8dW39st3M4OlsZnEORXhgeMriM0NrhlI2jPfbgIU7Lj23htOwpGqm87nZYh2crNE4LCoXorH7DnGrm6RhycuPiZ//fl2x7EHtPj0kz28Okmb2k/FiZEVtO94ktK641OzcbE1vyT9u2+m7WmwNktl6Pa+/35QrFnU4q8J25PkdmbitHJlvEwCu/x1DZLz9wMHX2AbRun/Oo+sH9gay5K8eJrw/cZ3z9tf3BrD+4V8DVT3+c3wSGs0t5QluP0bcRem3bosg/K8q1wOAw4EBGCcomy6uzLK+uhHk11+semNdoBt0GrEfrWdTULIPm+NvUchkNBtGxvPlAvNdvX7op2zeeHdKib/PYXWSkRS85t0Tsi0k0G66pY+H0rM84hjuJ/6uBHmn6bBKwvxIVvmJCZF0DKCWkF0qbcsNpKoRCHoN1/Y59kRDdqtsO0XRqxkS3bfkbJzY81MIK7V3zokf6SnyfbJ2AgL+cevs9Q7beGds+aytJ6yB4XdFnWP/KyIbfKw7CsC4fkHLmVTExawguDHGHIG2t5jCcPyit+qP2RxvzawPzdtrWzH2nNTQrDYsZV+ukmTjMl/h/hWmJSv31/21U6ntYlP/DPnP6wlbm9ARx1Fbm9D5zVPstB2FOv3E3Iybp0i8M6dJb29ClX8zo0tv7pUt/yR62S4O/55v8T2C7NlhYnpt669iJ3lkIiltMNE5+94gxOMvvPljY3PWwbX7hLEjKmvuKq7+8u/E237879znjtOZPw7brWPm486DioLsxMh3c1PzxA5JM/9oOFEtnZNyPHVQ/6V93Zry+8AAmxXnUQHppw2bnA/L8etIaDOKJFcNUdhelaBYWYyzZHCRu7JQ5dm0OEnXpgGIku6cvdFbRh/IJ0cticgcQXpZdem+zOsgOseaS85RygGViS1CxgZiVgIHXub8GR4qiWJguAfCitqB3xZG+dkHXQWoy7RXKvU+cg7Pbuw5jyXT6y8TcI75LzWlZrpoxM7jHoQvF3x8vdjXXt8EOAuCiD2ROljEIVZpl4qbBFtecphCAETCA+PxeNXx+r97O2G8YMrbXbk14Iyf43djmEzk0zUo8Y0AHFgJZfgpaa5cKHEYkH2W7dhGgpd+/g6EzeN4kB4IqxQv3Jha7W7buiFSENl4kn+BSgQs49TqSokQ1ENme2sL9MgBXL01nh4i4wOMzWKEPKwK8h7XCoLdhVTEoGaJXdPl/w92JBqriI2gi+cjomjlvRuiAdE5WXT5fAYEqmiwl7JoQMIVnaT1qa3Hz9+KCQuAkx1cKqCWyVEpkvZp/GQDJOSf3i4RwD4sKno/QK0YRV7hWlAwqm1g94mVYuQECRyujF0WMwD/JCgf0MEkqjO3msTAqqI1mQ1tZ0rGhV5LRFC+OrughNrRtKB4CO3ZEJAFBrvdxKkswrzdFm7VppJxvkROycoQ1UaOKpISK5KM8kWi704qQVpTaJDqh3BP734p3O9r7AHtFzkcNSa+pTjGk9feZIOyjMFj9K+ryd1pswhXLE8II89zKOptyMatSCh3b1Y+h9OshtVpcn7OWG/xnyKKoFMN34SgZo2lLmRswuh4LG3u0mtloRoyu6+2dVWQzlM8FQ0qV3MOkPM6QWXSxZkmmCClZmZltFzBoMjP+yuzcCo7AwLIrvxMzGxg5LfKxiY3IxFjC4nLTYGZkk3VRN8IBpVDsxByvOnAIqK/4G3YUm+VGRCv5Z3Bc6dT5a2p+Aat2MIE0uzwrYh0U/hcaiqzsWiht+2Zm2EIyNO0SZuXZw+cdmZH7dh68geT2fmkiOCJYtglSbWXAA+t6Dg2DwSWR63pIHhmTcl+d9vKkOq1ySkbjcVielMHxhUv403CSlxPZwj3hJMJoy3yIzT2sAJxh91hJbnANq5i2zoFvvGVqaSci90v6pXeDrWuZVsjwypa1KtlYzBRCGa5JZFTn2i82H98Kfi3Rgif8W0Ttzmp17u6bI2kDtpl1+bBK5EP5gTtIzBtCueJT2K/8wpaCLEnvO1qT9el9Q964RElG2YVwMH8KloNxHEocU8s4hmYmGIAZNNND9cu9v3cRQnNhFKRpRQzAyCmLaq/9finQ9+Vq2OPhdo9Dt+6lhjufhF9OETEww1+Gxd4AgVlrMcAkt8Ajaymc2Dg0cDhQCO3P4aZWNlYmEw7XfwPJfcOYuscKBgF0+7TBRPinqW+PWx+eWQAa22H2dfmMUV3ed4zqEgie/Qaqvb3nprHvp827zrwQRYPvHMayN+zr8uq9bC8JL7rbyAVXsU7y6dTPDkQlJPwP9MexuK1v2IXb+k5OGwHwnv5vdc2eOsRyvbi2OMRyfdm1lx5KslxfWTk0wPwW8dOqth9jfm+KCYp+9X+Qp75xFx5sBUUbOeltYLv67JkmYGP6m3OQhs76uc7Y9/Sorx+w9fOZ/yk5/EUHbBf9w/6yeop8X2VO5aCx/nvUDdjClXEP5Pn7i2pCEge/gXbE5as3PfPUqWfetBr/N1c6+0Xg+DHqpRNHLmm1Tq03m+unWq1Ljkw8Y+5YS881ji0vHWsoSuMYf+pc+s779xdxfttywRyEn2a4OYB5mWTZt6Alncbm7HsRZbZtvKwO9Xg6UrxMG81KGLAMPT62Xb21zxPy+W7p80DFzGX/7Pl9dDV2twmOFvseJe6sAbXGKFZIJ42J9tBfuCKNIoljSVOxe68CYx3uIhCzdzmj+LKKphj6OiaoM1CPSYJfCtJiVheh8CmqgZLBUYu6PHoAWK6SlzR68BmNu5tsrMuFgg+yhaOYyueUQM1nLUCULaUAPq70US4XeJ6hqGn+oXjxkd57+FJn2sy5mA2TjdB0wRSau9isGxgvh80YGNmzgEgDJC3DRwlKOF4umcXzS70/Y2/hTjIjV7qQNOKeiu8XiJ0HsJ1eDWDq4BBoQdKW7k57PwXyXvKXdRMqTZjBndIalQBdRnByLS77v/xxfaIJSi5DnZydwxZm6vRX+X8B/TdjxzlQw67C0YLDOpHhETdCZ311Z/0kBh1coQ16OvMM2eHt1e7b4nSv23e/TmthsSJCGoJsywq7gbGcksRH8/36RCMzbmvv1fvoxt2L/qrqqq4Vlwt6Ulvp7X1tpaoFhhtzwsaUN8jVGoBcq+H7PG6PTl7vmVsaeTyi+Zf478Gqd7LVtbMXub2x1EZpaLBzw28s+aaz0aJJy5m99EfzwYQ+GuCdMcWczvzmzy3UeTZ72KJH+t6kHunjiKq8jjO8fYrwdKb19JSk1lNAv3VS6wkukYNL/AeUeV6V+nLoEmenxeKtbSsjioJI2Co4votXnPEgn3vomTdagEbdIiyKllxCflT1sqP+ckl/2H9k67D/d3pX7jzs/1A87F/gn3umDZjcdJl+hy36o70fDcmY4xZUKwU3vW2jZvN9+0IIMPGIL2ETK4dxwSdTPzm7pchZCDXOQbSn2uPUytzjz0KtcrD49N39KVC9Yk+Z7XMZx/48Gcdu2jWObT5y36pUt+9YJPMACn0H3EE5bOn+zX+XX6JeOYvFNPfwe9DlRquejx1Up/vMfetI7FsPHPGtlyd96/mkSDebKISmFqb6N+S9DirnzaeykG3WgZH4Ddo7SNZAfaWZvUug5R0qoC3qzv5WeefVBS6SdxZGiyRud6lnDwS1eGxagBooryRKIGe4BMpmoDbkBO6gArL7FdDJgSC05WVDRWg3VISGpU5S59QsWorRr4++JmlYnrHBH4xlOH2wmRjVQh8YFDJ+VAhdMFIIqbsUQld9JbGCaOqRfPQjkjIq3+RvZT/DKPtaXCs9IaqVNt82kJO+cnhH8TeYnDS11r4itMAZekfqi6l/OouZc5kLeUSXk1GDqdxsiRo7jUDPTO0OsPluFLnOQmqNehOPsSAzEriMXLPrOdKrymgACLoGNrqRAvlLzkgQefnZUb7jfsFfcQWw3AaFQDzzACPIIYgHvlzPglGNEDNuxvdsvvdhNL1tSQZ7JHa0QRmY4be/ud5xllTxuP/gsJ4SHgXEHjs1CXmfH6VuTL0GrsgwEbRvB8VQP2K30yM/xCYUPDVE2ocktqT/wxYqAlL/gQcS47Ib4rL62hTrceCgJanlvnwxiXlFOK6AsVf6y2vR1lQkYockPRNyXfBXCrkcSCPfRZ9ZAeN7RUZDRaDdoPycJTtKF6l02ilVdcnItU7WF2+aP2y1LKNadNK0LM7zarbhOgGtCW1+miA8rrL0oGX3iEPMcFh8NbNgxiOeUP4yLNq6k047yGJsJsDYaN1s/tifcecVSGVleBOZgw/0FuBhdaFxZcOfc8AxJKtKTS8eK3yQ0Q7yShOEsdiCZiBlFOWu5U247nJQW6nXzq9bOi/krWCl0PsxiFCJVun1CIjwkBwojpkClGTKYN8U8lihw4fVRTnkRs9k1Vm2yvRFcDv/M0D/9039CoNUjWp+9OUDRsQDMqyUiQWuKKz3y2IskzX7ZTEe+qAxw2LJUPueG4oeQnvXtMaPf3y/q4Yl6JUO/8GkusAX+uoChx6xHGsLHL6tMTXHoDAKTnxGiApkq6j4vfcNoDDch7iclykiLEMZBILiaSkw/2iH5mrvtq3Bp8mCD5Y5tFwuPBZR0AL1n8DJ3AtJI8TN5fsSEb5eERka+cGRAkGlXpX5NxeDk2KlUcX2gRDWxzgKDAOD6rgdAAPzbMkFwXbOsWjfxOCS4UGfX17QBsce5ESVbUIKaHENXTH17syMmW9TJMoqOS13vWUynCV5xc+wO/3I1OuIwfKMCCvGcSkOHtW9J1zlD86IwYI7nfS0vxl42hNDT+PhaPc/py60HzKL54SKNElvK4XedjL0Nn3e4j98Dj1JZKuSWf6bQEhcDQ3cP059fWyMxLhx6J7wGmcMdMQtY6Aj+Kt3CFRPGgSqB5xb/8mOA5DYffuSe++OUeyGaiAI5VDoiP/YufOszR/svrYpIoR9izneLHbgXwkylY/sdrVtUcY5B07FjfiUMDKtbI9yZA3faoNYkz924nhfM+fw9WfVXfgRb3nMKME/r4zSZ3Gv2sEbhlV1+I/u4g2Ts5MJb8CS6C7eULqikfCFi+AL/zHC8r9gYkUfnPmg2kJrRbKYyPvnmDdckXpG6ndSX4vXPdheAHX02aymv3udbGSstqKElZLTBk1zUaW0qoKzD2diHJxjORNecBBf4u9w6yaYtg2tcbIiL64t5dLTi9OC1bLtSUcLKN9LlwxrwnaaNgfY+zstXfUF3s2DQpn7iD1RBVzSLbfMF6QPHV2aSbrd3+7gdve7vzKm12Uz+3e7C7MWpI4xlZYMJQ3mrTRvOSapn0pQJzGouNftDC09qzIn53JEqQzuf6JrzkAV2cvBufJln7tmR89MCrLxfwZV5Z08c2puKvZMqD88fBe3vCbplpezNEo//WkQjXOp6yEu+/7Ud0e8ThzL68iVKExUmFJs6HzisPM1z05GtdI5kOu9IuF6UnmiO1HJpKeXtnW+CeZ8b3RNvUDO95mZwMak5/aE//Gl9ky7PLm9Bx56woGSLK736P363+VZR8v6PobkpoYtHZ+krfLlPA+ZAfiFYKqSKpoOKNBl2YYvqApNKXTd7fKWX1RMD4lA1ra9fA5vrOPbNe4XE6kYv0Mm9p5dIiT4PwcRUik2d3HEC5KOeIQ5onf6H4Rr0SS6EAisVyALS/WpJvi184CyJYZAdh35xH2UFN8tc0huYuFdoixoCav92g7K22jeDc9FMWxoOTvryrT6b7ba7uvU6IyTuO/TQkhZCL/nShUe8iENy7GR2srSpJwPDLNQM8GAuLLQHFHnDZV5PTx0ibODvw/nnhZVdb3pNh/OR+M9CHq6fmPSfvaQsozbUkhZRj9S11yIyhiOLPTupMTCLlVjmZoLgKXIy7F8SO/9csE3Zyv8855r1lQKUGXI816VVn0bqD1xSMi3haWGViTia/ol82pH3fxnVtKxtYbGxCOTE9Fw66GTlJipnqhFEjOOcr47oZO4TIB/XvSmzFAoJChgNg/GtHRaa2iQWkD0EXUIBZdTwunTp7+H/oSBVdbnQeMq5YRLwrH+MvVfaD1ui/AyFowHHkCRYaC9HMevyJMYioILZc7AQbNF5wxiZB7N0pfZPDRSKGNQmKVgGyWzX1WWEsLMEIwxleyxU0ezu0kyEzsJ02Rep7wbAmdi5D9M8ROl3jNJ88zmh0TPwiHh5lP57qFZKVzAihXLeO4XG25f2ezBCWUz/t4DzWZe4LfVbHbhyG5CtZlWzkLZZqNZL0iTV00mfCZXKpdyvdt3UkCTWgtrUMrtfYpNfafn2kIoY5aemJ3McOpWpTO044qQGd0ET82DUr9O0kI6zywYLSvF4tl6OIsU4i1HIiXqDPvGztrcwlqcwDJJOjT6IvLpiH8APLMSm2aGnF3L/Nuz4AhxQeJPzSxSL89EAtrHGa0y7AVeUahGEMIFvBdFDVscS1v1uc2Q2HdEn9s0W1WnubBsyk6uslHBWwi6ZUyamkZLbPWVQ0vVYFpVOD2ThyAT90qzFqBEM4OqmZtaWLCJDxDRn8v6niVMHqmbVQ9jAbdUN0tEQsvvJtLd+12syOW9QoGkooxOZ0JzWgoKkyrI9pTbgHewOqDqIm2QEnork0hFb0bL/uMkLDNOG21I/GFPzl4cXGdl7Z7oprxonKbaJ8cm+r03R73ZoFhIXOtv2amYeZHgAbo4dKvP7l77fnuvtppZU3YlAVbLNvcMGsxwO93TMwuziUoGug+71bWd6elkXXsdu6tLIG8j/1hK3QAF8L9kPN5QABqQFW4hix/2gGBv2rZ7yDnes3Qdsfr36QyDK6+5wtvJAxYyCUbCr+5A9PaP59Y/uDrPe9MJjsMRrvekM/zJruxwPz+nThIFESR0j8Ia/OfOjozISBzZRhPEOkB5IO7P1eA1f3o2hEdGgsuIgshejjFaDnAP2IffcePok+zmWSQ7YvebuPwD9pHq+7u6XXOimagh8izWfJPFmvulXpb6GI2PR3uz+753lrft5Z6LeLOlnzZGj/aRyR7tB8a+lu7cftXtrrMajUadzt9vo3avy0sr2dsx6e3qMvtqzI12QPZq0goksQfGaxGEYy8kjt79lSSZpPsNsyJ3k3z4nagw2YtxOSpnIGm4HDp6XOi03jR2JSIgB9+eNXluwK08TUh9GORBOzIx9+bj8gU8+Uy8JCprsPE2ZtVhAKWxI5vygHLZaOhh4ZHfg6aZvzSuWbBIbDSMQS2DQsNMlfif8F+HksHTYEVg5omEXogU45iGpBSN8QfbEStU583wGZrwe4N/oKdOnCndyBc4n9UXaJg1pJDbZXBtIS0WEXAWssB0eMWK/pqfHbbbGrAYAnPtENSuaxMTpTSJvWnA2T9WSnyNHgyv5h6CM5Iz+Xe6QWPSbN9rovfd1uEga2YsjeqRNARozRzfntCL/BN1w1QND8SFAB1pmmI0LmjUMYSfcLwZG6q+FTtYy7/JNnQ5zd0L/3Bp4suT95mWSZYOpYjSKyNYFdT4cKDrA6FKycwBs4v6Icvm8kThS3Mzogv/I6oTzhYbb/eeiMb8+8ZI57irx+CVfMw5jbIP2TWNO7Qr5+RfnbvQmZLgAX+BkcX3UxMgBXxK6o2pv8B6b6odqTfAqnjWsB0TbWBZGv4fYuEMIiaJgvNrEZJmRPk59oe1mN1ZONQa8adyCAJj7I57Wr4GZVi8YIGjVI/QPJnYqwYQ1BrHOgSdVYcgyXhHHHn+k6VC47rLloJMUKsFl9d8v3Yf+hNC6eadWTTfvry6PHNrU0QSrltgMXU3Pwr3CGL34LIoL8m9IBmo3Tl9NG7uMXrIPsnJa/fyBoGbqZfwwJDhKZ7escjDlJqfdC9e90uQMilZhUa3MXlldd3JS9XjM3O1iutW8lahYOXpT0aHe2goDiiCitvS0yT7rMJhCJvee0XIXQLqJK4YvMoLBrIi5TpjsuAndnaOJ7calfxhJHeSz4Xe5pWTnvYCzTfkVmnzh0LezRfyhUrQx/V8HwiO+6aej/XIM5QcoeZwI+QhhimpLeGM4RqR2fcuAxi3BYhU33dG4Iw3WuWGxc/rEzXfrU6Ymx/VynnjjXv6gOqV9HJ1jCy/26zUhpL7S8Pkvj0Cv7iUZe4dyEyjzyX7XpDPEW4LP2FHG99u+YZUy1+2Rwr/snKnXWGx4W+i2PAA8BK+G6iKfxkzNogjQnTxdgop0UX2DhUCgxENOwdK8hv8ctikZxpeIwFlfdxYcZwbtyykX+OYkIwaf7tz1LgtFDB8+P/aIlz4dGI2gYDgg1+JCzjWPXxp6GDToj19+TPf92zEmZqbhe1zm59IBppr9w4h0/V6eZwSkSf/KYZx5NrhOOJTHPHDOKIpdSV2qoSiYX3i8lBwkEtIIHLvo/fNKrWChaSHS4ScD+/sa89qTU0VN/YqFifaE1qtM10BLt7c/NggtDBID386Sk2eg9TkK2NDevaTn0iDm+ScdKfGKRdvHIL0fGIrXToPSM9cMof5ctJ3KIdZphzmotvIOfRFa+Aar9kpg7lj310rLy4U54cLxZ/sD9GTR/WrUmFCMlm2puiDROfPmadw/LlqaO1VKKZTrdOfFAIEvAswvbqDNkTRNicscXSbUVt0pRN1LEhlFf5EzhYurNCL4C4VTozplFuiJ7DqoZ8f4a3EhEO2x4hP4Z01bnrsxqGP/5DXhoBVua72rvW6eRAziUSkmFZKcz62Wf5i5ZGr6sRELQPodXml3HsVFkigEvIFpYwdAqBclF7zEZQfcT8OU6NcvlRSNz8X+12b++KegWiqWS+PkylDeKQkT7iQZGXL6S27uFx02o4FmkpWtCgaIBcMii5k87St3YXmgzCBna4oD8pbuBL5fljK/u6uEac73dVqjan6XrnyeqM5O1GkwTaxQX6Fv5txvt85Puf7Pcjy+N3dmeE333/OiBxPbGWOv36UOf57sn3Nuado1E5/g0cxm7oPUpW3YJyBdkCFD5H5jGqV75DqHI282Ngwbh30dTGCiujGtKx8tF3CRWonTLgktF83FEqPGF191iqCvUn5pLFEWofxzgpTtWdHMd5rifo/R+CqfKbizOmkGg6z6XxhpRB4EAzBAs7khnzkCWslCccIqq8qnxVLtTpWGanRsOQZ0CKxVNT96Z7u1RUN9hUwqMTCB5ybZ6tBC+XLOdkoHJdqjm0qRK4aislrlpLXallq3j39uNWwjnaRnuQVSTCNKau80FyGsjm9VORRpzpEpEpLsXy2qFWXN04sVV3f8KScYXSd8oKWz6mVii9ufls0JGz0qqKANQ9H+RWh3IAMQyaTpR0AKLBkgc0hFePvO0Ula2QMJWsrrYlLW6vG9Eyb7U157iHvg53zccguAnvPCRjwCuIvX8eOYHR1+lQpDGQRwk0LJjgW9W7iTY8VgsDFe2OxXBkXiGfC3hriSpLsrZ+mZyShGZdXNGQvqtU2sgSxwU2pl3TRL/rp+7tt16iD3BRqlMy7TdApqKonSghj/gEYWdk/EyXrD/EjwGjPiGohuyBCjksW86ZBmvG4kGVFKer1k42fAAbFVaZmLHdGQYIqYEcbxHi+8hs7sa4iT9qLdZUxMIB1dT1kXcVteQht1fPRVu1gyPy/iQrFiYYr62sd0hWgaBZW+Wjk07yQJWheXzWrE3PZRHQlO9EfwbyUpOEcoUW7xq7GCheyKDOwyPo0gxuES1wnogYuImT/JVggY1H41dWO4dBvrNH+Q9YOEwFwGv+1ZtFa32SJm2UkNpQa2FJEYyMWdKuZ3Z5sqwP858PrXRzKahcLxnPTugeNUVIlkZQZH8Nqnvu3rIqLMq1DhwMXWDpfKUvFSype2cqG5NlSrgu0AXqlWHrirtXcQm3mUTPFI4Fm4earXoTt0ibTAZQMiBQH1vNC8hqIdqX79DU5le/TUG5DYPMOHQEcKi4F+gTovdpl7wmaa9uqiw0k3fGUp1EUMTUD0COs7eDDC7JV9gBP8HzNsS3VcsSMHzxQL+J9EWmXwAVHdu+m7k0ag8EYHKTcOfGMvx6HW3TzxztZ/XN9qzdDq+ez2QAgH4n6H2J1R6uX9qAJfdzeRnzusBGfuKcR8dgX0Ws5AXHX1dTTU+9i/W+2t0/qMX1CVx7lq8Ta4fRkl9bi0ihKYMVQiYuGaA2v0WctZ5JfLerWHOPCd4Mpj/KrEA+b5yIVvMaSQ2ty4Zpba0BKTBGXLjkWcoUKgfvADYBahz7FSQwgsd+m62h0ZrAsBi0sGEKEwNzS+edbVhcDjjR60YF+OmVAmtXiH6Zr5RLka3pHuH/Byjr6G7BLW+9dOIPgU/NYsm5YVn7xgYtfWXzl9262dV/hZTkoFAHR/f21N2MqlVdKJgwVVOtFUgjiJzqmLfNZCcuXlG8ILrL+t5fLygWXHs+UA5b14nbMSWalMVn0uq4aQnc5RS5X8iLuzzSvPzLbtu5VmkGXAteig/tAwzc1KpeJYDjKaRD9mDGCkkIye3ncecAFUabSxg1RnOqW+aA17T8Z2RNo3nkrX1JnzVC4SJLZYfqscAr0Yg+BxNe7GdU4k0srh9vuYAVaZbBudtV5uzRO+nyyUa9ta+MlICjl1nPo+iOncCwC2GvKs0jYVYATCxmLcwBqkjLytFFSWAvkZe9MtEDe0GeIZZ2TdK60tvS2Ld2T395AopHpfXxwWEsgnbcjWQ/5s/2zurgXxytXy+i5yfzDChs+1hxzavlUrUQ67kA1b+lsQEmkAzqPbRohnixew87xfZPnOE8CH/EpfvyY9K2HILhL8TLsZLxlbHmPc3ObjtGQuGaMHaNjZ/su3fzUnpNoZy9O1XFC7/7vz5fuRY4aJ0LLqZuApfrAjuSorDgkchWkMsPcKufmfjwou2muXHIFRm4qBI2JXJI1ZfWsp1D+nnylza18pek0inRGV+r4WUlOspVyT9nbB64a9oETe/vAK3ehHT2EwoXMv4SF9Nv3L/HCBe1zYn1+ap/cJJVD7d5fnG37/tE+KUZ8sXzD3gb8hWEDPnKc/OkQKCzITJelnkBBeH3/vBFIfFi/Jf6KcE7s9okDskFYM0UB1eCAD+LE2bZl7aB0DsVJHJkEnUPrHIRpFoe/yizspDZSj6fSZJSq9dxcqVvoVs8fpVu98WxbYk8GVU47FzfhKBUqHarPsEd+FSA5bzvQ5tnQvqN4Ni7CkVT1dQfeHBtdWwzXxjZPn7E1h2x5lezo2cC3sQWmCwZ2GwyBL1QK2ALL0BYYVhQ10XSzOUgvYQssF26Bmbo7iU+QdW0/j5Yeh+8DqVt6T6O/9MZho583YvT7j0bNJSwXkoGvT/0i1ScHWS3s9+M8dhZ9LIgkLE0l587FyL4s/dqD7wgil1SmaRX0drtd90BE1o7N3UuRuekE9s0tnIG1z2DnL6+7ppKbDLZs/R0ls3vNWtPrG36jmW8mSpWb7zNs9rURs988bHY+NQP+wp6gwex0VVK90gfFEY8OtOSEkK52PVZ/DLsOAGi5FCHRTA974xAoC/ywb1cJoY8zXNuNmrjNKD9aQQepZfmZPplUiL2zVuIC1Gdvu4xUmv28jWjghXevcH/nm7KnEHUk+JhQtISNoKxcoi6rpmOtSmADKTRopPMwl/BmJwKwy1Y0t23VeDiF4OdAFAjRMuD7OO5KLOdAshPfjByFsHOy0ijiL0AD4Z9AaywSwQ0mK7CtKVAfFkRguHclozFhN6z73eeqYNK9xPBEF4AM8jhByMgaPh4olBqqKa1efNWVp6ySIkC0XMoQ8qRUzhmugh8tbmgVHVesqGU0mF/JGZnN3ma+4Fs2+g7ImHQNh/1pVS8QeD1rgE9ZsTN3fbrhwI1VAb1kKIc7QeCQzO5RFJ3Ez7aB5uxzw7WsVl/UvUuHkMaKw2pA4RpmsBoV/myK6RDVtHCIsDhkbtQOrNFXw5Szyo8TrfHra45qB6Ee8zwn6Z4etHjS+PGzmTQdkHmmFGfWilR7y3xGhryr0SuUJ8ApCgxfMFXEq/4qC1Dr5qu39Aei2PvG/mlcynm2qjjadFBcq3GvVgJH7Qbcs4bVeiD+NjXBPRZdJcNwITinNtObT0MrlLBTOdNTniAhPGCBZ3buBl7MmZy3Z2Rlz/zzWH1MQ4P1RdShO3MNViYBGI2UaMLRGsRDNqwY0XLy15bXV2OFwNCi3J4NH/6vz4ImK3+Ik5QcToyjqaIhLIYBUaZBoQrWq6Sx0yUrUgb0LMMCfdXmW3bo+fRNOruVfbWzDfvqZSH7KndvqFoj8uayanmhVr0pinzE9g6tQ4p8DsZaOQy8Yf1rOO5yFf5gGDKKfEOGH/R+Z4++DzLNo8g08TugpfMYiH19YGxoyoDVDmZalTCDGrJozOwfn0c2WAwi1cfoQO5t0cwYLZ4nj0Mj8xwyqqKCP10ykNwjZjGdrkwO2HTYldESDgwrNq3kOd58815mffOeDZ+ANXxmRho+C4cW+g2fFzCuywzZ+sIaJlc3MVJfUQolui4bPvTp7A1wlFvV5KnvvYFZ+9Yha5+XsPZPh7s/5aHuj8JO/WcFLPqhrryDENRnoa5MuAm2ZUFhd5b8ZEts/trZKjUxnOy7Cml/nrmvjIZ172zVnmt9j8Gm0oSBp/3QIZ+5dgyf+Y29b4N0qnv6c/y/wy8cdAWfA57UrcIh5yYabLGyOFqfXj9an/K/fpZP+pZLOTdasD5utGDtDE7yxXSSb8YTD62COcOo2N4BrfKlLVIeMejg6tRrQ+amEZgAuIorEdfAtgABN/C2hRd08WXx7GEY+B+KfhIyoB9ysLazBSyAdjRnl/ktr7XLm988M9gCKDH5CDmghMgB+IEDiNaOkAFr0W5x/W9C+quH3/RC7pIzAzGw6/ebwnVMEO9ytHnefAYTlZGrkxsqKFvRnmH4550VeDBTWW7gZPWv2ta0SLINEmGDHjV00350K7pT1aoLO1yVH9ECoAnS3RLSlmQRGVxBf0Ldcaji76y6s/k93eQW0V9nV6sg5HPXPP7SKR99a53daKFE3fzI7bq4tNi/XcNW+gOG7sbz2d2ou74cuNypobrxeCx/yQlJhZ3z4/FYLptTtM13WQK7SX3oOeMWBaO0DpMunv6acBmTWToMXZ0XjNW7OyvG29K9u3Y0Op7acyZ5EOs8ejQiPnM0Ino7Pv0wmnEX7vD0g+TTv2746X90Swg8DKD1FwQ5dQLMrCkOcuR4RiHfLQb/0BYfS7emfRZj3dWZudW5jFXzs6DpkFQzu3x0JQt8BcNHGX5fo6Y20KjpPTUR3gDD2S68PWG38HZVOPP3Kg6Cm8wKirlr5mJJmnyzY26+eVtJmtXxgtndOwUzIXUcecI/g5B/Fjs08Pv2DjIw07w0zbX6OjDr27XPtlz97FUr66PM/OGzHqXm559LAi+hkPMwokaxKgtXP+MGMOELiqXW8N39ltjwhf/l+EjcUpmHaQTTTYMPesCqjx3hmFbfimj1f8ZUWn7Rdb02gqIdFJR0sVKI6TKIsugW1t7CENVL3uytzkTiZn+v6OZgW0aFxB3pE+LzqD/BiP/2JCP+K/DMj6C99TNovpwA7uLlY1TqI2CKoSJd2BtTMYg+QGmEb4Nzsj6sDEMVPMRzPtIvxw9vLcff2btCtEar8XyL+3Bcic9P7RmsjiKZi4Vbnl2ZEAXDL+nG8XJS2wXq42MontRjwRNudY9QNTPQWnmJkM43TMx2BW5lVJNl7dgjsPlx9PQXgORVcBHcgnH6H6f+DJcBC+bDeJf1kR2jzpYVo+7ephEBFJQYgXcHJ6wTEuNQlzH8BthkOZzds2jWHTJkJjLk2raGJBBisLz6md+JpZKfHeFgYqnkZ9w+KpD8YqaN3NDftKcNce/WrGDaL7i6UzAcut8pfKHp6tNC/g3YL6zmMLgXcmMZ+31i7tJbFpLayEt6JI28rTAyXpPbw+J35NZPrCtug2cfzciXNK9WrXuFaSx849d3JupzVhW+k80iYv/ewD1+lYvcg+MWt3GP3ltbSpZbR8Jw8elv8T9G2JzE7OmpqVcP0Kd7RETylB0jYrQ+wY2VTq6P0Wd5106Rsm/LF/QjZW2iPhIpJ4pBZ/PnY7RqrtuzlRJCS/eIou/ghUQYvWA0jL6vMNGovWTz3/eC4Tx7L8DMMYTfrzLb3Sf1WEbJcBZuM7IdNakhRoKd0Cq3tiwS1gV5BkFxGNblAKLFbzojA3byim8pvRc6BZxOw5K4U6KJLM0wRW75svtedoh7/L5Ei7jrmRGXV5eHjNicaCWM+BZxNxv+ebsgGQXnGb0n4mfpMmPTwuaGB2Qk96sR0IZoy25qHhkIA8+j2TIZyQx11fnrI6gNq8Q+w/8XYvUhkLv8cuo3KW1fb0n90S6IXSh1ZDDgELtNgwd//Jx+5OrE9+wWcke5jZ++ogB6UuR52wUu82t81tDMigctA/61xkSrKKa1QsOYXbjmcSdOPO6axdl9XZ3318seRksa4q++nB+Op7fXl86v1Y8vVquLxyGfsFS/5FCZTwumhYETB/42C1WBkVcNNS3oju1rYulQe74AGNM8d2qPuNoYhMpfELJGYFkgJEQTe2usfGLvVzSgkTFw0RQNxYeoMxDxv/A/x1joUOo6UO5Hy7zRuqLVZTxw7LYbEeAJNVmCmFNzlNikzDP6zvZQer+Ins5Idu9KbMQUVQpVbilRJwwmvcCkHYWeTj7U05G422QHnXteDuRS7oaB8E7Dwv7IeySNyE1wAya5TWC5za8Pp/vJZJ9npUK5amlxncChJmaFQrFafFBSNof0XxTHsKcUXIx/llDZqYYiOzN/ohGf3zbaOaWV8+79iOffr7gYlQEmlQHXLFxyv6uOK0NFwLRSf+zTHlNnRUTIrBNVEQqGmlRG4JhNYrnpbkzhp9CoehZbQouW7Cng7Yi9H6c5uD7UcVwlBpQosIYhNiyUvfVItik8a7E6D+hT+e8wlH2Pw2Jzbic0/oOAxt/83Z26hM+Lz9d3USCDLTOXpbFRhr+XNQkuVIqsQqEB7a20qFRrAKwdwSlUsz7SB7KsiO1OPSiq/CEC32tuXnk+gfORt+DAgPmgFoPzEdm29gcbE00WOjFIx+FK43DBDGEn+A8R+MCAqhgsg7mZNSDTjtH209BOsjSS2/LUhth7dNi4DJqT1PWdxdX2Y1jqImhavDr1J2djCrh3Frs+gpNYzYyakU3owwXD9WPcqCnjeh77rcfSa/z/SUwE56kE4fc/EZzeIZj2jf2T2NgRaOLSgbXz9aZGe5hFvWZmcE64E6HBS7HBsRhgWiJ2B4ShOuVUWKe0t5kNXsoKlUluZo/Z3ovvF7kAFlrhAy8giE2uEjvBCTgBYBNpJ+pCx46A/jMc4ePMEYAewAJtGRy61bmV+RqDpX0G2VuID31B6g17I0S5YYAoTD4OQnQ9M+ZR3mr/6Chf0rq8pZYFQU4ARr0YMHpxJVgrJOGieqFYsXvv3PNUf18YPtb3Th7rduJYbz3V4C56b2mxnKtY4LrQpRg/asf40WlLN7VsLUaPurqi8Yp+5Z7n/IWXJA/6s8Y86K9JHHQeLYR/RNssnboEATnFUVKCXqXVh1lQftJZjf4cC0jhgOOLIW1Y4mvHOOogA5xNMZwYOJPNsg5Jc3aPCSGJtcffGx31fFComthTLvuKD6gIx/1KUBBJlUmSEHpnlmaz3IudKknF0RekiflFq/dLhuMtYXPcqBUM3i41LbGOdJV6/q2pDLsitaDhUleQv8OcbObzrSl783f0WtFG675kyWvnHwPDMOjrMBZiAwCW0puHGzw4x3WNvmrSV+l/ivXeUYQkuqqNgucVQTuNhk67Ud9oXPW6q1kfzGrkc9C/KlYpKzl2+tv8JlqQG6mHpl5CcximAMcW3xe4AbQMbtxkuWXEITwkGycsDjFXUXq4yh5ZgCXP8E7s7l5lhDv7/N+D1qtVLHa5K4od5Aa8YHvpersu6nN2fhJ3Pe1S255QbrUSMm/CYN/sZ1PzjD67ojGaILoCl7jP7lRGvKE4IQiNJv+DDITQ+d6LOxP10g1QDNMQy1STtRUvIDiTIppYkFdMltXLpViQbfOGAbPU0yXbs9GZR4BKO/kSqR17dPd9iRUNR48fHSoaqEtKJ4KrFYMSotQJ6J3fDRs4bK/vxVsb8O3RRnl7nMd5IFtetWVA6Y12y3sX7PFEuXsfxI6jONql4XZ5+CgPHzk89Cg7093Bo+TeHVryw2TJjWFLzu1iSRyDldOf5L8BExwFmPZ1bBcMs0feHyzboRu8GpI1r4R3Q2Ml5HBuNfqp+/qBnjg31tF43vRk2B6O+O1764x+GWMPkfjvP8KHhFi9d7IvQ4qO1MAvO4gdNj+xk3nfEZlXaAaHBbwPjy68S7uYgMAiq5Y1aA9KgEymuXqWmsj4gqMq+Ct3d2iYvyTDzI9vmN7xvY2e4lJeqigU+H/DciaS87XlpHRGAwbqS7fQSGUpwFrfeofBKkOG3FWiFolrJcQrIquirhLkUX3KBhlpjR9E3Ia4IDKkd+gFdGks+2v8x8ADY1WYnAXRi25+CkWEt2h5NthFfXHx5iVOqDRAPG1anWZJIqY5gVdUzCYcP8eIG1EmRhTpXCdjyEpBtbqKKomWHswWs362fQXH5acnpwO7+etEUq7qnlLIEPM/FDghbVqXaJ/5RVI6XGvOee7sjUtg8vA9E7TduJy8fJAN4JNF38pnhXCLxnTcgmFlNer2A4OAt8LF6p7+Dv9vmATeBjzNXmJKWFvtSPEjXEOjZ/VEROvJaP/9PiEU3Bj9neghhu+G1JuoqqBfssE5O9IeJmjq+DcmBUPuHkjW4EMUshoPnk6r2ypLaabHAP1KhZd4lKqqaMtZWnxF1gM5ABUiiw0Uo/aMmhMMtd5qGlk728yj73ri+OFagtDwuyOEhvSUQkbD54WSM35fcsaNJWcuZ4qivqcADTt9aFrUCthLpaVb1JUapoK2fD1ysWwo7QnS0KLGuoXWrM71vjC4Sx6bXHAG/zHdI8w2X2S2OS/19nOm1rezYfdtVv71Z1GGL2HwVmOikAVYf8TgaUva3tzNyNxZQ63VG8zcAcx9/vkbZ0NnjwOFzMDoFFphdCwNDEx+Ysjknkabypxe1wjg757+GjNpG7tr7zuYbF6CvegounRn51Au+eOsql68bzk8MiPgwWTHV6NPfWaHthZasVfYs//ujUGOlRmcaQncSgq4tzLcRVzCuN2Z7jYn+ortTrTRReOl91d7cSO7pz/PzH8jGvHP2TPebj2RoUVDTeflLbZsRQeR25pLUk+eo/XUWIfujbsctquGbJQtWBpwmGQdmbdVbmaLYS4I7bL59jGE5V62Yyy9qB9IF1gghQS3yh74Q4njY/CozY7G9T49vVZTsuX1hYW1Cmy7RvJwJA6HGoCXrMSTfjD4bf5g/JuNhDriMUXy+FSF5Z0DX1g7hiHzKNdthZGY/txY7tM+0MyzzKivo9YQ+1q3DVAb3hdpCmNIBiqR8U7tah86SFNmYbbhwruw9qLJw0dIyFoIHDuen81/tjpgreLlbM5TyoGwpiKwZSUgDnXurwEyUxRsx+DRm2pLJSevKlZB13klN+0Vyr33UvKWTn8ZqaUmvkvNafDxnY16Ic04nHYtNmoWzOD9k3Rf1aDcJHGKsEHduyxjZBxwTeETnuJcFdk1GOxQZHnFfIZIjEDqU/CIXQ1YtxlNQT3OvwYs6CJnaopLA1Da1IIHeBiW/DuGJTdCHPAzTHEjpNNg+Tsbba0RzCYiBWMcDhEJdWegZMQFkc0oLSSjtWjOHH1PdBgzbh9YnMAlJuT/+uTWazStYdrYIY/n6qBVGIppLzMijwztjIffhL5E9G6sC0k/k/1opt3D/4DuLo3wwrK4+V6jkc3Kqpb3ZnRP7uQsZe3RegM0luwRWYEq55sAQ4HiTamfqHO54qIodQt3cfyGWTYP66CMsjNYKOAdkI9hxcZgbQdAm9Sm685XKofrtaOl8qLrNaBo7+sqbKyAZo5rTX6UJ2lqpZk3qKfzdV0H6/h7Mpiwe0SZ+IsmaCpcbJlIcsZVQRdynlUzjLKmedxjsZHDKHDQRlLrKuj6ef5YWlP1CatwqJifVYCtN6smEZ2l01alXEJrqEkU6TzaUH8CiKNIumt0+/htu5YDdknK0AYQuNmkrKnmUNn4WCOXIAcGmXgHiltA3GbSOQ0fJA2yLqwRpbPS64BuUiBByDgzMKwQZJBr0OAD70PaPhawchegoTiL8enzqU5kXf+oTDS4KMZu0cUS90ZDDGSzogR4G92suKLk/yztgnfMLeIZVABIyAV+Acisgd4V05PfvHuHRvBX4v5g7318udWIFLEcAJAlv4Q9Ne6xCUmsV5AkVg6wRdLE4j7IJMrzAYhibEf4R2umUwxaXZO/fwJ+auYXb3hl3OxdjLfihpu9f0vxQJ2eqpPIFc8Httru1EnlyodeY6hyhfonlLkSUrXTfyusYXR2ZeqljOxqiR0VhtwnprcQL8Jj9px4ojMcwIgsmQk2uJgjO+IkjVMmh23FJXcG8L01rr8yQG84tDAQbwpwW/TvGM9kSBHDZLi41UfkjxNsZy2spkMTyKQikGZG+ExshKvTmFEZec+ZsDQg+qfs3js43XElksJUJn4TnSU/5zUsLQ0Wt3hVAGyLTuYKo2KZUzW0+ezMDYk9AVObu6Rli6UZDM/QiknK3ylWtjiVTrc6nurVbGgd/brAeV1dtfOlhwZNT9WhTQ94mGMeUWR0bG0viyZ0w6XLPysVzcA1MM6RJXRsMxlN670d65RexsQFgf9WKt1wOSBn+7lbgpl8MMejvZvPPam/GDBbdTjnwllwXTmzLph6Tia178qHifS6Va3oV5jVAEt6kxVW9vwd/zP+xxjpvCak6ElkOGB2HGS7dLxWiTyQO7RI/x+Mg6zdvl0GHCMe2UlkqbC/xihF1/y4a0MCKJH0WaiiVh0MCKKmATpyXJO/aeReza4fX88OpbbcDultlB1SkquiVaw4yiclU1byvWowBZUAnbUT+IbZrvvNhSWz63bcDl7MG0zxLNQWKJTnpue4f8KtuRzemtQAgC1cBe2ETBoNGhUBXGkoGJ7KjpzObE1hMXuFCpuSBUgvTmbDT9b7A9zGVpdEJBCUC34ofVa9OE/CZxxTPpvAipDHhbXMD4QGUiyatLz2jCSthueqXiBhWL221BXGqmCGfWKQK/PvWLp1WKrqsntfOp5U1RdzpbzVbwZQ7433W5Mtn7tr7IozC0BWdmvJytSoGuVYjao6lhqVqHvW1YkWQT0kDH7DwKCXDtUk+bDkpHs1YBl1a6oVVqnh6WJWexyF1f1qTJFwEHB7eNa76gbhDUd1ps7Qlh/av4AUmMAaTU9udhqZnYx+yCUloISI1OKZ2nd+zw4DIjhLUaFBAjSFr7GmnpjLeipwSlnWp6uYA6Woz+/RV9imFYGjqWIu/nPGkXQr1ZlttLKjQfi2KjmZhIwO2tbTXHugtcMS3x0kedZHr2NveEXg+30sSU154ogcTnYglGPOTNV7twy0dLgXu7NGpLhTrXmuHSvudE5eMnS1ZuObtQ8a2uAYgKREAJLvbhW8KcSCOOB9MLnXDSRz0npSV+f1sa7O2zjhw5TWvLHYDpMao1gsW7ckNs9woFI1OOM/YY5wY3Rdxbm/xA5V5M20TT/oOIfpPL9B1Ti7goToaROddX+1CdobEv/ERGs4uOKa+5QHfeVEVxkuZoKmqXnBI+/NGso9tJ/zhhZeKHPFmbA57V32qosufTH3u4NWMHNF6h9fvfTEoe5x97rDVjkdETD1nspltDz2xFmIog40HpVEGhfsHvgGuON7qWZqHSlyyglFh8MWRdyFaMSj2c4KRyzfQjQ3XGOv5OKXtZtx+U3h5gaw2pmtEiBFapE7pLVbBbcx6fZ+x1vEw+P4C/1pyjb8XK88P9H2GhUUf5+waoHuVFvG5p9niwV7ruovnLj2Ka/h36OVAmOueX/P4hXfJT1hIafMF8X27Ozmeyt1w9XEVvDkSruD5dGmqAeODbgZFms8q16iA8d+zb8D+I66sc/dtR+7No72xhlFQ2FIC8ZPSsFEGkpUHG6juwGZq2lfP/rI1z+pNznaja3NnXfrc/vd2I0zjoSlrJfL//3K0swtjbQ76dRcA3ovn2ByQBiTayVw6W8NljLXGWnH3ovFwdZB4mDvj9iXM1oVoME04UQlW3axMs+H5vwsqrts6tFAifze2aSC3B5khFyTUUIuERld5O7dRqTR7WzpNUV+gPYrXrIQhmz+4u1oIP2YBvKVb0zQQN45QgOp1Y4sPRd8woUtVJBA9ogvDukgX3L+7Xe8/CKzjZBbbZmbd6llrNb45amR7hK4c7n72NNqLmNYh6u9N5Wmaw5yVJbeHIwNMoIQDfFB/hbLSKG04uVV1J+KZ5tgvuYuTvgBMf7KaB7p2KKlJtPj4+vPPX0XDm8W5Na3x9QQfRodYf88SQJ3ZseVAILM5KMqGaywf0GCR0deXFvKpacXt2XRae7Ol5Q+dHRp87/O9NhWTr3sGm7aqhfMEQkvJFDlY7KlZTzPFDC8ZDK7PGj9OWCFQKbDm8RXrbuAq2SzGnH8oxcugnDWnqCGnA0efWwggmsp4P9i/4lr7/XgzQ4cty/bZQOXq1Kj10ab76f8aaDbr0RTPca2s62SlWirxGNAzURiEuBqljAQjnB4caKzltgrDlh3NpQcEMLzHeNnqRcn/eHIxJz6LyNQ9cO51ZNXnlxVLnIt2cFqMMs/uafall7J4jaW3W+JsuaWWAqEbTY9yo7CkUE6pG3rD8JNFIzV8weD8DD9+A7jKuOh7hH4rHxA9ztjFwyCkp8HtTtNZDoBSAEeFBzTKRXyZ4MTv/WGO9edBlKXo6e/zn8e5+RmWkZclzAFD3yGlQy3rKPKORRmob4pyVfj+Yb8xd1EaxPMyNZKJ8b4s6e1FoONKdkBDJm6pJIXdb37yGV8XydEu66x3meITr4LJCaSfAcmSqDcgZfYBvkz2npQUUALOSvpWUcy5D/GfA6wAYMUKtJEn0/RnpeLYFLLwTsAOOPAMsSrjBeIpy5lsaDjy6TfwBHZsKhZvqdDBBL/+i0dkTVN+3J49mqGuoOOCvriHAk1kiyjICh4nhktazYMnE5uVXTkmZxLTXRfJVZjHDYxJ+n0gTb/ECMlHIc0qZpBfgPFJa9K6AVl0O98YOAowDTmckrOy4IEwJMZkvVb/GeFTOoY1mtem/obcmT2gI6n8WyjzHE9DEKVdJX0FgKy0VHU0dFDCwmduA7DsHWO8ytRaKOZ4nLcAvF8tn/lZvqCwDRixDlYd5FLHOXDJQ6B5C+60zT8o7kRCDMyFaHfQO+3tYmPmux9PB23smPseYW7o+yhqefxCsocSc+All2VDQJck9JCNm1/2sikcUxwD9luufcnwMFh806wFL2ic3+VMxQs8eKiDhXlyfiIEvB6VezJZUN5IIklZLFtK8NmmAXmkOX3fqo4Oqip0MQEzRQiXwZqDjgCcBDwrDPkCw+cCiRqoLLhSbzE3SRBBtJvzq2tzetFs+JnctDe4UmUs1q/tNzqoPmGeoCw/HgjCTBcJVPMZCHeYmVhS1NpbdhV1bCzaUpVsmk0Y/TcjIpRSRFvl1aBkSdtj3Tm0aQqIEAXxzRJNoI8OavpusrVJDUNT5NEaHrg/UVQZ5sYviiNa6/XfVBomyY9Ino5PC9XxIFdBvctEShcBvVAksuhBY8MJSnRSeTX6Byyu4zGBMwWoSoHQznSmrzOg0XBIQQkIOtxXdfKSOVQlDMjbe1l4/x+sLKQ5jW/oinrF12czwaHArOcpadFT0eqNUrC97hKs47fVOAzttuWjNr6vF7JMAUrOxDaR05yz7RLeA6OAxYgXs37+bKeFF4QhZfhIizadElkxKKl1LDPzb1DKDaJPE3iMqYpoUuZZpN2eAo+ONd7q1ugi+5YOu8jLFh5rnj+yVM1rdNCq8SttU3+4Ykm9fpTjjAOxU8K56E03gDk5XVhOz/s+IX5M57g+rG4HYyUrsqgpuyWF1pdPAs299mKFDsWmgCPWWoeCvFh9Bb74dQTWtxLjXrZrs8vO6+0241ilhaG6IzIjul2hOrU4lRV0MpFSKNx6BihSPsQr22ct/HD6e4QUCzUSkR6x/U+wBm4oSWToGEbexDnFcqFcKseW+Cowv9SJDRpXhUkTdW67RL/+5BUdiVMAsOqEEm8NWllAWHi3szx35kIjkB+yxGwAtVXQgQm0ie0EaZJ0F0ALvXux+9OJfv4wY59LhexjH46MtdjU78GPeuDGGyfRqBijrj22bvtrn8Ro4i3V8A4oDm58/dlqJ4DXPm1kMVYaeuTU5NbNTF+OKyJYROjfqvd1rdVxXD2aXfxPrvzmo5YtPcWyGMIVr1WJvThnuIY9JpxxDE2MOf/jQP5hjCGnoazP/95Xmz1l41t9bVj62/YWV7jeB/uXDiXR7hX3UNq4zuP2/30PmHk9NIC3KeFddhnPfUkIqxd75DkaCzYRpcS7Ym2mJIbG4Djyff13DI0ayFY7Tk48Vtpha/kVK9scH/sdVzL4bBbYE6ls8HcNb90CwZfNMGTc9wvFSatIGeYbV+5/JlvefjkFLd6IFNz99oX/fB7/aqdFbIZ37byUL/gAYWzLVBUYvcRzHrTLrFIcAB3fEDAsmNsbTTL+N8F5akzbO1OaO3Xcryxf85nITV1+q+FS0BUeglQNV+HPRshXoEQFYzp8hg3EFwLV646rQQB+xolJeusuVGJ8xJSRxFC1MXqOgqJ9VCzbTnSbFseUg3zvf7eDhF4dT1KWkPdsFgthdUo3ZDgrc2Kj/AfZtgf+pkSKW6sDHYuieDLZbvI1BFHYk2dHvxy/4f7LlI1AX00bfPvbYvSd0inWWjcK/N6t8Bd0MtlMzmBMlQwL2bwb+e5czXu1uIkVnt4cAxrqJx7x17Gh/9DQA083bK3is7/bM7OzqOeAEsq1hixeAw0hIg0ExwF9h9PaxXj+aZmSYplFIAP1v3cB9DBxTwBPwVzRV7SC0oJmu3/n7n3gJOkKvf++1R1VXV1dVV3dXXOYbpndnKe3WUDLAu7sCBplRwVJJuQ4DUSFBUxoIig/gWv4hUzRgxcEX1VDIDXi0rQS/KKGMDsdZr/75yq6q7O3TM9A3547wvLzOzSz3POec7vPM/3hys8L4Oh6ma2jnhEl3BTF8u6xLMrky75PJIm+dyRgijDiFT0ewzl+QIs5GD4Qr9gxo3SNKSCsYJvEHDFChSPAm1fg1xDjvMGkA2Cdn0atyGv6JdQW5suavQ3UiRdQ3WNJgrzP+7dHLXHlCMRn2Lex9BO4BcCN6Bq1yT4oOM7j8gEg/RjwIEEU5dpTvF4aZGN5nUx5MHf4D/fA4uXI9nODzjFLDxxd+KCuhmPwTe6vu96bGUFG+TXRQsbljKv79Y9xn6gpANCdi4IK6NfWG6QtpeL3dfTxE2GeIsLr+kvaJXjrLMHbWQrOzhu4BLZlNvIB0Oa6b2IVkxVeaMvp+LQp6Wy6teClR991CZjXNJAxrjgLY1kjCssMga5LJP1BERm/yJEtar/S/WUweb0JpN2JWYAIGWHFpQHP9rPHoPOXt2MhvIx7trmoydjbkbvIBztDUEbTimkDJWHFJhgYlKA+Q/KDH4Q9A2PDPsCBmz37ugPnPG24xLwC6O2MfPm/tbaN6ZyONAJ7nwpRxvqOZmnbAHWy8ly8E4rB0/GyP23XD9aUQ6SNTVy7iP5bNvlFWYbeUV7t+ZXmGLzia9oEpnPt9yaj73aoVFfZiXi6d2z7DLTYbnPrKqcXu/InNNDIT23Akfmn22zsyjWMYv2cbq1zzzzKBhr1IjolL6otf3nltAXuL2XRu+T6xq972zG6HnVDCms7Haztw9+OzxwrVbvcn2r93K11VvvalP0q/4uNLvr66I9DXXRJQ0mDd3tin7OH4w0mAG8+EbXd9vYFS1ifVeZKDQBbCIKP/h0aGddlCJdvIsOk7fuPemorVV8SjYXL1B0yoUkH/RGQmqVnPLjlWXG8/vzMoo7vYwyY9NjmZqXEZna/7D9J4YcXkaHZea4UhJjVVj9hIwnApAlfFF98nwLr8KJjWlyXds0uZJw6tb6NBnv7udxA3U1ElS309YoaNsazWJs/WCYHu9vWnuw50jecjDqIfYoZWZFySokjP48kZAYS/3tIC/Rh0IMVMtpETWXz3ovaRHn9PD4cLoaZyWv38mcx9XphelH+vVK2ln8fq83X+pJdwcUZg1UQAOOuyiBOq57XSITuRL6FrnK7/p1T+LSjzR4I72i/ZXYdM3ZAJjqRtygDCBhLqVskSZOsT2X3m/UO91506S9h87sNm5H4wQw2WhGGA+3Q+ORW/qILi0R2q5jaOLOFXxp45jx6ya2DPmV/Na52a0FRSlsJVdYgQzFNKHHKHIN99q91YgE8snz6lfkLXpY4WmThx8N4UQOIz50Hc6g2ptynQW98d9pfBaXnIglm4IUksww1BGWaBzmrKXLAojbLXsPrg+i+Q7JFyWhJ//HJmjqS0NBB2npPhSXen4SJfEn/EN5iOa+cFzNMc7SeUdMHU63VtVesHyiNGpwZGTTlnBwiAbV4wjqj/y5OO4QRjLr+wxZ7ub8+EaGXdoylU5PbWHYpYMiRa3KXRrSc7wQSXvSApGDAX9Q4ZOjpcmE15uYJN9FIYH3Ek0T0GVDnTgQ2QQ+yFurkcUESzLESHuffYVl+3hGne3j2fWBvFT1yyBpwN0Uk5uihpeSzDN/4P4IYMQeTH+46JO9HrJ4StTYAa9gtqBLL396lU1Wq5zZqpmrPWfSZWROEUXs2yOtv/EUWqXJU9VXN1/9581A4//Qy+RsdU5ENPUJ+GFr+PEGlRyoUkL/X3SWe8LsxM3hoVvmdtGHH7ec1aijKk8v1EhqFYM2ggLveQRtF/0Y8WwMKoUoV64VZcGH2zku0SJIYwHpGjyGyRFPKAB9gd306b0dpCNR1SSveJukS0EtYN7nPYaUDp+hAeuEjx6OsUZJiaoz6JhUuZ/gpyx/Gq9ykSQ6V9EW8tc/aZiVC4p4nsPoQFqTgYMpo36nBko+aA8w0MFfeN6XI+rDv5bxeAubDwgfkrb8YfoiF5T8gkem9ulu/DehWcGvyJqsSeQRUZelIICvgodjLYK4iOH9Djg1L/gklIDvEcqVd2i6m5rIshGBH3BP8prrANerKNWuAfDeme4ewntXuJnvbq5fZptEykXqg03f/x0rl65Lx+7LoAFOeiwwJDYjYLhKj+V+Wwd8368j7X0kXEd7/6Y6vGFY9aYSQRLOlwNvG5oOsOYOa8kKY7NjgmMXvp48UKcj8zUZGa6KasBPmI5Mjqjx3/fPRk6vY/Kf2WDeIobHYABCzqznv/+ZdrCiYTCChgU0buTTIe5rrS5j2JkrF8Wjb4+Ga89CiRRFzprM2XJEE7DvZgB4+ROmng2E8yKKJWnF7zdNdEzGXTg0j6sKQki/kJ6YVSRhUbDnMsz9t9y4/TYGsSuxnzwK0IcWz7u92JTiUMKFYTy6BBKGGpTdqXgwpgrbKy/9aBoD5BvLqIsn5sJDWwJ1B2ZjoG4g32w8/S6hNAy1sGXKRlJvRKuirxwjCz7MWHC8P1HQAbQDjYGQs/xJA3uAFkn4Kl8Nj2B1qmfkeJJI5Qwg79RCJuLYTRuiQZqg1JlnHuTuAgpjEc7ygFIzUcGiUoOgsIiuzfZQakhZ0qoforldEtr2qhRqoP0OzdF6HwRqvUqgTlACNfXhunkAj9Fscl+L5CiBmpLUYqNjU2kLQJ0EXX/5Y1UAdVYn4S0vPWWlr9PYqTLP/Ij7FT7f/dF1/0G0djjLBPpRFspWrvZS8ZE2yGp8pI49h3Qkr9axqLeST6hzm+bUxqKeI/HSRLiX2u8Och+FWbd5v6rbeD7Wgd/pRFUL5NtmleBHGR9RKEiQFYBDiVbbDCsAK29gcOvLMJhU3WlS2YTb7Keythp0Szmpqwc3EjtvdMKr38xi9xj3S97FYveBVceuFTapCr+wyUlG69hFWmHEVx06jlRfFysKhSlxQ1HI9g6a0neqIUvlU7WQ5WQ7YpoFF+8/ZMtP1gGVQkGRhc7kKcUYT4m8igYsYwaMI6dUAyaEaLxe64zXe1m8KBJQQbyuoIPfqwcCGrPVee0xkuYoqAfzwEt2S5X9HCUVbdzPVoZhtVOA1DFVC/bVG2HGXy2Z5DUg4KZmJvnHK4e0BwLeZrdvT70vYug5K8SPoP3y5NOCTEADrgo5IozH08Wrk9FQCYc8fQeAwzOak0KoUbijHNRVvaikS+CGAXvm8SXU/pnlUOItaDn3Q54DABQoMrGUXPTJHpVtEXhH8pQVI8nMSmgrIxJmQzmFt0xKWJX85lTaNTUM67nIviSUS/zynlZAc1pJPAKukxcJ8AowIb++2iUr9L6RDi8MDmW9+i35DT3utG6y/NRgoNc/7nf5v7ozAftrzrV90fLTqyZh0738oWpq3LPOqdGDPXyDNryF0ObPbtDs9UyVynvqDOSnlqbqDOR37901Q07tj7K9tllT+bd2XvJvd4jDh/vTMT+pEriHoBAPWQRumN2fWiNwj+Ca8htk0H7MNud9zgwia55B3RCBX7QTIcSuBn2nwYXVNMh12zGe6M4MpIEVqOGAI6xD+Wgr/a6s6wJ5S11Y93Z0Fbm48o7O6ECm5P2SNka49oXO+nHXHfT9rQ7TMi1abey9olrI2oWaZzIg9UJIkVY4mPAH65EtaOrk+6K27FhlanTcIcpRPZCq3Mm4MPcwLsyHGRcmAxUKL66U5IKeXxLCrF7QZLlEMMFkslwSmbjFcplQMWIOCeRJuh80p82tbXaDy+vS5qjGtPkqLAxDhZfCskjGADzkjRjH6kh0FqBYHMfoYgUq4YzrKIrjcgLaTf59R0B7VUJsGKql8iLUiNIaq4X7mdh2ow22Xa1i2z/FCxKdtdVljg7hGpoeM4dw+co1a6Ia1kHd/8YLvpDFdP9+M9N9/P+h+akKdT/aCXUXDrlqV+VfiemzB6kbEgzsZvgYBnZfiIDTcSyL0cMK97I1MmHq75ZikUcnIpyaTTRhyb4OMDk5WoeetNsZq/BJcghJjKejM2GMQ1KBArW1R11MkQ+TVCHL9AkPyA6Va6O4qhJeArGG7J3JA72CiCWmJ46eJP/n4Ey+7c7X7Sp6uCpp8j1vxM+jYkQmHSZf5CLprC/kQ7M3pIhgwI3u+kA4LBzvTYlQLfwChmnCngJN/Ss4Tw0oSV3NGU+SsQHu5p7insZN99quyKxJc33QhRIyhR4LA8A2S9qDl2f8FFbrLm3mWdJaw9Gss9OCZ0m0+yXiaKWnCK4pUrIXHz/TngQ5VI6PHxny5dJRNK/RXQSjpclkhCdfDk+E6HJAG+dIRHBXPigYrJ/InVB85R1n7Dk4vkEPSQJt5fRsmFuKUBrklo3lDRNmH72OPnrm1UHeXvmVlo7RFw+ZOWNe2gFfhn9GFqJQ8PlOJYFo0kuFIY+UM9s2KYknGDV4idmlx+OhEK0/9LKPfChVziyOpcWaahFPRt1U/QpSLzsJQWKxeWDdY7M6UOfw0HB84qjVhmcETy8Iz9YtSxkHoeNpB6zTL/M2rHOckDPaRmiXM0KXtI5QIptsiFBgA5hkT9RkinOcHdKav8bqvMcKz3+uW3is7arKaDB7qnHG5OldA785u2ZSzs1mYW4zbyMfzC7ZURxHebs9oCNubvRQY5UxHFvcZBE4lz9Lf4IUS4R48j1Hr7Wqk8rNMKKHWyXtWXRDAQkrhM9Ozk+XJL48VubRe61oIJzj5wnRbDF4fOVuD16/hIDciT+3cUWrUsUQWuWfWihAh/SEWus1CloJd2SQseh34hzzJczua3pQCiWN5cGPwB1U0PN1XQ95YD5YzC82BJC19aH4MyMYLdkPzXVrs0d0S72Y1ZGqO3nqBJzDuPFJck9oKBQIEs7QQwU1QE7Y7/X7omGPubloKY2crRayUR6TuTm/PL64MWzCdBPtGC3bzr3p5ZVMFThgwHWQPDE3bkpV00BxtiOtwgbXnyyFXzg1ihikdT2OWyNPRaKgwRj6GA7RQqkArvmAh5DKBU6ewG6lSOErw1SQikRRIiEEhzGYQJlNiD/IwvRS7Ka3dcdDTnJFe8WapR4XWeGSHZhA1H7bLQ3Hw+MbCrIvl4nSd2NGoup/351ZpGt26z5Ly7cNRh76YNtVus1epRAdfecSFUATDIJzXVapVqC0SEZ6nWwgvTpM619Vz2TN1olCmgmCsHbuf3d9c932br5/c7ThRrVopiYprdsGvkfetvdkRw+gU9x5a5O4U6o15E0feOQBU6Z4FFTXZsfe7VB09qSnao5qceg5iZqeYzuqHetQgyyVyEKD3GtlxKXrWGx1lHe6MnsHEOOFzdE+QL7tK+FNzgie0zqCkXi0cTVnsYPfP7qU9XnSG6emltKynF4C1hfL1QOwL+6uRAzigNVBnUti5z6DOarVwzItC545CtakbzDUB6Dz23/Y1HQWracc3lR1OHq/FyKiZHcUhCP2Ew591jYfwy1c5wIrwhYZ/Yq8zkHR/DmlaIYFCtFM61wkmRQZmbapMWB+y7yzMcAU8WBh5gNbgIZKUdRsLuM1O2AfJZ4I3mXQtrYf/I/VCGYn8eAMwHYMfUDu/YgnjEFJMEDIh4DSqnI1lUwgAqwmo+EUNwwrxBNTi9BU7m7TInAP/ZPizR1SgIZbNM59z/BYSdyV3KR5Y4WS9qvHo7NoSwrMRLiNvCRoOGgEIaBkhzZEbvsfrVRAZ5rfNzI5EWBdOg/wCYA8T0T38/9iMW2uIjaGqxwUGpo5jH7ZOlr1Bc2S0VgDAeuFq0asToVDJwHqsj7BnlKVYYFJ3freIRF+QB3bhzAj1tw8dAlwnimvh+I8H2M4T4A6hlSMCASL2YTEzB/5piboCAYnEPUftNLnsEBm2rNADwwUAq1ZoOVtaSp7hIXEaNAfpG4Tju4jJezlOzYgJTVnAxL5oEfNo83F76YYUJ8R8qsypvd9VJZLwNzxxRhGhA2Oz0whmkExKuY+j4l4PkvEwzxF5VOeOADOVXDoPjVw6IvjCxEbHPrGKjh0kYJDl5boXiL5QOozIDE5m5ZUckRd19K+9V1Lbs8x+NaT6nqW2O7xBOoYP95/wBZdsgC880umLscqZoqOYbBPq3Z2buSsbQUEIChX1EFqO5m1N3KIwAB5twL4WnsSLATDrHGGjiDyDYQFygCnY2Dh82twXrSy8JHpUCBpzVWBmSAmEngSV0JDhlmbB4fCbveNalIK0D0dXXdhgCS/MJEPgRjpx3PQliKrej7s2JROrW1Kw9xHcWmRZWRILK05ScKsQPoY/T09oxMl9rMlIaobCZIZm5vAf+R4iEqOwMym9EDUTTteRN3/EjnA9n9NjsWMoMQuRe6h8RGK+I0mErWtiBJ+Z+dnYfeeSVndNtCHa5yGqt072z1+D5Ch1/Vi19sYBhjvYXWx4lYSKGBoQuGlGiK4gZ1G2qoeVlmODo16wbeKR6xxFBceIaB7VAPI1eKXrY/fFxri95/V+HlmQcYjhzZDgum2wp3qUEP+2mBdgn9gziXLdSRgQnvh0TqqxFUNzCE3ucGP7hw7tPF0nG8VWAk6q2wFNmIGVja8Ej3QgQeOh8yNAXzgCLpvucq3a0rJsQ6lxINTBb1QG53030PeeAD+DaKtoTGLbhdxOOEycPsv0LrrBWjvJjovsyrjEzNhumULHOcp8ilMsbN01q4qk+Bn2LlSf2jZuVJqoEJDM25OBe5LqzNGIaFxoymNwvVp9EVciiVq5ifJPuHhaDqAAVs8qg6FlJ0j5JzayVSXQ+6O+dGPW8pVOBKQSRGaSZF4pDmTsPY5f8Yj0IcCNAdHgjSRSBCbNfGoOTUk+/FE76F5ZNA8ut+ZKOWNuIK3SBUbFf0XmJJfatXptEin0PyiqR/bkj7vkPQ1szl0ku7GTCjDDSsk0m+exTg5Rb/N9oSEBuMYqCUTCX0jtCnBr41MTIU+OnHohD8D8mjQ7Edkhfj1JFMuMMHfHZLlVCg7sv+O3ROeEH4w+4BBUEvKQ/sNLbxgYXr5973AoFV6Rpgs6J8JIfqBolR2y0GteOjwTrsvkTMbE/EaQO/gbrPlhoO1Y8aQAjombPBD4B/Wgvmc2h6tMZ8TFvOZvRDweVyNjqUd10s25mYfOti61AH4bK0liQ5N0NWJNcDbtdVCtX9xDPLIqm5SdGleztzQRNrPdi8C0B76nAtNhWdPAf73Q5bsr3ht1R99b3pCiVR+vborlXfLrh0BfcfBO06g3YelqAb2lbDbJj4bdcTnnMImMQ4WkNo78XAn0H0knODNB4EgWkvp4j+3/5txDdWNsB3kejU2VbDFVv0xCyunfbc5U78yoA+b/HLF3O+H2pyj5Lsr+dxvXgHqu9WpaTqBAdrNQZG4bV2h3ZPWa2jD64JozhPSb8fXs1bGzXYp68gSvK2aEjfuyOtF8H45paXNxsm99Qp25Zf+jB8StsLxmGX5hjtTSLsBmg/zUzmvSjkdQ2Hv5v339Qcmpsb8+R35WBLQ0e4HoJYMdIF543erwbwPiM9GAL6tatm049HNR8xWSDzRKr6EYUhmtU+Fb8nUJx9ha/cQU6punCLHRFoPG+9cK5l5ANsA34NSfapTPv5CDzvy9S0V5kMHtD94uyrVwXr3sNmOO/Z0C3Ox31S3i+NabxcBPHQ1bheVd3V3D3ucZcJm+NBcZ07ILPV07FJCmTWhuPqQO8ZlGBd3Gzlsw+7TNvUQ18UT9i/biuI5LaL5yYZo/ocjmsVtp9VFc9P+2xHNg3aQtzcqk2eWZtLoct7WMWrbiJKcHZmaj4tifB6tgCvY3is3+jQJXEcNDfBYym66ViPgM/KMu38xLZD65u6TlakP9FuHrWtOtDd0P/lbH2z+g+oEiC4X2O/RCyy7engPPHJPwLoCR3rC+/eF7ydfwAjfECadWusRG2t6RFhntw3zqlvphfrPVtv9eNsXXDshNb+TYu1XHRriCHfLfOjRdmHH6sPBfa4W4obgL5/QOlTpXBgoSStUwzvJ71f26ZftGMLVizu1Oca3tQvPtXZ4PojwuFlJlOCDrh0A5v6H6y4WIG5V0dlGTPp6lZ3A/Jw181mgxkzgq1P15gZbpMGx6D5WOwXdZAt1m7LgkAN06jBfF300C25ekUTk3f+w3XZIyXFGETr8acF0uhBT02iGpXSF72FGUwt7Q+Njw34HV8EoFoshfezk0BjCmwyWQ5jJDAZ8nqgvi14y6jI0BpqShPk3HtkAuYClA4ceXakc1GSqHtGIg3ysx5l4gFeSPhQkOxm+qYpuxb1dDaEHzRPTtRQlL5wvKTAt86jJOAabbeZCxOvHW6imRn/FIS3CvrTPBJ0my6gZJZ0ay1lHJ2WLoxijGcS/FnQEzWZgk0kYJNX6CycilX8mpkwDD4gIP3UdCi+AmoiApBm2Rvf7FhEWqYLQ3tHjegUuiH5teHwydPiHj9CoVkBdwphakKAH4TtIZqhAPzuoBR45ZWSH992+c8JjGH6O1Rei5El4jvjgYdPLTzlcPoo1l4+rqcvHZWj5Q+NKkC23oBacnJ02TuUS+aKpDNh9glK9MjAblFKZBAovvvL2jqYfv8A5+jQjEd8wmBulqQykSCthoErUnRtmMLfZxSh7tWvN1MeExUcHdZv8Ult14HM1pSEU3/28Q9Lbr94p6MP5cAtyPtwuVnaJfDgBOSCdz9S0AMrdJ+bsNJUUvsrqHCmebGDjBzj74m+G6SX0KXsQ5V/3mzxpHRkzMOzhnG7D0YGF6P96ucIf3iIyKgsMr+X0+XM2I3orC1Hl/Z1u72SEyIlkrBqcSFilsSEMl2ItpcesGN1AxxQGcSvr0BjIJq97bgw01ne1vXwNugNza7Y2Kz9obhGkFE+VOvW17hAkl3RZrr+gLFE8fby1X3u2Zo+hwYk30TrDofpXs3Inw6E+XjkGKdzkPSEl/sDC3NhJBQEwSfSmBGA+dAdCHrUXfR+PGyuQbW5l/4DxDH9cp9ZDeArHuqfDsqxyfYSt9xLbk2/rFQw4gH1B6m01Gz2IOsfU9QT+sJkQSNTM/gPaFY7sYQU/31Z1pupVnT+3U3VayDYPr2QTGGm/oCt3dFZ03MyEiqbCgut1ro9Sur3Qf1sgWbe8IJ0aEA/qqzGwcsQ65gb5UZs2xNE+GwbJU4POkHe1bUG0y+uLgdoeRE0Qta63pMv1lv61zjX2J82La2l70dfl2lref1gfe3jNDvSfm9fRxHjKG7Uuoxdbl9FMOu68jKYnUmr02x3Ocrq2f46r0tMgGp2I1X1NM9FoIHcmq5UR3cGFMvzHnBGaI40dpFsa+zrPHlQJ/oBezoXRXOb1RONxLyfmdvzb7W+tRgTn2S8aZdozaq2eGVnOLJEbqhE7unXE/EagKWJbmFMYnPCkagBQHMqVexyNo/A9pI2jM898H1wIEWZXl9UqK4lN7w4XW2GL6mYA6VCGDS3CjK4F7d6HLDJgyOJsdI72DQg2DMS2DmueDKV3XPInRaMKwBAa9ROxQnRbR4SRx6yAX2UTjDAoKFHvTpnTIeF6lSJOkxlCh1JoNirRVICpeh6m6qVNVY9cQcUAQw9wpvgS15VcCkLPp7lEoUEPwCs1flOKMBL+wO0zLvCKIZkwD3KWL+qDVxHg8ZIp4BHubF8qFcOsqKGHJ6PCoTftXpaD2L+KIC38F7o+t6Fz6yo6Jc/Ntpycbm7Qrc1NtyLmsAnqRl5Oadrq3rRCOA9ildWbybA5WCCfajv/PLR/XT9u0Tn9jEEVOvz85xohJ+ck5CCzKCFnmpDdFGlPOTiCj7fs7NBCia0i66XF/13svo7yw5pppv23lHDwpab+26EipeI8WrtQXqyUlPBQlYmTYEycf2oYgPEobjgwDpVLOkzilsIqaKV+HUbfYDOU3RYH5YcIQQkky7e6Pt1zmbk6JMZ0DVmAr1ycb4hDL/DpvXWl5R3NpSWc8A5dNfZIt9FFiuiIWFrP0Igt/9UuJ4fqy8lnnOVkF+70b/oFW/zLDKtHZVEde/5ofUyXb+3MNzHZR79FyPd3/dsAWFX9UYS3Md18qUv8V88qeVNpm4MdvLkrO1g0wmFZCym/6BTv/iEklX37hAULssTk3Avrg3z2aIuF+xBcGXkUDke7LkHfa3PhsKZLtIk2e+jM0RcdcMCFR8/OHn3hAQdcdPTMyatefMFOwXhpfmFnsbhjLpud21Es7lzIX9zA+iBvHvTK+m4DPYTyuB+AsxRhotyX8CwAAT+Esxv6pTmMYFUP9IOnHsHWGzytH8xPnlVzNXhIAZ+4YLpq1jxGaZ1QBtyhKOE2h1LJ9N8rTg83N4iHzf5wkTrPofrAG8NSyXzWkqZTXNqcE82gaFkyyNU4X9IeH16QlAgcWLRCIrQYPwkWrSgffJlcWrFLDWBaEyl4JWokU8rj1BeQnjC1VHxkI8YH8NCE75fokyDMSwOTAZugQ7GMvpCJZaz59xGzOzVEZKEymvAXWEUGsATPA+DsjuH7XnLJ6J6D94zOUgqCoEQgmOlm5HlajrB3p1vQuFjE6AtGBgJ+peiR2IZ3CytaFDA+YPJHeY082wb5+PaE2UaelDGzkGjsI8eyLAWBMIYP507wIvDHuwWVU0Sm6fV1qIOij01H7iYnYdHNP/M7/iRwnw8CffRjrtvNhyBTSiuL7N3GpkTU1tY2agWI8Q9clCJVu1O2xuZRt4u2aVEnu0AKim00CxTrRk7aQvtpCbuZX1ikVZFIq3/Q4yJcTPfSKjzpVeFCOZeYOWXWmPDJTAh3u8WoPz4bh5qmBwFJCQBoOZsI5GmZU9BPYdFNjCX9qbe19BO0SY7Wkwd3DKN8U0KBxfiucaIbXRw+7Y5JXDhqcJwy7OM0TGsQ8jMpqasJmP6wnMIFwxME+S1N3sfrlOoGeog5BsFOO/rH1zVaHPFuf7o8lJXod5D/paaDqFnrTQdDYYM9kGB2aTiM1oz/MYngMGS1fa4sjnRLTD+rkJWYcj4T+q5UWW48xh/P9oKX4TL+xQHmBundfc7OinnnIFI9KLy4dilReai9Pd2uanmcZ4NFAd2v0pRgY0Xpqq0HrCBDeMVmCfG5NUqIiqeLhd1vj7dQgmxm6OD6maEXcbVEECONeSAgDx5hewQVbj/kutN1f8+eLgPbS/raIXoptvlWKXNWDwPf5N8HkFYP9r6HfK9r216iOam6F+lPDyDrpL42mMrbOpbx5PXNiTf6zEP885F4tCK8EvbQt7bAY68mxST2D0t9JVdTmUhaZdLzm1DaX1l52rCUeajnlLmqkUhX2dycIU215ZUrTIjrWCrw/aXCTfV1J7m4Mfa8awIv+EEgyg5A0+eHIFxZlSetOht421bhafG2a4XnGLp0Jfgu0l9GGIEms6hk7HvpdHPK+nLbQoz9JMs4ZK427WxXnKgX8S+sLYmWnHimILdZtaZXlhSfVW1GZyINtebjJJZO2qUm3NSxzcI2UYA5mEZOowHUIO5FMNK5D+2jFiKKL+ZBq6yuK3FPVNqHeIGR9ys+9/JjAMSJ9JrBqhOUmZDEwAkil9uFJS9Vq8pPtawqKwfGAvgq8mP0l1U24MujMxiRdYMoMhp+8pduWYzMoYUIKLHZCLcEvj10Us4T2TH+8e9rQwWAvTHhPD4BOQwVZWp2Zjb1ZVZRiu7dZJM35EXZkHvmYUyq8wAQvhmPud+gZQPvWHNaVY2vrVs8uxYddwnn0nWMKLOWpBXNKButGzfqqg68/ELuD7Mfs0QOVFXFp9prcAdN8R3+lOpYxPgCVY0NFYbiTQuZO7A2ekzveX3OHhum5ubbsKVd6XE2So/lO8QgViaRsLjj3JPmyjQXpft8NeejP9expq0mMWtVf9ixqisHVueLtam5Gb9KLqubMH559wnj5deaqt11tAbB5+BHDSKksnYNwk3TP/01Kmu3Ymv7Qe6veO7f5bqa2ZRM8lXuPpo3luZwOR+mvqht4ftlTKCBKkkb1FCB8NYldbPFk7a2ANxRy2LHO2qoulVwre+U3MulRCoBPn/Y5PND2izmTXOJVpB+kd0Fyf34mDVPvBzFwDH6pHEPXYqfBHxS61voOEnmM4K7egn9ZKHxEpnDT503I6hGsozcb+768WIiMR7XnPj+T1fx/ZnaQHE0vID+SbJv9SIqwDzFG5bNi2gvV9H2F0iqvT3O2MKUE//5VV4SwuY/9IT6L/WBixda3hC4lZ7Jp7Ij+dJe4f8PVimi9DbQgSRfGW1xQbitzcn8pS4n8xfZyXwvMwe4wGkOYLnT18wB/lWHmn9BA2r+s04C7fk566i+ih3VH1VZCjzMBpcHmQLGwB0D1iQFvle9Ay7/raWJwO+exdBXrqu9p7wVQA2ny0AaT220S++dHUN/ZZ3LgB36t7rdtdDfzz3DXAfe5Pqy6weDCf2qrQv69B4IRUwBYZCJcW/VzGBqxWYGXJEVDT14EgjLN1vZU8udO9vkzie75M4nzNw5qy+bA3JIzarg9R2tCi6I0d/z0+x3fr/qEpFC93F/QAptdJ0Nnekrricx5uBaWpkZdQlt1CIVmZF5dPaTNVMTOKuXKbqOBnvO7BEwcw6RB+KY7ztla+WsFGb/IPSZcBkittSs7v647Vb9mga36ouvbnSrfrPtVn0z4qBHRyPxkGbEmXkc/Z8ihCIR2sF+jBdm0V4vQEpfFby73+FM65Fuaa0aQYMWwZEYEvtQNQSvbX+K3uR6S0v84Zc/3rytndiXl/XF3qVtS0oob75t+EFqDGczuXB8FAM0+GiModwE3k+AUwA7W72oqHhAMjlTivV+mbUr50IeLyY3mHo+2d2j9UZmYW5+ztoXX8aOxLea++KDKKrokfhWdDreM5B9kWi8E/O0SA/IaJXzxL6hgfSEbyhX/4k822dl5adKNJnRwyAhVYlO/pihS0N5PRsMjGXZP8TGog6ok6HKIYV9W0BMjobBg5FDDij7s3CmnuJPBjHVlAJf3YY5ES0c925cSiwmojMc+4fiQUNVoNO+GYMzfDHdnzbAH5FDmxL0n1Pky6spugRk2L0UK2QZ537Dde9gcgw27U7XT8t0Dl9jwuKo3RntjLPEt5Wdsw15RccL6RMubam0kX+rTbW3TIkOp9BfcR6/GkgD28Vz7/cPFROC2xfN+o0QMws9/8hp7rz+T1pnTv2QeYJunc5kprcyT9DVnr6vmkxWLUV9mCSE9ueP+fw+Nw8FMKIKRC3GSuMx7HnjsIbq6+hFGl3K0uj9auU81Yf3TpXe9jDKz3w+/syHod1QM8L3Ur11Rbob2EFSmN3Gl7p4CYQdzgMLw4Q2kLX0FaAHPAVvtJXhbrdlOL9fhwznRlNcCxnuAcaft2Q4GKp6c1Ruk+JDshwyVBwC1EZghNkI+Ko2AqbdAC7dCv3UoqJqROkpS8dHA9XxUX75vpgHwl69MkcdKS5rocx9puUl+5KjrjmKXs6/UTMOuKfZOGDmNKfLwGOVH6ogH5kuAjvqXQTes+vxxDR3MHELTKubnU19parV7UO1OsHS6gTXVtfprnfhwf/ORrUu2o9U14PKxtdrdwu0E84+i5YWato7kBz40XZ7BnYPnZ5QtgAE8MoW96LQQbHbl+zbu1x3bE+C24exRwAW5/WYz3wRfQTMOHoMCcUAPmMlkw1I6CmFmoUtJ6InKZUKSotXgpaqCx63nyeVje01u5t7FuyWD+iotpHTqRiPViBTv7uZeELeNM4Zqr6dwbQ8t2FJeVCBdBVnDkS8vFB5HTtzULa4vSJIg2TDll1bRrc6pTuaMA/ykyxhroBzyH2uR1eTMMYqK5p1yqXtZHvPubQ0oBrn5c+ZZJsbVMFzU11avrLntPxsQ1rmZzfNFurSks4yJ+Bt8lvXmaCt4sxarLMnwexXUayZk8BYYW7Ysp4xL5YLDuNC6AwO30NMAkQdtubDkXAUPc+RRVL9ddsFsVBu8kCs/1Fpwt2BoUuHr8ny3XjqqbqaCBtfuRELGJ9I1G2WBrzgduumPeF5tq+hL6dfQk7HPHjEy+TmRGnEf4YSg9pf2nckWKgoezQ1FrEa1MJCzKfpp4SK6EzAJ2XaHYoGft75+HlZqy3tkncj9nLNGQWMbsw8U2sUQi6QvZ4ggMcIXEp7hHWZ4SNlG6Nta4gWQqQbtVGEJTKKjdezpnW3/auGZnocIjfT2Yzvdy1/xkHbTdgT8NP/xMgA3owMu/OyGhxEjsbO8YnOp7glq08Mu0aUPhiYq5+bXZhzfvR4HohYwbBpxzRkNJ4hMKijbUHXwFyzAcIeZ7TfHZrBGjZj1+azprFT4l6vxxv1UeIIAizOLI2rdfEl7KuYayXTaPE+pBtngFtBNp491hqGPbN31pPwaX5yTi9z2+R2dDp48xosk1+JJwZdEH1WQLyKv6ShYSQ3zIyIYVOJxPH7LxTKSsPXCCRXyjJcclb2YDdjL1nYYAq0lmGMbKezge0WQz+cX3Sb7WaDQI9ayXCz66vPtXTguyHLnwOJ8K0eWObPahZUbh6dT8pCfGHKwhEBeo5/K9HZFRypos6ygGIX/+k6Dc0fP68DL+LUZl4hw6aZXVu6W1GkoHm8oNNLaScEo9FDhjiS0M4s0ldiOn6Yg9eIHXTymFF9AmM+fDvg21hYoMQ3wr2bVhvt1vgXe8gepKYumqBllnObZivjPacrxkjoj/KyH1XFO4Kmwi6xrSF/hAsMJUiiPd6Ru6GWTclcoimbWJb6lbjvxdX8q/ysmrpntE7dVD7JUrfuJ7GU+hWQghKGQz7s+tWKoIJdkI8WarluJp2sc3KtjDp48PN2h9rn38wL64CD5K51zbWN3ZmEYb0DaRIT6lEHkfAHdqKg2wL/qTTjMg0Zl/MrUd8htYz7K/tFzRdR97TKODcxooaZcc6fxPph7ucBvnEdiOr0GtbvsKqeNc3KNmNAVC1jsM2zZ9MXi8QCRLg/rRa1lW2htP1PG13tis66mvs4NegzpbVQFxDXZ9qBuK6yQVzvRrZNWlLacUxKu4B2rIGnhDR7GFfj19ApJBIpzLIrQP09gUaar790zNVfE4TIzHS776y/rnCzjVcMvj1+aRRsCchiWnB77fYAS3R7nXpkwXz5MG8dyt4jHev7ssr73G41uFB3t6DfeWLzas5PF3XHan7JDgeqacKJahrac8A28j5mmlJ3UyA8DBuChowbx/32bYGG2rorHLDPrpbfowzrzu9gIlz1Wyr7tWE6mRPL9yBw/3SNug7Hcw1Fr/dW7pd64v2ssLBYWPnmf34vVwAu0Q0MdMCbR1ewxS+NV+ZXtsU/0O1a8LlORCFyZt9FBKnct7Iqwm1xCv7pOgI6+edcf6B9yYNCDzE5/bmXVQesAaKIOyiwoRDrDKcaW9ccvLJ/stHlXhi8tEvKF6xvUv6Ep6ap2yHmf8j14Go5Sr3Aj8i6b26roy0d3p2QxGXWNePG+nCbuLYtXols7bugJZW/rKyiFdgdiu5+Jdfz0OP9HdcTPQ8EmSemWLe52Z4iTkYev955xQ+I/cRN02PV663b00SxkbgXX9ccO6QrJCrcFRL1CXr4Kj7Z2ugkj7ce6LeO52/l7d35Ut9jCTppJair1AcFqMSUPfqrDeSfPDOwXO/MJC/qDxNEjvEX00bIGwrHtOUfO+hAZCh78CF7POuaeQ/2Rxa6g/OGg7GgR+I4dphSqhAG7Mk563eMivDeeoT7PR9hAJG3YSj6B/Qo7X3gsfH9s8/7fam7xVapvYdXLwg7gz51Fs2nTlz8T+xhVwMEid7o1RWLAiY1ua3lUuWmj7S2++qOtztEzBSz5iMn1Qq60u6405kMwB4/A/U6QrmQIAd10RGkOievq1s4ec23Ngj7Zsc9i8M7KtlYHZDZ8Mx/cb/mnsGAzEsoCMNsqJktWOMtzn6cnggMpEc8E33DaIlWeBd0eeKJb47aXTZA2dFhN6kdWqEMknM9WqHcmdNUGU94jBBVwK3BFz0UZPSEV1xy1DuPskZWrD4ax7RK6xG35TuagU3H1gOb3kmBTdwC0pynky2LO4e+4ZxsORXvkXmgMLahnD7M9ROEYDUQC/yfFMHbko2wEDSGRcAmAbgFYrCZltLWareHl7Bch6HFidhDrPOkvLTIqKSW7mOyS0BUGC4XJYvlzp6paMlu7x34TUPsD2y2RDNWCidyv14R58LCXCw/gqd5fBkCruQLeaV4aFGjbezAawmqJzQcDk4aWPZRSUtosemQxwv1k/1oWY7Ek9oZvlFV5tFwhtvkbVpBRlnkiadi07H3hkZDESr1sHICTo1gmOA3QO1JT8HvtINh7NcNhjEUFLTUVMlEYbyXU/wBSZ3SpIjAmqvx4u7BOxX6NURZ8LJLG6PbaegPS2VjGzaMxY3FAJAr2CI9ya1JZUhWeI8Cs5v0hARAHJ7y8cCFWk+fCeR3FIqbo2H2co5VPAq2xl6ML+90vZy6YhBHMztn0mfoS9YChWEgLmbvrd04QMuKalt7MTxnvjFEeodq0GKijpIgFdvPOZPv+uLqzyKT0UjKJKLL2kz04e+KIOCrUsivKxLO/CEfLE/RsXDX/CbcppLarx9FD5keFXw39sbNqBtSjrYfZz6MYvcycbkwlPN44cGm4/UOiz7oS6tY/jwZLZ/jH/fiogs/iIh/+KyeYBgwzUgUC/VjyIc5Z5a3OWeWWfAe44/AFrzTda7r+sEEb8DUi9UFrfL0IMkW/Qat8qYuwIr/ucwJrHh1/Qjq+U5gBWJVfuY+/hgstANcb6nHR9ujI1vbzRCV7REi+i/qXuzEbuEuN0abnZ2OcC9h37W8s+uYAvWrkrvNHvmwBQ175CMM4YncWtkfG1e8cfgDLV4CuZNNgCR8lRLxRVLtMyHg83ucicBLIEI5UuEvmawOXlDdIqxbrJPOeY0NmmwNbJjjQE0jG9CZxrGk0zE5V8wiGeJKQNpEk0FPJAFi5MmG0pmSYeA/gSP7Ihu08kVHJIYlXxE/srYI5YL3iLrVimvdKEAkexmI5GzgqW7vuSofwNo1+tpOe6jCT+6FNXLSalb4Uz1uuMu/7MUZrAtP5Kz+1j85pJ/tePlT3QiAo6jVzKP21a5PDuioXQkH0Fi/U/dFpd0OIODO7kDAQDBIgYCPr9E5/JF+wYCAI1AwIPlkcypc5EyFM5pO5getWF/l+vqATuZVNiKvX9QrywNqMP7NGqVB5ZsD6hfmXtVXxeZmtKC9jBZ0DES/D7RgBa33OdDECtrbhAW6YD12+AsbiUBN9B95TbfvbzVgJt2o2O5lFdss3k8/iBdUxKqvwbP1qs745tm0N/Q3WkZ2rWlp9r7GybP9+5gc27IGZVrlhfUzZRRA/ns2qTgPqwf05rOlMslR/pL59yZ7qUpbouglE8TENl3b05wqXMNMTt+OOCBeZWBgtkD2tNWPBWu/hqbOblgQrtg9C2Nmkl0P0uwALd4PmChNJvo1dscUizZPMEuh6mGF34+TvL6oYngghHsNPaopins/KRyOqD6fmyzfyikybR0SRaYpwpWO4z/EiyFWlXhDl0l5BZoFWFAatGWAOAPUFUk72Y8xDjcV+UBB1xXIZpLfI0VjBkfvX26BuxZ+5PSdOej3jBnHJTf6vbFCSXvy6eiMpns9+nSUO1DLZ+AvF1BGpuYi7/ipVirGOYpkmpwILH8NXTBGwD+6IcNfg2Pfq+HxUFTkoMzFczlvMkhEn6wrYlSUFKua0mKeUDjA3ynmSkUPre/5zXwM+l1Y4mDIoCZiftSFVMqYRn01DBrXZtcbMKLvMqrLSHKuxCV7ITLV27EK7RF9cVhwjuwsNKCbpsUUoWLZkpPdpDsBUFjsRWMlhdnnPmetKCACPmotR85ej++/ni3GoNdajGfvN79JC0Q3kQ0dqU0JjTixTTXmE/zlJ9wrLM/IH8zF5jfXZrFc9NhLE+0V/tra1Ea8GveqGqkJ3gXkoPp7ciiZoP3WL3CimqxxGkp7kuPJhLyt8tMVFm5Y2gWQXx5lvk20EMN0+QLDtDBlEqGD9AhwkxSSRDvmbKGiaGI7vXUBN798rkEVbauJDlQRxeZC9dDTqeQIOwg5VE7r1A+Ql+lGLEZVlarNHiMpQ3ZUBUydQ6Pgvdj0PXsqL6rqoNGN0VYqKH1naqmBHunQQD/q1EAva6GBRjcGqQLKbfMVfSP4jT0arFtU3hhOK7pn+WbeK/h8CqVscwEVG0zoz+Z/DDBzfo/fwPSqFwOg5MOcz69XhU/aHNeoe7L/rVj33OjUPe/nngb8YCdeLz44oMvYwIlQqyvDrx04+qnfOvtlPXCdnq5DDJzSgBj4jBMxcLoleUqDjdvgMU6ri9v/duM1PbxW8ar8qwZjekMDjCmRjjEY09V9wJhMOQwYPS+Tw95Hd+D1k8OW+olYD2rYmb2oYc9fTeRf2TM05ND1l8Ne38dCrVzRWQyjefEY23+XIIbdQuEzDe5qW8jifHd/NX6906RmqobtAUZcs9RZqMF5jTtP3v6C016wraXd2nua7NY+uz4Z8y7TWC2spnZk+PzU0lSerzmvze7eu2sm5nBcO9yfjvlJ1XNtCPrIUM1z7VTbc+2MQabQt5wpdGTlfZbnmv3kW/ViY6fA47zMTgGaPc+elLq0bofCcSss1S9Yq7PihhVW5Pd1zIEPOHPgYktIjbFIX0VnbJ8LQuq6xbzy1IB01EvWrGAYlJBKPtVPGUgZQA+x44PqqG+iJudroaP2s7qbZNQXNMmoL22RCz/6fOtc+JKVCz+xc+HcXkPoHrSO2te5f31LFRV9D0xF/Zjra8+CilrqlwDWQlB9a5+C6tbVCKpE6Zn0dc1qpNV9+5NW9Z4ZXpU31+urvGsYNO1/YL2+DOyTH7Ft3Gz8o8aNaaZ07lPtXqNdxUU65UmDa9FvJlEQmjeGqoaCX1gsm3WXpaSYYZyz5xIjppRCuwYl5M0ca1SZZV6d5u9DpR9MejPZxqTtW12whND7HwCYSEpbHKL9jFZVMEzR3rSBbomlDnkNB/khquqF0Db08gnCu71B2WsIHizSaKagnpjJYa4DFH1cFKzWrXTq5TDGZCOb0GaEoHg57/MkAhwX1bF9Z7dkthvBoIpyCyvuQD6RfpFhoDNR8cepmGP2snvVAJyyxIVQkUOjnNdLXiyiByPqYe1iMOBC6xz+wq9BEBKZ2hIkb8d0u4y+ZVl9r1uFuAN5Rc77gkH2TRAOwRPCKo5ORoOz87M6/kipLP4FVGSvImvRAJraqJTM8YWInhDoviPGRRW/uyjzb09sviUxypNLgmMeTg7g9w+PRlML6cp2NSzqJcUnampJv4EJhJ4gTMa49IaJwKHPq5zrS/giIU3m6WeD1kwFUoWoidyrIW3hLyUACW/0mV+C383DHPRu6Lr1Ehy3uLSZizSLcJS8UGtNZOlB04VBVlesw+GGIpL2xPctdGNi8qF1uaX1BfDvZs5Uf40sbeEW76k1KOoBXQmOTYzr9eKcDHYa8EqiZDUpAqTBZm1Mee4EjMTY8tz7nfLcJZDnwv4GeW4IgBzZC7NnQQaOlIunHER47AJHROMCD8kN+5MfPyXhIYcYGUEyf0FZQjf7JBfEYvDFNDEsmDc7DqUebgFhnOKCbCJK8RuKmsfwZbSJ86eCE35NpScVLye2JZSC7EVjrSB7kuMileZESHMileYm/blDcvltiKfH/MHHOFnxn6my4pO6XBzdoGkK9lDo3SZhnn5DcOcwxXjgPwS/GqBNl7iyZJPUKY66QyWB6qVq0RfWUy0ijBxYXyIUIQlaRQTKiYJotkRb/7yFq5YX5N7VFI1Pd1OPyGloH+YkFYO3Ib9PBIaQ9xfzCTwFYYsIQ6DD15fySZGnny5+Bdi+uEw7miU5G8ytRlJqw/fm3iql0jGucjNRg0FR9kkqJufSUAix7WQVX4DVHfuhOd8rBFDVKgEGA3OHIobbE/BQn0DmA/YIj4AznelTFDS6jm1X/ca6Vkn2Iju9fM1lp2dWkBB0IMHMiOXHnoXWrDdJkXCQq3y1U8pMNKaMnPNYCbN8djd9CjsHoPEu16LrBNe11E2sB32KHQx4q7DVqVIvalFJxC7SIl3Kzdli4kgBzRhA0nIXdRSpFPxuORpiS6SqXNNVPiK3pIZaJ475zw1p40XSJSq/6/tOpGsP2nnbRbDCsAb+yCQ/OnmopVdd3U5Sup3LZkJm+kTs9NmXpg+l/zUmT8jMvR9jiKS/rGUH0oPWgXQVrWWeC3LGKnave1dzo608MRh1g/Ouavt69nrHvrC6PYxtUg/hMczFVJD3uz6zRt1kK0+QJlHknCZR5MWrSaHVHVznDrzjbLWn0usa1BMOQ3YPcP/iVQAG/98gbs04sxa3kN5uzfuQbjDsrWTYic7GpDI6p+gBZQ6CNkGyyetWfFGmydH5niwe1BaJLZLjZQOtJ5xM0dkHHYYoXIIs8Iqqgm4EC5ONOb8gnfO7unpHvrbrHXmmdkc2cgb11fN0uiPvOb2ZlF14mZOUDa1NDvqDWYrVfjNRRv655yO7nnElpsMqeid4E6B9hgOg7SIWVfY3eAjpzpSNDhcbNwNEZolOm4jseluV05hMwlLCdBq0RLV82ALJ2ehZVDQREGO6UGNPeRE505wbYR0IdHBEiErkhZVrMDciqmJYpTWIMKRgaqQYmJpfiHxfLwRiGj5tD50deSW5StY9mEERQMiKK58gaP3YEA0W2kJhOe4kwpUT8sh42RPzJRUdgd1LR7KNaCIYZKklSFORyz2JFCNnHQ7TDj005BH4k+gfkIFe7+ae4nXXG2njJ6kNOTfiNsEpmVuomv2YFaFJm2eujij45reReWYBP8oNN3wh+wkYtly05noi5r0kL9mfMvuQ8TvToX6pO/CJBZS7EdBNzLw2UTdjxfxQ/FwahzTtB5S1yUjRO73vQTs3BYKhQACtWdyh6uaDjtyzWWO2PwHMxiq4UXuxPcm6nD1lguhzi9i+ZP+wXlkg5D6P7rEshJR7MHez776by12wTjy2RXScnIv7uuCT67ibMZO7uYhvjwXnNWUEgiQ7ElQ//aNxskcOyfhDCUzXwP/y5YPkWBQICzKCkk8fBqAEyDZyfSK6pS2iCZ70QLfS8P6ehfcK9nzYFqa6ftE1ZutkBecEXsQawGOB1Z6duGaIz69yYlBJkOWHyuOIQCos6IKqscF6Ll/MTOES1xamumlVQU1rpPKPmoxwrGMmDx2rODwYMvMBK6DvY8M1axxSq1RqHVJG6N1MSEcC7zaur3iOb9pv64Ijngv7H7xzsXU8XzCxXAvnUYR8yxHOr7FoLn+sB/DuK9pGc2o10URJRCpPNGJ1MZOLP7Hf54MQTESq+erPPAHNw+96BXvdw00GceEWWp5fUVbP1p9fFuKsxXOQaC27FDXQpVWNOU3JGvTMLbSESXmm7GJjbZ6UD9G/IAufz6WKefDuidZ8tP33r5oPNuKtO9OecZ5o5xPy4XxI8aEmkguByqm+QFCCzgrxdpj7KGRxWfYHMeyONx8Iwgkl6ldFE4b/Mfq7CvFMXmXnXXEob513+OWDHAceO+4usY+7bdXjTs1nYgLxSdFEQkYsaQ98JpBCI+msObCesnTYunn1qmcn20h/xv2N+zMABK9nAIL21UJ10rXH2mOOLNprR6Rht3h1lh/C8AIDBRTMkAFpxx1e9/GeSj7k/IAr57SoPy6qvK5d/YHDqpgxClNzAdnwpjenKYNB0/0jATTbIrVz8zOzmeioTyGaFANPg/sz+4CPtz/g0eoHzMKSyiSqZchYXRlSgc0xnunicYXOpk4ljKIC8EYGUFIFjrchvYxWWqscARFYdz2fzg6ThtlhPEbNW/wfcDV4toEV60wIO+9eNEykDlttETvKzfRgSzqFrtUdV83dam87lf3qtjNysr2RVc60TQabTyXHLnYQ+YFHB6iqOqn/I84dPeh5u8NAAauNJOBcaCo8exJAwO/thKHmFGtDYpsZRhpEkCKwn3Ewzmizlx0oh8NB7GWlyuE27tFIhiygL3CsDp5vVqE4Xy4IZaoDVNoyFPgb9yesn7es5fppXDxNq0la+5VEx8FxVXIso8sbltURziX1p5UuKb22pFIzMceK2p9kxxN1/+xcYS48RnCPuQ51nQNBBWJ8y8/evFAPzzsn9RuFlKrTp2ngku/Au/1x6kQ80ZjnMzybqBXnsezj5U0tZDISpl6c51YugCJi4KoqUjkEdJAg/TDfNTfPWgcADXzR6a0Jttftv/vN5Ewaq5geKnmonjGMa9FY2cOFeLy8onw6EG8L9MkOnx5Ppkcu8KQycajjlZe2odGa1RbQomw7ej2kidVvSA0VMs17fpB82yj38epWtFS/Fb2iuhXtbb8V1RfI/+3R5weDrwVlb1X70M+74Whv7oSjNSP5eyuS/+a6aW0i2cPVhjw7UQz0cqs5fK2DeHSnqw0K564R/AWv8wHMN12KBqvV8VQNU/Sp/xHVINMKOu/4GfRVlYKhHLoxrkLVaM1ZPHd2lE0XHAS4xQgrDVaOSDW0LQfujP6pmg2HO7JhLAK9jdxUmQeFCdbFqiQUFUjx8/tsiv6d/YCSUnneKYF8cOnFW/d/y24hPIKOLEOfCC9/TY/EoJtoahol7mwfzNO/sStQ9av1Ec38+rzJHsHbO/3qneyrb7ZZlKIAl1i/j3ruSUIErRSKZCNyH3Esye+szaIk/bBQu63LXp6xB712l7/YM+m0y+KtbOgK8FvN+l5+uCu39CMd13jlp51Ros7j+PKqnjXofOkLTvqs7OaVO/qEkB6y1jv7w/2RRT/beaunO8NPrTi/CxPO96zVzlCuvifvA+HE3uv3IXn20sTZ5St9f5qL1NiwmJw2etwv0L6Hv8GLBC2mywAUlunQbHjge8Qv9DIojgiSN6ykovyiL4knGhHj0Rq5q6ChqVkXJR9e5jC1Sq0yMooe1zRO8Y6G46mlXrYOGMnBguMBxEgVPunzqp7VbRV3SX7Wc4s/8wEk5MN7G0zzwC0NJ2KSx02fuSLxMOEZZHBMVWS6D3y+8+bxbU4mAgmoSogO7VP/RDoUHUc/7iPcv9BReYvdUYkmyh6nms1mSnuqOULVU6uxsc9+SqujUugN/fmfXrNBsIdZZrNVsjbLfIIYjkTEtkTHxnZJJQNSI22Y5OKdiaCEVgkBSTSQ86wxks4s1/dFWv+z+iIjC4sLseAGszMSMeraGrnbbo1k/zV/aWaGHlrPDL2CMkNxJKQx3/wYWmZp5+M713W+edqBQlhcWDR/M8vXFOlEvroeM83cOfZQhCJ6BNMzBh9bWs94qXK6BnPM79CCBp2DQB1YLuljz0dzdlzx6/RdP6yW3Swkj3B/BK3xYJzSN5qv+WM8e5koD291zy9ZIRkj1eXDFsE+PFUNTDQFPlgayPA+HHuOZM/1FLYr1qr1BZs5srhQUymsATesvjRHmwZKlgaBoGENW+ttkenbYXIbdJz4z8cnomoAFjb+mBpVHs0+IgVFXaMUYndCR+uxrtyVHNayWH5+1ScGpccfNYxw0v93LBKoDEIQlkoiV/GFc4oqM+sbzIXh6c3NedDZQPkEZCp1MDkDQJGQricNlS4Rv18JAU/MkYOw5tw+PY4x/6F8XI4rGnVg3YqVH0XqiwgRR4DaLZ2Fnxn10AEFLgmy89/AOJEFZQT7GRqrRVFX50b0fFIH44RT0HuDoEtuDx1Nw18bJjjyd2BrdB2L2kj4IcIMEY+azyUkrON8qICIxbGInsQi2t91JfXEamA2TrUDNk4Sm9hYlYIGR2zstr64z1tnqBc3q/FIMoxtn5e1oUiWKkmfr+ywz0+6ebotVqNHxwdHWY3m/aoEf6fVzK/wnRbfLFZpiflB5KI70BcDSmPRpDQqIV8N03ggwzSW+sU0+rssQzdbhr9BUGmn8FW0aWr9OoW77o093KOOX/N24M7hW75v/dt9M52DunxrN/Ri+pn70EZFT8MLXNcNaA6gn2FhTArXh34ebViNwf82gvZwQ9B+fnvroN1hBe2h31tB+1U/w8HpjaW/D/J8rDzZzyRwREqfUBfQ8MbNS+Gm4xKtb/xuoM3HXK9jZGqoVTP0Nd00Rq9i5Zd0c4KPo5DyTgR0zGZ0JaCjOhUpvNpioLMrL/ua4YUtaHebNwM9hr43+sMBgsKuAwOa3Ajmrtx4yc9mE+QLcmmk6NFor5jHW9gwFsxtIj9uxzLvSDK3WeZfx2F3oi/mVaxfjIrk+cCr4e/+AEGu7K8IJJzKeH0a9gUlYuR3F2F0UpyYCoSCeC2pPNyGSu7LF/NqVy45nnnBBttokskr93ro3YIXRTygqEbQUJ9SMfjpMWQOvhdGOCxigy1aSPHtrvOAaLkLoRPhL2bFi9qPs8E5+v9VF4jVaMaJtKihrHr8xSJVFtYGJi6MmoivNBHR6jgdYr+4D6HX0wj7Ay3QNUpfxvDbkGOkmY2zHhIs5hIYmmJvMwiW4RdCcA14ODJjYL7SGoDiZb8vsYmUesSNG7j4mZi8spONSGeyBAf99g8yZuJkemVwC56hIEkUkqhXPKJp+IU/TVAmR9Grkc+njpTA8VdSerCo5Xg6m6mZWCfJJ6dyeYDAAktIRTWuKfF4yK2Qk9aATb4R9ZkQ4kY9GEPEBUn0ss8MphMwWojBdgNXdoVnqfIoAOYVpMqLXe9x3bG6VOEHiy4vrW2KvKUPtHnQgTbP2GhzAxGy0ebLj/eQIEeuMEEq7+rCQX/kTCcH/eR6vtu5Tg76F3rKCxF58W2G3qR5cbXry67HXH9cXW5Yxzd7icUmgsDtQ69I7PED/wdfT1uC+J54m8R6z+Jnig0ZlzL1UZpyfF/ZQ0eCYMGI+9kK9poLkvHE9mxsPG9EpWg2Gz04G4lkj6B/58EAdjc4Z+XN2JDoI5iITuprR/cxkzJuTgxWt6139pBfqh7PD+dHVrwRVf6RWTIMn+iO5scSE9l0KJTGHTCu++jf+cvkNT2hPV9lblmQy9B5cV04Wt3ShFSOpS1X7CUJl2/iY6FYPBZPR9k+9Zh1pL2JZePqjrSyWa50NuG0/nXNfhO7b9V/E2nzXDruKk9C/zR9N3/S4Lv5gSbfzTOdZpvx/IgxuVT5RdVtE6rl63plwv9jDU/Fr4SnQ15kRr3HZjCk1zw246bHpm2yGZmNcGWCZVd/SB47gEPyPmszvML1CdfPV7kRDsJ3oqdtco3PT7Kr6kmxqYUnxX9UDm3rSXGb7UkxxaW6bY/Lv+whyV7cmGQpJdIqyZTGHe//9Wta8bXjW+6Bu+pS7hozsSKtE8vnSKyfWIl1Cyamn1ldYkWt3rWUef0tzw9TXZPZf5WHzcsYhMs5Z590QwZaPQrF1kIanU6iBNbnQu4tp8YTwO1IsWRc0okRlPGbyRE/rCcDair03hvlAG3o8tHkvLaamyB2TEXcanbT7KW4UMXNDgepKsGx1Hzz5oSakX71rCblbknzjsROj2+O+Pxury91QDZJzVq5qJb0StwG9HEHyn7KgEhHdY9WhoLnpzqdqeChB9Jr5mxYFu4aXLIKjiP4lWB0/8T1j9Wlq1E/zm2r5Z1gg8aanbh8L4Pi/afpH+Rte08+amvLEe+rMKNYzyF86QCP3d3OafHcxPxErjYtzk3tOuLAqZVXie9xTH0fkp7hqjPfCVydMsGIDSk8zhr65r458EN5+V9t2YR0V33ASlTqqHb3KnfVPqmEfbq7rHFd+HSf0ML0puL3ngvF3/V9sg0jcqaVQ8xq9RG66T1k5dJReDT8jOvOVd48GsfDB5kr5m5lpUrj4PcK7hRPzBx90QEHXHj07OzRFx5wwEVHz3BvWHVumMonyw0lv7CzWNwxl83O7SgWdy7kV5wt9zeMjXMvGkgq+PDCZe83y01YvSKweiexzHi76z9dv1v9pYC9dtFNRhg2XZ0tYsSik3m6UKx2dtCXTWQOWBLFjPBc2nTI7lAuIIuCX83vTIupoeGhtOQenR3l9WIwOGKoUXpfcyf90LYN5AZmuW4MBbQ4z4VicLogtweHMpCvQqli4AouWRorpaZ7Tbu1VGkr/5INzRONBHkpoPH+UCTk57l4Os7JOmZ9BV7HFwsBQPwxUR/0Eq9PoTS1gBYaoS0/oWAkRl8P8H14HD9+baTc+/jTWEJeC8z3E6tMyNmI6W1ut0KwViNruoJ+15KJimR9RPTKSrMJmgnLIaewwuzR/ezSOzv33Li3HhEucSSUyvkqR4WHY7itCrShy60kJyJ4kf/O/JkLvqGhrAR8SGo+VbkOsE0Z791SIK7TObSYkgI+wCvqSmIhDMy2V8DsEW4OHvJQ11vDT9fyKvvtEK5EbCqxGITvtlEydHTYsWuBouqAFNInLd4TY8UaRktHFPhaYz/OsU/n871oex/o6arAuzZipsHPy64NrpPQE4+pqmibd0Nme8/iSvq2/On0NChiNyQbFX+yiC/kJUFMJiPknZ5sISOhn49HP4qcLg4FkuUEeapXNx/0CMtb0B8jmx4dnCGQhRD+D/dHEskP+SsSCSfTXp9K3wDDRu6AIjmbz49P+Y0gzb/ls22jnj//s2bUs9Np1PPGu5xGPZXDPH7mASSm6Uufbvj+4vN5ox7Dw6maEMRKwprPwFrlH3hWX8QT7c3woHcRc/kW+1j6xGmdgy+idJOw04BnpsGAB72A+Bvr8dzy3+Fbj5fUPQARc8UOt1recwBZIBXmyQd4CYt0KSlRGgdd1fGmVa28PzJlruoX1Nx06Bu6EkZCdvLiSWp1VjzshaeS3bCl3TvQ0XgHqiyaC3NJVmtrNxDcEpLYl35QicUMt0KsVTtcSpKcVsSq9YYbV202p1Uer/rqaBvGxvwqeUnNmwdPNyfVP924Pcfge0/yOa15ll9rTqpcRx+EsLb9YaqsZ+0HIc7PFiFnrtQcRvQy1kqFS0t5bAQ1bQbo5r/DpslAI9w7XR9xfb8Ftqj/NIoOwLOpqWjtIWNOaCIa7ddHCt26cu+mbCO9qPKlTpnSxDY6pq/M+e0APJzeXV/Ekse7pAqPVHmQ+z028lHXEbSJtVS3g6OLxt7CZ602HWSQddRvtjKkZd9GVLC0Rdq0DDAOLS4W2lNdAfuFnEnzDu31W2CXU231+KGczaXRLEFbrcGhSWcKwRdJUXlTbiQiV36Irg3JL8tlub5147BYiJ3N/wmuRTGrcIiWFsgYNF5e2a+bnSA2m1U0O0Eur2vwCKRT6SC5PphNJTR0H5PI0FSsst2T4Nq0ZqiaN6HeTxuWp8ro9KP9Hwcm5uKak7P6sSpnNVOb7496s/kMQC1sq7+f+xsAztuZj8t3VnkPHbhTUn9F21F9F22JgXspVfau4W3hjB4alv/V0cjntjqu+3t6vARkINL6BpYlA/dlWussObfauFEhLdm7P3tOZIeDpXNRA5I3Gg/34PJ0gTM5buk9Oe7nluEEsB1TJ192/Xqg75gr6cWuVgzlHo0BAIRvk0EYtWqVQQdJk/NT7TLoZ60y6NRq8/am5ubtj1cOad+8fZvdvD3FFcyqQpKluNjFQIBeDR5qSDUVPHJtcBfDu/rr9z7FqjRwBha0czv5DGQW5uZ/2HwlbPF2lEHL9/8xE7LTXe92fZM2cPTW9G2sIkOX1mpj4nvoEj+vhy7x+/vd3/4xyN3r0gG0kZ+3wg3wPYM++pb/t3MHunnrMeuno6BJfNr1rQEr+Wt2CjZdivo+Fiu/a7wjcb6BnoOFxqvQwKR8ctPAM6VRyqe3nCeZinIEHgyvteUqU27qgl8thjtqWq0prNY4pVjqqmBlTAVrRwew6o4u8tavwVhNqH4Ig5SxirCmzMlJvpue9ZV7mlmp4y92slL/8PXOilfKwUw9xMFMjQqHvGfXHxPTb+wqcLFVC0FRcJ2CuRHKFYSvQIM4tUAJq1L/eoXEluhCTYcGObcRGEh/wKK9jE29wr6VQhHf4l7kV6JYcKehPABGzusxu4ojWgFFQR+ylxQSigEsRyWTDUhuQHGX/69pgc9BcYawmfTSMVxB8UqyJ4AGF7efJ5n+hAty7/E4r/BIbGpUryRu9fC+pIuCSGuPM5hi4TZMwWL53qY3OyXi1VWsbIgXecESL+CiDKk9tX+W5Gc3zRaW7+5bwcjCuebXELuOBijpaiRPF++Y4XC74RbUr4tM4UgTk/MOIcKSOrjFuU5axxYUx/jB1IuGO72N/8sZQbUqanyjcX7lKKlgShqYmRaTxaJa2WZKG+5Q1BDqxY2TLHHjTvIi3SdJnlwxz13p1Bk+7fRzGZ2Z0oQ9HYZXOKZtHGJNw5D8QmW8i8zxgH9TnuMvMUfdrRspB0T6duYLcv963EhXQdQX1viCelpXc5gLV+cF8uT6XFsvbry2JsJtnWRmujnJ1ADsr+6xLYMeC5xVzFGZ4xcDLuasn2LNfxNqEMLGnIDzgNkVkqBs/Ug2ORjWATwgVe96fv0LvL837f+cRJEWPPvmoM8d9eHPwH7Jo0YDRMeTJMFzlyfijQclmIy4Za8U8tCaj6ZfT0XfxNoVfQdyold2a37Nrej0Xcebpb+gpuO0DdIbi4WBeCd8SKbX6cr/JHJZXFYVjyIGjaDw1IqKQLpP3cMcbbe73uu6n3jWvZ/DPEJYeThX6+vgV5WJZHitBbeVt3rci+ukMgq+C3dTreHjfWbDx56VJm+vF5YVaymPeAzVE4noaAJReb+BZg6ei6ViaAIRaRNIwAe/v4Dh8eqyjCYQ2WwC0bTQMKfHtFBA8Y4A1ukJBsMxL/4bNPwAlezoJ9sfDsXjZrYrMeWpnt7jTbRmjHsCr/G9mRRQFKloDmcv0lPWPCVZu1GGtwQ8ms4gQXJRStqORhZ5oGa2cWW6QPCNxekC+5IwlgfA6Z3dCY4+AU6ZvsSWeGJMEOh/AgCA/vLwsI7bTTSXZ6UJQdOspi8Gw6PhVJhLjQ6PJIKFW/Ahi2h5kBPxO/3AwqkwptAjUfk97W0J3kShLxwXTqXmZmbTB6o54CYkmi0C1kk2FyffhLOElpKo28Sb6QsDQac1oMyqJu4NRDFrh8+XC6pv9CluYoK/uKeA8TnN9TbX57tSz9noG3BLw4UFp/bFNE5omPikbM4vXcu2DjZGAb+9exDQe6bRRqEqjvLFqkjVEX9OzvIaXjWj8LaKpaU0rOJvxJORZBy0J2MEBRZhr6RU0Iop38AH04sBARu8PQKR8FLtCYPYaEVFCY+7ckI+nh+dGeXDoxGZgobeZvLPI1X+ecjmn29my9tjy1ObqDwluE2cExOpovPR0EjIVqm0IZ38RzdQJ3lpvYKUqilIuInSSP/AivSnXf+9DpHmGc+rPLzAJIRh/IxhhgjeRtCZvsgqXrqphx2HCa2DI2LUwsQBsQVEHHn2MuEOOaVF/D5ByxtIBXyUkn5kbhiffmY4qA2VhrRwEoRNOejRYvCFwLLyhoMaPku3IISlbaoByTxT9J1Sef+6J0vlBNkPlR4kDri3ujUjrByroR1Ez8ViMrWW8QZT4TPAhfAGPf4sKBABHEu0pSOq+ULKYYGooccUt3IezHa6pBQ2D4BDT3R9gDUWd7FMWFFC2e4Wq4KSrjqHzuwzhb5mml4Yq2KU5nrJm1tp3gTrTBaSZt5scWbNbHPWTFSzRgP8v/La3nGl3NYOYrXJH7W2misxb/iTddhseoORLvXw7vEsnjzLt/Xw5rK366tHev23m1O6AUpf1RFASp7qYZ9h+fROvPuufTYJfaBK+WcvXyp394crfc26J8aH+sOXIk065AHdVx618uBC1//nunU99pUGYaV5d5hfnC83xbtOEqFjeGu0YTS58FzdHGKeb4rxa5qsei7tNeo7m6O+vWk7eKTBnIcL1sXVHQj43dXIZsVKKIA6CtVVQNOhI4o6W/L/xVwtpl2nojWY8rZa3elIyztdtC/bl1KHex/5fXC/XfsFcXo6bnaZPXnc60LpjONeN4F73TtaGr7M2IYvMxPTTsMXGNK1vvuR09nnZN7xsomsdcfzi9Ub3mW1G94RTvOX/Z3WFMdVrSnutu9/Ecf9b3f1/gdbGLakrnPdjj7aOhOXUcIWT7lYJa/XW7mwj5zyzvARdzdzIX2tQlbotT+y65bb5bWL2Y8JN3nMqD4RgK0prF0ksdHbRaeuFsLsiXP4IN7dyd6l8ome12PlcLaA9/awv55gX9dCY37amYnZCzGkOI1f/DFqVsIFhhKdjF/IZT3tw/il13Q7W+9nCfBq2BSCDFFyXtMWI1k619xzGiD0WJJUBAQHh97xxUhVNqT3PwohYc2aS0UkSvVf8sP8mqUG0bGvbLNvbektaHvtNT/QIpXYnA6ndA/78EDTGjbiGOKElw0lprrRcY1Sme6OgqiMRdgV8Zq1yJlTrbtb3Eu/O5DzdUwcTP2xd01e1lPhiE8AatVAy7VuCFIkukNLMCSPDJyz2xc9Ug0Fg74Qb94RyVcGklNuZglCc2rBdSbeLL8APvRK4iuYLlEaXzSfqy1LqXYZGO1uEtJTrfbafkPI5Wb3wiuK84ei3kwezzrRQ47cE26XXFNSD5Yhl/RSqf2y12h9CUfJaFqBvMwlMvh1y2+qVfp8o6OTSNcy/TEW9ktRpP+SzmRUe+vhGtzPJjLXkWuExBHmWL9kHd0I8qE94G6s2XZyDHR7kXGKPtLzPnJdA9Do5iagEZ+dnJ8uSXx5rMw72UbRbDF4fOVuG21UXovN5Rqo+n6vF705hqfjvgIkeT3KSFV9NZRRwkQZWSSjAe0kpi9FHgrTWaj3v9OfNQ39tfmuuwbqwiJyoU4uWrvTiLutL0FIy09u3cBFD37e7lD7HJt5ITaf66ui0fa1SJLuVjZaWO+wrRDOH9Vqbjff7UmVas6Oep1JQHbcx7LjDHjXf9/1FNGw6YTnmuhAS2aWRBfqsVRzFDgE5kBvGaLR/m3WD7ei9BCgSS5aZFnatxO27ytF+/cuL9ReZnsSvUn19onLL9sgQ+ZRt5k89FEbbXWJRQ+y0VYXvKURaHWFB/1vpJckE4bCkBPy2t39phjaZRPZFNTwYEhjpRT9t6pymS+neiW6D/IqqNuYd+rh1LuaKl7oyvOhQwp6F80NDAQDcHnilBOFNatZJKx6DhZSx/B1TFT4MQYi/B7aS46f9IFeM/VB9styKaTkCjkF/wK9ImxOWWY/IOgrDhV9AUPC3nlCh6RevoPej4HHRG8+dgY+mUu5mXTG9kIz29/g+pLrIeyFnSfce9v6cLFgZh39j8Kv4Sb5Hx3n29/ey4aY3ZZb0Qz8K9di9xxvPdiu0MXQIRM1jOL3NPr+o4Fsp25XDldBFb2qW1wvhWUyHnQM2jKyVNuWkFlsmGXRBCiYrSMmRKg4WpuqJHar2j6koXHY7BtmDR3m0OzMAi3dSk6nWMvzTbSYWUUUAlRIQJoYYplu6uzbw1K1F8RsBKGt61stqvPz7L4PJR4spaLR/fIBWXFjKDG3hX5waEANKtliCQ2j25bsbhG62m+VDcymcnJUziovo+3GsWq7MZJDo33I1MIlMLYhVzkRTvE+H84E3M2uDyX9sqRpwbKRzoUNnQyllFDAyw/vvFFUPYZXq/VzFI1z8GAoqcxbB11kXoH8MbhPOl9GFRkU/SpvEWbo/0LFyFCxHMvtSbP0EdHvAZOKyqFohzX8waSCre7X0HijElSBQHgieviHdv0zOhVXoeFxprmLh7yfyCqMZTVkl1uTkVvMChUfwYfSo0hVNWp8DIvrVvortBNjpDoC48ZtVlblXTL1NcJZOwrQMjpGXEXXQa5LcN5+iYpy1TZT+JnOL4bnrTafORPlJ/Xg21iCoi7anUXbCUyCaLMQm55Co6uNVg9DTIA7DvMSohvJwiTrIqJfwxRAqH2kXBxmvznVBovSKDGbhsytaI78gej52cJbg8VsXIJZDv57PWZ+3J7bR8Hy/a3jVvbXdkaOL8LB4+YEBTQn+OUkeU4tKqEQh87vTBQN0KCz+4oqm+ysXIlTTiiNFjk+viWhZRIB2vZCXqDm00Z8aIP/WBlbDhcL7EFuqH4qOgmeuMEdMTSO9hrB6/WhjXZorEjEvAzCGjLCn1ASoeWvd7qe/QRvVzpGHyRWhCdnvoztKlvK8dxxSgq964q7EEHrennH9n2L22JzuhGOROPb8X1KKOhHbY/XayMS8ZA/00Z7WSqGaIOP6s/gORsbI4cU2PDMj7A1xtBhdgqu9V93/XCVXpF0SL99AoUNqhRZvgrzs8P1O4kesjaRMlSlQrnkOOdmSovMJNfeQMy9xPwCXEHLBbjL0STBb81coea4H1Sr8k31Vfm2c296eSXT+Eybn9xxyuXVZ9ppsqgkJgq30573WmoFkFp/Qh8ZdhQFWYgN5XC6g9MU0ePUjEnwKIWgJkuCHwY1laNwfIl4kA8bfnKmMaoFEnoplEkCuiPGfflcFAvSn9T8BoHqFNOvxDyEv9zHe+2psQw6s+AO4E1ECEYgQJKgMyj4qcVS5Tz8C7/PG8d+siwItTmHiUjl3oTu1byQktB6RC5AVxlSE13ZsN8BrtdvJBWJEZ717GxA4iXd559M4o/zANj/ukeGN6UbJO4Nz9zFPc0HXROu57leg+fgO13/5XIJVXji0kIXciLP95wmW/iFwWUJ8ySj734mPHGmbCaL0Zg8L5f3Ofy4wzZ7tizV8xEvJJrJR8TqjQ+NvbK3JGmRIkBklAup3lPkccEni/gnyJNzBx990GxA8atnVdNmlibM0oYjs/M17mEcO1AiGLe5hydPxjKwS/q0M2kS2Xhd0pxbS5oTz14E+r9l2hB3H2lTuYLHszEbBZCVKIYKjnXkEcpfVxYvQv8LVMxeYIzx9NfQyIeDgT7yON+IGt6JSHsbbWORmbQsWW9BPKpp1lI6RqbZOAWj0or0TYj7oGq9+vj1yWB4LJxCO3B5bxmFXXwczTbEfCTKHlIgh5NwOrP83w5f7WLNV/tq+Gq/WvKJlycKMSC3JMHsSxWlkvZjIFFgmkLJDQJ9EuJ+6snm4+S26GRMYwIJz+pG+kKUTk9PTqfRkCkXqfGUh70SLR/YznibvN6UaNxovA+LRVyjIOPEFIUzff1klCyYBC4WfTgOmIHKf3MP86JrxHW462I6V9bJPIXOl8yR3oz4Si0GTxYa507IlXRkpDpVcnvjVMleTJWQd3a211u+iw6aCLI7log2DJqchRYnutE/yeAX8Y4zJMt7mm3zTqq3zbtp91Ny8GznbIk+vvu8I+pGS1Bjj+AJu8KrrmMwqPct11+oNF5m7arWTY1iQubtZu0FyxRxiVoqLzKAsTlKjvoJlWdEQvMvuqIjtH+b+gdKJiO5wFRT2jkVqd6+htm0iYmpZepY1OGqCFM37HbYTBnpiP2aeaXcSpjD1DyMppYspyF24Ot2mM1G7RJ982MmRFHzJy/N4ovxW+EHlNHhvVAuwsxzGMi4gsRuAOG3045mYDC9gmj7G6KtxSuA8OoRQqJXfDCUSAQDIs/uLWzeT+S9Itwz/3/mvgMwsqs6e+5783qf99686VUzo5VWfSVtX5d1N8aAA24Y20Aw1YDpAYJjcIwppjiUEHpCMCSAIRAgoYUWIJgeQsBUQ0j4gYRerNn/u/e9qdKMZlTWkA1I2tmR9M65557yne8zD/DQPrQs8j08ZRfptQSVOHcPTgmXSKSg3waX1lVOpF7BKejVenbBIBciNvHydUI8ErXkbSjZ2KrpIxumB4mPo/6zMIHWmhM0e1IS1wmQhZR5ma4TUFlGUOrIwnWOxpsghCUXQ2wOhZuUUDUXnCvSMclWHssDl6PE8cdgRRiSReyhylgJs6Uytsbi4H6Pn0e14wzogIJYFlpyWFX4KU5cDYw9+B6oIF+AbchJQeJ93aI4PWzrQ5tS0qSrwmPLCb+UHRV1xkVm2rwOMnvI1GxbA4ac43TN9JovRbDFG+InAcT6q5KMA4EjoeBXpLBEMZ70ThUMTo5TuTwjrq1gZSDyyl9ggfQYk6n72slQJ6C1ZHcLn87ke+QJNpM6E8YiUrjfuEQKXYoE/9rXwH9zfwP/3a795119e+14fe++5te6FQluGiqI9vuR+BO2up3y/qFCBPDTjaUIfjtcMm1p/ZrKBowdkye+wP0Pc6wHQ3H4q9tzrNqmCmjj+UQ/AUj0QwzRMVjHADK2W5HrhnrC3SN5wkPaHB+nRxwfgAi2OD5e17x/h+PDkHooPt7RKloObHmDZKlXeK1SLPsbOsYwQo21v+9i9DhDdCC/iFbtZMjpEXSJFlxuBqD0mGSO9NXIkV62A9Qvu0MOes8GLHK43Ta9YkNa0Af20IK+sa8lavS0RF/URQv63R3w2HuIFPSy3hh27tTYroos+ADo2C+HjOBBND1eFW5gh2QKUmsDO8yHo4Q3+mvkuh5IA5dgWSxmCzssK9iQ8K/wh1zD6emUb+sGq9TQoZNdSHp9MTWdMAxBslKJRdYi4N6Ip/Hq7WgINh9K/p77M3ViIqPJexYX7eaL+drcgiVZKNoETjbVYgFrcZpZybvT6J1z0urhOQITO8J5O6ge+M7vEK00UVZlSDFJCAvzUAo8BZzBS4AJvoQq7LaIHxm/BdBnBIlrxGhBD+0hbiVStw8frbtL4oCIJ5hs0OVIjDXAPeGFXXPyec32lMxEevXRK7avx0mELJIyuawMU1xvVDlOs7Q6nhbHv2VECcDRyKWbt1JDP9Q29axCUxINgPInkyerngW8Nk1X/ULZQGtl2TcKhbxm2LxqZM8qJSuuM40gLMtFO+E3L98Frb815LymbzLYEueUHU0OW87zmEeExn0IVLPeE7tjbPOujmM00gt9C/eTOhi1VdpZ4BvhotJgjFtd5HfE+L8b1ayXdK8l5S/M+1lb6sGk/c7JmCFYjZfjfiYlZs7aENVmKZ/dAQ9xxrL8p3ugbQrWkh7bA0l7Es2eKVrNMgxRoRdehGsDkU03ru3KENeW29CTaJj4Pn8EwulLsctiz2XS6eP5EdlZYcidCQ/N348hAOl0CUDmWwKQlDqpJQDZvH4HjL92/iZCjz+6rFvo8dxeEtiHdAs9poaYMgwKz8Qi4yfHN+WWqtNty+ftjMUf165J7+yrSV/aX5N+0LVfvIFO3ue7q9LnntSrg2ytDoUk3rbvknisAvDEcbjNGaDIeiWoxrsmV9uQsfNYhTAVAXgo2VI98jua8C91+50wknSAAAq2qshSPtQbXBvG04KL9SjUvat5+kCFuo+1FOpqJF110/XMyoNXSiX6VAz4Vkam/SZCbldt6loqjGpsKvP5KI57V2j9pDY7ruzcE7wybdSS2Yy/enC/n5kMmJeYOcvyndXITQC5cD4+Co+/ajcSqBo7xv0SM+4j2RLDZ2mn+qRIyTV22/733V2ZuOoueAYp7pj62w275zM0ufweu0dqsUtiN4PY6ROjMnruago6yoLqgKvkvBGWR8nTdiMFXfvWpjup797gAtmcnfPFu5l6vm0o4Sa578CiJMw/loFJ/ksIJ/1H9zB7ZCVAfjedaBQtwEFexF2gHLv/1fc/uqHk38vWSf7dvCslTaVb/K88vzJf7hL/WzjnfmcvPH4Df0qNKesHKOkuute/DBL4o/IOAzzrm8yz3NhZmLY+P/bXg2UtdsNt1lFBDqpjT1knWPGi3fCCJ/XTc/1qA5uvE6VY2E2bfrSPvfGiTZLN+4On/C10Y722Kw1nd9fTz90RmvrCLqQde7fVJ37S7mUa0DZCpmEwb/ir2Osw8PdoYUnVRlYArV0NZ/wrjPomoGeMtiKdCCQb/VfYXCYhSACLAk4LABX9OzSi/JC/GX+12kUIG9DJPvMD+n+LEXSAfYdcS/uTkgDnIu9CTtx4LwDNqpxSc5gvoJjkTT2jGLIhUvRO3OEkXoSMDDrJuvQKM0mXxnWQerIJvgi6GElOpgMJJ/kMGchnTJ9kN21jjk7H7qfhDRSgmnEWBPYP3Gxes6TTQAwZWEHzLU/lyJ06o4LkJPl9qqO6Oibpiudl9TSIaeTmc4pnQiwFs3U6z4ZJ4xzQUhZMgBUGjhGz2qKsCwqk7SzJkNaeCEJVQLW5q1zDMDWRt5GaqknMAPT3/hQoXNfQgWxzGp4W6OARXrtbz5tGxgZiZjX41c/1wPBKAq+SKz79WZzpgye+gmFAPHYAPKy3xf4ZNcYS5o894dZpRWeGjFkfnjHpEbYvMhTQCrRb+aTOCAhYt7ojfeICUQ+3CA5SctAjhOhgzG+HYBau96ezhVQ+W0r1h2sF8wRCrt66sNBiT1+K31jn5LHECjI6p4m5cpFmXn+soUGlOJPsqBWshNf8eRTK2Y+3mPEPHjnkG57nRqF8T+n/dkBSKB3cGPj9GidcW+KETJyGYyxkrQZzga/iPKg4yC9C2vej3Qrr/JYcixIr+r3e1deCxDfet7Jc7+B4KLP7fIsSmvIh1HqdhvvY7sR/blxffCEaCDRNkBWFtjHBHdvtjHG28Exnkr5jOQAUUW/EIgWOt2Dxzaf0Otq2Lgru9HVeenefl9L7o8dL34iL4UKWU6BCCj11BZeHi6GZiicG97yckNoBDi5rQewJe8QK9dSPGY6DSw+empv74wPUCVNmBbfJ6SfuBGxPwTTyz0DZN8Y0kk65ALg7Rph2FR9pV6HNuUyXyMZTsBIayAfZ/PHxo80fhanlRVSjhpnFRkUCQYJpVlWdcClrsGxV8/8gi0zGmjvuO3JA5/jZ99M3MJMlN5o4cnH0w4B9GE21imaMgv7PnyP+Ub81azyOyi+L478EGsoXQHZu7M7zjqsRDewq3zVOQg646iaczqOLDv10o0bxn3Vy8kS6sPkQ4SOdLYfn9dE058vZEdSFbupWVXj5/IAs/RS27qTFTse60xtjt69rCW9BEWicjJx0KrGRtYN60/Ov7IDUT3OkXDzNkgHTtYzN1YCaT+xKyxfHk+557Kh5ePPH0RxpFImfem/nD+eYuxvneBX94o07OIcpYcFO93CCMQ729lo4Tx7SwvmL1lZCu4Xz2nFixU0jR4KX9PRw5lbnuno4ZPHsi85aeOAmPZwLrXzKIu0uzgS6OBOdJYWrWl2cV44XXW4fQ4+lecuYTRx6SfyAd9klQZ3rneMDUrpI56JZ42zUfA7drod8Dq5EX7160u+MR9fOruol7G1Tzrna8YpTsrUU7lcVO7CZI/lu5rmLG07FEe1EgpZ+TzipN0lzKrMPkh6OWaDMc85UAPSXDKyDKsuenJyx2vxzGTV/LGe4poAKhot78nfGcJKNrxda9n8XnmBgTP1aXC8jlf3+aIo94/cGhuv4bFb1nzNEvuec0VsC3PmQ8nEMKwG4ep+Uz+s3K/0f+/X1Yj6Vx3WL+fz2pjGbA0/tUve5slfd57Vn/S4zTw5Fdf/X8SoBHBNviX0u9u2N5XvqDX+TEg21ICzfW9flyb7IVL0qPu72lQk30/0BV6LUXek9sE/Rx5nEHdoqzVJ20F+aYQ0nUcT6a1chB7Bfv6zPte0EZW59gvIPzdMGJygfayUoNfKBwUJAzYdxxRQqu2Q6TQ/dD3p0fq4ishcXn9LfRDja3URI7kfW01/SPRzlhBVfr/jz/LFyGe4pvXpAH+/TAyrM7Jst/gWiy0EtgQaDPclqu2/B1+BzgCm8CPnoiAXdcqcG5NuF2SY6QUybPppz0v86zNWXmXv0fJGQn29e1XUqwOtpsUY+MEAi6GiQFng0/kRsPNvTDjnsFgQp/FRrZD43Wln3nK5K8HinPIPgzCCJoOqePSaaf4aEbharBXGbSPmJmgPAiYYfDF+1aYVIuPIyzvsMNEZ/ggt8GUvOT2EcoyNe4FGW77sjSROvDriGA2bntlzGMtsNg1bGMS7KRzcWbCFfZYd1dpPbGxvimLTisN42ohrxf25wC9+FQX5b2iJtVlfMnEp1LU4FQ4EcbKjHMurFjXMKl2FX90UjCBD/20ZX76rqdLQo7k1wBnMpm/ATelJpyVBMGM0vdERXACYUonIQwx1WDv5D7F92ohwcBx/kblcopbc2/MxOhN7EKMXhC7ejdfKjk1Er/teW9UnOHVw5vj32ldiPT07luF3X+IOtJp+7Hdf5Qy0wmz8fx91+1I5DWkVr/mhs0MBxgAYkuCQFDbwAyOb3bRs04G5TO2y9pOQAz3rkOhzBU0+K89ALKb5OQvLno6ALDu+mK/TpgDX/34hog1MwljLZWOoG4KG/8oeANtjhy+yO3ZlDffKkXm8nCaGwU7cdFd3KMNGtx1BN4RFEt0KGdYaAY4hpRv4keqGDrCzh/yld4Up0H6I1JSZZKwOb3/jTkuGi3rZIb6gkYPgBu6UOs6YXAJBgEMBNJqHw2VyQq34k4S/SGwuTQd7y05riJQw2w+McIcgE39csalPD9eY0O84CzUGrZpWOFrj0zNTeVKLSnI9XHa4yv7pQ4bHQKBg69Ld4A99HuEuBcBohtw6W6boZ1hQMpQS69q9SNkBonRKqiinkynkgMhmTHA90bjaIQxUTtDvO3kZwzgVnB0fQEnk+0+1SLIF0LoK44/tUHJn+labzIDxsC/CoaE68GI3szeQQ8JTrFamNUlxdYQbCM6fmKS9SAyF7YeaR2rlKFZsPlCGligRmcWVU+S5Kng8LUoIPGlXYdyiQdsaBKFKvVMO0JDlQG2HP5FQaDz51WsqfZrmHm1RTvsW6RLYQzKWIp6AhADYdM4F3hKHphZkpQEPXoWuoOZPsf6I9ipzXQc5CeMutZt1cNu+qnkbbRjA5yyfkhPoyfnZlllcqYNkhzwylEroFd1pSCVFqkfXIW9wa3VtydKWs0B4iY2yRM3IiH5cqEzOPmDUTuqZRt7NKGveqTbW9TlGkFlaV/W87MeA5HW4CV8ic+DH3S16K/Qmazv8aIuAjjpsW0SgFiFTbc6aVQ9wy+PS4SqfNTP+EjkGnUKwRnedozxK8XTjSRzolaJ7H+3pRTxqmx6bcIc5dCnuZ9F6pMncI4fSrETtTuM3a4htBWxLNUJ5PHhIp0PkIV56m4BfuTTKWgE1KtShzlO9IQjRf+/ECrTGxvgbtBHfur9HZK1ysgfDRo8u6LC6C+EMKRHCgKCAFedIVk/c6UqfESwKauTXfpUQ6YMLI63iz1Yuzs8eOHZRxI9BuoYBHjAi4dmfDRbIXxxuCu0jjRY2jkDMkg4q8b1/6RslJ37dczr6X0oU073423pw8NE7hTC4qKSMeR18DU3nVqKNS4ZTDHOMMFPF36D6CtEn7MDrODkW9c3LDdUMW1LinGfiBJI2T7MTE4oGDZtrQVVGRQA3CT6Sad+NdFVlL5FWH10BZeCk2qtDDxAURF0D9AfUITbAFyhz0N+DrkQSjmI93okIa5OtvZpQL/VGB3t99YWHLUYGacdvyXNuLFprekVLBoZ2fGztaBF7AosX2JbuUMQLJW0PlLr8VSGQsa0XSXZOdSPKadiQJuiKJ3YokV3QiieqppHnjGKxwxvqgorKgEufo5KMl5MW7sYehtridNb83v2G2d8HsqJTXjtxCO+NWO6TtJY7hX68aeFHNd9zrdUPcK9VzUUFThjTvu02hry9vco9Rl/sSXM5jnN6fif3wZCQ1/Pj7G2Qc1yL9vZaFTkNmd5OfZeXoRQ+635ENezfPW9e7aV4xThrUabbMn3nfM+bCbkzCIDftfH7UPL+ra3Nefm4gc+EDop4N94DhfrZ2oru3EvZcGMe2c+Lb/BVs2vdeenVSb1qik5RoGB/VNqSntlnqK2w4r1PZTLNkOR/OcsPrjo0AQn5k0kv04dE/XovmI5wVd2hDcqRNG4LkijK+oUAGcQib7uArdAowqFyihfRjuFy1zHZrFbAF741KI6ESdBdGz2pVRf4ChIdIVBYVrRK5peyh7AC3WMVuPlG3E5KP5ERNNCj9DPxOCyyDFbeULoRDSwocaqAgANmIKEYjn5BrhH4fzIesBPB+Zrx5lwD1iVZZdSql5MVYKe28mdEoBrmCGfIpskLq31FIBVDJomVUOp+mZRStofzAYzVUnBZXBTE4O6yijBKGG0SXgkxGASMCqkCtYOcUzDqELo6RNubvUZRhJPwFaL2uW5IpdchK8J/0TCYkK8lhzJQs1WwyxeoyL53qqsvcZIIDqhGBrHji3/n7gUbxKnTlvkD1UMA1EoBHj/lRqw0XNlB4NGWTB7nVntlw1LVDdwSX2SI4KYKDHe72BnKqiMyU/hOXCbTj0xYqhDpoMfpshX5Ih4MRy3KLfZt+SHoBASwpD8LXVttENS2y7mUMD1ertH23mESB8LDgcAWnbyGIenUglGOdOiqUxomlPTP1VC/MNz1Bh8i6lcgE7gSAAIC/7kk0Xwu8vSeKSMa1ibcB7pdU/bJjxGVLSlQ82U1mLB0NJek8CyzYe4pW2k9IF4saAAQVp7IYWLYxc1Y1IWSnQYlNLqD0qYHpZCl9KvizNcNHyn+gJFJQtwTeZtAwgl//B2xIqYlLh5YwtOSIXWJu5mTyupcJsl56OqnT7grYvsGnSqqOz9ornqoZn1Zd+CtSfVcFeSeNLGLGNhzFosUAag94jmQYzY9CY92XbFHS8b9avpHTMr5F1ERSfWAwnQpmAIX1Uurj0bFyVEfSvL0Fl7in7QXHhbvXc3nuMKVsFgFIsPy9ycpxzEHQcMyprrYPNQB81pRwwnD5pqEk9124aanVDCwi9/8db4Ini0Lb7tgmQ7NLVQQ2ahsP8VjEJjjs6sE21VGXr1J3rPW5XIF4m3ka95FtJeWEuLXEuobyQDdFA9onj4SH5kIHvS1yUF2bMDizx8NIn2P9usuxFkfPxOl4VGs5YOCmPN1zE1rogpKgwwXTXS74nsgFAdbAlwxoaICCC++riAp44Q2N+36389T3Ly1X1jvN32EHJ9kaIhSRc9GZ98VguHonUC53IliNHakaLbNvEKMYgdL4WZbb6yod4YqOo/BDciu3x4m+R0h2OT1qrAoqPrlXV5TqdgLyM+Xo/QalVTevS6uUoS4z29lsnTvzPp086pbuGPVcI6OPGaE4kkXfIQxPZis8qeD1goM0zx03n/pYt0ud/8zj6x2q+d6NUiou1glOtDHxFe7XwLdcguBEWRooDx5yHThOS3k1VOws93Di0pyrDWpcZX0tCmrz6KhiZZXx7EWeFBHkegHf3f0SWXOSseGKbcraFtduNfo+lBWXehpl2a0dJA2gpICVoT8AeGunKCUx9kRNCpmDvzOOmFUMSlYphURIYbzMfZTJdhbzSDEKStIGC2bzl5qvaB7GA7xAiVloGwoQNUyzPSVF8wVyBQdSIxSFhiIYSLexvgTabnDTgiBHs5PZlOHLr6IFOXhosa+mUFY2NIW+bCSVQJPiwCUBXwOzyNweOfFg2u9ShK/v8YG5Q7mlKxRtI6NBpFLuJ0VIwCd18NbCLLfJanzFKjmnOhkjV4mIBCUJyb4ti7b4cQU/t6vqDppUaK/Jib3guJVN/HCyLk6BQYJu2cQlqMdLzeNofhng63ZkAz15c4/m5xK2o9Pel60YCF/iNfQdlITmmnKccu1+mcf4hQcHHwXdQL1HlUs4k+DxbeVaYDoUWtqkWHW5DKvQX+rRJu2I29TXa9tETQJzJE3SnqqRDSY7dSNj7gsrR7AWij21Izal4BK02bE6TinYpVR6B0f7/VQn0OiXsSl5c/7iFVAoJS8fqlD6uq66kAW17sIQXwgrw3CO3O5IpBr1yRQgubShcfroBV9buFTzW7I10BXpUq0palS0hoMbD9UtvYTVfx9s1X+Ci+y9XQHGHTcRD2vAYP/BA0GrCqSdj4eN0Dr4CfOXs6EY/DdUZcDdvnWpCCXut5YK5b7N9cJG0aEcx2Uev10jc/XQl1oClfiw5XlbV6h80Ritgndv1eTv4BhtpBlJV6oqxFCGSCa9bKh45d9tOkIJ40069ojY38e+Mb7YIHWNOotRlSgsJXt9g1bulSrq+F61wfEbV1sMPltRH8TznVo9tjopbhSn4CwLHpW47MgPnjd+i3SLAWly0/yaSmsyc+u66xusHUV45i2Y3uPL+PtOCv6B8brtAyJST/+cetS/Mo96cezLhO941NhsU6wM29y1/EMjE1+Rk+Z15K+2RlF1w0ie95hNGbKa3zxpLtkYkduKFm7DHLO+CYXWLvgqvT1/AF+1YqfFHgeVng/3356hi7AMe8ddhKct1uXVIRdrlNNJlHQ1RLXVOjAzssLQjK2LMoPlkLad1yIz+xuaeaJSa5n5nLaZU0HKhSBun5lv5Pcu7Q3N/PQ9Z199YMgdytK3K5fIyuWn1/dd8uTjx5988T5Oqx44s1I5vlIurxyvVM48UCVf33ErNudrC3mI8q60Lkm355IshRnaCtGyi5Nz+9KimN43B8kTjNpNbF7hu8dNBK0s8GSTCFrPgkDJzzZFk414621ZZvLk3Y7vGC47OdJNWDyyNd3J609ajBoAQ8OLhoakidGkKN+3G7foPGSI7oIM0cHY1bFHb4nyYFRZovb2zIPGojW4YbgIUfPpY5MY7D/tMLZdDjYPjqY7dNpHib/od0jRv899H1oJ94NO1vMoIritkxXWxVUqslSpt1of6LUeEZmWcKfFEjb2llqdlfBBMewO+nOtHdWwodIC+ggdyYW2AKwnop1ZqVskEMJ5WNhrwavlcF7WWVTN8zkomRKBwm40XtDiJu2HGNdmV7KihWqSifBQ0AxQQVALQNCVocT5TrRGFFk0NWjsgHAozn0b+URc5hTJ1Rx83ixMpVUdLBpugKfK0b8UQl0C7gkXX8aR95DncNgJNOumznoa2HOUwX0gO0qBuuX1GGKif4I35FivghcBF4IaD47X3v375nMFyaIAHyqzE6ewYkXIT5xWr9E+nIXvhF1Emy6PJdS1D+ENeAn9l5oPBLIG0bMbsYZmgi5KZ1z8EOiSkqAhdKpV8vZ4/CJI9jkKBOAkHedYS2jViYWlU+aMQLQkfEmgCp/YRjULeu0dF+kZGH0We0u/hdHp+spLKM/UyV1f2VT8ohfR+5GdWE9RR+IuyA6Trzg5ZAVfHS6l85+9bLYNJGIKLElXyLfCM7K1FfLN7DdobfyT42D2n7XFtfGfDrXhU+/JVfEnDrftbwbsbew58U3uVzAy3dt4OHQx/2LbexubncCR9zIuXbeXce1YdDLJYcZ67LrFi//ejcWL7w23ytq/jrhbMX3iC8CA8rEHxJ4dexMkKFhUZUg0eraEBpu7twbrK92Hij7W8IvhfIClGdS8gck3qgWB3+ngatIudxRe3+GVbEUULKN8PC/mJhoTeSk+BaFRp5pITLpGwMTkshbkVVxI9gB08nrPNpGBeKkvAtKlTflYa3hhYqKAeYSXq9rP4bK16VruezsUbxnlEw2454KjC4Nyh5dsSEu7wNTzXCqX4hRHlCSBt3VRF2xXVh1FQXqq6BpuSsE0vQbnpEzP1tRJqCXLiYSfolrFJt7AIFd3ojJ1kiFR+Tu9PnJen4983s4nkImqcicufwOADhI7H7frm8EYjYFEaI8w4wwTSVqzhCK0K2ES6tEDLfori8eYFmlrT9tLthLXKtmONhBDDPVoAwlMK3tpeQlVzWrjNakZpKzgZ0DOmvFlerlpJRM5rZnEMCkc/Bg14FeUIMp3aXbPMt4gcHly5RY0g7hIMmjtbwk5dh0hxwmaIWqhmIqHKa6fpDnux8inGA7HpDAcdHfBMXTWPgw9u7LkZxrliWqYJeMn/dAgHaHK5jpCtQSoRJH9rYY6QtfLh04/KH3ywDV18kkE471QEboCDJ3HUF68BsMmqiPUba5AihJoviqENj9Cumwu9VjcJyNrCtUGs/FKNA0LeshZa0lq1lU401KDXHM2KqUkNZlG63a7ZbDmj1mNAoObQcvg57fMLZP50SSFBpLykj4O1rW/4bgLryP3ItxTSD60XKpQcV+SOa3QMltk+m91LD8x2TJ8rdK8eiRBoe9c1s3Ke243K692BqrkXgrfKWfCPJ0kKtbpzLhf5a+GcU+FhtDbsNn9/m0YF5XhTshGjMTF22vuc7E44LfMDYSZubm5JfrZ5TugIMHVN6PiXXs9c4N7E+56uAHEqFG6ZYpwg9WCZPe4wWc6bpApRG4gGXbSWXvJuJIS7xyFi3cG8NrTsMhuno4IPgHuRAP4gwvArn0r8MVRBN+3aQRfQEj11sXwTvOhSjVtHQTiVtIdkuqGqzAh10YYuEN8KOPkrbNVGnwG1SIarlEriwjYL/Abto5i1PDR5ZFogFaSQMPJBrZGdMaKT0AsApoc13dNjWIWabgGGsP3bZ7cTg+o6S4YsriK9oQKZtuUjPvVcbQ0YLnxVSL7vm9penzt2QvXELLEgRNXyedTPOeYpVzC842syX2CfIbY0GE0TDNvc+l8igsm5tKEfFitVJAWN+bmrebj9VKlgjERhUAS7iyM35oZJFHBgpcBJHzK/+3/iyticsm0QdcCEZdzjXI+wPQfDaP5peRN/2ZOVJBvWPrk3pnmj+SjZx2RvpA9tLqYIF/AkZ048UV+HnaicrTvjX0QkvEDj6xUiXhxh8TjbgZdHG42Aunh8Onj4UUvCB9EOVZEw8uPWFEdwzfGS6PDC2ALDu8s5vegX4W5KKKftziDwwapw38x2aDnucvUi9DGgewV3TT8QodTl6ZRmg/lnGGMvFmzh5B35CrroIcLyQOTDrdM/YFwl5F6J5D/VeZAdyBPZ9PadzoneGahK5D/a5ta16zUJixAQy/r8POuF3uKyxfDV6/Qu+l51148cgU2a+tx1/q9UzfPIG7VOiMmItB/L7rFH4pb/F+wBXfHtu5xfjQ5kD5+/TCV24RrXxpF6IPf/n1/YoSlE+4JvYT859GPkMMv5JOD04C1b2+6qjKxzcxg7bLN9EG49/WE+iMt6TBomW6ULKgy0HFrbx0u+/GXndSBR8Z/J/dTAEpuBhvTK7aV79M2NNh8VsYh2W0gT6R0zO1LhmcZvRTl9+Nn9sDw+cBcxbkhhLtc3Ed06C4BzqEJPNgRjm0tiX8iiTcumRyFc7dYLmghCP/Gnrz/KEvTSZiy4xbfe+IuXgda9ZGox/+ZEvXQ1HqMg53viwmjMXLulGyc23WquUf5VWPUs9wbANCU3oRBce2utljcp/rE4v52AwHzjcTiuiXMD0fHmfwQJz1zan60Q5ztPvsrYWm4jk/x9m4+xcc0b9+aThx5Rufo0mL9Wzi68dgTsRB9Q+yWbR/eJaovPZRSrSsb7D2oNZ/yGTCGtfHPrJHP+LD3xoxqD+Gl9ceUzJjFrB/fYs3tk/KUOpBLrTG71zTKlYq54dl85LOoknO+WnMo9AXsEXHuNwATPBlwPOyjr7SeaTI8dl3PSwpWFqPR7lCOieRSo9pzvDe0oi+xRLrVByGfnD3fY2dHzcvs8PDhRC+TTfIv5qbOn0pU7D42ibt62CSWLp8l16eW20cznP2ZZ8x06mryUtJ8EgIX92BCGvRpYlCULdfdlxi1yUY7kt1M2xXcINIIQm6OTHaiPQicRUbWPkxvcNF6uQ9+E0S0+zDEBt3zngRe7S8gTP1aOiig29iDMmW26xgM3KbELqXUfrgrIWQxz2bw4WSQ1b/uaPwPJLTA0mqVfIzMnu92hy7eoQ8/mXT555D9j5jeeP1x4aLFP4/OSqaaScfp+A1PfC/BLB3S4ay2fcMozA7kIvJi0nzUDeTZ3H9wtAPpquCzBN+JmXSvyxxr5yJOQaaRZcDm4nIrzL07XzExaRTR9UxjpyrtoMOEn95eu3tTCocnG4FG5ubn2oabQ+P/NvCIvWszw7G/HMtw0aloGY6aclsb+l32/Gjbnp7TZ89nD7XnTd32FLrNqbl0gsp9Y3tLPpW2oX/AUdSBo6SSFsolw3OuCQ5mRbTqaY2FmWNo6ESPoaPF+1m6FZHLBvxfZ4oG0BMGCdDQDiwRNseKmrV2ZIz9+tMpAHF67zQqWu/Ep6Kj+rrYB4Cr+eRJOazjb9w0hq3TnIxD/YyxNpZrA5aQfzraobfzww790maH/u7vjblGc8mGKzIrXYEhlkN74CcY4t+EVaxbe65NmKBIui5NoWXWwflMyCQ86DoFEL0OTpcw6w07H0uH+eWeL/DRVerRi/QTrYvUt1MoI1vXaC6AMDHNXB0wnyQyrcSm+348EV2uARaF1r6GkUKyfbkaEybuRE3Duq6Pp/IM9nExh04Beon0VuWeHV6qtKtoH6m/pKc2iCz0313ZJ9nT1ZQIOMXQk+uvWmBqZhVVTshKXA0cs4bWleE70Ve0wMZXyGXuXhstTUjk3DviJfg191sw8z4p9nRor/SaZtPeQp9peEYTG0562cpTVFNEFM2N5SkisoPLyo7FJVABS9QOLKH5x44dug4fqyAet76C6NghDLLVgluZW7KxwEoRaRyovh1r0jYMOk0p7VtYLARTukZAtANbQVSUmYC7kfszeopYZ9cJcu5NnVMUb3d2CykrkcQR5TLwVEzjWq3d5nMwpEn56TSFYxfPybhVDdQQBROMEleC5dWpA6zGN5G4k9MJzeFZvKSrHJOxM2NPRWLzN7gnh8dLYZRgiBFpa49jZQe2OLri4bcGx8PmwzYLeZ9evAhtt9Z2BscH59/3vO0tZ9w8UviLbxLemqsc50/lo+UL7N4PWb344NDVi9+0Ihw17PeYYe8fe3XsI7gGP7NedvcQ5VDFkQCgFBX2EBtJlDcOXrG0sUzvttxllAZdJyu6qrvP9m4ye/GUM2ODBGGQFad9gYLXX7axSO912/Gm5nc27cyRUss/Er10LuDTYvPbjW2MbMzdgPGF+9k2fGztycP5Yn7TfTcW8SP8BCHhj0FJ+KQoANOQygy23rq9pT5jMWtHYNbjoZQZoWMJi8nO8J0SwwBuy0Y+XWXkp6bOdKO6nC3+h32bVMqjRpljRpFslPUBi7pSrjaVZHFXy0qm3Hy9XUxZBqsuuZnMdHj7+ee88PSJ8844Ss4Ga0rzcRA64y6J6keNlY/vWd8thYZW+65rV4do06Bh+gYiGSnPs5jd6FWXBqqQFZx0YSAlkwcROZtLSw9i5/AudFgKeJrXgt6RCVNuN8BuEjFD3mGXgsAZnh/nuxpuiNfDnGMxGaW2SHwbndj6b9s5DT/oipY/bEXLbFe0VP3q6gP+9JDTKAPzMuNh8Ln2NWIDdKEbRs6iC60lZ98jDx574fGPtIPqHdtx+KcNiZTwqgJRMtlUwqQTVkk2kpgF2RyDUNNO1392jkPjxJcBIBNjjdgTwnykNhrGWdgZ0ArfgzLhfjEcAb122/ZgKL9vAUmW1+Ohr+zHQ/9cSczsBN7kaDdIhIvZgP/sQ0fxT+kucggDw8OudvMnml1DQTHqEcO7w6lgW1VhpfVZe2C4usK6/qv7QlDXMRIOHYOQTCjpdRDV7E+RbAsyFPK8dEOGyBexKQ4GQTtHElnLylD6gHQKKQm1qgKRLUeJx61yUtGChIPGIiZFFH+sM+PiNSKP5w/yf8C0oexCmx48DpKrcY6rAlbNM0UWfBnsKL4BaC/FcmPbm5hbABexv6booj8F6kPLmEUu5dgVA8DwOpArDpbpOdWnFV1cdEpyPOGkE3A06IXgLxKAJ1KkMb6t5ioYqdJtd83R7GLivQBpa0nFwKWHLXoAteFjbsFf2rfkQzIwWXeT076K30aGvIkgQ2hsABapvDkWiY07gEXaH2KR0CtVgT9aBuvUDCaXf8k2bkYEEFEiKTSlQ8ofDDHoNSZ24e9Nwrxz3oyH1UWtM/eut4aSLTrejUFH3LWjIIZONdG+TxU1Btm16I6uGiTtAkB8ogD8waxn5wXBLdXN2pFSAlsKSU5LOVrA3RLKeuLWT4jRjFFIm05F3hBs9MuRoEJXio43OVEyfaQ7Cc/TnHLWBr/mtOukzeJ8zp/JJIvoI9XvM+Xmq6WAN7w4d+NlkUAnxIRaM0OsDbSH1eshRsxq/86sdj6woe9jSgAs9C4zqaUGEtoGbdEgfIJsfyW6M5FSdGFE2/Yqkshac6S26yYlv1RyZtLSBbPsokKjyYpz31IDbctCI2FO1CZMP4vbCALJZsrUXBw61U+Y6D+BptiXjhouxP8KVf3Kta+cFKvrigX9JaxJABQDaIuvXWKiu+KUUikksxyvJnL+H4PpRAUZRdE2sjZouSkGIYBslHZvO3CdlBbXHv27k+UVGlRCl7hmbD/0Y16IJcqOOcMBUrRKM8ykbn/+xKxHS85yW0LU7QUX9En9dtu72miZqeToGUZMK2Zz9iQzk6e5ddsuRGY6XEpkSjmf03Iw04t6VJy7BWLIWW3B0DLDpICMmslGMURKQW4BxDCfxNIUR41ITu08f2cW1JxQ9QSi207MuVbJzh5LUgPkDcmsP2DKK9WBDaIGaN5WDV7UlSRB/jNH5T9bKRT57jWRDCRDmDyoF2HyKK5jGjHGn/gNgIALEGQ7A3D7v163H7MlJB8/9mEdBfnHvXQHQHvXb/FwvnozrN/suDi9Q1s4ek8fBduHLFhFO4HG4Frsgdh6es/6ZsLGoB1+94PsCP2DU0ZA59ROSoxd+9SmTYPEZmgccu1JCbHNFwwF8DCf+D7ziWWgud9AudCFLfC77r6DjCLKw50+RHznZcToG4esffWkeEtT75HemV+Z75Le4RbOud/ZC90yO+fnFzqTkQyuj0Ii2ZqMXNoS2XnUyXGe1w8S2GF+803mN27sPOy+37p+IWv3o8a6Ha3l/l0s66RY+Pn9W1rrFrKsk2OvN/TuaaEMd7Dn+nuodi9SC9VCgPUst+xUnW6wNYPqMKxXq7HBSmnS2tdqAbhYdb56VFjtKcKjwjzS3o5azp0ynC+GG3hd1T/3OzSowLvsa/xxCKnqvuajaOY1zwnMQDwOuG/S0LX42i8JFj0p/wcKUbMATKJqYIMOn7qZfBZylax4Rh+FFxyVA0IKWi0iSHrxNVo+q3hIRDc0Qgtw1OtmhtgpE9dskDoru99SUxXaBGquBQumo8rOfMDd2ywXgrhgB+fMvOmzZq2aRlGv16am7OY1JMgmQZGjohKnhTJGXylUylxh79JMJY4MAEXx7WFRLMLnWGOYp5x/spo2px4+FVXFsz6fTPuU4VBvFeNTZr3IEuGvoEEVBxvX46j+bRcKG8cAtN0tfOxgEDaOxlIfCpsmX93SivV99VZR3NFWbPTl3EvhGcuR3rM6FzkC98sO1BoUW2ZNG4q0BtWCr3Rjra/qSZT5jYUUHwdMs5rMqmbeUmEExXPRo7F51oyQnWzCDIS4nS/rj344Hq/mk4e20dQQCzW3gKVuLqaDGwO/Xz2Ra4snPlSyvQY9wZWkU0uiAZoEykxG9zGrYLuuMJ3z92T8giGaL71B9+F/bAb6Te7nMKkbuxSY2NcMWlkdy8jrkPZknfWSQ4wn9EfMB/RHTO6lvebNDjevUHG6jbt2fJ3hrEkxMlu532zcyqaBs7htw76813ATeVey0TYNNjbbHesiaBoR9IvYaf0jChlzw3AXFpoYL+OPl+xuNkrRrittalQ7rc2osbna+werqcst9emDXNCgcOeQF53tslI1a/S0vM7SBI24jdX6FNegHJstlCxe/Ek84VSV9wXw04S9b3TYAhNEDTIkUFRZCHTL07xZh0PxiXjIl5bKNogvxQDM4rwQrOaBJwVrJqXA5LhfIF7S/mSuUrPwWqrVwivWogMEA8If8l6sVkkJMGPyLrrNMjgXDBBdQp2Wp33Oh1s5K1els08vlVKDepBdySXqicyMnzmSMjOm03A0tErB9LkScMBFgdiyem7FxtslrAzYQPfeZ0oPoJ4NTKCAP/hKkZfQ7kTa8ZBkcpZytQBppJi8o2TyBWPtdfg1MGPClU43Hryp9FMUT/tTRB78QrTNarmCjAArwY6fBw56CrQoL8FdOJLu7Ngdw42l5cPj2w+S5q4aUVb2lK1lMeRnbfn44kSpA37GeLKFfnYi9POPR5CPffgWcpi/o8rwpVAZHqqMbSQzhwYIoMz/3A1lfjIz0veBQ6ZGejAz0nzPkAz3Fz0eUZ8HnfuwzVPbQtNogKE2BLNzH2g3cNZ+vWcWj38iAOuJYcNg1FiLpPlPW2sacW7bQpvA0y/tzMGeB9b3hMgM5aaytMuTpV2e/9pKy4jZpxDaZz3S/KZu87w8OkN3IZs8HTDxv9sJzpSxa4ROGw/BsK3ORXlrV+iSYLtSZXcjJgLc37WpUw6sp055S/P8wdQp72+BJef+YotVxFtwV0qqCZZx03aqWr6GVnBSMqiUIJJD8NE4edmM4xYdk0plZgsncX/U+pMr5qPgZVk0WvCe53G264qKQasKy1br2srhhyFzocfw80y5l0oZfbynL7vzcXCk2n5LysHVXQ+czb8YoqvLLVBdXXLVWJLA5I92Ps5+rvsgP6T5J4PK+lvGlvtlQeEH3H9FzvLaXXYVfitkPbvvBfNbJOrZDVv33qnNT26RqIcZ9k5uDYY9C0P8t6N6ARNLl2QKoxgM2popzGC9qikAPrSEU/AZv5t+8VEtyBYcKH4m2zIoVsp1pImyU0zY00X2SWo66FJCcQ2kieyf2WJ2yrcSpuK9ddc9pWhlE0hUc6WClj8UypwQ00+r+1czK5lggWOfVM+ZaEudnFJwOVdPOVbeBaRe8Q5k6Oc5Utv1bIxeA9/kvh6d7D+hW2G7ew30Vce1/lp198/x2v+sK4f9/hL1JJzZp/dVwYt9RSmVL/1v3kJrYT52ISRIYjWv0zdddhoM8MBqyKXWYGe1BUvynYBinnqALl2AJ7G2az2/q1COpcArD5oFkUC7ygGVHxgvs+ocrRo1D0iRsgPOg9eKEPuxEgqsBP/HhkGIiuLXfrJb3cCr0oXA8tBmzRZyMgGdou5ZiT0gUSTvMbIGatAEis8CKL8crrn3A4aCKaKbyhncvbR8NiVB5oOuawjnP/+s32Xm37q7jcJ4zD/xdaT7AnLw6wBD/PgOZ+Ej9JBqvT2qZbYl0SLzWu4MatEbWT1MWrxbcAaHnvfWFigw5YfjK9yndoDZ8K+6ek7ZsOdUZz0naITm1vWcamhnQYINckBsCJ90JgG0o9FBqNoEcKVC0ZbiEDCfpS2QpJNVRcpcqqkSmDkwNI5D8W3MdL06VgfqZbTFhVwhbHHdSMCOmUfgoKC/U1m7K+5G3S4QmzgGggj6XGWh+XEWQ+K8CsJc9MpIYWbfbOgv3wCiTGBB/FaKvKltJYeq3XMuctYWk6vmqWP1Iuvb94v3bTHXumAsB3l+j4M8t9tB7jvMQV7d5yATK8dWamhwqtj9/hLukmfS7YLdRmom21BNshFS0x2+NB6Oq9pXGg/nmQsh0T1fI5/uAWimdgygCfRihNBkdwqAk6kugObNA/bOLwnSAm2sUllHOVfIy+QBbgH9TPYFpE9FoxucWWLgzMI2wJl/0w3O5KhqJUNnTj1wagNsJlgPBq2vTy3MmVD7BmGvGmo7snagdaBMlwDxm+GrNv0q/U95GZ4kYenrNxBu+BN6LRGWbPSmeNCexf+szxM3abO2M8iKSP2RW4k+77TtyPi1CZHajM7sK9ynKSUxxDJNy7PQTsazNQuFNELn+pRS3SwTVRyJ56GyGaTRKayVs8g4qCUSPhKHtEKzmbikFBOlteYWCxdnOkNN3ylduO9LHubRuAaMREJUIKuom1qeYItXWZ+OCsNTWB1YdF23WU9wBsByVbBRJGk2S16VrAxXo7SPa7mtFjOZSdohbRczSGhTJ36ERQU+9iC0ED7Eas1xstBuDu3uLDToT0Ld9alxJwem/up77WvrCOlJpClHleOFkmjr0+dfjZOb2k4cESTMTfF1Q6Gbz7pprEtM/6krS57nGc8QBiMCpm/Ik5FO55MgvEc2fVr367CBDZynaGi6YSVUnmbRqHAyyKL/bYTc9O09uSmiVJyPctOHdeWmQTYr92amYOmlWXORZs0PDLNmcPdjadiM8uZrWJItsRz71RyCVvTiyz983p+f1fx9Zt6HwDoGTesyawQWyo6R4n4NjueHowgNR2xUXKo1PFutdyrLUGeYZwLC4iw3R8hmPBlBo73Ei8UnYI9BTfNLdyaTmNKwQy8XDlW0CccLOMrfb8yD6Q1nGZCMheV9AZ6U6lv5XEp9N5nsY8X4fA8rxlUPxS0CRqVK0SepPXv2BIkKOdeZkAWdCrZ6SvVoQak4blDIBjMQRRUkKA1nMikphZ8ya5RLBUiZ6An1Tc0PDSLE4Lhnhhu5xMgmbqCDJCapQ7kTpmKH8eRuDZ+dGULjN356nT9clB/OkSheCsOVxfdFp5Cp0kujEV/80K1lFDfhSDKhD/rUipZHpzx80HvtwKIEeDJCyOkTuiMqVn7Z9fa5l4AYzgG3EBkmQb+vkMW2LtOSr49EfPELoyCw7ED3E7aUPRRIaR27LyC5RUIfFzOYTRrAeBf2FcD/B+dPO1bROUVTZJ1zqk8Jt+KT7a14ry3iXQB4C59OOOS2zTgvmKD292Gu6dg0RB9voXcoH2qCsOfGbr+QhyJJpx1HuRCygwUwN5TLDuUFQoHG+mpEicw2yrylcFYG4p92jr8c3bmhDEnIwtSp5hk+n5ofV+ObrYynO07+cPGcW85+F0AyWJXzPAhnrD582clVnEA7UjurXHOgX4F8AcKd8bXve3nIMmJWLJl7gU9iq4+OlTYe9M4HWRPN+yIj1kvlAvIwkiyUlPqFdUEo1aoyVdHmspnkrO0fwBIYkv5KMHFG6dL6vcjjkW17tpOh8gJEtB1vQgQ9F3fYzVrYpJoLMHJu/oD3c0Wg22ktBjmXyvGS5igaqJH8dEaPS3TnDQa6VUQeB5UEW1RFq5hPq+VD5bxi2G4cpRyyQi0deA3NmQiUVNrHTe8sB6cWVtunaV/sKNi03jrKaeJ35DRti4xk0zOGBVZ6iLZ5ytxt0ZFwiQ2PH4Adiej4yXTuN/AAPnYgRcnx6ADOgsjrmaOzkTD4zvfaofMWSjtzsoInGQmUvToCZPqkxNe1948AzL5o8zXr3Y/AzSt7F7jXb2c/beh+dd99+oqT5xICTU6KpKtzw+peNmPp79icFKM3P+9WC4Fwde1YVc+jN017M5/Sfdv0VW/vdMPq7sqc3nCmT4J1X2eIcS1+LLM3RzlKcrQH8xQJ6DVVNgr5tNTuviTV/EzOCNgJv6ttzGdAdfDknfBhow46+T45B/fN+y6mcmuX7Bsiu3YSTuV/TO3LKkJ6ea4lsmZjnw69QNtEa4aIDsuLvs3djSbmgdhVFBfkmi2gXVgF8MdITwXQuntbJQA1kZCkeJAwR1q/5usFoTQAQbtgibXJI94DRj+9GIT5VbXMkGFhEvYbD7KF9bQzQasEyUwFGfs+dDtQ06espIk+kia7KqqFNBZYFdUzs6mk8myYyKJdJnSKgLxL5U0qyCRntMAymMoYuGKfwFWmG2K41Wtrmp6s0L3XW8qepmOxT6nYzat0OyH5AqeoiQa53S+5DhInzdJTQVJxsum0dTVLYMIqwq3ZgNN5uVzR1ydqZRU5lac+H9wA7nfDzdtc1PzpWbxtE402H8NUxqZmarzuCPEgEZ/YOwlWFSnIZBQbYT/OawU7B5QerdOw40l4H9t8j0Ty2lXBDyvXuk8Unq4QJbmUwCQi/ZkmYp1KkneLh4D9Ff1AgELIC1aSewO4KI5Mq2LDeckZlt2u2KDMQIDmZ+cF+Z1v5TKB0lwO9mAcZIYsE9N2Daooc4t2w6t7dVxenBUS/dD7IJ2bn53nghV/0kMK6dRZ1UafdvVYQSlaiUTgJyZazztrg0KpcXa987TvIkC2N0xG/a2lkyGzT+5oijL7kIjaJzENPif2CKmq7hQgwy/v0fAeSe/R31zCm99GiOuS4/7cCIKOQ9W4P7edCNdW15bOHqrdeC4/VFz7FduJbSwZuIvZahGsIFAkIuNxJtW2YQmyOd8SdxvVse4mShqqYt08Y1tXzltG4FkiJTAklXMthqTCMIakL23HNM2LOmjJB3ezhmQpvxI7ZFRouAJinL8fX7gaGFQg0hjd9DC2Jbwh5R/rLsW2Uy9uRY2aC/A7+UqlXpYG2T2UBeY6itRnbq9cLG1aYplZm91zXFxHjzJpsCaWoMq+btkCTbc5M292hKa/vb3CkJ3SH7BTen7sudTc6/mzRomsG5JmbSdd5Eco3/p4sjaPuH+5Ye318u2c7Ms2Ldys3qJq/yZquusZsbRtnfUrhpds9LB/nNn/3pAxYTFaCkaqo46R4X6xnfiN4AxzXT5a9WRWk8Ntv83YXeS4Mw+NVjZprnnhYPt+edv3KT2pBdRjT4YS67aqsZ3RyP79dp7rx3ZG9/qH2zod14YS13NDD+XcJhLX3omvsBP0YACO3ksjaL1tkkOkUY12kFYPcaM870MkMlhIHpcjTAogOo+s6Uy2YXeXyggt0akOlYSoY6OuDpYZ0b/FqStUYFbGQB0MrCs62oOyiD028+0jmOhWaD5rGmT2dE239apOVYUKGoalJqepU34617x1O56CYk+Ox78BtIkh/L2OySHZA/oz13VA4cKdQTwdg0kdNe4wGx5BzI/7GBjR0SDhAB6jnW5wLk0bmkL/ZX5bfnQepxCB2IbmcaEQtUwRwqUT/wnOsWqsHLssdiOYA9hslNGpLfShC0NwIdlC3c63KO+4xUhOopVgoc8Cxj1a31B4YVNAGWVYjE5NYnRquRA4KDRNLwdgTcquAomDSj1Ipu0LaKWu6nugYkkrdclV7MBPg8pDUV0TWtbKs/DYrHeZOV3XsXqKwfZzvb2WIplmou7mSz6GvRM5jCNUvnFcogLgXEiwxl2N2B1IqDFsfya48HVn/T6YI9/xSgmnjBLd1FKBr9iZVMp6UNLDSggtGUuBm7GBKaBi5L5emShh0me46k2WriWaXyNg5A18WjvGMeXXKUkhtSt5WX4KvREjcF+DOV8clvgsdk0DqPnQ9eGPj5fVrpsZjIjVDm0prDA2SIaoYDsX7dNLSZ1oRKiGJgyL+i4nweL5SqMPhYqFuPdva5RwLSCCWrqoOzWKzdAoNiMFbIYcYjP8aZ+hhMsNs364fL1WcPSAPNubsuxsoubFU8AL6kR19WKB0itn9oKgRQI5n5nFhqEo+S6WJx8FZeo6IBeKQrHEAN0kdSct0vWJ2ujzBXIHFv6y6aRqFxwR60Gy4Zl4K9MxDRfJlE+ZmFCparmZ0lWqjQSnwCELTGcpFwFFHlU1CTJlOrLmUIeGspDqjoJVWZn/M1HyTIH5I1Y8ANEROtP0meQPM3MMFfgJrgl/WQQ96F9CFyZWizrM/CaZEW2NbUD3sR4LuJGDTBPqIH6uHeHr1EUYq2WI+GsRjA71EaAwyJPC9nMin6+kjE1SKLdarXrOdPN/BngGRVEN8IybvWnqGXUvnsljjUswDL0I4m0+PR06hsx3IgT3yIGO8fmwNW14btKSU1GW9Zgoy4IXdGdZFiAsphGQgmDahWwK2JyEaFmOYiYB8DIkNAQl09e9RuCk/URaj+vFhcrDNai9wNV4wwrS1EWg+2tlfEdmTlJYDLNj+AjuG1fHWPV1PS5yep+LNL+eqTHURREc3r9B0/UBNBnj17Xx9rVz5fXFK0NeDGaMPaEFqYzd6tcdQ79OpzxltPqT6YXpUw4nQBwttXq8q2f35uZ3u5hhq93MsGc/l5wme34i3t+bSySsCTNRkiNQBabOMm3Q3burQffa5lUDyGA5lv58A13NFNLSq1FCbistHaFvQ0ajfP3f3W/XXDgCzSv57vaKt6FE2JND2V2ZZT6BpfUp3HrP7OUo28Kdt53mDESxoC+ObxQsJRdb2W6j13Yr3Du3da9tszHzNtnT0t9YXpq+oiKAnByjGHvWW/sXWDVoWbUwxvX1P9ud17OpgoBz5piUBhhH0jcopJ6N5T6N81YCI9XjY6+kLGVbYaTaxiGV4Bp0oThY2vgoRhQQZIj4B3fOWMIczVdt5zS/MX32BefncRiFDQ4sihpqW+QbG2t/LI0pysHltnPg/5jVMFI667VPdQLPhx7r5ks3kvtg7vBtuMMUaFQujD2NkkT206i4O2zrSn2Kr/Ybu39Ce7h/dvoPO2tCopTPfMaHn9drxO/3dwceNbVa1OX8/rm51byi5FfJP27HOk8cYp07bQeNNZkOZVFViQm2OPBp7l/Bqf3M2Jvu6cUBbjQ273toMeDEcLrvexD9f+l6gvBH9BOErykJRt/7SRhbBTLxFmbuDuY6H9IYhTzp++oUp9ioiOG62RID2K+udFm2m/+GUuC0dxPp3S12rROGmpBhHcBgiNJGf+BuNfrfsxy9GELAI6zNXVK2JQsmQbYgqKaSWtZpWCskbl64cjF7KBskRDGRytmXqxKm60DXG5JiCFXKQgaMNuQiBcb+BGNoEuhqLFgN4GRJ0PMLGcnCs+aQM+tAwqNd4FXMYwqevwUaIlQYlIcGRKP4NI6lUo17LZfL+UjUia7NJHTQsHLc7zkpLomCKuItbs5WsN0pSxkpV54ASQ+VWJKnAzuhkMtEm6InElICgtbyHmSt+MlgchENeVVAvuBYmsqDkg5tb89JW3rhzAoWSLW0HliKShn+Od2b9O+Di1wCZN+ia3SCiraRSJ8L4SeDPW5hIvErf9ZLSBJYfTLa+bdGLCx3AYw/CbTFc9axsLCF3h3hYJnvVppGqD1MIm4rtg6GIpR7Z5t5pcntLPPK61v0KqFgNGEsVtgKLlCxgm62Fa2mdbhWMpD+3irXSmAmXLrja1gT9Zrj7z+46iMsa5ZDdyl8ox6PCFa+hidPCVZefY8QrPTahIbhXou8fgcWNp+1RT6VNw6z2UngUKn0WHD6j6b67CfAfndghYHHsuXlwG+8j0qxj7szH5qOddAR23AqDtEkk5Uq+C/U0BQJI4SVTbDc5wBLQdv4UG1fOtiOo9MkfCHZxL48TWkh0gtasy2u23Nvz6bLF52zGEhBsRicW0wmi/ehH2FfZO1KvAd4mR97Y1jrSG0PUa6nTMxGznvU6xFJaZ1E+ZxfFtE5v3iY3f/ESZcb5UnyoC0YtPm7wqqbEgtHpmeKec/Lo1+TdnT6kVU3tBLkCtDTox6EhrsaelBp4lwziw7tHuTIdh3VEkfyAXnEcM9YeyKf8lLpVDpPYYc2gMVfwcLl/XGVvi/2I7hI974t22Xc17oWW9chJXLsS3pYl651P/YmW7RV44Yi2WB8jC7GCEscamGwN6OSFqCXi5aasDpAMUKNVSpskzzElVHLwoNWF/HTUO6tBq728jRHES4kjzk+/d/2HdxoNfPwraCSB8+KFqvCrDtPZk0bhG7YmvFSDTAP4XLCRqtO2eksRocsioIh6K6uB+jR0/sVSSZuLBsQNNyvTtEBEyv+QnZlBaNxXfcbFM5PG58oo+KamCmSj2ki2oCqJ9FsCyIaABhoQqpJBX8c6Qqq5C2bZCKL6w8E+DRcCYLpN+/eM23SvQAkgShE8RpJhEfiOlfoogFH8wcN7yTT21akyQK5WC5h90EuLOTziyUVqZeA29lEg551r0A2LkoLqqZ4SDN1M2eojmqkdD0hJ+DudPFp0vNmsTkki2DeT8tq4OE7C82/jCOdwO6EK08s6VldxtugaYifWpCwF6hN7gWKL0U3FigFLXKER8UZyZ+IVMJlP2ucJi2QpCYZjB8EFSuoAAFAhUATExZ+BjyZ6gOeJmIygV8Pv5egqFAvqNvvZkQf3wDfEw1b18ZeGqkzjM+2RLZ312xw/4/G+nyucvR+g2rtm9fV2muf3WJcG5oxNOvdPFDFmX0zxS4eqLkz73PGXHlsciXyxC3EtFN604xadaIvzVj74EBW55DM6f8iT3jx9rkCdibnmNsSA0BOa56xG6b+6Fa3/LdgzFTvvfLw/owjDmT0t5jBTok9BYOcd66bzs+LoSpgOKEn5aVNp+87bD0yYCJ/Y+9E3nIdvjOUJ5/ZbOK+9sldOcanrBvFFyQbm9VsFA+wKfEML5nQ6QZoPJlNR9P2INuats8YgPTiXrpuC8beu0kS8fbWDN7n2Go2oMORGtL9eDl2Q+z22HfZ2r0YncsoIRAXWI5QWQbJ6Xo4NqJ7+/gudYS0CCzkiSG37Ygvw5+RlZhqvXosPeoeG6gqxeNQC1TiVMzIm8BqtCnpKgdxN00mumtpcXxFTfhmWlFUW4TjUC07sOpwWLFGE0czZCGu8xJDifESgGGShv700NegS88Jzx9FzIm7mHHFm66jRUzxHSWQPp548hzVR6XNC+CFLB6rJmeTmityKhF4rH+XK0UVX7HS6O/oRj6b0bLL+UQC/IzLikuzCkmiqD68VrbTCSKSRCobZJJO2cHgevPX5Q7nBe1lI0lCfScknlelNu18JCkySMTHhVTMvUALekbsn6gL7ohUzAbeJtEB9WBnlMRkV5t3nCOwLIwmNPP2HRCaWdjI5zgAsAa7JM2EmT/yWzgG3AN2WqGGu2W9n5ULC8FpLT8sr//7BWcmYB4ojn0CkomE+c8j6tsUTnyRv5hXgGp4c+xzse/RUcFqVQwXRrDrf4gwehnWzWL9ftxmnETb/tEg4Q/Q6aBxgTx8ipZbrdHD9XNgojDR7Ep46EV/mwNjkZ33aRHzV9ZENQOnCYqW683d9zFHjz7mvvPqH5zHvbK0eEqxdGS+UJg/Uiqeslg6fTYLngnbcYocgfS1g4BqpTDGh9q26yQhb2lUU7W9KVlO7eVefdK97/2jeF/zwQYU18AvR1UK4zrGI9qJO8HAoCCN/looNxpaO+SGb4QEJ5EDrBt6tIlNutj1cmxHv8h8h75yw5eBw8RLooCHr0RgnhbTDb7nKvvW4dgFQAK6lMg6BKvLg2mXsGcFp6U/FxauQK10jeF5KMFtgclLSrZt8Mw9jAS+7NNb0pAvFOmOH+pTVJ+2wuHuRGkaMfFRzqzsEhuTxKnfsRfYrRdwrBWAZvsMEWkHHqV0SiO2Z4ou5B++YWbRCUjCx9A7MO0ZJ+Qegval5YTaly3WJTHUvrwIq1pxMBdRVnsZaxCyUKjm44DixRNyUsc45S1ag85M3tFDeoKBiBBxnlwzZbgJT/eX8ve6ClWFLeDF397olf7qgRWfvVbL5jLKtbxumjyGOpZFkg771q+iP5KZLLmR/iWcRFc0A0MZs5uB6c1tBqZCZwkvUCsTZU3QcdeC/g+bkCrSvbfF7ryH072RKPTHYlq37plE7/oRifjJnaPytd/jqd5rRmD0v3so+/vt3aSkj2Fom6+jt03Z398X+58dGU6c1PuWjMcd7yW5z+wAd/z9T/bt+2gm1zIC6Xx8vIkJ97yTfvE2/1+HtP5JQ0nrH8n2fEDNwP0KCJH30bhIvQXBKmj5E0zLPGoldKg2nsDv7m60ASLUg9DbXFwJBq71Y6m/u+8eOVs0415uRC18+q3IaGxIpCCn4yrtJ4DqTXMhuCMoJB6Pq0JS4zDDxtjWiqu0DMUUhSJK8EBlguM552cbabvkkP2PmN549X/hokX8O79B5ZSNYtZLghzMk4/SeXCcCPG4xr6FQy4chSuJ+xlHW/VFQG1VV1tQEyY+cu2clIHjxQU2hEVjR9ATKcdXFLCmZZNoRgOc6UsC53h7cnbR8mbZpJviG7pZWyJ6gKOUsXdasyu2VkBTHevzviufiTxBdsxJ0RRkTMARr9f+b1NOpcgvwEr4wti3/8D8gqdq8V2LDS2yOzpnr9B3ZpjQJBKzg8LSQb61SkFfVhGn6MCm1ZS9513na/jWSNYyHk8+5Nc9xyWc79h7DPA73C6if0bhKmA9REAF1x1fnN03X5P4+nSdT086GqYWll1LCkGxmris+XlZlkzkhYS7+w/G0W42PTQZVQ1rlVIy4aRocoqiH3hwji7EAMqo6hnPYxwOdEunZjLP+xL3az4Ze2rsLfC8fW18RK+XdaCl6260vtFex5UoCrLjsW03hT+GH4S+5q60QHIivYsjB4u4dRvLU0RkE56IbYF8kQ2UgDDp8xkkqjJ+UZk6jUIUXUwkUyrcxqm6KvBkKeA8bTlykCDrlVoOoqLBGjmgTPFGVpw9S0pSp4CsKeF+xK4W3Mrckq24av5gnlYEZki6QPXhS/sWFgvBlA6KBikVAO59W5zBuw16xbC5HK+DwLCcyiPrwVJPYGE3SsXujsTLRNJzB+rBbGD4Eq41AUCazCEbn9sZ3DKGkc9l9asSAdSnZjC20cM3hC/hHRVfL3u4hSynkjAz7sRSqvksKNWn/JC2oXhOhtI2RKwNVyLLcupAjfNt6gYXKPGv9FA3gApgina+G2EnfuDGeBXmgI1G4HDYgSAW0bs16iNFqh7mB2724ilnxoY7DNoqn/YFulZOuFuHUUC8shOzqvCH8WIWdT4sUqRgtIS3aXRqE0Zgn4MLt2U2Yh0gnD2RGUYZwb1ruxEJSTwGxhoNFFJihMjD9jAq+Mn+F5CgV44URlh+zbGKbGfiyJA9DvL1IUHDsiwWNLBoh5iRVKwgmbS2HTWat3StgMx0VkBegRUQ7oYBMWKq0QhA0ZNiMSLFYgTczs7ly/4oUeKPNogS5/RGCQCuh62Q/CdwYyoA7a+mmCBy0g/wiClobbTlE1I/eUd3xJw0M8KyCi+e7NO7dudmCerfbr7jcgd2XHzsuLwj9u/b3HEhW/cm1m/sjhTgFO1x3+V13lug6dWu78WQj27NzYAXiHe8TI4cGoniQIcWhLWfbr5FUx99i4Z7l0ObpuO7GWKMbXodN+OYX1spDZ0a5taB5jv9Xi16zS8MW7upgc0owTvoLN4W+2zs8xv2FtlV0n2zdIEFjpC2g7T70UmvLgaDG4vtMIeSal/nhQXitm4tQPn5eg8ULsfRHiReC5B5RURWVe1ZHS13VWaEryxzl8UlQhcbPSee3GNZBYvCDtV0OqEKREtYGm8XLM0L7CwG95ojAYEv0X4xwGrxBLotJoBUJi/Ew34hehGGrLmyRNUf8FThcHiRrOGfCHo8BNyj+ZLBbt3tgmJ4WbaPjjBpRgvpEeQm/jN15awLzlrRTvccxZXMMIcif5pwzLyM+0zBrgJ5sEq3ZrH2ERdLx2vBYiDiWlPw/Uxg5SpgrMWXcFPhtjML+ZyeP1AAZYDv7U/aOt3xRHMa7i0rScNFa9BN59PZFMASbt1LePRlgLCJ7J7EzUTbV9BVpsCwuM1emT+lKOjNN8m2ZLT2RLmrgsMm3WwH31rmXpc+6OJzg+SRvFteYU14TpL0IMkyKjw9KZG2KLqJO0DYKOTLELcWYw2mPzLarsYfxMSE+8Xw1Y3mdffgOGR5/fLGlf3LGz9XEsk/oCEI7rOlE5+CIj0PTbm3xD7FUqGTNr+gUabejjKjTS9Y+Uxr5A33E+bkuHtyphU0sADT9tQRJxXclSIWxu2sZPG9CCdyg7vHPIljCZnGF5e9sHLOe9lQ4sbuoUS+lO0dSjxdQaxxrMKZZX//gQ1WJJYwhcjCf54Ze33swyfXf7pf5vZJE690rXKj6/IH4zfha8zcZzqbNGTPLDyo1N6kof/5yR+Iu3ReVzmn+dbOGs7xytGyn22t4WTzaf53HT859YxT1vvJHnD8ucxPbg+TmXV+0tJp360wE2YyYyJoSbA63HWWFM5FO8Lpch0nhy4kVr2AgTUr3a4zuc2Qg4tPMfPjwm/zq/Vfj+FOBhwKA7HyREXPLyWtZMedju5s9DkRGxO5myT5J3S87Miph9d72QK4IY5jl2Mmdj14d2LuIktp+QhNG3pVVFYtd+gyKP5ikYSbGJ1slaZEdQkAWRAVY4dR8sPh+HxjPV0xtu4oW7FI8Zb4aHEpuUoWw/eO7jG8nxUiOVgLgf8tdhDq+RTYZij2X3DT/qFK8ZR8tmxC+BCFMXJF3OauMXVINMjvMMNEo0RLokmOZjbyU3vWDjNXirbQvRBtochSVktaphCiLfDXWFsWmhq2oFGa0Da4qqg528FqskgvLdoMkZwC1VkS85nTz73XxOzlM3MPqpf2YOzg2POl+aWpi6b27w9mkgmYoaBPyaR5B+O30TClRuodYSeoU+noTxghg3FWAbNGpp/COE4rPkwbsASyKlBUDml+UNcnU7PXzLvTUw3LSXCch3pqj+dNeSD9zRxerqIMyqOLey5vxlKouJ8QuymKHDQviHq30ZIp2QDsOkdqLckgfqFLBK/eQrmGA+ZBOFdKQIe+C/1n9HI5ypHnHV4SxYdek52ZnErNVevT1Qfs9fKZDFH7kKnx5qmCHyQIrymimzCxC0sxqZQMMSFGqFQhbToVuYNLTXfwWM2XxI2MH6zMTwi8FOwp+lMTGe7Hpcde8JCrCSru4kOWlx9YzmXQ+BLVtZ9QDKkHSuVuDOm9OYoe9fKIN3Hy82sZflSg82uKIL0CsClVp9PaQRjS2WSjnIH3NYr+dDWFJZlEmVni6/wZOFvUEtfEnj7QEnw/lQoeHoIvIOftO9plMioR2pg1MpgZ8qT7+VdHfv5v3LO4LgdTFq697TG0IcXFHdyye3QXWwgmuoZ4alrJKSuaBBCcH/cSiLRGpdB83gYP/XsbP/S7/7cavKiLHyWeL+cohIjQC3IC5QD5+QudBhbYqSIg9skpTA2P26wkHsN1nrO4d4PHLOAxfyxy+MtBb/P22EeHuXybAZUycrfXBvr3/bm23CO/KoXdnpUu2PfAI+F3zkLIlIPX8gvVPvvmSCgVOOph2Zuf0mnIEUUHImba5GFIP2LpRUuil2IA8wKwoglpGQPSVBnqtODeE9wgkFeUhGMJNFoFCn6HoSfqgvZZuhw+YOBjRUwkjD/bUwgdJR2lWlADXB3jsP1OdUQ6euDp3XmB0/BwU0kAGklGxlIzajohQghKpLvnaloFE4CUymZVEjcMCpxQuB8+tPckXtR3Eh/Gd/CLj2Mn2GMneCJ4kR+0D7dQmiiiNfaBDbxHBPHcJ/gLmPcciT0EM/Y3UI7dQf4zymorPxIstkWktLF3RFRK61zE7Wy3khcO8JYnDVxfzWyGa22+htleTFDTv2zqUL/pw+UBfb39/y/cYR3oBg8YvKZKnjESOvWxIbqfGjcTvKHbuEUYl5It/cN68zYXu9dWM0D5H+cTQPlfimTn1p3B+buhp7AYQYcSOMYj2b+2Uu+x7Cr3ph0A51/9x4+UpKuuzOyp17Fxm5AmTrmY/GZTqz9dKJf8xZkyTqlfz3uNckoYG1P/bekJj7z0asE0zcm5xdTKfVdSzTtGMezxiaMgqKjmYLYkIBY2LCXCUncwS3mgbntC7FVAir6vfSa7n/TubppvzY6k64iq683BJXZ8u/yGrRiYkPDI8uY6w62dtkNL5Vt0gKbSfWpLKFCuYPH5QnB5vHJgbHa3sum5ugMp7oA4/PMtqj5/cfPMt9u0149xGX9si4ufX7us9xY+d4v5cAkLBaEpr4TcxG2D8+HxxXD5LiFcsntGvWmLarfsn3W0bsl/756Rp7aqaWvlXWSYbU1b8qYdsboAq38zsvpe0PE8kTJQDkqv+njRdsCQbjft2UH41CDLNr+7fOnTzjjjaZcut/6Xu3nbRvrtxIGzqtUzViuV1TOq1bMOTAy02g0zh6umWj68tHi4rGnlw+RFO/H0my9wQM3Eqx4gTSoGuMwa34qscQlLdt8/rCrd1h62u33r8QNWrwcZ8ZvbW8l+xLYNfu667etBFr/7x1tay/7FjrjFEzZcxK5hE7+Jfa9ZUCrfRFuBQzqBK90dX9oLTLL2xCy37FSd8GP2QofuZ9HdrEiIbJkhhulnsGKr4dd/VROGzOC/k/EmskHOkljDLxF4+0v5I5lMUU8IWOOgtCk82KLRIZvPiDrYO+QkuP18jT+VA14rwJDbAUmY5tpJiJDFTyWy7/sm5KfJ2nds09SBscTbWnJgmAHVVRUFxpeG3QUzxf0yLhQyx846d2L2opn5K8L+nh329y6Yys3ngqmANvjyepCKk7X7Zw5gPF7BwDfWPJFcNB1VduYD7mhcikNqNoiLtj45t5S86bNmrZrG8o0+OTPjNA+hlxfMXTVfv6BEO3m+B8xeouj5exCrvMyRfVRQooHkJ4cO0oWYArwuhF31tlsrDU+kLVQ2WN6o0eoF/kZt2krDZwSgIzd73eHdWe4OIdndbjXLmOMp6xqtSCeIZpN1r9XsZmWM/i6/SYOWrNLeP2u5alHLFcrpZmFgq9WZT1RJ+98AnWKyf/PnhHx2jFbv2vNHaM8mQXdwEQvAZ2KE/NKx2rMbcxH09AClqh9aO/x4MEuBsC7nefaAhkJuNBaBnuAYnEc/QqNnIZ8cTC/QfMXoiU0zNtLuP5ihu6PfkVbrkBgbcgKoMiTN/2HDbDV54vuRoU4BAP4FY3Vvw/ZNudO+3V0TvXSDdm44UidntcemE7tsoA17vHTBMJqBcu/fGcuIrJFzCmsP3AtH6L2xz8S+uFF7gGePubukRwHY1w2or2sGNGoAmYqRavkUQyEDakpRxvVIZVxaatke785vzbL9XQP095PB0vJGHYPUW1qNoWdEBX+rMfSUF/a3g57LOkFlk/wtejNOMJVMe6abtlyqekXTHcFLJinA6WLVBLBPVTne2opXvHx9P+GDgno2Os/regl/NNfdSVo0o0bShm0kjjxFXT26qnlltpJCrFTW8IuFkp+egiIJfmV3ojSDOSwgknJKM8jHx3eoN6/vNlxWBWxhFalx58BfEPtzdJ0+MrjXMD6f9w5FAH4UQrFBYeJ/lWP3v/r+RzfkGXsZMfp4xh67Q/Hi2m5isfL8yny5i1hs4Zz7nb0wMKL8vItx7Pz8QofbO2NRKtxki2/s0ha393t2JMQ0nz+QYEyIpVBAnc5LGJhfEnt27G1EitDwoQmhfRdWSY16m3ybOQ2SsMUIU9yVPHfxIwIpKfawEdJ3ATYQFAZhTka3FaLsrY0QxNh8MXo3d1/0r+j+XUWMXsychW3hFWjzmvmWi3U8CmimCMPW7k41dEr203gsT6QqftO0Au9hSWz9ZHQGua9r3Rj/KE/IM/LTekbil+ceZqZUkDqrIP9NLlig7pWLQWkvlhw0WzZ1EfvGdvPbum6WAn9fIX+sWj4lX1hK+hUzCPKTSFfzp5Srx/KFfX5QMlMkAxZjThUB9c2aKR0TcUtEAQCUh63qkOyjdNAgLha0H8mqEphmznHL+GMlcqaZhDix7eTMXMIqu2fgg7yTeJoRiHrcRlCkzhSXsBmRNf1zHbwhfDhuevRTho6NyyJWKrBtrMeZ0h+uM5AVml4GmFq6nMH90JnMHjrn6vk5+gnYG6ziwsz+9GIyVXOzGJfCidlyydpzg6ptBgrW7zhauSApDczMykIhb8tY7mt/qUg+pPmyxtiS4XD4prbqwc81T6a/oAwC53hcV2W3+QyZkkXgG9BKCB/ELQp0pVzfFHpvSNwhKDTjmcUBOQDTsoaf9hASZiUOwhUwM3roS4qqQGkk8asANyNEhNrkdNTCrqaCtxEIHDCNg72Rc6PhCb1z7w9l5L+O/SOGJ4tJ2lSNYPwM7FOP9CiTi3ROshoS1LB7lE5SQLpJkitLdAEj2b0vWqfjF4udocWl9eMUYWcuWO5Nfg0Dg1xJb97Pb6QwVBFoaR3XsjNJbL9/Yt81y/rERFFCWyy3L9d8BYgEwIUOOHXaoZt9KS2nanFVdLTMst98DgWjYhyD/Z7MBhOXX+zQnbrXy6BpSCNQNZFZyrg110ERw2YwmuFUOcb+xsspFhQB/AdaSqAVUIkhTr677jK+bvzoeOv68Uw8NnfiR7yNRsF+KMo8kmXGPXW90+oFHCFVP9nuAPU0A8DTsrRcJeO0GNxN2gXcpcdpjZ+0aI1PmwE2bQYcRzNABAt9dzcAWJrjx5svHqe9wG/aMjh8/57qPtbqCTzuyegIyErYEljtagmU9+yFUNGfk8Wxeg2vHqFrMHXiTu47sM8cuq0v3wzTta6TE83ItsGxIwzvFfwqrPSLCVbA00r/KKv0a6zShwOLUamfXMkDy/Voc9asFrRRKXOgZNjXHMh1NwfszdBb+dX/z9x3gElyVVd3VXWlrpw75zA5h81Bu9KupFUWCqCMBUgIEQxGiGRjskFgRPoJBhEsyRgbMMHGGZMx2eRsgj8bG37gxzgwvf95r6pzz0zPzowkeY12RjPTPfXuu+++c889J9u+0/t44s1TZInn6l2qNwl1VNWbUrUI1Zu/HAEWKFJZHFJ8HsOQ3fPXhwV2XLNm5OYHY+24ykzz11vobPzXthVhPtitCHNzdp0m1Q9Bzx5hIfr405BfWR60FXB2ZSEe177Ur/1qqKvAV3dlAW7uchUQbHgGdHwFcqUMJWHcteHzf2H3839Ndp120YeBQodsrhdjZPBD0Qpw0SGyU1yuw8wGS8P1rszmXK6+coOuHJtdumBp9crKbLWzcuM7QOX62MiL+w+bUbn28enJaPGTWPypWrj4YydXinpQvGkHmVz/s4WN2bx+UyrX1HGzEzgJL0837g/g5UoC55GxVxCLl/U2LpWL8DeVLMHZ16dXUimLbcES6E8wu7G3m98n5TuVIflWnwzJ3f0yJH/jmL/frT6SKo05M6td8iOIB21XMsHbvDk3kcCO7xETwVgeFRMhciWQE0mFciItPREfDYebt52ea+DU8riHHItdBYvtP9gJFa8hFK4tKm3lGWGQz/XptvjWvkHxrfubF6wvvvUXrdnguf1DCETJUfWxsMWbTxy8VWxRNeubg8Su3+6oWt22kapVfnlx6cnDLhBV6MqsUQD3t2N/FvvoUG7XQshvzkYZfKlBnCAmuEmyHN4GtK02iS8aKa8MDwEECCgli6s7sNKMO+QO+LrsFC5vKrJgSrQYx5bxMrJvZBTK43rNMB4XE9K/4lph78JzQPpPDdDACNvvRfvSWl78920GwRDaVxN+P4mx5M2pfb4K8QM1e3YhQ2Z64fszQO2yJL2O0CFMsCh0OlwwT+Z/c3sBQoqA70N6NOSMPAJkzbevm82D/sQabCErM+XQ5Jk4loTmIi1grY151erl1cjadBW/hk+vNitL5FpTqhOMTBRg5yGsl87jg0n156Nm5LWfICDgI4rFMrJZ5ivOmO1qJEpwM0WKDJS1X2n5y/H9mHURmb3wyEsmCNAviMg5/+ZDuF2mQbVOEv/ZYH7ltnJIC6xUgNOzlV4ABieAfihJNdeanpm2FYuiZc/k6etT615ZJrQKGo4MprbQzqWr/BnufLrKd8TuhfT2J9cH3PEhOaVFwjCIujFUecyniAMWJOrN0KlpRmyT/NZX/2fpyb+t+tzBy1JhKnw1Mb5dJwbOA1Tgpcrn1vzxghM+jzgveElfFHFnvRsefDaEEzSB9nX0nK5kceNMeLZWRRTwvCYaJUvDGevkQSicyuaqJU7O6v5rtnOyYxhqfMqAbBqrqMD61gPgv0uWDu9Xzabs6bkZWzE0LaHoHOwZTWgncUrVULU4B+BTUzMOiG8cmIx60daTNoyhDRAyXC0Fp+e6Z6fh9Jw/Vi6O1+KKCQfA9PZKgeaFahqaI3MElCe1348wK9nKF3fvTrbgzoRhuhuJYfEMqaW7lQm+cYa80ogSWqELdxN0pt++k5TQUAOhixa6G+X63WdICLUm08T7sosSeseuFOpnzAZNjxEVjA4b9M+3WbnzsQJ4oEJ7jz4eMi27c6b3kUhrAwzQl+7CUf0vA+xRb1Tu53Z338v7qKMLQzif/8iexpM/gpblC2NviL13+yY73Prn9BnvsfXYnq/cHqvzR+s0w7ez3y4f4HnOd+ic165H58yXs710Ti6/DtfpF9s8HG/DIDPP+LaR6SZ4TqJvA4Gn2CUANsn4k9th5x7sEs1atzWwGLVrFqN6mZbMC1SBxgood6aHf9glhiPUSJuara/bu7kO7dykL5hoVQrMuZxV2LAbI5DWjZcBinU+R1tripwoWXjGbxE0xdQI3wX2xkTnxg51bri1r4PTa5LHuV4D54ZUPjDQgADylpV+yh562mJ3J+bIRHZPNpjq6sSga5M8eOxk+UtaRsO1DN1BLg9tb4ttTvyNJsNrl3OSWY29WMllkkS+iUjR8qdee+Jn6bmn8KJ19PyTyfpVXT2ccdrDqbnpleksDsbx01/lahwPnOOxsZdT7meHTk3ancsVrBTx+ibwP9dJnUQXhizMcqcd6gue0+V+ux5TjTvAtGQasLktl1bIkTYVdmR8hfZU6WfJD11hn4g7KNrr6L1rpJ3pG1VduPpCv1oqu07aEArl3MmKmfR8fboRl12+YuKZKfmCKcY5jnlXKOWhjh9Yj7l2K0Du30YHVfKtDFGrgtBQQpTRzUenGrIMzdcJRs6uF4I4ESNPI3u9mXCjUfYIdIr4Xiz0NTcQSSPDAPs2tXBTIZ2KEzNlMXXRokykix6FCsnj4k5InV77nRDafi3hsCHgDHDY+GyhxWFjn6b4CUvDJoz7aolvPptuwjiXQFc4e6zAjB84cWDiA9PnqSLnjeVcAqXy49h0S2BV/wQU3vPg/f6GSP5yeBftALMcYdwHOtbiB9j6cigP1v1Jpralnt5m5N3bCFdXc9hUtqufhgb1oSAFIQoCV2uGOWkxB5w86AD0Q6WRbr5qS408bpO+HPvC7oban7YbahlLroyP67oCoVYxIdI+HBKrmKvWLKKLjHeKz5qUsMuWlp+/pe7eSJTd7t7clcCWt9ebGxjqpWcxG60ZRhgb5Ui4kI3QJyqc4llzbitcKClx2226nw2ea/8EqIcjKA5rq/GUXlnRs7jHBeZRBvswAMgPVTZwbRNw9CSnI+lHbKtdxyQHD6+bE1ZcN/S4YiE7H2ew57JJk+GqKgS7AKG6sqRWteYP08WCQOTh4A7q2Hxf447Q97bXuGPoqdZbsVSwpK1W0uJy+HPZ1sedYoffuT4ecxN5xKIG5VDXUAURv79RKUEXEcWD7eF54utrpYxANgSDz+DMScnkvIuLcsEuNl+5o9099vfEbC7JNu8FVxAHK1o/0LycJySaBMBA1aSlxlE0BRK8CeKKQj6B0qMICpZEJGd+ORTRnzn9eU6NEP03QL5hdxB9ek52NhkWvkIJ9EQwaR+xfaxHyXLYZgMpeADe/6cd8BE/OQQ4/l3R80jNE23CQMXToJ8i+5CBXicRrU1I/sBmJKXqzwaR3rGtwf0/GsSF72SFhNzZkkqiQD6h5VIEHCZaxFJrX+J3+mc3lQr3pZJUXrsRtluLHYo9J/ZqMoEWjITDrocNbndpB+4hI+C9TxoBmmWs4dv+Z9tZ4SGXkfs3hYDtFlR7oBuqnVuYa0G1nLjOReQ1W1n7H7dzMjwc7hhyLbmjFxEudBDhoIUIt07ai4Di3QsZ1y1QsMN7PyEZDmVgczseJyNxsdfJ/f/bx8WOq74tgxhIuNivGvB89nc4ZH6jh5M9uzrbxclmFk5efmJ9Tva/dnGyT2RmWDnwDDbh2HaXBXRFnbmyZQH9gQ0jCK46Utepfro7gm4fEkHP2YCZXTz9vQhLvANDIf8Y+8aD0E7YaoxFUnlDw2u07kJ5d7oLf7e1iOPUwNVz4jrhlhyt2/CLXes2MO/YSh77ipkHPRv0zaFJ7MbexsM3o8bDxTjK/miH1Sm2lbG40VHsL51hQ+EpZ5qWSFW7JRz7TKUrXraVdf+Lzp0iX8nzd6zDD/wEV41ELP5wo/H5bYpYPFBr/4odkrS44wGLBX+nFC6esKWk0AkO8NGGBkeodRGPehyEPPq60bUudny9R1a++PeB3gW/02uJ6/sZK2Gcs5VV+l4vLHDHiJoYn4RxQNgfeRMISZ/avf7ITq/yej2Te7fXM/nvHb65rBcXRwf6KIudPspl6/VRMvlUXx+luBPXlxFi5xbWQV/FwSxXp69C5mH+A9k+jjvL46Fu8/KWdAYT7GeGdEq8vrYLtyF0y4f9E3F4e6VHM7ceDfyRcHQwLoVX/zFplCRTknei1SeRaZ8k7LYYtNtypZiszBU2UNZoAE9KDGusrH2rPRUTl0Urg6aKxSeyX8aQzHH2F2iQZPYXTw60R6Ye3d1puZLNrkwXO42WowONllvPf8OJn6bnvK6myqmupsraL+hEzGVzzvzijInWqefO3LKYvPD8FebU5PXT78f+LkMRN4deyknQDd8ee1/sI8O7Kev1U1pKGL0tlTNigzhb7LGswsErbOeQN5hn2Fv7ei7WGOh01uWHh3RdcrUEaW/29V30Myz1XrWFTswzGNnHy5KGEL74Cz1tmRojuXHh0JGhjRlrJhcXFIP0ZtSe3kxTPMP6j/mL3q7Nu/u6NqWFvQvl/q7NKhwhFPIm9qOH5I4jgsZR9M3QCHoFZh8/FvvKTkQQswOclu3G0xO3G0/N5+4YA+ZND2qIrd28Q1QZ9q4dCDlimpfiknADPhG7DpA4Bme7/VpLGPBuW7aS0z8g7aZOoRH9IVMzwcLKPrL03EqYoqLaIU9ijv0QGDlWjrqmEv+etc9hsNWbCw3pfP7Ka5j8vpVZOzAuOzn3yIXxS+tWUa+AKDNz4hHzbHZmaiptl5+Aw/ngXPbSiw4InJieqVbOrViVvH83jkdZxUgIDm34EgJ6gKFcUcBZwb6CTfiVdOGc+oW3BKaMB2NJvlG/amHvRYvJ3yedKuYyTV1axI9Ta2PJqXISR4XIKXaGmon9AB7Jp2NLoBDdGk3eDzWxBfmb2NiSD2mVLcCX2yOPwlnoaf9QtkqrH+5H7fCwdoYkx+rCIZa9Z7ivbLJSqqae+dt/fN+pZz18/mV449kjR/blGdUgArpKmln7dn0KDyHr8RYMjoi1EsuWKvlZhjHzK+dPf+Tm66rnHqgxd6xr7Xq+ePLCS08xZu3g9GUneHtSZZrf7fRorlZKSrtDI1li2EVNmtKRbJHhtYA+rI/Qh7UPree7Nn9Y3HLXnSQ0Cd5H7R/O3K6t+w5CkNENn+Xqtcfqs1c+62LyPKsnbjtJH6izPW+1+2v7zq1Wz9lTKe85u0qf93vI87Z7nncmfN57OKOwWB9fKWhyfnV6fLmgMSiTmeatWzBEu9K0AHHLFk5U9M95C2eHe/of2P+iq3A97oN/0jb33vJK7K7abf9ScR0d262v2tk7LnIbDCxkqF/L/Nm667k6ZD1zWM9X7Yy8Lfu4vrVe+/OObm1n8y1hHO1JZ5Sp+EN0trCrzpxlorFGrr++PPOM1fxrp5IP+JtqhytqDvdiUhd+QvVMOEu6U5MNo7siPNawJplCd/Z66rrZ61Rv9ppSmTdp5Iw7nJ7KJgL4GpJK7g7I+qCI0/K5lNiu4fxEbjqrBczru7NZvCv1ExbGY8/okTa6H9OGTNFNs1X/czza9VjW/nXpqqceP/7Uq5eWrib/vmqJVSp7zymXj6+USivHy+Vz9laYl6z76FZ7Hp2ZUpkvdj2KZnJiKSPzqeXZ2aWUIKSWZk1kf1R/UD/EKSNY1Mn5Y/RZ0TnIWquTSi4qfGRDF5WV3ddNbrkSSXmsLlKmUWXEzNRjJS8S0h/5igDlLVBUbuCp3ukWTRl+lFrpeE7IVhvVnBifWJjgrIptjzlaQOYF4xkD5idO1WbcwL0HxkApjnWT0EaWeOVLIyQgr3vlDJW9y67mYSnhZivm89hMbbKWnepPKEdAVJJ83+JEeOAZju/oHJuE+6YMnETkoesgqLzpSAlLhoUhXMQVwnnSdbfBWkk9IY+SepjuXKVUXZGRbNtLwmiW1fGCGrvUf3zEY9bp70KwlczKPQpiDn80dFZupaPwmGXaRjxEvgf1vuATK55QInKSGaYQiT9uy4iHCBURHtMiPTYIauFH0p0LEeJVKVEqUxg7zMAw3NiQkUUHhb4AHxuf8L0omSx04yEdPDDPDBtKDphWw0UkrQSGRiVPiBkPC0PUtVtYP5MRQuseKHmqfpnonry15Coqx/Ny2Ww+RTVt0eNhsWw3mPJow25vZSJbHtUQdbFjy4N/UtPp0JYnG5HReqQi2+oOtxFPHkzX/YJakk5M1zjV4uOBHa9OjYmMKgbptGyiLItzSt7MyjhWnjFsFrJw+mvcZVwZYio3ADq6J5TrWFlabgGHi3m6Xz3QDhYOYWhxH9PnQxtpdTrLXSbIRIesl4aGZnTF6aXmQucpXFzylW1pUGo+R1wtGyv16LpAaBD4xkcHB8qMP+lPFV7wzMXL9uIedd0lKHftdOBULQ13uHG7+SYYR7sA2VWlOhsyzYiXDNOcqLGt4XO9xUhj/dKY/UxOEpRAp9adgPsqiuapkr63KBAXTlFRUjAwleX4Z8mqLs9X40JjnztRy/DMm1nWKBosyBbnN664mEvNnDVx9JRUFVUSPZKQNlMubnlxcAwdKI9qWvPTlHVGRSJL1cd009JCDcm6ks0kIYrkGN6UXz4AOSvGTmUhhlQEERSrrsOSlDjOpgKL+e9cA8yZRMrPTyHsHJuu40+idbwOxfabzngdmb77yZDryQO7juztXXea/6xPYR0H7zS/eMCW8SNdV6AutcnoBjSz3UX8crSId8TuI5X6mW5Gesh2ozsLxJ21De4UmD5op4XpMA/o0v4JeH5+wgMBAD31NnwDnTVHPN/IQXagYKQ8W7yqC7sxtekTFZvPTDqGzVz4gK3623Aye6KJjgX+reQaIT6TsP3EtcFkMpiGTa2bTDypjc1M5R3GOWtKE2RnynU49sB24oLMLn0ziotTUGJ+Rcsp70wio7/v17vgWYbUVBsseTBwT9tmDAgDpWp8tFUV+yvaL29/mT88sVpQpdye2dnljChmltnrutfNSgWB0V65k0NWzrTAKEPHSTcEHLwmm+pfSg711E9AE1aAqz2LgCK1oWXNYlQBLa1GRVYbzKWrjIKJtHL4PqGzll3MBprnfXgs8+yuMuZrnTImZ3WKHsauer1IbL7qggVz/EBYJv0AWme62RI+13x4SfJU6Sypt3TPfY1oojXH+kDUN6uil0x2ihSfFClkZaZmGxxRirP60VNzdu+x6iU3KaRCr89MiCcye/UEUTn77o+CBR3WyvM+u4cTeb2IKyVvKoXquP/B7+m1MgYqDHVsZtr8zf4JCXpysv+NzbUAAvAziJycM3xfra63p1a3fma2dC83zKbfZ5Izyc42eviFzAWdLXR/Zwtp7I0jHJFrPduK6dtNXxvYPK+nW0ftbJ3DF0g1snUGN47CbnIs7uneRqeef/YISY9rI9AXwBftzs0xaDzk+kGWrkdP07uNRTNi+OAXh4PR4NY26KAgaYuHP0codyPUAd7m2jd4l/fbCLUxjskAEA5rR5P9ILVw8QEFDRJmzJ580nCI+jnpvTlyW7vVJXRoXrYpZq2p/gBmTSzCrwVh1ZLkemUQuL7wWoSnbh4bXx+6fjdYbQq+Avp/1wrYHyJDEY2P0lv6PKSuHht7Zh+iUeq6fS/WcR3vATQIt7VANeJdP9uaIiJK1dHEySTTFojvhbMhgdUI73yL1EdSZ9i34okZoiglQ5hjwfJxu84F5zASJ118aQhznLoAwzaMPz5NpeAVDCSIXDRWYqUVv/mejhQ88/UuKOQf0WAkwnzPJXwAd4J5EmJedWVkSwltaI1emfGAxzOYcTjncIR6HDjbhJt0wbgnHRznc6U8RhG4sFT3fJfKvaOSrwWo5F/eBYy8FK68caNiOTWUK5QR2oKMFmJnxS6LPTr29A0f8cqwZxyEkJEw5OnRh7c5iLTO010k7HHp4nPfet+pZ141d5I+Xjm3fO70I6++5rrqyX3Vj7eenEgeXPMPR4CU7hz+cD1oFQ483cD4EXl2xWL3w8uAO0meXfPtm2FMBOD8MvsrCCEfQFc9Uttyoy5lR4un0ZUK2uNrK10E2kgTudxrOrFCBzrCuWGq+4p49kMxoDBli602KM5anBZEfJJZivSP61G3NBJKxo8heWsxNKFmP0Y0cqFHVSvfcOA4JFXdmm0VjXRNVhIJRakmlYxdGnNrDlirDdcad9GqzCpkikNauzfwXFXkTS4hwmUFrAb24oQhm4rAmZKneJkP0zxCNLWBokpoSnAk+QPU5KG0Wrbz0/6E59XMMs9D803WUv64UXBOVvMFDfSYh2EcQ3GU+gECuON0gP2zVUsGc5n0jO1WMEDDyxIZqsMfwlGJo5VpwOUkkWweQ99WsmXXhDQbOVQ4DpNywG1lkP/FuHiFbPIAnSyNh7gxRlQkUxB0XtDi6riRY54VmDDalkQyycWQd1X09IRJlITIGS9opuKE2CtX4piYA9OK21A4xRjKnO6EfkAlpD30G8PWM22Ctw5oFqu5j+k+doMRDmy6ieimI1mNeePJZz5iaekRzzwZ/fvDC9ct4pc13CCRJwPzwbkXnvTAEhbxy5NeJnvAyOt6RlE4EL1mxd6+3NAD+kTt3H3Vx11P/re671zmA4nK0dWFIzU9UT66Z/VoJfEOjOqWsgroTGw6D7VVqmwGl2mXdAokMnWRkFzVALrHvXfj05hVPKccgOwc+I6nsHQzfZYrIVPdTkdiukagNu+6kc9h/IFYFeCpVzZ46uQHgnfQ06LjNs1fH9xSB04vzRwcZwO8cU8u10vieisy7y5ci/V7XbtV99QWhjtxxW8/7MTTr11mi/0IbWPTRpyeMUPoMK6CsORr9BjnE5KnGibJhCwLBnynW3dBC6GdXs0lErnV6UH41QU8V+I83PtuQBvn1YOzSvuZ1Q2CPXrq4uLQgaa+TdToC/kR5pBu7J5Deh+z/iYourPewg2LzOuGjyrN9+2ukz17odncdMQoy0pZOmI0QUeMDrQ2h9OzOYqKRHLiPjKBlHOtqemp1gQS89P+7fb1vl2y9m4+0Z4eSgzqSUWbCGvloOX2lOE5SgxGaqcdZjZeU2bT5IRHfc1oLTW94m+8bs3v9CamTw1JTAf3j9ZWUxz9xAZL89z+zEQ2wI/wUBU81AY0en5r8LE2JhgyBpVnV8PZJ0xl0SH35VH2Bcbg19VpeeOwmMwun5ptReVLx0/etHeEmF+55lh9g6rp01LxCFayokqFI3tWjxSlz0iuQ0jCKHg833Gltc/XFgrgRS1sGNQLjJpbHIuAi1nVlEBvMhIEiRCMcIgc8qQ8iv2bgfP/SdvMK98jh9FNJqQgAu3BhIwxpzV+vJ/pE9no5ojSu+z8MtErpSrQrWe/4HedA6RP5wrkwoDXYVY6tVrYywkrr6iz/D6roJsQo0VGxOjNWDmFXIl5G0vWM3p2xZ8oJfxy0q57pfJYRbZl/3qMsak4IgK5oDwxYotmQxkOlEy6ktYMXHh5c3K82LxWz6oqUAgXsM6L3ClDFnXdrjv5AubCmGpWcc0EVz/OeEICWh0ogERLTi9NFePAIryaDn+HnOYk2X8VLcWokrF9La2W9zu6Fo9aOah4PCN7xbQ/N4VthyKOJYYMwtq54JcBwMzAj4H5V2xH2MvEbdObDi5+84n/CWZTGhp0LPpRvmuYzBsZXAoDT8eKx8FTU2HHI1FlxTflJlCpaYFzL17orFwaDSEBWVJCB7Gcsap6hpRchGBHRgP2n/4653NGzAaI+CigHH9AIoCjFze6TVAjjwBj1AhduAUcH2YipQCiV7nc09XD0UDhqUgOGedVpTsYyGhkGAuNAfyQOUzhDvEJN6RnZ6YC4B9sZQR4g3k8atM4ywPRUESFz3Bs9Ygqqi5h5xLkw1crGv3y5rMYJVALOQ9PMHVOuisCrnAnDXCr7UnnUD8aAn41gUBOXsjwEZq4dnSjGutvBce1oOIjUvHZzPyHFCuRBuubvZ0gIVjtsk/kWF514uzpI6hdJEvVlor4Pr610mycXP6x0tjlC4OA8AKu7qe5AJ7xp4CN3A/xwi3XbD0D61j5yD8RYUBaduE+J5OkvVvdctvtAqJXynfn19pK58JEtjjNKK31x9ZmVggiIIS9Wiw1+9GwtAuU5iK8WVql3YyvH3n8257YTKK+6pR2uE3ue/R9z1sg9VpKa05cv3j5vlzc+PuJay5YeBbzSjK7yghkz+eJJwVZbytFkC5ewtVHh3SpnW9OYbGBmIWr/WSstixm7LpbyPupDKtYNCgIPQ7TfsAe7OK4PXmc55zimKXVqlmfVfQiZW4yafdIAiedyJSwvJLrikTPhWOyxaNqWsJn8dfZQ5WXyKWDy1ec0/weI2qWmkhht8+A4Nghj0/7zb9NWwnd5DnZrLHvYO6D1oIA5xpEAPFV0WVPzamhVradS4icaKnQMqCpJeOkUSzGvRzMiCDHIDo0Kv6BSyMqdDhIPSP2jthfY493r+yZt4V2PiQaQ0OCme5e1qu22R+a2XpU3NCJiqThpBjFiaKCMXPDwwKiHZ21Xktur1HE3NOJlWP9sXJPV6y8l3nj+rHiVRQaKwlXpbFSG4gVAaj351BXFYCy7ovdgrGRd8X+ZrgO8qZnwmonOKwhwUG7DWEgCWU++uvy8K+seW7nzOit3boCiRwZrZhZYbhHXC8KV14e1MqUMS4W917IZkY4MNROcCz0Bge5z4gNhIciscEUcxX9O+Z3+r+oWRZS0UFysjuGxHYMTQCvLS5AHsXIpyt1LstfdN6hCzGWlMhDPKi2t2at1TunyCO7T5EMOUXuwVyLEQYDc25/NDwewL2SgFw/JycCmUnSvyEymNcP/coXpwoLJo0KHb5IrKThgkpjpzt0kqVxnvOLWsY3gGjERETJx2C1U0DVeDz2ZIi2/WXsy7EfxmL8OgZ0Cy0DuqUVslgt6YOesKJ1pTNazABSwORbbSeChulXRpjHmBoVT4B5Ain8gdaBQMS+VD502fWXHRxqUvfi8kSZbWkiNG8lgXfFw2jg1XMIu89tHlHwv8okbeYRZx5SMFFsu9fNnnPJ2bNOHXJKWk6sN4ysb7LyOXo+7ayQmykUsJOBzZyVmmC1Ig/YUbF9jCtkDYMxzfEbx1ULFowcdwl/6tihfYhKd2+ptlLS1/69K+wq/cH03k7YYfKKEdphd8XQr7zNaIWdNZFbJ+wgCsWIQKgFerJxGOzAgDt7C4BhuPMuoHIXey8wlwHx/YMzuMAwXReUoTeYTS4sOrs7Nxbmms61pO/CsnbNBjcUVvWgEkDuKJXDTLDTdxS5dQlJJW32xsFLyrvWu5a8xEhDxYNeTF6Jn/6wDS8mBDX5BHB8LZaBt9utrVXtH14lY0zOSgsmFCqRcUY0adRYbgx8ohy20kkNcojpbfah8rzYntUbmiC95GnF888/kV0dm1zwzrngvNTsydvMSt7JNqaB15HtyeloQpuaRth570Ry7v74QDChKowuJtEYZD4psvZkI3v5xYdIk2+umjnn7L3sv0p5e/GaycuuZgTTKj5yz8rlZd2DGBKnNxPQrEh6qRRYmbkjKaeiAFLKIwyUy5nCwXT3x6zsWmPwhI7/0J+fLIBXmKjU/EbRg84+71GE5Cs4yWUgJJfEnoqTfBB4EsqI0DY4vkpA2DZSvtswuVJ0EMktmJxhnsXyHdD8RTsJmL9fqR5bXTgLQVw9tmf1WFV5Kw60uWQEmBvTbjCWa6HnY1CoGw6df3xD6PwCCI04ZcwDKEnfCVSK+sUKyFY/j2VjK4hgcqmOJp+6jjtCvFlp2WOSoybyFER9Rcos+uz5Bb/jkE4sNCHe84HyoT0LPhl5mj332vnxa66+KBsY/tje6twj/xovujJnVvzc/oVqnPaVjYKZ2rvQaM6ZqF01OlHFTqcnw2a1d+5dx6rnn30IYpCSlUvWb1nYe/lqxmyMFS6rN04cmMIgdvMbaB4fAUVW9mq55Fwjy5ELGe/Wm09GVZp0XYM+q+hiKhC/JRp+30dPiKCeeylGPRB+zuZRxCystJgV9XIlJFfUw24cjBwJ/RtD5itBP+z54r5g++4IQcNcbDVKnmtOu9jga19jTDBVVU3LGkQcumgtPXbf4buON3/d14vR6mevLhwbR8F/9p7Vs+ta856NwgQ5TE7jnNdJlhNhrORpqkmdMakZDTPL6ymnDJdhLe07KZ2nT/ETnMQ5uNCTTfx727vO9zdVMNW5nyVfB9fVhT4OS+sxr/R2XlAJvcMgt3Oo0DSX3Anf7bqd3/7WJzbT6NJFt3P0NgzT3/voe5+3uKyZZJR96rf6uykNyVVS31xenLyuzGP36RjWn3HXPoTHH7QeP/Pr/oZLndWsmkUbLvnkeUoRvR6mDnFBKfDlBG24lGrn6bkE+exV43srplbaNz29r6Th36+khxvmzI2UpRMrVQn3Ro0I0f296SpoYYLUb6ORIDm0Uf81xLCKGK6hn3wTtV3buDni0E+3Aja8XiMZ7pifx4s3bIj8xKrm7FYMf1R0Hb0RCD2ScJ8e6LM0mS63jtnePsr/a/dRmA9t1gdp/oxJBIFLg5tTHCtXaF7Z23wZ7K7cuXHrhCzAP2MBdIryH48Kgb4FGFAsQUJY7M0bre/oyxNOf0+RufPEnQ9fXHz4nSdOPJ38++nNp/ezG5ijSAN8T6oQ02nXSmUVxque3Ft57LX432p178n7BwD9TyXKh1fmD1chI3JkdeVwOdF8x/Tekirn98/P7y/IcmE/cwXSgJjKdJ6i4aOZyEMYyymh/S4D4vAS7NqXLZsQCuG9ZsscI5JWeOb099jT6NReHntZ7B9iPwdbrV+4AdUuOUrIKEWb4uB3eFAYyWiRGKKKuYyjiopa4g90RsjPq/kupTuQ6Q38y21/dSPkPSwTrIejBJ4VqswdkSUww8FFdy6ai4Qy4WJAFaQ8yZS7ZCYiIkZYccCYSwjCH7AIJtfCSvRf215nEQzV9pS+Y8wi09mJwDQrgTubti3JkeIIbBmPMmFZAsAiBRU01Ycl/3BomWQsLa1rGR3XFE7mbXy5gAJQEzMpuKfeSb9MpJ7LkpzULHiY0e9GBWjoEvgIwN00AcXxNzXC00io+DEgtF1vVZxzYPR8Cwp8DJnIkoCI1jCpQ6zj7kzASVlvvg6FmuQ20PmVyE8SSckDwiPPgqARp1MneC/pjJZUiM+yzFyZXUrPpdLTPsp3KwnlUiKJgd8B0yi8lOBU0XYSPrG1Q4NZwOSiKTRKVlqVVNgo069E91nU/p87EbwlGHOeZBZ0vA8zwWOICBU4oe3xpggeSYJT2Eu0tJmxMHsCB2YDau4Az5uLcRHAkaVpradHXloQLc0xZCLjQZ7KzY6XNAoGT7wEOdlTME+ft0SU9SKKG54A8VTcTUmkqO77V1h4L8RmsLHv2MwPtt8OVm8NFEUsyaH67n5tY4XpX22oFI0U1OP4+mM8QRINSpA16Z1MoneyXHgnY5rB9hxe9+zplYBeVlFIgg1JGDv0tsWw16rZLLoEvGN5MwF/wVtO/l/ZvnAkpejPt5Wib449bbsurnMd+WGiDbREnc0ivQcs3uhCw5kRJaHZG1vWBwq0FOhXcbwqlax8AmTk5vO37Nb6rO45m3Qu1Sv//HLddoiPgWZU6zVr8mETGuLfMohWsKfV4388VICtjoY0h+vWXOyJsTcSJ3Im9HEMreHKQ7V0SGZrJWCGajiG/vY8/fKD8ZUwoNtfE+Tiiz5qNZRsZPCRaA8zXXy2diIUycxcK7cjb4bVxCpPm7FCiMg7S/XWewg85uUH02iDceXV8yYWE1BRwx9Pn0GeAthZdO164M7A3x41K0lkgslcodscVC4NBTODJ5/5osfNeAUVuJgOXJz1OLjEEbQAo3KgcJkJYf7sS88/aKRYvfmn2EL4FtjXa0lNTyuqJyVgWo78aMpKEjajiksssTWOeRpkokrFBm2gQLdZcpQAI5g/rqxmzhqfPrmYgRsGrmpSfjFYSmUWgmTNMjyBWM8TyWniXS+s3Z603JSikawjBMr/cVzdVwi3GNPdMpB4IeUU83qIdnxWsWTCQJMhLI8o0hUpRd5MwgX1TKAbXIFnve29BQ+nKIoTOZBuyxiPLBXSwANYruiVI81oEgPHodj1TKK4NKAZHWWpQdXo+hZEo3v339LKAaZ/Bw7IQn+qLQt9LJKFRmpvyUK/uXlFRxZaE3tUod/VYkLtPRhOUNpj41PtCUqza19S23cgWzrsSsJ9+fSNZZ/PFizH4iH8PBYKP8NPtq37fI0eoHwfY781OCL5gp7d6dUqVY/sT8Nq7c9XDZtnnDn9KUxtytTb8S0QW3oQvR03S58Ds6v5B97I8QdbXViOH1wpfcecG28elpE3XHGUFbDxm6YTynvRo3g1uuHvHbrqu6tfseXF7uhbDFt3NrvjEha/v9WlZpRQ42LI/PLaWTsjYsHcuvGCv2RgwZtyR+WCirnTgoeIud+A1X/tNsXcma2WPFsXax9+M19PrB146Uar9vwN5NjXvePbmzlnrivH/oKNV+uPN9dcH7z6T57+Ovs/ICbVwZp8UextRP0SFZVP7o9svXX9i1CqULxsMWTVc+VGi4UfLmL9IBfVOqGugBtu7cVQjZ0O2kExG2yipfZ30Tsl/b/WPRmLGN4+nYUVRNEkVydK3bTHE2KRi077ShIpnRHvHNIFXY3U1TiPeQOsawR+0T907OwsKgkvOW/arlT0y9NTUxjbwS1QV9W3iJJo8D6OX9RK9CHFZUXOZX2icInCKs48m7EgMI27GLG1hhpQrvldwABYL2CcXg5llQ+pSpQ9UIZQbOgxKT7Y9KL+bZhvY/Zi+sLiWUUpk/XRU/P8iWD1upVP0OshK8C1Btdk2sHDBVcyDNNyoI31k/LK3gtvnvcDLCiLa7JRXJhfXp4LxswcoDOqlxCP87/+AYlCndx2YYkDW3ieu6iopNM+/HI4XUceghm3wJStNEY55crkjOPsWa6x44Fr2bIB32CcPrzsOoWU46MphnsOCqtEXJXc5vmqb9JsgULOYghcylwoKWgdwaJKhgK3YDhcffXo/impqkG3AXczOJL4mbA/+AVumd59rsPR/8rtCCMzG+gi79Sd6IWb6dZlApfo1mHUaSPZ4//danpY98JUGFF/zs67G4kaX9BOEY2JsZFSRKRbLEa6xRdGNN8RdYu3vB4j6xL/dECX+GVbfdiMcOa6w1O9ufb6EXJtv7Qw2RQfR7yTB/uY2IujpvnQx7p1jR46I9WW2XF2DCs4fMbyPCKqjr8dENo5a8d2yMWyo6P1YKONrXOGC3IuhwnvFAY2RKLQY2HmgzddKWFjgjrBJEKFHpgCjOFFJdf2kwr+gu/DAXK0d3HPH3GXfAo6sqFO9NMB/967fZ3oHSuD1tGBfs/2dKCbv96pqmhlQOl5oaP0fOl6Ss/pAaXnws5VRjewMsScIRia7Ig5s6ebp7/DneJiGCAhHP2F6DxqSTYLWSSugMDseT7q1AsdDnf0Rw9p3SGSv9yNp3YNQRIR1kk691gP54jotRiyzfjuSVyOwREIOwVtWgVGHa3IEY5628CpLMcxLx/Pa0lA2CKIvGlLH0+SX8UvVItJTjKIZpImWYqdTULkOiULMpzyZKdQLHtK2gWu6pPVwxJIcQENPYkPsR6MP+mSYLJnLdl8XVVtlDWAAXX21X4d6LtkWL42ESHdQHyMBQNmgaRWgMaTbhY0S4izX5J4zCdm1SyFp1ivWHdn9/kiXi4zNjtREvSSKZiyTjoAhERTJganKMWDycmplGpjtBoji4qJdwvsS8IVi2BZjuR6KGAFP/7frFAte5rJcs1fsZ5V12VSZu+7qHJeBV8OUB41jW5paFNgXPUiSRd0mMfxuKapTm4191TMNMKCCj3H88BnuhpucX+FpZ4TXPJIu2ZTaYXZqlRbUDm5mNbbNnAQ0o32Lvl4H7cawuItWL1CJ7SzbKTLFYG9B5gWilhpD2mv1jp6wuSL5q3wJVYidFEkt1/KB6G1NWXUnYUqNS1jZ4sq79TRL1Esxx9THUg6Z/WMqAta1h6vou8ALxjMr7oJuTFWjh9Ri4U07RFASTtXznP/NraKIpb0QXwJTRImNtGgQ95trSZcSNL1FlIcDXmzV4E/BIIb7hO2QKSD8SGf0q2yJIBeQyrIuJ/0eUjCQ9V3Lse+IJmH3EOALaigTeFMBbJPErVeMJWckiH1eE7Lg36PYVuU0Ylaoxi/FLGLWSlVR9pOuLjJ2aBZEMWt26vBXi5I+xwaJgPoclzWE1Tk6XtEFFhFpYsZfNvSmPPiVTWBqVZJDgV/z5YxxEt+uTimc3MJl2cQFCqmNC5Gd+8yJPj7e4NiJ8KB29CBNUQwHa9zuUEYhD2+VhR43RFQYc7H4N1iZufW/k/HF9azYz3R9iosYanFhGmFktFIvgUrF6069VLGIDIbrnmmnGMrezObrvbkbD1+zTqrvXZZJXh9F8MjXqwVI0tWyv9gvvccrLOGUCTaz8zzqahze5GfxnYWWMARrp3+KAfVImz6Z0EK/rOxr+/axh8F7cLwW0szpqMM3r/KYosCzs1X+sInG5aNJH6CLjjr1O7khYevi4iZ+QIB8REXiXzNboVC1/ZvvhKZgzCDBNvWXj2xv6UFR60u2/nlVyHctZO5Yu0j6+NkzDMvSTdEtSIxk0gNHse7iBm5nLikJyk07wwzCmkop4PXekE74/DZIjUHPtgt+xoADL0JAXY2tH7/fqAv0UGwN2hMkP/QOxzUHVmTOxGvzEiBx34YPDPSzGiPfhOOtAzo0wPAwPxZ8xiIpQTcltDNELqxbeJxiQnXtNqsfbo3inbgzHr7ZtFWQ7BVddL7yAbWOMYI8sT1cjLEu92u5seF1PRylv1cd8i46WCLwXeiE3zNfx8lpnAxDMDauxzVRy32bMDlXx0VNnV2JVnxW689RoBdrxvBI/M/didVnbOl4mTt46M7aK4H2bL37FzSevelvZXL0U0rl+ZLN0Z5w3h7GOJtGffWD8f+bf0RkpXWCMmggybzUAm+UYw32av7HDa7B0leDQfjXodNsOp2JRJPbCkSm2yPMefcylyPMee5l52cT3f5b57KzbN6SiC0bg2jZWBp2j414EypMw+PDDjZN+9gYJ7bG5h7Ng/MN61r2EnOyi9C2piHdeJrqdPr8GL7DCvtbdrvbT0orwDbfW+qK3RK+3JnHDd/vkOufGtbvKWRij25kGpHSXq6MDxEHrVewXXXTrnzveua3mA7f/P7G0lz36Eh5cQeB/bB+2Ox1T68+qFygHL9MPh1/Wj3f+1OQrp4SxHxkn78/Gl9MDl7JFvObzG9XLdeerm5d8Uv3zy9vLUPcWdj9unvsv8FvZJV0ouutRQ6l62K1VlogqP1SnRSuhD9SKwRzgIREUNdTNTt94d0lagfCoFWAWdi6Os0LIC6ZuF6YoiGEfsriHVaWkusE5P3IGGB1JlwrICqdYpUrFMFK/FdZjHjcnk8PzPJAQdl31+eBEGR1/IJO8iTiWiOqBRCaww0WLMMoYOE7jhlxcxqiRThwgom5CZNK2/GRd4RhYQoWHh+vBgkXf5UZo9BdTsZttkM5nUL03FzAXsY8oR6KR/E0c6E8qf/wk/rtUqqJd2J6JAqOS8pQMseU1RZPuQH1pcPobkIsVDIjKFzYEnppYJeUvSkjqEXo65LtoQhO3ccNsQY1bfGdCuv4xNGo1EUsF7a6W+xPwVf6ASB00O2SAviXIV06goRU62vhqu1H8M9npVlWp6IISgK/hDRfzsALx+sI7cQNa8x7pxlqD5isP52rzfcstdhYlPEvXvBrNBvq74aMgQD9rGYIbQKgE1ZkPB0c9qie4aJJ2TDgoq9EY9LspgGXZWUHOQBfWp8H1ByvZo8tEhCV8oSKF7Clh7DYqqWF0xoTgkebNCXgQ4fnBQFPWtP1hMythSAepfsKrlQSPMH65gx1UBVL/BY8jhzkvx83S86kXg9WMeGqmvpRaj9FQqZSLt+7T7GSibRGDb1fEe7PkgUSnmFV5nX6LlMJosuLmtVci73BMw9S4WEmjZlW8wcKWIdjZTuTnlmwSAdcHKZcWQPA/icAK8ww8obZCnHG0WMtYMoWCsmk0TbF4e7Ayv3H3EJIC3PhaXmLqEszmg8WrLQS5GD93JreSP4ng47Cy2T92Xm0l1Ju78ckYDL3JebQeTAZy0OCB+PHECXiL4KRoEwxU56LlZk676jiOqjKFn3yd1k3QBIXg9Z93/BtUkUFUyokrd+BbBXQPZwOWMBA1bizXupzRk6MCr+y1NpAHwTsr67HADMXM9s21Idib0Dj3FeNCQ5PADooIRVeUACgFls46dNZRwjzGw14I0QACNhsMB8sL3y2VK2s/JFgla0um3RyufrxS2u/Lrl2ic7c3S/B7UPW2h7isVzpQyBt5jfJQufDxeeZW5tLzzvknW/tXvd76Hr/nlI4yhgwL829okhzNx14K9uAufu419d/KGDTPvTCBWQuJdJFEXlGz350bxhP9bm9e6NeL242LR4vX/UPNXh9QptOmBI7P1gi9g7+1c7DoVBeApQvO4Ymm4Gc2quxscdH8Myet0Br4jHmF9OgrEKVJC76MBngf8JPKwS8T9dtQOInUMBsRr76Z0DxP4gQuelsn4ViekMECPyYteypuMIskbKO8NM1JWVA48GQO9gVuWXiJ7LIZH1l7F/Z2TShN3x9Xe8xQFq8Wof9bQ+wDxtrMLgbiUaEshS1buWrGZrirvekuEif3qCrFzvBBmGrIYFGSzXVknBg55/mY4YsG44XbCPYV6207Hz7j9sgbtPi7DdFrj75Bf3Q7rPo2huSf8cmy5k407edgmbn6U4nqb8rlrUEmKcdOc1Q7c/1BWTzoLejklMkvbG5GMIzgYav2oYPFA2yjrjWNM22F/uWPit3TLbDQYv6BEWPBQJZpk/p+edXMPsQbmoYE5WNYluB6EGEPjPVivVimo6Ih9/diesr4x3ovq6IVHd/E1AcsimWSQGTPBymWI2Tucx6djxd9mvsGuxKiwlfswkyH21TmvfSArAa+NvlVpZaA3/cS2bglAkI4pBgYB5kwhVQk/weqpe6iIX3WK6tko0KdPomkVsURJW+kgLhxmygcKtwdMoRgoPm1qr4R/KSGqNOtKhRaFD06RvmxD9Q1oEaYgtr3BCORyh8dxFd5GmfTpSis1BirgrIVccpOezzEvdGVsj414SnzGCZloyoZsPBQhmgkgeYwzPYpbdnJbOkipYSqNGJRSAo5ibA/mZx6Agrj0YjFMRNg4pwnBfhKyxkjAE2Sb0Ag20EanBE9V2fGNirAqmSgDddkDXCYFwJQ1ZdhQUvu5hQSd3UUll/hARBzCrhJ9gkwE9kDAt0ZBRvuO16Nw+0WFOqJZp6bhKs+yynoKGLg74f5SAReCMBdOCZSaBhvlwExd4UXiNWlDTssKoiTETA9/+nG8qdPpPxKAOIvgxom7kVVUCpJ7J4WQxcOczkzIoDhbIG2RMDqxO/BKcioFA3+NlWLHjd4fXt0TGJ2X8viqc6SVOAEVCFzFPrukKqFP4HRPh7whnM8m9mbzk2TwZZbwVD45HvhB5Ea+FX1HldfnLkM/nTPJqMsYhMVSkYBBTeAqKBNhH6LzSfBhEdRJktlOg4nsGeFk8GbF3Tn+B/X8oCFdjvx/7u9iPBiDoAwyUvB8kEDrYyhVhJPj5NzeAn1/F6P3w8xd3pep80wa3CVbsuk007+8BnmdXZ7uAZ3b+5OUn5ya7gOeLjVwSA54t6LkKjK9qp1rQ840t6PndO3dFeVPP7eNh/bePv+quQh/ZfMa6qDMJw28DcEhQiPCNsXc/UBDhxhHWdwkZQAcv60cHT+9KvLx5g3gJLyHt62c/MHhHPzB4dOcW//6exb++f/Hv717825qv68MEOZp5/hNLfhE4PV87I0PMXrIt8+BHCPvWHaPpcmlC04WDxwOdgXoj6qIdY/eye3Yu9P6gJ/Qu3zDv/AZCzT7975zFcVBJu5SgHjW30xU4yDQo2y/S8TzQKa6ot6brWUEo7csNH7IXmN1Epm9EnZD0BWCJisCcams4ZxL7iOYAbI5wzpcssHLvgYIcTJCcRJxopRltrTRu7fW7CVnfmMoHBtQChEw+K/061G8uo/T4pAY1MwnvGgPMeejAWWxz6q80GdUb5yQRk6c6mnhE8ff3TvxPeo49sAtQdjyWg4hKBs2nc2Dj8HqUOKHZzNA16Aaa24mhTuvsvtuuxwyXbuphDnKd/hNpPy1TY6Y2zbhD8QGpePUA0yKSI3QiqcdokArk8fgK83S7hh2bMGzMdFueDmhawPRww7LzVoKHrgiIEo4kFcuZeEFJJ12sZTyt/Lw6oeN+A5NUVwLcUWd+GGJd6viB9RiFtwIReytRoZOwoUIyITBluL+SdMFXTCbOK/kC1AgxjjUD7BOdkwxRHcLaE/URE0SjuIH722edVbrBdej7mUpJEdK8OaUZBhQOow0+NlkJL4WpdP/+vrCphOjXawnHECnT8Aizq5CNOIbMzYRGCq1+gfIL70WqSeSQDoh636Mo1zDuhN2puOLDZAWpIe6rJb75bJoZYBIVTwjZYwVm/MCJAxP0xvdxTsW43blgIL4z9oWtBwlR4xsSJV2+Bu3bXZcwY6+/AQTP/GB1/aAJz5+tBM2TRg6aRRo0JP1rpikMxE25drKiFgElENeE2vEyXJCUJAw5EkpKTh/MdXsnXNWwypaeSufsx/WG0UQ7jDgT50J3IO3ZIJD+cqRAekR0Uoh0rrY7lm5q3p1eyiY8S88TFwZrIsAMguQi4CTJlfxpo+3FkE7kDmc1R1c0aFp/qSfCnt2OMLJV7twoxB7bF2JTR88/Oo2Wmn76O+zPuXjsfNICZQb7YYVOyM2wsww6YH3BNrT1xa/fgjtAwAF6xT/QGnDgEDKzob5Zz+eYt/b2wx7f6oNBHcwS7mDu8PPO5r0v5H9Z1hw2le1quKGXfXWQwi019JiWsvmcxFzp5KEDSj8BIRq4OHyn0/FqwJ+NdLzuzqzQTlfCsMS7GOaVvjfY3TK6ultXdvfX/rTdX8tY8sT8rK4rZCozEXpK0w6KsbeExh9GPslnTfJZ8k9pGeVCCbJzVVSm58bujn2l1STpPbpnu5SfVsLHuPPcF+BLrVnekP9C65HekrPS8p+g+SF8B2zr405ThbkBqd1udBeQy6taxrbnk7RyNBy5Mb57DBhrMg3jDb7DgSEisJAFggOa4RqqIJKJ1UopLaBjydke+lzow9RKGYGjgia2h7IhJZN6Ji7KBbvIviBdyrJPcCdbRWTeXDoMBVXdk2gBGbiJ6blG/PL1GizPXZ8Ps9rhw5w3yIdJj5GJmjYfhv0ipqVMtvk+UNdsQYbCFF4LGH5cSQDPB05JdtM0gV4g4oI6yqQFq1wjwllkCgp5wY2lYej4L1A4fEEoTE919bDegSu0ikYuUnLmQpvS0BmnHur4HgKMXRFojOATpAJdZDYxhVyBf95qNBLuQSEHXR9/hb3ZrhddJ1e1SvvIqAns03IXFmXfBM6UK5XV3Eyj5jJuBg5mqULJMIq5TELj3Jw+fmlZ51+dcq0cecgZ9N71co35245FJJHcXPsc4CyvbRF5w2/gIAdcWCn6THJ8fDywy+y/8CrMZNMqeWRsBvEGu7bi0WICNgQAZhhN8qrlisMYkKYUHAxjJ3ScbG4pk1SKx0q6bU1hSA1lQmBrWOA/Ia6Rqu4NuEay7C1ygpSMcSVlP4XUPVRt9zMQTOBjb4h9iTGpeFx40B5muvFW2oMAUtp2uVtdabXGSMW3j44BRmmdqKbg/4VKeCFd7FGb63ba87uEvHrs+bpvBh2hOTgJ0GUVOkpyfMtEhB4JlJ/RuaHi7oE/9OU5MvnvQrVOqHQbAVKbPpA08IuVwqMjVBcgP4yC2YijS4kZJ4Z4ZOtsyASJBnRhQWqTXwD5Gl7FThfhtkeUjVzZTgSSilabxDxPcWXPsOIiccFNamMQoyvhjggkFGg7sFdUHzIQdzEBgBOHiyMBMoVmPxFdE5VitZI1IF7kK0RRDpcNE0pKEhBT3BmIJFxKS3gyDmjZZu82iL8fkCSIMwH7XPvnOc1JJBWZsNGT/huTehbXUQm3Ifan0Htz0FIx9CT5kVC8EyIpN1loThMfPrQQIAaHWSp0RkRcP35dz3jM+2WXJ/dLWSnxyJ8omoDNylyJJCbcyoEtq4YSyuJpCT/QCLeX44qhRBy570NMjQgHyEQaD9+L41PCRRkfw+JEklXo4uFswleg4sKnOAxZYlQvTn42fSWeiE+fEpPkWQHfDTX5JIxsWAaH6TkO4okiVZwDWgxdJjxnLBXXBKgrHnZYvB9g1ST54oc18DR9qtFGJFcFTtCrRGOdhRxVqFnL/gySMbXY78L44J+2IBrSAW6i6OkIKTbaV6jWJiIdk/D0CnfPCukwkAAlaQ+4s+j1b5JWHuO7nEGJAhhhIkVxTvLeKPT3c0agv7Npp2qCeWeoxbNzmRmM1igabp96RkpPpV2Sq3BaxR39bAsai9PurWZgQJFaEdE7kKpOYMKd6OHmRANN6Nz0AsQYTRwNUDdUhISTcGrnWhWaFVOh8+i8FdBLcLJSqqaW8hnIwTPZI0f2NVOj0N83FhhlL5SSmogSjhUNOOjCXFKAoDzMx2Cjo0oey5huQsPmKMvoNvtigWirC7j1KyYx7BNdL5lWaCeOIxNlJIZk992omRQ3gSgiVrMsJGv1HE/OVGZfHjRnfFi1mOYXNpY2JbH2RRpryyix/i72rTNivjsPlcDjBlwUOs0I9qh86PL1rBN+b6DlkH8IhN5vdMjtc+dcevZs2ISwtYmuXsP5udkOyT2F6ind6TRc2eo0XPtghd9bupoLUdMhauz+gEbdtVT24T0tXf2HQu7a1PHzsQ+ByFi7b3O/Y3bpwVr1r25mj0wC4AsIgCy8p18OH6jPkzbTalQ8k9J4P/VIpFczcbG1sCIR7o10VR4yGYcYOlZaHo80QK6ZFYBxACyzXYAp32WBupg5D21u9g1GtZLm42pQMBx39tLbDx26/dI51ngIxNMlxYUjheLBuXx+7mCxcGSheGwmg8rHtKwCy8AIwgIr3kiCQQuHCQf6BjyjVZK1KSgrJKfYQ1uKM2a9OGO64uzPSJzZiWQ7zohXN42z41GczSDOXqahMlM1ReWJpS2uD9bp79L5hsthuf2VXaFGMSstGdRItIAqmRJiCNGjgBy1T6hKIVWkp1MRzja0dL+IMCpRwF4kUreLh0JON8UpKOF+IZJFqZQoSzd8L8zdO06Q+ztSCyuw+CH6wAQEMmfMVlMYEJJhg7OtUw3oNBzRNYEJ7YNdUsiu3cIWGlWBoRcSU1FUv0ykTp5XchUV4qVy2Ww+RTVt0YMpYMJu9LKWttWBav49LWFwbVUNURcjgnf4vlPT6aUFMLzz2QiBgnqKFaQAoBp6ocPwvg1cDcLs/QVV4Z+YrnGqxccDO16dGoO3hxik07KJ8hQ+43kzC+YGwQeIozv7q9g1mBHc0fOKMLLFLkYSE+HY1CIqPIkmGRK/+e4fv4L7In4uqjX28ZtmEFxptpRBdLWVQJpmMK7BRib06yiZNajEzS6YDag617HrWCM0nCHPP5WdnphmPpPIGFIy6XCSretwj9Bw74ftj8Ybvp5A39X2VWxnuZGAVkpKuoSgOIKh5FXbxpJKfjKb0+hKXiKBrIN7KaKz+UFGca0G8fLBqqd8akvDZA8liQ8NExnR2JNoodFlIs5xpLSA6+RqS0BkPxEbGMVy1xUJcyv0q8AW51oNgOU2d36S2dV697kdFZEvIM439+9l/w+5RI5PU1US6LEZIhe1kSwo8L13N0+Xawj7vRbohO50ckP73/PgL54OjhPGlEsyZZoLefS2Y1Ie/Vd3vlahcNJPolh4OZl229WqAbJZ8I/sOBdtEGsjmhexz9/NtVtZuA6x0zE7Wj/QRjU82o2Cs/nPUEcqZVvGSHm3FWVDvJH+ZiPTm1ZmQAK/PfbBrRvY4B6MGyWhKFQ2WFXyA9EQ7LG7abWTyiFw3BdwIbS5cagJDfoS7AdDQ9pkW3CCWt7M+vrRJ7z9SU031NuNDGkNMJJnDo6zAX5BTy7XS+J6azvvLlyLSHhdi4hfZ/7GzqHX48qFSgXTTdMTtmloKSk9kXbGfRsSvJ57vHy8cYuBeEspoC9CybxqB1DpZC4zx+t5XshOLRj5ySy6Ak51jFXNqkEpBNngHCUP21ymSgjGHtAT6pKDdmJYVyBgNLhGUJyYT0gese4heAWLaqdQOaFnZPKtKfwHraIT5XTZgUw7dojKaaYCpilj2E4uUbJK+BUZVDZyEumQ3JVtJwgShL3MEns/h6aG79PUcCr2R7HPDCJs+5lRDovFBxyGGwVau7EbWnvfCCfI6x4E9K15wVZhtY395eceGNStWR4BUKOBRQC1v499+6EHqDm0zNFpHtssyDfC06556OBpKySKSacQJ9nG8f70hzCk1vwPlq0aDqhaXr68frD/eiimRjLaN2ng7QOv4Y9D3u7qSCUvKAsPBKxCoJJQrBpQCbNCsZKLxk/etHeEDLVyzbF6G+la3c1QSvXDaNfV5nOYst+4vD3JKJmFsQjuwuvsfGwUTdjEgWpj6hDvAwqDBQ8tZz2gHS+kI6S7gHa0OA3wQR7mSCt2WdYuE0vITSxqhZZD7V/uNJTBvKLNySwoT+yzqZU6Brbm5Hixee0GrrVMNUs9a+vHOa8bsfC2PGd1smvOqh4yMjPEs/hfB81qUy0zW9B6TeaN61nXvimHNEWMazHYiJNm8fQ/cmls+PMAon8w9h+DETCw8hspxojdA4CU9N3NksFtpcC0STIFpo8i0+LGMB3j7OUNzdbJxJ/Y5X9dIQHS5ZRN/pDUVekKKOajvVEzhb61UdO7AqZaWCdexHQ+r54Lc1Qripe7MM3rJ7ySpcUlo02hAcvKEc83cpY5XjBSni1e1cWfMbXpExWbz0xiIZlDHTNtfR0zbYtX3VvcCWqMXXPjqSxBVUL7bPyTnsR8HbJCIopFx8A3JhwBmr9hwKEBjirXHvdlj0rN4FdLpGGMpgcqDbRMQvES8F0huSKOUaWMqsOSb0nClLoIaoCKfyu5RkipSdh+4tpgMhlMozXuJhNPatNppvIO45w1paGUnnIdjvlMx1zb73fM/mjHWxuO2p9hboYnJdRzU7IYFkQtK22t5kcFEgv6jWkj/XHtdEXA2d+K3bM76WqbDtq7l57Yl23ZQztX9ByrlY0axzlmx7LRr/9nE+/sP1zXO7uVgF4ZJaAQXrkg9puxV8U+uUECOoMcxGwOkNQ66000awbSjVAbyDARNTOsiEbMMQMLP3qaYX+rCzf5z/U8fy8Bnl5HxsAcbF8uaZ7uSyC8ptEMwg5NIEZfApGcBOJjqznkYRvhKPcKIs0AtKPEXNGfI76Qnr27Ny3UDd+GsSRJDPpcZlhicKEqLKEXeBgDZ/+wNWSGxcj5ANiyaxUsP4pRMfueLaE0Rnn++COf9/AO+PKJ3axu1/5nc6PjhU0Bmw4WM7Hzrb/713VGpnJIX4L+gRC7PuRo7qaW0YjWnsxbdknBiP3tjX0+2a92qNo12E9tR5xI6qJvr103aPh5fb/h589lmw4OfpH9Aaa5iIbNHz7IIkabWELskm7Nj8/EOXTAEWIXxIqe0eMsmk2O4CzasYOgS/vPoICGS3vfgytPtLnP5G6JEh1sixKt/WqoKBHzqAdqWdc+1zmU7+pTIsqX6TgWnmqPIyW0Urwh6/pF9idYVyI/9MGHqvzQJnuZfX9bbWh2UG3ovc2z1lcb+nDrnK19ZcdL/Hs2ioWJrSkMfWrnFIZeuMleJyP//8z+C2JiLPYcGNx9fKAZgvmVB1Bte7PVH6UD8rhOBwRFhicyfzroaqho+a/vTtq4cKNAWPu3Vt+j1tv3aLb7Hk6PmjZHxIAGBbXfQrRotxYV63lINH+8sZfX2ns2k88maob/hggi2iV/RjQEHkLaJZvG00h6JbdsTa/kW7ukTruhr1R1U5GS8tZFSu7bwdLk9Ma2Ymt/vYEaNtFL/F9akLyEWk/tTq25xTFhJlh9cOrOt29xDDi3r/JfD1gFurDFMV9fyt/UZcs4bk0+Ztgh9W3oZXJUl+ZlkAN7gHRpNsseA1I01/ZL0fxyd1LBVRst552by8/ka1sVybx5vfX+fu+2fnT/tv74EMWZf4DiDBe7IvYOuAzFags+2VsR4EPIU0uR61toVw5r25XWtiRfhLXJEagGXNzQDSZSeSP/dQKzyORrFxZ3vzIdchVh3+/V4OWdLarNy7xGElYwPLHoiyuZaR/V6EeXHrOsVqsFEQB8dinbfC0ZZ+PilmimsEdzTBIAnYJ5dUtJL3vN5wFdQ8sR/StpxwUO2fs3CqCkC1d3Svet2OmDaWfWsWCGSAtWRbMqLP0GTirTwwNc7TFFxO/JsrSNzn5r56rXN/TeaWqVqjckNfwTLJo5GE++DlZ1/7QDtpMPTiGyjknly7ZpUvn9ByEBNZcHDC3HO4aWl61naJnpN7Rk37WD59IvN74Jrb2NOl46JgQH246XXEwBreIijgHk+M7Yh4j5N/irPsLDpW1QLko9ETbVhhaBBuPDUDsr8pKKYGey7iEOTYFGfoEuPpkF6J48CZkZwEAwTxDqDMw1BucJPDpOgAo6mijA0DFP5CxXo9ep4M3CXpH5BH4ZARDiNCMQvBAD95D9MF1dcOBGt0dzXUl2AVUJChHPsGyT02AHjqFh1F6adDFCk1m080IETTJ3zlQBDad/TUZZwRP3cZcBrgvyhnQpmQVIyKobar2D9p1RfIPIi7Lh4AAj800i9uA0iMDAjfjUI8cfntYc21WVTDYj386pus4pad0wGN+SQFuUbrLqEppTaZlXM2mP5/OVXNwq4VOSr9pF/Y+UhmIW7LeCKW3lkh5Z6EIDOhevjEYEFIPIO9rw6GaIPKkWTgdkZHRt0/3jAahWajamlTGUvIcMCLDMSW8xt3Je+BLvrF4QkHeKjOOd/izsqaTYlbHngVf8EUQF+gguQGivy597NtQAmWFofgjTRvvDLrkahjaeVvz9XGiBEcmV1p2tmmO2PBF7PMsGvTVqhMIuuAW8ETJrzvyLpWmMvxSopsBXjKBgzZ1vZgzThUk6ZqGxqlebvmHCSUwK9uTSxEgd6pcCn06IbuPwAib4XeU+K7A0IiAjCaItKeLrt+CRiXkiJXLa6BiW9Rv/HIbLOqZO8r5Mhq6fQnJcPpdI7k/pMy6kz+SiM3cVvOh9iF1hmluXbrQSdjqvVo9XbmdJNshABiI0HEDWkgXHszmSE5q3Ea9MiKL1emVG4u4dr8zHU+cNCG4R340ndazLiOsGDAZ6XTf+jMnuz5Tz8uMYGik/5B4Bx8wrYWT2Tky67UqkMDvrm9kOEPLq248QJVCd+Nv6IqT5nzvppdncE8WHYpKWCfsiBEixVEwkD24WIOdUfqsnQMg0fleArF1TCV7eba8JneIee82v3Nltr/nMXnvNO7rtNT/NZI9lKroffwqJi3LbCPH/YOz6sztjhUhiC2jKdiKL6Y2sYCQnxL6AYT/UNkacH2KM+O7m2esaI36oZYzYYCYxVYSY8BejsPNJ2Bm9YWe0wm41l05kUt1hN49+59/1Bd1PNzXiPIA4clguhziKiw1Gs2pUGzsXWJM6EZLRZWYqMkpMSokQtS1WL9YzQG3n2Ufh7U65wb5An0JSE6SCPXO5ZcLBmUjwYVLtWku20lm1cqRyBUva7WnoA7eykiLzjmvRoHvnKCaJ72QytXRJd+MPY2ICwunjNJwuAzryN7Efxn4Z+3WYanY2HJgzE4av+VlGoGIp9QoZoqDTVAx0UupUaQ3vbrHl7U7kUc4k5pDfgAsvLjM/22bYYDt/sD9Xfft+BHSiioB+BpQOu8TgvTte2hfG0osWqBi8xrwNhYgVjPspV3dShk1wXgQO0pTvQdKEuUqG2DpZf07cSlTipX/CJ06yLz3DUCP5rSvU1j4yR4KcdvvzgbWkqwUUTAx4KnG5O8IvIRHOMc9Q9hzZq3hllqqvmcmc5hULJT89BQIRnodbK81aBdSQspRUdYZ7RBTHy6PF8dqXq4rM7IXNgYfhjOsQzsuxF6FL9d3YT8+IRc/tQjrcSqE1ErLs9FZj7G1b8mX8fSuM9m2czX/ZF+2/HL0qUzewY2TniR3jeHfdtmVvxpcxTDDjjVLlPXyjQ/zNj+gu387rLd+24MlITBIapLK7mqH3wm9xHu6Fj4ST3l/Q2UIUddu4GXLLw2+GPKYlLfxUv82Nxb2OeBj4LfcMcN+IWEJreLxt3SZEd8HwJ7fugr9PfitelOMNho/HSUNM8BLoYCgCtPi5eVzyRBEFFwawQODiDAPXMcvCkDUREFTEc4iGEjNuZHggWCnSUj17rIDRX4+5ihRwuhwkPeABe3B5BrcsjQEuRrbMBFIJ7lRMwnM9nKM8s/ZRRpLNMkc0Jx+GBXuCNz1Z1zv3wMdtcg+EQmbfPfB+wbRNHte0ewG/GSnfIfPdmYrrxwsgLzbBpeeDBVdT4hZRq/3fn8VlwV/SIXCw4LPnacTVDXWbMj6/5P/Ox/RaOYWxNHV8eubzuAAun9v62e+un0pHV0AbYz55qEheCi3bD8e+R09bHIAu7uu96Sb8ayffdD4mkJFI/7q4Sot6v/uodbvRooMMOXJ7FUmj9BPV8B7YSPhLhCmthFKkHDmDu6kzdWKfwkxwlQ5zxkGrA28J7z3L0RxG1dBoPmT+RBRhOskw5yfQS0hpTlmvjicc1SiaKuiJYCRZQiNhqwlMa8B9QgE10DG5WT/PscXKXeAPiewfZJMq0ReEsCFsEJjfIBiDomIdKGgE9iFHS3wxIet6QiXsMlLk+xKEtMgQYEansJJZSJOj6LaeOwNNSI2x0vhFz7+9w7S5FYeroMPFAesftyHYpTiizD6JYaxZy36K0fBsXUhU3PkVPa1ZyBJlm7CtXGkPZtUVXVUWAsVKKPlcEH8MyxbTXoEAakCRcEcESY1tfpmqisI7QtXHpiYMvL876A0g0idlHt17BYhLZF9cpwKcMgwXWJdajjfnUsHzA6/3vskSETONsnOYuyIxA9lPBhJJ5PEksaXISI9E3vGQd2JwBLwe82X37Roe5QBcoHeMlc3dBQ+wjdow1OmLu4E6nWMVXIkXKv4+sOM2MBZsPrcHZrp6l2Cm5k9Vr+C4yYmbJjfxFZS9iZP7V4bjSYXTnwf9MQGU4DmwXPi7XcKTtuMGONQMrh9J+tl2cQJpAEl626jOgF9sK+kTYGADf7jmu3YIS+qrMpq3j+AS+Oses7gb+szi7u6Wy3/Oa/pxpEzbLvBDOxQhfF+E7Lhd4I5jjeh7DMTIf25G0/vqGcbGs3cKZ1z7xuY+gnf1hMYVfaHxwu7QeE1XaPBIHt/hHOrY8sjYK8DDfe9gb3x7wSKsLPZdg7YQAT0N8oVD5K10RcRT+7vlzJ1nGiHxj3yjLy6eNuqyD7i1NN/TjoO4+PTpA1VDKR1cXDhYVpTyQfZIKywWUvrqFsKC74mJ1/as9wV96/3G7vX+veaLiScyp3hoocP9WPZAlmpHAGmnfwchFI+dREFAIOYtSZEzQ6TIyefE3SkshvWnsNGGC5bv7xIsN8cs5mBHrlyZ8t+5G/VF89c9dcML1xUzn1pe6BUzR1ANSJkjF5SmMrtUe3xzWDFBdKxz0LH+IWROnoFYQF3vkRY3UbWnCNxs1JEOViAojHvCJgrVC0FLApkNm+rkqnqQ7dLqWwR9A9/eqJAmZLS6y+zdahraT9rZ0AJWlWnnWqtkYwczc1fP2WVzQ0nquavmGbcmWZO2lM4XdBUDmtJxBSDXBKStYeZRToklmfledWnuW8+Hbm9lwnHY25mimc2VvCfI+FXAynFv8SY9DDHcRYoFdj0JaoZ5VXJV95a8hK+xOp59SrnBSKdy9jgqy7gfQNmcYZPlepJjxuxsMmkc3ZNarNKJpU+yP4OSzKOhK0RMBHC0Ud8AtvWADaYlEbiZmODq3ODz7QiJdz1fLpSkynZt544iVbsXiOsc3gh2HPtEgrb5R3FPk8gCXIMFIGMjDLvnyZPriAJOjE3AztytS/jazrM/6PlTUJPHHFMpKRQl5jOV+ZmpttxURmG61KZgk9Tu730JsnDV8SLPvpixKskTguvYcZ41zjPy8C7BSPaEhbcjEjnJoC3z5+nZUObvmJBgbUR23hBNmYG8tG1Lq0ExjVIqDhefFBbGL1T85ol0cBafLeUEL8VJE37c8x3aupP0RI1cpf7azzmzY4UZumhE6ZaJ3RB7M4yuhiyauMmCYbk6guCbrJaznSG2cA2RIwcWEZdUhtlz6zoLOH/5ArLlKOvnbWtG7Q1Y2cqEBWfHV0ZLi5lDntXPVyERCWF8uqx2z7Kmw2Udw6UtXFY4LrLRsvqlaFlz6WhZ117NqkZoS8pkguMA5gBKV2jbxceoIZlBy5fBlZfJZx+HJZ5pGGN+S1cW7dabwRL8HcykDlvl1kLv20Tokzofj7DUtWjHba4cO2RLUl519uCBVW+dPdmoNlJ2Qdx0RZvvjbZb85YRpGFfMbAl8T7MGZ2SuRRn2I48JVilxGb7kYu229oXNpOAZcMkiv34rgg+7SwFgey9xY6h3KLfmunEAo5gR7dImgGVM926DQrjDSaGWntX3tO1Vl+BdOZzuuzi2Ayxi+Pq+Zb73PtG9J37AvgGn998K090L/xXsfAloExDUkTzc61NyrylezvKvuowko25RCRuVnM9RzOSZIQTxnLq5ayXdGEpxxNLOYMI4huwAzBhfCozMrWUixuaW2cVy1fPZF8zQ9PFz9sbmM4CQ2Tz/8Lx5U464ont212+EAS8tYmFRnTHEHprk2Fn50prW1LOXsQWjQyaGssTDDUHboluMq2XpIXMSw1AhChkAJkrguX58rVmycYAayYAb9NGoVKqkgXS6AIdUEyFb6RdyOZylRT8b5kf15bnc2Yl75RnF034KxCWJ5R19VA2k+iWFpfmF/LBhAqRTTEZoO1w1XNhBIeyxmafxsh6Mp23b5TAYkOzhJXla5yao+ANJVjZ8ea1eg2mLqymBL6fOK77QcrMdEqXFEqX5qswjp30QsnMwnKaSGZGipmnAFhYdYPURE+wTHBVtb3z/kyRrgJRyjsduyl2b+xPe1Q0iQweISc2Qkrlujp4xG4ZuXoELc2hCZqs7cgbtpWAu5QzP8vMXDVhTZvQqV1P9m7S44nuHfPKjdQzPziYsdENwcku4j+MctC203JbKtOu6hQ9Gq5hiF0FJ5YNlDLZlYHUjf4zvI3BGh6hYOK666FPciby76OgFvW+LY3dg3eytKHAZbi9gNz1KSGus9Y9TisjLTbJwltTQ8xcdiEbnLzgHMd0VBIPgW8y7ByIrOhsK1zBnXDnbppn3taZw//sOksfF7GSW1l7pODypiP1CjHLIWcDOv0JzIRTCURZssFyRUCyqqN0hu6f1JtFEQGyESftFLYdAxtm4TAGwoKpJcpyJTSE3tdiMm6zad6PKo4qIsVtRULK6Sep/WKbxA8CLgJwubcPRGJH0pWKMwPCUq9zM+tIubynh85xxlSOPtbQ2tu7NKZ+toHGVODDGeoN60m8vLkl8XIfovJDXSQjHgnjqwjF07CleSx6Tx+I/e3IxjQ7sO85MgISCm5Al6OtuUHjbsGPijzc3kYZD23dkS8cxYOmuO08IFqNkuea0y7Wc+1rkNrwRZKCiNYGpxetpcfuO3zX8WZhUz3Me6KjJLep3cwHhp8R3Rli42v1f3NSMpO0dUJFEiW4P6EWJFcEkmPxT/NTG6pgsgc6p8z46X9Cl1+INVDOvQGnzIiqGg8c+EisoTbS2Wj+YPdhxuVByY0b+iU3fgGLrdoDiSSStuQ34MbG0bbk26hLy4PXltxkeIbvaStssxOJo6AwwFh++ahSH4/dcDDmeFdnYecaTCM1HzdR/Zjv7jcWYMTXxNIfBYjygdhHR1GKaI1HhRfyQaWInaejOlsKigr7cTPgExWiG7HHnfHTXsjirPp5ohtxX/NCMFiCkM8J3Qi+QhoyVDXizxeWNYNUhQtMfpuEO7CSP9QXWGsjxgtib5zRI7JmOTgJ7VGUkZPUQg4yEp5mJsg3F2ugIyuYt2JvOEP6XH9srW08tt3osOJIM/LbaEWRMd1Hg7v5xpYQbX8zcodpmVsd0u1tQv5/6r4DQJKrurZfVVfqyl2pc5zuSTs5abO0K7HKWQgFBAhEEiAjI4z5JGNytgkCPhljAf7kYHLOyYAtwAgBRoBNMEmYZE/vP+9Vde6e6dmZWcnLit2dnemerXvffTedc6rX9U0hn7Pze5UbmvlJfRPIT3XavQ++u3dnNiP/uAkgvwe5y2W7Tf110I/ykHB6FszMQAxbFHHa+VJjc0foVWvqcYUXb028iVy9TUdhKw398JgNneVpvWJNjS90OstWpJuuhx+dMpIfPWDDEHHnJtDKF3YpNXGXkdwC9aP7U043DwDLM/lpZBh/gOIrNTRFa7duk0ggd22JLaO0Nh7p/+VbhSSVokXHQYryEwpbCfokvZq/Sl1g3tmIvLZb3zWC9nZyPbQ1aGt9YE0mAgXELsSfNoNs4v96IJsfE1Ue2Xm2uiQl0zTFSPCaKGriU7B7LGgQ0sVz5TXkqQfdScMAFhaKpFUVPrYnHQo1ydBbFdBvxo4k/hcHPlbVKXuXagSqo6LZoNBLTcaWoklfF8IJoimLZsIFna0igAGSZyUPXgNOi3fCxrMBLAO31oPwNPRIH2oDmCf7a4rzBIja5n/A+t1OUsL6NSoQlFqcOq7onuJQ1QheRX0sJ5VJCLSaOtwL/zj6BeCwdcRH4F9kxXWZqrJCY8LAAUJurKUt2rMxTQ0OJYK21lMUD91tRafgC7pB4Sr46Zqc6FlWwqYfFZFVy3wS/VsFcsPJN/YgQyPxKF4rV8ubwUOZeFQbHor6JnX8P/mz+WLsfmCl+Fg0x+gFi3dzDcK9O4HitJ22n7TEx72lrjVgSlDJNq8i590lTCh5nl0RKarNRn/YztEmw/2tMWwwOJKI/VxbySzk5ZSt5rI+hQLwaRQ7cJWLONO384jqhOytThkg25JFyN5qjpYESSicLonN3v/eYTAo+SJIvxIMBm4WTS1lPNzWQwS45qr5w4U1WsE3EeCodCZlUUyi2AZpKRqSTTQ4QVdYs7FYS5Hl2m0UB0prty4cKIYj3TjQLQEJcEWmjn+GP585x9OA/vxm7Ae77iDNIQkqY7wD+iOMiJt1YZdYH4WS8o6GsGoS8PIL1R58aS7cbqDLgAFFs9QrQHf5u+lD5LJsunzpWYugQy0Wg7OLvl+8iP5ORmNiU/jUs+BmlINXhFTzS6b2hzVcOlwQbDnj7+10ebw8sRvO1XhcYc1JiYWD0zPFvOvmQe6btjX6O7NOHj8K2K/x2NAHQZOA2cBLvaDlo0KuxACpB/mUm0qn0vmAxaRvMrc7A+Obr+wMtNTZXbetjeSR3NtbwNK5AcDSdzWODgWWfqoJLK19Zxe99ILNfHEWrhjuNeQCe9JQQNUBJsDpCFIatIkAz2dEgHPklTvvjtYoHocWQAogPHqz1dC5e1/sO1tRId9VT9nSvTZCN/iyEbrAZHYXveacka++9c+PIprUQR6o9jMHkh/tvEuJW0PYPXczPsEUugjU9ZzYTVho/sCAHsLdycn62gtn9/UTTr9buM9zNqMFI0+9y33jdX1kYSn0GagzXABozA/C26zF8C6Mj7IPtEo7ka1toruV73AvcktWc1VIzI2Nj+WlEReGJHT/Ptq3edRYv1u42gWKY2DSmMRWkcGbGOWYPJfOp7FbJNHdIvQadMFyqaMlkgmSYLtFgmW4E/gGZDfpp9BmIPg6iJU9bhd88nCnT85ulshz6HX9ACVkFQSndIYVes8sR4G4bU8CDLfewt6GQNw69RmKxPVqIUldSFYf7sMM5xcbRlHfQbFAWv21kEHBw79S9rFdB5zAaZyUQNvAAToTda5j+VBnjp9GZM/zAHDEGbtPZdaQOAg3uJMTlIdflWUbOg5xowzPSahusqKaGZhPS3gKRmGVoiKiTcWLkgWQp4AlJVeoF8qi4QkKJqAqdhYu53h0zJOeh8r7/MxeQ01VasZ//dFfNOyEbM8H3CGMSw2KshUtbWJuyX/BrUatmgY4Q5uYmbHPT2T1vJrBpj9Xygt/LkP8Iq+oabTfpfT+vF5MGCnNgVpBRTOLtluzJ/i4j80xM4fPkI36WEG8naNgh0A1caNks2msfkhE0PYusfhxKwCTtAh7IxWa3+XjL7ThL3i9lZ2E7bICvz0S29V669FtoC4e6fZxugMQe7tQaV3fAufmjhbxLV3VBc09ewRo7uIAaC5rd0UzNOZPt/OzzJ/+IfabXfcnHpdWhw4X66YHLSEu9jndUlzNOXm99RGyAy65m872YjXIFmwPklUtIS4TOxTSWNkuJq3pIvtDajro0OJydKw92tMZKhliidkpz4R8jsvFtuO1u1L6X2Bmk9gYyJUKan5/KMbFhCpPWcusZoIFjv2hetZYS5Dr1ILDOVrKzkxQZXTF3Zuhf86Rle26dpRWS1Fa/aHYV096Wr0jsbE32b6+L9mu3l3j4hPvivx72zFx/VM9KTkXyx+/nfs5PxE7Fvs5AmCd2q6JHNyHSY2HInu5mzcglP7rog1Yprzw9WV0E4T/DUMf7oHGnGEXfVngIOFjyJl8NrzasL3bJCFAq7iHheC+d9PZDjkL/mP4JYcNQCiZU7qSySylNyExgF8EiWK5qELbcMh4Z6xvvFM/qeMd3NB7sLf0G76AG/q5DA+7yzMZtsDEImi9A5Y3JVQ3ZVUIw5wdhcXozl4hr9u9APYnusUEILEjFISMzUWpGd5l7uLHXcmSs7hNk7O3t7DTuXKuiZ0u2yZIrHlOwmzaVFyZgafJF3Y+Zn2FbTM9wyxlsbQvTweUdjGC9aljyMK+O4RGgQNPJMDTbw/B03Apip6+Dh5RZfQJ1COeg5tvZI9gltz6DGbnaBS25BLlPpe4su0SR3tcotC+087djD/hPfmZyBmKY8WmM1Q6gfTQFxzVGYioqVvLoZ69OXnCY7sc4qE9YPrHd/nD88IIgUxoAlrZr4h9PZqQiJtvtzWX0k/aXEToSI8wtZkirZehuJrVkOsrYr5j8xIoa4vcrUBGCDAyGsOH+wWSXt64mgokWXUFW27xXBUkdW9uwh4Of3AXc6erwlTJV0zdsJRUyhPyNSHu+JIua7PYoonzgoe9W9mIs010pLy6ncxK4brbGWqNrruhXxE31CSkCsUqeDczWHQbJ2/a2OlmRoxA4FhvOd0ZzSxJrhj3pc2tPCYI+PUcznIcUYGYH+SlrERdXS0szM0jt84evwMpUQHTkqeiT3nrCU5LWjnSjnjP2kYhxhU7WDpGmZM8tGtO8sV+RSUec5Jch/8UZrMPsOpwHkWPb9t7Xte6kIpjpe4YBM1Lu0ngcl1zQDLTPSD5Xf+AZF/ngGRuca41IPlhy52ya/kbbBPXirS9dmNXdHpIT3R6O1w+Ivq4uvG87tFIvms0orHI9WOwvdCb7IVULHWXc5tBgjj8Bmo4d5c05929+jgFS4SKqpQu26WDORW6mU15nHPHbZBKH6sdu0sTnsZvezVzUmirQhnEyKv+VJdkzlJO9wxfzH65y6ke1ZsD/W3XnXdDWP1zd8JzaPX/TIq5PsnVv9NbufNb8ZbL+8r8td1znzt6C/W5kb2jr6R/yi54y5u6K/Ke9GeEfJjOMxzMMxZiF0HAALgOWqiwPdmlpuhfc2eRcz073HJscu+STtxe14Yjtf6uTzrIP7QgednEPCBtSEFVzCXK0L3mUOmmfBE1rYpFWUAs+YSIGKCbSYWj4D0IHuP2Jo3Ld3UCQs5DeWwmJykS72t6luL4oOqD8yX6gc01xh+eLgSmy8fFbCEn/4kcOPelx/6Umfd0lOg876QguHJFW1R7Udm94Qjt5FDqqInYubFfb5U4il9DI2e8mziKX6svk/8V3ZxhlFNXdFBOyblCXiaXt0mnQI6KFlrj7Lvrwu5wtqqJ+dlutiqWVegz2W6+KpZ5TJ7eeNfdublzOz/DEqB/oLzg/wvGLyyEdrPiVZuYaHb1hd8c1/xzO1HfzRTpzTs1dSF/4CnDr45L0AVniIRa06yWMxTayCc9TNDQTaiVsyIlSCP4CCJcWsEx4OOSUkyWdiWdunCHxi7ce0CNkuQaHwTzelJUNEkH30Ce6rlRNQjNYvftDJTQEoIFwTSVfgDJekmWLZmCHxgdW4ZP8WfG7g1t1BjjSqC2hd8FUB1rwmJIvTqOtVrmTxHYNYprtG+ORLtO7z/aZF9pImxoqF4M6RnIZiRuwXjH2zLeN3IxTrOqj5VT5AKpICUnKilcEtVJ+7FUsksy65PjllOUxVy5qs1fPEmKUzOWNb8wq+tcsmBZk1BpBDj4UZVMME6xAElNMhXey2BY+k8bkrtdSws0vHEVLBez58wmK9xtVUh9eajNtExyBQaWU+ksJRXLyaCDhWxzuVyy3D1FVxdMuXiPOvHLVV3LJ0nSLWZSmpYvlW0jcCBJEAelTeBQNM76+4cxvnHcE5QEMDdKXE0nn0Wbn03SKH4BEeV54HJ/bxhTWitG0fUitu6VZl7SvExoxKiHBzvEPYY711Ee2wI+Udh61122ASlc84spSdXmtFLXO2MWkjtTK52Rz85iRVrVUesYWTmzJ+NOBskKTmTcMc6wM1Sr6bAVmCB/USXAk+QxJ0D1fMVyIQunJo+ypsbRIsrPLFpWlXKnAK3o1M4awkxVLY+l2RdyJHfqqfvW3zgC79SynNIp2RAnmbrm63GEC0nGyY0bjgZ8GWDVCd1w5YqiIWWieHXcE4k02HYQRQsQCLBdyVM5aDqnMpTPBrkfQpHivoOyVrkJv8Va5Rr5kJhoX/hVxphNGt/ajJOKj9nHf4rAMht7APrEmBw4q8thtoK2mjv8ouAH5LZ87z3E995D2PDwWJaFnfx+nJAbhNpuBNfM0iG+eXFFq0WLkYBhtcxGDOF73AHO/qAygxB0Xk/Un6BRP550HQE5ZfeVIvjow/1V16WiV8aqhjzVea1wr6dpi2ImMeZCew4igBk1MHWmEInzdj1XHB8TQ1wQlo00v0bRMS8pu6rGI0mpWI37aVZS8gQO617j3Ie1upGT9UoBljJJdxgXwiZcPAkWPAgWtu+GlCli7116TMftYI6N18zZzvuhUQgBPLkoCerC77RGWI0H0LeSp2ZqvGYL8SAZH9szIRFNCjIZxUKPK86rBSunmDLitwPawD/ypwK/QZc9GA5xKoTbsCPPDm4T70wrlXF8IPrY2mJ0joOlfa1jL4UWryBB9vz+1Lb9AZrjUpKqemeK266Z2qlueB+MH+hLciNStWZWwggVch0JcitlWmmDt6NvfYnuTDJ9VeLhZD0VSosCIrCqJGgvOWGDEcxXNIHX5AdBtiPOiQnJSph4K+hI8i9KQETSAVMzL1pSEnnGJLzqDN3gkAOINHmQ1QSwgcj2kPiaSIUZQ2fctEt2paindBUjHoN+GuhJkhIUKm3B8FWUPGDGsdOKrVioxUUKTTs9YYmgepQd8lXIQ+KTvYQRGJ9iWXacRwKKN3AlCY0UgbtVDRTVlpDLQ/zCkBIiZRKcx0Ii6qKMqAiLcFlJNASABnR8nYDEvkYBcPipQrQSabog2soM6khRwNmwRTUuIqDR/B9xiKI9BfA14HWFBPxNhtSPjptNwQGQLXTvkEYLaCjTwgEvGRd5mFClTEQIdLhKkeamAKmUDQHfyiSFiIp4rcZxqqvoZpAs401wN0JdA08nkZQTtDuN0wkImy4/H0bRca8pioPsiKMbSyz1oDReuNiuorGsg8Sr3iJvqg/mboJvACI7AnnXbl+UHZReX+HiwVnnn+mBz0vvpfMquXPe4jVLhLt5IzKvd+/uPdli+HKyLuNyEjQw7HQQfBVVyu/FJSF/swHBF/nW7tyRjPHrF8wf7hd7EV2q3/U0xwn9yOCroarzBoxh9H2Dxa65aaegoR/Bzbin7a4NV5kXcaYbJAplHOqmxw1kkJvDlWFSYJmaIevfrUM0i8t5gi3ohsyQ9uVqYY7sVsrTQHnulXMq5h5cpuAWmi43iFTuI+0B6hUdYoZoICEZZ3Hi2/CL/bGHxr60JR449jGUJJU6iy2VKJz43YYFMhpccLh3urngNnS+aq/zhaSDzdxpqPdV4X3RTbpFfjijPHtwEg9tau3w2oQ4KMjA4gsupQx8eZsk7vNO1UJrI6mV1vLZhRHdUVT4zfxREpk7Lm7OG+cxpwBDnOZ4Okt/cT1TwycF6oX4+zZxnKj4KlzR4gU1dEWUyHBFnbmiQ2wHnphUKii8EJzgTJwqJlKqaXHcROiJchblqOOlKJlknFA/dBj9/L/x4/wcWsn/SkQMPtlhx94DnARGYn3Ajg4HBLjpXL2pwD3dbMAg36Xe4UW9O8jBU5JJ5iZ8qxzu6Pd1N/vCn7Ms++rJgujPtlwh+wTOX6Puc4j4AU2mVztyMxBXTgNmsdjZeqSwiyV/Cc5ewJW4to/9O1awwoa0qVoOawH8xLeeI/eXkTmgOZdM5433HDjXqSM6ZNMKKNuQAYyh0DhczEiWmHR500Z35doHvExNqqUamoW8aCSgqz171jULN/6tmeOyVFnJ1YmiQmhIN9MJw9doMqLTpWpbBjsDuCG0NLg/dbC7UgkrRkoXR2ftDJkiHxPIxURVPDVvzhjIOuI0TZEzxaKeuWZ8YZp/lDsBJlFZVMHIAI7TYDYo04E3FDaEhK3KXuM0GFkI9qTGjpx2tM7ppsahM4dWuRpv/GQm4SXiyEkQZyg7qjfjzdk509OEvVTAG4kOcgZJVeJcPFPISSi81xC5ChXFTcygPWrXdIq9jXPnolEo2x7otvCeoIqHM1L+MCGOpAmPkSouSWC5A+0G2NZQnOCSxO4CPgl/qtD0B5wZ9NM50B1KccT5hAAeAgAogxRtuvk0M5UEM4FGAU2g4lGihtar3MiwOU6o68alkGrKPGtKUbQwuyy/wy7LA7FXUeorOixbWx4pcZLQP+8Yqe3qFUsZTWjNyRhNyCprCFwweezavdymyRIhq1cfrbeK9bXdvVnTvb2Aa2oLGHTogblRrmTgTKnZxYmoYsd77c5lWrIMHA8s6hrwHhClwP4hM+Yq6G1eSgftta2xWPKbt6XHIcPWYrTBdbqPC7vSa4ysGET/AxoO7R2z0VgyMfDZnL4SEYvRV47bpXZnIAMMT+K67mbzYp7EnSClNBsDRNUNkc8W0miB4jYI7EJgkHv19B4WWx3nxjM76DGf6e4ZQo8538FjeedwHkuJNg0I+ZQ72ewQZE0tbdy/s3u8UihGvQGJbfhrwHOhYNPhA6qmdXceiq3m8fdG4cbs8JD7xf469taRJhHjwyYRo9m86WLc8sJAHxyROpX8xwiGHjRWaBt53/Atr2yLFFXo8bf1q0eyP7lzE5N2DwRGsynXZD8FuSJ3v36v+sAwm7+kafNXRb3i72BeuhAtUbx58BLFbkf87v6vE747RggtVtQuUtQDfX3Zkx3qz6UEqKmxyWST/VTvJD998NRaUZPzp8zNreUVJb9G/nuXgvyUZWObSqb9XjikmCSH40bKCQKFcZwifW5TnLKi6F+5H/FToKW69X8JLZUgulIouM0Wa5DpYqkGINQ1u7XPwdrLPv3GsNEnfXTUOfbpbqlrjj21y3NsEELZBhjEfJeys0Y/0MMT2LeXxCAeutk8WRgypa71TanHT+qU+rd4OWsM+yKcUHbxFUbVrh2rT1++hyBaimKCp/sECSXpBsX9xakphim8g/skhtqnxC4D3SYQxqFnMJ+g6j7j9YPCKlvNIEuRz1AJ4DyPugQ9Z8qSHBGRIT2l0JvW/UA5dYXdnZFzfwuxZqTpgHWrOuJnIzvtpHjHxsguTpN3EVUAZ4kpZ1XTsJ2EtN+3rbSr0bTPNKnaiMc1/nn3Jt2X8rROiGs1Bw1rVfefrjuYYKmUhl/m4XDUqaRkoUDVGH6TcFTDxalIYv3HVkvEw0pFGnrtQj4o3b7zk2pm+9u4z2IF52jsDbHPjkK02ixlm1w9/kneSd+EZJF7PhovlKUn0bi8f/v8OY2H0u1z2n1hNKsRS09ItPqKZmflvFt3cQ99ZSNyxUWUfzWdtlxKwRHM+EHPUw3peVRXa/Pz3IPx89TI63beJe69MZciPCaNkdQn4DHXx77MVmAWw1snF+7kIvIj6KO6YLdVmAHSLsu+Vo+j3Q052NXdqw72LvgeVl6Wxu9itzqc25PBmreUyqYlmzhJNAskxTezWMPQc+7Nr8VdQzt+lB7qJS12KC4Bdqi4Xty7+GREonTY9JNabsfIoZ65L6MXpCN3lceRomQkJlLXpff5mhlPaLkzilkU7AR8JdmEBM5feGQdTUCO5AO60AenNKnrNWl/5UTolJ4ivOfkeyPjieI+xZAPT4eu2pfuJjxRm7lTF+KhDXiodgAerukCPLytH/BQBOChdle5zfrxJtShJit2sol0+MUWmKB+uPPucskmRLDvauIbkGYPoH7iYwFuw3+LkHpvP6n4BiqCKlHpxj5gA/aO1/rdKWR3YRvrvEeeu4ubetW1Npjh/WrKMqzEzShh800Mw/njdsU20pl88kd9HgMTUpexoOC1K5t2P8kutYELj5Fd6EHID+/EKxzI6b6h6pxq3KvbNx4yhTG7kwQuI4Fl9qBQ0lF1pVBfH4Yo0X2gch2rUYy4WGeNsqZJVhcX5v01uqUeLljSn1U6YqpH+8mh4gO7uto1Fl3AZNKZfIQpWCE7y+FLzgWlsWMlLcfMYVNSUY0pHxN6450Y0qBlL2J/4nwYCbN6dFuMBPhxZcGRvFn/y3peA12hEpLQxhVLt209I1jkFdsh330+pNVegD8kXKNsezqVQC1ZC7aQZFRNYc8ba++JAtBsKHOwCo8DKfAJycjZubVc420kPz5tJXzXwk6DWhonD99R0tw84LjHoCRzYewx4HeLQcsnlO4I+xZ07yCgIlPIWPa1CmTa33Yl8IVHx7M6X2k3O0Lr4JOZW/C942MWCej8uNyC5jrdNF3LncQT3bST1S+W71GzbVKyPZzUMeNCFAw5VufBiHFRUCyaulK7GHKuiL8h5LiiQs+DboHIupI7v4gqjStdFnTR4nTqR5BjLQhumYEkLdvUKcUWY5PIy00mSZDRQHOEowRb3BOxNjOdDoBAIeEP1kVXzIod7N2/N8jNp4xkXDUKq1VekjTHUSkCga19uzWXcOsPrgYv6BgGU4g1hdI2R8XkZyFRhDqQJ+IBXJsgS0QO4IAr8lReRg7waHCOfnHUHGCnDV9bznHdlKHV4Wxso2AezxmBG/L6HXIP8h9dDGrBUK619e9tnwWSe9n23GeGZKqVbpq0Czo51Q51cqqtv3VjwkcuJmOEzPFabAmCym1+tRW7avst5BElWAvZ1WiHbYWFZEa1JpFB9wRKmvCaQC205WuCNK8JHDvZt1u0aiLW0CivGpdw7MAIpNMwhQh0DZrsDTyYMcPQE7qeWnKRlEMrCh+Oa39Nme1UOoidMYpoNkhoV+syQecBO/TJcef1eGySDgNxdIHSD0xDzQvGedlTMLUEiRo4RP4YLBiyEvKoXcpI1AQrOHPmjV9hFGqcqU3MzliNZWw6PC8M+eko5O+zpmzB7gn5rmW7qtgd8vOHco0PQNth2nKnEgj4xXEE6czxH3Dr0Hc4M/ZnVOqrg0UKGRCed+UE2Hucwes9XfGZDA8Ki622aV9QYNbqDgmMNI37YZuxh6ZEW6TscVlQbmiTB4aF7ocidK+/LbM3b+gkbUDHAZJ9p+LI41vD6qKUQPMLbdN4xBWjipl8RsKXfYR4mM4LEAJLyP6hlJVHxZdZJfdosfUYk9PTpk5u6KLruWYEup4nhJs+L6XBHSWi6VGW6GIzuHMHcP7rAVaBWwcf/wkADBZMb2VtxUtP+7oFUuXsQpHXNMtSqYo9++aTkxgjM8e4HcKRcWi0viD2PUxAdgAi0+lHKz1+NB8JTq11OlInnoajYl61HfWab+wYOObaDZ0tY5AuCrKWqyI6zzSu3SGvKu4UCdkZbWfEVJmc1e2NbjZDC4R7dhHqvaPl0Eo6m1EOvXCb7kcHM7djMKOAfOrViEps134tmsCsUewEZeHsJp/qwTL2sk/13x77Sbu+wIe3Wltw9zOyHVRR1owdmineIopqIQ6bPFHfZuWDqZlmbh9OvWruK98SlQ68Wjq02l84fGJY4XAlfckWtROdjmgYf+kjkjvVxsdA7vQZ1A8vp46VNMftlLJkuc3aYStVA9sNu437Pp9Apv9/6LR0pxM+Mpp43ChUOxEy7+M7lc29dkS9OPL5Frac5vcRtjzfya4TkVtwN20vZ2s8dgSRuP/pgpLfs4er4g0hkjxkq3gss+/tEIFKgJz5ZqoStyP2XW0Xclu/WvjOa+XE7X5gc7v/rNPua4eY2U/jTvDiYF/WcW3cf2SnOME6kI/KwNed6N1g5h1R7Lgb3reh43yg03GuQxRPHv8eONri0JZ83cBGzzZD8Nag7GTtANeHZccHCd5lx+LyyhDE+aEOxLk1bZMDbby5Op6hnZwXtyPxHqt0IpGYqw1FhlcnJ7uR4XAwKT9Ws7uR4bhUyitRQP8RDvxRYAi+tSPTytFCht8KGGi/bnAjCGxBk2s5CSoNxuNWx7Yv3dxdWa1HAYTNATx73m16BwsE3Fta08u5/unluxtHhk8vP9WcXtbk8oF2MMkMvkTozRzGEgWLp//VdYmc3rxE/oJuuQk8q+CSWjzQ8DTYh2Q9sIiNXgH1AtlPpJMST+knoSonR5Fha5NM7ryhcWT2EbPNKGIGftoeeLn8GhAwwKpMI67atMxKFOkH9HyaTrISwC3J+JZ4F/sVeEA/cNNpPD2sEoPnBk7l4RZJsizhpbHv7kI/cJvXyLZcil/55A6lFNoO3S2POFGnojj/bfcdd+zCuXorHvdvmVIx9Dg6cxDYfvdXgfrWYmejZfla+JxYaQ99+nxuMeTXo2GozXxVoy0quv5HcfVL45XZONkU1+03Yd1SCKzLkUG4upaM29Ivy0dqSRDPlZLehI+q4nZsJMFFKHJSwHa9wHmJBA0lEoXqFxMaTxqPNFOWbGeKRuWBD7t/kagz+w7vmyN/PwTF7eJxLxfWcFnlLrj47Pow7FzjnR1abS8jAlcCS7ogtFyAJEyjZE2dP52ZSRoWFoOtPUlOhcIDYyoiNBWjPxo/DZHaqRZS228itecLGV6cNAKbvJGi4/LlQhsah3W1Jv0nBdhF1vsjrHcYW5gf2BpoifP3kS4o0mamX+qIN53Wr0fGx2fA+JywifEPsUjDkOTUAbg3bwmfZFYWTr//U69sQY8uKh8ZCx3DZY5xW9sx4swxEhZdjqRZAlyjFLrGo4olO00d4/pri8S+6N6XkJd1usUdTbfwU6lkKm2gUmVrnvCMsyY2hSK1cUZ/Cf/I+26ywz9Q4WtFwy0WS2560gYUWNVgam4Myqg0t2ASWMeJRH0jaPmGZ+RC38ibqEzgihimYueDsD3cO9jprcVuBD7j4yMPHEY75b2W3sY5758y0A5F55zBv0fXkOHL/XsGRC+8ZJQ40LT2hoHgrSMFgka6OWOYa80YIPWKrOi34ZCBpzOGnJrM2Jnl1ozBAZHiQotIkXvXsDjhFXMlrxUpUt2RYiyMFHeOECkaXxASrcECLgMracabowU916L20EBv9Zfggh49zG/fAbZA4PHvJ8m2IVUHjDsSVcfQIO9VStWhxts0zNcLeZ7PuoYO692xGSEH1aH/DH8JryPO/wUGi5/dZqRnv2E1xPIKi98hS8MhykcYzGFdbiXqEKyGiSZzhqAbapFjbhImjNXW6kATmLFSY/jCRXyd1DJ6mfkP0Mv/2Ar553WH/IV7v/jGxrHekF+YOnjVX7VC/nnQetflQjmP1I1v3BlkPAcsQ/rU7B4jueCSBqb0BevYyy8CNhDouLiIzEe4GBAMICjsPIVgELeq6p4mG3tLIl2blzQ1i9IPQI0GdKCJm6/kHPJ4s5jF3kbJarxaz7j6crmwhcBv+rOOqhNNE7GMbXAF10XREf6YxCo0FKmx9BI6k6yrWb2EfZgUMHuOiTsnmHBolzedwwruYQwt0JRErzsEbeCslyGsaDjYxTYniOK7boAMWffNUjpGKICZ+z33M1Dvxpy6GLFy0FSduQXmSn64FeQvNjfuWSbHt8TIRVqmgh8jtGbEwDu+MoUpF+snMJvSPuJa6HYRxCJSIsf6NcsB6lPQQvhl9R5FO1lJ+hPBKfKhY4ewXg50gaw4CtgkQHHMhxkbwqkoLCxW5pYsxUnk9+URL3nQoUxYOt1DJqXlhcVCMKWpxADdIFLatws49n8GWiQ0/lFxChzW2hPTawdPmVHd6YDT5vadtneGuw6iFGI+g5aC1Oyu44UTtlmz5y+a0ydmpi0uVUpTAC8xp6bHdawrJRS5gIUl9dFoD9p1kzImZVbzSdBuKI6mthZLCIZThKVenwMwUkcH4G/p8kYTGBkitAGI3QDhLwFdW6WEkG2AZFTYM2AFTzsGLfzK6hJb91mNHi+r5CgdSqW5CLRGkbth5C4SfxA05oLJM6/dS2bvNWXPUHTKMCD/tCdQXPfKVUdqrYD44LA+RxqqxAWMd+9LclAuo7weGHhYqjKz/8iBOdWd8sjsNddcOWXkKZCxZPsT3jrC92EwpAgAyLqqIty7N7ReWlsuWZxd0eiTHQLZR8wsuJxRXJqIUDHcs6aOTWXGA90A5k5SbMvSNax5JYSmcUjSRBmE45jIZNwoauOU2npp/cU9wBfGSlbEifm32JXYwIk5OB6hG4cV8xQfun1IBzPoouw+ReE1CR8I2YiY/Xha0TAfEOit2gyUdAHvsUqQUGbx/OaZ56rzB48eWFBLx+pAgZWT/mRg5Ix/x0PMQxpOwWKjInAi56kINvi34kaR86UCdDb4xlWKpqMtClJOq5gydcY3xlUz0yHZmHfW846e+UzyXyS8wNxVVJ8CN5kJUh2zJ9xpSXPMnv+zeWNuaQY8oXHMrsZqdRTDmmQkUTyLDeRqesp1TWYiyiQGbJhIocPsMPwQvVQ9dn7sUbH/S4fkO+jOzuZ8GIQixBj0mELEBuO/8Krc3+2YNxsjcF6QCyngy7VmXDRFB2K+Dj/vdO5tJ+7QL9+I0AIc8Uomm0oadGUKodfvBHZF0K6vAq6jxx4W+38M2rWfx6NEjO821yoSA9JpLfaQI2v5a+Uea7X6URHwktqk2yCrZDu5y3WA4qW/c0r6UAlPqHH/DgPaYCXaf9qBWWa/mesecN8pIxfaz5vwiNk0oBIakGVyIoU4odMz665/AuYJmubhLtxWUUreT/dDM66palhjQe4aXR12yYrTG4+A9d9xoowSXL2mVjDchaVFx8mDlELAybKBw0YhocFotHXZuGH07KOFztRjdaT7r4l9qq8qxMMevIve6iUOO7jIEZk9luigYNN7aLRTOcoC2hXt2tBIGoOKQ1UvcKdG7cMdON/2CEe3MdVaPe9eQGu0FtDSrDjEAtoULQ4RcGHUvGvvmdnTqg6/6oE7w2tGAJBk9UcAdB4VZXAMaHxrw1Pe+ERXZThg5cw8/g3uZ7yITeOn7+6msdAkbBOjEqEHu+0x8LYPcdXWBvEBtkG8vM0N4lfhnOBRSGqQsxgcW2Zw7HwIxybPxWTped07wocsf/Qd4bf2zJimNJqSY9sc4YHhrAl3jZbLpUCK5tjebCCc97ozf80ofF3MkL6HzTK6FPDKu2wpYBOAyCd2ahHguSMuAnDXbwT32G7fvfGUUFOpc/gfqSq1h/+P2xR6FqDv9p9Y9D2KpcBnwXTRZUc9XvTbHZNqs0oKsx7q6curEapZrLThFfhb0pnlzDG1pHaikwtPFkyLYouEK71iaDC6DLq0Srupf8ofyk+V2CPBalImn5Phet8jGRkNKzWQLWV5f6rqUVYataBZc0sLTgZ/ytsuos8S+Tble+FYY7uRn9wTPlrYKhkqINEcMVuzimBMImfimcuONathKYkYritARoL7Izo0U3u81b2rnlEs5jXDiieM3BkVXhcc2UnY7N4jkuswQiZmt1oKbRVqxvVr2onMvDExPWH6rZW9fDkfnujL09OeO449bF0tVsoGqaULuBCDsSm7NY7l2Tj2vXfDcSzZDNV3dxq3UragnUKGbnee2ji+yVnkYovIds4CVuaRsU8zy7N7ZhrXmBQql3VcNTRLWVyjfrDW5CYIWaanSZ6jLRL64eivpAgxKjKYaHg54cNAmdMkJ/qknYbPfEdXOdPw54NJXC22XauVEgm25KigpQvGJ/mnGuUkQ0tUAdSfbiPw2eB/LIA/E/fDnCOLzTUaWQWgmh4jKpNwCwQ5Tio58XJ5gZfitlVChknS2wLVKIVSDjwDNCTIoKYYr+c48i1CBaEMI/o8gDNknWL+veLlyQm29Ccq4IizRNranDhAxgyPxOMsVuF1Th0Gq6mMDqtZa8FqFo5/i7+GF2L3jD2F6ruQkIcEe9rRADvCrEXqYahgOhyhSntXkDNf7XASKfIoL3IAFgBosMhxEZFsdMEeCOnZmEB1c3S5RoaBMZpfxhbGQ/GyEJDx9aYTvMaujZVUlld2uACJe1bT+lwu4ILVq4+VpsnloJ/IUPvTFqcAltjbkBwbwlvtkil+Ymo8jOZpwTDDaM5n6s2LtznPvDKeAkk9eN55UV8spZBPihq6ayBRU3UGvRACM1lUJIbCeQtUIbIgTZMMVa1WM+R7xEjirtAYnxm6BjYaB26O7KGGjAtyyZBMwZQyEBfBX5OvjQV7eTtp8ViDal/Eruew+aZiJMY9yl/2MeIXizLzSltTy6ovkstB9aaDa4MHzQeINc+NjxugMOAoLgBqILD+OEBVlzLrP4GC53bF+iMhq7Zs98/tuN3/MArUamErZn/rtszeWKoGj+tEW2HvshNtxX2QZMeq3QZ/fLfBnzTA4J+LDP7M2Ed2yeCDBMA6GWn6NcDuDuZ/Sq/8V8kKYbNqWskczHdiZ+9FsbP5fdXvnURnuLNX7CuthsBZ2ZX9mS61r8M53TF8uUDeB3hOrdtBHtbtIDcNcJDPRw7yqtg/75KDkG3uVt0NvKVxfGcWq7jESfShK3ZojYp7ypavmjgc63vMsRxQBr+aXjYDWNB23tVqW/WVPq34y/pE5P58x72JuFvwgkf0Cs39Za983IPkdDpF3URHj6UYDHATSXKzZDFyk2zoJsXITX7Rb9wj3cZd6zbu+pf7xN6XoImhYznzkQyqnSdDyoUK6vpqjhMXQpOhg83sGbTYF1BO8E1/GKkyIU0cKPYtvTYJRAsGypQwOnGg7wRJrppYAlF/SvUUOpEQQI57kYw+IRqQnOgmpUoly5lmwYxDM44zdHfWzYMNykETZqySTyjIv3leRhMagE3pQyqaopCjUAD41GjHkst4X+aupIBQvQkIBUtaGw+KEo4CQn0GCOXU1AzL/6n+BRh/TeT/zmTZTxsuLQBgnLiSL2RRT6CY0NR6DVCQ24mJ9riht4oJSCAkURm4xfXfNwGhf2gADmqHaNCzIjSoOjG35D/9S514UIT/2vFbud9jxf6eaLJ9ZvPwv3RC5cD2kXusoujs1tXZfhQrJtrtOvKq5kl9zMCT+p3ug6qOX0AP6lzvQX0XO6hPowf1oyeOzFvsSi/5IcCed2JQmds8wte6I3w+OrqnbR9r10gHT8MGTw/Yh2u1+1gP4XbudwDTnU0lIrrAdPu4zdB09YFwOukkNCIWOzoR3A3GTAfYTs7kMnIX3K5gCSHcQg2kJt7ume12w9GB7YbvD2g3/Ia1G/b1tBsu6m432Hvsjn7DGfTtdL8YYvHwLSHttIZC8cAu2IXFK5TywOK9Y4ttB3eyr+0AapvOtgNrFdxGeRrRN3wxjQ07Qjo3PLqA873L2F3RpSuytAKL0OZtAEtZq2XclD0Pu8Qduuc+98VWJ3FvfyfxzY1zh3cSP9DsJM7990bpgEGFzpQB6cDTulIBsZUJTLMIYzhU79yuqm21c7gLD3KElti5sEXWueeiy52mkQWd6Eo5TW6FUrotUHZFxuucsGVVcrI4NRgdYbdHpCPbtE55GCMIr0p1zZ+E+jM7TNb8wKOQ5y0c/y4ldWV53suggHRy8ry1LcD2+lK86/tSvAfteIr36lHBefHe9K5PHfjB26oC9gzR/Y2Exbswd42X92R2fGwSKsAKxuX3gTThO5DbdYfdjXO5LQZ3ZwsKwyv2xgrDb3xoR3b3yCixm5gqI7FzW4ndmDuemcwMSuvePSCt+/SfOjSF612awnQfoUNTeCbSFM50agqD4ZqQT7czPaeWT1b78rwwgEep3m1DU73G75h6cJ1u3n2jXz248shO9WB87YFzX90rH3zfDvlg2HkWds6iXPsr8PN9Bdd8N23HCtOKHHf7c7vtJoxRH2ClzboDdNQoFCD8AdKcETUzxiZ+E4zGB+Kr3CPpBSfD10OeJN+e0HEGuhM8YTsZo5oggmkJVQvHTi0ULQhN8OTvR2IDeTT4e1AjZBMiCx3YYZAt8EzGTUTx11BWJXSeQj6PW4jsSljFbGd98S3ljCK2eVU6uH8gyw7jTpgcrj97YwqQG1Q/YUMvjEPaWBYaT2RxIs4n4gkxd7RIJg8cOzCF6D+LhrLJ3OYfY99B1nBXOw6Wc2ZJpalCjnXDVg6Arw7KK1E+4HpihNKqOJv5EQmVM/C3mHViwBlt51F1l1Xa6IQMzRS5i5zNUg7f89p7HpLdPaBVhislDMmW7WqcS2jkJdCjNaZUiPEJBGljtlBIDne6xl8pnqUSjA1zRwp8eX51vswLBupOUXIS3MJZl5y5QL7e5Zc37ZJfHqFnRdSVLCTQzsnPc0ZapJ8FgTscnUIS3O2gxU5rs/eaNRyk2nHu492e+o4eTy0v7l2srP8T8jxFFezmmBUPBCvXeF1W39wBnJiM/cyPR/rmbF1nQBkzssL5ASrucXJLnEeCRluRcN80seM5AGcl2k26Z6dceRarD+TSTrnyXEF/xskpdbjnsIpGErsh5ihpgDGvz0wPUB93zt4zQH08M9VQt1jxpGcHVDxjfRXP5/kxyJ3dE5uBP9yt8dhdqxa+8/PTO3aKBwntlW2JhN9V3fJePfDPb1MPnIR64NwvaDO1tplu92IwPqxjWm4HkZZ0WTkP96RrqsMjjLtcp0k9Ewaguz3YM8YvrUAVfW4dTblV1P7+KnjGN5Lznr96kRxLWnXmbXynr72URRWgXuBxAl1D5XN+455ycXImWDnUt7JxYOFpOuu4wX5S0Y0L4yv7V+riPNSKWXTh0/EcDWHqnipJTY5TjZIXDdP4JuRhLGpU0QwlCtbVze6oIYEMyfaKC0o7aOgsaLiQvZuHZ3KtsMEll3FP4gWZUjhdHP8K4IQKdMLfH1ETD8cAdgSWluFafZCQZpQ1TvYJC0s9QaVaDsTVoM9Ai53lF3QO3a0AybnXbiDjfaptjlULCSAo8URooZQAiutDKJGghiyKrEbKeo3LErP7Di6Xr0Z/PZPwFSOMF4HeeCj9KrFoC6DS2r9cF+ZkwQbDMFAbqMVM3Z1zJ+XlLFMJHwlgTh48FD64SBuxcj7nkX8EGQsKOoV9d3GJSoOoouWN054H4hlEPTQxjYqNwRIRJIjkp1xo6xINqjAv2BRiTo39GRg7G3t+7J8GGDtSfh7J2n7Eui8EsHbfFTKatSMwqbMdCEG/D6hajxMUO51A08lHsEQHJ0jEeeoCbuM6Aic4tFwmoRcELS8wGg9uecE4vGA89IJS2wvm3UllGbGSuoGzPZjBzdQ/kgmv6R9Q6jCyoYMsA0SlyDTBfD3gqToYH0IHgUw0lu9ckqX7mIAa0M0pVfQSHQ4iwgdQbBPanms8bQvAA7rR/M9Yi3WxEvux2O1NZd2RYkNUw/R1SDcNDIubxAV+6+XSeG/ls9Auj7hXwncAKYic5xd+GECmqe9U04fhO5UogFBeIRo/PhDGD0YdhBZL4/LE7N5DS+Wr+sLHw5qOI5912VnyoOCxlCXZUw/vO6YcuvQ+lxwcWBE9GwlBd0VUa9U4ZP4eF58xFxZBSZ08AzwD4FZXAkFi7qObvp4L1zTnQ++BgPNbuZLc4TtiQjTdWtN1tDjtJQsUbBTFlsh1sMlBGud1VTlz7Sonjawjk0w3q5zLoyrnio6SJSplONIKQC5umw/fbW4bgULgi6SHNp+pVPG920B3kyun8SGnWgiEa2uHqxqw5wm6E/R5zbMML+HumR43O7eBjo7b0+TPd/v2eTla8Wr8cGZPLhHYRo4x50sqQC6yXsinpdb+j5/Iz+T0IIQZRq7wOrrmfTdxhk2ZDe4mHjAK38HuW73xm83oDuiR/yfAcn8LcMXrmyUqW5wQRjWpj1b9Yp9Vm+l/ngw0rrTatOFoOHjuleEjnnEnlNkDpx+Yky2zivCvsBEnz+K/htTBlqkphbDH7jauTszsPbhYvhKmTEOGIjKlr9+wf/7Jelqj5izAnLXlvcs1YRb02HRPI25VC87oKPnXsGUPVB5o0SfKpRT3M4zGIPKmhiaD+ByW7UGcsRYm/1JBlzAeQ+xPBjh1LPEn8X/EAnbKi0DygeN2guRPaYHkwwgNKHwC0zHKfbnZwRndigMPJt/M5feTEXWI6fcSJoBIsfhB9cH3Nz1DFDq4f0bZ5lm9qp3cf2UUZeKb6SsOKxWwLz/giG3ljDZmm3m+CtDSRvrDrkpoqaAKgot426oWko4VD3fuQxFYIfbA2DM6tq7rUWswbNUsd5ib1e59BgeeprczKLqddftyqzPItnJ3SAmWw6oSZ+nBvH+P7FyuVcfjHChJg+lukjIr4VHRs+QkFzR+TQhrDt4U1fDUyrSGfw6ag0baoNWzIX7RKpnSz7etBPtZGat0EEKiPSFOYbNu7hsEsBk65GPdAh7DOVnGkU5mExAnDheu5KIhoP2DUw2WfcCxwh7Q/CYSsG8fJgH7oqYE7CuYBOwUIP8670Pu/i8wFP/SJq3ELa4+0CHrCLj/WlttGtIl42FfO/IAG+ZfbWHQpSo1OTN+U1KUfpeV8U6aDk5tdg7fPXDvIRV2h+kUknUO84eupZ3Dl3d2DX9J9x4+QZuG3+igCPj5MIqAGzheqqMzqCQY0AqRWfU1O838rPErdxoukU3W3Xg6YyGSe1oxD8wel54O0P1GX5mHA1HZRupBXFbElQXiJwEb1Nm0Q95AoMLAJxS2DsGjTYf4YHqQVsG/ScQoTOW1uMuWKoAw37cRl8AtogQdJuYzuFzuC5dvT1Zn/MbnMnPPgr6S4mmA4DJ0SWpCl3jJ1pKVFv0KsLu6St2K3RixFOLKT2OPi71i8AW/jT7fRk0+OsKPkFvDiTkw6npva1qgzB8649C8MrC593d9zb2637hULk3OpdZO62julYPHHFx+dndnb3L10OqE6KYsTWatvfV/7CDvmOkk7xg754xD5P5KNpcOlySjll6ifxAAfS3a0ltqt/TcdNjPm+zq5zXeM4TKI+S1uY3SIuMyfwHVYN3t65zsGLvHl0/SJU5+vGPcH9y2b/CVDSlA1I0pQKixv8b9CgXVQ2Mfit1xEnK38EJo3cZNhRlq+wot45jJ6aWwT1jaxzfvcvpp9FiikdtE39zNfOJvwBAgSqmMy5PPe3XXdgjn2dYkZXe7RXRdG2EDTz2OzTxPJXxxdnm+JvH16TqfnkDPjkNzr+YLQbGavKrxVdzj0LzD1Odsq15CYN/jCpKw/iNiehhA6VrOoC5UtJcevPfQs4+AEGi7LnSR4VpmIqGCSUPyk3ZKoKFC4nXkRByNGNi70TKuK4bYXU6AGM91RMESra3ReQMKCRcYELPHr77K23wOfHVvom3j7bHVdftW2D/m93ODSvaljZqCw5yXb7nLUidpDUNzNznOVn3uXdtr1v6DYnV5U7LxECwJj88EN4b+5LX8SRvUCiy0vXaWeu2+I/uY11a6vVY7ZJWTaw86ePRZZwrehGtajj3jrX/I9lPoWRp6Hnu1W6Ew/S3NHKQ4tvgSohF2jUEuELCuMYTLhY6mscc6f+gbSrTh91rWdcbGAtf468gtiChkdc/ErBI+I/jQTVRpX4Hx1XwZV44LFtPnoHj45ugsptRouxOphJ3jrjl/BF7TJ+CgCnsOnnFwzy7eWx8ehdOm2E94KnbwneLVJro4bdQBlDbnScKQgPS2wQGp0hmQ3rYxo81nNmO0WQTe4+dgtBmnuWVtNNaZ3aEN4OrVobssP92Ylaaxvtm+ymAmgImk553eM1a+CiWpCDyAOHBjZbWfr+Y+vXw1v1GSF+7GMooK6oarkWsehWwK1qoJI0+g683L6JwWGK6WSl5MYQ4T1mt1VHh1SnpSX6szso2IJIU+VF8MdpaNoYb+Lg/jLdnzy3Q3CrRHeE2uHpeTexyOJH3QJKR4zsqUnfRiqn5OPbOU0cpFn+NTY5NUPo2YhXwKSyN+sJq68JUXunOGQb6yHeqF9d/SLOIK2oK4mDZeuBsRCFCmp+TGPenfxO1COlBC1Ifm2UGQIJwzliSX8ZWA4FIKpmjGj+2O5XcMFTKtjMy4sDdkXDgfWx6N1/FJmTzBzWTQ6MSprSGq17A3eRXUTc+L3YQ27hcpwVG9bbB9BHoBbB53gF8Il8+w7M669/iE1cVo0doPXYL3aDxmcEe4xA4Lm9ZWgeyJFBIr1NnwjkazhYQ9/EX28xC50d0jCzwWbBBqpDjt52Kfz0nRxZsk7ni7aDs19xYjqwM9JRrJaZeFqFSAm11FvpTRPr6TyqeNM9iX450kkLzERV5mFkToBqEVnAx79/fWXGMC2umEpp0ruGqo6iS+KWzAewlTEMJuoiAFZlFBsqfPLs7DFUFjNWuCtY40nrFj2qjoG4mHwOnMxqD07rMk8PNeJupC5OA8c5hv8tdiSfGM2AtBZv+DPjgOg8AMQeTUm4Ac+hed2SO/U05XQ0hhO7MrXfKp3b4kCSP6Evcp1NwUptPKJulAXtHnfA+5N3lX4ygOVxo5JSjNoLETwnQUm6ZYIPzBnC6jNWqXbtchyZFC0QahcKesKumSX20c2szLZtHTHqNxCtmkPWkoaoHCdqZD2I4btFE75zPUzhzZuz2v/MuLMuOSBpKI6ba2qlJJXNQlwipsxd/uiSW0L8f+C/62yMicoiqF7kYv16O00We+sRY6BHUP+kmwLCCboMik909nSVunHmuy8eTi0hY8EH1S/uR5oFcD73CupDUu8cZT8DuBMnTF1ewMyJrin1l+8Io2NlaUcFvklnONl+JaV/i4LVlp8ETkSUrNAY6REG01s+I1noqUA8MDuKf8ik2dUk1p2PnfZbfc42aweUhtX03iXnZqjl0xCswrVd2uMtohLCim2E4CZp4TqkQXGbgSC8v77x4+ykMR+IcAHyRi58SeBIji8AyJYyPLZorE1rh7kqSQAzyskDoh5fYokPJaXcR9ihkgy4YAcaXuhRmWYheS2Bq1Tc73ec4I8slg1k+mU2k7NQcPwYSBs/NlwPyIEXh0odT1Jv2xUw+eWrMhey8RmZwyIo58/V/COMLLFE4uco8OM59AblwQZj75VBByfccxNgmQBXFKbXJMIRgY+sh9zGA8zH1Q5nrr/9KEkf9PowNHfkEnjvyZXbrCBuqLRMFoPJbHZf00J4NdFolDDMkgg10AuPxM7Md9NvZLWKjz/NKJY+sEk4gUKrJG0BcHwjBAqZGXdkAJdquUNTz97PHhwSNHOoIHeZKW1lwREqvYIqHFl20hkVTNCa/xa8X3k9hyhsKQLGbpZrKUFG0fhwWgr7Qq1SfHJPLQEwedG1sktRGtZFLBAPN/WBYtopEBXQCUvMxZ4nEJrx0XcKK57wIk6kfneW55ITzPU6aHBgiwjGM0GmDwvbczGPiOKbBGSuPmHYCp37pFPhxgbVDxuvJXEUiO9AWSK7oDCVWojGFn9yh4Xl85QDAWfYvR5GKXKQqE32alJgwurR63VcHYew2pxY5uXIu9OKzFGp+joeMi+oTOZgygy32aselqZjTFWG/FEzRy9ETrsfsPLaJu4/4H8f88ENTfQlupO1ZEBTuuGSvsWB1lFex3b5Af3DGqpuztoyKUGx/etJi6pDMlOGvzlGB532pnSvDAbYvOfqUTx3xRGYf+4r5D/5DeDLdJb/BC0ID/fCcIDnYum90qs8GoZXoHA8K+fgaENzXOG86A8P5mu37+gTuQxZ4/Ku9BfPNafovMCCvby1/LbXaER2/IjnB9apRCSwbwOg+A/WLsEvBkvRtu2AFzPxjdFwygutYNivdDVHwwGAAfNW/FHUqKpUE5LncDLwtuE/a+R6HwWwqPDxJjbXi87UGNhns19hts3XSwZ4M1H8ewU2Evl2+8d/t58m+7st/LO7Hvv4KRHTM5oVKr/nsHUt4yIqj8ZwZj4vcEQoiZ5+7TSqYvGZpMj41XByfTXpQaP4Gmxk9upsYCUuNbGW76TFBmvSr2ydjPdiw5HokpqTYIpR3dXz2Q6rXN8NHCSUqLXzESodJ3+nHYaO3jlutBTs9ugIV+3K5mw/ImjEs/74NZJ/K49uJ9UOn4CMDn20ZLf8G0z+q051Cl7S3rYpM50i+LLe1OFvxXQxSyz+pUyF61ybEOhezFzJU7mgpzzxiqlD0OpbVepWxzb7lfJ/uQtrPZMM9GClk+Bp6WD4Xg5cEgYbHVxdtepjwfDMYaH+BaeTA/37W+RNOWlTZtP++FYwl+1NTld/3w4HIRtWOcZRSNz51w5gx4sTsEXkwxyQxdzLdmEOu/n8T4jhvDp4f0/zQKLZJLNstSuB9JuXyKa9zSgwvGYJEXaWJxgjk0pxosJT6tF1IcR9CJR6Di9fu1d6GeLSa9pMgCkJPK0slFlk4uyMNHz5oTTNntG7HGSc6a4Yvc8Kx5bZu67ieQRJ+4IMFVo7jrhjn0J7ch/L55TXdyk+raCUvDXzDaNIOSlNHY+AbAsv9tSHSkvuLvSHzEn0chY9gIG0WJysiJh0ajkEP0ksTtxMaAxkZuJPKF9Sf2cqpxXi+xWePjI4TIQdQJ+BI1LZ9oiBQkugSyKe3C+hN7eNcWu7nQyP03D490dzsL5oafQC/+eaNxN6xUuuqwOgMGDK7CGNkZy6nypCunmiZNKgbI37CVmqWVzqQJxIebUzQ4qUR2JatXSgHHp2tTJsuFSvm0rAVBcEp68jFPfMykuwBolKLEZWcGvVcncLl0GtpymaqLNOoKkpqamALrQuNpuDQ/QR/IRxhW6sXDWRie3pPuXMTv6cp2ZD/lSWGiVJH/vitPegZ9A/J0mPNK5EKPDQp5lgrFbddjO5bf5n7N/T72YDR3XrkpGLJtAUKZBVuPn6ldho8fVwx7+C7dh+95+ltjWSCwCXY0N2ZbmMgezurFnBvZguc6TXHjX9xITQF1GGoIypLTbYlztkCj8IiPxQECO7pfIs8NwY1+C9zoNsGNM6GNfOw3OafYzD4ocYlgWQsGMw7J2U6a7jjFzcg6CMzkTZsRKJBXx6ULmLH+k7uT+w3kif4ldhu6uNWmQux4KJ9G42szxoaAFXEcwRDyIoFHDxg7ZFIEXsJ0nR6QKCwvNb9KbE13WCksAt1CVxajl19lmKklmi+wt6YOUo/C9D5azWCnOugCWEjMpuNs1yYSEoZycHMKBY9AAU9reJxK6kRrDgXbeUuvLmJTAZUn9v6wQ+yrGeNmDIz/NeFrKdiTkzjXV/GcS2icqIB8JjiQcGMP0JJv48gBq2wdMlKgKFAtKCejQuXxdygq8GLr3/dTqWRKkdFvV+bxX0W2E5OvECxJMURdT/CaADJDrCInURShGYL9SggroTGD5o0u4jJd/w42ugR0R7CJa8UlTlNoNUXb/BR4ngUEWf/Qx+GHX+CewNHtTBTPfhJCgtTqtpFOYfYMJBVnooU3SRs7OIsVFXw64D+EoyjYoUVXT9YcKDnjfhLiVMiI58EUpBsqbRBx+wG8YtpKFrapmPY0Wklaw6SbgOBBl4RJbPNhB8sIrsC6jS1R8SXsfssCHgCG63F0gtlUgstxgnAm9aoYFnK4H0PX/ZWx94SzgbYuM9Wy9VaYJk21U4+YtIF3XrSsiBPv0VWFaF5IPUigZg2om4X/Uf+h4t0tD/GWIgHcJtISob/lcavUH1bXaARaDnWuDhPIiC6v4J7HXi4FEeI9qazZ0islrB6WkG3ZiZxBdBPTM1LAMiKesimUgZwjP0e/W3MlBZenVHP2EK6gutDYlgSUyapkKo0bcD0ZCsoEAsGgkqqU0oohgfsVH+ZLl5QkS9JpU8xAXlUpHiqlLQ+dkGRKKNrAx+DhC7qgSj8DuAc35/9zmXqgTBYQ0RUlq9qaxHYFxlW/sjoNgkpByetjcAtqNVlSfB2mSZqiJf0DLm1oOFZUiHcSl8drGkod+650C+GYPwlz43s0lMtkThGNeYuTGbeO5mW1JHQLqbA0jE2bd3TO+XQJnZgXYv3VUoPCZA4wLomFkW8AGP2T2FlATj0fBscNuLyytZu0OhXvvI756GspJiPCP9MlWBphQrtGXTCQWiNvIxWn5+pFixEURJ2h+7FPfuzGt6g+s7p/dUbvvIrTwaQO8HKIfipbtZJfmVu0xt26W6cGMkOoM1PUzM1MzTyVj99Gg/03WVeJfJlMra6oQy5VT37UkOYDeh6qa49TpCPS8bQfIp1zh1IU50wioHNyGoA7cgXu36t12wlbERUjgjiUuV/F7o1+EvRz19qwZByztQiXPEgBPDoukjsCMJls6Zru7nize74W3cRPad+HX4c3N7HH/TrgDHx83yXCvWwj7HHjP7ZyWbv3OPeY03PbkyPNW/nq5l0JDOuZEQpZdLq0wEshDPlsQd4IhsyVBt3bLi6ZrnubdFz1eTsuLYe5FBDsauwRIAD+4NbwKvRjVPcd+xR47hvKvuMFUZJ3gVv47Rm4aV7uA1sCpxjl2YOTXIB/Hm7Relkapgi/4FJBeO7lLRQLv02zH2oafXFTEIqRtULgKADYOugRWF4NaKungSJUZoqjeaONVLluq7Y/jVqeYk/uwDH+E67Qv8EV+tF+7Ml+MsphXhoIUNnu6XVGgJc0c+37dcJM3jPCCX95HxJl/fd64fztHmy5CSDZ2w0g+WkLQEL2Nb0g2Q0lObDh6d83AGnymq2f+PWfbQgg4apNv/gxC++ngzP1GRRJ4uxUKKYtkcNkBJ9Cm6XdNSG0OUJZqCJOmQ/sXABuXDJ55rV7R/CY1auP1odTx3CPO7Hw25ivLQLvNLuh8Wc4Lb80MbcCPe/cypxloV6wcCfB3y2WBxeRFn0PadGDYo9vb0n2ZT7cFhoRGwDEnQEtCNHlPjo43XHPuvBsZ8O+w03/56YoY1p/XQcKvNqJAj/zmbTl8AF6Bb+XZj1/3pytvH3oaGUWvYZKX69h/ZYh4G+OHEen4QHIdJ7StYLkHv8FLEBPwkMRI//vDpyEncN8j0dn6pbtngZO3ylQ9y3NY3Ui52H9DxviuSc2hMb9OsxlDODf/gD829HY9eAs3zaoyhlRtz2UfO+aZeJMTG4LLPWhTUBydEuUoaEuo0eiDYa6fKNx46V948b1946GgSPfpXPJ19O55OO7joh5/Gfcv3ON2BVQnH0tpdh2wob7SjSlQUl8UKqgqGJ9F8ZACNQqbrR2ykCpT8QgH3KfdFLVgHKKgZ6jvgwuhLAnQ+tq2llvZR4BLdOBZgYRCo5MXcSXeaKb5/CyDLuAJFUI8fZNLE00KwoY/SGlu7rCzPjU39HTcKkirBAXbAi26Xi6UnFszLjgLYlMNkDvgsP+gZtAwuYFIkTUVCw6QdBNFiUwX5tiioDvRqb9D0H3zUYwEXgJORmAkBAbrApm2gwOPJs76wJgRD0ZM36Q/nHxck6kVca70JfTdcdEOUB7AYi26A3lGfLwIHZxREtFHxyi5nE5nr6vj14eKNaFuOL4gLyaOjaI0czx0egRhSktbVyIulvkJEtTXZk2BDjyPRAZCqjAs76hmt77VEvUaS4gYdoCzjlx8hScqB/DIeh3iQ2KtGZflsgnOCGo2C9yioqMtpWUP694c2ZpukC9k/eTq/XKuWcfhSNQHfJfMx3yvwGS+baTPzrcCMC0iQb5yMCR95+s0eBGO6Dkwo1EyhvH7l6zP29jFfNbRxnwuYAaHOarsRTu4dcAIIeOP99a5I/41nlhAwis6G8dAsuugPDKALET/II2GKMLm7YvqBLSSmuTihIoLPGHmi0MFthYcOKJu3r2bJJPu/4FV15eyPjY/Yk7rjqxuJf8chgidjRMbOMDLrA78URianYcu1SYdpnyo5f2xOOOQWNIPG3UGe+O4hXBMaminSEX5Cf4JRekWEnTqI+XJAcvkwQs2rE5i5s/977XXjM2PikC73ywVjvj9CNlJ+8oZw8BzKaPZEaEy54WwmV/AiTDuK4xS3OZXD6p0f5gHIwRaDLnaQZsrflk/f18fmLWtacnq6oiyI41efG0P6fzlKMnHktTaC0/C4j7BWgEPhuuEDJb8fRqQbMXvzS7tXlqKY+yIgH8dKK42YGwWYGS5M5yYU1C/jhVr1x08bn7x1JeMl2ppJ9SSaUqz6a/07x041ejIF8zhC5OWg6YrnSKfFXL2BMVGfYrlQniXhKtfEiJNtZKc/k9y3vyfmWK3Dl3aT7tisXlM/dMnJou+kGx5IK3FhKhfjF96voXNkGwfv+vOxGsj2e7Zwythd2zGzoBrNPiTL0w4RF3spit+yJD/nyJP5+fA1r1Yei+v3Nn0KpkJIhfzZWYwkIzI2aclLTvvp9mHPh0HGg6RWJGx/dE+wb4jGolrCzZS3JfaQFQ9w8AoL6iceVQAOpbmgDUA+R/NgXq/cizFg8eLc5f5FkJ0VJACaaYpu1fH59drPM3pgzLsnzAgCTtI+64bGTymLnbqomkQkoaVqW6VXDph0dB3pX3TJRqDqY1S1Ol6XrWzEK2wXB9Uy/kcvHJSd3yHNNQs2b+gVzSzS+ZSBxw6vO5lIgFCwGn7wf8NTh9NaAynhB7LtUMG42wZLRTGnSfwC4/YFdxN9yTnUJSCY8hP0LD6JFdfCTfHNgFIo/f6Dj/EvYWVcOxVbp/2mX8XvPPts/qmZs2hhxOLrJ20GKLWaTm2jOzM61+jzF3Xj7tC4Wleww67mc8AN++JmNamLR1cknbA3Caz1AESjfT4QUrKGhwpOmJrrrxxqcFpdUWUvp5RajZv8bMPo6W//Nw5D85atg9EcWmE/CBKBLzo2g5bRyuH7clyaUHnZA3xDcQYyKLTIxpk9j+/g5+8XPzC0NVlK5sqiiRqzrd4+xN3ONAd8RvfHmovBJ1jdsj19iP2+BJdDQ34o3cKyS5JbvzvUTTZAtX8nV920zPGtmQz+nbe/pAx538u7mL8mlPLCwf2zNxsNduBxuXzewv60px/9Li/pKilPaTZ1/SaZdzu+xyQZ9dGrfYDqp6CBVCeZAnSN5OE6dalqp5Au7mwvHvY19Mjh0EH+3LYj+hwINIfYJGYhA6V8cjvSt6C/OLMExTguAQiVJh5MrIgvdzUpROd45xmt0QEulfsC91VlvIlYOkCbhtSxzhS0KNpOgnXcYQwtwalzdNFqi6txdd7GizHORYZdfG/aKhyS2FhT/+1xrEI2WHwcmDqMCQzLQdcWkbaunDbk5GXLWgCmEWsiqPKKbJkoOkmM5XeK7kuFd6VSw24ErFtoRIlw3TTnViYrKeclNUJBUbDslr72EhP8I2A6NsonsR4CgVdbpSxsBpUIPlUOrj5KKKk+JI5WhJnCkVAeIkp9ENBzuwkh7yWrQMTN0BcxE8iq7ycjwkkjQbLke7PHRj/N2Y62XSghKnXR9eFmVApCz6vQnYlrTQZsAmKPozsoR3lJS4Ij6fAza84FaW03Pp9LyfmsR1rbpx3tKquUNjuEnsAkiO7GMXNS7jdWyLoNOgeYlxZCwJF/8CkV4qPFM2sKfqwVSQCLSEQ5GF3CyGS35WcFM2Ip/8H/+pp0CKa0pxqZjUUxp3mqAUTBt0m7RglcCe52n4jLlX/qAsAzuqYv8UvN2UrxXMW4mk3AKKm7F67OFY0HxXM0BEDjQ8QgjtBU5EgxXWKOoCtvSAw0XaBQqi0j7ChvMnAgWv0ViCNxVZLPlgrTzz8IWFI0lbDsrl4GGlICjfSH8ng+vw9DZCGzSAqkepkzeAd2eNTnT3C04Qz924M1ddyBcWrWyF/GLqrHRFdt1L95XXvLzvF9BkTDvlgu/nvbU3t3DWgIzgra9qQ7X7WWvi8r0Q7K7RupDawgkCs98klirjkKGemEoVrThzgtv5WeYEfwZu1U+P7AQ7Iai2A35ERnaJz+6YYFpsO77VSIzoIw1rh5TRyMq2ve033V5Ds4vvtrKLR2EYefMJZxdd2UPVW2qyIOL3w/OOPm3pbWYZXZlEcA79HVp5C3l/ePpx04b5xsZ5YuPePUvP3BVd+cTBFkeVPjA9TMjgWVz/WM+m9GpfPyB7/HbuTr4eOxK7JvaS2NsHUSxshWGhhv6MH40cmw1idvi30pFDVOhqydXDWBC25Lgb+tgWWAE0nG2h8ebZM2bTvIBuzGXz0xfm0cYD1jGetGkf75attOGAdCBdfTgrnVlJtPtwpNrHxLC0nJnpJmJ462AihjEQMfyGqx04f+rQ/5mdwkEqFNHIm75wPLeWo528Vw9uwGFjvtmAk1OZrNrVgsPGgOf3tOAoMcNsbCp2GYY+L4mOJMe46DeuBneedyE8j9V6eEbpiczsO3Qwl1sYcwcdyhftPH3Cm0pzdnYs6Yzl7OaJdFxB0dSx2b3lycP9h/LrI9Ah/GYLsu6n4zz6lUAjql9NsRNJ4+YdgH7SPs2FsSey9Z6t9GlGMGVw4kYapVFz4yiNmsdtYuw/P0EbHtu0W5PctFujb+YGB7dj4caXN+7Y0DP6Y95hZ/RamP/1WzijJ5Iwr+3ikb3XCSbJj9q9E/zGE0yKv7mtU01r+x/wGPTHzsYY7PWxW5sqg3jOuOvspgRISBzhdfNMtAw4qHyvhYNOaTDXRG2jBgLZoIHAb7krQGLNqpycSyTTRNlbsgEfABFFKiSiEMgZdL9hcL3OXYCaNoGVSavFRWEwyRnS2KhFcGZ/gyCzpcqfqzWLcfjZrJbP+WgAFEIGiqmHMsKKOCWsyMo3EzNnDK/Vrz73ZkpK4XWQVtyrTVqxmN5qk2D9C1us/Vmh9m3ul0jmsmAseXjsfWzWusvp2Iaq7Gv9lAT9muwA8XCrJHPScrTLhsmxc+T0TqqCBZuc3kFVMIcb39rd/Iwb61Jh//tOFXZ7NdfLXtCnwE7vrqmpCrtCaMVOr5Ab0bT59OhXCOks2cn2NNAjNxhZAH2Ll0vjv7uqdXuqeGK1Ovk9ILqy5ZtWQdqqsnnjtK3eP/Guij2YBvjHCaJ6PfrDKErm7wnhuO8XXcz8zK3JmDdeOzDrpDhs6jGHYk9GYfDGLfhMb70+hN9iBB8YVrSP7hQ39lXuz96Wdv3D+mr4t2zV5H2V/Ku3J0O//sQBVX2vPX3kGwTkVcewW/ya2NcZejO8q5cGklV15xxV8W6fb9RWqKo2IL1/QN6h+YmbmsRWBoQo5DDxMDCZYAxYDwJF0KCk49K+pANynhnsaTbut5tJB0lcRj+Rph5qyv7aIPKrR3ZyZc3r1pCs4yHnvKE36+ikylJ3Pet4zIOdKmU9Ygj7DJ/i52OXY4M3hi3rYKU3coRxojN2YCOkGlCIdoCR8oagfLJKUw8aVOjU8BD3rOlrZmvnHZ7IBBnavf2kaBVSKSiQfimoVII9uWI8PnnksjmSm5uZySQr1gYoe/LRuD+9v5Tbv1iFwNzsqeXs2lwF6MCHCJnF8/dNn5amAWYy4WFeYnqJSfqn7Hmrc2cvpq+jDQhuGIi+Ul0q21RduparL+QSYrKINWcbKdpv+XHAM/4SOxibwd/ZMj/bbV4Kojs4T1p03j7bitsixr1P5ffvNgC7r97rUDnp1rj4TPGrhKSsZCVjvc+erGU4bjxj1U6/Zt8WAO0fLC0dKZdPXSwUFk8tl48slciTh6r2LgEmNTdWTnHJoJIihawtiJwemCWU88lkMY1JXW0+rwNtlSCv2hTMfpEBMiBc8UC5IuoLJsxgHf8pzLAAjrc3UI0HZoYOMDoWl6vNlXK2jABThDcWthAilnX6NAOWwC6x5VUYBujhxeZ4k71SGxdDf1LrQLcHliqScNsVN2S4Fk25mUL8cRCuwgZ+jqNrFkAJOKvN9KpZB4bvwXbdV8EtwTyD+ztM/NCsR9qMtT1fTaz/cs6b4DnHRsdePXBkTcotetMHsokcRSHGFQPrnugg219D2olDbhtgWnuH4iZcV7agFM/puIwAJHcV5J7ldAonUxibX5uvAClOtyvoIr+qces/qGYCqsKuB6A3EzSg02FKDoXx9NFL9zwNSCUrpeWs0w5bOYwapWRSyuha1jCKoJa07Kym57Ff+wC6964h4KQkmJnHdZf17TrbTl1BwJSqy0fH8SmCA346eoEXp8CsDYEvwzDL9ABiQdpUrAJg88SYtut5PSkrKipNdMttgz8O4IiouSXVRCNCT98HNz20oHRG1pxQVOxK2Wwt/yMJPJVQ7pjGcE3xPIUu7PNUvhScN3QcakPJOzy914JI5Fk7eX7H+7YiNtXn3oGTe9/eM9kQRlDb3pFz+86eU9k4spnCNo2e38dMSUV5+waq8kif5xItQNnMYuMs1WNJSwE7wvmw0RLuLs6HBS09Q2S1vYScI60lZJFhHKI1ZFbh4iP9a8gu/ek2l5Cppk9Pt+wRXHF8TKStPkhr0/zVBRlrtZpC/pquPCsNdUze9qbqNYTSp5ZdVeMB2a9YjZs0Kyl50OtMJMe5N9MlcHq8qXIWq1LbO8egFTCTGIAAsYMbPaMGpi5GIqbAC0l8Y09pvpm4epWpN9KvEnOVqgYYglaZOaU8dopPc9dJcDhhPoTc1T9lbO6cfFYDPUFOJJoUZDIQ7cKgklcLVk4B9lUn0X6xZkqG1N4vxo/0TLRhnIsGH10Lxq3Bx8PoejGITMSxul/EDpXslFLZapL2QXPH/5W/hD8Dy8J/ARJpdDMchMZVEAcwW29qaqBIJJA3LNJk0Y/E8ZqALLb4stK6FOm+uNcz26AyWE43ZoixhkQFcLW1p97Ucl6p0f5IfbzKJoxk9UHBgQpJaOk9JSfBRYZOVZmhsdFfq2ZROcG2mcAZs3NJYzLZeDVwbS46kII6NhfOM2x6bzamalw490gLRnPuwfnlieTjkdKpgWFnmfCuW1V1T5ONvSWR4ookVU3rBvBH8cZnjZStjKWX/YKdHyN/i75zMsELiUxltlDNUEuXnWzWKVPrYyg1tTftJoiapCAkWS+mXTBcxhUFIgfgENEbt7GLddzDxVoee3DnKMT1HLxxXc1BxB35p+nt8SsHUNiQZDqXcNQSVplhd3BkoJ8rg2zTJm/i46pjlzI8AkMqk+CZ1X8RWf0mHPL37rTVRwDx3XVW5x7RAef73RA43513hdH/eSOAHze7XZN/G7iAC6DJ/TdAoX09NDmK1DCLXRtocZZaMcZbbBg2Dd7cdYtMHpatsPm2dDy7vSHHErSoCTbAG3z0TSN3KPAPchfyiJDUGaRUpe0LlRQKOxNLWjNpx3VyWfgClNbltjeIInOHB21Pu/M1XZ7ij+vMUw5Xej3lLUYpa2fci5MpzK5z5N1YWEEkTgTFqULB6/KUAthzDa+YCTTd5Is0cMsiSl9dCb0FlXToLk/agljnfTqdJz2RjJzHVbmJfu/5e7yjY+fA5+tnbDgrOh05rKiFAeP+oBTbjYuit7+1pfhAyW6oUE0HCJ7sYMgQ+9K1+GjxQerN6hof28mA8fWplXxCzK7Oza1kJSm7wl2zhRjRuBMOTSja1cCvqOrI5/ujRvr4p9FuqKLD9VyQs38i7Fcya0YcT12xIMKcLOG/zdbWSKcmzerB0KgbbZyBXqxn4yzCJw9NLPgwNZSoB/jkI7kKNr32ORlbo1GgaDd+CgM7oqapVf1iPKgjp5lGgnY4H1FJBZWbUul0iuKxr2gvmVEs4SnC8A2zeNnt3DBbfx8iGeo2N1/WyDeG5hfH81krXbYzxTVuvHLAteUssjxJTJmqrRjMWgnHpevvBiq5s1Yzk3Y2aRfGLc+zxvN2MmdPNn7VWiwzwMdtas/rWix7/IDFsnt37ZWt/x1R3KSXRbZRGntQd7aRRBV4s5DJJrOWyMeL+WKZucVn+LHILT4W+8rdyi1o07NIZ3LNKT2j56ZFPd85nafbV3e1hzSe6lQLgXBtMp+vpPQ82s10hv95zbMML+HumR43O6b3TrVaxUTrhrveXRp5HRvh8cO66/z/9r47vKpie3vtml5Pek4K6b33c9JIIyG9SBEQFBQUFREVFRQVFBUUpYheVPSiooQQQgIJJEBiKgRICCGigOgFRYpyERUVwvfufU7CSQHRe/19/9zkWc/ss8u0NfPOrDUza9mY6dvBOJ60zv+AnhGHJX4TR3sbvf4VfhtDM4jepia2TOjANsSR07Uz2L9iRmPlDTgkrVFIUqbXLQmZstpHkjIxZEDnPZyk6fkHkqSkkR8kPT7Luvl7S/IcY6fQCI8u0lDxSoCdvfdb0lBhJwmPFh4KcNLR1VEI1hEh79QVIV8fVlLUuE1gekcOkBHXSroQ0c7ZBS7ydEXEcElEDL8uIhorBCNXV0dRkjaN9Wzs7a6LiVYQE+N0BEFvf0s2Z6AgaDDC08di0xABULKP4iQrlCdhFfNF7UnF4ZXDskkynD6I8Jbt+N2K3hlOnqXahpyOzjZItwyjB96yF0RYqpYixaJFNAwasPvNYVpGT0/fFlacrx7gr6uQrQVzF9k+BjYIuFjeUCUtRAcYyn77zA2s/Z8fRuv8gbm7ZPnDEScD5Nf0VzEGJuhw/aplS3tZtaxnDG8HiVgMNzUaEaTy0uqoXft01K5aHXVsAY5CWiTCTzXPuA/RRq+D9w7MPPQRl5gIbjGyRbFj7C9cDAXgtNhDsnpLwiZp1nOzGnXnovqmR7LRFK0/Sa0rCu9IP0aUz5FpLfZ5Dqpu9iFzTIh9EgtxuHJiUbSJsY9Ufd191XdYqj4Tc3dnhVtwuLmBwlBy5IhpjqnGvJ6kcXCNCA1ztvUzhjE+PTtMIJh1vJlHpKsy0s+J5yw9o0c4hvk4svfZxnoFJPrZsmb+2QlOwVbQb7qEGChMDQxMFQYh0q/ef8KOpZ21xqSeS4SDZFJPa1FvNLb+WXjB/Ax3wjVQCSOfgqWrvZOfg7Fo5tBnVw+z0Hthff3DP2+KDZ3dzUueNWhsUcLQxkA7bJIiCmoY6ZCsrnAyQJWoYdMQfaPtEMXhXzC7htmYX3RitI8IU0smN7S5dt3kGtPar2wMLnk0PWNOYdBgdeQTg3WPPn9sXc1BNnrBsMbGCphbktcaOMnekhlsq0u3HXVsq7X16xz9wpQGBsowv6F6ybcHLw1IBgu+wMppBvatj6dF/bvWtevgmlnCMMIo17fArWIGWZrRXTCVI3ET/RjPvrkHG6b1wNq39gBsg8Fc6T20EcXAQYA111n+xrmF68pDJysjE0ccLjOW3fy4GD0krWXayRuoJM2BZEYUNkkxd4C63dzf17V3oqnS2NgYdhVwYuBFqwAzAz1TU0svhZOrNbbIeCjhP8eQ807dPWA4YEOB9fAFpW8kDwZRPoyLtbTWjcEAa91WTpxV0NWvNW59HOHknfkRUwRbPRg6NLcOtM1fm/GbbbC9xDSWM5Cs4fPMeqCbMQ4O60sGcHCqSrLpJCmUmbVOfhh4TGwV68F04yFDgyB1N2xbT6NE2JFeTc302Z/rckOl/D4eM4MFRt1xw8ZWmsNruCydSx3IaK0HHnmtJp7x0/BSXrHR6CL6zNxq5UrZdGmf3WRvLaO13fRP9tAhkr/Cwc02Ki7WPnykiWDn5mb3tLutsa2V8XxphiiY5qOhwO6o1E68JOdM0CcbW9jL4iKmPXreWPm2EKzcJymdra0V6JPGLk6SNVErd4WRoxHmbjB7rIez5gzzoMLPzNzR0hPTU1MbJzMzJ4idSg+fPyH8p7gHWpmaclizUoWNsHW0snJwMof9IlhEcbCycrRfhbUbS2NDe7SmUKzYXl/ZDrTpvQA5FsvTpgJnYO7JPv0ymg2cBulxehbGsHWBVg/zxiaGFgaYTsL8MXYj2zli6tkj2JmbY9sECxuqRgpjcUCHz8RBledvscMrrsv4ocP2+L+ji3+t7caSUamBHfzqhL+pQ5dqe6xkX4qdMrRHb79RH17V14ffAcdthu3DR9jPuQTygSvrhRg0q3Rq/ubdEOsWDJZjxKGC9YjI6/64IHx7Du2C2m0lQ7ugrY7SxmKYzi1qjxa6a08QdfT3MWhtBvUxBoZ4NQOVRqo21dORqnvfl5X7mIZrtfu9F9HTbHR7mpvCSDmgp82yknqahdePWMnxQv+EAmdQz+1NV2KaFGntjB7IjvGOtIVlFqwQpcSOsHOC4T8XCwc9YzMDFycsUSl7fTh7JzvO0t1okPJeVu0rbCS/NfZPDe5QGkOHxjo9yt4RR57g6E3uhPIyJBM0uJv+5hB8VFBaOttxSNPYxlSUOb8P+1Q16L0KCrs9/zfordfPaz13qWFoTqP17zRy020XwvXWIG1ZGtQarLWtQQext/5niO19U8Q2svKXgNbLindytrK2xgldTUNhFG7YWuHkYCA3FHR9ds6NG0jhAJT2/BMonX5zlK7pbwtSk7d1NZHbDAxSab3g9jWZWbot5eqghtLtENwyGJulaXUn5JFAyCP3YD3oL8kjg4WRIdKJnq5kIm9uFm20YokZx3uq8/rEEpuhUh3XJ5ZIFmawEUxHJlk4SEYp0JVP3jIYmRxTqC+mpTgGe9ix99qm6EgmsbJk4tUnmXjJksk/rksmTrH2OoJJDuMSoCuopPQLKseTE3jWJ1wVJokoUq87CBElTD6QORvj3HLJwMCflh8SWGkHH5Sbkd66A9xAO7CiG+rQWrNEM+zeBcmbj2xF3BZ2RdhFf15W6NXPSpSa14vDySOS5VcjV9hvjEq48S6GnwFnJvamVp4wm3j8uqgQ6WJs7BJ5U1HBAseK9C17g8NVphj7TOGoELBorWv+1clIdoNo7mhuGhMZHO1kYOAUje0MOOmjL21nwJAtWrbAf7vkj8PKqM8ULHbuB+CAyKS+du79h+38JtZeB++XY2dIe+L8Rt4WEuZ11/gErY6iXgQy48CuuFdqzVe7b2zHlXmGV3jHuCpjglx50cpfPcIxwt+FzYeWISQzzIExDR6TqVVD+PWpIfykX1c7b2i49eWhG+R4WZBm5FZaqN0idyttVHFru988b9E+6xCJefYfttDKW9kDxzrcginW8YPbum7zvKEke7X3RvvgYB5L3gdXcVMzrFXDScLfa1mRI5/gvlVW/NfM5P4FNlz+bxnE/YtceP4/sIQ7LAs6OAvMlLwx/i2FkdZbZMF/Mpni+us/XCu1yMslIW46rliibIbuRnvqD3lz/j+aIuWYj7CMvic+5aVRgrWPlZm5wiLQ+mqthY0dlhhMTZygSWY+H8Kzf98Kz2JufSrEPK3lFSMKjibWZvCIy+npCTb6CiPJ4A9TOhwLW7UsXA4Pd/tuHdBkNzZKzblNL0mz7eXtx/lLPsf7HOD0O7ORfw2y36dlt/vw1lqllQkJEP82Zi9WBjjglKaenaO9ngWjsMSxJnidgdE6+B9XWr3xHsx6S81BMuW3qt+SH2sIS368iUts2LMwPWmvaRF6/eZYZUN+L8Y5mDjr9b74dzWHXg89U0Mfu2n2cTbGZryhsTLNBdtRkTdb7FrUY6EJNTH3MpM2ijrZWuibeuHMhplka1VjhRWzAEONdT9rA2H5n2ws0hztKx3IXS25aLml5sLc2gnxW8Nd5lb8N/wFbO59Z8DR8H1Djob3MibObMgtgHOvb/85byMjA+vr57wvXXfXMP+vAbjZQOcOQ703MOU3BfHePTd11MB8ORzTj2qZrurfV3xLTB9iKOWW2DvE/hr3V3j57JCNJ2NugXEZg2fhir/GpZf9ol2M9Z1igrWTa2bCzZnSNWjyzZwdDqgbtUD9FK2TT8/eIlD3+yXV+JyK8NJ6YJFR1qZ/u7covwTuYGtAVLjECxutYlA7aQfHzOS9amHhf98g/I21J9x8KV2Ne4usve1gNlVgpDozcgzEkVu+OWJ6pLGHh4seTiAqI5S9q3F8yYDjLfTM7S2kZTc7IyXOKRmKFkYOkda9iyDDQ/YBv/WX/m2js68VxhF5J7O7JazvKzwVFm6mzjLcGplYuLOyFW1O3042o4iN6TgrLEjihavcCV/5C+P1SdjfsMBJyPyh6uA/MJjZ722A67N9rgFhJStKdvKh9HUT3USs8WmM5/RLz1E6pq+5QQphAx2FsHbVf7WkEl4jrfrj4N73goGJlaOsE4Y5eFOtUli7KZy/aBQ2MmtkuFGKlYWBAkaqZUmZuc8SZ5L1Id0ZWPUM0Agznw3QCA+zJbxXOh9i0qfFYafYqk0lfbBNgK1Dzvg7xmbZ2sQ7KUZEyaofVk/P2NZGlouxXV0Pi9eyscvYYTZ7O8D9wzkIwN6wTDxfWnXzvEUHDtoT7pz732Zw6MwfuHOIDcoIU0pH1409AkPs/MfpHF73j1Rv1h5eDwzz6zu8vmDA4fWQQYfXvXF4ffENDq9H3aLHh86+g+rWLtZGf5cloVOcg3xgeCwY9uqf6CZ/7HteFkqiBxr+j4hSM9dN/2tsfP3Z08E/XHcVf3moq3gjW6+YMU/eg6kIDIwoBhrod7EwtQYgMb3hf/b0r5rHdFIjEC4Y5N7dQWmHcZ+5OMDKvrUqIc66384+a2cIQ/u9l4axKBIi+3tPg9OGmTDs+85/w2lDn12/P+Cg8EcuGeSFkn7N+H/DJztj4+ke9HC4tEdWaWcnYeAsaZPsoxIG2ttDR3lTtwqhTu7hLmbOUqf1+JMeFD7zy7F318eWGr8IZ78k24HbYG2Tqm/uIeGC4Obu42dg5WptB2Mog4w7zcaq1/r/tnGnP+IN8//JoBPD3JRD4f/3VpzevTnres/8WctNgEAiroW5SnpEml83/PtAwksidi6R9KFQR6QXB8JvfR/QYSKDHiJDKN0MvyQyGgmaCfqGyHgDkUkIkakNkZkZqIPIvIvI4iMiy1HY/I59W1bRIHhRsvqVyBpb52zwvQ0OVthiVmsvEDlMJnK8i0iJPCg/J3IuInKBN27XMiI3d9C3RO69gJTXibzuJvLGfR+Q70QiP+in/RF3ANZrAzcSBUFGDcbvENwPhWGj8NFEEQ8TRbYRRZWAkL9ofBdjAkKascYgfBs3HXSZSNVMpEYc8SuJEpBWwk9EiYg36QxRMny1j4TV2ZQniVINQC1EaauJ0sNBeJ6xiWhUFug3osx/E2Wh3kafI8p+lyjnKdBpolx8k/cgqJUo34uoAOUobCQqKiQq7iS67VGisYZE4w4Q3Y7fE38huqOdaAryfxfKNA11dU8s0fQ7iO5F/u77neh+eNZ7MILooVCih8GHR+yIHksietyJ6MlIonlLiJ56lmgB+PLsLKKFQUTPK4kWg78vVRItxb7kZQ5Er4E3y82JVqD8q1DO1cuI3sL2sTVI8x3U2doRRO+Dr+tQ5g/RHtYj7k8QXynKUIa6Kc8gqkAeK9EutiJf1bDotx28qEUcO58j2nWJqB5tq+EHosY5RM15RK1qorZTRHs9idqhUdw/j6gjhugg2kIX6qgb56F70CaOXCM6Cp4dH0t0AuYj/rWA6BT4+y3q9Duosc7CMtl5nM+6YER0Ee35Eur9Z7z3K/j6O8p2FW302hPEMD8Sth/CIOpjxICFjJFAjPEvxJguIca8lBjLTmKs7YixXU2M/WRiHCqIUVZiCeQiMa4dxLjnEONZT4z3EWJ85xPjn0BMwA+wU/ktMWhzTFgEMRG2xEReJiYa8ca+Q4xqATFqpJtwiJikvcSMRFqpSDvtDDEZPxOTZUrM6C3E5MwgJk9NTP5WYgqjiCn6hJiSDGLG3E/MOF9ixiOOCf8kZtJ4YibzxNyJdO46T8y0WGLuriNmehIxM64Sc186MTO/JuaBKmJmIe+znYmZ40rMo9OJeew4MY8j708+Q8z8aGKeVhKzYDExz7xIDNoGszCRmOcdiVmsR8yLKcS8tJ+YJZeIeQXvvvoNMa8j3eXriFk5h5g3ThLzFuJcs5aYdz4iZi3efR95X3cbMR8izfWo549xb8NoYko3EFN2DzHlyHMF6rcynJitjxBTjXxtTyWmFmWoKyJmJ+py9yvENKwipjGemOZRxLSivG2oy71IY38kMQdOEdOJMhxCXroRR08AMZ+dI+bz08QcBZ+OryDmBHj31TViTmYSc+opYr71JOZ0GzFnwINzNcR830jMhWPEXETeL4UQ89PbxPyCvPyqIOY3xH0FvOzNhR2JewlO0YjlzxIrfkus/nvEGn5KrPGrxJq+Tqz5UmItO4i1/oBYOz1iHSYSq8wh1vkpYkdYE+t2hFiPb4j1OkesbyKx/puJDXyT2OBCYkMXERvhQGzUc8TGehCrmkJs/EliE2cQm/wJsSn3EJumIDb9d2IzEddohtgce2Jzm4jNRzyFjxBbvITY294ndux4YscbEjvBjdhJk4mdnEXsnYhvqhGxd1sQOz2P2HsXEzsTZXmggdiHEM/DiP+RTGIfuw/Qj3tPoGzz8PypFGKfPkPsMwXEPudH7MItxC46QewLyNOLM4l9OZ7YpQ8S++oYYl/DN8ufJXYl8reqhdjVa4h9axmxa1KJffsqsWt9iH0/idh1qKOPUC8ff0hsaRGxZVeI3TyK2C13Elv1I7HVqK8a1G+tktidGcTuOkhs/WViGxFvM+q6zZLYvYHEtrcSe8CA2I6XiD34JbHdYcR+ZkrskenEfoE6PQY+fFlH7NcmxJ7Et4Ai9ls8+w51ehb3z1cSewF8uuhJ7E+o21/mEPvra8T+voLYq3uw9mlJHLOIOPYz4oQHiNNrIc4Q7jGNXybO1Js4GBPmLHOJs7InziafOLtA4hymEKd8kzjnH4lzrSPObS9xHq8R57WCOF+857ecuIC7MNG6nbiQauLCGoiLeJG4qJ+Ii3mcuLjZxKlXEpfoQ1yyP3EpzxGX5kVcRihxmWriRj9PXM6vxOU/Rlwhvi2JIQ6YwI3rJm4C8jMJHgsnzyHuzmbipiGue54k7l5j4u7Dt/cjjgd+J27WCeJmv0DcHOTlUXw7N4u4J0qIe/IqcU+FE7cAZX7WkbiFScQtqifuBQ/iFh8j7qUDxC35mbhXUJ5XrxH3GuplBepo5WTi3sDphNWvE/fWeeLW/JO4d2qIW1tE3Puop3Uq4j58mLj1KP/HyPMGlG8jyr/JnbjyVuIq7iGuMo+4rfOIq0Y+tt9G3I4LxNWdJW438tGAvDei3M3IS+uXxO1BPHvx3T58d6CYuM4ZxHVFEXcI5TqMcvWAd0ceJe6LYOKOKYn7EnQC9fH1JOJOot6+wX7y06iLM0jr7ETizv1C3Pf7iLtwlLiLjxB36U7ifgZff0Eavy4m7veNxPUmYjqUSTzzG/Hc78SLTxEPD/K80QriTc4Qbz6NeAXUBdZK4m1XEW+/iHjHY8Q7rSXe5Qvi3VKJ93iXeK8NxPucJd5fQXzg48QHjyY+pJv4MDXxEU8QHzWV+BhT4uMciFedIj4e3wID+OSFxKfYEp+KtNKXEz8qkPgs3Mv+hPi894gv2Eh8UQ7xJZCAb3uJeMwb+PHwoDfBl/iJ3xM/GQqkKT8RPxXlmHaZ+Hv+RfyMicTfh3zfb0H8A58TP+tt4mfjm4dRvkeQx7ko3xPI97xq4p9COgtaiH92PvEL64h/Ht8uRnletiR+iQ/xS0uIfwV5XXaQ+NfdiV+eR/xKlGEV6mt1A/FvvUD8Grz/zr3Ev3uF+PdQb+8jPxgf+A+2EP8Rnn2MKecnbxJfmkb8xreIL/ua+HJQRTnxlc3Eb71IfI0d8Tv+SXzdk8TvrCV+t4r4elDDM8R/eo34pgXENyOvbcjfHuS33Z/4/cHEH9hDfCfe70JZuvFtz6fEH3ma+M8/I/7oB8QfR52deJj4rxcTf3I68d+0EX/638SfnUL8eeTzwijiL2YR/yPK8xPK+EsX8b/uJf6KAfG9l0lgTpLA30eCOIkE/TYSDJtIMD5DglkOCeZ4rphGgtV3JNj+QILD7SQoO0lwPkjCCB8S3BeR4BlAgncMCb7pJPgXkRBYSkKIJ2HzBAkRoCjEF/MGCXHHSYg3ICEB10mzSRiZRUIq0kxfS0ImnCmNBmV3kJDnTELBPBKKlpFQsp2EMUhr/AgSJlwg4Y4VJExZTsJUYxKmnSBhOkvCvU4kzHQh4YFAEh7ENw+lkfCwLwlzukl4FOWYO4sEYIQwbzwJTz1PwoIdJDz7GAkLkYfnPyFh8UoSXjpGwtJ/kPBqNQmvB5Ow4hESViG91VdJ+MczJLwdT8K7S0l4P4OEdUjjI7zzcTIJGwpI2PhPEsqNSKhAupX4vRXp1CB/O2ohgqB8u2aQUI/yNEaT0IzvW+8gYc87JOybQ8IBUOcqErpeIqEb1z1fkXAEeTmKJYzjb5Nw4iwJX6MMJ1Ev37xHwmk8P4O8nXuFhB9MSLiA+rn4FgmXukj4+WUSLqNOfi8m4aolCdcsSWRiSYRHc1FwJVFcSqJ+IYkGb5FolEeiiQ+JZsUkmh8g0fIlEq0cSLSxIdHOm0QHTxKVuHaOJtF1GYlu80n0iCLRazyJPojDby6JAWNIDEokMeRREsPjSIxMJTG6ncTYxSSqHiEx/j0SE38mcSRDYsp3JELGEDP+QWIm8jF6D4k500jMQ1wFn5BY9BmJt3mROKaTxHFlJN7+JYmTkMfJP5J453ISp6lJvBvXM0JJvK+axPvxziwVQYwmcc49JD7mROLjz5P4pCmJ83aQ+LQFic+wJD6LtBYiz8+jnItnkviSPYkvI79LkdYrb5K47H0SX+8lcaUBiavw7uoXSHzrKRLX4Nk7viSurSXx/XoS1/1C4odvk7h+CYmfBJNYGkJimUBi+b0kVjxMYuUHJGIeKFafJnG7CYk7VpBYt5fEXaNJrI8h8dMgEptGkNhyB4ltqLe9D5C4r4LEA+BPRymJnadI7NpEYjfy2bOWxCN2JH4B/h1DuY+jPk94kPgV4vi6hsSTuHfqGomnA0g8gzjPrifxPL79ATy7cJjEi4j/kjGJP52RiZGl5pHPTX7zmzvM1D+RI3daEpYPbE0plsKv9l++cO2Xa6bcnRzkSBIxV5RlbPYApTPeoB2UyqVTOmaPPvAkHA7XtknMFHqQKaFUZjxFsLEUwo4gX8aJXJjPse+4lTyZL8mbnUo+zD/Igs3ENVTQ7BzyYpNB95IPOxG/sSbE5uD97yiaegkLEZTMchTIOiPOCFJzsymS3YF3A0H3ki87GaEnyBU0hTxBPowd8jWLDJAH6b43W4HwIYSPgzJx/QLCEoSTke5zCJ8AvU/enBPCR/DsPpAUzxFaKuUZYTrTTVguoTg2Eb+Polz7UZ4juP6d3JmVePcCfvcg34dxvZbcmPW4xm/kw5c5i9Af753Ds+/xzWnca8Y9CPvMeaRljut3EXLIjwfe+VZOO4OZSY8z31ESNBeBTAA9D7qNSyZzkAUoDfu5TbkxpAcSQcZc9rWr8u8iKQRJ4R24XwRKwCjvKYemnAuZwLCSLafEdSDZ4L4pN4LM5N/BZC2/m0CueKfvfYkUchiF79zJl/OX3zPlAsiKE4YhPeTxDlACKblsckHoj1OeVqhjBXuJjLhIXA9HVkjXCnlKkNO2ke8ZgaxBSm0okZS2K0gpkzGOLtoiL6YITZAecVlIQ6JsLaVpw1z5vlQ+QpmlfBiiDqzlOBJIH3VhhHgs5bSUiOt6qEmrRCr3tWu4dsD7joNIgbya9+e1jxRyft0RL6HuTHCdAgoFhYFCtGHoDSgMttP8EaoGkBLtVROPSo5DQTGIO55zpliEKuQhnbNHf3HGtR+e26OfelMAnoXiWSzuq3GdgPsR+N76BjyUeCzx0EXmQR+PglBX1tpymcs80/AkCPVmh/QYpJNA4QPKoCmnr/ZaU970/mea+6bkzBkiLQtyZs+AroKuyfecOSjO2CsI9eRyhHHhSONGba+PirR57yuDAuUxukG7k9paCEIfnfZmPUy7k8gG5IC825I7exH5+gWEUFuWiH4qIT+EgXJfCkbIa8tiDTIBuYNc5e985Hck0i1TX97icf9G+fFAuZRy/Y1Aef3Qvv248eTVfy1RAWgs7ml4EcK5kRsXgXshID9QAAirS+jbfuClD+57oR685Xu65emjQKQ3uO6lOu6r28H15znoN0P28IDtBH7jsDuu9RC6gbIQbwn6SQFoLKgIJP0erw2LtDQBdAcoAW3eCvVnA1JqyQPkDLLX1q2t9reIepKejdDSzdrOjdrI9bYi8cpP22595fehsEUZfLCs6oMyasIE9DNNu9clNy0NvhcFitOS1K9TQUnaMFXneQryHzjoWZJOeRwGlGUK+FKCsoeCPAf144FlckSbDkHeQ4DzQQi90V98Qf7ghzfqPABxSf3aQ6axuPaUMSgAbcgb/X5gHboPqsc+3sfK35iDDLVkBDy9rPPbEHm1kHHYGe87kj37PcY0A9LDjFUPfQjWV0HG+P0rwgQZhyWcsgY+GAKPpHt2OvVhMYS/Ulu1vgUe24L0tZgxqN+xF8hQIjkfUr7sEV4hc/Yyrm1BbkhjLJ4XYEwYi/YWJZVTzufQdqbbrxPIE/eMtPgZrm1jElY69VOW3P4cZJqI68k6FI7vA1DHBcCzAnkcdeDGIcxCneTI3wSDv379eHOdPLW8HXg/WMZPV3n8lvLih/4f3f88aMC7UYNCKS1N2x6IF8aD+DEBdSXNEXJBWaBsHcwOuIV+qUlLpTO2uGjJddg6vj6HcMR8xF/7vZe2PBoK7i/zwPpIv9YLHnCoS2Pk1YSbinlHDqgENA40EaQZB02A8QppviPPnZxBJLdnBdqH5n4C3ksAP6U2EY25hYThAdoxdXCbnaiDrzeug/D+UCnPtUxQ1wqUVQGsVaCNKoCVCuCHhpy0YQnamzSvmSyTG9JyQ1msUS4jbR6ttfXZFyqGxc++/Hlo82Mtj12+/fwI1YY5iKcA7VGiErldXg+z5HfsZIoBjZDrJ0CePyUjtJLnWQGoUzttvJrnATp9W6r3gfWj0KkjTb5c5T5sh7HbDjhiz36H8HfwTpO2k1zGOMwHrdFnnECaMUwh80+qE6nuPLXzJhOdOijQwdjBuBGAOba5fN9W5kcO2upk9O3J6K99VCLjYzji98Q4rDsv9NVpn5r7ujxghuGDGmX1RV/va++8zljsiTjGgb8Tkc5U0HTQSJRXgysKLR54ynPiofc8+9PW08Y3XNvsK780T7dD2S3lOKyQnj3K6oA07eVrKQyX50EaTJPuxcp8tu+nYDwPkZ9rfocC06Q86IPf+hhP9OVxzgLlUSJUgg8auh6Hk/x+Xz6leZ6lNoQ9bfDDatj5i+eg+Yun9hv3/rxI47c9ZDPNmrTrtRj6jTsN2fkod+fgdWkO+jvOnYGmCJL0SyxW+2i0JmQmURj+B/4xup+PzHF1hZUl157V2jTupR/6Vr6ZchYrr+QKKZ1kAtTgnBMnP7WCDncC1r0LsfptwBTirTvoKVcnL9FrWilTypfql1qUWpfalypLg0sfKp1TOrf0mdLnSl8sXVK6rHRt6cel5aU1pXWl9aWNpSdKT5aeLv136Y+lP5Ve2UgbLTYqN96/cdbGRzfO3/jMxiUbl21ct3H3xhMbL2+8UkZl+mVGZSFlEWUxZUllKWVZZTll+WXFZRPL7iibUja9rK6ssWxf2YGyzzbpbwrcFLFJvSllU+amBZtqNtVu2r2ptdy4PLV8VHlWeXZ5cfnE8nnlC8pXl79Vvqb8vfKPyzeVV5ZXl9eWN5a3lXeUnyg/tdlgs/lmxWb7zR6bfTYHbI7enLQ5dXPJ5rGb526et3nB5sWbl25esXl9BV+hX2Fc4VqxrGJFxZsVH1aUVrRWfFbxTcXpinMV31f8VPFLxa9bmC3WW0q2jN0yYcu0LTO2PLBl1pamLa1b2rd0bzmy5UqleaVdpbLStbKgsrhybOXkymmVMyvXVW6rPFZ5ovJk5fnKHyr/XWVVZVflUeVd5VsVWhVRlVSVVpVdlV/1XtW6qvVVG6oqq2qrdld1bLXY6rn17a3rtl7Y5rstZFvMNtW24m2Tt83ftmDbwm1Ltr22bfW2DdvOb7uwDebDqvWrPap9qiOrY6uTqidWT65+qLq8+ruasTWP1MytmVezsOaFmldqNtaU11TW1Nbsqmmraa/prDlS80XN8Zqvak7WnK75dXvsdvX2pO2jtudsL94+Y/us7XO2L9r+wvaPt2/YXr69evuO7XU7onbE7FDvSNiRsyN/R/GOsTum7Ni94/KOK7VUa1FrU2tX61TrWetbG1gbWptZu7B2ce2S2pW1b9SurV1fW1fbWLuvtrO2u/an2su1V+qEOvM6j7r8unF1z9QtrHuxbmXdmztTd47amb1zzM5xO2/fOWXn9J3zdr66c/3Ojp09u/R3Je8atatgV/mu9l0du47uHrt7wu5luzfuLt9dubtud/3utt3H6p3qXes96gPrQ+tj6pPqR9cX10+vn1W/tH5Z/Yr6NfXv1r9Xf6LBvkHZ4Nrg0+DfENgQ1jCzYU7D0w3rGtY3lDZUNdQ0HGs40XCy4XzDDw0/N/z6KX2q+HTGp7M+PfLpl43TGv/deLnJuMm3KaBJ1ZTWlNWU3VTUNK5pUtPkpvlNC5peaFra9FrTyqbVTVVNNU11TY1NbU37mzqaDjWdb7rQdKmZaRab9ZuVzR7NPs0BzeHN0c2xzarm5ObU5pLmCc3zmlc2f9xc3lzZXN28u/nT5qbm9uaO5kPNJ5rPNf/awre4tni0qFuSWlJbslsKWsa2PNIyt2V+y6KWl1peaXmtZUXLqpbVLe+1fNBS2sq08q36rYatFq02rcpW19bg1pjW7NaHWp9pXdS6pPVqG7XxbSZtFm12bQFt+W3Fbcva6tsa21rbOtu62rrbPm871nai7WTbt23n237dk7Mnf8+UPQv31O1p3NO5p2tv5t78vVP3nmw3abdqH9Hu2x7UHtIe057QntY+rv3N9jXta9vXt29o39he2d7RfnKf/j6nfRP2rdy3et+afev2fbyvfN/p/ZH7x+6fsH/K/un779s/Z//c/Qv3L9u/Yv+6/af2Xz6gPOBxIORAyYEJB6YemHFg7oETB37qmNkxq2NOx7yODzrWd5R21Hc0dnR3HOsM6YzpTOvM7szvnNg5vXNe53ud6zs3d27prDoYeHDBwYUHqw/WHtx9sPXghS7jLvMuqy7PLp8uVdf8roVdb3ZVdlV31Xa1dZ3vunBowqHHDy04tPjQ0m6+W79b3Z3Undo9tntC9+TuGd33d8/pXtz9QXdb92fdX3SfPEyHrQ8rD8ceVh/OOVxyeOzhCYdnHH7o8HOHlxxef7jxcPvhE4dP99j3uPZE9GT2FPQU94zrmdwzrWdGz8yexT1Lepb1rL52TUbeETTFVeklAFNJxlTzUgUw1RGYOguY+ljpAh1MXS9jam0/pn47CFNnAlMfvimmRmsxNVvG1AlaTK3VwdQAGVOTZUytHoKpRQMwdW35+vIN/ZjaqsVUfRlT7Ta73xBTXx+Eqav7MfUkMPUsMPVHCVMrrgFTi2VMnarF1EZg6t4thwZgav4gTD0KTP1X5blBmBqig6lr+zF1h4yp5v2Y6rMtuB9T52kx9dVtbwBTzwFTr2y7Vq0nY2pEdQwwdYIWU08DU+foYGppP6a2AlP3y5h6rB9TY4bF1PU6mBoBTFUNxdQd14CpVsBUx1oPGVNDhmBqbT+mXpIxle/H1AXA1MVDMHXyIExNGgZTS3dvAqbWAlNbgalKLaYGD8DUJQMw1e6mmHpUxtSzOpg6XYupUxsvyJjqI2NqatMoGVPHyJg6bwCmVjZVN+0ApjZrMfWchKlNV2RMdRyEqUnA1GIZU1f8KUydA0yd1/Jcy2Jg6jItpq5tWQdMJS2mmrda62DqrNYFwNSXW6/ImGo8AFN3y5jaIWPqkbaj/Zh6eU+2FlNrtZg6SoupxjKmemsxNb49tX1s++obYOqKYTB18hBMPfkHmLpOxtTdwNSujqNDMHVtP6YG9GPqriGYOg+YurofU8/JmDr3Bpg6XcbUF4Cprf2YagVMjZExtfgGmGqnxdR8YOrYoZjKfXjtxLUvT2Av5ZGrxXcVTymeVDym+LbiouLC4qRiKuotulL0U9Gloh+KzhedKfqi6FDR/qLmosai+qJdReuK3it6t+iNolVFK4teLVpSNK9odpF70YgilyL7Ipsi4yKDwp8LvyisLfyg8P3CdwtXF64qnF34YOH9hXcXTi2cVDix8PbCsYUFhfmFeYWZBT8XXCg4XfBtwZcF5QVLC14oWFAwr+CxguQCwwL9AiG/N39H/sL8Z/IX5D+d/3j+Q/lF+fn5sfkx+dH5EflB+YH5vvle+e75ynz7fEU+n095x/M+yzucdzCvLa8579O8mrzNeWV57+StyZuf90TeY3mz8mbmTc8ryf0t95fcS7lf5c7OfTB3Zu7k3Ntzk3JDc71yPXPdc91ynXOdcpW5trl8TnNOY059zvacbTlbcipy7siZmHN7TnFOQU5wjjLHOscyxyz7RPbx7C+yD2V3ZO/JXp79TPbE7Nuzx2UXZhdk52cHZftnu2Y7Zztl22ZbZxtmi9k0+urostGloz8e/dHod0e/OXrV6BdGjxodmbUzqzrr/qyorNAsvyyfLPMsIfNM5unMU5nHM49m9mQ2ZS7KfC5zbuZjmbMzx2QWZ2ZmZmQmZ3plemRajTo86t1RoaNsRlmNshhlOEp/FJtxKuNfGScyjmT0ZBzI2JfRntGU0ZjxaUZ9xq6M2ozSjAcyZmbMyLgzY1LG2IzUjIQMVYZ/hl+GYYZBhpDem34l/ff0RekL059Nfyb94fSH0h9Ivy/9rnQhbX/a3rS2tJq0bWlb0yrTytI2pK1P+zDt1bSStMK0vLSMtPS0hLToNI805zSbNEWaeerF1Aup51O/ST2a2pb6Tuqq1FmpD6Telzo5dWLKlpTylI0p/0x5P+W9lLdT3khZmDI7ZXxKeErgyKsjm0fuHlk9cvzIxJHqkaHJW5O3JC9InpY8NXlK8vjkMckFyQnJlNSb9HvSj0kXk84lnUr6IqkraXdSTdI7SWuS3kx6PWlZ0qtJBUkOSXZJ1kmmScZJRkl6ifsTWxLrEt9MXJW4PPHlxMWJdydOTZySeHvi+MTixMLE7MS4hG8STiTMTXg4/of4afF3xGfHh8YHx4+It4+3jbeJN483iTeI11efV59Vn1KfUB9Tf67+TF2n3qHerq5Ub1FvUpepN6hXqF9Xv6perF6ofk79kPpe9T3qqepJ6tvV49Xj1CXqInWqOkHtotZX/aT6QXVO9Z3qa9UJ1ZeqI6rDqi5Vq6pOtVn1kWqJ6kXVbNWDqpmqaaopqttVSaoElUoVpYpQhapCVEGqQFWAylPlrnKK2xPXGtcU1xi3K642bltcZdyHce/EvRw3PW583Ji4wth/xX4Vezy2J/ZQ7P7YHbGrY1fGjo/1j/WN9Yp1iXWOdYp1iLWPtY21irWMNYnlYjbHbIp5N2Z+THpMUkxETHj0ruia6A+jvaMp6reo76O+izoVdTLqWNSRqENRDVELo56NejpqbtSjUY9EPRhVHJUc5RxlGNkeuTJyeeSyyBcjF0U+HTkq4krE5xE9EYci9ke0RzRG1EdsjdgQsT7izYjxEaMiPCOcIxThP4R/F/51+PHwjvAZ4SVhX4YdDTsSdjBsQ9jHYR+GLQ97Ley5sPlh/mEeYXZhlmFmWJj7NfSb0E9D60KrQitDt4TGh5wNOR1SFVIRUh7yccizIfeETA2ZElIQkhcSH3w1+Jfgk8F7gluCG4Org1cFrwj2DTYN1odV4qtBLwQtDCoIyg0aHRQTFBkUFuQf5BPkFmQeeCnwYGBjYEPg9sB3A5cEPh94X+CMwHGBRYEFgbmBIwNVgX6BboF6AecCTgUcDNgbsCZgVcBzAQ8GzAi4J2BqwKSA8QFjAkoC4gKiAyICAq9rIoQs+t/f//7+9/e/v//9/Wd/UwhnR3ACabykaeVx4AJ2lEh7jR1o+KW5ZskUJzc11xzsTt2tvebJBiaMNddYt8UJNc21iPsNOGz4IM2CXabZNAMWaabjgLQrNMQhFEoxuCrGnWkIR8J6hSssWZVQMkLppNuD2NU/DQ46pPeTYcltDt58EPcfxluPIM+FeCpZeJuJ69mILQhxSrGqEMdoeJTMxZXmzcBB72ruug66ext+SbHPQCoP4On1GIePRaOdxt+1qiEab63emxhoVczkMcuQsKqPEyXp2cWkLx/gIlnj0nfqy5CMUbvy3/8D9cMd6g=="
