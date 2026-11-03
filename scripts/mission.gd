extends Control
## Mission 1: protect a friendly humvee from the drone's camera.
## Paced like War Drone's first level: four soldiers, then one vehicle, 20% per kill.

enum State { IDLE, BRIEFING, LOADING, RUNNING, FINISHED }

const FONT_BOLD := preload("res://assets/fonts/Vazirmatn-Bold.ttf")
const FONT_BLACK := preload("res://assets/fonts/Vazirmatn-Black.ttf")
const WEAPON_ICON := preload("res://assets/icons/weapon.svg")

const FRIENDLY_SPOT := Vector3(11, 0, 34)
const START_AMMO := 123
const START_ROCKETS := 4
const GUN_INTERVAL := 0.2
const GUN_SPREAD := 0.9
const GUN_SOUND := preload("res://assets/sounds/gun_shot.wav")
## How long the hit marker stays, and how fast the crosshair settles after firing.
const HIT_MARKER_TIME := 0.16
const SPREAD_RECOVERY := 3.5
const GUN_HIT_RADIUS := 2.2
const ROCKET_COOLDOWN := 1.6
## Every unit of a kind has the same health; armour takes far more punishment than infantry.
const UNITS := {
	"soldier": {health = 100, speed = 2.2, dps = 1.6},
	"vehicle": {health = 300, speed = 4.5, dps = 4.0},
}
## Indexes into the weapon cards of the menu, which hold each weapon's damage.
## Radians of leg swing per metre walked.
const STEP_PER_METRE := 4.2
const GUN_CARD := 0
const ROCKET_CARD := 1
## A blast does full damage near its centre, falling to this share at its edge.
const SPLASH_FALLOFF := 0.4
const SPLASH_FULL_REACH := 0.4
const FRIENDLY_FIRE_DAMAGE := 25.0
const SOLDIER_REWARD := 25
const VEHICLE_REWARD := 100
const KILL_PERCENT := 20
const FINISH_DELAY := 2.2

## Each entry enters once `after` kills have been scored.
const ENEMIES: Array[Dictionary] = [
	{kind = "soldier", after = 0, delay = 1.5, from = Vector3(19, 0, 84), stop = Vector3(18, 0, 48)},
	{kind = "soldier", after = 0, delay = 3.5, from = Vector3(14, 0, 92), stop = Vector3(13, 0, 49)},
	{kind = "soldier", after = 2, delay = 1.0, from = Vector3(-58, 0, 31), stop = Vector3(-4, 0, 32)},
	{kind = "soldier", after = 2, delay = 3.0, from = Vector3(-62, 0, 37), stop = Vector3(-3, 0, 37)},
	{kind = "vehicle", after = 4, delay = 1.5, from = Vector3(18, 0, -60), stop = Vector3(18, 0, 22)},
]

const COLOR_ACCENT := Color(1.0, 0.66, 0.16)
const COLOR_FRIEND := Color(0.42, 0.95, 0.6)
const COLOR_ENEMY := Color(1.0, 0.27, 0.3)
const COLOR_PANEL := Color(0.04, 0.06, 0.08, 0.86)
const COLOR_STAR := Color(1.0, 0.8, 0.3)

var _state := State.IDLE
var _time := 0.0
var _health := 100.0
var _ammo := START_AMMO
var _rockets := START_ROCKETS
var _gun_timer := 0.0
var _gun_sound: AudioStreamPlayer
var _crosshair_spread := 0.0
var _hit_marker := 0.0
var _hit_killed := false
## Ground spots with a rocket on the way, each with its remaining flight time.
var _incoming: Array[Dictionary] = []
var _rocket_timer := 0.0
var _kills := 0
var _soldiers_killed := 0
var _vehicles_killed := 0
var _zoomed := false
var _enemies: Array[Dictionary] = []
var _pending: Array[Dictionary] = []
var _friendly: Node3D
var _aim_finger := -1
var _gun_finger := -1
var _key_fire := false
var _cover: ColorRect
var _stars := 0
var _victory := false
var _layer: Control

