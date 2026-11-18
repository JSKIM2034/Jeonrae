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
		"cfg": {"title": "호박에 박힌 말뚝을\n사라지기 전에 눌러 뽑아요", "goal": 8, "interval": 0.9, "life": 1.5, "target": "말뚝", "center": "호박", "color": Color(0.95, 0.6, 0.2), "art": "world", "world": true, "scene": "kim"},
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
			var stand := Vector3(-14.3, 0, 2.6)
			world_game_begin(stand, nest * Vector3(1, 0, 1), stand + Vector3(2.2, 2.0, 3.0), Vector3(-15.0, 1.1, 0.6))
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
			var a := rng.randf_range(-0.9, 0.9)
			return Vector3(-15.08, 0.05, 0.6) + Vector3(sin(a) * 2.6, 0, cos(a) * 2.2)
		"kim":
			var pumps: Array = w["pumps"]
			return (pumps[rng.randi() % 3] as Vector3) + Vector3(rng.randf_range(-0.25, 0.25), 0.55, rng.randf_range(-0.2, 0.2))
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
			add_mbox(n, wood_mat, Vector3(0.09, 0.6, 0.09), Vector3(0, 0.0, 0))
			add_mbox(n, dark_wood_mat, Vector3(0.14, 0.06, 0.14), Vector3(0, 0.3, 0))
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
	pop3d(n, true)
	return n

func scene_target_update(n: Node3D, age: float, life: float) -> Vector3:
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
