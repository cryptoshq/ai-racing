class_name TrackGenerator
extends RefCounted

# Procedural track generation — 5 difficulty levels, harder maps, variable road width

var tile_size: int = 32

func generate(difficulty_target: String = "Medium") -> Dictionary:
	var width: int = 32
	var height: int = 24
	var road_half_w: float = 60.0
	var road_tile_w: int = 2

	match difficulty_target:
		"Easy":
			width = 32; height = 24; road_half_w = 60.0; road_tile_w = 2
		"Medium":
			width = 36; height = 28; road_half_w = 50.0; road_tile_w = 2
		"Hard":
			width = 40; height = 30; road_half_w = 42.0; road_tile_w = 1
		"Expert":
			width = 44; height = 32; road_half_w = 35.0; road_tile_w = 1
		"Insane":
			width = 48; height = 36; road_half_w = 28.0; road_tile_w = 1

	var tiles: Array = []
	for y in range(height):
		var row: Array[int] = []
		row.resize(width)
		row.fill(2)
		tiles.append(row)

	var waypoints := _generate_waypoints(difficulty_target, width, height)
	var road_center := _draw_road_spline(tiles, waypoints, width, height, road_tile_w)
	_add_walls(tiles, width, height)

	var checkpoints := _place_checkpoints(waypoints, difficulty_target)

	var start_pos := waypoints[0]
	var start_dir := (waypoints[1] - waypoints[0]).normalized()
	var start_rot := atan2(start_dir.y, start_dir.x)
	var finish_pos := waypoints[waypoints.size() - 1]

	var sx := clampi(int(start_pos.x), 0, width - 1)
	var sy := clampi(int(start_pos.y), 0, height - 1)
	tiles[sy][sx] = 9

	var fx := clampi(int(finish_pos.x), 0, width - 1)
	var fy := clampi(int(finish_pos.y), 0, height - 1)
	tiles[fy][fx] = 10

	return {
		"name": _get_track_name(difficulty_target),
		"author": "Procedural",
		"difficulty": difficulty_target,
		"tile_size": tile_size,
		"width": width,
		"height": height,
		"tiles": tiles,
		"road_points": road_center,
		"road_half_width": road_half_w,
		"checkpoints": checkpoints,
		"start": {
			"x": start_pos.x * tile_size + tile_size * 0.5,
			"y": start_pos.y * tile_size + tile_size * 0.5,
			"rotation": start_rot
		},
		"finish": {
			"x": finish_pos.x * tile_size + tile_size * 0.5,
			"y": finish_pos.y * tile_size + tile_size * 0.5,
		},
		"obstacles": []
	}

func _get_track_name(diff: String) -> String:
	var names := {
		"Easy": ["Gentle Cruise", "Easy Drive", "Sunday Road", "Smooth Sailing", "Beginner's Path"],
		"Medium": ["Twisty Path", "Winding Way", "S-Curve Run", "Rolling Hills", "Coastal Drive"],
		"Hard": ["Switchback Pass", "Hairpin Hill", "Mountain Road", "Canyon Run", "Alpine Circuit"],
		"Expert": ["Zigzag Gauntlet", "Extreme Path", "Devil's Run", "Night Terror", "Razor's Edge"],
		"Insane": ["Death Spiral", "Needle Thread", "Chaos Circuit", "Impossible Run", "Brain Melter"],
	}
	var options: Array = names.get(diff, ["Track"])
	return options[randi() % options.size()]

func _generate_waypoints(difficulty: String, w: int, h: int) -> Array[Vector2]:
	var points: Array[Vector2] = []
	match difficulty:
		"Easy":
			points = _make_easy(w, h)
		"Medium":
			points = _make_medium(w, h)
		"Hard":
			points = _make_hard(w, h)
		"Expert":
			points = _make_expert(w, h)
		"Insane":
			points = _make_insane(w, h)
		_:
			points = _make_easy(w, h)
	return points

