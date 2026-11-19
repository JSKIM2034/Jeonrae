extends Node
var m
var shots := OS.get_environment("SHOTS") == "1"
func _ready() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.cfg"))
	get_window().size = Vector2i(480, 854)
	m = load("res://chapter2.tscn").instantiate()
	add_child(m)
	run()
func wait(s: float) -> void:
	await get_tree().create_timer(s).timeout
func snap(name: String) -> void:
	if not shots:
		return
	for f in 4:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/ch2_%s.png" % name)
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
	await wait(2.6)
	await snap(name)
	m.end_game(true)
	await settle()
func go(x: float, z: float) -> void:
	m.player.position = m.on_ground(x, z, 0.3)
	m.player.velocity = Vector3.ZERO
	await wait(0.6)
	await settle()
func run() -> void:
	await wait(2.5)
	await settle()
	m.cam_hint_seen = true
	await snap("start")
	m.talk_to("mom"); await settle()
	print("Q after mom ", m.quest)
	m.talk_to("host"); await settle()
	m.start_pound(); await game("pound")
	m.talk_to("cook"); await settle(); await game("tteok")
	for g in ["guest1", "guest2", "guest3"]:
		m.talk_to(g); await settle()
	print("feast ", m.feast, " deliv ", m.delivered.size())
	m.talk_to("mom"); await settle()
	print("Q leave ", m.quest, " follow ", m.mom_follow)
	await go(-5, 10)
	await wait(1.0)
	await snap("follow")
	await go(-8, 2)
	await settle()
	print("Q after pass1 ", m.quest)
	await go(9, -30)
	await go(10, -36)
	await game("paws")
	print("Q after pass2 ", m.quest)
	await go(-6, -66)
	await go(-7, -73)
	await settle()
	print("Q run ", m.quest, " run_active ", m.run_active)
	await wait(1.5)
	await snap("run")
	await go(5, -101)
	await settle()
	print("Q warn ", m.quest)
	m.talk_to("oppa"); await settle()
	print("Q door ", m.quest)
	await go(6, -99)
	await snap("door")
	m.talk_to("oppa"); await settle()
	print("Q tree ", m.quest)
	m.start_climb(); await game("climb")
	await game("rope")
	await wait(4.0)
	await settle()
	await wait(4.0)
	await settle()
	await wait(1.0)
	await settle()
	print("Q end ", m.quest, " ending ", m.ending)
	await go(18, -104)
	await snap("end")
	print("STORY OK ", m.quest == 10)
	get_tree().quit()
