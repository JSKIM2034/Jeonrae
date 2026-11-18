extends Node3D

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

	load_south()
	load_controls()
	make_sounds()
	make_world()
	make_village()
	make_forest()
	make_decor()
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
	scatter_items()
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
	show_card("흥부와 놀부, 해와 달이 된 오누이...\n\n점점 잊혀 가는 옛이야기들이\n이 책 속에 잠들어 있어요.\n\n우리 이야기를 다시 세상에 들려줄\n첫 장을 펼쳐 볼까요?", 1.0, 8.0, func():
		if not walk_hint_seen:
			show_walk_hint())

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

# 한옥. style: "thatch" 초가집 / "tile" 기와집. 앞쪽은 +z 방향
# ---------- 고운 질감: 코드로 직접 그린 그림들 ----------

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

# 박: 뽀얀 둥근 몸통에 은은한 골, 꼭지, 덩굴과 하얀 박꽃
func make_gourd_visual(g: Node3D, c: Color, radius: float) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = int(g.position.x * 10.0 + g.position.z)
	var R := radius
	var body := [[Vector3(0, R * 0.9, 0), Vector3(2.0 * R, 1.8 * R, 2.0 * R), c]]
	for i in 8:
		var a := i * TAU / 8.0
		body.append([Vector3(cos(a) * R * 0.3, R * 0.9, sin(a) * R * 0.3), Vector3(R * 1.5, 1.74 * R, R * 1.5), c.lightened(0.07) if i % 2 == 0 else c.darkened(0.04)])
	body.append([Vector3(-R * 0.35, R * 1.35, R * 0.55), Vector3(R * 0.5, R * 0.35, R * 0.3), c.lightened(0.3)])
	add_blobs(g, body, blob_gloss())
	var stem := make_color(Color(0.45, 0.4, 0.2))
	var top := Vector3(0, R * 1.78, 0)
	add_beam(g, stem, top, top + Vector3(0.05, R * 0.22, 0.02), R * 0.09, R * 0.09)
	add_beam(g, stem, top + Vector3(0.05, R * 0.22, 0.02), top + Vector3(R * 0.22, R * 0.3, 0.06), R * 0.06, R * 0.06)
	var leaves := leaf_items(Vector3.ZERO, 5, R * 0.95, r, Color(0.3, 0.56, 0.24))
	for i in 2:
		var a := r.randf() * TAU
		leaves.append([Vector3(cos(a) * R * 1.4, 0.2, sin(a) * R * 1.4), Vector3(0.32, 0.08, 0.32) * R, Color(1, 1, 0.97)])
		leaves.append([Vector3(cos(a) * R * 1.4, 0.24, sin(a) * R * 1.4), Vector3(0.1, 0.06, 0.1) * R, Color(1.0, 0.92, 0.5)])
	add_blobs(g, leaves, null, true)
	var vine := make_color(Color(0.28, 0.48, 0.2))
	var prev := Vector3(0, 0.08, 0)
	for k in 6:
		var nxt := prev + Vector3(r.randf_range(0.2, 0.6), 0, r.randf_range(-0.5, 0.5)) * R
		nxt.y = 0.08
		add_beam(g, vine, prev, nxt, 0.06, 0.06)
		prev = nxt

# 처마 밑 제비 둥지: 진흙 사발 + 입 벌린 아기 제비 셋
func make_nest_visual(n: Node3D) -> void:
	var root := Node3D.new()
	# 흥부네 처마 밑, 앞쪽 왼편 기둥에 붙어 있어요
	root.position = Vector3(0.12, 1.98, -0.5)
	root.scale = Vector3(1.45, 1.45, 1.45)
	n.add_child(root)
	add_mbox(root, dark_wood_mat, Vector3(0.7, 0.06, 0.45), Vector3(0, -0.2, 0))
	var mud := []
	var r := RandomNumberGenerator.new()
	r.seed = 9
	for i in 12:
		var a := i * TAU / 12.0
		mud.append([Vector3(cos(a) * 0.24, r.randf_range(-0.04, 0.04), sin(a) * 0.17), Vector3(0.2, 0.17, 0.17), Color(0.55, 0.42, 0.28).lightened(r.randf() * 0.15)])
	mud.append([Vector3(0, -0.1, 0), Vector3(0.5, 0.18, 0.36), Color(0.5, 0.38, 0.25)])
	for i in 6:
		mud.append([Vector3(r.randf_range(-0.25, 0.25), 0.05, r.randf_range(-0.15, 0.15)), Vector3(0.3, 0.02, 0.02), Color(0.9, 0.78, 0.45), Vector3(0, r.randf_range(0, 180), r.randf_range(-20, 20))])
	for i in 3:
		var x := (i - 1) * 0.14
		mud.append([Vector3(x, 0.12, 0.02), Vector3(0.13, 0.13, 0.13), Color(0.15, 0.17, 0.28)])
		mud.append([Vector3(x, 0.09, 0.07), Vector3(0.08, 0.06, 0.04), Color(0.98, 0.95, 0.9)])
		mud.append([Vector3(x, 0.17, 0.1), Vector3(0.09, 0.03, 0.08), Color(1.0, 0.75, 0.2), Vector3(-25, 0, 0)])
		mud.append([Vector3(x, 0.14, 0.1), Vector3(0.08, 0.025, 0.07), Color(1.0, 0.6, 0.15), Vector3(20, 0, 0)])
	add_blobs(root, mud)

# 약초: 가는 줄기, 톱니 잎, 보랏빛 도라지꽃
func make_herb_visual(h: Node3D) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = int(h.position.x * 7.0 + h.position.z)
	var items := leaf_items(Vector3.ZERO, 6, 0.28, r, Color(0.26, 0.52, 0.24))
	var stem := make_color(Color(0.3, 0.5, 0.22))
	for i in 4:
		var a := i * TAU / 4.0 + r.randf() * 0.5
		var top := Vector3(cos(a) * 0.18, r.randf_range(0.55, 0.85), sin(a) * 0.18)
		add_beam(h, stem, Vector3(0, 0.02, 0), top, 0.035, 0.035)
		items.append([top * 0.55, Vector3(0.18, 0.04, 0.1), Color(0.34, 0.6, 0.28), Vector3(0, -rad_to_deg(a), 25)])
		var fc := Color(0.66, 0.45, 0.92) if i % 2 == 0 else Color(0.95, 0.5, 0.75)
		for k in 5:
			var b := k * TAU / 5.0
			items.append([top + Vector3(cos(b) * 0.07, 0.02, sin(b) * 0.07), Vector3(0.09, 0.05, 0.09), fc])
		items.append([top + Vector3(0, 0.04, 0), Vector3(0.05, 0.05, 0.05), Color(1.0, 0.95, 0.6)])
	add_blobs(h, items)
	# 뿌리 쪽 흙더미
	add_blobs(h, [[Vector3(0, 0.02, 0), Vector3(0.6, 0.12, 0.6), Color(0.45, 0.33, 0.22)]], null, true)

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

# 놀부가 흩뜨려 놓은 빨래: 구겨진 천 더미 + 저고리 한 벌
func make_laundry_pile(n: Node3D) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = int(n.position.x * 3.0 + n.position.z)
	var cloth := [Color(0.98, 0.98, 0.96), Color(0.82, 0.9, 1.0), Color(1.0, 0.88, 0.86)]
	var items := []
	for i in 5:
		items.append([Vector3(r.randf_range(-0.35, 0.35), 0.04 + i * 0.03, r.randf_range(-0.3, 0.3)), Vector3(r.randf_range(0.7, 1.0), 0.05, r.randf_range(0.5, 0.7)), cloth[i % 3], Vector3(r.randf_range(-5, 5), r.randf_range(0, 180), r.randf_range(-5, 5))])
	items.append([Vector3(0.1, 0.2, 0.0), Vector3(0.5, 0.18, 0.35), cloth[0], Vector3(0, 30, 10)])
	# 빨간 고름 하나
	items.append([Vector3(0.25, 0.2, 0.1), Vector3(0.05, 0.03, 0.34), Color(0.85, 0.25, 0.3), Vector3(0, 35, 0)])
	add_blobs(n, items, null, true)

# 김 서방네 호박: 골 깊은 주황 호박 + 꼭지 + 잎
func make_pumpkin(pos: Vector3, s: float, r: RandomNumberGenerator) -> void:
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	var c := Color(0.9, 0.42, 0.06)
	var items := []
	for i in 8:
		var a := i * TAU / 8.0
		items.append([Vector3(cos(a) * 0.2 * s, 0.38 * s, sin(a) * 0.2 * s), Vector3(0.48, 0.66, 0.48) * s, c.lightened(0.06) if i % 2 == 0 else c.darkened(0.08)])
	items.append([Vector3(0, 0.4 * s, 0), Vector3(0.8, 0.7, 0.8) * s, c])
	add_blobs(root, items, blob_gloss())
	add_beam(root, make_color(Color(0.42, 0.45, 0.2)), Vector3(0, 0.7 * s, 0), Vector3(0.05, 0.86 * s, 0.03), 0.07 * s, 0.07 * s)
	add_blobs(root, leaf_items(Vector3.ZERO, 4, 0.55 * s, r, Color(0.3, 0.55, 0.24)), null, true)

# 박 첨지네 논: 논두렁 + 찰랑이는 물 + 줄 맞춘 모
func make_paddy(center: Vector3, w: float, d: float) -> void:
	var earth := make_tex_material(Color(0.6, 0.5, 0.34), plaster_tex, 0.4)
	add_mbox(self, earth, Vector3(w, 0.25, 0.4), center + Vector3(0, 0.12, d / 2.0))
	add_mbox(self, earth, Vector3(w, 0.25, 0.4), center + Vector3(0, 0.12, -d / 2.0))
	add_mbox(self, earth, Vector3(0.4, 0.25, d), center + Vector3(w / 2.0, 0.12, 0))
	add_mbox(self, earth, Vector3(0.4, 0.25, d), center + Vector3(-w / 2.0, 0.12, 0))
	add_mbox(self, make_color(Color(0.42, 0.34, 0.24)), Vector3(w - 0.4, 0.04, d - 0.4), center + Vector3(0, 0.02, 0))
	var wtr := add_mbox(self, water_material(2, Vector4(center.x, center.z, w / 2.0 - 0.2, d / 2.0 - 0.2), Color(0.36, 0.44, 0.36), Color(0.52, 0.6, 0.48), Vector2.ZERO, 0.25), Vector3(w - 0.4, 0.02, d - 0.4), center + Vector3(0, 0.08, 0))
	wtr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var rice := []
	var nx := 9
	for ix in nx:
		for iz in nx:
			var p := center + Vector3(-w / 2.0 + 0.55 + ix * (w - 1.1) / (nx - 1), 0.25, -d / 2.0 + 0.55 + iz * (d - 1.1) / (nx - 1))
			rice.append([p, Vector3(0.18, 0.4, 0.18), Color(0.45, 0.7, 0.3)])
			rice.append([p + Vector3(0.05, 0.08, 0), Vector3(0.08, 0.36, 0.08), Color(0.55, 0.78, 0.35), Vector3(0, 0, -20)])
	add_blobs(self, rice)
	house_rects.append(Rect2(center.x - w / 2.0 - 0.3, center.z - d / 2.0 - 0.3, w + 0.6, d + 0.6))

func spawn_rice(pile: Node3D) -> void:
	for i in 3:
		var p := Vector3((i - 1) * 0.85, 0, rng.randf_range(-0.2, 0.2))
		add_blobs(pile, [[p + Vector3(0, 0.5, 0), Vector3(0.75, 1.0, 0.6), Color(1, 0.95, 0.8)], [p + Vector3(0, 1.02, 0), Vector3(0.4, 0.2, 0.35), Color(0.95, 0.85, 0.6)]], thatch_blob_mat)
		add_beam(pile, make_color(Color(0.55, 0.4, 0.2)), p + Vector3(-0.3, 0.9, 0), p + Vector3(0.3, 0.9, 0), 0.04, 0.04)
	var heap := [[Vector3(0, 0.2, 0.75), Vector3(1.3, 0.4, 0.9), Color(0.98, 0.97, 0.92)]]
	for i in 14:
		heap.append([Vector3(rng.randf_range(-0.8, 0.8), 0.04, 0.75 + rng.randf_range(-0.6, 0.6)), Vector3(0.06, 0.04, 0.04), Color(1, 1, 0.96)])
	add_blobs(pile, heap)

func spawn_silk(pile: Node3D) -> void:
	var silk := [Color(0.85, 0.2, 0.3), Color(0.2, 0.4, 0.8), Color(0.95, 0.75, 0.2), Color(0.3, 0.65, 0.4), Color(0.75, 0.45, 0.85)]
	var y := 0.2
	for i in 5:
		var roll := add_mcyl(pile, glossy_mat(silk[i]), 0.2, 0.2, 1.3, Vector3(-0.42 + (i % 2) * 0.42 + (0.21 if i >= 2 else 0.0), y + (i / 2) * 0.38, 0))
		roll.rotation.z = PI / 2.0
		add_mcyl(pile, glossy_mat(Color(0.95, 0.8, 0.3)), 0.205, 0.205, 0.08, roll.position).rotation.z = PI / 2.0

func spawn_gold(pile: Node3D) -> void:
	var gold := glossy_mat(Color(1.0, 0.78, 0.2))
	gold.metallic = 0.7
	gold.roughness = 0.25
	# 열린 궤짝
	add_mbox(pile, dark_wood_mat, Vector3(1.2, 0.6, 0.8), Vector3(0, 0.3, 0))
	var lid := add_mbox(pile, make_color(Color(0.65, 0.18, 0.15)), Vector3(1.2, 0.08, 0.8), Vector3(0, 0.85, -0.55))
	lid.rotation.x = -1.1
	for sx in [-0.55, 0.55]:
		add_mbox(pile, gold, Vector3(0.06, 0.62, 0.82), Vector3(sx, 0.31, 0))
	var heap := []
	for i in 22:
		heap.append([Vector3(rng.randf_range(-0.45, 0.45), 0.62 + rng.randf() * 0.15, rng.randf_range(-0.28, 0.28)), Vector3(0.16, 0.05, 0.16), Color(1, 0.82, 0.25)])
	var jewels := [Color(0.9, 0.15, 0.25), Color(0.2, 0.75, 0.5), Color(0.3, 0.45, 0.95)]
	for i in 4:
		heap.append([Vector3(rng.randf_range(-0.35, 0.35), 0.75, rng.randf_range(-0.2, 0.2)), Vector3(0.12, 0.12, 0.12), jewels[i % 3]])
	add_blobs(pile, heap, blob_gloss())
	# 말굽 은덩이와 엽전 꾸러미
	for i in 3:
		add_mbox(pile, gold, Vector3(0.36, 0.16, 0.22), Vector3(-0.9 + i * 0.25, 0.08, 0.75))
	for i in 3:
		for k in 5:
			add_mcyl(pile, gold, 0.12, 0.12, 0.035, Vector3(0.75 + i * 0.28, 0.02 + k * 0.04, 0.7 - i * 0.1))

# 가시덤불: 작은 잎 뭉치와 삐죽한 가시 가지
func make_thorn_shrubs(parent: Node3D, size: Vector3, c: Color) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = int(parent.position.x * 7.0 + parent.position.z * 3.0)
	var items := []
	var n := int(maxf(size.x, size.z) * 7.0)
	for i in n:
		var p := Vector3(r.randf_range(-0.5, 0.5) * size.x, r.randf_range(-0.5, 0.45) * size.y, r.randf_range(-0.5, 0.5) * size.z)
		var sz := r.randf_range(0.35, 0.7)
		items.append([p, Vector3(sz, sz * 0.85, sz), c.lightened(r.randf() * 0.15 + (p.y / size.y + 0.5) * 0.15)])
	var mi := add_blobs(parent, items)
	mi.position.y = 0.0
	var thorn := make_color(Color(0.42, 0.3, 0.2))
	for i in int(n / 3):
		var a := Vector3(r.randf_range(-0.5, 0.5) * size.x, r.randf_range(-0.3, 0.5) * size.y, r.randf_range(-0.5, 0.5) * size.z)
		add_beam(parent, thorn, a, a + Vector3(r.randf_range(-0.5, 0.5), r.randf_range(0.2, 0.5), r.randf_range(-0.5, 0.5)), 0.03, 0.03)

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

func make_signpost(pos: Vector3) -> void:
	var sign := make_spot(pos, "gate", "", "", true)
	add_mcyl(sign, dark_wood_mat, 0.07, 0.08, 1.9, Vector3(0, 0.95, 0))
	var board := add_mbox(sign, plank_mat, Vector3(1.7, 0.42, 0.08), Vector3(0, 1.62, 0))
	board.rotation.z = -0.05
	var lab := Label3D.new()
	lab.text = "이 길 끝은 2장\n해와 달이 된 오누이\n(준비 중)"
	lab.font = font
	lab.font_size = 34
	lab.modulate = Color(0.25, 0.14, 0.08)
	lab.outline_size = 0
	lab.position = Vector3(0, 1.62, 0.05)
	lab.pixel_size = 0.0034
	sign.add_child(lab)
	add_tag(sign, "다음 이야기로 가는 길", 2.4)

func make_border(r: RandomNumberGenerator) -> void:
	# 보이지 않는 벽 바깥에 나무와 덤불을 둘러 심어, 마을이 숲에 감싸인 것처럼
	var side := MAP_HALF + 2.5
	var t := -side
	while t <= side:
		for edge in 4:
			var p := Vector3.ZERO
			match edge:
				0: p = Vector3(t, 0, -side)
				1: p = Vector3(t, 0, side)
				2: p = Vector3(-side, 0, t)
				3: p = Vector3(side, 0, t)
			p += Vector3(r.randf_range(-1.5, 1.5), 0, r.randf_range(-1.5, 1.5))
			if edge == 1 and absf(p.x + 2.0) < 4.5:
				continue
			make_tree(p)
			if r.randf() < 0.5:
				make_tree(p + Vector3(r.randf_range(-3, 3), 0, r.randf_range(-3, 3)) + p.normalized() * 4.0)
		t += r.randf_range(4.5, 6.5)
	# 다음 이야기로 가는 남쪽 길목
	make_jangseung(Vector3(-4.7, 0, 37.5), false)
	make_jangseung(Vector3(0.7, 0, 37.5), true)
	make_signpost(Vector3(1.6, 0, 34.0))

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

func make_paths() -> void:
	make_dirt_path([Vector2(-2.0, -13.6), Vector2(-2.3, -8.0), Vector2(-1.6, -2.5), Vector2(-2.3, 3.5), Vector2(-1.8, 8.0), Vector2(-2.4, 12.5), Vector2(-2.0, 18.0), Vector2(-2.7, 25.0), Vector2(-1.7, 32.0), Vector2(-2.2, 39.0), Vector2(-2.0, 48.0)], 2.5, 1.0)
	# 남쪽 갈림길: 왼쪽은 연못 낚시터, 오른쪽은 최 영감네 논
	make_dirt_path([Vector2(-2.3, 30.0), Vector2(-6.0, 31.2), Vector2(-10.5, 30.6), Vector2(-15.4, 31.0)], 1.8, 7.0)
	make_dirt_path([Vector2(-1.8, 29.0), Vector2(3.5, 30.0), Vector2(9.5, 29.4), Vector2(15.0, 30.4), Vector2(19.0, 31.0)], 1.8, 9.0)
	make_dirt_path([Vector2(-12.2, 6.4), Vector2(-7.5, 8.4), Vector2(-2.0, 8.0), Vector2(4.0, 7.5), Vector2(9.5, 8.4), Vector2(14.5, 8.0), Vector2(19.6, 8.6), Vector2(20.4, 13.5), Vector2(19.8, 17.6)], 2.3, 4.0)

func make_creek() -> void:
	var line := []
	var x := -45.0
	while x <= 45.0:
		line.append(Vector2(x, creek_z(x)))
		x += 0.8
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in line.size() - 1:
		var a: Vector2 = line[i]
		var b: Vector2 = line[i + 1]
		var ha := creek_half(a.x)
		var hb := creek_half(b.x)
		var quad := [[Vector3(a.x, 0.03, a.y - ha), Vector2((a.x + 45.0) / 90.0, 0)], [Vector3(a.x, 0.03, a.y + ha), Vector2((a.x + 45.0) / 90.0, 1)], [Vector3(b.x, 0.03, b.y - hb), Vector2((b.x + 45.0) / 90.0, 0)], [Vector3(b.x, 0.03, b.y + hb), Vector2((b.x + 45.0) / 90.0, 1)]]
		for k in [0, 2, 1, 1, 2, 3]:
			st.set_normal(Vector3.UP)
			st.set_uv(quad[k][1])
			st.add_vertex(quad[k][0])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = water_material(0, Vector4(0, 0, 1, 1), Color(0.13, 0.4, 0.6), Color(0.42, 0.72, 0.82), Vector2(0.06, 0.0), 0.8)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


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
	ALBEDO = col;
	ROUGHNESS = 0.07;
	SPECULAR = 0.75;
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
var splat_r: PackedFloat32Array
var splat_g: PackedFloat32Array

