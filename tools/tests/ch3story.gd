extends Node
var m
var shots := OS.get_environment("SHOTS") == "1"
func _ready() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.cfg"))
	get_window().size = Vector2i(480, 854)
	m = load("res://chapter3.tscn").instantiate()
	add_child(m)
	run()
func wait(s: float) -> void:
	await get_tree().create_timer(s).timeout
func snap(name: String) -> void:
	if not shots:
		return
	for f in 4:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/ch3_%s.png" % name)
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
func game(name: String) -> void:
	var g := 0
	while not m.mg_active and g < 200:
		g += 1
		await get_tree().process_frame
	m.mg_lives = 99
	print("GAME ", name, " active=", m.mg_active, " type=", m.mg_type, " scene=", m.w.get("scene", ""))
	for k in 14:
		await wait(0.18)
		var ev := InputEventScreenTouch.new()
		ev.pressed = true
		ev.position = Vector2(120 + (k % 2) * 300, 500)
		m.on_mg_input(ev)
		var ev2 := InputEventScreenTouch.new()
		ev2.pressed = false
		ev2.position = ev.position
		m.on_mg_input(ev2)
	m.mg_lives = 99
	print("  count ", m.mg_count, " lives ", m.mg_lives)
	await snap(name)
	m.end_game(true)
	await settle()
func touch(pos: Vector2, down: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.pressed = down
	ev.position = pos
	m.on_mg_input(ev)
func dig_game() -> void:
	var g := 0
	while not m.mg_active and g < 200:
		g += 1
		await get_tree().process_frame
	print("GAME dig ", m.mg_type)
	var kinds := {}
	var shot := false
	for f in 3000:
		if not m.mg_active:
			break
		await get_tree().process_frame
		var tg: Dictionary = m.cg.get("tgt", {})
		if tg.is_empty() or tg["state"] != "up":
			continue
		var pos: Vector2 = m.cam.unproject_position(m.dig_holes()[int(tg["i"])])
		kinds[tg["kind"]] = true
		if not shot and tg["kind"] == "big":
			shot = true
			touch(pos, true); touch(pos, false)
			await wait(0.1)
			await snap("clam")
		match tg["kind"]:
			"crab":
				pass
			"razor":
				touch(pos, true)
				var dr := InputEventScreenDrag.new()
				dr.position = pos - Vector2(0, 200)
				m.on_mg_input(dr)
				touch(pos - Vector2(0, 200), false)
			_:
				touch(pos, true); touch(pos, false)
				await wait(0.05)
	print("  dig count ", m.mg_count, " lives ", m.mg_lives, " kinds ", kinds.keys(), " active ", m.mg_active)
	await settle()
func go(p: Vector3) -> void:
	m.player.position = p
	m.player.velocity = Vector3.ZERO
	await wait(0.5)
	await settle()
func act_at(p: Vector3) -> void:
	await go(p)
	await wait(0.3)
	m.current_thing = m.find_thing()
	m.on_action()
	await settle()
func run() -> void:
	await wait(2.5)
	await settle()
	m.cam_hint_seen = true
	await snap("beach")
	m.talk_to("jara"); await settle()
	print("Q find ", m.quest)
	var rb: Vector3 = m.npc("rabbit").position
	await go(m.on_ground(rb.x + 5.0, rb.z + 5.0, 0.3))
	await wait(1.2)
	await snap("rabbit")
	var rb2: Vector3 = m.npc("rabbit").position
	print("rabbit fled ", rb.distance_to(rb2))
	# 토끼는 세 번 잡아야 항복해요 (두 번은 쏙 빠져나가요)
	for k in 6:
		if m.quest != m.S_FIND:
			break
		m.player.position = m.npc("rabbit").position + Vector3(0.4, 0.3, 0.4)
		await wait(1.2)
		await settle()
	print("rabbit catches ", m.rabbit_catches)
	print("Q lure ", m.quest, " follow ", m.follow_on)
	m.talk_to("haenyeo"); await settle()
	m.start_clam(); await dig_game()
	m.talk_to("haenyeo"); await settle()
	print("mulji on ", m.dive_on)
	await go(m.on_ground(22, -11, 0.4)); await wait(1.0); await snap("mulji")
	for it in m.mulji_items:
		await go((it[0] as Node3D).position + Vector3(0, 0.2, 0))
		await wait(0.2)
	await settle()
	print("mulji done ", m.mulji_done, " got ", m.mulji_got, " wall ", m.sea_wall.disabled)
	await act_at(m.on_ground(m.GINSENG_POS.x + 0.5, m.GINSENG_POS.z + 0.5, 0.3))
	print("ginseng ", m.has_ginseng)
	await go(m.on_ground(m.JARA_BEACH.x - 1.0, m.JARA_BEACH.z + 2.0, 0.3))
	m.talk_to("jara"); await settle()
	print("Q dive ", m.quest)
	await go(Vector3(0, -2.0, -9))
	await wait(1.0)
	await snap("dive")
	for rg in m.rings:
		await go((rg[0] as Node3D).position + Vector3(0, -0.7, 0))
	await settle()
	print("Q deep ", m.quest, " swimming ", m.swimming)
	await go(Vector3(-4, -2, -14)); await wait(1.5); await snap("reef")
	await go(Vector3(2, -7, -52)); await wait(1.0); await snap("kelp")
	await go(m.on_ground(m.OCTO_PTS[0].x + 2.5, m.OCTO_PTS[0].z + 2.5, 0.6)); await wait(0.6); await snap("octo")
	for o in m.octos:
		await go((o[0] as Node3D).position + Vector3(0, 0.1, 0.3))
		await wait(0.3)
	print("octo ", m.octo_count())
	await act_at(m.chest_c + Vector3(0.4, 0.5, 0.8))
	await game("chest")
	print("chest ", m.chest_done)
	for i in 3:
		var sp2: Vector3 = m.WRECK_C + [Vector3(2.4, 0, 2.2), Vector3(-2.6, 0, -1.4), Vector3(0.8, 0, -4.6)][i]
		await act_at(m.on_ground(sp2.x + 0.6, sp2.z + 0.6, 0.6))
	print("pearls ", m.pearls)
	await go(Vector3(0, -9, -80)); await wait(1.0); await snap("valley")
	await go(Vector3(0, m.PALACE_Y + 3.0, -100)); await wait(1.5); await snap("palace2")
	await go(Vector3(0, m.PALACE_Y + 1.0, -97)); await wait(0.5); await settle()
	print("Q gate ", m.quest)
	m.talk_to("flatfish"); await settle()
	await game("sand")
	print("Q court ", m.quest)
	await go(Vector3(0, m.PALACE_Y + 1.0, -106)); await wait(1.5); await snap("palace")
	m.talk_to("yongwang"); await settle()
	print("Q feast ", m.quest)
	m.talk_to("crab"); await settle(); await game("drum")
	m.talk_to("octopus"); await settle(); await game("pearl")
	m.talk_to("jara"); await settle(); await game("dance")
	print("feast ", m.feast_flags)
	m.talk_to("yongwang"); await settle()
	print("Q escape ", m.quest)
	await wait(4.5)
	await snap("chase")
	await go(Vector3(0, -12, -86)); await wait(1.5)
	print("ink ", m.ink_fired, " amt ", m.ink_amt)
	await snap("ink")
	await go(m.on_ground(0, -3, 0.3))
	await wait(1.0)
	await settle()
	await wait(3.0)
	await settle()
	print("Q end ", m.quest, " ending ", m.ending)
	await snap("end")
	print("STORY3 OK ", m.quest == 9)
	get_tree().quit()
