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
	"mom": {"scale": 1.25, "arm_down": 0.18},
	"oppa": {"scale": 1.25, "arm_down": 0.2},
	"nui": {"scale": 1.25, "arm_down": 0.2},
	"tiger": {"scale": 1.45, "arm_down": 0.05},
	"tigermom": {"scale": 1.45, "arm_down": 0.08},
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