@onready var _field: Node3D = get_node("../../Battlefield")
@onready var _menu: Control = get_node("../MainMenu")


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The HUD reads touches only, so a mouse has to arrive as one finger.
	Input.emulate_touch_from_mouse = true
	_field.exploded.connect(_on_exploded)
	_gun_sound = AudioStreamPlayer.new()
	_gun_sound.stream = GUN_SOUND
	_gun_sound.max_polyphony = 6
	_gun_sound.volume_db = -5.0
	add_child(_gun_sound)


func _fa(value: Variant) -> String:
	var text := str(value)
	for digit in 10:
		text = text.replace(str(digit), "۰۱۲۳۴۵۶۷۸۹"[digit])
	return text


func open_briefing() -> void:
	_state = State.BRIEFING
	visible = true
	_menu.show_top_bar_only()
	_field.begin_mission(FRIENDLY_SPOT + Vector3(10, 0, -4))
	_friendly = _field.add_friendly(FRIENDLY_SPOT, 0.0)
	_build_briefing()


func _new_layer() -> Control:
	if _layer:
		_layer.queue_free()
	_layer = Control.new()
	_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_layer)
	_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return _layer


func _style(color: Color, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	return box


func _label(text: String, size_px: int, color := Color.WHITE, font: Font = FONT_BOLD) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", color)
	return label


func _action_button(text: String, pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", FONT_BLACK)
	button.add_theme_font_size_override("font_size", 30)
	for state in ["normal", "pressed", "hover"]:
		button.add_theme_stylebox_override(state, _style(COLOR_ACCENT.lightened(0.15 if state == "hover" else 0.0), 6))
	for color_name in ["font_color", "font_hover_color", "font_pressed_color"]:
		button.add_theme_color_override(color_name, Color(0.07, 0.05, 0.02))
	button.pressed.connect(pressed)
	return button


func _build_briefing() -> void:
	var layer := _new_layer()
	var number := _label("۰۱", 120, Color.WHITE, FONT_BLACK)
	number.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	layer.add_child(number)
	number.anchor_top = 1
	number.anchor_bottom = 1
	number.offset_left = 60
	number.offset_top = -330
	number.offset_right = 360
	number.offset_bottom = -170

	var title := _label(_menu.MISSIONS[0].name, 36, Color.WHITE, FONT_BLACK)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	layer.add_child(title)
	title.anchor_top = 1
	title.anchor_bottom = 1
	title.offset_left = 60
	title.offset_top = -180
	title.offset_right = 700
	title.offset_bottom = -120

	var strip := Panel.new()
	strip.add_theme_stylebox_override("panel", _style(COLOR_PANEL, 0))
	layer.add_child(strip)
	strip.anchor_top = 1
	strip.anchor_bottom = 1
	strip.anchor_right = 1
	strip.offset_left = 40
	strip.offset_right = -40
	strip.offset_top = -112
	strip.offset_bottom = -30

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.layout_direction = Control.LAYOUT_DIRECTION_LTR
	row.add_theme_constant_override("separation", 14)
	strip.add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 16
	row.offset_right = -12
	row.offset_top = 10
	row.offset_bottom = -10

	var intel := PanelContainer.new()
	var chip := _style(Color(0.82, 0.95, 0.62), 4)
	chip.content_margin_left = 10
	chip.content_margin_right = 10
	intel.add_theme_stylebox_override("panel", chip)
	var word := _label("اطلاعات دشمن", 16, Color(0.08, 0.1, 0.06))
	word.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	intel.add_child(word)
	row.add_child(intel)
	row.add_child(_intel_icon("soldier"))
	row.add_child(_intel_icon("jeep"))
	var gap := Control.new()
	gap.custom_minimum_size.x = 60
	row.add_child(gap)

	var start := _action_button("شروع", _start_mission)
	start.custom_minimum_size.x = 270
	row.add_child(start)


func _intel_icon(name_id: String) -> Control:
	var box := PanelContainer.new()
	var style := _style(Color(0, 0, 0, 0.4), 4)
	style.set_border_width_all(1)
	style.border_color = Color(1, 1, 1, 0.55)
	box.add_theme_stylebox_override("panel", style)
	var icon := TextureRect.new()
	icon.texture = load("res://assets/icons/%s.svg" % name_id)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(54, 54)
	box.add_child(icon)
	return box


func _start_mission() -> void:
	_new_layer()
	_state = State.LOADING
	_cover = ColorRect.new()
	_cover.color = Color.BLACK
	_cover.modulate.a = 0
	_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cover.draw.connect(_draw_spinner)
	_layer.add_child(_cover)
	_cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var tween := create_tween()
	tween.tween_property(_cover, "modulate:a", 1.0, 0.25)
	tween.tween_callback(_enter_battle)
	tween.tween_interval(1.0)
	tween.tween_property(_cover, "modulate:a", 0.0, 0.4)
	tween.tween_callback(_cover.queue_free)


func _draw_spinner() -> void:
	_cover.draw_arc(size / 2, 18, _time * 6.0, _time * 6.0 + 4.6, 32, Color(0.3, 0.9, 0.8), 3.0, true)


func _enter_battle() -> void:
	_menu.visible = false
	_field.start_drone_flight()
	_pending = ENEMIES.duplicate(true)
	_state = State.RUNNING


func _input(event: InputEvent) -> void:
	if _state != State.RUNNING:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_down(event.index, event.position)
		elif event.index == _gun_finger:
			_gun_finger = -1
		elif event.index == _aim_finger:
			_aim_finger = -1
	elif event is InputEventScreenDrag and event.index == _aim_finger:
		_field.move_aim(event.relative)
	elif event is InputEventKey and not event.echo:
		if event.keycode == KEY_SPACE:
			_key_fire = event.pressed
		elif event.keycode == KEY_F and event.pressed:
			_fire_rocket()


func _touch_down(finger: int, spot: Vector2) -> void:
	if spot.distance_to(_gun_centre()) < 62.0:
		_gun_finger = finger
	elif spot.distance_to(_rocket_centre()) < 46.0:
		_fire_rocket()
	elif spot.distance_to(_zoom_centre()) < 42.0:
		_zoomed = not _zoomed
		_field.set_zoom(_zoomed)
	elif spot.distance_to(_exit_centre()) < 34.0:
		get_tree().reload_current_scene()
	else:
		_aim_finger = finger


func _gun_centre() -> Vector2:
	return Vector2(100, size.y - 86)


func _rocket_centre() -> Vector2:
	return Vector2(208, size.y - 150)


func _zoom_centre() -> Vector2:
	return Vector2(84, size.y - 236)


func _exit_centre() -> Vector2:
	return Vector2(size.x - 56, 46)


func _process(delta: float) -> void:
	_time += delta
	if _state == State.IDLE:
		return
	queue_redraw()
	if is_instance_valid(_cover):
		_cover.queue_redraw()
	if _state != State.RUNNING:
		return
	_rocket_timer = maxf(_rocket_timer - delta, 0.0)
	_crosshair_spread = maxf(_crosshair_spread - delta * SPREAD_RECOVERY, 0.0)
	_hit_marker = maxf(_hit_marker - delta, 0.0)
	for rocket in _incoming.duplicate():
		rocket.left -= delta
		if rocket.left <= 0.0:
			_incoming.erase(rocket)
	_spawn_enemies(delta)
	_update_gun(delta)
	_update_enemies(delta)
	if _health <= 0.0:
		_finish(false)
	elif _kills == ENEMIES.size():
		_finish(true)
	elif _ammo <= 0 and _rockets <= 0 and _rocket_timer <= 0.0:
		_finish(false)


func _spawn_enemies(delta: float) -> void:
	for entry in _pending.duplicate():
		if _kills < entry.after:
			continue
		entry.delay -= delta
		if entry.delay <= 0.0:
			_pending.erase(entry)
			_spawn(entry)


func _spawn(entry: Dictionary) -> void:
	var unit: Dictionary = UNITS[entry.kind]
	var enemy := {kind = entry.kind, stop = entry.stop, alive = true, phase = randf() * TAU, stride = randf() * TAU,
			health = unit.health, max_health = unit.health, speed = unit.speed, dps = unit.dps}
	if entry.kind == "soldier":
		enemy.node = _field.add_soldier(entry.from)
	else:
		enemy.target = _field.add_enemy_vehicle(entry.from, entry.stop)
		enemy.node = enemy.target.node
	_enemies.append(enemy)


func _update_gun(delta: float) -> void:
	_gun_timer -= delta
	if (_gun_finger < 0 and not _key_fire) or _gun_timer > 0.0 or _ammo <= 0:
		return
	_gun_timer = GUN_INTERVAL
	_ammo -= 1
	var offset := Vector2.from_angle(randf() * TAU) * randf() * GUN_SPREAD
	var spot: Vector3 = _field.aim_point + Vector3(offset.x, 0, offset.y)
	_crosshair_spread = minf(_crosshair_spread + 0.4, 1.0)
	_gun_sound.pitch_scale = randf_range(0.93, 1.07)
	_gun_sound.play()
	_field.fire_round(spot, _on_round_landed.bind(spot))


func _on_round_landed(spot: Vector3) -> void:
	if _state != State.RUNNING:
		return
	for enemy in _enemies:
		if enemy.alive and _flat_distance(enemy.node.global_position, spot) < GUN_HIT_RADIUS:
			_damage(enemy, _menu.WEAPONS[GUN_CARD].damage)
			_hit_marker = HIT_MARKER_TIME
			_hit_killed = not enemy.alive
			break


func _damage(enemy: Dictionary, amount: float) -> void:
	if not enemy.alive:
		return
	enemy.health = maxf(enemy.health - amount, 0.0)
	if enemy.health > 0.0:
		return
	enemy.alive = false
	_kills += 1
	if enemy.kind == "soldier":
		_soldiers_killed += 1
		_field.drop_soldier(enemy.node)
	else:
		_vehicles_killed += 1
		_field.destroy_armour(enemy.target)


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _update_enemies(delta: float) -> void:
	for enemy in _enemies:
		if not enemy.alive:
			continue
		var node: Node3D = enemy.node
		var flat := Vector3(node.position.x, 0, node.position.z)
		var left: Vector3 = enemy.stop - flat
		if left.length() > 0.2:
			flat = flat.move_toward(enemy.stop, enemy.speed * delta)
			node.rotation.y = atan2(-left.z, left.x)
			node.position = flat
			if enemy.kind == "soldier":
				enemy.stride += enemy.speed * delta * STEP_PER_METRE
				_field.animate_soldier(node, enemy.stride, true, false)
		else:
			_health = maxf(_health - enemy.dps * delta, 0.0)
			var toward := FRIENDLY_SPOT - flat
			node.rotation.y = atan2(-toward.z, toward.x)
			_field.set_muzzle(node, sin(_time * 30.0 + enemy.phase) > 0.3)
			if enemy.kind == "soldier":
				_field.animate_soldier(node, 0.0, false, true)


func _fire_rocket() -> void:
	if _rockets <= 0 or _rocket_timer > 0.0:
		return
	_rockets -= 1
	_rocket_timer = ROCKET_COOLDOWN
	_crosshair_spread = 1.0
	_incoming.append({spot = _field.aim_point, left = _field.ROCKET_FLIGHT})
	_field.fire_rocket(_field.aim_point)


func _on_exploded(spot: Vector3, radius: float) -> void:
	if _state != State.RUNNING:
		return
	var rocket_damage: float = _menu.WEAPONS[ROCKET_CARD].damage
	for enemy in _enemies.duplicate():
		var reach := _flat_distance(enemy.node.global_position, spot) / radius if enemy.alive else 2.0
		if reach < 1.0:
			var share := clampf((reach - SPLASH_FULL_REACH) / (1.0 - SPLASH_FULL_REACH), 0.0, 1.0)
			_damage(enemy, rocket_damage * lerpf(1.0, SPLASH_FALLOFF, share))
			_hit_marker = HIT_MARKER_TIME
			_hit_killed = not enemy.alive
	if _flat_distance(FRIENDLY_SPOT, spot) < radius * 0.8:
		_health = maxf(_health - FRIENDLY_FIRE_DAMAGE, 0.0)


func _reward() -> int:
	return _soldiers_killed * SOLDIER_REWARD + _vehicles_killed * VEHICLE_REWARD


func _finish(victory: bool) -> void:
	_state = State.FINISHED
	_victory = victory
	_gun_finger = -1
	_aim_finger = -1
	_stars = 3 if _health > 70.0 else (2 if _health > 35.0 else 1)
	get_tree().create_timer(FINISH_DELAY).timeout.connect(_build_result)


func _build_result() -> void:
	var layer := _new_layer()
	_menu.visible = true
	var text := "مأموریت کامل شد" if _victory else "مأموریت ناموفق"
	var title := _label(text, 62, COLOR_FRIEND if _victory else COLOR_ENEMY, FONT_BLACK)
	title.add_theme_color_override("font_shadow_color", Color(COLOR_FRIEND if _victory else COLOR_ENEMY, 0.45))
	title.add_theme_constant_override("shadow_outline_size", 12)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer.add_child(title)
	title.anchor_left = 0
	title.anchor_right = 1
	title.anchor_top = 0.36
	title.anchor_bottom = 0.36
	title.offset_top = 0
	title.offset_bottom = 90

	var objective := _label("هدف: %s٪" % _fa(_kills * KILL_PERCENT), 22)
	objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer.add_child(objective)
	objective.anchor_right = 1
	objective.anchor_top = 0.36
	objective.anchor_bottom = 0.36
	objective.offset_top = 96
	objective.offset_bottom = 132

	var strip := Panel.new()
	strip.add_theme_stylebox_override("panel", _style(COLOR_PANEL, 0))
	layer.add_child(strip)
	strip.anchor_top = 1
	strip.anchor_bottom = 1
	strip.anchor_right = 1
	strip.offset_left = 40
	strip.offset_right = -40
	strip.offset_top = -150
	strip.offset_bottom = -30

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.layout_direction = Control.LAYOUT_DIRECTION_LTR
	row.add_theme_constant_override("separation", 26)
	strip.add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_right = -14
	row.offset_top = 12
	row.offset_bottom = -12
	row.add_child(_score("soldier", _soldiers_killed, SOLDIER_REWARD))
	row.add_child(_score("jeep", _vehicles_killed, VEHICLE_REWARD))

	var collect := VBoxContainer.new()
	collect.custom_minimum_size.x = 270
	collect.add_theme_constant_override("separation", 4)
	row.add_child(collect)
	var total := HBoxContainer.new()
	total.alignment = BoxContainer.ALIGNMENT_END
	total.add_theme_constant_override("separation", 8)
	collect.add_child(total)
	var cash := TextureRect.new()
	cash.texture = load("res://assets/icons/cash.svg")
	cash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cash.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cash.custom_minimum_size = Vector2(34, 34)
	total.add_child(cash)
	total.add_child(_label(_fa(_reward()), 28, Color.WHITE, FONT_BLACK))
	var button := _action_button("دریافت" if _victory else "بازگشت", _collect)
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	collect.add_child(button)


func _score(icon_id: String, count: int, each: int) -> Control:
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 0)
	var tag := _label("×" + _fa(count), 16, COLOR_FRIEND)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(tag)
	var box := _intel_icon(icon_id)
	box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(box)
	var price := _label(_fa(each), 16, COLOR_FRIEND)
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(price)
	return column


func _collect() -> void:
	GameState.cash += _reward()
	get_tree().reload_current_scene()


func _draw() -> void:
	if _state == State.BRIEFING:
		_draw_friend_box(true)
	elif _state == State.RUNNING:
		_draw_battle_hud()
	elif _state == State.FINISHED and _layer.get_child_count() > 0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.45))
		for star in (3 if _victory else 0):
			var scale_size := 56.0 if star == 1 else 42.0
			var spot := Vector2(size.x / 2 + (star - 1) * 120, size.y * 0.27 + (0 if star == 1 else 14))
			_draw_star(spot, scale_size, COLOR_STAR if star < _stars else Color(1, 1, 1, 0.2))


