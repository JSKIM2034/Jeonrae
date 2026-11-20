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
	restart.text = "처음부터 다시 하기…"
	skin_button(restart, make_round(Color(0.93, 0.78, 0.72), font_size * 0.35), Color(0.55, 0.18, 0.12), 0.75)
	page.add_child(restart)
	place(restart, 0.22, 0.74, 0.78, 0.81)
	restart.pressed.connect(func():
		close_settings()
		ask("", "어디부터 다시 할까요?\n• 이 장만: 지금 장 이야기만 처음으로 (엽전·물건·다른 장은 그대로)\n• 모든 장: 1장부터 새로 (도감, 엔딩 기록, 설정은 남아요)", ["이 장만 처음부터", "모든 장 처음부터", "그만둘래요"], func(i: int):
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
		"stack":
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
			for k in 5:
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
			ci.draw_circle(center, short_side * 0.14, Color(0, 0, 0, 0.18))
			if fd != "" and ft < 0.45:
				draw_arrow(cg_draw, center, fd, short_side * 0.1, Color(1, 0.86, 0.3) if cg["phase"] == "show" else Color(0.7, 0.95, 1.0))
			var seqn := (cg["seq"] as Array).size()
			for k in seqn:
				var px := W * 0.5 + (k - (seqn - 1) / 2.0) * font_size * 1.1
				var done: bool = cg["phase"] == "input" and k < int(cg["input_i"])
				ci.draw_circle(Vector2(px, H * 0.72), font_size * 0.3, Color(1, 0.86, 0.3) if done else Color(1, 1, 1, 0.35))
			ci.draw_string(font, Vector2(0, H * 0.79), "보여 준 순서대로 손가락을 휙휙!" if cg["phase"] == "input" else "화살표 순서를 잘 봐요", HORIZONTAL_ALIGNMENT_CENTER, W, int(font_size * 0.85), paper)

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
