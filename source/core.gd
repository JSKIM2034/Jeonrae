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
	# 살짝 처진 빨랫줄 (꼰 새끼줄)
	var st0 := MeshKit.begin()
	var sag := 0.06 * clampf(length / 3.0, 0.5, 2.0)
	for k in 12:
		var x0 := -length / 2.0 + length * k / 12.0
		var x1 := -length / 2.0 + length * (k + 1) / 12.0
		var y0 := -sag * (1.0 - pow(2.0 * x0 / length, 2.0))
		var y1 := -sag * (1.0 - pow(2.0 * x1 / length, 2.0))
		MeshKit.tube(st0, Vector3(x0, y0, 0), Vector3(x1, y1, 0), 0.014, 0.014, Color(0.74, 0.64, 0.45) if k % 2 == 0 else Color(0.66, 0.56, 0.38), 5)
	kit_instance(root, MeshKit.finish(st0))
	# 흰 보자기(줄에 걸쳐 앞뒤로 늘어짐), 옥색 저고리(어깨로 걸림, 소매 펼침), 분홍 치마(주름)
	var kinds := ["sheet", "jeogori", "chima"]
	var cols := [Color(0.97, 0.97, 0.94), Color(0.72, 0.86, 0.9), Color(0.98, 0.78, 0.8)]
	var xs := [-0.95, 0.0, 0.95]
	for k in 3:
		var cl := Node3D.new()
		var x: float = xs[k] * length / 3.0
		cl.position = Vector3(x, -sag * (1.0 - pow(2.0 * x / length, 2.0)), 0)
		root.add_child(cl)
		kit_instance(cl, laundry_mesh(kinds[k], cols[k], int(a.x * 7.0 + k)))
		sway_items.append([cl, cl.position, 1, xs[k] * 2.0 + a.x, 0.1])

# ---------- 천(빨래) 모양: 결이 진 얇은 천을 격자로 짓고 주름만큼 밀어내요 ----------
# o: 한쪽 모서리, du/dv: 두 변(길이 포함), nu/nv: 칸 수, foldf(u, v) -> 천 면에서 밀려나는 거리(u, v는 0~1)
# 접힌 골은 어둡게, 솟은 결은 밝게. 가장자리엔 박음질 단
func cloth_sheet(st: SurfaceTool, o: Vector3, du: Vector3, dv: Vector3, nu: int, nv: int, col: Color, foldf: Callable, hem: Color = Color(0, 0, 0, 0)) -> void:
	var nrm := du.cross(dv).normalized()
	var pts := []
	var cols := []
	for j in nv + 1:
		var row := []
		var crow := []
		for i in nu + 1:
			var u := float(i) / nu
			var v := float(j) / nv
			var f: float = foldf.call(u, v)
			row.append(o + du * u + dv * v + nrm * f)
			# 주름 음영: 옆 칸과의 높이 차로 골/결을 찾아요
			var fx: float = foldf.call(minf(u + 0.04, 1.0), v) - foldf.call(maxf(u - 0.04, 0.0), v)
			var c := col.darkened(clampf(fx * 9.0 + (0.08 if f < 0.0 else 0.0), -0.12, 0.32))
			if hem.a > 0.0 and (u < 0.035 or u > 0.965 or v > 0.965):
				c = hem
			crow.append(c)
		pts.append(row)
		cols.append(crow)
	for j in nv:
		for i in nu:
			MeshKit.quad(st, pts[j][i], pts[j][i + 1], pts[j + 1][i + 1], pts[j + 1][i], cols[j][i], cols[j][i + 1], cols[j + 1][i + 1], cols[j + 1][i])

