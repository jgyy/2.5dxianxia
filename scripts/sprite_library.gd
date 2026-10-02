extends RefCounted

## Native artwork replaces individual frames without changing gameplay IDs.
const ROOT = "res://assets/sprites/"
const NATIVE_ROOT = ROOT + "native/"
var replacements: Dictionary = {}

func _init() -> void:
	if FileAccess.file_exists(NATIVE_ROOT + "manifest.json"):
		var manifest = JSON.parse_string(FileAccess.get_file_as_string(NATIVE_ROOT + "manifest.json"))
		for frame in manifest.frames:
			replacements[ROOT + frame.resource] = NATIVE_ROOT + frame.path

func texture(path: String, fallback: Texture2D = null) -> Texture2D:
	if replacements.has(path):
		return load(replacements[path])
	return fallback if fallback != null else load(path)
