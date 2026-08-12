extends Resource
class_name Reward

## Награда за выбор в миссии: предмет / валюта / бог.

enum Kind { ITEM, ESSENCE, GOD, CURRENCY }

@export var kind: Kind = Kind.ITEM
# Ресурс награды: ItemResource / EssenceResource / ThoughtsResource / CharacterResource.
@export var resource: Resource
# Количество для валют.
@export var amount: int = 1


## Применяет награду: выдаёт предмет / добавляет валюту / открывает бога.
func grant() -> void:
	if resource == null:
		return
	var path: String = resource.resource_path
	match kind:
		Kind.ITEM:
			CampaignState.add_item(path)
		Kind.ESSENCE, Kind.CURRENCY:
			CampaignState.add_currency_amount(path, amount)
		Kind.GOD:
			CampaignState.add_god(path)