func splat_stamp(ch: PackedFloat32Array, cx: float, cz: float, r_in: float, r_out: float, strength: float = 1.0) -> void:
	var k := SPLAT_N / SPLAT_SIZE
	var px := (cx + SPLAT_SIZE / 2.0) * k
	var pz := (cz + SPLAT_SIZE / 2.0) * k
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
	# 흙길
	for pl in path_lines:
		var line: Array = pl[0]
		var w: float = pl[1]
		for i in line.size():
			var p: Vector2 = line[i]
			splat_stamp(splat_r, p.x, p.y, w * 0.2, w * 0.72)
	# 집 마당 (흥부네, 놀부네)은 흙이 드러나요
	for yard in [Rect2(-17.5, -5.2, 9.0, 8.0), Rect2(7.0, -3.0, 14.0, 9.5)]:
		var y := 0.0
		while y <= yard.size.y:
			var x := 0.0
			while x <= yard.size.x:
				splat_stamp(splat_r, yard.position.x + x, yard.position.y + y, 0.6, 2.2, 0.62)
				x += 1.2
			y += 1.2
	# 개울가 진흙
	var cx := -50.0
	while cx <= 50.0:
		splat_stamp(splat_g, cx, creek_z(cx), creek_half(cx) + 0.2, creek_half(cx) + 1.4)
		cx += 0.6
	# 연못 둘레
	for i in 48:
		var a := TAU * i / 48.0
		splat_stamp(splat_g, POND_C.x + cos(a) * 5.4, POND_C.z + sin(a) * 3.9, 0.4, 1.6)
	# 논두렁 둘레
	for fc in [[FARM_C, 9.0, 7.0], [Vector3(-34.5, 0, -3), 6.0, 6.0]]:
		var c: Vector3 = fc[0]
		var w2: float = fc[1] / 2.0 + 0.5
		var d2: float = fc[2] / 2.0 + 0.5
		var t := -1.0
		while t <= 1.0:
			splat_stamp(splat_g, c.x + t * w2, c.z - d2, 0.3, 1.1, 0.8)
			splat_stamp(splat_g, c.x + t * w2, c.z + d2, 0.3, 1.1, 0.8)
			splat_stamp(splat_g, c.x - w2, c.z + t * d2, 0.3, 1.1, 0.8)
			splat_stamp(splat_g, c.x + w2, c.z + t * d2, 0.3, 1.1, 0.8)
			t += 0.12
	var bytes := PackedByteArray()
	bytes.resize(SPLAT_N * SPLAT_N * 4)
	for z in SPLAT_N:
		var wz := z * SPLAT_SIZE / SPLAT_N - SPLAT_SIZE / 2.0
		var forest := clampf((-17.5 - wz) / 4.0, 0.0, 1.0)
		for x in SPLAT_N:
			var i := z * SPLAT_N + x
			bytes[i * 4] = int(splat_r[i] * 255.0)
			bytes[i * 4 + 1] = int(splat_g[i] * 255.0)
			bytes[i * 4 + 2] = int(forest * 255.0)
			bytes[i * 4 + 3] = 255
	var img := Image.create_from_data(SPLAT_N, SPLAT_N, false, Image.FORMAT_RGBA8, bytes)
	ground_mat.set_shader_parameter("splat_tex", ImageTexture.create_from_image(img))

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
	var mat := ShaderMaterial.new()
	mat.shader = sh
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mat
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

func make_gourd_at(pos: Vector3, c: Color, radius: float) -> Node3D:
	var g := Node3D.new()
	g.position = pos
	add_child(g)
	make_gourd_visual(g, c, radius)
	g.set_meta("radius", radius)
	add_tag(g, "박", radius * 2.0 + 0.7)
	g.visible = false
	return g

# ---------- 세상 만들기 ----------

func make_world() -> void:
	make_surface_materials()
	var sun := DirectionalLight3D.new()
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
	add_child(env)

	var full := MAP_HALF * 2.0
	var none := Color(0, 0, 0, 0)
	var ground_col := add_solid(Vector3(0, -0.5, 0), Vector3(full, 1, full), Color(0.45, 0.7, 0.35))
	(ground_col.get_parent().get_child(0) as MeshInstance3D).material_override = ground_mat
	add_solid(Vector3(0, 2, -MAP_HALF), Vector3(full, 8, 1), none)
	add_solid(Vector3(0, 2, MAP_HALF), Vector3(full, 8, 1), none)
	add_solid(Vector3(-MAP_HALF, 2, 0), Vector3(1, 8, full), none)
	add_solid(Vector3(MAP_HALF, 2, 0), Vector3(1, 8, full), none)

	# 숲 바닥, 개울, 다리, 길
	make_creek()
	add_box(self, Color(0.55, 0.4, 0.25), Vector3(3, 0.2, 4), Vector3(-2, 0.1, -15.5)).material_override = plank_mat
	# 개울은 다리로만 건널 수 있어요 (점프로도 못 넘는 보이지 않는 벽, 다리 자리만 비워 둠)
	var creek_left_len := (-3.5) - (-MAP_HALF)
	var creek_right_len := MAP_HALF - (-0.5)
	add_solid(Vector3(-MAP_HALF + creek_left_len / 2.0, 2, -15.5), Vector3(creek_left_len, 5, 3), none)
	add_solid(Vector3(-0.5 + creek_right_len / 2.0, 2, -15.5), Vector3(creek_right_len, 5, 3), none)
	make_paths()

func make_village() -> void:
	# 놀부네
	make_house(Vector3(14, 0, 2), Vector3(9, 4, 6), Color(0.95, 0.93, 0.86), Color(0.28, 0.3, 0.36), "tile")
	make_npc("nolbu", "놀부", Color(0.6, 0.2, 0.45), Vector3(14, 0, 7.5), 1.15, true)
	make_npc("wife", "놀부 마누라", Color(0.75, 0.3, 0.3), Vector3(10.5, 0, 7.8), 1.0, true)
	nolbu_gourd = make_gourd_at(Vector3(19, 0, 8.5), Color(0.6, 0.68, 0.4), 1.7)
	make_npc("dokkaebi", "도깨비", Color(0.2, 0.55, 0.6), Vector3(19, 0, 8.5), 1.3, false).visible = false

	# 흥부네
	hut = make_house(Vector3(-13, 0, -2), Vector3(4.5, 2.8, 3.5), Color(0.8, 0.74, 0.64), Color(0.6, 0.53, 0.38), "thatch")
	make_hut_shabby(hut)
	make_npc("heungbu", "흥부", Color(0.85, 0.6, 0.35), Vector3(-12, 0, 2.5), 1.0, true)
	make_npc("kid1", "첫째", Color(0.95, 0.75, 0.5), Vector3(-16.5, 0, 4), 0.7, true)
	make_npc("kid2", "막내", Color(0.98, 0.82, 0.6), Vector3(-9, 0, 5), 0.55, true)
	var nest := make_spot(Vector3(-15.2, 0, 0.7), "nest", "", "", true)
	add_tag(nest, "제비 둥지", 3.4)
	make_nest_visual(nest)
	for pos in [Vector3(-6.5, 0, -3), Vector3(-5, 0, 0), Vector3(-6.5, 0, 3)]:
		add_thing(make_gourd_at(pos, Color(0.82, 0.9, 0.62), 1.2), "gourd", "")

	# 장터
	add_solid(Vector3(20, 1, 19.2), Vector3(4, 2, 1.2), Color(0, 0, 0, 0))
	make_stall(Vector3(20, 0, 19.2))
	make_npc("merchant", "장터 상인", Color(0.3, 0.5, 0.35), Vector3(20, 0, 21.2), 1.0, true)

	# 놀부 심술에 당한 마을 사람들
	make_npc("dori", "돌이", Color(0.9, 0.8, 0.45), Vector3(9, 0, 19), 0.6, true)
	make_npc("suni", "순이 엄마", Color(0.55, 0.65, 0.85), Vector3(-9, 0, -12), 1.0, true)
	make_npc("kim", "김 서방", Color(0.5, 0.45, 0.3), Vector3(-24, 0, 15), 1.0, true)
	make_npc("ong", "옹기 할멈", Color(0.6, 0.5, 0.55), Vector3(27, 0, -9), 0.9, true)
	make_npc("park", "박 첨지", Color(0.4, 0.5, 0.55), Vector3(-31, 0, -5), 1.0, true)
	var pr := RandomNumberGenerator.new()
	pr.seed = 15
	for pos in [Vector3(-26.5, 0, 16.8), Vector3(-22.3, 0, 17), Vector3(-25, 0, 18.5)]:
		make_pumpkin(pos, 1.25, pr)
	var ong_jars := StaticBody3D.new()
	add_child(ong_jars)
	var crack := make_color(Color(0.15, 0.1, 0.08))
	for pos in [Vector3(29, 0, -10), Vector3(29.8, 0, -8.6), Vector3(28.6, 0, -7.6)]:
		make_jar(ong_jars, pos, 1.05, Color(0.42, 0.25, 0.15))
		# 놀부가 차서 생긴 금
		var c0: Vector3 = pos + Vector3(-0.1, 0.85, 0.5)
		ong_cracks.append(add_beam(self, crack, c0, c0 + Vector3(0.12, -0.2, 0.02), 0.025, 0.02))
		ong_cracks.append(add_beam(self, crack, c0 + Vector3(0.12, -0.2, 0.02), c0 + Vector3(0.02, -0.4, 0.04), 0.025, 0.02))
	make_paddy(Vector3(-34.5, 0, -3), 6.0, 6.0)
	for pos in [Vector3(-14, 0, -13.2), Vector3(-21, 0, -17.6), Vector3(5, 0, -13.2)]:
		var cloth := make_spot(pos, "laundry", "", "빨래", false)
		make_laundry_pile(cloth)

	# 품팔이 터
	var well := make_spot(Vector3(4, 0, -3), "job", "water", "우물", true)
	make_well_visual(well)
	add_solid(Vector3(4, 0.45, -3), Vector3(1.4, 0.9, 1.4), Color(0, 0, 0, 0))
	var straw := make_spot(Vector3(-17.5, 0, 8.5), "job", "shoes", "짚더미", true)
	make_haystack_visual(straw)
	add_solid(Vector3(-17.5, 0.4, 8.5), Vector3(1.6, 0.8, 1.2), Color(0, 0, 0, 0))
	var stump := make_spot(Vector3(15, 0, -19.5), "job", "wood", "나무터", true)
	make_spot(Vector3(3, 0, 5.4), "job", "gam", "감나무", true)
	make_stump_visual(stump)
	add_solid(Vector3(15, 0.35, -19.5), Vector3(1.0, 0.7, 1.0), Color(0, 0, 0, 0))

	# 숨바꼭질하는 흥부네 동생들
	for pos in [Vector3(18.6, 0, -2.6), Vector3(-23.4, 0, 6.6), Vector3(5.2, 0, 12.4), Vector3(-4.4, 0, -13)]:
		var kid := make_spot(pos, "hider", "", "", false)
		make_person(kid, "kid", Color(0.98, 0.78, 0.5), false)
		kid.scale = Vector3(0.5, 0.5, 0.5)

	# 마을 나무
	for pos in [Vector3(5, 0, 14), Vector3(-22, 0, 8), Vector3(24, 0, -6), Vector3(-26, 0, 22), Vector3(30, 0, 18), Vector3(8, 0, -8), Vector3(-20, 0, -9)]:
		make_tree(pos)

	# 바위 (점프해서 올라가요)
	add_solid(Vector3(29, 0.55, 7.5), Vector3(1.8, 1.1, 1.8), Color(0, 0, 0, 0))
	add_solid(Vector3(30.8, 1.1, 5.6), Vector3(2.4, 2.2, 2.4), Color(0, 0, 0, 0))
	var rr := RandomNumberGenerator.new()
	rr.seed = 5
	make_rock(Vector3(29, 0.45, 7.5), Vector3(2.0, 1.25, 2.0), rr)
	make_rock(Vector3(30.8, 1.0, 5.6), Vector3(2.6, 2.4, 2.6), rr)

	# 이웃 초가집들과 살림살이
	make_house(Vector3(-28, 0, 10), Vector3(4.6, 2.4, 3.4), Color(0.94, 0.9, 0.82), Color(0.8, 0.66, 0.3), "thatch")
	make_house(Vector3(30, 0, -3), Vector3(4.4, 2.3, 3.4), Color(0.93, 0.89, 0.8), Color(0.8, 0.66, 0.3), "thatch")
	make_house(Vector3(-10, 0, 22), Vector3(4.8, 2.4, 3.5), Color(0.95, 0.91, 0.83), Color(0.8, 0.66, 0.3), "thatch")
	make_jangdok(Vector3(7.8, 0, -2.7), rr)
	make_laundry(Vector3(-19.4, 0, 0.9), Vector3(-17.0, 0, 0.9))
	make_laundry(Vector3(-13.2, 0, 25.0), Vector3(-6.8, 0, 25.0))
	make_basket(Vector3(-10.3, 0, 0.9), 1.0, Color(0.95, 0.55, 0.15))
	make_basket(Vector3(-25.2, 0, 13.0), 0.9, Color(0.4, 0.7, 0.3))
	make_basket(Vector3(-7.1, 0, 25.5), 1.1, Color(0, 0, 0, 0))
	make_sieve(Vector3(-11.6, 0, -4.15), PI)
	make_sieve(Vector3(27.6, 0, -1.25), 0.3)
	make_bench(Vector3(8.6, 0, 11.6), 0.2)
	make_trellis(Vector3(-10.0, 0, 11.9), Vector3(-7.0, 0, 11.9), rr)

	# 숨은 이야기 조각
	var piece_pos := [Vector3(14, 0, -6.5), Vector3(-31, 0, -12), Vector3(-9, 0, -36), Vector3(-27.5, 0, 23.5), Vector3(35, 0, 33), Vector3(30.8, 2.2, 5.6)]
	for i in piece_pos.size():
		var p := make_spot(piece_pos[i], "piece", str(i), "", true)
		make_piece_visual(p)
	make_south()
	make_wild_herbs()

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

func make_wild_herbs() -> void:
	for k in HERBS.size():
		for pos in HERBS[k]["spots"]:
			var n := make_spot(pos, "wild", str(k), "", true)
			add_tag(n, HERBS[k]["name"], 1.25)
			make_wild_visual(n, k)
			wild_spots.append([n, k, 0.0])

func wild_keep_clear() -> Array:
	var out := []
	for h in HERBS:
		out += h["spots"]
	return out

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
	add_blobs(n, items)
	add_blobs(n, [[Vector3(0, 0.02, 0), Vector3(0.55, 0.1, 0.55), Color(0.45, 0.33, 0.22)]], null, true)

func update_wild(delta: float) -> void:
	for ws in wild_spots:
		var node: Node3D = ws[0]
		if node.visible:
			continue
		ws[2] = float(ws[2]) - delta
		if float(ws[2]) <= 0.0:
			if node.has_meta("anchor"):
				node.position = random_near(node.get_meta("anchor"), SCATTER_HERB)
			node.visible = true
			pop3d(node, true)

func herb_kinds_done() -> int:
	var n := 0
	for c in herb_counts:
		if int(c) >= HERB_NEED:
			n += 1
	return n

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
		lines.append(["", "%s을(를) 캤다! (%d/%d) 3분 뒤에 다시 자라요." % [nm, cnt, HERB_NEED]])
	elif cnt == HERB_NEED:
		var rw: int = HERBS[k]["reward"]
		earn(rw)
		lines.append(["", "%s을(를) %d번 모아 약초 도감에 올렸다! 장터에 팔아 엽전 %d냥. (약초 도감 %d/%d)" % [nm, HERB_NEED, rw, herb_kinds_done(), HERBS.size()]])
		if herb_kinds_done() >= HERBS.size() and not herb_reward:
			herb_reward = true
			earn(40)
			lines.append(["", "약초 도감을 모두 채웠다! 마을 사람들이 고맙다며 엽전 40냥을 모아 주었다."])
	else:
		earn(1)
		lines.append(["", "%s을(를) 캐서 장터에 팔았다. 엽전 1냥." % nm])
	save_south()
	say(lines, Callable())

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

func read_story(i: int) -> void:
	if not story_read[i]:
		return
	sfx("tap")
	var st: Dictionary = STORY[i]
	story_reader_label.text = "%d. %s\n\n%s" % [i + 1, st["title"], st["text"]]
	story_box.visible = false
	story_reader.visible = true

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
func laundry_spot(seg: int) -> Vector3:
	var ranges := [[-35.0, -15.0], [-13.0, 12.0], [14.0, 35.0]]
	var rg: Array = ranges[seg % 3]
	for i in 40:
		var x := rng.randf_range(rg[0], rg[1])
		if absf(x + 2.0) < 3.0:
			continue
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var p := Vector3(x, 0, creek_z(x) + side * (creek_half(x) + rng.randf_range(1.2, 2.2)))
		if ground_ok(p):
			return p
	return Vector3(rng.randf_range(rg[0], rg[1]), 0, -13.0)

func scatter_items() -> void:
	# 물리 세상이 준비될 때까지 잠깐 기다려요
	await get_tree().physics_frame
	await get_tree().physics_frame
	rng.randomize()
	for t in things:
		var node: Node3D = t["node"]
		var kind: String = t["kind"]
		var radius := 0.0
		if kind == "piece" and node.position.y < 0.5:
			radius = SCATTER_PIECE
		elif kind == "herb":
			radius = SCATTER_HERB
		elif kind == "wild" and node.position.x < 36.0:
			radius = SCATTER_HERB
		if kind == "laundry":
			node.position = laundry_spot(laundry_seg)
			laundry_seg += 1
		if radius > 0.0:
			if not node.has_meta("anchor"):
				node.set_meta("anchor", node.position)
			node.position = random_near(node.get_meta("anchor"), radius)

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

func story_count() -> int:
	var n := 0
	for r in story_read:
		if r:
			n += 1
	return n

func get_piece_id(id: int, extra: String) -> void:
	pieces_found += 1
	update_quest_text()
	var first: bool = not story_read[id]
	story_read[id] = true
	save_south()
	var st: Dictionary = STORY[id]
	var found := []
	if extra != "":
		found.append(["", extra])
	found.append(["이야기 조각 “%s”" % st["title"], st["text"]])
	if first:
		found.append(["", "새 이야기 조각을 찾았어요! 도감의 ‘이야기’에서 다시 읽을 수 있어요. (%d/%d)" % [story_count(), STORY.size()]])
	if pieces_found >= PIECE_TOTAL:
		found.append(["이야기 조각", "일곱 조각이 하나로 이어졌어요.\n놀부의 욕심 뒤에는, 동생들을 지키고 싶었던 겁 많은 형이 있었어요."])
	say(found, Callable())

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
	for c in [action_button, jump_button, turn_button, book_button, settings_button, quest_label]:
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
	var i := skel.find_bone(bn)
	return skel.global_transform * skel.get_bone_global_pose(i).origin

# 도구는 손에 붙이고, 정해 준 방향(dir)으로 뻗게 해요
func place_tool(dir: Vector3) -> void:
	if tool_node == null:
		return
	var hand := bone_world("handR").lerp(bone_world("handL"), 0.5 if tool_kind == "axe" else 0.0)
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
		turn_bone(skel, bones, "arm" + side, [[Vector3.RIGHT, arm.x], [Vector3.BACK, -sx * arm.y], [twist, sx * 0.9]])
		turn_bone(skel, bones, "fore" + side, [[Vector3.RIGHT, arm.z]])
		turn_bone(skel, bones, "thigh" + side, [[Vector3.RIGHT, -0.14 - crouch * 0.5]])
		turn_bone(skel, bones, "shin" + side, [[Vector3.RIGHT, 0.26 + crouch]])
		turn_bone(skel, bones, "foot" + side, [[Vector3.RIGHT, -0.12 - crouch * 0.45]])
	turn_bone(skel, bones, "hips", [])
	turn_bone(skel, bones, "spine", [[Vector3.RIGHT, lean]])
	turn_bone(skel, bones, "head", [[Vector3.RIGHT, -lean * 0.4]])
	player_body.position.y = 1.0 - crouch * 0.12

func world_pose(delta: float) -> void:
	if scene_pose():
		return
	match mg_type:
		"wood3d":
			var t: float = w.get("chop", 0.0)
			var arm := Vector3(lerpf(-2.75, -0.85, t), lerpf(0.12, 0.28, t), lerpf(-0.55, -0.08, t))
			pose_custom(arm, arm, lerpf(-0.14, 0.32, t), 0.18 + t * 0.15)
			var sh := (bone_world("armL") + bone_world("armR")) * 0.5
			place_tool((((bone_world("handL") + bone_world("handR")) * 0.5) - sh).normalized() + Vector3(0, 0.25 * (1.0 - t), 0))
		"well3d":
			var ph: float = w.get("pull_anim", 0.0)
			var reach := -1.35 - 0.35 * sin(ph)
			var reach2 := -1.35 + 0.35 * sin(ph)
			pose_custom(Vector3(reach, 0.25, -0.7), Vector3(reach2, 0.25, -0.7), 0.15, 0.15)
		"fish":
			var jerk: float = w.get("jerk", 0.0)
			var fight := 0.0
			if mg_step >= 2:
				fight = sin(anim_t * 18.0) * 0.06
			pose_custom(Vector3(-0.5, 0.45, -0.3), Vector3(-1.05 - jerk * 0.6 + fight, 0.3, -0.85 + jerk * 0.3), 0.06 - jerk * 0.1, 0.12)
			var fwd := Vector3(sin(player.rotation.y), 0, cos(player.rotation.y))
			place_tool((fwd * 0.75 + Vector3(0, 0.62 + jerk * 0.5, 0)).normalized())

# --- 효과 ---

func splash3d(pos: Vector3, big: bool = false) -> void:
	burst3d(pos + Vector3(0, 0.1, 0), Color(0.75, 0.9, 1.0), 26 if big else 12)
	ripple3d(pos, 1.6 if big else 0.9)

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

func chips3d(pos: Vector3) -> void:
	var p := CPUParticles3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.09, 0.03, 0.05)
	mesh.material = make_color(Color(0.9, 0.74, 0.5))
	p.mesh = mesh
	p.amount = 22
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = 0.8
	p.direction = Vector3.UP
	p.spread = 80.0
	p.initial_velocity_min = 2.5
	p.initial_velocity_max = 5.0
	p.gravity = Vector3(0, -12, 0)
	p.angular_velocity_min = -720
	p.angular_velocity_max = 720
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	p.position = pos
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)

# ---------- 나무하기: 타이밍 맞춰 도끼로 쩍! ----------

func start_wood3d() -> void:
	var stump := job_spot("wood")
	var s := stump.position
	start_game("wood3d", {"world": true, "art": "world", "title": "막대가 초록 칸에 왔을 때 눌러서\n도끼로 장작을 쪼개요!", "goal": 6}, job_done)
	world_game_begin(s + Vector3(0, 0, 1.15), s, s + Vector3(2.5, 2.1, 2.8), s + Vector3(0, 0.75, 0.35), stump)
	if stump.has_meta("axe"):
		world_hide(stump.get_meta("axe"))
	hold_tool("axe")
	w["chop"] = 0.0
	w["busy"] = false
	w["stump"] = s
	wood_new_log()

