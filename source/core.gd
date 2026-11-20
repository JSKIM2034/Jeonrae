extends Node3D

# 모든 장이 함께 쓰는 공통 부분: 주인공, 카메라, 화면, 대화, 미니게임 틀, 소리, 3D 부품.
# 장마다 다른 맵과 이야기는 chapter1.gd, chapter2.gd ... 가 이 파일을 이어받아 만들어요.


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
const ZOOM_MIN := 0.3
# 가까이 당기면 카메라가 낮아져 하늘이 보여요 (주인공 뒤 어깨 높이)
const CAM_NEAR := Vector3(0, 1.5, 4.0)
var pinch_start_angle := 0.0
var pinch_start_yaw := 0.0
var pinch_rotating := false
var cam_hint_seen := false
var cam_hint_timer := 0.0
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

	load_controls()
	# 마지막으로 있던 장이 다른 장이면 그리로 바로 가요 (처음 켤 때 1장 화면이 열리므로)
	var want := saved_chapter()
	if want != "" and want != chapter_id() and CHAPTER_SCENES.has(want) and chapter_id() != "":
		leaving_scene = true
		get_tree().change_scene_to_file.call_deferred(CHAPTER_SCENES[want])
		return
	load_world()
	make_sounds()
	build_chapter()
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
	after_ui()
	make_game_ui()
	make_fx_ui()
	card_overlay = make_overlay(1.0)
	card_overlay.gui_input.connect(on_card_input)
	card_label = add_label(card_overlay, "", 0.92, 0.13, 0.26, 0.87, 0.74)
	resumed = restore_progress()
	update_quest_text()

	cam = Camera3D.new()
	cam.fov = 64.0
	add_child(cam)
	cam.make_current()
	make_card_scroll()
	start_chapter()

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

# ---------- 고운 질감: 코드로 직접 그린 그림들 ----------
# 한옥. style: "thatch" 초가집 / "tile" 기와집. 앞쪽은 +z 방향

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

# ---------- 이어하기: 진행 저장 (모든 장이 하나의 세계로 이어져요) ----------
# save.cfg 안의 칸
#   [world]  모든 장이 함께 쓰는 것: 지금 있는 장, 엽전, 가진 물건, 입은 옷
#   [ch1_state], [ch2_state] ...  장마다의 이야기 진행 (각 장 스크립트가 채워요)
const SAVE_PATH := "user://save.cfg"
const SAVE_VERSION := 1
const CHAPTER_SCENES := {"ch1": "res://main.tscn", "ch2": "res://chapter2.tscn", "ch3": "res://chapter3.tscn"}
var resumed := false
var save_timer := 0.0
var leaving_scene := false

# 이 장의 이름 ("ch1", "ch2" ...)
func chapter_id() -> String:
	return ""

# 이 장의 진행을 사전으로 (각 장이 덮어써요)
func chapter_state() -> Dictionary:
	return {}

# 저장된 사전으로 이 장을 되살려요 (각 장이 덮어써요)
func restore_chapter_state(_d: Dictionary) -> void:
	pass

func load_world() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) != OK:
		return
	coins = cf.get_value("world", "coins", 0)
	shown_coins = coins
	has_yeot = cf.get_value("world", "has_yeot", false)
	has_shoes = cf.get_value("world", "has_shoes", false)
	has_sickle = cf.get_value("world", "has_sickle", false)
	has_hanbok = cf.get_value("world", "has_hanbok", false)

func saved_chapter() -> String:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) != OK:
		return ""
	return cf.get_value("world", "chapter", "")

func save_progress() -> void:
	if chapter_id() == "" or leaving_scene:
		return
	var cf := ConfigFile.new()
	cf.load(SAVE_PATH)
	cf.set_value("world", "version", SAVE_VERSION)
	cf.set_value("world", "chapter", chapter_id())
	cf.set_value("world", "coins", coins)
	cf.set_value("world", "has_yeot", has_yeot)
	cf.set_value("world", "has_shoes", has_shoes)
	cf.set_value("world", "has_sickle", has_sickle)
	cf.set_value("world", "has_hanbok", has_hanbok)
	var st := chapter_state()
	if player != null:
		st["pos"] = player.position
		st["yaw"] = cam_yaw_target
	cf.set_value(chapter_id() + "_state", "data", st)
	cf.save(SAVE_PATH)
	save_timer = 0.0

# 저장된 진행이 있으면 되살리고 true
func restore_progress() -> bool:
	if has_hanbok and player_body != null:
		recolor_outfit(player_body, Color(0.45, 0.78, 0.72))
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) != OK:
		return false
	var st: Dictionary = cf.get_value(chapter_id() + "_state", "data", {})
	if st.is_empty():
		return false
	restore_chapter_state(st)
	var pos: Vector3 = st.get("pos", Vector3(0, -100, 0))
	if pos.y > -5.0:
		player.position = pos + Vector3(0, 0.3, 0)
		cam_yaw = st.get("yaw", 0.0)
		cam_yaw_target = cam_yaw
	return true

# 다른 장으로 옮겨 가요 (지금 장을 저장하고, 다음에 켜면 그 장에서 이어져요)
func go_to_chapter(id: String) -> void:
	save_progress()
	var cf := ConfigFile.new()
	cf.load(SAVE_PATH)
	cf.set_value("world", "chapter", id)
	cf.save(SAVE_PATH)
	leaving_scene = true
	# 다음 장을 짓는 동안 화면이 멈춰 보이지 않게, 두루마리를 먼저 펼쳐 둬요
	show_card("책장을 넘기는 중...", 1.0, 30.0, Callable())
	await get_tree().create_timer(0.9).timeout
	get_tree().change_scene_to_file(CHAPTER_SCENES[id])

# 이야기 진행만 지우고 처음부터 (도감, 엔딩, 설정은 남겨요)
# 지금 장의 이야기만 처음으로 (엽전·물건·다른 장 진행은 그대로)
func reset_chapter() -> void:
	var id := chapter_id()
	if id == "":
		return
	var cf := ConfigFile.new()
	cf.load(SAVE_PATH)
	if cf.has_section(id + "_state"):
		cf.erase_section(id + "_state")
	cf.save(SAVE_PATH)
	leaving_scene = true
	get_tree().change_scene_to_file(CHAPTER_SCENES[id])

func reset_progress() -> void:
	var cf := ConfigFile.new()
	cf.load(SAVE_PATH)
	for sec in cf.get_sections():
		if sec == "world" or sec.ends_with("_state"):
			cf.erase_section(sec)
	cf.save(SAVE_PATH)
	leaving_scene = true
	get_tree().change_scene_to_file(CHAPTER_SCENES["ch1"])

# 화면 돌리기·가까이 보기 안내 (한 번만)
func update_cam_hint(delta: float) -> void:
	if cam_hint_seen or chapter_id() == "":
		return
	if is_busy() or mg_active or in_card or (walk_hint != null and walk_hint.visible):
		cam_hint_timer = 0.0
		return
	cam_hint_timer += delta
	if cam_hint_timer > 4.0:
		cam_hint_seen = true
		save_controls()
		say([["", "두 손가락을 화면에 대고 비틀면 화면이 돌아가요.\n벌리면 가까이, 오므리면 멀리 보여요.\n아주 가까이 당기면 하늘도 올려다볼 수 있어요!"]], Callable())

func update_autosave(delta: float) -> void:
	save_timer += delta
	if save_timer > 5.0 and not mg_active and not is_busy() and chapter_id() != "":
		save_progress()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if player != null and not mg_active:
			save_progress()

# ---------- 해와 하늘 (모든 장 공통) ----------

var sun_light: DirectionalLight3D
var sky_mat_ref: ProceduralSkyMaterial
var env_ref: Environment
var star_node: MeshInstance3D
var time_of_day := 0.0

func make_light_and_sky() -> void:
	var sun := DirectionalLight3D.new()
	sun_light = sun
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
	sky_mat_ref = sky_mat
	# 위는 맑은 파랑, 지평선은 따뜻한 크림빛
	sky_mat.sky_top_color = Color(0.33, 0.58, 0.9)
	sky_mat.sky_horizon_color = Color(0.93, 0.9, 0.82)
	sky_mat.sky_curve = 0.12
	sky_mat.ground_horizon_color = Color(0.8, 0.84, 0.72)
	sky_mat.ground_bottom_color = Color(0.5, 0.62, 0.45)
	sky_mat.sun_angle_max = 20.0
	sky.sky_material = sky_mat
	# 하늘빛이 바뀔 때 다시 그리는 반사 지도를 작게 해서 버벅이지 않게
	sky.radiance_size = Sky.RADIANCE_SIZE_32
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
	env_ref = e
	add_child(env)

# 하루의 시간대: 0 = 한낮, 0.5 = 늦은 오후, 0.68 = 노을, 0.82 = 해 질 녘, 1 = 깊은 밤
const TOD_KEYS := [
	[0.0, -46.0, Color(1.0, 0.9, 0.74), 0.82, Color(0.33, 0.58, 0.9), Color(0.93, 0.9, 0.82), Color(0.86, 0.88, 0.86), 0.62, Color(1.0, 0.95, 0.86)],
	[0.5, -24.0, Color(1.0, 0.8, 0.58), 0.8, Color(0.36, 0.54, 0.84), Color(0.98, 0.84, 0.66), Color(0.92, 0.84, 0.74), 0.58, Color(1.0, 0.9, 0.78)],
	[0.68, -9.0, Color(1.0, 0.56, 0.32), 0.7, Color(0.34, 0.36, 0.62), Color(1.0, 0.58, 0.36), Color(0.92, 0.6, 0.46), 0.5, Color(1.0, 0.78, 0.66)],
	[0.82, -4.0, Color(0.8, 0.45, 0.4), 0.18, Color(0.12, 0.13, 0.3), Color(0.44, 0.3, 0.42), Color(0.36, 0.3, 0.42), 0.42, Color(0.7, 0.66, 0.86)],
	[1.0, -52.0, Color(0.58, 0.68, 1.0), 0.32, Color(0.03, 0.04, 0.12), Color(0.1, 0.12, 0.26), Color(0.1, 0.12, 0.22), 0.42, Color(0.55, 0.62, 0.95)],
]

var tod_applied := -1.0

func set_time_of_day(t: float) -> void:
	if sun_light == null:
		return
	t = clampf(t, 0.0, 1.0)
	time_of_day = t
	# 하늘을 다시 그리는 건 무거워서, 눈에 띌 만큼 바뀌었을 때만 바꿔요
	if tod_applied >= 0.0 and absf(t - tod_applied) < 0.012:
		return
	tod_applied = t
	var a: Array = TOD_KEYS[0]
	var b: Array = TOD_KEYS[TOD_KEYS.size() - 1]
	for i in TOD_KEYS.size() - 1:
		if t >= float(TOD_KEYS[i][0]) and t <= float(TOD_KEYS[i + 1][0]):
			a = TOD_KEYS[i]
			b = TOD_KEYS[i + 1]
			break
	var k := 0.0
	if float(b[0]) > float(a[0]):
		k = (t - float(a[0])) / (float(b[0]) - float(a[0]))
	sun_light.rotation_degrees.x = lerpf(a[1], b[1], k)
	sun_light.light_color = (a[2] as Color).lerp(b[2], k)
	sun_light.light_energy = lerpf(a[3], b[3], k)
	sky_mat_ref.sky_top_color = (a[4] as Color).lerp(b[4], k)
	sky_mat_ref.sky_horizon_color = (a[5] as Color).lerp(b[5], k)
	sky_mat_ref.ground_horizon_color = (a[5] as Color).lerp(b[5], k).darkened(0.1)
	sky_mat_ref.ground_bottom_color = Color(0.5, 0.62, 0.45).lerp(Color(0.05, 0.07, 0.12), smoothstep(0.6, 1.0, t))
	env_ref.fog_light_color = (a[6] as Color).lerp(b[6], k)
	env_ref.ambient_light_energy = lerpf(a[7], b[7], k)
	env_ref.ambient_light_color = (a[8] as Color).lerp(b[8], k)
	if star_node != null:
		var sa := smoothstep(0.78, 0.95, t)
		star_node.visible = sa > 0.01
		(star_node.material_override as StandardMaterial3D).albedo_color.a = sa

# 밤하늘의 별 (멀리 둥근 천장에 작은 점들)
func make_stars() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r := RandomNumberGenerator.new()
	r.seed = 99
	for i in 420:
		var y := r.randf_range(0.12, 1.0)
		var ang := r.randf() * TAU
		var dir := Vector3(cos(ang) * sqrt(1.0 - y * y), y, sin(ang) * sqrt(1.0 - y * y))
		var c := dir * 260.0
		var s := r.randf_range(0.35, 1.0) * (1.6 if r.randf() < 0.08 else 1.0)
		var u := dir.cross(Vector3.UP).normalized() * s
		if u.length() < 0.01:
			u = Vector3(s, 0, 0)
		var v := dir.cross(u).normalized() * s
		var col := Color(1.0, 0.96, 0.85).lerp(Color(0.8, 0.88, 1.0), r.randf())
		for p in [c - u, c + v, c + u, c - u, c + u, c - v]:
			st.set_color(col)
			st.add_vertex(p)
	star_node = MeshInstance3D.new()
	star_node.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.disable_fog = true
	m.albedo_color = Color(1, 1, 1, 0)
	star_node.material_override = m
	star_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	star_node.visible = false
	add_child(star_node)

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
# 흙길 그림이 덮는 땅 영역 (장마다 바꿀 수 있어요: x, z, 한 변 길이)
var splat_rect := Rect2(-50, -50, 100, 100)
var splat_r: PackedFloat32Array
var splat_g: PackedFloat32Array

func splat_stamp(ch: PackedFloat32Array, cx: float, cz: float, r_in: float, r_out: float, strength: float = 1.0) -> void:
	var k := SPLAT_N / splat_rect.size.x
	var px := (cx - splat_rect.position.x) * k
	var pz := (cz - splat_rect.position.y) * k
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
	paint_ground_splat()
	var bytes := PackedByteArray()
	bytes.resize(SPLAT_N * SPLAT_N * 4)
	for z in SPLAT_N:
		var wz := splat_rect.position.y + z * splat_rect.size.x / SPLAT_N
		for x in SPLAT_N:
			var forest := splat_forest(splat_rect.position.x + x * splat_rect.size.x / SPLAT_N, wz)
			var i := z * SPLAT_N + x
			bytes[i * 4] = int(splat_r[i] * 255.0)
			bytes[i * 4 + 1] = int(splat_g[i] * 255.0)
			bytes[i * 4 + 2] = int(forest * 255.0)
			bytes[i * 4 + 3] = 255
	var img := Image.create_from_data(SPLAT_N, SPLAT_N, false, Image.FORMAT_RGBA8, bytes)
	ground_mat.set_shader_parameter("splat_tex", ImageTexture.create_from_image(img))
	ground_mat.set_shader_parameter("world_rect", Vector4(splat_rect.position.x, splat_rect.position.y, splat_rect.size.x, splat_rect.size.x))

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
# Meshy 가 넣어 준 뼈대(믹사모 이름)를 우리 이름에 맞춰요. 우리 L 은 모델의 -x 쪽 = 믹사모의 Right 예요
const MIXAMO_BONES := {
	"hips": "mixamorig_Hips", "spine": "mixamorig_Spine1", "head": "mixamorig_Head",
	"armL": "mixamorig_RightArm", "foreL": "mixamorig_RightForeArm", "handL": "mixamorig_RightHand",
	"armR": "mixamorig_LeftArm", "foreR": "mixamorig_LeftForeArm", "handR": "mixamorig_LeftHand",
	"thighL": "mixamorig_RightUpLeg", "shinL": "mixamorig_RightLeg", "footL": "mixamorig_RightFoot",
	"thighR": "mixamorig_LeftUpLeg", "shinR": "mixamorig_LeftLeg", "footR": "mixamorig_LeftFoot",
}

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
	var mixamo := skel.find_bone("mixamorig_Hips") >= 0
	for bn in RIG_BONES:
		var i := skel.find_bone(MIXAMO_BONES[bn] if mixamo else bn)
		if i >= 0:
			bones[bn] = [i, skel.get_bone_rest(i).basis.get_rotation_quaternion(), skel.get_bone_global_rest(i).basis.orthonormalized().inverse(), skel.get_bone_global_rest(i).basis.y.normalized()]
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	body.set_meta("skel", skel)
	body.set_meta("bones", bones)
	# Meshy 동작(걷기·뛰기)이 들어 있으면 틀 준비를 해요
	var players := inst.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		var ap: AnimationPlayer = players[0]
		for an in ap.get_animation_list():
			var a := ap.get_animation(an)
			a.loop_mode = Animation.LOOP_LINEAR
		ap.playback_default_blend_time = 0.25
		body.set_meta("anim", ap)
		if file == "hero":
			find_step_times(body)
	return body