# 빨랫줄에 걸린 빨래 (줄이 y=0, 아래로 늘어져요)
func laundry_mesh(kind: String, col: Color, seed_v: int) -> ArrayMesh:
	var key := "laundry_%s_%d" % [kind, seed_v % 3]
	if prop_mesh_cache.has(key):
		return prop_mesh_cache[key]
	var ph := float(seed_v % 3) * 1.7
	var st := MeshKit.begin()
	match kind:
		"sheet":
			# 줄에 반 접어 걸친 보자기: 앞자락 길고 뒷자락 짧게, 아래로 갈수록 물결
			var w := 0.74
			var front := func(u: float, v: float) -> float:
				return (0.035 * sin(u * 11.0 + ph) + 0.015 * sin(u * 23.0 + 1.0)) * pow(v, 1.2) + 0.012 * sin(v * 3.0)
			cloth_sheet(st, Vector3(-w / 2.0, 0, 0.012), Vector3(w, 0, 0), Vector3(0, -0.78, 0), 16, 10, col, front, col.darkened(0.08))
			var back := func(u: float, v: float) -> float:
				return -(0.03 * sin(u * 9.0 + ph + 2.0)) * v
			cloth_sheet(st, Vector3(-w / 2.0, 0, -0.012), Vector3(w, 0, 0), Vector3(0, -0.42, 0), 14, 6, col.darkened(0.05), back)
			# 줄 위로 둥글게 넘어가는 접힌 자리
			for k in 8:
				var x0 := -w / 2.0 + w * k / 8.0
				MeshKit.tube(st, Vector3(x0, 0.006, 0), Vector3(x0 + w / 8.0, 0.006, 0), 0.016, 0.016, col.lightened(0.05), 6)
			# 빨래집게 대신 묶은 끈
			for sx in [-0.3, 0.3]:
				MeshKit.tube(st, Vector3(sx, 0.03, 0), Vector3(sx, -0.05, 0.025), 0.008, 0.008, Color(0.6, 0.48, 0.3), 4)
		"jeogori":
			# 어깨를 줄에 걸친 저고리: 몸판, 양 소매(살짝 늘어짐), 흰 동정과 깃, 붉은 고름 두 가닥
			var body := func(u: float, v: float) -> float:
				return 0.02 * sin(u * 8.0 + ph) * v + 0.01 * sin(v * 9.0)
			cloth_sheet(st, Vector3(-0.22, -0.02, 0.012), Vector3(0.44, 0, 0), Vector3(0, -0.46, 0), 10, 10, col, body, col.darkened(0.12))
			cloth_sheet(st, Vector3(-0.22, -0.02, -0.01), Vector3(0.44, 0, 0), Vector3(0, -0.46, 0), 6, 6, col.darkened(0.1), func(u, v): return 0.0)
			for sx in [-1.0, 1.0]:
				# 소매: 어깨에서 밖으로, 끝으로 갈수록 처지고 소매 끝은 둥근 배래
				var sleeve := func(u: float, v: float) -> float:
					return 0.015 * sin(u * 7.0 + v * 3.0 + ph)
				var so := Vector3(sx * 0.2, -0.02, 0.008)
				var du := Vector3(sx * 0.36, -0.12, 0)
				var dv := Vector3(0, -0.24, 0)
				cloth_sheet(st, so, du, dv, 8, 5, col.lightened(0.04), sleeve, col.darkened(0.1))
				# 소매 끝동 (색 띠)
				cloth_sheet(st, so + du * 0.9 + Vector3(0, 0, 0.002), du * 0.1, dv, 2, 5, Color(0.55, 0.3, 0.45), func(u, v): return 0.0)
			# 깃과 흰 동정 (목 둘레에서 비스듬히 내려오는 띠)
			MeshKit.tube(st, Vector3(-0.08, -0.03, 0.028), Vector3(0.05, -0.2, 0.03), 0.018, 0.016, Color(0.98, 0.98, 0.95), 6)
			MeshKit.tube(st, Vector3(0.08, -0.03, 0.026), Vector3(0.0, -0.12, 0.028), 0.016, 0.014, Color(0.98, 0.98, 0.95), 6)
			# 고름: 매듭에서 늘어진 붉은 두 가닥
			var knot := Vector3(0.06, -0.22, 0.034)
			MeshKit.ball(st, knot, Vector3(0.018, 0.014, 0.01), Color(0.82, 0.18, 0.25), 6, 4)
			for g in 2:
				var a0 := knot
				for q in 4:
					var a1 := a0 + Vector3(0.01 + g * 0.012 + sin(q + ph) * 0.006, -0.05, 0.004)
					MeshKit.tube(st, a0, a1, 0.011, 0.011, Color(0.82, 0.18, 0.25), 4)
					a0 = a1
		"chima":
			# 허리말기를 줄에 걸친 치마: 아래로 넓어지고 세로 주름이 촘촘
			var top_w := 0.42
			var bot_w := 0.62
			var nu := 20
			var nv := 10
			var pts := []
			var cs := []
			for jv in nv + 1:
				var v := float(jv) / nv
				var row := []
				var crow := []
				var wv := lerpf(top_w, bot_w, v)
				for iu in nu + 1:
					var u := float(iu) / nu
					var pleat := sin(u * TAU * 7.0) * lerpf(0.012, 0.03, v) + sin(u * 5.0 + v * 2.0 + ph) * 0.02 * v
					row.append(Vector3((u - 0.5) * wv, -0.06 - v * 0.74, 0.012 + pleat))
					var c := col.darkened(clampf(-cos(u * TAU * 7.0) * 0.12, -0.06, 0.12))
					if v > 0.95:
						c = col.darkened(0.12)
					crow.append(c)
				pts.append(row)
				cs.append(crow)
			for jv in nv:
				for iu in nu:
					MeshKit.quad(st, pts[jv][iu], pts[jv][iu + 1], pts[jv + 1][iu + 1], pts[jv + 1][iu], cs[jv][iu], cs[jv][iu + 1], cs[jv + 1][iu + 1], cs[jv + 1][iu])
			# 흰 허리말기와 끈
			cloth_sheet(st, Vector3(-top_w / 2.0, 0.01, 0.016), Vector3(top_w, 0, 0), Vector3(0, -0.075, 0), 6, 2, Color(0.97, 0.96, 0.92), func(u, v): return 0.0)
			MeshKit.tube(st, Vector3(top_w / 2.0, -0.03, 0.02), Vector3(top_w / 2.0 + 0.05, -0.2, 0.03), 0.009, 0.008, Color(0.97, 0.96, 0.92), 4)
	var m := MeshKit.finish(st)
	prop_mesh_cache[key] = m
	return m