func job_spot(id: String) -> Node3D:
	for t in things:
		if t["kind"] == "job" and t["id"] == id:
			return t["node"]
	return self

func wood_new_log() -> void:
	var s: Vector3 = w["stump"]
	var lg := Node3D.new()
	lg.position = s + Vector3(0, 0.72, 0)
	world_node(lg)
	var body := add_mcyl(lg, dark_wood_mat, 0.2, 0.21, 0.52, Vector3(0, 0.26, 0))
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var cap := add_mcyl(lg, endgrain_mat(), 0.195, 0.195, 0.01, Vector3(0, 0.525, 0))
	cap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w["log"] = lg
	pop3d(lg, true)

func wood_marker() -> float:
	return sin(mg_phase)

func wood_zone() -> float:
	return maxf(0.08, 0.2 - mg_count * 0.018)

func update_wood3d(delta: float) -> void:
	if not w.get("busy", false):
		mg_phase += delta * (2.0 + mg_count * 0.32)
	mg_progress = float(mg_count) / float(mg_cfg["goal"])
	mg_info.text = "장작 %d/%d | 남은 기회 %d" % [mg_count, mg_cfg["goal"], mg_lives]

func wood_strike() -> void:
	if w.get("busy", false) or not mg_active:
		return
	w["busy"] = true
	var hit := absf(wood_marker()) < wood_zone()
	var tw := create_tween()
	tw.tween_method(func(v): w["chop"] = v, 0.0, 1.0, 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): wood_impact(hit))
	tw.tween_interval(0.18)
	tw.tween_method(func(v): w["chop"] = v, 1.0, 0.0, 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		w["busy"] = false
		if hit and mg_active:
			wood_new_log())

func wood_impact(hit: bool) -> void:
	var lg: Node3D = w.get("log")
	if lg == null or not is_instance_valid(lg):
		return
	var top := lg.global_position + Vector3(0, 0.5, 0)
	if hit:
		mg_count += 1
		sfx("crack", rng.randf_range(0.95, 1.1))
		sfx("saw", 1.4)
		hit_stop(0.07)
		shake(12)
		cam_kick = 0.35
		chips3d(top)
		flash(Color(1, 0.95, 0.8))
		var at := cam.unproject_position(top)
		float_text(["쩍!", "탁!", "쩌억!"][mg_count % 3], at, Color(1, 0.95, 0.75), 1.5)
		burst(at, Color(1, 0.85, 0.4), 10)
		# 통나무가 반으로 갈라져 양쪽으로 날아가요
		lg.visible = false
		for sx in [-1.0, 1.0]:
			var half := Node3D.new()
			half.position = lg.global_position + Vector3(sx * 0.1, 0, 0)
			add_child(half)
			var hm := add_mcyl(half, dark_wood_mat, 0.2, 0.21, 0.52, Vector3(0, 0.26, 0))
			hm.scale = Vector3(0.5, 1, 1)
			add_mbox(half, endgrain_mat(), Vector3(0.01, 0.5, 0.38), Vector3(-sx * 0.0, 0.26, 0))
			var dest := half.position + Vector3(sx * rng.randf_range(0.7, 1.0), -0.6, rng.randf_range(-0.3, 0.3))
			var tw := half.create_tween()
			tw.tween_property(half, "position", half.position + Vector3(sx * 0.4, 0.55, 0), 0.18).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(half, "rotation", Vector3(0, 0, -sx * 1.4), 0.5)
			tw.tween_property(half, "position", dest, 0.3).set_ease(Tween.EASE_IN)
			tw.tween_property(half, "scale", Vector3(0.01, 0.01, 0.01), 0.35)
			tw.tween_callback(half.queue_free)
		lg.queue_free()
	else:
		mg_lives -= 1
		mg_perfect = false
		sfx("bad")
		sfx("tick", 0.6)
		shake(6)
		var at2 := cam.unproject_position(top)
		float_text("빗나갔어요!", at2, Color(1, 0.6, 0.5), 1.1)
		var tw2 := lg.create_tween()
		tw2.tween_property(lg, "rotation:z", 0.25, 0.06)
		tw2.tween_property(lg, "rotation:z", -0.18, 0.08)
		tw2.tween_property(lg, "rotation:z", 0.0, 0.12)

# ---------- 우물: 두레박을 당겨 물 길어 올리기 ----------

const WELL_TOP := 1.12
const WELL_WATER := 0.72

func start_well3d() -> void:
	var well := job_spot("water")
	var p := well.position
	start_game("well3d", {"world": true, "art": "world", "title": "손가락으로 위로 쓸어 줄을 당겨요\n너무 세게 당기면 물이 쏟아져요!"}, job_done)
	world_game_begin(p + Vector3(0, 0, 1.3), p, p + Vector3(-2.2, 2.4, 3.0), p + Vector3(0, 0.8, 0), well)
	for k in ["bucket", "rope"]:
		if well.has_meta(k):
			world_hide(well.get_meta(k))
	var bk := Node3D.new()
	bk.position = p + Vector3(0.2, WELL_TOP, 0)
	world_node(bk)
	add_mcyl(bk, wood_mat, 0.17, 0.14, 0.26, Vector3(0, -0.13, 0))
	add_mcyl(bk, make_color(Color(0.3, 0.22, 0.14)), 0.175, 0.175, 0.03, Vector3(0, -0.02, 0))
	var wtr := add_mcyl(bk, water_material(1, Vector4(0, 0, 0.15, 0.15), Color(0.2, 0.45, 0.6), Color(0.45, 0.7, 0.8), Vector2.ZERO, 0.0), 0.15, 0.15, 0.01, Vector3(0, -0.24, 0))
	w["bucket"] = bk
	w["water_disc"] = wtr
	var rope := MeshInstance3D.new()
	var rb := BoxMesh.new()
	rb.size = Vector3(0.025, 1.0, 0.025)
	rope.mesh = rb
	rope.material_override = make_color(Color(0.75, 0.62, 0.4))
	world_node(rope)
	w["rope"] = rope
	w["pulley"] = p + Vector3(0.2, 1.75, 0)
	w["well"] = well
	w["y"] = WELL_TOP
	w["water"] = 0.0
	w["sway"] = 0.0
	w["state"] = "lower"
	w["timer"] = 0.0
	w["fill"] = 0.0
	w["pull_anim"] = 0.0
	w["last_y"] = -1.0

func update_well3d(delta: float) -> void:
	var st: String = w["state"]
	var y: float = w["y"]
	w["timer"] = float(w["timer"]) + delta
	w["sway"] = maxf(0.0, float(w["sway"]) - delta * 0.9)
	if st == "lower":
		y = move_toward(y, WELL_WATER, delta * 0.9)
		if y <= WELL_WATER + 0.001:
			sfx("splash")
			splash3d((w["pulley"] as Vector3) * Vector3(1, 0, 1) + Vector3(0, 0.62, 0))
			w["state"] = "fill"
			w["timer"] = 0.0
		mg_info.text = "두레박을 내려요..."
	elif st == "fill":
		w["water"] = minf(1.0, float(w["timer"]) / 0.6)
		if float(w["timer"]) > 0.7:
			w["state"] = "pull"
		mg_info.text = "물이 차오르고 있어요"
	elif st == "pull":
		var sway: float = w["sway"]
		if sway > 0.5:
			# 너무 흔들리면 물이 쏟아져요
			var spill := (sway - 0.5) * delta * 3.0
			w["water"] = maxf(0.0, float(w["water"]) - spill)
			if rng.randf() < delta * 8.0:
				var bkn: Node3D = w["bucket"]
				burst3d(bkn.global_position, Color(0.7, 0.88, 1.0), 4)
		if y >= WELL_TOP - 0.001:
			var got: float = w["water"]
			if got < 0.3:
				mg_lives -= 1
				mg_perfect = false
				sfx("bad")
				float_text("물이 다 쏟아졌어요!", cam.unproject_position((w["bucket"] as Node3D).global_position), Color(1, 0.6, 0.5), 1.1)
			else:
				if got < 0.85:
					mg_perfect = false
				w["fill"] = float(w["fill"]) + got * 0.36
				sfx("splash", 1.2)
				sfx("good")
				shake(4)
				var bp := (w["bucket"] as Node3D).global_position
				splash3d(bp + Vector3(0.4, -0.3, 0.5))
				float_text("물 한 동이!" if got >= 0.85 else "조금 쏟았어요", cam.unproject_position(bp), Color(0.8, 0.95, 1.0), 1.2)
			w["water"] = 0.0
			w["state"] = "lower"
		var sw_txt := "흔들려요! 살살~" if sway > 0.5 else "위로 쓸어 올려요"
		mg_info.text = "%s | 항아리 %d%% | 남은 기회 %d" % [sw_txt, int(minf(float(w["fill"]), 1.0) * 100.0), mg_lives]
	w["y"] = y
	mg_progress = minf(float(w["fill"]), 1.0)
	# 3D 위치 갱신
	var bk: Node3D = w["bucket"]
	var pul: Vector3 = w["pulley"]
	var swing := sin(anim_t * 9.0) * minf(float(w["sway"]), 1.2) * 0.35
	bk.global_position = Vector3(pul.x + sin(swing) * 0.15, (w["well"] as Node3D).position.y + y, pul.z)
	bk.rotation.z = swing
	(w["water_disc"] as Node3D).visible = float(w["water"]) > 0.02
	(w["water_disc"] as Node3D).position.y = -0.24 + float(w["water"]) * 0.2
	var rope: MeshInstance3D = w["rope"]
	var top := pul
	var bot := bk.global_position
	rope.global_position = (top + bot) * 0.5
	rope.scale = Vector3(1, maxf(0.05, top.distance_to(bot)), 1)
	rope.rotation = Vector3(0, 0, -swing * 0.3)

func well_drag(dy: float, dt_ms: float) -> void:
	if w.get("state", "") != "pull":
		return
	var h := mg_overlay.size.y
	var rise := dy / h * 1.1
	if rise <= 0.0:
		return
	w["y"] = minf(WELL_TOP, float(w["y"]) + rise)
	w["pull_anim"] = float(w["pull_anim"]) + rise * 14.0
	var speed := rise / maxf(dt_ms / 1000.0, 0.008)
	if speed > 1.1:
		w["sway"] = minf(1.6, float(w["sway"]) + (speed - 1.1) * 0.12)
	if rng.randf() < 0.3:
		sfx("tick", rng.randf_range(0.7, 0.9))

# ---------- 낚시 (3D): 연못 위 찌, 물고기 그림자, 튀어 오르는 물고기 ----------

func start_fishing3d() -> void:
	start_game("fish", {"world": true, "art": "world", "title": "찌가 쏙 들어가면 눌러서 채요!\n걸리면 눌렀다 뗐다 하며 초록 칸에"}, fish_done)
	var stand := POND_C + Vector3(4.1, 0.0, 0.0)
	var fspot: Node3D = null
	for t in things:
		if t["kind"] == "fish":
			fspot = t["node"]
	world_game_begin(stand, POND_C, POND_C + Vector3(7.4, 3.3, 3.8), POND_C + Vector3(1.6, 0.3, 0.0), fspot)
	for d in pond_deco:
		world_hide(d)
	hold_tool("rod")
	var bob := Node3D.new()
	world_node(bob)
	add_ball(bob, Color(0.9, 0.2, 0.2), 0.07, Vector3(0, 0.05, 0))
	add_ball(bob, Color(1, 1, 1), 0.065, Vector3(0, -0.01, 0))
	w["bobber"] = bob
	w["bob_at"] = POND_C + Vector3(1.0, 0.09, 0.4)
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

func update_fish_world(delta: float) -> void:
	if not mg_world or not w.has("bobber"):
		return
	var bob: Node3D = w["bobber"]
	var base: Vector3 = w["bob_at"]
	var shadow: Node3D = w["shadow"]
	var bang: Label3D = w["bang"]
	w["jerk"] = maxf(0.0, float(w["jerk"]) - delta * 3.0)
	var target := base
	if mg_step == 0:
		var nib := 0.03 if fmod(mg_phase, 1.7) < 0.15 else 0.0
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
		target = POND_C + Vector3(1.0 + fz * 0.4, 0.07, fx)
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

func fish_world_hooked() -> void:
	if not mg_world:
		return
	w["jerk"] = 1.0
	cam_kick = 0.3
	hit_stop(0.05)
	splash3d(w["bob_at"], true)

# 낚아 올린 물고기가 물에서 튀어 올라 품으로 와요
func fish_leap(kind: int) -> void:
	var f: Dictionary = FISH[kind]
	var col: Color = f["col"]
	var fish := Node3D.new()
	add_child(fish)
	var ln: float = f["len"]
	add_blobs(fish, [
		[Vector3.ZERO, Vector3(0.5 * ln, 0.22, 0.14), col],
		[Vector3(-0.3 * ln, 0, 0), Vector3(0.16, 0.18, 0.05), col.darkened(0.15)],
		[Vector3(0.18 * ln, 0.04, 0.06), Vector3(0.05, 0.05, 0.03), Color(0.05, 0.05, 0.05)],
		[Vector3(0.18 * ln, 0.04, -0.06), Vector3(0.05, 0.05, 0.03), Color(0.05, 0.05, 0.05)],
	], blob_gloss())
	var from: Vector3 = POND_C + Vector3(1.0, 0.1, 0.3)
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

# 오른쪽 힘겨루기 칸 (낚시)
func draw_reel_meter(ci: CanvasItem) -> void:
	var w2 := mg_overlay.size.x
	var h := mg_overlay.size.y
	var mx := w2 * 0.88
	var y0 := h * 0.4
	var y1 := h * 0.82
	var span := y1 - y0
	d_box(ci, Vector2(mx, (y0 + y1) / 2.0), Vector2(54, span + 20), 0.0, Color(0.62, 0.45, 0.28), 4)
	d_box(ci, Vector2(mx, (y0 + y1) / 2.0), Vector2(38, span), 0.0, Color(0.3, 0.5, 0.66), 0.0)
	var hard: float = FISH[fish_kind]["hard"]
	var half := lerpf(0.16, 0.1, hard)
	var zone_c := y1 - mg_off * span
	var inside := mg_step == 2
	var z_top := maxf(zone_c - half * span, y0)
	var z_bot := minf(zone_c + half * span, y1)
	d_box(ci, Vector2(mx, (z_top + z_bot) / 2.0), Vector2(40, z_bot - z_top), 0.0, Color(0.45, 0.9, 0.45, 0.85) if inside else Color(0.6, 0.85, 0.5, 0.6), 3)
	draw_fish2d(ci, Vector2(mx, y1 - mg_trail * span), 17, fish_kind, -PI / 2.0 + sin(anim_t * 10.0) * 0.3, true)

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

func scene_setup(scene: String) -> void:
	w["scene"] = scene
	w["seen"] = {}
	w["count0"] = mg_count
	w["lives0"] = mg_lives
	match scene:
		"heal":
			var nest := Vector3(-15.2, 0, 0.7)
			var stand := Vector3(-13.6, 0, 3.4)
			var table := stand + Vector3(-0.15, 0, -0.75)
			world_game_begin(stand, table, table + Vector3(1.0, 1.25, -1.15), table + Vector3(-0.05, 0.6, 0.35))
			# 소반 위에 다친 제비
			var tb := Node3D.new()
			tb.position = table
			world_node(tb)
			add_mcyl(tb, wood_mat, 0.42, 0.42, 0.05, Vector3(0, 0.42, 0))
			for k in 4:
				var a := k * TAU / 4.0 + 0.4
				add_mcyl(tb, dark_wood_mat, 0.035, 0.03, 0.4, Vector3(cos(a) * 0.3, 0.2, sin(a) * 0.3))
			var bird := Node3D.new()
			bird.position = table + Vector3(0, 0.5, 0)
			bird.rotation.y = 0.6
			world_node(bird)
			var navy := Color(0.17, 0.2, 0.38)
			add_blobs(bird, [
				[Vector3(0, 0.1, 0), Vector3(0.26, 0.17, 0.34), navy],
				[Vector3(0, 0.07, 0.03), Vector3(0.18, 0.11, 0.24), Color(0.97, 0.95, 0.9)],
				[Vector3(0, 0.2, 0.15), Vector3(0.16, 0.15, 0.15), navy],
				[Vector3(0, 0.18, 0.24), Vector3(0.05, 0.04, 0.07), Color(1, 0.6, 0.2)],
				[Vector3(0.06, 0.22, 0.2), Vector3(0.035, 0.035, 0.035), Color(0.05, 0.05, 0.05)],
				[Vector3(-0.06, 0.22, 0.2), Vector3(0.035, 0.035, 0.035), Color(0.05, 0.05, 0.05)],
				[Vector3(0, 0.12, -0.24), Vector3(0.08, 0.03, 0.22), navy, Vector3(10, 18, 0)],
				[Vector3(0, 0.12, -0.24), Vector3(0.08, 0.03, 0.22), navy, Vector3(10, -18, 0)],
			], blob_gloss())
			var wl := add_blobs(bird, [[Vector3(0.14, 0.14, -0.02), Vector3(0.08, 0.04, 0.26), navy.lightened(0.1), Vector3(0, 0, -25)]], blob_gloss())
			var wr := add_blobs(bird, [[Vector3(-0.14, 0.14, -0.02), Vector3(0.08, 0.04, 0.26), navy.lightened(0.1), Vector3(0, 0, 25)]], blob_gloss())
			# 다친 다리 + 부목
			add_beam(bird, make_color(Color(0.85, 0.55, 0.35)), Vector3(0.05, 0.03, 0.02), Vector3(0.12, -0.02, 0.1), 0.02, 0.02)
			add_beam(bird, wood_mat, Vector3(0.07, 0.04, 0.0), Vector3(0.15, -0.01, 0.13), 0.035, 0.012)
			w["bird"] = bird
			w["wings"] = [wl, wr]
			w["threads"] = []
		"straw":
			var hay := job_spot("shoes").position
			var stand := hay + Vector3(0.6, 0, 1.6)
			var mat_at := stand + Vector3(-0.1, 0, -0.65)
			world_game_begin(stand, mat_at, mat_at + Vector3(2.7, 1.9, 1.3), mat_at + Vector3(-0.1, 0.5, 0.3), job_spot("shoes"))
			var sandal := Node3D.new()
			sandal.position = mat_at + Vector3(0, 0.36, 0)
			world_node(sandal)
			add_mbox(sandal, thatch_dark_mat, Vector3(0.7, 0.06, 0.5), Vector3(0, -0.04, 0))
			var sole := Node3D.new()
			sandal.add_child(sole)
			add_blobs(sole, [[Vector3(0, 0, 0), Vector3(0.18, 0.04, 0.4), Color(0.9, 0.76, 0.46)], [Vector3(0, 0.04, -0.08), Vector3(0.14, 0.05, 0.16), Color(0.85, 0.7, 0.42)]], thatch_blob_mat)
			w["sole"] = sole
			var twist := Node3D.new()
			twist.position = Vector3(0, 0.12, 0.25)
			sandal.add_child(twist)
			for k in 6:
				var tor := MeshInstance3D.new()
				var tm := TorusMesh.new()
				tm.inner_radius = 0.025
				tm.outer_radius = 0.05
				tor.mesh = tm
				tor.material_override = thatch_dark_mat
				tor.position = Vector3(0, 0, -k * 0.05)
				tor.rotation.x = PI / 2.0 + k * 0.4
				twist.add_child(tor)
			w["twist"] = twist
		"ong":
			var jar := Vector3(29, 0, -10)
			var stand := jar + Vector3(-1.05, 0, 0.95)
			world_game_begin(stand, jar + Vector3(0, 0, 0.4), jar + Vector3(0.9, 1.5, 2.9), jar + Vector3(-0.3, 0.75, 0.4))
			for c in ong_cracks:
				world_hide(c)
			var patch := blob_node([[Vector3.ZERO, Vector3(0.34, 0.5, 0.06), Color(0.62, 0.45, 0.3)]])
			patch.position = jar + Vector3(-0.05, 0.66, 0.52)
			patch.scale = Vector3(0.05, 0.05, 1)
			w["patch"] = patch
			w["crack_on"] = []
			var cr := make_color(Color(0.15, 0.1, 0.08))
			var c0 := jar + Vector3(-0.1, 0.85, 0.53)
			w["crack_on"].append(world_node(add_beam(self, cr, c0, c0 + Vector3(0.12, -0.2, 0.02), 0.025, 0.02)))
			w["crack_on"].append(world_node(add_beam(self, cr, c0 + Vector3(0.12, -0.2, 0.02), c0 + Vector3(0.02, -0.4, 0.04), 0.025, 0.02)))
			var trowel := blob_node([[Vector3.ZERO, Vector3(0.16, 0.04, 0.24), Color(0.55, 0.57, 0.6)], [Vector3(0, 0.06, -0.14), Vector3(0.04, 0.12, 0.04), Color(0.55, 0.38, 0.22)]], blob_gloss())
			w["trowel"] = trowel
			w["jar_c"] = jar + Vector3(-0.05, 0.66, 0.58)
		"saw":
			var g: Node3D = saw_thing["node"]
			var gp := g.position
			# 박의 실제 높이를 재서 톱을 꼭대기에 올려요
			var top_y := 0.0
			for mi in g.find_children("*", "GeometryInstance3D", true, false):
				if mi is Label3D:
					continue
				var gi := mi as GeometryInstance3D
				var bb := gi.get_aabb()
				var tr: Transform3D = g.global_transform.affine_inverse() * gi.global_transform
				top_y = maxf(top_y, (tr * (bb.position + bb.size)).y)
			var rad: float = maxf(0.5, top_y / 2.0) if top_y > 0.1 else g.get_meta("radius", 1.2)
			w["rad"] = rad
			var stand := gp + Vector3(rad + 0.75, 0, 0.0)
			world_game_begin(stand, gp, gp + Vector3(0.4, rad * 2.0 + 1.6, rad * 2.0 + 4.6), gp + Vector3(0.0, rad * 1.1, 0.0))
			if npcs.has("heungbu"):
				world_move(npcs["heungbu"], gp + Vector3(-rad - 0.75, 0, 0.0), gp)
			var saw := Node3D.new()
			saw.position = gp + Vector3(0, rad * 2.0, 0.0)
			world_node(saw)
			add_mbox(saw, make_color(Color(0.42, 0.44, 0.5)), Vector3(rad * 2.0 + 1.4, 0.3, 0.04), Vector3(0, 0, 0))
			add_mbox(saw, make_color(Color(0.8, 0.82, 0.86)), Vector3(rad * 2.0 + 1.4, 0.05, 0.05), Vector3(0, -0.15, 0))
			for sx in [-(rad + 0.7), rad + 0.7]:
				add_mcyl(saw, wood_mat, 0.04, 0.04, 0.35, Vector3(sx, 0.1, 0))
			w["saw"] = saw
			w["gp"] = gp
			var cut := MeshInstance3D.new()
			var cb := BoxMesh.new()
			cb.size = Vector3(0.9, 1.0, 0.05)
			cut.mesh = cb
			cut.material_override = make_color(Color(0.95, 0.95, 0.85))
			world_node(cut)
			w["cut"] = cut
			w["dir_last"] = 1.0
		"ditch":
			var pd := Vector3(-34.5, 0, -3)
			var dig := pd + Vector3(3.8, 0, 1.2)
			var stand := dig + Vector3(0.0, 0, 1.0)
			world_game_begin(stand, dig, dig + Vector3(2.2, 2.4, 3.6), dig + Vector3(-0.3, 0.4, 0))
			if npcs.has("park"):
				world_move(npcs["park"], dig + Vector3(-0.9, 0, 0.9), dig)
			hold_tool("shovel")
			var pile := blob_node([[Vector3.ZERO, Vector3(0.7, 0.4, 0.6), Color(0.45, 0.33, 0.22)]])
			pile.position = dig + Vector3(1.0, 0.0, -0.3)
			pile.scale = Vector3(0.2, 0.2, 0.2)
			w["pile"] = pile
			var ch := MeshInstance3D.new()
			var chm := BoxMesh.new()
			chm.size = Vector3(1, 0.02, 0.5)
			ch.mesh = chm
			ch.material_override = water_material(2, Vector4(0, 0, 0.5, 0.25), Color(0.3, 0.42, 0.4), Color(0.45, 0.58, 0.5), Vector2(0.1, 0.0), 0.3)
			world_node(ch)
			w["channel"] = ch
			w["dig"] = dig
			w["pd"] = pd
		"snake":
			var nest := Vector3(-15.08, 2.0, 0.2)
			var stand := Vector3(-12.5, 0, 1.3)
			world_game_begin(stand, nest * Vector3(1, 0, 1), Vector3(-11.2, 2.7, 5.4), Vector3(-14.7, 0.9, 0.9))
			if npcs.has("heungbu"):
				world_move(npcs["heungbu"], Vector3(-10.6, 0, -0.6), nest * Vector3(1, 0, 1))
			hold_tool("stick")
			w["nest"] = nest
		"kim":
			var pumps := [Vector3(-26.5, 0, 16.8), Vector3(-22.3, 0, 17), Vector3(-25, 0, 18.5)]
			var mid: Vector3 = (pumps[0] + pumps[1] + pumps[2]) / 3.0
			var stand := mid + Vector3(2.4, 0, 0.6)
			world_game_begin(stand, mid, mid + Vector3(6.6, 4.8, 2.0), mid + Vector3(0.3, 0.2, 0.2))
			w["pumps"] = pumps
		"sparrow":
			var stand := FARM_C + Vector3(-5.2, 0, 1.6)
			world_game_begin(stand, FARM_C, FARM_C + Vector3(-8.4, 5.6, 5.4), FARM_C + Vector3(-1.2, 0.3, 0.6))
			for s2 in sparrows:
				world_hide(s2[0])
		"rice":
			var wife: Node3D = npcs["wife"]
			var wp := wife.position
			for lb in wife.find_children("*", "Label3D", true, false):
				world_hide(lb)
			var stand := wp + Vector3(0, 0, 2.6)
			world_game_begin(stand, wp, wp + Vector3(0.0, 2.3, 7.4), wp + Vector3(0, 2.9, 1.4))
			var bowl := blob_node([[Vector3.ZERO, Vector3(0.6, 0.22, 0.6), Color(0.86, 0.76, 0.5)], [Vector3(0, 0.08, 0), Vector3(0.48, 0.08, 0.48), Color(0.98, 0.97, 0.92)]], thatch_blob_mat)
			w["bowl"] = bowl
			w["items"] = {}
			w["center"] = stand
			w["depth"] = cam_depth_of(stand + Vector3(0, 2.4, 0), wp + Vector3(0.0, 2.3, 7.4))
		"plant":
			var stand := FARM_C + Vector3(-3.0, 0, 1.2)
			world_game_begin(stand, stand + Vector3(1, 0, -0.9), stand + Vector3(5.6, 3.4, -0.9), stand + Vector3(1.2, 0.3, -0.9))
			var line := MeshInstance3D.new()
			var lb := BoxMesh.new()
			lb.size = Vector3(0.02, 0.02, 2.6)
			line.mesh = lb
			line.material_override = make_color(Color(0.95, 0.9, 0.75))
			world_node(line)
			w["rope"] = line
			var marks := []
			for k in 4:
				var mk := blob_node([[Vector3.ZERO, Vector3(0.07, 0.07, 0.07), Color(0.9, 0.2, 0.15)]])
				marks.append(mk)
			w["marks"] = marks
			var bundle := blob_node([[Vector3(0, 0.15, 0), Vector3(0.12, 0.35, 0.12), Color(0.45, 0.72, 0.3)], [Vector3(0, 0.0, 0), Vector3(0.1, 0.1, 0.1), Color(0.99, 0.83, 0.69)]])
			w["bundle"] = bundle
			var ring := MeshInstance3D.new()
			var tm := TorusMesh.new()
			tm.inner_radius = 0.2
			tm.outer_radius = 0.3
			tm.rings = 32
			ring.mesh = tm
			var rmat := StandardMaterial3D.new()
			rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			rmat.albedo_color = Color(1.0, 0.85, 0.15)
			rmat.no_depth_test = true
			rmat.render_priority = 5
			ring.material_override = rmat
			ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			world_node(ring)
			w["ring"] = ring
			w["planted"] = []
			w["base"] = stand + Vector3(0.9, 0, -1.0)
			farm_stages_hidden_for_plant()
			if has_node("Scarecrow"):
				world_hide(get_node("Scarecrow"))

