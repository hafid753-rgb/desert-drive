class_name DuneSea
extends Node3D
## A vast dune sea for the run: ~1.2 km of procedural sand.
##   * transverse dune ridges across the driving line (gentle windward side,
##     steeper lee), so the car climbs and jumps crests
##   * giant star/linear dunes rising on both sides of the corridor
##   * the sebkha: a flat salt basin to the east where the dunes die out
## Visual mesh + HeightMapShape3D collision (layer 1) from the same heights.

const SIZE := 1280.0          # metres
const RES := 320              # grid cells (4 m)
const SEBKHA_X := -40.0       # dunes fade out into the salt flat from here
const SEBKHA_Y := -0.25

var _ridge := FastNoiseLite.new()
var _big := FastNoiseLite.new()
var _warp := FastNoiseLite.new()


func _init() -> void:
	_ridge.seed = 7
	_ridge.frequency = 0.004
	_big.seed = 19
	_big.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_big.frequency = 0.0035
	_big.fractal_octaves = 3
	_warp.seed = 3
	_warp.frequency = 0.01


## Ground height at a world point (also used for placement).
func height(x: float, z: float) -> float:
	# corridor dunes: transverse ridges every ~48 m, crest line wandering
	var ph := x / 48.0 + _warp.get_noise_2d(x, z) * 0.6 + _ridge.get_noise_2d(x, z) * 0.8
	var f := ph - floorf(ph)
	var prof := 0.0
	if f < 0.72:
		var u := f / 0.72
		prof = u * u * (3.0 - 2.0 * u)          # long windward slope
	else:
		var u := (f - 0.72) / 0.28
		prof = 1.0 - u * u * (3.0 - 2.0 * u)    # steep lee face
	var ridge_h := 6.5 + 2.5 * _ridge.get_noise_2d(x * 0.5, z * 0.5)
	var h := prof * ridge_h
	# giant dunes either side of the corridor (z), elongated along x
	var side := smoothstep(30.0, 140.0, absf(z - _corridor_z(x)))
	var big := 0.5 + 0.5 * _big.get_noise_2d(x * 0.45, z * 1.3)
	big = pow(big, 1.3)
	h += side * big * 55.0 + side * 8.0
	# the sebkha: dunes melt into a flat salt basin
	var basin := smoothstep(SEBKHA_X, SEBKHA_X + 60.0, x) * (1.0 - smoothstep(80.0, 160.0, absf(z)))
	h = lerpf(h, SEBKHA_Y, basin)
	return h


## The driving corridor wanders a little so the shots aren't a straight line.
func _corridor_z(x: float) -> float:
	return sin(x * 0.006) * 18.0


func _ready() -> void:
	var n := RES + 1
	var step := SIZE / RES
	var half := SIZE * 0.5
	var hs := PackedFloat32Array()
	hs.resize(n * n)
	for j in n:
		for i in n:
			hs[j * n + i] = height(-half + i * step, -half + j * step)
	# visual mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var verts := PackedVector3Array()
	verts.resize(n * n)
	for j in n:
		for i in n:
			verts[j * n + i] = Vector3(-half + i * step, hs[j * n + i], -half + j * step)
	for j in n:
		for i in n:
			var c := verts[j * n + i]
			var l := verts[j * n + maxi(i - 1, 0)]
			var r := verts[j * n + mini(i + 1, n - 1)]
			var d := verts[maxi(j - 1, 0) * n + i]
			var u := verts[mini(j + 1, n - 1) * n + i]
			var nrm := (u - d).cross(r - l).normalized()
			if nrm.y < 0.0:
				nrm = -nrm
			st.set_normal(nrm)
			st.set_uv(Vector2(c.x, c.z) / 8.0)
			st.add_vertex(c)
	for j in RES:
		for i in RES:
			var a := j * n + i
			var b := a + 1
			var c2 := a + n
			var d2 := c2 + 1
			# clockwise seen from above = front face in Godot
			st.add_index(a)
			st.add_index(b)
			st.add_index(c2)
			st.add_index(b)
			st.add_index(d2)
			st.add_index(c2)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.name = "DuneMesh"
	add_child(mi)
	var court := Courtyard.new()
	var m := (court._sand_mat(Courtyard.SAND) as ShaderMaterial).duplicate() as ShaderMaterial
	court.free()
	# big forms need stronger form shading than the courtyard's small dunes:
	# lit windward faces vs mauve lee faces, so the dune sea reads at range
	m.set_shader_parameter("y_squash", 0.45)
	m.set_shader_parameter("lambert_gain", 3.2)
	mi.material_override = m
	# collision
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var shape := CollisionShape3D.new()
	var hm := HeightMapShape3D.new()
	hm.map_width = n
	hm.map_depth = n
	hm.map_data = hs
	shape.shape = hm
	shape.scale = Vector3(step, 1.0, step)
	body.add_child(shape)
	add_child(body)
