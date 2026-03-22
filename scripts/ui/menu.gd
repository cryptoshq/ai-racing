extends CanvasLayer
class_name MainMenu

signal mode_selected(mode: String)
signal track_selected(track_data: Dictionary)

# Palette
const BG = Color(0.05, 0.05, 0.09)
const CARD_BG = Color(0.09, 0.09, 0.14)
const CARD_HOVER = Color(0.12, 0.12, 0.19)
const CARD_SELECTED = Color(0.10, 0.13, 0.22)
const ACCENT = Color(0.45, 0.72, 0.72)
const WARM = Color(0.82, 0.62, 0.38)
const GREEN = Color(0.42, 0.76, 0.48)
const TEXT = Color(0.78, 0.78, 0.85)
const TEXT_DIM = Color(0.36, 0.38, 0.46)
const BORDER = Color(0.14, 0.14, 0.20)

var track_options: Array[Dictionary] = []
var selected_index: int = 0
var is_visible: bool = true
var car_count: int = 15

func _ready() -> void:
	layer = 100
	_generate_tracks()
	_build_menu()

func _generate_tracks() -> void:
	track_options.clear()
	var gen := TrackGenerator.new()
	for diff in ["Easy", "Medium", "Hard", "Expert", "Insane"]:
		var data := gen.generate(diff)
		var tex := _create_preview(data)
		track_options.append({"data": data, "texture": tex})

func _create_preview(data: Dictionary) -> ImageTexture:
	var road_pts = data.get("road_points", PackedVector2Array())
	var ts: int = data.get("tile_size", 32)
	var map_w: float = float(data.get("width", 32)) * float(ts)
	var map_h: float = float(data.get("height", 24)) * float(ts)
	var rhw: float = data.get("road_half_width", 60.0)

	var pw := 140
	var ph := 100
	var sx := float(pw) / map_w
	var sy := float(ph) / map_h

	var img := Image.create(pw, ph, false, Image.FORMAT_RGBA8)

	# Dark background
	for y in range(ph):
		for x in range(pw):
			img.set_pixel(x, y, Color(0.12, 0.14, 0.10))

	if road_pts is PackedVector2Array and road_pts.size() > 0:
		var road_r: int = maxi(int(rhw * sx), 3)
		var curb_r: int = road_r + 2
		var sand_r: int = curb_r + 2

		_paint_path(img, road_pts, sx, sy, sand_r, Color(0.68, 0.56, 0.34), pw, ph)
		_paint_path(img, road_pts, sx, sy, curb_r, Color(0.75, 0.20, 0.15), pw, ph)
		_paint_path(img, road_pts, sx, sy, road_r, Color(0.38, 0.38, 0.42), pw, ph)

		# Start dot
		_paint_dot(img, int(road_pts[0].x * sx), int(road_pts[0].y * sy),
			3, Color(0.92, 0.72, 0.25), pw, ph)
		# Finish dot
		var last_pt: Vector2 = road_pts[road_pts.size() - 1]
		_paint_dot(img, int(last_pt.x * sx), int(last_pt.y * sy),
			3, Color(0.32, 0.85, 0.42), pw, ph)
	else:
		var tiles: Array = data.get("tiles", [])
		var th := tiles.size()
		var tw: int = tiles[0].size() if th > 0 else 0
		var tscale_x := float(pw) / float(tw) if tw > 0 else 1.0
		var tscale_y := float(ph) / float(th) if th > 0 else 1.0
		for y in range(th):
			for x in range(tw):
				var tid: int = int(tiles[y][x])
				var c := Color(0.12, 0.14, 0.10)
				match tid:
					1: c = Color(0.38, 0.38, 0.42)
					3: c = Color(0.12, 0.12, 0.18)
					9: c = Color(0.92, 0.72, 0.28)
					10: c = Color(0.32, 0.85, 0.42)
				if tid >= 4 and tid <= 8:
					c = Color(0.35, 0.62, 0.68)
				for py in range(int(y * tscale_y), int((y + 1) * tscale_y)):
					for px_i in range(int(x * tscale_x), int((x + 1) * tscale_x)):
						if px_i >= 0 and px_i < pw and py >= 0 and py < ph:
							img.set_pixel(px_i, py, c)

	return ImageTexture.create_from_image(img)

