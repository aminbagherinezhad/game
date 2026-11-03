extends Node3D
## Live menu background: an embattled coastal base filmed from a drone high above.
## Road, pad and crater positions must match tools/generate_textures.py.

signal exploded(spot: Vector3, radius: float)

const MISSION_SPOTS: Array[Vector3] = [
	Vector3(16, 0, 30),
	Vector3(-70, 0, 40),
	Vector3.ZERO,
]
const ROAD_V_X := 16.0
const ROAD_H_Z := 34.0
const CAMERA_OFFSET := Vector3(0, 58, 42)
## Moves the subject to the right, clear of the mission text.
const VIEW_SHIFT := Vector3(-16, 0, -4)
const STRIKE_DELAY := Vector2(6, 11)
const DRONE_OFFSET := Vector3(0, 60, 26)
const DRONE_ORBIT_SPEED := 0.05
const DRONE_FOV := 34.0
const DRONE_ZOOM_FOV := 20.0
const AIM_LIMIT := 75.0
const ROCKET_FLIGHT := 1.0
## The Kheibar's blast is held back a little compared with a heavy bomb.
const ROCKET_WAVE := 0.7
const ROCKET_KICK_METRES := 2.2
const ROCKET_KICK_FOV := 1.6
const LAUNCH_SOUND := preload("res://assets/sounds/rocket_launch.wav")
const EXPLOSION_SOUND := preload("res://assets/sounds/explosion.wav")
const IMPACT_POOL_SIZE := 8
const BULLET_MARKS := 140
const BULLET_FLIGHT := 0.09
const TRACER_POOL_SIZE := 6
const TRACER_LENGTH := 7.0
const GUN_KICK_METRES := 0.42
const GUN_KICK_FOV := 0.5
const WIND := Vector3(1.4, 0, 0.5)
const MIN_3D_SCALE := 0.5
const LOW_FPS := 45.0
const QUALITY_CHECK_SECONDS := 2.0
const CRATER_VARIANTS := 3
## Every third shell is a heavy bomb that whites out the whole feed.
const HEAVY_STRIKE_EVERY := 3
const SHAKE_METRES := 3.2
const BLAST_RADIUS := 12.0
const DEBRIS_GRAVITY := 30.0
const MAX_LANDED_DEBRIS := 40
## Destroyed targets are swapped for fresh ones under a heavy bomb's white flash.
const WRECK_SECONDS := 25.0
const SHAKE_ROLL := 0.035
const MAX_CRATERS := 40
## Footprints shells avoid, so they land on open ground: x, z, width, depth.
const BLOCKED_AREAS: Array[Rect2] = [
	Rect2(-34, -40, 16, 22),
	Rect2(24, -40, 40, 84),
	Rect2(-24, -60, 80, 20),
	Rect2(-14, -6, 18, 16),
	Rect2(-92, 8, 56, 56),
]

const FIRE_COLORS := [Color(1, 1, 1, 0), Color(1, 1, 1, 0.7), Color(0.7, 0.7, 0.7, 0.35), Color(0.1, 0.1, 0.1, 0)]
const FLASH_COLORS := [Color(1, 1, 1, 1), Color(1, 1, 1, 0.8), Color(0.8, 0.8, 0.8, 0)]
const SPARK_COLORS := [Color(1, 1, 1, 1), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0)]
const SMOKE_COLORS := [Color(0.3, 0.3, 0.3, 0), Color(0.34, 0.34, 0.34, 0.7), Color(0.44, 0.44, 0.44, 0.4), Color(0.55, 0.55, 0.55, 0)]
const DUST_COLORS := [Color(0.34, 0.34, 0.34, 0), Color(0.3, 0.3, 0.3, 0.95), Color(0.38, 0.38, 0.38, 0.6), Color(0.46, 0.46, 0.46, 0)]
const DIRT_COLORS := [Color(0.03, 0.03, 0.03, 1), Color(0.05, 0.05, 0.05, 0.95), Color(0.14, 0.14, 0.14, 0)]
const HAZE_COLORS := [Color(0.7, 0.7, 0.7, 0), Color(0.7, 0.7, 0.7, 0.1), Color(0.7, 0.7, 0.7, 0)]

const GROUND_SHADER := preload("res://shaders/ground.gdshader")
const PALM_SHADER := preload("res://shaders/palm.gdshader")
const FLIPBOOK_SHADER := preload("res://shaders/flipbook.gdshader")
const BARREL_SCENE := preload("res://assets/models/Barrel_02/Barrel_02_1k.gltf")
const CRATE_SCENE := preload("res://assets/models/old_military_crate/old_military_crate_1k.gltf")
const TEXTURES := "res://assets/textures/"
const PUFF_FRAMES := 4
## Columns and rows of each explosion flipbook.
const SHEET_GRIDS := {
	"explosion_fire.png": Vector2(5, 5),
	"explosion_fire_b.png": Vector2(5, 5),
	"explosion_dust.png": Vector2(16, 4),
}

var _camera: Camera3D
var _focus := MISSION_SPOTS[2]
var _target := MISSION_SPOTS[2]
var _time := 0.0
var _movers: Array[Dictionary] = []
var _spinners: Array[Dictionary] = []
var _materials: Dictionary = {}
var _blueprints: Dictionary = {}
var _flames: Array[OmniLight3D] = []
var _shake := 0.0
var aim_point := Vector3.ZERO
var _mission_active := false
var _mission_centre := Vector3.ZERO
var _drone_yaw := 0.5
var _orbit_speed := 0.0
var _view_fov := DRONE_FOV
var _strike_timer: Timer
var _impacts: Array[GPUParticles3D] = []
var _next_impact := 0
var _tracers: Array[MeshInstance3D] = []
var _next_tracer := 0
var _marks: MultiMesh
var _next_mark := 0
var _kick := Vector3.ZERO
var _launch_sound: AudioStreamPlayer
var _explosion_sound: AudioStreamPlayer
var _strikes := 0
var _targets: Array[Dictionary] = []
var _debris: Array[Dictionary] = []
var _landed: Array[Node3D] = []
var _feed: ShaderMaterial
## Starts negative so the slow first frames do not count against the device.
var _quality_time := -3.0
var _quality_frames := 0
var _particle_ratio := 1.0
var _barrel_spots: Array[Transform3D] = []
var _crate_spots: Array[Transform3D] = []
var _craters: Array[MeshInstance3D] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 7
	_feed = get_node("../FeedEffect/Screen").material
	_build_environment()
	_build_ground()
	_build_palms()
	_build_base()
	_build_compound()
	_build_village()
	_build_jetty()
	_build_traffic()
	_build_fires()
	_build_haze()
	_build_props()
	_merge_all_meshes()
	_prewarm_effects()
	if OS.has_feature("mobile"):
		get_viewport().scaling_3d_scale = 0.7
		_particle_ratio = 0.75
	_queue_strike()


func _exit_tree() -> void:
	for blueprint: Node3D in _blueprints.values():
		blueprint.free()


func _process(delta: float) -> void:
	_time += delta
	_tune_quality(delta)
	_update_debris(delta)
	for mover in _movers:
		_update_mover(mover)
	for spinner in _spinners:
		spinner.node.rotate_y(spinner.speed * delta)

	_shake = move_toward(_shake, 0.0, delta * 0.9)
	var jolt := _shake * _shake
	var tremor := Vector3(sin(_time * 53.0) + sin(_time * 31.0), cos(_time * 47.0), sin(_time * 41.0) + cos(_time * 29.0)) * jolt * SHAKE_METRES
	if _mission_active:
		_drone_yaw += _orbit_speed * delta
		_focus = aim_point
		_camera.fov = lerpf(_camera.fov, _view_fov, 1.0 - exp(-delta * 9.0))
		_kick = _kick.lerp(Vector3.ZERO, 1.0 - exp(-delta * 16.0))
		_camera.position = aim_point + DRONE_OFFSET.rotated(Vector3.UP, _drone_yaw) + tremor + _kick
		_camera.look_at(aim_point + tremor * 0.25 + _kick * 0.35)
	else:
		_focus = _focus.lerp(_target, 1.0 - exp(-delta * 1.1))
		var drift := Vector3(sin(_time * 0.11) * 4.0, 0, cos(_time * 0.08) * 2.5)
		var angle := sin(_time * 0.05) * 0.1
		_camera.position = _focus + drift + CAMERA_OFFSET.rotated(Vector3.UP, angle) + tremor
		_camera.look_at(_focus + VIEW_SHIFT + drift * 0.6 + tremor * 0.25)
	_camera.rotate_object_local(Vector3.FORWARD, sin(_time * 37.0) * jolt * SHAKE_ROLL)

	for i in _flames.size():
		_flames[i].light_energy = 8.0 + sin(_time * 9.0 + i) + sin(_time * 14.0 + i * 2.0)


## Draws one tiny copy of each effect while the screen is still black, so the first
## real explosion does not stall on compiling shaders.
func _prewarm_effects() -> void:
	var spot := _focus + VIEW_SHIFT
	var layers: Array[Node] = [
		_play_flipbook("explosion_fire.png", spot, 0.2, 0.3, true, 1.0, 1.0),
		_play_flipbook("explosion_dust.png", spot, 0.2, 0.3, false, 1.0, 1.0),
		_play_flipbook("explosion_fire_b.png", spot, 0.2, 0.3, true, 1.0, 1.0),
		_add_mesh(self, _shard_mesh(0), spot, _shard_material()),
		_add_box(self, Vector3.ONE * 0.05, spot, _textured("camo.jpg", "", 0.22, 0.95, 0.13)),
		_burst(spot, 1, 0.2, SPARK_COLORS, true, 10.0, Vector2.ONE, Vector2(0.05, 0.05)),
		_burst(spot, 1, 0.2, DUST_COLORS, false, 10.0, Vector2.ONE, Vector2(0.05, 0.05)),
	]
	var mesh := PlaneMesh.new()
	mesh.size = Vector2.ONE * 0.05
	layers.append(_add_mesh(self, mesh, spot, _crater_material(0)))
	var tween := create_tween()
	tween.tween_interval(0.3)
	for layer in layers.slice(3):
		tween.tween_callback(layer.queue_free)


## Trades sharpness, then particles, for a steady frame rate on weaker devices.
func _tune_quality(delta: float) -> void:
	_quality_time += delta
	if _quality_time < 0.0:
		return
	_quality_frames += 1
	if _quality_time < QUALITY_CHECK_SECONDS:
		return
	var fps := _quality_frames / _quality_time
	_quality_time = 0.0
	_quality_frames = 0
	if fps >= LOW_FPS:
		return
	var viewport := get_viewport()
	if viewport.scaling_3d_scale > MIN_3D_SCALE:
		viewport.scaling_3d_scale = maxf(viewport.scaling_3d_scale - 0.1, MIN_3D_SCALE)
	else:
		_particle_ratio = maxf(_particle_ratio - 0.25, 0.25)


## Flies the camera over the area of the selected mission.
func focus_mission(index: int) -> void:
	_target = MISSION_SPOTS[index]


## Stops the menu's random shelling and road traffic and takes over the camera.
func begin_mission(centre: Vector3) -> void:
	_mission_active = true
	_mission_centre = centre
	aim_point = centre
	_strike_timer.stop()
	for target in _targets.duplicate():
		if not target.mover.is_empty():
			_movers.erase(target.mover)
			if target.wreck == null:
				var traffic: Node3D = target.node
				_spinners = _spinners.filter(func(spinner: Dictionary) -> bool: return not traffic.is_ancestor_of(spinner.node))
				traffic.queue_free()
			_targets.erase(target)
	_build_gun_effects()
	_launch_sound = _add_sound(LAUNCH_SOUND, -4.0)
	_explosion_sound = _add_sound(EXPLOSION_SOUND, -2.0)


func _add_sound(stream: AudioStream, volume: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume
	player.max_polyphony = 4
	add_child(player)
	return player


func _build_gun_effects() -> void:
	for i in IMPACT_POOL_SIZE:
		var grit := _burst(Vector3.DOWN * 5.0, 7, 0.75, DIRT_COLORS, false, 26.0, Vector2(7, 17), Vector2(0.35, 0.8))
		grit.process_material.gravity = Vector3(0, -26, 0)
		grit.process_material.scale_curve = null
		var drift := _burst(Vector3.DOWN * 5.0, 3, 1.5, SMOKE_COLORS, false, 40.0, Vector2(1, 2.5), Vector2(3.0, 5.5))
		grit.emitting = false
		drift.emitting = false
		_impacts.append(grit)
		_impacts.append(drift)

	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color.WHITE
	for i in TRACER_POOL_SIZE:
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.1, 0.1, TRACER_LENGTH)
		var tracer := _add_mesh(self, mesh, Vector3.DOWN * 5.0, glow)
		tracer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		tracer.visible = false
		_tracers.append(tracer)

	var mark := PlaneMesh.new()
	mark.size = Vector2.ONE
	_marks = MultiMesh.new()
	_marks.transform_format = MultiMesh.TRANSFORM_3D
	_marks.mesh = mark
	_marks.instance_count = BULLET_MARKS
	_marks.visible_instance_count = 0
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = _marks
	instance.material_override = _crater_material(0)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.custom_aabb = AABB(Vector3(-300, -1, -300), Vector3(600, 2, 600))
	add_child(instance)


