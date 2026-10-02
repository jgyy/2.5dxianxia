extends SceneTree

var checks = 0
var failed = 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failed += 1
		push_error(label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	game.begin()
	game.player.set_physics_process(false)
	for actor in game.actors:
		actor.set_physics_process(false)
	var manifest = JSON.parse_string(FileAccess.get_file_as_string("res://assets/sprites/native/manifest.json"))
	for frame in manifest.frames:
		var texture = game.sprite_library.texture("res://assets/sprites/" + frame.resource)
		check(texture != null and texture.get_width() >= 1000 and texture.get_height() >= 1000, "Actual engine loads native dimensions: " + frame.resource)
		check(texture.resource_path == "res://assets/sprites/native/" + frame.path, "Native replacement preserves the source frame ID: " + frame.resource)
	var pilot = game.actors.filter(func(actor): return actor.data_id == "npc_000")[0]
	check(pilot.frames[0].get_width() >= 1000 and pilot.frames[0].get_height() >= 1000, "The campaign uses native Lin Ning artwork")
	game.player.position = pilot.position + Vector3(0, .1, 3)
	for state in ["idle", "walk", "attack"]:
		pilot.animation_state = state
		for index in range(4):
			pilot.animation_clock = index / pilot.animation_fps
			pilot.update_directional_view()
			check(is_equal_approx(pilot.sprite.pixel_size * pilot.sprite.texture.get_height(), 2.5), "Physical height survives frame replacement: %s/%d" % [state, index])
	for index in range(4):
		check(game.weapon_frames[index] != null, "Weapon artwork retains loadout %d" % index)
	game.stop_audio()
	game.queue_free()
	await process_frame
	print("NATIVE_SPRITE_TESTS checks=%d passed=%d failed=%d" % [checks, checks - failed, failed])
	quit(1 if failed else 0)
