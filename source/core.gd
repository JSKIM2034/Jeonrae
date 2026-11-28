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
			var want := int(overall_progress() * 9.0)
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

# 여러 단계를 통틀어 얼마나 왔는지 (0~1). 나무 오르기·동아줄처럼 단계가 바뀌어도 이어서 오르는 놀이에 써요
func overall_progress() -> float:
	var goal := maxf(float(mg_cfg.get("goal", 1)), 0.001)
	var here := clampf(float(mg_count) / goal, 0.0, 1.0)
	if mg_type == "circle":
		here = clampf(mg_progress, 0.0, 1.0)
	return (float(mg_round) + here) / float(maxi(mg_round_total, 1))

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