func farm_stages_hidden_for_plant() -> void:
	for st in farm_stages:
		world_hide(st)

func cam_depth_of(target: Vector3, cam_pos: Vector3) -> float:
	return target.distance_to(cam_pos)

func plant_world_pos(row: int, col: int) -> Vector3:
	var base: Vector3 = w["base"]
	return base + Vector3(row * 0.75, 0.12, (1.5 - col) * 0.55)

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

func make_south() -> void:
	make_fishing_pond()
	make_farm()

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

func make_fishing_pond() -> void:
	var c := POND_C
	var rx := 5.6
	var rz := 4.0
	var r := RandomNumberGenerator.new()
	r.seed = 33
	var none := Color(0, 0, 0, 0)
	flat_ellipse(c, rx, rz, 0.06, water_material(1, Vector4(c.x, c.z, rx, rz), Color(0.12, 0.36, 0.52), Color(0.42, 0.68, 0.72)))
	# 물가 돌 (나루터 쪽은 비워요)
	var stones := []
	var a := 0.0
	while a < TAU:
		a += r.randf_range(0.18, 0.3)
		if absf(wrapf(a, -PI, PI)) < 0.3:
			continue
		var k := r.randf_range(0.0, 0.35)
		stones.append([c + Vector3(cos(a) * (rx + 0.3 + k), 0.08, sin(a) * (rz + 0.3 + k)), Vector3(r.randf_range(0.5, 1.0), r.randf_range(0.3, 0.55), r.randf_range(0.45, 0.8)), stone_color(r)])
	add_blobs(self, stones, stone_blob_mat)
	# 갈대와 부들
	var reeds := []
	for ang in [2.2, 2.55, 3.5, 3.9, 1.3, 4.9, 5.4]:
		var base := c + Vector3(cos(ang) * rx * 0.93, 0, sin(ang) * rz * 0.93)
		for i in 7:
			var p := base + Vector3(r.randf_range(-0.5, 0.5), 0, r.randf_range(-0.4, 0.4))
			var hgt := r.randf_range(0.9, 1.5)
			var tilt := Vector3(r.randf_range(-12, 12), 0, r.randf_range(-12, 12))
			reeds.append([p + Vector3(0, hgt * 0.5, 0), Vector3(0.05, hgt, 0.05), Color(0.42, 0.62, 0.28), tilt])
			if i % 2 == 0:
				reeds.append([p + Vector3(0, hgt * 0.85, 0), Vector3(0.1, 0.3, 0.1), Color(0.48, 0.3, 0.16), tilt])
			else:
				reeds.append([p + Vector3(0.06, hgt * 0.35, 0), Vector3(0.16, hgt * 0.6, 0.04), Color(0.5, 0.7, 0.32), tilt + Vector3(0, 0, 18)])
	add_blobs(self, reeds)
	# 연잎과 연꽃
	var pads := []
	for i in 9:
		var pa := r.randf_range(0.5, TAU - 0.5)
		var pr := r.randf_range(0.35, 0.8)
		var p := c + Vector3(cos(pa) * rx * pr, 0.085, sin(pa) * rz * pr)
		pads.append([p, Vector3(0.75, 0.04, 0.65), Color(0.36, 0.62, 0.3).lerp(Color(0.48, 0.7, 0.34), r.randf())])
		if i % 3 == 0:
			pads.append([p + Vector3(0.1, 0.08, 0), Vector3(0.24, 0.16, 0.24), Color(1.0, 0.7, 0.8)])
			pads.append([p + Vector3(0.1, 0.14, 0), Vector3(0.1, 0.08, 0.1), Color(1.0, 0.92, 0.5)])
	add_blobs(self, pads, null, true)
	# 나루터 (나무 발판)
	for i in 8:
		var plank := add_mbox(self, plank_mat, Vector3(0.42, 0.08, 1.45 + r.randf_range(-0.08, 0.08)), Vector3(c.x + rx + 0.3 - i * 0.48, 0.12, c.z + r.randf_range(-0.04, 0.04)))
		plank.rotation.y = r.randf_range(-0.04, 0.04)
	for px in [c.x + rx - 3.0, c.x + rx - 1.4]:
		for pz in [-0.72, 0.72]:
			add_mcyl(self, dark_wood_mat, 0.07, 0.08, 0.7, Vector3(px, 0.1, c.z + pz))
	# 꽂아 둔 낚싯대와 동동 뜬 찌
	var tip := Vector3(c.x + rx - 4.6, 1.9, c.z + 1.3)
	pond_deco.append(add_beam(self, make_color(Color(0.55, 0.42, 0.22)), Vector3(c.x + rx - 2.8, 0.2, c.z + 0.6), tip, 0.04, 0.04))
	var bob_pos := Vector3(c.x + rx - 5.4, 0.1, c.z + 1.6)
	pond_deco.append(add_beam(self, make_color(Color(0.95, 0.95, 0.95)), tip, bob_pos, 0.012, 0.012))
	var bob := Node3D.new()
	bob.position = bob_pos
	add_child(bob)
	add_ball(bob, Color(0.9, 0.2, 0.2), 0.08, Vector3(0, 0.04, 0))
	add_ball(bob, Color(1, 1, 1), 0.07, Vector3(0, -0.02, 0))
	sway_items.append([bob, bob_pos, 0, 1.3, 0.0])
	pond_deco.append(bob)
	# 물이 막아요 (나루터 자리는 열어 둬요)
	add_solid(Vector3(c.x - 0.8, 1, c.z), Vector3(8.0, 2, 6.0), none)
	add_solid(Vector3(c.x - 5.2, 1, c.z), Vector3(0.8, 2, 3.4), none)
	add_solid(Vector3(c.x + 4.2, 1, c.z - 1.67), Vector3(2.0, 2, 1.85), none)
	add_solid(Vector3(c.x + 4.2, 1, c.z + 1.68), Vector3(2.0, 2, 1.85), none)
	var spot := make_spot(Vector3(c.x + rx - 2.0, 0, c.z), "fish", "", "낚시터", true)
	spot.visible = true
	make_basket(Vector3(c.x + rx + 0.9, 0, c.z - 1.3), 0.9, Color(0.62, 0.68, 0.74))
	make_npc("fisher", "강태공", Color(0.5, 0.6, 0.66), Vector3(c.x + rx + 1.6, 0, c.z + 2.0), 1.0, true)
	make_tree(Vector3(c.x - 5.8, 0, c.z - 4.8), "Willow0")
	make_tree(Vector3(c.x - 6.3, 0, c.z + 4.6), "Willow0")
	house_rects.append(Rect2(c.x - rx - 0.4, c.z - rz - 0.4, rx * 2.0 + 0.8, rz * 2.0 + 0.8))

func make_farm() -> void:
	var c := FARM_C
	var w := 9.0
	var d := 7.0
	var r := RandomNumberGenerator.new()
	r.seed = 44
	var earth := make_tex_material(Color(0.6, 0.5, 0.34), plaster_tex, 0.4)
	add_mbox(self, earth, Vector3(w + 0.5, 0.25, 0.5), c + Vector3(0, 0.12, d / 2.0))
	add_mbox(self, earth, Vector3(w + 0.5, 0.25, 0.5), c + Vector3(0, 0.12, -d / 2.0))
	add_mbox(self, earth, Vector3(0.5, 0.25, d), c + Vector3(w / 2.0, 0.12, 0))
	add_mbox(self, earth, Vector3(0.5, 0.25, d), c + Vector3(-w / 2.0, 0.12, 0))
	add_mbox(self, earth, Vector3(0.4, 0.2, d), c + Vector3(0, 0.1, 0))
	add_mbox(self, make_color(Color(0.42, 0.34, 0.24)), Vector3(w - 0.4, 0.04, d - 0.4), c + Vector3(0, 0.02, 0))
	var wtr := add_mbox(self, water_material(2, Vector4(c.x, c.z, w / 2.0 - 0.2, d / 2.0 - 0.2), Color(0.36, 0.44, 0.36), Color(0.52, 0.6, 0.48), Vector2.ZERO, 0.25), Vector3(w - 0.4, 0.02, d - 0.4), c + Vector3(0, 0.08, 0))
	wtr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# 자라는 단계마다 벼 모양을 따로 만들어 두고 바꿔 보여 줘요
	var young := []
	var green := []
	var gold := []
	var nx := 12
	var nz := 8
	for ix in nx:
		for iz in nz:
			var p := c + Vector3(-w / 2.0 + 0.55 + ix * (w - 1.1) / (nx - 1), 0, -d / 2.0 + 0.55 + iz * (d - 1.1) / (nz - 1))
			if absf(p.x - c.x) < 0.4 or (absf(p.x - c.x - 1.5) < 0.55 and absf(p.z - c.z) < 0.55):
				continue
			p += Vector3(r.randf_range(-0.05, 0.05), 0, r.randf_range(-0.05, 0.05))
			young.append([p + Vector3(0, 0.2, 0), Vector3(0.09, 0.28, 0.09), Color(0.5, 0.76, 0.32)])
			young.append([p + Vector3(0.04, 0.22, 0), Vector3(0.045, 0.24, 0.045), Color(0.6, 0.82, 0.38), Vector3(0, 0, -22)])
			var rot := r.randf_range(0, 180)
			for k in 3:
				var lean := Vector3(0, rot + k * 60.0, -14.0 + k * 14.0)
				green.append([p + Vector3((k - 1) * 0.06, 0.4, 0), Vector3(0.07, 0.8, 0.07), Color(0.36, 0.62, 0.25).lerp(Color(0.5, 0.74, 0.32), k / 2.0), lean])
				gold.append([p + Vector3((k - 1) * 0.06, 0.38, 0), Vector3(0.06, 0.76, 0.06), Color(0.8, 0.68, 0.3).lerp(Color(0.9, 0.78, 0.36), k / 2.0), lean])
			# 고개 숙인 이삭
			for k in 2:
				var sx := -1.0 if k == 0 else 1.0
				gold.append([p + Vector3(sx * 0.13, 0.74, 0.0), Vector3(0.09, 0.22, 0.07), Color(0.98, 0.82, 0.34), Vector3(0, rot, sx * -50.0)])
	farm_stages = [add_blobs(self, young), add_blobs(self, green), add_blobs(self, gold)]
	# 허수아비
	var sc := Node3D.new()
	sc.name = "Scarecrow"
	sc.position = c + Vector3(1.5, 0, 0)
	sc.rotation.y = -0.4
	add_child(sc)
	var pole := make_color(Color(0.55, 0.4, 0.24))
	add_mcyl(sc, pole, 0.06, 0.07, 2.1, Vector3(0, 1.05, 0))
	add_beam(sc, pole, Vector3(-0.95, 1.45, 0), Vector3(0.95, 1.45, 0), 0.08, 0.08)
	add_mbox(sc, plaster_mat(Color(0.78, 0.66, 0.5)), Vector3(0.75, 0.75, 0.4), Vector3(0, 1.28, 0))
	add_mbox(sc, make_color(Color(0.55, 0.62, 0.78)), Vector3(0.25, 0.22, 0.42), Vector3(0.18, 1.18, 0.0))
	add_mbox(sc, plaster_mat(Color(0.78, 0.66, 0.5)), Vector3(1.5, 0.22, 0.3), Vector3(0, 1.48, 0))
	add_blobs(sc, [
		[Vector3(0, 1.98, 0), Vector3(0.55, 0.55, 0.5), Color(0.96, 0.88, 0.62)],
		[Vector3(-0.85, 1.42, 0), Vector3(0.28, 0.2, 0.2), Color(0.95, 0.85, 0.55)],
		[Vector3(0.85, 1.42, 0), Vector3(0.28, 0.2, 0.2), Color(0.95, 0.85, 0.55)],
		[Vector3(0, 0.88, 0), Vector3(0.6, 0.18, 0.36), Color(0.95, 0.85, 0.55)],
	], thatch_blob_mat)
	# 밀짚모자, 얼굴
	add_mcyl(sc, thatch_dark_mat, 0.52, 0.55, 0.04, Vector3(0, 2.2, 0))
	add_mcyl(sc, thatch_dark_mat, 0.16, 0.26, 0.22, Vector3(0, 2.33, 0))
	for ex in [-0.11, 0.11]:
		add_ball(sc, Color(0.15, 0.1, 0.08), 0.045, Vector3(ex, 2.02, 0.25))
		add_ball(sc, Color(1.0, 0.55, 0.55), 0.05, Vector3(ex * 1.7, 1.93, 0.22))
	add_beam(sc, make_color(Color(0.5, 0.2, 0.15)), Vector3(-0.08, 1.88, 0.26), Vector3(0.08, 1.88, 0.26), 0.02, 0.02)
	sway_items.append([sc, sc.position, 1, 2.0, 0.025])
	# 참새 (참새 떼가 몰려오면 보여요)
	for i in 6:
		var sp := Node3D.new()
		var pos := c + Vector3(r.randf_range(-3.6, 3.6), 0.95, r.randf_range(-2.8, 2.8))
		sp.position = pos
		sp.rotation.y = r.randf() * TAU
		add_child(sp)
		add_blobs(sp, [
			[Vector3(0, 0, 0), Vector3(0.26, 0.2, 0.32), Color(0.6, 0.42, 0.28)],
			[Vector3(0, 0.1, 0.13), Vector3(0.17, 0.16, 0.16), Color(0.55, 0.32, 0.2)],
			[Vector3(0, 0.07, 0.18), Vector3(0.12, 0.08, 0.08), Color(0.98, 0.95, 0.9)],
			[Vector3(0, 0.02, -0.2), Vector3(0.1, 0.05, 0.16), Color(0.45, 0.3, 0.2)],
			[Vector3(0, 0.1, 0.23), Vector3(0.05, 0.04, 0.06), Color(0.3, 0.25, 0.2)],
		])
		sp.visible = false
		sparrows.append([sp, pos])
	# 논 앞 팻말, 논 주인, 볏짚단
	make_spot(Vector3(c.x - w / 2.0 - 0.9, 0, c.z), "farm", "", "최 영감네 논", true)
	make_npc("choi", "최 영감", Color(0.62, 0.55, 0.42), Vector3(c.x - w / 2.0 - 1.8, 0, c.z - 3.4), 1.0, true)
	var stack := Node3D.new()
	stack.position = c + Vector3(w / 2.0 + 1.8, 0, -2.2)
	add_child(stack)
	make_haystack_visual(stack)
	add_solid(stack.position + Vector3(0, 0.4, 0), Vector3(1.6, 0.8, 1.2), Color(0, 0, 0, 0))
	house_rects.append(Rect2(c.x - w / 2.0 - 0.4, c.z - d / 2.0 - 0.4, w + 0.8, d + 0.8))
	farm_visual()

func farm_visual() -> void:
	if farm_stages.size() < 3:
		return
	var stage := -1
	if farm_state == 1 or farm_state == 2:
		stage = 0
	elif farm_state == 3:
		stage = 1
	elif farm_state == 4:
		stage = 2
	for i in 3:
		(farm_stages[i] as Node3D).visible = (i == stage)
	for s in sparrows:
		(s[0] as Node3D).visible = farm_state == 2

func update_south(delta: float) -> void:
	update_walk_hint(delta)
	update_wild(delta)
	if farm_state == 1 or farm_state == 3:
		farm_timer -= delta
		if farm_timer <= 0.0:
			farm_state += 1
			farm_visual()
			if farm_state == 2:
				float_text("참새 떼가 논에 몰려왔어요!", Vector2(short_side * 0.5, 300), Color(1, 0.9, 0.6), 1.0)
			else:
				float_text("최 영감네 벼가 누렇게 익었어요!", Vector2(short_side * 0.5, 300), Color(1, 0.9, 0.4), 1.0)
	if farm_state == 2:
		for i in sparrows.size():
			var node: Node3D = sparrows[i][0]
			var base: Vector3 = sparrows[i][1]
			var hop := absf(sin(anim_t * 5.0 + i * 1.7))
			node.position = base + Vector3(0, hop * 0.18, 0)
			node.rotation.x = 0.5 * maxf(0.0, sin(anim_t * 9.0 + i))

