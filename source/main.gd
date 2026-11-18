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
		var lead: bool = side == "L"   # 점프할 때 (가방끈 없는 쪽) 주먹을 위로 "얍!"
		# 다리: 보폭은 작게. 점프하면 왼쪽 무릎을 올리고 오른다리는 뒤로
		var leg := swing * 0.42 * sx
		turn_bone(skel, bones, "thigh" + side, [[Vector3.RIGHT, lerpf(leg, 0.25 if lead else -0.95, a)]])
		var knee := clampf(leg * 1.4, 0.0, 0.6) + absf(swing) * 0.12
		turn_bone(skel, bones, "shin" + side, [[Vector3.RIGHT, lerpf(knee, 0.7 if lead else 1.35, a)]])
		turn_bone(skel, bones, "foot" + side, [[Vector3.RIGHT, lerpf(-knee * 0.4, 0.35, a)]])
		# 팔: 몸 옆으로 내리고 주먹이 허벅지를 보게 돌린 다음, 다리와 반대로 흔들어요
		var fwd := maxf(0.0, swing * sx)
		var down := -sx * lerpf(0.78, -2.15 if lead else 0.7, a)
		var arm_swing := lerpf(-swing * 0.5 * sx, -0.35 if lead else 0.55, a)
		var twist: Vector3 = (bones["arm" + side] as Array)[3] if bones.has("arm" + side) else Vector3.UP
		turn_bone(skel, bones, "arm" + side, [[Vector3.BACK, down], [Vector3.RIGHT, arm_swing], [twist, sx * 1.25]])
		var elbow := -0.22 - fwd * 0.45
		turn_bone(skel, bones, "fore" + side, [[Vector3.RIGHT, lerpf(elbow, -0.15 if lead else -0.7, a)]])
	turn_bone(skel, bones, "spine", [[Vector3.UP, swing * 0.07 + a * 0.12], [Vector3.RIGHT, a * 0.08]])
	turn_bone(skel, bones, "head", [[Vector3.UP, -swing * 0.04], [Vector3.RIGHT, -a * 0.12]])

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
const FONT_B64 := "eNq0vQmAZWdZJny/7+z7vtxz7zl3OXepW3vVXWrp6upOL+l0p9PdSTorW0ISwJAITgCjggsKAv4oiKOAzvzOKODI/O6gDC4gCC7MwIi//AyICu6jgiCIaKr/5zvn3qrqJIQBSeemuu926pzvfb93ed7nfU+FVCoVo/KdFa5y6cylizefetH5F1b4z/04Xm2eufmWE5VqRcfzd+G5ffHmlfXVm+eeXeE/2cHzu+558O7nf/S22j14/j2VivWuZ9/90PPZ5/D51+Nv+dkPfMuz/uALbx7j3x+v8L8XPue+u+/1je/4WIX/w8/gtclz8IL0IuEX8X08rXSe8+ALHl755I2vrvAfmatU1P/vgefdc7fwheM/XOE/4OP5xx+8++Hn018nezjWP7Lz+8a7H7wvePnKT1T4z56qVMj685/30Auu/EplHb//YfZ+hVauvfKZysfplyppZVipeLtkuB5GGRUDp04kkyyTPh69ydgZTbyMRBkx91/ewIcn4S1y3dACNXAFTpJ68z2J4wgh4rdxAuWoaOpaVo8FgQhiYnld+qeGTqg4GI/svY/6c65jE8dWaprT9chFvffIqwRF1OLIFwQq2obZNS2N8DjJU/QB8gB3DxauhZPE6eB341xS4ouS2Nt49As3W5SQwZIrc5678ubDT+iLrb5/w2rTl/vBDd6crlHz0S+Ua0I/Sj9V+ebKt2HVQlywtJ7R2cXn0voE/5Z8k7Tztkklk5PEZYozYI+8+AweWKHylXks13g02VgPhxt5e5mOR7v0CNnl8F5WfHa4ukvHxWczQvAZ+n2iKGiCktQigRd40+RXepmeR4FHsvkVh+ISCS+akW/XfIVSiedl7ptFTRQc311ydV7UOE7ijLwZOqG/7M9tapGnWXHdOMYrVuB4nUQTJUN8oSCKYi1Q48jde+e39B6mv2jEySQhgiyKYeRRSt9KKUn8wJfSvMk5rbrPUdWvW1ZqOl2nup6ES4Yhunqz3TLN1JQ912sQ8lZOcQw70AVvdWXetAW7U61v16N6TKMjpkgld++Ot2IvzV35ID3KCZXnVl5YeWmlIpRKxa0VP8u1mxRrHo2nStgvl3EyXegdUso88sMoDArdZIspss/1p89FaSYNqS1mJPC54vVobBKC3+KHUrhLyQuVZqvGQ2tJdDSyWllVhC47luq7rhIdTdwl0wjkRV9VZVGv6Q3XGfmy7vtuXcJXmqfrYY0Q37TrhrMUBcvO5pgSU/Z1ve448z477DuJLiuJ1VogNrWimsERKwuN2NB5z6GuZ3OaLBpOZOu1xIfodAty4n9GVHlBEpyO2438HF/QbVmWqdnQHJNS06WOqplSYJt5YiaUWpLs0FeJnhTds9VrmrGqWbKg8IZtEYcKsieKEv0mmu79vhG5Bpefyani1StCZXjlj+kf0k9W6pXTlbsqL6q8upBFuevLlWYLlnFRyBaTCw8tqcnk1B/NBMIe3MYkjIjYfsz3Sfl9wl7rj5iMyoMU75UbZfzol+lDrd1mPCcrvCgtpNFqFM45sqlKRBAMdbFHfc2sm73re3bDUYJaOzRdEmpmw+qd75lNS3bDxHEyuvejzdPNOJdlTpQWi6P0HcejgqRpA7LqyJZEsKJt0zQIpYLtyMHeG2VNsDjZsZqmrcOcFa9GWHt1XG0eb6VjRYaVM0wpqiZa73ie1ugvBHNOMkpOvfx0eiSzek2Xo6EZzfu1cXL6FafrmzUzq/kc73t7X5JNZRy3jjfTsSpzhBqmORf0LnZqjb3vp4q56FoLikwkKbb0dqvGwXj9MhEFa8mz+7gGWY4sLW/X8EVsouNXPkV/mv555abK/ZWXQHDlTlmeyiJaplhuGharDzvF/mqQ3i5l78GYceVaM3NfbBtuo3heSHGZFiIsdhQ7gFeIqDh48VpGiaqF2txZ19Y4Wq1S3dSJH4mSap+69an9pQFPiZ5EiidoakgkVSFyWK1bJjTSMnnFUYhFxJotJl5fp5omUW9Qy8+1rHazKlJRVTm56nQH/SPwIYZ3rtnKOI7yphVsRp5LOSUeVCnHyfP95rk8v65KNV0h1Z1jx+orm4EWhLetVkfri7YcyGa0gjc1osWezPNetVb1BbNqUIfqa6MlSfBNansuH3Wxl76RGn7VkjzfFb2eGgr8aCEaurFHnkLn61Zar6oWb2kNP17JvQqpPI8+UPlU4ZQe65K+/YmdDr596sovwQQllY3pfuP6M+GNr9pR+z5XEgN/upWY8xFJJnctsxp6EqyTrHM85QXBVNTQ0tJIb1uuLFm8GcuJyMuyaKliRMnEUEQhrKd6vJZUh/XkSBpNsuaRRgP/WLcliVI7jNXumc5DD21NqmtJvB45A48XcL4jnG9Wnm+Ec5xt7o3JeFScNlRtEu6fX8SM7b6pgH/snSKERqJqibLMi4kcm4Ipya7V1qNUs0JVMQUBV8DpshwY2LpV0+pO4Py8gROtx8ladbL10EOdM101Dm24PMlej1J23s1sgn8k9WE1WYv1tB4KooKzXa28h8r03srNzH8z0yP2Fsj+4s3imkc56rYozRe7ZxIeIb1yG+HjjenbuDy2i4bbhHxJI1TVtEy/QYs0QYWb5LU0q8laoK2Ktm7CViu8KeNNv+cZVd0VHHPgHLUNvSZwdcfN1Y4e67Jl6pli8H5dvdbqkbcrpl4TRc7NXdlXJUtyZS3WnYZzvRoJIvZQXE10p+1QImpLpsZFgbMY2VC0trXldTzNhdvS3MFcx8ICDCo/Qv6evrSygwWI2JkX4qDtBRKw1cjbuD46Gvfztsj2eaFz3DAq5cpiwFCMyPHnO45pSqLsOhq5n8MV+2pTkCWOXNYsQ5cDx1YNzdDOEmrKdc2sCcwjvpeUnwzZJ1/g5MURqrFDnktggq0QH4OyEnJDtOZoumcHixFOuHHlDysfqfx0JYF+9fqlkWIRANMek9s2ZQErgMAkqWlGzVMEPq4nMIuOO6DMDscKc+Icp3lVDYFTVZJcR8Vh58gl2M+PILytkEI/p+uQz5SgCCnCDfIsJ7ckCWea4Ezfq1fjQMHJOcFSRD7M66bka3pNUlQW3HIKBG06LVEhBL+ie+XdlZ+oHK9olcrQZyuLQ2IFf6KbJF32f/Gz18Mn+1f+gfwKfV+lh2tEIIi4dSOfOc5CL4V953qfHtoyDKFM8pPd1mZNMN3YSaqC6Th+Y6ntdl3RlOXMkk3fcFPrwo9cf+2Ld7TQ4CVtLuks9eaO331+cK6rIVqxEdHOVTh6lH6w0sF5Vrrt3szSFItcbNzSwTOXwLWnGzfwS9fBVAMGigzxW2tr/ur6nBSlDTtMmpdayyeWYWAoz2tuPejdMTJr0H45sL2q3gr9gZu2HQ5WpTHk4HC70eR1559zt9PL65KqqlTWti4+bbV5rJluT9aC7oCeFhAnmZ2b5hee2nNrooCj7lx7LstOTHIsn3Nlj4zox6DbFW8aLuP8fOQqfjjbyVDgscnlcGeFJn9I0kUp8Byeh+CoqporjitJsERpwicLHN9Nm0fp71N4U0hVUWv1mrZHtCgOJI2IYtv5nkdejnCY55xGs6NoTE/7FZG26IcrF3ASTIXYCpY+NvBZLsDMHZZsiBwhnGQz55q32iJLo0a7ZZ7AIdjJi3X+j9agV0XAGFSN+OjJk+ml263u0SWraQv1kEcIEybrVTWOQ8R+BFF7z9l7gxopLom7826yU8vXMnN3NT/qixr5y0i1u7HdyxuaVzepUn3g1sE1O7tdIzF42zYR3sBQIZpBbIENYhHKCXWrutBtWtFylK7OD6LhRpZOr5KSPfqByi3Mt41n9q/IDbnCCuI6M45dMctoSutfROvTIIHb38HLRFwgzMhsGUSUw/U06kT5zV0riy1CjLCmh5th/+xmq3vizkk0Hq04usPZvlVPqnr3xn7oc5HvLS/PW47eGuiS5xiU091APGm28xa9R4+1QPZFXBYuTbQix++0Uj0aRUKyfHp19aajbdmuunorTyWBwsVHcmT05zq6Jsum4y3O9wzJ9z1ZZnaLk7FRetgo5+nvVXYr10xdB/KLFBYRVwfL0RbhIYJ64ZFpsYt2KDxLsaEO+eyNybpFhuQDEhVw4AUtRq44V6eGbcBRILZ0HdGF16A/lx6PXFEL1d6Zjr/gma1qvHjbm99M/5vm5GfzwaXBLYLuGk14bnpKq9diJNf4p9h3uFY3o47RajWN4f2j2notWNS13/obSK53ZY9W6e9W7ig2yRGyPplGfyJTOFgnnLjPjKAYbkzYZU39dJk39WZyhP7OVBTX2RvtX9qzldT/J6OVRQJHFNdINpN0sa61FUTp2EVO0OkNb7+mS6h8YefM64+7mSRLkZMmVSNar+9ef+EEHJjdyFLDYNoIiIDI9J2KANnZahI5hEUBHNUtW3RyB25PqW3cvKG6yrG7gpowQPAVLGmyYGF/Wic2J0cRIaicYptzTrqdplup4zNjhyU4QT8EQOM6yHAas3LSLikvl+ksi3bLzci2LscuchYMc1Nr92HF1/KbO2k/1kntwtHhHSd6c6efsXH8GbnfCHU9Xe20L12+3FUTl9eRjvk/2d4JTZxPc2EY15aaDsfFvXW6LBq8yTnm/Gg7rS2kmzeNx7cdy/ttf+3YTePFOy+fS2sZj7g5qucuL/OAHRqJsxBUu5HCcVG+Ukv7oVS4jj06ob9dGZUgTauAIArXuJ+J7edg/d50y0Gcu3rmkPvNpuGKRlJPBLtWrdn+MJLcKHUSS/c6bm2lJterFpdvte92B50qlp/+mshRSV0YHxkvaNn6+no2uKOvxzYvm5Oofbo9fPrQWlheciBxKawGMVKRfoXQlP5+ZbNysfJM5mOKDKIIq6a5RBFhFOc9TdVx1vuQEsexKBGqFxZWgykjXik/u7E+YQkJ6WbHjgwdz6LCsVXecS1OtwTDbxhzyyserGRj7M9FluAbnOnYfLyIjI7zPW9tslUNl7oJR61q25nrmtXAERXOCseNaL7pEKKazmrc3XAMvT0koteupSfzyXlfNQ1qtJ2le7p21VERXGfh4oNbdk1H5CcRK02S7e2NMExdmXSIGuSJ34gMGHtOUB0rGDuJTY5QNezUvJbpSyTspOtIG0rt7MIVLzILIxRxGC5vvbjS4fou7QNhmqJEhb0t/ArXYxuRPTvIw4i5fEtuRIrqG/BwSjROW5t9V0jPtSe37bY7J566efy2TjfvXvsNi25u1pqyE3qj8apta1Jom30aNPRGo6HLqiN7enN0ouV4ja2b1kd3XNPtdvvf/uzL/9e9G/R27EhtbXvbc3Ux9ryFhb6lGbiKjcrdlbfRmxD0RJXKxqGwxzn077fNQqDZ/z8+jYXI7bOgiKVCSuUdxZEQFnmHvs09NgzcP+Abvnw8SN3psR/5xBNGhtdc+RPyKfqPkEOFHKQq9CCHKbOy3nhm+3AW5FOyyvvO/PW5HpvErG42vb4bq/5Sw87qifarZ+un5pONltmqu/RtVl0TPSe/sGBmzY6XH28gF4jHc66O6CkzPnhyeHd+Qy8ZulCmOtZhqfJ28j/pCUSqR75CrOo9YSD7nYcD2Y8eDmT/8Mu+Q7aeIMQlwhPHvyMs5B+WC+lBaWdwD2DDAhglB9nsLMPFY+TWsUwbyfyp+tlf1ZJ6ZjeWfDV2+15zE+m5Gev59fOOz6syfZtXt4jkDpPeDfndw5MfNLI0knR3bhx7Pb9xPPc6zcxcuJA7nqixhdy58iHyGfrPWMbri8x8Yz9WxO5clQ7wWTqZYVawUD2TlrEaDI3PEqRC8tDDKDzOE0Vbb7bPnL4mbTS4ICDOohfKPBc1ggAArNiMjCS0OU6P27471w4IgRXQ3E4WkDQM6rUAf2r1IKQG8NX2yLINGWb4zPnrmzTqBtFKWh8QUs37Vn4MAVm9GXj9Bg6iRU1fr0ah6pAw32ukURjG9UYQRSGucnzlL7gR/YfKvZVvYgp8lWngSj1m1pZZWi6fgkLcvrubhi/cuPhXm2E/7K3eaLpWgcQUHrEbbDKZ0Jt4Qa1XAx7AsyTYp5/63MmR87kY2ZMzNy1oK/NVVVocj62Lr1lfWxZ4vzPuzN/1rPvHR24ZeqK0MVKSrO1qji4hYpGTel1d2W6Kojw6da5BkAkqaS14kJOp1FhdN6xwaUL6el32eStR3KXlRW/r0gLnBRfu+abNwe58SKU4cT2Z0J1jO288P3f5hhNwnUC3k4v3vuj49jc0RZUohhwFCG+rKqwxVVd2rs2XTzaVjNPhETRJ8qw/BYzYHodud26zqhY2+Z/o6+h7YdNQnumyvVWERP1e/5DKFk5sBY61fwgCnT2wUP1ZIo3/1rzCYpQ/JtCh4j+GJXgMgCwPVnwTcSJ9LVMYVarWTY0WoawA9ysA8CI8CU6/8nSAoA9REYeXRKH8BKDPqqRyiFuBg30IkBn7DpAVDUUToPsyPocXP8Rx/9uoWQgs8J5VM9yfPyVqkq4KCmfyvEJZ2kMERcCDl3hFWiNkDR/Gv8sXCUuMqMIjhFEEVZc0UVEUWrFFVTJUURVkAX9kRVcN2GJ7r6Iof5vuNhVPwaO5my4WOP/nqEt/E/HB8QKNOSgi5dOQE7Ul5uqKwKBcJeSgB/aClViAWcDcMRhyGW8iEA/8rLQrkx75hXSgG6RxcpJeaPRv7jsWx0e91cQfBK0zTctx1GaD7/+/jeO6oQmBE+2kZuTIWFtNm19qDCIYsaS/YHf6HL9Bvskbdgc3nxlrkkyILFRtXO5mvWExs6fogiLr6Q0Xr9v7E6qa9sLSQHc1IphmMorNlqbJ5E8hyCjyuq7vIeMUu50llrcOrnyBXoecYgu6VUTiLCDiNqYVoJnV6S+TmQNihokh6fSIEY9OZq2zZ0+ned8lCCkXjg4aN1w8U7Vz22qZoWtL8fFjG5btIfS2VyYbiez5ge4u/FS6sdxGpuu04vTGpz5t0L2EjeIaUi0y10dLMi8YrpIG2qDZvvHmC1mc6bLJW7bJiWaxHT5PN3HC8wwtIPuQP0uqD1BKZ6fQ7TIz3GBWZWp88tAPRD9FhQsRqyCok9HkVaeildBVBJGyBAbqCxUTdUE05LeceM65+bcD0/Vdc3FyNCWksTVeIj/Yura19UBvLsXHBU7mVEQhIsoZ9AgSehOSQIWQcjxPt25/8HPZhRtvyMK6JaaTrHOq+QEiuC0G/Vz5EnkEm/oV8ALSEJsQMcWw1DFkcGzHsv8WsAMjYHoH2if57PVcbEu52G/35qGouO5eWYZiP7HHj5INttORGY/LFYCfGG/TSfFrwvVoPTz4NdPFA/Qm/TydGxzvC3qk6aHmaEgBNcE0UAFYeQd9/4psirIhIiBj2qbqdlDVYk28cNmPPd8G7C8Wu5Gl8KT4QVRekS1bBkwQxMHcdT0en9fYgbGzNV4RRQMHlJd+m57/D+zjAifqhi0YgqZIHI+9/V5mACgvqRpWF/VWXinyaKpKOuQEM6RBfAKifv7Ca17W2WwJmqciW9bZ54o/KE/qpikCAtVgbphkSbHwX8Sz91ReUGTQfrnQsyUIpG2ygeV+rDCKdWLimGWkB0a1qDNBBhvjY2QyYiDleDIqtO9g4ffXnfyLwpaHWStDFk1p6X8S2TPnjvVELdKxPIBVUZtAiceQJENe/hWGDCHbETW7FsMwlio6+8MWXJYMy5EFN/Rj/9IFoTyKQ9+s27hyDapZXDj3E+zzHC9CnijGynB3lAmS/JXMjCkELaAEpXOKxFOxXFlZti+8pnkiny5t6DjSoZUtoMV/oFv0/ZWnwXIU6BJ3leE4QLL3bUdYJrBHAUmwEGbfIZWgxJEyrizUPKBbottpWIOlRe/O5x1xBC4YHJ3vP+0pFyMbUHKzl4uSH8TjtQXTQR0Di6c0evNere1Lhi+EgauouFxVZBqLVX6KluJDlJVR/z47ujX0VEPhCHfjw68+3rv9phMo89vzeXKuDeCgFkR9w+Ltdlg9cuxYurZgVy2UOqNmD0EPKqGaXawfvB1bP0niZUGDLIVCtT6PBfntyncx1YKN4aaeulAVZp5GM1UZjSdQltwij/rEl9GlaYg/LDcu+w9HZ6q6jloAlnC/JrP/EdQnNwm2JE/hFtx6ZAh0CrCxH5PfowdvqQoUjJL9nVugcAI8vm3LuggwigNMROXAHD17a/Yu1YBQyQYqOjLWgb4Odm/wyD+rsJqaqItMHrJOWc0HdhEqKAErvfjt5G8Pf0A0C01j78uKdfF1zVOdzmbOq4Gmeir0Hy6OaJJiqOzYbyJ06aalw+9RFd/VsOjXXvl85fex6MhXj1EsGQx/afgmh1ejTEkKkYiHgqKrLGdv48z08lXJtC1YO4QRQrlNxGIbcpIgu7UYwt+3deT+w6fuBqa6f3Iig3c10cHCcIpYuohyaab2q7x2lmNe+Sy9gJ10N1OcogSyH7uhJCKGJZAyK2QxHGKX6yG6OEomY4TPbYB84xkJ4ZDjw446MGdYB3pSZUZA48Ch0CVJl7aIInJ6bbHdPH/DtbERynroNdKGNxhlBlfaDbG32AeYb8seMyUUlkkyZTzuEm21f74joqgEqgd9K+NaCKiMCuWyOHf+0p3ZsY1lQ1flJNLzflfX9KTOq978zu62P37WmC92I4EaYvOEsgDNwMlMF5XIfLGfPkd9oIWvYKHJ1Er32wdefoVGBVY4lWZvuscKkbItNhqvkBGDB9keGpWLsj7Vh7Aoh0bFtjlGykh4lhxG/v7yWzTjisiYvY6rlwRdVEXNEpnPFxgJQub1d2GtkCpIvGZZVQNJIVDQqaVk5huLbMmWAlKLoWF9mEEmdsOqjWuo4ssoOXmKJQkoKqPCKOKAAo869DtB9UiU2nrMwfFa11nwpIIEx8WDgsE+I6i88Tu/o/AK2AaizKvMf2JLQVNVxL6oqjJ6xsXXHT/HNBMUKN+3FKHY5wrEL1tQgMG3mplTHyccWAaw7YCo2U6VTA3RtMAuUBaM37BajZpS36izU3UKqO9z5Iv03ZUzTCYlVLsfjvTE5VmV41AAMt2H+xFMEX5x0cFr5AswBIoTBygo8jfc5K+v9mUEYdNYAotnuFg77CeUXIrw7H0rMOmwTZqknRc8EQsEk1JsXE7wAviz9onma1/e2WwLqq+iCKkwvyUKiCSQXkD1BXdvUJpCTirKcFf+kb6K/g64PpXuzBoXFcijBYKOS+mXLCqmdr7IMFr8P400j7FC1ejwZRYaE+2WrpA7MNrMBIXlg76SoB4ua5aZaKbBlIX2h6DKyLZl8PFOs7BDdq0TAIkuzI/Ay3DzWAY/RQHaBTVh4HKyIoHyFFUdKaw3psaa58u44Do90aCqzFUr1XpmXHiD7Vqey1mtay4uoLgh64aYXd4hx5/x4NOPOakLi54ZZmJeeOPLb7useYotY9H4vqkAl1Xnr61yGghBdiOfr+ntZsRspKwYCpZz8xs3T73mlNksdOPz9Cyg7ZvLdZy6/xX2FzfVFNQV9z1baaYOV+WRgDKeDfNo+9QQhtW4KHPQ64hk61mayO2t9LLT83FGql1teVKhKFBthXe03GD+RmHbEntJ+0tSGOM4yzS4f6HYjuednq7ykqXN37H0HbWT6d5LFbvBvJxd77rOhdc2T+YLd81HNrg8PEt04eCLrS7Yez90onkS6MG8Exq2CJgWG0Q1tZfs/etLzBoyE1Z9u5H+ViVjPASvKFXQfW8zS6sIg49pW5oiyllheT568sFbj3qWzSnIVLXqxZXmqRNHq425UATOvniM+DqurbW00w0bnsYSbN9JTrc3Up3+16q4dtOwd/nmS+2o5y1MkOc5rWp28bbb57qXLxzbu3flRaPmWuJqvdVRnGxtDf0skvWjYZFIPUJznO4OK6RN2X7lYx6R8KxmWWRTh0gfIAdeJTMmIYlhVICF8167zK+CDWDF5KO9Ds+vD+curASpx3s8p3ha0zA9kZdoUe+DcgYBbZyvmrEGyoHqKLKHQMNcIkFvNRaRN4gIMcDAirdHXfqy/O7V5Rt8x2T1efJBb05DVA+sQYkcOoAmwoUgiBXkaYxcBDwIQYAK/Fzcic3Cjze2Wm7HIaLbZvK68i/0GfR/gI/x9AJYKXd+GZmuHHBJuSlzDMK0ysgWn90o/G1vRvhjSNx0PXYPijoQML2Dna0qqTLsqq5oat0ZhM2TkG7WY9J1u1uDe161mA9QLHetGi8Ze9+V3dI1Y84CoYorUAzgFyqySg1GAOVREZH+uXGQ+hrz5f4ZcDFMDY4JOi8qsR0CeLHbtcaNt98517vjpuN6o78+98CLvnm4akaCZD29D4cT8haoebbGs5IdYpoSYWmdu/5ss1dLtMFwUqjKNNleQpp6a+W+wgmbZc7YL5NthjfBVEp5wEAP8WpYqleozXSTI/s5cADlJxtTykvIQVdYUYUpjxjQRcLOCTCZJdu6o0Gqz0P4EXR9jwnV1IMMlkgsICdmGbHK1Xjp9sX0mjoMnJZ3hptUok9V4CsBSXFfdFs1l/A7a+lp0D8XVQXOkgV1yEERwfrah4uI+G0yIHtb0iIEfWCnFhkR4uJNhCaaBiigSD0VoHOa2rxzeXJnCJm+w+ZhanTwo55ihKmzvkbp4Jbtosj5zwAofge8N7arfHFWjC1po+vTqwardlTYhBnUO7MXpZ9hhfpsWmKiy0AUePuub/vuYXPZBpLm2mo1RlF9ELVObrTNah7Ea+ur0fKqkrWad0yQ4ayh+GkKnp0msVq7lIe9Gqg4TjWzlu5cWNwluZl3cmPz+rZad0dNDRgnwhfLCHJN45OlNG4EjPGEUMK7cOcdzRQUANEMLbXVbesqZ/myb/KcGeehHZrggYiOs1240UfoU2BPbiui2Ksza5EZBpMR0KIioWbvBvt5EQvDnfkZnxtPdg7Bk4A/9slb9BJTeuylMggdurmznwjznGCGNUcBIZOFrQs9KIYcgM/GGbwj665sK/mxfPuhLSPWFZu+CYkwpKuymBPSbJx5+otvOq9iHwgMSkOhV1QVGBhJwZ5V1DJBYrEqLL8u6DKnUH6aMvECpxSXf4XeBFzq2kLsh8hlRTW3t8NIwYWtmEYJZMZhmZlWOuoX/KYi1DwHdwUP5Gn28sbRbPyMuazjC4wGICvNvInzZOdD9dCf1KpD8NYoL+IlRc6SIJEV+urV7/iuh/Jgya0NUpvAMKcnzl4YeFtHt32j0Uh1A2izbKutyxdP2Dt3N1PUBxqZVtd7993/rIFrGT7xUEljLv1f6YtBCrp2CrVxZdmEn7Hqyoj6KhdeI4cJgtMLgui+WQCq1mxmqho2Bmm62mvEvtxYTyRXcFMk6shHENTCDrEcAvDwa75fYkGgwCPg5ZA5GUDkRM+jPxSteP277rqlnpw4NtJ1Ix9vjr1Trz/tb22tKIwswzO/ooLRwx7O3n3kjY6gSSzdggUVmdjg1uNCYp+hX0Da9e1THr1FDkDz6Zbl+sUll9aOzujfG/uwWtggBxfPRTOyVPFvbpZaHBAvCjcR0s/yjEdAzNzUsUthvL24ZscRAixwLxTXNjjZq/USX0ZW4A9kCxcjKSJTcpgbRG66oQgsv4ZWKonG67ouGjUbJdS65ySq4jg2uLiKzBt15P2ETpdR5k3V0G1DpT/mBUik+d1XHl1/eB2cByvSOM3ZqUqrW2Mj3JwsqP5qGzWREAHh9f+pcU3utPrrLYBAFgIhCi8kg+KA3FYYPXPJHW+NYFWW434iS9JyHK6tzFsafKg9eXDMFl5kay/gewjJVLXQqUeQ7X6g8jDzKOKjaxkrjypd9KeF1jJRWzko0x343ln1YuZ/D6V0G9PqxsxxWZR9jJ4ELZiLTFe31CLRYWDYy76HMG8I0JApmmE1dJGCpg6FNGLzaa/UWekBHpkBApzKwz/YkJRvwwyR6qCK7YdHtBBTZFOgCHk2atKgZ0PVBBEgEae/6mkTxX2qn4H7DosBKKGIUsFLede7kD3yLO0TmF4Aa9Jr9USHW3Zy/3vf56CeAYPDcAOgViikIMTXDQ/S4FtH2yzcVYX20RZSa81DAwuEANAEeTpYtah7OO/73vOo4JIi2DkJnOQZ5U4ubbPFOWKJQAX7iMh0dUdjZ4VOMfVeiWZGs63++Etd1kjoCYYzwmUiuDC+M6IzYheIRHXksCIrHNHwpSjWgLrGHDFiXs10NSQcjgTDzsXzEcViSDSax2IashHajgfQkpfpGwRVNDUTCbjgvCPd+wKeFqYafwALQcMQkYtF/E+c9q+4iq5BkAieDAUpLQ4q2YrqaHzzSJul8hpt7zR5xVNd5OVUhfgKM44gfov+GpoNKlNzsM2F6yUG3yCrB8rE1i9vgXHVa0/dVh/Aw8ao9yiK9DF60Gkz828FPAw4fmPIeGuMjDelwVPbzMxjL9m1bNTQ1gbJMGHqCBDTRHGTl1kwogh7/x4JLxSRZ0ZNLxJfrAFTXuxzRLx09LRwIXLqdn5055q+2WU+UFGtwAeXS0gfug1AfDQMgBLoxPDpWjDn3/kLTyn8CQ6h+FVJYzjVPsqMNVZZ3w3eRxLOMQ4JdJXDxjj7vemxdtJn6SBBaKSh7oS0Up5iiVRHbUTLmhlW9dVXfg29NwJC7QrzfweEX1Y/48Qjh1/MWSpR1t3InU6nYOiy4GEJODeOO7cwZe02GjE5Hc/VLLe5WGUMzhmtV3VjY888ffCCGM9vNWnaGHb8q4muAqO0IPQcTq0KV5CshH1vRr7168l0ZWDlr5F7y2XwGN3LYViCNE/2Ca+ME9fnEBgukMOvDv+uuthEejAXnyZxoyFjnczcWZhjSJljLRHTD4vXOg4n+J1h45FPNbfmY8hKFkLVB+xxmnzWiF314AWcTEz+lvwkvVIkq0UBDYQ65twew/AvG2Ty+X3LO6WSkh/g4btCWXNU2UCxCMmbN+dboMjXdCtSq6Oqq3VMUK8dVQXh33UsoEvMqeuiAy0lMHoAdGWtplYXIjdGSCfINbN3c6/WUjX0vGSAl/1QgGGjIs53+8obyd9UJLQ0VrqHSON5gfzNCCZvPETp/itwuKOCws0fIn2zJALrXtDBi6Sdp1Xy7kp7yl7LDrUUsVB8yj5kzjyaEnDCXUbAp+J/yE5cs5MkdZF3Aw8NbolVCx0pmvSa262FjRSp6eauaeNXq6tJthRRW+8vLpA3WSh0VpPdXrK4uBhHC+DFo5aWtWD8FW3j7OXB5NQ9Zm9+3jbR5dbZOJZ4LrFwooMrj5BfggHvs1KtxwRDAaSJjP/JKgEFC6nkZk36LNz0JtMiNXKKQMJ6zdNBz3Vw1VXQUjcurmHbtndvm+wer7H9+qsbgaZTVFnrWTsEi8yjD3cWVcGvNaxXAS40SHPr4srmpVGVti/feOH1N6hhvb/ncDVrfr5v6BqW9eGbsbSsLgR67k+R94NsN0UVCqbSjCJWMLbZ+RJROsAYZjl2SH5MJrLS8hXT8iwrN8NE1rBurtMG+AMiI3JVfdGPjyR6oi8eafA6YJHNdn4BtuC7zKbpIuBRWekSZIOl4chFJxocsOBQr5ZpVg1xMlgKvH3k3OVBf5IHSCI8o0AC/pn8PH0XkJtlRm/Kipo+mkyZerWLACQajln4zoXs/AFtLhcVLXKXhzo1jJ/T3hg88BKe1jduHG2I7o8FG5qPCCzfqls2Vek7BcnP3PXNYO+/T65bCpVnPW/10laD/KLdqPmP/K+0QInpO0Qu1LuDOZxPjiX8MBoD1isnoOwF56Xkbx/qoCr1lBZBudjG6wVBccL8S+GcuCOQPnmpXg1M3Q3V9Pq5yT3A8lRt3F16/rA9AR2ULZNb79fi+cWVlHOyntveVb0A5fvUpyqYFe8l8is5KnsIBV2DN+Cf+kuLD6xunw0TGlnDjpKkdc31i5ow2gxTTyXU+kDIuuCkiCmT6ZUlV/IgfX3lfKkQOLu2hMIXq2T7+zlgcWFHUc0aLx80vaxPhkUYvd8+WVB+ofIwzWfAexTrdgsmjwHuali1QPMtg41oTUM6JApGYNMIKQFI8+m5zEQrpO4rnu+gGYWSqE/eItSshsSTv4yriiogdWAAMVqF1QJF5LZHzx+hCiXiGzxrtWuf2lpASKELmetm+K3IaADnSlXK+nK7V2rk/eS/QGbnWUGUXdsBm4tRzsmUPEE29htysXPLUuk664XrlYjAPtOCkPez6pqumau95mYzWJ1vgmRf7zn68mjNRNfa8Lm3jXmuu5DfPohX5pqywb1b9RD+w1WjrcrsdFoawxR1c/XXmueaWZYcTdprYCijZSDJwxrYflU35J3A2qwF2sbTjgzvBPFdr9fmb/pOwKd+NbONZhpyqDloitGbn7N9txDnHvlZ+t8ZfxklgKLsSyfFJZrUIlMK8wwzPMDHCtod8BBIj5Uvi7YO8jMsdtGrrOTC5KYlSSu3WZM2CIBZWoB4iJQR5umiZYqokTA9m39qp9t3ud/yF9zaEugvXG9t3Qy3hh1Y9loPhH233wz7KT3GagYaEyULZlArgSILnu8JQvNE2zGJ661unyj7Tyo/i5CvCZojSJ5hfb97FFRApO77WTvXZ66mECSE9Oby3INGYT8p0PgkrYksou81BuiMrneYxwvJt9Wvvf5sw8ozj9D1pWhn90hszsFoygrQqLCW/rqcpkHToYbezKo4nfaV7ybfSt+Jxv1dbJjDvzGqc0FRCtw3A6VGoVdqh5udKFvWc9m8wFm18gQ8IljNevN8JxyYLtKS3LGzLAPZEntAko0B+pwAp51UGjgLG2fRyJJf10/ccJ2XnTqx5QUgJvm2N45QRpFtEAeV9mBgh41aGuir42XQ/zQpiKuFXvwreTkc1IPg3BYx1EGL/jRwQI+gX6YawD4OSrCzfGOHXK0xZes0U5eSsoP3pvl00Q4kfDoMFF4NQzdCR3NU1aN5Q2HJrmTLrPI2rSWCvFCHZeCKKjfyMb7gNxgiGNhlqCrbaFLXjPmoumKbkRuGYK4EfxEFKlWDyF2pgfemK86SXhwC6V6fqRSYFUpZU4eh1MACYmwLZjNAXNALrRML6oWsmJ6rDpCr7eT5MdQZTJnDL1sCa6FeW/EjUDSVoESPoIPvrkyweFgcCVDzVejYbDdNHr00Eitrs6LS/4NIHdCGYMQ1xFsskyzKIpysw6gBXMb2Kavbl3DmAawjs3Wgj6DXCSXLVQaXsMqhgs/AdviOOqciU8rbxxq/j1BfLahie6jCfAqszmLj1/chchiu3kbRIG2y5k/QE4BSH1SAiohkimqy9g6WQLWnBbaieSNiDSzs8qJZhwe9FoJUVT1LPFa0EXUlDGxuynoBMbiGboyyBI9G24EJmg/RhEaeCcwZyFJmuxAf0RrpuUW/Ea8vdZF0/3Vzq6lj4ANiYOQTy8vRfM9bQ5czGsKMmo43wd3FmxwaYqJ+GK1FaLb1EN5LUpikxjXPSC3bdrTB+jB4DZoWUYfxai2r2hLMkW8oxG3HzQslCYT8FvlrNKyDcNwr92NUlgFZUAmPsV8NKleNpRx1gppJfeYqsGIDoshd18UEBaJmzVTuXY+eU5hINqzCsAKAPQX8TcnafHMVtk3uJZohMcIkuS8agXEvcHYASmVoiq3M7c8vhMePGe0W0iSApCbaQVPdW/ZX1nh+oW2EYWK3zkYxVAQ7WWtttVgIAl6gSj5ZiUG0O4iLw/2g7fEC4v/Suu7MyXrUlp04NQdRdm1r5ykbjmUfvc6yeU1XR/XmapU6+sLKMnmvbcpZLbqmsfH81TDX0DLKTS4/d3Pn+n9nzi8tuZaPWGP7VB2ov1XUIWy0bv4VDDSziWjuKk+E1R0O4UQlA8IZzSqLXFSQp9s5VC5A6e14upp7ZG1j/o5V4DIMc4kTm8U5pWYJymYeD1d6Jh/01mLOgBWJhosN8pv60vbJ9vDO2HG4Xwa+AOQHP3WJoClPNZgdWALMoMOZYr9r+h/V+1VUm4AynCSymxXhpUneh7MfM63YONQMg/S/wcybM0XLH81Jwf5g9OieV1YDsFnmyWu3UGnoN83U0fsrozifMGSQwF/Lil0LEb6QIpEnnORv+N0XxKu9AODu0jDGyZmnqk+fLN/eNANJQIss8aoxasqPfBjXoILBgT54QwE7BWYDrtOomT8Me4I8qc1pUR9VRXSTrD5zubAEnyXvIV8sprJMUW22h4PiihjbcsqeZVcUzGrl8FIDBONyG8QtMM0azYQCOLPbiaKYbV/LtPbIC21i5S23XtjqZ+qNVgMtZsSMUtv2ddhbWQzqLbdKBGpStMc74Wtq2yspJS3bml9e8ade6D+TP2e9xd0SrN3lpn2BjP7ZM0lYFlaKysQ01oQbXcc1kMhbWVv2BqidLG9sJ06vBX8uWJFhJUnNijINvSzLSwtOy4qPzKUnrzmCvew0fXtxcWCF9OcwZcAyG09ZjhsOqhGaW/ONGOgBmN0qcZNMU3XdNmvXXQuJmVlkDxog/Qa6YnYLUOIL5GP0tSzeL4H2HOldaWILLsKEkSnKdsbpevcYteWge8APCkI9+bBsOEqWt3VmHcHIaQzRTsh0wtK73SasvAKk4kTK1F3XrEYNZVmeqNZcv0ne4S0D/uRpdmxnI7T6nRoPtpuRd3Nj/rkT7A7FyGoBY4MhyMTBWlAVPTL1VqdjUd4qLuKzhe1bZwSAGWUJcWFZ+ZgUDYuMAcimaYym0x9AlXkP5Z28WT9+fCeOMwSvPCNuZsOSZRWsrUUW2LRCswNePqz737dO7q5bcMqOZa1u7iSnTxqtZk2y64vRZtS+uNswpc2NeHtrzXBdYrv22taRQi3+hfw1+WOWO5Nw1gqL3SYWBpeb9RgccDemE2/+nOexxZPlhmi5gQ5PqeqBC/ZMENU9ASEBWM9ZpijgbYiA81XbQqdW1VXqWZW8Xc8aqTZ+1o7eaiSiiG40MWm09Ghu5eiinmQN23IxkQIlu5aenkqjRtapJ+ueKolesZSfoQ+TP6pcPny+U/n3p0113EFewc3gWK50oNyMf0JD+jxFQFXYSdDLaQWWU3V03kBy6pq8jidxXnWBrwWYCeI1umC9qQhuLIxn0BCmOGgRSzCdRZURIkkyeEUAa9Ghm9TIbxobx476y5dWzXpoxp05a/Fsmp5asBZ6CIe7o82gduL06dRrGhgXkOUdp7cQRQs9vVGvipbVWfH8NEajYhinvtHOm5pmcWpRO/08+QT5BGuO6Wbc1B+O2uP9Wtq0FjDFDOhB0X2/kWbWAEzIQ1o/B+SzGDuLgybwU1NWq2nD8ruC6GYodWJeSzNVYx8WzwdFJlkOYQwFS/YHVSPFsBtgw5EatS3F+w0TLstJZF2eW+wz8j02AJROlAM3WF6Ys8xAtbqZVsuajuVJouJtVsHpkm0tHoE3J7mG3cxqWnXOVaNCF5vkXyHbO4q6E8ugDipPh2pQpSuYVY42psWnIoPcrzkdqi1NQQGGoXwOhhxjKFDWMBPbTk2EvKtGZCI2kmpWzdclvuRHcPQs45GlWRNNE4gF5QT0GgcZ8pw/kg0JhSdE04rEWGGGqJoW+XXTjhwBm4oXGtut5tEURfpno7sR/kOPCAVPS2GEa0Zm+4+Mknv69IlMjaJYtwyiq+5iNHf7/Dfamel0LMDtOA+BRaRgrhWr8gX4lE9WtiF6Fg+GJdGAtTXP5vUcIzOstPSe24QFw9MeYpCatq1unoqW5rir/uCpAxPKpqBWZvbNl9yHmgqa7WSESqKHIAdN8Eum22lGCOktX/3Rh2EO1WSgIZJjgZUA+KnvVFednwShRFaiOGLEgSLNCyIrrdX038Ypn5mi2pceB9VGUF4oYgEmIp5/LMQNsGOZrpAeS2q4cf/x8W4GYYAxDy/hG8Ljgd8EaW3L4tUc4AchjweFXxclcT12fNsx/DBsZU95NDJ+ix36ob0AIH8FFDHXuGcKlH/Llb+r7NF/YWPNomlBtD0uAqyDlhg23wAB/z9Irh8gPxSJDiftWlYPjT60KFIjmyhIw3grtelL9djVQDNHfWPB3ENPZyPEbzqOhfzJciELXBxoWVGow27gioV8DEgOZmfRIM2g2WIhHwWY/yUDzAlbnFzlrRZbnMeDz9Gii4YNZBR2gOV9XCz9HvgRz1qJ+slCsU63PBpaf0rWCkPfcGzfwTon0XWPQdqXyDw9R3mGMM/G5eTtGZiel1yw3sbVJNThfvsKynbYm4HeWpxvWHUD9IVqrdlSTBMskEiWB8HCWi8xq7pWNapdnzFuDTuNyU+hZuRkZhd1YVS9ZAe9FQbguTxK5uwG+o1lZImgn2LXG5qPdiCc58upVvk03avUIAYobdl6XgYfDJ19vwR8DWkpujPCWl2RWNzJiDqKQf9Z8MJYUfNermJAGLxad76vqbXYg83BgW+lTuWdHC0OvMwY65Oy85JtCX9m258pFqMSWPkwThMJhE1w9zBXTDFpVfQj7N68j8NjYJKKo6u4eButOgiv7St/wPUxJeyGynfj+OGsWrxPxWQ/Z0Q8hNuly5+x8so+rf2xbrt0PSrwFengW7PIYH9s2GRGDsDPT7oeirPV1bbouSYHDfFNlNqq/XYn9Guqajeu9XQi9KXOfHVjtGzbhr1916aKgiYFFAkoQE7bHUsHjuTYg/m5F0pBtHRhSWzkbXC+WPXYtt+kOUBtvPml9boWo6vYSI82gQlmF3u6CV652U/IZwGA6urcvRNVQpm9urS4ENpgw4k8IqY46zjNTVf33XeiiVNptBvIeNTuMR9QgaeM79uEZdDTdi+ws8hibmFZx1/oQGvmHVhBx9E7N219E5BztOs0201j/e6FpG6ka6luMVYBrDc6l29bL0ag/BkXQg5Pn3XSHQxuETNuymzi9itIfK+U034gQ7OyDZSbDdcDDlBF6Rsj0+TAtzm5ZkRrCw2ex3w7XbA07DpAekCSw36dkWIlpb+y1g95PtCY7/OSVJc9Dx13taWtjQXF9lhboOMi3UeLuSj7iqSSz1M2vEgmKNjJfkP12g3ssLXto6MuoATdZAMOsY3Q4yhpOi9E1VCwqtlO6i8HQTut2SrMnu6FWhGqOlFd9wf93NKFMHeSceIlWJXTFRkskw8VlYVp9DIpJz1Mg7rpsvSYUcV1kx9HN3ggubv5/PHF0M16fvP8ArZXpEgA1IXV267fcnXSPr05t9lPFOyQTretpm1CWptn+/1Tx3cbw8uL4FXaRDENvnv5Gd+wM7jvjp2ouxRgr5hXPs5dx6ESWXkl/GyJupWpGnug67GoAxZ59D7B4shBvFHkqiVAWs5p6o3Zm+uHeH04RDsAUBkWmR8+tcqgDmeaJh4AwQA9cDSSsy4DhsdJhrQCLgoq/tByZEwKCBCeFCyHP2NAjhaD1opKt2IbjmNgWAR5CyqEAIb9qsDafOxlm3HGeVAlfRqnFsppslTTQssUyu6WV4NiSnbtpiO4BTZGp/0ukprZnoftwgaiMNIg2j/qDjjve79CUjRfqqFvM5fa7JPnl4QvlFQ6oMizWoOA8S0tY7RuGo2spmCGYNIb2PQm4kRVAEdIBx1expREWQ3mGcwsXfk77jJmuSxVnl15PQt0gIbXaVhiP+Xkj/7OrLVUxGAehl8wKXjb+5PLQulgxAudFIMJ0SQ9T8Vy1AvddxxDYVSnQTkclGFy+FI+hV2Z++HWnN7kwOXQ75/v4+rSSEB525LL9o+k17TI3o8QAxN6MEyzjsEjiJprSsGIQ5s06j8ocxXsONV02RBKWV1oXts1DVZNceCSMAWR3sqHcQgUmaLFbDWNMB8UrcAeWgzRhoYnaoYyOuPVfL4TbXGOi5GToRYkOIDtRxrvBx4LJHjFVPvgJRJyBdQ43ejbC7cumIzMZoKJaVp5r+dUJ3CDrElAoG6cgG7MmnHoOZLAyRaSszQtVUGku4jpZ+hllETXMcgu39GR1/oIZtUQQhKv/Dl3CYXxPhpyfoBNw0KjTW86eQwWzZ/NoBm2VlmcyiRHvhbxkKuFUbJlpxmNdJXc8k8M1qFtkE0C+E8ugW2uhuFIqINBNlRgstn7v78W4dwMCWAwomMZTBycqDacVC77nviwGvIwvJSJrZZHrwmjUiwBxJK26gwowjRQtReYImd9lVLZ+/hTIAQDvCYRjDdyTsghBFRRCilo99IDcYmQiX7lI9wFbJwTlRdjnhlja5cL35qxEqbD4bZpuE2G4+nLvbIdEYkCKDxsr/klaye4ajsVkOxMXswcIkCf5x5HXH4Zto2v2jdXS0qiP2dVBa2rV7W9FX8BO7sAqRVz3CFSsnHPj3zjnq9iViqGw6D1ygZz01LsY89/60uGE4BDib7X/a+lEFWFsdj3pcgKGkyIijIVomGWQkx0JsTrs4ajgRF+aDORqzbdMrZwh1lCUo/cHvgGmiOQBYDsqJzIiliS4/MLZgJfuELfU8rSWjy/YDSaV8lyEbIECF1KUpcKSX76xqQv6blMFg52ktJWb7xqy1X4K49c+RR3DkLsgoX2msovsa1V4pzjaeln2DqYb1LGa3m3137ybV85omK4vtFCQLpeHIH1akqtIv2EggBvvoW1HsNVcaZVr5OPeHOuz5pzwLdiJZZIe+SfjOzTT6Z1fOSPsd0UhsdumQZ8pMq6vaSquvc34XwIzi9OxqVyA6M9HKTkNgaOsCpw13eWlpcw4YJn3pEzn0zb+cjPCMq06gZmqoIJp3LpY1nzG/IfDhrwR4UGnEGT7C+wUhd3MJusDPvCaH+gTUlw8Kf1zp44HcvU23/25CvGn2hRLXMCSQ8lt+3LXphYVuw5UqflNFx7oVE8iRcikfUGtJ32emR5BmZzFV+zxdp8YLmm4t/7ZOoFWgldcEzrzUxLj9S1BNNF2MQ+dXMDA12itWJ8n5qf7SgoX6mOpPnHM496euxYKaA9UfG3Eva8Tt/7pPpVtv0/UQjfQ6b27ZUfhPhHZcw7G9VHnnR5MmpdMbMDTryAj86N7/zW06e/9c7x7G9ktE+irF7U2TqT56c32u2N03l+Zqvz8NIOYOPWznB9B0M6Wjv0Z57UDfoeB2QdTvUdYF68HBxyrLfCIv9yEZGyRUfkOR25Nx6VyMQRuFCGYW2UeNt0biSrXqIKPSl4rCEmv4X7VB3mmot+KbjeJ9PdBl3MRKo39b2bg34cBnzR5cdrtSVM2+XfN3rOWO90GhKUvz6q770e9Xdk3Y6EsWkYykdira5qPGjSWjIO9l6Gwj4VGPNavvdJ8cKLfgKrwMxj7oLb63U9p21mRVMrwPaclnCoDHipAM60OXDnWWtjs0hUfuvJ8MoUG/PvOQstLCOMuy8Y+WJeoJP5wTDeEvNjImCcw5IKVz4LCDpkd0ghR5L3pgPSSowuHD5O3ljMj+NMTNx2DCfQuGuQf2HkiCc7IlU9JzLRgnSNFAQhSIX8I18gbKLm4imMAsb4+U74AyBZlOmgWjC9uH4OhFO4s7ZpqXG7a/7jl6I10E1lZzWil8y06vOCrXUWVsIf/IjZTkNMote7c/P2nmglnfVL/+5GDDB2QYvopGmjoGvwRfYXO7XN+t67SH0Oo3cWMQysSJw/hmIPVzmLfVIpBlj0WC96r3/VvGlsEWwYFs6U0TxWgfm04upnXf3l6u6gC7YvfD0ScPpioc3m5EG8BmsSB7EHfS7A4T3lCGM/ooDl0CAB85NjJF2uoKdENdYsvveWrz37vo5NZ0EDNcglehO8e57NB7hO97V4JcZseuB0VrVpJ5u1vbPtMygDsRkstNaftzvu0sqS92P/5mwcxsu48jH6NygczaM98YcYLTgD7h4epNIl64QNCm31V6ep9NBbDw8Zo3C/2wcw8tQW5VNTVEgUBg9JRUFzGU2r9vsCL/sZnbwEOtplaDKmr85yX/wy+VqRTFukSNjeq9QPjAyG/sPK1NDnVNgYRU1qsdI60ikcDetvQEtIb3R03CdquoxwCoNoi/ys4DRJcuo0WRjPcEATIybRNcCTvwPdMdZfEIYHyXTEvlFIEg2pvRAZAe4sALOi9+3Fb1g8MCv+MLk/z7AFIQVmVDQAZvja3qcph3oeynVsKAi5FYk6LCr4Q4Kv5/zefyO6g2oiWlXwxn0QUIRU2j4koP2EucWSalYFHu/n1cCMyrSae9IF9In9nPmRfxqAJUs7kYCMDMX6QkrrZPFJlsyds7S5Gn2f6AauWEgIbWAsr66xvJq+eV8uz7haLnc9nlz+6gnl8orDcvkRyMW88mf0nyGXc5WXsTyMDfsGyH3Yf2OJmZDaM972MGQhwMZsbEN51xKMn2ojSZqVMiZ98mSL7jzaOVF/9jnyu0HPd0CpxJz3geGQvTeLvu8U3UWoHwiYS/Lrnv3a6pyjmejbtruhUG3Necsbex/CQGVTsMs6n/wky/kNwSpuzQJ5ok/CdWLWtom+KNd3KC1mWWCMm6pXfV8k0451oWuG6yF9yb7wb7la+Ld+9cJ/zKYM4cp0TqucxG05fu4xWAqrSM78d2vMQrz9zo8STWGRINOUfyOa4s+67Zl2tKd3NGCMbzym/JCSM1IEfWAE/YEdF8CKurfjL4a1ACsIXKUTNtBURt6ydxHNUDGgFcUSGAm3xFZkhw0K/OXhBNOtE2Nv/WVfS1h3N7Ir1fQsw7SdXEu7uPEDmAKynhhgHzIWUor5dFCmdVj2Luu4JM3oWq2hoTNwUMR2subrByDL+QJkGdDfmIVztz4mnJs8Tjj3n6Zomdw2H4C+1QBV4HDX4w4hnogKHJAzTKnuaZNsPBxV+Ip15c/pF7HDtyvfABDz/WWF+qvemsJXsTUhRNbSXMxEDqNtMlmfMNBtt+B/AkyZpxhXh3Z5kK7apX8uo6DxvqgD9MG1xlOx+8Xgo2ICKLnlSd6me29SUGYnQmDUT2Rca2VjpYVuch0xi4SWhvXrLp9ZI3crx2595q27sr/oQA4sG5RQVc15VGDIvyfg185rbBAzyt1yLcvoJ7+aHfwXV23gE4/awP/jqg28923sbgDogJyyYVHAxTg3dpQfKPosDQWRMrlkpZhhb1aLTMLwO8AEOm4VPYKqUtWX7142PfAx+cIT/AXnQU+OVh6o/ORVWpIR/1F60vv62HBun0sqHvT9So/qvT583yb2aXJ5pgPlZe8rARuv8fXRgkb3ulxvcpyhOU23e6rtNEHgwZwMVasqydFUq+PeNKjAAaju3d5HsCzauAeX6Wv0b2eyDjHROrxa2rZpPdZg/+sTGuwfOyzv7977WDKqq4FjZoqJWtJ8pFVRqoT+ybIvh0tskhPuXdB00PmdHqsbnikYjHrhy0Vq99dcjeNRkUWPe/f/MFMrE7yD9v31Is9zyvLebOOCy3+QzgnFLMTDRb5CiZA/Mh9B+CdM4p7JaPUYXYQXWw7PCOtCHLJhYppInrmf4YH5afix5bEJAZIWg/kpKsXg2fu/ciZ39neNmoF8Bpk+JRnuGOXQvcXnVFHuBsdLrGV1+YvkRQfJ3iVDATbv4ZZ09AaMxojRDVQ0EQrnf/jMZ5JV2NbmlU9iWQ3c6+PuyvdXfnE6GaWo1j1BpegQulVsrav8ZPF3e0ZimfnJaYWIrTKDssb7tw5hj/EBLAIaTjSdmVH6S6csL+fTe52Nd/gJF04DXj/z1S9XTLofgfEe7mB1aKfBS1brtcJLlltNvca2oKAHPpKifI52bihwWUMKnT5mWrEdB4lCEBq4jpjhwOGWUqjThk5NLZgjmiqBMeSgCR4TbNdYMKx7kfa9rMYEn2mhxiTUG7MaE3371FuGGJ0YPMpf6p1eR2ceE2Hzvsvc+1lWX8J2FYsC01sIiIgpthwb2/H8otjEe2WtCeVG1WFz2/hQbwl7Ly62H1pGgQvVTzbI4OiZ3XlIXQd2nUDqZxE2/XTlg18Teg1wst37cgj240RO/waFGH4lhfhasW1nIeEQVR2g2+2ZvkyDqpm6lEHV9V9BW3RnbqYtNfP/UFu+Zsg7mYPNOAR5v/srxWBXadSfXqVRL9zXKGyMqzXqaoV666MUqj08MswLSOmPod08+gVfB8dbAGxHWG+DM+2sKYXFennHU0Rov0OKA6V6pWy9ueo18nUBlL6jIHt7FPfEQ5ME+tpgcFl3yR1RVSims2A8hlzPUpnc5mUAaooXQO1uGHtv+poBJfoKTKapKQapgUHxyM8SJ45lUGhNjPSZX1sxwSfESFwVt2UDu7RAMKytFvInzM9jr9rCtAm1Nd6zvh7QUoTdvoG46Awy5N/7t1eqvtawanYDo6nYAJoUJPCC+Y/JwuNJb3oSjPgLMuaqP1OdYu7QI1+f+tUtXyb2KosiTxB7oTeQ3Xy3kAJu/hrpWITiJdmIcHtd4OJMLHKoVl029Rn0csmXWTiGeZr061bYett+fAYffXV8dtqJHic+ewub/oQ7Opo8K5NTTW2wF4y06rB5gnEcYHYJ4cA+Qw6496dJs4GMU8MEEtdzhSKm/iSHphtEB99Z0KwOB16FmMu77BZTWffvSFhgxzuHRwUVYRdr8Dscd7X7hwIvUkZY5Uy2qwKwjArtfnnMafwVtpstL8/j3nL0MsRacVTGX6wrSDw/jcEUpcXqxKSMwawiBns6G5nAorBQBWsUEZfKhiAblstu5MtCMT9U6N5LJDao9Pz9Vq03uumhMhrrpGGVtU0rZSRmD21y334kxk0Dsf71rcOR2ItwQmGzW0ZidPH6Hz3zpWQ1wKRJYO9FSHbrNCSrz81/mLyCfA/sqF/JuZj+GUpYuD+sV0IJM5+4XUAK2Elssdf3J3SyMZxFAamMast7qUxYHyPaxTCujN02q7gfFWwnK2+V9wwpudu4W1q+P3ICI1yQ5obD/mhGOg2iYqDLDzsLOrv5cYr43Kv6CsJ1URHmxjvjPtpxbXYfRQfNYlIZfomq1nR8j92vA+0vJoZABqhF3e+nvt9ggwTIlziRc9KC+h2HDnnkQ3g7WHXQiwKSiRB02p2Iwfua0WnHdPNZI7dNb1NcjEzAkvHFjb72ESYxqmEmR2J6697g4sBuwLQKAMe69vxctBE6DdYtVPAZ965lzZa6GWhVqegh4kwP0L7ImrA/ggtywarWqu6nGK8A8ZF/5cP0H+in0eX2UOU/V36juHXo4VwfWO9XzvSXubLFFdABG/1WyC2bJRQHtJAyiiksJ2PJYQcIh0eCCIdGgkxA/gGgNJna6AB2lXCPhiXWDrALeo2ye/kZNx993ET/+x6T6O/NOc0YYxob0RC9EzLI1sL81jXbA8Fu2DHGBTHFZeN5VN9eZnOGGGNEipJE2ftfIqYqU+fQwJJH/vf+xJI4b3Wqo6zGGrUIWqO27z3AI1avven0SglYuMb8oaT/+nSF7qf8VVjL5CDlv22a8tPvJ4qdeE3b4KfD3CWp4ReJq9+URWpqXdzcEw2kilRozO9+mdEphNyehRwH+5TUawrZ++FDQMQUoMC8fQ5a8aFCK47gLsBvYPTvJxJwKD5GvO1Hi5fLhfYTS1dg27BBDqEMRahU8swfhS688CtJD8W0r152zatkd2TvQ16O0fLP7B7L9RTld4Yv/I6OEZyYy7zIblp1CFk42XcW6H2PJ6Olc0sHEvJDD+PbuQMBJRglDmXFXPZ4JqA7ZgJKIaC3G5iHyx9LFutq5Jh1hiU8LIG3jG6BLK1K+ygCJoUs1Y0I+9lBce1z9DOVhcqd8GI/OwWKg4OxFnn7YNbn6BBeEBZEi0J8hRVlw2FnaQrEuB7u4wPl/UYO3Qw9Z7yB6ZDvgg15hExvpU7FoKxOcLObcbNHXjI9ZjcfHrKB+NvsC/TesGNUq0YnDMdZegy991k6DsPcrFbNHK+lGXstzcas3YCvZnVp/MLnXLTiOcSunhYb17zkmuE9w+ouOm8hdiXwwXmnP4r5grzIsWHUwtLlhb0XRpERqbiVrmY1T7Sei7bcBHf0wlgh3PRY0X5eBltECS2r6bwKjRh1y3XZcNvMcdruaadpWeHHZc9K1lZS05MlFg/DuSoSbgeRrgzquFEpYyqwVxXMdsGN7MpBZ4zs4C1ivAmLYTE7AJOQr/WX5+oYvBI3H5RbbMY4qz0i30DrkjZnAXnm3J6X4dZ5CW6RgMvl9t4uWIhdEKezcgnYAJhP75iglhXnQFkI4yCEeTonoV/yoUOw4JSoXA7I9sU6Ke82KeaPYXjjvoFBt1cQMI+QKYRP2ehraYoFlrFvIcUhy3EZ3bmoM5Cy6yJvFQXb/v49f73Z/Q0yrs44JwW6zCVoVNZCdI4UOYg/F7DUxfLRf46LQkObFlkMImRCfOQBH6PMRNWux//4glgpYlJRQ2ZqRm02tl5WFYtwemN7DfNmFd/UIvIbGlskpW3vvVC3XSkQ/n/m3gPAkbO8G9c7o5mRNEUz0hT1upL2tpfb3etnn+98Z/vcbdywsSmG2MH0mo+QYGoAQ+hgmqmmt9CchCQE8mEggCHEFJsaSKgBQsg/5Fvd//e8MyONdrX17vx9gM3d7kq7O89bnvIrQjKV6VjKVFOMmxBjcxv8ZhUb04v5OvsY7kx8EHq8fpWC7+At7dmdAzS8FNQ1A8hwdWJhz1xL/qAGQ6iUCZmSQ+AMmLJXcOXcbA7GcCVZHqmoT7m6lbJD8waxu4+fQKZCgVQrZimZpvs4q1lS3MsIo7sP7R2jHwrMA/vE14X/gQH7H/GruG9qRA++GUAXQuYg9ahIuL3NBYSoPVhvBOCGnT0OIp54HckQehahnC8mtg51DCkPDR1TbLlvXUDZK/vLuIb1lYRllkxL+Ou5jEc6kvCBIjF9pIPsTvr1sA/jqXTd6v6PCU4miVaizjYSYMFBzyORrmGYk0TDNQ1og6+8sSNJHyJLCdxsk/pdBHYgmVDItBpyRpZt+aNIUbOJTDJJpor0krvBYcUIKEF/luUMths5NWRJl1DmH4P0MGQUSbHSyBkXJfLJ59FHQVQFq1qmu/xVug2JTmSdWRyPXeEnsRfCGRqwKc8tiz1rGJp2NUMhxf0CLewAUBU8Syrv9goL4wI+Sj0enHhNX1GZX21tni31Hjt1EJFo1rG16K7EQy4Ltt8GIuV9POo47poBWUyECgNbweU7JsyeFM92fVkiudmTeiS8ys5pLjQwztpKHT+s8PjJbJ47faGmMSiBTBmSiDofHQ2pO5GE+DkehUTGXiQ8LUj/fNnYDigo2q04BAJT9KUy1Ya+KiGZpkK6mr4YVf6Z0ApL489whk8oJvajpMQ9GXZAk9PXdP8WnKgE+GPwcZMz4Pak0hVj3z1mPQ3KvWajApNlat+RlCNoa5B3VPGtuHETtIFgMqJr3Xubycy/wXJt74Eq6Lqk50zK70hNsvCiTI6YWFTQUK2BNwKJSUm8jPGoCzSZJZY55JYkknMRKWvmPh3Q+IFwqmom06IvuTrVZs8g1K+ZLGRA7ExIgVksCidDs+r25UiMobsD3i8OVPKH0eBHCPdV6N6RfQMOVxWzuX8R/gOeJa+OfR05UQ/DHihXLO1lFGu6a/3FhH88OnptXzk5cB7qYBvjpThLs41AKCYgEc5TrwDFn4CtSnUmHcF8FFOhBqITrh3ul0Fvs4+7zvCfYTyO7yYwfkn7UwGHfB6CS59+kjp3nur4B/hih7BOfasVAKnL7CGgVqcsGccc2kDA02VTQmXMtdwEmHHWWH7RPc7luzG6tLOGJWvxyzLoPSTSo9jpGLdIXIcVehquXlDrqmIdO9csq3U66SZx05MNBpcushMZLZWViHxFjx+sTZiHepWD8GncdYjdqUBBHVMVCMMnSBYTtRhJxKe751RgpoEev0KLGIKbHtqMacqlBHaY/JSkjJrMYlXiPdNmzkB/LyGM6nEo/oDol4hnEdM4BNFKpSaWYgcgP1S3KXinQA7A4CMJiDSrccjSjzl21bAd/MAoruUkCu5kOhunCQatFfyz/DuR5OjisK/QINtA2gvcfgy/jJo0U6OZqjGmZ9Mpqt9VKKEmponCZYNmV8ex/jjKyZZ81SdhjoyAFnw1Ur/ZRxYKOK/7DWZ+OOHAgBqKMx8BevACqEkFEFe/JKTHvLvY/wqCeSDqxJXMbrs8u5LkDzhw4+1s6soxa9K0qogAsByoZoV92OdGUVVF4FLHHWnu2nn2mgi8A0LGs5f+0YPkDGx149BBJXiH9oF3yfmO5WomYTu8ajNzTfcrKgRQ4metSulb87vnWhsXZP9NSf3LDdtMQyVPMmtw4hLgqmGrULRMcGuVhK2lcxItFb2U6WM6KEGXy1LgaJNIjjsc0JHI5NPCwkblVjENzqcdllv82v4W4vvvsTdHoRmNdh+a4dNZBjgui/7HcIEHEhH9BbAqFJ1NlGDz0TUjc2H+Af6McBfAGFobDuchywXPJGlMu8aZj3374znFJWlIUPMlGAZoi/Wp/Ttg+nLuBcegJdaLO/sFfyjh8/8lPf/iquh10DNpDxZkgljqL5fZh80z4XUhxAO21po5kuYuOyXAMCop5EcjBMJwXF4hiej0ZXkrROrFVq+osJ33wiAIQ8uvayehYjqwCDIFq9o8isYovgMvde/lgXtT7B9jP8XWdOaD8PEb3kfQ+AH0FpqDBCW6ok9n8PCHMHqdJTCkFoOBb4mFLTCKaz8h2NfTLacm986wFOdoMNvjbJk97DvvCKlOTwuYTpzqpE+7T/yzlRyn50BPYsgC+JmwrQWAl+RXLACpBX8mLDTjK0KhWopnKxl0wqlXTewcXb1Vq8FKjDqhop42MtcQeQYHgZZOo272PXZwF2TS105HiFLWnAGiFGA8K4hS8LdatYRUTCs2sYSguTawhLJFuCeCWMSZVwL7BEdmJlu2Cqq1ao/amilxLHiSE3sg3jfS1Mwskq5vgmBDHDwSr4KnU7FWivN2LtZhjQp3qClcAq7cR/2OaDtEJ/vKGkjWF/upepNaZrwsa/TM0PyivRnW9oIPbMbKYBEIJ8RmoTs4MO4mR96lnj52J1B546cXrzKQyeIlA6WiDxNwH2N1IEQYz8JMw3uFOQLpJV1YssehpG5k2nY8D3sPDatU1aBTiKsaksGYTJGEhWCUoIAPtnGafRJP6o19bOf37aKpcEar3Bt0J2ef+nfvIJVAmCADSWHAMzY+coamyKKhoTNaJnc01dWaeoLrywmPNK1M3vASmBI72R3HJ24W4tQFzUu8+cLciVYJVmq2pu+uBcQnrDkdJR10oeNjSac+01r+SYj2TJmOOrOnbsg9QC6I3Vke4PdrHuzitBQZMyZ5R+l+6CoXaOLAcmVLEdUS+t5qvOESEuFNR/ck1QDKh0wcEh3HSfxA6j/02RVgDH9S0OoHNAB7hrufhJRtjuKgGryXNVDRLru9qXR7n+APq1i70ZtLowku/FYy1IKeBoROCgAaJR+gIS0/uB8f9gJ7Ak5oBiKaLcNJ2mIjJdU2U2LnMMsnAmgeXmTw+VKSh0xIpjNJZQRak1WRD5hEmiLDPVMR/SeVEW5AA83Ds8mYsAu/6M1Hf+9N3wWj5SAISMWw3cKAvaqMjqmse9k3MhpnBKCC1kjLLcx4/vjXcwuWDUNrzafbhBPgBOOzhqrwX8I9UCq5JdhZi/7uAKRxj8jzJj4OxENDwu6VBFmJTOx9FTRS7lqkIx2zQaoU0UwRSQ2QR0Wa629MLsn98sy4CtMVrdqoQ8cEFkl7Du9JpKum1W6U5IR/HsHcAVVLFsbRxazgCyOSAhm5n6rqfThVIURkVnNpnQ8PhGZh3J8cOOfcdtaxFwhnQzxhXk/xlgjmW45dXKp5ZQ/oI71Wr+npMrQ/Ucska15qpF1T6ku1pIXKuTdUWP42U/QcLOZ4mhRsD5lm5/xW/CVOqB+hAXwDd7tdcYGhTTus/yv27r1xbjLkH1w95HgUZOMGGBtGzCReqZDkX32M9RuToC1Rr5hr7f/5yvslceSiw4nV/V7JP+vDu4muJuhsQMlIkDNqgXXhjIilUXIkS9INflgI9WZlmrF9VqcOuYpJG52N5W8yE0oImq6X0pjgGDVr5817Dt52WLhm6P1wTtDhBSTcTkS78N1UHzB+VYSFneCsDjYKH5Ai9BuJbwRJV9eBzwfX8+cTH14z3C+mhF+iB08Xwt44njz5BPstA/hHimQl7JeVoa0LdQ8oUZjjIm1Ud5Z8URR+ZDTrAQGmV7giIFR1LvFI+KYbVCyOM9+ZvOeKsBcyH7hM0PqQ+0rPe+U5bshoB7bHdeepmeLdu8+2a9Alw4GKqkyXil7DRlfdvvJyZBeZrGhmUgXdyBsvmsSpkVCmr51qtzTqZgoiIPWiqZe8peXPqmShBRuShG8cDgsNSN/ybb03aZKBQkdP5rvnjo+rGUkXSe8wqwE9PnNlcd+Oj+/89ycbtUpJRXlIanlWZXzXJTfdtsszdDgi6NlEsXsmu0+wx2y6zeOkqEsmIviByxBwSfgehvF4ZWKhWKiCBibxzEBBh74s0ReSJ0oGWuvoSxJSoXsFNLkzI6ZEWiv5s70kxCO46izbIaI9icE56eabSt68VMkoRlJp87HbDxHmH3NS9fNj7900qXq9fbiykuvvQ2kPCzcZlozYXGOXbYZQ/dABQvXfryJUd1WdpGvW26yDlRwV714+H+zVH5g7GjnahixZP/sZf/vCoRux+5SQU90a5FR3o5zqEudUj/U41WXbmpicCDnVwpOHlniNWqM/UTNqarCTP5zKF9baqejLp3r86dQQ/jSvDZnwUz5N+/NtH6bZLQzIWqf9VP3E1oZj7Phmztfrt3i+vnRr47FPbHTgGic+LyyLMjREbgndMEN/HWHncKCse0rkeNDx521KmNmVTJ6OJXg6VvbTMdbtbBuhNY4UFbJ9Brn08MSLCTdpJQgqI/WwnClPOv8tx5aTmatOBfzKQIsUmAdOHHvh6SWOzfTB6cQ0X9xHsruLfewk7iThc32RlfipJIy9WlAApoFyHMR3ZZ+XFzeT9WxDpenRJlhiL9sSUeg6I5MlYLmeHum0LHfPgT2Qd4cFLagvguQQX1zokcNEkMOeG7vzgSGHtTcdn8Wd0ejg8Dqvxwi7fwUj7OXbYYQlhwdyQ6Tba0IqAdzhJd+MGDulbFVSaAVulwb2B73onrciukNhay/th7fdssYvH9NR4aYtHly9Heds/28L/47QEvXrTf/XqF8bRFT4eI/pNb2a6fUX3UNrM70+E7YBW2/fDtPrqvWCGKV3HfLpXc0h9K6zOb2rtVV61ws3iF0ciNQfCv+J2LVi18eeFXvHphO9U3AorgrRZvK7R25CMOdn2zs2191sy/eeAp0cc0vn6nPXD97yR9bXxYmDyP5dMYPYnoFh/ZtIh8MLW2Z8GtiZkYNmXDgdDL1/eJOgxPgR3E/65G0Scde/CinuJZImJd862t9tDJ95puK802qTEV8SOndqyRMhGylqQCEl5Comn+wLELmA3DLaW6pmak2NnF4gQJU3DEBrx5x8qfvF07AOupdhBBOP34djXZfeB/PEBKsopoI7AZoIwoPJsAiCuBmNLEPjbhEYxziVbuVGifuEq+qkrtLoDWIV4Vq4cHAtXDRsLbx5YC04rSZc3AdXwweA6JEYGjBFgfO/0NxFxhgLlBkvjX2a422CDn2vF8SFFZWmsrG2oksdeoecwRAtG0CAJVywkcwyiD3jNoRBSoljnNrDe6LG3qTt27Pp8rNLvIe1kw+N/Qy1n34GX9ERfo1zGG1x1SX9VoTS0KHMGPTE1xJnpKCjTpOW3x8mpyKTIauZR16aoLQ04VTdczBKh23pHxM2w09QBSFox6cLuA70gkz6pX5u6yg8dQXFxFKMgoTB7Jd5Eop+GMlkcHyObxyv1RsbCji2MpB1AehrNwbI+Am7n6cU90zwA6UML/nhPmXRIuSpLW/IBdltEdntpwWiltljKtRe1eooumrscb2X4t32dj/KvyLlkm0HvqayAyeC2tNKe2ns72I/2uxpD+hyk0LS025pcxejpX1CQEboUNoWxt8NwSJLvsGlN9/3sq0wchuKhh7lif820toCSwqlBt6ARM+pEleDhHQOW9Es2EBsUUR94hpfLRm4OvHVgr/y5dL0dkvkSJhi70H7GYslLgnhUkkHSwVsNnb1mlJNbIV2z/LdJ3+tIF1nxSNnLGq5aRigItDyxPyEBOAZVrm/HGgtwXuHJXuLSeAnIpYThj5KIjmx6+Du8WRvNfXfQLbffE1U+OncqPCTeiSJHtiA8k/3xRtdSoCp8CW4gFH0PbH/2hagW/x/cD1uhqcuXLkO3ftVTF+BAj/xf3VpdrUB+vrM4kyEvi7MnnPpsdlcBCZ+vDzbh4kX8N0qGTeEiV8dwsRf8v/QSr1jLcY7x1LdxxfpTeAcfI37pZ3+9ZbdDoF9aWuL9BGnfkV9f5v89q9ueiHCsuQ0rpruWdtkwn9zS8uN8+b/BbJFcUCsPkSq3cPynIWBlKoth6iroMzlM0Gk1ByGtzqt8ilcq9IqUOlt/mnf3yrE6tIkMarFFtrpBGpsPWk2VqAuEsGadQ0gTQ0QHZ5dYf4hyyVFdZMaclCkUSYok9A0geFo0YMLuSE9gzt4qBBlTwRJleElVTQOYfyKCCk6+xnF2kjm8y5QuXvRUE2pnpZLWKJiQQQREPj4XpbyHCcNnXTh4fji3d0PCsX2mJmy0dajYCLHQQORnW3W0ugM+rkPVoNjYZhIJiNCcBv5ncGiWTij2P0Mfwt7lK+Gcge8WvYkvB7HgQwemditwh3Sm7V1NW4Z9pjzO0zaZXfeMEEVRvvkiF4vw/tXAAx+Zt597ueNkQZQ8GltdGISOKvYie8IPwfD84McRbed/LjMCNCwRPyTndwDb2FtEi+f+u4kqCUdI7wp72yUXa9adG/YcnqsNwGkCIbEwLdbfvIdcnplIWjN1kbqymYz6dduIfk9n3tkGpqhF+bzRpTge2eP4FuxRFjyjmTQoPNScPxSKcmm/9yyQeLcffqqvFmIpdDh+v8gbvSa2H3+bVAST8Vd4CwOlSZCqiOuFjLqrHlzsJNuuLGHyzBjObl7AVPjVfJFAKJGRI40J7EyHTnaa8rtXt2Ue3f3+NpNubvCpty08Cy4Tx/YM9u/H9rj7S3dD6mxEv0Oq2SPur8ZkEfCkaeR+mP/Hul9I9le/vCWOnlYVAnoqBhoz7ySxufR+6DHtd74Ophf4zZYJbfirtZbWZhmgd6KuPLCYOtrrzjgx+BX0z3cBzk1ch1kB68D+IBqYtaz+7dBpncbHO4rtFhOwpdosX2JFgToMJUMZsFS07274nuyDgxIBvQlQIGMHhRIDO6Fj/YPdTe4FM5ccSlo61wKF94fkXOBkYev5/LIKIv4h8J1/HukS64e3huPDe6N5Xf29V2OD+q7vJLruwixTGwUhOLfwKDrdoSb+zEQUseG/U+Awg/skNrAUOCI8Wd0PtuJGMd8FOsR35gMUGwOoKcuXN+5N4wVwSvmexIOi/Oh/L/jcZYNXIACvIWPp1NwbCg+sUQ4LqZSILe8j56YCo5fOYn7XCRUQW7SgjpwB5s7DttzQ06nmodrM1dP7bKaVhqOqnFCwQqClqjbWY8ABsv3UMPGVudumLd3ZwnBDqQVfIOAQpDBrjgHyC57NNvyEijRRexbZA7Lv3XH7SmYnFuKYKKqcNGrQzOwJtaP193JLEyAkppaNQr78p/wXXLVBpSQbKAfBZ9TYVvOiG3Pe9WdteoZNcsQxJzl7cx3f5vE6AsI3zdhDYqwpZRVgXPOZTMJlpCYA/gGP6whJX02nJLQJjgI4ltiQvg3jAsvj/0Zb6BFGdsDdOAVdFGFH64hpZ67soaioYChhP4b87QG+nkB39MDpQIbOPDF1ro3ixt++15SR/5fbeETUT7pvT0+6ewj50M26a6b6jsmuUuHimGCIgbSPVZBdbsf7rt0sLtYylEK2AlqPQVRlbjsmZ9cozTo3rT64mjwiwNjYLgB+hlCcOHEyfEnyZ4H3Q1wTnM9UrBrlCU+x3howDkt1ypJ4W0F77BUrlcwtxR9+VFsBe7lAfHRlofRyzNkG4bM0P2lSXWaRU96Y2p+Wu+f38DWlofcDlCdhRekaXTGx81ciy6VhJrSU1dYZkzi0JiE8EP00C6Cisdfx76/6S7aZldP5wFYFtlN9M+u3UT/TLhojeX1+P7yesiDT+vCSWymhbY+2oZ9aM21d2XFE8WSrXi5XFL4+9O3spZ/uT5MJ44J+j2gkLHYFRAA+UjsJ/6gtRKauUodntL30FXRTsFCM7hYeFVBYNIyV/OAe2MH9tbZgYXZGLow2VbX5c72ZtYlW3lavdyuwQhZSuv1w2W5NNIZKSvxsbkx0WpmMqNZ3aPjOV5Mw/0oO5JhmEncYZsG6i8799Vx2Kwb0m2ZkQosX+xS03yOUGyNt0qj0RX6pf4Kfay/QgWcf1tYoKx780YrVFixQM9NZPWE66KqNXVMsVyif8PUTwCBFGtHNDVZk8wsyG3JJNTmcMVRpmkYdkew3AJMBLEJ4UTm5GA+Lhh4uc7+mJZrxl+uAl+tRX+1HvZPSmPKEj64zloF4L+/VtVCY+2VWjyzHlmnu3ECCrECNDmWAQ68gdSXGXdiFnseU6HSieFXK6G56BIhQdvjbHNCKuJi6N/A+dvIkQLaSQD6ACdN5h1jHyg9L9yZADDLBk9L4KYKgEQEaif7OaECbtpgAJDzOj4LsFEB/oKJudViKqbPC1khpmKazUq2MT1vJrMp6PvjLUTDSo+auk7TntrO2bmKN6apzFBycJBnrzarHs5J06uYqR3T0xmSmSElV/jhWuLo7ppZcZDE2sWaWQQlDVD0dRRVuu/FLCnn5PMqrcF2e0TPNlWcDhUA49WboMRttYGPJvpnEcnKKK6la+CB8fnABGzDDGSA39ccIAkNp/hldy4+EDnL8zeTj3w54PwBBxhh/wyj/V3AKK31CvnI/n77WhfQ80UHzceB7T2x/gX0o40yErOq+jXSGrw/rZRhT6Uygq21YcenJyKXC6h9610u7bGx6OVyGTZtHOvjl3x9zMWuDKR7ESSMLFD8+eJ9q2higyvA2xgr/wAtjg/OXQZqlpC2vVSljrrRO37Jec5aK2Ba6aPrl7+zBrr+u6d3fbCaIDhjZRUKZEKhAv7VCpZXdDF8al1I/n+f1kUikvyAqIP584jY88gQLTt4XlMZSpiQVYpXQGgRmzt6XgxSfzpRyhfZv6CjyTaiFTE/oYHcw7y/LkMpreZb1ejZTaa1amLfkb2J1RJYIjQthlODJvsEojHBF6e6YU26UXeKkl5GfSf2Rs73CwS1MNHrnd6CKAzVw7KxY0D/BbJiTcpQn1eUroNuUyqmurkNuEjCsXSjlpdHLxwF6C9dTxNAwxfaIvPaWFH4T+H7IOs9GVFEm5gUU8SATc/1NeSgddAfCOykXsO4oFBXwel/gp46oXI6wVpgLr+YkXLWZR891Il6KEtAmEwngI10CmXj9v/alWnpUAEU+Zza7+Ma+shIMU5EeB2t5UfLkY/RgxG01MOwGVKm8B7bq4+arfNHuj9p7vISpmLpdJHHNXXETAmtEaMgPM5Im1raAcwavSVdV9P1M+s1FP4jWWc8Y8HUNuMt5t6aSRtwaj4fnzgW+fDoxWNJouzjDle7JRxieS3Mv5E3QcRDNlPoXOLiTcRkVH3/gKrvF7ERAFifGLsj9g8YXsdatj9Qwe/uCx8Tn3GRc5rxL+yEcewXRuyUxaB344Ww90HM+2LIRBJnmytO1xILRIiARN7wuCQjYnwBfKzb0k7qHynhUdzvO1e59TV+3CzXPGpA58gVvlzM1y87Z85TvGrVO7fqutWL6U/YSMuvSthq/r6F+fHrGhLOLmh1mVP28qcBkfdCiDxL4FamQxZkev1VY3t9IeC8D2XuOX6+fqODU2TjtSIeWBJaD47RtugwVqtu9CQWDLcIrmbRytc79dHjlaVsTq7sH5+sQtOunLPyeStHf0q32cN92rwE2phlxNGFTWgA1FN/tvty3/UT0CxW8F7jeH3eZKnGpYGFkbUPzic06+XcLst0ZZf5JzG6d5FT+Dm6m042i8u/EnN2Lp/Ll71eJ+kXsYPoJD079v6tcfC5+WS0Wy+Sw1nd58wglJTNZTexNIKwd2htrHtRc48sgP4/vCU6froxe/hhz7m6R5m/wyrVLWHKGKm6dmXEXP60Xsql79hwDWhO0ShVaA1scCl3GuXqAC3/mE/Lbw3Q8qvNY5xK32aXZVEeJF3Hy6WoU4jvsGaMb7PctFzNnYMor3fhvrjUbpX52fCPwdnwEGBoP4CO0M83eTZIK5j74YSGqPtBvCF4FEYxQvrPzh3AIHg+1E6Di92KA2Vps2fFfrbheggSN/o19onRU+NLa58aN6F3BM7+jf/LXyVKb3qTfAqZkuol+6GvxvFLK4y4/i/yF9iYlBk79+kffgbOGShUIvap5S9GD5pLNz5Cxmq10saLB2Gk9VPwz5FLB88Rl84R1z9HdLWmhouKsrWUP8epjZxrFEGrhhWHbrbTpPQFg74P0/sm1GrewpXHIkfOX6691v6ouWNHYc8GK80YaY3o1fZYGegJc/nv+0cLb0cKJ3g78jjsLz8Zu3/T7cjNcbA6fG3I/ZvktCT14ibakVcNtCO/uJraJ6AdORnlcd0XXTvE45onHtdZN9HiMGas/tK4fa1k/2VbTvadsBs5NdiN/M+tdSNzqGRI5lYkHYCMrhp9Ithn+UphwumqAzbuRDZPfFn0cOCdCdLAywAk3Z7BoxRSf5qSI/LcsZcf4a2kyIJsbeJ88u+szS2/4Kvp6BPu2obVI7s3cHgsqt3GIyk/Yr/1U6NUrljUlv8pXHct9q0ND6IdjVpp46JSYCDJF5Mjm/R6JHhKB/xkcQQ2MkEelIPYHE3JgmMp8d51T5zOWEev1nfUID9trbN+ikv1xsRIwW8Mxk7cL/yM8xNftXl+4gOIIv/J+izG5Y+cNqD4gdUsxytWshx/msxccroh4ELsLEAbD2CKcB5RtZaAEAxOXpcSzT4D1B8Nc0mOoPALR9PAs5J7QCDkEwh6ME86GXIB/rWCXHAPtctkVPI5qE+3RjSrlU5QhxsHrVE0JLfgxh9st+x0Ddh7UfZPKxPwI01zJJIJdLdBGOCfJsbAr/AtQN7jPAowTCXIBSWlnJkmMS6c50lVLRi1w/X/xBSClXeMW/a4ivxGBMwF+puu+sq1SAG4ZjciBXDEEkgBSz4pAIftLHoyZ6An00Zr908IOpgN5itLi22iUNJm8ItENO2oS8fv976lRztEhgbwvrWwoQgv3fFQfkN/Z5GfrGXmk3w4sGxpjDf5fTOmA0H3Bxus9yXQoeSb+LWVdjpLv7FOA9tExr9HQLn5gm4R9GO0yCY4+JNulowcwD+lvAG1vuFI5DasRm6sdWCxW+kAIz05ZjjQ4CECtqyOu2gRC+zXCQ3nbNwA5RjnXzxXLsmFo2WnZCV8cwE51UGPH40W6PizSyFkXR3/g/HCbg8CeVAEOAsQ1kadpFlkWMQkPetWH9wJfZJ4D96Z0ggYtCae+F0G9j8I63n6CdC4yZScx+p2JqPZgEwYWUeFCj3aUXpaBy2XBCeBRLBKDoYCsKXNZizNgj6g611vFEixTYzNAShPce/ELiAVHm9l13XABsgvJtlpWRlf2DG3lrPP0b4s0m/Xivo/9aLe8KOeSyQ8mUwAKOqVNaNebHovjXRASZYqsO3h/VF2y8ZBfNZgEB+3YRDx2GdQqh8QM+AnPCX2Pt4843ZyRJRfDJ8SZKPxkLj6pUCbJcysg/xH8kVHaGRSd+o9Uh1XN2lSsc9NdBa5viXptYrgPwSCP/W5LBfG9GcuTim83ujEpXSFH7liWZjnJAOkyvRTHEZDGYAcw0CXWAG6BbIfCASUQtncGWdYVgfd0TgaWZ5xIpb21KQlPMLQS0Uw9bu72c8Bekd5jLi0jO6hcRw+VYfnemnLys1cP3P/zKt/ek3GcFUhmfTyBS3J/mLxbehd59SiiUB5lVqBxBCEkbaZSQokvqvQdSXaSBrvLJXUM4/tV0oeT5rQNU3JZrk+WnA6tuariTM1WSrnJHDnoHP6qETLOr84jiIXo7As7gMdL6qXz5GACE7p4DePp72iSopCOahrYhpHF10LN0RhR6ckeM0x9wm4fMFCFKxcUZswfY0GOckP0R/wzeRXSW/fNM319By1myh2LtkE9mLfqT5ol7+yIZQiuxEbaTP7cuuH64vWpxWJCPB9PMBzwNfdFkIjNk+mYF7rtIRa2LFFekR5ttX9h1Md109ukeLgSqUrN47i0waj+KjNnK6zkIyiMJ0TeyztwlNgdiaelrh98VTZmB041bE8VS5lrHka9ilPW+7hEb4C7pAf2B5GqVdZOARSIkMHQimFyQ1dnr1Q2+6WAu0Mbs7Xbx9shINPhRSzKdyWadUckLdaIdyoG6OQU9x6IRe3FvGBeJ8EeAguSqaaGvVWwYf2UuidRrXh9IK/p5Fr5Puhv+biwdAvrgj9NSvJTeMkXA8fwyv4tqbLtTcbJAgztB5En6iyFEp2eIF6OCn92xA6tl0+TYYSgOf6FUjZnwCPs1bgRhWoHRLzBQQmy1V6FAx/BGnt7FkV8redR8rEv9+eoPNDIvfsn10z6ajEI1AhR4T71KcvJItUL+rQAiWoMJeTSsoHUaA7E7BBwlxJt1tWVcCiEGHEhxfLNOZk7DjAPdBZwYtxntIIManWISWZwlgMnwKhSSJsMVoMiK3JLZAAe8cZIafrI5m69aCLL/RG7aNpR7IxmeCi76KS1PHjQbe8rpnywtkXHj9iFSFKH8e+pxFMsZRK26QiKe3RywaOA0lXdIRfTaWV5e5yLu9amTjJ09uGnlOFJ1ccT4T6ZRpMKjWj3H1PPYtlrEFDX4HcW9bzsqSNtPfE14HQjkPE5fmU9568iAvXfQiIDNQ3aA64TCJWkYQaOxMil4HXZK+rMKScWbHfhS+cAlEXYZbJagrRy+pQchdn/M2ZpO6NRkL/KchNJEi5HTuzaAVyEI6VtoBiX357/3wvQl2it9nvCDf7xGpaSHsILeQcnxbCLoAsFk6BVEIrTVcrVwe7kDiGELigXZiFa20KXUhk6pcwdq6GzZiGkibwMEmtEe++m5/ql0dP9dxiZGPzSH8NlqNx3MEvw7zgVNzBzI5KfIC9gK7PoKdowEwN26/o/OEPgQzIom8mupni9ZS5i6LNg5irGkh+XOQDcCEMbEBWUlKAkyDunDDSD7zUsHjczWqBJkDLb1sV9uBa78XdOVX39CI3+gSZRjMaIyNpPO2Hc1ZSYBjKLuUmob2TOZ64Ej/MdaQ2mU7b0CChVfHKDe961EidE/8Ehed4LAtrpj8FKwkERsyZ50IkJlhB/TAjcAunLcoSoIrNhoHvWxHQtz/Arli4+ulHjjz96oXw/4VX9MOXxqM85dFjqZHdR5vNI0uNxtKRZvPo7pFbJvc1jVR93/zcvrqq1kG/68WldHYVUbkGT9yPCqwm2bmnJCrfxkQBVbMNIFsKQ+1I+/ai2Ot9PsqKhisMlKiJyvXUhrVabc8Z2qjt4MPSqesGC7+S3Gjz1ZjNkofSyrYrajeWKQmrvjZTWv7hyTWAwYYSgh6smgiNk7KYlazZfLVmMk3WexHZfPgveh47enLtYGytmRPfE8+BnkA2tgv07+es3lrZDa86NpC6Nh0/hv6f19YAEFdupUtXbqUja1xgX+tthcWBfNQ7j/6EFGa27K5N4b955fZ5+srt4/DF/5CBi+qMyEXFDg2kmPuDP8nMi9LuLwtp96lEStWXP71qv+zCePxeMRk7AAZXjEGkirwOfH8qgRSnNkWvbp3CjXGRMrkwqVhVFxY/uqyZifm9O7kxEKdSuz0qdbVPpe4+KbIX0P0ethceu95euNBvtTll2FZJviD35CWTIXM612iby28bypxe2NzK/9laK5/aqT/nso+zsctibwhRMcHc3+KGADyx9FbQVX22qrfagtZP46GAji6p3Bp44jM4k1c8cJtuFznwlsCOmYuErl8pQphlr29Om+HmtDcls8i2hKSXLKau7NNU4WIrglWhE0Y0S4Y7fYgoNg18AQYiEH3+Ao9eqWLpYehgNOTHrlAp3BAlmRIpVc2mMztUpIyfiXBSA2fb8U9FbGsHmKbFnQcveOSzH1SYCSJjUmQumT76oAv3qwNxGVNrj37yH9Z4XH1YehBYFUURRZb3S7+Kyshvpz0nNI1Zr6HGBvtp2CObaagtKWs6z4vzfed5Z2m17Ty3gFwQjjbPbWolUUxG+mtO2F87u+wt5qPdNSNfKGe671nr+r81PPN+IQ7ayV/Qs5MX4WkbGsob0m7fTb4SusnrBqFIP1ScKaXKFnBnUG8L2m2ZsN02ZhmmnqiGzTY4AuqCahwfkgrURxo8FUDNjvPweUejNvF/BJGdVJbbxOM/1wQ+8emWGw9d4iWHXOJv95MUrzFq4TDcfeK7OAzjsB+Hex/DI6YbyPJxgb5HC8681a7w+GBniCu87XKXYhoEGuLAEQhlAhx/+0QuUiM6wgW4VHNevmICM1ByVRfVKmN/FvV9H5+bSLAXRHzfR6ZmrO4z01lnDiiOdBWeR5liw5JqIzV+7Td3KHyX6V7dprNeeJk52sjlmjsyy+82qoUMbm9YvC+esW+Ixbu5a5jFe6HW3YszgXZ7Ou84BfBIAfRu1Wt76he+4SJ+ull1qFHHs4WKgYNtH7SEl3Gx7Ik9nLSEme+rzUEoXPe6v4wbUQV8fCDse3muOEyAWBxQH+4M63r195GPnxG+AYB1s1DosPMKbRwvJFUfr7VqkjGZyY3iuCBcQ8YRS81mkjvSKclqpib2h3f/RfLDLJMv6xH14a/1+1iD2+TNhRFRrDeEX0L20BS6L2iP1IpXgi+uo7yFtQx92ZnUUYHdFcAqqsmhC8kiNTRIrnD5yj7H4SlcgdggZ0ZfgtjLOzTl+zbvUO3dv9eJ7gi6+2hHsGrBK0JsxYkVxLzwa0zqYq0N/LQX5zzIKSy1eWfKp7qQM+XO8LrA8ybgKw1kuO1Gfc4HwLlegJLHAleIrU9O3MRWWxT+fl337Jlr5phYrpPDEEw1ijKpesNLW8ONmXVTnALA5NCTGxaJ6aSa17hbjWQZ3kQh4SZa58GlZWx0zMs0XrG2afbz5XgitNiYuGoOqCDXMcGcwuZy4MfuYUUWXCvnm3oIZI+Xh/ulTvwklFF4K+7k8GPh11zv6mXrsdy5LXKDG3kGj3BxZ8Tus+fX54NLsUIh3xY8RP/d0Dci2Cs3VM6uSSiKQN6FO9ZwQ8YPkU/oAhgfVqdZkuNc1ENGOgofP43EXuD0SFNQmTxLkhokAuq4jzPjGrme1JqNNPwUGznAhg/s31WNUIR+soIiRE/Jd+C41acIRz2ry/4Q81yuZeI6KhqKY7Njkp7HkJImsGTag1w1k7wCd0mgJQr6SUHnkzVrwmDde/t74dHRaTfszWgf8Nh8i8fmIMlmnxRufDuB3XJYhTedFGqcnVjHujxhiCsDHrfk4eFuBOFOwOSmVufh9nzT84293Hr+a+xPI0TbgBce+GDviQSdjloEHepR/ZAfGAi54xvhGDXdty//Hg9pC6PKD29PPiCChNzLFYJOxaacczczmj57y7IAFEZN5XF8LQa5J7dpq34Uu/kNZ9XOJoC2Sn9Py8BpqsDxKuwsFgluZ7wzZEefN2xHpzto8nU/t7Hfxtd5+K+KPRqNto3O29U70o+ob7YxvyqWzWAjshUthtZOUtkc4958FYFrU655utJmu3AgRom8pZcSPDpJIaOx8VWBOdOPy/KdO698yuHDT7lq586r6P+v3Cmozd1nNxqHF+v1xcONxtm7m+zFa56lZ/UO0ml+kEKzR+MP/OEE+Oo/arOts+49Y4tVNVFamp5eLCO2i9MmADAWsn9k8bIVedIPBdjxY5u/2YgrHaqQRrdPRZxf++Bjg+LaWxLWhm/nMAXsdeNDG2mHmZ+o21hdmBzqycEtJCYsHBxr7p/lfxtU117ckrT2h9gqGex1gnqIZEKzrWoY1AQ4pr2ddLmWptwksougpNo9R0kr2SwX1T7CbA25tS+p7RRygaQ2zOsDSe1xXUU9IdxezGCDmrpqc/8D4u2JMefEV9HUVrHX3h37Kic9+9iqhsyv0DafD/YUtOYXfO8hXgv1ws8tLX0L27ofe1DhvfngNcFmVOzebCTSWu3hk6d6bsz4htwnmypdzglaCOahPggWkK95jupSiGgT2CeTwQ5/K94VpO/JvzWXTxB+SXeXTiMPaF1/CHZuiaSm55xxw0m2U5a6eLNRByWGPyLL05K5BjmdAw5cO1BjqcKMJHfydzNhj1kydxkFVKoK5mBCFkBmTCnTvGxCw01r2PZUubyrVt1bLM3YTh0SWC6cqVG/ArLOmqOfFkhYSW3k0lSTft8wwF/9oAK+j0P0iz82i+jWK3DkTiq2BuzYQauaTpd03WGPxlCT4yFRBms1DTRuQdgX1zVjxMrPFnITqmK7ZsUk0DQskssl6Js7DSLbCiijP4UurUQaGHT7uK1MNYWOmqxwi3D0CBKmlkKl40LnVYYFYzaXz8opEvBU4ikdP0hclWgSCxPnN6DnpioSVwYj/q4IY3bukoX3IXkFCx3cM9EQmYhdDAZfLOjGBgC9NAvO2BXd9ooobdjXlTBkm+cj1L5OW9nvgPlp24zPy+eJnvCZuJ33FLuAZ1A+givKc/PoFwJSniioXpp6FPj5l3+2Rk/3/rC/0f2wUGrWZR8NncUMRXaLGPWzR9dtjL/xTBpm9+WamYF4nyAkU5kO+wQX2Mp5QA3CJO271ni74DU7JhTv+x102DJd+epw/jgTAgsG549fovNAG9tREzULT9vLaC2Y/zFNcaGvgyMew3TUPybZcuOpV098SVxE9/B47EUc+TzHtwofPsIl3H+keE44mftPdJyhRc6TGW8PC/m2Ab8pTJmyHFgQHXvitVXWm3rSGw7MPMNhJxtsRBJgYc4vwsc5GZO+wyNz+2mQsOiXz34IksRHj/MgfDUMwkVxtOnSOSc7YukYSu7IdN8Fm0Mb+ZAiqSOvQ2Xsppy6pccT6d60E8yNrHJeugwzmiraFBnlysio09QnjzYzUnEc/UN2AVmOeoZV5AYC8E4v7IjHm21Hc6oZyE28QmROx9AyueLDvYajGVBWMywra+5Wk+g4ZZwEmmh1spbD1VIwPTsNNERSRsdJUXS9eycQKY5i4oLA/0MKz59vpjJu6lpvPOdNCmhP5VKP7802JypZlj00AeBzdsIGbPMw+Y5iJ2bTzoRb2kUE2malbJxnVjzgHEbLvOz5Z3hi/jb2KC6XN5jhgCXSz3Zpey1w+dPZGS6CiiyauiXDMuC+/6gXpMLkMcRL/bBnQ8oXgfqML2RTiZjW+U0DDFRYQ7h6xb2aWNq/lBhIbdka6W2QHVKSq6HVpWbVL0OITs11K94O8M0N30+zbrZqbmN6zuzYbbuNLxbSXHTGZ6nnS5Njk+xfcWvO+7cmNQAQC1tFO0GJo3kPTywNRvfoHyezybiyOoVF+xlCOCrs59UwmfV/su7HcBtbHZIjwKGcd331mcrZOdKeYVx8ZkTNjDuMBU6cdaRY1Cl+/UmpikwJ0S6AQ66/2MUdcVMVzOCa6OfKwrvmrhtUCznngmObUwv5VqqYs3rNAEK+C25ztOmyuzddcSaWDqxYE7xk5YIg9VIoCFLZlCCIZDjWRZEWQc0nH765H9BjAzVJrue9qno8o27uaPpVqr+7eNRuoWN1q4bwpBkEAC2e9bqSQXjDlQ7vJxnLbfjDAxZebzjJRruurBX0WZs0giJm7zMnG9+pDTsMOMF9D7s4TIdVV+dNPSmVcLS0KSV4n65s9toQwtc36CsMaUUEvlz/jZxlPnYd1ZktbtnIGwZD9VYi5tqzC+S0tklf56WV17EzOLj+RW+cVlUft0JYJdGXXDHHd9S61w63da5UHTsTare0Dx8duFoT4c3aG1nvYXyGVqQZ2k9WS6fkQ2kV106b7A1rmTq/KVRoeScT/5LSmjsKLT+pSRcKJevaCHiGWzhjMf4rPDSvCq6rMPeX+aYKVjMBEvsdZz+dF/ZQNc6voDX9moXHRVrD3nmXXFzq95UjXWUsMTMupRtnPuoC3lDuShGD5sm+QfNrYNDM3ttvBfOlSP3ji+YeN9A97ly2yyrFA1WU7pPWdWT+AXjo3VgjtoQUOZbl3QfXb1GEXYh6OFpq72TEGBaDucci/0oWflmrEZbfdNxcCZEAs1nEVFUrsFm91czb9VG7+26437keEw65Y5RtuKluaWqk5dTLKP6+aFU9I1tpppc/myjkM5MVd/rApU+8XfigXvTSk40HO5agurbtpKABq04VpNbExPKHyrW0rUtN7wnlVhv4t4ZkeNmMg6oTHu1WrUgbjv+a/yz8H96Nfda6/djFzeh4nNRpKA7oyrhRWZlAjYeKwyEaHhBMGnONvY960+O7oyu7sdXJg9c9q9eN3XPSJ2Ex4aRy39g5N35tPQ6136qdhnbMF7m9KsZ8ehG8/NWHZZK1V7Rjz+fnYHM752D3k/zDil7Jp0kHBj2OTNIG0lMg2PLeE98Xvo5wXkPwkCUZEyDP5SBXHyQVZI2+wAH1DBrcW73TbESlj/y4ANHaDu1rfPvcEGtAGx0oBOoQyE7Q8ekBF/C69tLOgA4WoJRt527gTuXky9BNBWIXv20mTSEgZWIpi/ZJQjYSWTmd/Gv0pjFVSxPTGw1N/hAVIVkALj8FcAmGxQwgZUHjsGKBKvRC3sCHiQfNiHUl6ZbrGJDSwmf/xTDxB5mGhXEUZFQZZzXwuFIkd0XiVqKoKroElXezngZEni1I2eR4yqYGkqsRvQvrA9rKBv1Ayx9HOxU81jipA4HGjsRK0GTUQQpq/eu9rJoFHjmlppwEMHwOUbQmYBD6NVGJ7Ys9CYnkPxLPlT+g/XE82+DUXPL3SzmOJ0oPap5cv70A2eb4eHDW5vPn9n4hNAenfvp8mP47VILDeVwJJSWb1F4H/mDJxj7aK0jUGN0vEo28M0aNb+qZAu+qlMVe86jX0iFiHsV7fzxs44TQkzJ7WclBQesIKq542YCkdEpLpglvAdo5/pu5J62QEjpwGRm71P0UZtjALovwES0b7HOptApYFRapL2hJwcdqx4WjSd1kKa1eT2r0CeCfkogZ+uAp3HDd36lZA8h2FPBAqZMZqAD2uokZdwKEUz4FhuVcHFIPYKs7siCzq2WIabmNycXFKaNgll0lBQ0LgaTNKrVjpWYbhSfuQpSuuKfRYQQvWSkoCYggWAnE0lSbezIVLZ1JcO3vRByFiJEa19AmLODt4hogMsSRjys3E71ahL6EaeL9ebsmoRuGxqqyFsdKkyVw4/H+EjiEJhqPav3SKwwXXELTpEdEX46Vlypgw86DDU34x3OgwkWyEx7YIQrZgQY7EQ6D2Ie8pqcWGY9F4KVACIUmd5cFCDJL6IWKwMKcpqnIJV/aTJFX93Gwfz9Rno6TiKiuLp11di7hzXpmKUFPi56OXIVz7k9ZuVGTSAVdydgtOV1dmjLKCleCyXhia/dh9vRMEc8hmwVwW9Bybq5kRBnokvhi8FEKYHEAayVB+74KhB17l1hoEPdCZoppyqjQ43zKhJWCH5x132Hn6WzeF8+5OBasHCuccfhIVW83USbY1ZYp3Bhp0Cw9cTfnYH1ZPIi0cA/GvW/wW1l+tevfHXiCS/vCVgi5f3OYCL+QxGYHz4L3PAEyFdw+PzVUf52iObncmO0pjC5thZIjNtmL0rVSpjY1n311plUv4LygVYunlDXttljZMbOjIuqlAiSGGKolJCh3Cfqeg3t+NdbheqHQHDPSPc0xXGms+1EG30gmm4A5CHs24N3kS3kf5whcHjLQ/y0REiSniXC+0TutovAXEBq1ZXTB/YwIF5g1aiUwvmdvY8KPR7zdkLHJigC+9RTFgGdwadKOTioI6MCU/Owx67PmHtNHPaZSAaHK54HvwRTjldsKl7gJ6nh2a2G6NQzTizcdpsV9S29em0m+vwdGyZ/OIHUrG7DKf3zL+vF57Kr4zIDwtoT4LMUeH3snGVuTOFvE1Zo7vzW55g1v7+PJ95RvFOokEWRoG1HdOqnxONOcUpr9dcTROp7wJi955rVo61F/Mpliz4SVtZciI2v13Ke//cbRHWxhW6Fm52+J1fght5JJRIysMejPWOAwQVEJdJcx38Qao6uPkhpyGG2UAsJ7wYnLDka77Uf79UxIb4fAuOPEF8SjYLIdxcwQ2v5LdX8aQ/MiSvQ6+1hfmsZnQ7WbETbxIl07S3xOVA5vHhICEP2Z0sISUsUlX91mPlC3oW0534emOj1UJTEsOg6lJcwX7rTD4RWy0I7PwGnx9NL/xDj/Q+8uBCGuvbMPqiUGhs3dhbg/TIVxNxDP/Sv2E1zGIqoEffkbGYsSNIjMWGhLqFNGJ8/O7JKRi0g5COhQCj530J6ssusKowBeCooJIJ2mdPe92LfkEGgMhadbchbQ15hIZRJTyBhBowNONUUG5UlyigFPP/PXY3o5/WxTt2TVSueBfjLc1EdRn6Jbgu9CFh2ykVeL0DZFXSEmQbKLcwEsjAgUNHLktqWIPCm2FA1e64oWdxtyEpJtcjqRVS+XILYDbQP6gtk4kg9bB64ZL5CQRJvNS6F7YEDAjV2dgq9XWjJeV5bIGARy0xLluoL/jVTFMpA/YUTk/3KvEEhILOm6mupn3BiWpCXzduRlhgK9ULzy4komQ48BeiTQL5gR1ESK0igwUmQ7gT/g109AzeASbl4DAbe5E58RD6ME2QP1wNfF/j72pW2d8ey0yg0Ggln+kuqPK1cxasW+OOA2rwj2hLU1BZ/gawpe+4RVmoK3BJqCV90W0RS81S94hUdUqgkTrVU6gTwjZCj07xEcP7f6OoDsR+gL9I6XkXpOeNXqy6TiHy8vxWXyiEHdwJoFG+jaNnQDv3GgAHEbrZlgOf+E4j6CyUbq4kEVhL1RTdFZ2AmewyUtro/9OVlIbVb2b8trS9oSq3ozEKKHDECIPrNayi8FZ97GtlJBdtkWyNVQagtARO1BENFyD0RkbSh48b0tZSDSscE76bwVd9LTBkP+lo38dGdPfBNWpRIIFn8IWeLPreGnu4j93TPTpQXQs9I99cthLXPcEtvAHffC5P7Lrrt0f88dt1rLN8gZ98msnkm5tt4zxv3y9lbG5VtTncpH/W8r4zPjlb7/LZs+68KzJkci/rcXVuaFVhGAXex+xiYKJpJ+zbOmbgm9b+WVy+Q1ay6T58Nbbf/gMpnYWCPldjK0lfR41NE24zvaxpHV/FDchawmCx7Os0iebxW5M0Tyb2IlsGZnDi0Ud8M8tDzIWhtgo80dEA6tJKOxXdaITbWu4I1MuO8ZEt1yZ6JT7kVXrVuf4aqY/OpYM77oREQj+6yV5LRnTu4bSav1/fNz+xuq2tjPnoMGjQGak50zpHV3NWT5J2utSbrLV+Sal/UCZtaLjx6M1HssB35kaCvDuwwgAAfxmQPhZhZZwHTsD+DN/jaKz+KSHAA/CGkUukNCDZ+HAVFze+xBioNf3Cl+AMkdhRrGg0H0RzJiU5H4fR5e54tr3eYryYOPtTNQkSkIQsYG7+VeJB1WfQodj/emR+poVWhOXq9NX3LLgQOPvnj6Itpyuh9OqsZbY1mBje7e52RGKKiJSFC/lK7lwcjMFqvaB9lyBRQlfln32YQD0Xtube6Mam3fdLk8vQ8ub3O1c9wmgiKaFtQZ2IhVEyW3nChLLJkx0xlVLI61pgqpVGGKfQ4XDLpUhiGhr0/yCYhsAQ/yI73IAjNXtIncxT70hEJHoRv5xr6xLy7kmwYD+Sw9nQT3COJawIrLBvpTlRP/LvwKFJvzgDeLUU/fsgMSGykgoPcY6ulxb8ee2Xk/o+K7Zr7fRKZt5OMW3bD3SHlZo92n4JPsnuWPBXb6gca/qH0910OmyX7NADlGUl4l8y/e5qZ/vDnhp/7sv+Zl7aRwlNpt8WTVIEEvkZJcLGod0D5JhXImgnaUHqNiAP8FR4Puq2RI7yNjRmIrG0nFVF6OFmTSTdgmcn6efVMuDXqZrBuw+LtLsZSMYfo5diKrlJ0bDXDp8OghWJZtqZ4+ixmtLnwN77L8AfRC3SJm5ZWm+bv/MIDOzchoigKsVDaS0FRoI69LAvKpoR6A6gn+h+FA0tV/8K9JtMxVnH1ovxnLb6U+aEZJSwmUNgq+FQpLKD2oSSNpKOyHspVUMiA+SgnB1wEFJtJUjATqezVFsgEJqd19qWHFScOMg5K+CItfI3Yk9nQyyVjBil+fEm+jy+isJsX7+5dr3bB2k0stQzA1snNpX0ZOX0b5utvvvRFxyzf3adY7M6G9oPCzAZb8metS5EedAYr83+mdHR09VSpkmFNvmy8emTH5FCjYstL43LgUOYVfx+4b6O2I/dZO99VIddOM93bYxX3S/FlV9xEDQgaPGqTMY448DqUM9qhB0vxvaWaOEaULPCMwDvWyLfzVsCQdJ3P3KXnvJXCP7jXjCqV8nEPe4MvThlcY36/3C18AjWsR2prgB/N6JyAIgza0iFHl2vxg+DMrJ92BFo4qmFX1CMFQoz2/NtxXmfR73nkKutCcrmK4NSIDk+BMbmx8ujzcRblqMWffY6/fblsam6Vy4kvC9/B8zwLU5I2Y6URvKnqUjXZwXW0m6WCL5FwXXfehp5USWfYcybUzQiKNMoKtZkSrBOP49+rzu+d71xTsJfRavYonnW9NOptJPz7N7q00bXmNtubA2r+zPIWsFhzSeBUsRmKDYRhZtoDyoZmbrKUAwAMiCIThz/oXVToNFUSVCMQ8BxkpDFvpPAfp/imswHLarUDj9RZ7qVqI81IhXO1QVRTtFBjKaQ5OOxf9HejIgCoqgOPajHfv4HsTcgmYCakv4LH7kfBdMcZj94aTjt0wrmOP8RXSHbPDY+euDl1n4aRDJ7Be07mrEgNSGPHQzYlQIP+hF7JSvdQPWS0ZRszgEcNnthyy5Z8PsCDtjMxD55Mgc5wEyZ5OAav4ARPY9b2ASTbF64+j8Xo1csgKtA5+AO/5s2JPiL0WzqQnGTFp8/uos8A21XxY2kRv4OR35J9ucqPF2fKvN8FlumxDohGs6LYY/f81sBXPXLkV/yoa2qcs/2ajHsQzNuoSjIL5/RMsjTO5/Mhro0uDnfalsZqINFhWfCyMuI30chvxfnIv3rWN4v3TVUpCzspikIIJ7bScGgnlSN0bVv+1LUtifzYQystWhvLOaCif2n3pCh2UuRWKJVQJfpea3bEzUKe/m1ynvUFi0YwcgE82Sy5ipy/UIi8jcZyTbvsQApPzxkGSEUax4pZ4RodOcmmsexS0PcssdT/DmUz3cCbTWzmTqYIqBp1c4h5hUs9soMsyPvvILeYD9lGhkg/YR5O6yo1nfk5nwOpl85E1ToBnDyybS1cum7+EbpjdeCykX5KAbCM9zgn8EgD8GjfzBMB2XVSZs7FLiUAaVVXZzzZUVemVoKsdGUjCoHWaq80zfa2V7BpaK3pPa+X9oqQQOtRKCgQbzRpWzoeNit2Xn5aqc0CJ5b9ESbMDIZbPrxZimfjfGGj1lFiuiCqxSMdfdLT7fwozN53KupMBYloRc4CYPgwBJ8uegFVGgnt+veEjLfvlRr1Bvoz+Vp1vzYX6LRR8b0AsIRxR9+QS2HFWmCh7sw4AfFRdoFZM6Isl9lZWalR5cZEAF6H7Kg95JixqwLFil83C3wT2F0phZvKKKfY/EWWEF3/mmUebCaGnjfDK5+L9qJKolB32McEtVzVbA0QDdUTGjAMTYzqOdE2qJKPkSEuAwDmJBi395wiJvgQCSZlyBQSOZv+K8GvhN0hTX7UhyXPK3x+0UWy/SguA6/ywpLlqnTN+eKaytEfkizaA8/JpfUD3VGiq5kYAMEQanWatcPOJs2trF4y08xOX2Fqt7GEgSacIwJDFoiuyTziTNm0HjOZHXSnefaOUlUjkPF5QtfahG887N7/DshWJxvOJHfNLLukX7NvVDtxyQVMI7XJf0v2eUc5RxyzJ5eietQ7hljyrTMiepjTtBrgWF1NU1SWUmj+KJ+5YxsuKCtdIzedtmxILq62xN5falcXxstwvOfJFL06la4Y0wRTyKqfY3PeAx+bkpCU6I5385KUnG55RtO4Qnv37lioRTslvIvIS6aQYyktMMHbjmhE6Go3Q04ZHqFAtroiQuQMs2p/2a4ybo6gXI91Xl/gSGNIqZoiv2UR4mpyks3NxAODipxN06Ru+NForbFAPxGSTJJNBEdl19T+mbpjMFXVhYordY4/YJjx1spbd0E324DP/5AwMgLn0llEy2E16o+qJwAPX0smJxV2OL/tRWItNcuAP3/L4bqUHjc564D/9dH7Cx0TPkDvXGpoQ0BxMF1vOw6bHAGUpW1aem0mhYZPJcrUiGH4YdslEcg6aA+s+cdC9sEk0kQ4NjF0PVyNCcKFvXchh518LdtHbyG/rAdpH4rBRoj+HcHrTRI4okcN5YmflVG+Wz/5s+kbr0tnHzs+e5I4bX9wdKHyclzxw2UMig8SUoUCwuRmnYeILmQELGRVQlHCa2OpP9WbOvuTItD/2y+jrENp3bevQhFgz6x6LzAzPK08LRl6mXwj8EowNC5k8ECqpZF6buiKYG17F53gan+PRgE+VLMEnInw1WBHPegBP1nVruQ0lJU5BjBf2eFvQmVj72tsdjeDNwyPo5r0VETSq2LbfHluqaonyrunppXIyWV6C6gR2dAK6E0hUYU3PRwT3QWJZjF2Lkfy/ITh7eooAgz6d88CChUXYfnq2kRqMt475IA4YsCElHHrIirhVHrPSV2WXV8n5jrOty/k+DezlEvSowV7+EWcvQ6BrRAduJdOsFhSqzzBVWDmZd4HmQXn2xWHFHR747NrU57PNhjmc+tw+UKac2ZEKY5l0hsS1IqMP1UmtLxBcNKLTD/bGhF7XM8l0nFjPWtZO60kAtjWq6QqOITwS6ESolml+TUclXY46ARfwClALKkCAfLrvT+ShV9HjSe/t86QfmV9wQ570c3s86UXiSS8t0dqE7eMsqNIo/iITE51dPDAyOWNjlWHc8daJn6LDlUZXEFTqpUBvYOeSX9Txaxekop2c2xxcwNGDgQ8swE+SSZp/bvEgmwsPBnQQoFsyTK8gUHFswfXN1yIeZ8OkiF1S5nRu6WsRYIghujO2CVZf0M7S5EIBzVDVHsn6F3xmxInH79CLiklnBEZ+DnizH52s2yDIptE03NfkXbC3RpQMbiAlA0fiQgbCOwDag7Z7BrMVIyqcwIvrO7kTwNhki7+3InlWtsAq4/OT+CUnbKpXwaovWaYXp1mHbKUfkzT5eWIkc7lsRuE83vjIxCgpGniFQqBooFa4oMGc7/1WCuYsA+rDPc1Vfnr8ErzNVOyRsRdz1QPwXwZiJWwnUGAe2c5SXxFhBVWMrZkyBy1b9OYHuwU9NmifNrrwQwZCRy+AQj9+1cH4fXRF/P62F7/EHIiA7PzVmgh0rAg3RFLp361QasNfuFDb8oDwAZNp4geVp7xugGUaZ7enMZcJQ5sv58VhgVVQpCeDwLp+YJPZlEIXBNQQ8rZ/MEAOwcXoX+h+tp9mXxVJs2HHReTIXVGxg+PPPYLPINoGRnJ0XOQhdcx1ar4F3EAKvMK3EIjrpHTe/AWz0WpRxugvnkMsewKAhphPeo9wrQxeWuFaaa0QwUDDYfVSED5+cjpwzJ7IrlpGzuAy+hgya4W0V5WkJv3AK5tA3KILP2Krh0fZzf2baWANxdddH1sRh3sRrgSsJJdWkpt3V68k7H0hXUlI1GUCMsHN0EJiGRzWLKHXdDuZRnc+QesoS+vo29GF0t4FQaohSyVUxvjP2IXI/Py8j5I+0ghq+s2HsB8kRvpBhq9RMkWnMWXksG1Ep45eDLdNDLoBx9uUAgYkHcCu8xUw7oArMUxgRyen7XdMnj+ZroBonfEn0Tyxex2rtBu8WxS3k8mSXR0969CxyYSNN+YPGAY2cLQ9c2ThQQszy7/cjPaFTneEL33xDcmmB4rUK57MGM3zO4fDibTgj6TRSqLpTNx3+xagxFvJKqYFvSC8Sfc9wyQuSge9vsRFIZC44AqMEEsQkGrf9YCKJUwFPb1oqU3Cpr7yMr0cX4/NS4l5cKf28nUONfAL9gVyOX5glBMeT0y9uTz76mA93v1uupJGQa4KIhA9n4pXGuU4BD4ccbqW0olBMOKk9px1RtqcnB5P1w/V4d4HPOKGO9EomhuIKOC79UUUjuTnXBCOe5U5jcbjoqsHnt+SqhWyWd+VkJfxisHLrB+LdZRZe6D69BofNQkOxzqqJkEwFbJHDbX9T6ryoqOX9csstsjrrAt3HHvobra2mEnNnnbmrp9niw8+qx0WSDcPKb7et6L4elek+GoeeGi0+ErtPuugaR065xB7ycpC61Gt2TKwjgdCHZPsgI5JTeVovwNMLc6NTu/My3J+J3vJ1utnKNPcoRkKmKQGJu8IYNyP0LfRy5Jih2M3AgcP4YFt5bKkd9EJLk0WEcIYqpSxSWGMQwMp7AYp0N2UAvHLK3X2JeeZYRL14b5AxgrpjOUHD9fKKNccEB4DrYzOYfZLAM5GKu4aCeyufgLrWPx68nOjbjsUyYDumnDDahGNu9aSzXhVKJvxRkgLx/nhWYCf6iHQut8V+wIPkHBS0TnAfC3Gnh4919s2fKvvvrGj2EMh+5uyScEJWDIB+Z42ZmNgI0uRDMYiDfOB6GM4tmdbWW3qrAuPhSFlV2ebFU96aKZcbuT0Moa/JF1/NzBthpOyJ8Y76YgpZLbZbNrW+EPscYS3mGnbwLBlTC3haVXMTkgHatzDFBRgLRGrARkOXw4CZtJKGz5HlPBSxMHPt/I830H7dgtJb7gY/k6X42r8oG5j5pLIWUaJjCRvUeC6k0roxTyAoKGFpJtKk7eC7n1PwLJwNFilczpusY3bRbFI+i/AKZCSA45tWkHiHwNNbkh8sQG9PgUJq/48bdLt/r4w7UusIO/5euz82M2RvAeLphNAnbec9yxS0rO25srrVOhUpo3OxJR90VsvNii9IR03nuAU6PB8KauMNOjZIcFJJEvZaueMg4cnE9lsWuDMEFlJFBIXv/HCmeVfR3RYmn0dlttIh+VWjLjAe8zw7ZYxMlNzM9kbhEK96Scz4VxMGUxm5jJKqVIATkXsvmRdWZZf4uz9Dfjyj6E24am4izauFBm59/lVJrKQgY4XF7rhyuqL3jtOrhmY2nf0EO6jcw+x/4mUhd9ZoyxkF1mdOgwbJ23MVZe/ySVINJKmJEJfzdp5856Dtx1mn9vWrfT69eo/NsqShWIuQwLwAB/orqNrJi1/Tmb0Y/SjIEa3E97jFMRI9DdC73qKZI9tjj/lkSLtuz3S/B5xPlL90VE7zuqhPkkWxSVlmN788Jgu+kE9VaF8PL1cyRVskd0doSnrFuu+UwYmAzsNDy4O0z9HZWJ1audMSxHb420RtGVUIzK9meRVm5lrul9JAKQumUlWyx+74HgZ0ZWGrABkTrQEthn4L8Jhk2RMpAh1GRRXnUT66GWADGgFn7xMsZZgHfI0/kclX7R7KyKjkhFQ0NX/FhFt0QZ44VaV2VbLC526+sEb0Boa7CC119Ma2kLFfyprh3rCVvP3LcyPX9eQ7FEbfX8TukOfRsi9cNNvodDfRuXwEf4X4FzSeYtUh9AWxr4nG0ieEv2Q7/cWP5Pv2rwZ+UmfC8rmdnN2EzDNKweQk/+4msLJYNlxik6FSzaxgy8PUZrTgyjN3/ZQmpkN5eB/sJ1DYHTtDd399PpS8LQUvsaXwkLsmbF3gPw9nL25/siVPWDrgq033D1nS0PX7sUP4NpgX1pjxDu2xWEs+/WpXiEvW3O8+60gJ3gqdChORU7gBXUT26Buov91Hthb/31+RdQ62NQ2qIfaZ3Ws8R+ctgv9m36dU5gopbygynlqUOVUyvlolVOeLOneZ9e5y2lvfxM5+G9Aub0Wu/vlw0wfTzqoUojUBfICRnZiMxqhebZyOr9v5cz8plOVgt9ntWsOBq2phJfPpwS5duiP/uaFvYjgPvvWyp7Rjf0xeiWZrCyx23sRu2J4xNJZc1XE9nF120ySCE5BAJAcJrv3RIbykDzMoH6cPfF50CNkaP3d2s+sFA6D7jSHkbcGwJSEcgqpWwA7B56CcA7gztewl5qnHroUCLf4Cn/URFgFsUWC5rL/UA0qLUfyzkQh1/AOrEvkSvgZ8NNDHhcQlwrJdiYFC+DZlNrEbTLLDIGLxSmqVzJ5uyjB20Vlv13EnkNVZtYyBb+qz1tqrYQOwgeEQmNFoWngcaMUBZFL+ndh74QkqlnFV69gf6B5GqTaoKyi+J0hJtyklUo5gG6zljPlSee/5dhykhAQTXCH/gkIiAOYYr6I6AbC3FAIutxeG4A+jDfEoegrWUOtmQDJEIRwJ3h7AU6Bk4ewQd6/JpB85CwzCiNvRmHkQH4Rivy3fZ5QLcoTwsointAMY8dI74XYQJImBqqU5BJes6opSv6/QKzhBNKPABzOEjlOD/n4KnD4SJO4Qf/SLyifqrZUZ6THDCpwZtDvDSDKEmo8paRH2i3L2bV7ydFhM5i2yGDN0dtxTgf6DrQtRZw/V8SehlHy6vPn5OhBM1HTb6garXjiq9jj589e8ZQjR558xdzcFU8+cuQpV8w+5KQJXJmQhOW7eAdPvUyGjIw9tr5wuNk8NF+tzh9qNg8v1J+60oP2BVul7fwf/7kndP7Yxy8fG3zoy59bweYg9bb7oN7GeG3/cbSt0GAih2a0QXx8T3AI0YMHhTScK9Ax5D95fin0yRwNPHFpqIEzwPZNBUkhTlxfxXCo/bPjQy5k0u/DIYYe2FLLb7sqMyWhHFjb4uxbyrLbsEzLCQ0dTpgz47BqFOzF/HWKIuEU0iq1shqeWKBdF0pQnDRYpVXH4SGhGwZpUFVju4DIQSM0Yu5sTpmhPAVxXFcaQkvckBSftVlS6o4V0g1+sAPoL4oQZIjn8LrHPG3svHPPG5sjVLqkuqi7LT/yIp1qvC/6HswCmyqo4hgFptVmQuEFwHv42cftnXXfE5on52L+YMFHZgw3ho4nrFYGkgRQMz0M/D5+vPfgAHaTtLz+Gk0GWSOWPDvGrsOm23niF+J10HE4B6aEd8b+xm9U+hV5W+Z9xRC1399bB0hQEYiqObIjCFXA+B7bietfDoXB1hNd5HY2KyQXhxpCrxZnoZtwj7iwSIerTEkEZCBgQ2yl6DIvpnRoec4XZq+fy05qSd5Pi8dlL52fy6MotzIgrZhgB88VzDqdlg3ret9Nc7yYLr14qCpjSIs1AJUjUcYr13aRXqnW84F4ThEcD9YmakcT4KOKr/iGUrT0AoS1+JpCnpLI6DvaZfZa0YIwXBJsDsZ6NRj9+JZBZ6wYT5fbI1WFXsH+jaQbcfUNSjfaTpYItPGkkeo4GDd9/5qo8/S5fV2IoXIs/KKFYfMtvF/wfB1KX2MnviNezl3Ar4g9Hxq3HxmiwnIyq0Xhf1naUvRXndJs2HK4fJVQyye3vz742vjOpqP+opUEve6e1ctg1dH+/G0ui9fwBSFuKdTdtwwe++ypK2MvxibRh8+AsXUEc2SyUw4Ofjr0V2gHBOd+oB3QP/fHmWgrkBakDyOMYGoFJC3+WlIXKQVfHiq18XcKdHjmfRkDQuuFBz6Oa3wiOF3oxEezgd0VHPWppKJqwWHvzborjvofs1y5GJ70kISWXTD/FQkabAZ7KAXQQIruAqS4lwbykqtquYSF8Y+l5hOeshe+RY6TVrX48o/Al5MV7ssr8FMeiS1oE+zZ4bkuKr1D/f1DD/Xu2TkTX8W+jPFjdwe+3JsF6DMOoP2Y8/PvxpOyO48JE5hVc66wBLkIVDtCwj008e7PGyMNiBSktdGJSSS1ONBLc7NzpU/wA12OH2O7U3aKR+5+4XdoyR6FWSNpuuDUHbCQR+bT2bkpG/md5KAsBhnAHr+PEwYYCUBbXjcBsHsLQRh+YQuPVwqlApQkHF9JAulns+4rcQyTk/C95dm3ccsbiXzbA0ASg3Vc8kv568APGX7FT7BivQLZ8PCGf19j5Q1NtiQ7/Sted6tZ33aZfoI8DIon8kZUaOIDQ03nnQUMT9kZvVsevuRAAyf9W34z9/zat3MFvMlfcYY8KRr8xUnezg7/S/aUCxtIQ29kYbsn7g38wL17hdvzKq2DX/Sosi5pFq+tddAdG3IN37XGefvxDc7bj/HztvuafsHzQm4J3RdDKKMWpjHanw+IITxohRjC8wfEEGrBAfzCOCXw79B56L8tnADR6azY82KfiH3x1IS+N57ho5hgPBPKwnLvhgGdTd4qGOA3sf5dzV1cgyYcH8rMkx972PzlpTMIh362dioXxlcxtVGhl5nC1GbCLTokQ580RtwqUaTf3T0OtdYcjW7SiH0ouJmwkNizu8LZzbTQ5Oh6AzBGw7SaarkFn3TYvCe0gg5RewkTmHICcGts5uV3Bqunv3Y+s8baed8Ga+e9/tr5AySTLRqtsJp3CBbkBpwi6AUQ3rS1RNJvXVSbZxuFFAQ52XGOoFcTiYbxJ1jjRcw48PnzYIyN76WTYFvaTLXVxX1PzNH3/AD/zq/XuYjCb0UHBfUR5PavpuxtW7c4sLWKw0//pQ2I2k6E1r3QYdRUGkrapuVEPO01L/W/CS/1dNrCpR5Ho2zIpX4fJ/cGlzrUzlI1uryV/EgyaWd1Mo8ER3uUc7S1Hkfb53LjkFcpep6sZz3STyOsktnDKonL9+YSSBMG73mi+9865J7/4NBD/WmXvvxSugw+1Wdl37OalT370CiF+0fdf4QrquRTtA8NUrRfefTHhRnhXBaX+M0/N1f6ZO/m30s3vxSrnbhfnAKybD8kMz4cuzf2L3RoiJF8OzgS+qcIpqbNyBUePUhgORjl6SzSpeH1iDr8nVZQdfCCdu9vK6g5C9zcPpSOW+gn+QCRLgUK1f6ZYdHdEuYiQO/uiy9KbfSPOw5fJEvsbB2GKnp4JhxkB2HLGTlR8Fldz400RvKrTpUl1StWLAfklh5JJ53LWspI3apmzPEq/0tu3IvwdLJ60lb5y0y5OOYA4p+02eNxeICIATsZnYoB1xolI0vcRFLTRHzUStWEQYmIzAuqg65VJMQ3soKUgqzOkhLxtMi6u+QM9i9TcLjkhZ/7Z4V/TMTfScdO5IgJ4EfBIfPWyCGzPJ8uZgABK0F8ISTrMMPJp3YtFRYL3qzA/9I8Z6RH2DmjkhWyWs5Kl7PAlyft3QX6e4m9hQoITCx8ns6TWMJOlXF1EX7nRs7ZiWcDyg5yG0vHNQayTl2Cry5dY3ExFU/J4Puw+tzuucZ+OoFernPwD8dBFaAD8DM4I95BR9DiAJUf4/2m3Cfyg4Q83wlkGvyLaCFgmflS5XM9oZBxQgN4EQnJjut4aGu7i6z38aC3zU+kCGFt9VuVmfBp4GoiGgDLX0Ed0FMAkHY9aReOATwRL+4f7aIEc1dTAipNezTa1DVq8Wk162nsEcCSuSmerRZao+kbYT0kstYZo5lGVz3P0HNu0Dx0pBwcLK+3m1aanhRIZxL62Vm83y14v2rQMnzaKxD7ZF9FABRX4KVIRoCxJyZTcDJSKXAl44e8A4hHylNOQdesccuSIQ2D5QYXExvyc7gp/oTPJeLhR7OwwqXbBmuzXK1ovxj6Hucc9CHlYG/+HlOhT6E5HgISe8FB5Ch2kSe6syQsBT08nBoe1Rv+7hfmFuajjx7VhRsEo+KP9njIKJ42KJzemjxRsEQ5RkTi+UmobBAIG/g9JuCCwibT/CvsWexhP3ZrPGuKnZpPpRIpTyO7GgRYnl2a0Afiy/hX5VK25uvygYpnZW8E5pXtuml8OJd09rK5REEz0uzmQPhATYW6B0hlrYLqdj/cbzCxvwFSIVU3tJz+JFQoliRrQUBSarplwPOh1uGKeyJ6wQJLp58stdUVXyOxWqtKoI9ENQkrGp80iAOmQVcTp5hG2eChsgI9nG8VvMNSuV5BQiv6bSW0YHlbCb9ry4MGIc16vwKM+e/h7/H62DfREwqf8V7kkwucWd/xJX/WZA+QwwCivZeoPH74nJI4LH7ZTSyVyGoMlxjb0gqNvNmz+3HA3pm6csyaxAxPXItQMO5IxChg0NnHsbBWdD+2iQWE1WnJPqOQL7vdc92JTa9YzIjorVL8rR4cRgoYXJ5+DvfpZII5UmAUbXhKEx+qF/AMxBHpdbf3V1OxVli1mvgqTcMG4ZG99df9Rm/p3jh86ZbqRb50B96JL6nvgbKiQEz4rbHvbYu0soFxa8ApHACcsQd4cW2P1XLuBcfstdff7MMGCC3sCw/oWtu1MefFsdYxiwX8zIswXr4YLhSRZfGr0oqrrFhxtbTqacf7K+53/IOG5urnDVtxcZb1sv6Kq6xYcdwA8wdIlp/BXaXcxhxPCgYzB4qzOJiGzA8mDpI7O7PWKwcTGGFuZdIhrg3mhrw8uvlxI3Own08Ybi9+iaTkt8P8PES97JJI3G/tvjYe1zMLA9kGvfLa1VGuzzStSJQfc2i4AedtZ42cd+QAey1XIRjIHWA3Kacz2SRykG+H+QMVxUH2cGTv0aGvUTtW9BW8yuq9pHvmGghxH6ZyNwL3+9hU7ILYC2L/gMNiC0ChFp9d0EdXgIPqXD9kewfCwrZPBPbwrSGJ2JXpZjlrp2wnZyx/OQIgYiPVc4+fl9jG5l+a6O7c3ua/f2vgo0/DsDWTyyTgscdh5QQ8wvCc3bzla4Z1793ePSPE6hhvkx3fhbGvcdvb7Q+m8S8Y8NlOOJaWDD7qRHHtkVAyAGlLc0EPzgl75gCjdtAEk8kfNbDTXFrkgOXgdPDxCB2SJPRVtX05fXeJoMwhix3f1OY/MG8D+vgHOLb/67Zm18HoevmHJOVHXo+CWm/U1eb5TYMaaEDeQEvd7jiZqSwKbk+BVWJuBhaa4v/P3HfAR3ZV5899b17vbd50TdGMtNJq1aXt67LuBtwCBhdswNgG001L6NimhGZMNRBaIPTmkACh90AA44QWTDM2/EPvoViz/+/e96aqzIzKEn6Ld1fSjkbvnHvuKd/5PiNq1CtKKpMzH6xPGAqPUTOw8B8yKwpqKTmTT8+kX+5P+CkzVloiIDQALgHfALGYev9n1xtwn9hvwD3qCmZ+uhaNt1/OaZYtGdOmlBJYPx2VmowsV6eE74JKr58I+GaiTZQfSe/aNZnxlmzAKBA+5dyhnDaqaFBcwipmYUoCdgwloMCkj5xZu3xSpbo/DFjFhWtjAvPyCzATPQr1tDcy+fim5hDQU4eaDdVFOuCmmgZjzeiz1CQUjNOPsWpLt2jwQTkNIt2SB9X1h6fk83rG+GZqT5jKR1s4ijkb3vF5qFQik/AtEJ7hrI9CDhPPXfjiwj5kEDnzx3eileSEgv76wWbhXZPPcP0Z6b0oIq+YUSqjJVnFqrKD3B/BxtULBrppPJmoP9TarSIhwA5iyhq7eqABN3k/yULotGu2ea/OQejhzkEoM95d/LncMRjvGkhXbYvxyOBahU0jLXSy1HRLWFS3ZrTGb9YXLDytNU8ps9637UTdK8YrU2iJDWGU4tu0YzpTGNZojWf10Sr8wTPjVjbjgnlSNxfMw7m2GUXYqn7sG/yFOGinQOm4a7OkOaI4tN70ot4cXtBPdOX7Yj9z13utzXqRHeZeHkiIhPsQEhY6o2gl+jQqKdACC7BtQ25pnIzAlUG6DyE3Q2yKgqE1KJBPU2UwM6s3akRP5df3BFu35E5H4CWgvDpc4ff9ZEn24BiP0jsAmbuzy1RAZItBxGQ0iPDD9hzinmwOMU1240gX0kqpOgJnyGi2tI86g5PNAaPJk121qyTPw4/AkRPgDWb98efGgiSTXYIk3QphSOcmsFxCA2oN6q6vogCkAWXBtuHsekOF06FlwtZm5wbd0RZO+K8HDLgr3+tLAu72FQq7erjzT0lYBw/HK+/amAOcRuvb46v2SYl3btNV21EktLTQpZZ+ZU+xgDhCv9o7frfug2qnV/USzxu0EKgdrTglW0vbpo0Dp2QPFTrLgQvHnIoj2q6rmL72ox26h9+UXcirkFAq0uTemQhx7mUA2VVZ9uXUlNVK8bNq4UjegF4w6MvobjF552pXeHynKzx41c38ndjWz6NCANtyM29xgHX8rN5Y2abB1P/skBs0PrFNcybub4fK2JIMgngBgyBeiGL/NWsAEI/3PbAKgHjBKqzhtccjwj+uF2a4ClKo7Gj4/lQPdJzuq/yCcsclFrAZiDkfe3yUfpfKiEktOdYWrI9i/CLEHzuITTooOoceY62VIzA0HnsdiLSDVKY1rogX4zOM/grLugEaYLk3EAhSM0egpsdykUUof3JA+zjLTT4UBiLlCeayBlW1O5GTVD3UPBlNEdUD17ymJU+UgiBl6JBcW7mF0xTKJSJSQV2Ut6jy+dfxos9uKtV/plTWUMcCdGiizwDAtU2X6M37WxgJJxkPuQB7A5YmWbIUpj2O5uRJgXsZqJwoVt+15Envfrm9lpqu1Myf/SacNR1VdmZC7lSzXATPha2NT8+nXvQ1k2pHU+zfnil75cPon3m2NQFyyptwFagm+qyiBgkxLlMqqTkXpHaKo4mhSOXP2A1rpmU/sPlPi6VaVaY5H7+fTwNCEUgc9veMbNpCrhCJg9+BfW4+cQCwz3dg0tc6I6LUmTwvN48Za1Z2JM5NYV5xTPA71y0OkU3RdXpr8zZ01Vjvex89OSWorLmp/JvjY8c1z92rb2aHzlXjdPkhJy7sM+1wH8T1WoSbdBVjSMZNPtquCXYdXK/eupxWyb9kubCHQT7Lnav1qtxMncEKYLVzZ3McZPRvbVFnmrsmJy2DPLKLPPP+/ckzV54SYdJYGYZE3kIZJlD+lKgMYwa+nYd2L/ihnp74YKeBh7Zvpy0Xe2w5E8vGLXca0+n0CITqqreZbCwyNwJlbRhr79rQtlmTdNGptjwD3GtTyU3mZLHx69ZAtv/btqmxy0jO6La1n8vSEe29u5Tl3ttyFyWTyyqHG1/bZLaG2F0B0PROxuNAsy8APxcZKpS1I6lGRoqChCWq2h7bnEViZEpjLX7eGGJM5ntaoes2Qre1DYrbgzZBr2A66JC49OsFhxLP8AotjMXQMCgOV/Zy4DUFrwGAozgRvMrh+Z7VeFCr+RnuDddqfdKm8pqNz/M6Gp9v7mx8PnONxme416VtT+4wpGPG8Y1lE6vcBu+NFTRHXvknXhVARowdMo6zISIy7v8u+mEAWLdkywNyTQX4i7yR0y2n1e2kc5PeZmcka7/ZZufezmbnXRh+q8jKH0HF8LYl19p29PHWcu//1w9mfMegMOOhk+q72xjip/dgiLOFNMMQv2AIDHHUSwH0X2W9FCaodvx6KcvDWGyAVspVg7RS/mYrln/swPjxexz/XsrTNlTSe0+n4a9oXN9PTQ3nmPsN/GIZnZS3J766irXjIAEDb1/eDv54u0mbrGMDEfaHKUfu/YB7H16TxuOlq2g83nt8PObFnVLs5enl6XKHFPvc6RecNpvuYPI4xyqkLdLi8hhF9jja5vK4vMnl8eDtdKFPdbrQeY1XxlweHVLsEcdH3JtJs1vgeYl/+7/Rmzlu10Pj19vUmnnijl0j29WbIe8aIuaw7YLvsqBCWzPPYkz9O9CaGSZerOrM3HtVZ+aRa/jCl/95bV/419gX/rPpC9cMasLkdrdmhroNbl6l0Fg/dhuPUWpiju14f5haarkqNrNqJNysJ8PyMsafwxSiad8ktuPWx2a1YdeGYEvGGEMvgJgL5u+nsUNqoqp1Idohfx+Zu2EXIG7Bc6+2RqtZIamHI5bnT5/38MOHH37eDDm0lfEZ0QZeELqpNHfCSOnQTLE4c6g0csJc6eQ9OZQWtuOMcEQHSy06eFZat/QksNtOyhCIUU3XdqehvbibnDDcUM0ZeBeo8RxDBxzEoGsp4JtGGB/DXihVaXgUYPhfZmE8gkVSmpgCa5QdaAFiKECpSje2xpoqikvIIg/GeWSrQsMHlurRbRzXaZEZ55uAuFRUqFGArwS/mWez7znGDBR9H1pYAnrKisJoKzheayOEVgVFIsIpm6Un3VxqUuHSJVWKyVlmrkOeDCU/OTScin8Y+ElBeInqKqoHUm0et0nFuKRYAjwS275IH2M0SCH/aNDwMApgVH6CK17H63LW5rjQQfgeOVg84rmuwVMBRnIqny08yPPAV6NZGVoqRlSYqmGDUENc9KuQ6BBUlVwpYqwbygyBAp4OoHEEynGLtQpOZLWcS14IuC1IWTnFeHnSQOmI4k0p667L/hHaElhtwSkO94Qu1DcgPooSDp9AE1KFDGNoAydDO5EcX0k5WYHGHTEjGvjuosK/MLv/7dkJnjzRnYRCIxU4DybC/GKhccQIRKem6aJp1JxXsfaD7IKLhCvsmrLvcc/GNXpWT/mmwtNng+UqDc0s0RS5J6Fwxi/NRoNgAoK8P0Jj8JmJW9E16i7wuaXl/VxqdYlPoeBttBNzD+outMpPbbrKR94qkvV3lw/SwMSaE3HJQ/MLLDJHPtP6GFk+yC19tY15cmwH9PlTu53u0l/BVhY2fUD8H5X/APczVGtU/F8M1Gmz+H91Z/H/RBT/gdVT/I9iV0NRQS0HORfD4zL5jt1mRIFzw4zAo6BHfLLwKlmZnO0VBSn6gLYMYNwezsVh0NOmGAhRvs+htYPcMMAtLigk5trlRFP29KI59fBpd8oyDXpT8Ur2cFarKJArgvvJud0iLfxFFP4iLfz3WKWzS+XDsKccvfCFnVvP72ltPeccpTqxyzQ1xFB006JdafoP3KNjdK8APwg+alMcFxLZkVzACEZ+yCP6sJr0XYnbjut8n20ldicJVWCr4jQCCUVFjDbf4r+384tBStRH73iJegyb4JxkYJ/At3QRe5C8VS1nMXBAJAmSgOMJVq2cE3lqBHwEe4MZha4vgnt5xC2t3PVXwAA8S0oFLtf4N2JAcUrRJQNo9wJmHohfIxBNZgnMFHi8VcFGeqzZbMFNKcmyLVNWopWH9KtlF1DLHoM/LSUuBhnptweqZVm4SEmtSrY2SGVZE9GfWsNd6qu9JVp/Bc/+Njgt9/gNC1oN361ETdzkpbypb6lJ3p4fXdtxor/3uI0Kp8s2fj50puyY32n6bZ/iNit7eMukPLHnHnFt+4L1ys+PcSNFP3KfVNN9TqDuQ9cTe53Hj3zvK1gOHs5rEZ8WUOTm4Fa0yL31/0aRu4XoddtW6pzGT7an5uXULYWvvx5I4f1bi2EsSH0XjfMEq41fnXjPDsEWNu8gq0rlh64qla/cigtt7eK6ZtuhDVu9lZ66CuywCzLRd/NG4p8Sn9uOWgp3FjggB6ulDpB+5AuHIqmQJlUDVmEAx6AXVCR4toqUgTx10+UTdY6NqyfxjHUpGERykeJR6laFUjWccS9Y4YnwAhUyG5iAxbQM4AR1KS3DC1qV08v6Vk6z7crJK3mUFUreqHI664rVzAyVR3UyMzyNSl1Y7gilcXgO0cb/fNabTjuWyM4EBuZ1fETY8OAOwoYEidfe/wct9/5L7+FYtTcYwDLLFNYssqKn1WRhxTNziYgnK261lINyC6jBduOR0aQgmNBnrf2yB5GrIoAyQy5QhLIQSuSBjZsAUBYNMTBoDiKMaoAnV+3phcXUF5yKnTbxtGUKUn4seZ7iyAA7C4YLtPM7CMaNu0K3su7WOsddSrh6VhnfXZfTek6jCrQX0J0fL8y6LnMtQZpOXSdn80yf5xzQ1Tv+KCTpLqVvkG2i3woBcCdxAyguEqS94bmmjHCLzybKCCN2E8ZJhoRv4TBZYPyhE9xYzxeyV2CCKxGAPBXVJWWp+ZTZQ441hqX+C+jMoExqGPRka2sNX0PtUKAgI8Xck6qqMyeccXSf7fq2DTgAdw9j/xnnnbXfZMw2NkhPIFdvqwhPiqOMXDZFnPklhC/FGnMai4R8Q3bkmCVH+2okP1zvs3rOIyxi9/waVHGCrnSth6ej9fAl/PO0u2Bq42hTsSvBsOhb4xRZgVyeTXXqotS9XD9DSYcguaZM4oYzhgVRqh9+czY8uO5qOQhNsVtOzfsLZt7rMajqJxJ9XKzr9ZeP2VBDeoftWhxESubqdXf+923JqFQf/E8backwg34TKki/w8bd09jG3fpRq7XaMWAMhFhcM6ESqYVjJvKYOGZskW3GVepNjUjunK7QdTl5XWfoajx0jTj4+MZT14uDODTVoleZnrchtFrYDwIRtHcjzUe6xFZamJ0rhhM6FCKlNGQwud+xuHZRM65NtOIaC4dQRmqFw8mucNgAWSCayJHe48h0luo9xnKPpxLdd+qAkfAxQcf/cr/FY37uTj7m3me86qFLO//A6ZoMbvaOp31dz9M/t/PJ/3azT95pP/n8bLrjwZ9MRnZnu/7eaYgE6N+4uyLVLw+9ozWffZT/jS10bjD15v0t7rWIEKm8wbb4V/KX7KHs8TQ6gNKKkqPdlz1ePkrd96QCyo52TeNaJPAeMiuRZu/YmnTpw3zx/AKbf4BA4EFXrL3//Qoq/HUVtVXa8WsyTb/HcItP1mXO59E+xmk/Fa0w2nfE0+PJzPi1cr6YQTOn8ch+al+I9n+T+DvoCDdF0lqPCS3+haY2QBmyTzSmV7t46jYO6NTvvW2T/+Le1oy9jeWuoE4e0wznjQua7HP9YvnXQZK/XSpgnBYHZBbMgSwWscSLeM6BC2udWH6qEgSwPak17rNVLbD/5h3eBnDwGZgtblEHOspsu1+iZWRa9pY7XoO2jumadUdxjCu8Za35uVRb+Gmm0iEHvZTibtmS8pNnHjz1aPjbljec0+ENkykUFeQNjQXsNIOC0JCEqoZ+w8KBfeEf2QvUtMY9L7PL7vKVh05+7ulCMI5hpOdMBSsfdlJpJIemUXCGUnsi/8tu7dZXO+Nm9PXlaJMPUDb61UfZV/9TbDkiCjkjsHRKZAdFaEwRKEdwS+ypdSQ/uzOHkgw2AxjsXA7Sq9/us7vyLwPISXEzAxzexq6+QlBbOd8rd/RVkXrThme88bWNNaFi6R/mMde1kvbt9pehKD7+KtG88ckhqTzO3unIfsdw/Bzv3TjUc4kMAAQ/5O7GCPjtzREwpr4Dgryj6W8T5J2itVo8iR1yAByPgAcUrvm4Gk00B4B2R7PdNrT7YjFIpcR1WS1657taEWwVdMLLZTYWtmFC4bYkevBRNsmlEO7uQW78v3iQm1pcWky7u6JRLuzRd5Z7enOWy36a36/WwLlHtwbO9bEGTgGUw3dhxk/h3jdu08ItagfQu7Z5LVqtEak8NtPk5qv1kWYh/7aVKerLipBRXmdNh7FZWIQBwLmHbqTOMuw44lEoCtL6talUm78ipLAx+rK04VFPmcKLNpZnYSb5IfcrMFacidj6+qjRPMmzPkh97FByYTk2ySRpHR92CA7wtEIoNLWgqCGDAxzrlLFOMuUBFts51mJzx25psV2RxPvSOH0Fjvaza3G9AaNR+viYrZ+x4QTkQ6jZMt/aPRVCARPIrLQRaneO/FByRcekZFDJrAOshKN9MTdmjuD4WYYuutKP7vS8IGf9EYcEFYXgQjVc5Bp6UNIMhZFEYXEFXaEkJ6PpTtc1yHT+TPJgLND5jpPzDHpELEvz5QyY3s/AmUtCNRpbD6PljJLRTMpeeggnP4TrizAR1L60VO1qvGYoU0QVlwMr7P9ipw8CCeOIZ0CCiKJjzI875ZyDnT4OVP/0bElJme7O4NeuKY78EawKjoND7WVBKy2PEtkol7ISznHZryB/ohb7Hxwiind4Hh39HD+8Q99jNECidNGOgxoIv9ExW/nG8QctFPuoJN3Sj6mgcOwbGAbRwHlt4hXbtCczzGIcFu26Tb+GoBj5DIx2R4/RvvWxtY32ydho3/1FbLTvD7MBV9hb++N2htLGz4bZaktJhYu7DBrs3b9KbYynAzz+dDCBTULrkBI5oRydpQPaiH+6pW217EToVI5yem1EGIbdpb6EYT1KViynjfQrFw9S8dTI0JOY3tEXxwolsA7gLyyNA1OYRH95ZCRL3q/UxquySSdeslrZNemW9kFLZB3qrw2Jv5rUXx9BXLxET6ta/MFQJH+DFXT86ZeouOtWQyBBvqjqJuICJPnKp1fJVXx1atr2XTTRGnesQ+Kll6tloy+NFzYasTa9NyLyatwm05STF0X01QzP9YxfGwA1y57CgR7OCwIRAbYaM3AdSTwMS2lfhOlEiITH9qKbxgwUSn9rHZB4XMaJ9P6j1G74xSxVF3aGe0uYiJZjC0TEwHbGj9ntaeWRYm9okZ5R2jDFtyEXSrN752TiVkuRhBwNt9CQswQfiiV3pGY9YIdjcB+vWHp2H6kNyM7loRSIqATqnVQCFG8odJDF/FIB3lOh2WVSkEddkq3kcLXJYiQKjnfjKuR8mkXrujFeA+2dlnfcqlniKe7YjBYiJV3Jl8pYobWX4YpGxtQgepnUyKU7QOW1F1e54HMT4OjXkUuLTLEFAETEGi8NzQhUaRrPXOVO8H014CpXJl5Kpeq34ir89jJ91XbWRZ47BBOY28EEVmwygXmwUJMJbOVHAzjIeZt0kMaL+9CG/fCqTtqwni34azppw94/kF+I8IvPMG4x6hcvgLrKXYlfbc034uubNegRRGC4AzSbZt1N/AdfT+eJ/EDkYSRuWPOz1R6Py0cNEOpy/FDeQ4GN9QredmoTsebaXCZ7ZCS9u+yFUjgyEp45kkqNnEv/JGO5oB/NWOM5CEi0yy0CD/KyiQORU2aiDdtW2LpxAP8ynEx5rDy+6UDU+FNx2fN0MRmWJ7NTIwXfL6BcyDg6/ZNVJ08ehLCs8bdRyJIwzMiGrwjCVkgT8iXmtlx1ECdceQOf9tOZdKYQsjj1jdgfrwfrxre26IvbwZQ3kKfucAgjp7VY9PatwaL31sY91mXR+1CTRW+ay/fz0JXvDeB8V/Y6XV5LreV0Wq/TfW5Ymr0PX7SmG57W5YY3RT6WWtvH9DjQCVTVOM6VHgtSnv9M/GlrruV1Q62b7YKNloa9HUub+EFA3MN73S+Vwxfc//xDa8Kvnwf8YPc+8SMH5eP7U38nO70TyV2aWpgqtZHc3PRp5546vfnY99IORPbZhVmuhcfOIiEouqnmsvH9YkA29wmCCN+dj913a/nYyt3r7hjTCHh77KiUVvfWrbnpsCx/Q1L87XBy/5sh+WYK+6r/vo1euGkfu3lI9pmUUlyLJnCrWT8Net+Nfel8dE3fk/j0FkvEXuj2dvpKFK1iV1klbTu07zR+0qtZzj19y74R1fPMN7ReifJNe8u3eyDd3IO2xRV0LM42483KqkXoKhahL2We8cLExxM/33qexXq4NMgIY2as/dDZho9w94vV1miLInrgOdjzqBaF/0tBh5zul2xFFCyjfLQg5kfHRgtScmJugneqrjvuGSGdRyVzFjo2HnwDouyv920TcrR+GtR25GPuaBFFmZ+v2tdzudpkLT8zqNvtZO+hcbfimXKYcnnJNnnLT/kWz4EOjVMc4HAF3sEXCzZInYB2d1Wi6hrdf7VNf5zqrfluKk17Yvh3mA5ctP2hik/sBf7J4pXErsSlwM8Atxeu04JkQhPM1mRoYsWNuowiXJDs1axcFV8ITUMxl0uRG+WRSlGCbBmPKYhSqI7auXqW/HpQzkTgCZSDmMooEVEW5wlk0cd/uF+RVHnUakgkyBVU3aDtxMArnVIlD+HLu6ctz6U+ufKQJh3i7/7cpkM82kmHeMMXO+kQG/eSLca0KBZo09Dx9N/ruhrKnswZpuDi3OJOKIKs4o+gvfMwSbsx8abEF9ZYyYmOdXWIkBBuAwfeqqAfHeGxtc77PGD98IOFi1dt65zISzjGyzmJLivQc59Zde61V6em2bm/ZfNceCOrtM3/NTqiy4rRPsW2e9CXaHhZtbdzoZZOe0kKZWXneayWIyWzimpKDXrP80jJ/Ok2cOK9pEfq/Efs6HHR+SwB+lmMzycI0uqT4ziTRcAcfoEzOZE4l07Ba12HkUqlxqdxLh7ewINYyT1HQRDrd/NDIRbWpagHLH0sDqbBjaWgBZxm8p3WAOBLykipIFMRa47uWBSKFfdBUqjsK42nlMaX0MuXLEWpK90N/XulfVb5fhyY7eqIxuS27aK3odL2dV1tf7uQL7jkZncknzUBXyCp0el044ic5dZp2BummjW+TREP03XI79KpwKnZ+W497besqaetjpSLWEKINZD/F5QVRxif2We3mMcNBkUYgnBmuP7H+UPfydkBgQvkOwMTU12wg7ftgwdAPNy9IaHdh7qYbF46YJe/iCaHvm1esu38hDvtJde02vkNsiaD4Tf/T3hHx57I43vYDsNMMADb4bWdzvH2wZ3j29wKuI+OALb2gcSPt7W1umn99DgEDUSFBAqcdTwIWMq1POgMac/C9Hoe9M21POjylqL6vs0rqleirEJSpIzYhzKJZnnf7XE1Awws5va1Xb84nMb6ZXGmgTuwYl6zEbNScXF+4Uuru69r9F6LAAL9hZFxXpF4SeITGDINCAXytuChyzsVmPgBsEMPGwA79O1h49uftjN6PWMbwEUP22QAfOl2X30r/68fLql47Geg/OKRyD4aXClxeRmVh332x6vBhjXo2mvkMehWrPWtOItRxXnSBpvhJ/UpR3+MJfGsYdkioUvi8IJ8hK/l+9WfH/zq6mXv3Vd2Lnv/8iMbV6j5jqXvszuWvkPh7Jee9qvszA2DFaRoAAiJywAZeyXkbUCM1EOPv0hXxKXhi1KJHfrFdvMIq/+kt9Y9SJrQsGZR2iw9wE5wMLnEb6Ys5R6AOwB0WaocAQpSZgWRf/DCFCxvQtXG6dWKI7aUxFb/yl96K11uHg0lNCJyKgVrQ7hcUmQIQEJflCfF4apTcluP6H3SOGeo+rQi0gvmwawsTXpRVbpy26rGppZSHQMHHRVqWYgrVFCPJ1Uxf/IIKc/tm6us3Dp0mToCQrYfo6NxH+zVvgDO04cSbSxYD9eGJGWJlbEFEhHVoNqM61luaX6jgvYgMiC8MKVY465Yh9bswa7Rqlw/2gtdO1+qRHUrkPVirlo1Goej+jXph57QXcFeGlewnyYPcnRJkkvVMvfszmLy3Z00ZROz06Zw1ga4NY4VsGfHQDhSXmzs7lPL3m7tK3P8E5MsxsZlBweOlyOM2Ozbx6Ps2AIlkLDDVcgD+vGok8dtjczsZ8enNnlCb22SZbUJ9/dSvpDmGv/UySAz28Mgc+L6DDJPGnB2Ra8FjtWy57Na9r+3eXYVv0q8JUAowxlDOGIpCxyOcIJ6/JIMNBw4WIshLcEHfshadtUdMrRbNf64Kv5zEt1vYjLSnKsnQx3vgX1INkKbOJg4ELSn5ZSacSWwpCUVVfJlmiJS9xuowp3qvUa2bchFTuVEVUmalpnUHCo6o47QDxiFDBVJV9PpABw1hPcVWjM1fpAtjaAi0SAs5Hqu8OuBcsLVQ6/isa/yCnOplye+TeTjPvSKrhCWHs63h1/8ljyRjO10V2Xz87DbUDNoE9js497Qnoq9MpqKnbVZ5x20O7PpgvmHsmfIqZSDSZnBWx4mXjyXzqcxKRPppMzWQWNre7LqKAomZUo0KTNNf4xz0qZva+o46Btk1w3SKtWbxwsY5KRhvP0OP5OJvF1La78eCN8UkS2kuZ9gejYYyxIlpxCjvYwlestGtySbyRb5uEtD3RnMPVxI2V/C1BKPhcTDXJ0eEPzD6kyFfUmA4wHml43ple5zMQig9ezBTHZSEOiPgOV+qz425qC6CUtllpoQIItMZ8kNJoJ8wOUnxsazbuXteMgiNiWUbObTFla+DTBrOalQeen6vErPoquBHBfk8/Ozc4VTjRKWkiTqLQLOyUgpQz4BaiwzL1G6rOfQNjLByhLk2gxTvMAOAbPF8+Vc4wZdS5JoqZf7NZY9H5B4fuKf+zLxMNQr1m3HKoudDQ7WyEKjCk9qP2mhcoJms2MSC0nB4CRKtM701mlDULW3VidiQz4ecrXqqUZR45utCjNv4hR/NJNL5TLY7fXGkWARNgqjXYu09lE8mEEYlBjm/lxYQqUNBuxgAK+DFB61cla5iJ+YneCDiZRC11GfH9HxpFp0PH6Tjmc/O95yswexj/YghGS028s6EeFC6I/7zVaEOeqQt2bDo+uyKtVCYOsf2d0myLfbBExo2T/2H7Gl3534+nGwNE9vDwTxRdZCGMNrjDHSmMME8L0llvHSoB50XCY0D06JYbwCjsVwrH+Tv54nfFLJmylLF8yyZ1J1L1TQ55UgqmYXx1xztDZqBjmwZyiubKZBbIVjpQauiWeZFIRAOmx46IsWq/pljVcfd2dpXKxYaMViCQ+k5EnTC7T7mgAAOqV0WqHceKqbDx6MlTDVla0RLIDZuJaoHF1o6r52Lzv0nLSW1B4GtsA+LoXgAVKQS6DY+en+NF6bcqgmPdeWCEe27ENXDelCH45Yu7wt8Y+UBvGbW6jfuF2cX7nIbw52es3caq+ZanmNWTZI4ymDU5FwhzboSEbcInGoeTZw7v95HILNYEQjywM0t/+KN8/KhwZorF/Qt7VdOP7h5rJ+5CN/uyG5CPn1AHGG+dONGO7tvDcJQ9CQ8H89f2ncOhwVyZOPu2O8bjhqErjJBn5A48qdsR88LvHaxC3HI670NFZWR4eFpYX6Knt3tUTorsIOBYy3LFz4+KNHH3/fhYX70t8vXHjBahPz/CobP7m679RK5ehSubx0tFI5dV+VPGNQqx9dbfUjq8LBDycWcoqQWZyeXsiAfneBc7vsmrRtK9my7IjY8G3kUciubNNBH1F02JH/L8ZzOJO4HIvbdNV+rZqOrFnThUPxRdY2qPvIL9wTTzvRxe3ZUdkVzyqjrvMLxY66bgp13YvWZIqcbTJFzk7NdDJFglF37dqPXMGeU1TjjWRH4hrPElsV3jPbFd65nayRJ3eSFd6vRVZ4a7P+S3XUf6e36r9v82UcqSeBZhcLabXOLH0pNUJ3f6i8C45QvdriVsNTKzdPTrwgTwkPcGxgEdoDwgYkLfHEVKtrRNN/phRDAVnLVSRnrU9Cp3io88lSwPUv8+6D6MCtDjeT9sJBQNv2XDjhTNmgbbc9QwInAqNAPGgVTTOnabxDaRCFuUvmCWAQ2f2FIO/IzB7Yox7zMlh0ALklpVVJAlWJTIkeDkHUJlOsQrhp4CPcOIed+QsGCMmXx6l7RqX/2i7pFLbHoa3ja4HB2BZFVfZ1K01pLzkg49lYi1ecfJDSBfCxeIBVOp4gpcKTzCxbxlRsQ4OO1nmG77q6z0clAvngQKEdH3pyvzD9C+ZTi4mrMLJ6P0ikNmNfMD+B0CYw+Wo0rYzmWet6YNif/3Ggq/opw5qQK81dMA8zWn6oFsvo6odnn3dWsJ5zTUsDsEE+cZCL+nuDWutfEUkmoE2vC1y2iI8z8aC13eejG5JE9s/S+DKqwatxN392OIpI+rGFviZGDK/CT7pKu50LHdyHhirezPKeQ7u48Mx7nu6vH1hmHwhPublV4B3ZiXDRn1LSDJwNfIBwVmi2WSc/P1AFuToodNeEArzjG8w7HgyhjC8kfk1MIPOD+RYLdwtQF3lJuNi9ugzoAdVUGdBDTAqoY9iVTbmHgP7BUkwAk2fShHFuUW1+7/pie4oyUIOKtDJFJKp0rM75UVzaT7775ub68xPj7efm+vO1z+1der5eBlaFDOJkwmiA1L9s3jqsiwG/lB3Jo3Pl+ia79+hnDe2ZeslQMcyFTrlhmS4A6AOEqBeoTJSM14FmQG1KfQPrqOChuGS6c116zoy3pbt3peE6nr6ho3o5307xZ1FwH17pNYN66nfYh5War5UqJQ2fwFyXCVwo7AVcvTpa1W1PAhnkxRs49conaS4LFguAJREZ+Fwpn2RlLq7AEtIqA7Cfg4lHQjIVvTGPTt+W214DNAYDf7IR3HI8hYuWVuE4rakdaU79D5AeDFYEwYqEPtiSyewiza9qTRZMjiFS2yeDVkiI07TjDu/0xDo9c+yfB1JrrBbN1Ciu8FDMjXPP5ghNy7i1fBieWLYVLQkQf+mgJlEuH8nVRqo1YG8OLzcHb9QYt7QEP0a0R8XyHjFyC5gsk0K6KGeiPbmr1LgEqgG6jiOLPOdmP2cpkmm6da9QCjyHjOY131b5saOvFw3ZU832aKzqPRS9V8lgxJUYyKsC+ZV7oFCuI7NzRcvg441G+j+/mhqt1tOlswqY2sOJMDoDKxwUvwXNs9wclfv4McrlUNKSrh1Mhee87rQ/h9MZA+UQF7EpyuTVRDH0MDDhhknIHukW4xnHI3hdYQLeb4TeWxBcb6EfoUOt8RZkNInMUDGU0xSdUu8KoKT6Mk5kGpPay5AffSTxpS3yKdONpibeB1TjC0vBQjxvpWEz8GjKHVOTLcyNdbuR48ceVEd6XqnXOoLrbG2J0Y83vSdypOgLUBDUK2BgpYVYJIYDclDuP1o35r7uG/PwNW94dKPY2+4s7znpsuta7c4ZsqRlpyofo9gxCayXeI6yAgGxjPtbzGPhThpEQuFNkArhZXBggdSDUl8KslaBCpUkWKADbJyPMAglTjHwLHKVN2HaWafmF3PY8BMzerkUwhpWzrQ8gvQ97TwbuEKrPkTf8/J0ERNOEGyp2RQBlJAIOQrtxKtWa42H4ROWrmbgTCsQ12zhBadSjduyjmqqyMkxwiPXYjoLFVGgm0B2yCGcejlNYiQpzsicLfGSo1t7cng7t4M+y5EV8DdHRGZf5+7gxcR44pzEEyjIcyMSMwr2mieDcafW1kCBLfaCwMizKX6rBfH6WC/E6wJAvMiNGzOirnyRor4EJZnOhj2or6sxb6De8jO2bpTZENC1ctZqptNLu5lO33D6rxX3IZ1AL2f36Q87twvnxaSt7+R+B9zsEfSp37ZVPhahHtHHRVGXPXh0GeiBZvc9SxJouAftbRzB44Slgv5zU+12aawfuaMw1JLA+cMuCTR+Bo+U0lmfJ58P6r7jEXiZvctAV+ctou87gGVTXVksEgTa+z37WRkw4oKu2LJrKe1offdC41uyLJmCrTBC4WdvSAH5l4F2AzYLyvlQMOOriL+8LKVcJ43LHIhy3vUd9uLwDECD9Yzvi7GcKifUzNRc6k8bk0TOr0bnrLGNMn7sq9xPmGM9MPHixDe25li1vpyPw/lE73JL/CY2oA1atd0ytFuRx2zoCXcP5AkPau2vnBzvr2Ay0txfeV3j3u39FUPqWl95T/OO2bdp4Mx8N9VkZaQcrOkYGy2LrLyzY1vlFNGB4rfJZHbobRN2cARdbIZYVxlnjvSN2JFetg1rTXMpll+WmyTCjKQ71iCJ8tCl5sCDMbdTj8I9wsBWnXGtTn3HitHD5K8bsMjBoIad7nxJb1wajKXBGSUQSv2k5aZSGMV/duGSRX10dESCGmR+Id94I5YxFCivS3bGoU1aQ8tjQUAVHS27GDRehCQS1QYyVJncsQ0eu2mY1mf8LEtUCVd1s/NZr+Y5FbPIPEUzHOiQ0zfEy2nG7oPe/ThNxpFNlNizuag7hp05MbSrIt/YB6qei0Gcuh856qsi4Hm0QyI1gedR5hGnFvGnkVX4WIifj1TjhW0mUh2T8K/wi1zF6Zl0YOsGy8ZQaskeSAxvS0+6hiFIVtqdYxkd90Y8jddshTW1cQV5J/cMdXQ0q8m75ubsxo18bXrWkixelgVONtWRItCAmlkpeJOosDlp+eA0gYkd4axt5Et93w+IVhotqzLI5ySEhRlwo54AgpN5TEdejNQl0SQ1YGs9gFQRUIbHizz00B7glmJphujRejtEh4p4guYHxYSi84GVGz+qcMmtmu0r2dHM8sOW7EBPkrijLmXzORmmeLpR5TjN0up4Whz/tgFJTwcjHmlQjULuCtvUcwpNSaBeqz2ePF71LYyp6cgqKJYNFEyLgVEsFjTD5lUjd1opVfGcSQRhWR6x3aBx8Q6wm65g8ckMTNau55yyo8lReTiD3kFk3AclnpX4l8SXhzbv8jBGI90jnwiW1Z7NLNOhGz8W4bPWn+3URX5bjP/nQc163040VuGcQpBjwnbtWcyfnawZDWl4ORlk02L2tDWnOZbypW3wEGcoy3+ha6SjAI31yK5RzONo9kynNJZhiAq98OJ5Dvb3Ouc5l0XznPyankTDxF38IagKzCcuSjyH6QoM50dke6lwtyc8NP4yBOWt00F5W2hS3tIF0yblbePp22D8lbP7UNv+9KJOatszuwlOHtRJbZvewJRRUHgK8JufG96Um6pOaUexpz79K1wIjUe1atLv9NSkN/XWpB/17Bs7alIhUx739iw3bu2sSp9zXK8Osrk6lKtv/S5JJiqYuhyF25yCzeBXQsS6o9G4BdZYn1UIE/EshO6Y1mO/own/fKffCQMxzArYZa+KLOVDvcG1JiLNyVsXIewtjZPXJYT9dJMQtkYyVS9Tzy49cKlUok/FgG9l4QX0td6r2tS1VBjV6EtsfA3H3RJZP6XtGZbl9Vq/TFtiZE82WN6/N8iOh8xLzLxlBc5y7CYYzDifGYSVWLXHXFSN7UThhywm1BL3hRrou+jQdUARkp1MJwbBWK4TFs4aRJTkb3cinVj5Xl9Y5fvXCAb9WQRu3Mk04l0bEgOQ89ZNMKO7ZBGj+ptBkPjNREIYnvGX30knGoTzdz0v4u6pHLn3A+59eE1q35etovZ97o6kp5VOkt/yzNJMuYPkd/aM80+fffQa/pQekr4XE9YddK9PrkfkS2no1vGs7zLP8hKnYUbxvMQ/rk+/txNus4rNYL2a5IRVxHov2gkveFzvhukf1rD5KvK82Z206ad6CAguWNOSfGIJdwu6Kol7A67xOoyvfZoWUh68JQyxlxcjdju2rxPSp0obCU48jo7/09Iqi4nunOZQMv53VO6PRLqRDhU4a7FY4OUod0lUSSxH2Wj8HfJNVmfKXJKPm5EkmB/7ANAIqpxW8+gOIhXkTT2rGLIh0glb0uEkXgTBIfpAuvQKM0WRrjqYCCLxPey4SHIqE0qw3SkQDMMX67KXgfw0XVHnTsILKKavIewx9UWADgqaJZ2EbfbQChtveyJHvqOz/XVOkj+oOqqng2FI8f2cnsE2jdy4fuRU0PgBjqDwNLkDXhTTSwvWAJaDY2wStijrggLSUksypJXHggUCcAzucs8wTE3kbclU1RQ6ePoHfol5t2foGCM6Y1A300F+snK3XjCNrA3F5eXwD7/VQ8MvCbxKLv3Cl2DFk499B/ALBT28Z2C/b4geHu0NYSB4hDA2Qz5mM0RxsEhRLMNxGgpjOHmsa/fowbp2wsTiHO59w8wBM+CCj5KxGFadCBWyPpFh49cgmiZDdesWDu3TOX7Ph+gLmKmSF/fpoDAHJm5jQB5DejYF/cNfIcHhoNmhO4o7Nodt7HnsrD4fRKRD12vbzk+3bi125zChDwDoPgQQg9PQ/XKt8uoZ7ejnZor9S+9PtCGLf9/D6VAo5wbgm3t2JyPTy2fWKaROYIAeLXEyAD1vTLx3VSG1CY44b4gyirTvvIHZ5Lprqq9tA/lbY6CSKsNaL6ZnGf354RqP7aiu5oYjc3vkoLVV4+dx92UQ0rd6Z41F78E7eI830HV5LZWPG+QeDAbj3Rr+styYjavfNXjGBiRcZwx+R3Jng5DLMSxX43sJuV7f7y585LdXU3JVHtVJyfWnZw95Wz6xg6Prsm6Ortee9ufsDDmAizCZ2I/jC98D+vRtia8kvr82CVd9LGgGaQanWR2lMbGE5XGvdZzNAlmITdXNxeVtnUSyH3sXNp5w1lEgUQagQ4S7pIeXyxmHc7PovjeTS9thrpTuiu7A77gjnIFD1o7vCNw95FyPaEWO6dWR458bJ60fOT7djBw18pH16bwaV3IjaU4TU5kMPXQ/6mLruhz87EnxCfGlwN78XDbYf/hAYPi+F10Kqb0IRxp+ZMUZZ4e+aLn+1bjnqTJsL2/X84YKMtwTulm9PtPD6lWcWtgz8lJEsv2aCzCYPc6Sru/B1+Bz6Lq9CBfFgJnWYjs541sZUx+2L8YIH7d66H8OcvVF5h5dHyTkt/3TrXZq9nSaRZGPrEP0dTjMQMMXMUEEeG7SIQe9IiR02V+1sexXBsu3ru9I0Y628ybQRq1H9FXdtctENmxI4B5lSRruDKkwWnPQP9XwxvBRm6ZuhCsvxtc1yhx2Xf8zVQTc+nU9TNfT2yrrTffd/cXtOIHuIJf3C7ZCXPPT43GX/3jTZDNndndPkaFDzFdNLCceionK16hMSE8X7CBZWtj2PthWXWNrrbHHb9Aaeykxe1pjrx2mMnjOVlznxV3tsunl6Y52GZk7/YLTZi/p0y47xyqkLdJqmI2iYTbqZpoNs8ubDbNXDldeNH47jLv9tMXkpVW0xk+HbJ9RmqMsozl6OGVxHYDmKNppZQ1bNqxhK3CiH4WkpXn8ny6dLMVOi5pQTEVK8RW6rtkkPqI4rjnqRilMAEPmSgdZkwX9+rEqdTcJl1R/CqT6ITeYo24FoBRvBRlN8V2DgWA4Rwiz4V2aRZ3D8PxpzU4yV9pv1azS4SKXmZrYnXYrjZlk1eEqM8uzFR5YKsHQwXjEG/g+wp0KqKoIecn6xEjPxS0sGEoJC7LfoDsdYJcklIdQyJcLGCCwVRdeEzK5MAkeQgC0nd1j4Rn3PD08hPT1eYwpSbEE0rZW0gkCSkfLJOp1HmsrLcoTFYnkjeic91tAx1OuV6RWU315iRkIz5yapzxHDYQQw8wjtQJKFUPXOkXhIMrMLQ1KmETXlWFBiuKmeD32HYqkFRZwb9Ur1Sh2pNbdRt81PpHBg0+flA4mWYDwUmo6sFhGbwvhdJr4CpI3gPNNF68IQ1OvzhbBWupQBFzeJHsfaw9CoLSfs1D/5pdzXj5X8FRfoyk+TM4OveyqL+P3LO3hlQog++Qp0XJ6J8VJczk9Pv85n7zNq1HIhKMrZYXW+TwzYlZ2C0mpMjr1kD2mq0O/Bv/AKmncq/qyKZ2gSM3RCvu9dXp5ToebwBWyx37O/Z6XEn+H1enPU0A+KwJbhZ0ZIamqlbYKPLeItRuu0haro78ix6ClPOthFzhaX2LDA0f6EBffPqgyeLyuHyvbwfQA6RzgvPmo7mTyQMwdonnucrzuEQHp2A4Qc6IAhSvPpw6IdC53iCtPUuEa7s0y8Icm3QWTObo8IaE7svLzWTMPZXY5iW11b/ofUYUVL9SwYuZTnCC7qjlRkELRl0RF9MTHXTp+j0N1unElJH25FmBEDyBlUi7oeLHlC3N7jhzZLyNnppWdgEeMKLnynTEPETmJF8RyhMaLGkeb5ojYirywkLlBcjLnlcu5D6B25Rt3X4cXJ1ckaS/WQ7pjQMQeXskrqlFHOsEpBzm2WiTic6gUsQGifRx6dI5APyyPeV60y5b0NQNvSNI4yXZH5/btNzOGroqKpCP3GU037sarKrLmFlSH17DZdD+AOVBv4k5JCqIhYl9fE2xBQlrzJmy8SYIxUki2o0IG+85vYWjv3qhAM8aesLDpqEDNuGVCpK1FC01vk1fg0M5MDx0tQj9k0WLrJEnKEIHk7RFXUtAMJDJwIjFZ0ng7kvxDK5KEHZHEbkaSS9uRRPVV0rhhiP0hY3VQUVlQSXK0O9mkTuI9CFY/H13G7w90w2ztgtlW8qRtuYW2x622iU1JHMK/XrXuRTXTdq/XbeBe6a6LCiwepHHeFqmV/qvvPeYc+z7UEmlv7AM0eFEfmqd9h1hUNc4uSVd2Od+TWnJ+O7ecZOlKIep8RgGHyS5Fi6ykG+Xt019+E+MddVbbmPE8aWHGcb3hFNBlBqDGWS8EH0E2RNZLWGnx/HAuXy0zYJWCtc7dcXIqVMLO1PRpzbw0mNUEgcSJ6YhVIi8s+0j8BEGp2I3H6rYrBbgeVHeM7h7A47TQMhhGn2LFOTCKcCi5ReC2U6IYN0gioDn9PuimWC7GVmaycadgW2ozsT2R7taiCZNx3sJ4O8J80WR/iFLZryOVDW1GqC1A0ZAmsjSLDUKfZbFJmt4WxfD0KI81SoBFEl0Ks1kFcFjk4VrRzitASQodAPPW6OoaCi+PfgBaUemWZEptpDr+l5nKRkj1PJoyqVLNJhMsM/Yz6Y7M2Eu5HIZziF4jx77On89zQKW/PvHVxPfQL0dStLSwzPyoWRtHlTGP2jW1n1vu6qTGpTTKXoSTOQCSw/3t5f4x3Grxeir9Jx4jJcZfm+yR1EFjPQrqwyOURb3JWdxck6Z/JN3tc5YWhdHXVltbCs2t6kW02partH6eSyFFuzI8WAFkfzaM62GOM1g1TMmBOLG0a6qebvdSafWcGaUtV91ys6E3ira5Kpu73MZrMa71RRHpkDb6LkytUmpQdoykbEluxZe9VNbS0SmQzrKwrrxrxMoErnShqKHdXnEqc6FlG1OnVV0hN4ndZXJPug0bmk6ObsNi0VkzAiRd+0qoS+kqppbBtiP21H/EWnqaOH9gHi0+jtgl5mZOtqD72TDnZyZTOi2BsZaN9VhSdQJWBPuqZnxB9eCvSLY8VdKpw8ti1jYcxaLpGLI/eI5kGI1PgVc4kGxR0vG7VhjLa9nAIqqbUi8JJ9PhFCa6flp9NBZxHNWRNH83dOm8k3YD4Ozt9j2eO6jlc2kR7Xsr2J2qHEW7CCV6XvW0BWRh8FkTWni4VuUM2JPugJuWmjMa/9jXIB+XBAruZrpLzfaMEE7gQ01Cr4gIimZKFOjexD3SSXVzzMKSdzpl8SnYcWmZ7THF2TdNpGnPJ+Q7U3yRVWBwzpQkNicJLNOjo+9q/H0WF1gPdn4J+1W1/WQMbXs0b+kbqI7Rt4Q3VqHrtQF1fobBXUbTcZmyU0TLuIvcpxgb1EgBp7iopGxsGTZ+rwWK5qOZwgsU+EpzbcxM0FfzlTQ9kuRSDqBx3HyGIhi4sQA2JibyKAMAZM1O5dJGIL+KZh28zANRoNCtF2S+/2WklFCTkmiUo+ELS8jcLtl9IE3qFeHbuwIMgXCn6Apt/8rIglWKrVcEFzeqzok0036rrCaXrJJzopM18pV4UQsiDg7uN9EWP6PgfXuq7iATRw0hu7sVC9UG3pysixNAcAoi3ZYHKanUOIoM39BCw5ENNB7MXVqQd20IucKFbcWQsNBzFX0FxdUg/Zqki9T/xWNxi8eOE+0Cg2hClUs4opLYogHAJpnQpCcCKOJ0EIu9KfFfCFJdyRNrlbXTJ7bHFCVQearJ2plCgeEDBqT5FyUrQvBqshUt9KcqGYSvaJhs6tEdmRILTJ2pEj4Q5UpRG6qVK6XH6uNpaIvTVIurz106T78iJjLCH2l7ZGtMRi8aInt6P0uPPtpMjwQPd1wrQUo6EOWJMvBw7/59YTNJohnaezi2ZmXGFEeqqmjqBrwhL9uQ5OgdffMl/9it8J8M5EDembh9eJ4j6hp11repxEwdqW7foMlOpYrUp5voaPgMv+2ey0Pl5ZsgPsLznVg+sjwuwluMNZxl1qeUam3mo7OGz+s7ffXkwd1qvG95hkQoMreue4HBUnfCM29B7xofxufbdEgfGa5EpO555QBF34/gUVbipMSjwJf78d6IFBmb3ULbbmyeZvqLyxsEq7gClOjiVwThrLVhlmSJzR6awSeLiX7LnCuxNYM1rTlaqTWteUbLmukw7alqrzVv4HfP746s+aRdpz9g3wZxqeRPB3OXzZOli0+uNzkxOW0V3eW3t92KjZnabEHnwNgTBx6vK/AgV6FgwiWi5ebGY1bMaRBcoOdmAhGF7540EVpyWNcYR2h5WuJTid8gtGy8sD1gJAn2k00tdh/HiPOe1g73+WvscL9woOgycqjUuej9ip5F73TXovf17UXvpx+3ULR77aVufNGG8WeUDLT0/cHtj0w8AN1f5+4E6cx+cO4+bFMA0kFJaFqQh/sPBRJ95saUM40nDQ0J3XvSQUAU9jf2D8Yyc9KnwBQctBez7+LuAl/D+YnrE3+f+CCFfcbDAInRWVYppU6l3iwPUFweEhk1XLsMiSrh+Wb1ET0o1sRHu85rdkZY0dHs+Att2ocWq50vQlutUreg3xa1ZaJ6BF8tR22bNlS0wENb+svQCUH/XeMFLWnSmsF4RG4pJ1qAi3EU+Ey75xgPgLEAQVcGc9f7UD4osmhqso1ZHKzwfTTHkzKnSJ4GGt9koziRUXVOlb0QT5WjnxQibgTu2gsv4si/kOs5ALnMuqmzvB/gNBlIUtlRitQtn44mGmoMvCDH8nlexNxA0iQcr917F2byRTDiotMvyQIgD3ABRSiMnlSv0YLVwncCgMymiB9XXfkYXoCXUKPUAqhDaaBXugHYIRNAeZ3xAQiyKKWwPuNUq+TdyeQFYHlyFNBKSTrOseZq1dHZ+ROmjVC0JHxIoIxggI6aRb32ngv0LIy+B9rDVH6Tgk1eTNHyxxds0peAoxtM8ontAJOoAyFBcxtRaBwf6Oc3Nqbz+e9uTMiuY9/l/gBL0v2VqxNPTrx0y/sr/YyzWoBzHejG/VatrDxiKNx2aiNbPHKVoub/DLKpcnBIMMUPNzbGyucHWk5JJiYhdYb/QRPzusSbwZDADtz2yJVt97kzIzJ5dvLesw1aYy9oa41dH2mN/XCbjiLbraBn8cwdkAh7QPvAUifZ4MD+oNtHzurxkVvtgoskRZWbvjAGmprz0Xw+G4H3LViCTSxXIntEyUiUY9B0NqJsXYryE58eaDFYmjvCmOSbuEs/1cxpqmQr1DVsptFFXSNgJALq4sV5JLzLY/+QnkI2A7w10plsINO4p5VMpDtmCr24qG9m1NBhV8I4FaKJH0uGwtDjyWWboLThYkablX8i5MhjCDlKHGQ/xZF0Msp+ghRNfz5N/p1NCkw6KEAzBWD+0xbQOu5IoJ5ilEerUQKFd/qx9WhuKv1pbmouVq+RGCxHNDdPlw+cvF/63L6r6uRzCMa7QXJzKVbQjiDz/AesElKam05zhVKcW/FVIbL5IdJhc6nL4gEZmPKmtv6CoURv6LBrHbFGGakXl+FM82PkqtORRKeoyTRa0tlNgzV+ztJXGNwMmwY/u2lumcwMxniz7p4h6dlZX3kTx53zGHIPwj2BFCLLpYsV78XZk4pNs8Wm/17b8qPjTcPXKo0HDMR384OLOhcNz+xcNNROQQHVvZU44YyaJxO3Yp3MjPsN/gEw7omguHkXILof2oJxUTRsB6vBQEwF3eY+E+CSoGluzMDM/uaW6N8u3gaCA67ej7pg5fXMDe5FuKfDDcB+iqw+OwI3WC5KdpcbfLHtBtli7AaSYaeclRcPy3jwvkGIDKYw+T8JiGTzZETwUSwpGhjf3BMLwy/BumkcwRf6RvDZPNWP643h7bq0CtuCIhXhWGSJQbw1GsGlIux8FLijCTZbOq0zuBX+BlIdGq5RRokI2M8PxmwddYoRoAEg0QCtpDCvkw0gi3S26E+wKIC1Fy/wTI1OVWm4xtQqCGyevJceUNObNWRxGZWritXNtIz71XG0DBADyWUiB0FgaXpy5brZqwiZ57D0qRQKaZ5zzFLe9QMjZ3KfJV8kNmgCDdMs2FwGMsXh6HSGkI+rlUpGk8emZ6zGo/VSpYKuLB3SEu40dLsbWSRR4ayfBWxgIvjTz5KKmJo3baxfgGPkTKNcCDE8QS9hZj717P8wRyvINyx9fPdU46fy4dMOSV/NHViec8lXcWRHj93Gz8BOlC31A4mPMsW3dY6sFFlww3jsd2ZPhwgd03Xv5MTHMC5qA7QJ8Ic4x1qKdmL4ZlerBadrFdtdOk1HCFV0CuPDi7kgDu8eoBSlANmNxljKLc6gksMOf1tqjJ7nDlPPgboFrEwUjfpVrEipmu4bURqlBSB2odtukqqAakqnZSylGkrJUpJRq+dMlmjZI1mVHhS9BPp0KtNUO1pxSraWxpapCvr07KFCp1jThWP7fVxIPjZjuEXqD4S7iNTbgfzV2X2dgTyTy2g/aJ/gqdmOQP55trAiUXG/Sm3UwvA6oiKK12t6uYiS8oXw1Ut19Lwty09i6aWSXLlRDRyzSMWbnIkQ2ZgM3iwVo2E5NWW1JJyyauFIfo+tJz3rL07dPIV4VeuUhIhA/8P4Fr8Ct/gngZT88pbucX4whpMeyoAoletDHyANwl3Cb/2+PzYAMIm7tptj4Cz6J+Tws4XU+mnAyvf7wplGt5gZrFzUj/KE+2BXqD/UZLYC1eZayYIqA2Gw8vaNmUxubqcOyRhsOY7520tBTPla2mOjkMj1QhEDuYXrouiAoZNaXrc0H+uS0usm6sqxBMMbDIRN2F0hzC9XyafJnrO9TufgHeocqZTHX0/2PmRybejb7AVzz4pLg2w1m0nS1hcxT9lN0McGdShLHt4wCLyaXEBuJI1rnkmu477J0RLPU7EAiMUEM+U9JnukZWynSHUa1kOtLTad4f2Fiokun4iyMgNYTcZBCo93b6/c3RdH/Xgj1Mj0zHTLcNPorLwVGze39DMc++RQhovzhKbhqCm9rRHrt+z5qZY9fafHntdtaM9nd9pT6DSn5tHuJXf7luCvpNIy9I842vF3lHTKwn1k+M5V4f6ciF4IvcTQ74sMvaZU6B4KTsznQv4fsyMGJhcGCN9zXGiJsDlQStbKoSFArifTgerk7kkm+vLv8VF9HXQOPhXx1u34YR2ey2isd4Fqtr1l5R2PQ/1k5fAF9z//0Jp7WX+/ai+r1t6Nmjn1vFOmo+Up1/jlYIfeLmx06Of7Hfq7f9ixdnVWYbrNUpTB0lW2vXR1n3jp6r6du0/RThSuiaXOwPCfEPv7E/ZlHwchumfQXYqlITKEntqAD7zhBAAR1mFgdq+Tf91ztr/awuxOf9TqO908ZaqjrLt9TQHA8aYA4MLsXJcA4FnkJtJ4HMfdwD2DmorVZ06Y957dNlWyVZ8V05abgh9wWQiToqfWLNAa13cqAJ7RqQB4WUsBsIGbk5xM6CXKDiXFP40nTk08EbfnmxCMNz6UwiAnbpul2joO3ffWP3SNK/udqy9suzbbcwc6Y8k+Z6ixvF2ibH9sH6MxaGb+AcPascS10TGqDTZ7FbanY8p3tTi53/URA3nr1nqgf2l2MRdXz2kv653T/lZxp7aj2Xm4s0PJJWz0nhdQET+ValxHMwg87GrngpfZUZGKMe0q7rOoJG2t6C8dafP3x59aWojJ/dlXHCFRxRtGWPuU3570sl8jhGwz1fptQHlixcnOEzdnWVngf7lMGieJWlUBlYqjJJNWOaVooeugk4wyhc5FdWZcfI3I4/mD8gHjY9CE0ISQR/vK0zjHg2yYyDN6D3wY4OHAwMiRzpiB1CTmVsjan4qWo5Y1R7i0Y1cMDKzraJs6AMJyakBvu6TolOSk62RcOBrIJ/AJF7MxOgHFt9U8BfU8RapqjmaPuB/A8FhLKQbOIxCwGCDDx7xiML8wH4AYKlX3UpMBJNPwOvghZbKNfO8AXqhofi9iKWMKZfPNDAk0YPea7lkA0hUh4g/zDDwgduACTMK8c8ZMRpdird10qTcr4ua+8Nodb+4Rg7SrTzQxxUmPaIDJiHTdATVvmLKLmCCJAppfe3y7IAheqW7WDpVcoCdSnJZ2tJB7IStvaQXoinGBK2RMpyKv2en+/UB96stExx8fLZnQpZNdHzpwZZCF2+6k52TMkZl8MJVNjSDHrp874RWqpZA3/CR3Q9TbBrA/2SpYAWdodUpW97eZ1b7OrHY2BpMfZHwCLPQuRlTqi51M63TfOuJa94OOAWXLXkx+nFprmtR23KTk90reTFm6YJY9Rp7eSa5ujtZGzSCH6wb0c2ba1DwcOjVwTeTm2KMOpMOGB4qnYlW/bOVrx8XqumKBzAfwDXRkGV/6fWM+9TS6CByvgk/9wVgBVQEkH7GNnA0CAtoAC8FBpN3LDj0HalPaw/58vLxCAxfcPNdI7GV6bwmvbU5C0QVNiM9GJvW2l4l9rGmmkqNn2easmMvb48xMvubVbbsYm+lgyc2W8gEH8RItfNEQzOtuB/N6cS3mdXJi+/k7e7A7CO42wAlsd9qzSnbuSIoaoGBIZv0+E36pjsY0NUDjrX2o1u+4qpNq/f7d7c1rOqnWE/yxP2IKNQt2r1OA9fjH7SHH5oc+rIOMnbibtmFi9PRNHs7X9Bs0DU2LfWATR+9JgwyWkAWraDjTGFxLXAI01r8MyonN73yQHaC7fMIAreHacYmxK//et5fcn/36EcclxDaev2H3mPnEXcwnFgEleAMla9gE3zXZeQcZhNqHO3koduuVbxwXb2noffmuh+a2vub4OM/r16PpYX7zXeY3XuIsYPJfshoNuPNRYxVAcLEXCGgdFws/rxciuAoNaB0fe72hGySIMtwB/vYv4GadoxaqRdP9PdyiU3U6J/2MSo+inUmzscFKadIECzY1UVh1vnxYWO4qwuPCPGZYjbtZ7TKcH4ngnx3VP/dn9KzAihNo/FGwcuqBFqBo5jXfCc1QPIpZcwp6pMmV3xMAUAl+XBSiZhEDMdUAfBN/9bKFHLgPWfFMWakFR4XMMRTmUFwnKTMmLZ9BDa0R3dAILcBRr0MQyE6buGbD9Gm5vZaartAmUGMlnDUdVXZmQu5eZrkYJgU7PGPqzV8ya9UMinq9NjFhN64iYS6FdSgVlTgtlFXZTaNS5oq756cqSWQAKIrfGxXFInyO6d7ydDFXVjPmxNUTcVW8J+BTmYBuJevNYnzCrI+wRPhraFAlsXn5KEqm2gEBwDEAlUVzOLs+AgBHY74HAkCTr1S7KAYXbr1ZFI/NNCdzYz0593x0xvKk+6xOx47A/b4958c6pVnTNhzzYwUkUDoH/Zd3Jcp8O09mFbJFWKL8KAzU1VRONQuWCiMovocejc2zZoTs5FwzFJJ2oaw/7Go8Xi0gV7RG+WCeNDcxyG/MZcIbwqBdJ4eUoJmLhnX1lClcIdn+GD3BlZRTSzlj5RQ2f2Ulm8spgHYWJ/PBrmxQBBv3Tc/UgyQXra59l/stTOol7gcNkn9YDy89lJFXwTzIKuulNjCe0Bsx79MbMbmbus2b29i8QsXpNO7K0VWGs8bF2GzlXrNxS30D58iWDfvybsONFjzJRts0XNtsX14VQTOIoLcBUP03dJzuReEuKjQxFcEvP9XZbJRioDVtalTbrc24sbnc/Qu46MUmlfF+LhyjzPERbQgDUlNqZPS0/DZih0ZcqM5NcGN0P74pPIUv/hyecLrKBwL25pjmO13sDk0skMjgaFJlIdQtX/P3OByKT8RDvjRftrG0LoYg3uCFcLkA0DA23nnG4/87xEvan8xXaha+lpJJQVB0zsHKEcIf8l7g+iQXW+28h26zjF0QMFiD8op+Lc9dbeWtfJW27P10Wg3rYW4p79bd7FSQPZQ2s6Yz5mholWJLfynkMDPGUnr1zIqNl3OtLDb5d587oYegYsZSi4Bf+MgIL6HdibTjQanUHrpDhimsYvKOki0UjZXX4cfQdWDKRQq38ScyT1B87alUIh00zvgxLE+QEWAl2PFWsNNNYF3rxbgLMQfrDo5N1IK0dmwcLIdZm3Q+Or69rPPc5cWqL67TNeiMhidsLoshv2nRzY+Mltp085icNPnmnZhk8ueYh6X1a0FO0RMAaaoTR8CrN5HDvIPSy5cienlwO7bo5Tk0QMAv/+FOfvnHMyPdxf2SGemBzEgDMf3XNtE0qg2hDsB9pB+vf+PfNtc04rxBBQHu15fK/8ebaRm9Ywj6//gM3cmY/v8Oy9jbsMs1dI0wHNc/Rhzv2AZu/5dusop4G+7Kgdj+h1zxmtrESdw7IM//wSuZnX/E/Zjx/17Jbr2djIJ8/CIDQFWjV6RfXd3xiDhTO706MCSVvQ3XpVo45G92Okw2PpddyA8MOzU8E1wxaPX4MlJSCSnpt2PD/l3ihTtsWtKT79Z6s8+dN+PKT1YluEFv0nkcTPaknrx2rifNpIyp/8NbKBZmEueAMzVR65DEWHTG2AiTZYXzHfT1Tf2MkKIY1hW/qO1YFX95pJPhM50MkLU5WBrGbn1OnaZ5oOY35TReK4LdynIVjqpiIOqlmqoYv9ip+v7yTuEMgsVt3bfcXVjXJv8SyWy4UktlY/dHDAVzASaTcY9umYznUZmMt+9s6Z9MBCDkR/6OW/UxwAJ+Zpvv1QGqwtpagh9Layp3LPfT3eD+fRt2qF/dUUXmoiqyzqpI0JLmV1WRtdXSHiLhVot17FlfZ2PIC7g6VE35si7Vjhug2qEWtEiA48QuAY7kAIIazF9uB0ZEYEH8JXSWXtvMFVr767nIaZu8WxsnDtVdqG/dLz64yav2nkM5yPO6HOQ5nQ5y3kYO8poeBxldOrJUQ8tCAmb0j3wCN/xnKEkuvSK6L2Ywr+O31bd7n3K3de9XROpisVADFdhplk/oGHeyTjJ6nLBFO8leppt4kq2dNBk/2Ee4L1DKCnB6mpZvoayHec1iMQOHX50IqP3yB8WBAhLIQMMMKrZaOSdSbRSCjyDcZxQmxyQpI25ppaGFuaIDTvtUi2bSSnuONFp2Rlx7coT9JT0ZdjBNegb6DM5kluKjbDE3EViuqfjcXZKPuQAOr+G6ogL2R93UCgRIc2V1EiFsnHjowATqus1qsykA/FTBBkmOZrOUQ8nJwGPR3e+VvJVz0f3Il4pa4UBELUnMIKPuXc4uZcNZjv2lesZoi17yhKLHeXrayY7TSlXx92Xp3/NIQ9LHfgoMKZ+4P/L+j6FjOVzu0Mmx0pk7hL2pg7c6oWlnLp2SYGwE2ZX+0EW1ppzm6qTnD8NkFLaTBA1SlFHg44ZC0fm6aaxKJ/6tI7eZaWuFoQsaiYUVUiBEQg50UufXYUsAeBsogulQBFOZIhjy0ixyn/8YIKN4d1dGge5Xko8ziis7Moowl5O78wlQddBcZ4TmOpd0SIrZZpztXMVSI4llRq/hgOyLv/jij5/1rNMaf8nOBB2yYZ35UEuE43+h3Hg1Soeo1cnEWZp4zXq7HojokHnGcyzu4aYJ6S/aEauFIfEMY82N33tTWXdCw56HXDxQ0UYdP+Qov5Mxg3VPnGWMxmYXF0I8KTWwCvm0+n4yvqEYx+VXAG6JtarKSEDSu3btCt0KOdMZlQWd8sr6SvVwUak4XljMhVPgbhUkECJns2kpjXeZM8qloipxuqu+ufGx9eU2nqLAorJCjJz7TNrQa7HgTyQO4sm9JHp2ZgRRXPvptX9x8a0+TeJ4KWzMer4Qn0JGXz6gQsb/82pZxXMdSSb0QZ9Y0QroWEQPercdWnQLVkYIOXlUd0TFKix6/oJ3X2yHOqBVIxtxlS8UcwD7M9Lx+kDLWb8zigKD0eqBa0u5A6GU0YFBBtMF0rCkmEWP2ADWrrhQxBIwnD/jWCPOCRpEZjin+oRocyPV2tzwW2oYRQzR8ddRh7y1314W4/2+C+aaTEyCOPeF9A7lI8449tzY7RftSqVo1+kwF41OsZ3jRazeEf1URHIbK07EEH5/PupZzqVIKzNbjO/ciKaOnR2pXYMxnCQ1P67Gt1hZX3ecwsGRM154+i0YVmYE2fdBrLZ89aKTrzihdqh2WrnmgN8MOhAgPU6u3OUXQG2Lnr1k7sacmG0hOlbGuP/77m+NNs5DHqOXykUAlkmqWFLq59QFoVSrypTsm8tlU3vsYB+A+UjVKuHoKaX71e9BHo0cybedLKWfIqLt+KMiaGW5g17OAqJ9OkTrv/EjPsiPAGVIM2jQ/VWOljRH0bArHGSyelKi6wgw0EtEQ1bBomVDPcIaKWTU8oFyQTFsL4kEHPBpLRP6Y5ozGirpTICb3lkMTywut5QAotP0Qrotd7zO0/bJARyXI7dNPP/H4VA2Ltsal3/E1Q/RMiGxDxTrL266RPuG4o+Qrtspzkxa1xP1BqGbP99Zk48/IFQF4DDfUiCN+BHWZPT/o18InXrGGaU3mGSmw6x9LkUQa/qElTIx+tFkT8VNlgHIXVF9M5dOKdfByBbXRYvfS6m/ci1XmRwTI+S/DY7xVIVi4zs5+S/v4OQn7w1KnoNDrVl6OkwpTi6TsR7ADld0w3k1GyM3P58fCfTRWlnFeffV52GlyLujzXGf6wXnt7jyGw9nDIkTUzVed4Rk6CZHd49La3Ht0xwCOHDCB0D8PhSBtSO73CiV6Dy8eLpCHIDp/lS8zzZJoB9EiqST3Qp04xCCBJyNPH8ptTuEB+PQNbMJnLg8VAha2QSogwgQP+zEIfYEVj4bKo3FcBcaTCbLJLhJuwbaruk5e8yv+3WcIs6KdtioY2byM3tmuHApGIfeAefUWUZBn3b1SFEZsVw3DNzR5vPO2XpKGzu93n7adxKgX8ZMxk2hZVLR0lr+cJourZF4a82dDCItNMayPAFYwcspI0h8ix8gA3HVBugjLUWrvJRUcq3EgN9CNL2ufZd/ZQAy2pdTR18vMfjKVmLkxc3rXDp9Q97ZM3lCEwKwWvh0iauZE7iezcafr9hK6GOJ353MVnOJR1DKPDLcOmBtC5Yg/VcJubdSXvPOHcANWc0bp2zp0nrbACuEpITlv3K+ufxX3Gj57z+3YprGBe2J6gM7VwdzdHWQHbLPw3AVCA6+c3gic8ypgUildWt1A+vSF6SrtV3yU30tzq9r8c2wk3MhfqZAqdTL0np2jwjKuTZD+an93ABcizQ5WccRSn0X5s2cHUnHJHXUzymDFViCKge6ZQv03ufMgtkmHv/+mo4AVJAbO4JMh8Ybn9IfsVN6duI51Ny9sPgDZJDIOr9WLriVzJQfII+8vDPDe/8AEffmNZPAl2/lZF/UN4O0urO7vX2YwFclf5y2pbN+ab/cETIpzP4PxADmA9T+9Za9DkCPJEZZLR/gBvGDAyS2ZkQbnidUuyTujrOPjZEtOIVHWbrmab+E6qVAQrNaxx6dGLzQqSuU2lfGPmc+5Jd08FfIIpB65rsH8IqXgG1b08BiqWu6rVd1StpV1NCGNKHrOhFk8o2XbMVDkKrKyeTtVNhJeKeOnhzZhWVvz4OsSZI7hfg6Wn46MvSN3OIQFSkJ0IqhTTfCYZhGa0hslU4amkL/ZWFLPnIWpxCB2IbmcxEFuExRY6Vj/42t6mqinLgocQN2I9rqR7M909Zo2Eo2UXXwTJU8dqe5VMf1gIIUXAM0O6Pj1oaAJJCKECl0b5gujOejQarQMP08Bg1pu4rJBOqMMJWx70nrDFXfBZJYWmdInmKHQQbLSorqmWARV56Gx2bdYuZ1XQe4Fi3j5/i7LUUyTbfuFUoB2qijeRT6Kj92VKLU61y0Qs49APOZUEKGZAdT4TmvO+0v4TT5gV9ynTIKDFNLh4FiZ9Np6/4pH6AXmvCWQi9ro1tPaeADvTJaQg/N8NRnW7rmNr5FFEMPA5r5JtE/17HMRaM9xmaFCfQXjND7h7iDdjvqhjRq/gcgSG+p4h8gMyJUFYAdaRyxaqSuxWxEwZ8x3wr6Pb/a+YToHGCNgX2e8tHJXfkWsbGurhtG3qLKPyVn4aH7j7zgKLlja+FxQxaFcQKUc9o16WabJBspkL3RqomLcKbMMp8FdHQCNGZP6d4U3Iz65hbSHwk1ELfE9KFSc82IPNZtuyXufVviFNpi6vMu2dcyty/OT15aEcBsgV6Ivcdf+SSsGjatWhycToj8ZGuJzyPZlQgMh5VxTErMIaMFbtAxOOuxfQHnrYS9sEcnXkl3BTezF7aFQyrBNSisL5xf+yjGQGyyAT0Rd8ZQ1EGNV23lNL8xc/o9zy7gMAprHFhcvNS25MvrsBPND0kbxOW3cuAfzO5ZKZPzW6faxfOhx7px01qERCiH1GNf4D4PApWngFV8x/k8Ui1CD7IGnwc3GHUL+UIXTUd622g6wGER83QwHBLoM9IdNB3HNuZ26eThKDEejuIWeDje1MnDwVH9TkbEMXHJxBo0HPdbzQbzkF42mBXFZVwNn4OxVYw/XsjM3R7sNnUoGSnOQp0OQyDUFyGR5tkUf3mpw7Kdyw5036EFW6NXhBh2inLEjbt6POuQ1voFd6vR/+7hYgkQymiVErn7lm3JgklwKQmqqaQXdXp6iu5zZy+byx3Iha4ouum8fbEKURiobUiGpBhCla6cYRAsUUkMEql4QAEDqyOwGiag0NErzGYlC8+awwhRx7gdmZNfMY9APkO0sHOCkQRdOsBWOf6aBN5Q417L5fNBBooDujbl6ti557i/cFJSEgVVxEs8N1cB8E+WslK+PIqNDMo1Jk+GtquQi0SbdsldSPzBwXahP4h3RkVTUVmpAq4lx9JUKH0gww98J2PpxVMrwBZqGT20FJUyPHG6Px6ci/tCAi7AoggrQUUGLdLnQvjxcJdXHHX/EOzxXUnCCkdWO/slMeT+Tkz8x9E2v34V5J5hPbcFcN+tCLCwdJD0aAJw72vB7Bvc9sLsX78Rw38ntF6raW1gfRYkw5sF1oddVP3B3v3LQTdZf4ym/xbTRvm7xGv+Kmj6PioN3Ou3Acv3tE2C59+4kc2OA2C+srEgBzIkG1PIrwGye29EyQ8mfkql6ToiXn2xfaXNt+SH6EJmz33GcHstDd6ue5RHpPWYFBJi7Vhb9ogOHiNOK/ZilJoKa2IxKAajZ9rHH1tm6r0HuDKy4Xmqc4Z3Q3doxhC1y5Mc7UJD3oiw31vhlSXnlIwH3+oQhxyvKbQU5WgFsse0sZgF1IWfHgupGhYPHJtOt8wsRmsgioIh6J6uh6hEaehEDYdgZGNMhNDpjDjYqMYnZE9W0L7S9WCMjoOpBgMSsaQmZkfIpzVR1RzVl+hFCjIsNAE1Id0AFxkqkkt5qo5qktEcIhuIbKgnQmIjaNy9a9JkckgWvgBNI6S+cEdEaoUOqjl6NWh4JZkGUpHeA+RCuYTZuVycLRTmSipuVQGBF4Kp9DIwMb5BbJ9VNcVHBqGbeUN1VCOt667swtcpcGbc9/cAeQL1VlXOyGro4zsLjZuTuCkwe/fk0Xk9p8t4GTGp4V0LEnBl2vhuTNrSdOJNV8kR/q9JsmU9EbeEx95rkt5HJgfmPhTZgppM4vbGqA1nzbXwHvBkqvf5WxH1N348pj+rgoWobr+fwftvx44bD2ToIxI3xSxLnTn7QYKNw+1nc+gb2gdjbzhTOXz+etn6c1dl6ytf2mRg2fAyaNQ7yRpGphamRjrIGqZPPfeU6XJHrn6OVUhbpJWtjyJbH21n65c36Roeu4n4c0L3DVKrjvbcICsfXZedIdrg+XXsCTduHSG8PdfJ9KZwv3mtccpOmPpTm8X2bsKY6e7L5OrVl4lz7HvMYCckngBSu/et6kHPiJDGa/WhSXm+b495m61H1uk739Ddd7Y8h2+3nskX+/WVVz63I8f4hFUNZ+h6AJnLGs4YCBPf8FOuThGEyVQuE/eUw1yzpzxlYOyOe+kxmzD27j5SXu9udpoDjkF7Md6PWQ3PhxjAMxPvTdzBYNtifC7jhECcZTlCZRHLyqshE4jureM73ybEJLCQL0Y76gN+2f9n7k3gJLvKsvG699bd96XurX1feu+eXmfPJDOTWZJMVrJAdgyQAGERJCBhEwFZAkhYZA8gCeqnICDKp4IIKCAgoCyyBUH9K4IG9EMwU/N/zrm39qru6unuJDC/ZLpT3dV9z3vOed/nfd7nwZ8d8gPCsxYYUY4TUUKvCmqtIWoKC5FWGFZprglzxbShOAkjJcuKJSBwqCEMTlNQdFGfqzoMDTUu9OXkRDRvRBUI17qvAc7H8q/cZg8h5teVBIooOMxzQuGcij/nq67AKgwcFBmtVC4o+IyZQumu6blMWs2s5BwHc5YrskuyClEknTe8VrJSDiMwTjITpH1YuDk1b+PXZffnePUNO2BBhBB0Ifl2EcZ7j8b+LwnBbZF8GxJtIlFwHB2MxNivAwpuZgus8OMJxv3BNgjG7RoWcyw8jEeHJMmEaTxyZ7EN2Ku2W2mOffVgnJXyu4LzWnFYGvzvu+zZgEagsOkd4DuO8adj6tTlYadzNSeDNHNf7Iux7xPlFNh0Ru6Eq7B3poJFFKhYCu2bcXcRkDicM3UfgUEHrSrk4VOk3CLTryT5feE8JhkM4BiOB5jxfhZzSlYuQYqYt5rVShpBExRgoDx/2e0HD95+2YLyiIu43youHioUDyzk8wsHioVDi8XDcxnMKVi2XYCrQjJh40A1k6DBQezdtX3IVOuVZG0mKUnJGfZtD3n0fXSc6Gs+VodyKqZKidpwXAPyrcKDK4ZgfG3sG6FseLjaocZL5KcZBcAAnt0ejOmaqc1SjneBxg555dCXYQbG81HAI1Yw+Me1DHrCq3iNvnWIqKMVSTjKFCFYW6H7Yh+hq7c8qMOfFf+5voygJT8XSJH7GeYJ8PlFCW7xVCZatOBnScNDd/DpBLkldekSgdB0UZ+i+rRkFncnStNo/pZMymWWKAIeJ3FHX2C1XsBSKAA46iwjEHAVpXRSZSzPEIhh9beMDJAAHzEG7MCwZm16MBENa9MONawlWUwDNSdVIHmrK0CnjDvElxxVDqhKEp+v5OJoOMcdydeAlP+O2iBw+Pt7hmaAdfPRzMwTpnTX8bTEUu6im1BVWDxefP+wVybW9qwm6GvVTDYtP4XTDIMDXm+ajG/Tt34L+ZEMv+hGOtYIEk1WdeDtIMoWMhFR9vR9jJ1MYl9aRr5DlA2UcrWk8hruWgz9gq2sIN37/di3H+Z0bywpnE0pppgPT6L3wjEFdZhvj6u78rCnem8fQ5nnwXVVXD7QLUVwO2U2YhaJ/X/QWyYm7DQiEA1B64LEqUKjZjUMmnYvLtFdPrb7tSQ2N3am6QY2ozCO+kMrjQgjJW/FjOkllZdScYUUbJjFVF0ok/EyrJbjCu+rLPo/aHmYcYXk+ayik74t1g8mupo6n8g0UlbRXteQBl+XaBDdeb2Q8XxM73nSQdJLiTOwU1fpW9jMJeMMM7E/YQkWWjASiuKquxTHwN9cKyumIQtDHN8Z2orkNSdpJ2QZY40ZH2if5CUSIs/a3mTWKpjenLqOI81BIoQwrVplS80DtcQMQcKVzsdBLNnGhGDwcKMnh+bpBzYceoriAmPDd8Xuf4TFBbcc2oi3+FGtaVTSoyqT70xpO8QKfC+/tJdrMbLIy8rCFEHEW6jXwx8638Bb4zZMexzzsUTds12GTdjWpI4ZmA8IAChIqxdjyWi8YBiVK8wtL9RErj5d51ITtgpY2LRqPh8UKs5jmn8LL2sDFy/DPviICbSXw+baxDAsuKWi79hJcvujqtJ1KJfGKdtE0dKeRwdZCNmvZrQHGlwwu/6+Z6ABBPkpgjU1QuxrJI+6AtMiYjC/8WTDNkR1NJDXqI8Vuj3zEOzc1VP2rIWgGsW1nk7whGzNsHevNxjxW50grsC1bHNBbFdcxTZgWh5H4bFhuLbHKLxpk1plD+fiM6xVTa83SMF+cKshimsTLRqVRI7ojBGKdF65jJ/sP9Ff/S2caMvtnnXvOnexyrwoCWunXH1Nuc5CEwZUJ2jakYLfPPxLGAlkiiwMWZ7gry33GTJHynyT9n3Q4+9bNOSTkmlCGpVwE6C46fi+bAYw/iELB15PEowuS4oWLsh4xdbCKQBCoxCQCOXDjNPnQIaRZUSJ4zZfbRWSph4OM82mp8OZ6MSJNx0+/hvsrwE/cuJo3oli2C3jNIyll5JTjUaAwbWkiYVXkhB+5CSEnZXNlRLBXKAnRIAMPLgL6X0WPrbSyIV0PZfNaDc5AdQdH4V2ihZ+S6wvvqec0E54yJVMu+wYabe6lARJStSTnmfSmCJj1KCACsjJQnLhP6AJr4CE9jbqqvuQb+Axc5LaeIRRpv7Qbd0xk5T0GARTTniod+/pb2+Usdy7MS/1C+ClJsBLfX/sq1vkpTJnH020wu8+KTAF3hO+KwPRmyf37Y5zWWHceVZhhg5dvBNlUhTQyBxGBjTPn/6PjZmv9U0YaX7QJjDF5sMMZ4xleJ0wY2lcm0kVtREN60BN2P1RLXjNL42myhKEqGUu9ydjG8s9IoCkjYzomr/8MKJEY5rX+Y8gbAiHzhJsXf8Xfdznx34n9hl6Xz1ksA7KreV60HrdeKAORczJsPpQRt68FHcfGhCHJS8xss8eE8BhbxQM37IyMB/sbfwyv+ZOGg8hWiMR8pJLX1g+8ccUq3lJN1aTK2Z6sZrnyigbbTN/fimxe88QUuASxAAziJ/nxe6JffyhjZ/ul7l9ysurPf5aiUdM3ISvMbKf63BHmck5RFCxzR0l//vxIyRcOq8rn2j+bod4eqR8sJTItIinmVyK+0UnTs49emgwTnZhHOoIyIezsRcSvwh3kaYOXET/aKvQ16OiuTN9sbq43XaYi+H3jk4YfD8zbD3QDJz7OUhz9VwybwuErMa7qcS+cuFQLlMyoM+JvBK5As5ZV5/aJ+jML7ZicdlUMbuBm53ACoqsZC07J8sCOU5ILSHaeSIsJ+TSh09eVJ27dnb+hnpxEjCObS0UF5amrpjavTuY9R0wfvLalMQ0vzDKtLI8vmnlWmha2fxzTZtIzj1hwZ2eapi2w7Ie0pFJz5vyoCSR3r9SQdMzBxDkJGfEkkhYnxF7WbT3yYkdQR8R4Z0Zws6AEWJLI43btXkjHSLMi7KFfBnZ9gdZ5hX7lwThlidkZiemkvOV+nTlqhkvl04zSh+VIt48l08EDsOpsuDCgvnAxsY5qS5rpN+M6+lEsLpQ5TkxmCwkpqpp9kfFp576pZvhfWsVfmll5bpSNh0nVnmnf0xIDx50OrpJDxezhO7g5XCIxJmfPqXXMef6DR1z5vxGKY3oaxQS05UkWJ1Oia7EN7mj2FtkJZ4Au+BRK8ENcR5E+Q+OVJfxoDfMdpC6tXQ8B8d+/u8e4jIo73rK+24n9Rwbt3H+TWouaHOGSg0G1aJdklURXdtE3HNwfOrlfPMVQx7694c/9Af/c4ilINlQ5OiqIlFjfnqX3ZAjR8Hn89XQjsMoO7d32wnODHnMAmZrP82dogF/IPZLQJ3fRUbvRwU9PajoWYaoxqf3kf9GSzT8Aw+ZaL9wY3XiW9Of3K5K3/pl6eB2aLLdvyIuIasCbEY2zdw1YnP8SiZVuuLEYiAGhUJwsuD7hUvJ36DQl96old58O1aQzIIKjqO/YWpfuMqp6AZr8ZW0wZV7wE6VGqWJkbvmqvyamxTyB6ZnCznPy2l2KmVr5G9mnblzrIb4U0NCEdlg6eBdiaC99/hCtUAGJJgPDS5vc5FLeslUMpULsKHSIBYd4RwQix6N6+ru7aEWuWGk0JKYoDLYNWOtf2213rOya+x7t4EPdPPjniiKN92YnqzXQfJ3xOqhq5n/2XDVn8uXionF2RIuwkQ95zVKSX7TNJ77xWc88dE384ZhTMwvJlcvW002vzDOwh6pHsS4UyWLZfPRdLDoShWRVlxP9+QlmAb6rZH70T0bQvHaNlxMI/beT89SUvjLm7Pye+Em7qtPniW/+Bub9n0bfosVwVsJl/JGKA+9b/QttnnNXq5Lr5fZuUV92VmK8tIv60jyMv+6c4s8dbbSu2bOFYSO9C7z3m1ZdR6r/p1o1Wcw0PdMIpUw6krtdyPb+kK6/QYPo1a2+Y8Dtgwv3/Ii/bzf2GHkqv1av83Ya7bj6Tdf1efqQFbju9FqXEMTnI+ul0tuie7vbn31uBEM/1GL+J2tMf9v2/KCnxwg+Y9a8Qd/dFbs///alrB4xlC+fwM3bRZFxiWAet4ZNrZ6K/JywxNIlU1R4WG1uBckhlXy5UaCyiKMjQe46xfw7Bd4v7siN0oA4eSBWhx3F6NazMBrVatZ3gQEwG1QwzNrpJlMq3I1qsqhJm7kR1bj9oJDRkOjrwH+b9CveSnDfH4TaMDpV45RwfsY4biC7vbzgf++blMV/PD5ip4yEe6QS22Twco6kxf8wAX74hEVS3a8yYienRhcQP4GltyunD96ZKL5pvFv0WZsrHkG6OV0b7UDreqS0YfOOSgSZL4/NDQ18uF5HS7UodizY6/aVIEf1oelToW/s0v0uiEVf4iHM8famGd1hxdoKAxASJMRgMl+dHtWhu9amVOxl8beEvuL0RXI5uVotmmpuHGmWUet539uyqL8qdu0sE/Z0IJ85NL/dJPe5OwfbUssNF85crqVh0vFd7nDnAjw+5rYi2O/z4gRMSRcQogjhrlTo94WCqJBg9tyMWqvtyfpe4bz0WUXekbhyXchnqvL0eVJiDvRNdvuwwICX4y+m7scfRXhJpaF6MU0WChDMU9gDBpbLqiKpLdP+rgtGlslDEr603j0Qicyj9MkL+8Z0W/9ZARPXO7yO8QX5Rjmzty0lha5lfnHG0kFYjEKREX8XSYkQaRCUJwB30e1JEMToNlgNe/XNKMYJJbzuXMqpUO5/JKfKBtBkJtAXpE7VKqck8svJ4KikWTSUEdhFQFd74yRpA67MMmA9UXcUjRoOhKZGQii8OoPYUkC49ms7Zbwx3SyhuFDvdqys0bWMUvuUfwlZzvP0QNBi1uuQjIv8DdAEsoYiZM2viFiOG545EPSNSYC8mAXwSdRi1MpSJw7mJQ3vDQm4wlPif3/7InMvhM3L8yTDzA6YBZ2ze5OLfrJmptRiUuxQHlWp38jqFhGIIOaSD1tkT0ERnp1Vz5nSSrb+VSB+RjcyFWqwoKAw5taioc4Vz2J/ILwyBXjcU2R3OadEplUiBN3XLwxXgmZA1EnGkKEhaKL7D5IeOOZxdE+gIKLip92HzIbOY5pH8gCeEArBIUnGgb4VYgLSSTUwxxGhuzChBmqmjJyFRHSAayLa2se5iwWJlF2QwTvifTaIp6XkV07Zola9u4HmErCb9cCxN+9vhJZvGMwZGmlwiyukxyu9rgUd6WH/RgPQ3ksHPvoI4wEx3ao+eGOltBnC33dRUWAopEr2ZCfUV3Lt8hIzZEjzdemvWomyJoiTQadwNtdzB1Ipwuaw5MHSZplgiihgbKQFjTOMgyNQ2LP8KYU6EZAvAMEnsr1YLrJSLL7r6RG7ZylTczO2s1Yeg80CGEU+rRn+YuGJIfG7mtxMU693QVLK03O+M1vvpRZjPP59DnHTlbnrphduD7M/qww+zs1lV3IBlMBSf9yWpCEj+DbkP8F8zct1E8VSfaXIOZ2TsFLTKLW9dIHlomK7NSZb7Pfw/rMo+5+40Y9uf7HzETSLlsY6uHXT+T/X5iGFxyaXZM0/CBNw2s0Dcd1LkR5uL+aQy/uycacUcmr487oQCC0L3PPdmfu1kbdt9xatp1w+3jizQvJEi/Uu8ZsFG3cMZtStYgxm/87Rs5eRMKRoQnHYXAMXzI6Zx/LitjdxJDM2DAY8+SN/Ie/Pu44S/PBTWBbt2zoOczctQn/4OwIvOqTbJM+/2tjLwdR7xPRCnDR2dVVM7WVlYnSfxv76JefY9vGdNyaGPLlQlW5dZaG6/MtpR0iYVSLqMC4fS0EunJsdvmi5bWrKvPVzspN5qY0EvaCYMO3S53YD486ZDKqDzKajoeF9oABNxUdbkxpgjJAFJd3g0BalR3b5MmOCeS/Gntx/5L2kDhBJk2kF03m+5tI1+zl09PR4iex+DO1cPEnjq8WjaB4c/fi/0KxBULd5ghL4pTd8IBai3g7UU+bSlpJOQKsjwQihKakFMjSiclMRmHiOsnydJn9xbqB8dHuwLileQPt4Xq0h1sNXtPdYiqixcQyfzZzxOoEjpLI0437AyjzksAhVuHvHb1xqVGEv+HkCI7cvrGRSllsz43UVxvMTuzt5vdJpkCnQb7dNw3yuv5pkD93rdd2D4GkShPu3FrXFAjiQd+Rk+A9iQVPUbDje2Y6HM+mMx1kagRTHalwqqM11uEDhLplE1GQHVqp19CK59E5PBy7OvaK2Nu3QyVtSN9wc67iXp4RBpuIn29rpe0d1Ep7X/Oi0Vppf9Ji5C7sG2wiskkUd2OZiGOLN5822E/cnFQa+63BbuILxrQOz68sLT9jsKlIzvjvY4I67Ek8Bg3g3x65WYP+fRNsYtNtnznTqN0aH9wzPxl3w8HseDu8mEbt0QcGtw+3mTNYYKUCVehfbPsv1Tx7dm62JcF/Jy+3NfTlQQ19sspf4C6gq3xH7F4oiHx2NHSDD8khLKJWwTQFGaQJ5/t8WsdgQVpGaITlzIjtJvJoESOWHuxbSr9cvK1ATg+8miiAj4iBkyhAEqnyiZo/WXDD5xHnhUTSF0Vkwq+DSqwDNrouUBIBbCrULPJYJeHoVUQBz+uiWbJ1HKFuHg3rmWyuWuLkrOG/cSsHNyhykzMmhhNZmEFyI6Gc+8nS4efVsilndmHOUU1dV1SDg4qwhYE0Tq2amg6fSQhRaBkXjVUOnXKj6BhJR4GakQ/mvJ5qwNAq4cDFTcsfLhcna3HVgkZtemsnffOUlsYgxwKBd8jV/s+c2z4vXrczpwV3NgyGnTgYls6SurBTJ8E3z5K3EFEOKnThboZcxm9vJ+Wg3yZ4R7Kx122XCzBzx47kYVPbZPTL/PEWEzM+VgDPQGjv0adAx2Jn7vQ+kkJtgGHwqh24qv9lgJ2QGJdbsNXd95o+asJiH6eAi00DBcS0VOxS4BWESud1uv4HuibQRgJNSxH412W8vErdC+HBEgx3VY6GloQaAbrZ+kgk8HoAwklfsHhihnyCswvrYnsCAQITGRSnF0SeyrJSsgEIvwumT5ZuAhyOfE6ccB6JO/0P4ApY5DmOggNvpO7GaNcTe+P/YA8+e6kb1zs0ld2dDWa6cD1ggMkDh4+X/75tlczlQ6PkqT/v8kG+pMsHOeAvfNOxB9ILz+RF+9wLjifrV3chgpMUEax56dXZLA7EyTNf52rwpDwMvPY1tM3foWmQTtMKcUA2QoNrUou0tgyZ36GWsJ1OFIzC3OGeJT1NSW4/05rEwHakvu8tvBDDGvvjqzypXOhnyTddZZ+G+gIAPdB7nbSSfLNqCNec8qulsuemTaFQzh2vWMmEb8w24rLHVyw8MzVfsMQ4vNTfH45caJP7RzUpbwN29QJ0ryTfzihIkDAQpogy+gHAujGN0XyzYOaceiGIEyWrNNo27yScC1x3AuUU34uFvvZGMnpmmhPzS6nFmwvpVJzIvIupi5dkMmL2ONyMCS7uhpSM0y8MEas3kXYlAs5Eu5LPFlrtSvbZqq/YOnZf3NdKfPP5dPfBETquCNnDBWZy/7H9Ux+ZPamJXGIi5xGEhJ/EpluGPOePwdY4GXtO7K3RLPlwTHY/sxJBV/s7pgf72fpKKK3c/UmmtimEeCOexpMILUN32VS2C51Fc/BgkML8CUGh4Hc5bTP73TwaCvRDtZFuvn5TsDC3AcrLvqwbnv2DNjybseXK5KRhwJdYFBWRoro4dsVctWYT1Qn8pPisRbkZbGnlJZvCisdiZ3QjvaS1vDWkl6HnZe9lVQGNo4U9Lq2E35dtfdy55/jtA36ZmwlGKOoY8PZMTRCBOZiVUprY3KMMgVIQXl8rZQTyqBl8BqdZSiYnaVyUC06xefe2wsHsK8RsLsk270UfG0c2sEKMJu9C0wC9rAJqDHr/nQsUSeEt8DNV8gkUkEW0ByUy2vTfQyGguTNf4rQIAnpr7A92CAKiJ3C0WER55AC1mQgn6/YSPdx6tA3piFvCXvBau56u/SAe9HfboJ1/fAip/NfERILcpqTwdLR4oOFp0E9JemAxGKsm2gKK5AOiFTlccLIC3fFWsvnAID40sTl86J8H8aHnsIIix+E+E1dtXMWqUiCf0HMpm4j5QjJCwltznkwgq+Y/eqkUfmEVOjNJ9U3roUW12MHYi2JvIJzJYCxkZxTasNWlHeB/jIEgPX0MsIexh2/7B7aywkPKifdtCCo5LfBnfzf4s7C40AJ/OHEEc+uNm1n7H6aLhWjty+odQ1CAO3oxpkIHYwpaGBNRzSNn+MXABe6NfX4z9KCwksBQ9HB2ELftcTIWT2jE2f+/fTyhuOY7Mug+hCf0+gExfH+bQ+aXevhC82vzXXwhZvH4FcdG84X+tYsvdCwzx8pBwmQV13G6tPErHScr5iPrRhDE99oRVNWbZ7oj6PYhEfSidVhDxTPfi9CJO2Dy+Texbz4MAOVmYyyasx4aXuPhleWdwSs/vrmI47TAM3LiiHBLjodf/nTH8Evmdzdzjn3NyoM6BJrJ0EPspl4o81sRlHkJrrLf2eZ5qi2dWNz4uNjfnyVE+cyzPZZIVrspZOxsh61evZl1/5P26SPkK3n+jhFjV5/hqtHY1XvXG/jY4tjVQ7X2v7lNQ1h3PGSx4G/XTNZTN3UodIIDBIahwRFOZ8Uj1JSwjd48/nTWtq/32LNa/z6AhvLbvZYMd/azW+dvZpW+11klx3WGrdLQKa7Pcg5W7RDoxu+IfTD2ua27s3A7UasMWeVRM133bm126+fbXLmMiotzBya8ljqDXJePGuTK5FO9g1xccTvKlzFi51bWxaiXC55xZ9SL8HZ/hNM+jprlKZjHfA1hhoaE7X3MEAw+0Qfoc+uCgnyIzIvDgfsebZZ6REYn4ehiBgLv/kMCwSdTUuJYC4GXKQIf4vgmxfGvEpOVhcJoGJ9tAE9ShkH2p7/dZu/GZdHOAK63eSX7VZB5j7A/BfSe2Vc8PgC8zzy+G8O/is2uzhY7EP65AxD+bRe89dh/pBcSXXD9hV1w/emfUubu5QvurqU5C82YhDd361Ly1AWrzIXTN8z+EfZ3GcorOaD0x2MvQNPyw7FPDcfpRyH1rXG6XrD+rPrL7ibR+zUIrYaNAvIDwkn2tj40354AQce+4pwheH6uppBmWB+ib5xlqvf6TWD8z2VkH29LWg148Zd7AP8aI3lx4eChoZC/PZeLC6pJUH+tB/VvimeZ/zF/0tsP+EBfP6C0uGex3N8PWIMmnEp+iH3oTniTiKBJJH1zNIJ+M/aR2F/FvrYdEcRsQ5d8q/H0tK3GU/PF29ZTf8fDGmKnb9mm5jt71zaEHNE2TnFJqPgfi10PSNxfXerWWS9h+KgttU5u/4CMmHYSjegPoVkHi6t7ydJzq+ERFeUOeRJz7CfQ47dzVO2ciAaf/lvMqCQWQt1gn7/qWia/d3XeCczLjy88dnHysrpdNCpovc8de8wuNjs3M5N2yk/F5XxgIXvZxfthqJ2eq1ZOVOxK3n8drkdZA4cYlzbkowE9QPe3KOCuYH+TVfxKunB+/dStgSXjwdiSb9avXtxz8VLytaSzyFyua8tL+HZabSI5U07iqhA51clQzdcfwNvgTGwZpITboqmwoeLzkH0l8vPkQ5plC8Q/iDwKd3GkAXKE+wJrobkzpIDWFg+y7D3D9eCTlVI1decLfu++C5/36F2vxg+ePXRob57RTCLzo6aZ09+pz+AhZBO8zeuGRF3HS5X8PMNY+dULZj91y/XVE/trzB0jJdkvEI+fuuxCxqodmL38GO9Ma0zz/k6P5hq11PEyhnFq2J9LWtKhbBGW1QF9WJ+iD2svmpp3bfywuJWumiQU98fj2pKqbncNQpDRdZ/l2nWH6/NXPe8S8jyrx550nD5Qd2sSuO+r7T1RrZ6/u1LefbRKn/cfkuft9DzvTPi8d3NmYak+uVrQ5fza7ORKQWeQJjPN2zahW3uVZQPilm3cqOjM8nbXKiyDyP70swpZ/iCdSuhKOOaZaCCC6080zj50m3/mVvIBf3PtnIqWQ4FEEoTPaAkLStDezHTD7E4NDjfsaabQHcbPGhnGF/aG8YzGvEMnh9056ZmsEkCHmFzpd4gqh9tcz+dSYvsy95XcbFYPmLd0h3W86ww4HLsKxIuzeaSN7se0Lglpw7Dtf47ndj2W0/+6fPWzjhx51jXLy9eQf1+9zKqVPeeXy0dWS6XVI+Xy+XsqzCtHPrq1nkdnpTTmK12PopmcWs7IfGplfn45JQip5XkLxwDSAMuAhiYj2NR29H4IlDi4TR6HkbUOPtndGl3tiExkmbZcJBlMRbYg+EQwMlSpmGaGiVTgj9eSiyQjuAySl6WDXFTzEETdy9FXs+GpQMVpwz46099VZSaGMORdpAkC1BZ9wkOgJIdQM5Lg/2BEmA7m1cCQRxqTVgNTp9YTRDKSher16VtZP5MRQoFJS1U1v0wEG99d8lSN43m5bDWfqVmOmOCho+80mPJgA5UzBlui72Yi8UjNFA2xIx6J/6Vm06F4ZDYiSfSoVbRn2J5ElCPB6P8p1Z2emq1xms3HAydenZkQGU0M0mnZwqEe59S8lZVx5Dx3mJ5X4cyP4Spaxsjo9Tji3xEOJcIEugU7LOWp7HQCTcvFgxgL3cv0iY1HciFM36045FJ0eylj1H08ylArbXWS0OYcqtiN1XqUbJAmKr7w8cH+MuNP+zOFl965dPkeZGHXX4rL0kkHbtXWkQFOOs13wB3AA0SnqVX29q6b9P/VZ3B5Dt6kP+XgQB4YdkYgLSCvouoJTTL2FAVi8S2qako3oHod/yJZ1JVd1bjQ2OtN1TI8806WNYsmi07tBY0rL+FSc+dNnXuhVBU1EjySkLZSHlLEOKgvLrRPdL35qa6Lt0soIbp359RsJolZX9dMzPjl/ZjSZpxUFjO+RbwGS26IIpkgllKBzfw810DTXUn5+RnEnOvQRfxqtIh3wBDxT856EV2qMd5dUywSVfB2SVFg+gqKViXBPKRL+/tgl/hKAm0ndHLaRQMmz13xAjOH6aiCmUo44tVdFYOlzx6rOHxm2jUd5tRDturvkaD1LFrAyfBvNdcIqwLF8ZXrgulkMAt5dC+pPL1dEczkXcY9b0YXZHfGczl2/1bigsPh/WMwmlSUAM8j+Vtt6Bm6FB23y2vRid6uO2nQ4HQmqBPfNzve0lHsTI7TU7p73LyvdGSe33VmfqNzZubszgnLONVEb9GYr3po2B3ZH57JP8D4uEHHx88FTqj70FHm6fB40lDV+Ll0zFwnY+bNib56752amEgmOyeiT05Esmoz8w2OyFHY/YWeNb/ncPXSm1UyWlyfmxKPZfYYChkcv/+fg0UDOvC7fHY3J/JGEUkPb6mF6qT/0e8ZtTJYhaY2MTdr/XI/TZAet+zPsVMXwVV6LpnQd4dv07VRW3Rt8wdt2wVpvS34fSY5l+zsv0efYi7q7L33dfaezt40xrl6umeHMX0b6xsDG+stdFtpnW11zkVSjWyrwU2lshucpbu798yFLzk61k5pFcsXQWj2ORuXy3jI9QMsXY8efL5dNjNi+OCXhtfNoAE1KJ2dIPjh9xHK3cV0gB/z9Dd5j/fbxbQ5aTGEG1E7N9lfTwuX7FeB5TATzvTTh1fTL0rvyZGM8DaPMLd42aHlta75A+U18TO4DtwaW5LrlcEa+9R1CE/DOjw5usr+ABrwKl4BSYXrBOwPkaE596dpzr0LY9xPjN3Zl3OXunLupToQqZ6Um9BwCuNa/3Xn5RjvboQJ5hKVVjYY9t14YqYoSskwEV+0fSTiueB8RuKkSy4LE/ELLwLjlPHHMcdh/qErWf8bYKFE6+DFpHXhTTFPR8xrnozTUgJirtNCEQ94MgM65vnnRHn5/qMWpO8L5j0b2dkwr+lK3V8FRfq4WbHdGu44Sl5pFTWLsfNil8ceD0ur9R7x6rBnHIRFjTDk6dGHt3GZM+LpLhGim3TJiXffd+GdVy8cp49Xzq2cmH3sNddeXz2+t/rXrScnkgfXfO8YRc9zhj/cBOQfBp5uYP4zeXbFYvfDy4DmQZ5d87c3qoJICf5V9mfQE9qPBkA0Se5FgOo00yKTNrqOgjaHe7WL6xNJC5V7RfZWQ9NCv3XekzKJlkOtI1tsIba4a3FbED0PZjmSEapHwG6kN4RvQ86tpdBsgf0rIjWDWeta+cb9R9ya69Ucu2ima7IKAz61mlQzTmnCq7kg2DQ8e9IDqppVCeFUOn0vPLQ0kbc4RYSEIRow7CWKKVuqwMFaTE1kPknPESJNhTqfOLBQVyWU3TzknMpOftafSiRqVpmHM4wk6yl/0iy4x6v5go5O3qPAHFVdtb4fkYavwYUs2bVksJBJzzleBVxfXpYIsxx/SDstDtTV1LARk83DgJjhVgb3F4EhlwrHgS4OZEEGT1GMi1fK8PZxAJ7y0AgCm1ayBFj5CHpcmzRzzPMCC4YSkkgcbRjyUxUThmKRUWlyxwu6pbohOgCvQSbmQqTvSUicYgwleXVCP6BKTAlAoyFKTvH60eaDwRgXNt1EdNORU4152/E7H7O8/Jg7j0f//uTi9Uv4ZU0vUPJkWig4cep4YpRD4LzYCyEOvaCP1U7srT75BvLP6t4TzEeUyrlri4dqhlI+d/fauRXldzGvUsqq6Lyy6TwEbOjU/nBnvw+tfxuzasItB+BlBb6bUEPbrS9yJZxUt1P27qZst8jnwNQEMZJ0Sda1fMQ3RIukB03kNjy/PropsNAozR2YZAP84AkZ7j7iqBXZ5RHLRvbNbVTxWS2UcurKFzzq2K9et8IW+2HGxoaYoZGxQpwirqG36uv0GucVKaGZFjkJYWqVMzrA4kUtXHJ2LacoubXZfqCRRP43EPmJ2IVgJj2dLE0/rXofs7ZOsEdPXVwayr3u20SNvpAfgzJ9Uzdl+sPM6E1Q9OYTizcuMW8ezqre1be7jvfshWZzQzZ0lpWylA09RdnQ+1ubw+3ZHEWVuF6yewlZOufZM7MzLbI08x/92+0f+nbJ6Q/wSpvorAwO00ebCGvlAhR+5vAzSgzGAnzPYdZfU2bDwwmP+trxQF+j4q+/bs3v9h5MnxtyMB3YNx7wq7rGsXWW5sX9JxOh5n0TkjE8ktRbwML4/bbobr5nlrG7X78SeYauLoVNWbc14bOP6ZuQ7KZh0Bps1wrRkKm1/Pra3sWt8ws5G5IMkujifZjVTo4RAp5hxhBh9h+2C4YFgSDsZLBbJ8op7HFQWm3ZyBjZVX+qpPjlpFNPlMoTFdmR/RvAFNdwtAVyQX1aRMjIhjOUuOoNNa2bxO3Nmp4sNq8zspqG6tlDO/M3vBlTFg3Dqbv5AqjXTDWrepbC1Y8wCUHBoCUubtGW08szRbgiKYmaAXm/nO4m2X8VbdWskpkrPa2V97mGHo/wTtzUCTN75ay/MINwQfLBEj0+4fQJtHCB1mQgx8f8K8IoEOEVayVmg0veeewXwXxKB9rNArT1PdNi3sagmAkSBtY4jlawRhxCqeTJO3JTyDD0wL0Xb3ReLg3UVMDuhnmqVc7YVSNDUgXSwybsu33wEvU5M+YASXscqvO3kwgIfYLpFkFuN0b5XSOMnBZKdg6Ri6HsLCIV0wN940ijsEokUYVzttIdDKttP9gG11+tM+fQMl186o3p+bmZAHU7WxmjLGeegpwqzvKoxFW45GU4tnpIEzWPEGBIxe5rFZ2+vPk8Rg20Qi6BJ5g6P90VAVfC5hf0JWfaPdhfxYPCREr346cYPkLITp+7Xm7wMbj42RirFqkgUGbXJ1RbSYNYxd5OKnisdtkns7SvP3Z09hDuXMnW9OUivo5vrTQbj7xgsa8X+2t6PraIkvMMF8A85kLU9O+D4simc42emTCsfAiBkTAghnnhPifDGr1b3fba2ChRC+K7z9baaifRJ1ucniit9cfWZlZJJSuEDQ0sNfvpMCUJ1OYSpDlbKcmcbxx6ynue1kwiL+ikJKiC9j7+vl9fJHlGSm9O3bB0xd5c3PyLqWsvWnweczcZD2EEsudRhYTrbacIQsNLSNkNOJY4+eYMFhtIT7jaz8Bqy2LGqXuFvJ/KsKpNg4J0oEGoR83sFCed6SM85xYnbL1WzfqsahQpOYJJe4cUnNAiUyLGi54nkmFcjskWz9XSEj6Lv84frLxSLh1YufL85vdg8WtrSgq7fQ4cgg4/a9ZvfixtK4bFc7JVY3+XuQ/jjAKESxEBRFbTgF9wTgv1y5ycInKirWFckB4tGTeNJCeeyEGLFhOPokuj4i+5NKLCgIDwc2O/G/sz7PHulT17DHz7Q6IxNCSY2e5lvXqLYPjc5qPixk5UJE03xahuFBWMlRseFpiL7az16eTWUHHmnk6sHO6PlXu6YuVDzNtGx0qiotJYUTyNxkptIFYEoLXEdr4AdHBv7FYwM98f+/OhDdCN74S1TnDYQ4KDouRhIAllPvrryvBX1hJe587ozdu6AolcGa2YWWW4x9wgClddEdTKlJQlFvecYjNjXBhaJzgWe4OD5OFiA+GhSmwww1xN/w6KbP+LmmUhFV0kx7tjSGzH0BRwxuIiJpDNfLpS57L8xScPngLzV8lj8ru2p2afrndukcd23yIZcovcQ6zGwmBgTvRHw1MAOKsKJBQ5WQlkJkn/hshg3jL0lS9PFRYtGhUGzLpZSUdhRWOnO3SSpUme84t6xjdRicdERMlfQXW3gKzxCHz57sY989XYP8Vi/Aj98cWW/vgyNQRvTRf2hBXNK93xYgalMMjlte0IGqZ/+HAXMfwkaSYELUmlDJQJXXb2VfLBy2+4/MBQjfKXl6fKbGvssHkbCbwrH0UDr55D2P3txhEF+WPYdjOPOfuQYtSOePn8+ZcenXfrsIXVc2K9YWZ9i5XPN/Jpd5VUVJCtS8Ke8LzUFKsXecBlquODEZiFZ69lTd40qdkKhA25S/kLDx/ci6j09pRqqyXj9L93hV2lP5g+1Ak7kJsZoR12Vw595ZPMVtjZU7kRYQe/BUYEsirQm40DdxIzZOytADThorGIzF00ewqYy4FUvv0sChimq0AZWsFsULAY7M5ULMy1nbKkr2A5fe06FQqrJTCIR2qUyjlMsN01itwqQuA+zd40WKS8f1RZ8kozjUFZWpjcje/+qHULE1Ltfwb4sx7LxK5ssRYH50MIU9hdbcFbQiUSM43IvI2VxsAnymELmOQgB5neJhUyz0uceaOhC9Irn1284IJj2bWJ6cXE+RedTM0ff5JVybvZxqxFLO5QUhhonlq6Tigs/4cYeXd9vD+Y0lTGEJNoaDGfFVlnupG94pKDpDm1UM2cf3QP+69S3lm6dvryaxjBsouP3b16RdlIQG+AM5oKxkKTiVRKZZjcoZRbUQGF5BEG6hVM4UC6+2NW9uwJeLfE/8nfNV0A+Uap1PxGMQEBTD5B+3twImR/EsvGVvEIYy2jc677vCUEiNWWPD856yIzCFzw5J6nz4lf9DtWOkTCHwPaHykf3L3oE1rr/Inrdk1ee83F2cD0J/ZUFx77Z3jT1QWr4uf2LVbjtCFnFqzUnsVGc8FC8qRT1iw7m54Ou3yJE3cdrl5w9CCkZCQ7l6zfurjnirWM1ZgoXF5vHNs/g2Gb5jfRdTsEIpOcqOWSCw3YbeJNeK/efAbSoqTnmRTniCojgYgwU2jv+wDTCVy0h4J7A4CRu3EOgyHiVku6Xq6EXel62MZY9ClbDoNEq0E/XvTyPrzo/jHgaeYSu1FKeNashwg7/Q3GAodM0/WsSSTFivbyE/eec9eR5oN9ILZeP7q2eHgSGefR3WtH63rznvXKT2wiOY2LxiDbTITackLXLKrMTxVqmXneSLnlEouhI99NGTx9ip/hJM5FRXlp7FmQm91SPdmPRoO5v48lr4Prw2Jf87/1mFd7IWtcxb9rkvIQk8bNZW/K97rKw9vf/bRmGu2NqDwEKGxa/p7H3/vrSyu6RcaVZn6lH4ZuSJ6a+tbK0vT1Zd6bgHKsZ815pz+Bxx+0Hj/zYD9SXWd1u2ZTpDqfPKkWAZIzdQjISIEvKxSpLtVOGjmFfPbqyT0VSy/tnZ3dW9Lx77vp6YpZIjNlG8TKQULhohOxkb+wPBW9Hw9QAxBYyaUdzm8ghjXEcA2NuJupFvv6qLJLP90K2LC+Q7Nl21RgX74ukvxju5pzWjH8adFzjUYg9Mh+fH4AoG4yXRqv870A9H+1AWjmExsByM0HGCUIPBrcnOrauULzql7UehCWfs76mHM8ljnzPfYMGjdXxF4d+8vYT0Be6R85QxJBDkhC42x3PP0OLQJ00FZPM0pEyjiAqRwP/mBCkny/mu/R7idhjuJfXvvVjbANukJKaC60SqZqdVHvFPxRLkpl6Q4TyqQ1i3lG/Lvc7W222uq67iWOL8hFw2+wBGLH4mr0X9uy3lF133ZquWPCJnMlSmBZlcCbTzu25EpxLJeMx6zYtoAaXEViQgYW6f84YM8ZW08begbGYsgDeQcvF3Cv6mImBX+K59CXidTJRJKTug25bvrVuFhNQ0J7EnCGLiDn+JZO2raKhm8DfssNdsU9H/YptyJvAsFVlgSsky7ATx7n/3MU+JMYzTfj/pO8BhpBEvlOIkHdwX/iWfRr45Txip8lndGTKnEvkZmrssvphVR61kdWZCehuUSG+fA7gAnLSwqniY6r+ETBHf0mAYJEltAo2WlN0mBOQl+JZpSo/5c3FbwrmHCfbhUM/ByWwosIb9iigMXDWyLaygqnspfqaStjg/cKXxMT0obAJJtLcRH1uK3rradH3loQbd01ZTKASJ7KLW4iaRZMnsjmc3IC/rl23haRLYm4snmCb1JZClVJUS3Er7HQoYzN4da/YyPHjX7DDaNFZo5IU0M1D/3a+qprP1tXPa3jbRd6avwQT5BEgxpkLZrqSjTVzYWpLtMMtuah0eVZR2XRVrRAA9/HIA18msQy7HVaNgvwlXftxFzAX/Su4/8pO6fGUk/7UqS8cxjdk2ePnltfpRI7HV+7No1HLDUWWjSe2kJHOI1MNS9T++doUg2LN75EWiZf8YQR4oPUxA5mhdTE7qaWxKeKKTD6Ko7XpJKdV8BNbL5kE/oC/8NoXlJ7HsCttlVdOpeK08OUsHnqvsG/xnBcIuqpm9V6zZ5+1JSO+LdNonKW0Ovx3xsqHVGH7jEH/5iF2NNib8McYYwJLQs4esKVh04Bh7ZSEfWEqs+ErlE8ffmB+GoY0O3XBLn4ko8MBIkImX4gqmlMF72lfRCKhK/fOttxboZ35BpPe1xCCHS6y/XWzxAkmNccSKO7wJXXTk4tKdB/wJ+EMYdzChhS0XPqgTcH1yhkYuQgEyzmSgOG9PBUUjHXcPzO33jyXKKgAW4wADeyCVjX86QIA00fjA5LEXYdveyCA2aKNZp/gC2EL4EplJ7UjbSqJSRFAQtFEC1ZTRLDbY+YDukc82wMuJeKDYpLQ3FOctUgYNkfVtYy503OHl/KQPUVzUMpvxQspzKLQbJmmwmBGDoRsTziCCWcvj1peylVJ6eOEKi/5XqGrxKqIS/GZQCcQsot5o2wiPyiasuEkCJDbBFRZKhSivwwigcmikA3uAonKCfxLjycoihO5cDBK2Oco1RIo8xiuWKiHKndkRg4Aq2BO8ms+IDaXXRKreOUPobcXe/+W17dz/TvwAFBu8+1Be0OR4J2ONpbgnbvbF7ZEbTTxR49u/e3iBF7DoTTG87E5Ex7esPq2pc83UMcDqxctC9/dX3BuqOC7do8JOsmQsm6oMsf/VojQFI6wX57cDzjpT27M1GrVBNkf5p2a3++ftgsxdyZz2FiREax+QJY+X54OFRMtkzI7iJGNMsNMKYbU+EGDutKjM0shQ14v4dedqCnuKgMlzHEoqOOWFrb6PgcmJvJD1ESfHN2Jg3xBTi3pESbcR0ZO1uGeAo0H/Ss98Z7ZEsizSksufqGkC5DUllFn/fjemHP4ouwRVMhZUZsKxgC0JP439ib1vPiDza7sBw/uFKGaCgTyVtSe33NjCta9mgh4xNthsDIoLE4CR9Cqw4aDcvkAtDU6tAvBJGmFukXghOghNGQkPlbhp3I66440gpYGszS6ag9gH7fgCbjh4auegS+IsXAumE30RYRrQbxDyz7NL6GD5c3WOlb1qWgvVWHhwaz6cUmIG+d8jyHrTubzaRKV5xYDMSgUAhOFny/cCn5m6Rqp28M1/epLxlY1xcurdKweNKwsHjtZpeagZhIqVGaGDI7dfq8/JqbFPIHpmcLOc/LARhO2Rr5m1nX1SJd377VLVZPDoYDc9v6C/7KgQVvylzSS6aSqZYMJU14iAzljVj9N21RhpLZbMqzeZnJ4fXmKJlJ5nnrrtpL1hGSHFm5Ohu5iIwUknzp+qv1exurRQ46kkyf+Qf2F+B71EGi+o3Ye4huDzIq4hIacqRaDqGR6V6USuEVXLnR5bOJRawf4KJcJ5xp9MKtvRTqSNK5G2j9gaSx3P4qWlPS/7fqZCxiWH26i6uIommuTjQGKXQeImxLbrskiTQaiJ40aS6tRboQXIJ5K+ScBX7JP3j4aBaZRCK5y3I8qeiXZ2dmwOJHFWho2rtESTR5H9cvciX6kOKyKueyPtHmQWIVZ57P2JDGQy1GHJwwx5xr3s8xItYLyF0ih7TKh8gO0h4Noy8OJslVH+Ra0fgOfKZAxZ49VTyvKGWyPloVCX8qWLt+9TO0PGRhSqujTKaNERS4kmlatoup/h+XV/ecumWXH2BBWZTJZnFx18rKQjBh5QAI0VnNeJx/8AckCg1S7UImGg5oPHdxUU2nfWhIc4aBcwi+UwJTttNxTpIr03Ouu3ulxk4Gnu3IJnyScPvwsucWUq6PXgPqHCRWSlyTvOYFmm/R0wKJnM0QEJA5JalA5CHbLkM7UDBdrr527r4ZqapjZhS1GbSU/UzYdvkyt0Jrn+tx9d+9FUk3Zh1Ft+2qiV62keJGJvCI4gYmH9YTbPvfzR4PIwumwpjKGU7eW0+O7aL2EdGYmhjriIgU18RIce0UUMVfGV9xbdPrMbai2n8MKKq9erMPmxHOXjFtpvesvWGMs7ZfFI1sir9GvJMH+wQYN7599GNtXZCkaOQblH7T2gTdYlbcSqUefZKOTOCZYntAZtHdNqzgHK9oyQJv6qUjOSFbbVRzYnxqcYqzK44z4eoBPcEypl113KrD4JS/B/h0imO9pIis42NONZ/AB9mK9etspjZdy563bTvkEtk1AKg76A4anOmB88ixqVwK/G00hXnOBgWct2CW7WCgUmEUTSVYE+RMJ/Cmkuf4SZgLM/g6XCDn9i7uBWPuks9BAStUuPtVwL/3bl3hbtvSoBEKdn+4NQW75oPblRWtDmjULXY06i4bpVGXHtCoK2xfZnQjK0OGDlJHyY4MHXumCdf0C7kY+OSE+hw5oYstsTkhi4MrIDB7no/o4UKHGtvyWA3ZsiGSv9KNp3bNRBH5qGk6BlUPxwpoWQzBOXz1NIpj8GLDTkG7W43JJ7vl0055saihOeY1k3k9CQhbBD8ybRuTSfKr+IVqMclJJtFr0OGf6mSTkOdLyYIM9wjZLRTLCTXtAVf1yephCaS4gDaVxIdYD6YhDEmw2POWHb6uaQ7SGsCABvsGvw70XTJtX5+KkG4gPuaiCQMNkitAX8KwCrotxNm/l3iMK2W1LIWn2ESx7s3v9UW8XWZifqokGCVLsGSDdAAIN6FM3H6QigfT0zMpzcGkJSaYVAs/LbAvCSUWwbJcyUsggRX8+M9ZoVpO6BbLNX8GK9C6IZM0e+/FlZMVvBygPHIaw9bRpsD02sWSIcBeXeBRpmlubi33LIw4QTwfnbSToIlcA5+LP8VSLwgeeaRdo2o0w2xlqi2onBSmXea5K629Sz7ey0X2qC1YvUIHNrNspAkSgb37mRaKWGnPbK7VOkpo5EW77HrLTzOMQFL90ikqmltTotJ5yFLTMna2qPFuHf0S1Xb9Cc2FGF3WyIiGoGedySr6DlCxxjibp8iNiXL8kFYspGmPABqAuXKe+7eJNSSxpA/iS2iSMLGpBp35hCeuYYY8QS5dbyHF0cwnezVoGeANoZ5wBCJ6hg/5lGGXJQGsBWqC7Sd9HmKW0CNbyLEvTeYx/R1gC6poU7gzgeyTg9ooWGpOzZB8PKfnwWrG7B3SaKXWKMYvQ+xidEIzcGwrHio5B+QBovZxezXYwwVpn0PDZABdJi65jQQmRb9H5Mw0iRgGC46tMyfjVXhjEyPOUKrsqIyZPvLLxTGsl1M8ngyQ6mc+zUEZAUHxPIgcfjH2DzsWGOOgIRz+HUkMdDTviLlqbxxErIXhPswRbyHogjsu3Jm4efRIxMTKFwjIixBR8jUnDJCe8GjeTU2ZBYd4Mr9hal+/J3MYfz8L4ZDtjKXTnxqNozB3XppuiFpFYqYROgm4yCJw5LJyaU/QNJ8TRhxpOKaDN3XbMmeL1FDpQAcw4WIBwLKbEWBHoWr8FwO4dQfhXAe4XvT7gOs+0+9tiFdmrMBjPwl2DQG725OChJooAxpLoABlPtg8DD4XAT8loN1CN/ZJ3FswEJXWmrXP90bRNpxpv71RtNUQbFWDYOPZwJ4EezdP/FymQzzU6wLHT1E7l3n2b7tDxksHmwy+Y53ga/77ODGFwiEAV+kK3E612PMBp359XFjN3ZHDit/83TQGLHf9GO4vP9qZo+r8TV1ep/96fG+YUZAee8/2HVofuKz3Zjt3w5ut+ar1UcAw3h6FeFtBXfPJ2L+NZm6vtpjbg94wzCMl+MaxlGGv6fOO6eZvvwHeXL3eMeAS7UgkHttUJDbZHsuZhdWFHsuZE5cf35Xucpa5MLeLNVICKikMk6SBJ+Udn1rLpLS5R0fWMuw7tzEwT/QG5u6NA/MdI61oSEx+F7J7PLhuT0Yr8Y9isbU+8OmRctpx/ZjW9f3Q1f/sTPRcsqnoeWU/GPbsPsyLPZQt5zcZC9ePioVbemPhio1j4d198Bkbc87cz/4PtLvWSGOp1lLfWrErdmehSVHcK79Fe//0I7FGGpBEIARJDFGs3Bf2nqPmRhZVNg6wUF56WAB1zQv0xBANI/ZnEOKy9ZYQF6YTwagAQ0tx7YAqcYlUiEsDxej9VjHjcXk8PyvJAdRg/6g8DbYRr+cVJ8iTqTGOKBBBRwScNquMYVDFcN2yamV1JUWIbQKMAAPLzltxkXdFQREFG8+PF4Okx1+Y2W1STS6GbTaDXYaNCYKFgD0H0kNGKR/E0ZuAqpf/ss8btUqqJcuF6JAquURSYBBHOE74kOxTXzmITgGEwCAhAhjQltLLBaOkGkkDvGyzbkiOhEEEbxJuSBhntCcMO2/gE2ajURSwXvqZb7P/geb/MYKNha3fFl6xBlm0VSKUVl9bGe0LCmGXBtF22Q9JYawjtxh1ojASlmWo9lEwervXG1450aFVUvise8HsUPa7vhbSfQL2iZizsAvAQFgwagxr1qZ7hokrsmlDDrPLIFRg6XX5ucm9gLyMavLgEgldKUtwNQlbegKLqdmJYEp3S5CCh/w3NHZg6CAYWWe6rsjYUkDdPLKr5EIhzR+oYw5HBye1wGPJ48xx8v0Nv+hGKpigEJqaoaeXoOTT5RR6X9spNN8RwQyUQimv8hrzRiOXyWTRkmHtSs7jnorZMKmgaGlLdsTMoSLW0UwZ3kzCKpiknUUyT1dOYEiREyBZbtp5kyzlZKOI0T+wfmrFZJJo+qFqcc98C4ptCsriF8PZY6dK4rEsRd3N+GJftjPH7lLbcbSpDnUc/WjbRDtbyq5nos2+NF8vbvLEfdyoWvazG3qPMr/W47J9W5/L9m3dLtv30HX/EqbHVbAZ3xT7zLZ4iu5ArdrVCz7AtD+NUAEhb4VEUXR704MfQBz7V22O1p5B09HfaV442nT0oy2S1vyfbnvZCm0GtGYN19QNK1jQcjW4yfkgPht1Fz1iHoMIOQkCvRC425wX6ee3r3h9O650HfmGVDauJjGdQXVH3uw61nJdQdbJ7W5aSl1d3f94OilyP/s19nSsGnt37IeMQvK3Or0LInGVRLt4qNTKQovZzrUkOcPBuuj2FUglMo04Ith7oucWoJre0a3eFTsRDbTRRbRv4e2rfYj8OcSNWgiDl6exg5gOEbm18A9tt7V4/JSRL3Q4CPTHJiy2EPMnaN7KKieUQ35owlvylug+WA3CkCTY71WQ5grSu7LMq7w5RydcZonPmEEzLVnQiMTUGDNF5L3AMbeZFS+np7PkVpDSOLMJvn0uSOFg9vBgwSMNAOtbwzK6hOKL/AkSXqpiCrJDsHMdPRGpwROFQnyhMlFFGwYG9ogo2NEQIoApy66Ki8A7RzBIbiZpzHsRAcjES/gODmGfg2Fgi6aM6wzvRUetiOaYotmWbSC1ZNkVIwW9KJx4fyMhN8ehgzYCy0wjlfdh8iPwovBGraClZZXRlAkLMzr+gm+plNougoUKLOYJomHmNU0CHpDJYauZyIGspAz83kZngnDAQVnAL8FpYLv7CV6GQxJ+d1jwSGQ2QMbvq8EwSuIE4P+GiBEg3VDRF8TvqIS/o4zfxruFvOVRnvD0b8OD47H5RF7Ee+FX1HhD/iqkIjmLvJsMrj8YsyqmDIRn4tSEVKrBq81HEWNmMrggUMEOE01HnkxFuWe+zP4Xbsi12GtjH4/980D9vJ+Bat3DVEEHw6/MsH3V5849Xu38y+vUzoO+q82v7Mg1/I72JYtuV+eSxSwYKl4Rl6zd8m593zpGreyu41ccX5juqpovMXNJTC+06uZqlyUr6uabWnXzB7avbn4HuZWL4a3MMI9q38os7GRwLf9p97X82OZz1ymZ3TPfQQKu0JL5bbEPPFQl8/oR1peVDVTLl/dXy2d2JF7euU68hFlZK2DY/kL5jv5C+dztW/z39Sz+Df2L/77uxX9S8819NTKHGvnfOZvjMO5+GcnNa73GaLS/GAmy7O/ceC0btWC4I1o01iMwO1k+3xT6pznUP+3CthhXRtkb2azh8KU+a/dACsBu26aZ7aF37vRbdrKuvqnbYe3BUIirjPvgs20zNozPRm5sfzrCVw3STa849ov0Art/R+pt48x32Z/AM+8Cgo8wg8VymBpFsMk8g/K4ZYO4Xl3Mj67P95NMieY7+1tUBm5tPzMfzuf2fI55d2+x/JRWkYzpVlu4g7nDz7sbF8Z47rKsu2wq21WNA+i6Jkjhyg6dLKRsPicxV7l5CCnQT2DkrKCz3+2Uww0IM5Ny+HWZVVoGK6Yt3sUwd/uJwdLX7Cp9r+ouvv+gXXxnbHlq17xhqIR/qYTOFRQfMPeUgAqA3Ek+a5HPkv+VVrBNS9TxVomdgCX711oldO+Wme+a8VwNH+MG5y63DeZn9BzoPaErLQE/epyHPwHb+rhTcjM3QkvbaXSfzytresZxdiXpwWy6cmNy43P5j7fL+4yoaGAAENLHpmdqgki4qZVSWgCcAfvueJBClV4rZQSOji45CWzXlEzOkbgoF5wi+9J0Kcs+1ZtuHeZ5a/kcSFAYCYke5IGnzC404leMKr9fPJrAudYhcJ7c2PrsK+BFWWzzw2hCwCASs6R4L1R4cVVBtadZtHSfJXkoxrVwfln04pBrZESW8J2o7VkaSu7/ggn9l4bKXnQuHOsdeG3fdS6SwuFCf4JQErMeCqEcRCVdEWiM4BPk5F9iNjZPi2ZHceVjFg6YgL/K3uLUi56bq9qlvYRUAt3k3Kmi7FtIunOlspaba9Q8xstAujhVKJlmMZdRdM7LGZOXlQ3+DSnPzpGHnAEwZ5RrzMfWNVq78ZdwpaN2qhR9Jjk5ORk4ZfZfeM23U2mNPDI2g3iDTnPx3KICHTdkqYwuJarlisuYkFYQXNCuFYNTTK+USarFwyXDsWdAR4NYQuDoWODfH+3GdquskKM6rqacZ5JzPVSbYB/AWEwt9mvQzPq7TQxGdJigURXbGRaPiACoWCMKWYUUzuG+DQGXVVJokoUiC47yQ+xJ9tb3eFqO+vzU3GmcFu75Y7Rw2bRbtdCQMLXi0VxmDvQQVcd9Z2Sk9EzaI6uEfRp3jaM25shnvduswISYiSqihJSqbmBB2PLR1lQD4ExudhED57DSxLELqpniKm7txDqeUsv5DJSEQluu1Dgt3PWlAdhTUlIXcXmxognTAOhpC9Aigt4qFBg1KcEylqfohieVZaAwvlggsjwC8gzVIhrFopdIplUKzaBcRyCTcXXvA6Frld92rfJarlV782jV4cOqzTS/vJEoAdW9R6xdR0nGf9gSx3kkRNGGctNPfASEx+n7NhbbZ5cfruX/+sYOZR7ghwe4LIwPXgMxxy+Rum8tOsDJ8byPoSkdxdeXWgtLXNxaLP5HSrigNmSIHAbBIKIAuXYeDt4G/GQcD86m97MwWbVyCeBO7FvNaiXNx7WgYLre/GW3Hzx4+2ULrPkIiKdLi4uHCsUDC/n8woFi4dBi8fBcBpJQlm0XWAZqTjbatmYSLR7IRLlg0/KMXknWZsDjTc6wBzcVZ8yoOGO64uyDI+0aj0RxNoc4e7Wu8bymq/BUQ/+JWifdTxvwV8Dv4WthgbHd4P3DaJv3um2H8D++NY+9QqM64LH36yM89tj/7s49t4RGNP/ioffhIzkqsRNhfwYrnFdv731FmNViV4uAiYZoqM5jeBNNMyR+893ffhUIPr4vUFv2KRueIMgKN3WCGFrrAGlawaQOLbhQ86xk1TCTOL9oNaAhUseuY81QNY48/1R2dmqW+YKSMWEl43KSYxhQ4NKRe0K7T+dN31AwjOP4Graz3FDAzE9Jl5JKQjDVvOY4WFLJT2ZzOl3JSyWg51CZQXQ2P8qont0ggnxY9ZRPteWY7MEkEZNjIjU5ZxrwCV0mIv9KUgtIR6+16Or7CHV5HB8ETyStlFDzC1ucG2Zc5O7k7fPiDmf9y4jzjQ0T2N8i2NIo36MP7eTtcm3L5gj9h+PrGiqchLkF8UpCC8MjJ2XLLslxLSqx8vXtz1WoAuOPo1h4DaFj7WjW4G67wQz7kp1cu9Vtt6fZiYSz+Y/je9r8+XrCga2TAQf47bGPPpQGNi1IsxyCF30Bt0rDbf1QExr0LR4qoxvmz50c8EZPLlQqoN/MTjmWqaek9FTanfQdCD4kvCPlI41bTcRbSkU/Ebo5VdjFI94utybreV7Iziya+ekskCm3OrHdnjgp/Ae9YhCdHtmFKBB2iMbBBgqtX8Z03JxSskv4FRlkNnISxyFplDluECiEKcUSjV6XHg3fp0fDhbBH/sL2mubs5CnzEFru7CwO0rxoswDH4roXzMJDg380yxtDG1+hgbUC3PwvYt85K2K6u9MXFZF8JufYRkE+IC3e6baz18oHrxilJ/6KgZ56fmfvMkQxQatxk60f77/aYZ8vnH/Z0fmw0e7oU1399Aty8x0WegrnR7rTTb+q1U2/bgdi60csWzVdtOkS+fLoYH+wq4MeddZZhp5o36KBtxe9td8LG+lrY6W8aJs9FLAKgUpCaRRAJcwqxUounjx+854xTqjVaw/X20jX2k6GUqofRru+tisHGvj66e1x+BUvTkRwF95n+2OjaEFqF9LyloFRUaAwWPBQNz4BtONllOS6A2jHThlj/d/thjKY39x2cywu0Y1YJDZNRDzeQSxO17fdFgs3zdKZv4EpjhM7CRD9o7EfDUbAwMrX11l4sWvdd8pOp+OYQvx0xC4TiwoJkC67C/KHHF3d5lrMp3ujZgY6SGbN6AqYamFEvIjpfF47oQWuHcXLXVs04DnYccQwRjhi2Lzm3epNUXeLmhdPZQmqkmqZ7qSnMbeJU0GJYtE18YWKK0BhIgy4uMQhy3UmfTlBIi2NX01JQ4bXCDQaaBk45ChQ+SNnRRzcwYxmKOzp5S269Hyh45Dh99tefLpjkAFbjC8wt0DXG1oNKVkME6KWH4Ze86MEiUUL2HJw/HHt44qAs78Su2dnjqst2mDs3PHEvnrTRhi5YsK1W6dR4wjHbNtp9OAvNjDAeO9IA4zWAXR3dACF8MpFsV+OvT722XUOoLM4g8bx7Ous91AHHaE2cMJE9KC2d9s4Z8zAwo9/zLC/Mo7B36XA0+s4MWQ53neWNM/0HSC8rkcuOsMOELPvAJFcBfGx2TPkUevhKPcKIj0BaEdp0Brny+n51/UeC3XTdyBjTv2ZFjKDBwMZwvp79r8h931DSP7YyQmqMdXBmXft0NwU+4L1pcLZr3c4YDUoWG5lJErq4oWdvn5QM/yGfs3wn8gOHaH5CvsD0DPJ6NR7d2p0yt0WPfEdGpf64dmIjw+ISm2rgszjqDj5c3vEybPJMcTJO4pSdGn/EZzPcGnve3in4jaWqt6pWbgD7Vm40z8bOgvHPO6hWtbTf9s5ae/qG4DLl6kWC55qj6g1RlITQ9b1K/Ae4ujU20cfqVNvG+xl9o/aQ27zg0NuH2qeN3rI7ZMt5Lr2tW3P2+5ZLxamNjfY9rntG2x72QZ7nQxWfJP9N8QEme/5YOwbj6j5no1iYbyZnls3N9Pz7R1SNFhXWLC64SBPefODPPdt48VyZn1dydN/NnJ2Jxyy/l96nbySag/uTKbQ+VadQckuX0Q2Qh871hlrD0/W8Nu14xWtyHEY/Sg6tSNlG98uaRmWgkw4fSCHKisHBSmer2j1qxt22c7trfzPQ5Y/LKaXswpYaXnZiEv2VIBFlkA/VyTJk/xZjCKKjCDBYSat5M7J6q7hS/mbu3R5J+3pJww7Yr6DIXuOzm69GiOzD9Hs1kanx8C41nX941r/vTNHwdXrLedzNh7Rytc2O1l/y6j1/n7vtn58/7b+6wHhX/fM30FVnYNW7JuhLvl326AU+/BcHSN0ZV+9RV3Z7z8MIdNcGdCgnexo0F4+SoM2069By75/G0+S/14/8zj9HipS61oYo26L1HIxFb2pizkGJf7/iX2C6PWDBOQjPDyKJXPR2HxUC7ZLeWAy+DDUlo7k/aLuE1n3sB1FC3s+tEgKFjvkzDYdQ0TNAVJmODC00BgkZSYoJxM5T0TLXPLXeDKkvxa9TwU/LBRRmc8Q42GU7LOMQOpzTM4kVbRyDMH1LG637sERyENpKKiYhYzbjsXpUPCXE6R+1KVLEJrMkpMXIiiAec5cFYSI9INIYNFUUn00wgEGogMmXUYIlYqseaGiC7hzGdU3ifwfG7IvGZlvkqktt0EmhW7Cpx47+ei07jqepmayGfl2TjMMTk0bsEP24UZUL0k323UJCF9a5rVMOsHz+UoubpfwKcnXnKLxO2pDtQrOu0E3g4Fpgix0oYGBtbsjniXsOdDzciCrz2iVakUPKZYZGdB3up9jiful5kDOEKP3uwnLEn7PiaXc6snwLf5P9aKA/KQ4cRJnvgjFQCl2VezXQc76FPGFFBoeQJ9El6T+fDjMN8fQ8yE8NtofRmdFdHYAvVv193Gh0FUkwlB3N6tnS+Ms1NDqyEgOKmjVCA9Q8Ar4QVZwMDL/Avs7xl8ONEvgK2ZQsBcusDKm5cHXAMoCWNVrLN+0IO4oBbtzaeJ9gJl+gU8rotc4ZxGjOJ56nx3YuhjnAACKjqSKb9mErC1I2Wqkp9XRkOzXYjsHxgig7uZ9mUgBPJOccfmcktyXMuY8yALIRXfhathH+JgWlXkIKt9kK046r1WPVG5nyWmQwTxXKCuEU0sW3ITDkTOh+SQibwuV8l552yDl98rbPoXqa2FilahrPb2jJkm0tSAj1Kut9UEmuy9TzstPZujp8W0ugdPjsVBV+xNK48syWzk/uJXh5wds0DBZiAOh3YbC7if6HX5LrwUwM5lLaPG02zJeQnRihN+5dWK8lqwBL8rxBsPH44RdIyQUVCYqPJOhfoujQBRtUwfXCVgpZ5rYtLYNPjOZF1XF8zlynE+aGR7dmhQpdI9OFMCyTTBXUzsNOUjC14zfjSMWMG4aXClGti0FBpDYeYyS8BJo1/DM6U8zkmyV8c3gWI3le2pidrpudE6LJ29wWnhC/2nxPsFyLB6b+V54JJkp3yVU6kzF8+MF9AmaaFvzwaKnq3GbDAX/7wPwVPOXDcwSLPrsSZ0ofMEhTp3ctey/8K+MWjkFBpg2OTv3JRwTKyda3/sD9QvT0UHhgFEDj0SMi78FUo/fowcFkgYPp3rvORH+tXNQdD4miYVI/7q0Rg8Jv+uMYLzunOIAQy2b2pJ6XaeB31JQz5HORpR5rIZSLhw5aLoBzfoyyXSmuEoHz3RRwhjUNTXL0SOFCrTQg4z5fVGELQbDXKCgRkjpbtmoTiquZhYtDZ0A4MS20FAcTQExAsorKlB41+Lm/TzHFit3AdUV2bdnkxoZJ8UcKyRAmF8iN5GqYR1oagGgH37oEOwRFdkwFI0w7wQF2Y8kEms8hs8YNPmwCmniv/SkycUuBJQeJo2J0uTFL7m9g3/eJuG9DCiYYP3jDtzVVVeU2aczjD1vO880GwnHgKO3t2vVSENiXZPLDsHAPWk3aOGqoamLgWoraj4XxJ/AssV0okDSLuQaOEnAfGCbX6VKAtBN0YyJmSkTP98dVM8H+ZUAFXzm8ailYN3QEuiLS2RfXK8hhTFNDxmRVo43F1LBS4JE76lEDYt0ipkyd0VzA7KfDCRyWMeTRJIlIz0WgVeAa5+AEeirYi+CNMXHd+iGGg8K34SKWP/d9MCW7iY10KSBu+k9Y0LkzFfaGhY+uQ9GC4s1379NtxO+uOd2up1C58/ohs6jq6kDnT/YozJ2Y5/K2Ou6FS1e9MbOzcQjQr7LuVS+5LGx30S75EODRfDWYkZYXeoNl2ATgcD1+Y4zPYHxrP6ymHnO2QZK/FPf7AuQZ4+77gPSJc0/bAdCXPzV2f1VUy0dWFo8UFbV8gH2UCsuFlPG2ibigu8Jijf1rPdFfev9tu71fkXz5UQwk1MTqJUhjSkngIq2I4BMrucwuf5PIJU/F+cDjvYEqYWJjgWhR9Xno9I1gJ0Y6uONZtIXg5YMCRtW3yRbOcB2TUYu1ajafqNCqpWoTFlhX6elMWmjH4XVo6bOutfZJQdrxixcs+CUrXWH0Beu3sV4NcmedqR0vmBooMNIR1RbFaYwzJ6H8WtKLMnM96rLC99+CSdJlSnXZW9nilY2V0o8Fb7lsBPhvFsT0wl0F+8iZwA7auicYV6fXDMSywmYUbMGMouUeqOZTuWcSeR9cT+AlgHDJsv1JMdMwP8jaZ67O7VUpcTGz7IPgLf/eExxENkQnGlUKYRtPWCTaQ1kbjS6ubYw+Hw70gFdz5cLB4CyXVoinfmfdtGAGx0/CJIA9mmkE+ufi6taIgtwLRaAocaau58xPWIEc2piCuqmXl3CazvP/kDCn4F+BLj9paRQlJgvVHbNzbSHezIq0zXb0/zDTiHw9xjCq04WefbljF1JHhM814nzrHnSzFs45nhjysaPI5Lh3aA9VJkwsuFQ5WFBYR3UZ3kTbruMKjuOI60FxTROyDj0clJYGL9Q8ZvH0sF5fLaUExIpTpry4wnfpTm+ZCg1cpv+mZ9z5ycKc3TYAouGnP39UcbeWRaR9NmXOk5QS36Lc4q1HMNHaon0KSrda4uV7ej3bLCwDZo5dkePSCOnRlcS35m9p2u9vobByBcNOERx9XzLcOrDY1pNfRmF0Jfaa7/rikVowQxZ+qnupf86lr6ExKY7rpA6Mczu25p/i+WuTMHVm3kXWVUnWlXZ11xGckBQQKCwOgy/dTNJqKiwoNKuYBNJD+ZTPDGfgt6IxpuupFjQmZMZmZpPxU3dq7Oq7WtheKTD8JgAZyEMDwjXsVF4+KUoPHLpKDyYKPJAQOFZ4wIN88JQ6vgJYmKuYU744U7moOQbexwIyh/e1AwOkJ3ldWeqQtshZCV9wzcDh0WITna8jzYOmU5obG4AJ3P5KTY4ftH5ruVqhNoc+BbDLgD2g62pyhVgxL5w8y7mPZ25my8OHiIoCAMfwsi4n8Y5KZofoscA4qK84diNSjRCSMCCAgLLSZFO3ciSA0wQkcRqrtqZuXl679LiUJHNOCkr2LgijBEaHD0YSBDE2zzAq0Bb/XAL90HHcSs5Nd+XU4/LW+Y2w1p2W+kT+SFIYv1TDL7i+fpLUcbkk4zJ7M2YzFbGtJZLK5lUd2q9C7APahn13r7ciR2LyhxnBrjMb/YyI9iDJKdyWS6nWoR9xL4KP/SMF+wNjBkAR4JUcOausC0YWxGdMIxUX2fLdjqrVQ5VrmQJLywNZckW8qPKvOvZNI06/dtdtOYH1qE1Bz4Ecd46ilX4zhar8D5E5SeYTC1dMrz4o0h+7Z35OkLxDDRpnohxmo/EPja2Ks027HuOzDLQk4UMM5SmQs2wsGdOnV3JzYOcY5yZrFaicGocAZrils8B0W6UEp4162E9T3+DgZurSI6grIlc0Cjay0/ce85dR5qFDUew7omyityGWjMfGUg7YKLTe0Ksn1v8nJOSmaRjEPMbUdJ9DBZqFnk0ZL4CaMDn1h28Yve3Ug8uNnnm74B2CbEG+IRvxS0zJudvZ3oSw1oJVC99HRZg8wc70WpoPtjdM1gZJATe2E8I/KnssLUdai18a3hToADayoNoQxLI5T1UGOjhg1w28rTsqaa3iLLgKijE39N3EbxmXCLiE9dtIx7pKqjZ528b7D8OsLIBJ3FXdyWdQI/wODeNZf+fWMwlK0moZ61+8Vok1ra2RPmEbTiW/CPXvt2JLBrSQDEKGmhZC8GAtE/r38Plt41udklLBrRXfLv1t9pAv5GKwaDpDBGYjbqO+Edf1/HjgsrhyMxUlkQnRdZd4TQBKtEvJlrbcOsABVvnNBweB7xJw0A7FxLZFRUxNpMKBVskUSai09jzOOaFOFq8EObG/1QjoArb6AMQhW1AqCb5vhigJuLTpuJhrEXmwQTn6D2E74GgxTuB7GOAZceu9TUpDT3SiVmnU0n/M2lVggdgc/9IKyPXgaa3gmsB9x+rNmQ9AQlw4huuImmRHHkS0oamjpDDL0e+ALMsrnA7fiMLpqAoV/Az8wY2EA4sLWWRRNo0NUgAQd5aTsjQ2VYdWSe0QILmeDL+eCYrJCxLsclnIbMNvW1HhGc6USm9r6+5GYnIcFqpUtqow0lFZDodTlw6yTM/gjtnIXYTqDAfjyrefr5DLz0d4d3NdSA1zj6mLYSZWOrpUZBRS0qejYJ3h9qazF12Gbcp7EQgrWJnSeb3WKsKYVBozaJ5YMvpXTkpaavZjE96jFwKNxBC5VLW9O0cpj4ZZk9lygA/UxIkV9JczcGwAILOQdvhf7e5n8l8DjxRhTIZzIKpJY0nw/aekhg0T82dk18jaVWLxIDrZ1ISBAcZEIYXUCW2CA0MRj81G6g/IUdo3yStTHKh9rQyUUYPc+qMWpkne1uZgy6dJDi+BpfOAkwU7yViA9tiorizAVYbz1Dx/dtgqPitnQs55uKNrBXnNmmtyLxt+4POGtNiMQnJCnLE1JDX/nHsW5sR6NzRSNnUATNGrfSoMWokZm4Ho+aCsc+g05/ZutMi80/bH1LCpk6ojdwWyQH2ZRp6F6MP+o/hAdbWCeAb46C2qwRaaWO+j6iYZO/2IGUeAbpCttqo5sQxYV0RqNrHBvDh5ulHRHBeLLsGoBcH2K/BmahtTY5N5VL/P3XfASdVdf1/73tvep950/vMzmzvjS0sCyy79I4goqLRiC2W2GLssWA3thj/Go3RSCIiIEgREVCaImIQiL0naiyxxKA/Gf7f+97M7Mxsm4Ulv/yU+5nZKe+9efecc88953u+BxFgFYsAw/c3KMwikzutVUu1UgRYYTaKRbgAtWh1uOD2U3wPhCGXHAERHZEpohUDLaIctobvw32LoqLhvozeegyhk9VbL57dW68unuytp7TH0r0AUFso87v1DU/tq6Kwvnthpmmi0jZOChriV6odIDnNarCnhI9pM6N7DBrsUbXdbgfyASp3fKTCqOJQPCkWFzHWBzQpsqCWEh3wIDlanQjmfpMH06fX2jWIDUSCGiWihei4ZFYzvn+XU1TEA2hLj84yCAnpEMSdDV5wQQHifXi9kz1NRh1rsfev7x01qQZ7bakGe0qznjXYu22P1GCPx1/l5ZbJWq/Br/OAop4L+RU/V6MA1a/RuY0o+3S3+A1BrdGltxWJxojeFLSIMUsRLzgQ3zf58An0fCoIKN/iGP++U2eCEfF63YiFq6hC31Qr2Y89KAFn3vEiRvZ6hNVf0Z0Gx/HqhxLPIznX3TGCI+kv0wu6ETy4pYcP4OkFnnEEXOjT06gd3+ggLumYLMzO+DwwOzW9YHakrWYyqCDJ01t8hSRPj5Gvj7g8DUXXgiEQySMpbHcNWU8DcjhSeyQEMjGl7z4HDd19DsYN2OeA1h+uaGMV86Pj6Gd8ETqOfga5jUfSHUfbaDOCW3a4wzkdR2XWlD4ajir+L8TJuJ8aKzP6lqo9fq9skcChlOpcit11duvSxPz/0nAYHcdltD7FlZrdEU/ejU+DaHwq9hERK+gREYv/RyNiMKxliL9/zQdgWG8GL/sRD2NJgXgJKBfPwNiUKKIDIh+zm8HFU93gHjpyJvIHFo0HDsymCCg8Fi65ouIsldMvmSutqYKFralLe+ulGraYHKk2byaNqJawb/SFobd2O6Wo/EJTyAseNXWpE51UfUmMjq4Ai+fbfUAdk927lsrYN4gUA7+dDImIHvyI90oScRMKw/KWCGkmBy0QQ9hSd1AiEe4hEnO7RWJ0jkgEul20iQORCaz0l6d7uAVTwhDJxEGCmiVfYaDoMTa4pe/GgTvsXtxvh91Ls+ThFkShvGgT8xnkIYaynWVkzyFGodIr2pDYkcb+BEJUZraLzCP+dFpW/OnFHvGnBI/4ky9DqgIV3pPMcYiUxiActpl5qLeuf7LEgLow3SLy5FTgqTw78PRdz8BTc2bgqbKmMh14+jAtcd5G/1kWE4yA6vD29FmydGqOLC1FQ+AkqnZe4pbskJM/K+Skl1aivwFazezOHeS5I74S9VZmzvdTY/7fsiityK06D5iVIMNUucOW0HCfDlxCqaLziYWWoMXfFev6X12eEt/mVqK7ELvQYAfg1zlKsgrRa30Gu9Gh9L6UJVTn5a5Yt2dZqLMkF/sdWLYiUDt/BbkZZG9AeNiFub0B43X0/4Sbffmh9h400sT4/9bk88I+WxoWVVX00tLQUO7tpaVhcUfiyf9mr/stvlyydY+RL/9PhDMOownjEbSGfx6qKAbdf1idGY+I5Zw6RGEMbiUA4VYu8XR3u0aXzj9gu8ZQbrtGfiz6avwa0lqf0UcRJBCpfl00Hi10+pK9G2XsVtKusYBGqncji37UN3b3bkSeSMJ/D659o1RdQ6dL7RQLwi46RRVQWYsiLkSko8WWixmDgsoULy4024JqpS8c1VdNL6bBknKzuaq6At1rrAGzuRg0J0AfnhfxOAsZrsWqRwt53u5B8PHlfktoTjy5u49jxYQKdHF8IwrmBTvcML3HWo8JVrvcXla64VOjlg6sVeFwyCyWBUU0xVEHO+PUEY4a9H4rtYpBj0uv94fCFqPTFkn2crQxkPGBNX03c7ysu5njDVIzR9YJ61NIUwU5Cbs27ONtDXXyEgXmbbFv68D3kgrhc40Pn2t8aD49r+yD6HT1ASqinZFyyN2kHFUvYqouWEWbAoyT2XZE4XDZFVdmWRJDpCBqVJdk2hLuD/11tjpwem5PqxiD99yd0dPqhMyeVs/o40af2hAJoFrCRLN1Fx9huitY7TYsdopug+AyKe1Ou+qiDJNgKiiMmSoyjUIikE8bq8RJefevSvHvNqDl3j3MoY4NDiPPD7wmFaLYOY29xLrSzMlLUqPUxAq1VL0Inj2r6dXAGHxsFgYGx6uBOmPg+EJLqFtCPEiIaU/OXmlq/FSwOV2alIBQncGo5BmBSjmrhXBaAk5wtOTIYE16uUlcnxd1b1UGSv6bvlHyKiY8lD4vFqckxWvSu40/yVw66gPBpIyopHC5HslRtZIz2HWcTq/PlsBgeuV4Jx/kvVSz9Rr3EV8CBOae/yMITIVSVInKlK+C0Dm6ooFNMt5oSTeOlwyRQ6J5wbU9m6+b2yGGstzckiPs5gL7aDECHOsQGTo8+R8vMNwlDmOFn66FAaPVfTixsR5ObOF/1In9FoczFyBBzSnCIr5hjFpiXfHS2WUUSqNUanm23dBqrKIz2BIsKZFSeB9wz8HnHUZmobADCX1ZMiSZYCWWhfHhigZp50ZrkzLDqDj8vFjrQNqdVWkkMbdYOFjKJG3FGKZfcWRdaO52EPGpQPvBg3sQWpUAK7yLt1mwogsokcHuGQB/s9Jla9DrEWVF3yGHxewW9ayFhMmks2mddi6x+8g5wjOx3VMJgj5m00MgDI7rDDYUHurwJQ6s0EYlEyqVNRAwQNi+1tp0RhFaYQXewKILUTt2XG6Vgir8ztBbQ+/ISnP/BrcVO/TR5BGydUgIS48woGAg8tJb0+Sls3uSl96UOK1v8tL7UuV/k/YcQShBfX8FAjWDojGlDw29SBw7AJ0pB4l5kx8hEYih00mMJUCxGWD+Rio011BTXeVAbXBrctvK/kVZZ9Z4MsYjl+VI0tO9ELFNrFTkzScDdvV0aDH9dCL1VdvAaWMz+bDb1OiMJQ6kjI3LsW1UABML8rXJIIMEAh3eiRHNLLE42VT2CsdLBr8eqFmNDEoXNGaDxWLwKMz0vsMB49+Kotzb8Ae6OIQtdgMr1g+Zqy0KqwQf4+QQLKBLAbMNlgM2G8KCmdOqjD6Lr9GXeIL6C0vNWodoVqDqOFRIzxxSEL0fuaYulPtNJRcx7nEUXMr1VXLFHWvM6WSVwKj6bU57EayZkKhijLVymDZaFUm5kikXAB+WxILPbSQgqT7LKIXTeSdbNnSwLhOVkY1+jr4Y7oxZLDRksUP/CoxTYVV90mKISRSUYG1i+i21r1P7gniH0oMaHYqucAPUaoPGNzmIpYwLzXJmQXUyi3xoVzq/FJZQFGbQRTHYn4Sh8KtTgGYAZFAYxjHQH3e5QsGVup0I59IUaSvaFmlMEYuzqaXJ6atyGa2CzhhoiPIqld5mAy6NVQPjtGJMpNyBBVHnbRms/yx/yPJEqUQS/YeMetD1Cno4iesG7SmhtuqD78G11ZNaUDd0Y/bqLVGLQ5nCVqVItWQ3sl5SKQm+p6K96TmiA7KaA481aDWnKTXHbVM7LGmontKhk7B6nNZmcRqdqpFwxp0GPfg+ErgvBUajQWswuGpFA8i1ym14WdD/iqEldax9crkxiBVVBU8cDI1YXhFHshba/oDbpEJ3GZD9Yg4cTpNR51cYJ3mHmbQMmAeAw/fOaqNaI2PzZkrAPIXZObZ80U4JlseZ9EUV5eZEHaIzt8gq606qbLO5xIKmX9kqK5otIN3LVll/mw+9c31QWbFEC4UNFkLJPAff5w6gxG4sOZvV0+ayXykjhwBNsvXeqCNLv2jf2lyT3hv00GZptrJ1WQLicR8eFr+VKClVQl/c2pfqnQbVO/CEp8lvNFC3EZV5qItvh0bj0lT4Bx5mrGQowJXjyzqlx+9R4WvrqR2sWApU22rVjjaX2Q/qZE8D7ezmsiouLQXn21lZ2KHjBsYOHbhMzuPew5QTi7MJyqmAXUkqJ9eKnF7cichIWu8Z+RxyJQGTvb6x3u4udRjMqM3wVgd5vd5s1sFUU+nircWACkiC8RbYGQQyDsr6DoiMhiBMnClH9TlyVJWs6mzMFKTMmDLHKmZjQyo1e4csQHxiv8LmMdIsWFtaVGGcyxMnDpFUBYcK2DamWxgRXKHjsqVR9HqYy3ZUFkhzWVqgNW6vR9N2x2GKH4s+vIXogwbIuAdglaTQY2MyzACDj8YH8focZFxOPi8XGtdz9Wih3f4hXh6sb8idYPRm4NjM5RZ5moQ0ii2ddUuB2F6X3D+T3mTyNUPrdabm8KNJ14/Xhdoaejp+m/py/OayQ6ZxZywEoEdnQEOeyLNYYQGQZ1vg/93LBMtqKrS4NLVmMeX7Dcbrw2RZD74DnJiAOu2HevXHD/NODy5rSxtbuR5pW7xIcZYhu/31fSRX2zKSq+ZSC23tTq3qCj3M4b6r+4aXmUOHcsO5WJ9J0GhxcXYSFK6cyl8Qs2QnQSE74XrYeDtsvBWEdVMRBH77CHjYg18z+Mz1QoKNcWkRgTshIcnidYwMnO2848mDSftuu6VKTMmGFKh+bog8cv0hLhPS1zIWiZ+xmC74vtk5rXoBXbeoU3pJbXCaqQWFOkwK1A6t2wpKcUgbyADUDOHDso+H7ck/dKjLg8lvAxdp9/IwjwNOVzCajGA9Z66WNsheMPjdWIU4rctlVwMtwosIJCKO8Z4nFESQQ6fWoeu2VSFxOmzhZ/AGMoJciPrXrYPrvc45mmk2o5OUEJSZPGKRNB9LG+P6d1YiWl2fTDQ3yCIsBQ6d2RkOHyugTopiNL3NT/eSi7FjcjX4nirN5MgqqnGuWm5VmgNqUjYHVPWxd52b6MrhgDIFSoYfc+XcdJCHlnIGdSDsh1DwiW+cHrsNWVVDSUWZ0Vot0gR21AFz173TUFIjIKyoxD1VTEeWA3kAmR2EilGdwa5XG5tCSkauAsZ6L/QfXCGJ0xkhvD/is9FLTUEvIDQhc+IBg0c01IUDA5JBdVM9mRwVNp2B6kE7qzUZuYAoGtVJ+StGbNcSRARRFkhOjQ5yhhAiUi4l+r+Z7GUOZ5GNrehuH2KKI+CgYgGCXyP3GnRaaBi1uEYbgsumIlCViSKjIDE4TCE3oVj+X+f+zf0DqEJii0tWKdlIVBIL7CEccsjOUZNKISCnxJYM9oQhiKVOAqhyk2czCS4srC/BjkZaVKQ5ZXDiRlnsZPtVk6QJkTrM1BZG0FkmHvky2hm0WCNWR5FzmLqtqw3xclDSsFZrMfQDhKW2a7UKthMDgUd1TaSy1qyxaf3Nfqgzj0xgEXih2PoRqquuCThL9DpqRMEWlGWpgqeJs5EGhpMH30rBIU6vLW0cPqxcJ5Y6OX1l88imcu5klE0o/R6sK6qUJ4UDay2mmKVqWqWhqLzUzLlCbjfjAjSVlBYaEDAEI04AIUMd+g2KlriJZYg9DX4Q8Fo0Nr0uHQSi2IjIrJVB3Oz3yFwEWogNd1a+A7IZL+HlO8ZSPg29LgzZEyAvC0i9yDlc6b6iOieZzJN4cFI6xgKrF2ucWk1Fy6jWKulH66qGj26t1oW64siZha2OYqfRZ/w7shB+VCVqrFpBA/YUzq6DnOI3gOVO7Q8FUCvAJ47R6A3ArqEizhx0mQxSap6LekrlvLx93C2jx15P/0Ul+AIVG2ASFVyxx+nKcFFBJWQ1FViqzq4yVtaWG0ywpyZTQSwOC40uiVZYdGUC6FCDSxRNUtNnlnRH9kyJTRcnEdp9iP2XgUwm54GcGntph7ROSjkznoWuU8sk5FcKUiZbGdVKqyWENB5JhS8bGZWUfH+DlN1d28ANMGnvDFW5BFXcw8xdRLw3HNAIIBRKzKc+lIBi0UNzCLVZpynHbFTqxBI7rTjuuLklRr8TS0XI4iiyH8BEjNBaNArMgwjqL2NGP8u3++pnObUX9ilDDvkU90RJV4mn0GkwIuWqAnG52aBHeFqrSAkqtZqw2MA0aT0eEbxC0oQhamgIHbi3vwaVFKbFk0kkZTdk8khhPWKN0tmkxckvyINgFM9FMOM+9w5hTvtBfc0vViFptapl/uhA88vnN3n5IJaP7kYso+8VfaknZFkHWrH2pOszBGJgyWOGEyUpiHIsG6KcSEOU3Vm0YtDLnrxiu+zRcNSeEhSF2txTUOA1aTS9i0rir/0KQ2JTv6RiMJSmg3u5f6R6kx7JvIMiT5ayCd35hFYpn1B3mPmE3/XPRXYzNjC3ZGcM2syO/DMGS3K2MiU9eceOy+Ud+wqgSI7UQE3HIeVzDuOIjCVVEYxbSAfK24Tue8TUq6aRJQwbUzgEGXBWSv0c8x7Yy8m3ZLwAjlPK2Jrlu4qXkVFm2pn80FBngd406DiT0VHlLMY9sVhisRAYFVmsR2M1CTqlUv2pHrFkDjk19HnVs90a73X+aPai39sJwJp5sYFn4UkF0m0XKTXFcCUh4JwqZBPC4WpeJVjMITOvoO7Dyg1pAiEfMAVsWVSbDPrCOAiZ/0oxr4h1JD+HHIPawPL79uBsa5EU+1BqoliAlbC9tKiVFhjt4PVjH2Upnfa+skOR/LNDjensUDXIII8DcehRaF8qkwpLjl5patfI6oWSO9kGZi9rMgQhytw6MAU0ZAiJKilR9qQASNuFvImVaJ2Py2bDiXaHzeOpuLncUlFGOP0lJQQPWmIFIZ1kEDNEgAp2c2r2OZ+TczbM6wqV0tmAmnjY/DPvX4GC/Ddg1Y2KJZaQSbkpL0qluYILeFVAPnmloSbkgiFU6uF4qk1KnUFikFA4TdagRiUlkx4HQNyr1AGhqdNFox76DvqVWBUGoBgAYoBXZIFjJPpoGZtIQaEOGVUmhUnlAXMB3qav5MWfRDdQRzColqTSoteFdQ4lna13GwzA1fCA9IBwYqJQiB4RHMfSI2AhwOwXHtyGdkFs9q8n64/Q7A++2aBt0FKwbcil4OrBdx58ZzAiseSwRCLxzeB7D9LVSFrFsgXkjGwBOT9HQDh0o/8U+EYt1guWOvbTPux+hDWy83HKanniEWGQpMKZhn9gXeBTUpXXEkP75CLJJCLJyGsuN7m1Om2toFW4dHYNc50VOqdhmhqeClwgTilaVZGIlzOZAiYBJX+c0SBWiH5AeGyoMi2I+LUaGFKwRFoQkEGAZ50ObhnQphokMPXMZ+I89pe4uSzBacjhIpHzm4yKBGEoh5Tg5HSucsmQM3irCtVDMOS24rADbcaZJccMChp/wIuFAauCXhePocT1LWqy2RRGQ3pVUKiNVph4MXjg36kE5/4E0ptJ5pFxyeymjtGOXLcjM78JzY6h//u/EUs+itxPtgys2bWHZNcPPxPlzI8R5Hcp/b6oV/1+M1u9dYVTmHpX5qr3k5J6X8vU+9lDzzTV5EUCshw7at/A+h3L1m9/Ur9HHn7uKDEQ4QdzBt/ivkNyaLxUlZ6ZHGrmBsoOxXtND6n+Ax5lTYZLyZ1lLM8iQfB51Fnpo4BZIecVdE5VKn90fbffOLpXv/HdXvzGryW/sTnHb5yW7TdayiwZjuMYdjqDI5jiNBCwYJj7TC0BEpqVWwqE/MgtLRuk/ygW9/AfK2lFpv+IvXr1wbd5ldRg5zTyWzSP7Nle50j4AY2H2mSHtZs9vUdfnVOGfMl/IN/2OsJAbWfpgsNa3cv67Zy0NLOTzsmJe3O6zjKq7vd5DUIxx6OQaBlW7WyF6n+VHqTa2iTPXcJs1qYDPcldGytmk/d5sm2vt9DMIoisPR474KLTMtbtc5JLdlFJGEu2mF6yC8RCT7GntwV7RS8L9uYf0oUNXm2cZ5qCuK1OEWZxELRacDmUUE0dQpflAHZrlQZW6WDVcKwEQpRKICjd3L2G22J+a7THCi6rZnIRf6PPRTzxHThKTNY4ixvvNXhZUwAtyy0FlA6nhUtEznEHnCaRF5TegI/lBlonPtD1g6fKbkBUlkcpHJrdztf5vS7U6AB1XCPl9regG4wX3Lgv53SDUSjjyVh/uktPhiqnpxUdh2vSCHE2nQqnvVnRQ42jYaeyQVLjGiwMLGwtvV2TKTaRqNTwpVmq+T7kNFRWmxiprY9OL/f1iYYL3O0WU0E0qEXWDErD5l2rN9D1yEOiKkeL9oec1y6ihF9b0dxWF6bz4Al6tE6NUdZ0pzGxgH0NvYkVisK6lrpCRaVaYTGFgL/nIFto0lIlFmvqULPna29vtg2qKYkpUt3xk2vmdjcd+Q3yxOgfY091BQIE3OiVMw91jJ9HzTrT/wGVMQbk9CRhFZRqI9KQIvWyDIgCTiy26Tq0tkRUXGYhRFEJyi0YzSsygjRxbf7pJymmvpv7nBfRHWQDeUuWlmQxUK89nTINf0OurMhWPwxRqa7tR1Rq+pIUBOqYpPCI+FZQOSnCs/Mks47wILGYOMP18nN8WooOsystrHG0MbFmG8gSDlml6kjciJ/B2Cq4+yE7CLwmhecLh9wXqJTJTtQ9ArITCciyw5L8WmTj1sJYMNHhZWORmK2taGqrDR8jCY4jLTiGxBkpwVGPmzVOLYlNsFtsKsVida2XettHNHdp2mYeP2O4WixDBQPmQGtUWdSWqMBp9fRGLAHGEp0W6w3FYu8NBGIKI/x/pcqmpVWd08dUauxmHbxHA12I7kNAmWucaCrExMdgchh8coKlSpYer0iXoKNFhuygO6VJjKVERy8wbLxCahwmiY4qKTrYJ9LEJPaq0qBhQjjBX8kZ3Ur2QYPoRmjaY3XzPKpK3PqK2RVGG5we4WgUuqixYklYPl6j0QEnSeVEDQyQSG4BXuWpXkxQPH8LlGpEMLBY9W2BknJFc5yZWFbDPghQTyvjzDEygUwjA0lZJ0uKUindbq89MQtGZnhdeF4PUTktbWPisDFxRW/CUueVTMyBRXVzLuzouPDourqj2eOcOk4XbeqMRDoawuGGjkiksylKf84Miah1pduLOYx+2Y7USJ0q/D47XQUIDtZAjSwLKlbchGa49kImDHB2UJakV7p1GXZE5XCJSg2zIxCGr0vqvBqFu76yss6tVLrrKs3Ma1RZQLmJ+VZa0kWOCnSYWsgqBZLeYTzpLcg16XUZs8rchZ7zijRero+vFDN9/Lq0jy+FjbqxA9W91lLm2WCIw46cMxucVY5Ob6XPao5LziJgrYLGahRQTKaiYeSgNVY4jZJ8+5yJr8A/xtz985PuPptf5u7fBHefNQtDDbFR+aI5ZFJ9lm4dpMipmzwwL686RroVdcxOVJOwMCOn0WkjYTe3l+qMJubxSFFmHp6KWg1Pw+rVorRSjiuog0aQIplgFACONgtaOSxUlWoOhBwAd0LPssilfRUt3pkqWrxPqnQWMeNYQbA/uI3VkdkG0r4SxWFpNx2yrOxLA6ofS8i1lGsOV83/NmQ5W6431RyMbifq+03d6vpP3bJO4G/y8zDZo8lv2GaQSlkZtimrg8EMSBFahjUswZpLCyWHH/EAVISCFrgxHknRTbEMrdSdxzm0aZ4YzDoaoTtrLVV1LOSARCCOycUFtbXMxlGrA/kXF8+ZPWGbu8YVnxD31Hr04aCD410FxQyeTk0BvwuoM4ezwTX1/qlipdFIdx5OTufAt7h5wtHMVkxnIXjuXEgQ9MmlThzF3hEsAbdTI0ch9HaL06mlHOO4nsVHnBTeorOEoR4AEKtb1mehTyTvVE6TnMqZDGaJxEO8VU0vEz0eFVocqdQx7PVjqP45BtU/k8j55A/kRYZOjHdPWDMF+k/yvVr5ajmmE5dJDdgHGBOztD10yCLB22UWClESiSEu/Ik1INKUrECJMGHDGY0pW4/oQY30r42eK5ahIhbbZ6STVWiLBUimSW1zsW21Fc43+JhsMfFRo9eAaJ7SaC0VpTS0y4m9pU7jdHv0G4eyMigxRvo6zqQCJlJQ8mppBpGzRYoXQoZowbF60VikVbF9rV1Xj8Aeo+bCRWHfbkepsUKOICpUTlNQg42roaKmysw63OsqTDqYp8TCIasdgoFXtgFtLbm8LFpiVgETNwuM5UkB5yWB2cefyKvRVuMOsjbFS3+4jTX4oRK6/FpoKPKUJe75IWi1MfNwBZKOGqihRqJtICkbdMuNpsOTyl/k015DMbC88ahm+5A3IRg5gVxB7upn9eEkKGJq+ZEg6zkLkIxplL2SzPSRJZ/0USyuhK1y2uSVBuFsJjx0JwJKAfSDBf6Qc6DFnNHptzorHFa3y21xVbp0PrhZnMUfNmCZMTrtDO8r2osdBe3D22OWEiBHqJoOyzNndOBVeY54NUsdKbkL5FXFqU5MkVcVv8spYxcF+I5OrDCcJlZcoKFhPuLAumJyFsrrCiIA9gOvplJGPyYyckZTMnNG12fVxBmBz9EGjImLeRjCa20e7AlVLFjsgXdQjUTSWMSZtkpEWpnayfj+0/pJk5n85Gw4e2i5rOQMr1c7BFVMg00sS0Q8hX2bBh/NMA30Cr0bnMIoD0L+l4GXLGYs0jpTkT3xlcaB/g8C/DarWullMV2VVWlxQFkQBnTrVPHiAhU97dATTMZBpp6VZqtVYxR1P0oeCnghlMA5w8WUhEUQVDg2KC8ArX0bfASOpD5X1lXL+lxisnM8oygsYNYAaNemTGPgsJkUUowp8ZshSEntGWTWGhXwQIyJ6l0wJKN6GJKjsw2JDQyFvCSoN7H6mUFXu8Ao9ix2UR2mM6zo3Xu9so+6l3GZdS8NFtqVUfdS45nbh887un+f9y7Z501sY2ZkGrtb4yW3tW8SwEJA53PrX0xN4Z7VL236Q3V9f9Krv8pL/qqXJ0hdrCMfslhD75x4UrmCFGM+PLeiytk7tV4rl85P8XnRJ/P5uhzf9STBCwehPILkCyS2DehNmAOWFb15EyDRE/sg0cMzmUOPH4haecZAjgb3kcrnd3GJR3OI7hBz4JXMM8j0K8YN7FfUNTdIdojTGaVs18hcjjwBNkhIsuQdOGFg6uUzYSum97AVp+Y6uW/AVmix5b2d7CWJoWBLGZyLy/Xt4jYeVr0WLcx3I8W9mOZXqezJr7IiMapvfpXnU5mO2DH5iKuhP+/3uUMt52KEzc8MJK6DpGGpPzyvODaYmq73RbdbrukCXe+U/LZmLG/PbOMjwGq+14d1ZLLiGBL7iL/z4R7tL97Ocvf00E2jMeCD9VIpD8c2Oplt5PKiGD1weS7MgLPn5voTG/Mwkb1xgeIrOrf6UE2kQsXQDAPyiB64PAeKUJMND6A/Gdg8skomL+/iPiEXILUDhpEBSENrnIX1kazdWVwCjPS+N5Py/5JP5adZPlUp6gchcihJQ9dwKRVQW5/pNIkOblO/lKFV82qozaX11nsNkZCT492xEpPkC4X8brXe6XQOcxdfdPlFxWK1SYXiBkFtK4fzaXOKnBt95yyeqAg36mjqKikqcVojiWuxaG5iN2Q9g87Qu/qiCqX0uhx3ZxpfluXtqMGiqZIdpYj6j1l+0kJ2AnodpnMufKGLnQG/5AoJFtEuheFf577i/k0WIBZz/4AJtu4ZoAxsk779KfZXpt6ifPNFVj6Wc/eT6TOVtKg5fDS9OUs38mYMcmlIHubE3szX9ptMK/KO8BqCPjE5FzyXORXnXngumwqU27KJwH3ImYkJUpYsXlwuobF1sAqqFNjO4tE5Esu70dj0ZxsEqmoZ3aKiN8sJM0c6YSamEmbl8hw5ANiwDbNI84MNM1WYzdVGaXLQfsDGCAl5wZScHRhm+iePs0OB6h64GryMpEMqNdX8I+aE1/KAoJoiTdbn3Dfc1+RO8ip5A3FWbDGiFRnN65l9TdlYKZGBqhQYQ8a/Z2cKJimZKpnCQuhGYu6RzXJt6lvKbgZHhpBUFkakJEjy8A1S5qyW+QvSqZmAJDkeUSCF3UwhrXHWdBNFyuyyEisgArnJylBHTbpEHRKB7T3b4UMrmRA12qL4jr32gSDCYAA3I1NhMOgdaF3/GxRqvqZ16F2YT07FiQ4d7nMIUBsd0ohaxumHzIVZ/QZHW81hcxva3mlMOrOJcefBGOvZVhkHO/Cuw+WyujRqxLY1VRgR9O8rvk9hVmmMSoMBtJIK4HtQQGjFpkiHgm7Wuw+gL+RhEJ/DYnrgTaQLFIjPacwaM7gE9Rq2m5LIH1nO3WL0GdZthBy+wF3GsTouPQgcrajbYrNuMbpdiLchn8aZVAZ1Mcu4QBcjOtR7AxIEQdEAX8FjD623oTQX65NCYLXhPI86doNRp2YQlBZGRcnAYmaE6qViYoCP9AkTKwcC8FulKAZcBQF+o/NoxHItKsayo1DhgnEDEGsUAPKSaCg4H4iQxjKpIoj2cn8D7/79ZKUcve8utGUVpvZ6qZIiLW1yTiydeLMnYV/QeDtK3WqTARMmQQo2rRJBlDyY/LBq7LSE2GuTZaliKlEX6Za4BiYP6LoGsamTaftG0Jo2WlePdR7JQIiOEuf0MabJ+1WoTArB27JofUZqMCF8QAOoVcJdNinCyJ/SzwBl04sqDRZPVcxWRrmATkTRtAqMnhodGKMTZ2F5MmqwTaAocwnpNCE3GiGqdfgAx4dmhFRmlYEhqozwqyLBtpDbbNeozVaXAl0V3QydqTCg+eU/kPfFyrlYlIq11LQaFl2j8eosepXE31eoc0QaSoHZUmj8hgKIBZs1cJM6DJgaq0lpVj2GRRslcxGdETMPekfQgmriyNAxbEaXoxjTjWs0amapOY3SWGXm1AxxyentXr0VZWKsUhiTzZBfLNBznQqBmTuQkTPrnIFiH6/VqCQzshdVxJ+AMOgSRNyIDStgXf3gVtJoiZC5HPPJ77I8eYPsp7HUPbMwmS1mAeWF8whQji1n6QVA7U6atYpefNXF/a+ihvKGloZyQ+ZS7HYWG1CzLRcUh82xkCNSWWMuFONinE2QSa7wlgoYfeUl5dfwwhvM2O+TQMv0JVrSUK/rY1G1q8/rI/iAmIdOtBSyfDfccbdDru/2tblYdTdNlndbS+148Wisv/MMFpsciogY5eWXD/M68jPAKJ8eHMMCew2eNkBKbBa6NZPNQTPNVE12QOzisnBw/KCW7uzYONb+WGptXjsoFJsxXDG8mHPi58HwxsMqsw18kgaVNGGtpoDR6NXpePiR1WLNsbWUuzcNd+MHs6yLnRO7bNl+QVtq9a4ZENNm9JrlAkkgNww6h0FyxRRatV1vMivUUimu39jNu3Byb8s86BIsWcs87fYMRgqqOqma+QM+zP0Aq/trWN1ne/ZjaqHyNr33eU1Oq6q2t4pn2+FNbgW15VG8nHLPTshsu7SSOsdNHmvvdV5DYqW9Zn4tvbfXzuCTD3OGefWALb1pc0oKrFkFzLrWJEeL0qazGyS+APB1ifqQTs0QDM29lDc/ONhZt/kP/KPfomUuyuSCT1I8vAPjfAq5tDtZ1cP+coPYDtG+WR1svWyElCL3bO9GVxw3dbyt393P+b88P2m3DzzUN70D2/isZbb3KWZ7f56K8C7tM8BbgR1PpMeO58CjfXE80IPY75wEe3t1FlRBPPgFZvSfpAOwo18z5ofD1pShwxUVJvXp0cNVBM4wVMChR1P6wl1yCPK+/zDoHr6SlcGIErP9KOMfTU4nVx4+bsiWZ7G+XOeflVGBThQfFh5oXf/1+gmWrJMAP7OYSnTjfWb3l/SY2SPpceCpnoX6x+cW6n8NCq23WXbkDyw7cmmWitjA8f0VaEZHQ0GeZLvM/3Tcuj9oxgB83nmDMtb8p+LSK/oDZUztj9070fXfFXi298/1vSef6LIosYFHiQvm90FAfxBu4tNp9CQBHa/oB9yndAwe3CdpvmwpUG0GuWC726SdZhENVplWn4T5AFrIZJRvS4WkJIMht0ICFdH4CivvFh1T5s4OeBxouSDYRF1RTRP9si+sX35ov8RasUinErTakopCJPgRajWpL6gtEwSb0WYCn5jbGGfJfE5jDxp9Gh1iVeqA+jJHSAQu12oyxgtDKhsOY0V1oM3CmbmqifNPPK6gsFiJwr7hsdiYjlFhm9+mGd8HFNA9ypMnEHCkDAT8BDiCQoNemmnO4/Nb9WxzKqBIBREOP3OkzI0OdD7i/UUVoqW0OArmGbXNXDy91FGJphsA9gvEzUCDaHRUSKZgF3oj42Bic80clQbGA4uHVKhAalICUWC7SXqoiMBeAYEKVupRwbH6DvAcf18Sj0ybPrGlwGW3uiMR99URlytyI3umt7sT/8wH0+ehDKJttpkNrB4f2cowml0oJbCVy+MU7FbEkVC4n2gMVfrL6sr8jkgJ/aZypt8tKoN1Y8uK2t1BhzMYElF9EQo6HUF3+4EXBsDmvfurTGzepRJmQsJKATJxViY0r1RZHg8UgYevOOiNO5QS7mYHP5mvBA7vDIR+lg8NDo/mBZ+LiSqJcjLlCKWYf9mks9ZgKtb8BT6TNOm4JrYDwSeiEXmTIzfz2JmG1rX0Aq27LzG3T2jd4yloXSv9cUBk3Ed2c83w0cGqaXazVmnWWPTooGCyOE4XKmri/LkuI6iNHADhqPTrxUK10eNHwseiMyk1SpXVaI5EBwubeyYf3Fu4rCgUsyFUWFsSKo17TV4wWhpFh8kQ8PmE4mKD2W4DcbnX5P8pZxX9tSa1Ci3LDH6fS4nsngLa9z4oWSrQDHgSuQwtw5fl3Q44Ly11ZmtglhxIS3E2lFLSQhqR1ZDPY+t5Tlan33297ifppf2p85eYbyU4DS06Br7Nmvzc6a/o1tWxA24xbanmvTWZzXvLK8rTO0dj5SS/26EI1Hb2pu5jTsLloz+QChAoA53RLQHQ5jEaBAOzpKAefixUmml0VBQSm7N78+ayYgkkcPBdZEDVZDjqbH5LPmFAu2RhptQ+JVIYLUxW3TPV5msws6nqvDaaXF+xAGNpbeFUgQw+wVTSIOlZ02RpqPRVW0MaIDecpjtGpYlk8RW5Vjj5j6UXFPKCXcjI2GRyDnvSWsBlH85J7mI3lA+bY65Wuk72fzq0DD8AEkVPYZSuaqmAF5bAqAs9I/rUmCwzCiZNAS+oLhHoUatsWGlZ+IfnQjZxrj2KUD30FPF/JUufu23RoqLiuEuEewf3XKmwnthphtFFfF4qm2CRfgENUwwsSSpVUhtRagEPHtV3Amvpg/WBJYjBsQoeATqSxewtTrPVLrWmQtU9iFvxBs/AKeh5iLIZC8ST7RgYBmqFQiF6wBHFmhNxrE8MCofN7NoUyP+blUiBIEOAw6hwRpVG0Chv5QD3DIiROnel213lcBXDBuhEgTfro762AoinBXS3IUvXtMQs3oD8h86h1du1hTCDaIaAon4mqbxU9GcpiTtLnFqnXmtjXbe4CsS+HF6F6LKg6lD98ecGF4p9TCpBFbQaXHpupEITMFnQwY95wSqTVmvX4xOV978fRm8bqw6ICnRZQItFKKlBa1VLa9Bb4Jw0gdTvbJQBbU75AUkB6tvEDEUz1G5UAyxUvUQmMNgGCpTZLtbQQvIgno6Fy8+srh5ltaid4bDzjJDTGT6XPVNbbFuHisKeI91YThPglINroJDQ+qLV/kCN2RuhX5SMc0fUojizOdwI5mVHAPtZty0ccDj89saEeahY6uvTGE3faLQspsdktVAYP3ALhcTXylCkELQTRSWuoFmQ1q+3pfWrkLSAwXMhqory9R9zaShyOKBqU3VkKT6oXtewHtwRdBCO5Mk9ACA3ZC04zgnsGbaG1X5H36vU+T1AI2vz9ikTx+YgOLijs5aV4elqDkPmajQ+tRpp0U3FcGBDDuyjoYd/6QX5yzd8nIwix5G7ydJeugM0FObXGqCOYWZj8PcdychlYbohGJR/MDs8WIWsLV5ctgXyFg9cL7mNAmTaxb4bBfy5YkyFm1fAu59VVTrVj20hAN2C1cL2hY8OZlvHGrdn7evMbk+9tntfR6M9+gjU1nnKs5lelvTaRMBeYFfov+ZirZNL2n5ZUQJFCgSxMSydWghWQ7YzfKD3DR3gP6kNndrlQSPczC0dYtl2R9aWLgCnEmErcP2chjqwPSkKABhK3HKpKqJ31o7hGa0je3MgYv1yesT6c2FoPy4MP2i/hJKUX4D2YCqTCQtvyIKUPJ+m+WCMPLzQh8fATUkygJgNJhuqaWHnjTIDSKI/J2VsTxfFMyjfg4ul3AGIWIXe73Mo0pwgJadJnCAC4wTxqn9DTT5j397CvIm/yeULmZPBF+IerJty4IVBeh+Sv/A69yVsipfMIGeS1VII6QhbBSqLbu/sVI09Yf51vfW04Bqo5z9mKmahl6VGBZaZFPjfBwAoopSQl45M+H+1hXZkwP8rEWQwH1kzwRVI5kqllO3VH7uZqcB83+DLrQiwjS/rURFgKCmJSAEk5jhWkBJyLuLUKceRk2iA+ncBMj1HemieYwoUmxQDqV4gHxyr7CZE47LrwBwFT3PbcJ+vukDs1Vf4nyyn0VISPMSuR6DpA1O0w2QOqKRygGjYg8KxvACriZGhSou3wGor8FlSroVNVGj0uoKKpnDxiJ7ehZDlODpLAaixOZNuY/KPQbS7XwPaSJPRNLhe94nfwxlxRJx6qnNEXZI7IjuNKkli2shVcEgWDUJmerCX9V4zkocM9OU75i8U5/ZwIG/sWfAxiBk+o4cr+fhgp7yHQ/lAr/jkvOfvwOW9OJe58+mAv8H44LuQKX+Q/EVCRMprdQ5RmKM3nyOq/K/3N2L1Ual5smo//A69Q3t+il7MCMoJtex4GBEbkfjFTkEVXm9Ox8weTgdoVzzIOiZOOJJOB9XOYh9krofOZXklg43MbOyNjqzKYO7D6zh1wiP9sJSV6Y6413HRAlvUhgVZQq17eBdfhfZZp4PSELD0+lzLIduJTNuBQDc4SBuapdY2/QLdaQNzPZhRYTRCbdwNpcdVxCaNKPI4PSyI8JzSHHC5AhbFDmck4izzBQWheNSsSuqrLC/3WCPmfpDr9FnBUdoS8rXURAWls6I97G2sjABxd6rCUzO5uXSkmxmYYq0dERuTXVvM/vJOaqgcX+M+maU5uL6A6ZFobdjCqJ9ivni1T6u0BpG0Nx/8lPuWrwah7yOMDYLK7G/2btixIprKzEPKAbyoT5pK1sOlMJ20d0qeU62UDPajLAloiVRkTzpSNwqK/WNwcjC/AFrOujRI+FPG+s1wx6zQTgaTOuXUstMB8mfWZ4ivtTWk1vXUBkQ+hwQZYL1rJLeAexjBLgQr4K8hDebQaQ98WWkv4jmbBRELXeuoRpWvxl7a6tX6FAClgi8b6VPsoC2vwN+BdKFBvFa1TCNqRVFtBn8YZ4AVBCpY1MDpCbtdEAlFQVVjVQSwX0bqxfAQOj134P2ox8m4uQxOXiso9IAaI63BgaWxdPTMsmuBITK79D7zyBFmH6JsKqtV5THo0VUoaLZEzRav3uBHvvokBh/QQ9JdaEQIhn9KvQ5LXMr21kNTVdG60YWM+d+GImS2cgRLUCdOYVeMpjCbeWBJTRpzABhoaiy1xP0GtOXSYYuDaIHFyB8E/kapF0M6E2qJDe7jscQolGj5wIRGq9Eh92CR0A3rtSLrByM9h0bpNXa0qmesp4yRCAVMLBJoAdXXt3wherKciKqQGwasRZAwTZK0QFRk583PyENl+LFDyhInCw4Kc/m5BibwerifmoOGOW1hqxjjhPLgLkpdZmvEY15tKY6hvWehxxzrOK5ZqiuYH6odFQ631wQCNe3h8KjaUEKRBx3XVX3ScdUCeFhZEHZxVmfERQNeCybU4DSFkISwWoNuBJdjVX4D8ItautyIekt4fAASwwlQmBKjBqbgshx8FzE1HfZVjzBCJnY/a9nOR4rZ9O8e2aXVMoCcu1/e4cu5wCp5J8V0iDZ0J/V9NJ3UVzL+VmUyrS9trfBKz7S+yP6JqaQ+Y/9RZDtNP+OChQVKFpHRWNTMcRItOlc06oLj5I7c4I5G3bzFXhKPodDjmrCo04PCDoybifP1ZqvKrgAZubWQ+zMDVTD1ZuRM0vaoO4cPjLjJigAQgE9YSsDuajIok200ALtCT6OyUFXKY7JHShaxbyl9kaieUwj6SPmwcMEwB3OailGQh/gYnCbHsILKCX6vHlhzn5LqVU6PB7xQCNTyuoDZpwEq1UCT+Xq9CR1Gu/P1+M9dnszY+5KBn6yEfTrwcwZL16MqRVkQB0WwlqptIZc3amWZIN/B19DbbQyS76y3G7bRNpjGBqDApbkecKrtoFUDEr9GatUmQ9vSuDYp51OfruJh+At7Jv023gBmOWrLhl5JJSD9tHZjG/N4YVSKsNKGU5ytEarVu8tCNi2XnGhXVJpoIGRiUS9cdsytx2krsPisxmJr4gHAA0VU/yt0BZUyh7aFVfUkSmKcnNZPtWJg99wRLrJeCl8ClJ4Wr8TZltG+jcGz0BLFbTACxiUkthpdFk2Bu84RsPgL6O3IvFm1vELriVQEoh4202Gb12sLs9lHUK6kyS1q0VWSYbnUhqAbtLNI5WtA2YGCEEPiDankR2q2EC5Y4HDk9mKIZzZti7T6003bQhlN25BzZE3b/sQLOpsl5OFhGFweLS/N+hfJWT8fSv7UUM96HljI/71Z536WgYr8rg9U5Df/G5O+uz+cJFdxuFP+OnA2U8g0wPk2YpMkTTl2R3LZXWOvM55szccmw09TE55K8yanPNXnjx5WT8i+2zsW9iINDgTskuIQ4E8Rq/2wkEwYVK5ItyxEXNhRmJCfLHfbRJvPC1kAeaK6WxqUSkkcTjk8+t0HsyTFUWiQJGVEJFdSHjeGvBaPON3qQuzeR1cgYQdLrHUGSwIBe5akBMCMYrQHPU69wcQHmeFWK7HnMmhkacEWThaXKwbRFPL4TOFxF1mTwiPquKKe0vNHnNFm8YGrxeGxQFjhE/jRm0OB7Owccjnkh7BIBnMJ4nl5BJKPzlwCmAXsjHtzC2IDLPts356z1F/FRUoLJaJal01e6YPMFNxS5nIX3stMgYut9JYCkFgK3pBXUZmx3p+Yud7f3uuyLtMf0cSorAX9Qea4Kl2BoB6leRnreS1bz2u713O9TaELhbxK5hroVQ63q3tNF7GmN2es2oWlVm5S9qqtCceKLE/0WK1ZldAuVAmNQV7ldtYkZbBVQriBkbi0IEeSdKaO7BIh5onBD2Goq0ztzPKlo1Ij1R4Ot7OH53wIFUFwlkoaRzQWKVE3YuizHKi7GohuS3vblbMu6Ow6b3pFrj9+ca7zXTRw4Q+qBKXmknq9zW6Q3G/sYlAHYgJTBHvZm1H2sz3tdJfU+DQaX01JT8f8/hwvXELAMtbTLiSu56Jj6m+yI5CNklHtxRrzqdBiC+2VpzZtJXnEHUtonrS1tmzF4swZgUcAF7q9Z7+oM3jTNPdB3Tk5PLTqJEOtGvtNc2lxKHFsXry0G7JUjKuG/tgcqLiUFKyhiAbtLMoIBUOUUfTzYsWB94FdtpmsXkZw/01P6ll3kpqWcXsIdFFfRLQPpohoF2HS9T3UTcHUDXnrMWh8vADttreQvw5V62Oa62RlRoocTuYdy7PMCMizJ9oiL8hSsGI4uIyluZRCFvJinCraTfpiUiFmqgq8MDnRSTUdpIb2WPpsnoizobnJXTvKoHBFIq7Lo069U9RfyuLTCuNUCAqqKJmcxBnTHDZUeotbWiWxlKgKEXO0KMTocb6A3W6DTuqDflYbKUZtOi8Y7NG/GI6mDYJzlq3EZPZaY+t9EaPDbzL5sdr6CooGsfqNjpaLRiN6/epaasJOryh6/GbUQQBi7xFFr/tuBC+seq0b0lSNWFl3TLHckfgnlm8EBo0KXmOOcZffCLGxeLUqXmXRAzwNqUextgGNNYFrQTE3cIguLyKf+xQusxkBaw4VoTqbXinJ0l9gumskpMq55FqwLJBDsKttHIspo7ilvjBTt7PLAZUR1NHaU22VewlqMM6WGqn4GtUX3DWDt6EJ9fgRbHW8vjc7zcr7dCHUxzS09R3e+A6etgEtqmIoS3m724TWB/X6YH2/JtQCtKXamqisbTFCr41aJdKNentmuZ5fJzXmMXvNxmH1lY1+jcbfiDgHQJBqFueArVJat4KmkLEuiLpUqR1yyWWALBwnxZsYKFmekL5jutF+qulyI7jcqSxKWzLqqKqa+E/mtiUDuRuVVgRyg2bliyyQe2BPP22QrxRshcNCvmEVITQVL20Ne+tKg9xUxGarxtV4qLFy9rhk8LYkFbwtYX8deKXPwrgbe4ZsBcnBoJKUTkdz3ZvzlFFbfjwesTzr33p4EucOKKEr8qHu4Dx5lLrNzZX1TPHsc4U/kOiLugM4dIm6Y3m/ZW4re/MQvkhOxSQJ2pbvVAxZGeIhTMP+oSo4PMRZuPYwKg17nYJtvAXrfyGs9RryUv7aIDFd+OSCJiDX2GZV6kkYL0xxZKT5LmRO++wqi6Q7Ee29po5toZg2pWeqNunaSZvyqkgGNUeDo2dA+7IBZ3Ghr8wD1jOVy+tWWajNCpQGiClQWqA3G3zib36PmlvmOLCCi7vT9RacFvUWgiHYVHMVCoTcsu+gShfNSeUW1zd7DAFV4npz2Np4yvDRN4xV2ItEk9lmKbcfWGdxuNBRxWjwYwdEX+8x/1/lMf+JApVRW+Q62d3s0JsErd43JogkB67NiVi4isP2wmCOm1j6we+0qI1xpKBNrCJOrpXDEqKVazDsGsUdSamgSoXXYDeBeZVXqRQOtU3HoPd0ca6wsAX+vQx9vYcszlNcaH71FkPXbJwegmInfpdVadFLg3KKBuVV+XQVL07XTuh0Gnt37cS33eX5lx6a9puyi/l7VuvTpf13E3+h38J8+k5vk/5mctJb0tmqvCa9B/w4r+nlc6eOP5S5vKpH9ml2HhPXlevC2Q5tlm4saQzq1f5hlUnPjM7rf1J253hu9B+9Gernk4b6MvKwBAbM01CnqQtlWpq6eJJxQ7KyjnQSUSl9CLODBqINtWwuHMkNddLjw4yZpAhoDdhZj5Rd/ps9BiYgX0ifmGEvdKG4DU2XGJTGWw4EobClbkG9vqAgqAKgylfnS9wDNIaGFywqsxsdg/0UDOKAXWiVFp2n3p64BhsdOM6Yb/XNR8ocHygWsY5I+bGoFaXxtpjNEjEGJHOrM1iiUotx7AxdUksopDsBfWR9pLiQpIS3DNIEMzH4EOzMFgC7psIEX5s/rMsmMaTJ0WU+VaEuG2H0MMSHADUoRONhJQJnMiQ9vfVqyChQ5nMCKZqMQEoyPHkPC6Xcx8KTwCF9odAYRK/U0Yey/o2uZB9AKdUofK2rGTV+VK1utGjR2FBKLG2z6OlWQCzV2BpoxH1ZcRP616y4SS+JxgRDHRgUEhsAthgnOFuNLGziKHN6Js09fs54p2O43xZukNvDqFR6p0PaVCEJqrK6TVLjrqZeUogecDN8ht1TIepHL2WhrFie7ApJwC4fPWIw/k8H4Fpoquiq8TEkrr6gvMpVenQGFre0vnVZEotbXlOSwuJekYXFrcrB4hYCi7uwDyxuQ550DK+kcLf2oF13ZPD5rOTaI+Ef52DCbh2EmgxMTy0FvRqz6RnqGlppN0GDXDkzWLDjl91s0vt7sknrnPFhs395ClwR0CjYsmkUghajHQaJJmoHC2ZsFeBOyruJK3IYoD0+F2ta9XUWF4K9pa3ZnmZD4Fxa0CEkvu0VgPoB7BSrup2KWNDVDIA6iKrbPCZKMQA/Rs7dz6fU9tx8Sm0vGWAWKe2X6SJ7hroGLLK1Dlhkaxhokh/on80i8Wnu9CVe6r+4FtpECPcUPUBUhMh/9fnfI0z18OmLCGFfVKA1tqoZA3+rizD2EqLZR4gWm3/tO4ToRmGcgfE3QvSPEWKoIsToIMRkwthFiHk3IZZHCbGORXb3HELERgyw5YjfE2K/nhAHvu9A5tcJB8mtIMQznxDvTwjx4Rp8rxMSmEFIENyvoSWERKIYfyckygjLbyck/lNCCvF6EUbxsYSUIE5WimOXgSiyHJ28KrDdqcTfVXi9GiU/tRMIqfs5IfXbCWmYhYHra8T3hhkwcM4mPQa+27wAYz8hLWgc34pjDEdfljacq+1fhIzAcds/JWQkmIFHoRng6F8S0qHB2ErImHsI6azFwPtdTxAydjzGD4SM+4qQ8bhvEz4jZOIDhEy6DONjQibjO1POwthGyNQ4IdPwO6Y/T8iM6YTMfIWQoy4gZI6WkKPR3/YY/H3sTkKOx3WecDIhJ4KV4qQQISdvJOSUowk59ShCTm8h5Ey8f1Y7IWdjzTsXsbLz3ibkAlzjRUBNXYxz/BLXf+lzhFwO+q4rLybkV22EXH0fIddiTq+3E3IDfuNNuI5bG8CzHSbkdtznO3BNd40j5DcFhPzWQsi9IEf5f/hd9+P6HphGyO9x/x5CwfbD+H1//B9C/oTftxhztQQysxT3dznuyQrIy1MXErK6mJC1IwhZh/l+diQhG3BfNn1HyGYvIVs+IGRbPSEvYI524Lg78XtfgXzsnkvIq5jzvbinf4UsvR4g5I1vCXkLc/rOJYS8h/n9APP5EeQO4kE+cRHyKeT2Mxzn888J+fJMQr7CtX+Na/62k5B/vUDIv22E7MfxfriKkB8hIwf+QcjBzwnl6gnlHyNU8UdCVZMJ1QiEaj8hVD+LUMNRhBqHE2rWE2r5DaG2ZwjFLaOOJwh1TSHUEyTUdytCtVsJDe0kNPIvQgvuIjR+LKFF7YSWGAgtPZPQ8mIUG75GaNW32BM8gE4dzxHasJrQxr8Q2vQzQlvwudYVhLZtIbT9J4SO+orQjt8T2oljjd1A6PhqQieWEzrpZUKn4PPT8N3puPaZvyb0qPsInXMloXNvInTeI4Qet4DQ4/cTCpmhJ35M6Ek4/09xPQt+Qehp5xN6RiWhZ/4PoWd9R+i5TYSeh2u7AOe46GpCL8bxLvmQ0Mvxu680EfqriYReczOh140ndCE+f8PbhN6EY9+Cz9z2I6G3LyL0zjMIvXsSofecROi9FxN6XwmhvxtF6INXEPoQ7tnDIwn9Yxehi64h9M/rCX3cSOgTuLZlTxL6JH7fylWErsJrq/F71uL9dTFCn1lC6Po3CN1wP6Gb8Huff5DQLQsJ3XYqodtx3hfx/ksPEfoyrvMVXOfuZkL3TCd03/uEvt5C6Ju4vneqCH0P1/0BjvNRB6F/P4vQj38g9B8hQj/HnH6J836N732zh9DvHIT+G9f6/WeE/jiC0INeoKvPJxx3POGE5YRTvkA4jYdwuggB/pVwRrxn3k446wbCiW8TzrmDcO5PCOcLEs5/LuGCLxIuIhKu4FbCxUsJVwS0dsl0wpX5CVcxk3BV1YSrOZVwkAOu4WbCDZtBuKaXCNdyP+Fge7gR8wg3chvhRk8k3JizCDeWI9y4Rwg3YSnhJj1NuKkKwk2/iHAz8f3ZTYQ7egHhjllEuGN/INx88JmfeCfhfvI84U5eQ7hTfkW4U0sId3oD4c40E+5nnxPu7P2EO/dBwp23l3AXFsH0v0e4i3cT7hJ8/zIc64qRhLsSv/tq/NZrcI7rXiPc9T8n3I1dhLv5GMLdegfhfo3z3v4+4e5cSbi7f0m4e0YT7rcfE+7/XUe4+3HND4wl3IN4/6G3CPcIjvNoBeH+hN/8GN5fvJFwS84m3FIT4ZYXEO5J3K+VRixYawm3GudZO59w6zDW/4JwG/B7NuK+PIfXN19FuK049nZcwwt7CLcD9+rlQsK9gvv5F5zr1Q8It++nhHvtS8K9eQnh3v4L4d6bRLgPTibcR+8Q7uNGwn2C3/hZPeG++B3h/vlnwn39KeH+ZSXcdx8Sbv/PCPc9jvs/zxLuAK71IFjfaAnhudWEF3YTXvlHwqtBfa35hPB6E+FNSsKb8Zp1LuFtrxPeYSO883vCu9cT3vsw4f1fED74KOHDtxM+qid8AY4Tv5LwRR2EL/6R8KWfwQFTE75qDOFr1hC+7jHCN2wj/LDLCN+MY7QeR/i2Bwk/EscdVUz40UcRvuNNwneWE77raMKPayL8+AThJzkIP3kR4ae2E37a7wk/A10uZx5P+KMmEH72YsIfjePP/Yrw8zoJfxzGfJHwJ+J3nYTj/fQSwp8KHt7T3iH8GSHCn4nxs58S/qwPCX/OyYQ/z0X4868i/AV/I/xFnxL+4msIf8mFhL/s54S/ooHwV+Far24m/DV3EP66+YS/Hue6sYLwN48m/K24B7/eQfg7Wwl/9y7C3/MXwt+LY92H+/W76YR/8DbC/wHn/yMc0Ue/I/yfvib8Y/cTfomW8E/cQvhlPxD+yf8h/FPTCL96CeHXziL8uhMIv/4swm/A9zbtIfzmyYTfOoLw2zFexP1+aQPhd+H3vHIX4XefTfg9IJXeN4/wrz1L+Dcw3rqJ8O/gd7yH+/ZhEeH/Vkj4j3GPP91E+M+eJ/wX+PtL3OOvcL++wTV9FyH8/tmE/wFz8CNIchM74CZ9QgQwFQmKPxNBXUEEzadE0DcTwfgtESx3EMH2CBHsK4ng8hPBM5sIfg0RgmuIED6GCNGfESF2GxEKDxCh+HsilJUSocJChMr3iVB9ARFqbyVCg5EIjU8ToennRGj5OxHaDEQYcTER2jcRYdSFROj4AxE6A0QYi2sYX06EiZOJMFlFhKk41vQoEWaiNnUWrmmOgwhzTyfCvBlEOG4MEebXEOFExChOaifCT5cSYcFUIpyGazjjWSKcBbq9c94gwnkdRDgfv/HCXxDhFy8T4ZcbiHDpBCJcju9feSwRrlpLhKtPI8I1bxFhYRMRbsDnb9xGhJtxbbfiN94+kQh3XkWEu4uIcI+TCPdeQoT7riHC71YR4cHriPDQD0R4GFm+Px5FhEf3EuFPzxHhMXzv8cVEeALXvOwcIjzZQoQV7xJhVRkRVuPYa/5ChKdx7nV47Vnci434fZuuJ8LzuI9bUNu/FcfePowILzqkQSWPd9TdI75ZeLyp9V/o7fAxc3Rffmr0TPb43s79/zz474NGdH2E70SUsPWSf8y9TDppIcbTpIPvJJ3cuaQIbI+1XIK00xPIWXQW6aBzSR3XRKq4MCmmfhKkr5Miso3E6DukkDuJFNH/RyzcODxHJII7j8S5kRinkSLuWPyN0CA3CZ//hDSiBQ/iUWQkx5NyLoBj1pFW/lxSzz2Nz5ZjnEaKufl4jGGEME4gMYwi6sJ1nU00uAb2eiG3HI/n4PEXGOPw/Do8zsLjfJz3V3i8GOMhUsj78Xg+3jsdgx3nNXIzu2Y8dtI9BFEz0syNwN9v4nftxO95Dc//h0TpXfjsP/H3Plz3Xjx/kEToIjzH37iOYvoPPJbic5/hvS/wnY/x2ha8Bkedfo5zmfH8ATzyuJ4CfObv0rm76BnkF/QT0o5dRzktI9diHMWPJGYMC8YYvo0Y+dlEhaHE0PMTDx7gZ2PMwDgef7dBA9lngsSAKg0n78PzcuLgw8QkPZffD+E9vfS5BnyGPZYRsJgnhwrnOh7DhOd+YuO+JTq+Hs9TQ8T323BMHZ7bMXzJRzbYsUIYPmnoUYXlxDDwEwnB0CEMrJMex0vXQXA8LR7VOL9VOo482Hc9eN2bHDacy5zxvsjbpHNF8T0sBWQ0RjVGDUZV8nl1+rVqUorHFmn4MOfy56twjGF8CR6j+JydNPEByFobsafvgyLrntjxngUjKP3u1L2owG+0J6/HjOHCOSgpw+dqc66pOPm8GjpUnf7bSAJoPxXkPiUB7gDGQfyNzR7OV4Q5quFrcayyXq5HIf3+YPqabLi+zOuqwijC0GXMTeY8seHA8OBanCSKdhWB5PXV8bNICR7LYcnLcW2op5feK5LkJnUtqfN0z3uYn4HvTcaYS+Lp52xMk45XnbwPVXyERHB9Jbj3JTheCWSwBDJVhNfiuOZCFvySriNzlON+Zd4HXc5vi2U8p8QNalQ/7q0f99GP8/khb8X4XVFcS5SfgzErOWYkxzyMNsiDA7/VlxwFGAEMN4Yz+VyJe81eDydHX3OTusb6nNEm6U4x5rgYUdkiXG+R9NgG+Uvdn+4Ryfm7ISm7HRjtyb+bk6+1S693X48nfR0nQEZm5citfC1ezH8VrqEK9qICMlSMUYp7VIj7UYbvMTkukMYcPO/ttzVJ+mTG0CaHjm87uD/jby30z4L50eH+ibyXuLkvYL80RAVaddSK4vF7PLZJ+m6Xhln625XxWyxJebdI81vfx33NkHGwR2vZ4PXyebgfiZnbj+M6MSI4zhy8Nw12ZQ7msIFdc4be1+foTL30fm1apzshT52STIWk6z4Wj/MzRhnuyTTYRzaOxhiP39JGKnGPS5LznxqxnL9D0Dmm06WSjJRIss9er8j6TEPOIzu2LCvFvcrjPPzeyTju+Ax7UZaXnLYkbUJN0tYEpdd7sylMlvzSdbPvxZPXLI9K6bXSHr+182AC95HHdRn4k7BOTMKYhXEsRgXWAxdex/qD+2aDvjDZsWH+bPiulW+U1rJwj997LH6frg8Z6f5dtelHP86hxzHtGEYMB0Y4Y8zC3M+CbEySZMCavg+Z5y3IkL/hkl0P4vN2zL8L33XhuTzk+++SRhjy0ybpV5QXpTWOPZdfK0vKOjtmSJJlF3o/uZLf9fPNWC/tkDs/Rkz6rBWP7HzBHnaxDOv+JMzffMjtfElX2W+OwdbWJG1ysfQbaPK3tCZ/x9H4vcficydhjML5ZP20JWVWHmXptVE+V+Z9T10D8wWs0vdEHMuNa/DwC/BYK60pHum1Jvz+SvxdJZ3DLY1q6A07vhq2RS3ZLwuux4dHH36nT7oP9ck1zppzztz1IJb8XLT7+PCrpOgvHzo4jPzAfwy/903+xNx4MPcUvJQovQ1ZAcLdwM3BSxPkR3ocqcH/2f/RzK+PmhQKkQ0ktO+e5DlOYz2T5TPQpRwiniQED5tIA+INnCMvvSsSwYRYK/83vKGmf8OnjieXhfxxZfzkxXSxsFi92LzYvti92Lf4nMXnLb5o8ZWLf7X4psW3LX5w8aLF6xY/v/jdxV8t/mbxvxb/+PiZj5/9+HmPX/D4TY9veHz/4z8uIUvUS3RLqpbULRm2pH3J+CUTlxy75PglC5asW/L8kr8+Uf5E6xOjn1jzxLql+qUdS8cvnbh05tJjl16y9J6l9y69b+mDSxctXbz0iaUrlq5bun3prqUfLVMvK1jWuKx9Wceyi5ZdsuyKZQuX3bzszmWLlgvL1cv1y0PLb1t+5/J7lm9b/tflHy3/ePlny/+1/Psn6ZOznpzz5ElPnvrkz548+8nNT257cseTe558bYV5hWuFb0VoxdQVc1acvOLhFatWvLni3RUfrvh8xZcrvloprnStLF5ZvXLMyokrH1z58MpFK9et3PWU5an7n3p4VdGqllWXrrpi1dWrblr161X3rLpv1WOrPlv1z1UHVtPV6tUFq+tXN61uX33s6vmrP14zZ815ay5ac8maq9dct+bxNUvXrFvz7Jrta3as2blm15rX1ryx5u01H675fm3T2ta17WvHrp259tS1Z689b+01a69b+6e1j61dunb12qfXPvN03dMNTw97uvXptqenPj3n6f3ryDrLOsc61zrfuti64nVV665et3DdTeseXLdo3bp1z697ad2/1u1f9+MzwjPmZwqeueKZq59Z+Mxdz/x2fcf6sesnrj96/THrT1i/YP0l629dv+jZkc+OfXbaszue3bXhtg2Pb1i6YcWGZzZs3LB9w1sb/RtDGws2Vm6s3jhsY/vGCRsXbDx7480bb9t438Z3N7k3+TaFNhVtqtl0xqZFmxZvWrnprU3vbvpw0+ebvtz03abvnyPP2Z479bnXnnvn+ZOf/+r5/ZuLN5dtHrN57ObxmyduPnrzcZsv3XzF5ps3/3rzPZtXbF6zed3m5zdv37xr86ubP9v8z83fbqFblFvUW3xbCrYUbSnb0rilaUv7lo4tM7fM23LJlru2/GnL0i0rtqzesmHLc1t2bNm15dUt7275bMv3W4Wtoa2tW9u3dmyduHXO1vO3XrT10q3XbL1h6y1bf7317q33bP391ke2Lt5Gtgnb1Nss2+zbfNuGbZu47extV2y7ZttN2w5sJ9uF7Ybtlu2u7WXbp26fuX3j9ue3b9v+yvbd2/dsf337W9u/f2HSCye88MwLu1+c+uJJL364w7CjeEfVjmE72naM2TFnx2933Ldj0Y7Hduza8eFL6pfmvbR055yd83bO33nezot23rbzzp0P7/zwZd/LVS9f9PK7u87YdfauS3Y9vGvjrt27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"
