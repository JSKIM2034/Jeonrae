extends RefCounted
# 코드로 입체 모양을 짓는 도구 (물고기, 약초). 하나의 SurfaceTool 에 잎·줄기·꽃·공을 차곡차곡 쌓아
# 한 덩어리 메시로 만들어요. 색은 정점 색으로 칠해서 재질 하나로 그려요(휴대폰에서도 가볍게).

static func begin() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st

static func finish(st: SurfaceTool) -> ArrayMesh:
	st.generate_normals()
	return st.commit()

static func tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color) -> void:
	st.set_color(ca)
	st.add_vertex(a)
	st.set_color(cb)
	st.add_vertex(b)
	st.set_color(cc)
	st.add_vertex(c)

static func quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, ca: Color, cb: Color, cc: Color, cd: Color) -> void:
	tri(st, a, b, c, ca, cb, cc)
	tri(st, a, c, d, ca, cc, cd)

# 잎 한 장: 밑동 base 에서 dir 쪽으로 len 만큼, 폭 width. 가운데 잎맥이 살짝 솟고 끝이 아래로 휘어요
# shape: oval(달걀), long(가늘고 긴), heart(밑이 넓은 하트), round(동그란), ribbon(띠), tooth(톱니)
static func leaf(st: SurfaceTool, base: Vector3, dir: Vector3, side: Vector3, length: float, width: float, col: Color, curl: float = 0.25, shape: String = "oval") -> void:
	var fwd := dir.normalized()
	var sd := side.normalized()
	var up := sd.cross(fwd).normalized()
	if up.y < 0.0:
		up = -up
	var n := 7
	var rows := []
	for i in n + 1:
		var t := float(i) / n
		var wf := 0.0
		match shape:
			"long":
				wf = pow(sin(PI * clampf(t, 0.0, 1.0)), 0.8) * (1.0 - t * 0.5)
			"heart":
				wf = pow(sin(PI * minf(t * 0.85 + 0.15, 1.0)), 0.6) * (1.0 - t * 0.3)
			"round":
				wf = sqrt(maxf(0.0, 1.0 - pow(t * 2.0 - 1.0, 2.0)))
			"ribbon":
				wf = 0.75 + 0.25 * sin(t * 9.0)
				if t > 0.9:
					wf *= (1.0 - t) * 10.0
			"tooth":
				wf = sin(PI * t) * (0.75 + 0.25 * absf(sin(t * 18.0)))
			_:
				wf = sin(PI * t)
		var hw := width * 0.5 * wf
		var droop := -curl * t * t * length
		var wave := 0.0
		if shape == "ribbon":
			wave = sin(t * 7.0) * width * 0.4
		var c := base + fwd * (t * length) + up * droop + sd * wave
		rows.append([c + sd * hw + up * (-0.15 * hw), c + up * (0.12 * hw + 0.002), c - sd * hw + up * (-0.15 * hw)])
	var dark := col.darkened(0.18)
	var light := col.lightened(0.18)
	for i in n:
		var r0: Array = rows[i]
		var r1: Array = rows[i + 1]
		var k0 := dark.lerp(col, float(i) / n)
		var k1 := dark.lerp(col, float(i + 1) / n)
		quad(st, r0[0], r1[0], r1[1], r0[1], k0, k1, light, light)
		quad(st, r0[1], r1[1], r1[2], r0[2], light, light, k1, k0)

# 줄기, 가지, 뿌리: a 에서 b 까지 원통 (r0 → r1)
static func tube(st: SurfaceTool, a: Vector3, b: Vector3, r0: float, r1: float, col: Color, seg: int = 6, col_b: Color = Color(0, 0, 0, 0)) -> void:
	var axis := (b - a)
	if axis.length() < 0.0001:
		return
	var f := axis.normalized()
	var s := f.cross(Vector3.UP)
	if s.length() < 0.01:
		s = f.cross(Vector3.RIGHT)
	s = s.normalized()
	var u := s.cross(f).normalized()
	var cb := col if col_b.a == 0.0 else col_b
	for i in seg:
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		var d0 := s * cos(a0) + u * sin(a0)
		var d1 := s * cos(a1) + u * sin(a1)
		var shade0 := col.darkened(0.12 * (1.0 - sin(a0)) * 0.5)
		var shade1 := col.darkened(0.12 * (1.0 - sin(a1)) * 0.5)
		quad(st, a + d0 * r0, a + d1 * r0, b + d1 * r1, b + d0 * r1, shade0, shade1, cb, cb)

# 공·타원체 (열매, 꽃술, 알뿌리, 눈알)
static func ball(st: SurfaceTool, c: Vector3, r: Vector3, col: Color, seg: int = 8, rings: int = 6, basis: Basis = Basis()) -> void:
	var top := col.lightened(0.15)
	var bot := col.darkened(0.15)
	for j in rings:
		var t0 := PI * j / rings
		var t1 := PI * (j + 1) / rings
		for i in seg:
			var p0 := TAU * i / seg
			var p1 := TAU * (i + 1) / seg
			var v := [
				Vector3(sin(t0) * cos(p0), cos(t0), sin(t0) * sin(p0)),
				Vector3(sin(t0) * cos(p1), cos(t0), sin(t0) * sin(p1)),
				Vector3(sin(t1) * cos(p1), cos(t1), sin(t1) * sin(p1)),
				Vector3(sin(t1) * cos(p0), cos(t1), sin(t1) * sin(p0)),
			]
			var pts := []
			var cols := []
			for q in v:
				pts.append(c + basis * (q * r))
				cols.append(bot.lerp(top, (q.y + 1.0) * 0.5))
			quad(st, pts[0], pts[3], pts[2], pts[1], cols[0], cols[3], cols[2], cols[1])

# 꽃: 가운데 c 에서 꽃잎 n 장을 방사형으로 (tilt 만큼 위로 젖혀요), 가운데 꽃술
static func flower(st: SurfaceTool, c: Vector3, n: int, petal_len: float, petal_w: float, col: Color, center_col: Color, tilt: float = 0.25, up: Vector3 = Vector3.UP) -> void:
	var u := up.normalized()
	var s := u.cross(Vector3.FORWARD)
	if s.length() < 0.01:
		s = u.cross(Vector3.RIGHT)
	s = s.normalized()
	var t := u.cross(s).normalized()
	for i in n:
		var a := TAU * i / n
		var out := (s * cos(a) + t * sin(a))
		var dir := (out + u * tilt).normalized()
		var side := u.cross(out)
		leaf(st, c, dir, side, petal_len, petal_w, col, -0.1, "oval")
	ball(st, c + u * petal_len * 0.08, Vector3.ONE * petal_len * 0.28, center_col, 6, 4)

# 지느러미·꼬리: 점들로 둘러싼 얇은 판 (양면)
static func fan(st: SurfaceTool, center: Vector3, pts: Array, col: Color, edge: Color) -> void:
	for i in pts.size() - 1:
		tri(st, center, pts[i], pts[i + 1], col, edge, edge)
