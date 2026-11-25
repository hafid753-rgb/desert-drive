extends "res://game/main.gd"
## "Dune run": the car across a vast dune sea, over the crests, flat out
## across a flooded sebkha, through crate stacks and a tin shed.
##   godot --path . res://game/drive/dune_run.tscn            (drive it)
##   ... -- teaser    scripted run + cinematic cameras (the video)

var car: DesertCar
var sea: DuneSea
var flat: Sebkha
var props: SmashProps
var cam := Camera3D.new()
var teaser := false
var t := 0.0
var _cap := Label.new()
var _shake := 0.0
var _slowmo_until := -1.0
var _shed_hit_t := -1.0
var _cam_pos := Vector3.ZERO
var _cam_look := Vector3.ZERO
var _shot := -1

const START_X := -330.0
const CRATE_X := 124.0
const SHED_X := 150.0


func _ready() -> void:
	teaser = OS.get_cmdline_user_args().has("teaser")
	Settings.quality = 2
	_build_environment()
	# a vast view: haze only far out
	env.fog_depth_begin = 70.0
	env.fog_depth_end = 1100.0
	env.fog_height_density = 0.004
	env.fog_density = 0.55
	# light from behind the run, high enough that the giant side dunes
	# do not shade the corridor (the car drives +x): the long
	# windward faces catch the sun, the steep lee faces fall into shade
	sun.rotation = Vector3(deg_to_rad(-46.0), deg_to_rad(-102.0), 0.0)
	env.fog_depth_curve = 2.2
	if OS.get_cmdline_user_args().has("sunset"):
		_sunset()
	sea = DuneSea.new()
	add_child(sea)
	if OS.get_cmdline_user_args().has("sunset"):
		# the Journey sheen terms blow out with the sun this low: calm them
		var sm := (sea.get_node("DuneMesh") as MeshInstance3D).material_override as ShaderMaterial
		for k in ["ocean_strength", "sheen_strength", "sky_sheen_strength", "rim_strength"]:
			sm.set_shader_parameter(k, 0.0)
		sm.set_shader_parameter("glitter_strength", 3.0)
		sm.set_shader_parameter("sand_color", Color(0.86, 0.56, 0.4))
		sm.set_shader_parameter("shadow_color", Color(0.48, 0.36, 0.5))
	flat = Sebkha.new()
	add_child(flat)
	add_child(SandInteraction.new())
	var flare := LensFlare.new()
	flare.sun = sun
	add_child(flare)
	props = SmashProps.new()
	add_child(props)
	# crate stacks across the line, then the shed square on it
	# a wall of crates square across the line, a second row behind
	var cz := _path_z(CRATE_X)
	for k in 3:
		props.crate_stack(Vector3(CRATE_X, DuneSea.SEBKHA_Y, cz + (k - 1) * 3.2), 0.0, 3)
	for k in 2:
		props.crate_stack(Vector3(CRATE_X + 3.0, DuneSea.SEBKHA_Y, cz + (k - 0.5) * 3.2), 0.0, 2)
	props.build_shed(Vector3(SHED_X, DuneSea.SEBKHA_Y, _path_z(SHED_X)), PI * 0.5)
	car = DesertCar.new()
	car.max_speed = 34.0
	car.engine = 17.0
	car.dust_scale = 2.4
	car.plume = true
	car.water_fn = flat.is_water
	car.water_power = 0.9          # sheet water: a hiss of spray, little drag
	car.water_drag = 0.18
	add_child(car)
	var sz := _path_z(START_X)
	car.global_position = Vector3(START_X, sea.height(START_X, sz) + 0.1, sz)
	car.yaw = -PI * 0.5
	car.velocity = Vector3(18, 0, 0)
	if teaser:
		car.autopilot = _autopilot
	else:
		car.autopilot = Callable()
	car.landed.connect(func(v: float) -> void: _shake = maxf(_shake, clampf(v * 0.02, 0.0, 0.35)))
	if OS.get_cmdline_user_args().has("sunset"):
		for sx in [-0.55, 0.55]:
			var hl := SpotLight3D.new()
			hl.light_color = Color(1.0, 0.9, 0.7)
			hl.light_energy = 6.0
			hl.spot_range = 40.0
			hl.spot_angle = 28.0
			hl.position = Vector3(sx, 0.6, -2.0)
			car.add_child(hl)
	add_child(cam)
	cam.fov = 55.0
	cam.far = 1600.0
	cam.current = true
	var layer := CanvasLayer.new()
	add_child(layer)
	_cap.add_theme_color_override("font_color", Color(1.0, 0.97, 0.92))
	_cap.add_theme_color_override("font_shadow_color", Color(0.2, 0.12, 0.08, 0.75))
	_cap.add_theme_constant_override("shadow_offset_x", 2)
	_cap.add_theme_constant_override("shadow_offset_y", 2)
	_cap.add_theme_font_size_override("font_size", 22)
	_cap.position = Vector2(48, 650)
	layer.add_child(_cap)


