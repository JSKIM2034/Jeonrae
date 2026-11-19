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
const ZOOM_MIN := 0.5
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
				ci.draw_string(font, Vector2(gx - 26, ty - 44), "흥부" if key == "saw" else "첨지", HORIZONTAL_ALIGNMENT_LEFT, -1, int(font_size * 0.5), INK)
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
		"name": "돌이",
		"ask": [["돌이", "으아앙! 놀부 아저씨가 내 엿을 뺏어 먹었어!"], ["돌이", "엿 먹고 싶어... 장터 아저씨가 파는데..."]],
		"wait": "훌쩍... 엿은 장터 아저씨가 팔아.",
		"done": "우와, 엿이다! 고마워! 이제 안 울게.",
	},
	"suni": {
		"name": "순이 엄마",
		"ask": [["순이 엄마", "놀부가 빨랫줄을 끊어 놔서 빨래가 개울가에 다 흩어졌지 뭐니."], ["순이 엄마", "개울 따라 세 장만 찾아 주겠니?"]],
		"wait": "빨래는 개울가를 따라 흩어졌단다.",
		"done": "아이고, 다 찾아 왔구나! 고맙다.",
	},
	"kim": {
		"name": "김 서방",
		"ask": [["김 서방", "놀부가 다 익은 호박마다 말뚝을 박아 놨지 뭐냐!"], ["김 서방", "말뚝이 보이면 재빨리 눌러서 뽑아 다오."]],
		"fail": "말뚝이 너무 깊이 들어갔구나. 다시 해 보자.",
		"done": "호박이 살았다! 고맙다, 얘야.",
		"game": "tap",
		"cfg": {"title": "호박에 박힌 말뚝을\n사라지기 전에 눌러 뽑아요", "goal": 8, "interval": 0.9, "life": 1.9, "target": "말뚝", "center": "호박", "color": Color(0.95, 0.6, 0.2), "art": "world", "world": true, "scene": "kim"},
	},
	"ong": {
		"name": "옹기 할멈",
		"ask": [["옹기 할멈", "놀부가 지나가다 장독을 발로 차서 금이 갔단다."], ["옹기 할멈", "진흙을 살살 돌려 발라 주겠니? 세게 하면 또 깨진단다."]],
		"fail": "에구, 금이 더 갔구나. 다시 살살 해 보자.",
		"done": "감쪽같구나! 장맛을 지켰다.",
		"game": "circle",
		"cfg": {"title": "깨진 장독 둘레에\n진흙을 살살 돌려 발라요", "label": "장독", "turns": 5.0, "max_speed": 10.0, "warn": "너무 세게 바르면 깨져요!", "color": Color(0.5, 0.33, 0.2), "art": "world", "world": true, "scene": "ong", "trail": Color(0.66, 0.48, 0.3)},
	},
	"park": {
		"name": "박 첨지",
		"ask": [["박 첨지", "놀부가 제 논에만 물을 대려고 우리 물꼬를 막아 버렸어!"], ["박 첨지", "나랑 박자 맞춰 삽질 좀 해 다오."]],
		"fail": "박자가 안 맞아 삽이 엇나갔구나. 다시 해 보자.",
		"done": "물이 콸콸 들어온다! 올해 농사는 살았다.",
		"game": "follow",
		"cfg": {"art": "world", "world": true, "scene": "ditch", "title": "박 첨지와 박자 맞춰 삽질!\n아래 손잡이를 좌우로 따라가세요", "slow": 2.0, "tol": 0.4, "goal": 5.0, "patience": 4.0, "color": Color(0.4, 0.6, 0.85)},
	},
}


# ---------- 시작 ----------

func _ready() -> void:
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
		lab2.text = "지\n하\n여\n장\n군" if female else "천\n하\n대\n장\n군"
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
	lab.text = "지\n하\n여\n장\n군" if female else "천\n하\n대\n장\n군"
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

