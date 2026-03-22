extends CharacterBody2D
class_name RaceCar

signal checkpoint_hit(car: RaceCar, checkpoint_idx: int)
signal track_completed(car: RaceCar, time: float)
signal crashed(car: RaceCar)

# Identity
@export var car_index: int = 0
@export var car_color: Color = Color(0.35, 0.55, 0.90)
@export var is_ai: bool = true

# Physics — tuned for faster, more responsive driving
var max_speed: float = 750.0
var max_speed_grass: float = 280.0
var acceleration_force: float = 650.0
var brake_decel: float = 600.0
var friction: float = 0.97
var turn_speed: float = 4.5
var normal_grip: float = 0.92
var grass_grip: float = 0.55
var grip_damping: float = 0.8

# State
var heading: float = 0.0
var forward_speed: float = 0.0
var lateral_speed: float = 0.0
var slip_angle: float = 0.0
var current_grip: float = 0.92
var on_grass: bool = false
var is_drifting: bool = false
var handbrake_input: float = 0.0
var drift_boost: float = 0.0
var was_drifting: bool = false

# Inputs
var steer_input: float = 0.0
var throttle_input: float = 0.0
var brake_input: float = 0.0

# AI
var brain: AIBrain = null
var sensor_distances: PackedFloat64Array = PackedFloat64Array()
var sensor_rays: Array[RayCast2D] = []
var sensor_count: int = 10
var sensor_length: float = 350.0

# Progress
var current_checkpoint: int = 0
var total_checkpoints: int = 5
var drive_time: float = 0.0
var total_distance: float = 0.0
var last_position: Vector2 = Vector2.ZERO
var stuck_timer: float = 0.0
var alive: bool = true
var track_finished: bool = false

# Checkpoint positions (set by game)
var checkpoint_positions: Array[Vector2] = []

# Visual
var body_sprite: Sprite2D
var drift_particles: GPUParticles2D
var trail_left: Line2D
var trail_right: Line2D

# Track
var track_data: Array = []
var tile_size: int = 32
var prev_checkpoint_dist: float = INF

# Stats for brain fitness
var grass_time: float = 0.0
var max_speed_reached: float = 0.0
var drift_time: float = 0.0

func _ready() -> void:
	_setup_visuals()
	_setup_sensors()
	_setup_collision()
	_setup_particles()
	last_position = position
	sensor_distances.resize(sensor_count)
	sensor_distances.fill(1.0)
	if not checkpoint_positions.is_empty():
		prev_checkpoint_dist = position.distance_to(checkpoint_positions[0])

func _setup_collision() -> void:
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(50, 18)
	collision.shape = shape
	add_child(collision)
	collision_layer = 1
	collision_mask = 2

func _setup_visuals() -> void:
	body_sprite = Sprite2D.new()
	var img := Image.create(60, 24, false, Image.FORMAT_RGBA8)
	for x in range(60):
		for y in range(24):
			var c := Color(0, 0, 0, 0)
			if x >= 12 and x < 48 and y >= 7 and y < 17:
				c = car_color
			if x >= 48 and x < 58 and y >= 9 and y < 15:
				c = car_color.darkened(0.1)
			if x >= 58 and x < 60 and y >= 10 and y < 14:
				c = car_color.darkened(0.2)
			if x >= 44 and x < 50 and y >= 3 and y < 6:
				c = car_color.darkened(0.3)
			if x >= 44 and x < 50 and y >= 18 and y < 21:
				c = car_color.darkened(0.3)
			if x >= 46 and x < 50 and y >= 2 and y < 4:
				c = car_color.darkened(0.4)
			if x >= 46 and x < 50 and y >= 20 and y < 22:
				c = car_color.darkened(0.4)
			if x >= 22 and x < 32 and y >= 9 and y < 13:
				c = Color(0.1, 0.1, 0.15, 1.0)
			if x >= 24 and x < 30 and y >= 6 and y < 9:
				c = car_color.darkened(0.2)
			if x >= 28 and x < 42 and y >= 5 and y < 7:
				c = car_color.darkened(0.1)
			if x >= 28 and x < 42 and y >= 17 and y < 19:
				c = car_color.darkened(0.1)
			if x >= 4 and x < 12 and y >= 4 and y < 8:
				c = car_color.darkened(0.3)
			if x >= 4 and x < 12 and y >= 16 and y < 20:
				c = car_color.darkened(0.3)
			if x >= 2 and x < 6 and y >= 3 and y < 5:
				c = car_color.darkened(0.4)
			if x >= 2 and x < 6 and y >= 19 and y < 21:
				c = car_color.darkened(0.4)
			if x >= 42 and x < 50:
				if (y >= 4 and y < 7) or (y >= 17 and y < 20):
					c = Color(0.1, 0.1, 0.1, 1.0)
			if x >= 8 and x < 16:
				if (y >= 4 and y < 7) or (y >= 17 and y < 20):
					c = Color(0.1, 0.1, 0.1, 1.0)
			if x >= 58 and x < 60:
				if y == 9 or y == 14:
					c = Color(1.0, 1.0, 0.9, 1.0)
			img.set_pixel(x, y, c)
	body_sprite.texture = ImageTexture.create_from_image(img)
	add_child(body_sprite)

