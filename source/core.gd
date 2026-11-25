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
		"coins": 10, "gift": ""},
	{"id": "host_fish", "npc": "host", "region": "ch2", "who": "잔칫집 영감", "need": [["fish", "bungeo", 2], ["fish", "ingeo", 1]],
		"ask": ["자네 덕에 고갯길이 다시 조용해졌으니 동네 잔치를 한 번 더 열까 하네.", "그런데 잔치 국을 끓일 물고기가 없구먼. 이 고갯길 웅덩이 물고기는 너무 작아.", "흥부네 마을 남쪽 연못에서 붕어 두 마리와 잉어 한 마리만 구해다 주겠나?"],
		"thanks": ["옳지, 붕어가 통통하고 잉어도 실하구먼!", "이 정도면 온 동네 사람들이 한 그릇씩 먹고도 남겠네.", "떡집 할머니가 쪄 둔 떡을 광주리째 주겠네. 집에 가져가게나."],
		"coins": 20, "gift": "rice_cake_basket"},
	{"id": "haenyeo_ssuk", "npc": "haenyeo", "region": "ch3", "who": "해녀", "need": [["herb", "ssuk", 3]],
		"ask": ["물질하고 나오면 몸이 꽁꽁 얼어서 말이야.", "쑥뜸을 뜨면 금방 따뜻해지는데, 이 바닷가엔 쑥이 잘 안 자라.", "흥부네 마을 길가에 쑥이 많다던데, 쑥 세 줌만 뜯어다 줄래?"],
		"thanks": ["어머, 향긋한 쑥이네! 벌써 몸이 따뜻해지는 것 같아.", "고마워. 이건 내가 물질하다 주운 진주야. 작지만 참 곱지?"],
		"coins": 15, "gift": "pearl"},
	{"id": "yongwang_yeongji", "npc": "yongwang", "region": "ch3", "who": "용왕", "need": [["herb", "yeongji", 1]],
		"ask": ["뭍의 아이여, 덕분에 병은 나았소만 아직 기운이 없구려.", "뭍의 산에는 영지라는 귀한 버섯이 있다지? 몸보신에 그만이라 들었소.", "오누이 고갯길 그루터기에 비 오거나 안개 낀 날 돋는다 하오. 하나만 구해 주겠소?"],
		"thanks": ["오오, 이것이 영지로구려! 빛깔이 꼭 옻칠한 것 같소.", "벌써 기운이 솟는구려. 이번엔 욕심이 아니라 고마움으로 주는 것이오.", "용궁 앞뜰에서 자란 붉은 산호 가지라오. 뭍에서도 오래 고울 게요."],
		"coins": 30, "gift": "coral"},
	{"id": "granny_sancheoneo", "npc": "storyteller", "region": "home", "who": "이야기꾼 할머니", "need": [["fish", "sancheoneo", 1]],
		"ask": ["얘야, 할미가 젊었을 적 이야기 하나 해 줄까?", "고갯길 바위 웅덩이에 산천어라는 물고기가 살았는데, 몸에 고운 점무늬가 있었지.", "그걸 다시 한번 보면 잊어버린 옛이야기 하나가 떠오를 것 같구나. 맑은 날 잘 나온단다."],
		"thanks": ["아이고, 산천어로구나... 이 점무늬, 그대로야.", "옛날 옛적, 할미가 너만 했을 때 고갯길 웅덩이에서 한 소년을 만났단다. 그 아이는 웅덩이 물고기들에게 이름을 하나씩 붙여 주었지.", "그러고는 '이야기는 누가 들려줘야 살아 있는 거야' 하고 웃었단다. 그 말 때문에 할미는 평생 이야기꾼이 되었지.", "고맙다. 오래 잊었던 이야기를 되찾았구나. 이건 그때 그 웅덩이 가에서 주운 매끈한 돌이란다."],
		"coins": 10, "gift": "pool_stone"},
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
	req_state = (cf.get_value("common", "requests", {}) as Dictionary).duplicate()
	req_given = (cf.get_value("common", "given", {}) as Dictionary).duplicate()
	req_gifts = (cf.get_value("common", "gifts", []) as Array).duplicate()
	good_rod = req_gifts.has("good_rod")

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
