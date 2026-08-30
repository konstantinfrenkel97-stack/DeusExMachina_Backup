extends Resource
class_name Reward

## Награда за выбор в миссии: предмет / валюта / бог.

enum Kind { ITEM, ESSENCE, GOD, CURRENCY }

@export var kind: Kind = Kind.ITEM
# Ресурс награды: ItemResource / EssenceResource / ThoughtsResource / CharacterResource.
@export var resource: Resource
# Количество для валют.
@export var amount: int = 1
# Для наград вида "случайный предмет": если resource пустой, берется случайный ItemResource
# из random_item_root с указанными типом и редкостью.
@export var use_random_item_type: bool = false
@export var random_item_type: ItemResource.ItemType = ItemResource.ItemType.WEAPON
@export var use_random_item_rarity: bool = false
@export var random_item_rarity: ItemResource.Rarity = ItemResource.Rarity.COMMON
@export_dir var random_item_root: String = "res://Items"


## Применяет награду: выдаёт предмет / добавляет валюту / открывает бога.
func grant() -> void:
	grant_resolved(resolve_resource())

func resolve_resource() -> Resource:
	if resource != null:
		return resource
	if kind == Kind.ITEM and (use_random_item_type or use_random_item_rarity):
		return _pick_random_item()
	return null

func display_name() -> String:
	if resource != null:
		for prop in ["name", "item_name", "unit_name", "display_name"]:
			var value: String = str(_resource_prop(resource, prop, "")).strip_edges()
			if value != "":
				return value
	if kind == Kind.ITEM and (use_random_item_type or use_random_item_rarity):
		var parts: Array[String] = ["Случайный предмет"]
		if use_random_item_rarity:
			parts.append(_rarity_name(random_item_rarity))
		if use_random_item_type:
			parts.append(_item_type_name(random_item_type))
		return " ".join(parts)
	return "Награда"

func _resource_prop(res: Resource, prop_name: String, default_value = null):
	for prop in res.get_property_list():
		if str(prop.get("name", "")) == prop_name:
			return res.get(prop_name)
	return default_value

func grant_resolved(resolved_resource: Resource) -> void:
	if resolved_resource == null:
		return
	var path: String = resolved_resource.resource_path
	match kind:
		Kind.ITEM:
			CampaignState.add_item(path)
		Kind.ESSENCE, Kind.CURRENCY:
			CampaignState.add_currency_amount(path, amount)
		Kind.GOD:
			CampaignState.add_god(path)

func _pick_random_item() -> Resource:
	var item_paths: Array[String] = []
	_collect_item_paths(random_item_root, item_paths)
	var matches: Array[ItemResource] = []
	for path in item_paths:
		var item := load(path) as ItemResource
		if item == null:
			continue
		if use_random_item_type and item.item_type != random_item_type:
			continue
		if use_random_item_rarity and item.rarity != random_item_rarity:
			continue
		matches.append(item)
	if matches.is_empty():
		return null
	return matches[randi_range(0, matches.size() - 1)]

func _item_type_name(item_type: ItemResource.ItemType) -> String:
	match item_type:
		ItemResource.ItemType.WEAPON:
			return "оружие"
		ItemResource.ItemType.ARMOR:
			return "броня"
		ItemResource.ItemType.TRINKET:
			return "безделушка"
	return "предмет"

func _rarity_name(rarity: ItemResource.Rarity) -> String:
	match rarity:
		ItemResource.Rarity.COMMON:
			return "обычная"
		ItemResource.Rarity.RARE:
			return "редкая"
		ItemResource.Rarity.EPIC:
			return "эпическая"
		ItemResource.Rarity.LEGENDARY:
			return "легендарная"
		ItemResource.Rarity.UNIQUE:
			return "уникальная"
	return ""

func _collect_item_paths(dir_path: String, out_paths: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not file_name.begins_with("."):
			var child_path := dir_path.path_join(file_name)
			if dir.current_is_dir():
				_collect_item_paths(child_path, out_paths)
			elif file_name.get_extension().to_lower() == "tres":
				out_paths.append(child_path)
		file_name = dir.get_next()
	dir.list_dir_end()
