extends Node
# 1장 우물 긷기 테스트: 한 번에 휙 쓸어 올려도 바로 끝나지 않고, 살살 여러 번 당기면 물 한 동이를 길어요
var m
func wait(t: float) -> void:
	await get_tree().create_timer(t).timeout
func check(ok: bool, what: String) -> void:
	print(("OK   " if ok else "FAIL ") + what)
func _ready() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.cfg"))
	m = load("res://main.tscn").instantiate()
	add_child(m)
	await wait(2.0)
	if m.in_card:
		m.end_card()
	m.start_well3d()
	await wait(0.2)
	if m.in_card:
		m.end_card()
	m.mg_started = true
	while m.w.get("state", "") != "pull":
		await get_tree().process_frame
	var h: float = m.mg_overlay.size.y
	# 1) 화면 끝까지 0.1초 만에 휙
	m.well_drag(h, 100.0)
	await wait(0.5)
	check(m.w["y"] < m.WELL_TOP - 0.1, "one fast swipe does not finish the bucket (y=%.2f)" % m.w["y"])
	check(float(m.w["sway"]) > 0.5, "fast swipe makes the bucket sway")
	# 계속 홱홱 당기면 물이 거의 다 쏟아져요
	for i in 12:
		m.well_drag(h * 0.6, 80.0)
		await wait(0.35)
	check(float(m.w.get("fill", 0.0)) < 0.2, "yanking spills the water (fill=%.2f)" % m.w["fill"])
	# 2) 살살 당기기: 한 동이를 거의 가득
	var f0: float = m.w["fill"]
	while m.w.get("state", "") == "pull":
		m.well_drag(h * 0.04, 120.0)
		await wait(0.12)
	f0 = m.w["fill"]
	m.mg_lives = 9
	while m.w.get("state", "") != "pull":
		await get_tree().process_frame
	var t0 := Time.get_ticks_msec()
	var guard := 0
	while m.w.get("state", "") == "pull" and guard < 200:
		guard += 1
		for k in 6:
			m.well_drag(h * 0.04, 120.0)
			await wait(0.12)
	var secs := (Time.get_ticks_msec() - t0) / 1000.0
	check(float(m.w["fill"]) - f0 > 0.3, "gentle pulls bring up a full bucket (+%.2f)" % (float(m.w["fill"]) - f0))
	check(secs > 2.0, "one bucket takes a few seconds (%.1fs)" % secs)
	print("DONE")
	get_tree().quit()
