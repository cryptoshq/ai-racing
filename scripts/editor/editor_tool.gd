extends Node2D
class_name TrackEditor

signal track_saved(path: String)
signal track_loaded(data: Dictionary)
signal track_test_requested(data: Dictionary)

var active: bool = false
var grid_width: int = 32
var grid_height: int = 24
var tile_size: int = 32
var tiles: Array = []

# Grass tool removed — Eraser sets to grass by default
enum Tool { ROAD, WALL, CHECKPOINT, ERASER, START, FINISH }
var current_tool: Tool = Tool.ROAD
var brush_size: int = 2
var checkpoint_index: int = 0

var tile_colors := {
	0: Color(0.04, 0.04, 0.07),
	1: Color(0.28, 0.28, 0.32),
	2: Color(0.08, 0.16, 0.08),
	3: Color(0.10, 0.10, 0.15),
	4: Color(0.35, 0.65, 0.70, 0.7),
	5: Color(0.30, 0.60, 0.65, 0.7),
	6: Color(0.25, 0.55, 0.60, 0.7),
	7: Color(0.20, 0.50, 0.55, 0.7),
	8: Color(0.15, 0.45, 0.50, 0.7),
	9: Color(0.85, 0.65, 0.30, 0.8),
	10: Color(0.35, 0.80, 0.45, 0.8),
}

var editor_ui: CanvasLayer
var tool_label: Label
var status_label: Label
var is_painting: bool = false
var is_erasing: bool = false
var camera: Camera2D
var cursor_pos: Vector2 = Vector2.ZERO
var is_panning: bool = false

func _ready() -> void:
	_init_grid()
	_setup_ui()

func _init_grid() -> void:
	tiles.clear()
	for y in range(grid_height):
		var row: Array[int] = []
		row.resize(grid_width)
		row.fill(2)
		tiles.append(row)

