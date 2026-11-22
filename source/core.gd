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
				ci.draw_string(font, Vector2(gx - 26, ty - 44), tr("흥부") if key == "saw" else tr("첨지"), HORIZONTAL_ALIGNMENT_LEFT, -1, int(font_size * 0.5), INK)
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
		"name": tr("돌이"),
		"ask": [[tr("돌이"), tr("으아앙! 놀부 아저씨가 내 엿을 뺏어 먹었어!")], [tr("돌이"), tr("엿 먹고 싶어... 장터 아저씨가 파는데...")]],
		"wait": tr("훌쩍... 엿은 장터 아저씨가 팔아."),
		"done": tr("우와, 엿이다! 고마워! 이제 안 울게."),
	},
	"suni": {
		"name": tr("순이 엄마"),
		"ask": [[tr("순이 엄마"), tr("놀부가 빨랫줄을 끊어 놔서 빨래가 개울가에 다 흩어졌지 뭐니.")], [tr("순이 엄마"), tr("개울 따라 세 장만 찾아 주겠니?")]],
		"wait": tr("빨래는 개울가를 따라 흩어졌단다."),
		"done": tr("아이고, 다 찾아 왔구나! 고맙다."),
	},
	"kim": {
		"name": tr("김 서방"),
		"ask": [[tr("김 서방"), tr("놀부가 다 익은 호박마다 말뚝을 박아 놨지 뭐냐!")], [tr("김 서방"), tr("말뚝이 보이면 재빨리 눌러서 뽑아 다오.")]],
		"fail": tr("말뚝이 너무 깊이 들어갔구나. 다시 해 보자."),
		"done": tr("호박이 살았다! 고맙다, 얘야."),
		"game": "tap",
		"cfg": {"title": tr("호박에 박힌 말뚝을\n사라지기 전에 눌러 뽑아요"), "goal": 8, "interval": 0.9, "life": 1.9, "target": tr("말뚝"), "center": tr("호박"), "color": Color(0.95, 0.6, 0.2), "art": "world", "world": true, "scene": "kim"},
	},
	"ong": {
		"name": tr("옹기 할멈"),
		"ask": [[tr("옹기 할멈"), tr("놀부가 지나가다 장독을 발로 차서 금이 갔단다.")], [tr("옹기 할멈"), tr("진흙을 살살 돌려 발라 주겠니? 세게 하면 또 깨진단다.")]],
		"fail": tr("에구, 금이 더 갔구나. 다시 살살 해 보자."),
		"done": tr("감쪽같구나! 장맛을 지켰다."),
		"game": "circle",
		"cfg": {"title": tr("깨진 장독 둘레에\n진흙을 살살 돌려 발라요"), "label": tr("장독"), "turns": 5.0, "max_speed": 10.0, "warn": tr("너무 세게 바르면 깨져요!"), "color": Color(0.5, 0.33, 0.2), "art": "world", "world": true, "scene": "ong", "trail": Color(0.66, 0.48, 0.3)},
	},
	"park": {
		"name": tr("박 첨지"),
		"ask": [[tr("박 첨지"), tr("놀부가 제 논에만 물을 대려고 우리 물꼬를 막아 버렸어!")], [tr("박 첨지"), tr("나랑 박자 맞춰 삽질 좀 해 다오.")]],
		"fail": tr("박자가 안 맞아 삽이 엇나갔구나. 다시 해 보자."),
		"done": tr("물이 콸콸 들어온다! 올해 농사는 살았다."),
		"game": "follow",
		"cfg": {"art": "world", "world": true, "scene": "ditch", "title": tr("박 첨지와 박자 맞춰 삽질!\n아래 손잡이를 좌우로 따라가세요"), "slow": 2.0, "tol": 0.4, "goal": 5.0, "patience": 4.0, "color": Color(0.4, 0.6, 0.85)},
	},
}


# ---------- 시작 ----------

# ---------- 언어 (한국어 / English) ----------
# 브라우저나 기기 언어가 한국어면 한국어, 그 밖은 영어로 시작해요. 설정에서 바꾸면 user://lang.cfg 에 남아요.
const LANG_PATH := "user://lang.cfg"

func lang() -> String:
	var cf := ConfigFile.new()
	if cf.load(LANG_PATH) == OK:
		var l: String = cf.get_value("lang", "code", "")
		if l != "":
			return l
	var sys := OS.get_locale_language()
	if OS.has_feature("web"):
		var nl = JavaScriptBridge.eval("(navigator.languages && navigator.languages[0]) || navigator.language || ''", true)
		if nl is String and nl != "":
			sys = nl.substr(0, 2).to_lower()
	return "ko" if sys == "ko" else "en"

func ensure_lang() -> void:
	if Engine.has_meta("jr_lang_ready"):
		return
	Engine.set_meta("jr_lang_ready", true)
	var t := Translation.new()
	t.locale = "en"
	var en: Dictionary = preload("res://lang_en.gd").EN
	for k in en:
		t.add_message(k, en[k])
	TranslationServer.add_translation(t)
	TranslationServer.set_locale(lang())

func set_lang(l: String) -> void:
	var cf := ConfigFile.new()
	cf.set_value("lang", "code", l)
	cf.save(LANG_PATH)
	TranslationServer.set_locale(l)
	leaving_scene = true
	get_tree().reload_current_scene()

# 표 안의 글자만 지금 언어로 바꾼 사본 (id 같은 키는 그대로)
func trd(v: Variant) -> Variant:
	ensure_lang()
	if v is String:
		return TranslationServer.translate(v) if v != "" else v
	if v is Dictionary:
		var d := {}
		for k in v:
			d[k] = trd(v[k])
		return d
	if v is Array:
		var a := []
		for x in v:
			a.append(trd(x))
		return a
	return v

func _ready() -> void:
	ensure_lang()
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
		lab2.text = tr("지\n하\n여\n장\n군") if female else tr("천\n하\n대\n장\n군")
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
	lab.text = tr("지\n하\n여\n장\n군") if female else tr("천\n하\n대\n장\n군")
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
	show_card(tr("책장을 넘기는 중..."), 1.0, 30.0, Callable())
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
		say([["", tr("두 손가락을 화면에 대고 비틀면 화면이 돌아가요.\n벌리면 가까이, 오므리면 멀리 보여요.\n아주 가까이 당기면 하늘도 올려다볼 수 있어요!") if is_touch_device() else tr("마우스 오른쪽 버튼을 누른 채 끌면 시야가 돌아가요.\n마우스 휠로 가까이, 멀리 볼 수 있어요.\n아주 가까이 당기면 하늘도 올려다볼 수 있어요!")]], Callable())

