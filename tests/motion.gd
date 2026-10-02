extends SceneTree

const Bank = preload("res://scripts/animation_bank.gd")
var checks = 0
var failures: Array[String] = []
var game: Node

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error(label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	game = load("res://main.tscn").instantiate()
	game.save_path = "user://motion-autosave.json"
	root.add_child(game)
	await process_frame
	await physics_frame
	game.player.set_physics_process(false)
	for actor in game.actors:
		actor.set_physics_process(false)
		check(actor.frames.size() == 50 and actor.frames[0].get_size() == Vector2(320,320), "Complete frames load for " + actor.actor_name)
	var npc = game.actors.filter(func(a): return a.data_id == "npc_000")[0]
	game.begin()
	npc.previous_animation_state = ""
	var seen: Dictionary = {}
	for frame in range(16):
		npc._physics_process(1.0 / 12.0)
		seen[npc.sprite.texture] = true
	check(seen.size() == 8, "Idle traverses all eight visible poses at 12 FPS")
	game.show_modal("pause","Pause",[])
	var clock = npc.animation_clock
	var texture = npc.sprite.texture
	npc._physics_process(.5)
	check(npc.animation_clock == clock and npc.sprite.texture == texture, "Pause freezes texture and state clock")
	game.close_modal()
	var enemy = game.actors.filter(func(a): return a.data_id == "monster_000")[0]
	enemy.position = Vector3(0,0,6)
	enemy.speed = 0
	enemy.pattern = "melee"
	enemy.previous_animation_state = ""
	game.player.position = Vector3(0,.1,12)
	seen.clear()
	for frame in range(32):
		enemy._physics_process(1.0 / 24.0)
		seen[enemy.sprite.texture] = true
	check(enemy.animation_state == "walk" and seen.size() == 16, "Pursuit traverses sixteen walking poses at 24 FPS")
	enemy.position = Vector3(0,0,10.9)
	enemy.attack_time = 100
	enemy.animation_clock = 9
	await physics_frame
	enemy._physics_process(1.0 / 24.0)
	check(enemy.animation_clock == 0 and enemy.sprite.texture == enemy.frames[24], "Switching from walk starts attack on its first frame")
	seen.clear()
	for frame in range(32):
		enemy._physics_process(1.0 / 24.0)
		seen[enemy.sprite.texture] = true
	check(enemy.animation_state == "attack" and seen.size() == 16, "Attack traverses sixteen poses at 24 FPS")
	enemy.alive = false
	enemy.death_time = .8
	enemy._physics_process(.1)
	var last = enemy.sprite.texture
	enemy._physics_process(.1)
	check(last == enemy.frames[49] and enemy.sprite.texture == last, "Death holds its final pose instead of wrapping")
	var canvas = game.find_children("*","CanvasLayer",true,false)[0]
	var hud = canvas.get_children()[0]
	game.state.hair = 2
	game.state.clothing = 3
	hud._process(.01)
	check(hud.avatar_identity == "hero_011" and hud.active_avatar_frames.size() == 50, "Appearance changes select the matching complete animation bank")
	game.show_modal("pause","Pause",[])
	clock = hud.avatar_clock
	hud._process(.2)
	check(hud.avatar_clock == clock, "Pause freezes heroine animation")
	game.close_modal()
	for region in game.campaign.regions:
		check(game.travel(region.id), "Animation visit reaches " + region.id)
		await process_frame
		for actor in game.actors:
			actor.set_physics_process(false)
			if actor.data_id != "":
				check(actor.frames.size() == 50, "Live regional animation bank " + actor.data_id)
		check(Bank.cached_count() <= Bank.CACHE_LIMIT, "Regional travel bounds retained animation banks")
	check(game.avatar_frames.size() == 50, "Only the selected heroine bank is retained")
	print("MOTION_TESTS checks=%d passed=%d failed=%d" % [checks, checks-failures.size(), failures.size()])
	game.stop_audio()
	game.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)