func _draw_star(centre: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	for point in 10:
		var reach := radius if point % 2 == 0 else radius * 0.42
		points.append(centre + Vector2.from_angle(-PI / 2 + TAU * point / 10) * reach)
	draw_colored_polygon(points, color)


func _draw_friend_box(labelled: bool) -> void:
	var spot: Vector2 = _field.screen_point(FRIENDLY_SPOT + Vector3.UP)
	var half := Vector2(52, 34)
	draw_rect(Rect2(spot - half, half * 2), COLOR_FRIEND, false, 2.0)
	if labelled:
		_text("محافظت", spot + Vector2(0, half.y + 18), 15, COLOR_FRIEND)


func _text(text: String, centre: Vector2, font_size: int, color: Color) -> void:
	draw_string(FONT_BOLD, centre - Vector2(150, 0), text, HORIZONTAL_ALIGNMENT_CENTER, 300, font_size, color)


func _draw_battle_hud() -> void:
	var centre := size / 2
	_draw_compass()
	for rocket in _incoming:
		_draw_landing(_field.screen_point(rocket.spot), rocket.left / _field.ROCKET_FLIGHT)
	_draw_markers(centre)
	_draw_crosshair(centre)

	var bar := Rect2(centre.x - 95, 16, 190, 22)
	draw_rect(bar, Color(0, 0, 0, 0.55))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * _health / 100.0, bar.size.y)), COLOR_FRIEND)
	_text("%s٪" % _fa(int(ceilf(_health))), Vector2(centre.x, 33), 15, Color(0.04, 0.1, 0.06))
	_text("هدف: %s٪" % _fa(_kills * KILL_PERCENT), Vector2(size.x - 110, size.y - 46), 20, Color.WHITE)

	draw_circle(_exit_centre(), 22, Color(0, 0, 0, 0.5))
	for line in 3:
		var y: float = _exit_centre().y - 7 + line * 7
		draw_line(Vector2(_exit_centre().x - 10, y), Vector2(_exit_centre().x + 10, y), Color.WHITE, 2.0)

	var firing := _gun_finger >= 0 or _key_fire
	_draw_round_button(_gun_centre(), 50.0, firing)
	for bullet in 3:
		var y: float = _gun_centre().y - 17 + bullet * 14
		draw_rect(Rect2(_gun_centre().x - 24, y, 44, 9), Color.WHITE)
	_text(_fa(_ammo), _gun_centre() + Vector2(58, 48), 16, Color.WHITE)

	_draw_round_button(_rocket_centre(), 34.0, false)
	if _rocket_timer > 0.0:
		var ready_share := 1.0 - _rocket_timer / ROCKET_COOLDOWN
		draw_arc(_rocket_centre(), 34.0, -PI / 2, -PI / 2 + TAU * ready_share, 48, COLOR_ACCENT, 4.0, true)
	var tint := Color.WHITE if _rocket_timer <= 0.0 and _rockets > 0 else Color(1, 1, 1, 0.35)
	draw_texture_rect(WEAPON_ICON, Rect2(_rocket_centre() - Vector2(20, 20), Vector2(40, 40)), false, tint)
	_text(_fa(_rockets), _rocket_centre() + Vector2(46, 32), 16, Color.WHITE)

	_draw_round_button(_zoom_centre(), 30.0, _zoomed)
	_text("X2" if _zoomed else "X1", _zoom_centre() + Vector2(0, 7), 18, Color.WHITE)


