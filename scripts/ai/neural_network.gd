class_name NeuralNetwork
extends RefCounted

# Neural network — deeper architecture: 18 -> 48 -> 32 -> 16 -> 4

var layers: Array[PackedFloat64Array] = []
var biases: Array[PackedFloat64Array] = []
var layer_sizes: Array[int] = [18, 48, 32, 16, 4]
var activations: Array[PackedFloat64Array] = []

func _init(sizes: Array[int] = [18, 48, 32, 16, 4]) -> void:
	layer_sizes = sizes
	_initialize_weights()

func _initialize_weights() -> void:
	layers.clear()
	biases.clear()
	for i in range(1, layer_sizes.size()):
		var prev_size := layer_sizes[i - 1]
		var curr_size := layer_sizes[i]
		var scale := sqrt(2.0 / prev_size)
		var w := PackedFloat64Array()
		w.resize(prev_size * curr_size)
		for j in range(w.size()):
			w[j] = _randn() * scale
		layers.append(w)
		var b := PackedFloat64Array()
		b.resize(curr_size)
		for j in range(b.size()):
			b[j] = 0.0
		biases.append(b)

func _randn() -> float:
	var u1 := randf_range(0.001, 1.0)
	var u2 := randf_range(0.0, 1.0)
	return sqrt(-2.0 * log(u1)) * cos(TAU * u2)

func forward(inputs: PackedFloat64Array) -> PackedFloat64Array:
	activations.clear()
	var current := inputs
	activations.append(current.duplicate())

	for layer_idx in range(layers.size()):
		var prev_size := layer_sizes[layer_idx]
		var curr_size := layer_sizes[layer_idx + 1]
		var weights := layers[layer_idx]
		var bias := biases[layer_idx]
		var output := PackedFloat64Array()
		output.resize(curr_size)

		for j in range(curr_size):
			var sum := bias[j]
			for k in range(prev_size):
				sum += current[k] * weights[k * curr_size + j]
			if layer_idx < layers.size() - 1:
				output[j] = _leaky_relu(sum)
			else:
				output[j] = tanh(sum)
		current = output
		activations.append(current.duplicate())

	return current

func _leaky_relu(x: float) -> float:
	return x if x > 0 else x * 0.01

func get_weights_flat() -> PackedFloat64Array:
	var all_weights := PackedFloat64Array()
	for i in range(layers.size()):
		all_weights.append_array(layers[i])
		all_weights.append_array(biases[i])
	return all_weights

func set_weights_flat(flat: PackedFloat64Array) -> void:
	var offset := 0
	for i in range(layers.size()):
		var w_size := layers[i].size()
		for j in range(w_size):
			layers[i][j] = flat[offset + j]
		offset += w_size
		var b_size := biases[i].size()
		for j in range(b_size):
			biases[i][j] = flat[offset + j]
		offset += b_size

func get_total_weights() -> int:
	var total := 0
	for i in range(layers.size()):
		total += layers[i].size()
		total += biases[i].size()
	return total

func duplicate_network() -> NeuralNetwork:
	var nn := NeuralNetwork.new(layer_sizes.duplicate())
	nn.set_weights_flat(get_weights_flat())
	return nn

func mutate(rate: float = 0.05, strength: float = 0.1) -> void:
	for i in range(layers.size()):
		for j in range(layers[i].size()):
			if randf() < rate:
				layers[i][j] += _randn() * strength
		for j in range(biases[i].size()):
			if randf() < rate:
				biases[i][j] += _randn() * strength

static func crossover(parent_a: NeuralNetwork, parent_b: NeuralNetwork) -> NeuralNetwork:
	var child := NeuralNetwork.new(parent_a.layer_sizes.duplicate())
	var flat_a := parent_a.get_weights_flat()
	var flat_b := parent_b.get_weights_flat()
	var child_flat := PackedFloat64Array()
	child_flat.resize(flat_a.size())
	# Multi-point crossover for better genetic mixing
	var num_points := 3
	var points: Array[int] = [0]
	for _i in range(num_points):
		points.append(randi_range(1, flat_a.size() - 1))
	points.append(flat_a.size())
	points.sort()
	var use_a := true
	for p in range(points.size() - 1):
		for i in range(points[p], points[p + 1]):
			child_flat[i] = flat_a[i] if use_a else flat_b[i]
		use_a = !use_a
	child.set_weights_flat(child_flat)
	return child

func save_to_dict() -> Dictionary:
	return {
		"layer_sizes": layer_sizes,
		"weights": get_weights_flat()
	}

static func load_from_dict(data: Dictionary) -> NeuralNetwork:
	var sizes: Array[int] = []
	for s in data["layer_sizes"]:
		sizes.append(int(s))
	var nn := NeuralNetwork.new(sizes)
	var flat := PackedFloat64Array()
	for w in data["weights"]:
		flat.append(float(w))
	nn.set_weights_flat(flat)
	return nn