func _setup_ui() -> void:
	editor_ui = CanvasLayer.new()
	editor_ui.layer = 15
	add_child(editor_ui)

	var panel := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.04, 0.08, 0.95)
	style.border_color = Color(0.14, 0.14, 0.20)
	style.border_width_bottom = 1
	panel.add_theme_stylebox_override("panel", style)
	panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	panel.custom_minimum_size.y = 50
	editor_ui.add_child(panel)

	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.offset_left = 10
	hbox.offset_top = 4
	hbox.offset_right = -10
	hbox.add_theme_constant_override("separation", 5)
	panel.add_child(hbox)

	# Tool buttons — no Grass (eraser handles it)
	var tool_data: Array[Array] = [
		["Road", Color(0.45, 0.45, 0.52), Tool.ROAD],
		["Wall", Color(0.30, 0.30, 0.40), Tool.WALL],
		["CP", Color(0.45, 0.72, 0.72), Tool.CHECKPOINT],
		["Erase", Color(0.65, 0.35, 0.35), Tool.ERASER],
		["Start", Color(0.85, 0.65, 0.30), Tool.START],
		["Finish", Color(0.35, 0.80, 0.45), Tool.FINISH],
	]

	for td in tool_data:
		var btn := Button.new()
		btn.text = td[0] as String
		btn.custom_minimum_size = Vector2(52, 36)
		var btn_style := StyleBoxFlat.new()
		btn_style.bg_color = Color(0.06, 0.06, 0.10)
		btn_style.border_color = td[1] as Color
		btn_style.set_border_width_all(1)
		btn_style.set_corner_radius_all(4)
		btn.add_theme_stylebox_override("normal", btn_style)
		var hover := btn_style.duplicate()
		hover.bg_color = Color(td[1].r * 0.2, td[1].g * 0.2, td[1].b * 0.2)
		btn.add_theme_stylebox_override("hover", hover)
		btn.add_theme_color_override("font_color", td[1] as Color)
		btn.add_theme_font_size_override("font_size", 11)
		var tool_enum: Tool = td[2] as Tool
		btn.pressed.connect(func(): _set_tool(tool_enum))
		hbox.add_child(btn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	tool_label = Label.new()
	tool_label.text = "Road  Brush: 2"
	tool_label.add_theme_font_size_override("font_size", 12)
	tool_label.add_theme_color_override("font_color", Color(0.45, 0.72, 0.72))
	hbox.add_child(tool_label)

	var actions: Array[Array] = [
		["Test AI", Color(0.45, 0.72, 0.72), func(): _test_track()],
		["Validate", Color(0.42, 0.76, 0.48), func(): _validate()],
		["Save", Color(0.45, 0.55, 0.80), func(): _save()],
		["Load", Color(0.55, 0.50, 0.70), func(): _load()],
		["Auto-Wall", Color(0.80, 0.58, 0.32), func(): _auto_walls()],
	]
	for act in actions:
		var btn := Button.new()
		btn.text = act[0] as String
		btn.custom_minimum_size = Vector2(62, 36)
		var btn_style := StyleBoxFlat.new()
		btn_style.bg_color = Color(0.05, 0.05, 0.09)
		btn_style.border_color = act[1] as Color
		btn_style.border_width_bottom = 1
		btn_style.set_corner_radius_all(3)
		btn.add_theme_stylebox_override("normal", btn_style)
		var hover := btn_style.duplicate()
		hover.bg_color = Color(0.10, 0.10, 0.16)
		btn.add_theme_stylebox_override("hover", hover)
		btn.add_theme_color_override("font_color", act[1] as Color)
		btn.add_theme_font_size_override("font_size", 11)
		btn.pressed.connect(act[2] as Callable)
		hbox.add_child(btn)

	status_label = Label.new()
	status_label.text = "Left-click: paint | Right-click: erase | Scroll: brush size | Middle-drag: pan"
	status_label.add_theme_font_size_override("font_size", 12)
	status_label.add_theme_color_override("font_color", Color(0.36, 0.38, 0.46))
	status_label.anchor_left = 0.0
	status_label.anchor_right = 1.0
	status_label.anchor_top = 1.0
	status_label.anchor_bottom = 1.0
	status_label.offset_top = -30
	status_label.offset_left = 10
	editor_ui.add_child(status_label)

func activate(cam: Camera2D = null) -> void:
	active = true
	visible = true
	editor_ui.visible = true
	camera = cam
	if camera:
		var tw := grid_width * tile_size
		var th := grid_height * tile_size
		var zx := 1280.0 / (tw + 100.0)
		var zy := 720.0 / (th + 100.0)
		camera.zoom = Vector2(minf(zx, zy), minf(zx, zy))
		camera.position = Vector2(tw * 0.5, th * 0.5)
	queue_redraw()

func deactivate() -> void:
	active = false
	visible = false
	editor_ui.visible = false

func _draw() -> void:
	if not active:
		return

	for y in range(grid_height):
		for x in range(grid_width):
			var tile_id: int = tiles[y][x]
			var color: Color = tile_colors.get(tile_id, Color(0.04, 0.04, 0.07))
			draw_rect(Rect2(x * tile_size, y * tile_size, tile_size, tile_size), color)

	var grid_c := Color(0.16, 0.16, 0.22, 0.2)
	for x in range(grid_width + 1):
		draw_line(Vector2(x * tile_size, 0), Vector2(x * tile_size, grid_height * tile_size), grid_c, 1.0)
	for y in range(grid_height + 1):
		draw_line(Vector2(0, y * tile_size), Vector2(grid_width * tile_size, y * tile_size), grid_c, 1.0)

	var cx := int(cursor_pos.x / tile_size)
	var cy := int(cursor_pos.y / tile_size)
	for dx in range(-brush_size + 1, brush_size):
		for dy in range(-brush_size + 1, brush_size):
			var tx := cx + dx
			var ty := cy + dy
			if tx >= 0 and tx < grid_width and ty >= 0 and ty < grid_height:
				draw_rect(Rect2(tx * tile_size, ty * tile_size, tile_size, tile_size),
					Color(1.0, 1.0, 1.0, 0.08))
				draw_rect(Rect2(tx * tile_size, ty * tile_size, tile_size, tile_size),
					Color(0.45, 0.72, 0.72, 0.3), false, 1.5)

	for y2 in range(grid_height):
		for x2 in range(grid_width):
			var tid: int = tiles[y2][x2]
			if tid >= 4 and tid <= 8:
				draw_string(ThemeDB.fallback_font,
					Vector2(x2 * tile_size + 8, y2 * tile_size + 22),
					str(tid - 3), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
			elif tid == 9:
				draw_string(ThemeDB.fallback_font,
					Vector2(x2 * tile_size + 6, y2 * tile_size + 22),
					"S", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.1, 0.1, 0.1))
			elif tid == 10:
				draw_string(ThemeDB.fallback_font,
					Vector2(x2 * tile_size + 6, y2 * tile_size + 22),
					"F", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.1, 0.1, 0.1))

