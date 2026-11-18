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

func pose_rig(body: Node3D, swing: float, arm_up: float) -> void:
	var skel: Skeleton3D = body.get_meta("skel")
	var bones: Dictionary = body.get_meta("bones")
	var a := arm_up
	for side in ["L", "R"]:
		var sx := -1.0 if side == "L" else 1.0
		var lead: bool = side == "L"
		# 다리: 보폭은 작게. 점프하면 무릎을 살짝 당겨요
		var leg := swing * 0.42 * sx
		# 무릎은 늘 살짝 굽혀 앞으로 나와 있어요 (허벅지 앞으로, 정강이 뒤로, 발은 땅과 나란히)
		var thigh := leg - 0.14
		turn_bone(skel, bones, "thigh" + side, [[Vector3.RIGHT, lerpf(thigh, -0.5 if lead else -0.2, a)]])
		var knee := clampf(leg * 1.4, 0.0, 0.6) + absf(swing) * 0.12 + 0.26
		turn_bone(skel, bones, "shin" + side, [[Vector3.RIGHT, lerpf(knee, 0.85 if lead else 0.5, a)]])
		turn_bone(skel, bones, "foot" + side, [[Vector3.RIGHT, lerpf(-(thigh + knee) * 0.9 - 0.02, 0.3, a)]])
		# 팔: 몸에서 살짝 떨어뜨려 내리고, 다리와 반대로 크게 흔들어요 (앞으로 갈 때 팔꿈치가 굽어요)
		var fwd := maxf(0.0, swing * sx)
		var down := -sx * lerpf(0.44, 0.25, a)
		# 앞으로 갈 때 위팔(이두)이 더 올라와요
		var arm_swing := lerpf(-swing * sx * (0.75 if swing * sx > 0.0 else 0.42) - 0.08, -0.35, a)
		var twist: Vector3 = (bones["arm" + side] as Array)[3] if bones.has("arm" + side) else Vector3.UP
		# 순서: 비틀기 → 내리기 → 앞뒤 흔들기 (뒤에 적힌 것부터 적용돼요)
		turn_bone(skel, bones, "arm" + side, [[Vector3.RIGHT, arm_swing], [Vector3.BACK, down], [twist, sx * 0.9]])
		var elbow := -0.3 - fwd * 0.6
		turn_bone(skel, bones, "fore" + side, [[Vector3.RIGHT, lerpf(elbow, -0.9, a)]])
	turn_bone(skel, bones, "spine", [[Vector3.UP, swing * 0.08], [Vector3.RIGHT, a * 0.06]])
	turn_bone(skel, bones, "head", [[Vector3.UP, -swing * 0.05], [Vector3.RIGHT, -a * 0.1]])

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
