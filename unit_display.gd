extends Area2D

signal unit_clicked(unit)
var associated_combatant: Combatant

func setup(unit: Combatant, sprite_path: String):
	associated_combatant = unit
	# Проверка, что путь к файлу существует
	if ResourceLoader.exists(sprite_path):
		$Sprite2D.texture = load(sprite_path)
	else:
		push_warning("Картинка не найдена по пути: " + sprite_path)

func _input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		emit_signal("unit_clicked", associated_combatant) # Отправляем данные о бойце[cite: 10]
