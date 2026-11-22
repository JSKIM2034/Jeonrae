extends Node
# 3장 결말 갈래 테스트: 위로만 하고 끝냄 -> 자라가 산삼 힌트 -> 산삼을 가져다줌(늦게 도착한 약) -> 용왕 회복, 보상 한 번
var m
func _ready() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.cfg"))
	m = load("res://chapter3.tscn").instantiate()
	add_child(m)
	await get_tree().create_timer(2.0).timeout
	run()
func settle() -> void:
	var idle := 0
	var guard := 0
	while idle < 10 and guard < 3000:
		guard += 1
		await get_tree().process_frame
		if m.in_card:
			idle = 0
			if m.card_tween != null:
				m.card_tween.kill()
			m.end_card()
		elif m.talking:
			idle = 0
			if m.asking:
				m.on_option(0)
			else:
				m.last_advance_ms = 0
				m.next_line()
		else:
			idle += 1
func check(ok: bool, what: String) -> void:
	print(("OK   " if ok else "FAIL ") + what)
func run() -> void:
	m.quest = m.S_END
	m.ending = "plain"
	m.has_ginseng = false
	m.apply_story_state()
	m.update_quest_text()
	check(m.is_active({"kind": "ginseng", "node": m.ginseng_spot}), "plain ending: ginseng can be dug")
	m.talk_jara(); await settle()
	check(m.ending == "plain", "turtle gives a hint, ending stays plain")
	var c0: int = m.coins
	m.talk_yongwang(); await settle()
	check(m.coins == c0 and not m.king_thanked, "sick king gives no reward")
	m.has_ginseng = true
	m.talk_jara(); await settle()
	check(m.ending == "late", "giving ginseng late -> ending late")
	check(m.coins == c0 + 20, "late ending pays 20")
	check(not m.is_active({"kind": "ginseng", "node": m.ginseng_spot}), "ginseng spot closed after healing")
	m.talk_yongwang(); await settle()
	check(m.king_thanked and m.coins == c0 + 50, "healed king thanks once (+30)")
	m.talk_yongwang(); await settle()
	check(m.coins == c0 + 50, "no second reward")
	var cf := ConfigFile.new()
	cf.load("user://save.cfg")
	check((cf.get_value("ch3", "endings", []) as Array).has("late"), "ending recorded")
	print("DONE")
	get_tree().quit()
