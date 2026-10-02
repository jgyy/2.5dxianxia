extends SceneTree

const Directions = preload("res://scripts/directional_sprites.gd")
var checks = 0
var failed = 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failed += 1
		push_error(label)

func _initialize() -> void:
	for index in range(12):
		var angle = index * TAU / 12
		check(Directions.view_index(angle) == index, "Thirty-degree sector center %d" % index)
		check(Directions.view_index(angle + TAU * 3) == index, "Positive full turns %d" % index)
		check(Directions.view_index(angle - TAU * 3) == index, "Negative full turns %d" % index)
		check(Directions.view_index(angle + deg_to_rad(14.9)) == index, "Below clockwise boundary %d" % index)
		check(Directions.view_index(angle + deg_to_rad(15.1)) == (index + 1) % 12, "Above clockwise boundary %d" % index)
	var origin = Vector3(17, 8, 60)
	check(Directions.relative_view(origin + Vector3(0, 2, 3), origin, PI) == 0, "Observer in front of a south-facing resident")
	check(Directions.relative_view(origin + Vector3(3, 2, 0), origin, PI) == 3, "Observer at the left profile")
	check(Directions.relative_view(origin + Vector3(0, 2, -3), origin, PI) == 6, "Observer behind the resident")
	check(Directions.relative_view(origin + Vector3(-3, 2, 0), origin, PI) == 9, "Observer at the right profile")
	check(Directions.relative_view(origin, origin, PI) == 0, "Coincident horizontal position remains deterministic")
	call_deferred("run")

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	game.player.set_physics_process(false)
	for actor in game.actors:
		actor.set_physics_process(false)
	game.show_turntable()
	check(game.modal_kind == "turntable" and game.turntable.visible and not game.playing(), "F2 preview pauses the world")
	check(game.turntable.grid.columns == 6 and game.turntable.grid.get_child_count() == 12, "All twelve views appear in the preview")
	for index in range(12):
		var drawing = game.turntable.grid.get_child(index).get_child(0)
		check(drawing.texture == game.directional.texture("hero_000", index), "Preview shows registered angle %d" % (index * 30))
	var key = InputEventKey.new()
	key.keycode = KEY_RIGHT
	key.pressed = true
	game.turntable._unhandled_key_input(key)
	check(game.turntable.angle == 1 and not game.turntable.all_views and game.turntable.preview.visible, "Right arrow selects the next view")
	check(game.turntable.preview.texture == game.directional.texture("hero_000", 1), "Single-view preview shows the chosen drawing")
	game.close_modal()
	check(not game.turntable.visible and not game.modal, "Closing the turntable restores the current screen")
	game.begin()
	var probe = game.spawn_actor("Directional test", "npc", 0, 1, Vector3(0, .05, 35))
	probe.visual_key = "hero_000"
	probe.set_physics_process(false)
	for index in range(12):
		var heading = PI + index * TAU / 12
		game.player.position = probe.position + Vector3(-sin(heading) * 3, .1, -cos(heading) * 3)
		await process_frame
		check(probe.view_direction == index, "Actual world camera selects view %d" % index)
		if index > 0:
			check(probe.sprite.texture == game.directional.texture("hero_000", index), "Actor displays the authored side/rear drawing %d" % index)
		check(is_equal_approx(probe.sprite.pixel_size * probe.sprite.texture.get_height(), 2.5), "View %d retains the same physical sprite height" % index)
	game.player.position = probe.position + Vector3(0, .1, 3)
	await process_frame
	check(probe.sprite.texture == probe.frames[0], "Returning to front restores the original animated frame")
	probe.visual_key = "npc_000"
	game.show_turntable()
	check(game.turntable.selected == "npc_000", "F2 selects the nearby character in view")
	game.close_modal()
	game.player.position = Vector3(0, .1, 7)
	game.show_turntable()
	check(game.turntable.selected == "hero_000", "F2 defaults to the current heroine away from characters")
	game.close_modal()
	game.show_modal("pause", "Paused", [])
	var paused_texture = probe.sprite.texture
	game.player.position = probe.position + Vector3(0, .1, -3)
	await process_frame
	check(probe.sprite.texture == paused_texture, "Pause freezes the actor's displayed orientation")
	game.close_modal()
	var attacker = game.spawn_actor("Attack test", "monster", 0, 0, Vector3(0, .05, 35), 55, "monster_001")
	attacker.set_physics_process(false)
	attacker.animation_state = "attack"
	attacker.facing_yaw = PI
	game.player.position = attacker.position + Vector3(0, .1, 3)
	for clock in [.0, .21, .41, .61]:
		attacker.animation_clock = clock
		attacker.update_directional_view()
		check(attacker.sprite.texture == attacker.frames[2], "Four-pose attacks retain the authored attack at %.2f seconds" % clock)
	game.stop_audio()
	game.queue_free()
	await process_frame
	print("DIRECTIONAL_TESTS checks=%d passed=%d failed=%d" % [checks, checks - failed, failed])
	quit(1 if failed else 0)
