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
	add_beam(n, make_color(Color(0.7, 0.6, 0.42)), Vector3(0.2, 1.75, 0), Vector3(0.2, 1.25, 0), 0.025, 0.025)
	add_mcyl(n, wood_mat, 0.17, 0.14, 0.26, Vector3(0.2, 1.12, 0))

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
	add_beam(self, make_color(Color(0.55, 0.42, 0.22)), Vector3(c.x + rx - 2.8, 0.2, c.z + 0.6), tip, 0.04, 0.04)
	var bob_pos := Vector3(c.x + rx - 5.4, 0.1, c.z + 1.6)
	add_beam(self, make_color(Color(0.95, 0.95, 0.95)), tip, bob_pos, 0.012, 0.012)
	var bob := Node3D.new()
	bob.position = bob_pos
	add_child(bob)
	add_ball(bob, Color(0.9, 0.2, 0.2), 0.08, Vector3(0, 0.04, 0))
	add_ball(bob, Color(1, 1, 1), 0.07, Vector3(0, -0.02, 0))
	sway_items.append([bob, bob_pos, 0, 1.3, 0.0])
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
	start_game("fish", {"art": "fish", "title": "찌가 쏙 들어가면 눌러서 채요!\n걸리면 눌렀다 뗐다 하며 초록 칸에"}, fish_done)

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
		start_game("catch", {"art": "water", "title": "두레박을 좌우로 움직여 물방울만 받아요\n돌멩이는 피해요", "goal": 10, "interval": 0.55, "speed": 0.5, "bad_ratio": 0.3, "good": "물", "bad": "돌", "basket": "두레박"}, job_done)
	elif id == "wood":
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
	mg_active = true
	pop(mg_title, 1.15)

func end_game(ok: bool) -> void:
	mg_active = false
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
	if real_press and mg_type == "fish":
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
	cam.position = player.position + (CAM_OFFSET * cam_zoom).rotated(Vector3.UP, cam_yaw)
	cam.look_at(player.position + Vector3(0, 1.3, 0))

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