func _paint_path(img: Image, pts: PackedVector2Array, sx_f: float, sy_f: float,
		radius: int, color: Color, w: int, h: int) -> void:
	var step := maxi(1, pts.size() / 80)
	for idx in range(0, pts.size(), step):
		var px: int = int(pts[idx].x * sx_f)
		var py: int = int(pts[idx].y * sy_f)
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				if dx * dx + dy * dy <= radius * radius:
					var nx := px + dx
					var ny := py + dy
					if nx >= 0 and nx < w and ny >= 0 and ny < h:
						img.set_pixel(nx, ny, color)

func _paint_dot(img: Image, cx: int, cy: int, radius: int, color: Color,
		w: int, h: int) -> void:
	for dx in range(-radius, radius + 1):
		for dy in range(-radius, radius + 1):
			if dx * dx + dy * dy <= radius * radius:
				var nx := cx + dx
				var ny := cy + dy
				if nx >= 0 and nx < w and ny >= 0 and ny < h:
					img.set_pixel(nx, ny, color)

func _build_menu() -> void:
	for child in get_children():
		child.queue_free()

	var bg := Panel.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = BG
	bg.add_theme_stylebox_override("panel", bg_style)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	center.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "AI Racing"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", ACCENT)
	vbox.add_child(title)

	var sub := Label.new()
	sub.text = "watch an ai learn to drive"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", TEXT_DIM)
	vbox.add_child(sub)

	_spacer(vbox, 4)

	# Track cards — 5 difficulties
	var cards_row := HBoxContainer.new()
	cards_row.add_theme_constant_override("separation", 8)
	cards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(cards_row)

	for i in range(track_options.size()):
		cards_row.add_child(_create_card(i))

	# Refresh
	var refresh_row := HBoxContainer.new()
	refresh_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(refresh_row)

	var refresh_btn := Button.new()
	refresh_btn.text = "new tracks"
	refresh_btn.add_theme_font_size_override("font_size", 12)
	refresh_btn.add_theme_color_override("font_color", TEXT_DIM)
	var flat := StyleBoxFlat.new()
	flat.bg_color = Color(0, 0, 0, 0)
	refresh_btn.add_theme_stylebox_override("normal", flat)
	var flat_h := flat.duplicate()
	flat_h.bg_color = Color(1, 1, 1, 0.04)
	refresh_btn.add_theme_stylebox_override("hover", flat_h)
	refresh_btn.pressed.connect(func():
		_generate_tracks()
		_build_menu()
	)
	refresh_row.add_child(refresh_btn)

	_spacer(vbox, 2)

	# Car count
	var count_row := HBoxContainer.new()
	count_row.alignment = BoxContainer.ALIGNMENT_CENTER
	count_row.add_theme_constant_override("separation", 10)
	vbox.add_child(count_row)

	var minus_btn := _small_btn("-", func():
		car_count = maxi(1, car_count - 5)
		_build_menu()
	)
	count_row.add_child(minus_btn)

	var count_lbl := _label("Cars: %d" % car_count, 14, ACCENT)
	count_lbl.custom_minimum_size.x = 80
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_row.add_child(count_lbl)

	var plus_btn := _small_btn("+", func():
		car_count = mini(50, car_count + 5)
		_build_menu()
	)
	count_row.add_child(plus_btn)

	_spacer(vbox, 2)

	# Action buttons
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 14)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	btn_row.add_child(_action_btn("Train AI", ACCENT, func(): _start("training")))
	btn_row.add_child(_action_btn("Free Drive", WARM, func(): _start("drive")))
	btn_row.add_child(_action_btn("Track Editor", GREEN, func(): _start("editor")))

