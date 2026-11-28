extends Node
# 이야기 조각 테스트 (이야기골): 조각 자리 4곳(할머니 집 장독대, 정자나무 뒤, 빈 집터, 내 집 방 안),
# 정자나무 조각은 이야기를 하나 끝낸 뒤, 방 안 조각은 이야기골 물고기·약초를 다 모은 뒤에만,
# 예전에 끝낸 할머니 부탁은 넷째 조각을 받은 걸로, 다 모으면 숨은 이야기와 30냥, 저장에 남음
var m
var fails := 0
func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
	print(("OK   " if ok else "FAIL ") + what)
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
	cf.set_value("world", "chapter", "home")
	cf.set_value("home", "data", {"met": true})
	cf.set_value("common", "tales_done", ["ch1"])
	cf.set_value("common", "requests", {"granny_sancheoneo": "done"})
	cf.set_value("common", "book", {"story": {"ch2": [true, false, false, false, false]}})
	cf.save("user://save.cfg")
	m = load("res://home.tscn").instantiate()
	get_tree().root.add_child.call_deferred(m)
	await get_tree().create_timer(2.5).timeout
	await settle()
	await run()
	print("DONE fails=%d" % fails)
	get_tree().quit()
func spot(i: int) -> Dictionary:
	for t in m.things:
		if t["kind"] == "tale" and t["id"] == "home:%d" % i:
			return t
	return {}
func run() -> void:
	var n := 0
	for t in m.things:
		if t["kind"] == "tale":
			n += 1
	check(n == 4, "4 piece spots in Iyagigol (got %d)" % n)
	check(m.tale_read["home"][3], "old finished granny request counts as piece 3")
	check(m.tale_read["ch2"][0], "other village pieces kept")
	check(m.tale_list("home").size() == 5 and m.tale_count("home") == 1, "5 home pieces, 1 found")
	await frames(3)
	check((spot(0)["node"] as Node3D).visible and (spot(1)["node"] as Node3D).visible and (spot(2)["node"] as Node3D).visible, "crock, tree, lot pieces shown")
	check(not (spot(4)["node"] as Node3D).visible, "room piece hidden before the village book is done")
	var hints: Array = m.granny_hints()
	var has_hint := false
	for h in hints:
		if String(h).contains(m.tr("장독대")):
			has_hint = true
	check(has_hint, "granny hints at hidden pieces")
	# 마당 조각: 가까이 가서 줍기
	for i in 3:
		var sp: Node3D = spot(i)["node"]
		m.player.position = sp.position + Vector3(0.4, 0.3, 0)
		await frames(3)
		m.current_thing = m.find_thing()
		check(m.current_thing.get("kind", "") == "tale" and m.current_thing.get("id", "") == "home:%d" % i, "piece %d nearest" % i)
		m.on_action()
		await settle()
		check(m.tale_read["home"][i], "piece %d read" % i)
	check(not m.book_rewards.has("tale_home"), "no bundle yet")
	m.book_rewards["fish_home_pond"] = true
	m.book_rewards["herb_home"] = true
	await frames(3)
	check((spot(4)["node"] as Node3D).visible, "room piece after the village book is done")
	m.enter_room()
	await settle()
	var rp: Node3D = spot(4)["node"]
	m.player.position = rp.position + Vector3(0.2, 0.3, 0.5)
	await frames(3)
	m.current_thing = m.find_thing()
	check(m.current_thing.get("kind", "") == "tale" and m.current_thing.get("id", "") == "home:4", "room piece nearest (got %s)" % m.current_thing.get("id", ""))
	var c0: int = m.coins
	m.on_action()
	await settle()
	check(m.tale_read["home"][4] and m.book_rewards.has("tale_home"), "all 5 home pieces -> bundle")
	check(m.coins == c0 + 30, "bundle 30 coins (got %d)" % (m.coins - c0))
	await frames(3)
	check(not rp.visible, "found room piece hidden")
	var cf := ConfigFile.new()
	cf.load("user://save.cfg")
	var st: Dictionary = (cf.get_value("common", "book", {}) as Dictionary).get("story", {})
	check((st.get("home", []) as Array) == [true, true, true, true, true], "home pieces saved")
	check((st.get("ch2", []) as Array).size() == 5 and st["ch2"][0], "ch2 pieces still saved")
	m.open_book("story")
	await frames(2)
	check(m.book_village == "home" and String(m.story_buttons[4].text).contains(m.tale_list("home")[4]["title"]), "book story page shows Iyagigol pieces")
	m.close_book()
