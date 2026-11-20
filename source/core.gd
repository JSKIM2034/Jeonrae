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
const CUSTOM_GAMES := ["rhythm", "swipe", "alternate", "mash", "stack", "aim", "simon", "dance"]
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

func custom_release(pos: Vector2) -> void:
	if mg_type == "swipe":
		swipe_check(pos, true)
	elif mg_type == "aim":
		aim_release(pos)
	elif mg_type == "dance":
		dance_check(pos)

func custom_drag(pos: Vector2) -> void:
	if mg_type == "swipe":
		swipe_check(pos, false)
	elif mg_type == "aim" and cg.get("drag") != null:
		cg["drag"] = pos
	elif mg_type == "dance":
		dance_check(pos)

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
const FONT_B64 := "eNrMvQmYZFlZJhzn3H3fl7gRN7YbS0buW0RmVmVlVdfStXR19Va9snXTNCB0s0wD9iCbKAjMj4KoLDLzO78CKvO7ozK4IQguODDiyOOAqCCKjisKAtJZ/3vOjcjMqm4auqWf5+/Orq6MiLx57znf+n7v950KqVQqVuUVFaFy/enrr7vp5IvOv7Aiv/AVeLV1+qabj1eqFRPf/wi+d6+7aWl1+aaZZ1Tkp/wLvr/z7vvuet4nXjoUK/KdFyuV4GPPuOv+57HP4fMP4P/qM+79j0//8vrtd+Lvn6rIJ5Rn3nPX00Lr5Z+syDd8DK+Nn4kXlBfJz8X12PfdZ973ggde+Uv3/O+KfKOKm/rte5979126/+aiIp8U8f1H7rvrgecJLya7uNZfsPt7zl333RO9eulHK/ILupUKWX3ec+9/waVfrqzi99/G3q/QytWX/rHyKfrVSl5Zwx3ukLXVOGlQOfLqRLHJIhngqz8eeevjoEGSBrH3Xt7Ah8fxzWrdMiI98iVBUfqzfUUQCCHydwgSFahsm0ajnkoSkeTMCXr0zy2TUHk4Wnd3/zic8T2XeK5WM7xeQK4z+w++TtJkI01CSaKya9k92zGIiJs8Se8l9wp3Y+HauEncDn437iUnoazI/Y0rX7jJoYQMF3xVCPyldx78hr7EGYTXLrdCdRBdG8yYBrWvfKFcE/rH9LOVb698B1YtxgMrqw06ffhCWR3j70pok07RsaliC4q8SHEH7Kvgn8EXVqh8ZRbLNVofb6zGaxtFZ5GO1nfoYbIj4L0G/+za8g4d8c82CMFn6H+SZcmQtKyWSKIk2ra41G+YRRIFpDG75FE8IhFlOwndWqhRqoiiKny7bMiSF/oLvinKhiAoglW0Yi8OF8OZTSMJDCetW0dFzYm8oJsZsmLJL5RkWa5Fepr4u+/7j/0H6M9baTbOiKTKcpwElNJ3U0qyMAqVvGgJXrseClQP646T217Pq65m8YJlyb7Z6rRtO7fVwA+ahLxb0DzLjUwpWF6atV3J7Vbrh+pJPaXJYVumir97+7uhSzOXPkqPCFLl2ZUXVl5ZqUilUAkr/M9y7cZ8zZPRRAgH5TKOJwu9Tco9T8I4iSMum2wxZfa5weR7WZnuhtKRGyQKBf56MrIJwW8JYyXeoeSFWqtdEyG1JDmSOO1GVYYse44e+r6WHMn8BduK1PlQ11XZrJlN31sPVTMM/bqCH2mdqsc1QkLbrVveQhItepsjSmw1NM26582G7LLvI6aqZU57jrjUSWqWQJxGbKWWKQYe9QNXMFTZ8hLXrGUhts50sE/iT8m6KCmS1/V7SVjgB0xXVVVqNw3PptT2qacbthK5dpHZGaWOonr0dXKgJHdv9Vt2qhuOKmmi5TrEo5IayLJCn0/z3T+wEt8SitMF1YJ6RaqsXfpT+kf0M5V65VTlzsqLKq/ne1FqfbnSbMEaQhKzxRTiA0tqs30arE83hH0JG+M4IXLnIT9Pyp8n7LXBOtuj8iL8vVJRRle+TO9v77TSGVUTZWUuT5aTeMZTbV0hkmTp830aGnbd7l/Td5ueFtU6se2T2LCbTv983245qh9nnteguz/cOtVKC1UVZGWeX2XgeQGVFMMYkmVPdRSCFe3YtkUolVxPjXbfphqSI6ie07JdE+aMv5pg7fVRtXWsnY80FVbOspWkmhn9Y0Veoz8XzXjZenby1afyww2n3/IFGtvJbFgbZadec6q+WbMbtVAQw2D3q6qtjdL2sVY+0lWBUMu2Z6L+dd1ac/d7qWbP+86cphJFSR2z064JMF6/RGTJWQjcAZ5BVRPHKDo1/CCU6Nilz9KfpJ+r3Fh5VuWl2LhSUxYne5EsUiw3jfnqw06x/zVJf4ey92DMhHKtmbnnaiNs8O/5Li5SvoVco9gFAr5F/OL8tQYluhEbM2d91xBotUpN2yRhIiu6e/KWJw4WhiIlZpZogWToMVF0jahxte7YkEjHFjVPIw6Ra66cBQOTGoZCg2GtONd2Oq2qTGVdF9Sq1xsODsOHWMG5VrshCFS0nWgzCXwqaOmwSgVBnR20zhXFmSo1TI1Ut48erS9tRkYU37pcXV+dd9VItZMlvGkQIw1UUQyqtWoo2VWLetRcWV9QpNCmbuCLSQ+69BxqhVVHCUJfDvp6LInrc8manwbkCXS27uT1qu6IjtEM06UiqJDKc+m9lc9yp/RQl/SyR3Y6+OmTl34BJiirbEz0TRhMN290mUbt+VxFjsKJKjHnI5OG2nPsahwosE6qKYhUlCRb02PHyBOz4/iq4oh2qmayqKqyo8sJJWNLk6W4npvpSlZdq2eH82TcaB1uNvGXVVdRKHXjVO+d7t5//9a4upKlq4k3DEQJ97uO+22U95vgHqfKvTEerfPbhqiN4737S5ix3TMV8I/9k4TQRNYdWVVFOVNTW7IV1Xc6ZpIbTqxrtiThCQRTVSMLqlu1nd4Yzi8Yeslqmq1Ux1v339893dPT2IXLU9zVJGf33WqM8ZesvlbNVlIzr8eSrOFulysfoCp9WuUm5r+Z6ZH7c2Rv8aZxzRWOuiMrs1x7xvFh0i/VCB9vTt7G4zEtWjtEyFcNQnXDaJjXGokh6XCTopE3aqoRGcuya9qw1Zpoq3gz7AdW1fQlzx56R1zLrElC3fMLvWumpurYZkOzxLCuX+30yS9qtlmTZcEvfDXUFUfxVSM1vaZ3jZ5IMnQorWam1/EokY0F2xCSyJtPXAhax9kKuoHhw20Z/nCm62ABhpU3k7+nr6xsYwESdud8O2hnjkRsNYoOno+ujwZFR2Z6zmVOWEvKfWUxYCwn5NjzPM+2FVn1PYM8S8ATh3pLUhWBXDQcy1Qjz9UtwzLOEmqrdcOuScwjfpCUn4zZJ1/gFfwK1dQjzyYwwU6Mj0FYCbk2WfEMM3Cj+QQ33Lz0R5VPVH6ykkG++oPSSLEIgEmPLRyyVQkrgMAkqxlWLdAkMa1nMIueP6TMDqcac+KCYARVA4FTVVF8T8dlZ8j1sJ+fQHhbIVw+J+tQTIWAhxTxBnm6VziKgjvNcKcfNKtppOHmvGghIR8XTVsJDbOmaDoLbgUNG217bVkjBL+id+n9lR+tHKsYlcpayFYWl8QK/mgvy3rsP/5nv49PDi79E/ll+qFKH8+IQBBx60YxdZxcLqU953qPGbsqDKFKihO99mZNsv3Uy6qS7Xlhc6Hj93zZVtWGo9qh5efOhTdfc/VLto3YEhVjJusu9GeO3XV+eK5nIFpxEdHOVAR6hH600sV9Vnqd/tTS8EXmils6eOYShM5EcaOwdB1MNGCgyBp+a20lXF6dUZK86cZZ6/r24vFFGBgqioZfj/q3r9s1SL8auUHVbMfh0M87ngCr0lwT4HB7yfhN5595l9cv6oqu61Q1tq570nLraCs/NF6JekN6SkKcZHdvnJ17Yt+vyRKuun31uUbj+LjA8nmXdsk6/SRkuxJMwmXcX4hcJYynmgwBHtlCAXfGJfljiikrUeCJIjaO6rq95PmKAkuUZ2I2J4i9vHWE/gGFN8WuanqtXjN2iZGkkWIQWe543/3gqxEOi4LXbHU1g8npoCLTNv145QJugokQW8HSx0YhywWYucOSrSFHiMeNqXMt2h2ZpVHrO2WeICDYKfg6/xdn2K8iYIyqVnrkxIn8+tuc3pEFp+VK9VhECBNnq1U9TWPEfgRRe9/bfaueaD5Je7N+tl0rVhr2znJxJJQN8leJ7vZSt180jaBuU6167y3Dq7Z3elZmia5rI7yBoUI0g9gCCuIQKkh1pzrXaznJYpIvzw6TtY1GPnlKSnbpRyo3M982mto/nhsK3AriORsCe2KW0ZTWn0frkyBB2NPgRSLPEWZktiwiq/FqnnST4qae00gdQqy4Zsab8eDsZrt3/I5xMlpf8kxPcEOnnlXN3g2DOBSSMFhcnHU8sz00lcCzqGD6kXzC7hRtereZGpEayngsPJrsJF7Ybedmsp5I2eKp5eUbj3RUt+qb7SJXJAoXn6iJNZjpmoaq2l4wP9u3lDAMVJXZLUGFovShKOfp71V2KldNXAfyixwWEU8Hy9GR4SGiOvfIlGvRNoVn4Qp1wGdvjFcdskY+olAJF54zUuSKM3VquRYcBWJL35N9eA36M/mxxJeNWO+f7oZzgd2upvO3vvOd9L8bXnG2GF4/vFkyfasFz01PGvVaiuQaf5UHntDuNahntdsta+1Z67XVWjRvGr/1N9i5/qVdWqW/W7mdK8lhsjqeRH8yEzhYJ9x4yIygHG+M2WNN/HSZN/Wn+wj5nYoonrO/vvdoz9Dy8F+tdiORBKL5VraZ5fN1o6MhSocWeVG3v3bbVT1C1Qvbp99yzG8oqpJ4eVa1ktX6zjUXjsOBuc1GbllMGgEREJW+T5Owd66eJR5hUYBATceVvcKD29NqGzdt6L529M6oJg0RfEULhio50E/n+Ob4CCIEXdBce8bLD+X5Vu6FzNhhCY7TjwHQOIM9nMSsgrJDysdlMsui3VIZmeoK7CGnwbAwsXYf10KjuKmbD1KT1C4cWbv9eH/m1FM2jj2lCJuxaebL3c71Fy/29MwXTaRj4Y91tmMb99OaW0trCy1PENL+Kl2ULdEWPHt2/VBem8s3bxyNbj1aDDrhytEbR/N3XDyX1xoi4uakXviiKgJ2aGbeXFTtJZogJMVSLR/ECncdu3RMf7uyXoI0bQ5BcNe4l4nt5WCD/kTlsJ07ZsMjz7Jbli9bWT2T3Fq15oZrieInuZc5ZtD1a0s1tV51hGKrc5c/7Fax/PRXZYEq+tzo8GjOaKyurjaGtw/M1BVVe5x0TnXWnrzmzC0ueNhxJa5GKVKRQYXQnP5BZbNyXeWpzMfwDIKHVZNcgkcY/L4nqTrueg9SEgQWJUL0Ym41mDDilfKzG6tjlpCQXuPo4TUvcKh0dFn0fEcwHckKm9bM4lIAK9kchTOJI4WWYHuumM4joxPCIFgZb1XjhV4mUKfa8WZ6djXyZE1w4lEzmW15hOi2t5z2NjzL7KwROejU8hPF+Hyo2xa1Ot7C3T236ukIrhvx/H1bbs1E5KcQJ8+yQ4c24jj3VdIlelRkYTOxYOwFSfecaORlLjlM9bhbC9p2qJC4m68ibSilswdXPM8sjMTjMDzeKn/StdUdOgDCNEGJuL3lfkXoM0Vk3+3nYcRevLmwEk0PLXg4LRnl7c2BL+XnOuNbdzrd40/cPHZrt1f0rv62eb+way3Vi4P10bLrGkrs2gMaNc1ms2mquqcGZmv9eNsLmls3rq7fflWv1xu87BkX/6+nbdDboJHGyqFDgW/KaRDMzQ0cw8JTbFTuqryH3oigJ6lUNg6EPd6Bv79nGgJN//uRSSxEbpsGRSwV0irv5VdCWBQc+GnhoWHg3gXf+vXjQepPrv3gpx8xMrzq0p+Rz9J/wT5UyH6qQvdzmDIr64+mtg93QT6r6mLozV5TmKlN7OpmKxj4qR4uNN1GPTN+5Wz95Gy20bbbdZ++x6kbcuAVF+bsRqsbFMeayAXS0YxvInpqWB89sXZXcW0/W/MhTHWsw0LlF8n/pMcRqR7+BrFq8IiB7CsOBrJ/fDCQ/aOv+w7ZeoQQl0iPHP+uYyH/qFzIAEI7hXsAG3JglOxns9MMF1/rfh3LtJHNnqyf/RUjqzfc5kKop/4gaG0iPbdTs7hm1gtFXaXvCeoOUfy1rH9tcdfaiY9ajTxRTH9mlAb9sHmsCLqthj13ofAC2WALuX3pY+Qf6VewjNfwzHxjL1aEdi4r+/gsHU8xK1iovk3LWA2GJmQJEt95yGESHxOJZqy2OqdPXZU3m0IUEW8+iFVRSJpRBABWbiVWFruCYKad0J/pRITAChh+txGRPI7qtQj/1OpRTC3gq511x7VUmOHT569p0aQXJUt5fUhItRg4xVEEZPVWFAyauIiRtEKzmsS6R+Jit5kncZzWm1GSxHjK0aW/FNbpP1WeVnk+E+DLTINQyjGztszSCsUEFBL23N0kfBFG/G8dhv2wt/rrk7WKFCbwiN1gk8mY3ihKer0aiQCeFck99cRnjw+fL+TEHZ++cc5Ymq3qyvxo5Fz3htWVRUkMu6Pu7J1Pf9bo8M1rgaxsrGtZo+MbnqkgYlGzel1fOtSSZXX95LkmQSao5bXoPkGlSnN51XLihTEZmHU1FJ1M8xcW54Ot6+eEILpw9/M3hzuzMVXSzA9UQrePbr/t/MzFa4/DdQLdzq572ouOHfq2lqwTzVKTCOFtVYc1pvrS9tXF4omW1hBMeARDUQLnzwEjdkax35vZrOrcJv8rfRP9IGwayjM9pls8JBr0BwdEljuxJTjWwQEIdPqFhRpME2n8uxJwi1H+MYYM8X8ZlhAwALK8GP9JxIn0jUxgdKVatw3KQ1kJ7lcC4EVEEp167akIQR+iIgEvyVL5CUCfVUUXELcCB/sYIDP2M0BWDBRNgO6r+Bxe/Jgg/B+r5iCwwHtOzfJ/9qRsKKYuaYItihplaQ+RNAlfoiJqygohK/gw/l6+SFhiRDURIYwm6aZiyJqm0Yor64qly7qkSvhH1Uzdgi12dyua9rf5TksLNHy1dvJ5jvP/M/XpbyI+OMbRmP0iUjEJOVFbYq6OBwblKiEH3bcXrMQCzALmjsGQi3gTgXgUNkq7Mu6Tn8uHpkWaJ8b5hebgpoHnCGLSX87CYdQ+3XI8T281xcH/ah4zLUOKvGQ7txNPxdoaxuxCc5jAiGWDObc7EMQN8vxgrTe86fTIUFRCVKnq4nE3602HmT3NlDTVzK+97szun1HdducWhqZvEMm2s/XUbhuGSv4cG5kkQc8PA2Sccq+7wPLW4aUv0TPIKbYgWzwSZwGRsDGpAE2tzmCRTB0QM0wMSaeHrXT9RKN99uypvBj4BCHl3JFh89rrTlfdwnXaduy7Snrs6IbjBgi93aXxRqYGYWT6cz+ebyx2kOl67TS/4YlPGvauh6L4llJL7NX1BVWULF/LI2PY6txw04VG2jBVW3RcW5Btrg5fpJu44VmGFpA9yJ8l1fsopbfNZbvMDDeYVZkYnyIOIznMUeFCxCpJ+nh9/LqTyVLsa5JMWQID8YWIyaYkW+q7jj/z3OwvAtMNfXt+fCQnpLk1WiDf3766vXVvfybHxyVBFXREITLKGfQwEnobO4EKIRVEkW7ddt8/Ny7ccG0jrjtyPm50T7Y+QiS/zaCfS18lD0KpXwMvoKxBCRFTrJUyhgyOaSz7dw4amADT25c+JWSvF3JHKeRBpz8LQcVz98syFPsTOn6EbDBNR2Y8KlcAfmJ0iI75r4lXk9V4/9dMFg/Qm/KzdGZ4bCCZiWHGhmcgBTQk20IFYOm99MNLqi2rloyAjEmbbrpR1UgN+cLFMA1CF7C/zLWRpfCE/0F0UVMdVwVMEKXRzJm+iM8b7MLQbEPUZNnCBdWF36bn/zP7uCTIpuVKlmRoiiBCtz/IDAAVFd3A6qLeKmo8j6a6YmKfYIYMbJ+EqF+88IZXdTfbkhHoyJZN9jn+D8qTpm3LgEANmBu2s4Qv/Jfx3QcqL+AZdFgu9HQJIuUQ2cByP3Qz+Dqx7ZhmpPtGldeZsAcbo6NkvM5AytF4nUvf/sLvrTv5N40tD7NWlirbysL/JGpgzxzty0ZiYnkAq6I2gRKPpSiWuvjLDBlCtiMbbi2FYSxFdPoPW3BVsRxPlfw4TMPrL0jlVTz6TtPFkxsQTf7gwo+yzwuijP1EMVaFu6NsI8nnVWZMsdESSlCmoCkilcuVVVX3whtax4vJ0saepxxYWQ4t/hPdoh+uPAmWg6NLwmWGYx/J3rMdcZnAHgEkwUKYPYdUghKHy7iSi3lEt2S/23SGC/PBHc897ElCNDwyO3jSE65LXEDJrX4hK2GUjlbmbA91DCye1uzPBrVOqFihFEe+puNxdZlJLFb5CUaOD1FWRv37xpGttUC3NIEINzzw+mP92248jjK/O1tk5zoADmpRMrAc0e3E1cNHj+Yrc27VQakzafUR9KASarh8/eDt2PopiqhKBvZS4qL1RSzIb1e+k4kWbIww8dRcVJh5Wp+KyvpoDGEpHHLFJ76OLE1C/LVScdm/uDoT1VXUArCEezWZvY+gPrlJoJIihVvw64kl0QnAxv4Y/x7df0vXIGCU7GkuR+EkeHzXVU0ZYJQAmIiqkb3+jK3pu9QAQqVaqOioWAf6Jti94YNf0WE1DdmU2X6oJmU1H9hFiKACrPS6l5G/PfgB2eaSxt5XNee6N7VOdrubhahHhh7okH+4OGIomqWza7+D0IUbFw6+R3X8rIFFv/rSFyt/gEVHvnqUYslg+EvDNz64GmVKwrdEPhAUXWY5+xunJ4+vK7brwNohjJBKNZG5GgqKpPq1FJu/Z+vIsw7euh/Z+t7NyQzeNWQPCyNocukiyqWZ2K/y2VmOeekL9AI06S4mOLwEshe7oSQixyWQMi1kMRxiR+gjujhCxiOEzx2AfKMpCeGA44NG7ZszrAM9oTMjYAjgUJiKYipbRJMFszbfaZ2/9urUilUzDpp5MxiuNyyhtBtyf34AMN9VA2ZKKCyTYqv4ulN29cH5royiEqge9N2MayGhMiqVy+Ld8Qt3NI5uLFqmrmaJWQx6pmFmdVEPZrd3DoWjp49Ero0EYgjliVUJkoGbmSwqUUWuT/9MQ6CFr2GhycRKDzr7Xn6JJhwrnOxmf6JjfEuZiq2Plsg6gweZDq2Xi7I6kYeYl0MTrjZHSRkJT5PDJNxbfoc2BB4Zs9fx9IpkyrpsODLz+RIjQaii+RtYK6QKimg4TtVCUggUdGIpmfnGIjuqo4HUYhlYH2aQidt0aqMaqvgqSk6B5igSisqoMMq4oCSiDv0+UD0yrbaaCnC8zhkHnlRS4LhEUDDYZyRdtH7ndzRRA9tAVkWd+U+oFCRVR+yLqiqjZ1z3pmPnmGSCAhWGjiZxPdew/aoDARi+2G549VEmgGUA2w6ImmmqYhuIpiX2gKpk/brTbta0+kad3arHob5/Jl+m76+cZntSQrV74UhfXpxWOQ4EIBM93ItgePglJPuvkS/BEGheGqGgKF57Y7i6PFARhE1iCSye5WPtoE8oufDw7ENLMOmwTYZinJcCGQsEk8IVV5CCCP6sc7z1xld3NzuSHuooQmrMb8kSIgmkFxB9yd8dlqZQUHgZ7tK/0NfR3wHXp9KbWmNegTzCEXQ8yqBkUTGxC2WG0eK/SaR5lBWq1g8+JpeYZKd0hcK+0WYmKC6/6GsJ6uGq4diZYVtMWOhgDVQZ1XUsMd1ucTvk1roRkGhufiRRhZvHMoQ5CtA+qAlDX1A1BZSnpOopcb05MdaiWMYFZ8zMgKgyV61V6w3rwltd3wl8wWlfdd0cihuqacmNi9vk2FPue/JRL/dh0RuWndkX3vbqWy8ageaqWDRxYGvAZfXZq6uCAUKQ2yxma2anlTAbqWqWhuXcfM7myTectFtcNr5IzwLavqlcx4n7X2L/EyaSgrrinmcrzdTBqjwSUMazYR5tjxrCsBofZQ56hiiu2cgztbOVX/T6Ie5Id6vtQOGCAtHWRM8oLOZvNKaW0CXjrwg3xmmjYcD9S1wdz3t9UxcVx5i9feHltRP57is1t8m8nFvv+d6FN7ZOFHN3ziYuuDwiS3Th4LmqS+7uDxxvnQB6MOvFlisDpoWC6Lbx0t2vvdSuITNh1bcb6G9VGoyHEPBSBd3zNtO0ijD4mHaUCaLc4Jbnj0/cd8uRwHEFDZmqUb1uqXXy+JFqcyaWgbPPHyWhiWdrL2z34mZgsAQ79LJTnY3cpP+tKq/cuNa/eNP1naQfzI2R53ntauO6W2+b6V28cHT3aUsvWm+tZL7RX15Ps62ttbCRqOaRmCdSD9ICt7vNCmkTtl/5NYtIeFqz5NnUAdIHyIGX7RnbIYVhVICFi36nzK+iDWDF5I/7XVFcXZu5sBTlgRiIghYYLcsOZFGhvN4H4Ywi2jxftVMDlAPd09QAgYa9QKL+ciojb5ARYoCBlR5a79FXFXctL14bejarz5OPBjMGonpgDVri0SEkES4EQaykTmJkHvAgBAEq8DNpN7W5H29utf2uR2S/w/br0r/Rp9D/AT7GkzmwUmp+GZku7XNJhQlzDJvplJEtPrvB/W1/SvhjSNxkPXb2izrYYHo7u1td0VXYVVMz9Lo3jFsnsLuNPttdv7c1vPt188UQxXLfqYmKtfudjZt7dio4IFQJHMUAfqEjqzRgBFAelRHpnxtFeWgwXx6eBhfDNuCYIPOylroxgBe3U2vecNsdM/3bbzxmNgerM/e+6NvXlu1EUpwnD+BwYtEBNc81RFayQ0xTIiztc9ecbfVrmTFcG3NRmSTbC0hTb6ncw52wXeaMgzLZZngTTKVSRAz0kC+HpfpcbCZKjuxn3wGUn2xOKC+xAFlhRRUmPHJE5wm7J8BkjuqanoFdfS7Cj6gXBmxTbTNqwBLJHHJilhGrXE0XbpvPr6rDwBlFd22TKvSJGnwlICnhy3675hNxeyU/BfrnvK7BWbKgDjkoItjQ+DiPiN+jArJ3FSNB0Ad2Ks+IEBdvIjQxDEABPPXUgM4ZeuuOxfEdMfb0va4IU2OCH/UEK8691RVKhzcf4kXOrwCg+B3w3phWhfK0GFvSRlcnTw1W7Tq3CVOod2ovSj/DCvWNSYmJLgJREN07v+O71lqLLpA039WrKYrqw6R9YqNjV4soXVldThaXtUa7dfsYGc4Kip+2FLh5luq164u4XwMVx6s2nIU75uZ3SGEX3cLavKaj1/31lgGME+GLY0WFYYjZQp42I8Z4QigRXLjj9lYOCoBsx47e7nVMXXBCNbRFwU6L2I1t8EBkzzvE3eiD9AmwJ7fyKPbyzFpmhsFmBLSEJ9Ts3WgvL2JhuDc75XPjm+0D8CTgjz3yFr2eCT10qQxC1/zC20uERUGy45qngZDJwta5PgRDjcBnEyzRU01fdbXiaHHo/i0rNTWXvgOJMHZXZzEndrN5+skvufG8Dj2QGJSGQq+sazAwigad1fQyQWKxKiy/KZmqoFFxkjKJkqDxx79EbwQudTXf9gPkMl7N7W8zUjC3FZMogUw5LFPTStcHnN/EQ81zcFfwQIHhLm4caYyeMtPohhKjAahaq2jhPtn9UDMOx7XqGnhrVJTxkqY2sihTNfr65Zd/5/1FtODXhrlLYJjz42cvDIOtI4dCq9nMTQtos+rq7YvXHXe372rlqA80G0bd7N/zrKcPfccKSYBKGnPpX6MvASno6gnUJpRlE3HKqisj6stceI0cJAhOHghb9+0SULVWq6HrcXOY58v9ZhqqzdVM8SU/R6KOfARBLewQyyEAD7/hexUWBEoiAl4BmZMFRE4OAvoDyVIwuPPOm+vZ8aPrpmkVo81RcPItp8KtrSWNkWVE5ld0MHrYl7d7D3mbJxkKS7dgQWW2bXDrKd+xf6RfQtr1sgmP3iH7oPlEZYUBf+TS2tEp/XtjD1aLm2T/4YVkSpbifxemqcU+8YK7iZh+QWQ8AmIXtgkthfEO0pqbJgiwwL3QfNcS1KDWz0IVWUE4VB08jKLJTMhhbhC5mZYmsfwaUqllhmiapmzVXJRQ64GX6ZrnueDiaqpo1ZH3EzpZRlW0dct0LZ2+PYiQSIs7rz2y+sAqOA9OYgiGt11VlrdGVrw5ntPD5Q5qIjECwmv+a/OqwmsPVtsAgRwEQhReSAXFAbmttP7UBX+0tQ6rspgOMlVRFtN4ZWnWMeBD3fF9I7bwMlt7CT+HkEzXuUw9iGz3I5UHmEeRr6xlLF1RuhhMCq1lora0X6bb973T6sXU/x5I6TYm1Y2p43Io+xg9AVqwkNi+6eg80WFg2Ku+mzBvCNCQCZrlNE2ZgqYOgbRS+0mvNVnpAR6ZAQKCLsI/uNip0IUZItVhFeqHr2QupcimQBEKXNSkQc+GqEkyQCLBfN2Txpr/xLAB7jssBqAEHqWCl/Ibv4HsUWRpn8TkAliTWatnJtyyV4Tf8yEP9QwYHIYbALVCIQUhvmkF2A2xfaTDwl1d6hxpI7U2AjSwYBMAmiBPB6sWdQ/vQ99zHhVcwoOdE8BJnlJqcmmbHcGTSwQq2kNEJqu7PvKW6ART75doZjJV9Ydf6rJGQo8znBEuE8GF9YqEToldIBLVkcPKrHBE41eiWAPqGnPEiHkN2zeQcHgKDLuQziYUi6HQZBaLaalW7HoBQEtRpW+VdNk2bCTgkvfefPdL+JabavwDWAgShohc5vE/8Tq/7GumgY1E8GRpSGlxUcXVdM8QW4c7LJU3aGe7JWqB7iMvpzq2j5txBPFb9FfRbFCZmINDQrxaYvBNsrwvTGz9ijYYV/3OxG0NADxsrPevoEgfpfudNlP/xuFhwPEba4y3xsh4Exo8de2GffSlO46LGtrKMFvLmDgCxLRR3BRVFoxo0u4PIuGFIIrMqJk88cUaMOGFniPipetPiucSr+4WR7avGtg95gM13YlCcLmk/P5bAcQnaxFQApNYIV2JZsI7fu4J3J/gElpYVQyGU+2hzFhjnfXd4H0k4QLjkEBWBSjG2e/Jj3ayAUsHCUIjA3UnpJXqBEukJmojRqPVwKq+/tKvovdGQqhdYf5vn/DL6meCfPjgiwVLJcq6G7nD63KGLgseFoBz47ozcxPWbrOZklPpTM3xW/NVxuCc0np1P7V27VP7L8jp7FaL5s21bng50VVilBaEnmsTqyJwkpW0583Ii7+VTFcGVv4qeVq5DAGje3kMS1BmyR7hlXHiBgICwzly8NW1v6vOt5AezKSnSNpsqlgnu/DmZhhS5jkLxA5j/lrXE6Swu9Z88LOtrdkUe6VKsR4C9jhFvmClvr7/Am4mJX9Lfoxe4skqL6CBUMec20MY/mWDTDG7Z3knVFLyfSJ8V6wanq5aKBYheQtmQgcU+ZrpJHp1veobXRvUa0/XQfj3PQfoEnPqpuxBSgmMHgBd1ajp1bnETxHSSWrN7t/Ur7V1Az0vDcDLYSzBsFEZ93vo0tvI31QUtDRWegdI4wVH/qYEk7cdoHR/HhzuhFO4xQOkb5ZEYN05HZwn7SKtkvdXOhP2WuNASxELxSfsQ+bMkwkBJ95hBHwq/+fG8au2s6wui34UoMEtc2qxpyTjfutQe24jR2q6uWO7+NX6ctZYSKhrDubnyDscFDqr2U4/m5+fT5M58OJRS2u0Yfw1Y+PsxeH45N12f3bWtdHl1t04mgU+cXCjw0sPkl+AAR+wUm3ANoYCSJMZ/5NVAjgLqeRmjQcs3AzGkyI1copIwXrN0mHf9/DUVdBSN65bgdp2dm4d7xyrMX39lY3IMCmqrPVGJwaLLKAPdOd1Kaw1ndcBLrRIa+u6pc3r16u0c/GGC2+5Vo/rg11PqDmzswPLNLCsD9yEpWV1IdBzf5x8GGS7CarAmUpTihhnbLP7JbKyjzFMc+yYvF0lqtYONdsJHKew40w1sG6+1wH4AyIjclVzPkwPZ2Zmzh9uiiZgkc1OcQG24Dvtlu0j4NFZ6RJkg4W1dR+daHDAkkeDWsNwaoiTwVIQ3cPnLg4H4yJCEhFYHAn4CvlZ+htAbhYZvanBa/poMmXi1eEBSLI2YuG7ELP7B7S5yCta5M4AdWoYP6+zMbz3pSKtb9ywviH7b482jBARWLFVd1yq0/dJStjwVzej3d8fn1mItac/d/n6rSb5ebdZCx/83zlHiel7ZSE2e8MZ3E+BJfw4GgNWK8ch7JzzUvK3D3RQlXJKeVAud/A6JyiOmX/hzkk4jN0nrzSrkW36sZ5fMzO+G1iebox6C89b64xBB2XL5NcHtXR2fikXvEbf7+zoQYTyfR5SHcyKDxL1tQJVA4SCviVa8E+Dhfl7lw+djTOaOGtdLcvrhh/ymjDaDPNAJ9T5SMy64JSECZMdlCVXch99S+V8KRC4u46CwherZId7OSB/sCOoZo0W95teVsdrPIzea5/klF+IPEzzafAe5brbhsljgLseVx3QfMtgI1kxkA7JkhW5NEFKANJ8fq5hoxXSDLUg9NCMQkkyIO+Sak5TEclfpVVNl5A6MIAYrcI6RxGFQ+vPW0cVSsZPiKzVrnNyaw4hhSk1fL+B34qMBnCuUqWsL7d3qUY+TH4Ce3aeFUTZs+2zuRjlnEzIE2RjryEXmluWSldZL1y/RAT2mBaEfJhV10zDXu63NlvR8mwLJPt63zMX11dsdK2tPfvWkSj05orbhunSTEu1hPfrAcJ/uGq0VdndbttgmKJpL/9q61yr0ciOZJ0VMJTRMpAVcQ1sv6ofi17kbNYiY+NJh9fuAPHdrNdmb3wF4NOw2nCtVh4LqDkYmtWfnXFDn2/nLvlp+vuMv4wSAC/70jF/RJs6ZEJhnmKG+/gYp90BD8HusfIlb+sgP8ViF7PKSi5s34wsaxcua9IGAbCRcxAPkTLCPFN2bBk1EiZns0/s9ga+8FvhnF9bAP1F6K+s2vHWWheWvdYHYd8ftOJBTo+ymoHBtpIFM6iVQJClIAwkqXW849nED5YPHS/7Tyo/jZCvBZojSJ5xfa97FFRApO57WbswYK6GbyQ26Z3lvUdNbj8p0Pgsr8ksou83h+iMrneZx4vJd9SvvuZs0ykaAaGrC8n2zuHUnoHRVDWgUXEt/zU1z6OWRy2z1ajidjqXvou8mL4Pjfs7UJiDvzGpCxEvBe6ZgVKi0Cu1LUxvlC3rucasJDi18gYCIjmteut8Nx7aPtKSwnMbjQbIltABRbWG6HMCnHZCa+IuXNxFs5H9mnn82jNB4+TxrSACMSl0g1GCMorqgjiodYZDN27W8shcHi2C/mcoUVrlcvE18mo4qPvAueUx1H6L/iRwQI9gWKYawD72S7DTfGObXC4xZes0E5eSsoP3Jvk0bweS/iGONFGPYz9BR3NSNZNZS2PJruKqrPI2qSWCvFCHZRB4lRv5mMj5DZYMBnYZqqoumtQNazapLrl24scxmCvRXyaRTvUo8Zdq4L2Zmrdg8ksg3RswkQKzQitr6jCUBlhAjG3BbAaICyaXOplTL1TNDnx9iFxtuyiOos5gqwJ+2QJYC/XaUpiAoqlFJXoEGXx/ZYzFw+IogJovQ8em2jS+cmkUVtZmRaX/F5E6oA3JSmuIt1gmycsigmrCqAFchvqU1e3rcecRrCOzdaCPoNcJJctlBpewyqGGz8B2hJ4+oyNTKjpHm3+AUF/nVLFdVGE+C1YnV/z6HkQOw9Xf4A3SNmv+BD0BKPV+BYhHJBNUk7V3sASqMymw8eaNhDWwsMdLph0e9GpspK6bjSxgRRvZ1OLIFSasFxCDa+jGKEvwaLQd2qD5EENqFg2JOQNVabg+to8YzfzcfNhMVxd6SLr/urXVMjHwATEw8onFxWS2H6ygyxkNYVbNxJvg7uJNAQ0xySBOVhI02wYI7xUlznLrqqfkjut6xnB1LXoDmhZRhwlqbafaluz10NKI30lbF0oSCPkt8tdoWAfhuF/qY1KWAVlQCY+xVw0qV42lHHWCmkl96iqwYkOiqT3fxwQFojdaudq/Bj2nMJFsWIXlRAB7OPxNycpsaxm2Te1nhqUwwiS5J1kH414S3AiUytiW2w1/MDsXHztqddpIkwCS2mgHzc1gMVxaEcW5jhXHmds+m6QQEWiy0d5qsxAEvECdfKaSgmi3HxfHe0HbwwXEP9E+c/pEPemoXprbw6RxdXv7CRue4x4547iiYerr9dZylXrm3NIi+aBrq41aclVz43nLcWGgZVQYX3z25vY1/8GeXVjwnRCxxqGTdaD+Dq9DuGjd/DwMNLOJaO4qb4TVHQ7gRCUDwlufVhaFhJOnOwVELkLp7Vi+XARkZWP29mXgMgxzSTOXxTmlZEnaZpGuLfVtMeqvpIIFK5KszTfJb5oLh0501u5IPU/4JeALQH7wp6kQNOXpFrMDC4AZTDhT6Lth/kl9UEW1CSjDCaL6DR5e2uRDuPsRk4qNA80wSP+bzLx5E7T8Sk4K9IPRo/tBWQ2AssySN26h0jBo2blnDpbW02LMkEECf61qbi1G+EJ4Ik8EJdwIey9Il/sRwN2FtRQ3Z5+sPnm8eFvLjhQJLbIkqKaoKT/4cTyDDgYH+uAtDewUmA24Tqtm/xDsCfKkjmAkA1QV0U2y/NRFbgm+QD5AvsynskxQbabDEX8ixracsGfZE0XTWjm81BDBuNoBcQtMs2YrowDO3E6maXYnNBpGZz2IXeIUbb/ObfVTzWa7iRYzYie564Ym7K0qR/W2XyUStSna4734DbVDSzklbdeZXVwKJ17o/yGfY73FvRKs3REmfYGM/tm3SVwWVnhlYhJrwo2u4hlIEiytLAZD1E4WNw5lXr8Nfy45ieVkWc1JGgZ6WRYX5ry2kx6eyU9cdRi67LVCd35+6MT0ZzBlwLGbT1hMmx6qEYZfC60U6AGY3Trxs4ahm6Zr185cjR2zG4k7bIL0G5ma3eOgxJfIJ+kbWbxfAu0F0rvSxHIuwpiRKcp2xsl69xm1Zb97IIw4oZ58XLU8rVF0TGYdwchprqGdkMmEY/Z6LVh5DUjF8ZyJu2k4zRrKsiLRnZlBi7w3WAT8KdLG0e2N2Bl0ayLYblbRK6zZZ4+hHZrVqEWMDYYgExdrQ1TMxDbb3a5DRYc/xBe47VtlBIApZQlxYVn5GPOGRcYAZNM01ifTH0CV+QAVvaJVP3ZsO00bCF5FRtxsrJUsq2hlJXHAppVaXfDyYd3/vn1iZ9WBU/YcZ3lzOzt1wmq3aopbn082k851O01b2dxID22tWL5PXN9d2TrMxeLfyF+TP2W5M4mnrbDQNpkbXGHaY7DP3ZhMvPmcKELFs8Wm7PiRCU+pm5EP9kyU1AMJIQFYz42GpoG3IQPO110HnVpVX6s3quQXzUYzN0ZP3zbbzUyW0Y0mZ822mcwsHZk3s0bTdXxMpEDJrm3mJ/Ok2ejWs9VAV+SAL+U/0gfIn1QuHrzfyf4PJk11wn5eIUzhWKF0oMKUf0Jj+lxNQlXYy9DL6USOV/VM0UJy6tuiiW/SouoDX4swEyRo9sB60xHcOBjPYCBM8dAilmE6i64iRFJU8IoA1qJDN6uR37Q2jh4JF69ftuuxnXZnnPmzeX5yzpnrIxzurW9GteOnTuVBy8K4gEbR9fpzSTLXN5v1quw43aUgzFM0KsZpHlqdomUYjqDz2ukXyafJp1lzTK8hTPzheme0V0ub1AImmAHdL7rvNdJMG4AJud8YFIB85lNvftgCfmqrejVvOmFPkv0GSp2Y19LK9TSExQtBkckWYxhDyVHDYdXKMewG2HCiJx1HC37dhsvyMtVUZ+YHjHwPBYDQyWrkR4tzM44d6U6vYdQaLc8JFFkLNqvgdKmuka6DN6f4lttq1IzqjK8nXBZb5GvY29t53YllUPuVpwM1qNIVTCtHG5PiE88g92pOB2pLE1CAYSj/DEOOMRQoa9iZ6+Y2Qt5lK7ERGyk1pxaailjyIwR6lvHI8kYLTROIBdUM9BoPGfJMuK5aCgpPiKY1hbHCLFm3HfJrtpt4EpRKlJqH2q0jOYr0z0B3I/yHmRAKnpbGCNeMzPZfGCX31KnjDT1JUtOxiKn788nMbbPPcRu213UAt+M+JBaRgrnGV+VL8CmfqRzC1rN4MC6JBqyteTqv5yiZYqWl9zxEWDA86SEGqemQ0yty2TE8fzkcPnFoQ9g01Mrsgf3Se1BTQbOdilBJDhDkoAl+wfa7rQQhvRPqP/wAzKGeDQ1EciywkgA/DbzqsvdjIJSoWpImjDjA07wocfJazfxt3PLpCap9/cOg2gjKuSByMBHx/EMhboAdi3SJ9FlSI4wGD493MwgDjHl4idCSHg78Jkhr246oFwA/CHk4KPxMkqX11AtdzwrjuN14wpXI+M1uHMbuHID8JVDEfOvuCVD+Hy/9XWWX/hsba5ZMCqKdEQ+w9lti2HwDBPz/pPhhhPxQJiactO84fTT6UF6kRjbBScN4K3fpK83UN0AzR31jzt5FT2czxm86hoX8sXIhOS4OtIwX6qANAl/Ih4DkYHbyBmkGzfKFvAIw/ysGmBO2OIUuOm22OA8Hn6NFFw0byCjcCMv7sFj63fAjgbOUDLI5vk43XwmtP6HRjuPQ8tzQwzpnyZmHIO0LZJaeoyJDmKfjcorOFEwvSi5Yf+NyEuraXvsKynbQzchsz882nboF+kK11mprtg0WSKKqw2hupZ/ZVdOoWtVeyBi3lpun5MdRM/Iadg91YVS9VA+9FRbguSLJZtwm+o1VZImgn0LrLSNEOxDu89XUqPwD3a3UsA0Q2rL1vAw+GDr7YQX4GtJSdGfEtbqmsLiTEXU0i35FCuJU04t+oWNAGLxab3Zg6LU0gM3BhW+hXuV9AuUXXmSM9XHZeclUIpza9qfKfFQCKx+meaaAsAnuHuaKaTatymEC7S0GuDwGJum4uo6Hd9Gqg/DavfSHwgBTwq6tfBeuH0+rxXtUTPbnlIiHcLt0+VNWXtmntTfWbYeuJhxfUfZ/ahoZ7I0NG0/JAfjzM36A4mx1uSMHvi1AQkIbpbbqoNONw5quu82rA5NIA6U7W91YX3Rdyz1056aOgiYFFAkoQM07XccEjuS5w9mZFypRsnBhQW4WHXC+WPXYdd9heEBtgtmF1bqRoqvYyo+0gAk2ruubNnjl9iAjXwAAauozTxvrCsrs1YX5udgFG04WETGlja7X2vTN0H8fmji1ZqeJjEfvHQ0BFQTa6J5NWAYz7/Qjt5E4zC0smvgfOtBaRRdW0PPM7o1bzwdyjnadVqdlrd41l9WtfCU3HcYqgPVG5/Ktq3wEyl8IMfbhydNOuv3BLXJDmDCbhL0Kktgv92kvkKGNsg1UmA7XAw5QRekbI9PUKHQFtWYlK3NNUcR8O1NyDGgdID0gyfGgzkixijZYWhnEohgZzPcFWW6qQYCOu9rC1sac5gasLdDzke6jxVxWQ03RyRcpG16kEhTs1LCpB50mNGzl0JH1HqAE02YDDqFG6HFUDFOUkmosOdXGdh4uRlEnr7k6zJ4ZxAYPVb2kbobDQeGYUlx42SgLMqzKqYoKlsnHeGVhEr2My0kPk6Busix9ZlTx3ORH0A0eKf5OMXtsPvYb/bB1fg7qlWgKAHVp+dZrtnyTdE5tzmwOMg0a0u119LxDSHvz7GBw8thOc+3iPHiVLtFsS+xdfMq3bQ/vuX076S1E0BX70qeEMwIqkZXXws+WqFuZqrEvdD3yOiDPo/cIFof34w2eq5YAaTmnqT9ib64e4PXhEp0IQGXMMz98aplBHd4kTdwHggF64GqkYF0GDI9TLGUJXBRU/CHlyJg0ECACJVqMf8rCPjoMWuOVbs21PM/CsAjyLlQIAQyHVYm1+biLLuOMi6BKhjTNHZTTVKVmxI4tld0trwfFlOy4LU/yOTZGJ/0uit5wgwDqwgaiMNIg2j/qHjjvu79McjRf6nHoMpfaGpDnlYQvlFS6oMizWoOE8S1ta33VtpqNmoYZgll/6NIbiZdUARwhHfREFVMSVT2aZTCzcunvhIuY5bJQeUblLSzQARpep3GJ/ZSTPwbb09ZSGYN5GH7BdiE4tDe5LFb2R7zQMR9MiCbpWSqXo17onuNYk9brNCqHgzJMDj9UTGBX5n6EFa8/3nc59HtnB3i6PJFQ3nbUsv0j67ccsvtmYmFCD4Zp1jF4BFFzTeOMOLRJo/6DMhdnx+m2z4ZQqvpc6+qebbFqigeXhCmI9BYxTmOgyBQtZst5gvmgaAUO0GKINjR8ozdQRme8mi92ky3B8zFyMjaiDBdww8QQwyhggYSo2foAvERCLoEaZ1oDd+6WOZuR2WwwMW2n6Pe96hhukDUJSNRPM9CNWTMOPUcyOFm+c45h5DqIdNdh+hl6GRXZ9yyyI3ZN5LUhglk9xibJlz4nXI/C+AANOd/HpmGh0aY/mTwGixZOZ9CstZdZnMp2jjyW7SGXb0bJlp1kNMpl+1Z8ergKacPeZID/1BLYFmoYjoQ6GPaGSmxvdv/vx7I5N2EHMBjRcyy2HYKsN71cLfuexLgaizC8lG1brUjeECfltkTYlrxdZ0ARpoHq/ciWBedR7srup56ATbDAa5LBeCPnpAKbgCoK3wXjaXR/u2TsiXnpE8IFKM7xykswz4yxtcuFb09ZCZPhcIdofIisjSYv98t2RCQKoPAwXQtL1k50mTpxSHa6X8wcIkCfFR5mu8IybBtdpjeX75RCf8apSkbPrBq7S+EcNJuD1Jo96hIl27j7zc/ZDXXMSsVwGLReuWBuOpp79HnvfunaGOBQZu72/lu5ibrGWOx7u8gKGmwTNW2yiZZdbmJmsk28ptH0DDDCDygTuUzpFqHCXWYJST3x++AbGJ5E5gCyo3KianJJji8u2Bl84RL9QLmXzvz5OavZumwv57GXAKHLnTQVvpP/cEM2UMxCJXP7mqR19BsuU7mKeOnBS58VzmETe2ChvaHyC0y1SpxzNCn9rLX355uU8VrR63cef9tXjqhYW91oIyBd5VdgvZpKm6efEBDgzTez1mO4KsF26nXyiWDGD1lzDvhWrMSSGA/+q9X4h8fTOj74p1A3jeGxW7YFH6mzbi+lqu/+TTwbg/OLm/Gp2sRoDw8puYuBI6wK3Au9hcUFTLgQmXcU7MfTdj74U5I2qbqBmaphwqla+ljW/Ib8R4T/+xz3f6PKcys/UvkQHy8KELZTuj5e/p9UumBqwIprjybAYcjbIPk8EPL4i0Onz8jZfLpTnBwi49UxMx87vJIFsZilaLynT9WO3vLUW3bUcN6DGWNbrCDNKkSEZOSHiOXbswabzIT8V601Grv/5/GUjd2OBpyASJFVP94Q2svj5Tbo8CaCdiXQ6crZm86spJyFaWkY40zO5yvUrsrMwlhhBifS8GPwB3Wtai7esWgHqNUAwH5cReU32UxD8DgnNT2koWhKZ56tIsBO/Am3E6fRSv1zrCAq7E+wK5ODONkbe1TSYMJJVbwvT4Z39fe+e/zNx58ZSa3hRYoZK34nVIM4c5w08JRu22v67lyTf5POJTLrIOl4ndXECSxMcOM/5sq12cjxbS182uMpIWg49cFErrcaRn64bmSYQcPmOuqbGxj7k6zwIY96cbarocipe4oRHmsENDBTz8kBAMtauJWx7+v0g49r9MWcxKf55gfI519W+X5s/3qZGU0HOj7++s8ImHyyC0I9DjKeG93x4lOnXnzHaPp/4B6P4169qLt1uihObXQ6G6eK4vRW94GFbRQX2ttrq9sY5dLepj/1uOrmBzxQugQ99ICMimp0IPy6BX77l3jewhYd+clkMONovcSvDiPQYkjnRonKTqaLsho3uApjznaOMR8w3iN0sQCOd9UhQHs8g7Koh8lZ9Za5e1M0SONI5L2golFbwExm8UPrzxyZ3W5TgfDX1+u7bwFLA9iMp2C4HkY3ktSo64YIMr2RjaLdV4H+QSXGz1ef9rjEavNhBqvArGLhgwEe9AKvYzd46zNKMgUtQXM15fYbFecZdFiwBtgWT2d/63GJ3SABn+ISsFp5TuUHKz/B1HKjkKdjObHpDI/lplnZg+SVBpkq7YG9bbARZt/K3YW6IoKY5Q1VDcod9bcvAZhmJw/4IaCBP0NTBjDRCKMK6dudbpFhaFzSdIJw6cbn7Ow858blv5ruY0l4/1Zt5Ftbq8earSPLjcbykVbz2Grr2sUaKsOu5zUx5CWNPBgAB8URE910AZqKJWIVaW8+VdV0nv7OZB/jXrcXXbmTnce6k7v3WUA6UHg22ZOYQITES38vOOhgW8dpF7whRy54caLYn8VdQv5s9RnluGTClt9FBA3y24RvISn6k/mIJUQfrz0MbMTHRwo2Bu57lhcZwlWAXzBxKFA9meqBl9joQLxKiaIYnGLxwS8RNlB3/iQmgSNs6cbfB45ViQbpnOgpDAoUOKQ7apuOnnZ69r98NVkB21z1lhN6vZ1XQ1Fyje7cUvz9n7A7eYyDKMzezKy7KztZd/X6/3AD5pf7YEV187zJ2VoiB39Sr7ZZ3/0NUp/B5K15zALkBvBT6GYQgZu9jIUkZNJPxJ3HVDing0aW5TphANfGRGa5tfNKMIw1F3PiUyHsMWrk/e4n5YoOtIOnV7BPC9/ARE6rIFMdotfy7B6AvG3rJuOHsfw+RjmXV7kym08Fst1mprMcUEYThxlaBuOuLSi9M4XZEgTL8Fp+72THa6GeibZh3ahq2ZHcqGNUPwBJ5O392wZA7mQXR5LYofFHWnqZUazWawd06WbXMT1/X5HIyzkKIMmAATyTkKOX4wBhLWPjj2/BnBHHCUUxNjvi7rsILoHHUk2tWsu0M7v/K1uv61D4hmYDbptNjCrQXLhiVQ3VeIENu8B455aH5rj8aN0KbMli1alQJX82NZa3PMRYjrmKwazu6RiHTz+Jkr9QOQs/WOFjjPpsIkl/cNmpA7CGcIgsqS0xHSgDM4xcCaazXUol28YshIH0rYBh6UukDpuWimWz2KgQ0DvR7YhqbKAdZhx40Bg8GmXg/wusVUPgJMWkxkaGYD0fMwZ7hs3owhgNUAzNFrqvRDYl5owZGulSihNKUK1xqi0326ztnu2cBhmATeKitcGs2/UXlhaCt/+7MVnopnXpk/RvQB+YRZP6D7DmkAaqr/E+oFpyD9m46PZgeQKorgWr8QFNivc0DjnoxBsVE2fEdxQBDaAlTnZcn3C39ja87Gr3igMajjls9PWNIpS/DmrHIVWHcNjug1p9X19w9AucTw3drlxdND2rpVr7cJcHkqzLDY2B/fUjowHR80VknRhHzlE6zmxV1NxrMTCHVYNsDBpG75hI/g6k99R8QRzvQ6oJ+wm+kxhL0I+BC+F8GWiCOXDnv21+XxPCtexZRQOWGLvA1MBA2QQ/tvsPVACrA6QNNhoKyhkzXitYpFJoFuLuf+fqqaJhEW/cgw1KkPW7BzZoDzZtM2iVcYFGe+gqKgcluCo87hv06T3k9MF/HaJXgnYTCbgcKFt8l1bJ/OO8M3dMwdNq8p9kP/JlvkNoBmboao2hq/Sde/vylMv35c6H25fPP+K+vObgvrwZ+2Jf+gv6FezLucqrGBrH/BVKnQfjcywx26TOtHtnLWYh/sZ0eE95dhWGEHYAlU0L2uMBeby37jya+sFCCgXyu1E/9ECsx2kfQ8sju++Uw9DjPaaoIkvwGr8WuG+szniGjekdbi+Wqu2ZYHFj92MYq29Lbsn2UB/nfX5rtIwDurCf6JbzvZQ176M71g89SvlEIwzz1M1qGMpkMrdE6tnxakxfurf5N1+++bc8+s1/iFLGcGWmYFRO4HCmn3kIos54KdMwrj1iKdxe/1+JqbNMj0nKvxNTD6czV5h0dKYhzyo7omJtwhIsAUAe9oMX+oduyuF1fXc7nI9rEVYQ6Ho3bqK1mLxr9zq0xKYA2DVHYq0YJcKuemxc7C+tjXHGQWbtrr7qsaRtdwE90e3AsWzXK4y8h+N/wBdTzcwCB51xUXNMKYUwrcKy91jfPWklVxtNA/3hQ567qUZo7kPt5znUPqS//o0ikMuD/P86qZmoHfteyFsNgDUudw3OiQpk8DAQN+Gsgr4xbozW1pG1OZc+R78MDT9U+TaUsj5c8pQetWpKj0I1vyns9ArUl0VB3wTue/PjrKa777gMRF3aWDoAopLVMxdPr5C7HgH0/UFiXwH60s88Gg3+y8sU+PgVCvw/LlPg3e/4evjp9x3Aea93cpxksof0doH5df3qFOm9a4L0ck/wl0IAOTlSubfyY5dJCc/WL5OT/rfGhj+m/IdcnMpA+dh7QsCGLH1rpKD5GNMe+rfTvY5xrkF8+W67tvNQg/21RzTYbz+439+1+8nHmOLwDP+vhRpy1yezSSe9bzJhL/P8/SEuqzzd90qSx1Rx0dG1n9VLfCLuQaoHFyLACMxHEPERc/mnsuYqDLDDi21PZG1LUhqzkZKGTJ66l+iD/2+FqROwOTGKkYL/L2t8/PizvnFCf/Z3rZqFfAZIHiUNnBvo0d35Z1ZBegLTV6416uqXyYv2c/7rLQ0V2gAHk9JrMSApRU8obyWXzv/Q6X/MlmFbW5c+g2W1cOLTXZXvrfz8ZD4W52w8Al+APBIQxv//kCR+whOYoA0ro70DpNjXaB8YAxkzmUxOOoA5lD/GQdptcSzEk4A3bIT616MUPAuB8a4wTeOnmNg0jy9VTb/qikSegkSFoR4Q4JJJEHsDTDZkGocdxUYYYLxjko+AgwUBycVeTef8QUNXwBv1MAoFc8xXWDBsBonxPYxpAJ/pgGkg1ZtTpgH9xSkohgG6V4JiZrffNa/M2Xd/mrEMoK4ypxm8i4COnkPl2PCm53GoQQxKpAGkE91j0zuBMbSl3Zdw9cPgAOC+9RNNMjxyemeW46B/ImTY9bMIm36y8tHHVJ1C8aHT/3oVqm8C1XkUArH2jQTisdauvLlMQFS1X73qPCLsc803kBbTm5lKS83+JqXlMZe0shnYjAMlrfc/GhRo988vk6gX7kkUFONyibpcoN59hUB11g6vFRxS+lNIt4iu8TfB8XKc9TDrcPMm/ZXlZrGJDqMJIrTXJyugsWapbMC87DXyLQGUXs5bfgKKk1HRKofuZhhc1mN4e1KV+IwuDElS641cJbcGDQA1/AU0+DSt3Xc8ZkCJvgbzyWqaRWrg0T3408RLUxWNFDYGu82uLNlglWMwuo7DOdFjwBEMZ6uN/AlTVNmrrjQZRdAe7TrfCmgJeB/9/AS5+JHHFVoK9l9iOzPisOI6Gx80CYxZZweKGsvhVCr4YDn6qm8SZfr9xxQ8f8Ku6fzMdIqju9vewjV2HfTyxL0FLbkqRrz4bFY/moKUUGXhE6Yg0y9zuOnlB+GmWl69HG4ilx5VZvsG3cPxurbIOEv0JIFW1VOXCF0z1hCwCWABm11r93NZq4mcz8AkKD/wJdhqG9nP55HiblTur7yn8smHsE2+ybzj62/nI4XC06MHpxvKm7d4xx5OBBiN+xMX8XDbSgbfHAPl7keVjOx+7uFFoKxZP0LojMQ78qU9MajaRZu/wgSBRDiMnSmVGj9EGlhK9f2PkFLRlTMXzyynjzpfoV/Zk55rrpAeL3mYOPvdbJbjvgDtsG+tvOqx2cAYLqxOZQjQwBf3ZAhDsnb/5utzVIBp/omwActwGtjZ7/37OSqPNeG6QsoApz4KORNGD35rmCs3f52s7BuKlnG5aCUmFmFfttCZ8PVki1mabxml5T17mRui98szt1MPK1HvulyiDL15UKbSNDooU3/+ELs0xLH2X6Vfw5H2r628hzTh9tcOHZyozFxMXs5SmBaL+pPRceuMLblTSgWjKKI9fE5hjVl7x3NzC4bZcmt88uaasDeEd3/i+t7U/INX7q1P0vCidGj7B+2Wo42RHh4qTzvcGAecvp/kxIv2Z+FNO5pwnRED+orpkQSTe2LjL8cbsIRzZO8dyOsOKd9lg6UPs7/vn1vDqHjP90U2lF7FVA3MBGQTEpnTFtkZHGg8UlXwMkTOuxHY0FAMjZDRnqu60WkPh5Kwbmb2joG2Vpxsz071dtQlnEQwN3OocbjV3snrq+F8NbWMZDFcrec77dbhRr4SLqQJTkZRVXSo1nAiqOs2LbeOoYtoDLO8xKy7FnvN9WroZnNfx2cc4q5YUQ1sXh9nV4l87mZLZUxfGR0obJK4jEPOcSyEgrpYh7/KB1Xz1/UIj8cO0mJDJA3V8XFk0udwkjg7JAKsk9C6Y2GuObmaZCH5BSqIpmOcjYgeLgPD1TZBHbYQXPJpnyyJRj0OpxMYjlKSkh58U9y388DBOagskVKddr6KPrC6h+NmRDY+0FDdvNHHDAk2WlnkvFYEdBhHjSnr6I8VyyfE7NDXiCgeQ5KN3Q9qbBKohlwcx4hqbGgmTu/BmUioB+JYUewPKox4HIRpC+zJ8DmEkaKL7UTTqYxAMsFRHiKb7gPqBDsBF1Y1As8IzCPOM/rD/1/xjP5dhpYM6AceHwbSHY8BysbRv4/R6sKqfYvISd8c2v3Dj8bOfiasVvd8N4/dPyNg9AXQmVfwZqeDwBd3puwUUw577U8wjnjtfvvgwF4Oe4XK5bhXZ3AA+CIlwlVORr8MAGtQqTMorznBv+JOqx0URdpfTF4FNU2TEv9isznk8xMMTNPajK1NSgzM4RjYk9ngQoaCxTp6N4F46ewoIstBM63AobAw1ujuSxV2XMj5Zzm1/vqN95doWDePq2x4mVYiYe6aS+7ZQ8KECRA2uKZ9EAl7EW4obvVKJIzOX/PDp7+aLUc47wHKySGxWyaQWH1m9uPkNeS7kceGlUJI6V9AdV+PLsyylDPFJLjjYL0ZbLFX987JYIdhcApXiSqWJ5qO2TQhDG3B0HB2eDU/FRr6y9S6PLmz7KDGmeXF3uBHDFJFgByvDdanrZ9Rwseq/pA3hy5zUc2BjwbVUANcKmvSzGh7NMBQLNcvfJxrYphKmTXJutHywoCdmokhFPb/x9x7AMiSlWX/faq6qrq6cnWFzrl78p25E2/evbt387K77C5uYslxkSRR+MC/BAEJIsgCkiUnSYIIhk9AJUkUUSQKqEQBUf5+On2/5z1V1WlSzw37ubrsvT0zPTP1nvOe97zh90CKwcdOu8OreF6NcH7s/4iy6FT4AHY+cNjm5/Bhf8kBEQKjHpLfbrZDOm00o93MC4cetOo2hZtUF+BCPLI0l9vuV/jksAQyZtHMLedmrp2xa7jaSihOduzZ6XAjcGrE7OBThb1LCXmkm75WUDjJA71iOEJkQqF9Gb+Qi9lmreB+mw46rHrv9I+Fnwo/4Zn8F9G4rRgd/ggIiKXOTVBNYoHBnEXkXnmoSWNnWMzSMGNTGmJsrmOaBrW59Tio9RGIstzySEl/OPsZxMnPxzn1POQMauEKGAMZDCVLs4dPHpmRcI7mgdWlpUUY26xnHyAeL51ASlgsqr2vyFAfEpwhsOfmD/pkz3yr0S6sVksENGFAiBypMsAGBJxPRbb5N90mHnXZlxzJMDP8mG60qotMeBBT7WKubhvpWNBMUWoeT9t79YwsmFrHUlxAlFSF2+sbO+BDGbulir55eAeEuyrrfW1Qz7//0KhUpkRNN9w234Vt/jV1d9Ti/pQ6KLvRxPGeFfcj0soRcbzoPsf6Nfe7yMrHiWES1d0/MVZ3f/N43Z2JtQOrSx1FBIlfHC7Ah7WWe9ug/n7orlkWLzY92wL8UhqtwRuGzmvwvAJfjCrwcQFeuGB/i+QjOy6S6+JFAg6Dyvgy+ApfBhcghfzO4cp7szuovEczayODbOvxdNtw0V3cxfIiXSaHKatRdBPZfdiXSnJ3oNG8neGF16DqbkBkvT/URjk7czEwL3zEG36FT7SpJqJrXm+3bKt58NT9n3lrUm/vLuxqY3K/kWxsbGNM1aYhSbyjiaELzW1cKVQHNr70spNrgm53ba6vVQsv1xpZC+rnVHgP8hmCZCFj3LoSBbQM6wpLW4wrWqDiW0VU1GPzljC9i2sv/WhvQiCjueifjW0Lskti3GsS4+bJuGkY94vcuGvIOf1e6s/ObMLprtnO4nhC6eAg6yScVE/ceO8bjm+bW3ru1tzS9F2zjR8wqMcvXXr9JYtRdsk1ZoeSSFdVFgfDTQXkBIqDFNJNSQrpBfvb3J/ccXPfnJwAZToB7hxKEsXJIyHa8p/jq+Jo6o7Uy/c6lQN5i3mb4+YVW1Jzd+tKFAbV2FCVnZcKItrGWHV9z7MZzaT7t119xHZHe5/LtSCweb/OBS29gkse1dc/oUOICOp083NT1nBl/eIpZ0544HY2WrhyYWAhL8hBxFIcGKgo8Z0Odcr8tkf0B3BJ1tIXFOfL2dAxy1RLf6ICegOS2tVKQelX0cFLXigbIfazgwrAvyGemkvdilvEu2J37Q/gvq3mQPFodaheHvBBIm4+HsWSRFZSpoMZl4N+fTxSXQ6rfT3eFt1XY6lD3lh+lB2Laa+yH8UKIoeoxd+4FSVh+M7l0VbAlR9PMOEBQdsoFIx2EKxVKxeAQFqtrAVByywgiYvXKlV6rVJdoy7wdKFaVtYe95Brrfw0ajc5LW+cfMrJlfuvFE6APwizq74H8ofwCqispGWRJPmkhRvneo8LQyPMmvCQVv2ixsMAJywW4AtZyvAzqvaeDKah1MCy6s5vAkdTtlyXJL6qjtN0L3HqlhV8NZOzigcXK2Yuo1A9CJcbVYEobmVxpmwGGboH06sqCNdBwY/kHugqnZsH5JnumyCoQg/uUu/AdBn46Xz94ZkGKS1SVQTpBwCctGkLySLR7eaqBVEoQigWv67Y+4Bk4eaIOhWFLZiRgEqngySRxH8GQcK2dXCFvJeogBr3mKG2mBjXEMkEetTsH3H6Wls4F1XACzpdfnofZXELm0ACgErcCxNleLkVV6jGS9AHfuKziD3TavCqUrRsaMHkEpXXqlimXAevC4hF4Bq1APwcXoPzpn0q3VkeKJz4pYD10kKLWmTIiJu/7EHQQc7a5fzPH5tXeQ5A1lCZNcMmiXdmsqrFRL125CDSTapnaiH7M40ektq0e4/TbVfxkXvKulOOcqAlpm1IUgRNfrMRm4vrhQb7AOJsvAhVsqhKh+8Qbhw5nAcgoxzX9Ub4GNr82pHljvxuPfStrA1Y80Ugp9hyWAzk/MG8Wm+UZbld1Z5wayfrJRK2Yu8Y90C2QobUqnZZteg+lNMdKR26wvThi47O0g+FDVwGlea4KGNy47Focv0+nO8KCQyizhprgeIKSj0qwtH0cl8pltfoG60oicm3dndQKdroRB1LEfK21aV8JofbxC2TnBxExzny+t7KcFcN5Qjo3spDPX5PWuXTAYkoKQlC0aUYCaooHZrrQ51Z9JNyGnJ8VETQlVhki8YZI7rO00/CQZvIjegKkDWUZSx4/qkGFESRZMNEOFKg7d6LuCovUnEy6Y6Cr42X0+zBboMEkgRqjpKF3IHOlV2rUQ4oFWjOln8IH1nSNA3vIhf+llyGQmJAXF4I+UM+YL75X7mqBodrG9AchpA7lCsFnv9RM6vrkEyUf4ZjMevMYRFSklRow/uqwB9RJJFFEiqrG0K74kVEHSD9m6ZbR0kIg+9QjFFJM9uS8wUkviD7mYE8nMrVi9OURUXCE5A6VaaMJsTdoe/lGA+CQDjCfFo3YjZwMR9RQOEQ2WDokjTM6omVRu8N1AuG2S08kDTUeUAShsyzlr81DD3DZCTUk5UMSj87kszFtI/q+XyQdRn4iRnwO1HoP6bngQJAPxm+JdIyOV7UvqNSAoOo0rAue01KStXQAn+ZiMWHEOCXU6+kjtstc610RHDMnxSn5BO3IXghbCwtB4nAFIr0nrIMflZ4JFqwFC00hgFondEmLKyp5SAuQSl9CXMu5Edc1hwm6MgbDU3Q3Wf15iecOvWEW1ZXb6H/3rzKflkLXI2UP7NiZ+3YahtQWK3vS77/mDxPzbPp3v/yDpap1h5UG7rBxU0ZIE3lUq7tIF9lzri91zAz56ECo2ttIUvo7NB0Sryygj4Pw8coyXKF5MwElOExOYs0ZlppHb602Ty13misn2o2Lz3cetjsWiUrl9YXF9dKilJaYy8B5T+4AT4iybKISuRSoBB0seHajn5DqzMtsMoRR0f4qCh+oWLhV6DLn1y0Cx56gtJYYjkggwzje1q5lAflN2f580FlGfBc5hbKWUwozeJGD21Rk/jp2E0FkKh7P8O1B/En+Ez4L5wisE/e6S8J/yV8N/VkfgOIDvVE5KAVTwwl2EZqDSPV3C5Xb6CuvEYznila7QMg4egbyIHB4ImWop94BKQfVwaVnb5uNCUt2YfTOo411SqiVI5t8KW8G5KIl0IrGozyjMTewncHkvNZq+H0/ssGEJMn/yGcngGCEDD1jFVHD7WKPkcLE0UR9nxGpZdIzxsB9YLxIZoxIo02aOSZsivLnvx+7J1cxlVVaJrxI/UTAIgiXZ2hP8uyi1OeZLJzJAol89dQBYCGFcmFmXnzukxBfRa9CkookLYyXSHuNDzooyHZmENU1hO+l3pu6stUJUDJTEwWtZzUnngv6nGBztO4fhA/S6qdHhXW5gS8Sq1VCLRa8c2bo8z5Ja3/2Cl3hfxiAyc6+V085IoQOV0ue4xHnUaIO6JJBlMhayME/KBOLm1K6AWRJoTc6uts0ZjY6iKnPM+xrtLADyv8ykKuwChDiIKhSXnDrCmJuCLDT0u9eRXKs3gUEhW7SPVTkP72xtkZyFd5HZRlIBiKT5UpCR9JQkmkKJamsSsIXAonIdRi4c85NK4rNrYufF4oq7K8sHhb738DSIdDQFHQ1OUCrJa1quaxz9sNC7xj3UPaXZZ5YQjTZWAGQltLw7fCzyFippAqcobe+3JLdf9FAx35RA3lORLTJNldHDk5NeupbRuLCgJ2dSmq5Yk3Mm51gZIxhPiF1oVEGRqRHDoXSYfAAlTrNFu1xEjv7kCXPYWQK7ZadEHVzESLER9MQxrUaXj3QD4UogeAriKOg2KWpPvoEjXxYZ20sxHTaUjCfUf4NwjGvzT1JTjkPkAoxoajEEm2DvjJSosJ/4YU8XmRbKUSDT1PYRvjS+E0c82Y0h8THFfo4EbOX+CnOMXi8VFdpb49P1k7XKyc3uYYL5nyn2Euje8mMH43WEmO/P5dg36SRktOBg6h/j5FI4YDnXtEDxV2b3Bts46M6ArFShSJ0GdRnQ0w8wksoTNbWA+u5tqpmBjwcqYj6+kbXRT2M9Y0djq6nCUuggeYeWAUtYamOJdfaVe0BgVYC7hgkAY5143wMq6ezUl0TtPjR2VUg8hQ9QJ3KnfoIvYWBfK1aGaGKm+GNMmQgid9Xqt3RRVxCFprFVrEUDsL0Udk0RVOYKcEWtCupuYkGk+FfEzeRFtdRpg20pBbQEEzk87Bpmmo0ZTLLSzFKRzbKGpkIVwPFrPJO4FFKglDE3jW92qm5+MHRk1FVlFnUa0cFSEVWiv4d/M/RNICSutUSTYcKhVTEQt3jbSm2tlpt2bOGjkrS2UbDTJ0mUXi53mIJhtw64+mq2A/gXuUPEYkBRf12K1Gad1BoTGKKGVC0fsrQ9lennfhJy+XHqN070qwPviMONFLoMozT/Le3M/bvpEduHnWWbCdGiyAESoUMYRj2Ocm4joRuIc5X1q+fYW9bCi7CxXJgzc8+Zdk10UdGyJ0lN3V3/VWuTDlBLo9lNHVQJ9PX7wlk9BZObzc2TsP9J+US+hnae26BmughOxpkBPLcF37jKdbeYmWilF2B2lcygvIFUmIkgQZdc7nWdyMW7CEtb2yPCULwE0vyfLwY/srsO+/8ma/feRl6TUc4DGfe7AAtphiaoLMz8rwmpG5KvJIzlf4ELKxencoG4tnwrOxJx/1xq3ZWLNx4PgME8Mrr7kcQi59u7Mf8YeSPP8f0/MvbbHeFEpl3dE8kCCWB8vl4P1XmPC7/UzvMlKwbYunYMuYfqr2U7B+EKdg3XyOp9ilvm2NKnoiSmFiBGHbrM/tC+hyGFkEbtGptS5D7RvfgWfYvswN95rUX9Mlb8Nfic3HT/hocC0yYLjWGqXD0RF9Po2HPyTWm9pAAn89vhGWWVL5JLsOAoJjfdFYivdXkwwgLwl5UUHtCPv6mxLO3K/GmDnOmTMWg8f+5jhg7pmAeW+zAH4gnNECwJcUxhaA1AlgeLNhfk4o1srpXNX1TN4IRmg0Q3u6XjeyCtWGRMMy3duIXAZHoFsW0nX8h0C21nat2xeHKHXOsglKHabnxih1uCRsWUIamoQnWEIQvBlZQrmSZ4egunHsncA+yDtU1Y6ngXOredOebku8i0HlVDUoJ7Vbup1D0PX3oJsRAJGUQwRVLNXLaV7F5+vwi/yAeAQSRn8egSJafBkkAPvV/kHROoerTdx/lWFql/S/yJKjgFFPXah6XVmKjg4sgeFF9BNJPCMvAkGHaBH9wb4KDZ0dCgDsIdygU4btUmO4m8cJRtfRoUVitvThlP72i+SKBTQVJ4uk99Dh3tTqyqCs0Nq+M/WWHdP/38Ki+D5mbX8d8Bx+898YihhGF8I2QQOaJKiaF6N0Jo4DRBrG7q8nNky1IttfO3P5/Q6z7ay6XUzA1m+7qJMkA05uMfH0xomN6W2PeRrMxQLJRCvku7RC2LvGr/MP76xCfMxumGNGGz34rWIomLWV6cWNiqpWNlAp2/18x1C9l0EVLzZ5z7JJQhatTKYDvyO7ME2d8vtAz18PsOj7o8aVbgLxiGQIcLleH1ytW1RZ49nbZqLSMxXl9ltJCUCI+B/w5GyIdABlToi0jUyFyVVQ0PsNlAkZhkcbPCuAmye+ZCSjHE3TBY90pqDals4ZQSX8HbsNnRpD2PDmIDttul0vXSi7lo41oOkQdcMDhb4qBjiI9y+YZciFIwVksT/CI3n1AIHwLa9kKxz/K/fHCNSDT/zzN1F6TZSQidFMFW6vfaGuwN3oaGCpaJS8CfSWwZsrmPBg23ELJvr6oGmam7l6/mFIRKJZpSDxGg0L5jtlRdE93ThcjymRsLWBNA1EdNOzqt9Y6mx+L2miyNq+tnSkYcr9QQJQsHPcIf++HuoQjAftHLUCXnj6GkRoi9QWxvIVRxEpewMZ42ZAA3uvueyIqvGJ968IPxNd1N1fmvqLs667D23ZDgk/d+O8XUyJF48mujyRGkmSpuOV2WgtxdxapHqaEs2SRNlj8sijyTvHi5cHWDNysyv80b7Cv/Fi/AOwApB640uA5akF1RU7q0dXeD5PNfB3iHc7pfz3j1yip9NcZQ2eQFVKWFi1ci4sygVon0Dtg3lNx86xl6kg2DEZah/addT5RwvCKVA2D4WXJrrDFclqNwp7R4b9aI49RyC9Ec3FqsCPY80ZbnqQ1AP4PevhMgstgnyD5/UOw2vBTajA2OsRt9qpLds4ZhzdOgDNT2C7sab0bAGZ638m7b7+OOdC0Pt60cFgkoTaT4b39Qec8CNB9OJqkhOQBjvz4Nhga9T11xns+riNJwnpSJrY4xOxVM/pe3UqAMlBv+W0e0yIek5Zt9mf8UNDm/BzydSKhoXkpxQPu5ajYVdp856DTcye481bKuQqUNyq1CH8xtpl9FFkxalTrJBJqGYwIe/IV/m+FlTLVZU21BtrIm/JF6kxFLl1RYy2kyvcF8XYEBvIxTMKr3vtZf8nXPwQU5Odivs1XHKyq++soPouG2Hu1YxaEwfUsqC4FEYNnmFQdLxKiHZqjiZMpuky0dn4Yx4wUTfM60nwsonxB8hctqKNxAPo+C9ro/E5duVwtM0mLKqL/TiLkjs4F/fuXRPeqtdozMXywmy1QS7oDmQ1kr+Jrxo+OqcVjD4pyeG5uPmFLUdle2ljqbVNbV2KAtw4ltrkB+V/D7Wz/Xd3ftt2NlxwWH4pD51kSShWrQUvnK7Ef0EQK+90mi7tEAANHZ3D8VIvO+huu2W4u40jpXgDaE34hfB5iLg8Ij5H16OzEO3T6F6jrAafhMHqRzotLAv9KkQ8OoBCBIma8ZAFYzGUx0XELJJQIje4tDw4hrla+YvdOS0rWnqt2YDEi6Nmjpw6krHQl99tluVMdFtIo4sWB0fGzJZyQqQZSeJsUHVAJeureMbQaLJrecvgHZ1CqzgXtXP6V7zg4sufI1wKXYkVI6tGlsG4UGmjHlZCjOQb9UbdsCqQRUWmUa2H2Xa3rjQ26qoDj9fv9Nz8B6YYec+z+NOPD0OZCmLx0mdY+kfRo/zsrV0hOEDO0fpl1CYfVYmghhgViuJuBfTQUwNJQII+vz2+VDOXXHcqs9dC7fGF+rPBQu3JOy3UY85UA0oeC2ikkjb/ntkQiUCJqGyhrdasO6sPO3LBC04Jt53LdcmmmYrpI0izMCrQGYFv6DadESLv8+MZva+JWeHHaMyh8O9oGk9+dT2uySOqmxObuBpFSd+4/5+qB/waz0tqPCtcjvRiuCfideOpZneQVoZB6GTf4JbgqVpKLDeiOZjF+FPo8IcCCs3HCFzyKh4nOypT4Bc3mNOX+U90S584fKlXd/n4CHKmhlQKmx5abbyb74HT382JuAUVDbNgPm8B7j+jLN5+oNvRqcVBEMGZQnW2HG5s/gU4cJKkIYsOgVfMchuqBFVg7p+PqpD6lfUpQy30rpyb01zJEKlCmtPR2rl0c+nYzB+u/uvjzXq1rCF5S0KCTnXu0PV3vOBQaBo4+DEqU+qdZF8VvFmPnA3VYOnOTz9wBdo2mXQ095uuzq+VijUgMyV+JVPQtlOR6BOhYyO6kKFHgZHGd3s3oVrsttHdBxmawqWhCl0NLsjLZkRUjjG9gAyuYCsF+wbFVRB0dHkv3rdh5n/ivPlnp94xMW9+t304nmcd7EPpCEs2GZaM2Nphl03Cmr/fCGv+o1tY8z3NIFWf3TbraJ6VUuthoRDv1X+0Z5p52oZMbVz6lP/93G03Yu8JCW6+M4qb7w3j5sscNz/bx81XPGd+YT7BzQuP3/aC1qw3B212Zj25nr03WyjutFPRrJPto+WzW9HyvKsWn/l93mL322fsTHP76JrrnHev+sH9dcyxqyfxr/fZp3994f565j64l8M1T39S2ERDzhTFCR0zaaWKWxG2pccE50SpCPV4XkRUtLBs87g6w+PqShRXs97UGWML5nAhxaybmcG1i0fQTLhDL0NrGqGH4x8Ipbv93uWbqnvLuWESfFfAIApnEjz3/NIUl4aYtZRRPEaKxOsDoAjOJOHjA/2Z9LmkKL4Ul0ANsr8OdInliB6QttVGrqlRS9kE6MQX7YsxcC/TzRFtybDaUx0nOHLiiG9oRY2G6ATJJ0i60CcmiiAm/kbqLXcNMbE7sX3WV4etA+d1VR+T+LWxcY0XnwkmUT1DfsDLEr4Whnb5eCAhh8HeqmZRqDtTNuJD98cAeOHAvN2OM3ePWQP5LMvhxjW6aU54/gfhX2Fa4iG+5v8ZD3EPiwp/2McfLm7FH/5B76Kd8YcfSzJAnTeeCf7wlt2MOMw8vChiHra2YR5eypmHnf0yD5+7h+3SgDF8W/h32K6Dkfqnpd40caB3DpziFhNNEt89eAItoR+cmdvcdbNtfvkcSAjZ+/Krv7G78Tbft7tkEEcTCqdh2w30794Z7cv9Y9N3w2ucuamF42fICnzhDryMszLuR88Ugv6vO4MLLzoDk2I/GmBaubDZhWh/fA0JhoRJUYP3V00tyXG5JOm34qnyJLFTZvzYHATq8hkShXcPX2ivlklpF9193Cd30c7Ho0v/zU4X0SF6lrO+Vg4xGeaIOsZJMjLY+Sb7FAbeoR6OAoSm23oL0HpGemoF08SE+qxfKPc+fR72bu9GVK7S6a8ShkF6p541Mqyq2ArOccDdhXvikz3oO7sY9UYTU1DCsDDHQVSaZQINoCV/wdComQmV4mT/Xju6f6/bztivHTG232m1/bEd/C6MZkgMSbOSwEGWKJcjyk/FQqM3pD7CByfinod+/o7rhCotZW+p0IB6HpA0rJC1PLRWbiAoGroNxLantHD/GoCjlwp4I1QVkqruz0NGNwK8h7PK2/CiW8XgyhB/xpTwU5ydSKBqAckRw5SmAaHRuIC8k9YoGR13a2nz95MLhchkqMQWcJfI0FUi49eCK9CcmM1ln0rdrtGlQhDiBgeriCPcKMokxxvdR3yFXzfAynMUsyihSvpZfnFADpN4/3zQgrtRUW8099Qj7biQLcH0zmGJVEBY75N0LUFJ15ZcnqaRs4FDi5BfR3gSNb6RlHAj+YhAjExvVoN4sVabRiaUPbr/pXi3o73388/IBrhD0udUZ3jX5Y+4qtNDUXv7OGX5uy161H2NERgBwtAbx4SYiTRFIXRi1yBpq92IODm1gbxwlWH9jFgUN8XoXdjE4qqdnaWgFIrnwhG5GfZAOY89ZBc9zMyQKSLiGjez66ElksyMv3I7t8LDMLDqqW9HzQZGTktCYmIrNjE66ll2Eu1V4eYdFaPYmPKM8ETGSpdcuK7nFzE3ARPI8yvzEmZ7sP4iQ5GVPQdX276Z+RAuGZoGQzLq/KELDs+pfTsP3kD2er82kVArByX2JaauHJaY0i5RkXgc1RjirbniZRBefSgSOH921ywScQJx19zkOq3nYW28cRLp18aEIq7nd11sPnJ3jVj2g8klX9NYDYla6AvRSfXdSYP6s1s14Uo4ybKR9ucxzpG8KCrz+11daONnu7ueWyd2KpufOPvbA7Iy53EBvnZfHqf3/L3kSskhXcnlSl+b+nzqF2c0zC/+D1yPE9Elb96Xvunp/6dLs6efc/1T4bf+B63U1+1CotQQadMivQO8iS+e7ak54XrLncktfON8h1l7rqhvneF9/Qv/UwKvi8/wjv/3+wvFyPMlKqxPSf0+XeG2TKveBcHZ/rzaBKqtpXMfuU/uo563p6rrJedz7bxvfx7n98Y0YElG4jtQ8Upj9Ok98DLb3pbXRi7mXTmZhooT3LwbCIkZPh639XIeEfW2XM6hLOHxD/tBv2uS5CnLkf9JFCojUcog0ajsC1ayItWPiHJg6Bie1NE7GfUYE1uzrGiBqiOTgcu4DYI4gmhZDEphWsqY0lNw9Yc2pYKtFl/NzVDVUDKUDXrwisF+QDY21UIhwLTsUZRSs1qo5zMOWg+h+QsiRvooy4a+b2l6WngAPvlw791CqTtrZz0U9MhGuCmjdMgutesWaoLRDRpG9h20EaGPSBHiACWqCZbs4oWl3sf4W3jT3MiVKWDm2ePw9SLNx6PXoldDk2R4EDKOacf0Zv3/QEetHKyYNsj5KJxcYjQqIVJDoGIsrQS/8Umz3QQUw9Kn5xcw/5Q6/XXhhwBw8vn0M8qyVBg1Lm8QjoaGW7sbazsz7Xm/1yqNQNKe5+V4f68czZZF96p9J1mMFhqm4/Yw4C6cKIWTIO5lIS7K1tsNZdJ8zMv3kUK5G/1VN3XTKK4UzGHe/Vv6vPuqgxlziCSiNBdma42aRqka+ucRe6Rfek/akn0RUlnUtv5/gNBflvpqFCBQ0u3swwN/fVulLkS/4lZdr6mdEzVnXWpjD5BD8yxDBfSLbVHzwqV5SPNL9zPj3v+yfjnu8NZy3Nt6V+9cjvtQUo5bFJ7GWOHEkYMDtw9k3r7cfna2TL/DFhWw3s9G1MLg8nTSxB0cD/1vhLv7e/dVw8Oi0qEZlYKreAkm7s5p1OlPpB9F9QOEAOcwPmUPOgcRZ1pV9lKYyodtc0sg8dEzlZ0664Aze7gu8DoFu8+YBNVvD0tQPQNbpDI/FFvMLM7049K7nbk6VQbqVCZqRS+h/svhsKKPT947qljZIajYImIVbFWxWltksYqVOB53sN0VrXxQl/DYjBBhRV4biipyo1FFBhLXYi70BkGF2w8qTg10rxw/EwlfeZHwFSx1ipIRdtHRrH7I8U3ZQBOxCygWhgLM/lCAGIcX7x/EBkEcW5wciy30XWKLa782JJJlm7FK1oOH2cDfFu7Fv4dVDowk/HhUHH5svnmgmnX1qGrWS7hqlpByU9PABP8sdUvqFTA3T8dTq7cXeEEMWTBjl4EmXDiVqMkrguEQR5j38oVEEYavIHKTF5UE+4zLjcRW1J+70hfGISh4XEIMOUQlWFmPG3ZjGD5OHyWaxBOuFrNZsEveSU9MAzmuoiIsFKktNb/gqDltCmdEOleqmrKVbZ2qL9164JDTcqxqMZemURZB0DMNLxdSh+rm56l65GnL913xDucIUICZCxty5xkSvRauwIyHN53rhBkk/0RsYASgmz8P5rwDGpDbimAjXxGgcIjKZF1sXN0IFnK6lVZ1rWYWjxU+yOkXgtYEeMbDcKsQITM8x2973kpYW4XqfN2B7H3eCVcLvZ+r6J3CAPdrsAZFFeB1TeAkadlWAYER8+jexg9rSmrEWFMy+jzvov0KGFH/gn6ze6R+k1fzxtmhfQzhGIRQ4Wd0AsqmndTXy0Efc1J+WaE1MAgv+Z4eSUKwkbhB7Ox6kgTJt+/fDTB/s9oVPjhMKfxyn1J48MErCaPw0B2NmQVehdHQjaKIcaLdKWpB772DKgz7EMv6ShE7AYRRSFWl5dD+ox2uiL07th4cTX5woI/QyGajQDM+cECgEJnKnkWsUS+b76MmA7Mi8UaY+8Ukw0q9qgpvKIanpEqjisY3MSq/YCvw8gs0djohyi9PkT2AurI5h1odLTbs8s0DK4vGwJNjdLqyzTEBLW/L1Gxzam7OznfodMloWSN7k2PzEj+til9gbOchqVcRSOWsxukmWVIMK2rqrlgqHzir+Tp2enil/fVgpT06WmkCFto9z+sS2s+o3a9HZNvh1VaKVtupaLWZBxzhw+dxJUm8Sz8jfBt1nuugpfMnqW9NXOmZ1A/dFasmN0GN5/YJajzCdTs4ql8ZOKp7n9/1k5mkzLN74z97z45e7OZqKIrlCJgsfPT8razNH+8+MUDyYJ8Ha4qlboJAxPtS30t6y3gTEg3z8hxDf9Bj+Law1opDFJ7moLRohas9hBB1alWl3MjCbJ4bb7banWRdsnFn9mKvboPzZRmNUxW53J5qV5T07PKs6LRcdzpnhHTQp0uW03ZzbZeh1eZ1nm0iIeTlvzAXutBqe4HbrqJK65Vb9jOFUmeuU54eXqGfGazQR52Rg2O9h+21QoWxBXplJmdkggBpNttAc1ZAeNp8OS+ANIe1I9q6rEt2DhQsVYUaLIIluvqapjclOEFRs31swozr+vks3tjElxvsqUNuUNjBC757l7UKMshgrWrF5s4rtXSyMbROD/Oz1D/99+INgENehBrOi+EBU/0JI2H9AgBsiB3A0+8BjbwOC2iUGRxLIp5Bkyotca0fV0E9B3eVUbFClPZauZ3ZkK3+m611+qxJ1Ar5/EwfPc1hBlj3rFQRsprecHIujhVVnlbzoWUXajbYCKuLzTGFjUhdw8dDl5kb/l0kTehQRNWb7QhRj0PS/kJPN2hMu08ZoUN6LY3okObhuuEBDGnlVLF3J21qt1RNUJMnkY3Nq1ApBBAGUzTvUwuBPV8Rnv40u6abQOeVIbFxbVoPXNT9pBExjhZ6WVqxEIcdlOzrcvrmv/BwinezNNoPGdY0jJpdusOYyOqJWoyJzGkXem2TAJEhPrzkz9gRcjIsILunw/ukjYYB2h68j2RC7KOcEk+fPv193A0sdDA/HZzaVC7qDU80VOjuQ12RW8RT0Fc+WAHkGQb6KYn/ilcSz8OyCFWM0cMtrGIAhX0GsboVnmSLKcM8mb4cbkMj/i1teUhcRTVNW8scu+RoZjdZFRpK47oqG3TmAVIsxeuHU/sRZj2JuMWuMAIujjJPm48Tpg7Oy1HfXUIdFthTG16fTny/ITqxcM1Ad0UQhW11VzwsZG9IeYU6DSPpFatZL8jT104PrZlsqVzK9l6wE8VYbi2uQ+2i9zmeSpxd6IgRijjdnp9WmL6VVoyrcBFSAZsYT7xv6new5ZHd4haMe9QSARwzypqKSXMrzaJ2R9fGzvo64npSsONYaVyyYyxVPHYCAo3MmxmiUe0V4S0ZjIZ54LgJkaZaRolFcI5z4BLsBeIIwIGUI8e4U9FA887yVo0dO0L+jGns2HarmmsurthqLgtRKxIUMx1r2jYM6l2srx5croazusZMJQ+oKnupXQsRHtlh1c7OLC66pD4E788yge+I04frdtVHFsQr1e0S4WmE3YR2eu9AZ2TeLxQI92p1u20j19IQFFTBWNDugGKp08WENuEhS7jXTCMavQ3qOZ/kCmQTXGFH+H970nywcXOr63fFTebZk1xoPzsxAugaRnmRsFgYOtbfuFPc+WzRR/Fz5FSf3z3u/O5eV1q7pu2KB9LLLnsi5aHYTuf03OL8UEwJ9N9uMWV3dnY4pryRn9UlzOzT+lhO3QwVn7/ihC9AYAeMii0YudEVEO49rX8XLY53L98IdNuAYhFeff1V/k4rYFEZAlF8fYf5/m+c3/XB6oLgzw6hLcYocMOL4U93hQL853ldJLETQUD3UEw//M25IUmO+ZFtsJDOGVwPpP0tNayaPz8X7Mkx5zIGkdxrYYxfB9i997Hu2CSIyt1WFpEn3X4CRbj3PkL9YNdl12w3h+4QeSwjUK5FAyyiB6aeRWic/YWEyvByGYURTQ2TyrpxYLgX6CgOJ0EVX4kWZhJotl4/cSQoIgbaHla0MEAazQqR9N19dwQg9Q4k4SMIZhwrGYeV6FmcMOqzUErcEWI0IB1ZDTMK/PJ70JGEy5OYEdOrVsMaxJII9OxUSfh34VtgzD0eVkTXA+HBxBjazDHuclzCGPS3rFKcPScoVN3wBx+gp06jSlPxWmABj++QsGjIfcXdRATgKJMwdrOYwZCvX6yYr/jFIbdjQNJKjBRzebnSNNrtUpp4ywY6JR4uD71GD0bQs/fHys/awtu9sDFtd+7W7n2vdSjM2IpjUDyYBsTfzgqdtlkUHm1atm754AWgxmUYmtU42aijANHO+XMulBEqbrief71rmWqa3Q0fuHzo5em7z6pEhkYoqPXKOAsLepK9wa0brHjZzqIQj/gtw2sSRM6hnCFRuv6I4rRzBcGZOh+n75a0zHsnOE7ZdRPgHH75nJ654671/rseowd3RT18fFdvNz0/PXTIgjexyyFbun7YkV6JI1bGCvhLZI1/lGpjFv+xqdel/hIN2qlOzNWDVbm+6zrH6fFTEv8DXzgHj0nCKsJ6XEUcU89I1sN6AlUSD7bG1lOZxSJLgCrsafkaxBnwCYuMjlqqZCrJqhp0PNQYv6F113Jc06kJHadA+Gyp0LjxiuVQCWu18MpaENTuTn+CK928M4Pkx1fXVubu1ZQQBEGLzD7gbX4EyyNMlgfLILyn5QVqt3Hn7NEkucKpDP3ZolfutRpENlcv4YHhhNV8s+vQCtNqwfDyEsygBMhkySk0phrTV1c3cnm5enxuoQbN1EreKRScPP3J6rIHRHxuCQQsx0yTdIaOBUMNJ70XRyNDmFhkxfBlfjgAPpbrfIBEaO+8OB7TalTyh3C4ygGLVptfHl5pzzQCS22VNn8i5r18IV+ohP2a5o9QvbpH6hlocD1LGCQl5xoR/gempGthboKlEZt97zAMC5c+UXjvWRWmXueUG45wwGzXAq/atjc/YpTz1uv2XAO6XzLL1QmirKlmpTYSXF0eBVedsdLT5Txy6rIbc8gzqIEf5rNUs8Z32NHGL3ACS67lr9gjhHp+udupcN/w17FvuDdwAO9CRemHE/oGaQwRnrScESM8tvccz4aGY3TxHNR4jggriTYc6MpjDmVjUl9xnE0altOvcUwc9hqf2dlr3IHaE+DgD/pf0SpR+u1o6hNW1nUAwbz7vRQHMK0wgoo/L1pgs5I7e+WT3vsU+BkoIMP22c1PDzuaG/Z2IbP1enmSEF2g9VOM/MgNo34kID8SRH7E0OpasqgoOM9G6cF6+0qzBB7sDCY67K5FSmaVkL2X3jej1QoOgh425HI+vPNae3JrZqZ4ZK9gvd1pG7XubAVtWPbmRweuhZczhdNxaPLrCE2+NnE5cz/xiTw4Sc5LdkCcoJx5y0g589NbKWUCypkLwzHMV4fXDsUwKxTDXHwHLQ5zyRksjVfsFMG8aN9ZAz+pZh4YrWb++/6qmdD8ckhGXSSAsWto5iDQ+Qu+UphwvhIKe1cyW6c/K4ZweCdRPXgRYeeRtqQ+qvg0o7TUakS1pt5Z6qzdoMUW9UfSJ2G5VLjAGKcYtSRf5LeHfnyEt5KGFmRnAv8UnVmThsde4vqED/kdUnes670b/Kl84GPCjOJLrbQQoHnyL1cfsqa32zVFte3yarn3MvQrAs75Za2MljXogWm95oMpPmI/j0KjbL5U0jf/Jll3HfaVPR3RTLNeniRSBu+zpLa9omPz8YKWW1wp5jo5B3QIfmnRDKclcIyDmMlTv/0UUItim70kiYPyULWiakbsljLv2NXjTM1OGbXGTH2vWHmj0ZxvF6mwSBCGrwk/4Ki1OydHrd2FcIXv7Q5k23zfeeMnnNgKbLtpHNj2fdW9/nyTEYTUxRjfO4EuhKuIOrWBjubY8wYUaA5gdlGTIsdEx1f/pEkSM5ur3aTLNYFMs1A6G+ZGVBYeZm58nvLuMnI5ec3A4ac7HStDFXI4WrNkSkExSN/T63hWHUgKYOb5w7ExT6HrvkR6ZMEZcDT4hwmk8RN8C3DIOF4EsDwJEGVVytsWqf7An6uaVjTrpxr/ji4GVpmZc7w5DfGNiL596IsG2kt2YmXgmN2LlcFHMMDK2IhYGXC2B5GVuxBZuS5qRP8fzULl4tzoxnqXaHC0GaJLIvK2lO7n57vfZx13k2G2eF5pp/lHmJfOeEhMIcO3zj1rhUXsG17r3Zjl1cKoWf5EnP/DBut/Cprk+SZ+ebVr5eg3Nqh1MONG5whINJ8yHGpCni6xeT7FRieLK8dzbFLBhCzY9tO2XaY4D6pPiWmnOoU54IVZ04d4ALEkZW0uQK1JYD/N6PCzaRP0RPi/dL5SlouXVfwyCTCQX5OzUygWItXmWBV2A4S6a3MPnSseDqHEBbjpxeiFbzYIFy5bUB8JnadH02tALaf782tZXejDA7aZYHurif0P9maBfgKk7tyy/yjDc13dQ/OumfO1xwuUkDSg9iirpGyHnlin7KO66AdGznV0B0JkQXgfs0jSUGJqGcPgZPep1DVEhg8nIEew87IyPjUJEWLz5ztZ/W/6Vm9GVs9nMiFq9DJdn6XqjlYv7QF3eMTeRnzaqBEfvacR8diXcFU/AdWGtdQTUu/k6dNjbH2VMz/7GA7IYuMhcZk9gTZLElnH8Y8U8ZOp9trwG33WVCLwu0jq2vzdSDkbwpAiZvxjdnljOccV+KLi7QAlQx6XwhXucsUK9eaQFisCJvwUp1A/QGu4aSJPpqDPmmvUgrMqseULL3ScKeTH00hlhubplAXNBUd4oGmUS4CO9g6zH2KwG9dj2KVj9i6ag/Op+TzWsxwnv3Sfpa8tvfT7t7lmoAmqGhaKusr+YP0NKFXktZINQ4XVepG4rkK7a7uqQCqfCh1Xooeg8S3lsnby8uNKOeRBE/LmWdmuNKaL/pSnR2rpTFPLlbwEpBQEFR+S6Th3K83hkouaeg7ngYEvalSukDDimIW8L5uzwpJGcPQ8ZPxQ1qeDroMTojgzVRbC1mzwGBy+gHMJTr6kz9sRblZW+Wb6ongJ5ovvDzDzuxJlbTptePs/xgKpthADEv1d7t0HIqRXP1Wz9d4eUifU1n3oBWO70Ium1dZGx4xH8C6KcH15HvGejt6iguKwHHoSZEWdtUoav0E//+1DN+jXxrJcLLp4p7Ol9eU3b7l8/96RolFVep8cbNYSUGFuDGNUv9jfq0tVHGWeNjJgPLI9WQ1KiNP5BxaOBJgQyOrlS2olEmhCU+KWizH4j12MeG1zj/ZV6Xq+j+8xvI/zhGVMdvEj716cUvQWhLkGM8RqM3v38RHygxBPJ38ZXYTfODGU8fycphPcZ6+foD332Lk+Szc/t2e3bW4vqMokrnf/5+fz9qKjJIHQSupWtEK8f0c6Cr9bEBwFocwoG+X8nI9nijfJlkueyOkmYthoZ4fgJr21cx5CBXsCS5pbgSXpNO54nFeSCzLQQx/ClbDH7r0Grh1dAyf2XgMv3YU7chAXFzL/Mma5XrB/MCcLO+fF+sLMPicpKwc7vb881/b9o30ORAZS+ea9DfirowZ8yCTx00HoW5CZrkg9ipzwBrUSJgKTKGdQqBrGYtfRY4w6gaP7f2y8Viw5HL0inhe7fVoLS1XHV/RAcZteJhcULSufc5R2w6m59lyN/yU/F8ooYGtQLF4OrZyhepozVxRxG7Tl0qwPeXnVO3GubVmzSi50oMr1qlY5WtaKvkWaiIXsoY3iejE8KPC/tK5oIyXlIL+geRdWc0JOzzvFaWwZtBkcLtLfy6x1Htw098Nf5xbOpY6kHklXk3FWy/k5UrfwVi4c563ccq4tsSdChRnn4yQcZ6HQpvoCf+TXoqPjzWc0OLJOCIP+xMi5OAjHQtVXnfHgB7S72Z9tmfrYPH3W1hyx5bVqzsyEgYshDlO00JoMifdCpYAhDoWGOBwIkkk2hN4AzMUQRzYa4rBNbxo/QcZzgzx6QRm+Lock7p5Gf94to0a/YMzo9xz3msuYDSID35R6Kt1PzmQyqJ+P8/leDNDfPWRpunLufBnZl6VfeeYjPoglNSil28IL3E7dBzahk5i7lyJz0w7sm1s8C2ufxchOHqLgWnY63DK0c5TM7jdrTb9v+CPNfHPoqnLb3UfNvj5m9ttGzS6k5gBK6YkGzE5HJd1X+j1VNIIOArgY8Wo2EmZ/lHVAf49HHrKC4X3ehQesdBhEebtK1Dk3xzqePCx3RgAccIycQOkjM6LWLWc1uYAG/G1XEErz73ckrpfg3SvsbwNb9TXCiYBShUtLlAjKqCXKshqQ/qRRb64no8oXIK3tz7dD4GUqhtdxagIWhRhkwfMDahrtYYxdjd56CC3gixGjUOuVqjUgCphFMwk+BK6RRLPhSMzDtrbIhdRgMlWSrUbbbTi/dPdrw2nvMsuXPNTzacWJoqIa+PEydqah2/LapddefYlT0kRITckKNS6UylnLIz1A6YhRMXHESoZiwPxa1lI2e5v5QuC4yDsgYjINbPbHV/1QhI6hBaCS5iqf+Hwjh2Wsi8glQ+8pF4Y5Ekc5iksn0SSOIDn7tGiqotWX4pqiTUhVqVGGazRFFa7FF39eBMtxweaD1MpB5sbdgSf6aiiSVYVJvDV+fSOnu2GkonOAyaZvhi2ByKxBRknTBjnA+d52rUh3b1VQVIhyWL1CuQ3ODFrAwpkiPuvjGfREbr58S34g9r2v6+/G5azv6lrOmA2L6zX2ci3M6VMhe/IoYxXI7pk2eziySpblAROuN9Obj0cqlFpvSG/1UTLcA/rv5xduFqSszfw9PSt/5l/C5FIayhnPpgzd2StncHB7DP+gCkfLHxIKFNfGCbxQFtxYS7jukUXZngkf4VPnQElDOMhkLYsdkzN0yRKXIoeoUp1JBzBi2NjpkhPz3H3HckB+2HzjDjmfvknntxJ5utsQea6IiDzsGmgRwfNmM3p5sVa9NfZ8hHsDoZ48X04SwHYxke7RrmfsSh3rwYJ8IUYAVKyD3tv2yPtwS39RxGwG7hIvoqbLc3CXYN4wo/84qX+OWjvB/iV7FTVK/CHm+MebdZL9+M1zdb1AQQo213Tw1TilH23sIqcvK1m0PsPuHLIyMLzUdIb3+eYb9tzK/rm6b6xzfg8ANDqay9sWnvYDOBBKkiMA8w2jziGduRk/zL30Ye/Qe8neHiCdmjr9NxDRTuMGcutA4XyEFjkwMwy3dt6sLI3fSW4av5MIvzMwn4VHec6tx7Ljl5RHjF9Sun27lC+twSq34YlHVkFueRyLfYZW+Yct/Mak0Hxd6pURw2WsNAyaViUeD922KOyF/rYl5Sm8LJ27urXwEykYLhObB3Po9N9SIEYKkrllYcvnuuXNb59dqRoEISGuFmtRtRjrIIeujh3LxM6S22L9L0LIY0Zf9Cx22dkVrrG1joKOcSOnoF+Jq/0bziKLPnYAspFLRMuPLBv9eWfsKvLoKw3srH4GvTUrtSiBTnTOh44k0D+ytSFMN6qLO5x6f2aEqCCnp0o4qoYvDuFV9CfEmgcrwc6o1c3vmzZbQk6V589FMZ+9/pGXzwTIVZo8hx1xyQ+MpdCXlpf6KfQofXrvkdPvQn76mV6ghh67ZOSucDwB1TNxGKt6YVISyWaymrH5TkfkufMAyivIm4N5ZsKkS6e/KV7B2bqHAFN95kT5mnNivC0ZmxvGveMle9ahzsQ6Dxv3iE8a94j+jk8/8mbsoh2efjj89G8cffof2eICD6E388uimjoBkFWKQTgIzyjCg6HYCxWgiWClnXPo665TFtYWFKcWZDBZLet2ZuXoKjTv07wnxgr6YNLaAEzae9yQe0PrxXbu7VG7ubdrozqvX8nBuUXC1gvXLyQc0nyza2++YVsO6dpkzuwHOzkzMXUcccK/ABk5j7Z7rPvOOoFTxggV5FIEUkhcSjgWG9ulTLYc/fyzVjfG2ZHRsx6HRwpPq7ZIUnBrF4XmVBave+LNYDWKmqPX8NX9NMjogf/VZEvcXjkA04i2lwZ5ccB9xLBgAn50YvDjLzBontef6nl+B07RDQtaulgpJBPORJm4nac0UDjzh0/2Vrc9dLK/R/KysC2nV7DDfWSjgDsHmI1vGWY2vhjP/DBSGr8A+/UEau2/PcHtbKyAPnIxE/euow+8Dyrz0dtgn2yMEmLp1gY9mz/rX8EObb2Cvb13leSM38DyLfbh5PZ1YGZPZ3UUwVwCcH1KpS2JVlAyrePlYcbrZOqF9QR8ytb2cFVzA+bqcyGu2bBRzxPZ6jibdf3Yg3EUXAo90Z9jQ0wjk/y41MsHvWR7rHVyKzuu9biXlk0UKGxMUBh/5057oP+kn9nfA7V2fWwPtIthd/M/J6it37hnJTxqFNtjf7xVEIc2yMnxDfLeQrtRe+7mv+1VVH/KXuXvY9hYX+e2u3vq4Xw+9xz4KbIdpZwAQsWAUBUi8xJVrnGCUGGdV67PQIPk9WdlwG5eCxyt96xcAceG5cjsEsnG+WvZElu54h5XHGSP3EUp5CXMHFMKYTdxI66srYwYsdluDRnxjdJuNvyLTkG2Crkn9h6N7wWxd5HPFmd89Dmx34rL5sQQubV5eKDzcQDX6Gm3wHU+pvQDN8WFc95i9kOu6nswdSNYhvGkUDwL4UxxyAfPLY3BZCOWbJgAk8anpssCZzN1RgKBJdz+xuIAT+YJyDimqPalDsmCgzoAOhaOgg2bj9iwMrtDzSGvI6ihWsrePIDINhwwZN8tGzQ5ncumhwen8Yg2vzUaGAyHBQIPKspVx0giCobomYcUxWrxvsMIWELGajnLndHgND82RIytRsDYuT81CNayDQe2tHrBNQ9+xi8Vl+KAwaaA4frFy37p2uPaSLgwq9Uf/vhfrvNwI2J+xPGGhpQ3BRzYgNOn/xHd7VJqBlfaJ/MO93iCjzbQjp2Zk6QRNkZyE2s0Xh1v1GjLRiG1v7E6pIWtOHGIATaW8E+RIDbD1FR2p17N+6JXc/MdO+UTnp7szO8hlAYKKZuJtL3u5kwDdEU7VSw0wJFOS1q1hnaGwzjq9ExAWpHUyorRETMs6sJBas00vLz2DGrdxJmG7YWxylrSuomdsjWT0Gg3+VZEmQVbMQ33DDNEOaM/xEYC3kqzuHj8bTxVkc5ZnSANDrBjEDra1xtS72FRiiNsTlN+aB6u8uew1MWAhb489afnIke8dyiyMVZFW1PGzcjrN9H0wsYxNm7KJPLH8Myx9Lrwx0P54gMUrAj7zxfP7hCx9I3974mx45La5QNr5+tNg4Y8imbNVrBP2InI4KXE4GgbtR0JnaXiSERzSRTRdLbJHF/OQ5ppNrdH5vc5vxQvAUzLYA08kwqw2UqyCE5gEaCols7F+apkISBThYXwSb4QUFvCdE4ZgLTqwuqBGm9a+AKigah76JmQ19qzf4iNtg/B5JP0D20oE27lrfaPt/JlrStbelkU1aF2Ij9pJ7q0Eq4XhpuJzEKx4vbevueu/pE4uq2vGd7WnaFtvXVXA4zwntJSOVtxMEgLlda4u8hNuotmHdM2MrWkt8gzNUPQzKv33OfPumx4oz95wo3+iqGNLuCy8Q1csNOpy+CQU4xCf2Q1nH4Rjm4B3bX4zwmZGxscL0ZMkqHXjjHKNaF1j3w44ZWGr9UA/eNKfUyMCIW+cA1yb/mwULUxBFUOtACFRMZ+MyxIhLuWZbjeueX5DHtOrkrYc3pBbh9Ycnq/ZuX8ZYylWbWCJbilpiPVEf5QdrA1o/Aj0ggbHuUPhBfZ0818vjXjbr7NrBVdJPlKjrp+4THg40C1QQKZpwp5iGgfakC3XjMNetWmV+mfYr13FC6Jjmqr4PtFMAVx9es06kca177qOn5jdhr5LMDixaqJqOTY6e8Km0hWHEk9IPVcythStBFN1S2yQeMBlnFT5rtFSF4YCCeISyNYDLqErfFHFmIEKDoTp3aPWqOBQOHvwAxpFYtT7KpiF7GBILp+ut6pS+aCm5/GWU+DWq4vllstlWj0aUWtuXVxMI3wi5kDnI1YMTiDgI7AZfbFncLS1xbbothoCj+GvLEt9J7TbddLNwPFbsCX6TZPQJykYrcm2Zi+02weJaolqjWTLPHmzQNsxRNk13eRw4ODSufyJS0dFnw6+/6BB6FHjx8dCUIpn0I7gtWKYQle6gTkcH4AG+T41MdztqbqOuMptc4kj/OMbHntllKGP55X653c44mya87EjuNdVsujibXoUR46fGjkUXZnpwaPkr0rsuSHyZJHRi25sIsloUjkp4piQfgppj8Q362vDKN1Gxgs7WOfKX+3HGJuYKPL+zYigtYajb4m4TaWPMEU6KILtYiAAgo+VB2EMXsHPkYhLQI/JL8DDXLho5hTdiocd0vgqs3PIQ71lxyoXaO9X1q6bZmJlQbAdLbTbZZkIqGIgqYjEZYLshwshMJ/jFBkXcVStYLuTGm6LDlmOF/MBJnOVYzlZ6dnQ7f5OwQx1E1fg3Y3UYlEE0oPdZkGpp4tp6O5qazvzd+yjEnTwLeB9YN/8/NhJsRCKgZOPiNGbbp2zitYTsag1BIKXngr+Gbv9D8JP+U6gS/ajeGPOQqswi6U0JNHuI6759qJGDvFsaBBH1iAVY0rZ/wQo3dD9EYoBfCNj7DcjlieIYyK8LphoPAP+kDhPH6IQsYQwJFyplplOc15rTKyzIIs6KSI5KoZmqzBwQlcqA4BhAbuM+6cnhUtvd5qWhk308wDRXHi+KHaEHDne2PAHXpKEXHn6RG2Ouhjq70IW41yOVdpCXwN7TazB2clo4DBF5rqwdXEQAraVW/CcR7LtgNqVTR4AsOZN1nvywN39PDhCSrw0cgVcdt8hdvmgtRbzhtJf2fD7tuswmvOISJ/yOCtRruQQTfgmMHTjry9uZuxuTOWXqs3uLlDmPvCC4+cCwY+w4jzwOjkJWF0dCUOTH5ixOS+QaNQzKwb1EHonf4mN2kHzfHvPTOk/dB0/VEuo3UuNuVyMMkszKX7RtWTGdF/RHZ8OVJnZ7dpa5EVe4U9U4L+BPAGZbCnZcz+a2BDKOxiNmTcqbmpbXb0VdvtaGsKd/fex3dHMpD5v8TNfwtyg7++p7/duiMji0ZKmStbbNmKNyLbGo5QmpDR/EtV4EMvO3pX2mzXjtgoU3CMcoZbRxVcnc1tMczJyC6bb1m9+QmnTj3hltXVW+i/N68KWuvwpc3mqfVGY/1Us3np4RZ7/o6+9OK+I13kjhSKRDp/4A+gIeLBo7a7But9fna9pmXKG4uL6xXYdn3RRoOwgwsYLlKyM/Sk74cB+g9MfrIRyDfJnA5vn6q4srPji64fkcs8yqZakSemPzdW+nOlxNQoczRjnF3gr0110EGB90WYwgl+aIHhXIRd7UMbacYuzDc8rC701Rrq6BYSMw4cx477Z/NfnC6oCoKayfpaORTXdTi2jIz2FpN9Ch0Nmob2Wzx6W2/ptMirmlMwTUHLzvqFcu89FJil019FlGhI79SzBtb4zka9iNKuuU4tMWoG5Mr+TrqHblFsMrSLMKLVu0KxlBxYCPgJL2GejpAYhBXE6X4xr5AWFqgBBZ/oH2ismDM0XOmEV5RcbFDb0MDi5zsugxXgn/4C2o807LW3pb7AibzRvC7Cw0aUbV+nmm4MreBDojEksTsgnbMwthmFhWQ0cJrDlfhr4s2oeP0utqEmmD7zIslacFhGizAblGzgnKm1QbYpErpa4ZPCCg2lRV+Eq238bjyRRd+Tf2vO9hZ+TGeXQc1pqrT5HquRyai6kffnTF/tZh1t/WFmA5gl/oicUFfzTVTegSDR6ifqLFtckuSpwieYcMQu24fMIpIFCjoWhRzgGOjhtfjNFXV0vel5ByqVQ/Xa0VJ5yfMbEPgKTB021oBBYa3pjwgkG6U18xalBb5lmqBivlvBGKtPSJ+n2piD9dDGKquKp2Me+QKnZlllw/DZw9Hyy2fskYnQ6zpAsIJwLG3oZtspHCzm5zXFC+yqTSCOdNqplEvILjQJ4Skgk/Gn6KeRSJeBTp+g49ayKJTLCrUYgx0iZ2w9i0tKgDk1GXIBuXwhByI/2ruUdNbAD5IG3h19yumM/CqU0jVF4rpnRAUVVUzvUu4c70PsbweNGSeRk5pHRecZNJTME8fx0LfFYh+7hZsv7ZmKlAZY/b4K3RaufnINFD6W9gqh4hXxDCroOsmGQQFtAAMePtfv2/zBDrnEryUppt57hXKrERPzc+h2k4MSGuHZw4eQ+S8mZH4WPTLEzGcf5PJh+RCT6G5O/IYz1y2GrSlbuOdQr5OdX7r5pUm+cClpux/NF36G/IE+O1MnCL4ghK7e6daJgh9A8yWi4OP+E2HwxVTt9GfEdVRfrk49j9M0lvlW4W2ix1n8SPGc4JkHT3SOofOFBzPhEZYwHGNmVhIy5Xjb/XCDKr62xvr9qfSGI92pSVsq26KPwTlI0Qw6x/SztQfnj1ONeD26b0cmUIlym+ZG+EJihOvSKHNYeT/Xdgy0j864vbcyM+chHlIkrf27SE4EWb/hGOmM1e9LBQ0op1xlVRx7poZMkavcPNSUahsLl7VcqTSH+gtu88PyGJqTKc6k062ur/s1Fyz03xGZP2Xqbr70gLDp6yZ049CLkLMPayqSfq6fQR6z4dHhn5GLduhZqAioMpJ+imIYvbdgXsNXbBwQ+C+E/qJO1KwbZG8P5/LhgoAMYT77K/0u1PlqjuUumgdMIzfvAQVwalgbo3yIoIytasW8yq6GmAKYrvBrz98KvxB+jqrAKyIGwFCEA/LQINql7bXGNYIPLnGlYETRlGHZLgJO2mv4TuShcLDOkVfrQZJqIaB2LI0QqSxUBznmOGmApA5rCreOnauZjeMbmZHQlu0Q3sbRIQW5OrKNWk77LGT2tHyvGs6AYmvydILQsDv1oLm4bE95Xa+LTxYsrogQsW8L5YXZBfbPODVXolOTEgCwhachnaCk0ZOjw4FrDeiQSmpOTStbQ1iU76DSoGXQEZIEs9FP1vsATmNniiDHcMqFIJJGqF6aJ2EExpUR2po757PoLvNjsYEQi5L1rzwr5P1oac4P5SrJRU+JE91gRtfEIFYW3rp8r1GU/RXXXD4Zyv4r2VLe6ScDqEInBK3pVsA+MfGNM7NxYmxN8Csrp9U3ygmtvjoRrV4yfee6oRRBPQLavXZg0MtH7iT56MpJ52rII+rWTCu6pUa7i1vtEeRW98ugJ0ELjGzjWe+qZ4E3HOfQn6UtP7R/wDxQI42mrza7DWUnox/0SMBiCDK/dLb2PbBnhgEenIeoYGSjIB8YPKknZTO+jtaJDM/TVewBSf5Le+QVtklFYGvqKK3+J4cw3IvumR100cW11G0p7soQ5h255lnWGbDgeeC7AzJ+Y/w49kf7UX/Ub0eoaY8ew7VnBiB3e26m3rt9wHpnz/HmrZgIX635npsQ4bunLhs5WjPJydrvWDnCeA9CiXoQvrcVyF5IgO0YLLXZqwZI97Q5zH1/TcJ9fzMTP0xhzeuKnSiosYrFsnP70JgDNlSqhsX4z6mjcIPRcZXE/jLfVPFqpnG9QcY5CueFI3Qb50eQGD9twi32++jBhpaFRw+lhsOrrr97eZBXHsoqY4nZ4EA0Tz7kGp5Q7iH9nLeM6EBZKM5FyWn/ipddfPlz2DsGqWC+FCl/fN3yo0eyx1M3HnLK6Zjw0HscU4w8BtG4i6IMNB6VTAxmfg78I9imvVQztYEQOZWLRMmiFEWShWgk1b3uKiMKpRiXntb5Z7Lk0zrN5PpN7uZmYHPsVgldKXqRHTQ6rYLXmPZ6b/OX8PCYcFEwS9FGkO2VD7Q7fqOCy9+nnVpo5qota/MvMsWCu1ANFk/c8NhXCO82SqG10Lyn7wha4JHemJjVDhSlzvz85nsqdcszpFb4mEqni0mlpmSGOdfHrVPUfKdeog3Hf82/Ff6bZ2Oftms+dn0SNvRZeUNxhFUeDKPKY8Y/XQ634UJDhmE2MI8+5DW/0psez8bWFi6419P62dgjZ+0JSxk/m/+71eW52xtpaBnXPAs88k9zXD0qrUYJrNetzlJl3bF07N24H2ydiR/s/RF/WTGqBYvY4shxuKqHmTyBzOkiPfAfwmk06l2NZFzSpkfq9OurkTvj2bIRhxZiS8soJMUtIImDXB8afgl5VidCaYrRkkhat+gOL//hWC2OyzOP+rBD2bVTV59a0y72oCqN+RV+brHHuY5ZyWAXq953JNXwStx1ouXajL1qlGpMRzyJfuHNRqBZvXBQeIvc1j9xiIIAam0Y8LADWTPFLVjUFXcBVBwMifMv4TruGx4zyYUG8+GJV7/2zo1cAy7v6OlvCV/CVriNOuY3ZFTPwoC36USjQHHEHQGHKd9Cslh4vhFYbWooJQJkm7PaTdoV+dNaT/rcyEmiA46yK7IfZ8v6TXP4um7UaLXOcyZRY9wnMF0pqy9CJhqzwFgprkXLlzSrpRxSTxnZzORkS/0T5PVRSrSIvIpkMF+AiqAWgXjIot8evQ4M48+CzgeWBcpuFAsmXiYuKSMKmmQ4gW9C3AQf/Y4J8leamrrx7HWFsgo5HVy1LAmQkNyIKGp4noqRsRsWhu/ZmpRT57IeJd8CnXBr2FtQ3TbpB9r8Q6SiwZVME60fWFkEpYIu4w6pIE9ynzCnoZ0mm9WyfgaTar7Km6i+I3xRVFLH0Cn8ytRf00LmD+h4Gs82PnE2Il9TSeOJ0oOCjY4i/o4fWjRpzrq8faJ7XFiNa8tUi1hJrk4+pS9kxVP6QkNUmsA+2PDgg44KUT+qSFjXqVkqGlC+GVOdSkXsJ9766TAC5ZG9j6eTFFjS9lhhLyr7SAb4gobwSDYhNp7VVYt6/YCBxf+5n7eUNLYJmqlcr9z7U7RgoD1cdDSzYrKPZy0NkybY4JFSHRkfngKrXpd6atnS7iNS4IGREBU2Qw0hi+ig9x9azsTMPJIfmH+Ho1ME0GRttGiApZTmxW9BMtNAL4Me68uCzG6VIW8SNBfW1w+YRbsSKFkwpQUSm6nWLy+3uri0I47AtR8xDrKz4IQqRSUDKLGTgS1trXXEreqWm+Gq8Jk0LnFmdk5HirWIt0vraM8kZm1aeRjhTkXwnm0b789TXRnDNHVWk/U0VposgVWL95fA9IP2IUDZN9xkBmD72TY9Ivp0rLxsERt2BVAumvK7AqoYhIEOMfKuEEgv3onQgcQ+5PkQSi9yW/CwUOYNNjTLZQoY9ctR8w26JZN4sKXI5UhsRpG35sCwfz9YWUyTOqChbVx8aT4THgztcoaeFj0dudYoid9nlWYdv6koKK7Xka3axgGzonAyuxuKncOn2JPcEp5DLofxZEHPB/myOUyElcTng3RRBB8CvlAqOloNQ0fsrWKxSVQHmSm2LSO7keYVOqwU/OCs9yavQOfasXQ+gFtw8qx44alLaka3hSuWV+vYwoOGklsbjz3M4S6fFS9ASH0EpfJXRWnAKFMQnbt4ghvHkjQSCaPyLid+mIutKTwLni/GKKUQDHiRiawjTbdgyPlgXzpwYz+wD7HFnmfVy279wErupW6nUcxQ7zPtETVne12xOrM0UxWNchHIf4abJoK7DwnGkQuO/GR2Khp2SQRWuQYIwgHWez+zIMQk2+jSEY7sQfQolAvR6BdGlRC9/5VEjUx5XZQN3ZjqlIQ/gIKgJ6OCEEWTOPydaSeD1gf2Bib8Uzs8DKx8TkQ390BHNSwE1KWALDSAsGiJ+sEjd2dcPXIwCJbNxqiWiMt6BBWgl5yRucQJUK65/Znp6YmZnj+xmdaPbbx2Z7Lr8X4vVeF8GqlX3YPy+k+P2N0+j9pinyWgdDZgn43UrxAraaNLYikJap7cDg01tDiDnpdG8OT7JHqFsnDUJXUGVt0/0epqpvtli/2J3/WcHEPjoj2TzoQL1//a7UiJUm5XzbJfK0w7YdayO4F25ZPe+KDpGbZ2RqZmd9sX+eo9QdXNQI41cJ08wKsCmiRcB3QUzC8B6jDr0TAbQ9nv/SRzmlgb1yjhHaDt5Eat3Y2s/UomWPvHjYmpmdOfEi8DI+cy1Fu/BXs2okoW1do4ZOUYG6Dio37ubmuI/bdOx84Gr7FVkpOHwLxiVI9b20CouBHR5ldi2jxty5XBWITfbwomjsCUT2EJi6TUvKTwhyh0KuJMdHh4GX1gjv+hfxYS7HV1MNBBnAGPD85QrgShE9278Mv9MfseDmMRNyxj8+9chwI0QN8dpHS0A+ZUgZ3sQW06K1IMAuiHgo9d4C3U2L2K0+gbFoC3MhRd6R17vhD9QyU8PN2yv4ac0HzWzRxAxAhAD2YkMCWDOpmEQALcXPdPZo2K9QzbcGTNsQroHDOD7Ptxt0emCd8FGWdBNgtaCWpzuJOJKvA9aS5IgfKKgiSY3HUUkQfFjqJnFFPR00FTViGhIluZnHYPCfB7sIbpEw6mEXx4BkY98QUSgmi7dQNAjya4sezWrI3VIJm/W0G8m5WhIytRrCtE30hTHBPxE8pr0S/3OwIJe6hBoGtRxI1CkyXZr0BcZipQcMNX3r3quvQYwAcHT3hJ0DJZCqMwvyB7GfwBv34GdOHr6XuIEFRZhprPKVxBjqBM8Dpo8n73zI5kXMzXY3pBObqgxZFqkrqm7uNkLUh8onoUNLwxpg3U3SINNBXrWCQY4aTiuwXZhWs9rjSRMkIccPGaLxoMzuzgeIVQrJXTuYYL7UeuGoEmHUP7Db1ugMFOwZBhmW7vM29CModmGLRfjeHEpGmggk782N9EkgBWhtJCDCZ+JqkCmQ2TPb1ay9gyJw9LodlHD/dPGTinZ0VD93IV7Bt+aOFuaaEx4bvIwPSdUbuRF+7cevRUI2f0QiZQ1RAF2o6ntbttDfId6A/lygkqn9Rz9anpKd3OQQ3jI4uYb2iTRgCyCc6yib4FTDjMUT7BCwfjDdfQeAM+5/m3FoGqJ2LxauTftkcW967DnF+60alTq6WgijQIx7t8+Br8WLwG75363dRHU585ozXIzqsE1T4WXyIYdYarjT1mZ52px0S469sfswV1/YhYZ+qWFwxRsp8eL8QH7r3Knh5pQ+1zVfUeOKolBSV6z6mfgZbU351IVlF+11V0dFhn7uDp7wD1QAzs+2D4+v2TS0Hte21J+2IGTtICeO+RFsCPbaV5ZI0qa57RdYTduA90INR74ibA7mgT4Ga/CdDZk5D9zX1FwdLlo3HRVWNx0a+O8UH3JmX/vXgllsHB1C/jCPv4DqTsdezv/gAvLYBkfFc898thJ2p2me2Bzb5WPX7jvW443p/1rdULTZrzfTxruNnAM/pjvp89s5Vxj/1htAvDGO3q3NJcdYDRZosXX3vxQnsIo31tdUXolNBwj93P2HwRaqWSHjoHHhHPAgvy+DJ52Y7L5NlMMI6PLpP5vVGyryCgtmSkh4nabkLUXsZM3JWQa7o4osrySWAxhmdPYHuEMstI3EWBRG5/OG4sjI39eZBHOm2P87IgAWrUG7Xsr25j58rU/FSlb2et4XyMa6YZS2tL394vpvtU65OT3nxJDuEjyCGagJPk8hrQG8Ku+x5ytgv1DjpahN6P9gvuFirfHsNyP2bnK3EEbJ4B0+kQblA5zJs/jQaXt+DSkqG3/Vp9tztvhe2Mb14+IVw0Pl7EDkUWhoJEez54+z6sSyHCjvsYWc/hHfy08RmmX1s41ra0xvGV5eNNTWseZ8+MDenlTWlCKwpj99ob+xaxG6WHj+7Itzu+JlL5z0KrIOQCYR/ahwcR7S2mHpp6ITG3qP4g98HNR5MdgwcZmQFWC/rwJrLDSrx1uQFxu+WFvVEjRpUmsaVIE0mPbGE3PcpzsUwx0u16GBH9MoJLp3EAIfE7rHYDaVHdLxj1xesfceLEw+++eB25ViPZsGKxM5sT2PThY77bJqNmhoz6GatewB0iV6rp72abe4mO/EZ9+cJa/dhipbJ4rF67cLl+RdCCUUTbAWOWtZ26KAWVTEViqmtbriaWZjsHitls8QD7OAIJZMRNU0L9lSCwsGwRD/J9fcuit7nkEcSAvecxseLIg0YUR+4YNeTTDEvFmC6EdTDTI5vIhVdP/6vwE0yjXoW+4BTVXh0vhjUQUxR1jkRLiy5/Th+kMYic+a5ZGRSsaBtF/eVBcnuk+LvZHUAtSXLLicq3q5Gh8T90mVzudxDLUX4CUmykupijlANlSujfcFn4ftSjVQ9znipcRqn9tFozScxHpAs1FrWBFmxJg2oejHYZPUYUBjHyKqu9O2UIr+N2jku0DCyGrbwY5Q41yHg28gv8pk/3dmAUZMNUsvKHFEdxTTu6z2dySsV/kAlmBB49xIpyHS00DqKXxhC+iHfZfBfqLkEJPU3Vlv0f/2ZiisKVUYBBU2nFVDFr3kX8TuxuHbkHsJvx/yjiqoHxj/+sojwHwiwSH4q5+XqqubiKJWWQRlHwrZDEAjtVU03VVNi3ZUdVXHCnpIwQaQCid91WwP7IYviZQJwZqdt7oemkSb+IN49+WvihaKYuST2JECxjnMndIZMeKhr+VsxktH85sZt1W1xmFRXeoZ1L+3LI+zK6lw1DrDDjzJtBkBGb6kOshB+McCdP7gqdnPZHoJN/bkzNTBnZctFlfqNrP7+9ZPNqfbxlpbnlOWnIC/8u++pIHlkcpJEh6GHYFuN5ZHb3AYby4lrwwBE06EPGuMGyPwf2LHvIKIby59TbhFaSACVp9KI1Kp7wx9tdxuCZe08ohL8V+oPEf7FM5KsIfdUNTAl+t4rp8X/DPFwO5nwCzTxvhxGN+M1EaaPXV3FVgQnpE+nE7PNzWlLSsRv53+64+x034p7gUPYdTBGbhUY6C6dUQCZcmsqh5FTMGa6aLhfcvCFd0HvUmyoYLTzURVy8sOK3j9kjB+a4oV7B/nz89PtVGrU1mscWEzLeITSx6N08W9PRfSuIVrHpCEzHJC9jD7VKOfgAMyjqvQ/709idxoPqIiuW6zmm541mNRjypmPWYFvYeFVohX4Ko87rEDUEG48nFWI4HmZr19HPszMbD6ks5axLjcJlCho6+jA84LnuVqd4HyA8pw/CKxIIjxDwbz4H5UY+02kGdQLhEaYlPzu3WIk5eCVAPjff0ufg1RzmH3vUfc60/ghPVT39GeGbeL4Xox/z1SjeD4cJ9Cib3XitThLxsR3IeXikQz6H7YoJG0HiHWfvMFYOrxjjQb3ACp0Ff5LY7yPsy8TU26F+NeJ43rILbGqYmCexv4iiBAthfKARpYgHgO3idm6GB4C9X+eMvaejZb3vacq1YjrqmIldDfphhhFhV47jpV43zNB7Drfdd4VviCluu1edte22YzL0x6ITLENue9sF29EMz9p0aK5Lqos9jUgNQjtE2n4I1fCXfZOVG+WByepqYjEzZhzu32SbPxyhNXiuzE0XwRryHNbAnkQGq0YGE9h9+gaTPLLXU4ft9VJ+kHxb+Eeg2S5OPQa8oT85W4tJk++jqbVzh907+x356xNutDTb/Om5AfR9dr/W/1+70/r+eNi0T9j82VlT+2grf72/ND5/Fy+NCYTpxlKDXOx0T8DfXblUei8Zka5b3Fgcka67/MbLDrL77o8IeH5XTe/JO6nY/dZQbvA6q5K3WJ8W2EaCsB3TAiGzd9+EFkjYuW8I38MKOsnhzS8fXkHsvK+gvfAzH0gWgscjw30vg8f3l0F9L4/x/b15NGRYCLjktSGzthvhdumbruNI7DdHzHrjrmzbJ/ZeuDuWhidyvkF18dSFSLO9LfURLto8PL+9JMd9qpPOcLPzZ2qRZ4GI21pm282J+68eneVG15a4r3Hui85yaezqIbqhY5d7H+MD45/nA+Ov5wPjVSQhUHCjEW809TEPTfxuNOQdQEI3GvIuVgvxkPeCgdkz3IB/SP5g67J53w7e4Bkjy+aG8WXzYQhpeM1HAZytYjIOt9u8wMMIFJYR281jpqGHJNHB1A3E6RiGfwJgvBf8s59BGpu2oewSLqOd85wsOhkhQXM7IEGNPhL090VJoSEcRxVoOidnOvloOkfsvfi8JI1GgKG/ECXdi3mhn9zKC53/K/S+9IGhNw0DQ6Wrn3dZ77+LS3ecy7QRwyRPVcxjkuf+MPhUt5kM75MCTXRjjQZaBhfWBhrRoBEVMYs6y0lphYwfjjCpkm62PpWKXc2K85XwoI85CbqfItWTMdbL7PWs3Kzx62kGI5+9O0PcVJioYJSd3XiwgZlsWKy4tHDTAfZfQwCq53/s1y5rZYQ+guolv4H3o7toteKzDwhBpaZ7Oro5cRN17TTaZ23fl27LlmVcWi0J3fJ+pklL/5lCZkCaIj01DpriQ4OfE34q/AwXnTv3ZGkciPYHbRQvuufH84HcWVILVoMPVvNYd+OIyBdtPDXFG/tiqoZCzQ/BUK8ssTkWWSfZfOLBnRFR7W5h/npPr1dC9C6RF8HMSakUiOyD/oJH2wFdfNOBlO69WsrxdpJ0UdO7Fz3oqisLM46nSNTJl5lZ2QgIE3XsUHdmIWqUddAoy7nC7Ld63zQreUp4q1yf5Wm7cE3wd6xCBAq6fl9mh6Us5QUySj3q2qMRfTfMiQoXaisUPI/iD6ers9eWu9X1uYo8uLQWSmGakh8uKSooMBK3zVfvctucHcFrqj1VWLjhbM0zjcw7zHP8/zJ3JnCOlGX+z1uVqkqlUlWpVJLKfXane7qn72vugWGAgeEGARUQkBtEZTn9ewMKgije17qKu6KwnuiqrMeK6KqIAq6iIqhcup6Lul5LZ/6/962qpHJ1ku70IJ8R6SPpnnqf932f4/d8n21LOU/r7u89FC9d5l2K10ZCzum4Qod6V+iq9iuUyqebVii8AbCSX9aj1Au9AllNr0O8vg0QjQKpxzt6WB47Tzm/2KCFtd0Jeulr9mCJYbe+1LAmPfbyNhJzV8SsTZ4xkUir3MZJcn90KBqOEM40oiU1TE458JUHQKfDCNFaRiMXqKW8xaPtqqDLGxc3xWy6WqpT0+6Oi265pJqrdaCZmHlAfjm30W49mwabqRN6C0N49PRw7PlTY1C9Zg0jiWgBmTtOjZiMy8nLhhbNhBHeoZuUVC/1NpjtUcq0G3eE6nriFq5GLMHRrLuswrr7HmbL9CLsoju784ImubK7kewrnouvbicNLjHQebsNjyRjGzeU5FAhZ9FyEUMT9L/fZhYpRm371qXlOweTFnhvxx25w92R4H6HLiIqOlzR5cd1OTO1EsUHMfTXZBP6a2pmyk0GvKQR0pVvSAZozBS+6xyo/+z78n47Uvn+Af4jzVmCmXoqYUWA1NiR5hoP3/HFzQ5Tb6+844TneaQ/3qD+hpagfriuw5k+5LiDp+ykQURdASG1aVX3J4aHkuoeTyS/NztVp/4nEcen6nG8S/1/ticL4GQHOLv19wHHIl69Hy/ZFcP6rhC3AazxwharD7JbZw9os3cFL2y/gvGk1byb8zjBHxpbyocC2U1TU0tZWc4ugfOG7RoA6Q0xCxEjuGANYEjSOLnPYVMaGulJDtZ7jpKWaJ2KgmFXLvnF7Fh+0RmdxdvRPEfjOiEuSm4hMRZ359nQapZdA3P4TQssVlhkOATyCg9W6YcUqxQTKFUpa3DxdFpkqLKWeuD8tnlvPdBO3mAsQghNo3SpFEXNF3JBW/j2OAnEtTBVqxyI6UtqPBqJoM4E4mIC5X//gSQQi8VV9HKT94GtUAMtKblwHJwl1h5d3jCikEBCLSOWvq9DZfB++pui1IYQUEP0hHs/MDI+LB6a3qwFE6Vh7adPWrNQI4Rn4twmXhI0XDQYy63khzbE7/yZNlyCIEUPjU5OhFlx/scYF8r7ToXo8RfYTFtqvdNOD3vF7ludQ8eHmz/ZTveCJ33C6oZMAlNbsYbsCwqIEt8v6UmqT3UWW0ZTQl3d92jKq8B3ymC2KvhOTzC+Ezqwh1QogyPlfEpiA0r4Fu1jHHpprPq32uVlsEFmOsOhDgmXwu3hUJUdWRruxoTUWESPUPywR3SgxIIrD7tMa17dAXlvQC2iuq37KRcqZEZ1VUZbZoimY1IxjTsXPUhAa4dsE6IWlKBJvKNY8ibkJG8go65+NJAE0a9GktpaJ0mdm1yIuySp19RIUouUJLW0RM8SKQR0i4nUgleroJJjG8QKB3SfmMlOj1/Cj9GR9wdsaskhss0v2fkY5jFTJgCjPzm+s/cgZ9VqEBxEOtp7dnEnmXUPciT/QHZsR3RzziSMJYnZczXHSbuxmnHa/RG7uE5rQwWbj09Hw2mnnQLNsGIqhUqYEh0ybd88MhTz+9+vpqUwPdMhtomBLPTpiWIUCCEdZYBtZeb1fMBzKJ1RP5RGuA+iNQdziiMorGtetBxzkD7EJomPTQyz95YEyzBTJDc+N4G/5MYoTTWBO5YxwpafFrpFQ3+hHGbnvyYnEmZEYqQj/9DGUcp8s1Kp+lFEkW+z87MYNpfLOEX2hkmatWFz7PT4Lcg2Qd+5vtczLhzqIA1rxa1mocAXiMaW6sy4JpgG6RjtOm45CrONib4aL6cO1ll4jKBtu7aAXH398o3r9+mm9fuP2voFZoFKIUe2UuPoscKd4YmC/9TEssYHDGW93ICGI1QCC8WYklQ1wCT85N06ivLu0iazSb7dwkrIr8nOwsbthZXNoEQvdPDiklH7YAAwLg7RHVf9aj1CfrYnQg7gVoEEYpMXB3fEaw7GV7DaGvQY9LhIYloTI3n+CIq9IMgrt1CZ/JpI2LbBdLMWzLujLI8Y5ZDRFhu3q4a+h2srjZeWayvDTZhA5ApbTYH7zNpI2SS60Wwxo1ijGf0bgmKJDgiR5JDwqJUNo68OxbShqLJ7lFxYv5kabMi/on30g8++EVcCLClOLSmejLdaEvY+p+cCAk0QQxMYj1BDIhEc1iSgFtSorKM0G6B2ZFI7eshrKJVNCMHbmIrLDvxfDM57teOnUyedUlTLdt7QTeXynlSuZmvCJulpTCMozK1Fkp2+eBZdpEu0HNsTIxDQOzA0bEbg+xVIJ3RtdGIq+sGJIyf0HFBUEVuGxBzxd5FcpcQSvf6oLGei+dGDdu2ZCETxxuwBi5KUlocOHFo4cWF6+be90AFVekfYcMAfCFH6QOEq++WIVj5yZLcrR+JsPRKywDQG93N26RPjYnKmFDYgrMebVG9vBwHM7LTqEMBUIwQQodFhvpdid4I+sqbIh24lYfUcwQ6H8+fWFggFtx26K2zsOnwX+cmqiYKPdDiQydf7D20JuXUVEMF2x689YwA4QA6h7Z37FQc46ZRTvFlOOrrD7kehL8f3Y+1oIOz4RB4rQXHGzpUi2NpfbMBLKE9lNkkeaEyFVn+i53TkQhWOhxb6i/5cKesHwjLGTxWCKu3zHooFtxx0gB6emBrXi7uKiXQInRxdT1ItHe6CCcRPq2MCD07OxoHUqiVFqa7Nz8dV2150QQmlTFOy3UaaQZXsRNeTbO9uAdf4HbauFp32K+w3ZzElaD1rQ6nXvN89IluyyPIaR2/Yc+Zm0nlzFaJTsdnT58jiKQdV3ITEhW32+Eea9viHPXu8vOPMhj2++aCd2OOH7SJvaE5snDc8k0WXyA53k5kNm6ygsD6JHURJz45OzSdFMTkPBckqNnX1/SFNAu9Hg2wOC+inKxQHt4dnHMcrqZC9b44jWV3wQl864nhJVm8oSPLnPliPhzXEL138329Q/5d5LsFDjtsbdjzoeE+4yL5wkOTTEP4PQR/dPpzZVA9nYgZzVmxPudoLRZLttodQEhJ8u5GpupliEte8NMSz3G3toUeM5661Lwf3yfoSNy3+8intlypbiAEx5CzVyG7y29U9/Yq7hqDEc2e0rvGdnZbnbe7yvBfL42cXYYqP+HYBpPZh3z1sgbg1rc4OYk+OqHVcsqFemp1VrHda8rVePPuALdPFcZgATo8mPWRLDYey4IkmDDr0rmH1oTHZsqoIM3jQ0XvcJSXPMctI450ZyWZLCTULDRXtyfwGOju0WDC6cXxE93RjmuVyOWqMPy86juVNRypRdHJEwqGAFcpDgkCp1eNgMEhQzfOwBkQbzBw4SLukSkSTafBJVxxEPCPJYg8kWfsIQF1j+LIq+hX/TjUK6UIgYWgZ2q95saQAgh9Q00m0Q7mdmvGgTifpqtZPOZhFLJQN2QCsdAWegmTQQQVOjYhyJ3EFUwviX46eSs1lI5JJALfrspSJePVvqSkbCIsY5Hu+I30XemIQGM2I0/DXdwyySAOQzoTYdymYqqFrIxsno8d84FiNhhqUOs+CjRS9CN9IckMl+uwQbATkjJkfOWDn7omAaeoc64MXpUAqcOx7j55efspDjS3XqbE3UWrs1VCKgDQUYdstokUmZ6fNM7hUsWwHFq68RGoMLGYjUiaXQmWQr75hRYjsj3CP/p4R6t49mDiC+ZuugMTRj9jtEOOkRlqbG2EImNlFiyX97fQP3MtaKnrRBih+cFAxxGccLYkSdKUk0NIbKSVe/STV26OmAb19NLnnqCOyO2/aLRgjxVg0PBHFHbr8Q0ZPDcEhyoCeurrQ4dGUtVvIFnMQlfC2piQWj9JGCNoGMWxpwr8zP0dKpqMROrgOaj41gqxqKMy54Z69TC+klbBBuH/d4zfSfmXshWF1N3oMWwNbov/rJXA7ps3KqGxheK1gzF+4Bau3uiWqvmelmA2TeeVUOlFbnHhMpWtDWJO1s5WecNbo3VTdOoA14u3zquZFeAK2CuvXYitFBypsEea28HOehBm9EbHdXNqAuX932yX05VIiFeXJNzz8NtUg1VtFKFBxIOLB+THDOaYQPj85Pz0s8ZXxCg+eGxI4In0zwcqXI8+t3hdAR60Qlklh3fZm9VtaNEz5roKH6Qb2l0onP9CXQSAZStlUN7rWAkYCX9Vlu/6IEsiQOb2hX9x/K7N6cCG71QCwbky6V1YCWPeRJB1kuF4MRJXkjxfmxk8rCUBQobQdBsz6Liy55W76PnKjqwjW72AfQNWrJw2KskYlDfuezvJmnutjbL8PszP5zl5xQgM4F6TedrPZg3rp5AZJ0b2tXCGC+bEDOhWO62EHP8uVL001ypf+WJMvRbrOGHx0NYfAaOcNXb1r5fmC1BS+y0xhwfcK3wdBJGuPFFpZVUT2m12QlfRLh/WlK6oeux9tg3y7g4pprE+9EXlq0Bbypo4KJte9vhKAzkH4BJYT3pIu4S39s5997I/YgevwznKoS9haOWjEGH903S70H9rhaGpjJmg5weiVTjCayya9wWh2IqNaX13hLqd7+4cIlX4PDsKp2N1vbuUgDCRmcpRQEBeWKhg/4V2hOdIsQNvWLAu7YFAu+I+NSiEGbUowYCWTQU4s7Pp/X7qhtiK4z37UnKY9p64Uy8lybom8u7ZiJ7VfMd0Mt6zYNjYyKSJTIICzAHAO5er9Ht0Z5mhQ3dnMvm+inVjEEISr656VxJq+RsrtYAcNrSNU0+2iDtDa5aA+MY5yK3XGMLN8jpYdBYdoWxsp0dpQRGNc8gdFoxmAIeh8U4mStWNF8EHA9oBf4nIP0F8i0VkwMmcghRtUyrhNZojGMYq+pFiZMMvqBVhWL2tn9ci1NBlgGmHOTr4kDaWQQaLnY1yq1JQP0PC4kTEA+ED4Hbd1o8ArpmQjFcn5ISsEhj2Qs5KdwCPcBaFMJoEWI9OITVrCkbfsWZYjOL/KaND9L4jGdkD4cSNtruRm2zbcter76u127frsWeNdc5f98LQj/nKWcB6cC0faxZrtsUE+2rFtbuigBjlf2ds0B5077Zn7Y72vvuDtq4dl0b76aUL2UBAu7Z4XQrwz6gQKLBwV+SB1/u9h8TrcD6cVjsr3aGPsZ1rke0Nl2kv/eD2gvFIZVmJDtU76FOuk/5sG/XxA8QclfagybGB4yFJMBeNMNzA4Di29Fb/TPn8vlmAY/KsbfB/r2c1cWyf1dL3TFd+5ON+0Dr0gK09ocC3vanUtMSHlyDXDEgwXeKCInhXLGjm6Yst/ct3JoUZ3cp/XnexCq/zvfvuhn7aXNaCyVR1/1ljjmi7fsXJbPCVcPMT9Ckt+kO//DYBw0R97cAfLmy91Wf+1t7i/dniHhzi4pStxUDRjMVmLKj9aab37712vHtAnYlCQJZbOvbxxkS8Ya7NxH8G0Hh6Ow0m+qyCba3Uc1nWLtjDqjpw56YqDD778pNnZky4/+OArTpp53po3X2SlxXhRcWF3ubxrLp+f21Uu714oXtnUIk6uH/TO+npT0zmleP4Y8ygIS8p9BmUBJPCjuLuRv7S1zI73QB88WEluDZ76D/aTZ95cvee8hCcu2NOWPDOn6dZCT3BZQjQHV8mey1KeHmnVl8ZsealIJ5LA+0CNYWnYLmtJ0xkua7eZ5eC0LJnkJtwv2UAIFSQlDm67VkpFF5OnSZIA9yGUK2QV19UA3C2VwQwdjeSGi7j1BZgnhh0pIbIJ6mMUmvB6iZYEMdQqPBl2wQsU5hSK2jCn+lwXYovbokQWqmMpvcQ8MvQj8zywj/4EXvfCq8b2Hr53bJY2zwpKHAkzw155nrojrO50O3RPZSjnoTgO60o5ILED73bmtChoDcfwFzbmmh2DfHJnylahpmVInlPNMlRsy+EIwIeYz7Qbbcb49W6H5xSXqXl9AdlBMcSaq/aQ07Dp5vf9hj8NtMjDwCz7kO9LdiHITqVVRFa3cZuL63trBx0RA/X4LB1O6841YHtsHn676I46WGmMDBtu3jRERmxQrHdE/VIXdgu/sEi9IpF6/4BNxrmEEaReeDqoYjrRXGrm9FlzIiSzRLjfL1p6cjaJbJoRQW99GBis2VS4SN2cknE6W93UeFrPvL7tnBmX/+SUPLiTGRuUNrY6ZNA6XbKZ/fwxf0LiYhYGXSsjIU6D2JuQH0hpQ01hVACzKQQYgYi6oZIl7+QNjLqQ0XROSO22o7++oVHniPfr2cpQXqKvIL+gw2jgszYOo4nGTFYgQevDSAzSjJ/ZHFEM6nKnYzj0ybZwX+YhKwnlYpbou04FN34eCTtqGzRh9z7f3b6HeiaAD8yG+rKMXpwsvp31nN9DnyD55wFY2MO92843uvYlplqtq7tz9vsBmJ/Ul2FVX7+i+0Ze2Wp4Y/se4Z8Fw6OewHUYF3dHG5jiWkxMYh8s9WVcLe4BaWdJz2oBL35u9WbDTOaRnk3mxmaATXVLq4W0+BTXrdIg3sFMge/PFG5p9DfIlc1rz/smULmNgGhyMMR+70PCwvE4qLfRRGd0HA6Hzlh3OMYJH5UwpYd+GssIkokDMWGvpU1xGefb3YET7J0czPRcvUnO9TTgJ+ALzpFEXQ2kp8mdjo8RlCUl5HgZ1ky8ycd4kiSyadfFwHRFMQ62oiRglIRGzqQLqCGpE0cn0FaqmhTiSigRMKDrMJRkwJK2kiCgo7oS8i8/AZ6MSN1LdivBvUAqBFgBco3rUPBSzZv4aFtvonpIIozvIt+Brqi6Ad9uzaCzyo9G9LHYr3/il8X4HKQjII/Mxrkl0FCRH+MC8V0bb/umNlQCBhKNcRsnkAaBJ5GZnZnNfJZ5EqJ/D9kcjAbhShT2PYoGRx68outRxPsidSV4z57TalnY+r5Fua3s8SG9W9fT2cakKKtqbTPbF+wbJqSh4oc0b4y9zRI5RMXwVtXdg7uoie/SM6pnE+MbVDUxVBpKtmxk7pB6xxr17/tsWTPtXEtow7ZOc9QugBuyfJcYwc4kEjZ3kvu1vTPtTem/WC2E6Pt69rQjDnJ29Qc8u7p6SK0tTZuam9FVcnVDY9ol3RvTll9uZ2veQcv/eA6Y2qoImbw7dI2bpr/9m1W/M5p4AvCCP6HMe6jvJga1hkPoUlpRtF+aQ1A2QqdodUS1VtC4AAgVFSbBA+Gd4GSLXRtyjwDEJhVxxdgkWjsquPaxBHeJlMqkQHON2TRXpLTKRRtF3A7pKrIYgDyEx6wFkhULfWrQxyL+WEqeBsJG++hjI0kXc5jR6gYfHyk1Bw8FvOu8vYJqPM84r/apnyynUhuTmhf2+rEa7DVX70OzYgvQzZEDagGIANR2MCbbAUgvIUjnwIHmXJ5kKEJKFf3UGgOHmP1BT2DY4T7gokLbYIFb7Z18BruSX90rKvbhGnQsTgdFduaOVsfaRAp3driZP9PlZv43djM/wFCyl3pRss60yjpK9ukGMOmJTWDST3iBdRcXnKv6RnZVf1BlJvAo63cbpAmYA+fLrosJfKOWGl/+c1vk7G+ewaWvvqOeR78BfdheJm0WJRaqzrp5xaW/roFJ6y79DX5/fekf4vYBZnCQ77W+z/q+NZilr6l+mMLHUf24YxjZnPmGmWKsAtUACSJ1hx5+XslN1DKtD+Ud1DQFzDkAtcvOJQzSMB6AGIgOqQtCDLQxno7Rsc+yNhTPU87gbdUjMB0xQRVBOtbeHS4WMJB2Ine6kqAprsycBg0NhUAmlJXssOCHJ6MGQikVk+oECHuyATQ+4zxfvtWxnrrt3N3Bdj7SxXb+1bad83F+DVPFDilYu5Q8nU1Xpi/AkLFoqD6e7hA6no4MkyOYy6AEAiXtlbDxNEJvfH0vF6Y/S6VDS/RwsKIsbrs0QX/mx9hPfo/qE2FCD3K/gwltwqDiF/s+5/s15O2+pdWNLhyGfJYN/obl0U4vJqIlmMNZocQjuthzdm3YtjmsPIiIfN8mW3dnpRj7QOjT4HJEbJu+uu82d7bhy5pmG155U/Nsw+vd2Ya3Yh0MayyejGpmko0aof8oQjQep8rlk4MYLYgxthz/70Jwzxu9Zj3azaxVM2JSJziegGEfqUYxmVHP0EiuN7PEL798W+uxdmpfkw+vDC7tWFKiRTunrQPwFcvnCrHkGBon8GjMocIE8ubowgVqU72irATQAH+elOg9mHU951IRmfJ323lcsqduzxetZM+5hbn5OedcfDG7Em+wz8WH4VTRK/EGKNzuH8i5SDTeSwdZpBekVcODsBc0AULwgkrtI/JM35XV7ylWOmfEANCogUD0hGlIQ0UjHwmP59kHiXHLwwIxVTmqsJeFxfRYDBgBOephuD4Dd+rpejqCbpYMcKwuA4RosWRw01JqMWXNcOyD8mFDNQ7IATmTM0MJQ8+aaFuXo5tT9OMM+exanC4BFvYApVE4Y9a+6HtgMDaGoZ7eGVHOiBJ8j80YosMxqCLKSb6t7p5tsivaVkZLd1RK55Ki1mpqr5sSPXOlfsoFdDWcBe2F596jD5VTgj9k5XUzykZLXXzcNPeC/m9ar03dyyZIbZ/O5aa3swlSa719XzKZrg2gwixsA7k/PRHSMRsZGcC4KhC1nBjemMCZtxGDBPq6emFGr2Zm9B61+gI1hDqXSqM9NO4yLPgf+RhyN3R0zdtpvnVVeTcgJ6QYi8aXuqCHYx5Q8cIIocKhthhiesHTNvuOabgvuWk4XTeQhvNDDNUmDfdjhqt10nAYvxUs0HSblByS5aip4hKg1OFRRh0O1ajDNp0YQbdCn5olqqZFb1naNhiutQ3yyw8mAkjsNWbmKMD66jaZuY+3DbKvOv7Nx9Pg/It1zvD9rZzhmTO9UOInqveqAGbY0OFdjdDhtx76ZGqaO5z4BZarm53NfK6Wq9tKc3UCcnUP85No8twOCPwnfQ/6Hm/O1ll9pOrMNV5QjWm9BSqOcq+ppYV6Wh69+UvOeHb7YDHo5eXmhkBg2OZfFFZI5u0kO3vO5C0N6Mq6BOcL+ERBnEM0fR83RoEpoleYUA5jfZRcPixBh4hMGI6ruJGmIBRkaYIS8rCGEPDrPKlu6pzvu7XnZN/y3KDur1toyh9CEztLeBkJRINZ3GY0x3cOyxj6TSdhiFyToeJmQ6qwKDg3G5wjf1AEBosUZzfPlrZ7E4S0JTEFsvWv2Kx0HEGLDXBqtHCUxTqaGljduREHPG7HCQsOfI1+CmFjDX0/Tjs+LM9Mw5F4zIJ0Mb5Iap939IvOrK0ax631rbKEuwu9Ux6q9fJ9yNzXmNbCpss24RjAE7H89knPC34/FHJoEA29AFLEAlWDhArGVeRstHXGgyx7mBoe1c9RMLqVDB8wGilVlb2amog7OpOYkAhpxunRsqHTJwUWmwDNoon3uxjvl3fUJVe9hQ7+rnOxQepE6yIFYxNyqRwMRIA9xMJltMeYWASPlGWtODVkjBuGCCUQzC2M3xPz0HB3vJJpT/3uZ00tSNWy1Daz+VzoN23f47CdNqkDEMq/QfmLEoDpCqhqi4OVo2vneaLzGW7JkXvg1LBo/tfe/dzswpz30SPbG3cWw2Ue0iWj6xkFidLqiLsE7JL1AfXYavmW6Az2sL12HZ41XTslGQwGglaIggOwwOLM0ka1YX0J+65EMBqy2xaR7jfMc9B+TjZdMN4eiTlzwmwgFdJ0cmEv7ZfkSyhcB4sa5qVdhoyxIYghZ0GCij6sYcxbYYRNIeMhG+KIrl8uVJSm7xFIYTjPoIl5OYDTjBUmcMCU6NXESJlevrHLCqcP50fdWjSZnv9xxxhu9f3735s58N3ApX8HhvCVHoimz6gVVG8dm0/LQnJhyqGKAH2Kr0pUgo4rVTSYFdwHgMvffGeilv9DJHncnbYVKb4FRgwfsUeZdETzlEWKm0VBlMYYbBPHMny7XWz2YCEeI3Qti/RlmJ43u6a+G3GCTp48ZkxArc93ovWMxwSK6yHcW6i30WmP/1sP1gPTNEQbt8hsbvNsdWPP5go1OH2rIHurU9z9CigCi0naE5oIFx5KEbrnFUGgsLjato9gbCB93bvr1pQupFqsiVmpriRD59bsr/qDmume0950M8U0M92Gd2Im9VPwoCRovD/g++mqiFBdeF0OcLGhtZTsZ+NaHTLq8KP2RDvb38zzG2hR5J79amubugOlYsYKmDA0mloenNS3XENB8Rx/VWpxuSaLK+iKFTqibnF/Yp/UQnF1bzuL8xPTMm2L874Tkzc8xINf4TsE3umbWfl6TRIkzbE2c0BwHHOwssgLaAI6tYCcyh/WSszJt0mc/KxDmuTaldMk/ueokZCdKYl24el8vBNP50aXp/MWWNukkxl5DsuMXEoFSMCiwMweRWj8MtpMQOKlWRYCNMYJdKX5xqBjrjFMEOIz051e2RiucLPNIQbfmaIyhhZxZDm0yM569KDFa/s0IAt2ItuOOpQTjvPs76ur7/T71chCQ2xBX3lq624uTpcNz25+4S4PcWXCS1wZ2nvwDvJOhk5viBQID2xzxJQRcTzkRgt0qZ1Y4eCth7Z9jTJieF/Bciq1l1QP7IBmIQ4ZicDLOBY5rE/6fkc1g4PCQbBUV1eyxyp9j4VV3w8HrwM2gjssvKGUWBkYMr6KO2NpY3V+dXfGdf3TJq4JgtndAT1CTuzbTSHVB1fnp1Cj/AYzyknfUZDFfQ2eSh/9yMMsOKGfbepBLrJJHPvb3MhZ/TUsk5P1ctaMBqOxhLb8HU+fMhnKH37E3sB+taKH++txvosLxiKJSEDiOGZCtL8ZrT7kwv1nPJyviGacHWjGOdr3XVxEa2mjwb8yBGGx20QjaKwxA/6LReeXo+99adZxUGKujA6H4AjcCBHujWNHlaVFxkVxriy7e2qEznksSw5NjkXYlJjiyjLxQ6PsF7aL86xbixO5n6+q08ZptFl+jM5HRMuwn1OKpaJSPrKsUUEFGnwFNRAdiUUmTbgxlqSltMR0NBCE48beWpbjybR2TmhMlXmUPnB23qmVZJxsgWQmMZ14e3QsGqe3FJsbCNQ8uqjwA+AIUuv/Wqd2nAO7teMMRQQtMzVsN+O8nVP0sKROaVJcYGV+JAsDCLGRasYswyA7olh/vYZKRSaf2LBhPGkuhtH0hTs9kN6eVoZkhQ8ogKxmJyS0qCMLidgcp7UxEy7uKpW3WDGW9IMvM4bunhMgpN/tu4RyOYlHVsHZ/W80CF+g7ThYF7sK7OY82ZRGV2BRjs3Z4VG897YeeojEGjT05c6Ke/L1UFL9QXzSimdsJpuszViPfl0Eg0+VojqmyGGvD4UwswHJ1nvmNyN8SWs/fxzVDMMSQu/vrXOnQS5vdRbWH00b/3NJuTRUCAQBkTaQeMBhEwllVRR0eDJWuVDfGIQ7CSJlXB85v6d2HGA7U+VSoyD+aK96fodXPc8W7wn+WG4fFu8i37sGs3hkRSW0HZqYjYs07xVZSw3rWV7bolV/v2G2k9D50Jq+rsgqtGHDLqAw+XQ2YC8TkwFEw7RoN53td9Gqry1bb/SOwssWXdkyk86Rn13t1FeZGPqljWLoi7n6MopYq8q+B/mTsdEO9r2uEWDlipi2d1KzVVwxG/1CQ7JB7LbclebVZuUwz3IvxaLu8J+G7pbGXcnd6YqP3CyDKz6Kwc0id1QPwsGVbJYhoTolkLuZFikVqg6TUDzT2RLCIT3gNQReQk+qxxT+N5c30LHYsAkbNuukVzm0QZMd6ZAtTGsRDyH/sxFbOpuQC+U8jCGphKXN1BiMVBooCJ5sGD5PMk38FThyAKxBq1xxbGpECpXxlvVNKJeCxzbsVrhzY2iJO4G1xF2ABtkv9dwQN4C9a/Z1nPbQCve8XrreTlvLDn+qxwN3+Sddm926d7ad39/+p5Ntez+Olz/ajUEwBl/Nvmpf6vvIgK7a1ZAIzP136541vMeDJNjdHUkQjkQokuDJdbqH/6VfNAHadCiagHyk1RSu8JrCOS0388POWt/o+8KAbuY1aij236pXlwekjfjvdTKD6pcHJHXgXtKXx+ZnfasnsL7VkxHs/2ObrtX9fQ+0dK2e0NKgeun+OOEvb+5NbelDldf1+P5KE+iCYrF+y3SU8wAQQmrSMjLR7gxtGJhot4myjegO6qHZ/hGWWtmJhcZjr6BJbRtKSm5EvODsYeRXmNcN3RrzvSGCk1wfgS49GGY6ybAsI/0etwDAOo95zE40VHd2YshSzACSIkHTsNjsRImNTgz5yfIdnCLTTLgo0huRAyud49/Hi1F2UwWjV0tFBXEsOlU15BmAhwhTVq/2PB2qJD8b7i5gvdGpJukByUqYHBvjKHBvw5AdmmmL6IFx8znpTTqbpfjr31szmhEMGNMWd4hWzIF6HlZGp+bib/yeNlxOupMUlz+PpK4Z1scwNvDNuAqCGtLuoiJHZC5ZKATTEYwbkw1FtERJcW5YLRGIxsL83WJhuBygPh+/hU9AxReTOGAC1VRCh69Aw9tp3Lkj6BXe4nsVGgh8Zm2PSF7fecndZSyB7vGb3QYCcUTwKtAWmhpLp8UMoQmUJW9nqeFtT8VOLpuruaw/+UlnH6GB4YPOHuTcTfied7EdGAk6vvMFB85v1sLWZrJhxZ7SlEYa5iDWOlIxNGnCv8orm/zO9pN1260uV8oB16tGglmvu9XaaFDjXlLvIwVRjxzWGDtF0ykqHzjR20jqqMNoL6qcTKfkHdXvrfIyx9YuoS/tcUYTppcztO8LrImMZauwdEhHoa1Uikqiu+Zso+IiHakN1nSaUslcU6asY55soFkyHC40R3Y2TUMBUihHK1mDUup5mcZNoqWqtHMzYKYxkBB0XWjiEbfyQaidA3urZ9VyY9Ymq11mjOYc2+bFjvPkxT7ozYtd3SYvZm2K0KwYtyNUDo3iBwc0AEVV3hzJKkZg+VY+KGCKKGU/cWEVB0z0j/ZfBk3wekA3oa0NQp5KPsCFdKOWDKO1nuZcGPtn1bmwTd5c2BMQZgThtL3Q997BOG2Db1Zcm2v2i25diY/22kHRt8/1dL3l8FVNLYepbIK1HN7UR8uhHWqjWTzIQu130p28/0LtpX5WrIdI+7xeIu1nrWXlL+u5NebI/R9qv7Jh4U9vWviPexf+7Oq1Kwfa1C6e4H4Pu1hCoH07bbFqYkdvIxid2ZUeze9vM6kjo3E8ADM8S7mpTVxp7gXyzhPPPHFHW5j0W1tg0p/YPxbzJhsbHVMzu3J8cWppqsjXudKze044dCbh4Ukfo2cTOqkRpYcQew3VidJnuETpcwZpQl/xmtBx1Xc6RGm3nFQjTTuhe4LdAjdSQerfQ+i+366H6lMDityvWrdrZFChO/loH2cO6396hB0qNHJ/LRuxvQ6Rez/nRUvgfmJL4P6iNrbw7U+1t4XPOLbwXdcWLup1Cf2Djtz7ug3e1RS3+1FpeYBHpc03y4CFn6cr1Vfr4tqrKsP9dj/yrY2ON/TXp0i2r6W6QpSeuxzf3NzQeFAfDYkH9FdzMXruX6xe39ivyPtGQBKi49VfjEahb7Nj3JbsUlh5luVRttb0ElS/UqaSSLq4TqvYJNwE24+sRWj4xGLFvo2dOM1exjlXxBe3AzUqPpdgN3OsNDrL+PT2z6GBJWTRLCi0SWOOJJQQGhWg+R9G6YaetLfSnZtHsUZUsrHETIe8jENwY6lGKboD2l5BeEswIgdNTFPlcZuU1FNzBUh3QRCD++iIBbKZSwCDZ/pGRH5CRLyGDwVSYY6zDBzf+W25nWYkouISxo47hE9lzzJNUNMVPUlDRXsgU1ANgw4rLkTLHKQZwSA5V0TVzwowgQKgsxBrCHQgHhq/OJHFchHyBkjBMcGNk9W3+1WEjgje5GIoEmEvQloCzXfYxdakFZmdnzXwK2Xy+AJyVEFF1qwwZBQ0UcXxpbiREui5IyZFFT9dlPk3pLbcnhrjyVWR8QAnh/HzY2NWZiFb3anGRGNYCYmaOmy8m6UfAhGAdbnshonwkUdVLwqlQvGoJvP02aD9U0FtWdRE7qUInPFHCSNBMLbvJ2AX8QDi34esUWOAzy0ubeHirSE+bVOoi2GYeVBzYYCJVUf58FtF0pl2tY0eTCw54YQ81L8A+sq2mdrnyNI2bvH+uiTGCBuYez2x0WgM/WX0jaIXERO77fAfXSdMcW0H/6dAEe0G/+/xBv9XIfiP6U3B/xC6yeQgBpwIMlAMXDLjoWHhFDjWSgo8AnqcTzreJRUgR5g5QbI/oSxBNzXJRbAZQglNjAm2v88htQPfMIZbXJCJM5iPE7WAGcppExdPRSZ0TaU3FS+ndqSUkhwE9F+QA+mNIg38RQT+Ig38J/XCEYXiDqxnwH7jk72crI/XOFlpQy6PbdA0BWcosmk2XYu+ILJ7hPa84C+Cz4apzAeObD5N6cjzyCGkgSmhOYRP788cAmFd040uQtmdssvciZJoi8+dj7dxNfeCPLAWp/H33XIK5ExAwThJRRNLVA+JaMHm9XIxhUQzjogYoFP4/uFiWuTp08Vn0LKclGkXoyTnI4W1JBo6sI24G6RMNsFVbyVqJCLKIUlFA0UWmWwcO3klFGZ+x4GY1RkUwvBqlbA92SoaN/2BcICysRkX+TE6DJdlHz5KIQv7sdDf71rXPclekhGXrHsyYt8qDIJ2AdgWsfzEMyAGeK0Uj0W46r+vZDITzSYjFwKOwSxf0C1rgZMDwCyfb9F3CoafPdRT1oJdDHGplrMY7iWHMCziFGljLpVWa7FRDOgwGYDRclesmLpQ8NMKdIndOVhv7ppUILdnhtobjv1xk9kEYXSp6m/6jokM7WHXbrukMVIBE78yKY5NHulkMW7qlGj4EpfPRW3zibvmcwA1H9oq32w8Udv2vgNQRX9Wyy6kh50L6Ubqy/w9pDPWcHo9sJaItvrLwWQ3uOCajq9nTq3w6bWdYeyQegQlEh/LgrzH9/F10i+s3kBakiIXtiRFzl2LCa3t4rpo4BqHtd5Kr2hRPWzY92PuaV5FN/5/DiJqxp2FmVO9Rc1bSTcQ0HZ7gryLDUJPDHQZ9IJi4XIrIIi8YtWBMjWOleNk8bCOOCCRPFc26ag4mWKDDjsaq3AVrCCI6euodTqIIPRJRmif5E21GPltXWPkmXqMbBZMyhQPrBQj7z27lRJUerGXEvRKOgFdj+QpUuh6ooz+be+/HLrPl5qOqajM8jY86BwPPMhHHATLf6O40h3AYo2Umw8DrMwS1TeLLLytpdNYmoSZhE1Zd5JqxZjTde1yWuDRxNGR1wWxcvpZ5Dxbqcwk41SqLFgSeX71zVAqi6oYU6kPIgwp0CmXw1PzC/FvGqVwQsPTDlC18mXkRtkIQPUsoJ00qfwrQWF5gxUpdSSocNxphKuk5NGNlUAilFYMLOwJtPnHtFKRCDMtQZqKXxNIZVib6TEAFhrRoYDAn0Z/QUZFuY97ijd8r0Froo/U+8yb2RToTp9bqIFObY/QJm0xoj0cvvkdZJ6NPRrjRpq+kb0D2nsWHSV53I5LipL7lNlDxk+m7WNSdxgKW1Du/SBUAG7fgqhIlItDyYvoOmSp2kjWJuPl4PQBh+3eHI5Ew2EIP7gj1S2HHbd3i8aQp2E07imIqIM4nmRDzp8+QYy5RRxfsj5iVBcIeTBgBBx8qnI/lN4HHLCl0gWDwuNYBAflIsTrQkhugFQkbEjFIl6eiMxryigSkuxKUHX6q3FyQI7K+KUEltfAP8XKYXLCQtsjnVyqGiNoU0d/M3lXytrWEXOCOUzgnNDl/S1b3mtRkmTLG3+GV9fsPq6eLaz2zKxrrpfR9ed3JI9sXtOiZjVS/etKs+sZX+LHzoK+k8m513lJHVep/ZIynM0WQlbE1ezg+lrPjZsP3L7gWc+Fgw7fvdh+PU+cWK4v5/GEfMWznJ9nq7n8oR4oNf/QcTWn1rKacIlI9ZfNDBp0geE31kMhJIIx4RM71Nj3S+Q8dN8/sOoeIhmsC7fQ9v6ymD/beH85LeRtykGis+0ydHgI9Wrs/h2Gq7eP0GH0ZrLMLg7W1t7MqGXPOLuYy5SLgMMRrfVq+/5PWy82Emy40/Z5b7SLCflAMaqE4BPJpXD1jFA4IiHPiuTtCPdBpMVlWY+gvRI1HySEU4qlq6JNjvsQ/alCMldU2X1XHio69x0+fZjnwmPX3VXudbejdt1h5G1CICHJSqVkrCVV2ObCGcjUZu0WyYyTh23okKzNK2AH6Q+4P3N/RMvrK1nLa2dvodZb1aPvMUcW3b0j0mV3eAAOPHBkgbWmluwlAzKAO6bh8Z5B3ud9wNUL2/gfV1Rf0cn/wGVVzpmlqbmwbAazWwCRQwHN0EfDkPLBtAvzM7M5ayykEE1KWND6/ZE94Oe6D3is9oDZsmRyqZobMt7ghlQx4gVlumRSod1QUymzrGAAew4EDwXTPqJGBUI9xx0BPsfwPYt2q5GmbjUUo+bdWcpFcBHoAVZuALCvfHrRZSINjCeHtVNpRe04qVPktbqznbg73GOnemDDcUae5x5k1fNcwHrrreQ5xQ4j3woYgBvUekO/zfmtw47aEwM3R23G5hSiU7HZ00DNeftKzCZOcQ4kdphBMC2iNxnnGQfKZIez7BA5FovgLBuuHuMimMx01KHfgF3igd/kFcq+4SLITK1AYHLoe3/m/oD987r13D/Nm6dlN0nrv5NoAyJCJc82uqZpWx3r3VJ/WO2WMupbKjOT8Oyog0h+Y6rhY+8O86EYwT3hO9J3IRIqSMa3ffZ2QD0y7+0NbU6k1KYc2LTT4gpwmO9kTp2k47/p/QxeLR1D8Gz2eHk7FzIZj9E5BBdVL0VGxESoKtJ0CPrRI/RhvmlunkkHwIU66+z2uJd3HLTnenIeXauEER0O0HzGCMKi8UqAi/KovMJ9OgS1BVqyw9PjyfTopYFMLonsePVFHdAttrcFdAs7jl6J1MTaD6QmD5naPd8b+3GYaka6kl4s7rbaUbTUeBT9Q+0oOqHzUdToIH8/YMz3gnvkUgb28Mpolt1rOod+2A3peCuRU+lOZBV7JX/rrOT/892yPivZQ2hDnplVDPcS1Ryz3ot40kqhDRznriv4I97gw+ieeDUEVn2R9bg4m89c72E37aRP41vUFpl60EXPe9CqKkWRePLGCIVqqzXnwM/YVTZdqrH7qLEw16B3Up5emtn9/GufU6Pgmdq2Q3Zbf6hZwzEeaxiPI99GbqnOg/uBsS2qJJQVpOLnt262/sLeYFipHnV6uBhZOnf7Qa/bI8RGocgyjYnY8ueNeAJ5E03NwsWd7Uq+q2HtyJ9ZCFT7bmNUs7+/aHe7o/ZOv3s3++5bnZUjooAJGXqI8sYlIQ4pBR2+aCOIHvNsya+tz6YkvZXHe9uXvZSxB713l/+toS5+b0tdvErUHDfdw+atbnAL2FONBew/1grYa9nfy49ygQyrfo/Vqt/ZqLFxYmOt+v0vK+7x6veEYK1YHWzXy16/jq+p5bMGbS99YbCekdO8elefuKsj1vtkf7Q/htUnVj7q6cnwPWed34T+yfvX62So1OrJW5E4cc/6raTIKk2c677S+tNcvE4hQ1+m2eN5QQe6ztGKBHWmK0BiVWhLXmzgZ8SPjAoomFikYEzJWPxiKI0SjYjmS43cU9IgajZEKYTKHHriKFcypxhJTeOU4FgsmVnq5egAdR28yh9jjVThI6GgGljbUXGPpDPNLX7ng0k0hHobCPMgf8ZSCSngp2WueDJGeIa1GlcVmZ4Dn1r58PgqJxNMC1eVKG0JpsMGaMtlEnrcx7inoai83VVUQkTZY8+kLaZ0eybjNHvqCBv71FM6ikrBZW2Kdndu+7ki8f8I2gLBHjolbalkvVPyFDEWj4sdGWLNckklBzYYFUxyaIum1TxJsTJhRlQNsEph1iaqEkK9hLAkmrB5JoykHZGNukjnH0cXGV9YXEhENtjKSKxRV2nkHlcayf42/xuyMNHXrwXgGTGSKlLBoUwmgVebRmzSEo68ds+yHMGVkMXAvycgmaXKx5sHhDfpbdrntHcOMCbEOhN+mYAJ5kT+fS1Stbf1OMqTu9BtirAn+9ot1miYyAVp5rRPzceLe5jN+UYtYtI+CPiBlWFj/FkQZycV3aB1/Zha8bMleYz7H/DBDsct/X67mj/Os8pEZWS7f37JWZJxUts+bBNs5WnWwG58x4OlCxnbyrFyJCvX08E/Yt1bX3CJBosL9SyFQ6fB7styVDQw7OQgsGh0fq8zUJvlt2PkTuRxkj/cOGGpYfBe9YRqKY/nH5MioqFRHqw/ZUB6bCj3pEe0PLafrobEiPTk46YZS+t/wSZBlkGIgD8sctVQrKCoMuPEog8cpTc/F4CygXY/k6nM4eQc4AqihpE2VbpFdF2JBpIYtXsY9pw/ZCTRRDxUTMpJRaPjSrZj51swfRFLxBFMxh0+H+9pBWiDApcGG/nPIChghvkozjMIq0XRUOdGjWLaAEGBwzRuurckf4C2ouPPhgmO/AUMK8PApjZTGOoYGCIBtVhISdjHxWgJ9y1dsf/GJqKi0hupvmb/iUq7bqMeXO7nrrtylPArbbPlB/e/MjS38jZcvqMbFyqLMZdPs4PzUt87BiQZ74czAW5F49LPQ7HTvPhfxaI92rRoP/xS+0W7y1m0R37rLNpP+wFKZDcN/2WQR2n11/1AIuJS9pSGBY1t2rIUazlZoZLi94C7Ou57BcNmIrExQwuv9sAp3p0tvmTYzV4cJaiuhGeFjL8rnhWOjEjJmg6glUVH7HtGFrZBGTVvL/Q4JFL0zUEkgaAUqPrCKFp0/Cj65vMp8ml5eLQc0KisKBAsbRiPFDaT73QCra6IWXVBq1/AuXhqKBFUnE9aInkWgD/4r98hd1PRqwKJZXLBkIZzQYmbxT1lch5fnpgKRyNIrFcf7YBMDRXLRbUrNBUVQUBqNtnY1OoDAeqG8qKIXDubT/qUih7BgClzgPGasZiIA7bs8E53+l4AxsM9WDoRqG9nvehYJ9ZjRf+vtkEcTRJHx8daFKSLP2ylKsL6kE6FMZs1kyUiVHHTUWecHY1k4uwXWqB7lBZR8GPIydLMptkAiZQLKfTXsDQ+FsvUhShGxj8anzHRiuf0yvCyHkptJsM9slBNxAg2uKniBTfR9h3Bg+b7nYz2KZl6l34hMBQhqVIaV1tAtNnb+G0iMjmeetGhkDo6DMiwkjEiZa3A0zY+zeaLSCE5UyiCSBNegimqSU1JJqN+hZy2DuDUTRwdgcuNYShfCL60GGTPjARw1pgJzDhAdKfwzFQeB121ClM51/dW311rMxV+sFzV4fU1kdf1wV2NeLirOZe7amKFXO7q8pM9GMhxqzSQ6pu6QFofO88LaX1eI2joIi+k9dM92YUIu/gqI7lSu7gJs82f8P3P2mzDub5Z0Q6HCBZuK/WmWZ4c/8L3U/UI3xOqlTilD36m3GRxGTuVRk2O78t6aPcIpiHAlV/FWXNpOpnamU9sLJqWZOXz1uH5eDx/LP2vAHp1u0Fdq9fjQKL1EhGi27eNbbWNMmk3l9WOrZt7sC/VSBZHiqOrPoiqf80tmWZI9FvF8dREPhuNZhEuJI0Q/S+9Ql7WCx62+hL7yEJmBUX6d8Ss2pEmZArMbLlyL0a4fAufiCaSiWTWYufUg449Xuv7Vzo9a022OAgucU+Wus5HGDm0xize3IZZ/OHqkR2ZxXe6zOIpLtPNQpd/0oPxndtsdBkl3s7olGaj+89+ocaff25bMzy0wQzfbNtYvL2NhTwX4Hcdw7od/Y371mZYlqM0ydgRSGV+hGYh6OBguE22P4w0w5xX1dhkgU5FsexNLrsmGGcDciiN7e/B9pYzG1OAY0iJdFIyiBmR8cPkuJ5G3lfNRN/+fjlM5Rchapxvq9km+uun4n41v3n21fBpk3Y9EmGV1zSv35JSc9JPn1Gj3CNpwdHE2ckt8ZDuD4YyB+fTdLAWZ2npoMRtgOoyXNFpx3bWMgJaBX0oqEsO2yZLx3UFbZuNycI9gzNWAcb6hOPYXwZe53d9f12buZqNzZdubmslYJS5bj4+30tbZ/9m+jt5xwnPO35724bMG9FR1MiSelGvqO6/dje+Pd7ezsLE/ESh3tvJTR167CFTq7+o3+rp0TwiO8PVOjRT8F5zkbgLmnqO06LJfZnAHWkMHp69tuBh+emOfCl6qv7YMVQ6ceO+NZ6qfTJF+6R/r3Mk+vs+WaPZzeVvDNAKV21j7+qTPBqXc+0I4msNUemh94hjS8cjxf9x391rzGc0N3MO0lbs08oxleY2zf5tp/rLmZOuOPjgy0+anT3p8oMPvuKkGe5Va7YNO/nEbEMpLuwul3fN5fNzu8rl3QvFVVvLQ01NntxZAzGFEKBJ7nmz3ALBKgOCdRqzjDf4/sP3m7UHBazgQA8ZYURzZhV6a0Z2J+5CuVaHpZJUWA46v8s54e/p0CF7ooWwLAq6WtydFTNDI0NZyT82O8Yb5Uhk1FQtWjz1p3WkF03YBjov3h8Na0meiyZAvSZfigzlkEGIZsrha7n08PhwZrpXs1vPRFn1adnUAlY8wkthjdej8ajOc8lskpMNdOYJvIFvFsIA+qL/NRIkwZBC2UdhLTpKC/TRSDxBE7h4HUpZzx38UcX7NkH2qfOyb4PvNMgGITy3OuTL2Qw6ttakb+b6SilxESZINil6uoxv5CVBTKfj5OZAvpSTIHngUbKTs+WhcLqSIk/1ilOHjErehhKibEOSOVMgC1H8i/sfEi8O6VWJxNLZYEilue+YWTi4TC7gixundDNCbXL5ApeU/se/1Unpu72k9Nfc4yWlV48O6AzCLmZphtswQ/8bCgWtgBngVE2IYN/iTsgBVPgXIM9NlH1v9v2L75ttmvTtbV3u40iwBsA/bzn07S080m6/z6HRF3Ywf0pL//6BvIRtvJSWaPsy3ffJln2vvCc+xfb9HavnoOebe/Wrn7G36JKs1ndxOLItKtHjpaWT/2QlkTD9CnH288hwmhS0MqKsYKx5P+cL2q8GwEN/S+MlQJ5kW4+z92cBvQs5Z38Cjl0ZH8WezEGT81vsyTFMRIVkY7hhM6IQ6O7GWafSCAti+aFZqtjpXHqyBCc2pxIdtIFT1c5CZ4YZ0HZIB1C7g5hsGyEP16pV98r5Qhb1HiosQtd1NleKnCVZ8ubCaFyu3ovCk6TLckVurD4dnYiyiPg/0MVZziscVksL59jE5qCsG3YxyyWRiXYx65qGGlU4m8lGyLsi+UxKg9aGxIemEtWdgRTXobqkasGU+hCV50xVAgYrYR2SmktqXqrYh2pUsVy9m80K5os5tCXjvs5BPfNn4Ap3Mpb119box/Wmm+kDNtpfwuT4vu/kVI8qG/Jwz1DiE9bxtj2nB3nO0yvCzO9soJi+tceSVA5JjtDArGTgbPr1tpKLarWnKmlLmvvB34V1eDrHr2gC0FnJWA+k+0u9xnF778bxELcM7u1OaCw/6/v5QOsAU52KAN4UbFMVoOYxVHrE4AJ/2sGC2OjtVgs6TJqcn+pkQT9oZ0FnOHLfIIoCG+PpGFabl7WheJ42vd1WPcKV+lKdp5t5xZEus6KA3QoyxZVsr0KSpaTYBZdLvbxHmkxNBX1TG1yN4B6cjsMqrREUrF3ItqJAUHayrdFQvUJwCKsQDAOnbHsauANL2kUrUXVzC3Pz97ZmX9vkXnNQrf0fG8Rwtu8tvi+jItqjbs1cg4UurdfBxPcgdHtBD0K3h/o93/46yNPr1QNQwr1glQfgWwd99S3/YmURnR312P7T8QgvP+b7yoAzYet2C7YERX1fi9XfNMdIXGig92CpORQaWCqM3DJwS2lOhdEo59cggfOIcS4BWNPJPNiZgy6wsXJsxfREe+aY0zwgDndNRuTsZMSuFTBiu7pkKn4OolhK1cMioUQxLGvG7hPgu6UmPnd/Kxls47leMtjvvrBy8iLjIYQd4SGEWcIRbz30f1LTr+ktV4HckOA7HdJXStEBRZfEvJmGmQXKE5P6z1dIbIsu1POK4MQ143HoGyy629jOV7hRKYgU2/yL/GoyFtyZcA8ATQkGbGFUXCvBKeg9ZwH4u1AOYzsquXxY8gMBt/x/LRt8DrlG5KjSQdp0IihBSQ6EUSD26zzJ9Ze4IA88F/cViiwiU0hdRvzqMX2lLkoi9T3OYRkLv2knLJYfaMl5K/GgoWJnI3lRFJzkBSaS+YNi5qA8Kc5uni0t39d3BiMPTvvPkew6CViAm2A8XUjpI7FO+lz4r4ssw5ElNtUUiQgn1cEtzq2U69gG5xhvTMnr3NkdaOfnRNRaUuOLzRLc46WSndJAh5CYLpfV6g47teGPWqbQmNw4zUlu3E3OMkKSFCiUi9x13jzDx7z08rGZKU3Yu4L+lmO5jSMcQS8pLlQ3dklz/FjfXOT4q+zGLici5QAE3cko2A/tj4h0DfxYYZ0D1DO7otAvXxv5+tf7J2y9sjlsTcU6ctNnunHT67jRl/ZY1qTXAuc4czTN8aMBO3POuzjdToTisJlSG82rGO0AI6g4b8maH2IG2vtIbQ4kv/8dvL+0nP+cRBs4efbiSMhvhfA7sE8FVCtMDBSjCCoXgXgwGZGA1PbLQSkaoD4fNb+enL6J9XP6DuHEoOzXdM2vGHBIlGCefkLNJqmMKJhIxAA0JXxUpuF09WepQh7BqoJxtBEzIjy1KieQnlP38zIzqbf7HiKB/V4Pta8Q5h7O1eui/JoskYysd8Jt9aXSBxBOKmPoZuZuqRdM32kXTPeu1nh7DVhWnUt5LGCqgXjcQBFV5XUTxVCeS2QSKKKKtIgaDmG6TdgMBA1ZRhFVtouomhYd4YyEFg0rwVGgqQKRSCwRxN9BwxuoZFc/1v5oNJm0rV1JKE/1JH2zQVIJ7pcorPaG5KXgLdHuL1ukt6x9S7JyfY53EnjUnME94izKlbTiizwaq3dwFbpB8MLydIl9SwzbA5jQlVm8J52CuVCh1LZkalwQ6F8BuBu9MjJiILqxCkXmmhCIzjRjMRIbi2ViXGZsZDQVKd2Ohyyi40tOJe/WAUFRgWE24pb81s4Q3tfSFmeOi2UyczOz2UPUAporJWotAvZJvpAkXwZHWctIlK18Pa0wECgVgSBUNfGEsIV2ATxfLqK+JqT4iY254J5C0/qZvtf7PtWV8cnU+4ALjJQWvLkvluNEDhNPyqXa0b3s5sHGKc6ud+IujTPNDhkqOiO8lqRaEfZJzg+aQTWn8G4WS8to2MVfTKbj6STYBuYoHCzCqqQ0oZVQvogH0wtul/UOHYuVCNLcE3rJIOWCC49YOSU/lx+bGeNjY3GZttW/3qZ9xmu0z6hL+9zCtnfATU9tpukpwW/DC1iSypq3oqNRN0ulDRnkw92wVORFjRmkTD2DhEiUrvS3nJX+mO/7+2GleUavqIwssBTCCN5jhAHxdhAoOxeZx0sP9ZjnMqF+cFy0HCgKgBIAopBnzhLukjNaXA8JWtHU6NBvRNDHFTBrPZwbiWhDw0NaLA2elBwJaAlQkLGtgrGIhmfpF4SYtEM1kTLPlUOnV9+z342leoqsI0uPZmLMKvNrZkx5tgZtqFFIJGQKUg9GMrFz0NoajAT0PBpZw7iWUGbXLC0UVY4OW6aRUPzKC4CW72JSODyAyTrV949MmNcFELwqg3JZzmtCcK3Zhs7r04Q+byOezTURuQq92M0d1G4iDUjhtG0327xWM9tqNRM1q9GAuq2+vHc4F7d9hWS1Tdtyjprr0K/z3f1w2PSG3lrqoe7xDN48y3f2UHM5oWvVI7v/j5vTu+G4XrIibos81cM5w+zpZtR919+ahD7AXPwzZy/V+/qDc71svxvG+/qDdcFMVrADeq487tjB5b5/8t2xP86VpsRK6+kwvzhfaVnvhpQIbWNZpwOjhTl/U+sS83zLGr+sBUz/6l5XfXfrqu9sOQ4ea0LRc5GGdfWHw7q/trJ5sRoNw4+CdxXWDOQRRYNt+f9iDOdp3xkAUFBkSLuYjrSN6ay+IOfDK8R95LeRAw89MILb0xPZ5fYWEddFszlPXDeBuO6NbfHmMy7efGZi2os3x/iV9rEfOZs9JzvGy6fyToyni7UI7+p6hHesF3V+kBfE/JwaiPk+N/6Le+K/PbX4DxB0tqXe4fsSdLQNyHI67xWbp1KucUYbweXskVNkCx5xd3Q56WsXMkev85XdsN2uqQdm3yHc5MljxkQYQ7wAMpfEZpK5QRnOwuypc3gQb1kJZl791573Y/UYtoFP6OF8PcUN16LjOlVmgnIuRhUv5lxPUDQ3Fx5KrYQ5J1f3dA7jUy/rdrc+xAzgpRjKg87qYW+YthjP077Ans0AS48tSZOAaOWnMb4Yr6UNafzHJghTseZSGYZS+yI/wq+baRAD58oON2rLboPstVf7gEQqtSUbyxgB9vAABBkxk2iCArmd8sH8UFzDVaanoyAq43EWIr55PWzmDCd2Swbpq8OF0IqGg64ZVtfkZSMTi4cEgMVMSK4NU5Di1i4txagCMuCFmK9+nBqNREJR3o4RyecGYlN+BsCmNrXgOw81SwwJNlezvoI9E0Hjy3a52hmg0MkCre5I7J58tZf3u4RcYfYETEbg9KgVzBVR1rGOOG5vrJNxTUk9ALKv6sVT+0mvq/UZXCVjWQXpZS6Vw+ed6QrtzOeLK3Kzu7vpGKgR9p0P5+xr/VGz6efmuy4xLvEy7KQhtl+/o4O7s6/oXStObt/AWYcftSfa+WCZeT4s5V21CH/nehwX3SnbWsxYwQYIp1taHcT99Z5SCK2HQmNSQIB1PMis4xyM1fym7ymiwduIzbWgEJZsK7EWGhkcc5SugAbL3ixEo2JbJl5alXkISCAtOiQzKrKIuc5l2f3ZlYV6Ga2nDCWphQqIVKiugova59IW8sgHXY7HVQ4qweV4XPq6ZnrHtQGIlUgvRiYMxRD7FbX7+jUxaBtT+QxSl5Goxu49+lVVuTpUUIOo5nNoZta1CJpTejiibgqyYfV8CHIWJCeobaBVHUClU6e83I9ZzcF+NEI/YDpmaEVDxaiYcJzfS4W/eKd/7NVSH2afloejSqFUUPAFFPbZOEyZvUEkVB4qh8KmBBryKSsY9fJdNJgBjglCapwMfLqQ8bM8BzsLbWt/le8zvkdwFs7GaeLApf/jNpuv1EabbCW9HX3wAhlH2E1KMAo1LY2iIMYKos6ALocljSNWdxQ+63hIfjg2jG67TCFUPT42kgB6RqAsZb+SnogjE/6GXg7E/I5CaGgoL2G6b2Y+U30HBJIy7zekcNKgcVRCyUDDFxQNJbUQq16LyhvsAcK+wGXrcXpujAJswiaBlSOpuZQ5bBqgWhOFboYVLFEDrYTzK6pR5hjPkQ8kGJQBcfWoIglUWlJgdvTtgRynfl8BfrsKYeE234swzQ3Zd5PW95fqxxIsi3UesCL/klPnt4kJ5bF6CxxxdUVbSZPK0xZ52nNnWYfjzAJ14Ie9Q6yccRSiAwgpwxGgUR/MxBQr9FBnL49JtcK9XbWnOuPtDkXwKLdIryQjwxnLOrAYlhU/OsgK2+iDg1owouTLw1D37VhyS/t0t99Rmz+bV17sTJt1tKEwDo2KRildOjy+oVA9FUMsQyHcCXCk3xVN67KkaZGKmS3ETIMMZZRoOMiP7H6/qAbMoFYvvpfNC1HdkVSG/YbkJyiQ/4lszRYrCB0ioq7yTjs9/Sdajg+VK4nC3iwzHxHFefBzq0dCu2jqkTSdPvtzJOQsCSFcODZhHfO+Q/9mTSVVJFw4mzsdIO8hsoqZVxqsy48p3CGdTWnCI3hfdgymqlrmh7C57qCfoWXz0Vq/gh+hh6zKh8oUuY67dsO+b2NfJKAFOR0O+Bd8965xhgltp3UVhRjUNL8Ym3cUHfRejpk0pnMgrvOzI41mZEQdC6og/itVhj2H3MzwIhve5FqPbUj2NyDirJQw9YCmeuzZzMCoc9+quWSbG12yHRfdckk111xQKU7uOv2aWkFlmiwqqYnSl6g6VQIfHM8xIGOefTLyByg+YE4KEak1HUO3L2ihwJ9RSLgQUEoYii4JOsDJ1eNxdokoncVMnZxnjmnhlDEczaXRXi4mQ8WChdXQ05puEsSHCeM6KJf1Sh+VlTMSOWgogCINpuIEYmUipKlaHO9aHq6+AF/QQ8EkjGlZEOqK5Il49YGUEdSCCPogEiCXQv8hBIPQTwILDYy+bqYVieHkjPxsWOIlI6RPpvHr/BigUSMgY2aKH9i/Dfvu4X7PR3wTvqN8L0Ph5m7ff/l8Qg0TtLTQhRHE8z2byTZ+YXBWwlj5NENvY4JmKraxmM3Gc4m89ZjnHL0lsG2pkQR0OdFsEhA2c3Jo/LLejKSNiXB+vVLK9G4iT2JeL5t2GSRzh5902GxY0dXza2YzSw1macNx+fk64SeJAywVSbqEn+dNJnLAeH/MazSpfLLBaC6qG82pFyyCM9rWbIi/D7OpXsujwMNEu7JiQf77bI8dwffx5ZG7/YVv0XcCgH1I0jdJbpDKpelYbza3KaNLOo93MxcZEXrJydrycKWY+GucTDPhM+OviTR7y71XdfKzujEZiY3HMhDuVU6o4FZPbkRZnNjp3PwRJcyqjmVzy9/3zHsr1+e93YR5by+VQuI1qVICcAlJsBVkojSsfUePWSA00x5rgSZvue8F8sUkudOaTGgsOuaZ00Bzudns9OR0FtIpuUyB6AGWz10+pNNAOPJK9kpkbiPA+pbhQ0u8mlAUzp43IeO+Qs9euRxS2KjeDfu+zz3Ki75R3zG+K2kHyEqkZqoEnyO9DYgYbiMRX2hWiJPrqLi7pv/+UrP++wTov8nNK499WL6HSsIF2Z9IWU2S8PMhRqAH/a9Zm3pyRbX38t7WcQ6nNY5zuGXPU3LkAq8K3Ni45wXHNojA4WCNotj0RzTV7EQR+7a1QieFis3I9jjoOFHpXcxiQeZoU08Nsz0c58vx+UsoTjvYK5h5N4K90Fdz6fH9NpdWf41TQUqkojz5eqwSNUwCKwtvUFHy+ZAYjRpowoLX7UcDakz5tBl+bRJjPzCsRQ8Px5XdlY3z1R8GApImhGU2SeW6FTn3/9dTT+lqFbt3xqajQbhOfECKR4wEDgP0j/GRqMHeHJaBvqFQMhoV7b8+XMphLT4b/+vKJPy5Vulumy7m0X33c79khvV8zBx6cG2GNdwVbN+fTTQ3RTu/xAps1Jau6L7NivzDipbwdE+WcFat7/kgp+8Zsgm37/l91RPrfc+q1ND2/HHXPdy8alXtXCNPv5QvxtoaxkpNxssf8XQ5HywamFiksRHf1FG0PCDUUzQLbc6jzJAedAzpbQNoh185Q0FDyFUkHsgze2CRbbXsxGltshNfmz91wZt5+EBT5kFtyDy8sZ55II8OwGJXreH+avsUBbWUHhIQz208ww4f69tU4W9sBuLxFEyH2ILw8t12V5rdYCq5XWm25+G4Fs6X4VVEAVKaw8qiWU0Y8LSIEQmvwh9yHhdKJmLhkMp8YmRJAiZI7Q8kxiOqKkh6IjLLgjHuA3ga/7iW0RDVs8lHuFcHh4ZSSmDD7Gy4ejM/PDWjSzrcY4ELaMF8Dq0CilbKmuNIUXHS0rYpgiU2hL0DHArxyZ8RpTBUDAZA2JZwLExjAMQBAOPNQTrxJrguPheGxXp+UZEnmIvkdPnSTbuVW3Tm29mP1lynmQ84T5BApA0jyB6iHzdqJ6fIfUo4KqeGkksvWAzHQn7iVFulVCYdwFK8Si1znKIrFTwtjr+tx8kOvQHrqm+hC312WAulZeqSKBDZXUGuCEZ1aNioniWWK6oIYhdiai6XVdQwH1TThxbiJdMYxyEcCOTDkVj1lHUY4bCMrmgtprFSLmcUDSVgZ3amkfazF/cs32t9/+b7dt/Lu9TPopFGOYCt2a7X7ZdoDMeP2OLtznX/isgPZPH/1uuyPtsr1c4ek42lw1JDnf5vRkqzC/h8gE4CFFOHtq306/K9A7AQo6+V/2ZDuV+GVPtFDWX6y6n3TCv4uqqKMr3wnFo/mvu9tf7T7Vp/pq0l0WPiCX47RqfN+Z7ru54NT+vPjshg530M5nio/l8fcz0Mz1yPrDvXg+Ik3Lke1VcNYPGXj+gyv+NXz/XO7zi8EYx3lnd+R2KFpbQPhZejueM/+1/KVUWntBjQFJ8+AxdC9cW1mPThppj0zc0x6RfN8M2emFRIFkfNyaXqfd6o9Pr9enWQ1cWhXGXtd4nfV0KNcjfM5mBgQ97pu9VbI1jDaIwoixDGnDo5BVBUHLujDv+c1+6EnkYZCMDSlEXm8iHe4GrVcleV0TD14o7qQR2nXtztTr0YJsmymaykFp+/WCjQp6LCtlKwAvpenwiGqWkFsahq1+ktF3HcHfbqx5XJfkdZXBot0pQYmUzFlrZsiqVGLWYlWkbXY8aSYyaobBpf7WX0SjA8EkHUWF/c77LFvZAJO++lOcH9Mp5iZL3X/7j1HT1RXgfLIPmBTZS4ev1shjqXj7F7ZNj3bN/rALv4Ws/TOdfTBe2laafDVbK3l2mdL1kPF3T5J137dD7d5gLpTiy7eT1dz4+uCCEjx3UMSmz/YwHSv3cBxv4Db9mw5+ki/HoaUS/zRTpZEXeUvPPEM0/c0XaMyNtaxoi8bl1CmpJ3oEhxenG66BkoMnPY8XtmLmljT4k+R4VAsbWO5nVXp6EhFHndwbIeYZZl+g5FXetG3z93Rn2vh9m04LE6xbEHtEC837geVnB5M7LkT23WvAXUPbOea/qVJqLVCV2czRPBbr2NdvENr0vC2Vx393NFvdvX5s9bWJWW7f51cDs2rilPfPn6eRq8bxGehsqs4T2+90G7FqWBJSWwL0LBtrRgc9UZDsCie4ymIg1Hi+b8qzbS3UGsG67UxHkdElExm2mJLy15IHl4O4pGtHMRS3Y86/yEjDtPiIIRM451wSce+Sx0g8FAIphBfQHBJK+FUrIaUEWqk/AbnMSLQOsjkxyS3qHFaSNdCKAzGq5xIlropUA8aUnYyQdjrjq+ORQwk2Eou6isbBfeQIZ4EHtBYC8w01lFl3YBlmXpVvW2qzjycIjhsTgp8LmgETRDYNvK0Wg6lESzfqB6bf4QAOShI5R5Gh5C7gBdio4lgFKYY7C6sBgICTLGZeiSKi1fBsgcFJHcGaaqaorIh+GaBuOoAYQ++zuI3Uw1BA2RMYIh8CGwFZefDmU1NRWGNmHJ+tMfQpYaLQh8kJz2zXuxp7fs+x6KAX7fZrDpPuz7PGKMOdQfG45bwz2dmQah9XhGpUdY++AFi0agXhp8hTVlsmx1HQdvQrgKs7C2UGDadkJCoAjXjmB2XG9KpnOJbLqQaD6uZdQTCDlz9cMWZhvyUnx79vuLiG6lQpwiZop56nmdoyBBJRujbKvl9Ei0+gfnKGe/3mwqtmX71pgajZrOUb6h8NQAxiwkrddYsWbuO1fDvpOhXdjGQlofYSbwIPZDEBv5jXD7frVexzq/KsOisKlYo3U1pSDxg+cXF9ySpG1yxrSLyaQ9osONRsPdvT7nP9evLd6EBAJ1EwKyTNOY4Ol5jdHPmsBoTTJm6IYAW4U1Qq+M7S3ofPXKRkNb00XBHdRipU83WSm9Pxqs9AO4GI5hPgUiJNtSF3F5mCiaBfHEYJ6nEDK8mYPJ6hiAgd4qmVrq3aph4NKDpWamztlMjTChlXCbHLTvYQikZFQjXw2MUR/VSFrlgrRpJ2HzPHhnngfSnAu0V6O/qR7CCPxBVn+8pLf6ozC2MItoVNXSEC5HcEiwOR5lw+596DzKo/oURq2RvuqO89s3hzh+8k76Blq8YDoVR86PfBi0D71N8qAeoxD6/HdIbEfMrTXuRuSXxvafA5rr9RjF03fmeeATGjpmlR/vxyGHMLAL57L3QQy/a5cofnXdJ48kc92LCF+uN+bd0ISuzBbTPUxcuM5Lmn77dAcv/QDWVaD4DkJXwQd8n2hJCa9iSkI/HjmpR2I9z1NodM+/N4DxB9WefPEkcwY0U1e7T0ioXuZxy2f7G2fwol798OpvnDpSL2MPKo2ZP+xj7mns4yXki9tncLaRxfmB53CsPjb22lI4V6yQwnmrq/+upXD+qZ+z4rqeT4I3NeRwppamPDkcMrvnhENnTu2SwzlGzyZ0UsviDCGLM1SXg5/hZnHe2d/p8ok+GPXVN/SZxKHB3qO8yasoTv4TDpWegr1Yb+z6/iPClYn23WK9w1YA2R/WeyDIHQGovaHqEYVvhtq/v1vA96KHWrH2pRd7sfZ/va7PkPAqD+f+9EbO/T8d+rfUNNnqRHsP4bsENPDe5vuO76ftQfaVkVgXxxwRAFa+0ZvPknlnqRp59ubaZ/R0I+CDGiR5/ftTm9j2xihOTtchT4StZoccMvdInlO97jskXs2A+xfWrqWp1mvpU9Vdna+lu91raZh8oTMSv3oul0/An48nk3TTPdlAvD8D4y/94pXNoeMOb+gY34S7rtmRPx9OpO5vZd/f2NcNxl3ZSMb/ahMZPzcxP5l/Kw6eLUoEYWV4lHn0P4GtweZQnH4jvJAe3fiFuufP19zxLsR8NnDTqW7Rf23jKgvMPBo+Scgfuvvydb//VdRFJ1/oAMvfYSUFHukeUUSfz7hBtpk5QbI/VEZS3+nNmb/W4//vrjvlQK93guWXN2zQkPJRJeQwWASAG0bKDg0bkBko+MXw2TCNCwhXXHB8QWR2mS/4Kd9dg/AF+xEHmGslRzc6hvcMYgdGevEMb1oL/PlX+8NR/Pmqgc2Hd3YbP+b7Hp3CvD/cxrWaxt+tK3n9Wkzn79W7rP6hH3P7VY2Gr5SU6q/6rhjuRsVQgknSiuHrIWv83JorhuYahym0ztjpYFkXthQRr9ovxkMnJvhbZur8oZfS4rb1NIWmwQjVX/dYajwAOWmN5aSvhhjye38PpcYBX2bfXp8k9H/u1+ttP5UnB3Xb0SkEKTaF4GI6ZK2HKQQ2cpLJX5hckgHKxKhtIItz+B9FAi069yFSHmKcRbRo+8Qfdy4BtbZZekPFocG12C21jRUpoX4aKdObTIL/231CQWV7JDZLbyyUBXg9llTkaERlCXzOEKyU9YSi0zVVzeiUEvazg2aLPqwXduS45MTYxkSkVJ32lw2uNL00U+LRzSSoIQwk4FX8HOFxGZMkCHlL57kFr8NqCqpcAL/yQUrcwfAnQscECZliFnIsRmvhIc1LW36MCQLdwNg4Yh121B5rOyLjG9kgA1kXSP0i8BuxGJ0WR7+khHhAhWpE8iBi1JuRxerGh8VTrpSkmkRpaZEtEJ45XZ7iLF0geC9seaSar1KG7Jk2opfhwMwu9jrPgNJEsYK0j5qeKuwn5EjN48ApUimVbbck3hEWu2F0LIkHn9iViI0z38OMBxMxnSULwoI1lSBRGXEhoAVaBO+IhaYXZiqHoWIG7UHLaGTTZeFe5hts4XQcb5mltJlJZ81gVKHZAyw58ycCkeDb+MnFSV4uAWZAXm6zY70Ecpcd67gW6Si5zRymTQtGSC7KNMvEGuMDqUAk65dKQxMXTGqRkKJQs9MLCvfursMODpAlV6jG/r/mGPBcCGYCU0jt+w33v7zk+38AW37dlr86KAEX5kWrw+VaknlxK7cAZg1XcvXs9h/bMGgKmlUHsxxNXQGPgi29nXMcWyQweLyvTaig+3IcbTJbOXPOTmnRe6XMzMHW0i45EAy7lY0BdGxuKnJiPB/fKlKV43auOE4r39wHA+gA1CjOKMBRrISE03z5NzNaJhhA7wpgsubUPyPBkztZAVQpSjv12LnIiYJkiVFJlEVTvPy00SO3VyjfQvBHA8Mxk/IK0IGfDeHNlk5OT+7cuSWAG4EmjQQ8YpyAyw+PmHD2/HhDICIUXlQ4qjeBMygH5ueTr5GM5HHFYvqzSIvx1aevwZuTs/1Uy2AiklL9foS3KMkF1QoiFU7exjEuj4ivIQkFNobyHwHcClTyygVGTNMmjfmjiopfSFI4KRwZmt28RUuqoaAoSyHcO0OJ6tN4VzmgRLJBg1eABXoO2imQysIF4RdEVQROVxHCAgU0/AuwCJKg5rP++qmQBI3yQ6zfuvlUoPd307Gw6lOBLuOa5xWs7bRQQnW2NDbt9FTfp4UVtdhpsfYZBnIfB8nt9iiDmHuQBNCp4cwyGK2fJO+tnSSW5yQJuyfJafWTJBgNkupr+oDvqK2HSpAdKn6O5sbdyQa86TsXscUnWA60+w2ztgtmoLMNBnILDcasBjTsQOzDvt7d8aKarpvX+1Ywr0TDRQXINqket8bJB//V5R6jJvddmFyUcTPv8f1ifzg1fP/ibdKPaZHmXMtMPSGzvs7PgrzjhOcdv71t7uaGltxN9bR+3KB6smX6kOMOnrKzMRiLet3g/aPqEZ6szd7sVEdA1ElOzoY7aWU7W97nza3YORfGsTT2/ZQ/jRV9PkuvTmpNczShLla8sQ1piG3mmgIbLlqPbMaZs5y1S3r2dcf0eTaDkDR2+Ufpn6jb42+XDOvMgAypMQPgXFFGOgJkUANYkh+fgS9OOoVLNJC+mMuUi6yxTgaRb6MTGgklyxsYvdKNimIzILETJyzK6wXyhmIUYYcgyKVw9bJQOCLF4JwEIyOUPQG7UyxdZcEtZQVwSElxyCWL6NuPi6KT+bdBA/TnoEygRyD20fzVx4WwHnTDqgMpFhHVhaTxIUarsjI5zcZWsUDq+wikrDCbtioks0kaRtEYKmZFWQzlp8FVTrT22FGUWoD8kIQkK5WS0Q6NKFDJhTMyumQFD2CgJvi5iOIF7L8AjddDuqRJdVIB/klOpGxSQQbVhnhhOEzGWFwWTSY8cZkZj3CQNOEgy+/7Pn88aFVnICt3v+8nKATDJV+cX2J25Kbh7AQKj6RsfAu31FAidLJ2yI7gMptFQ7q1pc5HHYFP5TDj6EtMNrESH7qjxaiBOsPKqQ3n6Yhdd6ClS7ik/0ka68LMKbfs7y3XKBUuEHMBNaSlMk3fzcYRIJxrbSth981YTq6O41SWqaOTIzixsGGikmjU+CWHaC0xpEdSljmEejC0bxsi1X+C2DYqinDGlaGPQusTD8aKhuoP6FKkFA2Y8ZQeQkJJ2quDNLkhrydjEelkUUEduWSUZi09rE4cWo4I6XFgJ8lRlFJnaUaaUurAqFTUGFz+zQWRKjolRUmCdgWG7ZOsVqWIc1vnULviSLjAzMxIZf8/c98BbtlZlX323mfvfc7ufZ/ey+29TKYmmUlmJpmEQCJppAKSQCBUiUiACESMQICEItKRElFpioCKhSYoiAgqUgz1199fFCNS75n//b69Ty/33HvuDPDMQ+49c+aWvda3vlXe9b6Kk/LTTnLWU0h3BYyaoK1jyqZL2yuOJKuflmz4K1J9WwJHGoksQspQzbhOigHUHvAcUVUbH4XopCsagqjgv3K2npFTrs5Ilidd588m/Hng4JyE9FR0rEzJFGVnLmcz9vlzWHC35xybYw/KmXRCwFxad+e80jHMQdBwzEi2vIYaAD6riThhuHyTkNb4Bty00GwG5pH7/5jTQJJDcC2fnZAI0yZMvYPaxiM8FrEJDru5v8Vz0uGrxB2rPS6XY5ztPI39i4mScoaxq1ZfQ3mom6IB7TJPgIdmAgd9IHRQRa6orNblYUyPY/2gw7FWxs/ECTxObjqgbyccxbEtOXBBkVfggskOF/xA6IKY2eMlFTzV4N/B140LcXCvqjL77U7nqe2DfHa/0/wuAPhec4iQR871XbSRrgK9zfsAdvgqgtWOI1W9afYBMYqyp+w8y7K7XaVNDt12FG5EbmV3OdE3GSa9nhw3Vvkll7mkI0p1OgHz3/HDlw9Lq+7pS6viI11mob3Wtnjhw9t51L2dMerX1ZSywwjFMmn0HYLwpDXDkwRSHzhI46Kd5lMf63SpU8851u9QjQ8OSqnYSDs4kcbEF9kfAOZwNYITWdEmJFjIdeA4TSmqQMKIhCrCwtJcxybg4ya4ifa1CLbJIaOKjU1KshV6EukxEQ/yuc7ul0Cbk3AeTxSa+B3aBCFo5nL4fdbXKPJhdQMDkup+pg6wDCAT5Aco18mPhB+sRLgfXeLvlCBiE4OSTbI/HjBFrrMfpTpG+SxSjFzcM0CB1/i+7MZlB+MBjiesDKQNBaQSptlOPEHyBeZ6FowmKArVOK8i3cbuAthRjZgKdgzZ8NIJ1Y39FinIuRiHZZU4oWRCU+gLqhf3ZTEKeApgFjBLjJ2OWY8m/a44/+VpF9ArlFtKnIAuYmgQSYT4Jc5b8EmFFUgT6oGYFN3QC+Z5ZkrNlEIWMVFEsm/EBEP4eBw/ty0pJppUaK/FrLm4jkYcfriYIsxgfZxA7KMi5DTFxjE0v1TQopoxFT15bVp2M5ZhKqT3ZcRVhC/hFvIV4pZsa7EoYVr9AofxCwcCLoK9AEO+FCvgTIpCi14aNGd8U6wJOPdrsQf5911iTW0C+Vo/f3zYJNDGEmnqqhrpYLJdN1LarqByBGWZ0FU7Yk0CLkGaHZs7KQU7pJs+y5J+PxFOUXup4gvOortyPSSbmFePlGx6U0ddSINaZ2GIF4LKMJgjtzoSiXptKmGWTNLQODp+wddScpLdJjU8uLs7mOHzMiGGZ+HGI4Wcrqb130ea9R9vI3tvVYBR07aiQQ3o79t/jt+sAknn43FjtA6+S/3lBCTU3kbInO3JrUtUeXC/NWV51rbX5BhHmGcnLvPUSY3M1gJfair24MOm5+1esudlO2gV/OFuTf4elnLGaaGWjyTFZWmELMGrRqr5/O62I5Qg3iQjj4/8XuQrOxf0Ia5RozGqFIYlr9s3SOVeKqOO71b02XnjapfBZzcKP3i+M5tHNqeEQXEKzrLsEO2wtsTPxTtvke4yIE1tm1+jqg/MrSi2q9J2FMNRb8H0Hi/j79sp+J/urNs+JCJ19c+JR/0V9aiXR77AcG2P2jHVDC3Dtnct98DYrDfMWfM65nW746d5/lie96Rt6XEaXztrLlkfk9iGFG6jHLO2DX/OGfBVcnt+B76qR86PPAViCH/ee3sGLkIz7D13EY60WNc3R1ysYU4nEsbFANVWbcPMmA2KZmxelCnsCLTsvBWa2R1o5kqp2jTzyZaZE37ClqReM9/Nza3OBWZ+9vSJm88ZcYfS9O3GVWbjUUdrTaVaVu4Tof3ynluxsVRdziosVG7CS9LuuiQLQYa2wcjplalQq3YRzPIYtWtY28F3j2oIWmngyaYQtJ4X+Wjkv7dFk4156+1ayuns3Y7vGS3tNNZNmD+0O22nu85ajBoCQ8ObRoakynhyTx86E7foEtQevgW1h/2Q7X3irvadx1V/aC1R3LCjnebnj9Z6aDx7xxvM+84/iKWH/Y3948k7nP9R6He7bUbkb7PfBlH65ZAj+Q2CCG7JkQR1cZloWZRqzdYHeq2HBKrX126xBI291WZnJXhQFLuD/pzdHEnRhkoT6MO3+dZbImuOgHZmqaYzPh/Mw4JeC94dC+Zl7QXILJeBWhjDE9iNzPFyVCP9EPX29EZa0FFNsoQvhIBmgAoCVTiCbgxqV+9DayQeEzQ5ZgCCBys8iHwiGmPjoi1DXDvayM0kJQUr9LaPp8qSv+QDUnL26VddyzIfYF7IYjVMq2kK7Wlg3S2GxeeYGc8Rt7wLQ0z0T/AFWdqr4ATAhURZxPGa27e2lMlBpxoAHzHGI3eBC8T5bOX8WpX04XR8J6ykGWSHyJK2/gxfgBPRf6m6QCDL0Ja5G9tIGrhiFErEDR0U0QMHmVkuM++ORq+AMpIZh86OqOAcy5Zcriyvnruo+oIu4iWeqGhhX1HLKdX3XKGkYPSF019mfwSjk/WVVxCSmbO7vrIt8303ovcv9mI9RRprcTk9irv+7Gwq/+NoHY1/7qayrCMRi8OSq9gy2Q3JQPN4EuO1gH2t8x9S/rSWTWF88u7N7ew3jGfgkzvB7D+veqKsFCCpKZsFq3qsZBYMOQFOBgnyhKlDWQjGZUHRwGP9rnZVHXebYFgWoQv6z5E2/OU9YBxozKTWMpJrarm4BtL5GR8WioETW0JTPebN6wAiMkKsYJopKXsko9oaep4YujixZ4y27Q+H7G1Mn/4a+78wMtnbuBXyY6+ceG9juxM49l7GNX17GbfviEvCG2WsJ/ctXvzbmVi8+OZoq2z91Zi7FbOn/w4YUC5yZeQFkbeDf55GVYpEI2eLr9O5e3OwvtF5qMhjDV4M5gM0zSDm9TWuXs7x3F4HV410ucPw+h6nYMQFXleLx7JCplKvZMXoDPTczLJlTdmqT6W20jq0FWzodQB08mbH0JCBOInPA9Ilz7hYa3ipVclhHuFkysYL2XR1tpr55h7FW8r3QgLuRSDowaDc5ERD5XQbmHqOTWQSbNwURBHS74qg8IYdk8x4HOlpXJFxU/Ka5tRZM6E5hixN+SIyV8tNIElmNXwBlbm5HZWJk4yIyl/v9pGLe3zkc0bWQiYqxdpx+SsAdDCRU7hd3wm6WAwkAnsEGWeQSJKaJdD62wiSUIccaMHdWDlCJd+a67qO10xcy8wkwiAUMdQlDMIDcATR8PVVVDWb9Tck5pGyYk0fOWvKjZHLTS5oyGk1D8OkYPCjVoFfifthvkuye5rx+r7NMTfuQjCEDfVCtt7BMEeexjDHGDRDpFw+EQ1SXNcjOe7HmE9RHI5GYDjo7oJg5Pgahp4dWfJz1GKlHGTJ+En/bJiISGl7EZGqBR5BZH+bgYjIXbEDR/eLnzznlhrzSQTjOUiIXA96viMoL96AYRMREek0ly+GCTRX5gObH2I6bC52WdxlxhYUqQ6n4hRJGuZ3MTNWiRb8+iacabXO3HIClZJHTCaTut1oGqzxH7RGgcE1v2nwU01zx5il8fREhjJyMj0EjFtvY9nLnsZcwrB3MNnAcolcyX5F6vxc02yh6f+lbfnKVNPw1VLj5rHURL5+bScl50WdlJzyBaiSu/k7Z8yKdpSxSvpRatx/5G6Gcc+DgMjvY7P7wxMYF5XhXnDGj0XE2W3ui7A44DbNDYSZtr25RfLZo/aAPp6tbcfDufVm6gYPY9i74AbQ/ETplsrDDTZzotHlBn/ddoNULnQDUTU8c+sVO+WTf984RJzzgNeej0V27SgieAXEaSrwB5eCWvd+4IvDCL62bQRfRkh1+mJ4u/lQhm1B0YdwHCbdAaNmsAoTUC4EgTvAh1JCzhpdpcFnkCwh4Rq1soCA/RK3bigoRlUXXR6RBOi4BzRcTMXWiEIpsRnwS4AtxXZtTSaYRRKugcZwXYNj3ksOqGYvqzFhE+0JCbSWiRjuV9OUk4DlRjeZmOu6uqxEt16wfAvDrLIgxIxnswmONbVCxnJcNa2xn2D+mjEgwqZqWtZgk9kE61cWkwzz51KphLS4vrikN56qFEoljIkIBJJhj2P81kghifKXnRQg4TPuj/5fNC54q5oB1g4oOFykFrM+pv9oGC2tei/6G61SQr6hK1Nz841/jx0+fkj8u/SBzRWL+Tsc2crpz3NLsBPRovxg5CNE7nvYkRVLISnmiHjcSZ+Jw01HIF1ULj0knOgF4YMwxwo5OLkxK6oj+MZ4a3h4AWzB4V3A/B7cizAXQfRzOquy2CA1uc97dXKeO0y9AmEMaN6QTcO/axNqkjRKdiGbMYqOM611sXGOXWXtd3AhOSBUYdeJPzDstUytHchflzqnM5An00n56+0TPL/cEcj/qsWrqZWqFR3Q0Gvb5Jz9Si/R2FXw1euVTm7OrZePXYEtGErU1n9i1rQLGLusXwA95zmQ7Aa3+GNxi/8ltuA+O9E9zo2nBdBDrh2kctsQbYvjsPxzk9/3p8dYOmGf3s3GfTH5CDn8ctYbngZsPbjtqkplwsxg69rtxAHYD3WF+kNN3SAIGQ5KFiRIF6tb7xrN+f/adurAIeP/KvufAJTcA1Ke10yU75M2NNTiN3bCsFlHnki4WFuXDEczejHM73ee2QPD5wJzFWVHsG2yURfRobMEOEkSeLAjHNldEv8MJlq/emocws18MScHIPy7u/L+wzRNZ4KUndZh/wKrRCPPwK7r8yP3TmyXVaIbOpI0qeOi77ZB1SWr6pRDaefmULMpF7/tYM6kx3BivwWYeS2fdqO7LKdcpjgjDWVLqi/MaWqxVNIGPvYnPI8odGbLVZMKngPUxf4Qc+JnAmmFVeON5jP1gijb8bxEf2MlnNqNpA/wVuvlrpA80IquSHOkZonLfHLhlEPjopSN0cDIBcOaVNrjXs7OnJqxSkYPUcC3uogCVh+1wNyVWG9F0GCso10w3y6ZmPuYxi/BJ9lHM0ydPE3MANLFmv0KtTpVbznpPaQSZYfxATDMPaHJTrdmPAu4bFvB7i02quqH4zfBLfRwOownK7xTgCK9EoKjbyQ9YLJoOywJomts/tBFOazJia2HuxGg0bJ0vBoMfWhpY4+32s8EFljdLDMfYxZO2Z3XEmeSh+95NvdCZt/jZwdvti1fsfJr4VlJlVPJKJms4InPMRiTQhKWli1vGWdpn7mCeTnTuO35zAvYf2JJc8mWwFgHKgvNs5+WOtK6ZsxcjCiLDVlKW29eQ3+YLWkYIgloaCWxLpM00TzAT29s/XTb7fxnqr7MLC4ttgy3iJ7uA6CIev92hqN/uSPDhaeiaThiyomWrzvs+dGWPR2zx54vGGnPF3Xak+80p2yT4Rj7lcn2N0otQ3+HJQNlM57wdGTCqmPe4u9PC+jCkvQZ46TA0FaXocOd6gUCeM+kfe63U3kVg3GV8dGr9HUBNsf2kb51aAer00cJtmx2bhbFinP6U+FRfVPkTwGZ+ORZOaw7X6aoj9qUOBuH+s4dLaNWh+yX/ud4h97Ijjr0q9sd+p9+c4cbElcP3H7Y6AgMkQwqv+9iPvsibNnc33VtwgR5puPS5JtmHZ7PBFyhw65TYIxroOsIStKgqF09yK13vcCFV6lDLtJPNC9S10igQmheoxkfgpOkwDBBamGlmolN5/14OrxcfeyAbH0J3WKvdbmqFQ13oixjE9PFU7mTfpzPoAhEm4jcquwLgkuVNIyMQ7VXdKV9oYX+raM6YKY76k2fjauK13/VAi6xEJdiViwelXxTq6Irobpm+IrsG3iFudaeM9CtgvTBw8KV8x+wPwL35i9Fng1O/W7TbFs29piGc+2N5hCPbrOEsKaQhLW+PgPdeoq92KAoN5B9isQONKH5o7YdOg4fLfSe0l/ote0QBNlyzi4trhrYTSRgIxZkvqY+ZagqaZQX1pZXcv6MIjPgUIGtIBZHTcDezf4qOUW0aWf6GftF7VMUbTXtcgnd8nBE2RQ8FYOWZteu8UL03xNuMkmQtvmTKbssY+s/p4Es4EZGccwacEhcA+UUc5QhlRWNlwSlPxW5MPLLSGzehntydLzkxwmGmH41IfobewDQ74iH/zI8HjYet13I+/TKFeioNIH3LOefesTFk+Hu7xkr/EW3CW+NTZZ1Z7Ihrh5r1SNQ9R8Ziar/YTPCEcN+kxr2kZHXR/4C1+Bf98spHiD0mDgSwAoCfzTCRiKhBINXrA6WX5zIXcbpvbSzops6Wyh/yCxcNWPOG9hvH2bFWZcnuORXDRZffNok3tT4+rZNF6bQ9A+rm6kDVEl0NDfYxsjG7AFkHux/T+BjW88cTQXyw867MY8f4bsICb8ItrlfCgMwCanUYP3W7S71KUFVKwJTlBphQwgci1/x2nNVwvkBJCXt5neUkZ+audAO63K60x201xIJhxhlkRpFNFDW+zTqipnqjEfjrpwWtVjjzUY+oau0umTnU7PB7eeefOnRysUXHGZOgBCj8RQI2LBXh/WjTMvHD/Q3wqCN0rrrWtUhGsLohb2FEdWE4+jUbuSqSwIwRgtOggVPxJgbmFg6kxRvoP2RLwBaIkTqkacH11l1PPQjvzfjbK5r/sz+z2hs5NYDkw2of9IcMa/3IyVv7EVKPhS35vdiEn24c3zMRgwAA9bQkHou2VIMACJ42OVOZjWtY1wghIrjSNeCeUGLdnuj+VlrlLC5QfuBm2sB3OMIE4wj/IBmxHPaWEv6J89MBCYIGCA6wQTM57FDCm4xI8NYaV1PkcXiZAI3GrFqHNobZjwa1YteXPYtE30p9JAJMlGhxsV7BA7PHzTuAHCC+p/UzBxmi7bMmrYEwCVHKfvxMngTXBWgP4LyxB4oo+0CdkD/muAOnot5sJzS8mzCNEoqIKM1zLRNrNmykksKgqhgFmJRy0xacDQQyuMvLACXCAYR31a24xi2kD1Y2ZSNvPVBwDdlL64iZmK/FhBO+Jidc1fXVl0oCXk125t1Jfw2MfDf8zHojwxBKRS3RynQRihQCvsClAJabRKQCevgo5nHTOO1FIs/JrSAUMygpxmQgUBthERBoQOZqzHUO5e0aJCcVtsTsVpzXNEk6hwMR2BvHwdLcJ4GiE0iL1Mwn0629yTfM3KA9wg8JpMLjpHlebtQ06qHChbwyx4rJ0zZZ+8N1L5waVhCOH3gk5pZig2EIXx/LBDBjYLpTFUKmovb0nIc2SymDTDvzdpmUssvZdz5lJdHG6L28Bk7Wy74nOpE2buvDXW7oDbRnCYAUNwaY/WDD6jV/oFa7RRQYx+iHOE09K5TLY468qE6qfARPkHDvREmKbiROtBjLXvlmdBai0z1jJuU+X48o3m6wmtFGwk+uevMRxTq6Hrl6pZWqVY0N420D7qJWkKTbRw6ybU0tC9AYOqKh1UbmkC5snLj1hfPitWVuA6BDgCoMS7H0NuVr9ZQnJuFRAK5EMtJVsb9RXAgSFhTzxtq2gBhL5lO+tAVkR9m+LaZkKPyE398trxChnjYKtuI7IvciA5AxG6bM5g/hCD7USa1ewsWaj1SsRRbymJ299ixRwGw097letNMBVNJUcpKIZ0xpqiZHNmuGUYuNNPBgpUqZFxWzsBML+sSdwwCb6DuyBxv6YgV6bQaNLVUV4TOqnOxJnQEwkFYp2CJEZnz2s/fXABpH8S+gPU0rEVbLxjpIx4xQFYVtdqVM06hBtQAMUDjgbL/so5qBKpgGaIK1qxVmG/cEqpD0dnzDd2z59vYtmmECHf6h4AILUOx5wIAcX+7Dzm/K4wPt+PDOg4miL1vD+A8d+3ycL5+OxTQwk4RPAd2cfSePQ7qB1mwhGqUxOBq5DrsQ3ygvxYdPM7nznyQHaP8PHeMuX31rMTYrU9tW3Na283pmdvPSohtvGTkaJ/6xLepT6wD5/kWwpLM74L58cw7yDhyHezREbIcr2LUnm761j+eFW9pKF2iHEsbSx2iHOzyyctPLHcKcJzKLrcb6ylcHznLazbWr2nKb9x2dpznzcOkN6jffI36jR25GFux9/evapz5qNG3vbHeu6WhnxULv7h3f6NvVUM/O/Z6S/cGB8pwExtwP4GY5wqxUDWAXi6w62bZ7IRhUqQH5UhoNjZoKc00NznC4rxGq/PNw/xmVxEeFuahJGfYsWyX4Vw+2M3pqP7ZH6PbB0ZWV+aOQWlPcWUXRTMnO6av+cIxAAE9VZGjW99nsAJGmAFQiGo5oJUkFbs1+NROZdPQM6PFM5FT502JyAZDxUEAfSdeI+UzNM1lRlFlhhTgqNe1FGMkNFyzfuJ4ep8uJUqkCdTY8pc1U4qZSz77MK2Y86O84Z+cf/tntGo5iaJeqc7MGI1bGD/tgTxDQiVOCmVMThKolNnc3Op8KYoMAEXxe4OiWIDP0b4iR9jAYlJSm7l1JqyKF1zOS7qE+0xpFuMzWi1PE+EvokEVBU/PU4hAYgc+E8cAhL5ieTt4Jo7Gag8+cyxJ9HpPzr0anLEM031WF0NHYL/fBmGCfEeryiMxmFjCduOdKMybxlFBfwrQjpKXlrSsLsEIccdGj8bgaDMiZqYtzeejRraoPPFWPF7ZZR7bwllCTU7bBcqysbKN4vljRcOpkxNc8syqZ9aLHkBKsXgqnY5j7yY3m3GnU24O8s33PV9x4X90hPY19iGY1I5cA7TcG4Yts+3IyH0YXKbPet4I4/G9EfPK3ojJ3tdt3vRo8/Ils9O4W8f6DKdPCaHZir1mYze2DZz5iQ376m7DVbK2aKBt6g8222f7ImgSEfTz2Hb7BYI4soNwFxSamE7ij+N1NhvFcAuONDXK7dZm2Njc7P6DpbX1pjzpftavEyBkwJhMt9yI3Cl6Wk4bTk0ibn2zNsPWCfte2EYlh/iTeMKJMufyYK7gaJcRHTZfwwp3DOIIUoz3Fd2RnQWTRfGJeMgVVosGKPEEH5zDHO9vZrHRBT49Qo7Hsv+DeEn6k5lSVcd7iYoDF9dXTAzAEf6Q92LpQrTAmcfZ6DbHsI0NyWNoTZD3cuytekbPlMnozEkkJL/mpzcyVs1KzbupQwktpZl1U0arFByAGz4LWA0o78oXlQx8OUtPgSdw7uEzig95VUDKePzBK3lORLsTacdjPG+BsDgAqBLXODOeyubUrTfh18CIAlc6wUI7M8k74o78XEQe/EKkzarbfAwBVoQdPwc+zxkQJrwCdyHm0d3BsQnsEgfHxvFymMFixsHx7VUzZm/KlR1hSNegMxqeu7sshvnvlipxvlJoqxJjutWUJTZDUab/wFw6oTwdvLw9AZCkOmEEvHUXOczvElXhQqAqDL22lqowiwYIZIX/pFNW+JnUSN8GjJUY6dHUSGNJw1d30TSq7kB1mv3T7YTgG3+8u6YRa4+rG33Nttrv/2c3LaPf3YFefHiGvkWl4X8FdEh7wKaw4xphZ+LwGHH87h6Iwb9yl1XE7+CuHEsefockC/O7OIn7xhSGP/g4ZC7kGH6OanoSkZOPd/Vl9z4OjlXb70pTtHzGA2fjlSMUN9llorjJ3LQjsVDmF/Y+zv5t50F+TONXhpX19+5YCJQGhe+w/yd0ljeeYVfhdkPjcea9YGmXFB5nwtbdd2rjk7uk8KCG/Sq7BcMexxD/3ahewNHQIaZAycf8lpoCNVi3ngKAD01JBXzGnUm/+Kjsp3MmtAC9lkCCnrBNsVI085Yxm6efJGb9Do0EW0WaSP+ZIaRnXN3S4s67zrin5PW0hUQ1U8jJ2QOBAAKjuUlp32ZqI+Uvs/ST8slKSwTh3JzN2krC1LM2ENlx55wU+TzDVM94Nkauga+xXw5P9q+QpaIzew30VMfV3lr1zJ/jrf/bVw67vSXqWTizz+6pgld6ilIibPhvnI7WwlLkMogTRKpOu2+6btYp4IHWkKsdAvYBLMk1fYJ56gK6dACehOoZ6/ndhHIsAcZpLGALDFRtTJB8gQsvLS2SqlF2gBQpmtiGfqMAGRDdisNK8H8A1ANUFLf13TPVDbwpmfN1B23WdC4TY0C0pji6NQ16NeYDalpFDWqh+MyBDMhkG3N/qsYxRbQTGZW9RM6mEyIEAAjanz/14uM/Ti2968w2CqMR9/SXke7zyMGfhuWKj+9xFj5GD6na3aNapyD7Js3PentQi97I5kGmycgDZzDJeW8uEQKSfDC6wX5qDzjPXtfRc0oHPaca7TlBPTDT13Oqop0FcSYIhdAhvGdOAWhHogNfNhjAlXJ5Q4xC2niBtEA8My0JhNNQlkTs7GNoHIUW1A7T9fKOOlCvIi0u5ApBi+tuBrx5WQQOAvo7j7a7onbY7QLlgakiiKDPVeQbH6cxJMpJoNJEr4zJza8tBP7yFSDKeBrE7yfIm+pucqjqz85Fju8yuWqct6NeZG1yv/jQLnOtS3fkIC/ucpBf73SQR4xykNf3OEhl48hGFQ1OCavDf4+75DkEnH6mkZpeC6rJDEJq2qN3joNxVetK4+A8iwwVvOh6jfl0F0AzsWcATaAXQ4QmvVMAnEx0ADTvGbK2fLWf5EljlQi+xTK5bIy50s6hn0lfQPqUVzvBmQUKzsxNAM58Wyc4kyV6dhSdOXPdzABsJlTmhm0/zywvatABBpWnFKi+0Xagfk6R7JDhN8OrBnmV/K+4Dk8SsTP0Q1C6/wq5lhiabHSneFClxH/688Rt2qytDLIkEH9kN8LP2207Zue1CSO2uF7pK+ynCVkpZPQ03dHRTsaz1XK5JEJnf0opbZeJxk2R46C/5yfRKawW08g4iCUsF4lDMk6ymagYz1uFrcYuCxdzNkVM3y5d2G+LDubRuAZUyxLiEFxTNDnLYAk03p+O8qNTWAVYdEUxaE9wHsByiTdQJMkGTV7j6RhcjRDCbWV2W8ykpkiHtFXMIKFNnP53bH1wkRvQQvgzWmvuJAvtZNftzEL93iTU7k+N2zkw8VfXaV1bh5iuRJqw15ihcnh/+vy/O8lNDTOKCBLkpnhdjZPFWUVT+xLTP+7Ikpc4ykCCwQiP6RvyZKTTWQ9U2Mimz+98HxZ4gfMUVFlRdUviSBaNCieFLPpvxshN392VmyJKRbkwN31cR27qp9Ox7swU/J0ka86TrPm6IGsGqzd2TrUwb76FJtkizbFfzyJohW9+1J9f/GvHGz9JLbmQXsagqS+zRmAh5AoJ9gdgf70VRWgwYiOyM83h2WatXVkGCqQclRYVFthFhtmOZsGvt3ZAsTcD7DHES79vz6esGRkr2LHcgZJcMR2fJcze6hI4oHCWAclYXl/z8aQkV89mEtIfMlM9pAqf6yJVuOmxuEXAtVLKu0xienrat0rMRWYlxitEytGJlw/n4iXT9nNpfx5yibwIDdJUKiEm8FOm1WIhB5EDxZLe3vizYXwKLPucYKGTUdPW88kgqSV7PhM5iCd3f/DstAAaP/jptf+wYX64yITxkh+tObwWnkKqVy2Ox5vwr3Y1FbctU4wx5EGfV5Kz6JQHD3rO8HVCjRVDCDlaUUwhrmfXbWfNvhqUUSYI9ZlR4tRruTSWPanKdG0s3oT/UXM8zQ4U1zLE9AFfTCrYfQH9JRL6qJDCbFIFxju3lgMzGJw/aep581w5HlNYs3xHsFTttZaqnZa8bw7gLXxaMZkHtqNMoFK734a5ZiOzkIO7l9yhXKAWQJ8bvf0CGgOPTDsOswFkB4vzdiCkGxCPB9Jttc2QLJWucDqrwaxsxWNaOf56eOcGAgX07Ijtap7i84n5cTW+U085imlmD+ZP3nvi/QDJYNPKcUCpv3nrupkpmb58qHq8WDXBbI98AZJ+0a1vO1kItmFWLGpzwCfRzTlTT6o3vO8GvdJ4BDJipVDMIQ9jvFwhXrusxvOFajlG9HXZdMpbMNxzsDSHpL/kVy4oXFO7hHkqsm3HMFOEeJwRDNOpCCDuYQ/aaR2bVIs+Rs6N73BuJg90O6nFIPRQOlaQzbgMAjE3mVKiIlkghIHuF5DHgT/dECRBz2eTUvFAMRtXDTuKUg5ZoZz0nbpsVvx4IunipjfX/fNym63TtBY5DBbqd41zmrg9OU0TcVlse8aw/0gO0YSnzJ6IzYK1Bh4/ADus8PjFyNxv6AF88lCGi2PhAVyAGuNzxiezoPCdb7ZC572EteRsBU9mLFD25hiQ6bMSX7c+PAYw+4rtt3TPfARu3Ni9/9u/3Puskeu5gRY6+1N0U86BhPUrmi7RTke4I0xXKtIMAs1chHgD361Pbg7UO3cZorJO+3Xh/i5lyByomP5DB8pKtaRZIemKqCX8lPFwsqYkKzO6p6GglWO2hLQliU26uORo6YQXfwGMrLNdsuO9kuVbT2dLs3UhWC80oOHslcgCXqfm+U0dmufMe92CbSKCy7qS8L24mU4m9ZtpJA3SGbtqANfjZDJ5V6lUixKCuyO9GBvf9jfaGuLp3g3AFhda40lUCGVmvsopJh/1rWhlbkocpGVOEkYsmzGci7WiJ+AW7SglRuWNnYcXT5cPb1uyiB+SV8wyRMo5x3Tym4OgDo0JTKeZl2x4cz48GIeumTrixGWg8t5KHUEezQBWTE8cLhpXz6T8eGPdn0ZfWgu2pWeNKojbF1eMulNzajhFrB4QVhDHTGaWFpZYf8Odgp48a9Zo+kiedvlILp7XLct3rUrzeacNUIHUT9TaT/tbDCC2dY2yk8pJL2CoyBxOEIYKJqSosGbBS0IfIRH+mwF28dVdMqNjSVK526uMchNE0w7F0L8dQ3NqpGDo304SI1sCoOKJkfJSF3Ej9T9fM0noo3nJt6itViK3E9EEZmfcH9UJLMFszxvCPkCkNjsJP0YKbTYumOjS+p0x+EKYApg+ipkm00duFNPH309imsYVbdjWozt5QtKEJ4QeMqKFWALBw+/tXFsTYDhAYygj5ijWEHxBwqPTJWE/QeK6G8FM1sfv5MZLtaI4zO6BciHbFs28cLK8tbBtrqelDXrPsVEFzRJPpdU0L8VcRTd4cu+zWlZra2E+OFmGSk/pd+gpPRX5dWLufh6YcSLrQPKXSTJTbow8sofvZfuI+9qBSeCrJznZ126bQerd2d2+bQT/+pld5InO+vWjc0dy2D9O7f8wMK3TGC36HaM4OsigoJneEdwRZrRfTBK/EZxhrkdVj5SVLCAGZMT2KcU1NFdy5mbreudw7WhdK3ujbT9h7M6z7IUHUnMZQlGWITO0O0RsH0gxNZdNiq3pmSdl5zPQTb9suH2/MPF9Sk5qDqXfMyEWN1Hhtzcynj+Z5Ll+bG+kOf91otNxe6DCuTjyUC5uo8LpnP4iPUGPBvLhgySC1lomOcDUy+EyxOYBdpznfYAJDRaQIGXwKfpq4Xmk3S9mArvbROlglbSXCWt1Das9NdBdCO69Zi1ONPBimOyBSXBDQZ8iJmChRnv3GCa6H7KUsgwlIAVavkpZIcIHORlTG42VpRk3mWncP4mnoNiLRaNfwdhb5X9PwQiDmQZvlW2b4JJgL2AcBRMSBTXuKBseQsyPuuhckxkFwwLFQlpuIH+ZVeU4+ZfZifzoYjbO8Iyhyg4baGXGCFSxcPqfQX5UjhQj10buxgozHdJQXqflHphTgHJidlG3c3TQHLpTwKgVJlho6YCNi9Q3BOfU4FFGqTrldRIpr1MmQDDxDc3JYMKfMMqABKBS972kcSmp1CVlGkJbpFIX7bjhu0lwCsQlW4PcZvx5eGz6+7WMoijYgcOE7dedOT0uappVs7MFF1OnSgZ9UYmrHxOJRikbMD2xNyN2+yJqDMOd9y970/Gf+IvM152CZRZRomtywnfjRiqR0G/wHGDTSclY8O2UgeEm0Ut1lVKlgJGDaksv0hXZanyJAbOk75LaMYpxo0LItohdmVdlZ9COVX37DRg4RGGJz2DpzYfgANlj/PjOstq+5uWYoNHAlvwGZTWjo10K/m6dXsIuQyJCOTBhUNR3OAk2YDfqPXA4bOZ8eKKe5u3AKsnJvGJWyZBYJkPiBIbEsWBI7M66FK5YrGu1g8W75Jyp+MwLnBndSFtVJ5oAcElhJFvJ5whNaGoOTBEiWMK0NFadBNG1scV1G8Qza5j9xuME1Ijpv6eYSYHguKvjNzqZz2LzKJ30JCNnCthTiKmOhi+lmZpqI5lyCSUMKlU5M1+4STKQ4ORYZIHJNFmKJhCIsixCSUVB1hxQ5RM2PcWMY2cvxv2qIDoaT/0RWHNgBfj2WG/e+9fUIoUnfYJtwF9WQHP32sifwF/IHA7wJW6bzIi0xgbwDvSDkgY5yCxDHMTNtCJ8jbjIDPkogB41ifJG+gjGwcwv2eWcz99sZbOlhLpNCmWXy2XHnG383yGeQeAcQzzjHmeWeEbNiaay2CfhVVXJg0CWS84GjhHj2hGCfcJQx/icKkTl6BHVsT09lgizrCeFWRa8oDPL0jFL11SfyfGakUsnABKwBF0345oHpIkqoiEoaq7i1H0z6VpJJarkl0u3ypAZh6txqu4niYtAmlBPuWaMOkluJciO4SO4b2wF8503dbnI0R4XaXw5VaXj3zy4aH+IpuuVJBnj+tp4a61cub94pSPg4cyHp2U/kTKa/boj6NcphDCJVH8xcmG6hEwGWCtdKh/r6Nm9s/GNDobDcifD4YlfZ86POa4V7e3NWZZe0axCLJzuYvwVIw26h3U06N7YuGkIqSFL05+voKuZQFp6M0rIidLSMfo2DJEmp6cF6QsBlzbPBVnTCVm5MXr8rzPfrrkM69ZY/553ACrY+hJjgLFPUdWMjoG7VjDXnrD/yEuPMd+YrHgbSeg6xWDRO2FphNxHjKkexIhIT5cNVm2pZT6B7dkZ3HrP6SZL2sWdN0lzRkSHliXtIX/VW2lmu/Vu222w75voXpuwMfP7MUdOfmV9dfb6Eg+SXUxqjAVn6y9hVb9p1dwOrq//O+ngkE4VeJwzUyP8rTiSrkqwvXQC+GmctwKocZ4a+U1Cl7QbapwJDqkI1yCbjf7q4KMY7qIzI0js2ZM7Iphv/NYkp/mtyROXnsriMPIDDiyKGmJb5BuDOexXd0guz2YmOfC/SGsYMZl2WqfawvMhx7px3yDaeuoOD8IdZsDncFnkWYStrpfPwd5jW5dqM1y519idWzHE8AfXriIl+9VrzdL9D/bWhEy8eOGdf/4b3Ub8dm934LaZzbwSy+5bXNzMxuPZTeaPJrHOM0ZY56uGicZazDQ08O9jBkQRzJ9m/wrkvs+BHPHPGMHMjkcr/DNCKJ8ezTv8M4QhX9PPVPz4XqbirbhFeUQ/CWNLgEjdS83dBn9mQ3FwSti8ViOAqXpJCPZeVinSd3Ojw7KdRByEi6O1JEXubqFjr8n3wnlvLcRDiYP+wN2q5P8XWHIxBMgrWJu9umiIOkyCbIGXtHhiXSFhLWfds3zjSvpA2rcEwUpkjEdJIqbrgPmqYlzly4QOCWBRkcdTI6aBMWQRvBk6rAaUpMgr2eWUqONZs8iZFUBy0S5wStqROJ6/Dj4UVBiEEAOMh/g0iu02mX0jm8m4SNQZRZ63FPBBsuxPWDEqCrwk4Evcky5hzSwmpsRMsQK2ECIVEpv1DSvOXCsYBFxhiRY0N2PTyFrxk8HkAhryEo98wdRliQM3FtrejpnUldyFJWyyyUnF1+MS4W1nFWfKfTguchHYYZ3s8/AS2kYCeS4MN+VP27mK9b/ugmOJIuhFUvKp+0M6iG8BFTwFtMUL++gg6GbhnpBBdEuJr20cZHrExNn3tSggGuzeUkC8eZQ0eCftg1yV26QPKaiT7pb0we/S+Hb37d90u1W+Q6aHL+HJE6aH1/9MmB62kXdn37wHm2PP2yWxw1tH2ewskDmUulXaf6FHpR25igHw2hex1PNIRMkPRf4dxWLnThfdl1lrRrxmpCNkYT33GW3ANENf9z1KqnA7kGgEq1gY80K8WsC3Tr8YoU0HhVEInAc8lcA/6ptErcI7wBZRpqBa2VzBT0P4XeqI2sVZloAXmCxGtFSTVmvxeod9GnwrCPnAKULwfpBQZZkFzQBpEJDZTqIOdgvEHWxNKYQBSaeUm4LAq7xiK4qP9isJncgfEIwMoIsQOs28CbY//EXMjsUx9VQUt04go6SnhQw5KgupPPMxWUCHR3JEcpGCqB2zY5lPNIgmgSleT3QkYxpTSSOygWSZeCLPa27jp9OzGsGe4n5HjYH3iALcEZE6TsCsLLkaZHylGAmkArkHmKtiBeBrY7nlbHalIOFW5RF4NfReaWMChLaCuCzJcQcZhKJlVMmU1ISiWDELvk7A9VOOswB0ekwAu3MyJvkOvjPfeG0UNwXwuXassqqklRi+DPpB+Kl5Ebsn8tQcAFoJgoolNIcI/7dFKZGUgFvCpj9rlNxHGgs9DnSWeQlrTpjvgulaFiwdPwOeTPnKZwloOuPXw+/FxyUwZNeMP6TL5F8BpwiHPcTbI/eFDOA7Z/RgJgsjA0L7eMyiF8UPXz6sjLqnr4za+swuA8vIy6BR6+Qayc+vzec7uEYWL3z4BYvFHRN4MM/YRfw5t/sGqZYrPTfI1keGMocGhCHfCz3h5ZPvo+7NdbK4qy3TjNy44EyY+qO73STdhTET3ZfJrf2XiYkNUWKwcyN3oEf/vr7B65IQCBcFw1emuLrtYHWPrccMGbbe3T1s1W2Ta89bmb/ebpi69ckzcozP7Zuy5kQD23t0ygocIeOojmcpZMso6qWT4SDVTzcHqfMq0Jq4l562C2PPjc4ctt7dHK+6LF3/Ayo0VNy4HCriz4+8N/INutophOcyTAiEZZojlNZBpNePtEV0bx3f1bZYCwMLOULAnzjm2/BnbLWP6gip8QHKHdEoBI3iUSKY4VSwfqeJisRCjkmOMYqty1G8IlmulozHJUOA4xDxKTA3sFjjQ30uqzE+qnAiBQBxIjA/oozW48j3oAHL8i8eRzCEvWq46ngPFzHzQslFEcXx4B7LHyl7C55sC6zE8BxWDIulvIRX9CRKd0XNplNyej1rWeAAW4/bJKsQRQLYwntjRtJiBMZKpP2UZxZNzCS3f1/mYJaXXzWW7MjXrx0oRz5cKMKGHMEloJ67IPLHxAX3RI5ggLeJZPY43BlFwevo4O3kCKzz44kZvHsPxAyWB/kcC2zNcJckmTD1R24Xx4C9cq9VENh7+/2smFv2z2/6YbH/75fNeZ96oLDjE+BZlvYnY2oo5E5/nruKi2Ng/c7I30a+SbrAm2Uh2AXAPukBhlIY0EYFbeXiNmNF0tENe8Q/h04HHnXk4TOk3Gp2le9axLazhj6G5aDN+CALVgwj65Ii5nV6pZyC0/h53XYWH/Gkw4ef9Igl6efO436zsHJuvnBoKZdbOlTIn7tSOLqQxi6zYZp5iCInXBMBVU9gQgtBUNv0iPR8OVGdS8RiiTn29Wfd+z48jvc1Hq1C1QccRkQJK6qg8y2f/iq2fONIo78USNoF1g74h+vBEn3oAH397NbyfAeDU4bugeap75B3Dnwb9uQdDwU8fCXEaTTZFPA9N+m3DjrqmBGT1TbaIdhcH07tgRUaOC35ubBLA/qOW1THQQlu8FTCTDQMlaPuoVp42SW3pBq7TCDbXahPUX0acRZ3J0rTkO2J8LKkV2kHPEr8jr7BaL6Bpa0A9FHnGYE0V1FKJ2TGcDTBBsX4V7Q0OgEefAy9A82YNwN+C+ir6Wagr9Zk9hACfbUrsIUTBTsGYU6OAeEe43PlbBQoq6gV8xR0yn9HrpN2+Hu6FuvR6+bDvfpbZlTbchR3NXvJTagqDB5vfnDQO93NczZc+l45nUnFb+cUTePQr9d1xjPpt/4t8iNpXsEONdbgJEpcVtFv1zpZPt7ZYvnItferfKlUKcq8grsWFFNYcpOQ7v1+5Ks/43RvLJrmHbH56j+bRO+uMcmema+Oywn8M0/13jAGa/RPRzIMv7eT+O5JFCOPDWv2fzFd/RBxPGJDeIPfvCARVajXbARO05rFuZ3lY2u4Snxze2H5zsZm6MbhfGi9HvZIybdixqM0YHKxZFQiBRv4WmQbrPl8nIlGoxLvySzmPxh56FGJ5PmspJJpLOwXY/D7L7rpetIomCP15PHv3DrRRFTzaccDw4cTO0xmKVGGj0Zl+i1M5rJxCA8gY0t6oXnA1CRbXpYsDR/ZRkZMgbI4ytMBBipnXrESphuPg/ok7aHbB2CTK/Ks6UxnjLzuLMgjBOUPE9q9WdkoGXIOXUusnrp27EIE4pipTQkaH8P0CAdi63vbEiOEfgFqoZdGHvw58wuOSL52gIKbjDVkRlUiX5niqTzcfPv51f1cE4ZM3kZ0d+E7za7Xz951voRvjdsw5XDMn7k1x7QZ1jWNaRWr0+8V0KAgo15QF2HwAsIaLr+wtlQVudpsjUtOmTLawrpR9Xg/X7aubXwuBpFeXLwM+9OfG0e7R3PQxZFkrCSJnmUmyO2PqgpYSpaAyQEDkpSU49D9Z4Jwr2rU8/6e/QHnQZj9d+B5a63ZYreXtWFZfXdlz+yk7UoEQdT22Jabwh+DDwJfszeaABOBFLShg4UEeXUIhwu0hR5uKjOfpx17TGd7fAaZQAy/aIw4TZyJK4LlJSS4jVm2JWAxEsBIGbHQQfy0U2g6iIQOVuiAMTKr16P0WRKmmTgYFyz7L4xyzi4trhpxW8ruz5KUSwsWlonIa2FteSXnzyhYbxYTPqCSD0QpNFIl9wodfHAKWIiKiSyuFQDifR17BRJw7yIXY0Qlc07NX/BVF5LSDI8hdOqAgc+NFC41Vc1m0spNlg8JiXn0xZXgC8KX8BXjrlJ0cOnpZsnSUnZlNdF4HuRmE26w8pw/mSIrz+HG8424xswaEJdca+3ZBsLyi11rz1ijHVujHTYaY/95D4JYyNFSr40Vqbq2ptlxRdsZ9v5R69O/2Y5ZZfjDzmIWcT6AkBMwmuVsG51ay9bAQo/UbTcqqVHr1uz7J41IyJIwkZNJoBCtMSIPxTCX8JP9F8bpvzlWGKFdKpamvHsTR0ZgoJkvjwgauq7ToIElFcQML6770CCfOGo07h0sEP8awKfZ5w+JETP1ug96iwSNEQkaI+B2RiZbdMeJEr8wIEqc7I4SACuOgl//MzAXEsCgr498bG+ykJ0d4DFT0Op4wG2mdvaO7pg5aWoMoDcnnO3Tu/XV7RLUd2yPD/8s8OEu8OHvifzDhPhwZvfeRBs6nZECxGBd7rve5705kl6dcUw589HduRkGstG2l8VCh0aiONSheX7rP7dHoNfGR6Cz7zdJV2rnboYYY2hO281Y6td6QkYpTN3al12z16sFp/F3oyDrVTCBWJyJ1s0Dkc9EPjeweUOvks6bpWMae4hpOUir4ec5NcEf3rlphTmUVGvtN+YYu3lrAQbL1bqwRhmWNHnwXgA0SwKyqnLX2lWxozJjuNI6e21UZMhSkGNGvWldz+m8CLsmk5bEM7Kly5yR02XHN9KYjMqmCPSqSBpyQANFLTR3NCBVNI6PBg0ZqOCoMdmOiYTCGU8VDoc3xWT8E16JBmBVyPaksJfyXj6uOmm6y4kwqYXLnCGmIfrf0sbxS49vyEcdM26LWpBDMc+1TC0bw30WB86XebRENs4AmY4KhWNVf8UXcK3F8f00gJFKoJ3DS7ipcNtpuWxGyZ6Tw7qt6+zzDIXsR6H7B/eOxT3VRu/FTmaT6QSm0XbNsRzyNmCEBHpP4mYiMDeIIxLkTdSg78yem+eVxttjhqg2d6zYm/yDGtkKBVdR6pJrbrjqIt87lLWLG7TLyYqi4ns0o8LTE62kTuAj7DkM7TV/AQqVQqROScTHwzn/XLSk2f8ZDXtuPO1n2G9e7wc+39gLfH4obnk/R11m3Gerpz8FWVkOwjC/E/kUTYXOWoOYRJlaK8qM1x6m5TOpkQdiexdjUfvstINJYAFo6JfHbAWzNwpYtjTSos51Q0iY59vT2lns+8ZIfLHpG0snP0i7vnd3dn2zhXR31/fZccQaU89dWHT3nTMAXrwKEYs0/Oc5kTdH/vzs+k/n2+wefcGNjjVIdF1+bvwmeI+W+es2Cp2ZXoAHFVoodPK/7/6cuEv7faWTjXe1IezHSoeLbroJYU9nk9yP235y3gXn9vvJNPixbOon7w2SmT4/aYqtnqkwE2QyO4QoMv7maNdZjbM22hFmh+uYGXQhsSYBkKFW6nSdqQlDDi6+uJbdKb4xu1n7wQ7cSYVDYd5frJSU7Kqne213Ory30ed0ZIfQSI/JPr3tZYfOO9jvZcvYqz4GsPx85C6ivW2v0JSWC+GKLUXfWtj1a6/2bawwAdS9na2SlKgmAoEIkk/s/4huMH1cqvdTfWJjhTB9CgTQho9WVr1NZiX42uE9hq+nB6Ny2kLgfgSQdy2bAFMDAVfzdtI9UMqfm00XNagXoTBGrojb3FZnDggq82PsOqBRIntokqOZjfzUWDCCzJWMsxUnGGfHY2Ja9nSND8bZ+Gus/PENGRuEKE1IG1yKSxnDxFqfQC4t0gwRzRwRSxCyqaMXXVJZeNT84g21wjTGDqaxVFhanbliZt8+f96zYIacMhNjGp+l3BAyxoBIvcPhNHEqBf0JNWD/TMexlZ7qpf+MkooP0wag7Dd5AntgGh9RlKnEwi1L9uxMXTctlnVQT007zowDwszUwfUyyqAsurgXcVokgYr76ZEXhZGD5AVh7zZc0GIGoAkXmWqT959b7lCyqTVhhAEqfRiQkJA3oe9C/hm5XA6zzG8cXBWEx96Snp+aSSyWa7PlK+ecbCrFSD3Qv2jjPN71LYaT44JtadgjI6A/QiRmCSHsj09qZinWBv4l24CXxiuiasr1N5YqPCf603l3ppJi/6Pw5EsfczODijv/mPX164qZFBpfgrT1XQLSc0BH2gnSexhL4HlOFvEmyjx0OwXo8QSeQyB61wOXIilsS2u7H6S34NWLKXhfPe/OlhPYQrCK1BJf5i7A2SKWuCXy7KGW4HppCPDwEHyB6W3d0TblQg/hnGstZfQs0/n8y2M//7d2CdEHvh9fvv2BJ5GGFBs1cctOKzZg3hq6hnhqcsEsxmURKCM36liItGop1/iNAQ/9m4Mf+k//q+y/rINbAMK9GYLRYMgFWUE5wDz0UrOO5U8qbf5cvhJIm2sl60ls+zkLcwMeM4/H/LHQ4R8Faoh3Rz46yuVb7IGEzbaFy+7dlWVbmk3cphh0ezY6cLVDj4TbPgsBywTeyy2Xe+ybYQK9n3EPy1x2RiEhRxBMKJHIUweh34StAtlDL0UFqABoMA388Cr0JVLEacFbxdu+H9uIW6bOk2jlx/E7jDxRl7bO0qPgAyo+jguWpf7qdC5wlGSYakHSZ3MHh+3HkimQ0QNH7s5LzbqDm0oEkkNUU7qUkpKWADUHgextSkkJW7RiIp2WmKiqEsneOPuvj+0+iVf0nMTHcW2A2FPoCXboCa74L3P91uHmC5U8WmN/OsB7BJA2fYK7lHrPochjMGN/C+GnHOY/TuAsuAlhU7x8gPwd7VDi/3BECUEyNxbusElCMtg7QhqSPhexyWoORuuo+JmXDvGWX0oni1ecXPFFP5/3L8p7Xv7h5CNolqS2Aw423kBtL1jE9K+aOdBr+gCdrfTb/3tmslgvTg11gytzm3ZCyB2anc9nHScLSp6kqZCP9Bpz51jwvycH8Gli3JT/lk7j5mFcQlTyB/3mbaxwCSeRTCSzPsJxCjDqY5wFGPU1SHbu3xsgtR14Co0RZCiBYzyW/asbtS7LbrJv3wP0882/+ARRvOnG1HSthpVGS6ycexXzw22t/my+WHBX5os4pW4t69SLCX7HoOUHxac/4ZqbeU3TphZXEhuP2Eg0PjuOYY9VDmO5u5yB2TxALAxqqQKS0uvpmbwMu8+/OfQ82rtZn9rcg7RmyNl7aJdyfZ/fPtvptNddOwjAH9vlNtWXru2OvBftMgcqAKUbmPJG0HM/MDwHmkxhmTlzRn3R3ugrM/925ow8s1fKym/fE6vzsPrXQqvPgb7gGYSxa9iV2sMjsweGtHvFk4dZtvGNPsnjeyY20o96RZOHWu35PVLHzMv24uk3XtKjmEys8S+hNa6mCc6HR1UiEy032pNbjxuyzzjMiF+bbM/x8RMb/KK+lcZhFv/pf+xq1/F/9sQtnj5wu7GK9dYGligWQEH5ItL+GdH92ejs8pH+j0dL0gV23Sybwcf0jSZZeiALD6FwyzpFiZLPYMVmk6f3qmboNJ77esqppP2MLtImj+U7+wrZQ6lUXrF46OMRLgIO7JroiiylBAUr8TEPXEiuzJ3HAqPjY7BpglRFtg0Poi3R85iY67oadAOZra8bmqYAV4cvq8d8VfOJIJbAU34ZrONoCfb7UT6XOnL8osrCFfNL1wc9HSPo6Vw6k1nK+DM+aepkFT8BtfRHps7BSLSEIV+kcdpb0UwpZi757OGoGIVGmB8VDGVqcdV70We0ajkJRLsyNT9vNg6gf+Mv3rRUu7RAujcuEf628o47jVjlpA6tEQLuOpKfDLoGl6Hz+6YAatPdYivVHYG0zegwcVBzzfHdQa25Ut2lhGljN/js0R059rO819li04o6UYHtba4hnWBkg+l7r2w0Sjvo6XHbNOWYTdLvpW02OWyzQfJSyw1tr5lLVplp/RsgEjT6b36NYT6zg/be1ovHaMl52CG+ggbgCzE2vG9HLbnBC75dfR+x7AbWDj4evvrL9+U8LxhSRGbGW83tCo7+xeQjFPfLWW/4zm7jNeMnNo3IWAu1YNLsjH6Hmu0iRh24aCvFoEX5BwOzVe/0t0NDnQvQ80t21LELSvZiu2V3Zk1034AWXjBGZY63RmWVM2yggX09srUTzr3YD++NZfgOy1wa+bXIb0X+YnhRuHOiyj0yFTcOncowe/5X/Mgjb37k4YEsK6+CsHE3y8qT98iwt3fSqhSXNpaKHbQqyycvP7E81PQPdfCtnMout0krUzrhePOabCvXNEkrP7AnvtB48VB6FR5Syv/CHeVETLOujrwg8vuMGEJVAxNC1CVIZ+u1FqskdRrclish4K8jy+lghwKMSejiYiJfBcAdLHAGlyeBEofXbAu+g5nWSvjV7LXwX5HlmJIQvpk6C12RyZHOEvUtG7syBG1I4D9NYH05cEr60zj0QifyNLOkVOriiGr+ZGRAsBa6fPiPsgxzZ3ZWSYnc+uLjtIQEtkIJrHbesg5OuljeL8wBgSwbMU0RQBpmNB5UFK3gu2u57JFy8dxsbtVzS5rvZ6eQV2TPLZaPZHNrrl/QEkwK9HysJACHl9YSCsZVOpScoc8cNSQFWjSE5xCMfLz879DN9jUtY9pF/NGtjKZ5UN0zzIyWsfSifQE+yJrWs1RfUKKGLZFkGIhSwJbTmnuRiS8IH45qDvmUQtegcgq8c0yLKlEqYYO4A6omzUkB8EaQ0+y/mlPpAydvXlokn2B3Vc8vz+9LrniJqp3GLANOTJHfW7/ulw3Nj2M3hiUpJrIHX0ttLOeyRgybN62X8syfyW5MpjSAcDh8U0Ny4OeyEyO/YAzMhNGoIsXsxp0xsiqLb0BSVnwQ1QkKjZBYElysKrIHID2IZxbFPBAUgjJ+2gPIbOJRrJuDl8pBA0mQeEKihV+FSGWHTJHMURQttiyBtQrjcVBogruKtcPO5rnobD4Skn+/HfkjdDZXPNL9CjG2dBJfC4WWvBXSxNwM1vOpvi5pc4JyjGhFE3S017nMVSO9UZ2eoZXV/l4nv7vA2d/7dKss42QKSuNyt55Ax5MnNVBUTs972Pb8xNot60qlkhfRv8isZRqvwRolSD6BdUyaZO0mIWegty0JppxadxsvJEgx9EoBvk8NaIf+z24i56v7O6RzTgrdHRKBylZqNWVXbRPZJm2QyqpZZin3DRdL0KAIVC6gDDxJVQt0HPyNvnbp03YeHe8f1DtdhJq8gYpuH6jSn0BTmK4CzGwWbYeYsuu1SvWuqg1b6qvrZWYntaC9TV3HXnOMFGOeTooxUrUZpGo7hqpNAL1qZ9mGQfexY42X76QO5Lat7Q4+sqsMizSLt6c8E6VbLB7UbpsdtVtxeg4M/L/GrOyoKHz9GOXdzOmvsl+HfRbRFnv1doCLvpI75JmcgGGAH13U/W9QkuUtWmmRkuwwLcmqtCSDAwthTeZtZAG0eKK2oJVz8riEAZDo6aniMp1VnLEdtCK7mWkVXx6eeOMUMfFSrWPnX1LG3fkvVgrY+f/jMeq3AiUFIMnnUWzA3D28ftvzjf2xu9SMuec79o2f7qAF/cOJ9+E/3LkP/9jMkGnCt4GdHMMQPeDG2hpZ7+jly7XPiCGe2Kq+tn4wkC73n86IAR7bQZcrWCDDbRPmZotpOiF96cjn/6LO5//qzJC+/sfQLgygFvdgn+cvQwtw4SWyV0CLI8wI03DdltkeaNGTblDLsZm1S9Y2rywvVtqWm94DnMUnxzbuR7fDWeznU7Oh8RMw/lw1MP7UiY2C5hdu3kOYxY93cDAbN2yLs5g7ZrQdR3Jz9OB+CyJlxHEeDe3wtw8/uHSX29uWTwB3Xw+ZQLkkttgEsBzOnImz3fgmSd8pR8BXezgC7uvlCPiIbby8kxogWZyyFzY7uAHgD+oZiQS/7S45koQT37Xpj50ZuulPuASw658Mdv2by/4eOsOPnTg8VwF441GHHI1cBe3IN+wFd/YAfEW7sABeo9Qc8ZOd8w2S6ra6PdSDiI6k0A+2+EyLQXt/P4P2A41LhjNof6i5uLd0oL+6YBOoG7A/BZkq6E6U5WyVj9oetOmUlAqEMo+FuywqVioeB8RSf1WxMwJt9iv9qIvnkSONiVaspN0Gf0pD2hb/5GIW+GIhrpKpkW5INXkjt7669vT+AoLE+G+CVyuY3V4LoMzbhh5Wv/fc+Ds4dEyPBPBqcZC67+YYCr3DTmu0/8z897gHbuu7nbK/zD8O1PS9YltZ3mFn9Hv9x4fbSQwW2Fieyv2uULlfoudbdcz5hfmmnu+dfLwlyBvvF+QlVv4sdzG18h2Rd4BX8tPD+6n4lARhkUz6wJaHffuA9cWjBSUMEnwcbKwxYgtsM5zalqWBfaL0y8a3paQgeDcR7BriAxehEnSTpZNVbzpvB88jygtuwhNFlCT3QTvEwtKqKlCwFTSv5QwKCsm11Aq8gOdVUS+aKkKonQOwZy6TrRS5eEbzXj1J4AYQfXpOB2UNKyto5Qzrrz5ITIefV8kkrfmlBUvWVVWSNQ6yMgZ4Kzi5oitqlENfS1XSNgAoHBBFWsHSEhYE7XQMRh01CYW6mmuloFCXO1oqTFejsgHlktRkkb5xqZLCvvcS6bmSq/072FNpxov7zky04HaD9DoTgWF1lxCvMxUJvrxLfFcIzSpTw90MEsW37SU0K9g/7YBnnYls7L5dArPM2RTR7OmAZt1xRvKwXaOyUlNkA7mNyvrghIkZH8kDjyW0zujtWJE/M3d6D5ir2ofEeskZuKr/Tx+Kyx0XgzXp6XtZD4RrZQD26m/Y03jy52Ii9aLI6yJ/MDmDPDf8nt71GRuGurp/MnTVd4bMOic5b1f04a2W27Cq64bBqnKlTDesissNwRw8NOHleBuWyHjGs/R0J9BqFm15kGtEHo6+FYGeO22U3KEOwpKhnd/VsBu/GubLNGVeodv/pk9larpwQB1EBEKVTCHZ2tDW/PWY1iU8ARrFIOw4yZn5kc12gXTm3TSaFBdzdHIix6WiiWf8FkGVDVXH5C6U/rYCjgFu65+BrTPI4xzWn78xmfN19JfRWMnE/pM9/MurnY32c2cy+zL+XEejHU35xKGjJ0pfVNMq5jwY/nA5EEWbbGPmI2ocGmGcncio7GVtPd05nz/1muPfSy09gxfN8y4+kahd1dGin6Yt+qqT2pjP4GKcPv1PXJXjUcY+IfIyisFqwxrJNGu9DEtpgaw2qUmboZPs5BPDrLenXZ7g2oOlZrsQI9xBprkii8NtOjRDDnlBcCKjG3RkRl8lX3SDfQrqTExPMVpVybTKg7qucPWlXqVYcuyULuRL2RNlI+F62nw9Gnf4soFnJufyhhjlOOY9wRq1Mn1wGILk8ehhPg8DsphnpglTCEgeJDGOYS0GkViJbbxW0LNWLe9HCc91CtHrTQSjiLRHoBtc74ChH3UjoZPQdaDgkis351PJKBGBE5MPW40T2ohfRIbkclE7gDBu3RV0Ll9DsCRwOB1YEj6Tb2JJ2F+WPclUcQijnlLkG8+lhzDKSRj6ZY7mmemDxw/O/NH8RYrIuVNZh3TK+GkcujWgG78LKN1F0Kx8XUg9NnhIcpBZD1uYB9uSiAfZ2npAzdL5IlPd0chmOxDdbQQzp9psMtMxLsH88bCfxBIw6UaqujFrMgftHKa99FO5nmq8ckdzGm6bsQv7os55ybtb85K0GS9PT2uaDJI8URLpmAWBVcxWqibhpMRPilcNCpxji+t372h4MxZ0rnP0ciVah5ONXvoWquhdzIY2wzZXvRSSRrFhG4kurbvmktN0F/LF1yeewnyv/177gpYmDxdXhqVEk1p5Q8ugjvON8xicQx89XDDiAPMmQa6K3I6k3TzRNIZJ9F9ej5XMKJRKo7KJ6HyMwZnLJAyGI+LfuI05BxKlFbXx7VQhLxBqHkhf2RbfM5ch6KzJ5jIMvdW6M5YyTNqcFKyuB1+XbX7eTnb4vRvTMDeTRyyqYG1zdEUQ8fvr5SI4qZA8WC6eJ95fLaYFciAYvII7Jxkn911UjOetQuP+PR3esL8hZrIJtvEOQMFwsaKzD76xZYKRkNAmVAyaapyHnq/EG8AlyOQFpB4FIGxiZN3/+wMbtgun/45Twobt67A6e2YatvSebB8yGL5MgayErGI/0TSqhcFy0GFj6v3d2y/sgf7hiQHYkOeLrktynvAQ+gqeBn2JnEMGXGmEMFCKeX2HkaSq3+vv5k7trJv7nf5u7rNYQYq3j6Qs5ckLajZpEkEm8EDGmucSv9M3nGQyOJdyQn7NqN5uNXI48quRV5FNEH+sPuyw3uCkpu2rQ8bo9z51jNYsYw4+9t+bxMIDipEHtm0BW81W7cHOVu3SylKzVcuJQwqRV+/E9v/eisngz75jQFlyR3dHON/uCPvNjnDzpn0YunjvAIXeDhC2Qd1PMGQDAbbcnvvJWFDbIbH/Jz1Q26jiWXHgvgjU9pV9gobeHrvMY7ogt4ubix2QW2blxBXHh0Nu/60Dcns8vcDGfVdnJduyOvQNy22ZeOaPRnoQBBRiHbf66U4PetIAD/rVEcDbwumvh73EOyIfjPxN5Ms/g3HCTn0spCka6F7jTRdKZ2a68Oc78zhO8R0tKw5xt8R404aHzti0gXnXTuLYPxo5oG+BzhsYxG7qHjx8JRw8XIar7Hf2eEt8oojFjd/F/uIuBwrP2G1YIlntjvrYu10hv3cndv9Qu6bIlXP8HUPgX5/iKuEy+dtHrbFOuEx+tmz/ij1aLb/jrPmCt1eb5k/eUVBoOwfgRgOdI9g5j4YzDoINfO34O+d7bu+xN9D/X9/sgt9rW6J83/VG+oU7sdLXu9sCd4y5m/5pkDYH85E3Rt4f+eszNx/ZaysPm5m8Y7KZyY/2uHIZ5hfn9c1RVttzlMuHzVHSuWTPHKWwF+XLGL5zK2tjrmJjVac9VyHrDv+BaB9FzXI7WCZe1lxhZ/wDzIBJidszduFGtm75YH4iDh6vdPEV1sJ9LuKONrZh8N3/nQxKEsmYe7w5J4nTOUkwbdHptOVKMVFeyo/YcK+jnyQNGqxsfbW19BCNi2YaQxWTlzL/gB2IY+xDGJCkDxRO9I1H5h7XOWm5ks1szBfag5bz+gYtj7/4dcf/M7XkdgxVTnUMVbYeogsPly/Zy6sLBkanrrNw62ri0os3mFOzN8x/AOe7BDbCLGYpJyLPA8TgDyMfHzxNGTZPaW6kd49UdoUGsXc4Y9mEekowziE/YI5hH98zczGnAKczrzgyYOqSrUpkvNkzd9F2meq9cgeTmGczcQ/flgyE8ObPd41lqkzMiQqHzx04mDEXslFB1slsRumazTTEXeZ/zIe6pzbv7ZnaFFfOWSn1Tm02wcYtkx/iAGZIzjQ8aBpJ3wL1oFdgte2TkX/cCw9i9gDTMqk/PWVSf2q8YM8QMG/8mbrY1mP3CCrDvnQPXI4IFiW5BJQYj0euR0sce5GdWnlF7O+25PLI7e+TcVM70Qj/kKUIf2VjPzE9txGEqDB3yBGfY/8SiBwzSxXriHbC1uewt+guBWJAHn/lo5jc/o1Fy9cvP7H06JXpR9TMglYGUGbh+LXLbGZhbi5llZ6My/nQUuYRDzsocGJqoVI+WTbLOe8+XI9xBYh/XNrQhELrAWI+BQF3BfsKVvLKqfyFtUtv9Y04HowZ8/TaVSvnPGw18XIyqWIuV5W1VXw5pTqVmCslcFWInGylqZDLt6BPeTqyBgjR48PF6oECgtByIRKC5FOaZQtEA5o8Cnula/xD0SrNebgXjsOD3BkEh5srh1n2zYM1/RLlYiV55/N+952nnnPN8r34wTPnnrs/xyg6IS+UU8zW12pzeAgZlzchLkFkLVi2WM4tMoyR27h4/uOPvb5y8mCVuWOorN7F4olLH3GKMaqH5i8/zluzCtN4sD2juVouyq0JTcwUgylqwoidmykwvOrTh/Vx+rD2Y/T80u0fFrfeUZMEAo37KfX27qVyOmsQ0hkd+Sw3rztaW7zyOZeR51k5ftsJ+kDtyXRtHqjuP1mpXLivXNp3QYU+7/eR5211Pe908Lz3cXp+tTa9kVfjuc356fW8yiBNZhqP34EYzZWGiRZ33MSNivk5b+LucE5/lP0htcINqAd/vyWsumNLjEP8yQfm8dd7ZmSrfssu2NlfDUTzPPpZ8MY+U3Ftms+dW+2CofyfWzci8Qah5JPvDkwntoZj8bsIhaSacW57M0TNiNkJEeWrQh5Kv8+QAd0n8/6h9twcYM8s7PnK4USgqlwADw/GYGQ8BmU7KRiPFSoXYTAustOgljBqOpEDyvrsE3tsvfXBNtNn+/CtYdvoqbuKVPxhujrWkWcuMuHWGtebX+4+YjX+1C7nfP7m6pGykkVdTPLCTymuAVUvZ262rndmhEfr5iyT74xezxwavU51R685hXmjSu64I6m5jORDU4pkcneIMockTs1lk2Irh/Ok7HxG9Znf6oxm0Y7QT1AYT9jVI613PqaRSNFto1Xvczyv47Fs/dvaVc88duyZV6+tXU3+e9UaK5fPubBUOrZRLG4cK5UuPKfMvHjoo9vsenRGUmH+vuNRNBIza+k4n1xfXFxLCkJybdFA9Ef2BxYy3DKCiWdlnn4QbHsWkohfxIJ3uy3dORHfaNNzZZgWcz6h9ECSKHiEOz/g95plBtF74Y/TZM4n5CUE/LJ6mAtLXS/kXVsJ2yTlIsW/BPAJpneYzkwNWGOykR0KIJ73CEiIIpAC+nwy9gFcSbew3Y01JmSvKdnXVUqDQNjzWSiYbd3Keum0EHDtg4ZN8UqEC+GtRUdWOJ6Pl4zGMxTDEl0emohWnSn1z805rX8S/lYm5NFXdFET2zz6+F9yPhXw6GdCBFMXz1dr4/s2QqKPtauHqIbYzHyVU0w+6lvRytyUyCiin0rFDdzlUU7OGZk4YtGzBxEs5E9/ibucK4Fg4Ub0G94crPBvrK03u02rOarz5GJWvXIYJAr7mR7huJBozV7vUC0k3ETd2CVMMMt2N54T3C+Bcck7W7xuVC2GyFDVN2phjklm5/iHj/MPlhhv1pvL/9qdq5efg+T7+ocjR7JSvl0xVST+01bjjVB6dNCZVeTKYgBPIuTvTGOmyjYXUrUmjIn1ilPWnVxMkH2Nam2hR1SWVVeJaecUBCKbJcpyEopj8Xj0b4lV15crUaG+35mppnnmTSyrF3QWE/qL64+8jEsunD9z3qlYRVSI98SElJF0UBpEAUyzQRunqo3PUKgSZfgqVm7pxDIFBGA1OZNOgCjF1t05r3QQFDeMlcyAIKUA9CCsrkFDjEjEJaG9+6NsHXALKenl5uB2tkXt+N3QjtcjQ3vjru3I9CS1A3Las2tH9kkdifD/1uZgx/5E+KGzZsaPd+TNHVRhYdq8MKkR/yE04h2Rd5L0breHkYqzdbYEVoicWqsjkGd6+gHNRgBzVk37+wCHeZKLqTEGsa2aH9xLtnixnsUqcl5PupZ4VUfBb6jzx8sWn561dYu59KxZ/bdjOLCigTY3/itn60FRL1medJ0/m/DnoSvnJKSntgr6uZzN2OfPqULcnnNsjj04iV+QhZevhH5xCjSar2hK2+zGM3qHRd0GzzCkRBhhcr8vuZ/QB4S+/CY6nlXF3jToHyY388dmNvNKLLtvcXE9LYrpdfb6TruZSd/XW5Y7McByhgkYEsYUmg6l4ajBJntNySGf+i6wpTKaMc8hlXR1YFqzGmZAa5thktXqAFIrI2Ei/X++h/yoydM/grC2p4nHPLcjjflSO43Jmu2kh7Eqbnf7LldxAJ04djBIk74F/iPNaLLWqh7En3jKfpTQmqS1nkp4khpTPZ23Nymim0i0kxSPJCnEMnOLdY6wR5m9LTdj8ZyjlYffLBNunNrCjHg8fY4mEeajB7/jr2jQQlz22H2cyGsF1CG8Iecr096Hv65VS0Dh68rUwrzxtF5YPb052R/hcK0ANfpsQjFlDz5Xm8PO1ObO78yWyPyoaPpNJrGQaB+jay5lLmkfoQfaR0hlbxrjitzqOlZMz2n6Ut/h+S16dJT20TlySaxKjk7/wZHZba7FfZ3H6NTdF4wR9LhW2/ISCJk8a/vGJR5y7RBL7dE1KW01MBkxePCrgzuYAGTW6XYZmaUGX0codbY1ffyYW1/mHd5rtTX1acDJgVKrnpfo7WwKlx2U0VVnpqzZpw7ua/5q6pwsKdIe7xAMLR+3aKNTVby+RifR9LwOKEczFq+V+7udl14H99SMo9PD+53vBRRKxjvACXadgPMhMrQM/gQtg5dBf/OEyJ09ZXCxowxerWE20FUFE0BkfkwV866OAmhx6kHNt0qFnzSGfSuemC6KsURQG6+YHmrjrH8hE+Nilz0iqI1PXYINDcYbR3uc+eeO+vlvMJUiZF0vIENkZ4Z5KnxeceKIljHMLlXa4sEDnk4DGH/hkbBUPniBAfnHvP7m7dTCmZd1VNMvgYxeVC+bdhXpCoURNvsMK5HzI5dHHhf5lZGPeGPQM/aDPoMw4OnRh7d952HI010lkOPYZSff+s5Td161dII+3nh2/eT8o69+1PWVE/srf9V8ciJ5cI23j9GHeNbgh+uCv6zv6fr6d8izKxQ6H14agDvy7Bpv264xQbpi/8D+AOSoBzGKDRl4nHC01exENv+0Z+HhFkwbdRnypJa6GcM36BZAsGxKuSDhz7RD0QzZYnN2hrsWtwUhpGPWQk7UWjhiC8lT8WVI3FoNVCPZTxLeTHDUVEs3HjwGmkWnapkFPVWNy5Iky5WEnLaKU07VBtSx7pjTDuZbGZlA/2Nb7/BdRxF5g5NEUORjFM5eJulxQxY4I+bKbvpjNI4Qnl203ogKMRWtRyeMB/tiycrNezOuWzVKPNSRY3E1Cf3tvH2iksurwFT8AjD8si3XDpIuLW4H6DWa1YS/lE4tWE4ZWxd8PEY2sag6tRyLYv6lg6JeSjSOYtgXsyC6TKSxycYIh/UqNPviQIyLUfGRcUinWxhj8SA8xV5DzBCglC6oUWVazzLP8Q0oY8ZEsv7DkJ+q4GqSQShmyB0vqIZsBw07rsgxERuM47chcYowFG7bdn2f0sq6GFIF80o6OW1e0ESGfD/Tee36Y1zY9BDRQ0eiGvP6E3deu7Z27Z0nwv9+bOX6VfyyuuNLObJl7Z+89IQLaKkoBOLh7EE9p2lpWeaADloUu4c5Ay/o49WT+ytPvIH8f2X/SeaPpPJ5myvnVjWpdN6+zfPK0ruw31nMyMDAsKkcGBgp2xFkIR3SXo4RqL4UcxQdXUDuD0bfxqzs2iUfCFnfs12ZpYfpb7kiItWT6B5Fx97M9qMa8how82jwkHl1ecRTJ18Qw+quuQ63bfz68I7GNlpx4dA06+MHd+NQuBaHWWTZWbkO9ntta77zzObkYeaRz/uF479y3Tpb6J0T/H/q3gNA1rMsG57nfeftvU/vZcvZfnY3p6ed5KSd9AIkIYUASSCgAkJAsBCaEFA6ApKAkoBIRwUVKSJFqSI1dD5/QeUD5EMwO+e/nuedPltmc3ZDhAPJzpndmZ37fu7nbtd1Nbec3phZO24dJnVsuVD1dVxSgioHumXTSMhxWJvujXgu6EwUZlbzqppfnRke+VDP/wo8P0Dddx16/68YBbgcIKubOHv7U5eW1kXBDB2i5pDLjwFeub4fvPJesvEhKPlzweJ1S+Q16+NbFoZO17GBs9BqbYlLyXFyjuFSphgu5WDncHgDh6OkyTQm7qewlbzv7JnZ04GtkB8NH7evDp2StXcKahdyoo6SELUPEWzlYU7z5PVjlBSNNYM5Qja3KdkyOOGjvnq8OYxZDTe3W+ubg4HpU+sEpkMHxpvFaJ559iamefZwZGKIWVDtCUhSb0J/+s+7CiKFAex//+YUK37Z7CBej/E6WMsDZIhRoH8hjtVgC8uUe48xmnY+98WwL34hZ0OSQRNdvA5Z6eUY8QwizhjaY7T3OkXTBrEiTjJwBhOVNM44wAWOYmbN3Eo4VVbDSsptBOXKRFVxlfCRwOzoCG2RUtR+rb0al4s5B3DVm1rGsFCoCfb0ZKl1jZnTdVTPPtoRz/f3WIpkmm7DKxQBgiG1nObbKt84kwSiCmICXNySo2T27ilBylkN6ia4yvOGl+L+TXI0q0YxykZGrxzwTCPZHkHgpg6s3BUz4fweuAuSD46Si4tr52CZBo23LLjFyb/BjSJJS7p2MBNd9IazfxnNpQ0MoDjMUULfssnrCIqZKDBh4ySWcnQIAsqMKu6P81PIMIzIezNe6PR8BoMMEadb5iW7knVqZpamCnSbiO5BHzjxVT7krYSL5tejUZ2/nnoAzwoOdkSQ241RftfpbmSn4XmEtGHRlGVveWAahZDG2iptak/E2Wq/M1AcWOwLzZG+FznCynTpiddl5mb3RKjbueoYZTl5AnKqJCegEtckTcjyXO1UXdJ9uopIK/ZQrxrs6a1nEi3Si/kAn2D6rEyfB1zhT1tYJHWnvcPDVTyWSWnpfuw4EdpdsLXTNssNPih6vgPKEokRKWYXPqw5agYrrtxttIKHtSsh5Z54+dlHZ07FnSs7urG3hO8TOpbmkrRohaVxrhdHG5mLKDlP8BHESc9HTX8vmNq2nWsMoHNh+bZoE9yAjpric05hc4NH3fG7bW7Ksij0x9b6Si/Rp0ecRZSO/XG0yQqtZMV4xghTcx+LU5JIay1BZ6CTksyG5qlPeNOvtVLIC3opCaqg/Y+5545FmmekjdbUI5cu259PWh+auvqCxWeSl1GgHhHpmS9QfnVqbydNOzSCjJTdhCKmW2jtgbHR6Ymt/SRYW5GybsMvFsJ0ltMc5hR0FwjQJtTMbmnSnT5T4L3ShGPUa7mQ08wSW1MjGf9UFRFaImWYV/Z9iZJX8CRXOk3PyHgU/zp3uPpCpXxo+YqzWt8mkuHoahqnfRbbXL1N2Zmw9cGMo5q2wCt2nXsruQfAchEqDPAAqhFgKoGe12PeVzevSrzk6ABus9CS9TJIcpJBHsIawJ5LHvOKj/AZeIUJNZRnJN6a+Buc8X7LPvBxxs67RHNdlyAz/Wa96iTnGrPb94rrel6Rsrw00by2VxA7v75bgKGgZ+u11MkNOMhdPV85Y9hX7urzlfeQ123sK0FVY76i+jrzlfqIr4jo1n4WSVYR3cH9iZuxI/+OxN+uu5Ow9Z2w2nMOZx3nYF3y2JHEitD+1+X1n1kP/N6dMZi39TkSvTI6PrNC+Ec8UhKvvCyqV9h6rFTad5zLjnFh6D3nWBx0DpqHS024hyZz0R5yFft3gBWGn9SqiOn2RXKs34ekrg9Noc9YWgQXhFXIVBt8Trjw3MPHgcFQC2BKqe+rO2uN3i1yY/8tkqW3yF1UCD12BnLOsDc8AQ1nTQX1NK+oEPJOsX+DZ5A/WveZL0gXF23mFSY0PjjZQGHFfKffdVLlSYEPS0Y2tFCJJyR4yT9ANqKIrPHMxJPAUPWBxL8kvp9ICBuIKS12xJT2rlBjdXDeA27F8kpvPJ9BKQyYT30nnIYMw8AXgMlhSHEQgdNKGV0mLL5wL1IOX/rISw+tK7j0gspUhesAwFu3UMe74nLmeI083O6zW3sUtFyyKZc84oG7FNF6SkxzZ118dM5rgDvGyEuNppULbU45yyxkvBVaUYHuNxW55PT0FGeUBLTLNDfEbnbOsohtT14/qTsqCKH5i4Xzzzi8H17p7yvXV8rm2r/3uV112Jne03M7wEyI2HW7K9Z95uOsjts5U/kN3A4MOERCZ1VkNxuPLXagebmb0dCEJOAiMnfJGihgLkWn8vUPoIAhfQXKuhXMFgWLye1OxUKu7pUlQwXL2tWbVCicHgASTWuU6hES7XSNonSKkHTK5a4fLVLesVFZ8kIrA8oCVpi8DD/98k0LE1rtfwL9ZyORhU7RLR2rDiP1KGbDW+m0t8RqmwS+DatoLjdHHqjEI2Cagxwmg0MqZJ4XuXNm0xDlFz6tdN55Z+dWJ6YXg7MuODc9d+xxdrXg5ZozNpVQR0lhYnhqGwbdKnsbgnP/1wejKV0jppTCQIt8UuLc6WbusosO0+HUfC171tF93L/JBXfp6ulLH0ZE2yndeMrKZRUzAPMLb7ZUAPRTQTqtEZI/Ne1VNbRCCnAD7TJSPJTp/5pTfGcCQpTJ74cL00Xsw6nVetgsBSAOFwLW2voSbnIF7ZKLE7/JNJWHGyZiBR7abequ0uZht8O72+1dreTBkzvtXUKeyQm9Zu/zd7LR+z6tdsbq4ulw4toZp6yeUdPeiAttPtVu9FozfjSR73R9J0DHtX7L9+ObtnwvAKuCV8Hys5YKvUhn3apEEdHqJ4lcYgUeTIvqNsyj77qjCyMrHak3etW09bGQX9E0i332wmLYk2WlcnBgKvmLyuFTFkOK75g755qFyasfdmEussKJfbX5G/8GL7oyb1fD/IHFWpLNQ62ind632GzN28hdDQYf4WYy0/GQNTjnzjNq5x09DOY72cmnGjcv7rtsNWs3J4qXNppnH9wD1Gnraxh6norVTiWo51PzzRxPCzLBb7SehKw05fsW+6zahalItUOY+30XswzardvHeqsj7udt7UVkcaWzEdCoVOOlgEY8RYIoGd0fBqJ2JRpu171gyNm+NYbTkIucZjnw7RkfB3ztK8TGhqVuGDmLMuGWnL237j9y55mt+4dmCEbj6OriGZNI+I+esnq0YbTu2sxNEMOUDO55k0Y5CSIhgaHbTOWNCSuQOcFMe5UyB/Rt6KVNgX2Kn+Bl3kNBTw/x759cOT88DACE7QBHnwcFwcWh3YvOx7wyODFAJvRWi1bnoNxo7fWnQr+vOr/tjb/WymC61K7O0ZO37HDfY958x9KyYVPc7p6nDE8BmrKvpb++vDR9bUXA6TOBTJ711z6Mjz/qfPzk/uFBQYMznLrDBgWF1LlaCTMK0gCTmhyFisoGBeX6uWZepY9eNbmvahvl/TMz+8sG/vkydrkBVGulHZPKAsqoGw3KuvUh29cwevPR6UEDXPbYgPkr8GEdPlzHHPQGJiG0eVPfYw93HDYurxEMd0y84AWbNvL/06nl3Y4Pf0zyPbMZiQP8V/80Mh9okT5pgrnB/v9/dfv/5MNb9e9bPyZqFPnMuXnNc/LF1pWDQ4PRqcDtm7f8qQG+AwOYMEATlUacCAwZYISeAQFhaTBudL5jKE54w7MwcvvZtz98aenht5999tPpP5/eevrwVJ6chjAgDIQKKZPxnXROI0Ht2L7qrdfg/2u1fcfuHRnff0qtHFlZOFIDZ8KpqytHKmrrrTP7yrpSOLCwcKCoKMUD5AqEASmd7X2KVoghmAAWIK+MsbGCFkegcmv/4rh0EQ46Qq7CE4mOcLMnvs2dwITxssSLEx9J/ARbVsModWS79CqhEIDuaD7s7e8AStAZvrcz5gquKsbghz8gVaA/rx76bExPUQf4h999djOe1y/TXg/PFk9WGA1xe8gP7AHfrrlYLBIrdIcAFAj4Z6VfUXylsx6wn+qsomiKf8ASNpAWV9p/29XtabehuvqoT51wKBRVjWy7GvlzGdeRPTkJx1bwUaqOI6JZpCGDZmSY9D88hiRZx8iYRhZy3ihYBBdPF5EAGlI2DSXA29nTJKYfKispw4EeD/tuZICWKWOOjr6bISI5/rpB9wtUHT8Gi1iPdKreWRAtvRkJPsARiizCow1RF6gM0u0qVEHN1muQqMl+ExNLmf4kiaY8WNQTOCwWJBlaAu8lkzVSGtUMVciVub2Z+XRmJkT67qRA00jx//gdgKIQZJXXJddTQyrRhMGoCJiWLTbLTkaXdUiCsmdiaioZ/+VPRXdHE96v20UT78NWBQmBAGKkWDcTbAn7DyqvcRcbGTvrADMBNVEL1NVonreWkhIaR45hdD49+tKi5BiepVDOAvqp3OQFKatoCVQXi1cCDeDhgiMhrZeQ3Ai0Ec+YrDQ1zUiuv8SBaD4xi4P91K20DYelDc0OEKa93bcumXVY35xO9+eb0uL2FOVj9cIf4hOk3qBFOZvVZDKryfJxTUZa0cmpFfYpxTO+22UdiSS2+OimCau2CHeNnsthSiB4TjAbCRfcfez/Ku7xsWhxP9elxb0JUuUnqUg43+NapUQoWM5prHTA7TDe+Kyq2TH5b7nrOzzvGoDj7Fm8oMtlp6Biibb1nG0rDz6zHx+SyacHuW5fYroeJW03rFqj7kxfPmXA/x2LEqMGRiP5Z+uyTTUgbMKj3JpP/FridVRVl8SaZDyLcJV1iUNiMef2jhQjrIu1mgX29EPJldihu8+J8smlELkaUjaKnKNEq6RvD6sbCCWK9erEdsTNOJtYFdgwVow78t7eRuc9RAF5yaEMxmB8ZfXcqSUVlFH4E5iziFNodpZ8txH5s9BqRs5KA5lokytMlweln6UBE3fst57/+NmgqKMvZqIvzgW8iBaRSPNCH6tHtiouHL3kvENWmjNbb8cRwrdAitlIGWZG0wNZhQAv4qOtaClI5mk+lXc1ePI0cOKUS002QAFJrexpUcRxP6yuZk+fnDm2lAX1P0o1ubAU7U1nF6NU3bECkcooU35dqsMsrt2Wcvy0ZtCoI0baqz3fDDW6Ewsoq4JOvJj2SgUz7nZ8RnMUujmlgEUbXmRqcpq+GdXHypTIDrgG/WU3uBsfTkmSpvJYFq0AClguZtAP4PhSUGkT5FIfOBP0RL9F6WVGCHLbUWqUIrexDYbcwfO3d+UgGT6BIxy4n+py4J7R5sBFaO9w4L6hdUWPA9eQBihw39HZ4Nl3KEb+uROTe7rIP7vvXDIJY3S2TGgzxOfy6Ztz3B4VHc8RwHI7EbPcQhuxS3J7tRkhfZ/g7huF9j134HQG9WotoOfTcjrn8+Xr4fBmT3wKaEMFZflvJ+4Gs8y6Mw16ZOI1RKo0ubeJ1f7mVHyAg00Q2bPx598tw6rrMx/D6Ki4lla3Cp8jmMvCOuTDr8ntgaK0DmnGtOQQz1VwshXwrWkMmP3K9YDZJMZzJ43ivsXfxRFNj+C6weEhPH9/xihI39uuYXlh1FKmZKoTqZvS+0PdSqp67mgxG1I6p2gUoo19ygYojymiu0153MN0B4pw03oReVOLI62AZtkMQ9buw4ziFZiGv2ddq+8uWH/bxu6B+dezO5fbcbz+H2zX1ESLAf3r4G7XTt8ZxD65ZXODv3DE4C2lB+lnzNUs4aHM1dfB+q86SeZqst2UZ/vM1OtX5hsxU6NfupnVnrMJ9/SGNb67lUzghtzTz93cWn+2NcH0aOk/feKr3C+xmNTAtt/zE2+iVH/IqEJaP3KNTvnX7lLFTE1L8TY4X2l2tsdjIzYO8e1cJ8bD+/HRXoqppxlADPTA2Cba2/0uVlOy/3bqZBgxrj69xRV40TTfoLTEbMYT9yKXvG5J0qZ1okIhdAq62qaS4gPyWuh0iMJSePiMozlkEkFqwXZ9uRRWZvbsAdwEVaCp63dLsmQJIa5f5ErsQ0oqmpLPhZTOD4lVkjyLOGDTRS1GJVpBfZJvfQttANgLPc4gj7QqBC8f0h4dGC0X5DNaiC1wyfwGhGSBGZg5Xjq9JGdzIWZqQTgVrV678glWHnIiJDpQJrMJHgpc2bJsxwMR0H9WVvYdv2khjGBQDmWyVVpcWF6ejybsPFpnDOefTAr3f496oUmrXeh/QOJY4C8saZlMCHEQ3jQRhyAsK5KKkwEEUalOz3reKct1bjLyHVexIISK20dQfK+Y9kIMxVDnILFSk7rst87TQ5tFCyRyDqHtUnJc1jA6gh6PArph0fL4xuppB/bINQN8A6jNIL8QZuP54Of5ZVb7XIur/2UnwwJLNiGB3ama6HlbkXRlI5+SdAGisxnH6/9sNzxsWDAVxyTbcgv+ZgyuF3RDRHNqYqwQ0SZpldokrcfRf33K+CSt27bH2CSsPxohYX3xdj9sIj5wktU9g7H2kWPE2mEeVXooPg5/px/sY6HM/vqNP9bOBUmLRqHJ9sQ6h6Cf/5JfrjbaDzJsDz5THA8wM3s71is44pdsRRQso3xmXszVmrW8lJxanOKdqutOeEbEIljWcmquV3MJovxd6OSnec5PScg6PujWCgG+yFXtO7hsfbqeO33HTshFimdi9OBijG3ylo/lXB7I5DSABtheEHgHWAXB9mXVBfJXJaqu0V4TGNAn8KKy74YpDf+C78MFctqgcc8b85R8CqSZMSnu09H+ffPJk+LuWBq0Aentu06O9LZ1/05lRSsjtLaLPVrbSzaitc2M0NoWdy4zuo5TwFwLdsRUj7mWO9E68U3+fD4B4APd0V9s30cdfloxh8AV0TZ7QWhP6sXeDnf7jxmvdced/OX+fmofeI8yTk4zvF4jxr+wshgctfjuaRTH2BGIJwXdtQpA9Jy2/BUT8oAsU54nL5ksGCm0sCUs8mYcczJFf5WwWCuleNmiXD+G7GhuLgVG37QiKpAFU7xiqRJoGR991ZBaDyaQkyIGerIQ93oA2zFl0eZO3+sKDV13kdagDWhyrwgb6L7LlhMaU+1ONzo+1qIFZTSaK4CbyLSLhiMmuS/KAnB1OT3H2lNcUGr4c/tDCS+XnZibKotm2RZtxaQTALpEU6FqjkjFo+npPWndBSQYUDvNxrtF70tGiUV7WZ7sB0hgxTD5C06sVQLD5vjWz7nAaZgKTbP3X1g9t4qnoymPnMZ0DIwpALO8UDZFE0pZAso03cuv5n8TWDzo7WDmeC72mR4Gaay/hqnnRZ9+pH2YSpZhdjLVTqucFqaNruYVWEPbZ5d+vZ9fjdvinbZ6lSGLc1ybT6rd7D1IOl3EahdcvFrvkafSJy048UustLuLEq1+2T4Iy63ZRt3pyFIzCk62pAteA/MSzfHCCd0Df23OzEqmaOTcyRrmDhC+AO7SV5XmRCV5ql4qZtiMALTB+UqB/8HEKpJYOgcJZQxJSGKqycDJXY4hFCSZRqdT3AYnc1dhfwgLbqgnXJHypOJLIW06FVnEeg3NIJNhKhTAfw0K0/k899xUATQFEY6ghjGFtydSQhqozaKt5bUszcfzRgHr9wCJIo1W681S8hL4LjA+uomwrfqo5FysWVCmqNtq0T4+yoQ8BiYj3eWkYqqMnOjblAFVR6YL7LjrGOTcZE1XgcaUlZjd9KgC8Cn95ZJAleZVXyBwCh0ojYsw3bsUAf7eQafYCXfgN5WbjDuYXtArbuAG8Yyv4wVBvwdUyXkAjC1ld872b59c3Eh78uyuMFsZppZU24n5cRF8i06+bXUmHAsALRfbPFvJc9V92S2tPT3XSF69gbXXLq1Gf9S34ZEs1Utt/Um2/0G+/buwswFXpES35DmMwbZr5KdxPQOLuMKNEx/jwbaDQ/9M8F5/JvHVXTv443S7ePyzzXXSo0EetrLUWQHnF6pD7pOL00bqP1FfO+v83YkLD9+wI2YXirSJD79QC3W34wp9x7/1MkQOuhkkuq7xiqkDHQ4zpuvXjS8/j9tdOxkr1v5+4z4Z+a2LM01Jr8pkGqEh4AUfPqNU1IsHgkLr9jii0IFyJnpVEHUjjpArMSXUQ/0clxGaoTfAwY6C2PRDI3OJXgd7k8EE/YtBcFC/Z03vhL+SsRyP+yj2zOgwowtZpjvSClqfARoM5N2tM7BYSpvbMqYZYn9vmwr6AZmZ0Vv1fxr0oh24s/5kK2+rw9lqJp195CJnEjCCApX4m4773X7f8OM4U/ib4z7b7zJ+Jtqm853dc77Wv4/jUygMI2ztXYbso554FtrlXx63bertSrAStp97jNF2vXYMQcD/2J1Qdda2kpO1j48vF7hRy5a7a+eC1jsvGcxcTtsyc2m9aPMub+xvl8PfllG3fjTxg40hJCsdCMmoXCB5qDjfOCqD3MOG5AT7gSSvgFzroJwgtup2xRPP3pYntrgBFcL5lfkBFcJzLj22kOkTGzw/v8CZaZGudRuAlmFL0w2Z2mBan314W22Qe8MOOuY5g455ytaO+ccbqhNSn/wmKHkFLB0+HqPi9yUSq0PNxYdKtOOHe5bXDrcm/3t3vOeibXnPC4ebnU8b6mlyp+YqhW36wrUb+cJNg75w2da+8Mah9iiXcE98i/tvkAiu0sFhvUMDuOxUnZ6hadNjkAeQ7Xawr6Q6HTBTpiIkMZTN+kC8W9AeXoEFUkQAixVH1nOgPuDSgA8xN+J+DkZAx+gwAgImjY0ZbOCpnhMxSkCJMQLqWCF7h13K+nwBn5+d4tG04t5XmcY2mWAUVDcqUPgqT6nQQGiEnUW7AlS6anpeRbNzhpqmi4sitKEj2ynYSUnwJFGVRAefnyBFKV84P3uKxcgBCddqRQumAyjTfMQdAQeaWS5EScyeQC8YPu+fzHo13eEHhHfI1XyQEkHwDshLToiXuRrLhzEJAiMhuIzQ5nXkzN6iWdbMlAmEgtUwZVcGIsqfhEAmcNXOhOkUTDxgNZslEfYyTtzH/QjLHWfT3mc82u/0o1bBz7hCGRsbq7G1DgCJETg50lHrijtYWPagJFMHoTIBO/KL7UkjsKk5wkjYoo2Pe6PpV4Le2ixrj/YbzImVYBqr8TpXxN0KwJdTRI+Lw8aUac847MyQpKpYDqiyrWRSVqQMdgvp/UA/oE9N7kdL06ylDi9R15VztG8q40hPwJi6E0RThleGOhAUYUD2BY0v0cy50w1VwZFCV9Wnp0opFjPCoQYAgQb2iosCTJ4kx+jPN8OS12bIxoqopZtGZgmUYsVitk2QvXYPcVIpTPFss9AjyI7UYrmgCTp5pZnPZnMYuXFONe/zTwRIVS6qesZWXCl7agl2tNKmvyewixYdV9LM01MCoKV5ESo2llOwqCknmyVgkLHVVS+lUpRAFFWLd+LroI5UURY/G2Jvu1USj6UyT4VoG3s7ivI9CXnaanWqg+rz5JLdCbtL3V5HS1tXhP79+Vm4DKR/krlyDp812hESut8lWll0OuNMaZh7bqFR2mbEffRGtewnt5SjJ7+HhQgVPX2LdbRvQYMMfVXo7gi+Xk22bmG6O+iS6/iLu5jdPwcaCw3bqq9KfGJHZOZ3oVbtm/UfIt2H4SpYuFymXtS+vVngR6OV+4fuDt6+UR36t7TO31iH/v2dJby5v97xshUkMWibmZ5lmHY0r+frEBgOsdhuNjzsAAiA5ORlkPeDaXN78vT/tHPF6+vbnTS5Yl5FfTqL6o6+2DWc7XmiYtDb3bLVhrZy8DEMM/Ut7kvcWqIGHucfEpXmbw12F7RxjEG3eKjWK2IHucB3uIFjhG/79hVpJTINP6KzlWDgFmB6H+1bvc932mu+zT4gRWeesjI0cTlCqEfFzisw34FPxx251fgPG6d2cBoMcSH2dkzY26ZbivFMh3bzlld4sRLv/wb+kr/EzgHDw8AlaW//SnAERpmFHHmRP+sadFddFrJW1MrINshqAV8lU5RnEBgChyz7eSOTo7eCnEHMpvOL07D0j80tASgHpAHY6tdhRo+ucCN/Apegplqi4tLZiIGZl9wUKFUqvlGdqGHMFoEsFXW3KtJFD0tRPA0XgX9ENGluJuvkT+EByMTL+AkuRRdgg8SRLAXXGV6LgQ4p+aGqO7ZjIrXkuGUzDeI6RLx/lJGbI+hgTMSRaaTyIXQfRUESX6kX9YyiEV2dsIFWC+dDW2PQBQlbxujFPFYyrYKuy+gHZPM4ahZyIDulYD7jYPJEd/yxkoJfgteBZggDQYFoJn53qDLKFPuh4PfVoSEq8yLmO6YEMJxhapj74ndU499RwW/j30Rf8qhAcRi34IMTcPgkQcJr4VfUBVP5F3DW8jZ9NQVYDmxEa0CRiE9G1ARnsylorcvBCKBSYIrImIMsDJUFig/0Tnye+y/ckKuJP0j8XeL/jNTPBwnoM39FFXS0/pUZjyedoStzrNr5NzapnV9OzOHa+Qu7cg3/cfeSxTSzd8kCFYmKV8Il67Qv2da9A1Xz3OpcX9XMLRy77Nj8dF/VfJGVTwGd0qmba6iba266Uzdf36mb37lzdfMf01u5FN/KhFzevZU5TFBwLf91/7V8Y+sZm5TM3olvIAFXWcn8usQ7H6ySeXMPG8rKRqrlS4er5RO74i9v2MRf4qys4zDccKH81OFC+bSdM/69A8Z/5LDx7+03/uNarxmqkXnUyP/OOzwP3o1LaG5eH9TKZfPjNjPUwd6N11HWjdYXyW3DtkSym+Xz9bGkrsskdc/vsgJm1f1t5V0EXya9exc4SZyukq7VZd/g1/5oN+vq6/tFd++PGQEruA8+2dXnBZC8LdD71xtI7YJD7vfP/mVmnju4C/V2MpEHLDeLDtlZILT9I9w7Me32ujbor4a757nBkp+hnDwg65MBDMyi+fW0XFfWFW1d3UpxlTzdreNgqpYLlJATmKifReBRmo5bcFQBSFW03j1ZLlWyyaKWSfmwZTKj/aQ2ZSI9h1yULyMpb5DvxxWZPnlwoxn1Lajb3jgq3wpk9qhK6+zG0qrkM94qO/AmGGNsiEqKGcHeY1gWOHPaB35iuhpnzunM8Hk/3tLiGu1VdGqNtN0K6KywmGtPrclNA9Ksb8ZqmprXYv3VRw/oryYHVVOfNaSaOnnw7INTLA3/OK9jgfsczLTflvj89p2E8rus4yXbVHPmwmh1Y6eJr43tOM2vj+00S8xpaJQ3bFsc8ZvKNvWdzXQm7z5+0I2mum7E29gj7HekUzZxpA+M5UiPaN8cEkNq9PvSDa2XblPlWTPAkvjFAQ97VtfD6FG5fTMXu3XIxfacdt5pM+j7mSe+yf0Ecu7n0T4tGW3aFXsuN8vNEbTphpxt3f6csHGf8CCt2FjddbCzMsfDZeZixoyBx8gbB5t2T+g068A34YhPJU8NC97WDTrEf0UxPC6d6+sKouH+sCiN0iFW25NzhbxMrvQKYJZiDwDaXDS4b/back0oVdC23EuzK6wdp1qOdCchLwuD0Rac1deCu7K/Cfj2bhMw6yhTC3OmqdE9fzVW12N9SmtfGd1JgAjoozZ9lP6nvIx0oQwikxoyxHMSL2Wa3CwfHLy65/q4BFbij3GrvaUd0OVm+chgpljtMBqz+BC/A67zda/1R65DaHeb/Xni8qqRdd2FFEsQLU9pTm6dH/7lTslyU1oxAM2hBWH5li5KFANRLWdEtFV5N0hGaXQL6+WsyDOIrBsgbUgrNJ9JSkrRLXHPzZRz3BP96U5SWbD3HgEnlxnILKGMfHVmvpm8bKM24LM3Bgqs9oAC526tyv0F7N/aXOu9GIa6ogLOArwWOk1JTUXXSbdZC3GG1sOABSOPslkCq9QpFQPdq2WK3BlI2/wrOHOeG1OdMqYW2DvyxU7SyLe5AflYsCnmCG/EzHCH0dGrisxH8ADNQJfI1rrebY4ClB7AXKM3Ga5wN7mNku/la055P11ehJBE/nhJCW0U//lyRc/PNus+8bPQckgXy5ZVymdVg/fz5uQlFVN4Rdp38vRDzmJAYFbq5IObaoBf9yhc5OjhVEshSU1OTkZuhftXQYesVkanHxmXhb9BuKJ0WkkFsS2qZWLIQa1S9YgFsiPRA7xHNXGz+eVsSiudUTZdZw/WnpEmRK4BA//5xkLhNysqTRmTWtp9Ms17GH/bpwHBExKvTXyR2IyOJL5oj5D+JhgDVKJ91dX7WF3pNHBpxrefLZa3wzrF4eJ/YjWuI5cG+Ev6NUfCPmqIAaGS/sqgR10CblpmVrHHTSJ0aKnZlcCGSL3CErUH/rCX5ymWzAcPiljtl0RhgiWYJOEXK8dXR4xXoz+MdRjhR5f4TPJUUZyjAJ5LFpjGgOJRngtAtKDjpEvQHaFYeV9x1UjW0RCWyR2arwSWk5SoHljKmAC9SRmYArSnOLCBiJRjQwFjh6Si64TLxZPRxwILLKXxkLRSrZqzAIcPNcpRgmLDBjZfRhsLNQMlGUkbaqDgglZc7qUWVTpBeQ+4PxpSa9+ZNzw1pSl0vykVvi5l5gBfkFENcT8Cg4iHBSzLTNEfCQ4VsU0OooitGapIIqGrhQAhuugpSyg/7m9kA/I+xRdovaloZQHxE0kTGmYKX6aBCcU3Gn66pcVEK4YaRgbdFuH5Ukw6QsdUoOegUDSFkq3ge3F9ygBW4GuQZsuKDqYV3E14BjIuPMRjbR/L30n6s9krCZTO8HwpRT8rNN1ilhcZS4COxWMfmwcdj8Q4TNDCA9IfnzNMxbfQaZOOeBzeD5WupT9GFZv4NEPG+kFJvEReNGuUtZMDwUHMgsb9GCDkeuL3QKX7z9uAofZwN23v6VHzNLslVOcQ0TZ2fHvFp2eFtn2pg9Kwh2agFAwfko3VmPe2t+6YDPM4C1VnjbFQxWW8mo31AEsvHc1nZ7GsqRmoPs2snNmT8Wmswm2V9MyjDlh7Zvxb7MgCx6EmoaEr17zIBt/9w+2pJkYl+ZlF0PvYuBrAl6OJqqd69XM2UX/eW8iCYDQW0E6Ps1C1OWUVd1xOGRJSOE6yoCUGmR0RFKWQYQAxuy4HHLF91cDhqCiYiYRSkbJ1iqj6NZtKl0h+kMpobFDC0x1l6kOK/85YXzrs6kv7HX3p/QUszuDLmkNan9+cLIv62heYry0jxfq7xH0PaJfKe6g4Hj/Cy9vrEHOnKYcv24iM9/dH+sCFh4DrPaq3LjV/1iVH5+LOsGtM9TWAz8vP9dam0sieMr3275Wd9u81vyr3u7uv49vuBLd5Hr/HvO4aBiR8V4ep9aEQu7bUPrr1IeAZa/dsrfzG7f1VWf3LWyvY+xhB/ZjPQYXvJVAW+Bzt/a+2k2eaGh8grJxmOxZLHcNKlAqujdR9yEScvTRWThEaZdoOcvWciB4HmmWuj2bKtzh0Xex8gNkj91qrVs0IST0qWp4/d8lthw/fdsk8Zz0E/Oni0uKpxdKh+UJh/lCpeOpi6YzZLDIf23GKHAG1sIPVPSuFNR9wFntAzAnEqKbqe4DVS+3hDm/Lz8hGfkb6/Ozd1M9cNdX1M6payPzszLafzcLPXmwgM9MNTReouBfT8f0WW8K8DOKDX4qbOzu9wLHSIdZqw+AYNxad1lOEIwgOQ7q1Ec/vByYV8QJmh0mCUm1RTsUl0hYVZlldrPGcjwceI/rD5KU7vsbxdzQX1kAaTxnnaBPInrU7kzq0kCwXi2UmYxXMQBvSEGNxYc6niezazVyxWYvliJO2pulhhYJn7+gTL35yT7y4yf2sv+4/qYlU60MshUHZqluSKbW30OL3nZ7J7F3EGloh1+5AAY/rRGk0UC2z2FtDexwG6BR991PG6zo1U+d1R0hGbrK2ZwJs0VKUyfQkkHMYp9P+ANW25H4OXdYX7+x9RdGTUt+aCGn3sZnoQHwTTRPqv4X+H7+CehE/F9ka94QtIwhKmm1FEFPvBJCWHU0aICaPGaDLdh28I3OLdhM8gQ2cOs6KKczp55/OzUzNkE+rWQu6ph4vu6YJPmIDdT+I5A3BCk0VgHs31HGclaYK9G1avph2cURLK+iuC5PKYSqXN5glL5axQYG6FN7Zej/RfKdJ2eFh9XTIiM5J7nCKMpuTNrW5O40RGjMT1SKhqQV0jFY7kNQDFL42jiifL9F1mpgBGUecX09Fd1fz3Wf3cKmfh59vrd7HvZoWkRuJ8L5nN2+XqzuauyiHj22q7nculBapcC/WWHwaKTvava5nMxrFL+98rsLaSf/Z9oWX0JX8Xc0avB1XO+Wes5u2W9lxrdTdSDhb3xlfYPVvN6NR70QGBPDbEu9/MNVUO+OkStw4HnK4uLW5uauJTfYSD5bqKvlbN49Zj68Uq1WsYM9MubZlpOXMVMabDF2QugX+mZUzmzdb8Le0hp0ycGPW3Ai8T+RSe7JREMTcnkWrMJ3DVMCrTey0QGsaf2FUTcrFqXgg/sQJ0XloEmP9j1iul1fLThm/IkFmo6QQDmmt7HpRpNJteY4KxngsNHyXhYbzE29JfHpnFVx3M8o8iPqvu9t9a12w3bba4qYXzPyD03VrVcZoqDHHog21DyW+8dBrqHkszTFZHNvKyTfrp1390OmnrVAvppNC3GSb+/vTH8IttdZ/cFzN8rCqFRQqGzv7/ev21GhE+zpzvP3Ya/izeJlydayUFysLD0ZbhbZKYvpDtErICuuVXDh57IZ9Y0SolavPaHQ7Xau76Urp4TbatfWFPKCAm6e3x4iWXZxot7vwOjvvGyUbwiNYtbFN0MGgCwODxyJmAbodz2NAp13oduyWSvMHdrqVQf5wx5Wa+aC/YxFsG4xyrNexWGvsuEYzbpqlE/8IhVY3cS6a6O9P/MeoB4xYvrGJ4aU+u++WtmtPvpOKu0p9iopV6iB92ov0Dw1d/UrP5GODXrMHc2urbvY5TK24gb9ImUJBPwdyW07bX+48STXYwz15RnMDeUZH0P2b/SkmtVj3k+kc7aqkOwqwmWlwdyAqqG1f9Cx8o+qJYJGLHQ4DcGS57mSoBNTTMvjV1AykNsxIZ46WhVyrCiZvGiuSwI9kdRMiL3tPUjL20z25xnBYg/FjPbVGaDR+mtwElSPwsaUVKU6IOuKMRj1sJ0gc1m9sF+GP74Yr2px9SuKu3QlXJ6nJuHvhiXvxtlUZ86XAczrRqHkmT3YsGt3/yy3UGP90QzXGTgB6WTsAxe2VCxK/kXh54pObBKAHEIPGEZDv2XtdOVexPhJh2quZXSHxcWLMiOHHDzPcU8ZRm78Y/fQGIoaiJIdiSevEUAARDKMt6bpeALGGAojsqfCP7caQyzfro7xZlFgEYBOlUZ3Wz2fmXjoYFhpW6EKqiIkFz2fXCww+eOpkzAKPAAX0ke11ZrhwPxlptuxaBiuMI33HvWtbXRqrsnDmjXc8vNd8+cRuZrdrv9xaOm9xy4ZNrxcztfOjv3s31NpjnA1f5H4G9adHxjuau0m4MKZYFLl7l2gWuN/eXDmK+3JvVbsOQYOTYVCQ+9a3164dlZB65LCE1E8UlyHuv8B9D2guyrTwp7vFtODtiLzULrEr/PCBaFGNcAzvKKHoo5lW1TMGtKpyqTG0qnoEw8y038EKaGzae361JBpbKxftFnXGoS51xtrP16XOII9+sMy69tnepXznEF9GocLgWPhUBzSOwGATrGPXL0C0l2ckGe9/qJJkbHGWufd1OTHmRjkx3tM6fWNOjI927tn6l3Y8xb9rM1+Y2h4Pxqd2jgfjeVucdYrD/g73r/CJicTvQjLl4yPDEOBXHkT+xq2sP84E5PG9CQiSjEAibx/VydGMwld3J2wc38wR1n7QmXvUB+cere7cwxvgZ+QpjcooRePdlI94e16xEStx64ebq0OsvWsrQkbvxNe4H8CDKKHEuxNfeUgRSmzpT2ORSNy8PRKJ+3aJQm9TpYLalswRle0zR9yzg6nJic2FKtb+ZkOyiJjV639YQvJCJmawO7nmNmHCJFr91eSdf7JNGHB+f/W/H7QMdHGbMN9QLtzQJ/Qz6Uw/dr1L6htgdeMZWciLwdH0IJGFbBU9RvhBrhnmB/nZ7oSCqzYz5+1bc4IU6tulcrtpI3t/d/BYP2b4WH98hAbEO/ER7v/BmFck3gre+kR9MaRnq93woctTe9s6IrEAJsTSVjrHkj4JtsnTVg12cWN+8Tb1Fv3bKWCR6XMXl3Y/M12nFOHeF9ShDpkr6a1Lg2YK5OICFX1JatmZENnox/Y+dlmv1YoSGvC5vbnWqyicjU86kp3GGc2TFBp0GvDqjpZZDlp3oLuGkSPmV/KLdzxdvXczB0r50All675VN3Mo4815DuR1WMKqGU6VY9/AyxV2eWBXe0KTBCpYzcbo3H07l72+divdVhYa/hmifzykjF4D8ZN/3gEho19NIrKB7NGLT1L26Lu/ggDUWh6RSJrsSSRdupFEUnZYIol7xw7eSz/bvBJaexPTUPJssMB1NZT4hIa1igt5gpbj2xIfpnKS2F8N4R4+G4Py7dDT7k11W4voBuPLWPqsrU7QbjtTu8d9aNZoFGIF72ixhyvobhJK6IEATxDzDMw3R/EEAYMTIINuIwoAOhYox+Bq+3WqeLMQ7CGfwC8jooU4Q0TaLwTgHrQftm+KHvRNTjF8CFb7aFWJGiXPcFybNyAwCdAwci9DvgiuSZbcgthuTZLbZ2toDWfup1BW7ImHqGXQ18XyhnwJxQKoiu7HhLRY+85qoUXVC7gYOEAUoUXJHrwmJRi4Hg/dOPnwjOG5vq5lc1nlNl43TV7LmJZFQohlN8ryDU5DxnAqowh6NhMIQqGaTzplPCSHulsy36I1NbvovhGb0k4+FVBDF5vguXhZGyIA9Visa7hQfSR6tVY1YnRAVsHUNjMMD0C2UneBVgYo+RQKEODIsWApv3Ju/BJvq10Q0XeKiBOc+AwED+TElYk7sFf89/AKzBF8NKGDPsXHuZgDZJaw+BCHje6XfXQ1hA2eVsIDfMzT3eaQbHjblVvqqOwMqGCMEoDX6Qq76BfxRijWnPyrYxgk3BvptihUrajozJ9nZy3bh+wmsNCw6sPs0LKhTSFHp+QzVJoTlISikFElv3lkEQh+X7vHiRyDEshAkt2VNemPtqG6BDyR1qYD70lgDFPJH4FuJ1AnhVChoOsn0xhXyKupA2lz1geroVLy5q+CumkIsiuguU35ekd1MwW9dmb1No5GgyxoIGJWZEQtRfQCl6cxofU4qr4EEb1B9aUIwj8D6ktPYPTgINyi5OC/3hPDoNTgYEEepAZ/N8kdyFYKyuMJ9KQr4DOiEiqXomz528T3Ez9L3B97C6rek/EVMugrJGYWGJAXXx2Sn26MqE8362GOiIzFoFGl280M5kC1ZxuMAgnvbqkj40d5C8YSWum6F33n8C8P4TJaWiY/BkoEn3+41Ha0kDqaNehoVsfRVvMZNZvud7QFmOD9Q27W+sa9GE2rNYi6PAMUZFTTpS3qEjz1RUNSLvLzF6mKS9kgb0KEcKLJMO2bXtpyaQMG8Qv+FQbgGiBXKSZmXqqKmeyWSkAH4ZYex+c1m05q/lNQj3Evwq+4x4/2R+YeOLYoF93ZyxwbunCUhg1opWscxcnk9Oqp1Ss4OnLN0JciMQ2Apgie7zDPXPv7eWI4dTaGK0TOXlNnOucYICcVP9WTwb4YMtiYzT9DO+XUfVpQYdK+xE7ljaBULIeZPZjs4/Pw6+U5p4jgrsgp3ST8I9q6Lsub6Lq8jWTrmbLpJy8na/9S0xSyD5JTAbamr4U7L0Nd+f2JbyV+9IDWW/kd9/9oWxFwrJaPNxgmucdtS4LjD5zY2x9oWNUi/QND3v6z8cOlvonyBrdAlTcm+wPqtmU4XkxINBuME34fPhB+qZP3hd83PKI/rp47GFe3Ib9BxZGaNOQ+jLCE7T4+QMJ2I3Q4/oqBfnAvn0TKxi+vn7IJgDE5+Klhd2kNCRdlfA47DN9YSqEo5g6qsyv8ILaTtPgnd5K0P6C/lSApySYRkknaqRYDFa1FTQRzMb+A7EuSoFMHZAQ2K3jLQp7kOEA/UmYvTTqLkpuQSSsroLRM01nH0YkiMHkBuYoJbCtRKkCifgqyWix9ZICsIIpjqwglSHaIGvgBlrsEsvYxIit2hadkcJfDYE8MZqYbZi9Be/wWCRqo64YStHtF27UF5E9vRl1spUOPAi+zVT9MFrFV1MKSqxAt+oaWdCiN5P/8OKmI4V4TyOPFkDvXoJoQUMDTJhf2hr/zD2a9kgZeRJ+cmf0cMrPlczo/+52N8zPt3MzF/n0B9G6XgGTyo4lvs9sWF6CPRHow3MT/2os3va9pLSexf11aZXlZ2H/V+v1l3CFCr9xBqsB2+Ak7mqp52pBoF3srMUcgT+/g/pl2Yy8tLqf4am+k7aEHibeE957jWQxjNEUsHpI/lyQIZRNynoomX9rwKmZtUvV0q2Tr2BvCqoAjNlVXV7FGDa5uDTs7ns3PhQWeK1XvxGBf4l6fS+mU+AuMYyCNJo+iyb+mww6smsNaEM+UESVVMU1Vp2sfVBsRquxJGnCErMnqPbuYoVfR4wakFllAak6UJy98zm29EfgtuFxFE5zXsH/SBZOO5kkK9+uEOHOO+2SrGbimqFb9hRUzA9FVXam4dA3Cl08BiFQzdW0x0hxVK+Sj5GM5rpQJirTSRXmH5A3bI1zrXxjdH5i2dXNiz5SF9/dUxgDfJg4kjxkUU0zK9Fxcq6NqtCwfRaheSbbm09FzomAwEeQou5DBxubkzjbKWAlTkUwDeTJFSbyz8o2IOwHiTgJ6Io8E8OOeXSsUPWT9bBC7srU2yUGuWV+vHPzCbpSDZzlFXxbEargfayubyJK0nj1Q/z1sl+q/1o/0oOj5qakbprdQJVGCqWMHVtYv9IonPoe9JBWF3u+CoPrvdqnQG2/DZRtaIsMl3o9PqsRDLiKPlHhvGnPzhXyhy2RN9VQ3kRdpvWOHiryhLKN1G9uIeVL/Rky7wuttxNw/oDVy3ZDWyEv7ea1/95W9Ao+2Ar4PVuOO2syHd8hDhCEP2XG1mR1vAqAhOeIj/2+r/ZkvP0DfeNZONQDWvra1DM2dA65xxZBrPK/fNV7Z5xoCgsc3eY/x29+Y+EMsyL1ndGh1cs4iriwNlUHb8ICBydXiYfpW+jziN4fHWOT2B+ohyb//2pBfPG1cs49w27fe1fWDpPT0mYM1SysfWlo8VNG0yiHu1I5bLKbN1W24hTDgE68asPcFQ/Z+Xb+9f7/1AqqoxmsBZlvQTlMCbDF0PYDOub4JF0omjiEh+BuEhm1xBJN1OILpY9LuJBbrNY5x0NZnEj7QxyRsTzjkUI9HWNsTvm038ovW/QN5w/M2ZBnes7w4yDIMpxrhGEYsKO/J7lLu8fX1kglKMJsHwez3wT/wDPgC8vqAzp4o3TTrwM21R0XRCpg+USdsQR27GHW4Sbl42kVL1UNcH4nWUp2JczerdDrQtu4y91I9A1IW4yhIOnVtxrvGKbs4wWT+YfNuxd6UK3b+qgXi12Vn2pUzhaKpAzkln6mhyTUFzlmw7FfSUlkh367tnb/vOSDUrE55HncbKdm5fDl4ooJfBeNy/+ZgOsB28Z00WeA24oYl5OWpVTPYG6ihwZn47NPadVYmnXcnkVkmwwiUw4RLVRopnky4uVTKOu2U9FKNQQk+yf0YFA+PAeEHZffG1cYIvbnOB2yRDnfXVixfq/Ojn2+P4bfv8+Vjrphc33HuUcV0m/Qo5/BGcOK4X6PdtvA01GkyNcDVMADd5ybcKU+a3oCta2piCmKIfkPGc3uf/aEg3AOaZwAMyimxJJNPVxdm93R5YLIa6aOBab2r13j/IviaapMlgXsBcaqps0Xfc5MCZ51rFSAqAKzklIO3I1Get6jLvxWYuZh/6wxR5Vx4dsGSbIWA99V15dWolEEqlYS8RhqGCYvVsHV2JjpdyJXzYpDm5akwGYQe66nLplqnpdTfhHlvbqI4y4xGKShJ4rrEGxL3rmc0aQuDwVw9pt4trOWdDLoktiFi5IgRUaQScsotGxhw4bJFRMtx7BecFHjktbBsdcqBDtbL2qYFGEjgzPN0cLeBsZqZ1R0wayY26wSKttis0Kfi2mYNy22z5jNts669gtOtWI6cZKMz0ZhDU7rKpMhDYIAoOKRQwRKrQh99PEw827Qmwg7hI3cicRPWd34HYLH1rNwx9P4tGPiYcN4Ypq63T9zWlI7rHEm28Jg7dHA12OBMNmvNtFuUtrRo6z3t49a6eQzOxj8cOZJ4H/asybYsNG+9E3m+6JTVrc4j3z5ua5/fipuRi4MozuM72u3Tniloyz5gOSc49KsFYSnsgK1gQL6f1aZvSY5frrbXesCITbluHujRbbI23mhgqHdP5V19tvoSOO1+160V0PPxc1X7Di5bn67n+EZBAbjKKJ+Zf29yanGKd6quO+EZESOIzlpOzfVqLsFY/S7fNtP43tTnMQj83NZHearf8F+G4cvoMq0TIlqf7RxScnf/cVRC3SOyC8AQAjdn+IFnWCmKreIlW7+MC1I+B0gxVjR4izJVW+DptiETpxBc4xi/Jy3Db3CaE+oP5FyTdcPFT7oHmIH0wH73fyHFcDvDXuH49qcvtAPeOcRis11jiIO5yXp350rnWLJlmvYaV1s5pbk8RZiUYocNj3RekiUyL7LQIkQig5a5JjpBqFxjl10gy7IRFqpcJCrlGjWQwQx0ULM1oZnxwWfJV9NQCyQ/rC8v5O1qwavMLdkgPqfrV6C8NGM+O0ooWNq7sFiIpnSw30mpCGOHq54NhSakNS73NKKYqUzBvV7GegmGJZyiXO3VPQ1vSOUUL1gwGnWoLXCGFoWheqYZRmk720td0khdWi8HTjIVxFx2xeUM5bJrU9mdj4aF07BoTvREx8YSmbFvIZwtMStQCqsTiRugWfz2AXo7yk9Ft4aa8a7ThgRVVJwSsXoMkrt1AzS17dgHthOA+yjtPkNmr5pyIOks8RvxUU0HAiWkIi/bjNbu/aMRG9MQ3OwS/mKci7Yblrscdm7NZN2j9cnFcKogkbAJhR23MhK6MX+GEiTW+cZImPj+fOiTPDSvE48Gjct7t4WHxRLR3k2Z5+Ljhc7dEEXZBrYekEAYy9g0Cm+Ppix76XEuOnbBWZ7t6dQfotAm3Dw2zDDZ1viiP+XP37BA3tQDyH5mA9NDQhyF+jZsjxBc2RLrqlEVC3o3YNKvAqzJuMkU2cX6GRyS0z2th4b99cEoCg9QrCQdp3BdH9g0Csc+ECdMHbaEK0Hu8d7OitFJDs2Hu4rjsrvw2+F28Yb2P8hPT3LxgzYX0XB581ATiRuL8CVJRhhfXuNnN+BYeNfAOscDXuWgPcb+VY4/6SN/+fEm5C9RCMmW127EvfCGDvfCPfDKD/eWM9Bo9E98Ga54AnoRt2L29BeJD46tGLED556nu9kxEh6A+S4YnvndYthO8lC9jYPb6tTIx8cRhyiddByQnGY58O0ZH/Zc+wow8KFEQxAFwfNmydl76/4jd57ZKm5JVHdX+yrJb6kD8Rfr3xH9EWLzsvoXvJzKplyTriJJMmRZkAvSEoHpHGMK+qlN6em4g71bZvLEP2PKLyaaSOdei1tmTLj7g9d8pJotmwHgW9/b/Tbj8igW/rphLPxPoX1TfzA7iXQs+TXIJPFsLPkmJp/wqxtLbrHVLgyMFU5yEomroJh809BF8JJxMfi3brqxfmbfZGHnBkxjDR+3gOMv9M8bi1DIasH0p6GJ8heJj40D4e7gFuKCfBTCvfPrqN62nKLKfdyOBLVKAd2n+LNhJoi3OGthgQK672kdxwZLFO9zAtAtVOlAhsG5/3Jx2bBoVrhICie5cAd6lA8POdbamP4C35skZntZsxIdAykg0shppu0EfHdg2Cr95lL9IpQ4AEJw1z3A9blh31rbHE/Z7G3F0WHkNzCKovi5x2B383UdhsjhYeQOr2VuFz03OISs3jQyhXzhzu9Vbmrm3x6ZQH603+4juLp9O7MZ+YstkLJDkDouO2jqz4MXkIe2ygtg5r+jCLttqqvsfKmxtSMMy6gMucLLt6eqQq4+SUdhKw3eyGWzqbM8Z1hFpfXJfmfZjqbKrfCjU8byo0dtGiJ+ugXm6aUDEirc5SS3QP3oRkq2FAD5dIyfRobx35BipIamMMrubdJWrlxdYsso3Y1H+n/5biFJNSLRcZDa+UmEgiEa0drp/FMaQNnNtlklB4UX25i7fhB2TxyyPoKiYuosgNJBlWUrLBX+bwhL9XeixiM7z1aXJDdNUwyV10VRF5+N3WNBh8IlPleoVXPcIX/SNAFSg1RgVYOP7UnHCioyhBAF9JuxI4n/JgFc0wxKq6OZkeZpaDYo9FKTsaVo0Z8LRnPRkkVL9cEzqQigZuNZyYOfAafFK2Hj2QSWgVsdgl6ZRlu4ZRP8FftrCsACutHhv8P63Z4rYf0aFQhKLU5rKkageJTOnddQH8uuMgnlRMuAe+GXo98AcklPvA2/kZ00ZCqXCPJ3EwcIubGetmnPxrJ0OJQIPslAUQJ0txWDgi/oBoWv4I9vcWJg26pDHxWRVcu8i/6tQqXj7xmCbLVVXXi9XC1vhdtiqi493Bbqm9SJ/+DP5YuJ6wEXX1dsfkTVGe7dj+Ck7bQDpKsKHCwNrAFT5ji2edV23l0Ca5E7nYpIldYd9IedHG0y3GjXsMHgSSL2cx0ls5CXU46Wy4YUCsCnUezAVS7mrNDJI6oTsq8aS4iL0KPUPd0Fex+czsVm7//sMEqLfApsPCrDZ1pFS0+Zj3eMGJqp+1r+SGGVVvAdaCYqnUlZFF0U22ATREOyA9Mk6ArrDhZrKeRT/xoFaNHabQCgheHIIEBrW0AC5hxf4o/DOY6ij/7pkRyarfJvwITU6BAhxcjzvtnw7jpYfSzwFfcO9IsoNVK399oGRAGIjnblu1tn4Hykh6BRGCvJjBoJ+KiM3qp/ffdcjly4FaZqFq4XD5hzkTNpKgAzgytpOuZK8qMeVdJxRpU0R163805nX9zGR01vgo9CLZYCGoqGmDpaKH+Z+Pp2dFp31VO2FWDGaMtdPkY7jszuotecN3YMWvvEOLISffRK2ii3Evn+zruUuD2o04u2YlxKoZyjruclnozN0vevU8w9lJxspM47d6SwO/Mh4T4v3Io4hdzxK/eNu0foVFIo+KgzXAiMwnfi26zLgSs0x1nMWKEtoe5ax0PKd7iX+SW7s7Mh5mrNWl4ac3NDQhvmgyMrIK21h4SrXah4JkY+LtY7TN5CT93iuXQ+jSUPiS55oOgzBNunjgaxdqKyJQ8BCuoTeAOy74Yp1HsE3wc5l2fsgk8e6ffJ2a0yKg5Nh+8gl6+CAo4OE2LvmeUoIrLnScBDNrogyBgR2aA+QyGRQT2m8YnpfOPFhI0ZWDYi8e3DupNuoyOGsgf4LeUQa05Y2D6Nk1TUbx5gcig4PDuEfmXyNCIHQQCkGc7YIyuzJpTgtbw/OUGZijVZdsB0nTTL8BxV892KZmVgPl0NFMwkKkVFRL+AFyUbaDsB2yK+0CiURTMQFIyiNAyPr+R4tC7dIEAJdDyzz9RSlbr5s1+Ei6ajys58xB3G3MqkcEfR1ifmlsKXfNGsV9PYktcnZmac42rWyGsZKjpfygu/IYMePK9oafRBpfSBvFFUzZTugc+5oltFx687E3wyxAqPlcMzZLNRK4j3cXTrPNIs3CjZbBozeIkI+r4lFj++COQaLZXuoVK8u3z8hR4OAT9veSfxk6zS6s0mdrN4Ik/pISbxkZ48YHId6NQu1FO3dlGSuTOKeEuPGMBInjsGRnJxHYwk6zu0hxnMn+7jZ5k/vTXxk133Jx6XVp9SCWtrRl2pEvacQbGSzsCy0X2E7IBL7qazvVyLsgUngKhHV6rEwjBbqpWdomtPF9kXqemoT63EM7B/5kxnKKm6LWanAgsCAz6XOBmv3Q2HbF1oZV2MbnOlgpY/EMuVMCmvU1YzK5logWNfVM+pdSVLTi14nKennMwE1Y5V/H0Z+nWOLJ+sa7fTaqmdVv914rMPelq9I7FxONm+dSTZrj5U4+KzfhX590nHxLWPDqXkXCJ/4j7u3/mJxNmJf0cAbFDbdSBc+9EyD1Bk7x0EcMfiSAP47b2UORcqzwep8sRDv/vOPdqcM51iKAscRA5MOZPPxlcb1ig7aHD07Ibg4Nc9RJvs5Bz4jxmWPNaJpqw66Uoms5TeAk0Ov4jUYrmoQf1pgz57baTP3nhQ++y4ofdggeQnfAE39IsYMHGXm+Nsk4RF0EYfPmpKqG4Jb4/DnNMOi+07e5ncvXsB7Jd0nQSITk8oCBmHa6dmeJW5S57xcJacJR2anL2jC2LNlXMdEGvZsUDzyXMShoSW4ssMxUo+ufMx69NsreR5VimL7Wl5OgJaOdfGV2k1ZGHf2ADPzhkqRbG+I0axwqUojPUmeESV4dipR7wQN9/YHsEsuW2HIDuHZ9+WS5RHXOLhPZc4Y8glCr077fytgOzvzc+0naFYK3acodKPaIYC07jOQERd214O9ftbo9hvH3CIW4ZQzb814A93xhECmdAE1ERfm/h8e0Iibr1m1NkOftDmIkJfeoSpzRTp/hgKcFiJSZfaFGRsXgLtUZH7IlbUBRgZjeEjoxISr2ldTSUk7IaCdaNkrgq2sLd09s+PfGAXc6dHxKlSqFiGaSupVCDk60LSCyVD1mexzpDkhQALkLKZZCvBSHkNx81K8d7RUa1O947Qr0iamgsxJ7Fau8jMYOOoSe7d3OlmxoxAYKHtOt3RTpYkV8zraHMrjwkC/nkeZ3ueqEDuCAIcttrQVgoLc/PIrbMnvouUqIBpyR3oU37xAU5LujnSjnjP6mYhxhf76BLGmZPcMjAn+dSo5gSPOUmuz38Ks9lH2Q04j2IkT9p77u5eSMVaaTAGQRXM6TBp3NQZkMwMDkj+3+iAZH//gGRuca47IPle152yq/knOBauFenk2o0D0enmoej0Drh8m3Hh6tadg6OR/MBoRGeR6/+AdoPeZC+lcnK7nNusJxnAb6IX8FBJc94zrCBQsEXozEnpslM6lNOgLNYREDi/6RSd/Nn1s3+lCU/rv4ZVBVJoq4I73cxr4dSAqMBSzgjMUMz+04BTPWk4B/rDgTvvCXH1z/0UnkOr/+dT8OuDXP17w5U7vx1vuXKkzF/dPff57nChPje2d4yU9M/eBW+5d7AiH0p/xsiH6TzDwzxjIXExKJ6xYE8LFbawuNSRReosj3F+4MTrZh0SVNIPoBpYNaPW3/VJB3lrFxuVVeeBLUIKqmEuUYYyKIdKNxWKqGk1bCwC68arImKAYbkKR1FUkITE7U1aV+7qBIRcgPLYcicpJOpzRpYCqqB7gPMlhpHDtZqPTxciy+eTYraQk39JDp7/qrN/mZkPDJToPO+lQEn/sJ7s6KKye8MR2smhHD4TifMTP94ugw+/ikZOc5DBh19t7CX/K7o5G3H/PKyP+0fOFfIyubLH/gOWSrTQWuc+VDcnN6YNmpifHaQNYlmFMZMdJA5imcfkma13P5SbO/fxMywBeislaP5fMH5hIXSQnqzaAaeyqy9+c1zn616ivpsp0lt2aupC/punVKsGLkEf5A0Sak2rWs5QjBnvBpigoZtQL2dFylRF8AgiXFrBMeCTklJ0S7uSTl20Q2MX7r3gqHC51gdAge2Kii4ZAH7nqeKNCplD3Wb37Qy0YlTBhqSMRh9Asl6SZVumW+iMFyvDp/hjiWugHpcgy+1YCL+DzPJKB59AGtVmlIt9ro06bMc12jdHot2g9x9tsi93oA40VC/GOHmyFZtW1Ox7WUbARS7BadaMWjlFLpQKkjtRSeGSqE46t1NRE8lqTDZtryiLuXJVn79kkhSnZmx7fmHWMDi3YNuT0LECSvNJlUzUpEvZri5ZCh9kMCz9zKYsWzfQAg0vXAXdwOx5s26F+1oVYigBajM94y7DwHIqnaXsTjkZvJwQtiyXS7a/p+gbgiUXz2qQsFw19LxLXL+YSel6vlR2zMgDN3wS3CKRR2ERa3+1EfUWxz1TUQF+UJJa2n0BbX522Hv4BUSUO0Gq/b44powvsz2qsn2AUq2389ilfsHtgbtsE3auzjdTtqCt+X1uHV9TG7nKkVFN7YftLWTh1ORJA9LaaJAxVe1zNqAIqpZrafaNHMmdeur+tXvGIADaO76iNtxmQFC7UABTu+NLgdaT1kbux1S130npg3w17NIH+WY+ZojZH3+XWXNI68tbkQPxCefEDxBYZhOPQp8YkwNvZW+craCt5m98UfDr5Lb88D3ED99D2PAIWJYFJNAoYMOPYvUbgmtm6TDfubjaq0WLbYmnapmNGOLX+C7I06PKDELQBUNRf4JG/aTrewJyysErRQjRh/udgUvFqNSqpjzVf61wb6Rpi2K5GHOhPQeZpIwWWQbT0MJ5u5UrNmtiDNDAspEe1ilM4RVlX9N5JCkVu3W9brtSIHBY92pyf6M3zJxsVAqwlEUGw7gQN+GSLujIIOnUuxtSlhhEgfTUvtvBqjXr1mz//dAqxEiKXDsJGgBSdEdYrUcxEfapmTqvO0IycpO1PRMS0aUok1Fs9LiSvFawc4olI35TTeFf8KdCH4kuezBA2FSMe2BHnh3cDvCUVipNPNB+bHWxfY6jpf3dYy/FFq8gQQ7C0dS29wDNcSlbUKM/xe3VTL1UN74PmgdHktw2u1UnK2HI9lxfgtxNmZZ7KNr2W1+iO5NMgY4EOFl3QIsK8u6Wpqi0l6w6oGYKFV3gdfkx0E9IcqIq2aqFl4LSFv8yFTJbHihzedGWXOQZk/Cqo4bJIQcQafIgaypAWsj2kPhaSIUZVWLSckpOpWikDA0jHpM+DTwRrgQNL0cwQw0lDyhKnLTiKDZqcZFihM5UbRGce7JHPgsBLTw5UM3I/CjLspM8ElC8gC9JaKQI3Be1SNEcCbk8VAhMSRUppds8FhJRF2VERViEy0qiKQA0YOD7BCT2dYpEwh8Nsl5I0wXRUWZQR4oCzoYjakkRAY3m/4hDFHYnADiPnyuo8DcZmisGbjYFB0C20b1DGi2goUwLB/zIpMjDhBqlhEGgw1WKNDcFbJtsCngrkxSrJ+JntU5Q5Sk/g2QZL4K7ETIH+HRUV1ZpdxqnE1giQ34xjGLgXlMUD9kRRzeWWOpB+ZRwsT2CxrI+NqVGl0WnsT6JDnwDWMUxWJR2+6Ls41b6NJeMzjl+LACxkjHMq1Ty54LFa5cI98rNWJXes7v3ZJdqycv6jFRH0EF10se0VNQo0RLnQodkE6Yl8uXduSOZP3wV/nAgcUviH7dFvMQeQ+pZaTAfqrTdJhyk3wIUEeRLiC+D5Eubukh12EVilq/OHbmhj1ThI+2IuU1CJrM8e2gSBplaPbI6Ia7nTGiqLfiUo+s1PVamT3hVGyWsq5dW89mFMV1HVPitfEcSmessbk3UFDBbgpJJ9wKDpTkIw5S+yxWQvEDSoo+pSVRCDR5k84IWexBKIXiQwTzII44HB3KVChJsOCH8h9NENaVZNsdNxA4kZ1F2eEGKsrclCXUfj/E9f5tv8nNoGX6FiBhwsTEV5ttwEhiJ9Xv6KllIUdL5aUeLcrpTaCOvod4RtHs0EEalrG7MTfhu2dPX1xls6sR/ZtktO3Tb0T89fTD2BC5cpe5zmIQRTZpW+u5gMMVNY51+sb/FRNfrl8IlOHsBoW91P/s9lrGqhOuxWo5zPvzBW8+RG2XcEGjCuOm8+d6D53sNV8tk0wo4khDpa0gojxQzki26Pm85qKJveNSrNVcr1dEU4kVThcLk7DnXLvz6H1o5LkulTHyDKBqUPQwrrZqhTi8dgy7POjLg0ABj62mQ7RmgU6SaMYwFKokOylGZItxU3LmiJp6at2ZM3C5Jeh3JmWLRyFzbXJjmn+RPgLpPFjVAoEEqGM1GZTrYBKW9oDqaHLROg5GFaE+qdvppZzQ4w9I5dGDQEtWSrX+bUQM1ibsHMYzSEQYzwZyTswJd2EelLHGh4W6QNCXJJTOFnIQCaxUBp1BRfHUGbTCnblDkZZI7Hw0h2QnAb4PXBDcznJES9ghJXI74GKnEiQRaKeDcQW+EJBTBEDNqPAlfVeg1B5A6fToHfjEpiZisCgD+AigXpWhzJaQZiCRYKgpCelEm2xcyWmxyK8P69bGQEpdCSiHzrPmAq8VgfHRfZ5fkwcTrKdcMHYqs7h3rgpTQJ+0bnezqRUgpBGhtwSgEyAor/C6cPPuGfdyWlyIhK1ef0egWZau7ewumh2u+a+sLaGgbkbXZnWjiTGnZxYl2ZYbX2pU7sFWyTRwPLGSa8B4wE8D+MRXdCvgkXkUHqvXt0cbxW7cfm9A96lJI4Drdz8Xdx1XGDgpm7XUKy94u0Xi0dGjsb80Xh4jF+OKaTqlXAWaA1VBvGmwqLuZJ0otSSqcAJJphijyVr52h9ICRU4igkDtUYy52O4ut5/fx0T3f37MBH918H3HcTzcmjpNocUjIR/3JTiWYtfS0eWN/l3C5UGzXgBLb5NaB20FibsAHNF0frDCL3SbhN8cho2P9oa9jRrLQHpy+Zf3B6W6f/sGejxe/Omn0KOkGGOkOjvRiHuxjfz5ln0vVJt0O9ZzRzzz32KnVoi7nT5mbW80rSn6V/M8uHfgp28EGhUx7PDgMokuOJM2UF0UKI5hDKtXjl2MJ8le47/NT4AT54v8SThBB9KVY7ZQN05H1LMcC8053hstaSiGTU8Z7++C4s6sz/dLA7Gpql2dXYONwTNC3hD6lxmv/B3W7wN6ei+EbREt5srDBZKo+MplqPqiTqf/Cj7NrmBFzQtnHd5hVp352Y/rKPQThURRVns4QVcX1o+KB4tQUwxF9l/sIBlmnJC4H1xlQhbFnMJ+g0grNxiFhhY1jyVLbZ6j+Yp5Hjoo+E6WobLPAIFWh6/bd+4oSGgq7Oxfj/hBKmUjZAOXUDMTPVnbaS/GegzZ9kiZyIjJCzhZT3oquYyMBKWDo2GlfpymAZVGq94BrfWH3pluX8TRnTOp1D00qzQifa3joWmuUA1nm4XDUqSS3UKBU2D9RPc30cSpcjPwdrUQCjFHTEMsV8lHpvp2fTjHbf437B4zdz0j8SeIfxmG568oet/k5wgd5D3ULhivuxSjCKTOH2rpydOP0ha1b6MYprcQZx11HtJix3L22U2Vf8MVd3D1d3ozZahGlQN2g5XcpOh1zPVByVGNKDs3Xe5wcZzFOjjq5e+dd4prNiaxiNg7uo2y/9LmQEfnHhwgbx1Z+MbBX2lsrrfatlV47sFb69tG10iLWSuu/KtdYO9FZKK3LiuN29kn/cxt8G9/beXe5dAves3d3tkiR2KxDsMEnIsSfb7fxEO94ULdIqeaXRJWKRtZHsd21OupOMYae7QXyAXnRLu5DVFd7K6N/paVs01ZfibIk39kUPd50Ko6ZzuTd7494DExIXcaGYMWu7DP8W3aptx76VNkH/bH8+P6t0IM5IzQ1g9PMqwZ94+YpDDM8F9uvKlYGo0LJQJ6bQkVzBBz8j4SoY6JOkXioXGiZ2jHJyuLCfLhKdwHjNRb6p0obvI32FlhMcMyuol5WS9dcmFIU397cXCY7S1lHzgeDnwdVZM/KYR9F0cypEHMQ811okaJhJmJKdRxGwkQERa2pgg5OFjwpmA3/ycjrIIVSYs61pGIbjmNkBJu89mS45l4MJZGX4AvVN8tOYFDFr5K94AguI8SIO05YLlQLwAwgscTCIQ6kwKuSmXNyq7nW20m+OW2roW9jcqSVmuTxO8oRlwfo6WwQp1+UeCpYdBKgro+ZquNKkU53IqqpgM7W/m5JQrtLvkS17OPjWZ2v9MrL2Dp4MnMLnoKbGqtdZJPPIgFFpZS7AChvkAxlbz+8d5Dcq/qp8ll1xyElJ8BJrZkXIUXLscwaRkyK0P2myQK1iynnivgbQk4oGuir6axNNpTc8SLyYq50eTRAPtBPl0zO7gKdygyKYkNwnBKZMMxuXu7wdQHyD4ptjtKYcM/CcHI6HWHPl3SE2dHDUqyKE+07sC/KzadMN6mZhZUqL0m652l0z5Mt1/l1n3Brj61GLwmjmE8A+ykUyEYBSx1EE/lhDMfV1kXjPorr0ZCIyAE8MHKdysvIAZ4CZrdPjZsD7LTh63tz3CAxW3VjzptxkCXnjcHAdesOuQf5/wZ4aqINGW3WvnnyXFvcq0/OfWZIploZJKO5sJ+55nA/c83an29Oq8UlZAxwOF5PLEE/sMdis+xUnbC7301pbGIOG9rTWGYhmRHaSGS9ewKjwfiaAEPJtq8J0rkmcOzk0OmS14gY9lP2Gk71nMiMpNPQA4wMHRKkLXwwNdM0VMNILfmGrEIaAQ8n9d+j/EEaHYPMmEWUdxIagIZMUOthU9Ftem/ExyYZMBBH11TCyDK1vGBekD0FMwNQ1QCp/YtowZSVmK3mMkZVI9jRsZl7Ps2IajhLn5idsVt7MWe8Mw756XbI329POYIzFPJ92/E1cTDk5w/nWu8HlfG07U+pCPjFJoJ05sR3uDXQGR9LPJEqW/RxdSADwuddeQAcCV4PfLphfCYbB4XFbqNqJCgwaw2GBEZNw32vx4tAU6JtEiP4LCi39MmDG4XuWxC6196e2Zc3DZI2QVsMhZpTceTx1rAgIqloN6BRlWwj8jUxk89I+La/JQFmYwJ0L1Q5PJyy89C5yqyQs7qcCObk9LRlkCcMkCJcOwYpwjNjQOqraHBHpWghuAsIPO3gzh3E+W9EWLjqHnz8TwAso2AFy6vLQXo6NGxQV2YXiryu27ZGRVvZm3cnMcRhjnEfdJKSkCR7SeKb6DnvwCJyvx8tD/nRfFtfYbXfkfq3ljmqXVHfUa/5lx1bQb5hU2fLmGSA6KXrqojOM60bdsirijtF9XK054yY6ZBzBr3Rz2ZogXDFAG3RO7sOraSzGeXwS0/S/Wgr/D60whVQfPwxohLbaFxt97xX6YYq5TobpPgYQowMc3yM3h4HSK++wMPbrS24681sHyGHPePEZkp26Ti6uI4OG8dXWflg6ZaV249Tr1n7y29ulw68Vjq8Mlo4fHijwuHh9Ed2CTRoP1rHwMEYk0Kj3qyBQuNjqB9eQx3LtZpOSlmy/U7tsJ2qgW1mfI37FrTYL0o8nc6ndjrhI+NppWxDnv1DO5XN3TWmPAr5xNiq7E8+uZytdfsYmij3DwD2rhhCBP9Jvwr77TiM7olvgtAkCUWcu9et10/yJG1buZ0bAX5R6Xa8yo4dr+UN4FmH+6XZpx1ysE+avZmhBfnLewdqj116IAeKq28Io6pOTo6or0v5Wt0Z1V9fxrkMcIe77Fy+KvGNXajAt58T8P35ANtx4bougnSRUZ40sDBFl5+WVxrtH8aauYEz73d8g+0/fGSHDrH+ANMA9m19ScBtdFVA4Fki7urJSMcHwB6SjcgmDko+6gVyqKZdiadcTdDCkOmpp/ilk670736g17+V90Sx7/q/GsvUWFC2zKTm0FRaLdIHjHwaWQanYgNYRpTifUwtMTT5dqZUxEQFy1q0yyfEIqpAs+iJc9EkuAs+x/RmVzfwucWYNwRrKH2I/jotCumKA8ULLTUrs0myJV4l7MBVpCG9+IF94Z5e/I/Kp9ddEGqU3GAixD1+H6aucBG6ES5gm0zgAlXFLJWTKASpqOo8af2albJlJ1M0K49+3I1Fos3sP7J/jvzpBugUHx/33sIq4kruwkvObWy0E9yvHM+9mghcCeyPgtB1AaJaZsmeOj6dmXFNG4sw9h6X08BcyxDYhO7n0P+0fhAjUFJdBErYQaDMFzK8OGlCYfceuvWbLxd6K78YyXdojejicNt6v4D1jmDT5P3bW9JdR899c9Mv9cWbfus32sbHM2B8TtjC+IdZpGEIGeoA3FtOSuT94vLptdgxfOYYX+s5RpI5hmrTBRAa0OEapdg1nlQsOWnqGLfeUCTOxddcSl7d7xbf7bhFmEq5qbSJ3JCtssAzzpnYcvW2t1f7NPhHPvTdPv9ATq0XTb9YLPnpSef/Z+46AKSqrva5r0zvve7O7uxs75WyLB0EQUFEQcEWjSXGKJaosUeNPSZRYxJrohETQKpUCyjNIIIIGEs0iSb2HkviDv9333szO7M7uzvLLslPvJmd9t6bd84995xzz3c+QBzMFohaKAH1Dl8GlNb+BzgRticXuXnUDl8AqojtCxRFMqXW6O/K7E3QAtQjbsw7xZffLO8u6UHM8555PR4TZGb2fJOy0nrP99zZY9aCu/KxAylp92kIluRlCJLBVFavLp3VA5cQ0npfqGk9kWf1wHMZcoaa01k9kJ3WNaQbxAgrerMT3sJIzJu2FIFsS1GiWorP87AUyeeyiC4lhwtMu1oyzxpRePK2iLNEK8zED5EJ3jpIQ6H8IajEmMr0V8FLHbxNh78O9U8tmivfqvopihL4s6sjI4qaqf5GPL3Xo5ZK8sMq5diN+J4+XTlXpOhfa5OwOm0xpmdbjIb5dy5ITu5uMQoqRx1/ddpiTAcXndVQUBTFyi8mP/eHvG6Ab62VtdU2V4OHJbGtUuCY/OuZKKVGMbGkw8IpH4UKSdQQqmSbzBM3W70Wg214TMcry/SguYSTB+rNJHiqmCdaHHGzy+2FYWy0xRzJ+60hj7W5qGAAdsPuq3Wbrcxi0aFeySYUeDyoMFD/VaBaCIxZ2KVUpW2wmsPWGDYwAyhxdtthsvzlbh6WByOoUhmNLBOiSCQnFErdIFSlCHwjNjfKlezlzOjzeDijp9VnjwWJaaz276MjFblLdRpYjXt6ilogEehTt3F9jamiNMURENNkaQptPWBjuj6J6xH4talqp1UhakxpqFBSlpDSSrQI/Tg+qdDpKnb5yv3DDB2TO1CBhQI8g9FtBMgKnb9EdcHHbNTJDY1drPWYbn2y1i+VYRHOBVoYmRokSGQBlV+mqrZRw2rMniq/YKkbMXZ4jXAaerXqoiEED/pUOgQHNjntCWf9zDpreU2VQwjEVLZ6e2VVmTWDr/6iLr76UGvUBTSa0W0xp3cCGbKJTFm5t6GO3IqSnp/z3bZUHfkAaOu9GfXkkAMPAZTaQ5GXAKVLPFublP3ZVu32KoEARwkWp3Zu2zjQQbX8hcyXq3r0yIrDThmeN1V9y/HjEuky0jN4qgNb3UUFRgm0tMmTWAQN/TncDRkqh9lYM3Jce53ZU+lltSeccFylLcrrvmNOX7m3E5Z9NICDMvAEHhBIz+9eMXp0ojnmEJzFlr556gs8gq2wqVwrHBVuqpxcGSrzW20oUdYbnQ6H1YJ9eZOcEg5z2eFFYzqaQiGPZrExS53WWOed3WpDFbB+IWbMX+k4bJmSG9NDVWM14KoUVbVXUZK5FtrsWaQus9ABFaSryE/kDrGiAwo3cMpQ8oqJS41+k7EW969e0Vxz/ajx7Q3m2ORSFE0XuXwVflvE9k/cxCgYE4yoRDGC5k/wmmFs8FuxmhiisQK0nxWTxxstViQ30KvGURiwWxUYvhAPVakYfO+U28YfdiP7F1MXL08rghdZqAj5AxnJQqw6LnuJs/7celtdUw3a50hINpYkShFLWfQ2F2IvXRJLvTXg8dgVEXGAPcqndRxpoUyGt5AJt9IRdAH9hu9qDKE689pnf+4dDp+2wcFys3Z3J+0WHhoybbYxi90q6AACYp1/Ka3GYSNe2SlbbQaF/bIoXlDH2IwcjNzWboTcwmMHr9C/7mqUOTdj0xmNgniPTKwPoUxy7czaZwgtVedupVK6hB6gZ3v4nrjPuWvM0hmL3uQLV0JxOZp45qhfc5Wf8PLZWJ7b5YHaXLZcLqgZVOtjtCTFEKiBMw8JJyvTJWXZG8vJ9MZyMItqHfOyJ9f6Li8Qad6UogBi3FNRkN8wGnOrSvLlPpUhualPonUYSvuBfcL74Fc/EeWIh7SCSM6Tuf3wrsqgdqUyqHmQlUH39c3PfitSjbdl1/50OHz51/4s6ZZ0rOzJxX5Cdy72T5UGSB4k+9/AjjFP9t/7P0v291P4uWmoEvy3Dgn/+WCze8lr1Y7UmUl9rSd1V1L/sn6KeHnZ5d+FD1HAMx6b/TdBdBqgi2u8ztcVmMdTzrS6OHJNb27V8CG64q6ySbzLMhfDOqXXdNd6GFFnFkQLn5yppTo6VWC8yKOpleds/h3tiFbGlFuCLcdQNGKA6r3BQgaExWa/wWFsHhmIeznW01xgcdQ1NbhDeBZ1emB9mtgrHEUpKOmzZLSiWr21kJVL7R/NXYlwwlEIHDI7DPfc4HbUWrDZyGwej4wmnMI3iPErq72tw1u9tsLCqMXmkEy2yMRi0Sq7DW4T71CO+aT3uBWYsyK3RACRNxdj5wld6129rbyq3O5Lb8VHi6LqjD42WOX1lKG+ymouLC6ysUSwAFGbv6TSqe2bvY2pNJ7u4H1/hqAMP7/J6EtPRYiir7nYX9n94nTZfV3PsvuVyXG9l90/m4qfE4ai9q6pGso9VVU/ic9UI9Cz/8qaqhO0qcoxuENVYy9M73W+1p5Tm5qtdr8v6Mw9Xw/0MxcFaoS3MwU1sOfRZkXyyjoDTm7e61vZF+laariX0tjG9aAthfJSe3RVsajAI2n+svaWisbCcRQouro44WXgdbiTo31oqMtiX7OaBbvNV++vwNLidCYSMZNJKV4wInEEHLXhPQtH+iOpZgRoim9PiWH/t46w2WI6GdnUMHakuWWVUa18sc5YAbWAkRP0MbdUVNQg6iWnI4ZmAiw4qGJZY0EsAsQWNwmgN7eUlUYE9jLj7bRtNu1zKLo0WDl6ylt4rKtc2czXGdF5waHjnZrK21mJzcskSbFVOM6Y3spli/Mvl21Ll8s2HHhZPEGU6Ri6lnfHZSqiE/VX2jaZVouu9V5vK2rMUIQ4T3GADK41Q0n0mkZ5NQVQDEDeRMqstyLL1NeUQjC19btaaPliSgkecCZKYmbFr8xQASZ5HSnpCxG/4G+dNzlWxY4FkC/E5c8zYTJ67LwK59gmL3HG7LpNeVEoHycF0OIPXfJEnbUxFoA/CQp7F6pVdGarUlIp++2uQqNeqa5djJ6aYbQi0NvM5ng8xN5gNhfWCovSJQDBpRPxpSfCqrkgJdkQs+ntsl0fQmtWvM1258WXzJ5mvsJCg6KVTou5yOzTsWPRQMEK1KIIwCQ4BadJZTaAwQRe74deqpB+GYqlj1akfwUvij8k0s+rYnrAct825HL/Op8S6oaBiH3JoMSebIr7L8usokY9RWYVtbCehUvi2QK/PFvgV+UQ+DZN4DfSk4dI4Lnap2die3t2UP//IP5ruzdPjzlUOIw5aAyNimZiYuZwTEx0RPyN/6IyfN69VXrQrAJiDB6DryarV/roiNVt8xkK2BqU3SayFeTsbAW5sJuCCNSEXoBWFG+cp4AnoqyXhb4YHnk8IugaVMFje0XRCn8aDwVHQExpVV4+BeuVXzSTXDSjMns5msaYTU1oUBYwe4085SSjWcxMAyJ8pA4EncelLy4OC3Z7gV1Cr2zBZvXUeqJAxLoRPpUUR01GrJyiaHCi5AAlDBvMSGegDZ8RJdgWnmsQQt7nheN4iba1G7+oWqHN6UVRaOFTSrQFc6BGWbl53z90wLFj5XZXFPmCNg9fuiFByRgtCMMTgBtgMZcmUJz1OrO73bLNmnYD0PrNhTXdU9j5VapE++skCrQ1NtEpWn22mVOJ/mRHZoU2ZnbiwF7hK1RLHYPweEv/M7vpoBbywdfS+vNj+bwvNb8vzjm/X8ue3uayI/n0rus+vVco0/t6Pr2fOvha2ca8iD2XIxMd6X9+J7Lnd1Sb32MHX/2a7I/Ek3v/rwtforx1qkIQllneOkLor761NGeBq/6/EEI0ZsQQwg9sNVl8dJGQIasAtsAhq5VzZr8+VQF7Y1egMD5noPBmjkDhMyVQGNEtUJiZHSg4q50ZkcJEfjqrrzBFLydhwXD0WhyLDgtZ1bEFsSiqY5cNMGDwVPQIGAA2zQwYFCf/Vd6rAhH/ndw2DAnwvnfrgh5oWcLOsi5ZliVtWOQuJBUIn9LJnhTdk5rfyeB78gl/SucAhvfMAfwhOa33HMC6VA6g7j99ORE23uDZmMOJuD7LgdCl/Af8IG5hbG7O8+SMm7tYnqAuIuBKaZIneYDI+1uRnwpyy4IcUnFRkO0FQ5RT5h0mlD5HJqfBrHeHMWuQ9MXmrY5XDQStvBeFVlRv5nxOV8FzDPdG59R+AXZCGhSiVBM6/pxFv0Ln11wdf4beW2wbQAF1HjSopw+5Y3h/vjXUUr9Ep2cMyges7oXvRCNUyiyfPi356270pSJVgP3EiI2uE9GSfRl8u2yz27cvN0Dj7h4As0qLs29mlYVnZXh352mOXXllERw7T9qxK/GUhSpCudy6lTncus3/zuBSKc3iUsGkyeRSqdG4VEKZXCroMMbY5i5Pz52IuuI9/DzVgGuu3qu9unrJLxXWlFJeWrGvJ2tK8XmZrCn4bvu0+7vTppyUQZsCOddCzmGEeFejY8ZOLPPZQLoWpUd+maenbzdYh1GrwW7pwsGiejofUJ7YzlLZ3ZTH2EUI19IutQrn8QXOAF1Xkcs+Z7kVcyDbwZMH4zGaTUy2O+S4A9POXFDoQONFkf0+L3zeRUDUIkYIm3SK6cDuo8HhRA7ZDiv+AMc5I2ZUEXaPMINHj1qbLq9PGpDPqEO5lplvuX1X8Q4lt+ocdt7cNyjvB2afyYk+yQLcxiI5eaViJyTRJJl04EZmFe2T2yth/WuRCrIrarOaXoPX8L9WHGyr17LiFPsS6knSPgC+7S9q0fwBj1enVXEXu/vTI6Z2kuQcgTjxCKaVX/Bup608RYG2rJXsf6RsDuPoY045psPgqUZrKaiSyaZ3GpxxSTBZ2F3g4bBVmtGEXGZwG8MFBa7elS55tdHrMDMk/CPjCsSi+tb6IlG2Ie7U6d0moWHKrMMa2ItZennhIdLLcXyu6KzGMFo/Hx6tF2xBHf8UGntj6hS40L8OrcGClto5tTY3XG1J2Jitqcu6aWpR4/DG4s4X4OcZzbIztUGCG4KaOhxXiW/+jjpyAwpwNmq8TspGe44wJm9mp3be7PK/G+Kch1ZiRj3WmxQMKGI2B/Q8o3RMJk1TGJuW7OhMmqZIgfWG/06oI9yiRDR6XTZaCCEN4EKlNVU5WJfcU6tzsC6FKpPmAUY8wdocEU9Jj4hnu1giCsiGPEBvHarE9v+WJWnodz7+PlTIZKRXBkWONMhc6dyh4kHaPkgeJKbyIAkf8WRqoj++okZ/WW8Z06IuI5Ju5V0UhXryArPeLYynuZQ79UpzRL4rjyJ4PKQNlfbZUiTlWhH7+1qFTX3SGNXPa2STXY5SRdvETF27W7EqKGuGxsm8gEyM+JLHGAoravwtHT02W9sbrrcqGTfIT1/okeSylpEtpbp6sLQo1kUMShFuwszVcRaoKON9Wu/ojduIsbMVqxFHMpQZUY9oz7YaesCTnd7CBmOX0bAqRsODNvD10EwhbTYEVzPWSRxQYUjiYPCdQKUYwY+0VmsW1jtIJMOwpAWXzoOojX+UxMkIuaGpm1GJF/l1rf4eAmrMDL/Q998zEKCZ8GAf9EVjnPaSeIEJCAvOPo1AyYQy/Q0IkcACo9MpMVLYm5xtqh0xqrloHvLrIZPPaFPthd+aPIt/S1folAFuH9lcKtcZZCd6fqEsF7GY3eqp81QYmsMKO1JeADR2Rq/YkEaeiDVEI162GrhaBHRG5eokPW+PatY5vGU85wF7hsamFl0QEZuCOYGRYHpfwANOEWZBZ9zb+4WgcWFvgbDD9FN6IYewNcabvKTtU6ZnFZP9kHaPJSQ/aWtwI/dg8C09dcBs6aYEhZlKYLGyJ1H+AiUwgVIUKuABrzSUoKO5iKla4E9rgS15RloLyqAFZaoWxLq0oN5TYWyGreRq4B4UNo79kuuHy+RN6Qe6ldrCqoI0o0reaOAO5u+APbICEaoqCOhxUDbjYWFeSSVjgwg1D2ad15ShIDroAIJtxtNzyevzx7UotYh7UNDmQTHb0/R6ijgtL9ugxTA9MqT9GobGfuyCOPBwqax75NPQFR4J90J3UAysKc9HPtWAVHHdiQdHQ3eKNQPCIeLcfqxT7YeCAkeKJXmsqXZ4R1PR8T3Mx9kpxTFMmT3FkMt4NIVZeMzoEZONHUefOGtUzojoZjgE2RFRIh3jsPpJR02sU4Mgl5XdABwiuh0a/bJeUR+r3WeNqAVW9ar2gLhmiRAzZOiOzqSzexIp1bFIPJcs82pyzbZoqoM9WJacnhXl1HVFOUF4HSFXMBXlHKtFOXMzQhYtlBFUJA3n4/NksvH9P1hv+ufh+/+x0uTDw8fOP9QLTfKz/sj2+ELzAsA2X6AW9nepuETZLZfzFakP+dnGHlJN+XxRllO4+taUDPNDtwn3qre4xlNurG2f0F5ncNjjmPNGZV9LVCa9BeuF08BFKauJVU9ynqlm+KjGouMgyiC6gWqi9Fl/MLL+GmvQwsVZAHEmmoc3J+RadCnjm/OSI17gzh/79oCyww93E3lZU1EsILyP/RB0NzerIkPXddRGAinbpnp8+gIruNTQdJC5/CiSULw9Jq1GvVzAq0Hf/G5PJvRtWBr6pvoFALiZsCWyhbcV6Gfi5C/FnBNT7GIry5OMpX+2sjf7nUMc6TGyxjjIuXp8JmlZHvQsfZKWobwxxxQbyBxN1qacOzDH9UnC4jH3RUyW5kqR6bt0Q0aRXKmWD1Lj8+YMcSsBWw+Bo/y5ezpI58kM1prT6SCliKoLRtyQk5IlkSdHCupTBIfVX++bFK6LpIM3zAOjy6YQTrAiJW5DGKesSBF/8lPGlIzQhVrgxqXMA7dbkBGyBW08ZLLp/uSI2fUfaCQrHCmSTb/SOS8vOhS2Fcy3fvSj5okAwahscAr7GKqc+c6OEiKK2JExGDClXWETGFrUKhtDISgLQVrIeLNDVM+rgX+9xp7CkSTCyT3ZVZb2xn1yR4r75B418qMAVOM9uozuyW2jBxGf9xWc8603rVa6d8QkUtSPp7N8xvqOiR31xpxB+UM9gvJSX/JoQ6yiLtA2NiMoL/JfPKr55uyIvKK1o7Vc5wk4LAYlJO9cnYGqrMlEVZYcPrGDfccYjgTV4iYtFDf1TOBxklWE4k1dobgnqMbhFVlxeHJVLxhL1U16FRsbDPb4ds4fcagtMhsy2OXz/yU7zP4xZKBMYdBGuKVPbKa5b2ym0hdGdIoRNHx4lIflg2v3kC1wNT4XRwq5vOOmvoKu3jRKTIu6STPHXCWKFJxLqklAq09YMbhg+I9GR5YmuJJnogirrMa/QNUFb1oXLLlCrYIujavlGjdi3AhF44qzNc7S4ShytZ0+avxNh8neco/d4XbWeDs3OH0BxIQ2axR1SwNpIfMFN+N6zsho0tnUqBywK78SlYMcR84Iyr1KZIW4TM8DqgeVqB47QkLyx5paMJ0ctnpB18eAgZF96BRv5i68guR9HqbBgy4yt2Cd3p9/FxkutENjPuShQ/UekUdfmSswJ+XqURNHVR9C+/JEPmjfwp4NZ3QZ/WZwtPIstK85B9h3ul7uxfY8ltv2FGfansf6xvpu6Q/r24h62g+A9S3jPkAiPzzuoQFUgSy0173C9/rG6yY7+9sPzI2RKnd5vRO6pe2Ph/enQ72lLueOYGtPJO+J3ZG8nxldMw7FZp8ZoLZ58AnG0y952RpTYGW8fKwZSYoCBXHAu0NWIs/FypQQCzvDpRwOWtpWWqxxFCpIfe5r6fxDi1NLIJUiQnhNzvpmvvcMQDiOKZRKBle1W2AuHwBkAVFwhIrcwcZA6eGloaaQpajQJ4ggkuMNo5m9IBrAppzP3xqYce8MT53NxnYOBpTWCXssSnO5t38Uj3GEBTAE8IgDhuQx/B3JWRD0G9WqWovX6febmOAucbHZYrGfYVHyV3LPDLtnzct6pW4ozhuLNlzFoh2BXbTkb0WXgV3hCYWQU8CsTcCqJ1CXcjz4HKaDh/B3vP2/W8tSMBViin6NSr6zXWxQN/dRTKgkyhQ6d62QzaeqhOhVeQY9ikoMMZVDohWV01pP+GKubDijLRWtoc6xUfmvgy3wVIMwDRuYMDV6iadOUC/hDvCNTRfWeGeh053wPGILW1GdrrO5qjyKiQr4sbKbjf5gyLJxKLkekhOVr+NMesBfQdBuUCQI0w2ov8zZftl8i8dWbtLzCjyvuQVLDe+zj4tChaEXTHSyGrjLer+90IgSO2ttYz1UEQD/Wjs4clnyhiFjg0CIputAvzQlzczXPoceDa5m66yypuCiojD7xVNQBDKRfoFmgn/rUe6slBj3UvFcmip45m9keo/iUCldAiZFqUlqySKMyNYlvZynLgnPIjbiZdBpb5JveBitdT6vhITKiuR4TK6giXMT8na0ahm00cldLEChUZ4esiQTRw9WIdm4gkInOnJlEkmwLMKJZEd/WlaL9FEJt1PwJp0VNqO5gJdFV6ll0R5/V1X0EUpVdB0bPjitvGRmqAwcjzhFF5uEsdg0M4t2Qu5f30TwS7yFwjkTHU5Xoby+99VHUDKvqeVHKUHqtgCpDcpU7zMTDuXMBw6VKOUU3UhlKisN4BlceZCKMzoLXKh4cNoFn08UbP4ouLB9rmAg6AzUBcwRJEoEZ7QIJerM5vfyYgiPt8JXMmbUmIQTJEp6ZmDD8sRAdb6kykg0cCiUTrhIXVX8huSR6qoSDfjVRmQSsj+cjVQwJipKjAx5Tx/WFbu/TF1XEEJ4O19KQaC+TWZgoI7MxEDdmMVSYYPvZiqwJS8VYQivd4ewD6PnDX5C8A4aAIw6DHu7W+ljSChzdvLEaXp+Mg2KrEnD32OWq5Oc921qGgJegYECJUX+6bLeTUOEZZgGdpUlaPGARdwCPCN3bJ0OLNJme7k3+anR53OhQgfdcw26MK+q0bt0Th8mCwqWg2Z9aUWJnp118IAp2wChlDqHy2VEHvZbxUMBbagOTQsRTijKIkl6HBuMqGjH8BcAHHzafK5rblDnc6Xdi+ASdfgl3Bogfz880xj43HZZCVKTvxwCiNXeAaIwUSeKaMJj2AVDMq6HIZmbbUjc6JtNqDcZj+5C9+agH0BMmB/5QDOvYBQH6QXLud3WywZKPzCnFz93fN9+7p2qn5vcxk3HTH6Hpip9Z5p7MBAE46H8+Ae8LV7ZwsYfrK/7nV4d1FeFb2H/p6N73iM8TTVkDqp/yBkI5CHzUR0FzpV9uAR/z5eh4PV80TXJJ/p1VGdlugRT+ncJmke0ZroE3x00hcHOTAzOzCJM+qN6TPozu3urKWjeL9B87oOhAOcNwFcFWE/sw1cdKCov3xAoA703oid679Hk9N7Re2tTqdD67/aro+aABaiLvhzXI/LF7En9x0kDRPW1DM5/LepC9l3UJ7Lve4H+nVgZTtJeBf1xGID/99Ez9P6QuUl54b0TubAmaRLWLGBIW38oD/m/5CDdkxcs/LWeaBIk0GDvuuE/avtAdFx2SP0iQz+48Q96gEVMURhAqQfgQ8oDvvFqfo4QOv0pHvstnPplwEQtrI715GnRHxp/6OpeKFumZFK2tDrZ5AzKlsbQcUPqFAk39ErdUoaG4N2pW+zDi3oSt3RYhtYvEpXEXVgkoE03qBCM3FAHpQm7sqM3OJ+p3p8bMdEupD0isT5rM5cvYC1dbQM5czNf2MR8F7Eve4IcigoRRUjK2pLcdtA+FEASnl5AEhxZoWAkxHSmr/OrCiTJhRJ8XG0/yK1QI5vV33olvK2PRANC8pFu6Aak70UdX2IO0psCG7PiHI3tDoyQYHQkDRrReXLXzvDNOpfXpVMMkDsQ5vnBMM8Psu/n7z+ZlAbk+yj5X/afoItC7/5T26CohljZQbhTB98Q8fh81LVPb+qZg2Uiysu7/++6V4mB0BH9zRMMqnRE5oD5yPxy1LzVAreNDwNc8tderCPXFd+Q2Ec8zwdS1lexL2+3wA7eNNoKIrBeet1gbKOf20YhLwhZ55XdO0MI3u7tGZIb8zCRuQBg+Io5aDhYEynr+VZrv+Cxziu7dY9ozO7owL7Tv3nklWxh4M/eBSvWbfkh0FqKs9LUpQpSMneSWmnZoPhUUZblU1WxFKAM7XeVjeumlkynCe1b+geauQOmcEvYWhzzC2IwUWlXfKFYNGiw+P3+YcGKi6+8uMLTgFpfo1EyuGuQhXP7PUIwKArOUNwDN2ouC1SWVwI7lrwei+YmfkOeVIp/7+wdS/aTbu7OTLE6y9sx+AJeveooFRt+n+Un3cBPwH4CcR4HX+hSf0FUcYUkp8erVDK9InwqfEVnIMy/t9/q/i4JMN4fJX37FVIG9fZjiVFuvodXB3a7+wPDijHIBJVQfWPGysOjw9bCiEeThShkimLBDxdwUaA7LRcEx/pmS+LwAYDBznlaQlXz+JF6dqtare9LV+t7UtX6NaqMfKgicA9zKvLBzgGTHY4GmyIcFnG6g7ySQLJr0oFhZo/2BwNj90v6IxVhfSh8LnyG9sgv0avI58VTRCZlavt2bl9TNlYtxgYBJRIgCC+9fIIpk0yvVeNiD0shFVfNclPqW7p0nl8JhXVlxUphkHb4VqUIuIn7C8qpuYKUamZ6BI9mylijP6vcVK/ItEzZ0db4bkBwk9qPgEYggOcxPGYlV6I2N68e9zbdX4j9QESeqK6xWi0+c8j2S5Tg/9nkswQgT0EveHxm3OcYikTMwDCYBLQORLWNw/CqwNodRY4OWwBAK7MDBD+IUEW8h6ACB+t8U2EdMxqQeTXWYxQbnKaKe2SH3mjTWa0m0SKjJQsYNVwIiszgIpSRr0ZZCuoWsVGJxbTzNdRNyNioRL2bQ9ILFiOPpnjCl8Nnwk5bxLphI/TwOeEKgddAIXj2gSyNW1XRaQsGsPGI0mDBjmROBS+FwVwsNgMVjC4uUBQjKtWQ3zFY3CAcwvokS7yRsigC72y1mQ0c/zYSlcRKb2cHahYUiiT0i7Ek7bzeBh0d9XIFamZQ6WDzz8WmtlPPmz/LqLOVcQOw6SohJ6jkp4UIONoP41pF2PYW/kHTYABWqVniLvogTrnibVF64sYzaXNYVyW5VysJwoz3okqsSds54hokc7Eq3PXq4PrDOabSGuJt0nhaUtABmP60xrVyfWht4xaoWe2zPZo1drDmFqzzqH7jVfE4J2+r3nSvHgU+MXhbTlPExqx27KOwApT84C7b5SKUgrMPkPm0ePRGLJ76hLuaCQVmD6ig9DLCZLPebkz+AMuTzYgwgaFhccxsjAWNNj06WOFlMTYrpnforbwJjg1+VXFhRyzo8CIT4grIhU5UC+Pmy1bZrH8fpc5YORd5FPYCA2uARTcaw2anRa/04C4z+4pbq9BmRzZGrSVQCy41g97os0I0LrvOof8jFm1wSBSbbZC8R8QxbcZSVJVxYNhkXwXEjWu0GWcbBKPOVu8QDApC2OINW1zgTeD8RxA2b9bDd7x+okcm5hcoMnOY/QUVERHVi4oZ2Qekz7vgMr8MW4/kxgrY3DKwlTReKWUux6L2XV7yrwF6eKkZtzCqXLUsGFrzwW9jxe5uSy96CgFInWm6L73m0r5XUWtN68jWGmvmUhz0V1iBxlFrwYsciZivuK7RUeYp9ZRyAdlV7I7C6BGpqay5TpRe5cZ+v5JVYs+zytYWcy+LqtdwQS/JB+Q8zB5nGS/dhzse9KnQnUhHgAN3mIbccVWhST+bi/V3ntXpVlMRxTZ1+QWKx0znoPPV+oEVEvPXOKMVNmMhhT4JrXBARHFZVcfigJbu7CIBrP2J1Nq8bkBVw7ai2lEVgh8/D4a3tEjfG9dVg4dTXQm/TpcXiwNZ1j2Tpk12Z/sFHanVu7Hf6mBb2KEyhgCEYgVETHHFZJPBa0FvHINCkhG1dZUQn5ZrmQcJnDNrmWddnsFYSd+sUkuKRcK/YXV/Bqv7VM+i4JGsTQNa5ZKrJlZ9U87K4cEJt5a586j7TblnJ2fW/65iKYRVT7kqEKuTmtive5QId35lLThikBIWDanK3uHZlb3vpSt72YiUFriya3zbNRyWzp3FcRZTgVgjcpQAPzBQqbujne/3WdkrxFN68Q/oxSc0Ac2CbuAlvoMWZmqu8ih6NMtDp7qI7xBoMx5Pc/i1hqtdN1g5sXEpKSRnKcx3/WtM67zxpb3DZ4XLBi4MJ252sj7RiEL02j6FXyNYoqC3awEFVaSlzuGAi+lAmAB9dyiuEyeoewMr6el0eVeJVY/FUhhA7NoHwsqdI2rVeYSncq+Qnikzprr7DFUv/NGF2iLb+dveyel4lLqOL5SP84Xy/FQ6fmmv2fhahKfFPcLTzkd6Y6hjBxCcnorF8dqs+gXPgY8gAT4TzoKN/M0QzIShA02VaXPqkcHOBsE6VKioR1LT6mDmQ+fXgyCr+5RbLpFsACZ8DWDCePoemvUNutrdnSfVmMpSlrX9hTlRMagq9g39oBd4iZlSpj6bT4muKvVj+9qhOrrHDlXn4/mBE9hf+FbW7/hW1uVZU4QzJn2qMCb9DMiiV//7mwx9FRT3w5aUdynx2v/WJkJfdUNsRl90SsnJ/792Cbx98y3tzWcrgPNPjhbjFID5fQAF68gNiuniT62/nCj3AUnR+QYOSVFmvmop0BMPesFTEZqd5ukn3vm5JV1zoZB5iR2p/KFiMBRnRgSR6tRalxj0+I487tiCkA9VApLbYy5vHM4+7g2hkh9GJbnOU27WSyZTZW0Zqi6QF7cbLmqqliQ3qnVAaR20lSp4ZaO30BYxmpFYNBQYrvDFPMCDu+y20rKY3o3DuABTcjsFh1A/7aRTTigpq9ABfzQqkZg4YVyRO+o2Tu0FwBIcF8oTvjJWha+8i+rXMqtFkbQQikRdFp5JkIDgRDoqyh0fR5uPda4Vo+W1HmdVRRy8meCFqziqyldnFTm2WaIgh7qItYCcHYmUwc2cQZbLmjsqrZweDw+pvE6US8rL0eTAih8sjiUnjEXmTYFqBdUVZd9UlhbPPGrayJKA1xUsLg5eWxwIFN/M/7J4g8lP8kGihBhvDeBwO6ycFQVby0UJVN0oEIFAyC95XUj6gT4l2Rari1Y3V0d9xZXs87qjo0GPrrD5sOryMcFCn78w5kGfnlih31cYHNP5XD+Ikjd/nIkouVypUlEq/FGl8oNMQEmVrqa0oBxU8BWF4VKfTqkW3yEeIdYBPXI28nTLhwY9wvICfSTw/2JZlyMU1whludA7eIoHE5rnmxWh45p4uIhPxIvVgEI5pLAzDQgZmQMQck/yuF4BIYtTgJB29m2/eI63vY7GUeML62d6HSadw+i0uIx2u9P3Pam2sVRcELCBmNWH0nG95UlPmcEWimJ3zmm264w6vcvmKI4PFOzxRD5ojaLq8ljCjbxuU2WsqjRsD6NNpc3js1sLIhGposLq8LrtNnPYHv2u4PJEm+zoDYhZH40EdHpeAhdE3+wTMPsSqOS9gm7lPdLzAxDnN0v92TMwSw+UpTgbAKTMQlasTkMxjzzBeVn44P05g392eV/T+WPIW2e2uZ1mXqmWJfzu4q/tmquH9ZsPcAuGQiUL0JhG+iY8zpramnSYb6ubHg365IKmSbmm+8RTcfkWA/YVXE4rm9WlAZjNE40yh39naEEL/FhMaT6j4x4puVk2prMBxp44Xy721xWxl9FITPmreKY2T7PbnR1hQALuQU/PBmB3T+uxuX1T3rK7pcc2+LoMw/tl3cxo0KsraJ5cXT6quyRGJWfXjCyyGgtHNjWOjBmNsZHs5lmZspmWJZsje8gm+YjTDY8d3ffRTl9kWKHH6irTBjjhlWGACw68ifIBA41Cv51f0bu8DlVrqcinGxpWxcu0Js7c1IqNEEyqr14H0/wdOERwdUYK+oIMdvrUjpsW6TCtqaPyVXdrGmYziqWQOF19e/EVtfGv9h/fm5NVB6qMU3urlFVezXojhBolKO57FyAIyQqhSblO/r/0vgz8Mgicnc675hoUwgJYZps59oQnYsDkcaDVob0gbBahqhaD3g3Ph+dORSHm9hznjWOfC3YTm2c6XnsSdMfLyytKA54AZ/7AhpfrlEkOLILY3FJw8nybDN2xdFZeYaBUrYPiREBEhbYtcNX1EtZrXl0RihUC3cHG8g0vp9/h8sJ5QQWr3eoGXBwaxSu7BBF9fy1OqByP4HgB4Uq0TwqBKlPiEZ1o0BlQO+3g1yajeMahw/4httdwGD3OqDdKRt1PBYDGCjzFzcG6YLDeF6iATTZ7JNFhiUc6SmAunAVAljsnz0zOFq3YPERxqcVrKsOyZPLgF+i45RCVdn3OylJ/pd/kt5jcHHIg1CJx7AvLnoAT/QIN73xoDaDpj10v6Qtd1oBFGCsbC+xO9KLhUYnebjJ5LfhE3b1/KzIAVGJGORL6kpnxKtodmFyGNILMDor476NeZ0XKQGgK1LuFkLvqeWANWpT+0Vl1zt1QYzq+d+fX4jcNNCYeDEYswW0JTqpTbMn6RFHN9xsaxrmcBn9Rkf/smN9ftID/ZXC62YQu6JYdVcJe3hqqD9xX2JYJ+7r9IIFeyc8j8YZoQaMjXMw+qpwSLDZ4PEePKGoDF6+vAAmEoLuowOeLetv+kAZgoYIYpz6+C8PVEyosGebA2J1gyYJwyQeJ2HpUFysuA7dSeWWg0CEpSvC6WKsowbloPLQ5byUYii7hQ6BHLG+V2DpkXcBpMLqVNOWpI0nHELX7Zi2D1rbPsrWGexd/SXsXF2Cj4ZcH7V10o8dsSrWeSVFl5vQ7ehAmDdLLyPIk/Ifzv5CvaYj6enc/LuzT3+g70EvO71YDJ8zN8idGpRsDWDPdkKkpN8RkQHObzqe7Fc619gj6wuDF+1wspXF0At1FS3NhLwcCvUwgCPfpUrzzLGWgxbaBpF1gFbLyLqWqLVDzLqDB6w7DVLzc3mGYyT/UTqwNijJC7tn1VTOiyNUA+iK5nDxZ88hAci0ofGVZyRZHMNRi6kq2sHgPiGZTc6gmG6G5JDdCswQIzc+ERPsRlR0/qq3ERCooRLamakYZGL55uub+3FkWFFCmsiyGQChszsqzYDfQ6+uWZ+GIzVqqpNlgvb5Lm5KCwkbV56R0Dz0gU52P8VJ1jvIZGRrRMSoSaSjx5JqUdww9rvLRWJ0zXOJyl0ScqRnp9shGi7mkdnhRxeiek/LFPHCSnw2Aq2wC5qOv2G9hZl88oMxIbjf/DiQQD8Zn0JXK1v1AgvE8ROk/eCHlE40vyCcav6wfYZ9/kDKc3G9I7uo3JLf2pwajBiPh5PN9h+V8jv5DdCtz9BSI/3cDmKMH4zC3HcIpO+cgneQLDt0MXniQTvH+Qc1qHtv/TcQmHvhnz4JI96Za5+M+Y61zqnxNuTgCR7GytABzhe+JPhkEE30lEFgfCQRxwFkBRqmonE1jersdYW/MiWpSMU0qyFliRamXeF04UuMbdFjtbvS0hYNtU/kGk32lCA7rmSAIDSjyFxKpYBx6VmuJRnxymoGw8iyFgVDiDIRhwy+ZPWLrPVafN+2X3dkJ52SwEwYHmiTofG6Asb8SqL0ifAxnLkyzEK+vUTbUDrE71ifVWFtPhGpPojHUdAutLPRf89Fm98YxJrAJmcjVBiebkIFcrcOK7zi0/plQkkUt9vtMajFna6Q7mLUHrRhfuyori5UlhEfsfAlZgKTN5vyXEJYZsrPBEXtpapA3q9cAF5fkf7KidWdl4cHF6gzU8YLB4bM7CvQDpetKjh3o+iNlRez+KtSCu/1avK49yYeea5WKzlqr82Bjxz4wbq7kgzm9Tg7L4xrTQdcgMFg4AJ3pwZV80MxuvQXt+SvFgh6R+82DImQ7u0cMv3igIu8Ryd8/OG61zitzRPXd5emDv8FAeTwZdYMP0IsKmEddq7vREvty+Rxx3f97fyPRwqmigPD6Gn6HxWe6MEVmbEP3X4PqeNiwM6GwGZ+OjhG5nI6jezgdoCsJoQYrefKhdDqYaTb/IHc9zAHn7gzuY4ctF/lxvdXRi9dx5uEP98GJXG0+5F7HxWe447wJhgK4BOGfWE/HojqPUEHpb+luOVQ7kWk7sO3PKfg47QOytX1hNFkrdz24UeG7hh3CTVUn1Camjy4P+UM8e/uMzlEQCIBhZYe/uNhfHSmUpIpxs+tYpK6mJuQqdvQBumRPSb6qkbHIyMa4pPPXjikKt9Vx1r0z5VDjESOqxga5gakwebFfYveaKviz8PTWuqmNwdN4AkLoDVNZHG8qcnLKpESktCFi0rkKUcLohIv2hViG0utLsNHeHxpSKdRV6hab/NoaHOVdiNQoz6eUPg0Q8tiDxeihPrCPrXM6ilyehCDVFO5iLOBwFYcca5wVCZAtl4UciQknjBgAvnF9rGlcUdGYxoKCxjFFReOaYuyaXlmJmgCBqCspCgguf3GAFYSdsk6w+u0xhPMuV2EQO3WJ+qgVSAoTu69fbONMG3pDYIkH6AlWX7ZDDI4D70EMDWj58zBvrMtU8jpvF3BRjqfKRRW2ZIhCXbFAFqa6OkoBo19xYJuUCkUIBmCyxtT2pnKkrpp3/h+XDpqlQ1KFTC1pxAqpIhd5qw4VjuZX6x39vojA6ctQAexuTblXqThQPYdSx9oKqLGiGcJD2PFDsh5uM2qzfGZT58d13nJRcDuRsTe3j2vTRxq9Ve1hU4STvUhGG2r6kEF27obbiUnutKHxzjKjx+TxGBygPxOsWIyAK/QY4XsWBQOYmXJJfVt9MYCDnJOMF+maLULn3+IhP6cWs/rR7Ua2AKwIUQoIjKvGH119PVAIjoAl4hg72hHBVqPe5dKHrJawzVaInlMOZ9hijaKI8lRe02qBwQnoIWYRy13Y5yxVShBbYDD18ebxZfiI7Ea7Ir6AF1ai5SaDebfZi/gEBBrNbnQUAEXJbFXO0qjVZTCaEWkiW+60iQdQFK6zeGJmOxIR1uCJWOnRgN+qdHE0Gc0oiHEqJbdPmnBXVDonbsMtRq/XyItxRU7PghYIfDvUCaYydfaeAlz5TUM5f8t6VEX0yz82BDP3pO5zMinnwSY2JPN2ebdZmRzXH4MYt55vYk/JjPD2YU6Bwu9nEw9AlT2Lvr1Ur+K0FKAQNKomWtQCtXo1oOVziLV2VZpGWLrSVMepj3VarakS4eKVnrWmHv6fJ1Vpyhupd8uWnSMUlpXoeKoP1GHcf/WgS1s8HoD/Giy+KQjqGNHprSxNwJReV+QxW8DAZyx2JC+0OFx6L8hsTK4y4Q+80pdPb05XoESpXYWlQJnaXdgAQTU+VnQQHdutOqbizIAF0IvJ6lh9ynH1Flcu5N/SRYrjFkGWLMU1w4pKhvm471qBlh7YH4Lv6htWUnd4NGwBWjWiYxa9PxQCUwI2KkVzgSNiBK7NyrQiUotdb9N3FZHiX7BGKyONaBsfWVWk6Y2Ps3kNKXDtupJSXyEYDA3uWCAcd/E8aOTAn8VZ4kRUhP4Q3SWRzXDDNLYCR6rIul9Re8ExBSxvI3cWfRojSQpsoRS+tKQXRV4U7O22t8G5B9zZeAAFRK4FwPF0MXKKq6olwfMjpWVxZYeRtZ7uby9mJkuwOgbyeU3QgbgiaJRtJ+JhRE6QbcjvLnFGXLYKV/J+YFY8yEDK5pI6dT/DydfNZGVCUPc9grItte8h+IrKXZfDpQMjqTOsEFh54mYr+Ohtw2M6jhnQm81Bqw3YAim51RZwGkuCzb4CZ7SE/Rx5Z5dJlE2h4tqCeIhLusgdDruLuPSxKVU5POgxMbOLAwwM1sKgBw3PJKMR3Y8BKbcmX1UW1jIvFtaikjMyt0I8XjdOXGqOgKQO/qfdW+0rbkdgw1zBiMltjqFeFXIHZBr5XAN6rznZo6JkdjtjIRGGIRAyiYrUP9KkfiEm+eNDLfU8ADr/O6kL52RAdb7sBarz+f9C6Hv6Au8ItYMV+Sso/j6SZmK7YyNiVUXkCFJVL7Ytp8QV10ppgIgKw5TAU7VumsjVsBUyHxR5UrY2RBQHTUuC5dAGH/KmmjoUiKd7GqKwkFwZ9IHiLl0oDiCws6NIqybo9rgjYegCmOQMXdqg0ynqcPrgCJMeyNIUX5lV0ZTRxd01ZbEtFnaGPEe5Ati7jrCVKFiBJTb5CysLCrxZmlKAZoo2b2HIb7HaxUJuuA06hL5Wo6otiKRVdblqAAxJJ2YqT7DcpSmPxyyU99Se3+OMbmcE7R19ISeUFT5B9MB72Gy00xxlt5R4Qom7BKV5eQSKj85dApgFJChyuQWJfpZ9nj7pttRfIxRXlSk8uwG3utIXclNwW3UgWPZrbgoCfKV3loDRTwrHwnJdxnp/SuZ6//Ocy7raSZ4lx2Ut6A9wx1UXKCi0oLlHxnrexNfzpq713OKWzbFYWMddA4veFwx0rekerOkjMlbtsiqXMD171TYWJcqdj/VYrTlQNapE/ycg5Xyjhh3IHckrxJ0oFW0uU3pw5JMkAA0Sv9twqjpANpadCNBjUvOT4bjKQZFhagOhq7DTAYyvXm/wowNb5wtSV7zvlR2FClARuzmFrl7zB3JbtYkrsMFh9FZdnyNF8LAjziGYYZRxKh8z3AWORZvXlM4DuIJKHkBvQafS0di5sJmLakeWagmFWCqhENMSCsNnApzgHA0mJ4nFe6QOHgJXAVYWA46lGw1pMY0jrghL5VloAPj7gbd2gM4Wlyo+ULFGp+nL7uvAnV+4fhx9kcUmlxm+8MgkR4zj7xGsHEQbB/inlW2j28p1uehU0z0culo4sG3pAKdu9kWTJl9wVG33EOjS7vFO/1xuaMeiuNGCxeL2WpWIB4Ej8Nt2tPfjL4czejVsT8c5lY0RozHSWNkzFrq3ezpC0qgdJ6NW7ji6Ll0pp+Xe25R1LMcCKKaS6iNZTp7U9MIktnDuzDxpU93ZtkxwZKTcUSvZFbBEPWZrGAXtFgjSbyw0n9eNB9WgMaQaEOI7qipiyfl58aI+nWXVhAaYLDSmNpgVm9Zazgq9PL8Om4b8uicqemo7/wYMo9vuCoPNi33ek/o0qFGj8oaMElvYGxHqAyki1IUQuqWHhZP5dEOp3ERQMp5Bd4MT+eXB0jKmZMy6+7WZ5s/n5wGJKmVOWZ8taK0JtJIfGgVuVUWWSpZI9X9SnZY091fpnpNq3VWmCVqbpgOcoT28DXeo2N86YniwaZxVDhQXB66M+y1+j+VyvjMj22ZAUdD6hutJKedJQQxrcQYVxwSrt74M2Xan7ImfECnwet2Yk5bCKG9o44m7zWGzDTEoXCKAmBj7gbvS7gi7Ek9Gim2+qN0ehYMTKRkIJeP4eI3HZhORJxvZWOQPezyhqAN4aEBtQx5POHgX8kUuiykIbWpAlrgrm17jS34CjwkpcZssGh0J4cqboTboW60X9U4LQJTQenTYspqcoBTWowMXKqACYeT898sBhwNbNQLa+JjdFl3WhJ+C4tjr85zwQ8WMPKAp/rfBEh0PfEIv6ofMeF1vc/iu1By+DxL35ZzDfxZeETuonI5B/ePveXFdntMQuRKGFJCuZ5agqKWrJTwyCYmeU1Dbyuo5Bf0ZoYMzx+TWaXCGuFa1vCs9xxBcdptj4B02qguVmimw6TMyBcnfKgkFeJNaRiH5GWaaL3OmFbvNkayZdq6HzzRn6efIHpVifho5b2bWzE1OisBZavEWYAYKx5a1+AH5RVZq/PCiQBSNRAqdIb3FbiyMIi0WSZaLwWhAdMXN3RIGSjrB7eOtk4NXdJ9QGnt5xowKhlFmDXYmZRIqqU9W232a/jtU95occRUERJzT4rPpFGdpt/CVWEPV2BC9UEncYu9Jr7ovvbufcbE1lYHVxVVPVKc13C9rKev+gl7rbAAZJ1qVMhlOsNohCOfhxkiJ9iMBEZ0/qw3dBnu6nKIjXuAurmtycEAqthRtai8xnk+7Fvcr8/lMf6UFXcj0AQRE7NfGcWOHHWXQTRwfrisJCGf5x5dWj670C/aqaR3R4R7k8AtLjW5Iz+Y2lvJnyd+gdV/Aq3QRiw4P8iZiWg+x6aywOpTxfDyqXZ2l6KYi/mVshySUN41s1NlDyix6EY5no1LavwDW6xccqjZgr7BD4HvBaNHRUpZptrK7BemKcQ+9arCfMwvO2wQ3Kv3+0ENCuG7gHmDSMHU0nyc35vIyeX8gcwxdPlo7es+HfwkltQZtngSaa/ylywFsKbRYClv6dACdKFA1uJJ1TSNtsGg2MCBA2b2ZTYKiZoVfwRF22Ia11LVFjcZoGxLjqBk18MQ4DLHOtRUUYbzRp8ecahiEGrBqlBqekNLzsn71vI+eQN13XoUz+e5q5bhj6htLv3NchxZAbdRhvgH6ofsT1+bOvb13+2FXS+6yYbHIsNqYpPNUtReFm6sKhRkIgeqnNIaYre7YKVqMVJmKkSr5s87dvbb3ubnnVqukhEdM0dKjtM3WfHTUnd8+aiLPLj494qAF/Wroynx2U4VQHg17juuu65nq2Wt80pnsbUcVaHplR3V5n816VuWKbz7SRDFdwQLlK4oha6Z0EGL4eqjaJh2kFK4fRL+knCLghPITIYLTMRcezFcEgwlw8qOF77mveUW/svlwUKHK9H4Z3tkrPWT2aT4yG5Z/GMKu7JvVfVEuEW7TRPgLtM5/Pn+DpvTHjagIgFKedistqxSrOK1VqrNuukuuSv2e3e5DE3c8d3MnnjblBvGQCfuGSHUI9f76QDiodzK3CwWyaGeLHheguIp4fvkgmr9xdeCdP+5KN/4QTGj8IVkLhzdeg041QVUj9OnuTUrfjxtHhKwF+uSNh0odkiV6m6k8cFpwhM9il0yWyMRCFDbg2vzY/9YLyG9ZHaV2XnIQ9TsNtlJU/9l5aya1aRO8AJPaDMRrlH8xQGXhPtpfM0zu3bQoT3Vh+WGN8rO7LJ8unwdhm5P3ZYGMnu8BMkoya4FQn4dxTlakEUNms9HbhRj6oqup5+UHZ8Dt2S1Ae/b4ZEv7NOLJ5/ps58neyCX01zShj0xXqOQl9B6Q27zE26OTh3gwsrymR8XJsXkIbnJ3L9x9cFK6ubKt0GKIDqvTnGs2r2+h7OnmfLP3cxnqZzVDfQU9pOAw8jTUacITtZl1c6nWp1exsr504ZBO+RCkA0RmaxOXhU9L92hOOyRmV3Y9G5sO3SL8D28C/cMjMUtylrcsgC5LMuP3zByuAXhD2tJ8RoulpKRQj1r2SHMkeTcKYY2i5NQ7gk702WcgYEbFq0nnNIdavMnrEMIj9oG8DbcestW5woN1RKmJibvQo9GdcDuLbQWKuTVbnXFBabonGgI6pWedwQzUiczDi5gyCW87iPX6LSA5naipn9EzydcnkE/hVVDTQmKqVaJqhCMCKqF1KC8sK9YV67Bzo/H/paLn1oxOeWK3NJ8xI82nbUnezRN99/AtSZSAfyQbrZ6wkukDXZFNS/Vp5UXSZ+bGcVPHNZnHe5xGN3raKZEy+54L6BYDojujZ39Wno+9nJXny1FclOSVhtZUFkc42d9u41k+X7U/NP24E+dM9ftGRd1FrUobH0Gvt/h9SlyMwic9dtaCXErDc5QNgc9R+AABcBkamV3O91ISebb51LBSYvyQQdff66fp5/DayY0RDoKylNTUB6rmZsCgqlral2kwqJrGyhQM6qosGFR9NxhUGWBQN/QCg2rNsy/o7hTkyVvoNR8qTPrbYkiBnsyBwH46gGnSP6mdEpS0ZfcJbW5tZ12dQtVuEQPFmXzcxUH3dU8OOrO/dNixPzodrgigqu7sfp6FTpsXBoklmwaKI2mX4E6qAeFV3XjjQpEA1n32WVZTTu/IjhHedFtOIWBCX87kFzmwqfUKkdxE9Hg9G1xJ9w1Fj9dUh5h+JCj318FVSX+nd6iGguyN+RLx2vObeE1OJBDgNvBcXpVzEbeBwSBylH12YW2IxpsK7QV80pYMsOHqy5XTg3ED9vsrmwsqx/izK7D8Y9b03VD1E7k4Xl5p9MS8AcBqu7UJWIC9jIVD3SagP9mw/1FrAMb6lFDTf78fwP19iy753kB7ABAjEhewTtIT/8eo938Pc3NJJFxMmMhE8hNE+hEYeG4ox9hHZNxPZELOzfQGkXkcxtkY/yCy/JHIWk9k8xHZ7Ri7iBx7iJyPELkOQxXeeUSeNgy02vZ8Q+RFWY8P3/ehQs8PpzYoE4VOIgp/hyiCa4i8QlQwi6gQLF+xJUTFcYx/EsU5NeXPiUq/S1SG18sxKuYTVSI9XYVjV2MTrmYxUS1C1Do8r8frDUDINx1O1Hw+Uct2otbZGLi+NnxvmBUD5xxuwcB3R5yB8TXRyC1E7TjGqDuJOnCujn8RjcZxx7xHNBYccOPQvmz8j4gmGDG2Ek28m2hSEwben/wY0WFTMf5NNOVToqm4b4eDknza/UTTr8B4h+gIfOfIH2BsI5pRSjQTv+OoZ4lmHUV09G6iYy4immMimvsC0fF4Pv8rohO/IDoZ9+07aGl72qlE30VEdgaq1M7C97+H433/RKIfzCM6byzR+WcSXTiJ6CLcv4uxpXIpqGMvw/24YjTRVWhOfw3keB2u7YZRRDfid96Ma78F57oN13o7ftvPcZ/u+DHRXVcR3T2B6NfPEd0Dypf7gkQPHE30W8jgoQVEv68iWojP/wG/YxHu45IjiJbiPi/D+Vbgfq2EnjyOa12D866rJloPWTzhJXoS1/00dGcT9OpZKNtm6MBWHH87zvOnj4me7yTahXPvSRDtvZRoP1Luf8b5XoUuvY7f9AaO/1fo19+vI3obv+efbxO9B1l/AB35CPf6k78QfYbr+AK//Usc++sDRP/GPfoW158MYxbMJSa0EZNWEtOXEzOOIWZ6i5jlTmK2W4mh6xRzvkLM/QQx733E/PcSC04gFJ8Ti/wKOyGXEoudR6y4kVj898QStxMrW0isYjqxKpFY9T40P5pBrG4XsQZ8r/Gv4F/GMVpPJzasgNjwbcRGvkps1DJiHZ3ExlxNbBzOOR7fn/AusUkbiB22ntjUBLFpZcSO+AGxI98mNvNNYrNuIDa7g9ixcWJzfkpsLs593A+JzZtEbP41xE60Eju5idgpFxE7Fd8/bTOx0/G7zpKJnX0jsXM2EjsX51/wMbEL9hO7CN+9eDSxS4uJ/QivXX42sSt2ELsK57lmGLFrZxG7Ht+/AffoplOJ3YJ7d+v5xH5qJ3b7EmI/n03sjpOI3bWA2N147VdPEbsHv+Ne/K77PyX22wix3+GePozXHplCbOH7xP6wmtiiY4gteYDYY3uJLbuM2IoYsVVVxFY7iK2FjNY3E9vwFbEnf0LsqS+IbcR1PnMWsc31xLasIrbtYWLP4bc8P4LYC63Edn1CbI+L2Et/IbYP9/vl14i9WkjsdXz3TZzrb4uIvXUPsX/i3ryD476P+/2hidjH84l9+gKxz3FN/zqX2Ne4T/8eR+zbHxNL4jcf+IAE9hIJ4kckyK+QoP+MBON9JJhPIcF6CQn2n5LgHE2C+1gSvHeS4F9EQvAYEsLzSIj+moTCPSQUPUFA5JNQeioJ5ctJqLyDhOrHSajFa3U4fgPeb7qNhJYWElrvIWHYhSQMT5IwsoqE9n+R0LGahDE3kDBuHQkTfkvCJHznsOdJmHoSCdNcJByhI+FIvDfzfBJm4dpm49hzJpFw3P0kzJ9Gwok4xiljSTj1eBK+i++eMZuEs64i4WwzCec0kHDuESQs2EbChYeT8MPvknAJI+FH40i47BkSrgyQcPX3SLh2MgnXPUjCT24m4ca/kHDzlyTchnPcju/+fDgJv8B7d+LafonXf/UhCffg2Pd9Q8KDx5Hwux+S8PBiEh7BdTx6Bgl/WE/CYg8Jj80nYdnLJKy4gIRVM0lY/RsS1uL86+8l4YlLSXhqCQkb/0HCs2NI2GIiYRuuZTvO/ae/krATn3vhTRJ2LyVhz0IS9skk7N9BwivDSHh1Awmvv0HCmwtI+Bvu5Vu4V/84l4R3fkTCe9eT8MEuEj4eT8KnG0n4wkLCl9eQ8DXu8X8KSejE7zlwBYnsScKWFYm6DSQaNpNoPoZEy/Uk2n5EomMiia5KEt27SfS+TqJ/NYnBO0gM309idDKJhZeTWPQCifHTSCz5B4mlU0gsF0is+ILE6jCJNY+TWFdCYn0niU1tJDZfR2LLlyQOm0niCLCetUdJHIVjjr6ZxLE45vj9JE7EMSeXknjYNyROfYrEaT8h8YhqEo/8E4kzV5A4600SZ68l8dh1JM49msTjQcI4/0oST3yAxJPfIxG2QPzueBJPx3HOxPfOwvfOXkPiOc+TeO4FJJ6H853/HRIvjJD4QyOJl2BciuNedjiJV5xK4pUfkXhNAYnXjiPxuqkkXv8WiTfgXDdtJ/GWU0i8Dee7fSSJP1tF4i8uJPEu/I67gbT61SYSf/MMifdNIvEB3JPfzSPx4eUkLqwh8Q+4j4vwW5YsIXEZSiuW41irUAK8+vskrt1G4vqXSHzSQ+LT7SRu+i2Jz+I6NydJ3Ir7uv13JP7pVhKfx/17Afd219ckvgj5vPQgiftA8fEyzv/npSS+imt9/VwS3zydxL+dT+JbbhLf3kriP2eQ+M4uEt/H7/zgYxI/WkniJ78m8TP8ri/uJfHLG0j8Gsf9t4nE/0BenbiXB8bBNXqHJOEBkqTbSdItIsnwLknm+SRZjyTJfjZJTnTNcJ9CkhdtVPwTSAquJin0PEnhf5MUvYqkwh+SFNtGUtEXJMVfIilxD0llJ5NUcQlJVfg81g6p9hyS6l4gqaGepMZbSWrGey2vkNR2PknDsSE94gKS2jE6cD1j5pA07lqSJvyBpMktJE2xkjT1CJIOxzmnYRzhJunIn5E000XSUe0kHf0xScfMJenYJ0iau5Gk4+eRNB+fP3EqSSfju9+ZTdJpTpK+exZJZ7SRdFaEpLPRU/icEEk/wG9YcDxJF/yYpIs+J+mSn5D0oxtJunw4SVfiO1cbSfrxZJKubyIJuiHdtJikWx4l6badJP2sgaSfv0bSnVNIugvX9as9JN0zmqT7VpH0wOMk/c5C0sNnkvSIg6RHcc4/VpK0GOd/DPd5OY67AudehbEGx1v3I5I2bCLpyQ9Jehp/bzqGpGdrSdqC+7EN9+K5f5K0A2PnSpJ2Qw57TiJpL+7X/vtIeuX7JL2Oa30D5/krrv3vkN3bV5L0z1+T9C5k8T7u44e4Dx/h+J/8nqTPjiLpi9NJ+hfO9dWLJH2zn6RvgTVJDiPpwBcks49JlspI1rlINhxHsjlAsrWFZPuPSHZ+SbIHbdF9PyE5MJ7k0C9Ijk4nufAukovxmZLJJJceS3L5oyRXOUmuOZzkOjxvOInkZhyvdRPJw04lecQPSG6/huTRo0gei++Pv4XkSaeQfBjG1GtJnnYOyUe8SvKM/STPMpI8G8c49hiS57aTfLyV5Pn4zgl/Jfmkf5P8nUtIPq2U5NPR2+GMJ0n+XiPJZ39C8jkY5/lJPh/nuOAPJF+Ec/5wNcmXnE3yj+4m+XI3yVfsJPmqE0i+Br/z2u+RfP2ZJN+Av2/Cb72lmeTb5pB8+wySf34RyXfMJvkuHOvuC0j+zTCS7x1H8v3Pkfzg9ST/7nySH76f5Edw/x59jeQ/3kzy4ttIfuwqkpeFSV5hIHlVK8mr8dvW1pG83oJwBMd6ajHJG/FbnsF93Yy/t75P8nMLSN5xgOSdm0neXUXyHvzOfVNJ3v8iyX++kuRX95L8+haS35hJ8l9xf//+HZLfdpD8j++T/E6U5HdvJ/n9D0j+8CuSP8bv+PRCkj/Hb/7iW5K/+inJ39xB8n9w3Z3nknzgRALskoD7JZ30Mun0o0hnnEQ688Wksx5GOvt60jneJJ3rdNJ57iOdr4B0ATPpQox04S9IV9BIusK1pCuqJl3xl6Qr+Q3pSv9JunIct3Iu6aoeJl3NWNLVHk66un2ka8BrTRHStUwhXVsH6YZtJt2IHaRrH0e6UZ+TbvQFpBtbQbrxemUwJcIb95Cp/vwT7fAbwuI7PLB74fHxR/PHv+78+pMDXx2wiaeI8NUJPoMaDwov0CRWhrGeJoiTaJKwgMpBjdQkJGkMO5l+wGbTBHYcNQvDqV4oogoWpUL2Cgoft1GCvUFlwqlUzn5DTmEK/ka2VLiASoWxGGdRuTAfz7F9IUzH59+lNkrC847TWEGkGqEAx2ymdnEBtQjr8dkajLOoQjgJjwmMGMbJlMAoZwFc17lkxDXw18uE5Xg8D4+XYEzB3z/B42w8noTz/hiPl2L8lsrEKB4vxHvfw+DH+TPdyq8Zj5PYXkJmn0YIo/H8Nfyunfg9f8bf/6E4uxOf/QTP9+O69+HvB6iYLcTfeI7rqGDv47EKn/sA732E77yD17bgNQSm7EOcy4G/78ejiOspwWf+qZx7MjubLmHv0hhE2TWsmq7HOEYcSw4MJ8ZEFJTaxGNJj6HDsIjTDnSqz/E4C+NEvDYLo4MkMaE82sRCsgJJ7hcj+LuGfGIR2ZW/+Wc6KIb3Up9TRys+G6cKsYq8yuvVBO7WHEOPazoRowOku9OoEMgoD+6nW/iCzGIL/u4+PDiXB+fvwODPzRhejIj2yAc/XwwjogwLYD5+nN+GRyvOAdcGx+ZjGsZE7fEI5TX+W+AmkUn5XgcZ8D2XcuwIvqs+2sTZ/DcdOIC/Q/hMOGO4cT2O9PWkhlu5pjiORXgcj9GA0YhRrz029DIa0fShCo8j0yMCfVOPMVL5vpuG4T6PEgtoOM47SQxC1yvxehDzq4yq8V4DXh+O99vxdwe+4+1FDlxOXA6Fyj1N3e9a3Aev9hscynOXGMC5GY7dQU3dfkuF9rf6myal31Nft1GBaMLxnVQgvIfRiXEAryERI3yLR71yzY1iE47dm77wMUu7ztT1unHt5m56wvWjHo/lGTrizaErfPgwQrhWP8VBJl4A9vcC/qhde7MyZlMlHmsUXa/Do6T8FrSRw7BixDFiynfKlc9kXn/qmkbhdW+Wnhbht1RC9yrF46g0/TcfM5XzNSj3tZiK8VsqIddKHLcSc6sSc6Acr5Xi95XxzYj0dWaOGtz37veR37PUvep+XxLdnjMKYhWKQm5RyCaK64hijlTgXsRxfXFxDgb/+zjtcZY25mF0QC99uB8RbZRgFGAEtfvk157rID/+XpE2+pK7OYc96JJ3TNOzCuVzSNphV60cv6NceezAHFB1NHMUa6P7a60YI7TB59oEjDHaY2vG66nX1Pe7rj2Udd0n457Pxu9swEh0m1/ZvyEMPazHNdfDhtbisQy6XYFRhftdhvtajWPxeVeijDn4O4HXKzEC3e5VvNv94vIcrtgOB4ZJG2bYsa8znptwjU4c0wzZeMQwBYWPsC4YSQ9iXj10Hm2bMCx4/g0eOxT7x+2GF/PXBPvAXwtk3Adnlt55+5BfSoZ+DIM2n7vNVVBfmvhQzo/rwTkdwtc4px+jGMefg/dmwgbPgR618t+WYevMGfchddwOSuA1s2bHmjT94XYrmh5TFb0KifPxeFLGaMJ3q3E/Z8LO8DEXYyp++3TlntRBfpWaTmaORI/X6hQ7xv+uUs5fiXnbln6/Nuuzrd0e+XlUfc2e55aMv+fhvvB19QiMqRjTMuxmdT9zSz3HyAybXqiNWM772WXXwljDq7Tvl2q/Qx116d+afR8mHUjifou4fxZcp1U8FWv2dIzZGPMx1HXHyn0D3Fs35jfXTzdk78b3XRhRDA/unU2xq9XaetXdhszPsH+925Gm9GNE8UesuKdu/DY3bKEbNswN2+aGvVJHVHucDV3ivsF8yGQuHqcruuXS5khhxqM7p51LXVeJdh1eZc2oSN/3Bu1xOo4zE7o2W9G3rsepyvsBZQzDKFLuSbXie4zFo0fxUapx/wLaMdX3qzPmqBXX1nU/3Ol7wq8lpszBANbHgPAuxn8gF/V8UeU3jYC/5IX+RzHUtUSVTUKbh1btPDMzbGDmGlQNn9KhvOZX7vN06NxJmI8nYZ6dpNiuJhw7gXUv02eqyNAv9fXMe8u63dv2jDU4kX5shLzMkFsCepcQx+F3qLbNrc3ZRI7nifR59NpxuutV6rdxX9SlfNeD4wfxW0LiGXjko0nxGULK4O8NV2QUTI86vF+vvK8+b4Cd4ec1QFYG2HKDsrY4ce0RPEZwbyOKPKq1a+D+j0t7FDKu0dxt3U90e16urCGp8/J1MYg4Qt3rix0YRv8W30Gc95p4Svf9PkRakhhniHgR9d0kzMFLh6uP7ARqxP+y/7HMr4+bHovR0xTbf7d2jrPo49SOIlsqYHeFYogoSRkwAYCPiMq7HuTDNmBP8T1s9BjpPXzqRLoiFi3VlZ62iC2SFhkWORd5FwUXRRbVLTpv0QWLLl509aIfL7pl0e2LHlj06KK1i55YtHHRs4veXPTWoncWfbro80X/WvTtYlrsXPz9xecuvmDxRYsvX3z14lsW37746cVvLv568bdLaIlhiXlJ/ZLmJcOWjFkyfsnUJdOXzFgyf8mJS05ecsaSDUueXfLCkpcfq3ms+bH2x8Y/NuWxqx5b+9iGx55ealk6YelhS6cunbb06KXzl1629O6lv156z9IHlz669LGlK5euWbph6falu5a+ufTtZcZljmXBZSXLypdVL2tbNmbZhGWzl1287LJlVy27Ydmty+5YtnC5tNyw3LI8tvz25Xcsv3v5ouXblr+8/O3l7yz/YPlHy/+1/Kvl36xgK7wrZq+Ys+K0FWeuOGfFuSs2r9i2YseKvSv+vOLblY6VgZWRlbGVM1YevXLOytNWnr3yoZWrV76+8s2Vb638cOXHKz9d5VkVWFWyqmxVxaqGVWNWTVw1bdWMVQ+uemjVwlV/XLVy1YZVux53Pp54/N7HH3r8k9Xlq+tWj1x9+eqrVl+7+pbVP1t99+o/rv5g9SerO9ewNYY1JWvK17SsGb5mzJr5a05ac96apWveXTtn7YVrL1572dpr1/5k7W1rF69dunbD2qfWbl+7Y+3OtbvX/nntq2v/svattd+sG76ufd2YdYetm77u6HVnrjt33QXrrlv3k3WPrvvjuqXr1qxbv+6J9a3rh61vX9+xfvr6GevnrD95/dPrv95AG5wbfBsCG6IbEhsqNtRsaNgwZcO1G27YcMuGOzc8sGHhhg0bnt3w/IbdG/Zu+NeGrzd8+4T8hOOJkidmPDH3iaufuPaJG5+484lfPTnhycOenPbksU/OffL4J09+8ownL3vyp08ufHLXU4anxj512FMzn1r61I6ndj312tNznr796cVPL3165dNPPL3x6e1Pv74xujG2sWRjzcaGjcM2jtl4+MajN56x8dyNt268feMdG+/Z+Oam4KbIptim8k1Vm2o2NW46e9MFm67c9NCmhZsWbVq1ae2m1ze9uemtTR9u+njTl5u+eYaecT9z5jN/fuaNZ0979tNnv95s2VyxuXrzyM0TN0/dPG3z3M0nbD5p8+Wbr9p86+afbb5z892bV21eu3nD5mc3b9+8c/OuzS9t/nDzJ5u/2MK26LYYtkS2lGwp31K9pWlL25bhW8ZumbBl9pZ5Wy7bcueWR7cs3bJyy5otT295ZsuOLbu2vLTlzS0fbPlmq7Q1trVka/vWMVsnbJ22debWOVsv3Hrx1su3Xrf1pq23bf3Z1ju23rX17q0Pbn1466JttE3aZtjm3ObdFtkW21a3bdi2advO23b1tuu23bKtczttl7Zbtzu3B7ZXb5+x/ejtt2/fuP3Z7du2796+Z/ve7a9sf337P7d/uP2b56Y/N+O5k5+79rknnnv2ud3P7fnTlD/N+NOpf3prh3WHZ0fRjood9TuG7ejYMXHH3B2/2nHPjgd2LNzxxx2Ld6zcsWvHW88bno8+P+/5O5+/5/mHnn/0+aU7W3bO2Tlv50k7z9j5vZ0X7Lx457U7b995x86Hdr79QuSF+hdmvzDvhVNfuPiFN1/4166zd52767JdD+9auGvRro27nt21Z9fru+t3D9s9cfe03TN2z999xu7Ldj+4e+HuZbtXvVjz4lUvrnlxw4tPv7jtxU/2WPY49nj2lO8ZuefyPdfu+dWelXvW7NmwZ/ueD/d88tK8ly5+6aqXbnjp1r3SXsPe9r0T9s7ZO2/vSXvP2Pv9vRfsvWHvw3u3731576t739pH+7z7IvuG72vfN33f7H1z9s3bd8u+hft27Htz3zv7g/ub90/ZP3P/0fvn7j9p/2n7z9x/9v4b9t+y//b9dx84oFjEIjo5FimVYetIsXWORR7YujBs3bmwdT/MsHULYes2pG3dP7Ns3dmwdef3aevaNFs3DbZuXjdbV51h69Z0s3WzMmzdA0sXLv2jZuu2abbOAFsX6NXW/fz/2rvXqCiuOwDgW5Yipho1oUaRUk6iJxhm9jk7zM5cnNndeeywszOzM6tIDhoNYhCaEhUSLWiMmpQKNUHThAYl1Ee1xdZHMSEFWzRSSeoJ2pIcbSBGIBqNGpOY1DYgvQxbwiMkp197vF/mP3fvubtnP/z27L33/58xrOuG1n0Erfus37pDfdC6MLRuScS644Z1bd9gXTu0rqvuygjrbIPW1Qxa1wCtmzzCupKIdc8OWtdTb6ofZ1iH1RPQuqyIdR9C6wqHWLcvYl2LYd0pw7oOwzria63bO8Q6bLR1DX3Qujho3YzGmYZ1tjGtu2FYFz1o3TpoXeko6xYNs44ZZd2+pv3QukZoXQu0LiFinXWYdeWD1k37RuvaDeuuDLEu17BuyfHrhnXJhnVssx9al2FYVzLEurrm+uYGaN1fItZd6beuucewbsYw6xhoXdiw7vn/wbpCaF3JiQ0nSqF1z0Wsqxli3eRh1j3Wsg5aV9bSY1g3YZh1TYZ1pwzrzr7Rblh3800pYl1jxDp/xLoJhnX3G9alnWRPzj9ZOYZ1z3+rdd1jWLfLsK7JsK59lHU1EeuQMawrGWbdlW+17qfQupZB6+KgdYRhXXiEddMM61Ro3fzR1plDfe/3nXsfnuk62xvODi8OLwxnhOeGtXAoTOt9eq/+pf6Z/ql+Wb+on9FP68f0Jv2I3qDX6Nv1Kn2rvkWv0Mv0Un2Vnqgn6PH6dP1ufbIeo5u1Nu2wVq1VaZVahfaslq/laku1h7QFWoY2TwtroubXBM0Tuha6GOoIvR1aHyoJFYUKQnkhTO1Vv1Rvqr9TH1dXqivU5Wq+mq1y6gPqbDVZnaX+UE1U49V71Dh1vGpWbijXlbeUFuWo8qpSpxxU9igvK9uUciVPeURZoixQMpW5ile+KHfL5+W35IfkLDlT5uUUOUGeIk+SJ8oT5Fh5nBwjfyd4LXgg+PvgzmBNcFuwKugP8kFfEATdwXuC0VKv9G/pn1KL1Cwdk16RDkirpUckn+SRaImQUiVcipOmSDFStGQO9AY+DnwU+CDQGdgaqAhsDpQHNgbWBvIDSGB6+o70bemh9Pj0uPTx4hviCfG4eERsEA+LO8VscZE4V9RFWXSKNnGWeJ/4AxFujviv+w/5i/0ThU+F68JV4YLQLbwnHBX+LNQJh4TfCnuFPcKvhZeFamG7UClsFHiBFTwCKeCCTUgQpgp3C2Yhiu/kz/Md/Dt8G/93fgGfxWfy8/l03s97eDf3LreLq+Y2c+VcGfczbgO3jlvDFXNLuAe4+7mZXAJ3F/c99ib7CXuJvcB2sc3s62wT+xq7n93GLmeXsT7Ww85hnazN94xvg2+d73Ffka/Q95gvz5fh43yoL8bb6q30bvFu8iLeKd47vWZPqSfkwT0uj8OT4kn23OuZxJxmWpmTzHHmdeYI8wqzj9nFVDCbmALmUSaPyWaS6Ev0Rbqb7qDfpf9Bv0Nvp1+gy+lcOod+mH6QzqBdtJO20bPpZPpeOomOp2Pn1M3h5jBpjWmONCRtOrgFesA1cAF0gy5wFrwN2sBr4FVQC/aC3WAnKAXPgKfBWrAGrAarQBFYCLJAJtCADIKAAhiwAwtIBrPATJAIEsBEMI76kDpN/Ymqpw5Th6ha6jfUr6hqqop6jnqaWk0VUGEqRJFUKoVRKDWbuo+KpWIoM3mL7CH/Rd4kvyA/J2+QV8nLZDdZQW4my8iN5FNkMbmKzCMfJhUSIRPJGeRU9x73bvcOd5W70r3F/aQ7y53pTiQ+Jq4Sl4kuopM4T7xHdBBtRCvRTKwklhOLCZqIJaJSv0j9PPWp1OLUXPwSfgxvxA/gtfhuvBp/Cf8FvgHncB/O4G54dBfHbfj38SjXOddfXT93zXOpLtHFuWisAfsl9gK2FSvHNmHrsSexQmwZthTLwKY5O52tzlrnbme1s8w50znZ8ZLjRUe5I8eR7VjkCDoCjjSHy95lb7efsr9pP2FvsB+0V9uL7UX2R+15thu2HbZ8W64tx7YQ1o1OsMEn3drM1k+sB6211heta6w/sT5hzbeKVsHSbjlq+aPlD5b9FrcFt5jRHvQSegHtQtvRM+jf0CZ0F7oeLURXoHmoggIUR2eg09HxqBluxd1CWpE6pAJZizyB+BELEo/EIXchk5DxyHeRKMSU8kFKZ8q5lDNf/aOO7jTdbrfb7Xa7/b+2xSZ4Jh9mDjzYv5IXDc+6w/InpkgMT7TAu4E4ynQnTLgaiM2wXMzSSBxtmgrrSQ7EcN8NJpYMxDGw/xjMESqAT4FeDVNOlsFCErkwrzEJrkDaTHYTAaMw7MmBVy9MOk+CBWjmmjzw2p+gUgCrVOaYso3xHliAqRCOLID9K+GoIviZNfhqf2GmH8F4BZzNAufsn5WCcwTgI0VkGA2MREeMHehNGtE7D971z74MvsuP4atfzfj1swysfsLWd3jUimpkXRWeKu4zTTJ+S+4wwR1YeOqbl8KmWCPxwmSsHPw3W+MO0wT47RrtP73frZM="
