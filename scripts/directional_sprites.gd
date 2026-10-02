extends RefCounted

## Twelve camera-relative drawings; actor heading is independent of billboarding.
const VIEW_COUNT = 12
const STEP = TAU / VIEW_COUNT
const ROOT = "res://assets/sprites/directional/"
var characters: Dictionary = {}
var cache: Dictionary = {}
var library = preload("res://scripts/sprite_library.gd").new()

func _init() -> void:
	if not FileAccess.file_exists(ROOT + "manifest.json"):
		return
	var manifest = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "manifest.json"))
	for character in manifest.characters:
		characters[character.id] = character

static func view_index(angle: float) -> int:
	return posmod(int(floor((wrapf(angle, 0, TAU) + STEP / 2) / STEP)), VIEW_COUNT)

static func relative_view(observer: Vector3, origin: Vector3, facing: float) -> int:
	var offset = observer - origin
	if Vector2(offset.x, offset.z).length_squared() < .000001:
		return 0
	return view_index(atan2(-offset.x, -offset.z) - facing)

func has_character(id: String) -> bool:
	return characters.has(id)

func texture(id: String, view: int, state: String = "idle", pose: int = 0) -> Texture2D:
	if not characters.has(id):
		return null
	var character = characters[id]
	var bank = character.states.get(state, character.states.idle)
	var frames = bank[posmod(view, VIEW_COUNT)]
	var path: String = frames[posmod(pose, frames.size())]
	if not cache.has(path):
		cache[path] = library.texture(ROOT + path)
		if cache.size() > 96:
			cache.erase(cache.keys()[0])
	return cache[path]