func start_drone_flight() -> void:
	_orbit_speed = DRONE_ORBIT_SPEED


## Moves the aim, which is always the ground under the centre of the screen.
func move_aim(drag: Vector2) -> void:
	var right := _camera.global_basis.x
	right.y = 0.0
	var down := _camera.global_basis.z
	down.y = 0.0
	var distance := DRONE_OFFSET.length()
	var metres := 2.0 * distance * tan(deg_to_rad(_camera.fov) / 2.0) / get_viewport().get_visible_rect().size.y
	aim_point += (right.normalized() * drag.x + down.normalized() * drag.y) * metres
	aim_point = _mission_centre + (aim_point - _mission_centre).limit_length(AIM_LIMIT)


func set_zoom(zoomed: bool) -> void:
	_view_fov = DRONE_ZOOM_FOV if zoomed else DRONE_FOV


func screen_point(spot: Vector3) -> Vector2:
	return _camera.unproject_position(spot)


## One cannon round: the camera kicks, a tracer streaks down, and `landed` runs on impact.
func fire_round(spot: Vector3, landed: Callable) -> void:
	_kick += (Vector3(randf_range(-0.5, 0.5), 0, 1.0).rotated(Vector3.UP, _drone_yaw)) * GUN_KICK_METRES
	_camera.fov += GUN_KICK_FOV
	var from := _camera.global_position + _camera.global_basis.x * 7.0 + _camera.global_basis.y * -9.0
	var tracer := _tracers[_next_tracer]
	_next_tracer = (_next_tracer + 1) % _tracers.size()
	tracer.visible = true
	tracer.look_at_from_position(from, spot)
	var tween := create_tween()
	tween.tween_property(tracer, "global_position", spot, BULLET_FLIGHT)
	tween.tween_callback(func() -> void:
		tracer.visible = false
		_round_impact(spot)
		landed.call())


## A heavy round throws up a white burst of earth, grit that falls back, and drifting dust.
func _round_impact(spot: Vector3) -> void:
	var size := _rng.randf_range(7.0, 10.0)
	_play_flipbook("explosion_fire_b.png", spot + Vector3.UP * 1.2, size, 1.5, true, 1.9, 1.0)
	for layer in 2:
		var impact := _impacts[_next_impact + layer]
		impact.position = spot + Vector3.UP * 0.4
		impact.restart()
	_next_impact = (_next_impact + 2) % _impacts.size()

	var mark := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * _rng.randf_range(1.2, 2.2))
	var lift := 0.03 + 0.0004 * _next_mark
	_marks.set_instance_transform(_next_mark, Transform3D(mark, Vector3(spot.x, lift, spot.z)))
	_next_mark = (_next_mark + 1) % BULLET_MARKS
	_marks.visible_instance_count = mini(_marks.visible_instance_count + 1, BULLET_MARKS)


## The Kheibar leaves the drone with a jolt and streaks down on a column of smoke.
func fire_rocket(spot: Vector3) -> void:
	_kick += Vector3(randf_range(-0.4, 0.4), 0, 1.0).rotated(Vector3.UP, _drone_yaw) * ROCKET_KICK_METRES
	_camera.fov += ROCKET_KICK_FOV
	_shake = maxf(_shake, 0.35)
	_launch_sound.pitch_scale = randf_range(0.96, 1.04)
	_launch_sound.play()

	# Starts part way down, just outside the frame, so it streaks in across the picture.
	var from := _camera.global_position.lerp(spot, 0.45) + _camera.global_basis.x * 24.0 - _camera.global_basis.y * 12.0
	var rocket := _add_box(self, Vector3(0.5, 0.5, 3.4), from, _plain(0.95))
	rocket.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rocket.look_at_from_position(from, spot)

	var smoke := StandardMaterial3D.new()
	smoke.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smoke.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke.albedo_color = Color(0.82, 0.82, 0.82, 0.72)
	var column := BoxMesh.new()
	column.size = Vector3(0.42, 0.42, 1.0)
	var trail := _add_mesh(self, column, from, smoke)
	trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var tween := create_tween()
	tween.tween_method(func(t: float) -> void:
		var point := from.lerp(spot, t)
		rocket.position = point
		if point.distance_to(from) > 0.1:
			trail.look_at_from_position((from + point) / 2.0, spot)
			trail.scale.z = point.distance_to(from), 0.0, 1.0, ROCKET_FLIGHT).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		rocket.queue_free()
		_explode(spot, false, ROCKET_WAVE))
	var fade := tween.tween_method(func(t: float) -> void:
		smoke.albedo_color.a = 0.72 * (1.0 - t)
		trail.scale.x = 1.0 + t * 7.0
		trail.scale.y = trail.scale.x, 0.0, 1.0, 1.3)
	fade.set_ease(Tween.EASE_OUT)
	tween.tween_callback(trail.queue_free)


## Armour only blows up once its health runs out, however close a blast lands.
func destroy_armour(target: Dictionary) -> void:
	target.armoured = false
	var spot: Vector3 = target.node.global_position
	_explode(Vector3(spot.x, 0, spot.z))


func add_friendly(spot: Vector3, degrees: float) -> Node3D:
	var humvee := _make_humvee(0.86)
	humvee.position = spot
	humvee.rotation.y = deg_to_rad(degrees)
	add_child(humvee)
	_merge_meshes(humvee, [])
	return humvee


func add_enemy_vehicle(from: Vector3, to: Vector3) -> Dictionary:
	var heading := to - from
	_add_target(_make_humvee.bind(0.62, true), from, rad_to_deg(atan2(-heading.z, heading.x)))
	var target: Dictionary = _targets.back()
	target.armoured = true
	_merge_target(target.node)
	return target


## An infantryman about 1.8 m tall: jointed legs and arms, a vest, pack, helmet and rifle.
## The pieces are named in a rig, which animate_soldier() poses every frame.
func add_soldier(spot: Vector3) -> Node3D:
	var soldier := Node3D.new()
	var rig := Node3D.new()
	rig.name = "Rig"
	soldier.add_child(rig)
	var cloth := _textured("camo.jpg", "", 1.4, 0.95, 0.95)
	var trousers := _textured("camo.jpg", "", 1.4, 0.95, 0.7)
	var gear := _plain(0.14)
	var skin := _plain(0.95)
	var helmet := _plain(0.3)
	var steel := _plain(0.06, 0.5)

	var body := Node3D.new()
	body.position = Vector3(0, 0.92, 0)
	rig.add_child(body)
	_add_box(body, Vector3(0.3, 0.52, 0.44), Vector3(0, 0.3, 0), cloth)
	_add_box(body, Vector3(0.34, 0.34, 0.5), Vector3(0.03, 0.34, 0), gear)
	_add_box(body, Vector3(0.22, 0.42, 0.36), Vector3(-0.27, 0.36, 0), _plain(0.2))
	_add_box(body, Vector3(0.1, 0.1, 0.12), Vector3(0, 0.6, 0), skin)
	_add_sphere(body, 0.12, Vector3(0.02, 0.72, 0), skin)
	_add_sphere(body, 0.17, Vector3(0, 0.79, 0), helmet, 0.72)

	var arms: Array[Node3D] = []
	var elbows: Array[Node3D] = []
	for side: float in [-1.0, 1.0]:
		var shoulder := Node3D.new()
		shoulder.position = Vector3(0.0, 0.5, side * 0.27)
		body.add_child(shoulder)
		_add_box(shoulder, Vector3(0.13, 0.3, 0.13), Vector3(0, -0.15, 0), cloth)
		var elbow := Node3D.new()
		elbow.position = Vector3(0, -0.3, 0)
		shoulder.add_child(elbow)
		_add_box(elbow, Vector3(0.12, 0.28, 0.12), Vector3(0, -0.14, 0), cloth)
		_add_box(elbow, Vector3(0.1, 0.1, 0.11), Vector3(0, -0.3, 0), skin)
		arms.append(shoulder)
		elbows.append(elbow)

	var rifle := Node3D.new()
	rifle.position = Vector3(0.22, 0.3, 0.1)
	body.add_child(rifle)
	_add_box(rifle, Vector3(0.95, 0.08, 0.09), Vector3(0.38, 0, 0), steel)
	_add_box(rifle, Vector3(0.3, 0.14, 0.08), Vector3(-0.08, -0.02, 0), gear)
	_add_box(rifle, Vector3(0.1, 0.18, 0.07), Vector3(0.2, -0.12, 0), steel)
	var flash := SphereMesh.new()
	flash.radius = 0.15
	flash.height = 0.3
	var muzzle := _add_mesh(rifle, flash, Vector3(1.0, 0, 0), _muzzle_material())
	muzzle.name = "Muzzle"
	muzzle.visible = false

	var hips: Array[Node3D] = []
	var knees: Array[Node3D] = []
	for side: float in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.position = Vector3(0, 0.92, side * 0.12)
		rig.add_child(hip)
		_add_box(hip, Vector3(0.2, 0.46, 0.21), Vector3(0, -0.23, 0), trousers)
		var knee := Node3D.new()
		knee.position = Vector3(0, -0.46, 0)
		hip.add_child(knee)
		_add_box(knee, Vector3(0.17, 0.42, 0.18), Vector3(0, -0.21, 0), trousers)
		_add_box(knee, Vector3(0.36, 0.1, 0.19), Vector3(0.08, -0.44, 0), gear)
		hips.append(hip)
		knees.append(knee)

	soldier.set_meta("rig", {body = body, arms = arms, elbows = elbows, rifle = rifle, muzzle = muzzle,
			hips = hips, knees = knees, aim = 0.0})
	_add_contact_shadow(soldier, Vector2(1.5, 1.5))
	soldier.position = spot
	add_child(soldier)
	return soldier


## Poses a soldier. `phase` is the stride; a soldier that is firing plants their feet,
## leans into the rifle and lifts it to the shoulder.
func animate_soldier(soldier: Node3D, phase: float, moving: bool, firing: bool) -> void:
	var rig: Dictionary = soldier.get_meta("rig")
	rig.aim = lerpf(rig.aim, 1.0 if firing else 0.0, 0.18)
	var aim: float = rig.aim
	var hips: Array = rig.hips
	var knees: Array = rig.knees
	if moving:
		var stride := sin(phase) * 0.7
		hips[0].rotation.z = stride
		hips[1].rotation.z = -stride
		knees[0].rotation.z = -maxf(cos(phase), 0.0) * 0.9
		knees[1].rotation.z = -maxf(-cos(phase), 0.0) * 0.9
		rig.body.position.y = 0.92 + absf(cos(phase)) * 0.05
	else:
		hips[0].rotation.z = 0.28
		hips[1].rotation.z = -0.22
		knees[0].rotation.z = -0.12
		knees[1].rotation.z = -0.3
		rig.body.position.y = 0.92
	rig.body.rotation.z = lerpf(-0.07, -0.16, aim)
	var arms: Array = rig.arms
	var elbows: Array = rig.elbows
	for side in 2:
		arms[side].rotation.z = lerpf(0.9, 1.5, aim)
		elbows[side].rotation.z = lerpf(0.6, 0.15, aim)
	rig.rifle.position.y = lerpf(0.3, 0.5, aim)
	rig.rifle.rotation.z = lerpf(-0.22, 0.0, aim)


func _muzzle_material() -> StandardMaterial3D:
	var key := "muzzle"
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color.WHITE
		_materials[key] = material
	return _materials[key]


func set_muzzle(node: Node3D, lit: bool) -> void:
	if node.has_meta("rig"):
		node.get_meta("rig").muzzle.visible = lit


## A shot soldier is thrown backwards and lies where they fall.
func drop_soldier(soldier: Node3D) -> void:
	set_muzzle(soldier, false)
	var rig: Node3D = soldier.get_node("Rig")
	var tween := create_tween().set_parallel()
	tween.tween_property(rig, "rotation:z", PI / 2, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(rig, "position:y", 0.22, 0.4)
	tween.tween_property(rig, "position:x", -0.5, 0.4)


func _build_environment() -> void:
	_camera = Camera3D.new()
	_camera.fov = 34
	_camera.near = 1.0
	_camera.far = 400
	add_child(_camera)
	_camera.make_current()

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, 132, 0)
	sun.light_energy = 1.75
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 135
	add_child(sun)

	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color.BLACK
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 0.42
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)


func _build_ground() -> void:
	var material := ShaderMaterial.new()
	material.shader = GROUND_SHADER
	material.set_shader_parameter("ground_map", load(TEXTURES + "ground_map.jpg"))
	material.set_shader_parameter("detail_map", load(TEXTURES + "detail_ground.jpg"))
	material.set_shader_parameter("detail_normal", load(TEXTURES + "detail_ground_normal.jpg"))

	var plane := PlaneMesh.new()
	plane.size = Vector2(600, 600)
	var ground := MeshInstance3D.new()
	ground.mesh = plane
	ground.material_override = material
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)