func _make_easy(w: int, h: int) -> Array[Vector2]:
	var points: Array[Vector2] = []
	var m := 3.0
	var fw := float(w)
	var fh := float(h)
	points.append(Vector2(m + 1, fh * 0.5))
	points.append(Vector2(fw * 0.2, fh * 0.32))
	points.append(Vector2(fw * 0.4, fh * 0.58))
	points.append(Vector2(fw * 0.6, fh * 0.38))
	points.append(Vector2(fw * 0.8, fh * 0.62))
	points.append(Vector2(fw - m - 1, fh * 0.5))
	return points

func _make_medium(w: int, h: int) -> Array[Vector2]:
	var points: Array[Vector2] = []
	var m := 3.0
	var fw := float(w)
	var fh := float(h)
	points.append(Vector2(m + 1, fh * 0.8))
	points.append(Vector2(fw * 0.18, fh * 0.25))
	points.append(Vector2(fw * 0.35, fh * 0.75))
	points.append(Vector2(fw * 0.48, fh * 0.18))
	points.append(Vector2(fw * 0.62, fh * 0.7))
	points.append(Vector2(fw * 0.75, fh * 0.25))
	points.append(Vector2(fw * 0.88, fh * 0.6))
	points.append(Vector2(fw - m - 1, fh * 0.4))
	return points

func _make_hard(w: int, h: int) -> Array[Vector2]:
	var points: Array[Vector2] = []
	var m := 3.0
	var fw := float(w)
	var fh := float(h)
	points.append(Vector2(m + 1, fh - m - 2))
	points.append(Vector2(fw * 0.25, fh * 0.85))
	points.append(Vector2(fw * 0.65, fh - m - 2))
	points.append(Vector2(fw - m - 1, fh * 0.72))
	points.append(Vector2(fw * 0.7, fh * 0.55))
	points.append(Vector2(fw * 0.3, fh * 0.52))
	points.append(Vector2(m + 2, fh * 0.38))
	points.append(Vector2(fw * 0.35, fh * 0.2))
	points.append(Vector2(fw * 0.65, fh * 0.28))
	points.append(Vector2(fw - m - 1, fh * 0.12))
	return points

func _make_expert(w: int, h: int) -> Array[Vector2]:
	var points: Array[Vector2] = []
	var m := 3.0
	var fw := float(w)
	var fh := float(h)
	points.append(Vector2(m + 1, fh - m - 2))
	points.append(Vector2(fw * 0.22, fh * 0.88))
	points.append(Vector2(fw * 0.5, fh * 0.92))
	points.append(Vector2(fw - m - 1, fh * 0.82))
	points.append(Vector2(fw * 0.78, fh * 0.65))
	points.append(Vector2(fw * 0.35, fh * 0.6))
	points.append(Vector2(m + 2, fh * 0.48))
	points.append(Vector2(fw * 0.3, fh * 0.35))
	points.append(Vector2(fw * 0.65, fh * 0.42))
	points.append(Vector2(fw - m - 1, fh * 0.28))
	points.append(Vector2(fw * 0.6, fh * 0.15))
	points.append(Vector2(fw * 0.25, fh * 0.1))
	return points

func _make_insane(w: int, h: int) -> Array[Vector2]:
	var points: Array[Vector2] = []
	var m := 3.0
	var fw := float(w)
	var fh := float(h)
	points.append(Vector2(m + 1, fh - m - 2))
	points.append(Vector2(fw * 0.15, fh * 0.85))
	points.append(Vector2(fw * 0.35, fh * 0.92))
	points.append(Vector2(fw * 0.55, fh * 0.82))
	points.append(Vector2(fw - m - 1, fh * 0.88))
	points.append(Vector2(fw * 0.85, fh * 0.7))
	points.append(Vector2(fw * 0.55, fh * 0.65))
	points.append(Vector2(fw * 0.25, fh * 0.7))
	points.append(Vector2(m + 2, fh * 0.55))
	points.append(Vector2(fw * 0.2, fh * 0.42))
	points.append(Vector2(fw * 0.45, fh * 0.48))
	points.append(Vector2(fw * 0.7, fh * 0.38))
	points.append(Vector2(fw - m - 1, fh * 0.25))
	points.append(Vector2(fw * 0.72, fh * 0.12))
	points.append(Vector2(fw * 0.4, fh * 0.08))
	points.append(Vector2(fw * 0.15, fh * 0.15))
	points.append(Vector2(m + 2, m + 2))
	return points

