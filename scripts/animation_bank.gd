extends RefCounted

const FRAME_COUNT = 50
const FRAME_SIZE = 320
const CACHE_LIMIT = 8
const STATES = {
	"idle": Vector3i(0, 8, 12),
	"walk": Vector3i(8, 16, 24),
	"attack": Vector3i(24, 16, 24),
	"death": Vector3i(40, 10, 12),
}
static var _cache: Dictionary = {}
static var _order: Array[String] = []

static func available(id: String) -> bool:
	return ResourceLoader.exists("res://assets/sprites/motion/atlases/%s.webp" % id)

static func frames_for(id: String) -> Array[Texture2D]:
	if _cache.has(id):
		_order.erase(id)
		_order.append(id)
		return _cache[id]
	var atlas = ResourceLoader.load("res://assets/sprites/motion/atlases/%s.webp" % id, "Texture2D", ResourceLoader.CACHE_MODE_IGNORE) as Texture2D
	var frames: Array[Texture2D] = []
	if atlas == null:
		return frames
	for index in range(FRAME_COUNT):
		var frame = AtlasTexture.new()
		frame.atlas = atlas
		frame.region = Rect2(index % 10 * FRAME_SIZE, int(index / 10) * FRAME_SIZE, FRAME_SIZE, FRAME_SIZE)
		frame.filter_clip = true
		frames.append(frame)
	_cache[id] = frames
	_order.append(id)
	while _order.size() > CACHE_LIMIT:
		_cache.erase(_order.pop_front())
	return frames

static func frame_index(state: String, clock: float) -> int:
	var clip: Vector3i = STATES.get(state, STATES.idle)
	var index = maxi(0, int(clock * clip.z))
	return clip.x + (mini(clip.y - 1, index) if state == "death" else index % clip.y)

static func cached_count() -> int:
	return _cache.size()
