extends SceneTree

var game: Node
var checks = 0
var failures: Array[String] = []

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error(label)

func _initialize() -> void:
	call_deferred("run")

func place(point: Vector3, yaw: float = 0) -> void:
	game.player.position = point
	game.player.reset_motion()
	game.player.yaw = yaw
	game.player.rotation.y = yaw
	game.player.pitch = 0
	game.player.camera.rotation.x = 0

func walk(frames: int, yaw: float) -> void:
	game.player.yaw = yaw
	game.player.rotation.y = yaw
	Input.action_press("forward")
	for _frame in range(frames):
		await physics_frame
	Input.action_release("forward")
	for _frame in range(3):
		await physics_frame

func press_choice(choice: int) -> void:
	var event = InputEventKey.new()
	event.keycode = KEY_1 if choice == 1 else KEY_2
	event.physical_keycode = event.keycode
	event.pressed = true
	game._unhandled_input(event)

func freeze_enemies() -> void:
	for actor in game.actors:
		actor.set_physics_process(false)

func write_save(data: Dictionary) -> void:
	var file = FileAccess.open("user://city-invalid.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()

func run() -> void:
	game = load("res://main.tscn").instantiate()
	game.save_path = "user://city-journey.json"
	root.add_child(game)
	await process_frame
	await physics_frame
	freeze_enemies()
	check(game.city.buildings.size() == 12, "Twelve city buildings load in the running world")
	check(game.city.resident_actors.size() == 40, "Forty named city residents spawn")
	check(game.city.interiors.instances.size() >= 576, "Every floor is furnished with at least sixteen Blender GLBs")
	check(game.city.interiors.scenes.size() == 40, "All forty Blender models are loaded and cached")
	for model_id in game.city.interiors.scenes:
		var instance = game.city.interiors.instances.filter(func(n): return n.get_meta("interior_prop") == model_id)[0]
		var textured = true
		for mesh in instance.find_children("*", "MeshInstance3D", true, false):
			for surface in range(mesh.mesh.get_surface_count()):
				var material = mesh.get_active_material(surface)
				textured = textured and material is StandardMaterial3D and material.albedo_texture != null and material.roughness_texture != null and material.normal_enabled and material.normal_texture != null
		check(textured, "Embedded PBR textures import into Godot: " + model_id)
	game.begin()
	place(Vector3(0, .15, 13), PI)
	await walk(150, PI)
	check(game.player.position.z > 23 and game.player.is_on_floor(), "Walk through the actual camp gate into Lantern Avenue")
	var names: Dictionary = {}
	var stories: Dictionary = {}
	for id in game.city.buildings:
		var building = game.city.buildings[id]
		var origin = game.city.building_origin(id)
		check(building.floors.size() == 3 and building.description.length() > 80, "Three documented floors: " + id)
		# Door passage uses the player controller and real collision geometry.
		place(origin + Vector3(0, .15, 9.5))
		await walk(75, 0)
		check(game.player.position.z < origin.z + 6 and game.player.is_on_floor(), "Walk through entrance without jumping: " + id)
		for floor_index in range(3):
			var props = game.city.interiors.instances.filter(func(n): return n.get_parent().name == str(id).to_pascal_case() and n.get_meta("interior_floor") == floor_index)
			check(props.size() >= 16, "Textured GLB decor on floor %d of %s" % [floor_index + 1, id])
			var occupants = game.city.residents.values().filter(func(r): return r.building == id and int(r.floor) == floor_index)
			check(occupants.size() == 1, "Resident on floor %d of %s" % [floor_index + 1, id])
			var resident = occupants[0]
			var actor = game.city.resident_actors[resident.id]
			check(actor.frames.size() == 4 and actor.frames[0].get_height() > 150 and actor.sprite_id == resident.sprite, "Existing high-resolution animated artwork loads: " + resident.id)
			check(not names.has(resident.name) and not stories.has(str(resident.story)), "Unique resident and authored story: " + resident.id)
			names[resident.name] = true
			stories[str(resident.story)] = true
			place(actor.position + Vector3(0, .1, 2.2))
			await physics_frame
			await physics_frame
			var target = game.nearby()
			check(target.get("actor") == actor, "Crosshair finds resident on the correct floor: " + resident.id)
			game.interact(target)
			check(game.modal_kind == "city_dialogue" and game.modal_title.begins_with(resident.name), "E interaction opens personal dialogue: " + resident.id)
			press_choice(1)
			check(Array(game.modal_lines) == Array(resident.story), "Story choice displays authored lines: " + resident.id)
			game.state.health = 50
			game.state.stamina = 30
			var qi = game.state.qi
			var herbs = game.state.herbs
			press_choice(2)
			var expected = {"appearance": "appearance", "journal": "campaign", "atlas": "campaign", "directory": "campaign", "cultivate": "cultivate"}.get(resident.service, "city_dialogue")
			check(game.modal_kind == expected, "Service choice works: " + resident.id)
			if resident.service in ["heal", "rest"]:
				check(game.state.health == game.state.max_health(), "Treatment restores vitality: " + resident.id)
			if resident.service in ["tea", "rest"]:
				check(game.state.stamina == 100, "Hospitality restores stamina: " + resident.id)
			check(game.state.qi == qi and game.state.herbs == herbs, "City conversations do not mint qi or consume herbs: " + resident.id)
			game.close_modal()
		# Ascend both complete stairs with ordinary WASD movement, not teleportation.
		place(origin + Vector3(5.5, .15, 5.8))
		await walk(180, 0)
		check(game.player.position.y > 3.8 and game.player.position.z < origin.z - 5, "First staircase reaches floor two without jumping: " + id)
		await walk(42, PI / 2)
		check(game.player.position.x < origin.x + 4.1 and game.player.is_on_floor(), "Upper landing joins the furnished room: " + id)
		await walk(150, PI)
		await walk(42, -PI / 2)
		await walk(180, 0)
		check(game.player.position.y > 7.8 and game.player.position.z < origin.z - 5, "Second staircase reaches floor three without jumping: " + id)
		check("Floor 3 / 3" in game.city.location_caption(game.player.position), "HUD identifies the upper floor: " + id)
		# Descending the same route is also physical, with no transition trigger.
		await walk(180, PI)
		check(game.player.position.y > 3.7 and game.player.position.y < 4.4, "Descend staircase to floor two: " + id)
		await walk(42, PI / 2)
		await walk(150, 0)
		await walk(42, -PI / 2)
		await walk(180, PI)
		check(game.player.position.y < .2 and game.player.is_on_floor(), "Descend the lower staircase to the ground floor: " + id)
		await walk(70, PI / 2)
		await walk(30, PI)
		check(game.player.position.z > origin.z + 7.5, "Exit through the door after visiting all three floors: " + id)
	for resident in game.city.residents.values():
		if resident.building != "": continue
		var actor = game.city.resident_actors[resident.id]
		place(actor.position + Vector3(0, .1, 2.2))
		await physics_frame
		game.interact(game.nearby())
		check(game.modal_title.begins_with(resident.name), "Street resident can be addressed: " + resident.id)
		press_choice(1)
		check(Array(game.modal_lines) == Array(resident.story), "Street resident shares personal story: " + resident.id)
		press_choice(2)
		check(game.modal, "Street resident service opens: " + resident.id)
		game.close_modal()
	# Verify opaque physics walls and floors block interactions.
	var actor = game.city.resident_actors["city_00"]
	var original = actor.position
	var origin = game.city.building_origin("lotus_inn")
	actor.position = origin + Vector3(-7, .05, 0)
	place(origin + Vector3(-9.5, .15, 0), -PI / 2)
	await physics_frame
	await physics_frame
	game.talk(actor)
	check(not game.modal and not game.in_reach(actor.position + Vector3.UP, actor), "Cannot speak through a building's closed side wall")
	actor.position = original
	place(origin + Vector3(-.6, 4.1, 1.5))
	await physics_frame
	check(not game.line_of_sight(game.player.camera.global_position, actor.position + Vector3.UP, actor), "Floor slab blocks sight to a downstairs resident")
	place(original + Vector3(0, .1, 2.2))
	game.talk(actor)
	var before_position = game.player.position
	for _frame in range(20): await physics_frame
	check(game.player.position == before_position, "Resident dialogue pauses player movement and gravity")
	game.close_modal()
	# Directory searches include names, floor titles, roles, and district addresses.
	game.open_campaign("city")
	check(game.campaign_panel.ids.size() == 12, "City directory lists all twelve buildings")
	game.campaign_panel.search.text = "Qin Yue"
	game.campaign_panel.refresh()
	check(game.campaign_panel.ids == ["star_observatory"], "Search finds a resident's address")
	check("FLOOR 3" in game.campaign_panel.reader.text and "Qin Yue" in game.campaign_panel.reader.text, "Directory contains every floor and its resident")
	check(game.city.mark_building("star_observatory") and game.city.marker.visible, "Directory marks a real entrance in the world")
	check(not game.city.mark_building("unknown"), "Unknown marker addresses are rejected")
	check(game.city.mark_building("star_observatory") and not game.city.marker.visible, "Selecting an address again clears the marker")
	# Version four stores an upper-floor position and all version-three consumption.
	place(game.city.building_origin("star_observatory") + Vector3(0, 8.15, 1.5), .4)
	game.state.health = 100
	game.regional_collected = ["regional_0"]
	check(game.save_game(), "Save succeeds inside a third-floor room")
	var saved = JSON.parse_string(FileAccess.get_file_as_string(game.save_path))
	check(int(saved.version) == 4, "City uses save schema version four")
	place(Vector3(0, .15, 13))
	check(game.load_game(), "Load restores a third-floor city journey")
	freeze_enemies()
	check(game.player.position.y > 8 and game.regional_collected == ["regional_0"], "Upper-floor location and consumed regional blossom survive loading")
	check(game.city.resident_actors.size() == 40 and game.actors.filter(func(a): return a.resident_id != "").size() == 40, "Loading does not duplicate city residents")
	for invalid in [Vector3(30, 8, 40), Vector3(0, 8, 138), Vector3(0, 13, 40), Vector3(0, 8, -91)]:
		var data = saved.duplicate(true)
		data.position = [invalid.x, invalid.y, invalid.z]
		write_save(data)
		var position_before = game.player.position
		check(not game.load_game("user://city-invalid.json") and game.player.position == position_before, "Out-of-world city save leaves journey intact: " + str(invalid))
	var foreign = saved.duplicate(true)
	foreign.campaign.region = "region_01"
	write_save(foreign)
	check(not game.load_game("user://city-invalid.json"), "Another region cannot restore a Cloudrest city position")
	var legacy = saved.duplicate(true)
	legacy.version = 3
	legacy.position = [0, .15, 13]
	write_save(legacy)
	check(game.load_game("user://city-invalid.json") and game.regional_collected == ["regional_0"], "Version-three saves migrate without losing regional consumption")
	freeze_enemies()
	game.travel("region_01")
	freeze_enemies()
	await physics_frame
	await physics_frame
	check(not game.city.visible and not actor.visible and actor.collision_layer == 0, "Travel hides Cloudrest city and its residents")
	check(not game.city.mark_building("lotus_inn"), "Cannot mark a Cloudrest entrance from another region")
	check(not game.walkable(Vector3(0, 0, 25)), "Other regions retain their original valley bounds")
	place(Vector3(0, .15, 13), PI)
	await walk(150, PI)
	check(game.player.position.z < 18, "Inactive city gate physically blocks travel out of another region")
	game.travel("region_00")
	freeze_enemies()
	await physics_frame
	await physics_frame
	check(game.city.visible and actor.visible, "Returning to Cloudrest restores city access")
	check(game.rest_at_camp(), "Valley camp rest still works after returning from the city")
	check(game.actors.filter(func(a): return a.resident_id != "").size() == 40, "Rest does not duplicate or remove city residents")
	print("CITY_TESTS checks=%d passed=%d failed=%d" % [checks, checks - failures.size(), failures.size()])
	game.stop_audio()
	game.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)