func _build_palms() -> void:
	var spots: Array[Vector3] = []
	for center: Vector3 in [Vector3(-40, 0, -14), Vector3(-48, 0, -38), Vector3(54, 0, 14), Vector3(52, 0, -40),
			Vector3(-62, 0, 12), Vector3(-92, 0, 30), Vector3(46, 0, 42), Vector3(-6, 0, 44)]:
		for i in _rng.randi_range(3, 6):
			spots.append(center + Vector3(_rng.randfn(0, 3.5), 0, _rng.randfn(0, 3.5)))

	var material := ShaderMaterial.new()
	material.shader = PALM_SHADER
	material.set_shader_parameter("frond", load(TEXTURES + "palm_frond.png"))

	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = _make_palm_mesh()
	multimesh.instance_count = spots.size()
	for i in spots.size():
		var turn := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * _rng.randf_range(0.8, 1.15))
		multimesh.set_instance_transform(i, Transform3D(turn, spots[i]))
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.material_override = material
	add_child(instance)


func _make_palm_mesh() -> Mesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var height := 8.0
	var lean := Vector3(1.0, 0, 0.4)
	var sides := 6
	for side in sides:
		var a := TAU * side / sides
		var b := TAU * (side + 1) / sides
		var low_a := Vector3(cos(a), 0, sin(a)) * 0.34
		var low_b := Vector3(cos(b), 0, sin(b)) * 0.34
		var high_a := Vector3(cos(a), 0, sin(a)) * 0.2 + Vector3(0, height, 0) + lean
		var high_b := Vector3(cos(b), 0, sin(b)) * 0.2 + Vector3(0, height, 0) + lean
		_add_palm_triangle(tool, [low_a, high_a, low_b], [0.0, 0.25, 0.0], Vector2(0.5, 0.995))
		_add_palm_triangle(tool, [low_b, high_a, high_b], [0.0, 0.25, 0.25], Vector2(0.5, 0.995))

	var crown := Vector3(0, height, 0) + lean
	var segments := 6
	for frond in 16:
		var angle := frond * 2.4
		var length := 4.6 + 1.0 * sin(frond * 1.7)
		var lift := 1.4 - 1.5 * (frond % 3) * 0.5
		var along := Vector3(cos(angle), 0, sin(angle))
		var across := Vector3(-along.z, 0, along.x) * 1.15
		for segment in segments:
			var t0 := float(segment) / segments
			var t1 := float(segment + 1) / segments
			var p0 := crown + along * length * t0 + Vector3.UP * (lift * t0 - 3.0 * t0 * t0)
			var p1 := crown + along * length * t1 + Vector3.UP * (lift * t1 - 3.0 * t1 * t1)
			var sway0 := 0.25 + t0
			var sway1 := 0.25 + t1
			tool.set_color(Color(sway0, 0, 0))
			_add_frond_vertex(tool, p0 - across, 0.0, t0, sway0)
			_add_frond_vertex(tool, p1 - across, 0.0, t1, sway1)
			_add_frond_vertex(tool, p1 + across, 1.0, t1, sway1)
			_add_frond_vertex(tool, p0 - across, 0.0, t0, sway0)
			_add_frond_vertex(tool, p1 + across, 1.0, t1, sway1)
			_add_frond_vertex(tool, p0 + across, 1.0, t0, sway0)
	tool.generate_normals()
	return tool.commit()


func _add_frond_vertex(tool: SurfaceTool, point: Vector3, u: float, t: float, sway: float) -> void:
	tool.set_color(Color(sway, 0, 0))
	tool.set_uv(Vector2(u, 1.0 - t))
	tool.add_vertex(point)


func _add_palm_triangle(tool: SurfaceTool, points: Array[Vector3], sway: Array[float], uv: Vector2) -> void:
	for i in 3:
		tool.set_color(Color(sway[i], 0, 0))
		tool.set_uv(uv)
		tool.add_vertex(points[i])


func _build_base() -> void:
	_add_target(_make_launcher, Vector3(-6, 0, 2), 155)

	_add_target(_make_tank, Vector3(-4, 0, -20), 200)
	_add_target(_make_tank, Vector3(-14, 0, -14), 165)
	_add_target(_make_truck.bind(true), Vector3(0, 0, 14), 90)
	_add_target(_make_truck.bind(false), Vector3(4, 0, -4), 90)

	for i in 5:
		_add_target(_make_container.bind(i), Vector3(-27 + (i % 2) * 0.3, 0, -30 + i * 3.2), 0)
	_add_target(_make_container.bind(2), Vector3(-27, 2.6, -27), 0)
	_scatter_props(Vector3(-14, 0, -32), 9)
	_scatter_props(Vector3(4, 0, -24), 6)


func _build_compound() -> void:
	_make_building(Vector3(40, 0, -14), Vector3(26, 7, 18))
	_make_building(Vector3(42, 0, 24), Vector3(18, 5, 14))
	_make_hangar(Vector3(-2, 0, -52), 90, 34, 9)
	_make_hangar(Vector3(38, 0, -56), 90, 30, 8)
	_make_hangar(Vector3(-46, 0, 2), 0, 28, 8)
	for car in 4:
		_add_target(_make_car.bind(car == 2, 0.2 + car * 0.16), Vector3(30, 0, 8 + car * 3.0), 180)
	_add_target(_make_car.bind(true, 0.42), Vector3(30, 0, -32), 90)
	_add_target(_make_car.bind(false, 0.62), Vector3(-12, 0, 28), 8)

	var tower := Node3D.new()
	tower.position = Vector3(25, 0, 42)
	add_child(tower)
	_build_watchtower(tower)

	# Perimeter fence along the road and the northern edge of the compound.
	_add_fence(Vector3(25, 0, -38), Vector3(25, 0, 42))
	_add_fence(Vector3(25, 0, 42), Vector3(62, 0, 42))
	_add_fence(Vector3(25, 0, -38), Vector3(62, 0, -38))
	_scatter_props(Vector3(32, 0, 8), 7)
	_add_sandbags(Vector3(21.6, 0, 6), 5)


func _build_village() -> void:
	var center: Vector3 = MISSION_SPOTS[1]
	_make_building(center + Vector3(-12, 0, -22), Vector3(13, 4, 10))
	_make_building(center + Vector3(10, 0, -24), Vector3(10, 3.5, 9))
	_make_building(center + Vector3(-16, 0, 16), Vector3(11, 4, 11))
	_make_building(center + Vector3(22, 0, 18), Vector3(12, 3.5, 9))

	var wreck := _make_truck(false)
	wreck.position = Vector3(-74, 0.1, 48)
	wreck.rotation = Vector3(0.05, 0.9, 0.08)
	add_child(wreck)
	_add_fire(wreck.position + Vector3(0, 1.4, 0))


func _build_jetty() -> void:
	var start: Vector3 = MISSION_SPOTS[0]
	var planks := _textured("planks.jpg", "", 0.25, 0.9)
	for plank in 28:
		_add_box(self, Vector3(0.95, 0.14, 4.4 + 0.2 * (plank % 2)), start + Vector3(plank, 0.8, 0), planks)
	for post in 8:
		_add_cylinder(self, 0.18, 1.6, start + Vector3(post * 4.0, 0.5, 2.3), Vector3.ZERO, _plain(0.16))
		_add_cylinder(self, 0.18, 1.6, start + Vector3(post * 4.0, 0.5, -2.3), Vector3.ZERO, _plain(0.16))
	_scatter_props(start + Vector3(8, 0.9, 0), 4)


func _build_traffic() -> void:
	var north := Vector3(ROAD_V_X + 2.1, 0, -130)
	var south := Vector3(ROAD_V_X + 2.1, 0, 130)
	_add_traffic(_make_truck.bind(true), north, south, 4.5, 0.0)
	_add_traffic(_make_truck.bind(false), north, south, 4.5, 150.0)
	_add_traffic(_make_tank, Vector3(-130, 0, ROAD_H_Z + 1.8), Vector3(ROAD_V_X, 0, ROAD_H_Z + 1.8), 3.5, 40.0)


func _build_fires() -> void:
	_add_fire(Vector3(46, 0.5, -30))
	_add_fire(Vector3(-26, 0.5, 28))


## Drops an artillery round on open ground around the current view.
func _queue_strike() -> void:
	_strike_timer = Timer.new()
	_strike_timer.one_shot = true
	_strike_timer.timeout.connect(_on_strike_timer)
	add_child(_strike_timer)
	_strike_timer.start(_rng.randf_range(STRIKE_DELAY.x, STRIKE_DELAY.y))


func _on_strike_timer() -> void:
	_strikes += 1
	_explode(_pick_strike_spot(), _strikes % HEAVY_STRIKE_EVERY == 0)
	_strike_timer.start(_rng.randf_range(STRIKE_DELAY.x, STRIKE_DELAY.y))


## Usually a live target in view, otherwise open ground near the camera's focus.
func _pick_strike_spot() -> Vector3:
	var in_view: Array[Vector3] = []
	for target in _targets:
		if target.wreck == null and target.node.global_position.distance_to(_target) < 45.0:
			in_view.append(target.node.global_position)
	if not in_view.is_empty() and _rng.randf() < 0.75:
		var aim: Vector3 = in_view[_rng.randi() % in_view.size()]
		return Vector3(aim.x + _rng.randf_range(-3, 3), 0, aim.z + _rng.randf_range(-3, 3))
	for attempt in 10:
		var spot := _target + Vector3(_rng.randf_range(-20, 40), 0, _rng.randf_range(-26, 12))
		if _is_open_ground(spot):
			return spot
	return _target


func _is_open_ground(spot: Vector3) -> bool:
	if _shore_distance(spot) > -4.0:
		return false
	for area in BLOCKED_AREAS:
		if area.has_point(Vector2(spot.x, spot.z)):
			return false
	return true


## Same shoreline as ground.gdshader; positive values are in the water.
func _shore_distance(spot: Vector3) -> float:
	return spot.x + 12.0 * sin(spot.z * 0.045) + 6.0 * sin(spot.z * 0.13 + 1.0) - 70.0


## Dust drifting low across the whole map.
func _build_haze() -> void:
	var haze := _particles(Vector3(-10, 3, -5), 6, 16.0, HAZE_COLORS, false)
	var process: ParticleProcessMaterial = haze.process_material
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(130, 1, 90)
	process.direction = Vector3(1, 0, 0.35)
	process.spread = 8.0
	process.initial_velocity_min = 2.0
	process.initial_velocity_max = 3.5
	process.scale_min = 26.0
	process.scale_max = 44.0
	haze.preprocess = 16.0


