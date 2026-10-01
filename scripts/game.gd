extends Node3D

const Cultivation = preload("res://scripts/cultivation.gd")
const Player = preload("res://scripts/player.gd")
const Actor = preload("res://scripts/actor.gd")
const HUD = preload("res://scripts/hud.gd")
const SHRINES = [Vector3(-14, 0, -15), Vector3(15, 0, -34), Vector3(-13, 0, -53)]
const SPRITE_GROUPS = ["villagers", "spirit_beasts", "corrupted", "sect_heroes", "ancient_spirits", "female_protagonist"]
var state = Cultivation.new()
var player: CharacterBody3D
var actors: Array = []
var interactables: Array = []
var atlases: Array[Texture2D] = []
var avatar_atlas: Texture2D
var weapon_atlas: Texture2D
var avatar_frames: Array[Texture2D] = []
var audio_enabled = true
var model_cache: Dictionary = {}
var collected: Array = []
var defeated_ids: Array = []
var save_path = "user://journey.json"
var started = false
var modal = false
var modal_kind = ""
var modal_title = ""
var modal_lines: Array[String] = []
var modal_footer = ""
var prompt = ""
var notice = ""
var notice_time = 0.0
var swing_time = 0.0
var damage_flash = 0.0
var spirit_cooldown = 0.0
var music: AudioStreamPlayer
var voice: AudioStreamPlayer
var rng = RandomNumberGenerator.new()
var elapsed = 0.0
var smoke_mode = false
var capture_mode = false

func _ready() -> void:
	rng.seed = 7301
	audio_enabled = DisplayServer.get_name() != "headless"
	configure_input()
	for i in range(5):
		atlases.append(load("res://assets/sprites/atlas_%d.png" % i))
	avatar_atlas = load("res://assets/sprites/atlas_5.png")
	weapon_atlas = load("res://assets/sprites/weapons.png")
	for row in range(16):
		for frame in range(16):
			avatar_frames.append(load("res://assets/sprites/frames/female_protagonist_%02d_%02d.tres" % [row, frame]))
	build_world()
	player = Player.new()
	player.game = self
	player.position = Vector3(0, .15, 10)
	add_child(player)
	populate()
	var canvas = CanvasLayer.new()
	add_child(canvas)
	var hud = HUD.new()
	hud.game = self
	canvas.add_child(hud)
	music = AudioStreamPlayer.new()
	music.bus = "Music"
	music.stream = load("res://assets/audio/valley.wav")
	music.finished.connect(func(): music.play())
	add_child(music)
	voice = AudioStreamPlayer.new()
	voice.bus = "Voice"
	add_child(voice)
	if audio_enabled:
		music.play()
	var args = OS.get_cmdline_user_args()
	smoke_mode = "--smoke" in args
	capture_mode = "--capture" in args
	if smoke_mode:
		call_deferred("run_smoke")
	elif capture_mode:
		call_deferred("capture_screenshots")

func configure_input() -> void:
	var keys = {"forward": KEY_W, "back": KEY_S, "left": KEY_A, "right": KEY_D, "sprint": KEY_SHIFT, "jump": KEY_SPACE, "interact": KEY_E, "cultivate": KEY_C, "journal": KEY_J, "spirit": KEY_Q, "heal": KEY_H, "save": KEY_F5, "load": KEY_F9, "appearance": KEY_P}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var event = InputEventKey.new()
		event.physical_keycode = keys[action]
		InputMap.action_add_event(action, event)

func material(color: Color, glow: float = 0) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = .9
	if glow > 0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = glow
	return mat

func surface(pos: Vector3, dimensions: Vector2, color: Color, texture_path: String = "") -> MeshInstance3D:
	var node = MeshInstance3D.new()
	var mesh = PlaneMesh.new()
	mesh.size = dimensions
	node.mesh = mesh
	var mat = material(color)
	if texture_path != "":
		mat.albedo_texture = load(texture_path)
		mat.uv1_scale = Vector3(35, 35, 1)
	node.material_override = mat
	node.position = pos
	add_child(node)
	return node

