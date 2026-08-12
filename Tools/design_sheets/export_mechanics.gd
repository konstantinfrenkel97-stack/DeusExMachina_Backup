extends SceneTree

func _init() -> void:
	var data := {
		"gods": _scan_units("res://Gods"),
		"enemies": _scan_units("res://Enemies"),
	}
	var json := JSON.stringify(data, "\t", false)
	var f := FileAccess.open("res://Tools/design_sheets/project_mechanics.json", FileAccess.WRITE)
	f.store_string(json)
	f.close()
	quit()

func _scan_units(root_path: String) -> Array:
	var result: Array = []
	_scan_dir(root_path, result)
	return result

func _scan_dir(path: String, result: Array) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name.begins_with("."):
			name = dir.get_next()
			continue
		var full := path.path_join(name)
		if dir.current_is_dir():
			_scan_dir(full, result)
		elif name.to_lower().ends_with(".tres"):
			var res := ResourceLoader.load(full)
			if res is CharacterResource:
				result.append(_unit_to_dict(full, res))
		name = dir.get_next()
	dir.list_dir_end()

func _unit_to_dict(path: String, unit: CharacterResource) -> Dictionary:
	var abilities: Array = []
	for ab in unit.active_abilities:
		if ab != null:
			abilities.append(_ability_to_dict(ab))
	var ult = null
	if unit.ultimate_ability != null:
		ult = _ability_to_dict(unit.ultimate_ability)
	return {
		"path": path,
		"unit_name": unit.unit_name,
		"special_effect_type": unit.special_effect_type,
		"is_enemy": unit.is_enemy,
		"is_large": unit.is_large,
		"max_hp": unit.max_hp,
		"damage": unit.damage,
		"armor": unit.armor,
		"initiative": unit.initiative,
		"accuracy": unit.accuracy,
		"evasion": unit.evasion,
		"crit_chance": unit.crit_chance,
		"abilities": abilities,
		"ultimate": ult,
	}

func _ability_to_dict(ab: AbilityResource) -> Dictionary:
	return {
		"resource_path": ab.resource_path,
		"name": ab.name,
		"description": ab.description,
		"damage_modifier": ab.damage_modifier,
		"majesty_gain": ab.majesty_gain,
		"majesty_cost": ab.majesty_cost,
		"target_type": ab.target_type,
		"extra_targets_count": ab.extra_targets_count,
		"effect_types": ab.effect_types,
		"effect_values": ab.effect_values,
		"effect_durations": ab.effect_durations,
		"damage_type": ab.damage_type,
		"usable_from_positions": ab.usable_from_positions,
		"targetable_positions": ab.targetable_positions,
		"is_stance": ab.is_stance,
		"stance_duration_type": ab.stance_duration_type,
		"stance_effect_type": ab.stance_effect_type,
		"breaks_enemy_stances": ab.breaks_enemy_stances,
		"condition": ab.condition,
		"condition_effect": ab.condition_effect,
		"condition_effect_value": ab.condition_effect_value,
		"condition_effect_duration": ab.condition_effect_duration,
		"ability_marker": ab.ability_marker,
		"mark_type": ab.mark_type,
		"mark_target_team": ab.mark_target_team,
		"mark_position": ab.mark_position,
		"mark_duration": ab.mark_duration,
		"mark_effect_type": ab.mark_effect_type,
		"mark_effect_value": ab.mark_effect_value,
		"mark_effect_duration": ab.mark_effect_duration,
		"mark_damage_percent": ab.mark_damage_percent,
		"mark_damage_type": ab.mark_damage_type,
	}