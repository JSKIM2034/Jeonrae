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

# ---------- 헤엄치기 (장마다 물속인지 알려 줘요) ----------
const SWIM_UP := 3.2
const SWIM_SINK := 0.9
var swimming := false
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
		cam.position = player.position + offs.rotated(Vector3.UP, cam_yaw)
		var gh := cam_ground(cam.position.x, cam.position.z)
		if cam.position.y < gh + 1.2:
			cam.position.y = gh + 1.2
		var ceil_y := cam_ceiling()
		if cam.position.y > ceil_y:
			cam.position.y = ceil_y
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
