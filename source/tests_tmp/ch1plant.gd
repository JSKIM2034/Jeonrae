extends Node
# 모내기 테스트 (흥부네): 손이 있던 자리에 모가 심기는지(어긋난 방향과 거리, 화면 크기와 상관없이),
# 벼 포기 모양(어린 모·푸른 벼·누런 벼)이 입체 메시인지, 12포기를 다 심으면 끝나는지
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
func _ready() -> void:
	var cf := ConfigFile.new()
	cf.set_value("world", "version", 2)
	cf.set_value("world", "chapter", "ch1")
	cf.save("user://save.cfg")
	m = load("res://main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(m)
	await get_tree().create_timer(2.5).timeout
	await settle()
	await run()
	print("DONE fails=%d" % fails)
	get_tree().quit()
func run() -> void:
	check(m.farm_stages.size() == 3, "three farm stages")
	var mm_ok := true
	for s in m.farm_stages:
		for ch in (s as Node3D).get_children():
			mm_ok = mm_ok and ch is MultiMeshInstance3D and (ch as MultiMeshInstance3D).multimesh.instance_count > 20
	check(mm_ok, "farm stages are multimesh rice clumps")
	for st in 3:
		check(m.rice_mesh(st, 0).get_faces().size() > 300, "rice mesh stage %d has real blades" % st)
	m.player.position = m.FARM_C + Vector3(-3.0, 0.2, 1.2)
	m.farm_state = 0
	m.farm_action()
	await get_tree().create_timer(1.0).timeout
	check(m.mg_active and m.mg_type == "plant", "planting game started")
	var tries := 0
	var planted := 0
	while m.mg_count < 12 and tries < 20000:
		tries += 1
		await get_tree().process_frame
		if not m.mg_active:
			break
		var row: int = m.mg_count / 4
		var target: Vector2 = m.plant_slot(row, m.mg_count % 4)
		var off: float = m.plant_cursor_x() - target.x
		var want: float = m.mg_overlay.size.x * (0.035 if planted % 2 == 0 else -0.035)
		if absf(off - want) < m.mg_overlay.size.x * 0.008:
			m.plant_tap()
			planted += 1
	await get_tree().process_frame
	var nodes: Array = m.w.get("planted", [])
	var near_ok := nodes.size() >= 4
	var dir_ok := true
	for k in mini(nodes.size(), m.mg_items.size()):
		var it: Array = m.mg_items[k]
		var slot: Vector3 = m.plant_world_pos(it[0], it[1])
		var dz: float = (nodes[k] as Node3D).global_position.z - slot.z
		near_ok = near_ok and absf(dz) < 0.16
		# 손이 오른쪽(다음 칸 쪽)으로 비켜 있었으면 다음 칸 쪽으로 심겨요
		var nxt: Vector3 = m.plant_world_pos(it[0], int(it[1]) + 1)
		dir_ok = dir_ok and (signf(dz) == signf(nxt.z - slot.z)) == (float(it[2]) > 0.0)
	check(near_ok, "seedlings land within a hand's width of the mark (%d planted)" % nodes.size())
	check(dir_ok, "seedlings land on the side where the hand was")
	await get_tree().create_timer(3.0).timeout
	await settle()
	check(m.farm_state == 1 or m.mg_count >= 12, "all 12 planted (state %d)" % m.farm_state)
