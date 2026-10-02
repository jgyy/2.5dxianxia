extends Control

var game: Node
var font: Font = ThemeDB.fallback_font
var serif: Font
const INK = Color("101f27")
const JADE = Color("83d9be")
const GOLD = Color("ddbc80")
const PAPER = Color("ebe2cd")

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	serif = load("res://assets/fonts/serif.ttf") if ResourceLoader.exists("res://assets/fonts/serif.ttf") else font

func text_at(value: String, point: Vector2, size_px: int = 18, color: Color = PAPER, face: Font = null) -> void:
	draw_string(face if face else font, point, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)

func panel(rect: Rect2, alpha: float = 0.9) -> void:
	draw_rect(rect, Color(INK, alpha))
	draw_rect(rect, Color(GOLD, 0.4), false, 1)
	draw_line(rect.position, rect.position + Vector2(42, 0), GOLD, 2)

func bar(point: Vector2, width: float, ratio: float, color: Color) -> void:
	draw_rect(Rect2(point, Vector2(width, 5)), Color(0.8, 0.8, 0.8, .13))
	draw_rect(Rect2(point, Vector2(width * clampf(ratio, 0, 1), 5)), color)

func draw_avatar(rect: Rect2, animate: bool = true) -> void:
	if game.avatar_atlas == null:
		return
	var frame = int(game.elapsed * 3) % 2 if animate else 0
	if game.started and not game.modal:
		if game.player.velocity.length() > .2:
			frame = int(game.elapsed * 6) % 2 if animate else 1
		if game.swing_time > .2:
			frame = 2
	draw_texture_rect(game.avatar_frames[game.state.appearance_row() * 4 + frame], rect, false)

func draw_weapon(rect: Rect2) -> void:
	if game.weapon_atlas == null:
		return
	var cell = game.weapon_atlas.get_size() / 2
	var region = Rect2(Vector2((game.state.weapon % 2) * cell.x, int(game.state.weapon / 2) * cell.y), cell)
	draw_texture_rect_region(game.weapon_atlas, rect, region)

