extends Node
# 1장 공용 저장 테스트: 1장 도감 저장이 [common] book 에, 1장 엔딩이 [common] endings 에 들어가는지
var m
func check(ok: bool, what: String) -> void:
	print(("OK   " if ok else "FAIL ") + what)
func cfg() -> ConfigFile:
	var cf := ConfigFile.new()
	cf.load("user://save.cfg")
	return cf
func _ready() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.cfg"))
	m = load("res://main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(m)
	await get_tree().create_timer(2.0).timeout
	m.fish_caught[3] = 2
	m.herb_counts[1] = 3
	m.story_read[4] = true
	m.save_south()
	var book: Dictionary = cfg().get_value("common", "book", {})
	check(int(book.get("ch1_fish", [])[3]) == 2 and int(book.get("ch1_herbs", [])[1]) == 3 and book.get("ch1_story", [])[4], "ch1 book saved to common")
	check(not cfg().has_section("ch1"), "no old [ch1] section written")
	check(m.fish_kinds_found() == 1 and m.herb_kinds_done() == 1 and m.story_count() == 1, "counts from core")
	m.finish_chapter("greed")
	var en: Dictionary = cfg().get_value("common", "endings", {})
	check(en.get("ch1", []) == ["greed"], "ch1 ending recorded")
	check((cfg().get_value("common", "tales_done", []) as Array).has("ch1"), "ch1 done")
	check(m.card_label.text.contains("1/4"), "card shows 1/4")
	print("DONE")
	get_tree().quit()
