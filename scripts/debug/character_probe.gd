extends SceneTree
## Debug: prints height, facing and animation names of every character model.

func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var dir := DirAccess.open("res://assets/characters/quaternius")
	for f: String in dir.get_files():
		if not f.ends_with(".glb"):
			continue
		var inst: Node3D = (load("res://assets/characters/quaternius/" + f) as PackedScene).instantiate()
		root.add_child(inst)
		var total := AABB()
		var first: bool = true
		for mi: Node in inst.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			var bb: AABB = m.global_transform * m.get_aabb()
			total = bb if first else total.merge(bb)
			first = false
		var ap: AnimationPlayer = inst.find_children("*", "AnimationPlayer", true, false)[0]
		var sk: Array[Node] = inst.find_children("*", "Skeleton3D", true, false)
		var head_z: String = ""
		if not sk.is_empty():
			var s := sk[0] as Skeleton3D
			for b: int in s.get_bone_count():
				var bn: String = s.get_bone_name(b).to_lower()
				if bn.contains("foot") or bn == "head" or bn.contains("toe") or bn.contains("hips"):
					head_z += "%s:%s " % [s.get_bone_name(b), (s.global_transform * s.get_bone_global_pose(b)).origin]
		print("%s size=%s pos=%s nanims=%d walk_len=%s" % [f, total.size, total.position, ap.get_animation_list().size(), Array(ap.get_animation_list()).filter(func(a: String) -> bool: return a.ends_with("Walk")).map(func(a: String) -> float: return ap.get_animation(a).length)])
		print("   ", head_z.substr(0, 300))
		inst.free()
	quit()
