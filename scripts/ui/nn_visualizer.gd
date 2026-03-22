extends Control
class_name NNVisualizer

var network: NeuralNetwork = null
var car: RaceCar = null
var panel_visible: bool = false
var evolution_stats: Dictionary = {}

# Layout
var node_radius := 5.0
var layer_spacing := 80.0
var node_spacing := 12.0

# Colors
var bg_color := Color(0.05, 0.05, 0.09, 0.85)
var active_color := Color(0.45, 0.72, 0.72)
var inactive_color := Color(0.18, 0.18, 0.26, 0.5)
var positive_weight := Color(0.35, 0.70, 0.45, 0.3)
var text_color := Color(0.70, 0.70, 0.78)
var border_color := Color(0.20, 0.20, 0.30)

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func toggle() -> void:
	panel_visible = !panel_visible
	visible = panel_visible

func set_network(nn: NeuralNetwork, c: RaceCar) -> void:
	network = nn
	car = c

func set_evolution_stats(stats: Dictionary) -> void:
	evolution_stats = stats

func _draw() -> void:
	if not panel_visible:
		return
	if network != null:
		_draw_nn_panel()
	if not evolution_stats.is_empty():
		_draw_evolution_panel()

func _draw_nn_panel() -> void:
	var panel_size := Vector2(400, 280)
	var panel_pos := Vector2(size.x - panel_size.x - 10, 50)

	draw_rect(Rect2(panel_pos, panel_size), bg_color)
	draw_rect(Rect2(panel_pos, panel_size), border_color, false, 1.5)

	draw_string(ThemeDB.fallback_font, panel_pos + Vector2(10, 20),
		"Neural Network", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, active_color)

	var layer_sizes := network.layer_sizes
	var activations := network.activations
	var node_positions: Array[Array] = []
	var start_x := panel_pos.x + 35.0
	var start_y := panel_pos.y + 40.0

	for layer_idx in range(layer_sizes.size()):
		var layer_nodes: Array[Vector2] = []
		var count := layer_sizes[layer_idx]
		var display_count := mini(count, 16)
		var x := start_x + layer_idx * layer_spacing

		for i in range(display_count):
			var y := start_y + i * node_spacing
			layer_nodes.append(Vector2(x, y))

		node_positions.append(layer_nodes)

	# Connections
	for layer_idx in range(node_positions.size() - 1):
		var from_nodes: Array = node_positions[layer_idx]
		var to_nodes: Array = node_positions[layer_idx + 1]
		for i in range(mini(from_nodes.size(), 8)):
			for j in range(mini(to_nodes.size(), 8)):
				var w_color := positive_weight
				w_color.a = 0.10
				draw_line(from_nodes[i], to_nodes[j], w_color, 1.0)

	# Nodes
	for layer_idx in range(node_positions.size()):
		var nodes: Array = node_positions[layer_idx]
		for i in range(nodes.size()):
			var pos: Vector2 = nodes[i]
			var activation := 0.0
			if layer_idx < activations.size() and i < activations[layer_idx].size():
				activation = activations[layer_idx][i]
			var brightness := clampf(abs(activation), 0.0, 1.0)
			var color := inactive_color.lerp(active_color, brightness)
			draw_circle(pos, node_radius, color)

	# Dynamic layer labels
	var labels: Array[String] = []
	for i in range(layer_sizes.size()):
		if i == 0:
			labels.append("In(%d)" % layer_sizes[i])
		elif i == layer_sizes.size() - 1:
			labels.append("Out(%d)" % layer_sizes[i])
		else:
			labels.append("H(%d)" % layer_sizes[i])

	for i in range(mini(labels.size(), node_positions.size())):
		if not node_positions[i].is_empty():
			var x_pos: float = node_positions[i][0].x
			draw_string(ThemeDB.fallback_font,
				Vector2(x_pos - 12, panel_pos.y + panel_size.y - 30),
				labels[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 9, text_color)

	# Decision info
	if car != null:
		var steer_dir := "L" if car.steer_input < -0.1 else ("R" if car.steer_input > 0.1 else "-")
		var text := "Steer:%s %.1f  Thr:%.1f  Brk:%.1f" % [steer_dir, car.steer_input, car.throttle_input, car.brake_input]
		draw_string(ThemeDB.fallback_font, panel_pos + Vector2(10, panel_size.y - 12),
			text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, text_color)

func _draw_evolution_panel() -> void:
	var panel_size := Vector2(400, 170)
	var panel_pos := Vector2(size.x - panel_size.x - 10, 340)

	draw_rect(Rect2(panel_pos, panel_size), bg_color)
	draw_rect(Rect2(panel_pos, panel_size), border_color, false, 1.5)

	draw_string(ThemeDB.fallback_font, panel_pos + Vector2(10, 20),
		"Evolution", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, active_color)

	var gen: int = evolution_stats.get("generation", 0)
	var best_f: float = evolution_stats.get("best_fitness", 0.0)
	var avg_f: float = evolution_stats.get("avg_fitness", 0.0)
	var mut_r: float = evolution_stats.get("mutation_rate", 0.0)
	var stag: int = evolution_stats.get("stagnation", 0)

	var y_off := 36.0
	draw_string(ThemeDB.fallback_font, panel_pos + Vector2(10, y_off),
		"Gen: %d  Best: %.0f  Avg: %.0f" % [gen, best_f, avg_f],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, text_color)
	y_off += 16.0

	var stag_col := Color(0.82, 0.42, 0.32) if stag >= 3 else text_color
	draw_string(ThemeDB.fallback_font, panel_pos + Vector2(10, y_off),
		"Mutation: %.2f  Stagnation: %d" % [mut_r, stag],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, stag_col)
	y_off += 20.0

	# Fitness graph
	var best_history: Array = evolution_stats.get("best_history", [])
	var avg_history: Array = evolution_stats.get("avg_history", [])
	if best_history.size() > 1:
		var graph_x := panel_pos.x + 10.0
		var graph_y := panel_pos.y + y_off
		var graph_w := panel_size.x - 20.0
		var graph_h := panel_size.y - y_off - 10.0

		draw_rect(Rect2(graph_x, graph_y, graph_w, graph_h), Color(0.03, 0.03, 0.06))

		var max_f := 1.0
		for f in best_history:
			max_f = maxf(max_f, float(f))

		var display_count := mini(best_history.size(), 50)
		var start_idx := maxi(0, best_history.size() - display_count)

		# Avg fitness line (warm color)
		if avg_history.size() > start_idx + 1:
			for i in range(start_idx + 1, avg_history.size()):
				var x1 := graph_x + float(i - 1 - start_idx) / float(maxi(1, display_count - 1)) * graph_w
				var y1 := graph_y + graph_h - clampf(float(avg_history[i - 1]) / max_f, 0.0, 1.0) * graph_h
				var x2 := graph_x + float(i - start_idx) / float(maxi(1, display_count - 1)) * graph_w
				var y2 := graph_y + graph_h - clampf(float(avg_history[i]) / max_f, 0.0, 1.0) * graph_h
				draw_line(Vector2(x1, y1), Vector2(x2, y2), Color(0.82, 0.62, 0.38, 0.5), 1.5)

		# Best fitness line (accent color)
		for i in range(start_idx + 1, best_history.size()):
			var x1 := graph_x + float(i - 1 - start_idx) / float(maxi(1, display_count - 1)) * graph_w
			var y1 := graph_y + graph_h - clampf(float(best_history[i - 1]) / max_f, 0.0, 1.0) * graph_h
			var x2 := graph_x + float(i - start_idx) / float(maxi(1, display_count - 1)) * graph_w
			var y2 := graph_y + graph_h - clampf(float(best_history[i]) / max_f, 0.0, 1.0) * graph_h
			draw_line(Vector2(x1, y1), Vector2(x2, y2), active_color, 1.5)

		# Legend
		draw_string(ThemeDB.fallback_font, Vector2(graph_x + 2, graph_y + 10),
			"Best", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, active_color)
		draw_string(ThemeDB.fallback_font, Vector2(graph_x + 32, graph_y + 10),
			"Avg", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.82, 0.62, 0.38))

func _process(_delta: float) -> void:
	if panel_visible:
		queue_redraw()
