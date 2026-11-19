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
