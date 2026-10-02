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

func write_save(path: String, data: Dictionary) -> void:
	var file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()

func freeze_actors() -> void:
	for actor in game.actors:
		actor.set_physics_process(false)

func run() -> void:
	game = load("res://main.tscn").instantiate()
	game.save_path = "user://revision-autosave.json"
	root.add_child(game)
	await process_frame
	await physics_frame
	game.player.set_physics_process(false)
	freeze_actors()
	game.begin()
	game.open_campaign("quests")
	# Exercise the actual reader before and after all 1,200 completions.
	for id in game.campaign.quests:
		var quest = game.campaign.quests[id]
		game.campaign_panel.selected = id
		game.campaign_panel.show_entry()
		check("Lin Yue returns through " not in game.campaign_panel.reader.text and "THE ACCOUNT'S CONSEQUENCE" not in game.campaign_panel.reader.text, "Unfinished briefing preserves chronology: " + id)
		check(game.campaign.accept(id), "Chapter accepts after its prerequisite: " + id)
		game.campaign.record(quest.objective.kind,quest.objective.target,int(quest.objective.count))
		check(not game.campaign.claim(id,quest.owner).is_empty(), "Completed chapter claims: " + id)
		game.campaign_panel.show_entry()
		check("Lin Yue returns through " in game.campaign_panel.reader.text and "THE ACCOUNT'S CONSEQUENCE" in game.campaign_panel.reader.text, "Completed reader reveals aftermath: " + id)
		if quest.choice:
			check("Before the next chapter begins" not in game.campaign_panel.reader.text, "Final chapter has no nonexistent successor: " + id)
	game.close_modal()
	game.campaign = load("res://scripts/campaign.gd").new()
	var pilot = game.actors.filter(func(a): return a.data_id=="npc_000")[0]
	check(pilot.frames.size()==16 and pilot.frames[0].get_height()>300 and pilot.animation_fps==12, "Existing Lin Ning loads 16 doubled-resolution frames at 12 FPS")
	var item = game.regional_items[0]
	game.player.position = item.node.position+Vector3(0,.1,2)
	game.interact(item)
	check(game.regional_collected==["regional_0"] and not item.node.visible, "Gathering consumes a regional blossom")
	var monster = game.actors.filter(func(a): return a.data_id=="monster_000")[0]
	monster.hit(10000)
	check("monster_000" in game.regional_defeated, "Regional victory records the consumed encounter")
	check(game.save_game("user://revision-regional.json"), "Version three saves regional consumption")
	var saved = JSON.parse_string(FileAccess.get_file_as_string("user://revision-regional.json"))
	check(int(saved.version)==4, "Save uses the city-aware regional-state schema")
	var qi_before = game.state.qi
	var herbs_before = game.state.herbs
	check(game.load_game("user://revision-regional.json"), "Regional save restores")
	freeze_actors()
	check(not game.regional_items[0].node.visible and game.actors.filter(func(a): return a.data_id=="monster_000").is_empty(), "Loading preserves gathered roots and defeated monsters")
	check(game.state.qi==qi_before and game.state.herbs==herbs_before, "Loading does not mint additional rewards")
	var invalid = saved.duplicate(true)
	invalid.regional.defeated = ["monster_001"]
	write_save("user://revision-invalid.json",invalid)
	check(not game.load_game("user://revision-invalid.json") and game.state.qi==qi_before and not game.regional_items[0].node.visible, "Foreign-region encounter data is rejected without altering the journey")
	invalid = saved.duplicate(true)
	invalid.regional.collected = ["regional_0","regional_0"]
	write_save("user://revision-invalid.json",invalid)
	check(not game.load_game("user://revision-invalid.json"), "Duplicate consumed regional IDs are rejected")
	var legacy = saved.duplicate(true)
	legacy.version = 2
	legacy.erase("regional")
	write_save("user://revision-legacy.json",legacy)
	check(game.load_game("user://revision-legacy.json") and game.regional_collected.is_empty() and game.regional_defeated.is_empty(), "Version two migrates with deterministic regional defaults")
	freeze_actors()
	game.player.position = Vector3(0,.15,13)
	check(game.rest_at_camp() and game.regional_items[0].node.visible and not game.actors.filter(func(a): return a.data_id=="monster_000").is_empty(), "Camp rest renews resources and encounters")
	freeze_actors()
	# A breakthrough outside camp must not fulfill an explicit camp-rest objective.
	var c = load("res://scripts/campaign.gd").new()
	for stage in range(6):
		var id = "quest_000_%02d" % stage
		var quest = c.quests[id]
		c.accept(id)
		c.record(quest.objective.kind,quest.objective.target,int(quest.objective.count))
		c.claim(id,quest.owner)
	c.accept("quest_000_06")
	game.campaign = c
	game.state.realm = 0
	game.state.qi = 30
	game.show_cultivation()
	game.meditate()
	check(game.state.realm==1 and not c.ready_to_claim("quest_000_06"), "Cultivation does not impersonate rest at a lantern camp")
	check(game.rest_at_camp() and c.ready_to_claim("quest_000_06"), "Actual camp rest advances its accepted objective")
	freeze_actors()
	var enemy = game.actors.filter(func(a): return a.kind=="enemy" and a.data_id=="")[0]
	enemy.pattern = "charge"
	enemy.position = Vector3(0,2,4)
	game.player.position = Vector3(0,.1,13)
	enemy.velocity = Vector3(0,-2,0)
	enemy.charge_clock = .5
	enemy.charge_direction = Vector3.BACK
	enemy.attack_time = 0
	enemy._physics_process(.1)
	check(is_equal_approx(enemy.charge_clock,.4), "An active charge advances beyond its initiation range")
	check(enemy.velocity.y < -2, "Charging preserves gravity")
	enemy.position = Vector3(0,0,11.9)
	enemy.charge_clock = .4
	enemy.charge_hit = false
	game.state.health = 100
	await physics_frame
	enemy._physics_process(.01)
	check(game.state.health==100-enemy.attack_damage and enemy.charge_hit, "A charging enemy damages the player on contact")
	enemy.position = Vector3(0,0,11.9)
	enemy._physics_process(.01)
	check(game.state.health==100-enemy.attack_damage, "One charge cannot deal damage on every physics tick")
	var barrier = StaticBody3D.new()
	var collision = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(2,3,.15)
	collision.shape = shape
	barrier.position = Vector3(0,1.5,12.4)
	barrier.add_child(collision)
	game.add_child(barrier)
	enemy.position = Vector3(0,0,11.9)
	enemy.charge_clock = .4
	enemy.charge_hit = false
	game.state.health = 100
	await physics_frame
	enemy._physics_process(.01)
	check(game.state.health==100, "Solid geometry blocks charge contact damage")
	barrier.free()
	enemy.pattern = "melee"
	enemy.charge_clock = 0
	enemy.position = Vector3(0,0,3)
	enemy.warning_time = .4
	enemy._physics_process(.01)
	check(enemy.warning_time==0, "Pursuit cancels an unfinished attack windup")
	enemy.position = Vector3(0,0,11.9)
	enemy.previous_animation_state = "walk"
	enemy.animation_clock = 5
	enemy.phase = 2.5
	enemy.attack_time = .5
	enemy._physics_process(.01)
	check(enemy.animation_clock==0 and enemy.sprite.texture==enemy.frames[8], "Attack animations start on their first authored pose")
	game.show_modal("pause","Pause",[])
	var animation_before = enemy.animation_clock
	enemy._physics_process(.1)
	check(enemy.animation_clock==animation_before, "Pause freezes state-local animation clocks")
	game.close_modal()
	enemy.warning_time = .6
	enemy.charge_clock = .5
	enemy.charge_hit = true
	game.respawn()
	check(enemy.warning_time==0 and enemy.charge_clock==0 and not enemy.charge_hit and enemy.charge_direction==Vector3.ZERO, "Respawn clears pending charges and warnings")
	game.state.realm = 2
	game.state.quest = 3
	game.state.seals = 3
	game.state.defeated = 3
	game.collected = ["seal_0","seal_1","seal_2"]
	game.defeated_ids = ["Meridian Warden 0","Meridian Warden 1","Meridian Warden 2"]
	var boss = game.actors.filter(func(a): return a.kind=="boss")[0]
	boss.hit(10000)
	game.choose_ending(false)
	check(game.state.ending=="Ascension" and game.state.realm==3, "Ascension grants the Golden Core promised by its story")
	game.close_modal()
	check(game.load_game() and game.state.realm==3 and game.state.ending=="Ascension", "Ascension Golden Core survives its autosave")
	print("REVISION_TESTS checks=%d passed=%d failed=%d" % [checks,checks-failures.size(),failures.size()])
	game.stop_audio()
	game.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)
