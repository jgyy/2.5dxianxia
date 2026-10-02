extends SceneTree

var game: Node
var results: Array = []
var baseline = false

func record(id: String, condition: bool, category: String) -> void:
	results.append({"id":id,"pass":condition,"category":category})

func panel() -> void:
	var lines: Array[String] = []
	game.show_modal("pause","Audit pause",lines)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	game = load("res://main.tscn").instantiate()
	game.save_path = "user://gameplay-audit-only.json"
	root.add_child(game)
	await process_frame
	await physics_frame
	var enemy = game.actors[6]
	game.player.position = enemy.position+Vector3(0,.1,2)
	var health = enemy.health
	game.attack()
	record("PLAY-001",enemy.health==health,"combat on title screen")
	enemy.health = health
	enemy.alive = true
	if "reward_given" in enemy:
		enemy.reward_given = false
	game.state.realm = 1
	game.spirit_cooldown = 0
	game.spirit_palm()
	record("PLAY-002",enemy.health==health and game.state.stamina==100,"spirit palm on title screen")
	enemy.health = health
	enemy.alive = true
	if "reward_given" in enemy:
		enemy.reward_given = false
	game.state.realm = 0
	game.state.stamina = 100
	var item = game.interactables[0]
	game.player.position = item.node.position+Vector3(0,.1,2)
	game.interact(item)
	record("PLAY-003",game.state.herbs==0,"item rewards on title screen")
	game.state.herbs = 0
	game.collected.clear()
	item.node.visible = true
	game.begin()
	game.player.velocity = Vector3(3,5,-4)
	game.player.attack_clock = .7
	game.spirit_cooldown = 2.4
	panel()
	var before = game.player.position
	var phase = enemy.phase
	for _frame in range(5):
		await physics_frame
		await process_frame
	game._process(.1)
	if enemy.has_method("_process"):
		enemy.call("_process",.1)
	else:
		enemy._physics_process(.1)
	record("PLAY-004",game.player.position==before,"pause movement and gravity")
	record("PLAY-005",game.player.attack_clock==.7,"pause sword cooldown")
	record("PLAY-006",game.spirit_cooldown==2.4,"pause spirit cooldown")
	record("PLAY-007",enemy.phase==phase,"pause animation timers")
	game.player.attack_clock = 0
	game.player.position = enemy.position+Vector3(0,.1,2)
	health = enemy.health
	game.attack()
	record("PLAY-008",enemy.health==health,"combat during a modal")
	enemy.health = health
	enemy.alive = true
	if "reward_given" in enemy:
		enemy.reward_given = false
	game.close_modal()
	game.player.velocity = Vector3.ZERO
	game.player.position = item.node.position+Vector3(0,.1,2)
	game.interact(item)
	var roots = game.state.herbs
	var qi = game.state.qi
	game.interact(item)
	record("PLAY-009",game.state.herbs==roots and game.state.qi==qi,"duplicate collected item rewards")
	qi = game.state.qi
	game.interact({"id":"forged","kind":"qi","node":item.node,"value":999})
	record("PLAY-010",game.state.qi==qi,"forged item reward dictionary")
	game.state.quest = 0
	game.player.position = Vector3(0,.1,-60)
	game.interact({"kind":"npc","actor":game.actors[0]})
	record("PLAY-011",game.state.quest==0,"remote NPC progression")
	game.close_modal()
	enemy.health = 55
	enemy.hit(-10)
	record("PLAY-012",enemy.health==55,"negative enemy hit")
	enemy.health = 55
	enemy.hit(NAN)
	record("PLAY-013",enemy.health==55,"nonfinite enemy hit")
	enemy.health = 55
	game.state.health = 60
	game.take_damage(-10)
	record("PLAY-014",game.state.health==60,"negative player damage")
	game.state.health = 60
	game.take_damage(NAN)
	record("PLAY-015",game.state.health==60,"nonfinite player damage")
	game.state.health = 100
	game.state.herbs = 3
	var event = InputEventKey.new()
	event.keycode = KEY_H
	event.physical_keycode = KEY_H
	event.pressed = true
	game._unhandled_input(event)
	record("PLAY-016",game.state.herbs==3,"healing at full vitality consumes a herb")
	game.choose_ending(true)
	record("PLAY-017",game.state.ending=="","premature final ending")
	game.modal_kind = ""
	game.close_modal()
	game.state.ending = ""
	game.state.quest = 3
	game.state.realm = 2
	game.state.seals = 3
	game.state.defeated = 3
	game.collected = ["seal_0","seal_1","seal_2"]
	game.defeated_ids = ["Meridian Warden 0","Meridian Warden 1","Meridian Warden 2"]
	var boss = game.actors.filter(func(a): return a.kind=="boss")[0]
	boss.alive = false
	game.enemy_defeated(boss)
	game.choose_ending(true)
	game.choose_ending(false)
	record("PLAY-018",game.state.ending=="Mercy","repeated final choice changes ending")
	game.close_modal()
	var count = InputMap.action_get_events("forward").size()
	game.configure_input()
	record("PLAY-019",InputMap.action_get_events("forward").size()==count,"input registration idempotence")
	# Check model collision coverage on each instantiated physical prop.
	var prop_index = 0
	for node in game.get_children():
		if not node is Node3D or node.scene_file_path=="": continue
		var path = node.scene_file_path
		if not path.begins_with("res://assets/world/") or node.scale.length()>8: continue
		var family = path.get_file().split("_")[0]
		if family in ["crystal","sword","banner"]: continue
		prop_index += 1
		record("PROP-%03d" % prop_index,not node.find_children("*","StaticBody3D",true,false).is_empty(),"physical prop collision coverage")
	var failures = results.filter(func(r): return not r.pass).size()
	var output = "res://docs/audit/gameplay-results.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	var file = FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":results.size(),"failed":failures,"results":results},"\t"))
	file.close()
	print("GAMEPLAY_AUDIT checks=%d passed=%d failed=%d" % [results.size(),results.size()-failures,failures])
	game.stop_audio()
	game.queue_free()
	await process_frame
	quit(0 if failures==0 else 1)
