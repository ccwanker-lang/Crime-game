extends SceneTree
## Debug: prints the AABB of every Poly Haven model (run with --script).

func _init() -> void:
	var dir := DirAccess.open("res://assets/polyhaven")
	for id: String in dir.get_directories():
		var path: String = "res://assets/polyhaven/%s/%s.gltf" % [id, id]
		if not ResourceLoader.exists(path):
			continue
		var inst: Node = (load(path) as PackedScene).instantiate()
		var parts: PackedStringArray = []
		var total := AABB()
		var first: bool = true
		for mi: Node in inst.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			var t: Transform3D = Transform3D.IDENTITY
			var cur: Node = m
			while cur != inst:
				t = (cur as Node3D).transform * t
				cur = cur.get_parent()
			var bb: AABB = t * m.mesh.get_aabb()
			parts.append("%s[%s|%s]" % [m.name, _v(bb.position), _v(bb.size)])
			total = bb if first else total.merge(bb)
			first = false
		print("%s TOTAL pos=%s size=%s" % [id, _v(total.position), _v(total.size)])
		print("   ", " ".join(parts))
		inst.free()
	quit()

func _v(v: Vector3) -> String:
	return "%.2f,%.2f,%.2f" % [v.x, v.y, v.z]
