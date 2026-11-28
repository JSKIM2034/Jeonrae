extends Node
# 이야기 조각 테스트 (오누이 고갯길): 조각 자리 4곳과 나타나는 조건(반딧불, 서낭당 돌 셋),
# 살펴보면 조각을 얻고 [common] book story ch2 에 저장, 약초꾼 부탁으로 다섯째 조각,
# 다 모으면 숨은 이야기와 엽전 30냥(한 번만), 도감 이야기 쪽 마을 칸, 흥부 조각은 그대로,
# 예전에 끝낸 해녀 부탁은 불러올 때 조각을 받은 걸로
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
		else:
			return
func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
func _ready() -> void:
	var cf := ConfigFile.new()
	cf.set_value("world", "version", 2)
	cf.set_value("world", "chapter", "ch2")
	cf.set_value("world", "coins", 0)
	cf.set_value("common", "book", {"herbs": {"hamcho": 2}, "story": {"ch1": [true, false, false, false, false, false, true]}})
	cf.set_value("common", "requests", {"haenyeo_ssuk": "done"})
	cf.set_value("ch2_state", "data", {"quest": 1, "herbalist": true})
	cf.save("user://save.cfg")
	m = load("res://chapter2.tscn").instantiate()
	get_tree().root.add_child.call_deferred(m)
	await get_tree().create_timer(2.5).timeout
	await settle()
	await run()
	print("DONE fails=%d" % fails)
	get_tree().quit()
func spot(i: int) -> Dictionary:
	for t in m.things:
		if t["kind"] == "tale" and t["id"] == "ch2:%d" % i:
			return t
	return {}
func run() -> void:
	check(m.TALES["ch2"].size() == 5 and m.TALES["ch3"].size() == 5, "5 + 5 new story pieces")
	check(m.story_read[0] and m.story_read[6] and not m.story_read[1], "heungbu pieces kept")
	check(m.tale_read["ch3"][4] and not m.tale_read["ch3"][0], "old finished diver request counts as her piece")
	var n := 0
	for t in m.things:
		if t["kind"] == "tale":
			n += 1
	check(n == 4, "4 piece spots in the pass")
	await frames(3)
	check((spot(0)["node"] as Node3D).visible and (spot(1)["node"] as Node3D).visible, "rice cake and tree pieces shown")
	check(not (spot(2)["node"] as Node3D).visible, "cottage piece hidden before fireflies")
	check(not (spot(3)["node"] as Node3D).visible, "shrine piece hidden before stones")
	var ok_ground := true
	for i in 4:
		var p: Vector3 = (spot(i)["node"] as Node3D).position
		ok_ground = ok_ground and absf(p.y - m.height_at(p.x, p.z)) < 0.6
	check(ok_ground, "piece spots sit on the ground")
	# 떡집 조각 살펴보기
	var sp: Node3D = spot(0)["node"]
	m.player.position = sp.position + Vector3(0.6, 0.1, 0)
	await frames(3)
	m.current_thing = m.find_thing()
	check(m.current_thing.get("kind", "") == "tale", "piece is the nearest thing")
	check(m.action_text(m.current_thing) == "살펴보기", "action says look")
	m.on_action()
	check(m.talking, "piece text shown")
	await settle()
	check(m.tale_read["ch2"][0], "piece 0 read")
	var bk: Dictionary = cfg().get_value("common", "book", {})
	check((bk.get("story", {}) as Dictionary).get("ch2", [])[0] == true, "saved in [common] book story ch2")
	check(((bk.get("story", {}) as Dictionary).get("ch1", []) as Array).size() == 7, "heungbu save kept")
	await frames(3)
	check(not sp.visible, "found piece disappears")
	# 반딧불, 돌 셋
	m.fireflies_got = m.FIREFLY_N
	m.stones = [true, true, false]
	await frames(3)
	check((spot(2)["node"] as Node3D).visible, "cottage piece after all fireflies")
	check(not (spot(3)["node"] as Node3D).visible, "shrine piece still hidden with 2 stones")
	m.stones = [true, true, true]
	await frames(3)
	check((spot(3)["node"] as Node3D).visible, "shrine piece after 3 stones")
	m.get_tale("ch2", 1)
	await settle()
	m.get_tale("ch2", 2)
	await settle()
	m.get_tale("ch2", 3)
	await settle()
	check(m.tale_count("ch2") == 4 and not m.book_rewards.has("tale_ch2"), "4/5, no bundle reward yet")
	# 약초꾼 부탁 → 다섯째 조각 + 묶음 보상
	var c0: int = m.coins
	m.req_state["herbalist_hamcho"] = "asked"
	m.finish_request(m.request_of("herbalist_hamcho"))
	await settle()
	check(m.tale_read["ch2"][4], "herbalist request gives piece 4")
	check(m.book_rewards.has("tale_ch2"), "bundle reward recorded")
	check(m.coins == c0 + 10 + 30, "request 10 + bundle 30 coins (got %d)" % (m.coins - c0))
	var c1: int = m.coins
	m.get_tale("ch2", 0)
	await settle()
	check(m.coins == c1, "re-reading gives no more coins")
	check(((cfg().get_value("common", "book", {}) as Dictionary).get("rewards", {}) as Dictionary).has("tale_ch2"), "bundle reward saved")
	# 도감 이야기 쪽
	m.open_book("story")
	await settle()
	check(m.book_village == "ch2" and m.village_row.visible, "story tab opens on this village with village row")
	var vis := 0
	for b in m.story_buttons:
		if b.visible:
			vis += 1
	check(vis == 5, "5 piece buttons for the pass")
	check(m.tales_all_count() == [8, 22], "total count %s" % str(m.tales_all_count()))
	m.book_village = "ch1"
	m.show_book("story")
	vis = 0
	for b in m.story_buttons:
		if b.visible:
			vis += 1
	check(vis == 7 and String(m.story_buttons[1].text).contains("???"), "heungbu tab: 7 buttons, unfound ???")
	m.book_village = "home"
	m.show_book("story")
	vis = 0
	for b in m.story_buttons:
		if b.visible:
			vis += 1
	check(vis == 5 and String(m.story_buttons[0].text).contains("???"), "story hollow tab: 5 buttons, unfound ???")
	m.book_village = "ch2"
	m.show_book("story")
	m.read_story(3)
	check(m.story_reader.visible and m.story_reader_label.text.contains(m.TALES["ch2"][3]["title"]), "read a found pass piece")
	m.close_book()
