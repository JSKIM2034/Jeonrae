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

var proverbs := [
	"콩 심은 데 콩 나고 팥 심은 데 팥 난다.",
	"가는 말이 고와야 오는 말이 곱다.",
	"티끌 모아 태산.",
	"백지장도 맞들면 낫다.",
	"뿌린 대로 거둔다.",
	"고생 끝에 낙이 온다.",
	"하늘은 스스로 돕는 자를 돕는다.",
]

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
	make_sounds()
	make_world()
	make_village()
	make_forest()
	make_decor()
	apply_distance_culling(self)
	if light_mode:
		# 3D 화면은 조금 낮은 해상도로 그리고, 글자와 버튼은 그대로 또렷하게
		get_viewport().scaling_3d_scale = 0.7
	make_player()
	make_ui()
	make_game_ui()
	make_fx_ui()
	card_overlay = make_overlay(1.0)
	card_overlay.gui_input.connect(on_card_input)
	card_label = add_label(card_overlay, "", 1.0, 0.08, 0.25, 0.92, 0.75)
	update_quest_text()

	cam = Camera3D.new()
	cam.fov = 64.0
	add_child(cam)
	cam.make_current()
	show_card("흥부와 놀부, 해와 달이 된 오누이...\n\n할머니가 들려주던 옛이야기들이\n하나둘 잊혀 가고 있었어요.", 1.0, 3.2, opening2)

func opening2() -> void:
	show_card("할머니 댁 다락방에서 찾은\n빛바랜 옛이야기 책 한 권.\n\n“우리 이야기를 다시 세상에 들려줘.\n아무도 잊지 않도록.”\n\n책장을 펼치자, 눈부신 빛이...!", 0.0, 3.8, Callable())

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
var tile_tex: ImageTexture
var plaster_tex: Texture2D
var house_rects: Array = []

func make_village_materials() -> void:
	var stone_tex := make_noise_tex(Color(0.62, 0.62, 0.62), Color(1.0, 1.0, 1.0), 0.09, 17)
	stone_mat = make_tex_material(Color(0.86, 0.84, 0.8), stone_tex, 0.6)
	stone_blob_mat = make_tex_material(Color(1.0, 1.0, 1.0), stone_tex, 0.9)
	stone_blob_mat.vertex_color_use_as_albedo = true
	thatch_tex = make_thatch_tex()
	thatch_blob_mat = make_tex_material(Color(1, 1, 1), thatch_tex, 0.7)
	thatch_blob_mat.vertex_color_use_as_albedo = true
	thatch_dark_mat = make_tex_material(Color(0.92, 0.82, 0.62), thatch_tex, 1.4)
	var wtex := make_wood_tex(41, 0)
	wood_mat = make_tex_material(Color(0.62, 0.42, 0.26), wtex, 0.9)
	dark_wood_mat = make_tex_material(Color(0.42, 0.27, 0.16), wtex, 0.9)
	plank_mat = make_tex_material(Color(0.78, 0.57, 0.36), make_wood_tex(43, 32), 0.7)
	tile_tex = make_tile_tex()
	lattice_mat = StandardMaterial3D.new()
	lattice_mat.albedo_texture = make_lattice_tex()
	lattice_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	lattice_mat.roughness = 1.0
	basket_mat = make_tex_material(Color(1, 1, 1), make_weave_tex(), 2.2)
	plaster_tex = make_noise_tex(Color(0.88, 0.86, 0.82), Color(1, 1, 1), 0.035, 23)
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
	tm.albedo_texture = thatch_tex
	tm.albedo_color = Color(1, 1, 1).lerp(roof * 1.25, 0.2)
	tm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	tm.cull_mode = BaseMaterial3D.CULL_DISABLED
	tm.roughness = 1.0
	return tm