## Timed from the game's trailer: an instant of white, a chain of huge blasts with flying
## black debris and sparks, then everything tears into pale haze within about a second.
func _explode(spot: Vector3, heavy := false, wave := 1.0) -> void:
	var power := 1.8 if heavy else 1.0
	_shake = maxf(_shake, (1.0 if heavy else 0.8) * wave)
	_leave_crater(spot)
	_flash_sensor(spot, heavy, wave)
	_send_shock_wave(spot, wave)
	if _mission_active:
		_explosion_sound.pitch_scale = randf_range(0.9, 1.08)
		_explosion_sound.play()
	_destroy_targets_near(spot, BLAST_RADIUS * power)
	exploded.emit(spot, BLAST_RADIUS * power)
	if heavy:
		_repair_old_wrecks()

	_play_flipbook("explosion_dust.png", spot + Vector3.UP * 0.4, 58.0 * power * wave, 4.0, false, 1.0, 0.8)
	_play_flipbook("explosion_fire.png", spot + Vector3.UP * 7.0 * power, 40.0 * power * sqrt(wave), 3.0, true, 1.0, 1.0)
	for blast in 2 if heavy else 1:
		var offset := Vector3(_rng.randf_range(-9, 9), 5, _rng.randf_range(-7, 7)) * power
		get_tree().create_timer(_rng.randf_range(0.1, 0.3)).timeout.connect(_play_flipbook.bind(
			"explosion_fire_b.png", spot + offset, _rng.randf_range(24, 32) * power * sqrt(wave), 2.6, true, 1.0, 1.0))

	var sparks := _burst(spot + Vector3.UP, 18, 0.6, SPARK_COLORS, true, 66.0, Vector2(26, 54), Vector2(0.6, 1.1))
	var streak := QuadMesh.new()
	streak.size = Vector2(0.16, 2.6)
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	glow.vertex_color_use_as_albedo = true
	streak.material = glow
	sparks.draw_pass_1 = streak
	sparks.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY
	var sparks_process: ParticleProcessMaterial = sparks.process_material
	sparks_process.gravity = Vector3(0, -30, 0)
	sparks_process.scale_curve = null
	sparks_process.angle_min = 0.0
	sparks_process.angle_max = 0.0

	var flecks := _burst(spot + Vector3.UP * 2, 10, 0.7, SPARK_COLORS, true, 78.0, Vector2(14, 34), Vector2(0.8, 1.6))
	flecks.process_material.damping_min = 12.0
	flecks.process_material.damping_max = 20.0

	var chunks := _burst(spot + Vector3.UP * 0.5, 52, 2.0, DUST_COLORS, false, 62.0, Vector2(16, 52), Vector2(0.6, 3.4))
	var chunk := BoxMesh.new()
	chunk.size = Vector3(0.5, 0.2, 0.4)
	chunk.material = _plain(0.02)
	chunks.draw_pass_1 = chunk
	var chunks_process: ParticleProcessMaterial = chunks.process_material
	chunks_process.gravity = Vector3(0, -30, 0)
	chunks_process.color_ramp = null
	chunks_process.scale_curve = null
	chunks_process.angular_velocity_min = -400.0
	chunks_process.angular_velocity_max = 400.0

	var smoke := _burst(spot + Vector3.UP * 5, 8, 8.0, SMOKE_COLORS, false, 40.0, Vector2(3, 8), Vector2(18, 30))
	smoke.explosiveness = 0.4
	smoke.process_material.gravity = WIND * 1.5

	var embers := _particles(spot + Vector3.UP, 6, 6.0, SMOKE_COLORS, false)
	embers.process_material.scale_min = 2.0
	embers.process_material.scale_max = 4.0
	embers.process_material.initial_velocity_max = 3.0

	var light := OmniLight3D.new()
	light.omni_range = 80
	light.light_energy = 28 * wave
	light.position = spot + Vector3.UP * 8
	add_child(light)
	var tween := create_tween()
	tween.tween_property(light, "light_energy", 0.0, 1.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	tween.tween_callback(light.queue_free)
	tween.tween_interval(9.0)
	for layer: Node in [sparks, flecks, chunks, smoke]:
		tween.tween_callback(layer.queue_free)
	tween.tween_interval(8.0)
	tween.tween_callback(func() -> void: embers.emitting = false)
	tween.tween_interval(6.5)
	tween.tween_callback(embers.queue_free)


func _play_flipbook(sheet: String, spot: Vector3, size: float, seconds: float, face_camera: bool, brightness: float, opacity: float) -> MeshInstance3D:
	var material := ShaderMaterial.new()
	material.shader = FLIPBOOK_SHADER
	material.set_shader_parameter("sheet", load(TEXTURES + sheet))
	material.set_shader_parameter("grid", SHEET_GRIDS[sheet])
	# Fire rises, so a burst keeps roughly upright; a flat dust ring can spin freely.
	material.set_shader_parameter("turn", _rng.randf_range(-0.35, 0.35) if face_camera else _rng.randf() * TAU)
	material.set_shader_parameter("brightness", brightness)
	material.set_shader_parameter("opacity", opacity)
	material.set_shader_parameter("face_camera", face_camera)

	var mesh: Mesh
	if face_camera:
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE
		mesh = quad
	else:
		var plane := PlaneMesh.new()
		plane.size = Vector2.ONE
		mesh = plane
	var layer := MeshInstance3D.new()
	layer.mesh = mesh
	layer.material_override = material
	layer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	layer.position = spot
	layer.scale = Vector3.ONE * size
	layer.custom_aabb = AABB(Vector3(-1, -1, -1), Vector3(2, 2, 2))
	add_child(layer)

	var tween := create_tween()
	tween.tween_method(func(value: float) -> void: material.set_shader_parameter("progress", value), 0.0, 1.0, seconds)
	tween.tween_callback(layer.queue_free)
	return layer


func _send_shock_wave(spot: Vector3, wave: float) -> void:
	if _camera.is_position_behind(spot):
		return
	var viewport_size := get_viewport().get_visible_rect().size
	_feed.set_shader_parameter("shock_centre", _camera.unproject_position(spot) / viewport_size)
	var tween := create_tween().set_parallel()
	tween.tween_method(func(value: float) -> void: _feed.set_shader_parameter("shock_radius", value),
		0.02, 0.75, 0.55).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_method(func(value: float) -> void: _feed.set_shader_parameter("shock_strength", value),
		0.03 * wave, 0.0, 0.55)


## Overloads the sensor: a heavy bomb burns the picture fully white for a moment.
func _flash_sensor(spot: Vector3, heavy: bool, wave: float) -> void:
	var distance := Vector2(spot.x - _focus.x, spot.z - _focus.z).length()
	var strength := 1.0 if heavy else clampf(0.6 - distance / 180.0, 0.2, 0.45) * wave
	var set_flash := func(value: float) -> void: _feed.set_shader_parameter("flash", value)
	set_flash.call(strength)
	var tween := create_tween()
	tween.tween_interval(0.14 if heavy else 0.05)
	tween.tween_method(set_flash, strength, 0.0, 1.1 if heavy else 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)


## Merging a vehicle takes long enough to hitch a frame, and wrecks are built right as a
## shell lands, so each kind is built only once and then copied.
func _build(maker: Callable) -> Node3D:
	var key := "%s%s" % [maker.get_method(), maker.get_bound_arguments()]
	if not _blueprints.has(key):
		var blueprint: Node3D = maker.call()
		add_child(blueprint)
		_merge_target(blueprint)
		remove_child(blueprint)
		_blueprints[key] = blueprint
	var copy: Node3D = _blueprints[key].duplicate()
	for part in copy.get_children():
		if part.has_meta("traverses"):
			_spinners.append({node = part, speed = _rng.randf_range(-0.15, 0.15)})
	return copy


func _add_target(maker: Callable, spot: Vector3, degrees: float) -> void:
	var node := _build(maker)
	node.position = spot
	node.rotation.y = deg_to_rad(degrees)
	add_child(node)
	_targets.append({maker = maker, node = node, wreck = null, wrecked_at = 0.0, mover = {}})


func _add_traffic(maker: Callable, from: Vector3, to: Vector3, speed: float, offset: float) -> void:
	var node := _build(maker)
	_add_mover(node, from, to, speed, offset)
	_targets.append({maker = maker, node = node, wreck = null, wrecked_at = 0.0, mover = _movers.back()})


func _destroy_targets_near(spot: Vector3, radius: float) -> void:
	for target in _targets:
		if target.wreck == null and not target.get("armoured", false) and target.node.global_position.distance_to(spot) < radius:
			_destroy_target(target, spot)


## Real vehicles rarely fly apart: the hull stays, is shoved aside and settles at an angle,
## burnt out. A turret may be blown off, and small torn pieces of metal are thrown clear.
func _destroy_target(target: Dictionary, blast: Vector3) -> void:
	var old: Node3D = target.node
	var place := old.global_transform
	_spinners = _spinners.filter(func(spinner: Dictionary) -> bool: return not old.is_ancestor_of(spinner.node))
	_movers.erase(target.mover)
	old.free()

	var spinner_count := _spinners.size()
	var wreck := _build(target.maker)
	_spinners.resize(spinner_count)
	add_child(wreck)
	wreck.global_transform = place
	var away := (wreck.global_position - blast)
	away.y = 0
	away = away.normalized() if away.length() > 0.1 else Vector3.RIGHT
	var centre := wreck.global_position

	for part: Node3D in wreck.get_children():
		if part is MeshInstance3D and part.material_override.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			continue
		_char(part)
		if part.has_meta("can_fly_off") and _rng.randf() < 0.6:
			_launch_part(part, away, _rng.randf_range(11, 18), _rng.randf_range(3, 7), _rng.randf_range(1.2, 2.6))
	_merge_meshes(wreck, [])
	_shove_wreck(wreck, away)

	for shard in 7:
		var size := _rng.randf_range(0.25, 0.8)
		var piece := _add_mesh(self, _shard_mesh(shard % 3), centre + Vector3.UP * 1.2, _shard_material())
		piece.scale = Vector3.ONE * size
		_launch_part(piece, away, _rng.randf_range(9, 20), _rng.randf_range(4, 14), _rng.randf_range(3, 8))

	target.wreck = wreck
	target.wrecked_at = _time
	_burn_wreck(centre)


func _char(part: Node3D) -> void:
	_set_part_material(part, _textured("camo.jpg", "", 0.22, 0.95, 0.13))


func _set_part_material(part: Node3D, material: Material) -> void:
	for mesh: MeshInstance3D in part.find_children("*", "MeshInstance3D", true, false) + ([part] if part is MeshInstance3D else []):
		mesh.material_override = material


## The blast heaves the hull up and sideways; it comes down a little askew.
func _shove_wreck(wreck: Node3D, away: Vector3) -> void:
	var start := wreck.position
	var finish := start + away.rotated(Vector3.UP, _rng.randf_range(-0.5, 0.5)) * _rng.randf_range(0.8, 2.2)
	var rise := _rng.randf_range(0.8, 2.0)
	var from_rotation := wreck.quaternion
	var tilt := Quaternion.from_euler(Vector3(_rng.randf_range(-0.09, 0.09), _rng.randf_range(-0.3, 0.3), _rng.randf_range(-0.09, 0.09)))
	var to_rotation := from_rotation * tilt
	var tween := create_tween()
	tween.tween_method(func(t: float) -> void:
		wreck.position = start.lerp(finish, t) + Vector3.UP * rise * 4.0 * t * (1.0 - t)
		wreck.quaternion = from_rotation.slerp(to_rotation, t), 0.0, 1.0, 0.7)


## Jagged scraps of plate; three shapes are enough at this distance.
func _shard_mesh(shape: int) -> Mesh:
	var key := "shard|%d" % shape
	if not _materials.has(key):
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		var corners := 7
		var outline: Array[Vector3] = []
		for corner in corners:
			var angle := TAU * corner / corners
			var reach := _rng.randf_range(0.35, 1.0)
			outline.append(Vector3(cos(angle) * reach, _rng.randf_range(-0.12, 0.12), sin(angle) * reach * 0.7))
		for corner in corners:
			tool.add_vertex(Vector3.ZERO)
			tool.add_vertex(outline[(corner + 1) % corners])
			tool.add_vertex(outline[corner])
		tool.generate_normals()
		_materials[key] = tool.commit()
	return _materials[key]


func _shard_material() -> StandardMaterial3D:
	var key := "shard"
	if not _materials.has(key):
		var material := _textured("camo.jpg", "", 0.22, 0.8, 0.2).duplicate()
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_materials[key] = material
	return _materials[key]


func _launch_part(part: Node3D, away: Vector3, lift: float, drift: float, spin: float) -> void:
	var place := part.global_transform
	if part.get_parent() != self:
		part.get_parent().remove_child(part)
		add_child(part)
	part.global_transform = place
	var scatter := away.rotated(Vector3.UP, _rng.randf_range(-1.2, 1.2)) * drift
	var axis := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-0.4, 0.4), _rng.randf_range(-1, 1)).normalized()
	_debris.append({node = part, velocity = scatter + Vector3.UP * lift, axis = axis, spin = spin})


func _update_debris(delta: float) -> void:
	for piece in _debris.duplicate():
		var node: Node3D = piece.node
		var velocity: Vector3 = piece.velocity
		velocity.y -= DEBRIS_GRAVITY * delta
		node.position += velocity * delta
		node.rotate(piece.axis, piece.spin * delta)
		if node.position.y < 0.3 and velocity.y < 0.0:
			node.position.y = 0.3
			if velocity.y > -9.0:
				_debris.erase(piece)
				_landed.append(node)
				if _landed.size() > MAX_LANDED_DEBRIS:
					_landed.pop_front().queue_free()
				continue
			velocity = Vector3(velocity.x * 0.45, -velocity.y * 0.32, velocity.z * 0.45)
			piece.spin *= 0.5
		piece.velocity = velocity


func _burn_wreck(spot: Vector3) -> void:
	var fire := _particles(spot + Vector3.UP * 1.5, 8, 0.8, FIRE_COLORS, true)
	fire.process_material.scale_min = 1.5
	fire.process_material.scale_max = 3.0
	var smoke := _particles(spot + Vector3.UP * 3, 8, 8.0, SMOKE_COLORS, false)
	smoke.process_material.scale_min = 6.0
	smoke.process_material.scale_max = 11.0
	var tween := create_tween()
	tween.tween_interval(WRECK_SECONDS - 8.0)
	tween.tween_callback(func() -> void:
		fire.emitting = false
		smoke.emitting = false)
	tween.tween_interval(9.0)
	tween.tween_callback(fire.queue_free)
	tween.tween_callback(smoke.queue_free)


func _repair_old_wrecks() -> void:
	for target in _targets:
		if target.wreck == null or _time - target.wrecked_at < WRECK_SECONDS:
			continue
		var place: Transform3D = target.wreck.global_transform
		target.wreck.queue_free()
		target.wreck = null
		var node := _build(target.maker)
		add_child(node)
		_merge_target(node)
		target.node = node
		if target.mover.is_empty():
			node.global_transform = Transform3D(Basis(Vector3.UP, place.basis.get_euler().y), Vector3(place.origin.x, place.origin.y, place.origin.z))
		else:
			target.mover.node = node
			_movers.append(target.mover)
			node.rotation.y = atan2(-(target.mover.to - target.mover.from).z, (target.mover.to - target.mover.from).x)


## Stamps a lasting crater on the ground. The oldest one disappears once there are too many.
func _leave_crater(spot: Vector3) -> void:
	var size := _rng.randf_range(11, 17)
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(size, size)
	var crater := _add_mesh(self, mesh, spot, _crater_material(_rng.randi() % CRATER_VARIANTS))
	crater.position.y = 0.04 + 0.003 * (_craters.size() + 1)
	crater.rotation.y = _rng.randf() * TAU
	crater.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_craters.append(crater)
	if _craters.size() > MAX_CRATERS:
		_craters.pop_front().queue_free()


