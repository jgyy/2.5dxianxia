extends Node3D

var game: Node
var actor_name: String = ""
var kind: String = "npc"
var sheet: int = 0
var row: int = 0
var health: float = 55.0
var alive: bool = true
var sprite: Sprite3D
var phase: float = 0.0
var hurt_time: float = 0.0
var attack_time: float = 0.0
var death_time: float = 0.0
var spawn_position: Vector3
var animation_state: String = "idle"
var frames: Array[Texture2D] = []

func _ready() -> void:
	spawn_position = position
	sprite = Sprite3D.new()
	for frame in range(16):
		frames.append(load("res://assets/sprites/frames/%s_%02d_%02d.tres" % [game.SPRITE_GROUPS[sheet], row, frame]))
	sprite.texture = frames[0]
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.pixel_size = 2.5 / sprite.texture.get_height()
	sprite.position.y = 1.25
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.shaded = false
	add_child(sprite)
	phase = float(get_instance_id() % 100) * 0.3

func _process(delta: float) -> void:
	phase += delta
	hurt_time = maxf(0, hurt_time - delta)
	attack_time = maxf(0, attack_time - delta)
	if not alive:
		death_time += delta
		sprite.texture = frames[12 + mini(3, int(death_time * 4))]
		sprite.modulate.a = maxf(0, 1.0 - death_time / 1.4)
		if death_time >= 1.4:
			queue_free()
		return
	animation_state = "idle"
	if kind != "npc" and game.started and not game.modal:
		var distance = position.distance_to(game.player.position)
		if distance < 14 and distance > 1.7:
			var direction = (game.player.position - position).normalized()
			direction.y = 0
			var target = position + direction * delta * (1.4 if kind == "boss" else 2.0)
			if game.walkable(target):
				position = target
			animation_state = "walk"
		elif distance <= 1.7:
			animation_state = "attack"
			if attack_time <= 0:
				attack_time = 1.4
				game.take_damage(18 if kind == "boss" else 9)
	var base = {"idle": 0, "walk": 4, "attack": 8}[animation_state]
	sprite.texture = frames[base + int(phase * 6) % 4]
	sprite.modulate = Color(1.7, 0.45, 0.35, 1) if hurt_time > 0 else Color.WHITE

func hit(amount: float) -> void:
	if not alive or kind == "npc":
		return
	health -= amount
	hurt_time = 0.16
	game.sound("hit")
	if health <= 0:
		alive = false
		game.enemy_defeated(self)