func _draw_round_button(centre: Vector2, radius: float, active: bool) -> void:
	draw_circle(centre, radius, Color(0.03, 0.05, 0.06, 0.7))
	draw_arc(centre, radius, 0, TAU, 48, COLOR_ACCENT if active else Color(1, 1, 1, 0.75), 3.0, true)


func _draw_crosshair(centre: Vector2) -> void:
	var color := Color(1, 1, 1, 0.8)
	var push := _crosshair_spread * 16.0
	draw_line(centre + Vector2(-112 - push, 0), centre + Vector2(-26 - push, 0), color, 1.5)
	draw_line(centre + Vector2(26 + push, 0), centre + Vector2(112 + push, 0), color, 1.5)
	draw_line(centre + Vector2(0, -72 - push), centre + Vector2(0, -22 - push), color, 1.5)
	draw_line(centre + Vector2(0, 22 + push), centre + Vector2(0, 72 + push), color, 1.5)
	for tick: float in [-112.0, -70.0, 70.0, 112.0]:
		var x := tick + signf(tick) * push
		draw_line(centre + Vector2(x, -5), centre + Vector2(x, 5), color, 1.5)
	for tick: float in [-72.0, 72.0]:
		var y := tick + signf(tick) * push
		draw_line(centre + Vector2(-9, y), centre + Vector2(9, y), color, 1.5)
	if _hit_marker > 0.0:
		var mark := COLOR_ENEMY if _hit_killed else Color.WHITE
		mark.a = _hit_marker / HIT_MARKER_TIME
		for corner: Vector2 in [Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]:
			draw_line(centre + corner * 9.0, centre + corner * 20.0, mark, 2.5, true)


