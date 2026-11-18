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
		"cfg": {"title": "호박에 박힌 말뚝을\n사라지기 전에 눌러 뽑아요", "goal": 8, "interval": 0.9, "life": 1.5, "target": "말뚝", "center": "호박", "color": Color(0.95, 0.6, 0.2), "art": "kim"},
	},
	"ong": {
		"name": "옹기 할멈",
		"ask": [["옹기 할멈", "놀부가 지나가다 장독을 발로 차서 금이 갔단다."], ["옹기 할멈", "진흙을 살살 돌려 발라 주겠니? 세게 하면 또 깨진단다."]],
		"fail": "에구, 금이 더 갔구나. 다시 살살 해 보자.",
		"done": "감쪽같구나! 장맛을 지켰다.",
		"game": "circle",
		"cfg": {"title": "깨진 장독 둘레에\n진흙을 살살 돌려 발라요", "label": "장독", "turns": 5.0, "max_speed": 10.0, "warn": "너무 세게 바르면 깨져요!", "color": Color(0.5, 0.33, 0.2), "art": "ong", "trail": Color(0.66, 0.48, 0.3)},
	},
	"park": {
		"name": "박 첨지",
		"ask": [["박 첨지", "놀부가 제 논에만 물을 대려고 우리 물꼬를 막아 버렸어!"], ["박 첨지", "나랑 박자 맞춰 삽질 좀 해 다오."]],
		"fail": "박자가 안 맞아 삽이 엇나갔구나. 다시 해 보자.",
		"done": "물이 콸콸 들어온다! 올해 농사는 살았다.",
		"game": "follow",
		"cfg": {"art": "ditch", "title": "박 첨지와 박자 맞춰 삽질!\n아래 손잡이를 좌우로 따라가세요", "slow": 2.0, "tol": 0.4, "goal": 5.0, "patience": 4.0, "color": Color(0.4, 0.6, 0.85)},
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
	hut = make_house(Vector3(-13, 0, -2), Vector3(4.5, 2.8, 3.5), Color(0.93, 0.89, 0.8), Color(0.8, 0.66, 0.3), "thatch")
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
		add_beam(self, crack, c0, c0 + Vector3(0.12, -0.2, 0.02), 0.025, 0.02)
		add_beam(self, crack, c0 + Vector3(0.12, -0.2, 0.02), c0 + Vector3(0.02, -0.4, 0.04), 0.025, 0.02)
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
	world_hidden = []
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
	w = {}

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
	update_quest_text()

func world_node(n: Node3D) -> Node3D:
	add_child(n)
	mg_nodes.append(n)
	return n

func hold_tool(kind: String) -> void:
	drop_tool()
	tool_kind = kind
	tool_node = MeshInstance3D.new()
	var root := Node3D.new()
	if kind == "axe":
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
			start_game("plant", {"art": "plant", "title": "손이 노란 동그라미에 왔을 때 눌러서\n못줄 눈금에 맞춰 모를 심어요"}, plant_done)
		1, 3:
			say([["", "벼가 자라고 있다. (약 %d초 남았어요)" % int(ceil(farm_timer))]], Callable())
		2:
			start_game("tap", {"art": "sparrow", "title": "참새가 벼를 쪼아 먹어요!\n눌러서 훠이 쫓아요", "goal": 10, "interval": 0.75, "life": 1.6, "target": "참새", "center": "허수아비", "color": Color(0.85, 0.72, 0.45)}, sparrow_done)
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

func make_flowers(pos: Vector3, r: RandomNumberGenerator) -> void:
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	var petals := [Color(0.95, 0.4, 0.6), Color(0.98, 0.98, 0.95), Color(0.98, 0.78, 0.12), Color(0.72, 0.45, 0.92)]
	var pc: Color = petals[r.randi() % petals.size()]
	var items := []
	# 작은 잎 뭉치들이 모인 낮은 덤불 + 줄기 끝의 작은 꽃
	var base_g := Color(0.3 + 0.08 * r.randf(), 0.55 + 0.08 * r.randf(), 0.26)
	for i in 11:
		var a := r.randf() * TAU
		var d := r.randf_range(0.0, 0.42)
		var y := r.randf_range(0.12, 0.42) * (1.0 - d * 0.8)
		var sz := r.randf_range(0.2, 0.34)
		items.append([Vector3(cos(a) * d, y, sin(a) * d), Vector3(sz, sz * 0.8, sz), base_g.lightened(r.randf() * 0.2 + y * 0.3)])
	for i in 8:
		var a := r.randf() * TAU
		var d := r.randf_range(0.05, 0.42)
		items.append([Vector3(cos(a) * d, r.randf_range(0.38, 0.55) - d * 0.3, sin(a) * d), Vector3(0.1, 0.07, 0.1), pc if i % 4 != 0 else Color(1.0, 0.95, 0.6)])
	add_blobs(root, items)
	sway_items.append([root, Vector3.ZERO, 1, pos.x * 1.1 + pos.z, 0.05])

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
	var q := QuadMesh.new()
	q.size = Vector2(0.2, 0.2)
	var mat := make_color(Color(0.98, 0.62, 0.22))
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	q.material = mat
	p.mesh = q
	parent.add_child(p)

func make_butterflies(r: RandomNumberGenerator) -> void:
	var spots := [Vector3(-8.9, 0, 2.2), Vector3(6.4, 0, 2.6), Vector3(-4.4, 0, -7), Vector3(0.7, 0, 18), Vector3(-5.6, 0, -12.5), Vector3(21.6, 0, 2.6), Vector3(-18.6, 0, 2.4)]
	var cols := [Color(1.0, 0.9, 0.35), Color(1.0, 1.0, 1.0), Color(1.0, 0.65, 0.8), Color(0.7, 0.85, 1.0)]
	for i in spots.size():
		var root := Node3D.new()
		add_child(root)
		add_box(root, Color(0.25, 0.18, 0.12), Vector3(0.05, 0.05, 0.2), Vector3.ZERO)
		var c: Color = cols[i % cols.size()]
		var left := Node3D.new()
		var right := Node3D.new()
		root.add_child(left)
		root.add_child(right)
		add_box(left, c, Vector3(0.24, 0.02, 0.2), Vector3(-0.13, 0, 0))
		add_box(right, c, Vector3(0.24, 0.02, 0.2), Vector3(0.13, 0, 0))
		butterflies.append([root, left, right, spots[i], r.randf_range(1.2, 2.2), r.randf_range(0.5, 0.9), r.randf_range(0, TAU)])

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
		var flap := sin(t * 18.0 + b[6]) * 0.9
		(b[1] as Node3D).rotation.z = flap
		(b[2] as Node3D).rotation.z = -flap
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
		sp.bus = "SFX"
		add_child(sp)
		sound_players.append(sp)

# ---------- 배경음, 자연 소리, 소리 켜고 끄기 ----------
var music_on := true
var sfx_on := true
var bgm_player: AudioStreamPlayer
var amb_player: AudioStreamPlayer
var creek_player: AudioStreamPlayer3D

func setup_audio() -> void:
	for bus_name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var bi := AudioServer.bus_count - 1
			AudioServer.set_bus_name(bi, bus_name)
			AudioServer.set_bus_send(bi, "Master")
	var cf := ConfigFile.new()
	if cf.load("user://save.cfg") == OK:
		music_on = cf.get_value("ui", "music_on", true)
		sfx_on = cf.get_value("ui", "sfx_on", true)
	apply_audio_toggles()
	if ResourceLoader.exists("res://sounds/bgm.ogg"):
		bgm_player = AudioStreamPlayer.new()
		bgm_player.stream = load("res://sounds/bgm.ogg")
		bgm_player.bus = "Music"
		bgm_player.volume_db = -11.0
		add_child(bgm_player)
		bgm_player.play()
	if ResourceLoader.exists("res://sounds/ambience.ogg"):
		amb_player = AudioStreamPlayer.new()
		amb_player.stream = load("res://sounds/ambience.ogg")
		amb_player.bus = "SFX"
		amb_player.volume_db = -14.0
		add_child(amb_player)
		amb_player.play()
	if ResourceLoader.exists("res://sounds/creek.ogg"):
		# 개울에서 가장 가까운 곳을 따라다니며 졸졸 소리가 나요
		creek_player = AudioStreamPlayer3D.new()
		creek_player.stream = load("res://sounds/creek.ogg")
		creek_player.bus = "SFX"
		creek_player.unit_size = 4.0
		creek_player.max_distance = 22.0
		creek_player.volume_db = -4.0
		add_child(creek_player)
		creek_player.play()

func apply_audio_toggles() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), not music_on)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("SFX"), not sfx_on)

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
	start_game("catch", {"title": "놀부 마누라의 밥주걱은 피하고\n튀는 밥풀만 바가지로 받으세요", "goal": 12, "interval": 0.6, "speed": 0.42, "bad_ratio": 0.35, "good": "밥풀", "bad": "주걱", "basket": "바가지", "art": "rice"}, rice_done)

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
	start_game("tap", {"title": "구렁이가 제비 둥지로 기어와요!\n닿기 전에 눌러서 쫓아내세요", "goal": 12, "interval": 0.75, "life": 1.6, "target": "구렁이", "center": "둥지", "color": Color(0.5, 0.38, 0.25), "art": "snake"}, snake_done)

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
	start_game("circle", {"art": "heal", "trail": Color(1, 1, 1), "title": "다친 제비 다리에 부목을 대고\n둘레를 천천히 돌며 실을 감아요", "label": "제비", "turns": 6.0, "max_speed": 11.0, "warn": "너무 빨라요! 제비가 아파해요", "color": Color(0.2, 0.22, 0.35)}, heal_done)

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
	start_game("follow", {"art": "saw", "title": "슬근슬근 톱질하세! (%d번째 박)\n아래 손잡이를 흥부와 같이 좌우로" % (gourds_done + 1), "slow": 2.4 - gourds_done * 0.35, "tol": 0.42 - gourds_done * 0.04, "goal": 6.0, "patience": 4.0 - gourds_done * 0.5, "color": Color(0.82, 0.9, 0.62)}, saw_done)

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
	elif id == "wood_2d":
		start_game("tap", {"art": "wood", "title": "통나무가 올라오면\n눌러서 쩍! 장작을 패요", "goal": 10, "interval": 0.7, "life": 1.3, "target": "장작", "center": "나무", "color": Color(0.5, 0.35, 0.2)}, job_done)
	else:
		start_game("circle", {"art": "straw", "trail": Color(0.9, 0.78, 0.42), "title": "짚을 빙글빙글 꼬아 짚신을 삼아요\n너무 빠르면 짚이 끊어져요", "label": "짚신", "turns": 5.0, "max_speed": 12.0, "warn": "짚이 끊어질 것 같아요!", "color": Color(0.8, 0.68, 0.35)}, job_done)

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
		say([["장터 상인", "엽전이 모자라는구나. 우물, 나무터, 짚더미에서 품을 팔거나 남쪽 연못에서 낚시를 하고, 최 영감네 논일을 도우면 엽전을 벌 수 있단다."]], Callable())
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
		["산신령", "책 밖에서 온 아이야, 네가 대신 답해 보아라."],
	], func(): ask("산신령", "이 번쩍이는 금도끼가 저 나무꾼의 도끼냐?", ["아니에요", "맞아요"], on_axe_gold))

func on_axe_gold(i: int) -> void:
	if i == 1:
		axe_lie()
	else:
		ask("산신령", "그러면 이 은도끼가 나무꾼의 도끼냐?", ["맞아요", "아니에요"], on_axe_silver)

func on_axe_silver(i: int) -> void:
	if i == 0:
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
		["산신령", "허허, 거짓을 말하는구나. 정직하지 못한 자에겐 아무것도 줄 수 없다."],
		["", "산신령이 연못 속으로 사라졌다. 나무꾼에게 다시 말을 걸어 보자."],
	], Callable())

# ---------- 미니게임 공통 ----------

func start_game(type: String, cfg: Dictionary, done: Callable) -> void:
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
	else:
		update_tap(delta)
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
	var basket_y := h * 0.78
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
		mg_move(item, rng.randf_range(w * 0.12, w * 0.88), h * 0.37)
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
