extends RefCounted
class_name TormentorLogic

## ИИ Мучителя: если на противниках суммарно 4+ дебаффа, с шансом 70% — «Симфония боли».
## Иначе — другой доступный навык.

static func get_decision(monster: Combatant, heroes: Array) -> Dictionary:
	var usable: Array = []
	var symphony_ab = null
	for ab in monster.active_abilities:
		if ab == null:
			continue
		if ab.usable_from_positions.size() > monster.position_index and ab.usable_from_positions[monster.position_index]:
			usable.append(ab)
			if ab.ability_marker == "tormentor_symphony":
				symphony_ab = ab
	if usable.is_empty():
		return {}
	# Считаем суммарно дебаффов на героях
	var total_debuffs = 0
	for h in heroes:
		if h == null or h.current_hp <= 0:
			continue
		for eff in h.active_effects:
			var st = Combatant._effect_get(eff, "stat", "")
			var v = Combatant._effect_get(eff, "value", 0)
			if st == "periodic_damage" or v < 0:
				total_debuffs += 1
	if symphony_ab != null and total_debuffs >= 4 and randf() < 0.70:
		return {"ability": symphony_ab, "target": monster}
	# Иначе другой навык
	var others = usable.duplicate()
	if symphony_ab != null:
		others.erase(symphony_ab)
	others.shuffle()
	for ab in others:
		if ab.target_type in ["Self", "All_Allies", "All_Enemies"]:
			return {"ability": ab, "target": monster}
		for h in heroes:
			if h and h.current_hp > 0 and Combatant.can_be_targeted_at(h, ab):
				return {"ability": ab, "target": h}
	return {}