var house_scenes := {}

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
		"Straw": make_tex_material(Color(0.95, 0.82, 0.52), thatch_tex, 1.4),
		"Tile": glossy_mat(Color(minf(roof.r * 1.35, 1.0), minf(roof.g * 1.35, 1.0), minf(roof.b * 1.35, 1.0))),
		"TileBase": tile_base, "Lime": make_color(Color(0.95, 0.94, 0.9)),
		"Paint": make_color(Color(0.32, 0.58, 0.48)), "PaintRed": make_color(Color(0.72, 0.28, 0.22)),
	}
	for node in inst.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i)
			var key := m.resource_name if m != null else ""
			if map.has(key):
				mi.set_surface_override_material(i, map[key])
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
	var wtr := add_mbox(self, water_mat, Vector3(w - 0.4, 0.02, d - 0.4), center + Vector3(0, 0.08, 0))
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
	add_mcyl(n, stone_mat, 0.78, 0.85, 0.85, Vector3(0, 0.42, 0))
	var water := add_mcyl(n, water_mat, 0.62, 0.62, 0.04, Vector3(0, 0.78, 0))
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
	add_ribbon(line, width * 1.5, 0.012, worn, seed_v + 3.0)
	add_ribbon(line, width, 0.022, dirt, seed_v)
	var core := make_tex_material(Color(0.72, 0.6, 0.4), sand_mat.albedo_texture, 0.09)
	core.cull_mode = BaseMaterial3D.CULL_DISABLED
	add_ribbon(line, width * 0.38, 0.03, core, seed_v + 7.0)
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
	var wm := water_mat
	wm.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = wm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	creek_mat = water_mat
	# 물가의 진흙 띠
	var bank := make_tex_material(Color(0.6, 0.58, 0.42), sand_mat.albedo_texture, 0.07)
	bank.cull_mode = BaseMaterial3D.CULL_DISABLED
	add_ribbon(line, 3.4, 0.015, bank, 9.0, false)

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
void vertex() {
	float h = max(VERTEX.y - 1.6, 0.0);
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float ph = wp.x * 0.35 + wp.z * 0.27;
	VERTEX.x += sin(TIME * 1.3 + ph) * 0.05 * h;
	VERTEX.z += cos(TIME * 1.05 + ph * 1.3) * 0.035 * h;
}
void fragment() {
	ALBEDO = COLOR.rgb * vec3(0.72, 0.8, 0.82);
	ROUGHNESS = 0.85;
	SPECULAR = 0.25;
}
"""
	leaf_mat = ShaderMaterial.new()
	leaf_mat.shader = sh
	bark_mat = make_tex_material(Color(0.5, 0.35, 0.22), wood_mat.albedo_texture, 1.6)
	bark_red_mat = make_tex_material(Color(0.66, 0.38, 0.24), wood_mat.albedo_texture, 1.6)

func make_tree(pos: Vector3) -> void:
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

func make_person_model(parent: Node3D, kind: String, c: Color) -> Node3D:
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
	sun.rotation_degrees = Vector3(-42, 38, 0)
	sun.light_color = Color(1.0, 0.93, 0.8)
	sun.light_energy = 0.66
	# 부드러운 그림자 (가까운 곳만 그려서 가볍게)
	sun.shadow_enabled = SHADOWS_ON
	sun.shadow_blur = 1.6
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.0
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
	sky_mat.sky_top_color = Color(0.36, 0.62, 0.92)
	sky_mat.sky_horizon_color = Color(0.78, 0.9, 0.97)
	sky_mat.ground_horizon_color = Color(0.6, 0.78, 0.55)
	sky_mat.ground_bottom_color = Color(0.45, 0.68, 0.42)
	sky.sky_material = sky_mat
	e.sky = sky
	# 따뜻하고 포근한 빛: 하늘 대신 부드러운 크림색으로 전체를 밝혀요
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(1.0, 0.96, 0.88)
	e.ambient_light_energy = 0.56
	# 멀리는 살짝 뿌옇게 (공기감) + 색을 조금 선명하게
	e.fog_enabled = true
	e.fog_light_color = Color(0.72, 0.84, 0.92)
	e.fog_density = 0.0018
	e.fog_sky_affect = 0.0
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = 1.02
	e.tonemap_white = 5.0
	e.adjustment_enabled = true
	e.adjustment_saturation = 1.12
	e.adjustment_contrast = 1.02
	env.environment = e
	add_child(env)

	var full := MAP_HALF * 2.0
	var none := Color(0, 0, 0, 0)
	var ground_col := add_solid(Vector3(0, -0.5, 0), Vector3(full, 1, full), Color(0.45, 0.7, 0.35))
	(ground_col.get_parent().get_child(0) as MeshInstance3D).material_override = grass_mat
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
	for pos in [Vector3(14, 0, -6.5), Vector3(-31, 0, -12), Vector3(-9, 0, -36), Vector3(35, 0, 33), Vector3(-27.5, 0, 23.5), Vector3(30.8, 2.2, 5.6)]:
		var p := make_spot(pos, "piece", "", "", true)
		make_piece_visual(p)
	make_south()

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
	flat_ellipse(c, rx + 0.55, rz + 0.55, 0.02, make_tex_material(Color(0.52, 0.44, 0.31), plaster_tex, 0.4))
	flat_ellipse(c, rx, rz, 0.06, water_mat)
	flat_ellipse(c, rx * 0.55, rz * 0.5, 0.065, make_color(Color(0.3, 0.52, 0.7, 1.0)))
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
	make_tree(Vector3(c.x - 5.8, 0, c.z - 4.8))
	make_tree(Vector3(c.x - 6.3, 0, c.z + 4.6))
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
	var mud_water := StandardMaterial3D.new()
	mud_water.albedo_color = Color(0.5, 0.62, 0.56)
	mud_water.roughness = 0.15
	mud_water.metallic_specular = 0.8
	var wtr := add_mbox(self, mud_water, Vector3(w - 0.4, 0.02, d - 0.4), c + Vector3(0, 0.08, 0))
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

func save_south() -> void:
	var cf := ConfigFile.new()
	cf.load("user://save.cfg")
	cf.set_value("ch1", "fish", fish_caught)
	cf.set_value("ch1", "fish_reward", fish_reward)
	cf.set_value("ch1", "harvests", harvests)
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
		var ctr := (aabb.position + aabb.size * Vector3(0.5, 0.68, 0.5)) * mi.scale
		var rad := aabb.size.x * 0.5 * mi.scale.x * 0.82
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
	add_box(self, Color(0.42, 0.66, 0.38), Vector3(600, 1, 600), Vector3(0, -0.502, 0)).material_override = grass_mat
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
	pond.material_override = water_mat
	pond.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pond.position = Vector3(33.5, 0.05, -35.5)
	add_child(pond)
	make_npc("woodman", "나무꾼", Color(0.55, 0.42, 0.3), Vector3(28, 0, -33), 1.0, true)
	make_npc("sansin", "산신령", Color(0.95, 0.95, 1.0), Vector3(31.5, 0, -35), 1.2, false).visible = false

	var keep_clear := herb_spots + [Vector3(-9, 0, -36), Vector3(-2, 0, -19), Vector3(15, 0, -19.5)]
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
	for i in 6:
		var sp := AudioStreamPlayer.new()
		add_child(sp)
		sound_players.append(sp)

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
	sfx("drum")
	card_done = done
	card_label.text = text
	card_overlay.modulate.a = start_alpha
	card_overlay.visible = true
	var tw := create_tween()
	card_tween = tw
	if start_alpha < 1.0:
		tw.tween_property(card_overlay, "modulate:a", 1.0, 1.0)
	tw.tween_interval(hold)
	tw.tween_property(card_overlay, "modulate:a", 0.0, 1.0)
	tw.tween_callback(end_card)

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
	return talking or mg_active or in_card

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
		get_piece("")
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
	elif kind == "fish":
		start_fishing()
	elif kind == "farm":
		farm_action()

func get_piece(extra: String) -> void:
	pieces_found += 1
	update_quest_text()
	var found := [["이야기 조각 %d/%d" % [pieces_found, PIECE_TOTAL], proverbs[pieces_found - 1]]]
	if extra != "":
		found.insert(0, ["", extra])
	if pieces_found >= PIECE_TOTAL:
		found.append(["이야기 조각", "조각을 모두 모았어요! 책 귀퉁이에 속담 일곱 줄이 새겨졌습니다."])
	say(found, Callable())

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
	], func(): get_piece("산신령이 책에 이야기 한 조각을 새겨 주었다."))

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
	for b in [jump_button, turn_button, action_button]:
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
		walk_phase += delta * 11.0 * dir.length()
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
	pose_person(player_body, sin(walk_phase) * limb_amt, arm_up_amt)
	if dir.length() > 0.1 and on_floor:
		player_body.rotation.x = lerpf(player_body.rotation.x, 0.12, 0.2)
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
