class_name SmashProps
extends Node3D
## Physics props for the run: stacks of wooden crates and a tin-roofed
## shed (a "hangar" of planks, posts and corrugated sheets). Every piece is
## a RigidBody3D (layer 2, collides with the ground and each other). The
## shed is held frozen until the car comes close, then let go so it comes
## apart under the hit. The car pushes them through its AnimatableBody3D.

const LAYER_PROPS := 2

var shed_pieces: Array[RigidBody3D] = []
var shed_center := Vector3.ZERO
var shed_released := false
var crates: Array[RigidBody3D] = []

var _wood: StandardMaterial3D
var _wood_dark: StandardMaterial3D
var _tin: StandardMaterial3D
var _rust: StandardMaterial3D


func _ready() -> void:
	_wood = _mat(Color(0.72, 0.52, 0.32))
	_wood_dark = _mat(Color(0.5, 0.34, 0.2))
	_tin = _mat(Color(0.7, 0.72, 0.72), 0.45, 0.4)
	_rust = _mat(Color(0.64, 0.38, 0.22))


func _mat(c: Color, rough := 0.95, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


func _piece(size: Vector3, xf: Transform3D, mat: Material, mass: float, frozen := false) -> RigidBody3D:
	var b := RigidBody3D.new()
	b.collision_layer = LAYER_PROPS
	b.collision_mask = 1 | LAYER_PROPS | 4   # 4: the car's pusher body
	b.mass = mass
	b.continuous_cd = true
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	b.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	b.add_child(mi)
	b.transform = xf
	if frozen:
		b.freeze = true
		b.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	add_child(b)
	return b


## A crate: plank faces (lighter boards, darker frame) as one body.
func _crate(at: Vector3, s: float, yaw: float) -> RigidBody3D:
	var b := _piece(Vector3(s, s, s), Transform3D(Basis(Vector3.UP, yaw), at), _wood, 14.0 * s * s * s)
	var mi := b.get_child(1) as MeshInstance3D
	# frame battens
	for e in [Vector3(1, 1, 0), Vector3(1, -1, 0), Vector3(-1, 1, 0), Vector3(-1, -1, 0), Vector3(0, 1, 1), Vector3(0, -1, 1), Vector3(0, 1, -1), Vector3(0, -1, -1), Vector3(1, 0, 1), Vector3(-1, 0, 1), Vector3(1, 0, -1), Vector3(-1, 0, -1)]:
		var bat := MeshInstance3D.new()
		var bm := BoxMesh.new()
		var sz := Vector3(s * 1.02, s * 1.02, s * 1.02)
		for k in 3:
			if e[k] == 0:
				continue
			sz[k] = s * 0.14
		bm.size = sz
		bat.mesh = bm
		bat.material_override = _wood_dark
		bat.position = Vector3(e) * s * 0.45
		mi.add_child(bat)
	crates.append(b)
	return b


func crate_stack(at: Vector3, yaw: float, rows: int) -> void:
	var s := 1.0
	var basis := Basis(Vector3.UP, yaw)
	for r in rows:
		var count := rows - r
		for i in count:
			var off := (i - (count - 1) * 0.5) * (s + 0.04)
			var p := at + basis * Vector3(off, s * 0.5 + r * s, 0)
			_crate(p, s, yaw + randf_range(-0.05, 0.05))


## Shed: 4 corner posts, plank walls on three sides (open front), a
## corrugated tin roof on rafters; ~40 rigid pieces, frozen until released.
func build_shed(at: Vector3, yaw: float) -> void:
	shed_center = at
	var b := Basis(Vector3.UP, yaw)
	var w := 6.0     # x
	var d := 4.5     # z
	var h := 3.0
	var post := Vector3(0.2, h, 0.2)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			shed_pieces.append(_piece(post, Transform3D(b, at + b * Vector3(sx * w * 0.5, h * 0.5, sz * d * 0.5)), _wood_dark, 25.0, true))
	# walls: horizontal planks, back (+z) and both sides; front (-z) open
	var plank_h := 0.34
	var rows := int(h / plank_h) - 1
	for r in rows:
		var y := 0.3 + r * plank_h
		var mat := _wood if r % 3 != 1 else _wood_dark
		shed_pieces.append(_piece(Vector3(w, plank_h * 0.92, 0.06), Transform3D(b, at + b * Vector3(0, y, d * 0.5)), mat, 12.0, true))
		for sx in [-1, 1]:
			shed_pieces.append(_piece(Vector3(0.06, plank_h * 0.92, d), Transform3D(b, at + b * Vector3(sx * w * 0.5, y, 0)), mat, 9.0, true))
	# rafters + tin sheets (slight pitch)
	for i in 4:
		var x := -w * 0.5 + w * (i + 0.5) / 4.0
		shed_pieces.append(_piece(Vector3(0.14, 0.14, d + 0.6), Transform3D(b * Basis(Vector3.RIGHT, 0.08), at + b * Vector3(x, h + 0.1, 0)), _wood_dark, 8.0, true))
	for i in 3:
		var x := -w * 0.5 + w * (i + 0.5) / 3.0
		var mat := _tin if i != 1 else _rust
		shed_pieces.append(_piece(Vector3(w / 3.0 + 0.1, 0.04, d + 0.9), Transform3D(b * Basis(Vector3.RIGHT, 0.08), at + b * Vector3(x, h + 0.22, 0)), mat, 10.0, true))
	# clutter inside: barrels (boxes) and a crate
	_crate(at + b * Vector3(1.6, 0.5, 1.2), 1.0, yaw + 0.3)
	_crate(at + b * Vector3(-1.8, 0.45, 1.0), 0.9, yaw - 0.2)


## Let the shed go (car close): unfreeze, and give the hit side a shove.
func release_shed(car_pos: Vector3, car_vel: Vector3) -> void:
	if shed_released:
		return
	shed_released = true
	for p in shed_pieces:
		p.freeze = false
		var d := p.global_position.distance_to(car_pos)
		if d < 4.0:
			p.apply_central_impulse(car_vel * p.mass * 0.35 * (1.0 - d / 4.0) + Vector3.UP * p.mass * 2.0)
		p.angular_velocity = Vector3(randf_range(-2, 2), randf_range(-2, 2), randf_range(-2, 2)) * (1.0 if d < 5.0 else 0.2)
