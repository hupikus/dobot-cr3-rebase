class_name CollisionGeometry
extends Node

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
				transform * vertices[i],
				transform * vertices[i + 1],
				transform * vertices[i + 2]
			))
	return ret

static func add_triangle(a: Vector3, b: Vector3, c: Vector3):
	var ret := Face.new()
	
	var minimum = a.min(b).min(c)
	var maximum = a.max(b).max(c)
	var bounds = AABB(minimum, maximum - minimum)
	
	ret.vertices = [a, b, c]
	ret.bounds = bounds
	
	return ret;

static func triangles_intersect(u: Face, v: Face) -> bool:
	for i in 3:
		# 1-2, 2-3, 3-1
		var j = (i + 1) % 3
		if Geometry3D.segment_intersects_triangle(u.vertices[i], u.vertices[j], v.a, v.b, v.c) != null: return true
		if Geometry3D.segment_intersects_triangle(v.vertices[i], v.vertices[j], u.a, u.b, u.c) != null: return true
	return false

static func meshes_intersect(a: Array, b: Array) -> bool:
	for tri_a: Face in a:
		for tri_b: Face in b:
			if tri_a.bounds.intersects(tri_b.bounds):
				continue
			if triangles_intersect(tri_a, tri_b):
				return true
	return false
