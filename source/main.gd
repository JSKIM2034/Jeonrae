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
	make_book_ui()
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
	return talking or mg_active or in_card or book_open

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
	if book_open:
		return null
	for b in [jump_button, turn_button, action_button, book_button]:
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
