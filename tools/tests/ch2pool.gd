extends Node
# 오누이 고갯길 바위 웅덩이 테스트: 들여다보기 낚시(보이는 물고기가 찌로 다가와 물면 채기),
# 돌 뒤집어 가재 잡기, 칡뿌리 당기기(성공하면 캐고, 실패하면 끊김), 네 가지 다 모으면 30냥
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
	cf.set_value("world", "chapter", "ch2")
	cf.set_value("ch2_state", "data", {"quest": 1})
	cf.save("user://save.cfg")
	m = load("res://chapter2.tscn").instantiate()
	get_tree().root.add_child.call_deferred(m)
	await get_tree().create_timer(2.5).timeout
	await settle()
	await run()
	print("DONE fails=%d" % fails)
	get_tree().quit()
func run() -> void:
	check(m.fish_in("ch2_pool").size() == 4 and m.pool_fish.size() == 5, "4 pool kinds, 5 fish visible in the pool")
	check(not thing("fish", "pool").is_empty() and m.cray_rocks.size() == 3, "pool fishing spot and 3 crayfish stones")
	# 들여다보기 낚시
	m.current_thing = thing("fish", "pool")
	m.start_fishing()
	check(m.mg_active and m.fish_place == "ch2_pool", "pool fishing starts")
	var bit := false
	for i in 1200:
		await get_tree().process_frame
		if m.mg_step == 1:
			bit = true
			break
	check(bit, "a visible fish swims to the float and bites")
	var k: int = m.fish_kind
	var chaser: int = m.w.get("chaser", -1)
	check(chaser >= 0 and int(m.pool_fish[chaser][1]) == k, "the fish that bit is the one you saw")
	m.fish_tap()
	for i in 1200:
		await get_tree().process_frame
		if not m.mg_active:
			break
		m.mg_off = m.mg_trail
		m.mg_progress = maxf(m.mg_progress, 0.97)
	await settle()
	check(m.fish_caught[k] == 1 and m.FISH[k]["place"] == "ch2_pool" and m.FISH[k]["id"] != "gajae", "pool fish caught")
	# 가재: 돌을 뒤집다 보면 나와요. 도망가기 전에 잡기
	var got_cray := false
	for tries in 12:
		for i in 3:
			m.cray_rocks[i][2] = 0.0
			var t := thing("crayrock", str(i))
			m.on_crayrock(t)
			await settle()
			if not m.cray.is_empty():
				check(m.action_text(t) == m.tr("가재 잡기!"), "action says grab crayfish")
				m.on_crayrock(t)
				await settle()
				got_cray = true
				break
		if got_cray:
			break
	check(got_cray and m.fish_caught[m.fish_index("gajae")] == 1, "crayfish caught from under a stone")
	# 놓치기: 가만히 두면 웅덩이로 도망
	var fled := false
	for tries in 12:
		m.cray_rocks[0][2] = 0.0
		m.on_crayrock(thing("crayrock", "0"))
		await settle()
		if not m.cray.is_empty():
			await get_tree().create_timer(1.8).timeout
			fled = m.cray.is_empty()
			break
	check(fled, "crayfish runs away if you wait")
	# 칡뿌리 당기기
	var chik: int = -1
	for ws in m.wild_spots:
		if m.HERBS[ws[1]]["id"] == "chik":
			chik = m.wild_spots.find(ws)
			break
	var cs: Array = m.wild_spots[chik]
	m.pick_wild({"node": cs[0], "id": str(cs[1]), "kind": "wild"})
	check(m.mg_active and m.fish_place == "ch2_chik" and m.mg_step == 2, "kudzu pull starts straight in the tug")
	for i in 1200:
		await get_tree().process_frame
		if not m.mg_active:
			break
		m.mg_off = m.mg_trail
		m.mg_progress = maxf(m.mg_progress, 0.97)
	await settle()
	check(m.herb_counts[cs[1]] == 1, "kudzu root dug after a good pull")
	(cs[0] as Node3D).visible = true
	cs[2] = 0.0
	m.pick_wild({"node": cs[0], "id": str(cs[1]), "kind": "wild"})
	m.end_game(false)
	await settle()
	check(m.herb_counts[cs[1]] == 1 and not (cs[0] as Node3D).visible, "pulling too hard snaps the root")
	# 웅덩이 네 가지 다 모으면 30냥
	for i in m.fish_in("ch2_pool"):
		if m.FISH[i]["id"] != "sancheoneo":
			m.fish_caught[i] = maxi(1, m.fish_caught[i])
	m.fish_caught[m.fish_index("sancheoneo")] = 0
	m.fish_place = "ch2_pool"
	m.fish_kind = m.fish_index("sancheoneo")
	var c0: int = m.coins
	m.fish_done(true, true)
	await settle()
	check(m.book_rewards.has("fish_ch2_pool") and m.coins >= c0 + 22 + 30, "pool complete reward")
	m.open_book("fish")
	await get_tree().process_frame
	check((m.village_buttons["ch2"] as Button).text.contains("4/4"), "fish book pass tab 4/4")
	m.close_book()