func farm_action_text() -> String:
	match farm_state:
		-1: return "논 살펴보기"
		0: return "모내기"
		2: return "참새 쫓기"
		4: return "벼 베기"
	return "벼 살펴보기"

# --- 저장 (도감은 다음에 와도 남아 있어요) ---

func load_south() -> void:
	var cf := ConfigFile.new()
	if cf.load("user://save.cfg") != OK:
		return
	var got: Array = cf.get_value("ch1", "fish", [])
	for i in mini(got.size(), fish_caught.size()):
		fish_caught[i] = int(got[i])
	fish_reward = cf.get_value("ch1", "fish_reward", false)
	harvests = cf.get_value("ch1", "harvests", 0)
	var hg: Array = cf.get_value("ch1", "herbs", [])
	for i in mini(hg.size(), herb_counts.size()):
		herb_counts[i] = int(hg[i])
	herb_reward = cf.get_value("ch1", "herb_reward", false)
	var sr: Array = cf.get_value("ch1", "story", [])
	for i in mini(sr.size(), story_read.size()):
		story_read[i] = bool(sr[i])

func save_south() -> void:
	var cf := ConfigFile.new()
	cf.load("user://save.cfg")
	cf.set_value("ch1", "fish", fish_caught)
	cf.set_value("ch1", "fish_reward", fish_reward)
	cf.set_value("ch1", "harvests", harvests)
	cf.set_value("ch1", "herbs", herb_counts)
	cf.set_value("ch1", "herb_reward", herb_reward)
	cf.set_value("ch1", "story", story_read)
	cf.save("user://save.cfg")

# --- 낚시 ---

func fish_kinds_found() -> int:
	var n := 0
	for k in fish_caught:
		if int(k) > 0:
			n += 1
	return n

func fish_book() -> String:
	var parts := []
	for i in FISH.size():
		if int(fish_caught[i]) > 0:
			parts.append("%s %d마리" % [FISH[i]["name"], fish_caught[i]])
		else:
			parts.append("???")
	return "물고기 도감 %d/%d\n%s" % [fish_kinds_found(), FISH.size(), ", ".join(parts)]

func fish_how() -> Array:
	return [
		["강태공", "찌가 쏙 들어가면 바로 화면을 눌러 낚싯대를 채거라. 너무 일찍 채면 물고기가 놀라 도망간단다."],
		["강태공", "물고기가 걸리면 화면을 꾹 눌렀다 뗐다 하며 초록 칸 안에 물고기를 붙잡아 두거라."],
	]

func talk_fisher() -> void:
	if not fisher_met:
		fisher_met = true
		say([["강태공", "허허, 세월을 낚는 중이란다. 너도 한번 해 보겠느냐? 나루터 끝의 낚싯대를 쓰거라."]] + fish_how() + [["강태공", "물고기는 모두 여섯 가지. 금빛 잉어는 나도 평생 두 번밖에 못 봤단다."]], Callable())
		return
	var lines := [["강태공", fish_book()]]
	if fish_kinds_found() >= FISH.size():
		lines.append(["강태공", "허허, 이 연못 물고기를 다 낚아 보다니! 네가 진짜 강태공이로구나."])
	else:
		lines.append(["강태공", "물고기마다 힘이 달라. 큰 놈일수록 초록 칸에 붙잡아 두기 어렵단다."])
	say(lines, Callable())

func start_fishing() -> void:
	if not fisher_met:
		fisher_met = true
		say([["강태공", "낚시는 처음이냐? 내 알려 주마."]] + fish_how(), start_fishing)
		return
	start_fishing3d()

func pick_fish() -> int:
	var total := 0
	for f in FISH:
		total += int(f["w"])
	var roll := rng.randi_range(1, total)
	for i in FISH.size():
		roll -= int(FISH[i]["w"])
		if roll <= 0:
			return i
	return 0

func fish_done(ok: bool, _good: bool) -> void:
	if not ok:
		say([["", "물고기가 모두 달아났다. 다시 해 보자."]], Callable())
		return
	var f: Dictionary = FISH[fish_kind]
	var first := int(fish_caught[fish_kind]) == 0
	fish_caught[fish_kind] = int(fish_caught[fish_kind]) + 1
	var pay: int = f["pay"]
	earn(pay)
	var lines := []
	if first:
		lines.append(["", "%s를 낚았다! 처음 보는 물고기다. (물고기 도감 %d/%d)" % [f["name"], fish_kinds_found(), FISH.size()]])
	else:
		lines.append(["", "%s를 낚았다! (%d마리째)" % [f["name"], fish_caught[fish_kind]]])
	lines.append(["", "장터에 팔아 엽전 %d냥을 받았다." % pay])
	if fish_kinds_found() >= FISH.size() and not fish_reward:
		fish_reward = true
		earn(50)
		lines.append(["강태공", "허허! 여섯 가지 물고기를 다 낚았구나. 상으로 엽전 50냥을 주마!"])
	save_south()
	say(lines, Callable())

func fish_tap() -> void:
	var at := Vector2(mg_overlay.size.x * 0.42, mg_overlay.size.y * 0.58)
	if mg_step == 0:
		mg_lives -= 1
		mg_perfect = false
		mg_timer = rng.randf_range(1.6, 3.2)
		sfx("bad")
		shake(10)
		float_text("너무 일찍 챘어요!", at, Color(1, 0.6, 0.5), 1.1)
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
		float_text("걸렸다!", at, Color(1, 1, 1), 1.3)

func update_fish(delta: float) -> void:
	mg_phase += delta
	var at := Vector2(mg_overlay.size.x * 0.42, mg_overlay.size.y * 0.58)
	if mg_step == 0:
		mg_timer -= delta
		mg_info.text = "찌를 잘 보세요... | 남은 기회 %d" % mg_lives
		if mg_timer <= 0.0:
			fish_kind = pick_fish()
			mg_step = 1
			mg_timer = lerpf(0.95, 0.6, FISH[fish_kind]["hard"])
			sfx("pop", 0.7)
			shake(4)
	elif mg_step == 1:
		mg_timer -= delta
		mg_info.text = "지금이에요! 눌러요!"
		if mg_timer <= 0.0:
			mg_step = 0
			mg_timer = rng.randf_range(1.5, 3.2)
			float_text("미끼만 먹고 갔어요...", at, Color(1, 1, 1), 1.0)
	else:
		var hard: float = FISH[fish_kind]["hard"]
		if mg_touch:
			mg_speed += 2.6 * delta
		else:
			mg_speed -= 2.2 * delta
		mg_speed = clampf(mg_speed, -1.1, 1.1)
		mg_off += mg_speed * delta
		if mg_off <= 0.0 or mg_off >= 1.0:
			mg_off = clampf(mg_off, 0.0, 1.0)
			mg_speed = 0.0
		mg_frame_angle -= delta
		if mg_frame_angle <= 0.0:
			mg_dir = rng.randf_range(0.05, 0.95)
			mg_frame_angle = rng.randf_range(lerpf(1.5, 0.45, hard), lerpf(2.4, 1.0, hard))
		mg_trail = move_toward(mg_trail, mg_dir, delta * lerpf(0.22, 0.85, hard))
		mg_trail = clampf(mg_trail + sin(mg_phase * 9.0) * 0.004 * hard, 0.0, 1.0)
		var half := lerpf(0.16, 0.1, hard)
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
			float_text("줄이 풀려 놓쳤어요!", at, Color(1, 0.6, 0.5), 1.1)
		else:
			mg_info.text = "꾹 누르면 초록 칸이 올라가요 | 남은 기회 %d" % mg_lives

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
	if kind == 4:
		for k in [-1.0, 1.0]:
			d_line(ci, c + Vector2(s * ln * 0.8, s * 0.05).rotated(rot), c + Vector2(s * ln * 1.25, k * s * 0.35).rotated(rot), col.darkened(0.3), 3)
	if kind == 5:
		for k in 3:
			ci.draw_circle(c + Vector2((k - 1) * s * 0.35, -s * 0.05).rotated(rot), s * 0.08, Color(1, 1, 0.85, 0.8))

func draw_bobber(ci: CanvasItem, c: Vector2, s: float) -> void:
	d_line(ci, c + Vector2(0, -s * 1.3), c, Color(0.95, 0.4, 0.3), 4)
	d_ell(ci, c, s * 0.42, s * 0.55, Color(0.92, 0.25, 0.22), 0.0, 3.0)
	d_ell(ci, c + Vector2(0, s * 0.3), s * 0.42, s * 0.28, Color(1, 1, 0.97), 0.0, 2.0)

func draw_pond_scene(ci: CanvasItem) -> void:
	var w := mg_overlay.size.x
	var h := mg_overlay.size.y
	var pc := Vector2(w * 0.42, h * 0.6)
	var rx := w * 0.38
	var ry := h * 0.17
	d_ell(ci, pc, rx + 14, ry + 12, Color(0.56, 0.46, 0.32), 0.0, 0.0)
	d_ell(ci, pc, rx, ry, Color(0.42, 0.7, 0.9), 0.0, 4.0)
	d_ell(ci, pc + Vector2(0, ry * 0.15), rx * 0.6, ry * 0.5, Color(0.36, 0.62, 0.84), 0.0, 0.0)
	# 물결 반짝이
	for k in 5:
		var gx := pc.x + sin(anim_t * 0.6 + k * 1.9) * rx * 0.6
		var gy := pc.y + cos(k * 2.3) * ry * 0.6
		d_line(ci, Vector2(gx - 16, gy), Vector2(gx + 16, gy), Color(1, 1, 1, 0.45), 3)
	# 연잎
	for lp in [[-0.7, -0.3], [-0.55, 0.45], [0.65, 0.5], [0.72, -0.4]]:
		var lc := pc + Vector2(rx * lp[0], ry * lp[1])
		d_ell(ci, lc, 30, 16, Color(0.4, 0.66, 0.32), 0.0, 3.0)
		d_line(ci, lc, lc + Vector2(26, -6), Color(0.42, 0.7, 0.9), 4)
	ci.draw_circle(pc + Vector2(rx * 0.72, -ry * 0.4) + Vector2(-6, -8), 9, Color(1, 0.72, 0.82))
	# 갈대
	for rd in [-0.95, -0.88, -0.8, 0.86, 0.93]:
		var base := pc + Vector2(rx * rd, ry * 0.55)
		var top := base + Vector2(sin(anim_t * 1.3 + rd * 5.0) * 6.0, -h * 0.12)
		d_line(ci, base, top, Color(0.38, 0.58, 0.26), 5)
		d_ell(ci, top + Vector2(0, 14), 7, 20, Color(0.5, 0.32, 0.18), 0.0, 2.0)
	# 낚싯대와 줄
	var hold := Vector2(w * 0.06, h * 0.86)
	var bend := 0.0
	if mg_step >= 2:
		bend = 0.12 + sin(anim_t * 14.0) * 0.03
	var tip := hold + Vector2(w * 0.34, -h * 0.34).rotated(bend)
	var mid := hold.lerp(tip, 0.5) + Vector2(0, 20 + bend * 200.0)
	ci.draw_polyline(PackedVector2Array([hold, mid, tip]), Color(0.55, 0.38, 0.2), 9, true)
	d_ell(ci, hold + Vector2(10, -10), 16, 26, Color(0.6, 0.45, 0.25), -0.7, 3.0)
	var bob := pc + Vector2(0, -ry * 0.1)
	if mg_step == 0:
		var nibble := 0.0
		if fmod(mg_phase, 1.7) < 0.15:
			nibble = 5.0
		bob.y += sin(mg_phase * 2.2) * 4.0 + nibble
		d_line(ci, tip, bob + Vector2(0, -18), Color(1, 1, 1, 0.85), 2)
		draw_bobber(ci, bob, 18)
		ci.draw_polyline(ell_pts(bob + Vector2(0, 8), 30 + sin(mg_phase * 2.2) * 4.0, 8), Color(1, 1, 1, 0.5), 2, true)
	elif mg_step == 1:
		bob.y += 16
		d_line(ci, tip, bob + Vector2(0, -6), Color(1, 1, 1, 0.85), 2)
		d_line(ci, bob + Vector2(0, -6), bob + Vector2(0, -18), Color(0.95, 0.4, 0.3), 4)
		for k in 3:
			var rr := 20.0 + fmod(mg_phase * 70.0 + k * 22.0, 66.0)
			ci.draw_polyline(ell_pts(bob, rr, rr * 0.3), Color(1, 1, 1, 0.8 - rr / 90.0), 3, true)
		ci.draw_string(font, bob + Vector2(-16, -40), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, int(font_size * 2.0), Color(0.95, 0.25, 0.2))
	else:
		# 물고기가 이리저리 버둥대요 (그림자만 보여요)
		var fx := pc.x + (mg_trail - 0.5) * rx * 1.3
		var fpos := Vector2(fx, pc.y + sin(mg_phase * 3.0) * ry * 0.25)
		var dirv := signf(mg_dir - mg_trail)
		if dirv == 0.0:
			dirv = 1.0
		draw_fish2d(ci, fpos, 34, fish_kind, 0.0 if dirv > 0.0 else PI, true)
		d_line(ci, tip, fpos, Color(1, 1, 1, 0.9), 2)
		for k in 2:
			var rr := 26.0 + fmod(mg_phase * 60.0 + k * 30.0, 60.0)
			ci.draw_polyline(ell_pts(fpos, rr, rr * 0.3), Color(1, 1, 1, 0.6 - rr / 120.0), 3, true)
		# 오른쪽 힘겨루기 칸
		var mx := w * 0.88
		var y0 := h * 0.4
		var y1 := h * 0.82
		var span := y1 - y0
		d_box(ci, Vector2(mx, (y0 + y1) / 2.0), Vector2(54, span + 20), 0.0, Color(0.62, 0.45, 0.28), 4)
		d_box(ci, Vector2(mx, (y0 + y1) / 2.0), Vector2(38, span), 0.0, Color(0.3, 0.5, 0.66), 0.0)
		var hard: float = FISH[fish_kind]["hard"]
		var half := lerpf(0.16, 0.1, hard)
		var zone_c := y1 - mg_off * span
		var inside := mg_step == 2
		var z_top := maxf(zone_c - half * span, y0)
		var z_bot := minf(zone_c + half * span, y1)
		d_box(ci, Vector2(mx, (z_top + z_bot) / 2.0), Vector2(40, z_bot - z_top), 0.0, Color(0.45, 0.9, 0.45, 0.85) if inside else Color(0.6, 0.85, 0.5, 0.6), 3)
		draw_fish2d(ci, Vector2(mx, y1 - mg_trail * span), 17, fish_kind, -PI / 2.0 + sin(anim_t * 10.0) * 0.3, true)

# --- 모내기 ---

func plant_slot(row: int, col: int) -> Vector2:
	var w := mg_overlay.size.x
	var h := mg_overlay.size.y
	var sc := 1.0 - row * 0.12
	return Vector2(w * 0.5 + (col - 1.5) * w * 0.2 * sc, h * (0.76 - row * 0.12))

func plant_cursor_x() -> float:
	var w := mg_overlay.size.x
	var row := mini(mg_count / 4, 2)
	var sc := 1.0 - row * 0.12
	return w * 0.5 + w * 0.36 * sc * sin(mg_phase)

func plant_tap() -> void:
	if mg_count >= 12:
		return
	var row := mg_count / 4
	var col := mg_count % 4
	var target := plant_slot(row, col)
	var cx := plant_cursor_x()
	if absf(cx - target.x) < mg_overlay.size.x * 0.05:
		mg_items.append([row, col, cx - target.x])
		mg_count += 1
		sfx("pop", 1.0 + mg_count * 0.04)
		shake(3)
		burst(target, Color(0.6, 0.9, 0.5), 7)
		float_text(["쏙!", "착!", "꾹!"][mg_count % 3], target + Vector2(0, -40), Color(1, 1, 1), 1.0)
	else:
		mg_lives -= 1
		mg_perfect = false
		sfx("bad")
		shake(10)
		flash(Color(1, 0.3, 0.3))
		float_text("삐뚤빼뚤!", Vector2(cx, target.y - 40), Color(1, 0.6, 0.5), 1.1)

func update_plant(delta: float) -> void:
	var row := mini(mg_count / 4, 2)
	mg_phase += delta * (1.7 + row * 0.45)
	mg_progress = float(mg_count) / 12.0
	mg_info.text = "모 %d/12 | 남은 기회 %d" % [mg_count, mg_lives]

func draw_seedling(ci: CanvasItem, c: Vector2, s: float, lean: float) -> void:
	for k in 5:
		var a := -0.5 + k * 0.25 + lean
		d_line(ci, c, c + Vector2(0, -s).rotated(a), Color(0.42, 0.7, 0.3).lerp(Color(0.6, 0.82, 0.38), k / 4.0), 5)

func draw_plant_scene(ci: CanvasItem) -> void:
	var w := mg_overlay.size.x
	var h := mg_overlay.size.y
	var top := h * 0.44
	var bot := h * 0.83
	var field := PackedVector2Array([Vector2(w * 0.16, top), Vector2(w * 0.84, top), Vector2(w * 0.98, bot), Vector2(w * 0.02, bot)])
	d_poly(ci, PackedVector2Array([field[0] + Vector2(-14, -12), field[1] + Vector2(14, -12), field[2] + Vector2(14, 12), field[3] + Vector2(-14, 12)]), Color(0.62, 0.5, 0.34), 3.0)
	d_poly(ci, field, Color(0.5, 0.62, 0.66), 3.0)
	for k in 4:
		var gy := lerpf(top, bot, 0.15 + k * 0.23)
		var gx := w * 0.5 + sin(anim_t * 0.5 + k * 2.0) * w * 0.25
		d_line(ci, Vector2(gx - 20, gy), Vector2(gx + 20, gy), Color(1, 1, 1, 0.4), 3)
	var row := mini(mg_count / 4, 2)
	# 못줄: 지금 심는 줄에 빨간 눈금
	if mg_count < 12:
		var a := plant_slot(row, 0) + Vector2(-w * 0.12 * (1.0 - row * 0.12), 0)
		var b := plant_slot(row, 3) + Vector2(w * 0.12 * (1.0 - row * 0.12), 0)
		d_line(ci, a, b, Color(0.95, 0.9, 0.75), 3)
		for col in 4:
			var p := plant_slot(row, col)
			if col == mg_count % 4:
				var pulse := 1.0 + sin(anim_t * 8.0) * 0.15
				ci.draw_polyline(ell_pts(p, 26 * pulse, 12 * pulse), Color(1, 0.9, 0.3), 4, true)
			ci.draw_circle(p, 6, Color(0.9, 0.25, 0.2))
	for it in mg_items:
		var p := plant_slot(it[0], it[1]) + Vector2(it[2], 0)
		draw_seedling(ci, p, 46 * (1.0 - it[0] * 0.12), float(it[2]) * 0.01)
	# 모 한 움큼을 든 손
	if mg_count < 12:
		var cx := plant_cursor_x()
		var target := plant_slot(row, mg_count % 4)
		var near := absf(cx - target.x) < w * 0.05
		var hp := Vector2(cx, target.y - 60)
		draw_seedling(ci, hp + Vector2(0, 30), 50, 0.0)
		d_ell(ci, hp + Vector2(0, 34), 24, 18, Color(0.99, 0.83, 0.69), 0.0, 3.0)
		d_box(ci, hp + Vector2(0, 62), Vector2(30, 26), 0.0, Color(0.85, 0.78, 0.6), 3.0)
		if near:
			ci.draw_polyline(ell_pts(hp + Vector2(0, 34), 36, 30), Color(0.5, 1.0, 0.5), 4, true)

# --- 참새 쫓기 ---

func draw_sparrow2d(ci: CanvasItem, c: Vector2, s: float, danger: float, flap: float) -> void:
	var brown := Color(0.62, 0.42, 0.26).lerp(Color(0.85, 0.35, 0.25), danger * 0.5)
	d_poly(ci, PackedVector2Array([c + Vector2(-s * 0.5, 0), c + Vector2(-s * 1.0, -s * 0.25), c + Vector2(-s * 0.95, s * 0.15)]), brown.darkened(0.2), 3)
	d_ell(ci, c, s * 0.62, s * 0.45, brown, 0.0, 3.0)
	d_ell(ci, c + Vector2(-s * 0.05, s * 0.15), s * 0.4, s * 0.25, Color(0.96, 0.92, 0.84), 0.0, 0.0)
	var peck := sin(anim_t * (6.0 + danger * 14.0)) * 0.25 * (0.5 + danger)
	var head := c + Vector2(s * 0.5, -s * 0.3) + Vector2(0, peck * s)
	d_ell(ci, head, s * 0.32, s * 0.3, Color(0.5, 0.3, 0.2), 0.0, 3.0)
	ci.draw_circle(head + Vector2(-s * 0.02, s * 0.12), s * 0.14, Color(0.98, 0.96, 0.92))
	ci.draw_circle(head + Vector2(s * 0.12, -s * 0.05), s * 0.06, Color(0.1, 0.08, 0.08))
	d_poly(ci, PackedVector2Array([head + Vector2(s * 0.28, -s * 0.04), head + Vector2(s * 0.5, s * 0.04), head + Vector2(s * 0.28, s * 0.1)]), Color(0.35, 0.28, 0.2), 0.0)
	d_ell(ci, c + Vector2(-s * 0.1, -s * 0.12), s * 0.38, s * 0.2, brown.darkened(0.15), -0.3 + flap, 2.0)

