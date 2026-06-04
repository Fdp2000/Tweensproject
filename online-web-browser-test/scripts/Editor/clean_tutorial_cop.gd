@tool
extends EditorScript

func _run():
	print("--- CLEANING 12MB CORRUPTED FONT CACHE ---")
	
	var file_path = "res://scenes/UIScenes/TutorialCop.tscn"
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		print("ERROR: Could not open TutorialCop.tscn")
		return
		
	var lines = []
	var skip = false
	
	while not file.eof_reached():
		var line = file.get_line()
		
		# If we hit the massive Base64 Image chunk, skip it!
		if line.begins_with("[sub_resource type=\"Image\" id=\"Image_6orfi\"]"):
			skip = true
			continue
			
		# If we hit the next section bracket, stop skipping
		if skip and line.begins_with("["):
			skip = false
			
		if skip:
			continue
			
		# Delete all font cache offset/advance math
		if "cache/" in line:
			continue
			
		lines.append(line)
		
	file.close()
	
	# Save the squeaky clean file back to disk
	var save_file = FileAccess.open(file_path, FileAccess.WRITE)
	for i in range(lines.size()):
		# Don't store an extra blank line at the very end
		if i == lines.size() - 1 and lines[i] == "":
			continue
		save_file.store_line(lines[i])
	save_file.close()
	
	print("--- DONE! TutorialCop.tscn is now only a few Kilobytes! ---")
	print("WARNING: Godot might still show the old file size until you completely restart the engine, but the file is fixed!")
