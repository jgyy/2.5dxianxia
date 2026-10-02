extends Control

var game: Node
var selected = "hero_000"
var angle = 0
var spinning = false
var clock = 0.0
var preview: TextureRect
var caption: Label
var roster: OptionButton
var grid: GridContainer
var all_views = true

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background = ColorRect.new()
	background.color = Color("101f27")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 32)
	add_child(margin)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	margin.add_child(column)
	var title = Label.new()
	title.text = "CHARACTER TURNTABLE"
	title.add_theme_font_size_override("font_size", 28)
	column.add_child(title)
	roster = OptionButton.new()
	for id in game.directional.characters:
		var character = game.directional.characters[id]
		roster.add_item(character.name + (" · " + str(int(id.trim_prefix("hero_")) + 1) if id.begins_with("hero_") else ""))
		roster.set_item_metadata(roster.item_count - 1, id)
		if id == selected:
			roster.select(roster.item_count - 1)
	roster.item_selected.connect(func(index): selected = roster.get_item_metadata(index); refresh())
	column.add_child(roster)
	preview = TextureRect.new()
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(preview)
	grid = GridContainer.new()
	grid.columns = 6
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(grid)
	for index in range(12):
		var cell = VBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.size_flags_vertical = Control.SIZE_EXPAND_FILL
		grid.add_child(cell)
		var drawing = TextureRect.new()
		drawing.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		drawing.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		drawing.custom_minimum_size = Vector2(100, 180)
		drawing.size_flags_vertical = Control.SIZE_EXPAND_FILL
		cell.add_child(drawing)
		var number = Label.new()
		number.text = "%d°" % (index * 30)
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(number)
	caption = Label.new()
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(caption)
	var controls = HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(controls)
	for entry in [["← Previous", -1], ["Rotate", 0], ["Next →", 1], ["All 12 views", 3], ["Close", 2]]:
		var button = Button.new()
		button.text = entry[0]
		var action: int = entry[1]
		button.pressed.connect(func():
			if action == 2: game.close_modal()
			elif action == 3: all_views = true; spinning = false; refresh()
			elif action == 0: spinning = not spinning; all_views = false; refresh()
			else: angle = posmod(angle + action, 12); all_views = false; refresh()
		)
		controls.add_child(button)
	var help = Label.new()
	help.text = "LEFT / RIGHT · Change view     SPACE · Rotate     ENTER / ESC · Close"
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(help)
	refresh()
	hide()

func open(id: String = "") -> void:
	if id != "" and game.directional.has_character(id):
		selected = id
	for index in range(roster.item_count):
		if roster.get_item_metadata(index) == selected:
			roster.select(index)
	angle = 0
	spinning = false
	all_views = true
	refresh()
	show()

func refresh() -> void:
	if preview == null:
		return
	preview.texture = game.directional.texture(selected, angle)
	preview.visible = not all_views
	grid.visible = all_views
	for index in range(12):
		grid.get_child(index).get_child(0).texture = game.directional.texture(selected, index)
	var names = ["Front", "Front left", "Front left", "Left side", "Back left", "Back left", "Back", "Back right", "Back right", "Right side", "Front right", "Front right"]
	caption.text = "%s · %d° · View %d / 12" % [names[angle], angle * 30, angle + 1]
	if all_views:
		caption.text = "Twelve views around the character · 30° steps"

func _process(delta: float) -> void:
	if not visible or not spinning:
		return
	clock += delta
	if clock >= .35:
		clock = fmod(clock, .35)
		angle = (angle + 1) % 12
		refresh()

func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not event.is_pressed():
		return
	if event.keycode == KEY_LEFT or event.keycode == KEY_RIGHT:
		all_views = false
		angle = posmod(angle + (-1 if event.keycode == KEY_LEFT else 1), 12)
		refresh()
	elif event.keycode == KEY_SPACE:
		all_views = false
		spinning = not spinning
		refresh()
	else:
		return
	get_viewport().set_input_as_handled()
