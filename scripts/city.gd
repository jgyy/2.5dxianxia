extends Node3D

## A continuous, physically traversable district south of the original valley.
const DATA_PATH = "res://content/city/cloudrest.json"
const FLOOR_HEIGHT = 4.0
const CITY_END = 138.0
const STAIR_X = 5.5
const STAIR_LENGTH = 10.0
const InteriorDecor = preload("res://scripts/interiors.gd")
var interiors = InteriorDecor.new()
var game: Node
var buildings: Dictionary = {}
var residents: Dictionary = {}
var resident_actors: Dictionary = {}
var material_cache: Dictionary = {}
var mesh_cache: Dictionary = {}
var selected_resident = ""
var destination = ""
var marker: Label3D
var gate_collision: CollisionShape3D

func _ready() -> void:
	name = "CloudrestCity"
	var data = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	for definition in data.buildings:
		buildings[definition.id] = definition
	for resident in data.residents:
		residents[resident.id] = resident
	build_district()
	marker = label("", Vector3.ZERO, 40, Color("ffda89"))
	marker.no_depth_test = true
	marker.hide()

func finish_setup() -> void:
	# Append after the original cast so their stable spawn order remains intact.
	for id in residents:
		var resident = residents[id]
		var point: Vector3
		if resident.building == "":
			point = Vector3(float(resident.position[0]), .05, float(resident.position[1]))
		else:
			point = building_origin(resident.building) + Vector3(-.6, int(resident.floor) * FLOOR_HEIGHT + .05, -.7)
		var actor = game.spawn_actor(resident.name + " · " + resident.role, "npc", 0, 0, point, 100, "", resident.sprite)
		actor.resident_id = id
		var caption = Label3D.new()
		caption.text = resident.name
		caption.position.y = 2.65
		caption.font_size = 24
		caption.pixel_size = .008
		caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		caption.modulate = Color("ebe2cd")
		caption.visibility_range_end = 14
		actor.add_child(caption)
		resident_actors[id] = actor

func building_origin(id: String) -> Vector3:
	var point = buildings[id].position
	return Vector3(float(point[0]), 0, float(point[1]))

func entrance(id: String) -> Vector3:
	return building_origin(id) + Vector3(0, .05, 8.4)

func set_active(active: bool) -> void:
	visible = active
	process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	if gate_collision != null:
		gate_collision.set_deferred("disabled", active)
	if not active:
		destination = ""
		marker.hide()

func _process(_delta: float) -> void:
	if game.player == null or game.campaign.current_region != "region_00":
		return
	# Let the whole street remain legible while preserving the valley atmosphere.
	game.world_environment.fog_density = .006 if game.player.position.z > 18 else .018
	if destination != "":
		marker.text = buildings[destination].name + "\n%d m · entrance" % game.player.position.distance_to(entrance(destination))

func mark_building(id: String) -> bool:
	if not buildings.has(id) or game.campaign.current_region != "region_00":
		game.notify("Travel to Cloudrest before marking a city entrance.")
		return false
	# Selecting the same address clears the marker.
	destination = "" if destination == id else id
	marker.visible = destination != ""
	if destination != "":
		marker.position = entrance(id) + Vector3.UP * 3
	game.close_modal()
	return true

func location_caption(point: Vector3) -> String:
	if game.campaign.current_region != "region_00" or point.z <= 18:
		return ""
	for id in buildings:
		var local = point - building_origin(id)
		if absf(local.x) < 8 and absf(local.z) < 7:
			var floor_index = clampi(int(floor((local.y + .2) / FLOOR_HEIGHT)), 0, 2)
			return buildings[id].name + " · Floor %d / 3" % (floor_index + 1)
	return "Cloudrest city · Lantern Avenue · N directory"

func directory_text(id: String) -> String:
	var building = buildings[id]
	var text = str(building.description) + "\n\n"
	for floor_index in range(3):
		text += "FLOOR %d · %s\n" % [floor_index + 1, building.floors[floor_index]]
		for resident in residents.values():
			if resident.building == id and int(resident.floor) == floor_index:
				text += resident.name + " · " + resident.role + "\n"
		text += "\n"
	text += "Walk south through the camp gate and follow Lantern Avenue. Entrances face the cross lanes on the south side of each building. Inside, the staircase on the right reaches all three floors.\n\nPress E near any resident. Choose 1 for their story or 2 for their service. Mark the entrance below to follow its gold sign; mark it again to clear it."
	return text

