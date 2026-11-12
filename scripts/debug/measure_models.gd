extends SceneTree
## Prints the AABB (size + centre) of glTF models: --script res://scripts/debug/measure_models.gd -- id id ...
func _init() -> void:
	for id: String in OS.get_cmdline_user_args():
		var path: String = "res://assets/polyhaven/%s/%s.gltf" % [id, id]
		var root: Node3D = (load(path) as PackedScene).instantiate()
		var box := AABB()
		var first: bool = true
		for m: Node in root.find_children("*", "MeshInstance3D", true, false):
			var mi := m as MeshInstance3D
			var t: Transform3D = Transform3D.IDENTITY
			var n: Node = mi
			while n != root:
				t = (n as Node3D).transform * t if n == mi else (n as Node3D).transform * t
				n = n.get_parent()
			var a: AABB = t * mi.get_aabb()
			box = a if first else box.merge(a)
			first = false
		var names: PackedStringArray = []
		for c: Node in root.get_children():
			names.append(c.name)
		print("%s size %s centre %s parts %s" % [id, box.size.snapped(Vector3.ONE * 0.01), box.get_center().snapped(Vector3.ONE * 0.01), names])
		root.free()
	quit()
