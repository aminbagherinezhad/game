extends Control
## Persian main menu: a clean, cinematic mission briefing over the live battlefield.
## Everything is anchored to the screen edges, so it adapts to any landscape size.

signal mission_selected(index: int)
signal play_requested

const FONT_BOLD := preload("res://assets/fonts/Vazirmatn-Bold.ttf")
const FONT_BLACK := preload("res://assets/fonts/Vazirmatn-Black.ttf")
const MISSION_SCRIPT := preload("res://scripts/mission.gd")

const MISSIONS: Array[Dictionary] = [
	{name = "مشت آهنین", brief = "از خودروی خودی محافظت کن و نیروهای دشمن را از میان بردار.", best = 100, goals = 10},
	{name = "شب خاموش", brief = "روستا را پس بگیر و راه تدارکات را ببند.", best = 87, goals = 6},
	{name = "حمله پنهانی", brief = "ستون زرهی را پیش از سپیده‌دم در هم بکوب.", best = 53, goals = 0},
]
const MISSION_SLOTS := 6
const MISSION_GOALS := 10

const NAV_ITEMS: Array[Dictionary] = [
	{icon = "home", text = "خانه"},
	{icon = "weapon", text = "تسلیحات"},
	{icon = "support", text = "پشتیبانی"},
	{icon = "store", text = "فروشگاه"},
]
const HOME_TAB := 0
const WEAPONS_TAB := 1
const SUPPORT_TAB := 2

const WEAPONS: Array[Dictionary] = [
	{name = "مسلسل ۲۵ میلی‌متری", image = "gun", level = 25, progress = 0.4, damage = 34, ammo = 102,
			damage_up = 1, ammo_up = 3, action = "ارتقا", price = 410},
	{name = "موشک خیبرشکن", image = "kheibar", level = 3, progress = 0.08, damage = 112, ammo = 3,
			damage_up = 6, ammo_up = 1, action = "ارتقا", price = 590},
	{name = "موشک فتاح ۲", image = "fattah2", action = "تجهیز", price = 10000,
			brief = "موشک هایپرسونیک با کلاهک مانورپذیر برای اصابتی ویرانگر و نفوذناپذیر."},
]
const SUPPORTS: Array[Dictionary] = [
	{name = "پهپاد شاهد ۱۳۶", image = "shahed136", action = "خرید", price = 2500,
			brief = "پهپاد انتحاری دوربرد که با پرواز کم‌ارتفاع هدف را غافلگیر می‌کند."},
]
const CARD_SLOTS := 3

const EDGE := 28
const CONTENT_LEFT := 148
const CHIP_SIZE := Vector2(58, 58)

const COLOR_ACCENT := Color(1.0, 0.66, 0.16)
const COLOR_GLASS := Color(0.04, 0.06, 0.08, 0.62)
const COLOR_LINE := Color(1, 1, 1, 0.16)
const COLOR_MUTED := Color(0.72, 0.76, 0.8)
const COLOR_DARK := Color(0.07, 0.05, 0.02)

var _nav_buttons: Array[Button] = []
var _chips: Array[Button] = []
var _chip_labels: Array[Label] = []
var _heading: VBoxContainer
var _mission_tag: Label
var _mission_title: Label
var _mission_brief: Label
var _best_value: Label
var _goals_value: Label
var _toast: PanelContainer
var _toast_label: Label
var _toast_tween: Tween
var _heading_tween: Tween
var _selected_mission := 0
var _top_bar: Array[Control] = []
var _home_items: Array[Control] = []
var _card_pages: Dictionary = {}


func _ready() -> void:
	var menu_theme := Theme.new()
	menu_theme.default_font = FONT_BOLD
	menu_theme.default_font_size = 20
	theme = menu_theme

	_build_scrims()
	_card_pages[WEAPONS_TAB] = _build_card_page(WEAPONS)
	_card_pages[SUPPORT_TAB] = _build_card_page(SUPPORTS)
	_build_nav()
	_build_player()
	_build_resources()
	_build_heading()
	_build_mission_row()
	_build_play()
	_build_toast()
	_show_tab(HOME_TAB)
	_select_mission(_selected_mission)
	_fade_in()
	_add_mission.call_deferred()