func set_time_of_day(t: float) -> void:
	if sun_light == null:
		return
	t = clampf(t, 0.0, 1.0)
	time_of_day = t
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
	for bn in RIG_BONES:
		var i := skel.find_bone(bn)
		if i >= 0:
			bones[bn] = [i, skel.get_bone_rest(i).basis.get_rotation_quaternion(), skel.get_bone_global_rest(i).basis.orthonormalized().inverse(), skel.get_bone_global_rest(i).basis.y.normalized()]
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	body.set_meta("skel", skel)
	body.set_meta("bones", bones)
	return body

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
		var down := -sx * lerpf(lerpf(0.44, 0.52, run * amt), 0.25, a)
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

func make_person_model(parent: Node3D, kind: String, c: Color) -> Node3D:
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
	{"name": "쑥", "hint": "마을 길가", "reward": 5, "spots": [Vector3(-5.6, 0, 16.5), Vector3(8.5, 0, 24.5)]},
	{"name": "냉이", "hint": "논 근처", "reward": 5, "spots": [Vector3(16.5, 0, 35.8), Vector3(31.2, 0, 36.2)]},
	{"name": "달래", "hint": "개울가", "reward": 6, "spots": [Vector3(-27.0, 0, -13.1), Vector3(12.0, 0, -13.2)]},
	{"name": "도라지", "hint": "개울 건너 숲", "reward": 8, "spots": [Vector3(-14.0, 0, -27.0), Vector3(10.0, 0, -26.0)]},
	{"name": "더덕", "hint": "깊은 숲 속", "reward": 10, "spots": [Vector3(-33.0, 0, -31.0), Vector3(3.0, 0, -37.0)]},
	{"name": "산삼", "hint": "아무도 안 가는 숲 구석", "reward": 25, "spots": [Vector3(-36.5, 0, -36.5), Vector3(37.0, 0, -31.5)]},
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
	book_button.text = "도감"
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
	for tab in [["fish", "물고기"], ["herb", "약초"], ["story", "이야기"]]:
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
	back.text = "목록으로"
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
	close.text = "닫기"
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
		book_title.text = "물고기 도감 %d/%d" % [fish_kinds_found(), FISH.size()]
		if fish_kinds_found() >= FISH.size():
			book_footer.text = "다 모았어요! 강태공 할아버지도 깜짝 놀랐어요."
		else:
			book_footer.text = "남쪽 연못 나루터에서 낚시해요.\n다 모으면 50냥!"
	elif tab == "story":
		book_title.text = "이야기 조각 %d/%d" % [story_count(), STORY.size()]
		for i in STORY.size():
			var sb: Button = story_buttons[i]
			if story_read[i]:
				sb.text = "  %d. %s" % [i + 1, STORY[i]["title"]]
				skin_button(sb, make_round(Color(1.0, 0.95, 0.8), font_size * 0.3), INK, 0.8)
			else:
				sb.text = "  %d. ???   (%s)" % [i + 1, STORY[i]["hint"]]
				skin_button(sb, make_round(Color(0.88, 0.84, 0.76), font_size * 0.3), Color(0.5, 0.45, 0.4), 0.72)
		if story_count() >= STORY.size():
			book_footer.text = "일곱 조각이 하나로 이어졌어요. 놀부는 어떤 형이었을까요?"
		else:
			book_footer.text = "찾은 조각을 누르면 다시 읽을 수 있어요.\n산신령에게서 받는 조각도 있어요."
	else:
		book_title.text = "약초 도감 %d/%d" % [herb_kinds_done(), HERBS.size()]
		if herb_kinds_done() >= HERBS.size():
			book_footer.text = "다 모았어요! 마을 최고의 약초꾼이에요."
		else:
			book_footer.text = "종류마다 3번씩 캐면 도감에 올라가요.\n캔 자리는 3분 뒤 다시 자라요. 다 모으면 40냥!"
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
	var rarity := ["흔함", "흔함", "보통", "보통", "드묾", "아주 드묾"]
	for i in 6:
		var cc := Vector2(cw * (i % 2) + cw / 2.0, ch * (i / 2) + ch / 2.0)
		var got := false
		var name_t := "???"
		var sub := ""
		if book_tab == "fish":
			got = int(fish_caught[i]) > 0
			if got:
				name_t = FISH[i]["name"]
				sub = "%d마리 낚음 | %d냥" % [fish_caught[i], FISH[i]["pay"]]
			else:
				sub = rarity[i]
		else:
			got = int(herb_counts[i]) >= HERB_NEED
			if int(herb_counts[i]) > 0:
				name_t = HERBS[i]["name"]
			sub = "%d/%d  %s" % [mini(int(herb_counts[i]), HERB_NEED), HERB_NEED, HERBS[i]["hint"] if not got else "완성!"]
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

