extends Node
# 이야기 조각 테스트 (바닷가 마을): 조각 자리 3곳, 용궁 조각은 용궁에 들어간 뒤에만,
# 넙치 문지기에게 말 걸면(문을 지난 뒤) 넙치 조각, 해녀 부탁으로 다섯째 조각과 묶음 보상
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
	cf.set_value("world", "chapter", "ch3")
	cf.set_value("common", "book", {"herbs": {"ssuk": 3}})
	cf.set_value("ch3_state", "data", {"quest": 4})
	cf.save("user://save.cfg")
	m = load("res://chapter3.tscn").instantiate()
	get_tree().root.add_child.call_deferred(m)
	await get_tree().create_timer(2.5).timeout
	await settle()
	await run()
	print("DONE fails=%d" % fails)
	get_tree().quit()
func spot(i: int) -> Dictionary:
	for t in m.things:
		if t["kind"] == "tale" and t["id"] == "ch3:%d" % i:
			return t
	return {}
func run() -> void:
	var n := 0
	for t in m.things:
		if t["kind"] == "tale":
			n += 1
	check(n == 3, "3 piece spots by the sea")
	await frames(3)
	check((spot(0)["node"] as Node3D).visible and (spot(1)["node"] as Node3D).visible, "rock and back hill pieces shown")
	check(not (spot(2)["node"] as Node3D).visible, "palace piece hidden before the palace")
	m.talk_to("flatfish")
	await settle()
	check(not m.tale_read["ch3"][3], "no flounder piece before the gate")
	m.quest = m.S_COURT
	await frames(3)
	check((spot(2)["node"] as Node3D).visible, "palace piece after entering")
	m.talk_to("flatfish")
	await settle()
	check(m.tale_read["ch3"][3], "flounder gatekeeper gives piece 3")
	var sp: Node3D = spot(1)["node"]
	m.player.position = sp.position + Vector3(0.5, 0.1, 0)
	await frames(3)
	m.current_thing = m.find_thing()
	check(m.current_thing.get("kind", "") == "tale", "back hill piece nearest")
	m.on_action()
	await settle()
	check(m.tale_read["ch3"][1], "back hill piece read")
	m.get_tale("ch3", 0)
	await settle()
	m.get_tale("ch3", 2)
	await settle()
	var c0: int = m.coins
	m.req_state["haenyeo_ssuk"] = "asked"
	m.finish_request(m.request_of("haenyeo_ssuk"))
	await settle()
	check(m.tale_read["ch3"][4] and m.book_rewards.has("tale_ch3"), "diver request gives piece 4 and bundle")
	check(m.coins == c0 + 15 + 30, "request 15 + bundle 30 (got %d)" % (m.coins - c0))
	m.quest = m.S_ESCAPE
	await frames(3)
	check(not (spot(2)["node"] as Node3D).visible, "found palace piece stays hidden")
