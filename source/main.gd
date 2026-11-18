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
	# 게임이 끝난 뒤 늦게 불리면 아무것도 안 해요
	if not mg_active or mg_type != "wood3d" or not w.has("stump"):
		return
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
	var earth := make_tex_material(Color(0.5, 0.42, 0.3), plaster_tex, 0.4)
	add_mbox(self, earth, Vector3(w + 0.5, 0.25, 0.5), c + Vector3(0, 0.12, d / 2.0))
	add_mbox(self, earth, Vector3(w + 0.5, 0.25, 0.5), c + Vector3(0, 0.12, -d / 2.0))
	add_mbox(self, earth, Vector3(0.5, 0.25, d), c + Vector3(w / 2.0, 0.12, 0))
	add_mbox(self, earth, Vector3(0.5, 0.25, d), c + Vector3(-w / 2.0, 0.12, 0))
	add_mbox(self, earth, Vector3(0.4, 0.2, d), c + Vector3(0, 0.1, 0))
	add_mbox(self, make_color(Color(0.42, 0.34, 0.24)), Vector3(w - 0.4, 0.04, d - 0.4), c + Vector3(0, 0.02, 0))
	var pmat := water_material(2, Vector4(c.x, c.z, w / 2.0 - 0.2, d / 2.0 - 0.2), Color(0.3, 0.3, 0.2), Color(0.46, 0.42, 0.3), Vector2.ZERO, 0.12)
	pmat.set_shader_parameter("spec", 0.25)
	pmat.set_shader_parameter("rough", 0.3)
	pmat.set_shader_parameter("mud", 1.0)
	var wtr := add_mbox(self, pmat, Vector3(w - 0.4, 0.02, d - 0.4), c + Vector3(0, 0.08, 0))
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
	# 논두렁에 난 풀
	var bank_mm := MultiMesh.new()
	bank_mm.transform_format = MultiMesh.TRANSFORM_3D
	bank_mm.use_colors = true
	bank_mm.mesh = make_tuft_mesh()
	var tufts := []
	for k in 70:
		var side := k % 5
		var t := r.randf_range(-0.5, 0.5)
		var q := Vector3.ZERO
		match side:
			0: q = Vector3(t * w, 0.25, d / 2.0 + r.randf_range(-0.15, 0.15))
			1: q = Vector3(t * w, 0.25, -d / 2.0 + r.randf_range(-0.15, 0.15))
			2: q = Vector3(w / 2.0 + r.randf_range(-0.15, 0.15), 0.25, t * d)
			3: q = Vector3(-w / 2.0 + r.randf_range(-0.15, 0.15), 0.25, t * d)
			_: q = Vector3(r.randf_range(-0.12, 0.12), 0.2, t * d)
		tufts.append(c + q)
	bank_mm.instance_count = tufts.size()
	for k in tufts.size():
		var bs := Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3.ONE * r.randf_range(0.5, 0.9))
		bank_mm.set_instance_transform(k, Transform3D(bs, tufts[k]))
		bank_mm.set_instance_color(k, Color(0.42, 0.66, 0.32).lerp(Color(0.62, 0.82, 0.42), r.randf()))
	var bank_mi := MultiMeshInstance3D.new()
	bank_mi.multimesh = bank_mm
	bank_mi.material_override = grass_material()
	bank_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bank_mi)
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
	# 멀리 겹겹이 보이는 부드러운 산 능선 (가까운 초록 언덕, 먼 푸른 산)
	add_ridge_ring(84.0, 26.0, 9.0, 22.0, Color(0.28, 0.48, 0.24), Color(0.4, 0.58, 0.34), 11)
	add_ridge_ring(128.0, 40.0, 22.0, 46.0, Color(0.34, 0.48, 0.5), Color(0.46, 0.58, 0.64), 23)

func add_ridge_ring(r0: float, depth: float, hmin: float, hmax: float, low: Color, high: Color, seed_v: int) -> void:
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
			col.append(Vector3(cos(ang) * rr, y, sin(ang) * rr))
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

