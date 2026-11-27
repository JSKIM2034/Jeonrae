extends Node
# 미니게임 단계 테스트: 단계마다 값이 바뀌고(목표·빠르기·제목), 남은 기회가 이어지고,
# 단계 사이엔 잠깐 멈추고(누르기 무시), 마지막 단계를 이겨야 끝 콜백이 한 번 불려요. 지면 처음 단계부터.
var m
var fails := 0
var done_calls: Array = []
func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
	print(("OK   " if ok else "FAIL ") + what)
func _ready() -> void:
	var cf := ConfigFile.new()
	cf.set_value("world", "version", 2)
	cf.set_value("world", "chapter", "home")
	cf.set_value("home", "data", {"met": true})
	cf.save("user://save.cfg")
	m = load("res://home.tscn").instantiate()
	get_tree().root.add_child.call_deferred(m)
	await get_tree().create_timer(2.5).timeout
	m.cam_hint_seen = true
	await run()
	print("DONE fails=%d" % fails)
	get_tree().quit()
func on_done(ok: bool, perfect: bool) -> void:
	done_calls.append([ok, perfect])
func cfg() -> Dictionary:
	return {"title": "T", "goal": 5, "interval": 0.6, "speed": 0.4, "bad_ratio": 0.3, "good": "a", "bad": "b", "basket": "c",
		"rounds": [{"goal": 7, "interval": 0.5, "title": "T2", "round_text": "R2"}, {"goal": 9, "speed": 0.5, "round_text": "R3"}]}
func run() -> void:
	m.start_game("catch", cfg(), on_done)
	check(m.mg_active and m.mg_round == 0 and m.mg_round_total == 3, "round 1 of 3")
	check(m.mg_title.text.begins_with("[1/3]"), "title shows round")
	m.mg_lives = 2
	m.mg_perfect = false
	m.end_game(true)
	check(m.mg_active and m.mg_round == 1 and done_calls.is_empty(), "won round 1 -> round 2, no finish yet")
	check(int(m.mg_cfg["goal"]) == 7 and is_equal_approx(float(m.mg_cfg["interval"]), 0.5) and is_equal_approx(float(m.mg_cfg["speed"]), 0.4), "round 2 values")
	check(m.mg_title.text.contains("T2") and m.mg_title.text.begins_with("[2/3]"), "round 2 title")
	check(m.mg_lives == 2 and not m.mg_perfect, "lives and perfect carry over")
	check(m.mg_hold > 1.0, "short pause before round 2")
	var c0: int = m.mg_count
	var ev := InputEventScreenTouch.new()
	ev.pressed = true
	ev.position = Vector2(100, 400)
	m.on_mg_input(ev)
	check(not m.mg_touch, "input ignored during pause")
	await get_tree().create_timer(2.3).timeout
	check(m.mg_hold <= 0.0 and m.mg_active, "pause ends, game runs")
	m.end_game(true)
	check(m.mg_round == 2 and int(m.mg_cfg["goal"]) == 9 and is_equal_approx(float(m.mg_cfg["speed"]), 0.5) and is_equal_approx(float(m.mg_cfg["interval"]), 0.6), "round 3 values from base + its own")
	check(m.mg_title.text.contains("T") and m.mg_title.text.begins_with("[3/3]"), "round 3 title falls back to base")
	m.end_game(true)
	check(not m.mg_active and done_calls.size() == 1 and done_calls[0][0] == true, "finish called once after last round")
	# 지면 처음부터
	done_calls.clear()
	m.start_game("catch", cfg(), on_done)
	m.end_game(true)
	m.end_game(false)
	check(not m.mg_active and done_calls.size() == 1 and done_calls[0][0] == false, "losing in round 2 ends the game")
	m.start_game("catch", cfg(), on_done)
	check(m.mg_round == 0 and int(m.mg_cfg["goal"]) == 5 and m.mg_title.text.begins_with("[1/3]"), "retry starts from round 1")
	m.end_game(false)
	# 단계 없는 놀이는 그대로
	done_calls.clear()
	m.start_game("catch", {"title": "Solo", "goal": 3, "interval": 0.6, "speed": 0.4, "bad_ratio": 0.3, "good": "a", "bad": "b", "basket": "c"}, on_done)
	check(m.mg_title.text == "Solo" and m.mg_round_total == 1, "single round game unchanged")
	m.end_game(true)
	check(done_calls.size() == 1 and done_calls[0][0], "single round finishes at once")
	await get_tree().create_timer(0.5).timeout