func draw_scarecrow2d(ci: CanvasItem, c: Vector2, s: float) -> void:
	var wood := Color(0.55, 0.4, 0.24)
	d_line(ci, c + Vector2(0, -s * 0.6), c + Vector2(0, s * 1.2), wood, s * 0.1)
	d_line(ci, c + Vector2(-s * 1.0, -s * 0.2), c + Vector2(s * 1.0, -s * 0.2), wood, s * 0.08)
	d_box(ci, c + Vector2(0, s * 0.15), Vector2(s * 0.8, s * 0.8), 0.0, Color(0.8, 0.68, 0.5), 4.0)
	d_box(ci, c + Vector2(s * 0.15, s * 0.3), Vector2(s * 0.25, s * 0.22), 0.2, Color(0.55, 0.62, 0.8), 3.0)
	d_box(ci, c + Vector2(0, -s * 0.2), Vector2(s * 1.6, s * 0.24), 0.0, Color(0.8, 0.68, 0.5), 4.0)
	for sx in [-1.0, 1.0]:
		for k in 3:
			d_line(ci, c + Vector2(sx * s * 0.8, -s * 0.2), c + Vector2(sx * s * 1.05, -s * 0.3 + k * s * 0.1), Color(0.95, 0.85, 0.55), 5)
	d_ell(ci, c + Vector2(0, -s * 0.62), s * 0.36, s * 0.34, Color(0.96, 0.88, 0.62), 0.0, 4.0)
	for ex in [-0.13, 0.13]:
		ci.draw_circle(c + Vector2(ex * s, -s * 0.66), s * 0.05, Color(0.15, 0.1, 0.08))
		ci.draw_circle(c + Vector2(ex * s * 1.7, -s * 0.56), s * 0.06, Color(1, 0.55, 0.55, 0.8))
	d_line(ci, c + Vector2(-s * 0.1, -s * 0.52), c + Vector2(s * 0.1, -s * 0.52), Color(0.5, 0.2, 0.15), 3)
	d_ell(ci, c + Vector2(0, -s * 0.9), s * 0.62, s * 0.1, Color(0.85, 0.72, 0.42), 0.0, 3.0)
	d_poly(ci, PackedVector2Array([c + Vector2(-s * 0.26, -s * 0.92), c + Vector2(-s * 0.16, -s * 1.15), c + Vector2(s * 0.16, -s * 1.15), c + Vector2(s * 0.26, -s * 0.92)]), Color(0.85, 0.72, 0.42), 3.0)

func draw_rice_field(ci: CanvasItem) -> void:
	var w := mg_overlay.size.x
	var h := mg_overlay.size.y
	d_box(ci, Vector2(w * 0.5, h * 0.62), Vector2(w * 1.1, h * 0.46), 0.0, Color(0.5, 0.66, 0.42), 0.0)
	var rr := RandomNumberGenerator.new()
	rr.seed = 9
	for k in 70:
		var x := rr.randf_range(0.0, w)
		var y := rr.randf_range(h * 0.4, h * 0.85)
		var sway := sin(anim_t * 1.5 + x * 0.02) * 0.12
		draw_seedling(ci, Vector2(x, y), 30.0 + (y - h * 0.4) * 0.08, sway)

# --- 최 영감네 논 ---

func talk_choi() -> void:
	if farm_state == -1:
		farm_state = 0
		say([
			["최 영감", "아이고 허리야... 올해는 모내기를 못 하겠구나."],
			["최 영감", "얘야, 나 대신 모를 심어 주겠니? 벼를 거두면 쌀을 팔아 엽전을 나눠 주마."],
			["최 영감", "논 앞 팻말에서 '모내기'를 누르면 된단다. 못줄 눈금에 맞춰 반듯하게 심어야 한다!"],
		], Callable())
		return
	match farm_state:
		0:
			say([["최 영감", "모내기를 부탁하마. 반듯하게 심어야 벼가 잘 자란단다."]], Callable())
		1, 3:
			say([["최 영감", "벼가 쑥쑥 자라는 중이란다. 마을 일을 보고 오너라."]], Callable())
		2:
			say([["최 영감", "참새 떼가 몰려왔다! 허수아비만으로는 안 되겠어. 어서 쫓아 다오!"]], Callable())
		4:
			say([["최 영감", "누렇게 잘 익었구나! 벼를 베어 다오."]], Callable())

func farm_action() -> void:
	match farm_state:
		-1:
			say([["", "물이 찰랑이는 빈 논이다. 옆에 있는 최 영감에게 먼저 말을 걸어 보자."]], Callable())
		0:
			farm_perfect = true
			start_game("plant", {"art": "world", "world": true, "scene": "plant", "title": "손이 노란 동그라미에 왔을 때 눌러서\n못줄 눈금에 맞춰 모를 심어요"}, plant_done)
		1, 3:
			say([["", "벼가 자라고 있다. (약 %d초 남았어요)" % int(ceil(farm_timer))]], Callable())
		2:
			start_game("tap", {"art": "world", "world": true, "scene": "sparrow", "title": "참새가 벼를 쪼아 먹어요!\n눌러서 훠이 쫓아요", "goal": 10, "interval": 0.75, "life": 1.6, "target": "참새", "center": "허수아비", "color": Color(0.85, 0.72, 0.45)}, sparrow_done)
		4:
			harvest_rice()

func plant_done(ok: bool, good: bool) -> void:
	if not ok:
		say([["최 영감", "허허, 모가 삐뚤빼뚤하구나. 다시 심어 보자."]], Callable())
		return
	farm_perfect = good
	farm_state = 1
	farm_timer = FARM_GROW
	farm_visual()
	say([["최 영감", "반듯하게 잘 심었구나! 이제 벼가 자라기를 기다리자."]], Callable())

func sparrow_done(ok: bool, good: bool) -> void:
	if not ok:
		say([["최 영감", "아이쿠, 참새들이 아직 남았구나. 다시 쫓아 다오!"]], Callable())
		return
	farm_perfect = farm_perfect and good
	farm_state = 3
	farm_timer = FARM_GROW
	farm_visual()
	say([["최 영감", "훠이훠이! 참새들이 다 날아갔구나. 이제 이삭이 여물 차례란다."]], Callable())

func harvest_rice() -> void:
	farm_state = 0
	farm_visual()
	harvests += 1
	save_south()
	sfx("good")
	shake(6)
	burst3d(FARM_C + Vector3(0, 1, 0), Color(1, 0.85, 0.35), 30)
	var pay := 25
	var lines := [["", "누렇게 익은 벼를 쓱싹쓱싹 베었다!"]]
	if farm_perfect:
		pay = 30
		lines.append(["최 영감", "모도 반듯하고 참새도 말끔히 쫓았으니 올해 쌀이 최고로구나! 덤까지 얹어 주마."])
	else:
		lines.append(["최 영감", "수고했다! 쌀을 판 돈이다."])
	earn(pay)
	lines.append(["", "엽전 %d냥을 받았다! (수확 %d번째) 빈 논에 다시 모를 심을 수 있어요." % [pay, harvests]])
	say(lines, Callable())

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

func make_decor() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 21
	# 돌담 (앞쪽은 열어 두었어요)
	make_stone_wall(Vector2(-20, -7), Vector2(-8.2, -7), r)
	make_stone_wall(Vector2(-20, -7), Vector2(-20, 2), r)
	make_stone_wall(Vector2(-8.2, -7), Vector2(-8.2, -1.5), r)
	make_stone_wall(Vector2(5.5, -4.5), Vector2(22.5, -4.5), r)
	make_stone_wall(Vector2(5.5, -4.5), Vector2(5.5, 1.5), r)
	make_stone_wall(Vector2(22.5, -4.5), Vector2(22.5, 1.5), r)
	# 마을 한가운데
	make_persimmon(Vector3(3, 0, 2.5), r)
	# 텃밭, 장작
	make_garden(Vector3(-17.6, 0, -4.6), 3.2, 1.8, r)
	make_garden(Vector3(-8.5, 0, 13), 3.0, 1.6, r)
	make_firewood(Vector3(-9.6, 0, -2.6))
	# 꽃덤불
	for pos in [Vector3(-18.6, 0, 2.4), Vector3(-8.9, 0, 2.2), Vector3(6.4, 0, 2.6), Vector3(21.6, 0, 2.6), Vector3(-4.4, 0, -7), Vector3(0.7, 0, -9), Vector3(-4.4, 0, 13), Vector3(0.7, 0, 18), Vector3(-5.6, 0, -12.5), Vector3(1.8, 0, -12.5), Vector3(7.4, 0, 5.8), Vector3(-11.5, 0, 7.2)]:
		make_flowers(pos, r)
	# 징검돌 (집 앞에서 큰길까지)
	var steps := []
	for z in [1.9, 2.9, 3.9, 4.9, 5.9]:
		steps.append([Vector3(-12 + r.randf_range(-0.25, 0.25), 0.05, z + r.randf_range(-0.1, 0.1)), Vector3(0.85, 0.12, 0.65), stone_color(r)])
	for z in [6.0, 7.0]:
		steps.append([Vector3(14 + r.randf_range(-0.25, 0.25), 0.05, z + r.randf_range(-0.1, 0.1)), Vector3(0.9, 0.12, 0.7), stone_color(r)])
	for x in [-9.0, -8.0, -7.0]:
		steps.append([Vector3(x, 0.05, 3.2 + r.randf_range(-0.2, 0.2)), Vector3(0.8, 0.12, 0.6), stone_color(r)])
	add_blobs(self, steps, stone_blob_mat, true)
	# 시냇가 돌과 물빛, 다리 난간
	for side in [1.0, -1.0]:
		var bank := []
		var x := -38.0
		while x < 38.0:
			x += r.randf_range(1.0, 1.7)
			if absf(x + 2.0) < 2.3:
				continue
			var zb: float = creek_z(x) + side * (creek_half(x) + 0.12)
			bank.append([Vector3(x, 0.08, zb + r.randf_range(-0.2, 0.2)), Vector3(r.randf_range(0.6, 1.1), r.randf_range(0.35, 0.6), r.randf_range(0.5, 0.8)), stone_color(r)])
		add_blobs(self, bank, stone_blob_mat)
	var foam := []
	for i in 22:
		foam.append([Vector3(r.randf_range(-38, 38), 0.07, r.randf_range(-0.9, 0.9)), Vector3(r.randf_range(0.6, 1.4), 0.04, 0.12), Color(0.85, 0.95, 1.0)])
	var foam_mi := add_blobs(self, foam)
	foam_mm = foam_mi.multimesh
	for f in foam:
		foam_data.append([f[0].x, f[0].z, f[1].x, f[2]])
	var rail := Color(0.55, 0.38, 0.22)
	for sx in [-3.45, -0.55]:
		for pz in [-17.3, -15.5, -13.7]:
			add_mbox(self, dark_wood_mat, Vector3(0.16, 0.95, 0.16), Vector3(sx, 0.55, pz))
			add_ball(self, Color(0.72, 0.7, 0.66), 0.14, Vector3(sx, 1.05, pz))
		add_mbox(self, wood_mat, Vector3(0.12, 0.1, 3.9), Vector3(sx, 0.92, -15.5))
		add_mbox(self, wood_mat, Vector3(0.1, 0.08, 3.9), Vector3(sx, 0.55, -15.5))
	# 멀리 보이는 둥근 언덕
	make_butterflies(r)
	make_clouds(r)
	make_grass(r)
	add_box(self, Color(0.42, 0.66, 0.38), Vector3(600, 1, 600), Vector3(0, -0.502, 0)).material_override = ground_mat
	make_border(r)
	var hills := []
	for i in 28:
		var ang := i * TAU / 28.0 + r.randf_range(-0.08, 0.08)
		var rad := r.randf_range(78.0, 92.0)
		var k := r.randf()
		hills.append([Vector3(cos(ang) * rad, -3.0, sin(ang) * rad), Vector3(r.randf_range(30, 46), r.randf_range(14, 24), r.randf_range(30, 46)), Color(0.42 + 0.08 * k, 0.7 - 0.06 * k, 0.45 + 0.05 * k)])
	add_blobs(self, hills)
	var far := []
	for i in 20:
		var ang := i * TAU / 20.0 + r.randf_range(-0.1, 0.1)
		var rad := r.randf_range(125.0, 145.0)
		far.append([Vector3(cos(ang) * rad, -6.0, sin(ang) * rad), Vector3(r.randf_range(50, 75), r.randf_range(34, 52), r.randf_range(40, 60)), Color(0.46, 0.64, 0.6).lerp(Color(0.55, 0.7, 0.72), r.randf())])
	var far_mi := add_blobs(self, far)
	far_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

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

func make_butterflies(r: RandomNumberGenerator) -> void:
	var spots := [Vector3(-8.9, 0, 2.2), Vector3(6.4, 0, 2.6), Vector3(-4.4, 0, -7), Vector3(0.7, 0, 18), Vector3(-5.6, 0, -12.5), Vector3(21.6, 0, 2.6), Vector3(-18.6, 0, 2.4)]
	var cols := [Color(1.0, 0.82, 0.25), Color(0.98, 0.98, 1.0), Color(1.0, 0.58, 0.78), Color(0.55, 0.78, 1.0)]
	var body_mat := make_color(Color(0.22, 0.16, 0.12))
	for i in spots.size():
		var root := Node3D.new()
		add_child(root)
		var c: Color = cols[i % cols.size()]
		var wing := butterfly_wing_mesh(c)
		var wmat := StandardMaterial3D.new()
		wmat.vertex_color_use_as_albedo = true
		wmat.cull_mode = BaseMaterial3D.CULL_DISABLED
		wmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var left := Node3D.new()
		var right := Node3D.new()
		root.add_child(left)
		root.add_child(right)
		for side in [[left, -1.0], [right, 1.0]]:
			var mi := MeshInstance3D.new()
			mi.mesh = wing
			mi.material_override = wmat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.scale = Vector3(side[1], 1, 1)
			(side[0] as Node3D).add_child(mi)
		# 몸통과 더듬이
		var bd := add_mcyl(root, body_mat, 0.018, 0.012, 0.16, Vector3.ZERO)
		bd.rotation.x = PI / 2.0
		add_ball(root, Color(0.22, 0.16, 0.12), 0.026, Vector3(0, 0.005, 0.085))
		for sx in [-1.0, 1.0]:
			var an := add_mcyl(root, body_mat, 0.004, 0.004, 0.11, Vector3(sx * 0.022, 0.03, 0.13))
			an.rotation = Vector3(PI / 2.0 - 0.5, 0, -sx * 0.35)
			add_ball(root, Color(0.22, 0.16, 0.12), 0.011, Vector3(sx * 0.04, 0.06, 0.175))
		root.scale = Vector3.ONE * 1.25
		butterflies.append([root, left, right, spots[i], r.randf_range(1.2, 2.2), r.randf_range(0.5, 0.9), r.randf_range(0, TAU)])

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

func make_forest() -> void:
	var herb_spots := [Vector3(-24, 0, -25), Vector3(5, 0, -32), Vector3(27, 0, -22)]
	for pos in herb_spots:
		var h := make_spot(pos, "herb", "", "약초", false)
		make_herb_visual(h)

	# 가시덤불로 막힌 연못 (금도끼 은도끼)
	var none := Color(0, 0, 0, 0)
	for hd in [[Vector3(23, 1.1, -37.5), Vector3(1, 2.2, 4)], [Vector3(23, 1.1, -31.25), Vector3(1, 2.2, 2.5)], [Vector3(31.25, 1.1, -30), Vector3(17.5, 2.2, 1)]]:
		var hc := add_solid(hd[0], hd[1], none)
		make_thorn_shrubs(hc.get_parent(), hd[1], Color(0.2, 0.42, 0.22))
	bush_col = add_solid(Vector3(23, 1.0, -34), Vector3(1, 2.0, 3), none)
	make_thorn_shrubs(bush_col.get_parent(), Vector3(1, 2.0, 3), Color(0.36, 0.46, 0.2))
	var bush: Node3D = bush_col.get_parent()
	add_tag(bush, "가시덤불", 1.6)
	add_thing(bush, "bush", "")
	var pond := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 3.2
	disc.bottom_radius = 3.2
	disc.height = 0.08
	pond.mesh = disc
	pond.material_override = water_material(1, Vector4(33.5, -35.5, 3.2, 3.2), Color(0.12, 0.36, 0.52), Color(0.42, 0.68, 0.72))
	pond.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pond.position = Vector3(33.5, 0.05, -35.5)
	add_child(pond)
	make_npc("woodman", "나무꾼", Color(0.55, 0.42, 0.3), Vector3(28, 0, -33), 1.0, true)
	make_npc("sansin", "산신령", Color(0.95, 0.95, 1.0), Vector3(31.5, 0, -35), 1.2, false).visible = false

	var keep_clear := herb_spots + wild_keep_clear() + [Vector3(-9, 0, -36), Vector3(-2, 0, -19), Vector3(15, 0, -19.5)]
	var planted := 0
	var tries := 0
	while planted < 30 and tries < 500:
		tries += 1
		var pos := Vector3(rng.randf_range(-37, 37), 0, rng.randf_range(-37.5, -19))
		var ok := not (pos.x > 20.0 and pos.z < -27.5)
		for c in keep_clear:
			if pos.distance_to(c) < 3.0:
				ok = false
		if ok:
			make_tree(pos)
			keep_clear.append(pos)
			planted += 1

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

	quest_label = add_label(ui_layer, "", 0.8, 0.04, 0.15, 0.96, 0.36)
	quest_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	quest_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP

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
	dialog_panel.add_theme_stylebox_override("panel", make_paper(font_size * 0.5))
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
		skin_button(b, make_paper(font_size * 0.3), INK, 0.85)
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

func update_quest_text() -> void:
	var t := ""
	if quest == Q_NOLBU:
		t = "큰 기와집에 가서 여기가 어딘지 물어보기 (길 따라 오른쪽)"
	elif quest == Q_MEET:
		t = "길 건너 초가집의 흥부 만나기 (왼쪽)"
	elif quest == Q_RICE:
		t = "흥부와 함께 놀부 마누라에게 쌀 부탁하기"
	elif quest == Q_VILLAGE:
		if mischief_done >= MISCHIEF_NEED:
			t = "흥부에게 돌아가기"
		else:
			t = "놀부 심술에 당한 마을 사람 돕기 (%d/%d) | 마을 곳곳을 돌아다녀 보세요" % [mischief_done, MISCHIEF_NEED]
	elif quest == Q_SNAKE:
		t = "흥부네 처마 밑 제비 둥지 지키기"
	elif quest == Q_HERB:
		t = "개울 건너 숲에서 약초 찾기 (%d/%d)" % [herbs_found, HERB_TOTAL]
	elif quest == Q_GIVE:
		t = "흥부에게 약초 가져다주기"
	elif quest == Q_GOURD:
		t = "흥부네 마당에서 박 타기 (%d/3)" % gourds_done
	elif quest == Q_NOLBU2:
		t = "시끌시끌한 놀부네에 가 보기"
	elif quest == Q_RETURN:
		t = "흥부에게 돌아가 소식 전하기"
	elif quest == Q_END:
		t = "1장 끝! 마을을 둘러보고, 흥부에게 말을 걸면 엔딩을 다시 고를 수 있어요"
	quest_label.text = "할 일: %s\n엽전 %d냥 | 조각 %d/%d | 심술 수습 %d/5" % [t, shown_coins, pieces_found, PIECE_TOTAL, mischief_done]

func set_quest(q: int) -> void:
	quest = q
	update_quest_text()

func earn(amount: int) -> void:
	coins += amount
	sfx("coin")
	float_text("+%d냥" % amount, quest_label.position + Vector2(short_side * 0.25, quest_label.size.y * 0.75), Color(1, 0.85, 0.3), 1.2)
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
		say([["", "“이 길을 따라가면 해와 달이 된 오누이 이야기”"], ["", "2장은 아직 준비 중이에요. 흥부네 이야기를 끝까지 들려준 뒤에 다시 와 보세요!"]], Callable())
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

func talk_to(id: String) -> void:
	if id == "nolbu":
		talk_nolbu()
	elif id == "wife":
		talk_wife()
	elif id == "heungbu":
		talk_heungbu()
	elif id == "kid1":
		talk_kid1()
	elif id == "kid2":
		if gourds_done >= 1:
			say([["막내", "쌀밥 세 그릇이나 먹었어! 배가 뽈록해."]], Callable())
		else:
			say([["막내", "배고파... 그래도 제비가 빨리 나았으면 좋겠어."]], Callable())
	elif id == "dokkaebi":
		say([["도깨비", "껄껄, 책 밖에서 온 아이로구나. 너는 착하니 겁낼 것 없다."]], Callable())
	elif id == "merchant":
		shop()
	elif id == "woodman":
		talk_woodman()
	elif id == "fisher":
		talk_fisher()
	elif id == "choi":
		talk_choi()
	elif id == "sansin":
		say([["산신령", "정직한 마음을 잊지 말거라. 그것이 금도끼보다 귀하니라."]], Callable())
	else:
		talk_villager(id)

# ---------- 놀부네 ----------

func talk_nolbu() -> void:
	if quest == Q_NOLBU:
		say([
			["놀부", "뭐냐, 웬 꼬마가 남의 집 앞에서 얼쩡거려?"],
			["놀부", "옷차림은 또 그게 뭐냐? 저고리도 아니고, 신발은 왜 그 모양이야?"],
			["놀부", "길을 잃었다고? 내 알 바 아니다! 책 속에서 왔다니, 별 실없는 소리를 다 듣겠네."],
			["놀부", "밥? 흥! 물 한 모금도 아깝다. 길 건너 내 아우 흥부한테나 가 보든지."],
		], func(): set_quest(Q_MEET))
	elif quest == Q_NOLBU2:
		say([
			["놀부", "흥부 놈이 제비 덕에 부자가 됐다지? 그깟 거 나도 한다!"],
			["놀부", "그래서 내가 제비 다리를 똑 부러뜨린 다음 고쳐 줬지. 으하하!"],
			["놀부", "자, 봐라. 내 박은 흥부네 것보다 훨씬 크지? 슬근슬근 톱질하세..."],
			["놀부", "어? 어어? 박 속에서 뭐가 나온다!"],
		], after_nolbu_boast)
	elif quest >= Q_RETURN:
		if helped_nolbu:
			say([["놀부", "네가 내 편을 들어 주다니... 박대해서 미안했다, 얘야. 이제 심술은 안 부리마."]], Callable())
		else:
			say([["놀부", "내가 욕심이 과했다... 다 내 탓이지, 누굴 원망하겠느냐."]], Callable())
	else:
		say([["놀부", "아직도 안 갔느냐? 내 마당 흙 닳는다, 썩 가거라!"]], Callable())

