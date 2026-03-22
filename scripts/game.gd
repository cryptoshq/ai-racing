extends Node2D

# Main game controller — curriculum learning, evolution visualization, faster AI

enum GameMode { TRAINING, DRIVE, EDITOR }
var current_mode: GameMode = GameMode.TRAINING

# Systems
var evolution: Evolution
var track_editor: TrackEditor

# UI
var hud: HUD
var nn_visualizer: NNVisualizer
var main_menu: MainMenu

# Cars
var car_count: int = 15
var cars: Array[RaceCar] = []
var player_car: RaceCar = null
var lead_car: RaceCar = null

# Track
var track_data: Dictionary = {}
var track_tiles: Array = []
var tile_size: int = 32
var checkpoint_positions: Array[Vector2] = []
var start_position: Vector2 = Vector2(320, 320)
var start_rotation: float = 0.0
var checkpoint_radius: float = 40.0

# Physics bodies
var wall_body: StaticBody2D = null
var checkpoint_areas: Array[Area2D] = []

# Training
var gen_timer: float = 0.0
var gen_time_limit: float = 25.0
var current_generation: int = 0
var training_speed: float = 1.0
var is_paused: bool = false
var best_ever_fitness: float = -INF
var alive_count: int = 0

# Curriculum learning
var curriculum_enabled: bool = true
var curriculum_index: int = 0
var curriculum_levels: Array[String] = ["Easy", "Medium", "Hard", "Expert", "Insane"]
var curriculum_thresholds: Array[float] = [4000.0, 3500.0, 3000.0, 2500.0, INF]
var curriculum_streak: int = 0
var curriculum_streak_needed: int = 3

# Camera
var game_camera: Camera2D

# Track rendering
var track_node: Node2D

func _ready() -> void:
	_setup_camera()
	_setup_systems()
	_setup_ui()
	main_menu.show_menu()

func _setup_camera() -> void:
	game_camera = Camera2D.new()
	game_camera.enabled = true
	game_camera.zoom = Vector2(1.0, 1.0)
	game_camera.position_smoothing_enabled = true
	game_camera.position_smoothing_speed = 8.0
	add_child(game_camera)

func _setup_systems() -> void:
	evolution = Evolution.new(car_count)

	track_editor = TrackEditor.new()
	track_editor.visible = false
	add_child(track_editor)
	track_editor.track_saved.connect(_on_track_saved)
	track_editor.track_loaded.connect(_on_editor_track_loaded)
	track_editor.track_test_requested.connect(_on_track_test)

	track_node = Node2D.new()
	track_node.z_index = -10
	add_child(track_node)

func _setup_ui() -> void:
	hud = HUD.new()
	add_child(hud)

	nn_visualizer = NNVisualizer.new()
	nn_visualizer.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.add_child(nn_visualizer)

	main_menu = MainMenu.new()
	add_child(main_menu)
	main_menu.mode_selected.connect(_on_mode_selected)
	main_menu.track_selected.connect(_on_track_selected)

func _get_car_color(idx: int) -> Color:
	var base: Array[Color] = [
		Color(0.35, 0.55, 0.90), Color(0.90, 0.40, 0.35),
		Color(0.40, 0.80, 0.45), Color(0.85, 0.65, 0.30),
		Color(0.70, 0.40, 0.85), Color(0.35, 0.80, 0.78),
		Color(0.90, 0.55, 0.70), Color(0.60, 0.75, 0.35),
		Color(0.50, 0.60, 0.85), Color(0.85, 0.50, 0.30),
		Color(0.55, 0.45, 0.70), Color(0.40, 0.70, 0.60),
		Color(0.80, 0.72, 0.40), Color(0.62, 0.35, 0.55),
		Color(0.45, 0.62, 0.50),
	]
	if idx < base.size():
		return base[idx]
	var hue := fmod(float(idx) * 0.618033988749895, 1.0)
	return Color.from_hsv(hue, 0.65, 0.85)

