extends Node3D

const Cultivation = preload("res://scripts/cultivation.gd")
const Player = preload("res://scripts/player.gd")
const Actor = preload("res://scripts/actor.gd")
const HUD = preload("res://scripts/hud.gd")
const Campaign = preload("res://scripts/campaign.gd")
const CampaignPanel = preload("res://scripts/campaign_panel.gd")
const SaveCodec = preload("res://scripts/save_codec.gd")
const City = preload("res://scripts/city.gd")
const DirectionalSprites = preload("res://scripts/directional_sprites.gd")
const CharacterTurntable = preload("res://scripts/character_turntable.gd")
const SpriteLibrary = preload("res://scripts/sprite_library.gd")
const SHRINES = [Vector3(-14, 0, -15), Vector3(15, 0, -34), Vector3(-13, 0, -53)]
const SPRITE_GROUPS = ["villagers", "spirit_beasts", "corrupted", "sect_heroes", "ancient_spirits", "female_protagonist"]
var state = Cultivation.new()
var campaign = Campaign.new()
var campaign_panel: Control
var city: Node3D
var directional = DirectionalSprites.new()
var sprite_library = SpriteLibrary.new()
var turntable: Control
var regional_nodes: Array = []
var regional_items: Array = []
var regional_collected: Array = []
var regional_defeated: Array = []
var landmark_cache: Dictionary = {}
var world_environment: Environment
var ground: MeshInstance3D
var effects: Array[AudioStreamPlayer] = []
var sound_cache: Dictionary = {}
var player: CharacterBody3D
var actors: Array = []
var interactables: Array = []
var atlases: Array[Texture2D] = []
var avatar_atlas: Texture2D
var weapon_atlas: Texture2D
var weapon_frames: Array[Texture2D] = []
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
	avatar_atlas = load("res://assets/sprites/hires/hero_0.png")
	weapon_atlas = load("res://assets/sprites/weapons.png")
	for index in range(4):
		var weapon = AtlasTexture.new()
		weapon.atlas = weapon_atlas
		var cell = weapon_atlas.get_size() / 2
		weapon.region = Rect2(Vector2(index % 2, int(index / 2)) * cell, cell)
		weapon_frames.append(sprite_library.texture("res://assets/sprites/weapons/frames/weapon_%d.tres" % index, weapon))
	for row in range(16):
		for frame in range(4):
			avatar_frames.append(sprite_library.texture("res://assets/sprites/hires/frames/hero_%03d_%d.tres" % [row, frame]))
	build_world()
	player = Player.new()
	player.game = self
	player.position = Vector3(0, .15, 10)
	add_child(player)
	populate()
	city.finish_setup()
	var canvas = CanvasLayer.new()
	add_child(canvas)
	var hud = HUD.new()
	hud.game = self
	canvas.add_child(hud)
	campaign_panel = CampaignPanel.new()
	campaign_panel.game = self
	canvas.add_child(campaign_panel)
	turntable = CharacterTurntable.new()
	turntable.game = self
	canvas.add_child(turntable)
	spawn_region()
	for i in range(12):
		var effect = AudioStreamPlayer.new()
		effect.bus = "Effects"
		add_child(effect)
		effects.append(effect)
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
	capture_mode = "--capture" in args or "--capture-city" in args or "--capture-directions" in args
	if smoke_mode:
		call_deferred("run_smoke")
	elif "--capture-directions" in args:
		call_deferred("capture_directional_screenshots")
	elif "--capture-city" in args:
		call_deferred("capture_city_screenshots")
	elif capture_mode:
		call_deferred("capture_screenshots")

func configure_input() -> void:
	var keys = {"forward": KEY_W, "back": KEY_S, "left": KEY_A, "right": KEY_D, "sprint": KEY_SHIFT, "jump": KEY_SPACE, "interact": KEY_E, "cultivate": KEY_C, "journal": KEY_J, "spirit": KEY_Q, "heal": KEY_H, "save": KEY_F5, "load": KEY_F9, "appearance": KEY_P}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var event = InputEventKey.new()
		event.physical_keycode = keys[action]
		if not InputMap.action_has_event(action, event):
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
	if family not in ["crystal", "sword", "banner"] and scale_value.length() < 8:
		add_prop_collision(node, family)
	return node