func _setup_sensors() -> void:
	if not is_ai:
		return
	sensor_rays.clear()
	# 10 sensors for better spatial awareness
	var angles: Array[float] = [0.0, 0.3, -0.3, 0.65, -0.65, 1.0, -1.0, 1.5, -1.5, PI]
	for i in range(angles.size()):
		var ray := RayCast2D.new()
		ray.target_position = Vector2(cos(angles[i]), sin(angles[i])) * sensor_length
		ray.collision_mask = 2
		ray.enabled = true
		add_child(ray)
		sensor_rays.append(ray)

func _setup_particles() -> void:
	drift_particles = GPUParticles2D.new()
	drift_particles.emitting = false
	drift_particles.amount = 20
	drift_particles.lifetime = 0.6
	drift_particles.position = Vector2(-20, 0)
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 35.0
	mat.initial_velocity_min = 20.0
	mat.initial_velocity_max = 40.0
	mat.gravity = Vector3.ZERO
	mat.scale_min = 2.0
	mat.scale_max = 6.0
	mat.color = Color(0.6, 0.6, 0.6, 0.35)
	drift_particles.process_material = mat
	add_child(drift_particles)

	trail_left = Line2D.new()
	trail_left.width = 2.5
	trail_left.default_color = Color(0.2, 0.2, 0.2, 0.3)
	trail_left.z_index = -1
	trail_left.top_level = true

	trail_right = Line2D.new()
	trail_right.width = 2.5
	trail_right.default_color = Color(0.2, 0.2, 0.2, 0.3)
	trail_right.z_index = -1
	trail_right.top_level = true

	add_child(trail_left)
	add_child(trail_right)

func _physics_process(delta: float) -> void:
	if not alive or track_finished:
		return

	_update_sensors()

	if is_ai and brain:
		_ai_decide()
	elif not is_ai:
		_read_player_input()

	_apply_physics(delta)
	_check_surface()
	_check_stuck(delta)
	_check_checkpoints_proximity()

	var dist := position.distance_to(last_position)
	total_distance += dist
	last_position = position
	drive_time += delta

	# Track stats for brain fitness
	if on_grass:
		grass_time += delta
	if velocity.length() > max_speed_reached:
		max_speed_reached = velocity.length()
	if is_drifting and forward_speed > 50.0:
		drift_time += delta

	# Update brain stats continuously
	if brain:
		if current_checkpoint < checkpoint_positions.size() and prev_checkpoint_dist > 0.1:
			var d := position.distance_to(checkpoint_positions[current_checkpoint])
			brain.checkpoint_progress = clampf(1.0 - d / prev_checkpoint_dist, 0.0, 1.0)
		brain.time_alive = drive_time
		brain.grass_time = grass_time
		brain.max_speed_reached = max_speed_reached
		brain.drift_time = drift_time

	_update_effects()
	move_and_slide()

	if get_slide_collision_count() > 0:
		_on_wall_collision()

