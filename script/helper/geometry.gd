class_name CollisionGeometry
extends Node

var GRADE_BOUNDS_MAX_SIZE = 0.1
var GRADE_BOUNDS_LEVEL = 4
var GRADE_BOUNDS_DECREASE_FACTOR: int = 2

var region_data: RegionData

func _init() -> void:
	region_data = RegionData.new()
	region_data.bounds = AABB(Vector3.ONE * -GRADE_BOUNDS_MAX_SIZE / 2.0, Vector3.ONE * GRADE_BOUNDS_MAX_SIZE)

func calculate_child_regions_bounds(parent: AABB) -> Array[AABB]:
	var result: Array[AABB] = []

	var size := parent.size / float(GRADE_BOUNDS_DECREASE_FACTOR)

	for x in GRADE_BOUNDS_DECREASE_FACTOR:
		for y in GRADE_BOUNDS_DECREASE_FACTOR:
			for z in GRADE_BOUNDS_DECREASE_FACTOR:
				var offset := Vector3(x, y, z) * size

				result.append(AABB(
					parent.position + offset,
					size
				))
	return result

func attach_to_region(face: Face) -> bool:
	return _attach_to_region(face, region_data, 0)

## Returning: if new regions were created.
func _attach_to_region(face: Face, region: RegionData, current_depth: int) -> bool:
	if not face.intersects_region(region.bounds):
		return false
	var new := false
	
	if current_depth >= GRADE_BOUNDS_LEVEL:
		if not region.faces.has(face):
			region.faces.append(face)
			region.has_mesh = true
		return true
	
	if region.regions.is_empty():
		for bounds in calculate_child_regions_bounds(region.bounds):
			if face.intersects_region(bounds):
				var child := RegionData.new()
				child.bounds = bounds
				child.parent = region
				region.regions.append(child)
				new = true
	
	for subregion in region.regions:
		new = _attach_to_region(face, subregion, current_depth + 1) || new

	return new

static func get_triangles(node: MeshInstance3D) -> Array[Face]:
	var ret: Array[Face] = []
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

static func add_triangle(a: Vector3, b: Vector3, c: Vector3) -> Face:
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