func _crater_material(variant: int) -> StandardMaterial3D:
	var key := "crater|%d" % variant
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_texture = load(TEXTURES + "crater_%d.png" % variant)
		material.normal_enabled = true
		material.normal_texture = load(TEXTURES + "crater_%d_normal.png" % variant)
		material.normal_scale = 1.6
		material.roughness = 1.0
		material.metallic_specular = 0.0
		_materials[key] = material
	return _materials[key]


func _burst(spot: Vector3, amount: int, lifetime: float, colors: Array, additive: bool, spread: float, speed: Vector2, scale_range: Vector2) -> GPUParticles3D:
	var layer := _particles(spot, amount, lifetime, colors, additive)
	layer.one_shot = true
	layer.explosiveness = 0.92
	var process: ParticleProcessMaterial = layer.process_material
	process.direction = Vector3.UP
	process.spread = spread
	process.initial_velocity_min = speed.x
	process.initial_velocity_max = speed.y
	process.scale_min = scale_range.x
	process.scale_max = scale_range.y
	return layer


## Combines parts that share a material, which cuts draw calls and shadow passes.
func _merge_all_meshes() -> void:
	var skipped: Array[Node] = []
	for target in _targets:
		skipped.append(target.node)
		_merge_target(target.node)
	for spinner in _spinners:
		if not skipped.any(func(node: Node) -> bool: return node.is_ancestor_of(spinner.node)):
			_merge_meshes(spinner.node, [])
			skipped.append(spinner.node)
	_merge_meshes(self, skipped)


func _merge_target(target: Node3D) -> void:
	var detached: Array[Node] = []
	for child in target.get_children():
		if child.has_meta("detachable"):
			_merge_meshes(child, [])
			detached.append(child)
	_merge_meshes(target, detached)


func _merge_meshes(root_node: Node3D, excluded: Array[Node]) -> void:
	var root_inverse := root_node.global_transform.affine_inverse()
	var tools: Dictionary = {}
	for part: MeshInstance3D in root_node.find_children("*", "MeshInstance3D", true, false):
		var material := part.material_override as StandardMaterial3D
		if material == null or excluded.any(func(node: Node) -> bool: return node.is_ancestor_of(part)):
			continue
		if not tools.has(material):
			tools[material] = SurfaceTool.new()
			tools[material].begin(Mesh.PRIMITIVE_TRIANGLES)
		tools[material].append_from(part.mesh, 0, root_inverse * part.global_transform)
		part.get_parent().remove_child(part)
		part.queue_free()
	for material: StandardMaterial3D in tools:
		var merged := _add_mesh(root_node, tools[material].commit(), Vector3.ZERO, material)
		if material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			merged.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _add_mover(node: Node3D, from: Vector3, to: Vector3, speed: float, offset: float) -> void:
	add_child(node)
	var heading := to - from
	node.rotation.y = atan2(-heading.z, heading.x)
	var mover := {node = node, from = from, to = to, speed = speed, offset = offset}
	_movers.append(mover)
	_update_mover(mover)


func _update_mover(mover: Dictionary) -> void:
	var from: Vector3 = mover.from
	var to: Vector3 = mover.to
	var length := from.distance_to(to)
	var travelled := fposmod(mover.offset + _time * mover.speed, length)
	mover.node.position = from.lerp(to, travelled / length)


func _make_tank() -> Node3D:
	var tank := Node3D.new()
	var armour := _camo()
	var dark := _plain(0.09)
	var steel := _plain(0.2)

	# Tracks with road wheels, under a fender and an armoured skirt.
	for side: float in [-1.0, 1.0]:
		var belt: Array[PackedVector3Array] = []
		for stage: Vector3 in [Vector3(-3.78, 0.55, 0.86), Vector3(-3.45, 0.14, 1.04), Vector3(-2.85, 0.02, 1.08), Vector3(2.7, 0.02, 1.08), Vector3(3.45, 0.24, 1.12), Vector3(3.86, 0.66, 1.02)]:
			belt.append(_ring(stage.x, stage.y, stage.z, 0.33, 0.33, 0.33))
		_add_loft(tank, belt, Vector3(0, 0, side * 1.58), dark)
		for wheel in 6:
			_add_wheel(tank, 0.42, 0.14, Vector3(-2.75 + wheel * 1.03, 0.46, side * 1.86), steel, dark)
		_add_wheel(tank, 0.34, 0.14, Vector3(3.42, 0.68, side * 1.86), steel, dark)
		_add_wheel(tank, 0.32, 0.14, Vector3(-3.42, 0.62, side * 1.86), steel, dark)
		_add_box(tank, Vector3(7.0, 0.07, 0.8), Vector3(0, 1.1, side * 1.56), armour)
		_add_box(tank, Vector3(5.6, 0.42, 0.07), Vector3(-0.2, 0.92, side * 1.96), armour)
		for seam in 5:
			_add_box(tank, Vector3(0.05, 0.44, 0.09), Vector3(-1.9 + seam * 0.85, 0.92, side * 1.96), dark)
		_add_box(tank, Vector3(1.1, 0.3, 0.46), Vector3(-1.6, 1.28, side * 1.6), armour)
		_add_box(tank, Vector3(0.7, 0.26, 0.46), Vector3(0.1, 1.26, side * 1.6), _plain(0.3))
		for strap: float in [-1.85, -1.35]:
			_add_box(tank, Vector3(0.05, 0.32, 0.5), Vector3(strap, 1.28, side * 1.6), dark)
		_add_cylinder(tank, 0.12, 0.1, Vector3(3.3, 1.27, side * 1.5), Vector3(0, 0, -PI / 2), _glow(0.6), 8)
		_add_box(tank, Vector3(0.05, 0.3, 0.3), Vector3(3.42, 1.27, side * 1.5), steel)

	var hull: Array[PackedVector3Array] = [
		_ring(-3.58, 0.5, 1.28, 1.0, 1.22, 1.15),
		_ring(-3.3, 0.45, 1.42, 1.05, 1.24, 1.2),
		_ring(2.0, 0.45, 1.46, 1.05, 1.24, 1.2),
		_ring(3.5, 0.55, 0.92, 1.05, 1.24, 1.2),
		_ring(3.78, 0.6, 0.72, 1.0, 1.18, 1.12),
	]
	_add_loft(tank, hull, Vector3.ZERO, armour)

	# Reactive armour bricks on the glacis.
	for row in 3:
		for brick in 5:
			var along := 0.28 + row * 0.42
			_add_box(tank, Vector3(0.36, 0.1, 0.4), Vector3(2.0 + along * 0.94, 1.5 - along * 0.34, -0.92 + brick * 0.46), armour).rotation = Vector3(0, 0, -0.34)
	_add_cylinder(tank, 0.3, 0.1, Vector3(1.95, 1.5, 0), Vector3.ZERO, armour)
	_add_box(tank, Vector3(0.14, 0.12, 0.5), Vector3(2.2, 1.5, 0), dark)

	# The engine deck is the hottest thing on a tank, seen through a white-hot sensor.
	_add_box(tank, Vector3(1.7, 0.05, 2.0), Vector3(-2.4, 1.45, 0), _glow(0.6))
	for grille in 9:
		_add_box(tank, Vector3(0.07, 0.07, 2.04), Vector3(-3.15 + grille * 0.19, 1.48, 0), dark)
	for bar: float in [-0.5, 0.5]:
		_add_box(tank, Vector3(1.8, 0.09, 0.08), Vector3(-2.4, 1.5, bar), steel)
	for side: float in [-1.0, 1.0]:
		_add_cylinder(tank, 0.27, 1.05, Vector3(-3.68, 1.2, side * 0.62), Vector3(PI / 2, 0, 0), _plain(0.3), 10)
		_add_box(tank, Vector3(0.04, 0.26, 0.5), Vector3(-3.57, 0.96, side * 0.62), _glow(0.85))

	var turret := Node3D.new()
	turret.position = Vector3(0.1, 1.45, 0)
	turret.set_meta("detachable", true)
	turret.set_meta("can_fly_off", true)
	turret.set_meta("traverses", true)
	tank.add_child(turret)
	var shell: Array[PackedVector3Array] = [
		_ring(-2.3, 0.14, 0.62, 0.5, 0.62, 0.46),
		_ring(-1.7, 0.05, 0.78, 0.86, 1.08, 0.78),
		_ring(-0.4, 0.0, 0.86, 1.12, 1.38, 0.98),
		_ring(0.8, 0.0, 0.8, 1.0, 1.2, 0.78),
		_ring(1.6, 0.08, 0.66, 0.55, 0.72, 0.42),
		_ring(1.88, 0.2, 0.52, 0.25, 0.38, 0.2),
	]
	_add_loft(turret, shell, Vector3.ZERO, armour)
	_add_cylinder(turret, 1.3, 0.1, Vector3(-0.1, 0.0, 0), Vector3.ZERO, dark, 18)
	for side: float in [-1.0, 1.0]:
		for brick in 4:
			var t := 0.12 + brick * 0.25
			_add_box(turret, Vector3(0.36, 0.42, 0.2), Vector3(0.8 + t * 0.8, 0.42, side * (1.3 - t * 0.5)), armour).rotation = Vector3(0, side * 0.54, 0)
		for tube in 4:
			_add_cylinder(turret, 0.065, 0.34, Vector3(0.0 + tube * 0.17, 0.82, side * 1.0), Vector3(side * 0.9, 0, 0), steel, 7)

	# Stowage basket on the bustle.
	_add_cylinder(turret, 0.2, 1.7, Vector3(-1.95, 0.85, 0), Vector3(PI / 2, 0, 0), _plain(0.3), 8)
	_add_box(turret, Vector3(0.5, 0.26, 0.5), Vector3(-1.55, 0.92, 0.45), _plain(0.3))
	for rail: float in [-1.0, 1.0]:
		_add_box(turret, Vector3(1.1, 0.04, 0.04), Vector3(-1.9, 0.92, rail * 0.92), steel)
	_add_box(turret, Vector3(0.04, 0.04, 1.84), Vector3(-2.45, 0.92, 0), steel)

	# Commander's cupola with its machine gun, and the gunner's sight.
	_add_cylinder(turret, 0.42, 0.2, Vector3(-0.45, 0.94, 0.55), Vector3.ZERO, armour, 14)
	_add_cylinder(turret, 0.32, 0.05, Vector3(-0.72, 1.28, 0.55), Vector3(0, 0, 1.1), steel, 12)
	_add_box(turret, Vector3(0.5, 0.14, 0.14), Vector3(-0.2, 1.17, 0.55), dark)
	_add_cylinder(turret, 0.028, 1.0, Vector3(0.45, 1.19, 0.55), Vector3(0, 0, -PI / 2), dark, 6)
	_add_box(turret, Vector3(0.14, 0.18, 0.08), Vector3(-0.12, 1.1, 0.42), _plain(0.3))
	_add_box(turret, Vector3(0.5, 0.26, 0.36), Vector3(0.3, 0.94, -0.58), armour)
	_add_box(turret, Vector3(0.05, 0.16, 0.26), Vector3(0.56, 0.94, -0.58), dark)
	_add_cylinder(turret, 0.3, 0.08, Vector3(-0.6, 0.9, -0.55), Vector3.ZERO, steel, 12)
	for side: float in [-1.0, 1.0]:
		_add_cylinder(turret, 0.025, 3.0, Vector3(-1.5, 2.2, side * 0.68), Vector3(side * 0.08, 0, 0.12), dark, 5, 0.3)

	# Gun: mantlet, tapered tube, fume extractor, thermal sleeve joints and muzzle brake.
	var gun_height := 0.38
	_add_box(turret, Vector3(0.5, 0.42, 0.7), Vector3(1.86, gun_height, 0), armour)
	_add_cylinder(turret, 0.13, 4.5, Vector3(4.2, gun_height, 0), Vector3(0, 0, -PI / 2), steel, 10, 0.72)
	_add_cylinder(turret, 0.19, 0.7, Vector3(3.5, gun_height, 0), Vector3(0, 0, -PI / 2), _plain(0.3), 10)
	for joint: float in [2.5, 4.3, 5.2]:
		_add_cylinder(turret, 0.145, 0.07, Vector3(joint, gun_height, 0), Vector3(0, 0, -PI / 2), dark, 10)
	_add_cylinder(turret, 0.16, 0.42, Vector3(6.55, gun_height, 0), Vector3(0, 0, -PI / 2), dark, 10)
	_add_contact_shadow(tank, Vector2(9.0, 5.0))
	return tank