func _update_sensors() -> void:
	for i in range(sensor_rays.size()):
		var ray := sensor_rays[i]
		if ray.is_colliding():
			var d := global_position.distance_to(ray.get_collision_point())
			sensor_distances[i] = clampf(d / sensor_length, 0.0, 1.0)
		else:
			sensor_distances[i] = 1.0

func _ai_decide() -> void:
	if brain == null:
		return
	var state := PackedFloat64Array()
	state.resize(18)

	# 10 sensor distances
	for i in range(10):
		state[i] = sensor_distances[i] if i < sensor_distances.size() else 1.0

	# Normalized speed
	state[10] = clampf(velocity.length() / max_speed, 0.0, 1.0)

	# Checkpoint direction in local space
	if current_checkpoint < checkpoint_positions.size():
		var to_cp := checkpoint_positions[current_checkpoint] - position
		var local_x := to_cp.x * cos(-heading) - to_cp.y * sin(-heading)
		var local_y := to_cp.x * sin(-heading) + to_cp.y * cos(-heading)
		var cp_dist := to_cp.length()
		if cp_dist > 0.1:
			state[11] = clampf(local_x / cp_dist, -1.0, 1.0)
			state[12] = clampf(local_y / cp_dist, -1.0, 1.0)

	# Checkpoint distance
	if current_checkpoint < checkpoint_positions.size():
		state[13] = clampf(position.distance_to(checkpoint_positions[current_checkpoint]) / 800.0, 0.0, 1.0)
	else:
		state[13] = 1.0

	# Surface and motion state
	state[14] = 1.0 if on_grass else 0.0
	state[15] = clampf(forward_speed / max_speed, -1.0, 1.0)
	state[16] = clampf(slip_angle / (PI * 0.5), -1.0, 1.0)
	state[17] = 1.0 if is_drifting else 0.0

	var action := brain.network.forward(state)
	steer_input = clampf(action[0], -1.0, 1.0)
	throttle_input = clampf((action[1] + 1.0) * 0.5, 0.3, 1.0)
	brake_input = clampf((action[2] + 1.0) * 0.5, 0.0, 0.5)
	handbrake_input = clampf((action[3] + 1.0) * 0.5, 0.0, 1.0)

func _read_player_input() -> void:
	steer_input = Input.get_axis("move_left", "move_right")
	throttle_input = 1.0 if Input.is_action_pressed("move_up") else 0.0
	brake_input = 1.0 if Input.is_action_pressed("move_down") else 0.0
	handbrake_input = 1.0 if Input.is_action_pressed("ui_select") else 0.0

func _apply_physics(delta: float) -> void:
	var speed_factor := clampf(velocity.length() / 80.0, 0.0, 1.0)
	heading += steer_input * turn_speed * delta * speed_factor
	rotation = heading

	var forward_dir := Vector2(cos(heading), sin(heading))
	var right_dir := Vector2(-sin(heading), cos(heading))
	forward_speed = velocity.dot(forward_dir)
	lateral_speed = velocity.dot(right_dir)

	if abs(forward_speed) > 5.0:
		slip_angle = atan2(lateral_speed, abs(forward_speed))
	else:
		slip_angle = 0.0

	# Grip with handbrake drift
	var base_grip := grass_grip if on_grass else normal_grip
	if handbrake_input > 0.5 and forward_speed > 40.0:
		base_grip *= 0.35
	current_grip = lerpf(base_grip, 0.3, clampf(abs(slip_angle) / (PI * 0.5), 0.0, 1.0))

	was_drifting = is_drifting
	is_drifting = abs(slip_angle) > 0.22

	# Drift boost on exit
	if was_drifting and not is_drifting and drift_boost <= 0.0:
		drift_boost = 0.15

	if drift_boost > 0.0:
		drift_boost -= delta * 0.5
		velocity += forward_dir * 120.0 * delta

	var current_max_speed := max_speed_grass if on_grass else max_speed

	if throttle_input > 0.0 and forward_speed < current_max_speed:
		velocity += forward_dir * throttle_input * acceleration_force * delta

	if brake_input > 0.0:
		if forward_speed > 10.0:
			velocity -= forward_dir * brake_input * brake_decel * delta
		else:
			velocity -= forward_dir * brake_input * acceleration_force * 0.3 * delta

	var lateral_correction := right_dir * lateral_speed * current_grip * grip_damping
	velocity -= lateral_correction * delta * 8.0

	var friction_mult := 0.86 if on_grass else friction
	velocity *= pow(friction_mult, delta * 60.0)

	if velocity.length() > current_max_speed:
		velocity = velocity.normalized() * current_max_speed

