@tool
extends EditorScript

func _run():
	print("--- STARTING ANIMATION FIX ---")
	var dir = DirAccess.open("res://Assets/Animations/Rhino")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		var count = 0
		while file_name != "":
			if file_name.ends_with(".res") or file_name.ends_with(".tres"):
				var anim_path = "res://Assets/Animations/Rhino/" + file_name
				var anim = ResourceLoader.load(anim_path)
				if anim is Animation:
					var modified = false
					for i in range(anim.get_track_count()):
						if anim.track_get_type(i) == Animation.TYPE_METHOD:
							var path = str(anim.track_get_path(i))
							# If the path is not a relative dot, we reset it to "."
							if path != "." and path != ".." and "metarig" not in path:
								print("FOUND CORRUPT TRACK in ", file_name, " (Path was: ", path, ") -> Changing to '.'")
								anim.track_set_path(i, ".")
								modified = true
					if modified:
						ResourceSaver.save(anim, anim_path)
						count += 1
			file_name = dir.get_next()
		print("--- DONE! FIXED ", count, " ANIMATIONS ---")
	else:
		print("Could not open Animations folder!")
