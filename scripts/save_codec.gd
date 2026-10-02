extends RefCounted

const Cultivation = preload("res://scripts/cultivation.gd")
const BOSS = "Immortal Xu · The Hollow Sun"
const CURRENT_VERSION = 4
const CITY_END = preload("res://scripts/city.gd").CITY_END

static func known_collected() -> Array:
	var ids: Array = []
	for i in range(9): ids.append("herb_%d" % i)
	for i in range(15): ids.append("qi_%d" % i)
	for i in range(3): ids.append("seal_%d" % i)
	return ids

static func known_defeated() -> Array:
	var ids: Array = [BOSS]
	for i in range(3): ids.append("Meridian Warden %d" % i)
	for i in range(8): ids.append("Ash Spirit %d" % i)
	return ids

static func valid_ids(value: Variant, allowed: Array) -> bool:
	if not value is Array or value.size() > allowed.size():
		return false
	var seen: Dictionary = {}
	for id in value:
		if not id is String or id not in allowed or seen.has(id):
			return false
		seen[id] = true
	return true

static func valid(data: Variant, campaign: RefCounted) -> bool:
	if not data is Dictionary or not Cultivation.integer(data.get("version"), 1, CURRENT_VERSION):
		return false
	if not Cultivation.valid_data(data) or not valid_ids(data.get("collected"), known_collected()) or not valid_ids(data.get("defeated_ids"), known_defeated()):
		return false
	if not data.get("position") is Array or data.position.size() != 3:
		return false
	for value in data.position:
		if not Cultivation.number(value):
			return false
	var southern_bound = 18.0
	if int(data.version) >= 4 and data.get("campaign") is Dictionary and data.campaign.get("region") == "region_00":
		southern_bound = CITY_END
	if absf(float(data.position[0])) >= 30 or float(data.position[2]) <= -90 or float(data.position[2]) >= southern_bound or float(data.position[1]) < -.05 or float(data.position[1]) > 12:
		return false
	var seals = 0
	for i in range(3):
		if "seal_%d" % i in data.collected:
			seals += 1
			if "Meridian Warden %d" % i not in data.defeated_ids:
				return false
	if seals > 0 and int(data.quest) < 2:
		return false
	if seals != int(data.seals) or int(data.defeated) < data.defeated_ids.size():
		return false
	if int(data.quest) >= 3 and (seals != 3 or int(data.realm) < 0):
		return false
	if data.ending != "" and (int(data.quest) != 4 or BOSS not in data.defeated_ids or int(data.realm) < 2):
		return false
	if int(data.quest) == 4 and data.ending == "":
		return false
	if BOSS in data.defeated_ids and (seals != 3 or int(data.realm) < 2):
		return false
	if int(data.version) >= 2:
		if not data.has("stamina") or not data.has("appearance") or not campaign.valid_saved(data.get("campaign")):
			return false
		if not data.get("orientation") is Array or data.orientation.size() != 2:
			return false
		for value in data.orientation:
			if not Cultivation.number(value):
				return false
		if absf(float(data.orientation[0])) > 10000 or absf(float(data.orientation[1])) > 1.15:
			return false
	if int(data.version) >= 3:
		if not data.get("regional") is Dictionary:
			return false
		var regional_ids: Array = []
		for i in range(8):
			regional_ids.append("regional_%d" % i)
		var monster_ids: Array = []
		for id in campaign.monsters:
			if campaign.monsters[id].region == data.campaign.region:
				monster_ids.append(id)
		if not valid_ids(data.regional.get("collected"), regional_ids) or not valid_ids(data.regional.get("defeated"), monster_ids):
			return false
		if int(data.defeated) < data.defeated_ids.size() + data.regional.defeated.size():
			return false
		if data.ending == "Ascension" and int(data.realm) != 3:
			return false
	return true

static func atomic_write(path: String, data: Dictionary) -> bool:
	var temp = path + ".tmp"
	var file = FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.flush()
	var error = file.get_error()
	file.close()
	if error != OK:
		DirAccess.remove_absolute(temp)
		return false
	# Atomic same-directory rename keeps the existing save intact on failure.
	if FileAccess.file_exists(path):
		if DirAccess.copy_absolute(path, path + ".bak") != OK:
			DirAccess.remove_absolute(temp)
			return false
	if DirAccess.rename_absolute(temp, path) != OK:
		DirAccess.remove_absolute(temp)
		return false
	return true