func _draw_road_spline(tiles: Array, waypoints: Array[Vector2], w: int, h: int, road_width: int = 2) -> PackedVector2Array:
	var raw_points := PackedVector2Array()

	for i in range(waypoints.size() - 1):
		var p0 := waypoints[maxi(i - 1, 0)]
		var p1 := waypoints[i]
		var p2 := waypoints[i + 1]
		var p3 := waypoints[mini(i + 2, waypoints.size() - 1)]

		var steps := int(p1.distance_to(p2) * 3)
		steps = maxi(steps, 10)
		for s in range(steps + 1):
			var t := float(s) / steps
			var pos := _catmull_rom(p0, p1, p2, p3, t)

			raw_points.append(Vector2(
				pos.x * tile_size + tile_size * 0.5,
				pos.y * tile_size + tile_size * 0.5))

			for dx in range(-road_width, road_width + 1):
				for dy in range(-road_width, road_width + 1):
					var tx := int(pos.x) + dx
					var ty := int(pos.y) + dy
					if tx >= 0 and tx < w and ty >= 0 and ty < h:
						if Vector2(dx, dy).length() <= road_width:
							tiles[ty][tx] = 1

	var thinned := PackedVector2Array()
	if raw_points.size() > 0:
		thinned.append(raw_points[0])
		for i in range(1, raw_points.size()):
			if raw_points[i].distance_to(thinned[thinned.size() - 1]) >= 6.0:
				thinned.append(raw_points[i])
		var last_pt := raw_points[raw_points.size() - 1]
		if thinned[thinned.size() - 1].distance_to(last_pt) > 1.0:
			thinned.append(last_pt)
	return thinned

func _catmull_rom(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * (
		(2.0 * p1) +
		(-p0 + p2) * t +
		(2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 +
		(-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
	)

func _add_walls(tiles: Array, w: int, h: int) -> void:
	var wall_tiles: Array[Vector2i] = []
	for y in range(h):
		for x in range(w):
			if tiles[y][x] == 1:
				for dx in [-1, 0, 1]:
					for dy in [-1, 0, 1]:
						if dx == 0 and dy == 0:
							continue
						var nx: int = x + dx
						var ny: int = y + dy
						if nx >= 0 and nx < w and ny >= 0 and ny < h:
							if tiles[ny][nx] == 2:
								wall_tiles.append(Vector2i(nx, ny))

	for wt in wall_tiles:
		var road_count := 0
		for dx in [-1, 0, 1]:
			for dy in [-1, 0, 1]:
				var nx: int = wt.x + dx
				var ny: int = wt.y + dy
				if nx >= 0 and nx < w and ny >= 0 and ny < h:
					if tiles[ny][nx] == 1:
						road_count += 1
		if road_count >= 1 and road_count <= 5:
			tiles[wt.y][wt.x] = 3

func _place_checkpoints(waypoints: Array[Vector2], difficulty: String = "Medium") -> Array[Dictionary]:
	var checkpoints: Array[Dictionary] = []
	var num := 5
	match difficulty:
		"Easy": num = 5
		"Medium": num = 6
		"Hard": num = 7
		"Expert": num = 8
		"Insane": num = 10
	num = mini(num, waypoints.size() - 1)
	for i in range(num):
		var frac := float(i + 1) / float(num)
		var wp_idx := int(frac * float(waypoints.size() - 1))
		wp_idx = clampi(wp_idx, 1, waypoints.size() - 1)
		var pos := waypoints[wp_idx]
		checkpoints.append({
			"x": pos.x * tile_size + tile_size * 0.5,
			"y": pos.y * tile_size + tile_size * 0.5,
			"index": i
		})
	return checkpoints
