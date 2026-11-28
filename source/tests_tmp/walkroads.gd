extends Node
# 걸어서 오가기 테스트: 길 끝(나가는 곳)에 걸어 들어가면 다음 지역으로, 길 열리는 순서, 떠날 수 없는 때
# 새 게임(이야기골) -> 돌고개는 안개(막힘) -> 버드나무 길 끝 -> 흥부네 -> 흥부와 놀부 결말 -> 남쪽 길 끝 -> 이야기골
# -> 돌고개 길 끝 -> 오누이 고갯길(엄마와 걷는 중엔 막힘) -> 이야기골 -> 갈대 나루(막힘) -> 오누이 결말 -> 바닷가 -> 이야기골
var m
var fails := 0
func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
	print(("OK   " if ok else "FAIL ") + what)
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
func wait_scene(id: String) -> bool:
	for i in 900:
		await get_tree().process_frame
		var cs = get_tree().current_scene
		if cs != null and cs.has_method("chapter_id") and cs.chapter_id() == id and cs.player != null and cs.cam != null and not cs.leaving_scene:
			await get_tree().create_timer(0.5).timeout
			m = get_tree().current_scene
			await settle()
			return true
	m = get_tree().current_scene
	return false
func exit_to(to: String) -> Dictionary:
	for e in m.exits:
		if e["to"] == to:
			return e
	return {}
# 길 끝 바깥에서 한 번 서 있다가(켜기) 길 끝 한가운데로 걸어 들어가요
func step_into(to: String) -> void:
	var e := exit_to(to)
	var c: Vector2 = e["c"]
	var y: float = m.player.position.y
	m.player.position = Vector3(c.x, y, c.y) + Vector3(0, 0, 0).lerp(Vector3(6, 0, 6), 1.0)
	for i in 5:
		await get_tree().process_frame
	m.player.position = Vector3(c.x, y + 0.2, c.y)
	for i in 5:
		await get_tree().process_frame
func _ready() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.cfg"))
	m = load("res://home.tscn").instantiate()
	get_tree().root.add_child.call_deferred(m)
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().current_scene = m
	await get_tree().create_timer(2.0).timeout
	await settle()
	await run()
	print("DONE fails=%d" % fails)
	get_tree().quit()
func run() -> void:
	check(m.chapter_id() == "home", "new game starts in home")
	check(m.exits.size() == 4, "home has 4 road ends")
	check(not m.road_open("ch2") and not m.road_open("ch3") and m.road_open("ch1"), "only willow road open")
	# 막힌 돌고개
	await step_into("ch2")
	check(m.talking and not m.leaving_scene, "fog road blocks with a message")
	var c2: Vector2 = exit_to("ch2")["c"]
	check(Vector2(m.player.position.x, m.player.position.z).distance_to(c2) > exit_to("ch2")["r"], "pushed back out of the road end")
	await settle()
	# 이정표로 물어봐도 막혀요
	m.try_go("ch2")
	check(m.talking and not m.leaving_scene, "signpost also says fog")
	await settle()
	# 버드나무 길 끝 -> 흥부네
	await step_into("ch1")
	check(m.leaving_scene and m.card_label.text.contains(m.tr("버드나무 길을 따라\n흥부네 마을로...")), "willow road card")
	check(await wait_scene("ch1"), "walked into Heungbu's village")
	check(m.player.position.distance_to(Vector3(-2, 0.3, 29)) < 1.5, "arrived inside south road")
	check(m.exits.size() == 1, "ch1 has south road end")
	# 도착하자마자 다시 나가지 않아요
	for i in 30:
		await get_tree().process_frame
	check(not m.leaving_scene, "no instant bounce")
	m.record_ending("ch1", "original")
	check(m.road_open("ch2"), "ch1 ending opens stone hill road")
	await step_into("home")
	check(await wait_scene("home"), "back to home by walking")
	check(m.player.position.distance_to(Vector3(-23.5, 0.3, -19.3)) < 1.5, "arrived at willow road entrance")
	await step_into("ch2")
	check(await wait_scene("ch2"), "stone hill road to Mountain Road")
	check(absf(m.player.position.z - 46.0) < 1.5, "arrived at ch2 south")
	# 엄마와 걷는 중엔 못 떠나요
	m.mom_follow = true
	await step_into("home")
	check(not m.leaving_scene and m.talking, "can't leave while walking with mom")
	await settle()
	m.mom_follow = false
	await step_into("home")
	check(await wait_scene("home"), "ch2 south road end back home")
	check(m.player.position.distance_to(Vector3(0.8, 0.3, -25.5)) < 1.5, "arrived at stone hill entrance")
	await step_into("ch3")
	check(not m.leaving_scene, "reed ferry still foggy")
	await settle()
	m.record_ending("ch2", "oppa_sun")
	check(m.road_open("ch3"), "ch2 ending opens reed ferry")
	await step_into("ch3")
	check(await wait_scene("ch3"), "reed ferry to Seaside Village")
	await step_into("home")
	check(await wait_scene("home"), "seaside south road end back home")
	check(m.player.position.distance_to(Vector3(23.0, 0.3, -15.0)) < 1.5, "arrived at reed ferry entrance")
	await step_into("fog")
	check(not m.leaving_scene and m.talking, "south fog road closed")
	await settle()
	var roads: Array = (func():
		var cf := ConfigFile.new()
		cf.load("user://save.cfg")
		return cf.get_value("common", "roads_open", [])).call()
	check(roads.has("ch1") and roads.has("ch2") and roads.has("ch3"), "visited roads saved")
