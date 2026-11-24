extends Node
# 저장 옮기기 테스트 (version 1 -> 2): 예전 모양 save.cfg 를 직접 만들고 켠 뒤
# 엽전/가방/도감/엔딩/끝낸 이야기/가 본 길이 [common] 에 그대로 옮겨졌는지, 예전 칸은 남았는지,
# 다른 지역(집 마을, 2장)에서도 같은 도감이 보이는지, 도감 "엔딩" 쪽과 새 결말 기록이 되는지 검사해요
var m
var fails := 0
func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
	print(("OK   " if ok else "FAIL ") + what)
func settle() -> void:
	var idle := 0
	var guard := 0
	while idle < 10 and guard < 3000:
		guard += 1
		await get_tree().process_frame
		m = get_tree().current_scene
		if m == null or not m.has_method("chapter_id"):
			idle = 0
			continue
		if m.in_card:
			idle = 0
			if m.card_tween != null:
				m.card_tween.kill()
			m.end_card()
		elif m.talking and not m.asking:
			idle = 0
			m.last_advance_ms = 0
			m.next_line()
		else:
			idle += 1
func wait_scene(id: String) -> void:
	for i in 900:
		await get_tree().process_frame
		var cs = get_tree().current_scene
		if cs != null and cs.has_method("chapter_id") and cs.chapter_id() == id and cs.player != null and cs.cam != null:
			break
	await get_tree().create_timer(0.5).timeout
	m = get_tree().current_scene
	await settle()
func cfg() -> ConfigFile:
	var cf := ConfigFile.new()
	cf.load("user://save.cfg")
	return cf
func old_save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("world", "version", 1)
	cf.set_value("world", "chapter", "home")
	cf.set_value("world", "coins", 77)
	cf.set_value("world", "has_yeot", true)
	cf.set_value("world", "has_shoes", false)
	cf.set_value("world", "has_sickle", true)
	cf.set_value("world", "has_hanbok", false)
	cf.set_value("ch1", "fish", [2, 0, 1, 0, 0, 0])
	cf.set_value("ch1", "herbs", [3, 1, 0, 0, 0, 0])
	cf.set_value("ch1", "story", [true, false, true, false, false, false, false])
	cf.set_value("ch1", "fish_reward", false)
	cf.set_value("ch1", "herb_reward", false)
	cf.set_value("ch1", "harvests", 2)
	cf.set_value("ch1", "endings", ["original"])
	cf.set_value("ch1_state", "data", {"quest": 13, "ending_id": "true"})
	cf.set_value("ch2_state", "data", {"quest": 10, "ending": "nui_sun"})
	cf.set_value("ch3_state", "data", {"quest": 3, "ending": ""})
	cf.set_value("home", "data", {"met_granny": true})
	cf.set_value("ui", "left_handed", true)
	cf.save("user://save.cfg")
func _ready() -> void:
	old_save()
	m = load("res://home.tscn").instantiate()
	get_tree().root.add_child.call_deferred(m)
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().current_scene = m
	await get_tree().create_timer(2.0).timeout
	await settle()
	await run()
	print("DONE fails=%d" % fails)
	get_tree().quit()
