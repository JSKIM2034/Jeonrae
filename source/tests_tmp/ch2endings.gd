extends Node
# 오누이 새 엔딩 테스트: 서낭당 돌 셋 + "엄마도 같이 가요" → 엄마가 살아 돌아옴(mom_saved),
# 솔방울을 하나도 놓치지 않으면 맞서는 길 → 호랑이를 쫓아낸 밤(fight), 수숫대는 그대로, 오누이는 땅에 남음
var m
var fails := 0
func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
	print(("OK   " if ok else "FAIL ") + what)
func settle() -> void:
	for i in 2000:
		await get_tree().process_frame
		if m.in_card:
			if m.card_tween != null:
				m.card_tween.kill()
			m.end_card()
		elif m.talking and not m.asking:
			m.last_advance_ms = 0
			m.next_line()
		elif m.asking:
			return
		elif i > 300:
			return
func load_ch2(state: Dictionary) -> void:
	var cf := ConfigFile.new()
	cf.set_value("world", "version", 2)
	cf.set_value("world", "chapter", "ch2")
	cf.set_value("ch2_state", "data", state)
	cf.save("user://save.cfg")
	if m != null:
		m.queue_free()
		await get_tree().process_frame
	m = load("res://chapter2.tscn").instantiate()
	get_tree().root.add_child.call_deferred(m)
	await get_tree().create_timer(2.5).timeout
	await settle()
func _ready() -> void:
	# 1) 엄마를 살리는 엔딩
	await load_ch2({"quest": 9, "stones": [true, true, true], "mom_together": true})
	check(m.mom_together and m.stones == [true, true, true], "conditions restored from save")
	m.on_ending(0)
	await settle()
	await get_tree().create_timer(4.0).timeout
	await settle()
	var cf := ConfigFile.new()
	cf.load("user://save.cfg")
	var e2: Array = (cf.get_value("common", "endings", {}) as Dictionary).get("ch2", [])
	check(e2.has("mom_saved") and not e2.has("oppa_sun"), "mom saved ending recorded: %s" % str(e2))
	check(m.npc("mom").visible and m.quest == m.S_END, "mom is back and the tale ends")
	# 2) 조건이 모자라면 평소 엔딩
	await load_ch2({"quest": 9, "stones": [true, false, true], "mom_together": true})
	m.on_ending(1)
	await settle()
	await get_tree().create_timer(1.0).timeout
	await settle()
	check(m.ending == "nui_sun", "without all shrine stones: normal ending")
	# 3) 호랑이를 쫓아낸 밤
	await load_ch2({"quest": 9})
	m.pine_done(true, true)
	await settle()
	check(m.asking and m.options_box.get_child_count() == 2, "perfect pinecones open the fight choice")
	m.on_option(0)
	await settle()
	await get_tree().create_timer(5.0).timeout
	await settle()
	cf.load("user://save.cfg")
	e2 = (cf.get_value("common", "endings", {}) as Dictionary).get("ch2", [])
	check(e2.has("fight") and m.ending == "fight", "fight ending recorded")
	check(m.npc("oppa").visible and not m.tiger.visible, "kids stay on the ground, tiger gone")
	check(m.quest == m.S_END and not m.event_lock, "tale ends, controls free")
	# 4) 하나라도 놓치면 바로 하늘에 빌기
	await load_ch2({"quest": 9})
	m.pine_done(true, false)
	await settle()
	check(not m.asking, "missed pinecones: straight to praying")
	print("DONE fails=%d" % fails)
	get_tree().quit()
