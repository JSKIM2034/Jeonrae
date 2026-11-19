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
