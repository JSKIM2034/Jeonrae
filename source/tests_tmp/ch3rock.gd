extends Node
# 바닷가 마을 갯바위 낚시와 바닷속 도감 테스트: 예전 바닷속 본 물고기(ch3_state fish)가 공용 도감에 올라감,
# 갯바위 어부 첫 인사, 갯바위 낚시(갯바위 물고기만, 파도 박자 힘겨루기), 다섯 가지 다 모으면 30냥, 도감 바닷가 칸 9칸
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
func thing(kind: String, id: String) -> Dictionary:
	for t in m.things:
		if t["kind"] == kind and t["id"] == id:
			return t
	return {}
func _ready() -> void:
	var cf := ConfigFile.new()
	cf.set_value("world", "version", 2)
	cf.set_value("world", "chapter", "ch3")
	cf.set_value("ch3_state", "data", {"quest": 1, "fish": [true, false, true, false]})
	cf.save("user://save.cfg")
	m = load("res://chapter3.tscn").instantiate()
	get_tree().root.add_child.call_deferred(m)
	await get_tree().create_timer(2.5).timeout
	await settle()
	await run()
	print("DONE fails=%d" % fails)
	get_tree().quit()
func run() -> void:
	check(m.fish_caught[m.fish_index("juldom")] == 1 and m.fish_caught[m.fish_index("bollak")] == 1 and m.fish_caught[m.fish_index("jwichi")] == 0, "old undersea sightings in the shared book")
	check(int((cfg().get_value("common", "book", {}).get("fish", {}) as Dictionary).get("juldom", 0)) == 1, "sightings saved")
	check(m.npcs.has("seafisher") and not thing("fish", "rock").is_empty(), "rock fisherman and spot")
	m.talk_to("seafisher")
	check(m.talking and m.seafisher_met, "fisherman greets")
	await settle()
	m.current_thing = thing("fish", "rock")
	m.start_fishing()
	check(m.mg_active and m.fish_place == "ch3_rock", "rock fishing starts")
	var bit := false
	for i in 1200:
		await get_tree().process_frame
		if m.mg_step == 1:
			bit = true
			break
	check(bit, "float dips")
	var k: int = m.fish_kind
	m.fish_tap()
	var d0 := -1.0
	var moved := false
	for i in 1200:
		await get_tree().process_frame
		if not m.mg_active:
			break
		if i == 10:
			d0 = m.mg_dir
		if i == 60 and absf(m.mg_dir - d0) > 0.05:
			moved = true
		m.mg_off = m.mg_trail
		if i > 70:
			m.mg_progress = maxf(m.mg_progress, 0.97)
	await settle()
	check(moved, "fish rides the waves (target keeps moving)")
	check(m.FISH[k]["place"] == "ch3_rock" and m.fish_caught[k] == 1, "caught a sea rock fish")
	for i in m.fish_in("ch3_rock"):
		if m.FISH[i]["id"] != "doldom":
			m.fish_caught[i] = maxi(1, m.fish_caught[i])
	m.fish_caught[m.fish_index("doldom")] = 0
	m.fish_place = "ch3_rock"
	m.fish_kind = m.fish_index("doldom")
	var c0: int = m.coins
	m.fish_done(true, true)
	await settle()
	check(m.book_rewards.has("fish_ch3_rock") and m.coins >= c0 + 60, "rock complete reward")
	# 바닷가 약초 다섯 가지
	check(m.herbs_in("ch3").size() == 5 and m.wild_spots.size() == 11, "5 seaside herbs, 11 spots")
	for i in m.herbs_in("ch3"):
		for rep in 3:
			for ws in m.wild_spots:
				if ws[1] == i:
					(ws[0] as Node3D).visible = true
					ws[2] = 0.0
					m.pick_wild({"node": ws[0], "id": str(i), "kind": "wild"})
					await settle()
					break
	check(m.herb_done_in("ch3") == 5 and m.book_rewards.has("herb_ch3"), "seaside herbs complete reward")
	m.open_book("fish")
	await get_tree().process_frame
	check(m.book_village == "ch3" and (m.village_buttons["ch3"] as Button).text.contains("/9"), "fish book seaside tab 9: " + (m.village_buttons["ch3"] as Button).text)
	m.close_book()