func _check_surface() -> void:
	if track_data.is_empty():
		return
	var tile_x := int(position.x / tile_size)
	var tile_y := int(position.y / tile_size)
	if tile_y >= 0 and tile_y < track_data.size() and tile_x >= 0 and tile_x < track_data[tile_y].size():
		var tile_id: int = int(track_data[tile_y][tile_x])
		on_grass = (tile_id == 2 or tile_id == 0)
	else:
		on_grass = true

func _check_stuck(delta: float) -> void:
	if velocity.length() < 8.0:
		stuck_timer += delta
	else:
		stuck_timer = maxf(0.0, stuck_timer - delta * 2.0)

func _check_checkpoints_proximity() -> void:
	if current_checkpoint >= checkpoint_positions.size():
		return
	var cp_pos := checkpoint_positions[current_checkpoint]
	var d := position.distance_to(cp_pos)
	if d < 50.0:
		hit_checkpoint(current_checkpoint)

func _on_wall_collision() -> void:
	for i in range(get_slide_collision_count()):
		var collision := get_slide_collision(i)
		velocity = velocity.bounce(collision.get_normal()) * 0.3
	if brain:
		brain.collision_count += 1
	emit_signal("crashed", self)

func hit_checkpoint(idx: int) -> void:
	if idx == current_checkpoint and not track_finished:
		current_checkpoint += 1
		if brain:
			brain.checkpoints_hit += 1
		emit_signal("checkpoint_hit", self, idx)

		if current_checkpoint < checkpoint_positions.size():
			prev_checkpoint_dist = position.distance_to(checkpoint_positions[current_checkpoint])

		if current_checkpoint >= total_checkpoints:
			_on_track_complete()

func _on_track_complete() -> void:
	track_finished = true
	if brain:
		brain.finished = true
		brain.finish_time = drive_time
	emit_signal("track_completed", self, drive_time)

func _update_effects() -> void:
	if drift_particles:
		drift_particles.emitting = is_drifting and forward_speed > 50.0

	if is_drifting and trail_left and trail_right:
		var right := Vector2(-sin(heading), cos(heading))
		var back := -Vector2(cos(heading), sin(heading))
		trail_left.add_point(global_position + right * 8.0 + back * 12.0)
		trail_right.add_point(global_position - right * 8.0 + back * 12.0)
		while trail_left.get_point_count() > 80:
			trail_left.remove_point(0)
		while trail_right.get_point_count() > 80:
			trail_right.remove_point(0)

func reset_car(pos: Vector2, rot: float) -> void:
	position = pos
	rotation = rot
	heading = rot
	velocity = Vector2.ZERO
	forward_speed = 0.0
	lateral_speed = 0.0
	slip_angle = 0.0
	current_checkpoint = 0
	drive_time = 0.0
	total_distance = 0.0
	stuck_timer = 0.0
	alive = true
	track_finished = false
	last_position = pos
	prev_checkpoint_dist = INF
	on_grass = false
	is_drifting = false
	handbrake_input = 0.0
	drift_boost = 0.0
	was_drifting = false
	grass_time = 0.0
	max_speed_reached = 0.0
	drift_time = 0.0
	if not checkpoint_positions.is_empty():
		prev_checkpoint_dist = pos.distance_to(checkpoint_positions[0])
	if brain:
		brain.reset_episode()
	if trail_left:
		trail_left.clear_points()
	if trail_right:
		trail_right.clear_points()
