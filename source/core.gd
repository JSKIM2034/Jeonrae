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