func prop(family: String, variant: int, pos: Vector3, scale_value: Vector3 = Vector3.ONE, yaw_value: float = 0) -> Node3D:
	var path = "res://assets/world/%s_%02d.glb" % [family, variant % 64]
	if not model_cache.has(path):
		model_cache[path] = load(path)
	var node = model_cache[path].instantiate()
	node.position = pos
	node.scale = scale_value
	node.rotation.y = yaw_value
	add_child(node)
	return node

func solid(pos: Vector3, box: Vector3) -> void:
	var body = StaticBody3D.new()
	var collision = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = box
	collision.shape = shape
	body.position = pos
	body.add_child(collision)
	add_child(body)

func build_world() -> void:
	var world_env = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky = Sky.new()
	var sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("173c50")
	sky_mat.sky_horizon_color = Color("92aaa2")
	sky_mat.ground_bottom_color = Color("182b2c")
	sky_mat.ground_horizon_color = Color("758f89")
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c0dfd4")
	env.ambient_light_energy = .38
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color("6e958b")
	env.fog_density = .018
	world_env.environment = env
	add_child(world_env)
	var sun = DirectionalLight3D.new()
	sun.light_color = Color("ffdfa8")
	sun.light_energy = .95
	sun.rotation_degrees = Vector3(-32, -35, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70
	add_child(sun)
	surface(Vector3(0, -.04, -35), Vector2(160, 200), Color("415d50"), "res://assets/world/rock_00.png")
	solid(Vector3(0, -.55, -35), Vector3(160, 1, 200))
	surface(Vector3(0, .012, -30), Vector2(5.3, 104), Color("b4a288"), "res://assets/world/rock_04.png")
	for point in SHRINES:
		surface(Vector3(point.x * .5, .017, point.z), Vector2(absf(point.x) + 4, 3), Color("82937f"))
	# River, distant silhouettes, and landmark composition.
	var river = surface(Vector3(25, .035, -35), Vector2(9, 135), Color("3e8482"))
	river.material_override.metallic = .55
	river.material_override.roughness = .15
	for i in range(15):
		var side = -1 if i % 2 == 0 else 1
		var mountain = prop("rock", i, Vector3(side * rng.randf_range(37, 60), -1, -i * 9 + 8), Vector3(rng.randf_range(12, 22), rng.randf_range(14, 35), rng.randf_range(12, 22)))
		var mountain_mat = material(Color("365456"))
		mountain_mat.albedo_texture = load("res://assets/world/rock_%02d.png" % i)
		for mesh_node in mountain.find_children("*", "MeshInstance3D", true, false):
			mesh_node.material_override = mountain_mat
	for i in range(130):
		var side = -1 if i % 2 == 0 else 1
		var x = side * rng.randf_range(9, 34)
		var z = rng.randf_range(-80, 16)
		var skip = false
		for point in SHRINES:
			if Vector3(x, 0, z).distance_to(point) < 5:
				skip = true
		if skip:
			continue
		var family = "bamboo" if i % 3 != 0 else "pine"
		prop(family, i % 64, Vector3(x, 0, z), Vector3.ONE * rng.randf_range(.9, 1.5), rng.randf_range(0, TAU))
	for i in range(24):
		prop("rock", i, Vector3(rng.randf_range(-22, 22), 0, rng.randf_range(-75, 10)), Vector3.ONE * .55)
	prop("gate", 0, Vector3(0, 0, 0))
	prop("gate", 12, Vector3(0, 0, -39))
	prop("pavilion", 0, Vector3(-7, 0, -5))
	prop("pavilion", 7, Vector3(8, 0, -21))
	prop("pagoda", 6, Vector3(0, 0, -78), Vector3.ONE * 1.5)
	prop("bridge", 3, Vector3(25, .08, -24), Vector3(1, 1, 2))
	for i in range(14):
		var side = -1 if i % 2 == 0 else 1
		var point = Vector3(side * 3.9, 0, 6 - i * 5.7)
		prop("lantern", i, point)
		if i < 4:
			var light = OmniLight3D.new()
			light.position = point + Vector3.UP * 2
			light.light_color = Color("ffbc67")
			light.light_energy = 1.5
			light.omni_range = 6
			add_child(light)
	for point in SHRINES:
		prop("shrine", int(absf(point.x)), point)
		prop("banner", int(absf(point.z)), point + Vector3(2, 0, 1))
		prop("ruin", int(absf(point.z)), point + Vector3(-3, 0, -2))
	prop("bench", 4, Vector3(-7, 0, -1))
	prop("urn", 1, Vector3(-5, 0, -4))
	# Physical boundaries; enemy navigation also respects the valley bounds.
	solid(Vector3(-32, 3, -35), Vector3(1, 6, 130))
	solid(Vector3(31, 3, -35), Vector3(1, 6, 130))
	solid(Vector3(0, 3, 19), Vector3(64, 6, 1))
	solid(Vector3(0, 3, -91), Vector3(64, 6, 1))
	for x in [-2, 2]:
		solid(Vector3(x, 2, 0), Vector3(.4, 4, .4))

func spawn_actor(name_value: String, kind_value: String, sheet_value: int, row_value: int, point: Vector3, hp: float = 55) -> Node3D:
	var actor = Actor.new()
	actor.game = self
	actor.actor_name = name_value
	actor.kind = kind_value
	actor.sheet = sheet_value
	actor.row = row_value
	actor.position = point
	actor.health = hp
	add_child(actor)
	actors.append(actor)
	return actor

func item(id: String, kind: String, point: Vector3, family: String, variant: int, value: int = 0) -> void:
	var node = prop(family, variant, point, Vector3.ONE * (.5 if kind == "herb" else 1))
	interactables.append({"id": id, "kind": kind, "node": node, "value": value})

func populate() -> void:
	spawn_actor("Mei · Lotus Healer", "npc", 0, 1, Vector3(-3.1, 0, 3.0))
	spawn_actor("Master Shen · Last Witness", "npc", 0, 2, Vector3(7, 0, -21))
	spawn_actor("Lan · The Bell Keeper", "npc", 3, 7, Vector3(-4, 0, -42))
	for i in range(9):
		item("herb_%d" % i, "herb", Vector3((-1 if i % 2 == 0 else 1) * (3.0 + i % 3), 0, 5 - i * 4), "crystal", 30 + i)
	for i in range(15):
		item("qi_%d" % i, "qi", Vector3((-1 if i % 2 == 0 else 1) * 5.8, 0, -3 - i * 4.6), "crystal", i, 22)
	for i in range(3):
		interactables.append({"id": "seal_%d" % i, "kind": "seal", "node": Node3D.new(), "value": i})
		var node = interactables.back().node
		node.position = SHRINES[i]
		add_child(node)
		spawn_actor("Meridian Warden %d" % i, "guardian", 2, 2 + i, SHRINES[i] + Vector3(0, 0, 4), 80 + i * 20)
	for i in range(8):
		spawn_actor("Ash Spirit %d" % i, "enemy", 2 if i % 2 == 0 else 1, i % 14, Vector3((-1 if i % 2 == 0 else 1) * (7 + i % 3), 0, -17 - i * 6), 45 + i * 4)
	spawn_actor("Immortal Xu · The Hollow Sun", "boss", 4, 15, Vector3(0, 0, -73), 300)

func walkable(point: Vector3) -> bool:
	return absf(point.x) < 30 and point.z < 18 and point.z > -90

func _process(delta: float) -> void:
	elapsed += delta
	notice_time = maxf(0, notice_time - delta)
	damage_flash = maxf(0, damage_flash - delta * 2.5)
	spirit_cooldown = maxf(0, spirit_cooldown - delta)
	swing_time = maxf(0, swing_time - delta * 3.2)
	prompt = ""
	if started and not modal:
		var target = nearby()
		if not target.is_empty():
			prompt = "E  ·  " + target.label

func nearby() -> Dictionary:
	var best: Dictionary = {}
	var distance = 3.7
	var forward = -player.camera.global_transform.basis.z
	for actor in actors:
		if not is_instance_valid(actor) or not actor.alive or actor.kind != "npc":
			continue
		var delta = actor.position + Vector3.UP - player.camera.global_position
		if delta.length() < distance and forward.dot(delta.normalized()) > .45:
			distance = delta.length()
			best = {"kind": "npc", "actor": actor, "label": actor.actor_name}
	for target in interactables:
		if target.id in collected:
			continue
		var delta = target.node.position + Vector3.UP * .7 - player.camera.global_position
		if delta.length() < distance and forward.dot(delta.normalized()) > .30:
			distance = delta.length()
			best = target.duplicate()
			best.label = {"herb": "Gather moonlotus", "qi": "Absorb jade essence", "seal": "Restore the meridian seal"}[target.kind]
	return best

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_P:
			show_appearance()
			return
		if modal_kind == "appearance" and event.keycode in [KEY_1, KEY_2, KEY_3]:
			cycle_appearance(int(event.keycode - KEY_1))
			return
		if event.keycode == KEY_ENTER:
			if modal_kind == "appearance":
				close_modal()
			elif not started:
				begin()
			elif modal_kind == "cultivate":
				meditate()
			else:
				close_modal()
			return
		if event.keycode == KEY_L and not started:
			load_game()
			return
		if event.keycode == KEY_ESCAPE:
			if modal:
				close_modal()
			elif started:
				show_modal("pause", "The mountain waits", ["Your journey is paused.", "F5 saves your journey. F9 restores it.", "M toggles music. V toggles voiced dialogue.", "WASD move · Shift sprint · Space jump", "E interact · H use a moonlotus to heal", "Left click attack · Q spirit palm", "C cultivation · J journal · P appearance"], "ENTER / ESC   Resume")
			return
		if event.keycode == KEY_F5:
			save_game()
			return
		if event.keycode == KEY_F9:
			load_game()
			return
		if event.keycode == KEY_M:
			AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), not AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")))
		if event.keycode == KEY_V:
			AudioServer.set_bus_mute(AudioServer.get_bus_index("Voice"), not AudioServer.is_bus_mute(AudioServer.get_bus_index("Voice")))
		if modal_kind == "ending" and event.keycode in [KEY_1, KEY_2]:
			choose_ending(event.keycode == KEY_1)
			return
	if modal_kind == "appearance" and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var origin = get_viewport().get_visible_rect().size / 2 - Vector2(430, 260)
		for i in range(3):
			if Rect2(origin + Vector2(302, 133 + i * 82), Vector2(506, 66)).has_point(event.position):
				cycle_appearance(i)
				return
	if not started:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			begin()
		return
	if modal:
		return
	if event.is_action_pressed("interact"):
		interact(nearby())
	if event.is_action_pressed("cultivate"):
		show_cultivation()
	if event.is_action_pressed("journal"):
		show_journal()
	if event.is_action_pressed("spirit"):
		spirit_palm()
	if event.is_action_pressed("heal"):
		if state.herbs > 0:
			state.herbs -= 1
			state.health = minf(state.max_health(), state.health + 45)
			sound("gather")
		else:
			notify("No moonlotus left. Gather the green jade blossoms.")
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		attack()