func _make_humvee(shade: float, armed := false) -> Node3D:
	var humvee := Node3D.new()
	var paint := _textured("camo.jpg", "", 0.45, 0.8, shade * 1.5)
	var dark := _plain(0.08)
	var rubber := _plain(0.05)
	var glass := _plain(0.03, 0.2)
	var steel := _plain(0.2)
	var lamp := _plain(1.0)

	# Chassis with side sills, a sloped hood and a tapered cabin.
	_add_box(humvee, Vector3(4.7, 0.5, 2.1), Vector3(0, 0.72, 0), paint)
	_add_box(humvee, Vector3(4.7, 0.12, 2.3), Vector3(0, 0.45, 0), dark)
	_add_frustum(humvee, Vector2(1.7, 2.0), Vector2(1.5, 1.8), 0.34, Vector3(1.55, 0.97, 0), paint)
	_add_frustum(humvee, Vector2(2.7, 2.1), Vector2(2.1, 1.8), 0.72, Vector3(-0.35, 0.97, 0), paint)
	var windshield := _add_box(humvee, Vector3(0.06, 0.5, 1.7), Vector3(0.86, 1.34, 0), glass)
	windshield.rotation.z = 0.39
	_add_box(humvee, Vector3(1.0, 0.36, 0.05), Vector3(-0.35, 1.38, 0.97), glass)
	_add_box(humvee, Vector3(1.0, 0.36, 0.05), Vector3(-0.35, 1.38, -0.97), glass)
	_add_box(humvee, Vector3(0.05, 0.34, 1.4), Vector3(-1.55, 1.36, 0), glass)
	for side: float in [-1.0, 1.0]:
		_add_box(humvee, Vector3(0.04, 0.62, 0.03), Vector3(0.12, 1.1, side * 1.05), dark)
		_add_box(humvee, Vector3(0.04, 0.62, 0.03), Vector3(-0.85, 1.1, side * 1.05), dark)
		_add_box(humvee, Vector3(0.14, 0.05, 0.05), Vector3(-0.1, 1.2, side * 1.07), dark)
		_add_box(humvee, Vector3(0.06, 0.16, 0.22), Vector3(2.38, 0.88, side * 0.7), lamp)

	# Front bumper and grille, wide arches over the wheels, and the rear deck with its spare.
	_add_box(humvee, Vector3(0.22, 0.28, 2.3), Vector3(2.42, 0.48, 0), dark)
	_add_box(humvee, Vector3(0.05, 0.26, 0.9), Vector3(2.37, 0.8, 0), dark)
	for x: float in [1.5, -1.5]:
		for z: float in [-1.12, 1.12]:
			_add_box(humvee, Vector3(1.05, 0.1, 0.36), Vector3(x, 1.0, z * 0.95), paint)
			_add_cylinder(humvee, 0.52, 0.42, Vector3(x, 0.52, z), Vector3(PI / 2, 0, 0), rubber)
			_add_cylinder(humvee, 0.22, 0.45, Vector3(x, 0.52, z), Vector3(PI / 2, 0, 0), steel)
	_add_box(humvee, Vector3(0.9, 0.1, 2.0), Vector3(-2.0, 1.0, 0), paint)
	_add_cylinder(humvee, 0.42, 0.26, Vector3(-2.4, 1.12, 0), Vector3(0, 0, PI / 2), rubber)
	_add_box(humvee, Vector3(0.2, 0.34, 0.16), Vector3(-1.95, 1.22, 0.7), _plain(0.28))
	_add_box(humvee, Vector3(0.2, 0.34, 0.16), Vector3(-1.95, 1.22, -0.7), _plain(0.28))
	var antenna := _add_cylinder(humvee, 0.02, 2.2, Vector3(-1.6, 2.3, 0.82), Vector3(0, 0, 0.12), dark)
	antenna.rotation.x = -0.05

	if armed:
		# A pintle gun behind a shield on the roof. It can be blown off.
		var mount := Node3D.new()
		mount.position = Vector3(-0.35, 1.78, 0)
		mount.set_meta("detachable", true)
		mount.set_meta("can_fly_off", true)
		humvee.add_child(mount)
		_add_cylinder(mount, 0.5, 0.2, Vector3.ZERO, Vector3.ZERO, steel)
		_add_box(mount, Vector3(1.1, 0.1, 0.1), Vector3(0.6, 0.3, 0), dark)
		_add_box(mount, Vector3(0.5, 0.12, 0.14), Vector3(0.0, 0.28, 0), dark)
		_add_box(mount, Vector3(0.06, 0.7, 1.0), Vector3(0.28, 0.45, 0), paint)
	_add_contact_shadow(humvee, Vector2(6.6, 4.0))
	return humvee


func _make_truck(covered: bool) -> Node3D:
	var truck := Node3D.new()
	var paint := _camo()
	var rubber := _plain(0.09)
	var steel := _plain(0.2)
	var glass := _plain(0.03, 0.2)

	_add_box(truck, Vector3(7.6, 0.3, 1.1), Vector3(0, 0.85, 0), steel)
	for axle: float in [2.9, -1.3, -2.5]:
		for side: float in [-1.0, 1.0]:
			_add_wheel(truck, 0.56, 0.44, Vector3(axle, 0.56, side * 1.1), rubber, _plain(0.3))

	var cab: Array[PackedVector3Array] = [
		_ring(0.95, 0.98, 2.95, 1.1, 1.16, 1.0, 2.0),
		_ring(2.15, 0.98, 2.95, 1.1, 1.16, 0.98, 2.0),
		_ring(2.65, 0.98, 1.98, 1.1, 1.16, 1.05, 1.7),
		_ring(4.0, 0.98, 1.74, 0.96, 1.0, 0.82, 1.5),
		_ring(4.16, 1.02, 1.55, 0.85, 0.9, 0.75, 1.4),
	]
	_add_loft(truck, cab, Vector3.ZERO, paint)
	_add_box(truck, Vector3(0.05, 1.0, 1.72), Vector3(2.44, 2.46, 0), glass).rotation = Vector3(0, 0, 0.46)
	_add_box(truck, Vector3(0.95, 0.72, 2.3), Vector3(1.55, 2.4, 0), glass)
	_add_box(truck, Vector3(1.1, 0.06, 1.7), Vector3(1.55, 2.98, 0), _plain(0.3))
	_add_box(truck, Vector3(1.1, 0.05, 1.3), Vector3(3.25, 1.9, 0), _glow(0.6)).rotation = Vector3(0, 0, -0.14)
	for slat in 6:
		_add_box(truck, Vector3(0.07, 0.05, 1.34), Vector3(2.8 + slat * 0.18, 1.98 - slat * 0.025, 0), steel)
	for slat in 4:
		_add_box(truck, Vector3(0.05, 0.05, 1.26), Vector3(4.18, 1.2 + slat * 0.1, 0), _plain(0.2))
	_add_box(truck, Vector3(0.24, 0.26, 2.2), Vector3(4.24, 0.96, 0), steel)
	for side: float in [-1.0, 1.0]:
		_add_cylinder(truck, 0.11, 0.06, Vector3(4.2, 1.42, side * 0.68), Vector3(0, 0, -PI / 2), _glow(0.85), 8)
		_add_box(truck, Vector3(0.16, 0.34, 0.08), Vector3(2.5, 2.1, side * 1.3), rubber)
		_add_box(truck, Vector3(1.36, 0.08, 0.5), Vector3(2.9, 1.18, side * 1.1), paint)
		_add_box(truck, Vector3(0.7, 0.08, 0.1), Vector3(1.4, 1.0, side * 1.3), steel)
	_add_cylinder(truck, 0.33, 1.1, Vector3(0.1, 0.8, -1.2), Vector3(0, 0, PI / 2), _plain(0.3), 10)
	_add_box(truck, Vector3(0.7, 0.42, 0.42), Vector3(-0.1, 0.75, 1.22), steel)
	_add_cylinder(truck, 0.07, 1.9, Vector3(0.82, 2.35, 1.24), Vector3.ZERO, steel, 7)
	_add_cylinder(truck, 0.085, 0.34, Vector3(0.82, 3.3, 1.24), Vector3.ZERO, _glow(0.85), 7)

	_add_box(truck, Vector3(4.7, 0.22, 2.45), Vector3(-1.4, 1.17, 0), paint)
	for rib in 7:
		_add_box(truck, Vector3(0.09, 0.2, 2.46), Vector3(-3.6 + rib * 0.73, 1.03, 0), steel)
	for side: float in [-1.0, 1.0]:
		_add_box(truck, Vector3(0.1, 0.5, 0.42), Vector3(-3.5, 0.4, side * 1.1), rubber)
	if covered:
		var canvas := _textured("corrugated.jpg", "", 0.16, 0.95, 0.42)
		var cover: Array[PackedVector3Array] = []
		for x: float in [-3.72, 0.92]:
			cover.append(_arch(x, 1.28, 2.95, 1.2))
		_add_loft(truck, cover, Vector3.ZERO, canvas)
		for bow in 6:
			var x := -3.5 + bow * 0.84
			var hoop: Array[PackedVector3Array] = [_arch(x, 1.28, 3.0, 1.24), _arch(x + 0.12, 1.28, 3.0, 1.24)]
			_add_loft(truck, hoop, Vector3.ZERO, rubber)
		_add_box(truck, Vector3(0.05, 1.35, 2.0), Vector3(-3.74, 1.95, 0), _plain(0.09))
	else:
		for side: float in [-1.0, 1.0]:
			_add_box(truck, Vector3(4.7, 0.5, 0.08), Vector3(-1.4, 1.54, side * 1.2), _textured("planks.jpg", "", 0.6, 0.9, 0.7))
		_add_box(truck, Vector3(0.08, 0.5, 2.4), Vector3(-3.74, 1.54, 0), _textured("planks.jpg", "", 0.6, 0.9, 0.7))
		for crate: float in [-3.05, -1.75, -0.45]:
			_add_box(truck, Vector3(1.15, 0.8, 1.9), Vector3(crate, 1.68, 0), _textured("planks.jpg", "", 0.6, 0.9))
			for strap: float in [-0.5, 0.5]:
				_add_box(truck, Vector3(0.06, 0.84, 1.94), Vector3(crate + strap * 0.8, 1.68, 0), steel)
		_add_cylinder(truck, 0.34, 0.8, Vector3(0.5, 1.68, 0.5), Vector3.ZERO, _plain(0.3), 10)
		_add_cylinder(truck, 0.34, 0.8, Vector3(0.5, 1.68, -0.4), Vector3.ZERO, _plain(0.3), 10)
	_add_contact_shadow(truck, Vector2(10.4, 4.2))
	return truck


func _make_launcher() -> Node3D:
	var launcher := Node3D.new()
	var paint := _camo()
	var rubber := _plain(0.09)
	var steel := _plain(0.2)
	var glass := _plain(0.03, 0.2)

	_add_box(launcher, Vector3(9.8, 0.4, 1.3), Vector3(0, 1.0, 0), steel)
	for axle: float in [3.5, 1.9, -1.5, -3.1]:
		for side: float in [-1.0, 1.0]:
			_add_wheel(launcher, 0.62, 0.48, Vector3(axle, 0.62, side * 1.14), rubber, _plain(0.3))
	for side: float in [-1.0, 1.0]:
		_add_box(launcher, Vector3(2.5, 0.08, 0.5), Vector3(2.7, 1.34, side * 1.14), paint)
		_add_box(launcher, Vector3(2.5, 0.08, 0.5), Vector3(-2.3, 1.34, side * 1.14), paint)
		for jack: float in [-4.3, 0.2]:
			_add_cylinder(launcher, 0.11, 0.9, Vector3(jack, 0.5, side * 1.1), Vector3.ZERO, steel, 8)
			_add_cylinder(launcher, 0.28, 0.08, Vector3(jack, 0.1, side * 1.1), Vector3.ZERO, _plain(0.3), 10)

	var cab: Array[PackedVector3Array] = [
		_ring(2.9, 1.05, 2.85, 1.2, 1.26, 1.08, 1.9),
		_ring(4.25, 1.05, 2.85, 1.2, 1.26, 1.08, 1.9),
		_ring(4.85, 1.05, 2.05, 1.2, 1.26, 1.14, 1.7),
		_ring(5.0, 1.1, 1.6, 1.1, 1.18, 1.1, 1.3),
	]
	_add_loft(launcher, cab, Vector3.ZERO, paint)
	_add_box(launcher, Vector3(0.05, 0.86, 1.95), Vector3(4.58, 2.44, 0), glass).rotation = Vector3(0, 0, 0.62)
	_add_box(launcher, Vector3(0.9, 0.62, 2.5), Vector3(3.6, 2.35, 0), glass)
	_add_box(launcher, Vector3(1.2, 0.07, 1.9), Vector3(3.6, 2.88, 0), _plain(0.3))
	_add_box(launcher, Vector3(0.24, 0.3, 2.45), Vector3(5.06, 1.06, 0), steel)
	for side: float in [-1.0, 1.0]:
		_add_cylinder(launcher, 0.12, 0.06, Vector3(5.04, 1.45, side * 0.82), Vector3(0, 0, -PI / 2), _glow(0.85), 8)
		_add_box(launcher, Vector3(0.16, 0.36, 0.08), Vector3(4.6, 2.2, side * 1.42), rubber)

	# Power pack behind the cab, its exhaust the brightest spot of the vehicle.
	_add_box(launcher, Vector3(1.5, 1.05, 2.4), Vector3(1.9, 1.7, 0), paint)
	_add_box(launcher, Vector3(1.1, 0.05, 1.9), Vector3(1.9, 2.24, 0), _glow(0.6))
	for slat in 6:
		_add_box(launcher, Vector3(0.07, 0.06, 1.96), Vector3(1.42 + slat * 0.19, 2.27, 0), steel)
	_add_cylinder(launcher, 0.1, 0.8, Vector3(1.3, 2.5, 1.0), Vector3.ZERO, _glow(0.85), 8)

	_add_box(launcher, Vector3(5.6, 0.3, 2.5), Vector3(-2.0, 1.3, 0), steel)
	for rail: float in [-1.0, 1.0]:
		_add_box(launcher, Vector3(5.0, 0.42, 0.18), Vector3(-2.0, 1.62, rail * 1.0), steel)
	_add_box(launcher, Vector3(0.9, 0.5, 2.0), Vector3(0.45, 1.7, 0), paint)
	_add_box(launcher, Vector3(1.2, 0.5, 0.5), Vector3(-1.2, 1.6, 0), _plain(0.3))

	# Sealed launch canisters, raised a little on their rear hinge.
	var pods := Node3D.new()
	pods.position = Vector3(-4.6, 1.8, 0)
	pods.rotation.z = deg_to_rad(9)
	pods.set_meta("detachable", true)
	launcher.add_child(pods)
	_add_box(pods, Vector3(6.0, 0.14, 2.4), Vector3(3.0, 0.08, 0), steel)
	for side: float in [-1.0, 1.0]:
		var tube := Vector3(3.0, 0.72, side * 0.6)
		_add_cylinder(pods, 0.56, 6.1, tube, Vector3(0, 0, -PI / 2), paint, 16)
		for band: float in [-2.7, -1.0, 1.0, 2.7]:
			_add_cylinder(pods, 0.59, 0.16, tube + Vector3(band, 0, 0), Vector3(0, 0, -PI / 2), steel, 16)
		_add_cylinder(pods, 0.5, 0.06, tube + Vector3(3.08, 0, 0), Vector3(0, 0, -PI / 2), rubber, 16)
		_add_cylinder(pods, 0.5, 0.06, tube - Vector3(3.08, 0, 0), Vector3(0, 0, -PI / 2), rubber, 16)
	_add_box(pods, Vector3(5.2, 0.05, 0.1), Vector3(3.0, 1.3, 0), rubber)
	_add_box(pods, Vector3(0.14, 0.7, 2.3), Vector3(0.7, 0.4, 0), steel)
	_add_box(pods, Vector3(0.14, 0.7, 2.3), Vector3(5.2, 0.4, 0), steel)
	for strap: float in [-0.7, 0.7]:
		_add_cylinder(launcher, 0.09, 1.2, Vector3(-1.6, 1.95, strap), Vector3(0, 0, 0.3), steel, 8)
	_add_contact_shadow(launcher, Vector2(12.6, 4.6))
	return launcher


