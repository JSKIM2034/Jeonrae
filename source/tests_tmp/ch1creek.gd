extends Node
# 흥부네 개울 여울 흘림 낚시와 새 도감 저장 테스트
# 예전 도감(ch1_fish 배열) 읽기 -> 여울 낚시터 -> 찌가 소용돌이에서 물림 -> 채기 -> 힘겨루기 -> 개울 물고기만 나옴
# -> [common] book fish 사전에 저장 -> 날씨에 따라 고르는 정도 -> 네 가지 다 모으면 30냥 -> 도감 마을 칸
var m
var fails := 0
func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
	print(("OK   " if ok else "FAIL ") + what)
func cfg() -> ConfigFile:
	var cf := ConfigFile.new()
	cf.load("user://save.cfg")
	return cf
func settle() -> void:
	for i in 400:
		await get_tree().process_frame
		if m.in_card:
			if m.card_tween != null:
				m.card_tween.kill()
			m.end_card()
		elif m.talking and not m.asking:
			m.last_advance_ms = 0
			m.next_line()
		elif not m.mg_active:
			return
func _ready() -> void:
	var cf := ConfigFile.new()
	cf.set_value("world", "version", 2)
	cf.set_value("world", "chapter", "ch1")
	cf.set_value("common", "book", {"ch1_fish": [1, 2, 0, 0, 0, 0], "ch1_herbs": [3, 0, 0, 0, 0, 0], "ch1_story": [true, false, false, false, false, false, false], "fish_reward": false})
	cf.set_value("ch1_state", "data", {"quest": 1})
	cf.save("user://save.cfg")
	m = load("res://main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(m)
	await get_tree().create_timer(2.5).timeout
	await settle()
	await run()
	print("DONE fails=%d" % fails)
	get_tree().quit()
func catch_one() -> int:
	m.current_thing = {}
	for t in m.things:
		if t["kind"] == "fish" and t["id"] == "creek":
			m.current_thing = t
	m.start_fishing()
	var bit := false
	for i in 2400:
		await get_tree().process_frame
		if m.mg_step == 1:
			bit = true
			break
	if not bit:
		return -1
	var k: int = m.fish_kind
	m.fish_tap()
	for i in 1200:
		await get_tree().process_frame
		if not m.mg_active:
			break
		m.mg_off = m.mg_trail
		m.mg_progress = maxf(m.mg_progress, 0.97)
	await settle()
	return k
func run() -> void:
	check(m.fish_caught[0] == 1 and m.fish_caught[1] == 2 and m.herb_counts[0] == 3 and m.story_read[0], "old book arrays read")
	check(m.FISH.size() == 27 and m.fish_in("ch1_creek").size() == 4 and m.fish_in("ch1").size() == 10, "10 fish, 4 in creek")
	var spot_found := false
	for t in m.things:
		if t["kind"] == "fish" and t["id"] == "creek":
			spot_found = true
	check(spot_found, "creek fishing spot exists")
	var c0: int = m.coins
	var k := await catch_one()
	check(k >= 0, "float bit at the swirl")
	check(k >= 0 and m.FISH[k]["place"] == "ch1_creek", "creek gives creek fish")
	check(k >= 0 and m.fish_caught[k] == 1 and m.coins > c0, "caught and paid")
	var book: Dictionary = cfg().get_value("common", "book", {})
	var fd: Dictionary = book.get("fish", {})
	check(k >= 0 and int(fd.get(m.FISH[k]["id"], 0)) == 1 and int(fd.get("bungeo", 0)) == 2, "book saved as id dictionary")
	# 날씨: 비 오는 날 꺽지가 더 잘 나와요
	m.fish_place = "ch1_creek"
	m.weather = "clear"
	var w_clear: float = m.fish_weight(m.fish_index("kkeokji"))
	m.weather = "rain"
	var w_rain: float = m.fish_weight(m.fish_index("kkeokji"))
	check(w_rain > w_clear, "rain makes Korean perch more common")
	m.weather = "clear"
	var picks := {}
	for i in 300:
		picks[m.pick_fish()] = true
	var only_creek := true
	for p in picks:
		only_creek = only_creek and m.FISH[p]["place"] == "ch1_creek"
	check(only_creek, "pick_fish stays in the creek")
	# 네 가지 다 모으면 30냥
	for i in m.fish_in("ch1_creek"):
		if i != k:
			m.fish_caught[i] = 1
	if k >= 0:
		m.fish_caught[k] = 0
		m.fish_kind = k
	m.fish_place = "ch1_creek"
	var c1: int = m.coins
	m.fish_done(true, true)
	await settle()
	check(m.coins >= c1 + 30 and m.book_rewards.has("fish_ch1_creek"), "creek complete reward")
	check((cfg().get_value("common", "book", {}).get("rewards", {}) as Dictionary).has("fish_ch1_creek"), "reward saved")
	# 도감
	m.open_book("fish")
	await get_tree().process_frame
	check(m.village_row.visible and m.book_village == "ch1", "village row on fish tab")
	check((m.village_buttons["ch1"] as Button).text.contains("/10"), "village button counts 10: " + (m.village_buttons["ch1"] as Button).text)
	m.book_village = "ch2"
	m.show_book("fish")
	check((m.village_buttons["ch2"] as Button).text.contains("/4"), "other village tab counts its own fish")
	m.show_book("ending")
	check(not m.village_row.visible, "no village row on ending tab")
	m.close_book()
	# 연못은 예전 그대로 연못 물고기만
	m.fish_place = "ch1_pond"
	var pond_only := true
	for i in 200:
		pond_only = pond_only and m.FISH[m.pick_fish()]["place"] == "ch1_pond"
	check(pond_only, "pond still gives pond fish")