## Built here and not in main.tscn, so an editor saving an older scene cannot unhook it.
func _add_mission() -> void:
	var mission := Control.new()
	mission.name = "Mission"
	mission.set_script(MISSION_SCRIPT)
	get_parent().add_child(mission)
	mission.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	play_requested.connect(mission.open_briefing)


## Converts Latin digits to Persian ones.
func _fa(value: Variant) -> String:
	var text := str(value)
	for digit in 10:
		text = text.replace(str(digit), "۰۱۲۳۴۵۶۷۸۹"[digit])
	return text


func _pin(control: Control, anchor: Vector2, spot: Vector2, size_px: Vector2) -> void:
	control.anchor_left = anchor.x
	control.anchor_right = anchor.x
	control.anchor_top = anchor.y
	control.anchor_bottom = anchor.y
	control.offset_left = spot.x
	control.offset_top = spot.y
	control.offset_right = spot.x + size_px.x
	control.offset_bottom = spot.y + size_px.y


func _style(color: Color, radius: int, border_color := Color.TRANSPARENT, border := 0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.border_color = border_color
	box.set_border_width_all(border)
	box.anti_aliasing = true
	return box


func _label(text: String, size_px: int, color := Color.WHITE, font: Font = FONT_BOLD) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", color)
	return label


func _number_label(text: String, size_px: int, color := Color.WHITE) -> Label:
	var label := _label(text, size_px, color)
	label.text_direction = Control.TEXT_DIRECTION_LTR
	return label


func _icon(name_id: String, size_px: Vector2) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = load("res://assets/icons/%s.svg" % name_id)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = size_px
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


func _button(parent: Control, size_px: Vector2) -> Button:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = size_px
	button.pivot_offset = size_px / 2
	button.button_down.connect(_scale_button.bind(button, 0.93))
	button.button_up.connect(_scale_button.bind(button, 1.0))
	parent.add_child(button)
	return button


func _set_button_style(button: Button, normal: StyleBox, hover: StyleBox = normal) -> void:
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("pressed", normal)
	button.add_theme_stylebox_override("hover", hover)


func _scale_button(button: Control, value: float) -> void:
	create_tween().tween_property(button, "scale", Vector2.ONE * value, 0.08)


func _build_scrims() -> void:
	# Darkens the left and bottom of the battlefield so the text stays readable.
	var left := _scrim(Vector2(1, 0.5), Vector2(0, 0.5), 0.86)
	left.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	left.anchor_right = 0.62
	var bottom := _scrim(Vector2(0.5, 0), Vector2(0.5, 1), 0.82)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.anchor_top = 0.55
	var top := _scrim(Vector2(0.5, 1), Vector2(0.5, 0), 0.6)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.anchor_bottom = 0.2


func _scrim(from: Vector2, to: Vector2, strength: float) -> TextureRect:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, strength)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = from
	texture.fill_to = to
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	return rect


func _build_nav() -> void:
	var rail := VBoxContainer.new()
	rail.add_theme_constant_override("separation", 10)
	rail.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(rail)
	_pin(rail, Vector2(0, 0.5), Vector2(EDGE, -195), Vector2(92, 390))

	for i in NAV_ITEMS.size():
		var button := _button(rail, Vector2(92, 90))
		button.pressed.connect(_on_nav_pressed.bind(i))
		var icon := _icon(NAV_ITEMS[i].icon, Vector2(42, 42))
		button.add_child(icon)
		_pin(icon, Vector2.ZERO, Vector2(25, 9), Vector2(42, 42))
		var label := _label(NAV_ITEMS[i].text, 16)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.add_child(label)
		_pin(label, Vector2.ZERO, Vector2(0, 54), Vector2(92, 28))
		_nav_buttons.append(button)


func _select_nav(index: int) -> void:
	var clear := _style(Color.TRANSPARENT, 8)
	var hover := _style(Color(1, 1, 1, 0.07), 8)
	var active := _style(Color(COLOR_ACCENT, 0.14), 8)
	active.border_color = COLOR_ACCENT
	active.border_width_right = 3
	for i in _nav_buttons.size():
		var selected := i == index
		_set_button_style(_nav_buttons[i], active if selected else clear, active if selected else hover)
		for child: Control in _nav_buttons[i].get_children():
			child.modulate = COLOR_ACCENT if selected else Color(1, 1, 1, 0.62)


