extends CanvasLayer
class_name HUD

# Simplified HUD — top bar + compact stat + messages only

var top_bar: Panel
var stat_label: Label
var gen_label: Label
var brain_label: Label
var mode_label: Label
var message_label: Label
var message_timer: float = 0.0

var accent := Color(0.45, 0.72, 0.72)
var text_col := Color(0.78, 0.78, 0.85)
var dim_col := Color(0.36, 0.38, 0.46)
var bg_col := Color(0.05, 0.05, 0.09, 0.88)

func _ready() -> void:
	layer = 10
	_setup_top_bar()
	_setup_stat()
	_setup_message()

func _setup_top_bar() -> void:
	top_bar = Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = bg_col
	style.border_color = Color(0.14, 0.14, 0.20)
	style.border_width_bottom = 1
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	top_bar.add_theme_stylebox_override("panel", style)
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.custom_minimum_size.y = 36
	add_child(top_bar)

	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.offset_left = 10
	hbox.offset_right = -10
	hbox.offset_top = 4
	hbox.add_theme_constant_override("separation", 20)
	top_bar.add_child(hbox)

	mode_label = _label("Training", 15, accent)
	hbox.add_child(mode_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	gen_label = _label("Gen: 0", 13, text_col)
	hbox.add_child(gen_label)

	brain_label = _label("Alive: 15/15", 13, Color(0.50, 0.62, 0.78))
	hbox.add_child(brain_label)

func _setup_stat() -> void:
	stat_label = _label("", 12, Color(0.52, 0.62, 0.72))
	stat_label.anchor_left = 0.0
	stat_label.anchor_right = 1.0
	stat_label.anchor_top = 1.0
	stat_label.anchor_bottom = 1.0
	stat_label.offset_top = -24
	stat_label.offset_left = 10
	add_child(stat_label)

func _setup_message() -> void:
	message_label = _label("", 20, accent)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.anchor_left = 0.0
	message_label.anchor_right = 1.0
	message_label.offset_top = 48
	message_label.visible = false
	add_child(message_label)

func _label(text: String, sz: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", color)
	return l

func update_car_stat(drive_time: float, checkpoint: int, total_cp: int,
		distance: float, speed: float) -> void:
	stat_label.text = "CP: %d/%d  |  %.1fs  |  %.0f px/s" % [
		checkpoint, total_cp, drive_time, speed]

func update_generation(gen: int) -> void:
	gen_label.text = "Gen: %d" % gen

func update_brain_info(alive: int, total: int, gen: int) -> void:
	brain_label.text = "Alive: %d/%d" % [alive, total]
	gen_label.text = "Gen: %d" % gen

func update_mode(name: String) -> void:
	mode_label.text = name

func show_message(text: String, duration: float = 3.0) -> void:
	message_label.text = text
	message_label.visible = true
	message_timer = duration

func _process(delta: float) -> void:
	if message_timer > 0:
		message_timer -= delta
		if message_timer <= 0:
			message_label.visible = false
