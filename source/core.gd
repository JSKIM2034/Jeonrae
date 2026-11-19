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
const CHAPTER_SCENES := {"ch1": "res://main.tscn", "ch2": "res://chapter2.tscn"}
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
	if not ap.has_animation(want):
		return false
	if ap.current_animation != want or not ap.is_playing():
		ap.play(want)
	ap.speed_scale = 1.0 if want == "Idle" else clampf(speed_ratio, 0.6, 1.8)
	body.set_meta("anim_on", true)
	return true

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
	restart.text = "처음부터 다시 하기"
	skin_button(restart, make_round(Color(0.93, 0.78, 0.72), font_size * 0.35), Color(0.55, 0.18, 0.12), 0.75)
	page.add_child(restart)
	place(restart, 0.22, 0.74, 0.78, 0.81)
	restart.pressed.connect(func():
		close_settings()
		ask("", "이야기 진행과 엽전, 물건을 지우고 처음부터 시작할까요?\n(도감, 엔딩 기록, 설정은 그대로 남아요)", ["처음부터 시작", "그만둘래요"], func(i: int):
			if i == 0:
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

func add_ridge_ring(r0: float, depth: float, hmin: float, hmax: float, low: Color, high: Color, seed_v: int, center: Vector3 = Vector3.ZERO) -> void:
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
	if player == null:
		return
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
	var cur_speed := Vector2(player.velocity.x, player.velocity.z).length()
	if not (mg_active and mg_world) and on_floor and arm_up_amt < 0.15 and drive_anim(player_body, limb_amt, gait_run, cur_speed / lerpf(2.6, 6.5, gait_run)):
		# 동작 클립이 몸의 오르내림까지 해 줘요
		player_body.position.y = lerpf(player_body.position.y, 1.0, 0.3)
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
		# 기본보다 가까이 당기면 카메라가 점점 낮아지며 앞을 바라봐요 (하늘이 보여요)
		var offs := CAM_OFFSET * cam_zoom
		var look_y := 1.3
		if cam_zoom < 1.0:
			var nk := clampf((cam_zoom - ZOOM_MIN) / (1.0 - ZOOM_MIN), 0.0, 1.0)
			nk = nk * nk * (3.0 - 2.0 * nk)
			offs = CAM_NEAR.lerp(CAM_OFFSET, nk)
			look_y = lerpf(2.6, 1.3, nk)
		cam.position = player.position + offs.rotated(Vector3.UP, cam_yaw)
		var gh := cam_ground(cam.position.x, cam.position.z)
		if cam.position.y < gh + 1.2:
			cam.position.y = gh + 1.2
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

func world_game_end() -> void:
	pass

func world_node(n: Node3D) -> Node3D:
	return null

func bone_world(bn: String) -> Vector3:
	return Vector3.ZERO

func place_tool(dir: Vector3) -> void:
	pass

func pose_custom(arm_l: Vector3, arm_r: Vector3, lean: float, crouch: float) -> void:
	pass

func world_pose(delta: float) -> void:
	pass


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