func talk(actor: Node3D) -> void:
	if not residents.has(actor.resident_id):
		return
	selected_resident = actor.resident_id
	var resident = residents[selected_resident]
	game.show_modal("city_dialogue", resident.name + " · " + resident.role, resident.greeting, "1   Their story   ·   2   " + resident.action + "   ·   ENTER / ESC   Close")

func dialogue_choice(choice: int) -> void:
	if game.modal_kind != "city_dialogue" or not resident_actors.has(selected_resident):
		return
	var actor = resident_actors[selected_resident]
	# Choices retain the same proximity and wall checks as the original interaction.
	if not actor.visible or not game.in_reach(actor.position + Vector3.UP, actor):
		return
	var resident = residents[selected_resident]
	if choice == 1:
		game.show_modal("city_dialogue", resident.name + " · " + resident.role, resident.story, "1   Their story   ·   2   " + resident.action + "   ·   ENTER / ESC   Close")
		return
	match resident.service:
		"rest":
			game.state.health = game.state.max_health()
			game.state.stamina = 100
			game.show_modal("city_dialogue", "A quiet room in Cloudrest", [resident.name + " offers a place to recover.", "Your vitality and stamina are restored.", "Camp-rest quest objectives still require the valley camp."], "ENTER / ESC   Return   ·   1   Their story")
		"heal":
			game.state.health = game.state.max_health()
			game.show_modal("city_dialogue", "Lotus medicine", [resident.name + " dresses your wounds with clean river water.", "Your vitality is restored. No moonlotus was consumed."], "ENTER / ESC   Return   ·   1   Their story")
		"tea":
			game.state.stamina = 100
			game.show_modal("city_dialogue", "A cup of mountain tea", ["Steam carries the scent of rain and toasted rice.", "Your stamina is restored."], "ENTER / ESC   Return   ·   1   Their story")
		"appearance": game.show_appearance()
		"journal": game.open_campaign("quests")
		"atlas": game.open_campaign("map")
		"cultivate": game.show_cultivation()
		"directory": game.open_campaign("city")
		_:
			game.show_modal("city_dialogue", resident.action, resident.advice, "1   Their story   ·   2   " + resident.action + "   ·   ENTER / ESC   Close")

func mat(color: Color, texture: String = "", glow: float = 0) -> StandardMaterial3D:
	var key = str(color) + texture + str(glow)
	if material_cache.has(key):
		return material_cache[key]
	var result = game.material(color, glow)
	if texture != "":
		result.albedo_texture = load(texture)
		result.uv1_scale = Vector3(3, 3, 1)
		if texture.begins_with("res://assets/interiors/textures/"):
			result.normal_enabled = true
			result.normal_texture = load(texture.replace("_albedo.png", "_normal.png"))
			result.roughness_texture = load(texture.replace("_albedo.png", "_roughness.png"))
	material_cache[key] = result
	return result