func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return

	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1: _set_tool(Tool.ROAD)
			KEY_2: _set_tool(Tool.WALL)
			KEY_3: _set_tool(Tool.CHECKPOINT)
			KEY_4: _set_tool(Tool.ERASER)
			KEY_5: _set_tool(Tool.START)
			KEY_6: _set_tool(Tool.FINISH)

	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if event.pressed:
					brush_size = mini(brush_size + 1, 5)
					tool_label.text = _get_tool_text()
			MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed:
					brush_size = maxi(brush_size - 1, 1)
					tool_label.text = _get_tool_text()
			MOUSE_BUTTON_LEFT:
				is_painting = event.pressed
				if event.pressed:
					_paint(get_global_mouse_position())
			MOUSE_BUTTON_RIGHT:
				is_erasing = event.pressed
				if event.pressed:
					_erase(get_global_mouse_position())
			MOUSE_BUTTON_MIDDLE:
				is_panning = event.pressed

	if event is InputEventMouseMotion:
		cursor_pos = get_global_mouse_position()
		queue_redraw()
		if is_painting:
			_paint(cursor_pos)
		elif is_erasing:
			_erase(cursor_pos)
		elif is_panning and camera:
			var delta_v: Vector2 = event.relative
			camera.position -= delta_v / camera.zoom.x

func _set_tool(tool: Tool) -> void:
	current_tool = tool
	if tool == Tool.CHECKPOINT:
		checkpoint_index = (checkpoint_index + 1) % 5
	tool_label.text = _get_tool_text()

func _get_tool_text() -> String:
	var names := ["Road", "Wall", "CP %d" % (checkpoint_index + 1), "Eraser", "Start", "Finish"]
	return "%s  Brush: %d" % [names[current_tool], brush_size]

func _paint(world_pos: Vector2) -> void:
	var cx := int(world_pos.x / tile_size)
	var cy := int(world_pos.y / tile_size)
	var tid := _get_tile_id_for_tool()
	for dx in range(-brush_size + 1, brush_size):
		for dy in range(-brush_size + 1, brush_size):
			var tx := cx + dx
			var ty := cy + dy
			if tx >= 0 and tx < grid_width and ty >= 0 and ty < grid_height:
				tiles[ty][tx] = tid
	queue_redraw()

func _erase(world_pos: Vector2) -> void:
	var cx := int(world_pos.x / tile_size)
	var cy := int(world_pos.y / tile_size)
	for dx in range(-brush_size + 1, brush_size):
		for dy in range(-brush_size + 1, brush_size):
			var tx := cx + dx
			var ty := cy + dy
			if tx >= 0 and tx < grid_width and ty >= 0 and ty < grid_height:
				tiles[ty][tx] = 2
	queue_redraw()

func _get_tile_id_for_tool() -> int:
	match current_tool:
		Tool.ROAD: return 1
		Tool.WALL: return 3
		Tool.CHECKPOINT: return 4 + checkpoint_index
		Tool.ERASER: return 2
		Tool.START: return 9
		Tool.FINISH: return 10
	return 2

func _auto_walls() -> void:
	var wall_list: Array[Vector2i] = []
	for y in range(grid_height):
		for x in range(grid_width):
			if tiles[y][x] == 1 or tiles[y][x] == 9 or tiles[y][x] == 10:
				for dx in [-1, 0, 1]:
					for dy in [-1, 0, 1]:
						if dx == 0 and dy == 0:
							continue
						var nx: int = x + dx
						var ny: int = y + dy
						if nx >= 0 and nx < grid_width and ny >= 0 and ny < grid_height:
							if tiles[ny][nx] == 2:
								wall_list.append(Vector2i(nx, ny))
	for wt in wall_list:
		tiles[wt.y][wt.x] = 3
	queue_redraw()
	status_label.text = "Auto-walls added!"