# 땅에 흩어진 빨래 더미: 구겨져 겹친 천 몇 장 + 개켜진 저고리 + 붉은 고름 (가운데가 (0,0,0), 땅 위)
func laundry_pile_mesh(seed_v: int) -> ArrayMesh:
	var key := "laundry_pile_%d" % (seed_v % 3)
	if prop_mesh_cache.has(key):
		return prop_mesh_cache[key]
	var r := RandomNumberGenerator.new()
	r.seed = 300 + seed_v % 3
	var st := MeshKit.begin()
	var cloth := [Color(0.88, 0.88, 0.84), Color(0.68, 0.8, 0.9), Color(0.92, 0.74, 0.74), Color(0.86, 0.8, 0.62)]
	for i in 4:
		var a := r.randf() * TAU
		# du × dv 가 위(+y)를 보게 (주름이 땅 위로 솟게)
		var du := Vector3(-sin(a), 0, cos(a)) * r.randf_range(0.5, 0.65)
		var dv := Vector3(cos(a), 0, sin(a)) * r.randf_range(0.7, 0.9)
		var o := Vector3(r.randf_range(-0.12, 0.12), 0.035 + i * 0.04, r.randf_range(-0.1, 0.1)) - (du + dv) / 2.0
		var p1 := r.randf() * TAU
		var p2 := r.randf() * TAU
		# 구겨진 천: 가운데가 불룩하고 이리저리 접힌 골, 가장자리는 땅에 처짐
		var crumple := func(u: float, v: float) -> float:
			var mid := sin(u * PI) * sin(v * PI)
			# 가장자리는 땅 쪽으로 처지되 땅 밑으로 꺼지지 않게
			var edge := minf(minf(u, 1.0 - u), minf(v, 1.0 - v))
			return mid * 0.1 + 0.03 * sin(u * 9.0 + p1) * sin(v * 7.0 + p2) * (0.4 + mid) + 0.015 * sin((u + v) * 13.0 + p1) - 0.03 * (1.0 - clampf(edge * 6.0, 0.0, 1.0)) + 0.01
		cloth_sheet(st, o, du, dv, 12, 10, cloth[i], crumple, cloth[i].darkened(0.1))
	# 비틀어 짠 빨래 뭉치 둘: 꼬인 주름이 진 굵은 천 타래
	for q in 2:
		var cc: Color = cloth[(q + 1) % 4]
		var a := r.randf() * TAU
		var dirv := Vector3(cos(a), 0, sin(a))
		var start := Vector3(r.randf_range(-0.15, 0.15), 0.2 + q * 0.03, r.randf_range(-0.12, 0.12)) - dirv * 0.22
		var rings := []
		for k in 11:
			var t := float(k) / 10.0
			var c := start + dirv * t * 0.44 + Vector3(0, sin(t * PI) * 0.05, 0) + dirv.cross(Vector3.UP) * sin(t * 4.0 + q) * 0.04
			var rad := 0.05 * (0.55 + 0.45 * sin(t * PI))
			rings.append([c, rad, rad * 0.8])
		var tw := float(q) * 1.3
		kit_loft(st, rings, dirv.cross(Vector3.UP).normalized(), Vector3.UP, 12, func(t: float, ang: float) -> Color:
			# 꼬인 결: 비스듬한 골이 진하게
			return cc.darkened(0.2) if sin(ang * 2.0 + t * 22.0 + tw) > 0.55 else cc.lightened(0.04 * sin(ang)))
	# 위에 반쯤 개켜진 저고리 (몸판, 접힌 소매, 흰 동정)
	var jo := Vector3(-0.18, 0.2, -0.14)
	var jcol := Color(0.66, 0.82, 0.8)
	cloth_sheet(st, jo, Vector3(0, 0.01, 0.32), Vector3(0.42, 0.02, 0), 6, 8, jcol, func(u, v): return 0.02 * sin(v * 6.0) * sin(u * PI), jcol.darkened(0.12))
	cloth_sheet(st, jo + Vector3(0.36, 0.03, 0.02), Vector3(-0.04, 0.01, 0.2), Vector3(0.28, -0.04, 0.1), 4, 6, jcol.lightened(0.02), func(u, v): return 0.015 * sin(u * PI))
	MeshKit.tube(st, jo + Vector3(0.08, 0.035, 0.02), jo + Vector3(0.2, 0.04, 0.25), 0.016, 0.014, Color(1, 1, 0.98), 6)
	# 붉은 고름 한 가닥 (구불구불)
	var g0 := jo + Vector3(0.24, 0.04, 0.22)
	for q in 5:
		var g1 := g0 + Vector3(0.06, -0.008, 0.03 * sin(q * 1.7))
		MeshKit.tube(st, g0, g1, 0.012, 0.012, Color(0.84, 0.2, 0.28), 4)
		g0 = g1
	var m := MeshKit.finish(st)
	prop_mesh_cache[key] = m
	return m

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

# 나무 모델의 잎 면 가운데 숨은 둥근 덩어리(그림 자리가 한 점이라 단색 공처럼 보임, 버드나무에 있었음)를 빼요.
# 잎 카드는 그림 자리가 넓으니 그대로 남아요.
func strip_leaf_blobs(mesh: Mesh) -> Mesh:
	var am := mesh as ArrayMesh
	if am == null:
		return mesh
	var out := ArrayMesh.new()
	var changed := false
	for i in am.get_surface_count():
		var mat := am.surface_get_material(i)
		var arr := am.surface_get_arrays(i)
		if mat != null and mat.resource_name == "Leaf" and arr[Mesh.ARRAY_INDEX] != null and arr[Mesh.ARRAY_TEX_UV] != null:
			var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
			var keep := PackedInt32Array()
			for t in range(0, idx.size(), 3):
				var a := uv[idx[t]]
				var b := uv[idx[t + 1]]
				var c := uv[idx[t + 2]]
				if a.distance_squared_to(b) < 1e-8 and a.distance_squared_to(c) < 1e-8:
					changed = true
					continue
				keep.append(idx[t])
				keep.append(idx[t + 1])
				keep.append(idx[t + 2])
			arr[Mesh.ARRAY_INDEX] = keep
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		out.surface_set_material(i, mat)
	return out if changed else mesh

func load_trees() -> void:
	tree_tried = true
	if not ResourceLoader.exists("res://models/trees.glb"):
		return
	var root: Node = (load("res://models/trees.glb") as PackedScene).instantiate()
	for node in root.find_children("*", "MeshInstance3D", true, false):
		tree_meshes[node.name] = strip_leaf_blobs((node as MeshInstance3D).mesh)
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

