extends Node
# 다른 마을 부탁 테스트 (흥부네에서): 부탁 일곱 개, 처음 말 걸면 부탁, 모자라면 평소 대화,
# 다 있으면 "드리기/다음에", 드리면 가진 수가 줄고 엽전·선물, 대나무 낚싯대, 다른 마을 부탁은 여기서 안 나옴,
# 물건이 나는 마을 길이 닫혀 있으면 부탁도 안 함, [common] 저장, 도감 "부탁" 쪽
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
func _ready() -> void:
	var cf := ConfigFile.new()
	cf.set_value("world", "version", 2)
	cf.set_value("world", "chapter", "ch1")
	cf.set_value("world", "coins", 5)
	cf.set_value("common", "book", {"herbs": {"miyeok": 2}, "fish": {"doldom": 1, "pirami": 2}})
	cf.set_value("common", "tales_done", ["ch1", "ch2"])
	cf.set_value("common", "roads_open", ["home", "ch1", "ch2", "ch3"])
	cf.save("user://save.cfg")
	m = load("res://main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(m)
	await get_tree().create_timer(2.5).timeout
	await settle()
	await run()
	print("DONE fails=%d" % fails)
	get_tree().quit()
func run() -> void:
	check(m.REQUESTS.size() == 7, "seven requests")
	var rows: Array = m.request_rows()
	check(rows.size() == 7 and String(rows[0][1]).begins_with("???"), "unknown requests show ???")
	var ok_items := true
	for r in m.REQUESTS:
		for n in r["need"]:
			ok_items = ok_items and m.item_index(n[0], n[1]) >= 0
	check(ok_items, "every needed item exists")
	check(not m.request_talk("herbalist"), "pass grandpa's request is not asked here")
	# 흥부: 처음엔 부탁
	check(m.request_talk("heungbu") and m.talking, "heungbu asks for seaweed")
	await settle()
	check(m.req_state.get("heungbu_miyeok", "") == "asked", "request marked asked")
	check((cfg().get_value("common", "requests", {}) as Dictionary).get("heungbu_miyeok", "") == "asked", "asked saved in [common]")
	check(not m.request_talk("heungbu"), "only 2 seaweed: normal talk")
	m.herb_counts[m.item_index("herb", "miyeok")] = 3
	var c0: int = m.coins
	check(m.request_talk("heungbu") and m.asking, "3 seaweed: give or later")
	m.on_option(0)
	await settle()
	await get_tree().create_timer(0.3).timeout
	check(m.req_state.get("heungbu_miyeok", "") == "done", "request done")
	check(m.item_have("herb", "miyeok") == 0 and m.herb_counts[m.item_index("herb", "miyeok")] == 3, "seaweed handed over, book count kept")
	check(m.coins == c0 + 15, "15 coins")
	check(m.req_gifts.has("gourd_bowl"), "gourd bowl gift")
	var cf := cfg()
	check((cf.get_value("common", "given", {}) as Dictionary).get("herb.miyeok", 0) == 3, "given saved")
	check((cf.get_value("common", "gifts", []) as Array).has("gourd_bowl"), "gift saved")
	check(not m.request_talk("heungbu"), "done request no longer intercepts")
	# 강태공: 낚시를 배우기 전엔 부탁 안 함
	m.fisher_met = false
	check(not m.request_talk("fisher"), "fisher waits until you met him")
	m.fisher_met = true
	m.roads_cache["ch3"] = false
	check(not m.request_can_ask(m.request_of("fisher_doldom")), "no request while the sea road is closed")
	m.roads_cache["ch3"] = true
	check(m.request_talk("fisher"), "fisher asks for a rock bream")
	await settle()
	check(m.request_talk("fisher") and m.asking, "has the bream: offer")
	m.on_option(1)
	await settle()
	check(not m.request_talk("fisher"), "said later: normal talk this visit")
	m.req_declined.clear()
	check(m.request_talk("fisher") and m.asking, "offer again")
	m.on_option(0)
	await settle()
	check(m.good_rod and m.item_have("fish", "doldom") == 0, "bamboo rod gift, bream given")
	check(m.requests_done() == 2, "2 of 7 done")
	# 도감 "부탁" 쪽
	m.open_book("request")
	await get_tree().process_frame
	check(m.request_page.visible and "2/7" in m.book_title.text, "book request tab shows 2/7")
	rows = m.request_rows()
	check(rows[0][0] and rows[1][0] and String(rows[2][1]).begins_with("???"), "done rows star, others ???")
	m.close_book()
	# 다시 불러와도 그대로
	var m2 = load("res://main.tscn").instantiate()
	m.queue_free()
	await get_tree().process_frame
	get_tree().root.add_child(m2)
	m = m2
	await get_tree().create_timer(2.0).timeout
	await settle()
	check(m.requests_done() == 2 and m.good_rod and m.item_have("herb", "miyeok") == 0, "reload keeps requests")