func talk_wife() -> void:
	if quest == Q_RICE:
		say([
			["흥부", "형수님, 아이들이 굶고 있습니다. 쌀 한 되만 꾸어 주십시오."],
			["놀부 마누라", "뭐야? 남 줄 쌀이 어디 있어! 이 밥주걱 맛이나 봐라!"],
			["흥부", "아이고! ...어? 뺨에 밥풀이 붙었네. 형수님, 이쪽 뺨도 마저 때려 주십시오!"],
			["흥부", "얘야, 바가지를 들고 튀는 밥풀을 받아 다오. 주걱은 피하고!"],
		], start_rice)
	elif quest >= Q_RETURN:
		say([["놀부 마누라", "아이고, 내 팔자야... 주걱으로 때린 벌을 받나 보다."]], Callable())
	else:
		say([["놀부 마누라", "뭘 봐? 우리 집엔 남 줄 쌀 한 톨 없어!"]], Callable())

func start_rice() -> void:
	start_game("catch", {"world": true, "scene": "rice", "title": "놀부 마누라의 밥주걱은 피하고\n튀는 밥풀만 바가지로 받으세요", "goal": 12, "interval": 0.6, "speed": 0.42, "bad_ratio": 0.35, "good": "밥풀", "bad": "주걱", "basket": "바가지", "art": "world"}, rice_done)

func rice_done(ok: bool, _good: bool) -> void:
	if not ok:
		say([["흥부", "아이쿠, 주걱에 너무 많이 맞았다... 형수님께 다시 부탁해 보자꾸나."]], Callable())
		return
	var heungbu: Node3D = npcs["heungbu"]
	heungbu.position = Vector3(-12, 0, 2.5)
	say([
		["흥부", "허허, 밥풀이 한 줌은 되는구나. 아이들 죽이라도 끓여 주겠다."],
		["놀부 마누라", "저, 저런 못난이들! 썩 꺼져!"],
		["흥부", "나는 품을 팔러 가야겠다. 형님 심술에 마을 사람들이 고생이 많은데, 네가 좀 도와주겠느냐?"],
	], func(): set_quest(Q_VILLAGE))

func after_nolbu_boast() -> void:
	nolbu_gourd.visible = false
	var dok: Node3D = npcs["dokkaebi"]
	dok.visible = true
	pop3d(dok, true)
	sfx("crack")
	shake(22)
	hit_stop(0.08)
	flash(Color(1, 1, 1))
	burst3d(dok.position + Vector3(0, 1.5, 0), Color(0.6, 0.68, 0.4), 30)
	set_quest(Q_DOKKAEBI)
	say([
		["도깨비", "이놈 놀부야! 멀쩡한 제비 다리를 일부러 부러뜨려?"],
		["놀부", "아이고, 도깨비님! 잘못했습니다, 살려 주십시오!"],
		["도깨비", "욕심으로 얻은 재물은 내가 몽땅 가져가마. 뚝딱!"],
		["놀부", "아이고, 내 재산... 내 기와집... 흑흑."],
	], func(): ask("놀부", "얘야... 염치없다만, 흥부한테 내 얘기 좀 잘 해 주겠느냐?", ["도와준다", "모른 척한다"], on_nolbu_choice))

func on_nolbu_choice(i: int) -> void:
	helped_nolbu = i == 0
	if helped_nolbu:
		say([["놀부", "고, 고맙다... 박대한 나를 도와주다니. 내가 부끄럽구나."]], func(): set_quest(Q_RETURN))
	else:
		say([["놀부", "그래, 내가 한 짓이 있는데 무슨 낯으로... 흑흑."]], func(): set_quest(Q_RETURN))

# ---------- 흥부네 ----------

func talk_heungbu() -> void:
	if quest == Q_NOLBU:
		say([["흥부", "어서 오너라. 처음 보는 옷이로구나. 길을 잃었으면 저기 큰 기와집 형님께 먼저 여쭤 보렴."]], Callable())
	elif quest == Q_MEET:
		say([
			["흥부", "아이고, 형님 댁에서 그냥 쫓겨났다고? 저런, 많이 놀랐겠구나."],
			["흥부", "옛이야기 책을 펼쳤더니 여기였다고? 허허, 신기한 일도 다 있구나. 그 책 좀 보자."],
			["흥부", "이런, 책장이 텅 비었구나. 이야기가 채워져야 돌아갈 길이 열리려나 보다."],
			["흥부", "밥이라도 먹이고 싶다만... 실은 쌀이 똑 떨어졌단다."],
			["흥부", "형님 댁에 쌀을 꾸러 가려던 참인데, 같이 가 주겠느냐?"],
		], after_meet)
	elif quest == Q_RICE:
		say([["흥부", "형수님께 같이 부탁드려 보자꾸나. 바로 옆에 계신다."]], Callable())
	elif quest == Q_VILLAGE:
		if mischief_done >= MISCHIEF_NEED:
			say([
				["흥부", "마을 사람들을 도와줬다고? 장하구나!"],
				["흥부", "그런데 큰일이다! 처마 밑 제비 둥지에 구렁이가 나타났어!"],
			], func(): set_quest(Q_SNAKE))
		else:
			say([["흥부", "형님 심술에 당한 사람이 마을에 다섯이나 된단다. 셋만 도와줘도 큰 힘이 될 게다."]], Callable())
	elif quest == Q_SNAKE:
		say([["흥부", "어서 둥지를 지켜 다오! 우리 집 처마 밑이다."]], Callable())
	elif quest == Q_HERB:
		say([["흥부", "약초는 개울 건너 뒷산 숲에 있단다. 나무 사이를 잘 살펴보렴."]], Callable())
	elif quest == Q_GIVE:
		say([
			["흥부", "오오, 세 포기나! 정말 고맙구나."],
			["흥부", "약초를 바르고 실로 다리를 감아 줘야 한단다."],
			["흥부", "내 손은 거칠어서... 네가 살살 감아 주겠느냐?"],
		], start_heal)
	elif quest == Q_GOURD:
		say([["흥부", "박은 마당에 있단다. 하나씩 같이 타 보자꾸나."]], Callable())
	elif quest == Q_NOLBU2:
		say([["흥부", "형님 댁이 시끌시끌하구나. 무슨 일인지 가 보겠느냐?"]], Callable())
	elif quest == Q_RETURN:
		var lines := [["흥부", "형님이 도깨비한테 혼쭐이 나셨다고? 저런..."]]
		if helped_nolbu:
			lines.append(["흥부", "네가 형님 편을 들어 주었구나. 고맙다. 우리 새 집에서 함께 지내시라 해야겠다."])
		else:
			lines.append(["흥부", "미워도 내 형님이다. 우리 새 집에서 함께 지내시라 해야겠구나."])
		lines.append(["흥부", "얘야, 네 책 좀 보렴. 빈 책장에 우리 이야기가 거의 채워졌구나. 마지막 한 줄만 비어 있다."])
		lines.append(["흥부", "그 한 줄은 네가 정해 다오. 네 덕에 제비도 살고 우리 식구도 살았으니."])
		say(lines, ask_final)
	else:
		ask("흥부", "집으로 돌아가는 길, 꼭 찾기를 바란다. 이야기의 마지막 한 줄을 다시 고르겠느냐?", ["다시 고를래요", "이대로 둘래요"], on_replay_choice)

func after_meet() -> void:
	var heungbu: Node3D = npcs["heungbu"]
	heungbu.position = Vector3(12.2, 0, 9.8)
	set_quest(Q_RICE)

func talk_kid1() -> void:
	if hide_state == 0:
		hide_state = 1
		for t in things:
			if t["kind"] == "hider":
				var node: Node3D = t["node"]
				node.visible = true
		say([["첫째", "그 옷 어디서 났어? 처음 봐! 참, 심심한데 숨바꼭질 하자."], ["첫째", "동생 넷이 마을 어딘가에 숨었어. 다 찾으면 내 보물을 줄게!"]], Callable())
	elif hide_state == 1:
		if hiders_found >= 4:
			hide_state = 2
			earn(20)
			say([["첫째", "벌써 다 찾았어? 대단하다! 약속한 보물이야."], ["", "엽전 20냥을 받았다!"]], Callable())
		else:
			say([["첫째", "아직 %d명 남았어. 집 뒤, 나무 뒤, 다리 밑을 잘 봐!" % (4 - hiders_found)]], Callable())
	elif gourds_done >= 2:
		say([["첫째", "나도 새 옷 입었어! 다음엔 어느 이야기로 가? 나도 따라가고 싶다."]], Callable())
	else:
		say([["첫째", "우리 아버지는 세상에서 제일 착해. 가난해도 제비까지 돌봐 준다니까!"]], Callable())

# 구렁이 쫓기
func start_snake() -> void:
	start_game("tap", {"world": true, "scene": "snake", "title": "구렁이가 제비 둥지로 기어와요!\n닿기 전에 눌러서 쫓아내세요", "goal": 12, "interval": 0.75, "life": 1.6, "target": "구렁이", "center": "둥지", "color": Color(0.5, 0.38, 0.25), "art": "world"}, snake_done)

func snake_done(ok: bool, _good: bool) -> void:
	if not ok:
		say([["흥부", "구렁이가 둥지에 닿았다! 얼른 다시 쫓아 다오!"]], Callable())
		return
	for t in things:
		if t["kind"] == "herb":
			var node: Node3D = t["node"]
			node.visible = true
	say([
		["", "구렁이는 달아났지만, 놀란 새끼 제비 한 마리가 떨어져 다리를 다쳤다."],
		["흥부", "저런, 가엾어라! 뒷산 숲에서 약초를 세 포기만 구해다 주겠느냐? 분홍빛 나는 풀이란다."],
	], func(): set_quest(Q_HERB))

# 제비 치료
func start_heal() -> void:
	start_game("circle", {"world": true, "scene": "heal", "art": "world", "trail": Color(1, 1, 1), "title": "다친 제비 다리에 부목을 대고\n둘레를 천천히 돌며 실을 감아요", "label": "제비", "turns": 6.0, "max_speed": 11.0, "warn": "너무 빨라요! 제비가 아파해요", "color": Color(0.2, 0.22, 0.35)}, heal_done)

func heal_done(ok: bool, good: bool) -> void:
	if not ok:
		say([["흥부", "제비가 놀라서 푸드덕거리는구나. 숨을 고르고 다시 살살 감아 보자."]], start_heal)
		return
	var lines := [["제비", "짹짹!"]]
	if good:
		lines.append(["흥부", "허허, 아주 꼼꼼하게 감았구나. 제비가 하나도 안 아파하는구나."])
	else:
		lines.append(["흥부", "조금 놀랐나 보다만, 그래도 잘 감아 주었구나."])
	lines.append(["흥부", "어라, 네 책에 제비 그림이 생겼구나! 이야기가 채워지고 있나 보다."])
	lines.append(["흥부", "다 나으면 강남으로 날아가겠지. 고맙다, 얘야."])
	say(lines, after_heal_talk)

func after_heal_talk() -> void:
	set_quest(Q_SEASON)
	show_card("제비는 따뜻한 강남으로 날아갔어요.\n\n계절이 바뀌고,\n이듬해 봄...", 0.0, 3.0, after_season)

func after_season() -> void:
	set_quest(Q_SEED)
	say([
		["제비", "짹짹! 짹짹!"],
		["흥부", "아니, 작년 그 제비가 아니냐! 입에 문 건... 박씨로구나."],
		["흥부", "마당에 심었더니 어느새 커다란 박이 세 통이나 열렸단다."],
		["흥부", "얘야, 나와 같이 박을 타 보지 않겠느냐? 박자가 너무 어긋나면 톱이 끼니 조심하고."],
	], after_seed)

func after_seed() -> void:
	for t in things:
		if t["kind"] == "gourd":
			var node: Node3D = t["node"]
			node.visible = true
	set_quest(Q_GOURD)

# 박 타기
func start_saw() -> void:
	start_game("follow", {"world": true, "scene": "saw", "art": "world", "title": "슬근슬근 톱질하세! (%d번째 박)\n아래 손잡이를 흥부와 같이 좌우로" % (gourds_done + 1), "slow": 2.4 - gourds_done * 0.35, "tol": 0.42 - gourds_done * 0.04, "goal": 6.0, "patience": 4.0 - gourds_done * 0.5, "color": Color(0.82, 0.9, 0.62)}, saw_done)

func saw_done(ok: bool, _good: bool) -> void:
	if not ok:
		say([["흥부", "아이쿠, 박자가 어긋나 톱이 박에 끼었구나. 숨 한번 돌리고 다시 타 보자."]], Callable())
		return
	var g: Node3D = saw_thing["node"]
	g.visible = false
	sfx("crack")
	shake(22)
	hit_stop(0.08)
	flash(Color(1, 1, 1))
	burst3d(g.position + Vector3(0, 1.2, 0), PAPER, 30)
	spawn_treasure(gourds_done, g.position)
	var all_lines := [
		[
			["흥부", "아이고, 쌀이다! 하얀 쌀이 끝도 없이 쏟아지는구나!"],
			["막내", "쌀밥이다! 아버지, 오늘은 배불리 먹어요?"],
			["흥부", "그럼, 그럼. 네 몫으로 엽전도 나왔구나. 자, 다음 박도 타 보자."],
		],
		[
			["흥부", "이번엔 비단이로구나! 고운 비단이 필필이 나온다!"],
			["첫째", "우와, 우리도 새 옷 입는 거예요?"],
			["흥부", "허허, 마지막 박이 남았구나. 톱질이 점점 빨라지니 잘 따라오너라."],
		],
		[
			["흥부", "아니, 이번엔 목수들이 우르르 나오는구나!"],
			["흥부", "뚝딱뚝딱, 눈 깜짝할 사이에 새 집을 지어 주었구나!"],
			["흥부", "착한 일을 하면 복이 온다더니... 이 은혜는 잊지 않으마."],
			["흥부", "그런데 형님 댁이 왜 저리 시끄러울꼬? 한번 가 보겠느냐?"],
		],
	]
	var lines: Array = all_lines[gourds_done]
	gourds_done += 1
	earn(15)
	say(lines, after_gourd_talk)

func after_gourd_talk() -> void:
	if gourds_done >= 3:
		nolbu_gourd.visible = true
		set_quest(Q_NOLBU2)
	else:
		update_quest_text()

func spawn_treasure(order: int, pos: Vector3) -> void:
	var pile := Node3D.new()
	pile.position = pos
	add_child(pile)
	if order == 0:
		spawn_rice(pile)
		add_tag(pile, "쌀", 2.0)
	elif order == 1:
		spawn_silk(pile)
		add_tag(pile, "비단", 2.0)
	else:
		spawn_gold(pile)
		add_tag(pile, "금은보화", 1.6)
		hut.visible = false
		pop3d(make_house(hut.position, Vector3(7, 3.4, 4.5), Color(0.96, 0.94, 0.88), Color(0.2, 0.35, 0.5), "tile"), true)
	pop3d(pile, true)

# ---------- 1장 엔딩 ----------

func ask_final() -> void:
	var opts := ["형님도 우리 집에서 함께 지내요", "형님은 벌 받은 대로 두어요"]
	if coins >= RICH_COINS:
		opts.append("보물로 땅을 더 사서 불려요")
	ask("흥부", "이야기의 마지막 한 줄이다. 형님을 어찌하면 좋을꼬?", opts, on_final_choice)

func on_replay_choice(i: int) -> void:
	if i == 0:
		say([["흥부", "그래, 마지막 한 줄은 몇 번이고 다시 쓸 수 있지."]], ask_final)

func on_final_choice(i: int) -> void:
	var id := "original"
	if i == 0:
		if helped_nolbu and mischief_done >= 5:
			id = "true"
		else:
			id = "awkward"
	elif i == 2:
		id = "greed"
	finish_chapter(id)

func ending_data(id: String) -> Array:
	match id:
		"true":
			return ["함께 사는 집", "놀부는 마을 사람들을 하나하나 찾아가 고개를 숙였어요.\n처음엔 닫혀 있던 대문들이 하나둘 열렸고,\n흥부네 처마 밑 제비집은 둘로 늘었답니다.\n\n책의 첫 장이 환하게 채워졌어요."]
		"awkward":
			return ["아직은 어색한 화해", "흥부는 형님을 새 집에 모셨어요.\n하지만 놀부에게 상처받은 마을 사람들은\n아직 대문을 활짝 열지 못했어요.\n\n용서는 한 사람만의 일이라서\n시간이 더 필요한가 봐요.\n\n책의 첫 장이 반쯤 채워졌어요."]
		"greed":
			return ["작은 놀부", "보물로 땅을 사고 또 사던 흥부네 대문은\n해마다 높아지고 굳게 닫혔어요.\n처마 밑 제비는 다른 집으로 떠났고,\n마을 사람들은 흥부를 '작은 놀부'라 불렀어요.\n\n책장의 글씨가 흐릿하게 번졌어요.\n욕심은 누구의 마음에든 찾아오나 봐요."]
	return ["권선징악", "놀부는 도깨비에게 모든 것을 잃고\n흥부네 담장 밖을 오래 서성였어요.\n\n착한 마음에는 복이, 욕심에는 화가 따른다지만\n담장 밖 뒷모습이 자꾸 마음에 걸렸어요.\n\n책의 첫 장이 채워졌어요."]

# 모은 엔딩을 파일에 기억해요. 지금까지 모은 개수를 돌려줘요
func save_ending(id: String) -> int:
	var cf := ConfigFile.new()
	cf.load("user://save.cfg")
	var got: Array = cf.get_value("ch1", "endings", [])
	if not got.has(id):
		got.append(id)
		cf.set_value("ch1", "endings", got)
		cf.save("user://save.cfg")
	return got.size()

func finish_chapter(id: String) -> void:
	ending_id = id
	var seen := save_ending(id)
	set_quest(Q_END)
	var d := ending_data(id)
	show_card("%s\n\n엔딩 “%s” (모은 엔딩 %d/%d)\n1장 흥부와 놀부  끝" % [d[1], d[0], seen, ENDING_COUNT], 0.0, 5.0, Callable())

# ---------- 마을 사람 돕기 ----------

func talk_villager(id: String) -> void:
	var v: Dictionary = villagers[id]
	var who: String = v["name"]
	var state: int = mischief.get(id, 0)
	if state == 2:
		say([[who, "네 덕에 한시름 놓았다. 고맙다!"]], Callable())
	elif v.has("game"):
		say(v["ask"], func(): start_game(v["game"], v["cfg"], villager_game_done.bind(id)))
	elif state == 0:
		mischief[id] = 1
		if id == "suni":
			for t in things:
				if t["kind"] == "laundry":
					var node: Node3D = t["node"]
					node.visible = true
		say(v["ask"], Callable())
	elif (id == "dori" and has_yeot) or (id == "suni" and laundry_found >= 3):
		if id == "dori":
			has_yeot = false
		finish_mischief(id)
	else:
		say([[who, v["wait"]]], Callable())

func villager_game_done(ok: bool, _good: bool, id: String) -> void:
	var v: Dictionary = villagers[id]
	if ok and id == "ong":
		# 진흙을 발라 금이 사라졌어요
		for c in ong_cracks:
			(c as Node3D).visible = false
	if ok:
		finish_mischief(id)
	else:
		say([[v["name"], v["fail"]]], Callable())

func finish_mischief(id: String) -> void:
	var v: Dictionary = villagers[id]
	mischief[id] = 2
	mischief_done += 1
	earn(10)
	say([[v["name"], v["done"]], ["", "엽전 10냥을 받았다! (놀부 심술 수습 %d/5)" % mischief_done]], Callable())

# ---------- 품팔이와 장터 ----------

func start_job(id: String) -> void:
	if id == "water":
		start_well3d()
		return
	if id == "water_2d":
		start_game("catch", {"art": "water", "title": "두레박을 좌우로 움직여 물방울만 받아요\n돌멩이는 피해요", "goal": 10, "interval": 0.55, "speed": 0.5, "bad_ratio": 0.3, "good": "물", "bad": "돌", "basket": "두레박"}, job_done)
	elif id == "wood":
		start_wood3d()
	elif id == "gam":
		start_gam3d()
	elif id == "wood_2d":
		start_game("tap", {"art": "wood", "title": "통나무가 올라오면\n눌러서 쩍! 장작을 패요", "goal": 10, "interval": 0.7, "life": 1.3, "target": "장작", "center": "나무", "color": Color(0.5, 0.35, 0.2)}, job_done)
	else:
		start_game("circle", {"world": true, "scene": "straw", "art": "world", "trail": Color(0.9, 0.78, 0.42), "title": "짚을 빙글빙글 꼬아 짚신을 삼아요\n너무 빠르면 짚이 끊어져요", "label": "짚신", "turns": 5.0, "max_speed": 12.0, "warn": "짚이 끊어질 것 같아요!", "color": Color(0.8, 0.68, 0.35)}, job_done)

func job_done(ok: bool, good: bool) -> void:
	if not ok:
		say([["", "일을 망쳐서 품삯을 받지 못했다. 다시 해 보자."]], Callable())
		return
	var pay := 10
	if good:
		pay = 15
	earn(pay)
	if good:
		say([["", "솜씨가 좋다고 덤까지 받았다. 엽전 %d냥!" % pay]], Callable())
	else:
		say([["", "품삯으로 엽전 %d냥을 받았다." % pay]], Callable())

func shop() -> void:
	ask("장터 상인", "어서 오너라! 무엇을 줄까? (가진 엽전 %d냥)" % coins, ["엿 5냥", "짚신 20냥 (발이 빨라져요)", "낫 15냥 (덤불을 베요)", "한복 40냥 (옷 갈아입기)", "그만 볼래요"], on_shop)

func on_shop(i: int) -> void:
	if i >= 4:
		return
	var prices := [5, 20, 15, 40]
	var owned := (i == 0 and has_yeot) or (i == 1 and has_shoes) or (i == 2 and has_sickle) or (i == 3 and has_hanbok)
	if owned:
		say([["장터 상인", "그건 이미 가지고 있잖니."]], shop)
		return
	if coins < prices[i]:
		say([["장터 상인", "엽전이 모자라는구나. 우물, 나무터, 짚더미, 감나무에서 품을 팔거나 남쪽 연못에서 낚시를 하고, 최 영감네 논일을 도우면 엽전을 벌 수 있단다."]], Callable())
		return
	coins -= prices[i]
	if i == 0:
		has_yeot = true
	elif i == 1:
		has_shoes = true
	elif i == 2:
		has_sickle = true
	else:
		has_hanbok = true
		recolor_outfit(player_body, Color(0.45, 0.78, 0.72))
		pop3d(player)
		burst3d(player.position + Vector3(0, 1, 0), Color(0.45, 0.78, 0.72), 20)
	sfx("coin")
	update_quest_text()
	say([["장터 상인", "옜다, 잘 쓰거라!"]], shop)