## The line the run follows: the dune corridor, then the wet lane of the
## sebkha (weaving through the water), then straight at the crates/shed.
func _path_z(x: float) -> float:
	var dunes := sin(x * 0.006) * 18.0
	var lane := sin(x * 0.05) * 5.0
	var k := smoothstep(-60.0, 0.0, x)
	var z := lerpf(dunes, lane, k)
	var k2 := smoothstep(100.0, 118.0, x)
	return lerpf(z, sin(CRATE_X * 0.05) * 5.0, k2)


func _autopilot() -> Array:
	var p := car.global_position
	var speed := Vector2(car.velocity.x, car.velocity.z).length()
	var ahead := p.x + clampf(10.0 + speed * 0.5, 10.0, 28.0)
	var target := Vector3(ahead, 0, _path_z(ahead))
	var to := Vector3(target.x - p.x, 0, target.z - p.z)
	var want := atan2(-to.x, -to.z)
	var err := wrapf(want - car.yaw, -PI, PI)
	var steer := clampf(-err * 2.4, -1.0, 1.0)
	var thr := 1.0 if p.x < SHED_X + 12.0 else -0.4
	return [thr, steer, false]


var _crate_hit_t := -1.0


func _physics_process(_delta: float) -> void:
	if _crate_hit_t < 0.0 and car.global_position.x > CRATE_X - 3.0:
		_crate_hit_t = t
		if teaser:
			_slowmo_until = t + 0.8
			Engine.time_scale = 0.3
	if not props.shed_released and car.global_position.distance_to(props.shed_center) < 7.5:
		props.release_shed(car.global_position, car.velocity)
		_shed_hit_t = t
		if teaser:
			_slowmo_until = t + 0.9
			Engine.time_scale = 0.35


func _process(delta: float) -> void:
	var real := delta / maxf(Engine.time_scale, 0.01)
	t += real
	if _slowmo_until > 0.0 and t > _slowmo_until:
		Engine.time_scale = lerpf(Engine.time_scale, 1.0, 1.0 - exp(-3.0 * real))
		if Engine.time_scale > 0.97:
			Engine.time_scale = 1.0
			_slowmo_until = -1.0
	_camera(real)
	if teaser and _shed_hit_t > 0.0 and t - _shed_hit_t > 3.8:
		Engine.time_scale = 1.0
		get_tree().quit()
	if teaser and t > 60.0:
		get_tree().quit()
	if OS.get_cmdline_user_args().has("trace") and fmod(t, 0.5) < real:
		print("t %.1f pos %s spd %.1f air %s water %s shot %d shed %s ts %.2f" % [t, car.global_position.snapped(Vector3.ONE * 0.1), Vector2(car.velocity.x, car.velocity.z).length(), car.airborne, car.in_water, _shot, props.shed_released, Engine.time_scale])


