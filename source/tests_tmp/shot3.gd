extends Node
var m
func _ready() -> void:
	var cf := ConfigFile.new()
	cf.set_value("world", "version", 2)
	cf.set_value("world", "chapter", "ch3")
	cf.set_value("ch3_state", "data", {"quest": 4})
	cf.set_value("ui", "walk_hint_seen", true)
	cf.set_value("ui", "cam_hint_seen", true)
	cf.save("user://save.cfg")
	get_window().size = Vector2i(540, 960)
	m = load("res://chapter3.tscn").instantiate()
	get_tree().root.add_child.call_deferred(m)
	await get_tree().create_timer(5.0).timeout
	if m.in_card:
		if m.card_tween != null:
			m.card_tween.kill()
		m.end_card()
	await get_tree().create_timer(1.0).timeout
	var S := OS.get_environment("SHOT")
	var i := 0
	for sc in m.schools:
		for v in 2:
			var cam := Camera3D.new()
			m.add_child(cam)
			var mm: MultiMesh = sc[0]
			var fp: Vector3 = mm.get_instance_transform(0).origin
			var fb: Basis = mm.get_instance_transform(0).basis
			if v == 0:
				cam.position = fp + fb.z.normalized() * 0.9 + fb.x.normalized() * 1.0 + Vector3(0, 0.7, 0)
			else:
				cam.position = fp + fb.z.normalized() * 1.3 + Vector3(0, 0.15, 0)
			cam.look_at(fp)
			cam.make_current()
			m.set_process(false)
			await get_tree().create_timer(0.3).timeout
			get_viewport().get_texture().get_image().save_png(S + "_%d_%d.png" % [i, v])
			m.set_process(true)
			cam.queue_free()
		i += 1
	get_tree().quit()
