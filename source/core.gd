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
