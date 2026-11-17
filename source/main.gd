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
	var o := Color(0.96, 0.6, 0.18)
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
		"snake", "wood", "kim":
			var s := mg_r * 0.8 * pop_scale(mg_big)
			if key == "snake":
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
				if key == "snake":
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
				p = Vector3(bx * 1.02, -0.2, bz * 1.02)
				v = vrep + 0.06
			else:
				p = Vector3(bx * 0.96, -0.42, bz * 0.96)
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

func make_house(pos: Vector3, size: Vector3, wall: Color, roof: Color, style: String = "thatch") -> Node3D:
	var house := StaticBody3D.new()
	house.position = pos
	add_child(house)
	house_rects.append(Rect2(pos.x - size.x / 2.0 - 0.7, pos.z - size.z / 2.0 - 0.7, size.x + 1.4, size.z + 2.6))
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
		soft_gloss_mat.roughness = 0.42
		soft_gloss_mat.metallic_specular = 0.6
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
	root.position = Vector3(0.52, 1.45, 0.0)
	root.rotation.y = -PI / 2.0
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
	var c := Color(0.95, 0.58, 0.18)
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
	grass_mat = make_tex_material(Color(0.5, 0.68, 0.3), tex, 0.05)
	forest_mat = make_tex_material(Color(0.4, 0.58, 0.28), tex, 0.06)
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
	var blades := [[Vector2(-0.05, 0.0), 0.5, 12.0], [Vector2(0.06, 0.03), 0.38, -16.0], [Vector2(0.0, -0.05), 0.3, 6.0]]
	for b in blades:
		var o: Vector2 = b[0]
		var h: float = b[1]
		var lean := deg_to_rad(b[2])
		var base_c := Color(0.55, 0.68, 0.5)
		var tip := Vector3(o.x + sin(lean) * h * 0.5, h, o.y)
		var corners := [Vector3(o.x - 0.045, 0, o.y), Vector3(o.x + 0.045, 0, o.y), Vector3(o.x, 0, o.y + 0.045)]
		for i in 3:
			var a: Vector3 = corners[i]
			var c: Vector3 = corners[(i + 1) % 3]
			for v in [[a, base_c], [c, base_c], [tip, Color(1, 1, 1)]]:
				st.set_normal(Vector3.UP)
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
		Rect2(-3.6, -18.0, 3.4, 36.0), Rect2(-12.6, 6.5, 27.0, 3.0), Rect2(18.4, 6.5, 3.2, 15.0),
		Rect2(-40.0, -17.4, 80.0, 3.8), Rect2(-19.6, -5.8, 4.4, 3.0), Rect2(-10.2, 12.0, 3.4, 2.4),
		Rect2(30.0, -39.0, 7.0, 7.0), Rect2(9.0, -1.5, 10.0, 7.0), Rect2(-15.5, -4.2, 5.5, 4.8)] + house_rects
	var spots := []
	var tries := 0
	var grass_n := GRASS_COUNT / 2 if light_mode else GRASS_COUNT
	while spots.size() < grass_n and tries < grass_n * 4:
		tries += 1
		var p := Vector2(r.randf_range(-38, 38), r.randf_range(-38, 38))
		var ok := true
		for k in keep_out:
			if k.has_point(p):
				ok = false
				break
		if ok:
			spots.append(p)
	mm.instance_count = spots.size()
	for i in spots.size():
		var p: Vector2 = spots[i]
		var sc := r.randf_range(0.55, 1.0)
		var basis := Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3(sc, sc * r.randf_range(0.8, 1.3), sc))
		mm.set_instance_transform(i, Transform3D(basis, Vector3(p.x, 0.0, p.y)))
		mm.set_instance_color(i, Color(0.36, 0.6, 0.27).lerp(Color(0.62, 0.8, 0.34), r.randf()))
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

func make_tree(pos: Vector3) -> void:
	var tree := StaticBody3D.new()
	tree.position = pos
	add_child(tree)
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
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.45
	shape.height = 2.0
	col.shape = shape
	col.position.y = 1.0
	tree.add_child(col)

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