# 가만히 서 있는 자세(코드로 만든 자세)를 동작 클립으로 만들어, 걷기와 부드럽게 섞이게 해요
func make_idle_clip(body: Node3D) -> void:
	if not body.has_meta("anim"):
		return
	var ap: AnimationPlayer = body.get_meta("anim")
	var skel: Skeleton3D = body.get_meta("skel")
	skel.reset_bone_poses()
	body.set_meta("gait", [0.0, 0.0, 0.0])
	pose_rig(body, 0.0, 0.0)
	var root: Node = ap.get_node(ap.root_node)
	var spath := str(root.get_path_to(skel))
	var a := Animation.new()
	a.length = 3.0
	a.loop_mode = Animation.LOOP_LINEAR
	var bones: Dictionary = body.get_meta("bones")
	for bi in skel.get_bone_count():
		var bname := skel.get_bone_name(bi)
		if bname.contains("Hand") and not bname.ends_with("Hand"):
			continue
		var t := a.add_track(Animation.TYPE_ROTATION_3D)
		a.track_set_path(t, NodePath(spath + ":" + bname))
		var q := skel.get_bone_pose_rotation(bi)
		a.rotation_track_insert_key(t, 0.0, q)
		# 숨 쉬듯 가슴과 팔이 살짝 오르내려요
		var breathe := Quaternion.IDENTITY
		if bones.has("spine") and bi == (bones["spine"] as Array)[0]:
			breathe = Quaternion(Vector3.RIGHT, -0.03)
		a.rotation_track_insert_key(t, 1.5, q * breathe)
		a.rotation_track_insert_key(t, 3.0, q)
	var hip_i: int = (bones["hips"] as Array)[0]
	var pt := a.add_track(Animation.TYPE_POSITION_3D)
	a.track_set_path(pt, NodePath(spath + ":" + skel.get_bone_name(hip_i)))
	a.position_track_insert_key(pt, 0.0, skel.get_bone_rest(hip_i).origin)
	var lib: AnimationLibrary
	if ap.has_animation_library(""):
		lib = ap.get_animation_library("")
	else:
		lib = AnimationLibrary.new()
		ap.add_animation_library("", lib)
	lib.add_animation("Idle", a)
	skel.reset_bone_poses()
	ap.play("Idle")

# 걷기·뛰기·서 있기를 동작 클립으로 틀어요. 동작 클립이 없거나 특별한 자세일 땐 false
func drive_anim(body: Node3D, moving: float, run: float, speed_ratio: float) -> bool:
	if not body.has_meta("anim"):
		return false
	var ap: AnimationPlayer = body.get_meta("anim")
	var want := "Idle"
	if moving > 0.35:
		want = "Running" if run > 0.5 and ap.has_animation("Running") else "Walking"
	if body == player_body and swimming and ap.has_animation("Swimming"):
		if ap.current_animation != "Swimming" or not ap.is_playing():
			ap.play("Swimming")
		ap.speed_scale = lerpf(0.45, 1.15, clampf(moving, 0.0, 1.0))
		body.set_meta("anim_on", true)
		return true
	if not ap.has_animation(want):
		return false
	if ap.current_animation != want or not ap.is_playing():
		ap.play(want)
	ap.speed_scale = 1.0 if want == "Idle" else clampf(speed_ratio, 0.6, 1.8)
	body.set_meta("anim_on", true)
	return true

# 걷기·뛰기 동작에서 발이 땅에 닿는 순간(0~1)을 미리 찾아 둬요. 발자국 소리를 그때 울려요
func find_step_times(body: Node3D) -> void:
	var ap: AnimationPlayer = body.get_meta("anim")
	var skel: Skeleton3D = body.get_meta("skel")
	var bones: Dictionary = body.get_meta("bones")
	if not bones.has("footL") or not bones.has("footR"):
		return
	var out := {}
	for clip in ["Walking", "Running"]:
		if not ap.has_animation(clip):
			continue
		var length := ap.get_animation(clip).length
		ap.play(clip)
		var n := 48
		var ys := {"footL": [], "footR": []}
		for i in n:
			ap.seek(length * i / n, true)
			for f in ys:
				var bi: int = (bones[f] as Array)[0]
				(ys[f] as Array).append(skel.get_bone_global_pose(bi).origin.y)
		var times := []
		for f in ys:
			var arr: Array = ys[f]
			# 발이 가장 낮아지기 시작하는 때 = 땅을 딛는 순간
			var lo: float = arr.min()
			var hi: float = arr.max()
			var th := lo + (hi - lo) * 0.12
			for i in n:
				var prev: float = arr[(i - 1 + n) % n]
				if arr[i] <= th and prev > th:
					times.append(float(i) / n)
		out[clip] = times
		ap.stop()
	skel.reset_bone_poses()
	body.set_meta("step_times", out)
	body.set_meta("step_last", 0.0)

func anim_footsteps(on_ground: bool) -> void:
	if not player_body.has_meta("step_times"):
		return
	var ap: AnimationPlayer = player_body.get_meta("anim")
	var st: Dictionary = player_body.get_meta("step_times")
	var clip := String(ap.current_animation)
	if not st.has(clip) or not on_ground:
		player_body.set_meta("step_last", -1.0)
		return
	var length := ap.current_animation_length
	var now := fposmod(ap.current_animation_position / maxf(length, 0.001), 1.0)
	var last: float = player_body.get_meta("step_last", -1.0)
	player_body.set_meta("step_last", now)
	if last < 0.0:
		return
	for t in st[clip]:
		var hit: bool = (last < now and t > last and t <= now) or (last > now and (t > last or t <= now))
		if hit:
			sfx("step", rng.randf_range(0.85, 1.15) * (1.08 if clip == "Running" else 1.0))

# 동작 클립을 멈추고 코드로 자세를 잡을 준비 (점프·미니게임)
func stop_anim(body: Node3D) -> void:
	if not body.has_meta("anim") or not body.get_meta("anim_on", false):
		return
	var ap: AnimationPlayer = body.get_meta("anim")
	ap.stop()
	(body.get_meta("skel") as Skeleton3D).reset_bone_poses()
	body.set_meta("anim_on", false)

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
		var arm_down: float = body.get_meta("arm_down", 0.44)
		var arm_adj: float = body.get_meta("arm_adj", 0.0)
		var down := -sx * (lerpf(lerpf(arm_down, arm_down + 0.08, run * amt), 0.25, a) - arm_adj)
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

# 뼈대를 넣은 Meshy 인물 모델: 모델 크기, 팔을 얼마나 내리는지(A자 자세가 모델마다 달라요)
const RIGGED_PEOPLE := {
	"hero": {"scale": 1.27, "offset": -1.0, "arm_down": 0.44, "arm_adj": 0.31, "idle_clip": true},
	"heungbu": {"scale": 1.25, "arm_down": 0.3},
	"nolbu": {"scale": 1.0, "arm_down": 0.22},
	"wife": {"scale": 1.2, "arm_down": 0.04},
	"dokkaebi": {"scale": 1.0, "arm_down": 0.08},
	"sansin": {"scale": 1.1, "arm_down": 0.0},
	"mom": {"scale": 1.25, "arm_down": 0.18},
	"oppa": {"scale": 1.25, "arm_down": 0.2},
	"nui": {"scale": 1.25, "arm_down": 0.2},
	"tiger": {"scale": 1.45, "arm_down": 0.05},
	"tigermom": {"scale": 1.45, "arm_down": 0.08},
	"jara": {"scale": 1.2, "arm_down": 0.15},
	"rabbit": {"scale": 1.1, "arm_down": 0.16},
	"yongwang": {"scale": 1.5, "arm_down": 0.0},
	"octopus": {"scale": 1.45, "arm_down": 0.04},
	"crab": {"scale": 1.15, "arm_down": 0.04},
	"flatfish": {"scale": 1.35, "arm_down": 0.0},
	"haenyeo": {"scale": 1.2, "arm_down": 0.25},
}