func _test_track() -> void:
	var data := _export_track_data()
	var result := TrackLoader.validate_track(data)
	if result["valid"]:
		emit_signal("track_test_requested", data)
	else:
		var errors: Array = result["errors"]
		status_label.text = "Fix first: " + ", ".join(errors)
		status_label.add_theme_color_override("font_color", Color(0.82, 0.38, 0.32))

func _validate() -> void:
	var data := _export_track_data()
	var result := TrackLoader.validate_track(data)
	if result["valid"]:
		status_label.text = "Track is valid! Ready to test."
		status_label.add_theme_color_override("font_color", Color(0.42, 0.76, 0.48))
	else:
		var errors: Array = result["errors"]
		status_label.text = "Invalid: " + ", ".join(errors)
		status_label.add_theme_color_override("font_color", Color(0.82, 0.38, 0.32))

func _save() -> void:
	var data := _export_track_data()
	var validation := TrackLoader.validate_track(data)
	if not validation["valid"]:
		var errors: Array = validation["errors"]
		status_label.text = "Cannot save: " + ", ".join(errors)
		status_label.add_theme_color_override("font_color", Color(0.82, 0.38, 0.32))
		return
	var timestamp := str(int(Time.get_unix_time_from_system()))
	var path := "user://tracks/track_%s.json" % timestamp
	DirAccess.make_dir_recursive_absolute("user://tracks")
	if TrackLoader.save_track(path, data):
		status_label.text = "Track saved: track_%s" % timestamp
		status_label.add_theme_color_override("font_color", Color(0.42, 0.76, 0.48))
		emit_signal("track_saved", path)

func _load() -> void:
	# Load the most recent saved track
	var dir := DirAccess.open("user://tracks")
	if dir == null:
		status_label.text = "No saved tracks found"
		status_label.add_theme_color_override("font_color", Color(0.82, 0.62, 0.32))
		return
	var files: Array[String] = []
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if fname.ends_with(".json"):
			files.append(fname)
		fname = dir.get_next()
	dir.list_dir_end()
	if files.is_empty():
		status_label.text = "No saved tracks found"
		status_label.add_theme_color_override("font_color", Color(0.82, 0.62, 0.32))
		return
	files.sort()
	var latest := files[files.size() - 1]
	var path := "user://tracks/" + latest
	var data := TrackLoader.load_track(path)
	if data.is_empty():
		status_label.text = "Failed to load track"
		status_label.add_theme_color_override("font_color", Color(0.82, 0.38, 0.32))
		return
	_import_track_data(data)
	status_label.text = "Loaded: " + latest
	status_label.add_theme_color_override("font_color", Color(0.42, 0.76, 0.48))
	emit_signal("track_loaded", data)

func _export_track_data() -> Dictionary:
	var checkpoints: Array[Dictionary] = []
	var start := {"x": 0, "y": 0, "rotation": 0}
	var finish_cp: Dictionary = {}

	for y in range(grid_height):
		for x in range(grid_width):
			var t: int = tiles[y][x]
			if t >= 4 and t <= 8:
				checkpoints.append({
					"x": x * tile_size + tile_size / 2,
					"y": y * tile_size + tile_size / 2,
					"index": t - 4
				})
			elif t == 9:
				start = {
					"x": x * tile_size + tile_size / 2,
					"y": y * tile_size + tile_size / 2,
					"rotation": 0
				}
			elif t == 10:
				finish_cp = {
					"x": x * tile_size + tile_size / 2,
					"y": y * tile_size + tile_size / 2,
					"index": 99
				}

	checkpoints.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["index"] < b["index"]
	)
	if not finish_cp.is_empty():
		finish_cp["index"] = checkpoints.size()
		checkpoints.append(finish_cp)

	return {
		"name": "Custom Track",
		"author": "Player",
		"difficulty": "Custom",
		"tile_size": tile_size,
		"width": grid_width,
		"height": grid_height,
		"tiles": tiles,
		"checkpoints": checkpoints,
		"start": start,
		"obstacles": []
	}

func _import_track_data(data: Dictionary) -> void:
	if data.has("tiles"):
		tiles = data["tiles"]
		grid_width = data.get("width", 32)
		grid_height = data.get("height", 24)
		queue_redraw()

func get_track_data() -> Dictionary:
	return _export_track_data()