func _build_player() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	add_child(row)
	_pin(row, Vector2.ZERO, Vector2(CONTENT_LEFT, 22), Vector2(300, 44))
	_top_bar.append(row)
	row.add_child(_icon("avatar", Vector2(44, 44)))
	row.add_child(_label("شیر سرخ", 24))


func _build_resources() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	row.layout_direction = Control.LAYOUT_DIRECTION_LTR
	add_child(row)
	_pin(row, Vector2(1, 0), Vector2(-EDGE, 22), Vector2.ZERO)
	_top_bar.append(row)

	row.add_child(_resource("energy", "%s/%s" % [_fa(14), _fa(10)]))
	row.add_child(_resource("cash", _fa(GameState.cash)))
	row.add_child(_resource("gold", _fa(10)))

	var settings := _button(row, Vector2(44, 44))
	_set_button_style(settings, _style(COLOR_GLASS, 8), _style(Color(0.2, 0.22, 0.25, 0.8), 8))
	var icon := _icon("menu", Vector2(22, 22))
	settings.add_child(icon)
	_pin(icon, Vector2.ZERO, Vector2(11, 11), Vector2(22, 22))
	settings.pressed.connect(_show_toast.bind("تنظیمات به‌زودی اضافه می‌شود"))


func _resource(icon_id: String, value: String) -> Control:
	var pill := PanelContainer.new()
	var style := _style(COLOR_GLASS, 8)
	style.content_margin_left = 10
	style.content_margin_right = 14
	pill.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	pill.add_child(row)
	row.add_child(_icon(icon_id, Vector2(28, 44)))
	row.add_child(_number_label(value, 20))
	return pill


func _build_heading() -> void:
	_heading = VBoxContainer.new()
	_heading.add_theme_constant_override("separation", 2)
	_heading.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_heading)
	_pin(_heading, Vector2(0, 1), Vector2(CONTENT_LEFT, -118), Vector2(620, 0))
	_home_items.append(_heading)

	_mission_tag = _label("", 22, COLOR_ACCENT)
	_heading.add_child(_mission_tag)

	_mission_title = _label("", 84, Color.WHITE, FONT_BLACK)
	_mission_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	_mission_title.add_theme_constant_override("shadow_offset_x", 0)
	_mission_title.add_theme_constant_override("shadow_offset_y", 4)
	_heading.add_child(_mission_title)

	_mission_brief = _label("", 21, Color(0.9, 0.92, 0.94))
	_heading.add_child(_mission_brief)

	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 10)
	_heading.add_child(stats)
	# Laid out left to right, so each value comes before its label for RTL reading.
	_goals_value = _number_label("", 18)
	stats.add_child(_goals_value)
	stats.add_child(_label("اهداف", 18, COLOR_MUTED))
	var divider := ColorRect.new()
	divider.color = COLOR_LINE
	divider.custom_minimum_size = Vector2(1, 18)
	divider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stats.add_child(divider)
	_best_value = _number_label("", 18)
	stats.add_child(_best_value)
	stats.add_child(_label("بهترین", 18, COLOR_MUTED))


func _build_mission_row() -> void:
	var holder := Control.new()
	add_child(holder)
	_home_items.append(holder)
	var row_width := MISSION_SLOTS * CHIP_SIZE.x + (MISSION_SLOTS - 1) * 12
	_pin(holder, Vector2(0, 1), Vector2(CONTENT_LEFT, -CHIP_SIZE.y - EDGE), Vector2(row_width, CHIP_SIZE.y))

	var line := ColorRect.new()
	line.color = COLOR_LINE
	holder.add_child(line)
	_pin(line, Vector2.ZERO, Vector2(0, CHIP_SIZE.y / 2), Vector2(row_width, 2))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	holder.add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	for i in MISSION_SLOTS:
		var chip := _button(row, CHIP_SIZE)
		chip.pressed.connect(_on_chip_pressed.bind(i))
		_chips.append(chip)
		if i < MISSIONS.size():
			var label := _number_label(_fa(i + 1), 24)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			chip.add_child(label)
			label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			_chip_labels.append(label)
		else:
			var lock := _icon("lock", Vector2(20, 20))
			lock.modulate = Color(1, 1, 1, 0.35)
			chip.add_child(lock)
			_pin(lock, Vector2.ZERO, Vector2(19, 19), Vector2(20, 20))


