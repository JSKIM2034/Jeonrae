extends Node
# 오누이 고갯길 약초 테스트: 약초 다섯 가지 자리, 약초꾼 할아버지 첫 인사, 영지버섯은 비·안개 날에만,
# 종류마다 세 번 캐면 도감, 다 모으면 30냥, [common] book 저장, 도감 고갯길 칸, 흥부네 약초는 그대로
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
	cf.set_value("world", "chapter", "ch2")
	cf.set_value("common", "book", {"herbs": {"ssuk": 3, "naengi": 1}})
	cf.set_value("ch2_state", "data", {"quest": 1})
	cf.save("user://save.cfg")
	m = load("res://chapter2.tscn").instantiate()
	get_tree().root.add_child.call_deferred(m)
	await get_tree().create_timer(2.5).timeout
	await settle()
	await run()
	print("DONE fails=%d" % fails)
	get_tree().quit()
func spots_of(id: String) -> Array:
	var out := []
	for ws in m.wild_spots:
		if m.HERBS[ws[1]]["id"] == id:
			out.append(ws)
	return out
func run() -> void:
	check(m.herb_counts.size() == m.HERBS.size() and m.HERBS.size() == 11, "11 herbs, counts sized")
	check(m.herb_counts[0] == 3 and m.herb_counts[1] == 1, "ch1 herbs loaded in ch2")
	check(m.herbs_in("ch2").size() == 5 and m.wild_spots.size() == 11, "5 pass herbs, 11 spots, no ch1 spots here")
	var on_ground := true
	for ws in m.wild_spots:
		var n: Node3D = ws[0]
		on_ground = on_ground and absf(n.position.y - m.height_at(n.position.x, n.position.z)) < 0.05
	check(on_ground, "spots sit on the hills")
	check(m.npcs.has("herbalist"), "herb grandpa stands on the pass")
	m.talk_to("herbalist")
	check(m.talking and m.herbalist_met, "herb grandpa greets")
	await settle()
	# 영지버섯: 맑은 날엔 숨고 비 오면 돋아요
	m.weather = "clear"
	await get_tree().process_frame
	await get_tree().process_frame
	var y: Array = spots_of("yeongji")
	check(not (y[0][0] as Node3D).visible, "reishi hidden on a clear day")
	m.weather = "rain"
	await get_tree().process_frame
	await get_tree().process_frame
	check((y[0][0] as Node3D).visible, "reishi sprouts in the rain")
	# 다섯 가지를 세 번씩
	var c0: int = m.coins
	for hid in ["gosari", "chwi", "omija", "chik", "yeongji"]:
		var sp: Array = spots_of(hid)
		for k in 3:
			var ws: Array = sp[0]
			(ws[0] as Node3D).visible = true
			ws[2] = 0.0
			m.pick_wild({"node": ws[0], "id": str(ws[1]), "kind": "wild"})
			await settle()
	check(m.herb_done_in("ch2") == 5, "all pass herbs in the book")
	check(m.book_rewards.has("herb_ch2") and m.coins >= c0 + 30 + 4 + 6 + 8 + 10 + 16, "complete reward 30 plus sales")
	check(not m.herb_reward, "Heungbu herb reward untouched")
	var hd: Dictionary = cfg().get_value("common", "book", {}).get("herbs", {})
	check(int(hd.get("yeongji", 0)) == 3 and int(hd.get("ssuk", 0)) == 3, "saved by id")
	m.open_book("herb")
	await get_tree().process_frame
	check(m.book_village == "ch2" and (m.village_buttons["ch2"] as Button).text.contains("5/5"), "herb book opens on pass tab 5/5")
	m.close_book()
	m.talk_to("herbalist")
	check(m.talking, "herb grandpa praises")
	await settle()
