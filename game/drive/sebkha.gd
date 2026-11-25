class_name Sebkha
extends Node3D
## Salt flat (sebkha) with sheets of shallow standing water.
## Crust: off-white salt polygons (voronoi ridges) over damp grey-brown
## mud. Water: a mirror-flat sheet only where the mask says so; the same
## mask answers is_water() for the car (spray, drag).

const CENTER := Vector3(50.0, 0.0, 0.0)
const HALF := Vector2(110.0, 120.0)    # x, z half extents
const MASK_RES := 256

var mask := Image.create(MASK_RES, MASK_RES, false, Image.FORMAT_R8)
var _noise := FastNoiseLite.new()


func _ready() -> void:
	_noise.seed = 11
	_noise.frequency = 0.022
	_noise.fractal_octaves = 3
	for y in MASK_RES:
		for x in MASK_RES:
			var w := _world_of(x, y)
			var n := _noise.get_noise_2d(w.x, w.z)
			# a long wet channel along the driving line + scattered pools
			var lane := 1.0 - smoothstep(4.0, 14.0, absf(w.z - sin(w.x * 0.05) * 5.0))
			var v := clampf((n + 0.12) * 4.0 + lane * 1.4, 0.0, 1.0)
			var edge := smoothstep(HALF.x * 0.75, HALF.x, absf(w.x - CENTER.x))
			v *= 1.0 - edge
			mask.set_pixel(x, y, Color(v, v, v))
	var tex := ImageTexture.create_from_image(mask)
	var crust := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = HALF * 2.0
	pm.subdivide_width = 4
	pm.subdivide_depth = 4
	crust.mesh = pm
	var cm := ShaderMaterial.new()
	cm.shader = load("res://game/drive/salt_crust.gdshader")
	cm.set_shader_parameter("wet_mask", tex)
	cm.set_shader_parameter("area_center", Vector2(CENTER.x, CENTER.z))
	cm.set_shader_parameter("area_half", HALF)
	crust.material_override = cm
	crust.position = CENTER + Vector3(0, DuneSea.SEBKHA_Y + 0.02, 0)
	add_child(crust)
	var water := MeshInstance3D.new()
	water.mesh = pm
	var wm := ShaderMaterial.new()
	wm.shader = load("res://game/drive/sebkha_water.gdshader")
	wm.set_shader_parameter("wet_mask", tex)
	wm.set_shader_parameter("area_center", Vector2(CENTER.x, CENTER.z))
	wm.set_shader_parameter("area_half", HALF)
	water.material_override = wm
	water.position = CENTER + Vector3(0, DuneSea.SEBKHA_Y + 0.07, 0)
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)


func _world_of(px: int, py: int) -> Vector3:
	var u := (px + 0.5) / MASK_RES
	var v := (py + 0.5) / MASK_RES
	return Vector3(CENTER.x - HALF.x + u * HALF.x * 2.0, 0.0, CENTER.z - HALF.y + v * HALF.y * 2.0)


func is_water(p: Vector3) -> bool:
	if p.y > DuneSea.SEBKHA_Y + 0.6:
		return false
	var u := (p.x - (CENTER.x - HALF.x)) / (HALF.x * 2.0)
	var v := (p.z - (CENTER.z - HALF.y)) / (HALF.y * 2.0)
	if u < 0.0 or u >= 1.0 or v < 0.0 or v >= 1.0:
		return false
	return mask.get_pixel(int(u * MASK_RES), int(v * MASK_RES)).r > 0.5
