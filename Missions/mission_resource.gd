extends Resource
class_name MissionResource

enum Location {
	HELHEIM,
	HELL,
	TUNNELS,
	CLOUDS,
	STARS,
	MOUNTAINS,
	ARENA,
	CASTLE,
	DESERT,
	DEPTHS,
	ISLAND,
	SHIPS,
	JUNGLE,
	GARDEN,
	SWAMP,
	HOME,
	BOOK,
	NONE
}

const LOCATION_IDS: Array[String] = [
	"helheim", "hell", "tunnels", "clouds", "stars", "mountains",
	"arena", "castle", "desert", "depths", "island", "ships",
	"jungle", "garden", "swamp", "home", "book"
]

enum RequiredGod {
	NONE,
	CHERNOBOG,
	DUNA,
	HADES,
	KOSCHEI,
	LOKI,
	MORGAN,
	ODIN,
	OSIRIS,
	POSEIDON,
	SAMDI,
	SET,
	SHIVA,
	SUSANOO,
	THOR,
	ZEUS
}

const REQUIRED_GOD_PATHS: Array[String] = [
	"",
	"res://Gods/Chernobog/Chernobog.tres",
	"res://Gods/Duna/Duna.tres",
	"res://Gods/Hades/Hades.tres",
	"res://Gods/Koschei/Koschei.tres",
	"res://Gods/Loki/Loki.tres",
	"res://Gods/Morgan/Morgan.tres",
	"res://Gods/Odin/Odin.tres",
	"res://Gods/Osiris/Osiris.tres",
	"res://Gods/Poseidon/Poseidon.tres",
	"res://Gods/Samdi/Samdi.tres",
	"res://Gods/Set/Set.tres",
	"res://Gods/Shiva/Shiva.tres",
	"res://Gods/Susanoo/Susanoo.tres",
	"res://Gods/Thor/thor.tres",
	"res://Gods/Zeus/zeus.tres"
]

@export var mission_name: String = "Миссия"
@export_group("Localization")
@export var mission_name_key: String = ""
@export_group("")
@export var scenes: Array = []
@export var location: Location = Location.NONE
@export var required_god: RequiredGod = RequiredGod.NONE

func get_location_id() -> String:
	if location == Location.NONE:
		return ""
	var idx := location as int
	if idx >= 0 and idx < LOCATION_IDS.size():
		return LOCATION_IDS[idx]
	return ""

func get_required_god_path() -> String:
	var idx := required_god as int
	if idx >= 0 and idx < REQUIRED_GOD_PATHS.size():
		return REQUIRED_GOD_PATHS[idx]
	return ""