# 마을 사람: 기본 체형 5개(Meshy)를 옷 색, 모자, 수염만 바꿔 여러 사람으로 써요
# hat_y: 머리카락 꼭대기 높이, chin/front: 턱 높이와 얼굴 앞쪽 (모델 키 2, 발 -1 기준)
const VIL_BASE := {
	"vil_man": {"arm_down": 0.2, "hat_y": 0.83, "head_r": 0.31, "chin": 0.3, "front": 0.26},
	"vil_woman": {"arm_down": 0.2, "hat_y": 0.98, "head_r": 0.37, "chin": 0.28, "front": 0.3},
	"vil_grandpa": {"arm_down": 0.16, "hat_y": 0.86, "head_r": 0.35, "chin": 0.22, "front": 0.3},
	"vil_grandma": {"arm_down": 0.2, "hat_y": 0.98, "head_r": 0.38, "chin": 0.3, "front": 0.33},
	"vil_child": {"arm_down": 0.2, "hat_y": 0.98, "head_r": 0.4, "chin": 0.28, "front": 0.31},
}
const VILLAGERS := {
	"suni": {"base": "vil_woman", "scale": 1.2, "bottom": Color(0.6, 0.7, 0.9)},
	"ong": {"base": "vil_grandma", "scale": 1.15, "bottom": Color(0.66, 0.56, 0.62)},
	"kim": {"base": "vil_man", "scale": 1.2, "bottom": Color(0.72, 0.64, 0.48), "hat": "straw"},
	"merchant": {"base": "vil_man", "scale": 1.2, "top": Color(0.45, 0.68, 0.5), "hat": "pae"},
	"woodman": {"base": "vil_man", "scale": 1.32, "top": Color(0.78, 0.62, 0.45), "bottom": Color(0.6, 0.5, 0.4), "hat": "band"},
	"park": {"base": "vil_grandpa", "scale": 1.2, "top": Color(0.6, 0.72, 0.9), "hat": "gat", "beard": 0.8},
	"fisher": {"base": "vil_grandpa", "scale": 1.2, "top": Color(0.62, 0.74, 0.62), "hat": "sat", "beard": 1.0},
	"choi": {"base": "vil_grandpa", "scale": 1.22, "top": Color(0.42, 0.7, 0.64), "hat": "tang", "beard": 1.4},
	"kid1": {"base": "vil_child", "scale": 1.25, "bottom": Color(0.8, 0.7, 0.55)},
	"kid2": {"base": "vil_child", "scale": 1.25, "top": Color(1.0, 0.72, 0.8), "bottom": Color(0.98, 0.88, 0.6)},
	"dori": {"base": "vil_child", "scale": 1.25, "top": Color(0.62, 0.78, 1.0)},
	"kid": {"base": "vil_child", "scale": 1.25, "top": Color(1.0, 0.9, 0.6)},
	# 2장: 잔칫집 사람들
	"host": {"base": "vil_grandpa", "scale": 1.22, "top": Color(0.82, 0.72, 0.95), "hat": "gat", "beard": 1.0},
	"cook": {"base": "vil_grandma", "scale": 1.15, "bottom": Color(0.72, 0.52, 0.42)},
	"guest1": {"base": "vil_man", "scale": 1.2, "top": Color(0.66, 0.78, 0.95), "hat": "gat"},
	"guest2": {"base": "vil_woman", "scale": 1.2, "top": Color(1.0, 0.82, 0.45), "bottom": Color(0.5, 0.6, 0.88)},
	"guest3": {"base": "vil_grandpa", "scale": 1.2, "top": Color(0.85, 0.85, 0.8), "hat": "tang", "beard": 1.2},
}
const CLOTH_SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform vec3 top_c : source_color = vec3(1.0);
uniform vec3 bot_c : source_color = vec3(1.0);
void fragment() {
	vec3 c = texture(tex, UV).rgb;
	vec3 g = sqrt(c);
	float skin = smoothstep(0.09, 0.15, g.r - g.g);
	float l = min(dot(c, vec3(0.3, 0.5, 0.2)) / 0.8, 1.0);
	vec3 o = mix(c, top_c * l, COLOR.r * (1.0 - skin));
	ALBEDO = mix(o, bot_c * l, COLOR.g * (1.0 - skin));
	ROUGHNESS = 0.78;
}
"""
var cloth_shader: Shader

func make_villager(parent: Node3D, kind: String) -> Node3D:
	var v: Dictionary = VILLAGERS[kind]
	var base: String = v["base"]
	var bd: Dictionary = VIL_BASE[base]
	var rb := make_rigged_model(parent, base)
	if rb == null:
		return null
	var sc: float = v["scale"]
	(rb.get_child(0) as Node3D).scale = Vector3.ONE * sc
	(rb.get_child(0) as Node3D).position.y = sc - 1.0
	rb.set_meta("arm_down", bd["arm_down"])
	rb.set_meta("arm_adj", 0.0)
	rb.set_meta("gait", [0.0, 0.0, 0.0])
	# 옷 색 (흰 옷 자리에만 물을 들여요. 얼굴·손은 그대로)
	if v.has("top") or v.has("bottom"):
		if cloth_shader == null:
			cloth_shader = Shader.new()
			cloth_shader.code = CLOTH_SHADER
		for mi in rb.find_children("*", "MeshInstance3D", true, false):
			var mesh := (mi as MeshInstance3D).mesh
			var old := mesh.surface_get_material(0) as BaseMaterial3D
			if old == null:
				continue
			var sm := ShaderMaterial.new()
			sm.shader = cloth_shader
			sm.set_shader_parameter("tex", old.albedo_texture)
			sm.set_shader_parameter("top_c", v.get("top", Color.WHITE))
			sm.set_shader_parameter("bot_c", v.get("bottom", Color.WHITE))
			(mi as MeshInstance3D).set_surface_override_material(0, sm)
	# 모자와 수염은 머리뼈에 붙여요 (고개를 돌리면 같이 돌아요)
	if v.has("hat") or v.has("beard"):
		var skel: Skeleton3D = rb.get_meta("skel")
		var hi := skel.find_bone("head")
		if hi >= 0:
			var att := BoneAttachment3D.new()
			att.bone_name = "head"
			skel.add_child(att)
			var holder := Node3D.new()
			att.add_child(holder)
			holder.transform = skel.get_bone_global_rest(hi).affine_inverse()
			if v.has("hat"):
				add_villager_hat(holder, v["hat"], bd)
			if v.has("beard"):
				var bl: float = v["beard"]
				var bm := MeshInstance3D.new()
				var sp := SphereMesh.new()
				sp.radius = 0.08
				sp.height = 0.16
				bm.mesh = sp
				bm.material_override = make_color(Color(0.95, 0.95, 0.93))
				bm.scale = Vector3(0.8, 1.5 * bl, 0.55)
				bm.position = Vector3(0, float(bd["chin"]) - 0.04 - 0.07 * bl, float(bd["front"]) - 0.03)
				holder.add_child(bm)
	return rb

func add_villager_hat(holder: Node3D, hat: String, bd: Dictionary) -> void:
	var y: float = bd["hat_y"]
	var r: float = bd["head_r"]
	var parts := []   # [메시, 위치, 색]
	match hat:
		"gat":
			parts.append([cyl(r + 0.26, r + 0.26, 0.02), y - 0.04, Color(0.08, 0.07, 0.07)])
			parts.append([cyl(0.15, 0.18, 0.3), y + 0.1, Color(0.1, 0.08, 0.08)])
		"tang":
			parts.append([cyl(0.17, 0.22, 0.2), y + 0.03, Color(0.12, 0.1, 0.1)])
		"straw":
			parts.append([cyl(r + 0.3, r + 0.3, 0.03), y - 0.08, Color(0.9, 0.78, 0.48)])
			parts.append([cyl(r - 0.02, r + 0.02, 0.2), y + 0.0, Color(0.88, 0.75, 0.45)])
			parts.append([cyl(r + 0.025, r + 0.025, 0.05), y - 0.05, Color(0.55, 0.25, 0.2)])
		"pae":
			parts.append([cyl(r + 0.17, r + 0.17, 0.03), y - 0.06, Color(0.82, 0.7, 0.46)])
			parts.append([cyl(0.12, r, 0.24), y + 0.04, Color(0.8, 0.67, 0.42)])
		"sat":
			parts.append([cyl(0.02, r + 0.32, 0.34), y + 0.02, Color(0.78, 0.66, 0.42)])
		"band":
			var t := TorusMesh.new()
			t.inner_radius = r - 0.03
			t.outer_radius = r + 0.03
			parts.append([t, y - 0.12, Color(0.96, 0.95, 0.9)])
	for p in parts:
		var mi := MeshInstance3D.new()
		mi.mesh = p[0]
		mi.position = Vector3(0, p[1], 0)
		mi.material_override = make_color(p[2])
		holder.add_child(mi)

func cyl(top: float, bottom: float, h: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = h
	m.radial_segments = 20
	m.rings = 1
	return m

func make_person_model(parent: Node3D, kind: String, c: Color) -> Node3D:
	if VILLAGERS.has(kind):
		var vb := make_villager(parent, kind)
		if vb != null:
			return vb
	if RIGGED_PEOPLE.has(kind):
		var rp: Dictionary = RIGGED_PEOPLE[kind]
		var rb := make_rigged_model(parent, kind)
		if rb != null:
			(rb.get_child(0) as Node3D).scale = Vector3.ONE * float(rp["scale"])
			(rb.get_child(0) as Node3D).position.y = float(rp.get("offset", float(rp["scale"]) - 1.0))
			rb.set_meta("arm_down", rp["arm_down"])
			rb.set_meta("arm_adj", rp.get("arm_adj", 0.0))
			# 서 있는 사람: 걸음 없이 숨만 쉬어요
			rb.set_meta("gait", [0.0, 0.0, 0.0])
			if rp.get("idle_clip", false):
				make_idle_clip(rb)
			return rb
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

# ---------- 세상 만들기 ----------

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
	cam_hint_seen = cf.get_value("ui", "cam_hint_seen", false)

func save_controls() -> void:
	var cf := ConfigFile.new()
	cf.load("user://save.cfg")
	cf.set_value("ui", "left_handed", left_handed)
	cf.set_value("ui", "walk_hint_seen", walk_hint_seen)
	cf.set_value("ui", "cam_hint_seen", cam_hint_seen)
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
	place(page, 0.06, 0.17, 0.94, 0.83)
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
	place(again, 0.15, 0.645, 0.85, 0.725)
	var restart := Button.new()
	restart.text = "처음부터 다시 하기..."
	skin_button(restart, make_round(Color(0.93, 0.78, 0.72), font_size * 0.35), Color(0.55, 0.18, 0.12), 0.75)
	page.add_child(restart)
	place(restart, 0.22, 0.74, 0.78, 0.81)
	restart.pressed.connect(func():
		close_settings()
		ask("", "어디부터 다시 할까요?\n- 이 장만: 지금 장 이야기만 처음으로 (엽전·물건·다른 장은 그대로)\n- 모든 장: 1장부터 새로 (도감, 엔딩 기록, 설정은 남아요)", ["이 장만 처음부터", "모든 장 처음부터", "그만둘래요"], func(i: int):
			if i == 0:
				reset_chapter()
			elif i == 1:
				reset_progress()))
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
	place(close, 0.3, 0.84, 0.7, 0.95)
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

# ---------- 나무하기: 타이밍 맞춰 도끼로 쩍! ----------

# ---------- 우물: 두레박을 당겨 물 길어 올리기 ----------

const WELL_TOP := 1.12
const WELL_WATER := 0.72

# ---------- 낚시 (3D): 연못 위 찌, 물고기 그림자, 튀어 오르는 물고기 ----------

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

func cam_depth_of(target: Vector3, cam_pos: Vector3) -> float:
	return target.distance_to(cam_pos)

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
	if is_tap_scene(scene):
		tap_scene_update()
		return
	if is_catch_scene(scene):
		catch_scene_update()
		return
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

# 눌러서 쫓는 미니게임(구렁이, 말뚝, 참새 ...): 화면의 버튼마다 3D 목표를 하나씩 붙여요
func is_tap_scene(scene: String) -> bool:
	return scene in ["snake", "kim", "sparrow"]

func tap_scene_update() -> void:
	var scene: String = w["scene"]
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

# 받는 미니게임(밥풀 ...): 떨어지는 것들을 3D로 보여 주고 주인공이 손가락을 따라가요
func is_catch_scene(scene: String) -> bool:
	return scene == "rice"

# 떨어지는 물건 모양 (장마다 바꿀 수 있어요)
func catch_item_node(bad: bool) -> Node3D:
	if bad:
		return blob_node([[Vector3.ZERO, Vector3(0.22, 0.34, 0.06), Color(0.85, 0.66, 0.4)], [Vector3(0, -0.3, 0), Vector3(0.07, 0.36, 0.05), Color(0.7, 0.5, 0.3)]])
	return blob_node([[Vector3.ZERO, Vector3(0.2, 0.17, 0.2), Color(1, 1, 0.97)], [Vector3(0.06, 0.06, 0.03), Vector3(0.1, 0.08, 0.1), Color(1, 1, 1)]])

func catch_scene_update() -> void:
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
			items[key] = catch_item_node(it[1])
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
		var gy: float = w.get("ground_y", 0.0)
		var gpt := ro + rd * ((gy - ro.y) / rd.y)
		var lim: Vector3 = w["center"]
		gpt.x = clampf(gpt.x, lim.x - 2.4, lim.x + 2.4)
		player.position = player.position.lerp(Vector3(gpt.x, player.position.y, lim.z), 0.35)
	bowl.global_position = player.position + Vector3(0, 2.2, 0.15)
	mg_cfg["basket_px"] = cam.unproject_position(bowl.global_position).y
	mg_cfg["spawn_px"] = maxf(h * 0.12, float(mg_cfg["basket_px"]) - h * 0.38)

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

func add_ridge_ring(r0: float, depth: float, hmin: float, hmax: float, low: Color, high: Color, seed_v: int, center: Vector3 = Vector3.ZERO, arc: Vector2 = Vector2(0.0, TAU)) -> void:
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
		var ang := lerpf(arc.x, arc.y, float(i) / n)
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
			col.append(center + Vector3(cos(ang) * rr, y, sin(ang) * rr))
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
	if player == null:
		return
	update_autosave(delta)
	update_cam_hint(delta)
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

func set_quest(q: int) -> void:
	quest = q
	update_quest_text()
	save_progress()

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
		on_gate()
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

# ---------- 놀부네 ----------

# ---------- 흥부네 ----------

# ---------- 1장 엔딩 ----------

# ---------- 마을 사람 돕기 ----------

# ---------- 품팔이와 장터 ----------

# ---------- 숨은 이야기: 금도끼 은도끼 ----------

const AXE_GOAL := 3

# ---------- 감나무: 장대로 감 따기 (꼭대기 까치밥은 남겨요) ----------

const GAM_GOAL := 8
var persimmon_ctr := Vector3(3, 3.7, 2.5)
var persimmon_rad := 2.0
var persimmon_fruit_mi: Node3D = null

# ---------- 주변 세상에서 하는 미니게임 (공통) ----------

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
	elif kind == "mallet":
		# 떡메: 긴 자루 끝에 굵은 나무 방망이
		add_mcyl(root, wood_mat, 0.035, 0.04, 1.05, Vector3(0, 0.52, 0))
		var head := add_mcyl(root, make_color(Color(0.62, 0.45, 0.28)), 0.15, 0.15, 0.5, Vector3(0, 1.08, 0))
		head.rotation.x = PI / 2.0
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
	var bones: Dictionary = player_body.get_meta("bones")
	if not bones.has(bn):
		return player.position + Vector3(0, 1.0, 0)
	var i: int = (bones[bn] as Array)[0]
	return skel.global_transform * skel.get_bone_global_pose(i).origin

# 도구는 손에 붙이고, 정해 준 방향(dir)으로 뻗게 해요
func place_tool(dir: Vector3) -> void:
	if tool_node == null:
		return
	var hand := bone_world("handR").lerp(bone_world("handL"), 0.5 if tool_kind in ["axe", "mallet"] else 0.0)
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
		var adj: float = player_body.get_meta("arm_adj", 0.0)
		turn_bone(skel, bones, "arm" + side, [[Vector3.RIGHT, arm.x], [Vector3.BACK, -sx * (arm.y - adj)], [twist, sx * 0.9]])
		turn_bone(skel, bones, "fore" + side, [[Vector3.RIGHT, arm.z]])
		turn_bone(skel, bones, "thigh" + side, [[Vector3.RIGHT, -0.14 - crouch * 0.5]])
		turn_bone(skel, bones, "shin" + side, [[Vector3.RIGHT, 0.26 + crouch]])
		turn_bone(skel, bones, "foot" + side, [[Vector3.RIGHT, -0.12 - crouch * 0.45]])
	turn_bone(skel, bones, "hips", [])
	turn_bone(skel, bones, "spine", [[Vector3.RIGHT, lean]])
	turn_bone(skel, bones, "head", [[Vector3.RIGHT, -lean * 0.4]])
	player_body.position.y = 1.0 - crouch * 0.12

# ---------- 손맛 미니게임: 리듬 · 스와이프 · 번갈아 오르기 · 연타 ----------
# 화면 위 그림(cg_draw)과 판정은 여기서, 3D 세상 쪽 연출은 장마다 cg_event()로 해요.
const CUSTOM_GAMES := ["rhythm", "swipe", "alternate", "mash", "stack", "aim", "simon", "dance", "dig"]
var cg := {}
var cg_draw: Control
var mg_lives_start := 3

# 장마다 바꿔 쓰는 연출 (kind: perfect, good, miss, bad, block, hit, feint, climb, slip, pull, fall, round, ...)
func cg_event(_kind: String, _info: Dictionary = {}) -> void:
	pass

func custom_begin() -> void:
	cg = {"t": -1.4, "combo": 0, "best": 0, "press": null, "msg": "", "msg_t": 0.0}
	g3 = {}
	mg_lives = int(mg_cfg.get("lives", 5 if mg_type == "rhythm" else 3))
	cg_draw = Control.new()
	cg_draw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mg_stage.add_child(cg_draw)
	place(cg_draw, 0, 0, 1, 1)
	cg_draw.draw.connect(custom_draw)
	match mg_type:
		"rhythm":
			cg["notes"] = []
			cg["next"] = 0.4
			cg["beat"] = 60.0 / float(mg_cfg.get("bpm", 96))
			cg["made"] = 0
		"swipe":
			cg["atk"] = {}
			cg["next"] = 1.0
		"alternate":
			cg["side"] = 0 if rng.randf() < 0.5 else 1
			cg["step_t"] = 0.0
			cg["shake"] = ""
			cg["shake_t"] = 0.0
			cg["shake_in"] = float(mg_cfg.get("shake_every", 5.0))
			cg["held"] = 0.0
		"mash":
			cg["tilt"] = 0.0
			cg["drift"] = 0.0
			cg["gauge"] = 0.0
			cg["round_t"] = 0.0
			cg["pulse"] = 0.0
		"stack":
			var bw := float(mg_cfg.get("base_w", 0.5))
			cg["layers"] = [[0.5, bw]]
			cg["cur"] = [0.1 + bw / 2.0, bw, 1.0]
			cg["falls"] = []
			cg["scroll"] = 0.0
		"aim":
			cg["climb"] = 0.0
			cg["shot"] = {}
			cg["drag"] = null
			cg["hit_flash"] = 0.0
		"simon":
			cg["seq"] = []
			for k in int(mg_cfg.get("start_len", 3)):
				(cg["seq"] as Array).append(rng.randi() % 5)
			cg["phase"] = "wait"
			cg["show_i"] = 0
			cg["show_t"] = -0.4
			cg["input_i"] = 0
			cg["lit"] = -1
			cg["lit_t"] = 0.0
		"dig":
			cg["tgt"] = {}
			cg["gap"] = 0.3
			cg["last"] = -1
			cg["razor_press"] = null
		"dance":
			cg["seq"] = []
			for k in int(mg_cfg.get("start_len", 3)):
				(cg["seq"] as Array).append(SW_DIRS4[rng.randi() % 4])
			cg["phase"] = "wait"
			cg["show_i"] = 0
			cg["show_t"] = -0.4
			cg["input_i"] = 0
			cg["flash_dir"] = ""
			cg["flash_t"] = 0.0
	cg_say("준비!", Color(1, 0.95, 0.7))

func cg_say(text: String, col: Color) -> void:
	cg["msg"] = text
	cg["msg_c"] = col
	cg["msg_t"] = 0.0

func cg_judge(text: String, col: Color, big: bool) -> void:
	var at := Vector2(mg_overlay.size.x * 0.5, mg_overlay.size.y * 0.42)
	float_text(text, at, col, 1.7 if big else 1.2)

func cg_combo_up() -> void:
	cg["combo"] = int(cg["combo"]) + 1
	cg["best"] = maxi(int(cg["best"]), int(cg["combo"]))
	if int(cg["combo"]) >= 3:
		float_text("%d 콤보!" % cg["combo"], Vector2(mg_overlay.size.x * 0.5, mg_overlay.size.y * 0.5), Color(1, 0.8, 0.35), 1.0)

func cg_combo_break() -> void:
	cg["combo"] = 0

func cg_lose(text: String) -> void:
	mg_lives -= 1
	mg_perfect = false
	cg_combo_break()
	sfx("bad")
	shake(14)
	cg_judge(text, Color(1, 0.5, 0.42), true)

func cg_progress() -> void:
	mg_progress = clampf(float(mg_count) / float(mg_cfg.get("goal", 10)), 0.0, 1.0)
	mg_info.text = "%s %d/%d | 남은 기회 %d" % [mg_cfg.get("unit", ""), mg_count, int(mg_cfg.get("goal", 10)), mg_lives]

func custom_input(event: InputEvent) -> void:
	var is_button: bool = event is InputEventScreenTouch or event is InputEventMouseButton
	var is_move: bool = event is InputEventScreenDrag or (event is InputEventMouseMotion and event.button_mask != 0)
	# 터치에서 따라 만들어진 가짜 마우스 신호는 버려요 (두 번 눌리지 않게)
	if (event is InputEventMouseButton or event is InputEventMouseMotion) and event.device == -1:
		return
	if is_button and event.pressed:
		mg_touch = true
		mg_pos = event.position
		cg["press"] = event.position
		cg["swiped"] = false
		custom_press(event.position)
	elif is_button:
		mg_touch = false
		custom_release(event.position)
		cg["press"] = null
	elif is_move:
		mg_pos = event.position
		custom_drag(event.position)

func update_custom(delta: float) -> void:
	cg["t"] = float(cg["t"]) + delta
	cg["msg_t"] = float(cg["msg_t"]) + delta
	if float(cg["t"]) >= 0.0 and cg.get("go_said", false) == false:
		cg["go_said"] = true
		cg_say("시작!", Color(1, 0.9, 0.4))
		sfx("drum")
	match mg_type:
		"rhythm":
			update_rhythm(delta)
		"swipe":
			update_swipe(delta)
		"alternate":
			update_alternate(delta)
		"mash":
			update_mash(delta)
		"stack":
			update_stack(delta)
		"aim":
			update_aim(delta)
		"simon":
			update_simon(delta)
		"dance":
			update_dance(delta)
		"dig":
			update_dig(delta)
	update_g3(delta)
	cg_progress()
	if is_instance_valid(cg_draw):
		cg_draw.queue_redraw()

func custom_press(pos: Vector2) -> void:
	if float(cg["t"]) < 0.0:
		return
	match mg_type:
		"rhythm":
			rhythm_press()
		"alternate":
			alternate_press(pos)
		"mash":
			mash_press(pos)
		"stack":
			stack_press()
		"aim":
			cg["drag"] = pos
		"simon":
			simon_press(pos)
		"dig":
			dig_press(pos)

func custom_release(pos: Vector2) -> void:
	if mg_type == "swipe":
		swipe_check(pos, true)
	elif mg_type == "aim":
		aim_release(pos)
	elif mg_type == "dance":
		dance_check(pos)
	elif mg_type == "dig":
		dig_release(pos)

func custom_drag(pos: Vector2) -> void:
	if mg_type == "swipe":
		swipe_check(pos, false)
	elif mg_type == "aim" and cg.get("drag") != null:
		cg["drag"] = pos
	elif mg_type == "dance":
		dance_check(pos)
	elif mg_type == "dig":
		dig_drag(pos)

# --- 리듬: 오른쪽에서 다가오는 박자가 동그라미에 겹칠 때 누르기. 빨간 손 박자는 누르면 안 돼요 ---
const R_PERFECT := 0.075
const R_GOOD := 0.17
const R_TRAVEL := 1.6

func update_rhythm(_delta: float) -> void:
	var t: float = cg["t"]
	var beat: float = cg["beat"]
	var goal := int(mg_cfg.get("goal", 14))
	# 박자 미리 만들기 (화면 오른쪽 끝에서 나타나요)
	while float(cg["next"]) < t + R_TRAVEL + 0.2 and int(cg["made"]) < goal * 3:
		var bad: bool = rng.randf() < float(mg_cfg.get("bad_ratio", 0.18)) and int(cg["made"]) > 2
		(cg["notes"] as Array).append({"t": float(cg["next"]), "bad": bad, "done": false})
		cg["made"] = int(cg["made"]) + 1
		var gaps := [1.0, 1.0, 1.0, 0.5, 0.5, 1.5, 2.0]
		cg["next"] = float(cg["next"]) + beat * float(gaps[rng.randi() % gaps.size()])
	for n in cg["notes"]:
		if n["done"]:
			continue
		if t - float(n["t"]) > R_GOOD:
			n["done"] = true
			if not n["bad"]:
				cg_lose("놓쳤어요!")
				cg_event("miss")
			else:
				cg_event("dodge")

func rhythm_press() -> void:
	var t: float = cg["t"]
	var best: Dictionary = {}
	var bd := 9.0
	for n in cg["notes"]:
		if n["done"]:
			continue
		var d := absf(t - float(n["t"]))
		if d < bd:
			bd = d
			best = n
	if best.is_empty() or bd > R_GOOD + 0.05:
		cg_combo_break()
		cg_judge("헛손질!", Color(0.85, 0.85, 0.9), false)
		cg_event("whiff")
		return
	best["done"] = true
	if best["bad"]:
		cg_lose(String(mg_cfg.get("bad_text", "앗, 손!")))
		hit_stop(0.08)
		cg_event("bad")
		return
	mg_count += 1
	cg_combo_up()
	if bd <= R_PERFECT:
		cg_judge("퍼펙트!", Color(1, 0.88, 0.3), true)
		sfx("good", 1.1)
		hit_stop(0.05)
		shake(10)
		cg_event("perfect")
	else:
		cg_judge("좋아!", Color(0.7, 0.95, 1.0), false)
		mg_perfect = false
		shake(5)
		cg_event("good")

# --- 스와이프: 화면 가장자리에서 공격이 오면, 그쪽으로 손가락을 휙! 가짜 공격엔 속지 마세요 ---
const SW_DIRS := ["left", "right", "up"]

func update_swipe(delta: float) -> void:
	if float(cg["t"]) < 0.0:
		return
	var a: Dictionary = cg["atk"]
	if a.is_empty():
		cg["next"] = float(cg["next"]) - delta
		if float(cg["next"]) <= 0.0:
			var fake: bool = rng.randf() < float(mg_cfg.get("feint_ratio", 0.22)) and mg_count > 1
			cg["atk"] = {"dir": SW_DIRS[rng.randi() % 3], "phase": "tele", "time": 0.0, "fake": fake}
			sfx("tick", 0.8)
		return
	a["time"] = float(a["time"]) + delta
	var tele := float(mg_cfg.get("tele", 0.85)) * maxf(0.6, 1.0 - mg_count * 0.025)
	match a["phase"]:
		"tele":
			if float(a["time"]) >= tele:
				a["time"] = 0.0
				if a["fake"]:
					a["phase"] = "back"
					cg_event("feint", a)
				else:
					a["phase"] = "strike"
					sfx("crack", 1.3)
		"strike":
			if float(a["time"]) >= float(mg_cfg.get("window", 0.5)):
				cg_lose(String(mg_cfg.get("hit_text", "앗, 당했다!")))
				cg_event("hit", a)
				cg["atk"] = {}
				cg["next"] = float(mg_cfg.get("gap", 0.9))
		"back":
			if float(a["time"]) >= 0.45:
				cg["atk"] = {}
				cg["next"] = 0.4

func swipe_check(pos: Vector2, released: bool) -> void:
	if cg.get("press") == null or cg.get("swiped", false) or float(cg["t"]) < 0.0:
		return
	var from: Vector2 = cg["press"]
	var d := pos - from
	if d.length() < short_side * 0.09:
		return
	cg["swiped"] = true
	var dir := "up"
	if absf(d.x) > absf(d.y):
		dir = "right" if d.x > 0.0 else "left"
	elif d.y > 0.0:
		dir = "down"
	var a: Dictionary = cg["atk"]
	if a.is_empty():
		cg_judge("휙~", Color(0.85, 0.85, 0.9), false)
		cg_combo_break()
		return
	if a["phase"] == "back" or (a["phase"] == "tele" and a["fake"]):
		cg_lose("속았지롱!")
		cg_event("fooled", a)
		cg["atk"] = {}
		cg["next"] = 0.7
		return
	if a["phase"] == "tele":
		cg_judge("너무 빨라요!", Color(1, 0.75, 0.5), false)
		cg_combo_break()
		return
	if dir != a["dir"]:
		cg_lose("반대쪽이에요!")
		cg_event("hit", a)
		cg["atk"] = {}
		cg["next"] = 0.8
		return
	mg_count += 1
	cg_combo_up()
	var quick: bool = float(a["time"]) < float(mg_cfg.get("window", 0.5)) * 0.45
	cg_judge("퍽! 막았다!" if quick else "막았다!", Color(1, 0.88, 0.3) if quick else Color(0.7, 0.95, 1.0), quick)
	sfx("crack", 1.0)
	hit_stop(0.07)
	shake(12 if quick else 7)
	cg_event("block", a)
	cg["atk"] = {}
	cg["next"] = float(mg_cfg.get("gap", 0.9)) * rng.randf_range(0.6, 1.2)

# --- 번갈아 오르기: 가지가 있는 쪽(왼쪽/오른쪽)을 눌러 한 칸씩. 흔들릴 땐 꾹 누르고 버티기 ---
func update_alternate(delta: float) -> void:
	if float(cg["t"]) < 0.0:
		return
	if cg["shake"] == "":
		cg["step_t"] = float(cg["step_t"]) + delta
		cg["shake_in"] = float(cg["shake_in"]) - delta
		if float(cg["step_t"]) > float(mg_cfg.get("step_time", 1.6)):
			cg["step_t"] = 0.0
			cg_lose("미끄러져요!")
			cg_event("slip")
		if float(cg["shake_in"]) <= 0.0:
			cg["shake"] = "warn"
			cg["shake_t"] = 0.0
			cg_say("흔들린다! 꾹 누르고 버텨요!", Color(1, 0.6, 0.45))
			sfx("crack", 0.7)
			cg_event("warn")
	else:
		cg["shake_t"] = float(cg["shake_t"]) + delta
		if cg["shake"] == "warn" and float(cg["shake_t"]) > 0.9:
			cg["shake"] = "shake"
			cg["shake_t"] = 0.0
			cg["held"] = 0.0
			shake(18)
			cg_event("shake")
		elif cg["shake"] == "shake":
			shake(4)
			if mg_touch:
				cg["held"] = float(cg["held"]) + delta
			if not mg_touch and float(cg["shake_t"]) > 0.15:
				cg_lose("손을 놓쳤어요!")
				cg_event("slip")
				cg["shake"] = ""
				cg["shake_in"] = float(mg_cfg.get("shake_every", 5.0)) * rng.randf_range(0.8, 1.2)
				cg["step_t"] = 0.0
			elif float(cg["shake_t"]) > 1.2:
				cg["shake"] = ""
				cg["shake_in"] = float(mg_cfg.get("shake_every", 5.0)) * rng.randf_range(0.8, 1.2)
				cg["step_t"] = 0.0
				cg_judge("버텼다!", Color(1, 0.88, 0.3), true)
				sfx("good")
				cg_event("held")

func alternate_press(pos: Vector2) -> void:
	if cg["shake"] != "":
		return
	var side := 0 if pos.x < mg_overlay.size.x * 0.5 else 1
	if side != int(cg["side"]):
		cg_combo_break()
		cg_judge("헛디딤!", Color(1, 0.75, 0.5), false)
		sfx("tick", 0.6)
		cg["step_t"] = float(cg["step_t"]) + 0.35
		return
	mg_count += 1
	var quick: bool = float(cg["step_t"]) < 0.45
	if quick:
		cg_combo_up()
	cg_judge("영차!" if not quick else "영차영차!", Color(1, 0.88, 0.3) if quick else Color(0.8, 0.95, 1.0), quick)
	sfx("tick", 1.0 + mg_count * 0.03)
	shake(4)
	cg["step_t"] = 0.0
	cg["side"] = (1 - side) if rng.randf() < 0.7 else side
	cg_event("climb")

# --- 연타: 빠르게 눌러 당기기. balance 이면 기운 반대쪽을 눌러 균형, rounds 이면 제한 시간 안에 게이지 채우기 ---
func update_mash(delta: float) -> void:
	if float(cg["t"]) < 0.0:
		return
	cg["pulse"] = maxf(0.0, float(cg["pulse"]) - delta * 4.0)
	if mg_cfg.get("balance", false):
		if rng.randf() < delta * 1.2:
			cg["drift"] = rng.randf_range(-1.0, 1.0) * float(mg_cfg.get("sway", 0.9))
		cg["tilt"] = float(cg["tilt"]) + (float(cg["drift"]) + float(cg["tilt"]) * 0.8) * delta
		if absf(float(cg["tilt"])) >= 1.0:
			cg["tilt"] = 0.0
			mg_count = maxi(0, mg_count - 2)
			cg_lose("휘청!")
			cg_event("fall")
	else:
		cg["round_t"] = float(cg["round_t"]) + delta
		cg["gauge"] = maxf(0.0, float(cg["gauge"]) - delta * float(mg_cfg.get("decay", 0.22)))
		if float(cg["round_t"]) > float(mg_cfg.get("round_time", 2.6)):
			cg_lose(String(mg_cfg.get("lose_text", "쏙 숨었어요!")))
			cg_event("escape")
			cg["round_t"] = 0.0
			cg["gauge"] = 0.0

func mash_press(pos: Vector2) -> void:
	cg["pulse"] = 1.0
	if mg_cfg.get("balance", false):
		var left: bool = pos.x < mg_overlay.size.x * 0.5
		cg["tilt"] = float(cg["tilt"]) + (-0.16 if left else 0.16)
		if absf(float(cg["tilt"])) < 0.6:
			cg["pull"] = int(cg.get("pull", 0)) + 1
			if int(cg["pull"]) % int(mg_cfg.get("per", 3)) == 0:
				mg_count += 1
				cg_combo_up()
				sfx("tick", 1.0 + mg_count * 0.02)
				cg_event("pull")
		else:
			cg_judge("균형부터!", Color(1, 0.75, 0.5), false)
	else:
		cg["gauge"] = float(cg["gauge"]) + 1.0 / float(mg_cfg.get("taps", 9))
		sfx("tap", 0.9 + float(cg["gauge"]) * 0.4)
		cg_event("tap")
		if float(cg["gauge"]) >= 1.0:
			mg_count += 1
			var quick: bool = float(cg["round_t"]) < float(mg_cfg.get("round_time", 2.6)) * 0.55
			if quick:
				cg_combo_up()
			cg_judge("쑥!" if not quick else "쑥! 빠르다!", Color(1, 0.88, 0.3), quick)
			sfx("good")
			hit_stop(0.05)
			shake(9)
			cg_event("round")
			cg["gauge"] = 0.0
			cg["round_t"] = 0.0

# --- 떡 쌓기: 좌우로 움직이는 떡판을 톡! 어긋난 만큼 잘려 나가요 ---
func update_stack(delta: float) -> void:
	if float(cg["t"]) < 0.0:
		return
	var cur: Array = cg["cur"]
	var sp := float(mg_cfg.get("speed", 0.45)) * (1.0 + mg_count * 0.06)
	cur[0] = float(cur[0]) + float(cur[2]) * sp * delta
	var half := float(cur[1]) / 2.0
	if float(cur[0]) + half > 0.97:
		cur[2] = -1.0
	if float(cur[0]) - half < 0.03:
		cur[2] = 1.0
	for f in cg["falls"]:
		f[3] = float(f[3]) + delta * 2.2
		f[2] = float(f[2]) + float(f[3]) * delta
	cg["scroll"] = lerpf(float(cg["scroll"]), maxf(0.0, (cg["layers"] as Array).size() - 6.0), minf(1.0, delta * 5.0))

func stack_press() -> void:
	var layers: Array = cg["layers"]
	var top: Array = layers[layers.size() - 1]
	var cur: Array = cg["cur"]
	var l0 := maxf(float(top[0]) - float(top[1]) / 2.0, float(cur[0]) - float(cur[1]) / 2.0)
	var r0 := minf(float(top[0]) + float(top[1]) / 2.0, float(cur[0]) + float(cur[1]) / 2.0)
	var over := r0 - l0
	var lvl := layers.size()
	if over <= 0.02:
		cg_lose("툭, 떨어졌어요!")
		(cg["falls"] as Array).append([float(cur[0]), float(cur[1]), 0.0, 0.0, lvl])
		cg["cur"] = [0.1 + float(top[1]) / 2.0, float(top[1]), 1.0]
		cg_event("fall")
		return
	var perfect := absf(float(cur[0]) - float(top[0])) < 0.018
	var nx := (l0 + r0) / 2.0
	var nw := over
	if perfect:
		nx = float(top[0])
		nw = minf(float(top[1]) + 0.01, float(mg_cfg.get("base_w", 0.5)))
		cg_combo_up()
		cg_judge("퍼펙트!", Color(1, 0.88, 0.3), true)
		sfx("good", 1.0 + lvl * 0.03)
		hit_stop(0.04)
		shake(7)
		cg_event("perfect")
	else:
		# 잘려 나간 조각
		var cut_l := float(cur[0]) - float(cur[1]) / 2.0
		var cut_r := float(cur[0]) + float(cur[1]) / 2.0
		if cut_l < l0:
			(cg["falls"] as Array).append([(cut_l + l0) / 2.0, l0 - cut_l, 0.0, 0.0, lvl])
		if cut_r > r0:
			(cg["falls"] as Array).append([(r0 + cut_r) / 2.0, cut_r - r0, 0.0, 0.0, lvl])
		cg_combo_break()
		cg_judge("탁!", Color(0.8, 0.95, 1.0), false)
		sfx("land", 1.2)
		shake(4)
		cg_event("drop")
	layers.append([nx, nw])
	mg_count += 1
	var from_left := mg_count % 2 == 0
	cg["cur"] = [(0.03 + nw / 2.0) if from_left else (0.97 - nw / 2.0), nw, 1.0 if from_left else -1.0]
	if nw < 0.05:
		cg_lose("너무 좁아졌어요!")
		cg["cur"] = [0.1 + 0.2, 0.4, 1.0]
		layers.append([0.5, 0.4])

# --- 조준해 던지기: 아래쪽에서 손가락을 뒤로 끌었다 놓으면 휙! 목표(장마다 정해요)를 맞혀요 ---
func aim_target() -> Vector2:
	var W := mg_overlay.size.x
	var H := mg_overlay.size.y
	return Vector2(W * (0.5 + sin(float(cg["t"]) * 1.1) * 0.3), H * lerpf(0.62, 0.22, float(cg["climb"])))

func aim_anchor() -> Vector2:
	return Vector2(mg_overlay.size.x * 0.5, mg_overlay.size.y * 0.8)

func update_aim(delta: float) -> void:
	if float(cg["t"]) < 0.0:
		return
	cg["hit_flash"] = maxf(0.0, float(cg["hit_flash"]) - delta * 3.0)
	cg["climb"] = float(cg["climb"]) + delta * float(mg_cfg.get("climb_speed", 0.045))
	if float(cg["climb"]) >= 1.0:
		mg_lives = 0
		cg_judge(String(mg_cfg.get("lose_text", "다 올라와 버렸어요!")), Color(1, 0.5, 0.42), true)
		cg_event("top")
		return
	var sh: Dictionary = cg["shot"]
	if sh.is_empty():
		return
	sh["v"] = (sh["v"] as Vector2) + Vector2(0, mg_overlay.size.y * 1.4) * delta
	sh["p"] = (sh["p"] as Vector2) + (sh["v"] as Vector2) * delta
	sh["spin"] = float(sh["spin"]) + delta * 12.0
	var tgt := aim_target()
	var rad := short_side * float(mg_cfg.get("target_r", 0.09))
	if (sh["p"] as Vector2).distance_to(tgt) < rad:
		mg_count += 1
		cg["climb"] = maxf(0.0, float(cg["climb"]) - float(mg_cfg.get("knock", 0.14)))
		cg["hit_flash"] = 1.0
		cg_combo_up()
		cg_judge(String(mg_cfg.get("hit_text", "딱! 맞았다!")), Color(1, 0.88, 0.3), true)
		sfx("crack", 1.1)
		hit_stop(0.07)
		shake(12)
		cg_event("hit")
		cg["shot"] = {}
	elif (sh["p"] as Vector2).y > mg_overlay.size.y + 40.0 or (sh["p"] as Vector2).y < -200.0 or (sh["p"] as Vector2).x < -60.0 or (sh["p"] as Vector2).x > mg_overlay.size.x + 60.0:
		cg_combo_break()
		cg_judge("빗나갔어요", Color(0.85, 0.85, 0.9), false)
		cg_event("miss")
		cg["shot"] = {}

func aim_release(pos: Vector2) -> void:
	if cg.get("drag") == null or float(cg["t"]) < 0.0:
		cg["drag"] = null
		return
	var pull := aim_anchor() - (cg["drag"] as Vector2)
	cg["drag"] = null
	if pull.length() < short_side * 0.05 or not (cg["shot"] as Dictionary).is_empty():
		return
	cg["shot"] = {"p": aim_anchor(), "v": pull * 5.2, "spin": 0.0}
	sfx("jump", 1.3)
	cg_event("throw")

# --- 소리 기억: 조개가 울리는 순서를 기억했다가 똑같이 눌러요 ---
func simon_pads() -> Array:
	if mg_world and w.has("simon_pts"):
		var o := []
		for p in w["simon_pts"]:
			o.append(cam.unproject_position(p))
		return o
	var W := mg_overlay.size.x
	var H := mg_overlay.size.y
	var out := []
	for k in 5:
		var a := PI + PI * (k + 0.5) / 5.0
		out.append(Vector2(W * 0.5, H * 0.86) + Vector2(cos(a), sin(a)) * W * 0.36)
	return out

const SIMON_COLS := [Color(1.0, 0.55, 0.55), Color(1.0, 0.8, 0.4), Color(0.6, 0.9, 0.6), Color(0.55, 0.75, 1.0), Color(0.8, 0.6, 1.0)]

func simon_light(k: int) -> void:
	cg["lit"] = k
	cg["lit_t"] = 0.0
	sfx("tick", 0.75 + k * 0.14)
	cg_event("pad", {"k": k})

func update_simon(delta: float) -> void:
	cg["lit_t"] = float(cg["lit_t"]) + delta
	if float(cg["t"]) < 0.0:
		return
	var seq: Array = cg["seq"]
	match cg["phase"]:
		"wait":
			cg["show_t"] = float(cg["show_t"]) + delta
			if float(cg["show_t"]) > 0.5:
				cg["phase"] = "show"
				cg["show_i"] = 0
				cg["show_t"] = 0.0
				cg_say("잘 들어 봐요...", Color(1, 0.95, 0.7))
		"show":
			cg["show_t"] = float(cg["show_t"]) + delta
			var step := maxf(0.38, 0.62 - mg_count * 0.04)
			if float(cg["show_t"]) >= step:
				cg["show_t"] = 0.0
				if int(cg["show_i"]) < seq.size():
					simon_light(int(seq[int(cg["show_i"])]))
					cg["show_i"] = int(cg["show_i"]) + 1
				else:
					cg["phase"] = "input"
					cg["input_i"] = 0
					cg_say("이제 따라 눌러요!", Color(1, 0.9, 0.4))

func simon_press(pos: Vector2) -> void:
	if cg["phase"] != "input":
		return
	var pads := simon_pads()
	var best := -1
	for k in 5:
		if pos.distance_to(pads[k]) < short_side * 0.11:
			best = k
	if best < 0:
		return
	simon_light(best)
	var seq: Array = cg["seq"]
	if best != int(seq[int(cg["input_i"])]):
		cg_lose("앗, 틀렸어요!")
		cg_event("wrong")
		cg["phase"] = "wait"
		cg["show_t"] = -0.3
		return
	cg["input_i"] = int(cg["input_i"]) + 1
	if int(cg["input_i"]) >= seq.size():
		mg_count += 1
		cg_combo_up()
		cg_judge("딩동댕!", Color(1, 0.88, 0.3), true)
		sfx("good")
		shake(6)
		cg_event("round")
		seq.append(rng.randi() % 5)
		cg["phase"] = "wait"
		cg["show_t"] = -0.4

# --- 춤 따라 하기: 보여 준 화살표 순서대로 휙휙! ---
const SW_DIRS4 := ["left", "right", "up", "down"]
const ARROW_VEC := {"left": Vector2(-1, 0), "right": Vector2(1, 0), "up": Vector2(0, -1), "down": Vector2(0, 1)}

func update_dance(delta: float) -> void:
	cg["flash_t"] = float(cg["flash_t"]) + delta
	if float(cg["t"]) < 0.0:
		return
	var seq: Array = cg["seq"]
	match cg["phase"]:
		"wait":
			cg["show_t"] = float(cg["show_t"]) + delta
			if float(cg["show_t"]) > 0.5:
				cg["phase"] = "show"
				cg["show_i"] = 0
				cg["show_t"] = 0.0
				cg_say("잘 봐요!", Color(1, 0.95, 0.7))
		"show":
			cg["show_t"] = float(cg["show_t"]) + delta
			var step := maxf(0.42, 0.7 - mg_count * 0.05)
			if float(cg["show_t"]) >= step:
				cg["show_t"] = 0.0
				if int(cg["show_i"]) < seq.size():
					cg["flash_dir"] = seq[int(cg["show_i"])]
					cg["flash_t"] = 0.0
					sfx("drum", 1.1)
					cg_event("show", {"dir": seq[int(cg["show_i"])]})
					cg["show_i"] = int(cg["show_i"]) + 1
				else:
					cg["phase"] = "input"
					cg["input_i"] = 0
					cg["flash_dir"] = ""
					cg_say("이제 따라 휙휙!", Color(1, 0.9, 0.4))

func dance_check(pos: Vector2) -> void:
	if cg["phase"] != "input" or cg.get("press") == null or cg.get("swiped", false):
		return
	var d := pos - (cg["press"] as Vector2)
	if d.length() < short_side * 0.08:
		return
	cg["swiped"] = true
	var dir := ""
	if absf(d.x) > absf(d.y):
		dir = "right" if d.x > 0.0 else "left"
	else:
		dir = "down" if d.y > 0.0 else "up"
	cg["flash_dir"] = dir
	cg["flash_t"] = 0.0
	var seq: Array = cg["seq"]
	if dir != String(seq[int(cg["input_i"])]):
		cg_lose("스텝이 꼬였어요!")
		cg_event("wrong")
		cg["phase"] = "wait"
		cg["show_t"] = -0.3
		return
	sfx("drum", 0.9)
	cg_event("step", {"dir": dir})
	cg["input_i"] = int(cg["input_i"]) + 1
	if int(cg["input_i"]) >= seq.size():
		mg_count += 1
		cg_combo_up()
		cg_judge("얼쑤!", Color(1, 0.88, 0.3), true)
		sfx("good")
		hit_stop(0.05)
		shake(8)
		cg_event("round")
		seq.append(SW_DIRS4[rng.randi() % 4])
		cg["phase"] = "wait"
		cg["show_t"] = -0.5

func draw_arrow(ci: Control, c: Vector2, dir: String, size: float, col: Color) -> void:
	var v: Vector2 = ARROW_VEC[dir]
	var tip := c + v * size
	var tail := c - v * size
	ci.draw_line(tail, tip, col, size * 0.32)
	ci.draw_colored_polygon(PackedVector2Array([tip + v * size * 0.35, tip + v.rotated(PI / 2.0) * size * 0.55, tip - v.rotated(PI / 2.0) * size * 0.55]), col)

# --- 화면 그림 ---
func custom_draw() -> void:
	var ci := cg_draw
	var W := mg_overlay.size.x
	var H := mg_overlay.size.y
	var ink := Color(0.2, 0.13, 0.08)
	var paper := Color(1.0, 0.97, 0.88)
	# 알림 글씨
	if float(cg.get("msg_t", 9.0)) < 1.2 and cg.get("msg", "") != "":
		var a := clampf(1.2 - float(cg["msg_t"]), 0.0, 1.0)
		var col: Color = cg.get("msg_c", paper)
		col.a = a
		ci.draw_string(font, Vector2(0, H * 0.33), cg["msg"], HORIZONTAL_ALIGNMENT_CENTER, W, int(font_size * 1.5), col)
	match mg_type:
		"dig":
			dig_draw(ci, W, H, paper)
		"rhythm":
			var y := H * 0.74
			var hx := W * 0.24
			var span := W * 0.7
			ci.draw_rect(Rect2(W * 0.06, y - font_size * 0.9, W * 0.88, font_size * 1.8), Color(0, 0, 0, 0.28))
			var t: float = cg["t"]
			var beat_pulse := 1.0 + 0.08 * maxf(0.0, cos(fposmod(t, float(cg["beat"])) / float(cg["beat"]) * TAU))
			ci.draw_circle(Vector2(hx, y), font_size * 1.15 * beat_pulse, Color(1, 0.86, 0.3, 0.35))
			ci.draw_arc(Vector2(hx, y), font_size * 1.15 * beat_pulse, 0, TAU, 40, Color(1, 0.86, 0.3), 5.0)
			for n in cg["notes"]:
				if n["done"]:
					continue
				var k := (float(n["t"]) - t) / R_TRAVEL
				if k > 1.05:
					continue
				var x := hx + k * span
				var r := font_size * 0.8
				if n["bad"]:
					ci.draw_circle(Vector2(x, y), r, Color(0.9, 0.25, 0.22))
					ci.draw_line(Vector2(x - r * 0.45, y - r * 0.45), Vector2(x + r * 0.45, y + r * 0.45), paper, 6.0)
					ci.draw_line(Vector2(x + r * 0.45, y - r * 0.45), Vector2(x - r * 0.45, y + r * 0.45), paper, 6.0)
				else:
					ci.draw_circle(Vector2(x, y), r, paper)
					ci.draw_arc(Vector2(x, y), r, 0, TAU, 32, ink, 4.0)
					ci.draw_string(font, Vector2(x - r, y + font_size * 0.32), String(mg_cfg.get("note", "쿵")), HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, int(font_size * 0.8), ink)
			ci.draw_string(font, Vector2(0, y + font_size * 2.2), "동그라미에 겹칠 때 톡! 빨간 X는 누르지 마세요", HORIZONTAL_ALIGNMENT_CENTER, W, int(font_size * 0.8), paper)
		"swipe":
			var a: Dictionary = cg["atk"]
			if not a.is_empty():
				var c := Vector2(W * 0.5, H * 0.55)
				var edge := {"left": Vector2(W * 0.1, H * 0.55), "right": Vector2(W * 0.9, H * 0.55), "up": Vector2(W * 0.5, H * 0.34)}
				var p: Vector2 = edge[a["dir"]]
				var tm: float = a["time"]
				var grow := 0.6
				var col := Color(0.96, 0.56, 0.18)
				if a["phase"] == "tele":
					grow = 0.55 + tm * 0.5
					p += Vector2(rng.randf_range(-3, 3), rng.randf_range(-3, 3))
				elif a["phase"] == "strike":
					grow = 1.25
					p = p.lerp(c, minf(1.0, tm * 1.4) * 0.35)
				else:
					grow = maxf(0.2, 0.9 - tm * 1.6)
				var r := font_size * 1.6 * grow
				ci.draw_circle(p, r, col)
				for k in 3:
					var ang := -0.6 + k * 0.6
					var off := (c - p).normalized().rotated(ang) * r * 0.75
					ci.draw_circle(p + off, r * 0.22, Color(1, 0.96, 0.9))
				ci.draw_circle(p + (c - p).normalized() * r * 0.05, r * 0.38, Color(1, 0.96, 0.9))
				if a["phase"] == "strike":
					ci.draw_arc(p, r * 1.12, 0, TAU, 40, Color(1, 0.3, 0.25), 6.0)
					var dirv := (p - c).normalized()
					var s := c + dirv * W * 0.08
					var e := c + dirv * W * 0.26
					ci.draw_line(s, e, paper, 10.0)
					ci.draw_line(e, e - dirv.rotated(0.5) * font_size, paper, 10.0)
					ci.draw_line(e, e - dirv.rotated(-0.5) * font_size, paper, 10.0)
			ci.draw_string(font, Vector2(0, H * 0.86), "공격이 오는 쪽으로 손가락을 휙! (가짜엔 속지 마요)", HORIZONTAL_ALIGNMENT_CENTER, W, int(font_size * 0.8), paper)
		"alternate":
			var side := int(cg["side"])
			for k in 2:
				var rect := Rect2(W * (0.04 + k * 0.5), H * 0.7, W * 0.42, H * 0.16)
				var on: bool = k == side and cg["shake"] == ""
				ci.draw_rect(rect, Color(1, 0.86, 0.3, 0.75) if on else Color(0, 0, 0, 0.25))
				ci.draw_string(font, rect.position + Vector2(0, rect.size.y * 0.62), "< 왼쪽" if k == 0 else "오른쪽 >", HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, int(font_size * 1.1), ink if on else paper)
			if cg["shake"] == "":
				var lim := float(mg_cfg.get("step_time", 1.6))
				var left := 1.0 - float(cg["step_t"]) / lim
				ci.draw_rect(Rect2(W * 0.1, H * 0.67, W * 0.8 * left, font_size * 0.3), Color(1, 0.86, 0.3) if left > 0.35 else Color(1, 0.4, 0.3))
			else:
				var hold := 1.0
				if cg["shake"] == "shake":
					hold = 1.0 - float(cg["shake_t"]) / 1.2
				ci.draw_string(font, Vector2(0, H * 0.62), "꾹 누르고 버텨요!", HORIZONTAL_ALIGNMENT_CENTER, W, int(font_size * 1.4), Color(1, 0.55, 0.45))
				ci.draw_arc(Vector2(W * 0.5, H * 0.78), font_size * 2.0, -PI / 2.0, -PI / 2.0 + TAU * hold, 40, Color(1, 0.86, 0.3), 10.0)
		"mash":
			var pulse: float = cg["pulse"]
			if mg_cfg.get("balance", false):
				var tilt: float = cg["tilt"]
				var c2 := Vector2(W * 0.5, H * 0.74)
				var len := H * 0.14
				var tip := c2 + Vector2(sin(tilt * 0.9), -cos(tilt * 0.9)) * len
				ci.draw_arc(c2, len, -PI / 2.0 - 0.9, -PI / 2.0 + 0.9, 30, Color(0, 0, 0, 0.35), 18.0)
				ci.draw_arc(c2, len, -PI / 2.0 - 0.54, -PI / 2.0 + 0.54, 30, Color(0.5, 0.9, 0.5, 0.6), 18.0)
				ci.draw_line(c2, tip, Color(0.86, 0.74, 0.5), 12.0)
				ci.draw_circle(tip, font_size * (0.5 + pulse * 0.15), paper)
				var warn: bool = absf(tilt) > 0.55
				var hint := "< 왼쪽을 눌러요" if tilt > 0.0 else "오른쪽을 눌러요 >"
				ci.draw_string(font, Vector2(0, H * 0.84), hint if warn else "빠르게 연타! 기울면 반대쪽을 눌러요", HORIZONTAL_ALIGNMENT_CENTER, W, int(font_size * (1.0 if warn else 0.8)), Color(1, 0.6, 0.45) if warn else paper)
			else:
				var g: float = cg["gauge"]
				var c3 := Vector2(W * 0.5, H * 0.74)
				var rr := font_size * (2.2 + pulse * 0.25)
				ci.draw_circle(c3, rr, Color(0, 0, 0, 0.3))
				ci.draw_arc(c3, rr, -PI / 2.0, -PI / 2.0 + TAU * g, 48, Color(1, 0.86, 0.3), 14.0)
				var tl := 1.0 - float(cg["round_t"]) / float(mg_cfg.get("round_time", 2.6))
				ci.draw_arc(c3, rr + 14.0, -PI / 2.0, -PI / 2.0 + TAU * maxf(0.0, tl), 48, Color(1, 0.45, 0.35) if tl < 0.35 else Color(0.7, 0.95, 1.0), 5.0)
				ci.draw_string(font, c3 + Vector2(-rr, font_size * 0.35), "연타!", HORIZONTAL_ALIGNMENT_CENTER, rr * 2.0, int(font_size * 1.1), paper)
		"stack":
			if g3_on("stack_base"):
				return
			var lh := H * 0.04
			var by := H * 0.84
			var scroll: float = cg["scroll"]
			var cols := [Color(0.98, 0.97, 0.92), Color(0.55, 0.72, 0.4), Color(1.0, 0.75, 0.8), Color(0.98, 0.85, 0.45)]
			var layers: Array = cg["layers"]
			for k in layers.size():
				var y := by - (k - scroll) * lh
				if y > H or y < H * 0.25:
					continue
				var L: Array = layers[k]
				var rect := Rect2(W * (float(L[0]) - float(L[1]) / 2.0), y - lh, W * float(L[1]), lh - 2.0)
				ci.draw_rect(rect, cols[k % 4])
				ci.draw_rect(Rect2(rect.position, Vector2(rect.size.x, 4.0)), (cols[k % 4] as Color).lightened(0.25))
			var cur: Array = cg["cur"]
			var cy := by - (layers.size() - scroll) * lh
			var crect := Rect2(W * (float(cur[0]) - float(cur[1]) / 2.0), cy - lh, W * float(cur[1]), lh - 2.0)
			ci.draw_rect(crect, cols[layers.size() % 4])
			ci.draw_rect(crect, ink, false, 3.0)
			for f in cg["falls"]:
				var fy := by - (int(f[4]) - scroll) * lh + float(f[2]) * H
				if fy < H + 40.0:
					ci.draw_rect(Rect2(W * (float(f[0]) - float(f[1]) / 2.0), fy - lh, W * float(f[1]), lh - 2.0), Color(0.9, 0.88, 0.8, 0.8))
			ci.draw_string(font, Vector2(0, H * 0.36), "움직이는 떡판이 아래 떡과 딱 겹칠 때 톡!", HORIZONTAL_ALIGNMENT_CENTER, W, int(font_size * 0.8), paper)
		"aim":
			if g3_on("aim3d"):
				var climb3: float = cg["climb"]
				ci.draw_rect(Rect2(W * 0.92, H * 0.25, font_size * 0.5, H * 0.45), Color(0, 0, 0, 0.3))
				ci.draw_rect(Rect2(W * 0.92, H * 0.25 + H * 0.45 * (1.0 - climb3), font_size * 0.5, H * 0.45 * climb3), Color(1, 0.45, 0.3) if climb3 > 0.7 else Color(1, 0.8, 0.4))
				return
			var tgt := aim_target()
			var rad := short_side * float(mg_cfg.get("target_r", 0.09))
			var hf: float = cg["hit_flash"]
			ci.draw_arc(tgt, rad * (1.0 + hf * 0.3), 0, TAU, 40, Color(1, 0.4 + hf * 0.5, 0.3), 5.0)
			ci.draw_arc(tgt, rad * 0.5, 0, TAU, 30, Color(1, 0.5, 0.35, 0.6), 3.0)
			# 올라오는 정도
			var climb: float = cg["climb"]
			ci.draw_rect(Rect2(W * 0.92, H * 0.25, font_size * 0.5, H * 0.45), Color(0, 0, 0, 0.3))
			ci.draw_rect(Rect2(W * 0.92, H * 0.25 + H * 0.45 * (1.0 - climb), font_size * 0.5, H * 0.45 * climb), Color(1, 0.45, 0.3) if climb > 0.7 else Color(1, 0.8, 0.4))
			var an := aim_anchor()
			ci.draw_line(an + Vector2(-font_size * 1.2, -font_size * 1.6), an, Color(0.45, 0.3, 0.18), 10.0)
			ci.draw_line(an + Vector2(font_size * 1.2, -font_size * 1.6), an, Color(0.45, 0.3, 0.18), 10.0)
			ci.draw_line(an, an + Vector2(0, font_size * 1.4), Color(0.45, 0.3, 0.18), 12.0)
			if cg.get("drag") != null:
				var dp: Vector2 = cg["drag"]
				ci.draw_line(an + Vector2(-font_size * 1.2, -font_size * 1.6), dp, Color(0.95, 0.85, 0.6), 4.0)
				ci.draw_line(an + Vector2(font_size * 1.2, -font_size * 1.6), dp, Color(0.95, 0.85, 0.6), 4.0)
				ci.draw_circle(dp, font_size * 0.45, Color(0.55, 0.38, 0.2))
				# 날아갈 길 미리 보기
				var pp := an
				var vv := (an - dp) * 5.2
				for k in 14:
					vv += Vector2(0, H * 1.4) * 0.05
					pp += vv * 0.05
					ci.draw_circle(pp, 4.0, Color(1, 1, 1, 0.7 - k * 0.045))
			var sh: Dictionary = cg["shot"]
			if not sh.is_empty():
				var sp: Vector2 = sh["p"]
				ci.draw_set_transform(sp, float(sh["spin"]), Vector2.ONE)
				ci.draw_circle(Vector2.ZERO, font_size * 0.42, Color(0.55, 0.38, 0.2))
				for k in 3:
					ci.draw_line(Vector2(-font_size * 0.35, -font_size * 0.2 + k * font_size * 0.2), Vector2(font_size * 0.35, -font_size * 0.2 + k * font_size * 0.2), Color(0.35, 0.22, 0.12), 3.0)
				ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			ci.draw_string(font, Vector2(0, H * 0.36), "아래에서 손가락을 뒤로 끌었다 놓아 던져요", HORIZONTAL_ALIGNMENT_CENTER, W, int(font_size * 0.8), paper)
		"simon":
			var pads := simon_pads()
			var lit := int(cg["lit"])
			var lt: float = cg["lit_t"]
			for k in (0 if g3_on("simon_pts") else 5):
				var on := k == lit and lt < 0.3
				var col: Color = SIMON_COLS[k]
				var r := short_side * 0.095 * (1.15 if on else 1.0)
				ci.draw_circle(pads[k], r, col.lightened(0.45) if on else col.darkened(0.15))
				for f in 5:
					var fa := -PI * 0.85 + f * PI * 0.17
					ci.draw_line(pads[k], (pads[k] as Vector2) + Vector2(cos(fa), sin(fa)) * r * 0.9, col.darkened(0.35), 3.0)
				if on:
					ci.draw_arc(pads[k], r * 1.25, 0, TAU, 36, Color(1, 1, 0.85), 5.0)
			var msg2 := "따라 누르는 중 %d/%d" % [int(cg["input_i"]), (cg["seq"] as Array).size()] if cg["phase"] == "input" else "조개 소리를 잘 들어요"
			ci.draw_string(font, Vector2(0, H * 0.6), msg2, HORIZONTAL_ALIGNMENT_CENTER, W, int(font_size * 0.95), paper)
		"dance":
			var fd: String = cg["flash_dir"]
			var ft: float = cg["flash_t"]
			var center := Vector2(W * 0.5, H * 0.58)
			if not g3_on("dance_a"):
				ci.draw_circle(center, short_side * 0.14, Color(0, 0, 0, 0.18))
			if fd != "" and ft < 0.45 and not g3_on("dance_a"):
				draw_arrow(cg_draw, center, fd, short_side * 0.1, Color(1, 0.86, 0.3) if cg["phase"] == "show" else Color(0.7, 0.95, 1.0))
			var seqn := (cg["seq"] as Array).size()
			for k in seqn:
				var px := W * 0.5 + (k - (seqn - 1) / 2.0) * font_size * 1.1
				var done: bool = cg["phase"] == "input" and k < int(cg["input_i"])
				ci.draw_circle(Vector2(px, H * 0.72), font_size * 0.3, Color(1, 0.86, 0.3) if done else Color(1, 1, 1, 0.35))
			ci.draw_string(font, Vector2(0, H * 0.79), "보여 준 순서대로 손가락을 휙휙!" if cg["phase"] == "input" else "화살표 순서를 잘 봐요", HORIZONTAL_ALIGNMENT_CENTER, W, int(font_size * 0.85), paper)

# --- 갯벌 캐기: 여러 숨구멍 중 뽀글뽀글 거품이 오르는 곳을 찾아요 ---
# 바지락은 톡톡, 큰 백합은 빠르게 연타, 맛조개는 쏙 나올 때 위로 쓱!, 꽃게는 건드리면 따끔!
const DIG_KINDS := {
	"clam": {"name": "바지락", "taps": 3, "life": 2.4},
	"big": {"name": "백합", "taps": 7, "life": 2.8},
	"razor": {"name": "맛조개", "taps": 0, "life": 1.1},
	"crab": {"name": "꽃게", "taps": 0, "life": 1.5},
}

func dig_holes() -> Array:
	return w.get("dig_holes", [])

func dig_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.45
	return m

func dig_make_node(kind: String) -> Node3D:
	var n := Node3D.new()
	world_node(n)
	match kind:
		"clam":
			add_blobs(n, [[Vector3(0, 0.06, 0), Vector3(0.26, 0.12, 0.2), Color(0.82, 0.74, 0.62)], [Vector3(0, 0.1, 0), Vector3(0.2, 0.06, 0.16), Color(0.65, 0.55, 0.45)]], blob_gloss())
		"big":
			add_blobs(n, [[Vector3(0, 0.1, 0), Vector3(0.46, 0.22, 0.38), Color(0.9, 0.86, 0.78)], [Vector3(0, 0.17, 0), Vector3(0.36, 0.1, 0.3), Color(0.72, 0.62, 0.52)]], blob_gloss())
		"razor":
			var mi := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.045
			cm.bottom_radius = 0.045
			cm.height = 0.55
			mi.mesh = cm
			mi.material_override = dig_mat(Color(0.86, 0.76, 0.5))
			mi.position = Vector3(0, 0.2, 0)
			n.add_child(mi)
			add_blobs(n, [[Vector3(0, 0.49, 0), Vector3(0.07, 0.07, 0.07), Color(1.0, 0.9, 0.85)]])
		"crab":
			var items := [[Vector3(0, 0.12, 0), Vector3(0.4, 0.16, 0.3), Color(0.85, 0.3, 0.2)], [Vector3(-0.08, 0.22, 0.12), Vector3(0.05, 0.08, 0.05), Color(0.1, 0.05, 0.05)], [Vector3(0.08, 0.22, 0.12), Vector3(0.05, 0.08, 0.05), Color(0.1, 0.05, 0.05)], [Vector3(-0.26, 0.14, 0.12), Vector3(0.14, 0.1, 0.12), Color(0.9, 0.35, 0.22)], [Vector3(0.26, 0.14, 0.12), Vector3(0.14, 0.1, 0.12), Color(0.9, 0.35, 0.22)]]
			for k in 3:
				items.append([Vector3(-0.22, 0.06, -0.06 - k * 0.07), Vector3(0.16, 0.03, 0.03), Color(0.75, 0.25, 0.15)])
				items.append([Vector3(0.22, 0.06, -0.06 - k * 0.07), Vector3(0.16, 0.03, 0.03), Color(0.75, 0.25, 0.15)])
			add_blobs(n, items)
	return n

func update_dig(delta: float) -> void:
	if float(cg["t"]) < 0.0:
		return
	var holes := dig_holes()
	if holes.is_empty():
		return
	var tg: Dictionary = cg["tgt"]
	if tg.is_empty():
		cg["gap"] = float(cg["gap"]) - delta
		if float(cg["gap"]) <= 0.0:
			var i := rng.randi() % holes.size()
			if i == int(cg["last"]):
				i = (i + 1 + rng.randi() % (holes.size() - 1)) % holes.size()
			cg["last"] = i
			var r := rng.randf()
			var kind := "clam"
			if mg_count >= 1:
				if r < 0.22:
					kind = "big"
				elif r < 0.44:
					kind = "razor"
				elif r < 0.6:
					kind = "crab"
			cg["tgt"] = {"i": i, "kind": kind, "state": "tell", "t": 0.0, "taps": 0, "bub": 0.0}
		return
	tg["t"] = float(tg["t"]) + delta
	var hp: Vector3 = holes[int(tg["i"])]
	var kind2: String = tg["kind"]
	var sp := 1.0 + mg_count * 0.04
	if tg["state"] == "tell":
		tg["bub"] = float(tg["bub"]) - delta
		if float(tg["bub"]) <= 0.0:
			tg["bub"] = 0.1
			burst3d(hp + Vector3(0, 0.05, 0), Color(0.85, 0.95, 1.0) if kind2 != "crab" else Color(0.95, 0.75, 0.6), 3)
			sfx("tick", 1.6 + rng.randf() * 0.3)
		if float(tg["t"]) > 0.55 / sp:
			tg["state"] = "up"
			tg["t"] = 0.0
			var n := dig_make_node(kind2)
			n.global_position = hp + Vector3(0, -0.25, 0)
			n.rotation.y = rng.randf() * TAU
			var rise := 0.0 if kind2 in ["clam", "big"] else (0.18 if kind2 == "razor" else 0.05)
			n.create_tween().tween_property(n, "global_position:y", hp.y + rise, 0.15).set_ease(Tween.EASE_OUT)
			tg["node"] = n
			if kind2 == "crab":
				sfx("crack", 1.6)
		return
	var life: float = float(DIG_KINDS[kind2]["life"]) / sp
	var node: Node3D = tg.get("node")
	if kind2 == "crab" and node != null:
		node.rotation.y += sin(anim_t * 18.0) * 0.08
	if kind2 == "razor" and node != null:
		node.position.y = hp.y + 0.18 + sin(anim_t * 20.0) * 0.03
	if float(tg["t"]) > life:
		if kind2 == "crab":
			cg_judge("휴~ 꽃게가 지나갔어요", Color(0.85, 0.95, 1.0), false)
			if node != null:
				var tw := node.create_tween()
				tw.tween_property(node, "global_position", node.global_position + Vector3(1.8, 0, 0.3), 0.5)
				tw.tween_callback(node.queue_free)
		else:
			cg_lose("쏙 숨었어요!")
			cg_event("escape", {"at": hp})
			if node != null:
				var tw2 := node.create_tween()
				tw2.tween_property(node, "global_position:y", hp.y - 0.4, 0.2)
				tw2.tween_callback(node.queue_free)
		cg["tgt"] = {}
		cg["gap"] = 0.45

func dig_hole_at(pos: Vector2) -> int:
	var best := -1
	var bd := short_side * 0.14
	var holes := dig_holes()
	for k in holes.size():
		var d := pos.distance_to(cam.unproject_position(holes[k]))
		if d < bd:
			bd = d
			best = k
	return best

func dig_go(hp: Vector3) -> void:
	# 주인공이 그 구멍 옆으로 폴짝 옮겨 가요
	var stand := hp + Vector3(-0.55, 0, 0.45)
	stand.y = player.position.y
	if player.position.distance_to(stand) > 0.2:
		player.create_tween().tween_property(player, "position", stand, 0.12)
	player.rotation.y = atan2(hp.x - stand.x, hp.z - stand.z)

func dig_press(pos: Vector2) -> void:
	var k := dig_hole_at(pos)
	if k < 0:
		return
	var holes := dig_holes()
	var hp: Vector3 = holes[k]
	dig_go(hp)
	var tg: Dictionary = cg["tgt"]
	if tg.is_empty() or int(tg["i"]) != k:
		w["swing"] = 1.0
		burst3d(hp + Vector3(0, 0.05, 0), Color(0.45, 0.38, 0.3), 4)
		cg_judge("거긴 빈 구멍!", Color(0.85, 0.85, 0.9), false)
		cg_combo_break()
		return
	if tg["state"] == "tell":
		cg_judge("아직! 나오면 캐요", Color(1, 0.9, 0.6), false)
		return
	var kind: String = tg["kind"]
	var node: Node3D = tg.get("node")
	match kind:
		"crab":
			cg_lose("앗 따가워! 꽃게였어요")
			flash(Color(1, 0.6, 0.5))
			if node != null:
				var tw := node.create_tween()
				tw.tween_property(node, "global_position", node.global_position + Vector3(-1.6, 0, 0.6), 0.4)
				tw.tween_callback(node.queue_free)
			cg["tgt"] = {}
			cg["gap"] = 0.5
		"razor":
			cg["razor_press"] = pos
		_:
			w["swing"] = 1.0
			tg["taps"] = int(tg["taps"]) + 1
			cam_kick = 0.06
			sfx("tap", 0.9 + int(tg["taps"]) * 0.05)
			burst3d(hp + Vector3(0, 0.08, 0), Color(0.42, 0.36, 0.3), 5)
			if node != null:
				node.global_position.y = hp.y + 0.03 * int(tg["taps"])
				node.scale = Vector3.ONE * 1.12
				node.create_tween().tween_property(node, "scale", Vector3.ONE, 0.1)
			if int(tg["taps"]) >= int(DIG_KINDS[kind]["taps"]):
				dig_got(tg, hp)

func dig_drag(pos: Vector2) -> void:
	var tg: Dictionary = cg["tgt"]
	if cg.get("razor_press") == null or tg.is_empty() or tg["kind"] != "razor" or tg["state"] != "up":
		return
	var d := (cg["razor_press"] as Vector2) - pos
	if d.y > short_side * 0.07:
		cg["razor_press"] = null
		var hp: Vector3 = dig_holes()[int(tg["i"])]
		dig_got(tg, hp)

func dig_release(_pos: Vector2) -> void:
	if cg.get("razor_press") != null:
		cg["razor_press"] = null
		var tg: Dictionary = cg["tgt"]
		if not tg.is_empty() and tg["kind"] == "razor":
			cg_judge("위로 쓱 당겨요!", Color(1, 0.9, 0.6), false)

func dig_got(tg: Dictionary, hp: Vector3) -> void:
	var kind: String = tg["kind"]
	var node: Node3D = tg.get("node")
	mg_count += 1
	w["swing"] = 1.0
	var quick := float(tg["t"]) < 0.9
	if quick:
		cg_combo_up()
	cg_judge("%s 쏙!%s" % [DIG_KINDS[kind]["name"], " 빠르다!" if quick else ""], Color(1, 0.88, 0.3), kind != "clam")
	sfx("pop", 1.0 if kind != "big" else 0.8)
	hit_stop(0.05 if kind == "big" else 0.03)
	shake(10 if kind == "big" else 6)
	cam_kick = 0.14
	burst3d(hp + Vector3(0, 0.2, 0), Color(0.45, 0.38, 0.3), 14)
	cg_event("round", {"at": hp})
	if node != null:
		var tw := node.create_tween()
		tw.tween_property(node, "global_position", hp + Vector3(-0.5, 1.4, 0.5), 0.28).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(node, "rotation", Vector3(3, 2, 0), 0.28)
		tw.tween_property(node, "scale", Vector3.ONE * 0.01, 0.18)
		tw.tween_callback(node.queue_free)
	cg["tgt"] = {}
	cg["gap"] = 0.35

func dig_draw(ci: CanvasItem, W: float, H: float, paper: Color) -> void:
	var tg: Dictionary = cg["tgt"]
	if tg.is_empty() or tg["state"] != "up":
		ci.draw_string(font, Vector2(0, H * 0.8), "뽀글뽀글 거품이 오르는 구멍을 봐요", HORIZONTAL_ALIGNMENT_CENTER, W, int(font_size * 0.85), paper)
		return
	var hp: Vector3 = dig_holes()[int(tg["i"])]
	var sp := cam.unproject_position(hp + Vector3(0, 0.5, 0))
	var kind: String = tg["kind"]
	var txt := ""
	var col := paper
	match kind:
		"clam", "big":
			txt = "톡톡! %d" % (int(DIG_KINDS[kind]["taps"]) - int(tg["taps"]))
			col = Color(1, 0.95, 0.7)
		"razor":
			txt = "위로 쓱!"
			col = Color(0.75, 0.95, 1.0)
		"crab":
			txt = "꽃게! 건드리지 마요"
			col = Color(1, 0.55, 0.45)
	ci.draw_string(font, sp - Vector2(W * 0.3, 0), txt, HORIZONTAL_ALIGNMENT_CENTER, W * 0.6, int(font_size * 1.1), col)


# ---------- 미니게임 3D 연출: 월드에서 하는 쌓기·던지기·조개·춤은 그림 대신 진짜 물건으로 ----------
var g3 := {}

func g3_on(key: String) -> bool:
	return mg_world and w.has(key)

func g3_mat(c: Color, glow: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.6
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = glow
	return m

func g3_box(size: Vector3, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = g3_mat(c)
	world_node(mi)
	return mi

# 두 점 사이를 잇는 가는 막대 (새총 고무줄)
func g3_stretch(mi: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var d := b - a
	var l := d.length()
	if l < 0.001:
		mi.visible = false
		return
	mi.visible = true
	var y := d / l
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	mi.global_transform = Transform3D(Basis(x, y * l, z), (a + b) / 2.0)

func update_g3(delta: float) -> void:
	if not mg_world:
		return
	if g3.get("cam0") == null:
		g3["cam0"] = world_cam
	match mg_type:
		"stack":
			if w.has("stack_base"):
				g3_stack(delta)
		"aim":
			if w.has("aim3d"):
				g3_aim(delta)
		"simon":
			if w.has("simon_pts"):
				g3_simon(delta)
		"dance":
			if w.has("dance_a"):
				g3_dance(delta)

const STACK_COLS := [Color(0.98, 0.97, 0.92), Color(0.55, 0.72, 0.4), Color(1.0, 0.75, 0.8), Color(0.98, 0.85, 0.45)]
const STACK_TH := 0.13

func stack_world(x: float, k: int) -> Vector3:
	var base: Vector3 = w["stack_base"]
	var span: float = w.get("stack_span", 1.5)
	return base + Vector3((x - 0.5) * span, k * STACK_TH + STACK_TH / 2.0, 0)

func g3_stack(delta: float) -> void:
	var span: float = w.get("stack_span", 1.5)
	var layers: Array = cg["layers"]
	if not g3.has("layers"):
		g3["layers"] = []
		g3["falls_n"] = 0
		g3["cur"] = g3_box(Vector3(1, STACK_TH * 0.92, 0.55), STACK_COLS[1])
	var made: Array = g3["layers"]
	while made.size() < layers.size():
		var k := made.size()
		var L: Array = layers[k]
		var n := g3_box(Vector3(float(L[1]) * span, STACK_TH * 0.92, 0.55), STACK_COLS[k % 4])
		n.position = stack_world(float(L[0]), k)
		if k > 0:
			# 내려앉는 맛: 살짝 눌렸다가 펴져요
			n.scale = Vector3(1.06, 0.6, 1.06)
			n.create_tween().tween_property(n, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			burst3d(n.position + Vector3(0, STACK_TH / 2.0, 0.28), Color(1, 0.97, 0.85), 6)
		made.append(n)
	var cur: Array = cg["cur"]
	var cn: MeshInstance3D = g3["cur"]
	(cn.mesh as BoxMesh).size = Vector3(float(cur[1]) * span, STACK_TH * 0.92, 0.55)
	(cn.material_override as StandardMaterial3D).albedo_color = STACK_COLS[layers.size() % 4]
	cn.position = stack_world(float(cur[0]), layers.size()) + Vector3(0, 0.03 + sin(anim_t * 6.0) * 0.015, 0)
	# 잘려 떨어지는 조각
	var falls: Array = cg["falls"]
	while int(g3["falls_n"]) < falls.size():
		var f: Array = falls[int(g3["falls_n"])]
		g3["falls_n"] = int(g3["falls_n"]) + 1
		var fnode := g3_box(Vector3(float(f[1]) * span, STACK_TH * 0.92, 0.55), STACK_COLS[int(f[4]) % 4])
		var p0 := stack_world(float(f[0]), int(f[4]))
		fnode.position = p0
		var side := signf(float(f[0]) - 0.5) if absf(float(f[0]) - 0.5) > 0.01 else 1.0
		var tw := fnode.create_tween()
		tw.tween_property(fnode, "position", p0 + Vector3(side * 0.6, -1.4 - int(f[4]) * STACK_TH, 0.2), 0.7).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(fnode, "rotation", Vector3(0.8, 0.0, -side * 2.2), 0.7)
		tw.tween_callback(fnode.queue_free)
	# 높이 쌓일수록 카메라가 따라 올라가요
	var lift := maxf(0.0, layers.size() - 5.0) * STACK_TH
	var c0: Transform3D = g3["cam0"]
	g3["lift"] = lerpf(float(g3.get("lift", 0.0)), lift, minf(1.0, delta * 4.0))
	world_cam = c0.translated(Vector3(0, float(g3["lift"]), 0))

func g3_aim(delta: float) -> void:
	if not g3.has("pine"):
		var pine := Node3D.new()
		world_node(pine)
		var body := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.11
		sm.height = 0.3
		body.mesh = sm
		body.material_override = g3_mat(Color(0.5, 0.33, 0.18))
		pine.add_child(body)
		for k in 6:
			var sc := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.24, 0.03, 0.08)
			sc.mesh = bm
			sc.material_override = g3_mat(Color(0.38, 0.24, 0.12))
			sc.position = Vector3(0, -0.1 + k * 0.04, 0)
			sc.rotation.y = k * 1.1
			pine.add_child(sc)
		pine.visible = false
		g3["pine"] = pine
		# 새총: Y자 나뭇가지 + 고무줄 두 가닥 + 가죽 주머니
		var sling := Node3D.new()
		world_node(sling)
		var wood := g3_mat(Color(0.45, 0.3, 0.18))
		for part in [[Vector3(0, -0.09, 0), Vector3(0.035, 0.2, 0.035), 0.0], [Vector3(-0.05, 0.05, 0), Vector3(0.03, 0.14, 0.03), 0.5], [Vector3(0.05, 0.05, 0), Vector3(0.03, 0.14, 0.03), -0.5]]:
			var mi := MeshInstance3D.new()
			var bx := BoxMesh.new()
			bx.size = part[1]
			mi.mesh = bx
			mi.material_override = wood
			mi.position = part[0]
			mi.rotation.z = part[2]
			sling.add_child(mi)
		g3["sling"] = sling
		var band := g3_mat(Color(0.9, 0.78, 0.55))
		for nm in ["bandL", "bandR"]:
			var b := MeshInstance3D.new()
			var bb := BoxMesh.new()
			bb.size = Vector3(0.008, 1.0, 0.008)
			b.mesh = bb
			b.material_override = band
			world_node(b)
			g3[nm] = b
		var pouch := MeshInstance3D.new()
		var ps := SphereMesh.new()
		ps.radius = 0.03
		ps.height = 0.05
		pouch.mesh = ps
		pouch.material_override = g3_mat(Color(0.5, 0.33, 0.2))
		world_node(pouch)
		g3["pouch"] = pouch
		var dots := []
		var dm := SphereMesh.new()
		dm.radius = 0.012
		dm.height = 0.024
		for k in 10:
			var d := MeshInstance3D.new()
			d.mesh = dm
			d.material_override = g3_mat(Color(1, 1, 0.9), 1.5)
			d.material_override.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			world_node(d)
			dots.append(d)
		g3["dots"] = dots
		# 과녁: 호랑이 머리 둘레에 도는 빛 고리
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.42
		tm.outer_radius = 0.5
		ring.mesh = tm
		var rm := g3_mat(Color(1, 0.5, 0.35), 2.0)
		rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		rm.no_depth_test = true
		rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		rm.albedo_color.a = 0.75
		ring.material_override = rm
		world_node(ring)
		g3["ring"] = ring
	var near := 1.0
	var an := aim_anchor()
	var fork := cam.project_position(an + Vector2(0, -font_size * 1.2), near)
	var sling: Node3D = g3["sling"]
	sling.global_transform = Transform3D(cam.global_transform.basis.scaled(Vector3.ONE * 1.0), cam.project_position(an, near))
	var cb := cam.global_transform.basis
	var tipL := sling.global_position + cb * Vector3(-0.09, 0.12, 0)
	var tipR := sling.global_position + cb * Vector3(0.09, 0.12, 0)
	var pouch_p := (tipL + tipR) / 2.0
	var dots: Array = g3["dots"]
	for d in dots:
		(d as Node3D).visible = false
	if cg.get("drag") != null:
		var dp: Vector2 = cg["drag"]
		pouch_p = cam.project_position(dp, near)
		var pp := an
		var vv := (an - dp) * 5.2
		var H := mg_overlay.size.y
		for k in dots.size():
			vv += Vector2(0, H * 1.4) * 0.05
			pp += vv * 0.05
			var dn: Node3D = dots[k]
			dn.visible = true
			dn.global_position = cam.project_position(pp, near + k * 0.35)
	g3_stretch(g3["bandL"], tipL, pouch_p)
	g3_stretch(g3["bandR"], tipR, pouch_p)
	(g3["pouch"] as Node3D).global_position = pouch_p
	var tgt3: Vector3 = w["aim3d"].call()
	var ring: Node3D = g3["ring"]
	var hf: float = cg["hit_flash"]
	ring.global_transform = Transform3D(Basis(cb.x, cb.z, -cb.y).scaled(Vector3.ONE * (1.0 + hf * 0.4 + sin(anim_t * 5.0) * 0.05)), tgt3)
	var pine: Node3D = g3["pine"]
	var sh: Dictionary = cg["shot"]
	if sh.is_empty():
		pine.visible = cg.get("drag") != null
		if pine.visible:
			pine.global_position = pouch_p
	else:
		pine.visible = true
		sh["age"] = float(sh.get("age", 0.0)) + delta
		var far := cam.global_position.distance_to(tgt3)
		var depth := lerpf(near, far, clampf(float(sh["age"]) / 0.45, 0.0, 1.0))
		pine.global_position = cam.project_position(sh["p"], depth)
		pine.rotation = Vector3(float(sh["spin"]), float(sh["spin"]) * 0.7, 0)
		pine.scale = Vector3.ONE * (0.5 + depth * 0.12)

func g3_simon(_delta: float) -> void:
	var pts: Array = w["simon_pts"]
	if not g3.has("shells"):
		var shells := []
		for k in pts.size():
			var n := Node3D.new()
			world_node(n)
			n.global_position = pts[k]
			var col: Color = SIMON_COLS[k]
			var m := g3_mat(col, 0.0)
			m.roughness = 0.3
			# 부채꼴 가리비: 납작한 반구 + 골 다섯 줄
			var cap := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.32
			sm.height = 0.3
			sm.is_hemisphere = true
			cap.mesh = sm
			cap.material_override = m
			cap.scale = Vector3(1.0, 0.55, 0.85)
			n.add_child(cap)
			for f in 5:
				var rib := MeshInstance3D.new()
				var bm := BoxMesh.new()
				bm.size = Vector3(0.035, 0.05, 0.3)
				rib.mesh = bm
				rib.material_override = g3_mat(col.darkened(0.3))
				rib.position = Vector3(0, 0.1, 0.02)
				rib.rotation = Vector3(0.35, (f - 2) * 0.38, 0)
				n.add_child(rib)
			var hinge := MeshInstance3D.new()
			var hb := BoxMesh.new()
			hb.size = Vector3(0.16, 0.06, 0.08)
			hinge.mesh = hb
			hinge.material_override = g3_mat(col.darkened(0.2))
			hinge.position = Vector3(0, 0.03, -0.24)
			n.add_child(hinge)
			n.set_meta("mat", m)
			shells.append(n)
		g3["shells"] = shells
	var lit := int(cg["lit"])
	var lt: float = cg["lit_t"]
	var shells2: Array = g3["shells"]
	for k in shells2.size():
		var n: Node3D = shells2[k]
		var m: StandardMaterial3D = n.get_meta("mat")
		var on := k == lit and lt < 0.3
		m.emission_enabled = on
		m.emission = SIMON_COLS[k]
		m.emission_energy_multiplier = 2.2
		var s := 1.0 + (0.25 * (1.0 - lt / 0.3) if on else 0.0)
		n.scale = Vector3(s, s, s)
		n.position.y = (pts[k] as Vector3).y + (0.12 * (1.0 - lt / 0.3) if on else 0.0)

func g3_dance(_delta: float) -> void:
	if not g3.has("arrow"):
		var a := Node3D.new()
		world_node(a)
		var m := g3_mat(Color(1, 0.86, 0.3), 1.6)
		var shaft := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.4, 0.14, 0.08)
		shaft.mesh = bm
		shaft.material_override = m
		shaft.position = Vector3(-0.12, 0, 0)
		a.add_child(shaft)
		var head := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = 0.2
		cm.height = 0.3
		cm.radial_segments = 3
		head.mesh = cm
		head.material_override = m
		head.position = Vector3(0.2, 0, 0)
		head.rotation.z = -PI / 2.0
		a.add_child(head)
		a.set_meta("mat", m)
		g3["arrow"] = a
	var arrow: Node3D = g3["arrow"]
	var fd: String = cg["flash_dir"]
	var ft: float = cg["flash_t"]
	arrow.visible = fd != "" and ft < 0.45
	if not arrow.visible:
		return
	var who: Node3D = w["dance_a"] if cg["phase"] == "show" else w["dance_b"]
	var cb := cam.global_transform.basis
	var ang := {"right": 0.0, "up": PI / 2.0, "left": PI, "down": -PI / 2.0}
	var rot := Basis(cb.z, float(ang.get(fd, 0.0)))
	var pop := 1.0 + maxf(0.0, 0.15 - ft) * 3.0
	arrow.global_transform = Transform3D((rot * cb).scaled(Vector3.ONE * pop), who.global_position + Vector3(0, 2.3, 0))
	(arrow.get_meta("mat") as StandardMaterial3D).albedo_color = Color(1, 0.86, 0.3) if cg["phase"] == "show" else Color(0.7, 0.95, 1.0)
	(arrow.get_meta("mat") as StandardMaterial3D).emission = (arrow.get_meta("mat") as StandardMaterial3D).albedo_color


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
	if CUSTOM_GAMES.has(type):
		custom_begin()
	mg_lives_start = mg_lives
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
		# 별점: 기회를 하나도 안 잃으면 별 셋 (덤으로 엽전)
		var lost := mg_lives_start - mg_lives
		var stars := 3 if lost <= 0 else (2 if lost == 1 else 1)
		float_text("★".repeat(stars) + "☆".repeat(3 - stars), mid + Vector2(0, font_size * 2.6), Color(1, 0.86, 0.25), 2.2)
		if stars == 3 and CUSTOM_GAMES.has(mg_type):
			coins += 5
			float_text("별 셋! +5냥", mid + Vector2(0, font_size * 4.6), Color(1, 0.95, 0.6), 1.2)
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
	if CUSTOM_GAMES.has(mg_type):
		custom_input(event)
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
	elif CUSTOM_GAMES.has(mg_type):
		update_custom(delta)
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
	# 물속에서는 한 번 톡 눌러도 쑥 떠올라요 (꾹 누르면 계속 올라가요)
	if swimming and player != null:
		player.velocity.y = maxf(player.velocity.y, SWIM_UP * 1.15)
		sfx("splash", 1.4)

# ---------- 헤엄치기 (장마다 물속인지 알려 줘요) ----------
const SWIM_UP := 3.2
const SWIM_SINK := 0.9
var swimming := false
var cam_prev := Vector3.ZERO
var cam_smooth_ok := false
var jump_touch := -1
var jump_mouse := false

func is_swimming() -> bool:
	return false

# 헤엄칠 때 발이 올라갈 수 있는 가장 높은 곳 (물 위로 튀어나가지 않게)
func swim_ceiling() -> float:
	return 0.0

func jump_held() -> bool:
	return jump_touch >= 0 or jump_mouse or Input.is_physical_key_pressed(KEY_SPACE)

# 카메라가 올라갈 수 있는 가장 높은 곳 (물속에서는 물 밑에 머물러요)
func cam_ceiling() -> float:
	return INF

func fall_limit() -> float:
	return -10.0

func respawn_point() -> Vector3:
	return Vector3(-2, 0, 16)

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
	if player == null:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			var b := hud_button_hit(event.position)
			if b != null:
				btn_touches.append(event.index)
				if b == jump_button:
					jump_touch = event.index
				hud_press(b)
				get_viewport().set_input_as_handled()
		elif event.index in btn_touches:
			btn_touches.erase(event.index)
			if event.index == jump_touch:
				jump_touch = -1
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		if event.index in btn_touches:
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and not event.pressed:
		jump_mouse = false
	elif event is InputEventMouseButton and event.pressed and event.device != -1:
		# 컴퓨터 마우스 (터치에서 만들어진 가짜 마우스 이벤트는 제외)
		var b2 := hud_button_hit(event.position)
		if b2 != null:
			if b2 == jump_button:
				jump_mouse = true
			hud_press(b2)
			get_viewport().set_input_as_handled()

func pinch_dist() -> float:
	var ps := pinch_points.values()
	return (ps[0] as Vector2).distance_to(ps[1])

func pinch_angle() -> float:
	var ps := pinch_points.values()
	var d: Vector2 = (ps[1] as Vector2) - (ps[0] as Vector2)
	return atan2(d.y, d.x)

func _unhandled_input(event: InputEvent) -> void:
	if player == null:
		return
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
			pinch_start_angle = pinch_angle()
			pinch_start_yaw = cam_yaw_target
			pinch_rotating = false
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
			# 두 손가락을 비틀면 화면이 돌아가요 (지도 앱처럼 손가락을 따라 세상이 돌아요)
			var turn := wrapf(pinch_angle() - pinch_start_angle, -PI, PI)
			if not pinch_rotating and absf(turn) > 0.14:
				pinch_rotating = true
				pinch_start_angle = pinch_angle()
				turn = 0.0
			if pinch_rotating:
				cam_yaw_target = pinch_start_yaw + turn
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
	if player == null:
		return
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
	swimming = is_swimming()
	if swimming:
		# 물속: 위로 버튼을 누르고 있으면 떠오르고, 떼면 천천히 가라앉아요
		player.velocity.x *= 0.72
		player.velocity.z *= 0.72
		var want_vy := SWIM_UP if (jump_held() and not busy) else -SWIM_SINK
		player.velocity.y = lerpf(player.velocity.y, want_vy, minf(1.0, delta * 3.0))
		if player.position.y > swim_ceiling() and player.velocity.y > 0.0:
			player.velocity.y = 0.0
	elif player.is_on_floor():
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
	if on_floor and not was_on_floor and fall_speed > 3.0 and not swimming:
		# 착지: 쿵 하고 납작해졌다 돌아오기
		sfx("land")
		stretch_player(Vector3(1.3, 0.7, 1.3))
		burst3d(player.position, Color(0.85, 0.8, 0.65), 8)
	was_on_floor = on_floor
	if on_floor and dir.length() > 0.1 and not swimming:
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
			# 동작 클립으로 걸을 땐 발이 땅에 닿는 순간에 맞춰 따로 울려요
			if not player_body.get_meta("anim_on", false) or not player_body.has_meta("step_times"):
				sfx("step", rng.randf_range(0.85, 1.15))
	else:
		player_body.position.y = lerpf(player_body.position.y, 1.0, 0.3)
		limb_amt = lerpf(limb_amt, 0.0, 0.25)
	arm_up_amt = lerpf(arm_up_amt, 0.0 if (on_floor or swimming) else 1.0, 0.3)
	player_body.set_meta("gait", [fposmod(walk_phase / TAU, 1.0), limb_amt, gait_run])
	var cur_speed := Vector2(player.velocity.x, player.velocity.z).length()
	if swimming:
		limb_amt = lerpf(limb_amt, clampf(cur_speed / 2.0, 0.0, 1.0), 0.2)
	if not (mg_active and mg_world) and (on_floor or swimming) and arm_up_amt < 0.15 and drive_anim(player_body, limb_amt, gait_run, cur_speed / lerpf(2.6, 6.5, gait_run)):
		# 동작 클립이 몸의 오르내림까지 해 줘요
		player_body.position.y = lerpf(player_body.position.y, 1.0, 0.3)
		anim_footsteps(on_floor and not swimming)
	else:
		stop_anim(player_body)
		if mg_active and mg_world:
			world_pose(delta)
		else:
			pose_person(player_body, sin(walk_phase) * limb_amt, arm_up_amt)
	if dir.length() > 0.1 and on_floor:
		player_body.rotation.x = lerpf(player_body.rotation.x, 0.04 if player_body.has_meta("skel") else 0.12, 0.2)
	else:
		player_body.rotation.x = lerpf(player_body.rotation.x, 0.0, 0.2)
	if player.position.y < fall_limit():
		player.position = respawn_point()
		player.velocity = Vector3.ZERO
	if dir.length() > 0.1:
		player.rotation.y = lerp_angle(player.rotation.y, atan2(dir.x, dir.z), minf(1.0, delta * 14.0))
	cam_zoom = lerpf(cam_zoom, cam_zoom_target, minf(1.0, delta * 10.0))
	if mg_active and mg_world:
		# 미니게임 자리로 카메라가 스르륵 다가가요
		cam.global_transform = cam.global_transform.interpolate_with(world_cam, minf(1.0, delta * 5.0))
	else:
		# 기본보다 가까이 당기면 카메라가 점점 낮아지며 앞을 바라봐요 (하늘이 보여요)
		var offs := CAM_OFFSET * cam_zoom
		var look_y := 1.3
		if cam_zoom < 1.0:
			var nk := clampf((cam_zoom - ZOOM_MIN) / (1.0 - ZOOM_MIN), 0.0, 1.0)
			nk = nk * nk * (3.0 - 2.0 * nk)
			offs = CAM_NEAR.lerp(CAM_OFFSET, nk)
			look_y = lerpf(2.6, 1.3, nk)
		if swimming:
			# 물속: 뒤에서 낮게 따라가며 앞을 바라봐요 (물 위로 튀어나가지 않게)
			offs = Vector3(0, 2.2, 7.0) * clampf(cam_zoom, 0.6, 1.4)
			look_y = 0.6
		cam.position = player.position + offs.rotated(Vector3.UP, cam_yaw)
		var gh := cam_ground(cam.position.x, cam.position.z)
		if cam.position.y < gh + 1.2:
			cam.position.y = gh + 1.2
		var ceil_y := cam_ceiling()
		if cam.position.y > ceil_y:
			cam.position.y = maxf(ceil_y, gh + 0.5)
		# 물속에서는 카메라가 부드럽게 따라와요 (출렁임 줄이기)
		if swimming and cam_smooth_ok:
			cam.position = cam_prev.lerp(cam.position, minf(1.0, delta * 6.0))
		cam_prev = cam.position
		cam_smooth_ok = true
		cam.look_at(player.position + Vector3(0, look_y, 0))
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
	turn_button.visible = false

# ---------- 장마다 덮어쓰는 훅 (빈 함수: 각 장 스크립트가 실제 내용을 채워요) ----------

# 맵과 마을을 지어요 (주인공과 화면을 만들기 전에 불려요)
func build_chapter() -> void:
	pass

# 화면 부품을 만든 뒤 물건을 흩어 놓는 등 마무리해요
func after_ui() -> void:
	pass

# 첫 이야기 카드를 보여 주며 장을 시작해요
func start_chapter() -> void:
	pass

# 흙길·마당 같은 땅 얼룩을 칠해요 (splat_stamp 로 splat_r, splat_g 에)
func paint_ground_splat() -> void:
	pass

# 숲 바닥처럼 땅을 살짝 짙게 할 곳 (0~1)
func splat_forest(_x: float, _z: float) -> float:
	return 0.0

# 이정표(다음 이야기로 가는 길)를 눌렀을 때
func on_gate() -> void:
	pass

# 카메라 자리의 땅 높이 (언덕이 있는 장은 덮어써서 카메라가 땅속에 묻히지 않게 해요)
func cam_ground(_x: float, _z: float) -> float:
	return -100.0

func make_world() -> void:
	pass

func make_village() -> void:
	pass

func herb_kinds_done() -> int:
	return 0

func pick_wild(t: Dictionary) -> void:
	pass

func read_story(i: int) -> void:
	pass

func scatter_items() -> void:
	pass

func story_count() -> int:
	return 0

func get_piece_id(id: int, extra: String) -> void:
	pass

func world_pose(delta: float) -> void:
	scene_pose()


func splash3d(pos: Vector3, big: bool = false) -> void:
	pass

func chips3d(pos: Vector3) -> void:
	pass

func wood_marker() -> float:
	return 0.0

func wood_zone() -> float:
	return 0.0

func update_wood3d(delta: float) -> void:
	pass

func wood_strike() -> void:
	pass

func update_well3d(delta: float) -> void:
	pass

func well_drag(dy: float, dt_ms: float) -> void:
	pass

func update_fish_world(delta: float) -> void:
	pass

func fish_leap(kind: int) -> void:
	pass

func draw_reel_meter(ci: CanvasItem) -> void:
	pass

func scene_setup(scene: String) -> void:
	pass

func plant_world_pos(row: int, col: int) -> Vector3:
	return Vector3.ZERO

func update_south(delta: float) -> void:
	pass

func farm_action_text() -> String:
	return ""


func load_south() -> void:
	pass


func fish_kinds_found() -> int:
	return 0

func start_fishing() -> void:
	pass

func fish_tap() -> void:
	pass

func update_fish(delta: float) -> void:
	pass

func draw_fish2d(ci: CanvasItem, c: Vector2, s: float, kind: int, rot: float, shadow: bool) -> void:
	pass

func draw_pond_scene(ci: CanvasItem) -> void:
	pass


func plant_slot(row: int, col: int) -> Vector2:
	return Vector2.ZERO

func plant_cursor_x() -> float:
	return 0.0

func plant_tap() -> void:
	pass

func update_plant(delta: float) -> void:
	pass

func draw_plant_scene(ci: CanvasItem) -> void:
	pass


func draw_sparrow2d(ci: CanvasItem, c: Vector2, s: float, danger: float, flap: float) -> void:
	pass

func draw_scarecrow2d(ci: CanvasItem, c: Vector2, s: float) -> void:
	pass

func draw_rice_field(ci: CanvasItem) -> void:
	pass

func farm_action() -> void:
	pass

func make_decor() -> void:
	pass

func make_forest() -> void:
	pass

func update_quest_text() -> void:
	pass

func talk_to(id: String) -> void:
	pass

func start_snake() -> void:
	pass

func start_saw() -> void:
	pass

func start_job(id: String) -> void:
	pass

func update_axe(delta: float) -> void:
	pass

func axe_tap() -> void:
	pass

func update_gam(delta: float) -> void:
	pass

func gam_tap(pos: Vector2) -> void:
	pass

# ---------- 글꼴 데이터 (주아체, SIL OFL 라이선스, 압축됨) ----------
const FONT_B64 := "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"
