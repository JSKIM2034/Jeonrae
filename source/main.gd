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
	load_controls()
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
	make_book_ui()
	make_settings_ui()
	make_walk_hint()
	apply_hand()
	scatter_items()
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
	show_card("할머니 댁 다락방에서 찾은\n빛바랜 옛이야기 책 한 권.\n\n“우리 이야기를 다시 세상에 들려줘.\n아무도 잊지 않도록.”\n\n책장을 펼치자, 눈부신 빛이...!", 0.0, 3.8, func():
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
	var tx := 0.06
	for tab in [["fish", "물고기"], ["herb", "약초"]]:
		var b := Button.new()
		b.text = tab[1]
		page.add_child(b)
		place(b, tx, 0.09, tx + 0.42, 0.15)
		b.pressed.connect(func(): show_book(tab[0]))
		book_tabs[tab[0]] = b
		tx += 0.46
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
		if radius > 0.0:
			if not node.has_meta("anchor"):
				node.set_meta("anchor", node.position)
			node.position = random_near(node.get_meta("anchor"), radius)

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
	place(settings_button, 0.57, 0.075, 0.76, 0.135)
	settings_overlay = make_overlay(0.55)
	var page := Panel.new()
	page.add_theme_stylebox_override("panel", make_paper(font_size * 0.6))
	settings_overlay.add_child(page)
	place(page, 0.08, 0.28, 0.92, 0.72)
	var title := add_label(page, "설정", 1.0, 0.05, 0.04, 0.95, 0.17)
	title.add_theme_color_override("font_color", INK)
	title.add_theme_constant_override("outline_size", 0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub := add_label(page, "점프 버튼 위치", 0.8, 0.05, 0.18, 0.95, 0.28)
	sub.add_theme_color_override("font_color", Color(0.45, 0.35, 0.25))
	sub.add_theme_constant_override("outline_size", 0)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var opts := [[false, "오른손잡이\n(점프 오른쪽)"], [true, "왼손잡이\n(점프 왼쪽)"]]
	var x := 0.06
	for o in opts:
		var b := Button.new()
		b.text = o[1]
		page.add_child(b)
		place(b, x, 0.3, x + 0.42, 0.55)
		var val: bool = o[0]
		b.pressed.connect(func(): set_hand(val))
		hand_buttons[val] = b
		x += 0.46
	var again := Button.new()
	again.text = "걷기 안내 다시 보기"
	skin_button(again, make_round(Color(0.9, 0.84, 0.7), font_size * 0.35), INK, 0.8)
	page.add_child(again)
	place(again, 0.15, 0.6, 0.85, 0.74)
	again.pressed.connect(func():
		close_settings()
		show_walk_hint())
	var close := Button.new()
	close.text = "닫기"
	skin_button(close, make_round(Color(0.75, 0.45, 0.25), font_size * 0.4), Color(1, 1, 1), 0.85)
	page.add_child(close)
	place(close, 0.3, 0.8, 0.7, 0.94)
	close.pressed.connect(close_settings)
	refresh_hand_buttons()

func refresh_hand_buttons() -> void:
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

func save_south() -> void:
	var cf := ConfigFile.new()
	cf.load("user://save.cfg")
	cf.set_value("ch1", "fish", fish_caught)
	cf.set_value("ch1", "fish_reward", fish_reward)
	cf.set_value("ch1", "harvests", harvests)
	cf.set_value("ch1", "herbs", herb_counts)
	cf.set_value("ch1", "herb_reward", herb_reward)
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
	place(turn_button, 0.03, 0.075, 0.25, 0.135)
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
	elif kind == "wild":
		pick_wild(t)
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
