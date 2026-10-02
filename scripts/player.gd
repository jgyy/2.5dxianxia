extends CharacterBody3D

var camera: Camera3D
var game: Node
var yaw: float = 0.0
var pitch: float = 0.0
var step_time: float = 0.0
var step_distance: float = 0.0
var sensitivity: float = 0.0023
var attack_clock: float = 0.0
var sprint_exhausted = false

func _ready() -> void:
	collision_layer = 4
	collision_mask = 3
	var shape = CollisionShape3D.new()
	var capsule = CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.75
	shape.shape = capsule
	shape.position.y = 0.9
	add_child(shape)
	camera = Camera3D.new()
	camera.position.y = 1.62
	camera.fov = 78.0
	camera.near = 0.08
	camera.far = 220.0
	add_child(camera)
	camera.current = true

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and game.playing():
		yaw = wrapf(yaw - event.relative.x * sensitivity, -PI, PI)
		pitch = clampf(pitch - event.relative.y * sensitivity, -1.15, 1.15)
		rotation.y = yaw
		camera.rotation.x = pitch

func reset_motion() -> void:
	velocity = Vector3.ZERO
	attack_clock = 0
	step_distance = 0
	step_time = 0
	camera.position.y = 1.62
	sprint_exhausted = false

func _physics_process(delta: float) -> void:
	if not game.playing():
		return
	attack_clock = maxf(0.0, attack_clock - delta)
	var axis = Input.get_vector("left", "right", "forward", "back")
	if game.state.stamina <= 1:
		sprint_exhausted = true
	elif game.state.stamina >= 20 or not Input.is_action_pressed("sprint"):
		sprint_exhausted = false
	var running = Input.is_action_pressed("sprint") and not sprint_exhausted and axis.length() > .1 and is_on_floor()
	var direction = transform.basis * Vector3(axis.x, 0, axis.y)
	var speed = 8.0 if running else 4.7
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	game.state.stamina = clampf(game.state.stamina + (-22.0 if running else 16.0) * delta, 0, 100)
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = 5.0
	if not is_on_floor():
		velocity.y -= 16.0 * delta
	var previous = position
	move_and_slide()
	var moved = Vector2(position.x - previous.x, position.z - previous.z).length()
	if moved > .001 and is_on_floor():
		step_time += moved * 2.5
		step_distance += moved
		camera.position.y = 1.62 + sin(step_time) * .045
		if step_distance >= 1.8:
			step_distance = fmod(step_distance, 1.8)
			game.sound("step")
	else:
		camera.position.y = lerpf(camera.position.y, 1.62, minf(1, delta * 8))
	if position.y < -8:
		game.respawn()
