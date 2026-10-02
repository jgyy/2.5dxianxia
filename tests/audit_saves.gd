extends SceneTree

var game: Node
var results: Array = []

func _initialize() -> void:
	call_deferred("run")

func mutate(data: Dictionary, field: String, value: Variant) -> void:
	var bits = field.split(".")
	if bits.size() == 1:
		data[field] = value
	elif bits[0] == "position":
		data.position[int(bits[1])] = value
	else:
		data[bits[0]][bits[1]] = value

func run() -> void:
	game = load("res://main.tscn").instantiate()
	game.save_path = "user://audit-autosave.json"
	root.add_child(game)
	await process_frame
	await physics_frame
	var parser = JSON.new()
	parser.parse(FileAccess.get_file_as_string("res://tests/save_cases.json"))
	var cases = parser.data
	for test in cases:
		game.state = load("res://scripts/cultivation.gd").new()
		game.state.qi = 31
		game.state.health = 70
		game.collected = []
		game.defeated_ids = []
		game.player.position = Vector3(0, .15, 10)
		var before = game.state.to_dict().duplicate(true)
		var data = {"version": 1, "realm": 2, "qi": 74, "health": 140, "herbs": 2, "seals": 0, "quest": 1, "defeated": 0, "ending": "", "appearance": {"hair": 1, "clothing": 1, "weapon": 1}, "position": [0, .15, 10], "collected": [], "defeated_ids": []}
		mutate(data, test.field, test.value)
		var file = FileAccess.open("user://audit-invalid.json", FileAccess.WRITE)
		file.store_string(JSON.stringify(data))
		file.close()
		var accepted = game.load_game("user://audit-invalid.json")
		var unchanged = game.state.to_dict() == before and game.collected.is_empty() and game.defeated_ids.is_empty()
		results.append({"id": test.id, "category": test.category, "field": test.field, "accepted": accepted, "unchanged": unchanged, "pass": not accepted and unchanged})
	var failures = results.filter(func(r): return not r.pass).size()
	var output = "res://docs/audit/save-results.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
	var file = FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":results.size(), "failed": failures, "results":results}, "\t"))
	file.close()
	print("SAVE_AUDIT checks=%d passed=%d failed=%d" % [results.size(), results.size()-failures, failures])
	game.stop_audio()
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