func make_person(parent: Node3D, kind: String, c: Color, solid: bool) -> Node3D:
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
	sun.light_energy = 0.85
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
	e.ambient_light_energy = 0.5
	# 멀리는 살짝 뿌옇게 (공기감) + 색을 조금 선명하게
	e.fog_enabled = true
	e.fog_light_color = Color(0.72, 0.84, 0.92)
	e.fog_density = 0.0018
	e.fog_sky_affect = 0.0
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = 1.05
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
	add_box(self, Color(0.33, 0.58, 0.3), Vector3(full, 0.04, 23), Vector3(0, 0.02, -28.5)).material_override = forest_mat
	var creek := add_box(self, Color(0.35, 0.6, 0.85), Vector3(full, 0.06, 3), Vector3(0, 0.03, -15.5))
	creek.material_override = water_mat
	creek_mat = water_mat
	add_box(self, Color(0.55, 0.4, 0.25), Vector3(3, 0.2, 4), Vector3(-2, 0.1, -15.5)).material_override = plank_mat
	# 개울은 다리로만 건널 수 있어요 (점프로도 못 넘는 보이지 않는 벽, 다리 자리만 비워 둠)
	var creek_left_len := (-3.5) - (-MAP_HALF)
	var creek_right_len := MAP_HALF - (-0.5)
	add_solid(Vector3(-MAP_HALF + creek_left_len / 2.0, 2, -15.5), Vector3(creek_left_len, 5, 3), none)
	add_solid(Vector3(-0.5 + creek_right_len / 2.0, 2, -15.5), Vector3(creek_right_len, 5, 3), none)
	add_box(self, Color(0.8, 0.72, 0.5), Vector3(2.5, 0.04, 30), Vector3(-2, 0.02, 1)).material_override = sand_mat
	add_box(self, Color(0.8, 0.72, 0.5), Vector3(26, 0.04, 2.5), Vector3(1, 0.02, 8)).material_override = sand_mat
	add_box(self, Color(0.8, 0.72, 0.5), Vector3(2.5, 0.04, 14), Vector3(20, 0.02, 14)).material_override = sand_mat

func make_village() -> void:
	# 놀부네
	make_house(Vector3(14, 0, 2), Vector3(9, 4, 6), Color(0.95, 0.93, 0.86), Color(0.28, 0.3, 0.36), "tile")
	make_npc("nolbu", "놀부", Color(0.6, 0.2, 0.45), Vector3(14, 0, 7.5), 1.15, true)
	make_npc("wife", "놀부 마누라", Color(0.75, 0.3, 0.3), Vector3(10.5, 0, 7.8), 1.0, true)
	nolbu_gourd = make_gourd_at(Vector3(19, 0, 8.5), Color(0.6, 0.68, 0.4), 1.7)
	make_npc("dokkaebi", "도깨비", Color(0.2, 0.55, 0.6), Vector3(19, 0, 8.5), 1.3, false).visible = false

	# 흥부네
	hut = make_house(Vector3(-13, 0, -2), Vector3(4.5, 2.4, 3.5), Color(0.93, 0.89, 0.8), Color(0.8, 0.66, 0.3), "thatch")
	make_npc("heungbu", "흥부", Color(0.85, 0.6, 0.35), Vector3(-12, 0, 2.5), 1.0, true)
	make_npc("kid1", "첫째", Color(0.95, 0.75, 0.5), Vector3(-16.5, 0, 4), 0.7, true)
	make_npc("kid2", "막내", Color(0.98, 0.82, 0.6), Vector3(-9, 0, 5), 0.55, true)
	var nest := make_spot(Vector3(-16.1, 0, -3.15), "nest", "", "제비 둥지", true)
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

# ---------- 마을 꾸미기 (돌담, 감나무, 장독대, 텃밭, 꽃, 징검돌, 시냇가) ----------

