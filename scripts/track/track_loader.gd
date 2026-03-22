class_name TrackLoader
extends RefCounted

static func load_track(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("Track file not found: " + path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()
	if err != OK:
		push_error("Failed to parse track: " + json.get_error_message())
		return {}
	return json.data

static func save_track(path: String, data: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write track file: " + path)
		return false
	var json_str := JSON.stringify(data, "  ")
	file.store_string(json_str)
	file.close()
	return true

static func validate_track(data: Dictionary) -> Dictionary:
	var errors: Array[String] = []

	if not data.has("tiles"):
		errors.append("No tile data")
		return {"valid": false, "errors": errors}

	if not data.has("start"):
		errors.append("No start position")

	if not data.has("checkpoints"):
		errors.append("No checkpoints")
	elif data["checkpoints"].size() < 1:
		errors.append("Need at least 1 checkpoint")

	var tiles: Array = data.get("tiles", [])
	var has_start := false
	var has_road := false
	for row in tiles:
		for tile in row:
			if int(tile) == 9:
				has_start = true
			if int(tile) == 1:
				has_road = true

	if not has_start:
		errors.append("No start tile (place a START tile)")
	if not has_road:
		errors.append("No road tiles")

	return {
		"valid": errors.is_empty(),
		"errors": errors,
	}