func update_autosave(delta: float) -> void:
	save_timer += delta
	if save_timer > 5.0 and not mg_active and not is_busy() and chapter_id() != "":
		save_progress()

func _notification(what: int) -> void:
	# 마우스가 게임 화면 밖으로 나가거나 창을 벗어나면, 누르고 있던 마우스 버튼을 모두 뗀 것으로 쳐요
	# (화면 밖에서 버튼을 떼면 게임이 그 신호를 못 받아서 계속 눌린 것처럼 되기 때문이에요)
	if what in [NOTIFICATION_WM_MOUSE_EXIT, NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		release_mouse_holds()
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
const VILLAGERS_KO := {
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
var VILLAGERS: Dictionary = trd(VILLAGERS_KO)
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
	{"name": tr("쑥"), "hint": tr("마을 길가"), "reward": 5, "spots": [Vector3(-5.6, 0, 16.5), Vector3(8.5, 0, 24.5)]},
	{"name": tr("냉이"), "hint": tr("논 근처"), "reward": 5, "spots": [Vector3(16.5, 0, 35.8), Vector3(31.2, 0, 36.2)]},
	{"name": tr("달래"), "hint": tr("개울가"), "reward": 6, "spots": [Vector3(-27.0, 0, -13.1), Vector3(12.0, 0, -13.2)]},
	{"name": tr("도라지"), "hint": tr("개울 건너 숲"), "reward": 8, "spots": [Vector3(-14.0, 0, -27.0), Vector3(10.0, 0, -26.0)]},
	{"name": tr("더덕"), "hint": tr("깊은 숲 속"), "reward": 10, "spots": [Vector3(-33.0, 0, -31.0), Vector3(3.0, 0, -37.0)]},
	{"name": tr("산삼"), "hint": tr("아무도 안 가는 숲 구석"), "reward": 25, "spots": [Vector3(-36.5, 0, -36.5), Vector3(37.0, 0, -31.5)]},
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
	book_button.text = tr("도감")
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
	for tab in [["fish", tr("물고기")], ["herb", tr("약초")], ["story", tr("이야기")]]:
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
	back.text = tr("목록으로")
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
	close.text = tr("닫기")
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
		book_title.text = tr("물고기 도감 %d/%d") % [fish_kinds_found(), FISH.size()]
		if fish_kinds_found() >= FISH.size():
			book_footer.text = tr("다 모았어요! 강태공 할아버지도 깜짝 놀랐어요.")
		else:
			book_footer.text = tr("남쪽 연못 나루터에서 낚시해요.\n다 모으면 50냥!")
	elif tab == "story":
		book_title.text = tr("이야기 조각 %d/%d") % [story_count(), STORY.size()]
		for i in STORY.size():
			var sb: Button = story_buttons[i]
			if story_read[i]:
				sb.text = "  %d. %s" % [i + 1, STORY[i]["title"]]
				skin_button(sb, make_round(Color(1.0, 0.95, 0.8), font_size * 0.3), INK, 0.8)
			else:
				sb.text = "  %d. ???   (%s)" % [i + 1, STORY[i]["hint"]]
				skin_button(sb, make_round(Color(0.88, 0.84, 0.76), font_size * 0.3), Color(0.5, 0.45, 0.4), 0.72)
		if story_count() >= STORY.size():
			book_footer.text = tr("일곱 조각이 하나로 이어졌어요. 놀부는 어떤 형이었을까요?")
		else:
			book_footer.text = tr("찾은 조각을 누르면 다시 읽을 수 있어요.\n산신령에게서 받는 조각도 있어요.")
	else:
		book_title.text = tr("약초 도감 %d/%d") % [herb_kinds_done(), HERBS.size()]
		if herb_kinds_done() >= HERBS.size():
			book_footer.text = tr("다 모았어요! 마을 최고의 약초꾼이에요.")
		else:
			book_footer.text = tr("종류마다 3번씩 캐면 도감에 올라가요.\n캔 자리는 3분 뒤 다시 자라요. 다 모으면 40냥!")
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
	var rarity := [tr("흔함"), tr("흔함"), tr("보통"), tr("보통"), tr("드묾"), tr("아주 드묾")]
	for i in 6:
		var cc := Vector2(cw * (i % 2) + cw / 2.0, ch * (i / 2) + ch / 2.0)
		var got := false
		var name_t := "???"
		var sub := ""
		if book_tab == "fish":
			got = int(fish_caught[i]) > 0
			if got:
				name_t = FISH[i]["name"]
				sub = tr("%d마리 낚음 | %d냥") % [fish_caught[i], FISH[i]["pay"]]
			else:
				sub = rarity[i]
		else:
			got = int(herb_counts[i]) >= HERB_NEED
			if int(herb_counts[i]) > 0:
				name_t = HERBS[i]["name"]
			sub = "%d/%d  %s" % [mini(int(herb_counts[i]), HERB_NEED), HERB_NEED, HERBS[i]["hint"] if not got else tr("완성!")]
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
	auto_cam = cf.get_value("ui", "auto_cam", true)

func save_controls() -> void:
	var cf := ConfigFile.new()
	cf.load("user://save.cfg")
	cf.set_value("ui", "left_handed", left_handed)
	cf.set_value("ui", "walk_hint_seen", walk_hint_seen)
	cf.set_value("ui", "cam_hint_seen", cam_hint_seen)
	cf.set_value("ui", "auto_cam", auto_cam)
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
	settings_button.text = tr("설정")
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
	var title := add_label(page, tr("설정"), 1.0, 0.05, 0.04, 0.95, 0.17)
	title.add_theme_color_override("font_color", INK)
	title.add_theme_constant_override("outline_size", 0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub := add_label(page, tr("점프 버튼 위치"), 0.8, 0.05, 0.13, 0.95, 0.21)
	sub.add_theme_color_override("font_color", Color(0.45, 0.35, 0.25))
	sub.add_theme_constant_override("outline_size", 0)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var opts := [[false, tr("오른손잡이\n(점프 오른쪽)")], [true, tr("왼손잡이\n(점프 왼쪽)")]]
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
	again.text = tr("걷기 안내 보기")
	skin_button(again, make_round(Color(0.9, 0.84, 0.7), font_size * 0.35), INK, 0.78)
	page.add_child(again)
	place(again, 0.06, 0.645, 0.48, 0.725)
	cam_btn = Button.new()
	page.add_child(cam_btn)
	place(cam_btn, 0.52, 0.645, 0.94, 0.725)
	cam_btn.pressed.connect(func():
		auto_cam = not auto_cam
		save_controls()
		refresh_hand_buttons()
		sfx("tap"))
	var restart := Button.new()
	restart.text = tr("처음부터 다시 하기...")
	skin_button(restart, make_round(Color(0.93, 0.78, 0.72), font_size * 0.35), Color(0.55, 0.18, 0.12), 0.75)
	page.add_child(restart)
	place(restart, 0.06, 0.74, 0.48, 0.81)
	# 언어 바꾸기: 어느 언어 상태에서도 찾을 수 있게 영어와 한국어를 같이 써요
	var lang_btn := Button.new()
	lang_btn.text = "Language: 한국어" if lang() == "ko" else "Language: English"
	skin_button(lang_btn, make_round(Color(0.72, 0.8, 0.95), font_size * 0.35), INK, 0.75)
	page.add_child(lang_btn)
	place(lang_btn, 0.52, 0.74, 0.94, 0.81)
	lang_btn.pressed.connect(func():
		sfx("tap")
		set_lang("en" if lang() == "ko" else "ko"))
	restart.pressed.connect(func():
		close_settings()
		ask("", tr("어디부터 다시 할까요?\n- 이 장만: 지금 장 이야기만 처음으로 (엽전·물건·다른 장은 그대로)\n- 모든 장: 1장부터 새로 (도감, 엔딩 기록, 설정은 남아요)"), [tr("이 장만 처음부터"), tr("모든 장 처음부터"), tr("그만둘래요")], func(i: int):
			if i == 0:
				reset_chapter()
			elif i == 1:
				reset_progress()))
	var snd := add_label(page, tr("소리"), 0.8, 0.05, 0.43, 0.95, 0.5)
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
	close.text = tr("닫기")
	skin_button(close, make_round(Color(0.75, 0.45, 0.25), font_size * 0.4), Color(1, 1, 1), 0.85)
	page.add_child(close)
	place(close, 0.3, 0.84, 0.7, 0.95)
	close.pressed.connect(close_settings)
	refresh_hand_buttons()

var music_btn: Button
var sfx_btn: Button
var cam_btn: Button

func refresh_hand_buttons() -> void:
	if music_btn != null:
		music_btn.text = tr("배경음 켜짐") if music_on else tr("배경음 꺼짐")
		skin_button(music_btn, make_round(Color(0.95, 0.72, 0.3) if music_on else Color(0.85, 0.8, 0.72), font_size * 0.35), INK, 0.78)
		sfx_btn.text = tr("효과음 켜짐") if sfx_on else tr("효과음 꺼짐")
		skin_button(sfx_btn, make_round(Color(0.95, 0.72, 0.3) if sfx_on else Color(0.85, 0.8, 0.72), font_size * 0.35), INK, 0.78)
	if cam_btn != null:
		cam_btn.text = tr("카메라 따라오기 켜짐") if auto_cam else tr("카메라 따라오기 꺼짐")
		skin_button(cam_btn, make_round(Color(0.95, 0.72, 0.3) if auto_cam else Color(0.85, 0.8, 0.72), font_size * 0.35), INK, 0.7)
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
	var msg := tr("화면 아무 곳이나 누른 채\n밀면 그쪽으로 걸어요") if is_touch_device() else tr("WASD나 방향키로 걷고, 스페이스로 점프해요\nE나 엔터로 말을 걸어요")
	var fs := int(font_size * 0.95)
	var y := c.y + r * 1.25
	for line in msg.split("\n"):
		ci.draw_string_outline(font, Vector2(0, y + fs), line, HORIZONTAL_ALIGNMENT_CENTER, sz.x, fs, 10, Color(0.25, 0.15, 0.08))
		ci.draw_string(font, Vector2(0, y + fs), line, HORIZONTAL_ALIGNMENT_CENTER, sz.x, fs, Color(1, 1, 1))
		y += fs * 1.3

# ---------- 이야기 조각 7개: 놀부는 왜 놀부가 되었을까 ----------

var STORY := [
	{"title": tr("담벼락의 키 재기"), "hint": tr("놀부네 담장 근처"), "text": tr("놀부네 담장 뒤편에는 희미한 금이 두 줄 그어져 있어요.\n어린 형제가 해마다 키를 재며 새긴 자국이에요.\n놀부의 금은 언제나 흥부보다 손가락 한 마디 높았어요.\n“형은 동생보다 커야 해. 그래야 지켜 줄 수 있으니까.”")},
	{"title": tr("첫 박씨"), "hint": tr("서쪽 개울가"), "text": tr("어느 봄, 아버지는 형제에게 박씨를 하나씩 주었어요.\n놀부의 박은 장맛비에 썩고, 흥부의 박만 주렁주렁 열렸어요.\n아버지가 흥부의 머리를 쓰다듬던 날 밤,\n놀부는 처음으로 몰래 이불을 덮고 울었어요.")},
	{"title": tr("흉년의 겨울"), "hint": tr("개울 건너 깊은 숲"), "text": tr("큰 흉년이 든 겨울, 아버지가 세상을 떠났어요.\n굶어서 우는 동생들을 보며 열다섯 살 놀부는 맹세했어요.\n“다시는 우리 집에 배고픈 사람이 없게 할 테야.”\n그날부터 놀부는 곳간 열쇠를 꼭 쥐고 잠들었어요.")},
	{"title": tr("높아진 대문"), "hint": tr("마을 남서쪽 집들 근처"), "text": tr("놀부가 부자가 되자 사람들이 줄지어 찾아왔어요.\n빌려 간 쌀은 돌아오지 않았고, 고맙다는 말도 없었어요.\n놀부는 대문을 한 자, 또 한 자 높이 쌓았어요.\n“베풀면 바보가 되는 거야.” 놀부는 그렇게 믿기로 했어요.")},
	{"title": tr("대문 밖의 쌀자루"), "hint": tr("남동쪽 논 근처"), "text": tr("흥부네가 쫓겨나던 날, 아무도 모르게\n놀부네 대문 밖에 쌀자루 하나가 놓여 있었어요.\n흥부는 이웃이 두고 간 줄 알았지요.\n자루를 묶은 매듭은, 놀부만 묶을 줄 아는 매듭이었어요.")},
	{"title": tr("제비가 본 것"), "hint": tr("점프해야 닿는 큰 바위 위"), "text": tr("강남으로 떠나기 전, 제비는 이 바위에서 쉬어 갔어요.\n그리고 보았어요. 밤마다 놀부가 담장에 기대어\n흥부네 초가 굴뚝 연기를 오래 바라보다\n한숨을 쉬고 돌아서는 것을요.")},
	{"title": tr("산신령의 말"), "hint": tr("숲속 연못의 산신령"), "text": tr("“욕심은 두려움에서 자라느니라.\n놀부가 움켜쥔 것은 재물이 아니라\n다시는 굶지 않겠다던 어린 날의 약속이란다.\n그 마음을 알아주는 이가 있다면, 높은 대문도 열리느니라.”")},
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
		ci.draw_string(font, Vector2(0, y - 46), tr("지금!") if inz else "", HORIZONTAL_ALIGNMENT_CENTER, w2, int(font_size * 0.9), Color(1, 1, 0.85))
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
			ci.draw_string(font, Vector2(w2 * 0.1, y2 - 18), tr("흔들림"), HORIZONTAL_ALIGNMENT_LEFT, -1, int(font_size * 0.6), Color(1, 1, 1))
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
			ci.draw_string(font, Vector2(gx - 26, ty - 44), tr("흥부") if w.get("scene", "") == "saw" else tr("첨지"), HORIZONTAL_ALIGNMENT_LEFT, -1, int(font_size * 0.5), Color(1, 1, 1))
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
			float_text(tr("퍽!"), cam.unproject_position(at), Color(1, 0.95, 0.7), 1.3)
		"kim":
			sfx("pop", 0.8)
			chips3d(at)
			float_text(tr("쏙!"), cam.unproject_position(at), Color(1, 0.95, 0.7), 1.3)
		"sparrow":
			sfx("chirp", rng.randf_range(0.9, 1.2))
			burst3d(at + Vector3(0, 0.2, 0), Color(0.75, 0.55, 0.35), 10)
			float_text(tr("훠이!"), cam.unproject_position(at), Color(1, 0.95, 0.7), 1.2)
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
			float_text(tr("둥지가 위험해요!"), cam.unproject_position(at), Color(1, 0.55, 0.45), 1.0)
		"kim":
			float_text(tr("말뚝이 깊이 박혔어요!"), cam.unproject_position(at), Color(1, 0.55, 0.45), 1.0)
		"sparrow":
			float_text(tr("벼를 쪼아 먹었어요!"), cam.unproject_position(at), Color(1, 0.55, 0.45), 1.0)
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
	{"name": tr("피라미"), "pay": 3, "w": 30, "hard": 0.1, "col": Color(0.78, 0.84, 0.9), "len": 0.85, "thin": 0.34},
	{"name": tr("붕어"), "pay": 4, "w": 28, "hard": 0.25, "col": Color(0.72, 0.64, 0.42), "len": 1.0, "thin": 0.48},
	{"name": tr("미꾸라지"), "pay": 6, "w": 16, "hard": 0.5, "col": Color(0.58, 0.5, 0.32), "len": 1.5, "thin": 0.2},
	{"name": tr("잉어"), "pay": 8, "w": 14, "hard": 0.45, "col": Color(0.92, 0.58, 0.3), "len": 1.2, "thin": 0.44},
	{"name": tr("메기"), "pay": 12, "w": 9, "hard": 0.7, "col": Color(0.38, 0.38, 0.34), "len": 1.35, "thin": 0.36},
	{"name": tr("금빛 잉어"), "pay": 30, "w": 3, "hard": 0.9, "col": Color(1.0, 0.8, 0.22), "len": 1.2, "thin": 0.44},
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

	turn_button = add_hud_button(tr("돌리기"), 0.03, 0.25, on_turn)
	place(turn_button, 0.03, 0.075, 0.16, 0.135)
	turn_button.text = ""
	var icon := Control.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	turn_button.add_child(icon)
	place(icon, 0, 0, 1, 1)
	icon.draw.connect(func(): draw_turn_icon(icon))
	# 손가락 닿은 자리에 보이는 조이스틱
	stick_view = Control.new()
	stick_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(stick_view)
	stick_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	stick_view.draw.connect(draw_stick)
	action_button = add_hud_button("", 0.28, 0.72, on_action)
	jump_button = add_hud_button(tr("점프"), 0.75, 0.97, on_jump)
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
	next_hint.text = tr("다음 >")
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
	var cols := {tr("밥풀"): Color(0.98, 0.97, 0.93), tr("주걱"): Color(0.82, 0.62, 0.34), tr("물"): Color(0.55, 0.8, 0.98),
		tr("돌"): Color(0.62, 0.62, 0.66), tr("구렁이"): Color(0.5, 0.66, 0.3), tr("장작"): Color(0.72, 0.5, 0.28)}
	return cols.get(name, Color(0.9, 0.8, 0.6))

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
			ci.draw_string(font, sp + Vector2(5, 24), tr("전래"), HORIZONTAL_ALIGNMENT_LEFT, -1, int(font_size * 0.55), Color(0.98, 0.92, 0.88))
			ci.draw_string(font, sp + Vector2(5, 46), tr("동화"), HORIZONTAL_ALIGNMENT_LEFT, -1, int(font_size * 0.55), Color(0.98, 0.92, 0.88))
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
		ci.draw_string(font, Vector2(0, paper.end.y + 78), tr("화면을 누르면 넘어가요"), HORIZONTAL_ALIGNMENT_CENTER, w, int(font_size * 0.75), Color(1, 0.95, 0.82, al))

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
	if current_lines[line_index][0] == tr("제비"):
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
	float_text(tr("+%d냥") % amount, quest_label.global_position + Vector2(short_side * 0.25, quest_label.size.y * 0.75), Color(1, 0.85, 0.3), 1.2)
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
		return tr("약초 캐기")
	if kind == "gourd":
		return tr("박 타기")
	if kind == "nest":
		return tr("둥지 지키기")
	if kind == "piece":
		return tr("살펴보기")
	if kind == "laundry":
		return tr("빨래 줍기")
	if kind == "hider":
		return tr("찾았다!")
	if kind == "bush":
		return tr("덤불 베기")
	if kind == "gate":
		return tr("이정표 보기")
	if kind == "wild":
		return tr("약초 캐기")
	if kind == "fish":
		return tr("낚시하기")
	if kind == "farm":
		return farm_action_text()
	if kind == "job":
		if t["id"] == "water":
			return tr("물 긷기")
		if t["id"] == "wood":
			return tr("나무하기")
		if t["id"] == "gam":
			return tr("감 따기")
		return tr("짚신 삼기")
	return tr("말 걸기")

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
		say([["", tr("빨래를 주웠다. (%d/3)") % laundry_found]], Callable())
	elif kind == "hider":
		node.visible = false
		sfx("good")
		burst3d(above, Color(0.98, 0.85, 0.65))
		hiders_found += 1
		say([[tr("동생"), tr("앗, 들켰다! 헤헤. (%d/4)") % hiders_found]], Callable())
	elif kind == "gate":
		on_gate()
	elif kind == "bush":
		if has_sickle:
			node.visible = false
			sfx("saw")
			shake(8)
			burst3d(above, Color(0.3, 0.5, 0.2), 24)
			bush_col.set_deferred("disabled", true)
			say([["", tr("낫으로 가시덤불을 베어 냈다. 안쪽에서 울음소리가 들린다...")]], Callable())
		else:
			say([["", tr("가시덤불이 길을 막고 있다. 낫이 있으면 벨 수 있겠다. (장터에서 팔아요)")]], Callable())
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
	cg_say(tr("준비!"), Color(1, 0.95, 0.7))

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
		float_text(tr("%d 콤보!") % cg["combo"], Vector2(mg_overlay.size.x * 0.5, mg_overlay.size.y * 0.5), Color(1, 0.8, 0.35), 1.0)

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
	mg_info.text = tr("%s %d/%d | 남은 기회 %d") % [mg_cfg.get("unit", ""), mg_count, int(mg_cfg.get("goal", 10)), mg_lives]

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
		cg_say(tr("시작!"), Color(1, 0.9, 0.4))
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
				cg_lose(tr("놓쳤어요!"))
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
		cg_judge(tr("헛손질!"), Color(0.85, 0.85, 0.9), false)
		cg_event("whiff")
		return
	best["done"] = true
	if best["bad"]:
		cg_lose(String(mg_cfg.get("bad_text", tr("앗, 손!"))))
		hit_stop(0.08)
		cg_event("bad")
		return
	mg_count += 1
	cg_combo_up()
	if bd <= R_PERFECT:
		cg_judge(tr("퍼펙트!"), Color(1, 0.88, 0.3), true)
		sfx("good", 1.1)
		hit_stop(0.05)
		shake(10)
		cg_event("perfect")
	else:
		cg_judge(tr("좋아!"), Color(0.7, 0.95, 1.0), false)
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
				cg_lose(String(mg_cfg.get("hit_text", tr("앗, 당했다!"))))
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
		cg_judge(tr("휙~"), Color(0.85, 0.85, 0.9), false)
		cg_combo_break()
		return
	if a["phase"] == "back" or (a["phase"] == "tele" and a["fake"]):
		cg_lose(tr("속았지롱!"))
		cg_event("fooled", a)
		cg["atk"] = {}
		cg["next"] = 0.7
		return
	if a["phase"] == "tele":
		cg_judge(tr("너무 빨라요!"), Color(1, 0.75, 0.5), false)
		cg_combo_break()
		return
	if dir != a["dir"]:
		cg_lose(tr("반대쪽이에요!"))
		cg_event("hit", a)
		cg["atk"] = {}
		cg["next"] = 0.8
		return
	mg_count += 1
	cg_combo_up()
	var quick: bool = float(a["time"]) < float(mg_cfg.get("window", 0.5)) * 0.45
	cg_judge(tr("퍽! 막았다!") if quick else tr("막았다!"), Color(1, 0.88, 0.3) if quick else Color(0.7, 0.95, 1.0), quick)
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
			cg_lose(tr("미끄러져요!"))
			cg_event("slip")
		if float(cg["shake_in"]) <= 0.0:
			cg["shake"] = "warn"
			cg["shake_t"] = 0.0
			cg_say(tr("흔들린다! 꾹 누르고 버텨요!"), Color(1, 0.6, 0.45))
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
				cg_lose(tr("손을 놓쳤어요!"))
				cg_event("slip")
				cg["shake"] = ""
				cg["shake_in"] = float(mg_cfg.get("shake_every", 5.0)) * rng.randf_range(0.8, 1.2)
				cg["step_t"] = 0.0
			elif float(cg["shake_t"]) > 1.2:
				cg["shake"] = ""
				cg["shake_in"] = float(mg_cfg.get("shake_every", 5.0)) * rng.randf_range(0.8, 1.2)
				cg["step_t"] = 0.0
				cg_judge(tr("버텼다!"), Color(1, 0.88, 0.3), true)
				sfx("good")
				cg_event("held")

func alternate_press(pos: Vector2) -> void:
	if cg["shake"] != "":
		return
	var side := 0 if pos.x < mg_overlay.size.x * 0.5 else 1
	if side != int(cg["side"]):
		cg_combo_break()
		cg_judge(tr("헛디딤!"), Color(1, 0.75, 0.5), false)
		sfx("tick", 0.6)
		cg["step_t"] = float(cg["step_t"]) + 0.35
		return
	mg_count += 1
	var quick: bool = float(cg["step_t"]) < 0.45
	if quick:
		cg_combo_up()
	cg_judge(tr("영차!") if not quick else tr("영차영차!"), Color(1, 0.88, 0.3) if quick else Color(0.8, 0.95, 1.0), quick)
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
			cg_lose(tr("휘청!"))
			cg_event("fall")
	else:
		cg["round_t"] = float(cg["round_t"]) + delta
		cg["gauge"] = maxf(0.0, float(cg["gauge"]) - delta * float(mg_cfg.get("decay", 0.22)))
		if float(cg["round_t"]) > float(mg_cfg.get("round_time", 2.6)):
			cg_lose(String(mg_cfg.get("lose_text", tr("쏙 숨었어요!"))))
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
			cg_judge(tr("균형부터!"), Color(1, 0.75, 0.5), false)
	else:
		cg["gauge"] = float(cg["gauge"]) + 1.0 / float(mg_cfg.get("taps", 9))
		sfx("tap", 0.9 + float(cg["gauge"]) * 0.4)
		cg_event("tap")
		if float(cg["gauge"]) >= 1.0:
			mg_count += 1
			var quick: bool = float(cg["round_t"]) < float(mg_cfg.get("round_time", 2.6)) * 0.55
			if quick:
				cg_combo_up()
			cg_judge(tr("쑥!") if not quick else tr("쑥! 빠르다!"), Color(1, 0.88, 0.3), quick)
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
		cg_lose(tr("툭, 떨어졌어요!"))
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
		cg_judge(tr("퍼펙트!"), Color(1, 0.88, 0.3), true)
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
		cg_judge(tr("탁!"), Color(0.8, 0.95, 1.0), false)
		sfx("land", 1.2)
		shake(4)
		cg_event("drop")
	layers.append([nx, nw])
	mg_count += 1
	var from_left := mg_count % 2 == 0
	cg["cur"] = [(0.03 + nw / 2.0) if from_left else (0.97 - nw / 2.0), nw, 1.0 if from_left else -1.0]
	if nw < 0.05:
		cg_lose(tr("너무 좁아졌어요!"))
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
		cg_judge(String(mg_cfg.get("lose_text", tr("다 올라와 버렸어요!"))), Color(1, 0.5, 0.42), true)
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
		cg_judge(String(mg_cfg.get("hit_text", tr("딱! 맞았다!"))), Color(1, 0.88, 0.3), true)
		sfx("crack", 1.1)
		hit_stop(0.07)
		shake(12)
		cg_event("hit")
		cg["shot"] = {}
	elif (sh["p"] as Vector2).y > mg_overlay.size.y + 40.0 or (sh["p"] as Vector2).y < -200.0 or (sh["p"] as Vector2).x < -60.0 or (sh["p"] as Vector2).x > mg_overlay.size.x + 60.0:
		cg_combo_break()
		cg_judge(tr("빗나갔어요"), Color(0.85, 0.85, 0.9), false)
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
				cg_say(tr("잘 들어 봐요..."), Color(1, 0.95, 0.7))
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
					cg_say(tr("이제 따라 눌러요!"), Color(1, 0.9, 0.4))

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
		cg_lose(tr("앗, 틀렸어요!"))
		cg_event("wrong")
		cg["phase"] = "wait"
		cg["show_t"] = -0.3
		return
	cg["input_i"] = int(cg["input_i"]) + 1
	if int(cg["input_i"]) >= seq.size():
		mg_count += 1
		cg_combo_up()
		cg_judge(tr("딩동댕!"), Color(1, 0.88, 0.3), true)
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
				cg_say(tr("잘 봐요!"), Color(1, 0.95, 0.7))
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
					cg_say(tr("이제 따라 휙휙!"), Color(1, 0.9, 0.4))

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
		cg_lose(tr("스텝이 꼬였어요!"))
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
		cg_judge(tr("얼쑤!"), Color(1, 0.88, 0.3), true)
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
					ci.draw_string(font, Vector2(x - r, y + font_size * 0.32), String(mg_cfg.get("note", tr("쿵"))), HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, int(font_size * 0.8), ink)
			ci.draw_string(font, Vector2(0, y + font_size * 2.2), tr("동그라미에 겹칠 때 톡! 빨간 X는 누르지 마세요"), HORIZONTAL_ALIGNMENT_CENTER, W, int(font_size * 0.8), paper)
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
			ci.draw_string(font, Vector2(0, H * 0.86), tr("공격이 오는 쪽으로 손가락을 휙! (가짜엔 속지 마요)"), HORIZONTAL_ALIGNMENT_CENTER, W, int(font_size * 0.8), paper)
		"alternate":
			var side := int(cg["side"])
			for k in 2:
				var rect := Rect2(W * (0.04 + k * 0.5), H * 0.7, W * 0.42, H * 0.16)
				var on: bool = k == side and cg["shake"] == ""
				ci.draw_rect(rect, Color(1, 0.86, 0.3, 0.75) if on else Color(0, 0, 0, 0.25))
				ci.draw_string(font, rect.position + Vector2(0, rect.size.y * 0.62), tr("< 왼쪽") if k == 0 else tr("오른쪽 >"), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, int(font_size * 1.1), ink if on else paper)
			if cg["shake"] == "":
				var lim := float(mg_cfg.get("step_time", 1.6))
				var left := 1.0 - float(cg["step_t"]) / lim
				ci.draw_rect(Rect2(W * 0.1, H * 0.67, W * 0.8 * left, font_size * 0.3), Color(1, 0.86, 0.3) if left > 0.35 else Color(1, 0.4, 0.3))
			else:
				var hold := 1.0
				if cg["shake"] == "shake":
					hold = 1.0 - float(cg["shake_t"]) / 1.2
				ci.draw_string(font, Vector2(0, H * 0.62), tr("꾹 누르고 버텨요!"), HORIZONTAL_ALIGNMENT_CENTER, W, int(font_size * 1.4), Color(1, 0.55, 0.45))
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
				var hint := tr("< 왼쪽을 눌러요") if tilt > 0.0 else tr("오른쪽을 눌러요 >")
				ci.draw_string(font, Vector2(0, H * 0.84), hint if warn else tr("빠르게 연타! 기울면 반대쪽을 눌러요"), HORIZONTAL_ALIGNMENT_CENTER, W, int(font_size * (1.0 if warn else 0.8)), Color(1, 0.6, 0.45) if warn else paper)
			else:
				var g: float = cg["gauge"]
				var c3 := Vector2(W * 0.5, H * 0.74)
				var rr := font_size * (2.2 + pulse * 0.25)
				ci.draw_circle(c3, rr, Color(0, 0, 0, 0.3))
				ci.draw_arc(c3, rr, -PI / 2.0, -PI / 2.0 + TAU * g, 48, Color(1, 0.86, 0.3), 14.0)
				var tl := 1.0 - float(cg["round_t"]) / float(mg_cfg.get("round_time", 2.6))
				ci.draw_arc(c3, rr + 14.0, -PI / 2.0, -PI / 2.0 + TAU * maxf(0.0, tl), 48, Color(1, 0.45, 0.35) if tl < 0.35 else Color(0.7, 0.95, 1.0), 5.0)
				ci.draw_string(font, c3 + Vector2(-rr, font_size * 0.35), tr("연타!"), HORIZONTAL_ALIGNMENT_CENTER, rr * 2.0, int(font_size * 1.1), paper)
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
			ci.draw_string(font, Vector2(0, H * 0.36), tr("움직이는 떡판이 아래 떡과 딱 겹칠 때 톡!"), HORIZONTAL_ALIGNMENT_CENTER, W, int(font_size * 0.8), paper)
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
			ci.draw_string(font, Vector2(0, H * 0.36), tr("아래에서 손가락을 뒤로 끌었다 놓아 던져요"), HORIZONTAL_ALIGNMENT_CENTER, W, int(font_size * 0.8), paper)
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
			var msg2 := tr("따라 누르는 중 %d/%d") % [int(cg["input_i"]), (cg["seq"] as Array).size()] if cg["phase"] == "input" else tr("조개 소리를 잘 들어요")
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
			ci.draw_string(font, Vector2(0, H * 0.79), tr("보여 준 순서대로 손가락을 휙휙!") if cg["phase"] == "input" else tr("화살표 순서를 잘 봐요"), HORIZONTAL_ALIGNMENT_CENTER, W, int(font_size * 0.85), paper)

# --- 갯벌 캐기: 여러 숨구멍 중 뽀글뽀글 거품이 오르는 곳을 찾아요 ---
# 바지락은 톡톡, 큰 백합은 빠르게 연타, 맛조개는 쏙 나올 때 위로 쓱!, 꽃게는 건드리면 따끔!
const DIG_KINDS_KO := {
	"clam": {"name": "바지락", "taps": 3, "life": 2.4},
	"big": {"name": "백합", "taps": 7, "life": 2.8},
	"razor": {"name": "맛조개", "taps": 0, "life": 1.1},
	"crab": {"name": "꽃게", "taps": 0, "life": 1.5},
}
var DIG_KINDS: Dictionary = trd(DIG_KINDS_KO)

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
			cg_judge(tr("휴~ 꽃게가 지나갔어요"), Color(0.85, 0.95, 1.0), false)
			if node != null:
				var tw := node.create_tween()
				tw.tween_property(node, "global_position", node.global_position + Vector3(1.8, 0, 0.3), 0.5)
				tw.tween_callback(node.queue_free)
		else:
			cg_lose(tr("쏙 숨었어요!"))
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
		cg_judge(tr("거긴 빈 구멍!"), Color(0.85, 0.85, 0.9), false)
		cg_combo_break()
		return
	if tg["state"] == "tell":
		cg_judge(tr("아직! 나오면 캐요"), Color(1, 0.9, 0.6), false)
		return
	var kind: String = tg["kind"]
	var node: Node3D = tg.get("node")
	match kind:
		"crab":
			cg_lose(tr("앗 따가워! 꽃게였어요"))
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
			cg_judge(tr("위로 쓱 당겨요!"), Color(1, 0.9, 0.6), false)

func dig_got(tg: Dictionary, hp: Vector3) -> void:
	var kind: String = tg["kind"]
	var node: Node3D = tg.get("node")
	mg_count += 1
	w["swing"] = 1.0
	var quick := float(tg["t"]) < 0.9
	if quick:
		cg_combo_up()
	cg_judge(tr("%s 쏙!%s") % [DIG_KINDS[kind]["name"], tr(" 빠르다!") if quick else ""], Color(1, 0.88, 0.3), kind != "clam")
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
		ci.draw_string(font, Vector2(0, H * 0.8), tr("뽀글뽀글 거품이 오르는 구멍을 봐요"), HORIZONTAL_ALIGNMENT_CENTER, W, int(font_size * 0.85), paper)
		return
	var hp: Vector3 = dig_holes()[int(tg["i"])]
	var sp := cam.unproject_position(hp + Vector3(0, 0.5, 0))
	var kind: String = tg["kind"]
	var txt := ""
	var col := paper
	match kind:
		"clam", "big":
			txt = tr("톡톡! %d") % (int(DIG_KINDS[kind]["taps"]) - int(tg["taps"]))
			col = Color(1, 0.95, 0.7)
		"razor":
			txt = tr("위로 쓱!")
			col = Color(0.75, 0.95, 1.0)
		"crab":
			txt = tr("꽃게! 건드리지 마요")
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
		if cfg["label"] == tr("제비"):
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
		float_text(tr("성공!"), mid, Color(1, 0.9, 0.4), 2.0)
		burst(mid, Color(1, 0.85, 0.3), 18)
		# 별점: 기회를 하나도 안 잃으면 별 셋 (덤으로 엽전)
		var lost := mg_lives_start - mg_lives
		var stars := 3 if lost <= 0 else (2 if lost == 1 else 1)
		float_text("★".repeat(stars) + "☆".repeat(3 - stars), mid + Vector2(0, font_size * 2.6), Color(1, 0.86, 0.25), 2.2)
		if stars == 3 and CUSTOM_GAMES.has(mg_type):
			coins += 5
			float_text(tr("별 셋! +5냥"), mid + Vector2(0, font_size * 4.6), Color(1, 0.95, 0.6), 1.2)
	else:
		sfx("fail")
		shake(16)
		float_text(tr("아이쿠!"), mid, Color(1, 0.55, 0.45), 2.0)
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
		mg_info.text = tr("%s\n남은 기회 %d") % [mg_cfg["warn"], mg_lives]
	else:
		mg_info.text = tr("남은 기회 %d") % mg_lives

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
		mg_info.text = tr("박자가 맞아요!")
	else:
		mg_b.modulate = Color(1, 1, 1)
		if mg_started:
			mg_off += delta
		mg_info.text = tr("갈색을 따라 좌우로!\n남은 여유 %d초") % int(ceil(patience - mg_off))
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
				float_text(tr("아야!"), center, Color(1, 0.55, 0.45), 1.2)
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
	mg_info.text = tr("%s %d/%d | 남은 기회 %d") % [mg_cfg["good"], mg_count, goal, mg_lives]

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
	mg_info.text = tr("%s %d/%d | 남은 기회 %d") % [mg_cfg["target"], mg_count, goal, mg_lives]

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
			float_text([tr("뽁!"), tr("쏙!"), tr("얍!")][mg_count % 3], at, Color(1, 1, 1), 1.1)
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

var stick_view: Control
var stick_alpha := 0.0
var auto_cam := true          # 걸어가는 쪽으로 카메라가 천천히 따라 돌아요

func draw_stick() -> void:
	if stick_alpha <= 0.01:
		return
	var r := drag_range
	var a := stick_alpha
	stick_view.draw_circle(touch_start, r * 1.05, Color(0, 0, 0, 0.18 * a))
	stick_view.draw_arc(touch_start, r, 0, TAU, 48, Color(1, 1, 1, 0.55 * a), maxf(3.0, r * 0.05), true)
	var knob := touch_start + move_input * r
	stick_view.draw_circle(knob, r * 0.42, Color(1, 0.97, 0.88, 0.75 * a))
	stick_view.draw_arc(knob, r * 0.42, 0, TAU, 32, Color(0.45, 0.32, 0.2, 0.6 * a), maxf(2.0, r * 0.03), true)

func update_stick_and_cam(delta: float) -> void:
	var want := 1.0 if touching and stick_index != -1 else 0.0
	stick_alpha = move_toward(stick_alpha, want, delta * (8.0 if want > 0.0 else 4.0))
	if stick_view != null:
		stick_view.queue_redraw()
	# 옆으로 걸으면 카메라가 천천히 주인공 뒤로 돌아와요 (뒤로 걸을 땐 그대로)
	if auto_cam and touching and move_input.length() > 0.35 and not swimming:
		var a := atan2(move_input.x, -move_input.y)
		if absf(a) < 2.2:
			cam_yaw_target -= a * minf(1.0, delta * 0.6) * move_input.length()

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

const MOUSE_STICK := -2
var rmb_turning := false
func release_mouse_holds() -> void:
	rmb_turning = false
	jump_mouse = false
	if stick_index == MOUSE_STICK:
		stick_index = -1
		touching = false
		move_input = Vector2.ZERO
# 휴대폰/태블릿이면 터치 안내, 컴퓨터면 키보드·마우스 안내를 보여 줘요
func is_touch_device() -> bool:
	if OS.has_feature("web_android") or OS.has_feature("web_ios") or OS.has_feature("android") or OS.has_feature("ios"):
		return true
	if OS.has_feature("web"):
		return DisplayServer.is_touchscreen_available() and not JavaScriptBridge.eval("matchMedia('(pointer: fine)').matches", true)
	return false
var kb_moving := false
func keyboard_move() -> Vector2:
	var v := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		v.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		v.x += 1.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		v.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		v.y += 1.0
	return v.normalized()

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
	# ---------- 컴퓨터 조작: WASD/방향키 걷기, 스페이스 점프, E/엔터 말 걸기·행동, Q/R 화면 돌리기 ----------
	if event is InputEventKey and event.pressed and not event.echo:
		var k: int = event.physical_keycode
		# 글 카드와 대화는 스페이스/엔터/E로도 넘겨요
		if k in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_E]:
			if in_card and card_tween != null and card_tween.is_valid() and card_overlay.modulate.a > 0.6:
				card_tween.kill()
				end_card()
				return
			if talking and not asking:
				next_line()
				return
		match k:
			KEY_SPACE:
				if not is_busy():
					on_jump()
			KEY_E, KEY_ENTER, KEY_KP_ENTER:
				if action_button != null and action_button.visible:
					on_action()
			KEY_Q:
				cam_yaw_target += PI / 4.0
			KEY_R:
				cam_yaw_target -= PI / 4.0
	# 진짜 마우스로 끌기 = 휴대폰의 손가락 끌기와 같은 조이스틱 (터치에서 만든 가짜 마우스는 device -1이라 제외)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.device != -1:
		if event.pressed and stick_index == -1:
			stick_index = MOUSE_STICK
			touching = true
			touch_start = event.position
			move_input = Vector2.ZERO
		elif not event.pressed and stick_index == MOUSE_STICK:
			stick_index = -1
			touching = false
			move_input = Vector2.ZERO
	elif event is InputEventMouseMotion and event.device != -1 and stick_index == MOUSE_STICK:
		move_input = ((event.position - touch_start) / drag_range).limit_length(1.0)
	# 마우스 오른쪽 버튼을 누른 채 좌우로 끌면 시야가 돌아가요 (컴퓨터용)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.device != -1:
		rmb_turning = event.pressed
	elif event is InputEventMouseMotion and event.device != -1 and rmb_turning:
		if (event.button_mask & MOUSE_BUTTON_MASK_RIGHT) == 0:
			rmb_turning = false   # 버튼을 뗀 신호를 놓쳤어도 실제로 안 눌려 있으면 멈춰요
		else:
			cam_yaw_target -= event.relative.x * 0.006
			cam_yaw = cam_yaw_target
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
	update_stick_and_cam(delta)
	var kb := keyboard_move() if not busy else Vector2.ZERO
	if kb != Vector2.ZERO:
		move_input = kb
		kb_moving = true
	elif kb_moving:
		kb_moving = false
		if stick_index == -1:
			move_input = Vector2.ZERO
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
