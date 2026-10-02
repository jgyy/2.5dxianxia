extends Control

const PAPER = Color("ebe2cd")
const GOLD = Color("ddbc80")
const JADE = Color("83d9be")
var game: Node
var mode = "quests"
var owner_filter = ""
var ids: Array[String] = []
var selected = ""
var entries: ItemList
var search: LineEdit
var heading: Label
var subtitle: Label
var portrait: TextureRect
var reader: RichTextLabel
var accept_button: Button
var claim_button: Button
var power_button: Button
var abandon_button: Button
var travel_button: Button
var summary: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade = ColorRect.new()
	shade.color = Color(.025,.065,.08,.9)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left","right"]:
		margin.add_theme_constant_override("margin_"+edge,42)
	margin.add_theme_constant_override("margin_top",94)
	margin.add_theme_constant_override("margin_bottom",44)
	add_child(margin)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation",14)
	margin.add_child(box)
	var top = HBoxContainer.new()
	box.add_child(top)
	var title = Label.new()
	title.text = "THE MOUNTAIN'S ACCOUNTS"
	title.add_theme_color_override("font_color",GOLD)
	title.add_theme_font_override("font",load("res://assets/fonts/serif.ttf"))
	title.add_theme_font_size_override("font_size",29)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var close = button("Return · Esc",top)
	close.pressed.connect(game.close_modal)
	var tabs = HBoxContainer.new()
	tabs.add_theme_constant_override("separation",10)
	box.add_child(tabs)
	for tab in [["quests","Quest chapters"],["active","Active accounts"],["npcs","People"],["monsters","Bestiary"],["map","Travel atlas"],["city","Cloudrest city"]]:
		var b = button(tab[1],tabs)
		b.pressed.connect(func(): mode=tab[0]; owner_filter=""; selected=""; search.text=""; refresh())
	summary = Label.new()
	summary.add_theme_color_override("font_color",JADE)
	box.add_child(summary)
	var columns = HBoxContainer.new()
	columns.add_theme_constant_override("separation",24)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(columns)
	var left = VBoxContainer.new()
	left.custom_minimum_size.x = 340
	columns.add_child(left)
	search = LineEdit.new()
	search.placeholder_text = "Find a name, chapter, or region…"
	left.add_child(search)
	search.text_changed.connect(func(_value): selected=""; refresh())
	entries = ItemList.new()
	entries.size_flags_vertical = Control.SIZE_EXPAND_FILL
	entries.add_theme_font_size_override("font_size",15)
	entries.add_theme_constant_override("v_separation",10)
	entries.add_theme_color_override("font_color",PAPER)
	left.add_child(entries)
	entries.item_selected.connect(func(index): selected=ids[index]; show_entry())
	var right = VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(right)
	var profile = HBoxContainer.new()
	right.add_child(profile)
	portrait = TextureRect.new()
	portrait.custom_minimum_size = Vector2(140,140)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	profile.add_child(portrait)
	var names = VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	profile.add_child(names)
	heading = Label.new()
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.add_theme_font_override("font",load("res://assets/fonts/serif.ttf"))
	heading.add_theme_font_size_override("font_size",26)
	heading.add_theme_color_override("font_color",GOLD)
	names.add_child(heading)
	subtitle = Label.new()
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_color_override("font_color",JADE)
	names.add_child(subtitle)
	reader = RichTextLabel.new()
	reader.size_flags_vertical = Control.SIZE_EXPAND_FILL
	reader.selection_enabled = true
	reader.scroll_active = true
	reader.add_theme_font_size_override("normal_font_size",18)
	reader.add_theme_color_override("default_color",PAPER)
	reader.add_theme_constant_override("line_separation",6)
	right.add_child(reader)
	var actions = HBoxContainer.new()
	right.add_child(actions)
	accept_button = button("Accept chapter",actions)
	claim_button = button("Return account",actions)
	power_button = button("Inherit strength",actions)
	abandon_button = button("Abandon",actions)
	travel_button = button("Travel here",actions)
	accept_button.pressed.connect(func(): game.accept_quest(selected); refresh())
	claim_button.pressed.connect(func(): game.claim_quest(selected,"mercy"); refresh())
	power_button.pressed.connect(func(): game.claim_quest(selected,"power"); refresh())
	abandon_button.pressed.connect(func(): game.campaign.abandon(selected); refresh())
	travel_button.pressed.connect(func():
		if mode == "city": game.city.mark_building(selected)
		else: game.travel(selected))
	hide()

func button(caption: String, parent: Control) -> Button:
	var b = Button.new()
	b.text = caption
	b.custom_minimum_size.y = 38
	b.add_theme_font_size_override("font_size",15)
	b.add_theme_color_override("font_color",GOLD)
	parent.add_child(b)
	return b

func open(tab: String, owner: String = "") -> void:
	mode = tab
	owner_filter = owner
	selected = ""
	search.text = ""
	show()
	refresh()

func region_name(id: String) -> String:
	for r in game.campaign.regions:
		if r.id == id:
			return r.name
	return "Unknown region"