func run() -> void:
	var cf := cfg()
	check(int(cf.get_value("world", "version", 0)) == 2, "version is 2")
	check(cf.get_value("world", "region", "") == "home", "region from old chapter")
	var bag: Dictionary = cf.get_value("common", "bag", {})
	check(bag.get("yeot", false) and bag.get("sickle", false) and not bag.get("shoes", false), "bag moved")
	var book: Dictionary = cf.get_value("common", "book", {})
	check(book.get("ch1_fish", []) == [2, 0, 1, 0, 0, 0], "fish book moved")
	check(int(book.get("harvests", 0)) == 2, "harvests moved")
	var en: Dictionary = cf.get_value("common", "endings", {})
	check((en.get("ch1", []) as Array).has("original") and (en.get("ch1", []) as Array).has("true"), "ch1 endings moved (+ending_id)")
	check(en.get("ch2", []) == ["nui_sun"], "ch2 ending from state")
	check(not en.has("ch3"), "ch3 has no ending")
	var done: Array = cf.get_value("common", "tales_done", [])
	check(done.has("ch1") and done.has("ch2") and not done.has("ch3"), "tales_done ch1, ch2")
	var roads: Array = cf.get_value("common", "roads_open", [])
	check(roads.has("ch1") and roads.has("ch2") and roads.has("ch3") and roads.has("home"), "roads_open incl. visited ch3")
	check(cf.get_value("ch1", "endings", []) == ["original"] and cf.get_value("world", "has_yeot", false) == true, "old sections kept")
	check(cf.get_value("ui", "left_handed", false) == true, "ui settings kept")
	# 게임 안 값
	check(m.chapter_id() == "home", "home loaded")
	check(m.coins == 77 and m.has_yeot and m.has_sickle and not m.has_shoes, "coins and bag in game")
	check(m.fish_caught[0] == 2 and m.herb_counts[0] == 3 and m.story_read[2], "book in home village")
	check(m.tales_count() == 2, "home counts 2 tales")
	var pr: Array = m.endings_progress()
	check(pr[0] == 3 and pr[1] == 9, "ending progress 3/9")
	# 두 번째로 켜도 다시 옮기지 않음 (version 2)
	var cf2 := cfg()
	check(not m.migrate_config(cf2), "no second migration")
	# 할머니 힌트에 못 본 결말 힌트
	var hints: Array = m.granny_hints()
	var has_hint := false
	for h in hints:
		if str(h).contains(m.ENDINGS["ch1"][1][3]) or str(h).contains(m.ENDINGS["ch1"][3][3]) or str(h).contains(m.ENDINGS["ch2"][0][3]):
			has_hint = true
	check(has_hint, "granny gives unseen ending hint")
	# 도감 엔딩 쪽
	m.open_book("ending")
	await get_tree().process_frame
	check(m.ending_page.visible and not m.book_canvas.visible, "ending page shown")
	check(m.book_title.text.contains("3/9"), "ending title shows 3/9: " + m.book_title.text)
	check(m.ending_rows[0][1].text.contains(m.ENDINGS["ch1"][0][1]), "seen ending named")
	check(m.ending_rows[1][1].text.begins_with("???"), "unseen ending hidden")
	m.show_ending_tale("ch3")
	check(not m.ending_rows[3][0].visible and m.ending_rows[0][1].text.contains(m.tr("이야기를 끝내면 힌트가 보여요.")), "ch3 not done: no hint, 3 rows")
	m.close_book()
	# 새 결말 기록
	check(m.record_ending("ch3", "plain") == 1, "record ch3 ending")
	check((cfg().get_value("common", "tales_done", []) as Array).has("ch3"), "ch3 now done")
	m.read_tales()
	check(m.tales_count() == 3, "home counts 3 tales")
	# 저장하면 가방이 [common] 에
	m.has_shoes = true
	m.save_progress()
	check((cfg().get_value("common", "bag", {}) as Dictionary).get("shoes", false), "bag saved to common")
	check((cfg().get_value("common", "roads_open", []) as Array).has("home"), "roads keep home")
	# 2장으로 가도 같은 도감과 엽전
	m.go_to_chapter("ch2")
	await wait_scene("ch2")
	check(m.chapter_id() == "ch2", "ch2 loaded")
	check(m.fish_caught[0] == 2 and m.herb_counts[0] == 3 and m.coins == 77 and m.has_shoes, "same book/coins/bag in ch2")
	m.open_book("ending")
	await get_tree().process_frame
	check(m.book_title.text.contains("4/9"), "ch2 sees 4/9 endings")
	m.close_book()
	# 처음부터 다시: 가방은 비우고 도감·결말은 남김
	m.reset_progress()
	await wait_scene("home")
	var cf3 := cfg()
	check((cf3.get_value("common", "bag", {}) as Dictionary).get("shoes", false) == false, "reset empties bag")
	check((cf3.get_value("common", "endings", {}) as Dictionary).has("ch1"), "reset keeps endings")
	check(m.fish_caught[0] == 2, "reset keeps book")