# 짚신: 발 모양 바닥(씨줄로 촘촘히 엮은 결, 날줄 네 가닥), 앞코 매듭, 양옆 고리(총) 넷씩과 그 사이를 꿴 총갱기,
# 둥글게 세운 뒤축. 앞(+z)이 발끝, 길이 0.4, 가운데가 (0,0,0)
func jipsin_mesh() -> ArrayMesh:
	if prop_mesh_cache.has("jipsin"):
		return prop_mesh_cache["jipsin"]
	var st := MeshKit.begin()
	var straw := Color(0.88, 0.74, 0.45)
	var straw_dk := Color(0.66, 0.52, 0.3)
	var straw_lt := Color(0.95, 0.85, 0.58)
	# 발바닥 윤곽 [z, 가운데 높이, 반폭, 두께]
	var ctrl := [
		[-0.2, 0.012, 0.03, 0.012],
		[-0.185, 0.012, 0.062, 0.016],
		[-0.14, 0.012, 0.07, 0.017],
		[-0.06, 0.012, 0.064, 0.017],
		[0.02, 0.012, 0.078, 0.017],
		[0.1, 0.012, 0.086, 0.017],
		[0.16, 0.012, 0.072, 0.016],
		[0.19, 0.013, 0.045, 0.014],
		[0.205, 0.014, 0.012, 0.01],
	]
	var rings := smooth_rings(ctrl, 4, true)
	var colf := func(t: float, a: float) -> Color:
		var z := lerpf(-0.2, 0.205, t)
		var x := cos(a)
		# 날줄 네 가닥이 지나는 자리
		for wx in [-0.62, -0.2, 0.2, 0.62]:
			if absf(x - wx) < 0.07:
				return straw_dk
		# 씨줄: 가로로 촘촘히 엮인 짚, 한 줄씩 엇갈린 결
		var row := sin(z * 230.0)
		var off := sin(x * 18.0 + (PI if row > 0.0 else 0.0))
		var c: Color = straw_lt if off > 0.3 else straw
		if absf(row) < 0.25:
			c = straw_dk.lerp(straw, 0.4)
		return c
	kit_loft(st, rings, Vector3(1, 0, 0), Vector3(0, 1, 0), 18, colf)
	# 앞코: 날줄을 모아 묶은 작은 매듭과 발등으로 올라가는 앞총 끈
	MeshKit.ball(st, Vector3(0, 0.03, 0.19), Vector3(0.022, 0.018, 0.02), straw_dk, 8, 5)
	# 양옆 고리(총): 바닥 가장자리에서 솟은 작은 짚 고리 넷씩
	var rope_pts := {-1.0: [], 1.0: []}
	for sx in [-1.0, 1.0]:
		for k in 4:
			var z := lerpf(0.11, -0.1, k / 3.0)
			var half := 0.0
			for rg in rings:
				if absf((rg[0] as Vector3).z - z) < 0.012:
					half = float(rg[1])
			var base := Vector3(sx * (half - 0.004), 0.02, z)
			var top := base + Vector3(sx * -0.012, 0.045, 0)
			# 고리 = 짧은 두 기둥과 위쪽 반원
			var prev := base + Vector3(0, 0, 0.014)
			for q in 7:
				var a := PI * (q + 1) / 7.0
				var pt := base + Vector3(sx * -0.012 * sin(a), 0.045 * sin(a), 0.014 * cos(a))
				MeshKit.tube(st, prev, pt, 0.0045, 0.0045, straw_dk.lerp(straw, 0.5), 4)
				prev = pt
			rope_pts[sx].append(top)
	# 총갱기: 고리 끝을 꿰어 발등을 두르는 새끼줄 (앞코에서 시작해 양옆 고리, 뒤축까지)
	for sx in [-1.0, 1.0]:
		var pts: Array = [Vector3(0, 0.035, 0.18)] + rope_pts[sx] + [Vector3(sx * 0.045, 0.06, -0.17)]
		for k in pts.size() - 1:
			var a0: Vector3 = pts[k]
			var a1: Vector3 = pts[k + 1]
			var mid := (a0 + a1) / 2.0 + Vector3(sx * 0.004, 0.006, 0)
			MeshKit.tube(st, a0, mid, 0.0055, 0.0055, straw, 5)
			MeshKit.tube(st, mid, a1, 0.0055, 0.0055, straw.darkened(0.05), 5)
	# 뒤축: 발뒤꿈치를 감싸는 둥근 짚 둑 (여러 겹)
	for layer in 3:
		var y := 0.024 + layer * 0.014
		var prev2 := Vector3.ZERO
		for q in 11:
			var a := lerpf(-1.25, 1.25, q / 10.0)
			var pt := Vector3(sin(a) * 0.06, y, -0.17 - cos(a) * 0.022)
			if q > 0:
				MeshKit.tube(st, prev2, pt, 0.008, 0.008, straw if layer % 2 == 0 else straw_lt, 5)
			prev2 = pt
	# 삐져나온 짚 끝 몇 가닥
	var r := RandomNumberGenerator.new()
	r.seed = 12
	for k in 7:
		var sx := -1.0 if k % 2 == 0 else 1.0
		var z := r.randf_range(-0.16, 0.16)
		var b := Vector3(sx * 0.06, 0.015, z)
		MeshKit.tube(st, b, b + Vector3(sx * r.randf_range(0.015, 0.035), r.randf_range(-0.004, 0.01), r.randf_range(-0.015, 0.015)), 0.0025, 0.001, straw_lt, 3)
	var m := MeshKit.finish(st)
	prop_mesh_cache["jipsin"] = m
	return m

# 새끼줄: 두 가닥 짚을 꼬아 만든 줄 (z 방향, 0 에서 -length 까지)
func straw_rope_mesh(length: float) -> ArrayMesh:
	var key := "rope_%d" % int(length * 100.0)
	if prop_mesh_cache.has(key):
		return prop_mesh_cache[key]
	var st := MeshKit.begin()
	var n := int(length / 0.012)
	for strand in 2:
		var ph := PI * strand
		var col := Color(0.86, 0.72, 0.44) if strand == 0 else Color(0.78, 0.62, 0.36)
		var prev := Vector3.ZERO
		for k in n + 1:
			var z := -length * k / n
			var a := z * 70.0 + ph
			var pt := Vector3(cos(a) * 0.012, sin(a) * 0.012, z)
			if k > 0:
				MeshKit.tube(st, prev, pt, 0.011, 0.011, col.lightened(0.08 * sin(a)), 6)
			prev = pt
	# 끝에 풀린 짚 몇 가닥
	for k in 5:
		var a := k * TAU / 5.0
		MeshKit.tube(st, Vector3(0, 0, 0.0), Vector3(cos(a) * 0.02, sin(a) * 0.02, 0.03), 0.003, 0.0015, Color(0.92, 0.8, 0.5), 3)
	var m := MeshKit.finish(st)
	prop_mesh_cache[key] = m
	return m

