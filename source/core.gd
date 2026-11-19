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

# ---------- 이어하기: 진행 저장 (모든 장이 하나의 세계로 이어져요) ----------
# save.cfg 안의 칸
#   [world]  모든 장이 함께 쓰는 것: 지금 있는 장, 엽전, 가진 물건, 입은 옷
#   [ch1_state], [ch2_state] ...  장마다의 이야기 진행 (각 장 스크립트가 채워요)
const SAVE_PATH := "user://save.cfg"
const SAVE_VERSION := 1
const CHAPTER_SCENES := {"ch1": "res://main.tscn", "ch2": "res://chapter2.tscn"}
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
	cf.set_value(chapter_id() + "_state", "data", st)
	cf.save(SAVE_PATH)
	save_timer = 0.0

# 저장된 진행이 있으면 되살리고 true
func restore_progress() -> bool:
	if has_hanbok and player_body != null:
		recolor_outfit(player_body, Color(0.45, 0.78, 0.72))
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) != OK:
		return false
	var st: Dictionary = cf.get_value(chapter_id() + "_state", "data", {})
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
	cf.save(SAVE_PATH)
	leaving_scene = true
	# 다음 장을 짓는 동안 화면이 멈춰 보이지 않게, 두루마리를 먼저 펼쳐 둬요
	show_card("책장을 넘기는 중...", 1.0, 30.0, Callable())
	await get_tree().create_timer(0.9).timeout
	get_tree().change_scene_to_file(CHAPTER_SCENES[id])

# 이야기 진행만 지우고 처음부터 (도감, 엔딩, 설정은 남겨요)
func reset_progress() -> void:
	var cf := ConfigFile.new()
	cf.load(SAVE_PATH)
	for sec in cf.get_sections():
		if sec == "world" or sec.ends_with("_state"):
			cf.erase_section(sec)
	cf.save(SAVE_PATH)
	leaving_scene = true
	get_tree().change_scene_to_file(CHAPTER_SCENES["ch1"])

func update_autosave(delta: float) -> void:
	save_timer += delta
	if save_timer > 5.0 and not mg_active and not is_busy() and chapter_id() != "":
		save_progress()

func _notification(what: int) -> void:
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
	place(page, 0.06, 0.17, 0.94, 0.83)
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
	place(again, 0.15, 0.645, 0.85, 0.725)
	var restart := Button.new()
	restart.text = "처음부터 다시 하기"
	skin_button(restart, make_round(Color(0.93, 0.78, 0.72), font_size * 0.35), Color(0.55, 0.18, 0.12), 0.75)
	page.add_child(restart)
	place(restart, 0.22, 0.74, 0.78, 0.81)
	restart.pressed.connect(func():
		close_settings()
		ask("", "이야기 진행과 엽전, 물건을 지우고 처음부터 시작할까요?\n(도감, 엔딩 기록, 설정은 그대로 남아요)", ["처음부터 시작", "그만둘래요"], func(i: int):
			if i == 0:
				reset_progress()))
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
	place(close, 0.3, 0.84, 0.7, 0.95)
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
	if player == null:
		return
	update_autosave(delta)
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
	save_progress()

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
	if player == null:
		return
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
	if player == null:
		return
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
		var gh := cam_ground(cam.position.x, cam.position.z)
		if cam.position.y < gh + 1.5:
			cam.position.y = gh + 1.5
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