func _make_building(spot: Vector3, size: Vector3) -> void:
	var building := Node3D.new()
	building.position = spot
	add_child(building)
	var wall := _textured("concrete.jpg", "", 0.12, 0.95, 0.72)
	var roof := _textured("concrete.jpg", "", 0.07, 0.95, 0.5)

	_add_box(building, size, Vector3(0, size.y / 2, 0), wall)
	_add_contact_shadow(building, Vector2(size.x + 5, size.z + 5))
	_add_windows(building, size)
	_add_box(building, Vector3(size.x - 0.6, 0.1, size.z - 0.6), Vector3(0, size.y + 0.05, 0), roof)
	var rim := size.y + 0.4
	_add_box(building, Vector3(size.x, 0.8, 0.35), Vector3(0, rim, size.z / 2), wall)
	_add_box(building, Vector3(size.x, 0.8, 0.35), Vector3(0, rim, -size.z / 2), wall)
	_add_box(building, Vector3(0.35, 0.8, size.z), Vector3(size.x / 2, rim, 0), wall)
	_add_box(building, Vector3(0.35, 0.8, size.z), Vector3(-size.x / 2, rim, 0), wall)

	var metal := _textured("corrugated.jpg", "corrugated_normal.jpg", 0.3, 0.7, 0.55)
	var top := size.y + 0.1
	for unit in int(size.x / 7.0):
		var x := -size.x / 2 + 3.0 + unit * 6.5
		_add_box(building, Vector3(2.2, 1.0, 1.6), Vector3(x, top + 0.5, -size.z * 0.26), metal)
		_add_cylinder(building, 0.6, 0.12, Vector3(x, top + 1.05, -size.z * 0.26), Vector3.ZERO, _plain(0.12))
	_add_box(building, Vector3(2.8, 1.5, 2.8), Vector3(size.x * 0.28, top + 0.75, size.z * 0.2), wall)
	_add_box(building, Vector3(2.4, 0.1, 2.4), Vector3(size.x * 0.28, top + 1.55, size.z * 0.2), _plain(0.2))
	_add_box(building, Vector3(size.x * 0.5, 0.14, 0.2), Vector3(-size.x * 0.1, top + 0.08, size.z * 0.3), _plain(0.1))
	_scatter_props(Vector3(spot.x - size.x * 0.25, top, spot.z + size.z * 0.15), 2)


func _add_windows(building: Node3D, size: Vector3) -> void:
	var glass := _plain(0.03, 0.15)
	var frame := _plain(0.42)
	var floors := int(size.y / 3.2)
	for level in floors:
		var y := 1.9 + level * 3.2
		for i in int(size.x / 3.6):
			var x := -size.x / 2 + 2.0 + i * 3.6
			for side: float in [-1.0, 1.0]:
				_add_box(building, Vector3(1.7, 1.5, 0.1), Vector3(x, y, side * size.z / 2), frame)
				_add_box(building, Vector3(1.4, 1.2, 0.14), Vector3(x, y, side * size.z / 2), glass)
		for i in int(size.z / 3.6):
			var z := -size.z / 2 + 2.0 + i * 3.6
			for side: float in [-1.0, 1.0]:
				_add_box(building, Vector3(0.1, 1.5, 1.7), Vector3(side * size.x / 2, y, z), frame)
				_add_box(building, Vector3(0.14, 1.2, 1.4), Vector3(side * size.x / 2, y, z), glass)
	_add_box(building, Vector3(2.6, 2.6, 0.2), Vector3(0, 1.3, size.z / 2), _plain(0.1))
	_add_box(building, Vector3(4, 0.14, 1.6), Vector3(0, 3.0, size.z / 2 + 0.8), _plain(0.5))


## An arched steel hangar, its ridge along the local Z axis.
func _make_hangar(spot: Vector3, degrees: float, length: float, radius: float) -> void:
	var hangar := Node3D.new()
	hangar.position = spot
	hangar.rotation.y = deg_to_rad(degrees)
	add_child(hangar)

	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments := 22
	for segment in segments:
		var a := PI * segment / segments
		var b := PI * (segment + 1) / segments
		var near_a := Vector3(cos(a) * radius, sin(a) * radius, -length / 2)
		var near_b := Vector3(cos(b) * radius, sin(b) * radius, -length / 2)
		var far_a := Vector3(cos(a) * radius, sin(a) * radius, length / 2)
		var far_b := Vector3(cos(b) * radius, sin(b) * radius, length / 2)
		for point: Vector3 in [near_a, far_b, near_b, near_a, far_a, far_b]:
			tool.add_vertex(point)
	tool.generate_normals()
	_add_mesh(hangar, tool.commit(), Vector3.ZERO, _textured("corrugated.jpg", "corrugated_normal.jpg", 0.14, 0.6, 0.62))

	for rib in int(length / 5.0) + 1:
		var z := -length / 2 + rib * 5.0
		var arch := TorusMesh.new()
		arch.inner_radius = radius - 0.05
		arch.outer_radius = radius + 0.22
		arch.rings = 26
		arch.ring_segments = 6
		var hoop := _add_mesh(hangar, arch, Vector3(0, 0, z), _plain(0.2))
		hoop.rotation.x = PI / 2

	var end := _textured("concrete.jpg", "", 0.12, 0.95, 0.5)
	for side: float in [-1.0, 1.0]:
		_add_box(hangar, Vector3(radius * 1.7, radius * 0.86, 0.3), Vector3(0, radius * 0.43, side * length / 2), end)
		_add_box(hangar, Vector3(radius * 0.8, radius * 0.56, 0.4), Vector3(0, radius * 0.28, side * length / 2), _plain(0.05))
	_add_contact_shadow(hangar, Vector2(radius * 2 + 5, length + 5))


func _make_car(pickup: bool, shade: float) -> Node3D:
	var car := Node3D.new()
	var paint := _plain(shade, 0.35)
	var glass := _plain(0.04, 0.15)
	var dark := _plain(0.09)
	var trim := _plain(0.45)

	for x: float in [-1.28, 1.32]:
		for z: float in [-0.8, 0.8]:
			_add_wheel(car, 0.33, 0.24, Vector3(x, 0.33, z), dark, trim)
	var body: Array[PackedVector3Array] = [
		_ring(-2.08, 0.42, 0.8, 0.68, 0.84, 0.76),
		_ring(-1.75, 0.3, 0.92, 0.78, 0.88, 0.8),
		_ring(1.0, 0.28, 0.9, 0.8, 0.88, 0.82),
		_ring(1.8, 0.3, 0.74, 0.76, 0.86, 0.72),
		_ring(2.1, 0.38, 0.6, 0.62, 0.72, 0.58),
	]
	_add_loft(car, body, Vector3.ZERO, paint)

	var back := -0.55 if pickup else -1.6
	var rear_roof := -0.3 if pickup else -1.0
	var glasshouse: Array[PackedVector3Array] = [
		_ring(back, 0.9, 0.92, 0.76, 0.76, 0.76),
		_ring(rear_roof, 0.9, 1.4, 0.77, 0.74, 0.6, 1.14),
		_ring(0.2, 0.9, 1.4, 0.78, 0.74, 0.6, 1.14),
		_ring(0.98, 0.88, 0.92, 0.8, 0.8, 0.78),
	]
	_add_loft(car, glasshouse, Vector3.ZERO, glass)
	var roof: Array[PackedVector3Array] = [
		_ring(rear_roof - 0.06, 1.38, 1.44, 0.62, 0.62, 0.56),
		_ring(0.26, 1.38, 1.44, 0.62, 0.62, 0.56),
	]
	_add_loft(car, roof, Vector3.ZERO, paint)
	_add_box(car, Vector3(0.09, 0.5, 1.46), Vector3(-0.1 if pickup else -0.4, 1.14, 0), paint)

	if pickup:
		_add_box(car, Vector3(1.4, 0.04, 1.5), Vector3(-1.32, 0.94, 0), dark)
		for side: float in [-1.0, 1.0]:
			_add_box(car, Vector3(1.5, 0.22, 0.07), Vector3(-1.32, 1.03, side * 0.8), paint)
		_add_box(car, Vector3(0.07, 0.22, 1.6), Vector3(-2.04, 1.03, 0), paint)
		_add_box(car, Vector3(0.6, 0.34, 0.6), Vector3(-1.45, 1.13, 0.25), _textured("planks.jpg", "", 0.6, 0.9))
		_add_cylinder(car, 0.22, 0.46, Vector3(-1.0, 1.18, -0.4), Vector3.ZERO, _plain(0.3), 10)

	for side: float in [-1.0, 1.0]:
		_add_box(car, Vector3(2.3, 0.03, 0.03), Vector3(-0.2, 0.62, side * 0.885), dark)
		_add_box(car, Vector3(0.03, 0.46, 0.03), Vector3(0.0, 0.62, side * 0.885), dark)
		_add_box(car, Vector3(0.12, 0.08, 0.12), Vector3(0.82, 0.98, side * 0.93), dark)
		_add_box(car, Vector3(0.05, 0.1, 0.26), Vector3(2.09, 0.56, side * 0.46), trim)
		_add_box(car, Vector3(0.05, 0.12, 0.3), Vector3(-2.09, 0.66, side * 0.5), dark)
	_add_box(car, Vector3(0.16, 0.14, 1.5), Vector3(2.1, 0.36, 0), dark)
	_add_box(car, Vector3(0.14, 0.14, 1.46), Vector3(-2.1, 0.4, 0), dark)
	_add_contact_shadow(car, Vector2(5.2, 2.9))
	return car


func _add_contact_shadow(parent: Node3D, size: Vector2) -> MeshInstance3D:
	var key := "contact"
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_texture = load(TEXTURES + "contact_shadow.png")
		_materials[key] = material
	var mesh := PlaneMesh.new()
	mesh.size = size
	var shadow := _add_mesh(parent, mesh, Vector3(0, 0.03, 0), _materials[key])
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return shadow


func _make_container(variant: int) -> Node3D:
	var shades: Array[float] = [0.3, 0.62, 0.22, 0.46, 0.75]
	var material := _textured("container.jpg", "", 0.2, 0.75, shades[variant % shades.size()])
	var container := Node3D.new()
	_add_box(container, Vector3(12.2, 2.6, 2.44), Vector3(0, 1.3, 0), material)
	_add_contact_shadow(container, Vector2(14.5, 4.6))
	return container