func _create_card(idx: int) -> Button:
	var data: Dictionary = track_options[idx]["data"]
	var tex: ImageTexture = track_options[idx]["texture"]
	var sel := idx == selected_index

	var card := Button.new()
	card.text = ""
	card.custom_minimum_size = Vector2(140, 148)

	var style := StyleBoxFlat.new()
	style.bg_color = CARD_SELECTED if sel else CARD_BG
	style.border_color = ACCENT if sel else BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	card.add_theme_stylebox_override("normal", style)

	var hover := style.duplicate()
	hover.bg_color = CARD_HOVER
	card.add_theme_stylebox_override("hover", hover)

	var pressed := style.duplicate()
	pressed.bg_color = CARD_SELECTED
	pressed.border_color = ACCENT
	card.add_theme_stylebox_override("pressed", pressed)

	card.pressed.connect(func(): _select(idx))

	var content := VBoxContainer.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 6
	content.offset_right = -6
	content.offset_top = 6
	content.offset_bottom = -6
	content.add_theme_constant_override("separation", 4)
	card.add_child(content)

	if tex:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.custom_minimum_size = Vector2(124, 86)
		tr.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		content.add_child(tr)

	var name_lbl := Label.new()
	name_lbl.text = data.get("name", "Track")
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.add_theme_color_override("font_color", TEXT if sel else Color(0.55, 0.55, 0.62))
	content.add_child(name_lbl)

	var diff_lbl := Label.new()
	diff_lbl.text = data.get("difficulty", "")
	diff_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	diff_lbl.add_theme_font_size_override("font_size", 10)
	var dc := TEXT_DIM
	match data.get("difficulty", ""):
		"Easy": dc = GREEN
		"Medium": dc = WARM
		"Hard": dc = Color(0.82, 0.42, 0.32)
		"Expert": dc = Color(0.72, 0.32, 0.62)
		"Insane": dc = Color(0.90, 0.25, 0.25)
	diff_lbl.add_theme_color_override("font_color", dc)
	content.add_child(diff_lbl)

	return card

func _small_btn(text: String, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(36, 36)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.18)
	style.border_color = BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("normal", style)

	var hover := style.duplicate()
	hover.bg_color = Color(0.18, 0.18, 0.26)
	hover.border_color = ACCENT
	btn.add_theme_stylebox_override("hover", hover)

	var pressed := style.duplicate()
	pressed.bg_color = Color(0.22, 0.22, 0.30)
	btn.add_theme_stylebox_override("pressed", pressed)

	btn.add_theme_color_override("font_color", TEXT)
	btn.add_theme_font_size_override("font_size", 18)
	btn.pressed.connect(callback)
	return btn

func _action_btn(text: String, color: Color, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(140, 42)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(color.r * 0.12, color.g * 0.12, color.b * 0.12)
	style.border_color = Color(color.r * 0.45, color.g * 0.45, color.b * 0.45)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("normal", style)

	var hover := style.duplicate()
	hover.bg_color = Color(color.r * 0.22, color.g * 0.22, color.b * 0.22)
	hover.border_color = color
	btn.add_theme_stylebox_override("hover", hover)

	var pressed := style.duplicate()
	pressed.bg_color = Color(color.r * 0.32, color.g * 0.32, color.b * 0.32)
	btn.add_theme_stylebox_override("pressed", pressed)

	btn.add_theme_color_override("font_color", color)
	btn.add_theme_font_size_override("font_size", 15)
	btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.pressed.connect(callback)
	return btn

func _label(text: String, sz: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", color)
	return l

func _spacer(parent: VBoxContainer, h: int) -> void:
	var s := Control.new()
	s.custom_minimum_size.y = h
	parent.add_child(s)

func _select(idx: int) -> void:
	selected_index = idx
	_build_menu()

func _start(mode: String) -> void:
	if mode != "editor" and track_options.size() > selected_index:
		emit_signal("track_selected", track_options[selected_index]["data"])
	emit_signal("mode_selected", mode)
	hide_menu()

func show_menu() -> void:
	visible = true
	is_visible = true

func hide_menu() -> void:
	visible = false
	is_visible = false
