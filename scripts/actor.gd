extends CharacterBody3D

var game: Node
var actor_name: String = ""
var kind: String = "npc"
var data_id: String = ""
var sheet: int = 0
var row: int = 0
var health: float = 55.0
var alive: bool = true
var reward_given = false
var sprite: Sprite3D
var phase: float = 0.0
var hurt_time: float = 0.0
var attack_time: float = 0.0
var death_time: float = 0.0
var spawn_position: Vector3
var animation_state: String = "idle"
var frames: Array[Texture2D] = []
var warning_time = 0.0
var attack_damage = 9.0
var speed = 2.0
var pattern = "melee"
var charge_clock = 0.0
var charge_direction = Vector3.ZERO
var charge_hit = false
var animation_clock = 0.0
var previous_animation_state = ""
var animation_fps = 6.0
var max_health = 55.0

func _ready() -> void:
	spawn_position = position
	max_health = health
	collision_layer = 2
	collision_mask = 1
	var shape = CollisionShape3D.new()
	var capsule = CapsuleShape3D.new()
	capsule.radius = .38
	capsule.height = 1.9
	shape.shape = capsule
	shape.position.y = 1
	add_child(shape)
	sprite = Sprite3D.new()
	if data_id != "":
		if ResourceLoader.exists("res://assets/sprites/animation/frames/%s_00.tres" % data_id):
			for frame in range(16):
				frames.append(load("res://assets/sprites/animation/frames/%s_%02d.tres" % [data_id, frame]))
			animation_fps = 12.0
		else:
			for frame in range(4):
				frames.append(load("res://assets/sprites/hires/frames/%s_%d.tres" % [data_id, frame]))
		if kind != "npc":
			var stats = game.campaign.monsters[data_id]
			attack_damage = float(stats.damage)
			speed = float(stats.speed)
			pattern = stats.pattern
	else:
		for frame in range(16):
			frames.append(load("res://assets/sprites/frames/%s_%02d_%02d.tres" % [game.SPRITE_GROUPS[sheet], row, frame]))
		if kind == "boss":
			attack_damage = 18
			speed = 1.4
	sprite.texture = frames[0]
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.pixel_size = 2.5 / sprite.texture.get_height()
	sprite.position.y = 1.25
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	sprite.shaded = false
	add_child(sprite)
	phase = float(get_instance_id() % 100) * 0.3

func _physics_process(delta: float) -> void:
	if not visible or not game.playing():
		return
	phase += delta
	hurt_time = maxf(0, hurt_time - delta)
	attack_time = maxf(0, attack_time - delta)
	if not alive:
		death_time += delta
		sprite.texture = frames[3] if frames.size() == 4 else frames[12 + mini(3, int(death_time * 4))]
		sprite.modulate.a = maxf(0, 1.0 - death_time / 1.4)
		if death_time >= 1.4:
			game.actors.erase(self)
			queue_free()
		return
	animation_state = "idle"
	var falling_speed = velocity.y
	velocity = Vector3(0,falling_speed,0)
	if kind != "npc":
		var difference = game.player.position - position
		difference.y = 0
		var distance = difference.length()
		var reach = 7.0 if pattern == "ranged" else 1.8
		if charge_clock > 0:
			animation_state = "attack"
			velocity.x = charge_direction.x * speed * 3
			velocity.z = charge_direction.z * speed * 3
			charge_clock = maxf(0, charge_clock - delta)
			if distance <= 1.8 and not charge_hit and game.line_of_sight(position + Vector3.UP, game.player.camera.global_position, self):
				charge_hit = true
				game.take_damage(attack_damage)
			if charge_clock <= 0:
				attack_time = 1.8
				warning_time = 0
		elif pattern == "charge" and distance < 7 and distance > 2 and attack_time <= 0:
			animation_state = "attack"
			warning_time += delta
			if warning_time >= .7:
				charge_clock = .65
				charge_direction = difference.normalized()
				charge_hit = false
				warning_time = 0
		elif distance < 14 and distance > reach:
			warning_time = 0
			var horizontal = difference.normalized() * speed
			velocity.x = horizontal.x
			velocity.z = horizontal.z
			# Slide against world geometry instead of crossing rocks and columns.
			if get_slide_collision_count() > 0:
				var normal = get_slide_collision(0).get_normal()
				var tangent = Vector3(-normal.z, 0, normal.x)
				if tangent.dot(difference) < 0:
					tangent = -tangent
				velocity.x = tangent.x * speed
				velocity.z = tangent.z * speed
			animation_state = "walk"
		elif distance <= reach and game.line_of_sight(position + Vector3.UP, game.player.camera.global_position, self):
			animation_state = "attack"
			if attack_time <= 0:
				warning_time += delta
				# Visible windup permits a dodge; ranged attacks also require clear sight.
				if warning_time >= (.9 if pattern == "ranged" else .45):
					attack_time = 1.4
					warning_time = 0
					var previous_health = game.state.health
					game.take_damage(attack_damage)
					if pattern == "leech" and game.state.health < previous_health:
						health = minf(max_health,health+attack_damage*.5)
		else:
			warning_time = 0
		if not is_on_floor():
			velocity.y -= 16 * delta
		else:
			velocity.y = 0
		move_and_slide()
		if not game.walkable(position) or position.y < -5:
			position = spawn_position
			velocity = Vector3.ZERO
	if animation_state != previous_animation_state:
		animation_clock = 0
		previous_animation_state = animation_state
	else:
		animation_clock += delta
	if frames.size() == 4:
		# Two visible poses per living state, with a separately authored death pose.
		var pose = {"idle": 0, "walk": 1, "attack": 2}[animation_state]
		sprite.texture = frames[pose if int(animation_clock * 5) % 2 == 0 else 0]
		sprite.position.y = 1.25 + sin(phase * 3) * .035
	else:
		var base = {"idle": 0, "walk": 4, "attack": 8}[animation_state]
		var texture = frames[base + int(animation_clock * animation_fps) % 4]
		if sprite.texture != texture:
			sprite.texture = texture
	sprite.modulate = Color(1.7, 0.45, 0.35, 1) if hurt_time > 0 else Color.WHITE

func hit(amount: float) -> void:
	if not alive or kind == "npc" or not visible or not game.playing() or not is_finite(amount) or amount <= 0:
		return
	health -= amount
	hurt_time = .16
	game.sound("hit")
	if health <= 0:
		alive = false
		collision_layer = 0
		game.enemy_defeated(self)
