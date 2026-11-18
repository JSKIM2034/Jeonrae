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
		"snake", "kim", "sparrow":
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