# 산신령 연못: 이끼 낀 돌 테두리, 뒤쪽 갈대, 연잎과 연꽃, 큰 바위
func make_sansin_pond(c: Vector3) -> void:
	var rad := 3.2
	var r := RandomNumberGenerator.new()
	r.seed = 77
	flat_ellipse(c + Vector3(0, -0.01, 0), rad, rad, 0.06, water_material(1, Vector4(c.x, c.z, rad, rad), Color(0.1, 0.32, 0.46), Color(0.38, 0.64, 0.68)))
	var stones := []
	var a := 0.0
	while a < TAU:
		a += r.randf_range(0.2, 0.32)
		# 나무꾼이 서는 쪽은 낮은 조약돌만
		var front := absf(wrapf(a - 2.53, -PI, PI)) < 0.45
		var k := r.randf_range(0.0, 0.3)
		var sz := Vector3(r.randf_range(0.5, 0.95), r.randf_range(0.3, 0.55), r.randf_range(0.45, 0.8))
		if front:
			sz = Vector3(0.35, 0.12, 0.3)
		stones.append([c + Vector3(cos(a) * (rad + 0.25 + k), 0.06, sin(a) * (rad + 0.25 + k)), sz, stone_color(r)])
		if not front and r.randf() < 0.4:
			stones.append([c + Vector3(cos(a) * (rad + 0.3 + k), sz.y * 0.45, sin(a) * (rad + 0.3 + k)), sz * Vector3(0.7, 0.25, 0.7), Color(0.36, 0.5, 0.26)])
	# 뒤편의 큰 이끼 바위
	stones.append([c + Vector3(1.6, 0.5, -3.3), Vector3(1.8, 1.3, 1.4), Color(0.56, 0.56, 0.54)])
	stones.append([c + Vector3(1.6, 1.1, -3.3), Vector3(1.4, 0.3, 1.1), Color(0.38, 0.52, 0.28)])
	stones.append([c + Vector3(2.6, 0.3, -2.6), Vector3(0.9, 0.7, 0.8), Color(0.6, 0.59, 0.56)])
	add_blobs(self, stones, stone_blob_mat)
	var reeds := []
	for ang in [-1.2, -0.7, -0.2, 0.4, 0.9]:
		var base := c + Vector3(cos(ang) * rad * 0.95, 0, sin(ang) * rad * 0.95)
		for i in 6:
			var p := base + Vector3(r.randf_range(-0.4, 0.4), 0, r.randf_range(-0.4, 0.4))
			var hgt := r.randf_range(0.9, 1.5)
			var tilt := Vector3(r.randf_range(-12, 12), 0, r.randf_range(-12, 12))
			reeds.append([p + Vector3(0, hgt * 0.5, 0), Vector3(0.05, hgt, 0.05), Color(0.42, 0.62, 0.28), tilt])
			if i % 2 == 0:
				reeds.append([p + Vector3(0, hgt * 0.85, 0), Vector3(0.1, 0.3, 0.1), Color(0.48, 0.3, 0.16), tilt])
			else:
				reeds.append([p + Vector3(0.06, hgt * 0.35, 0), Vector3(0.16, hgt * 0.6, 0.04), Color(0.5, 0.7, 0.32), tilt + Vector3(0, 0, 18)])
	add_blobs(self, reeds)
	var pads := []
	for i in 7:
		var pa := r.randf_range(-1.6, 1.4)
		var pr := r.randf_range(0.45, 0.85)
		var p := c + Vector3(cos(pa) * rad * pr, 0.075, sin(pa) * rad * pr)
		pads.append([p, Vector3(0.7, 0.04, 0.6), Color(0.36, 0.62, 0.3).lerp(Color(0.48, 0.7, 0.34), r.randf())])
		if i % 2 == 0:
			pads.append([p + Vector3(0.1, 0.08, 0), Vector3(0.24, 0.16, 0.24), Color(1.0, 0.72, 0.82)])
			pads.append([p + Vector3(0.1, 0.14, 0), Vector3(0.1, 0.08, 0.1), Color(1.0, 0.92, 0.5)])
	add_blobs(self, pads, null, true)
	make_tree(c + Vector3(-1.2, 0, -4.6), "Willow0")

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
	make_sansin_pond(Vector3(33.5, 0, -35.5))
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