func begin() -> void:
	started = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	notify("Find Mei beneath the lanterns. Press E to speak.")
	speak("arrival")

func notify(message: String) -> void:
	notice = message
	notice_time = 5

func show_modal(kind: String, title: String, lines: Array[String], footer: String = "ENTER / ESC   Continue") -> void:
	modal = true
	modal_kind = kind
	modal_title = title
	modal_lines = lines
	modal_footer = footer
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func close_modal() -> void:
	# The final choice must be made; Escape cannot discard it.
	if modal_kind == "ending":
		return
	modal = false
	modal_kind = ""
	if started:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func show_appearance() -> void:
	if modal_kind == "ending":
		return
	show_modal("appearance", "Lin Yue", [], "1  Hair   ·   2  Clothing   ·   3  Weapon   ·   ENTER / ESC  Done")

func cycle_appearance(option: int) -> void:
	match option:
		0: state.hair = (state.hair + 1) % 4
		1: state.clothing = (state.clothing + 1) % 4
		2: state.weapon = (state.weapon + 1) % 4
	sound("gather")

func interact(target: Dictionary) -> void:
	if target.is_empty():
		return
	if target.kind == "npc":
		talk(target.actor)
		return
	if target.kind == "seal":
		var guardian = "Meridian Warden %d" % target.value
		if guardian not in defeated_ids:
			notify("The warden binds this seal. Defeat it first.")
			return
		state.seals += 1
		state.qi += 30
		collected.append(target.id)
		sound("seal")
		notify("Meridian restored · %d / 3. The mountain breathes again." % state.seals)
		if state.seals == 3:
			state.quest = maxi(state.quest, 3)
			speak("seals")
		return
	collected.append(target.id)
	target.node.visible = false
	if target.kind == "herb":
		state.herbs += 1
		state.qi += 8
		notify("Moonlotus gathered · %d. H restores vitality." % state.herbs)
	else:
		state.qi += target.value
		notify("Jade essence absorbed · +%d qi." % target.value)
	sound("gather")

