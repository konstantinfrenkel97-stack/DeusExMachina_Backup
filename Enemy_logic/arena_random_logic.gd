extends RefCounted
class_name ArenaRandomLogic

## Универсальный ИИ для юнитов Арены (Новичок, Гладиатор, Гоплит, Кентавр)
## и общий рандомный фоллбэк для других юнитов (Кобольд, Гном-щитовик, Гном-кузнец,
## Голем, Каменные великаны).
## Выбирает случайную доступную способность из текущей позиции и валидную цель.
## allies — команда самого юнита, нужна для способностей с целью Ally/All_Allies.
## exclude — способности, которые нужно пропустить (например, уже рассмотренные по условию).

static func get_decision(monster: Combatant, heroes: Array, allies: Array = [], exclude: Array = []) -> Dictionary:
	var usable: Array = []
	for ab in monster.active_abilities:
		if ab == null or ab in exclude:
			continue
		if _is_usable_from_position(ab, monster.position_index):
			usable.append(ab)
	if usable.is_empty():
		return {}
	usable.shuffle()
	for ab in usable:
		if ab.target_type == "Self":
			return {"ability": ab, "target": monster}
		if ab.target_type == "Ally" or ab.target_type == "All_Allies":
			for a in allies:
				if a and a.current_hp > 0 and a != monster and Combatant.can_be_targeted_at(a, ab):
					return {"ability": ab, "target": a}
			continue
		for h in heroes:
			if h and h.current_hp > 0 and Combatant.can_be_targeted_at(h, ab):
				return {"ability": ab, "target": h}
	return {}


static func _is_usable_from_position(ab: AbilityResource, pos: int) -> bool:
	if ab.usable_from_positions.size() > pos:
		return ab.usable_from_positions[pos]
	return true
