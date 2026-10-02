extends RefCounted

const INDEX = "res://content/campaign/index.json"
var regions: Array = []
var npcs: Dictionary = {}
var monsters: Dictionary = {}
var quests: Dictionary = {}
var active: Dictionary = {}
var completed: Dictionary = {}
var reputation: Dictionary = {}
var current_region = "region_00"
var book_cache: Dictionary = {}

func _init() -> void:
	var parser = JSON.new()
	if parser.parse(FileAccess.get_file_as_string(INDEX)) != OK:
		push_error("Campaign index is unreadable")
		return
	var data = parser.data
	regions = data.regions
	for npc in data.npcs:
		npcs[npc.id] = npc
	for monster in data.monsters:
		monsters[monster.id] = monster
	for quest in data.quests:
		quests[quest.id] = quest

func accept(id: String) -> bool:
	if not quests.has(id) or active.has(id) or completed.has(id) or active.size() >= 6:
		return false
	var quest = quests[id]
	if quest.previous != "" and not completed.has(quest.previous):
		return false
	active[id] = 0
	return true

func record(kind: String, target: String, amount: int = 1) -> void:
	if amount <= 0:
		return
	for id in active:
		var objective = quests[id].objective
		if objective.kind == kind and objective.target == target:
			active[id] = mini(int(objective.count), int(active[id]) + amount)

func ready_to_claim(id: String) -> bool:
	return active.has(id) and quests.has(id) and int(active[id]) >= int(quests[id].objective.count)

func claim(id: String, owner: String, choice: String = "mercy") -> Dictionary:
	if not ready_to_claim(id) or quests[id].owner != owner or choice not in ["mercy", "power"]:
		return {}
	var quest = quests[id]
	if not quest.choice and choice != "mercy":
		return {}
	completed[id] = choice
	active.erase(id)
	reputation[owner] = int(reputation.get(owner, 0)) + int(quest.reward_reputation)
	return {"qi": int(quest.reward_qi), "choice": choice, "reputation": int(reputation[owner])}

func abandon(id: String) -> bool:
	return active.erase(id)

func story(id: String) -> Dictionary:
	if not quests.has(id):
		return {}
	var book = str(quests[id].book)
	if not book_cache.has(book):
		var parser = JSON.new()
		if parser.parse(FileAccess.get_file_as_string("res://content/campaign/" + book)) != OK:
			return {}
		# Keep at most two regional books resident, not the entire word corpus.
		if book_cache.size() >= 2:
			book_cache.erase(book_cache.keys()[0])
		book_cache[book] = parser.data
	return book_cache[book].get(id, {})

func to_dict() -> Dictionary:
	return {"region": current_region, "active": active.duplicate(true), "completed": completed.duplicate(true), "reputation": reputation.duplicate(true)}

func valid_saved(data: Variant) -> bool:
	if not data is Dictionary or not data.get("region") is String:
		return false
	if not regions.any(func(r): return r.id == data.region):
		return false
	for field in ["active", "completed", "reputation"]:
		if not data.get(field) is Dictionary:
			return false
	if data.active.size() > 6 or data.completed.size() > quests.size() or data.reputation.size() > npcs.size():
		return false
	for id in data.active:
		if not quests.has(id) or data.completed.has(id) or not is_integer(data.active[id]) or int(data.active[id]) < 0 or int(data.active[id]) > int(quests[id].objective.count):
			return false
		if quests[id].previous != "" and not data.completed.has(quests[id].previous):
			return false
	for id in data.completed:
		if not quests.has(id) or data.completed[id] not in ["mercy", "power"]:
			return false
		if not quests[id].choice and data.completed[id] != "mercy":
			return false
		if quests[id].previous != "" and not data.completed.has(quests[id].previous):
			return false
	var expected_reputation: Dictionary = {}
	for id in data.completed:
		var owner = quests[id].owner
		expected_reputation[owner] = int(expected_reputation.get(owner, 0)) + int(quests[id].reward_reputation)
	if data.reputation.size() != expected_reputation.size():
		return false
	for owner in data.reputation:
		if not npcs.has(owner) or not is_integer(data.reputation[owner]) or int(data.reputation[owner]) != int(expected_reputation.get(owner, -1)):
			return false
	return true

func restore(data: Dictionary) -> void:
	current_region = data.region
	active = data.active.duplicate(true)
	completed = data.completed.duplicate(true)
	reputation = data.reputation.duplicate(true)

static func is_integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value))