# 둥근 덩어리 여러 개를 한 번에 그려요. items 한 칸: [위치, 크기(가로,높이,세로), 색]
func add_blobs(parent: Node3D, items: Array, mat_in: Material = null, flat: bool = false) -> MultiMeshInstance3D:
	if items.is_empty():
		return null
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
	for c in canopy:
		var k: float = r.randf()
		items.append([Vector3(c[0], c[1], c[2]), Vector3(c[3] * 2.0, c[3] * 1.7, c[3] * 2.0), Color(0.3 + 0.08 * k, 0.6 + 0.1 * k, 0.25)])
	for i in 18:
		var c: Array = canopy[r.randi() % canopy.size()]
		var dir := Vector3(r.randf_range(-1, 1), r.randf_range(-0.3, 1), r.randf_range(-1, 1)).normalized()
		var at := Vector3(c[0], c[1], c[2]) + dir * float(c[3]) * 0.95
		items.append([at, Vector3(0.44, 0.4, 0.44), Color(0.98, 0.45 + 0.12 * r.randf(), 0.1)])
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
				items.append([Vector3(x, 0.3, z), Vector3(0.28, 0.5, 0.28), Color(0.97, 0.96, 0.9)])
				items.append([Vector3(x, 0.55, z), Vector3(0.5, 0.3, 0.5), Color(0.3, 0.62, 0.28)])
			else:
				var k: float = r.randf()
				items.append([Vector3(x, 0.33, z), Vector3(0.62, 0.5, 0.62), Color(0.45 + 0.12 * k, 0.75, 0.38)])
	add_blobs(root, items)

func make_flowers(pos: Vector3, r: RandomNumberGenerator) -> void:
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	var petals := [Color(0.97, 0.55, 0.7), Color(0.98, 0.98, 0.95), Color(0.98, 0.85, 0.25), Color(0.85, 0.6, 0.95)]
	var pc: Color = petals[r.randi() % petals.size()]
	var items := []
	for i in 3:
		items.append([Vector3(r.randf_range(-0.3, 0.3), 0.3, r.randf_range(-0.3, 0.3)), Vector3(0.9, 0.6, 0.9), Color(0.25 + 0.1 * r.randf(), 0.55 + 0.1 * r.randf(), 0.25)])
	for i in 9:
		items.append([Vector3(r.randf_range(-0.5, 0.5), r.randf_range(0.4, 0.62), r.randf_range(-0.5, 0.5)), Vector3(0.22, 0.2, 0.22), pc if i % 4 != 0 else Color(1.0, 0.95, 0.6)])
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
	for zb in [-14.1, -16.9]:
		var bank := []
		var x := -38.0
		while x < 38.0:
			x += r.randf_range(1.0, 1.7)
			if absf(x + 2.0) < 2.3:
				continue
			bank.append([Vector3(x, 0.08, zb + r.randf_range(-0.25, 0.25)), Vector3(r.randf_range(0.6, 1.1), r.randf_range(0.35, 0.6), r.randf_range(0.5, 0.8)), stone_color(r)])
		add_blobs(self, bank, stone_blob_mat)
	var foam := []
	for i in 22:
		foam.append([Vector3(r.randf_range(-38, 38), 0.07, r.randf_range(-16.4, -14.6)), Vector3(r.randf_range(0.6, 1.4), 0.04, 0.12), Color(0.85, 0.95, 1.0)])
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
	add_box(self, Color(0.42, 0.66, 0.38), Vector3(600, 1, 600), Vector3(0, -0.6, 0))
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
			foam_mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(fd[2], 0.04, 0.12)), Vector3(x, 0.07, fd[1])))
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
	var hedge := Color(0.2, 0.4, 0.22)
	add_solid(Vector3(23, 1.1, -37.5), Vector3(1, 2.2, 4), hedge)
	add_solid(Vector3(23, 1.1, -31.25), Vector3(1, 2.2, 2.5), hedge)
	add_solid(Vector3(31.25, 1.1, -30), Vector3(17.5, 2.2, 1), hedge)
	bush_col = add_solid(Vector3(23, 1.0, -34), Vector3(1, 2.0, 3), Color(0.35, 0.45, 0.2))
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
		say([["장터 상인", "엽전이 모자라는구나. 우물, 나무터, 짚더미에서 품을 팔면 엽전을 벌 수 있단다."]], Callable())
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

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if stick_index == -1:
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
	cam.position = player.position + CAM_OFFSET.rotated(Vector3.UP, cam_yaw)
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