# 제비: 매끈한 유선형 몸(남색 등, 흰 배, 붉은 이마와 멱), 긴 제비 꼬리(갈라진 두 가닥). 앞(+z), 가운데 (0,0,0)
func swallow_mesh() -> ArrayMesh:
	if prop_mesh_cache.has("swallow"):
		return prop_mesh_cache["swallow"]
	var st := MeshKit.begin()
	var ctrl := [
		[-0.16, 0.02, 0.01, 0.008],
		[-0.12, 0.012, 0.03, 0.026],
		[-0.05, 0.004, 0.052, 0.05],
		[0.03, 0.006, 0.058, 0.056],
		[0.09, 0.022, 0.046, 0.046],
		[0.12, 0.038, 0.04, 0.04],
		[0.155, 0.048, 0.042, 0.04],
		[0.19, 0.05, 0.032, 0.03],
		[0.21, 0.048, 0.012, 0.012],
	]
	var rings := smooth_rings(ctrl, 4, true)
	var navy := Color(0.14, 0.17, 0.36)
	var navy_hi := Color(0.24, 0.3, 0.55)
	var white := Color(0.97, 0.95, 0.9)
	var red := Color(0.78, 0.3, 0.2)
	var colf := func(t: float, a: float) -> Color:
		var z := lerpf(-0.16, 0.21, t)
		var up := sin(a)
		if z > 0.12:
			# 머리: 붉은 이마·멱, 위는 남색
			if up < -0.2 or (z > 0.18 and up < 0.5):
				return red
			return navy.lerp(navy_hi, clampf(up, 0.0, 1.0) * 0.6)
		if z > 0.09 and up < -0.35:
			return navy   # 가슴의 남색 띠
		if up < -0.15:
			return white
		return navy.lerp(navy_hi, clampf(up, 0.0, 1.0) * 0.5)
	kit_loft(st, rings, Vector3(1, 0, 0), Vector3(0, 1, 0), 20, colf)
	for sx in [-1.0, 1.0]:
		var ep := Vector3(sx * 0.034, 0.062, 0.17)
		MeshKit.ball(st, ep, Vector3(0.009, 0.01, 0.009), Color(0.04, 0.04, 0.05), 8, 6)
		MeshKit.ball(st, ep + Vector3(sx * 0.006, 0.004, 0.004), Vector3(0.003, 0.003, 0.003), Color(1, 1, 1), 4, 3)
		# 길게 갈라진 꼬리깃 (수평으로 V자)
		MeshKit.leaf(st, Vector3(sx * 0.008, 0.02, -0.14), Vector3(sx * 0.3, 0.05, -1.0), Vector3(1, 0, 0), 0.24, 0.035, navy, 0.0, "long")
		# 다리
		MeshKit.tube(st, Vector3(sx * 0.02, -0.04, 0.03), Vector3(sx * 0.024, -0.07, 0.045), 0.006, 0.005, Color(0.3, 0.2, 0.18), 4)
	# 작은 부리
	MeshKit.tube(st, Vector3(0, 0.044, 0.205), Vector3(0, 0.042, 0.232), 0.011, 0.002, Color(0.12, 0.1, 0.1), 6)
	var m := MeshKit.finish(st)
	prop_mesh_cache["swallow"] = m
	return m

# 제비 날개 한 짝: 어깨에서 뒤로 뻗은 길고 뾰족한 칼깃 날개 (side: +1 오른쪽, -1 왼쪽)
func swallow_wing_mesh(side: float) -> ArrayMesh:
	var key := "swallow_wing_%d" % int(side)
	if prop_mesh_cache.has(key):
		return prop_mesh_cache[key]
	var st := MeshKit.begin()
	var navy := Color(0.16, 0.19, 0.38)
	# 몸 옆에 접어 붙인 날개: 수평 깃 몇 장이 뒤로 길게 (끝이 꼬리 쪽으로 뾰족)
	for k in 4:
		MeshKit.leaf(st, Vector3(0, k * 0.004, 0.04 - k * 0.018), Vector3(side * 0.12, -0.02, -1.0), Vector3(1, 0, 0), 0.26 - k * 0.03, 0.06 - k * 0.008, navy.lightened(k * 0.05), 0.04, "long")
	var m := MeshKit.finish(st)
	prop_mesh_cache[key] = m
	return m

# 구렁이: 등뼈 점들을 따라 단면 고리를 이어 한 덩어리 몸으로. 납작하고 넓적한 머리, 가는 목, 통통한 몸통,
# 끝으로 가늘어지는 꼬리. 등은 누런 올리브색에 검은 가로띠, 배는 크림빛 비늘판. 눈과 날름거리는 혀
const SNAKE_RINGS := 30
const SNAKE_LEN := 1.25
const SNAKE_R := 1.45   # 굵기 배율
func snake_radius(t: float) -> float:
	# t: 0 주둥이 끝 → 1 꼬리 끝
	if t < 0.025:
		return lerpf(0.006, 0.03, sqrt(t / 0.025))
	if t < 0.07:
		return lerpf(0.03, 0.046, (t - 0.02) / 0.05)    # 넓적한 머리
	if t < 0.1:
		return lerpf(0.046, 0.032, (t - 0.07) / 0.03)    # 목
	if t < 0.35:
		return lerpf(0.032, 0.05, (t - 0.1) / 0.25)
	if t < 0.6:
		return 0.05
	return lerpf(0.05, 0.004, pow((t - 0.6) / 0.4, 1.3))