func _build_play() -> void:
	var size_px := Vector2(300, 84)
	var play := _button(self, size_px)
	_home_items.append(play)
	_pin(play, Vector2(1, 1), Vector2(-EDGE - size_px.x, -EDGE - size_px.y), size_px)
	var style := _style(COLOR_ACCENT, 6)
	style.shadow_color = Color(COLOR_ACCENT, 0.5)
	style.shadow_size = 12
	var hover: StyleBoxFlat = style.duplicate()
	hover.bg_color = COLOR_ACCENT.lightened(0.18)
	_set_button_style(play, style, hover)
	play.text = "آغاز عملیات"
	play.add_theme_font_override("font", FONT_BLACK)
	play.add_theme_font_size_override("font_size", 34)
	for color_name in ["font_color", "font_hover_color", "font_pressed_color"]:
		play.add_theme_color_override(color_name, COLOR_DARK)
	play.pressed.connect(_on_play_pressed)

	var pulse := create_tween().set_loops()
	pulse.tween_property(style, "shadow_size", 26, 1.2).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(style, "shadow_size", 10, 1.2).set_trans(Tween.TRANS_SINE)


func _build_card_page(items: Array[Dictionary]) -> Control:
	var page := Control.new()
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(page)
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var dim := ColorRect.new()
	dim.color = Color(0, 0.02, 0.03, 0.8)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var row := HBoxContainer.new()
	row.name = "Cards"
	row.add_theme_constant_override("separation", 20)
	row.layout_direction = Control.LAYOUT_DIRECTION_LTR
	page.add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = CONTENT_LEFT
	row.offset_right = -EDGE
	row.offset_top = 80
	row.offset_bottom = -22
	for slot in CARD_SLOTS:
		row.add_child(_weapon_card(items[slot]) if slot < items.size() else _locked_card())
	return page


## An empty slot, saved for a later update.
func _locked_card() -> Control:
	var card := Panel.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size.x = 290
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel", _style(Color(0.03, 0.04, 0.05, 0.75), 12, Color(1, 1, 1, 0.22), 2))
	var lock := _icon("lock", Vector2(72, 72))
	lock.modulate = Color(1, 1, 1, 0.3)
	card.add_child(lock)
	lock.set_anchors_preset(Control.PRESET_CENTER)
	lock.offset_left = -36
	lock.offset_top = -36
	lock.offset_right = 36
	lock.offset_bottom = 36
	return card


func _band(parent: Control, child: Control, top: float, bottom: float, margin := 0) -> void:
	parent.add_child(child)
	child.anchor_left = 0
	child.anchor_right = 1
	child.anchor_top = top
	child.anchor_bottom = bottom
	child.offset_left = margin
	child.offset_right = -margin
	child.offset_top = 0
	child.offset_bottom = 0