func solid(pos: Vector3, box: Vector3) -> StaticBody3D:
	var body = StaticBody3D.new()
	var collision = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = box
	collision.shape = shape
	body.position = pos
	body.add_child(collision)
	add_child(body)
	return body

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
	world_environment = env
	add_child(world_env)
	var sun = DirectionalLight3D.new()
	sun.light_color = Color("ffdfa8")
	sun.light_energy = .95
	sun.rotation_degrees = Vector3(-32, -35, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70
	add_child(sun)
	ground = surface(Vector3(0, -.04, -35), Vector2(160, 200), Color("415d50"), "res://assets/world/rock_00.png")
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
		prop("rock", i, Vector3((-1 if i % 2 == 0 else 1) * rng.randf_range(11, 22), 0, rng.randf_range(-75, 10)), Vector3.ONE * .55)
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
	var camp = load("res://assets/props/camp_beacon.glb").instantiate()
	camp.position = Vector3(4,0,14)
	add_child(camp)
	add_prop_collision(camp)
	# Physical boundaries; enemy navigation also respects the valley bounds.
	solid(Vector3(-30.5, 3, -35), Vector3(1, 6, 130))
	solid(Vector3(30.5, 3, -35), Vector3(1, 6, 130))
	for side in [-1, 1]:
		solid(Vector3(side * 17, 3, 18.5), Vector3(26, 6, 1))
	solid(Vector3(0, 3, -90.5), Vector3(64, 6, 1))
	var gate = solid(Vector3(0, 3, 18.5), Vector3(8, 6, 1))
	city = City.new()
	city.game = self
	city.gate_collision = gate.get_child(0)
	add_child(city)


func spawn_actor(name_value: String, kind_value: String, sheet_value: int, row_value: int, point: Vector3, hp: float = 55, id: String = "", sprite_id: String = "") -> Node3D:
	var actor = Actor.new()
	actor.game = self
	actor.actor_name = name_value
	actor.kind = kind_value
	actor.data_id = id
	actor.sprite_id = sprite_id
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
	var southern_bound = City.CITY_END if campaign.current_region == "region_00" else 18.0
	return is_finite(point.x) and is_finite(point.y) and is_finite(point.z) and absf(point.x) < 30 and point.z < southern_bound and point.z > -90

func playing() -> bool:
	return started and not modal

func _process(delta: float) -> void:
	elapsed += delta
	notice_time = maxf(0, notice_time - delta)
	if playing():
		damage_flash = maxf(0, damage_flash - delta * 2.5)
		spirit_cooldown = maxf(0, spirit_cooldown - delta)
		swing_time = maxf(0, swing_time - delta * 3.2)
	prompt = ""
	if playing():
		var target = nearby()
		if not target.is_empty():
			prompt = "E  ·  " + target.label

func line_of_sight(from: Vector3, to: Vector3, actor: Node3D = null) -> bool:
	var ray = PhysicsRayQueryParameters3D.create(from, to, 1)
	ray.exclude = [player.get_rid()]
	if actor is CollisionObject3D:
		ray.exclude.append(actor.get_rid())
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func in_reach(point: Vector3, actor: Node3D = null, distance: float = 3.7) -> bool:
	return player.camera.global_position.distance_to(point) < distance and line_of_sight(player.camera.global_position, point, actor)

func interaction_point(target: Dictionary) -> Vector3:
	return target.node.position + Vector3.UP * (2.5 if target.kind == "seal" else .7)

func nearby() -> Dictionary:
	var best: Dictionary = {}
	var distance = 3.7
	var forward = -player.camera.global_transform.basis.z
	for actor in actors:
		if not is_instance_valid(actor) or not actor.alive or not actor.visible or actor.kind != "npc":
			continue
		var delta = actor.position + Vector3.UP - player.camera.global_position
		if delta.length() < distance and forward.dot(delta.normalized()) > .45 and line_of_sight(player.camera.global_position, actor.position + Vector3.UP, actor):
			distance = delta.length()
			best = {"kind": "npc", "actor": actor, "label": actor.actor_name}
	for target in interactables:
		if target.id in collected or not is_instance_valid(target.node) or not target.node.visible:
			continue
		var delta = interaction_point(target) - player.camera.global_position
		if delta.length() < distance and forward.dot(delta.normalized()) > .30 and line_of_sight(player.camera.global_position, interaction_point(target)):
			distance = delta.length()
			best = target.duplicate()
			best.label = {"herb": "Gather moonlotus", "qi": "Absorb jade essence", "seal": "Restore the meridian seal", "campaign_herb": "Gather moonlotus", "campaign_qi": "Absorb jade essence"}[target.kind]
	return best

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F2:
			show_turntable()
			return
		if event.physical_keycode == KEY_P:
			show_appearance()
			return
		if modal_kind == "appearance" and event.keycode in [KEY_1, KEY_2, KEY_3]:
			cycle_appearance(int(event.keycode - KEY_1))
			return
		if modal_kind == "city_dialogue" and event.keycode in [KEY_1, KEY_2]:
			city.dialogue_choice(1 if event.keycode == KEY_1 else 2)
			return
		if event.keycode == KEY_ENTER:
			if modal_kind in ["appearance", "turntable"]:
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
				show_modal("pause", "The mountain waits", ["Your journey is paused.", "F5 saves your journey. F9 restores it.", "M atlas · B codex · N city directory · R rest at camp", "WASD move · Shift sprint · Space jump", "E interact · H use a moonlotus to heal", "Left click attack · Q spirit palm · F7 music · V voices", "C cultivation · J journal · P appearance · F2 twelve views"], "ENTER / ESC   Resume")
			return
		if event.keycode == KEY_F5:
			if started and modal_kind != "ending":
				save_game()
			return
		if event.keycode == KEY_F9:
			if modal_kind != "ending":
				load_game()
			return
		if event.keycode == KEY_F7:
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
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_N:
			open_campaign("city")
			return
		if event.physical_keycode == KEY_M:
			open_campaign("map")
			return
		if event.physical_keycode == KEY_B:
			open_campaign("npcs")
			return
		if event.physical_keycode == KEY_R:
			rest_at_camp()
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
		heal()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		attack()

func begin() -> void:
	if started or modal:
		return
	started = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	notify("Find Mei by the valley lanterns. South: Cloudrest city · N directory.")
	speak("arrival")

func notify(message: String) -> void:
	notice = message
	notice_time = 5

func show_modal(kind: String, title: String, lines: Array, footer: String = "ENTER / ESC   Continue") -> void:
	if modal_kind == "ending" and kind != "ending":
		return
	if campaign_panel != null:
		campaign_panel.hide()
	if turntable != null:
		turntable.hide()
	modal = true
	modal_kind = kind
	modal_title = title
	modal_lines.assign(lines)
	modal_footer = footer
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func close_modal() -> void:
	# The final choice must be made; Escape cannot discard it.
	if modal_kind == "ending":
		return
	modal = false
	modal_kind = ""
	if campaign_panel != null:
		campaign_panel.hide()
	if turntable != null:
		turntable.hide()
	if voice != null:
		voice.stop()
	if started:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func show_appearance() -> void:
	if modal_kind == "ending":
		return
	show_modal("appearance", "Lin Yue", [], "1  Hair   ·   2  Clothing   ·   3  Weapon   ·   ENTER / ESC  Done")

func show_turntable() -> void:
	if modal_kind == "ending":
		return
	var selected = "hero_%03d" % state.appearance_row()
	if playing():
		var distance = 3.7
		var forward = -player.camera.global_transform.basis.z
		for actor in actors:
			if not is_instance_valid(actor) or not actor.visible or not actor.alive or not directional.has_character(actor.visual_key):
				continue
			var delta = actor.global_position + Vector3.UP - player.camera.global_position
			if delta.length() < distance and forward.dot(delta.normalized()) > .45 and line_of_sight(player.camera.global_position, actor.global_position + Vector3.UP, actor):
				distance = delta.length()
				selected = actor.visual_key
	show_modal("turntable", "Character turntable", [])
	turntable.open(selected)

func cycle_appearance(option: int) -> void:
	match option:
		0: state.hair = (state.hair + 1) % 4
		1: state.clothing = (state.clothing + 1) % 4
		2: state.weapon = (state.weapon + 1) % 4
	sound("gather")

func interact(target: Dictionary) -> void:
	if not playing() or target.is_empty():
		return
	if target.get("kind") == "npc":
		var actor = target.get("actor")
		if is_instance_valid(actor) and actor in actors and actor.kind == "npc" and actor.visible and in_reach(actor.position + Vector3.UP, actor):
			talk(actor)
		return
	if not target.has("id") or target.id in collected:
		return
	# Only a registered target may grant rewards; supplied dictionaries are untrusted.
	var matches = interactables.filter(func(t): return t.id == target.id)
	if matches.size() != 1:
		return
	target = matches[0]
	if not is_instance_valid(target.node) or not target.node.visible or not in_reach(interaction_point(target)):
		return
	if target.kind == "seal":
		if state.quest < 2:
			notify("Read the river memory with Mei before restoring its seals.")
			return
		var guardian = "Meridian Warden %d" % target.value
		if guardian not in defeated_ids:
			notify("The warden binds this seal. Defeat it first.")
			return
		state.seals += 1
		state.qi += 30
		collected.append(target.id)
		target.node.visible = false
		sound("seal")
		notify("Meridian restored · %d / 3. The mountain breathes again." % state.seals)
		if state.seals == 3:
			state.quest = maxi(state.quest, 3)
			speak("seals")
		return
	if target.kind.begins_with("campaign_"):
		regional_collected.append(target.id)
		target.node.visible = false
	else:
		collected.append(target.id)
		target.node.visible = false
	if target.kind in ["herb", "campaign_herb"]:
		state.herbs += 1
		state.qi += 8
		campaign.record("gather", "moonlotus")
		notify("Moonlotus gathered · %d. H restores vitality." % state.herbs)
	else:
		state.qi += int(target.value)
		campaign.record("gather", "jade")
		notify("Jade essence absorbed · +%d qi." % target.value)
	sound("gather")

func talk(actor: Node3D) -> void:
	if not playing() or not is_instance_valid(actor) or actor not in actors or actor.kind != "npc" or not actor.visible or not in_reach(actor.position + Vector3.UP, actor):
		return
	if actor.resident_id != "":
		city.talk(actor)
		return
	if actor.data_id != "":
		campaign.record("talk", actor.data_id)
		speak(actor.data_id)
		open_campaign("quests", actor.data_id)
		return
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
	if not playing() or player.attack_clock > 0:
		return
	player.attack_clock = [.48, .62, .38, .55][state.weapon]
	swing_time = 1
	sound("sword")
	var forward = -player.camera.global_transform.basis.z
	var closest: Node3D = null
	var distance = [3.5, 3.1, 4.5, 5.5][state.weapon]
	for actor in actors:
		if not is_instance_valid(actor) or not actor.alive or not actor.visible or actor.kind == "npc":
			continue
		var delta = actor.position + Vector3.UP - player.camera.global_position
		if delta.length() < distance and forward.dot(delta.normalized()) > .45 and line_of_sight(player.camera.global_position, actor.position + Vector3.UP, actor):
			closest = actor
			distance = delta.length()
	if closest != null:
		if closest.kind == "boss" and (state.seals < 3 or state.realm < 2):
			notify("Xu's binding is unbroken. Restore 3 seals and reach Foundation.")
			return
		closest.hit(state.damage())

func spirit_palm() -> void:
	if not playing():
		return
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
		if not is_instance_valid(actor) or not actor.alive or not actor.visible or actor.kind == "npc":
			continue
		var delta = actor.position - player.position
		if delta.length() < 8 and forward.dot(delta.normalized()) > .55 and line_of_sight(player.camera.global_position, actor.position + Vector3.UP, actor):
			if actor.kind != "boss" or (state.seals == 3 and state.realm >= 2):
				actor.hit(state.damage() * (2.4 if state.weapon == 3 else 1.6))
	notify("Spirit palm · the jade meridian answers.")

func take_damage(amount: float) -> void:
	if not playing() or not is_finite(amount) or amount <= 0:
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
	player.reset_motion()
	player.yaw = 0
	player.pitch = 0
	player.rotation.y = 0
	player.camera.rotation.x = 0
	spirit_cooldown = 0
	damage_flash = 0
	swing_time = 0
	for actor in actors:
		if is_instance_valid(actor) and actor.kind != "npc" and actor.alive:
			actor.position = actor.spawn_position
			actor.velocity = Vector3.ZERO
			actor.attack_time = 2
			actor.warning_time = 0
			actor.charge_clock = 0
			actor.charge_direction = Vector3.ZERO
			actor.charge_hit = false
	notify("Mei found you in the reeds. Lost 15 unspent qi; your realm remains.")

func enemy_defeated(actor: Node3D) -> void:
	if not is_instance_valid(actor) or actor not in actors or actor.alive or actor.reward_given:
		return
	actor.reward_given = true
	if actor.data_id == "" and actor.actor_name in defeated_ids:
		return
	state.defeated += 1
	state.qi += 35 if actor.kind == "guardian" else 20
	if actor.data_id == "":
		defeated_ids.append(actor.actor_name)
	else:
		regional_defeated.append(actor.data_id)
		campaign.record("kill", actor.data_id)
	sound("gather")
	if actor.kind == "boss":
		speak("xu")
		show_modal("ending", "The last immortal", ["Xu falls. A child's voice rises from the roots.", '"Father, I was never afraid of leaving. Only of leaving you."', "The sword can sever the binding. Or you can take its power.", "", "1   Release her soul. Let the mountain live.", "2   Inherit the meridian. Become its immortal keeper."], "Choose 1 or 2   ·   This choice completes your journey")
	else:
		notify("%s released · qi gained." % actor.actor_name)

func choose_ending(mercy: bool) -> void:
	if modal_kind != "ending" or state.ending != "" or SaveCodec.BOSS not in defeated_ids:
		return
	state.ending = "Mercy" if mercy else "Ascension"
	if not mercy:
		state.realm = 3
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
	if not started or modal_kind == "ending":
		return
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
	if not started or modal_kind != "cultivate":
		return
	if state.cultivate():
		sound("seal")
		notify("Breakthrough · " + state.REALMS[state.realm])
		close_modal()
	else:
		modal_footer = "Not enough qi, or Golden Core reached. ESC returns."

func show_journal() -> void:
	open_campaign("quests")

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
	if not sound_cache.has(path):
		sound_cache[path] = load(path)
	var audio: AudioStreamPlayer = null
	for channel in effects:
		if not channel.playing:
			audio = channel
			break
	if audio == null:
		# Bound effects voices; replace the oldest channel rather than allocating nodes.
		audio = effects[0]
		effects.push_back(effects.pop_front())
	audio.stream = sound_cache[path]
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
	if not started or modal_kind == "ending":
		return false
	if path == "":
		path = save_path
	var data = state.to_dict()
	data["version"] = SaveCodec.CURRENT_VERSION
	data["regional"] = {"collected": regional_collected.duplicate(), "defeated": regional_defeated.duplicate()}
	data["position"] = [player.position.x, player.position.y, player.position.z]
	data["orientation"] = [player.yaw, player.pitch]
	data["collected"] = collected.duplicate()
	data["defeated_ids"] = defeated_ids.duplicate()
	data["campaign"] = campaign.to_dict()
	if not SaveCodec.valid(data, campaign) or not SaveCodec.atomic_write(path, data):
		notify("Could not write a valid save. Your previous journey is retained.")
		return false
	notify("Journey saved · F9 restores it.")
	return true

func load_game(path: String = "") -> bool:
	if modal_kind == "ending":
		return false
	if path == "":
		path = save_path
	if not FileAccess.file_exists(path):
		notify("No saved journey yet. F5 creates one.")
		return false
	var parser = JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK or not SaveCodec.valid(parser.data, campaign):
		notify("Save is invalid. Current progression has been preserved.")
		return false
	var data = parser.data
	state.restore(data)
	collected = data.collected.duplicate()
	defeated_ids = data.defeated_ids.duplicate()
	if int(data.version) >= 2:
		campaign.restore(data.campaign)
	else:
		campaign = Campaign.new()
	regional_collected = data.regional.collected.duplicate() if int(data.version) >= 3 else []
	regional_defeated = data.regional.defeated.duplicate() if int(data.version) >= 3 else []
	# Old Ascension saves predate the ending granting its narrated Golden Core.
	if state.ending == "Ascension":
		state.realm = 3
	# Replace actors synchronously so old bodies cannot overlap restored bodies.
	clear_region()
	for actor in actors.duplicate():
		if is_instance_valid(actor) and actor.kind != "npc":
			actors.erase(actor)
			actor.free()
	spawn_core_enemies()
	spawn_region()
	player.position = Vector3(float(data.position[0]), float(data.position[1]), float(data.position[2]))
	player.reset_motion()
	var orientation = data.get("orientation", [0,0])
	player.yaw = float(orientation[0])
	player.pitch = float(orientation[1])
	player.rotation.y = player.yaw
	player.camera.rotation.x = player.pitch
	spirit_cooldown = 0
	damage_flash = 0
	swing_time = 0
	started = true
	modal_kind = ""
	close_modal()
	if SaveCodec.BOSS in defeated_ids and state.ending == "":
		show_modal("ending", "The last immortal", ["The binding is broken. Choose how the mountain remembers.", "1   Release her soul", "2   Inherit the meridian"], "Choose 1 or 2")
	notify("Journey restored.")
	return true

func spawn_core_enemies() -> void:
	for i in range(3):
		var id = "Meridian Warden %d" % i
		if id not in defeated_ids:
			spawn_actor(id, "guardian", 2, 2+i, SHRINES[i]+Vector3(0,0,4),80+i*20)
	for i in range(8):
		var id = "Ash Spirit %d" % i
		if id not in defeated_ids:
			spawn_actor(id,"enemy",2 if i%2==0 else 1,i%14,Vector3((-1 if i%2==0 else 1)*(7+i%3),0,-17-i*6),45+i*4)
	if SaveCodec.BOSS not in defeated_ids:
		spawn_actor(SaveCodec.BOSS,"boss",4,15,Vector3(0,0,-73),300)

func run_smoke() -> void:
	# Full quest checks live in tests; this exercises the running world and assets.
	await get_tree().physics_frame
	await get_tree().physics_frame
	var ok = atlases.size() == 5 and actors.size() >= 71 and model_cache.size() > 35 and player.camera.current and campaign.npcs.size()==100 and campaign.monsters.size()==100 and not campaign.story("quest_000_00").is_empty() and city.buildings.size()==12 and city.resident_actors.size()==40 and city.interiors.scenes.size() == 40 and city.interiors.instances.size() >= 576
	if not ok:
		push_error("World smoke check failed")
		get_tree().quit(1)
		return
	print("WORLD_SMOKE_PASS actors=%d models=%d atlases=%d city_buildings=%d city_residents=%d" % [actors.size(), model_cache.size(), atlases.size(), city.buildings.size(), city.resident_actors.size()])
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
	player.position = Vector3(0,.1,17)
	player.rotation.y = -.65
	player.yaw = -.65
	for _frame in range(10):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/screenshots/camp.png")
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
	close_modal()
	travel("region_01")
	player.position = Vector3(0,.1,12)
	for _frame in range(10):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/screenshots/academy.png")
	open_campaign("map")
	for _frame in range(3):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/screenshots/atlas.png")
	open_campaign("monsters")
	for _frame in range(3):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/screenshots/bestiary.png")
	close_modal()
	travel("region_00")
	var author = actors.filter(func(a): return a.data_id == "npc_000")[0]
	player.position = author.position + Vector3(0,.1,2.2)
	player.rotation.y = 0
	player.yaw = 0
	for _frame in range(5):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/screenshots/witness.png")
	talk(author)
	accept_quest("quest_000_00")
	campaign_panel.refresh()
	for _frame in range(3):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/screenshots/quest-reader.png")
	await capture_city_screenshots(false)
	await capture_directional_screenshots(false)
	print("SCREENSHOTS_CAPTURED")
	stop_audio()
	await get_tree().create_timer(.15).timeout
	get_tree().quit(0)

func capture_city_screenshots(finish: bool = true) -> void:
	# Use the same city geometry, actors, camera, and UI as interactive play.
	begin()
	close_modal()
	travel("region_00")
	for actor in actors:
		actor.set_physics_process(false)
	var views = [
		["city", Vector3(0, .1, 27), PI, .1],
		["city-interior", city.building_origin("lotus_inn") + Vector3(.8, .1, 3.8), .65, -.08],
		["city-bedroom", city.building_origin("lotus_inn") + Vector3(.8, 4.1, 3.8), .7, -.08],
		["city-clinic", city.building_origin("river_clinic") + Vector3(.8, .1, 3.8), .65, -.08],
		["city-forge", city.building_origin("ember_forge") + Vector3(.8, .1, 3.8), .7, -.08],
		["city-tailor", city.building_origin("silk_house") + Vector3(.8, .1, 3.8), .7, -.08],
		["city-archive", city.building_origin("ink_archive") + Vector3(.8, 4.1, 3.8), .7, -.08],
		["city-guild", city.building_origin("wayfarer_guild") + Vector3(.8, .1, 3.8), .7, -.08],
		["city-bathhouse", city.building_origin("moon_baths") + Vector3(.8, .1, 3.8), .7, -.08],
		["city-bell-house", city.building_origin("bell_house") + Vector3(.8, .1, 3.8), .7, -.08],
		["city-courthouse", city.building_origin("oath_court") + Vector3(.8, 8.1, 3.8), .7, -.08],
		["city-upper-floor", city.building_origin("star_observatory") + Vector3(1.1, 8.1, 3.2), .7, -.08],
	]
	for view in views:
		player.position = view[1]
		player.reset_motion()
		player.yaw = view[2]
		player.rotation.y = view[2]
		player.pitch = view[3]
		player.camera.rotation.x = view[3]
		for _frame in range(8): await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://docs/screenshots/%s.png" % view[0])
	var scholar = city.resident_actors["city_26"]
	player.position = scholar.position + Vector3(.6, .1, 2.2)
	player.reset_motion()
	talk(scholar)
	if modal_kind != "city_dialogue":
		push_error("City capture could not open the resident dialogue")
		get_tree().quit(1)
		return
	city.dialogue_choice(1)
	for _frame in range(3): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/screenshots/city-dialogue.png")
	close_modal()
	open_campaign("city")
	for _frame in range(3): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/screenshots/city-directory.png")
	if finish:
		print("CITY_SCREENSHOTS_CAPTURED")
		stop_audio()
		get_tree().quit(0)

func capture_directional_screenshots(finish: bool = true) -> void:
	show_turntable()
	for entry in [["hero_000", "character-twelve-views"], ["npc_000", "npc-twelve-views"], ["monster_000", "monster-twelve-views"]]:
		if not directional.has_character(entry[0]):
			continue
		turntable.open(entry[0])
		for _frame in range(8): await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://docs/screenshots/%s.png" % entry[1])
	if finish:
		print("DIRECTIONAL_SCREENSHOTS_CAPTURED")
		stop_audio()
		get_tree().quit(0)

func add_prop_collision(node: Node3D, family: String = "") -> void:
	if family in ["bamboo", "pine"]:
		var body = StaticBody3D.new()
		var collision = CollisionShape3D.new()
		var shape = CylinderShape3D.new()
		shape.radius = .13 if family == "bamboo" else .22
		shape.height = 3.6
		collision.shape = shape
		collision.position.y = 1.8
		body.add_child(collision)
		node.add_child(body)
		return
	for mesh in node.find_children("*", "MeshInstance3D", true, false):
		var body = StaticBody3D.new()
		var collision = CollisionShape3D.new()
		var shape = BoxShape3D.new()
		var bounds = mesh.get_aabb()
		shape.size = bounds.size.max(Vector3.ONE * .03)
		collision.shape = shape
		collision.position = bounds.get_center()
		body.add_child(collision)
		mesh.add_child(body)

func clear_region() -> void:
	for actor in actors.duplicate():
		if is_instance_valid(actor) and actor.data_id != "":
			actors.erase(actor)
			actor.free()
	for node in regional_nodes:
		if is_instance_valid(node):
			node.free()
	regional_nodes.clear()
	for target in regional_items:
		interactables.erase(target)
	regional_items.clear()

func spawn_region() -> void:
	var index = int(campaign.current_region.trim_prefix("region_"))
	var region = campaign.regions[index]
	var palette = Color(region.palette)
	world_environment.fog_light_color = palette.lightened(.1)
	world_environment.fog_density = .018
	city.set_active(index == 0)
	ground.material_override.albedo_color = palette.darkened(.25)
	for actor in actors:
		if is_instance_valid(actor) and actor.data_id == "":
			actor.visible = index == 0
			actor.collision_layer = 2 if index == 0 and actor.alive else 0
	for target in interactables:
		if not target.kind.begins_with("campaign_"):
			target.node.visible = index == 0 and target.id not in collected
	var slot = 0
	for id in campaign.npcs:
		var npc = campaign.npcs[id]
		if npc.region != region.id:
			continue
		var point = Vector3((-1 if slot % 2 == 0 else 1) * 2.8, 0, 8-slot*7)
		spawn_actor(npc.name, "npc", 0, 0, point, 100, id)
		slot += 1
	slot = 0
	for id in campaign.monsters:
		var monster = campaign.monsters[id]
		if monster.region != region.id or id in regional_defeated:
			continue
		spawn_actor(monster.name, "enemy", 0, 0, Vector3((-1 if slot % 2 == 0 else 1)*6.8,0,-15-slot*6), float(monster.health),id)
		slot += 1
	var families = ["lotus_terrace","jade_observatory","ferry_dock","frost_arch","ember_forge","ink_archive","meteor_dais","moonwell","thunder_obelisk","dream_orchard","bone_ossuary","dawn_sanctuary"]
	for variant in range(3):
		var path = "res://assets/landmarks/%s_%02d.glb" % [families[index], variant]
		if not landmark_cache.has(path):
			landmark_cache[path] = load(path)
		var landmark = landmark_cache[path].instantiate()
		landmark.position = Vector3(-7 if variant % 2 == 0 else 8,0,6-variant*24)
		add_child(landmark)
		add_prop_collision(landmark)
		regional_nodes.append(landmark)
	# Renewable camp resources make every gathering chapter recoverable.
	for i in range(8):
		var kind = "campaign_herb" if i < 5 else "campaign_qi"
		var node = prop("crystal",40+i,Vector3((-1 if i%2==0 else 1)*5,0,9-i*3.5),Vector3.ONE*.5)
		var target = {"id": "regional_%d" % i, "kind":kind, "node":node,"value":15}
		node.visible = target.id not in regional_collected
		regional_nodes.append(node)
		regional_items.append(target)
		interactables.append(target)

func travel(region_id: String) -> bool:
	if not started or modal_kind == "ending" or not campaign.regions.any(func(r): return r.id == region_id):
		return false
	clear_region()
	regional_collected.clear()
	regional_defeated.clear()
	campaign.current_region = region_id
	spawn_region()
	player.position = Vector3(0,.15,13)
	player.reset_motion()
	player.yaw = 0
	player.pitch = 0
	player.rotation.y = 0
	player.camera.rotation.x = 0
	campaign.record("explore", region_id)
	close_modal()
	notify("Arrived at " + campaign.regions[int(region_id.trim_prefix("region_"))].name + " · J quests · B codex · R rest at camp")
	return true

func rest_at_camp() -> bool:
	if not playing() or player.position.distance_to(Vector3(0,0,13)) > 7:
		notify("Rest beside the southern gate. M opens the travel atlas.")
		return false
	for actor in actors:
		if is_instance_valid(actor) and actor.visible and actor.alive and actor.kind != "npc" and actor.position.distance_to(player.position) < 12:
			notify("A spirit is nearby. Reach safety before resting.")
			return false
	clear_region()
	regional_collected.clear()
	regional_defeated.clear()
	spawn_region()
	state.health = state.max_health()
	state.stamina = 100
	campaign.record("meditate", "rest")
	sound("gather")
	notify("Camp restored vitality. Regional spirits and blossoms return.")
	return true

func heal() -> bool:
	if not playing() or state.health >= state.max_health():
		return false
	if state.herbs <= 0:
		notify("No moonlotus left. Gather blossoms; R renews them at camp.")
		return false
	state.herbs -= 1
	state.health = minf(state.max_health(),state.health+45)
	sound("gather")
	return true

func open_campaign(mode: String = "quests", owner: String = "") -> void:
	if not started or modal_kind == "ending":
		return
	show_modal("campaign", "The mountain's accounts", [])
	campaign_panel.open(mode, owner)

func owner_nearby(owner: String) -> bool:
	return actors.any(func(a): return is_instance_valid(a) and a.alive and a.visible and a.kind=="npc" and a.data_id==owner and in_reach(a.position+Vector3.UP,a))

func accept_quest(id: String) -> bool:
	if not started or modal_kind != "campaign" or not campaign.quests.has(id):
		return false
	var quest = campaign.quests[id]
	if not owner_nearby(quest.owner) or not campaign.accept(id):
		notify("Speak with the chapter's author to accept it. Six accounts may be active.")
		return false
	if quest.objective.kind == "talk" and owner_nearby(quest.objective.target):
		campaign.record("talk", quest.objective.target)
	notify("Accepted: " + quest.title)
	return true

func claim_quest(id: String, choice: String = "mercy") -> bool:
	if not started or modal_kind != "campaign" or not campaign.quests.has(id) or not owner_nearby(campaign.quests[id].owner):
		notify("Return to the chapter's author to claim its reward.")
		return false
	var reward = campaign.claim(id, campaign.quests[id].owner, choice)
	if reward.is_empty():
		return false
	state.qi += int(reward.qi)
	sound("gather")
	notify("Account closed · +%d qi · reputation %d" % [reward.qi,reward.reputation])
	return true

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and started and not modal and not capture_mode:
		show_modal("pause", "The mountain waits", ["Your journey paused when the window lost focus."], "ENTER / ESC   Resume")