func _camera(delta: float) -> void:
	var p := car.global_position
	var fwd := Vector3(-sin(car.yaw), 0, -cos(car.yaw))
	var right := Vector3(cos(car.yaw), 0, -sin(car.yaw))
	var pos: Vector3
	var look: Vector3
	var smooth := 6.0
	var shot := 0
	if not teaser:
		shot = 1
	elif t < 6.0:
		shot = 0
	elif p.x < -20.0:
		shot = 1
	elif p.x < CRATE_X - 26.0:
		shot = 2
	elif p.x < SHED_X - 10.0:
		shot = 3
	else:
		shot = 4
	match shot:
		0:
			# the reveal: high over the dune sea looking out at the horizon,
			# then swinging round and diving toward the speeding car
			var e := clampf(t / 6.0, 0.0, 1.0)
			e = e * e * e * (e * (e * 6.0 - 15.0) + 10.0)
			var start := Vector3(START_X + 260.0, 95.0, -210.0)
			var chase := p - fwd * 11.0 + Vector3(0, 4.0, 0) + right * 3.0
			pos = start.lerp(chase, e)
			var horizon := Vector3(START_X - 400.0, 10.0, 260.0)
			look = horizon.lerp(p + fwd * 6.0, clampf(e * 1.6, 0.0, 1.0))
			smooth = 60.0
			_cap.text = "DESERT DRIVE  —  the dune sea"
		1:
			# low chase over the crests
			pos = p - fwd * 9.5 + Vector3(0, 3.0, 0) + right * 1.5
			look = p + fwd * 10.0 + Vector3(0, 0.5, 0)
			smooth = 7.0
			_cap.text = "OVER THE CRESTS  —  airtime · dust trail"
		2:
			# racing alongside across the sebkha water
			pos = p + right * 9.0 - fwd * 3.0 + Vector3(0, 1.6, 0)
			look = p + fwd * 5.0 + Vector3(0, 0.4, 0)
			smooth = 8.0
			_cap.text = "THE SEBKHA  —  flat out through the salt water"
		3:
			# planted ahead of the crates, the car charging in
			pos = Vector3(CRATE_X + 7.0, 2.0, _path_z(CRATE_X) - 10.0)
			look = p.lerp(Vector3(CRATE_X + 1.5, 0.8, _path_z(CRATE_X)), 0.55)
			smooth = 10.0
			_cap.text = "CRATES"
		_:
			# side-on at the shed for the hit, slow motion
			pos = props.shed_center + Vector3(-5.0, 3.2, -13.0)
			look = props.shed_center.lerp(p, 0.4) + Vector3(0, 1.2, 0)
			smooth = 6.0
			_cap.text = "THE SHED" if _shed_hit_t < 0.0 or t - _shed_hit_t < 3.5 else ""
	if shot != _shot:
		_shot = shot
		_cam_pos = pos
		_cam_look = look
	var k := 1.0 - exp(-smooth * delta)
	_cam_pos = _cam_pos.lerp(pos, k)
	_cam_look = _cam_look.lerp(look, k)
	var jitter := Vector3.ZERO
	if _shake > 0.001:
		jitter = Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake
		_shake = maxf(0.0, _shake - delta * 1.2)
	# keep the camera above the sand
	var floor_y := sea.height(_cam_pos.x, _cam_pos.z) + 0.8
	cam.global_position = Vector3(_cam_pos.x, maxf(_cam_pos.y, floor_y), _cam_pos.z) + jitter
	cam.look_at(_cam_look, Vector3.UP)


## Golden-hour variant: the sun just above the dunes ahead of the run,
## long blue shadows, an orange haze, headlights on.
func _sunset() -> void:
	sun.rotation = Vector3(deg_to_rad(-9.0), deg_to_rad(95.0), 0.0)
	sun.light_color = Color(1.0, 0.62, 0.36)
	sun.light_energy = 0.42
	var sky := env.sky.sky_material as ProceduralSkyMaterial
	sky.sky_top_color = Color(0.36, 0.42, 0.62)
	sky.sky_horizon_color = Color(1.0, 0.6, 0.38)
	sky.ground_horizon_color = Color(0.96, 0.56, 0.36)
	sky.sun_angle_max = 40.0
	env.ambient_light_color = Color(0.55, 0.45, 0.62)
	env.ambient_light_energy = 0.45
	env.fog_light_color = Color(0.78, 0.46, 0.4)
	env.fog_sun_scatter = 0.05
	env.fog_density = 0.35
