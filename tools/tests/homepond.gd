extends Node
# 이야기골 연못 뜰채 놀이와 마을 약초 테스트: 연못 물고기가 헤엄침, 뜰채를 살살 따라가 세 마리 뜨기,
# 휙 휘두르면 놀라 달아남(기회 줄어듦), 밤에만 달빛 잉어, 마을 약초 네 가지, 다 모으면 30냥
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
func _ready() -> void:
	var cf := ConfigFile.new()
	cf.set_value("world", "version", 2)
	cf.set_value("world", "chapter", "home")
	cf.set_value("home", "data", {"met": true})
	cf.save("user://save.cfg")
	m = load("res://home.tscn").instantiate()
	get_tree().root.add_child.call_deferred(m)
	await get_tree().create_timer(2.5).timeout
	await settle()
	await run()
	print("DONE fails=%d" % fails)
	get_tree().quit()
func run() -> void:
	check(m.pond_fish.size() == 6, "6 fish swim in the pond")
	var p0: Vector3 = m.pond_fish[0]["pos"]
	await get_tree().create_timer(1.0).timeout
	check((m.pond_fish[0]["pos"] as Vector3).distance_to(p0) > 0.05, "pond fish move")
	check(m.herbs_in("home").size() == 4 and m.wild_spots.size() == 9, "4 village herbs, 9 spots")
	var y_ok := true
	for ws in m.wild_spots:
		y_ok = y_ok and absf((ws[0] as Node3D).position.y) < 0.05
	check(y_ok, "herb spots on the ground")
	# 낮에는 달빛 잉어가 안 나와요
	m.fish_place = "home_pond"
	check(m.fish_weight(m.fish_index("moon_ingeo")) == 0.0, "no moonlight carp by day")
	m.set_home_night(true)
	check(m.fish_weight(m.fish_index("moon_ingeo")) > 0.0 and m.is_night(), "moonlight carp at night")
	m.set_home_night(false)
	# 뜰채: 살살 따라가서 뜨기
	m.start_net()
	check(m.mg_active and m.mg_type == "net", "net game starts")
	var net: Node3D = m.w["net"]
	for i in 3000:
		await get_tree().process_frame
		if not m.mg_active:
			break
		# 가장 가까운 물고기 쪽으로 손가락을 조금씩
		var best: Vector3 = Vector3.INF
		for pf in m.pond_fish:
			if float(pf["gone"]) <= 0.0:
				var fp: Vector3 = pf["pos"]
				if best == Vector3.INF or fp.distance_to(net.position) < best.distance_to(net.position):
					best = fp
		if best != Vector3.INF:
			var aim := net.position + (best - net.position).limit_length(0.03)
			m.mg_touch = true
			m.mg_pos = m.cam.unproject_position(aim)
	await settle()
	check(not m.mg_active, "net game ends")
	var got := 0
	for i in m.fish_in("home_pond"):
		got += m.fish_caught[i]
	check(got >= 3, "scooped 3 fish gently: %d" % got)
	# 휙 휘두르기
	m.start_net()
	var lives0: int = m.mg_lives
	var pf0: Dictionary = m.pond_fish[0]
	for i in 120:
		await get_tree().process_frame
		var fp2: Vector3 = pf0["pos"]
		m.mg_touch = true
		m.mg_pos = m.cam.unproject_position(fp2 + Vector3(3.0 * sin(i * 0.5), 0, 0))
		if m.mg_lives < lives0:
			break
	check(m.mg_lives < lives0, "swinging fast scares fish (life lost)")
	m.end_game(false)
	await settle()
	# 약초 다 모으기
	for i in m.herbs_in("home"):
		for rep in 3:
			for ws in m.wild_spots:
				if ws[1] == i:
					(ws[0] as Node3D).visible = true
					ws[2] = 0.0
					m.pick_wild({"node": ws[0], "id": str(i), "kind": "wild"})
					await settle()
					break
	check(m.herb_done_in("home") == 4 and m.book_rewards.has("herb_home"), "village herbs complete reward")
	m.open_book("fish")
	await get_tree().process_frame
	check(m.book_village == "home" and (m.village_buttons["home"] as Button).text.contains("/4"), "fish book Story Hollow tab")
	m.close_book()
