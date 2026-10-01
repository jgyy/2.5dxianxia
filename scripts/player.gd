extends CharacterBody3D

var camera: Camera3D
var game: Node
var yaw: float = 0.0
var pitch: float = 0.0
var step_time: float = 0.0
var sensitivity: float = 0.0023
var attack_clock: float = 0.0

func _ready() -> void:
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
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not game.modal:
		yaw -= event.relative.x * sensitivity
		pitch = clampf(pitch - event.relative.y * sensitivity, -1.15, 1.15)
		rotation.y = yaw
		camera.rotation.x = pitch

func _physics_process(delta: float) -> void:
	attack_clock = maxf(0.0, attack_clock - delta)
	if not game.started or game.modal:
		velocity.x = move_toward(velocity.x, 0, 20 * delta)
		velocity.z = move_toward(velocity.z, 0, 20 * delta)
	else:
		var axis = Input.get_vector("left", "right", "forward", "back")
		var running = Input.is_action_pressed("sprint") and game.state.stamina > 1 and axis.length() > 0.1
		var direction = transform.basis * Vector3(axis.x, 0, axis.y)
		var speed = 8.0 if running else 4.7
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		game.state.stamina = clampf(game.state.stamina + (-22.0 if running else 16.0) * delta, 0, 100)
		if axis.length() > 0.1:
			step_time += delta * (12.0 if running else 8.0)
			camera.position.y = 1.62 + sin(step_time) * 0.045
			if fmod(step_time, PI) < delta * 8:
				game.sound("step")
		else:
			camera.position.y = lerpf(camera.position.y, 1.62, delta * 8)
		if Input.is_action_just_pressed("jump") and is_on_floor():
			velocity.y = 5.0
	if not is_on_floor():
		velocity.y -= 16.0 * delta
	move_and_slide()
	if position.y < -8:
		game.respawn()
