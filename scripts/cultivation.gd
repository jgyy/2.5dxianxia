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
	if realm < 0 or realm >= COSTS.size() or qi < COSTS[realm]:
		return false
	qi -= COSTS[realm]
	realm += 1
	health = max_health()
	return true

func max_health() -> float:
	return 100.0 + clampi(realm, 0, 3) * 30.0

func damage() -> float:
	return (22.0 + clampi(realm, 0, 3) * 14.0) * [1.0, 1.25, .85, .9][clampi(weapon, 0, 3)]

func appearance_row() -> int:
	return clampi(hair, 0, 3) * 4 + clampi(clothing, 0, 3)

func to_dict() -> Dictionary:
	return {"realm": realm, "qi": qi, "herbs": herbs, "seals": seals, "health": health, "stamina": stamina, "quest": quest, "defeated": defeated, "ending": ending, "appearance": {"hair": hair, "clothing": clothing, "weapon": weapon}}

static func number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func integer(value: Variant, low: int, high: int) -> bool:
	return number(value) and float(value) == floorf(float(value)) and float(value) >= low and float(value) <= high

static func valid_data(data: Dictionary) -> bool:
	var limits = {"realm": 3, "qi": 1000000000, "herbs": 1000000000, "seals": 3, "quest": 4, "defeated": 1000000000}
	for field in limits:
		if not integer(data.get(field), 0, limits[field]):
			return false
	if not number(data.get("health")) or float(data.health) < 1 or float(data.health) > 100 + int(data.realm) * 30:
		return false
	if data.has("stamina") and (not number(data.stamina) or float(data.stamina) < 0 or float(data.stamina) > 100):
		return false
	if not data.get("ending") is String or data.ending not in ["", "Mercy", "Ascension"]:
		return false
	if data.has("appearance"):
		if not data.appearance is Dictionary:
			return false
		for field in ["hair", "clothing", "weapon"]:
			if not integer(data.appearance.get(field), 0, 3):
				return false
	return true

func restore(data: Dictionary) -> bool:
	# Validate the entire object before changing any field.
	if not valid_data(data):
		return false
	realm = int(data.realm)
	qi = int(data.qi)
	herbs = int(data.herbs)
	seals = int(data.seals)
	health = float(data.health)
	stamina = float(data.get("stamina", 100.0))
	quest = int(data.quest)
	defeated = int(data.defeated)
	ending = data.ending
	var appearance = data.get("appearance", {"hair":0,"clothing":0,"weapon":0})
	hair = int(appearance.hair)
	clothing = int(appearance.clothing)
	weapon = int(appearance.weapon)
	return true