func refresh() -> void:
	entries.clear()
	ids.clear()
	var c = game.campaign
	summary.text = "%s  ·  %d active / 6  ·  %d chapters completed  ·  Scroll to read the full account" % [region_name(c.current_region),c.active.size(),c.completed.size()]
	var needle = search.text.strip_edges().to_lower()
	if mode == "city":
		summary.text = "Cloudrest · 12 buildings · 36 furnished floors · 40 residents · Mark an entrance to find it on foot"
		for id in game.city.buildings:
			var building = game.city.buildings[id]
			var searchable = building.name + " " + building.district + " " + game.city.directory_text(id)
			if needle != "" and needle not in searchable.to_lower():
				continue
			entries.add_item(building.name)
			ids.append(id)
	elif mode in ["quests","active"]:
		for id in c.quests:
			var q = c.quests[id]
			if owner_filter != "" and q.owner != owner_filter:
				continue
			if mode == "active" and not c.active.has(id):
				continue
			var name_value = q.title
			if c.completed.has(id):
				name_value = "✓ " + name_value
			elif c.active.has(id):
				name_value = "%d/%d  %s" % [c.active[id],q.objective.count,name_value]
			elif q.previous != "" and not c.completed.has(q.previous):
				name_value = "· " + name_value
			if needle != "" and needle not in (name_value+" "+region_name(q.region)).to_lower():
				continue
			entries.add_item(name_value)
			ids.append(id)
	elif mode in ["npcs","monsters"]:
		var people = c.npcs if mode == "npcs" else c.monsters
		for id in people:
			var person = people[id]
			var name_value = person.name+" · "+region_name(person.region)
			if needle != "" and needle not in name_value.to_lower():
				continue
			entries.add_item(name_value)
			ids.append(id)
	else:
		for region in c.regions:
			if needle != "" and needle not in region.name.to_lower():
				continue
			entries.add_item(region.name+(" · here" if region.id==c.current_region else ""))
			ids.append(region.id)
	if selected not in ids:
		selected = ids[0] if not ids.is_empty() else ""
	if selected != "":
		entries.select(ids.find(selected))
	show_entry()

func show_entry() -> void:
	for b in [accept_button,claim_button,power_button,abandon_button,travel_button]:
		b.hide()
	portrait.hide()
	reader.scroll_to_line(0)
	if selected == "":
		heading.text = "An unwritten account"
		subtitle.text = "No entries match this view."
		reader.text = "Press E beside a named witness to begin their twelve-chapter account. Gather roots and jade, visit regions, hear testimony, rest at camp, and confront named spirits. Return to the chapter's author to receive qi and reputation."
		return
	var c = game.campaign
	travel_button.text = "Travel here"
	travel_button.disabled = false
	if mode == "city":
		var building = game.city.buildings[selected]
		heading.text = building.name
		subtitle.text = building.district + " · 3 floors · 3 resident stories"
		reader.text = game.city.directory_text(selected)
		travel_button.text = "Clear entrance marker" if game.city.destination == selected else "Mark entrance"
		travel_button.disabled = c.current_region != "region_00"
		travel_button.show()
		if c.current_region != "region_00":
			subtitle.text += "\nTravel to Cloudrest using the travel atlas to visit."
	elif mode in ["quests","active"]:
		var q = c.quests[selected]
		var npc = c.npcs[q.owner]
		heading.text = q.title
		subtitle.text = "%s · Chapter %d of 12\n%s · +%d qi" % [region_name(q.region),int(q.stage)+1,q.objective.label,q.reward_qi]
		portrait.texture = game.sprite_library.texture("res://assets/sprites/hires/frames/%s_0.tres" % q.owner)
		portrait.show()
		var story = c.story(selected)
		reader.text = str(story.get("story","Account unavailable."))
		if c.completed.has(selected):
			reader.text += "\n\nAFTER RETURNING TO THE AUTHOR\n" + str(story.get("aftermath", ""))
			reader.text += "\n\nTHE ACCOUNT'S CONSEQUENCE\n"+str(story.get(c.completed[selected],""))
		elif c.active.has(selected):
			subtitle.text += " · Progress %d/%d" % [c.active[selected],q.objective.count]
			abandon_button.show()
			if c.ready_to_claim(selected):
				claim_button.show()
				claim_button.disabled = not game.owner_nearby(q.owner)
				claim_button.text = "Release the binding" if q.choice else "Return account · +%d qi" % q.reward_qi
				if q.choice:
					power_button.show()
					power_button.disabled = claim_button.disabled
		else:
			accept_button.show()
			accept_button.disabled = not game.owner_nearby(q.owner) or c.active.size()>=6 or (q.previous!="" and not c.completed.has(q.previous))
		if not game.owner_nearby(q.owner):
			subtitle.text += "\nAccept / claim beside %s in %s." % [npc.name,region_name(npc.region)]
	elif mode in ["npcs","monsters"]:
		var p = c.npcs[selected] if mode=="npcs" else c.monsters[selected]
		heading.text = p.name
		subtitle.text = region_name(p.region)+" · "+(p.role if mode=="npcs" else p.element+" · "+p.pattern)
		portrait.texture = game.sprite_library.texture("res://assets/sprites/hires/frames/%s_0.tres" % selected)
		portrait.show()
		reader.text = p.lore
		if mode=="npcs":
			reader.text += "\n\nTHEIR ACCOUNT\n"+p.arc+"\nReputation: %d\nMeet the author in %s to begin." % [c.reputation.get(selected,0),region_name(p.region)]
	else:
		var r = c.regions.filter(func(region): return region.id==selected)[0]
		heading.text = r.name
		subtitle.text = r.landmark.capitalize()+" · "+r.faction
		reader.text = "The road leads toward "+r.landmark+", where witnesses investigate "+r.mystery+".\n\nEvery region shelters named witnesses and spirits. The camp beside the southern gate restores vitality and renews regional creatures and blossoms. The three original meridian seals remain in Cloudrest.\n\nTravel counts toward active exploration chapters. Meet the named author to accept and close her accounts."
		travel_button.show()