func _draw_compass() -> void:
	var aim: Vector3 = _field.aim_point
	var marks := {"شمال": Vector3(0, 0, -24), "شرق": Vector3(24, 0, 0), "جنوب": Vector3(0, 0, 24), "غرب": Vector3(-24, 0, 0)}
	for word: String in marks:
		_text(word, _field.screen_point(aim + marks[word]), 14, Color(1, 1, 1, 0.75))


func _draw_markers(centre: Vector2) -> void:
	var view := Rect2(Vector2.ZERO, size).grow(-30)
	var friend: Vector2 = _field.screen_point(FRIENDLY_SPOT + Vector3.UP)
	if view.has_point(friend):
		_draw_friend_box(false)
	else:
		_draw_arrow(centre, friend, COLOR_FRIEND)
	for enemy in _enemies:
		if not enemy.alive:
			continue
		var spot: Vector2 = _field.screen_point(enemy.node.global_position + Vector3.UP)
		if view.has_point(spot):
			var radius := 26.0 if enemy.kind == "vehicle" else 18.0
			_draw_diamond(spot, radius)
			_draw_health_bar(spot + Vector2(0, radius + 8), enemy.health / enemy.max_health)
			if enemy.kind == "vehicle":
				_text("خودروی دشمن نزدیک می‌شود", spot + Vector2(0, -36), 15, Color.WHITE)
		else:
			_draw_arrow(centre, spot, COLOR_ENEMY)