func _weapon_card(weapon: Dictionary) -> Control:
	var card := Control.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size.x = 290

	# Everything inside the mask is clipped to the rounded card shape.
	var mask := Panel.new()
	mask.add_theme_stylebox_override("panel", _style(Color(0.015, 0.02, 0.025), 12))
	mask.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(mask)
	mask.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var photo := TextureRect.new()
	photo.texture = load("res://assets/weapons/%s.jpg" % weapon.image)
	photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_band(mask, photo, 0, 0.62)

	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(0.015, 0.02, 0.025, 0), Color(0.015, 0.02, 0.025, 1)])
	var fade := GradientTexture2D.new()
	fade.gradient = gradient
	fade.fill_from = Vector2(0.5, 0)
	fade.fill_to = Vector2(0.5, 1)
	var fade_rect := TextureRect.new()
	fade_rect.texture = fade
	fade_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_band(mask, fade_rect, 0.34, 0.62)

	if weapon.has("level"):
		_card_level(card, weapon)

	var title := _label(weapon.name, 25, Color.WHITE, FONT_BLACK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_band(card, title, 0.5, 0.58)

	if weapon.has("brief"):
		var brief := _label(weapon.brief, 21)
		brief.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		brief.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		brief.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_band(card, brief, 0.58, 0.82, 16)
	else:
		_card_stats(card, weapon)

	var action := _label(weapon.action, 18, Color(0.62, 0.92, 0.55))
	action.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	action.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_band(card, action, 0.82, 0.875)
	_card_price(card, weapon)

	var border := Panel.new()
	border.add_theme_stylebox_override("panel", _style(Color.TRANSPARENT, 12, Color(1, 1, 1, 0.75), 2))
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(border)
	border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return card


func _card_level(card: Control, weapon: Dictionary) -> void:
	var tag := PanelContainer.new()
	var style := _style(COLOR_ACCENT, 0)
	style.corner_radius_top_left = 12
	style.corner_radius_bottom_right = 10
	style.content_margin_left = 14
	style.content_margin_right = 14
	tag.add_theme_stylebox_override("panel", style)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(tag)
	_pin(tag, Vector2.ZERO, Vector2.ZERO, Vector2(84, 64))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", -8)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	tag.add_child(column)
	var word := _label("سطح", 14, COLOR_DARK)
	word.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(word)
	var level := _label(_fa(weapon.level), 26, COLOR_DARK, FONT_BLACK)
	level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(level)

	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.value = weapon.progress * 100
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("background", _style(Color(0, 0, 0, 0.72), 3))
	bar.add_theme_stylebox_override("fill", _style(COLOR_ACCENT, 3))
	card.add_child(bar)
	bar.anchor_right = 1
	bar.offset_left = 96
	bar.offset_right = -14
	bar.offset_top = 14
	bar.offset_bottom = 22


func _card_stats(card: Control, weapon: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 0)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_band(card, row, 0.58, 0.82, 12)
	row.add_child(_stat_column("آسیب", weapon.damage, weapon.damage_up))
	var divider := ColorRect.new()
	divider.color = COLOR_LINE
	divider.custom_minimum_size.x = 1
	row.add_child(divider)
	row.add_child(_stat_column("مهمات", weapon.ammo, weapon.ammo_up))


func _stat_column(title: String, value: int, bonus: int) -> Control:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", -6)
	for line: Label in [_label(title, 18, COLOR_MUTED), _number_label(_fa(value), 42), _number_label("+" + _fa(bonus), 18, Color(0.62, 0.92, 0.55))]:
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(line)
	return column


func _card_price(card: Control, weapon: Dictionary) -> void:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	card.add_child(button)
	button.anchor_left = 0
	button.anchor_right = 1
	button.anchor_top = 0.875
	button.anchor_bottom = 1
	button.offset_left = 12
	button.offset_right = -12
	button.offset_bottom = -12
	var style := _style(COLOR_ACCENT, 6)
	_set_button_style(button, style, _style(COLOR_ACCENT.lightened(0.18), 6))
	button.button_down.connect(func() -> void: button.modulate = Color(0.8, 0.8, 0.8))
	button.button_up.connect(func() -> void: button.modulate = Color.WHITE)
	button.pressed.connect(_on_card_pressed.bind(weapon))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.layout_direction = Control.LAYOUT_DIRECTION_LTR
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_child(_icon("cash", Vector2(30, 30)))
	var price := _number_label(_fa_price(weapon.price), 26, COLOR_DARK)
	price.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(price)


## Persian digits with the Persian thousands separator.
func _fa_price(value: int) -> String:
	var digits := str(value)
	var grouped := ""
	for i in digits.length():
		if i > 0 and (digits.length() - i) % 3 == 0:
			grouped += "٬"
		grouped += digits[i]
	return _fa(grouped)


func _build_toast() -> void:
	_toast = PanelContainer.new()
	var style := _style(Color(0.03, 0.04, 0.05, 0.94), 6, COLOR_ACCENT, 1)
	style.set_content_margin_all(12)
	_toast.add_theme_stylebox_override("panel", style)
	_toast.modulate.a = 0
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(_toast)
	_toast.anchor_left = 0.5
	_toast.anchor_right = 0.5
	_toast.offset_top = 84
	_toast_label = _label("", 21)
	_toast.add_child(_toast_label)


func _fade_in() -> void:
	var cover := ColorRect.new()
	cover.color = Color.BLACK
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cover)
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var tween := create_tween()
	tween.tween_interval(0.3)
	tween.tween_property(cover, "modulate:a", 0.0, 1.4)
	tween.tween_callback(cover.queue_free)


