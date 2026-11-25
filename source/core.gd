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
		elif book_village == "ch2":
			book_footer.text = tr("약초꾼 할아버지가 모자란 약초를 알려 줘요.\n종류마다 3번씩, 다 모으면 30냥!")
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
	return tr("이 마을 약초를 다 모았다! 엽전 30냥.")

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