func snake_mesh(spine: Array, sd: float) -> ArrayMesh:
	var st := MeshKit.begin()
	var n := spine.size()
	var olive := Color(0.5, 0.46, 0.24)
	var olive_lt := Color(0.66, 0.6, 0.32)
	var band := Color(0.16, 0.14, 0.08)
	var belly := Color(0.9, 0.84, 0.6)
	var head_c := Color(0.42, 0.38, 0.2)
	var rings := []
	var us := []
	var vs := []
	var prev_side := Vector3(1, 0, 0)
	for i in n:
		var p: Vector3 = spine[i]
		var fwd: Vector3 = ((spine[maxi(i - 1, 0)] as Vector3) - (spine[mini(i + 1, n - 1)] as Vector3))
		fwd = fwd.normalized() if fwd.length() > 0.0001 else Vector3(0, 0, 1)
		var side := fwd.cross(Vector3.UP)
		if side.length() < 0.2:
			side = prev_side   # 기둥을 오를 때(위를 볼 때)
		side = side.normalized()
		if side.dot(prev_side) < 0.0 and i > 0:
			side = -side
		prev_side = side
		var up := side.cross(fwd).normalized()
		if up.y < 0.0 and absf(fwd.y) < 0.7:
			up = -up
			side = -side
		var t := float(i) / float(n - 1)
		var r := snake_radius(t) * SNAKE_R
		var flat := 0.72 if t < 0.08 else 0.86   # 머리는 더 납작, 몸도 배가 조금 납작
		rings.append([p, r, r * flat])
		us.append(side)
		vs.append(up)
	# 고리마다 방향이 달라서 kit_loft 대신 여기서 직접 이어요
	var seg := 12
	var pts := []
	var cols := []
	for i in n:
		var t := float(i) / float(n - 1)
		var d := t * SNAKE_LEN
		var row := []
		var crow := []
		for k in seg + 1:
			var a := TAU * k / seg
			var c: Vector3 = rings[i][0]
			var off: Vector3 = (us[i] as Vector3) * cos(a) * float(rings[i][1]) + (vs[i] as Vector3) * sin(a) * float(rings[i][2])
			# 배는 납작하게
			if sin(a) < -0.3:
				off -= (vs[i] as Vector3) * (sin(a) + 0.3) * float(rings[i][2]) * 0.35
			row.append(c + off)
			var upv := sin(a)
			var col: Color
			if upv < -0.5:
				# 배 비늘판: 가로로 한 칸씩 살짝 진하게
				col = belly if (i % 2 == 0) else belly.darkened(0.08)
			elif t < 0.09:
				# 머리: 위는 짙고 입술 쪽은 밝게
				col = head_c if upv > -0.1 else olive_lt.lerp(belly, 0.5)
				if t > 0.055 and upv > 0.2:
					col = head_c.darkened(0.25)   # 뒤통수 무늬
			else:
				var bandv := sin(d * 34.0 + sd)
				var dorsal := olive.lerp(olive_lt, clampf(-upv * 1.2 + 0.2, 0.0, 1.0))
				col = band if (bandv > 0.62 and upv > -0.35) else dorsal
				# 비늘 결: 촘촘한 마름모 음영
				if sin(d * 160.0 + a * 6.0) > 0.7:
					col = col.darkened(0.12)
			crow.append(col)
		pts.append(row)
		cols.append(crow)
	for i in n - 1:
		for k in seg:
			MeshKit.quad(st, pts[i][k], pts[i + 1][k], pts[i + 1][k + 1], pts[i][k + 1], cols[i][k], cols[i + 1][k], cols[i + 1][k + 1], cols[i][k + 1])
	# 주둥이 끝 막기
	for k in seg:
		MeshKit.tri(st, rings[0][0], pts[0][k + 1], pts[0][k], cols[0][k], cols[0][k], cols[0][k])
	# 눈: 머리 양옆 위쪽, 노란 눈에 세로 동공
	var hi := 2
	var hc: Vector3 = rings[hi][0]
	var hu: Vector3 = us[hi]
	var hv: Vector3 = vs[hi]
	var hf: Vector3 = ((spine[0] as Vector3) - (spine[4] as Vector3)).normalized()
	for sx in [-1.0, 1.0]:
		var ep: Vector3 = hc + hu * sx * float(rings[hi][1]) * 0.82 + hv * float(rings[hi][2]) * 0.45
		var eb := Basis(hu, hv, hf)
		MeshKit.ball(st, ep, Vector3(0.0135, 0.0135, 0.0135), Color(0.85, 0.7, 0.2), 8, 6, eb)
		MeshKit.ball(st, ep + hu * sx * 0.011, Vector3(0.006, 0.013, 0.006), Color(0.05, 0.04, 0.03), 6, 4, eb)
		MeshKit.ball(st, ep + hu * sx * 0.014 + hv * 0.006, Vector3(0.003, 0.003, 0.003), Color(1, 1, 1), 4, 3)
	# 날름거리는 갈라진 혀
	var flick := sin(anim_t * 14.0 + sd)
	if flick > 0.2:
		var tip0: Vector3 = (spine[0] as Vector3) - hv * 0.006
		var tl := 0.07 * (flick - 0.2) / 0.8
		var mid: Vector3 = tip0 + hf * tl
		var tongue := Color(0.75, 0.12, 0.15)
		MeshKit.tube(st, tip0, mid, 0.003, 0.0025, tongue, 4)
		for sx in [-1.0, 1.0]:
			MeshKit.tube(st, mid, mid + hf * 0.018 + hu * sx * 0.01, 0.0025, 0.001, tongue, 4)
	return MeshKit.finish(st)

# 밥풀: 찰기 있는 쌀알 여러 톨이 서로 붙은 작은 덩이. 쌀알 하나하나가 길쭉한 낟알 모양(한쪽에 씨눈 자국)
# 반들반들 반투명한 흰빛. variant 마다 붙은 모양이 달라요
func rice_clump_mesh(variant: int) -> ArrayMesh:
	var key := "rice_clump%d" % variant
	if prop_mesh_cache.has(key):
		return prop_mesh_cache[key]
	var st := MeshKit.begin()
	var r := RandomNumberGenerator.new()
	r.seed = 77 + variant * 13
	# 낟알들이 비슷한 방향으로 나란히 기대어 붙은 작은 덩이 (두 층)
	var main_dir := Vector3(r.randf_range(-1, 1), r.randf_range(-0.4, 0.4), r.randf_range(-1, 1)).normalized()
	var across := main_dir.cross(Vector3.UP).normalized()
	var count := 5 + variant % 3
	for g in count:
		var row := g % 3
		var layer := g / 3
		var c := across * (float(row) - 1.0) * 0.027 + Vector3.UP * float(layer) * 0.022 \
			+ main_dir * r.randf_range(-0.02, 0.02) + across * float(layer) * 0.013
		var dir := main_dir.rotated(Vector3.UP, r.randf_range(-0.6, 0.6)).rotated(across, r.randf_range(-0.35, 0.35)).normalized()
		var side := dir.cross(Vector3.UP).normalized()
		var up := side.cross(dir).normalized()
		# 낟알마다 길이 축으로 조금씩 돌려서 납작한 면이 제각각
		var roll := r.randf_range(-0.8, 0.8)
		var side2 := side.rotated(dir, roll)
		var up2 := up.rotated(dir, roll)
		rice_grain(st, c, dir, side2, up2, r.randf_range(0.92, 1.08), r.randf())
	var m := MeshKit.finish(st)
	prop_mesh_cache[key] = m
	return m

