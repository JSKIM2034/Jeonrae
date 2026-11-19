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
	# 2장: 해와 달이 된 오누이 (엄마와 오누이는 전용 모델이 오면 바꿔요)
	"mom": {"base": "vil_woman", "scale": 1.2, "top": Color(0.97, 0.93, 0.82), "bottom": Color(0.45, 0.55, 0.45)},
	"oppa": {"base": "vil_child", "scale": 1.25, "top": Color(0.72, 0.84, 1.0), "bottom": Color(0.62, 0.62, 0.66)},
	"nui": {"base": "vil_child", "scale": 1.25, "top": Color(1.0, 0.86, 0.5), "bottom": Color(0.92, 0.42, 0.45)},
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
