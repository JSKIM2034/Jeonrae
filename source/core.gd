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
