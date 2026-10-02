extends SceneTree

var checks = 0
var failures: Array[String] = []
var game: Node

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func visit_item(target: Dictionary) -> void:
	game.player.position = target.node.position + Vector3(0,.1,2.2)
	game.player.rotation.y = 0
	game.player.camera.rotation.x = 0
	game.interact(target)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	AudioServer.set_bus_mute(0, true)
	game = load("res://main.tscn").instantiate()
	game.save_path = "user://test-autosave.json"
	root.add_child(game)
	await process_frame
	await physics_frame
	check(game.atlases.size() == 5, "All image-generated atlases load")
	check(game.actors.size() == 33, "Core cast and first regional cast spawn")
	check(game.model_cache.size() > 35, "World instantiates textured GLB library")
	check(game.player.camera.current, "First-person camera is active")
	check(game.avatar_atlas != null and game.state.hair == 0 and game.state.clothing == 0 and game.state.weapon == 0, "Female Lin Yue has default sprite appearance and jade sword")
	game.cycle_appearance(0)
	check(game.state.hair == 1 and game.state.clothing == 0, "Hairstyle changes independently of clothing")
	game.cycle_appearance(1)
	check(game.state.clothing == 1 and game.state.hair == 1, "Clothing changes independently of hair")
	game.cycle_appearance(2)
	check(game.state.weapon == 1 and game.weapon_atlas != null, "Weapon selection changes and generated weapon sprites load")
	for i in range(3):
		game.cycle_appearance(0)
	check(game.state.hair == 0, "Four hairstyles cycle back to the first")
	game.state.hair = 2
	game.state.clothing = 3
	check(game.state.appearance_row() == 11, "Independent hair/clothing choices map to the correct sprite row")
	game.state.weapon = 0
	var sword_damage = game.state.damage()
	game.state.weapon = 1
	check(game.state.damage() > sword_damage, "Saber loadout changes combat damage")
	game.state.hair = 0
	game.state.clothing = 0
	game.state.weapon = 0
	check(not game.state.cultivate(), "Insufficient qi cannot advance a realm")
	game.begin()
	Input.action_press("forward")
	var original_z = game.player.position.z
	for i in range(15):
		await physics_frame
	Input.action_release("forward")
	check(game.player.position.z < original_z - .4, "WASD physics moves the player")
	check(game.player.position.y > -.1, "Player remains above collidable ground")
	game.player.position = Vector3(-3.1, .1, 5)
	game.player.rotation.y = 0
	game.player.camera.rotation.x = 0
	check(game.nearby().get("kind") == "npc", "Directional proximity selects Mei")
	game.interact({"kind": "npc", "actor": game.actors[0]})
	check(game.state.quest == 1 and game.modal, "Mei starts moonlotus quest and dialogue")
	game.close_modal()
	for i in range(3):
		visit_item(game.interactables[i])
	check(game.state.herbs == 3, "Three moonlotus can be gathered")
	game.player.position = Vector3(-3.1,.1,5)
	game.interact({"kind": "npc", "actor": game.actors[0]})
	check(game.state.quest == 2 and game.state.herbs == 0, "Mei consumes herbs and advances story")
	check(game.state.qi == 74, "Gathering and quest reward grant expected qi")
	game.close_modal()
	game.show_cultivation()
	game.meditate()
	check(game.state.realm == 1 and not game.modal, "Meditation unlocks Qi Awakening")
	for i in range(9, 14):
		visit_item(game.interactables[i])
	game.show_cultivation()
	game.meditate()
	check(game.state.realm == 2, "Second breakthrough reaches Foundation")
	var boss = game.actors.filter(func(a): return a.kind=="boss")[0]
	game.player.position = boss.position + Vector3(0, .1, 2)
	game.player.attack_clock = 0
	game.attack()
	check(boss.health == 300, "Boss binding blocks damage without three seals")
	for i in range(3):
		var guardian = game.actors[3 + i]
		var seal = game.interactables[24 + i]
		visit_item(seal)
		check(game.state.seals == i, "Living warden blocks its seal")
		game.player.position = guardian.position + Vector3(0, .1, 2)
		game.player.rotation.y = 0
		game.player.camera.rotation.x = 0
		while guardian.alive:
			game.player.attack_clock = 0
			game.attack()
		visit_item(seal)
		check(game.state.seals == i + 1, "Sword combat frees warden and restores seal")
	check(game.state.quest == 3, "Three restored seals advance final quest")
	game.player.position = boss.position + Vector3(0, .1, 2)
	game.player.attack_clock = 0
	game.attack()
	var after_hit = boss.health
	game.attack()
	check(boss.health == after_hit, "Attack cooldown prevents repeated instant damage")
	game.state.stamina = 100
	game.spirit_palm()
	check(boss.health < after_hit and game.state.stamina == 65, "Spirit palm damages boss and consumes stamina")
	while boss.alive:
		game.player.attack_clock = 0
		game.attack()
	check(game.modal_kind == "ending", "Defeating Xu opens final moral choice")
	game.close_modal()
	check(game.modal_kind == "ending", "Escape cannot discard the ending choice")
	game.choose_ending(true)
	check(game.state.ending == "Mercy" and game.state.quest == 4, "Mercy ending completes story")
	game.choose_ending(false)
	check(game.state.ending == "Mercy", "Completed ending cannot be changed by a repeated call")
	game.close_modal()
	game.state.hair = 2
	game.state.clothing = 3
	game.state.weapon = 1
	check(game.save_game("user://test-journey.json"), "Save writes structured progression")
	game.state.realm = 0
	game.state.ending = ""
	game.state.hair = 0
	game.state.clothing = 0
	game.state.weapon = 0
	check(game.load_game("user://test-journey.json"), "Saved journey loads")
	check(game.state.realm == 2 and game.state.ending == "Mercy", "Load restores realm and ending")
	check(game.state.hair == 2 and game.state.clothing == 3 and game.state.weapon == 1, "Save/load retains hair, outfit, and weapon independently")
	check(game.collected.size() == 11, "Load restores consumed herbs, essence, and seals")
	var live_bosses = 0
	for actor in game.actors:
		if actor.kind == "boss":
			live_bosses += 1
	check(live_bosses == 0, "Defeated boss stays defeated after load")
	var file = FileAccess.open("user://invalid-journey.json", FileAccess.WRITE)
	file.store_string("not valid json")
	file.close()
	check(not game.load_game("user://invalid-journey.json"), "Malformed save is rejected")
	game.state.health = 1
	game.state.qi = 20
	game.take_damage(9)
	check(game.state.health == game.state.max_health() and game.state.qi == 5, "Defeat respawns with realm preserved and qi penalty")
	await process_frame
	print("GAMEPLAY_TESTS checks=%d passed=%d failed=%d" % [checks, checks - failures.size(), failures.size()])
	if failures.size() > 0:
		for failure in failures:
			print("FAIL: " + failure)
	game.stop_audio()
	await create_timer(.15).timeout
	game.queue_free()
	game = null
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)
