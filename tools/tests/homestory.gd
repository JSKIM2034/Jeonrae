extends Node
# 집 마을(이야기골) 테스트: 1장 남쪽 이정표 -> 집 마을 도착 자리 -> 할머니 첫 인사 -> [home] 칸 저장
# -> 내 집 방 안 -> 돌고개(2장)·갈대 나루(3장) 오가기 -> 버드나무 길 이정표로 1장 남쪽에 돌아오기 -> 1장 엔딩이 있으면 정자나무 등불과 빈 집터 팻말이 바뀜
var m
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
func check(ok: bool, what: String) -> void:
	print(("OK   " if ok else "FAIL ") + what)
func wait_scene(id: String) -> void:
	for i in 600:
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
func _ready() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.cfg"))
	# 테스트 노드는 장면이 바뀌어도 남도록 루트에 붙어 있어요
	m = load("res://main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(m)
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().current_scene = m
	await get_tree().create_timer(2.0).timeout
	await settle()
	run()
func run() -> void:
	check(m.chapter_id() == "ch1", "starts in chapter 1")
	m.on_gate()
	check(m.asking and m.options_box.get_child_count() == 3, "south signpost offers 3 choices")
	m.on_option(1)
	await wait_scene("home")
	check(m.chapter_id() == "home", "home village loaded")
	check(m.player.position.distance_to(Vector3(-23.5, 0.3, -19.3)) < 1.5, "arrived at willow road entrance")
	check(cfg().get_value("world", "chapter", "") == "home" and cfg().get_value("world", "entry", "x") == "", "save says home, entry consumed")
	check(cfg().has_section("ch1_state"), "chapter 1 progress kept")
	check(not m.met_granny and m.tales_count() == 0, "fresh village: granny not met, no tales")
	check(m.lot_text(0) == m.tr("빈 집터"), "lot sign says empty")
	var c0: int = m.coins
	m.talk_to("storyteller")
	await settle()
	check(m.met_granny and m.coins == c0 + 10, "granny greeting done (+10)")
	var hd: Dictionary = cfg().get_value("home", "data", {})
	check(hd.get("met", false) == true, "[home] section saved")
	check(not cfg().has_section("home_state"), "no home_state section")
	m.talk_to("storyteller")
	await settle()
	check(m.granny_hint == 1, "granny gives a hint")
	# 내 집 안으로 들어갔다 나오기
	m.enter_room()
	await settle()
	check(m.in_room(), "entered my house")
	m.current_thing = m.find_thing()
	check(not m.current_thing.is_empty() and m.current_thing["kind"] == "door" and m.current_thing["id"] == "out", "exit door is right behind you")
	m.use_room("bed")
	check(m.asking, "bed asks to sleep")
	m.on_option(0)
	await settle()
	m.leave_room()
	await settle()
	check(not m.in_room() and m.player.position.distance_to(Vector3(0, 0.3, 11.4)) < 1.0, "left the house to the yard")
	# 돌고개 -> 2장 남쪽 -> 다시 집 마을 돌고개 입구 (길 열리는 순서는 walkroads 테스트가 봐요. 여기선 가 본 길로 열어 둬요)
	var cfo := cfg()
	cfo.set_value("common", "roads_open", ["home", "ch1", "ch2", "ch3"])
	cfo.save("user://save.cfg")
	m.refresh_roads()
	m.current_thing = {"kind": "gate", "id": "ch2", "node": m}
	m.on_gate()
	m.on_option(0)
	await wait_scene("ch2")
	check(m.chapter_id() == "ch2" and m.player.position.z > 44.0, "stone pass leads to chapter 2 south entrance")
	m.on_gate()
	check(m.options_box.get_child_count() == 3, "chapter 2 south sign offers home")
	m.on_option(0)
	await wait_scene("home")
	check(m.player.position.distance_to(Vector3(0.8, 0.3, -25.5)) < 1.5, "back at stone pass entrance")
	# 갈대 나루 -> 3장 -> 집 마을
	m.current_thing = {"kind": "gate", "id": "ch3", "node": m}
	m.on_gate()
	m.on_option(0)
	await wait_scene("ch3")
	check(m.chapter_id() == "ch3" and m.player.position.z > 44.0, "reed ferry leads to chapter 3 south entrance")
	m.on_gate()
	m.on_option(0)
	await wait_scene("home")
	check(m.player.position.distance_to(Vector3(23.0, 0.3, -15.0)) < 1.5, "back at reed ferry entrance")
	m.current_thing = {"kind": "gate", "id": "ch1", "node": m}
	m.on_gate()
	check(m.asking, "willow road asks")
	m.on_option(0)
	await wait_scene("ch1")
	check(m.chapter_id() == "ch1", "back in chapter 1")
	check(m.player.position.distance_to(Vector3(-2, 0.3, 29)) < 1.5, "arrived at south signpost")
	check(m.coins == c0 + 10, "coins carried")
	# 1장 엔딩을 본 것으로 하고 다시 집 마을로
	m.record_ending("ch1", "original")
	m.on_gate()
	m.on_option(1)
	await wait_scene("home")
	check(m.met_granny, "granny remembers you")
	check(m.tales_count() == 1, "one tale done -> one lantern")
	check(m.lot_text(0) != m.tr("빈 집터"), "Heungbu lot says moving in soon")
	check(m.lot_text(1) == m.tr("빈 집터"), "other lots still empty")
	print("DONE")
	get_tree().quit()
