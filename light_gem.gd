class_name LightGem
extends Node3D
## Samples two rendered views for player illumination. raw_value is the brightest
## opaque quadrant average; value is calibration_curve.sample(raw_value).
## Requires both viewports and a calibration curve; headless runs keep prior values.

@export var viewport_top: Viewport
@export var viewport_bottom: Viewport
@export var calibration_curve: Curve
@export var frames_between_samples = 3
var raw_value = 0.0
var value = 0.0
var frame_counter = 0

func _ready() -> void:
	pass


## Reads the GPU images every frames_between_samples process frames.
func _process(delta: float) -> void:
	# No renderer (a headless run): nothing to read, and asking only errors.
	if DisplayServer.get_name() == "headless":
		return

	frame_counter += 1
	if frame_counter < frames_between_samples: return
	frame_counter = 0
	
	var vport_top = sample_viewport(viewport_top)
	var vport_bot = sample_viewport(viewport_bottom)
	
	raw_value = max(vport_top, vport_bot)
	value = calibration_curve.sample(raw_value)
	
## Returns brightest opaque quadrant mean, or 0.0 when no image was rendered.
## viewport is untyped and must provide get_texture().get_image(); image must be square.
func sample_viewport(viewport) -> float:
	var image = viewport.get_texture().get_image()

	# Nothing rendered yet (the first frames, or no renderer at all): no reading.
	if image == null:
		return 0.0

	var W = image.get_width()
	var N = W - 1
	var sums = [0,0,0,0]
	var counts = [0,0,0,0]
	var region
	
	for x in range(0, W):
		for y in range(0, W):
			var pixel = image.get_pixel(x, y)
			if pixel.a < 1: continue
			
			region = classify(x, y, N)
			sums[region] += luminance(pixel)
			counts[region] += 1
			
	var brightest = 0
	for r in range(0, 4):
		if counts[r] > 0:
			var avg = sums[r] / counts[r]
			brightest = max(brightest, avg)
	return brightest
	
## Returns quadrant index 0..3 for pixel coordinates; N is image width minus one.
## x/y/N are untyped numeric arguments. Diagonals define four triangular regions.
func classify(x, y, N) -> int:
	if y <= x and x + y >= N: return 0
	elif y < x: return 1
	elif y > N - x: return 2
	else: return 3
	
## Returns weighted RGB luminance; untyped color must expose numeric r/g/b fields.
func luminance(color) -> float:
	return 0.299 * color.r + 0.587 * color.g + 0.114 * color.b
			
	