func talk(actor: Node3D) -> void:
	if actor.actor_name.begins_with("Mei"):
		if state.quest == 0:
			state.quest = 1
			speak("mei")
			show_modal("dialogue", "Mei · Lotus Healer", ["You carry his sword. Then you survived the fire.", "Immortal Xu saved us once. Now our river tastes of ash.", "Bring me three moonlotus. Their roots remember clean water.", "They glow beside the road; press E to gather them.", "Do not spend them healing until you return to me."])
		elif state.quest == 1 and state.herbs >= 3:
			state.herbs -= 3
			state.qi += 50
			state.quest = 2
			show_modal("dialogue", "The roots remember", ["These roots carry a memory, not a poison.", "Xu bound his dead daughter's soul beneath the mountain.", "Her grief is drinking the meridians dry.", "Master Shen saw the binding. Find him down the road.", "Take this essence: 50 qi. C opens your cultivation."])
		else:
			show_modal("dialogue", "Mei · Lotus Healer", ["Three moonlotus will let us read the river's memory.", "When you are ready, follow the lantern road to Master Shen.", "Mercy is not weakness. Remember that at the summit."])
	elif actor.actor_name.begins_with("Master"):
		speak("shen")
		show_modal("dialogue", "Master Shen · Last Witness", ["Xu asked heaven to give his child back. Heaven was silent.", "So he chained her to the roots and called it immortality.", "Three wardens hold the seals: dawn, rain, and dusk.", "Defeat them, restore their altars, and the path will open.", "Cultivate to Foundation before you face Xu.", "Qi is power. What you do with it is cultivation."])
	else:
		speak("lan")
		show_modal("dialogue", "Lan · The Bell Keeper", ["I rang this bell for the dead. Xu ordered me to stop.", "He thought remembering was what kept grief alive.", "At the summit, you may sever the binding or inherit it.", "One frees a soul. The other makes an immortal.", "The mountain will remember your choice."])