func rice_grain(st: SurfaceTool, c: Vector3, dir: Vector3, side: Vector3, up: Vector3, size: float, shade: float) -> void:
	var L := 0.064 * size      # 낟알 길이 (짧고 통통한 멥쌀 밥알)
	var W := 0.027 * size
	var H := 0.022 * size
	var white := Color(0.93, 0.92, 0.88).lerp(Color(0.88, 0.87, 0.8), shade * 0.6)
	var glow := Color(1.0, 1.0, 0.98)
	var rings := []
	var nr := 15
	for i in nr:
		var t := float(i) / float(nr - 1)
		# 끝은 둥글고 가운데가 통통한 낟알
		# 끝이 뭉툭하게 둥근 통통한 낟알 (초타원 단면 윤곽)
		var e := absf(2.0 * t - 1.0)
		var prof := pow(maxf(1.0 - pow(e, 2.6), 0.0), 0.42)
		prof = maxf(prof, 0.12)
		# 살짝 휜 낟알
		rings.append([c + dir * (t - 0.5) * L + up * sin(PI * t) * L * 0.06, W * 0.5 * prof, H * 0.5 * prof])
	var colf := func(t: float, a: float) -> Color:
		# 가장자리는 살짝 어둡고 투명한 듯, 등은 반들반들 밝게
		var col := white.lerp(glow, clampf(sin(a) * 0.7, 0.0, 1.0)).darkened(0.16 * (1.0 - absf(sin(a))))
		# 끝은 조금 더 투명한 회백색
		if t < 0.1 or t > 0.9:
			col = col.lerp(Color(0.84, 0.85, 0.82), 0.4)
		# 씨눈 자국: 한쪽 끝 옆에 살짝 오목한 크림색
		if t > 0.1 and t < 0.24 and cos(a) > 0.55:
			col = Color(0.9, 0.87, 0.76)
		# 길이 방향 옅은 골
		if absf(cos(a)) < 0.12:
			col = col.darkened(0.05)
		return col
	var radf := func(t: float, a: float) -> float:
		var m := 1.0
		if t > 0.1 and t < 0.24 and cos(a) > 0.55:
			m = 0.86   # 씨눈 자리 오목
		return m
	kit_loft(st, rings, side, up, 14, colf, radf)

# 밥주걱: 넓적한 타원 머리가 살짝 오목하고 손잡이로 가늘어지는 나무 주걱 (나뭇결 무늬, 밥풀 몇 톨 묻음)
func paddle_mesh() -> ArrayMesh:
	if prop_mesh_cache.has("paddle"):
		return prop_mesh_cache["paddle"]
	var st := MeshKit.begin()
	# [y, 가운데 z, 가로 반지름, 두께 반지름]
	var ctrl := [
		[0.2, 0.0, 0.01, 0.006],
		[0.18, 0.004, 0.085, 0.012],
		[0.12, 0.008, 0.11, 0.014],
		[0.04, 0.006, 0.105, 0.015],
		[-0.03, 0.002, 0.07, 0.015],
		[-0.07, 0.0, 0.035, 0.016],
		[-0.12, 0.0, 0.026, 0.017],
		[-0.38, 0.0, 0.024, 0.018],
		[-0.41, 0.0, 0.02, 0.016],
		[-0.42, 0.0, 0.004, 0.004],
	]
	var rings := smooth_rings(ctrl, 4, false)
	var wood := Color(0.82, 0.63, 0.38)
	var grain := Color(0.66, 0.46, 0.25)
	var colf := func(t: float, a: float) -> Color:
		var y := lerpf(0.2, -0.42, t)
		var gx := cos(a)
		var col := wood.lerp(wood.lightened(0.12), clampf(sin(a), 0.0, 1.0))
		if sin(y * 70.0 + gx * 9.0 + sin(y * 15.0) * 2.0) > 0.75:
			col = grain
		if y < -0.36:
			col = col.darkened(0.15)   # 손때 묻은 손잡이 끝
		return col
	# 앞면이 살짝 오목하게 (가운데를 조금 들여요)
	var radf := func(t: float, a: float) -> float:
		if t < 0.45 and sin(a) > 0.5:
			return 0.55
		return 1.0
	kit_loft(st, rings, Vector3(1, 0, 0), Vector3(0, 0, 1), 16, colf, radf)
	# 머리에 붙은 밥풀 몇 톨
	var r := RandomNumberGenerator.new()
	r.seed = 9
	for g in 4:
		var c := Vector3(r.randf_range(-0.06, 0.06), r.randf_range(0.03, 0.15), 0.014)
		var dir := Vector3(r.randf_range(-1, 1), r.randf_range(-1, 1), 0.2).normalized()
		var side := dir.cross(Vector3(0, 0, 1)).normalized()
		rice_grain(st, c, dir, side, side.cross(dir).normalized(), 0.8, r.randf())
	var m := MeshKit.finish(st)
	prop_mesh_cache["paddle"] = m
	return m

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
			# 한 줄로 이어진 매끈한 몸 (매 프레임 등뼈를 따라 다시 지어요)
			var body := MeshInstance3D.new()
			body.material_override = kit_material()
			n.add_child(body)
			n.set_meta("body", body)
			n.set_meta("from", at)
			n.set_meta("seed", rng.randf() * TAU)
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
			var ground_back := (from - base) * Vector3(1, 0, 1)
			ground_back = ground_back.normalized() if ground_back.length() > 0.01 else Vector3(0, 0, 1)
			var climbed := maxf(head.y - base.y, 0.0)
			var gside := ground_back.cross(Vector3.UP).normalized()
			var sd: float = n.get_meta("seed", 0.0)
			# 등뼈: 주둥이 끝에서 꼬리 끝까지 0.9m. 땅에선 S자로 꿈틀, 기둥을 오를 땐 위는 기둥을 따라 곧게
			var spine := []
			for i in SNAKE_RINGS:
				var d := SNAKE_LEN * float(i) / float(SNAKE_RINGS - 1)
				var p: Vector3
				var wig := sin(anim_t * 9.0 + sd - d * 9.0) * 0.09 * clampf(d / 0.2, 0.0, 1.0)
				if d < climbed:
					p = Vector3(head.x, head.y - d, head.z) + Vector3(1, 0, 0) * wig * 0.35
				else:
					var g := d - climbed
					var start := head if climbed <= 0.0 else base
					p = start + ground_back * g + gside * wig
				spine.append(p - n.global_position + Vector3(0, 0.06, 0))
			n.get_meta("body").mesh = snake_mesh(spine, sd)
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
	var n := Node3D.new()
	world_node(n)
	if bad:
		kit_instance(n, paddle_mesh(), Vector3(0, 0.08, 0)).scale = Vector3.ONE * 1.25
	else:
		var mi := kit_instance(n, rice_clump_mesh(rng.randi() % 4))
		mi.scale = Vector3.ONE * 2.3
		mi.rotation = Vector3(rng.randf() * TAU, rng.randf() * TAU, 0)
	return n

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

