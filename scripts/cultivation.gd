extends RefCounted

const REALMS = ["Mortal", "Qi Awakening", "Foundation", "Golden Core"]
const COSTS = [30, 75, 140]
const HAIRSTYLES = ["Loose black hair", "High ponytail", "Silver bob", "Twin buns"]
const CLOTHING = ["Jade sect robes", "Ivory hanfu", "Crimson battle tunic", "Indigo traveling robes"]
const WEAPONS = ["Jade sword", "Scarlet saber", "Lotus war fan", "Meridian staff"]
var hair: int = 0
var clothing: int = 0
var weapon: int = 0
var realm: int = 0
var qi: int = 0
var herbs: int = 0
var seals: int = 0
var health: float = 100.0
var stamina: float = 100.0
var quest: int = 0
var defeated: int = 0
var ending: String = ""

func cultivate() -> bool:
	if realm >= COSTS.size() or qi < COSTS[realm]:
		return false
	qi -= COSTS[realm]
	realm += 1
	health = max_health()
	return true

func max_health() -> float:
	return 100.0 + realm * 30.0

func damage() -> float:
	return (22.0 + realm * 14.0) * [1.0, 1.25, .85, .9][weapon]

func appearance_row() -> int:
	return hair * 4 + clothing

func to_dict() -> Dictionary:
	return {"realm": realm, "qi": qi, "herbs": herbs, "seals": seals, "health": health, "quest": quest, "defeated": defeated, "ending": ending, "appearance": {"hair": hair, "clothing": clothing, "weapon": weapon}}

func restore(data: Dictionary) -> void:
	realm = clampi(int(data.get("realm", 0)), 0, 3)
	qi = maxi(0, int(data.get("qi", 0)))
	herbs = maxi(0, int(data.get("herbs", 0)))
	seals = clampi(int(data.get("seals", 0)), 0, 3)
	health = clampf(float(data.get("health", 100)), 1, max_health())
	quest = clampi(int(data.get("quest", 0)), 0, 4)
	defeated = maxi(0, int(data.get("defeated", 0)))
	ending = str(data.get("ending", ""))
	var appearance = data.get("appearance", {})
	if appearance is Dictionary:
		hair = clampi(int(appearance.get("hair", 0)), 0, 3)
		clothing = clampi(int(appearance.get("clothing", 0)), 0, 3)
		weapon = clampi(int(appearance.get("weapon", 0)), 0, 3)