# --- Track ---

func _apply_track(data: Dictionary) -> void:
	track_data = data
	track_tiles = data.get("tiles", [])
	tile_size = data.get("tile_size", 32)
	checkpoint_positions.clear()
	for cp in data.get("checkpoints", []):
		checkpoint_positions.append(Vector2(float(cp["x"]), float(cp["y"])))
	var start: Dictionary = data.get("start", {"x": 320, "y": 320, "rotation": 0})
	start_position = Vector2(float(start["x"]), float(start["y"]))
	start_rotation = float(start.get("rotation", 0))

	_render_track()
	_build_wall_physics()
	_build_checkpoint_areas()
	_center_camera()

func _center_camera() -> void:
	if game_camera and not track_tiles.is_empty():
		var tw: float = float(track_tiles[0].size()) * float(tile_size)
		var th: float = float(track_tiles.size()) * float(tile_size)
		game_camera.position = Vector2(tw / 2.0, th / 2.0)

func _render_track() -> void:
	for child in track_node.get_children():
		child.queue_free()
	if track_tiles.is_empty():
		return
	var drawer := TrackDrawer.new()
	drawer.tiles = track_tiles
	drawer.tile_size = tile_size
	var pts = track_data.get("road_points", PackedVector2Array())
	if pts is PackedVector2Array:
		drawer.road_points = pts
	drawer.road_half_width = float(track_data.get("road_half_width", 60.0))
	drawer.start_pos = start_position
	drawer.start_rot = start_rotation
	var finish: Dictionary = track_data.get("finish", {})
	if not finish.is_empty():
		drawer.finish_pos = Vector2(float(finish["x"]), float(finish["y"]))
	track_node.add_child(drawer)

func _build_wall_physics() -> void:
	if wall_body:
		wall_body.queue_free()
		wall_body = null
	if track_tiles.is_empty():
		return

	wall_body = StaticBody2D.new()
	wall_body.collision_layer = 2
	wall_body.collision_mask = 0
	add_child(wall_body)

	var h: int = track_tiles.size()
	var w: int = track_tiles[0].size() if h > 0 else 0

	for y in range(h):
		for x in range(w):
			var tid: int = int(track_tiles[y][x])
			if tid == 3:
				var shape := RectangleShape2D.new()
				shape.size = Vector2(tile_size, tile_size)
				var col := CollisionShape2D.new()
				col.shape = shape
				col.position = Vector2(x * tile_size + tile_size * 0.5, y * tile_size + tile_size * 0.5)
				wall_body.add_child(col)

	var total_w: float = w * tile_size
	var total_h: float = h * tile_size
	var borders: Array[Array] = [
		[Vector2(total_w * 0.5, -16), Vector2(total_w + 32, 32)],
		[Vector2(total_w * 0.5, total_h + 16), Vector2(total_w + 32, 32)],
		[Vector2(-16, total_h * 0.5), Vector2(32, total_h + 32)],
		[Vector2(total_w + 16, total_h * 0.5), Vector2(32, total_h + 32)],
	]
	for border in borders:
		var shape := RectangleShape2D.new()
		shape.size = border[1]
		var col := CollisionShape2D.new()
		col.shape = shape
		col.position = border[0]
		wall_body.add_child(col)

func _build_checkpoint_areas() -> void:
	for area in checkpoint_areas:
		if is_instance_valid(area):
			area.queue_free()
	checkpoint_areas.clear()

	for i in range(checkpoint_positions.size()):
		var area := Area2D.new()
		area.collision_layer = 4
		area.collision_mask = 1
		area.position = checkpoint_positions[i]
		var col := CollisionShape2D.new()
		var shape := CircleShape2D.new()
		shape.radius = checkpoint_radius
		col.shape = shape
		area.add_child(col)
		area.set_meta("checkpoint_index", i)
		area.body_entered.connect(_on_checkpoint_body_entered.bind(i))
		add_child(area)
		checkpoint_areas.append(area)