func attack() -> void:
	if player.attack_clock > 0:
		return
	player.attack_clock = [.48, .62, .38, .55][state.weapon]
	swing_time = 1
	sound("sword")
	var forward = -player.camera.global_transform.basis.z
	var closest: Node3D = null
	var distance = [3.5, 3.1, 4.5, 5.5][state.weapon]
	for actor in actors:
		if not is_instance_valid(actor) or not actor.alive or actor.kind == "npc":
			continue
		var delta = actor.position + Vector3.UP - player.camera.global_position
		if delta.length() < distance and forward.dot(delta.normalized()) > .45:
			closest = actor
			distance = delta.length()
	if closest != null:
		if closest.kind == "boss" and (state.seals < 3 or state.realm < 2):
			notify("Xu's binding is unbroken. Restore 3 seals and reach Foundation.")
			return
		closest.hit(state.damage())

func spirit_palm() -> void:
	if state.realm < 1:
		notify("Awaken your qi first. Press C to cultivate.")
		return
	if spirit_cooldown > 0 or state.stamina < 35:
		notify("Spirit palm needs 35 stamina and a moment of stillness.")
		return
	state.stamina -= 35
	spirit_cooldown = 3
	sound("seal")
	var forward = -player.camera.global_transform.basis.z
	for actor in actors:
		if not is_instance_valid(actor) or not actor.alive or actor.kind == "npc":
			continue
		var delta = actor.position - player.position
		if delta.length() < 8 and forward.dot(delta.normalized()) > .55:
			if actor.kind != "boss" or (state.seals == 3 and state.realm >= 2):
				actor.hit(state.damage() * (2.4 if state.weapon == 3 else 1.6))
	notify("Spirit palm · the jade meridian answers.")

func take_damage(amount: float) -> void:
	if not started or modal:
		return
	state.health -= amount
	damage_flash = 1
	sound("hurt")
	if state.health <= 0:
		respawn()

