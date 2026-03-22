class_name Evolution
extends RefCounted

var population: Array[AIBrain] = []
var population_size: int = 15
var elitism_count: int = 3
var breeding_pool_size: int = 8
var mutation_rate: float = 0.12
var mutation_strength: float = 0.20
var generation: int = 0
var best_fitness_history: Array[float] = []
var avg_fitness_history: Array[float] = []

# Adaptive mutation
var base_mutation_rate: float = 0.12
var base_mutation_strength: float = 0.20
var stagnation_counter: int = 0

func _init(pop_size: int = 15) -> void:
	population_size = pop_size
	elitism_count = maxi(2, pop_size / 4)
	breeding_pool_size = maxi(4, pop_size * 2 / 3)
	_create_initial_population()

func _create_initial_population() -> void:
	population.clear()
	for i in range(population_size):
		var brain := AIBrain.new()
		brain.generation = 0
		population.append(brain)

func evolve() -> void:
	generation += 1
	for brain in population:
		brain.calculate_fitness()

	population.sort_custom(func(a: AIBrain, b: AIBrain) -> bool:
		return a.fitness > b.fitness
	)

	var best_f := population[0].fitness if population.size() > 0 else 0.0
	var avg_f := 0.0
	for brain in population:
		avg_f += brain.fitness
	if population.size() > 0:
		avg_f /= population.size()

	best_fitness_history.append(best_f)
	avg_fitness_history.append(avg_f)

	_adapt_mutation()

	var new_population: Array[AIBrain] = []

	# Elitism — keep best unchanged
	for i in range(mini(elitism_count, population.size())):
		var elite := population[i].duplicate_brain()
		elite.generation = generation
		elite.reset_episode()
		new_population.append(elite)

	# Mutated elites — slightly mutated copies of the best
	var mutated_elite_count := mini(2, population_size - elitism_count)
	for i in range(mutated_elite_count):
		var elite := population[i % maxi(1, elitism_count)].duplicate_brain()
		elite.network.mutate(mutation_rate * 0.5, mutation_strength * 0.5)
		elite.generation = generation
		elite.reset_episode()
		new_population.append(elite)

	# Breeding
	var children_needed := population_size - new_population.size()
	for i in range(children_needed):
		var parent_a := _tournament_select()
		var parent_b := _tournament_select()
		var attempts := 0
		while parent_b == parent_a and attempts < 10:
			parent_b = _tournament_select()
			attempts += 1
		var child_network := NeuralNetwork.crossover(parent_a.network, parent_b.network)
		child_network.mutate(mutation_rate, mutation_strength)
		var child := AIBrain.new(child_network)
		child.generation = generation
		new_population.append(child)

	population = new_population

func _adapt_mutation() -> void:
	if best_fitness_history.size() >= 2:
		var current_best: float = best_fitness_history[best_fitness_history.size() - 1]
		var prev_best: float = best_fitness_history[best_fitness_history.size() - 2]
		if current_best <= prev_best * 1.01:
			stagnation_counter += 1
		else:
			stagnation_counter = maxi(0, stagnation_counter - 1)

	if stagnation_counter >= 8:
		# Heavy stagnation — big mutation burst
		mutation_rate = minf(base_mutation_rate * 3.0, 0.35)
		mutation_strength = minf(base_mutation_strength * 3.0, 0.6)
	elif stagnation_counter >= 5:
		mutation_rate = minf(base_mutation_rate * 2.0, 0.25)
		mutation_strength = minf(base_mutation_strength * 2.0, 0.4)
	elif stagnation_counter >= 3:
		mutation_rate = base_mutation_rate * 1.5
		mutation_strength = base_mutation_strength * 1.5
	else:
		# Gradually decrease mutation for refinement
		var gen_factor := 1.0 / (1.0 + float(generation) * 0.015)
		mutation_rate = maxf(base_mutation_rate * gen_factor, 0.03)
		mutation_strength = maxf(base_mutation_strength * gen_factor, 0.06)

func _tournament_select(tournament_size: int = 3) -> AIBrain:
	var best: AIBrain = null
	for _i in range(tournament_size):
		var idx := randi() % mini(breeding_pool_size, population.size())
		var candidate := population[idx]
		if best == null or candidate.fitness > best.fitness:
			best = candidate
	return best

func get_best_brain() -> AIBrain:
	if population.is_empty():
		return null
	var best := population[0]
	for brain in population:
		if brain.fitness > best.fitness:
			best = brain
	return best

func get_stats() -> Dictionary:
	var avg_fitness := 0.0
	var best_fitness := -INF
	for brain in population:
		avg_fitness += brain.fitness
		best_fitness = max(best_fitness, brain.fitness)
	if population.size() > 0:
		avg_fitness /= population.size()
	return {
		"generation": generation,
		"avg_fitness": avg_fitness,
		"best_fitness": best_fitness,
		"population_size": population.size(),
		"mutation_rate": mutation_rate,
		"mutation_strength": mutation_strength,
		"stagnation": stagnation_counter,
		"best_history": best_fitness_history,
		"avg_history": avg_fitness_history,
	}