func draw_appearance() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(INK, .78))
	var box = Rect2(size / 2 - Vector2(430, 260), Vector2(860, 520))
	panel(box, .98)
	text_at("LIN YUE", box.position + Vector2(34, 54), 34, PAPER, serif)
	text_at("WANDERING CULTIVATOR   /   YOUR APPEARANCE", box.position + Vector2(35, 81), 11, JADE)
	draw_line(box.position + Vector2(34, 100), box.position + Vector2(826, 100), Color(GOLD, .35))
	draw_avatar(Rect2(box.position + Vector2(22, 115), Vector2(256, 300)))
	draw_weapon(Rect2(box.position + Vector2(165, 236), Vector2(108, 155)))
	var labels = [game.state.HAIRSTYLES[game.state.hair], game.state.CLOTHING[game.state.clothing], game.state.WEAPONS[game.state.weapon]]
	var captions = ["1   HAIRSTYLE", "2   CLOTHING", "3   WEAPON"]
	for i in range(3):
		var rect = Rect2(box.position + Vector2(302, 133 + i * 82), Vector2(506, 66))
		panel(rect, .6)
		text_at(captions[i], rect.position + Vector2(18, 22), 10, GOLD)
		text_at(labels[i], rect.position + Vector2(18, 48), 18, PAPER)
		text_at("NEXT  ›", rect.position + Vector2(410, 41), 12, JADE)
	text_at("16 hair / clothing combinations · 4 weapons", box.position + Vector2(302, 410), 13, JADE)
	text_at("Changes are saved with your journey (F5).", box.position + Vector2(302, 437), 12, PAPER)
	text_at("Click a choice or press 1 / 2 / 3 to cycle. ENTER / ESC closes.", box.position + Vector2(34, 488), 13, GOLD)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if game == null or game.player == null:
		return
	var w = size.x
	var h = size.y
	var state = game.state
	# Soft letterboxing and restrained editorial HUD.
	draw_rect(Rect2(0, 0, w, 74), Color(INK, .68))
	text_at("JADE MERIDIAN", Vector2(38, 37), 23, PAPER, serif)
	text_at("THE MOUNTAIN REMEMBERS", Vector2(39, 59), 10, GOLD)
	text_at(game.campaign.regions[int(game.campaign.current_region.trim_prefix("region_"))].name.to_upper(), Vector2(w - 285, 38), 13, GOLD)
	draw_line(Vector2(0, 74), Vector2(w, 74), Color(GOLD, .3))
	if game.modal_kind == "campaign":
		return
	if not game.started:
		draw_rect(Rect2(0, 74, w * .58, h - 74), Color(INK, .70))
		text_at("A FIRST-PERSON XIANXIA JOURNEY", Vector2(74, h * .3), 12, JADE)
		text_at("Ashes of the", Vector2(68, h * .3 + 77), 60, PAPER, serif)
		text_at("Jade Meridian", Vector2(68, h * .3 + 145), 60, PAPER, serif)
		draw_line(Vector2(74, h * .3 + 178), Vector2(190, h * .3 + 178), GOLD, 2)
		text_at("The immortal who saved your village is killing its mountain.", Vector2(74, h * .3 + 219), 16)
		text_at("Follow the jade light. Learn what he buried beneath it.", Vector2(74, h * .3 + 246), 16)
		panel(Rect2(74, h * .3 + 286, 290, 56), .9)
		text_at("ENTER   ·   BEGIN YOUR JOURNEY", Vector2(94, h * .3 + 321), 15, JADE)
		text_at("L   Continue saved journey     P   Customize Lin Yue", Vector2(74, h * .3 + 381), 13, GOLD)
		text_at("WASD  Move     MOUSE  Look     E  Interact", Vector2(74, h - 60), 13)
		text_at("LEFT CLICK  Sword     Q  Spirit art     C  Cultivate", Vector2(74, h - 37), 13)
		if game.modal_kind == "appearance":
			draw_appearance()
		return
	# Compass, objectives, status.
	var cardinal = ["N", "NW", "W", "SW", "S", "SE", "E", "NE"][posmod(int(round(game.player.yaw / (PI / 4))), 8)]
	text_at(cardinal, Vector2(w * .5 - 6, 107), 13, GOLD)
	var city_caption = game.city.location_caption(game.player.position)
	if city_caption != "":
		text_at(city_caption, Vector2(39, 91), 13, GOLD)
	if game.city.destination != "":
		text_at("ENTRANCE · %s · %d m" % [game.city.buildings[game.city.destination].name, game.player.position.distance_to(game.city.entrance(game.city.destination))], Vector2(40, 140), 13, JADE)
	draw_line(Vector2(w * .5, 117), Vector2(w * .5, 125), GOLD)
	panel(Rect2(w - 344, 104, 306, 104), .77)
	text_at("THE BROKEN OATH", Vector2(w - 325, 131), 12, GOLD)
	var objectives = game.objective_lines()
	for i in range(objectives.size()):
		text_at(objectives[i], Vector2(w - 325, 158 + i * 22), 14, PAPER)
	panel(Rect2(38, h - 143, 312, 106), .85)
	text_at(state.REALMS[state.realm].to_upper(), Vector2(57, h - 116), 12, GOLD)
	text_at("VITALITY", Vector2(57, h - 90), 10, PAPER)
	text_at("%d / %d" % [state.health, state.max_health()], Vector2(244, h - 90), 11)
	bar(Vector2(57, h - 80), 274, state.health / state.max_health(), Color("cd8070"))
	bar(Vector2(57, h - 64), 274, state.stamina / 100, JADE)
	text_at("QI  %03d     SEALS  %d / 3" % [state.qi, state.seals], Vector2(57, h - 46), 11, JADE)
	draw_avatar(Rect2(350, h - 151, 100, 114))
	text_at("LIN YUE", Vector2(360, h - 26), 10, GOLD)
	text_at("E  Interact   ·   C  Cultivate   ·   P  Appearance   ·   J  Journal   ·   M  Atlas   ·   N  City", Vector2(w * .5 - 255, h - 25), 11, Color(PAPER, .72))
	text_at("Q  SPIRIT PALM", Vector2(w - 172, h - 56), 12, JADE)
	text_at("LMB  " + state.WEAPONS[state.weapon].to_upper(), Vector2(w - 190, h - 35), 12, GOLD)
	# Crosshair.
	var center = Vector2(w / 2, h / 2)
	for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		draw_line(center + direction * 5, center + direction * 11, Color(PAPER, .7), 1)
	if game.prompt != "" and not game.modal:
		var width = font.get_string_size(game.prompt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 44
		panel(Rect2(w / 2 - width / 2, h * .65, width, 42), .85)
		text_at(game.prompt, Vector2(w / 2 - width / 2 + 22, h * .65 + 27), 15, JADE)
	if game.notice_time > 0:
		text_at(game.notice, Vector2(40, 114), 16, JADE)
	# ChatGPT-generated weapon art, selected with the protagonist's loadout.
	if not game.modal:
		var swing = sin(game.swing_time * PI) * 165.0
		draw_weapon(Rect2(w * .74 - swing, h - 370 + swing * .2, 310, 360))
	if game.damage_flash > 0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(.8, .1, .05, game.damage_flash * .25))
	if game.modal and game.modal_kind != "campaign":
		if game.modal_kind == "appearance":
			draw_appearance()
			return
		draw_rect(Rect2(Vector2.ZERO, size), Color(INK, .65))
		var box = Rect2(w / 2 - 360, h / 2 - 190, 720, 380)
		panel(box, .97)
		text_at(game.modal_title.to_upper(), box.position + Vector2(34, 47), 27, GOLD, serif)
		draw_line(box.position + Vector2(34, 64), box.position + Vector2(686, 64), Color(GOLD, .3))
		for i in range(game.modal_lines.size()):
			text_at(game.modal_lines[i], box.position + Vector2(34, 101 + i * 28), 16)
		text_at(game.modal_footer, box.position + Vector2(34, 347), 13, JADE)