func _on_checkpoint_body_entered(body: Node2D, idx: int) -> void:
	if body is RaceCar:
		(body as RaceCar).hit_checkpoint(idx)

# --- Spawning ---

func _spawn_all_training_cars() -> void:
	_clear_all_cars()
	var brains := evolution.population
	alive_count = brains.size()

	for i in range(brains.size()):
		var brain := brains[i]
		brain.reset_episode()
		var c := RaceCar.new()
		c.car_index = i
		c.car_color = _get_car_color(i)
		c.is_ai = true
		c.track_data = track_tiles
		c.tile_size = tile_size
		c.checkpoint_positions = checkpoint_positions
		c.total_checkpoints = checkpoint_positions.size()
		c.brain = brain
		c.position = start_position
		c.rotation = start_rotation
		c.heading = start_rotation
		c.checkpoint_hit.connect(_on_checkpoint_hit)
		c.track_completed.connect(_on_track_completed)
		c.crashed.connect(_on_car_crashed)
		add_child(c)
		cars.append(c)

	lead_car = cars[0] if not cars.is_empty() else null
	_update_nn_visualizer()
	gen_timer = 0.0
	hud.update_brain_info(alive_count, car_count, current_generation)

func _spawn_player_car() -> void:
	_clear_all_cars()
	player_car = RaceCar.new()
	player_car.car_index = 0
	player_car.car_color = _get_car_color(0)
	player_car.is_ai = false
	player_car.track_data = track_tiles
	player_car.tile_size = tile_size
	player_car.checkpoint_positions = checkpoint_positions
	player_car.total_checkpoints = checkpoint_positions.size()
	player_car.position = start_position
	player_car.rotation = start_rotation
	player_car.heading = start_rotation
	player_car.checkpoint_hit.connect(_on_checkpoint_hit)
	player_car.track_completed.connect(_on_track_completed)
	player_car.crashed.connect(_on_car_crashed)
	add_child(player_car)

func _clear_all_cars() -> void:
	for c in cars:
		if is_instance_valid(c):
			c.queue_free()
	cars.clear()
	lead_car = null
	if player_car and is_instance_valid(player_car):
		player_car.queue_free()
		player_car = null

# --- Game loop ---

func _physics_process(delta: float) -> void:
	if is_paused:
		return
	match current_mode:
		GameMode.TRAINING:
			_update_training(delta)
		GameMode.DRIVE:
			pass
	_update_camera(delta)
	_update_ui()

func _update_training(delta: float) -> void:
	gen_timer += delta
	if cars.is_empty():
		_spawn_all_training_cars()
		return

	alive_count = 0
	var best_car: RaceCar = null
	var best_progress: float = -1.0

	for c in cars:
		if not is_instance_valid(c):
			continue
		if c.alive and not c.track_finished and c.stuck_timer > 3.0:
			c.alive = false
		if c.alive and not c.track_finished:
			alive_count += 1
			var progress: float = c.current_checkpoint * 10000.0 + c.total_distance
			if progress > best_progress:
				best_progress = progress
				best_car = c

	if best_car != null and best_car != lead_car:
		lead_car = best_car
		_update_nn_visualizer()

	if alive_count == 0 or gen_timer > gen_time_limit:
		_finish_generation()

func _finish_generation() -> void:
	for c in cars:
		if is_instance_valid(c) and c.brain:
			c.brain.total_distance = c.total_distance
			c.brain.calculate_fitness()
			if c.brain.fitness > best_ever_fitness:
				best_ever_fitness = c.brain.fitness
	evolution.evolve()
	current_generation = evolution.generation
	var best_f: float = evolution.best_fitness_history.back() if not evolution.best_fitness_history.is_empty() else 0.0
	hud.show_message("Gen %d  best: %.0f" % [current_generation, best_f], 2.0)

	# Curriculum advancement
	_check_curriculum()

	_spawn_all_training_cars()

