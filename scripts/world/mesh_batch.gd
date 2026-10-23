extends RefCounted
## Bake static primitive descendants into one draw surface per shared material.
## Local transforms make this work both before and after entering the SceneTree.


static func combine(root: Node3D) -> void:
	var surfaces: Dictionary = {}
	var sources: Array[MeshInstance3D] = []
	for child in root.get_children():
		_collect(child, Transform3D.IDENTITY, surfaces, sources)
	var index := 0
	for material in surfaces:
		var surface: SurfaceTool = surfaces[material]
		surface.set_material(material)
		var batch := MeshInstance3D.new()
		batch.name = "MaterialBatch%d" % index
		batch.mesh = surface.commit()
		root.add_child(batch)
		index += 1
	for source in sources:
		source.get_parent().remove_child(source)
		source.free()


static func _collect(node: Node, parent_transform: Transform3D, surfaces: Dictionary, sources: Array[MeshInstance3D]) -> void:
	var relative := parent_transform
	if node is Node3D:
		relative = parent_transform * (node as Node3D).transform
	if node is MeshInstance3D:
		var visual := node as MeshInstance3D
		# These models use static, childless primitives; preserve other scene nodes.
		if visual.mesh is PrimitiveMesh and visual.visible and visual.get_child_count() == 0:
			for index in visual.mesh.get_surface_count():
				var material := visual.get_active_material(index)
				if not surfaces.has(material):
					var new_surface := SurfaceTool.new()
					new_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
					surfaces[material] = new_surface
				var surface: SurfaceTool = surfaces[material]
				# append_from transforms positions and existing normals together.
				surface.append_from(visual.mesh, index, relative)
			sources.append(visual)
	for child in node.get_children():
		_collect(child, relative, surfaces, sources)
