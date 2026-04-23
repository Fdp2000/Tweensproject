extends Control

var progress: float = 1.0
var ring_color: Color = Color(1.0, 0.84, 0.0, 0.9)
var ready_color: Color = Color(1.0, 0.84, 0.0, 0.9)

func _process(_delta):
	queue_redraw()

func _draw():
	var center = size / 2.0
	var radius = min(size.x, size.y) / 2.0 - 4.0 # Leave room for thickness
	
	# Draw background ring (dark transparent)
	draw_arc(center, radius, 0, TAU, 32, Color(0, 0, 0, 0.4), 6.0, true)
	
	# Draw progress ring
	if progress < 1.0:
		# Draw filling up
		var end_angle = -PI/2 + (progress * TAU)
		if progress > 0:
			draw_arc(center, radius, -PI/2, end_angle, 32, ring_color, 6.0, true)
	else:
		# Solid when full and ready
		draw_arc(center, radius, 0, TAU, 32, ready_color, 6.0, true)