func _check_curriculum() -> void:
	if not curriculum_enabled:
		return
	if curriculum_index >= curriculum_levels.size() - 1:
		return
	var threshold := curriculum_thresholds[curriculum_index]
	var best_f: float = evolution.best_fitness_history.back() if not evolution.best_fitness_history.is_empty() else 0.0

	if best_f >= threshold:
		curriculum_streak += 1
	else:
		curriculum_streak = maxi(0, curriculum_streak - 1)

	if curriculum_streak >= curriculum_streak_needed:
		curriculum_index += 1
		curriculum_streak = 0
		_advance_curriculum()

func _advance_curriculum() -> void:
	var diff := curriculum_levels[curriculum_index]
	var gen := TrackGenerator.new()
	var data := gen.generate(diff)
	_apply_track(data)
	hud.show_message("Curriculum: %s!" % diff, 3.0)

func _reset_evolution() -> void:
	evolution = Evolution.new(car_count)
	current_generation = 0
	best_ever_fitness = -INF
	curriculum_index = 0
	curriculum_streak = 0

func _update_nn_visualizer() -> void:
	if lead_car and is_instance_valid(lead_car) and lead_car.brain:
		nn_visualizer.set_network(lead_car.brain.network, lead_car)
	nn_visualizer.set_evolution_stats(evolution.get_stats())

# --- Camera ---

func _update_camera(delta: float) -> void:
	match current_mode:
		GameMode.TRAINING:
			_camera_overview(delta)
		GameMode.DRIVE:
			_camera_follow_car(delta)
		GameMode.EDITOR:
			pass

func _camera_overview(delta: float) -> void:
	if track_tiles.is_empty():
		return
	var tw: float = float(track_tiles[0].size()) * float(tile_size)
	var th: float = float(track_tiles.size()) * float(tile_size)
	var target := Vector2(tw * 0.5, th * 0.5)
	game_camera.position = game_camera.position.lerp(target, 5.0 * delta)
	var viewport_size := Vector2(1280.0, 720.0)
	var zoom_x := viewport_size.x / (tw + 100.0)
	var zoom_y := viewport_size.y / (th + 100.0)
	var target_zoom := minf(zoom_x, zoom_y)
	target_zoom = clampf(target_zoom, 0.2, 2.0)
	game_camera.zoom = game_camera.zoom.lerp(Vector2(target_zoom, target_zoom), 3.0 * delta)
	game_camera.offset = Vector2.ZERO

func _camera_follow_car(delta: float) -> void:
	if player_car == null or not is_instance_valid(player_car):
		return
	var lookahead := player_car.velocity.normalized() * 40.0
	var target := player_car.position + lookahead
	game_camera.position = game_camera.position.lerp(target, 8.0 * delta)
	var speed_ratio := player_car.velocity.length() / player_car.max_speed
	var target_zoom := lerpf(1.3, 0.9, speed_ratio)
	game_camera.zoom = game_camera.zoom.lerp(Vector2(target_zoom, target_zoom), 3.0 * delta)
	game_camera.offset = Vector2.ZERO

# --- UI ---

func _update_ui() -> void:
	if current_mode == GameMode.TRAINING:
		if lead_car and is_instance_valid(lead_car):
			hud.update_car_stat(lead_car.drive_time, lead_car.current_checkpoint,
				lead_car.total_checkpoints, lead_car.total_distance, lead_car.velocity.length())
		hud.update_brain_info(alive_count, car_count, current_generation)
		nn_visualizer.set_evolution_stats(evolution.get_stats())
	elif current_mode == GameMode.DRIVE:
		if player_car and is_instance_valid(player_car):
			hud.update_car_stat(player_car.drive_time, player_car.current_checkpoint,
				player_car.total_checkpoints, player_car.total_distance, player_car.velocity.length())
	hud.update_generation(current_generation)

# --- Signal handlers ---

