class_name Face

var a: Vector3:
	get:
		return vertices[0]
	set(new_a):
		vertices[0] = new_a
var b: Vector3:
	get:
		return vertices[1]
	set(new_b):
		vertices[1] = new_b
var c: Vector3:
	get:
		return vertices[2]
	set(new_c):
		vertices[2] = new_c

var vertices: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
## This class uses several-grade bounds to filter out unnecessary triangle intersection calculations.
var bounds: AABB
var region: Array[int]

func intersects_region(region: AABB) -> bool:
	return bounds.intersects(region)
