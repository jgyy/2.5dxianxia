extends RefCounted

## Shared textured GLBs with explicit placement and simple collision bounds.
const ASSETS = "res://assets/interiors/"
const LAYOUTS = "res://content/city/interiors.json"
var models: Dictionary = {}
var rooms: Dictionary = {}
var scenes: Dictionary = {}
var instances: Array[Node3D] = []

func _init() -> void:
	var manifest = JSON.parse_string(FileAccess.get_file_as_string(ASSETS + "manifest.json"))
	for model in manifest.models:
		models[model.id] = model
	var layouts = JSON.parse_string(FileAccess.get_file_as_string(LAYOUTS))
	for room in layouts.rooms:
		rooms["%s_%d" % [room.style, room.floor]] = room.props

func decorate(parent: Node3D, y: float, style: String, floor_index: int) -> void:
	for placement in rooms["%s_%d" % [style, floor_index]]:
		var model = models[placement.id]
		if not scenes.has(model.id):
			scenes[model.id] = load(ASSETS + model.path)
		var node: Node3D = scenes[model.id].instantiate()
		node.name = str(model.id).to_pascal_case()
		node.position = Vector3(placement.position[0], y + placement.position[1], placement.position[2])
		node.rotation.y = deg_to_rad(float(placement.get("yaw", 0)))
		node.scale = Vector3.ONE * float(placement.get("scale", 1))
		node.set_meta("interior_prop", model.id)
		node.set_meta("interior_floor", floor_index)
		parent.add_child(node)
		for mesh in node.find_children("*", "MeshInstance3D", true, false):
			mesh.visibility_range_end = 42
		if placement.get("solid", true):
			var body = StaticBody3D.new()
			var shape = CollisionShape3D.new()
			var bounds = BoxShape3D.new()
			bounds.size = Vector3(model.size[0], model.size[1], model.size[2])
			shape.shape = bounds
			shape.position = Vector3(model.center[0], model.center[1], model.center[2])
			body.add_child(shape)
			node.add_child(body)
		instances.append(node)