func box(parent: Node3D, point: Vector3, dimensions: Vector3, material: Material, collision: bool = true, tilt: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var node = MeshInstance3D.new()
	var mesh_key = str(dimensions)
	if not mesh_cache.has(mesh_key):
		var mesh = BoxMesh.new()
		mesh.size = dimensions
		mesh_cache[mesh_key] = mesh
	node.mesh = mesh_cache[mesh_key]
	node.material_override = material
	node.position = point
	node.rotation = tilt
	parent.add_child(node)
	if collision:
		var body = StaticBody3D.new()
		var shape = CollisionShape3D.new()
		var bounds = BoxShape3D.new()
		bounds.size = dimensions
		shape.shape = bounds
		body.add_child(shape)
		node.add_child(body)
	return node

func label(caption: String, point: Vector3, font_size: int = 26, color: Color = Color("ebe2cd"), parent: Node3D = null) -> Label3D:
	var node = Label3D.new()
	node.text = caption
	node.font_size = font_size
	node.pixel_size = .012
	node.modulate = color
	node.outline_modulate = Color("172927")
	node.outline_size = 6
	node.position = point
	node.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	node.visibility_range_end = 55
	(parent if parent else self).add_child(node)
	return node

func cylinder(parent: Node3D, point: Vector3, radius: float, height: float, material: Material) -> void:
	var node = MeshInstance3D.new()
	var mesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	node.mesh = mesh
	node.material_override = material
	node.position = point
	parent.add_child(node)

func build_district() -> void:
	var stone = mat(Color("7f8678"), "res://assets/world/wall_03.png")
	var paving = mat(Color("b5a487"), "res://assets/world/rock_04.png")
	var timber = mat(Color("886343"), "res://assets/world/bench_04.png")
	var jade = mat(Color("81c3a1"), "", .4)
	box(self, Vector3(0, -.3, 78), Vector3(60, .6, 120), stone)
	box(self, Vector3(0, .012, 78), Vector3(8, .025, 120), paving, false)
	# Enclose the extension. Its north entrance aligns with the original camp.
	box(self, Vector3(-30.5, 2.5, 78), Vector3(1, 5, 120), stone)
	box(self, Vector3(30.5, 2.5, 78), Vector3(1, 5, 120), stone)
	box(self, Vector3(0, 2.5, 138.5), Vector3(62, 5, 1), stone)
	for x in [-4.0, 4.0]:
		box(self, Vector3(x, 2.6, 19.5), Vector3(.5, 5.2, .5), timber)
	box(self, Vector3(0, 4.8, 19.5), Vector3(9, .6, 1), timber)
	label("CLOUDREST CITY\nN · Directory / E · Speak", Vector3(0, 4.4, 21), 32, Color("ffda89"))
	for row_index in range(6):
		var z = 32.0 + row_index * 18.0
		box(self, Vector3(0, .016, z + 8.6), Vector3(53, .03, 2.6), paving, false)
		for side in [-1, 1]:
			var point = Vector3(side * 5.2, 0, z + 7.5)
			box(self, point + Vector3.UP * 1.7, Vector3(.18, 3.4, .18), timber)
			box(self, point + Vector3.UP * 3.2, Vector3(.6, .75, .6), mat(Color("f6bb6f"), "", .65), false)
			# A bounded number of real lights; other lanterns use emission.
			if row_index % 2 == 0:
				var light = OmniLight3D.new()
				light.position = point + Vector3.UP * 3
				light.light_color = Color("ffd293")
				light.light_energy = 1.0
				light.omni_range = 12
				add_child(light)
	for id in buildings:
		build_building(id)
	# Market stalls and a jade fountain flank the avenue without blocking it.
	for side in [-1, 1]:
		box(self, Vector3(side * 5.5, .6, 24), Vector3(2, 1.2, 2), timber)
		box(self, Vector3(side * 5.5, 2.5, 24), Vector3(2.7, .12, 2.7), jade, false)
	cylinder(self, Vector3(0, .15, 135), 2.2, .3, stone)
	cylinder(self, Vector3(0, 1.4, 135), .5, 2.4, jade)
	label("Lantern Avenue\nValley & camp ↑", Vector3(0, 3.2, 134), 26)

func build_building(id: String) -> void:
	var definition = buildings[id]
	var root = Node3D.new()
	root.name = str(id).to_pascal_case()
	root.position = building_origin(id)
	add_child(root)
	var timber = mat(Color("715238"), "res://assets/world/bench_04.png")
	var plaster = mat(Color(definition.color).lightened(.65), "res://assets/interiors/textures/stone_albedo.png")
	var floor_mat = mat(Color("dfcdb1"), "res://assets/interiors/textures/walnut_albedo.png")
	var trim = mat(Color(definition.color).darkened(.25))
	var glass = mat(Color("97b7a1"), "", .1)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color.a = .22
	for floor_index in range(3):
		var y = floor_index * FLOOR_HEIGHT
		if floor_index == 0:
			box(root, Vector3(0, -.1, 0), Vector3(16, .2, 14), floor_mat)
		else:
			# The staircase well remains open; no hidden ceiling spans the ramp.
			box(root, Vector3(-1.9, y - .1, 0), Vector3(12.2, .2, 14), floor_mat)
			box(root, Vector3(7.4, y - .1, 0), Vector3(1.2, .2, 14), floor_mat)
			for z in [-6.0, 6.0]:
				box(root, Vector3(STAIR_X, y - .1, z), Vector3(2.6, .2, 2), floor_mat)
		box(root, Vector3(0, y + 2, -7), Vector3(16, 4, .24), plaster)
		# Timber-framed windows have solid glass, so walls stay physical.
		for x in [-8.0, 8.0]:
			box(root, Vector3(x, y + .55, 0), Vector3(.24, 1.1, 14), plaster)
			box(root, Vector3(x, y + 3.3, 0), Vector3(.24, 1.4, 14), plaster)
			box(root, Vector3(x, y + 1.85, 0), Vector3(.08, 1.5, 14), glass)
			for z in [-7.0, -3.5, 0.0, 3.5, 7.0]:
				box(root, Vector3(x, y + 2, z), Vector3(.36, 4, .26), timber)
		for x in [-4.85, 4.85]:
			box(root, Vector3(x, y + .55, 7), Vector3(6.3, 1.1, .24), plaster)
			box(root, Vector3(x, y + 3.3, 7), Vector3(6.3, 1.4, .24), plaster)
			box(root, Vector3(x, y + 1.85, 7), Vector3(6.3, 1.5, .08), glass)
			for offset in [-3.15, 0.0, 3.15]:
				box(root, Vector3(x + offset, y + 2, 7), Vector3(.22, 4, .32), timber)
		if floor_index == 0:
			box(root, Vector3(0, 3.4, 7), Vector3(3.4, 1.2, .32), timber)
		else:
			box(root, Vector3(0, y + 2, 7), Vector3(3.4, 4, .24), plaster)
		# Above lower rooms, the next floor is the ceiling, minus the stair well.
		if floor_index == 2:
			box(root, Vector3(0, y + 3.9, 0), Vector3(16.4, .16, 14.4), timber)
		if floor_index < 2:
			build_stairs(root, y, timber)
		furnish(root, y, definition.style, floor_index, trim, timber)
		var floor_sign = label("%d · %s" % [floor_index + 1, definition.floors[floor_index]], Vector3(0, y + 2.8, -6.7), 24, Color("ffda89"), root)
		floor_sign.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		var light = OmniLight3D.new()
		light.position = Vector3(-2, y + 3.2, -2)
		light.light_color = Color("ffe0af")
		light.light_energy = .55
		light.omni_range = 6.5
		root.add_child(light)
	for side in [-1, 1]:
		box(root, Vector3(side * 4.4, 12.8, 0), Vector3(9.4, .22, 16), trim, false, Vector3(0, 0, -side * .2))
		# Raised eaves and red-gold shop banners frame the lantern street.
		box(root, Vector3(side * 8.5, 12.25, 0), Vector3(1.6, .22, 16.1), trim, false, Vector3(0, 0, side * .18))
		for level in [4.0, 8.0]:
			box(root, Vector3(side * 8.15, level, 0), Vector3(.7, .16, 14.5), timber, false)
	var street_side = 1 if root.position.x < 0 else -1
	box(root, Vector3(street_side * 8.5, 2.7, 4.7), Vector3(.14, 1.8, .9), mat(Color("ad534a")), false)
	box(root, Vector3(street_side * 8.5, 3.65, 4.7), Vector3(.28, .13, 1.2), mat(Color("d5b67b")), false)
	box(root, Vector3(0, 3.1, 8.1), Vector3(5.5, .18, 2.8), trim, false)
	var entrance_sign = label(definition.name + "\n3 floors · E to speak inside", Vector3(0, 3.7, 8.4), 27, Color("ffda89"), root)
	entrance_sign.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	var stair_sign = label("STAIRS ↑\nFloors 2 & 3", Vector3(4, 2.6, 5.4), 22, Color("a9dec4"), root)
	stair_sign.billboard = BaseMaterial3D.BILLBOARD_DISABLED

func build_stairs(root: Node3D, y: float, timber: Material) -> void:
	var angle = atan(FLOOR_HEIGHT / STAIR_LENGTH)
	# A continuous sloped collider lets CharacterBody3D walk up without jumping.
	box(root, Vector3(STAIR_X, y + 1.94, 0), Vector3(2.5, .12, sqrt(116.0)), timber, true, Vector3(angle, 0, 0)).visible = false
	for step in range(25):
		box(root, Vector3(STAIR_X, y + (step + .5) * .16 - .04, 5 - (step + .5) * .4), Vector3(2.5, .08, .4), timber, false)
	for x in [4.23, 6.77]:
		box(root, Vector3(x, y + 2.9, 0), Vector3(.08, .08, sqrt(116.0)), timber, false, Vector3(angle, 0, 0))

func furnish(root: Node3D, y: float, style: String, floor_index: int, _tint: Material, _timber: Material) -> void:
	# The crafted GLB set leaves the central approach and right stair route clear.
	interiors.decorate(root, y, style, floor_index)
