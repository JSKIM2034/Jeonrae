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
	print("GAME ", name, " active=", m.mg_active, " scene=", m.w.get("scene", ""))
	await wait(2.4)
	await snap(name)
	m.end_game(true)
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
	for k in 4:
		var sp: Vector3 = m.RABBIT_SPOTS[k]
		await go(m.on_ground(sp.x + 3.0, sp.z + 3.0, 0.3))
		await wait(2.0)
	await snap("rabbit")
	m.talk_to("rabbit"); await settle()
	print("Q lure ", m.quest, " follow ", m.follow_on)
	m.talk_to("haenyeo"); await settle()
	m.start_clam(); await game("clam")
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
	await go(Vector3(-4, -4, -18)); await wait(1.0); await snap("reef")
	await go(Vector3(2, -7, -52)); await wait(1.0); await snap("kelp")
	for i in 3:
		var sp2: Vector3 = m.WRECK_C + [Vector3(2.4, 0, 2.2), Vector3(-2.6, 0, -1.4), Vector3(0.8, 0, -4.6)][i]
		await act_at(m.on_ground(sp2.x + 0.6, sp2.z + 0.6, 0.6))
	print("pearls ", m.pearls)
	await go(Vector3(0, -9, -80)); await wait(1.0); await snap("valley")
	await go(Vector3(0, m.PALACE_Y + 1.0, -97)); await wait(0.5); await settle()
	print("Q gate ", m.quest)
	m.talk_to("flatfish"); await settle()
	print("Q court ", m.quest)
	await go(Vector3(0, m.PALACE_Y + 1.0, -106)); await wait(1.5); await snap("palace")
	m.talk_to("yongwang"); await settle()
	print("Q feast ", m.quest)
	m.talk_to("crab"); await settle(); await game("drum")
	m.talk_to("octopus"); await settle(); await game("pearl")
	m.talk_to("yongwang"); await settle()
	print("Q escape ", m.quest)
	await wait(4.5)
	await snap("chase")
	await go(m.on_ground(0, -3, 0.3))
	await wait(1.0)
	await settle()
	await wait(3.0)
	await settle()
	print("Q end ", m.quest, " ending ", m.ending)
	await snap("end")
	print("STORY3 OK ", m.quest == 9)
	get_tree().quit()