func _on_mode_selected(mode: String) -> void:
	is_paused = false
	match mode:
		"training":
			if track_tiles.is_empty():
				return
			car_count = main_menu.car_count
			current_mode = GameMode.TRAINING
			hud.update_mode("Training")
			track_editor.deactivate()
			_reset_evolution()
			_spawn_all_training_cars()
		"drive":
			if track_tiles.is_empty():
				return
			current_mode = GameMode.DRIVE
			hud.update_mode("Free Drive")
			track_editor.deactivate()
			_spawn_player_car()
		"editor":
			current_mode = GameMode.EDITOR
			hud.update_mode("Editor")
			_clear_all_cars()
			track_editor.activate(game_camera)

func _on_track_selected(data: Dictionary) -> void:
	_apply_track(data)
	# Sync curriculum index with selected difficulty
	var diff: String = data.get("difficulty", "Easy")
	var idx := curriculum_levels.find(diff)
	if idx >= 0:
		curriculum_index = idx
	hud.show_message(data.get("name", "Track"), 2.0)

func _on_checkpoint_hit(_car_node: RaceCar, _idx: int) -> void:
	pass

func _on_track_completed(car_node: RaceCar, time: float) -> void:
	if current_mode == GameMode.DRIVE:
		hud.show_message("Finished!  %.1fs" % time, 5.0)

func _on_car_crashed(_car_node: RaceCar) -> void:
	pass

func _on_track_saved(_path: String) -> void:
	hud.show_message("Track saved!", 2.0)

func _on_editor_track_loaded(data: Dictionary) -> void:
	hud.show_message("Track loaded!", 2.0)

func _on_track_test(data: Dictionary) -> void:
	_apply_track(data)
	car_count = main_menu.car_count
	current_mode = GameMode.TRAINING
	hud.update_mode("Training")
	track_editor.deactivate()
	main_menu.hide_menu()
	is_paused = false
	_reset_evolution()
	_spawn_all_training_cars()
	hud.show_message("Testing track...", 2.0)

# --- Input ---

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_N:
				nn_visualizer.toggle()
			KEY_ESCAPE:
				if current_mode == GameMode.EDITOR:
					track_editor.deactivate()
					is_paused = true
					main_menu.show_menu()
				elif main_menu.is_visible:
					is_paused = false
					main_menu.hide_menu()
				else:
					is_paused = true
					main_menu.show_menu()
			KEY_EQUAL, KEY_KP_ADD:
				training_speed = minf(training_speed + 0.5, 5.0)
				Engine.time_scale = training_speed
				hud.show_message("Speed: %.1fx" % training_speed, 1.0)
			KEY_MINUS, KEY_KP_SUBTRACT:
				training_speed = maxf(training_speed - 0.5, 0.5)
				Engine.time_scale = training_speed
				hud.show_message("Speed: %.1fx" % training_speed, 1.0)


# --- Smooth track drawer ---

