extends SceneTree
var game: Node
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
	game = load("res://main.tscn").instantiate()
	game.save_path = "user://ascension-test.json"
	root.add_child(game)
	await process_frame
	game.begin()
	game.state.realm = 2
	game.state.quest = 3
	game.state.seals = 3
	game.state.defeated = 3
	game.collected = ["seal_0","seal_1","seal_2"]
	game.defeated_ids = ["Meridian Warden 0","Meridian Warden 1","Meridian Warden 2"]
	var boss = game.actors.filter(func(a): return a.kind=="boss")[0]
	game.player.position = boss.position+Vector3(0,.1,2)
	while boss.alive:
		game.player.attack_clock = 0
		game.attack()
	check(game.modal_kind=="ending","Xu opens an ending choice")
	check(not game.save_game() and not game.load_game(),"Pending ending cannot be bypassed by saving or loading")
	game.open_campaign("map")
	game.show_cultivation()
	game.show_appearance()
	check(game.modal_kind=="ending","Other panels cannot replace the final choice")
	game.choose_ending(false)
	check(game.state.ending=="Ascension" and game.state.quest==4,"Ascension is independently playable")
	game.choose_ending(true)
	check(game.state.ending=="Ascension","Repeated choices preserve Ascension")
	game.close_modal()
	check(game.load_game(),"Ascension autosave loads")
	check(game.state.ending=="Ascension" and game.actors.filter(func(a): return a.kind=="boss").is_empty(),"Ascension and Xu's defeat persist")
	# Migration resets absent appearance and preserves valid legacy progression.
	var legacy = {"version":1,"realm":1,"qi":31,"herbs":2,"seals":0,"health":110,"quest":1,"defeated":0,"ending":"","position":[0,.15,10],"collected":[],"defeated_ids":[]}
	var file = FileAccess.open("user://valid-legacy-test.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	game.state.hair = 2
	game.state.clothing = 3
	game.state.weapon = 3
	check(game.load_game("user://valid-legacy-test.json"),"Valid version one save migrates")
	check(game.state.hair==0 and game.state.clothing==0 and game.state.weapon==0 and game.state.stamina==100,"Missing legacy appearance and stamina have deterministic defaults")
	check(game.save_game(),"Migrated state writes as version two")
	var original = FileAccess.get_file_as_string(game.save_path)
	game.state.health = NAN
	check(not game.save_game() and FileAccess.get_file_as_string(game.save_path)==original,"Invalid runtime state cannot overwrite the last valid save")
	print("ENDING_TESTS checks=%d passed=%d failed=%d" % [checks,checks-failed,failed])
	game.stop_audio()
	game.queue_free()
	await process_frame
	await process_frame
	quit(0 if failed==0 else 1)