# ---------- 미니게임 단계 (2026-11-28: 이야기 미니게임을 2~3단계로 길게) ----------
# cfg "rounds": [{바꿀 값...}, ...] 를 주면 한 단계를 이길 때마다 값을 바꿔 다음 단계를 이어서 해요.
# 남은 기회는 단계를 넘어 이어지고, 지면 처음 단계부터 다시. 별점은 모든 단계를 합쳐서 매겨요.
var mg_round := 0
var mg_round_total := 1
var mg_round_base: Dictionary = {}
var mg_hold := 0.0
var mg_carry_lives := -1
var mg_carry_perfect := true
var mg_first_lives := 3

func round_cfg(i: int) -> Dictionary:
	var c := mg_round_base.duplicate()
	var rounds: Array = mg_round_base.get("rounds", [])
	if i > 0 and i - 1 < rounds.size():
		var o: Dictionary = rounds[i - 1]
		for k in o:
			c[k] = o[k]
	c["_round"] = i
	return c

# 단계 사이 안내: 화면 가운데 두루마리 띠에 "N단계 성공!"과 다음 단계 설명 (줄바꿈되어 화면 안에)
func round_banner(head: String, text: String, hold: float) -> void:
	var vs := get_viewport().get_visible_rect().size
	var pw := minf(vs.x * 0.86, font_size * 22.0)
	var pad := font_size * 0.7
	var inner := pw - pad * 2.0
	var hs := int(font_size * 1.3)
	var ts := int(font_size * 0.95)
	var hh: float = font.get_multiline_string_size(head, HORIZONTAL_ALIGNMENT_CENTER, inner, hs).y
	var th: float = font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, inner, ts).y
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", make_round(Color(1.0, 0.96, 0.86, 0.94), font_size * 0.5))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size = Vector2(pw, pad * 2.0 + hh + th + font_size * 0.3)
	panel.position = Vector2((vs.x - pw) / 2.0, vs.y * 0.42 - panel.size.y / 2.0)
	fx_layer.add_child(panel)
	var y := pad
	for row in [[head, hs, Color(0.78, 0.4, 0.08), hh], [text, ts, INK, th]]:
		var lb := Label.new()
		lb.text = row[0]
		lb.add_theme_font_override("font", font)
		lb.add_theme_font_size_override("font_size", row[1])
		lb.add_theme_color_override("font_color", row[2])
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lb.position = Vector2(pad, y)
		lb.size = Vector2(inner, row[3])
		panel.add_child(lb)
		y += float(row[3]) + font_size * 0.3
	panel.pivot_offset = panel.size / 2.0
	pop(panel, 1.1)
	var tw := panel.create_tween()
	tw.tween_interval(maxf(hold - 0.35, 0.3))
	tw.tween_property(panel, "modulate:a", 0.0, 0.35)
	tw.tween_callback(panel.queue_free)

func next_round() -> void:
	mg_carry_lives = maxi(mg_lives, 1)
	mg_carry_perfect = mg_perfect
	mg_round += 1
	var t := mg_type
	var d := mg_done
	# 이번 단계를 치우고 (카메라와 장면은 같은 프레임에 다시 차려요) 다음 단계를 차려요
	mg_active = false
	if mg_world:
		world_game_end()
	for child in mg_stage.get_children():
		# 지울 그림판은 바로 숨겨요 (이번 프레임에 새 그림판 대신 그려지지 않게)
		if child is CanvasItem:
			(child as CanvasItem).visible = false
		child.queue_free()
	mg_items = []
	start_game(t, round_cfg(mg_round), d)

func start_game(type: String, cfg: Dictionary, done: Callable) -> void:
	if not cfg.has("_round"):
		mg_round = 0
		mg_round_base = cfg
		mg_round_total = 1 + (cfg.get("rounds", []) as Array).size()
		mg_carry_lives = -1
		mg_carry_perfect = true
	mg_hold = 0.0
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
	mg_title.text = cfg["title"] if mg_round_total <= 1 else tr("[%d/%d] %s") % [mg_round + 1, mg_round_total, cfg["title"]]
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
	if mg_round == 0:
		mg_lives_start = mg_lives
		mg_first_lives = mg_lives
	else:
		mg_lives_start = mg_first_lives
		mg_lives = mg_carry_lives
		mg_perfect = mg_carry_perfect
		mg_hold = 2.0
		sfx("good")
		round_banner(tr("%d단계 성공!") % mg_round, String(cfg.get("round_text", tr("다음 단계!"))), mg_hold)
	pop(mg_title, 1.15)

func end_game(ok: bool) -> void:
	if ok and mg_active and mg_round + 1 < mg_round_total:
		next_round()
		return
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
	if mg_hold > 0.0:
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
	if mg_hold > 0.0:
		# 다음 단계로 넘어가는 잠깐 (안내 글을 읽을 시간)
		mg_hold -= delta
		if mg_world:
			scene_update(0.0)
		return
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
const FONT_B64 := "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"
