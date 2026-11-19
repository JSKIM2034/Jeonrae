extends "res://core.gd"

# 2장: 해와 달이 된 오누이 (만드는 중)
# 공통 부분(core.gd)을 그대로 쓰고, 맵과 이야기만 여기에 새로 만들어요.

func build_chapter() -> void:
	# 임시 맵: 평평한 들판과 하늘만 있어요. 고개와 마을은 여기에 차례로 지어요.
	make_surface_materials()
	add_box(self, Color(0.42, 0.66, 0.38), Vector3(200, 1, 200), Vector3(0, -0.5, 0)).material_override = ground_mat

func start_chapter() -> void:
	show_card("2장\n해와 달이 된 오누이\n\n(만드는 중이에요)", 1.0, 4.0, Callable())
