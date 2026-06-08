@tool
extends EditorScript

func _run():
	ProjectSettings.set_setting("rendering/occlusion_culling/use_occlusion_culling", true)
	ProjectSettings.save()
	print("Occlusion Culling Enabled successfully!")