# ---------- 숨은 이야기: 금도끼 은도끼 ----------

func talk_woodman() -> void:
	if axe_done:
		say([["나무꾼", "네 정직함 덕분에 어머니를 잘 모시게 됐어. 고마워!"]], Callable())
		return
	var sansin: Node3D = npcs["sansin"]
	sansin.visible = true
	pop3d(sansin, true)
	burst3d(sansin.position + Vector3(0, 1, 0), Color(0.6, 0.8, 1.0), 20)
	say([
		["나무꾼", "엉엉... 하나뿐인 쇠도끼를 연못에 빠뜨렸어. 나무를 해야 어머니를 모시는데..."],
		["산신령", "어흠. 나는 이 연못의 산신령이니라."],
		["산신령", "책 밖에서 온 아이야, 네가 대신 시험을 받아 보아라."],
		["산신령", "내가 연못에서 도끼를 하나씩 들어 올리마. 나무꾼의 낡은 쇠도끼일 때만 눌러 받거라."],
		["산신령", "번쩍이는 금도끼, 은도끼에 손을 대면... 욕심으로 알겠느니라!"],
	], start_axe_game)

const AXE_GOAL := 3

func start_axe_game() -> void:
	start_game("axe", {"world": true, "art": "world", "title": "산신령이 도끼를 들어 올려요\n낡은 쇠도끼일 때만 눌러서 받아요!"}, axe_game_done)
	var sansin: Node3D = npcs["sansin"]
	var sp := sansin.position
	var stand := Vector3(29.3, 0, -32.6)
	var dir := (stand - sp) * Vector3(1, 0, 1)
	dir = dir.normalized()
	var side := dir.cross(Vector3.UP)
	world_game_begin(stand, sp, Vector3(26.4, 1.9, -31.4), sp + Vector3(0, 0.75, 0))
	world_move(sansin, sp, stand)
	if npcs.has("woodman"):
		var wm: Node3D = npcs["woodman"]
		world_move(wm, stand + Vector3(0.9, 0, 0.9), sp)
		for lb2 in wm.find_children("*", "Label3D", true, false):
			world_hide(lb2)
	for lb in sansin.find_children("*", "Label3D", true, false):
		world_hide(lb)
	var axes := {}
	for kind in ["gold", "silver", "iron"]:
		var ax := make_axe_model(kind)
		ax.visible = false
		axes[kind] = ax
	w["axes"] = axes
	w["sansin"] = sp
	w["top"] = sp + dir * 0.75 + Vector3(0, 1.25, 0)
	w["state"] = "gap"
	w["timer"] = 1.0
	w["cur"] = ""
	w["since_iron"] = 0
	axe_info()

func make_axe_model(kind: String) -> Node3D:
	var n := Node3D.new()
	world_node(n)
	var metal := StandardMaterial3D.new()
	match kind:
		"gold":
			metal.albedo_color = Color(1.0, 0.78, 0.22)
			metal.metallic = 0.85
			metal.roughness = 0.25
			metal.emission_enabled = true
			metal.emission = Color(1.0, 0.7, 0.2)
			metal.emission_energy_multiplier = 0.35
		"silver":
			metal.albedo_color = Color(0.86, 0.9, 0.95)
			metal.metallic = 0.85
			metal.roughness = 0.2
			metal.emission_enabled = true
			metal.emission = Color(0.7, 0.8, 0.95)
			metal.emission_energy_multiplier = 0.25
		_:
			metal.albedo_color = Color(0.36, 0.34, 0.33)
			metal.metallic = 0.3
			metal.roughness = 0.85
	var handle: Material = metal if kind != "iron" else wood_mat
	add_mcyl(n, handle, 0.032, 0.038, 0.95, Vector3(0, 0, 0))
	add_mbox(n, metal, Vector3(0.22, 0.17, 0.07), Vector3(0.1, 0.36, 0))
	add_mbox(n, metal, Vector3(0.07, 0.3, 0.06), Vector3(0.22, 0.36, 0))
	add_mbox(n, metal, Vector3(0.08, 0.12, 0.08), Vector3(-0.04, 0.36, 0))
	if kind == "iron":
		# 녹슨 자국
		add_ball(n, Color(0.55, 0.32, 0.18), 0.035, Vector3(0.12, 0.4, 0.035))
		add_ball(n, Color(0.5, 0.3, 0.18), 0.025, Vector3(0.05, 0.31, 0.035))
	n.scale = Vector3.ONE * 1.5
	return n

func axe_info() -> void:
	mg_progress = float(mg_count) / AXE_GOAL
	mg_info.text = "쇠도끼 %d/%d | 남은 기회 %d" % [mg_count, AXE_GOAL, mg_lives]

func axe_pick_next() -> String:
	# 쇠도끼가 너무 오래 안 나오지 않게 해요
	var since: int = w["since_iron"]
	if since >= 3 or rng.randf() < 0.3:
		w["since_iron"] = 0
		return "iron"
	w["since_iron"] = since + 1
	return "gold" if rng.randf() < 0.55 else "silver"

func update_axe(delta: float) -> void:
	var axes: Dictionary = w["axes"]
	var sp: Vector3 = w["sansin"]
	var top: Vector3 = w["top"]
	w["timer"] = float(w["timer"]) - delta
	var st: String = w["state"]
	var cur: String = w["cur"]
	var show_time := 1.25 - mg_count * 0.15
	if st == "gap":
		if float(w["timer"]) <= 0.0:
			cur = axe_pick_next()
			w["cur"] = cur
			w["state"] = "rise"
			w["timer"] = 0.35
			var ax: Node3D = axes[cur]
			ax.visible = true
			ax.global_position = sp + Vector3(0, 0.1, 0)
			splash3d(sp + Vector3(0, 0.05, 0))
			sfx("splash", 1.2)
	elif st == "rise":
		var ax2: Node3D = axes[cur]
		var k := 1.0 - clampf(float(w["timer"]) / 0.35, 0.0, 1.0)
		ax2.global_position = (sp + Vector3(0, 0.1, 0)).lerp(top, ease(k, 0.4))
		ax2.rotation = Vector3(0, k * TAU, 0.2)
		if float(w["timer"]) <= 0.0:
			w["state"] = "show"
			w["timer"] = show_time
			if cur != "iron":
				burst3d(top + Vector3(0, 0.3, 0), Color(1.0, 0.85, 0.3) if cur == "gold" else Color(0.85, 0.9, 1.0), 12)
				sfx("coin", 1.3 if cur == "gold" else 1.6)
	elif st == "show":
		var ax3: Node3D = axes[cur]
		ax3.global_position = top + Vector3(0, sin(anim_t * 4.0) * 0.05, 0)
		ax3.rotation = Vector3(0, sin(anim_t * 2.5) * 0.6, 0.2)
		if float(w["timer"]) <= 0.0:
			if cur == "iron":
				# 쇠도끼를 놓쳤어요
				mg_lives -= 1
				mg_perfect = false
				sfx("bad")
				shake(10)
				float_text("쇠도끼를 놓쳤어요!", cam.unproject_position(top), Color(1, 0.55, 0.45), 1.1)
				axe_info()
			axe_sink()
	elif st == "sink":
		var ax4: Node3D = axes[cur]
		var k2 := 1.0 - clampf(float(w["timer"]) / 0.3, 0.0, 1.0)
		ax4.global_position = top.lerp(sp + Vector3(0, -0.3, 0), k2)
		if float(w["timer"]) <= 0.0:
			ax4.visible = false
			w["state"] = "gap"
			w["timer"] = rng.randf_range(0.35, 0.7)
	elif st == "fly":
		var ax5: Node3D = axes[cur]
		var k3 := 1.0 - clampf(float(w["timer"]) / 0.35, 0.0, 1.0)
		ax5.global_position = (w["fly_from"] as Vector3).lerp(player.global_position + Vector3(0, 1.2, 0), k3 * k3)
		ax5.rotation = Vector3(0, k3 * TAU, 0.2)
		ax5.scale = Vector3.ONE * 1.5 * (1.0 - k3 * 0.6)
		if float(w["timer"]) <= 0.0:
			ax5.visible = false
			ax5.scale = Vector3.ONE * 1.5
			w["state"] = "gap"
			w["timer"] = 0.6
	var sansin: Node3D = npcs["sansin"]
	sansin.position.y = sin(anim_t * 1.8) * 0.06 + 0.1

func axe_sink() -> void:
	w["state"] = "sink"
	w["timer"] = 0.3
	splash3d((w["sansin"] as Vector3) + Vector3(0, 0.05, 0))

func axe_tap() -> void:
	var st: String = w.get("state", "")
	if st != "show" and st != "rise":
		return
	var cur: String = w["cur"]
	var ax: Node3D = w["axes"][cur]
	var at := ax.global_position
	if cur == "iron":
		mg_count += 1
		sfx("good")
		shake(6)
		hit_stop(0.05)
		cam_kick = 0.15
		burst3d(at, Color(0.6, 0.9, 1.0), 16)
		float_text(["정직하구나!", "옳지!", "바로 그거다!"][mg_count % 3], cam.unproject_position(at), Color(1, 0.95, 0.7), 1.3)
		# 도끼가 내 손으로 날아와요
		w["state"] = "fly"
		w["timer"] = 0.35
		w["fly_from"] = at
	else:
		mg_lives -= 1
		mg_perfect = false
		sfx("bad")
		shake(14)
		flash(Color(1, 0.3, 0.3))
		float_text("욕심이로구나!", cam.unproject_position(at), Color(1, 0.5, 0.4), 1.3)
		axe_sink()
	axe_info()

func axe_game_done(ok: bool, _good: bool) -> void:
	if not ok:
		axe_lie()
		return
	axe_done = true
	earn(30)
	say([
		["산신령", "참으로 정직하구나! 쇠도끼는 물론이고, 금도끼와 은도끼도 모두 주마."],
		["나무꾼", "고맙다, 얘야! 네 덕분이야. 이건 내 마음이니 받아 줘."],
		["", "엽전 30냥을 받았다!"],
	], func(): get_piece_id(6, "산신령이 책에 이야기 한 조각을 새겨 주었다."))

func axe_lie() -> void:
	axe_lied = true
	var sansin: Node3D = npcs["sansin"]
	sansin.visible = false
	sfx("bad")
	shake(8)
	say([
		["산신령", "허허, 욕심에 눈이 흐려졌구나. 정직하지 못한 자에겐 아무것도 줄 수 없다."],
		["", "산신령이 연못 속으로 사라졌다. 나무꾼에게 다시 말을 걸어 보자."],
	], Callable())

# ---------- 감나무: 장대로 감 따기 (꼭대기 까치밥은 남겨요) ----------

const GAM_GOAL := 8
var persimmon_ctr := Vector3(3, 3.7, 2.5)
var persimmon_rad := 2.0
var persimmon_fruit_mi: Node3D = null

func start_gam3d() -> void:
	start_game("gam", {"world": true, "art": "world", "title": "빨갛게 익은 감을 눌러 장대로 톡!\n초록 감과 꼭대기 까치밥은 남겨요"}, job_done)
	var c := persimmon_ctr
	var stand := Vector3(c.x + 1.9, 0, c.z + 3.0)
	world_game_begin(stand, Vector3(c.x, 0, c.z), Vector3(c.x + 0.6, 1.3, c.z + 8.0), Vector3(c.x + 0.5, c.y + 0.15, c.z), job_spot("gam"))
	if persimmon_fruit_mi != null:
		world_hide(persimmon_fruit_mi)
	hold_tool("pole")
	w["scene"] = "gam"
	w["swing"] = 0.0
	# 감이 달릴 자리: 카메라 쪽으로 보이는 나무 앞쪽
	var slots := []
	var r := RandomNumberGenerator.new()
	r.seed = 5
	var tries := 0
	while slots.size() < 11 and tries < 400:
		tries += 1
		var d := Vector3(r.randf_range(-1, 1), r.randf_range(-0.5, 0.35), r.randf_range(0.6, 1)).normalized()
		var p := c + d * persimmon_rad * Vector3(1.35, 0.85, 1.45)
		var ok := true
		for q in slots:
			if (q as Vector3).distance_to(p) < 0.75:
				ok = false
				break
		if ok:
			slots.append(p)
	var fruits := []
	for p in slots:
		var f := blob_node([[Vector3.ZERO, Vector3(0.44, 0.38, 0.44), Color(0.45, 0.65, 0.2)], [Vector3(0, 0.19, 0), Vector3(0.2, 0.06, 0.2), Color(0.25, 0.4, 0.15)]])
		f.global_position = p
		f.visible = false
		fruits.append({"node": f, "pos": p, "state": "empty", "t": r.randf_range(0.3, 6.0), "dur": 0.0})
	w["fruits"] = fruits
	# 꼭대기 까치밥 세 알과 까치
	var top := c + Vector3(0.2, persimmon_rad * 0.75, 0.5)
	var kk := []
	for k in 3:
		var kp := top + Vector3((k - 1) * 0.42, absf(k - 1) * -0.18, 0.1)
		var kf := blob_node([[Vector3.ZERO, Vector3(0.34, 0.3, 0.34), Color(0.92, 0.3, 0.06)], [Vector3(0, 0.15, 0), Vector3(0.16, 0.05, 0.16), Color(0.25, 0.4, 0.15)]])
		kf.global_position = kp
		kk.append(kf)
	w["kkachi"] = kk
	var bird := blob_node([
		[Vector3(0, 0, 0), Vector3(0.26, 0.24, 0.4), Color(0.08, 0.08, 0.12)],
		[Vector3(0.0, -0.03, 0.04), Vector3(0.2, 0.14, 0.24), Color(0.96, 0.96, 0.96)],
		[Vector3(0, 0.13, 0.16), Vector3(0.17, 0.16, 0.17), Color(0.08, 0.08, 0.12)],
		[Vector3(0, 0.12, 0.27), Vector3(0.05, 0.04, 0.09), Color(0.2, 0.2, 0.22)],
		[Vector3(0, 0.04, -0.34), Vector3(0.08, 0.05, 0.42), Color(0.1, 0.12, 0.25)],
	])
	bird.global_position = top + Vector3(0.85, 0.12, 0.0)
	bird.rotation.y = -0.6
	w["bird"] = bird
	# 땅에 놓인 바구니
	var basket := Node3D.new()
	world_node(basket)
	basket.global_position = stand + Vector3(-0.8, 0, 0.4)
	add_mcyl(basket, thatch_dark_mat, 0.32, 0.24, 0.3, Vector3(0, 0.15, 0))
	add_blobs(basket, [[Vector3(0, 0.29, 0), Vector3(0.6, 0.08, 0.6), Color(0.9, 0.78, 0.5)]], thatch_blob_mat)
	w["basket"] = basket
	w["in_basket"] = 0
	gam_info()

func gam_info() -> void:
	mg_progress = float(mg_count) / GAM_GOAL
	mg_info.text = "감 %d/%d | 남은 기회 %d" % [mg_count, GAM_GOAL, mg_lives]

func gam_ripe_color(k: float) -> Color:
	return Color(0.45, 0.65, 0.2).lerp(Color(0.98, 0.62, 0.12), clampf(k * 1.4, 0, 1)).lerp(Color(0.94, 0.32, 0.05), clampf(k * 1.4 - 0.4, 0, 1))

func update_gam(delta: float) -> void:
	var fruits: Array = w["fruits"]
	var speed := 1.0 + mg_count * 0.04
	var growing := 0
	for f in fruits:
		if f["state"] != "empty":
			growing += 1
	for f in fruits:
		var n: Node3D = f["node"]
		f["t"] = float(f["t"]) - delta * speed
		match f["state"]:
			"empty":
				if float(f["t"]) <= 0.0 and growing < 4:
					f["state"] = "green"
					f["dur"] = 0.0
					f["t"] = rng.randf_range(3.2, 5.0)
					n.visible = true
					n.scale = Vector3.ONE * 0.01
					n.global_position = f["pos"]
					gam_color(n, 0.0)
					growing += 1
			"green":
				f["dur"] = float(f["dur"]) + delta * speed
				var k := clampf(float(f["dur"]) / (float(f["dur"]) + maxf(float(f["t"]), 0.001)), 0, 1)
				n.scale = Vector3.ONE * minf(1.0, float(f["dur"]) * 4.0)
				gam_color(n, k * 0.75)
				n.global_position = (f["pos"] as Vector3) + Vector3(0, sin(anim_t * 2.0 + n.position.x) * 0.02, 0)
				if float(f["t"]) <= 0.0:
					f["state"] = "ripe"
					f["t"] = 3.0
					gam_color(n, 1.0)
					add_target_marker(n)
					pop3d(n)
			"ripe":
				var left := clampf(float(f["t"]) / 3.0, 0, 1)
				n.scale = Vector3.ONE * (1.0 + sin(anim_t * 9.0) * 0.06)
				update_target_marker(n, f["pos"], 1.0 - left)
				if float(f["t"]) <= 0.0:
					# 너무 익어서 툭 떨어졌어요
					hide_target_marker(n)
					f["state"] = "drop"
					f["vy"] = 0.0
					mg_lives -= 1
					mg_perfect = false
					sfx("bad")
					shake(8)
					float_text("홍시가 떨어졌어요!", cam.unproject_position(f["pos"]), Color(1, 0.55, 0.45), 1.0)
					gam_info()
			"drop":
				f["vy"] = float(f["vy"]) - 12.0 * delta
				n.global_position.y += float(f["vy"]) * delta
				if n.global_position.y <= 0.4:
					splash_gam(n.global_position)
					gam_reset(f)
			"pick":
				# 장대에 맞아 포물선을 그리며 바구니로
				var u := clampf(float(f["dur"]) + delta * 2.4, 0, 1)
				f["dur"] = u
				var a: Vector3 = f["from"]
				var b: Vector3 = (w["basket"] as Node3D).global_position + Vector3(0, 0.35, 0)
				n.global_position = a.lerp(b, u) + Vector3(0, sin(u * PI) * 0.8, 0)
				n.rotation.x += delta * 9.0
				if u >= 1.0:
					sfx("coin", 1.0 + mg_count * 0.05)
					w["in_basket"] = int(w["in_basket"]) + 1
					var bk: Node3D = w["basket"]
					var heap := blob_node([[Vector3.ZERO, Vector3(0.24, 0.21, 0.24), Color(0.94, 0.38, 0.06)]])
					var ib: int = w["in_basket"]
					heap.global_position = bk.global_position + Vector3(cos(ib * 2.4) * 0.14, 0.33 + ib * 0.025, sin(ib * 2.4) * 0.14)
					pop3d(bk)
					gam_reset(f)
	var bird: Node3D = w["bird"]
	bird.rotation.x = -0.4 * maxf(0.0, sin(anim_t * 5.0))
	gam_info()

func gam_color(n: Node3D, k: float) -> void:
	for mm in n.find_children("*", "MultiMeshInstance3D", true, false):
		var mmi := mm as MultiMeshInstance3D
		mmi.multimesh.set_instance_color(0, gam_ripe_color(k))
		return

func gam_reset(f: Dictionary) -> void:
	var n: Node3D = f["node"]
	n.visible = false
	n.rotation = Vector3.ZERO
	f["state"] = "empty"
	f["t"] = rng.randf_range(1.5, 3.0)

func splash_gam(at: Vector3) -> void:
	burst3d(at, Color(0.95, 0.4, 0.1), 12)
	sfx("pop", 0.6)

func gam_tap(pos: Vector2) -> void:
	var best := -1
	var best_d := short_side * 0.12
	var fruits: Array = w["fruits"]
	for i in fruits.size():
		var f: Dictionary = fruits[i]
		if f["state"] != "green" and f["state"] != "ripe":
			continue
		var sp := cam.unproject_position(f["pos"])
		var d := sp.distance_to(pos)
		if d < best_d:
			best_d = d
			best = i
	var kk: Array = w["kkachi"]
	for k in kk.size():
		var kn: Node3D = kk[k]
		if not kn.visible:
			continue
		var d2 := cam.unproject_position(kn.global_position).distance_to(pos)
		if d2 < best_d:
			best_d = d2
			best = 100 + k
	if best >= 100:
		var kn2: Node3D = kk[best - 100]
		mg_lives -= 1
		mg_perfect = false
		sfx("bad")
		shake(10)
		w["swing"] = 1.0
		float_text("까치밥은 남겨 둬야지!", cam.unproject_position(kn2.global_position), Color(1, 0.5, 0.4), 1.2)
		var bird: Node3D = w["bird"]
		pop3d(bird)
		sfx("chirp", 0.8)
		gam_info()
		return
	if best >= 0:
		gam_pick(best)

func gam_pick(i: int) -> void:
	var f: Dictionary = w["fruits"][i]
	var n: Node3D = f["node"]
	w["swing"] = 1.0
	if f["state"] == "green":
		mg_lives -= 1
		mg_perfect = false
		sfx("bad")
		shake(8)
		float_text("아직 떫어요!", cam.unproject_position(f["pos"]), Color(1, 0.55, 0.45), 1.1)
		pop3d(n)
		gam_info()
		return
	if f["state"] != "ripe":
		return
	hide_target_marker(n)
	mg_count += 1
	sfx("crack", 1.5)
	shake(4)
	hit_stop(0.04)
	cam_kick = 0.1
	burst3d(n.global_position, Color(1.0, 0.7, 0.2), 10)
	float_text(["톡!", "쏙!", "잘 익었다!"][mg_count % 3], cam.unproject_position(n.global_position), Color(1, 0.95, 0.7), 1.2)
	f["state"] = "pick"
	f["dur"] = 0.0
	f["from"] = n.global_position
	gam_info()

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

# ---------- 글꼴 데이터 (주아체, SIL OFL 라이선스, 압축됨) ----------
const FONT_B64 := "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"
