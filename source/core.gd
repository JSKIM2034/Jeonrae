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

# ---------- 손맛 미니게임: 리듬 · 스와이프 · 번갈아 오르기 · 연타 ----------
# 화면 위 그림(cg_draw)과 판정은 여기서, 3D 세상 쪽 연출은 장마다 cg_event()로 해요.
const CUSTOM_GAMES := ["rhythm", "swipe", "alternate", "mash"]
var cg := {}
var cg_draw: Control
var mg_lives_start := 3

# 장마다 바꿔 쓰는 연출 (kind: perfect, good, miss, bad, block, hit, feint, climb, slip, pull, fall, round, ...)
func cg_event(_kind: String, _info: Dictionary = {}) -> void:
	pass

func custom_begin() -> void:
	cg = {"t": -1.4, "combo": 0, "best": 0, "press": null, "msg": "", "msg_t": 0.0}
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

func custom_release(pos: Vector2) -> void:
	if mg_type == "swipe":
		swipe_check(pos, true)

func custom_drag(pos: Vector2) -> void:
	if mg_type == "swipe":
		swipe_check(pos, false)

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
			ci.draw_string(font, Vector2(0, y + font_size * 2.2), "동그라미에 겹칠 때 톡! 빨간 ✕는 누르지 마세요", HORIZONTAL_ALIGNMENT_CENTER, W, int(font_size * 0.8), paper)
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
				ci.draw_string(font, rect.position + Vector2(0, rect.size.y * 0.62), "◀ 왼쪽" if k == 0 else "오른쪽 ▶", HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, int(font_size * 1.1), ink if on else paper)
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
				var hint := "← 왼쪽을 눌러요" if tilt > 0.0 else "오른쪽을 눌러요 →"
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
