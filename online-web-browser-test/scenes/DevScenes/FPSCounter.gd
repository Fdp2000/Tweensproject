extends Label

func _process(delta: float) -> void:
	# 1. The standard smooth average
	var avg_fps = Engine.get_frames_per_second()
	
	# 2. The INSTANT calculation (1 divided by the time the frame took)
	var instant_fps = 0
	if delta > 0:
		instant_fps = int(1.0 / delta)
		
	# 3. Frame Time in milliseconds (The best way to spot a lag spike)
	var frame_ms = delta * 1000.0
	
	text = "Avg FPS: %d\nSpike FPS: %d\nFrame Time: %.1f ms" % [avg_fps, instant_fps, frame_ms]