## A ring that closes on the impact point as the rocket falls.
func _draw_landing(spot: Vector2, left: float) -> void:
	draw_arc(spot, 16.0 + 46.0 * left, 0, TAU, 40, Color(COLOR_ENEMY, 0.85), 2.0, true)
	draw_circle(spot, 3.0, COLOR_ENEMY)


func _draw_health_bar(centre: Vector2, share: float) -> void:
	var bar := Rect2(centre - Vector2(24, 2.5), Vector2(48, 5))
	draw_rect(bar.grow(1.0), Color(0, 0, 0, 0.7))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * share, bar.size.y)), COLOR_ENEMY)


func _draw_diamond(spot: Vector2, radius: float) -> void:
	var points := PackedVector2Array([spot + Vector2(0, -radius), spot + Vector2(radius, 0), spot + Vector2(0, radius),
			spot + Vector2(-radius, 0), spot + Vector2(0, -radius)])
	draw_polyline(points, COLOR_ENEMY, 2.0, true)


func _draw_arrow(centre: Vector2, target: Vector2, color: Color) -> void:
	var direction := (target - centre).normalized()
	var tip := centre + direction * 170.0
	var side := direction.orthogonal() * 9.0
	draw_colored_polygon(PackedVector2Array([tip, tip - direction * 18.0 + side, tip - direction * 18.0 - side]), color)