func respawn() -> void:
	state.health = state.max_health()
	state.qi = maxi(0, state.qi - 15)
	player.position = Vector3(0, .15, 10)
	player.velocity = Vector3.ZERO
	notify("Mei found you in the reeds. Lost 15 unspent qi; your realm remains.")

func enemy_defeated(actor: Node3D) -> void:
	state.defeated += 1
	state.qi += 35 if actor.kind == "guardian" else 20
	defeated_ids.append(actor.actor_name)
	sound("gather")
	if actor.kind == "boss":
		speak("xu")
		show_modal("ending", "The last immortal", ["Xu falls. A child's voice rises from the roots.", '"Father, I was never afraid of leaving. Only of leaving you."', "The sword can sever the binding. Or you can take its power.", "", "1   Release her soul. Let the mountain live.", "2   Inherit the meridian. Become its immortal keeper."], "Choose 1 or 2   ·   This choice completes your journey")
	else:
		notify("%s released · qi gained." % actor.actor_name)

func choose_ending(mercy: bool) -> void:
	state.ending = "Mercy" if mercy else "Ascension"
	state.quest = 4
	modal_kind = "complete"
	modal_title = "The mountain remembers"
	modal_lines = ["ENDING   ·   " + state.ending.to_upper(), ""]
	if mercy:
		modal_lines.append_array(["The jade light leaves the roots like fireflies.", "Xu hears his daughter laugh for the last time.", "Spring returns to Cloudrest. Mei plants a lotus by the river.", "You remain mortal enough to remember her name."])
	else:
		modal_lines.append_array(["The mountain kneels. Its grief becomes your golden core.", "The river clears, but every bell speaks with a child's voice.", "Cloudrest has a new protector, and a new prisoner.", "Immortality is a promise someone else must keep."])
	modal_footer = "ENTER   Return to the valley   ·   F5   Save this ending"
	save_game()

func show_cultivation() -> void:
	var lines: Array[String] = ["CURRENT REALM   ·   " + state.REALMS[state.realm], "UNSPENT QI   ·   %d" % state.qi, ""]
	if state.realm < 3:
		lines.append("Next: %s · requires %d qi" % [state.REALMS[state.realm + 1], state.COSTS[state.realm]])
		lines.append("Breakthrough restores vitality and strengthens your sword.")
		lines.append("Qi Awakening unlocks Spirit Palm (Q).")
		lines.append("Foundation can break Immortal Xu's binding.")
	else:
		lines.append("Your golden core is whole. Power is no longer the question.")
	show_modal("cultivate", "Stillness before heaven", lines, "ENTER   Attempt breakthrough   ·   ESC   Return")

func meditate() -> void:
	if state.cultivate():
		sound("seal")
		notify("Breakthrough · " + state.REALMS[state.realm])
		close_modal()
	else:
		modal_footer = "Not enough qi, or Golden Core reached. ESC returns."

func show_journal() -> void:
	show_modal("journal", "The broken oath", ["An immortal saved Cloudrest from the imperial hunters.", "To preserve his daughter, he bound her soul to the mountain.", "Her unending grief now poisons the valley he swore to protect.", "", "1. Mei: gather three moonlotus and read the river's memory.", "2. Restore the three seals after defeating their wardens.", "3. Reach Foundation; confront Xu at the ruined pagoda.", "4. Choose what cultivation means when heaven falls silent."])

func objective_lines() -> Array[String]:
	if state.quest == 0:
		return ["Speak to Mei by the first gate.", "E interacts with people and jade."]
	if state.quest == 1:
		return ["Bring Mei three moonlotus.", "Gathered: %d / 3" % state.herbs]
	if state.quest == 2:
		return ["Restore three meridian seals.", "Seals: %d / 3 · Cultivate to Foundation" % state.seals]
	if state.quest == 3:
		return ["Face Immortal Xu at the pagoda.", "Reach Foundation to break his binding."]
	return ["The mountain remembers: " + state.ending, "Your journey is complete."]

func sound(name_value: String) -> void:
	if not audio_enabled:
		return
	var path = "res://assets/audio/%s.wav" % name_value
	if not ResourceLoader.exists(path):
		return
	var audio = AudioStreamPlayer.new()
	audio.stream = load(path)
	audio.bus = "Effects"
	add_child(audio)
	audio.finished.connect(audio.queue_free)
	audio.play()