func _select_mission(index: int) -> void:
	_selected_mission = index
	var mission: Dictionary = MISSIONS[index]
	_mission_tag.text = "مأموریت %s" % _fa(index + 1)
	_mission_title.text = mission.name
	_mission_brief.text = mission.brief
	_best_value.text = _fa(mission.best) + "٪"
	_goals_value.text = "%s/%s" % [_fa(mission.goals), _fa(MISSION_GOALS)]
	_refresh_chips()
	_reveal_heading()
	mission_selected.emit(index)


func _refresh_chips() -> void:
	for i in _chips.size():
		var selected := i == _selected_mission
		var unlocked := i < MISSIONS.size()
		var fill := COLOR_ACCENT if selected else Color(0.05, 0.07, 0.09, 0.92)
		var border := COLOR_ACCENT if selected else (Color(1, 1, 1, 0.34) if unlocked else COLOR_LINE)
		var style := _style(fill, 29, border, 2)
		var hover := _style(fill.lightened(0.12), 29, border, 2)
		_set_button_style(_chips[i], style, hover)
	for i in _chip_labels.size():
		_chip_labels[i].add_theme_color_override("font_color", COLOR_DARK if i == _selected_mission else Color.WHITE)


func _reveal_heading() -> void:
	if _heading_tween:
		_heading_tween.kill()
	_heading.modulate.a = 0
	_heading.position.x = CONTENT_LEFT - 28
	_heading_tween = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_heading_tween.tween_property(_heading, "modulate:a", 1.0, 0.45)
	_heading_tween.tween_property(_heading, "position:x", float(CONTENT_LEFT), 0.45)


func _show_toast(text: String) -> void:
	_toast_label.text = text
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, 0.15)
	_toast_tween.tween_interval(1.6)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.4)


func _show_tab(index: int) -> void:
	_select_nav(index)
	for item in _home_items:
		item.visible = index == HOME_TAB
	for tab: int in _card_pages:
		_card_pages[tab].visible = index == tab
	if _card_pages.has(index):
		_reveal_cards(_card_pages[index].get_node("Cards").get_children())


func _reveal_cards(cards: Array[Node]) -> void:
	for i in cards.size():
		var card: Control = cards[i]
		card.modulate.a = 0
		var tween := create_tween()
		tween.tween_interval(i * 0.08)
		tween.tween_property(card, "modulate:a", 1.0, 0.3)


func _on_nav_pressed(index: int) -> void:
	if index == HOME_TAB or _card_pages.has(index):
		_show_tab(index)
	else:
		_show_toast("بخش «%s» به‌زودی فعال می‌شود" % NAV_ITEMS[index].text)


func _on_card_pressed(weapon: Dictionary) -> void:
	if weapon.price > GameState.cash:
		_show_toast("پول کافی برای «%s» ندارید" % weapon.name)
	else:
		_show_toast("«%s» آماده شد" % weapon.name)


func _on_chip_pressed(index: int) -> void:
	if index >= MISSIONS.size():
		_show_toast("این مأموریت هنوز قفل است")
	elif index != _selected_mission:
		_select_mission(index)


func _on_play_pressed() -> void:
	if _selected_mission == 0:
		play_requested.emit()
	else:
		_show_toast("عملیات «%s» به‌زودی آماده می‌شود" % MISSIONS[_selected_mission].name)


## Leaves just the player and resource bars, for the mission briefing.
func show_top_bar_only() -> void:
	for child in get_children():
		if child is CanvasItem:
			child.visible = child in _top_bar