func _build_watchtower(tower: Node3D) -> void:
	var timber := _textured("planks.jpg", "", 0.4, 0.9, 0.7)
	var height := 8.0
	for x: float in [-1.8, 1.8]:
		for z: float in [-1.8, 1.8]:
			_add_box(tower, Vector3(0.28, height, 0.28), Vector3(x, height / 2, z), _plain(0.14))
	var brace := _add_box(tower, Vector3(5.4, 0.14, 0.14), Vector3(0, height / 2, 1.8), _plain(0.14))
	brace.rotation.z = 1.0
	var brace_b := _add_box(tower, Vector3(0.14, 0.14, 5.4), Vector3(1.8, height / 2, 0), _plain(0.14))
	brace_b.rotation.x = 1.0
	_add_box(tower, Vector3(5.2, 0.2, 5.2), Vector3(0, height, 0), timber)
	_add_box(tower, Vector3(5.2, 1.1, 0.14), Vector3(0, height + 0.6, 2.5), timber)
	_add_box(tower, Vector3(5.2, 1.1, 0.14), Vector3(0, height + 0.6, -2.5), timber)
	_add_box(tower, Vector3(0.14, 1.1, 5.2), Vector3(2.5, height + 0.6, 0), timber)
	_add_box(tower, Vector3(0.14, 1.1, 5.2), Vector3(-2.5, height + 0.6, 0), timber)
	_add_box(tower, Vector3(6.2, 0.16, 6.2), Vector3(0, height + 3, 0), _textured("corrugated.jpg", "corrugated_normal.jpg", 0.3, 0.7, 0.34))
	for x: float in [-2.4, 2.4]:
		for z: float in [-2.4, 2.4]:
			_add_box(tower, Vector3(0.14, 2.9, 0.14), Vector3(x, height + 1.5, z), _plain(0.14))


func _add_fence(from: Vector3, to: Vector3) -> void:
	var length := from.distance_to(to)
	var direction := (to - from).normalized()
	var angle := atan2(-direction.z, direction.x)
	var center := (from + to) / 2
	for rail: float in [1.1, 1.9, 2.5]:
		var bar := _add_box(self, Vector3(length, 0.05, 0.05), center + Vector3.UP * rail, _plain(0.1))
		bar.rotation.y = angle
	var posts := int(length / 3.2)
	for post in posts + 1:
		_add_box(self, Vector3(0.14, 2.8, 0.14), from + direction * (float(post) / posts * length) + Vector3.UP * 1.4, _plain(0.1))


func _add_sandbags(spot: Vector3, rows: int) -> void:
	var bag := _plain(0.55)
	for row in rows:
		for layer in 2:
			var piece := _add_box(self, Vector3(0.6, 0.3, 1.0), spot + Vector3(_rng.randf_range(-0.05, 0.05), 0.16 + layer * 0.3, row * 1.05 + layer * 0.4), bag)
			piece.rotation.y = _rng.randf_range(-0.1, 0.1)


func _scatter_props(center: Vector3, count: int) -> void:
	for i in count:
		var offset := Vector3(_rng.randfn(0, 1.8), 0, _rng.randfn(0, 1.8))
		var spot := Transform3D(Basis(Vector3.UP, _rng.randf() * TAU), center + offset)
		(_barrel_spots if i % 2 == 0 else _crate_spots).append(spot)


## Draws every barrel and crate in two instanced batches.
func _build_props() -> void:
	for batch: Array in [[BARREL_SCENE, _barrel_spots], [CRATE_SCENE, _crate_spots]]:
		var spots: Array[Transform3D] = batch[1]
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = _flatten_scene(batch[0])
		multimesh.instance_count = spots.size()
		for i in spots.size():
			multimesh.set_instance_transform(i, spots[i])
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = multimesh
		add_child(instance)


## Bakes the many parts of an imported model into a single mesh.
func _flatten_scene(scene: PackedScene) -> ArrayMesh:
	var model: Node3D = scene.instantiate()
	var result := ArrayMesh.new()
	var tools: Dictionary = {}
	for part: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var offset := Transform3D.IDENTITY
		var node: Node = part
		while node != model:
			offset = (node as Node3D).transform * offset
			node = node.get_parent()
		for surface in part.mesh.get_surface_count():
			var material := part.mesh.surface_get_material(surface)
			if not tools.has(material):
				tools[material] = SurfaceTool.new()
				tools[material].begin(Mesh.PRIMITIVE_TRIANGLES)
				tools[material].set_material(material)
			tools[material].append_from(part.mesh, surface, offset)
	for material: Material in tools:
		tools[material].commit(result)
	model.free()
	return result


func _add_fire(spot: Vector3) -> void:
	_particles(spot, 12, 1.1, FIRE_COLORS, true)
	var smoke := _particles(spot + Vector3.UP * 2, 14, 11.0, SMOKE_COLORS, false)
	smoke.process_material.spread = 16.0
	smoke.process_material.scale_min = 6.0
	smoke.process_material.scale_max = 12.0
	smoke.process_material.initial_velocity_min = 2.5
	smoke.process_material.initial_velocity_max = 4.0
	smoke.preprocess = 11.0

	var light := OmniLight3D.new()
	light.omni_range = 22
	light.position = spot + Vector3.UP * 2
	add_child(light)
	_flames.append(light)


func _particles(spot: Vector3, amount: int, lifetime: float, colors: Array, additive: bool) -> GPUParticles3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.billboard_keep_scale = true
	material.particles_anim_h_frames = PUFF_FRAMES
	material.particles_anim_v_frames = PUFF_FRAMES
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = load(TEXTURES + "smoke_puffs.png")
	if additive:
		material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD

	var ramp := Gradient.new()
	ramp.colors = PackedColorArray(colors)
	var offsets := PackedFloat32Array()
	for i in colors.size():
		offsets.append(pow(float(i) / (colors.size() - 1), 2.0))
	ramp.offsets = offsets
	var ramp_texture := GradientTexture1D.new()
	ramp_texture.gradient = ramp

	var growth := Curve.new()
	growth.add_point(Vector2(0, 0.3))
	growth.add_point(Vector2(1, 1))
	var growth_texture := CurveTexture.new()
	growth_texture.curve = growth

	var process := ParticleProcessMaterial.new()
	process.direction = Vector3.UP
	process.spread = 12
	process.initial_velocity_min = 3
	process.initial_velocity_max = 6
	process.gravity = WIND
	process.scale_min = 3
	process.scale_max = 6
	process.scale_curve = growth_texture
	process.color_ramp = ramp_texture
	process.angle_min = -180
	process.angle_max = 180
	process.anim_offset_max = 1.0

	var quad := QuadMesh.new()
	quad.material = material
	var particles := GPUParticles3D.new()
	particles.amount = maxi(int(amount * _particle_ratio), 1)
	particles.lifetime = lifetime
	particles.draw_pass_1 = quad
	particles.process_material = process
	particles.position = spot
	particles.visibility_aabb = AABB(Vector3(-160, -20, -120), Vector3(320, 140, 240))
	add_child(particles)
	return particles


func _add_box(parent: Node3D, size: Vector3, spot: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _add_mesh(parent, mesh, spot, material)


func _add_sphere(parent: Node3D, radius: float, spot: Vector3, material: Material, squash := 1.0) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 14
	mesh.rings = 7
	var sphere := _add_mesh(parent, mesh, spot, material)
	sphere.scale.y = squash
	return sphere


func _add_cylinder(parent: Node3D, radius: float, height: float, spot: Vector3, turn: Vector3, material: Material, sides := 12, taper := 1.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * taper
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = sides
	mesh.rings = 1
	var instance := _add_mesh(parent, mesh, spot, material)
	instance.rotation = turn
	return instance


## A wheel on an axle along Z: tyre, a rim on both faces and a hub cap.
func _add_wheel(parent: Node3D, radius: float, width: float, spot: Vector3, tyre: Material, rim: Material) -> void:
	var axle := Vector3(PI / 2, 0, 0)
	_add_cylinder(parent, radius, width, spot, axle, tyre, 14)
	_add_cylinder(parent, radius * 0.62, width + 0.04, spot, axle, rim, 10)
	_add_cylinder(parent, radius * 0.24, width + 0.1, spot, axle, tyre, 6)


## A six-sided slice across a hull at length x: bottom, shoulder and top half-widths.
func _ring(x: float, low: float, high: float, bottom: float, shoulder: float, top: float, shoulder_y := -1.0) -> PackedVector3Array:
	var y := shoulder_y if shoulder_y >= 0.0 else lerpf(low, high, 0.6)
	return PackedVector3Array([
		Vector3(x, low, -bottom), Vector3(x, y, -shoulder), Vector3(x, high, -top),
		Vector3(x, high, top), Vector3(x, y, shoulder), Vector3(x, low, bottom),
	])


## A slice shaped like a canvas tilt.
func _arch(x: float, low: float, high: float, half: float) -> PackedVector3Array:
	var ring := PackedVector3Array()
	for point in 11:
		var angle := PI * point / 10.0
		ring.append(Vector3(x, low + sin(angle) * (high - low), -cos(angle) * half))
	return ring


## A flat-faced solid skinned over slices of equal point count, in order along +X.
func _add_loft(parent: Node3D, rings: Array[PackedVector3Array], spot: Vector3, material: Material) -> MeshInstance3D:
	var triangles: Array[Vector3] = []
	var points := rings[0].size()
	for stage in rings.size() - 1:
		var a := rings[stage]
		var b := rings[stage + 1]
		for i in points:
			var j := (i + 1) % points
			triangles.append_array([a[i], b[i], a[j], a[j], b[i], b[j]])
	for end: int in [0, rings.size() - 1]:
		var ring := rings[end]
		var centre := Vector3.ZERO
		for point in ring:
			centre += point / points
		for i in points:
			var j := (i + 1) % points
			triangles.append_array([centre, ring[i], ring[j]] if end == 0 else [centre, ring[j], ring[i]])
	return _add_solid(parent, triangles, spot, material)


## A box with a narrower top: x and y of each Vector2 are its length and width.
func _add_frustum(parent: Node3D, bottom: Vector2, top: Vector2, height: float, spot: Vector3, material: Material) -> MeshInstance3D:
	var low := func(x: float, z: float) -> Vector3: return Vector3(x * bottom.x / 2, 0, z * bottom.y / 2)
	var high := func(x: float, z: float) -> Vector3: return Vector3(x * top.x / 2, height, z * top.y / 2)
	var corners := [Vector2(1, 1), Vector2(1, -1), Vector2(-1, -1), Vector2(-1, 1)]
	var triangles: Array[Vector3] = []
	for i in 4:
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % 4]
		triangles.append_array([low.call(a.x, a.y), high.call(a.x, a.y), low.call(b.x, b.y), low.call(b.x, b.y), high.call(a.x, a.y), high.call(b.x, b.y)])
	for index: int in [0, 2, 1, 0, 3, 2]:
		var corner: Vector2 = corners[index]
		triangles.append(high.call(corner.x, corner.y))
	return _add_solid(parent, triangles, spot, material)


## Flat-shaded triangles, finished to match the primitive meshes: merging keeps only indexed
## triangles and needs tangents throughout, so this adds both, with throwaway UVs for the tangents.
func _add_solid(parent: Node3D, triangles: Array[Vector3], spot: Vector3, material: Material) -> MeshInstance3D:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_smooth_group(-1)
	for point in triangles:
		tool.set_uv(Vector2(point.x + point.y * 0.7, point.z + point.y * 0.3))
		tool.add_vertex(point)
	tool.generate_normals()
	tool.generate_tangents()
	tool.index()
	return _add_mesh(parent, tool.commit(), spot, material)


func _add_mesh(parent: Node3D, mesh: Mesh, spot: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = spot
	parent.add_child(instance)
	return instance


func _camo() -> StandardMaterial3D:
	return _textured("camo.jpg", "", 0.22, 0.65, 0.75)


## Triplanar material, so primitives need no UV work. Scale is repeats per metre.
func _textured(albedo: String, normal: String, scale_per_metre: float, roughness: float, shade := 1.0) -> StandardMaterial3D:
	var key := "%s|%s|%s|%s" % [albedo, normal, scale_per_metre, shade]
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_texture = load(TEXTURES + albedo)
		material.albedo_color = Color(shade, shade, shade)
		material.roughness = roughness
		material.uv1_triplanar = true
		material.uv1_scale = Vector3.ONE * scale_per_metre
		if normal != "":
			material.normal_enabled = true
			material.normal_texture = load(TEXTURES + normal)
		_materials[key] = material
	return _materials[key]


## Sits on the parts that run hot, so they stand out on the thermal feed.
func _glow(shade: float) -> StandardMaterial3D:
	var key := "glow|%s" % shade
	if not _materials.has(key):
		var material: StandardMaterial3D = _plain(shade).duplicate()
		material.emission_enabled = true
		material.emission = Color(shade, shade, shade)
		_materials[key] = material
	return _materials[key]


func _plain(shade: float, roughness := 0.8) -> StandardMaterial3D:
	var key := "plain|%s|%s" % [shade, roughness]
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(shade, shade, shade)
		material.roughness = roughness
		_materials[key] = material
	return _materials[key]