func save_controls() -> void:
	var cf := ConfigFile.new()
	cf.load("user://save.cfg")
	cf.set_value("ui", "left_handed", left_handed)
	cf.set_value("ui", "walk_hint_seen", walk_hint_seen)
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
	settings_button.text = "설정"
	skin_button(settings_button, make_paper(font_size * 0.4), INK, 0.8)
	settings_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(settings_button)
	ui_layer.move_child(settings_button, book_button.get_index())
	place(settings_button, 0.57, 0.075, 0.76, 0.135)
	settings_overlay = make_overlay(0.55)
	var page := Panel.new()
	page.add_theme_stylebox_override("panel", make_paper(font_size * 0.6))
	settings_overlay.add_child(page)
	place(page, 0.06, 0.2, 0.94, 0.8)
	var title := add_label(page, "설정", 1.0, 0.05, 0.04, 0.95, 0.17)
	title.add_theme_color_override("font_color", INK)
	title.add_theme_constant_override("outline_size", 0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub := add_label(page, "점프 버튼 위치", 0.8, 0.05, 0.13, 0.95, 0.21)
	sub.add_theme_color_override("font_color", Color(0.45, 0.35, 0.25))
	sub.add_theme_constant_override("outline_size", 0)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var opts := [[false, "오른손잡이\n(점프 오른쪽)"], [true, "왼손잡이\n(점프 왼쪽)"]]
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
	again.text = "걷기 안내 다시 보기"
	skin_button(again, make_round(Color(0.9, 0.84, 0.7), font_size * 0.35), INK, 0.8)
	page.add_child(again)
	place(again, 0.15, 0.66, 0.85, 0.76)
	var snd := add_label(page, "소리", 0.8, 0.05, 0.43, 0.95, 0.5)
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
	close.text = "닫기"
	skin_button(close, make_round(Color(0.75, 0.45, 0.25), font_size * 0.4), Color(1, 1, 1), 0.85)
	page.add_child(close)
	place(close, 0.3, 0.82, 0.7, 0.94)
	close.pressed.connect(close_settings)
	refresh_hand_buttons()

var music_btn: Button
var sfx_btn: Button

func refresh_hand_buttons() -> void:
	if music_btn != null:
		music_btn.text = "배경음 켜짐" if music_on else "배경음 꺼짐"
		skin_button(music_btn, make_round(Color(0.95, 0.72, 0.3) if music_on else Color(0.85, 0.8, 0.72), font_size * 0.35), INK, 0.78)
		sfx_btn.text = "효과음 켜짐" if sfx_on else "효과음 꺼짐"
		skin_button(sfx_btn, make_round(Color(0.95, 0.72, 0.3) if sfx_on else Color(0.85, 0.8, 0.72), font_size * 0.35), INK, 0.78)
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
	var msg := "화면 아무 곳이나 누른 채\n밀면 그쪽으로 걸어요"
	var fs := int(font_size * 0.95)
	var y := c.y + r * 1.25
	for line in msg.split("\n"):
		ci.draw_string_outline(font, Vector2(0, y + fs), line, HORIZONTAL_ALIGNMENT_CENTER, sz.x, fs, 10, Color(0.25, 0.15, 0.08))
		ci.draw_string(font, Vector2(0, y + fs), line, HORIZONTAL_ALIGNMENT_CENTER, sz.x, fs, Color(1, 1, 1))
		y += fs * 1.3

# ---------- 이야기 조각 7개: 놀부는 왜 놀부가 되었을까 ----------

var STORY := [
	{"title": "담벼락의 키 재기", "hint": "놀부네 담장 근처", "text": "놀부네 담장 뒤편에는 희미한 금이 두 줄 그어져 있어요.\n어린 형제가 해마다 키를 재며 새긴 자국이에요.\n놀부의 금은 언제나 흥부보다 손가락 한 마디 높았어요.\n“형은 동생보다 커야 해. 그래야 지켜 줄 수 있으니까.”"},
	{"title": "첫 박씨", "hint": "서쪽 개울가", "text": "어느 봄, 아버지는 형제에게 박씨를 하나씩 주었어요.\n놀부의 박은 장맛비에 썩고, 흥부의 박만 주렁주렁 열렸어요.\n아버지가 흥부의 머리를 쓰다듬던 날 밤,\n놀부는 처음으로 몰래 이불을 덮고 울었어요."},
	{"title": "흉년의 겨울", "hint": "개울 건너 깊은 숲", "text": "큰 흉년이 든 겨울, 아버지가 세상을 떠났어요.\n굶어서 우는 동생들을 보며 열다섯 살 놀부는 맹세했어요.\n“다시는 우리 집에 배고픈 사람이 없게 할 테야.”\n그날부터 놀부는 곳간 열쇠를 꼭 쥐고 잠들었어요."},
	{"title": "높아진 대문", "hint": "마을 남서쪽 집들 근처", "text": "놀부가 부자가 되자 사람들이 줄지어 찾아왔어요.\n빌려 간 쌀은 돌아오지 않았고, 고맙다는 말도 없었어요.\n놀부는 대문을 한 자, 또 한 자 높이 쌓았어요.\n“베풀면 바보가 되는 거야.” 놀부는 그렇게 믿기로 했어요."},
	{"title": "대문 밖의 쌀자루", "hint": "남동쪽 논 근처", "text": "흥부네가 쫓겨나던 날, 아무도 모르게\n놀부네 대문 밖에 쌀자루 하나가 놓여 있었어요.\n흥부는 이웃이 두고 간 줄 알았지요.\n자루를 묶은 매듭은, 놀부만 묶을 줄 아는 매듭이었어요."},
	{"title": "제비가 본 것", "hint": "점프해야 닿는 큰 바위 위", "text": "강남으로 떠나기 전, 제비는 이 바위에서 쉬어 갔어요.\n그리고 보았어요. 밤마다 놀부가 담장에 기대어\n흥부네 초가 굴뚝 연기를 오래 바라보다\n한숨을 쉬고 돌아서는 것을요."},
	{"title": "산신령의 말", "hint": "숲속 연못의 산신령", "text": "“욕심은 두려움에서 자라느니라.\n놀부가 움켜쥔 것은 재물이 아니라\n다시는 굶지 않겠다던 어린 날의 약속이란다.\n그 마음을 알아주는 이가 있다면, 높은 대문도 열리느니라.”"},
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
		ci.draw_string(font, Vector2(0, y - 46), "지금!" if inz else "", HORIZONTAL_ALIGNMENT_CENTER, w2, int(font_size * 0.9), Color(1, 1, 0.85))
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
			ci.draw_string(font, Vector2(w2 * 0.1, y2 - 18), "흔들림", HORIZONTAL_ALIGNMENT_LEFT, -1, int(font_size * 0.6), Color(1, 1, 1))
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
			ci.draw_string(font, Vector2(gx - 26, ty - 44), "흥부" if w.get("scene", "") == "saw" else "첨지", HORIZONTAL_ALIGNMENT_LEFT, -1, int(font_size * 0.5), Color(1, 1, 1))
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
			float_text("퍽!", cam.unproject_position(at), Color(1, 0.95, 0.7), 1.3)
		"kim":
			sfx("pop", 0.8)
			chips3d(at)
			float_text("쏙!", cam.unproject_position(at), Color(1, 0.95, 0.7), 1.3)
		"sparrow":
			sfx("chirp", rng.randf_range(0.9, 1.2))
			burst3d(at + Vector3(0, 0.2, 0), Color(0.75, 0.55, 0.35), 10)
			float_text("훠이!", cam.unproject_position(at), Color(1, 0.95, 0.7), 1.2)
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
			float_text("둥지가 위험해요!", cam.unproject_position(at), Color(1, 0.55, 0.45), 1.0)
		"kim":
			float_text("말뚝이 깊이 박혔어요!", cam.unproject_position(at), Color(1, 0.55, 0.45), 1.0)
		"sparrow":
			float_text("벼를 쪼아 먹었어요!", cam.unproject_position(at), Color(1, 0.55, 0.45), 1.0)
	var tw := n.create_tween()
	tw.tween_property(n, "scale", Vector3(0.01, 0.01, 0.01), 0.25)
	tw.tween_callback(n.queue_free)

func scene_update(delta: float) -> void:
	if not w.has("scene"):
		return
	var scene: String = w["scene"]
	w["swing"] = maxf(0.0, float(w.get("swing", 0.0)) - delta * 4.0)
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
		"snake", "kim", "sparrow":
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
		"rice":
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
					var bad: bool = it[1]
					var n: Node3D
					if bad:
						n = blob_node([[Vector3.ZERO, Vector3(0.22, 0.34, 0.06), Color(0.85, 0.66, 0.4)], [Vector3(0, -0.3, 0), Vector3(0.07, 0.36, 0.05), Color(0.7, 0.5, 0.3)]])
					else:
						n = blob_node([[Vector3.ZERO, Vector3(0.2, 0.17, 0.2), Color(1, 1, 0.97)], [Vector3(0.06, 0.06, 0.03), Vector3(0.1, 0.08, 0.1), Color(1, 1, 1)]])
					items[key] = n
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
				var gpt := ro + rd * (-ro.y / rd.y)
				var lim: Vector3 = w["center"]
				gpt.x = clampf(gpt.x, lim.x - 2.4, lim.x + 2.4)
				player.position = player.position.lerp(Vector3(gpt.x, player.position.y, lim.z), 0.35)
			bowl.global_position = player.position + Vector3(0, 2.2, 0.15)
			mg_cfg["basket_px"] = cam.unproject_position(bowl.global_position).y
			mg_cfg["spawn_px"] = maxf(h * 0.12, float(mg_cfg["basket_px"]) - h * 0.38)
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
	{"name": "피라미", "pay": 3, "w": 30, "hard": 0.1, "col": Color(0.78, 0.84, 0.9), "len": 0.85, "thin": 0.34},
	{"name": "붕어", "pay": 4, "w": 28, "hard": 0.25, "col": Color(0.72, 0.64, 0.42), "len": 1.0, "thin": 0.48},
	{"name": "미꾸라지", "pay": 6, "w": 16, "hard": 0.5, "col": Color(0.58, 0.5, 0.32), "len": 1.5, "thin": 0.2},
	{"name": "잉어", "pay": 8, "w": 14, "hard": 0.45, "col": Color(0.92, 0.58, 0.3), "len": 1.2, "thin": 0.44},
	{"name": "메기", "pay": 12, "w": 9, "hard": 0.7, "col": Color(0.38, 0.38, 0.34), "len": 1.35, "thin": 0.36},
	{"name": "금빛 잉어", "pay": 30, "w": 3, "hard": 0.9, "col": Color(1.0, 0.8, 0.22), "len": 1.2, "thin": 0.44},
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

func add_ridge_ring(r0: float, depth: float, hmin: float, hmax: float, low: Color, high: Color, seed_v: int, center: Vector3 = Vector3.ZERO) -> void:
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
		var ang := float(i) / n * TAU
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

	turn_button = add_hud_button("돌리기", 0.03, 0.25, on_turn)
	place(turn_button, 0.03, 0.075, 0.16, 0.135)
	turn_button.text = ""
	var icon := Control.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	turn_button.add_child(icon)
	place(icon, 0, 0, 1, 1)
	icon.draw.connect(func(): draw_turn_icon(icon))
	action_button = add_hud_button("", 0.28, 0.72, on_action)
	jump_button = add_hud_button("점프", 0.75, 0.97, on_jump)
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
	next_hint.text = "다음 >"
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
	match name:
		"밥풀": return Color(0.98, 0.97, 0.93)
		"주걱": return Color(0.82, 0.62, 0.34)
		"물": return Color(0.55, 0.8, 0.98)
		"돌": return Color(0.62, 0.62, 0.66)
		"구렁이": return Color(0.5, 0.66, 0.3)
		"장작": return Color(0.72, 0.5, 0.28)
	return Color(0.9, 0.8, 0.6)

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
			ci.draw_string(font, sp + Vector2(5, 24), "전래", HORIZONTAL_ALIGNMENT_LEFT, -1, int(font_size * 0.55), Color(0.98, 0.92, 0.88))
			ci.draw_string(font, sp + Vector2(5, 46), "동화", HORIZONTAL_ALIGNMENT_LEFT, -1, int(font_size * 0.55), Color(0.98, 0.92, 0.88))
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
		ci.draw_string(font, Vector2(0, paper.end.y + 78), "화면을 누르면 넘어가요", HORIZONTAL_ALIGNMENT_CENTER, w, int(font_size * 0.75), Color(1, 0.95, 0.82, al))

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
	if current_lines[line_index][0] == "제비":
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

func earn(amount: int) -> void:
	coins += amount
	sfx("coin")
	float_text("+%d냥" % amount, quest_label.global_position + Vector2(short_side * 0.25, quest_label.size.y * 0.75), Color(1, 0.85, 0.3), 1.2)
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
		return "약초 캐기"
	if kind == "gourd":
		return "박 타기"
	if kind == "nest":
		return "둥지 지키기"
	if kind == "piece":
		return "살펴보기"
	if kind == "laundry":
		return "빨래 줍기"
	if kind == "hider":
		return "찾았다!"
	if kind == "bush":
		return "덤불 베기"
	if kind == "gate":
		return "이정표 보기"
	if kind == "wild":
		return "약초 캐기"
	if kind == "fish":
		return "낚시하기"
	if kind == "farm":
		return farm_action_text()
	if kind == "job":
		if t["id"] == "water":
			return "물 긷기"
		if t["id"] == "wood":
			return "나무하기"
		if t["id"] == "gam":
			return "감 따기"
		return "짚신 삼기"
	return "말 걸기"

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
		say([["", "빨래를 주웠다. (%d/3)" % laundry_found]], Callable())
	elif kind == "hider":
		node.visible = false
		sfx("good")
		burst3d(above, Color(0.98, 0.85, 0.65))
		hiders_found += 1
		say([["동생", "앗, 들켰다! 헤헤. (%d/4)" % hiders_found]], Callable())
	elif kind == "gate":
		on_gate()
	elif kind == "bush":
		if has_sickle:
			node.visible = false
			sfx("saw")
			shake(8)
			burst3d(above, Color(0.3, 0.5, 0.2), 24)
			bush_col.set_deferred("disabled", true)
			say([["", "낫으로 가시덤불을 베어 냈다. 안쪽에서 울음소리가 들린다..."]], Callable())
		else:
			say([["", "가시덤불이 길을 막고 있다. 낫이 있으면 벨 수 있겠다. (장터에서 팔아요)"]], Callable())
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
		if cfg["label"] == "제비":
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
		float_text("성공!", mid, Color(1, 0.9, 0.4), 2.0)
		burst(mid, Color(1, 0.85, 0.3), 18)
	else:
		sfx("fail")
		shake(16)
		float_text("아이쿠!", mid, Color(1, 0.55, 0.45), 2.0)
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
		mg_info.text = "%s\n남은 기회 %d" % [mg_cfg["warn"], mg_lives]
	else:
		mg_info.text = "남은 기회 %d" % mg_lives

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
		mg_info.text = "박자가 맞아요!"
	else:
		mg_b.modulate = Color(1, 1, 1)
		if mg_started:
			mg_off += delta
		mg_info.text = "갈색을 따라 좌우로!\n남은 여유 %d초" % int(ceil(patience - mg_off))
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
				float_text("아야!", center, Color(1, 0.55, 0.45), 1.2)
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
	mg_info.text = "%s %d/%d | 남은 기회 %d" % [mg_cfg["good"], mg_count, goal, mg_lives]

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
	mg_info.text = "%s %d/%d | 남은 기회 %d" % [mg_cfg["target"], mg_count, goal, mg_lives]

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
			float_text(["뽁!", "쏙!", "얍!"][mg_count % 3], at, Color(1, 1, 1), 1.1)
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

func on_turn() -> void:
	cam_yaw_target += PI / 2.0

func on_jump() -> void:
	jump_wanted = true

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
	if event is InputEventScreenTouch:
		if event.pressed:
			var b := hud_button_hit(event.position)
			if b != null:
				btn_touches.append(event.index)
				hud_press(b)
				get_viewport().set_input_as_handled()
		elif event.index in btn_touches:
			btn_touches.erase(event.index)
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		if event.index in btn_touches:
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.device != -1:
		# 컴퓨터 마우스 (터치에서 만들어진 가짜 마우스 이벤트는 제외)
		var b2 := hud_button_hit(event.position)
		if b2 != null:
			hud_press(b2)
			get_viewport().set_input_as_handled()

func pinch_dist() -> float:
	var ps := pinch_points.values()
	return (ps[0] as Vector2).distance_to(ps[1])

func _unhandled_input(event: InputEvent) -> void:
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
	cam_yaw = lerp_angle(cam_yaw, cam_yaw_target, minf(1.0, delta * 8.0))
	var speed := SPEED
	if has_shoes:
		speed = SPEED * 1.3
	var dir := Vector3(move_input.x, 0, move_input.y).rotated(Vector3.UP, cam_yaw)
	player.velocity.x = dir.x * speed
	player.velocity.z = dir.z * speed
	if player.is_on_floor():
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
	if on_floor and not was_on_floor and fall_speed > 3.0:
		# 착지: 쿵 하고 납작해졌다 돌아오기
		sfx("land")
		stretch_player(Vector3(1.3, 0.7, 1.3))
		burst3d(player.position, Color(0.85, 0.8, 0.65), 8)
	was_on_floor = on_floor
	if on_floor and dir.length() > 0.1:
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
			sfx("step", rng.randf_range(0.85, 1.15))
	else:
		player_body.position.y = lerpf(player_body.position.y, 1.0, 0.3)
		limb_amt = lerpf(limb_amt, 0.0, 0.25)
	arm_up_amt = lerpf(arm_up_amt, 0.0 if on_floor else 1.0, 0.3)
	player_body.set_meta("gait", [fposmod(walk_phase / TAU, 1.0), limb_amt, gait_run])
	if mg_active and mg_world:
		world_pose(delta)
	else:
		pose_person(player_body, sin(walk_phase) * limb_amt, arm_up_amt)
	if dir.length() > 0.1 and on_floor:
		player_body.rotation.x = lerpf(player_body.rotation.x, 0.04 if player_body.has_meta("skel") else 0.12, 0.2)
	else:
		player_body.rotation.x = lerpf(player_body.rotation.x, 0.0, 0.2)
	if player.position.y < -10.0:
		player.position = Vector3(-2, 0, 16)
		player.velocity = Vector3.ZERO
	if dir.length() > 0.1:
		player.rotation.y = lerp_angle(player.rotation.y, atan2(dir.x, dir.z), minf(1.0, delta * 14.0))
	cam_zoom = lerpf(cam_zoom, cam_zoom_target, minf(1.0, delta * 10.0))
	if mg_active and mg_world:
		# 미니게임 자리로 카메라가 스르륵 다가가요
		cam.global_transform = cam.global_transform.interpolate_with(world_cam, minf(1.0, delta * 5.0))
	else:
		cam.position = player.position + (CAM_OFFSET * cam_zoom).rotated(Vector3.UP, cam_yaw)
		cam.look_at(player.position + Vector3(0, 1.3, 0))
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
	turn_button.visible = not busy

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

func world_game_end() -> void:
	pass

func world_node(n: Node3D) -> Node3D:
	return null

func bone_world(bn: String) -> Vector3:
	return Vector3.ZERO

func place_tool(dir: Vector3) -> void:
	pass

func pose_custom(arm_l: Vector3, arm_r: Vector3, lean: float, crouch: float) -> void:
	pass

func world_pose(delta: float) -> void:
	pass


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
