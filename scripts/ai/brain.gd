class_name AIBrain
extends RefCounted

# Neuroevolution brain — improved fitness with speed, drift, and progress rewards

var network: NeuralNetwork
var fitness: float = 0.0
var total_distance: float = 0.0
var checkpoints_hit: int = 0
var collision_count: int = 0
var generation: int = 0
var finished: bool = false
var finish_time: float = INF
var time_alive: float = 0.0
var grass_time: float = 0.0
var checkpoint_progress: float = 0.0
var max_speed_reached: float = 0.0
var drift_time: float = 0.0

func _init(nn: NeuralNetwork = null) -> void:
	if nn:
		network = nn
	else:
		network = NeuralNetwork.new([18, 48, 32, 16, 4])

func calculate_fitness() -> float:
	fitness = 0.0
	# Checkpoints are the primary reward
	fitness += checkpoints_hit * 2000.0
	# Partial credit for approaching next checkpoint
	fitness += clampf(checkpoint_progress, 0.0, 1.0) * 800.0
	# Finish bonus with time reward
	if finished:
		fitness += 10000.0
		fitness += maxf(0.0, 5000.0 - finish_time * 50.0)
	# Speed reward — cars that drive fast get more fitness
	if time_alive > 0.5:
		var speed_score := total_distance / time_alive
		fitness += speed_score * 0.8
	# Max speed bonus
	fitness += max_speed_reached * 0.3
	# Distance (mild)
	fitness += total_distance * 0.01
	# Alive bonus (capped)
	fitness += minf(time_alive, 20.0) * 5.0
	# Drift bonus (reward controlled drifting)
	fitness += minf(drift_time, 5.0) * 10.0
	# Penalties
	fitness -= collision_count * 15.0
	fitness -= grass_time * 3.0
	fitness = maxf(0.0, fitness)
	return fitness

func reset_episode() -> void:
	total_distance = 0.0
	checkpoints_hit = 0
	collision_count = 0
	finished = false
	finish_time = INF
	time_alive = 0.0
	grass_time = 0.0
	checkpoint_progress = 0.0
	max_speed_reached = 0.0
	drift_time = 0.0

func duplicate_brain() -> AIBrain:
	var b := AIBrain.new(network.duplicate_network())
	b.generation = generation
	return b

func get_action(state: PackedFloat64Array) -> PackedFloat64Array:
	return network.forward(state)
