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
		ask("", tr("어디부터 다시 할까요?\n- 이 장만: 지금 장 이야기만 처음으로 (엽전·물건·다른 장은 그대로)\n- 모든 장: 1장부터 새로 (도감, 엔딩 기록, 설정은 남아요)"), [tr("이 장만 처음부터"), tr("모든 장 처음부터"), tr("그만둘래요")], func(i: int):
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
