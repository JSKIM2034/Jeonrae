extends Node
func _ready() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.cfg"))
	var m = load("res://chapter2.tscn").instantiate()
	add_child(m)
	await get_tree().create_timer(3.0).timeout
	print("CH2 OK ", m.player != null)
	get_tree().quit()