func speak(name_value: String) -> void:
	if not audio_enabled:
		return
	var path = "res://assets/audio/voice_%s.wav" % name_value
	if ResourceLoader.exists(path):
		voice.stream = load(path)
		voice.play()

func stop_audio() -> void:
	# Flush playback references before headless test shutdown.
	for child in get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream = null

func save_game(path: String = "") -> bool:
	if path == "":
		path = save_path
	var data = state.to_dict()
	data["version"] = 1
	data["position"] = [player.position.x, player.position.y, player.position.z]
	data["collected"] = collected
	data["defeated_ids"] = defeated_ids
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		notify("Could not write the save file.")
		return false
	file.store_string(JSON.stringify(data, "\t"))
	notify("Journey saved · F9 restores it.")
	return true

func load_game(path: String = "") -> bool:
	if path == "":
		path = save_path
	if not FileAccess.file_exists(path):
		notify("No saved journey yet. F5 creates one.")
		return false
	var parser = JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:
		notify("Save file contains invalid JSON.")
		return false
	var data = parser.data
	if not data is Dictionary or data.get("version", 0) != 1 or not data.get("position") is Array or data.position.size() != 3:
		notify("Save file is invalid or uses a different version.")
		return false
	state.restore(data)
	collected = data.get("collected", [])
	defeated_ids = data.get("defeated_ids", [])
	player.position = Vector3(float(data.position[0]), maxf(.1, float(data.position[1])), float(data.position[2]))
	if not walkable(player.position):
		player.position = Vector3(0, .15, 10)
	for target in interactables:
		target.node.visible = target.id not in collected
	# Recreate enemies when loading an earlier save; keep NPCs and restored actors.
	for actor in actors:
		if is_instance_valid(actor) and actor.kind != "npc":
			actor.queue_free()
	actors = actors.filter(func(a): return is_instance_valid(a) and a.kind == "npc")
	for i in range(3):
		var id = "Meridian Warden %d" % i
		if id not in defeated_ids:
			spawn_actor(id, "guardian", 2, 2 + i, SHRINES[i] + Vector3(0, 0, 4), 80 + i * 20)
	for i in range(8):
		var id = "Ash Spirit %d" % i
		if id not in defeated_ids:
			spawn_actor(id, "enemy", 2 if i % 2 == 0 else 1, i % 14, Vector3((-1 if i % 2 == 0 else 1) * (7 + i % 3), 0, -17 - i * 6), 45 + i * 4)
	if "Immortal Xu · The Hollow Sun" not in defeated_ids:
		spawn_actor("Immortal Xu · The Hollow Sun", "boss", 4, 15, Vector3(0, 0, -73), 300)
	started = true
	modal_kind = ""
	close_modal()
	notify("Journey restored.")
	return true

func run_smoke() -> void:
	# Full quest checks live in tests; this exercises the running world and assets.
	await get_tree().physics_frame
	await get_tree().physics_frame
	var ok = atlases.size() == 5 and actors.size() == 15 and model_cache.size() > 35 and player.camera.current
	if not ok:
		push_error("World smoke check failed")
		get_tree().quit(1)
		return
	print("WORLD_SMOKE_PASS actors=%d models=%d atlases=%d" % [actors.size(), model_cache.size(), atlases.size()])
	stop_audio()
	await get_tree().create_timer(.15).timeout
	get_tree().quit(0)

func capture_screenshots() -> void:
	# Deterministic real engine renders, never mockups.
	for _frame in range(12):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/screenshots/title.png")
	begin()
	player.position = Vector3(0, .1, 7)
	player.camera.rotation.x = -.04
	for _frame in range(10):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/screenshots/valley.png")
	player.position = Vector3(-10, .1, -7)
	player.rotation.y = -.28
	player.yaw = -.28
	for _frame in range(10):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/screenshots/shrine.png")
	show_cultivation()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/screenshots/cultivation.png")
	show_appearance()
	state.hair = 1
	state.clothing = 1
	state.weapon = 2
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/screenshots/appearance.png")
	print("SCREENSHOTS_CAPTURED")
	stop_audio()
	await get_tree().create_timer(.15).timeout
	get_tree().quit(0)
