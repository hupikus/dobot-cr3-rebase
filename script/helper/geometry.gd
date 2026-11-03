class_name CollisionGeometry
extends Node

const FIELD_SIZE := Vector3(2.0, 1.0, 2.0)

static var GRADE_BOUNDS_MAX_SIZE = 1.0
static var GRADE_BOUNDS_LEVEL = 5
static var GRADE_BOUNDS_DECREASE_FACTOR = 4

static var REGIONS: Array[AABB] = []

class Face:
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

static func generate_regions() -> void:
	var size = GRADE_BOUNDS_MAX_SIZE
	for k in GRADE_BOUNDS_LEVEL:
		var dim := Vector3(size, size, size)
		var x = -FIELD_SIZE.x
		while x < FIELD_SIZE.x: 
			var y = -FIELD_SIZE.y
			while y < FIELD_SIZE.y:
				var z = -FIELD_SIZE.z
				while z < FIELD_SIZE.z:
					var box = AABB(Vector3(x, y, z) - dim / 2.0, dim)
					CollisionGeometry.REGIONS.append(box)
					z += size
				y += size
			x += size
		size /= GRADE_BOUNDS_DECREASE_FACTOR
	return

static func get_triangles(node: MeshInstance3D) -> Array:
	var ret = []
	var mesh := node.mesh
	var transform := node.global_transform
	
	for surface in mesh.get_surface_count():
		
		if mesh is not PrimitiveMesh:
			if mesh.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
				print("Auto mesh triangulation is not implemented. Triangulate your mesh. Collision with % will not work properly." % [node.get_path()])
		
		var arrays := mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		
		for i in range(0, vertices.size() - 2, 3):
			ret.append(add_triangle(
				transform * vertices[indices[i]],
				transform * vertices[indices[i + 1]],
				transform * vertices[indices[i + 2]]
			))
	return ret

static func add_triangle(a: Vector3, b: Vector3, c: Vector3):
	var face := Face.new()
	
	var minimum = a.min(b).min(c)
	var maximum = a.max(b).max(c)
	var bounds = AABB(minimum, maximum - minimum)
	
	face.vertices = [a, b, c]
	face.bounds = bounds

	return face;

static func triangles_intersect(u: Face, v: Face) -> bool:
	for i in 3:
		# 1-2, 2-3, 3-1
		var j = (i + 1) % 3
		if Geometry3D.segment_intersects_triangle(u.vertices[i], u.vertices[j], v.a, v.b, v.c) != null: return true
		if Geometry3D.segment_intersects_triangle(v.vertices[i], v.vertices[j], u.a, u.b, u.c) != null: return true
	return false

static func meshes_intersect(a: Array, b: Array) -> bool:
	var i := 0
	for tri_a: Face in a:
		var j := -1
		for tri_b: Face in b:
			if j <= i:
				continue
			if tri_a.bounds.intersects(tri_b.bounds):
				continue
			
			if triangles_intersect(tri_a, tri_b):
				return true
	return false