class TrackDrawer extends Node2D:
	var tiles: Array = []
	var tile_size: int = 32
	var road_points: PackedVector2Array = PackedVector2Array()
	var road_half_width: float = 60.0
	var start_pos: Vector2 = Vector2.ZERO
	var start_rot: float = 0.0
	var finish_pos: Vector2 = Vector2.ZERO

	# Colors — no grass, clean dark ground
	var sand_color := Color(0.68, 0.56, 0.34)
	var curb_red := Color(0.82, 0.18, 0.14)
	var curb_white := Color(0.94, 0.94, 0.90)
	var road_color := Color(0.34, 0.34, 0.38)
	var line_white := Color(0.95, 0.95, 0.88, 0.85)

	func _draw() -> void:
		if tiles.is_empty():
			return
		var tw := float(tiles[0].size()) * tile_size
		var th := float(tiles.size()) * tile_size

		# Dark ground background (grass removed)
		draw_rect(Rect2(0, 0, tw, th), Color(0.12, 0.14, 0.10))

		if road_points.size() < 2:
			_draw_tiles_fallback()
			return

		# Sand border
		draw_polyline(road_points, sand_color, road_half_width * 2 + 24)

		# Curb — red base
		draw_polyline(road_points, curb_red, road_half_width * 2 + 12)

		# Curb — white stripes
		_draw_curb_white_stripes()

		# Road surface
		draw_polyline(road_points, road_color, road_half_width * 2)

		# Center dashes
		_draw_center_dashes()

		# Start / finish
		_draw_checkered_markers()

	func _draw_curb_white_stripes() -> void:
		var curb_w := road_half_width * 2 + 12
		var stripe_len := 18.0
		var accumulated := 0.0
		var seg_start := 0
		var draw_white := false

		for i in range(1, road_points.size()):
			accumulated += road_points[i - 1].distance_to(road_points[i])
			if accumulated >= stripe_len or i == road_points.size() - 1:
				if draw_white:
					var segment := PackedVector2Array()
					for j in range(seg_start, mini(i + 1, road_points.size())):
						segment.append(road_points[j])
					if segment.size() >= 2:
						draw_polyline(segment, curb_white, curb_w)
				accumulated = 0.0
				seg_start = i
				draw_white = !draw_white

	func _draw_center_dashes() -> void:
		var dash_len := 22.0
		var gap_len := 18.0
		var accumulated := 0.0
		var is_dash := true
		var seg_start := 0

		for i in range(1, road_points.size()):
			accumulated += road_points[i - 1].distance_to(road_points[i])
			var target := dash_len if is_dash else gap_len
			if accumulated >= target or i == road_points.size() - 1:
				if is_dash:
					var segment := PackedVector2Array()
					for j in range(seg_start, mini(i + 1, road_points.size())):
						segment.append(road_points[j])
					if segment.size() >= 2:
						draw_polyline(segment, line_white, 3.0)
				accumulated = 0.0
				seg_start = i
				is_dash = !is_dash

	func _draw_checkered_markers() -> void:
		if road_points.size() < 4:
			return
		var s_tangent := (road_points[1] - road_points[0]).normalized()
		_draw_checkered(road_points[0], s_tangent)
		var last := road_points.size() - 1
		var f_tangent := (road_points[last] - road_points[last - 1]).normalized()
		_draw_checkered(road_points[last], f_tangent)

	func _draw_checkered(center: Vector2, tangent: Vector2) -> void:
		var normal := Vector2(-tangent.y, tangent.x)
		var sq := 9.0
		var hw := road_half_width
		var cols := int(hw * 2.0 / sq)
		for row in range(3):
			for col in range(cols):
				var on := (row + col) % 2 == 0
				var col_color := Color.WHITE if on else Color(0.08, 0.08, 0.1)
				var offset := normal * (-hw + (float(col) + 0.5) * sq) + tangent * ((float(row) - 1.0) * sq)
				var p := center + offset
				var hs := sq * 0.5
				draw_colored_polygon(PackedVector2Array([
					p - normal * hs - tangent * hs,
					p + normal * hs - tangent * hs,
					p + normal * hs + tangent * hs,
					p - normal * hs + tangent * hs,
				]), col_color)

	func _draw_tiles_fallback() -> void:
		var tile_colors_fb: Dictionary = {
			0: Color(0.05, 0.05, 0.08),
			1: Color(0.30, 0.30, 0.35),
			2: Color(0.10, 0.14, 0.10),
			3: Color(0.08, 0.08, 0.12),
			9: Color(0.85, 0.65, 0.30, 0.8),
			10: Color(0.35, 0.80, 0.45, 0.8),
		}
		for y in range(tiles.size()):
			var row: Array = tiles[y]
			for x in range(row.size()):
				var tid: int = int(row[x])
				var color: Color = tile_colors_fb.get(tid, Color(0.05, 0.05, 0.08))
				if tid >= 4 and tid <= 8:
					color = Color(0.35, 0.65, 0.70, 0.6)
				draw_rect(Rect2(x * tile_size, y * tile_size, tile_size, tile_size), color)
