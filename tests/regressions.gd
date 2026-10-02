extends SceneTree

var game: Node
var checks = 0
var failures: Array[String] = []

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error(label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	game = load("res://main.tscn").instantiate()
	game.save_path = "user://regression-autosave.json"
	root.add_child(game)
	await process_frame
	await physics_frame
	var enemy = game.actors[6]
	var enemy_health = enemy.health
	game.player.position = enemy.position+Vector3(0,.1,2)
	game.attack()
	game.state.realm = 1
	game.spirit_palm()
	game.interact(game.interactables[0])
	check(enemy.health==enemy_health and game.state.herbs==0 and game.state.stamina==100, "Title blocks combat and item rewards")
	game.state.realm = 0
	game.player.position = Vector3(0,.15,13)
	game.begin()
	var event_count = InputMap.action_get_events("forward").size()
	game.configure_input()
	check(InputMap.action_get_events("forward").size()==event_count, "Input setup is idempotent")
	game.player.velocity = Vector3(3,5,-4)
	game.player.attack_clock = .7
	game.spirit_cooldown = 2.4
	game.show_modal("pause","Pause",[])
	var position_before = game.player.position
	var velocity_before = game.player.velocity
	var phase_before = enemy.phase
	for _frame in range(15): await physics_frame
	check(game.player.position==position_before and game.player.velocity==velocity_before, "Pause freezes horizontal motion and gravity")
	check(game.player.attack_clock==.7 and game.spirit_cooldown==2.4, "Pause freezes combat cooldowns")
	check(enemy.phase==phase_before, "Pause freezes actor animation timers")
	game.attack()
	game.spirit_palm()
	check(enemy.health==enemy_health and game.state.stamina==100, "Modal blocks combat methods")
	game.close_modal()
	game.player.reset_motion()
	var health_before = game.state.health
	game.take_damage(-10)
	game.take_damage(NAN)
	game.take_damage(INF)
	check(game.state.health==health_before, "Negative and non-finite damage is ignored")
	enemy.hit(-10)
	enemy.hit(NAN)
	enemy.hit(INF)
	check(enemy.health==enemy_health, "Negative and non-finite hits cannot heal or corrupt an enemy")
	game.state.herbs = 3
	check(not game.heal() and game.state.herbs==3, "Full vitality does not consume moonlotus")
	game.state.health = 60
	check(game.heal() and game.state.herbs==2 and game.state.health==100, "Healing consumes one root and caps vitality")
	game.state.herbs = 0
	# Build an obstruction and test actual physics raycasts, not a stub.
	game.player.position = Vector3(0,.1,12)
	game.player.rotation.y = 0
	game.player.camera.rotation.x = 0
	enemy.position = Vector3(0,0,9)
	var barrier = StaticBody3D.new()
	var shape = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(4,3,.5)
	shape.shape = box
	barrier.position = Vector3(0,1.5,10.5)
	barrier.add_child(shape)
	game.add_child(barrier)
	await physics_frame
	check(not game.line_of_sight(game.player.camera.global_position,enemy.position+Vector3.UP,enemy), "World geometry blocks sight")
	enemy_health = enemy.health
	game.player.attack_clock = 0
	game.attack()
	game.state.realm = 1
	game.spirit_cooldown = 0
	game.spirit_palm()
	check(enemy.health==enemy_health, "Sword and spirit palm cannot hit through a wall")
	game.show_modal("pause","Pause",[])
	var actor_position = enemy.position
	for _frame in range(4): await physics_frame
	check(enemy.position==actor_position, "Paused enemies do not pursue")
	game.close_modal()
	enemy.position = Vector3(0,0,10.1)
	enemy.attack_time = 0
	game.state.health = 100
	for _frame in range(40): await physics_frame
	check(game.state.health==100, "Enemy attacks cannot cross solid geometry")
	barrier.free()
	enemy.position = enemy.spawn_position
	game.player.position = Vector3(0,.1,13)
	game.player.reset_motion()
	game.state.realm = 0
	game.state.health = 100
	var original_qi = game.state.qi
	game.interact({"id":"invented","kind":"qi","value":100000})
	game.interact({"id":"qi_0","kind":"qi","value":100000})
	check(game.state.qi==original_qi, "Forged and distant reward targets cannot grant qi")
	var target = game.interactables[0]
	game.player.position = target.node.position+Vector3(0,.1,2)
	game.interact(target)
	var roots = game.state.herbs
	var qi = game.state.qi
	game.interact(target)
	check(game.state.herbs==roots and game.state.qi==qi, "Collected items grant rewards once")
	game.choose_ending(true)
	check(game.state.ending=="", "An ending cannot be selected before Xu falls")
	game.player.position = Vector3(0,.15,13)
	game.state.health = 1
	game.player.yaw = 1.5
	game.player.pitch = .7
	game.player.attack_clock = 1
	game.spirit_cooldown = 2
	game.take_damage(10)
	check(game.state.health==game.state.max_health() and game.player.yaw==0 and game.player.pitch==0, "Respawn resets aim and vitality")
	check(game.player.attack_clock==0 and game.spirit_cooldown==0, "Respawn resets stale combat timers")
	check(enemy.position==enemy.spawn_position and enemy.attack_time==2, "Respawn returns pursuers to their spawn")
	check(game.effects.size()==12, "Effects use a bounded playback pool")
	# Test every quest chain independently from UI delivery.
	var Campaign = load("res://scripts/campaign.gd")
	var c = Campaign.new()
	var kinds: Dictionary = {}
	for npc in c.npcs.values():
		for id in npc.quests:
			var q = c.quests[id]
			kinds[q.objective.kind] = true
			check(c.accept(id), "Quest prerequisite permits " + id)
			c.record(q.objective.kind,"wrong-target",100)
			check(c.active[id]==0, "Unrelated events do not advance " + id)
			c.record(q.objective.kind,q.objective.target,int(q.objective.count))
			check(c.ready_to_claim(id), "Objective completes " + id)
			check(c.claim(id,"wrong-owner").is_empty(), "Wrong author cannot claim " + id)
			check(not c.claim(id,q.owner,"mercy").is_empty(), "Correct author claims " + id)
			check(c.claim(id,q.owner).is_empty() and not c.accept(id), "Rewards and completion are idempotent " + id)
	check(c.completed.size()==1200 and kinds.size()==5, "All 1,200 chapters and five objective kinds are completable")
	check(c.valid_saved(c.to_dict()), "All completed quest chains serialize consistently")
	var bad = c.to_dict()
	bad.active["quest_000_00"] = 1
	check(not c.valid_saved(bad), "Completed quests cannot also be active")
	bad = c.to_dict()
	bad.completed.erase("quest_000_00")
	check(not c.valid_saved(bad), "Saved chains cannot omit a prerequisite")
	var small = Campaign.new()
	for i in range(6): check(small.accept("quest_%03d_00" % i), "Six active account capacity")
	check(not small.accept("quest_006_00"), "Seventh active account is rejected")
	check(not small.accept("quest_020_05"), "Later chapters cannot skip prerequisites")
	check(small.abandon("quest_000_00") and small.accept("quest_006_00"), "Abandon frees a quest slot")
	for book in range(12):
		check(not c.story("quest_%03d_00" % book).is_empty(), "Every regional chapter book can be read")
		check(c.book_cache.size()<=2, "Regional reading cache stays bounded")
	# Visit every actual region and inspect the spawned, image-backed cast.
	var npcs: Dictionary = {}
	var monsters: Dictionary = {}
	for region in game.campaign.regions:
		check(game.travel(region.id), "Travel reaches " + region.id)
		await process_frame
		for actor in game.actors:
			if actor.data_id=="": continue
			check(actor.frames.size()==50 and actor.frames[0].get_height()==320, "Registered complete animation frames load for " + actor.data_id)
			if actor.kind=="npc": npcs[actor.data_id]=true
			else: monsters[actor.data_id]=true
		check(game.regional_nodes.size()==11, "Region contains three landmarks and eight renewable resources")
	check(npcs.size()==100 and monsters.size()==100, "All 100 NPCs and 100 monsters appear in reachable regions")
	game.travel("region_00")
	var author = game.actors.filter(func(a): return a.data_id=="npc_000")[0]
	game.player.position = author.position+Vector3(0,.1,2)
	game.talk(author)
	check(game.modal_kind=="campaign" and game.campaign_panel.visible, "Talking opens the long-form journal")
	check(game.accept_quest("quest_000_00"), "Nearby author permits accepting her chapter")
	check(game.claim_quest("quest_000_00"), "Completed testimony grants a reward beside its author")
	check(game.accept_quest("quest_000_01"), "Claiming unlocks the next chapter")
	game.close_modal()
	for i in range(3):
		var root_item = game.regional_items[i]
		game.player.position = root_item.node.position+Vector3(0,.1,2)
		game.interact(root_item)
	check(game.campaign.ready_to_claim("quest_000_01"), "Actual regional gathering advances the accepted task")
	game.player.position = author.position+Vector3(0,.1,2)
	game.talk(author)
	check(game.claim_quest("quest_000_01"), "Gathering task returns to the author")
	check(game.accept_quest("quest_000_02"), "Exploration chapter unlocks")
	var destination = game.campaign.quests["quest_000_02"].objective.target
	game.travel(destination)
	check(game.campaign.ready_to_claim("quest_000_02"), "Travel records the actual destination")
	game.travel("region_00")
	game.player.position = Vector3(0,.15,13)
	game.state.health = 50
	check(game.rest_at_camp() and game.state.health==game.state.max_health(), "Camp renews resources and vitality")
	game.state.stamina = 42
	game.player.yaw = .6
	game.player.pitch = -.2
	game.state.hair = 3
	game.state.clothing = 2
	game.state.weapon = 3
	check(game.save_game("user://regression-v2.json"), "Atomic version two save succeeds")
	game.campaign.active.clear()
	game.campaign.completed.clear()
	game.state.stamina = 100
	game.state.hair = 0
	game.player.yaw = 0
	check(game.load_game("user://regression-v2.json"), "Version two restores")
	check(game.campaign.completed.size()==2 and game.campaign.ready_to_claim("quest_000_02"), "Save retains quest progress and completed accounts")
	check(game.state.stamina==42 and game.player.yaw==.6 and game.player.pitch==-.2, "Save retains stamina and view orientation")
	check(game.state.hair==3 and game.state.clothing==2 and game.state.weapon==3, "Save retains each appearance choice")
	check(game.save_game("user://regression-v2.json") and FileAccess.file_exists("user://regression-v2.json.bak"), "Replacing a save retains a backup")
	check(not game.travel("unknown") and not game.walkable(Vector3(NAN,0,0)), "Unknown destinations and non-finite positions are rejected")
	print("REGRESSION_TESTS checks=%d passed=%d failed=%d" % [checks,checks-failures.size(),failures.size()])
	game.stop_audio()
	game.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)
