extends Node
# 품팔이 단골 테스트: 같은 일을 3·7·12번 하면 칭호와 덤, 품삯이 오르고, 횟수는 저장에 남아요
var m
var fails := 0
func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
	print(("OK   " if ok else "FAIL ") + what)
func settle() -> void:
	for i in 300:
		await get_tree().process_frame
		if m.in_card:
			if m.card_tween != null:
				m.card_tween.kill()
			m.end_card()
		elif m.talking and not m.asking:
			m.last_advance_ms = 0
			m.next_line()
		else:
			return
func _ready() -> void:
	var cf := ConfigFile.new()
	cf.save("user://save.cfg")
	m = load("res://main.tscn").instantiate()
	m.set("cam_hint_seen", true)
	get_tree().root.add_child.call_deferred(m)
	await get_tree().create_timer(2.5).timeout
	await settle()
	await run()
	print("DONE fails=%d" % fails)
	get_tree().quit()
func run() -> void:
	check(m.job_badge("water") == " (0/3)", "badge starts at 0/3 (%s)" % m.job_badge("water"))
	var spot: Dictionary = {}
	for t in m.things:
		if t["kind"] == "job" and t["id"] == "water":
			spot = t
	check(String(m.action_text(spot)).ends_with("(0/3)"), "action text shows progress")
	var c0: int = m.coins
	for i in 2:
		m.cur_job = "water"
		m.job_done(true, false)
		await settle()
	check(m.coins == c0 + 20, "plain pay 10 each (got %d)" % (m.coins - c0))
	c0 = m.coins
	m.cur_job = "water"
	m.job_done(true, false)
	await settle()
	check(m.job_level("water") == 1 and m.coins == c0 + 10 + 10, "3rd job: title + gift 10 (got %d)" % (m.coins - c0))
	c0 = m.coins
	m.cur_job = "water"
	m.job_done(true, true)
	await settle()
	check(m.coins == c0 + 10 + 3 + 5, "regular pay +3, good +5 (got %d)" % (m.coins - c0))
	for i in 8:
		m.cur_job = "water"
		m.job_done(true, false)
		await settle()
	check(m.job_level("water") == 3 and m.job_badge("water") == " ★", "12 jobs: master ★")
	check(m.job_level("wood") == 0, "other jobs separate")
	m.cur_job = "wood"
	m.job_done(false, false)
	await settle()
	check(int(m.job_counts.get("wood", 0)) == 0, "failed job not counted")
	m.save_progress()
	var cf := ConfigFile.new()
	cf.load("user://save.cfg")
	var found := false
	for sec in cf.get_sections():
		if cf.has_section_key(sec, "data"):
			var d = cf.get_value(sec, "data")
			if d is Dictionary and d.has("jobs") and int(d["jobs"].get("water", 0)) == 12:
				found = true
	check(found, "job counts saved")
